if _G.DepressiveCamilleLoaded then return end
_G.DepressiveCamilleLoaded = true

local LibPath = "Common/Depressive/DepressiveLib.lua"
local DepressiveLib = _G.DepressiveLib or require("DepressiveLib") or require(LibPath)
if not DepressiveLib then print("[DepressiveCamille] DepressiveLib missing") return end
if myHero.charName ~= "Camille" then return end

require "MapPositionGOS"
pcall(function() require("DepressivePrediction") end)
pcall(function() require("DamageLib") end)

local Camille = { __version = 1.60 }

-- Slots
local _Q, _W, _E, _R = 0,1,2,3

-- Prediction bridge
local DP = _G.DepressivePrediction
local function DPReady() return DP and DP.SpellPrediction end
local function DP_HC(val)
	if not DP then return 3 end
	if val == 1 then return DP.HITCHANCE_NORMAL or 3 end
	if val == 2 then return DP.HITCHANCE_HIGH or 4 end
	return DP.HITCHANCE_IMMOBILE or 6
end

-- Helpers referencing lib
local Ready = DepressiveLib.Ready
local IsValid = DepressiveLib.IsValid
local GetMode = DepressiveLib.GetMode
local GetTarget = function(r) return DepressiveLib.GetTarget(r, "AD") end
local PercentMP = DepressiveLib.PercentMP
local UnderTurret = DepressiveLib.UnderEnemyTurret

-- Q2 true damage estimate
local function Q2TrueDamage()
	local lvl = myHero.levelData.lvl
	local qLvl = myHero:GetSpellData(_Q).level
	if qLvl == 0 then return 0 end
	local baseRatio = ({0.4,0.5,0.6,0.7,0.8})[qLvl] or 0.4
	local base = baseRatio * myHero.totalDamage + myHero.totalDamage
	local bonusRatio = ({0.40,0.44,0.48,0.52,0.56,0.60,0.64,0.68,0.72,0.76,0.80,0.84,0.88,0.92,0.96,1.00,1.00,1.00})[lvl] or 0.4
	return base * bonusRatio
end

-- Menu
local Menu
local function LoadMenu()
	if not _G.MenuElement then return end
	Menu = MenuElement({type = MENU, id = "DepressiveCamille", name = "Depressive Camille"})
	Menu:MenuElement({name = " ", drop = {"Version "..Camille.__version}})
	Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
	Menu.combo:MenuElement({id="useAA", name="Set AutoAttacks", value=3, min=0, max=10, identifier="AA/s"})
	Menu.combo:MenuElement({id="useQ", name="Use Q", value=true})
	Menu.combo:MenuElement({id="useW", name="Use W", value=true})
	Menu.combo:MenuElement({id="eWeave", name="E > W > E if possible", value=true})
	Menu.combo:MenuElement({id="useE1", name="Use E1", value=true})
	Menu.combo:MenuElement({id="useE2", name="Use E2", value=true})
	Menu.combo:MenuElement({id="useR", name="Use R", value=true})
	Menu.combo:MenuElement({id="rHP", name="Cast R if target HP% <=", value=40, min=1, max=100, identifier="%"})
	Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
	Menu.harass:MenuElement({id="useQ", name="Use Q", value=true})
	Menu.harass:MenuElement({id="useW", name="Use W", value=true})
	Menu.harass:MenuElement({id="mana", name="Min Mana %", value=40, min=0, max=100, identifier="%"})
	Menu:MenuElement({type = MENU, id = "clear", name = "Lane Clear"})
	Menu.clear:MenuElement({id="useQ", name="Use Q", value=true})
	Menu.clear:MenuElement({id="useW", name="Use W", value=true})
	Menu.clear:MenuElement({id="wCount", name="W min minions", value=3, min=0, max=10, identifier="minion/s"})
	Menu.clear:MenuElement({id="mana", name="Min Mana %", value=40, min=0, max=100, identifier="%"})
	Menu:MenuElement({type = MENU, id = "jclear", name = "Jungle Clear"})
	Menu.jclear:MenuElement({id="useQ", name="Use Q", value=true})
	Menu.jclear:MenuElement({id="useW", name="Use W", value=true})
	Menu.jclear:MenuElement({id="mana", name="Min Mana %", value=40, min=0, max=100, identifier="%"})
	Menu:MenuElement({type = MENU, id = "lasthit", name = "Last Hit"})
	Menu.lasthit:MenuElement({id="useQ", name="Use Q", value=true})
	Menu.lasthit:MenuElement({id="useW", name="Use W if out of AA range", value=true})
	Menu.lasthit:MenuElement({id="mana", name="Min Mana %", value=40, min=0, max=100, identifier="%"})
	Menu:MenuElement({type = MENU, id="pred", name="Prediction"})
	Menu.pred:MenuElement({id="hitchanceW", name="Hitchance W", value=1, drop={"Normal","High","Immobile"}})
	Menu.pred:MenuElement({id="hitchanceE", name="Hitchance E2", value=1, drop={"Normal","High","Immobile"}})
	Menu:MenuElement({type = MENU, id="wall", name="Wall System"})
	Menu.wall:MenuElement({id="enabled", name="Enable Wall E", value=true})
	Menu.wall:MenuElement({id="autoCombo", name="Auto E1 to Wall in Combo", value=true})
	Menu.wall:MenuElement({id="mode", name="Mode", value=3, drop={"Mouse","Target","Smart"}})
	Menu.wall:MenuElement({id="turretSafety", name="Avoid Enemy Turret (E)", value=true})
	Menu.wall:MenuElement({id="searchMax", name="Max Search Range", value=1200, min=400, max=2000, step=50})
	Menu.wall:MenuElement({id="angleStep", name="Angle Step", value=20, min=10, max=60, step=5})
	Menu:MenuElement({type=MENU, id="drawing", name="Drawing"})
	Menu.drawing:MenuElement({id="drawW", name="Draw W Range", value=false})
	Menu.drawing:MenuElement({id="drawE", name="Draw E Range", value=false})
	Menu.drawing:MenuElement({id="drawR", name="Draw R Range", value=false})
end

-- Basic dmg wrappers (fallback if DamageLib absent)
local function GetDmg(spell, target, stage)
	if type(_G.getdmg) == "function" then return _G.getdmg(spell, target, myHero, stage) end
	return 0
end

-- Post attack Q logic
local function ShouldUseQ(mode)
	if mode == "Combo" then return Menu and Menu.combo.useQ:Value() end
	if mode == "Harass" then return Menu and Menu.harass.useQ:Value() and PercentMP(myHero) >= Menu.harass.mana:Value() end
	if mode == "LaneClear" then return Menu and Menu.clear.useQ:Value() and PercentMP(myHero) >= Menu.clear.mana:Value() end
	if mode == "LastHit" then return Menu and Menu.lasthit.useQ:Value() and PercentMP(myHero) >= Menu.lasthit.mana:Value() end
	return false
end

local function HasBuff(unit, buff)
	for i=0, unit.buffCount do
		local b=unit:GetBuff(i)
		if b and b.name == buff and b.count>0 then return true end
	end
	return false
end

local IsCastingE = false
local function PostAttack_Q(target)
	if not Ready(_Q) or IsCastingE or (myHero.pathing and myHero.pathing.isDashing) then return end
	local mode = GetMode()
	if not ShouldUseQ(mode) then return end
	local qData = myHero:GetSpellData(_Q)
	if qData.name == "CamilleQ2" and not HasBuff(myHero, "camilleqprimingstart") then Control.CastSpell(HK_Q) return end
	if qData.name == "CamilleQ" and not HasBuff(myHero, "camilleqprimingstart") then Control.CastSpell(HK_Q) end
end

local function HookPostAttack()
	if _G.GOS and _G.GOS.Orbwalker and _G.GOS.Orbwalker.OnPostAttack then _G.GOS.Orbwalker:OnPostAttack(function(a) PostAttack_Q(a and (a.Target or a.target)) end) end
	if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.OnPostAttack then _G.SDK.Orbwalker:OnPostAttack(function(a) PostAttack_Q(a and (a.Target or a.target)) end) end
	if _G.Orbwalker and _G.Orbwalker.OnPostAttack then _G.Orbwalker:OnPostAttack(function(a) PostAttack_Q(a and (a.Target or a.target)) end) end
end
-- (Post-attack hook will be registered during Init)

-- Wall search utilities
local function Rotate(base,to,height,theta)
	local dx, dz = to.x-base.x, to.z-base.z
	local px = dx*math.cos(theta)-dz*math.sin(theta)
	local pz = dx*math.sin(theta)+dz*math.cos(theta)
	return Vector(base.x+px,height,base.z+pz)
end

local function FindBestWallPos(towards, searchMax, step, angleStep)
	local origin = Vector(myHero.pos)
	local tgt = towards or mousePos
	local height = myHero.pos.y
	for dist = 100, searchMax, step do
		local dir = origin:Extended(tgt, dist)
		for ang = angleStep, 360, angleStep do
			local test = Rotate(origin, dir, height, math.rad(ang))
			if MapPosition and MapPosition:inWall(test) then return test end
		end
	end
	return nil
end

local function FindNearestWallAround(center, maxR, radial, angleStep)
	if not center then return nil end
	local best, bestD
	for r = radial, maxR, radial do
		for a=0,360-angleStep, angleStep do
			local rad = math.rad(a)
			local test = Vector(center.x+math.cos(rad)*r, myHero.pos.y, center.z+math.sin(rad)*r)
			if MapPosition and MapPosition:inWall(test) then
				local d = center:DistanceTo(test)
				if not bestD or d < bestD then best, bestD = test, d end
			end
		end
	end
	return best
end

local function WallModePos(target)
	if not Menu then return mousePos end
	local m = Menu.wall.mode:Value()
	if m == 1 then return mousePos elseif m == 2 then return target and target.pos or mousePos end
	return target and target.pos or mousePos
end

local function TryE1(target)
	if not Menu or not Menu.wall.enabled:Value() or not Menu.combo.useE1:Value() or not Ready(_E) then return false end
	local sd = myHero:GetSpellData(_E).name
	if sd ~= "CamilleE" and sd ~= "CamilleEDash1" then return false end
	if target and IsValid(target) and myHero.pos:DistanceTo(target.pos) <= 350 then return false end
	local maxSearch = math.min(Menu.wall.searchMax:Value(), 800)
	local cast = target and FindNearestWallAround(target.pos, maxSearch, 40, Menu.wall.angleStep:Value()) or nil
	if not cast then cast = FindBestWallPos(WallModePos(target), maxSearch, 50, Menu.wall.angleStep:Value()) end
	if cast and myHero.pos:DistanceTo(cast) <= maxSearch then
		if Menu.wall.turretSafety:Value() and UnderTurret(cast) then return false end
		Control.CastSpell(HK_E, cast); return true
	end
	return false
end

local function CastE2(target)
	if not Menu or not Menu.combo.useE2:Value() or not Ready(_E) then return end
	if myHero:GetSpellData(_E).name ~= "CamilleEDash2" then return end
	if not target or not IsValid(target) then return end
	if DPReady() then
		local spell = DP.SpellPrediction({Type=DP.SPELLTYPE_LINE, Speed=1050+myHero.ms, Range=800, Delay=0, Radius=130, Collision=false})
		local res = spell:GetPrediction(target, myHero.pos)
		if res and res.CastPosition and res.HitChance and res.HitChance >= DP_HC(Menu.pred.hitchanceE:Value()) then
			local cp = Vector(res.CastPosition.x, myHero.pos.y, res.CastPosition.z)
			Control.CastSpell(HK_E, cp)
			return
		end
	end
	if myHero.pos:DistanceTo(target.pos) <= 820 then Control.CastSpell(HK_E, target.pos) end
end

local function CastW(target)
	if not Menu or not Menu.combo.useW:Value() or not Ready(_W) or not target or not IsValid(target) then return end
	if IsCastingE then return end
	if DPReady() then
		local spell = DP.SpellPrediction({Type=DP.SPELLTYPE_CONE, Speed=1750, Range=610, Delay=0.25, Radius=300, Collision=false})
		local res = spell:GetPrediction(target, myHero.pos)
		if res and res.CastPosition and res.HitChance and res.HitChance >= DP_HC(Menu.pred.hitchanceW:Value()) then
			local cp = Vector(res.CastPosition.x, myHero.pos.y, res.CastPosition.z)
			Control.CastSpell(HK_W, cp)
		end
	elseif myHero.pos:DistanceTo(target.pos) < 610 then
		Control.CastSpell(HK_W, target.pos)
	end
end

local function ComboDamageLethal(target)
	if type(_G.getdmg) ~= "function" then return false end
	local aa = (_G.getdmg("AA", target, myHero) * (3 + (Menu and Menu.combo.useAA:Value() or 0)))
	local q1 = _G.getdmg("Q", target, myHero, 1)
	local q2 = (q1*2 + _G.getdmg("AA", target, myHero)) - Q2TrueDamage()
	local w = _G.getdmg("W", target, myHero)
	local e = _G.getdmg("E", target, myHero)
	local r = _G.getdmg("R", target, myHero)
	return target.health < (aa + q1 + q2 + Q2TrueDamage() + w + e + r)
end

local function Combo()
	local target = GetTarget(1200)
	if not target or not IsValid(target) then return end
	CastE2(target)
	if IsCastingE then return end
	local dist = myHero.pos:DistanceTo(target.pos)
	if (not Ready(_W) or dist > 610) and dist > 350 then
		if Menu.wall.autoCombo:Value() then TryE1(target) else TryE1(target) end
	end
	if dist < (myHero.range + 50 + myHero.boundingRadius + target.boundingRadius) and not HasBuff(myHero,"camilleqprimingstart") and Menu.combo.useQ:Value() and Ready(_Q) then Control.CastSpell(HK_Q) end
	if dist < 610 and (ComboDamageLethal(target) or dist > 310) then CastW(target) end
	if dist < 475 and Menu.combo.useR:Value() and Ready(_R) then
		local hp = (target.health/target.maxHealth)*100
		if hp <= Menu.combo.rHP:Value() then Control.CastSpell(HK_R, target) end
	end
end

local function Harass()
	if PercentMP(myHero) < (Menu.harass.mana:Value()) then return end
	local target = GetTarget(700)
	if not target or not IsValid(target) then return end
	local dist = myHero.pos:DistanceTo(target.pos)
	if dist < (myHero.range + 50 + myHero.boundingRadius + target.boundingRadius) and not HasBuff(myHero,"camilleqprimingstart") and Menu.harass.useQ:Value() and Ready(_Q) then Control.CastSpell(HK_Q) end
	if dist > 310 and dist < 610 and Menu.harass.useW:Value() then CastW(target) end
end

local function LaneClear()
	if PercentMP(myHero) < Menu.clear.mana:Value() then return end
	if not (Menu.clear.useQ:Value() or Menu.clear.useW:Value()) then return end
	for i=1, Game.MinionCount() do
		local m = Game.Minion(i)
		if m and IsValid(m) and m.isEnemy and myHero.pos:DistanceTo(m.pos) < 700 then
			if Menu.clear.useW:Value() and Ready(_W) and DepressiveLib.GetMinionCount(400, m) >= Menu.clear.wCount:Value() then Control.CastSpell(HK_W, m.pos) end
			if Menu.clear.useQ:Value() and Ready(_Q) and not HasBuff(myHero,"camilleqprimingstart") and myHero.pos:DistanceTo(m.pos) < (myHero.range + 50 + myHero.boundingRadius + m.boundingRadius) then Control.CastSpell(HK_Q) end
		end
	end
end

local function JungleClear()
	if PercentMP(myHero) < Menu.jclear.mana:Value() then return end
	for i=1, Game.MinionCount() do
		local m=Game.Minion(i)
		if m and IsValid(m) and m.team==300 and myHero.pos:DistanceTo(m.pos) < 700 then
			if Menu.jclear.useW:Value() and Ready(_W) then Control.CastSpell(HK_W, m.pos) end
			if Menu.jclear.useQ:Value() and Ready(_Q) and not HasBuff(myHero,"camilleqprimingstart") and myHero.pos:DistanceTo(m.pos) < (myHero.range + 50 + myHero.boundingRadius + m.boundingRadius) then Control.CastSpell(HK_Q) end
		end
	end
end

local function LastHit()
	if PercentMP(myHero) < Menu.lasthit.mana:Value() then return end
	for i=1, Game.MinionCount() do
		local m=Game.Minion(i)
		if m and IsValid(m) and m.isEnemy and myHero.pos:DistanceTo(m.pos) < 700 then
			local qDmg = GetDmg("Q", m, 1) + GetDmg("AA", m)
			local wDmg = GetDmg("W", m)
			if Menu.lasthit.useQ:Value() and Ready(_Q) and not HasBuff(myHero,"camilleqprimingstart") and myHero.pos:DistanceTo(m.pos) < (myHero.range + 50 + myHero.boundingRadius + m.boundingRadius) and qDmg > m.health then Control.CastSpell(HK_Q) end
			if Menu.lasthit.useW:Value() and Ready(_W) and wDmg > m.health and myHero.pos:DistanceTo(m.pos) < 610 and myHero.pos:DistanceTo(m.pos) > 250 then Control.CastSpell(HK_W, m.pos) end
		end
	end
end

local function OnDraw()
	if not Menu or myHero.dead then return end
	if Menu.drawing.drawR:Value() and Ready(_R) and Draw and Draw.Circle then Draw.Circle(myHero.pos, 475, 1, Draw.Color(225,255,0,10)) end
	if Menu.drawing.drawE:Value() and Ready(_E) and Draw and Draw.Circle then Draw.Circle(myHero.pos, 900, 1, Draw.Color(225,255,125,10)) end
	if Menu.drawing.drawW:Value() and Ready(_W) and Draw and Draw.Circle then Draw.Circle(myHero.pos, 650, 1, Draw.Color(225,125,200,10)) end
end

local function OnTick()
	-- Movement control during dash/E
	if myHero:GetSpellData(_E).name == "CamilleEDash2" or (myHero.pathing and myHero.pathing.isDashing) then
		DepressiveLib.SetMovement(false); IsCastingE = true
	else
		DepressiveLib.SetMovement(true); IsCastingE = false
	end
	if DepressiveLib.MyHeroNotReady() then return end
	local mode = GetMode()
	if mode == "Combo" then Combo()
	elseif mode == "Harass" then Harass()
	elseif mode == "LaneClear" then LaneClear(); JungleClear()
	elseif mode == "LastHit" then LastHit() end
end
-- Exposed interface for Loader
function Camille:Init()
	LoadMenu()
	HookPostAttack()
	print(string.format("[DepressiveCamille] loaded (v%.2f | Lib %.2f)", self.__version, DepressiveLib.__version or 0))
end
function Camille:Tick() OnTick() end
function Camille:Draw() OnDraw() end
return Camille

