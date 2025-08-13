require "MapPositionGOS"
pcall(function() require("DepressivePrediction") end)

local HAS_DAMAGE_LIB = false
do
    local ok = pcall(function() require("DamageLib") end)
    if not ok then pcall(function() require("mapposition/DamageLib") end) end
    if type(_G.getdmg) ~= "function" then
        function getdmg(_, _, _)
            return 0
        end
        HAS_DAMAGE_LIB = false
    else
        HAS_DAMAGE_LIB = true
    end
    if type(_G.ConvertToHitChance) ~= "function" then
        function ConvertToHitChance(menuVal, predHC)
            if type(predHC) == "number" then
                return predHC >= (menuVal + 1)
            end
            return true
        end
    end
end

local function IsValid(unit)
    return unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable
end

local function Ready(spell)
    if Game and Game.CanUseSpell then
        return Game.CanUseSpell(spell) == 0
    end
    local sd = myHero and myHero.GetSpellData and myHero:GetSpellData(spell)
    if not sd then return false end
    if sd.level == 0 then return false end
    if sd.currentCd and sd.currentCd == 0 then return true end
    if sd.cd and sd.cd == 0 then return true end
    return false
end

local function MyHeroNotReady()
    return myHero.dead or myHero.isChanneling or myHero.activeSpell.valid
end

local function GetMode()
    if _G.EOWLoaded and EOW and EOW.Mode and type(EOW.Mode) == "function" then
        local ok, mode = pcall(function() return EOW:Mode() end)
        if ok and mode then return mode end
    end
    if _G.GOS and GOS.GetMode then return GOS:GetMode() end
    if _G.SDK and _G.SDK.Orbwalker then
        local SDK = _G.SDK.Orbwalker
        if SDK.IsAutoAttacking and SDK:IsAutoAttacking() then return "Combo" end
        if SDK.Modes then
            if type(SDK.Modes[0]) == "function" and SDK.Modes[0]() then return "Combo" end
            if type(SDK.Modes[1]) == "function" and SDK.Modes[1]() then return "Harass" end
            if type(SDK.Modes[2]) == "function" and SDK.Modes[2]() then return "Clear" end
            if type(SDK.Modes[3]) == "function" and SDK.Modes[3]() then return "LastHit" end
        end
    end
    if _G.Orbwalker and _G.Orbwalker.Mode and type(_G.Orbwalker.Mode) == "function" then
        return _G.Orbwalker:Mode()
    end
    return ""
end

local function GetTarget(range)
    if _G.GOS and GOS.GetTarget then return GOS:GetTarget(range, "AD") end
    if _G.EOWLoaded and EOW.GetTarget then return EOW:GetTarget(range) end
    if _G.SDK and _G.SDK.TargetSelector then
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL)
    end
    return nil
end

local function SetMovement(bool)
    if _G.GOS then GOS.BlockMovement = not bool end
    if _G.EOWLoaded then EOW:SetMovements(bool) end
    if _G.SDK and _G.SDK.Orbwalker then _G.SDK.Orbwalker:SetMovement(bool) end
end

local function HasBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then
            return true
        end
    end
    return false
end

local function GetMinionCount(range, pos)
    local p = pos.pos or pos
    local count = 0
    for i = 1, Game.MinionCount() do
        local m = Game.Minion(i)
        if m and m.valid and m.isEnemy and not m.dead and p:DistanceTo(m.pos) < range then
            count = count + 1
        end
    end
    return count
end

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

local function IsUnderEnemyTurret(pos)
    for i = 1, Game.TurretCount() do
        local t = Game.Turret(i)
        if t and t.valid and not t.dead and t.isEnemy then
            if pos:DistanceTo(t.pos) <= 775 then
                return true
            end
        end
    end
    return false
end

local Menu

 

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
    if myHero:GetSpellData(_E).name == "CamilleEDash2" or myHero.pathing.isDashing then
        SetMovement(false)
        IsCastingE = true
    else
        SetMovement(true)
        IsCastingE = false
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
