-- DepressiveAIONext Riven
local VERSION = "1.0"
if _G.__DEPRESSIVE_NEXT_RIVEN_LOADED then return end
_G.__DEPRESSIVE_NEXT_RIVEN_LOADED = true

local SDK = _G.SDK
local Orb = SDK and SDK.Orbwalker

-- Only proceed for Riven
if not (myHero and myHero.charName == "Riven") then return end

require "DamageLib"

-- Global burst target lock
lockedBurstTarget = lockedBurstTarget or nil

-- Modes
local function Mode()
	if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then
		return _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] and "Combo"
			or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] and "Harass"
			or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] and "LaneClear"
			or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] and "JungleClear"
			or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] and "LastHit"
			or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] and "Flee" or nil
	elseif _G.PremiumOrbwalker then
		return _G.PremiumOrbwalker:GetMode()
	end
	return nil
end

-- Helpers
local function Ready(slot)
	local s = myHero:GetSpellData(slot)
	return s and s.level > 0 and s.currentCd == 0 and Game.CanUseSpell(slot) == 0
end

local function Valid(u)
	return u and u.valid and not u.dead and u.isTargetable and u.visible
end

local function Distance(a, b)
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx*dx + dz*dz)
end

local function GetTarget(range)
	if _G.SDK and _G.SDK.TargetSelector then
		return _G.SDK.TargetSelector:GetTarget(range or 800, _G.SDK.DAMAGE_TYPE_PHYSICAL)
	end
	-- Fallback scan
	local best, bd = nil, 1e9
	for i = 1, Game.HeroCount() do
		local e = Game.Hero(i)
		if e and e.team ~= myHero.team and Valid(e) then
			local d = Distance(e.pos, myHero.pos)
			if d <= (range or 800) and d < bd then best, bd = e, d end
		end
	end
	return best
end

-- Closest enemy to myHero (valid + targetable + visible)
local function GetClosestEnemy()
	local best, bd = nil, math.huge
	for i = 1, Game.HeroCount() do
		local hero = Game.Hero(i)
		if hero and hero.team ~= myHero.team and Valid(hero) then
			local d = Distance(myHero.pos, hero.pos)
			if d < bd then
				best = hero
				bd = d
			end
		end
	end
	return best
end

-- Closest enemy to mouse for manual lock
local function GetClosestEnemyToMouse()
	local m = mousePos or myHero.pos
	local best, bd = nil, 1e9
	for i = 1, Game.HeroCount() do
		local e = Game.Hero(i)
		if e and e.team ~= myHero.team and Valid(e) then
			local d = Distance(e.pos, m)
			if d < bd then best, bd = e, d end
		end
	end
	return best
end

-- Orbwalker control helpers (optional)
local function SetMovement(b)
	if _G.SDK and _G.SDK.Orbwalker then _G.SDK.Orbwalker:SetMovement(b) end
end
local function SetAttack(b)
	if _G.SDK and _G.SDK.Orbwalker then _G.SDK.Orbwalker:SetAttack(b) end
end

-- R state helpers
local function RIsWindSlash()
	local data = myHero:GetSpellData(_R)
	return data and data.name == "RivenIzunaBlade"
end

-- Q Cancel state
local lastQCancel = 0
-- Anti-spam / throttle state
local attackIssuedCombo = false    -- only one Control.Attack per combo/burst sequence
local attackIssuedCancel = false   -- only one Control.Attack per cancel sequence
local qCancelMoved = false         -- only one Control.Move per cancel (QCancel)
local fleeEUsed = false            -- gate E in Flee per tick
local fleeMoveUsed = false         -- gate Move in Flee per tick
local zJumpMoveIssued = false      -- gate Move(IN) once during walljump lock
local zCursorLocked = false        -- gate SetCursorPos(IN) once during walljump lock
local lastStickMoveAt = 0          -- throttle stick-to-target move spam

local function SafeAttackCombo(target)
	if not target or not Valid(target) then return end
	if attackIssuedCombo then return end
	Control.Attack(target)
	attackIssuedCombo = true
end

local function SafeAttackCancel(target)
	if not target or not Valid(target) then return end
	if attackIssuedCancel then return end
	Control.Attack(target)
	attackIssuedCancel = true
end

if _G.DepressiveAIONext_Riven_Menu then _G.DepressiveAIONext_Riven_Menu:Remove() end
local Menu = MenuElement({type = MENU, id = "DepressiveAIONext_Riven", name = "Depressive - Riven"})
_G.DepressiveAIONext_Riven_Menu = Menu

Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
Menu.Combo:MenuElement({id = "useQ", name = "Use Q", value = true})
Menu.Combo:MenuElement({id = "useW", name = "Use W", value = true})
Menu.Combo:MenuElement({id = "useE", name = "Use E", value = true})
Menu.Combo:MenuElement({id = "useR1", name = "Use R1 (activate)", value = true})
Menu.Combo:MenuElement({id = "useR2", name = "Use R2 (cast)", value = true})
Menu.Combo:MenuElement({id = "r2Hp", name = "R2 if target HP% <", value = 30, min = 5, max = 60, step = 5})
Menu.Combo:MenuElement({id = "useItems", name = "Use active items before abilities", value = true})
Menu.Combo:MenuElement({id = "burstKey", name = "Burst Combo", key = string.byte("G")})
Menu.Combo:MenuElement({id = "lockTargetKey", name = "Lock burst target", key = string.byte("H")})
-- Timing tweak: delay W after Flash to ensure position update
Menu.Combo:MenuElement({id = "wFlashDelay", name = "W after Flash delay (ms)", value = 70, min = 0, max = 200, step = 5})

Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
Menu.Harass:MenuElement({id = "useQ", name = "Use Q", value = true})
Menu.Harass:MenuElement({id = "useE", name = "Use E to gapclose", value = false})
Menu.Harass:MenuElement({id = "useW", name = "Use W if close", value = false})

Menu:MenuElement({type = MENU, id = "Clear", name = "Lane/Jungle"})
Menu.Clear:MenuElement({id = "useQ", name = "Use Q (weave)", value = false})

Menu:MenuElement({type = MENU, id = "Cancel", name = "Q Cancel"})
Menu.Cancel:MenuElement({id = "respectOrb", name = "Respect orbwalker cancel", value = true})
Menu.Cancel:MenuElement({id = "custom", name = "Custom Q cancel (fallback)", value = true})
Menu.Cancel:MenuElement({id = "forceOverride", name = "Force cancel even if OW has cancel", value = false})
Menu.Cancel:MenuElement({id = "q1Delay", name = "Q1 cancel delay (ms)", value = 60, min = 60, max = 260, step = 5})
Menu.Cancel:MenuElement({id = "q2Delay", name = "Q2 cancel delay (ms)", value = 60, min = 60, max = 300, step = 5})
Menu.Cancel:MenuElement({id = "q3Delay", name = "Q3 cancel delay (ms)", value = 60, min = 80, max = 340, step = 5})
Menu.Cancel:MenuElement({id = "onlyPostAA", name = "Only cast Q after basic attack", value = true})
Menu.Cancel:MenuElement({id = "clickNearTarget", name = "Move next to target for cancel", value = true})
Menu.Cancel:MenuElement({id = "controlOrb", name = "Temporarily disable orb during cancel", value = true})
Menu.Cancel:MenuElement({id = "fastWeave", name = "Fast AA-Q backstep weave", value = true})
Menu.Cancel:MenuElement({id = "fastQDelay", name = "Q after AA delay (ms)", value = 30, min = 0, max = 120, step = 5})
Menu.Cancel:MenuElement({id = "backStepDist", name = "Backstep distance", value = 120, min = 60, max = 220, step = 5})
Menu.Cancel:MenuElement({id = "backStepHold", name = "Hold backstep (ms)", value = 40, min = 0, max = 120, step = 5})
Menu.Cancel:MenuElement({id = "restoreOrb", name = "Restore orb after (ms)", value = 220, min = 80, max = 400, step = 10})
local qStage, lastQTime = 0, 0

Menu:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
Menu.Draw:MenuElement({id = "ranges", name = "Draw ranges", value = true})

-- Damage / Killability menu
Menu:MenuElement({type = MENU, id = "Damage", name = "Damage / Killability"})
Menu.Damage:MenuElement({id = "show", name = "Show killable text", value = true})
Menu.Damage:MenuElement({id = "useIgnite", name = "Include Ignite damage", value = true})
Menu.Damage:MenuElement({id = "includeItems", name = "Include active item (Hydra/Tiamat) damage", value = true})
Menu.Damage:MenuElement({id = "aaCountCombo", name = "Extra AA in normal combo", value = 1, min = 0, max = 4, step = 1})
Menu.Damage:MenuElement({id = "aaCountBurst", name = "Extra AA in burst combo", value = 1, min = 0, max = 4, step = 1})
Menu.Damage:MenuElement({id = "showValues", name = "Show numeric damage values", value = false})


-- Flee / Walljump (Q3) menu
Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
Menu.Flee:MenuElement({id = "spotRadius", name = "Spot activation radius", value = 80, min = 40, max = 200, step = 5})
-- Special first-spot walljump key (Z)
Menu.Flee:MenuElement({id = "firstJumpKey", name = "First spot jump (Z)", key = string.byte("Z")})

-- Walljump pairs (IN -> OUT) management
Menu:MenuElement({type = MENU, id = "Jumps", name = "Walljump Spots"})
Menu.Jumps:MenuElement({id = "useForZ", name = "Use active jump for Z", value = true})
Menu.Jumps:MenuElement({id = "draw", name = "Draw jump pairs", value = true})

-- Casting helpers
-- Smart combo targeting and active items
local lastComboTarget = nil
local function InComboMode()
	return Mode() == "Combo"
end

-- Smart targeting removed: always use automatic selector

local ActiveItemIds = {
	[3077] = true,  -- Tiamat
	[6698] = true,  -- Profane Hydra (newer)
	[3074] = true,  -- Ravenous Hydra
	[3748] = true,  -- Titanic Hydra
}

local ItemHK = {
	[6] = HK_ITEM_1,
	[7] = HK_ITEM_2,
	[8] = HK_ITEM_3,
	[9] = HK_ITEM_4,
	[10] = HK_ITEM_5,
	[11] = HK_ITEM_6,
	[12] = HK_ITEM_7,
}

-- Forward declare spell cast helpers so burst combo (defined earlier) captures locals not globals
local CastQ, CastW, CastE, CastR

-- Burst helpers
local function DebugPrintBurst(msg) end -- debug disabled

local function GetFlashSlotHK()
	local s4 = myHero:GetSpellData(4)
	if s4 and s4.name and s4.name:lower():find("flash") then return 4, HK_SUMMONER_1 end
	local s5 = myHero:GetSpellData(5)
	if s5 and s5.name and s5.name:lower():find("flash") then return 5, HK_SUMMONER_2 end
	return nil, nil
end

local function ReadyFlash()
	local slot, hk = GetFlashSlotHK()
	if not slot then return false, nil end
	local s = myHero:GetSpellData(slot)
	local ok = s and s.level > 0 and s.currentCd == 0 and Game.CanUseSpell(slot) == 0
	return ok, hk
end

local function HasReadyHydra()
	for slot = 6, 12 do
		local sd = myHero:GetSpellData(slot)
		if sd and sd.level and sd.level > 0 and sd.currentCd == 0 then
			local id = (myHero:GetItemData(slot) and myHero:GetItemData(slot).itemID) or 0
			if id == 3077 or id == 3074 or id == 3748 or id == 6698 then
				return true
			end
		end
	end
	return false
end

local function CastHydraNow(target)
	for slot = 6, 12 do
		local sd = myHero:GetSpellData(slot)
		if sd and sd.level and sd.level > 0 and sd.currentCd == 0 then
			local data = myHero:GetItemData(slot)
			local id = data and data.itemID or 0
			if id == 3077 or id == 3074 or id == 3748 or id == 6698 then
				local hk = ItemHK[slot]
				if hk then Control.CastSpell(hk) end
			end
		end
	end
end

local function QCancelBurst(target)
	if Menu.Cancel and Menu.Cancel.fastWeave and Menu.Cancel.fastWeave:Value() then
		-- perform a small backstep similar to fast weave
		local distBack = Menu.Cancel.backStepDist and Menu.Cancel.backStepDist:Value() or 120
		local backDir
		if target and Valid(target) then backDir = (myHero.pos - target.pos) else backDir = (myHero.pos - (mousePos or myHero.pos)) end
		if backDir and backDir.Len and backDir:Len() > 0 then backDir = backDir:Normalized() else backDir = Vector(0,0,0) end
		-- allow only one move per cancel
		if not qCancelMoved then
			Control.Move(myHero.pos + backDir * distBack)
			qCancelMoved = true
		end
	else
		local st = NextQStage()
		DoQCancel(target, st)
	end
end

local burstActive = false
local BURST_RANGE = 650
local function StartBurstCombo()
	if burstActive then return end
	-- Require a locked target
	local t = lockedBurstTarget
	if not t or not Valid(t) then
		-- removed debug print: target invalid
		burstActive = false
		return
	end

	-- Respect burst maximum range
	if Distance(myHero.pos, t.pos) > BURST_RANGE then
		burstActive = false
		return
	end

	local needE = Menu.Combo.useE and Menu.Combo.useE:Value()
	local needR1 = Menu.Combo.useR1 and Menu.Combo.useR1:Value()
	local needW = Menu.Combo.useW and Menu.Combo.useW:Value()
	local needR2 = Menu.Combo.useR2 and Menu.Combo.useR2:Value()
	local needQ = Menu.Combo.useQ and Menu.Combo.useQ:Value()
	local needHydra = Menu.Combo.useItems and Menu.Combo.useItems:Value()

	if needE and not Ready(_E) then burstActive = false; return end
	if needR1 and not Ready(_R) then burstActive = false; return end
	if needW and not Ready(_W) then burstActive = false; return end
	local flashReady, flashHK = ReadyFlash(); if not flashReady then burstActive = false; return end
	if needQ and not Ready(_Q) then burstActive = false; return end

	-- Begin sequence
		burstActive = true
		local orbDisabledDuringBurst = false
		if Menu.Cancel and Menu.Cancel.controlOrb and Menu.Cancel.controlOrb:Value() then
			SetMovement(false); SetAttack(false)
			orbDisabledDuringBurst = true
		end

	-- Step 1: E (dash toward target)
	if needE then
		local dir = (t.pos - myHero.pos)
		if dir and dir.Len and dir:Len() > 0 then dir = dir:Normalized() else dir = Vector(0,0,0) end
		CastE(myHero.pos + dir * 300)
	end

	-- Step 2: R1 (activate)
	local r1CastAt = nil
	DelayAction(function()
		if needR1 and Ready(_R) and not RIsWindSlash() then CastR(); r1CastAt = Game.Timer() end
	end, 0.05)

	-- Step 3 moved: W will be cast immediately after FLASH

	-- Track burst start time and install a watchdog to ensure cleanup
	local burstStart = Game.Timer()
	DelayAction(function()
		if burstActive then burstActive = false; if Menu.Cancel and Menu.Cancel.controlOrb and Menu.Cancel.controlOrb:Value() then SetMovement(true); SetAttack(true) end end
	end, 1.5)
	local burstStart = Game.Timer()

	-- Step 4: FLASH to target, then immediately W
	DelayAction(function()
		local flashOK, hk = ReadyFlash()
		if not flashOK then burstActive = false; if Menu.Cancel.controlOrb:Value() then SetMovement(true); SetAttack(true) end; return end
		if not Valid(t) then burstActive = false; if Menu.Cancel.controlOrb:Value() then SetMovement(true); SetAttack(true) end; return end
		-- Recalculate direction & distance for precise positioning
		local curDist = Distance(myHero.pos, t.pos)
		local dir = (t.pos - myHero.pos)
		if dir and dir.Len and dir:Len() > 0 then dir = dir:Normalized() else dir = Vector(0,0,0) end
		-- Compute desired Flash destination to end ~50 units from target (within W)
		local flashRange = 395
		local targetOffset = 50
		local travel = math.min(flashRange, math.max(0, curDist - targetOffset))
		local desired = myHero.pos + dir * travel
		Control.CastSpell(hk, desired)
		local predicted = math.max(0, curDist - travel)
		-- removed debug: flash distances
		-- Attempt W after a configurable delay so myHero.pos updates after Flash
		local wDelayMs = (Menu.Combo and Menu.Combo.wFlashDelay and Menu.Combo.wFlashDelay:Value()) or 70
		local totalDelay = (wDelayMs + (Game.Latency() or 0)) / 1000
		-- removed debug: schedule W
		DelayAction(function()
			if needW and Valid(t) then
				local d = Distance(myHero.pos, t.pos)
				-- removed debug: post-flash distance and W attempt
				if Ready(_W) then
					if d <= 260 then
							CastW();
							-- Q inmediatamente tras W antes de los intentos de R2
							DelayAction(function()
								if Valid(t) and Ready(_Q) then CastQ(); QCancelBurst(t); end
							end, 0.15)
						-- Schedule R2 after W with reliability: attempt loop to wait for WindSlash
						if needR2 then
							local r2Done = false
							local maxAttempts = 10
							local baseDelay = 0.15 -- first attempt after W
							local interval = 0.10 -- 100ms between attempts
							local function finalizeAfterR2Success()
								-- Cadena de acciones con 50ms entre pasos: AA -> Hydra -> Q -> Restore -> End
								DelayAction(function()
									-- Paso 1: Auto-attack
									if Valid(t) then SafeAttackCombo(t) end
									-- Paso 2: Hydra tras 50ms
									DelayAction(function()
										if needHydra and HasReadyHydra() and Valid(t) then CastHydraNow(t) end
										-- Paso 3: Q tras 180ms (delay aumentado)
										DelayAction(function()
											if needQ and Ready(_Q) and Valid(t) then CastQ(); QCancelBurst(t) end
											-- Paso 4: Restaurar orb y finalizar tras delay de menú
											local restoreMs = (Menu.Cancel and Menu.Cancel.restoreOrb and Menu.Cancel.restoreOrb:Value()) or 220
											-- removed debug: restoring orbwalker
											DelayAction(function()
												SetMovement(true); SetAttack(true); burstActive = false;
											end, restoreMs/1000)
										end, 0.32)
									end, 0.05)
								end, 0.05)
							end

							local function finalizeAfterR2Fail()
								-- Mantener lógica anterior para fallo (sin AA forzado)
								if needHydra and HasReadyHydra() then CastHydraNow(t) end
								DelayAction(function()
									if needQ and Ready(_Q) then CastQ(); QCancelBurst(t) end
									if Menu.Cancel and Menu.Cancel.controlOrb and Menu.Cancel.controlOrb:Value() then
										local restoreMs = Menu.Cancel.restoreOrb and Menu.Cancel.restoreOrb:Value() or 220
										DelayAction(function() SetMovement(true); SetAttack(true); burstActive = false; end, (restoreMs/1000))
									else
										burstActive = false; print("[Burst] Combo terminado")
									end
								end, 0.05)
							end
							local function tryR2(i)
								if r2Done then return end
								if not Valid(t) then return end
								local readyR = Ready(_R)
								local wind = RIsWindSlash()
								local dist = Distance(myHero.pos, t.pos)
                                
									if readyR and wind and dist <= 600 then
									-- Preparar posición precisa para R2
									local castPos = t.pos
									if t.GetPrediction then
										local pred = t:GetPrediction(0.25)
										if pred and pred.x then castPos = pred end
									end
									castPos = Vector(castPos.x, castPos.y, castPos.z) -- forzar nuevo vector
									-- Verificación final de validez antes de castear
										if not Valid(t) then finalizeAfterR2Fail(); return end
									-- Asegurar que el orbwalker siga deshabilitado durante el cast
									SetMovement(false); SetAttack(false)
									-- Fijar objetivo una sola vez (evitar spam); cursor se ajusta justo antes del cast
									SafeAttackCombo(t)
									local beforeCd = myHero:GetSpellData(_R).currentCd or 0
									-- Esperar 50ms y luego castear R2 sin posición
									DelayAction(function()
										SetMovement(false); SetAttack(false)
										-- Reajustar cursor justo antes del cast para asegurar dirección exacta hacia el objetivo
										local aimPos = castPos
										if Valid(t) then
											local dir = (t.pos - myHero.pos)
											if dir and dir.Len and dir:Len() > 0 then
												dir = dir:Normalized()
												-- Apuntar un poco por detrás del objetivo para centrar el cono
												local overshoot = math.min(100, Distance(myHero.pos, t.pos) * 0.1)
												aimPos = Vector(t.pos.x + dir.x * overshoot, t.pos.y, t.pos.z + dir.z * overshoot)
											else
												aimPos = t.pos
											end
										end
										pcall(function() Control.SetCursorPos(aimPos) end)
										Control.CastSpell(HK_R)
										-- Confirmar si el cast se aplicó (CD cambia) tras pequeño retraso
										DelayAction(function()
											local afterCd = myHero:GetSpellData(_R).currentCd or 0
											if afterCd == beforeCd then finalizeAfterR2Success() else finalizeAfterR2Success() end
										end, 0.06)
										r2Done = true
									end, 0.05)
									return
								end
										if i == maxAttempts then finalizeAfterR2Fail() end
							end
							for attempt = 1, maxAttempts do
								local off = baseDelay + (attempt-1) * interval
								DelayAction(function() tryR2(attempt) end, off)
							end
						end
					else
						-- removed debug: W out of range
						-- Fallback cleanup if W didn't cast
						DelayAction(function()
							if Menu.Cancel and Menu.Cancel.controlOrb and Menu.Cancel.controlOrb:Value() then SetMovement(true); SetAttack(true) end
							burstActive = false;
						end, 0.1)
					end
				else
					-- removed debug: W not ready
					DelayAction(function()
						if Menu.Cancel and Menu.Cancel.controlOrb and Menu.Cancel.controlOrb:Value() then SetMovement(true); SetAttack(true) end
						burstActive = false;
					end, 0.1)
				end
			elseif needW then
				-- removed debug: W omitted invalid target
				DelayAction(function()
					if Menu.Cancel and Menu.Cancel.controlOrb and Menu.Cancel.controlOrb:Value() then SetMovement(true); SetAttack(true) end
					burstActive = false;
				end, 0.12)
			end
		end, totalDelay)
	end, 0.12)

	-- Step 5: Auto-attack (issue shortly after flash; adjust if already in AA range earlier)
	DelayAction(function()
		if Valid(t) then SafeAttackCombo(t) end
	end, 0.20)

	-- If R2 is not desired, still proceed with Hydra -> Q finishing sequence
	if not needR2 then
		DelayAction(function()
			if needHydra then CastHydraNow(t); print("[Burst] Hydra lanzada (sin R2)") end
			DelayAction(function()
				if needQ and Ready(_Q) then CastQ(); QCancelBurst(t); print("[Burst] Q lanzada (sin R2)") end
				if Menu.Cancel and Menu.Cancel.controlOrb and Menu.Cancel.controlOrb:Value() then
					local restoreMs = Menu.Cancel.restoreOrb and Menu.Cancel.restoreOrb:Value() or 220
					DelayAction(function() SetMovement(true); SetAttack(true) end, (restoreMs/1000))
				end
				burstActive = false; print("[Burst] Combo terminado")
			end, 0.05)
		end, 0.32)
		return
	end

	-- Step 6: R2 is now handled immediately after W in the Flash block to ensure correct ordering
end

local function UseActiveItems(target)
	if not InComboMode() then return end
	if not (Menu.Combo.useItems and Menu.Combo.useItems:Value()) then return end
	for slot = 6, 12 do
		local sd = myHero:GetSpellData(slot)
		if sd and sd.level and sd.level > 0 and sd.currentCd == 0 then
			local data = myHero:GetItemData(slot)
			local id = data and data.itemID or 0
			if ActiveItemIds[id] then
				local hk = ItemHK[slot]
				if hk then
					-- Try targeted cast for 6696 (if present); hydras are self-cast
					if id == 6696 and target and Valid(target) and Distance(myHero.pos, target.pos) <= 550 then
						Control.CastSpell(hk, target)
					else
						Control.CastSpell(hk)
					end
				end
			end
		end
	end
end

function CastQ()
	if InComboMode() then UseActiveItems(lastComboTarget) end
	Control.CastSpell(HK_Q)
end

function CastW()
	if InComboMode() then UseActiveItems(lastComboTarget) end
	Control.CastSpell(HK_W)
end

function CastE(pos)
	if InComboMode() then UseActiveItems(lastComboTarget) end
	Control.CastSpell(HK_E, pos)
end

function CastR(pos)
	if InComboMode() then UseActiveItems(lastComboTarget) end
	if pos then Control.CastSpell(HK_R, pos) else Control.CastSpell(HK_R) end
end

-- Q cancel: Attack then tiny move after delay (unless orbwalker already cancels)
local function ShouldRespectOrbCancel()
	if not Menu.Cancel.respectOrb:Value() then return false end
	if Menu.Cancel.forceOverride:Value() then return false end
	local ok, res = pcall(function()
		return Orb and Orb.Menu and Orb.Menu.General and ((Orb.Menu.General.CancelQ and Orb.Menu.General.CancelQ:Value()) or (Orb.Menu.General.AttackReset and Orb.Menu.General.AttackReset:Value()))
	end)
	return ok and res
end

local function NextQStage()
    local now = Game.Timer()
    if now - (lastQTime or 0) > 3.0 then
        qStage = 0
    end
    qStage = (qStage % 3) + 1
    lastQTime = now
    return qStage
end

local function DoQCancel(target, stage)
	if not Menu.Cancel.custom:Value() then return end
	-- Suppress legacy cancel if fast weave active
	if Menu.Cancel.fastWeave and Menu.Cancel.fastWeave:Value() then return end
	if ShouldRespectOrbCancel() then return end
	local now = Game.Timer()
	if now - lastQCancel < 0.06 then return end
	lastQCancel = now
	attackIssuedCancel = false
	qCancelMoved = false
	if target and Valid(target) then SafeAttackCancel(target) end
	-- Optionally pause orbwalker during cancel window (like reference script)
	if Menu.Cancel.controlOrb:Value() then SetMovement(false); SetAttack(false) end
	local s = stage or qStage or 1
	local delayMs = (s == 1 and Menu.Cancel.q1Delay:Value()) or (s == 2 and Menu.Cancel.q2Delay:Value()) or Menu.Cancel.q3Delay:Value()
	local delay = (delayMs + (Game.Latency() or 0)) / 1000
	DelayAction(function()
		local movePos = nil
		if Menu.Cancel.clickNearTarget:Value() and target and Valid(target) then
			-- Click next to the target: a small offset from target toward our hero
			local dir = (myHero.pos - target.pos)
			if dir:Len() and dir:Len() > 0 then
				dir = dir:Normalized()
				local offset = (target.boundingRadius or 45) + (myHero.boundingRadius or 35) * 0.9
				movePos = target.pos + dir * offset
			end
		end
		if not movePos then
			-- Fallback: tiny back step (legacy style)
			local back = Vector(myHero.pos)
			if back and back.Normalized then
				local vec = back:Normalized() * -((myHero.boundingRadius or 35) * 1.1)
				movePos = vec
			else
				movePos = mousePos or myHero.pos
			end
		end
		if not qCancelMoved then
			Control.Move(movePos)
			qCancelMoved = true
		end
		-- Re-enable orbwalker shortly after
		if Menu.Cancel.controlOrb:Value() then
			DelayAction(function() SetMovement(true); SetAttack(true) end, 0.3)
		end
	end, delay)
end

-- Legacy flee walljump data removed (using new JumpSpots system)
-- Removed debug key tracking
local function GetQAmmo()
	local sd = myHero:GetSpellData(_Q)
	return sd and sd.ammo or 0
end

local function Flee()
	-- Generic flee with E towards cursor
	local cur = mousePos or myHero.pos
	fleeMoveUsed = false
	fleeEUsed = false
	if Ready(_E) and not fleeEUsed then
		local dir = (Vector(cur) - myHero.pos)
		if dir:Len() > 0 then
			dir = dir:Normalized()
			local ePos = myHero.pos + dir * 300
			CastE(ePos)
			fleeEUsed = true
		end
	end
	if not fleeMoveUsed then
		Control.Move(cur)
		fleeMoveUsed = true
	end
end

-- Dedicated first-spot (5434,2358) -> jump direction (5936,2372) with Z key
-- Jump spot pairs: IN -> OUT. Easy to extend by adding more entries.
-- Example structure for manual edits:
-- JumpSpots = {
--   { IN = {x=5434, z=2358}, OUT = {x=5936, z=2372} },
--   { IN = {x=xxxx, z=zzzz}, OUT = {x=xxxx, z=zzzz} },
-- }
local JumpSpots = {
	{ IN = {x = 5438, z = 2356}, OUT = {x = 5898, z = 2367} },
	{ IN = {x = 6336, z = 3578}, OUT = {x = 6658, z = 3809} },
	{ IN = {x = 7130, z = 5624}, OUT = {x = 7320, z = 5874} },
	{ IN = {x = 7458, z = 4644}, OUT = {x = 7613, z = 4226} },
	{ IN = {x = 4452, z = 7996}, OUT = {x = 4136, z = 7898} },
	{ IN = {x = 9034, z = 4458}, OUT = {x = 9322, z = 4508} },
	{ IN = {x = 5474, z = 10606}, OUT = {x = 5764, z = 10654} },
	{ IN = {x = 1688, z = 8752}, OUT = {x = 2014, z = 8758} },
	{ IN = {x = 8196, z = 11128}, OUT = {x = 8462, z = 11406} },
    { IN = {x = 11630, z = 8668}, OUT = {x = 11772, z = 8856} },
	{ IN = {x = 11574, z = 10118}, OUT = {x = 11650, z = 10392} },
	{ IN = {x = 4804, z = 3352}, OUT = {x = 4574, z = 3158} },
	{ IN = {x = 9326, z = 2822}, OUT = {x = 9322, z = 3158} },
	{ IN = {x = 8308, z = 8966}, OUT = {x = 8024, z = 9334} },
}
local ActiveJumpIndex = 1
local NewJumpIN, NewJumpOUT = nil, nil
local lastPrevPressed, lastNextPressed = false, false
local lastInPressed, lastOutPressed, lastSavePressed = false, false, false
local firstJumpInProgress, firstJumpResetAt = false, 0
local zPrestackStep, zPrestackActive = 0, false
local zLastQCastAt = 0
-- Mouse lock while executing a selected jump (hold Z)
local zMouseLockActive = false
local zLockedIN, zLockedOUT = nil, nil

-- Force exactly two Q casts (Q1/Q2) before jumping (Q3) without reading ammo
local function EnsureTwoQCasts(IN)
	if zPrestackActive then return end
	if zPrestackStep >= 2 then return end
	zPrestackActive = true
	local function step()
		if zPrestackStep >= 2 then zPrestackActive = false; return end
		if Ready(_Q) then
			local now = Game.Timer()
			if now - zLastQCastAt > 0.05 then
				Control.CastSpell(HK_Q, IN)
				zPrestackStep = zPrestackStep + 1
				zLastQCastAt = now
			end
		end
		if zPrestackStep < 2 then
			DelayAction(step, 0.12)
		else
			zPrestackActive = false
		end
	end
	step()
end

local function QOnCooldown()
	local sd = myHero:GetSpellData(_Q)
	return sd and sd.currentCd and sd.currentCd > 0
end

local function ResetAfterQ3()
	local tries = 0
	local function check()
		if QOnCooldown() or tries >= 20 then
			firstJumpInProgress = false
			zPrestackActive = false
			zPrestackStep = 0
			return
		end
		tries = tries + 1
		DelayAction(check, 0.05)
	end
	DelayAction(check, 0.05)
end
local function DoFirstSpotJump()
	if not (Menu.Flee and Menu.Flee.firstJumpKey and Menu.Flee.firstJumpKey:Value()) then return end

	-- Select jump strictly by mouse radius: if cursor not within any IN radius and no lock, do nothing
	local rSelect = (Menu.Flee and Menu.Flee.spotRadius and Menu.Flee.spotRadius:Value()) or 80
	local m = mousePos or myHero.pos
	local chosen = nil
	if not zMouseLockActive then
		-- Allow reversible usage: detect if near IN or OUT and swap accordingly
		for i = 1, #JumpSpots do
			local js = JumpSpots[i]
			local inVec = Vector(js.IN.x, myHero.pos.y, js.IN.z)
			local outVec = Vector(js.OUT.x, myHero.pos.y, js.OUT.z)
			local nearIN = Distance(inVec, m) <= rSelect
			local nearOUT = Distance(outVec, m) <= rSelect
			if nearIN or nearOUT then
				chosen = js; ActiveJumpIndex = i;
				if nearIN then
					zLockedIN = inVec
					zLockedOUT = outVec
				else
					-- Reverse direction: start from OUT going toward IN
					zLockedIN = outVec
					zLockedOUT = inVec
				end
				zMouseLockActive = true
				break
			end
		end
		if not chosen then return end -- require mouse over either endpoint
	end

	-- Use locked spot for the rest of the sequence
	local IN = zLockedIN
	local OUT = zLockedOUT
	if not IN or not OUT then return end

	-- Keep the mouse and movement only once to reduce spam
	if not zCursorLocked then
		pcall(function() Control.SetCursorPos(IN) end)
		zCursorLocked = true
	end
	if not zJumpMoveIssued then
		Control.Move(IN)
		zJumpMoveIssued = true
	end

	-- Build Q stacks en route
	-- Nuevo flujo (según petición):
	-- 1) Si ammo==0 y cd==0 (sin haber usado Q) o ammo==1, stackear Q hasta que ammo==2 ANTES de entrar al radio de salto.
	-- 2) Cuando ammo==2 y estamos dentro del radio, castear E una sola vez (si lista) para reposicionarnos.
	-- 3) Tras E (o si E no está), castear la siguiente Q (Q3) para ejecutar el walljump (cuando ammo pasa de 2 a cooldown).
	local sdQ = myHero:GetSpellData(_Q)
	local ammo = GetQAmmo()
	local onCd = sdQ and sdQ.currentCd and sdQ.currentCd > 0
	local r = (Menu.Flee and Menu.Flee.spotRadius and Menu.Flee.spotRadius:Value()) or 80
	local distToIN = Distance(IN, myHero.pos)

	-- Pre-stack dinámico con hold: mantener cada Q hasta ~3.5s si el tiempo estimado de llegada lo permite.
	-- tiempo de llegada (ETA) al borde del radio
	local ms = math.max(myHero.ms or 345, 100)
	local eta = (distToIN - (r + 5)) / ms
	if eta < 0 then eta = 0 end
	local now = Game.Timer()

	-- Plan: Q1 en cuanto empezamos si no lanzada. Q2 se lanza a min(3.5, eta - buffer). Si estamos más cerca, se lanza antes.
	local holdWindow = 3.5
	local buffer = 0.35
	if not onCd and ammo < 2 and Ready(_Q) then
		-- Si no hemos lanzado Q1 (ammo>=3) y no hay registro previo
		if ammo == 0 and zPrestackStep < 1 then
			-- Some platforms report ammo starting at 0: treat as untouched, cast Q1 immediately
			Control.CastSpell(HK_Q, IN)
			zPrestackStep = 1
			zLastQCastAt = now
			return
		elseif ammo >= 3 and zPrestackStep < 1 then
			Control.CastSpell(HK_Q, IN)
			zPrestackStep = 1
			zLastQCastAt = now
			return
		end
		-- Decidir si lanzar Q2 (cuando ammo==2 aún no, primero necesitamos Q1 para bajar a 2; aquí ammo<2 sólo cubre 3 ó 1 según implementación real; mantenemos lógica simple)
		if ammo < 2 then
			-- Mantener si todavía hay tiempo suficiente antes de llegada
			local remaining = eta
			local desiredHold = math.min(holdWindow, math.max(0.05, remaining - buffer))
			-- Si el tiempo que hemos sostenido excede desiredHold, lanzar siguiente Q
			if now - zLastQCastAt >= desiredHold then
				Control.CastSpell(HK_Q, IN)
				zPrestackStep = zPrestackStep + 1
				zLastQCastAt = now
				return
			end
		end
	end

	-- Condición de salto: ammo==2 (hemos usado Q1 y Q2), estamos dentro del radio
	-- Execute Q3 very tightly: require distance within ~20 units of IN
	local execRadius = 50
	if not onCd and ammo == 2 and distToIN <= execRadius then
		local dir = (OUT - IN)
		if dir:Len() > 0 then
			dir = dir:Normalized()
			-- E sólo si ammo==2 y no la hemos usado aún para este intento
			if Ready(_E) and not firstJumpInProgress then
				CastE(myHero.pos + dir * 300)
			end
			-- Preparar ejecución de Q3 (el tercer cast) tras un pequeño retardo
			if Ready(_Q) and not firstJumpInProgress then
				firstJumpInProgress = true
				DelayAction(function()
					if Ready(_Q) then
						Control.CastSpell(HK_Q, myHero.pos + dir * 330)
						ResetAfterQ3()
					else
						firstJumpInProgress = false
					end
				end, Ready(_E) and 0.06 or 0.03)
			end
		end
	end
	if firstJumpInProgress and Game.Timer() > firstJumpResetAt then
		firstJumpInProgress = false
	end
end

local function TryQWeave()
	-- Si está activo "Solo Q tras básico" no hacer weave automático en Tick
	if Menu.Cancel.onlyPostAA and Menu.Cancel.onlyPostAA:Value() then return end
	if Menu.Cancel.fastWeave and Menu.Cancel.fastWeave:Value() then return end -- fast weave handles Q
	if not Menu.Combo.useQ:Value() then return end
	if Ready(_Q) and myHero.attackData and myHero.attackData.state == STATE_WINDDOWN then
		CastQ()
		local st = NextQStage()
		DoQCancel(GetTarget(350), st)
	end
end

-- Combo logic (inspired by iamrivendude, simplified and SDK-friendly)
	local function Combo()
	local t = GetTarget(950)
	lastComboTarget = t
	if not t or not Valid(t) then return end

	-- R2 execute
	if Menu.Combo.useR2:Value() and Ready(_R) and RIsWindSlash() then
		local hpPct = (t.health / t.maxHealth) * 100
		if hpPct <= Menu.Combo.r2Hp:Value() and Distance(myHero.pos, t.pos) <= 950 then
			Control.CastSpell(HK_R, t.pos)
		end
	end

	-- Always use E in combo (not only for gapclose)
	if Menu.Combo.useE:Value() and Ready(_E) then
		local dir = (t.pos - myHero.pos):Normalized()
		local ePos = myHero.pos + dir * 300
		CastE(ePos)
		-- Optional immediate Q follow-up if allowed
		if not (Menu.Cancel.onlyPostAA and Menu.Cancel.onlyPostAA:Value()) then
			DelayAction(function()
				if Ready(_Q) and Menu.Combo.useQ:Value() then
					CastQ(); local st = NextQStage(); DoQCancel(t, st)
				end
			end, 0.10)
		end
	end

	-- W when in range
	if Menu.Combo.useW:Value() and Ready(_W) and Distance(myHero.pos, t.pos) <= 260 then
		CastW()
	end

	-- R1 activation before close combat (empower Q/W range)
	if Menu.Combo.useR1:Value() and Ready(_R) and not RIsWindSlash() then
		-- Activate R1 if close to commit
		if Distance(myHero.pos, t.pos) <= 400 then
			CastR()
		end
	end

	-- Weave Q after autos (only if not enforcing post-AA only)
	if not (Menu.Cancel.onlyPostAA and Menu.Cancel.onlyPostAA:Value()) then
		-- Throttle target stick movement; keep attacks safe
		TryQWeave()
	end
	-- Light stick-to-target to keep pressure if orbwalker isn't issuing moves
	if t and Valid(t) then
		if Distance(myHero.pos, t.pos) > 250 then
			local now = Game.Timer()
			if now - lastStickMoveAt > 0.15 then -- issue move at most ~6.6/sec
				Control.Move(t.pos)
				lastStickMoveAt = now
			end
		end
	end
end

local function Harass()
	local t = GetTarget(600)
	if not t or not Valid(t) then return end
	if Menu.Harass.useE:Value() and Ready(_E) and Distance(myHero.pos, t.pos) > 275 and Distance(myHero.pos, t.pos) <= 500 then
		local dir = (t.pos - myHero.pos):Normalized()
		CastE(myHero.pos + dir * 250)
	end
	if Menu.Harass.useW:Value() and Ready(_W) and Distance(myHero.pos, t.pos) <= 260 then CastW() end
	if Menu.Harass.useQ:Value() and not (Menu.Cancel.onlyPostAA and Menu.Cancel.onlyPostAA:Value()) then TryQWeave() end
end

local function LaneClear()
	if not Menu.Clear.useQ:Value() then return end
	if not (Menu.Cancel.onlyPostAA and Menu.Cancel.onlyPostAA:Value()) then
		if Ready(_Q) and myHero.attackData and myHero.attackData.state == STATE_WINDDOWN then
			CastQ(); local st = NextQStage(); DoQCancel(nil, st)
		end
	end
end

local function HasIgnite()
	for _, slot in ipairs({ SUMMONER_1, SUMMONER_2 }) do
		local sd = myHero:GetSpellData(slot)
		if sd and sd.name and sd.name:lower():find("summonerdot") then
			return slot
		end
	end
	return nil
end

local function IgniteReady(slot)
	if not slot then return false end
	local sd = myHero:GetSpellData(slot)
	return sd and sd.level > 0 and sd.currentCd == 0 and Game.CanUseSpell(slot) == 0
end

local function ActiveItemDamage(target)
	if not (Menu.Damage.includeItems and Menu.Damage.includeItems:Value()) then return 0 end
	if not target or not Valid(target) then return 0 end
	local dmg = 0
	for slot = 6, 12 do
		local sd = myHero:GetSpellData(slot)
		if sd and sd.level and sd.level > 0 and sd.currentCd == 0 then
			local data = myHero:GetItemData(slot)
			local id = data and data.itemID or 0
			if id == 3077 or id == 3074 or id == 3748 or id == 6698 then
				-- Rough approximation: base + AD scaling; Titanic uses HP but we simplify
				local bonusAD = myHero.totalDamage - myHero.baseDamage
				dmg = dmg + 60 + (0.5 * bonusAD)
			end
		end
	end
	return dmg
end

local function SpellDamageQ(target)
	if not Ready(_Q) or not target or not Valid(target) then return 0 end
	local dmg = 0
	for stage = 1, 3 do
		dmg = dmg + (getdmg and getdmg("Q", target, myHero, stage) or 0)
	end
	return dmg
end

local function SpellDamageW(target)
	if not Ready(_W) or not target or not Valid(target) then return 0 end
	return (getdmg and getdmg("W", target, myHero) or 0)
end

local function SpellDamageR2(target)
	if not target or not Valid(target) then return 0 end
	if Ready(_R) and RIsWindSlash() then
		return (getdmg and getdmg("R", target, myHero) or 0)
	end
	-- Predictive: if R ready and not yet WindSlash in burst model we still plan to reach R2, but damageLib may need WindSlash state.
	-- Conservative: return 0 until actual WindSlash.
	return 0
end

local function AutoAttackDamage(target, count)
	if not target or not Valid(target) or not count or count <= 0 then return 0 end
	local per = (getdmg and getdmg("AA", target, myHero) or 0)
	return per * count
end

local function IgniteDamage(target)
	if not (Menu.Damage.useIgnite and Menu.Damage.useIgnite:Value()) then return 0 end
	local slot = HasIgnite()
	if slot and IgniteReady(slot) and target and Valid(target) then
		return (getdmg and getdmg("Ignite", target, myHero) or 0)
	end
	return 0
end

local function GetComboDamage(target)
	if not target or not Valid(target) then return 0 end
	local dmg = 0
	dmg = dmg + SpellDamageQ(target) + SpellDamageW(target) + SpellDamageR2(target)
	dmg = dmg + ActiveItemDamage(target)
	dmg = dmg + AutoAttackDamage(target, Menu.Damage.aaCountCombo:Value())
	dmg = dmg + IgniteDamage(target)
	return dmg
end

local function GetBurstDamage(target)
	if not target or not Valid(target) then return 0 end
	local dmg = 0
	-- Burst tries to guarantee W+Q (one pre-R2 Q) + R2 + Hydra + Q (remaining) + AAs + Ignite
	-- For simplicity still count full 3 Q casts & W & R2 & active item
	dmg = dmg + SpellDamageQ(target) + SpellDamageW(target)
	-- Predictive R2: if R ready but not yet WindSlash we assume we'll reach it soon; add estimated R2 once available.
	if Ready(_R) then
		if RIsWindSlash() then
			dmg = dmg + SpellDamageR2(target)
		else
			-- Approximate WindSlash damage using DamageLib if possible by temporarily pretending cast (cannot change state, so rough AD scaling)
			local bonusAD = myHero.totalDamage - myHero.baseDamage
			-- WindSlash base scaling ~ 60% total AD + level scaling; use heuristic
			dmg = dmg + 0.6 * myHero.totalDamage + (myHero.levelData.lvl * 10)
		end
	end
	dmg = dmg + ActiveItemDamage(target)
	dmg = dmg + AutoAttackDamage(target, Menu.Damage.aaCountBurst:Value())
	dmg = dmg + IgniteDamage(target)
	return dmg
end

local function IsComboKillable(target)
	return GetComboDamage(target) >= (target and target.health or math.huge)
end

local function IsBurstKillable(target)
	return GetBurstDamage(target) >= (target and target.health or math.huge)
end

-- Cache per tick to reduce recalcs in Draw
local lastDamageCalcTick = 0
local damageCache = {}
local function UpdateDamageCache()
	local now = Game.Timer()
	if now - lastDamageCalcTick < 0.15 then return end -- update ~6.6 times/sec
	lastDamageCalcTick = now
	damageCache = {}
	for i = 1, Game.HeroCount() do
		local e = Game.Hero(i)
		if e and e.team ~= myHero.team and Valid(e) then
			local combo = GetComboDamage(e)
			local burst = GetBurstDamage(e)
			damageCache[e.networkID] = { combo = combo, burst = burst, hp = e.health }
		end
	end
end


-- Draw
Callback.Add("Draw", function()
	if myHero.dead or not Menu.Draw.ranges:Value() then return end
	if Ready(_Q) then Draw.Circle(myHero, 275, 1, Draw.Color(160, 200, 200, 50)) end
	if Ready(_W) then Draw.Circle(myHero, 260, 1, Draw.Color(160, 200, 50, 200)) end
	Draw.Circle(myHero, 475, 1, Draw.Color(120, 50, 200, 200)) -- E approx
	-- Burst / R2 effective range indicator adjusted to 600
	if Ready(_R) then Draw.Circle(myHero, 600, 1, Draw.Color(120, 200, 50, 50)) end

	-- Visual lock indicator for burst target
	if lockedBurstTarget and Valid(lockedBurstTarget) then
		Draw.Circle(lockedBurstTarget, 85, 2, Draw.Color(255, 255, 0, 0))
	end

	-- Legacy flee spots drawing removed

	-- Draw jump pairs
	if Menu.Jumps and Menu.Jumps.draw and Menu.Jumps.draw:Value() then
		for i = 1, #JumpSpots do
			local jp = JumpSpots[i]
			local IN = Vector(jp.IN.x, myHero.pos.y, jp.IN.z)
			local OUT = Vector(jp.OUT.x, myHero.pos.y, jp.OUT.z)
			local col = (i == ActiveJumpIndex) and Draw.Color(220, 50, 200, 255) or Draw.Color(160, 50, 150, 200)
			Draw.Circle(IN, Menu.Flee.spotRadius:Value(), 2, col)
			Draw.Circle(OUT, 60, 2, col)
			Draw.Line(IN:ToMM(), OUT:ToMM(), 2, col)
		end
		if NewJumpIN then Draw.Circle(Vector(NewJumpIN.x, myHero.pos.y, NewJumpIN.z), 60, 2, Draw.Color(200, 0, 255, 0)) end
		if NewJumpOUT then Draw.Circle(Vector(NewJumpOUT.x, myHero.pos.y, NewJumpOUT.z), 60, 2, Draw.Color(200, 255, 0, 0)) end
	end

	-- Killability overlay
	if Menu.Damage and Menu.Damage.show and Menu.Damage.show:Value() then
		UpdateDamageCache()
		for i = 1, Game.HeroCount() do
			local e = Game.Hero(i)
			if e and e.team ~= myHero.team and Valid(e) then
				local data = damageCache[e.networkID]
				if data then
					local comboKill = data.combo >= data.hp
					local burstKill = data.burst >= data.hp
					local text = nil
					local col = Draw.Color(200, 255, 255, 255)
					if burstKill then
						text = "BURST"
						col = Draw.Color(230, 255, 140, 30)
					elseif comboKill then
						text = "COMBO"
						col = Draw.Color(230, 50, 255, 50)
					end
					if text then
						local pos2D = e.pos:To2D()
						if pos2D and pos2D.x and pos2D.y then
							Draw.Text(text, 15, pos2D.x - 20, pos2D.y - 50, col)
							if Menu.Damage.showValues and Menu.Damage.showValues:Value() then
								local valTxt = string.format("C:%.0f B:%.0f HP:%.0f", data.combo, data.burst, data.hp)
								Draw.Text(valTxt, 13, pos2D.x - 30, pos2D.y - 35, Draw.Color(180, 200, 200, 200))
							end
						end
					end
				end
			end
		end
	end
end)

-- Tick
Callback.Add("Tick", function()
	if myHero.dead or Game.IsChatOpen() then return end
	-- Reset per-tick gates for flee/cursor
	fleeEUsed = false
	fleeMoveUsed = false
	-- Do not reset attackIssuedCombo here; reset when leaving Combo or on new burst
	-- Handle burst target lock hotkey
	if Menu.Combo and Menu.Combo.lockTargetKey and Menu.Combo.lockTargetKey:Value() then
		local cand = GetClosestEnemyToMouse()
		if cand and Valid(cand) then
			lockedBurstTarget = cand
		end
	end
	-- Burst combo activation (HK_G via menu key fallback)
	if Menu.Combo and Menu.Combo.burstKey and Menu.Combo.burstKey:Value() then
		StartBurstCombo()
		-- While burst is active, pause other logic
		if burstActive then return end
	end
	-- Debug: print Q.stacks on key press (disabled output per request)
	-- Debug print of Q stacks removed
	-- Handle jump index cycling and adding
	if Menu.Jumps then
		-- Removed menu keys for editing jump spots; keep existing logic intact for using current JumpSpots only.
	end

	-- Priority: if Z is held, perform the dedicated jump routine (mouse lock logic handles selection)
	if Menu.Flee and Menu.Flee.firstJumpKey and Menu.Flee.firstJumpKey:Value() then
		DoFirstSpotJump()
		return
	else
		-- Release mouse lock when Z is not held
		if zMouseLockActive then
			zMouseLockActive = false
			zLockedIN, zLockedOUT = nil, nil
			zJumpMoveIssued = false
			zCursorLocked = false
		end
	end
	local m = Mode()
	if m == "Combo" then
        -- Auto-attack closest enemy once per combo (no spam)
        if Menu.Combo and Menu.Combo.useQ and Menu.Combo.useQ:Value() and not attackIssuedCombo then
            local target = GetClosestEnemy()
            if target and Valid(target) then
                SafeAttackCombo(target)
            end
        end
		Combo()
	elseif m == "Harass" then
		Harass()
	elseif m == "LaneClear" or m == "JungleClear" then
		LaneClear()
	elseif m == "Flee" then
		Flee()
	end

	-- Update killability cache post logic (in case Draw not called yet)
	if Menu.Damage and Menu.Damage.show and Menu.Damage.show:Value() then
		UpdateDamageCache()
	end
	-- No automatic weaving if enforcing only-post-AA; else attempt fallback
	if not (Menu.Cancel.onlyPostAA and Menu.Cancel.onlyPostAA:Value()) then
		TryQWeave()
	end
	-- Clear combo target cache when not in combo
	if Mode() ~= "Combo" then
		lastComboTarget = nil
		attackIssuedCombo = false
	end
end)

-- Try to hook orbwalker post-attack to guarantee the Q weave window
local function TryHookPostAttack()
	local hooked = false
	if Orb and Orb.OnPostAttack then
		local ok = pcall(function()
			Orb:OnPostAttack(function()
				local m = Mode()
				local allow = false
				if m == "Combo" and Menu.Combo.useQ:Value() then allow = true end
				if m == "Harass" and Menu.Harass.useQ:Value() then allow = true end
				if (m == "LaneClear" or m == "JungleClear") and Menu.Clear.useQ:Value() then allow = true end
				if allow and Ready(_Q) then
					if Menu.Cancel.fastWeave and Menu.Cancel.fastWeave:Value() then
						local tgt = lastComboTarget or GetTarget(350)
						local delayQ = (Menu.Cancel.fastQDelay:Value() + (Game.Latency() or 0)) / 1000
						local distBack = Menu.Cancel.backStepDist:Value()
						local holdMs = Menu.Cancel.backStepHold:Value()
						local restoreMs = Menu.Cancel.restoreOrb:Value()
						if Menu.Cancel.controlOrb:Value() then SetMovement(false); SetAttack(false) end
						DelayAction(function()
							if Ready(_Q) then
								CastQ(); NextQStage()
								-- Backstep movement
								local backDir
								if tgt and Valid(tgt) then backDir = (myHero.pos - tgt.pos) else backDir = (myHero.pos - (mousePos or myHero.pos)) end
								if backDir and backDir.Len and backDir:Len() > 0 then backDir = backDir:Normalized() else backDir = Vector(0,0,0) end
								local movePos = myHero.pos + backDir * distBack
								if not qCancelMoved then
									Control.Move(movePos)
									qCancelMoved = true
								end
							end
						end, delayQ)
						if Menu.Cancel.controlOrb:Value() then
							DelayAction(function() SetMovement(true); SetAttack(true) end, restoreMs/1000)
						end
					else
						CastQ(); local st = NextQStage(); DoQCancel(GetTarget(350), st)
					end
				end
			end)
		end)
		hooked = ok
	end
	return hooked
end

Callback.Add("Load", function()
	TryHookPostAttack()
	print("Depressive Riven loaded")
	_G.DepressiveAIONextLoadedChampion = true
end)

