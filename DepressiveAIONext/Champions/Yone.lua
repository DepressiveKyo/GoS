if _G.__DEPRESSIVE_NEXT_YONE_LOADED then return end
_G.__DEPRESSIVE_NEXT_YONE_LOADED = true

local Version = 3.1
local Name = "DepressiveYone"

local Heroes = {"Yone"}
local function TableContains(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then return true end
    end
    return false
end
if not TableContains(Heroes, myHero.charName) then return end

require("GGPrediction")
require("DepressivePrediction")

local PRED_ENGINE_GG = 1
local PRED_ENGINE_DEPRESSIVE = 2
local PredictionMenu = nil

local function IsGGPredictionReady()
    return _G.GGPrediction and type(_G.GGPrediction.SpellPrediction) == "function"
end

local function IsDepressivePredictionReady()
    return _G.DepressivePrediction and type(_G.DepressivePrediction.GetPrediction) == "function"
end

local function GetSelectedPredictionEngine()
    if PredictionMenu and PredictionMenu.engine then
        return PredictionMenu.engine:Value()
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

local function GetPredictionDistance(p1, p2)
    if not p1 or not p2 then return math.huge end
    local pos1 = p1.pos or p1
    local pos2 = p2.pos or p2
    local dx = pos1.x - pos2.x
    local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
    return math.sqrt(dx * dx + dz * dz)
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

local function GetGGSpellType(spellData)
    if spellData.type == "conic" or spellData.type == "cone" then
        return GGPrediction.SPELLTYPE_CONE
    end
    if spellData.type == "circular" or spellData.type == "circle" then
        return GGPrediction.SPELLTYPE_CIRCLE
    end
    return GGPrediction.SPELLTYPE_LINE
end

local function GetGGCastPosition(target, spellData)
    if not IsGGPredictionReady() then
        return nil, 0
    end

    local prediction = GGPrediction:SpellPrediction({
        Type = GetGGSpellType(spellData),
        Delay = spellData.delay,
        Radius = spellData.radius,
        Range = spellData.range,
        Speed = spellData.speed,
        Collision = spellData.collision or false
    })
    prediction:GetPrediction(target, myHero)

    local castPos = prediction.CastPosition
    if castPos and castPos.x and castPos.z and GetPredictionDistance(myHero.pos, castPos) <= spellData.range then
        return {x = castPos.x, z = castPos.z}, NormalizeGGHitChance(prediction)
    end

    return nil, 0
end

local function GetDepressiveCastPosition(target, spellData)
    if not IsDepressivePredictionReady() then
        return nil, 0
    end

    local ok, prediction = pcall(_G.DepressivePrediction.GetPrediction, target, {
        type = spellData.type,
        source = myHero,
        speed = spellData.speed,
        delay = spellData.delay,
        radius = spellData.radius,
        range = spellData.range,
        collision = spellData.collision or false
    })

    if ok and prediction and prediction.castPos and prediction.castPos.x and prediction.castPos.z then
        if GetPredictionDistance(myHero.pos, prediction.castPos) <= spellData.range then
            return {x = prediction.castPos.x, z = prediction.castPos.z}, prediction.hitChance or prediction.HitChance or 2
        end
    end

    local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local legacyOk, _, legacyCastPos = pcall(
        _G.DepressivePrediction.GetPrediction,
        target,
        sourcePos2D,
        spellData.speed,
        spellData.delay,
        spellData.radius
    )

    if legacyOk and legacyCastPos and legacyCastPos.x and legacyCastPos.z then
        if GetPredictionDistance(myHero.pos, legacyCastPos) <= spellData.range then
            return {x = legacyCastPos.x, z = legacyCastPos.z}, 4
        end
    end

    return nil, 0
end

local math_sqrt = math.sqrt
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_huge = math.huge
local math_floor = math.floor
local math_ceil = math.ceil
local math_atan2 = math.atan2
local math_cos = math.cos
local math_sin = math.sin
local math_pi = math.pi
local math_random = math.random

local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort

local string_lower = string.lower
local string_find = string.find
local string_format = string.format

local pairs = pairs
local ipairs = ipairs
local type = type
local tonumber = tonumber
local tostring = tostring
local pcall = pcall

local Game = Game
local Control = Control
local Draw = Draw
local myHero = myHero
local Vector = Vector

local GameTimer = Game.Timer
local GameHeroCount = Game.HeroCount
local GameMinionCount = Game.MinionCount
local GameTurretCount = Game.TurretCount
local GameHero = Game.Hero
local GameMinion = Game.Minion
local GameTurret = Game.Turret
local GameIsChatOpen = Game.IsChatOpen
local GameCanUseSpell = Game.CanUseSpell

local _Q = 0
local _W = 1
local _E = 2
local _R = 3

local HK_Q = HK_Q or _Q
local HK_W = HK_W or _W
local HK_E = HK_E or _E
local HK_R = HK_R or _R
local HK_FLASH = HK_SUMMONER_1

local KEY_DOWN = KEY_DOWN or 0x0100
local KEY_UP = KEY_UP or 0x0101

local SPELL_DATA = {
    Q1 = {
        range = 450,
        speed = math_huge,
        delay = 0.35,
        radius = 40,
        type = "linear",
        collision = false
    },
    Q3 = {
        range = 1050,
        speed = 1500,
        delay = 0.35,
        radius = 80,
        type = "linear",
        collision = false,
        knockup = true
    },
    W = {
        range = 600,
        speed = math_huge,
        delay = 0.5,
        radius = 0,
        angle = 80,
        type = "conic",
        shieldPercentage = {40, 42.5, 45, 47.5, 50}
    },
    E = {
        range = 300,
        speed = 1200,
        delay = 0.0,
        radius = 0,
        type = "dash",
        duration = 5.0,
        damagePercentage = {25, 27.5, 30, 32.5, 35}
    },
    R = {
        range = 1000,
        speed = math_huge,
        delay = 0.75,
        radius = 112.5,
        type = "linear",
        blinkRange = 750,
        knockup = true
    }
}

local CC_TYPES = {
    [5] = true,
    [8] = true,
    [9] = true,
    [11] = true,
    [21] = true,
    [22] = true,
    [24] = true,
    [28] = true,
    [29] = true,
    [30] = true,
    [31] = true,
    [39] = true,
}

local PRIORITY_TARGETS = {
    ["Jinx"] = 5, ["Vayne"] = 5, ["Kaisa"] = 5, ["Aphelios"] = 5, ["Zeri"] = 5,
    ["Caitlyn"] = 5, ["Draven"] = 5, ["Ezreal"] = 5, ["Lucian"] = 5, ["Tristana"] = 5,
    ["Jhin"] = 5, ["Samira"] = 5, ["Xayah"] = 5, ["Varus"] = 5, ["Ashe"] = 5,
    ["Kogmaw"] = 5, ["Twitch"] = 5, ["MissFortune"] = 5, ["Sivir"] = 5, ["Kalista"] = 5,
    ["Syndra"] = 4, ["Orianna"] = 4, ["Zoe"] = 4, ["Ahri"] = 4, ["Leblanc"] = 4,
    ["Katarina"] = 4, ["Akali"] = 4, ["Cassiopeia"] = 4, ["Viktor"] = 4, ["Vex"] = 4,
    ["Xerath"] = 4, ["Lux"] = 4, ["Velkoz"] = 4, ["Ziggs"] = 4, ["Brand"] = 4,
}

local Cache = {
    buffs = {},
    damage = {},
    enemies = {},
    minions = {},
    lastCleanup = 0,
    cleanupInterval = 1.0,

    Reset = function(self, cacheType)
        if cacheType then
            self[cacheType] = {}
        else
            self.buffs = {}
            self.damage = {}
        end
    end,

    Cleanup = function(self)
        local now = GameTimer()
        if now - self.lastCleanup < self.cleanupInterval then return end
        self.lastCleanup = now

        for k, v in pairs(self.buffs) do
            if now - (v.time or 0) > 0.5 then
                self.buffs[k] = nil
            end
        end
        for k, v in pairs(self.damage) do
            if now - (v.time or 0) > 0.5 then
                self.damage[k] = nil
            end
        end
    end
}

local ETracker = {
    active = false,
    startTime = 0,
    targets = {},
    bodyPosition = nil,
    maxDuration = 5.0,

    Start = function(self)
        self.active = true
        self.startTime = GameTimer()
        self.targets = {}
        self.bodyPosition = {x = myHero.pos.x, z = myHero.pos.z}
    end,

    Stop = function(self)
        self.active = false
        self.targets = {}
        self.bodyPosition = nil
    end,

    GetRemainingTime = function(self)
        if not self.active then return 0 end
        return math_max(0, self.maxDuration - (GameTimer() - self.startTime))
    end,

    GetStoredDamage = function(self, target)
        if not target or not self.active then return 0 end
        local data = self.targets[target.networkID]
        return data and data.damage or 0
    end,

    GetExecuteDamage = function(self, target, level)
        local stored = self:GetStoredDamage(target)
        if stored <= 0 then return 0 end

        level = level or myHero:GetSpellData(_E).level
        if level == 0 then return 0 end

        local percentage = SPELL_DATA.E.damagePercentage[level] / 100
        return stored * percentage
    end,

    IsExecutable = function(self, target, safetyMargin)
        if not target then return false end
        safetyMargin = safetyMargin or 1.05

        local executeDmg = self:GetExecuteDamage(target)
        return executeDmg > (target.health * safetyMargin)
    end
}

local function GetDistance(p1, p2)
    if not p1 or not p2 then return math_huge end
    local pos1 = p1.pos or p1
    local pos2 = p2.pos or p2
    local dx = pos1.x - pos2.x
    local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
    return math_sqrt(dx * dx + dz * dz)
end

local function GetDistanceSq(p1, p2)
    if not p1 or not p2 then return math_huge end
    local pos1 = p1.pos or p1
    local pos2 = p2.pos or p2
    local dx = pos1.x - pos2.x
    local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
    return dx * dx + dz * dz
end

local function IsInRange(p1, p2, range)
    return GetDistanceSq(p1, p2) <= range * range
end

local function Normalize2D(v)
    local len = math_sqrt(v.x * v.x + v.z * v.z)
    if len == 0 then return {x = 0, z = 0}, 0 end
    return {x = v.x / len, z = v.z / len}, len
end

local function VectorExtend(from, to, distance)
    local pos1 = from.pos or from
    local pos2 = to.pos or to
    local dx = pos2.x - pos1.x
    local dz = pos2.z - pos1.z
    local len = math_sqrt(dx * dx + dz * dz)
    if len == 0 then return {x = pos1.x, z = pos1.z} end
    return {
        x = pos1.x + (dx / len) * distance,
        z = pos1.z + (dz / len) * distance
    }
end

local function IsValidTarget(target, range)
    if not target then return false end
    if target.dead or not target.visible or not target.isTargetable then return false end
    if target.team == myHero.team then return false end
    if range and GetDistance(myHero.pos, target.pos) > range then return false end
    return true
end

local function Ready(spell)
    local data = myHero:GetSpellData(spell)
    return data and data.currentCd == 0 and data.level > 0 and GameCanUseSpell(spell) == 0
end

local function HasQ3()
    local qData = myHero:GetSpellData(_Q)
    return qData and qData.name == "YoneQ3"
end

local function GetQStacks()
    local qData = myHero:GetSpellData(_Q)
    if not qData then return 0 end
    if qData.name == "YoneQ3" then return 2 end

    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.count > 0 and buff.name and string_find(string_lower(buff.name), "yoneq") then
            return buff.count
        end
    end
    return 0
end

local function IsInE()

    return myHero.mana and myHero.mana > 0
end

local function IsInEBySpellName()
    local eData = myHero:GetSpellData(_E)
    return eData and eData.name == "YoneE2"
end

local function GetEBodyPosition()
    if not IsInE() then return nil end
    return ETracker.bodyPosition
end

local function HasBuff(unit, buffname)
    if not unit or not unit.buffCount then return false, nil end
    local targetName = string_lower(buffname)

    local cacheKey = (unit.networkID or 0) .. ":" .. targetName
    local cached = Cache.buffs[cacheKey]
    local now = GameTimer()
    if cached and now - cached.time < 0.1 then
        return cached.has, cached.buff
    end

    local has, foundBuff = false, nil
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name and buff.count > 0 then
            if string_find(string_lower(buff.name), targetName) then
                has = true
                foundBuff = buff
                break
            end
        end
    end

    Cache.buffs[cacheKey] = {has = has, buff = foundBuff, time = now}
    return has, foundBuff
end

local function HasCC(target)
    if not target or not target.buffCount then return false, 0 end

    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and buff.count > 0 then

            if CC_TYPES[buff.type] then
                local remaining = (buff.expireTime or 0) - GameTimer()
                return true, remaining
            end

            local name = string_lower(buff.name or "")
            if string_find(name, "stun") or string_find(name, "snare") or
               string_find(name, "root") or string_find(name, "charm") or
               string_find(name, "fear") or string_find(name, "taunt") or
               string_find(name, "knockup") or string_find(name, "airborne") or
               string_find(name, "suppress") or string_find(name, "sleep") then
                local remaining = (buff.expireTime or 0) - GameTimer()
                return true, remaining
            end
        end
    end
    return false, 0
end

local function IsKnockedUp(target)
    if not target or not target.buffCount then return false end

    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and buff.count > 0 then
            if buff.type == 30 or buff.type == 31 or buff.type == 39 then
                return true
            end
            local name = string_lower(buff.name or "")
            if string_find(name, "knockup") or string_find(name, "airborne") or
               string_find(name, "yasuo") or string_find(name, "yone") then
                return true
            end
        end
    end
    return false
end

local function IsUnderEnemyTurret(pos, safetyRange)
    safetyRange = safetyRange or 900
    local checkPos = pos.pos or pos

    for i = 1, GameTurretCount() do
        local turret = GameTurret(i)
        if turret and turret.isEnemy and not turret.dead then
            if IsInRange(checkPos, turret.pos, safetyRange) then
                return true
            end
        end
    end
    return false
end

local function CountEnemiesInRange(pos, range)
    local count = 0
    local checkPos = pos.pos or pos

    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy) and IsInRange(checkPos, enemy.pos, range) then
            count = count + 1
        end
    end
    return count
end

local function CountAlliesInRange(pos, range)
    local count = 0
    local checkPos = pos.pos or pos

    for i = 1, GameHeroCount() do
        local ally = GameHero(i)
        if ally and not ally.dead and ally.team == myHero.team and ally ~= myHero then
            if IsInRange(checkPos, ally.pos, range) then
                count = count + 1
            end
        end
    end
    return count
end

local function GetQDamage(target)
    if not target then return 0 end
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end

    local base = ({20, 45, 70, 95, 120})[level] or 0
    local ad = myHero.totalDamage or myHero.ad or 0
    local rawDmg = base + ad * 1.0

    local armor = target.armor or 0
    local armorPen = myHero.armorPen or 0
    local lethality = myHero.lethality or 0
    local effectiveArmor = armor * (1 - armorPen / 100) - lethality
    effectiveArmor = math_max(0, effectiveArmor)

    local reduction = 100 / (100 + effectiveArmor)
    return rawDmg * reduction
end

local function GetWDamage(target)
    if not target then return 0 end
    local level = myHero:GetSpellData(_W).level
    if level == 0 then return 0 end

    local base = ({10, 20, 30, 40, 50})[level] or 0
    local hpPercent = ({10, 11, 12, 13, 14})[level] or 10
    local ad = myHero.totalDamage or 0

    local physicalDmg = base + ad * 0.15
    local magicDmg = target.maxHealth * (hpPercent / 100)

    local armor = math_max(0, target.armor or 0)
    local mr = math_max(0, target.magicResist or 50)

    local physReduction = 100 / (100 + armor)
    local magicReduction = 100 / (100 + mr)

    return (physicalDmg * physReduction) + (magicDmg * magicReduction * 0.5)
end

local function GetEDamage(target)
    if not target then return 0 end
    return ETracker:GetExecuteDamage(target)
end

local function GetRDamage(target)
    if not target then return 0 end
    local level = myHero:GetSpellData(_R).level
    if level == 0 then return 0 end

    local base = ({200, 400, 600})[level] or 0
    local ad = myHero.totalDamage or 0
    local rawDmg = base + ad * 0.8

    local armor = math_max(0, target.armor or 0)
    local mr = math_max(0, target.magicResist or 50)

    local physReduction = 100 / (100 + armor)
    local magicReduction = 100 / (100 + mr)

    return (rawDmg * 0.5 * physReduction) + (rawDmg * 0.5 * magicReduction)
end

local function GetComboDamage(target, includeR)
    if not target then return 0 end

    local damage = 0

    if Ready(_Q) then
        damage = damage + GetQDamage(target) * 2
    end

    if Ready(_W) then
        damage = damage + GetWDamage(target)
    end

    if IsInE() then
        damage = damage + GetEDamage(target)
    end

    if includeR and Ready(_R) then
        damage = damage + GetRDamage(target)
    end

    local aaDamage = myHero.totalDamage * 2.5
    local armor = math_max(0, target.armor or 0)
    damage = damage + aaDamage * (100 / (100 + armor))

    return damage
end

local function IsKillable(target, includeR)
    if not target then return false end
    return GetComboDamage(target, includeR) >= target.health
end

local function GetPrediction(target, spellKey)
    if not target or not target.valid then return nil, 0 end

    local spellData = SPELL_DATA[spellKey]
    if not spellData then return {x = target.pos.x, z = target.pos.z}, 2 end

    local activeEngine = GetActivePredictionEngine()
    local castPos, hitChance = nil, 0

    if activeEngine == PRED_ENGINE_DEPRESSIVE then
        castPos, hitChance = GetDepressiveCastPosition(target, spellData)
        if not castPos then
            castPos, hitChance = GetGGCastPosition(target, spellData)
        end
    else
        castPos, hitChance = GetGGCastPosition(target, spellData)
        if not castPos then
            castPos, hitChance = GetDepressiveCastPosition(target, spellData)
        end
    end

    if castPos then
        return castPos, hitChance
    end

    return {x = target.pos.x, z = target.pos.z}, 2
end

local function GetRPrediction(target)
    if not target or not target.valid then return nil, 0, 0 end

    local castPos, hitChance = GetPrediction(target, "R")
    if not castPos then return nil, 0, 0 end

    local direction = Normalize2D({
        x = castPos.x - myHero.pos.x,
        z = castPos.z - myHero.pos.z
    })

    local hitCount = 0
    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy, SPELL_DATA.R.range) then

            local enemyPos = {x = enemy.pos.x, z = enemy.pos.z}
            local toEnemy = {
                x = enemyPos.x - myHero.pos.x,
                z = enemyPos.z - myHero.pos.z
            }

            local dot = toEnemy.x * direction.x + toEnemy.z * direction.z
            if dot > 0 and dot < SPELL_DATA.R.range then

                local perpX = toEnemy.x - dot * direction.x
                local perpZ = toEnemy.z - dot * direction.z
                local perpDist = math_sqrt(perpX * perpX + perpZ * perpZ)

                if perpDist <= SPELL_DATA.R.radius + (enemy.boundingRadius or 65) then
                    hitCount = hitCount + 1
                end
            end
        end
    end

    return castPos, hitChance, hitCount
end

local function GetTarget(range, mode)
    range = range or 1500
    mode = mode or "smart"

    local best = nil
    local bestScore = -math_huge

    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy, range) then
            local score = 0
            local dist = GetDistance(myHero.pos, enemy.pos)

            if mode == "smart" or mode == "combo" then

                local priority = PRIORITY_TARGETS[enemy.charName] or 2
                score = score + priority * 100

                score = score + (range - dist) * 0.5

                local hpPercent = enemy.health / enemy.maxHealth
                score = score + (1 - hpPercent) * 200

                if IsKillable(enemy, true) then
                    score = score + 500
                end

                if HasCC(enemy) then
                    score = score + 150
                end

                if IsKnockedUp(enemy) then
                    score = score + 300
                end

            elseif mode == "lowesthp" then
                score = -enemy.health

            elseif mode == "closest" then
                score = -dist

            elseif mode == "cursor" then
                local cursorPos = {x = mousePos.x, z = mousePos.z}
                local cursorDist = GetDistance(enemy.pos, cursorPos)
                score = -cursorDist
            end

            if score > bestScore then
                bestScore = score
                best = enemy
            end
        end
    end

    return best
end

local function GetRTarget(minEnemies)
    minEnemies = minEnemies or 1

    local best = nil
    local bestScore = -math_huge
    local bestHits = 0

    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy, SPELL_DATA.R.range) and IsKnockedUp(enemy) then
            local castPos, hitChance, hitCount = GetRPrediction(enemy)

            if hitCount >= minEnemies then
                local score = hitCount * 100

                local priority = PRIORITY_TARGETS[enemy.charName] or 2
                score = score + priority * 20

                if IsKillable(enemy, true) then
                    score = score + 200
                end

                if score > bestScore then
                    bestScore = score
                    best = enemy
                    bestHits = hitCount
                end
            end
        end
    end

    return best, bestHits
end

local function GetBestGapcloseMinion(target, maxRange)
    if not target then return nil end

    local best = nil
    local bestDist = math_huge
    local targetPos = target.pos

    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and not minion.dead and minion.visible and minion.team ~= myHero.team then
            local distToMe = GetDistance(myHero.pos, minion.pos)
            local distToTarget = GetDistance(minion.pos, targetPos)

            if distToMe <= 475 then

                local afterDashPos = VectorExtend(myHero.pos, minion.pos, 475)
                local newDistToTarget = GetDistance(afterDashPos, targetPos)

                if newDistToTarget < bestDist and newDistToTarget < GetDistance(myHero.pos, targetPos) then
                    bestDist = newDistToTarget
                    best = minion
                end
            end
        end
    end

    return best
end

local function GetBestQFlashPosition(target)
    if not target or not HasQ3() then return nil end

    local flashRange = 400
    local q3Range = SPELL_DATA.Q3.range

    local dist = GetDistance(myHero.pos, target.pos)

    if dist > q3Range and dist <= q3Range + flashRange then

        local direction = Normalize2D({
            x = target.pos.x - myHero.pos.x,
            z = target.pos.z - myHero.pos.z
        })

        local flashPos = {
            x = myHero.pos.x + direction.x * flashRange,
            z = myHero.pos.z + direction.z * flashRange
        }

        return flashPos, target.pos
    end

    return nil
end

class "DepressiveYone"

function DepressiveYone:__init()

    self.keys = {
        space = false,
        v = false,
        x = false,
        c = false,
        a = false
    }

    self.lastHealths = {}
    self.lastEState = false
    self.eStartTime = 0
    self.eEngageLock = false
    self.eEngageLockTime = 0

    self.comboState = "idle"
    self.lastActionTime = 0
    self.lastQ3CastTime = 0

    self.beybladeState = "idle"
    self.beybladeTarget = nil
    self.airbladeState = "idle"

    self.lastTickTime = 0
    self.tickInterval = 0.02

    self:LoadMenu()

    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("WndMsg", function(msg, wParam) self:OnWndMsg(msg, wParam) end)

end

function DepressiveYone:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveYone", name = "Depressive - Yone [Advanced]"})

    self.Menu:MenuElement({type = MENU, id = "pred", name = "[Prediction]"})
    self.Menu.pred:MenuElement({name = " ", drop = {"Default: GGPrediction"}})
    self.Menu.pred:MenuElement({id = "engine", name = "Prediction Engine", value = PRED_ENGINE_GG, drop = {"GGPrediction", "DepressivePrediction"}})
    PredictionMenu = self.Menu.pred

    self.Menu:MenuElement({type = MENU, id = "combo", name = "[Combo] Settings"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.combo:MenuElement({id = "useQ3", name = "Use Q3 (Tornado)", value = true})
    self.Menu.combo:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.combo:MenuElement({id = "useE", name = "Use E (Engage)", value = true})
    self.Menu.combo:MenuElement({id = "useR", name = "Use R", value = true})
    self.Menu.combo:MenuElement({id = "minHitChance", name = "Min Hit Chance (Q3/R)", value = 3, min = 1, max = 5, step = 1})

    self.Menu:MenuElement({type = MENU, id = "eExecute", name = "[E2] Execute System"})
    self.Menu.eExecute:MenuElement({id = "enabled", name = "Auto E2 Execute", value = true})
    self.Menu.eExecute:MenuElement({id = "safetyMargin", name = "Safety Margin %", value = 5, min = 0, max = 20, step = 1})
    self.Menu.eExecute:MenuElement({id = "minTimeInE", name = "Min Time in E (s)", value = 2.5, min = 1.0, max = 4.5, step = 0.5})
    self.Menu.eExecute:MenuElement({id = "minTimeRemaining", name = "Force Return if Time < (s)", value = 0.5, min = 0.2, max = 2.0, step = 0.1})
    self.Menu.eExecute:MenuElement({id = "onlyIfKillable", name = "Only E2 if Killable", value = true})
    self.Menu.eExecute:MenuElement({id = "drawDamage", name = "Draw E Mark Damage", value = true})

    self.Menu:MenuElement({type = MENU, id = "ultimate", name = "[R] Ultimate Settings"})
    self.Menu.ultimate:MenuElement({id = "minEnemies", name = "Min Enemies for R", value = 1, min = 1, max = 5, step = 1})
    self.Menu.ultimate:MenuElement({id = "onlyKnockedUp", name = "Only on Knocked Up", value = true})
    self.Menu.ultimate:MenuElement({id = "killableOverride", name = "Use R if Killable", value = true})
    self.Menu.ultimate:MenuElement({id = "priorityTargets", name = "Prioritize ADC/Mid", value = true})
    self.Menu.ultimate:MenuElement({id = "teamfightMode", name = "Teamfight Mode (2+ enemies)", value = true})
    self.Menu.ultimate:MenuElement({id = "lowHPThreshold", name = "Force R if HP <", value = 30, min = 10, max = 60, step = 5})

    self.Menu:MenuElement({type = MENU, id = "mechanics", name = "[Mechanics] Advanced"})
    self.Menu.mechanics:MenuElement({id = "q3Flash", name = "Q3 + Flash Combo", value = true})
    self.Menu.mechanics:MenuElement({id = "q3FlashKey", name = "Q3 Flash Key", key = string.byte("T"), toggle = false})
    self.Menu.mechanics:MenuElement({id = "airbladeEnabled", name = "Enable Airblade (E-Q3-R)", value = true})
    self.Menu.mechanics:MenuElement({id = "eqCombo", name = "E-Q Combo", value = true})
    self.Menu.mechanics:MenuElement({id = "autoQ3Knockup", name = "Auto Q3 on CC'd Enemies", value = true})

    self.Menu:MenuElement({type = MENU, id = "gapcloser", name = "[Gapcloser] Settings"})
    self.Menu.gapcloser:MenuElement({id = "enabled", name = "Enable Gapcloser", value = true})
    self.Menu.gapcloser:MenuElement({id = "useMinions", name = "Use Minions for Gap Close", value = true})
    self.Menu.gapcloser:MenuElement({id = "maxRange", name = "Max Gap Close Range", value = 1200, min = 600, max = 1500, step = 50})
    self.Menu.gapcloser:MenuElement({id = "chainE", name = "Chain E through Minions", value = true})

    self.Menu:MenuElement({type = MENU, id = "safety", name = "[Safety] Turret Check"})
    self.Menu.safety:MenuElement({id = "enabled", name = "Turret Safety Check", value = true})
    self.Menu.safety:MenuElement({id = "range", name = "Safety Range", value = 900, min = 700, max = 1100, step = 50})
    self.Menu.safety:MenuElement({id = "allowLowHP", name = "Ignore if Enemy HP <", value = 20, min = 10, max = 40, step = 5})
    self.Menu.safety:MenuElement({id = "allowE2Return", name = "Allow E2 Under Turret", value = true})

    self.Menu:MenuElement({type = MENU, id = "harass", name = "[Harass] Settings"})
    self.Menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.harass:MenuElement({id = "useQ3", name = "Use Q3", value = false})
    self.Menu.harass:MenuElement({id = "useW", name = "Use W", value = true})

    self.Menu:MenuElement({type = MENU, id = "clear", name = "[Clear] Settings"})
    self.Menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.clear:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.clear:MenuElement({id = "saveQ3", name = "Save Q3 for Champions", value = true})
    self.Menu.clear:MenuElement({id = "stackQ", name = "Stack Q on Minions", value = true})

    self.Menu:MenuElement({type = MENU, id = "lasthit", name = "[LastHit] Settings"})
    self.Menu.lasthit:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.lasthit:MenuElement({id = "saveQ3", name = "Save Q3", value = true})

    self.Menu:MenuElement({type = MENU, id = "flee", name = "[Flee] Settings"})
    self.Menu.flee:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.flee:MenuElement({id = "useQ3", name = "Use Q3 (Knockup Chasers)", value = true})

    self.Menu:MenuElement({type = MENU, id = "draw", name = "[Draw] Visuals"})
    self.Menu.draw:MenuElement({id = "qRange", name = "Draw Q Range", value = true})
    self.Menu.draw:MenuElement({id = "wRange", name = "Draw W Range", value = true})
    self.Menu.draw:MenuElement({id = "eRange", name = "Draw E Range", value = true})
    self.Menu.draw:MenuElement({id = "rRange", name = "Draw R Range", value = true})
    self.Menu.draw:MenuElement({id = "eDamage", name = "Draw E Mark Damage", value = true})
    self.Menu.draw:MenuElement({id = "killable", name = "Draw Killable Indicator", value = true})
    self.Menu.draw:MenuElement({id = "eTimer", name = "Draw E Timer", value = true})
    self.Menu.draw:MenuElement({id = "qStacks", name = "Draw Q Stacks", value = true})
    self.Menu.draw:MenuElement({id = "status", name = "Draw Status", value = true})

    self.Menu:MenuElement({type = MENU, id = "performance", name = "[Performance]"})
    self.Menu.performance:MenuElement({id = "tickRate", name = "Tick Rate (ms)", value = 20, min = 10, max = 50, step = 5})
    self.Menu.performance:MenuElement({id = "lowFPS", name = "Low FPS Mode", value = false})
end

function DepressiveYone:OnWndMsg(msg, wParam)
    if msg == KEY_DOWN then
        if wParam == 32 then self.keys.space = true end
        if wParam == 86 then self.keys.v = true end
        if wParam == 88 then self.keys.x = true end
        if wParam == 67 then self.keys.c = true end
        if wParam == 65 then self.keys.a = true end
    elseif msg == KEY_UP then
        if wParam == 32 then self.keys.space = false end
        if wParam == 86 then self.keys.v = false end
        if wParam == 88 then self.keys.x = false end
        if wParam == 67 then self.keys.c = false end
        if wParam == 65 then self.keys.a = false end
    end
end

function DepressiveYone:UpdateETracker()
    local inEState = IsInE()

    if inEState and not self.lastEState then
        ETracker:Start()

        if self.eStartTime <= 0 then
            self.eStartTime = GameTimer()
        end

        ETracker.targets = {}

    elseif not inEState and self.lastEState then
        ETracker:Stop()

        self.eStartTime = 0
        self.eEngageLock = false
        self.eEngageLockTime = 0
        ETracker.targets = {}
    end

    self.lastEState = inEState

    if inEState then
        for i = 1, GameHeroCount() do
            local enemy = GameHero(i)
            if IsValidTarget(enemy) then
                local networkID = enemy.networkID
                local currentHP = enemy.health
                local lastHP = self.lastHealths[networkID] or currentHP
                local delta = lastHP - currentHP

                if delta > 0 and delta < 5000 then
                    local inRange = GetDistance(myHero.pos, enemy.pos) < 2500

                    if inRange then
                        if not ETracker.targets[networkID] then
                            ETracker.targets[networkID] = {damage = 0, hits = 0}
                        end
                        ETracker.targets[networkID].damage = ETracker.targets[networkID].damage + delta
                        ETracker.targets[networkID].hits = ETracker.targets[networkID].hits + 1
                    end
                end

                self.lastHealths[networkID] = currentHP
            end
        end
    end
end

function DepressiveYone:Tick()
    if myHero.dead or GameIsChatOpen() then return end

    local now = GameTimer()
    local tickRate = self.Menu.performance.tickRate:Value() / 1000
    if now - self.lastTickTime < tickRate then return end
    self.lastTickTime = now

    Cache:Cleanup()

    self:UpdateETracker()

    if self.Menu.eExecute.enabled:Value() then
        local inE = IsInE()
        if inE and self.eStartTime > 0 then
            local timeInE = now - self.eStartTime
            local minTime = self.Menu.eExecute.minTimeInE:Value()

            if timeInE >= minTime then
                self:CheckE2Execute()
            end
        elseif inE and self.eStartTime <= 0 then

            self.eStartTime = now
        end
    end

    if self.Menu.mechanics.q3Flash:Value() and self.Menu.mechanics.q3FlashKey:Value() then
        self:Q3FlashCombo()
    end

    if self.Menu.mechanics.autoQ3Knockup:Value() and HasQ3() and Ready(_Q) then
        self:AutoQ3OnCC()
    end

    if self.keys.space then
        self:Combo()
    elseif self.keys.c then
        self:Harass()
    elseif self.keys.v then
        self:Clear()
    elseif self.keys.x then
        self:LastHit()
    elseif self.keys.a then
        self:Flee()
    end
end

function DepressiveYone:CheckE2Execute()

    if not Ready(_E) then return end
    if not IsInE() then return end

    local now = GameTimer()
    local timeInE = now - self.eStartTime
    local safetyMargin = 1 + (self.Menu.eExecute.safetyMargin:Value() / 100)
    local minTimeRemaining = self.Menu.eExecute.minTimeRemaining:Value()
    local onlyIfKillable = self.Menu.eExecute.onlyIfKillable:Value()

    local timeRemaining = 5.0 - timeInE

    if timeRemaining < minTimeRemaining then
        local hasStoredDamage = false
        for i = 1, GameHeroCount() do
            local enemy = GameHero(i)
            if IsValidTarget(enemy) then
                local storedDmg = ETracker:GetStoredDamage(enemy)
                if storedDmg > 0 then
                    hasStoredDamage = true
                    break
                end
            end
        end

        if hasStoredDamage then
            Control.CastSpell(HK_E)
            return
        end
    end

    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy) then
            local executeDmg = ETracker:GetExecuteDamage(enemy)

            if executeDmg <= 0 then
                goto continue
            end

            local enemyHP = enemy.health
            local willKill = executeDmg > (enemyHP * safetyMargin)

            if onlyIfKillable and not willKill then
                goto continue
            end

            if willKill then

                local bodyPos = GetEBodyPosition()
                local safe = true

                if self.Menu.safety.enabled:Value() and bodyPos then
                    local underTurret = IsUnderEnemyTurret(bodyPos, self.Menu.safety.range:Value())
                    safe = not underTurret or self.Menu.safety.allowE2Return:Value()
                end

                if safe then
                    Control.CastSpell(HK_E)
                    return
                end
            end

            ::continue::
        end
    end
end

function DepressiveYone:Combo()
    local target = GetTarget(1500, "smart")
    if not target then return end

    local dist = GetDistance(myHero.pos, target.pos)

    local safeToEngage = true
    if self.Menu.safety.enabled:Value() then
        local hpPercent = (target.health / target.maxHealth) * 100
        if hpPercent > self.Menu.safety.allowLowHP:Value() then
            safeToEngage = not IsUnderEnemyTurret(target.pos, self.Menu.safety.range:Value())
        end
    end

    if self.Menu.combo.useR:Value() and Ready(_R) then
        local rTarget, hitCount = GetRTarget(self.Menu.ultimate.minEnemies:Value())

        if rTarget then
            local shouldR = false

            if self.Menu.ultimate.teamfightMode:Value() and hitCount >= 2 then
                shouldR = true
            end

            if self.Menu.ultimate.killableOverride:Value() and IsKillable(rTarget, true) then
                shouldR = true
            end

            local hpPercent = (rTarget.health / rTarget.maxHealth) * 100
            if hpPercent <= self.Menu.ultimate.lowHPThreshold:Value() then
                shouldR = true
            end

            if self.Menu.ultimate.priorityTargets:Value() and PRIORITY_TARGETS[rTarget.charName] then
                if hitCount >= 1 then
                    shouldR = true
                end
            end

            if shouldR and IsKnockedUp(rTarget) then
                local castPos, hitChance = GetPrediction(rTarget, "R")
                if castPos and hitChance >= self.Menu.combo.minHitChance:Value() then
                    Control.CastSpell(HK_R, Vector(castPos.x, myHero.pos.y, castPos.z))
                    return
                end
            end
        end
    end

    if self.Menu.combo.useE:Value() and Ready(_E) and safeToEngage then

        local currentlyInE = IsInE()

        if not currentlyInE then

            if dist <= SPELL_DATA.Q3.range + 200 and dist > 300 then

                self.eStartTime = GameTimer()
                Control.CastSpell(HK_E, target.pos)
                return
            end
        end

    end

    if self.Menu.combo.useQ3:Value() and HasQ3() and Ready(_Q) then
        if dist <= SPELL_DATA.Q3.range then
            local castPos, hitChance = GetPrediction(target, "Q3")
            if castPos and hitChance >= self.Menu.combo.minHitChance:Value() then
                Control.CastSpell(HK_Q, Vector(castPos.x, myHero.pos.y, castPos.z))
                self.lastQ3CastTime = GameTimer()
                return
            end
        end
    end

    if self.Menu.combo.useQ:Value() and not HasQ3() and Ready(_Q) then
        if dist <= SPELL_DATA.Q1.range then
            local castPos, hitChance = GetPrediction(target, "Q1")
            if castPos then
                Control.CastSpell(HK_Q, Vector(castPos.x, myHero.pos.y, castPos.z))
                return
            end
        end
    end

    if self.Menu.combo.useW:Value() and Ready(_W) then
        if dist <= SPELL_DATA.W.range then
            Control.CastSpell(HK_W, target.pos)
            return
        end
    end

    if self.Menu.gapcloser.enabled:Value() and self.Menu.gapcloser.useMinions:Value() then
        if dist > SPELL_DATA.Q1.range and dist <= self.Menu.gapcloser.maxRange:Value() then
            local minion = GetBestGapcloseMinion(target, self.Menu.gapcloser.maxRange:Value())
            if minion and Ready(_E) and not IsInE() then
                Control.CastSpell(HK_E, minion.pos)
                return
            end
        end
    end
end

function DepressiveYone:Q3FlashCombo()
    if not HasQ3() or not Ready(_Q) then return end

    local flashSlot = nil
    local d = myHero:GetSpellData(SUMMONER_1)
    if d and d.name == "SummonerFlash" and d.currentCd == 0 then
        flashSlot = HK_SUMMONER_1
    else
        d = myHero:GetSpellData(SUMMONER_2)
        if d and d.name == "SummonerFlash" and d.currentCd == 0 then
            flashSlot = HK_SUMMONER_2
        end
    end

    if not flashSlot then return end

    local target = GetTarget(SPELL_DATA.Q3.range + 400, "cursor")
    if not target then return end

    local dist = GetDistance(myHero.pos, target.pos)

    if dist > SPELL_DATA.Q3.range and dist <= SPELL_DATA.Q3.range + 400 then
        local flashPos, qPos = GetBestQFlashPosition(target)
        if flashPos then

            Control.CastSpell(HK_Q, Vector(qPos.x, myHero.pos.y, qPos.z))

            DelayAction(function()
                Control.CastSpell(flashSlot, Vector(flashPos.x, myHero.pos.y, flashPos.z))
            end, 0.05)
            return
        end
    end
end

function DepressiveYone:AutoQ3OnCC()
    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy, SPELL_DATA.Q3.range) then
            local isCC, duration = HasCC(enemy)
            if isCC and duration > 0.3 then
                local castPos, hitChance = GetPrediction(enemy, "Q3")
                if castPos then
                    Control.CastSpell(HK_Q, Vector(castPos.x, myHero.pos.y, castPos.z))
                    return
                end
            end
        end
    end
end

function DepressiveYone:Harass()
    local target = GetTarget(SPELL_DATA.Q3.range, "smart")
    if not target then return end

    local dist = GetDistance(myHero.pos, target.pos)

    if self.Menu.harass.useQ3:Value() and HasQ3() and Ready(_Q) then
        if dist <= SPELL_DATA.Q3.range then
            local castPos, hitChance = GetPrediction(target, "Q3")
            if castPos and hitChance >= 3 then
                Control.CastSpell(HK_Q, Vector(castPos.x, myHero.pos.y, castPos.z))
                return
            end
        end
    end

    if self.Menu.harass.useQ:Value() and not HasQ3() and Ready(_Q) then
        if dist <= SPELL_DATA.Q1.range then
            local castPos = GetPrediction(target, "Q1")
            if castPos then
                Control.CastSpell(HK_Q, Vector(castPos.x, myHero.pos.y, castPos.z))
                return
            end
        end
    end

    if self.Menu.harass.useW:Value() and Ready(_W) then
        if dist <= SPELL_DATA.W.range then
            Control.CastSpell(HK_W, target.pos)
            return
        end
    end
end

function DepressiveYone:Clear()
    local qRange = HasQ3() and SPELL_DATA.Q3.range or SPELL_DATA.Q1.range

    local best = nil
    local bestScore = -math_huge

    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and not minion.dead and minion.visible and minion.team ~= myHero.team then
            local dist = GetDistance(myHero.pos, minion.pos)
            if dist <= qRange then
                local score = 0

                local name = string_lower(minion.charName or "")
                if string_find(name, "siege") or string_find(name, "cannon") then
                    score = score + 100
                end

                score = score - dist * 0.1

                score = score - minion.health * 0.5

                if score > bestScore then
                    bestScore = score
                    best = minion
                end
            end
        end
    end

    if not best then return end

    if HasQ3() and self.Menu.clear.saveQ3:Value() then

        local enemyNearby = false
        for i = 1, GameHeroCount() do
            local enemy = GameHero(i)
            if IsValidTarget(enemy, 1500) then
                enemyNearby = true
                break
            end
        end

        if enemyNearby then

            if self.Menu.clear.useW:Value() and Ready(_W) then
                if GetDistance(myHero.pos, best.pos) <= SPELL_DATA.W.range then
                    Control.CastSpell(HK_W, best.pos)
                    return
                end
            end
            return
        end
    end

    if self.Menu.clear.useW:Value() and Ready(_W) then
        if GetDistance(myHero.pos, best.pos) <= SPELL_DATA.W.range then
            Control.CastSpell(HK_W, best.pos)
            return
        end
    end

    if self.Menu.clear.useQ:Value() and Ready(_Q) then
        local castPos = GetPrediction(best, HasQ3() and "Q3" or "Q1")
        if castPos then
            Control.CastSpell(HK_Q, Vector(castPos.x, myHero.pos.y, castPos.z))
            return
        end
    end
end

function DepressiveYone:LastHit()
    if not self.Menu.lasthit.useQ:Value() or not Ready(_Q) then return end

    if HasQ3() and self.Menu.lasthit.saveQ3:Value() then return end

    local qRange = HasQ3() and SPELL_DATA.Q3.range or SPELL_DATA.Q1.range
    local best = nil
    local bestHP = math_huge

    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and not minion.dead and minion.visible and minion.team ~= myHero.team then
            local dist = GetDistance(myHero.pos, minion.pos)
            if dist <= qRange then
                local qDmg = GetQDamage(minion)

                if qDmg >= minion.health * 0.95 and minion.health < bestHP then
                    bestHP = minion.health
                    best = minion
                end
            end
        end
    end

    if best then
        local castPos = GetPrediction(best, HasQ3() and "Q3" or "Q1")
        if castPos then
            Control.CastSpell(HK_Q, Vector(castPos.x, myHero.pos.y, castPos.z))
        end
    end
end

function DepressiveYone:Flee()

    if self.Menu.flee.useE:Value() and Ready(_E) and not IsInE() then
        local mousePos2D = {x = mousePos.x, z = mousePos.z}
        Control.CastSpell(HK_E, Vector(mousePos.x, myHero.pos.y, mousePos.z))
        return
    end

    if self.Menu.flee.useQ3:Value() and HasQ3() and Ready(_Q) then
        for i = 1, GameHeroCount() do
            local enemy = GameHero(i)
            if IsValidTarget(enemy, SPELL_DATA.Q3.range) then
                local dist = GetDistance(myHero.pos, enemy.pos)
                if dist <= SPELL_DATA.Q3.range then
                    local castPos = GetPrediction(enemy, "Q3")
                    if castPos then
                        Control.CastSpell(HK_Q, Vector(castPos.x, myHero.pos.y, castPos.z))
                        return
                    end
                end
            end
        end
    end
end

function DepressiveYone:Draw()
    if myHero.dead then return end

    local heroPos = myHero.pos

    if self.Menu.draw.qRange:Value() then
        local qRange = HasQ3() and SPELL_DATA.Q3.range or SPELL_DATA.Q1.range
        local color = HasQ3() and Draw.Color(200, 0, 200, 255) or Draw.Color(200, 255, 255, 255)
        Draw.Circle(heroPos, qRange, 1, color)
    end

    if self.Menu.draw.wRange:Value() and Ready(_W) then
        Draw.Circle(heroPos, SPELL_DATA.W.range, 1, Draw.Color(200, 255, 200, 0))
    end

    if self.Menu.draw.eRange:Value() then
        if IsInE() and ETracker.bodyPosition then
            local bodyPos = Vector(ETracker.bodyPosition.x, heroPos.y, ETracker.bodyPosition.z)
            Draw.Circle(bodyPos, 100, 2, Draw.Color(255, 0, 255, 255))
        end
    end

    if self.Menu.draw.rRange:Value() and Ready(_R) then
        Draw.Circle(heroPos, SPELL_DATA.R.range, 1, Draw.Color(150, 255, 100, 100))
    end

    if self.Menu.draw.eTimer:Value() and ETracker.active then
        local remaining = ETracker:GetRemainingTime()
        local pos = heroPos:To2D()
        if pos.onScreen then
            local color = remaining < 1 and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 255, 255, 255)
            Draw.Text(string_format("E: %.1fs", remaining), 18, pos.x - 25, pos.y - 80, color)
        end
    end

    if self.Menu.draw.qStacks:Value() then
        local stacks = GetQStacks()
        local pos = heroPos:To2D()
        if pos.onScreen then
            local stackText = HasQ3() and "Q3 READY!" or string_format("Q: %d/2", stacks)
            local color = HasQ3() and Draw.Color(255, 0, 200, 255) or Draw.Color(255, 255, 255, 255)
            Draw.Text(stackText, 16, pos.x - 30, pos.y + 40, color)
        end
    end

    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy) then
            local pos = enemy.pos:To2D()
            if pos.onScreen then
                local yOffset = -60

                if self.Menu.draw.eDamage:Value() and ETracker.active then
                    local executeDmg = ETracker:GetExecuteDamage(enemy)
                    if executeDmg > 0 then
                        local isKill = ETracker:IsExecutable(enemy)
                        local color = isKill and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 0, 255, 0)
                        local text = isKill and "EXECUTE!" or string_format("E: %d", math_floor(executeDmg))
                        Draw.Text(text, 16, pos.x - 30, pos.y + yOffset, color)
                        yOffset = yOffset - 18

                        local pct = math_floor((executeDmg / enemy.health) * 100)
                        Draw.Text(string_format("%d%%", pct), 12, pos.x - 15, pos.y + yOffset, Draw.Color(255, 255, 255, 255))
                        yOffset = yOffset - 15
                    end
                end

                if self.Menu.draw.killable:Value() then
                    if IsKillable(enemy, true) then
                        Draw.Text("KILLABLE", 14, pos.x - 30, pos.y + yOffset, Draw.Color(255, 255, 50, 50))
                    end
                end
            end
        end
    end

    if self.Menu.draw.status:Value() then
        local status = "Idle"
        if self.keys.space then status = "COMBO"
        elseif self.keys.c then status = "HARASS"
        elseif self.keys.v then status = "CLEAR"
        elseif self.keys.x then status = "LASTHIT"
        elseif self.keys.a then status = "FLEE"
        end

        Draw.Text("[Yone] " .. status, 16, 10, 50, Draw.Color(255, 255, 200, 0))

        if IsInE() then
            Draw.Text("E ACTIVE - Ready to Execute", 14, 10, 70, Draw.Color(255, 0, 255, 255))
        end
    end
end

if not _G.DepressiveYoneInstance then
    _G.DepressiveYoneInstance = DepressiveYone()
    if _G.DepressiveAIONextLoaded then
        _G.DepressiveAIONextLoadedChampion = true
    end
end
