if _G.__DEPRESSIVE_VAYNE_LOADED then return end
_G.__DEPRESSIVE_VAYNE_LOADED = true
local VERSION = "4.0"
if myHero.charName ~= "Vayne" then return end

-- ═══════════════════════════════════════════════════════════════════════════
-- DEPENDENCIES
-- ═══════════════════════════════════════════════════════════════════════════
require("DepressivePrediction")

local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
    end
end, 1.0)

-- Try to load MapPositionGOS if available
local MapPositionLoaded = false
pcall(function()
    require("MapPositionGOS")
    MapPositionLoaded = true
end)

-- Mark as loaded for DepressiveAIONext
_G.DepressiveAIONextLoadedChampion = true

-- ═══════════════════════════════════════════════════════════════════════════
-- LOCALIZED FUNCTIONS (Performance Optimization)
-- ═══════════════════════════════════════════════════════════════════════════
local math_sqrt = math.sqrt
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_huge = math.huge
local math_floor = math.floor
local math_ceil = math.ceil
local math_cos = math.cos
local math_sin = math.sin
local math_rad = math.rad
local math_atan2 = math.atan2
local math_pi = math.pi
local math_random = math.random

local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort

local pairs = pairs
local ipairs = ipairs
local type = type
local pcall = pcall
local tonumber = tonumber
local tostring = tostring

local Game = Game
local Control = Control
local Draw = Draw
local Vector = Vector
local myHero = myHero

local GameTimer = Game.Timer
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameIsChatOpen = Game.IsChatOpen
local GameCanUseSpell = Game.CanUseSpell

-- ═══════════════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════════
local TEAM_ENEMY = (myHero.team == 100 and 200) or 100
local TEAM_ALLY = myHero.team

-- Spell slots
local _Q = 0
local _W = 1
local _E = 2
local _R = 3

-- Vayne spell data
local VAYNE = {
    Q = {
        Range = 300,
        Cooldown = 0.25,
    },
    W = {
        StackDuration = 3.5,
        ProcDamage = {0.04, 0.06, 0.08, 0.10, 0.12}, -- % max HP true damage
        MinDamage = {50, 65, 80, 95, 110},
    },
    E = {
        Range = 550,
        KnockbackDistance = 475,
        KnockbackDuration = 0.5,
        StunDuration = {1.5, 1.5, 1.5, 1.5, 1.5},
        BaseDamage = {50, 85, 120, 155, 190},
        BonusADRatio = 0.5,
        Speed = 2200,
        Width = 50,
    },
    R = {
        Duration = {8, 10, 12},
        BonusAD = {25, 40, 55},
        QInvisibility = 1.0,
    },
    AttackRange = 550,
    BoundingRadius = 65,
}

-- Cache settings
local CACHE_DURATION = 0.05
local WALL_CACHE_DURATION = 0.1
local POSITION_CACHE_DURATION = 0.033 -- ~30 FPS

-- Interruptable spells
local InterruptableSpells = {
    ["CaitlynAceintheHole"] = true, ["Crowstorm"] = true, ["DrainChannel"] = true,
    ["GalioIdolOfDurand"] = true, ["ReapTheWhirlwind"] = true, ["KarthusFallenOne"] = true,
    ["KatarinaR"] = true, ["LucianR"] = true, ["AlZaharNetherGrasp"] = true,
    ["Meditate"] = true, ["MissFortuneBulletTime"] = true, ["AbsoluteZero"] = true,
    ["PantheonRJump"] = true, ["PantheonRFall"] = true, ["ShenStandUnited"] = true,
    ["Destiny"] = true, ["VelkozR"] = true, ["InfiniteDuress"] = true,
    ["XerathLocusOfPower2"] = true, ["JhinR"] = true, ["FiddlesticksR"] = true,
    ["MalzaharR"] = true, ["NunuR"] = true,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- MENU SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
local Menu = MenuElement({type = MENU, id = "DepressiveVayne", name = "Depressive Vayne v4.0"})
Menu:MenuElement({name = "Advanced Wall Detection & Smart Q", drop = {"by Depressive"}})

-- Combo Settings
Menu:MenuElement({type = MENU, id = "Combo", name = "[Combo] Settings"})
Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
Menu.Combo:MenuElement({id = "QMode", name = "Q Mode", value = 1, drop = {"Smart AI", "To Mouse", "Kite Only"}})
Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
Menu.Combo:MenuElement({id = "EOnlyStun", name = "E Only for Wall Stun", value = true})
Menu.Combo:MenuElement({id = "UseR", name = "Use R", value = true})
Menu.Combo:MenuElement({id = "REnemies", name = "R Min Enemies", value = 2, min = 1, max = 5})
Menu.Combo:MenuElement({id = "RRange", name = "R Detection Range", value = 800, min = 500, max = 1200, step = 50})

-- E Settings (Advanced)
Menu:MenuElement({type = MENU, id = "ESettings", name = "[E] Advanced Settings"})
Menu.ESettings:MenuElement({id = "WallStunEnabled", name = "Enable Wall Stun Logic", value = true})
Menu.ESettings:MenuElement({id = "KnockbackDist", name = "Knockback Distance", value = 475, min = 400, max = 475, step = 5})
Menu.ESettings:MenuElement({id = "ExtraWallCheck", name = "Extra Wall Check Distance", value = 50, min = 0, max = 100, step = 5})
Menu.ESettings:MenuElement({id = "WallCheckPrecision", name = "Wall Check Precision", value = 3, drop = {"Low (Fast)", "Medium", "High (Precise)", "Ultra (Slow)"}})
Menu.ESettings:MenuElement({id = "AngleScan", name = "Angle Scan Range", value = 15, min = 5, max = 30, step = 1})
Menu.ESettings:MenuElement({id = "SelfPeel", name = "E Self Peel", value = true})
Menu.ESettings:MenuElement({id = "PeelRange", name = "Self Peel Range", value = 200, min = 100, max = 350, step = 10})
Menu.ESettings:MenuElement({id = "PeelHP", name = "Self Peel HP %", value = 50, min = 10, max = 100, step = 5})
Menu.ESettings:MenuElement({id = "Killsteal", name = "E Killsteal", value = true})
Menu.ESettings:MenuElement({id = "Interrupt", name = "E Interrupt Spells", value = true})

-- Q Settings
Menu:MenuElement({type = MENU, id = "QSettings", name = "[Q] Advanced Settings"})
Menu.QSettings:MenuElement({id = "QRange", name = "Q Tumble Distance", value = 300, min = 250, max = 350, step = 10})
Menu.QSettings:MenuElement({id = "SafeDistance", name = "Safe Distance from Enemy", value = 400, min = 250, max = 550, step = 10})
Menu.QSettings:MenuElement({id = "MinDistance", name = "Min Distance (Anti-Melee)", value = 300, min = 150, max = 400, step = 10})
Menu.QSettings:MenuElement({id = "ChaseHP", name = "Chase Low HP Target %", value = 30, min = 10, max = 60, step = 5})
Menu.QSettings:MenuElement({id = "ChaseRange", name = "Max Chase Range", value = 700, min = 500, max = 900, step = 25})
Menu.QSettings:MenuElement({id = "AvoidWalls", name = "Avoid Q into Walls", value = true})
Menu.QSettings:MenuElement({id = "CheckEnemies", name = "Check Nearby Enemies", value = true})
Menu.QSettings:MenuElement({id = "PostAttack", name = "Q After Auto Attack", value = true})

-- Harass Settings
Menu:MenuElement({type = MENU, id = "Harass", name = "[Harass] Settings"})
Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
Menu.Harass:MenuElement({id = "QWith2W", name = "Q Only with 2 W Stacks", value = true})
Menu.Harass:MenuElement({id = "UseE", name = "Use E for Wall Stun", value = true})
Menu.Harass:MenuElement({id = "MinMana", name = "Min Mana %", value = 40, min = 10, max = 80, step = 5})

-- Lane Clear Settings
Menu:MenuElement({type = MENU, id = "LaneClear", name = "[Lane Clear] Settings"})
Menu.LaneClear:MenuElement({id = "UseQ", name = "Use Q", value = true})
Menu.LaneClear:MenuElement({id = "QWith2W", name = "Q Only with 2 W Stacks", value = false})
Menu.LaneClear:MenuElement({id = "MinMana", name = "Min Mana %", value = 50, min = 10, max = 80, step = 5})

-- Jungle Clear Settings
Menu:MenuElement({type = MENU, id = "JungleClear", name = "[Jungle Clear] Settings"})
Menu.JungleClear:MenuElement({id = "UseQ", name = "Use Q", value = true})
Menu.JungleClear:MenuElement({id = "UseE", name = "Use E on Large Monsters", value = false})
Menu.JungleClear:MenuElement({id = "MinMana", name = "Min Mana %", value = 30, min = 10, max = 80, step = 5})

-- Flee Settings
Menu:MenuElement({type = MENU, id = "Flee", name = "[Flee] Settings"})
Menu.Flee:MenuElement({id = "UseQ", name = "Use Q", value = true})
Menu.Flee:MenuElement({id = "UseE", name = "Use E", value = true})
Menu.Flee:MenuElement({id = "EWallStun", name = "E Only for Wall Stun", value = false})

-- Drawing Settings
Menu:MenuElement({type = MENU, id = "Draw", name = "[Draw] Settings"})
Menu.Draw:MenuElement({id = "Enabled", name = "Enable Drawings", value = true})
Menu.Draw:MenuElement({id = "QRange", name = "Draw Q Range", value = false})
Menu.Draw:MenuElement({id = "ERange", name = "Draw E Range", value = true})
Menu.Draw:MenuElement({id = "WallStun", name = "Draw Wall Stun Points", value = true})
Menu.Draw:MenuElement({id = "WStacks", name = "Draw W Stacks", value = true})
Menu.Draw:MenuElement({id = "Target", name = "Draw Current Target", value = true})
Menu.Draw:MenuElement({id = "QPosition", name = "Draw Q Position", value = true})
Menu.Draw:MenuElement({type = MENU, id = "Colors", name = "Colors"})
Menu.Draw.Colors:MenuElement({id = "Main", name = "Main Color", color = Draw.Color(255, 255, 100, 200)})
Menu.Draw.Colors:MenuElement({id = "WallStun", name = "Wall Stun Color", color = Draw.Color(255, 255, 200, 50)})
Menu.Draw.Colors:MenuElement({id = "Target", name = "Target Color", color = Draw.Color(255, 255, 50, 50)})

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Optimized distance calculations
local function GetDistanceSqr(p1, p2)
    if not p1 or not p2 then return math_huge end
    local pos1 = p1.pos or p1
    local pos2 = p2.pos or p2
    local dx = pos1.x - pos2.x
    local dz = pos1.z - pos2.z
    return dx * dx + dz * dz
end

local function GetDistance(p1, p2)
    return math_sqrt(GetDistanceSqr(p1, p2))
end

local function IsInRange(p1, p2, range)
    return GetDistanceSqr(p1, p2) <= range * range
end

-- Vector utilities
local function Normalize(v)
    local len = math_sqrt(v.x * v.x + v.z * v.z)
    if len > 0 then
        return {x = v.x / len, z = v.z / len}
    end
    return {x = 0, z = 0}
end

local function GetDirection(from, to)
    local pos1 = from.pos or from
    local pos2 = to.pos or to
    return Normalize({x = pos2.x - pos1.x, z = pos2.z - pos1.z})
end

local function RotateVector(v, angle)
    local cos_a = math_cos(angle)
    local sin_a = math_sin(angle)
    return {
        x = v.x * cos_a - v.z * sin_a,
        z = v.x * sin_a + v.z * cos_a
    }
end

local function ExtendPosition(from, direction, distance)
    local pos = from.pos or from
    return {
        x = pos.x + direction.x * distance,
        y = pos.y or myHero.pos.y,
        z = pos.z + direction.z * distance
    }
end

-- Target validation
local function IsValidTarget(target, range)
    if not target then return false end
    if not target.valid then return false end
    if target.dead then return false end
    if not target.visible then return false end
    if not target.isTargetable then return false end
    if target.team == TEAM_ALLY then return false end
    if range and not IsInRange(myHero.pos, target.pos, range) then return false end
    return true
end

-- Spell ready check
local function Ready(slot)
    local data = myHero:GetSpellData(slot)
    if not data then return false end
    return data.currentCd == 0 and GameCanUseSpell(slot) == 0 and data.level > 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CACHE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
local Cache = {
    enemies = {data = {}, time = 0, range = 0},
    wallStun = {},
    lastUpdate = 0,
}

local function GetEnemies(range)
    local now = GameTimer()
    if now - Cache.enemies.time < CACHE_DURATION and Cache.enemies.range == range then
        return Cache.enemies.data
    end
    
    local enemies = {}
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if IsValidTarget(hero, range) then
            enemies[#enemies + 1] = hero
        end
    end
    
    Cache.enemies = {data = enemies, time = now, range = range}
    return enemies
end

local function GetClosestEnemy(range)
    local enemies = GetEnemies(range)
    local closest = nil
    local closestDist = math_huge
    
    for _, enemy in ipairs(enemies) do
        local dist = GetDistanceSqr(myHero.pos, enemy.pos)
        if dist < closestDist then
            closestDist = dist
            closest = enemy
        end
    end
    
    return closest
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ORBWALKER MODE DETECTION
-- ═══════════════════════════════════════════════════════════════════════════
local ModeCache = {value = "None", time = 0}

local function GetMode()
    local now = GameTimer()
    if now - ModeCache.time < 0.05 then
        return ModeCache.value
    end
    
    local mode = "None"
    
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then
        local M = _G.SDK.Orbwalker.Modes
        if M[_G.SDK.ORBWALKER_MODE_COMBO] then mode = "Combo"
        elseif M[_G.SDK.ORBWALKER_MODE_HARASS] then mode = "Harass"
        elseif M[_G.SDK.ORBWALKER_MODE_LANECLEAR] then mode = "LaneClear"
        elseif M[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then mode = "JungleClear"
        elseif M[_G.SDK.ORBWALKER_MODE_FLEE] then mode = "Flee"
        end
    end
    
    ModeCache.value = mode
    ModeCache.time = now
    return mode
end

-- ═══════════════════════════════════════════════════════════════════════════
-- WALL DETECTION SYSTEM (Advanced)
-- ═══════════════════════════════════════════════════════════════════════════
local WallChecker = {
    cache = {},
    lastClean = 0,
}

-- Check if a position is a wall using MapPositionGOS
function WallChecker:IsWall(pos)
    if MapPositionLoaded and MapPosition and MapPosition.inWall then
        return MapPosition:inWall(pos)
    end
    return false
end

-- Check if there's a wall between two points
function WallChecker:HasWallBetween(startPos, endPos)
    if MapPositionLoaded and MapPosition and MapPosition.intersectsWall then
        return MapPosition:intersectsWall(startPos, endPos)
    end
    
    -- Fallback: sample multiple points
    local dir = GetDirection(startPos, endPos)
    local dist = GetDistance(startPos, endPos)
    local steps = math_max(5, math_floor(dist / 50))
    
    for i = 1, steps do
        local ratio = i / steps
        local checkPos = {
            x = startPos.x + dir.x * dist * ratio,
            y = startPos.y or myHero.pos.y,
            z = startPos.z + dir.z * dist * ratio
        }
        if self:IsWall(checkPos) then
            return true
        end
    end
    
    return false
end

-- Get the exact wall intersection point
function WallChecker:GetWallIntersection(startPos, endPos)
    if MapPositionLoaded and MapPosition and MapPosition.getIntersectionPoint3D then
        return MapPosition:getIntersectionPoint3D(startPos, endPos)
    end
    
    -- Fallback: binary search for wall
    local dir = GetDirection(startPos, endPos)
    local dist = GetDistance(startPos, endPos)
    
    local low, high = 0, dist
    local wallPoint = nil
    
    for i = 1, 10 do -- Binary search iterations
        local mid = (low + high) / 2
        local checkPos = ExtendPosition(startPos, dir, mid)
        
        if self:IsWall(checkPos) then
            wallPoint = checkPos
            high = mid
        else
            low = mid
        end
    end
    
    return wallPoint
end

-- Advanced wall stun detection with multiple rays
function WallChecker:GetWallStunPosition(target, knockbackDist, extraCheck, precision, angleScan)
    if not IsValidTarget(target, VAYNE.E.Range) then return nil end
    
    local now = GameTimer()
    local targetID = target.networkID
    
    -- Check cache
    if self.cache[targetID] and now - self.cache[targetID].time < WALL_CACHE_DURATION then
        return self.cache[targetID].pos, self.cache[targetID].distance
    end
    
    local heroPos = myHero.pos
    local targetPos = target.pos
    
    -- Calculate knockback direction (from Vayne towards enemy)
    local knockbackDir = GetDirection(heroPos, targetPos)
    
    -- Precision settings: number of angle steps
    local precisionSteps = ({4, 8, 16, 32})[precision] or 8
    local angleRange = math_rad(angleScan)
    local angleStep = (angleRange * 2) / precisionSteps
    
    local bestWallPos = nil
    local bestWallDist = math_huge
    local totalKnockback = knockbackDist + extraCheck
    
    -- Check multiple angles around the main knockback direction
    for a = -precisionSteps, precisionSteps do
        local angle = a * angleStep / 2
        local rotatedDir = RotateVector(knockbackDir, angle)
        
        -- Calculate end position after knockback
        local knockbackEnd = ExtendPosition(targetPos, rotatedDir, totalKnockback)
        
        -- Check if there's a wall in the knockback path
        if self:HasWallBetween(targetPos, knockbackEnd) then
            local wallPos = self:GetWallIntersection(targetPos, knockbackEnd)
            
            if wallPos then
                local distToWall = GetDistance(targetPos, wallPos)
                
                -- Wall must be within knockback range
                if distToWall <= knockbackDist and distToWall > 50 then
                    -- For the center ray, this is the actual stun
                    if a == 0 then
                        self.cache[targetID] = {pos = wallPos, distance = distToWall, time = now}
                        return wallPos, distToWall
                    end
                    
                    -- Track closest wall for edge cases
                    if distToWall < bestWallDist then
                        bestWallDist = distToWall
                        bestWallPos = wallPos
                    end
                end
            end
        end
    end
    
    -- If we found a wall on a non-center ray, use it
    if bestWallPos and bestWallDist <= knockbackDist then
        self.cache[targetID] = {pos = bestWallPos, distance = bestWallDist, time = now}
        return bestWallPos, bestWallDist
    end
    
    -- No wall found
    self.cache[targetID] = {pos = nil, distance = 0, time = now}
    return nil, 0
end

-- Check if Q position is safe (not into wall)
function WallChecker:IsSafePosition(pos)
    if not Menu.QSettings.AvoidWalls:Value() then return true end
    return not self:IsWall(pos)
end

-- Clean cache periodically
function WallChecker:CleanCache()
    local now = GameTimer()
    if now - self.lastClean < 1 then return end
    self.lastClean = now
    
    for id, data in pairs(self.cache) do
        if now - data.time > 2 then
            self.cache[id] = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- W STACK TRACKING
-- ═══════════════════════════════════════════════════════════════════════════
local WStacks = {
    data = {},
    lastCheck = 0,
}

function WStacks:Update()
    local now = GameTimer()
    if now - self.lastCheck < 0.1 then return end
    self.lastCheck = now
    
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero and hero.valid and hero.team == TEAM_ENEMY and not hero.dead then
            local found = false
            for j = 0, hero.buffCount do
                local buff = hero:GetBuff(j)
                if buff and buff.count > 0 and buff.name == "vaynesilvereddebuff" then
                    self.data[hero.networkID] = {
                        count = buff.count,
                        time = now
                    }
                    found = true
                    break
                end
            end
            if not found then
                self.data[hero.networkID] = nil
            end
        end
    end
end

function WStacks:Get(target)
    if not target then return 0 end
    local data = self.data[target.networkID]
    if not data then return 0 end
    if GameTimer() - data.time > VAYNE.W.StackDuration then
        self.data[target.networkID] = nil
        return 0
    end
    return data.count
end

function WStacks:HasTwo(target)
    return self:Get(target) >= 2
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DAMAGE CALCULATIONS
-- ═══════════════════════════════════════════════════════════════════════════
local DamageCalc = {}

function DamageCalc:GetEDamage(target)
    if not target then return 0 end
    local level = myHero:GetSpellData(_E).level
    if level == 0 then return 0 end
    
    local baseDamage = VAYNE.E.BaseDamage[level]
    local bonusAD = myHero.totalDamage - myHero.baseDamage
    local totalDamage = baseDamage + (bonusAD * VAYNE.E.BonusADRatio)
    
    -- Apply armor reduction
    local armor = target.armor
    local armorMult = 100 / (100 + math_max(0, armor))
    
    return totalDamage * armorMult
end

function DamageCalc:GetWDamage(target)
    if not target then return 0 end
    local level = myHero:GetSpellData(_W).level
    if level == 0 then return 0 end
    
    local percentDamage = target.maxHealth * VAYNE.W.ProcDamage[level]
    local minDamage = VAYNE.W.MinDamage[level]
    
    return math_max(percentDamage, minDamage)
end

function DamageCalc:CanKillWithE(target)
    if not target then return false end
    return target.health <= self:GetEDamage(target)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Q POSITIONING LOGIC (Smart AI)
-- ═══════════════════════════════════════════════════════════════════════════
local QPositioner = {
    lastPos = nil,
    lastTime = 0,
}

-- Check if enemy is fleeing
function QPositioner:IsEnemyFleeing(target)
    if not target or not target.pathing then return false end
    if not target.pathing.hasMovePath then return false end
    
    local vel = target.vel or {x = 0, z = 0}
    local speed = math_sqrt(vel.x * vel.x + vel.z * vel.z)
    if speed < 50 then return false end
    
    local toEnemy = GetDirection(myHero.pos, target.pos)
    local enemyDir = Normalize({x = vel.x, z = vel.z})
    
    -- Dot product > 0 means moving away
    local dot = toEnemy.x * enemyDir.x + toEnemy.z * enemyDir.z
    return dot > 0.3
end

-- Count nearby enemies at a position
function QPositioner:CountEnemiesNear(pos, range)
    if not Menu.QSettings.CheckEnemies:Value() then return 0 end
    
    local count = 0
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if IsValidTarget(hero) and IsInRange(pos, hero.pos, range) then
            count = count + 1
        end
    end
    return count
end

-- Get perpendicular position (side step)
function QPositioner:GetSidePosition(target, distance, side)
    local dir = GetDirection(myHero.pos, target.pos)
    local perpDir = {x = -dir.z * side, z = dir.x * side}
    return ExtendPosition(myHero.pos, perpDir, distance)
end

-- Get best side position
function QPositioner:GetBestSidePosition(target, distance)
    local leftPos = self:GetSidePosition(target, distance, 1)
    local rightPos = self:GetSidePosition(target, distance, -1)
    
    local leftSafe = WallChecker:IsSafePosition(leftPos)
    local rightSafe = WallChecker:IsSafePosition(rightPos)
    
    -- If both safe, check enemy count
    if leftSafe and rightSafe then
        local leftEnemies = self:CountEnemiesNear(leftPos, 400)
        local rightEnemies = self:CountEnemiesNear(rightPos, 400)
        
        if leftEnemies < rightEnemies then return leftPos end
        if rightEnemies < leftEnemies then return rightPos end
        
        -- Equal enemies, random choice
        return math_random(1, 2) == 1 and leftPos or rightPos
    end
    
    -- Return the safe one
    if leftSafe then return leftPos end
    if rightSafe then return rightPos end
    
    -- Both unsafe, return left anyway
    return leftPos
end

-- Get retreat position (away from enemy)
function QPositioner:GetRetreatPosition(target, distance)
    local dir = GetDirection(target.pos, myHero.pos)
    return ExtendPosition(myHero.pos, dir, distance)
end

-- Get chase position (towards enemy)
function QPositioner:GetChasePosition(target, distance)
    local dir = GetDirection(myHero.pos, target.pos)
    return ExtendPosition(myHero.pos, dir, distance)
end

-- Smart AI Q positioning
function QPositioner:GetSmartQPosition(target)
    if not IsValidTarget(target) then return nil end
    
    local mode = Menu.Combo.QMode:Value()
    
    -- Mode 2: To Mouse
    if mode == 2 then
        return Game.mousePos()
    end
    
    -- Mode 3: Kite Only
    if mode == 3 then
        return self:GetBestSidePosition(target, Menu.QSettings.QRange:Value())
    end
    
    -- Mode 1: Smart AI
    local qRange = Menu.QSettings.QRange:Value()
    local safeDistance = Menu.QSettings.SafeDistance:Value()
    local minDistance = Menu.QSettings.MinDistance:Value()
    local chaseHP = Menu.QSettings.ChaseHP:Value()
    local chaseRange = Menu.QSettings.ChaseRange:Value()
    
    local dist = GetDistance(myHero.pos, target.pos)
    local enemyHP = (target.health / target.maxHealth) * 100
    local myHP = (myHero.health / myHero.maxHealth) * 100
    local isFleeing = self:IsEnemyFleeing(target)
    local attackRange = VAYNE.AttackRange + myHero.boundingRadius + target.boundingRadius
    
    -- PRIORITY 1: Enemy too close (anti-melee)
    if dist < minDistance then
        local retreatPos = self:GetRetreatPosition(target, qRange)
        if WallChecker:IsSafePosition(retreatPos) then
            return retreatPos
        end
        -- If retreat into wall, try sides
        return self:GetBestSidePosition(target, qRange)
    end
    
    -- PRIORITY 2: Enemy outside attack range
    if dist > attackRange then
        -- Chase if enemy is low HP and fleeing
        if enemyHP < chaseHP and isFleeing and dist < chaseRange then
            local chasePos = self:GetChasePosition(target, qRange)
            local newDist = GetDistance(chasePos, target.pos)
            if newDist <= attackRange and WallChecker:IsSafePosition(chasePos) then
                return chasePos
            end
        end
        -- Approach to get in range
        local approachPos = self:GetChasePosition(target, qRange)
        if WallChecker:IsSafePosition(approachPos) then
            return approachPos
        end
    end
    
    -- PRIORITY 3: Within range but too close to comfort
    if dist < safeDistance then
        -- Check if we're lower HP than enemy
        if myHP < enemyHP then
            local retreatPos = self:GetRetreatPosition(target, qRange)
            if WallChecker:IsSafePosition(retreatPos) then
                return retreatPos
            end
        end
        -- Otherwise side step
        return self:GetBestSidePosition(target, qRange)
    end
    
    -- PRIORITY 4: Optimal range - kite to sides
    return self:GetBestSidePosition(target, qRange)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SPELL CASTING
-- ═══════════════════════════════════════════════════════════════════════════
local CastTracker = {
    lastQ = 0,
    lastE = 0,
    lastR = 0,
}

local function CastQ(pos)
    if not Ready(_Q) then return false end
    if not pos then return false end
    
    local now = GameTimer()
    if now - CastTracker.lastQ < VAYNE.Q.Cooldown then return false end
    
    Control.CastSpell(HK_Q, pos)
    CastTracker.lastQ = now
    return true
end

local function CastE(target)
    if not Ready(_E) then return false end
    if not IsValidTarget(target, VAYNE.E.Range) then return false end
    
    local now = GameTimer()
    if now - CastTracker.lastE < 0.25 then return false end
    
    Control.CastSpell(HK_E, target.pos)
    CastTracker.lastE = now
    return true
end

local function CastR()
    if not Ready(_R) then return false end
    
    local now = GameTimer()
    if now - CastTracker.lastR < 0.5 then return false end
    
    Control.CastSpell(HK_R)
    CastTracker.lastR = now
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- E LOGIC (Target Finding)
-- ═══════════════════════════════════════════════════════════════════════════
local ELogic = {}

function ELogic:GetWallStunTarget()
    if not Menu.ESettings.WallStunEnabled:Value() then return nil end
    if not Ready(_E) then return nil end
    
    local knockbackDist = Menu.ESettings.KnockbackDist:Value()
    local extraCheck = Menu.ESettings.ExtraWallCheck:Value()
    local precision = Menu.ESettings.WallCheckPrecision:Value()
    local angleScan = Menu.ESettings.AngleScan:Value()
    
    local enemies = GetEnemies(VAYNE.E.Range)
    local bestTarget = nil
    local bestDist = math_huge
    
    for _, enemy in ipairs(enemies) do
        local wallPos, wallDist = WallChecker:GetWallStunPosition(
            enemy, knockbackDist, extraCheck, precision, angleScan
        )
        
        if wallPos and wallDist < bestDist then
            bestDist = wallDist
            bestTarget = enemy
        end
    end
    
    return bestTarget
end

function ELogic:GetSelfPeelTarget()
    if not Menu.ESettings.SelfPeel:Value() then return nil end
    if not Ready(_E) then return nil end
    
    local myHP = (myHero.health / myHero.maxHealth) * 100
    if myHP > Menu.ESettings.PeelHP:Value() then return nil end
    
    local peelRange = Menu.ESettings.PeelRange:Value()
    local enemies = GetEnemies(VAYNE.E.Range)
    
    for _, enemy in ipairs(enemies) do
        if IsInRange(myHero.pos, enemy.pos, peelRange) then
            return enemy
        end
    end
    
    return nil
end

function ELogic:GetKillstealTarget()
    if not Menu.ESettings.Killsteal:Value() then return nil end
    if not Ready(_E) then return nil end
    
    local enemies = GetEnemies(VAYNE.E.Range)
    
    for _, enemy in ipairs(enemies) do
        if DamageCalc:CanKillWithE(enemy) then
            return enemy
        end
    end
    
    return nil
end

function ELogic:GetInterruptTarget()
    if not Menu.ESettings.Interrupt:Value() then return nil end
    if not Ready(_E) then return nil end
    
    local enemies = GetEnemies(VAYNE.E.Range)
    
    for _, enemy in ipairs(enemies) do
        local spell = enemy.activeSpell
        if spell and spell.valid and InterruptableSpells[spell.name] then
            if spell.castEndTime > GameTimer() + 0.33 then
                return enemy
            end
        end
    end
    
    return nil
end

function ELogic:GetBestTarget(onlyStun)
    -- Priority order
    local stunTarget = self:GetWallStunTarget()
    if stunTarget then return stunTarget end
    
    if onlyStun then return nil end
    
    local interruptTarget = self:GetInterruptTarget()
    if interruptTarget then return interruptTarget end
    
    local killTarget = self:GetKillstealTarget()
    if killTarget then return killTarget end
    
    local peelTarget = self:GetSelfPeelTarget()
    if peelTarget then return peelTarget end
    
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- POST-ATTACK SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
local PostAttack = {
    lastTime = 0,
    pendingQ = nil,
    hooked = false,
}

local function HookOrbwalker()
    if PostAttack.hooked then return true end
    
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.OnPostAttack then
        _G.SDK.Orbwalker:OnPostAttack(function()
            PostAttack.lastTime = GameTimer()
            
            -- Execute pending Q
            if PostAttack.pendingQ and Ready(_Q) then
                if CastQ(PostAttack.pendingQ) then
                    PostAttack.pendingQ = nil
                end
            end
        end)
        PostAttack.hooked = true
        return true
    end
    
    return false
end

local function IsPostAttackWindow()
    if not Menu.QSettings.PostAttack:Value() then return true end
    if not PostAttack.hooked then return true end
    return GameTimer() - PostAttack.lastTime < 0.5
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MODE EXECUTION
-- ═══════════════════════════════════════════════════════════════════════════
local function ExecuteCombo()
    local target = GetClosestEnemy(VAYNE.E.Range + 200)
    if not target then return end
    
    -- R logic
    if Menu.Combo.UseR:Value() and Ready(_R) then
        local enemyCount = #GetEnemies(Menu.Combo.RRange:Value())
        if enemyCount >= Menu.Combo.REnemies:Value() then
            CastR()
        end
    end
    
    -- E logic
    if Menu.Combo.UseE:Value() and Ready(_E) then
        local onlyStun = Menu.Combo.EOnlyStun:Value()
        local eTarget = ELogic:GetBestTarget(onlyStun)
        if eTarget then
            CastE(eTarget)
            return
        end
    end
    
    -- Q logic
    if Menu.Combo.UseQ:Value() and Ready(_Q) and IsValidTarget(target) then
        local qPos = QPositioner:GetSmartQPosition(target)
        if qPos then
            if Menu.QSettings.PostAttack:Value() then
                PostAttack.pendingQ = qPos
            elseif IsPostAttackWindow() then
                CastQ(qPos)
            end
        end
    end
end

local function ExecuteHarass()
    local target = GetClosestEnemy(VAYNE.E.Range + 100)
    if not target then return end
    
    local manaPercent = (myHero.mana / myHero.maxMana) * 100
    if manaPercent < Menu.Harass.MinMana:Value() then return end
    
    -- E for wall stun
    if Menu.Harass.UseE:Value() and Ready(_E) then
        local stunTarget = ELogic:GetWallStunTarget()
        if stunTarget then
            CastE(stunTarget)
            return
        end
    end
    
    -- Q logic
    if Menu.Harass.UseQ:Value() and Ready(_Q) and IsValidTarget(target) then
        if not Menu.Harass.QWith2W:Value() or WStacks:HasTwo(target) then
            local qPos = QPositioner:GetSmartQPosition(target)
            if qPos then
                PostAttack.pendingQ = qPos
            end
        end
    end
end

local function ExecuteLaneClear()
    local manaPercent = (myHero.mana / myHero.maxMana) * 100
    if manaPercent < Menu.LaneClear.MinMana:Value() then return end
    
    -- Find nearest minion
    local nearestMinion = nil
    local nearestDist = math_huge
    
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and minion.valid and not minion.dead and minion.team == TEAM_ENEMY then
            local dist = GetDistanceSqr(myHero.pos, minion.pos)
            if dist < nearestDist then
                nearestDist = dist
                nearestMinion = minion
            end
        end
    end
    
    if not nearestMinion then return end
    
    -- Q towards mouse for clear
    if Menu.LaneClear.UseQ:Value() and Ready(_Q) then
        if not Menu.LaneClear.QWith2W:Value() or WStacks:HasTwo(nearestMinion) then
            PostAttack.pendingQ = Game.mousePos()
        end
    end
end

local function ExecuteJungleClear()
    local manaPercent = (myHero.mana / myHero.maxMana) * 100
    if manaPercent < Menu.JungleClear.MinMana:Value() then return end
    
    -- Find jungle monster
    local nearestMonster = nil
    local nearestDist = math_huge
    
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and minion.valid and not minion.dead and minion.team == 300 then
            local dist = GetDistanceSqr(myHero.pos, minion.pos)
            if dist < nearestDist and dist < 800 * 800 then
                nearestDist = dist
                nearestMonster = minion
            end
        end
    end
    
    if not nearestMonster then return end
    
    -- Q
    if Menu.JungleClear.UseQ:Value() and Ready(_Q) then
        PostAttack.pendingQ = Game.mousePos()
    end
end

local function ExecuteFlee()
    local enemies = GetEnemies(VAYNE.E.Range + 200)
    if #enemies == 0 then return end
    
    local closestEnemy = GetClosestEnemy(1500)
    if not closestEnemy then return end
    
    -- E logic
    if Menu.Flee.UseE:Value() and Ready(_E) then
        local eTarget
        if Menu.Flee.EWallStun:Value() then
            eTarget = ELogic:GetWallStunTarget()
        else
            -- E closest enemy if very close
            if IsInRange(myHero.pos, closestEnemy.pos, 300) then
                eTarget = closestEnemy
            else
                eTarget = ELogic:GetWallStunTarget()
            end
        end
        
        if eTarget then
            CastE(eTarget)
        end
    end
    
    -- Q away from enemy
    if Menu.Flee.UseQ:Value() and Ready(_Q) then
        local retreatPos = QPositioner:GetRetreatPosition(closestEnemy, Menu.QSettings.QRange:Value())
        if WallChecker:IsSafePosition(retreatPos) then
            CastQ(retreatPos)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DRAWING SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
local function OnDraw()
    if not Menu.Draw.Enabled:Value() then return end
    if not myHero.visible then return end
    
    local mainColor = Menu.Draw.Colors.Main:Value()
    local wallColor = Menu.Draw.Colors.WallStun:Value()
    local targetColor = Menu.Draw.Colors.Target:Value()
    
    -- Q Range
    if Menu.Draw.QRange:Value() then
        Draw.Circle(myHero.pos, VAYNE.AttackRange, 1, mainColor)
    end
    
    -- E Range
    if Menu.Draw.ERange:Value() then
        Draw.Circle(myHero.pos, VAYNE.E.Range, 1, Draw.Color(150, 255, 150, 50))
    end
    
    -- Target
    local target = GetClosestEnemy(VAYNE.E.Range + 200)
    if target and Menu.Draw.Target:Value() then
        Draw.Circle(target.pos, 60, 2, targetColor)
    end
    
    -- Wall Stun Points
    if Menu.Draw.WallStun:Value() and Ready(_E) then
        local enemies = GetEnemies(VAYNE.E.Range)
        for _, enemy in ipairs(enemies) do
            local wallPos = WallChecker:GetWallStunPosition(
                enemy,
                Menu.ESettings.KnockbackDist:Value(),
                Menu.ESettings.ExtraWallCheck:Value(),
                Menu.ESettings.WallCheckPrecision:Value(),
                Menu.ESettings.AngleScan:Value()
            )
            
            if wallPos then
                Draw.Circle(wallPos, 80, 2, wallColor)
                Draw.Line(enemy.pos:To2D(), Vector(wallPos):To2D(), 2, wallColor)
                
                local textPos = Vector(wallPos):To2D()
                Draw.Text("STUN", 16, textPos.x - 20, textPos.y - 30, Draw.Color(255, 255, 255, 0))
            end
        end
    end
    
    -- W Stacks
    if Menu.Draw.WStacks:Value() then
        local enemies = GetEnemies(2000)
        for _, enemy in ipairs(enemies) do
            local stacks = WStacks:Get(enemy)
            if stacks > 0 then
                local pos = enemy.pos:To2D()
                local color = stacks >= 2 and Draw.Color(255, 255, 215, 0) or Draw.Color(255, 255, 255, 255)
                Draw.Text("W: " .. stacks, 14, pos.x - 20, pos.y - 40, color)
            end
        end
    end
    
    -- Q Position preview
    if Menu.Draw.QPosition:Value() and target and Ready(_Q) then
        local qPos = QPositioner:GetSmartQPosition(target)
        if qPos then
            Draw.Circle(qPos, 50, 2, Draw.Color(200, 100, 200, 255))
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════
Callback.Add("Tick", function()
    if myHero.dead or GameIsChatOpen() then return end
    
    -- Try to hook orbwalker
    if not PostAttack.hooked then
        HookOrbwalker()
    end
    
    -- Update W stacks
    WStacks:Update()
    
    -- Clean wall cache
    WallChecker:CleanCache()
    
    -- Execute mode
    local mode = GetMode()
    
    if mode == "Combo" then
        ExecuteCombo()
    elseif mode == "Harass" then
        ExecuteHarass()
    elseif mode == "LaneClear" then
        ExecuteLaneClear()
    elseif mode == "JungleClear" then
        ExecuteJungleClear()
    elseif mode == "Flee" then
        ExecuteFlee()
    end
end)

Callback.Add("Draw", OnDraw)

Callback.Add("Load", function()
    if HookOrbwalker() then
        print("[Vayne] Orbwalker hooked successfully!")
    else
        print("[Vayne] Waiting for orbwalker...")
    end
    
    print("[Depressive Vayne] v4.0 Loaded - Advanced Wall Detection & Smart Q")
end)