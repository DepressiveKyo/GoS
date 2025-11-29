if _G.__DEPRESSIVE_NEXT_KATARINA_LOADED then return end
_G.__DEPRESSIVE_NEXT_KATARINA_LOADED = true

local Version = "1.1"
local Name = "Depressive - Katarina"

if myHero.charName ~= "Katarina" then return end

-- Prediction library (DepressivePrediction)
local DepressivePrediction = require("DepressivePrediction")
if not DepressivePrediction then
	print("[Katarina] DepressivePrediction not found, using fallback")
end

local function CheckPredictionSystem()
	-- Prediction library optional: script can work without it (fallback to simple casts)
	return true
end

-- SPELL SLOT CONSTANTS
local _Q = 0
local _W = 1
local _E = 2
local _R = 3

local HK_Q = HK_Q or _Q
local HK_W = HK_W or _W
local HK_E = HK_E or _E
local HK_R = HK_R or _R

-- Utilities (compat with DepressiveAIONext champion patterns)
local insert = table.insert
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local TEAM_ENEMY = (myHero.team == 100 and 200) or 100
local TEAM_JUNGLE = _G.TEAM_JUNGLE or 300

local math_sqrt = math.sqrt
local function IsValid(u) return u and u.valid and u.visible and not u.dead and u.isTargetable end
local function Distance(a,b) if not a or not b then return 1e9 end local dx=(a.x or a.pos.x)-(b.x or b.pos.x); local dz=(a.z or a.pos.z)-(b.z or b.pos.z); return math_sqrt(dx*dx+dz*dz) end
local function DistanceSqr(a,b) local dx=(a.x or a.pos.x)-(b.x or b.pos.x); local dz=(a.z or a.pos.z)-(b.z or b.pos.z); return dx*dx+dz*dz end

local _EnemyCache={t=0,list={}}
local function GetEnemyHeroes()
	local now = Game.Timer and Game.Timer() or os.clock()
	if now - _EnemyCache.t > 0.25 then
		local L = {}
		for i = 1, GameHeroCount() do local h = GameHero(i); if h and h.team ~= myHero.team and IsValid(h) then L[#L+1] = h end end
		_EnemyCache.list = L; _EnemyCache.t = now
	end
	return _EnemyCache.list
end

local function GetTarget(range)
	local best, bd = nil, 1e9
	for _, e in ipairs(GetEnemyHeroes()) do local d = Distance(myHero.pos, e.pos); if d < range and d < bd then best = e; bd = d end end
	return best
end

-- Ready checks
local function Ready(slot) local sd = myHero:GetSpellData(slot); return sd and sd.level > 0 and sd.currentCd == 0 and sd.mana <= myHero.mana and Game.CanUseSpell(slot) == 0 end
local function MyHeroNotReady() return myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) end

-- Mode helper (support SDK/GOS)
local function GetMode()
	if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then local M=_G.SDK.Orbwalker.Modes; if M[_G.SDK.ORBWALKER_MODE_COMBO] or M.Combo then return "Combo" end; if M[_G.SDK.ORBWALKER_MODE_HARASS] or M.Harass then return "Harass" end; if M[_G.SDK.ORBWALKER_MODE_LANECLEAR] or M.Clear or M.LaneClear then return "Clear" end end
	if _G.GOS and _G.GOS.GetMode then local m=_G.GOS:GetMode(); if m==1 then return "Combo" elseif m==2 then return "Harass" elseif m==3 then return "Clear" end end
	return "None"
end

-- DelayAction (small scheduler for delayed execution)
local _DelayedActions = {}
local function DelayAction(func, delay)
	table.insert(_DelayedActions, {func = func, time = os.clock() + delay})
end
local function ProcessDelayedActions()
	local now = os.clock()
	for i = #_DelayedActions, 1, -1 do
		if now >= _DelayedActions[i].time then
			_DelayedActions[i].func()
			table.remove(_DelayedActions, i)
		end
	end
end

local SPELL_RANGE = {
	Q = 625,
	W = 340,
	E = 725,
	R = 550
}

local function getdmg(spell, target, source)
	if not target or not source then return 0 end
    
	if spell == "Q" then
		local level = source:GetSpellData(_Q).level
		if level == 0 then return 0 end
		local baseDmg = 75 + (level - 1) * 30
		local apRatio = 0.30
		return baseDmg + (source.ap * apRatio)
	elseif spell == "E" then
		local level = source:GetSpellData(_E).level
		if level == 0 then return 0 end
		local baseDmg = 15 + (level - 1) * 25
		local adRatio = 0.65
		local apRatio = 0.25
		return baseDmg + (source.totalDamage * adRatio) + (source.ap * apRatio)
	elseif spell == "R" then
		local level = source:GetSpellData(_R).level
		if level == 0 then return 0 end
		local baseDmg = 375 + (level - 1) * 187.5
		local adRatio = 2.85
		local apRatio = 1.65
		return baseDmg + (source.totalDamage * adRatio) + (source.ap * apRatio)
	end
    
	return 0
end

-- Simple hitchance helper
local function HitchanceOK(got, needed)
	needed = needed or (DepressivePrediction and DepressivePrediction.HITCHANCE_NORMAL or 3)
	return (got or 0) >= needed
end

-- Check if Katarina is channeling her ultimate (Death Lotus)
-- Must be defined before functions that use it
local function IsChannelingUlt()
	-- Method 1: Check buff
	for i = 0, myHero.buffCount do
		local buff = myHero:GetBuff(i)
		if buff and buff.name and buff.count > 0 then
			local name = buff.name:lower()
			if name:find("katarinar") or name:find("katarinarsound") or name:find("deathlotustarget") then
				return true
			end
		end
	end
	
	-- Method 2: Check if R spell is on cooldown but was just cast (active channel)
	local rData = myHero:GetSpellData(_R)
	if rData and rData.level > 0 then
		-- R has a channel time of 2.5 seconds, check if currently casting
		if myHero.activeSpell and myHero.activeSpell.valid then
			local spellName = myHero.activeSpell.name
			if spellName and spellName:lower():find("katarinar") then
				return true
			end
		end
	end
	
	return false
end

local function CastQWithPrediction(target)
	if not target then return false end
	-- Never Q during R channel - would cancel ultimate
	if IsChannelingUlt() then return false end
	if DepressivePrediction and DepressivePrediction.SpellPrediction then
		local ok, spell = pcall(function() return DepressivePrediction:SpellPrediction({
			Type = DepressivePrediction.SPELLTYPE_LINE,
			Speed = math.huge,
			Range = SPELL_RANGE.Q,
			Delay = 0.25,
			Radius = 75,
			Collision = false
		}) end)
		if ok and spell then
			pcall(function() spell:GetPrediction(target, myHero) end)
			if HitchanceOK(spell.HitChance) then
				Control.CastSpell(HK_Q, spell.CastPosition or target.pos)
				return true
			end
		end
	end
	-- Fallback to direct cast
	Control.CastSpell(HK_Q, target.pos)
	return true
end

local cachedDaggers = {}
local lastDaggerUpdate = 0
local isChannelingR = false
local rStartTime = 0
local comboQCast = false
local comboECast = false
local comboWCast = false
local lastComboTime = 0

local function GetDaggers()
	if Game.Timer() - lastDaggerUpdate < 0.1 then
		return cachedDaggers
	end
    
	cachedDaggers = {}
	for i = 1, Game.ObjectCount() do
		local obj = Game.Object(i)
		if obj and obj.name then
			local name = obj.name
			if name:find("Katarina") and name:find("Indicator") then
				table.insert(cachedDaggers, obj)
			end
		end
	end
	lastDaggerUpdate = Game.Timer()
	return cachedDaggers
end

local function GetBestDagger(target)
	if not target then return nil end
	local daggers = GetDaggers()
	local bestDagger, bestDistance = nil, math.huge
	for _, dagger in ipairs(daggers) do
		if dagger and dagger.pos then
			local distToMe = myHero.pos:DistanceTo(dagger.pos)
			local distToTarget = dagger.pos:DistanceTo(target.pos)
			if distToMe <= SPELL_RANGE.E and distToTarget <= 450 then
				if distToTarget < bestDistance then
					bestDistance = distToTarget
					bestDagger = dagger
				end
			end
		end
	end
	return bestDagger
end

-- Compute a deterministic pixel on the dagger area toward the target
local function GetDaggerEdgePos(dagger, target)
	if not dagger or not dagger.pos then return nil end
	if not target or not target.pos then return dagger.pos end
	local v = (target.pos - dagger.pos)
	if v:Len() == 0 then return dagger.pos end
	local dir = v:Normalized()
	local offset = 150 -- inside dagger area toward target
	return dagger.pos + dir * offset
end

-- Try instant E to the best dagger near the target; returns true if cast
local function TryInstantEDagger(target)
	if not target or not Ready(_E) then return false end
	-- Never E during R channel - would cancel ultimate
	if IsChannelingUlt() then return false end
	local d = GetBestDagger(target)
	if d and d.pos then
		local jumpPos = GetDaggerEdgePos(d, target) or d.pos
		Control.CastSpell(HK_E, jumpPos)
		comboECast = true
		lastComboTime = Game.Timer()
		return true
	end
	return false
end

local function IsInMeleeRange(target)
	if not target then return false end
	local distance = myHero.pos:DistanceTo(target.pos)
	return distance <= 350
end

local function GetEnemiesInRRange()
	local enemies = {}
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and hero.isEnemy and IsValid(hero) then
			local distance = myHero.pos:DistanceTo(hero.pos)
			if distance <= SPELL_RANGE.R then
				table.insert(enemies, hero)
			end
		end
	end
	return enemies
end

class "DepressiveKatarina"

function DepressiveKatarina:__init()
	self:LoadMenu()
    
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
    
	if _G.SDK and _G.SDK.Orbwalker then
		_G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
	end
end

function DepressiveKatarina:LoadMenu()
	self.Menu = MenuElement({type = MENU, id = "Depressive"..myHero.charName, name = "Depressive - " .. myHero.charName})
	self.Menu:MenuElement({name = " ", drop = {"Version " .. tostring(Version)}})
    
	self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Bouncing Blade", value = true})
	self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Preparation", value = true})
	self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Shunpo", value = true})
	self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Auto R after Q E W", value = true})
	self.Menu.Combo:MenuElement({id = "EDagger", name = "E to Daggers", value = true})
	self.Menu.Combo:MenuElement({id = "EWCombo", name = "Always W after E", value = true})
	self.Menu.Combo:MenuElement({id = "RBlock", name = "Block Movement during R", value = true})
	self.Menu.Combo:MenuElement({id = "RAutoE", name = "Auto E during R (kill/escape)", value = true})
	self.Menu.Combo:MenuElement({id = "InstantEDagger", name = "Instant E to dagger on hit", value = true})
    
	self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
	self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Bouncing Blade", value = true})
	self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Shunpo", value = false})
    
	self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
	self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Bouncing Blade", value = true})
	self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Preparation", value = true})
	self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Shunpo", value = false})
    
	self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
	self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Bouncing Blade", value = true})
	self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Preparation", value = true})
	self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Shunpo", value = true})
    
	self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
	self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Bouncing Blade", value = true})
	self.Menu.ks:MenuElement({id = "UseE", name = "[E] Shunpo", value = true})
    
	self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
	self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = true})
	self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = true})
	self.Menu.Drawing:MenuElement({id = "DrawDaggers", name = "Draw Daggers", value = true})
	self.Menu.Drawing:MenuElement({id = "Kill", name = "Draw Killable Targets", value = true})
	self.Menu.Drawing:MenuElement({id = "DrawDaggerArea", name = "Draw dagger 450 area", value = false})
end

function DepressiveKatarina:Tick()
	if myHero.dead or Game.IsChatOpen() then return end
    
	if not CheckPredictionSystem() then return end
    
	isChannelingR = IsChannelingUlt()
    
	-- Execute delayed scheduled actions ONLY if NOT channeling R
	-- This prevents W/E/Q from canceling the ultimate
	if not isChannelingR then
		ProcessDelayedActions()
	else
		-- Clear all pending actions when R is active to prevent cancellation
		_DelayedActions = {}
	end
    
	if isChannelingR then
		-- Bloquear orbwalker completamente durante la R
		if _G.SDK and _G.SDK.Orbwalker then
			if _G.SDK.Orbwalker.SetMovement then
				_G.SDK.Orbwalker:SetMovement(false)
			end
			if _G.SDK.Orbwalker.SetAttack then
				_G.SDK.Orbwalker:SetAttack(false)
			end
		end
		-- Bloquear movimiento manual para evitar cancelar la R
		if self.Menu.Combo.RBlock:Value() then
			pcall(function() Control.SetCursorPos(myHero.pos:To2D()) end)
		end
		self:RLogic()
		return
	else
		-- Restaurar orbwalker cuando no está usando la R
		if _G.SDK and _G.SDK.Orbwalker then
			if _G.SDK.Orbwalker.SetMovement then
				_G.SDK.Orbwalker:SetMovement(true)
			end
			if _G.SDK.Orbwalker.SetAttack then
				_G.SDK.Orbwalker:SetAttack(true)
			end
		end
	end
    
	local Mode = GetMode()
    
	if Mode == "Combo" then
		self:Combo()
	else
		comboQCast = false
		comboECast = false
		comboWCast = false
	end
    
	if Mode == "Harass" then
		self:Harass()
	elseif Mode == "Clear" then
		self:LaneClear()
		self:JungleClear()
	end
    
	-- No ejecutar KillSteal durante la R
	if not isChannelingR then
		self:KillSteal()
	end
end

function DepressiveKatarina:RLogic()
	-- Durante la R, NO usar E ni ninguna otra habilidad ya que cancela la ultimate
	-- Solo mantener la posición y dejar que la R haga daño
	-- El bloqueo de movimiento y orbwalker ya se maneja en Tick()
	
	-- NOTA: La opción RAutoE está deshabilitada porque usar E durante la R la cancela
	-- Si en el futuro se necesita escape, se puede implementar con cuidado extremo
	-- pero por ahora es mejor mantener la R activa sin interrupciones
end

function DepressiveKatarina:Combo()
	-- No ejecutar combo si está usando la R
	if isChannelingR then return end
	
	local target = GetTarget(1000)
	if target == nil then 
		comboQCast = false
		comboECast = false
		comboWCast = false
		lastComboTime = 0
		return 
	end
    
	if Game.Timer() - lastComboTime > 5 then
		comboQCast = false
		comboECast = false
		comboWCast = false
	end
    
	if IsValid(target) then
		local distance = myHero.pos:DistanceTo(target.pos)

		-- Allow re-casting combo spells whenever they become ready again while holding Combo
	if comboQCast and Ready(_Q) then comboQCast = false end
	if comboECast and Ready(_E) then comboECast = false end
	if comboWCast and Ready(_W) then comboWCast = false end

		-- Continuous instant dagger jumps while holding combo if enabled
		-- Double-check R is not channeling before any spell cast
	if self.Menu.Combo.InstantEDagger:Value() and Ready(_E) and not IsChannelingUlt() then
			if TryInstantEDagger(target) then
				-- After jumping to dagger optionally W if setting enabled
				if self.Menu.Combo.EWCombo:Value() and Ready(_W) and not comboWCast and not IsChannelingUlt() then
					Control.CastSpell(HK_W)
					comboWCast = true
					lastComboTime = Game.Timer()
				end
			end
		end
        
    if not comboQCast and distance <= SPELL_RANGE.Q and self.Menu.Combo.UseQ:Value() and Ready(_Q) and not IsChannelingUlt() then
	    CastQWithPrediction(target)
			comboQCast = true
			lastComboTime = Game.Timer()
			if self.Menu.Combo.InstantEDagger:Value() and Ready(_E) and not IsChannelingUlt() then
				local daggerAfterQ = GetBestDagger(target)
				if daggerAfterQ and daggerAfterQ.pos then
					Control.CastSpell(HK_E, daggerAfterQ.pos)
					comboECast = true
					lastComboTime = Game.Timer()
					if self.Menu.Combo.EWCombo:Value() and Ready(_W) and not IsChannelingUlt() then
						Control.CastSpell(HK_W)
						comboWCast = true
						lastComboTime = Game.Timer()
					end
				end
			end
			return
		end
        
	if not comboECast and self.Menu.Combo.UseE:Value() and Ready(_E) and self.Menu.Combo.EDagger:Value() and not IsChannelingUlt() then
			local bestDagger = GetBestDagger(target)
			if bestDagger and bestDagger.pos then
				local edgePos = GetDaggerEdgePos(bestDagger, target)
				Control.CastSpell(HK_E, edgePos)
				comboECast = true
				lastComboTime = Game.Timer()
                
				if self.Menu.Combo.EWCombo:Value() and Ready(_W) then
					DelayAction(function()
						-- Don't cast W if R is channeling (would cancel it)
						if Ready(_W) and not IsChannelingUlt() then
							Control.CastSpell(HK_W)
							comboWCast = true
							lastComboTime = Game.Timer()
						end
					end, 0.1)
				end
				return
			end
		end
        
		if comboQCast and comboECast and (comboWCast or Game.Timer() - lastComboTime >= 0.5) then
			if distance <= SPELL_RANGE.R and self.Menu.Combo.UseR:Value() and Ready(_R) then
				Control.CastSpell(HK_R)
				comboQCast = false
				comboECast = false
				comboWCast = false
				lastComboTime = 0
				return
			end
		end
        
	if IsInMeleeRange(target) and self.Menu.Combo.UseW:Value() and Ready(_W) and not comboWCast and not IsChannelingUlt() then
			Control.CastSpell(HK_W)
			comboWCast = true
			lastComboTime = Game.Timer()
			if self.Menu.Combo.InstantEDagger:Value() and Ready(_E) and not IsChannelingUlt() then
				local daggerAfterW = GetBestDagger(target)
				if daggerAfterW and daggerAfterW.pos then
					Control.CastSpell(HK_E, daggerAfterW.pos)
					comboECast = true
					lastComboTime = Game.Timer()
				end
			end
		end
	end
end

function DepressiveKatarina:Harass()
	-- No ejecutar harass si está usando la R
	if isChannelingR then return end
	
	local target = GetTarget(1000)
	if target == nil then return end
    
	if IsValid(target) then
		local distance = myHero.pos:DistanceTo(target.pos)

		-- Harass: keep jumping to daggers if enabled
	if self.Menu.Combo.InstantEDagger:Value() and Ready(_E) then
			TryInstantEDagger(target)
		end
        
    if distance <= SPELL_RANGE.Q and self.Menu.Harass.UseQ:Value() and Ready(_Q) then
	    CastQWithPrediction(target)
			if self.Menu.Combo.InstantEDagger:Value() and Ready(_E) then
				local daggerAfterQ = GetBestDagger(target)
				if daggerAfterQ and daggerAfterQ.pos then
					local jumpPos = GetDaggerEdgePos(daggerAfterQ, target) or daggerAfterQ.pos
					Control.CastSpell(HK_E, jumpPos)
				end
			end
		end
        
	if distance <= SPELL_RANGE.E and self.Menu.Harass.UseE:Value() and Ready(_E) then
			local bestDagger = GetBestDagger(target)
			if bestDagger and bestDagger.pos then
				local jumpPos = GetDaggerEdgePos(bestDagger, target) or bestDagger.pos
				Control.CastSpell(HK_E, jumpPos)
			end
		end
	end
end

function DepressiveKatarina:LaneClear()
	-- No ejecutar lane clear si está usando la R
	if isChannelingR then return end
	
	local minions = {}
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
	if minion.team == TEAM_ENEMY and IsValid(minion) and myHero.pos:DistanceTo(minion.pos) <= SPELL_RANGE.Q then
			table.insert(minions, minion)
		end
	end
    
	if #minions == 0 then return end
    
	if self.Menu.Clear.UseQ:Value() and Ready(_Q) then
		for _, minion in ipairs(minions) do
			if myHero.pos:DistanceTo(minion.pos) <= SPELL_RANGE.Q then
				Control.CastSpell(HK_Q, minion.pos)
				return
			end
		end
	end
    
	if self.Menu.Clear.UseW:Value() and Ready(_W) and #minions >= 2 then
		Control.CastSpell(HK_W)
		return
	end
end

function DepressiveKatarina:JungleClear()
	-- No ejecutar jungle clear si está usando la R
	if isChannelingR then return end
	
	for i = 1, Game.MinionCount() do
		local minion = Game.Minion(i)
	if IsValid(minion) and minion.team == TEAM_JUNGLE then
			local distance = myHero.pos:DistanceTo(minion.pos)
            
			if distance <= SPELL_RANGE.Q and self.Menu.JClear.UseQ:Value() and Ready(_Q) then
				Control.CastSpell(HK_Q, minion.pos)
				return
			end
            
			if distance <= SPELL_RANGE.W and self.Menu.JClear.UseW:Value() and Ready(_W) then
				Control.CastSpell(HK_W)
				return
			end
            
			if distance <= SPELL_RANGE.E and self.Menu.JClear.UseE:Value() and Ready(_E) then
				Control.CastSpell(HK_E, minion.pos)
				return
			end
		end
	end
end

function DepressiveKatarina:KillSteal()
	-- No ejecutar killsteal si está usando la R
	if isChannelingR then return end
	
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
	if hero.isEnemy and IsValid(hero) and myHero.pos:DistanceTo(hero.pos) <= 1000 then
			local distance = myHero.pos:DistanceTo(hero.pos)
            
				if self.Menu.ks.UseQ:Value() and Ready(_Q) and distance <= SPELL_RANGE.Q then
				local QDmg = getdmg("Q", hero, myHero) or 0
				if hero.health <= QDmg then
					CastQWithPrediction(hero)
					return
				end
			end
            
			if self.Menu.ks.UseE:Value() and Ready(_E) and distance <= SPELL_RANGE.E then
				local EDmg = getdmg("E", hero, myHero) or 0
				if hero.health <= EDmg then
					Control.CastSpell(HK_E, hero.pos)
					return
				end
			end
		end
	end
end

function DepressiveKatarina:Draw()
	if myHero.dead then return end
    
	if not CheckPredictionSystem() then return end
    
	if self.Menu.Drawing.DrawQ:Value() and Ready(_Q) then
		Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 255, 0, 0))
	end
    
	if self.Menu.Drawing.DrawE:Value() and Ready(_E) then
		Draw.Circle(myHero.pos, SPELL_RANGE.E, 1, Draw.Color(255, 0, 255, 0))
	end
    
	if self.Menu.Drawing.DrawDaggers:Value() then
		local daggers = GetDaggers()
		for _, dagger in ipairs(daggers) do
			if dagger and dagger.pos then
				Draw.Circle(dagger.pos, 100, 1, Draw.Color(255, 255, 100, 0))
				if self.Menu.Drawing.DrawDaggerArea:Value() then
					Draw.Circle(dagger.pos, 450, 1, Draw.Color(255, 255, 0, 0))
				end
			end
		end
	end
    
	if self.Menu.Drawing.Kill:Value() then
		for i = 1, Game.HeroCount() do
			local hero = Game.Hero(i)
				if hero.isEnemy and IsValid(hero) and myHero.pos:DistanceTo(hero.pos) <= 2000 then
				local QDmg = getdmg("Q", hero, myHero) or 0
				local EDmg = getdmg("E", hero, myHero) or 0
				local RDmg = getdmg("R", hero, myHero) or 0
				local totalDmg = QDmg + EDmg + RDmg
                
				if hero.health <= totalDmg then
					local pos = hero.pos:To2D()
					Draw.Text("KILLABLE", 20, pos.x - 35, pos.y - 50, Draw.Color(255, 255, 0, 0))
				end
			end
		end
	end
end

function DepressiveKatarina:OnPostAttack()
	-- No ejecutar nada si está usando la R
	if isChannelingR then return end
	
	if not _G.SDK or not _G.SDK.Orbwalker then return end
    
	local target = _G.SDK.Orbwalker:GetTarget()
	if not target or not IsValid(target) then return end
    
	local mode = GetMode()
    
	if mode == "Combo" then
		-- Instant dagger jump after an auto if enabled and E ready
		if self.Menu.Combo.InstantEDagger:Value() and Ready(_E) then
			local daggerAfterAA = GetBestDagger(target)
			if daggerAfterAA and daggerAfterAA.pos then
				local jumpPos = GetDaggerEdgePos(daggerAfterAA, target) or daggerAfterAA.pos
				Control.CastSpell(HK_E, jumpPos)
				return
			end
		end
	end
end

DepressiveKatarina()

