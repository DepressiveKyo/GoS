-- Champion Loader Guards / Validation
local VERSION = "0.01"
if myHero.charName ~= "Cassiopeia" then return end
if _G.DepressiveAIONextCassiopeiaLoaded then return end
_G.DepressiveAIONextCassiopeiaLoaded = true

if not _G.DepressivePrediction then require("DepressivePrediction") end

-- Neutral team constant (fallback)
local TEAM_NEUTRAL = _G.TEAM_JUNGLE or 300

-- Constants and globals
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameCanUseSpell = Game.CanUseSpell
local GameTimer = Game.Timer
local TableInsert = table.insert

-- Throttling utilities
local _Throttle = {}
local function ShouldRun(key, interval)
    local t = Game.Timer()
    local last = _Throttle[key]
    if not last or t - last >= interval then
        _Throttle[key] = t
        return true
    end
    return false
end

-- Cached collections
local cachedMinions = {time = 0, list = {}}
local function GetCachedEnemyHeroes()
    return Enemys -- Enemys itself already refreshed on its own throttle
end
local function GetCachedMinions(range)
    local t = Game.Timer()
    if t - cachedMinions.time > 0.25 then -- refresh every 250ms
        cachedMinions.list = {}
        for i = 1, Game.MinionCount() do
            local m = Game.Minion(i)
            if IsValid and m and m.isEnemy then
                cachedMinions.list[#cachedMinions.list+1] = m
            end
        end
        cachedMinions.time = t
    end
    if not range then return cachedMinions.list end
    local out = {}
    for i = 1, #cachedMinions.list do
        local m = cachedMinions.list[i]
        if m and (not range or GetDistance(myHero.pos, m.pos) <= range) then
            out[#out+1] = m
        end
    end
    return out
end

local lastMove = 0
local lastQCast = 0
local lastWCast = 0
local lastECast = 0
local lastRCast = 0
local Enemys = {}
local Allys = {}
local myHero = myHero

-- Get screen mouse position (not world coordinates)
local function GetScreenMousePos()
    local mouseX, mouseY = nil, nil
    
    -- Try multiple methods to get screen coordinates
    pcall(function()
        -- Method 1: Use Win32 API if available
        if _G.GetCursorPos then
            local pos = _G.GetCursorPos()
            if pos and pos.x and pos.y then
                mouseX, mouseY = pos.x, pos.y
                return
            end
        end
        
        -- Method 2: Check for Game screen mouse functions
        if _G.Game and _G.Game.GetMouseScreenPos then
            local pos = _G.Game.GetMouseScreenPos()
            if pos and pos.x and pos.y then
                mouseX, mouseY = pos.x, pos.y
                return
            end
        end
        
        -- Method 3: Use simple cursor position
        local ffi = require("ffi")
        ffi.cdef[[
            typedef struct { long x, y; } POINT;
            bool GetCursorPos(POINT* lpPoint);
        ]]
        local point = ffi.new("POINT")
        if ffi.C.GetCursorPos(point) then
            mouseX, mouseY = tonumber(point.x), tonumber(point.y)
        end
    end)
    
    return mouseX and mouseY and {x = mouseX, y = mouseY} or nil
end

-- Poison detection function with safety checks and caching for FPS optimization
local poisonCache = {}
local lastPoisonCacheUpdate = 0

local function HasPoison(unit)
    if not unit or not unit.buffCount then return false end
    
    -- Use cache to reduce buff checking frequency for FPS optimization
    local currentTime = GameTimer()
    local unitNetworkID = unit.networkID
    
    if poisonCache[unitNetworkID] and currentTime - poisonCache[unitNetworkID].lastCheck < 0.1 then
        return poisonCache[unitNetworkID].hasPoison
    end
    
    local success, result = pcall(function()
        for i = 0, unit.buffCount do
            local buff = unit:GetBuff(i)
            if buff and buff.type == 24 and GameTimer() < buff.expireTime - 0.141 then
                return true
            end
        end
        return false
    end)
    
    -- Cache the result
    poisonCache[unitNetworkID] = {
        hasPoison = success and result,
        lastCheck = currentTime
    }
    
    -- Clean cache periodically to prevent memory leaks
    if currentTime - lastPoisonCacheUpdate > 5.0 then
        poisonCache = {}
        lastPoisonCacheUpdate = currentTime
    end
    
    return success and result
end

-- Utility functions
local function GetDistanceSquared(vec1, vec2)
    if not vec1 or not vec2 or not vec1.x or not vec2.x then return math.huge end
    local dx = vec1.x - vec2.x
    local dy = vec1.z - vec2.z
    return dx * dx + dy * dy
end

local function GetDistanceSqr(pos1, pos2)
    if not pos1 or not pos2 or not pos1.x or not pos2.x then return math.huge end
    local dx = pos1.x - pos2.x
    local dz = pos1.z - pos2.z
    return dx * dx + dz * dz
end

local function GetDistance(p1, p2)
    if not p1 or not p2 or not p1.x or not p2.x then return math.huge end
    return math.sqrt(GetDistanceSqr(p1, p2))
end

local function IsValid(unit)
    if unit and unit.valid and not unit.dead and unit.visible then
        return true
    end
    return false
end

local function Ready(spell)
    if not myHero or not myHero.GetSpellData then return false end
    
    local spellData = myHero:GetSpellData(spell)
    if not spellData then return false end
    
    return spellData.currentCd == 0 and spellData.level > 0 and spellData.mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

-- Check if spell is learned (level > 0)
local function IsSpellLearned(spell)
    local spellData = myHero:GetSpellData(spell)
    if spellData then
        return spellData.level > 0
    end
    return false
end

local function OnAllyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero.isAlly then
            cb(hero)
        end
    end
end

local function OnEnemyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero.isEnemy then
            cb(hero)
        end
    end
end

local function GetEnemyHeroes()
    local _EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if IsValid(hero) and hero.isEnemy then
            TableInsert(_EnemyHeroes, hero)
        end
    end
    return _EnemyHeroes
end

local function GetTarget(range)
    local bestTarget = nil
    local bestDistance = math.huge
    
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if IsValid(enemy) then
            local distance = GetDistance(myHero.pos, enemy.pos)
            if distance <= range and distance < bestDistance then
                bestTarget = enemy
                bestDistance = distance
            end
        end
    end
    
    return bestTarget
end

local function MyHeroNotReady()
    return myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading)
end

local function HasBuff(unit, buffname)
    if not unit or not unit.buffCount then return false end
    
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name and string.find(buff.name:lower(), buffname:lower()) then
            return true
        end
    end
    return false
end

-- Check if any enemy is too close (within specified range)
local function IsEnemyTooClose(range)
    if not range or range <= 0 then return false end
    
    local enemies = GetEnemyHeroes()
    for i = 1, #enemies do
        local enemy = enemies[i]
        if IsValid(enemy) and not enemy.dead then
            local distance = GetDistance(myHero.pos, enemy.pos)
            if distance <= range then
                return true, enemy -- Return true and the enemy that's too close
            end
        end
    end
    return false
end

-- Cassiopeia Class
class "Cassiopeia"

function Cassiopeia:__init()
    -- Initialize prediction system with safety check
    self.Prediction = _G.DepressivePrediction or {
        -- Fallback values if DepressivePrediction is not available
        HITCHANCE_IMMOBILE = 6,
        HITCHANCE_VERYHIGH = 5,
        HITCHANCE_HIGH = 4,
        HITCHANCE_NORMAL = 3,
        HITCHANCE_LOW = 2,
        HITCHANCE_COLLISION = 1,
        SPELLTYPE_CIRCLE = 0,
        SPELLTYPE_LINE = 1,
        SPELLTYPE_CONE = 2,
        SpellPrediction = function(data) 
            return {
                GetPrediction = function(target, source)
                    return {
                        HitChance = 3, -- NORMAL
                        CastPosition = target.pos
                    }
                end
            }
        end
    }
    
    -- Spell data with prediction integration
    self.Q = {
        range = 850,
        width = 150,
        delay = 0.6,
        speed = math.huge, -- Instant
        collision = false,
        aoe = true,
        type = "circular",
        spell = self.Prediction.SpellPrediction({
            Type = self.Prediction.SPELLTYPE_CIRCLE,
            Speed = math.huge,
            Range = 850,
            Delay = 0.6,
            Radius = 150,
            Collision = false
        })
    }
    
    self.W = {
        range = 850,
        width = 160,
        delay = 0.5,
        speed = 2500,
        collision = false,
        aoe = true,
        type = "circular",
        spell = self.Prediction.SpellPrediction({
            Type = self.Prediction.SPELLTYPE_CIRCLE,
            Speed = 2500,
            Range = 850,
            Delay = 0.5,
            Radius = 160,
            Collision = false
        })
    }
    
    self.E = {
        range = 700,
        delay = 0.125,
        speed = math.huge, -- Instant
        collision = false,
        type = "targeted"
    }
    
    self.R = {
        range = 650, -- Reducido de 825 a 650 para evitar que se tire muy rápido
        width = 80,
        delay = 0.5,
        speed = math.huge, -- Instant
        collision = false,
        type = "cone",
        spell = self.Prediction.SpellPrediction({
            Type = self.Prediction.SPELLTYPE_CONE,
            Speed = math.huge,
            Range = 650, -- Reducido también aquí
            Delay = 0.5,
            Radius = 80,
            Collision = false
        })
    }
    
    -- State tracking
    self.lastECast = 0
    self.lastQCast = 0
    self.lastWCast = 0
    self.lastRCast = 0
    self.lastFlashR = 0
    self.lastEnemyUpdate = 0 -- For FPS optimization
    self.eSpamMode = false
    self.eSpamTarget = nil
    self.lastAntiGapcloser = 0 -- Anti-gapcloser cooldown
    self.enemyPositions = {} -- Track enemy positions for dash detection
    
    -- Flash detection
    self.flashSlot = self:GetFlashSlot()
    self.flashRange = 400 -- Flash range
    
    -- Initialize InfoBox for dragging
    self.infoBox = {
        x = 200,
        y = 200,
        width = 420,
        height = 140,
        isDragging = false,
        dragOffsetX = 0,
        dragOffsetY = 0,
        initialized = false,
        dragStartTime = 0
    }
    
    -- Initialize global timers
    lastQCast = 0
    lastWCast = 0
    lastECast = 0
    lastRCast = 0
    
    -- Load units
    OnAllyHeroLoad(function(hero) TableInsert(Allys, hero) end)
    OnEnemyHeroLoad(function(hero) TableInsert(Enemys, hero) end)
    
    -- Initialize enemy list
    Enemys = GetEnemyHeroes()
    
    -- Orbwalker integration
    if _G.SDK and _G.SDK.Orbwalker then
        _G.SDK.Orbwalker:OnPostAttack(function(target) self:OnPostAttack(target) end)
    end
    
    self:LoadMenu()
    
    -- Callbacks
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function Cassiopeia:GetQRange()
    -- Get Q range with extra range bonus
    local baseRange = self.Q.range -- 850
    local extraRange = self.Menu.advanced.qExtraRange:Value()
    return baseRange + extraRange
end

function Cassiopeia:GetQRadius()
    -- Get Q radius with extra radius bonus
    local baseRadius = self.Q.width -- 150
    local extraRadius = self.Menu.advanced.qExtraRadius and self.Menu.advanced.qExtraRadius:Value() or 0
    return baseRadius + extraRadius
end

function Cassiopeia:UpdateQSpell()
    -- Update Q spell prediction with current radius
    if self.Prediction and self.Prediction.SpellPrediction then
        local currentRadius = self:GetQRadius()
        self.Q.spell = self.Prediction.SpellPrediction({
            Type = self.Prediction.SPELLTYPE_CIRCLE,
            Speed = math.huge,
            Range = self:GetQRange(),
            Delay = 0.6,
            Radius = currentRadius,
            Collision = false
        })
    end
end

function Cassiopeia:GetRRange()
    -- Get R range from menu setting
    if self.Menu and self.Menu.advanced and self.Menu.advanced.rRange then
        return self.Menu.advanced.rRange:Value()
    end
    return self.R.range -- Fallback to base range
end

function Cassiopeia:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "Cassiopeia", name = "Cassiopeia - Depressive"})
    self.Menu:MenuElement({name = "Ping", id = "ping", value = 20, min = 0, max = 300, step = 1})
    self.Menu:MenuElement({id = "blockAA", name = "Block AA", value = false})
    
    -- Combo
    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.combo:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.combo:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.combo:MenuElement({id = "eOnlyPoison", name = "E Only on Poisoned Targets", value = true})
    self.Menu.combo:MenuElement({id = "useR", name = "Use R", value = true})
    self.Menu.combo:MenuElement({id = "eSpam", name = "Auto E Poison (Smart Spam)", value = true})
    self.Menu.combo:MenuElement({id = "eSpamDelay", name = "Auto E Poison Delay (ms)", value = 100, min = 50, max = 500, step = 50})
    self.Menu.combo:MenuElement({id = "rMinEnemies", name = "Min Enemies for R", value = 1, min = 1, max = 5, step = 1})
    self.Menu.combo:MenuElement({id = "rKillable", name = "Use R on Killable", value = true})
    
    -- Harass
    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.harass:MenuElement({id = "useW", name = "Use W", value = false})
    self.Menu.harass:MenuElement({id = "useE", name = "Use E on Poisoned", value = true})
    self.Menu.harass:MenuElement({id = "eOnlyPoison", name = "E Only on Poisoned Targets", value = true})
    self.Menu.harass:MenuElement({id = "manaThreshold", name = "Min Mana %", value = 40, min = 0, max = 100, step = 5})
    self.Menu.harass:MenuElement({id = "autoHarassRange", name = "Auto Harass Range", value = 850, min = 600, max = 1000, step = 25})
    
    -- Clear
    self.Menu:MenuElement({type = MENU, id = "clear", name = "Lane Clear & Jungle Clear"})
    self.Menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.clear:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.clear:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.clear:MenuElement({id = "eOnlyPoison", name = "E Only on Poisoned Minions", value = false})
    self.Menu.clear:MenuElement({id = "minMinionsQ", name = "Min targets for Q", value = 3, min = 1, max = 6, tooltip = "Minimum minions/monsters to use Q"})
    self.Menu.clear:MenuElement({id = "minMinionsW", name = "Min targets for W", value = 4, min = 2, max = 6, tooltip = "Minimum minions/monsters to use W"})
    self.Menu.clear:MenuElement({id = "manaThreshold", name = "Min Mana %", value = 30, min = 0, max = 80, step = 5})
    
    -- LastHit
    self.Menu:MenuElement({type = MENU, id = "lasthit", name = "Last Hit"})
    self.Menu.lasthit:MenuElement({id = "useE", name = "Use E on Poisoned Minions", value = true})
    self.Menu.lasthit:MenuElement({id = "manaThreshold", name = "Min Mana %", value = 50, min = 0, max = 100, step = 5})
    
    -- Auto
    self.Menu:MenuElement({type = MENU, id = "auto", name = "Auto Functions"})
    
    -- Auto Functions - Main Features
    self.Menu:MenuElement({type = MENU, id = "autoMain", name = "Auto Main Functions"})
    self.Menu.autoMain:MenuElement({id = "autoEPoison", name = "Auto E on Poisoned Enemies", value = true})
    self.Menu.autoMain:MenuElement({id = "autoQPoison", name = "Auto Q to Apply Poison", value = true})
    self.Menu.autoMain:MenuElement({id = "autoFlashR", name = "Auto Flash + R (Extended Range)", value = false})
    self.Menu.autoMain:MenuElement({id = "flashRMinEnemies", name = "Flash R Min Enemies", value = 2, min = 2, max = 5, step = 1})
    self.Menu.autoMain:MenuElement({id = "flashRMaxRange", name = "Flash R Max Range", value = 1200, min = 900, max = 1500, step = 50, tooltip = "Max range for Flash+R combo (R range + Flash range)"})
    self.Menu.autoMain:MenuElement({id = "flashRMinHealth", name = "Flash R Min Health %", value = 30, min = 10, max = 100, step = 5})
    self.Menu.autoMain:MenuElement({id = "autoEPostAttack", name = "Auto E after Auto Attack", value = false})
    self.Menu.autoMain:MenuElement({id = "antiGapcloser", name = "Auto R Anti-Gapcloser", value = true})
    self.Menu.autoMain:MenuElement({id = "antiGapcloserRange", name = "Anti-Gapcloser Range", value = 600, min = 400, max = 900, step = 50, tooltip = "Max range to detect gap closers"})
    
    -- Auto Functions - Farming & Lasthit
    self.Menu:MenuElement({type = MENU, id = "autoFarm", name = "Auto Farming Functions"})
    self.Menu.autoFarm:MenuElement({id = "autoELasthit", name = "Auto E Lasthit (Poisoned)", value = true})
    self.Menu.autoFarm:MenuElement({id = "autoELasthitNoPoison", name = "Auto E Lasthit (No Poison)", value = true})
    self.Menu.autoFarm:MenuElement({id = "autoEKillsteal", name = "Auto E Killsteal (No Poison)", value = true})
    
    -- Auto Settings - Configuration
    self.Menu.auto:MenuElement({id = "autoSettings", name = "--- Auto Settings ---", value = false})
    self.Menu.auto:MenuElement({id = "autoHarassRange", name = "Auto Harass Range", value = 850, min = 600, max = 1000, step = 25})
    self.Menu.auto:MenuElement({id = "harassManaThreshold", name = "Auto Harass Min Mana %", value = 40, min = 0, max = 100, step = 5})
    self.Menu.auto:MenuElement({id = "lasthitManaThreshold", name = "Auto Lasthit Min Mana %", value = 30, min = 0, max = 100, step = 5})
    self.Menu.auto:MenuElement({id = "lasthitNoPoisonManaThreshold", name = "Lasthit No Poison Min Mana %", value = 50, min = 0, max = 100, step = 5})
    self.Menu.auto:MenuElement({id = "ePoisonManaThreshold", name = "Auto E Poison Min Mana %", value = 20, min = 0, max = 100, step = 5})
    self.Menu.auto:MenuElement({id = "killstealManaThreshold", name = "Killsteal Min Mana %", value = 10, min = 0, max = 100, step = 5})
    
    -- Advanced
    self.Menu:MenuElement({type = MENU, id = "advanced", name = "Advanced Settings"})
    self.Menu.advanced:MenuElement({id = "qExtraRange", name = "Q Extra Range", value = 0, min = 0, max = 200, step = 25, tooltip = "Extra range for Q casting and drawing"})
    self.Menu.advanced:MenuElement({id = "qExtraRadius", name = "Q Extra Radius", value = 0, min = 0, max = 100, step = 25, tooltip = "Extra radius for Q circle hitbox - makes Q easier to hit"})
    self.Menu.advanced:MenuElement({id = "rRange", name = "R Casting Range", value = 650, min = 500, max = 825, step = 25, tooltip = "Adjust R range - lower values = less aggressive R usage"})
    self.Menu.advanced:MenuElement({id = "eDelay", name = "E Casting Delay (ms)", value = 50, min = 0, max = 200, step = 25})
    self.Menu.advanced:MenuElement({id = "poisonBuffer", name = "Poison Expiration Buffer", value = 0.141, min = 0.1, max = 0.3, step = 0.01})
    self.Menu.advanced:MenuElement({id = "rFacing", name = "R Only if Enemy Facing", value = true})
    self.Menu.advanced:MenuElement({id = "useAdvancedPrediction", name = "Use Advanced Prediction", value = true})
    self.Menu.advanced:MenuElement({id = "minHitChanceQ", name = "Min Q Hit Chance", value = 3, min = 1, max = 6, step = 1})
    self.Menu.advanced:MenuElement({id = "minHitChanceW", name = "Min W Hit Chance", value = 2, min = 1, max = 6, step = 1})
    self.Menu.advanced:MenuElement({id = "minHitChanceR", name = "Min R Hit Chance", value = 4, min = 1, max = 6, step = 1})
    self.Menu.advanced:MenuElement({id = "disableCloseRange", name = "Disable Spells When Enemy Too Close", value = true, tooltip = "Stops using spells when enemy is very close to avoid bad trades"})
    self.Menu.advanced:MenuElement({id = "closeRangeDistance", name = "Close Range Distance", value = 300, min = 100, max = 350, step = 25, tooltip = "Distance at which spells are disabled"})
    
    -- Drawing
    self.Menu:MenuElement({type = MENU, id = "drawing", name = "Drawing"})
    self.Menu.drawing:MenuElement({id = "Q", name = "Draw Q Range", value = true})
    self.Menu.drawing:MenuElement({id = "W", name = "Draw W Range", value = true})
    self.Menu.drawing:MenuElement({id = "E", name = "Draw E Range", value = true})
    self.Menu.drawing:MenuElement({id = "R", name = "Draw R Range", value = true})
    self.Menu.drawing:MenuElement({id = "poisoned", name = "Draw Poisoned Enemies", value = true})
    self.Menu.drawing:MenuElement({id = "killable", name = "Draw Killable Enemies", value = true})
    self.Menu.drawing:MenuElement({id = "cooldowns", name = "Draw Cooldown InfoBox", value = true})
    self.Menu.drawing:MenuElement({id = "predictionInfo", name = "Draw Prediction Info", value = true})
end

function Cassiopeia:Draw()
    if myHero.dead then return end
    
    local myPos = myHero.pos
    
    -- Draw Q Range
    if self.Menu.drawing.Q:Value() and Ready(_Q) then
        local qRange = self:GetQRange()
        Draw.Circle(myPos, qRange, Draw.Color(80, 255, 165, 0)) -- Q range with extra range
    end
    
    -- Draw W Range
    if self.Menu.drawing.W:Value() and Ready(_W) then
        Draw.Circle(myPos, 800, Draw.Color(80, 255, 255, 0)) -- W range
    end
    
    -- Draw E Range
    if self.Menu.drawing.E:Value() and Ready(_E) then
        Draw.Circle(myPos, 700, Draw.Color(80, 255, 0, 255)) -- E range
    end
    
    -- Draw R Range
    if self.Menu.drawing.R:Value() and Ready(_R) then
        Draw.Circle(myPos, self:GetRRange(), Draw.Color(80, 255, 0, 0)) -- R range dinámico
    end
    
    -- Draw Close Range Disable indicator
    if self.Menu.advanced.disableCloseRange:Value() then
        local closeRange = self.Menu.advanced.closeRangeDistance:Value()
        local isTooClose, closeEnemy = IsEnemyTooClose(closeRange)
        
        -- Draw close range circle
        local circleColor = isTooClose and Draw.Color(100, 255, 0, 0) or Draw.Color(60, 255, 165, 0)
        Draw.Circle(myPos, closeRange, circleColor)
        
        -- Draw text indicator if enemy is too close
        if isTooClose then
            local screenPos = myPos:To2D()
            if screenPos and screenPos.onScreen then
                Draw.Text("SPELLS DISABLED - ENEMY TOO CLOSE", 14, screenPos.x - 120, screenPos.y - 40, Draw.Color(255, 255, 50, 50))
            end
        end
    end
    
    -- Draw Poisoned Enemies
    if self.Menu.drawing.poisoned:Value() then
        for _, enemy in pairs(GetEnemyHeroes()) do
            if IsValid(enemy) and HasPoison(enemy) then
                local success, enemyPos = pcall(function() return enemy.pos:To2D() end)
                if success and enemyPos and enemyPos.onScreen then
                    Draw.Circle(enemy.pos, 100, Draw.Color(150, 0, 255, 0))
                    Draw.Text("POISONED", 16, enemyPos.x - 35, enemyPos.y - 40, Draw.Color(255, 0, 255, 0))
                end
            end
        end
    end
    
    -- Draw Killable Enemies
    if self.Menu.drawing.killable:Value() then
        for _, enemy in pairs(GetEnemyHeroes()) do
            if IsValid(enemy) and self:IsKillable(enemy) then
                local success, enemyPos = pcall(function() return enemy.pos:To2D() end)
                if success and enemyPos and enemyPos.onScreen then
                    Draw.Circle(enemy.pos, 150, Draw.Color(150, 255, 0, 0))
                    Draw.Text("KILLABLE", 18, enemyPos.x - 35, enemyPos.y - 60, Draw.Color(255, 255, 0, 0))
                end
            end
        end
    end
    
    -- Draw Cooldown InfoBox
    if self.Menu and self.Menu.drawing and self.Menu.drawing.cooldowns then
        self:DrawCooldownInfoBox()
    end
    
    -- Draw Prediction Information  
    if self.Menu and self.Menu.drawing and self.Menu.drawing.predictionInfo then
        self:DrawPredictionInfo()
    end
end

function Cassiopeia:DrawPredictionInfo()
    if myHero.dead or not self.Menu.drawing.predictionInfo:Value() then return end
    
    local target = self:GetHeroTarget(1000)
    if not target then return end
    
    -- Draw prediction visuals for current target
    local success, screenPos = pcall(function() return target.pos:To2D() end)
    if success and screenPos and screenPos.onScreen then
        -- Show basic target info
        local distance = GetDistance(myHero.pos, target.pos)
        local distanceText = string.format("Distance: %d", math.floor(distance))
        Draw.Text(distanceText, 12, screenPos.x + 30, screenPos.y - 20, Draw.Color(255, 255, 255, 255))
        
        -- Show poison status
        if HasPoison(target) then
            Draw.Text("POISONED", 12, screenPos.x + 30, screenPos.y - 5, Draw.Color(255, 0, 255, 0))
        else
            Draw.Text("NO POISON", 12, screenPos.x + 30, screenPos.y - 5, Draw.Color(255, 255, 0, 0))
        end
    end
end

function Cassiopeia:GetHitChanceText(hitChance)
    if hitChance == self.Prediction.HITCHANCE_IMMOBILE then
        return "IMMOBILE"
    elseif hitChance == self.Prediction.HITCHANCE_VERYHIGH then
        return "VERY HIGH"
    elseif hitChance == self.Prediction.HITCHANCE_HIGH then
        return "HIGH"
    elseif hitChance == self.Prediction.HITCHANCE_NORMAL then
        return "NORMAL"
    elseif hitChance == self.Prediction.HITCHANCE_LOW then
        return "LOW"
    elseif hitChance == self.Prediction.HITCHANCE_COLLISION then
        return "COLLISION"
    else
        return "IMPOSSIBLE"
    end
end

function Cassiopeia:GetHitChanceColor(hitChance)
    if hitChance == self.Prediction.HITCHANCE_IMMOBILE then
        return Draw.Color(255, 255, 0, 255) -- Magenta
    elseif hitChance == self.Prediction.HITCHANCE_VERYHIGH then
        return Draw.Color(255, 0, 255, 0) -- Green
    elseif hitChance == self.Prediction.HITCHANCE_HIGH then
        return Draw.Color(255, 100, 255, 0) -- Light Green
    elseif hitChance == self.Prediction.HITCHANCE_NORMAL then
        return Draw.Color(255, 255, 255, 0) -- Yellow
    elseif hitChance == self.Prediction.HITCHANCE_LOW then
        return Draw.Color(255, 255, 165, 0) -- Orange
    else
        return Draw.Color(255, 255, 0, 0) -- Red
    end
end

function Cassiopeia:DrawCooldownInfoBox()
    if myHero.dead then return end
    if not self.Menu.drawing.cooldowns:Value() then return end
    
    -- Initialize InfoBox position on first run
    if not self.infoBox.initialized then
        local screenWidth = Game.Resolution().x
        local screenHeight = Game.Resolution().y
        self.infoBox.x = screenWidth / 2 - self.infoBox.width / 2
        self.infoBox.y = screenHeight / 2 + 50
        self.infoBox.initialized = true
    end
    
    local boxX = self.infoBox.x
    local boxY = self.infoBox.y
    local boxWidth = self.infoBox.width
    local boxHeight = self.infoBox.height
    
    -- Mouse handling
    local mousePos = GetScreenMousePos()
    if mousePos then
        local isMouseInBox = mousePos.x >= boxX and mousePos.x <= boxX + boxWidth and 
                            mousePos.y >= boxY and mousePos.y <= boxY + boxHeight
        
        -- Drag detection
        local mousePressed = false
        pcall(function() mousePressed = Control.IsKeyDown(0x01) end)
        
        if isMouseInBox and mousePressed and not self.infoBox.isDragging then
            self.infoBox.isDragging = true
            self.infoBox.dragOffsetX = mousePos.x - boxX
            self.infoBox.dragOffsetY = mousePos.y - boxY
        end
        
        if self.infoBox.isDragging and not mousePressed then
            self.infoBox.isDragging = false
        end
        
        if self.infoBox.isDragging then
            self.infoBox.x = mousePos.x - self.infoBox.dragOffsetX
            self.infoBox.y = mousePos.y - self.infoBox.dragOffsetY
            
            -- Keep InfoBox within screen bounds
            local screenWidth = Game.Resolution().x
            local screenHeight = Game.Resolution().y
            self.infoBox.x = math.max(0, math.min(screenWidth - boxWidth, self.infoBox.x))
            self.infoBox.y = math.max(0, math.min(screenHeight - boxHeight, self.infoBox.y))
            
            boxX = self.infoBox.x
            boxY = self.infoBox.y
        end
    end
    
    -- Draw InfoBox background and border
    local bgColor = self.infoBox.isDragging and Draw.Color(200, 0, 0, 0) or Draw.Color(180, 0, 0, 0)
    local borderColor = self.infoBox.isDragging and Draw.Color(255, 255, 255, 0) or Draw.Color(255, 255, 0, 0)
    
    Draw.Rect(boxX, boxY, boxWidth, boxHeight, bgColor)
    Draw.Rect(boxX, boxY, boxWidth, 2, borderColor)
    Draw.Rect(boxX, boxY + boxHeight - 2, boxWidth, 2, borderColor)
    Draw.Rect(boxX, boxY, 2, boxHeight, borderColor)
    Draw.Rect(boxX + boxWidth - 2, boxY, 2, boxHeight, borderColor)
    
    -- Title
    local titleText = "CASSIOPEIA COOLDOWNS"
    local titleColor = self.infoBox.isDragging and Draw.Color(255, 255, 255, 0) or Draw.Color(255, 255, 255, 255)
    Draw.Text(titleText, 11, boxX + 5, boxY + 5, titleColor)
    
    -- Mode and mana info
    local currentMode = self:GetMode()
    if type(currentMode) ~= "string" then currentMode = "Unknown" end
    Draw.Text("Mode: " .. currentMode, 10, boxX + 5, boxY + 25, Draw.Color(255, 255, 255, 255))
    
    local manaPercent = math.floor(myHero.mana / myHero.maxMana * 100)
    local manaColor = manaPercent < 30 and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 0, 255, 255)
    Draw.Text("Mana: " .. manaPercent .. "%", 10, boxX + 5, boxY + 40, manaColor)
    
    -- Active options display
    local yOffset = 60
    if self.Menu.blockAA:Value() then
        Draw.Text("Block AA: ON", 10, boxX + 5, boxY + yOffset, Draw.Color(255, 255, 100, 100))
        yOffset = yOffset + 15
    end
    if self.Menu.autoMain.autoQPoison:Value() then
        Draw.Text("Auto Q Poison: ON", 10, boxX + 5, boxY + yOffset, Draw.Color(255, 0, 255, 0))
        yOffset = yOffset + 15
    end
    if self.Menu.autoMain.autoEPoison:Value() then
        Draw.Text("Auto E Poison: ON", 10, boxX + 5, boxY + yOffset, Draw.Color(255, 0, 255, 0))
        yOffset = yOffset + 15
    end
    
    -- Close Range Disable status
    if self.Menu.advanced.disableCloseRange:Value() then
        local closeRange = self.Menu.advanced.closeRangeDistance:Value()
        local isTooClose, closeEnemy = IsEnemyTooClose(closeRange)
        local statusColor = isTooClose and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 255, 255, 255)
        local statusText = isTooClose and "Close Range: DISABLED" or "Close Range: Active"
        Draw.Text(statusText, 10, boxX + 5, boxY + yOffset, statusColor)
    end
end

function Cassiopeia:Tick()
    if MyHeroNotReady() then return end
    local currentTime = GameTimer()
    -- Refresh enemy list every 0.5s
    if ShouldRun("enemyRefresh", 0.5) then
        Enemys = GetEnemyHeroes()
    end
    local ModeNow = self:GetMode()
    -- Manage AA block once per 0.25s (still responsive enough)
    if ShouldRun("aaBlock", 0.25) then
        if self.Menu.blockAA:Value() and ModeNow == "Combo" then self:BlockAutoAttacks() else self:EnableAutoAttacks() end
    end
    -- Auto features with individual throttles
    if self.Menu.autoMain.autoEPoison:Value() and ShouldRun("autoEPoison", 0.08) then self:AutoEPoison() end
    if self.Menu.autoFarm.autoELasthit:Value() and ModeNow ~= "Combo" and ShouldRun("autoELasthit", 0.12) then self:AutoELasthit() end
    if self.Menu.autoFarm.autoELasthitNoPoison:Value() and ModeNow ~= "Combo" and ShouldRun("autoELasthitNP", 0.15) then self:AutoELasthitNoPoison() end
    if self.Menu.autoMain.autoQPoison:Value() and ShouldRun("autoQPoison", 0.18) then self:AutoQPoison() end
    if self.Menu.autoFarm.autoEKillsteal:Value() and ShouldRun("autoEKill", 0.07) then self:AutoEKillsteal() end
    if self.Menu.autoMain.autoFlashR:Value() and ShouldRun("flashR", 0.25) then self:AutoFlashR() end
    if self.Menu.autoMain.antiGapcloser:Value() and ShouldRun("antiGap", 0.05) then self:AntiGapcloser() end
    -- Mode specific (lightweight) every tick, but internal casts already use last cast timers
    if ModeNow == "Combo" then self:Combo()
    elseif ModeNow == "Harass" then self:Harass()
    elseif ModeNow == "Clear" and ShouldRun("clearMode", 0.15) then self:Clear()
    elseif ModeNow == "LastHit" and ShouldRun("lastHitMode", 0.12) then self:LastHit() end
end

function Cassiopeia:AutoEPoison()
    -- Auto E Poison system - works independently when key is held
    if not Ready(_E) then return end
    
    -- Check if we should disable spells due to close enemy
    if self.Menu.advanced.disableCloseRange:Value() then
        local closeRange = self.Menu.advanced.closeRangeDistance:Value()
        local isTooClose, closeEnemy = IsEnemyTooClose(closeRange)
        if isTooClose then
            -- Don't use E when enemy is too close
            return
        end
    end
    
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.auto.ePoisonManaThreshold:Value() then return end
    
    -- Find best poisoned target
    local bestTarget = nil
    local bestPriority = 0
    
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if IsValid(enemy) and HasPoison(enemy) and GetDistance(myHero.pos, enemy.pos) <= self.E.range then
            local poisonTime = self:GetPoisonTimeRemaining(enemy)
            local priority = self:GetTargetPriority(enemy)
            
            -- Boost priority for targets with longer poison duration
            priority = priority + (poisonTime * 10)
            
            if priority > bestPriority then
                bestTarget = enemy
                bestPriority = priority
            end
        end
    end
    
    -- Cast E on best poisoned target
    if bestTarget then
        local timeSinceLastE = GameTimer() - self.lastECast
        local minDelay = 0.2 -- Minimum delay between E casts
        
        if timeSinceLastE >= minDelay then
            if self:CastE(bestTarget) then
                return
            end
        end
    end
end

function Cassiopeia:AutoELasthit()
    -- Auto E Lasthit system - runs when key is held
    if not Ready(_E) then return end
    
    -- NO mana check for minions since E on minions restores mana when killing them
    local minions = GetCachedMinions(self.E.range)
    local urgentMinions = {}
    
    -- Find minions that need immediate E to secure lasthit
    for i = 1, #minions do
        local minion = minions[i]
        if HasPoison(minion) then
            local eDamage = self:GetEDamage(minion)
            local poisonTime = self:GetPoisonTimeRemaining(minion)
            local healthPercent = minion.health / minion.maxHealth
            
            -- Urgent if: low health, will die from E, or poison running out
            if (minion.health <= eDamage and minion.health > eDamage * 0.4) or
               (poisonTime < 0.8 and healthPercent < 0.3) then
                table.insert(urgentMinions, {minion = minion, health = minion.health, poisonTime = poisonTime})
            end
        end
    end
    
    -- Sort by health (lowest first) then by poison time (shortest first)
    table.sort(urgentMinions, function(a, b)
        if a.health == b.health then
            return a.poisonTime < b.poisonTime
        end
        return a.health < b.health
    end)
    
    -- Cast E on most urgent minion
    if #urgentMinions > 0 then
        local timeSinceLastE = GameTimer() - self.lastECast
        if timeSinceLastE >= 0.2 then
            if self:CastE(urgentMinions[1].minion) then
                return
            end
        end
    end
end

function Cassiopeia:GetMode()
    -- Safety check for SDK availability
    if not _G.SDK or not _G.SDK.Orbwalker or not _G.SDK.Orbwalker.Modes then
        return "None"
    end
    
    -- Check each mode with safety checks
    local modes = _G.SDK.Orbwalker.Modes
    if modes[_G.SDK.ORBWALKER_MODE_COMBO] then
        return "Combo"
    elseif modes[_G.SDK.ORBWALKER_MODE_HARASS] then
        return "Harass"
    elseif modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
        return "Clear"
    elseif modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
        return "LastHit"
    end
    
    return "None"
end

function Cassiopeia:AutoQPoison()
    -- Auto Q to apply poison to enemies without poison
    if not Ready(_Q) then return end
    
    -- Check if we should disable spells due to close enemy
    if self.Menu.advanced.disableCloseRange:Value() then
        local closeRange = self.Menu.advanced.closeRangeDistance:Value()
        local isTooClose, closeEnemy = IsEnemyTooClose(closeRange)
        if isTooClose then
            -- Don't use Q when enemy is too close
            return
        end
    end
    
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < 30 then return end -- Save mana
    
    -- Get all enemy heroes in Q range (with extra range)
    local enemies = GetEnemyHeroes()
    local targets = {}
    local qRange = self:GetQRange()
    
    for _, enemy in pairs(enemies) do
        if IsValid(enemy) and not enemy.dead and GetDistance(myHero.pos, enemy.pos) <= qRange then
            -- Prioritize enemies without poison
            if not HasPoison(enemy) then
                table.insert(targets, {target = enemy, priority = 1, distance = GetDistance(myHero.pos, enemy.pos)})
            end
        end
    end
    
    -- Sort by priority (no poison first) then by distance (closest first)
    table.sort(targets, function(a, b)
        if a.priority == b.priority then
            return a.distance < b.distance
        end
        return a.priority > b.priority
    end)
    
    -- Cast Q on best target
    if #targets > 0 then
        local timeSinceLastQ = GameTimer() - self.lastQCast
        if timeSinceLastQ >= 0.5 then -- Don't spam Q too fast
            if self:CastQ(targets[1].target) then
                return
            end
        end
    end
end

function Cassiopeia:AutoEKillsteal()
    -- Auto E Killsteal for enemies without poison - highest priority
    if not Ready(_E) then return end
    
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.auto.killstealManaThreshold:Value() then return end
    
    -- Get all enemy heroes in E range
    local enemies = GetEnemyHeroes()
    local killableTargets = {}
    
    for _, enemy in pairs(enemies) do
        if IsValid(enemy) and not enemy.dead and GetDistance(myHero.pos, enemy.pos) <= self.E.range then
            -- Calculate E damage (GetEDamage already handles poison bonus automatically)
            local eDamage = self:GetEDamage(enemy)
            
            -- More aggressive killsteal - include targets that will be low after E
            local willKill = enemy.health <= eDamage
            local willBeLow = enemy.health <= eDamage * 1.2 -- Allow some buffer
            
            if willKill or willBeLow then
                local priority = willKill and 15 or 10 -- Higher priority for guaranteed kills
                
                -- MUCH higher priority if target has no poison (this is the main purpose)
                if not HasPoison(enemy) then
                    priority = priority + 10
                end
                
                -- Still prioritize poisoned if they're killable, but lower priority
                if HasPoison(enemy) then
                    priority = priority - 3
                end
                
                -- Boost priority for low health targets
                local healthPercent = enemy.health / enemy.maxHealth
                if healthPercent < 0.2 then
                    priority = priority + 5
                end
                
                table.insert(killableTargets, {
                    target = enemy, 
                    priority = priority, 
                    health = enemy.health,
                    distance = GetDistance(myHero.pos, enemy.pos),
                    willKill = willKill,
                    hasPoison = HasPoison(enemy)
                })
            end
        end
    end
    
    -- Sort by priority (highest first), then by health (lowest first)
    table.sort(killableTargets, function(a, b)
        if a.priority == b.priority then
            return a.health < b.health
        end
        return a.priority > b.priority
    end)
    
    -- Cast E on best killable target
    if #killableTargets > 0 then
        local bestTarget = killableTargets[1]
        local timeSinceLastE = GameTimer() - self.lastECast
        
        -- Very fast response for guaranteed kills, slightly slower for "low" targets
        local requiredDelay = bestTarget.willKill and 0.05 or 0.1
        
        if timeSinceLastE >= requiredDelay then
            -- Force cast E ignoring poison restrictions for killsteal
            if self:CastE(bestTarget.target, true) then
                return
            end
        end
    end
end

function Cassiopeia:AutoELasthitNoPoison()
    -- Auto E Lasthit for minions WITHOUT poison
    if not Ready(_E) then return end
    
    -- NO mana check for minions since E on minions restores mana when killing them
    local minions = GetCachedMinions(self.E.range)
    local lasthitTargets = {}
    
    -- Find minions that we can lasthit with E (prioritize those WITHOUT poison)
    for i = 1, #minions do
        local minion = minions[i]
        if IsValid(minion) and not minion.dead then
            -- Calculate E damage (without poison bonus for unpoisoned minions)
            local eDamage = self:GetEDamage(minion)
            local hasPoison = HasPoison(minion)
            
            -- Check if minion is killable with E
            if minion.health <= eDamage then
                local priority = 10 -- Base priority for killable minions
                
                -- MUCH higher priority for minions WITHOUT poison (this is the main purpose)
                if not hasPoison then
                    priority = priority + 15
                end
                
                -- Lower priority for poisoned minions (regular AutoELasthit should handle these)
                if hasPoison then
                    priority = priority - 8
                end
                
                -- Boost priority for low health minions (more urgent)
                local healthPercent = minion.health / minion.maxHealth
                if healthPercent < 0.15 then
                    priority = priority + 5
                end
                
                -- Boost priority for cannon minions
                if minion.charName and (string.find(minion.charName:lower(), "cannon") or string.find(minion.charName:lower(), "siege")) then
                    priority = priority + 10
                end
                
                table.insert(lasthitTargets, {
                    minion = minion,
                    priority = priority,
                    health = minion.health,
                    distance = GetDistance(myHero.pos, minion.pos),
                    hasPoison = hasPoison,
                    healthPercent = healthPercent
                })
            end
        end
    end
    
    -- Sort by priority (highest first), then by health (lowest first)
    table.sort(lasthitTargets, function(a, b)
        if a.priority == b.priority then
            return a.health < b.health
        end
        return a.priority > b.priority
    end)
    
    -- Cast E on best lasthit target
    if #lasthitTargets > 0 then
        local bestTarget = lasthitTargets[1]
        local timeSinceLastE = GameTimer() - self.lastECast
        
        -- Reasonable delay to prevent spam but allow responsive farming
        if timeSinceLastE >= 0.15 then
            -- Force cast E ignoring poison restrictions for lasthit
            if self:CastE(bestTarget.minion, true) then
                return
            end
        end
    end
end

function Cassiopeia:BlockAutoAttacks()
    -- Block only orbwalker auto attacks, not manual right-clicks
    if _G.SDK and _G.SDK.Orbwalker then
        -- Method 1: Disable orbwalker auto attacks
        if _G.SDK.Orbwalker.SetAttack then
            _G.SDK.Orbwalker:SetAttack(false)
        end
        
        -- Method 2: Keep movement enabled for manual control
        if _G.SDK.Orbwalker.SetMovement then
            _G.SDK.Orbwalker:SetMovement(true)
        end
    end
    
    -- Method 3: Block only orbwalker-initiated attacks, preserve manual control
    if _G.SDK and _G.SDK.Orbwalker.LastTarget and IsValid(_G.SDK.Orbwalker.LastTarget) then
        -- If orbwalker has a target and is trying to attack, redirect to movement
        if myHero.activeSpell and myHero.activeSpell.valid then
            local spellName = myHero.activeSpell.name
            if spellName and (spellName:lower():find("attack") or spellName:lower():find("basicattack")) then
                -- Only cancel if this was an orbwalker-initiated attack
                if _G.SDK.Orbwalker.GetMode and _G.SDK.Orbwalker:GetMode() ~= "None" then
                    Control.Move(myHero.pos)
                end
            end
        end
    end
end

function Cassiopeia:EnableAutoAttacks()
    -- Re-enable orbwalker auto attacks for lane clear and last hit modes
    if _G.SDK and _G.SDK.Orbwalker then
        -- Method 1: Enable orbwalker auto attacks
        if _G.SDK.Orbwalker.SetAttack then
            _G.SDK.Orbwalker:SetAttack(true)
        end
        
        -- Method 2: Keep movement enabled for normal orbwalker operation
        if _G.SDK.Orbwalker.SetMovement then
            _G.SDK.Orbwalker:SetMovement(true)
        end
    end
end

function Cassiopeia:GetFlashSlot()
    -- Detectar en qué slot está Flash
    local summoner1 = myHero:GetSpellData(SUMMONER_1)
    local summoner2 = myHero:GetSpellData(SUMMONER_2)
    
    -- Check summoner1
    if summoner1 and summoner1.name then
        local name = summoner1.name:lower()
        -- Check for various Flash name patterns
        if name:find("flash") or name:find("summonerflash") or name == "summonerdot" or name == "summonerflash" then
            return SUMMONER_1
        end
    end
    
    -- Check summoner2
    if summoner2 and summoner2.name then
        local name = summoner2.name:lower()
        -- Check for various Flash name patterns
        if name:find("flash") or name:find("summonerflash") or name == "summonerdot" or name == "summonerflash" then
            return SUMMONER_2
        end
    end
    
    return nil
end

function Cassiopeia:IsFlashReady()
    -- Update flash slot if not set or changed
    if not self.flashSlot then 
        self.flashSlot = self:GetFlashSlot()
        if not self.flashSlot then 
            return false 
        end
    end
    
    local spellData = myHero:GetSpellData(self.flashSlot)
    if not spellData then 
        return false 
    end
    
    -- Check if Flash is available (cooldown == 0)
    return spellData.currentCd == 0 and Game.CanUseSpell(self.flashSlot) == 0
end

function Cassiopeia:IsEnemyFacingMe(enemy)
    -- Verificar si el enemigo está mirando hacia nosotros
    if not enemy or not enemy.dir or not enemy.dir.x then return false end
    
    -- Vector de dirección del enemigo
    local enemyDir = {x = enemy.dir.x, z = enemy.dir.z}
    
    -- Vector desde el enemigo hacia nosotros
    local toMe = {
        x = myHero.pos.x - enemy.pos.x,
        z = myHero.pos.z - enemy.pos.z
    }
    
    -- Normalizar vectores
    local enemyDirMag = math.sqrt(enemyDir.x * enemyDir.x + enemyDir.z * enemyDir.z)
    local toMeMag = math.sqrt(toMe.x * toMe.x + toMe.z * toMe.z)
    
    if enemyDirMag == 0 or toMeMag == 0 then return false end
    
    enemyDir.x = enemyDir.x / enemyDirMag
    enemyDir.z = enemyDir.z / enemyDirMag
    toMe.x = toMe.x / toMeMag
    toMe.z = toMe.z / toMeMag
    
    -- Calcular producto punto
    local dotProduct = enemyDir.x * toMe.x + enemyDir.z * toMe.z
    
    -- Si el dot product es mayor a 0.5, está bastante mirando hacia nosotros (ángulo < 60°)
    return dotProduct > 0.5
end

function Cassiopeia:GetFlashRPosition(targetCenter, enemies)
    -- Calcular la mejor posición para Flash + R que cubra la mayoría de enemigos
    local bestPos = nil
    local maxEnemiesHit = 0
    
    -- Radio de área de efecto de R (forma de cono)
    local rWidth = 160 -- Ancho aproximado del R en el extremo
    local rRange = self:GetRRange() -- Usar rango dinámico de R
    
    -- Probar diferentes posiciones alrededor del centro de los enemigos
    for angle = 0, 360, 30 do -- Cada 30 grados
        local radians = math.rad(angle)
        local testPos = {
            x = targetCenter.x + math.cos(radians) * 300, -- 300 unidades del centro
            z = targetCenter.z + math.sin(radians) * 300
        }
        
        -- Verificar que la posición esté dentro del rango de Flash
        local flashDistance = GetDistance(myHero.pos, testPos)
        if flashDistance <= self.flashRange then
            
            -- Contar cuántos enemigos estarían en rango de R desde esta posición
            local enemiesInRange = 0
            local enemiesFacing = 0
            
            for _, enemy in pairs(enemies) do
                if IsValid(enemy) then
                    local distanceFromFlashPos = GetDistance(testPos, enemy.pos)
                    
                    -- Verificar si el enemigo estaría en rango de R
                    if distanceFromFlashPos <= rRange then
                        enemiesInRange = enemiesInRange + 1
                        
                        -- Verificar si estaría mirando hacia nosotros (simulando la posición post-flash)
                        local enemyDir = {x = enemy.dir.x, z = enemy.dir.z}
                        local toFlashPos = {
                            x = testPos.x - enemy.pos.x,
                            z = testPos.z - enemy.pos.z
                        }
                        
                        -- Normalizar
                        local enemyDirMag = math.sqrt(enemyDir.x * enemyDir.x + enemyDir.z * enemyDir.z)
                        local toFlashMag = math.sqrt(toFlashPos.x * toFlashPos.x + toFlashPos.z * toFlashPos.z)
                        
                        if enemyDirMag > 0 and toFlashMag > 0 then
                            enemyDir.x = enemyDir.x / enemyDirMag
                            enemyDir.z = enemyDir.z / enemyDirMag
                            toFlashPos.x = toFlashPos.x / toFlashMag
                            toFlashPos.z = toFlashPos.z / toFlashMag
                            
                            local dotProduct = enemyDir.x * toFlashPos.x + enemyDir.z * toFlashPos.z
                            
                            if dotProduct > 0.3 then -- Menos estricto para el flash
                                enemiesFacing = enemiesFacing + 1
                            end
                        end
                    end
                end
            end
            
            -- Priorizar posiciones que tengan más enemigos mirando hacia nosotros
            local score = enemiesFacing * 2 + enemiesInRange
            if score > maxEnemiesHit then
                maxEnemiesHit = score
                bestPos = testPos
            end
        end
    end
    
    return bestPos, maxEnemiesHit
end

function Cassiopeia:AutoFlashR()
    -- Auto Flash + R system (Flash first to extend R range)
    if not Ready(_R) then 
        return 
    end
    
    if not self:IsFlashReady() then 
        return 
    end
    
    -- Check if we should disable Flash+R due to very close enemy
    if self.Menu.advanced.disableCloseRange:Value() then
        local closeRange = self.Menu.advanced.closeRangeDistance:Value()
        local isTooClose, closeEnemy = IsEnemyTooClose(closeRange)
        if isTooClose then
            -- Don't Flash+R when enemy is very close, it's usually not worth it
            return
        end
    end
    
    -- Initialize lastFlashR if not set
    if not self.lastFlashR then self.lastFlashR = 0 end
    
    -- Verificar cooldown para evitar spam
    local currentTime = GameTimer()
    if currentTime - self.lastFlashR < 2.0 then 
        return 
    end -- 2 segundos de cooldown
    
    -- Verificar salud mínima - FIRST CHECK to avoid unnecessary Flash
    local healthPercent = myHero.health / myHero.maxHealth * 100
    if healthPercent < self.Menu.autoMain.flashRMinHealth:Value() then 
        return 
    end
    
    -- Calculate extended range: R range + Flash range
    local rRange = self:GetRRange() -- Usar rango dinámico de R
    local flashRange = self.flashRange -- 400
    local extendedRange = rRange + flashRange
    local maxConfigRange = self.Menu.autoMain.flashRMaxRange:Value()
    local maxRange = math.min(extendedRange, maxConfigRange)
    
    -- Find enemies in extended range but NOT in normal R range
    local enemies = GetEnemyHeroes()
    local flashTargets = {}
    
    for _, enemy in pairs(enemies) do
        if IsValid(enemy) and not enemy.dead then
            local distance = GetDistance(myHero.pos, enemy.pos)
            
            -- Target must be:
            -- 1. Beyond normal R range (otherwise we don't need Flash)
            -- 2. Within extended Flash+R range
            -- 3. Facing us is preferred but not mandatory
            if distance > rRange and distance <= maxRange then
                local isFacing = self:IsEnemyFacingMe(enemy)
                table.insert(flashTargets, {
                    enemy = enemy,
                    distance = distance,
                    priority = self:GetTargetPriority(enemy) + (isFacing and 20 or 0) -- Bonus for facing
                })
            end
        end
    end
    
    -- Check if we have enough enemies for the combo
    if #flashTargets < self.Menu.autoMain.flashRMinEnemies:Value() then 
        return 
    end
    
    -- Sort by priority (highest first) then by distance (closest first)
    table.sort(flashTargets, function(a, b)
        if a.priority == b.priority then
            return a.distance < b.distance
        end
        return a.priority > b.priority
    end)
    
    -- Execute Flash + R combo ONLY if we can cast R
    local primaryTarget = flashTargets[1].enemy
    if primaryTarget then
        -- Calculate optimal Flash position
        local flashPos = self:CalculateFlashRPosition(primaryTarget, flashTargets)
        
        if flashPos then
            -- Flash first - Cast Flash with proper summoner spell casting
            local flashPos3D = Vector(flashPos.x, myHero.pos.y, flashPos.z)
            
            -- Cast Flash using summoner spell
            if self.flashSlot == SUMMONER_1 then
                Control.CastSpell(HK_SUMMONER_1, flashPos3D)
            elseif self.flashSlot == SUMMONER_2 then
                Control.CastSpell(HK_SUMMONER_2, flashPos3D)
            end
            
            -- Set cooldown immediately to prevent spam
            self.lastFlashR = currentTime
            
            -- Cast R after Flash with minimal delay - ALWAYS cast R after Flash
            DelayAction(function()
                if IsValid(primaryTarget) then
                    -- Force cast R regardless of prediction - if we Flashed, we commit to the R
                    local rTarget = primaryTarget.pos
                    
                    -- Try prediction first for better accuracy
                    if Ready(_R) and self.R and self.R.spell then
                        local rPrediction = self.R.spell:GetPrediction(primaryTarget, myHero.pos)
                        if rPrediction and rPrediction.CastPosition then
                            rTarget = rPrediction.CastPosition
                        end
                    end
                    
                    -- ALWAYS cast R after Flash - no conditions, we committed to the combo
                    Control.CastSpell(HK_R, rTarget)
                    self.lastRCast = GameTimer()
                end
            end, 0.15) -- 150ms delay for Flash animation
            
            return
        end
    end
end

function Cassiopeia:CalculateFlashRPosition(primaryTarget, allTargets)
    -- Calculate the best Flash position to maximize R effectiveness
    local targetPos = primaryTarget.pos
    local myPos = myHero.pos
    
    -- Calculate direction from us to primary target
    local distance = GetDistance(myPos, targetPos)
    if distance <= self:GetRRange() then
        return nil -- Don't need Flash if already in R range
    end
    
    local direction = {
        x = (targetPos.x - myPos.x) / distance,
        z = (targetPos.z - myPos.z) / distance
    }
    
    -- Flash towards the target to get in R range
    local flashDistance = math.min(self.flashRange, distance - self:GetRRange() + 100) -- +100 margin for safety
    
    -- Ensure we flash at least some distance
    if flashDistance < 150 then
        flashDistance = math.min(self.flashRange, 150)
    end
    
    -- Calculate Flash position
    local flashPos = {
        x = myPos.x + direction.x * flashDistance,
        z = myPos.z + direction.z * flashDistance
    }
    
    -- Validate that from Flash position, we can hit the target with R
    local flashToTargetDist = GetDistance(flashPos, targetPos)
    
    if flashToTargetDist <= self:GetRRange() then
        return flashPos
    end
    
    return nil
end

function Cassiopeia:AntiGapcloser()
    -- Anti-Gapcloser system using R to counter enemy dashes
    if not Ready(_R) then return end
    
    -- Check cooldown to prevent spam
    local currentTime = GameTimer()
    if currentTime - self.lastAntiGapcloser < 0.5 then return end -- 0.5 second cooldown
    
    local antiGapRange = self.Menu.autoMain.antiGapcloserRange:Value()
    local enemies = GetEnemyHeroes()
    
    -- Update enemy positions and detect dashes
    for _, enemy in pairs(enemies) do
        if IsValid(enemy) and not enemy.dead then
            local enemyId = enemy.networkID
            local currentPos = enemy.pos
            local distance = GetDistance(myHero.pos, currentPos)
            
            -- Only check enemies within anti-gapcloser range
            if distance <= antiGapRange then
                -- Initialize position tracking for new enemies
                if not self.enemyPositions[enemyId] then
                    self.enemyPositions[enemyId] = {
                        lastPos = currentPos,
                        lastUpdate = currentTime,
                        speed = 0
                    }
                else
                    local lastData = self.enemyPositions[enemyId]
                    local timeDiff = currentTime - lastData.lastUpdate
                    
                    -- Only check if enough time has passed
                    if timeDiff > 0.1 then -- Check every 100ms
                        local distanceMoved = GetDistance(lastData.lastPos, currentPos)
                        local speed = distanceMoved / timeDiff
                        
                        -- Detect dash: high speed movement towards us
                        local isDashing = speed > 800 -- 800+ units per second indicates dash/blink
                        
                        if isDashing then
                            -- Check if enemy is moving towards us
                            local directionToUs = {
                                x = myHero.pos.x - lastData.lastPos.x,
                                z = myHero.pos.z - lastData.lastPos.z
                            }
                            local directionMoving = {
                                x = currentPos.x - lastData.lastPos.x,
                                z = currentPos.z - lastData.lastPos.z
                            }
                            
                            -- Normalize vectors
                            local toUsMag = math.sqrt(directionToUs.x^2 + directionToUs.z^2)
                            local movingMag = math.sqrt(directionMoving.x^2 + directionMoving.z^2)
                            
                            if toUsMag > 0 and movingMag > 0 then
                                directionToUs.x = directionToUs.x / toUsMag
                                directionToUs.z = directionToUs.z / toUsMag
                                directionMoving.x = directionMoving.x / movingMag
                                directionMoving.z = directionMoving.z / movingMag
                                
                                -- Calculate dot product (how aligned the movement is towards us)
                                local dotProduct = directionToUs.x * directionMoving.x + directionToUs.z * directionMoving.z
                                
                                -- If enemy is dashing towards us (dot product > 0.3)
                                if dotProduct > 0.3 and distance <= self.R.range then
                                    -- Calculate predicted destination position
                                    local predictedPos = self:CalculateDashDestination(enemy, lastData.lastPos, currentPos, speed)
                                    
                                    -- Cast R at the predicted destination if it's within range
                                    if predictedPos and GetDistance(myHero.pos, predictedPos) <= self.R.range then
                                        if self:CastRAntiGapcloserAtPosition(enemy, predictedPos) then
                                            self.lastAntiGapcloser = currentTime
                                            return
                                        end
                                    end
                                end
                            end
                        end
                        
                        -- Update tracking data
                        lastData.lastPos = currentPos
                        lastData.lastUpdate = currentTime
                        lastData.speed = speed
                    end
                end
            end
        end
    end
    
    -- Clean up old position data to prevent memory leaks
    if currentTime % 5 < 0.1 then -- Every 5 seconds
        for enemyId, data in pairs(self.enemyPositions) do
            if currentTime - data.lastUpdate > 10 then -- Remove data older than 10 seconds
                self.enemyPositions[enemyId] = nil
            end
        end
    end
end

function Cassiopeia:CalculateDashDestination(enemy, lastPos, currentPos, speed)
    -- Calculate the predicted destination of the enemy's dash
    local timeDiff = 0.1 -- Time difference between position updates
    local direction = {
        x = currentPos.x - lastPos.x,
        z = currentPos.z - lastPos.z
    }
    
    -- Normalize direction
    local magnitude = math.sqrt(direction.x^2 + direction.z^2)
    if magnitude == 0 then return nil end
    
    direction.x = direction.x / magnitude
    direction.z = direction.z / magnitude
    
    -- Predict how much further the enemy will move based on current speed
    -- Most dashes are around 400-600 units, so we predict based on typical dash ranges
    local dashRange = math.min(speed * 0.5, 600) -- Limit prediction to reasonable dash range
    
    -- Calculate predicted destination
    local predictedPos = {
        x = currentPos.x + direction.x * dashRange,
        z = currentPos.z + direction.z * dashRange,
        y = currentPos.y
    }
    
    -- Make sure the predicted position is not too far from us (within our threat range)
    local distanceToDestination = GetDistance(myHero.pos, predictedPos)
    if distanceToDestination > 1000 then -- Don't predict beyond 1000 units
        -- Scale back the prediction to a more reasonable distance
        local scaleFactor = 1000 / distanceToDestination
        predictedPos.x = myHero.pos.x + (predictedPos.x - myHero.pos.x) * scaleFactor
        predictedPos.z = myHero.pos.z + (predictedPos.z - myHero.pos.z) * scaleFactor
    end
    
    return predictedPos
end

function Cassiopeia:CastRAntiGapcloserAtPosition(target, position)
    -- Cast R at a specific position for anti-gapcloser
    if not Ready(_R) or not IsValid(target) or not position then return false end
    
    local distance = GetDistance(myHero.pos, position)
    if distance > self:GetRRange() then return false end
    
    -- Cast R at the predicted destination position
    Control.CastSpell(HK_R, Vector(position.x, position.y, position.z))
    self.lastRCast = GameTimer()
    return true
end

function Cassiopeia:CastRAntiGapcloser(target)
    -- Special R casting for anti-gapcloser (more permissive hit chance)
    if not Ready(_R) or not IsValid(target) then return false end
    
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > self:GetRRange() then return false end
    
    -- For anti-gapcloser, we're more aggressive with R usage
    -- Don't check if enemy is facing us since they're dashing
    
    -- Use prediction but with lower hit chance requirement
    local prediction = self.R.spell:GetPrediction(target, myHero.pos)
    local minHitChance = 2 -- Lower hit chance for anti-gapcloser (HITCHANCE_LOW)
    
    if prediction.HitChance >= minHitChance then
        Control.CastSpell(HK_R, prediction.CastPosition)
        self.lastRCast = GameTimer()
        return true
    end
    
    -- Fallback: cast at current position if prediction fails
    Control.CastSpell(HK_R, target.pos)
    self.lastRCast = GameTimer()
    return true
end

function Cassiopeia:OnPostAttack(target)
    -- Auto attack reset with E if target is poisoned and settings allow it
    if IsValid(target) and target.type == Obj_AI_Hero and Ready(_E) then
        local mode = self:GetMode()
        local shouldCastE = false
        
        -- Check Auto E after Auto Attack setting
        if not self.Menu.autoMain.autoEPostAttack:Value() then
            return -- Auto E post attack is disabled
        end
        
        -- Check if we should cast E based on current mode and poison settings
        if mode == "Combo" then
            if self.Menu.combo.eOnlyPoison:Value() then
                shouldCastE = HasPoison(target)
            else
                shouldCastE = true
            end
        elseif mode == "Harass" then
            if self.Menu.harass.eOnlyPoison:Value() then
                shouldCastE = HasPoison(target)
            else
                shouldCastE = true
            end
        else
            -- For other modes, only cast if poisoned
            shouldCastE = HasPoison(target)
        end
        
        if shouldCastE then
            Control.CastSpell(HK_E, target)
        end
    end
end

function Cassiopeia:Combo()
    local target = self:GetHeroTarget(850) -- Fixed combo range
    if not target then return end
    
    -- Check if we should disable spells due to close enemy
    if self.Menu.advanced.disableCloseRange:Value() then
        local closeRange = self.Menu.advanced.closeRangeDistance:Value()
        local isTooClose, closeEnemy = IsEnemyTooClose(closeRange)
        if isTooClose then
            -- Only allow movement, no spells when enemy is too close
            return
        end
    end
    
    local distance = GetDistance(myHero.pos, target.pos)
    local rRange = self:GetRRange() -- Usar rango dinámico de R
    
    -- Ultimate (R) logic - highest priority for kill potential or multi-target
    if self.Menu.combo.useR:Value() and Ready(_R) and distance <= rRange then
        local shouldUseR = false
        
        -- Use R if target is killable
        if self.Menu.combo.rKillable:Value() and self:IsKillable(target) then
            shouldUseR = true
        end
        
        -- Use R if minimum enemy count is met
        local enemiesInRange = self:GetEnemiesInRange(rRange)
        if #enemiesInRange >= self.Menu.combo.rMinEnemies:Value() then
            shouldUseR = true
        end
        
        -- Enhanced R casting with prediction analysis
        if shouldUseR then
            local rPrediction = self.R.spell:GetPrediction(target, myHero.pos)
            if rPrediction.HitChance >= self.Prediction.HITCHANCE_HIGH then
                if self:CastR(target) then
                    return
                end
            end
        end
    end
    
    -- Auto E Poison - Spam E on targets (respecting poison settings)
    if self.Menu.combo.eSpam:Value() and Ready(_E) and distance <= self.E.range then
        -- Add delay to prevent excessive spam
        local timeSinceLastE = GameTimer() - self.lastECast
        local minDelay = self.Menu.combo.eSpamDelay:Value() / 1000 -- Convert ms to seconds
        
        if timeSinceLastE >= minDelay then
            -- Respect the "E Only on Poisoned" setting
            local canCastE = true
            if self.Menu.combo.eOnlyPoison:Value() then
                canCastE = HasPoison(target)
            end
            
            if canCastE then
                -- Smart E spamming - check poison time remaining to avoid waste (if poisoned)
                local shouldCast = true
                if HasPoison(target) then
                    local poisonTime = self:GetPoisonTimeRemaining(target)
                    shouldCast = poisonTime > 0.5 or target.health < self:GetEDamage(target) * 2
                end
                
                if shouldCast and self:CastE(target) then
                    return
                end
            end
        end
    end
    
    -- Enhanced Q casting with smart prediction
    if self.Menu.combo.useQ:Value() and Ready(_Q) and distance <= self:GetQRange() then
        if GameTimer() - self.lastQCast > 0.3 then -- Prevent spam
            local qPrediction = self.Q.spell:GetPrediction(target, myHero.pos)
            -- Use Q if we have good hit chance or target is immobile
            if qPrediction.HitChance >= self.Prediction.HITCHANCE_NORMAL or 
               qPrediction.HitChance == self.Prediction.HITCHANCE_IMMOBILE then
                if self:CastQ(target) then
                    return
                end
            end
        end
    end
    
    -- Enhanced W casting for area control
    if self.Menu.combo.useW:Value() and Ready(_W) and distance <= self.W.range then
        if GameTimer() - self.lastWCast > 0.5 then -- Prevent spam
            local wPrediction = self.W.spell:GetPrediction(target, myHero.pos)
            -- W is more for area denial, so we can be more liberal with hit chance
            if wPrediction.HitChance >= self.Prediction.HITCHANCE_LOW then
                if self:CastW(target) then
                    return
                end
            end
        end
    end
    
    -- Enhanced E casting with proper poison validation
    if self:ShouldCastE(target, "Combo") and GameTimer() - self.lastECast > 0.5 then
        if self:CastE(target) then
            return
        end
    end
end

function Cassiopeia:Harass()
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.harass.manaThreshold:Value() then return end
    
    local target = self:GetHeroTarget(850)
    if not target then return end
    
    -- Check if we should disable spells due to close enemy
    if self.Menu.advanced.disableCloseRange:Value() then
        local closeRange = self.Menu.advanced.closeRangeDistance:Value()
        local isTooClose, closeEnemy = IsEnemyTooClose(closeRange)
        if isTooClose then
            -- Only allow movement, no spells when enemy is too close
            return
        end
    end
    
    local distance = GetDistance(myHero.pos, target.pos)
    
    -- Enhanced E casting with proper validation
    if self:ShouldCastE(target, "Harass") then
        if self:CastE(target) then
            return
        end
    end
    
    -- Cast Q for poke
    if self.Menu.harass.useQ:Value() and Ready(_Q) and distance <= self:GetQRange() then
        if self:CastQ(target) then
            return
        end
    end
    
    -- Cast W if enabled
    if self.Menu.harass.useW:Value() and Ready(_W) and distance <= self.W.range then
        if self:CastW(target) then
            return
        end
    end
end

function Cassiopeia:GetJungleMonstersInRange(range)
    local monsters = {}
    for i = 1, Game.MinionCount() do
        local monster = Game.Minion(i)
        if IsValid(monster) and monster.team == TEAM_NEUTRAL and GetDistance(myHero.pos, monster.pos) <= range then
            TableInsert(monsters, monster)
        end
    end
    return monsters
end

-- Helper functions for casting spells
function Cassiopeia:CastQ(target)
    if not Ready(_Q) or not target then return false end
    
    -- Check if target is within extended Q range
    local qRange = self:GetQRange()
    if GetDistance(myHero.pos, target.pos) > qRange then return false end
    
    -- Update Q spell with current radius settings
    self:UpdateQSpell()
    
    local qPrediction = self.Q.spell:GetPrediction(target, myHero.pos)
    if qPrediction.HitChance >= self.Menu.advanced.minHitChanceQ:Value() then
        Control.CastSpell(HK_Q, qPrediction.CastPosition)
        self.lastQCast = GameTimer()
        return true
    end
    return false
end

function Cassiopeia:CastW(target)
    if not Ready(_W) or not target then return false end
    
    local wPrediction = self.W.spell:GetPrediction(target, myHero.pos)
    if wPrediction.HitChance >= self.Menu.advanced.minHitChanceW:Value() then
        Control.CastSpell(HK_W, wPrediction.CastPosition)
        self.lastWCast = GameTimer()
        return true
    end
    return false
end

function Cassiopeia:CastE(target, forcecast)
    if not Ready(_E) or not target then return false end
    
    -- Only check poison requirement if forcecast is specifically false (for killsteal/lasthit override)
    -- Normal combo usage should be handled by ShouldCastE function
    if forcecast == false and not HasPoison(target) then
        return false
    end
    
    if GetDistance(myHero.pos, target.pos) <= self.E.range then
        Control.CastSpell(HK_E, target)
        self.lastECast = GameTimer()
        return true
    end
    return false
end

function Cassiopeia:CastR(target)
    if not Ready(_R) or not target then return false end
    
    local rPrediction = self.R.spell:GetPrediction(target, myHero.pos)
    if rPrediction.HitChance >= self.Menu.advanced.minHitChanceR:Value() then
        Control.CastSpell(HK_R, rPrediction.CastPosition)
        self.lastRCast = GameTimer()
        return true
    end
    return false
end

function Cassiopeia:GetHeroTarget(range)
    local target = GetTarget(range)
    return target
end

function Cassiopeia:IsKillable(target)
    if not target then return false end
    
    local totalDamage = 0
    local distance = GetDistance(myHero.pos, target.pos)
    
    -- Q damage with extended range
    if Ready(_Q) and distance <= self:GetQRange() then
        totalDamage = totalDamage + self:GetQDamage(target)
    end
    
    -- W damage
    if Ready(_W) and distance <= self.W.range then
        totalDamage = totalDamage + self:GetWDamage(target)
    end
    
    -- E damage
    if Ready(_E) and distance <= self.E.range then
        totalDamage = totalDamage + self:GetEDamage(target)
    end
    
    -- R damage
    if Ready(_R) and distance <= self:GetRRange() then
        totalDamage = totalDamage + self:GetRDamage(target)
    end
    
    return target.health <= totalDamage
end

function Cassiopeia:GetQDamage(target)
    if not target then return 0 end
    local qLevel = myHero:GetSpellData(_Q).level
    if qLevel == 0 then return 0 end
    
    local baseDamage = {75, 110, 145, 180, 215}
    local apRatio = 0.9
    local damage = baseDamage[qLevel] + (myHero.ap * apRatio)
    
    return damage
end

function Cassiopeia:GetWDamage(target)
    if not target then return 0 end
    local wLevel = myHero:GetSpellData(_W).level
    if wLevel == 0 then return 0 end
    
    local baseDamage = {20, 25, 30, 35, 40}
    local apRatio = 0.15
    local damage = baseDamage[wLevel] + (myHero.ap * apRatio)
    
    return damage * 5 -- Approximate total damage over time
end

function Cassiopeia:GetEDamage(target)
    if not target then return 0 end
    local eLevel = myHero:GetSpellData(_E).level
    if eLevel == 0 then return 0 end
    
    local baseDamage = {50, 85, 120, 155, 190}
    local apRatio = 0.6
    local damage = baseDamage[eLevel] + (myHero.ap * apRatio)
    
    -- Bonus damage if poisoned
    if HasPoison(target) then
        damage = damage * 1.5 -- Approximate bonus damage
    end
    
    return damage
end

function Cassiopeia:GetRDamage(target)
    if not target then return 0 end
    local rLevel = myHero:GetSpellData(_R).level
    if rLevel == 0 then return 0 end
    
    local baseDamage = {150, 250, 350}
    local apRatio = 0.5
    local damage = baseDamage[rLevel] + (myHero.ap * apRatio)
    
    return damage
end

function Cassiopeia:GetMinionsInRange(range)
    local minions = {}
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if IsValid(minion) and minion.isEnemy and GetDistance(myHero.pos, minion.pos) <= range then
            TableInsert(minions, minion)
        end
    end
    return minions
end

function Cassiopeia:GetPoisonTimeRemaining(target)
    if not target or not target.buffCount then return 0 end
    
    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and buff.type == 24 then
            return math.max(0, buff.expireTime - GameTimer())
        end
    end
    return 0
end

function Cassiopeia:GetTargetPriority(target)
    if not target then return 0 end
    
    local priority = 1
    
    -- Higher priority for low health
    local healthPercent = target.health / target.maxHealth
    if healthPercent < 0.3 then
        priority = priority + 3
    elseif healthPercent < 0.6 then
        priority = priority + 1
    end
    
    -- Higher priority for ADC and mages
    if target.charName then
        local charName = target.charName:lower()
        if charName:find("jinx") or charName:find("caitlyn") or charName:find("vayne") or 
           charName:find("xerath") or charName:find("syndra") or charName:find("leblanc") then
            priority = priority + 2
        end
    end
    
    return priority
end

function Cassiopeia:GetEnemiesInRange(range)
    local enemies = {}
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if IsValid(enemy) and GetDistance(myHero.pos, enemy.pos) <= range then
            TableInsert(enemies, enemy)
        end
    end
    return enemies
end

function Cassiopeia:LastHit()
    if not self.Menu.lasthit.useE:Value() then return end
    
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.lasthit.manaThreshold:Value() then return end
    
    local minions = self:GetMinionsInRange(self.E.range)
    for i = 1, #minions do
        local minion = minions[i]
        if HasPoison(minion) then
            local eDamage = self:GetEDamage(minion)
            if minion.health <= eDamage then
                if self:CastE(minion) then
                    return
                end
            end
        end
    end
end

function Cassiopeia:Clear()
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.clear.manaThreshold:Value() then return end
    
    -- Get both minions and jungle monsters
    local minions = GetCachedMinions(850)
    local monsters = self:GetJungleMonstersInRange(850)
    local allTargets = {}
    
    -- Combine minions and monsters into one table
    for i = 1, #minions do
        TableInsert(allTargets, minions[i])
    end
    for i = 1, #monsters do
        TableInsert(allTargets, monsters[i])
    end
    
    if #allTargets == 0 then return end
    
    -- Use E on targets (respecting poison settings)
    if self.Menu.clear.useE:Value() and Ready(_E) then
        for i = 1, #allTargets do
            local target = allTargets[i]
            if GetDistance(myHero.pos, target.pos) <= self.E.range then
                -- Check poison requirement setting
                if self.Menu.clear.eOnlyPoison:Value() then
                    -- Only cast E on poisoned minions when option is enabled
                    if HasPoison(target) then
                        if self:CastE(target) then
                            return
                        end
                    end
                else
                    -- Cast E on any minion when option is disabled
                    if self:CastE(target) then
                        return
                    end
                end
            end
        end
    end
    
    -- Use Q for clear (prioritize jungle monsters for higher damage)
    if self.Menu.clear.useQ:Value() and Ready(_Q) then
        -- First try to hit jungle monsters
        if #monsters > 0 then
            local bestMonsterPos = self:GetBestQPositionForTargets(monsters)
            if bestMonsterPos then
                Control.CastSpell(HK_Q, bestMonsterPos)
                self.lastQCast = GameTimer()
                return
            end
        end
        
        -- Then try minions if no good monster position
        if #minions > 0 then
            local bestMinionPos = self:GetBestQPositionForTargets(minions)
            if bestMinionPos then
                Control.CastSpell(HK_Q, bestMinionPos)
                self.lastQCast = GameTimer()
                return
            end
        end
    end
    
    -- Use W for clear
    if self.Menu.clear.useW:Value() and Ready(_W) then
        local targetList = {}
        for i = 1, #allTargets do
            if GetDistance(myHero.pos, allTargets[i].pos) <= self.W.range then
                TableInsert(targetList, allTargets[i])
            end
        end
        
        if #targetList >= self.Menu.clear.minMinionsW:Value() then
            local bestPos = self:GetBestWPositionForTargets(targetList)
            if bestPos then
                Control.CastSpell(HK_W, bestPos)
                self.lastWCast = GameTimer()
                return
            end
        end
    end
end

function Cassiopeia:GetClosestTarget(targets, maxRange)
    local closestTarget = nil
    local closestDistance = math.huge
    
    for i = 1, #targets do
        local target = targets[i]
        if IsValid(target) then
            local distance = GetDistance(myHero.pos, target.pos)
            if distance <= maxRange and distance < closestDistance then
                closestTarget = target
                closestDistance = distance
            end
        end
    end
    
    return closestTarget
end

function Cassiopeia:GetBestQPositionForTargets(targets)
    if #targets == 0 then return nil end
    
    -- For multiple targets, try to find position that hits the most
    local bestPos = nil
    local maxHits = 0
    local qRadius = self:GetQRadius() -- Use dynamic Q radius
    
    for i = 1, #targets do
        local target = targets[i]
        if IsValid(target) then
            local hits = 1
            -- Count how many other targets are within Q radius
            for j = 1, #targets do
                if j ~= i and IsValid(targets[j]) then
                    if GetDistance(target.pos, targets[j].pos) <= qRadius then
                        hits = hits + 1
                    end
                end
            end
            
            if hits > maxHits then
                maxHits = hits
                bestPos = target.pos
            end
        end
    end
    
    return bestPos
end

function Cassiopeia:GetBestWPositionForTargets(targets)
    if #targets == 0 then return nil end
    
    -- For W, find position that hits the most targets
    local bestPos = nil
    local maxHits = 0
    
    for i = 1, #targets do
        local target = targets[i]
        if IsValid(target) then
            local hits = 1
            -- Count how many other targets are within W radius
            for j = 1, #targets do
                if j ~= i and IsValid(targets[j]) then
                    if GetDistance(target.pos, targets[j].pos) <= self.W.width then
                        hits = hits + 1
                    end
                end
            end
            
            if hits > maxHits then
                maxHits = hits
                bestPos = target.pos
            end
        end
    end
    
    return bestPos
end

function Cassiopeia:GetBestQPositionForTargets(targets)
    if #targets == 0 then return nil end
    
    -- For multiple targets, try to find position that hits the most
    local bestPos = nil
    local maxHits = 0
    local qRange = self:GetQRange() -- Use dynamic Q range
    local qRadius = self:GetQRadius() -- Use dynamic Q radius
    
    for i = 1, #targets do
        local target = targets[i]
        if IsValid(target) and GetDistance(myHero.pos, target.pos) <= qRange then
            local pos = target.pos
            local hitCount = 0
            
            -- Count how many targets this position would hit
            for j = 1, #targets do
                if GetDistance(pos, targets[j].pos) <= qRadius then
                    hitCount = hitCount + 1
                end
            end
            
            if hitCount > maxHits then
                maxHits = hitCount
                bestPos = pos
            end
        end
    end
    
    return bestPos
end

function Cassiopeia:GetBestWPositionForTargets(targets)
    if #targets == 0 then return nil end
    
    -- For W, find position that covers the most targets
    local bestPos = nil
    local maxHits = 0
    
    for i = 1, #targets do
        local target = targets[i]
        if IsValid(target) and GetDistance(myHero.pos, target.pos) <= self.W.range then
            local pos = target.pos
            local hitCount = 0
            
            -- Count how many targets this position would hit
            for j = 1, #targets do
                if GetDistance(pos, targets[j].pos) <= self.W.width then
                    hitCount = hitCount + 1
                end
            end
            
            if hitCount > maxHits then
                maxHits = hitCount
                bestPos = pos
            end
        end
    end
    
    return bestPos
end

function Cassiopeia:LastHit()
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.lasthit.manaThreshold:Value() then return end
    
    if not self.Menu.lasthit.useE:Value() or not Ready(_E) then return end
    
    local minions = self:GetMinionsInRange(self.E.range)
    local bestMinion = nil
    local lowestHealth = math.huge
    
    -- Enhanced Auto E Lasthit - prioritize lowest health poisoned minions
    for i = 1, #minions do
        local minion = minions[i]
        if HasPoison(minion) and self:CanLastHitWithE(minion) then
            if minion.health < lowestHealth then
                bestMinion = minion
                lowestHealth = minion.health
            end
        end
    end
    
    -- Cast E on the best minion target
    if bestMinion then
        if self:CastE(bestMinion) then
            return
        end
    end
    
    -- Backup logic: look for minions that will die soon from poison and need E to secure
    for i = 1, #minions do
        local minion = minions[i]
        if HasPoison(minion) then
            local poisonTime = self:GetPoisonTimeRemaining(minion)
            local eDamage = self:GetEDamage(minion)
            
            -- If minion will die from E and poison time is running out
            if minion.health <= eDamage and poisonTime < 1.0 then
                if self:CastE(minion) then
                    return
                end
            end
        end
    end
end

-- Spell casting functions
function Cassiopeia:CastQ(target)
    if not Ready(_Q) or not IsValid(target) then return false end
    
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > self:GetQRange() then return false end -- Use dynamic Q range
    
    -- Update Q spell with current radius settings
    self:UpdateQSpell()
    
    -- Use DepressivePrediction system with configurable hit chance
    local prediction = self.Q.spell:GetPrediction(target, myHero.pos)
    local minHitChance = self.Menu.advanced.minHitChanceQ:Value()
    
    if prediction.HitChance >= minHitChance then
        Control.CastSpell(HK_Q, prediction.CastPosition)
        self.lastQCast = GameTimer()
        return true
    end
    
    return false
end

function Cassiopeia:CastW(target)
    if not Ready(_W) or not IsValid(target) then return false end
    
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > self.W.range then return false end
    
    -- Use DepressivePrediction system with configurable hit chance
    local prediction = self.W.spell:GetPrediction(target, myHero.pos)
    local minHitChance = self.Menu.advanced.minHitChanceW:Value()
    
    if prediction.HitChance >= minHitChance then
        Control.CastSpell(HK_W, prediction.CastPosition)
        self.lastWCast = GameTimer()
        return true
    end
    
    return false
end

function Cassiopeia:CastR(target)
    if not Ready(_R) or not IsValid(target) then return false end
    
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > self:GetRRange() then return false end
    
    -- Check if enemy is facing us for better stun chance
    if self.Menu.advanced.rFacing:Value() then
        local targetDirection = target.dir
        local myDirection = myHero.pos - target.pos
        myDirection = myDirection:Normalized()
        
        local dot = targetDirection.x * myDirection.x + targetDirection.z * myDirection.z
        if dot < 0.5 then -- Not facing us enough
            return false
        end
    end
    
    -- Use DepressivePrediction system with configurable hit chance
    local prediction = self.R.spell:GetPrediction(target, myHero.pos)
    local minHitChance = self.Menu.advanced.minHitChanceR:Value()
    
    if prediction.HitChance >= minHitChance then
        Control.CastSpell(HK_R, prediction.CastPosition)
        self.lastRCast = GameTimer()
        return true
    end
    
    return false
end

-- Enhanced prediction functions using DepressivePrediction
function Cassiopeia:GetQPrediction(target)
    if not target then return nil end
    
    local prediction = self.Q.spell:GetPrediction(target, myHero.pos)
    if prediction and prediction.CastPosition then
        return {
            castPos = prediction.CastPosition, 
            hitChance = prediction.HitChance,
            timeToHit = prediction.TimeToHit
        }
    end
    
    return nil
end

function Cassiopeia:GetWPrediction(target)
    if not target then return nil end
    
    local prediction = self.W.spell:GetPrediction(target, myHero.pos)
    if prediction and prediction.CastPosition then
        return {
            castPos = prediction.CastPosition, 
            hitChance = prediction.HitChance,
            timeToHit = prediction.TimeToHit
        }
    end
    
    return nil
end

function Cassiopeia:GetRPrediction(target)
    if not target then return nil end
    
    local prediction = self.R.spell:GetPrediction(target, myHero.pos)
    if prediction and prediction.CastPosition then
        return {
            castPos = prediction.CastPosition, 
            hitChance = prediction.HitChance,
            timeToHit = prediction.TimeToHit
        }
    end
    
    return nil
end

-- Utility functions
function Cassiopeia:GetPoisonedEnemies(range)
    local poisonedEnemies = {}
    range = range or 1000
    
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if IsValid(enemy) and HasPoison(enemy) and GetDistance(myHero.pos, enemy.pos) <= range then
            table.insert(poisonedEnemies, enemy)
        end
    end
    
    return poisonedEnemies
end

function Cassiopeia:GetPoisonTimeRemaining(target)
    if not IsValid(target) then return 0 end
    
    local maxTimeRemaining = 0
    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff.type == 24 then -- Poison type
            local timeRemaining = buff.expireTime - GameTimer()
            if timeRemaining > maxTimeRemaining then
                maxTimeRemaining = timeRemaining
            end
        end
    end
    
    return maxTimeRemaining
end

function Cassiopeia:ShouldCastE(target, mode)
    if not IsValid(target) or not Ready(_E) then return false end
    
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > self.E.range then return false end
    
    -- Check based on current mode and settings
    if mode == "Combo" then
        if not self.Menu.combo.useE:Value() then return false end
        if self.Menu.combo.eOnlyPoison:Value() and not HasPoison(target) then return false end
    elseif mode == "Harass" then
        if not self.Menu.harass.useE:Value() then return false end
        if self.Menu.harass.eOnlyPoison:Value() and not HasPoison(target) then return false end
    elseif mode == "Clear" then
        if not self.Menu.clear.useE:Value() then return false end
        -- Check poison restriction for clear mode
        if self.Menu.clear.eOnlyPoison:Value() and not HasPoison(target) then return false end
    elseif mode == "LastHit" then
        if not self.Menu.lasthit.useE:Value() then return false end
        -- LastHit always requires poison
        if not HasPoison(target) then return false end
    end
    
    return true
end

function Cassiopeia:GetHeroTarget(range)
    local bestTarget = nil
    local bestPriority = 0
    
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if IsValid(enemy) and GetDistance(myHero.pos, enemy.pos) <= range then
            local priority = self:GetTargetPriority(enemy)
            if priority > bestPriority then
                bestTarget = enemy
                bestPriority = priority
            end
        end
    end
    
    return bestTarget
end

function Cassiopeia:GetTargetPriority(enemy)
    local priority = 100
    
    -- Higher priority for poisoned targets
    if HasPoison(enemy) then
        priority = priority + 50
    end
    
    -- Higher priority for low health targets
    local healthPercent = enemy.health / enemy.maxHealth
    priority = priority + (1 - healthPercent) * 30
    
    -- Higher priority for closer targets
    local distance = GetDistance(myHero.pos, enemy.pos)
    priority = priority + (1000 - distance) / 10
    
    -- Role-based priority
    if enemy.charName:find("Adc") or enemy.charName:find("Carry") then
        priority = priority + 20
    elseif enemy.charName:find("Support") then
        priority = priority + 10
    end
    
    return priority
end

function Cassiopeia:IsKillable(target)
    if not IsValid(target) then return false end
    
    local totalDamage = 0
    
    -- Calculate Q damage
    if Ready(_Q) then
        totalDamage = totalDamage + self:GetQDamage(target)
    end
    
    -- Calculate W damage
    if Ready(_W) then
        totalDamage = totalDamage + self:GetWDamage(target)
    end
    
    -- Calculate E damage
    if Ready(_E) then
        local eDamage = self:GetEDamage(target)
        -- If target is poisoned, we can cast multiple Es
        if HasPoison(target) then
            totalDamage = totalDamage + eDamage * 3 -- Estimate 3 E casts
        else
            totalDamage = totalDamage + eDamage
        end
    end
    
    -- Calculate R damage
    if Ready(_R) then
        totalDamage = totalDamage + self:GetRDamage(target)
    end
    
    -- Add some auto attack damage
    totalDamage = totalDamage + self:GetAADamage(target) * 2
    
    return target.health <= totalDamage * 0.9 -- 90% certainty factor
end

function Cassiopeia:GetQDamage(target)
    if not IsSpellLearned(_Q) then return 0 end
    
    local qLevel = myHero:GetSpellData(_Q).level
    local baseDamage = 75 + (qLevel - 1) * 45 -- 75/120/165/210/255
    local apRatio = 0.9
    local damage = baseDamage + (myHero.ap * apRatio)
    
    -- Calculate magic resistance reduction
    local magicResist = target.magicResist
    local reduction = magicResist / (magicResist + 100)
    
    return damage * (1 - reduction)
end

function Cassiopeia:GetWDamage(target)
    if not IsSpellLearned(_W) then return 0 end
    
    local wLevel = myHero:GetSpellData(_W).level
    local baseDamage = 20 + (wLevel - 1) * 15 -- 20/35/50/65/80 per second
    local apRatio = 0.15
    local damage = (baseDamage + (myHero.ap * apRatio)) * 3 -- Assume 3 seconds of damage
    
    -- Calculate magic resistance reduction
    local magicResist = target.magicResist
    local reduction = magicResist / (magicResist + 100)
    
    return damage * (1 - reduction)
end

function Cassiopeia:GetEDamage(target)
    if not IsSpellLearned(_E) then return 0 end
    
    local eLevel = myHero:GetSpellData(_E).level
    local baseDamage = 52 + (eLevel - 1) * 8 -- 52/60/68/76/84
    local apRatio = 0.1
    local damage = baseDamage + (myHero.ap * apRatio)
    
    -- Bonus damage if target is poisoned
    if HasPoison(target) then
        local bonusBase = 20 + (eLevel - 1) * 25 -- 20/45/70/95/120
        local bonusAP = 0.6
        damage = damage + bonusBase + (myHero.ap * bonusAP)
    end
    
    -- Calculate magic resistance reduction
    local magicResist = target.magicResist
    local reduction = magicResist / (magicResist + 100)
    
    return damage * (1 - reduction)
end

function Cassiopeia:GetRDamage(target)
    if not IsSpellLearned(_R) then return 0 end
    
    local rLevel = myHero:GetSpellData(_R).level
    local baseDamage = 150 + (rLevel - 1) * 100 -- 150/250/350
    local apRatio = 0.5
    local damage = baseDamage + (myHero.ap * apRatio)
    
    -- Calculate magic resistance reduction
    local magicResist = target.magicResist
    local reduction = magicResist / (magicResist + 100)
    
    return damage * (1 - reduction)
end

function Cassiopeia:GetAADamage(target)
    local damage = myHero.totalDamage
    local armorResist = target.armor
    local reduction = armorResist / (armorResist + 100)
    
    return damage * (1 - reduction)
end

-- Minion and positioning functions
function Cassiopeia:GetMinionsInRange(range)
    local minions = {}
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if IsValid(minion) and minion.isEnemy and GetDistance(myHero.pos, minion.pos) <= range then
            TableInsert(minions, minion)
        end
    end
    
    return minions
end

function Cassiopeia:GetEnemiesInRange(range)
    local enemies = {}
    
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if IsValid(enemy) and GetDistance(myHero.pos, enemy.pos) <= range then
            TableInsert(enemies, enemy)
        end
    end
    
    return enemies
end

function Cassiopeia:GetClosestMinion(minions, maxRange)
    local bestMinion = nil
    local bestDistance = math.huge
    
    for i = 1, #minions do
        local minion = minions[i]
        local distance = GetDistance(myHero.pos, minion.pos)
        if distance <= maxRange and distance < bestDistance then
            bestMinion = minion
            bestDistance = distance
        end
    end
    
    return bestMinion
end

function Cassiopeia:CanLastHitWithE(minion)
    if not minion then return false end
    
    local damage = self:GetEDamage(minion)
    return minion.health <= damage and minion.health > damage * 0.7
end

function Cassiopeia:GetBestQPositionForMinions(minions)
    if #minions < self.Menu.clear.minMinionsQ:Value() then return nil end
    
    local bestPos = nil
    local bestCount = 0
    
    for i = 1, #minions do
        local minion = minions[i]
        if GetDistance(myHero.pos, minion.pos) <= self.Q.range then
            local count = self:CountMinionsInRadius(minion.pos, self.Q.width)
            if count > bestCount then
                bestPos = minion.pos
                bestCount = count
            end
        end
    end
    
    return bestPos
end

function Cassiopeia:GetBestWPositionForMinions(minions)
    if #minions < self.Menu.clear.minMinionsW:Value() then return nil end
    
    local bestPos = nil
    local bestCount = 0
    
    for i = 1, #minions do
        local minion = minions[i]
        if GetDistance(myHero.pos, minion.pos) <= self.W.range then
            local count = self:CountMinionsInRadius(minion.pos, self.W.width)
            if count > bestCount then
                bestPos = minion.pos
                bestCount = count
            end
        end
    end
    
    return bestPos
end

function Cassiopeia:CountMinionsInRadius(pos, radius)
    local count = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if IsValid(minion) and minion.isEnemy and GetDistance(pos, minion.pos) <= radius then
            count = count + 1
        end
    end
    
    return count
end

-- Initialize with error protection
DelayAction(function()
    local success, result = pcall(function()
        _G.Cassiopeia = Cassiopeia()
        print("[DepressiveAIONext][Cassiopeia] Loaded")
        return true
    end)
    if not success then
        print("[DepressiveAIONext][Cassiopeia] Error: " .. tostring(result))
    end
end, 0.50)
