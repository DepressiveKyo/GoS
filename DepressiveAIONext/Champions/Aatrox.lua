local VERSION = "2.0"
local SCRIPT_NAME = "DepressiveAatroxUltimate"

-- Guard against multiple loads
if _G.__DEPRESSIVE_AATROX_ULTIMATE_LOADED then return end
if myHero.charName ~= "Aatrox" then return end
_G.__DEPRESSIVE_AATROX_ULTIMATE_LOADED = true

-- Load prediction system
local DepressivePrediction = require("DepressivePrediction")
if not DepressivePrediction then
    print("[" .. SCRIPT_NAME .. "] ERROR: DepressivePrediction not found!")
    return
end

------------------------------------------------------------
-- LOCALIZED FUNCTIONS (Performance optimization)
------------------------------------------------------------
local math_sqrt = math.sqrt
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_huge = math.huge
local math_floor = math.floor
local math_ceil = math.ceil
local math_cos = math.cos
local math_sin = math.sin
local math_atan2 = math.atan2
local math_pi = math.pi
local math_random = math.random

local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort

local os_clock = os.clock
local pairs = pairs
local ipairs = ipairs
local type = type
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local string_lower = string.lower

local Game = _G.Game
local Control = _G.Control
local Draw = _G.Draw
local Vector = _G.Vector
local myHero = _G.myHero

local GameTimer = Game.Timer
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameTurretCount = Game.TurretCount
local GameTurret = Game.Turret
local GameMissileCount = Game.MissileCount
local GameMissile = Game.Missile

-- Forward declaration of Menu
local Menu

------------------------------------------------------------
-- SPELL SLOT CONSTANTS
------------------------------------------------------------
local _Q, _W, _E, _R = 0, 1, 2, 3
local HK_Q = HK_Q or _Q
local HK_W = HK_W or _W
local HK_E = HK_E or _E
local HK_R = HK_R or _R
local HK_FLASH = HK_SUMMONER_1

------------------------------------------------------------
-- TEAM CONSTANTS
------------------------------------------------------------
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = (myHero.team == 100 and 200) or 100
local TEAM_JUNGLE = 300

------------------------------------------------------------
-- SPELL DATA (Updated for current patch)
------------------------------------------------------------
local SpellData = {
    Q = {
        [1] = { range = 625, width = 180, sweetMin = 525, sweetMax = 625, castTime = 0.6, movement = 50 },
        [2] = { range = 475, width = 400, sweetMin = 375, sweetMax = 475, castTime = 0.6, movement = 75 },
        [3] = { range = 300, width = 300, sweetMin = 100, sweetMax = 200, castTime = 0.6, movement = 150 }
    },
    W = { range = 825, width = 160, speed = 1800, castTime = 0.25, pullDelay = 1.5 },
    E = { range = 300, speed = 800, cooldown = {9, 8, 7, 6, 5} },
    R = { range = 600, duration = 10, castTime = 0.25 }
}

-- Base damage values
local DamageData = {
    Q = {
        base = {10, 25, 40, 55, 70},
        adRatio = {
            {0.60, 0.675, 0.75, 0.825, 0.90},   -- Q1
            {0.75, 0.84375, 0.9375, 1.03125, 1.125}, -- Q2
            {0.90, 1.0125, 1.125, 1.2375, 1.35}  -- Q3
        },
        castMultiplier = {1.0, 1.25, 1.50}, -- Q1, Q2, Q3
        sweetSpotBonus = 1.70 -- +70% damage
    },
    W = {
        base = {30, 40, 50, 60, 70},
        adRatio = 0.40,
        pullMultiplier = 2.0
    },
    Passive = {
        hpPercent = {0.04, 0.08}, -- scales from 4% to 8%
        healPercent = 1.0 -- 100% of damage dealt
    },
    R = {
        bonusAD = {0.20, 0.30, 0.40},
        moveSpeed = {60, 80, 100},
        healingAmp = {0.50, 0.75, 1.00}
    }
}

------------------------------------------------------------
-- STATE TRACKING
------------------------------------------------------------
local State = {
    -- Timers
    lastQTime = 0,
    lastWTime = 0,
    lastETime = 0,
    lastRTime = 0,
    lastCastTime = 0,
    
    -- Q Phase tracking
    qPhase = 0,
    qStartTime = 0,
    qSequenceStart = 0,
    
    -- W tracking
    wTarget = nil,
    wCastTime = 0,
    wPullTime = 0,
    
    -- Passive tracking
    passiveReady = false,
    passiveStacks = 0,
    lastPassiveTime = 0,
    
    -- R state
    rActive = false,
    rStartTime = 0,
    rEndTime = 0,
    
    -- Combat tracking
    inCombat = false,
    combatStartTime = 0,
    lastDamageTime = 0,
    
    -- Enemy movement patterns
    enemyPatterns = {},
    
    -- Combo state
    comboTarget = nil,
    comboPhase = 0,
    
    -- Flash combo
    flashReady = false,
    flashComboTarget = nil,
    
    -- E during Q
    ePendingDuringQ = false,
    eTargetPos = nil
}

------------------------------------------------------------
-- DELAYED ACTIONS SYSTEM
------------------------------------------------------------
local DelayedActions = {}

local function DelayAction(func, delay)
    table_insert(DelayedActions, {
        func = func,
        time = os_clock() + delay
    })
end

local function ProcessDelayedActions()
    local now = os_clock()
    for i = #DelayedActions, 1, -1 do
        if now >= DelayedActions[i].time then
            local success, err = pcall(DelayedActions[i].func)
            if not success and Menu and Menu.Misc and Menu.Misc.Debug and Menu.Misc.Debug:Value() then
                print("[" .. SCRIPT_NAME .. "] DelayAction error: " .. tostring(err))
            end
            table_remove(DelayedActions, i)
        end
    end
end

------------------------------------------------------------
-- UTILITY FUNCTIONS
------------------------------------------------------------
local function IsValid(unit)
    return unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable
end

local function Distance(p1, p2)
    local pos1 = p1.pos or p1
    local pos2 = p2.pos or p2
    local dx = pos1.x - pos2.x
    local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
    return math_sqrt(dx * dx + dz * dz)
end

local function DistanceSqr(p1, p2)
    local pos1 = p1.pos or p1
    local pos2 = p2.pos or p2
    local dx = pos1.x - pos2.x
    local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
    return dx * dx + dz * dz
end

local function GetDirection(from, to)
    local fromPos = from.pos or from
    local toPos = to.pos or to
    local dx = toPos.x - fromPos.x
    local dz = (toPos.z or toPos.y) - (fromPos.z or fromPos.y)
    local len = math_sqrt(dx * dx + dz * dz)
    if len < 1 then return {x = 0, z = 0} end
    return {x = dx / len, z = dz / len}
end

local function ExtendPosition(from, to, distance)
    local dir = GetDirection(from, to)
    local fromPos = from.pos or from
    return {
        x = fromPos.x + dir.x * distance,
        y = fromPos.y or 0,
        z = (fromPos.z or fromPos.y) + dir.z * distance
    }
end

local function RotatePosition(center, point, angle)
    local centerPos = center.pos or center
    local pointPos = point.pos or point
    local cos = math_cos(angle)
    local sin = math_sin(angle)
    local dx = pointPos.x - centerPos.x
    local dz = (pointPos.z or pointPos.y) - (centerPos.z or centerPos.y)
    return {
        x = centerPos.x + dx * cos - dz * sin,
        y = centerPos.y or 0,
        z = (centerPos.z or centerPos.y) + dx * sin + dz * cos
    }
end

local function Normalize(vec)
    local len = math_sqrt(vec.x * vec.x + (vec.z or vec.y or 0) * (vec.z or vec.y or 0))
    if len < 0.001 then return {x = 0, z = 0} end
    return {x = vec.x / len, z = (vec.z or vec.y or 0) / len}
end

local function VectorLength(vec)
    return math_sqrt(vec.x * vec.x + (vec.z or vec.y or 0) * (vec.z or vec.y or 0))
end

------------------------------------------------------------
-- SPELL READY CHECKS
------------------------------------------------------------
local function Ready(slot)
    local spellData = myHero:GetSpellData(slot)
    if not spellData or spellData.level == 0 then return false end
    if spellData.currentCd ~= 0 then return false end
    local canUse = Game.CanUseSpell(slot)
    return canUse == 0 -- READY
end

local function GetSpellLevel(slot)
    local spellData = myHero:GetSpellData(slot)
    return spellData and spellData.level or 0
end

local function MyHeroNotReady()
    if myHero.dead then return true end
    if Game.IsChatOpen() then return true end
    if _G.JustEvade and _G.JustEvade:Evading() then return true end
    if _G.ExtLibEvade and _G.ExtLibEvade.Evading then return true end
    return false
end

------------------------------------------------------------
-- Q PHASE DETECTION
------------------------------------------------------------
local function GetQPhase()
    local spellName = myHero:GetSpellData(_Q).name
    if spellName == "AatroxQ" then return 1
    elseif spellName == "AatroxQ2" then return 2
    elseif spellName == "AatroxQ3" then return 3
    end
    return 0
end

local function GetQData(phase)
    phase = phase or GetQPhase()
    if phase == 0 then phase = 1 end
    return SpellData.Q[phase]
end

------------------------------------------------------------
-- ENEMY CACHING
------------------------------------------------------------
local EnemyCache = { lastUpdate = 0, heroes = {} }

local function GetEnemyHeroes()
    local now = GameTimer()
    if now - EnemyCache.lastUpdate > 0.1 then
        EnemyCache.heroes = {}
        for i = 1, GameHeroCount() do
            local hero = GameHero(i)
            if hero and hero.team == TEAM_ENEMY and IsValid(hero) then
                table_insert(EnemyCache.heroes, hero)
            end
        end
        EnemyCache.lastUpdate = now
    end
    return EnemyCache.heroes
end

local function EnemiesInRange(range, from)
    from = from or myHero.pos
    local count = 0
    local rangeSqr = range * range
    for _, enemy in ipairs(GetEnemyHeroes()) do
        if DistanceSqr(from, enemy.pos) <= rangeSqr then
            count = count + 1
        end
    end
    return count
end

local function GetMinionsInRange(range, from, team)
    from = from or myHero.pos
    local minions = {}
    local rangeSqr = range * range
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and minion.team == team and not minion.dead then
            if DistanceSqr(from, minion.pos) <= rangeSqr then
                table_insert(minions, minion)
            end
        end
    end
    return minions
end

------------------------------------------------------------
-- ORBWALKER MODE DETECTION
------------------------------------------------------------
local function GetOrbwalkerMode()
    -- Check SDK Orbwalker
    if _G.SDK and _G.SDK.Orbwalker then
        local modes = _G.SDK.Orbwalker.Modes
        if modes then
            if modes[_G.SDK.ORBWALKER_MODE_COMBO] then return "Combo" end
            if modes[_G.SDK.ORBWALKER_MODE_HARASS] then return "Harass" end
            if modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then return "Clear" end
            if modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then return "Jungle" end
            if modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then return "LastHit" end
            if modes[_G.SDK.ORBWALKER_MODE_FLEE] then return "Flee" end
        end
    end
    
    -- Check GOS Orbwalker
    if _G.GOS and _G.GOS.GetMode then
        local mode = _G.GOS:GetMode()
        if mode == 1 then return "Combo"
        elseif mode == 2 then return "Harass"
        elseif mode == 3 then return "Clear"
        end
    end
    
    return "None"
end

------------------------------------------------------------
-- TARGET SELECTOR
------------------------------------------------------------
local function GetPriorityScore(target)
    if not target or not IsValid(target) then return 0 end
    
    local score = 0
    local dist = Distance(myHero.pos, target.pos)
    
    -- Distance score (closer = higher)
    score = score + (1200 - dist) / 100
    
    -- HP percentage (lower HP = higher priority)
    local hpPercent = target.health / target.maxHealth
    score = score + (1 - hpPercent) * 20
    
    -- Can be killed by combo
    local comboDmg = CalculateFullComboDamage(target)
    if comboDmg >= target.health then
        score = score + 50
    end
    
    -- Sweet spot bonus
    local phase = GetQPhase()
    if phase > 0 then
        local qData = GetQData(phase)
        if dist >= qData.sweetMin and dist <= qData.sweetMax then
            score = score + 15
        end
    end
    
    -- W pull potential
    if State.wTarget == target and os_clock() - State.wCastTime < 1.5 then
        score = score + 30 -- Prioritize W pull targets
    end
    
    return score
end

local function GetBestTarget(range)
    range = range or 1200
    local bestTarget = nil
    local bestScore = -math_huge
    
    for _, enemy in ipairs(GetEnemyHeroes()) do
        local dist = Distance(myHero.pos, enemy.pos)
        if dist <= range then
            local score = GetPriorityScore(enemy)
            if score > bestScore then
                bestScore = score
                bestTarget = enemy
            end
        end
    end
    
    return bestTarget
end

------------------------------------------------------------
-- ENEMY MOVEMENT PATTERN TRACKING
------------------------------------------------------------
local function UpdateEnemyPattern(enemy)
    if not enemy or not IsValid(enemy) then return end
    
    local id = enemy.networkID
    if not State.enemyPatterns[id] then
        State.enemyPatterns[id] = {
            positions = {},
            timestamps = {},
            avgSpeed = 0,
            movementDirection = {x = 0, z = 0},
            isJuking = false,
            lastDirectionChange = 0,
            directionChanges = 0
        }
    end
    
    local pattern = State.enemyPatterns[id]
    local now = os_clock()
    
    -- Store position history
    table_insert(pattern.positions, {x = enemy.pos.x, z = enemy.pos.z or enemy.pos.y})
    table_insert(pattern.timestamps, now)
    
    -- Keep only last 20 positions (2 seconds at 10 samples/sec)
    while #pattern.positions > 20 do
        table_remove(pattern.positions, 1)
        table_remove(pattern.timestamps, 1)
    end
    
    -- Calculate movement patterns
    if #pattern.positions >= 3 then
        local lastPos = pattern.positions[#pattern.positions]
        local prevPos = pattern.positions[#pattern.positions - 1]
        local oldPos = pattern.positions[#pattern.positions - 2]
        
        -- Current direction
        local currDir = GetDirection(prevPos, lastPos)
        local prevDir = GetDirection(oldPos, prevPos)
        
        -- Check for direction changes (juking)
        local dirChange = math_abs(currDir.x - prevDir.x) + math_abs(currDir.z - prevDir.z)
        if dirChange > 0.5 then
            pattern.directionChanges = pattern.directionChanges + 1
            pattern.lastDirectionChange = now
        end
        
        -- Reset direction change count after 2 seconds
        if now - pattern.lastDirectionChange > 2 then
            pattern.directionChanges = 0
        end
        
        -- Is enemy juking?
        pattern.isJuking = pattern.directionChanges >= 3
        
        -- Calculate average speed
        local totalDist = 0
        for i = 2, #pattern.positions do
            totalDist = totalDist + Distance(pattern.positions[i], pattern.positions[i-1])
        end
        local totalTime = pattern.timestamps[#pattern.timestamps] - pattern.timestamps[1]
        if totalTime > 0 then
            pattern.avgSpeed = totalDist / totalTime
        end
        
        pattern.movementDirection = currDir
    end
end

local function GetEnemyPattern(enemy)
    if not enemy then return nil end
    return State.enemyPatterns[enemy.networkID]
end

------------------------------------------------------------
-- PASSIVE TRACKING
------------------------------------------------------------
local function UpdatePassiveState()
    -- Check for Deathbringer Stance buff
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.count > 0 then
            if buff.name:lower():find("aatroxpassive") or buff.name:lower():find("deathbringer") then
                State.passiveReady = true
                State.passiveStacks = buff.count
                return
            end
        end
    end
    State.passiveReady = false
    State.passiveStacks = 0
end

------------------------------------------------------------
-- R STATE TRACKING
------------------------------------------------------------
local function UpdateRState()
    -- Check for World Ender buff
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.count > 0 then
            if buff.name:lower():find("aatroxr") or buff.name:lower():find("worldender") then
                if not State.rActive then
                    State.rActive = true
                    State.rStartTime = os_clock()
                    State.rEndTime = State.rStartTime + SpellData.R.duration
                end
                return
            end
        end
    end
    State.rActive = false
end

local function GetRRemainingTime()
    if not State.rActive then return 0 end
    return math_max(0, State.rEndTime - os_clock())
end

------------------------------------------------------------
-- DAMAGE CALCULATIONS
------------------------------------------------------------
local function GetTotalAD()
    return myHero.totalDamage or 100
end

local function GetBonusAD()
    return math_max(0, GetTotalAD() - (myHero.baseDamage or 60))
end

local function CalculatePhysicalDamage(target, rawDamage)
    if not target then return 0 end
    local armor = target.armor or 0
    local armorPen = myHero.armorPen or 0
    local armorPenPercent = myHero.armorPenPercent or 0
    
    -- Apply armor penetration
    local effectiveArmor = armor * (1 - armorPenPercent) - armorPen
    effectiveArmor = math_max(0, effectiveArmor)
    
    local modifier = 100 / (100 + effectiveArmor)
    return rawDamage * modifier
end

local function CalculateMagicDamage(target, rawDamage)
    if not target then return 0 end
    local mr = target.magicResist or 0
    local magicPen = myHero.magicPen or 0
    local magicPenPercent = myHero.magicPenPercent or 0
    
    local effectiveMR = mr * (1 - magicPenPercent) - magicPen
    effectiveMR = math_max(0, effectiveMR)
    
    local modifier = 100 / (100 + effectiveMR)
    return rawDamage * modifier
end

local function CalculateQDamage(target, phase, sweetSpot)
    if not target then return 0 end
    
    phase = phase or GetQPhase()
    if phase == 0 then phase = 1 end
    
    local level = GetSpellLevel(_Q)
    if level == 0 then return 0 end
    
    local baseDmg = DamageData.Q.base[level]
    local adRatio = DamageData.Q.adRatio[phase][level]
    local castMult = DamageData.Q.castMultiplier[phase]
    
    local damage = (baseDmg + adRatio * GetTotalAD()) * castMult
    
    -- Sweet spot bonus
    if sweetSpot then
        damage = damage * DamageData.Q.sweetSpotBonus
    end
    
    -- R bonus AD
    if State.rActive then
        local rLevel = GetSpellLevel(_R)
        if rLevel > 0 then
            local bonusADPercent = DamageData.R.bonusAD[rLevel]
            damage = damage * (1 + bonusADPercent)
        end
    end
    
    return CalculatePhysicalDamage(target, damage)
end

local function CalculateWDamage(target, includeSecondHit)
    if not target then return 0 end
    
    local level = GetSpellLevel(_W)
    if level == 0 then return 0 end
    
    local baseDmg = DamageData.W.base[level]
    local damage = baseDmg + DamageData.W.adRatio * GetTotalAD()
    
    if includeSecondHit then
        damage = damage * DamageData.W.pullMultiplier
    end
    
    return CalculatePhysicalDamage(target, damage)
end

local function CalculatePassiveDamage(target)
    if not target then return 0 end
    
    local level = myHero.levelData.lvl
    -- Scales from 4% at level 1 to 8% at level 18
    local hpPercent = DamageData.Passive.hpPercent[1] + 
                      (DamageData.Passive.hpPercent[2] - DamageData.Passive.hpPercent[1]) * 
                      (level - 1) / 17
    
    local damage = target.maxHealth * hpPercent
    
    -- Cap vs monsters
    if target.type == Obj_AI_Minion and target.team == TEAM_JUNGLE then
        damage = math_min(damage, 100)
    end
    
    return CalculateMagicDamage(target, damage)
end

function CalculateFullComboDamage(target)
    if not target then return 0 end
    
    local damage = 0
    
    -- 3 Q hits with sweet spot
    if Ready(_Q) then
        damage = damage + CalculateQDamage(target, 1, true)
        damage = damage + CalculateQDamage(target, 2, true)
        damage = damage + CalculateQDamage(target, 3, true)
    end
    
    -- W with pull
    if Ready(_W) then
        damage = damage + CalculateWDamage(target, true)
    end
    
    -- Passive
    if State.passiveReady then
        damage = damage + CalculatePassiveDamage(target)
    end
    
    -- Auto attacks (estimate 3 during combo)
    damage = damage + CalculatePhysicalDamage(target, GetTotalAD() * 3)
    
    return damage
end

------------------------------------------------------------
-- PREDICTION SYSTEM
------------------------------------------------------------
local function GetPrediction(target, range, speed, delay, radius, collision)
    if not target or not IsValid(target) then return nil end
    if not _G.DepressivePrediction then return nil end
    
    local lib = _G.DepressivePrediction
    
    local ok, spell = pcall(function()
        return lib:SpellPrediction({
            Type = speed == math_huge and lib.SPELLTYPE_CIRCLE or lib.SPELLTYPE_LINE,
            Speed = speed,
            Range = range,
            Delay = delay,
            Radius = radius,
            Collision = collision,
            CollisionTypes = collision and {lib.COLLISION_MINION} or nil
        })
    end)
    
    if not ok or not spell then return nil end
    
    local predOk = pcall(function()
        spell:GetPrediction(target, myHero)
    end)
    
    if not predOk then return nil end
    
    return spell
end

local function GetQPrediction(target, phase)
    if not target or not IsValid(target) then return nil end
    
    phase = phase or GetQPhase()
    if phase == 0 then phase = 1 end
    
    local qData = GetQData(phase)
    
    return GetPrediction(
        target,
        qData.range,
        math_huge,
        qData.castTime,
        qData.width,
        false
    )
end

local function GetWPrediction(target)
    if not target or not IsValid(target) then return nil end
    
    return GetPrediction(
        target,
        SpellData.W.range,
        SpellData.W.speed,
        SpellData.W.castTime,
        SpellData.W.width,
        true
    )
end

------------------------------------------------------------
-- SWEET SPOT CALCULATION
------------------------------------------------------------
local function IsInSweetSpot(dist, phase)
    local qData = GetQData(phase)
    return dist >= qData.sweetMin and dist <= qData.sweetMax
end

local function GetSweetSpotCenter(phase)
    local qData = GetQData(phase)
    return (qData.sweetMin + qData.sweetMax) / 2
end

local function CalculateSweetSpotPosition(target, phase)
    if not target or not IsValid(target) then return nil end
    
    local qData = GetQData(phase)
    local sweetCenter = GetSweetSpotCenter(phase)
    local dist = Distance(myHero.pos, target.pos)
    
    -- Account for enemy movement
    local pattern = GetEnemyPattern(target)
    local predictedPos = target.pos
    
    if pattern and pattern.avgSpeed > 50 then
        -- Predict position after cast time
        predictedPos = {
            x = target.pos.x + pattern.movementDirection.x * pattern.avgSpeed * qData.castTime,
            y = target.pos.y,
            z = (target.pos.z or target.pos.y) + pattern.movementDirection.z * pattern.avgSpeed * qData.castTime
        }
    end
    
    local predDist = Distance(myHero.pos, predictedPos)
    
    -- Already in sweet spot
    if predDist >= qData.sweetMin and predDist <= qData.sweetMax then
        return predictedPos, true
    end
    
    -- Need to adjust aim
    if predDist < qData.sweetMin then
        -- Target too close, aim behind them
        local dir = GetDirection(myHero.pos, predictedPos)
        return {
            x = myHero.pos.x + dir.x * sweetCenter,
            y = myHero.pos.y,
            z = (myHero.pos.z or myHero.pos.y) + dir.z * sweetCenter
        }, false
    else
        -- Target too far, aim at max sweet spot range
        local dir = GetDirection(myHero.pos, predictedPos)
        return {
            x = myHero.pos.x + dir.x * qData.sweetMax,
            y = myHero.pos.y,
            z = (myHero.pos.z or myHero.pos.y) + dir.z * qData.sweetMax
        }, false
    end
end

------------------------------------------------------------
-- E-Q ANIMATION CANCEL SYSTEM
------------------------------------------------------------
local function CalculateEPositionForQ(target, phase)
    if not target or not IsValid(target) then return nil end
    if not Ready(_E) then return nil end
    
    local qData = GetQData(phase)
    local sweetCenter = GetSweetSpotCenter(phase)
    local dist = Distance(myHero.pos, target.pos)
    
    -- Calculate optimal E direction
    local dir = GetDirection(myHero.pos, target.pos)
    
    -- If target is too far, dash toward them
    if dist > qData.sweetMax + 50 then
        local dashDist = math_min(SpellData.E.range, dist - sweetCenter)
        return ExtendPosition(myHero.pos, target.pos, dashDist)
    end
    
    -- If target is too close, dash to maintain sweet spot
    if dist < qData.sweetMin - 50 then
        -- Dash sideways to maintain distance while repositioning
        local perpDir = {x = -dir.z, z = dir.x}
        return {
            x = myHero.pos.x + perpDir.x * SpellData.E.range * 0.7,
            y = myHero.pos.y,
            z = (myHero.pos.z or myHero.pos.y) + perpDir.z * SpellData.E.range * 0.7
        }
    end
    
    -- If in range but not sweet spot, adjust
    if not IsInSweetSpot(dist, phase) then
        local neededDist = sweetCenter - dist
        if neededDist > 0 then
            -- Move toward target
            return ExtendPosition(myHero.pos, target.pos, math_min(neededDist, SpellData.E.range))
        end
    end
    
    return nil
end

local function ShouldUseEDuringQ(target, phase)
    if not target or not Ready(_E) then return false end
    if not Menu.Combo.UseE:Value() then return false end
    
    local qData = GetQData(phase)
    local dist = Distance(myHero.pos, target.pos)
    
    -- Check phase-specific settings
    if phase == 1 and Menu.Combo.EDuringQ1 and not Menu.Combo.EDuringQ1:Value() then return false end
    if phase == 2 and Menu.Combo.EDuringQ2 and not Menu.Combo.EDuringQ2:Value() then return false end
    if phase == 3 and Menu.Combo.EDuringQ3 and not Menu.Combo.EDuringQ3:Value() then return false end
    
    -- Use E if target is out of range
    if dist > qData.range then
        return dist <= qData.range + SpellData.E.range
    end
    
    -- Use E to reach sweet spot
    if Menu.Combo.EForSweetSpot and Menu.Combo.EForSweetSpot:Value() then
        if not IsInSweetSpot(dist, phase) then
            local ePos = CalculateEPositionForQ(target, phase)
            if ePos then
                local newDist = Distance(ePos, target.pos)
                return IsInSweetSpot(newDist, phase)
            end
        end
    end
    
    return false
end

------------------------------------------------------------
-- W PULL COMBO SYSTEM
------------------------------------------------------------
local function IsTargetInW(target)
    if not target or not State.wTarget then return false end
    if target.networkID ~= State.wTarget.networkID then return false end
    
    local timeSinceW = os_clock() - State.wCastTime
    return timeSinceW > 0.5 and timeSinceW < SpellData.W.pullDelay
end

local function GetWPullTime(target)
    if not IsTargetInW(target) then return 0 end
    return State.wCastTime + SpellData.W.pullDelay - os_clock()
end

local function ShouldHoldQForWPull(target)
    if not target or not IsTargetInW(target) then return false end
    if not Menu.Combo.WPullCombo or not Menu.Combo.WPullCombo:Value() then return false end
    
    local pullTime = GetWPullTime(target)
    local phase = GetQPhase()
    local qData = GetQData(phase)
    
    -- Hold Q if pull is imminent and will result in sweet spot hit
    if pullTime > 0 and pullTime < 0.8 then
        local dist = Distance(myHero.pos, target.pos)
        -- Target will be pulled closer
        local pullDist = math_max(100, dist - 250) -- Estimate pull distance
        return IsInSweetSpot(pullDist, phase)
    end
    
    return false
end

------------------------------------------------------------
-- FLASH Q COMBO
------------------------------------------------------------
local function GetFlashSlot()
    local sum1 = myHero:GetSpellData(SUMMONER_1)
    local sum2 = myHero:GetSpellData(SUMMONER_2)
    
    if sum1 and sum1.name and sum1.name:lower():find("flash") then
        return SUMMONER_1, HK_SUMMONER_1
    end
    if sum2 and sum2.name and sum2.name:lower():find("flash") then
        return SUMMONER_2, HK_SUMMONER_2
    end
    
    return nil, nil
end

local function IsFlashReady()
    local slot, _ = GetFlashSlot()
    if not slot then return false end
    return Ready(slot)
end

local function CanFlashQ(target)
    if not target or not IsValid(target) then return false end
    if not Menu.Combo.FlashQ or not Menu.Combo.FlashQ:Value() then return false end
    if not IsFlashReady() then return false end
    if not Ready(_Q) then return false end
    
    local phase = GetQPhase()
    if phase ~= 3 then return false end -- Only flash Q3
    
    local dist = Distance(myHero.pos, target.pos)
    local flashRange = 400
    local qData = GetQData(3)
    
    -- Check if flash + Q3 can reach target sweet spot
    if dist > flashRange + qData.sweetMax then return false end
    if dist < qData.sweetMax then return false end -- Already in range
    
    -- Check if target HP is below threshold
    local hpPercent = (target.health / target.maxHealth) * 100
    local threshold = Menu.Combo.FlashQHP and Menu.Combo.FlashQHP:Value() or 40
    
    return hpPercent <= threshold
end

local function ExecuteFlashQ(target)
    if not CanFlashQ(target) then return false end
    
    local _, flashHK = GetFlashSlot()
    local qData = GetQData(3)
    local sweetCenter = GetSweetSpotCenter(3)
    
    -- Calculate flash position to land Q3 sweet spot
    local dist = Distance(myHero.pos, target.pos)
    local flashDist = dist - sweetCenter
    
    local flashPos = ExtendPosition(myHero.pos, target.pos, flashDist)
    
    -- Execute combo
    Control.CastSpell(flashHK, flashPos)
    DelayAction(function()
        if Ready(_Q) and IsValid(target) then
            Control.CastSpell(HK_Q, target.pos)
        end
    end, 0.05)
    
    return true
end

------------------------------------------------------------
-- TURRET DIVE CALCULATOR
------------------------------------------------------------
local function GetNearestEnemyTurret()
    local nearest = nil
    local minDist = math_huge
    
    for i = 1, GameTurretCount() do
        local turret = GameTurret(i)
        if turret and turret.team == TEAM_ENEMY and not turret.dead then
            local dist = Distance(myHero.pos, turret.pos)
            if dist < minDist then
                minDist = dist
                nearest = turret
            end
        end
    end
    
    return nearest, minDist
end

local function CalculateTurretDiveRisk(target)
    if not target then return 0 end
    
    local turret, turretDist = GetNearestEnemyTurret()
    if not turret or turretDist > 1200 then return 0 end
    
    local targetDist = Distance(turret.pos, target.pos)
    if targetDist > 900 then return 0 end -- Target not under turret
    
    local risk = 0
    
    -- HP risk
    local hpPercent = myHero.health / myHero.maxHealth
    risk = risk + (1 - hpPercent) * 40
    
    -- Time under turret
    local timeToKill = target.health / CalculateFullComboDamage(target)
    risk = risk + timeToKill * 20
    
    -- R availability
    if Ready(_R) or State.rActive then
        risk = risk - 20
    end
    
    -- Enemies nearby
    local nearbyEnemies = EnemiesInRange(1000, myHero.pos)
    risk = risk + (nearbyEnemies - 1) * 15
    
    return math_max(0, math_min(100, risk))
end

local function CanSafelyDive(target)
    if not Menu.Combo.TurretDive or not Menu.Combo.TurretDive:Value() then return false end
    
    local risk = CalculateTurretDiveRisk(target)
    local maxRisk = Menu.Combo.DiveRisk and Menu.Combo.DiveRisk:Value() or 50
    
    return risk <= maxRisk
end

------------------------------------------------------------
-- TEAM FIGHT MODE
------------------------------------------------------------
local function GetMultiTargetQPosition(phase)
    local qData = GetQData(phase)
    local enemies = GetEnemyHeroes()
    
    local bestPos = nil
    local bestCount = 0
    
    -- Sample positions around Aatrox
    for angle = 0, 350, 30 do
        local radAngle = angle * math_pi / 180
        local testPos = {
            x = myHero.pos.x + math_cos(radAngle) * qData.sweetMax * 0.9,
            y = myHero.pos.y,
            z = (myHero.pos.z or myHero.pos.y) + math_sin(radAngle) * qData.sweetMax * 0.9
        }
        
        local count = 0
        for _, enemy in ipairs(enemies) do
            local dist = Distance(testPos, enemy.pos)
            if dist <= qData.width / 2 then
                -- Bonus for sweet spot hits
                local myDist = Distance(myHero.pos, testPos)
                if IsInSweetSpot(myDist, phase) then
                    count = count + 1.5
                else
                    count = count + 1
                end
            end
        end
        
        if count > bestCount then
            bestCount = count
            bestPos = testPos
        end
    end
    
    return bestPos, bestCount
end

local function ShouldUseTeamfightMode()
    if not Menu.Combo.Teamfight or not Menu.Combo.Teamfight:Value() then return false end
    
    local nearbyEnemies = EnemiesInRange(800, myHero.pos)
    local minEnemies = Menu.Combo.TeamfightMin and Menu.Combo.TeamfightMin:Value() or 2
    
    return nearbyEnemies >= minEnemies
end

------------------------------------------------------------
-- AUTO R SYSTEM
------------------------------------------------------------
local function ShouldAutoR()
    if not Ready(_R) then return false end
    if State.rActive then return false end
    if not Menu.Combo.UseR or not Menu.Combo.UseR:Value() then return false end
    
    local hpPercent = (myHero.health / myHero.maxHealth) * 100
    local enemies = EnemiesInRange(SpellData.R.range, myHero.pos)
    
    -- Emergency heal
    if Menu.Combo.REmergency and Menu.Combo.REmergency:Value() then
        local emergencyHP = Menu.Combo.REmergencyHP and Menu.Combo.REmergencyHP:Value() or 25
        if hpPercent <= emergencyHP and enemies >= 1 then
            return true
        end
    end
    
    -- Standard usage
    local hpThreshold = Menu.Combo.RHp and Menu.Combo.RHp:Value() or 50
    local enemyThreshold = Menu.Combo.RCount and Menu.Combo.RCount:Value() or 2
    
    if hpPercent <= hpThreshold or enemies >= enemyThreshold then
        return true
    end
    
    return false
end

------------------------------------------------------------
-- CAST FUNCTIONS
------------------------------------------------------------
local function CastQ(target)
    if not Ready(_Q) or not target or not IsValid(target) then return false end
    
    local phase = GetQPhase()
    if phase == 0 then return false end
    
    local now = os_clock()
    
    -- Rate limiter
    if now - State.lastCastTime < 0.15 then return false end
    
    local qData = GetQData(phase)
    local dist = Distance(myHero.pos, target.pos)
    
    -- Check W pull combo
    if ShouldHoldQForWPull(target) then
        if Menu.Misc.Debug and Menu.Misc.Debug:Value() then
            print("[" .. SCRIPT_NAME .. "] Holding Q for W pull")
        end
        return false
    end
    
    -- Get cast mode
    local mode = 0
    if phase == 1 and Menu.Combo.Q1Mode then mode = Menu.Combo.Q1Mode:Value() end
    if phase == 2 and Menu.Combo.Q2Mode then mode = Menu.Combo.Q2Mode:Value() end
    if phase == 3 and Menu.Combo.Q3Mode then mode = Menu.Combo.Q3Mode:Value() end
    
    -- Calculate effective range with E
    local effectiveRange = qData.range
    local shouldUseE = ShouldUseEDuringQ(target, phase)
    
    if shouldUseE then
        effectiveRange = qData.range + SpellData.E.range
    end
    
    -- Range check
    if dist > effectiveRange then return false end
    
    -- Sweet spot logic
    local isSweet = IsInSweetSpot(dist, phase)
    
    -- Mode 2: Sweet Spot Only (dropdown: 1=Any, 2=Sweet, 3=Edge)
    if mode == 2 and not isSweet then
        if shouldUseE then
            local ePos = CalculateEPositionForQ(target, phase)
            if ePos then
                local newDist = Distance(ePos, target.pos)
                if not IsInSweetSpot(newDist, phase) then
                    return false
                end
            end
        else
            return false
        end
    end
    
    -- Get prediction
    local pred = GetQPrediction(target, phase)
    local castPos = nil
    
    if pred and pred.CastPosition then
        local hc = pred.HitChance or 0
        local needed = Menu.Pred.QHit and Menu.Pred.QHit:Value() or 1
        local reqMap = {2, 3, 4, 5, 6}
        
        if hc >= (reqMap[needed + 1] or 3) then
            castPos = pred.CastPosition
        end
    end
    
    -- Fallback to smart positioning
    if not castPos then
        local sweetPos, _ = CalculateSweetSpotPosition(target, phase)
        castPos = sweetPos or target.pos
    end
    
    -- Validate cast position
    if not castPos or not castPos.x then return false end
    
    -- Execute cast
    Control.CastSpell(HK_Q, castPos)
    State.lastQTime = now
    State.lastCastTime = now
    State.qPhase = phase
    
    -- Schedule E during Q if needed
    if shouldUseE then
        local ePos = CalculateEPositionForQ(target, phase)
        if ePos then
            DelayAction(function()
                if Ready(_E) and IsValid(target) then
                    -- Recalculate for fresh position
                    local freshDir = GetDirection(myHero.pos, target.pos)
                    local freshEPos = ExtendPosition(myHero.pos, target.pos, SpellData.E.range)
                    Control.CastSpell(HK_E, freshEPos)
                    State.lastETime = os_clock()
                end
            end, 0.1)
        end
    end
    
    if Menu.Misc.Debug and Menu.Misc.Debug:Value() then
        local sweetStr = isSweet and "[SWEET]" or ""
        print(string_format("[%s] Cast Q%d %s dist=%.0f", SCRIPT_NAME, phase, sweetStr, dist))
    end
    
    return true
end

local function CastW(target, force)
    if not Ready(_W) or not target or not IsValid(target) then return false end
    
    local dist = Distance(myHero.pos, target.pos)
    if dist > SpellData.W.range then return false end
    
    if not force and not Menu.Combo.UseW:Value() then return false end
    
    -- W after Q1 option
    if not force and Menu.Combo.WAfterQ and Menu.Combo.WAfterQ:Value() then
        local phase = GetQPhase()
        if phase == 1 then return false end
    end
    
    -- Get prediction
    local pred = GetWPrediction(target)
    
    -- Check collision
    if pred and pred.CollisionData then
        local collCount = pred.CollisionData.CollisionCount or 0
        if collCount > 0 then
            if Menu.Misc.Debug and Menu.Misc.Debug:Value() then
                print(string_format("[%s] W blocked by %d minions", SCRIPT_NAME, collCount))
            end
            return false
        end
    end
    
    local castPos = target.pos
    if pred and pred.CastPosition then
        local hc = pred.HitChance or 0
        local needed = Menu.Pred.WHit and Menu.Pred.WHit:Value() or 2
        local reqMap = {2, 3, 4, 5, 6}
        
        if hc >= (reqMap[needed + 1] or 3) then
            castPos = pred.CastPosition
        end
    end
    
    Control.CastSpell(HK_W, castPos)
    State.lastWTime = os_clock()
    State.wTarget = target
    State.wCastTime = os_clock()
    
    if Menu.Misc.Debug and Menu.Misc.Debug:Value() then
        print(string_format("[%s] Cast W dist=%.0f", SCRIPT_NAME, dist))
    end
    
    return true
end

local function CastR()
    if not Ready(_R) then return false end
    if State.rActive then return false end
    if not ShouldAutoR() then return false end
    
    Control.CastSpell(HK_R)
    State.lastRTime = os_clock()
    
    if Menu.Misc.Debug and Menu.Misc.Debug:Value() then
        local hp = (myHero.health / myHero.maxHealth) * 100
        local enemies = EnemiesInRange(SpellData.R.range, myHero.pos)
        print(string_format("[%s] Cast R HP=%.1f%% enemies=%d", SCRIPT_NAME, hp, enemies))
    end
    
    return true
end

------------------------------------------------------------
-- COMBO LOGIC
------------------------------------------------------------
local function Combo()
    local target = GetBestTarget(1200)
    if not target then return end
    
    State.comboTarget = target
    
    -- Update enemy pattern
    UpdateEnemyPattern(target)
    
    -- Turret dive check
    local turret, turretDist = GetNearestEnemyTurret()
    if turret and turretDist < 900 then
        if not CanSafelyDive(target) then
            if Menu.Misc.Debug and Menu.Misc.Debug:Value() then
                print("[" .. SCRIPT_NAME .. "] Dive too risky, backing off")
            end
            return
        end
    end
    
    -- R usage
    CastR()
    
    -- Flash Q3 combo
    if CanFlashQ(target) then
        if ExecuteFlashQ(target) then
            return
        end
    end
    
    -- Teamfight mode
    if ShouldUseTeamfightMode() then
        local phase = GetQPhase()
        if phase > 0 and Ready(_Q) then
            local multiPos, count = GetMultiTargetQPosition(phase)
            if multiPos and count >= 2 then
                Control.CastSpell(HK_Q, multiPos)
                State.lastQTime = os_clock()
                State.lastCastTime = os_clock()
                return
            end
        end
    end
    
    -- Standard combo
    if Ready(_Q) then
        CastQ(target)
    end
    
    if Ready(_W) then
        CastW(target)
    end
end

local function Harass()
    local target = GetBestTarget(SpellData.Q[1].range)
    if not target then return end
    
    if not Menu.Harass.UseQ:Value() then return end
    
    local phase = GetQPhase()
    if phase == 1 then -- Only Q1 for harass
        CastQ(target)
    end
    
    if Menu.Harass.UseW and Menu.Harass.UseW:Value() then
        CastW(target)
    end
end

local function LaneClear()
    if not Menu.Clear.UseQ:Value() then return end
    
    local minions = GetMinionsInRange(SpellData.Q[1].range, myHero.pos, TEAM_ENEMY)
    if #minions < (Menu.Clear.MinMinions and Menu.Clear.MinMinions:Value() or 2) then return end
    
    -- Find best position
    local bestPos = nil
    local bestCount = 0
    
    for _, minion in ipairs(minions) do
        local count = 0
        for _, other in ipairs(minions) do
            if Distance(minion.pos, other.pos) <= 200 then
                count = count + 1
            end
        end
        if count > bestCount then
            bestCount = count
            bestPos = minion.pos
        end
    end
    
    if bestPos and Ready(_Q) then
        Control.CastSpell(HK_Q, bestPos)
        State.lastQTime = os_clock()
    end
end

local function JungleClear()
    local minions = GetMinionsInRange(SpellData.Q[1].range, myHero.pos, TEAM_JUNGLE)
    if #minions == 0 then return end
    
    local target = minions[1]
    
    if Menu.Jungle.UseQ and Menu.Jungle.UseQ:Value() and Ready(_Q) then
        Control.CastSpell(HK_Q, target.pos)
        State.lastQTime = os_clock()
    end
    
    if Menu.Jungle.UseW and Menu.Jungle.UseW:Value() and Ready(_W) then
        Control.CastSpell(HK_W, target.pos)
        State.lastWTime = os_clock()
    end
end

local function KillSteal()
    if not Menu.KS.Enabled or not Menu.KS.Enabled:Value() then return end
    
    for _, enemy in ipairs(GetEnemyHeroes()) do
        local dist = Distance(myHero.pos, enemy.pos)
        
        -- Q killsteal
        if Menu.KS.UseQ and Menu.KS.UseQ:Value() and Ready(_Q) then
            local phase = GetQPhase()
            local qData = GetQData(phase)
            if dist <= qData.range then
                local qDmg = CalculateQDamage(enemy, phase, IsInSweetSpot(dist, phase))
                if qDmg >= enemy.health then
                    CastQ(enemy)
                    return
                end
            end
        end
        
        -- W killsteal
        if Menu.KS.UseW and Menu.KS.UseW:Value() and Ready(_W) then
            if dist <= SpellData.W.range then
                local wDmg = CalculateWDamage(enemy, false)
                if wDmg >= enemy.health then
                    CastW(enemy, true)
                    return
                end
            end
        end
    end
end

------------------------------------------------------------
-- MENU
------------------------------------------------------------
local function LoadMenu()
    Menu = MenuElement({type = MENU, id = "DepressiveAatroxUltimate", name = "Depressive Aatrox Ultimate v" .. VERSION})
    
    -- Combo
    Menu:MenuElement({type = MENU, id = "Combo", name = "[Combo]"})
    Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
    Menu.Combo:MenuElement({id = "Q1Mode", name = "Q1 Mode", value = 1, drop = {"Any Range", "Sweet Spot Only", "Edge Priority"}})
    Menu.Combo:MenuElement({id = "Q2Mode", name = "Q2 Mode", value = 3, drop = {"Any Range", "Sweet Spot Only", "Edge Priority"}})
    Menu.Combo:MenuElement({id = "Q3Mode", name = "Q3 Mode", value = 2, drop = {"Any Range", "Sweet Spot Only", "Edge Priority"}})
    
    Menu.Combo:MenuElement({id = "UseW", name = "Use W", value = true})
    Menu.Combo:MenuElement({id = "WAfterQ", name = "W only after Q1", value = true})
    Menu.Combo:MenuElement({id = "WPullCombo", name = "Hold Q for W pull", value = true})
    
    Menu.Combo:MenuElement({id = "UseE", name = "Use E during Q", value = true})
    Menu.Combo:MenuElement({id = "EDuringQ1", name = "E during Q1", value = true})
    Menu.Combo:MenuElement({id = "EDuringQ2", name = "E during Q2", value = true})
    Menu.Combo:MenuElement({id = "EDuringQ3", name = "E during Q3", value = true})
    Menu.Combo:MenuElement({id = "EForSweetSpot", name = "E to reach sweet spot", value = true})
    
    Menu.Combo:MenuElement({id = "UseR", name = "Use R", value = true})
    Menu.Combo:MenuElement({id = "RHp", name = "R if HP% <", value = 50, min = 0, max = 100, identifier = "%"})
    Menu.Combo:MenuElement({id = "RCount", name = "R if enemies >=", value = 2, min = 1, max = 5})
    Menu.Combo:MenuElement({id = "REmergency", name = "Emergency R (low HP)", value = true})
    Menu.Combo:MenuElement({id = "REmergencyHP", name = "Emergency HP%", value = 25, min = 5, max = 50, identifier = "%"})
    
    Menu.Combo:MenuElement({id = "FlashQ", name = "Flash Q3 Combo", value = true})
    Menu.Combo:MenuElement({id = "FlashQHP", name = "Flash Q if target HP% <", value = 40, min = 10, max = 80, identifier = "%"})
    Menu.Combo:MenuElement({id = "Teamfight", name = "Teamfight Mode", value = true})
    Menu.Combo:MenuElement({id = "TeamfightMin", name = "Min enemies for teamfight", value = 2, min = 2, max = 5})
    Menu.Combo:MenuElement({id = "TurretDive", name = "Allow turret dive", value = false})
    Menu.Combo:MenuElement({id = "DiveRisk", name = "Max dive risk %", value = 40, min = 0, max = 100, identifier = "%"})
    
    -- Harass
    Menu:MenuElement({type = MENU, id = "Harass", name = "[Harass]"})
    Menu.Harass:MenuElement({id = "UseQ", name = "Use Q1", value = true})
    Menu.Harass:MenuElement({id = "UseW", name = "Use W", value = false})
    
    -- Clear
    Menu:MenuElement({type = MENU, id = "Clear", name = "[Lane Clear]"})
    Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
    Menu.Clear:MenuElement({id = "MinMinions", name = "Min minions", value = 3, min = 1, max = 6})
    
    -- Jungle
    Menu:MenuElement({type = MENU, id = "Jungle", name = "[Jungle Clear]"})
    Menu.Jungle:MenuElement({id = "UseQ", name = "Use Q", value = true})
    Menu.Jungle:MenuElement({id = "UseW", name = "Use W", value = true})
    Menu.Jungle:MenuElement({id = "UseE", name = "Use E", value = true})
    
    -- Killsteal
    Menu:MenuElement({type = MENU, id = "KS", name = "[Killsteal]"})
    Menu.KS:MenuElement({id = "Enabled", name = "Enable Killsteal", value = true})
    Menu.KS:MenuElement({id = "UseQ", name = "Use Q", value = true})
    Menu.KS:MenuElement({id = "UseW", name = "Use W", value = true})
    
    -- Prediction
    Menu:MenuElement({type = MENU, id = "Pred", name = "[Prediction]"})
    Menu.Pred:MenuElement({id = "QHit", name = "Q Hitchance", value = 1, drop = {"Low", "Normal", "High", "Very High", "Immobile"}})
    Menu.Pred:MenuElement({id = "WHit", name = "W Hitchance", value = 2, drop = {"Low", "Normal", "High", "Very High", "Immobile"}})
    
    -- Draw
    Menu:MenuElement({type = MENU, id = "Draw", name = "[Drawings]"})
    Menu.Draw:MenuElement({id = "Enabled", name = "Enable Drawings", value = true})
    Menu.Draw:MenuElement({id = "QRange", name = "Q Range", value = true})
    Menu.Draw:MenuElement({id = "SweetSpot", name = "Sweet Spot Zone", value = true})
    Menu.Draw:MenuElement({id = "WRange", name = "W Range", value = false})
    Menu.Draw:MenuElement({id = "ERange", name = "E Range", value = false})
    Menu.Draw:MenuElement({id = "ComboDamage", name = "Combo Damage", value = true})
    Menu.Draw:MenuElement({id = "PassiveReady", name = "Passive Ready", value = true})
    Menu.Draw:MenuElement({id = "RTimer", name = "R Duration", value = true})
    Menu.Draw:MenuElement({id = "DiveRisk", name = "Dive Risk", value = true})
    
    -- Misc
    Menu:MenuElement({type = MENU, id = "Misc", name = "[Misc]"})
    Menu.Misc:MenuElement({id = "Debug", name = "Debug Mode", value = false})
end

------------------------------------------------------------
-- DRAWING
------------------------------------------------------------
local function OnDraw()
    if not Menu or myHero.dead then return end
    if not Menu.Draw.Enabled:Value() then return end
    
    local phase = GetQPhase()
    local qData = GetQData(phase > 0 and phase or 1)
    
    -- Q Range
    if Menu.Draw.QRange:Value() and Ready(_Q) then
        Draw.Circle(myHero.pos, qData.range, 1, Draw.Color(100, 100, 200, 255))
    end
    
    -- Sweet Spot
    if Menu.Draw.SweetSpot:Value() and Ready(_Q) and phase > 0 then
        Draw.Circle(myHero.pos, qData.sweetMin, 1, Draw.Color(100, 255, 100, 100))
        Draw.Circle(myHero.pos, qData.sweetMax, 1, Draw.Color(100, 255, 150, 100))
    end
    
    -- W Range
    if Menu.Draw.WRange:Value() and Ready(_W) then
        Draw.Circle(myHero.pos, SpellData.W.range, 1, Draw.Color(80, 150, 150, 255))
    end
    
    -- E Range
    if Menu.Draw.ERange:Value() and Ready(_E) then
        Draw.Circle(myHero.pos, SpellData.E.range, 1, Draw.Color(80, 200, 150, 255))
    end
    
    -- Combo Damage on enemies
    if Menu.Draw.ComboDamage:Value() then
        for _, enemy in ipairs(GetEnemyHeroes()) do
            local pos2D = enemy.pos:To2D()
            if pos2D and pos2D.onScreen then
                local comboDmg = CalculateFullComboDamage(enemy)
                local killable = comboDmg >= enemy.health
                local color = killable and Draw.Color(255, 255, 50, 50) or Draw.Color(255, 255, 255, 255)
                local text = killable and "KILL" or string_format("%.0f", comboDmg)
                Draw.Text(text, 16, pos2D.x - 20, pos2D.y - 30, color)
            end
        end
    end
    
    -- Passive Ready indicator
    if Menu.Draw.PassiveReady:Value() then
        local pos2D = myHero.pos:To2D()
        if pos2D and pos2D.onScreen then
            if State.passiveReady then
                Draw.Text("PASSIVE READY", 14, pos2D.x - 45, pos2D.y + 40, Draw.Color(255, 255, 200, 50))
            end
        end
    end
    
    -- R Timer
    if Menu.Draw.RTimer:Value() and State.rActive then
        local remaining = GetRRemainingTime()
        local pos2D = myHero.pos:To2D()
        if pos2D and pos2D.onScreen then
            Draw.Text(string_format("R: %.1fs", remaining), 18, pos2D.x - 25, pos2D.y - 50, Draw.Color(255, 255, 50, 50))
        end
    end
    
    -- Dive Risk
    if Menu.Draw.DiveRisk:Value() then
        local target = State.comboTarget or GetBestTarget(1200)
        if target then
            local risk = CalculateTurretDiveRisk(target)
            if risk > 0 then
                local pos2D = myHero.pos:To2D()
                if pos2D and pos2D.onScreen then
                    local color = risk > 60 and Draw.Color(255, 255, 50, 50) or 
                                  risk > 30 and Draw.Color(255, 255, 200, 50) or 
                                  Draw.Color(255, 50, 255, 50)
                    Draw.Text(string_format("Dive Risk: %d%%", risk), 14, pos2D.x - 40, pos2D.y + 55, color)
                end
            end
        end
    end
end

------------------------------------------------------------
-- TICK
------------------------------------------------------------
local function OnTick()
    if not Menu or MyHeroNotReady() then return end
    
    -- Process delayed actions
    ProcessDelayedActions()
    
    -- Update state
    UpdatePassiveState()
    UpdateRState()
    
    -- Update enemy patterns
    for _, enemy in ipairs(GetEnemyHeroes()) do
        UpdateEnemyPattern(enemy)
    end
    
    -- Execute mode logic
    local mode = GetOrbwalkerMode()
    
    if mode == "Combo" then
        Combo()
    elseif mode == "Harass" then
        Harass()
    elseif mode == "Clear" then
        LaneClear()
        JungleClear()
    elseif mode == "Jungle" then
        JungleClear()
    end
    
    -- Always check killsteal
    KillSteal()
end

------------------------------------------------------------
-- LOAD
------------------------------------------------------------
LoadMenu()
Callback.Add("Tick", OnTick)
Callback.Add("Draw", OnDraw)

print("[" .. SCRIPT_NAME .. "] Version " .. VERSION .. " loaded successfully!")
print("[" .. SCRIPT_NAME .. "] Advanced mechanics enabled:")