local Version = 3.1
local __name__ = "DepressivePrediction"
local __version__ = Version

-- Autoupdate block (adapted from DepressiveOrbwalker.lua)
if _G.DepressivePredictionUpdate then
    return
end
_G.DepressivePredictionUpdate = {}
do
    function DepressivePredictionUpdate:__init()
        self.Callbacks = {}
    end

    function DepressivePredictionUpdate:DownloadFile(url, path)
        DownloadFileAsync(url, path, function() end)
    end

    function DepressivePredictionUpdate:Trim(s)
        local from = s:match("^%s*()")
        return from > #s and "" or s:match(".*%S", from)
    end

    function DepressivePredictionUpdate:ReadFile(path)
        local result = {}
        local file = io.open(path, "r")
        if file then
            for line in file:lines() do
                local str = self:Trim(line)
                if #str > 0 then
                    table.insert(result, str)
                end
            end
            file:close()
        end
        return result
    end

    function DepressivePredictionUpdate:New(args)
        local updater = {}
        function updater:__init()
            self.Step = 1
            self.Version = type(args.version) == "number" and args.version or tonumber(args.version)
            self.VersionUrl = args.versionUrl
            self.VersionPath = args.versionPath
            self.ScriptUrl = args.scriptUrl
            self.ScriptPath = args.scriptPath
            self.ScriptName = args.scriptName
            self.VersionTimer = GetTickCount()
            self:DownloadVersion()
        end
        function updater:DownloadVersion()
            if not FileExist(self.ScriptPath) then
                self.Step = 4
                DepressivePredictionUpdate:DownloadFile(self.ScriptUrl, self.ScriptPath)
                self.ScriptTimer = GetTickCount()
                return
            end
            DepressivePredictionUpdate:DownloadFile(self.VersionUrl, self.VersionPath)
        end
        function updater:OnTick()
            if self.Step == 0 then
                return
            end
            if self.Step == 1 then
                if GetTickCount() > self.VersionTimer + 1000 then
                    local response = DepressivePredictionUpdate:ReadFile(self.VersionPath)
                    if #response > 0 and tonumber(response[1]) > self.Version then
                        self.Step = 2
                        self.NewVersion = response[1]
                        DepressivePredictionUpdate:DownloadFile(self.ScriptUrl, self.ScriptPath)
                        self.ScriptTimer = GetTickCount()
                    else
                        self.Step = 3
                    end
                end
            end
            if self.Step == 2 then
                if GetTickCount() > self.ScriptTimer + 1000 then
                    self.Step = 0
                    print(
                        self.ScriptName
                            .. " - new update found! ["
                            .. tostring(self.Version)
                            .. " -> "
                            .. self.NewVersion
                            .. "] Please 2xf6!"
                    )
                end
                return
            end
            if self.Step == 3 then
                self.Step = 0
                return
            end
            if self.Step == 4 then
                if GetTickCount() > self.ScriptTimer + 1000 then
                    self.Step = 0
                    print(self.ScriptName .. " - downloaded! Please 2xf6!")
                end
            end
        end
        function updater:CanUpdate()
            local response = DepressivePredictionUpdate:ReadFile(self.VersionPath)
            return #response > 0 and tonumber(response[1]) > self.Version
        end
        updater:__init()
        table.insert(self.Callbacks, updater)
        return updater
    end
    DepressivePredictionUpdate:__init()
end

Callback.Add("Tick", function()
    for _, updater in ipairs(DepressivePredictionUpdate.Callbacks) do
        if updater.Step > 0 then
            updater:OnTick()
        end
    end
end)

if
    DepressivePredictionUpdate:New({
        version = __version__,
        scriptName = __name__,
        scriptPath = COMMON_PATH .. "DepressivePrediction.lua",
    scriptUrl = "https://raw.githubusercontent.com/DepressiveKyo/GoS/refs/heads/main/DepressivePrediction.lua",
        versionPath = COMMON_PATH .. "DepressivePrediction.version",
    versionUrl = "https://raw.githubusercontent.com/DepressiveKyo/GoS/refs/heads/main/DepressivePrediction.version",
    }):CanUpdate()
then
    return
end

if _G.DepressivePrediction then return end

local Game = _G.Game
local Callback = _G.Callback
local myHero = _G.myHero

local math_sqrt, math_abs, math_min, math_max = math.sqrt, math.abs, math.min, math.max
local math_huge = math.huge

-- Constants (kept for compatibility with existing champion scripts)
local HITCHANCE_IMPOSSIBLE = 0
local HITCHANCE_COLLISION = 1
local HITCHANCE_LOW = 2
local HITCHANCE_NORMAL = 3
local HITCHANCE_HIGH = 4
local HITCHANCE_VERYHIGH = 5
local HITCHANCE_IMMOBILE = 6

local SPELLTYPE_LINE   = 0
local SPELLTYPE_CIRCLE = 1
local SPELLTYPE_CONE   = 2

local COLLISION_MINION       = 0
local COLLISION_ALLYHERO     = 1
local COLLISION_ENEMYHERO    = 2
local COLLISION_YASUOWALL    = 3 -- (not simulated, reserved)
local COLLISION_NEUTRAL      = 4
local COLLISION_ALLYMINION   = 5
local COLLISION_ENEMYMINION  = 6

-- Buff types considered hard CC / immobile (superset for safety)
local CC_TYPES = {
    [5]=true,  -- Stun
    [8]=true,  -- Taunt
    [9]=true,  -- Polymorph (engine dependent)
    [11]=true, -- Snare / Root
    [21]=true, -- Fear
    [22]=true, -- Charm
    [24]=true, -- Suppression
    [28]=true, -- Sleep
    [29]=true, -- Stasis
    [30]=true, -- Knockback (treated as immobilized while airborne)
    [31]=true, -- Knockup
    [39]=true, -- Knockup (alt)
}

local Menu = nil
do
    local ok, err = pcall(function()
        if _G.MenuElement then
            local root = MenuElement({name = "Depressive Prediction", id = "DepressivePrediction", type = _G.MENU})
            Menu = {
                Root = root,
                Enable = root:MenuElement({id = "Enable", name = "Enable Prediction", value = true}),
                MaxRange = root:MenuElement({id = "MaxRange", name = "Max Range %", value = 100, min = 70, max = 100, step = 1}),
                Latency = root:MenuElement({id = "Latency", name = "Ping/Latency (ms) [0=Auto]", value = 0, min = 0, max = 200, step = 5}),
                ExtraDelay = root:MenuElement({id = "ExtraDelay", name = "Extra Delay (ms)", value = 60, min = 0, max = 200, step = 5}),
                LeadFactor = root:MenuElement({id = "LeadFactor", name = "Lead Factor %", value = 100, min = 25, max = 120, step = 5}),
                Collision = root:MenuElement({id = "Collision", name = "Check Minion Collision", value = true}),
                HitchanceBias = root:MenuElement({id = "HitchanceBias", name = "Hitchance Bias (-1/+1)", value = 0, min = -1, max = 1, step = 1}),
                DrawStatus = root:MenuElement({id = "DrawStatus", name = "Draw Status", value = true}),
                DashPrediction = root:MenuElement({id = "DashPrediction", name = "Dash Prediction", value = true}),
                ZhonyaDetection = root:MenuElement({id = "ZhonyaDetection", name = "Detect Stasis (Zhonya / GA)", value = true}),
                YasuoWallDetection = root:MenuElement({id = "YasuoWallDetection", name = "Check Yasuo Wall", value = true}),
                ShowVisuals = root:MenuElement({id = "ShowVisuals", name = "Show Tracking Visuals", value = false}),
                EdgeOnly = root:MenuElement({id = "EdgeOnly", name = "Require target near max range", value = true}),
                EdgePercent = root:MenuElement({id = "EdgePercent", name = "Edge range % threshold", value = 90, min = 70, max = 100, step = 1}),
                VersionA = root:MenuElement({name = '', type = _G.SPACE, id = 'VersionSpaceA'}),
                VersionB = root:MenuElement({name = 'Version  ' .. Version, type = _G.SPACE, id = 'VersionSpaceB'}),
            }
            -- Alias for names used in code
            Menu.HCBias = Menu.HitchanceBias
        end
    end)
    if not ok then print("[DepressivePrediction] Menu creation failed: "..tostring(err)) end
end

local function SafePos(obj)
    if not obj then return nil end
    if obj.pos and obj.pos.x then return obj.pos end
    if obj.x and obj.z then return obj end
    return nil
end

local function DistanceSqr(a,b)
    if not a or not b then return math_huge end
    local dx = a.x - b.x
    local dz = a.z - b.z
    return dx*dx + dz*dz
end

local function Distance(a,b)
    local d2 = DistanceSqr(a,b)
    if d2 == math_huge then return math_huge end
    return math_sqrt(d2)
end

local function IsValidTarget(t)
    return t and t.valid and not t.dead and t.visible and t.isTargetable and t.pos and t.pos.x
end

local function IsImmobile(unit)
    if not unit or not unit.buffCount then return false end
    local now = Game.Timer()
    for i=0, unit.buffCount do
        local b = unit:GetBuff(i)
        if b and b.count > 0 and b.expireTime > now and b.startTime <= now and CC_TYPES[b.type] then
            return true, b.expireTime - now
        end
    end
    return false, 0
end

-- Basic line projection for collision
local function VectorPointProjectionOnLineSegment(v1,v2,v)
    local cx,cz,ax,az,bx,bz = v.x,v.z,v1.x,v1.z,v2.x,v2.z
    local rL = ((cx-ax)*(bx-ax)+(cz-az)*(bz-az)) / ((bx-ax)*(bx-ax)+(bz-az)*(bz-az)+1e-9)
    local pointLine = {x = ax + rL*(bx-ax), z = az + rL*(bz-az)}
    local rS = rL < 0 and 0 or (rL>1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS*(bx-ax), z = az + rS*(bz-az)}
    return pointSegment, pointLine, isOnSegment
end

local function CountLineMinionCollision(sourcePos, castPos, width, target)
    local count = 0
    for i=Game.MinionCount(),1,-1 do
        local m = Game.Minion(i)
        if m and m.valid and not m.dead and m.isTargetable and m.team ~= myHero.team and m ~= target then
            local mp = m.pos
            local pointSegment, _, isOnSegment = VectorPointProjectionOnLineSegment(sourcePos, castPos, mp)
            local rad = width + (m.boundingRadius or 45)
            if isOnSegment and DistanceSqr(pointSegment, mp) < rad*rad and DistanceSqr(sourcePos, castPos) > DistanceSqr(sourcePos, mp) then
                count = count + 1
            end
        end
    end
    return count
end

-- Analytic intercept for linear movement (adapted from Eternal Prediction)
local function LinearIntercept(source, origin, velocityVec, speed, delay)
    -- origin: current target pos, velocityVec: 2D velocity (units/sec)
    if speed <= 0 then return origin, delay end
    local sx, sz = source.x, source.z
    local ox, oz = origin.x, origin.z
    local vx, vz = velocityVec.x, velocityVec.z
    local dx, dz = ox - sx, oz - sz
    local a = vx*vx + vz*vz - speed*speed
    local b = 2*(vx*dx + vz*dz)
    local c = dx*dx + dz*dz
    local t = 0
    if math_abs(a) < 1e-6 then
        if math_abs(b) < 1e-6 then
            t = 0
        else
            t = -c / (b+1e-9)
        end
    else
        local disc = b*b - 4*a*c
        if disc < 0 then
            return origin, delay + Distance(source, origin)/speed
        end
        local sqrtDisc = math_sqrt(disc)
        local t1 = (-b + sqrtDisc)/(2*a)
        local t2 = (-b - sqrtDisc)/(2*a)
        t = math_min(t1,t2)
        if t < 0 then t = math_max(t1,t2) end
        if t < 0 then t = 0 end
    end
    local total = t + delay
    return {x = ox + vx*t, z = oz + vz*t}, total
end

-- SpellPrediction object
local SpellPred = {}
SpellPred.__index = SpellPred

function SpellPred:New(data)
    local o = setmetatable({}, self)
    o.Type = data.Type or SPELLTYPE_LINE
    o.Speed = data.Speed or math_huge
    o.Range = data.Range or 1200
    o.Delay = data.Delay or 0
    o.Radius = data.Radius or 50
    o.Collision = data.Collision or false
    o.CollisionTypes = data.CollisionTypes or { COLLISION_MINION }
    o.UseBoundingRadius = data.UseBoundingRadius ~= false
    -- runtime fields
    o.CastPosition = nil
    o.UnitPosition = nil
    o.HitChance = HITCHANCE_LOW
    o.TimeToHit = 0
    o.CollisionObjects = nil
    return o
end

local function ComputeCastPosition(self, target, source)
    local sourcePos = SafePos(source) or (myHero and myHero.pos)
    if not sourcePos then return end
    local tpos = target.pos
    local targetPosTo = target.posTo and (target.posTo.x~=0 or target.posTo.z~=0) and target.posTo or tpos
    local moving = (targetPosTo.x ~= tpos.x) or (targetPosTo.z ~= tpos.z)
    local ms = target.ms or 350
    local dir
    if moving then
        dir = {x = (targetPosTo.x - tpos.x), z = (targetPosTo.z - tpos.z)}
        local len = math_sqrt(dir.x*dir.x + dir.z*dir.z)
        if len > 0 then dir.x, dir.z = dir.x/len, dir.z/len else moving = false end
    end
    local immobile, immobileTime = IsImmobile(target)

    -- Base predicted position
    local castPos
    local travelTime = 0
    -- Apply menu extra delay
    local extraDelay = 0
    if Menu and Menu.ExtraDelay then extraDelay = (Menu.ExtraDelay:Value() or 0) / 1000 end
    local baseDelay = self.Delay + extraDelay
    if immobile then
        castPos = {x = tpos.x, z = tpos.z}
    travelTime = baseDelay + (self.Speed==math_huge and 0 or Distance(sourcePos, castPos)/self.Speed)
        -- Adjust if immobile ends before projectile arrives: reduce hitchance
        if immobileTime < self.Delay then
            immobile = false -- treat as not fully immobile
        end
    elseif moving and self.Type ~= SPELLTYPE_CIRCLE then
        local velocity = {x = dir.x * ms, z = dir.z * ms}
        -- Lead factor scaling
        local leadFactor = 1
        if Menu and Menu.LeadFactor then leadFactor = (Menu.LeadFactor:Value() or 100)/100 end
        velocity.x = velocity.x * leadFactor
        velocity.z = velocity.z * leadFactor
        local intercept, total = LinearIntercept(sourcePos, tpos, velocity, (self.Speed==math_huge and 20000 or self.Speed), baseDelay)
        castPos = intercept
        travelTime = total
    else
        -- Stationary or circle skill -> simple lead = current position
        castPos = {x = tpos.x, z = tpos.z}
        travelTime = baseDelay + (self.Speed==math_huge and 0 or Distance(sourcePos, castPos)/self.Speed)
    end

    -- Clamp to range
    local range = self.Range
    -- ÉNFASIS MEJORADO: Aplicar rango del menú con validación robusta
    if Menu and Menu.MaxRange then 
        local menuRangeFactor = Menu:GetMaxRange()
        range = range * menuRangeFactor
        
        -- Debug: mostrar cuando se aplica el rango del menú
        if Menu.DrawStatus and Menu.DrawStatus:Value() then
            -- Solo mostrar en debug si está habilitado
        end
    end
    
    if Distance(sourcePos, castPos) > range then
        -- Bring inside range along line
        local sx,sz = sourcePos.x, sourcePos.z
        local dx,dz = castPos.x - sx, castPos.z - sz
        local dlen = math_sqrt(dx*dx + dz*dz)
        if dlen > 0 then
            local scale = (range-5)/dlen
            castPos.x = sx + dx*scale
            castPos.z = sz + dz*scale
        end
    end

    -- Set values
    self.CastPosition = castPos
    self.UnitPosition = {x = tpos.x, z = tpos.z}
    self.TimeToHit = travelTime

    -- Determine HitChance
    local hitchance = HITCHANCE_NORMAL
    if not moving then hitchance = HITCHANCE_HIGH end
    if immobile then hitchance = HITCHANCE_IMMOBILE end
    -- If far and long travel time reduce
    if travelTime > 1.0 and hitchance < HITCHANCE_IMMOBILE then
        hitchance = hitchance - 1
    end
    -- Edge-only requirement: force low hitchance if target isn't at required edge percentage of range
    if Menu and Menu.EdgeOnly and Menu.EdgeOnly:Value() then
        local pctNeeded = (Menu.EdgePercent and Menu.EdgePercent:Value() or 90) / 100
        local dist = Distance(sourcePos, {x = tpos.x, z = tpos.z})
        -- ÉNFASIS MEJORADO: Usar la función GetMaxRange para consistencia
        local effRange = self.Range * (Menu and Menu:GetMaxRange() or 1)
        if dist < effRange * pctNeeded then
            hitchance = HITCHANCE_LOW -- se verá como no casteable para lógicas que pidan >= normal
        end
    end
    self.HitChance = math_max(HITCHANCE_LOW, math_min(hitchance, HITCHANCE_IMMOBILE))

    -- Collision (only line spells)
    self.CollisionObjects = nil
    local collisionEnabled = self.Collision
    if Menu and Menu.Collision and not Menu.Collision:Value() then collisionEnabled = false end
    if collisionEnabled and self.Type == SPELLTYPE_LINE then
        local width = self.Radius
        local colCount = CountLineMinionCollision(sourcePos, castPos, width, target)
        if colCount > 0 then
            self.HitChance = HITCHANCE_COLLISION
            self.CollisionObjects = colCount
        end
    end

    -- Hitchance bias
    if Menu and Menu.HitchanceBias then
        local bias = Menu.HitchanceBias:Value() or 0
        if bias ~= 0 and self.HitChance ~= HITCHANCE_COLLISION then
            self.HitChance = math_max(HITCHANCE_LOW, math_min(self.HitChance + bias, HITCHANCE_IMMOBILE))
        end
    end
end

function SpellPred:GetPrediction(target, source)
    if not IsValidTarget(target) then return self end
    ComputeCastPosition(self, target, source or myHero)
    return self
end

-- Core functions (public API)
local DP = {}
DP.__index = DP

function DP:SpellPrediction(data)
    return SpellPred:New(data or {})
end

-- Overload-friendly static access too
local function SpellPredictionStatic(_, data) return SpellPred:New(data or {}) end

local function GetPredictionFunc(target, source, speed, delay, radius)
    if not IsValidTarget(target) then return nil,nil,-1 end
    local srcPos = SafePos(source) or (myHero and myHero.pos) or target.pos
    speed = speed or math_huge
    delay = delay or 0
    radius = radius or 50
    local temp = SpellPred:New({Type = SPELLTYPE_LINE, Speed = speed, Range = 2500, Delay = delay, Radius = radius, Collision=false})
    temp:GetPrediction(target, srcPos)
    return temp.UnitPosition, temp.CastPosition, temp.TimeToHit
end

-- Collision helper (currently only minion line collision)
local function GetCollision(source, castPos, speed, delay, radius, collisionTypes, skipID)
    local src = SafePos(source)
    local cp = SafePos(castPos)
    if not src or not cp then return false, {}, 0 end
    local width = radius or 50
    local count = CountLineMinionCollision(src, cp, width, nil)
    if count == 0 then return false, {}, 0 end
    return true, {count = count}, count
end

_G.DepressivePrediction = setmetatable({
    -- Constants
    HITCHANCE_IMPOSSIBLE=HITCHANCE_IMPOSSIBLE,
    HITCHANCE_COLLISION=HITCHANCE_COLLISION,
    HITCHANCE_LOW=HITCHANCE_LOW,
    HITCHANCE_NORMAL=HITCHANCE_NORMAL,
    HITCHANCE_HIGH=HITCHANCE_HIGH,
    HITCHANCE_VERYHIGH=HITCHANCE_VERYHIGH,
    HITCHANCE_IMMOBILE=HITCHANCE_IMMOBILE,
    SPELLTYPE_LINE=SPELLTYPE_LINE,
    SPELLTYPE_CIRCLE=SPELLTYPE_CIRCLE,
    SPELLTYPE_CONE=SPELLTYPE_CONE,
    COLLISION_MINION=COLLISION_MINION,
    COLLISION_ALLYHERO=COLLISION_ALLYHERO,
    COLLISION_ENEMYHERO=COLLISION_ENEMYHERO,
    COLLISION_YASUOWALL=COLLISION_YASUOWALL,
    COLLISION_NEUTRAL=COLLISION_NEUTRAL,
    COLLISION_ALLYMINION=COLLISION_ALLYMINION,
    COLLISION_ENEMYMINION=COLLISION_ENEMYMINION,
    -- Methods
    SpellPrediction = SpellPredictionStatic,
    GetPrediction = GetPredictionFunc,
    GetCollision = GetCollision,
    Version = Version,
    Menu = Menu,
}, DP)

print("DepressivePrediction v"..Version.." (mechanical) loaded")

-- Profile application logic
-- Runtime scaffolding (ensure required utility tables / helpers exist before usage)
local Math = _G.DepressivePredictionMath or {}
_G.DepressivePredictionMath = Math
local table_insert = table.insert
local math_min, math_max = math.min, math.max

-- Basic sanitization helper (no-op if already present later)
if not Math.SanitizePosition then
    function Math:SanitizePosition(pos) return pos end
end

-- Map bounds fallback (loose; will be overridden if later defined)
if not Math.GetMapBounds then
    function Math:GetMapBounds()
        return {minX = -2000, maxX = 16000, minZ = -2000, maxZ = 16000, maxDistance = 18000}
    end
end

-- Safeguard menu helper methods (added only if absent)
if Menu then
    if not Menu.GetLatency then
        function Menu:GetLatency()
            -- Prefer manual latency if > 0, else fallback to Game.Latency
            local manual = self.Latency and self.Latency.Value and (self.Latency:Value() or 0) or 0
            if manual and manual > 0 then
                return manual * 0.001
            end
            local ok, lat = pcall(function() return (Game and Game.Latency and Game.Latency() or 0) end)
            return (ok and lat or 0) * 0.001
        end
    end
    if not Menu.GetExtraDelay then
        function Menu:GetExtraDelay()
            return (self.ExtraDelay and (self.ExtraDelay:Value() or 0) or 0) / 1000
        end
    end
    if not Menu.GetLeadFactor then
        function Menu:GetLeadFactor()
            return (self.LeadFactor and (self.LeadFactor:Value() or 100) or 100)/100
        end
    end
    if not Menu.GetMaxRange then
        function Menu:GetMaxRange()
            -- ÉNFASIS MEJORADO: Asegurar que el rango del menú se lea correctamente
            local rangeValue = 100 -- valor por defecto
            if self.MaxRange and self.MaxRange.Value then
                rangeValue = self.MaxRange:Value() or 100
            elseif self.MaxRange then
                rangeValue = self.MaxRange or 100
            end
            
            -- Validar que el valor esté en el rango correcto
            rangeValue = math_max(60, math_min(100, rangeValue))
            
            -- Convertir a decimal (ej: 95% -> 0.95)
            return rangeValue / 100
        end
    end
    
    -- NUEVA FUNCIÓN: Obtener rango efectivo incluyendo bounding radius
    if not Menu.GetEffectiveRange then
        function Menu:GetEffectiveRange(baseRange, target, useBoundingRadius)
            local maxRangeFactor = self:GetMaxRange()
            local effectiveRange = baseRange * maxRangeFactor
            
            -- Agregar bounding radius si se especifica
            if useBoundingRadius and target and target.boundingRadius then
                effectiveRange = effectiveRange + target.boundingRadius
            end
            
            return effectiveRange
        end
    end
    
    if not Menu.GetReactionTime then
        function Menu:GetReactionTime()
            -- default reaction time (seconds) used in some hitchance logic
            return 0.15
        end
    end
    -- Add missing toggle entries if they were referenced later
    if Menu.Root then
        if not Menu.DashPrediction then Menu.DashPrediction = Menu.Root:MenuElement({id="DashPrediction", name="Dash Prediction", value = true}) end
        if not Menu.ZhonyaDetection then Menu.ZhonyaDetection = Menu.Root:MenuElement({id="ZhonyaDetection", name="Detect Stasis (Zhonya / GA)", value = true}) end
        if not Menu.YasuoWallDetection then Menu.YasuoWallDetection = Menu.Root:MenuElement({id="YasuoWallDetection", name="Check Yasuo Wall", value = true}) end
        if not Menu.ShowVisuals then Menu.ShowVisuals = Menu.Root:MenuElement({id="ShowVisuals", name="Show Tracking Visuals", value = false}) end
    end
end

-- Neutral name identifier fallback (simple heuristic) if missing
if not IdentifyNeutralByNameLower then
    function IdentifyNeutralByNameLower(name)
        if not name or name == "" then return false end
        local patterns = {
            {"dragon", "epic", 9}, {"baron", "epic", 10}, {"herald", "epic", 8},
            {"rift", "epic", 8}, {"scuttle", "neutral", 5}, {"crab", "neutral", 5},
            {"gromp", "camp", 4}, {"krug", "camp", 4}, {"murkwolf", "camp", 4}, {"razorbeak", "camp", 4},
            {"blue", "buff", 6}, {"red", "buff", 6}, {"buff", "buff", 6}, {"sru_", "camp", 4}
        }
        for _, p in ipairs(patterns) do
            if name:find(p[1]) then return true, p[2], p[3] end
        end
        return false
    end
end

-- Ally / enemy helpers fallback if absent
if not IsEnemyUnit then
    function IsEnemyUnit(u) return u and u.valid and u.isEnemy end
end
if not IsAllyUnit then
    function IsAllyUnit(u) return u and u.valid and u.isAlly end
end

local lastProfileIndex = Menu and Menu.Profile and Menu.Profile:Value() or 5
local applyingProfile = false
local function ApplyProfile(idx)
    if not Menu or applyingProfile then return end
    if idx == 5 then return end -- Custom
    applyingProfile = true
    -- Presets
    if idx == 1 then -- Long Range
        Menu.MaxRange:Value(95)
        Menu.ExtraDelay:Value(0)
        Menu.LeadFactor:Value(105) -- slightly more lead
        Menu.Collision:Value(true)
    if Menu.HCBias then Menu.HCBias:Value(1) end
        Menu.EdgeOnly:Value(true)
        Menu.EdgePercent:Value(92)
    elseif idx == 2 then -- All In
        Menu.MaxRange:Value(92)
        Menu.ExtraDelay:Value(0)
        Menu.LeadFactor:Value(90)
        Menu.Collision:Value(true)
    if Menu.HCBias then Menu.HCBias:Value(0) end
        Menu.EdgeOnly:Value(false)
        Menu.EdgePercent:Value(90)
    elseif idx == 3 then -- Melee (short skillshots / follow)
        Menu.MaxRange:Value(85)
        Menu.ExtraDelay:Value(0)
        Menu.LeadFactor:Value(80)
        Menu.Collision:Value(true)
    if Menu.HCBias then Menu.HCBias:Value(1) end
        Menu.EdgeOnly:Value(false)
        Menu.EdgePercent:Value(85)
    elseif idx == 4 then -- Semi-Melee (bruiser / mid range)
        Menu.MaxRange:Value(90)
        Menu.ExtraDelay:Value(0)
        Menu.LeadFactor:Value(88)
        Menu.Collision:Value(true)
    if Menu.HCBias then Menu.HCBias:Value(0) end
        Menu.EdgeOnly:Value(false)
        Menu.EdgePercent:Value(88)
    end
    applyingProfile = false
end

if Callback and Menu and Menu.Profile then
    Callback.Add("Tick", function()
        if not Menu.Enable or not Menu.Enable:Value() then return end
        local current = Menu.Profile:Value()
        if current ~= lastProfileIndex then
            ApplyProfile(current)
            lastProfileIndex = current
        end
    end)
end

-- Draw status
if Menu and Menu.DrawStatus then
    Callback.Add("Draw", function()
        if not Menu.Enable:Value() or not Menu.DrawStatus:Value() then return end
        -- ÉNFASIS MEJORADO: Mostrar información del rango del menú
        local rangeInfo = ""
        if Menu.MaxRange then
            local rangeValue = Menu.MaxRange:Value() or 100
            rangeInfo = string.format(" | Range: %d%%", rangeValue)
        end
        local txt = string.format("DepressivePrediction v%.1f | Delay+%.0fms | Lead %d%%%s", 
            Version, (Menu.ExtraDelay:Value() or 0), (Menu.LeadFactor:Value() or 100), rangeInfo)
        if _G.Draw and Draw.Text then
            Draw.Text(txt, 14, 40, 420, _G.Draw.Color(255,255,255,0))
        elseif Draw and Draw.Text then
            Draw.Text(txt, 14, 40, 420, 0xFFFFFFFF)
        end
    end)
end

function Math:Get2D(p)
    -- Asegurar que obtenemos la posición correcta del objeto, no del mouse
    if not p then return nil end
    
    -- Si es un objeto con .pos, usar .pos
    local actualPos = p
    if p.pos and p.pos.x then
        actualPos = p.pos
    elseif p.x then
        actualPos = p
    else
        return nil
    end
    
    local pos2D = { 
        x = actualPos.x, 
        z = actualPos.z or actualPos.y or 0 
    }
    
    -- Usar un límite extremo grande, independiente del tamaño del mapa para no fallar en Arena
    local extremeLimit = 50000
    if pos2D.x > extremeLimit or pos2D.x < -extremeLimit or 
       pos2D.z > extremeLimit or pos2D.z < -extremeLimit then
        return nil
    end
    
    -- Sanear la posición antes de devolverla
    return self:SanitizePosition(pos2D)
end

-- FUNCIÓN Get3D ELIMINADA - TODO EN 2D

function Math:GetDistance(p1, p2)
    -- Robust guard: return huge if any input is invalid
    if not p1 or not p2 then return math_huge end
    if not p1.x or not p1.z or not p2.x or not p2.z then return math_huge end
    local dx = p2.x - p1.x
    local dz = p2.z - p1.z
    local d2 = dx * dx + dz * dz
    if d2 <= 0 then return 0 end
    return math_sqrt(d2)
end

-- Distancia al cuadrado (evita sqrt) para comparaciones rápidas
function Math:GetDistanceSqr(p1, p2)
    if not p1 or not p2 or not p1.x or not p1.z or not p2.x or not p2.z then return math_huge end
    local dx = p2.x - p1.x
    local dz = p2.z - p1.z
    return dx * dx + dz * dz
end

-- FUNCIÓN GetDistance3D ELIMINADA - TODO EN 2D

function Math:IsInRange(p1, p2, range)
    if not p1 or not p2 or not p1.x or not p1.z or not p2.x or not p2.z then
        return false
    end
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return dx * dx + dz * dz <= range * range
end

function Math:VectorsEqual(p1, p2, tolerance)
    tolerance = tolerance or 5
    return self:GetDistance(p1, p2) < tolerance
end

function Math:Normalized(p1, p2)
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    local length = math_sqrt(dx * dx + dz * dz)
    if length > 0 then
        local inv = 1.0 / length
        return { x = dx * inv, z = dz * inv }
    end
    return nil
end

function Math:Normalize(vector)
    if not vector or not vector.x or not vector.z then return nil end
    local length = math_sqrt(vector.x * vector.x + vector.z * vector.z)
    if length > 0 then
        local inv = 1.0 / length
        return { x = vector.x * inv, z = vector.z * inv }
    end
    return nil
end

function Math:Extended(vec, dir, range)
    if dir == nil then return vec end
    return { x = vec.x + dir.x * range, z = vec.z + dir.z * range }
end

function Math:ClampTowards(current, predicted, maxDist)
    if not current or not predicted then return predicted end
    local dx = (predicted.x or 0) - (current.x or 0)
    local dz = (predicted.z or 0) - (current.z or 0)
    local d2 = dx*dx + dz*dz
    if d2 <= 0 then return predicted end
    local d = math_sqrt(d2)
    if d <= maxDist then return predicted end
    local scale = (maxDist > 0) and (maxDist / d) or 0
    return { x = current.x + dx * scale, z = current.z + dz * scale }
end

function Math:Perpendicular(dir)
    if dir == nil then return nil end
    return { x = -dir.z, z = dir.x }
end

-- Interpolación cúbica para movimiento más suave
function Math:CubicInterpolation(p0, p1, p2, p3, t)
    local a0, a1, a2, a3
    a0 = p3 - p2 - p0 + p1
    a1 = p0 - p1 - a0
    a2 = p2 - p0
    a3 = p1
    return a0 * t * t * t + a1 * t * t + a2 * t + a3
end

-- Predicción avanzada de intercepción optimizada para 2D
function Math:AdvancedIntercept(src, targetPos, targetVel, speed, delay)
    -- Asegurar que trabajamos en 2D y considerar el delay antes del lanzamiento
    local srcPos = self:Get2D(src)
    local tgtPos0 = self:Get2D(targetPos)
    local tgtVel = { x = targetVel.x or 0, z = targetVel.z or targetVel.y or 0 }

    if not srcPos or not tgtPos0 then return nil end

    -- Validar velocidades para evitar cálculos extremos (más permisivo)
    local velMagnitude = math_sqrt(tgtVel.x * tgtVel.x + tgtVel.z * tgtVel.z)
    if velMagnitude > 2200 then -- permitir dashes rápidos, filtrar valores absurdos
        return nil
    end

    local dly = delay or 0
    -- Avanzar la posición objetivo por el delay de salida
    local tgtPos = { x = tgtPos0.x + tgtVel.x * dly, z = tgtPos0.z + tgtVel.z * dly }

    local dx = tgtPos.x - srcPos.x
    local dz = tgtPos.z - srcPos.z
    local tvx = tgtVel.x
    local tvz = tgtVel.z

    -- Validar distancia inicial (más permisivo para SR y Arena)
    local initialDistance = math_sqrt(dx * dx + dz * dz)
    if initialDistance > 8000 then
        return nil
    end

    -- Ecuación cuadrática para el tiempo de vuelo después del delay
    local a = tvx * tvx + tvz * tvz - speed * speed
    local b = 2 * (tvx * dx + tvz * dz)
    local c = dx * dx + dz * dz

    -- Resolver de forma robusta, manejando el caso casi lineal cuando |a|≈0
    local tf = math_huge
    if math_abs(a) < 1e-9 then
        -- Caso degenerado: b*t + c = 0 -> t = -c / b
        if math_abs(b) > 1e-9 then
            local t = -c / b
            if t and t >= 0 then tf = t end
        else
            -- a≈0 y b≈0: si c≈0 ya estamos en el punto, usar t=0
            if math_abs(c) < 1e-6 then tf = 0 end
        end
    else
        local discriminant = b * b - 4 * a * c
        if discriminant < 0 then return nil end
        local sqrt_disc = math_sqrt(discriminant)
        local t1 = (-b - sqrt_disc) / (2 * a)
        local t2 = (-b + sqrt_disc) / (2 * a)
        if t1 and t1 >= 0 then tf = math_min(tf, t1) end
        if t2 and t2 >= 0 then tf = math_min(tf, t2) end
    end

    -- Rechazar tiempos imposibles o excesivos
    if tf == math_huge or tf > 5.0 then return nil end

    -- Tiempo total hasta el impacto
    local totalT = dly + tf

    -- Calcular posición de intercepción desde la posición original + velocidad * tiempo total
    local interceptX = tgtPos0.x + tgtVel.x * totalT
    local interceptZ = tgtPos0.z + tgtVel.z * totalT

    -- Validaciones suaves: evitar falsos negativos por límites demasiado estrictos
    -- Mantener solo un saneamiento básico de límites del mapa
    local bounds = self:GetMapBounds()
    interceptX = math_max(bounds.minX - 200, math_min(bounds.maxX + 200, interceptX))
    interceptZ = math_max(bounds.minZ - 200, math_min(bounds.maxZ + 200, interceptZ))

    return { x = interceptX, z = interceptZ, time = totalT }
end

-- Análisis de patrones de movimiento
function Math:AnalyzeMovementPattern(positions, timestamps)
    if #positions < 3 then return nil end
    
    local velocities = {}
    local accelerations = {}
    
    -- Calcular velocidades con validación
    for i = 2, #positions do
        local dt = timestamps[i] - timestamps[i-1]
        if dt > 0 and dt < 2.0 then -- Solo usar intervalos de tiempo razonables
            local dx = positions[i].x - positions[i-1].x
            local dz = positions[i].z - positions[i-1].z
            local distance = math_sqrt(dx * dx + dz * dz)
            
            -- Filtrar movimientos extremos (posibles teleports o errores)
            if distance < 1000 then -- Máximo 1000 unidades por update
                local vel = {
                    x = dx / dt,
                    z = dz / dt
                }
                
                -- Verificar que la velocidad sea razonable
                local velMagnitude = math_sqrt(vel.x * vel.x + vel.z * vel.z)
                if velMagnitude < 800 then -- Velocidad máxima razonable
                    table_insert(velocities, vel)
                end
            end
        end
    end
    
    -- Si no hay suficientes velocidades válidas
    if #velocities < 2 then return nil end
    
    -- Calcular aceleraciones con validación
    for i = 2, #velocities do
        local dt = timestamps[i+1] - timestamps[i]
        if dt > 0 and dt < 2.0 then
            local dvx = velocities[i].x - velocities[i-1].x
            local dvz = velocities[i].z - velocities[i-1].z
            
            local acc = {
                x = dvx / dt,
                z = dvz / dt
            }
            
            -- Verificar que la aceleración sea razonable
            local accMagnitude = math_sqrt(acc.x * acc.x + acc.z * acc.z)
            if accMagnitude < 2000 then -- Aceleración máxima razonable
                table_insert(accelerations, acc)
            end
        end
    end
    
    -- Calcular promedios filtrados
    local avgVelocity = self:AverageVector(velocities)
    local avgAcceleration = self:AverageVector(accelerations)
    
    -- Validar promedios finales
    local avgVelMagnitude = math_sqrt(avgVelocity.x * avgVelocity.x + avgVelocity.z * avgVelocity.z)
    if avgVelMagnitude > 600 then -- Si el promedio es muy alto, reducirlo
        local factor = 600 / avgVelMagnitude
        avgVelocity.x = avgVelocity.x * factor
        avgVelocity.z = avgVelocity.z * factor
    end
    
    return {
        velocities = velocities,
        accelerations = accelerations,
        avgVelocity = avgVelocity,
        avgAcceleration = avgAcceleration
    }
end

function Math:AverageVector(vectors)
    if #vectors == 0 then return {x = 0, z = 0} end
    
    -- Ponderar más los últimos valores para mayor reactividad
    local sumX, sumZ, weightSum = 0, 0, 0
    for i = 1, #vectors do
        local w = 0.5 + (i / #vectors) -- peso lineal creciente
        sumX = sumX + vectors[i].x * w
        sumZ = sumZ + vectors[i].z * w
        weightSum = weightSum + w
    end
    return { x = sumX / weightSum, z = sumZ / weightSum }
end

-- Sistema de seguimiento de unidades mejorado
local UnitTracker = {
    Units = {},
    MaxHistorySize = 15,
    UpdateThreshold = 3  -- Umbral más bajo para tracking más preciso (ajustable)
}

-- Ajuste dinámico de thresholds según el mapa (arena requiere más precisión)
do
    local ok, bounds = pcall(function() return Math:GetMapBounds() end)
    if ok and bounds and bounds.maxDistance then
        if bounds.maxDistance <= 3000 then
            UnitTracker.UpdateThreshold = 2
            UnitTracker.MaxHistorySize = 24
        else
            UnitTracker.UpdateThreshold = 3
            UnitTracker.MaxHistorySize = 18
        end
    end
end

function UnitTracker:UpdateUnit(unit)
    -- VALIDACIÓN CRÍTICA pero más permisiva
    if not unit or not unit.valid or not unit.pos or not unit.pos.x then
        return
    end
    
    local id = unit.networkID
    local currentTime = Game.Timer()
    local pos = Math:Get2D(unit.pos)
    
    -- SER MÁS PERMISIVO con las posiciones - solo filtrar extremos obvios
    if not pos or pos.x > 30000 or pos.x < -3000 or pos.z > 30000 or pos.z < -3000 then
        -- Si Math:Get2D falla, intentar crear posición manual
        pos = { x = unit.pos.x, z = unit.pos.z or unit.pos.y }
        
        -- Si aún está fuera de límites extremos, no actualizar
        if pos.x > 30000 or pos.x < -3000 or pos.z > 30000 or pos.z < -3000 then
            return
        end
    end
    
    if not self.Units[id] then
        self.Units[id] = {
            positions = {},
            timestamps = {},
            lastUpdate = currentTime,
            isVisible = unit.visible,
            wasVisible = unit.visible,
            lastVisibleTime = unit.visible and currentTime or 0,
            lastInvisibleTime = (not unit.visible) and currentTime or 0,
            lastMoveStartTime = unit.pathing and unit.pathing.hasMovePath and currentTime or 0,
            lastStopTime = (not (unit.pathing and unit.pathing.hasMovePath)) and currentTime or 0,
            movementPattern = nil,
            lastAnalysisTime = 0
        }
    end
    
    local unitData = self.Units[id]
    
    -- Actualizar posición con tracking más preciso
    local needInsert = true
    if #unitData.positions > 0 then
        local last = unitData.positions[#unitData.positions]
        local thresh = self.UpdateThreshold
        local threshSqr = thresh * thresh
        needInsert = Math:GetDistanceSqr(pos, last) > threshSqr
    end
    if needInsert then
        table_insert(unitData.positions, pos)
        table_insert(unitData.timestamps, currentTime)
        
        -- Mantener solo las últimas posiciones
        if #unitData.positions > self.MaxHistorySize then
            table.remove(unitData.positions, 1)
            table.remove(unitData.timestamps, 1)
        end
        
        -- Analizar patrón de movimiento con throttling para rendimiento
        if #unitData.positions >= 3 then
            local analyzeGap = 0.2
            if currentTime - (unitData.lastAnalysisTime or 0) >= analyzeGap then
                unitData.movementPattern = Math:AnalyzeMovementPattern(unitData.positions, unitData.timestamps)
                unitData.lastAnalysisTime = currentTime
            end
        end
    end
    
    -- Visibilidad: trackear cambios de estado con timestamps
    if unitData.wasVisible ~= unit.visible then
        if unit.visible then
            unitData.lastVisibleTime = currentTime
        else
            unitData.lastInvisibleTime = currentTime
        end
        unitData.wasVisible = unit.visible
    end

    -- Movimiento: detectar inicios y paradas
    local hasMovePath = unit.pathing and unit.pathing.hasMovePath or false
    if unitData._lastHasMovePath == nil then unitData._lastHasMovePath = hasMovePath end
    if unitData._lastHasMovePath ~= hasMovePath then
        if hasMovePath then
            unitData.lastMoveStartTime = currentTime
        else
            unitData.lastStopTime = currentTime
        end
        unitData._lastHasMovePath = hasMovePath
    end

    unitData.lastUpdate = currentTime
    unitData.isVisible = unit.visible
end

function UnitTracker:GetPredictedPosition(unit, time)
    local id = unit.networkID
    local unitData = self.Units[id]
    
    if not unitData or #unitData.positions < 2 then
        return Math:Get2D(unit.pos)
    end
    
    local currentPos = Math:Get2D(unit.pos)
    local currentTime = Game.Timer()
    
    -- Limitar tiempo de predicción para evitar posiciones extremas
    time = math_min(time, 2.0) -- Máximo 2 segundos de predicción
    
    -- NUEVA LÓGICA: Verificar si está haciendo dash
    local isDashing = false
    local dashEndPos = nil
    local dashEndTime = 0
    
    if Menu.DashPrediction:Value() then
        pcall(function()
            if unit.pathing and unit.pathing.isDashing then
                isDashing = true
                dashEndPos = unit.pathing.endPos
                -- Calcular tiempo restante del dash
                if dashEndPos then
                    local dashDistance = Math:GetDistance(currentPos, Math:Get2D(dashEndPos))
                    local dashSpeed = unit.pathing.dashSpeed or 1200 -- Velocidad típica de dash
                    dashEndTime = dashDistance / dashSpeed
                end
            end
        end)
    end
    
    -- Si está haciendo dash y el tiempo de predicción es mayor al tiempo del dash
    if isDashing and dashEndPos and time >= dashEndTime then
        local finalPos = Math:Get2D(dashEndPos)
        
        -- Si el dash termina antes de nuestro tiempo de predicción,
        -- predecir desde la posición final del dash
        if time > dashEndTime then
            local remainingTime = time - dashEndTime
            -- Asumir que se queda quieto después del dash (comportamiento común)
            return finalPos
        else
            -- El dash aún está en progreso, interpolar la posición
            local dashProgress = time / dashEndTime
            local interpolatedPos = {
                x = currentPos.x + (finalPos.x - currentPos.x) * dashProgress,
                z = currentPos.z + (finalPos.z - currentPos.z) * dashProgress
            }
            return interpolatedPos
        end
    end
    
    -- NUEVA LÓGICA: Verificar Zhonya's Hourglass
    local isInZhonyas = false
    local zhonyasEndTime = 0
    
    if Menu.ZhonyaDetection:Value() then
        pcall(function()
            if unit.buffCount then
                for i = 0, unit.buffCount do
                    local buff = unit:GetBuff(i)
                    if buff and buff.name then
                        local buffName = buff.name:lower()
                        -- Verificar buffs de invulnerabilidad (Zhonya's, GA, etc.)
                        if buffName:find("zhonya") or buffName:find("zhonyas") or 
                           buffName:find("chronoshift") or buffName:find("guardianangel") or
                           buffName:find("stopwatch") then
                            isInZhonyas = true
                            zhonyasEndTime = buff.duration or 2.5 -- Duración típica de Zhonya's
                            break
                        end
                    end
                end
            end
        end)
    end
    
    -- Si está en Zhonya's, no mover la predicción hasta que termine
    if isInZhonyas then
        if time < zhonyasEndTime then
            -- Está en Zhonya's, mantener posición actual
            return currentPos
        else
            -- Zhonya's terminará antes de nuestro tiempo de predicción
            -- Predecir movimiento normal después de que termine
            local remainingTime = time - zhonyasEndTime
            -- Usar predicción normal pero con tiempo reducido
            time = remainingTime
        end
    end
    
    -- Si la unidad no se está moviendo (y no está en dash)
    if not unit.pathing or not unit.pathing.hasMovePath then
        return currentPos
    end
    
    -- Si tiene path, proyectar a lo largo de los waypoints primero (más estable que promedio)
    if unit.pathing and unit.pathing.hasMovePath then
        local ms = unit.ms or 400
        local path = self:GetUnitPath(unit)
        if #path > 1 then
            local remain = ms * time
            local pos = { x = currentPos.x, z = currentPos.z }
            for i = 1, #path - 1 do
                local a, b = path[i], path[i + 1]
                local seg = Math:GetDistance(a, b)
                if remain <= seg then
                    local dir = Math:Normalized(b, a)
                    return Math:Extended(a, dir, remain)
                end
                remain = remain - seg
            end
            -- Si excede el path, retornar el último waypoint
            return path[#path]
        end
    end

    -- Usar patrón de movimiento si está disponible (más preciso)
    if unitData.movementPattern and unitData.movementPattern.avgVelocity then
        local vel = unitData.movementPattern.avgVelocity
        local acc = unitData.movementPattern.avgAcceleration or {x = 0, z = 0}
        
        -- Limitar velocidad para evitar predicciones extremas
        local velMagnitude = math_sqrt(vel.x * vel.x + vel.z * vel.z)
        if velMagnitude > 1000 then -- Velocidad demasiado alta, probablemente un error
            return currentPos
        end
        
        -- Predicción con aceleración limitada
        local predictedPos = {
            x = currentPos.x + vel.x * time + 0.5 * acc.x * time * time,
            z = currentPos.z + vel.z * time + 0.5 * acc.z * time * time
        }
        
        -- Validar que la predicción esté dentro de un rango razonable
        local maxDistance = (unit.ms or 400) * time + 200 -- Velocidad de movimiento + buffer
        local predictionDistance = Math:GetDistance(currentPos, predictedPos)
        
        if predictionDistance > maxDistance then
            -- Si la predicción está muy lejos, usar predicción simple
            local direction = Math:Normalized(predictedPos, currentPos)
            if direction then
                predictedPos = Math:Extended(currentPos, direction, maxDistance)
            else
                return currentPos
            end
        end
        
        return predictedPos
    end
    
    -- Predicción básica basada en dirección
    local ms = unit.ms or 400 -- Velocidad por defecto si no está disponible
    if ms > 0 then
        local unitDir = unit.dir
        if unitDir and unitDir.x then
            local dir2D = Math:Get2D(unitDir)
            local maxDistance = ms * time
            return Math:Extended(currentPos, dir2D, maxDistance)
        end
    end
    
    -- Fallback final: usar historial de posiciones para calcular velocidad
    if #unitData.positions >= 2 then
        local lastPos = unitData.positions[#unitData.positions]
        local prevPos = unitData.positions[#unitData.positions - 1]
        local lastTime = unitData.timestamps[#unitData.timestamps]
        local prevTime = unitData.timestamps[#unitData.timestamps - 1]
        
        local dt = lastTime - prevTime
        if dt > 0 and dt < 1.0 then -- Solo usar si el delta time es razonable
            local vel = {
                x = (lastPos.x - prevPos.x) / dt,
                z = (lastPos.z - prevPos.z) / dt
            }
            
            -- Limitar velocidad calculada
            local velMagnitude = math_sqrt(vel.x * vel.x + vel.z * vel.z)
            if velMagnitude < 1000 then -- Velocidad razonable
                local predictedPos = {
                    x = currentPos.x + vel.x * time,
                    z = currentPos.z + vel.z * time
                }
                
                -- Validar distancia de predicción
                local predictionDistance = Math:GetDistance(currentPos, predictedPos)
                local maxDistance = (unit.ms or 400) * time + 100
                
                if predictionDistance <= maxDistance then
                    return predictedPos
                end
            end
        end
    end
    
    return currentPos
end

function UnitTracker:GetUnitPath(unit)
    local result = { Math:Get2D(unit.pos) }
    local path = unit.pathing
    
    if not path or not path.hasMovePath then
        return result
    end
    
    -- Manejo seguro de diferentes APIs de pathing
    pcall(function()
        if path.isDashing then
            local endPos = path.endPos
            if endPos and endPos.x then
                table_insert(result, Math:Get2D(endPos))
            end
        else
            -- Intentar obtener waypoints de diferentes maneras
            local waypoints = {}
            
            -- Método 1: Usar GetWaypoints si existe
            if path.GetWaypoints and type(path.GetWaypoints) == "function" then
                local success, points = pcall(path.GetWaypoints, path)
                if success and points then
                    waypoints = points
                end
            
            -- Método 2: Usar waypoints directamente si existe
            elseif path.waypoints and type(path.waypoints) == "table" then
                waypoints = path.waypoints
            
            -- Método 3: Intentar iterar por índices
            elseif path.pathIndex and path.pathCount then
                local istart = path.pathIndex
                local iend = path.pathCount
                if istart and iend and istart >= 0 and iend <= 20 then
                    for i = istart, iend - 1 do
                        -- Intentar diferentes métodos para obtener waypoint
                        local waypoint = nil
                        
                        -- Método A: GetWaypoint
                        if path.GetWaypoint and type(path.GetWaypoint) == "function" then
                            local success, wp = pcall(path.GetWaypoint, path, i)
                            if success and wp then
                                waypoint = wp
                            end
                        end
                        
                        -- Método B: Acceso directo por índice
                        if not waypoint and path[i] then
                            waypoint = path[i]
                        end
                        
                        if waypoint and waypoint.x then
                            table_insert(waypoints, waypoint)
                        end
                    end
                end
            end
            
            -- Agregar waypoints válidos al resultado
            for _, waypoint in ipairs(waypoints) do
                if waypoint and waypoint.x then
                    table_insert(result, Math:Get2D(waypoint))
                end
            end
        end
    end)
    
    -- Si no pudimos obtener waypoints, usar una predicción simple basada en dirección
    if #result == 1 and unit.pathing.hasMovePath then
        local currentPos = Math:Get2D(unit.pos)
        local direction = Math:Get2D(unit.dir) or {x = 0, z = 1}
        local extendedPos = Math:Extended(currentPos, direction, unit.ms * 2) -- 2 segundos adelante
        table_insert(result, extendedPos)
    end
    
    return result
end

-- Sistema de colisiones mejorado
local CollisionSystem = {}

function CollisionSystem:GetCollision(source, castPos, speed, delay, radius, collisionTypes, skipID)
    local collisionObjects = {}
    local collisionCount = 0
    
    -- Trabajar completamente en 2D para mejor rendimiento
    local source2D = Math:Get2D(source)
    local castPos2D = Math:Get2D(castPos)
    if not source2D or not castPos2D then
        return false, {}, 0
    end
    
    -- Extender ligeramente la línea para mejor detección (en 2D)
    local direction = Math:Normalized(castPos2D, source2D)
    if direction then
        source2D = Math:Extended(source2D, { x = -direction.x, z = -direction.z }, myHero.boundingRadius)
        castPos2D = Math:Extended(castPos2D, direction, 75)
    end
    
    local objects = self:GetCollisionObjects(collisionTypes, skipID)
    local segLen = Math:GetDistance(source2D, castPos2D)
    
    for _, object in pairs(objects) do
        -- Pre-filtro rápido por distancia para rendimiento
        local objPos = object.pos and Math:Get2D(object.pos) or nil
        if objPos then
            local distSrc = Math:GetDistance(source2D, objPos)
            local padding = (radius or 50) + (object.boundingRadius or 65) + 300
            if distSrc > segLen + padding then
                goto continue_object
            end
        end

        if self:WillCollide(source2D, castPos2D, object, speed, delay, radius) then
            table_insert(collisionObjects, object)
            collisionCount = collisionCount + 1
        end
        ::continue_object::
    end
    
    -- Evitar ordenamiento para ahorrar CPU; no es necesario para lógica de colisión
    
    return false, collisionObjects, collisionCount
end

function CollisionSystem:GetCollisionObjects(collisionTypes, skipID)
    local objects = {}
    
    for _, colType in pairs(collisionTypes) do
        if colType == COLLISION_MINION then
            -- Incluir TODOS los minions (aliados, enemigos y neutrales)
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i)
                if minion and minion.valid and not minion.dead and minion.networkID ~= skipID then
                    table_insert(objects, minion)
                end
            end
        elseif colType == COLLISION_ALLYMINION then
            -- Solo minions aliados
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i)
                if minion and minion.valid and not minion.dead and minion.networkID ~= skipID then
                    if minion.isAlly then
                        table_insert(objects, minion)
                    end
                end
            end
        elseif colType == COLLISION_ENEMYMINION then
            -- Solo minions enemigos
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i)
                if minion and minion.valid and not minion.dead and minion.networkID ~= skipID then
                    if minion.isEnemy then
                        table_insert(objects, minion)
                    end
                end
            end
        elseif colType == COLLISION_NEUTRAL then
            -- Objetivos neutrales (jungla, monstruos épicos, etc.)
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i)
                if minion and minion.valid and not minion.dead and minion.networkID ~= skipID then
                    if not minion.isAlly and not minion.isEnemy then
                        table_insert(objects, minion)
                    else
                        -- Algunos engines marcan neutrales como ni ally/enemy, otros usan nombres
                        local lc = (minion.charName and minion.charName:lower()) or ""
                        local ln = (minion.name and minion.name:lower()) or ""
                        if IdentifyNeutralByNameLower(lc) or IdentifyNeutralByNameLower(ln) then
                            table_insert(objects, minion)
                        end
                    end
                end
            end
            -- También verificar objetos especiales por nombre con lookup robusto
            for i = 1, Game.ObjectCount() do
                local obj = Game.Object(i)
                if obj and obj.valid and not obj.dead and obj.networkID ~= skipID then
                    local lc = (obj.charName and obj.charName:lower()) or ""
                    local ln = (obj.name and obj.name:lower()) or ""
                    if IdentifyNeutralByNameLower(lc) or IdentifyNeutralByNameLower(ln) then
                        table_insert(objects, obj)
                    end
                end
            end
        elseif colType == COLLISION_ALLYHERO then
            for i = 1, Game.HeroCount() do
                local hero = Game.Hero(i)
                if hero and hero.valid and not hero.dead and IsAllyUnit(hero) and hero.networkID ~= skipID then
                    table_insert(objects, hero)
                end
            end
        elseif colType == COLLISION_ENEMYHERO then
            for i = 1, Game.HeroCount() do
                local hero = Game.Hero(i)
                if hero and hero.valid and not hero.dead and IsEnemyUnit(hero) and hero.networkID ~= skipID then
                    table_insert(objects, hero)
                end
            end
        elseif colType == COLLISION_YASUOWALL then
            -- NUEVA LÓGICA: Detectar muro de Yasuo
            for i = 1, Game.ObjectCount() do
                local obj = Game.Object(i)
                if obj and obj.valid then
                    -- Verificar si es muro de Yasuo
                    local objName = obj.name and obj.name:lower() or ""
                    if objName:find("yasuo") and (objName:find("wall") or objName:find("windwall")) then
                        table_insert(objects, obj)
                    end
                    
                    -- También verificar por charName para versiones alternativas
                    local charName = obj.charName and obj.charName:lower() or ""
                    if charName:find("yasuo") and charName:find("wall") then
                        table_insert(objects, obj)
                    end
                end
            end
        end
    end
    
    return objects
end

function CollisionSystem:WillCollide(source, castPos, object, speed, delay, radius)
    local objectPos = Math:Get2D(object.pos)
    
    -- LÓGICA ESPECIAL PARA MURO DE YASUO
    local objName = object.name and object.name:lower() or ""
    local charName = object.charName and object.charName:lower() or ""
    local isYasuoWall = (objName:find("yasuo") and objName:find("wall")) or 
                        (charName:find("yasuo") and charName:find("wall"))
    
    if isYasuoWall then
        -- Para el muro de Yasuo, necesitamos verificar si intersecta con la línea del proyectil
        -- El muro de Yasuo es típicamente una línea, no un punto circular
        
        -- Intentar obtener las dimensiones del muro
        local wallRadius = object.boundingRadius or 350 -- Radio típico del muro de Yasuo
        local wallWidth = 50 -- Ancho típico del muro
        
        -- Verificar si la línea del proyectil cruza el área del muro
        local pointLine, isOnSegment = self:ClosestPointOnLineSegment(objectPos, source, castPos)
        if isOnSegment and Math:IsInRange(objectPos, pointLine, wallRadius + radius) then
            return true
        end
        
        -- Verificación adicional para el muro de Yasuo usando geometría de línea
        -- El muro bloquea proyectiles que pasan a través de él
        local wallDirection = object.dir and Math:Get2D(object.dir) or {x = 1, z = 0}
        
        -- Crear puntos del extremo del muro
        local wallStart = Math:Extended(objectPos, wallDirection, -wallRadius)
        local wallEnd = Math:Extended(objectPos, wallDirection, wallRadius)
        
        -- Verificar si las líneas se intersectan
        if self:LinesIntersect(source, castPos, wallStart, wallEnd) then
            return true
        end
        
        return false
    end
    
    -- LÓGICA NORMAL PARA OTROS OBJETOS
    local totalRadius = radius + (object.boundingRadius or 65)
    
    -- Verificar colisión en posición actual
    local pointLine, isOnSegment = self:ClosestPointOnLineSegment(objectPos, source, castPos)
    if isOnSegment and Math:IsInRange(objectPos, pointLine, totalRadius) then
        return true
    end
    
    -- Verificar colisión con predicción de movimiento si el objeto se mueve
    if object.pathing and object.pathing.hasMovePath then
        local timeToReach = Math:GetDistance(source, castPos) / speed + delay
        local predictedPos = UnitTracker:GetPredictedPosition(object, timeToReach)
        
        pointLine, isOnSegment = self:ClosestPointOnLineSegment(predictedPos, source, castPos)
        if isOnSegment and Math:IsInRange(predictedPos, pointLine, totalRadius) then
            return true
        end
    end
    
    return false
end

function CollisionSystem:ClosestPointOnLineSegment(p, p1, p2)
    -- Nil guards for all input points
    if not p or not p1 or not p2 then return p1 or p2 or p, false end
    if not p.x or not p.z or not p1.x or not p1.z or not p2.x or not p2.z then
        return p1 or p2 or p, false
    end
    local px, pz = p.x, p.z
    local ax, az = p1.x, p1.z
    local bx, bz = p2.x, p2.z
    local bxax, bzaz = bx - ax, bz - az
    
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    
    if t < 0 then
        return p1, false
    elseif t > 1 then
        return p2, false
    else
        return { x = ax + t * bxax, z = az + t * bzaz }, true
    end
end

-- NUEVA FUNCIÓN: Verificar si dos líneas se intersectan
function CollisionSystem:LinesIntersect(p1, p2, p3, p4)
    -- Guards against invalid points
    if not p1 or not p2 or not p3 or not p4 then return false end
    if not (p1.x and p1.z and p2.x and p2.z and p3.x and p3.z and p4.x and p4.z) then return false end
    -- Función para verificar si dos segmentos de línea se intersectan
    -- p1-p2: primera línea (proyectil)
    -- p3-p4: segunda línea (muro de Yasuo)
    
    local function orientation(p, q, r)
        -- Función auxiliar para encontrar orientación de triplete ordenado (p, q, r)
        -- Retorna:
        -- 0 -> p, q y r son colineales
        -- 1 -> Horario
        -- 2 -> Antihorario
        local val = (q.z - p.z) * (r.x - q.x) - (q.x - p.x) * (r.z - q.z)
        if val == 0 then return 0 end
        return val > 0 and 1 or 2
    end
    
    local function onSegment(p, q, r)
        -- Verificar si el punto q está en el segmento pr
        return q.x <= math.max(p.x, r.x) and q.x >= math.min(p.x, r.x) and
               q.z <= math.max(p.z, r.z) and q.z >= math.min(p.z, r.z)
    end
    
    -- Encontrar las cuatro orientaciones necesarias para el caso general y especial
    local o1 = orientation(p1, p2, p3)
    local o2 = orientation(p1, p2, p4)
    local o3 = orientation(p3, p4, p1)
    local o4 = orientation(p3, p4, p2)
    
    -- Caso general
    if o1 ~= o2 and o3 ~= o4 then
        return true
    end
    
    -- Casos especiales
    -- p1, p2 y p3 son colineales y p3 está en el segmento p1p2
    if o1 == 0 and onSegment(p1, p3, p2) then return true end
    
    -- p1, p2 y p4 son colineales y p4 está en el segmento p1p2
    if o2 == 0 and onSegment(p1, p4, p2) then return true end
    
    -- p3, p4 y p1 son colineales y p1 está en el segmento p3p4
    if o3 == 0 and onSegment(p3, p1, p4) then return true end
    
    -- p3, p4 y p2 son colineales y p2 está en el segmento p3p4
    if o4 == 0 and onSegment(p3, p2, p4) then return true end
    
    return false -- No se intersectan
end

-- Sistema de predicción principal mejorado
local PredictionCore = {}

function PredictionCore:GetPrediction(target, source, speed, delay, radius, useAdvanced)
    useAdvanced = useAdvanced == nil and true or useAdvanced
    
    -- Validación de parámetros
    if not target or not target.valid or not source then
        return nil, nil, -1
    end
    
    -- Actualizar tracking de unidad (controlado internamente)
    UnitTracker:UpdateUnit(target)
    
    local isHero = target.type == Obj_AI_Hero
    
    -- Trabajar en 2D para mejor rendimiento
    local sourcePos = Math:Get2D(source)
    local currentPos = Math:Get2D(target.pos)
    
    -- Validar que las posiciones sean razonables
    if not sourcePos or not currentPos or not sourcePos.x or not currentPos.x then
        return nil, nil, -1
    end
    
    -- IMPORTANTE: Validar que currentPos sea la posición real del objetivo, no del mouse
    if not target.pos or not target.pos.x then
        return nil, nil, -1
    end
    
    -- Verificar distancia inicial - ser más permisivo
    local initialDistance = Math:GetDistance(sourcePos, currentPos)
    if initialDistance > 12000 then -- Muy permisivo; no bloquear Arena
        return nil, nil, -1
    end
    
    -- COMENTAR VERIFICACIÓN DE VISIBILIDAD - puede causar que no castee
    -- if isHero and not target.visible then
    --     return nil, nil, -1
    -- end
    
    -- Verificar si la unidad se está moviendo de forma segura
    local hasMovePath = (target.pathing and target.pathing.hasMovePath) or false
    
    -- Si no se está moviendo, devolver posición actual en 2D
    if not hasMovePath then
        local distance = Math:GetDistance(sourcePos, currentPos)
        local timeToHit = delay + distance / speed
        return currentPos, currentPos, timeToHit
    end
    
    -- Calcular delay total y limitarlo
    local totalDelay = delay + Menu:GetLatency() + Menu:GetExtraDelay()
    totalDelay = math_min(totalDelay, 2.5) -- Más permisivo
    
    -- Para habilidades instantáneas, usar predicción 2D
    if speed == math_huge then
        local predictedPos = UnitTracker:GetPredictedPosition(target, totalDelay)
        
        -- Ser más permisivo con predicciones instantáneas
        if not predictedPos then
            predictedPos = currentPos
        end
        
        -- Validar predicción instantánea con límites más amplios
        local predictionDistance = Math:GetDistance(currentPos, predictedPos)
        local maxInstantDistance = (target.ms or 400) * totalDelay + 500 -- Aumentar buffer
        
        if predictionDistance > maxInstantDistance then
            -- Si la predicción está muy lejos, usar una predicción más conservadora
            local direction = Math:Normalized(predictedPos, currentPos)
            if direction then
                predictedPos = Math:Extended(currentPos, direction, maxInstantDistance)
            else
                predictedPos = currentPos
            end
        end
        
        -- CENTRAR: limitar cuánto adelantamos desde la posición actual
        do
            local lead = Menu:GetLeadFactor()
            local maxLead = (target.ms or 400) * totalDelay * lead
            predictedPos = Math:ClampTowards(currentPos, predictedPos, maxLead)
        end

        -- ASEGURAR que siempre devolvemos una posición válida
        if not predictedPos or not predictedPos.x then
            predictedPos = currentPos
        end
        
        -- Compensación ligera por radio (evita sobretiro en skills instantáneas)
        if radius and radius > 0 then
            local path = UnitTracker:GetUnitPath(target)
            if #path > 1 then
                local dir = Math:Normalized(predictedPos, path[1])
                if dir then
                    local back = math_min(radius, 100)
                    predictedPos = Math:Extended(predictedPos, {x = -dir.x, z = -dir.z}, back)
                end
            end
        end
        return predictedPos, predictedPos, totalDelay
    end
    
    -- Predicción avanzada con intercepción (todo en 2D)
    if useAdvanced and isHero then
        local success, result1, result2, result3 = pcall(function()
            return self:AdvancedPrediction(target, sourcePos, speed, totalDelay, radius)
        end)
        if success and result1 then
            -- Ser más permisivo con validación de predicción avanzada
            local predictionDistance = Math:GetDistance(sourcePos, result1)
            local timeDistance = speed * result3
            
            if predictionDistance <= timeDistance + 1200 then -- Más tolerancia para Arena
                -- CENTRAR: clamp respecto a posición actual del objetivo
                local lead = Menu:GetLeadFactor()
                local maxLead = (target.ms or 400) * (result3 or 0) * lead
                local centered = Math:ClampTowards(currentPos, result1, maxLead)
                return centered, centered, result3
            end
        end
    end
    
    -- Fallback a predicción básica con manejo de errores
    local success, result1, result2, result3 = pcall(function()
        return self:BasicPrediction(target, sourcePos, speed, totalDelay, radius)
    end)
    
    if success and result1 then
        -- Ser más permisivo con validación de predicción básica
        local predictionDistance = Math:GetDistance(sourcePos, result1)
    if predictionDistance <= 8000 then -- Mucho más permisivo
            local lead = Menu:GetLeadFactor()
            local maxLead = (target.ms or 400) * (result3 or 0) * lead
            local centered = Math:ClampTowards(currentPos, result1, maxLead)
            return centered, centered, result3
        end
    end
    
    -- Fallback final: SIEMPRE devolver posición actual si todo falla
    local distance = Math:GetDistance(sourcePos, currentPos)
    local timeToHit = totalDelay + distance / speed
    return currentPos, currentPos, timeToHit
end

function PredictionCore:AdvancedPrediction(target, source, speed, delay, radius)
    -- NUEVA LÓGICA: Verificar si estamos en arena para usar predicción optimizada
    local mapBounds = Math:GetMapBounds()
    local isArenaMap = mapBounds.maxDistance <= 3000
    
    if isArenaMap then
        return self:ArenaPrediction(target, source, speed, delay, radius)
    end
    
    local unitData = UnitTracker.Units[target.networkID]
    
    if unitData and unitData.movementPattern then
        local vel = unitData.movementPattern.avgVelocity
        local currentPos = Math:Get2D(target.pos)
        
        -- Usar intercepción avanzada sin errores
        local intercept = Math:AdvancedIntercept(source, currentPos, vel, speed, delay)
        
        if intercept then
            local castPos = { x = intercept.x, z = intercept.z }
            local timeToHit = intercept.time
            
            -- Tracking obvio: mostrar claramente donde va a estar el objetivo
            return castPos, castPos, timeToHit
        end
    end
    
    -- Fallback a predicción básica
    return self:BasicPrediction(target, source, speed, delay, radius)
end

-- NUEVA FUNCIÓN: Predicción optimizada para arena
function PredictionCore:ArenaPrediction(target, source, speed, delay, radius)
    local currentPos = Math:Get2D(target.pos)
    local unitData = UnitTracker.Units[target.networkID]
    
    -- En arena, los movimientos son más rápidos y erráticos
    -- Usar predicción más agresiva y reactiva
    
    -- Factor de corrección para arena (movimientos más rápidos)
    local arenaSpeedMultiplier = 1.3 -- Los campeones suelen moverse 30% más rápido en arena
    local ms = (target.ms or 400) * arenaSpeedMultiplier
    
    -- Reducir tiempo de reacción en arena (combates más intensos)
    local arenaReactionTime = math_min(Menu:GetReactionTime() * 0.7, 0.08) -- Máximo 80ms
    
    -- Si el tiempo de predicción es muy corto, usar posición actual
    if delay < arenaReactionTime then
        return currentPos, currentPos, delay
    end
    
    -- Usar análisis de movimiento pero con parámetros ajustados para arena
    if unitData and unitData.movementPattern then
        local vel = unitData.movementPattern.avgVelocity
        
        -- En arena, aplicar factor de velocidad aumentada
        vel = {
            x = vel.x * arenaSpeedMultiplier,
            z = vel.z * arenaSpeedMultiplier
        }
        
        -- Intercepción optimizada para arena
        local intercept = Math:AdvancedIntercept(source, currentPos, vel, speed, delay)
        
        if intercept then
            local castPos = { x = intercept.x, z = intercept.z }
            local timeToHit = intercept.time
            
            -- Validar que la predicción esté dentro de los límites de arena
            local mapBounds = Math:GetMapBounds()
            castPos.x = math.max(mapBounds.minX, math.min(mapBounds.maxX, castPos.x))
            castPos.z = math.max(mapBounds.minZ, math.min(mapBounds.maxZ, castPos.z))
            
            return castPos, castPos, timeToHit
        end
    end
    
    -- Predicción básica para arena con velocidad ajustada
    local path = UnitTracker:GetUnitPath(target)
    
    if #path > 1 then
        local direction = Math:Normalized(path[2], path[1])
        if direction then
            -- Usar velocidad ajustada para arena
            local predictedDistance = ms * delay
            local predictedPos = Math:Extended(currentPos, direction, predictedDistance)
            
            -- Validar límites de arena
            local mapBounds = Math:GetMapBounds()
            predictedPos.x = math.max(mapBounds.minX, math.min(mapBounds.maxX, predictedPos.x))
            predictedPos.z = math.max(mapBounds.minZ, math.min(mapBounds.maxZ, predictedPos.z))
            
            local distance = Math:GetDistance(source, predictedPos)
            local timeToHit = delay + distance / speed
            
            return predictedPos, predictedPos, timeToHit
        end
    end
    
    -- Fallback: posición actual
    local distance = Math:GetDistance(source, currentPos)
    return currentPos, currentPos, delay + distance / speed
end

function PredictionCore:BasicPrediction(target, source, speed, delay, radius)
    local path = UnitTracker:GetUnitPath(target)
    local ms = target.ms
    
    if #path <= 1 then
        local pos = Math:Get2D(target.pos)
        local distance = Math:GetDistance(source, pos)
        return pos, pos, delay + distance / speed
    end
    
    -- Cortar el path basado en el delay
    local cutPath = self:CutPath(path, ms * delay)
    
    -- Encontrar intercepción en el path
    local bestIntercept = self:FindBestIntercept(source, cutPath, speed, ms)
    
    if bestIntercept then
        local distance = Math:GetDistance(source, bestIntercept.position)
        local timeToHit = delay + distance / speed
        return bestIntercept.position, bestIntercept.position, timeToHit
    end
    
    -- Fallback a la última posición del path
    local lastPos = path[#path]
    local distance = Math:GetDistance(source, lastPos)
    return lastPos, lastPos, delay + distance / speed
end

function PredictionCore:CutPath(path, distance)
    local result = {}
    
    if distance <= 0 or #path <= 1 then
        return path
    end
    
    local remainingDistance = distance
    
    for i = 1, #path - 1 do
        local a, b = path[i], path[i + 1]
        local segmentDistance = Math:GetDistance(a, b)
        
        if segmentDistance > remainingDistance then
            local direction = Math:Normalized(b, a)
            local cutPoint = Math:Extended(a, direction, remainingDistance)
            table_insert(result, cutPoint)
            
            -- Agregar el resto del path
            for j = i + 1, #path do
                table_insert(result, path[j])
            end
            break
        end
        
        remainingDistance = remainingDistance - segmentDistance
    end
    
    return #result > 0 and result or { path[#path] }
end

function PredictionCore:FindBestIntercept(source, path, speed, targetSpeed)
    local bestIntercept = nil
    local bestTime = math_huge
    
    local timeOffset = 0
    
    for i = 1, #path - 1 do
        local a, b = path[i], path[i + 1]
        local segmentDistance = Math:GetDistance(a, b)
        local segmentTime = segmentDistance / targetSpeed
        
        local direction = Math:Normalized(b, a)
        
        -- Buscar intercepción en este segmento
        local intercept = Math:AdvancedIntercept(source, a, 
            { x = direction.x * targetSpeed, z = direction.z * targetSpeed }, 
            speed, timeOffset)
        
        if intercept and intercept.time >= timeOffset and intercept.time <= timeOffset + segmentTime then
            if intercept.time < bestTime then
                bestTime = intercept.time
                bestIntercept = {
                    position = { x = intercept.x, z = intercept.z },
                    time = intercept.time
                }
            end
        end
        
        timeOffset = timeOffset + segmentTime
    end
    
    return bestIntercept
end

-- Sistema de predicción de habilidades
function PredictionCore:SpellPrediction(args)
    local spell = {
        Type = args.Type or SPELLTYPE_LINE,
        Speed = args.Speed or math_huge,
        Range = args.Range or math_huge,
        Delay = args.Delay or 0,
        Radius = args.Radius or 1,
        Collision = args.Collision or false,
        MaxCollision = args.MaxCollision or 0,
        CollisionTypes = args.CollisionTypes or { COLLISION_MINION },
        UseBoundingRadius = args.UseBoundingRadius
    }
    
    if spell.UseBoundingRadius == nil and spell.Type == SPELLTYPE_LINE then
        spell.UseBoundingRadius = true
    end
    
    function spell:GetPrediction(target, source)
        local _startClock = os.clock()
        local hitChance = HITCHANCE_IMPOSSIBLE
        local castPosition = nil
        local unitPosition = nil
        local timeToHit = 0
        local collisionObjects = {}
        local initialPosTo = nil
        
        -- VALIDACIÓN CRÍTICA: Asegurar que tenemos un objetivo válido
        if not target or not target.valid or not target.pos or not target.pos.x then
            return {
                HitChance = HITCHANCE_IMPOSSIBLE,
                CastPosition = nil,
                UnitPosition = nil,
                TimeToHit = 0,
                CollisionObjects = {}
            }
        end
        
    -- Trabajar en 2D primero para mejor rendimiento
        local source2D = Math:Get2D(source)
        -- Capturar posTo inicial para verificar cambios de destino de path
        pcall(function()
            initialPosTo = Math:Get2D(target.posTo)
        end)
        
        -- CRÍTICO: Obtener la posición actual real del objetivo
        local currentTargetPos = Math:Get2D(target.pos)
        if not currentTargetPos or not currentTargetPos.x then
            return {
                HitChance = HITCHANCE_IMPOSSIBLE,
                CastPosition = nil,
                UnitPosition = nil,
                TimeToHit = 0,
                CollisionObjects = {}
            }
        end

        -- Early out por rango para evitar cálculos costosos (pero permitir clamp luego)
        local maxRange = self.Range ~= math_huge and (self.Range * Menu:GetMaxRange()) or math_huge
        if maxRange ~= math_huge then
            local distSqr = Math:GetDistanceSqr(source2D, currentTargetPos)
            -- ÉNFASIS MEJORADO: Aplicar rango del menú más estrictamente
            local effectiveRange = maxRange + (self.UseBoundingRadius and (target.boundingRadius or 0) or 0)
            if distSqr > (effectiveRange + 1200) * (effectiveRange + 1200) then -- hard cap con rango efectivo
                return {
                    HitChance = HITCHANCE_IMPOSSIBLE,
                    CastPosition = nil,
                    UnitPosition = nil,
                    TimeToHit = 0,
                    CollisionObjects = {}
                }
            end
        end
        
    -- Obtener predicción básica en 2D
    unitPosition, castPosition, timeToHit = PredictionCore:GetPrediction(
            target, source2D, self.Speed, self.Delay, self.Radius, true
        )
        
        -- VALIDACIÓN CRÍTICA: Si la predicción falla, usar posición actual del objetivo
        if not unitPosition or not castPosition then
            -- Fallback seguro: usar posición actual del objetivo EN 2D
            local distance = Math:GetDistance(source2D, currentTargetPos)
            local fallbackTime = self.Delay + distance / self.Speed
            
            return {
                HitChance = HITCHANCE_LOW,
                CastPosition = currentTargetPos, -- DEVOLVER EN 2D
                UnitPosition = currentTargetPos, -- DEVOLVER EN 2D
                TimeToHit = fallbackTime,
                CollisionObjects = {}
            }
        end
        
        -- VALIDACIÓN: Asegurar que castPosition no sea una coordenada extrema y clamp a rango si aplica
        local distanceFromTarget = Math:GetDistance(currentTargetPos, castPosition)
        local maxReasonableDistance = (target.ms or 400) * timeToHit + 800
        if distanceFromTarget > maxReasonableDistance then
            local reductionFactor = maxReasonableDistance / math_max(1, distanceFromTarget)
            castPosition = {
                x = currentTargetPos.x + (castPosition.x - currentTargetPos.x) * reductionFactor,
                z = currentTargetPos.z + (castPosition.z - currentTargetPos.z) * reductionFactor
            }
            unitPosition = castPosition
        end

        -- CENTRAR: aplicar LeadFactor para no sobre-adelantar respecto a la posición actual
        do
            local lead = Menu:GetLeadFactor()
            local maxLead = (target.ms or 400) * (timeToHit or 0) * lead
            castPosition = Math:ClampTowards(currentTargetPos, castPosition, maxLead)
            unitPosition = Math:ClampTowards(currentTargetPos, unitPosition, maxLead)
        end
        -- Clamp a rango de lanzamiento si corresponde
        if maxRange ~= math_huge then
            local distFromMe = Math:GetDistance(source2D, castPosition)
            -- ÉNFASIS MEJORADO: Aplicar rango del menú más precisamente
            local effectiveRange = maxRange + (self.UseBoundingRadius and (target.boundingRadius or 0) or 0)
            if distFromMe > effectiveRange then
                local dir = Math:Normalized(castPosition, source2D)
                if dir then
                    castPosition = Math:Extended(source2D, dir, effectiveRange)
                end
            end
        end
        
        -- Calcular hit chance usando posiciones 2D
        hitChance = self:CalculateHitChance(target, castPosition, timeToHit)

        -- Verificación posTo: si el destino cambió significativamente durante el cálculo, degradar
        do
            local currentPosTo = nil
            pcall(function() currentPosTo = Math:Get2D(target.posTo) end)
            if initialPosTo and currentPosTo and not Math:VectorsEqual(initialPosTo, currentPosTo, 50) then
                hitChance = HITCHANCE_LOW
            end
        end
        
        -- Verificar rango en 2D (después de clamp)
        if maxRange ~= math_huge then
            local myPos2D = Math:Get2D(myHero.pos)
            -- ÉNFASIS MEJORADO: Usar rango efectivo consistente
            local effectiveRange = maxRange + (self.UseBoundingRadius and (target.boundingRadius or 0) or 0)
            if not Math:IsInRange(myPos2D, castPosition, effectiveRange) then
                hitChance = HITCHANCE_IMPOSSIBLE
            end
        end
        
        -- Verificar colisiones en 2D
        if self.Collision and hitChance > HITCHANCE_COLLISION then
            local collisionTypes = self.CollisionTypes or { COLLISION_MINION }
            
            -- NUEVA LÓGICA: Agregar automáticamente verificación de muro de Yasuo para habilidades lineales
            if self.Type == SPELLTYPE_LINE and Menu.YasuoWallDetection:Value() then
                local hasYasuoWallCheck = false
                for _, colType in pairs(collisionTypes) do
                    if colType == COLLISION_YASUOWALL then
                        hasYasuoWallCheck = true
                        break
                    end
                end
                
                -- Si no está verificando el muro de Yasuo, agregarlo automáticamente
                if not hasYasuoWallCheck then
                    -- Verificar si hay un Yasuo enemigo en el juego
                    local hasEnemyYasuo = false
                    for i = 1, Game.HeroCount() do
                        local hero = Game.Hero(i)
                        if hero and hero.valid and IsEnemyUnit(hero) and 
                           (hero.charName == "Yasuo" or hero.charName == "Yone") then
                            hasEnemyYasuo = true
                            break
                        end
                    end
                    
                    -- Solo agregar verificación de muro si hay Yasuo/Yone enemigo
                    if hasEnemyYasuo then
                        table.insert(collisionTypes, COLLISION_YASUOWALL)
                    end
                end
            end
            
            local _, collObjs, collCount = CollisionSystem:GetCollision(
                source2D, castPosition, self.Speed, self.Delay, 
                self.Radius, collisionTypes, target.networkID
            )
            
            if collCount > self.MaxCollision then
                hitChance = HITCHANCE_COLLISION
                collisionObjects = collObjs
            end
        end
        
        -- Solo convertir a 3D al final para el casting - ELIMINADO: TODO EN 2D
        local castPosition2D = nil
        local unitPosition2D = nil
        
        if castPosition then
            -- VALIDACIÓN CRÍTICA pero más permisiva: Verificar coordenadas extremas
            local sourcePos = Math:Get2D(source)
            local distance = Math:GetDistance(sourcePos, castPosition)
            
            -- Solo rechazar si es REALMENTE extremo
            if distance > 4000 or castPosition.x > 20000 or castPosition.z > 20000 or 
               castPosition.x < -2000 or castPosition.z < -2000 then
                -- Usar posición actual del objetivo como fallback seguro
                castPosition = Math:Get2D(target.pos)
            end
            
            -- Verificar límites del mapa con más tolerancia y usando bounds reales
            local b = Math:GetMapBounds()
            castPosition.x = math.max(b.minX, math.min(b.maxX, castPosition.x))
            castPosition.z = math.max(b.minZ, math.min(b.maxZ, castPosition.z))
            
            -- MANTENER EN 2D - no convertir a 3D
            castPosition2D = castPosition
        end
        
        if unitPosition then
            -- VALIDACIÓN CRÍTICA pero más permisiva
            local sourcePos = Math:Get2D(source)
            local distance = Math:GetDistance(sourcePos, unitPosition)
            
            -- Solo rechazar coordenadas realmente extremas
            if distance > 4000 or unitPosition.x > 20000 or unitPosition.z > 20000 or
               unitPosition.x < -2000 or unitPosition.z < -2000 then
                unitPosition = Math:Get2D(target.pos)
            end
            
            -- Verificar límites del mapa con más tolerancia y usando bounds reales
            local b = Math:GetMapBounds()
            unitPosition.x = math.max(b.minX, math.min(b.maxX, unitPosition.x))
            unitPosition.z = math.max(b.minZ, math.min(b.maxZ, unitPosition.z))
            
            -- MANTENER EN 2D - no convertir a 3D
            unitPosition2D = unitPosition
        end
        
        -- Límite de tiempo de cómputo (protección FPS)
        if os.clock() - _startClock > 0.005 then
            -- si excede el tiempo, ser conservador
            if hitChance > HITCHANCE_HIGH then hitChance = HITCHANCE_HIGH end
        end

        return {
            HitChance = hitChance,
            CastPosition = castPosition2D, -- DEVOLVER EN 2D
            UnitPosition = unitPosition2D, -- DEVOLVER EN 2D
            TimeToHit = timeToHit,
            CollisionObjects = collisionObjects
        }
    end
    
    function spell:CalculateHitChance(target, castPos, timeToHit)
        local isHero = target.type == Obj_AI_Hero
        
        if not isHero then
            return HITCHANCE_VERYHIGH  -- Minions son más predecibles
        end
        
        -- NUEVA LÓGICA: Verificar estados especiales primero
        local isDashing = false
        local isInZhonyas = false
        local isImmobilized = false
        
        pcall(function()
            -- Verificar dash
            if target.pathing and target.pathing.isDashing then
                isDashing = true
            end
            
            -- Verificar Zhonya's/invulnerabilidad
            if target.buffCount then
                for i = 0, target.buffCount do
                    local buff = target:GetBuff(i)
                    if buff and buff.name and buff.duration and buff.duration > 0 then
                        local buffName = buff.name:lower()
                        
                        -- Verificar Zhonya's y efectos similares
                        if buffName:find("zhonya") or buffName:find("zhonyas") or 
                           buffName:find("chronoshift") or buffName:find("guardianangel") or
                           buffName:find("stopwatch") then
                            isInZhonyas = true
                        end
                        
                        -- Verificar inmovilización
                        if buffName:find("stun") or buffName:find("root") or buffName:find("snare") or 
                           buffName:find("fear") or buffName:find("charm") or buffName:find("taunt") or
                           buffName:find("suppress") or buffName:find("knockup") then
                            isImmobilized = true
                        end
                        
                        -- Verificar por tipo de buff si está disponible
                        if buff.type then
                            local immobileTypes = {
                                [5] = true,  -- Stun
                                [8] = true,  -- Taunt
                                [12] = true, -- Snare
                                [22] = true, -- Fear
                                [23] = true, -- Charm
                                [25] = true, -- Suppression
                                [30] = true, -- Knockup
                            }
                            
                            if immobileTypes[buff.type] then
                                isImmobilized = true
                            end
                        end
                    end
                end
            end
        end)
        
    -- LÓGICA MEJORADA DE HIT CHANCE
        
        -- Si está en Zhonya's, es imposible de golpear
        if isInZhonyas then
            return HITCHANCE_IMPOSSIBLE
        end
        
        -- Si está inmovilizado, hit chance máximo
        if isImmobilized then
            return HITCHANCE_IMMOBILE
        end
        
        -- Si está haciendo dash, hit chance basado en predictibilidad del dash
        if isDashing then
            -- Los dashes son muy predecibles ya que tienen destino fijo
            return HITCHANCE_VERYHIGH
        end
        
        -- Verificar inmovilización por duración (método original mejorado)
        local immobileDuration = self:GetImmobileDuration(target)
        if immobileDuration > timeToHit then
            return HITCHANCE_IMMOBILE
        end
        
        -- Si no se está moviendo, hit chance muy alto
        if not target.pathing or not target.pathing.hasMovePath then
            return HITCHANCE_VERYHIGH
        end
        
        -- Analizar patrón de movimiento para tracking obvio
        local unitData = UnitTracker.Units[target.networkID]
        if unitData and unitData.movementPattern then
            -- Heurísticas de waypoints/visibilidad al estilo GG
            local now = Game.Timer()
            local justAppeared = unitData.wasVisible and (now - (unitData.lastVisibleTime or 0) < 0.5)
            local longInvisible = (not unitData.wasVisible) and (now - (unitData.lastInvisibleTime or 0) > 1.0)
            if justAppeared then
                return HITCHANCE_NORMAL
            end
            if longInvisible then
                return HITCHANCE_LOW
            end
            local justStartedMove = (now - (unitData.lastMoveStartTime or 0) < 0.15)
            local justStopped = (now - (unitData.lastStopTime or 0) < 0.05)
            if justStartedMove or justStopped then
                return HITCHANCE_HIGH
            end

            local reactionTime = Menu:GetReactionTime()
            
            -- Si el tiempo de predicción es menor que el tiempo de reacción
            if timeToHit < reactionTime then
                return HITCHANCE_IMMOBILE
            end
            
            -- Analizar velocidad para mejor tracking
            local avgVel = unitData.movementPattern.avgVelocity
            local velMagnitude = math_sqrt(avgVel.x * avgVel.x + avgVel.z * avgVel.z)
            
            if velMagnitude < 100 then -- Moviéndose lentamente
                return HITCHANCE_VERYHIGH
            elseif velMagnitude < 300 then -- Velocidad normal
                return HITCHANCE_HIGH
            else -- Moviéndose rápido pero trackeable
                return HITCHANCE_NORMAL
            end
        end
        
        -- Modelo simple de sidestep: tiempo para esquivar vs radio efectivo
        local ms = target.ms or 400
        local effectiveRadius = (self.Radius or 0) + (self.UseBoundingRadius and (target.boundingRadius or 0) or 0)
        local sidestepTime = effectiveRadius / ms -- tiempo mínimo para esquivar lateralmente
        if timeToHit <= sidestepTime * 0.6 then
            return HITCHANCE_VERYHIGH
        elseif timeToHit <= sidestepTime * 1.0 then
            return HITCHANCE_HIGH
        elseif timeToHit <= sidestepTime * 1.4 then
            return HITCHANCE_NORMAL
        end
        return HITCHANCE_LOW
    end
    
    function spell:GetImmobileDuration(unit)
        local maxDuration = 0
        
        -- Manejo seguro de buffs con diferentes APIs
        pcall(function()
            -- Método 1: Usar SDK BuffManager si está disponible
            if _G.SDK and _G.SDK.BuffManager and _G.SDK.BuffManager.GetBuffs then
                local buffs = _G.SDK.BuffManager:GetBuffs(unit)
                if buffs then
                    local immobileTypes = {
                        [5] = true,  -- Stun  
                        [8] = true,  -- Taunt
                        [12] = true, -- Snare
                        [22] = true, -- Fear
                        [23] = true, -- Charm
                        [25] = true, -- Suppression
                        [30] = true, -- Knockup
                    }
                    
                    for i = 1, #buffs do
                        local buff = buffs[i]
                        if buff.duration and buff.duration > 0 and buff.type and immobileTypes[buff.type] then
                            maxDuration = math_max(maxDuration, buff.duration)
                        end
                    end
                end
                return
            end
            
            -- Método 2: Acceso directo a buffs de la unidad
            if unit.buffCount and unit.GetBuff then
                for i = 0, unit.buffCount do
                    local buff = unit:GetBuff(i)
                    if buff and buff.duration and buff.duration > 0 then
                        -- Verificar por nombre de buff común de CC
                        local buffName = buff.name and buff.name:lower() or ""
                        if buffName:find("stun") or buffName:find("root") or buffName:find("snare") or 
                           buffName:find("fear") or buffName:find("charm") or buffName:find("taunt") or
                           buffName:find("suppress") or buffName:find("knockup") then
                            maxDuration = math_max(maxDuration, buff.duration)
                        end
                        
                        -- Verificar por tipo si está disponible
                        if buff.type then
                            local immobileTypes = {
                                [5] = true,  -- Stun
                                [8] = true,  -- Taunt
                                [12] = true, -- Snare
                                [22] = true, -- Fear
                                [23] = true, -- Charm
                                [25] = true, -- Suppression
                                [30] = true, -- Knockup
                            }
                            
                            if immobileTypes[buff.type] then
                                maxDuration = math_max(maxDuration, buff.duration)
                            end
                        end
                    end
                end
            end
        end)
        
        return maxDuration
    end
    
    return spell
end

-- Callback para actualizar datos y mostrar visuals
Callback.Add("Tick", function()
    -- Actualizar héroes
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid then
            UnitTracker:UpdateUnit(hero)
        end
    end
    
    -- Actualizar minions importantes (incluyendo neutrales y épicos)
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.valid and not minion.dead then
            -- Solo trackear minions importantes para rendimiento
            local shouldTrack = false
            local minionName = minion.name and minion.name:lower() or ""
            local charName = minion.charName and minion.charName:lower() or ""
            
            -- Trackear objetivos épicos
            if minionName:find("dragon") or minionName:find("baron") or minionName:find("herald") or
               charName:find("dragon") or charName:find("baron") or charName:find("herald") then
                shouldTrack = true
            end
            
            -- Trackear jungla importante
            if minionName:find("gromp") or minionName:find("krugs") or 
               minionName:find("blue") or minionName:find("red") or
               charName:find("gromp") or charName:find("krugs") or
               charName:find("blue") or charName:find("red") then
                shouldTrack = true
            end
            
            -- Trackear neutrales en arena (más importante en mapas pequeños)
            if not minion.isAlly and not minion.isEnemy then
                local mapBounds = Math:GetMapBounds()
                if mapBounds.maxDistance <= 3000 then -- En mapas pequeños como arena
                    shouldTrack = true
                end
            end
            
            if shouldTrack then
                UnitTracker:UpdateUnit(minion)
            end
        end
    end
end)

-- Visualización del tracking optimizada para 2D - SIMPLIFICADO
Callback.Add("Draw", function()
    if not Menu.ShowVisuals:Value() then return end
    
    -- Visualización simple en 2D - no hacer cálculos complejos de dibujo
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid and hero.isEnemy and hero.visible then
            local unitData = UnitTracker.Units[hero.networkID]
            if unitData and unitData.movementPattern then
                -- Solo mostrar información básica - simplificado para evitar conversiones
                -- Se puede agregar dibujo 2D aquí si es necesario
            end
        end
    end
end)

-- API Global optimizada para 2D
_G.DepressivePrediction = {
    -- Constantes expandidas
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
    
    -- Funciones principales optimizadas para 2D
    GetPrediction = function(target, source, speed, delay, radius)
        -- VALIDACIÓN CRÍTICA: Verificar que tenemos un objetivo válido
        if not target or not target.valid or not target.pos or not target.pos.x then
            return nil, nil, -1
        end
        -- OVERLOAD: permitir llamada con tabla de configuración como segundo parámetro
        if type(source) == "table" and (speed == nil and delay == nil and radius == nil) then
            local cfg = source or {}
            local stype = cfg.type or cfg.Type or "linear"
            local src = (cfg.source and (cfg.source.pos or cfg.source)) or _G.myHero or target
            local pred = PredictionCore:SpellPrediction({
                Type = (stype == "linear" and SPELLTYPE_LINE) or (stype == "circular" and SPELLTYPE_CIRCLE) or (stype == "cone" and SPELLTYPE_CONE) or SPELLTYPE_LINE,
                Speed = cfg.speed or math_huge,
                Range = cfg.range or math_huge,
                Delay = cfg.delay or 0,
                Radius = cfg.radius or 0,
                Collision = cfg.collision or cfg.coll or false,
                CollisionTypes = cfg.collisionTypes or { COLLISION_MINION },
                UseBoundingRadius = cfg.useBoundingRadius
            })
            local pr = pred:GetPrediction(target, src)
            return {
                castPos = pr.CastPosition and { x = pr.CastPosition.x, z = pr.CastPosition.z } or nil,
                unitPos = pr.UnitPosition,
                hitChance = pr.HitChance,
                timeToHit = pr.TimeToHit,
                collision = pr.CollisionObjects
            }
        end
        
        -- Convertir source a 2D automáticamente
        local source2D = Math:Get2D(source)
        if not source2D then
            return nil, nil, -1
        end
        
        local unitPos, castPos, time = PredictionCore:GetPrediction(target, source2D, speed, delay, radius, true)
        
        -- ASEGURAR que siempre devolvemos algo válido - ser más permisivo
        if not unitPos or not castPos then
            local currentPos = Math:Get2D(target.pos)
            if currentPos then
                local distance = Math:GetDistance(source2D, currentPos)
                local fallbackTime = (delay or 0) + distance / (speed or 1200) -- Speed por defecto más razonable
                return currentPos, currentPos, fallbackTime
            else
                -- Último recurso: usar posición cruda del objetivo EN 2D
                local rawPos = { x = target.pos.x, z = target.pos.z or target.pos.y }
                local distance = Math:GetDistance(source2D, rawPos)
                local fallbackTime = (delay or 0) + distance / (speed or 1200)
                return rawPos, rawPos, fallbackTime
            end
        end
        
    return unitPos, castPos, time
    end,
    
    GetCollision = function(source, castPos, speed, delay, radius, collisionTypes, skipID)
        -- Trabajar en 2D para mejor rendimiento
        local source2D = Math:Get2D(source)
        local castPos2D = Math:Get2D(castPos)
    if not source2D or not castPos2D then return false, {}, 0 end
    return CollisionSystem:GetCollision(source2D, castPos2D, speed, delay, radius, collisionTypes, skipID)
    end,
    
    SpellPrediction = function(args)
        return PredictionCore:SpellPrediction(args)
    end,
    
    -- Utilidades optimizadas para 2D
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
    
    -- Función para obtener posición predicha directamente en 2D
    GetPredictedPosition = function(unit, time)
        return UnitTracker:GetPredictedPosition(unit, time or 0.5)
    end,
    
    -- Conversión 2D solamente - 3D eliminado
    Get2D = function(pos)
        return Math:Get2D(pos)
    end,
    
    -- Función para obtener información detallada del tracking
    GetTrackingInfo = function(unit)
        local unitData = UnitTracker.Units[unit.networkID]
        if not unitData then return nil end
        
        return {
            positions = unitData.positions, -- Ya están en 2D
            timestamps = unitData.timestamps,
            movementPattern = unitData.movementPattern,
            isVisible = unitData.isVisible,
            lastUpdate = unitData.lastUpdate
        }
    end,
    
    -- Arena-aware team helpers
    IsEnemyUnit = function(unit) return IsEnemyUnit(unit) end,
    IsAllyUnit = function(unit) return IsAllyUnit(unit) end,
    
    -- NUEVA FUNCIÓN: Detectar si es un objetivo neutral importante
    IsNeutralTarget = function(unit)
    if not unit or not unit.valid then return false end
    local lc = (unit.charName and unit.charName:lower()) or ""
    local ln = (unit.name and unit.name:lower()) or ""
        -- Primero, si no es ally/enemy asumimos neutral
    local isNeutralFlag = (not unit.isAlly and not unit.isEnemy)
    -- Prefer exact name detection first
    local byName, nType, pr = IdentifyNeutralByNameLower(lc)
        if not byName then
            byName, nType, pr = IdentifyNeutralByNameLower(ln)
        end

        if isNeutralFlag or byName then
            -- Clasificar
            if nType == "epic" then return true, "epic" end
            if nType == "buff" then return true, "jungle" end
            if nType == "camp" then return true, "jungle" end
            if nType == "scuttle" then return true, "neutral" end
            -- Arena fallback: cualquier neutral es relevante
            local mapBounds = Math:GetMapBounds()
            if mapBounds.maxDistance <= 3000 then
                return true, "arena_neutral"
            end
            return true, "neutral"
        end
        return false, "not_neutral"
    end,

    -- NUEVA FUNCIÓN: Obtener neutrales priorizados en un rango
    GetNeutralTargets = function(range, source)
        range = range or 2000
        source = source or _G.myHero
    if not source or not source.pos then return {} end
        local src2D = Math:Get2D(source.pos)
    if not src2D then return {} end
        local results = {}
        -- Recorrer minions para detectar neutrales
        for i = 1, Game.MinionCount() do
            local m = Game.Minion(i)
        if m and m.valid and not m.dead and m.pos and m.pos.x then
                local ok, t
                local s, r1, r2 = pcall(_G.DepressivePrediction.IsNeutralTarget, m)
                if s then ok, t = r1, r2 end
                if ok then
                    local p2d = Math:Get2D(m.pos)
            if p2d and Math:IsInRange(src2D, p2d, range) then
                        local lc = (m.charName and m.charName:lower()) or ""
                        local ln = (m.name and m.name:lower()) or ""
                        local _, nType, pr = IdentifyNeutralByNameLower(lc)
                        if not nType then _, nType, pr = IdentifyNeutralByNameLower(ln) end
                        pr = pr or (t == "epic" and 9 or t == "jungle" and 6 or 4)
                        table_insert(results, { unit = m, type = nType or t, distance = Math:GetDistance(src2D, p2d), priority = pr })
                    end
                end
            end
        end
        -- Recorrer objetos para detectar neutrales especiales (dragón, barón, heraldo, etc.)
        for i = 1, Game.ObjectCount() do
            local obj = Game.Object(i)
            if obj and obj.valid and not obj.dead and obj.pos and obj.pos.x then
                local lc = (obj.charName and obj.charName:lower()) or ""
                local ln = (obj.name and obj.name:lower()) or ""
                local byName, nType, pr = IdentifyNeutralByNameLower(lc)
                if not byName then byName, nType, pr = IdentifyNeutralByNameLower(ln) end
                if byName then
                    local p2d = Math:Get2D(obj.pos)
                    if p2d and Math:IsInRange(src2D, p2d, range) then
                        pr = pr or (nType == "epic" and 9 or nType == "jungle" and 6 or 4)
                        table_insert(results, { unit = obj, type = nType, distance = Math:GetDistance(src2D, p2d), priority = pr })
                    end
                end
            end
        end
        table.sort(results, function(a,b) return a.priority > b.priority end)
        return results
    end,
    
    -- NUEVA FUNCIÓN: Obtener información específica del mapa actual
    GetMapInfo = function()
        local mapBounds = Math:GetMapBounds()
        local mapID = Game.mapID or 0
        local mapName = (Game.mapName and tostring(Game.mapName)) or ""
        local mapNameLower = mapName:lower()
        local mapType = "unknown"

        -- Primary detection by mapID
        if mapID == 11 then
            mapType = "summoners_rift"
        elseif mapID == 12 then
            mapType = "howling_abyss"
        elseif mapID >= 30 and mapID <= 35 then
            mapType = "arena"
        end

        -- Fallback by name substring if ID didn't resolve (or mismatch)
        if mapType == "unknown" then
            if mapNameLower:find("rift") then
                mapType = "summoners_rift"
            elseif mapNameLower:find("abyss") or mapNameLower:find("aram") then
                mapType = "howling_abyss"
            elseif mapNameLower:find("arena") then
                mapType = "arena"
            end
        end

        -- Propagate globally for other modules (EvadeLogic, Geometry, SpellFilter)
        _G.MapType = mapType

        -- Debug print once per call (can be throttled externally if needed)
        print(string.format("[DepressiveEvade] Detected mapID: %s | mapName: %s | resolved mapType: %s", tostring(mapID), mapName, mapType))

        return {
            mapID = mapID,
            mapName = mapName,
            mapType = mapType,
            bounds = mapBounds,
            isArena = mapType == "arena" or mapBounds.maxDistance <= 3000,
            isARAM = mapType == "howling_abyss" or mapID == 12
        }
    end,
    
    -- NUEVA FUNCIÓN: Obtener rango efectivo del menú (helper para scripts de campeones)
    GetEffectiveRange = function(baseRange, target, useBoundingRadius)
        if Menu and Menu.GetEffectiveRange then
            return Menu:GetEffectiveRange(baseRange, target, useBoundingRadius)
        else
            -- Fallback si la función no está disponible
            local rangeFactor = Menu and Menu:GetMaxRange() or 1
            local effectiveRange = baseRange * rangeFactor
            if useBoundingRadius and target and target.boundingRadius then
                effectiveRange = effectiveRange + target.boundingRadius
            end
            return effectiveRange
        end
    end,
    
    -- NUEVA FUNCIÓN: Verificar si un objetivo está en rango efectivo
    IsInEffectiveRange = function(source, target, baseRange, useBoundingRadius)
        if not source or not target or not source.pos or not target.pos then
            return false
        end
        
        local effectiveRange = _G.DepressivePrediction.GetEffectiveRange(baseRange, target, useBoundingRadius)
        local distance = Math:GetDistance(Math:Get2D(source.pos), Math:Get2D(target.pos))
        
        return distance <= effectiveRange
    end,
}

print("DepressivePrediction v" .. Version .. " loaded successfully!")
print("  - Enhanced menu range emphasis: MaxRange setting now properly applied")
print("  - Added GetEffectiveRange() helper for champion scripts")
print("  - Improved range validation and clamping")

-- Retornar el módulo para require()
return _G.DepressivePrediction


