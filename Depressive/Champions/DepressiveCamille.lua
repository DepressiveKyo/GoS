require "MapPositionGOS"
local Lib = require("Depressive/DepressiveLib") or _G.DepressiveLib
pcall(function() require("DepressivePrediction") end)

local HAS_DAMAGE_LIB = (type(_G.getdmg) == "function")

local IsValid = Lib.IsValid
local Ready = Lib.Ready

if not _G.DepressiveCamilleModule then
    local DepressiveCamilleModule = {}
    function DepressiveCamilleModule:Init()
    end
    function DepressiveCamilleModule:Tick()
    end
    function DepressiveCamilleModule:Draw()
    end
    _G.DepressiveCamilleModule = DepressiveCamilleModule
    return DepressiveCamilleModule
end

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

-- Advanced Movement Helper -------------------------------------------------
-- Provides timed movement disabling (pauses), forced movement to a position,
-- and unified control so different spell phases (E hook, E dash, W cast)
-- don't fight each other toggling the orbwalker rapidly.
local Movement = {
    pausedUntil = 0,
    forcePos = nil,
    forceUntil = 0,
    lastReason = nil,
    lastSet = nil
}

function Movement:Pause(ms, reason)
    if not Menu or (Menu.movement and not Menu.movement.enabled:Value()) then return end
    local t = Game.Timer() + (ms or 0)/1000
    if t > self.pausedUntil then
        self.pausedUntil = t
        self.lastReason = reason or "generic"
    end
end

function Movement:Force(pos, ms)
    if not pos then return end
    self.forcePos = Vector(pos)
    self.forceUntil = Game.Timer() + ((ms or 250)/1000)
end

function Movement:IsPaused()
    return Game.Timer() < self.pausedUntil
end

function Movement:ShouldForce()
    return Game.Timer() < self.forceUntil and self.forcePos ~= nil
end

function Movement:Update()
    -- Auto-pause during E dash phases regardless of manual menu if enabled
    local eName = myHero:GetSpellData(_E).name
    local isDash = myHero.pathing.isDashing
    local inEDash2 = (eName == "CamilleEDash2") or isDash
    local inEHook = (eName == "CamilleEDash1" and HasBuff(myHero, "camilleedashtoggle"))
    local pauseByState = inEDash2 or inEHook
    if pauseByState and Menu and Menu.movement and Menu.movement.enabled:Value() then
        self.pausedUntil = math.max(self.pausedUntil, Game.Timer() + (Menu.movement.holdEHook:Value()/1000))
        self.lastReason = inEDash2 and "E dash" or "E hook"
    end
    local shouldDisable = self:IsPaused()
    if shouldDisable ~= self.lastSet then
        SetMovement(not shouldDisable)
        self.lastSet = shouldDisable
    end
    if self:ShouldForce() then
        Control.Move(self.forcePos)
    end
end

-----------------------------------------------------------------------------

 

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
    Menu:MenuElement({ name = " ", drop = { "Version 1.2" } })

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

    Menu:MenuElement({ type = MENU, id = "movement", name = "Movement Helper" })
    Menu.movement:MenuElement({ id = "enabled", name = "Enable Advanced Movement", value = true })
    Menu.movement:MenuElement({ id = "holdW", name = "Hold after W cast (ms)", value = 150, min = 0, max = 400, step = 10 })
    Menu.movement:MenuElement({ id = "holdEHook", name = "Extra hold during E phases (ms)", value = 200, min = 0, max = 600, step = 25 })
    Menu.movement:MenuElement({ id = "holdQ2", name = "Hold a moment after Q2 (ms)", value = 80, min = 0, max = 250, step = 5 })
    Menu.movement:MenuElement({ id = "forceGapclose", name = "Force move to predicted W edge", value = false })

    
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
            if Menu and Menu.movement and Menu.movement.enabled:Value() then
                Movement:Pause(Menu.movement.holdQ2:Value(), "Q2 cast")
            end
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
        local cpos = Vector(res.CastPosition.x, myHero.pos.y, res.CastPosition.z)
        Control.CastSpell(HK_W, cpos)
        if Menu and Menu.movement and Menu.movement.enabled:Value() then
            Movement:Pause(Menu.movement.holdW:Value(), "W cast")
            if Menu.movement.forceGapclose:Value() then
                local dir = (cpos - myHero.pos):Normalized()
                Movement:Force(myHero.pos + dir * 150, Menu.movement.holdW:Value())
            end
        end
    end
end

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
end

local function OnTick()
    -- Update E casting state (affects some other logic like W weaving)
    if myHero:GetSpellData(_E).name == "CamilleEDash2" or myHero.pathing.isDashing or (myHero:GetSpellData(_E).name == "CamilleEDash1" and HasBuff(myHero, "camilleedashtoggle")) then
        IsCastingE = true
    else
        IsCastingE = false
    end

    -- Centralized movement update
    Movement:Update()

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
