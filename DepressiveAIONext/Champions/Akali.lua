local VERSION = "0.47"
if _G.__DEPRESSIVE_NEXT_AKALI_LOADED then return end
if myHero.charName ~= "Akali" then return end
_G.__DEPRESSIVE_NEXT_AKALI_LOADED = true

-- Prediction library load (DepressivePrediction)
local DepressivePrediction = require("DepressivePrediction")
if not DepressivePrediction then
    if print then print("[Akali] DepressivePrediction not found, using fallback") end
end

-- MapPosition (wall detection) assumed loaded by core; fallback attempt
if not MapPosition or not MapPosition.inWall then
    pcall(function() require("MapPositionGOS") end)
end

------------------------------------------------------------
-- UTILIDADES BÁSICAS
------------------------------------------------------------
local insert=table.insert
local GameHeroCount=Game.HeroCount
local GameHero=Game.Hero
local GameMinionCount=Game.MinionCount
local GameMinion=Game.Minion
local TEAM_ENEMY=(myHero.team==100 and 200) or 100
local TEAM_JUNGLE=_G.TEAM_JUNGLE or 300
local MathHuge=math.huge

local function IsValid(u) return u and u.valid and u.visible and not u.dead and u.isTargetable end
local function Distance(a,b) local dx=a.x-b.x; local dz=(a.z or a.y)-(b.z or b.y); return math.sqrt(dx*dx+dz*dz) end
local function DistanceSqr(a,b) local dx=a.x-b.x; local dz=(a.z or a.y)-(b.z or b.y); return dx*dx+dz*dz end

local _EnemyCache={t=0,list={}}
local function GetEnemyHeroes()
	local now=Game.Timer and Game.Timer() or os.clock()
	if now-_EnemyCache.t>0.25 then
		local L={}
		for i=1,GameHeroCount() do local h=GameHero(i); if h and h.team~=myHero.team and IsValid(h) then L[#L+1]=h end end
		_EnemyCache.list=L; _EnemyCache.t=now
	end
	return _EnemyCache.list
end

local function Ready(slot) local sd=myHero:GetSpellData(slot); return sd and sd.level>0 and sd.currentCd==0 and sd.mana<=myHero.mana and Game.CanUseSpell(slot)==0 end
-- Explicit second-cast E readiness (E2) checker
local function ReadyE2()
	local sd = myHero:GetSpellData(_E)
	if not sd or sd.level==0 then return false end
	-- During second cast window Akali E name changes to AkaliEb (common) and CanUseSpell(_E)==0
	if sd.name ~= "AkaliEb" then return false end
	if sd.currentCd>0 then return false end
	if Game.CanUseSpell(_E) ~= 0 then return false end
	return true
end
local function MyHeroNotReady() return myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) end

local function HasBuff(unit, name)
	for i=0, unit.buffCount do local b=unit:GetBuff(i); if b and b.name==name and b.count>0 then return true end end; return false
end

local function GetTarget(range)
	local best,bd=nil,1e9
	for _,e in ipairs(GetEnemyHeroes()) do local d=Distance(myHero.pos,e.pos); if d<range and d<bd then best=e; bd=d end end
	return best
end

local function EnemiesInRange(r,from) from=from or myHero.pos; local r2=r*r; local c=0; for _,e in ipairs(GetEnemyHeroes()) do if IsValid(e) and DistanceSqr(from,e.pos)<=r2 then c=c+1 end end return c end

local function GetMode()
	if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then local M=_G.SDK.Orbwalker.Modes; if M[_G.SDK.ORBWALKER_MODE_COMBO] or M.Combo then return "Combo" end; if M[_G.SDK.ORBWALKER_MODE_HARASS] or M.Harass then return "Harass" end; if M[_G.SDK.ORBWALKER_MODE_LANECLEAR] or M.Clear or M.LaneClear then return "Clear" end end
	if _G.GOS and _G.GOS.GetMode then local m=_G.GOS:GetMode(); if m==1 then return "Combo" elseif m==2 then return "Harass" elseif m==3 then return "Clear" end end
	return "None"
end

------------------------------------------------------------
-- CONSTANTES DE HABILIDADES
------------------------------------------------------------
local Q_RANGE=500
local W_RANGE=250
local E_RANGE=650
local R1_RANGE=750
local R2_RANGE=750
local PASSIVE_MIN_OUT=390   -- distancia mínima desde el objetivo para activar círculo
local PASSIVE_IDEAL=500     -- distancia objetivo para reposicionamiento
local PASSIVE_RING_WIDTH=40

-- Force DepressivePrediction usage (mandatory)
if not _G.DepressivePrediction then
	local ok = pcall(function() require("DepressivePrediction") end)
	if not ok then print("[DepressiveAkali] DepressivePrediction missing. Disable script."); return end
end
local function HitchanceOK(needed, got)
	-- needed (menu index 0..4) => permissive thresholds; library hitchance often 0-6
	-- 0 Low -> >=2, 1 Normal -> >=3, 2 High -> >=4, 3 VeryHigh -> >=5, 4 Immobile -> >=6
	local reqMap={2,3,4,5,6}
	return (got or 0) >= (reqMap[(needed or 0)+1] or 3)
end
local function GetEPred(target)
	local lib=_G.DepressivePrediction; if not lib or not lib.SpellPrediction then return nil end
	local ok, spell=pcall(function() return lib:SpellPrediction({Type=lib.SPELLTYPE_LINE, Speed=1800, Range=E_RANGE, Delay=0.4, Radius=55, Collision=true, CollisionTypes={lib.COLLISION_MINION}}) end)
	if not ok or not spell then return nil end
	pcall(function() spell:GetPrediction(target, myHero) end)
	return spell
end

-- Simple manual collision check (in case prediction library returns high HC but path blocked) 
local function LineSegmentDistanceSquared(p, a, b)
	-- p, a, b: vectors with x,z
	local abx, abz = b.x-a.x, (b.z or b.y)-(a.z or a.y)
	local apx, apz = p.x-a.x, (p.z or p.y)-(a.z or a.y)
	local ab2 = abx*abx+abz*abz; if ab2==0 then return apx*apx+apz*apz end
	local t = (apx*abx + apz*abz)/ab2; if t<0 then t=0 elseif t>1 then t=1 end
	local cx = a.x + abx*t; local cz = (a.z or a.y) + abz*t
	local dx, dz = p.x-cx, (p.z or p.y)-cz
	return dx*dx+dz*dz
end

local function EPathBlocked(castPos)
	if not castPos then return false end
	if not Menu or not Menu.Pred or not Menu.Pred.EBlockMinions or not Menu.Pred.EBlockMinions:Value() then return false end
	local from = myHero.pos
	local rad = 65 -- a bit bigger than spell radius for safety
	local radsq = rad*rad
	for i=1,GameMinionCount() do
		local m=GameMinion(i)
		if m and m.team==TEAM_ENEMY and IsValid(m) and Distance(from, m.pos) < E_RANGE+200 then
			local dsq = LineSegmentDistanceSquared(m.pos, from, castPos)
			if dsq < radsq then return true end
		end
	end
	return false
end
local function CastEPred(target)
	if not Ready(_E) or not target or not IsValid(target) then return false end
	if Distance(myHero.pos,target.pos) > E_RANGE + 100 then return false end
	local spell = GetEPred(target); if not spell then return false end
	local needed = (Menu and Menu.Pred and Menu.Pred.EHit and Menu.Pred.EHit:Value()) or 2
	-- Force prediction refresh
	pcall(function() spell:GetPrediction(target, myHero) end)
	local hc = spell.HitChance or 0
	if spell.CanHit then pcall(function() if spell:CanHit(hc) then hc = spell.HitChance or hc end end) end
	local ok = HitchanceOK(needed, hc)
	if ok then
		local castPos = spell.CastPosition or target.pos
		if not EPathBlocked(castPos) then
			Control.CastSpell(HK_E, castPos)
			if Menu and Menu.Misc and Menu.Misc.Debug:Value() then print(string.format("[Akali] Cast E pred HC=%s needed=%s", tostring(hc), tostring(needed))) end
			return true
		else
			if Menu and Menu.Misc and Menu.Misc.Debug:Value() then print("[Akali] Blocked E due to minion collision path") end
		end
	end
	-- Close range fallback: if target very close, fire anyway at current pos (reduces missed combos)
	if Distance(myHero.pos,target.pos) < 350 and not EPathBlocked(target.pos) then
		Control.CastSpell(HK_E, target.pos)
		if Menu and Menu.Misc and Menu.Misc.Debug:Value() then print(string.format("[Akali] Cast E fallback close (HC=%s needed=%s)", tostring(hc), tostring(needed))) end
		return true
	end
	if Menu and Menu.Misc and Menu.Misc.Debug:Value() then print(string.format("[Akali] Skip E HC=%s needed=%s dist=%.1f", tostring(hc), tostring(needed), Distance(myHero.pos,target.pos))) end
	return false
end

------------------------------------------------------------
-- CÁLCULOS DE DAÑO SIMPLIFICADOS
------------------------------------------------------------
local function BaseAP() return myHero.ap or myHero.totalDamage*0 end
local function PhysDmg(source,target,raw) -- naive armor calc
	local armor=target.armor or 0; local mod=100/(100+math.max(0,armor)); return raw*mod end
local function MagicDmg(source,target,raw)
	local mr=target.magicResist or 0; local mod=100/(100+math.max(0,mr)); return raw*mod end
local function QDamage(target)
	if _G.getdmg then return _G.getdmg("Q",target,myHero) end
	local lvl=myHero:GetSpellData(_Q).level; if lvl==0 then return 0 end
	local qTable = {30,55,80,105,130}
	local base = (qTable[lvl] or 0) + 0.65*BaseAP(); return MagicDmg(myHero,target,base) end
local function EDamage(target)
	if _G.getdmg then return _G.getdmg("E",target,myHero) end
	local lvl=myHero:GetSpellData(_E).level; if lvl==0 then return 0 end
	local eTable = {30,55,80,105,130}
	local base = (eTable[lvl] or 0) + 0.35*BaseAP(); return MagicDmg(myHero,target,base) end
local function R1Damage(target)
	if _G.getdmg then return _G.getdmg("R",target,myHero) end -- treat same
	local lvl=myHero:GetSpellData(_R).level; if lvl==0 then return 0 end
	local r1Table = {125,225,325}
	local base = (r1Table[lvl] or 0) + 0.5*BaseAP(); return MagicDmg(myHero,target,base) end
local function R2Damage(target)
	local lvl=myHero:GetSpellData(_R).level; if lvl==0 then return 0 end
	local missing = 1 - (target.health/target.maxHealth)
	local r2Table = {75,145,215}
	local base = (r2Table[lvl] or 0) + 0.3*BaseAP()
	local scale = (missing<0.07) and 1 or (missing<0.70 and (1+0.0286*(missing*100)) or 3)
	return MagicDmg(myHero,target, base*scale)
end
local function PassiveAADamage(target)
	-- Approx: extra magic scaling 0.6 AP + bonus AD; simplified
	local bonusAD=(myHero.totalDamage or 0)-(myHero.baseDamage or 0)
	local raw=(myHero.totalDamage or 60)+(0.6*BaseAP())+0.5*bonusAD
	return PhysDmg(myHero,target,raw)
end

local function FullComboDamage(target)
	local dmg=0
	if Ready(_Q) then dmg=dmg+QDamage(target) end
	if Ready(_E) then dmg=dmg+EDamage(target) end
	if Ready(_R) then dmg=dmg+R1Damage(target)+R2Damage(target) end
	dmg=dmg+PassiveAADamage(target)
	return dmg
end

------------------------------------------------------------
-- (Passive helper removed)
local lastHitTime=0
local lastAbilityToProc=nil

-- Passive gate override logic
local function PassiveGateAllows(spellKey, target)
	if not HasBuff(myHero, "AkaliPWeapon") then return true end
	if not Menu or not Menu.Combo then return false end
	-- R2 execute allowance
	if spellKey=="R2" and Menu.Combo.AllowR2Passive and Menu.Combo.AllowR2Passive:Value() then
		if target and IsValid(target) and R2Damage(target) >= target.health*0.55 then return true end
	end
	-- E2 allowance if it secures kill (E + R2 combined)
	if spellKey=="E2" and Menu.Combo.AllowE2Passive and Menu.Combo.AllowE2Passive:Value() then
		if target and IsValid(target) then
			local potential = EDamage(target) + R2Damage(target)
			if potential >= target.health then return true end
		end
	end
	return false
end

------------------------------------------------------------
-- MENU (English)
------------------------------------------------------------
local Menu
local function LoadMenu()
	Menu=MenuElement({type=MENU, id="DepressiveAkali"..myHero.charName, name="Depressive - Akali"})
	Menu:MenuElement({name=" ", drop={"Version "..VERSION}})
	Menu:MenuElement({type=MENU,id="Combo",name="Combo"})
	Menu.Combo:MenuElement({id="UseQ", name="Use Q", value=true})
	Menu.Combo:MenuElement({id="UseW", name="Use W defensively (enemy count)", value=true})
	Menu.Combo:MenuElement({id="WCount", name="Min enemies for W", value=2, min=1,max=5,step=1})
	Menu.Combo:MenuElement({id="UseE", name="Use E", value=true})
	Menu.Combo:MenuElement({id="UseR1", name="Use R1 engage (kill potential)", value=true})
	Menu.Combo:MenuElement({id="UseR2", name="Use R2 execute", value=true})
	Menu.Combo:MenuElement({id="R1ECombo", name="Enable R1->E gap combo", value=true})
	Menu.Combo:MenuElement({id="EHitFollowR", name="Min E hitchance after R1", value=2, drop={"Low","Normal","High","VeryHigh","Immobile"}})
	Menu.Combo:MenuElement({id="R1OnEMark", name="Use R1 if target has E mark", value=true})
	Menu.Combo:MenuElement({id="R2OnEMarkKill", name="Use R2 if (E+R2) kills marked", value=true})
	-- Passive helper menu removed
	Menu.Combo:MenuElement({id="R2Threshold", name="R2 if HP% <", value=45,min=0,max=100,identifier="%"})
	Menu.Combo:MenuElement({id="R1MinRange", name="Min R1 distance (avoid too close)", value=150,min=0,max=400,step=10})
	Menu.Combo:MenuElement({id="WEnergy", name="Use W if energy% <", value=50,min=0,max=100,identifier="%"})
	Menu.Combo:MenuElement({id="AllowR2Passive", name="Allow R2 with passive ready (execute)", value=true})
	Menu.Combo:MenuElement({id="AllowE2Passive", name="Allow E2 with passive ready if kill", value=true})
	Menu.Combo:MenuElement({id="MinEnergyBurst", name="Min energy% for full burst", value=20,min=0,max=100,identifier="%"})
	Menu.Combo:MenuElement({id="UseR1GapIfEOut", name="Use R1 gapclose if E out of range", value=true})
	Menu.Combo:MenuElement({id="AvoidR1NoKill", name="Avoid R1 if low kill chance", value=true})
	-- E2 safety / logic refinement
	Menu.Combo:MenuElement({id="E2KillOnly", name="Auto E2 only if potential kill", value=false})
	Menu.Combo:MenuElement({id="E2MaxEnemies", name="Max enemies around target for E2", value=2,min=1,max=5,step=1})
	Menu.Combo:MenuElement({id="E2MinHP", name="Min my HP% to auto E2", value=25,min=0,max=100,identifier="%"})
	Menu.Combo:MenuElement({id="E2UnderTurret", name="Allow E2 under enemy turret", value=false})

	Menu:MenuElement({type=MENU,id="Harass",name="Harass"})
	Menu.Harass:MenuElement({id="UseQ", name="Use Q", value=true})
	-- Passive helper options removed from Harass

	Menu:MenuElement({type=MENU,id="Clear",name="Lane Clear"})
	Menu.Clear:MenuElement({id="UseQ", name="Use Q", value=true})
	Menu.Clear:MenuElement({id="ManaQ", name="Min energy%", value=35,min=0,max=100})

	Menu:MenuElement({type=MENU,id="Jungle",name="Jungle"})
	Menu.Jungle:MenuElement({id="UseQ", name="Use Q", value=true})
	Menu.Jungle:MenuElement({id="ManaQ", name="Min energy%", value=20,min=0,max=100})

	Menu:MenuElement({type=MENU,id="KS",name="KillSteal"})
	Menu.KS:MenuElement({id="UseQ", name="Use Q", value=true})
	Menu.KS:MenuElement({id="UseE", name="Use E", value=true})
	Menu.KS:MenuElement({id="UseR", name="Use R2", value=true})

	Menu:MenuElement({type=MENU,id="Pred",name="Prediction"})
	Menu.Pred:MenuElement({id="EHit", name="Hitchance E", value=2, drop={"Low","Normal","High","VeryHigh","Immobile"}})
	Menu.Pred:MenuElement({id="EBlockMinions", name="Block E if minion collision", value=true})

	Menu:MenuElement({type=MENU,id="Draw",name="Drawings"})
	Menu.Draw:MenuElement({id="Ranges", name="Draw Q/E/R ranges", value=true})
	Menu.Draw:MenuElement({id="Passive", name="Draw passive ring", value=true})
	Menu.Draw:MenuElement({id="DamageText", name="Draw combo damage", value=true})
	Menu.Draw:MenuElement({id="ComboPlan", name="Draw R1->E plan", value=true})

	Menu:MenuElement({type=MENU,id="Misc",name="Misc"})
	Menu.Misc:MenuElement({id="Debug", name="Debug prints", value=false})
end

------------------------------------------------------------
-- LÓGICAS
------------------------------------------------------------
local function CastQ(target, modeMenu)
	if not Ready(_Q) or not target or not IsValid(target) then return false end
	if not PassiveGateAllows("Q", target) then return false end
	if Distance(myHero.pos,target.pos) > Q_RANGE then return false end
	-- SkipQPassive removed
	Control.CastSpell(HK_Q, target.pos)
	lastHitTime=os.clock(); lastAbilityToProc="Q"; return true
end

local function CastW(target)
	if not Ready(_W) or not Menu or not Menu.Combo or not Menu.Combo.UseW or not Menu.Combo.UseW:Value() then return false end
	if HasBuff(myHero, "AkaliW") or HasBuff(myHero, "AkaliSmokeBomb") then return false end
	local energyPerc = (myHero.mana/myHero.maxMana)*100
	local count = EnemiesInRange(500,myHero.pos)
	-- Energy based usage
	if energyPerc < Menu.Combo.WEnergy:Value() and count >=1 then
		Control.CastSpell(HK_W, myHero.pos)
		if Menu.Misc and Menu.Misc.Debug:Value() then print(string.format("[Akali] Cast W (energy %.1f%%)", energyPerc)) end
		return true
	end
	if count >= Menu.Combo.WCount:Value() then
		Control.CastSpell(HK_W, myHero.pos)
		if Menu.Misc and Menu.Misc.Debug:Value() then print("[Akali] Cast W count="..count) end
		return true
	end
	if count >=1 and myHero.health/myHero.maxHealth < 0.35 then
		Control.CastSpell(HK_W, myHero.pos)
		if Menu.Misc and Menu.Misc.Debug:Value() then print("[Akali] Cast W low HP fallback") end
		return true
	end
	return false
end

local function CastE(target)
	if not Menu or not Menu.Combo or not Menu.Combo.UseE or not Menu.Combo.UseE:Value() or not Ready(_E) or not target then return false end
	if not PassiveGateAllows("E", target) then return false end
	if CastEPred(target) then lastHitTime=os.clock(); lastAbilityToProc="E"; return true end
	return false
end

-- E2 (second cast) auto logic
local function EnemyTurretInRange(pos, range)
    if not _G.GameTurretCount then return false end -- environment may not expose
    if not Game.TurretCount or not Game.Turret then return false end
    for i=1,Game.TurretCount() do
        local t = Game.Turret(i)
        if t and t.team~=myHero.team and IsValid(t) then
            if Distance(pos, t.pos) <= range then return true end
        end
    end
    return false
end

local function CastE2(target)
	if not target or not IsValid(target) then return false end
	if not Menu or not Menu.Combo or not Menu.Combo.UseE or not Menu.Combo.UseE:Value() then return false end
	if not PassiveGateAllows("E2", target) then return false end
	local sd = myHero:GetSpellData(_E)
	-- Use explicit ReadyE2() to ensure cooldown truly available
	if ReadyE2() and HasBuff(target, "AkaliEMis") then
		local d = Distance(myHero.pos,target.pos)
		-- SAFETY CONDITIONS
		local myHPPerc = (myHero.health/myHero.maxHealth)*100
		local enemiesAround = EnemiesInRange(600, target.pos)
		local allowTurret = Menu.Combo.E2UnderTurret and Menu.Combo.E2UnderTurret:Value()
		local underEnemyTurret = (not allowTurret) and EnemyTurretInRange(target.pos, 800)
		if underEnemyTurret then
			if Menu and Menu.Misc and Menu.Misc.Debug:Value() then print("[Akali] Block E2 (enemy turret)") end
			return false
		end
		if enemiesAround > (Menu.Combo.E2MaxEnemies and Menu.Combo.E2MaxEnemies:Value() or 2) then
			if Menu and Menu.Misc and Menu.Misc.Debug:Value() then print("[Akali] Block E2 (too many enemies)" ) end
			return false
		end
		if myHPPerc < (Menu.Combo.E2MinHP and Menu.Combo.E2MinHP:Value() or 20) then
			if Menu and Menu.Misc and Menu.Misc.Debug:Value() then print("[Akali] Block E2 (low HP)" ) end
			return false
		end
		local potential = EDamage(target) + (Ready(_Q) and QDamage(target) or 0) + (Ready(_R) and R2Damage(target) or 0)
		if Menu.Combo.E2KillOnly and Menu.Combo.E2KillOnly:Value() and potential < target.health then
			if Menu and Menu.Misc and Menu.Misc.Debug:Value() then print("[Akali] Block E2 (no kill potential)" ) end
			return false
		end
		-- Cast from farther distance (only wait if very close to avoid waste). Use threshold 220 dynamic: ensure we don't instantly E2 if already melee unless kill potential
		local distanceGate = 220
		if potential >= target.health then distanceGate = 120 end -- allow earlier finish if lethal
		if d > distanceGate or d > PASSIVE_MIN_OUT then
			Control.CastSpell(HK_E, target.pos)
			lastHitTime=os.clock(); lastAbilityToProc="E2"
			-- Removed forced auto-attack to avoid mouse/orbwalker conflicts
			if Menu and Menu.Misc and Menu.Misc.Debug:Value() then print("[Akali] Cast E2 at distance "..string.format("%.1f",d)) end
			return true
		end
	end
	return false
end

local pendingR1E={active=false,target=nil,time=0}
local function CastR(target)
	if not Ready(_R) or not IsValid(target) then return false end
	local sd=myHero:GetSpellData(_R)
	local name=sd.name
	if name=="AkaliR" and Menu.Combo.UseR1:Value() then
		if not Menu or not Menu.Combo or not Menu.Combo.UseR1 then return false end
		if not PassiveGateAllows("R1", target) then return false end
		local d=Distance(myHero.pos,target.pos)
		if d < R1_RANGE and (not Menu or not Menu.Combo or not Menu.Combo.R1MinRange or d > Menu.Combo.R1MinRange:Value()) then
			-- Always allow engage now (user request: cast R even if not killable)
			local engage = true
			-- Prioritize R->E if E is ready
			if Ready(_E) then
				Control.CastSpell(HK_R, target.pos)
				pendingR1E.active=true; pendingR1E.target=target; pendingR1E.time=(Game.Timer and Game.Timer()) or os.clock()
				lastHitTime=os.clock(); lastAbilityToProc="R"; return true
			end
			-- Gapclose even if E not ready
			if Menu and Menu.Combo and Menu.Combo.R1ECombo and Menu.Combo.R1ECombo:Value() and d>E_RANGE then
				Control.CastSpell(HK_R, target.pos)
				pendingR1E.active=true; pendingR1E.target=target; pendingR1E.time=(Game.Timer and Game.Timer()) or os.clock()
				lastHitTime=os.clock(); lastAbilityToProc="R"; return true
			end
			-- Standard cast inside E range
			if d<=E_RANGE then
				Control.CastSpell(HK_R, target.pos)
				if Ready(_E) then
					pendingR1E.active=true; pendingR1E.target=target; pendingR1E.time=(Game.Timer and Game.Timer()) or os.clock()
				end
				lastHitTime=os.clock(); lastAbilityToProc="R"; return true
			end
		end
	elseif name=="AkaliRb" and Menu and Menu.Combo and Menu.Combo.UseR2 and Menu.Combo.UseR2:Value() then
		local hpPerc=target.health/target.maxHealth*100
		if not PassiveGateAllows("R2", target) then return false end
		if (Menu and Menu.Combo and Menu.Combo.R2Threshold and hpPerc <= Menu.Combo.R2Threshold:Value()) or R2Damage(target) >= target.health then
			if Distance(myHero.pos,target.pos) <= R2_RANGE then Control.CastSpell(HK_R, target.pos); return true end
		elseif Menu and Menu.Combo and Menu.Combo.R2OnEMarkKill and Menu.Combo.R2OnEMarkKill:Value() and HasBuff(target, "AkaliEMis") then
			local potential = EDamage(target)+R2Damage(target)
			if potential >= target.health and Distance(myHero.pos,target.pos) <= R2_RANGE then Control.CastSpell(HK_R, target.pos); return true end
		end
	end
	return false
end

------------------------------------------------------------
-- COMBO / HARASS / CLEAR
------------------------------------------------------------
local function Combo()
	local t=GetTarget(1500); if not t then return end
	CastW(t)
	-- If both R1 and E ready, prioritize R->E chain
	if Ready(_R) and myHero:GetSpellData(_R).name=="AkaliR" and Ready(_E) then
		CastR(t) -- schedules E
	else
		-- Normal engage logic
		if Ready(_E) then CastE(t) end
		if Ready(_R) and myHero:GetSpellData(_R).name=="AkaliR" and Menu and Menu.Combo and Menu.Combo.R1OnEMark and Menu.Combo.R1OnEMark:Value() and HasBuff(t,"AkaliEMis") then
			CastR(t)
		end
	end
	-- E2 attempt
	CastE2(t)
	-- Second pass R (R2 or leftover R1 case)
	CastR(t)
	CastQ(t, Menu.Combo)
end

local function Harass()
	local t=GetTarget(900); if not t then return end
	CastQ(t, Menu.Harass)
end

local function LaneClear()
	if not Menu.Clear.UseQ:Value() or not Ready(_Q) then return end
	if (myHero.mana/myHero.maxMana)*100 < Menu.Clear.ManaQ:Value() then return end
	for i=1,GameMinionCount() do
		local m=GameMinion(i)
		if m and m.team==TEAM_ENEMY and not m.dead and Distance(myHero.pos,m.pos)<=Q_RANGE then
			Control.CastSpell(HK_Q,m.pos); return
		end
	end
end

local function JungleClear()
	if not Menu.Jungle.UseQ:Value() or not Ready(_Q) then return end
	if (myHero.mana/myHero.maxMana)*100 < Menu.Jungle.ManaQ:Value() then return end
	for i=1,GameMinionCount() do
		local m=GameMinion(i)
		if m and m.team==TEAM_JUNGLE and not m.dead and Distance(myHero.pos,m.pos)<=Q_RANGE then
			Control.CastSpell(HK_Q,m.pos); return
		end
	end
end

------------------------------------------------------------
-- KILL STEAL
------------------------------------------------------------
local function KillSteal()
	for _,e in ipairs(GetEnemyHeroes()) do
		if IsValid(e) then
			if Menu.KS.UseQ:Value() and Ready(_Q) and Distance(myHero.pos,e.pos)<=Q_RANGE and QDamage(e) >= e.health then
				Control.CastSpell(HK_Q,e.pos); return end
			if Menu.KS.UseE:Value() and Ready(_E) and Distance(myHero.pos,e.pos)<=E_RANGE and EDamage(e) >= e.health then
				CastEPred(e); return end
			if Menu.KS.UseR:Value() and Ready(_R) and myHero:GetSpellData(_R).name=="AkaliRb" and Distance(myHero.pos,e.pos)<=R2_RANGE and R2Damage(e)>=e.health then
				Control.CastSpell(HK_R,e.pos); return end
		end
	end
end

------------------------------------------------------------
-- TICK
------------------------------------------------------------
local function OnTick()
	if not Menu or MyHeroNotReady() then return end
	if pendingR1E.active then
		local now=(Game.Timer and Game.Timer()) or os.clock()
		if now - pendingR1E.time > 0.15 then
			if pendingR1E.target and IsValid(pendingR1E.target) and Ready(_E) then
				CastEPred(pendingR1E.target)
			end
			pendingR1E.active=false
		end
	end
	-- Global E2 attempt (outside combo ordering) in case mark appears slightly later
	local tE2 = GetTarget(1500)
	if tE2 then CastE2(tE2) end
	local mode=GetMode()
	if mode=="Combo" then Combo() elseif mode=="Harass" then Harass() elseif mode=="Clear" then LaneClear(); JungleClear() end
	KillSteal()
end

------------------------------------------------------------
-- DRAW
------------------------------------------------------------
local function OnDraw()
	if not Menu or myHero.dead then return end
	if Menu.Draw.Ranges:Value() then
		if Ready(_Q) then Draw.Circle(myHero.pos,Q_RANGE,Draw.Color(55,120,255,120)) end
		if Ready(_E) then Draw.Circle(myHero.pos,E_RANGE,Draw.Color(55,255,120,120)) end
		if Ready(_R) then Draw.Circle(myHero.pos,R1_RANGE,Draw.Color(55,200,200,90)) end
	end
	-- Passive drawing removed
	if Menu.Draw.DamageText:Value() then
		local t=GetTarget(1200)
		if t then
			local dmg=FullComboDamage(t)
			local txt = (dmg>=t.health) and "Full Combo = KILL" or string.format("Full Combo: %.0f / %.0f", dmg, t.health)
			local p=t.pos:To2D(); if p then Draw.Text(txt, 16, p.x-40, p.y-15, Draw.Color(255,255,255,0)) end
		end
	end
	if Menu.Draw.ComboPlan and Menu.Draw.ComboPlan:Value() and pendingR1E.active and pendingR1E.target and IsValid(pendingR1E.target) then
		Draw.Circle(pendingR1E.target.pos, 85, Draw.Color(80,255,50,50))
	end
end

------------------------------------------------------------
-- LOAD
------------------------------------------------------------
LoadMenu()
Callback.Add("Tick", OnTick)
Callback.Add("Draw", OnDraw)

print("[DepressiveAIONext] Akali loaded - Version " .. VERSION)

