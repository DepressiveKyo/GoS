if _G.__DEPRESSIVE_IRELIA_ADVANCED_LOADED then return end
_G.__DEPRESSIVE_IRELIA_ADVANCED_LOADED = true

local Version = "1.0"
local ScriptName = "Depressive Irelia Advanced"

if myHero.charName ~= "Irelia" then return end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LOAD PREDICTION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

require("DepressivePrediction")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
        print("[Irelia Advanced] DepressivePrediction loaded successfully!")
    end
end, 1.0)

-- ═══════════════════════════════════════════════════════════════════════════════
-- LOCALIZED FUNCTIONS (Performance)
-- ═══════════════════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════════════════
-- SPELL DATA
-- ═══════════════════════════════════════════════════════════════════════════════

local SpellData = {
    Q = {
        Range = 600,
        Speed = 1400 + myHero.ms, -- Irelia Q speed scales with MS
        Delay = 0,
        Width = 0,
        MinionBonus = 43 -- Base minion bonus damage at level 1
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
        Width = 70, -- Stun line width
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- CACHE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local Cache = {
    EnemyHeroes = {},
    AllyHeroes = {},
    EnemyMinions = {},
    AllyMinions = {},
    JungleMobs = {},
    EnemyTurrets = {},
    LastUpdate = 0,
    UpdateInterval = 0.05,
    HeroesLoaded = false,
    
    -- Item cache
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
    
    -- Spell state cache
    Spells = {
        E1Active = false,
        E1Position = nil,
        E1CastTime = 0,
        WCharging = false,
        WStartTime = 0
    }
}

local function UpdateCache()
    if GameTimer() - Cache.LastUpdate < Cache.UpdateInterval then return end
    Cache.LastUpdate = GameTimer()
    
    -- Update heroes
    Cache.EnemyHeroes = {}
    Cache.AllyHeroes = {}
    for i = 1, GameHeroCount() do
        local unit = GameHero(i)
        if unit and unit.valid then
            if unit.isEnemy and not unit.dead and unit.visible and unit.isTargetable then
                TableInsert(Cache.EnemyHeroes, unit)
            elseif unit.team == TEAM_ALLY and unit ~= myHero and not unit.dead then
                TableInsert(Cache.AllyHeroes, unit)
            end
        end
    end
    
    -- Update minions
    Cache.EnemyMinions = {}
    Cache.AllyMinions = {}
    Cache.JungleMobs = {}
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and minion.valid and not minion.dead and minion.visible and minion.isTargetable then
            if minion.team == TEAM_JUNGLE then
                TableInsert(Cache.JungleMobs, minion)
            elseif minion.isEnemy then
                TableInsert(Cache.EnemyMinions, minion)
            elseif minion.team == TEAM_ALLY then
                TableInsert(Cache.AllyMinions, minion)
            end
        end
    end
    
    -- Update turrets
    Cache.EnemyTurrets = {}
    for i = 1, GameTurretCount() do
        local turret = GameTurret(i)
        if turret and turret.isEnemy and not turret.dead then
            TableInsert(Cache.EnemyTurrets, turret)
        end
    end
end

local function UpdateItemCache()
    if GameTimer() - Cache.Items.LastUpdate < Cache.Items.UpdateInterval then return end
    Cache.Items.LastUpdate = GameTimer()
    
    local itemIDs = {
        BOTRK = 3153,
        WitsEnd = 3091,
        Titanic = 3748,
        Sheen = 3057,
        Trinity = 3078,
        Divine = 6632,
        Iceborn = 3110
    }
    
    for name, id in pairs(itemIDs) do
        Cache.Items[name] = nil
        for slot = ITEM_1, ITEM_7 do
            if myHero:GetItemData(slot).itemID == id then
                Cache.Items[name] = slot
                break
            end
        end
    end
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

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

local function IsValid(unit)
    return unit and unit.valid and unit.isTargetable and not unit.dead and unit.visible and unit.health > 0
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- IRELIA SPECIFIC HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

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
    return eName == "IreliaE2"
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
            -- Stun, Snare, Suppress, Knockup, Taunt, Charm, Fear
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
            -- Kayle R
            if name:find("kayler") then return true end
            -- Tryndamere R
            if name:find("undyingrage") and (unit.health < 100 or checkLethal) then return true end
            -- Kindred R
            if name:find("kindredrnodeathbuff") and (checkLethal or (unit.health / unit.maxHealth) < 0.11) then return true end
            -- Zilean R
            if name:find("chronoshift") and checkLethal then return true end
            -- GA
            if name:find("willrevive") and checkLethal then return true end
            -- Fiora W / Pantheon E
            if name:find("fioraw") or name:find("pantheone") then return true end
            -- Jax E
            if name:find("jaxcounterstrike") and checkAA then return true end
            -- Nilah W
            if name:find("nilahw") and checkAA then return true end
            -- Shen W
            if name:find("shenwbuff") and checkAA then return true end
            -- Samira W
            if name:find("samiraw") then return true end
        end
    end
    -- Spell Shield
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- ORBWALKER INTEGRATION
-- ═══════════════════════════════════════════════════════════════════════════════

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
        
        -- Fallback numeric indices
        if M[0] then return "Combo" end
        if M[6] then return "Combo" end
        if M[1] then return "Harass" end
        if M[2] or M[3] then return "Clear" end
        if M[4] then return "LastHit" end
        if M[5] then return "Flee" end
    end
    
    return "None"
end

local function GetTarget(range)
    if _G.SDK and _G.SDK.TargetSelector then
        return _G.SDK.TargetSelector:GetTarget(range)
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- DAMAGE CALCULATIONS
-- ═══════════════════════════════════════════════════════════════════════════════

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
    
    -- Champion-specific reductions
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
    
    -- Passive Stacks (Ionian Fervor)
    if HasMaxPassive() then
        magicDmg = magicDmg + (7 + (3 * lvl)) + 0.20 * myHero.bonusDamage
    end
    
    -- BOTRK
    if Cache.Items.BOTRK then
        if isMinion then
            physDmg = physDmg + MathMax(target.health * 0.10, 40)
        else
            physDmg = physDmg + target.health * 0.12
        end
    end
    
    -- Wit's End
    if Cache.Items.WitsEnd then
        magicDmg = magicDmg + 15 + (4.44 * lvl)
    end
    
    -- Titanic Hydra
    if Cache.Items.Titanic then
        physDmg = physDmg + (myHero.maxHealth * 0.01) + (5 + myHero.maxHealth * 0.015)
    end
    
    -- Sheen/Trinity/Divine proc
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
    
    local baseDmg = -15 + (lvl * 20) -- 5/25/45/65/85
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
    local qCount = 3 -- Assume 3 Q resets in full combo
    
    if Ready(_Q) then dmg = dmg + GetQDamage(target, false) * qCount end
    if Ready(_W) then dmg = dmg + GetWDamage(target) end
    if Ready(_E) then dmg = dmg + GetEDamage(target) end
    if Ready(_R) then dmg = dmg + GetRDamage(target) end
    dmg = dmg + GetAADamage(target) * 2
    
    return dmg
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- TURRET & SAFETY CHECKS
-- ═══════════════════════════════════════════════════════════════════════════════

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

local function GetEnemyCount(range, pos)
    pos = pos or myHero.pos
    local count = 0
    for _, hero in ipairs(Cache.EnemyHeroes) do
        if IsValid(hero) and GetDistanceSqr(pos, hero.pos) < range * range then
            count = count + 1
        end
    end
    return count
end

local function GetAllyCount(range, pos)
    pos = pos or myHero.pos
    local count = 1 -- Include self
    for _, hero in ipairs(Cache.AllyHeroes) do
        if IsValid(hero) and GetDistanceSqr(pos, hero.pos) < range * range then
            count = count + 1
        end
    end
    return count
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HEALTH PREDICTION
-- ═══════════════════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════════════════
-- FLASH DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════════════════
-- VECTOR MATH UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADVANCED E MULTI-TARGET SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

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
            
            -- Must be on the line segment (t between 0 and 1)
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
    
    -- Filter enemies within range
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
    
    -- Strategy: Test lines between each pair of enemies
    for i = 1, #validEnemies do
        for j = i + 1, #validEnemies do
            local enemy1 = validEnemies[i]
            local enemy2 = validEnemies[j]
            
            -- Direction from enemy1 to enemy2
            local dir = VectorNormalize(enemy2.pos - enemy1.pos)
            
            -- Extend line beyond both enemies
            local extension = 150
            local e1Pos = enemy1.pos - dir * extension
            local e2Pos = enemy2.pos + dir * extension
            
            -- Clamp to E range
            if GetDistance(sourcePos, e1Pos) > eRange then
                e1Pos = sourcePos + VectorNormalize(e1Pos - sourcePos) * (eRange - 10)
            end
            if GetDistance(sourcePos, e2Pos) > eRange then
                e2Pos = sourcePos + VectorNormalize(e2Pos - sourcePos) * (eRange - 10)
            end
            
            -- Count hits with this line
            local hits = self:CountEHits(e1Pos, e2Pos, validEnemies)
            
            if hits > bestHits then
                bestHits = hits
                bestE1 = e1Pos
                bestE2 = e2Pos
            end
        end
    end
    
    -- Also try perpendicular offsets to catch more enemies
    if bestE1 and bestE2 and bestHits < #validEnemies then
        local dir = VectorNormalize(bestE2 - bestE1)
        local perpDir = Vector(-dir.z, 0, dir.x)
        
        for offset = -100, 100, 25 do
            local shiftedE1 = bestE1 + perpDir * offset
            local shiftedE2 = bestE2 + perpDir * offset
            
            -- Clamp to range
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- CURVED R SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local CurvedR = {
    FLASH_RANGE = 400,
    R_WIDTH = 160,
    R_RANGE = 1000
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
    
    -- Test different flash positions and R directions
    for _, rTarget in ipairs(validEnemies) do
        local rDir = VectorNormalize(rTarget.pos - myHero.pos)
        
        -- Test flash positions around us
        local testAngles = {0, 30, 60, 90, 120, 150, 180, -30, -60, -90, -120, -150}
        
        for _, angle in ipairs(testAngles) do
            local flashDir = VectorRotate(rDir, MathRad(angle))
            local flashPos = myHero.pos + flashDir * self.FLASH_RANGE
            
            -- R fires from flash position in the original R direction
            local hitCount = self:CountRHits(flashPos, rDir, self.R_WIDTH)
            
            if hitCount >= minHit and hitCount > bestHitCount then
                bestHitCount = hitCount
                bestTarget = rTarget
                bestFlashPos = flashPos
                bestRDirection = rDir
            end
        end
    end
    
    return bestTarget, bestFlashPos, bestHitCount, bestRDirection
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- Q DANCE MODE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local QDance = {
    LastQTime = 0,
    QChain = {},
    MaxChainLength = 10
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
    
    -- Sort by health (kill lowest first for safety)
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
        
        -- Score: prefer minions close to enemy but also close to us
        local score = 1000 - distToEnemy - (distToMe * 0.5)
        
        -- Bonus for minions that get us closer to target
        if distToEnemy < GetDistance(myHero.pos, targetEnemy.pos) then
            score = score + 500
        end
        
        -- Penalty for minions under turret
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
        
        -- Pick minion that gets us closest to enemy
        TableSort(killable, function(a, b)
            return a.distToEnemy < b.distToEnemy
        end)
        
        local best = killable[1]
        TableInsert(path, best.unit)
        usedMinions[best.unit.networkID] = true
        simulatedPos = best.pos
        
        -- If we're now in Q range of enemy, we're done
        if GetDistance(simulatedPos, targetEnemy.pos) <= SpellData.Q.Range then
            break
        end
    end
    
    return path
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ADVANCED COMBO LOGIC (1v1 & TEAMFIGHT)
-- ═══════════════════════════════════════════════════════════════════════════════

local ComboLogic = {
    -- Combo states
    STATE_IDLE = 0,
    STATE_STACKING = 1,
    STATE_ENGAGE = 2,
    STATE_ALL_IN = 3,
    STATE_CLEANUP = 4,
    
    CurrentState = 0,
    LastStateChange = 0,
    ComboTarget = nil,
    
    -- Tracking
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
    
    -- Check if we can burst
    local comboDmg = GetFullComboDamage(target)
    local canBurst = comboDmg >= target.health * 0.9
    
    -- Favorable conditions for all-in
    if canBurst and myHP > 0.4 then return true end
    if HasMaxPassive() and myHP > enemyHP then return true end
    if enemyHP < 0.3 and myHP > 0.2 then return true end
    if allyCount > enemyCount and myHP > 0.3 then return true end
    
    return false
end

function ComboLogic:ShouldStack()
    if HasMaxPassive() then return false end
    
    local stacks = GetPassiveStacks()
    if stacks >= 3 then return false end -- Close enough to max
    
    -- Check if we have killable minions nearby
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
    -- Sequence: E1 -> R (if multiple or killable) -> Q on mark -> E2 -> Q on mark -> repeat
    
    local sequence = {}
    local dist = GetDistance(myHero.pos, target.pos)
    local isMarked = IsMarked(target)
    local isE1Out = IsE1Active()
    local canBurst = GetFullComboDamage(target) >= target.health
    local enemyCount = GetEnemyCount(600, target.pos)
    
    -- Priority 1: Complete E combo if E1 is out
    if isE1Out and Ready(_E) then
        TableInsert(sequence, {spell = "E2", priority = 100})
    end
    
    -- Priority 2: Q on marked target
    if isMarked and Ready(_Q) and dist <= SpellData.Q.Range then
        TableInsert(sequence, {spell = "Q_MARKED", priority = 95})
    end
    
    -- Priority 3: Q for kill
    if Ready(_Q) and dist <= SpellData.Q.Range and WillQKill(target, false) then
        TableInsert(sequence, {spell = "Q_KILL", priority = 90})
    end
    
    -- Priority 4: R for burst or teamfight
    if Ready(_R) and dist <= SpellData.R.Range and not isMarked then
        if canBurst or (isTeamfight and enemyCount >= 2) then
            TableInsert(sequence, {spell = "R", priority = 85})
        end
    end
    
    -- Priority 5: Start E combo
    if Ready(_E) and not isE1Out and dist <= SpellData.E.Range and not isMarked then
        TableInsert(sequence, {spell = "E1", priority = 80})
    end
    
    -- Priority 6: Gap close with minions
    if Ready(_Q) and dist > SpellData.Q.Range then
        TableInsert(sequence, {spell = "Q_GAP", priority = 70})
    end
    
    -- Priority 7: W during combat
    if Ready(_W) and dist <= SpellData.W.Range then
        TableInsert(sequence, {spell = "W", priority = 60})
    end
    
    -- Sort by priority
    TableSort(sequence, function(a, b) return a.priority > b.priority end)
    
    return sequence
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAIN IRELIA CLASS
-- ═══════════════════════════════════════════════════════════════════════════════

class "IreliaAdvanced"

function IreliaAdvanced:__init()
    -- Spell timers
    self.LastQ = 0
    self.LastE = 0
    self.LastR = 0
    self.LastW = 0
    
    -- E tracking
    self.E1Time = 0
    self.E1Pos = nil
    self.E2OptimalPos = nil
    
    -- W charging
    self.WCharging = false
    self.WStartTime = 0
    
    -- R-Flash
    self.RFlashPending = false
    self.RFlashPos = nil
    self.RFlashTime = 0
    
    -- Combo tracking
    self.ComboTarget = nil
    self.RTargetID = nil
    self.QUsedAfterR = false
    self.RCastTime = 0
    
    -- Dance mode
    self.DanceKey = nil
    self.DanceActive = false
    
    -- Hidden E system (1v1)
    self.PendingHiddenE = nil
    
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:OnTick() end)
    Callback.Add("Draw", function() self:OnDraw() end)
    
    print("[" .. ScriptName .. "] v" .. Version .. " Loaded Successfully!")
end

function IreliaAdvanced:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "IreliaAdvanced", name = ScriptName .. " v" .. Version})
    
    -- Combo Settings
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
    
    -- E Multi-Target
    self.Menu:MenuElement({type = MENU, id = "EMulti", name = "E Multi-Target"})
    self.Menu.EMulti:MenuElement({id = "Enable", name = "Enable Multi-Target E", value = true})
    self.Menu.EMulti:MenuElement({id = "MinHit", name = "Min Enemies to Hit", value = 2, min = 2, max = 5})
    self.Menu.EMulti:MenuElement({id = "DrawPreview", name = "Draw E Preview", value = true})
    
    -- Curved R-Flash
    self.Menu:MenuElement({type = MENU, id = "RFlash", name = "Curved R-Flash"})
    self.Menu.RFlash:MenuElement({id = "Enable", name = "Enable Curved R-Flash", value = true})
    self.Menu.RFlash:MenuElement({id = "MinHit", name = "Min Enemies", value = 2, min = 2, max = 5})
    self.Menu.RFlash:MenuElement({id = "Key", name = "Force R-Flash Key", key = string.byte("T")})
    self.Menu.RFlash:MenuElement({id = "DrawPreview", name = "Draw R-Flash Preview", value = true})
    
    -- Q Dance Mode
    self.Menu:MenuElement({type = MENU, id = "Dance", name = "Q Dance Mode"})
    self.Menu.Dance:MenuElement({id = "Enable", name = "Enable Dance Mode", value = true})
    self.Menu.Dance:MenuElement({id = "Key", name = "Dance Key", key = string.byte("G")})
    self.Menu.Dance:MenuElement({id = "ShowPath", name = "Show Dance Path", value = true})
    
    -- Burst Mode
    self.Menu:MenuElement({type = MENU, id = "Burst", name = "Burst Mode"})
    self.Menu.Burst:MenuElement({id = "Enable", name = "Enable Smart Burst", value = true})
    self.Menu.Burst:MenuElement({id = "AllIn", name = "All-In when Killable", value = true})
    
    -- Ninja Mode
    self.Menu:MenuElement({type = MENU, id = "Ninja", name = "Ninja Mode"})
    self.Menu.Ninja:MenuElement({id = "Enable", name = "Q Other Marked First", value = true})
    self.Menu.Ninja:MenuElement({name = " ", drop = {"Prioritizes any marked enemy in range"}})
    
    -- Harass
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q on Marked", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "Use E", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana %", value = 40, min = 0, max = 100})
    
    -- Clear
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q LastHit", value = true})
    self.Menu.Clear:MenuElement({id = "QJungle", name = "Use Q Jungle", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana %", value = 30, min = 0, max = 100})
    
    -- Flee
    self.Menu:MenuElement({type = MENU, id = "Flee", name = "Flee"})
    self.Menu.Flee:MenuElement({id = "UseQ", name = "Use Q to Flee", value = true})
    self.Menu.Flee:MenuElement({id = "Priority", name = "Priority", drop = {"Marked > Killable > Direction", "Killable > Direction"}})
    
    -- KillSteal
    self.Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
    self.Menu.KillSteal:MenuElement({id = "Enable", name = "Enable KillSteal", value = true})
    self.Menu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true})
    self.Menu.KillSteal:MenuElement({id = "UseE", name = "Use E", value = true})
    self.Menu.KillSteal:MenuElement({id = "IgnoreCombo", name = "KS Even in Combo", value = false})
    self.Menu.KillSteal:MenuElement({id = "DrawKillable", name = "Draw Killable Enemies", value = true})
    
    -- Safety
    self.Menu:MenuElement({type = MENU, id = "Safety", name = "Safety"})
    self.Menu.Safety:MenuElement({id = "TurretCheck", name = "Don't Q Under Turret", value = true})
    self.Menu.Safety:MenuElement({id = "TurretDive", name = "Dive if Enemy HP <=", value = 25, min = 0, max = 100})
    self.Menu.Safety:MenuElement({id = "AntiGap", name = "E Anti-Gapcloser", value = true})
    
    -- Drawings
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Drawings"})
    self.Menu.Draw:MenuElement({id = "Enabled", name = "Enable Drawings", value = true})
    self.Menu.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    self.Menu.Draw:MenuElement({id = "E", name = "E Range", value = false})
    self.Menu.Draw:MenuElement({id = "R", name = "R Range", value = false})
    self.Menu.Draw:MenuElement({id = "Killable", name = "Killable Minions", value = true})
    self.Menu.Draw:MenuElement({id = "DmgIndicator", name = "Damage Indicator", value = true})
    self.Menu.Draw:MenuElement({id = "Stacks", name = "Passive Stacks", value = true})
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MAIN TICK LOGIC
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:OnTick()
    if MyHeroNotReady() then return end
    
    LoadHeroes()
    UpdateCache()
    UpdateItemCache()
    
    -- Track E1 position
    self:TrackE1()
    
    -- Handle W release
    self:HandleW()
    
    -- Handle R-Flash
    self:HandleRFlash()
    
    -- Handle Hidden E during Q dash
    self:HandleHiddenE()
    
    -- Dance Mode
    if self.Menu.Dance.Enable:Value() and self.Menu.Dance.Key:Value() then
        self:DanceMode()
        return
    end
    
    -- Force R-Flash Key
    if self.Menu.RFlash.Key:Value() then
        self:TryRFlashCurved(true)
        return
    end
    
    local Mode = GetMode()
    
    -- KillSteal (runs always unless in combo and IgnoreCombo is false)
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- E1 TRACKING
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:TrackE1()
    local eName = GetSpellName(_E)
    
    if eName == "IreliaE" then
        self.E1Pos = nil
        self.E2OptimalPos = nil
        return
    end
    
    -- Track E1 missile
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- W HANDLING
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:HandleW()
    if not self.WCharging then return end
    
    local wBuff = GetBuffData(myHero, "ireliawdefense")
    local target = GetTarget(SpellData.W.Range)
    
    if wBuff and wBuff.duration > 0 and wBuff.duration < 0.95 then
        if target then
            ControlCastSpell(HK_W, target.pos)
        end
        self.WCharging = false
        SetAttack(true)
        SetMovement(true)
    end
    
    -- Timeout
    if GameTimer() - self.WStartTime >= SpellData.W.MaxCharge then
        ControlKeyUp(HK_W)
        self.WCharging = false
        SetAttack(true)
        SetMovement(true)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- R-FLASH HANDLING
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:HandleRFlash()
    if not self.RFlashPending then return end
    
    -- Check if R is being cast
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
    
    -- Timeout
    if GameTimer() - self.RFlashTime > 0.5 then
        self.RFlashPending = false
        self.RFlashPos = nil
    end
end

function IreliaAdvanced:HandleHiddenE()
    -- Process pending hidden E during Q dash
    if not self.PendingHiddenE then return end
    
    -- Timeout after 0.8s
    if GameTimer() - self.PendingHiddenE.castTime > 0.8 then
        self.PendingHiddenE = nil
        return
    end
    
    -- Check if we're dashing
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
        -- Check if curved R hits more than normal R
        local normalHits = CurvedR:CountRHits(myHero.pos, VectorNormalize(target.pos - myHero.pos), CurvedR.R_WIDTH)
        
        if hitCount > normalHits or force then
            -- Cast R first
            ControlCastSpell(HK_R, target.pos)
            self.RFlashPending = true
            self.RFlashPos = flashPos
            self.RFlashTime = GameTimer()
            self.LastR = GameTimer()
            return true
        end
    end
    
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DANCE MODE
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:DanceMode()
    if not Ready(_Q) then return end
    
    local target = GetTarget(1200)
    if not target then return end
    
    -- Find dance path
    local path = QDance:FindDancePath(target, 5)
    
    if #path > 0 then
        local nextTarget = path[1]
        if IsValid(nextTarget) and GetDistance(myHero.pos, nextTarget.pos) <= SpellData.Q.Range then
            if WillQKill(nextTarget, true) then
                self:CastQ(nextTarget)
            end
        end
    else
        -- No path, check if we can Q the target
        if IsMarked(target) and GetDistance(myHero.pos, target.pos) <= SpellData.Q.Range then
            self:CastQ(target)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- KILLSTEAL
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:KillSteal()
    for _, enemy in ipairs(Cache.EnemyHeroes) do
        if IsValid(enemy) and not CantKill(enemy, true, true, true) then
            local dist = GetDistance(myHero.pos, enemy.pos)
            local qDmg = GetQDamage(enemy, false)
            local eDmg = GetEDamage(enemy)
            
            -- Q KillSteal
            if self.Menu.KillSteal.UseQ:Value() and Ready(_Q) then
                -- Direct Q kill
                if dist <= SpellData.Q.Range and qDmg >= enemy.health then
                    self:CastQ(enemy)
                    return true
                end
                
                -- Q on marked target kill
                if dist <= SpellData.Q.Range and IsMarked(enemy) and qDmg >= enemy.health then
                    self:CastQ(enemy)
                    return true
                end
                
                -- Gapclose Q kill (through minions)
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
            
            -- E KillSteal (if E can kill and Q not available)
            if self.Menu.KillSteal.UseE:Value() and Ready(_E) and not Ready(_Q) then
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
        
        -- If we're now in Q range of enemy, we're done
        if GetDistance(simulatedPos, target.pos) <= SpellData.Q.Range then
            break
        end
    end
    
    -- Only return path if it gets us in range
    if #path > 0 and GetDistance(path[#path].pos, target.pos) <= SpellData.Q.Range then
        return path
    end
    
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMBO
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:Combo()
    local target = GetTarget(SpellData.R.Range)
    if not target or not IsValid(target) then return end
    
    local dist = GetDistance(myHero.pos, target.pos)
    local isE1Out = IsE1Active()
    local isMarked = IsMarked(target)
    local enemyCount = GetEnemyCount(800, myHero.pos)
    local isTeamfight = enemyCount >= 2
    local hasR = Ready(_R)
    
    -- Reset R tracking
    if GameTimer() - self.RCastTime > 3.0 then
        self.RTargetID = nil
        self.QUsedAfterR = false
    end
    
    -- Determine if 1v1
    local is1v1 = enemyCount == 1 and GetAllyCount(800, myHero.pos) <= 1
    
    -- 1v1 Logic WITHOUT R
    if is1v1 and not hasR then
        self:Combo1v1NoR(target)
        return
    end
    
    -- Stack passive first if needed
    if self.Menu.Combo.StackPassive:Value() and ComboLogic:ShouldStack() and not isMarked then
        self:StackPassive()
        return
    end
    
    -- Try R-Flash for multi-hit
    if self.Menu.RFlash.Enable:Value() and Ready(_R) and IsFlashReady() and isTeamfight then
        if self:TryRFlashCurved(false) then
            return
        end
    end
    
    -- Burst Mode: R if target killable
    if self.Menu.Burst.Enable:Value() and self.Menu.Combo.RBurst:Value() and 
       Ready(_R) and not isMarked and not CantKill(target, false, true, false) then
        if dist <= SpellData.R.Range and GetFullComboDamage(target) >= target.health then
            self:CastR(target)
            return
        end
    end
    
    -- Auto R on multiple enemies
    if self.Menu.Combo.UseR:Value() and Ready(_R) and not isMarked then
        if enemyCount >= self.Menu.Combo.RAuto:Value() then
            self:CastRAOE(target, self.Menu.Combo.RAuto:Value())
            return
        end
    end
    
    -- E1 Multi-Target or Single
    if self.Menu.Combo.UseE:Value() and Ready(_E) and not isE1Out then
        if dist <= SpellData.E.Range and not isMarked and not CantKill(target, false, true, false) then
            self:CastE1(target)
            return
        end
    end
    
    -- Cast R after E1
    if self.Menu.Combo.UseR:Value() and Ready(_R) and isE1Out then
        if GameTimer() - self.E1Time < 1.5 and dist <= SpellData.R.Range and not isMarked then
            self:CastR(target)
            return
        end
    end
    
    -- Ninja Mode: Q other marked enemies first
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
    
    -- Q on marked/killable
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
    
    -- E2
    if self.Menu.Combo.UseE:Value() and Ready(_E) and isE1Out then
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
    
    -- Gapclose
    if self.Menu.Combo.Gapclose:Value() and Ready(_Q) and dist > SpellData.Q.Range then
        self:Gapclose(target)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1v1 COMBO WITHOUT R
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:Combo1v1NoR(target)
    local dist = GetDistance(myHero.pos, target.pos)
    local isE1Out = IsE1Active()
    local isMarked = IsMarked(target)
    local hasMaxStacks = HasMaxPassive()
    local myHpPercent = myHero.health / myHero.maxHealth
    local enemyHpPercent = target.health / target.maxHealth
    
    --[[
        1v1 WITHOUT R STRATEGY (HIDDEN E):
        
        The key is to HIDE the E cast during Q dash animation.
        Enemy can't react to E if it's cast while we're dashing.
        
        Sequences:
        1. Q to minion near enemy -> E1 DURING dash -> land -> E2 -> Q marked
        2. If already close: E1 behind us -> Q minion toward enemy -> E2 through enemy
        3. E1 at self -> Q to marked minion/enemy -> E2 mid-dash
        
        Priority: Always cast E DURING a Q dash for maximum surprise
    ]]
    
    -- DEFENSIVE PLAY: Low HP, try to disengage or only take safe trades
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
    
    -- Track if we're currently dashing (for hidden E)
    local isDashing = self:IsQDashing()
    
    -- HIDDEN E: Cast E1 or E2 during Q dash
    if isDashing and Ready(_E) then
        if isE1Out then
            -- E2 during dash - try to hit the target
            self:CastE2Hidden(target)
            return
        else
            -- E1 during dash - place it strategically
            self:CastE1Hidden(target)
            return
        end
    end
    
    -- If E1 is out, complete the combo
    if isE1Out and Ready(_E) then
        -- If target is marked, Q first then E2
        if isMarked and Ready(_Q) and dist <= SpellData.Q.Range then
            self:CastQ(target)
            return
        end
        -- E2 to stun (will be cast during next Q if possible)
        if not Ready(_Q) or dist > SpellData.Q.Range then
            self:CastE2(target)
            return
        end
    end
    
    -- Q on marked target
    if Ready(_Q) and dist <= SpellData.Q.Range and isMarked then
        self:CastQ(target)
        return
    end
    
    -- INITIATE HIDDEN E COMBO
    if Ready(_E) and not isE1Out and Ready(_Q) then
        -- Strategy 1: Q to minion near enemy, E1 during dash
        local engageMinion = self:GetBestEngageMinion(target)
        if engageMinion then
            -- Store that we want to cast E1 during this dash
            self.PendingHiddenE = {
                type = "E1",
                target = target,
                castTime = GameTimer()
            }
            self:CastQ(engageMinion)
            return
        end
        
        -- Strategy 2: E1 at self/behind, then Q to minion, E2 during dash
        if dist <= SpellData.E.Range then
            -- Place E1 behind us
            local behindPos = myHero.pos - VectorNormalize(target.pos - myHero.pos) * 300
            self:CastE1AtPos(behindPos)
            return
        end
    end
    
    -- If E1 is out and we have a minion to dash to, setup hidden E2
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
    
    -- STACK PASSIVE if nothing else to do
    if not hasMaxStacks and self.Menu.Combo.StackPassive:Value() then
        local stacked = self:StackPassiveNearTarget(target)
        if stacked then return end
    end
    
    -- Q to execute
    if Ready(_Q) and dist <= SpellData.Q.Range then
        if WillQKill(target, false) and not CantKill(target, true, true, true) then
            self:CastQ(target)
            return
        end
    end
    
    -- Gapclose if out of range
    local canWinTrade = hasMaxStacks or myHpPercent > enemyHpPercent or enemyHpPercent < 0.4
    if Ready(_Q) and dist > SpellData.Q.Range and canWinTrade then
        self:Gapclose(target)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- HIDDEN E SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:IsQDashing()
    -- Check if we're in Q dash animation
    local spell = myHero.activeSpell
    if spell and spell.valid and spell.name then
        local spellName = spell.name:lower()
        if spellName:find("ireliaq") then
            return true
        end
    end
    
    -- Also check pathing dash
    if myHero.pathing and myHero.pathing.isDashing then
        return true
    end
    
    return false
end

function IreliaAdvanced:CastE1Hidden(target)
    -- Cast E1 during Q dash - position it to set up E2 stun on landing
    if not Ready(_E) or IsE1Active() then return end
    
    local dashEndPos = self:GetQDashEndPosition()
    if not dashEndPos then
        dashEndPos = myHero.pos
    end
    
    -- Calculate E1 position: behind where we'll land relative to target
    local dirToTarget = VectorNormalize(target.pos - dashEndPos)
    local e1Pos = dashEndPos - dirToTarget * 250
    
    -- Ensure in range
    if GetDistance(myHero.pos, e1Pos) > SpellData.E.Range then
        e1Pos = myHero.pos + VectorNormalize(e1Pos - myHero.pos) * (SpellData.E.Range - 50)
    end
    
    -- Store E2 optimal position
    self.E2OptimalPos = target.pos + dirToTarget * 150
    
    ControlCastSpell(HK_E, e1Pos)
    self.LastE = GameTimer()
    self.E1Time = GameTimer()
    self.E1Pos = e1Pos
end

function IreliaAdvanced:CastE2Hidden(target)
    -- Cast E2 during Q dash to stun enemy
    if not Ready(_E) or not IsE1Active() then return end
    if not self.E1Pos then return end
    
    local castPos = nil
    
    -- Use optimal E2 if available
    if self.E2OptimalPos and GetDistance(myHero.pos, self.E2OptimalPos) <= SpellData.E.Range then
        castPos = self.E2OptimalPos
    else
        -- Calculate E2 to pass through target from E1
        local dir = VectorNormalize(target.pos - self.E1Pos)
        castPos = target.pos + dir * 150
        
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
    -- Find a minion that:
    -- 1. Is killable with Q
    -- 2. Is between us and target or close to target
    -- 3. Gets us in a good position to land E
    
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
            
            -- Score: prefer minions that get us closer and in E range of target
            local score = 0
            
            -- Big bonus if landing puts us in E range of target
            if distToTarget <= SpellData.E.Range - 100 then
                score = score + 1000
            end
            
            -- Bonus for getting closer to target
            if distToTarget < distMeToTarget then
                score = score + (distMeToTarget - distToTarget)
            end
            
            -- Prefer minions not too close (gives time to cast E during dash)
            if distMeToMinion >= 300 then
                score = score + 200
            end
            
            -- Penalty if too far from target after dash
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
    -- Find minion to Q to while casting E2 mid-dash
    -- Ideally the minion is positioned so our dash path crosses near target
    
    local best = nil
    local bestScore = -MathHuge
    
    for _, minion in ipairs(Cache.EnemyMinions) do
        if IsValid(minion) and 
           GetDistance(myHero.pos, minion.pos) <= SpellData.Q.Range and
           WillQKill(minion, true) then
            
            local distToTarget = GetDistance(minion.pos, target.pos)
            local distMeToMinion = GetDistance(myHero.pos, minion.pos)
            
            -- Check if E2 can reach from dash path to create stun through target
            local canE2HitTarget = false
            if self.E1Pos then
                -- Simulate if E2 from minion position would stun target
                local e1ToMinion = VectorNormalize(minion.pos - self.E1Pos)
                local e1ToTarget = VectorNormalize(target.pos - self.E1Pos)
                local dot = e1ToMinion.x * e1ToTarget.x + e1ToMinion.z * e1ToTarget.z
                
                -- If minion is roughly in line with E1->Target, E2 will hit
                if dot > 0.5 then
                    canE2HitTarget = true
                end
            end
            
            local score = 0
            
            if canE2HitTarget then
                score = score + 1000
            end
            
            -- Prefer minions with longer dash (more time to cast E2)
            score = score + distMeToMinion * 0.5
            
            -- Prefer staying close to target
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
            -- Prefer minions that keep us close to target
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- HARASS
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:Harass()
    if myHero.mana / myHero.maxMana * 100 < self.Menu.Harass.Mana:Value() then return end
    
    local target = GetTarget(SpellData.E.Range)
    if not target or not IsValid(target) then return end
    
    local dist = GetDistance(myHero.pos, target.pos)
    
    if self.Menu.Harass.UseE:Value() and Ready(_E) then
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- CLEAR
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:Clear()
    if myHero.mana / myHero.maxMana * 100 < self.Menu.Clear.Mana:Value() then return end
    
    -- Lane Clear
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
    
    -- Jungle Clear
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- LASTHIT
-- ═══════════════════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════════════════
-- FLEE
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:Flee()
    if not self.Menu.Flee.UseQ:Value() or not Ready(_Q) then return end
    
    local mousePos = Game.mousePos()
    local bestTarget = nil
    local bestDist = 400
    
    -- Check marked champions
    for _, enemy in ipairs(Cache.EnemyHeroes) do
        if IsValid(enemy) and GetDistance(myHero.pos, enemy.pos) <= SpellData.Q.Range and IsMarked(enemy) then
            local distToMouse = GetDistance(enemy.pos, mousePos)
            if distToMouse < bestDist then
                bestDist = distToMouse
                bestTarget = enemy
            end
        end
    end
    
    -- Check killable minions
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

-- ═══════════════════════════════════════════════════════════════════════════════
-- STACK PASSIVE
-- ═══════════════════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════════════════
-- GAPCLOSE
-- ═══════════════════════════════════════════════════════════════════════════════

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

-- ═══════════════════════════════════════════════════════════════════════════════
-- CAST SPELLS
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:CastQ(target)
    if not Ready(_Q) then return end
    if GameTimer() - self.LastQ < 0.15 then return end
    
    -- Turret safety
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
    
    -- Track Q after R
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
    
    -- Check for multi-target E
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
    
    -- Single target fallback
    if not castPos then
        local dir = VectorNormalize(target.pos - myHero.pos)
        castPos = target.pos + dir * 150
        self.E2OptimalPos = target.pos - dir * 150
    end
    
    -- Cast
    if castPos then
        local pos2D = castPos:To2D()
        if pos2D and pos2D.onScreen then
            SetMovement(false)
            ControlCastSpell(HK_E, castPos)
            SetMovement(true)
        elseif self.Menu.Combo.E1Self:Value() then
            -- Cast at self if target offscreen
            ControlCastSpell(HK_E, myHero.pos)
            local dir = VectorNormalize(target.pos - myHero.pos)
            self.E2OptimalPos = target.pos + dir * 150
        end
        
        self.LastE = GameTimer()
        self.E1Time = GameTimer()
        self.E1Pos = castPos
    end
end

function IreliaAdvanced:CastE2(target)
    if not Ready(_E) then return end
    if GameTimer() - self.LastE < 0.25 then return end
    if GetSpellName(_E) ~= "IreliaE2" then return end
    if not self.E1Pos then return end
    
    local castPos = nil
    
    -- Use optimal E2 if available
    if self.E2OptimalPos and GetDistance(myHero.pos, self.E2OptimalPos) <= SpellData.E.Range then
        castPos = self.E2OptimalPos
    else
        -- Calculate position
        local dir = VectorNormalize(self.E1Pos - target.pos)
        castPos = target.pos - dir * 150
        
        if GetDistance(myHero.pos, castPos) > SpellData.E.Range then
            castPos = target.pos - dir * 50
        end
    end
    
    if castPos then
        local pos2D = castPos:To2D()
        if pos2D and pos2D.onScreen then
            SetMovement(false)
            ControlCastSpell(HK_E, castPos)
            SetMovement(true)
            self.LastE = GameTimer()
            self.E2OptimalPos = nil
        end
    end
end

function IreliaAdvanced:CastR(target)
    if not Ready(_R) then return end
    if GameTimer() - self.LastR < 0.3 then return end
    
    ControlCastSpell(HK_R, target.pos)
    self.LastR = GameTimer()
    self.RCastTime = GameTimer()
    self.RTargetID = target.networkID
    self.QUsedAfterR = false
end

function IreliaAdvanced:CastRAOE(target, minHit)
    if not Ready(_R) then return end
    if GameTimer() - self.LastR < 0.3 then return end
    
    local bestPos = target.pos
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
                bestPos = enemy.pos
            end
        end
    end
    
    if bestCount >= minHit then
        ControlCastSpell(HK_R, bestPos)
        self.LastR = GameTimer()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════════════════════════════════════════════

function IreliaAdvanced:OnDraw()
    if myHero.dead or not self.Menu.Draw.Enabled:Value() then return end
    
    -- Spell ranges
    if self.Menu.Draw.Q:Value() and Ready(_Q) then
        DrawCircle(myHero.pos, SpellData.Q.Range, 1, DrawColor(255, 255, 200, 0))
    end
    
    if self.Menu.Draw.E:Value() and Ready(_E) then
        DrawCircle(myHero.pos, SpellData.E.Range, 1, DrawColor(255, 0, 255, 255))
    end
    
    if self.Menu.Draw.R:Value() and Ready(_R) then
        DrawCircle(myHero.pos, SpellData.R.Range, 1, DrawColor(255, 255, 0, 0))
    end
    
    -- Killable minions
    if self.Menu.Draw.Killable:Value() and Ready(_Q) then
        for _, minion in ipairs(Cache.EnemyMinions) do
            if IsValid(minion) and GetDistance(myHero.pos, minion.pos) <= 800 then
                if WillQKill(minion, true) then
                    DrawCircle(minion.pos, 35, 3, DrawColor(255, 0, 255, 0))
                end
            end
        end
    end
    
    -- Passive stacks
    if self.Menu.Draw.Stacks:Value() then
        local stacks = GetPassiveStacks()
        local color = HasMaxPassive() and DrawColor(255, 0, 255, 0) or DrawColor(255, 255, 255, 0)
        local text = HasMaxPassive() and "MAX" or tostring(stacks)
        DrawText("Passive: " .. text, 18, 100, 100, color)
    end
    
    -- E Multi-target preview
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
    
    -- R-Flash preview
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
    
    -- Dance path preview
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
            
            -- Draw line to target
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
    
    -- Damage indicator
    if self.Menu.Draw.DmgIndicator:Value() then
        for _, enemy in ipairs(Cache.EnemyHeroes) do
            if IsValid(enemy) then
                local dmg = GetFullComboDamage(enemy)
                local killable = dmg >= enemy.health
                
                local pos = enemy.pos:To2D()
                if pos.onScreen then
                    local text = killable and "KILLABLE" or string.format("%.0f%%", (dmg / enemy.health) * 100)
                    local color = killable and DrawColor(255, 0, 255, 0) or DrawColor(255, 255, 200, 0)
                    DrawText(text, 16, pos.x - 30, pos.y - 50, color)
                end
            end
        end
    end
    
    -- KillSteal indicator
    if self.Menu.KillSteal.DrawKillable:Value() then
        for _, enemy in ipairs(Cache.EnemyHeroes) do
            if IsValid(enemy) then
                local dist = GetDistance(myHero.pos, enemy.pos)
                local qDmg = GetQDamage(enemy, false)
                local canKS = false
                local ksMethod = ""
                
                -- Direct Q kill
                if Ready(_Q) and dist <= SpellData.Q.Range and qDmg >= enemy.health then
                    canKS = true
                    ksMethod = "Q"
                -- Q through minions
                elseif Ready(_Q) and dist <= SpellData.Q.Range * 2.5 and qDmg >= enemy.health then
                    local path = self:FindKillPath(enemy)
                    if path and #path > 0 then
                        canKS = true
                        ksMethod = "Q(" .. #path .. ")"
                    end
                end
                
                if canKS then
                    local pos = enemy.pos:To2D()
                    if pos.onScreen then
                        DrawCircle(enemy.pos, 100, 3, DrawColor(255, 255, 0, 0))
                        DrawText("KS: " .. ksMethod, 18, pos.x - 25, pos.y - 70, DrawColor(255, 255, 0, 0))
                    end
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- INITIALIZE
-- ═══════════════════════════════════════════════════════════════════════════════

IreliaAdvanced()