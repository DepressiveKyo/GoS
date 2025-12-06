local Version = 5.1
local __name__ = "DepressivePrediction"
local __version__ = Version

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTOUPDATE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
if _G.DepressivePredictionUpdate then return end
_G.DepressivePredictionUpdate = {}

do
    local Updater = _G.DepressivePredictionUpdate
    Updater.Callbacks = {}
    
    function Updater:DownloadFile(url, path)
        DownloadFileAsync(url, path, function() end)
    end
    
    function Updater:Trim(s)
        local from = s:match("^%s*()")
        return from > #s and "" or s:match(".*%S", from)
    end
    
    function Updater:ReadFile(path)
        local result = {}
        local file = io.open(path, "r")
        if file then
            for line in file:lines() do
                local str = self:Trim(line)
                if #str > 0 then
                    result[#result + 1] = str
                end
            end
            file:close()
        end
        return result
    end
    
    function Updater:New(args)
        local updater = {
            Step = 1,
            Version = tonumber(args.version) or 0,
            VersionUrl = args.versionUrl,
            VersionPath = args.versionPath,
            ScriptUrl = args.scriptUrl,
            ScriptPath = args.scriptPath,
            ScriptName = args.scriptName,
            VersionTimer = GetTickCount()
        }
        
        function updater:DownloadVersion()
            if not FileExist(self.ScriptPath) then
                self.Step = 4
                Updater:DownloadFile(self.ScriptUrl, self.ScriptPath)
                self.ScriptTimer = GetTickCount()
                return
            end
            Updater:DownloadFile(self.VersionUrl, self.VersionPath)
        end
        
        function updater:OnTick()
            if self.Step == 0 then return end
            
            if self.Step == 1 and GetTickCount() > self.VersionTimer + 1000 then
                local response = Updater:ReadFile(self.VersionPath)
                if #response > 0 and tonumber(response[1]) > self.Version then
                    self.Step = 2
                    self.NewVersion = response[1]
                    Updater:DownloadFile(self.ScriptUrl, self.ScriptPath)
                    self.ScriptTimer = GetTickCount()
                else
                    self.Step = 3
                end
            elseif self.Step == 2 and GetTickCount() > self.ScriptTimer + 1000 then
                self.Step = 0
                print(self.ScriptName .. " - new update found! [" .. tostring(self.Version) .. " -> " .. self.NewVersion .. "] Please 2xf6!")
            elseif self.Step == 3 then
                self.Step = 0
            elseif self.Step == 4 and GetTickCount() > self.ScriptTimer + 1000 then
                self.Step = 0
                print(self.ScriptName .. " - downloaded! Please 2xf6!")
            end
        end
        
        function updater:CanUpdate()
            local response = Updater:ReadFile(self.VersionPath)
            return #response > 0 and tonumber(response[1]) > self.Version
        end
        
        updater:DownloadVersion()
        self.Callbacks[#self.Callbacks + 1] = updater
        return updater
    end
end

Callback.Add("Tick", function()
    for i = 1, #_G.DepressivePredictionUpdate.Callbacks do
        local updater = _G.DepressivePredictionUpdate.Callbacks[i]
        if updater.Step > 0 then
            updater:OnTick()
        end
    end
end)

if _G.DepressivePredictionUpdate:New({
    version = __version__,
    scriptName = __name__,
    scriptPath = COMMON_PATH .. "DepressivePrediction.lua",
    scriptUrl = "https://raw.githubusercontent.com/DepressiveKyo/GoS/refs/heads/main/DepressivePrediction.lua",
    versionPath = COMMON_PATH .. "DepressivePrediction.version",
    versionUrl = "https://raw.githubusercontent.com/DepressiveKyo/GoS/refs/heads/main/DepressivePrediction.version",
}):CanUpdate() then
    return
end

if _G.DepressivePrediction then return end

-- ═══════════════════════════════════════════════════════════════════════════
-- LOCALIZED FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════
local Game = _G.Game
local Callback = _G.Callback
local myHero = _G.myHero

local math_sqrt = math.sqrt
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_huge = math.huge
local math_floor = math.floor
local math_cos = math.cos
local math_sin = math.sin
local math_atan2 = math.atan2
local math_pi = math.pi

local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort

local os_clock = os.clock
local type = type
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local tonumber = tonumber
local tostring = tostring

-- ═══════════════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════════
local HITCHANCE_IMPOSSIBLE = 0
local HITCHANCE_COLLISION = 1
local HITCHANCE_LOW = 2
local HITCHANCE_NORMAL = 3
local HITCHANCE_HIGH = 4
local HITCHANCE_VERYHIGH = 5
local HITCHANCE_IMMOBILE = 6

local SPELLTYPE_LINE = 0
local SPELLTYPE_CIRCLE = 1
local SPELLTYPE_CONE = 2

local COLLISION_MINION = 0
local COLLISION_ALLYHERO = 1
local COLLISION_ENEMYHERO = 2
local COLLISION_YASUOWALL = 3
local COLLISION_NEUTRAL = 4
local COLLISION_ALLYMINION = 5
local COLLISION_ENEMYMINION = 6

-- Movement behavior types (for pattern detection)
local MOVEMENT_STATIC = 0
local MOVEMENT_LINEAR = 1
local MOVEMENT_ORBWALK = 2
local MOVEMENT_KITING = 3
local MOVEMENT_ERRATIC = 4
local MOVEMENT_CHASE = 5
local MOVEMENT_FLEE = 6

-- CC Types
local CC_TYPES = {
    [5] = true, [8] = true, [9] = true, [11] = true,
    [21] = true, [22] = true, [24] = true, [28] = true,
    [29] = true, [30] = true, [31] = true, [39] = true,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════
local Config = {
    Ping = 0,
    Delay = 0,
    LeadFactor = 100,
    LastPingUpdate = 0,
    PingUpdateInterval = 0.5,
    
    -- Precision settings
    HistorySize = 20,           -- More history for better analysis
    AnalysisInterval = 0.1,     -- Faster analysis
    MinSamplesForPattern = 4,   -- Minimum samples needed
    VelocitySmoothing = 0.7,    -- Exponential smoothing factor
    DirectionChangeThreshold = 0.3,  -- Radians threshold for direction change
}

local function UpdateAutoSettings()
    local now = Game.Timer()
    if now - Config.LastPingUpdate < Config.PingUpdateInterval then return end
    Config.LastPingUpdate = now
    
    local ok, ping = pcall(function() return Game.Latency and Game.Latency() or 0 end)
    Config.Ping = ok and ping or 0
    
    if Config.Ping < 40 then
        Config.Delay = 20
        Config.LeadFactor = 98
    elseif Config.Ping < 70 then
        Config.Delay = 35
        Config.LeadFactor = 100
    elseif Config.Ping < 100 then
        Config.Delay = 50
        Config.LeadFactor = 102
    else
        Config.Delay = 65
        Config.LeadFactor = 105
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MENU
-- ═══════════════════════════════════════════════════════════════════════════
local Menu = nil

do
    local ok, err = pcall(function()
        if _G.MenuElement then
            local root = MenuElement({name = "Depressive Prediction", id = "DepressivePrediction", type = _G.MENU})
            Menu = {
                Root = root,
                Enable = root:MenuElement({id = "Enable", name = "Enable Prediction", value = true}),
                MaxRange = root:MenuElement({id = "MaxRange", name = "Max Range %", value = 95, min = 70, max = 100, step = 1}),
                DrawPrediction = root:MenuElement({id = "DrawPrediction", name = "Draw Prediction", value = true}),
                DrawMovementType = root:MenuElement({id = "DrawMovementType", name = "Draw Movement Type", value = false}),
                VersionInfo = root:MenuElement({name = 'Version ' .. Version .. ' | Precision Mode', type = _G.SPACE, id = 'VersionSpace'}),
            }
            
            Menu.DashPrediction = {Value = function() return true end}
            Menu.ZhonyaDetection = {Value = function() return true end}
            Menu.YasuoWallDetection = {Value = function() return true end}
            Menu.ShowVisuals = {Value = function() return false end}
            Menu.Collision = {Value = function() return true end}
        end
    end)
    if not ok then print("[DepressivePrediction] Menu error: " .. tostring(err)) end
end

if Menu then
    function Menu:GetLatency() return Config.Ping * 0.001 end
    function Menu:GetExtraDelay() return Config.Delay / 1000 end
    function Menu:GetLeadFactor() return Config.LeadFactor / 100 end
    function Menu:GetMaxRange()
        local val = self.MaxRange and self.MaxRange:Value() or 95
        return math_max(60, math_min(100, val)) / 100
    end
    function Menu:GetEffectiveRange(baseRange, target, useBoundingRadius)
        local effective = baseRange * self:GetMaxRange()
        if useBoundingRadius and target and target.boundingRadius then
            effective = effective + target.boundingRadius
        end
        return effective * 0.95
    end
    function Menu:GetReactionTime() return 0.12 end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MATH MODULE (Enhanced)
-- ═══════════════════════════════════════════════════════════════════════════
local Math = {}
_G.DepressivePredictionMath = Math

local MapBoundsCache = nil
local MapBoundsCacheTime = 0
local CurrentMapData = nil
local DynamicArenaBounds = nil  -- Cache for dynamically detected Arena bounds

-- Map Data definitions
local MapData = {
    -- Summoner's Rift (ID: 11)
    SummonersRift = {
        id = 11,
        name = "Summoner's Rift",
        bounds = {minX = -200, maxX = 15000, minZ = -200, maxZ = 15000, maxDistance = 21000},
        center = {x = 7400, z = 7400},
        predictionSettings = {
            reactionTime = 0.15,
            leadFactor = 1.0,
            maxPredictionTime = 2.5,
            velocitySmoothing = 0.7,
        }
    },
    
    -- Howling Abyss / ARAM (ID: 12)
    HowlingAbyss = {
        id = 12,
        name = "Howling Abyss",
        bounds = {minX = -200, maxX = 13000, minZ = -200, maxZ = 13000, maxDistance = 18000},
        center = {x = 6500, z = 6500},
        predictionSettings = {
            reactionTime = 0.12,
            leadFactor = 1.05,
            maxPredictionTime = 2.0,
            velocitySmoothing = 0.65,
        }
    },
    
    -- Arena (IDs: 30, 33, and 30-35 range)
    -- NOTE: Arena bounds are DYNAMIC - each arena ring has different coordinates
    -- Default bounds are generous to not break predictions; will be refined dynamically
    Arena = {
        id = 30,
        name = "Arena",
        bounds = {minX = -2000, maxX = 16000, minZ = -2000, maxZ = 16000, maxDistance = 18000},
        center = {x = 7000, z = 7000},  -- Will be calculated dynamically
        predictionSettings = {
            reactionTime = 0.08,          -- Faster reactions needed in Arena
            leadFactor = 1.15,            -- More aggressive lead
            maxPredictionTime = 1.5,      -- Shorter prediction window
            velocitySmoothing = 0.6,      -- Less smoothing, more reactive
            speedMultiplier = 1.0,        -- No speed multiplier - causes issues
            directionChangeWeight = 1.3,  -- Weight direction changes more
            orbwalkAdjustment = 0.65,     -- Adjusted for Arena
            erraticAdjustment = 0.45,     -- Adjusted for Arena
            kitingAdjustment = 0.7,       -- Adjusted for Arena
        },
    },
}

-- Dynamically detect Arena bounds based on hero positions
local function DetectArenaBoundsFromHeroes()
    local minX, maxX, minZ, maxZ = math_huge, -math_huge, math_huge, -math_huge
    local foundValidPos = false
    
    -- Scan all heroes to find the actual playing area
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid and hero.pos and hero.pos.x then
            local x, z = hero.pos.x, hero.pos.z
            if math_abs(x) < 50000 and math_abs(z) < 50000 then
                minX = math_min(minX, x - 1500)
                maxX = math_max(maxX, x + 1500)
                minZ = math_min(minZ, z - 1500)
                maxZ = math_max(maxZ, z + 1500)
                foundValidPos = true
            end
        end
    end
    
    if foundValidPos then
        -- Add generous padding for movement
        return {
            minX = minX - 500,
            maxX = maxX + 500,
            minZ = minZ - 500,
            maxZ = maxZ + 500,
            maxDistance = math_sqrt((maxX - minX)^2 + (maxZ - minZ)^2) + 2000,
            isArena = true,
            isDynamic = true
        }
    end
    
    return nil
end

-- Detect current map
local function DetectCurrentMap()
    local mapID = 0
    local mapName = ""
    
    pcall(function()
        mapID = Game.mapID or 0
        mapName = Game.mapName and tostring(Game.mapName) or ""
    end)
    
    -- Check by ID first - Arena IDs are 30 and 33 (2v2v2v2)
    if mapID == 11 then
        return MapData.SummonersRift
    elseif mapID == 12 then
        return MapData.HowlingAbyss
    elseif mapID == 30 or mapID == 33 or (mapID >= 30 and mapID <= 35) then
        return MapData.Arena
    end
    
    -- Fallback to name detection
    local nameLower = mapName:lower()
    if nameLower:find("arena") or nameLower:find("cherry") then
        return MapData.Arena
    elseif nameLower:find("aram") or nameLower:find("abyss") then
        return MapData.HowlingAbyss
    elseif nameLower:find("rift") then
        return MapData.SummonersRift
    end
    
    -- Default to Summoner's Rift
    return MapData.SummonersRift
end

function Math:GetMapData()
    if not CurrentMapData then
        CurrentMapData = DetectCurrentMap()
        _G.CurrentMapType = CurrentMapData.name
    end
    return CurrentMapData
end

function Math:GetMapBounds()
    local now = Game.Timer()
    
    -- Cache for 5 seconds (shorter for Arena to allow dynamic updates)
    local cacheTime = self:IsArenaInternal() and 5 or 30
    if MapBoundsCache and now - MapBoundsCacheTime < cacheTime then
        return MapBoundsCache
    end
    
    local mapData = self:GetMapData()
    local bounds = mapData.bounds
    
    -- For Arena, try to get dynamic bounds
    if mapData.name == "Arena" then
        -- Method 1: Try MapPosition.GetMapBounds if available
        if _G.MapPosition and _G.MapPosition.GetMapBounds then
            local ok, mapBounds = pcall(_G.MapPosition.GetMapBounds)
            if ok and mapBounds and mapBounds.minX then
                bounds = mapBounds
                bounds.isArena = true
            end
        end
        
        -- Method 2: If still using default bounds, detect from hero positions
        if not bounds.isDynamic then
            local dynamicBounds = DetectArenaBoundsFromHeroes()
            if dynamicBounds then
                DynamicArenaBounds = dynamicBounds
                bounds = dynamicBounds
            end
        end
        
        -- Method 3: Use myHero position as center with generous bounds
        if not bounds.isDynamic and myHero and myHero.pos and myHero.pos.x then
            local hx, hz = myHero.pos.x, myHero.pos.z
            if math_abs(hx) < 50000 and math_abs(hz) < 50000 then
                bounds = {
                    minX = hx - 3000,
                    maxX = hx + 3000,
                    minZ = hz - 3000,
                    maxZ = hz + 3000,
                    maxDistance = 6000,
                    isArena = true,
                    isDynamic = true
                }
            end
        end
    end
    
    MapBoundsCache = bounds
    MapBoundsCacheTime = now
    return MapBoundsCache
end

-- Internal arena check (avoids circular dependency with GetMapData)
function Math:IsArenaInternal()
    local mapID = 0
    pcall(function() mapID = Game.mapID or 0 end)
    return mapID == 30 or mapID == 33 or (mapID >= 30 and mapID <= 35)
end

function Math:GetPredictionSettings()
    local mapData = self:GetMapData()
    return mapData.predictionSettings
end

function Math:IsArena()
    local mapData = self:GetMapData()
    return mapData.name == "Arena"
end

function Math:IsARAM()
    local mapData = self:GetMapData()
    return mapData.name == "Howling Abyss"
end

function Math:GetMapCenter()
    local mapData = self:GetMapData()
    return mapData.center
end

function Math:SanitizePosition(pos)
    if not pos or not pos.x or not pos.z then return nil end
    
    -- For Arena, be very lenient with bounds - don't clamp positions
    -- This prevents prediction from being broken by incorrect bounds
    if self:IsArenaInternal() then
        -- Only reject clearly invalid positions
        if math_abs(pos.x) > 50000 or math_abs(pos.z) > 50000 then
            return nil
        end
        return pos
    end
    
    -- For other maps, use bounds clamping
    local bounds = self:GetMapBounds()
    local padding = 1000  -- Generous padding
    pos.x = math_max(bounds.minX - padding, math_min(bounds.maxX + padding, pos.x))
    pos.z = math_max(bounds.minZ - padding, math_min(bounds.maxZ + padding, pos.z))
    return pos
end

function Math:Get2D(p)
    if not p then return nil end
    local actualPos = p.pos and p.pos.x and p.pos or p
    if not actualPos.x then return nil end
    local pos2D = {x = actualPos.x, z = actualPos.z or actualPos.y or 0}
    if math_abs(pos2D.x) > 50000 or math_abs(pos2D.z) > 50000 then return nil end
    return self:SanitizePosition(pos2D)
end

function Math:GetDistance(p1, p2)
    if not p1 or not p2 or not p1.x or not p2.x then return math_huge end
    local dx, dz = p2.x - p1.x, p2.z - p1.z
    return math_sqrt(dx * dx + dz * dz)
end

function Math:GetDistanceSqr(p1, p2)
    if not p1 or not p2 or not p1.x or not p2.x then return math_huge end
    local dx, dz = p2.x - p1.x, p2.z - p1.z
    return dx * dx + dz * dz
end

function Math:IsInRange(p1, p2, range)
    if not p1 or not p2 or not p1.x or not p2.x then return false end
    local dx, dz = p1.x - p2.x, p1.z - p2.z
    return dx * dx + dz * dz <= range * range
end

function Math:Normalized(p1, p2)
    if not p1 or not p2 then return nil end
    local dx, dz = p1.x - p2.x, p1.z - p2.z
    local length = math_sqrt(dx * dx + dz * dz)
    if length > 0.001 then
        return {x = dx / length, z = dz / length}
    end
    return nil
end

function Math:Normalize(v)
    if not v or not v.x then return nil end
    local length = math_sqrt(v.x * v.x + v.z * v.z)
    if length > 0.001 then
        return {x = v.x / length, z = v.z / length}
    end
    return nil
end

function Math:Extended(vec, dir, range)
    if not dir then return vec end
    return {x = vec.x + dir.x * range, z = vec.z + dir.z * range}
end

function Math:Perpendicular(dir)
    if not dir then return nil end
    return {x = -dir.z, z = dir.x}
end

function Math:DotProduct(v1, v2)
    return v1.x * v2.x + v1.z * v2.z
end

function Math:CrossProduct(v1, v2)
    return v1.x * v2.z - v1.z * v2.x
end

function Math:AngleBetween(v1, v2)
    local dot = self:DotProduct(v1, v2)
    local len1 = math_sqrt(v1.x * v1.x + v1.z * v1.z)
    local len2 = math_sqrt(v2.x * v2.x + v2.z * v2.z)
    if len1 < 0.001 or len2 < 0.001 then return 0 end
    local cos_angle = dot / (len1 * len2)
    cos_angle = math_max(-1, math_min(1, cos_angle))
    return math_abs(math.acos(cos_angle))
end

function Math:VectorAngle(v)
    return math_atan2(v.z, v.x)
end

function Math:RotateVector(v, angle)
    local cos_a = math_cos(angle)
    local sin_a = math_sin(angle)
    return {
        x = v.x * cos_a - v.z * sin_a,
        z = v.x * sin_a + v.z * cos_a
    }
end

function Math:Lerp(a, b, t)
    return a + (b - a) * t
end

function Math:LerpVector(v1, v2, t)
    return {
        x = v1.x + (v2.x - v1.x) * t,
        z = v1.z + (v2.z - v1.z) * t
    }
end

-- Catmull-Rom spline interpolation for smooth prediction
function Math:CatmullRom(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    return {
        x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2*p0.x - 5*p1.x + 4*p2.x - p3.x) * t2 + (-p0.x + 3*p1.x - 3*p2.x + p3.x) * t3),
        z = 0.5 * ((2 * p1.z) + (-p0.z + p2.z) * t + (2*p0.z - 5*p1.z + 4*p2.z - p3.z) * t2 + (-p0.z + 3*p1.z - 3*p2.z + p3.z) * t3)
    }
end

function Math:ClampTowards(current, predicted, maxDist)
    if not current or not predicted then return predicted end
    local dx = predicted.x - current.x
    local dz = predicted.z - current.z
    local d = math_sqrt(dx * dx + dz * dz)
    if d <= maxDist then return predicted end
    local scale = maxDist / d
    return {x = current.x + dx * scale, z = current.z + dz * scale}
end

-- Advanced intercept with iterative refinement
function Math:AdvancedIntercept(src, targetPos, targetVel, speed, delay)
    local srcPos = self:Get2D(src)
    local tgtPos0 = self:Get2D(targetPos)
    if not srcPos or not tgtPos0 then return nil end
    
    local tgtVel = {x = targetVel.x or 0, z = targetVel.z or targetVel.y or 0}
    local velMag = math_sqrt(tgtVel.x * tgtVel.x + tgtVel.z * tgtVel.z)
    if velMag > 2500 then return nil end
    
    local dly = delay or 0
    
    -- Iterative refinement for better accuracy
    local iterations = 3
    local tgtPos = {x = tgtPos0.x, z = tgtPos0.z}
    local totalTime = dly
    
    for iter = 1, iterations do
        -- Advance target by current estimate
        tgtPos = {
            x = tgtPos0.x + tgtVel.x * totalTime,
            z = tgtPos0.z + tgtVel.z * totalTime
        }
        
        local dx = tgtPos.x - srcPos.x
        local dz = tgtPos.z - srcPos.z
        local dist = math_sqrt(dx * dx + dz * dz)
        
        if dist > 10000 then return nil end
        
        -- Calculate flight time
        local flightTime = speed == math_huge and 0 or dist / speed
        totalTime = dly + flightTime
        
        if totalTime > 4.0 then return nil end
    end
    
    -- Final calculation with quadratic solver
    local dx = tgtPos0.x + tgtVel.x * dly - srcPos.x
    local dz = tgtPos0.z + tgtVel.z * dly - srcPos.z
    
    local a = tgtVel.x * tgtVel.x + tgtVel.z * tgtVel.z - speed * speed
    local b = 2 * (tgtVel.x * dx + tgtVel.z * dz)
    local c = dx * dx + dz * dz
    
    local tf = math_huge
    if math_abs(a) < 1e-9 then
        if math_abs(b) > 1e-9 then
            local t = -c / b
            if t >= 0 then tf = t end
        elseif math_abs(c) < 1e-6 then
            tf = 0
        end
    else
        local disc = b * b - 4 * a * c
        if disc >= 0 then
            local sqrtDisc = math_sqrt(disc)
            local t1 = (-b - sqrtDisc) / (2 * a)
            local t2 = (-b + sqrtDisc) / (2 * a)
            if t1 >= 0 then tf = math_min(tf, t1) end
            if t2 >= 0 then tf = math_min(tf, t2) end
        end
    end
    
    if tf == math_huge or tf > 4.0 then return nil end
    
    local totalT = dly + tf
    local predictedX = tgtPos0.x + tgtVel.x * totalT
    local predictedZ = tgtPos0.z + tgtVel.z * totalT
    
    -- Only clamp for non-Arena maps - Arena has dynamic bounds that may be incorrect
    if not self:IsArenaInternal() then
        local bounds = self:GetMapBounds()
        predictedX = math_max(bounds.minX, math_min(bounds.maxX, predictedX))
        predictedZ = math_max(bounds.minZ, math_min(bounds.maxZ, predictedZ))
    else
        -- For Arena, just validate the position is reasonable
        if math_abs(predictedX) > 50000 or math_abs(predictedZ) > 50000 then
            return nil
        end
    end
    
    return {
        x = predictedX,
        z = predictedZ,
        time = totalT
    }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════
local function IsValidTarget(t)
    return t and t.valid and not t.dead and t.visible and t.isTargetable and t.pos and t.pos.x
end

local function IsImmobile(unit)
    if not unit or not unit.buffCount then return false, 0 end
    local now = Game.Timer()
    for i = 0, unit.buffCount do
        local b = unit:GetBuff(i)
        if b and b.count > 0 and b.expireTime > now and b.startTime <= now and CC_TYPES[b.type] then
            return true, b.expireTime - now
        end
    end
    return false, 0
end

local function IsEnemyUnit(u)
    return u and u.valid and u.isEnemy
end

local function IsAllyUnit(u)
    return u and u.valid and u.isAlly
end

local NeutralPatterns = {
    {"dragon", "epic", 9}, {"baron", "epic", 10}, {"herald", "epic", 8},
    {"rift", "epic", 8}, {"scuttle", "neutral", 5}, {"crab", "neutral", 5},
    {"gromp", "camp", 4}, {"krug", "camp", 4}, {"murkwolf", "camp", 4},
    {"razorbeak", "camp", 4}, {"blue", "buff", 6}, {"red", "buff", 6},
    {"buff", "buff", 6}, {"sru_", "camp", 4}
}

local function IdentifyNeutralByName(name)
    if not name or name == "" then return false end
    local lower = name:lower()
    for i = 1, #NeutralPatterns do
        if lower:find(NeutralPatterns[i][1]) then
            return true, NeutralPatterns[i][2], NeutralPatterns[i][3]
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UNIT TRACKER (Enhanced with Movement Analysis)
-- ═══════════════════════════════════════════════════════════════════════════
local UnitTracker = {
    Units = {},
    MaxHistorySize = Config.HistorySize,
    UpdateThreshold = 2,
    MinionNameCache = {},
    LastCacheUpdate = 0,
    CacheUpdateInterval = 2.0,
    LastCleanup = 0,
    CleanupInterval = 5.0
}

-- Initialize unit data structure
local function CreateUnitData(unit, currentTime, pos)
    return {
        -- Position history
        positions = {pos},
        timestamps = {currentTime},
        
        -- Velocity tracking (exponentially smoothed)
        velocity = {x = 0, z = 0},
        smoothedVelocity = {x = 0, z = 0},
        acceleration = {x = 0, z = 0},
        
        -- Direction tracking
        direction = nil,
        lastDirection = nil,
        directionChangeCount = 0,
        lastDirectionChangeTime = 0,
        
        -- Movement analysis
        movementType = MOVEMENT_STATIC,
        movementConfidence = 0,
        avgSpeed = 0,
        speedVariance = 0,
        
        -- Behavior detection
        isOrbwalking = false,
        isKiting = false,
        clickInterval = 0,
        lastClickTime = 0,
        
        -- Visibility
        isVisible = unit.visible,
        wasVisible = unit.visible,
        lastVisibleTime = unit.visible and currentTime or 0,
        lastInvisibleTime = not unit.visible and currentTime or 0,
        
        -- Path state
        lastMoveStartTime = 0,
        lastStopTime = currentTime,
        _lastHasMovePath = false,
        _lastPosTo = nil,
        
        -- Analysis timing
        lastUpdate = currentTime,
        lastAnalysisTime = 0,
        lastPatternUpdate = 0,
    }
end

function UnitTracker:UpdateUnit(unit)
    if not unit or not unit.valid or not unit.pos or not unit.pos.x then return end
    
    local id = unit.networkID
    local currentTime = Game.Timer()
    local pos = Math:Get2D(unit.pos)
    
    if not pos then
        pos = {x = unit.pos.x, z = unit.pos.z or unit.pos.y}
        if math_abs(pos.x) > 30000 or math_abs(pos.z) > 30000 then return end
    end
    
    -- Initialize if needed
    if not self.Units[id] then
        self.Units[id] = CreateUnitData(unit, currentTime, pos)
        return
    end
    
    local data = self.Units[id]
    local lastPos = data.positions[#data.positions]
    local dt = currentTime - data.timestamps[#data.timestamps]
    
    -- Skip if time delta is too small
    if dt < 0.01 then return end
    
    -- Calculate instantaneous velocity
    local dx = pos.x - lastPos.x
    local dz = pos.z - lastPos.z
    local dist = math_sqrt(dx * dx + dz * dz)
    
    -- Only update if moved
    if dist > self.UpdateThreshold then
        -- Add to history
        data.positions[#data.positions + 1] = pos
        data.timestamps[#data.timestamps + 1] = currentTime
        
        -- Trim history
        while #data.positions > self.MaxHistorySize do
            table_remove(data.positions, 1)
            table_remove(data.timestamps, 1)
        end
        
        -- Calculate velocity
        local vx = dx / dt
        local vz = dz / dt
        data.velocity = {x = vx, z = vz}
        
        -- Exponential smoothing for velocity (use map-specific settings)
        local mapSettings = Math:GetPredictionSettings()
        local alpha = mapSettings.velocitySmoothing or Config.VelocitySmoothing
        data.smoothedVelocity = {
            x = alpha * vx + (1 - alpha) * data.smoothedVelocity.x,
            z = alpha * vz + (1 - alpha) * data.smoothedVelocity.z
        }
        
        -- Calculate acceleration
        if data.lastVelocity then
            data.acceleration = {
                x = (vx - data.lastVelocity.x) / dt,
                z = (vz - data.lastVelocity.z) / dt
            }
        end
        data.lastVelocity = {x = vx, z = vz}
        
        -- Direction tracking
        local newDir = Math:Normalize({x = dx, z = dz})
        if newDir and data.direction then
            local angle = Math:AngleBetween(newDir, data.direction)
            if angle > Config.DirectionChangeThreshold then
                data.directionChangeCount = data.directionChangeCount + 1
                data.lastDirectionChangeTime = currentTime
            end
        end
        data.lastDirection = data.direction
        data.direction = newDir
        
        -- Detect posTo changes (click detection)
        if unit.posTo then
            local posTo = Math:Get2D(unit.posTo)
            if posTo and data._lastPosTo then
                local posToChanged = Math:GetDistance(posTo, data._lastPosTo) > 50
                if posToChanged then
                    local clickDt = currentTime - data.lastClickTime
                    if clickDt > 0.05 and clickDt < 0.5 then
                        data.clickInterval = data.clickInterval * 0.7 + clickDt * 0.3
                    end
                    data.lastClickTime = currentTime
                end
            end
            data._lastPosTo = posTo
        end
    end
    
    -- Track visibility changes
    if data.wasVisible ~= unit.visible then
        if unit.visible then
            data.lastVisibleTime = currentTime
        else
            data.lastInvisibleTime = currentTime
        end
        data.wasVisible = unit.visible
    end
    data.isVisible = unit.visible
    
    -- Track movement state
    local hasMovePath = unit.pathing and unit.pathing.hasMovePath or false
    if data._lastHasMovePath ~= hasMovePath then
        if hasMovePath then
            data.lastMoveStartTime = currentTime
        else
            data.lastStopTime = currentTime
            data.directionChangeCount = 0
        end
        data._lastHasMovePath = hasMovePath
    end
    
    data.lastUpdate = currentTime
    
    -- Analyze movement pattern (throttled)
    if currentTime - data.lastAnalysisTime >= Config.AnalysisInterval then
        self:AnalyzeMovementPattern(data, unit, currentTime)
        data.lastAnalysisTime = currentTime
    end
end

function UnitTracker:AnalyzeMovementPattern(data, unit, currentTime)
    local positions = data.positions
    local timestamps = data.timestamps
    local n = #positions
    
    if n < Config.MinSamplesForPattern then
        data.movementType = MOVEMENT_STATIC
        data.movementConfidence = 0
        return
    end
    
    -- Calculate average speed and variance
    local speeds = {}
    local totalSpeed = 0
    
    for i = 2, n do
        local dt = timestamps[i] - timestamps[i-1]
        if dt > 0.01 then
            local dist = Math:GetDistance(positions[i], positions[i-1])
            local speed = dist / dt
            speeds[#speeds + 1] = speed
            totalSpeed = totalSpeed + speed
        end
    end
    
    if #speeds == 0 then
        data.movementType = MOVEMENT_STATIC
        return
    end
    
    local avgSpeed = totalSpeed / #speeds
    data.avgSpeed = avgSpeed
    
    -- Calculate speed variance
    local variance = 0
    for i = 1, #speeds do
        local diff = speeds[i] - avgSpeed
        variance = variance + diff * diff
    end
    variance = variance / #speeds
    data.speedVariance = variance
    
    -- Movement type detection
    local hasMovePath = unit.pathing and unit.pathing.hasMovePath
    local timeSinceStop = currentTime - data.lastStopTime
    local timeSinceStart = currentTime - data.lastMoveStartTime
    local dirChanges = data.directionChangeCount
    local timeSinceDirChange = currentTime - data.lastDirectionChangeTime
    
    -- Static detection
    if not hasMovePath or avgSpeed < 50 then
        data.movementType = MOVEMENT_STATIC
        data.movementConfidence = 0.9
        return
    end
    
    -- Orbwalk detection: frequent stops with regular click intervals
    local isOrbwalking = data.clickInterval > 0.08 and data.clickInterval < 0.35 and 
                         timeSinceStop < 0.5 and variance > 10000
    if isOrbwalking then
        data.movementType = MOVEMENT_ORBWALK
        data.movementConfidence = 0.7
        data.isOrbwalking = true
        return
    end
    data.isOrbwalking = false
    
    -- Erratic movement: many direction changes
    local isErratic = dirChanges > 3 and timeSinceDirChange < 0.8
    if isErratic then
        data.movementType = MOVEMENT_ERRATIC
        data.movementConfidence = 0.6
        return
    end
    
    -- Kiting detection: movement away from myHero with direction changes
    if myHero and myHero.pos then
        local toHero = Math:Normalized(Math:Get2D(myHero.pos), positions[n])
        if toHero and data.direction then
            local dot = Math:DotProduct(toHero, data.direction)
            if dot < -0.3 and dirChanges > 1 then
                data.movementType = MOVEMENT_KITING
                data.movementConfidence = 0.7
                data.isKiting = true
                return
            end
        end
    end
    data.isKiting = false
    
    -- Linear movement: consistent direction
    if dirChanges <= 1 and timeSinceDirChange > 0.5 then
        data.movementType = MOVEMENT_LINEAR
        data.movementConfidence = 0.85
        return
    end
    
    -- Default: normal movement
    data.movementType = MOVEMENT_LINEAR
    data.movementConfidence = 0.7
end

function UnitTracker:GetPredictedPosition(unit, time)
    local id = unit.networkID
    local data = self.Units[id]
    
    if not data or #data.positions < 2 then
        return Math:Get2D(unit.pos)
    end
    
    local currentPos = Math:Get2D(unit.pos)
    if not currentPos then return nil end
    
    time = math_min(time, 2.5)
    
    -- Check special states first
    local specialPos = self:CheckSpecialStates(unit, data, currentPos, time)
    if specialPos then return specialPos end
    
    -- If not moving, return current position
    if not unit.pathing or not unit.pathing.hasMovePath then
        return currentPos
    end
    
    -- Get prediction based on movement type
    local predPos = nil
    
    if data.movementType == MOVEMENT_STATIC then
        return currentPos
        
    elseif data.movementType == MOVEMENT_LINEAR then
        predPos = self:LinearPrediction(unit, data, currentPos, time)
        
    elseif data.movementType == MOVEMENT_ORBWALK then
        predPos = self:OrbwalkPrediction(unit, data, currentPos, time)
        
    elseif data.movementType == MOVEMENT_KITING then
        predPos = self:KitingPrediction(unit, data, currentPos, time)
        
    elseif data.movementType == MOVEMENT_ERRATIC then
        predPos = self:ErraticPrediction(unit, data, currentPos, time)
        
    else
        predPos = self:LinearPrediction(unit, data, currentPos, time)
    end
    
    -- Validate and clamp prediction
    if predPos then
        local ms = unit.ms or 400
        local maxDist = ms * time * 1.2
        predPos = Math:ClampTowards(currentPos, predPos, maxDist)
    else
        predPos = currentPos
    end
    
    return predPos
end

function UnitTracker:CheckSpecialStates(unit, data, currentPos, time)
    -- Check dash
    if Menu.DashPrediction:Value() then
        local isDashing, dashEndPos, dashEndTime = false, nil, 0
        pcall(function()
            if unit.pathing and unit.pathing.isDashing then
                isDashing = true
                dashEndPos = unit.pathing.endPos
                if dashEndPos then
                    local dashDist = Math:GetDistance(currentPos, Math:Get2D(dashEndPos))
                    dashEndTime = dashDist / (unit.pathing.dashSpeed or 1200)
                end
            end
        end)
        
        if isDashing and dashEndPos then
            local finalPos = Math:Get2D(dashEndPos)
            if time > dashEndTime then
                return finalPos
            else
                local progress = time / math_max(0.01, dashEndTime)
                return Math:LerpVector(currentPos, finalPos, progress)
            end
        end
    end
    
    -- Check Zhonya's
    if Menu.ZhonyaDetection:Value() then
        local isZhonya, zhonyaEnd = false, 0
        pcall(function()
            if unit.buffCount then
                for i = 0, unit.buffCount do
                    local buff = unit:GetBuff(i)
                    if buff and buff.name then
                        local name = buff.name:lower()
                        if name:find("zhonya") or name:find("chronoshift") or 
                           name:find("guardianangel") or name:find("stopwatch") then
                            isZhonya = true
                            zhonyaEnd = buff.duration or 2.5
                            break
                        end
                    end
                end
            end
        end)
        
        if isZhonya and time < zhonyaEnd then
            return currentPos
        end
    end
    
    return nil
end

function UnitTracker:LinearPrediction(unit, data, currentPos, time)
    -- Try path-based prediction first
    local path = self:GetUnitPath(unit)
    if #path > 1 then
        local ms = unit.ms or 400
        local remain = ms * time
        
        for i = 1, #path - 1 do
            local a, b = path[i], path[i + 1]
            local seg = Math:GetDistance(a, b)
            if remain <= seg then
                local dir = Math:Normalized(b, a)
                if dir then
                    return Math:Extended(a, dir, remain)
                end
            end
            remain = remain - seg
        end
        return path[#path]
    end
    
    -- Use smoothed velocity
    if data.smoothedVelocity then
        local vel = data.smoothedVelocity
        local velMag = math_sqrt(vel.x * vel.x + vel.z * vel.z)
        
        if velMag > 50 then
            return {
                x = currentPos.x + vel.x * time,
                z = currentPos.z + vel.z * time
            }
        end
    end
    
    return currentPos
end

function UnitTracker:OrbwalkPrediction(unit, data, currentPos, time)
    -- Orbwalking: predict they'll stop soon, then move again
    local currentTime = Game.Timer()
    local timeSinceStart = currentTime - data.lastMoveStartTime
    local avgClickInterval = data.clickInterval
    
    if avgClickInterval > 0 then
        local cyclePosition = timeSinceStart % avgClickInterval
        local remainingInCycle = avgClickInterval - cyclePosition
        
        if time < remainingInCycle then
            -- Still in current move phase
            return self:LinearPrediction(unit, data, currentPos, time)
        else
            -- Will likely stop, use shorter prediction
            return self:LinearPrediction(unit, data, currentPos, remainingInCycle * 0.8)
        end
    end
    
    -- Fallback: shorter prediction for orbwalkers
    return self:LinearPrediction(unit, data, currentPos, time * 0.6)
end

function UnitTracker:KitingPrediction(unit, data, currentPos, time)
    -- Kiting: they move away but might change direction
    local vel = data.smoothedVelocity
    if not vel then return currentPos end
    
    -- Reduce prediction confidence for kiters
    local reducedTime = time * 0.75
    
    return {
        x = currentPos.x + vel.x * reducedTime,
        z = currentPos.z + vel.z * reducedTime
    }
end

function UnitTracker:ErraticPrediction(unit, data, currentPos, time)
    -- Erratic movement: use very short prediction
    local path = self:GetUnitPath(unit)
    
    if #path > 1 then
        -- Only predict to next waypoint
        local nextWp = path[2]
        local dist = Math:GetDistance(currentPos, nextWp)
        local ms = unit.ms or 400
        local timeToWp = dist / ms
        
        if time <= timeToWp then
            local dir = Math:Normalized(nextWp, currentPos)
            if dir then
                return Math:Extended(currentPos, dir, ms * time * 0.5)
            end
        end
    end
    
    -- Very conservative prediction
    local vel = data.smoothedVelocity
    if vel then
        return {
            x = currentPos.x + vel.x * time * 0.4,
            z = currentPos.z + vel.z * time * 0.4
        }
    end
    
    return currentPos
end

function UnitTracker:GetUnitPath(unit)
    local result = {Math:Get2D(unit.pos)}
    local path = unit.pathing
    
    if not path or not path.hasMovePath then
        return result
    end
    
    pcall(function()
        if path.isDashing and path.endPos then
            result[#result + 1] = Math:Get2D(path.endPos)
        elseif path.pathIndex and path.pathCount then
            for i = path.pathIndex, math_min(path.pathCount - 1, path.pathIndex + 3) do
                local wp = nil
                if path.GetWaypoint then
                    local ok, w = pcall(path.GetWaypoint, path, i)
                    if ok then wp = w end
                end
                if not wp and path[i] then wp = path[i] end
                if wp and wp.x then
                    result[#result + 1] = Math:Get2D(wp)
                end
            end
        end
    end)
    
    if #result == 1 and path.hasMovePath then
        local dir = Math:Get2D(unit.dir) or {x = 0, z = 1}
        result[#result + 1] = Math:Extended(result[1], dir, (unit.ms or 400) * 1.5)
    end
    
    return result
end

function UnitTracker:GetMovementInfo(unit)
    local id = unit.networkID
    local data = self.Units[id]
    if not data then return nil end
    
    return {
        type = data.movementType,
        confidence = data.movementConfidence,
        avgSpeed = data.avgSpeed,
        isOrbwalking = data.isOrbwalking,
        isKiting = data.isKiting,
        velocity = data.smoothedVelocity,
        direction = data.direction
    }
end

function UnitTracker:Cleanup()
    local now = Game.Timer()
    if now - self.LastCleanup < self.CleanupInterval then return end
    self.LastCleanup = now
    
    for id, data in pairs(self.Units) do
        if now - data.lastUpdate > 10 then
            self.Units[id] = nil
        end
    end
    
    if now - self.LastCacheUpdate > self.CacheUpdateInterval then
        self.MinionNameCache = {}
        self.LastCacheUpdate = now
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COLLISION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
local CollisionSystem = {}

function CollisionSystem:GetCollision(source, castPos, speed, delay, radius, collisionTypes, skipID)
    local source2D = Math:Get2D(source)
    local castPos2D = Math:Get2D(castPos)
    if not source2D or not castPos2D then return false, {}, 0 end
    
    local collisionObjects = {}
    local direction = Math:Normalized(castPos2D, source2D)
    
    if direction then
        source2D = Math:Extended(source2D, {x = -direction.x, z = -direction.z}, myHero.boundingRadius or 65)
        castPos2D = Math:Extended(castPos2D, direction, 75)
    end
    
    local objects = self:GetCollisionObjects(collisionTypes, skipID)
    local segLen = Math:GetDistance(source2D, castPos2D)
    local maxDistSqr = (segLen + (radius or 50) + 400) ^ 2
    
    for i = 1, #objects do
        local obj = objects[i]
        local objPos = obj.pos and Math:Get2D(obj.pos)
        
        if objPos then
            local dx = objPos.x - source2D.x
            local dz = objPos.z - source2D.z
            if dx * dx + dz * dz <= maxDistSqr then
                if self:WillCollide(source2D, castPos2D, obj, speed, delay, radius) then
                    collisionObjects[#collisionObjects + 1] = obj
                    if #collisionObjects >= 10 then break end
                end
            end
        end
    end
    
    return #collisionObjects > 0, collisionObjects, #collisionObjects
end

function CollisionSystem:GetCollisionObjects(collisionTypes, skipID)
    local objects = {}
    local flags = {}
    
    for i = 1, #collisionTypes do
        flags[collisionTypes[i]] = true
    end
    
    -- Minions
    if flags[COLLISION_MINION] or flags[COLLISION_ALLYMINION] or 
       flags[COLLISION_ENEMYMINION] or flags[COLLISION_NEUTRAL] then
        for i = 1, Game.MinionCount() do
            local m = Game.Minion(i)
            if m and m.valid and not m.dead and m.networkID ~= skipID then
                if flags[COLLISION_MINION] or
                   (flags[COLLISION_ALLYMINION] and m.isAlly) or
                   (flags[COLLISION_ENEMYMINION] and m.isEnemy) or
                   (flags[COLLISION_NEUTRAL] and not m.isAlly and not m.isEnemy) then
                    objects[#objects + 1] = m
                end
            end
        end
    end
    
    -- Heroes
    if flags[COLLISION_ALLYHERO] or flags[COLLISION_ENEMYHERO] then
        for i = 1, Game.HeroCount() do
            local h = Game.Hero(i)
            if h and h.valid and not h.dead and h.networkID ~= skipID then
                if (flags[COLLISION_ALLYHERO] and IsAllyUnit(h)) or
                   (flags[COLLISION_ENEMYHERO] and IsEnemyUnit(h)) then
                    objects[#objects + 1] = h
                end
            end
        end
    end
    
    -- Yasuo Wall
    if flags[COLLISION_YASUOWALL] then
        for i = 1, Game.ObjectCount() do
            local obj = Game.Object(i)
            if obj and obj.valid then
                local name = (obj.name and obj.name:lower()) or ""
                if name:find("yasuo") and (name:find("wall") or name:find("windwall")) then
                    objects[#objects + 1] = obj
                end
            end
        end
    end
    
    return objects
end

function CollisionSystem:WillCollide(source, castPos, object, speed, delay, radius)
    local objPos = Math:Get2D(object.pos)
    if not objPos then return false end
    
    local objName = (object.name and object.name:lower()) or ""
    if objName:find("yasuo") and objName:find("wall") then
        local wallDir = Math:Perpendicular(Math:Normalized(objPos, source) or {x = 1, z = 0})
        if wallDir then
            local wallStart = Math:Extended(objPos, wallDir, -400)
            local wallEnd = Math:Extended(objPos, wallDir, 400)
            return self:LinesIntersect(source, castPos, wallStart, wallEnd)
        end
        return false
    end
    
    local totalRadius = (radius or 50) + (object.boundingRadius or 65)
    local pointLine, isOnSeg = self:ClosestPointOnSegment(objPos, source, castPos)
    
    if isOnSeg and Math:IsInRange(objPos, pointLine, totalRadius) then
        return true
    end
    
    if object.pathing and object.pathing.hasMovePath then
        local timeToReach = Math:GetDistance(source, castPos) / speed + delay
        local predPos = UnitTracker:GetPredictedPosition(object, timeToReach)
        if predPos then
            pointLine, isOnSeg = self:ClosestPointOnSegment(predPos, source, castPos)
            if isOnSeg and Math:IsInRange(predPos, pointLine, totalRadius) then
                return true
            end
        end
    end
    
    return false
end

function CollisionSystem:ClosestPointOnSegment(p, p1, p2)
    if not p or not p1 or not p2 or not p.x then return p1, false end
    
    local bxax, bzaz = p2.x - p1.x, p2.z - p1.z
    local denom = bxax * bxax + bzaz * bzaz
    if denom < 0.0001 then return p1, false end
    
    local t = ((p.x - p1.x) * bxax + (p.z - p1.z) * bzaz) / denom
    
    if t < 0 then return p1, false
    elseif t > 1 then return p2, false
    else return {x = p1.x + t * bxax, z = p1.z + t * bzaz}, true
    end
end

function CollisionSystem:LinesIntersect(p1, p2, p3, p4)
    if not (p1 and p2 and p3 and p4 and p1.x) then return false end
    
    local function orient(p, q, r)
        local val = (q.z - p.z) * (r.x - q.x) - (q.x - p.x) * (r.z - q.z)
        return val > 0 and 1 or (val < 0 and 2 or 0)
    end
    
    return orient(p1, p2, p3) ~= orient(p1, p2, p4) and orient(p3, p4, p1) ~= orient(p3, p4, p2)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PREDICTION CORE (Enhanced)
-- ═══════════════════════════════════════════════════════════════════════════
local PredictionCore = {}

function PredictionCore:GetPrediction(target, source, speed, delay, radius, useAdvanced)
    useAdvanced = useAdvanced == nil or useAdvanced
    
    if not target or not target.valid or not source then
        return nil, nil, -1
    end
    
    UnitTracker:UpdateUnit(target)
    
    local sourcePos = Math:Get2D(source)
    local currentPos = Math:Get2D(target.pos)
    
    if not sourcePos or not currentPos then return nil, nil, -1 end
    if Math:GetDistance(sourcePos, currentPos) > 12000 then return nil, nil, -1 end
    
    local hasMovePath = target.pathing and target.pathing.hasMovePath or false
    
    -- Get map-specific settings
    local mapSettings = Math:GetPredictionSettings()
    local isArena = Math:IsArena()
    
    -- Static target
    if not hasMovePath then
        local dist = Math:GetDistance(sourcePos, currentPos)
        local timeToHit = delay + (speed == math_huge and 0 or dist / speed)
        return currentPos, currentPos, timeToHit
    end
    
    local totalDelay = delay + Menu:GetLatency() + Menu:GetExtraDelay()
    local maxPredTime = mapSettings.maxPredictionTime or 2.0
    totalDelay = math_min(totalDelay, maxPredTime)
    
    -- Get movement info for adjusted prediction
    local moveInfo = UnitTracker:GetMovementInfo(target)
    local movementAdjust = 1.0
    
    if moveInfo then
        if moveInfo.type == MOVEMENT_ORBWALK then
            movementAdjust = isArena and (mapSettings.orbwalkAdjustment or 0.55) or 0.7
        elseif moveInfo.type == MOVEMENT_ERRATIC then
            movementAdjust = isArena and (mapSettings.erraticAdjustment or 0.35) or 0.5
        elseif moveInfo.type == MOVEMENT_KITING then
            movementAdjust = isArena and (mapSettings.kitingAdjustment or 0.6) or 0.75
        end
    end
    
    -- Instant cast
    if speed == math_huge then
        local adjustedDelay = totalDelay * movementAdjust
        local predPos = UnitTracker:GetPredictedPosition(target, adjustedDelay)
        if not predPos then predPos = currentPos end
        
        local lead = mapSettings.leadFactor or Menu:GetLeadFactor()
        local maxLead = (target.ms or 400) * totalDelay * lead
        predPos = Math:ClampTowards(currentPos, predPos, maxLead)
        
        return predPos, predPos, totalDelay
    end
    
    -- Projectile prediction
    local isHero = target.type == Obj_AI_Hero
    
    if useAdvanced and isHero then
        local castPos, timeToHit = self:AdvancedProjectilePrediction(target, sourcePos, speed, totalDelay, radius, moveInfo)
        if castPos then
            return castPos, castPos, timeToHit
        end
    end
    
    -- Basic prediction
    local castPos, timeToHit = self:BasicProjectilePrediction(target, sourcePos, speed, totalDelay, radius)
    if castPos then
        return castPos, castPos, timeToHit
    end
    
    -- Fallback
    local dist = Math:GetDistance(sourcePos, currentPos)
    return currentPos, currentPos, totalDelay + dist / speed
end

function PredictionCore:AdvancedProjectilePrediction(target, source, speed, delay, radius, moveInfo)
    local currentPos = Math:Get2D(target.pos)
    local data = UnitTracker.Units[target.networkID]
    
    if not data or not data.smoothedVelocity then
        return self:BasicProjectilePrediction(target, source, speed, delay, radius)
    end
    
    -- Get map-specific prediction settings
    local mapSettings = Math:GetPredictionSettings()
    local isArena = Math:IsArena()
    
    -- Get velocity with movement type adjustment
    local vel = {x = data.smoothedVelocity.x, z = data.smoothedVelocity.z}
    local velMag = math_sqrt(vel.x * vel.x + vel.z * vel.z)
    
    -- Apply Arena speed multiplier if applicable
    if isArena and mapSettings.speedMultiplier then
        vel.x = vel.x * mapSettings.speedMultiplier
        vel.z = vel.z * mapSettings.speedMultiplier
        velMag = velMag * mapSettings.speedMultiplier
    end
    
    if velMag < 30 then
        local dist = Math:GetDistance(source, currentPos)
        return currentPos, delay + dist / speed
    end
    
    -- Adjust velocity based on movement type (use map-specific adjustments for Arena)
    local adjustment = 1.0
    if moveInfo then
        if moveInfo.type == MOVEMENT_ORBWALK then
            adjustment = isArena and (mapSettings.orbwalkAdjustment or 0.55) or 0.65
        elseif moveInfo.type == MOVEMENT_ERRATIC then
            adjustment = isArena and (mapSettings.erraticAdjustment or 0.35) or 0.45
        elseif moveInfo.type == MOVEMENT_KITING then
            adjustment = isArena and (mapSettings.kitingAdjustment or 0.6) or 0.7
        elseif moveInfo.confidence < 0.6 then
            adjustment = 0.75
        end
    end
    
    vel.x = vel.x * adjustment
    vel.z = vel.z * adjustment
    
    -- Apply lead factor (use map-specific if available)
    local lead = mapSettings.leadFactor or Menu:GetLeadFactor()
    vel.x = vel.x * lead
    vel.z = vel.z * lead
    
    -- Calculate intercept
    local intercept = Math:AdvancedIntercept(source, currentPos, vel, speed, delay)
    
    if intercept then
        -- Validate prediction (Arena has tighter bounds)
        local predDist = Math:GetDistance(currentPos, {x = intercept.x, z = intercept.z})
        local maxDistMult = isArena and 1.15 or 1.3
        local maxDist = (target.ms or 400) * intercept.time * maxDistMult
        
        if predDist <= maxDist then
            return {x = intercept.x, z = intercept.z}, intercept.time
        end
    end
    
    return self:BasicProjectilePrediction(target, source, speed, delay, radius)
end

function PredictionCore:BasicProjectilePrediction(target, source, speed, delay, radius)
    local path = UnitTracker:GetUnitPath(target)
    local ms = target.ms or 400
    local currentPos = Math:Get2D(target.pos)
    
    if #path <= 1 then
        local dist = Math:GetDistance(source, currentPos)
        return currentPos, delay + dist / speed
    end
    
    -- Cut path by delay
    local cutPath = self:CutPath(path, ms * delay)
    
    -- Find intercept on path
    local bestIntercept = nil
    local bestTime = math_huge
    local timeOffset = 0
    
    for i = 1, #cutPath - 1 do
        local a, b = cutPath[i], cutPath[i + 1]
        local segDist = Math:GetDistance(a, b)
        local segTime = segDist / ms
        
        local dir = Math:Normalized(b, a)
        if dir then
            local vel = {x = dir.x * ms, z = dir.z * ms}
            local intercept = Math:AdvancedIntercept(source, a, vel, speed, timeOffset)
            
            if intercept and intercept.time >= timeOffset and intercept.time <= timeOffset + segTime then
                if intercept.time < bestTime then
                    bestTime = intercept.time
                    bestIntercept = {x = intercept.x, z = intercept.z}
                end
            end
        end
        
        timeOffset = timeOffset + segTime
    end
    
    if bestIntercept then
        return bestIntercept, bestTime
    end
    
    local lastPos = cutPath[#cutPath]
    local dist = Math:GetDistance(source, lastPos)
    return lastPos, delay + dist / speed
end

function PredictionCore:CutPath(path, distance)
    if distance <= 0 or #path <= 1 then return path end
    
    local result = {}
    local remain = distance
    
    for i = 1, #path - 1 do
        local a, b = path[i], path[i + 1]
        local segDist = Math:GetDistance(a, b)
        
        if segDist > remain then
            local dir = Math:Normalized(b, a)
            if dir then
                result[#result + 1] = Math:Extended(a, dir, remain)
            end
            for j = i + 1, #path do
                result[#result + 1] = path[j]
            end
            break
        end
        remain = remain - segDist
    end
    
    return #result > 0 and result or {path[#path]}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SPELL PREDICTION API
-- ═══════════════════════════════════════════════════════════════════════════
function PredictionCore:SpellPrediction(args)
    local spell = {
        Type = args.Type or SPELLTYPE_LINE,
        Speed = args.Speed or math_huge,
        Range = args.Range or math_huge,
        Delay = args.Delay or 0,
        Radius = args.Radius or 1,
        Collision = args.Collision or false,
        MaxCollision = args.MaxCollision or 0,
        CollisionTypes = args.CollisionTypes or {COLLISION_MINION},
        UseBoundingRadius = args.UseBoundingRadius
    }
    
    if spell.UseBoundingRadius == nil and spell.Type == SPELLTYPE_LINE then
        spell.UseBoundingRadius = true
    end
    
    function spell:GetPrediction(target, source)
        local startClock = os_clock()
        
        if not target or not target.valid or not target.pos then
            return {
                HitChance = HITCHANCE_IMPOSSIBLE,
                CastPosition = nil,
                UnitPosition = nil,
                TimeToHit = 0,
                CollisionObjects = {}
            }
        end
        
        local source2D = Math:Get2D(source)
        local currentTargetPos = Math:Get2D(target.pos)
        
        if not source2D or not currentTargetPos then
            return {
                HitChance = HITCHANCE_IMPOSSIBLE,
                CastPosition = nil,
                UnitPosition = nil,
                TimeToHit = 0,
                CollisionObjects = {}
            }
        end
        
        -- Range check
        local maxRange = self.Range ~= math_huge and (self.Range * Menu:GetMaxRange() * 0.95) or math_huge
        if maxRange ~= math_huge then
            local effectiveRange = maxRange + (self.UseBoundingRadius and (target.boundingRadius or 0) or 0)
            if Math:GetDistanceSqr(source2D, currentTargetPos) > (effectiveRange + 1000) ^ 2 then
                return {
                    HitChance = HITCHANCE_IMPOSSIBLE,
                    CastPosition = nil,
                    UnitPosition = nil,
                    TimeToHit = 0,
                    CollisionObjects = {}
                }
            end
        end
        
        -- Get prediction
        local unitPosition, castPosition, timeToHit = PredictionCore:GetPrediction(
            target, source2D, self.Speed, self.Delay, self.Radius, true
        )
        
        if not unitPosition or not castPosition then
            local dist = Math:GetDistance(source2D, currentTargetPos)
            return {
                HitChance = HITCHANCE_LOW,
                CastPosition = currentTargetPos,
                UnitPosition = currentTargetPos,
                TimeToHit = self.Delay + (self.Speed == math_huge and 0 or dist / self.Speed),
                CollisionObjects = {}
            }
        end
        
        -- Validate prediction distance
        local distFromTarget = Math:GetDistance(currentTargetPos, castPosition)
        local maxReasonable = (target.ms or 400) * timeToHit * 1.3
        
        if distFromTarget > maxReasonable then
            castPosition = Math:ClampTowards(currentTargetPos, castPosition, maxReasonable)
            unitPosition = castPosition
        end
        
        -- Clamp to range
        if maxRange ~= math_huge then
            local effectiveRange = maxRange + (self.UseBoundingRadius and (target.boundingRadius or 0) or 0)
            local distFromMe = Math:GetDistance(source2D, castPosition)
            
            if distFromMe > effectiveRange then
                local dir = Math:Normalized(castPosition, source2D)
                if dir then
                    castPosition = Math:Extended(source2D, dir, effectiveRange * 0.95)
                end
            end
        end
        
        -- Calculate hitchance
        local hitChance = self:CalculateHitChance(target, castPosition, timeToHit)
        
        -- Range validation
        if maxRange ~= math_huge then
            local myPos2D = Math:Get2D(myHero.pos)
            local effectiveRange = maxRange + (self.UseBoundingRadius and (target.boundingRadius or 0) or 0)
            if not Math:IsInRange(myPos2D, castPosition, effectiveRange) then
                hitChance = HITCHANCE_IMPOSSIBLE
            end
        end
        
        -- Collision check
        local collisionObjects = {}
        if self.Collision and hitChance > HITCHANCE_COLLISION then
            local collTypes = self.CollisionTypes or {COLLISION_MINION}
            
            if self.Type == SPELLTYPE_LINE and Menu.YasuoWallDetection:Value() then
                local hasYasuo = false
                for i = 1, Game.HeroCount() do
                    local h = Game.Hero(i)
                    if h and h.valid and IsEnemyUnit(h) and 
                       (h.charName == "Yasuo" or h.charName == "Yone") then
                        hasYasuo = true
                        break
                    end
                end
                if hasYasuo then
                    local hasWall = false
                    for _, ct in ipairs(collTypes) do
                        if ct == COLLISION_YASUOWALL then hasWall = true break end
                    end
                    if not hasWall then collTypes[#collTypes + 1] = COLLISION_YASUOWALL end
                end
            end
            
            local _, collObjs, collCount = CollisionSystem:GetCollision(
                source2D, castPosition, self.Speed, self.Delay,
                self.Radius, collTypes, target.networkID
            )
            
            if collCount > self.MaxCollision then
                hitChance = HITCHANCE_COLLISION
                collisionObjects = collObjs
            end
        end
        
        -- Validate bounds (skip strict clamping for Arena - bounds may be inaccurate)
        if castPosition then
            local isArenaMap = Math:IsArenaInternal()
            if isArenaMap then
                -- For Arena, only reject clearly invalid positions
                if math_abs(castPosition.x) > 50000 or math_abs(castPosition.z) > 50000 then
                    castPosition = currentTargetPos  -- Fallback to target position
                end
            else
                local bounds = Math:GetMapBounds()
                castPosition.x = math_max(bounds.minX, math_min(bounds.maxX, castPosition.x))
                castPosition.z = math_max(bounds.minZ, math_min(bounds.maxZ, castPosition.z))
            end
        end
        
        -- FPS protection
        if os_clock() - startClock > 0.004 and hitChance > HITCHANCE_HIGH then
            hitChance = HITCHANCE_HIGH
        end
        
        return {
            HitChance = hitChance,
            CastPosition = castPosition,
            UnitPosition = unitPosition,
            TimeToHit = timeToHit,
            CollisionObjects = collisionObjects
        }
    end
    
    function spell:CalculateHitChance(target, castPosition, timeToHit)
        -- Get map-specific settings
        local mapSettings = Math:GetPredictionSettings()
        local isArena = Math:IsArena()
        local reactionTime = mapSettings.reactionTime or 0.15
        
        -- Special states
        local isImmobilized, immobileDur = IsImmobile(target)
        if isImmobilized and immobileDur >= timeToHit then
            return HITCHANCE_IMMOBILE
        end
        
        -- Dash check
        if target.pathing and target.pathing.isDashing then
            return HITCHANCE_VERYHIGH
        end
        
        -- Zhonya check
        pcall(function()
            if target.buffCount then
                for i = 0, target.buffCount do
                    local buff = target:GetBuff(i)
                    if buff and buff.name then
                        local name = buff.name:lower()
                        if name:find("zhonya") or name:find("stopwatch") then
                            return HITCHANCE_IMPOSSIBLE
                        end
                    end
                end
            end
        end)
        
        -- Not moving
        if not target.pathing or not target.pathing.hasMovePath then
            return HITCHANCE_VERYHIGH
        end
        
        -- Get movement analysis
        local moveInfo = UnitTracker:GetMovementInfo(target)
        local data = UnitTracker.Units[target.networkID]
        
        if moveInfo and data then
            local now = Game.Timer()
            
            -- Recently appeared (shorter window in Arena)
            local visibilityWindow = isArena and 0.3 or 0.5
            if data.wasVisible and (now - data.lastVisibleTime) < visibilityWindow then
                return HITCHANCE_NORMAL
            end
            
            -- Just started/stopped (tighter windows in Arena)
            local moveStartWindow = isArena and 0.08 or 0.12
            local stopWindow = isArena and 0.05 or 0.08
            if (now - data.lastMoveStartTime) < moveStartWindow or (now - data.lastStopTime) < stopWindow then
                return HITCHANCE_HIGH
            end
            
            -- Reaction time check (use map-specific reaction time)
            if timeToHit < reactionTime then
                return HITCHANCE_IMMOBILE
            end
            
            -- Movement type based hitchance (adjusted for Arena)
            if moveInfo.type == MOVEMENT_LINEAR and moveInfo.confidence > 0.75 then
                return HITCHANCE_VERYHIGH
            elseif moveInfo.type == MOVEMENT_ORBWALK then
                local threshold = isArena and 0.2 or 0.3
                return timeToHit < threshold and HITCHANCE_HIGH or HITCHANCE_NORMAL
            elseif moveInfo.type == MOVEMENT_ERRATIC then
                -- In Arena, erratic movement is common but still predictable at close range
                return HITCHANCE_LOW
            elseif moveInfo.type == MOVEMENT_KITING then
                return HITCHANCE_NORMAL
            end
            
            -- Speed-based hitchance
            if moveInfo.avgSpeed < 150 then
                return HITCHANCE_VERYHIGH
            elseif moveInfo.avgSpeed < 350 then
                return HITCHANCE_HIGH
            end
        end
        
        -- Sidestep model
        local ms = target.ms or 400
        local effectiveRadius = (self.Radius or 0) + (self.UseBoundingRadius and (target.boundingRadius or 0) or 0)
        local sidestepTime = effectiveRadius / ms
        
        -- Arena players tend to sidestep faster
        local sidestepMult = isArena and 0.85 or 1.0
        sidestepTime = sidestepTime * sidestepMult
        
        if timeToHit <= sidestepTime * 0.5 then return HITCHANCE_VERYHIGH
        elseif timeToHit <= sidestepTime * 0.8 then return HITCHANCE_HIGH
        elseif timeToHit <= sidestepTime * 1.2 then return HITCHANCE_NORMAL
        end
        
        return HITCHANCE_LOW
    end
    
    return spell
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════
local function ShouldTrackMinion(minion)
    local id = minion.networkID
    if UnitTracker.MinionNameCache[id] ~= nil then
        return UnitTracker.MinionNameCache[id]
    end
    
    local name = (minion.name and minion.name:lower()) or ""
    local charName = (minion.charName and minion.charName:lower()) or ""
    local shouldTrack = false
    
    if name:find("dragon") or name:find("baron") or name:find("herald") or
       charName:find("dragon") or charName:find("baron") or charName:find("herald") then
        shouldTrack = true
    elseif name:find("gromp") or name:find("krug") or name:find("blue") or name:find("red") then
        shouldTrack = true
    elseif not minion.isAlly and not minion.isEnemy then
        -- Track neutral minions in Arena (use direct arena check)
        shouldTrack = Math:IsArenaInternal()
    end
    
    UnitTracker.MinionNameCache[id] = shouldTrack
    return shouldTrack
end

Callback.Add("Tick", function()
    UpdateAutoSettings()
    
    -- Update all heroes every tick
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid then
            UnitTracker:UpdateUnit(hero)
        end
    end
    
    -- Update relevant minions every tick
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.valid and not minion.dead and ShouldTrackMinion(minion) then
            UnitTracker:UpdateUnit(minion)
        end
    end
    
    UnitTracker:Cleanup()
end)

-- Draw
if Menu and Menu.DrawPrediction then
    local MovementTypeNames = {
        [MOVEMENT_STATIC] = "Static",
        [MOVEMENT_LINEAR] = "Linear",
        [MOVEMENT_ORBWALK] = "Orbwalk",
        [MOVEMENT_KITING] = "Kiting",
        [MOVEMENT_ERRATIC] = "Erratic",
        [MOVEMENT_CHASE] = "Chase",
        [MOVEMENT_FLEE] = "Flee"
    }
    
    Callback.Add("Draw", function()
        if not Menu or not Menu.Enable or not Menu.Enable:Value() or not Menu.DrawPrediction:Value() then
            return
        end
        
        for i = 1, Game.HeroCount() do
            local enemy = Game.Hero(i)
            if enemy and enemy.valid and enemy.isEnemy and enemy.visible and not enemy.dead then
                local predPos = UnitTracker:GetPredictedPosition(enemy, 0.4)
                if not predPos then predPos = Math:Get2D(enemy.pos) end
                
                if predPos and predPos.x then
                    local height = enemy.pos.y or myHero.pos.y or 0
                    pcall(function()
                        if Game.TerrainHeight then
                            height = Game.TerrainHeight(predPos.x, predPos.z) or height
                        end
                    end)
                    
                    local pos3D = _G.Vector and Vector(predPos.x, height, predPos.z) or 
                                  {x = predPos.x, y = height, z = predPos.z}
                    
                    local ms = enemy.ms or 350
                    local radius = math_max(50, math_min(120, ms * 0.12))
                    
                    if _G.Draw and Draw.Circle then
                        local color = _G.Draw.Color and Draw.Color(255, 255, 220, 0) or 0xFFFFDC00
                        Draw.Circle(pos3D, radius, 2, color)
                        Draw.Circle(pos3D, 20, 1, color)
                    end
                    
                    if _G.Draw and Draw.Line then
                        local color = _G.Draw.Color and Draw.Color(150, 255, 255, 0) or 0x96FFFF00
                        Draw.Line(enemy.pos, pos3D, 1, color)
                    end
                    
                    -- Draw movement type
                    if Menu.DrawMovementType and Menu.DrawMovementType:Value() then
                        local moveInfo = UnitTracker:GetMovementInfo(enemy)
                        if moveInfo and _G.Draw and Draw.Text then
                            local screenPos = enemy.pos:To2D()
                            if screenPos then
                                local typeName = MovementTypeNames[moveInfo.type] or "Unknown"
                                Draw.Text(typeName, 14, screenPos.x - 30, screenPos.y + 30, 
                                    _G.Draw.Color and Draw.Color(255, 255, 255, 255) or 0xFFFFFFFF)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GLOBAL API
-- ═══════════════════════════════════════════════════════════════════════════
_G.DepressivePrediction = {
    -- Constants
    COLLISION_MINION = COLLISION_MINION,
    COLLISION_ALLYHERO = COLLISION_ALLYHERO,
    COLLISION_ENEMYHERO = COLLISION_ENEMYHERO,
    COLLISION_YASUOWALL = COLLISION_YASUOWALL,
    COLLISION_NEUTRAL = COLLISION_NEUTRAL,
    COLLISION_ALLYMINION = COLLISION_ALLYMINION,
    COLLISION_ENEMYMINION = COLLISION_ENEMYMINION,
    
    HITCHANCE_IMPOSSIBLE = HITCHANCE_IMPOSSIBLE,
    HITCHANCE_COLLISION = HITCHANCE_COLLISION,
    HITCHANCE_LOW = HITCHANCE_LOW,
    HITCHANCE_NORMAL = HITCHANCE_NORMAL,
    HITCHANCE_HIGH = HITCHANCE_HIGH,
    HITCHANCE_VERYHIGH = HITCHANCE_VERYHIGH,
    HITCHANCE_IMMOBILE = HITCHANCE_IMMOBILE,
    
    SPELLTYPE_LINE = SPELLTYPE_LINE,
    SPELLTYPE_CIRCLE = SPELLTYPE_CIRCLE,
    SPELLTYPE_CONE = SPELLTYPE_CONE,
    
    -- Movement types (for external use)
    MOVEMENT_STATIC = MOVEMENT_STATIC,
    MOVEMENT_LINEAR = MOVEMENT_LINEAR,
    MOVEMENT_ORBWALK = MOVEMENT_ORBWALK,
    MOVEMENT_KITING = MOVEMENT_KITING,
    MOVEMENT_ERRATIC = MOVEMENT_ERRATIC,
    
    Version = Version,
    Menu = Menu,
    
    -- Main API
    GetPrediction = function(target, source, speed, delay, radius)
        if not target or not target.valid or not target.pos then
            return nil, nil, -1
        end
        
        if type(source) == "table" and speed == nil then
            local cfg = source
            local stype = cfg.type or cfg.Type or "linear"
            local src = (cfg.source and (cfg.source.pos or cfg.source)) or myHero or target
            
            local pred = PredictionCore:SpellPrediction({
                Type = (stype == "linear" and SPELLTYPE_LINE) or 
                       (stype == "circular" and SPELLTYPE_CIRCLE) or 
                       (stype == "cone" and SPELLTYPE_CONE) or SPELLTYPE_LINE,
                Speed = cfg.speed or math_huge,
                Range = cfg.range or math_huge,
                Delay = cfg.delay or 0,
                Radius = cfg.radius or 0,
                Collision = cfg.collision or cfg.coll or false,
                CollisionTypes = cfg.collisionTypes or {COLLISION_MINION},
                UseBoundingRadius = cfg.useBoundingRadius
            })
            
            local pr = pred:GetPrediction(target, src)
            return {
                castPos = pr.CastPosition,
                unitPos = pr.UnitPosition,
                hitChance = pr.HitChance,
                timeToHit = pr.TimeToHit,
                collision = pr.CollisionObjects
            }
        end
        
        local source2D = Math:Get2D(source)
        if not source2D then return nil, nil, -1 end
        
        return PredictionCore:GetPrediction(target, source2D, speed, delay, radius, true)
    end,
    
    GetCollision = function(source, castPos, speed, delay, radius, collisionTypes, skipID)
        local source2D = Math:Get2D(source)
        local castPos2D = Math:Get2D(castPos)
        if not source2D or not castPos2D then return false, {}, 0 end
        return CollisionSystem:GetCollision(source2D, castPos2D, speed, delay, radius, collisionTypes, skipID)
    end,
    
    SpellPrediction = function(args)
        return PredictionCore:SpellPrediction(args)
    end,
    
    GetDistance = function(p1, p2)
        local pos1 = Math:Get2D(p1)
        local pos2 = Math:Get2D(p2)
        if not pos1 or not pos2 then return math_huge end
        return Math:GetDistance(pos1, pos2)
    end,
    
    IsInRange = function(p1, p2, range)
        local pos1 = Math:Get2D(p1)
        local pos2 = Math:Get2D(p2)
        return Math:IsInRange(pos1, pos2, range)
    end,
    
    GetUnitData = function(unit)
        return UnitTracker.Units[unit.networkID]
    end,
    
    GetPredictedPosition = function(unit, time)
        return UnitTracker:GetPredictedPosition(unit, time or 0.5)
    end,
    
    GetMovementInfo = function(unit)
        return UnitTracker:GetMovementInfo(unit)
    end,
    
    Get2D = function(pos)
        return Math:Get2D(pos)
    end,
    
    IsEnemyUnit = IsEnemyUnit,
    IsAllyUnit = IsAllyUnit,
    
    IsNeutralTarget = function(unit)
        if not unit or not unit.valid then return false end
        local lc = (unit.charName and unit.charName:lower()) or ""
        local ln = (unit.name and unit.name:lower()) or ""
        local isNeutralFlag = not unit.isAlly and not unit.isEnemy
        
        local byName, nType, pr = IdentifyNeutralByName(lc)
        if not byName then byName, nType, pr = IdentifyNeutralByName(ln) end
        
        if isNeutralFlag or byName then
            if nType == "epic" then return true, "epic" end
            if nType == "buff" then return true, "jungle" end
            if nType == "camp" then return true, "jungle" end
            if nType == "neutral" then return true, "neutral" end
            
            -- Use direct arena check instead of bounds
            if Math:IsArenaInternal() then return true, "arena_neutral" end
            return true, "neutral"
        end
        return false, "not_neutral"
    end,
    
    GetMapInfo = function()
        local mapData = Math:GetMapData()
        local bounds = Math:GetMapBounds()
        local mapID = Game.mapID or 0
        
        _G.MapType = mapData.name
        _G.CurrentMapType = mapData.name
        
        return {
            mapID = mapID,
            mapName = mapData.name,
            mapType = mapData.name:lower():gsub(" ", "_"):gsub("'", ""),
            bounds = bounds,
            center = mapData.center,
            isArena = Math:IsArena(),
            isARAM = Math:IsARAM(),
            predictionSettings = mapData.predictionSettings
        }
    end,
    
    -- Map-specific functions
    IsArena = function()
        return Math:IsArena()
    end,
    
    IsARAM = function()
        return Math:IsARAM()
    end,
    
    GetMapCenter = function()
        return Math:GetMapCenter()
    end,
    
    GetPredictionSettings = function()
        return Math:GetPredictionSettings()
    end,
    
    GetEffectiveRange = function(baseRange, target, useBoundingRadius)
        if Menu and Menu.GetEffectiveRange then
            return Menu:GetEffectiveRange(baseRange, target, useBoundingRadius)
        end
        local rangeFactor = Menu and Menu:GetMaxRange() or 1
        local effective = baseRange * rangeFactor
        if useBoundingRadius and target and target.boundingRadius then
            effective = effective + target.boundingRadius
        end
        return effective * 0.95
    end,
    
    IsInEffectiveRange = function(source, target, baseRange, useBoundingRadius)
        if not source or not target or not source.pos or not target.pos then return false end
        local effectiveRange = _G.DepressivePrediction.GetEffectiveRange(baseRange, target, useBoundingRadius)
        local source2D = Math:Get2D(source.pos)
        local target2D = Math:Get2D(target.pos)
        if not source2D or not target2D then return false end
        return Math:GetDistanceSqr(source2D, target2D) <= effectiveRange * effectiveRange
    end,
}

-- Print map info on load
local mapData = Math:GetMapData()
local mapBounds = Math:GetMapBounds()
print("DepressivePrediction v" .. Version .. " (Precision) loaded!")
print("  - Map detected: " .. mapData.name)
if mapData.name == "Arena" then
    print("  - Arena mode: Dynamic bounds enabled")
    if mapBounds.isDynamic then
        print("  - Bounds: Dynamic (hero-based)")
    else
        print("  - Bounds: Default (will adapt)")
    end
end

return _G.DepressivePrediction
