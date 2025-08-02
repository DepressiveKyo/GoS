local Heroes = {"Elise"}

-- Hero validation
if not table.contains(Heroes, myHero.charName) then return end

-- Constants and globals
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameCanUseSpell = Game.CanUseSpell
local GameTimer = Game.Timer
local TableInsert = table.insert

-- Spell Keys
local HK_Q = 0x51
local HK_W = 0x57  
local HK_E = 0x45
local HK_R = 0x52

-- Spell Slots
local _Q = 0
local _W = 1
local _E = 2
local _R = 3

local lastMove = 0
local lastQCast = 0
local lastWCast = 0
local lastECast = 0
local lastRCast = 0
local Enemys = {}
local Allys = {}
local myHero = myHero

-- Form types enum
local FORM_TYPES = {
    HUMAN = 0,
    SPIDER = 1
}

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
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
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
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            TableInsert(_EnemyHeroes, Hero)
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
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then
            return true
        end
    end
    return false
end

-- Check if unit is a turret
local function IsTurret(unit)
    if not unit then return false end
    
    -- Verificar tipo
    if unit.type == Obj_AI_Turret then return true end
    
    -- Verificar nombre
    local name = unit.charName or unit.name or ""
    if string.find(string.lower(name), "turret") then return true end
    
    -- Verificar si es estructura enemiga estática
    if unit.isEnemy and unit.isBuilding then return true end
    
    return false
end

-- Get all enemy turrets that can attack us
local function GetNearbyEnemyTurrets(range)
    local turrets = {}
    for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i)
        if turret and turret.isEnemy and not turret.dead then
            local distance = GetDistance(myHero.pos, turret.pos)
            if distance <= (range or 1000) then
                TableInsert(turrets, turret)
            end
        end
    end
    return turrets
end

-- Check if we're in turret range
local function IsInTurretRange()
    local turrets = GetNearbyEnemyTurrets(950) -- Turret attack range is ~875, add buffer
    return #turrets > 0, turrets
end

local function IsBeingAttackedByTurret()
    -- Simplified - just check if we're in turret range
    local isInRange, nearbyTurrets = IsInTurretRange()
    if isInRange and #nearbyTurrets > 0 then
        return true, nearbyTurrets[1]
    end
    return false, nil
end

-- Elise Class
class "Elise"

function Elise:__init()
    -- Spell data for Human Form
    self.Q = {
        range = 625,
        delay = 0.25,
        speed = math.huge,
        width = 0,
        collision = false
    }
    
    self.W = {
        range = 950,
        delay = 0.25,
        speed = 5000,
        width = 235,
        collision = false
    }
    
    self.E = {
        range = 1075,
        delay = 0.25,
        speed = 1600,
        width = 55,
        collision = true
    }
    
    -- Spell data for Spider Form
    self.SpiderQ = {
        range = 475,
        delay = 0.25,
        speed = math.huge,
        width = 0,
        collision = false
    }
    
    self.SpiderW = {
        range = 300,
        delay = 0.25,
        speed = math.huge,
        width = 0,
        collision = false
    }
    
    self.SpiderE = {
        range = 750,
        delay = 0.25,
        speed = math.huge,
        width = 0,
        collision = false
    }
    
    -- State tracking
    self.currentForm = FORM_TYPES.HUMAN
    self.isRappelling = false
    self.rappelStartTime = 0
    self.lastFormSwitch = 0
    
    -- Human form cooldown tracking
    self.humanFormCooldowns = {
        Q = 0,
        W = 0,
        E = 0,
        savedAt = 0
    }
    
    -- Spider form buff tracking
    self.spiderBuffs = {
        wBuffActive = false,
        wBuffStartTime = 0,
        wBuffDuration = 3.0 -- Spider W buff lasts 3 seconds
    }
    
    -- Combat state tracking
    self.combatState = {
        usedHumanSpells = false,
        readyToSwitch = false,
        shouldStartHuman = true,
        minSpiderTime = 2.0 -- Minimum time to stay in spider form for efficiency
    }
    
    -- Turret tracking for dive safety
    self.turretTracking = {
        shotsReceived = 0,
        lastShotTime = 0,
        shotResetTime = 3.0, -- Reset shot count after 3 seconds without shots
        turretDamagePerShot = 0,
        isUnderTurret = false,
        lastHealth = 0,
        healthCheckTime = 0,
        lastHealthCheck = 0,
        -- New turret missile tracking
        turretMissileShots = 0,
        lastTurretMissileTime = 0,
        turretMissileResetTime = 4.0 -- Reset after 4 seconds
    }
    
    -- Damage monitoring system
    self.damageMonitoring = {
        lastHealth = 0,
        lastTime = 0,
        enabled = true
    }
    
    -- InfoBox dragging system
    self.infoBox = {
        x = 0, -- Will be initialized in first draw
        y = 0,
        width = 280,
        height = 170,
        isDragging = false,
        dragOffsetX = 0,
        dragOffsetY = 0,
        initialized = false,
        lastMouseState = false, -- Track mouse button state
        dragStartTime = 0
    }
    
    -- Human-like casting timers
    self.eCastTimer = 0
    
    -- Context-aware casting system
    self.castingContext = {
        lastTargetPosition = nil,
        targetPositionTime = 0,
        consecutiveMisses = 0,
        lastSuccessfulE = 0
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
    
    -- Try to add damage callback if available
    if Callback and Callback.Add then
        local success, err = pcall(function()
            Callback.Add("OnTakeDamage", function(source, target, damage) 
                self:OnTakeDamage(source, target, damage) 
            end)
        end)
    end
end

function Elise:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "Elise", name = "Elise - Depressive"})
    self.Menu:MenuElement({name = "Ping", id = "ping", value = 20, min = 0, max = 300, step = 1})
    
    -- Combo
    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.combo:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.combo:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.combo:MenuElement({id = "useR", name = "Use R (Form Switch)", value = true})
    self.Menu.combo:MenuElement({id = "humanFirst", name = "Start with Human Form", value = true})
    self.Menu.combo:MenuElement({id = "spiderGap", name = "Spider Q Gap Close", value = true})
    self.Menu.combo:MenuElement({id = "comboRange", name = "Combo Range", value = 1075, min = 500, max = 1200, step = 25})
    
    -- Harass
    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.harass:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.harass:MenuElement({id = "useE", name = "Use E (Cocoon)", value = true})
    self.Menu.harass:MenuElement({id = "manaThreshold", name = "Min Mana %", value = 40, min = 0, max = 100, step = 5})
    self.Menu.harass:MenuElement({id = "humanOnly", name = "Human Form Only", value = true})
    
    -- Clear
    self.Menu:MenuElement({type = MENU, id = "clear", name = "Jungle/Lane Clear"})
    self.Menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.clear:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.clear:MenuElement({id = "useR", name = "Use R (Form Switch)", value = true})
    self.Menu.clear:MenuElement({id = "spiderForJungle", name = "Spider Form for Jungle", value = true})
    self.Menu.clear:MenuElement({id = "waitForWBuff", name = "Wait for Spider W Buff to End", value = true})
    self.Menu.clear:MenuElement({id = "minSpiderTime", name = "Min Spider Time (sec)", value = 2.0, min = 1.0, max = 5.0, step = 0.5})
    self.Menu.clear:MenuElement({id = "manaThreshold", name = "Min Mana %", value = 20, min = 0, max = 80, step = 5})
    
    -- Auto Rappel
    self.Menu:MenuElement({type = MENU, id = "rappel", name = "Auto Rappel"})
    self.Menu.rappel:MenuElement({id = "enabled", name = "Enable Auto Rappel", value = true})
    self.Menu.rappel:MenuElement({id = "healthThreshold", name = "Health % Threshold", value = 20, min = 5, max = 50, step = 5})
    self.Menu.rappel:MenuElement({id = "enemyCount", name = "Min Enemy Count", value = 1, min = 1, max = 5, step = 1})
    self.Menu.rappel:MenuElement({id = "checkTurretShots", name = "Significant Damage Detection", value = true})
    self.Menu.rappel:MenuElement({id = "maxTurretShots", name = "Max Significant Damage Before Rappel", value = 2, min = 1, max = 4, step = 1})
    self.Menu.rappel:MenuElement({id = "rappelTarget", name = "Rappel to Target", value = true})
    
    -- Advanced
    self.Menu:MenuElement({type = MENU, id = "advanced", name = "Advanced Settings"})
    self.Menu.advanced:MenuElement({id = "formSwitchDelay", name = "Form Switch Delay (ms)", value = 200, min = 100, max = 500, step = 50})
    self.Menu.advanced:MenuElement({id = "ePrediction", name = "E Prediction Accuracy", value = 0.7, min = 0.5, max = 1.0, step = 0.1})
    self.Menu.advanced:MenuElement({id = "spiderQRange", name = "Spider Q Max Range", value = 475, min = 300, max = 750, step = 25})
    self.Menu.advanced:MenuElement({id = "attackReset", name = "Use Attack Reset", value = true})
    
    -- Drawing
    self.Menu:MenuElement({type = MENU, id = "drawing", name = "Drawing"})
    self.Menu.drawing:MenuElement({id = "Q", name = "Draw Q Range", value = true})
    self.Menu.drawing:MenuElement({id = "W", name = "Draw W Range", value = true})
    self.Menu.drawing:MenuElement({id = "E", name = "Draw E Range", value = true})
    self.Menu.drawing:MenuElement({id = "form", name = "Draw Current Form", value = true})
    self.Menu.drawing:MenuElement({id = "rappel", name = "Draw Rappel Status", value = true})
    self.Menu.drawing:MenuElement({id = "killable", name = "Draw Killable Enemies", value = true})
    self.Menu.drawing:MenuElement({id = "cooldowns", name = "Draw Cooldown InfoBox", value = true})
end

function Elise:Draw()
    if myHero.dead then return end
    
    local myPos = myHero.pos
    
    -- Draw Q Range
    if self.Menu.drawing.Q:Value() and Ready(_Q) then
        local range = self.currentForm == FORM_TYPES.HUMAN and self.Q.range or self.SpiderQ.range
        Draw.Circle(myPos, range, Draw.Color(80, 255, 165, 0))
    end
    
    -- Draw W Range
    if self.Menu.drawing.W:Value() and Ready(_W) then
        local range = self.currentForm == FORM_TYPES.HUMAN and self.W.range or self.SpiderW.range
        Draw.Circle(myPos, range, Draw.Color(80, 255, 255, 0))
    end
    
    -- Draw E Range
    if self.Menu.drawing.E:Value() and Ready(_E) then
        local range = self.currentForm == FORM_TYPES.HUMAN and self.E.range or self.SpiderE.range
        Draw.Circle(myPos, range, Draw.Color(80, 255, 0, 255))
    end
    
    -- Draw Current Form
    if self.Menu.drawing.form:Value() then
        local formText = self.currentForm == FORM_TYPES.HUMAN and "HUMAN FORM" or "SPIDER FORM"
        local formColor = self.currentForm == FORM_TYPES.HUMAN and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 0, 0)
        Draw.Text(formText, 20, myPos:To2D().x - 50, myPos:To2D().y - 100, formColor)
    end
    
    -- Draw Rappel Status
    if self.Menu.drawing.rappel:Value() and self.isRappelling then
        Draw.Text("RAPPELLING", 18, myPos:To2D().x - 50, myPos:To2D().y - 80, Draw.Color(255, 255, 255, 0))
    end
    
    -- Draw Turret Warning - SIGNIFICANT DAMAGE DETECTION
    if self.Menu.rappel.checkTurretShots:Value() then
        local warningText = string.format("SIGNIFICANT DAMAGE: %d/%d", 
            self.turretTracking.turretMissileShots, 
            self.Menu.rappel.maxTurretShots:Value())
        local warningColor = self.turretTracking.turretMissileShots >= self.Menu.rappel.maxTurretShots:Value() 
            and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 255, 165, 0) -- Red if at max, orange otherwise
        
        -- Only show if we have taken significant damage recently
        if self.turretTracking.turretMissileShots > 0 then
            Draw.Text(warningText, 16, myPos:To2D().x - 80, myPos:To2D().y - 60, warningColor)
        end
    end
    
    -- Draw Killable Enemies
    if self.Menu.drawing.killable:Value() then
        for i = 1, #Enemys do
            local enemy = Enemys[i]
            if IsValid(enemy) and self:IsKillable(enemy) then
                Draw.Circle(enemy.pos, 100, Draw.Color(255, 255, 0, 0))
                Draw.Text("KILLABLE", 16, enemy.pos:To2D().x - 30, enemy.pos:To2D().y - 50, Draw.Color(255, 255, 0, 0))
            end
        end
    end
    
    -- Draw Ability Cooldowns InfoBox
    self:DrawCooldownInfoBox()
end

function Elise:DrawCooldownInfoBox()
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
    
    -- Handle mouse dragging - FIXED: Use screen coordinates instead of world coordinates
    local mousePos = GetScreenMousePos()
    if not mousePos then 
        -- Fallback: try the old method but likely won't work for UI
        pcall(function()
            local worldPos = Game.mousePos()
            if worldPos then
                mousePos = {x = worldPos.x, y = worldPos.y}
            end
        end)
        if not mousePos then return end -- Still no mouse position, skip frame
    end
    
    local isMouseInBox = mousePos.x >= boxX and mousePos.x <= boxX + boxWidth and 
                        mousePos.y >= boxY and mousePos.y <= boxY + boxHeight
    
    -- Try multiple methods to detect mouse button state
    local mousePressed = false
    
    -- Method 1: Try Control.IsKeyDown
    local success1, result1 = pcall(function() return Control.IsKeyDown(0x01) end)
    if success1 and result1 then
        mousePressed = true
    end
    
    -- Method 2: Try alternative input detection
    if not mousePressed then
        local success2, result2 = pcall(function() return _G.SDK and _G.SDK.INPUT and _G.SDK.INPUT:IsPressed(0x01) end)
        if success2 and result2 then
            mousePressed = true
        end
    end
    
    -- Method 3: Simplified detection - if mouse is in box and we detect any key activity
    if not mousePressed and isMouseInBox then
        local success3, result3 = pcall(function() return Control.IsKeyDown(32) end) -- Try spacebar as test
        if success3 then
            -- If we can detect any key, try left mouse button again
            local success4, result4 = pcall(function() return Control.IsKeyDown(1) end)
            mousePressed = success4 and result4
        end
    end
    
    -- Start dragging logic - simplified
    if isMouseInBox and mousePressed and not self.infoBox.isDragging then
        self.infoBox.isDragging = true
        self.infoBox.dragOffsetX = mousePos.x - boxX
        self.infoBox.dragOffsetY = mousePos.y - boxY
        self.infoBox.dragStartTime = GameTimer()
    end
    
    -- Stop dragging when mouse is released or no longer pressed
    if self.infoBox.isDragging and not mousePressed then
        self.infoBox.isDragging = false
    end
    
    -- Update position while dragging
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
    
    -- Draw background box with drag indicator
    local bgColor = self.infoBox.isDragging and Draw.Color(200, 0, 0, 0) or Draw.Color(180, 0, 0, 0)
    local borderColor = self.infoBox.isDragging and Draw.Color(255, 255, 255, 0) or Draw.Color(255, 255, 0, 0)
    
    Draw.Rect(boxX, boxY, boxWidth, boxHeight, bgColor) -- Semi-transparent black
    Draw.Rect(boxX, boxY, boxWidth, 2, borderColor) -- Top border
    Draw.Rect(boxX, boxY + boxHeight - 2, boxWidth, 2, borderColor) -- Bottom border
    Draw.Rect(boxX, boxY, 2, boxHeight, borderColor) -- Left border
    Draw.Rect(boxX + boxWidth - 2, boxY, 2, boxHeight, borderColor) -- Right border
    
    -- Title with clean design
    local titleText = "ELISE COOLDOWNS"
    
    local titleColor = Draw.Color(255, 255, 255, 255) -- White by default
    if self.infoBox.isDragging then
        titleColor = Draw.Color(255, 255, 255, 0) -- Yellow when dragging
    elseif isMouseInBox then
        titleColor = Draw.Color(255, 0, 255, 255) -- Light blue when mouse over
    end
    
    Draw.Text(titleText, 11, boxX + 5, boxY + 5, titleColor)
    
    -- Get cooldown information
    local qData = myHero:GetSpellData(_Q)
    local wData = myHero:GetSpellData(_W)
    local eData = myHero:GetSpellData(_E)
    local rData = myHero:GetSpellData(_R)
    
    -- Human Form Cooldowns
    local formText = self.currentForm == FORM_TYPES.HUMAN and "HUMAN FORM (CURRENT):" or "HUMAN FORM (SAVED):"
    local formColor = self.currentForm == FORM_TYPES.HUMAN and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 100, 100, 255)
    Draw.Text(formText, 12, boxX + 10, boxY + 25, formColor)
    
    local humanQCD, humanWCD, humanECD
    local qColor, wColor, eColor
    
    if self.currentForm == FORM_TYPES.HUMAN then
        -- Currently in human form, show actual cooldowns
        humanQCD = qData.currentCd > 0 and string.format("%.1f", qData.currentCd) or "Ready"
        humanWCD = wData.currentCd > 0 and string.format("%.1f", wData.currentCd) or "Ready"
        humanECD = eData.currentCd > 0 and string.format("%.1f", eData.currentCd) or "Ready"
        
        qColor = qData.currentCd > 0 and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 0, 255, 0)
        wColor = wData.currentCd > 0 and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 0, 255, 0)
        eColor = eData.currentCd > 0 and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 0, 255, 0)
    else
        -- In spider form, show calculated remaining cooldowns from saved data
        local qRemaining = self:GetHumanAbilityCooldown(_Q)
        local wRemaining = self:GetHumanAbilityCooldown(_W)
        local eRemaining = self:GetHumanAbilityCooldown(_E)
        
        -- Show saved cooldowns with countdown
        if self.humanFormCooldowns.savedAt > 0 then
            humanQCD = qRemaining > 0 and string.format("%.1f", qRemaining) or "Ready"
            humanWCD = wRemaining > 0 and string.format("%.1f", wRemaining) or "Ready"  
            humanECD = eRemaining > 0 and string.format("%.1f", eRemaining) or "Ready"
            
            -- Also show original saved values for reference  
            humanQCD = humanQCD .. " (" .. string.format("%.1f", self.humanFormCooldowns.Q) .. ")"
            humanWCD = humanWCD .. " (" .. string.format("%.1f", self.humanFormCooldowns.W) .. ")" 
            humanECD = humanECD .. " (" .. string.format("%.1f", self.humanFormCooldowns.E) .. ")"
        else
            -- No saved data yet - need to use human form first
            humanQCD = "Use Human First"
            humanWCD = "Use Human First"
            humanECD = "Use Human First"
        end
        
        qColor = qRemaining > 0 and Draw.Color(255, 255, 100, 0) or Draw.Color(255, 100, 255, 100)
        wColor = wRemaining > 0 and Draw.Color(255, 255, 100, 0) or Draw.Color(255, 100, 255, 100)
        eColor = eRemaining > 0 and Draw.Color(255, 255, 100, 0) or Draw.Color(255, 100, 255, 100)
    end
    
    Draw.Text("Q (Neurotoxin): " .. humanQCD, 10, boxX + 15, boxY + 40, qColor)
    Draw.Text("W (Volatile): " .. humanWCD, 10, boxX + 15, boxY + 52, wColor)
    Draw.Text("E (Cocoon): " .. humanECD, 10, boxX + 15, boxY + 64, eColor)
    
    -- Spider Form Status and Info
    local spiderText = self.currentForm == FORM_TYPES.SPIDER and "SPIDER FORM (CURRENT):" or "SPIDER FORM:"
    local spiderColor = self.currentForm == FORM_TYPES.SPIDER and Draw.Color(255, 255, 100, 0) or Draw.Color(255, 150, 150, 150)
    Draw.Text(spiderText, 12, boxX + 10, boxY + 80, spiderColor)
    
    -- In spider form, show when we switched and time elapsed
    if self.currentForm == FORM_TYPES.SPIDER and self.humanFormCooldowns.savedAt > 0 then
        local timeInSpider = GameTimer() - self.humanFormCooldowns.savedAt
        Draw.Text("Time in Spider: " .. string.format("%.1f", timeInSpider) .. "s", 9, boxX + 15, boxY + 95, Draw.Color(255, 200, 200, 200))
        
        -- Show saved original cooldowns table
        local savedText = "Saved: Q" .. string.format("%.1f", self.humanFormCooldowns.Q) .. 
                         " W" .. string.format("%.1f", self.humanFormCooldowns.W) .. 
                         " E" .. string.format("%.1f", self.humanFormCooldowns.E)
        Draw.Text(savedText, 8, boxX + 15, boxY + 107, Draw.Color(255, 150, 150, 255))
        
        -- Show how many human abilities will be ready
        local readyCount = 0
        if self:GetHumanAbilityCooldown(_Q) <= 0 then readyCount = readyCount + 1 end
        if self:GetHumanAbilityCooldown(_W) <= 0 then readyCount = readyCount + 1 end
        if self:GetHumanAbilityCooldown(_E) <= 0 then readyCount = readyCount + 1 end
        
        local readyText = "Human Ready: " .. readyCount .. "/3"
        local readyColor = readyCount >= 2 and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 100, 0)
        Draw.Text(readyText, 9, boxX + 150, boxY + 95, readyColor)
    elseif self.currentForm == FORM_TYPES.SPIDER then
        -- No saved data yet
        Draw.Text("No saved cooldowns - use Human form first!", 9, boxX + 15, boxY + 95, Draw.Color(255, 255, 0, 0))
    end
    
    -- Show Rappel status and Form Switch cooldown
    local rappelText = "E (Rappel): "
    if self.isRappelling then
        rappelText = rappelText .. "RAPPELLING"
        eColor = Draw.Color(255, 255, 255, 0) -- White when rappelling
    else
        if self.currentForm == FORM_TYPES.SPIDER then
            rappelText = rappelText .. (Ready(_E) and "Ready" or string.format("%.1f", eData.currentCd))
            eColor = Ready(_E) and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 0, 0)
        else
            rappelText = "E (Rappel): N/A"
            eColor = Draw.Color(255, 100, 100, 100)
        end
    end
    
    Draw.Text(rappelText, 10, boxX + 15, boxY + 107, eColor)
    
    -- Show Spider W buff status
    if self.currentForm == FORM_TYPES.SPIDER then
        local spiderWText = "Spider W Buff: "
        local spiderWColor
        if self.spiderBuffs.wBuffActive then
            local buffTimeRemaining = self.spiderBuffs.wBuffDuration - (GameTimer() - self.spiderBuffs.wBuffStartTime)
            spiderWText = spiderWText .. string.format("ACTIVE (%.1fs)", math.max(0, buffTimeRemaining))
            spiderWColor = Draw.Color(255, 0, 255, 0) -- Green when active
        else
            spiderWText = spiderWText .. "INACTIVE"
            spiderWColor = Draw.Color(255, 150, 150, 150) -- Gray when inactive
        end
        Draw.Text(spiderWText, 9, boxX + 15, boxY + 119, spiderWColor)
        
        -- Show damage tracking info - SIGNIFICANT DAMAGE DETECTION
        if self.Menu.rappel.checkTurretShots:Value() then
            local damageText = string.format("Significant Damage: %d/%d", 
                self.turretTracking.turretMissileShots, 
                self.Menu.rappel.maxTurretShots:Value())
            local damageColor = Draw.Color(255, 200, 200, 200)
            
            if self.turretTracking.turretMissileShots >= self.Menu.rappel.maxTurretShots:Value() then
                damageColor = Draw.Color(255, 255, 0, 0) -- Red when at max damage instances
            elseif self.turretTracking.turretMissileShots > 0 then
                damageColor = Draw.Color(255, 255, 100, 0) -- Yellow when damage taken
            end
            
            Draw.Text(damageText, 8, boxX + 15, boxY + 131, damageColor)
            
            -- Show last damage time
            local timeSinceDamage = GameTimer() - self.turretTracking.lastTurretMissileTime
            if self.turretTracking.lastTurretMissileTime > 0 and timeSinceDamage < 5 then
                local damageTimeText = string.format("Last Damage: %.1fs ago", timeSinceDamage)
                Draw.Text(damageTimeText, 7, boxX + 15, boxY + 143, Draw.Color(255, 150, 150, 150))
            end
        end
    end
    
    -- Form Switch Cooldown
    local rCD = rData.currentCd > 0 and string.format("%.1f", rData.currentCd) or "Ready"
    local rColor = rData.currentCd > 0 and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 0, 255, 0)
    Draw.Text("R (Form Switch): " .. rCD, 10, boxX + 150, boxY + 107, rColor)
end

function Elise:Tick()
    if MyHeroNotReady() then return end
    
    -- Update enemy heroes list periodically
    if math.floor(GameTimer())%5==0 then
        Enemys = GetEnemyHeroes()
    end
    
    local Mode = self:GetMode()
    
    -- Update form state
    self:UpdateFormState()
    
    -- Auto Rappel logic
    self:AutoRappel()
    
    -- Execute mode-specific logic
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
    elseif Mode == "Clear" then
        self:Clear()
    elseif Mode == "LastHit" then
        self:LastHit()
    end
end

function Elise:UpdateFormState()
    -- Check if in spider form (has EliseR buff)
    if HasBuff(myHero, "EliseR") then
        self.currentForm = FORM_TYPES.SPIDER
    else
        self.currentForm = FORM_TYPES.HUMAN
    end
    
    -- Check if rappelling (has EliseSpideElnitial buff)
    if HasBuff(myHero, "EliseSpideElnitial") then
        if not self.isRappelling then
            self.rappelStartTime = GameTimer()
        end
        self.isRappelling = true
    else
        self.isRappelling = false
    end
    
    -- Track Spider W buff (EliseSpiderW - attack speed and heal on hit)
    local hasSpiderWBuff = HasBuff(myHero, "EliseSpiderW")
    if hasSpiderWBuff and not self.spiderBuffs.wBuffActive then
        -- Spider W buff just started
        self.spiderBuffs.wBuffActive = true
        self.spiderBuffs.wBuffStartTime = GameTimer()
    elseif not hasSpiderWBuff and self.spiderBuffs.wBuffActive then
        -- Spider W buff just ended
        self.spiderBuffs.wBuffActive = false
        self.spiderBuffs.wBuffStartTime = 0
    end
    
    -- Monitor damage by health changes
    self:MonitorDamage()
    
    -- Update turret tracking
    self:UpdateTurretTracking()
end

-- Update turret shot tracking - ONLY MISSILE-BASED DETECTION
function Elise:UpdateTurretTracking()
    local currentTime = GameTimer()
    local isInRange, nearbyTurrets = IsInTurretRange()
    
    -- Update turret range status and reset counters when leaving
    if isInRange ~= self.turretTracking.isUnderTurret then
        if not isInRange then
            -- Reset turret missile counter when leaving turret range
            self.turretTracking.turretMissileShots = 0
            self.turretTracking.lastTurretMissileTime = 0
        end
    end
    self.turretTracking.isUnderTurret = isInRange
end

-- Monitor damage - SIGNIFICANT DAMAGE DETECTION
function Elise:MonitorDamage()
    if not self.damageMonitoring.enabled then return end
    
    local currentHealth = myHero.health
    local currentTime = GameTimer()
    
    -- Initialize on first run
    if self.damageMonitoring.lastHealth == 0 then
        self.damageMonitoring.lastHealth = currentHealth
        self.damageMonitoring.lastTime = currentTime
        return
    end
    
    -- Check if we lost health (took damage)
    local healthDiff = self.damageMonitoring.lastHealth - currentHealth
    local timeDiff = currentTime - self.damageMonitoring.lastTime
    
    -- Only check if enough time has passed and we lost health
    if timeDiff > 0.1 and healthDiff > 0 then
        -- Calculate damage as percentage of current max health
        local damagePercent = (healthDiff / myHero.maxHealth) * 100
        
        -- Consider damage "significant" if it's more than 15% of max health
        if damagePercent >= 15 then
            -- Reset shot count if too much time has passed
            if currentTime - self.turretTracking.lastTurretMissileTime > self.turretTracking.turretMissileResetTime then
                self.turretTracking.turretMissileShots = 0
            end
            
            -- Only count if enough time passed since last significant damage (avoid duplicates)
            if currentTime - self.turretTracking.lastTurretMissileTime > 1.0 then
                self.turretTracking.turretMissileShots = self.turretTracking.turretMissileShots + 1
                self.turretTracking.lastTurretMissileTime = currentTime
                
                -- AUTO RAPPEL AFTER 2 SIGNIFICANT DAMAGE INSTANCES
                if self.turretTracking.turretMissileShots >= 2 and 
                   self.currentForm == FORM_TYPES.SPIDER and 
                   Ready(_E) and 
                   self.Menu.rappel.enabled:Value() then
                    
                    Control.CastSpell(HK_E)
                    lastECast = GameTimer()
                    
                    -- Reset counters after rappelling
                    self.turretTracking.turretMissileShots = 0
                    self.turretTracking.lastTurretMissileTime = 0
                end
            end
        end
        
        -- Update for next check
        self.damageMonitoring.lastHealth = currentHealth
        self.damageMonitoring.lastTime = currentTime
    elseif timeDiff > 0.1 then
        -- Update health tracking regularly even if no damage
        self.damageMonitoring.lastHealth = currentHealth
        self.damageMonitoring.lastTime = currentTime
    end
end

-- Save human form cooldowns when switching to spider form
function Elise:SaveHumanCooldowns()
    local currentTime = GameTimer()
    local qData = myHero:GetSpellData(_Q)
    local wData = myHero:GetSpellData(_W)
    local eData = myHero:GetSpellData(_E)
    
    -- Only save if we actually have cooldowns (spells were used)
    if qData.currentCd > 0 or wData.currentCd > 0 or eData.currentCd > 0 then
        self.humanFormCooldowns.Q = qData.currentCd
        self.humanFormCooldowns.W = wData.currentCd  
        self.humanFormCooldowns.E = eData.currentCd
        self.humanFormCooldowns.savedAt = currentTime
        self.combatState.usedHumanSpells = true
    end
end

-- Check if human form abilities are ready (considering saved cooldowns)
function Elise:AreHumanAbilitiesReady()
    if self.currentForm == FORM_TYPES.HUMAN then
        return true -- Already in human form, use normal checks
    end
    
    -- If we haven't saved any cooldowns yet, return true to allow switching
    if self.humanFormCooldowns.savedAt == 0 then
        return true
    end
    
    local currentTime = GameTimer()
    local timePassed = currentTime - self.humanFormCooldowns.savedAt
    
    -- Calculate remaining cooldowns
    local qRemaining = math.max(0, self.humanFormCooldowns.Q - timePassed)
    local wRemaining = math.max(0, self.humanFormCooldowns.W - timePassed)
    local eRemaining = math.max(0, self.humanFormCooldowns.E - timePassed)
    
    -- Return true if at least 2 abilities are ready (cooldown <= 0)
    local readyCount = 0
    if qRemaining <= 0 then readyCount = readyCount + 1 end
    if wRemaining <= 0 then readyCount = readyCount + 1 end  
    if eRemaining <= 0 then readyCount = readyCount + 1 end
    
    local canReturn = readyCount >= 2
    
    return canReturn
end

-- Check if it's safe to switch forms (considering spider W buff and minimum spider time)
function Elise:CanSafelySwitch()
    if self.currentForm == FORM_TYPES.HUMAN then
        return true -- Can always switch from human to spider
    end
    
    -- Don't switch if Spider W buff is still active (if option is enabled)
    if self.Menu.clear.waitForWBuff:Value() and self.spiderBuffs.wBuffActive then
        return false
    end
    
    -- Enforce minimum time in spider form for efficiency
    local minSpiderTime = self.Menu.clear.minSpiderTime:Value()
    local timeInSpider = GameTimer() - self.lastFormSwitch
    if timeInSpider < minSpiderTime then
        return false
    end
    
    return true
end

-- Check if we should rappel due to significant damage - DAMAGE-BASED
function Elise:ShouldRappelForTurrets()
    if not self.Menu.rappel.checkTurretShots:Value() then
        return false
    end
    
    -- Only in spider form can we rappel
    if self.currentForm ~= FORM_TYPES.SPIDER then
        return false
    end
    
    -- Check significant damage instances
    local maxShots = self.Menu.rappel.maxTurretShots:Value()
    if self.turretTracking.turretMissileShots >= maxShots then
        return true
    end
    
    return false
end

-- Get remaining cooldown for human abilities
function Elise:GetHumanAbilityCooldown(spell)
    if self.currentForm == FORM_TYPES.HUMAN then
        local spellData = myHero:GetSpellData(spell)
        return spellData.currentCd
    end
    
    -- If no saved data, return 0 (ready)
    if self.humanFormCooldowns.savedAt == 0 then
        return 0
    end
    
    local currentTime = GameTimer()
    local timePassed = currentTime - self.humanFormCooldowns.savedAt
    
    if spell == _Q then
        return math.max(0, self.humanFormCooldowns.Q - timePassed)
    elseif spell == _W then
        return math.max(0, self.humanFormCooldowns.W - timePassed)
    elseif spell == _E then
        return math.max(0, self.humanFormCooldowns.E - timePassed)
    end
    
    return 0
end

function Elise:GetMode()
    if _G.SDK and _G.SDK.Orbwalker then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
            return "Clear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
            return "LastHit"
        end
    end
    return "None"
end

function Elise:AutoRappel()
    if not self.Menu.rappel.enabled:Value() then return end
    if self.isRappelling then return end
    if self.currentForm ~= FORM_TYPES.SPIDER then return end
    if not Ready(_E) then return end
    
    local shouldRappel = false
    local rappelReason = ""
    
    -- Significant damage safety check (highest priority)
    if self:ShouldRappelForTurrets() then
        shouldRappel = true
        rappelReason = "Significant Damage Safety"
    end
    
    -- Health threshold check
    if not shouldRappel then
        local healthPercent = myHero.health / myHero.maxHealth * 100
        if healthPercent <= self.Menu.rappel.healthThreshold:Value() then
            local enemyCount = self:GetEnemiesInRange(800)
            if #enemyCount >= self.Menu.rappel.enemyCount:Value() then
                shouldRappel = true
                rappelReason = "Low Health + Enemies"
            end
        end
    end
    
    if shouldRappel then
        -- Try to rappel to a target if option is enabled
        if self.Menu.rappel.rappelTarget:Value() then
            local target = self:GetHeroTarget(self.SpiderE.range)
            if target then
                Control.CastSpell(HK_E, target.pos)
            else
                Control.CastSpell(HK_E)
            end
        else
            Control.CastSpell(HK_E)
        end
        
        lastECast = GameTimer()
        
        -- Reset turret shot counter after rappelling - MISSILE-BASED ONLY
        self.turretTracking.turretMissileShots = 0
        self.turretTracking.lastTurretMissileTime = 0
    end
end

function Elise:OnPostAttack(target)
    if not self.Menu.advanced.attackReset:Value() then return end
    if not target then return end
    
    -- Use W for attack reset in spider form
    if self.currentForm == FORM_TYPES.SPIDER and Ready(_W) then
        Control.CastSpell(HK_W)
    end
end

-- Damage callback - DISABLED (using missile detection only)
function Elise:OnTakeDamage(source, target, damage)
    -- Disabled - using only missile-based turret detection
    return
end

function Elise:Combo()
    local target = self:GetHeroTarget(self.Menu.combo.comboRange:Value())
    if not target then return end
    
    local distance = GetDistance(myHero.pos, target.pos)
    
    -- ALWAYS START WITH HUMAN FORM FIRST
    if self.currentForm == FORM_TYPES.HUMAN then
        local usedSpell = false
        
        -- Cast E (Cocoon) first for CC
        if self.Menu.combo.useE:Value() and Ready(_E) and distance <= self.E.range then
            if self:CastE(target) then
                usedSpell = true
                self.combatState.usedHumanSpells = true
            end
        end
        
        -- Cast Q
        if self.Menu.combo.useQ:Value() and Ready(_Q) and distance <= self.Q.range then
            if self:CastQ(target) then
                usedSpell = true
                self.combatState.usedHumanSpells = true
            end
        end
        
        -- Cast W
        if self.Menu.combo.useW:Value() and Ready(_W) and distance <= self.W.range then
            if self:CastW(target) then
                usedSpell = true
                self.combatState.usedHumanSpells = true
            end
        end
        
        -- Switch to Spider form ONLY after using human spells AND all are on cooldown
        if self.Menu.combo.useR:Value() and Ready(_R) and self.combatState.usedHumanSpells and
           (not Ready(_Q) and not Ready(_W) and not Ready(_E)) then
            self:SwitchForm()
        end
        
    -- Spider Form Combo - Only after human form was used
    else
        -- Use Spider Q for gap close
        if self.Menu.combo.spiderGap:Value() and Ready(_Q) and 
           distance <= self.SpiderQ.range and distance > 200 then
            Control.CastSpell(HK_Q, target)
            lastQCast = GameTimer()
        end
        
        -- Cast Spider Q for damage
        if self.Menu.combo.useQ:Value() and Ready(_Q) and distance <= self.SpiderQ.range then
            Control.CastSpell(HK_Q, target)
            lastQCast = GameTimer()
        end
        
        -- Cast Spider W for attack speed
        if self.Menu.combo.useW:Value() and Ready(_W) then
            Control.CastSpell(HK_W)
            lastWCast = GameTimer()
        end
        
        -- Switch back to human form ONLY if saved human abilities are ready and it's safe
        if self.Menu.combo.useR:Value() and Ready(_R) and 
           (not Ready(_Q) and not Ready(_W)) and 
           self:AreHumanAbilitiesReady() and
           self:CanSafelySwitch() then
            self.combatState.usedHumanSpells = false -- Reset for next combo
            self:SwitchForm()
        end
    end
end

function Elise:Harass()
    if not self.Menu.harass.humanOnly:Value() and self.currentForm ~= FORM_TYPES.HUMAN then
        return
    end
    
    local target = self:GetHeroTarget(self.E.range)
    if not target then return end
    
    -- Check mana threshold
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.harass.manaThreshold:Value() then return end
    
    local distance = GetDistance(myHero.pos, target.pos)
    
    -- Cast E for CC
    if self.Menu.harass.useE:Value() and Ready(_E) and distance <= self.E.range then
        self:CastE(target)
    end
    
    -- Cast Q
    if self.Menu.harass.useQ:Value() and Ready(_Q) and distance <= self.Q.range then
        self:CastQ(target)
    end
    
    -- Cast W
    if self.Menu.harass.useW:Value() and Ready(_W) and distance <= self.W.range then
        self:CastW(target)
    end
end

function Elise:Clear()
    local target = self:GetBestClearTarget()
    if not target then return end
    
    -- Check mana threshold
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.clear.manaThreshold:Value() then return end
    
    local distance = GetDistance(myHero.pos, target.pos)
    
    -- ALWAYS START WITH HUMAN FORM FIRST (same as combo)
    if self.currentForm == FORM_TYPES.HUMAN then
        local usedSpell = false
        
        -- Cast Q
        if self.Menu.clear.useQ:Value() and Ready(_Q) and distance <= self.Q.range then
            if self:CastQ(target) then
                usedSpell = true
                self.combatState.usedHumanSpells = true
            end
        end
        
        -- Cast W for AOE
        if self.Menu.clear.useW:Value() and Ready(_W) and distance <= self.W.range then
            if self:CastW(target) then
                usedSpell = true
                self.combatState.usedHumanSpells = true
            end
        end
        
        -- Switch to Spider form ONLY after using human spells AND all are on cooldown  
        if self.Menu.clear.useR:Value() and Ready(_R) and self.combatState.usedHumanSpells and
           (not Ready(_Q) and not Ready(_W)) then
            self:SwitchForm()
        end
        
    else -- Spider form
        -- Cast Spider Q
        if self.Menu.clear.useQ:Value() and Ready(_Q) and distance <= self.SpiderQ.range then
            Control.CastSpell(HK_Q, target)
            lastQCast = GameTimer()
        end
        
        -- Cast Spider W for attack speed and healing
        if self.Menu.clear.useW:Value() and Ready(_W) then
            Control.CastSpell(HK_W)
            lastWCast = GameTimer()
        end
        
        -- Switch back to human form ONLY if:
        -- 1. Spider abilities are on cooldown
        -- 2. Human abilities are ready
        -- 3. Spider W buff is not active (important for jungle efficiency)
        -- 4. We've been in spider form for minimum time
        if self.Menu.clear.useR:Value() and Ready(_R) and 
           (not Ready(_Q) and not Ready(_W)) and 
           self:AreHumanAbilitiesReady() and
           self:CanSafelySwitch() then
            self.combatState.usedHumanSpells = false -- Reset for next clear cycle
            self:SwitchForm()
        end
    end
end

function Elise:LastHit()
    -- Simple last hit with Q
    local minions = self:GetMinionsInRange(self.Q.range)
    for i = 1, #minions do
        local minion = minions[i]
        if self:CanLastHitWithQ(minion) then
            self:CastQ(minion)
            break
        end
    end
end

-- Spell casting functions
function Elise:CastQ(target)
    if GameTimer() - lastQCast < 0.3 then return false end
    if not Ready(_Q) then return false end
    if not target or not IsValid(target) then return false end
    
    local distance = GetDistance(myHero.pos, target.pos)
    local maxRange = self.currentForm == FORM_TYPES.HUMAN and self.Q.range or self.SpiderQ.range
    
    if distance > maxRange then return false end
    
    Control.CastSpell(HK_Q, target)
    lastQCast = GameTimer()
    return true
end

function Elise:CastW(target)
    if GameTimer() - lastWCast < 0.3 then return false end
    if not Ready(_W) then return false end
    
    if self.currentForm == FORM_TYPES.HUMAN then
        if not target or not IsValid(target) then return false end
        
        local distance = GetDistance(myHero.pos, target.pos)
        if distance > self.W.range then return false end
        
        local prediction = self:GetWPrediction(target)
        if prediction then
            Control.CastSpell(HK_W, prediction)
        end
    else
        -- Spider W is a self-buff, no target needed
        Control.CastSpell(HK_W)
    end
    
    lastWCast = GameTimer()
    return true
end

function Elise:CastE(target)
    if GameTimer() - lastECast < 0.5 then return false end
    if not Ready(_E) then return false end
    
    if self.currentForm == FORM_TYPES.HUMAN then
        if not target or not IsValid(target) then return false end
        
        local distance = GetDistance(myHero.pos, target.pos)
        if distance > self.E.range then return false end
        
        -- Human-like decision making with movement analysis
        -- Don't cast E if target is too close (save for gap close)
        if distance < 200 then return false end
        
        -- Use enhanced decision making
        if not self:ShouldCastE(target) then
            return false
        end
        
        -- Check if we have other spells available for follow-up
        local hasFollowUp = Ready(_Q) or Ready(_W)
        if not hasFollowUp and distance > 800 then
            -- Don't cast E at long range without follow-up potential
            return false
        end
        
        local prediction = self:GetEPrediction(target)
        if prediction then
            -- Add human-like delay before casting (varies based on distance)
            local baseDelay = 0.05
            local distanceDelay = (distance / self.E.range) * 0.1 -- Further targets = more hesitation
            local humanDelay = baseDelay + distanceDelay + math.random() * 0.05
            
            -- Use a simple timer approach for delay
            if not self.eCastTimer then self.eCastTimer = 0 end
            
            if GameTimer() - self.eCastTimer < humanDelay then
                self.eCastTimer = GameTimer()
                return false
            end
            
            Control.CastSpell(HK_E, prediction)
            lastECast = GameTimer()
            self.eCastTimer = 0
            self.castingContext.lastSuccessfulE = GameTimer()
            return true
        else
            -- Track missed prediction attempts
            self.castingContext.consecutiveMisses = self.castingContext.consecutiveMisses + 1
        end
    else
        -- Spider E (Rappel) - can be cast without target
        Control.CastSpell(HK_E, target and target.pos or nil)
        lastECast = GameTimer()
        return true
    end
    
    return false
end

function Elise:SwitchForm()
    if GameTimer() - lastRCast < (self.Menu.advanced.formSwitchDelay:Value() / 1000) then return false end
    if not Ready(_R) then return false end
    
    -- Save human form cooldowns when switching to spider form
    if self.currentForm == FORM_TYPES.HUMAN then
        self:SaveHumanCooldowns()
    end
    
    Control.CastSpell(HK_R)
    lastRCast = GameTimer()
    self.lastFormSwitch = GameTimer()
    return true
end

-- Prediction functions
function Elise:GetEPrediction(target)
    if not target then return nil end
    
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > self.E.range then return nil end
    
    -- Human-like prediction considerations
    local ping = self.Menu.ping:Value()
    local humanDelay = 0.1 + (ping / 1000) -- Add human reaction time
    local totalDelay = self.E.delay + humanDelay + Game.Latency()
    
    -- Get basic prediction
    local prediction = target:GetPrediction(self.E.speed, totalDelay)
    if not prediction then return nil end
    
    local predictedDistance = GetDistance(myHero.pos, prediction)
    if predictedDistance > self.E.range then return nil end
    
    -- Human-like accuracy adjustment based on distance and movement
    local movementSpeed = target.ms
    local isMoving = target.pathing.hasMovePath and target.pathing.isDashing == false
    
    -- Be more careful with very mobile targets unless they're slowed or stunned
    if movementSpeed > 400 and isMoving and not self:IsTargetCCed(target) then
        -- Add extra prediction time for fast-moving targets
        totalDelay = totalDelay + 0.1
        prediction = target:GetPrediction(self.E.speed, totalDelay)
        if not prediction then return nil end
        
        predictedDistance = GetDistance(myHero.pos, prediction)
        if predictedDistance > self.E.range then return nil end
    end
    
    -- Check if target is near minions (collision check)
    if self:WillCollideWithMinions(myHero.pos, prediction) then
        return nil
    end
    
    return prediction
end

function Elise:GetWPrediction(target)
    if not target then return nil end
    
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > self.W.range then return nil end
    
    local prediction = target:GetPrediction(self.W.speed, self.W.delay + Game.Latency())
    if not prediction then return nil end
    
    local predictedDistance = GetDistance(myHero.pos, prediction)
    if predictedDistance > self.W.range then return nil end
    
    return prediction
end

-- Utility functions
function Elise:GetHeroTarget(range)
    local bestTarget = nil
    local bestPriority = 0
    
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if IsValid(enemy) then
            local distance = GetDistance(myHero.pos, enemy.pos)
            if distance <= range then
                local priority = self:GetTargetPriority(enemy)
                if priority > bestPriority then
                    bestTarget = enemy
                    bestPriority = priority
                end
            end
        end
    end
    
    return bestTarget
end

function Elise:GetTargetPriority(enemy)
    local priority = 0
    
    -- Health based priority
    local healthPercent = enemy.health / enemy.maxHealth
    priority = priority + (1 - healthPercent) * 3
    
    -- Distance based priority (closer = higher)
    local distance = GetDistance(myHero.pos, enemy.pos)
    priority = priority + (1000 - distance) / 1000 * 2
    
    -- Killable targets get highest priority
    if self:IsKillable(enemy) then
        priority = priority + 10
    end
    
    -- CC'd targets
    if HasBuff(enemy, "EliseHumanE") then
        priority = priority + 5
    end
    
    return priority
end

function Elise:IsKillable(target)
    if not target then return false end
    
    local totalDamage = 0
    
    -- Human Q damage
    if self.currentForm == FORM_TYPES.HUMAN and Ready(_Q) then
        totalDamage = totalDamage + self:GetQDamage(target)
    end
    
    -- Human W damage
    if self.currentForm == FORM_TYPES.HUMAN and Ready(_W) then
        totalDamage = totalDamage + self:GetWDamage(target)
    end
    
    -- Spider Q damage
    if self.currentForm == FORM_TYPES.SPIDER and Ready(_Q) then
        totalDamage = totalDamage + self:GetSpiderQDamage(target)
    end
    
    -- Auto attack damage
    totalDamage = totalDamage + self:GetAADamage(target)
    
    return target.health <= totalDamage * 0.9
end

function Elise:GetQDamage(target)
    if not target then return 0 end
    
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end
    
    local baseDamage = {40, 75, 110, 145, 180}
    local apRatio = 0.8
    local healthRatio = 0.04 -- 4% current health
    
    local damage = baseDamage[level] + myHero.ap * apRatio + target.health * healthRatio
    
    local magicResist = target.magicResist
    local reduction = magicResist / (magicResist + 100)
    
    return damage * (1 - reduction)
end

function Elise:GetWDamage(target)
    if not target then return 0 end
    
    local level = myHero:GetSpellData(_W).level
    if level == 0 then return 0 end
    
    local baseDamage = {75, 125, 175, 225, 275}
    local apRatio = 0.8
    
    local damage = baseDamage[level] + myHero.ap * apRatio
    
    local magicResist = target.magicResist
    local reduction = magicResist / (magicResist + 100)
    
    return damage * (1 - reduction)
end

function Elise:GetSpiderQDamage(target)
    if not target then return 0 end
    
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end
    
    local baseDamage = {60, 100, 140, 180, 220}
    local apRatio = 0.8
    local healthRatio = 0.08 -- 8% missing health
    
    local missingHealth = target.maxHealth - target.health
    local damage = baseDamage[level] + myHero.ap * apRatio + missingHealth * healthRatio
    
    local magicResist = target.magicResist
    local reduction = magicResist / (magicResist + 100)
    
    return damage * (1 - reduction)
end

function Elise:GetAADamage(target)
    if not target then return 0 end
    
    local damage = myHero.totalDamage
    local armor = target.armor
    local reduction = armor / (armor + 100)
    
    return damage * (1 - reduction)
end

function Elise:GetEnemiesInRange(range)
    local enemies = {}
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if IsValid(enemy) and GetDistance(myHero.pos, enemy.pos) <= range then
            TableInsert(enemies, enemy)
        end
    end
    return enemies
end

function Elise:GetMinionsInRange(range)
    local minions = {}
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and not minion.dead and 
           GetDistance(myHero.pos, minion.pos) <= range then
            TableInsert(minions, minion)
        end
    end
    return minions
end

-- Check if target is under crowd control effects
function Elise:IsTargetCCed(target)
    if not target then return false end
    
    -- Check for common CC buffs
    local ccBuffs = {
        "stun", "root", "snare", "slow", "frozen", "entangle", "charm", 
        "fear", "flee", "suppression", "silence", "taunt", "knockup",
        "polymorph", "sleep", "suspension"
    }
    
    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and buff.count > 0 then
            local buffName = string.lower(buff.name)
            for _, ccBuff in pairs(ccBuffs) do
                if string.find(buffName, ccBuff) then
                    return true
                end
            end
        end
    end
    
    -- Check if target is moving very slowly (likely slowed)
    if target.ms < 200 then
        return true
    end
    
    return false
end

-- Check if skillshot will collide with minions
function Elise:WillCollideWithMinions(startPos, endPos)
    if not startPos or not endPos then return false end
    
    local minions = self:GetMinionsInRange(1200)
    if #minions == 0 then return false end
    
    -- Simple collision detection along the line
    local dx = endPos.x - startPos.x
    local dz = endPos.z - startPos.z
    local distance = math.sqrt(dx * dx + dz * dz)
    
    if distance == 0 then return false end
    
    -- Normalize direction vector
    dx = dx / distance
    dz = dz / distance
    
    -- Check each minion
    for _, minion in pairs(minions) do
        if IsValid(minion) then
            -- Vector from start to minion
            local minionDx = minion.pos.x - startPos.x
            local minionDz = minion.pos.z - startPos.z
            
            -- Project minion position onto the line
            local projection = minionDx * dx + minionDz * dz
            
            -- Only check if projection is within the skillshot range
            if projection > 0 and projection < distance then
                -- Calculate perpendicular distance
                local perpX = minionDx - projection * dx
                local perpZ = minionDz - projection * dz
                local perpDistance = math.sqrt(perpX * perpX + perpZ * perpZ)
                
                -- E has width of 55, add minion radius (~30)
                if perpDistance < 85 then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Analyze target movement pattern for better E timing
function Elise:AnalyzeTargetMovement(target)
    if not target then return "unknown" end
    
    local currentTime = GameTimer()
    local currentPos = target.pos
    
    -- Track position changes
    if self.castingContext.lastTargetPosition then
        local timeDiff = currentTime - self.castingContext.targetPositionTime
        if timeDiff > 0.1 then -- Update every 100ms
            local posDiff = GetDistance(self.castingContext.lastTargetPosition, currentPos)
            local speed = posDiff / timeDiff
            
            -- Categorize movement pattern
            if speed < 50 then
                return "stationary" -- Standing still or micro-movements
            elseif speed > 400 then
                return "fast_moving" -- Moving very fast
            elseif target.pathing.hasMovePath then
                if target.pathing.isDashing then
                    return "dashing" -- Using dash/blink
                else
                    return "predictable" -- Normal movement with path
                end
            else
                return "erratic" -- No clear path, likely juking
            end
        end
    end
    
    -- Update tracking
    self.castingContext.lastTargetPosition = {x = currentPos.x, y = currentPos.y, z = currentPos.z}
    self.castingContext.targetPositionTime = currentTime
    
    return "unknown"
end

-- Enhanced E casting decision with movement analysis
function Elise:ShouldCastE(target)
    if not target then return false end
    
    local distance = GetDistance(myHero.pos, target.pos)
    local movementPattern = self:AnalyzeTargetMovement(target)
    
    -- Check if we hit a recent E (target has our stun/root)
    if self:HasOurCCBuff(target) then
        -- Reset miss counter on successful hit
        self.castingContext.consecutiveMisses = 0
    end
    
    -- Always try to cast on good opportunities instead of random probability
    local shouldCast = true
    
    -- Don't cast on very difficult targets unless they're CC'd
    if movementPattern == "dashing" then
        shouldCast = self:IsTargetCCed(target) -- Only cast on dashing targets if CC'd
    elseif movementPattern == "fast_moving" and not self:IsTargetCCed(target) then
        -- For fast moving targets, allow casting at longer range (85% instead of 70%)
        shouldCast = distance < (self.E.range * 0.85) -- Only cast if reasonably close
    end
    
    return shouldCast
end

-- Check if target has our CC buff (Elise's Cocoon)
function Elise:HasOurCCBuff(target)
    if not target then return false end
    
    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and buff.count > 0 then
            local buffName = string.lower(buff.name)
            -- Elise's E applies these buffs
            if string.find(buffName, "eliseecocoon") or 
               string.find(buffName, "cocoon") or
               string.find(buffName, "elisee") then
                return true
            end
        end
    end
    
    return false
end

function Elise:GetBestClearTarget()
    local minions = self:GetMinionsInRange(1000)
    local jungle = {}
    local lane = {}
    
    for i = 1, #minions do
        local minion = minions[i]
        if minion.team == 300 then
            TableInsert(jungle, minion)
        else
            TableInsert(lane, minion)
        end
    end
    
    -- Prioritize jungle monsters
    if #jungle > 0 then
        return jungle[1]
    elseif #lane > 0 then
        return lane[1]
    end
    
    return nil
end

function Elise:CanLastHitWithQ(minion)
    if not minion then return false end
    
    local damage = self:GetQDamage(minion)
    return minion.health <= damage and minion.health > damage * 0.7
end

-- Initialize
DelayAction(function()
    _G.Elise = Elise()
end, math.max(0.07, 5 - Game.Timer()))
