if _G.__DEPRESSIVE_IRELIA_ADVANCED_LOADED then return end
_G.__DEPRESSIVE_IRELIA_ADVANCED_LOADED = true

local Version = "1.1"
local ScriptName = "Depressive Irelia Advanced"

if myHero.charName ~= "Irelia" then return end

pcall(require, "GGPrediction")
pcall(require, "DepressivePrediction")

local PRED_ENGINE_GG = 1
local PRED_ENGINE_DEPRESSIVE = 2
local PredictionMenu = nil

local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameTurretCount = Game.TurretCount
local GameTurret = Game.Turret
local GameMissileCount = Game.MissileCount
local GameMissile = Game.Missile
local GameTimer = Game.Timer
local GameCanUseSpell = Game.CanUseSpell
local GameLatency = Game.Latency

local TableInsert = table.insert
local TableRemove = table.remove
local TableSort = table.sort

local MathSqrt = math.sqrt
local MathHuge = math.huge
local MathFloor = math.floor
local MathCeil = math.ceil
local MathMax = math.max
local MathMin = math.min
local MathAbs = math.abs
local MathAtan2 = math.atan2
local MathCos = math.cos
local MathSin = math.sin
local MathRad = math.rad
local MathDeg = math.deg
local MathPi = math.pi

local ControlCastSpell = Control.CastSpell
local ControlKeyDown = Control.KeyDown
local ControlKeyUp = Control.KeyUp
local ControlSetCursorPos = Control.SetCursorPos
local ControlMove = Control.Move

local DrawCircle = Draw.Circle
local DrawLine = Draw.Line
local DrawText = Draw.Text
local DrawColor = Draw.Color

local _Q, _W, _E, _R = 0, 1, 2, 3
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team
local TEAM_JUNGLE = 300
local GG_TYPE_LINE = 0
local GG_TYPE_CONE = 2

local function GetOrbwalkerModes()
    return _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes
end

local function IsCombatModeActive()
    local modes = GetOrbwalkerModes()
    if not modes then return false end
    return modes[0] or modes[1] or modes[6]
end

local function IsFarmModeActive()
    local modes = GetOrbwalkerModes()
    if not modes then return false end
    return modes[2] or modes[3] or modes[4]
end

local SpellData = {
    Q = {
        Range = 600,
        Speed = 1400 + myHero.ms, 
        Delay = 0,
        Width = 0,
        MinionBonus = 43 
    },
    W = {
        Range = 825,
        Delay = 0.25,
        Width = 90,
        MaxCharge = 1.5
    },
    E = {
        Range = 850,
        Speed = 2000,
        Delay = 0,
        Width = 70, 
        StunDuration = 0.75
    },
    R = {
        Range = 1000,
        Speed = 2000,
        Delay = 0.4,
        Width = 160,
        WallDuration = 2.5
    }
}

local Cache = {
    EnemyHeroes = {},
    AllyHeroes = {},
    EnemyMinions = {},
    AllyMinions = {},
    JungleMobs = {},
    EnemyTurrets = {},
    LastHeroUpdate = -1,
    HeroUpdateInterval = 0.10,
    LastMinionUpdate = -1,
    MinionUpdateInterval = 0.08,
    LastTurretUpdate = -1,
    TurretUpdateInterval = 0.30,
    HeroesLoaded = false,
    
    
    Items = {
        LastUpdate = 0,
        UpdateInterval = 10,
        BOTRK = nil,
        WitsEnd = nil,
        Titanic = nil,
        Sheen = nil,
        Trinity = nil,
        Divine = nil,
        Iceborn = nil
    },
    
    
    Spells = {
        E1Active = false,
        E1Position = nil,
        E1CastTime = 0,
        WCharging = false,
        WStartTime = 0
    }
}

local function UpdateCache()
    local now = GameTimer()
    local heroInterval = IsCombatModeActive() and 0.08 or 0.14
    local minionInterval = (IsCombatModeActive() or IsFarmModeActive()) and 0.07 or 0.12
    local turretInterval = IsCombatModeActive() and 0.25 or 0.40

    if now - Cache.LastHeroUpdate >= heroInterval then
        Cache.EnemyHeroes = {}
        Cache.AllyHeroes = {}
        for i = 1, GameHeroCount() do
            local unit = GameHero(i)
            if unit and unit.valid and not unit.dead then
                if unit.isEnemy and unit.visible and unit.isTargetable then
                    TableInsert(Cache.EnemyHeroes, unit)
                elseif unit.team == TEAM_ALLY and unit ~= myHero then
                    TableInsert(Cache.AllyHeroes, unit)
                end
            end
        end
        Cache.LastHeroUpdate = now
    end

    if now - Cache.LastMinionUpdate >= minionInterval then
        Cache.EnemyMinions = {}
        Cache.JungleMobs = {}
        for i = 1, GameMinionCount() do
            local minion = GameMinion(i)
            if minion and minion.valid and not minion.dead and minion.visible and minion.isTargetable then
                if minion.team == TEAM_JUNGLE then
                    TableInsert(Cache.JungleMobs, minion)
                elseif minion.isEnemy then
                    TableInsert(Cache.EnemyMinions, minion)
                end
            end
        end
        Cache.LastMinionUpdate = now
    end

    if now - Cache.LastTurretUpdate >= turretInterval then
        Cache.EnemyTurrets = {}
        for i = 1, GameTurretCount() do
            local turret = GameTurret(i)
            if turret and turret.isEnemy and not turret.dead then
                TableInsert(Cache.EnemyTurrets, turret)
            end
        end
        Cache.LastTurretUpdate = now
    end
end

local function UpdateItemCache()
    return
end

local function LoadHeroes()
    if Cache.HeroesLoaded then return true end
    local count = 0
    for i = 1, GameHeroCount() do
        local unit = GameHero(i)
        if unit and unit.isEnemy then
            count = count + 1
        end
    end
    if count >= 1 then
        Cache.HeroesLoaded = true
        return true
    end
    return false
end

local function GetDistanceSqr(p1, p2)
    if not p1 or not p2 then return MathHuge end
    p2 = p2 or myHero.pos
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return dx * dx + dz * dz
end

local function GetDistance(p1, p2)
    return MathSqrt(GetDistanceSqr(p1, p2))
end

local function IsGGPredictionReady()
    return _G.GGPrediction and type(_G.GGPrediction.SpellPrediction) == "function"
end

local function IsDepressivePredictionReady()
    return _G.DepressivePrediction and type(_G.DepressivePrediction.GetPrediction) == "function"
end

local function GetSelectedPredictionEngine()
    if PredictionMenu and PredictionMenu.Engine then
        return PredictionMenu.Engine:Value()
    end
    return PRED_ENGINE_GG
end

local function GetActivePredictionEngine()
    local selected = GetSelectedPredictionEngine()

    if selected == PRED_ENGINE_DEPRESSIVE then
        if IsDepressivePredictionReady() then
            return PRED_ENGINE_DEPRESSIVE
        end
        if IsGGPredictionReady() then
            return PRED_ENGINE_GG
        end
    else
        if IsGGPredictionReady() then
            return PRED_ENGINE_GG
        end
        if IsDepressivePredictionReady() then
            return PRED_ENGINE_DEPRESSIVE
        end
    end

    return 0
end

local function NormalizeGGHitChance(prediction)
    if not prediction or not prediction.CastPosition then
        return 0
    end
    if prediction:CanHit(GGPrediction.HITCHANCE_IMMOBILE) then
        return 6
    end
    if prediction:CanHit(GGPrediction.HITCHANCE_HIGH) then
        return 4
    end
    if prediction:CanHit(GGPrediction.HITCHANCE_NORMAL) then
        return 3
    end
    return 2
end

local function IsValid(unit)
    return unit and unit.valid and unit.isTargetable and not unit.dead and unit.visible and unit.health > 0
end

local function GetGGCastPosition(target, spellData, spellType)
    if not IsGGPredictionReady() then
        return nil, 0
    end

    local prediction = GGPrediction:SpellPrediction({
        Type = spellType or GG_TYPE_LINE,
        Delay = spellData.Delay or 0,
        Radius = spellData.Width or 0,
        Range = spellData.Range or MathHuge,
        Speed = spellData.Speed or MathHuge,
        Collision = false
    })
    prediction:GetPrediction(target, myHero)

    local castPos = prediction.CastPosition
    if castPos and castPos.x and castPos.z and GetDistance(myHero.pos, castPos) <= (spellData.Range or MathHuge) + 25 then
        return Vector(castPos.x, target.pos.y or myHero.pos.y, castPos.z), NormalizeGGHitChance(prediction)
    end

    return nil, 0
end

local function GetDepressiveSpellType(spellType)
    if spellType == GG_TYPE_CONE then
        return "cone"
    end
    return "line"
end

local function GetDepressiveCastPosition(target, spellData, spellType)
    if not IsDepressivePredictionReady() then
        return nil, 0
    end

    local ok, prediction = pcall(_G.DepressivePrediction.GetPrediction, target, {
        type = GetDepressiveSpellType(spellType),
        source = myHero,
        speed = spellData.Speed or MathHuge,
        delay = spellData.Delay or 0,
        radius = spellData.Width or 0,
        range = spellData.Range or MathHuge,
        collision = false
    })

    if ok and prediction then
        local castPos = prediction.castPos or prediction.CastPosition or prediction.position
        if castPos and castPos.x and castPos.z and GetDistance(myHero.pos, castPos) <= (spellData.Range or MathHuge) + 25 then
            return Vector(castPos.x, target.pos.y or myHero.pos.y, castPos.z), prediction.hitChance or prediction.HitChance or 2
        end
    end

    local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local legacyOk, _, legacyCastPos = pcall(
        _G.DepressivePrediction.GetPrediction,
        target,
        sourcePos2D,
        spellData.Speed or MathHuge,
        spellData.Delay or 0,
        spellData.Width or 0
    )

    if legacyOk and legacyCastPos and legacyCastPos.x and legacyCastPos.z and GetDistance(myHero.pos, legacyCastPos) <= (spellData.Range or MathHuge) + 25 then
        return Vector(legacyCastPos.x, target.pos.y or myHero.pos.y, legacyCastPos.z), 4
    end

    return nil, 0
end

local function GetPredictedCastPosition(target, spellData, spellType)
    if not target or not IsValid(target) then
        return target and target.pos or nil, 0
    end

    local engine = GetActivePredictionEngine()
    local castPos, hitChance

    if engine == PRED_ENGINE_DEPRESSIVE then
        castPos, hitChance = GetDepressiveCastPosition(target, spellData, spellType)
        if castPos then
            return castPos, hitChance
        end
        castPos, hitChance = GetGGCastPosition(target, spellData, spellType)
        if castPos then
            return castPos, hitChance
        end
    else
        castPos, hitChance = GetGGCastPosition(target, spellData, spellType)
        if castPos then
            return castPos, hitChance
        end
        castPos, hitChance = GetDepressiveCastPosition(target, spellData, spellType)
        if castPos then
            return castPos, hitChance
        end
    end

    return target.pos, 2
end

local function Ready(spell)
    local data = myHero:GetSpellData(spell)
    return data.currentCd == 0 and data.level > 0 and data.mana <= myHero.mana and GameCanUseSpell(spell) == 0
end

local function GetSpellName(spell)
    return myHero:GetSpellData(spell).name
end

local function HasBuff(unit, buffname)
    if not unit then return false end
    local buffLower = buffname:lower()
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name then
            if buff.name:lower() == buffLower or buff.name:lower():find(buffLower) then
                return true, buff
            end
        end
    end
    return false
end

local function GetBuffData(unit, buffname)
    if not unit then return nil end
    local buffLower = buffname:lower()
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name then
            if buff.name:lower() == buffLower or buff.name:lower():find(buffLower) then
                return buff
            end
        end
    end
    return nil
end

local function GetBuffCount(unit, buffname)
    local buff = GetBuffData(unit, buffname)
    return buff and buff.count or 0
end

local function GetBuffStacks(unit, buffname)
    local buff = GetBuffData(unit, buffname)
    return buff and buff.stacks or 0
end

local function HasBuffType(unit, buffType)
    if not unit then return false end
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.type == buffType then
            return true
        end
    end
    return false
end

local function IsMarked(unit)
    return HasBuff(unit, "ireliamark")
end

local function GetPassiveStacks()
    local maxBuff = HasBuff(myHero, "ireliapassivestacksmax")
    if maxBuff then return 5 end
    return GetBuffCount(myHero, "ireliapassivestacks")
end

local function HasMaxPassive()
    return HasBuff(myHero, "ireliapassivestacksmax") or GetPassiveStacks() >= 4
end

local function IsE1Active()
    local eName = GetSpellName(_E)
    return eName and eName:lower():find("ireliae2") ~= nil
end

local function CanUseE()
    return Ready(_E) or IsE1Active()
end

local function IsRecalling(unit)
    return HasBuff(unit, "recall")
end

local function IsImmobile(unit)
    if not unit then return false end
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local t = buff.type
            
            if t == 5 or t == 8 or t == 10 or t == 11 or t == 22 or t == 24 or t == 29 or t == 30 or t == 31 then
                return true, buff.duration
            end
        end
    end
    return false
end

local function IsDashing(unit)
    return unit.pathing and unit.pathing.isDashing
end

local function CantKill(unit, checkLethal, checkSpellShield, checkAA)
    if not unit then return true end
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name then
            local name = buff.name:lower()
            
            if name:find("kayler") then return true end
            
            if name:find("undyingrage") and (unit.health < 100 or checkLethal) then return true end
            
            if name:find("kindredrnodeathbuff") and (checkLethal or (unit.health / unit.maxHealth) < 0.11) then return true end
            
            if name:find("chronoshift") and checkLethal then return true end
            
            if name:find("willrevive") and checkLethal then return true end
            
            if name:find("fioraw") or name:find("pantheone") then return true end
            
            if name:find("jaxcounterstrike") and checkAA then return true end
            
            if name:find("nilahw") and checkAA then return true end
            
            if name:find("shenwbuff") and checkAA then return true end
            
            if name:find("samiraw") then return true end
        end
    end
    
    if checkSpellShield and HasBuffType(unit, 4) then
        return true
    end
    return false
end

local function MyHeroNotReady()
    return myHero.dead or 
           Game.IsChatOpen() or 
           (_G.JustEvade and _G.JustEvade:Evading()) or 
           (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or 
           IsRecalling(myHero)
end

local function GetMode()
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then
        local M = _G.SDK.Orbwalker.Modes
        local SDK = _G.SDK
        
        if SDK.ORBWALKER_MODE_COMBO and M[SDK.ORBWALKER_MODE_COMBO] then return "Combo" end
        if SDK.ORBWALKER_MODE_SPACING and M[SDK.ORBWALKER_MODE_SPACING] then return "Combo" end
        if SDK.ORBWALKER_MODE_HARASS and M[SDK.ORBWALKER_MODE_HARASS] then return "Harass" end
        if (SDK.ORBWALKER_MODE_LANECLEAR and M[SDK.ORBWALKER_MODE_LANECLEAR]) or 
           (SDK.ORBWALKER_MODE_JUNGLECLEAR and M[SDK.ORBWALKER_MODE_JUNGLECLEAR]) then return "Clear" end
        if SDK.ORBWALKER_MODE_LASTHIT and M[SDK.ORBWALKER_MODE_LASTHIT] then return "LastHit" end
        if SDK.ORBWALKER_MODE_FLEE and M[SDK.ORBWALKER_MODE_FLEE] then return "Flee" end
        
        
        if M[0] then return "Combo" end
        if M[6] then return "Combo" end
        if M[1] then return "Harass" end
        if M[2] or M[3] then return "Clear" end
        if M[4] then return "LastHit" end
        if M[5] then return "Flee" end
    end
    
    return "None"
end

local TargetSelectCache = {}

local function GetTarget(range)
    if _G.SDK and _G.SDK.TargetSelector then
        local now = GameTimer()
        local mode = GetMode()
        local interval = (mode == "Combo" or mode == "Harass") and 0.05 or 0.09
        local key = tostring(range) .. ":" .. mode
        local cached = TargetSelectCache[key]

        if cached and now - cached.tick < interval then
            local target = cached.target
            if target and target.valid and not target.dead and target.visible and target.isTargetable and GetDistanceSqr(myHero.pos, target.pos) <= range * range then
                return target
            end
        end

        local target = _G.SDK.TargetSelector:GetTarget(range)
        TargetSelectCache[key] = {target = target, tick = now}
        return target
    end
    return nil
end

local function SetAttack(bool)
    if _G.SDK then
        _G.SDK.Orbwalker:SetAttack(bool)
    end
end

local function SetMovement(bool)
    if _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
    end
end

local function CalcPhysicalDamage(source, target, amount)
    local armorPenPercent = source.armorPenPercent
    local armorPenFlat = source.armorPen * (0.6 + 0.4 * source.levelData.lvl / 18)
    local bonusArmorPenMod = source.bonusArmorPenPercent
    
    local armor = target.armor
    local bonusArmor = target.bonusArmor
    local value
    
    if armor < 0 then
        value = 2 - 100 / (100 - armor)
    elseif armor * armorPenPercent - bonusArmor * (1 - bonusArmorPenMod) - armorPenFlat < 0 then
        value = 1
    else
        value = 100 / (100 + armor * armorPenPercent - bonusArmor * (1 - bonusArmorPenMod) - armorPenFlat)
    end
    
    return MathMax(MathFloor(value * amount), 0)
end

local function CalcMagicalDamage(source, target, amount)
    local totalMR = target.magicResist + target.bonusMagicResist
    local passiveMod
    
    if totalMR < 0 then
        passiveMod = 2 - 100 / (100 - totalMR)
    elseif totalMR * source.magicPenPercent - source.magicPen < 0 then
        passiveMod = 1
    else
        passiveMod = 100 / (100 + totalMR * source.magicPenPercent - source.magicPen)
    end
    
    local dmg = MathMax(MathFloor(passiveMod * amount), 0)
    
    
    if target.charName == "Kassadin" then
        dmg = dmg * 0.85
    elseif target.charName == "Malzahar" and HasBuff(target, "malzaharpassiveshield") then
        dmg = dmg * 0.1
    end
    
    return dmg
end

local function GetOnHitDamage(target, isMinion)
    local lvl = myHero.levelData.lvl
    local physDmg = 0
    local magicDmg = 0
    
    
    if HasMaxPassive() then
        magicDmg = magicDmg + (7 + (3 * lvl)) + 0.20 * myHero.bonusDamage
    end
    
    
    if Cache.Items.BOTRK then
        if isMinion then
            physDmg = physDmg + MathMax(target.health * 0.10, 40)
        else
            physDmg = physDmg + target.health * 0.12
        end
    end
    
    
    if Cache.Items.WitsEnd then
        magicDmg = magicDmg + 15 + (4.44 * lvl)
    end
    
    
    if Cache.Items.Titanic then
        physDmg = physDmg + (myHero.maxHealth * 0.01) + (5 + myHero.maxHealth * 0.015)
    end
    
    
    local sheenDmg = 0
    if Cache.Items.Trinity and myHero:GetSpellData(Cache.Items.Trinity).currentCd == 0 then
        sheenDmg = 2 * myHero.baseDamage
    elseif Cache.Items.Divine and myHero:GetSpellData(Cache.Items.Divine).currentCd == 0 then
        local divDmg = target.maxHealth * 0.10
        if isMinion then
            divDmg = MathMin(MathMax(divDmg, 1.5 * myHero.baseDamage), 2.5 * myHero.baseDamage)
        end
        sheenDmg = divDmg
    elseif Cache.Items.Sheen and myHero:GetSpellData(Cache.Items.Sheen).currentCd == 0 then
        sheenDmg = myHero.baseDamage
    end
    physDmg = physDmg + sheenDmg
    
    return CalcPhysicalDamage(myHero, target, physDmg) + CalcMagicalDamage(myHero, target, magicDmg)
end

local function GetQDamage(target, isMinion)
    local lvl = myHero:GetSpellData(_Q).level
    if lvl == 0 then return 0 end
    
    local baseDmg = -15 + (lvl * 20) 
    if isMinion then
        baseDmg = baseDmg + (43 + (12 * myHero.levelData.lvl))
    end
    local adDmg = 0.6 * myHero.totalDamage
    local total = baseDmg + adDmg
    
    return CalcPhysicalDamage(myHero, target, total) + GetOnHitDamage(target, isMinion)
end

local function GetWDamage(target)
    local lvl = myHero:GetSpellData(_W).level
    if lvl == 0 then return 0 end
    local damage = -15 + (lvl * 45) + 1.2 * myHero.totalDamage + 1.2 * myHero.ap
    return CalcPhysicalDamage(myHero, target, damage)
end

local function GetEDamage(target)
    local lvl = myHero:GetSpellData(_E).level
    if lvl == 0 then return 0 end
    local damage = 35 + (lvl * 45) + 0.8 * myHero.ap
    return CalcMagicalDamage(myHero, target, damage)
end

local function GetRDamage(target)
    local lvl = myHero:GetSpellData(_R).level
    if lvl == 0 then return 0 end
    local damage = -15 + (lvl * 125) + 0.7 * myHero.ap
    return CalcMagicalDamage(myHero, target, damage)
end

local function GetAADamage(target)
    local damage = myHero.totalDamage * (1 + myHero.critChance)
    return CalcPhysicalDamage(myHero, target, damage) + GetOnHitDamage(target, false)
end

local function GetFullComboDamage(target)
    local dmg = 0
    local qCount = 3 
    
    if Ready(_Q) then dmg = dmg + GetQDamage(target, false) * qCount end
    if Ready(_W) then dmg = dmg + GetWDamage(target) end
    if Ready(_E) then dmg = dmg + GetEDamage(target) end
    if Ready(_R) then dmg = dmg + GetRDamage(target) end
    dmg = dmg + GetAADamage(target) * 2
    
    return dmg
end

local function IsUnderTurret(pos, extraRange)
    extraRange = extraRange or 0
    for _, turret in ipairs(Cache.EnemyTurrets) do
        if turret and not turret.dead then
            local turretRange = turret.boundingRadius + 750 + extraRange
            if GetDistance(pos, turret.pos) < turretRange then
                return true
            end
        end
    end
    return false
end

local TeamCountCache = {}

local function GetCachedTeamCount(prefix, units, range, pos, baseCount)
    local now = GameTimer()
    local interval = IsCombatModeActive() and 0.07 or 0.14
    local xBucket = MathFloor((pos.x or 0) / 80)
    local zBucket = MathFloor(((pos.z or pos.y) or 0) / 80)
    local key = prefix .. ":" .. tostring(range) .. ":" .. xBucket .. ":" .. zBucket
    local cached = TeamCountCache[key]

    if cached and now - cached.tick < interval then
        return cached.count
    end

    local count = baseCount or 0
    local rangeSqr = range * range
    for _, hero in ipairs(units) do
        if IsValid(hero) and GetDistanceSqr(pos, hero.pos) < rangeSqr then
            count = count + 1
        end
    end

    TeamCountCache[key] = {tick = now, count = count}
    return count
end

local function GetEnemyCount(range, pos)
    pos = pos or myHero.pos
    return GetCachedTeamCount("enemy", Cache.EnemyHeroes, range, pos, 0)
end

local function GetAllyCount(range, pos)
    pos = pos or myHero.pos
    return GetCachedTeamCount("ally", Cache.AllyHeroes, range, pos, 1)
end

local function GetHealthPred(unit, time)
    if _G.SDK and _G.SDK.HealthPrediction then
        return _G.SDK.HealthPrediction:GetPrediction(unit, time)
    end
    return unit.health
end

local function GetQTravelTime(target)
    local speed = 1400 + myHero.ms
    local dist = GetDistance(myHero.pos, target.pos)
    return dist / speed
end

local function WillQKill(target, isMinion)
    local qDmg = GetQDamage(target, isMinion)
    local time = GetQTravelTime(target)
    local predHealth = GetHealthPred(target, time)
    return qDmg >= predHealth and predHealth > 0
end

local FlashSlot = nil
local function GetFlashSlot()
    if FlashSlot then return FlashSlot end
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" then
        FlashSlot = SUMMONER_1
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" then
        FlashSlot = SUMMONER_2
    end
    return FlashSlot
end

local function IsFlashReady()
    local slot = GetFlashSlot()
    if slot then
        return myHero:GetSpellData(slot).currentCd == 0
    end
    return false
end

local function GetFlashKey()
    local slot = GetFlashSlot()
    if slot == SUMMONER_1 then return HK_SUMMONER_1
    elseif slot == SUMMONER_2 then return HK_SUMMONER_2 end
    return nil
end

local function VectorNormalize(v)
    local len = MathSqrt(v.x * v.x + v.z * v.z)
    if len > 0 then
        return Vector(v.x / len, v.y, v.z / len)
    end
    return Vector(0, v.y, 0)
end

local function VectorRotate(v, angle)
    local cos = MathCos(angle)
    local sin = MathSin(angle)
    return Vector(v.x * cos - v.z * sin, v.y, v.x * sin + v.z * cos)
end

local function VectorPerpendicular(v)
    return Vector(-v.z, v.y, v.x)
end

local function PointToLineDistance(point, lineStart, lineEnd)
    local dx = lineEnd.x - lineStart.x
    local dz = lineEnd.z - lineStart.z
    local lenSq = dx * dx + dz * dz
    
    if lenSq == 0 then
        return GetDistance(point, lineStart), 0
    end
    
    local t = MathMax(0, MathMin(1, ((point.x - lineStart.x) * dx + (point.z - lineStart.z) * dz) / lenSq))
    local projX = lineStart.x + t * dx
    local projZ = lineStart.z + t * dz
    
    local distX = point.x - projX
    local distZ = point.z - projZ
    return MathSqrt(distX * distX + distZ * distZ), t
end

local EMultiTarget = {
    E_WIDTH = 80,
    HITBOX_MARGIN = 30
}

function EMultiTarget:CountEHits(pos1, pos2, enemies)
    local count = 0
    local hitList = {}
    
    for _, enemy in ipairs(enemies) do
        if IsValid(enemy) then
            local dist, t = PointToLineDistance(enemy.pos, pos1, pos2)
            local boundingRadius = enemy.boundingRadius or 65
            local effectiveWidth = (self.E_WIDTH / 2) + boundingRadius
            
            
            if dist <= effectiveWidth and t >= 0 and t <= 1 then
                count = count + 1
                TableInsert(hitList, enemy)
            end
        end
    end
    
    return count, hitList
end

function EMultiTarget:FindBestEPositions(enemies, eRange, sourcePos)
    if #enemies < 2 then return nil, nil, 0 end
    
    
    local validEnemies = {}
    for _, enemy in ipairs(enemies) do
        if IsValid(enemy) and GetDistance(sourcePos, enemy.pos) <= eRange then
            TableInsert(validEnemies, enemy)
        end
    end
    
    if #validEnemies < 2 then return nil, nil, 0 end
    
    local bestE1 = nil
    local bestE2 = nil
    local bestHits = 0
    
    
    for i = 1, #validEnemies do
        for j = i + 1, #validEnemies do
            local enemy1 = validEnemies[i]
            local enemy2 = validEnemies[j]
            
            
            local dir = VectorNormalize(enemy2.pos - enemy1.pos)
            
            
            local extension = 150
            local e1Pos = enemy1.pos - dir * extension
            local e2Pos = enemy2.pos + dir * extension
            
            
            if GetDistance(sourcePos, e1Pos) > eRange then
                e1Pos = sourcePos + VectorNormalize(e1Pos - sourcePos) * (eRange - 10)
            end
            if GetDistance(sourcePos, e2Pos) > eRange then
                e2Pos = sourcePos + VectorNormalize(e2Pos - sourcePos) * (eRange - 10)
            end
            
            
            local hits = self:CountEHits(e1Pos, e2Pos, validEnemies)
            
            if hits > bestHits then
                bestHits = hits
                bestE1 = e1Pos
                bestE2 = e2Pos
            end
        end
    end
    
    
    if bestE1 and bestE2 and bestHits < #validEnemies then
        local dir = VectorNormalize(bestE2 - bestE1)
        local perpDir = Vector(-dir.z, 0, dir.x)
        
        for offset = -100, 100, 25 do
            local shiftedE1 = bestE1 + perpDir * offset
            local shiftedE2 = bestE2 + perpDir * offset
            
            
            if GetDistance(sourcePos, shiftedE1) <= eRange and 
               GetDistance(sourcePos, shiftedE2) <= eRange then
                local hits = self:CountEHits(shiftedE1, shiftedE2, validEnemies)
                if hits > bestHits then
                    bestHits = hits
                    bestE1 = shiftedE1
                    bestE2 = shiftedE2
                end
            end
        end
    end
    
    if bestHits >= 2 then
        return bestE1, bestE2, bestHits
    end
    
    return nil, nil, 0
end

local CurvedR = {
    FLASH_RANGE = 400,
    R_WIDTH = 160,
    R_RANGE = 1000,
    Cache = {
        tick = -1,
        minHit = 0,
        enemyCount = 0,
        target = nil,
        flashPos = nil,
        hitCount = 0,
        rDir = nil
    }
}

function CurvedR:CountRHits(fromPos, direction, width)
    local count = 0
    local hitList = {}
    local rEndPos = fromPos + direction * self.R_RANGE
    
    for _, enemy in ipairs(Cache.EnemyHeroes) do
        if IsValid(enemy) then
            local dist, t = PointToLineDistance(enemy.pos, fromPos, rEndPos)
            
            if dist <= width + enemy.boundingRadius and t >= 0 and t <= 1 then
                count = count + 1
                TableInsert(hitList, enemy)
            end
        end
    end
    
    return count, hitList
end

function CurvedR:FindBestRFlash(minHit)
    local now = GameTimer()
    local interval = IsCombatModeActive() and 0.08 or 0.16
    local cache = self.Cache
    local enemyCount = #Cache.EnemyHeroes

    if cache.minHit == minHit and cache.enemyCount == enemyCount and now - cache.tick < interval then
        return cache.target, cache.flashPos, cache.hitCount, cache.rDir
    end

    local bestTarget = nil
    local bestFlashPos = nil
    local bestHitCount = 0
    local bestRDirection = nil
    
    local validEnemies = {}
    for _, enemy in ipairs(Cache.EnemyHeroes) do
        if IsValid(enemy) and GetDistance(myHero.pos, enemy.pos) <= self.R_RANGE + self.FLASH_RANGE then
            TableInsert(validEnemies, enemy)
        end
    end
    
    if #validEnemies < minHit then return nil, nil, 0, nil end
    
    
    for _, rTarget in ipairs(validEnemies) do
        local rDir = VectorNormalize(rTarget.pos - myHero.pos)
        
        
        local testAngles = {0, 30, 60, 90, 120, 150, 180, -30, -60, -90, -120, -150}
        
        for _, angle in ipairs(testAngles) do
            local flashDir = VectorRotate(rDir, MathRad(angle))
            local flashPos = myHero.pos + flashDir * self.FLASH_RANGE
            
            
            local hitCount = self:CountRHits(flashPos, rDir, self.R_WIDTH)
            
            if hitCount >= minHit and hitCount > bestHitCount then
                bestHitCount = hitCount
                bestTarget = rTarget
                bestFlashPos = flashPos
                bestRDirection = rDir
            end
        end
    end

    cache.tick = now
    cache.minHit = minHit
    cache.enemyCount = enemyCount
    cache.target = bestTarget
    cache.flashPos = bestFlashPos
    cache.hitCount = bestHitCount
    cache.rDir = bestRDirection
    return bestTarget, bestFlashPos, bestHitCount, bestRDirection
end

local QDance = {
    LastQTime = 0,
    QChain = {},
    MaxChainLength = 10,
    PathCache = {
        tick = -1,
        targetId = 0,
        minionCount = 0,
        maxSteps = 0,
        path = {}
    }
}

function QDance:GetKillableMinions(range)
    local killable = {}
    
    for _, minion in ipairs(Cache.EnemyMinions) do
        if IsValid(minion) and GetDistance(myHero.pos, minion.pos) <= range then
            if WillQKill(minion, true) then
                TableInsert(killable, {
                    unit = minion,
                    distance = GetDistance(myHero.pos, minion.pos),
                    health = minion.health
                })
            end
        end
    end
    
    
    TableSort(killable, function(a, b)
        return a.health < b.health
    end)
    
    return killable
end

function QDance:GetBestDanceTarget(enemies, targetEnemy)
    if not targetEnemy then return nil end
    
    local killable = self:GetKillableMinions(SpellData.Q.Range)
    if #killable == 0 then return nil end
    
    local bestMinion = nil
    local bestScore = -MathHuge
    
    for _, data in ipairs(killable) do
        local minion = data.unit
        local distToEnemy = GetDistance(minion.pos, targetEnemy.pos)
        local distToMe = data.distance
        
        
        local score = 1000 - distToEnemy - (distToMe * 0.5)
        
        
        if distToEnemy < GetDistance(myHero.pos, targetEnemy.pos) then
            score = score + 500
        end
        
        
        if IsUnderTurret(minion.pos) then
            score = score - 1000
        end
        
        if score > bestScore then
            bestScore = score
            bestMinion = minion
        end
    end
    
    return bestMinion
end

function QDance:FindDancePath(targetEnemy, maxSteps)
    maxSteps = maxSteps or 5
    local now = GameTimer()
    local interval = IsCombatModeActive() and 0.07 or 0.14
    local cache = self.PathCache

    if cache.targetId == targetEnemy.networkID and cache.minionCount == #Cache.EnemyMinions and cache.maxSteps == maxSteps and now - cache.tick < interval then
        return cache.path or {}
    end

    local path = {}
    local simulatedPos = myHero.pos
    local usedMinions = {}
    
    for step = 1, maxSteps do
        local killable = {}
        
        for _, minion in ipairs(Cache.EnemyMinions) do
            if IsValid(minion) and 
               GetDistance(simulatedPos, minion.pos) <= SpellData.Q.Range and
               not usedMinions[minion.networkID] and
               WillQKill(minion, true) then
                
                local distToEnemy = GetDistance(minion.pos, targetEnemy.pos)
                TableInsert(killable, {
                    unit = minion,
                    distToEnemy = distToEnemy,
                    pos = minion.pos
                })
            end
        end
        
        if #killable == 0 then break end
        
        
        TableSort(killable, function(a, b)
            return a.distToEnemy < b.distToEnemy
        end)
        
        local best = killable[1]
        TableInsert(path, best.unit)
        usedMinions[best.unit.networkID] = true
        simulatedPos = best.pos
        
        
        if GetDistance(simulatedPos, targetEnemy.pos) <= SpellData.Q.Range then
            break
        end
    end

    cache.tick = now
    cache.targetId = targetEnemy.networkID
    cache.minionCount = #Cache.EnemyMinions
    cache.maxSteps = maxSteps
    cache.path = path
    return path
end

local ComboLogic = {
    
    STATE_IDLE = 0,
    STATE_STACKING = 1,
    STATE_ENGAGE = 2,
    STATE_ALL_IN = 3,
    STATE_CLEANUP = 4,
    
    CurrentState = 0,
    LastStateChange = 0,
    ComboTarget = nil,
    
    
    E1CastTime = 0,
    E1Position = nil,
    E2OptimalPos = nil,
    RCastTime = 0,
    RTargetID = nil,
    QAfterR = false
}

function ComboLogic:CanAllIn(target)
    if not target then return false end
    
    local myHP = myHero.health / myHero.maxHealth
    local enemyHP = target.health / target.maxHealth
    local enemyCount = GetEnemyCount(800, target.pos)
    local allyCount = GetAllyCount(800, myHero.pos)
    
    
    local comboDmg = GetFullComboDamage(target)
    local canBurst = comboDmg >= target.health * 0.9
    
    
    if canBurst and myHP > 0.4 then return true end
    if HasMaxPassive() and myHP > enemyHP then return true end
    if enemyHP < 0.3 and myHP > 0.2 then return true end
    if allyCount > enemyCount and myHP > 0.3 then return true end
    
    return false
end

function ComboLogic:ShouldStack()
    if HasMaxPassive() then return false end
    
    local stacks = GetPassiveStacks()
    if stacks >= 3 then return false end 
    
    
    local killable = 0
    for _, minion in ipairs(Cache.EnemyMinions) do
        if IsValid(minion) and GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range then
            if WillQKill(minion, true) then
                killable = killable + 1
            end
        end
    end
    
    return killable >= 1
end

function ComboLogic:GetOptimalComboSequence(target, isTeamfight)
    
    
    local sequence = {}
    local dist = GetDistance(myHero.pos, target.pos)
    local isMarked = IsMarked(target)
    local isE1Out = IsE1Active()
    local canBurst = GetFullComboDamage(target) >= target.health
    local enemyCount = GetEnemyCount(600, target.pos)
    
    
    if isE1Out and CanUseE() then
        TableInsert(sequence, {spell = "E2", priority = 100})
    end
    
    
    if isMarked and Ready(_Q) and dist <= SpellData.Q.Range then
        TableInsert(sequence, {spell = "Q_MARKED", priority = 95})
    end
    
    
    if Ready(_Q) and dist <= SpellData.Q.Range and WillQKill(target, false) then
        TableInsert(sequence, {spell = "Q_KILL", priority = 90})
    end
    
    
    if Ready(_R) and dist <= SpellData.R.Range and not isMarked then
        if canBurst or (isTeamfight and enemyCount >= 2) then
            TableInsert(sequence, {spell = "R", priority = 85})
        end
    end
    
    
    if Ready(_E) and not isE1Out and dist <= SpellData.E.Range and not isMarked then
        TableInsert(sequence, {spell = "E1", priority = 80})
    end
    
    
    if Ready(_Q) and dist > SpellData.Q.Range then
        TableInsert(sequence, {spell = "Q_GAP", priority = 70})
    end
    
    
    if Ready(_W) and dist <= SpellData.W.Range then
        TableInsert(sequence, {spell = "W", priority = 60})
    end
    
    
    TableSort(sequence, function(a, b) return a.priority > b.priority end)
    
    return sequence
end

class "IreliaAdvanced"

function IreliaAdvanced:__init()
    
    self.LastQ = 0
    self.LastE = 0
    self.LastR = 0
    self.LastW = 0
    
    
    self.E1Time = 0
    self.E1Pos = nil
    self.E2OptimalPos = nil
    
    
    self.WCharging = false
    self.WStartTime = 0
    
    
    self.RFlashPending = false
    self.RFlashPos = nil
    self.RFlashTime = 0
    
    
    self.ComboTarget = nil
    self.RTargetID = nil
    self.QUsedAfterR = false
    self.RCastTime = 0
    
    
    self.DanceKey = nil
    self.DanceActive = false
    
    
    self.PendingHiddenE = nil
    self.LastTrackE1 = -1
    self.Perf = {
        KillPath = {
            tick = -1,
            targetId = 0,
            minionCount = 0,
            path = nil
        }
    }
    
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:OnTick() end)
    Callback.Add("Draw", function() self:OnDraw() end)
end

function IreliaAdvanced:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "IreliaAdvanced", name = ScriptName .. " v" .. Version})
    self.Menu:MenuElement({type = MENU, id = "Prediction", name = "Prediction"})
    self.Menu.Prediction:MenuElement({id = "Engine", name = "Prediction Engine", drop = {"GGPrediction", "DepressivePrediction"}, value = 1})
    PredictionMenu = self.Menu.Prediction
    
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo Settings"})
    self.Menu.Combo:MenuElement({name = " ", drop = {"[Advanced Combo Logic]"}})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
    self.Menu.Combo:MenuElement({id = "QMarked", name = "Q on Marked Only", value = true})
    self.Menu.Combo:MenuElement({id = "QKill", name = "Q to Execute", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "Use W", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
    self.Menu.Combo:MenuElement({id = "E1Self", name = "E1 at Self if Target Offscreen", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "Use R", value = true})
    self.Menu.Combo:MenuElement({id = "RAuto", name = "Auto R Min Enemies", value = 2, min = 1, max = 5})
    self.Menu.Combo:MenuElement({id = "RBurst", name = "R for Kill in 1v1", value = true})
    self.Menu.Combo:MenuElement({id = "StackPassive", name = "Stack Passive Before Engage", value = true})
    self.Menu.Combo:MenuElement({id = "Gapclose", name = "Q Gapclose with Minions", value = true})
    
    
    self.Menu:MenuElement({type = MENU, id = "EMulti", name = "E Multi-Target"})
    self.Menu.EMulti:MenuElement({id = "Enable", name = "Enable Multi-Target E", value = true})
    self.Menu.EMulti:MenuElement({id = "MinHit", name = "Min Enemies to Hit", value = 2, min = 2, max = 5})
    self.Menu.EMulti:MenuElement({id = "DrawPreview", name = "Draw E Preview", value = true})
    
    
    self.Menu:MenuElement({type = MENU, id = "RFlash", name = "Curved R-Flash"})
    self.Menu.RFlash:MenuElement({id = "Enable", name = "Enable Curved R-Flash", value = true})
    self.Menu.RFlash:MenuElement({id = "MinHit", name = "Min Enemies", value = 2, min = 2, max = 5})
    self.Menu.RFlash:MenuElement({id = "Key", name = "Force R-Flash Key", key = string.byte("T")})
    self.Menu.RFlash:MenuElement({id = "DrawPreview", name = "Draw R-Flash Preview", value = true})
    
    
    self.Menu:MenuElement({type = MENU, id = "Dance", name = "Q Dance Mode"})
    self.Menu.Dance:MenuElement({id = "Enable", name = "Enable Dance Mode", value = true})
    self.Menu.Dance:MenuElement({id = "Key", name = "Dance Key", key = string.byte("G")})
    self.Menu.Dance:MenuElement({id = "ShowPath", name = "Show Dance Path", value = true})
    
    
    self.Menu:MenuElement({type = MENU, id = "Burst", name = "Burst Mode"})
    self.Menu.Burst:MenuElement({id = "Enable", name = "Enable Smart Burst", value = true})
    self.Menu.Burst:MenuElement({id = "AllIn", name = "All-In when Killable", value = true})
    
    
    self.Menu:MenuElement({type = MENU, id = "Ninja", name = "Ninja Mode"})
    self.Menu.Ninja:MenuElement({id = "Enable", name = "Q Other Marked First", value = true})
    self.Menu.Ninja:MenuElement({name = " ", drop = {"Prioritizes any marked enemy in range"}})
    
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q on Marked", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "Use E", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana %", value = 40, min = 0, max = 100})
    
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q LastHit", value = true})
    self.Menu.Clear:MenuElement({id = "QJungle", name = "Use Q Jungle", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana %", value = 30, min = 0, max = 100})
    
    
    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    self.Menu.Flee:MenuElement({id = "UseQ", name = "Use Q to Flee", value = true})
    self.Menu.Flee:MenuElement({id = "Priority", name = "Priority", drop = {"Marked > Killable > Direction", "Killable > Direction"}})
    
    
    self.Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
    self.Menu.KillSteal:MenuElement({id = "Enable", name = "Enable KillSteal", value = true})
    self.Menu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true})
    self.Menu.KillSteal:MenuElement({id = "UseE", name = "Use E", value = true})
    self.Menu.KillSteal:MenuElement({id = "IgnoreCombo", name = "KS Even in Combo", value = true})
    self.Menu.KillSteal:MenuElement({id = "DrawKillable", name = "Draw Killable Enemies", value = true})
    
    
    self.Menu:MenuElement({type = MENU, id = "Safety", name = "Safety"})
    self.Menu.Safety:MenuElement({id = "TurretCheck", name = "Don't Q Under Turret", value = true})
    self.Menu.Safety:MenuElement({id = "TurretDive", name = "Dive if Enemy HP <=", value = 25, min = 0, max = 100})
    self.Menu.Safety:MenuElement({id = "AntiGap", name = "E Anti-Gapcloser", value = true})
    
    
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    self.Menu.Draw:MenuElement({id = "Enabled", name = "Enable Drawings", value = true})
    self.Menu.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    self.Menu.Draw:MenuElement({id = "E", name = "E Range", value = false})
    self.Menu.Draw:MenuElement({id = "R", name = "R Range", value = false})
    self.Menu.Draw:MenuElement({id = "Killable", name = "Killable Minions", value = true})
    self.Menu.Draw:MenuElement({id = "DmgIndicator", name = "Damage Indicator", value = true})
    self.Menu.Draw:MenuElement({id = "Stacks", name = "Passive Stacks", value = true})
end

function IreliaAdvanced:OnTick()
    if MyHeroNotReady() then return end
    
    LoadHeroes()
    UpdateCache()
    UpdateItemCache()
    
    
    self:TrackE1()
    
    
    self:HandleW()
    
    
    self:HandleRFlash()
    
    
    self:HandleHiddenE()
    
    
    if self.Menu.Dance.Enable:Value() and self.Menu.Dance.Key:Value() then
        self:DanceMode()
        return
    end
    
    
    if self.Menu.RFlash.Key:Value() then
        self:TryRFlashCurved(true)
        return
    end
    
    local Mode = GetMode()
    
    
    if self.Menu.KillSteal.Enable:Value() then
        if Mode ~= "Combo" or self.Menu.KillSteal.IgnoreCombo:Value() then
            self:KillSteal()
        end
    end
    
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
    elseif Mode == "Clear" then
        self:Clear()
    elseif Mode == "LastHit" then
        self:LastHit()
    elseif Mode == "Flee" then
        self:Flee()
    end
end

function IreliaAdvanced:TrackE1()
    local now = GameTimer()
    local interval = (GetMode() == "Combo" or self.Menu.EMulti.DrawPreview:Value()) and 0.05 or 0.09
    if now - self.LastTrackE1 < interval then
        return
    end
    self.LastTrackE1 = now

    local eName = GetSpellName(_E)
    
    if eName == "IreliaE" then
        self.E1Pos = nil
        self.E2OptimalPos = nil
        return
    end
    
    
    if GameMissileCount then
        for i = 1, GameMissileCount() do
            local missile = GameMissile(i)
            if missile and missile.missileData then
                if missile.missileData.name == "IreliaEMissile" and 
                   missile.missileData.owner == myHero.handle then
                    local endPos = missile.missileData.endPos
                    self.E1Pos = Vector(endPos.x, endPos.y, endPos.z)
                end
            end
        end
    end
end

function IreliaAdvanced:HandleW()
    if not self.WCharging then return end
    
    local wBuff = GetBuffData(myHero, "ireliawdefense")
    local target = GetTarget(SpellData.W.Range)
    
    if wBuff and wBuff.duration > 0 and wBuff.duration < 0.95 then
        if target then
            local castPos = GetPredictedCastPosition(target, SpellData.W, GG_TYPE_CONE)
            ControlCastSpell(HK_W, castPos or target.pos)
        end
        self.WCharging = false
        SetAttack(true)
        SetMovement(true)
    end
    
    
    if GameTimer() - self.WStartTime >= SpellData.W.MaxCharge then
        ControlKeyUp(HK_W)
        self.WCharging = false
        SetAttack(true)
        SetMovement(true)
    end
end

function IreliaAdvanced:HandleRFlash()
    if not self.RFlashPending then return end
    
    
    local spell = myHero.activeSpell
    if spell and spell.valid and spell.name and spell.name:lower():find("ireliar") then
        local flashKey = GetFlashKey()
        if flashKey and self.RFlashPos then
            local pos2D = self.RFlashPos:To2D()
            if pos2D and pos2D.onScreen then
                ControlSetCursorPos(pos2D.x, pos2D.y)
                ControlKeyDown(flashKey)
                ControlKeyUp(flashKey)
            end
        end
        self.RFlashPending = false
        self.RFlashPos = nil
    end
    
    
    if GameTimer() - self.RFlashTime > 0.5 then
        self.RFlashPending = false
        self.RFlashPos = nil
    end
end

function IreliaAdvanced:HandleHiddenE()
    
    if not self.PendingHiddenE then return end
    
    
    if GameTimer() - self.PendingHiddenE.castTime > 0.8 then
        self.PendingHiddenE = nil
        return
    end
    
    
    if not self:IsQDashing() then return end
    
    local target = self.PendingHiddenE.target
    if not target or not IsValid(target) then
        self.PendingHiddenE = nil
        return
    end
    
    if self.PendingHiddenE.type == "E1" then
        self:CastE1Hidden(target)
        self.PendingHiddenE = nil
    elseif self.PendingHiddenE.type == "E2" then
        self:CastE2Hidden(target)
        self.PendingHiddenE = nil
    end
end

function IreliaAdvanced:TryRFlashCurved(force)
    if not Ready(_R) or not IsFlashReady() then return false end
    if not self.Menu.RFlash.Enable:Value() and not force then return false end
    if self.RFlashPending then return false end
    
    local minHit = self.Menu.RFlash.MinHit:Value()
    local target, flashPos, hitCount, rDir = CurvedR:FindBestRFlash(minHit)
    
    if target and flashPos and hitCount >= minHit then
        
        local normalHits = CurvedR:CountRHits(myHero.pos, VectorNormalize(target.pos - myHero.pos), CurvedR.R_WIDTH)
        
        if hitCount > normalHits or force then
            
            local castPos = GetPredictedCastPosition(target, SpellData.R, GG_TYPE_LINE)
            ControlCastSpell(HK_R, castPos or target.pos)
            self.RFlashPending = true
            self.RFlashPos = flashPos
            self.RFlashTime = GameTimer()
            self.LastR = GameTimer()
            self.RCastTime = self.LastR
            self.RTargetID = target.networkID
            self.QUsedAfterR = false
            return true
        end
    end
    
    return false
end

function IreliaAdvanced:DanceMode()
    if not Ready(_Q) then return end
    
    local target = GetTarget(1200)
    if not target then return end
    
    
    local path = QDance:FindDancePath(target, 5)
    
    if #path > 0 then
        local nextTarget = path[1]
        if IsValid(nextTarget) and GetDistance(myHero.pos, nextTarget.pos) <= SpellData.Q.Range then
            if WillQKill(nextTarget, true) then
                self:CastQ(nextTarget)
            end
        end
    else
        
        if IsMarked(target) and GetDistance(myHero.pos, target.pos) <= SpellData.Q.Range then
            self:CastQ(target)
        end
    end
end

function IreliaAdvanced:KillSteal()
    for _, enemy in ipairs(Cache.EnemyHeroes) do
        if IsValid(enemy) and not CantKill(enemy, true, true, true) then
            local dist = GetDistance(myHero.pos, enemy.pos)
            local qDmg = GetQDamage(enemy, false)
            local eDmg = GetEDamage(enemy)
            
            
            if self.Menu.KillSteal.UseQ:Value() and Ready(_Q) then
                
                if dist <= SpellData.Q.Range and qDmg >= enemy.health then
                    self:CastQ(enemy)
                    return true
                end
                
                
                if dist <= SpellData.Q.Range and IsMarked(enemy) and qDmg >= enemy.health then
                    self:CastQ(enemy)
                    return true
                end
                
                
                if dist > SpellData.Q.Range and dist <= SpellData.Q.Range * 2.5 and qDmg >= enemy.health then
                    local path = self:FindKillPath(enemy)
                    if path and #path > 0 then
                        local firstMinion = path[1]
                        if IsValid(firstMinion) and GetDistance(myHero.pos, firstMinion.pos) <= SpellData.Q.Range then
                            self:CastQ(firstMinion)
                            return true
                        end
                    end
                end
            end
            
            
            if self.Menu.KillSteal.UseE:Value() and CanUseE() and not Ready(_Q) then
                if dist <= SpellData.E.Range and eDmg >= enemy.health then
                    if IsE1Active() then
                        self:CastE2(enemy)
                    else
                        self:CastE1(enemy)
                    end
                    return true
                end
            end
        end
    end
    return false
end

function IreliaAdvanced:FindKillPath(target)
    local perf = self.Perf and self.Perf.KillPath
    local now = GameTimer()
    local interval = IsCombatModeActive() and 0.08 or 0.14

    if perf and perf.targetId == target.networkID and perf.minionCount == #Cache.EnemyMinions and now - perf.tick < interval then
        return perf.path
    end

    local path = {}
    local simulatedPos = myHero.pos
    local usedMinions = {}
    local maxSteps = 3
    
    for step = 1, maxSteps do
        local bestMinion = nil
        local bestDist = MathHuge
        
        for _, minion in ipairs(Cache.EnemyMinions) do
            if IsValid(minion) and 
               GetDistance(simulatedPos, minion.pos) <= SpellData.Q.Range and
               not usedMinions[minion.networkID] and
               WillQKill(minion, true) then
                
                local distToTarget = GetDistance(minion.pos, target.pos)
                if distToTarget < bestDist then
                    bestDist = distToTarget
                    bestMinion = minion
                end
            end
        end
        
        if not bestMinion then break end
        
        TableInsert(path, bestMinion)
        usedMinions[bestMinion.networkID] = true
        simulatedPos = bestMinion.pos
        
        
        if GetDistance(simulatedPos, target.pos) <= SpellData.Q.Range then
            break
        end
    end
    
    
    local result = nil
    if #path > 0 and GetDistance(path[#path].pos, target.pos) <= SpellData.Q.Range then
        result = path
    end

    if perf then
        perf.tick = now
        perf.targetId = target.networkID
        perf.minionCount = #Cache.EnemyMinions
        perf.path = result
    end

    return result
end

function IreliaAdvanced:Combo()
    local target = GetTarget(SpellData.R.Range)
    if not target or not IsValid(target) then return end
    
    local dist = GetDistance(myHero.pos, target.pos)
    local isE1Out = IsE1Active()
    local isMarked = IsMarked(target)
    local enemyCount = GetEnemyCount(800, myHero.pos)
    local isTeamfight = enemyCount >= 2
    local hasR = Ready(_R)
    
    
    if GameTimer() - self.RCastTime > 3.0 then
        self.RTargetID = nil
        self.QUsedAfterR = false
    end
    
    
    local is1v1 = enemyCount == 1 and GetAllyCount(800, myHero.pos) <= 1
    
    
    if is1v1 and not hasR then
        self:Combo1v1NoR(target)
        return
    end
    
    
    if self.Menu.Combo.StackPassive:Value() and ComboLogic:ShouldStack() and not isMarked then
        self:StackPassive()
        return
    end
    
    
    if self.Menu.RFlash.Enable:Value() and Ready(_R) and IsFlashReady() and isTeamfight then
        if self:TryRFlashCurved(false) then
            return
        end
    end
    
    
    if self.Menu.Burst.Enable:Value() and self.Menu.Combo.RBurst:Value() and 
       Ready(_R) and not isMarked and not CantKill(target, false, true, false) then
        if dist <= SpellData.R.Range and GetFullComboDamage(target) >= target.health then
            self:CastR(target)
            return
        end
    end
    
    
    if self.Menu.Combo.UseR:Value() and Ready(_R) and not isMarked then
        if enemyCount >= self.Menu.Combo.RAuto:Value() then
            self:CastRAOE(target, self.Menu.Combo.RAuto:Value())
            return
        end
    end
    
    
    if self.Menu.Combo.UseE:Value() and Ready(_E) and not isE1Out then
        if dist <= SpellData.E.Range and not isMarked and not CantKill(target, false, true, false) then
            self:CastE1(target)
            return
        end
    end
    
    
    if self.Menu.Combo.UseR:Value() and Ready(_R) and isE1Out then
        if GameTimer() - self.E1Time < 1.5 and dist <= SpellData.R.Range and not isMarked then
            self:CastR(target)
            return
        end
    end
    
    
    if self.Menu.Ninja.Enable:Value() and Ready(_Q) and self.Menu.Combo.UseQ:Value() then
        for _, enemy in ipairs(Cache.EnemyHeroes) do
            if enemy.networkID ~= target.networkID and IsValid(enemy) and 
               IsMarked(enemy) and GetDistance(myHero.pos, enemy.pos) <= SpellData.Q.Range and
               not CantKill(enemy, false, true, true) then
                self:CastQ(enemy)
                return
            end
        end
    end
    
    
    if self.Menu.Combo.UseQ:Value() and Ready(_Q) and dist <= SpellData.Q.Range then
        if self.Menu.Combo.QMarked:Value() and isMarked and not CantKill(target, false, true, true) then
            self:CastQ(target)
            return
        end
        
        if self.Menu.Combo.QKill:Value() and WillQKill(target, false) and not CantKill(target, true, true, true) then
            self:CastQ(target)
            return
        end
    end
    
    
    if self.Menu.Combo.UseE:Value() and isE1Out then
        local shouldE2 = false
        
        if self.RTargetID and target.networkID == self.RTargetID then
            if self.QUsedAfterR or not isMarked or myHero:GetSpellData(_Q).currentCd > 0.5 then
                shouldE2 = true
            end
        else
            shouldE2 = not isMarked
        end
        
        if shouldE2 then
            self:CastE2(target)
            return
        end
    end
    
    
    if self.Menu.Combo.Gapclose:Value() and Ready(_Q) and dist > SpellData.Q.Range then
        self:Gapclose(target)
    end
end

function IreliaAdvanced:Combo1v1NoR(target)
    local dist = GetDistance(myHero.pos, target.pos)
    local isE1Out = IsE1Active()
    local isMarked = IsMarked(target)
    local hasMaxStacks = HasMaxPassive()
    local myHpPercent = myHero.health / myHero.maxHealth
    local enemyHpPercent = target.health / target.maxHealth
    
    

    
    
    if myHpPercent < 0.25 and enemyHpPercent > 0.3 then
        if Ready(_Q) and dist <= SpellData.Q.Range and WillQKill(target, false) then
            self:CastQ(target)
            return
        end
        if Ready(_Q) then
            self:Flee()
        end
        return
    end
    
    
    local isDashing = self:IsQDashing()
    
    
    if isDashing and CanUseE() then
        if isE1Out then
            
            self:CastE2Hidden(target)
            return
        else
            
            self:CastE1Hidden(target)
            return
        end
    end
    
    
    if isE1Out then
        
        if isMarked and Ready(_Q) and dist <= SpellData.Q.Range then
            self:CastQ(target)
            return
        end
        
        if not Ready(_Q) or dist > SpellData.Q.Range then
            self:CastE2(target)
            return
        end
    end
    
    
    if Ready(_Q) and dist <= SpellData.Q.Range and isMarked then
        self:CastQ(target)
        return
    end
    
    
    if Ready(_E) and not isE1Out and Ready(_Q) then
        
        local engageMinion = self:GetBestEngageMinion(target)
        if engageMinion then
            
            self.PendingHiddenE = {
                type = "E1",
                target = target,
                castTime = GameTimer()
            }
            self:CastQ(engageMinion)
            return
        end
        
        
        if dist <= SpellData.E.Range then
            
            local behindPos = myHero.pos - VectorNormalize(target.pos - myHero.pos) * 300
            self:CastE1AtPos(behindPos)
            return
        end
    end
    
    
    if isE1Out and Ready(_Q) and not isMarked then
        local dashMinion = self:GetBestMinionForHiddenE2(target)
        if dashMinion then
            self.PendingHiddenE = {
                type = "E2",
                target = target,
                castTime = GameTimer()
            }
            self:CastQ(dashMinion)
            return
        end
    end
    
    
    if not hasMaxStacks and self.Menu.Combo.StackPassive:Value() then
        local stacked = self:StackPassiveNearTarget(target)
        if stacked then return end
    end
    
    
    if Ready(_Q) and dist <= SpellData.Q.Range then
        if WillQKill(target, false) and not CantKill(target, true, true, true) then
            self:CastQ(target)
            return
        end
    end
    
    
    local canWinTrade = hasMaxStacks or myHpPercent > enemyHpPercent or enemyHpPercent < 0.4
    if Ready(_Q) and dist > SpellData.Q.Range and canWinTrade then
        self:Gapclose(target)
    end
end

function IreliaAdvanced:IsQDashing()
    
    local spell = myHero.activeSpell
    if spell and spell.valid and spell.name then
        local spellName = spell.name:lower()
        if spellName:find("ireliaq") then
            return true
        end
    end
    
    
    if myHero.pathing and myHero.pathing.isDashing then
        return true
    end
    
    return false
end

function IreliaAdvanced:CastE1Hidden(target)
    
    if not Ready(_E) or IsE1Active() then return end
    
    local dashEndPos = self:GetQDashEndPosition()
    if not dashEndPos then
        dashEndPos = myHero.pos
    end
    
    
    local predictedPos = GetPredictedCastPosition(target, SpellData.E, GG_TYPE_LINE) or target.pos
    local dirToTarget = VectorNormalize(predictedPos - dashEndPos)
    local e1Pos = dashEndPos - dirToTarget * 250
    
    
    if GetDistance(myHero.pos, e1Pos) > SpellData.E.Range then
        e1Pos = myHero.pos + VectorNormalize(e1Pos - myHero.pos) * (SpellData.E.Range - 50)
    end
    
    
    self.E2OptimalPos = predictedPos + dirToTarget * 150
    
    ControlCastSpell(HK_E, e1Pos)
    self.LastE = GameTimer()
    self.E1Time = GameTimer()
    self.E1Pos = e1Pos
end

function IreliaAdvanced:CastE2Hidden(target)
    
    if not IsE1Active() then return end
    if not self.E1Pos then return end
    
    local castPos = nil
    
    
    if self.E2OptimalPos and GetDistance(myHero.pos, self.E2OptimalPos) <= SpellData.E.Range then
        castPos = self.E2OptimalPos
    else
        
        local predictedPos = GetPredictedCastPosition(target, SpellData.E, GG_TYPE_LINE) or target.pos
        local dir = VectorNormalize(predictedPos - self.E1Pos)
        castPos = predictedPos + dir * 150
        
        if GetDistance(myHero.pos, castPos) > SpellData.E.Range then
            castPos = myHero.pos + VectorNormalize(castPos - myHero.pos) * (SpellData.E.Range - 50)
        end
    end
    
    if castPos then
        ControlCastSpell(HK_E, castPos)
        self.LastE = GameTimer()
        self.E2OptimalPos = nil
    end
end

function IreliaAdvanced:CastE1AtPos(pos)
    if not Ready(_E) or IsE1Active() then return end
    
    if GetDistance(myHero.pos, pos) > SpellData.E.Range then
        pos = myHero.pos + VectorNormalize(pos - myHero.pos) * (SpellData.E.Range - 50)
    end
    
    ControlCastSpell(HK_E, pos)
    self.LastE = GameTimer()
    self.E1Time = GameTimer()
    self.E1Pos = pos
end

function IreliaAdvanced:GetQDashEndPosition()
    local spell = myHero.activeSpell
    if spell and spell.valid and spell.name and spell.name:lower():find("ireliaq") then
        if spell.placementPos then
            return Vector(spell.placementPos.x, spell.placementPos.y, spell.placementPos.z)
        end
    end
    return nil
end

function IreliaAdvanced:GetBestEngageMinion(target)
    
    
    
    
    
    local best = nil
    local bestScore = -MathHuge
    
    for _, minion in ipairs(Cache.EnemyMinions) do
        if IsValid(minion) and 
           GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range and
           WillQKill(minion, true) and
           not IsUnderTurret(minion.pos) then
            
            local distToTarget = GetDistance(minion.pos, target.pos)
            local distMeToMinion = GetDistance(myHero.pos, minion.pos)
            local distMeToTarget = GetDistance(myHero.pos, target.pos)
            
            
            local score = 0
            
            
            if distToTarget <= SpellData.E.Range - 100 then
                score = score + 1000
            end
            
            
            if distToTarget < distMeToTarget then
                score = score + (distMeToTarget - distToTarget)
            end
            
            
            if distMeToMinion >= 300 then
                score = score + 200
            end
            
            
            if distToTarget > SpellData.E.Range then
                score = score - 500
            end
            
            if score > bestScore then
                bestScore = score
                best = minion
            end
        end
    end
    
    return best
end

function IreliaAdvanced:GetBestMinionForHiddenE2(target)
    
    
    
    local best = nil
    local bestScore = -MathHuge
    
    for _, minion in ipairs(Cache.EnemyMinions) do
        if IsValid(minion) and 
           GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range and
           WillQKill(minion, true) then
            
            local distToTarget = GetDistance(minion.pos, target.pos)
            local distMeToMinion = GetDistance(myHero.pos, minion.pos)
            
            
            local canE2HitTarget = false
            if self.E1Pos then
                
                local e1ToMinion = VectorNormalize(minion.pos - self.E1Pos)
                local e1ToTarget = VectorNormalize(target.pos - self.E1Pos)
                local dot = e1ToMinion.x * e1ToTarget.x + e1ToMinion.z * e1ToTarget.z
                
                
                if dot > 0.5 then
                    canE2HitTarget = true
                end
            end
            
            local score = 0
            
            if canE2HitTarget then
                score = score + 1000
            end
            
            
            score = score + distMeToMinion * 0.5
            
            
            score = score - distToTarget
            
            if score > bestScore then
                bestScore = score
                best = minion
            end
        end
    end
    
    return best
end

function IreliaAdvanced:StackPassiveNearTarget(target)
    if HasMaxPassive() or not Ready(_Q) then return false end
    
    local targetDist = GetDistance(myHero.pos, target.pos)
    
    for _, minion in ipairs(Cache.EnemyMinions) do
        if IsValid(minion) and GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range then
            
            local minionToTarget = GetDistance(minion.pos, target.pos)
            if minionToTarget <= targetDist + 200 and WillQKill(minion, true) then
                self:CastQ(minion)
                return true
            end
        end
    end
    return false
end

function IreliaAdvanced:GetBestMinionNearTarget(target, range)
    local best = nil
    local bestDist = MathHuge
    
    for _, minion in ipairs(Cache.EnemyMinions) do
        if IsValid(minion) and 
           GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range and
           WillQKill(minion, true) then
            local distToTarget = GetDistance(minion.pos, target.pos)
            if distToTarget <= range and distToTarget < bestDist then
                bestDist = distToTarget
                best = minion
            end
        end
    end
    
    return best
end

function IreliaAdvanced:StartW()
    if not Ready(_W) or self.WCharging then return end
    
    ControlKeyDown(HK_W)
    self.WCharging = true
    self.WStartTime = GameTimer()
    SetAttack(false)
end

function IreliaAdvanced:Harass()
    if myHero.mana / myHero.maxMana * 100 < self.Menu.Harass.Mana:Value() then return end
    
    local target = GetTarget(SpellData.E.Range)
    if not target or not IsValid(target) then return end
    
    local dist = GetDistance(myHero.pos, target.pos)
    
    if self.Menu.Harass.UseE:Value() and CanUseE() then
        if IsE1Active() then
            self:CastE2(target)
        elseif dist <= SpellData.E.Range then
            self:CastE1(target)
        end
    end
    
    if self.Menu.Harass.UseQ:Value() and Ready(_Q) and dist <= SpellData.Q.Range then
        if IsMarked(target) and not CantKill(target, false, true, true) then
            self:CastQ(target)
        end
    end
end

function IreliaAdvanced:Clear()
    if myHero.mana / myHero.maxMana * 100 < self.Menu.Clear.Mana:Value() then return end
    
    
    if self.Menu.Clear.UseQ:Value() and Ready(_Q) then
        for _, minion in ipairs(Cache.EnemyMinions) do
            if IsValid(minion) and GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range then
                if WillQKill(minion, true) then
                    self:CastQ(minion)
                    return
                end
            end
        end
    end
    
    
    if self.Menu.Clear.QJungle:Value() and Ready(_Q) then
        for _, mob in ipairs(Cache.JungleMobs) do
            if IsValid(mob) and GetDistance(myHero.pos, mob.pos) <= SpellData.Q.Range then
                if WillQKill(mob, true) or IsMarked(mob) then
                    self:CastQ(mob)
                    return
                end
            end
        end
    end
end

function IreliaAdvanced:LastHit()
    if not self.Menu.Clear.UseQ:Value() or not Ready(_Q) then return end
    
    for _, minion in ipairs(Cache.EnemyMinions) do
        if IsValid(minion) and GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range then
            if WillQKill(minion, true) then
                self:CastQ(minion)
                return
            end
        end
    end
end

function IreliaAdvanced:Flee()
    if not self.Menu.Flee.UseQ:Value() or not Ready(_Q) then return end
    
    local mousePos = Game.mousePos()
    local bestTarget = nil
    local bestDist = 400
    
    
    for _, enemy in ipairs(Cache.EnemyHeroes) do
        if IsValid(enemy) and GetDistance(myHero.pos, enemy.pos) <= SpellData.Q.Range and IsMarked(enemy) then
            local distToMouse = GetDistance(enemy.pos, mousePos)
            if distToMouse < bestDist then
                bestDist = distToMouse
                bestTarget = enemy
            end
        end
    end
    
    
    local allMinions = {}
    for _, m in ipairs(Cache.EnemyMinions) do TableInsert(allMinions, m) end
    for _, m in ipairs(Cache.JungleMobs) do TableInsert(allMinions, m) end
    
    for _, minion in ipairs(allMinions) do
        if IsValid(minion) and GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range then
            if WillQKill(minion, true) or IsMarked(minion) then
                local distToMouse = GetDistance(minion.pos, mousePos)
                if distToMouse < bestDist then
                    bestDist = distToMouse
                    bestTarget = minion
                end
            end
        end
    end
    
    if bestTarget then
        self:CastQ(bestTarget)
    end
end

function IreliaAdvanced:StackPassive()
    if HasMaxPassive() or not Ready(_Q) then return end
    if myHero.mana / myHero.maxMana * 100 < 40 then return end
    
    for _, minion in ipairs(Cache.EnemyMinions) do
        if IsValid(minion) and GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range then
            if WillQKill(minion, true) then
                self:CastQ(minion)
                return
            end
        end
    end
end

function IreliaAdvanced:Gapclose(target)
    if not Ready(_Q) then return end
    
    local bestMinion = nil
    local bestDist = GetDistance(myHero.pos, target.pos)
    
    local allMinions = {}
    for _, m in ipairs(Cache.EnemyMinions) do TableInsert(allMinions, m) end
    
    for _, minion in ipairs(allMinions) do
        if IsValid(minion) and GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range then
            if (WillQKill(minion, true) or IsMarked(minion)) and not IsUnderTurret(minion.pos) then
                local distToTarget = GetDistance(minion.pos, target.pos)
                if distToTarget < bestDist then
                    bestDist = distToTarget
                    bestMinion = minion
                end
            end
        end
    end
    
    if bestMinion then
        self:CastQ(bestMinion)
    end
end

function IreliaAdvanced:CastQ(target)
    if not Ready(_Q) then return end
    if GameTimer() - self.LastQ < 0.15 then return end
    
    
    if self.Menu.Safety.TurretCheck:Value() and IsUnderTurret(target.pos) then
        if target.type == Obj_AI_Hero then
            local hpPercent = (target.health / target.maxHealth) * 100
            if hpPercent > self.Menu.Safety.TurretDive:Value() then
                return
            end
        else
            return
        end
    end
    
    
    if self.RTargetID and target.networkID == self.RTargetID and IsMarked(target) then
        self.QUsedAfterR = true
    end
    
    ControlCastSpell(HK_Q, target)
    self.LastQ = GameTimer()
end

function IreliaAdvanced:CastE1(target)
    if not Ready(_E) then return end
    if GameTimer() - self.LastE < 0.25 then return end
    if GetSpellName(_E) ~= "IreliaE" then return end
    
    local castPos = nil
    
    
    if self.Menu.EMulti.Enable:Value() then
        local enemies = {}
        for _, enemy in ipairs(Cache.EnemyHeroes) do
            if IsValid(enemy) and GetDistance(myHero.pos, enemy.pos) <= SpellData.E.Range then
                TableInsert(enemies, enemy)
            end
        end
        
        if #enemies >= self.Menu.EMulti.MinHit:Value() then
            local e1, e2, hits = EMultiTarget:FindBestEPositions(enemies, SpellData.E.Range, myHero.pos)
            if e1 and e2 and hits >= self.Menu.EMulti.MinHit:Value() then
                castPos = e1
                self.E2OptimalPos = e2
            end
        end
    end
    
    
    if not castPos then
        local predictedPos = GetPredictedCastPosition(target, SpellData.E, GG_TYPE_LINE) or target.pos
        local dir = VectorNormalize(predictedPos - myHero.pos)
        castPos = predictedPos + dir * 150
        self.E2OptimalPos = predictedPos - dir * 150
    end
    
    
    if castPos then
        local actualCastPos = castPos
        local pos2D = castPos:To2D()
        if pos2D and pos2D.onScreen then
            SetMovement(false)
            ControlCastSpell(HK_E, castPos)
            SetMovement(true)
        elseif self.Menu.Combo.E1Self:Value() then
            
            ControlCastSpell(HK_E, myHero.pos)
            local predictedPos = GetPredictedCastPosition(target, SpellData.E, GG_TYPE_LINE) or target.pos
            local dir = VectorNormalize(predictedPos - myHero.pos)
            self.E2OptimalPos = predictedPos + dir * 150
            actualCastPos = myHero.pos
        end
        
        self.LastE = GameTimer()
        self.E1Time = GameTimer()
        self.E1Pos = actualCastPos
    end
end

function IreliaAdvanced:CastE2(target)
    if GameTimer() - self.LastE < 0.05 then return end
    if not IsE1Active() then return end
    if not self.E1Pos then return end
    
    local castPos = nil
    
    
    if self.E2OptimalPos and GetDistance(myHero.pos, self.E2OptimalPos) <= SpellData.E.Range then
        castPos = self.E2OptimalPos
    else
        
        local predictedPos = GetPredictedCastPosition(target, SpellData.E, GG_TYPE_LINE) or target.pos
        local dir = VectorNormalize(self.E1Pos - predictedPos)
        castPos = predictedPos - dir * 150
        
        if GetDistance(myHero.pos, castPos) > SpellData.E.Range then
            castPos = predictedPos - dir * 50
        end
    end
    
    if castPos then
        if GetDistance(myHero.pos, castPos) > SpellData.E.Range then
            castPos = myHero.pos + VectorNormalize(castPos - myHero.pos) * (SpellData.E.Range - 25)
        end
        SetMovement(false)
        ControlCastSpell(HK_E, castPos)
        SetMovement(true)
        self.LastE = GameTimer()
        self.E2OptimalPos = nil
    end
end

function IreliaAdvanced:CastR(target)
    if not Ready(_R) then return end
    if GameTimer() - self.LastR < 0.3 then return end
    
    local castPos = GetPredictedCastPosition(target, SpellData.R, GG_TYPE_LINE)
    ControlCastSpell(HK_R, castPos or target.pos)
    self.LastR = GameTimer()
    self.RCastTime = GameTimer()
    self.RTargetID = target.networkID
    self.QUsedAfterR = false
end

function IreliaAdvanced:CastRAOE(target, minHit)
    if not Ready(_R) then return end
    if GameTimer() - self.LastR < 0.3 then return end
    
    local bestTarget = target
    local bestCount = 1
    
    for _, enemy in ipairs(Cache.EnemyHeroes) do
        if IsValid(enemy) then
            local count = 0
            for _, enemy2 in ipairs(Cache.EnemyHeroes) do
                if IsValid(enemy2) and GetDistance(enemy.pos, enemy2.pos) < 350 then
                    count = count + 1
                end
            end
            if count > bestCount then
                bestCount = count
                bestTarget = enemy
            end
        end
    end
    
    if bestCount >= minHit then
        local castPos = GetPredictedCastPosition(bestTarget, SpellData.R, GG_TYPE_LINE)
        ControlCastSpell(HK_R, castPos or bestTarget.pos)
        self.LastR = GameTimer()
        self.RCastTime = self.LastR
        self.RTargetID = bestTarget.networkID
        self.QUsedAfterR = false
    end
end

function IreliaAdvanced:OnDraw()
    if myHero.dead or not self.Menu.Draw.Enabled:Value() then return end
    
    
    if self.Menu.Draw.Q:Value() and Ready(_Q) then
        DrawCircle(myHero.pos, SpellData.Q.Range, 1, DrawColor(255, 255, 200, 0))
    end
    
    if self.Menu.Draw.E:Value() and Ready(_E) then
        DrawCircle(myHero.pos, SpellData.E.Range, 1, DrawColor(255, 0, 255, 255))
    end
    
    if self.Menu.Draw.R:Value() and Ready(_R) then
        DrawCircle(myHero.pos, SpellData.R.Range, 1, DrawColor(255, 255, 0, 0))
    end
    
    
    if self.Menu.Draw.Killable:Value() and Ready(_Q) then
        for _, minion in ipairs(Cache.EnemyMinions) do
            if IsValid(minion) and GetDistance(myHero.pos, minion.pos) <= 800 then
                if WillQKill(minion, true) then
                    DrawCircle(minion.pos, 35, 3, DrawColor(255, 0, 255, 0))
                end
            end
        end
    end
    
    
    if self.Menu.Draw.Stacks:Value() then
        local stacks = GetPassiveStacks()
        local color = HasMaxPassive() and DrawColor(255, 0, 255, 0) or DrawColor(255, 255, 255, 0)
        local text = HasMaxPassive() and "MAX" or tostring(stacks)
        DrawText("Passive: " .. text, 18, 100, 100, color)
    end
    
    
    if self.Menu.EMulti.DrawPreview:Value() and Ready(_E) and GetMode() == "Combo" then
        local eName = GetSpellName(_E)
        
        if eName == "IreliaE2" and self.E1Pos and self.E2OptimalPos then
            local e1Screen = self.E1Pos:To2D()
            local e2Screen = self.E2OptimalPos:To2D()
            if e1Screen.onScreen and e2Screen.onScreen then
                DrawLine(e1Screen.x, e1Screen.y, e2Screen.x, e2Screen.y, 3, DrawColor(255, 0, 255, 255))
            end
        elseif eName == "IreliaE" then
            local enemies = {}
            for _, enemy in ipairs(Cache.EnemyHeroes) do
                if IsValid(enemy) and GetDistance(myHero.pos, enemy.pos) <= SpellData.E.Range then
                    TableInsert(enemies, enemy)
                end
            end
            
            if #enemies >= 2 then
                local e1, e2, hits = EMultiTarget:FindBestEPositions(enemies, SpellData.E.Range, myHero.pos)
                if e1 and e2 and hits >= 2 then
                    local e1Screen = e1:To2D()
                    local e2Screen = e2:To2D()
                    if e1Screen.onScreen and e2Screen.onScreen then
                        DrawLine(e1Screen.x, e1Screen.y, e2Screen.x, e2Screen.y, 2, DrawColor(200, 0, 255, 255))
                        DrawCircle(e1, 50, 2, DrawColor(200, 0, 255, 255))
                        DrawCircle(e2, 50, 2, DrawColor(200, 255, 255, 0))
                    end
                    
                    local midPoint = Vector((e1.x + e2.x) / 2, e1.y, (e1.z + e2.z) / 2)
                    local textPos = midPoint:To2D()
                    if textPos.onScreen then
                        DrawText("E: " .. hits .. " hits", 16, textPos.x - 25, textPos.y - 20, DrawColor(255, 0, 255, 255))
                    end
                end
            end
        end
    end
    
    
    if self.Menu.RFlash.DrawPreview:Value() and Ready(_R) and IsFlashReady() and GetMode() == "Combo" then
        local minHit = self.Menu.RFlash.MinHit:Value()
        local target, flashPos, hitCount, rDir = CurvedR:FindBestRFlash(minHit)
        
        if target and flashPos and hitCount >= minHit then
            DrawCircle(flashPos, 100, 2, DrawColor(255, 255, 165, 0))
            
            local startScreen = myHero.pos:To2D()
            local endScreen = flashPos:To2D()
            if startScreen.onScreen and endScreen.onScreen then
                DrawLine(startScreen.x, startScreen.y, endScreen.x, endScreen.y, 2, DrawColor(255, 255, 165, 0))
            end
            
            local rEndScreen = target.pos:To2D()
            if endScreen.onScreen and rEndScreen.onScreen then
                DrawLine(endScreen.x, endScreen.y, rEndScreen.x, rEndScreen.y, 3, DrawColor(255, 255, 0, 0))
            end
            
            local textPos = flashPos:To2D()
            if textPos.onScreen then
                DrawText("R-Flash: " .. hitCount .. " hits", 18, textPos.x - 40, textPos.y - 30, DrawColor(255, 0, 255, 0))
            end
        end
    end
    
    
    if self.Menu.Dance.ShowPath:Value() and self.Menu.Dance.Key:Value() then
        local target = GetTarget(1200)
        if target then
            local path = QDance:FindDancePath(target, 5)
            local currentPos = myHero.pos
            
            for i, minion in ipairs(path) do
                if IsValid(minion) then
                    local startScreen = currentPos:To2D()
                    local endScreen = minion.pos:To2D()
                    if startScreen.onScreen and endScreen.onScreen then
                        DrawLine(startScreen.x, startScreen.y, endScreen.x, endScreen.y, 2, DrawColor(255, 255, 200, 0))
                        DrawText(tostring(i), 14, endScreen.x - 5, endScreen.y - 10, DrawColor(255, 255, 255, 255))
                    end
                    currentPos = minion.pos
                end
            end
            
            
            if #path > 0 then
                local lastPos = path[#path].pos
                local targetScreen = target.pos:To2D()
                local lastScreen = lastPos:To2D()
                if lastScreen.onScreen and targetScreen.onScreen then
                    DrawLine(lastScreen.x, lastScreen.y, targetScreen.x, targetScreen.y, 2, DrawColor(255, 255, 0, 0))
                end
            end
        end
    end
    
    
    if self.Menu.Draw.DmgIndicator:Value() then
        for _, enemy in ipairs(Cache.EnemyHeroes) do
            if IsValid(enemy) then
                local pos = enemy.pos:To2D()
                if pos.onScreen then
                    local dmg = GetFullComboDamage(enemy)
                    local killable = dmg >= enemy.health
                    local text = killable and "KILLABLE" or string.format("%.0f%%", (dmg / enemy.health) * 100)
                    local color = killable and DrawColor(255, 0, 255, 0) or DrawColor(255, 255, 200, 0)
                    DrawText(text, 16, pos.x - 30, pos.y - 50, color)
                end
            end
        end
    end
    
    
    if self.Menu.KillSteal.DrawKillable:Value() then
        for _, enemy in ipairs(Cache.EnemyHeroes) do
            if IsValid(enemy) then
                local pos = enemy.pos:To2D()
                if pos.onScreen then
                    local dist = GetDistance(myHero.pos, enemy.pos)
                    local qDmg = GetQDamage(enemy, false)
                    local canKS = false
                    local ksMethod = ""
                    
                    if Ready(_Q) and dist <= SpellData.Q.Range and qDmg >= enemy.health then
                        canKS = true
                        ksMethod = "Q"
                    elseif Ready(_Q) and dist <= SpellData.Q.Range * 2.5 and qDmg >= enemy.health then
                        local path = self:FindKillPath(enemy)
                        if path and #path > 0 then
                            canKS = true
                            ksMethod = "Q(" .. #path .. ")"
                        end
                    end

                    if canKS then
                        DrawCircle(enemy.pos, 100, 3, DrawColor(255, 255, 0, 0))
                        DrawText("KS: " .. ksMethod, 18, pos.x - 25, pos.y - 70, DrawColor(255, 255, 0, 0))
                    end
                end
            end
        end
    end
end

IreliaAdvanced()
