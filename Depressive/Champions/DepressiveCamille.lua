local scriptVersion = 1.33 -- required first line pattern for loader (scriptVersion = x.xx)
require "MapPositionGOS"
local Lib = require("Depressive/DepressiveLib") or _G.DepressiveLib
pcall(function() require("DepressivePrediction") end)

local HAS_DAMAGE_LIB = (type(_G.getdmg) == "function")

local IsValid = Lib.IsValid
local Ready = Lib.Ready

if not _G.DepressiveCamilleModule then
    local DepressiveCamilleModule = {}
    function DepressiveCamilleModule:Init() end
    function DepressiveCamilleModule:Tick() end
    function DepressiveCamilleModule:Draw() end
    _G.DepressiveCamilleModule = DepressiveCamilleModule
end

if _G.DepressiveCamilleLoaded and _G.DepressiveCamilleLoaded >= scriptVersion then
    -- Already loaded same or newer version, skip re-init
    return _G.DepressiveCamilleModule or {}
end
print(string.format("[DepressiveCamille] Initializing v%.2f (prev %.2f)", scriptVersion, _G.DepressiveCamilleLoaded or 0))
print("[DepressiveCamille][Debug] scriptVersion variable now=", scriptVersion)
_G.DepressiveCamilleLoaded = scriptVersion

local MyHeroNotReady = Lib.MyHeroNotReady

local GetMode = Lib.GetMode

local function GetTarget(range)
    return Lib.GetTarget(range, "AD")
end

local SetMovement = Lib.SetMovement

local HasBuff = Lib.HasBuff

local function GetMinionCount(range, pos) return Lib.GetMinionCount(range, pos) end

local function Rotate(startPos, endPos, height, theta)
    local dx, dy = endPos.x - startPos.x, endPos.z - startPos.z
    local px = dx * math.cos(theta) - dy * math.sin(theta)
    local py = dx * math.sin(theta) + dy * math.cos(theta)
    return Vector(px + startPos.x, height, py + startPos.z)
end

local Objects = { WALL = 1 }

local function FindBestWPos(mode, towardsPos, searchMin, searchMax, stepDist, angleStep)
    local startPos, mPos, height = Vector(myHero.pos), Vector(towardsPos or mousePos), myHero.pos.y
    searchMin = searchMin or 100
    searchMax = searchMax or 2000
    stepDist = stepDist or 100
    angleStep = angleStep or 20
    for i = searchMin, searchMax, stepDist do
        local endPos = startPos:Extended(mPos, i)
        for j = angleStep, 360, angleStep do
            local testPos = Rotate(startPos, endPos, height, math.rad(j))
            if mode == Objects.WALL and MapPosition:inWall(testPos) then
                return testPos
            end
        end
    end
    return nil
end

local function FindNearestWallNear(centerPos, maxRadius, radialStep, angleStep)
    if not centerPos then return nil end
    local y = myHero.pos.y
    radialStep = radialStep or 40
    angleStep = angleStep or 20
    local bestPos, bestDist = nil, math.huge
    for r = radialStep, maxRadius, radialStep do
        for deg = 0, 360 - angleStep, angleStep do
            local rad = math.rad(deg)
            local testPos = Vector(centerPos.x + math.cos(rad) * r, y, centerPos.z + math.sin(rad) * r)
            if MapPosition:inWall(testPos) then
                local d = centerPos:DistanceTo(testPos)
                if d < bestDist then
                    bestDist = d
                    bestPos = testPos
                end
            end
        end
    end
    return bestPos
end

local function IsUnderEnemyTurret(pos) return Lib.UnderEnemyTurret(pos) end

local Menu

-- (Removed old generic Movement helper; W Edge Helper handles positioning)

 

-- DepressivePrediction wrappers
local DP = _G.DepressivePrediction
local function DPReady()
    return DP ~= nil and DP.SpellPrediction ~= nil
end

local DP_HITCHANCE = {
    NORMAL = function() return DP and DP.HITCHANCE_NORMAL or 3 end,
    HIGH = function() return DP and DP.HITCHANCE_HIGH or 4 end,
    IMMOBILE = function() return DP and DP.HITCHANCE_IMMOBILE or 6 end
}

local function DPRequiredHC(menuVal)
    if menuVal == 1 then return DP_HITCHANCE.NORMAL() end
    if menuVal == 2 then return DP_HITCHANCE.HIGH() end
    return DP_HITCHANCE.IMMOBILE()
end

local function LoadMenu()
    Menu = MenuElement({ type = MENU, id = "DepressiveCamille_" .. myHero.charName, name = "Depressive - " .. myHero.charName })
    Menu:MenuElement({ name = " ", drop = { "Version " .. tostring(scriptVersion) } })

    Menu:MenuElement({ type = MENU, id = "combo", name = "Combo" })
    Menu.combo:MenuElement({ id = "useAA", name = "Set AutoAttacks", value = 3, min = 0, max = 10, identifier = "AA/s" })
    Menu.combo:MenuElement({ id = "useQ", name = "Use Q", value = true })
    Menu.combo:MenuElement({ id = "useW", name = "Use W", value = true })
    Menu.combo:MenuElement({ id = "eWeave", name = "E > W > E if possible", value = true })
    Menu.combo:MenuElement({ id = "useE1", name = "Use E1", value = true })
    Menu.combo:MenuElement({ id = "useE2", name = "Use E2", value = true })
    Menu.combo:MenuElement({ id = "useR", name = "Use R", value = true })
    Menu.combo:MenuElement({ id = "rHP", name = "Cast R if target HP% <=", value = 40, min = 1, max = 100, identifier = "%" })

    Menu:MenuElement({ type = MENU, id = "harass", name = "Harass" })
    Menu.harass:MenuElement({ id = "useQ", name = "Use Q", value = true })
    Menu.harass:MenuElement({ id = "useW", name = "Use W", value = true })
    Menu.harass:MenuElement({ id = "mana", name = "Min Mana %", value = 40, min = 0, max = 100, identifier = "%" })

    Menu:MenuElement({ type = MENU, id = "clear", name = "Lane Clear" })
    Menu.clear:MenuElement({ id = "useQ", name = "Use Q", value = true })
    Menu.clear:MenuElement({ id = "useW", name = "Use W", value = true })
    Menu.clear:MenuElement({ id = "wCount", name = "W min minions", value = 3, min = 0, max = 10, identifier = "minion/s" })
    Menu.clear:MenuElement({ id = "mana", name = "Min Mana %", value = 40, min = 0, max = 100, identifier = "%" })

    Menu:MenuElement({ type = MENU, id = "jclear", name = "Jungle Clear" })
    Menu.jclear:MenuElement({ id = "useQ", name = "Use Q", value = true })
    Menu.jclear:MenuElement({ id = "useW", name = "Use W", value = true })
    Menu.jclear:MenuElement({ id = "mana", name = "Min Mana %", value = 40, min = 0, max = 100, identifier = "%" })

    Menu:MenuElement({ type = MENU, id = "lasthit", name = "Last Hit" })
    Menu.lasthit:MenuElement({ id = "useQ", name = "Use Q", value = true })
    Menu.lasthit:MenuElement({ id = "useQ2", name = "Use Q2", value = true })
    Menu.lasthit:MenuElement({ id = "useW", name = "Use W if out of AA range", value = true })
    Menu.lasthit:MenuElement({ id = "mana", name = "Min Mana %", value = 40, min = 0, max = 100, identifier = "%" })

    Menu:MenuElement({ type = MENU, id = "pred", name = "Prediction" })
    Menu.pred:MenuElement({ id = "hitchanceW", name = "Hitchance W", value = 1, drop = { "Normal", "High", "Immobile" } })
    Menu.pred:MenuElement({ id = "hitchanceE", name = "Hitchance E2", value = 1, drop = { "Normal", "High", "Immobile" } })
    Menu.pred:MenuElement({ id = "wEdgeMin", name = "W Edge Min Dist", value = 560, min = 500, max = 610, step = 5 })
    Menu.pred:MenuElement({ id = "wBackstep", name = "Intento backstep si muy cerca (< edge)", value = false })

    Menu:MenuElement({ type = MENU, id = "wall", name = "Wall System" })
    Menu.wall:MenuElement({ id = "enabled", name = "Enable Wall E", value = true })
    Menu.wall:MenuElement({ id = "autoCombo", name = "Auto E1 to Wall in Combo", value = true })
    Menu.wall:MenuElement({ id = "mode", name = "Mode", value = 3, drop = { "Mouse", "Target", "Smart" } })
    Menu.wall:MenuElement({ id = "turretSafety", name = "Avoid Enemy Turret (E)", value = true })
    Menu.wall:MenuElement({ id = "searchMax", name = "Max Search Range", value = 1200, min = 400, max = 2000, step = 50 })
    Menu.wall:MenuElement({ id = "angleStep", name = "Angle Step", value = 20, min = 10, max = 60, step = 5 })

    Menu:MenuElement({ type = MENU, id = "drawing", name = "Drawing" })
    Menu.drawing:MenuElement({ id = "drawW", name = "Draw W Range", value = false })
    Menu.drawing:MenuElement({ id = "drawE", name = "Draw E Range", value = false })
    Menu.drawing:MenuElement({ id = "drawR", name = "Draw R Range", value = false })

    -- W Edge Positioning Helper (like Lillia Q helper style)
    Menu:MenuElement({ type = MENU, id = "whelper", name = "W Edge Helper" })
    Menu.whelper:MenuElement({ id = "enable", name = "Enable W Edge Helper", value = true })
    Menu.whelper:MenuElement({ id = "onlyCombo", name = "Only in Combo Mode", value = true })
    Menu.whelper:MenuElement({ id = "desired", name = "Desired Edge Dist", value = 585, min = 540, max = 610, step = 5 })
    Menu.whelper:MenuElement({ id = "tolerance", name = "Distance Tolerance", value = 25, min = 5, max = 60, step = 5 })
    Menu.whelper:MenuElement({ id = "maxAdjust", name = "Max Adjust Move Dist", value = 400, min = 150, max = 900, step = 25 })
    Menu.whelper:MenuElement({ id = "draw", name = "Draw Helper Position", value = true })

    
end

local function Q2TrueDamage()
    local total = 0
    local Lvl = myHero.levelData.lvl
    local qLvl = myHero:GetSpellData(_Q).level
    if qLvl >= 1 then
        local qDMG = ({0.4, 0.5, 0.6, 0.7, 0.8})[qLvl] * myHero.totalDamage + myHero.totalDamage
        local TrueDMG = ({0.4, 0.44, 0.48, 0.52, 0.56, 0.6, 0.64, 0.68, 0.72, 0.76, 0.8, 0.84, 0.88, 0.92, 0.96, 1.0, 1.0, 1.0})[Lvl] * qDMG
        total = TrueDMG
    end
    return total
end

local function ComboDmg(unit)
    if not HAS_DAMAGE_LIB then return false end
    local AADmg = (getdmg("AA", unit, myHero) * 3) + (getdmg("AA", unit, myHero) * Menu.combo.useAA:Value())
    local Q1Dmg = getdmg("Q", unit, myHero, 1)
    local Q2Dmg = ((getdmg("Q", unit, myHero, 1) * 2) + getdmg("AA", unit, myHero)) - Q2TrueDamage()
    local QTrueDmg = Q2TrueDamage()
    local WDmg = getdmg("W", unit, myHero)
    local EDmg = getdmg("E", unit, myHero)
    local RDmg = getdmg("R", unit, myHero) * (Menu.combo.useAA:Value() + 3)
    return unit.health < (AADmg + Q1Dmg + Q2Dmg + QTrueDmg + WDmg + EDmg + RDmg)
end

local IsCastingE = false
local lastPostAttackTime = 0

local function ShouldUseQNow(mode)
    if mode == "Combo" then return Menu.combo.useQ and Menu.combo.useQ:Value() end
    if mode == "Harass" then return Menu.harass.useQ and Menu.harass.useQ:Value() and (myHero.mana / myHero.maxMana) >= (Menu.harass.mana:Value() / 100) end
    if mode == "Clear" then return Menu.clear.useQ and Menu.clear.useQ:Value() and (myHero.mana / myHero.maxMana) >= (Menu.clear.mana:Value() / 100) end
    if mode == "LastHit" then return Menu.lasthit.useQ and Menu.lasthit.useQ:Value() and (myHero.mana / myHero.maxMana) >= (Menu.lasthit.mana:Value() / 100) end
    return false
end

local function PostAttack_Q(target)
    if not Ready(_Q) or IsCastingE or myHero.pathing.isDashing then return end
    local mode = GetMode()
    if not ShouldUseQNow(mode) then return end
    local qData = myHero:GetSpellData(_Q)
    if qData.name == "CamilleQ2" then
        if not HasBuff(myHero, "camilleqprimingstart") then
            Control.CastSpell(HK_Q)
            lastPostAttackTime = Game.Timer()
            -- removed movement pause
        end
        return
    end
    if qData.name == "CamilleQ" and not HasBuff(myHero, "camilleqprimingstart") then
        Control.CastSpell(HK_Q)
        lastPostAttackTime = Game.Timer()
    end
end

local function InitializeWRAIOCallbacks()
    if _G.GOS and _G.GOS.Orbwalker and _G.GOS.Orbwalker.OnPostAttack then
        _G.GOS.Orbwalker:OnPostAttack(function(args) PostAttack_Q(args and (args.Target or args.target)) end)
    end
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.OnPostAttack then
        _G.SDK.Orbwalker:OnPostAttack(function(args) PostAttack_Q(args and (args.Target or args.target)) end)
    end
    if _G.Orbwalker and _G.Orbwalker.OnPostAttack then
        _G.Orbwalker:OnPostAttack(function(args) PostAttack_Q(args and (args.Target or args.target)) end)
    end
end

local function PostDashW()
    if not Menu.combo.eWeave:Value() or not Ready(_W) or not myHero.pathing.isDashing then return end
    local target = GetTarget(2000)
    if not target or not IsValid(target) then return end
    local minDesired, maxDesired = 560, 610
    local endPos = myHero.pathing and myHero.pathing.endPos or target.pos
    local projDist = endPos and Vector(endPos):DistanceTo(target.pos) or myHero.pos:DistanceTo(target.pos)
    if projDist >= minDesired and projDist <= maxDesired then
        Control.CastSpell(HK_W, target.pos)
    end
end

local function GetWallTowardsPosition(target)
    local modeVal = Menu.wall.mode:Value()
    if modeVal == 1 then
        return mousePos
    elseif modeVal == 2 then
        return target and target.pos or mousePos
    else
        return (target and target.pos) or mousePos
    end
end

local function TryWallE(target)
    if not Menu.wall.enabled:Value() or not Ready(_E) then return false end
    if myHero:GetSpellData(_E).name ~= "CamilleE" and myHero:GetSpellData(_E).name ~= "CamilleEDash1" then return false end
    if target and IsValid(target) and myHero.pos:DistanceTo(target.pos) <= 350 then return false end
    local dynBase = 800
    local dynMax = math.min(Menu.wall.searchMax:Value(), dynBase)
    local castPos
    if target and IsValid(target) then
        castPos = FindNearestWallNear(target.pos, dynMax, 40, Menu.wall.angleStep:Value())
    end
    if not castPos then
        local towards = GetWallTowardsPosition(target)
        castPos = FindBestWPos(Objects.WALL, towards, 50, dynMax, 50, Menu.wall.angleStep:Value())
    end
    if castPos and myHero.pos:DistanceTo(castPos) <= dynMax then
        if Menu.wall.turretSafety:Value() and IsUnderEnemyTurret(castPos) then return false end
        Control.CastSpell(HK_E, castPos)
        return true
    end
    return false
end

local function CastELogic(target)
    if not Menu.combo.useE1:Value() or not Ready(_E) then return end
    if target and IsValid(target) and myHero.pos:DistanceTo(target.pos) <= 350 then return end
    local dynMax = 800
    local castPos
    if target and IsValid(target) then
        castPos = FindNearestWallNear(target.pos, dynMax, 40, Menu.wall.angleStep:Value())
    end
    if not castPos then
        local towards = GetWallTowardsPosition(target)
        castPos = FindBestWPos(Objects.WALL, towards, 50, dynMax, 50, Menu.wall.angleStep:Value())
    end
    if castPos and myHero.pos:DistanceTo(castPos) < dynMax then
        if Menu.wall.turretSafety:Value() and IsUnderEnemyTurret(castPos) then return end
        Control.CastSpell(HK_E, castPos)
    end
end

local function CastE2Prediction(target)
    if not Menu.combo.useE2:Value() or not Ready(_E) then return end
    if myHero:GetSpellData(_E).name ~= "CamilleEDash2" then return end
    if not DPReady() then return end
    local dist = myHero.pos:DistanceTo(target.pos)
    local spell = DP.SpellPrediction({
        Type = DP.SPELLTYPE_LINE,
        Speed = 1050 + myHero.ms,
        Range = 800,
        Delay = 0,
        Radius = 130,
        Collision = false
    })
    local res = spell:GetPrediction(target, myHero.pos)
    local casted = false
    if res and res.CastPosition and res.HitChance and res.HitChance >= DPRequiredHC(Menu.pred.hitchanceE:Value()) then
        local cpos = Vector(res.CastPosition.x, myHero.pos.y, res.CastPosition.z)
        Control.CastSpell(HK_E, cpos)
        casted = true
    end
    if not casted and dist <= 820 then
        Control.CastSpell(HK_E, target.pos)
    end
end

local function CastWPrediction(target)
    if IsCastingE then return end
    if not Menu.combo.useW:Value() or not Ready(_W) then return end
    if not DPReady() then return end
    local spell = DP.SpellPrediction({
        Type = DP.SPELLTYPE_CONE,
        Speed = 1750,
        Range = 610,
        Delay = 0.25,
        Radius = 300,
        Collision = false
    })
    local res = spell:GetPrediction(target, myHero.pos)
    if res and res.CastPosition and res.HitChance and res.HitChance >= DPRequiredHC(Menu.pred.hitchanceW:Value()) then
        local predPos = Vector(res.CastPosition.x, myHero.pos.y, res.CastPosition.z)
        local dist = myHero.pos:DistanceTo(predPos)
        local edgeMin = Menu.pred.wEdgeMin:Value()
        -- If target is closer than edge, optional backstep
        if dist < edgeMin then
            if Menu.pred.wBackstep:Value() and not myHero.pathing.isDashing and not IsCastingE then
                local dir = (predPos - myHero.pos):Normalized()
                local backPos = myHero.pos - dir * math.min(edgeMin - dist + 40, 150)
                Control.Move(backPos)
            end
            return
        end
        if dist > 610 then return end
        Control.CastSpell(HK_W, predPos)
        -- no generic movement pause
    end
end

-- ===================== W EDGE HELPER (Movement Positioner) =====================
local WEdgeMovePos, WEdgeHooked, LastWEdgeCalc = nil, false, 0

local function ComputeWEdgePosition(target)
    if not target or not target.pos then return nil end
    local desired = Menu and Menu.whelper and Menu.whelper.desired:Value() or 585
    local hx, hz = myHero.pos.x, myHero.pos.z
    local tx, tz = target.pos.x, target.pos.z
    local dx, dz = hx - tx, hz - tz
    local dist = math.sqrt(dx*dx + dz*dz)
    if dist < 1 then return nil end
    local nx, nz = dx / dist, dz / dist
    local px, pz = tx + nx * desired, tz + nz * desired
    local pos = { x = px, y = myHero.pos.y, z = pz }
    if MapPosition and MapPosition.inWall and MapPosition:inWall(pos) then return nil end
    return pos, dist
end

local function UpdateWEdgeHelper()
    if not Menu or not Menu.whelper or not Menu.whelper.enable:Value() then WEdgeMovePos = nil; return end
    if Menu.whelper.onlyCombo:Value() and GetMode() ~= "Combo" then WEdgeMovePos = nil; return end
    if not Ready(_W) then WEdgeMovePos = nil; return end
    local target = GetTarget(1200)
    if not target or not IsValid(target) then WEdgeMovePos = nil; return end
    local pos, dist = ComputeWEdgePosition(target)
    if not pos then WEdgeMovePos = nil; return end
    local desired = Menu.whelper.desired:Value()
    local tol = Menu.whelper.tolerance:Value()
    -- Only reposition if we're outside tolerance
    if math.abs(dist - desired) <= tol then
        WEdgeMovePos = nil
        return
    end
    -- Clamp movement distance
    local moveDist = math.sqrt((pos.x - myHero.pos.x)^2 + (pos.z - myHero.pos.z)^2)
    if moveDist > Menu.whelper.maxAdjust:Value() then
        -- shorten towards target pos
        local ratio = Menu.whelper.maxAdjust:Value() / moveDist
        pos.x = myHero.pos.x + (pos.x - myHero.pos.x) * ratio
        pos.z = myHero.pos.z + (pos.z - myHero.pos.z) * ratio
    end
    WEdgeMovePos = pos
    LastWEdgeCalc = Game.Timer()
end

local function OnPreMovementWEdge(args)
    if not WEdgeMovePos then return end
    if myHero.pathing.isDashing or IsCastingE then return end
    if not Ready(_W) then return end
    if not Menu or not Menu.whelper or not Menu.whelper.enable:Value() then return end
    if Menu.whelper.onlyCombo:Value() and GetMode() ~= "Combo" then return end
    local dx, dz = WEdgeMovePos.x - myHero.pos.x, WEdgeMovePos.z - myHero.pos.z
    local dist = math.sqrt(dx*dx + dz*dz)
    if dist < 35 then return end
    if args then args.Target = WEdgeMovePos end
end

local function TryHookWEdge()
    if WEdgeHooked then return end
    if _G.GOS and _G.GOS.Orbwalker and _G.GOS.Orbwalker.OnPreMovement then
        _G.GOS.Orbwalker:OnPreMovement(OnPreMovementWEdge); WEdgeHooked = true; return
    end
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.OnPreMovement then
        _G.SDK.Orbwalker:OnPreMovement(OnPreMovementWEdge); WEdgeHooked = true; return
    end
    if _G.Orbwalker and _G.Orbwalker.OnPreMovement then
        _G.Orbwalker:OnPreMovement(OnPreMovementWEdge); WEdgeHooked = true; return
    end
end

-- =============================================================================

local function Combo()
    local target = GetTarget(2000)
    if not target or not IsValid(target) then return end

    local QRange = (myHero.range + 50 + myHero.boundingRadius + target.boundingRadius)
    local distToTarget = myHero.pos:DistanceTo(target.pos)

    CastE2Prediction(target)

    if IsCastingE then return end


    local W_RANGE = 610
    if (not Ready(_W) or distToTarget > W_RANGE) and distToTarget > 350 then
        if Menu.wall.autoCombo:Value() and TryWallE(target) then
        else
            CastELogic(target)
        end
    end

    if myHero.pos:DistanceTo(target.pos) < QRange and not HasBuff(myHero, "camilleqprimingstart") and Menu.combo.useQ:Value() and Ready(_Q) then
        Control.CastSpell(HK_Q)
    end

    if myHero.pos:DistanceTo(target.pos) < 610 and (not HasBuff(myHero, "camilleedashtoggle")) then
        if ComboDmg(target) or myHero.pos:DistanceTo(target.pos) > 310 then
            CastWPrediction(target)
        end
    end

    if myHero.pos:DistanceTo(target.pos) < 475 and Menu.combo.useR:Value() and Ready(_R) then
        local hpPerc = (target.health / target.maxHealth) * 100
        if hpPerc <= Menu.combo.rHP:Value() then
            Control.CastSpell(HK_R, target)
        end
    end
end

local function Harass()
    local target = GetTarget(700)
    if not target or not IsValid(target) then return end
    if myHero.mana / myHero.maxMana < Menu.harass.mana:Value() / 100 then return end

    local QRange = (myHero.range + 50 + myHero.boundingRadius + target.boundingRadius)
    if myHero.pos:DistanceTo(target.pos) < QRange and not HasBuff(myHero, "camilleqprimingstart") and Menu.harass.useQ:Value() and Ready(_Q) then
        Control.CastSpell(HK_Q)
    end

    if myHero.pos:DistanceTo(target.pos) > 310 and myHero.pos:DistanceTo(target.pos) < 610 and Menu.harass.useW:Value() and Ready(_W) and not IsCastingE then
        CastWPrediction(target)
    end
end

local function Clear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and IsValid(minion) and minion.isEnemy and myHero.pos:DistanceTo(minion.pos) <= 700 and myHero.mana / myHero.maxMana >= Menu.clear.mana:Value() / 100 then
            local QRange = (myHero.range + 50 + myHero.boundingRadius + minion.boundingRadius)
            local QDmg = (getdmg("Q", minion, myHero, 1) + getdmg("AA", minion, myHero))

            if Ready(_Q) and Menu.clear.useQ:Value() and not HasBuff(myHero, "camilleqprimingstart") and myHero.pos:DistanceTo(minion.pos) <= QRange and QDmg > minion.health then
                Control.CastSpell(HK_Q)
            end

            if myHero.pos:DistanceTo(minion.pos) < 650 and Menu.clear.useW:Value() and Ready(_W) and not IsCastingE then
                if GetMinionCount(400, minion) >= Menu.clear.wCount:Value() then
                    Control.CastSpell(HK_W, minion.pos)
                end
            end
        end
    end
end

local function JungleClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and IsValid(minion) and (minion.team == 300) and myHero.pos:DistanceTo(minion.pos) <= 700 and myHero.mana / myHero.maxMana >= Menu.jclear.mana:Value() / 100 then
            local QRange = (myHero.range + 50 + myHero.boundingRadius + minion.boundingRadius)
            if Ready(_Q) and Menu.jclear.useQ:Value() and not HasBuff(myHero, "camilleqprimingstart") and myHero.pos:DistanceTo(minion.pos) <= QRange then
                Control.CastSpell(HK_Q)
            end
            if myHero.pos:DistanceTo(minion.pos) < 650 and Menu.jclear.useW:Value() and Ready(_W) and not IsCastingE then
                Control.CastSpell(HK_W, minion.pos)
            end
        end
    end
end

local function LastHit()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and IsValid(minion) and minion.isEnemy and myHero.pos:DistanceTo(minion.pos) <= 700 and myHero.mana / myHero.maxMana >= Menu.lasthit.mana:Value() / 100 then
            local QDmg = (getdmg("Q", minion, myHero, 1) + getdmg("AA", minion, myHero))
            local WDmg = getdmg("W", minion, myHero)
            local QRange = (myHero.range + 50 + myHero.boundingRadius + minion.boundingRadius)

            if Ready(_Q) and Menu.lasthit.useQ:Value() and not HasBuff(myHero, "camilleqprimingstart") and myHero.pos:DistanceTo(minion.pos) <= QRange and QDmg > minion.health then
                Control.CastSpell(HK_Q)
            end
            if myHero.pos:DistanceTo(minion.pos) < 650 and myHero.pos:DistanceTo(minion.pos) > 200 and Menu.lasthit.useW:Value() and Ready(_W) and WDmg > minion.health and not IsCastingE then
                Control.CastSpell(HK_W, minion.pos)
            end
        end
    end
end

local function OnDraw()
    if myHero.dead then return end
    if Menu.drawing.drawR:Value() and Ready(_R) then Draw.Circle(myHero.pos, 475, 1, Draw.Color(225, 225, 0, 10)) end
    if Menu.drawing.drawE:Value() and Ready(_E) then Draw.Circle(myHero.pos, 900, 1, Draw.Color(225, 225, 125, 10)) end
    if Menu.drawing.drawW:Value() and Ready(_W) then Draw.Circle(myHero.pos, 650, 1, Draw.Color(225, 225, 125, 10)) end
    if Menu and Menu.whelper and Menu.whelper.draw:Value() and WEdgeMovePos then
        Draw.Circle(WEdgeMovePos, 40, 1, Draw.Color(200, 50, 200, 255))
        local from2d = myHero.pos.To2D and myHero.pos:To2D() or nil
        local toVec = Vector(WEdgeMovePos.x, myHero.pos.y, WEdgeMovePos.z)
        local to2d = toVec.To2D and toVec:To2D() or nil
        if from2d and to2d and from2d.onScreen and to2d.onScreen then
            Draw.Line(from2d.x, from2d.y, to2d.x, to2d.y, 1, Draw.Color(150, 50, 200, 255))
        end
    end
end

local function OnTick()
    -- Update E casting state (affects some other logic like W weaving)
    if myHero:GetSpellData(_E).name == "CamilleEDash2" or myHero.pathing.isDashing or (myHero:GetSpellData(_E).name == "CamilleEDash1" and HasBuff(myHero, "camilleedashtoggle")) then
        IsCastingE = true
    else
        IsCastingE = false
    end

    -- Simple movement disable while in active dash of second E to avoid orb conflicts
    if myHero:GetSpellData(_E).name == "CamilleEDash2" or myHero.pathing.isDashing then
        SetMovement(false)
    else
        SetMovement(true)
    end

    -- Update and hook W edge helper
    TryHookWEdge()
    UpdateWEdgeHelper()
    if WEdgeMovePos and not WEdgeHooked then
        -- fallback manual move
        if Game.Timer() - LastWEdgeCalc > 0.06 then
            Control.Move(WEdgeMovePos)
            LastWEdgeCalc = Game.Timer()
        end
    end

    PostDashW()

    if MyHeroNotReady() then return end
    local Mode = GetMode()
    if Mode == "Combo" then
        Combo()
    elseif Mode == "Harass" then
        Harass()
    elseif Mode == "Clear" then
        Clear()
        JungleClear()
    elseif Mode == "LastHit" then
        LastHit()
    end
end

local function LoadScript()
    LoadMenu()
    Callback.Add("Tick", OnTick)
    Callback.Add("Draw", OnDraw)
    InitializeWRAIOCallbacks()
end

LoadScript()

return _G.DepressiveCamilleModule or {}
