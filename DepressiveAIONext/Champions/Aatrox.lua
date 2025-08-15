if _G.__AATROX_CHAMPION_LOADED then return end
_G.__AATROX_CHAMPION_LOADED = true
_G.__AATROX_DEPRESSIVE_LOADED = true -- inform standalone script
local VERSION = "0.13"
-- ===================== BASIC UTILITIES ===================== --
local insert = table.insert

-- Fallback constants / references (align with other champion modules)
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local TEAM_ENEMY = (myHero.team == 100 and 200) or 100
local TEAM_JUNGLE = _G.TEAM_JUNGLE or 300
local MathHuge = MathHuge or math.huge
local lastQCastTime = 0
local W_WIDTH = 80
local nonCriticalNextTime = 0
local skipNonCritical = false

local function Now()
	return (Game.Timer and Game.Timer()) or os.clock()
end

-- Simple 2D helper for W collision (line segment from hero to cast position)
local function WMinionCollision(toPos)
	if not toPos or not toPos.x then return false end
	local ax, az = myHero.pos.x, myHero.pos.z
	local bx, bz = toPos.x, (toPos.z or toPos.y)
	local abx, abz = bx - ax, bz - az
	local abLenSqr = abx*abx + abz*abz
	if abLenSqr == 0 then return false end
	local rangeSqr = 825*825
	for i = 1, GameMinionCount() do
		local m = GameMinion(i)
		if m and m.team == TEAM_ENEMY and not m.dead and m.visible then
			local px, pz = m.pos.x, m.pos.z
			-- skip if beyond cast range in straight line significantly
			local apx, apz = px - ax, pz - az
			local t = (apx*abx + apz*abz)/abLenSqr
			if t > 0 and t < 1 then
				local projx = ax + abx * t
				local projz = az + abz * t
				local dx = px - projx
				local dz = pz - projz
				local distSqr = dx*dx + dz*dz
				if distSqr <= (W_WIDTH+35)*(W_WIDTH+35) then -- add small buffer for minion radius
					return true
				end
			end
		end
	end
	return false
end

-- Distance helpers (if not globally provided)
local function GetDistanceSqr(p1, p2)
	if not p1 or not p2 or not p1.x or not p2.x then return math.huge end
	local dx = p1.x - p2.x
	local dz = (p1.z or p1.y) - (p2.z or p2.y)
	return dx * dx + dz * dz
end

local function GetDistance(p1, p2)
	return math.sqrt(GetDistanceSqr(p1, p2))
end

-- Validation placed early so other helpers can use it
local function IsValidTarget(unit)
	return unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable
end

-- Enemy cache (refresh every 0.25s) to reduce per-tick hero iteration cost
local _EnemyCache = {time = 0, list = {}}
local function GetEnemyHeroes()
	local t = Game.Timer and Game.Timer() or os.clock()
	if t - _EnemyCache.time > 0.25 then
		local list = {}
		for i = 1, GameHeroCount() do
			local u = GameHero(i)
			if u and u.team ~= myHero.team and IsValidTarget(u) then list[#list+1] = u end
		end
		_EnemyCache.list = list
		_EnemyCache.time = t
	end
	return _EnemyCache.list
end

-- Spell readiness
local function Ready(slot)
	if not myHero or not myHero.GetSpellData then return false end
	local sd = myHero:GetSpellData(slot)
	if not sd or sd.level <= 0 then return false end
	return sd.currentCd == 0 and sd.mana <= myHero.mana and Game.CanUseSpell(slot) == 0
end

-- Environment check (chat, evade, death)
local function MyHeroNotReady()
	return myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading)
end

-- Basic target selector (closest valid in range)
local function GetTarget(range)
	local best, bestDist = nil, math.huge
	local enemies = GetEnemyHeroes()
	for i = 1, #enemies do
		local unit = enemies[i]
		local d = GetDistance(myHero.pos, unit.pos)
		if d < range and d < bestDist then best = unit; bestDist = d end
	end
	return best
end

local function GetMode()
	if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then
		local M = _G.SDK.Orbwalker.Modes
		if M and (M[_G.SDK.ORBWALKER_MODE_COMBO] or M.Combo) then return "Combo" end
		if M and (M[_G.SDK.ORBWALKER_MODE_HARASS] or M.Harass) then return "Harass" end
		if M and (M[_G.SDK.ORBWALKER_MODE_LANECLEAR] or M[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] or M.Clear or M.LaneClear) then return "Clear" end
		if M and (M[_G.SDK.ORBWALKER_MODE_FLEE] or M.Flee) then return "Flee" end
	end
	if _G.GOS and _G.GOS.GetMode then
		local m = (type(_G.GOS.GetMode) == "function" and _G.GOS.GetMode()) or nil
		if m == 1 then return "Combo" elseif m == 2 then return "Harass" elseif m == 3 then return "Clear" elseif m == 4 then return "Flee" end
	end
	if _G.Orbwalker and _G.Orbwalker.GetMode then
		local ok, m = pcall(function() return _G.Orbwalker:GetMode() end)
		if ok and m then return m end
	end
	return "None"
end

local function EnemiesInRange(range, from)
	local count = 0
	from = from or myHero.pos
	local r2 = range * range
	local enemies = GetEnemyHeroes()
	for i = 1, #enemies do
		local e = enemies[i]
		if IsValidTarget(e) and GetDistanceSqr(from, e.pos) <= r2 then
			count = count + 1
		end
	end
	return count
end

-- ===================== SPELL CONFIG ===================== --
local Q1_RANGE, Q2_RANGE, Q3_RANGE = 600, 450, 340 -- base cast ranges
local E_RANGE = 300 -- effective dash range (approximate)

-- Sweet spot windows (ideal target distance from Aatrox BEFORE casting)
local Q1_MIN, Q1_MAX = 525, 600          -- Try to hit with Q1 tip (optional)
local Q2_MIN, Q2_MAX = 370, 450          -- Q2 sweet spot band
local Q3_MAX = 340                       -- Q3 sweet spot (center)

-- Prediction data (same as original example for compatibility)
local QData = {Type = _G.SPELLTYPE_LINE, Delay = 0.6, Radius = 80, Range = 600, Speed = MathHuge, Collision = false}
local WData = {Type = _G.SPELLTYPE_LINE, Delay = 0.25, Radius = 80, Range = 825, Speed = 1800, Collision = true, MaxCollision = 0, CollisionTypes = {_G.COLLISION_MINION}}
local QspellData = {speed = MathHuge, range = 600, delay = 0.6, radius = 80, collision = {nil}, type = "linear"}
local WspellData = {speed = 1800, range = 825, delay = 0.25, radius = 80, collision = {"minion"}, type = "linear"}

-- ===================== MENU ===================== --
local Menu
local MENU_GUARD_KEY = "__AATROX_ADV_MENU"
function LoadScript()
	if _G[MENU_GUARD_KEY] and Menu then return end -- ya creado
	_G[MENU_GUARD_KEY] = true
	Menu = Menu or MenuElement({type = MENU, id = "Aatrox"..myHero.charName.."Adv", name = myHero.charName.." Advanced"})
	Menu:MenuElement({name = " ", drop = {"Version "..VERSION}})

	-- Combo
	Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
	Menu.Combo:MenuElement({id = "UseQ1", name = "Always use Q1", value = true})
	Menu.Combo:MenuElement({id = "Q1Tip", name = "Optimize Q1 tip (525-600 distance)", value = true})
	Menu.Combo:MenuElement({id = "UseQ2", name = "Use Q2", value = true})
	Menu.Combo:MenuElement({id = "UseQ3", name = "Use Q3", value = true})
	Menu.Combo:MenuElement({id = "EdgeQ2", name = "Prioritize Q2 edge (370-450)", value = true})
	Menu.Combo:MenuElement({id = "EdgeQ3", name = "Prioritize Q3 edge (<340)", value = true})
	Menu.Combo:MenuElement({id = "UseW", name = "Use W", value = true})
	Menu.Combo:MenuElement({id = "UseE", name = "Use E to reposition (pre-Q)", value = true})
	Menu.Combo:MenuElement({id = "QEHelper", name = "Q->E Helper (dash after Q cast)", value = true})
	Menu.Combo:MenuElement({id = "QEPhase", name = "Q->E Phases", value = 7, drop = {"Only Q1","Only Q2","Only Q3","Q1+Q2","Q2+Q3","Q1+Q3","All"}})
	Menu.Combo:MenuElement({id = "QEDelay", name = "Q->E Delay (ms)", value = 40, min = 0, max = 150, step = 5})
	Menu.Combo:MenuElement({id = "QEMargin", name = "Distance margin for adjust", value = 35, min = 10, max = 120, step = 5})
	Menu.Combo:MenuElement({id = "UseR", name = "Use R", value = true})
	Menu.Combo:MenuElement({id = "RHp", name = "R if HP% <", value = 50, min = 0, max = 100, identifier = "%"})
	Menu.Combo:MenuElement({id = "RCount", name = "R if X enemies in 600", value = 2, min = 1, max = 5})

	-- Lane Clear
	Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
	Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
	Menu.Clear:MenuElement({id = "UseW", name = "Use W", value = false})
	Menu.Clear:MenuElement({id = "UseE", name = "Use E helper", value = true})

	-- Jungle
	Menu:MenuElement({type = MENU, id = "Jungle", name = "JungleClear"})
	Menu.Jungle:MenuElement({id = "UseQ", name = "Use Q", value = true})
	Menu.Jungle:MenuElement({id = "UseW", name = "Use W", value = false})
	Menu.Jungle:MenuElement({id = "UseE", name = "Use E helper", value = true})

	-- Prediction (solo DepressivePrediction)
	Menu:MenuElement({type = MENU, id = "Pred", name = "Prediction"})
	Menu.Pred:MenuElement({name = " ", drop = {"Using only DepressivePrediction"}})
	Menu.Pred:MenuElement({id = "QHit", name = "Hitchance Q", value = 2, drop = {"Low","Normal", "High", "VeryHigh", "Immobile"}})
	Menu.Pred:MenuElement({id = "WHit", name = "Hitchance W", value = 2, drop = {"Low","Normal", "High", "VeryHigh", "Immobile"}})

	-- Drawings
	Menu:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
	Menu.Draw:MenuElement({id = "DrawQ", name = "Q sweet spot ranges", value = true})
	Menu.Draw:MenuElement({id = "DrawW", name = "W range", value = false})
	Menu.Draw:MenuElement({id = "DrawE", name = "E range", value = false})
	Menu.Draw:MenuElement({id = "EdgeDebug", name = "Edge/E debug", value = false})

	-- Performance (FPS optimization)
	Menu:MenuElement({type = MENU, id = "Perf", name = "Performance"})
	Menu.Perf:MenuElement({id = "LightMode", name = "Light Mode (fewer calculations)", value = false})
	Menu.Perf:MenuElement({id = "NonCriticalGap", name = "Non-critical interval (ms)", value = 65, min = 0, max = 250, step = 5})
	Menu.Perf:MenuElement({id = "SkipLaneClearEval", name = "Skip LaneClear E evaluation", value = false})
	Menu.Perf:MenuElement({id = "SkipStrictEdge", name = "Disable strict edge (add tolerance)", value = true})

	Callback.Add("Tick", OnTick)
	Callback.Add("Draw", OnDraw)
end

-- ===================== PREDICTION WRAPPERS ===================== --
local function DepressiveHitchanceOK(needed, got)
	-- Map indices: Low(1)=2, Normal(2)=3, High(3)=4, VeryHigh(4)=5, Immobile(5)=6 (library style)
	local map = {2,3,4,5,6}
	return (got or 0) >= (map[needed+1] or 3)
end

local function CastQPred(unit)
	local lib = _G.DepressivePrediction
	if not lib or not lib.SpellPrediction then
		return false
	end
	local ok, spell = pcall(function() return lib:SpellPrediction({
		Type = lib.SPELLTYPE_LINE,
		Speed = MathHuge,
		Range = 600,
		Delay = 0.6,
		Radius = 80,
		Collision = false
	}) end)
	if not ok or not spell then return false end
	pcall(function() spell:GetPrediction(unit, myHero) end)
	local needed = Menu and Menu.Pred and Menu.Pred.QHit:Value() or 1
	local hc = spell.HitChance or 3
	if spell.CanHit then
		local ok2, res = pcall(function() return spell:CanHit(hc) end)
		if ok2 and res then hc = spell.HitChance or hc end
	end
	if DepressiveHitchanceOK(needed, hc) then
		Control.CastSpell(HK_Q, (spell.CastPosition and spell.CastPosition) or unit.pos)
		return true
	end
	return false
end

local function CastWPred(unit)
	local lib = _G.DepressivePrediction
	if not lib or not lib.SpellPrediction then return false end
	local ok, spell = pcall(function() return lib:SpellPrediction({
		Type = lib.SPELLTYPE_LINE,
		Speed = 1800,
		Range = 825,
		Delay = 0.25,
		Radius = 80,
		Collision = true,
		CollisionTypes = {lib.COLLISION_MINION}
	}) end)
	if not ok or not spell then return false end
	pcall(function() spell:GetPrediction(unit, myHero) end)
	local needed = Menu and Menu.Pred and Menu.Pred.WHit:Value() or 1
	local hc = spell.HitChance or 3
	if DepressiveHitchanceOK(needed, hc) then
		local castPos = (spell.CastPosition and spell.CastPosition) or unit.pos
		if not WMinionCollision(castPos) then
			Control.CastSpell(HK_W, castPos)
			return true
		end
	end
	return false
end

-- ===================== Q LOGIC (EDGE PRIORITY) ===================== --
local function Phase()
	local name = myHero:GetSpellData(_Q).name
	if name == "AatroxQ" then return 1
	elseif name == "AatroxQ2" then return 2
	elseif name == "AatroxQ3" then return 3 end
	return 0
end

local function NeedReposition(dist, phase)
	if phase == 1 and Menu.Combo.Q1Tip:Value() then
		return dist < Q1_MIN or dist > Q1_MAX
	elseif phase == 2 and Menu.Combo.EdgeQ2:Value() then
		return dist < Q2_MIN or dist > Q2_MAX
	elseif phase == 3 and Menu.Combo.EdgeQ3:Value() then
		return dist > Q3_MAX
	end
	return false
end

local function DesiredDistance(phase)
	if phase == 1 then return (Q1_MIN + Q1_MAX) * 0.5
	elseif phase == 2 then return (Q2_MIN + Q2_MAX) * 0.5
	elseif phase == 3 then return math.min(Q3_MAX - 20, Q3_MAX) end
	return 0
end

-- Compute ideal hero position (after dash) to place target inside sweet spot edge for next Q segment
local function ComputeIdealEPos(target, phase, strict)
	-- Use sweet spot band (min,max) rather than exact distance
	local minB, maxB
	if phase == 1 then minB, maxB = Q1_MIN, Q1_MAX
	elseif phase == 2 then minB, maxB = Q2_MIN, Q2_MAX
	elseif phase == 3 then minB, maxB = 0, Q3_MAX -- Q3 only has an upper bound
	else return nil end
	local hPos = myHero.pos
	local tPos = target.pos
	local dir = (tPos - hPos):Normalized()
	if not dir or not dir.x then return nil end
	local currentDist = hPos:DistanceTo(tPos)
	local tol = strict and 0 or 10
	if Menu and Menu.Perf and Menu.Perf.LightMode:Value() then
		-- Mayor tolerancia en modo ligero
		tol = tol + 20
	end
	if Menu and Menu.Perf and Menu.Perf.SkipStrictEdge:Value() then
		-- Si usuario pide no estricto, añadir colchón adicional
		if strict then tol = tol + 15 end
	end
	if currentDist >= (minB - tol) and currentDist <= (maxB + tol) then return nil end
	if currentDist > maxB then
		local need = currentDist - maxB
		local step = math.min(need, E_RANGE)
		return hPos + dir * step
	end
	if minB > 0 and currentDist < minB then
		local need = minB - currentDist
		local step = math.min(need, E_RANGE)
		return hPos - dir * step
	end
	return nil
end

local function ComputeEPosition(target, phase)
	-- Legacy function now wraps precise ideal computation, falling back to previous behavior
	local hPos = myHero.pos
	local tPos = target.pos
	local dir = (tPos - hPos):Normalized()
	local dist = hPos:DistanceTo(tPos)
	local desired = DesiredDistance(phase)
	local ideal = ComputeIdealEPos(target, phase)
	if ideal then return ideal end
	-- fallback minimal adjust if ideal nil
	local dashRange = E_RANGE
	if dist < desired then
		return hPos - dir * math.min(dashRange, desired - dist)
	else
		return hPos + dir * math.min(dashRange, dist - desired)
	end
end

local function CastQSmart(target)
	local phase = Phase()
	if phase == 0 then return end
	local dist = myHero.pos:DistanceTo(target.pos)
	local preDist = dist -- original distance before casting Q
	local inRange = false
	if phase == 1 then inRange = dist <= Q1_RANGE
	elseif phase == 2 then inRange = dist <= 500 -- small extra margin for reposition
	elseif phase == 3 then inRange = dist <= 640 end

	-- Q->E logic: never use E before Q
	-- Allow Q if already in range or if we can gapclose with post-Q E
	local phaseRange = (phase == 1 and Q1_RANGE) or (phase == 2 and 500) or 640
	local canAttempt = inRange or (dist <= phaseRange + E_RANGE and Menu.Combo.QEHelper:Value() and Ready(_E))
	if not canAttempt then return end

	-- If not in range (dist > phaseRange) clamp cast position to max Q range
	local castPos = target.pos
	if not inRange then
		local dir = (target.pos - myHero.pos):Normalized()
		if dir and dir.x then
			-- clamp al borde del rango de la Q
			castPos = myHero.pos + dir * (phaseRange - 10)
		end
	end

	local casted = false
	if phase == 1 and Menu.Combo.UseQ1:Value() then
		if inRange then
			if not CastQPred(target) then Control.CastSpell(HK_Q, castPos) end
		else
			Control.CastSpell(HK_Q, castPos)
		end
		casted = true
	elseif phase == 2 and Menu.Combo.UseQ2:Value() then
		Control.CastSpell(HK_Q, castPos); casted = true
	elseif phase == 3 and Menu.Combo.UseQ3:Value() then
		Control.CastSpell(HK_Q, castPos); casted = true
	end
	if casted then
		local t = (Game.Timer and Game.Timer()) or os.clock()
		lastQCastTime = t
	end

	-- Q->E helper (solo después de Q). Gapclose si originalmente estaba fuera de rango (preDist > phaseRange)
	if casted and Menu.Combo.QEHelper:Value() then
		local phaseMask = Menu.Combo.QEPhase:Value()+1 -- convert 0-based to 1-based label choice
		local allow = false
		if phaseMask == 7 then allow = true -- All
		elseif phaseMask == 1 and phase == 1 then allow = true
		elseif phaseMask == 2 and phase == 2 then allow = true
		elseif phaseMask == 3 and phase == 3 then allow = true
		elseif phaseMask == 4 and (phase == 1 or phase == 2) then allow = true
		elseif phaseMask == 5 and (phase == 2 or phase == 3) then allow = true
		elseif phaseMask == 6 and (phase == 1 or phase == 3) then allow = true
		end
		-- Always attempt strict edge reposition; phase mask only controls pure gapclose
		-- Recalculate distance
		dist = myHero.pos:DistanceTo(target.pos)
		local useStrict = not (Menu.Perf and Menu.Perf.SkipStrictEdge:Value()) and not (Menu.Perf and Menu.Perf.LightMode:Value())
		local dashPos = (skipNonCritical and nil) or ComputeIdealEPos(target, phase, useStrict) -- si saltamos no crítico omitimos edge fino
		if not dashPos then
			-- If no edge is needed use phase mask to decide pure gapclose
			if allow and preDist > phaseRange then
				local dir = (target.pos - myHero.pos):Normalized()
				if dir and dir.x then
					local need = math.max(0, preDist - phaseRange + 35)
					dashPos = myHero.pos + dir * math.min(E_RANGE, need)
				end
			end
		end
		if not dashPos then return end
		local delaySec = (Menu.Combo.QEDelay:Value()/1000)
		local function castEDash()
			if Ready(_E) and dashPos then Control.CastSpell(HK_E, dashPos) end
		end
		if DelayAction then
			DelayAction(castEDash, delaySec)
		else
			local fireTime = os.clock() + delaySec
			local fired = false
			Callback.Add("Tick", function()
				if fired then return end
				if os.clock() >= fireTime then castEDash(); fired = true end
			end)
		end
	end
end

-- ===================== COMBO ===================== --
local function Combo()
	local target = GetTarget(1000)
	if not target or not IsValidTarget(target) then return end

	-- Q handling (highest prio)
	if Ready(_Q) then
		CastQSmart(target)
	end

	-- W (after Q1 or if Q on cd)
	if Menu.Combo.UseW:Value() and Ready(_W) and myHero.pos:DistanceTo(target.pos) <= 825 then
		local now = (Game.Timer and Game.Timer()) or os.clock()
		-- Permitir W si Q no ready, o ya pasó un pequeño retardo tras Q, o no estamos en Q1
		if not Ready(_Q) or Phase() ~= 1 or (now - lastQCastTime) > 0.15 then
			if not CastWPred(target) then
				if not WMinionCollision(target.pos) then
					Control.CastSpell(HK_W, target.pos) -- fallback directo si no bloquean minions
				end
			end
		end
	end

	-- R conditions
	if Menu.Combo.UseR:Value() and Ready(_R) then
		if myHero.health / myHero.maxHealth <= Menu.Combo.RHp:Value() / 100 then
			Control.CastSpell(HK_R)
		elseif EnemiesInRange(600, myHero.pos) >= Menu.Combo.RCount:Value() then
			Control.CastSpell(HK_R)
		end
	end
end

-- ===================== CLEAR / JUNGLE (simplified) ===================== --
local function ClearLike(sourceTeam, opts)
	for i = 1, GameMinionCount() do
		local m = GameMinion(i)
		if m and m.team == sourceTeam and not m.dead and myHero.pos:DistanceTo(m.pos) < 800 then
			if opts.UseQ and Ready(_Q) then
				Control.CastSpell(HK_Q, m.pos)
			end
			if opts.UseW and Ready(_W) then
				Control.CastSpell(HK_W, m.pos)
			end
		end
	end
end

local function LaneClear()
	if not Menu or not Menu.Clear then return end
	-- Smart E reposition: only if increases number of minions in Q1 band (throttled)
	if not (Menu.Perf and Menu.Perf.SkipLaneClearEval:Value()) and not skipNonCritical and Menu.Clear.UseE:Value() and Menu.Clear.UseQ:Value() and Ready(_E) and Ready(_Q) then
		local minions = {}
		for i = 1, GameMinionCount() do
			local m = GameMinion(i)
			if m and m.team == TEAM_ENEMY and not m.dead and m.visible and myHero.pos:DistanceTo(m.pos) <= Q1_RANGE + E_RANGE + 100 then
				minions[#minions+1] = m
			end
		end
		if #minions >= 2 then
			local sumx, sumz = 0,0
			for i=1,#minions do sumx = sumx + minions[i].pos.x; sumz = sumz + minions[i].pos.z end
			local center = {x = sumx/#minions, z = sumz/#minions}
			center.y = myHero.pos.y
			local function CountBand(pos)
				local c = 0
				for i=1,#minions do
					local d = pos:DistanceTo(minions[i].pos)
					if d >= Q1_MIN and d <= Q1_MAX then c = c + 1 end
				end
				return c
			end
			local currentCount = CountBand(myHero.pos)
			local toCenterDir = (Vector(center.x, myHero.pos.y, center.z) - myHero.pos):Normalized()
			if toCenterDir and toCenterDir.x then
				local centerVec = Vector(center.x, myHero.pos.y, center.z)
				local distCenter = myHero.pos:DistanceTo(centerVec)
				local candidatePos
				if distCenter > Q1_MAX then
					local need = distCenter - ((Q1_MIN + Q1_MAX)*0.5)
					local step = math.min(E_RANGE, need)
					candidatePos = myHero.pos + toCenterDir * step
				elseif distCenter < Q1_MIN then
					local need = ((Q1_MIN + Q1_MAX)*0.5) - distCenter
					local step = math.min(E_RANGE, need)
					candidatePos = myHero.pos - toCenterDir * step
				end
				if candidatePos then
					local candidateCount = CountBand(candidatePos)
					if candidateCount > currentCount then
						Control.CastSpell(HK_E, candidatePos)
						return -- wait next tick, then normal Q clear logic will run
					end
				end
			end
		end
	end
	-- After potential reposition, proceed with normal clear (E disabled here)
	ClearLike(TEAM_ENEMY, {UseQ = Menu.Clear.UseQ:Value(), UseW = Menu.Clear.UseW:Value(), UseE = false})
end

local function JungleClear()
	if not Menu or not Menu.Jungle then return end
	ClearLike(TEAM_JUNGLE, {UseQ = Menu.Jungle.UseQ:Value(), UseW = Menu.Jungle.UseW:Value(), UseE = Menu.Jungle.UseE:Value()})
end

-- ===================== TICK ===================== --
function OnTick()
	if not Menu then return end
	if myHero.dead or MyHeroNotReady() then return end
	-- Performance throttle for non-critical tasks
	local gapMs = (Menu.Perf and Menu.Perf.NonCriticalGap:Value()) or 0
	if gapMs > 0 then
		local now = Now()
		if now < nonCriticalNextTime then
			skipNonCritical = true
		else
			skipNonCritical = false
			nonCriticalNextTime = now + gapMs/1000
		end
	else
		skipNonCritical = false
	end
	_G.AatroxLightMode = Menu.Perf and Menu.Perf.LightMode:Value() or false
	local mode = GetMode()
	if mode == "Combo" then
		Combo()
	elseif mode == "Clear" then
		LaneClear(); JungleClear()
	end
end

-- ===================== DRAW ===================== --
function OnDraw()
	if not Menu then return end
	if myHero.dead then return end
	-- Simple & low contrast colors (alpha 70)
	local drawLibMode = (Draw and Draw.Circle and Draw.Color)
	if Menu.Draw.DrawQ:Value() and Ready(_Q) then
		if drawLibMode then
			Draw.Circle(myHero.pos, Q1_MAX, Draw.Color(70, 200, 200, 200)) -- outer reference
			Draw.Circle(myHero.pos, Q3_MAX, Draw.Color(60, 150, 150, 150)) -- inner sweet
		elseif DrawCircle and DrawColor then
			DrawCircle(myHero, Q1_MAX, 1, DrawColor(70, 200, 200, 200))
			DrawCircle(myHero, Q3_MAX, 1, DrawColor(60, 150, 150, 150))
		end
	end
	if Menu.Draw.DrawE:Value() and Ready(_E) then
		if drawLibMode then
			Draw.Circle(myHero.pos, E_RANGE, Draw.Color(55, 180, 180, 180))
		elseif DrawCircle and DrawColor then
			DrawCircle(myHero, E_RANGE, 1, DrawColor(55, 180, 180, 180))
		end
	end
	if Menu.Draw.DrawW:Value() and Ready(_W) then
		if drawLibMode then
			Draw.Circle(myHero.pos, 825, Draw.Color(40, 160, 160, 160))
		elseif DrawCircle and DrawColor then
			DrawCircle(myHero, 825, 1, DrawColor(40, 160, 160, 160))
		end
	end
	if Menu.Draw.EdgeDebug:Value() then
		local target = GetTarget(1000)
		if target then
			local phase = Phase()
			local ideal = ComputeIdealEPos(target, phase)
			if ideal then
				if drawLibMode then
					Draw.Circle(ideal, 35, Draw.Color(120, 80, 200, 200))
				elseif DrawCircle and DrawColor then
					DrawCircle(ideal, 35, 1, DrawColor(120, 80, 200, 200))
				end
			end
		end
	end
end

-- Auto-load if champion matches
if myHero.charName == "Aatrox" then
	if not _G.DepressivePrediction then pcall(function() require("DepressivePrediction") end) end
	-- Minimal fallback if missing
	if not _G.DepressivePrediction then
		_G.DepressivePrediction = {SPELLTYPE_LINE = 0, HITCHANCE_NORMAL = 3, SpellPrediction = function(self,data) return {HitChance=3, CastPosition=nil, GetPrediction=function(self2,t,s) self2.CastPosition=t.pos end} end}
	end
	LoadScript()
end

