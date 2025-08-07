local Version = 3.0
local Name = "DepressiveYasuo2"

-- Hero validation
local Heroes = {"Yasuo"}
if not table.contains(Heroes, myHero.charName) then return end

-- Load prediction system
require("DepressivePrediction")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
    end
end, 1.0)

-- Function to check if DepressivePrediction is working
local function CheckPredictionSystem()
    if not PredictionLoaded or not _G.DepressivePrediction then
        return false
    end
    
    -- Verify that the main function exists
    if not _G.DepressivePrediction.GetPrediction then
        return false
    end
    
    return true
end

-- Hotkey constants (fallback if not defined)
local HK_Q = HK_Q or _Q
local HK_W = HK_W or _W
local HK_E = HK_E or _E
local HK_R = HK_R or _R

-- Windows message constants
local KEY_DOWN = KEY_DOWN or 0x0100
local KEY_UP = KEY_UP or 0x0101

-- Constants
local SPELL_RANGE = {
    Q = 475,
    Q3 = 900,
    E = 475,
    R = 1200
}

local SPELL_SPEED = {
    Q = math.huge,
    Q3 = 1200,
    E = math.huge
}

local SPELL_DELAY = {
    Q = 0.4,
    Q3 = 0.4,
    E = 0.1,
    R = 0.5
}

local SPELL_RADIUS = {
    Q = 20,
    Q3 = 90,
    E = 100
}

-- Utility Functions - 2D Only
local function GetDistance(p1, p2)
    if not p1 or not p2 then return math.huge end
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

local function GetDistance2D(p1, p2)
    if not p1 or not p2 then return math.huge end
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

local function Ready(spell)
    if not spell then return false end
    local spellData = myHero:GetSpellData(spell)
    if not spellData then return false end
    return spellData.currentCd == 0 and Game.CanUseSpell(spell) == 0
end

local function IsValidTarget(target, range)
    if not target then return false end
    if target.dead or not target.visible or not target.isTargetable then return false end
    if target.team == myHero.team then return false end
    if range and GetDistance(myHero.pos, target.pos) > range then return false end
    return true
end

local function HasQ3()
    local spellData = myHero:GetSpellData(_Q)
    return spellData and spellData.name == "YasuoQ3Wrapper"
end

local function HasEBuff(target)
    if not target or not target.valid then return true end -- Prevent dash if target invalid
    
    -- Use YasuoThePackGod system for buff checking
    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and buff.count > 0 and buff.name == "YasuoE" then
            return true
        end
    end
    return false
end

-- Additional function from YasuoThePackGod for general buff checking
local function HasBuff(unit, name)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name == name then
            return true, buff.count
        end
    end
    return false
end

local function IsUnderEnemyTurret(position, safetyRange)
    safetyRange = safetyRange or 900
    for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i)
        if turret and turret.isEnemy and not turret.dead then
            local turretPos2D = {x = turret.pos.x, z = turret.pos.z}
            local targetPos2D = {x = position.x, z = position.z}
            if GetDistance2D(targetPos2D, turretPos2D) < safetyRange then
                return true
            end
        end
    end
    return false
end

-- Calculate position after E dash for turret safety check
local function CalculateEPosition(target)
    if not target or not target.pos then return nil end
    
    local heroPos = myHero.pos
    local targetPos = target.pos
    
    -- E dash distance is approximately 475 units, but we land slightly before the target
    local dashDistance = 475 - 50 -- Land 50 units before target
    local direction = (targetPos - heroPos):Normalized()
    local finalPosition = heroPos + (direction * dashDistance)
    
    return {x = finalPosition.x, z = finalPosition.z}
end

local function GetQDamage()
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end
    local baseDamage = {20, 40, 60, 80, 100}
    local adRatio = 1.05
    local totalAD = myHero.totalDamage
    return baseDamage[level] + (totalAD * adRatio)
end

local function GetEDamage()
    local level = myHero:GetSpellData(_E).level
    if level == 0 then return 0 end
    local baseDamage = {60, 70, 80, 90, 100}
    local apRatio = 0.6
    local totalAP = myHero.ap
    return baseDamage[level] + (totalAP * apRatio)
end

-- Prediction Functions - Using DepressivePrediction directly
local function GetPrediction(target, spell)
    if not target or not target.valid then return nil, 0 end
    
    -- Check if DepressivePrediction is properly loaded
    if CheckPredictionSystem() then
        local spellData = {}
        
        -- Dynamic spell data based on Q state
        if spell == "Q" or spell == "Q3" then
            if HasQ3() then
                -- Q3 (tornado) has longer range and different properties
                spellData = {
                    range = SPELL_RANGE.Q3,
                    speed = SPELL_SPEED.Q3,
                    delay = SPELL_DELAY.Q3,
                    radius = SPELL_RADIUS.Q3
                }
            else
                -- Q1/Q2 normal range
                spellData = {
                    range = SPELL_RANGE.Q,
                    speed = SPELL_SPEED.Q,
                    delay = SPELL_DELAY.Q,
                    radius = SPELL_RADIUS.Q
                }
            end
        else
            -- Other spells use direct lookup
            spellData = {
                range = SPELL_RANGE[spell],
                speed = SPELL_SPEED[spell],
                delay = SPELL_DELAY[spell],
                radius = SPELL_RADIUS[spell]
            }
        end
        
        -- Use DepressivePrediction direct API - 2D only
        local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
        
        local unitPos, castPos, timeToHit = _G.DepressivePrediction.GetPrediction(
            target,
            sourcePos2D,
            spellData.speed,
            spellData.delay,
            spellData.radius
        )
        
        if castPos and castPos.x and castPos.z then
            local hitChance = 4 -- Default to HIGH hit chance with DepressivePrediction
            -- Return 2D position only
            return {x = castPos.x, z = castPos.z}, hitChance
        end
    end
    
    -- Fallback prediction - 2D only
    return {x = target.pos.x, z = target.pos.z}, 2
end

-- Main Yasuo Class
class "DepressiveYasuo2"

function DepressiveYasuo2:__init()
    -- Walljump System
    self.walljumpSpots = {}
    self.selectedWalljumpSpot = nil
    self.walljumpExecuting = false
    self.walljumpStep = 0
    self.currentSequence = nil
    self.tempWalljumpPos = nil
    self.walljumpInitialPos = nil -- Track initial position for distance checking
    self.walljumpMovingToInitial = false -- Track if we're moving to initial position
    self.walljumpDelayStartTime = nil -- Track delay timer at initial position
    self.walljumpStartTime = nil -- Track when walljump started
    self.walljumpLastPosition = nil -- Track last known position
    self.walljumpStuckTime = nil -- Track if stuck in same position
    self.walljumpSpellWaitTime = nil -- Track if waiting for spells
    
    -- Cache variables for FPS optimization
    self.lastDrawUpdate = 0
    self.cachedSpellInfo = nil
    
    -- Combo System
    self.comboState = "idle"
    self.comboTarget = nil
    self.comboTimer = 0
    self.lastActionTime = 0
    
    -- Gapcloser System
    self.gapcloseTarget = nil
    self.gapcloseMinion = nil
    
    -- Safety System
    self.turretSafetyEnabled = true
    self.safetyRange = 900
    
    -- Key state tracking for automatic hotkeys
    self.keysPressed = {
        space = false,   -- 32 - Combo
        v = false,       -- 86 - Lane Clear  
        x = false,       -- 88 - Last Hit
        a = false,       -- 65 - Flee
        c = false        -- 67 - Harass
    }
    
    -- Beyblade (E-Q3-Flash) System
    self.beybladeState = "idle" -- idle, executing_beyblade
    self.beybladeTarget = nil
    self.beybladeStep = 0
    self.beybladeTimer = 0
    
    self:LoadMenu()
    self:LoadWalljumpSpots()
    
    -- Callbacks
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("WndMsg", function(msg, wParam) self:OnWndMsg(msg, wParam) end)
end

function DepressiveYasuo2:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveYasuo2", name = "Depressive - Yasuo"})
    
    -- Combo System
    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo System"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.combo:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.combo:MenuElement({id = "useR", name = "Use R", value = true})
    self.Menu.combo:MenuElement({id = "minHitChance", name = "Min Hit Chance", value = 3, min = 1, max = 6, step = 1})
    self.Menu.combo:MenuElement({id = "eqCombo", name = "E-Q Combo", value = true})
    
    -- Ultimate Settings (inspired by YasuoThePackGod)
    self.Menu:MenuElement({type = MENU, id = "ultimate", name = "Ultimate Settings"})
    self.Menu.ultimate:MenuElement({id = "minEnemiesR", name = "Min Enemies for R", value = 1, min = 1, max = 5, step = 1})
    self.Menu.ultimate:MenuElement({id = "maxHpForR", name = "Max HP% to R Single Target", value = 60, min = 20, max = 100, step = 5})
    self.Menu.ultimate:MenuElement({id = "allow1v1R", name = "Allow R in 1v1 if Killable", value = true})
    self.Menu.ultimate:MenuElement({id = "killableThreshold", name = "Killable HP Threshold %", value = 35, min = 15, max = 60, step = 5})
    self.Menu.ultimate:MenuElement({id = "prioritizeADC", name = "Prioritize ADC/Mid for R", value = true})
    self.Menu.ultimate:MenuElement({id = "teamfightR", name = "Use R in Teamfights (2+ enemies)", value = true})
    
    -- Gapcloser System
    self.Menu:MenuElement({type = MENU, id = "gapcloser", name = "Gapcloser System"})
    self.Menu.gapcloser:MenuElement({id = "enabled", name = "Enable Gapcloser", value = true})
    self.Menu.gapcloser:MenuElement({id = "maxRange", name = "Max Gapcloser Range", value = 1200, min = 600, max = 1500, step = 50})
    self.Menu.gapcloser:MenuElement({id = "useMinions", name = "Use Minions for Gapclosing", value = true})
    self.Menu.gapcloser:MenuElement({id = "checkTurret", name = "Check Turret Safety", value = true})
    
    -- Walljump System
    self.Menu:MenuElement({type = MENU, id = "walljump", name = "Walljump System"})
    self.Menu.walljump:MenuElement({id = "enabled", name = "Enable Walljump", value = true})
    self.Menu.walljump:MenuElement({id = "executeKey", name = "Execute Walljump", key = string.byte("Z"), toggle = false})
    self.Menu.walljump:MenuElement({id = "cancelKey", name = "Cancel Walljump", key = string.byte("B"), toggle = false})
    self.Menu.walljump:MenuElement({id = "selectionRange", name = "Selection Range", value = 300, min = 100, max = 500, step = 50})
    
    -- Turret Safety
    self.Menu:MenuElement({type = MENU, id = "safety", name = "Turret Safety"})
    self.Menu.safety:MenuElement({id = "enabled", name = "Enable Turret Safety", value = true})
    self.Menu.safety:MenuElement({id = "range", name = "Safety Range", value = 900, min = 700, max = 1100, step = 50})
    self.Menu.safety:MenuElement({id = "allowLowHP", name = "Allow under turret if enemy HP < %", value = 20, min = 10, max = 40, step = 5})
    
    -- Harass
    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useE", name = "Use E on minions", value = true})
    self.Menu.harass:MenuElement({id = "useQ", name = "Use Q after E", value = true})
    
    -- Clear
    self.Menu:MenuElement({type = MENU, id = "clear", name = "Lane Clear"})
    self.Menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.clear:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.clear:MenuElement({id = "stackQ", name = "Stack Q on minions", value = true})
    self.Menu.clear:MenuElement({id = "allowEUnderTurret", name = "Allow E under Enemy Turret", value = false})
    
    -- Drawing
    self.Menu:MenuElement({type = MENU, id = "drawing", name = "Drawing"})
    self.Menu.drawing:MenuElement({id = "walljumpSpots", name = "Draw Walljump Spots", value = true})
    self.Menu.drawing:MenuElement({id = "ranges", name = "Draw Ranges", value = true})
    self.Menu.drawing:MenuElement({id = "prediction", name = "Draw Predictions", value = true})
    self.Menu.drawing:MenuElement({id = "status", name = "Draw Status", value = true})
    
    -- Beyblade System (E-Q3-Flash Combo)
    self.Menu:MenuElement({type = MENU, id = "beyblade", name = "Beyblade (E-Q3-Flash)"})
    self.Menu.beyblade:MenuElement({id = "enabled", name = "Enable Beyblade Combo", value = true})
    self.Menu.beyblade:MenuElement({id = "key", name = "Beyblade Key", key = string.byte("T"), toggle = false})
    self.Menu.beyblade:MenuElement({id = "maxRange", name = "Max Target Range", value = 1100, min = 600, max = 1200, step = 50})
    self.Menu.beyblade:MenuElement({id = "flashRange", name = "Flash Range", value = 450, min = 350, max = 450, step = 25})
    self.Menu.beyblade:MenuElement({id = "autoFlash", name = "Auto Flash after Q3", value = true})
    self.Menu.beyblade:MenuElement({id = "requireQ3", name = "Only use when Q3 ready", value = true})
    self.Menu.beyblade:MenuElement({id = "minHitChance", name = "Min Q3 Hit Chance", value = 3, min = 1, max = 6, step = 1})
end

function DepressiveYasuo2:LoadWalljumpSpots()
    -- Default walljump spots for Summoner's Rift - 2D coordinates
    self.walljumpSpots = {
        -- Custom Raptors Walljump
        {
            name = "Raptor Tower",
            position = {x = 7194, z = 5136},
            sequence = {
                {type = "cast", spell = _E, position = {x = 6973, z = 5372}, delay = 0.1}, -- E a posición exacta especificada
                {type = "cast", spell = _Q, position = {x = 6973, z = 5372}, delay = 0.15}, -- Q en la misma posición (EQ combo)
                {type = "cast", spell = _E, position = {x = 6811, z = 5528}, delay = 0.4} -- E final a posición exacta especificada
            }
        },
        -- Custom Multi-Position Walljump
        {
            name = "Raptor Tower",
            position = {x = 7638, z = 9828}, -- Posición inicial (Custom Spot 2)
            sequence = {
                {type = "cast", spell = _E, position = {x = 7856, z = 9630}, delay = 0.1}, -- E a posición 3
                {type = "cast", spell = _Q, position = {x = 7856, z = 9630}, delay = 0.15}, -- Q en posición 3 (EQ combo)
                {type = "cast", spell = _E, position = {x = 7997, z = 9486}, delay = 0.4} -- E final a posición 4
            }
        },
        -- W Start Combo (Updated from new recording)
        {
            name = "Bait Enemy",
            position = {x = 8230, z = 3140}, -- Posición inicial
            sequence = {
                {type = "cast", spell = _E, position = {x = 8272, z = 2694}, delay = 0.1}, -- E inicial
                {type = "cast", spell = _Q, position = {x = 8272, z = 2694}, delay = 0.2}, -- Q en la misma posición (EQ combo)
                {type = "click", position = {x = 8640, z = 2644}, delay = 0.4}, -- Click de posicionamiento
                {type = "cast", spell = _E, position = {x = 8488, z = 2740}, delay = 0.6} -- E final después de 0.5s
            }
        },
        {
            name = "Bait Enemy",
            position = {x = 6611, z = 11706}, -- Posición inicial
            sequence = {
                {type = "cast", spell = _E, position = {x = 6561, z = 12153}, delay = 0.1}, -- E inicial (EQ combo)
                {type = "cast", spell = _Q, position = {x = 6561, z = 12153}, delay = 0.2}, -- Q en la misma posición (EQ combo)
                {type = "click", position = {x = 6158, z = 12238}, delay = 0.4}, -- Click de posicionamiento
                {type = "cast", spell = _E, position = {x = 6346, z = 12148}, delay = 0.7} -- E final
            }
        },
        {
            name = "River Escape",
            position = {x = 7208, z = 5975}, -- Posición inicial
            sequence = {
                {type = "cast", spell = _E, position = {x = 6957, z = 5599}, delay = 0.1}, -- E inicial (EQ combo)
                {type = "cast", spell = _Q, position = {x = 6957, z = 5599}, delay = 0.2}, -- Q en la misma posición (EQ combo)
                {type = "click", position = {x = 6730, z = 5433}, delay = 0.2}, -- Click de posicionamiento (0.2s como especificaste)
                {type = "cast", spell = _E, position = {x = 6780, z = 5543}, delay = 0.4} -- E final
            }
        },
        {
            name = "Gromp Jump",
            position = {x = 2267, z = 8410}, -- Posición inicial
            sequence = {
                {type = "cast", spell = _E, position = {x = 2095, z = 8428}, delay = 0.1} -- E directo al gromp
            }
        },
    }
end

function DepressiveYasuo2:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    -- Cancel walljump
    if self.Menu.walljump.cancelKey:Value() then
        self:CancelWalljump()
    end
    
    -- Execute walljump directamente al más cercano al mouse (tecla Z)
    if self.Menu.walljump.executeKey:Value() and not self.walljumpExecuting then
        self:ExecuteClosestWalljumpToMouse()
    end
    
    -- Execute ongoing walljump
    if self.walljumpExecuting then
        self:CheckWalljumpStatus()
        self:ExecuteWalljumpSequence()
    end
    
    -- Beyblade System (E-Q3-Flash Combo)
    if self.Menu.beyblade.enabled:Value() and self.Menu.beyblade.key:Value() then
        self:HandleBeyblade()
    end
    
    -- Execute ongoing beyblade combo
    if self.beybladeState ~= "idle" then
        self:ExecuteBeybladeCombo()
    end
    
    -- Automatic hotkeys detection
    -- Space - Combo
    if self.keysPressed.space then
        self:Combo()
    end
    
    -- V - Lane Clear
    if self.keysPressed.v then
        self:Clear()
    end
    
    -- X - Last Hit
    if self.keysPressed.x then
        self:LastHit()
    end
    
    -- A - Flee
    if self.keysPressed.a then
        self:Flee()
    end
    
    -- C - Harass
    if self.keysPressed.c then
        self:Harass()
    end
end

function DepressiveYasuo2:Draw()
    if myHero.dead then return end
    
    local currentTimer = Game.Timer()
    
    -- Draw walljump spots - 2D only
    if self.Menu.drawing.walljumpSpots:Value() and #self.walljumpSpots > 0 then
        for i, spot in ipairs(self.walljumpSpots) do
            local color = Draw.Color(255, 255, 255, 0)
            local spotPos2D = Vector(spot.position.x, myHero.pos.y, spot.position.z)
            Draw.Circle(spotPos2D, 100, 3, color)
            Draw.Text(spot.name, 12, spotPos2D:To2D(), color)
        end
    end
    
    -- Draw selection range for walljumps - 2D circle
    if self.Menu.drawing.ranges:Value() then
        Draw.Circle(myHero.pos, self.Menu.walljump.selectionRange:Value(), 2, Draw.Color(100, 255, 255, 255))
    end
    
    -- Draw ranges - 2D circles
    if self.Menu.drawing.ranges:Value() then
        if Ready(_Q) then
            local range = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
            Draw.Circle(myHero.pos, range, 2, Draw.Color(100, 0, 255, 0))
        end
        
        if Ready(_E) then
            Draw.Circle(myHero.pos, SPELL_RANGE.E, 2, Draw.Color(100, 255, 0, 255))
        end
    end
    
    -- Draw status
    if self.Menu.drawing.status:Value() then
        local statusText = "Ready"
        
        if self.beybladeState ~= "idle" then
            statusText = "Executing Beyblade: Step " .. self.beybladeStep
        elseif self.walljumpExecuting then
            statusText = "Executing Walljump: Step " .. self.walljumpStep
        elseif self.comboState ~= "idle" then
            statusText = "Combo State: " .. self.comboState
        end
        
        Draw.Text(statusText, 16, 100, 100, Draw.Color(255, 255, 255, 255))
        
        -- Show prediction system status
        local predStatus = CheckPredictionSystem() and "DepressivePrediction: LOADED" or "DepressivePrediction: NOT LOADED"
        Draw.Text(predStatus, 14, 100, 120, CheckPredictionSystem() and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 0, 0))
        
        if not self.lastDrawUpdate or currentTimer - self.lastDrawUpdate > 0.1 then
            self.lastDrawUpdate = currentTimer
            self.cachedSpellInfo = {
                q = HasQ3() and "Q3 Ready" or string.format("Q: %.1f", myHero:GetSpellData(_Q).currentCd),
                e = string.format("E: %.1f", myHero:GetSpellData(_E).currentCd),
                r = string.format("R: %.1f", myHero:GetSpellData(_R).currentCd)
            }
        end
        
        if self.cachedSpellInfo then
            Draw.Text(self.cachedSpellInfo.q, 14, 100, 140, Draw.Color(255, 255, 255, 255))
            Draw.Text(self.cachedSpellInfo.e, 14, 100, 155, Draw.Color(255, 255, 255, 255))
            Draw.Text(self.cachedSpellInfo.r, 14, 100, 170, Draw.Color(255, 255, 255, 255))
        end
    end
    
    -- Predictions
    if self.Menu.drawing.prediction:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if IsValidTarget(hero, 800) then
                local pred, hitChance = GetPrediction(hero, "Q")
                if pred and hitChance >= self.Menu.combo.minHitChance:Value() then
                    local predPos2D = Vector(pred.x, myHero.pos.y, pred.z)
                    Draw.Circle(predPos2D, 50, 3, Draw.Color(255, 0, 255, 0))
                end
            end
        end
    end
end

function DepressiveYasuo2:OnWndMsg(msg, wParam)
    -- Handle automatic hotkeys
    if msg == KEY_DOWN then
        if wParam == 32 then -- Space key
            self.keysPressed.space = true
        elseif wParam == 86 then -- V key
            self.keysPressed.v = true
        elseif wParam == 88 then -- X key
            self.keysPressed.x = true
        elseif wParam == 65 then -- A key
            self.keysPressed.a = true
        elseif wParam == 67 then -- C key
            self.keysPressed.c = true
        end
    elseif msg == KEY_UP then
        if wParam == 32 then -- Space key
            self.keysPressed.space = false
        elseif wParam == 86 then -- V key
            self.keysPressed.v = false
        elseif wParam == 88 then -- X key
            self.keysPressed.x = false
        elseif wParam == 65 then -- A key
            self.keysPressed.a = false
        elseif wParam == 67 then -- C key
            self.keysPressed.c = false
        end
    end
end

function DepressiveYasuo2:ExecuteClosestWalljumpToMouse()
    if self.walljumpExecuting then return end
    
    local mousePos = Game.mousePos()
    local mousePos2D = {x = mousePos.x, z = mousePos.z}
    local closestSpot = nil
    local closestDistance = math.huge
    local maxRange = self.Menu.walljump.selectionRange:Value()
    
    -- Buscar el walljump más cercano al mouse dentro del rango
    for i, spot in ipairs(self.walljumpSpots) do
        local spotPos2D = {x = spot.position.x, z = spot.position.z}
        local distance = GetDistance2D(mousePos2D, spotPos2D)
        
        if distance < maxRange and distance < closestDistance then
            closestDistance = distance
            closestSpot = i
        end
    end
    
    -- Si encontramos un walljump cercano al mouse, ejecutarlo directamente
    if closestSpot then
        self.selectedWalljumpSpot = closestSpot
        self:StartWalljump()
    end
end

function DepressiveYasuo2:AddWalljumpSpot(position)
    local spotName = "Custom Spot " .. (#self.walljumpSpots + 1)
    local newSpot = {
        name = spotName,
        position = {x = position.x, z = position.z},
        sequence = {
            {type = "move", position = {x = position.x - 150, z = position.z - 150}, delay = 0.1},
            {type = "cast", spell = _E, target = "minion", delay = 0.2},
            {type = "move", position = {x = position.x + 150, z = position.z + 150}, delay = 0.1}
        }
    }
    
    table.insert(self.walljumpSpots, newSpot)
end

function DepressiveYasuo2:StartWalljump()
    if not self.selectedWalljumpSpot or self.walljumpExecuting then return end
    
    local spot = self.walljumpSpots[self.selectedWalljumpSpot]
    if not spot then return end
    
    -- ALWAYS move to the initial position first, regardless of current position
    local initialPos = Vector(spot.position.x, myHero.pos.y, spot.position.z)
    Control.Move(initialPos)
    
    -- Store initial position for distance checking
    self.walljumpInitialPos = {x = spot.position.x, z = spot.position.z}
    self.walljumpMovingToInitial = true
    
    self.walljumpExecuting = true
    self.walljumpStep = 1
    self.currentSequence = spot.sequence
    self.lastActionTime = Game.Timer()
    
    -- Initialize verification variables
    self.walljumpStartTime = Game.Timer()
    self.walljumpLastPosition = {x = myHero.pos.x, z = myHero.pos.z}
    self.walljumpStuckTime = nil
end

function DepressiveYasuo2:IsSafeToEInClear(target)
    if not target then return false end
    
    -- Si la opción de permitir E bajo torre está activada, no verificar seguridad
    if self.Menu.clear.allowEUnderTurret:Value() then
        return true
    end
    
    -- Calcular la posición después del dash E
    local ePosition = CalculateEPosition(target)
    if not ePosition then return false end
    
    -- Verificar si la posición después del E está bajo torre enemiga
    local safetyRange = self.Menu.safety.range:Value()
    return not IsUnderEnemyTurret(ePosition, safetyRange)
end

function DepressiveYasuo2:IsSafeToE(target)
    if not target then return false end
    
    -- Para combos normales, siempre usar el sistema de seguridad general
    if not self.Menu.safety.enabled:Value() then
        return true
    end
    
    -- Calcular la posición después del dash E
    local ePosition = CalculateEPosition(target)
    if not ePosition then return false end
    
    -- Verificar si la posición después del E está bajo torre enemiga
    local safetyRange = self.Menu.safety.range:Value()
    local isUnderTurret = IsUnderEnemyTurret(ePosition, safetyRange)
    
    -- Si está bajo torre, verificar si el enemigo tiene poca vida para permitir la jugada
    if isUnderTurret and target.health then
        local allowLowHP = self.Menu.safety.allowLowHP:Value()
        local hpPercent = (target.health / target.maxHealth) * 100
        return hpPercent <= allowLowHP
    end
    
    return not isUnderTurret
end

function DepressiveYasuo2:CheckWalljumpStatus()
    if not self.walljumpExecuting then return end
    
    local currentTime = Game.Timer()
    local currentPos = {x = myHero.pos.x, z = myHero.pos.z}
    
    -- Check if walljump has been running for too long (timeout)
    if self.walljumpStartTime and currentTime - self.walljumpStartTime > 15 then
        self:ResetWalljumpState("Timeout: Walljump took too long")
        return
    end
    
    -- Check if hero is stuck in the same position
    if self.walljumpLastPosition then
        local distanceMoved = GetDistance2D(currentPos, self.walljumpLastPosition)
        
        if distanceMoved < 5 then -- If moved less than 5 units
            if not self.walljumpStuckTime then
                self.walljumpStuckTime = currentTime
            elseif currentTime - self.walljumpStuckTime > 3 then -- Stuck for 3 seconds
                self:ResetWalljumpState("Hero stuck in position")
                return
            end
        else
            -- Hero is moving, reset stuck timer
            self.walljumpStuckTime = nil
        end
    end
    
    -- Update last position
    self.walljumpLastPosition = {x = currentPos.x, z = currentPos.z}
    
    -- Check if user issued a move command that's far from walljump area
    if self.walljumpInitialPos then
        local distanceFromWalljump = GetDistance2D(currentPos, self.walljumpInitialPos)
        
        -- If hero is very far from walljump area and we're still in initial movement phase
        if self.walljumpMovingToInitial and distanceFromWalljump > 800 then
            -- Check if user is moving away from walljump (user cancelled)
            local mousePos = Game.mousePos()
            local mousePos2D = {x = mousePos.x, z = mousePos.z}
            local distanceMouseToWalljump = GetDistance2D(mousePos2D, self.walljumpInitialPos)
            
            if distanceMouseToWalljump > distanceFromWalljump then
                self:ResetWalljumpState("User cancelled movement")
                return
            end
        end
    end
    
    -- Check if spells are not available when they should be
    if self.currentSequence and self.walljumpStep <= #self.currentSequence then
        local action = self.currentSequence[self.walljumpStep]
        if action and action.type == "cast" then
            if action.spell == _E and not Ready(_E) then
                -- E should be available for walljump, if not available for too long, reset
                if not self.walljumpSpellWaitTime then
                    self.walljumpSpellWaitTime = currentTime
                elseif currentTime - self.walljumpSpellWaitTime > 5 then
                    self:ResetWalljumpState("E spell not available")
                    return
                end
            elseif action.spell == _Q and not Ready(_Q) then
                -- Q should be available, if not available for too long, reset
                if not self.walljumpSpellWaitTime then
                    self.walljumpSpellWaitTime = currentTime
                elseif currentTime - self.walljumpSpellWaitTime > 5 then
                    self:ResetWalljumpState("Q spell not available")
                    return
                end
            end
        else
            -- Reset spell wait time if not casting
            self.walljumpSpellWaitTime = nil
        end
    end
end

function DepressiveYasuo2:ResetWalljumpState(reason)
    if reason then
        -- Optional: you can remove this print if you don't want debug info
        -- print("Walljump reset: " .. reason)
    end
    
    self.walljumpExecuting = false
    self.walljumpStep = 0
    self.currentSequence = nil
    self.selectedWalljumpSpot = nil
    self.walljumpInitialPos = nil
    self.walljumpMovingToInitial = false
    self.walljumpDelayStartTime = nil
    self.walljumpStartTime = nil
    self.walljumpLastPosition = nil
    self.walljumpStuckTime = nil
    self.walljumpSpellWaitTime = nil
end

function DepressiveYasuo2:ExecuteWalljumpSequence()
    if not self.currentSequence or self.walljumpStep > #self.currentSequence then
        self:CompleteWalljump()
        return
    end
    
    -- Check if we're still moving to initial position
    if self.walljumpMovingToInitial and self.walljumpInitialPos then
        local currentPos2D = {x = myHero.pos.x, z = myHero.pos.z}
        local distanceToInitial = GetDistance2D(currentPos2D, self.walljumpInitialPos)
        
        if distanceToInitial <= 15 then
            -- First time reaching position - set delay timer
            if not self.walljumpDelayStartTime then
                self.walljumpDelayStartTime = Game.Timer()
            end
            
            local currentTime = Game.Timer()
            if currentTime - self.walljumpDelayStartTime >= 0 then -- Sin delay
                self.walljumpMovingToInitial = false
                self.walljumpDelayStartTime = nil
                self.lastActionTime = Game.Timer() -- Reset timer to start sequence
            else
                -- Still waiting, don't execute sequence yet
                return
            end
        else
            -- Still moving to initial position, reset delay timer if it was set
            self.walljumpDelayStartTime = nil
            return
        end
    end
    
    local currentTime = Game.Timer()
    local action = self.currentSequence[self.walljumpStep]
    
    -- Frame-perfect timing
    if currentTime - self.lastActionTime >= action.delay then
        if action.type == "move" then
            local movePos2D = Vector(action.position.x, myHero.pos.y, action.position.z)
            Control.Move(movePos2D)
            
        elseif action.type == "cast" then
            if action.spell == _E then
                if action.position then
                    -- Cast E to specific position
                    local ePos2D = Vector(action.position.x, myHero.pos.y, action.position.z)
                    Control.CastSpell(HK_E, ePos2D)
                else
                    -- Cast E to target
                    local target = self:FindWalljumpTarget(action.target)
                    if target and Ready(_E) then
                        Control.CastSpell(HK_E, target)
                    end
                end
            elseif action.spell == _W then
                if Ready(_W) then
                    -- Check if there's a specific position for W cast
                    if action.position then
                        local wPos2D = Vector(action.position.x, myHero.pos.y, action.position.z)
                        Control.CastSpell(HK_W, wPos2D)
                    else
                        Control.CastSpell(HK_W)
                    end
                end
            elseif action.spell == _Q then
                if Ready(_Q) then
                    -- Check if there's a specific position for Q cast
                    if action.position then
                        local qPos2D = Vector(action.position.x, myHero.pos.y, action.position.z)
                        Control.CastSpell(HK_Q, qPos2D)
                    else
                        Control.CastSpell(HK_Q)
                    end
                end
            end
        elseif action.type == "click" then
            -- Move to click position instead of using mouse events
            local clickPos2D = Vector(action.position.x, myHero.pos.y, action.position.z)
            Control.Move(clickPos2D)
        end
        
        self.walljumpStep = self.walljumpStep + 1
        self.lastActionTime = currentTime
    end
end

function DepressiveYasuo2:FindWalljumpTarget(targetType)
    if targetType == "minion" then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E and not HasEBuff(minion) then
                    return minion
                end
            end
        end
    elseif targetType == "krug" or targetType == "raptor" then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == 300 and not minion.dead then -- Jungle monsters
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E and not HasEBuff(minion) then
                    if targetType == "krug" and minion.charName:find("Krug") then
                        return minion
                    elseif targetType == "raptor" and minion.charName:find("Raptor") then
                        return minion
                    end
                end
            end
        end
    end
    return nil
end

function DepressiveYasuo2:CompleteWalljump()
    -- Add 0.5 second delay at exact position to prevent return movement
    DelayAction(function()
        self:ResetWalljumpState("Walljump completed successfully")
    end, 0.5)
end

function DepressiveYasuo2:CancelWalljump()
    if self.walljumpExecuting then
        self:ResetWalljumpState("Walljump cancelled by user")
    end
end

-- Combo Functions
function DepressiveYasuo2:Combo()
    local target = self:GetBestTarget()
    if not target then 
        return 
    end
    
    -- Auto stack Q when not in combat (priority system)
    if not self:IsInCombat() then
        self:StackQ()
        return
    end
    
    -- Check Q readiness and state
    local qSpellData = myHero:GetSpellData(_Q)
    local qReady = Ready(_Q)
    local qWillBeReadyAfterE = qSpellData and qSpellData.currentCd <= 0.5 and qSpellData.currentCd > 0
    local hasQ3 = HasQ3()
    
    -- Get positions and distances
    local basicAttackRange = myHero.range + myHero.boundingRadius + target.boundingRadius
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local distanceToTarget = GetDistance2D(heroPos2D, targetPos2D)
    
    -- PRIORITY 1: Ultimate combo (advanced airborne detection)
    if self.Menu.combo.useR:Value() and Ready(_R) then
        -- Check for knocked up enemies in range
        local knockedUpCount = self:CountKnockedUpEnemies(SPELL_RANGE.R, myHero.pos)
        local minEnemiesRequired = self.Menu.ultimate.minEnemiesR:Value()
        
        -- 1v1 Logic: Allow R on single target if they are killable
        local canUseR1v1 = false
        if knockedUpCount == 1 and self.Menu.ultimate.allow1v1R:Value() then
            local singleTarget = self:GetKnockedUpTarget()
            if singleTarget and self:IsTargetKillableWithR(singleTarget) then
                canUseR1v1 = true
            end
        end
        
        if knockedUpCount >= minEnemiesRequired or canUseR1v1 then
            -- Find the best target to R (prioritize low HP or multiple enemies)
            local bestRTarget = nil
            local bestScore = 0
            
            for i = 1, Game.HeroCount() do
                local enemy = Game.Hero(i)
                if IsValidTarget(enemy, SPELL_RANGE.R) and self:CanUseUltimate(enemy) then
                    local score = 100 -- Base score
                    local hpPercent = enemy.health / enemy.maxHealth
                    
                    -- HIGHEST PRIORITY: Killable targets (1v1 logic)
                    if self:IsTargetKillableWithR(enemy) then
                        score = score + 1000 -- Massive priority for killable targets
                    end
                    
                    -- For single target: check HP threshold (unless killable)
                    if knockedUpCount == 1 and hpPercent > (self.Menu.ultimate.maxHpForR:Value() / 100) and not self:IsTargetKillableWithR(enemy) then
                        score = 0 -- Don't use R on high HP single targets unless killable
                    else
                        -- Prioritize low HP enemies (higher chance to kill)
                        if hpPercent < 0.3 then
                            score = score + 200
                        elseif hpPercent < 0.5 then
                            score = score + 100
                        end
                        
                        -- Bonus for multiple enemies nearby (teamfight)
                        if self.Menu.ultimate.teamfightR:Value() then
                            local nearbyEnemies = self:CountKnockedUpEnemies(400, enemy.pos)
                            if nearbyEnemies >= 2 then
                                score = score + (nearbyEnemies * 75)
                            end
                        end
                        
                        -- Prioritize ADC and Mid laners
                        if self.Menu.ultimate.prioritizeADC:Value() and self:IsHighPriorityTarget(enemy) then
                            score = score + 100
                        end
                    end
                    
                    if score > bestScore and score > 0 then
                        bestScore = score
                        bestRTarget = enemy
                    end
                end
            end
            
            if bestRTarget then
                Control.CastSpell(HK_R, bestRTarget)
                return
            end
        end
    end
    
    -- PRIORITY 2: Q3 Tornado (highest priority damage spell)
    if self.Menu.combo.useQ:Value() and qReady and hasQ3 then
        local q3Pred, q3Chance = GetPrediction(target, "Q3")
        if q3Pred and q3Chance >= self.Menu.combo.minHitChance:Value() and distanceToTarget <= SPELL_RANGE.Q3 then
            Control.CastSpell(HK_Q, Vector(q3Pred.x, myHero.pos.y, q3Pred.z))
            return
        end
    end
    
    -- PRIORITY 3: E-Q3 Combo (gap close into tornado) - SOLO DIRECTO AL ENEMIGO
    if hasQ3 and qReady and Ready(_E) and distanceToTarget > SPELL_RANGE.Q3 and distanceToTarget <= SPELL_RANGE.E then
        -- Con Q3 cargada, SOLO usar E directo al target, NO a minions
        if not HasEBuff(target) then
            if self:IsSafeToE(target) then
                Control.CastSpell(HK_E, target)
                DelayAction(function()
                    if Ready(_Q) and HasQ3() then
                        local pred, chance = GetPrediction(target, "Q3")
                        if pred and chance >= 2 then
                            Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                        end
                    end
                end, 0.1)
                return
            end
        end
    end
    
    -- PRIORITY 4: Advanced E-Q Combo (standard combo) - SOLO si NO tienes Q3
    if self.Menu.combo.useE:Value() and self.Menu.combo.useQ:Value() and Ready(_E) and (qReady or qWillBeReadyAfterE) and not hasQ3 then
        -- Direct E-Q on target
        if not HasEBuff(target) and distanceToTarget <= SPELL_RANGE.E and self:IsSafeToE(target) then
            Control.CastSpell(HK_E, target)
            local qDelay = qReady and 0.1 or 0.2 -- Shorter delay if Q is ready
            DelayAction(function()
                if Ready(_Q) then
                    local pred, chance = GetPrediction(target, "Q")
                    if pred and chance >= self.Menu.combo.minHitChance:Value() then
                        Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                    end
                end
            end, qDelay)
            return
        end
        
        -- E-Q through minions (improved logic)
        if distanceToTarget <= 700 then
            local bestMinion = self:GetBestMinionForEQ(target)
            if bestMinion and not HasEBuff(bestMinion) and self:IsSafeToE(bestMinion) then
                Control.CastSpell(HK_E, bestMinion)
                local qDelay = qReady and 0.15 or 0.25
                DelayAction(function()
                    if Ready(_Q) then
                        local pred, chance = GetPrediction(target, "Q")
                        if pred and chance >= self.Menu.combo.minHitChance:Value() then
                            Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                        end
                    end
                end, qDelay)
                return
            end
        end
    end
    
    -- PRIORITY 5: Gapcloser for positioning
    if self.Menu.gapcloser.enabled:Value() and Ready(_E) and distanceToTarget > basicAttackRange then
        if self:ManualGapcloser() then
            return
        end
    end
    
    -- PRIORITY 6: Basic Q for poke/stack
    if self.Menu.combo.useQ:Value() and qReady and not hasQ3 then
        local qRange = SPELL_RANGE.Q
        if distanceToTarget <= qRange then
            local pred, chance = GetPrediction(target, "Q")
            if pred and chance >= self.Menu.combo.minHitChance:Value() then
                Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                return
            end
        end
    end
    
    -- PRIORITY 7: Basic E for gap closing
    if self.Menu.combo.useE:Value() and Ready(_E) and not HasEBuff(target) then
        if distanceToTarget <= SPELL_RANGE.E and distanceToTarget > basicAttackRange then
            if self:IsSafeToE(target) then
                Control.CastSpell(HK_E, target)
                return
            end
        end
    end
end

function DepressiveYasuo2:EQCombo(target)
    -- Find a minion to E to for better positioning
    local bestMinion = self:GetBestMinionForEQ(target)
    
    -- Check Q status before E
    local qSpellData = myHero:GetSpellData(_Q)
    local qReady = Ready(_Q)
    local qWillBeReadyAfterE = qSpellData and qSpellData.currentCd <= 0.5 and qSpellData.currentCd > 0
    
    if bestMinion and not HasEBuff(bestMinion) then
        local minionPos2D = {x = bestMinion.pos.x, z = bestMinion.pos.z}
        local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
        if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E then
            if not self.Menu.safety.enabled:Value() or self:IsSafeToE(bestMinion) then
                Control.CastSpell(HK_E, bestMinion)
                
                -- Queue Q after E - if Q will be ready after E (≤0.5s), use minimal delay since E resets Q CD to 0  
                local qDelay = qReady and 0.15 or (qWillBeReadyAfterE and 0.2 or 0.3)
                DelayAction(function()
                    if Ready(_Q) then
                        local pred, hitChance = GetPrediction(target, "Q")
                        if pred and hitChance >= 2 then
                            Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                        else
                            Control.CastSpell(HK_Q, target.pos)
                        end
                    end
                end, qDelay)
            end
        end
    end
end

function DepressiveYasuo2:EQ3FlashCombo()
    local target = self:GetBestTarget()
    if not target or not HasQ3() or not Ready(_E) or not Ready(_Q) then return end
    
    local flashSlot = self:GetSummonerSpellSlot("SummonerFlash")
    if not flashSlot or not Ready(flashSlot) then return end
    
    -- Start combo
    self.comboState = "eq3flash"
    self.comboTarget = target
    
    -- Find minion or use target directly
    local eTarget = self:GetBestMinionForEQ(target) or target
    
    if not HasEBuff(eTarget) and GetDistance(myHero.pos, eTarget.pos) <= SPELL_RANGE.E then
        Control.CastSpell(HK_E, eTarget)
        
        DelayAction(function()
            if Ready(_Q) and HasQ3() then
                local pred, hitChance = GetPrediction(target, "Q3")
                if pred and hitChance >= 2 then
                    Control.CastSpell(HK_Q, pred)
                else
                    Control.CastSpell(HK_Q, target.pos)
                end
                
                -- Flash after Q3
                DelayAction(function()
                    if Ready(flashSlot) then
                        local flashPos = myHero.pos:Extended(target.pos, 400)
                        Control.CastSpell(flashSlot, flashPos)
                    end
                    self.comboState = "idle"
                end, 0.2)
            end
        end, 0.1)
    end
end

function DepressiveYasuo2:BeybladeCombo()
    local target = self:GetBestTarget()
    if not target or not Ready(_E) or not Ready(_Q) then return end
    
    local flashSlot = self:GetSummonerSpellSlot("SummonerFlash")
    if not flashSlot or not Ready(flashSlot) then return end
    
    self.comboState = "beyblade"
    self.comboTarget = target
    
    -- E to minion or target
    local eTarget = self:GetBestMinionForEQ(target) or target
    
    if not HasEBuff(eTarget) and GetDistance(myHero.pos, eTarget.pos) <= SPELL_RANGE.E then
        Control.CastSpell(HK_E, eTarget)
        
        DelayAction(function()
            if Ready(_Q) then
                Control.CastSpell(HK_Q)
                
                DelayAction(function()
                    if Ready(flashSlot) then
                        local flashPos = myHero.pos:Extended(target.pos, 400)
                        Control.CastSpell(flashSlot, flashPos)
                        
                        DelayAction(function()
                            if Ready(_Q) and HasQ3() then
                                local pred, hitChance = GetPrediction(target, "Q3")
                                if pred and hitChance >= 2 then
                                    Control.CastSpell(HK_Q, pred)
                                else
                                    Control.CastSpell(HK_Q, target.pos)
                                end
                                
                                DelayAction(function()
                                    if Ready(_R) and self:CanUseUltimate(target) then
                                        Control.CastSpell(HK_R)
                                    end
                                    self.comboState = "idle"
                                end, 0.3)
                            end
                        end, 0.2)
                    end
                end, 0.15)
            end
        end, 0.1)
    end
end

function DepressiveYasuo2:Harass()
    if not self.Menu.harass.useE:Value() and not self.Menu.harass.useQ:Value() then return end
    
    local target = self:GetBestTarget()
    if not target then return end
    
    -- E-Q Harass
    if self.Menu.harass.useE:Value() and Ready(_E) then
        local minion = self:GetBestMinionForHarass(target)
        if minion and not HasEBuff(minion) then
            if GetDistance(myHero.pos, minion.pos) <= SPELL_RANGE.E then
                if self:IsSafeToE(minion) then
                    Control.CastSpell(HK_E, minion)
                    
                    if self.Menu.harass.useQ:Value() then
                        DelayAction(function()
                            if Ready(_Q) then
                                local pred, hitChance = GetPrediction(target, "Q")
                                if pred and hitChance >= 2 then
                                    Control.CastSpell(HK_Q, pred)
                                end
                            end
                        end, 0.1)
                    end
                end
            end
        end
    end
end

function DepressiveYasuo2:Clear()
    if not self.Menu.clear.useQ:Value() and not self.Menu.clear.useE:Value() then return end
    
    -- VERIFICACIÓN ESPECIAL: Si estamos bajo torre enemiga, SOLO usar Q, no E
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local isUnderTurret = IsUnderEnemyTurret(heroPos2D, self.Menu.safety.range:Value())
    
    if isUnderTurret and self.Menu.clear.useQ:Value() and Ready(_Q) then
        -- Solo Q bajo torre - buscar el mejor minion para golpear con Q
        local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
        local bestQPos = nil
        local bestScore = 0
        
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                
                if GetDistance2D(heroPos2D, minionPos2D) <= qRange then
                    local score = 1
                    
                    -- Contar minions adicionales en el área de Q
                    for j = 1, Game.MinionCount() do
                        local otherMinion = Game.Minion(j)
                        if otherMinion and otherMinion ~= minion and otherMinion.team ~= myHero.team and not otherMinion.dead then
                            local otherMinionPos2D = {x = otherMinion.pos.x, z = otherMinion.pos.z}
                            local radius = HasQ3() and SPELL_RADIUS.Q3 or SPELL_RADIUS.Q
                            if GetDistance2D(minionPos2D, otherMinionPos2D) <= radius then
                                score = score + 1
                            end
                        end
                    end
                    
                    if score > bestScore then
                        bestScore = score
                        bestQPos = Vector(minionPos2D.x, myHero.pos.y, minionPos2D.z)
                    end
                end
            end
        end
        
        -- Castear Q si encontramos un buen target
        if bestQPos then
            Control.CastSpell(HK_Q, bestQPos)
            return
        end
    end
    
    -- Check Q readiness - either ready or will be ready after E (≤0.5s cd resets to 0 with E)
    local qSpellData = myHero:GetSpellData(_Q)
    local qReady = Ready(_Q)
    local qWillBeReadyAfterE = qSpellData and qSpellData.currentCd <= 0.5 and qSpellData.currentCd > 0
    
    -- PRIORIDAD 0: Stack Q si hay minions con buff de E (YasuoE) para poder hacer EQ después
    if self.Menu.clear.useQ:Value() and qReady and not HasQ3() then
        -- Verificar si hay minions con buff de E que no podemos dashear
        local hasMinionsWithEBuff = false
        local minionsWithoutEBuff = 0
        
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                
                if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E then
                    if HasEBuff(minion) then
                        hasMinionsWithEBuff = true
                    else
                        minionsWithoutEBuff = minionsWithoutEBuff + 1
                    end
                end
            end
        end
        
        -- Si hay minions con E buff y pocos sin E buff, stackear Q
        if hasMinionsWithEBuff and minionsWithoutEBuff <= 1 then
            -- Buscar el mejor target para stackear Q (minions o jungle monsters)
            local bestQTarget = nil
            local qRange = SPELL_RANGE.Q
            
            -- Prioridad a minions sin E buff
            for i = 1, Game.MinionCount() do
                local minion = Game.Minion(i)
                if minion and minion.team ~= myHero.team and not minion.dead and not HasEBuff(minion) then
                    local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                    
                    if GetDistance2D(heroPos2D, minionPos2D) <= qRange then
                        bestQTarget = minion
                        break
                    end
                end
            end
            
            -- Si no hay minions sin E buff, usar jungle monsters
            if not bestQTarget then
                for i = 1, Game.MinionCount() do
                    local monster = Game.Minion(i)
                    if monster and monster.team == 300 and not monster.dead then -- Jungle monsters
                        local monsterPos2D = {x = monster.pos.x, z = monster.pos.z}
                        local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                        
                        if GetDistance2D(heroPos2D, monsterPos2D) <= qRange then
                            bestQTarget = monster
                            break
                        end
                    end
                end
            end
            
            -- Castear Q para stackear
            if bestQTarget then
                local pred, chance = GetPrediction(bestQTarget, "Q")
                if pred and chance >= 2 then
                    Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                else
                    Control.CastSpell(HK_Q, bestQTarget.pos)
                end
                return
            end
        end
    end
    
    -- PRIORIDAD 1: Lasthit con E (con mecánica de 0.5s Q)
    if self.Menu.clear.useE:Value() and Ready(_E) then
        local eDamage = GetEDamage()
        local bestLasthitMinion = nil
        local bestLasthitScore = 0
        
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead and not HasEBuff(minion) then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                
                if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E then
                    -- Verificar si puede ser killed con E
                    if minion.health <= eDamage and minion.health > myHero.totalDamage * 0.7 then
                        -- Priorizar minions con más vida (más oro)
                        local score = minion.health
                        
                        -- Bonus si Q no está disponible pero está cerca (priorizar E lasthit)
                        if not qReady and not qWillBeReadyAfterE then
                            score = score + 200
                        end
                        
                        -- Bonus si Q está listo o se reseteará con E (después del E podemos golpear más minions con Q)
                        if qReady or qWillBeReadyAfterE then
                            local futurePos2D = self:CalculateEPosition(minionPos2D)
                            local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
                            local minionsAfterE = 0
                            
                            for j = 1, Game.MinionCount() do
                                local otherMinion = Game.Minion(j)
                                if otherMinion and otherMinion ~= minion and otherMinion.team ~= myHero.team and not otherMinion.dead then
                                    local otherMinionPos2D = {x = otherMinion.pos.x, z = otherMinion.pos.z}
                                    if GetDistance2D(futurePos2D, otherMinionPos2D) <= qRange then
                                        minionsAfterE = minionsAfterE + 1
                                    end
                                end
                            end
                            
                            score = score + (minionsAfterE * 50) -- Bonus por posicionamiento
                        end
                        
                        if score > bestLasthitScore then
                            bestLasthitScore = score
                            bestLasthitMinion = minion
                        end
                    end
                end
            end
        end
        
        -- Ejecutar E lasthit si encontramos un minion válido y es seguro
        if bestLasthitMinion and self:IsSafeToEInClear(bestLasthitMinion) then
            Control.CastSpell(HK_E, bestLasthitMinion)
            
            -- Si Q está listo o se reseteará con E, usarlo después del E
            if qReady or qWillBeReadyAfterE then
                local qDelay = qReady and 0.15 or (qWillBeReadyAfterE and 0.2 or 0.3)
                DelayAction(function()
                    if Ready(_Q) then
                        Control.CastSpell(HK_Q)
                    end
                end, qDelay)
            end
            return
        end
    end
    
    -- PRIORIDAD 2: E-Q combo cuando ambos están disponibles o Q se reseteará con E (clearing general)
    if self.Menu.clear.useE:Value() and self.Menu.clear.useQ:Value() and Ready(_E) and (qReady or qWillBeReadyAfterE) then
        -- Buscar el mejor minion para E-Q combo
        local bestMinion = nil
        local bestScore = 0
        local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
        
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead and not HasEBuff(minion) then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                
                -- Verificar que el minion esté en rango de E y sea seguro
                if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E and self:IsSafeToEInClear(minion) then
                    -- Calcular posición después de E
                    local futurePos2D = self:CalculateEPosition(minionPos2D)
                    
                    -- Contar cuántos minions estarán en rango de Q desde esa posición
                    local minionsInQRange = 0
                    for j = 1, Game.MinionCount() do
                        local otherMinion = Game.Minion(j)
                        if otherMinion and otherMinion.team ~= myHero.team and not otherMinion.dead then
                            local otherMinionPos2D = {x = otherMinion.pos.x, z = otherMinion.pos.z}
                            if GetDistance2D(futurePos2D, otherMinionPos2D) <= qRange then
                                minionsInQRange = minionsInQRange + 1
                            end
                        end
                    end
                    
                    -- Score basado en cantidad de minions que podremos golpear con Q
                    local score = minionsInQRange
                    
                    -- Bonus si es Q3 (tornado) para múltiples minions
                    if HasQ3() and minionsInQRange >= 2 then
                        score = score + 5
                    end
                    
                    -- Solo considerar si puede golpear al menos 1 minion con Q
                    if score > bestScore and minionsInQRange >= 1 then
                        bestScore = score
                        bestMinion = minion
                    end
                end
            end
        end
        
        -- Ejecutar E-Q combo si encontramos un minion válido
        if bestMinion and bestScore > 0 then
            Control.CastSpell(HK_E, bestMinion)
            
            -- Queue Q después de E con delay apropiado - si Q se reseteará con E (≤0.5s), usar delay mínimo
            local qDelay = qReady and 0.15 or (qWillBeReadyAfterE and 0.2 or 0.3)
            DelayAction(function()
                if Ready(_Q) then
                    Control.CastSpell(HK_Q)
                end
            end, qDelay)
            return
        end
    end
    
    -- PRIORIDAD 3: Q solo para clear (cuando E no está disponible o no es seguro)
    if self.Menu.clear.useQ:Value() and qReady then
        local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
        local bestQPos = nil
        local bestQScore = 0
        
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                
                if GetDistance2D(heroPos2D, minionPos2D) <= qRange then
                    local score = 1
                    
                    -- Contar minions adicionales que serán golpeados por Q
                    for j = 1, Game.MinionCount() do
                        local otherMinion = Game.Minion(j)
                        if otherMinion and otherMinion ~= minion and otherMinion.team ~= myHero.team and not otherMinion.dead then
                            local otherMinionPos2D = {x = otherMinion.pos.x, z = otherMinion.pos.z}
                            local radius = HasQ3() and SPELL_RADIUS.Q3 or SPELL_RADIUS.Q
                            if GetDistance2D(minionPos2D, otherMinionPos2D) <= radius then
                                score = score + 1
                            end
                        end
                    end
                    
                    -- Bonus para Q3 (tornado) cuando puede golpear múltiples minions
                    if HasQ3() and score >= 2 then
                        score = score + 3
                    end
                    
                    -- Priorizar si E no está disponible o si hay muchos minions con E buff
                    if not Ready(_E) or score >= 3 then
                        score = score + 2
                    end
                    
                    if score > bestQScore and score >= 1 then
                        bestQScore = score
                        bestQPos = Vector(minionPos2D.x, myHero.pos.y, minionPos2D.z)
                    end
                end
            end
        end
        
        -- Castear Q si encontramos un buen target
        if bestQPos and bestQScore >= 1 then
            Control.CastSpell(HK_Q, bestQPos)
            return
        end
    end
end

function DepressiveYasuo2:LastHit()
    if not Ready(_Q) and not Ready(_E) then return end
    
    -- Find minions that can be last hit with Q
    if Ready(_Q) then
        local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                
                if GetDistance2D(heroPos2D, minionPos2D) <= qRange then
                    local qDamage = GetQDamage()
                    if minion.health <= qDamage and minion.health > myHero.totalDamage then
                        Control.CastSpell(HK_Q, minion.pos)
                        return
                    end
                end
            end
        end
    end
    
    -- Find minions that can be last hit with E
    if Ready(_E) then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead and not HasEBuff(minion) then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                
                if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E then
                    local eDamage = GetEDamage()
                    if minion.health <= eDamage and minion.health > myHero.totalDamage then
                        Control.CastSpell(HK_E, minion)
                        return
                    end
                end
            end
        end
    end
end

function DepressiveYasuo2:Flee()
    if not Ready(_E) then return end
    
    local mousePos = Game.mousePos()
    local mousePos2D = {x = mousePos.x, z = mousePos.z}
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    
    -- Buscar el mejor minion para hacer gapcloser hacia el mouse
    local bestMinion = nil
    local bestScore = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and not minion.dead and not HasEBuff(minion) then
            -- SOLO minions enemigos (team diferente) o neutrales (jungle monsters, team 300)
            if minion.team ~= myHero.team and (minion.team == 300 or minion.team ~= myHero.team) then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local distanceToMinion = GetDistance2D(heroPos2D, minionPos2D)
                
                -- Verificar que el minion esté en rango de E
                if distanceToMinion <= SPELL_RANGE.E then
                    -- Calcular si el E nos acerca al mouse
                    local currentDistanceToMouse = GetDistance2D(heroPos2D, mousePos2D)
                    local minionToMouseDistance = GetDistance2D(minionPos2D, mousePos2D)
                    
                    -- Solo considerar minions que nos acerquen al mouse
                    if minionToMouseDistance < currentDistanceToMouse then
                        local score = currentDistanceToMouse - minionToMouseDistance -- Más score = más cerca del mouse
                        
                        -- Bonus para minions que están en la dirección del mouse
                        local heroToMouse = {x = mousePos2D.x - heroPos2D.x, z = mousePos2D.z - heroPos2D.z}
                        local heroToMinion = {x = minionPos2D.x - heroPos2D.x, z = minionPos2D.z - heroPos2D.z}
                        
                        -- Producto escalar normalizado para verificar dirección similar
                        local heroToMouseMag = math.sqrt(heroToMouse.x^2 + heroToMouse.z^2)
                        local heroToMinionMag = math.sqrt(heroToMinion.x^2 + heroToMinion.z^2)
                        
                        if heroToMouseMag > 0 and heroToMinionMag > 0 then
                            local dotProduct = (heroToMouse.x * heroToMinion.x + heroToMouse.z * heroToMinion.z) / (heroToMouseMag * heroToMinionMag)
                            
                            -- Si el minion está en buena dirección hacia el mouse (coseno > 0.3)
                            if dotProduct > 0.3 then
                                score = score + (dotProduct * 200) -- Bonus por buena dirección
                            end
                        end
                        
                        -- Penalty por estar bajo torre enemiga (pero permitirlo si es para escapar)
                        local ePosition = CalculateEPosition(minion)
                        if ePosition and IsUnderEnemyTurret(ePosition, self.Menu.safety.range:Value()) then
                            score = score - 100 -- Penalty menor para escape
                        end
                        
                        -- Bonus extra para jungle monsters (team 300) ya que son más seguros para escape
                        if minion.team == 300 then
                            score = score + 50
                        end
                        
                        if score > bestScore then
                            bestScore = score
                            bestMinion = minion
                        end
                    end
                end
            end
        end
    end
    
    -- Ejecutar E al mejor minion encontrado
    if bestMinion and bestScore > 0 then
        Control.CastSpell(HK_E, bestMinion)
    end
end

-- Helper Functions
function DepressiveYasuo2:IsInCombat()
    -- Check if we're in combat with enemies (within 1000 units)
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if IsValidTarget(enemy, 1000) then
            return true
        end
    end
    return false
end

function DepressiveYasuo2:StackQ()
    -- Smart Q stacking system - prioritize minions over monsters
    if not Ready(_Q) or HasQ3() then return end
    
    local qRange = SPELL_RANGE.Q
    local bestTarget = nil
    local bestScore = 0
    
    -- Priority 1: Minions (easier to hit, more reliable)
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= qRange then
                local score = 100 -- Base score for minions
                
                -- Prefer closer minions
                score = score + (qRange - distance) / 10
                
                -- Prefer low HP minions (easier to predict)
                if minion.health < minion.maxHealth * 0.5 then
                    score = score + 20
                end
                
                if score > bestScore then
                    bestScore = score
                    bestTarget = minion
                end
            end
        end
    end
    
    -- Priority 2: Jungle monsters (if no minions available)
    if not bestTarget then
        for i = 1, Game.MinionCount() do
            local monster = Game.Minion(i)
            if monster and monster.team == 300 and not monster.dead then -- Neutral monsters
                local distance = GetDistance(myHero.pos, monster.pos)
                if distance <= qRange then
                    local score = 80 -- Lower base score than minions
                    score = score + (qRange - distance) / 10
                    
                    if score > bestScore then
                        bestScore = score
                        bestTarget = monster
                    end
                end
            end
        end
    end
    
    -- Cast Q on best target
    if bestTarget then
        local pred, chance = GetPrediction(bestTarget, "Q")
        if pred and chance >= 2 then
            Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
        else
            Control.CastSpell(HK_Q, bestTarget.pos)
        end
    end
end

function DepressiveYasuo2:GetBestMinionForEQ(target)
    local bestMinion = nil
    local bestScore = 0
    local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead and not HasEBuff(minion) then
            local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
            
            -- Check if minion is in E range
            if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E then
                local minionToTarget = GetDistance2D(minionPos2D, targetPos2D)
                
                -- Check if target will be in Q range after E
                if minionToTarget <= qRange then
                    local score = 1000 - minionToTarget -- Prefer closer minions to target
                    
                    -- Bonus for Q3 positioning (better damage and wider hit)
                    if HasQ3() and minionToTarget <= SPELL_RANGE.Q3 * 0.8 then
                        score = score + 200
                    end
                    
                    -- Bonus for good angle (minion between hero and target)
                    local heroToTarget = GetDistance2D(heroPos2D, targetPos2D)
                    local heroToMinion = GetDistance2D(heroPos2D, minionPos2D)
                    if heroToMinion < heroToTarget then -- Minion is closer than target
                        score = score + 100
                    end
                    
                    -- Penalty for low HP minions (might die before combo)
                    if minion.health < minion.maxHealth * 0.3 then
                        score = score - 50
                    end
                    
                    if score > bestScore then
                        bestScore = score
                        bestMinion = minion
                    end
                end
            end
        end
    end
    
    return bestMinion
end

function DepressiveYasuo2:GetBestQ3Position()
    if not HasQ3() then return nil end
    
    local bestPos = nil
    local bestScore = 0
    local qRange = SPELL_RANGE.Q3
    
    -- Check around each minion to find best Q3 position
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead then
            local minionPos = minion.pos
            if GetDistance(myHero.pos, minionPos) <= qRange then
                local score = 1
                
                -- Count other minions that would be hit
                for j = 1, Game.MinionCount() do
                    local otherMinion = Game.Minion(j)
                    if otherMinion and otherMinion ~= minion and otherMinion.team ~= myHero.team and not otherMinion.dead then
                        if GetDistance(minionPos, otherMinion.pos) <= SPELL_RADIUS.Q3 then
                            score = score + 1
                        end
                    end
                end
                
                if score > bestScore and score >= 2 then -- At least 2 minions
                    bestScore = score
                    bestPos = Vector(minionPos.x, myHero.pos.y, minionPos.z)
                end
            end
        end
    end
    
    return bestPos
end

function DepressiveYasuo2:GetBestLasthitMinion(eDamage)
    local bestMinion = nil
    local bestScore = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead and not HasEBuff(minion) then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= SPELL_RANGE.E and minion.health <= eDamage then
                local score = 100
                
                -- Prefer closer minions
                score = score + (SPELL_RANGE.E - distance) / 10
                
                -- Bonus if it's a cannon minion
                if minion.charName:find("Siege") or minion.charName:find("Super") then
                    score = score + 50
                end
                
                if score > bestScore then
                    bestScore = score
                    bestMinion = minion
                end
            end
        end
    end
    
    return bestMinion
end

function DepressiveYasuo2:GetBestClearMinion()
    local bestMinion = nil
    local bestScore = 0
    local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead and not HasEBuff(minion) then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= SPELL_RANGE.E then
                -- Calculate future position after E
                local futurePos = self:CalculateEPosition({x = minion.pos.x, z = minion.pos.z})
                
                -- Count minions that will be in Q range after E
                local minionsInRange = 0
                for j = 1, Game.MinionCount() do
                    local otherMinion = Game.Minion(j)
                    if otherMinion and otherMinion.team ~= myHero.team and not otherMinion.dead then
                        local otherDistance = GetDistance2D(futurePos, {x = otherMinion.pos.x, z = otherMinion.pos.z})
                        if otherDistance <= qRange then
                            minionsInRange = minionsInRange + 1
                        end
                    end
                end
                
                if minionsInRange >= 2 then -- At least 2 minions for efficiency
                    local score = minionsInRange * 100
                    
                    if score > bestScore then
                        bestScore = score
                        bestMinion = minion
                    end
                end
            end
        end
    end
    
    return bestMinion
end

function DepressiveYasuo2:GetBestQPosition()
    local bestPos = nil
    local bestScore = 0
    local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= qRange then
                local score = 1
                local minionPos = minion.pos
                
                -- Count other minions in range
                for j = 1, Game.MinionCount() do
                    local otherMinion = Game.Minion(j)
                    if otherMinion and otherMinion ~= minion and otherMinion.team ~= myHero.team and not otherMinion.dead then
                        local otherDistance = GetDistance(minionPos, otherMinion.pos)
                        local radius = HasQ3() and SPELL_RADIUS.Q3 or SPELL_RADIUS.Q
                        if otherDistance <= radius then
                            score = score + 1
                        end
                    end
                end
                
                if score > bestScore then
                    bestScore = score
                    bestPos = Vector(minionPos.x, myHero.pos.y, minionPos.z)
                end
            end
        end
    end
    
    return bestPos
end

function DepressiveYasuo2:GetBestQPositionAfterE()
    -- Use current position as the position after E (simplified)
    return self:GetBestQPosition()
end

function DepressiveYasuo2:GetBestMinionForHarass(target)
    return self:GetBestMinionForEQ(target)
end

function DepressiveYasuo2:GetBestMinionForQ()
    local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead then
            local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
            local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
            if GetDistance2D(heroPos2D, minionPos2D) <= qRange then
                return minion
            end
        end
    end
    return nil
end

function DepressiveYasuo2:GetBestMinionForE()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead then
            local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
            local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
            if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E and not HasEBuff(minion) then
                return minion
            end
        end
    end
    return nil
end

function DepressiveYasuo2:GetMinionChainToTarget(target)
    local chain = {}
    local currentPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local maxChainLength = 3
    
    for chainStep = 1, maxChainLength do
        local bestMinion = nil
        local bestDistance = math.huge
        
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                if GetDistance2D(currentPos2D, minionPos2D) <= SPELL_RANGE.E and not HasEBuff(minion) then
                    local distToTarget = GetDistance2D(minionPos2D, targetPos2D)
                    if distToTarget < bestDistance then
                        bestDistance = distToTarget
                        bestMinion = minion
                    end
                end
            end
        end
        
        if bestMinion and bestDistance < GetDistance2D(currentPos2D, targetPos2D) then
            table.insert(chain, bestMinion)
            currentPos2D = {x = bestMinion.pos.x, z = bestMinion.pos.z}
            
            -- If we can reach target from this minion, we're done
            if GetDistance2D(currentPos2D, targetPos2D) <= SPELL_RANGE.E then
                break
            end
        else
            break
        end
    end
    
    return chain
end

function DepressiveYasuo2:GetBestTarget()
    local bestTarget = nil
    local bestPriority = 0
    local bestDistance = math.huge
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if IsValidTarget(hero, 1200) then
            local distance = GetDistance(myHero.pos, hero.pos)
            local priority = 1
            
            -- Prioritize low HP targets
            if hero.health / hero.maxHealth < 0.3 then
                priority = priority + 3
            elseif hero.health / hero.maxHealth < 0.5 then
                priority = priority + 2
            end
            
            -- Prioritize AD carries and mid laners
            if hero.charName:find("Jinx") or hero.charName:find("Caitlyn") or hero.charName:find("Ashe") or 
               hero.charName:find("Ahri") or hero.charName:find("Zed") or hero.charName:find("Yasuo") then
                priority = priority + 2
            end
            
            -- Prefer closer targets if same priority
            if priority > bestPriority or (priority == bestPriority and distance < bestDistance) then
                bestTarget = hero
                bestPriority = priority
                bestDistance = distance
            end
        end
    end
    
    return bestTarget
end

function DepressiveYasuo2:ManualGapcloser()
    local target = self:GetBestTarget()
    if not target or not self.Menu.gapcloser.enabled:Value() then 
        return false 
    end
    
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local distance = GetDistance2D(heroPos2D, targetPos2D)
    
    -- Don't gapclose if we're already close enough for basic abilities
    if distance <= SPELL_RANGE.Q then
        return false
    end
    
    if distance <= SPELL_RANGE.E and not HasEBuff(target) then
        -- Direct E to target
        if not self.Menu.gapcloser.checkTurret:Value() or self:IsSafeToE(target) then
            Control.CastSpell(HK_E, target)
            return true
        end
    elseif distance <= self.Menu.gapcloser.maxRange:Value() and self.Menu.gapcloser.useMinions:Value() then
        -- Use minions to gapclose
        local gapcloseMinion = self:FindGapcloseMinion(target)
        if gapcloseMinion then
            if not self.Menu.gapcloser.checkTurret:Value() or self:IsSafeToE(gapcloseMinion) then
                Control.CastSpell(HK_E, gapcloseMinion)
                return true
            end
        end
    end
    
    return false
end

function DepressiveYasuo2:FindGapcloseMinion(target)
    local bestMinion = nil
    local bestScore = 0
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local currentDistanceToTarget = GetDistance2D(heroPos2D, targetPos2D)
    
    local minionCount = 0
    local validMinions = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        minionCount = minionCount + 1
        
        if minion and minion.team ~= myHero.team and not minion.dead and not HasEBuff(minion) then
            local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
            
            -- Check if minion is in E range from current position
            if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E then
                validMinions = validMinions + 1
                
                -- Calculate future position after E (Yasuo stops behind the target)
                local futurePos2D = self:CalculateEPosition(minionPos2D)
                
                -- Calculate distance from future position to enemy
                local futureDistanceToTarget = GetDistance2D(futurePos2D, targetPos2D)
                
                -- Only consider minions that actually bring us closer to the enemy
                if futureDistanceToTarget < currentDistanceToTarget then
                    -- Calculate how much closer we get (improvement score)
                    local improvement = currentDistanceToTarget - futureDistanceToTarget
                    
                    -- Bonus score if we can reach target after E
                    local reachBonus = 0
                    if futureDistanceToTarget <= SPELL_RANGE.E then
                        reachBonus = 300 -- High priority if we can reach target directly after
                    elseif futureDistanceToTarget <= SPELL_RANGE.Q then
                        reachBonus = 150 -- Medium priority if we can Q after
                    end
                    
                    local totalScore = improvement + reachBonus
                    
                    if totalScore > bestScore then
                        bestScore = totalScore
                        bestMinion = minion
                    end
                end
            end
        end
    end
    
    return bestMinion
end

function DepressiveYasuo2:CalculateEPosition(targetPos2D)
    -- Calculate where Yasuo will be after E
    -- Yasuo dashes TOWARDS the target and stops just behind it (approximately 65 units past the target center)
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local dashDistance = 65 -- Yasuo stops 65 units past the target center
    
    -- Calculate direction from hero TO target (E direction)
    local dx = targetPos2D.x - heroPos2D.x
    local dz = targetPos2D.z - heroPos2D.z
    local distance = math.sqrt(dx * dx + dz * dz)
    
    -- Normalize direction vector
    if distance > 0 then
        dx = dx / distance
        dz = dz / distance
    else
        -- If positions are identical, use default direction
        dx = 0
        dz = 1
    end
    
    -- Calculate final position (past the target in the direction of the dash)
    local finalPos2D = {
        x = targetPos2D.x + (dx * dashDistance),
        z = targetPos2D.z + (dz * dashDistance)
    }
    
    return finalPos2D
end

function DepressiveYasuo2:Harass()
    local target = self:GetBestTarget()
    if not target then return end
    
    -- Find minion for harass
    if self.Menu.harass.useE:Value() and Ready(_E) then
        local harassMinion = self:GetBestMinionForEQ(target)
        if harassMinion and not HasEBuff(harassMinion) then
            Control.CastSpell(HK_E, harassMinion)
            
            if self.Menu.harass.useQ:Value() then
                DelayAction(function()
                    if Ready(_Q) then
                        local pred, hitChance = GetPrediction(target, "Q")
                        if pred and hitChance >= 2 then
                            Control.CastSpell(HK_Q, pred)
                        else
                            Control.CastSpell(HK_Q, target.pos)
                        end
                    end
                end, 0.15)
            end
        end
    end
end

function DepressiveYasuo2:IsSafeToE(target)
    if not self.Menu.safety.enabled:Value() then return true end
    
    local safetyRange = self.Menu.safety.range:Value()
    local allowLowHP = self.Menu.safety.allowLowHP:Value()
    
    -- Allow if target is low HP
    if target.health and target.maxHealth then
        if target.health / target.maxHealth * 100 <= allowLowHP then
            return true
        end
    end
    
    -- Check if we would be under turret after E - calculate Yasuo's position after E
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local futurePos2D = self:CalculateEPosition(targetPos2D)
    return not IsUnderEnemyTurret(futurePos2D, safetyRange)
end

function DepressiveYasuo2:CanUseUltimate(target)
    if not target or not Ready(_R) then return false end
    
    -- Use YasuoThePackGod's precise airborne detection method
    -- Check for knockup/airborne buff types (type 30 and 31 are the correct ones)
    local buffCount = target.buffCount or 0
    for i = 0, buffCount - 1 do
        local buff = target:GetBuff(i)
        if buff and buff.count > 0 then
            local bType = buff.type
            -- Type 30 = Airborne, Type 31 = Knockup (YasuoThePackGod method)
            if bType == 30 or bType == 31 then
                return true
            end
        end
    end
    
    return false
end

function DepressiveYasuo2:CountKnockedUpEnemies(range, position)
    -- Similar to YasuoThePackGod's KnockCount function
    local pos = position or myHero.pos
    local count = 0
    local rangeSq = range * range
    
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if IsValidTarget(enemy) then
            local distanceSq = GetDistance(pos, enemy.pos) * GetDistance(pos, enemy.pos)
            if distanceSq < rangeSq and self:CanUseUltimate(enemy) then
                count = count + 1
            end
        end
    end
    
    return count
end

function DepressiveYasuo2:GetKnockedUpTarget()
    -- Get the first knocked up target in R range
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if IsValidTarget(enemy, SPELL_RANGE.R) and self:CanUseUltimate(enemy) then
            return enemy
        end
    end
    return nil
end

function DepressiveYasuo2:IsTargetKillableWithR(target)
    if not target then return false end
    
    -- Get target's current HP percentage
    local hpPercent = (target.health / target.maxHealth) * 100
    
    -- Check if target is below killable threshold
    if hpPercent <= self.Menu.ultimate.killableThreshold:Value() then
        return true
    end
    
    -- Advanced killable calculation (estimate R damage + follow-up damage)
    local estimatedRDamage = self:CalculateRDamage(target)
    local estimatedFollowUpDamage = self:CalculateFollowUpDamage(target)
    local totalDamage = estimatedRDamage + estimatedFollowUpDamage
    
    -- Add safety margin (consider armor/MR reductions)
    local effectiveDamage = totalDamage * 0.8 -- 20% safety margin
    
    return target.health <= effectiveDamage
end

function DepressiveYasuo2:CalculateRDamage(target)
    if not target then return 0 end
    
    -- R damage calculation (200/300/400 + 150% bonus AD per enemy hit)
    local rLevel = myHero:GetSpellData(_R).level
    if rLevel == 0 then return 0 end
    
    local baseDamage = {200, 300, 400}
    local bonusAD = myHero.totalDamage - myHero.baseDamage
    local rDamage = baseDamage[rLevel] + (bonusAD * 1.5)
    
    -- Consider armor reduction (simplified)
    local targetArmor = target.armor
    local armorReduction = 100 / (100 + targetArmor)
    
    return rDamage * armorReduction
end

function DepressiveYasuo2:CalculateFollowUpDamage(target)
    if not target then return 0 end
    
    local totalDamage = 0
    
    -- Q damage if available
    if Ready(_Q) then
        totalDamage = totalDamage + GetQDamage() * 0.7 -- Consider armor
    end
    
    -- E damage if available
    if Ready(_E) and not HasEBuff(target) then
        totalDamage = totalDamage + GetEDamage() * 0.7 -- Consider MR
    end
    
    -- Auto attack damage (1-2 autos after R)
    totalDamage = totalDamage + (myHero.totalDamage * 1.5 * 0.7) -- 1.5 autos with armor consideration
    
    return totalDamage
end

function DepressiveYasuo2:IsHighPriorityTarget(target)
    if not target then return false end
    
    -- Check if target is ADC, Mid laner, or other high priority champions
    local priorityChamps = {
        "Jinx", "Caitlyn", "Ashe", "Vayne", "Tristana", "Lucian", "Ezreal", "Jhin", "MissFortune", "Sivir",
        "Ahri", "Zed", "Yasuo", "Azir", "Syndra", "LeBlanc", "Katarina", "Kassadin", "Orianna", "Viktor",
        "Veigar", "Annie", "Brand", "Xerath", "Lux", "Velkoz", "Ziggs", "Cassiopeia", "Ryze", "Twisted"
    }
    
    for _, champName in ipairs(priorityChamps) do
        if target.charName:find(champName) then
            return true
        end
    end
    
    return false
end

function DepressiveYasuo2:GetSummonerSpellSlot(spellName)
    -- Get summoner spell slot by name
    local summ1 = myHero:GetSpellData(SUMMONER_1)
    local summ2 = myHero:GetSpellData(SUMMONER_2)
    
    if summ1 and summ1.name == spellName then
        return SUMMONER_1
    elseif summ2 and summ2.name == spellName then
        return SUMMONER_2
    end
    
    return nil
end

function DepressiveYasuo2:AdvancedComboLogic(target)
    -- Advanced combo decision making based on game state
    local myHealth = myHero.health / myHero.maxHealth
    local targetHealth = target.health / target.maxHealth
    local hasQ3 = HasQ3()
    local qReady = Ready(_Q)
    local eReady = Ready(_E)
    local rReady = Ready(_R)
    
    -- Aggressive combo (when ahead or target is low)
    if targetHealth < 0.4 or myHealth > 0.7 then
        if hasQ3 and qReady and eReady then
            return "eq3_aggressive"
        elseif eReady and qReady then
            return "eq_aggressive"
        end
    end
    
    -- Safe combo (when behind or low health)
    if myHealth < 0.5 or targetHealth > 0.8 then
        if hasQ3 and qReady then
            return "q3_safe"
        elseif qReady then
            return "q_poke"
        end
    end
    
    -- Standard combo
    return "standard"
end

-- Beyblade System (E-Q3-Flash Combo) Functions
function DepressiveYasuo2:HandleBeyblade()
    -- Check if Q3 is ready (essential for Beyblade)
    if self.Menu.beyblade.requireQ3:Value() then
        if not HasQ3() or not Ready(_Q) then
            return
        end
    else
        if not HasQ3() or not Ready(_Q) then
            return
        end
    end
    
    -- Check if Flash is available
    local flashSpell = self:GetFlashSpell()
    if not flashSpell or not Ready(flashSpell) then
        return
    end
    
    -- Find best target for Beyblade
    local target = self:GetBestBeybladeTarget()
    if not target then
        return
    end
    
    -- Find best unit to E onto for optimal positioning
    local bestUnit = self:GetBestUnitForBeyblade(target)
    if not bestUnit then
        return
    end
    
    -- Start the Beyblade combo
    self.beybladeState = "executing_beyblade"
    self.beybladeTarget = target
    self.beybladeStep = 1
    self.beybladeTimer = Game.Timer()
    
    -- Execute first step immediately (E to positioning unit)
    if Ready(_E) and not HasEBuff(bestUnit) then
        Control.CastSpell(HK_E, bestUnit)
        
        -- Queue Q3 with small delay
        DelayAction(function()
            if Ready(_Q) and HasQ3() and self.beybladeState == "executing_beyblade" then
                local prediction, hitChance = GetPrediction(self.beybladeTarget, "Q3")
                local minHitChance = self.Menu.beyblade.minHitChance:Value()
                
                if prediction and hitChance >= minHitChance then
                    local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                    Control.CastSpell(HK_Q, predPos)
                else
                    Control.CastSpell(HK_Q, self.beybladeTarget.pos)
                end
                
                -- Queue Flash with delay after Q3
                if self.Menu.beyblade.autoFlash:Value() then
                    DelayAction(function()
                        if self.beybladeState == "executing_beyblade" and 
                           self.beybladeTarget and self.beybladeTarget.valid and not self.beybladeTarget.dead then
                            
                            local flashSpell = self:GetFlashSpell()
                            if flashSpell and Ready(flashSpell) then
                                local currentTarget = self.beybladeTarget
                                local flashPos = currentTarget.pos
                                local distance = GetDistance(myHero.pos, currentTarget.pos)
                                
                                -- Calculate optimal flash position
                                if distance > 200 then
                                    local direction = (currentTarget.pos - myHero.pos):Normalized()
                                    flashPos = myHero.pos + direction * math.min(self.Menu.beyblade.flashRange:Value(), distance - 150)
                                end
                                
                                -- Execute Flash
                                Control.SetCursorPos(flashPos)
                                if flashSpell == SUMMONER_1 then
                                    Control.KeyDown(HK_SUMMONER_1)
                                    Control.KeyUp(HK_SUMMONER_1)
                                else
                                    Control.KeyDown(HK_SUMMONER_2)
                                    Control.KeyUp(HK_SUMMONER_2)
                                end
                            end
                        end
                        
                        -- Reset combo state
                        self:ResetBeyblade()
                    end, 0.2)
                else
                    -- Reset if auto flash is disabled
                    DelayAction(function()
                        self:ResetBeyblade()
                    end, 0.3)
                end
            end
        end, 0.1)
    end
end

function DepressiveYasuo2:ExecuteBeybladeCombo()
    -- Safety timeout - reset if combo takes too long
    local timeSinceStart = Game.Timer() - self.beybladeTimer
    if timeSinceStart > 2.0 then -- 2 seconds timeout
        self:ResetBeyblade()
    end
    
    -- Check if target is still valid
    if not self.beybladeTarget or not self.beybladeTarget.valid or self.beybladeTarget.dead then
        self:ResetBeyblade()
    end
end

function DepressiveYasuo2:GetBestBeybladeTarget()
    local bestTarget = nil
    local bestScore = 0
    local maxRange = self.Menu.beyblade.maxRange:Value()
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if IsValidTarget(hero, maxRange) then
            local distance = GetDistance(myHero.pos, hero.pos)
            local healthPercent = hero.health / hero.maxHealth
            
            -- Score based on priority and health
            local score = 1000
            
            -- Prioritize low health targets
            if healthPercent < 0.5 then
                score = score + 500
            end
            
            -- Prioritize closer targets
            score = score + (maxRange - distance) / 10
            
            -- Prioritize ADC and Mid laners
            if self.Menu.ultimate.prioritizeADC:Value() then
                local charName = hero.charName:lower()
                if string.find(charName, "adc") or string.find(charName, "marksman") or 
                   string.find(charName, "jinx") or string.find(charName, "caitlyn") or 
                   string.find(charName, "ashe") or string.find(charName, "vayne") then
                    score = score + 300
                end
            end
            
            if score > bestScore then
                bestScore = score
                bestTarget = hero
            end
        end
    end
    
    return bestTarget
end

function DepressiveYasuo2:GetBestUnitForBeyblade(target)
    if not target or not target.valid then return nil end
    
    local bestUnit = nil
    local bestScore = 0
    local flashRange = self.Menu.beyblade.flashRange:Value()
    
    -- Check enemy champions first (excluding our target)
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and hero ~= target and not hero.dead and hero.visible and 
           not HasEBuff(hero) then
            local distanceToHero = GetDistance(myHero.pos, hero.pos)
            if distanceToHero <= SPELL_RANGE.E then
                local distanceFromHeroToTarget = GetDistance(hero.pos, target.pos)
                
                -- Target must be within flash range after E
                if distanceFromHeroToTarget <= flashRange then
                    if distanceFromHeroToTarget >= 200 and distanceFromHeroToTarget <= 1000 then
                        local optimalDistance = 600
                        local distancePenalty = math.abs(distanceFromHeroToTarget - optimalDistance)
                        local score = 3000 - distancePenalty
                        
                        -- Bonus for closer heroes
                        score = score + (SPELL_RANGE.E - distanceToHero) / 5
                        
                        if score > bestScore then
                            bestScore = score
                            bestUnit = hero
                        end
                    end
                end
            end
        end
    end
    
    -- Check minions and jungle monsters
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.alive and minion.visible and not HasEBuff(minion) then
            local isJungleMonster = minion.team == 300
            local isEnemyMinion = minion.isEnemy
            
            if isJungleMonster or isEnemyMinion then
                local distanceToMinion = GetDistance(myHero.pos, minion.pos)
                if distanceToMinion <= SPELL_RANGE.E then
                    local distanceFromMinionToTarget = GetDistance(minion.pos, target.pos)
                    
                    -- Target must be within flash range after E
                    if distanceFromMinionToTarget <= flashRange then
                        if distanceFromMinionToTarget >= 200 and distanceFromMinionToTarget <= 1000 then
                            local optimalDistance = 600
                            local distancePenalty = math.abs(distanceFromMinionToTarget - optimalDistance)
                            local baseScore = isJungleMonster and 2000 or 1000
                            local score = baseScore - distancePenalty
                            
                            -- Bonus for closer minions
                            score = score + (SPELL_RANGE.E - distanceToMinion) / 5
                            
                            -- Bonus for large monsters
                            if isJungleMonster and minion.maxHealth > 1000 then
                                score = score + 300
                            end
                            
                            if score > bestScore then
                                bestScore = score
                                bestUnit = minion
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestUnit
end

function DepressiveYasuo2:GetFlashSpell()
    local flash1 = myHero:GetSpellData(SUMMONER_1)
    local flash2 = myHero:GetSpellData(SUMMONER_2)
    
    if flash1 and flash1.name == "SummonerFlash" then
        return SUMMONER_1
    elseif flash2 and flash2.name == "SummonerFlash" then
        return SUMMONER_2
    end
    
    return nil
end

function DepressiveYasuo2:ResetBeyblade()
    self.beybladeState = "idle"
    self.beybladeTarget = nil
    self.beybladeStep = 0
    self.beybladeTimer = 0
end

-- Initialize the script
DepressiveYasuo2()
