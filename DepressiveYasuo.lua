local Heroes = {"Yasuo"}

-- Hero validation
if not table.contains(Heroes, myHero.charName) then return end

-- Load GG Prediction
require "GGPrediction"
local Prediction = _G.GGPrediction

local blockSpells = {
    "ahriqmissile", -- Ahri
    "ahriqreturnmissile",
    -- "ahriwdamagemissile", -- Ahri
    "ahriemissile", -- Ahri
}

-- Yasuo spell data for prediction
local YasuoSpells = {
    Q = {
        speed = 1500,
        delay = 0.4,
        radius = 50,
        range = 475,
        collision = false
    },
    Q3 = {
        speed = 1200,
        delay = 0.4,
        radius = 90,
        range = 1000,
        collision = false
    },
    E = {
        speed = math.huge, -- Instant dash
        delay = 0.1,
        radius = 50,
        range = 475,
        collision = false
    }
}

-- Prediction helper functions
local function GetQPrediction(target)
    if not target or not target.valid then return nil, 0 end
    
    -- Check if GGPrediction is loaded
    if not _G.GGPrediction then 
        return target.pos, 2 -- Return target position with LOW hit chance as fallback
    end
    
    local spellData = YasuoSpells.Q
    local prediction, castPosition, hitChance = _G.GGPrediction:GetPrediction(
        target,
        myHero.pos,
        spellData.speed,
        spellData.delay,
        spellData.radius
    )
    
    -- Ensure we return valid values - never return nil for hitChance
    if not prediction then
        return target.pos, 1 -- Return IMPOSSIBLE if no prediction
    end
    
    -- GGPrediction uses different hit chance values (0-4), map them to our system (1-6)
    local mappedHitChance = 1 -- Default to IMPOSSIBLE
    if hitChance == _G.GGPrediction.HITCHANCE_IMPOSSIBLE then
        mappedHitChance = 1
    elseif hitChance == _G.GGPrediction.HITCHANCE_COLLISION then
        mappedHitChance = 2
    elseif hitChance == _G.GGPrediction.HITCHANCE_NORMAL then
        mappedHitChance = 3
    elseif hitChance == _G.GGPrediction.HITCHANCE_HIGH then
        mappedHitChance = 4
    elseif hitChance == _G.GGPrediction.HITCHANCE_IMMOBILE then
        mappedHitChance = 5
    end
    
    return Vector(prediction.x, myHero.pos.y, prediction.z), math.max(1, mappedHitChance)
end

local function GetQ3Prediction(target)
    if not target or not target.valid then return nil, 0 end
    
    -- Check if GGPrediction is loaded
    if not _G.GGPrediction then 
        return target.pos, 2 -- Return target position with LOW hit chance as fallback
    end
    
    local spellData = YasuoSpells.Q3
    local prediction, castPosition, hitChance = _G.GGPrediction:GetPrediction(
        target,
        myHero.pos,
        spellData.speed,
        spellData.delay,
        spellData.radius
    )
    
    -- Ensure we return valid values - never return nil for hitChance
    if not prediction then
        return target.pos, 1 -- Return IMPOSSIBLE if no prediction
    end
    
    -- GGPrediction uses different hit chance values (0-4), map them to our system (1-6)
    local mappedHitChance = 1 -- Default to IMPOSSIBLE
    if hitChance == _G.GGPrediction.HITCHANCE_IMPOSSIBLE then
        mappedHitChance = 1
    elseif hitChance == _G.GGPrediction.HITCHANCE_COLLISION then
        mappedHitChance = 2
    elseif hitChance == _G.GGPrediction.HITCHANCE_NORMAL then
        mappedHitChance = 3
    elseif hitChance == _G.GGPrediction.HITCHANCE_HIGH then
        mappedHitChance = 4
    elseif hitChance == _G.GGPrediction.HITCHANCE_IMMOBILE then
        mappedHitChance = 5
    end
    
    return Vector(prediction.x, myHero.pos.y, prediction.z), math.max(1, mappedHitChance)
end

-- Check if Q3 (tornado) is ready - ESSENTIAL for E-Q3-Flash combo!
-- Q3 is the only Q variant that provides knockup, which is required for Flash follow-up
local function HasQ3()
    local spellData = myHero:GetSpellData(_Q)
    return spellData and spellData.name == "YasuoQ3Wrapper"
end

-- Utility functions
local function GetDistance(p1, p2)
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

local function GetQCooldown()
    local spellData = myHero:GetSpellData(_Q)
    return spellData and spellData.currentCd or 0
end

local function WillQBeReadyAfterE()
    local qCd = GetQCooldown()
    return qCd > 0 and qCd <= 0.5 -- E reduces Q CD by 1 second
end

local function CanKillMinion(minion, damage)
    return minion.health <= damage and minion.health > 0
end

local function GetQDamage()
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end
    local baseDamage = {20, 40, 60, 80, 100}
    local adRatio = 1.05
    local totalAD = myHero.totalDamage
    local damage = baseDamage[level] + (totalAD * adRatio)
    return damage
end

local function GetEDamage()
    local level = myHero:GetSpellData(_E).level
    if level == 0 then return 0 end
    local baseDamage = {60, 70, 80, 90, 100}
    local apRatio = 0.6
    local totalAP = myHero.ap
    local damage = baseDamage[level] + (totalAP * apRatio)
    return damage
end

-- Check if target has Yasuo's E buff (cannot dash to same target again)
local function HasEBuff(target)
    if not target or not target.valid then return true end -- Prevent dash if target invalid
    
    -- Safe check for buff count
    local buffCount = target.buffCount or 0
    if buffCount == 0 then return false end
    
    for i = 0, buffCount - 1 do
        local buff = target:GetBuff(i)
        if buff and buff.name then
            local buffName = buff.name
            -- Check for Yasuo's E buff (exact match)
            if buffName == "YasuoE" then
                return true
            end
        end
    end
    return false
end

-- Check if target is valid for abilities
local function IsValidTarget(target, range)
    if not target then return false end
    if target.dead or not target.visible or not target.isTargetable then return false end
    if range and GetDistance(myHero.pos, target.pos) > range then return false end
    return true
end

-- Check if position is under enemy turret
local function IsUnderEnemyTurret(position, safetyRange)
    safetyRange = safetyRange or 900 -- Default safety range
    for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i)
        if turret and turret.isEnemy and turret.alive and turret.visible then
            local distance = GetDistance(position, turret.pos)
            -- Use configurable safety range
            if distance <= safetyRange then
                return true
            end
        end
    end
    return false
end

-- Check if it's safe to E to target (turret check)
local function IsSafeToE(target, yasuoInstance)
    if not target then return false end
    
    -- If turret safety is disabled, always allow E
    if yasuoInstance and not yasuoInstance.Menu.turret.enabled:Value() then
        return true
    end
    
    local safetyRange = yasuoInstance and yasuoInstance.Menu.turret.safetyRange:Value() or 900
    local lowHealthThreshold = yasuoInstance and yasuoInstance.Menu.turret.lowHealthThreshold:Value() or 15
    local veryLowThreshold = yasuoInstance and yasuoInstance.Menu.turret.veryLowThreshold:Value() or 10
    
    -- Always allow E if target is very low
    local targetHealthPercent = target.maxHealth > 0 and (target.health / target.maxHealth * 100) or 100
    if targetHealthPercent <= lowHealthThreshold then
        return true
    end
    
    -- Check if we would be under enemy turret after E
    if IsUnderEnemyTurret(target.pos, safetyRange) then
        return false
    end
    
    -- Also check if we're currently under turret (extra safety)
    if IsUnderEnemyTurret(myHero.pos, safetyRange) then
        -- If we're already under turret, don't E unless target is very low
        if targetHealthPercent > veryLowThreshold then
            return false
        end
    end
    
    return true
end

-- Get valid enemy champions in range (for future combo implementation)
local function GetEnemyChampionsInRange(range)
    local enemies = {}
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and IsValidTarget(hero, range) and not HasEBuff(hero) then
            table.insert(enemies, hero)
        end
    end
    return enemies
end

-- Yasuo Class
class "Yasuo"

function Yasuo:__init()
    -- Walljump system
    self.walljumpSpots = {
        {pos = Vector(7236, 0, 5118), name = "Bot Wall Jump", id = 1},  -- First walljump
        {pos = Vector(7634, 0, 9850), name = "Top Wall Jump", id = 2}   -- Second walljump
    }
    self.selectedWalljumpSpot = nil
    self.walljumpSelectionActive = false
    
    -- Walljump sequences for each spot
    self.walljumpSequences = {
        [1] = { -- First walljump (Bot)
            selectPos = Vector(7180.00, 48.53, 5120.00),   -- Position to select
            firstEPos = Vector(6962.84, 51.15, 5375.40),   -- First E position  
            secondEPos = Vector(6810.99, 55.35, 5533.42)   -- Second E position after Q
        },
        [2] = { -- Second walljump (Top)
            selectPos = Vector(7626.35, 51.87, 9814.79),   -- Position to select
            firstEPos = Vector(7831.61, 52.22, 9625.00),   -- First E position
            secondEPos = Vector(7999.78, 52.35, 9472.98)   -- Second E position after Q
        }
    }
    
    -- Walljump execution control
    self.walljumpExecuting = false
    self.walljumpStep = 0
    self.currentSequence = nil
    self.autoMovingToSpot = false
    self.arrivalTime = 0
    
    -- Harass control
    self.harassState = "idle" -- idle, waiting_for_q
    self.harassTimer = 0
    
    -- Auto Windwall tracking
    self.lastWindwallTime = 0
    self.trackedMissiles = {}
    
    -- Combo Logic System
    self.comboLogicState = "idle" -- idle, executing_eq3flash
    self.comboLogicTimer = 0
    self.comboLogicTarget = nil
    self.eq3FlashStep = 0
    
    self:LoadMenu()
    
    -- Wait for GGPrediction to load
    DelayAction(function()
        if _G.GGPrediction then
            print("Yasuo: GGPrediction loaded successfully!")
        else
            print("Yasuo: Warning - GGPrediction not found! Using fallback prediction.")
        end
    end, 2.0)
    
    -- Callbacks
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function Yasuo:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "Yasuo", name = "Yasuo - Depressive"})
    
    -- Walljump System
    self.Menu:MenuElement({type = MENU, id = "walljump", name = "Walljump System"})
    self.Menu.walljump:MenuElement({id = "enabled", name = "Enable Walljump", value = true})
    self.Menu.walljump:MenuElement({id = "key", name = "Walljump Key", key = string.byte("Z"), toggle = false, value = false})
    self.Menu.walljump:MenuElement({id = "stopKey", name = "Stop Walljump Key", key = string.byte("I"), toggle = false, value = false})
    self.Menu.walljump:MenuElement({id = "selectionRange", name = "Selection Range", value = 300, min = 100, max = 500, step = 50})
    
    -- Clear System
    self.Menu:MenuElement({type = MENU, id = "clear", name = "Lane Clear"})
    self.Menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.clear:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.clear:MenuElement({id = "minMinions", name = "Min minions for E-Q combo", value = 2, min = 1, max = 5, step = 1})
    
    -- Harass System
    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useE", name = "Use E on minions", value = true})
    self.Menu.harass:MenuElement({id = "useQ", name = "Use Q after E", value = true})
    self.Menu.harass:MenuElement({id = "enemyRange", name = "Enemy range for Q", value = 475, min = 300, max = 600, step = 25})
    self.Menu.harass:MenuElement({id = "key", name = "Harass Key", key = string.byte("C"), toggle = false, value = false})
    
    -- Combo System
    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.combo:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.combo:MenuElement({id = "useR", name = "Use R (Ultimate)", value = true})
    self.Menu.combo:MenuElement({id = "gapClose", name = "Use E for gap closing", value = true})
    self.Menu.combo:MenuElement({id = "executeThreshold", name = "Execute combo at enemy HP %", value = 50, min = 20, max = 80, step = 5})
    self.Menu.combo:MenuElement({id = "executeCombo", name = "Use E-Q → R execute combo", value = true})
    self.Menu.combo:MenuElement({id = "advancedCombo", name = "Use advanced E-Q when target airborne", value = true})
    self.Menu.combo:MenuElement({id = "minAttackSpeed", name = "Min Attack Speed for advanced combo", value = 1.33, min = 1.0, max = 2.5, step = 0.1})
    
    -- 1v1 System
    self.Menu:MenuElement({type = MENU, id = "onevsone", name = "1v1 Mode"})
    self.Menu.onevsone:MenuElement({id = "enabled", name = "Enable 1v1 Mode", value = true})
    self.Menu.onevsone:MenuElement({id = "ultThreshold", name = "Use R when enemy HP % ≤", value = 30, min = 10, max = 50, step = 5})
    self.Menu.onevsone:MenuElement({id = "forceUlt", name = "Force R when very low HP (≤15%)", value = true})
    self.Menu.onevsone:MenuElement({id = "aggressive", name = "Aggressive 1v1 Mode (more combos when low HP)", value = true})
    
    -- Prediction Settings
    self.Menu:MenuElement({type = MENU, id = "prediction", name = "Prediction"})
    self.Menu.prediction:MenuElement({id = "hitChance", name = "Min Hit Chance", value = 3, min = 1, max = 6, step = 1})
    self.Menu.prediction:MenuElement({id = "useQ3Pred", name = "Use Prediction for Q3 (Tornado)", value = true})
    self.Menu.prediction:MenuElement({id = "useQPred", name = "Use Prediction for Q", value = true})
    
    -- LastHit System  
    self.Menu:MenuElement({type = MENU, id = "lasthit", name = "Last Hit"})
    self.Menu.lasthit:MenuElement({id = "useQ", name = "Use Q for LastHit", value = true})
    self.Menu.lasthit:MenuElement({id = "useE", name = "Use E for LastHit", value = false})
    self.Menu.lasthit:MenuElement({id = "key", name = "LastHit Key", key = string.byte("X"), toggle = false, value = false})
    
    -- Drawing
    self.Menu:MenuElement({type = MENU, id = "drawing", name = "Drawing"})
    self.Menu.drawing:MenuElement({id = "spots", name = "Draw Walljump Spots", value = true})
    self.Menu.drawing:MenuElement({id = "range", name = "Draw Selection Range", value = true})
    
    -- Turret Safety System
    self.Menu:MenuElement({type = MENU, id = "turret", name = "Turret Safety"})
    self.Menu.turret:MenuElement({id = "enabled", name = "Enable Turret Safety", value = true})
    self.Menu.turret:MenuElement({id = "safetyRange", name = "Turret Safety Range", value = 900, min = 800, max = 1000, step = 25})
    self.Menu.turret:MenuElement({id = "lowHealthThreshold", name = "Allow E under turret when enemy HP % ≤", value = 15, min = 5, max = 30, step = 5})
    self.Menu.turret:MenuElement({id = "veryLowThreshold", name = "Allow E when we're under turret if enemy HP % ≤", value = 10, min = 5, max = 20, step = 5})
    
    -- Auto Windwall System
    self.Menu:MenuElement({type = MENU, id = "windwall", name = "Auto Windwall"})
    self.Menu.windwall:MenuElement({id = "enabled", name = "Enable Auto Windwall", value = true})
    self.Menu.windwall:MenuElement({id = "range", name = "Detection Range", value = 1000, min = 500, max = 1500, step = 100})
    self.Menu.windwall:MenuElement({id = "reactionTime", name = "Reaction Time (ms)", value = 200, min = 50, max = 500, step = 50})
    
    -- Combo Logic System
    self.Menu:MenuElement({type = MENU, id = "comboLogic", name = "Combo Logic System"})
    self.Menu.comboLogic:MenuElement({id = "enabled", name = "Enable Combo Logic", value = true})
    self.Menu.comboLogic:MenuElement({id = "eq3flash", name = "E-Q3-Flash Combo", key = string.byte("N"), toggle = false, value = false})
    self.Menu.comboLogic:MenuElement({id = "eq3flashRange", name = "E-Q3-Flash Max Range", value = 900, min = 600, max = 1200, step = 50})
    self.Menu.comboLogic:MenuElement({id = "flashRange", name = "Flash Range", value = 450, min = 350, max = 450, step = 25})
    self.Menu.comboLogic:MenuElement({id = "flashAfterQ3", name = "Auto Flash after Q3 hit", value = true})
    self.Menu.comboLogic:MenuElement({id = "requireQ3Ready", name = "Only use when Q3 is ready", value = true})
end

function Yasuo:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    -- Auto Windwall check
    if self.Menu.windwall.enabled:Value() then
        self:CheckAutoWindwall()
    end
    
    -- Combo Logic System - Handle E-Q3-Flash combo
    if self.Menu.comboLogic.enabled:Value() and self.Menu.comboLogic.eq3flash:Value() then
        if self.comboLogicState == "idle" then
            self:HandleEQ3FlashCombo()
        end
    end
    
    -- Execute ongoing combo logic
    if self.comboLogicState ~= "idle" then
        self:ExecuteComboLogic()
    end
    
    -- Stop Walljump Key - PRIORITY CHECK (antes que todo)
    if self.Menu.walljump.enabled:Value() and self.Menu.walljump.stopKey:Value() then
        self:ForceStopWalljump()
        return -- Exit immediately to prevent any other walljump actions
    end
    
    -- Handle walljump system
    if self.Menu.walljump.enabled:Value() and self.Menu.walljump.key:Value() then
        self:HandleWalljump()
    end
    
    -- Auto-execute walljump sequence if it's in progress
    if self.walljumpExecuting then
        self:ExecuteWalljumpSequence()
    end
    
    -- Auto-execute walljump if character is close enough to selected spot
    if self.selectedWalljumpSpot and not self.walljumpExecuting then
        local distanceToSpot = GetDistance(myHero.pos, self.selectedWalljumpSpot.pos)
        if distanceToSpot <= 45 then
            -- Just arrived, start waiting period
            if self.arrivalTime == 0 then
                self.arrivalTime = GetTickCount()
                self.autoMovingToSpot = false
            -- Wait 500ms before executing
            elseif GetTickCount() - self.arrivalTime >= 500 then
                self.walljumpExecuting = true
                self.walljumpStep = 1
            end
        elseif self.autoMovingToSpot and distanceToSpot > 150 then
            -- Continue moving to spot if we're still far away (only if not stopped)
            if self.selectedWalljumpSpot then -- Double check spot still exists
                Control.Move(self.selectedWalljumpSpot.pos)
                self.arrivalTime = 0 -- Reset arrival time while moving
            end
        end
    end
    
    -- Handle orbwalker modes
    if _G.SDK and _G.SDK.Orbwalker then
        if _G.SDK.Orbwalker.Modes[0] then -- Combo
            self:Combo()
        elseif _G.SDK.Orbwalker.Modes[1] then -- Harass
            self:Harass()
        elseif _G.SDK.Orbwalker.Modes[2] then -- Lane Clear
            self:Clear()
        elseif _G.SDK.Orbwalker.Modes[3] then -- Last Hit
            self:LastHit()
        end
    end
    
    -- Manual LastHit with X key
    if self.Menu.lasthit.key:Value() then
        self:LastHit()
    end
    
    -- Manual Harass with C key
    if self.Menu.harass.key:Value() then
        self:Harass()
    end
end

function Yasuo:Draw()
    if myHero.dead then return end
    
    -- Draw walljump spots
    if self.Menu.drawing.spots:Value() then
        for i, spot in pairs(self.walljumpSpots) do
            local screenPos = spot.pos:ToScreen()
            if screenPos.onScreen then
                local color = (self.selectedWalljumpSpot == spot) and Draw.Color(255, 0, 255, 0) or Draw.Color(120, 255, 255, 255)
                Draw.Circle(spot.pos, 80, color)
                Draw.Text(spot.name, 12, screenPos.x - 50, screenPos.y - 30, color)
            end
        end
        
        -- Draw selection range around mouse
        if self.Menu.drawing.range:Value() then
            local mousePos = Game.mousePos()
            Draw.Circle(mousePos, self.Menu.walljump.selectionRange:Value(), Draw.Color(60, 255, 255, 0))
        end
    end
    
    -- Draw walljump status
    if self.walljumpExecuting then
        Draw.Text("EXECUTING WALLJUMP - STEP: " .. self.walljumpStep, 16, 100, 100, Draw.Color(255, 255, 0, 0))
        Draw.Text("Press I to STOP walljump", 12, 100, 120, Draw.Color(255, 255, 100, 100))
    elseif self.selectedWalljumpSpot then
        local distanceToSpot = GetDistance(myHero.pos, self.selectedWalljumpSpot.pos)
        local statusText = "WALLJUMP SELECTED: " .. self.selectedWalljumpSpot.name .. " (Distance: " .. math.floor(distanceToSpot) .. "/40)"
        local color = distanceToSpot <= 40 and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 255, 0)
        Draw.Text(statusText, 14, 100, 120, color)
        Draw.Text("Press I to CANCEL", 12, 100, 140, Draw.Color(255, 255, 100, 100))
        
        if distanceToSpot <= 40 then
            if self.arrivalTime > 0 then
                local waitTime = math.max(0, 500 - (GetTickCount() - self.arrivalTime))
                Draw.Text("WAITING: " .. math.ceil(waitTime / 100) / 10 .. "s", 16, 100, 160, Draw.Color(255, 255, 255, 0))
            else
                Draw.Text("READY TO EXECUTE!", 16, 100, 160, Draw.Color(255, 0, 255, 0))
            end
        elseif self.autoMovingToSpot then
            Draw.Text("Moving to spot...", 14, 100, 160, Draw.Color(255, 255, 255, 0))
        else
            Draw.Text("Move closer to execute", 14, 100, 160, Draw.Color(255, 255, 255, 0))
        end
    end
    
    -- Draw combo logic status
    if self.comboLogicState ~= "idle" then
        local yOffset = self.walljumpExecuting or self.selectedWalljumpSpot and 200 or 100
        
        if self.comboLogicState == "executing_eq3flash" then
            local stepText = ""
            if self.eq3FlashStep == 1 then
                stepText = "E to unit"
            elseif self.eq3FlashStep == 2 then
                stepText = "Waiting for Q3"
            elseif self.eq3FlashStep == 3 then
                stepText = "Preparing Flash"
            end
            
            Draw.Text("E-Q3-FLASH COMBO: " .. stepText, 16, 100, yOffset, Draw.Color(255, 255, 215, 0))
            
            if self.comboLogicTarget and self.comboLogicTarget.valid then
                local targetName = self.comboLogicTarget.charName or "Unknown"
                Draw.Text("Target: " .. targetName, 12, 100, yOffset + 20, Draw.Color(255, 255, 100, 100))
                -- Draw line to target
                Draw.Line(myHero.pos:ToScreen(), self.comboLogicTarget.pos:ToScreen(), 2, Draw.Color(255, 255, 0, 0))
            end
            
            -- Draw timer
            local elapsed = (GetTickCount() - self.comboLogicTimer) / 1000
            Draw.Text(string.format("Time: %.1fs", elapsed), 12, 100, yOffset + 40, Draw.Color(255, 200, 200, 200))
        end
    end
    
    -- Draw combo logic instructions
    if self.Menu.comboLogic.enabled:Value() and self.comboLogicState == "idle" then
        local yOffset = self.walljumpExecuting or self.selectedWalljumpSpot and 240 or 140
        
        -- Check if combo is ready
        local hasQ3 = HasQ3()
        local flashSpell = myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" and SUMMONER_1 or 
                          (myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" and SUMMONER_2 or nil)
        local hasFlash = flashSpell and Ready(flashSpell)
        
        if hasQ3 and hasFlash then
            Draw.Text("E-Q3-Flash READY - Press N", 14, 100, yOffset, Draw.Color(255, 0, 255, 0))
            
            -- Show potential target and unit to E
            local target = self:GetBestEQ3FlashTarget()
            if target then
                local bestUnit = self:GetBestUnitForEQ3Flash(target)
                local targetName = target.charName or "Unknown"
                Draw.Text("Target: " .. targetName, 12, 100, yOffset + 20, Draw.Color(255, 180, 180, 180))
                
                if bestUnit then
                    local unitType = "Unknown"
                    local unitName = "Unknown"
                    
                    if bestUnit.charName then
                        unitType = "Champion"
                        unitName = bestUnit.charName
                    elseif bestUnit.team == 300 then
                        unitType = "Monster"
                        unitName = "Jungle Monster"
                    else
                        unitType = "Minion" 
                        unitName = "Lane Minion"
                    end
                    
                    Draw.Text("E unit: " .. unitName .. " (" .. unitType .. ")", 12, 100, yOffset + 40, Draw.Color(255, 180, 180, 180))
                    
                    -- Show distance info with Flash range check
                    local distanceToUnit = GetDistance(myHero.pos, bestUnit.pos)
                    local distanceUnitToTarget = GetDistance(bestUnit.pos, target.pos)
                    local flashRange = self.Menu.comboLogic.flashRange:Value()
                    local flashRangeOK = distanceUnitToTarget <= flashRange
                    local flashRangeColor = flashRangeOK and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 100, 0)
                    
                    Draw.Text(string.format("Distances: Me->Unit=%.0f, Unit->Target=%.0f", distanceToUnit, distanceUnitToTarget), 
                             10, 100, yOffset + 60, Draw.Color(255, 150, 150, 150))
                    Draw.Text(string.format("Flash Range: %.0f/%.0f %s", distanceUnitToTarget, flashRange, flashRangeOK and "✓" or "✗"), 
                             10, 100, yOffset + 80, flashRangeColor)
                    
                    -- Draw visual indicators
                    Draw.Circle(target.pos, 80, Draw.Color(150, 255, 0, 0)) -- Target in red
                    Draw.Circle(bestUnit.pos, 60, Draw.Color(150, 0, 255, 0)) -- E unit in green
                    Draw.Line(myHero.pos:ToScreen(), bestUnit.pos:ToScreen(), 2, Draw.Color(150, 0, 255, 0))
                    Draw.Line(bestUnit.pos:ToScreen(), target.pos:ToScreen(), 2, Draw.Color(150, 255, 255, 0))
                else
                    Draw.Text("No valid E unit found", 12, 100, yOffset + 40, Draw.Color(255, 255, 100, 0))
                    
                    -- Show debugging info for why no unit found
                    local nearbyUnitsCount = 0
                    local unitsInFlashRange = 0
                    local flashRange = self.Menu.comboLogic.flashRange:Value()
                    
                    for i = 1, Game.HeroCount() do
                        local hero = Game.Hero(i)
                        if hero and hero.isEnemy and hero ~= target and not hero.dead and hero.visible then
                            local distance = GetDistance(myHero.pos, hero.pos)
                            if distance <= 475 then
                                nearbyUnitsCount = nearbyUnitsCount + 1
                                local distanceToTarget = GetDistance(hero.pos, target.pos)
                                if distanceToTarget <= flashRange then
                                    unitsInFlashRange = unitsInFlashRange + 1
                                end
                            end
                        end
                    end
                    
                    for i = 1, Game.MinionCount() do
                        local unit = Game.Minion(i)
                        if unit and ((unit.isEnemy and unit.alive) or unit.team == 300) and unit.visible then
                            local distance = GetDistance(myHero.pos, unit.pos)
                            if distance <= 475 then
                                nearbyUnitsCount = nearbyUnitsCount + 1
                                local distanceToTarget = GetDistance(unit.pos, target.pos)
                                if distanceToTarget <= flashRange then
                                    unitsInFlashRange = unitsInFlashRange + 1
                                end
                            end
                        end
                    end
                    
                    Draw.Text(string.format("Units in E range: %d", nearbyUnitsCount), 10, 100, yOffset + 60, Draw.Color(255, 200, 100, 100))
                    Draw.Text(string.format("Units in Flash range: %d", unitsInFlashRange), 10, 100, yOffset + 80, Draw.Color(255, 200, 100, 100))
                end
            else
                Draw.Text("No valid target found", 12, 100, yOffset + 20, Draw.Color(255, 255, 100, 0))
            end
        elseif not hasQ3 and self.Menu.comboLogic.requireQ3Ready:Value() then
            Draw.Text("E-Q3-Flash: Need Q3 (Tornado)", 12, 100, yOffset, Draw.Color(255, 255, 100, 0))
        elseif not hasFlash then
            Draw.Text("E-Q3-Flash: Flash not ready", 12, 100, yOffset, Draw.Color(255, 255, 100, 0))
        else
            Draw.Text("E-Q3-Flash available - Press N", 12, 100, yOffset, Draw.Color(255, 255, 255, 0))
        end
    end
end

function Yasuo:HandleWalljump()
    if not self.walljumpExecuting then
        self:SelectWalljumpSpot()
    end
end

function Yasuo:SelectWalljumpSpot()
    local mousePos = Game.mousePos()
    local closestSpot = nil
    local closestDistance = math.huge
    
    for i, spot in pairs(self.walljumpSpots) do
        local distance = GetDistance(mousePos, spot.pos)
        if distance <= self.Menu.walljump.selectionRange:Value() and distance < closestDistance then
            closestDistance = distance
            closestSpot = spot
        end
    end
    
    if closestSpot then
        self.selectedWalljumpSpot = closestSpot
        self.currentSequence = self.walljumpSequences[closestSpot.id]
        
        -- Check if character is close enough to execute walljump immediately
        local distanceToSpot = GetDistance(myHero.pos, closestSpot.pos)
        if distanceToSpot <= 45 then
            -- Start waiting period immediately if already close
            self.arrivalTime = GetTickCount()
            self.autoMovingToSpot = false
        else
            -- Auto-move to the selected spot
            self.autoMovingToSpot = true
            self.arrivalTime = 0
            Control.Move(closestSpot.pos)
        end
    end
end

function Yasuo:ExecuteWalljumpSequence()
    if not self.currentSequence then return end
    
    -- Safety check - if walljump was stopped, don't continue
    if not self.walljumpExecuting or self.walljumpStep == 0 then return end
    
    if self.walljumpStep == 1 then
        -- Cast first E immediately
        if Ready(_E) then
            Control.CastSpell(HK_E, self.currentSequence.firstEPos)
            self.walljumpStep = 2
            
            -- Cast Q immediately after E with a small delay to ensure dash starts
            DelayAction(function()
                -- Double check walljump is still active before executing
                if self.walljumpExecuting and Ready(_Q) then
                    Control.CastSpell(HK_Q, self.currentSequence.secondEPos)
                    self.walljumpStep = 3
                end
            end, 0.1)
        end
        
    elseif self.walljumpStep == 3 then
        -- Wait for dash to complete, then cast second E
        if not myHero.pathing.isDashing and Ready(_E) then
            DelayAction(function()
                -- Double check walljump is still active before executing
                if self.walljumpExecuting and Ready(_E) then
                    Control.CastSpell(HK_E, self.currentSequence.secondEPos)
                    self:ResetWalljump()
                end
            end, 0.3)
            self.walljumpStep = 4 -- Prevent multiple executions
        end
    end
end

function Yasuo:ResetWalljump()
    self.walljumpExecuting = false
    self.walljumpStep = 0
    self.selectedWalljumpSpot = nil
    self.currentSequence = nil
    self.autoMovingToSpot = false
    self.arrivalTime = 0
end

function Yasuo:ForceStopWalljump()
    -- Reset all walljump states
    self:ResetWalljump()
    
    -- Force stop any movement commands
    Control.Move(myHero.pos) -- Stop current movement by moving to current position
    
    -- Clear any pending DelayActions by setting a flag or resetting critical states
    self.walljumpStep = 0
    self.walljumpExecuting = false
    
    -- Optional: Print confirmation (can be removed later)
    -- print("Walljump STOPPED by user")
end

-- Orbwalker functions (basic implementations)
function Yasuo:Combo()
    -- Advanced combo with prediction
    local target = self:GetBestComboTarget()
    if not target then return end
    
    local distanceToTarget = GetDistance(myHero.pos, target.pos)
    local minHitChance = self.Menu.prediction.hitChance:Value()
    
    -- Calculate target health percentage
    local targetHealthPercent = target.maxHealth > 0 and (target.health / target.maxHealth * 100) or 100
    
    -- AGGRESSIVE E-Q COMBO: Prioritize E-Q when both are available
    if self.Menu.combo.useE:Value() and self.Menu.combo.useQ:Value() and Ready(_E) and Ready(_Q) then
        -- Try to E directly on the target first
        if distanceToTarget <= 475 and not HasEBuff(target) and IsSafeToE(target, self) then
            Control.CastSpell(HK_E, target)
            -- Schedule Q after E dash completes
            DelayAction(function()
                if Ready(_Q) then
                    if HasQ3() then
                        -- Use Q3 with prediction
                        if self.Menu.prediction.useQ3Pred:Value() then
                            local prediction, hitChance = GetQ3Prediction(target)
                            if prediction and hitChance >= minHitChance then
                                local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                                Control.CastSpell(HK_Q, predPos)
                            else
                                Control.CastSpell(HK_Q, target.pos)
                            end
                        else
                            Control.CastSpell(HK_Q, target.pos)
                        end
                    else
                        -- Use regular Q with prediction
                        if self.Menu.prediction.useQPred:Value() then
                            local prediction, hitChance = GetQPrediction(target)
                            if prediction and hitChance >= minHitChance then
                                local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                                Control.CastSpell(HK_Q, predPos)
                            else
                                Control.CastSpell(HK_Q, target.pos)
                            end
                        else
                            Control.CastSpell(HK_Q, target.pos)
                        end
                    end
                end
            end, 0.3) -- Wait for E dash to complete
            return
        end
        
        -- If can't E directly on target, try E on a minion close to the target for aggressive positioning
        if distanceToTarget > 475 then
            local minion = self:GetMinionForGapClose(target)
            if minion and GetDistance(minion.pos, target.pos) <= 400 and IsSafeToE(minion, self) then -- Minion very close to target
                Control.CastSpell(HK_E, minion)
                -- Schedule Q after E dash completes
                DelayAction(function()
                    if Ready(_Q) then
                        local newDistanceToTarget = GetDistance(myHero.pos, target.pos)
                        if newDistanceToTarget <= (HasQ3() and 1000 or 475) then
                            if HasQ3() then
                                -- Use Q3 with prediction
                                if self.Menu.prediction.useQ3Pred:Value() then
                                    local prediction, hitChance = GetQ3Prediction(target)
                                    if prediction and hitChance >= minHitChance then
                                        local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                                        Control.CastSpell(HK_Q, predPos)
                                    else
                                        Control.CastSpell(HK_Q, target.pos)
                                    end
                                else
                                    Control.CastSpell(HK_Q, target.pos)
                                end
                            else
                                -- Use regular Q with prediction
                                if self.Menu.prediction.useQPred:Value() then
                                    local prediction, hitChance = GetQPrediction(target)
                                    if prediction and hitChance >= minHitChance then
                                        local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                                        Control.CastSpell(HK_Q, predPos)
                                    else
                                        Control.CastSpell(HK_Q, target.pos)
                                    end
                                else
                                    Control.CastSpell(HK_Q, target.pos)
                                end
                            end
                        end
                    end
                end, 0.3) -- Wait for E dash to complete
                return
            end
        end
    end
    
    -- INDEPENDENT Q USAGE: Use Q with prediction regardless of E status
    if self.Menu.combo.useQ:Value() and Ready(_Q) and distanceToTarget <= (HasQ3() and 1000 or 475) then
        if HasQ3() then
            -- Q3 (Tornado) with prediction
            if self.Menu.prediction.useQ3Pred:Value() then
                local prediction, hitChance = GetQ3Prediction(target)
                if prediction and hitChance >= minHitChance then
                    local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                    Control.CastSpell(HK_Q, predPos)
                    return
                else
                    -- Use fallback if prediction is not good enough
                    Control.CastSpell(HK_Q, target.pos)
                    return
                end
            else
                -- Fallback to direct cast for Q3
                Control.CastSpell(HK_Q, target.pos)
                return
            end
        else
            -- Regular Q with prediction
            if self.Menu.prediction.useQPred:Value() then
                local prediction, hitChance = GetQPrediction(target)
                if prediction and hitChance >= minHitChance then
                    local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                    Control.CastSpell(HK_Q, predPos)
                    return
                else
                    -- Use fallback if prediction is not good enough
                    Control.CastSpell(HK_Q, target.pos)
                    return
                end
            else
                -- Fallback to direct cast for regular Q
                Control.CastSpell(HK_Q, target.pos)
                return
            end
        end
    end
    
    -- 1v1 MODE: Aggressive R usage when enemy is low HP (30% or less by default)
    if self.Menu.onevsone.enabled:Value() and self:IsOneVsOneSituation(target) then
        local oneVsOneThreshold = self.Menu.onevsone.ultThreshold:Value()
        
        -- PRIORITY 1: Use R immediately if enemy HP is at or below threshold and R is ready
        if targetHealthPercent <= oneVsOneThreshold and Ready(_R) and distanceToTarget <= 1400 then
            -- First try: If enemy is already airborne, use R immediately
            if self:CanUseUltimate(target) then
                Control.CastSpell(HK_R)
                return
            end
            
            -- Second try: If enemy is not airborne but we have Q3, create knockup then R
            if HasQ3() and Ready(_Q) and distanceToTarget <= 1000 then
                -- Use Q3 to knockup, then R
                if self.Menu.prediction.useQ3Pred:Value() then
                    local prediction, hitChance = GetQ3Prediction(target)
                    if prediction and hitChance >= minHitChance then
                        local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                        Control.CastSpell(HK_Q, predPos)
                    else
                        Control.CastSpell(HK_Q, target.pos)
                    end
                else
                    Control.CastSpell(HK_Q, target.pos)
                end
                
                -- Schedule R after Q3 knockup with proper airborne check
                DelayAction(function()
                    if Ready(_R) and distanceToTarget <= 1400 and self:CanUseUltimate(target) then
                        Control.CastSpell(HK_R)
                    end
                end, 0.4) -- Wait for Q3 to hit and create knockup
                return
            end
            
            -- Third try: If no Q3 but have E, try to get Q3 ready
            if Ready(_E) and not HasQ3() and distanceToTarget <= 475 and not HasEBuff(target) and IsSafeToE(target, self) then
                Control.CastSpell(HK_E, target)
                
                -- After E, Q should be ready or closer to ready
                DelayAction(function()
                    if Ready(_Q) then
                        if HasQ3() then
                            -- Now we have Q3, use it and follow with R
                            if self.Menu.prediction.useQ3Pred:Value() then
                                local prediction, hitChance = GetQ3Prediction(target)
                                if prediction and hitChance >= minHitChance then
                                    local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                                    Control.CastSpell(HK_Q, predPos)
                                else
                                    Control.CastSpell(HK_Q, target.pos)
                                end
                            else
                                Control.CastSpell(HK_Q, target.pos)
                            end
                            
                            -- Schedule R after Q3 knockup with airborne check
                            DelayAction(function()
                                if Ready(_R) and self:CanUseUltimate(target) then
                                    Control.CastSpell(HK_R)
                                end
                            end, 0.4)
                        else
                            -- Still regular Q, just use it to build up to Q3
                            Control.CastSpell(HK_Q, target.pos)
                        end
                    end
                end, 0.3) -- Wait for E dash to complete
                return
            end
            
            -- Fourth try: Force R if enemy is very low and option is enabled, BUT ONLY if airborne
            if self.Menu.onevsone.forceUlt:Value() and targetHealthPercent <= 15 and distanceToTarget <= 1400 and self:CanUseUltimate(target) then
                Control.CastSpell(HK_R)
                return
            end
        end
    end
    
    -- COMBO EXECUTION: E-Q → R when target is at threshold health or less
    if self.Menu.combo.executeCombo:Value() and self.Menu.combo.useR:Value() and Ready(_R) and 
       targetHealthPercent <= self.Menu.combo.executeThreshold:Value() and distanceToTarget <= 1400 then
        
        -- Check if we have Q3 (tornado) ready for knockup
        if HasQ3() and self.Menu.combo.useQ:Value() and Ready(_Q) then
            -- Try to E-Q combo first to create knockup
            if self.Menu.combo.useE:Value() and Ready(_E) then
                -- Prioritize E on target if possible
                if distanceToTarget <= 475 and not HasEBuff(target) and IsSafeToE(target, self) then
                    Control.CastSpell(HK_E, target)
                    -- Schedule Q3 after E dash completes
                    DelayAction(function()
                        if Ready(_Q) and HasQ3() then
                            if self.Menu.prediction.useQ3Pred:Value() then
                                local prediction, hitChance = GetQ3Prediction(target)
                                if prediction and hitChance >= minHitChance then
                                    local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                                    Control.CastSpell(HK_Q, predPos)
                                else
                                    Control.CastSpell(HK_Q, target.pos)
                                end
                            else
                                Control.CastSpell(HK_Q, target.pos)
                            end
                            -- Schedule R after Q3 knockup
                            DelayAction(function()
                                if Ready(_R) and self:CanUseUltimate(target) then
                                    Control.CastSpell(HK_R)
                                end
                            end, 0.3) -- Wait for Q3 to hit and create knockup
                        end
                    end, 0.4) -- Wait for E dash to complete
                    return
                end
                -- If can't E directly to target, try E on minion near target
                local minion = self:GetMinionForGapClose(target)
                if minion and GetDistance(minion.pos, target.pos) <= 600 and IsSafeToE(minion, self) then -- Minion close to target
                    Control.CastSpell(HK_E, minion)
                    -- Schedule Q3 after E dash completes
                    DelayAction(function()
                        if Ready(_Q) and HasQ3() then
                            if self.Menu.prediction.useQ3Pred:Value() then
                                local prediction, hitChance = GetQ3Prediction(target)
                                if prediction and hitChance >= minHitChance then
                                    local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                                    Control.CastSpell(HK_Q, predPos)
                                else
                                    Control.CastSpell(HK_Q, target.pos)
                                end
                            else
                                Control.CastSpell(HK_Q, target.pos)
                            end
                            -- Schedule R after Q3 knockup
                            DelayAction(function()
                                if Ready(_R) and self:CanUseUltimate(target) then
                                    Control.CastSpell(HK_R)
                                end
                            end, 0.3) -- Wait for Q3 to hit and create knockup
                        end
                    end, 0.4) -- Wait for E dash to complete
                    return
                end
            end
            -- If no E available but Q3 ready, use Q3 directly and follow with R
            if distanceToTarget <= 1000 then
                if self.Menu.prediction.useQ3Pred:Value() then
                    local prediction, hitChance = GetQ3Prediction(target)
                    if prediction and hitChance >= minHitChance then
                        local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                        Control.CastSpell(HK_Q, predPos)
                        -- Schedule R after Q3 knockup
                        DelayAction(function()
                            if Ready(_R) and self:CanUseUltimate(target) then
                                Control.CastSpell(HK_R)
                            end
                        end, 0.5) -- Wait for Q3 to travel and hit
                        return
                    end
                else
                    Control.CastSpell(HK_Q, target.pos)
                    -- Schedule R after Q3 knockup
                    DelayAction(function()
                        if Ready(_R) and self:CanUseUltimate(target) then
                            Control.CastSpell(HK_R)
                        end
                    end, 0.5) -- Wait for Q3 to travel and hit
                    return
                end
            end
        end
    end
    -- ADVANCED COMBO: If target is already airborne and we have high attack speed (1.33+)
    if self.Menu.combo.advancedCombo:Value() and self.Menu.combo.useR:Value() and Ready(_R) and distanceToTarget <= 1400 and 
       self:CanUseUltimate(target) and myHero.attackSpeed >= self.Menu.combo.minAttackSpeed:Value() then
        
        -- Target is airborne, look for another target to E-Q before using R
        if HasQ3() and self.Menu.combo.useQ:Value() and Ready(_Q) and self.Menu.combo.useE:Value() and Ready(_E) then
            -- Look for another enemy champion to E-Q
            local secondaryTarget = self:GetSecondaryTarget(target, 900) -- Look within 900 range
            if secondaryTarget and not HasEBuff(secondaryTarget) and IsSafeToE(secondaryTarget, self) then
                local distanceToSecondary = GetDistance(myHero.pos, secondaryTarget.pos)
                if distanceToSecondary <= 475 then
                    Control.CastSpell(HK_E, secondaryTarget)
                    -- Schedule Q3 after E dash completes
                    DelayAction(function()
                        if Ready(_Q) and HasQ3() then
                            if self.Menu.prediction.useQ3Pred:Value() then
                                local prediction, hitChance = GetQ3Prediction(secondaryTarget)
                                if prediction and hitChance >= minHitChance then
                                    local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                                    Control.CastSpell(HK_Q, predPos)
                                else
                                    Control.CastSpell(HK_Q, secondaryTarget.pos)
                                end
                            else
                                Control.CastSpell(HK_Q, secondaryTarget.pos)
                            end
                            -- Schedule R on original target if still airborne
                            DelayAction(function()
                                if Ready(_R) and self:CanUseUltimate(target) then
                                    Control.CastSpell(HK_R)
                                end
                            end, 0.2) -- Shorter delay since target is already airborne
                        end
                    end, 0.3) -- Wait for E dash to complete
                    return
                end
            end
            -- If no secondary champion, look for minion near airborne target
            local nearbyMinion = self:GetMinionNearTarget(target, 600)
            if nearbyMinion and not HasEBuff(nearbyMinion) and IsSafeToE(nearbyMinion, self) then
                local distanceToMinion = GetDistance(myHero.pos, nearbyMinion.pos)
                if distanceToMinion <= 475 then
                    Control.CastSpell(HK_E, nearbyMinion)
                    -- Schedule Q3 after E dash completes
                    DelayAction(function()
                        if Ready(_Q) and HasQ3() then
                            -- Q3 towards original airborne target area
                            if self.Menu.prediction.useQ3Pred:Value() then
                                local prediction, hitChance = GetQ3Prediction(target)
                                if prediction and hitChance >= minHitChance then
                                    local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                                    Control.CastSpell(HK_Q, predPos)
                                else
                                    Control.CastSpell(HK_Q, target.pos)
                                end
                            else
                                Control.CastSpell(HK_Q, target.pos)
                            end
                            -- Schedule R on original target if still airborne
                            DelayAction(function()
                                if Ready(_R) and self:CanUseUltimate(target) then
                                    Control.CastSpell(HK_R)
                                end
                            end, 0.2) -- Shorter delay since target is already airborne
                        end
                    end, 0.3) -- Wait for E dash to complete
                    return
                end
            end
        end
    end
    -- R (Ultimate) logic - if enemy is already knocked up
    if self.Menu.combo.useR:Value() and Ready(_R) and distanceToTarget <= 1400 then
        if self:CanUseUltimate(target) then
            Control.CastSpell(HK_R)
            return
        end
    end
    
    -- Q3 (Tornado) with prediction for knockup
    if self.Menu.combo.useQ:Value() and Ready(_Q) and HasQ3() and distanceToTarget <= 1000 then
        if self.Menu.prediction.useQ3Pred:Value() then
            local prediction, hitChance = GetQ3Prediction(target)
            if prediction and hitChance >= minHitChance then
                local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                Control.CastSpell(HK_Q, predPos)
                return
            end
        else
            -- Fallback to direct cast
            Control.CastSpell(HK_Q, target.pos)
            return
        end
    end
    
    -- E to gap close (prioritize target if no E buff)
    if self.Menu.combo.useE:Value() and Ready(_E) and distanceToTarget <= 475 and distanceToTarget > 200 and not HasEBuff(target) and IsSafeToE(target, self) then
        Control.CastSpell(HK_E, target)
        return
    end
    
    -- E on minion to get closer to target
    if self.Menu.combo.gapClose:Value() and Ready(_E) and distanceToTarget > 475 then
        local minion = self:GetMinionForGapClose(target)
        if minion and IsSafeToE(minion, self) then
            Control.CastSpell(HK_E, minion)
            return
        end
    end
    
    -- Q with prediction for damage
    if self.Menu.combo.useQ:Value() and Ready(_Q) and not HasQ3() and distanceToTarget <= 475 then
        if self.Menu.prediction.useQPred:Value() then
            local prediction, hitChance = GetQPrediction(target)
            if prediction and hitChance >= minHitChance then
                local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                Control.CastSpell(HK_Q, predPos)
                return
            end
        else
            -- Fallback to direct cast
            Control.CastSpell(HK_Q, target.pos)
            return
        end
    end
end

function Yasuo:Harass()
    -- Simple harass: E on minion near enemy, then Q enemy with prediction
    if self.harassState == "idle" then
        -- Look for enemy first
        local enemy = self:GetNearestEnemy(self.Menu.harass.enemyRange:Value())
        if enemy then
            -- If E is ready and we want to use it
            if self.Menu.harass.useE:Value() and Ready(_E) then
                local minion = self:GetMinionForHarass(enemy)
                if minion and IsSafeToE(minion, self) then
                    -- Cast E on minion
                    Control.CastSpell(HK_E, minion)
                    
                    -- Change state to waiting for Q with timer
                    self.harassState = "waiting_for_q"
                    self.harassTimer = GetTickCount()
                    return
                end
            end
            
            -- If we can't E but Q is ready, use Q with prediction
            if self.Menu.harass.useQ:Value() and Ready(_Q) then
                local distanceToEnemy = GetDistance(myHero.pos, enemy.pos)
                if distanceToEnemy <= 475 then -- Q range
                    local minHitChance = self.Menu.prediction.hitChance:Value()
                    
                    -- Use prediction for Q
                    if HasQ3() and self.Menu.prediction.useQ3Pred:Value() then
                        local prediction, hitChance = GetQ3Prediction(enemy)
                        if prediction and hitChance >= minHitChance then
                            local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                            Control.CastSpell(HK_Q, predPos)
                            return
                        end
                    elseif self.Menu.prediction.useQPred:Value() then
                        local prediction, hitChance = GetQPrediction(enemy)
                        if prediction and hitChance >= minHitChance then
                            local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                            Control.CastSpell(HK_Q, predPos)
                            return
                        end
                    else
                        -- Fallback to direct cast if prediction disabled
                        Control.CastSpell(HK_Q, enemy.pos)
                        return
                    end
                end
            end
        end
        
    elseif self.harassState == "waiting_for_q" then
        -- Wait 600ms after E before casting Q
        local timeSinceE = GetTickCount() - self.harassTimer
        if timeSinceE >= 600 then -- Wait 0.6 seconds after E
            -- Now try to cast Q if it's ready
            if Ready(_Q) and self.Menu.harass.useQ:Value() then
                local enemy = self:GetNearestEnemy(self.Menu.harass.enemyRange:Value())
                if enemy then
                    local minHitChance = self.Menu.prediction.hitChance:Value()
                    
                    -- Use prediction for Q after E
                    if HasQ3() and self.Menu.prediction.useQ3Pred:Value() then
                        local prediction, hitChance = GetQ3Prediction(enemy)
                        if prediction and hitChance >= minHitChance then
                            local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                            Control.CastSpell(HK_Q, predPos)
                            self.harassState = "idle"
                            return
                        end
                    elseif self.Menu.prediction.useQPred:Value() then
                        local prediction, hitChance = GetQPrediction(enemy)
                        if prediction and hitChance >= minHitChance then
                            local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                            Control.CastSpell(HK_Q, predPos)
                            self.harassState = "idle"
                            return
                        end
                    else
                        -- Fallback to direct cast if prediction disabled
                        Control.CastSpell(HK_Q, enemy.pos)
                        self.harassState = "idle"
                        return
                    end
                end
            end
        end
        
        -- Timeout if too much time has passed (safety)
        if timeSinceE > 2000 then -- 2 seconds timeout
            self.harassState = "idle"
        end
    end
end

function Yasuo:Clear()
    local qDamage = GetQDamage()
    local eDamage = GetEDamage()
    
    -- E-Q Combo for clearing multiple minions (Q ready or will be ready after E)
    if self.Menu.clear.useE:Value() and self.Menu.clear.useQ:Value() and Ready(_E) and (Ready(_Q) or WillQBeReadyAfterE()) then
        local bestMinion = self:GetBestMinionForEQ()
        if bestMinion and IsSafeToE(bestMinion, self) then
            Control.CastSpell(HK_E, bestMinion)
            -- Cast Q after E (will be ready due to CD reduction)
            DelayAction(function()
                if Ready(_Q) then
                    Control.CastSpell(HK_Q, Game.mousePos())
                end
            end, 0.15) -- Slightly longer delay to ensure E CD reduction applies
            return
        end
    end
    
    -- Smart E usage when Q is almost ready
    if self.Menu.clear.useE:Value() and self.Menu.clear.useQ:Value() and Ready(_E) and WillQBeReadyAfterE() then
        local minion = self:GetBestMinionForSmartEQ(eDamage, qDamage)
        if minion and IsSafeToE(minion, self) then
            Control.CastSpell(HK_E, minion)
            -- Q will be ready after E
            DelayAction(function()
                if Ready(_Q) then
                    local clearTarget = self:GetBestMinionForQClear()
                    if clearTarget then
                        Control.CastSpell(HK_Q, clearTarget.pos)
                    end
                end
            end, 0.15)
            return
        end
    end
    
    -- Regular Q clear
    if self.Menu.clear.useQ:Value() and Ready(_Q) then
        local minion = self:GetBestMinionForQClear()
        if minion then
            Control.CastSpell(HK_Q, minion.pos)
            return
        end
    end
    
    -- E clear for single minions
    if self.Menu.clear.useE:Value() and Ready(_E) then
        local minion = self:GetBestMinionForEClear()
        if minion and IsSafeToE(minion, self) then
            Control.CastSpell(HK_E, minion)
        end
    end
end

function Yasuo:LastHit()
    local qDamage = GetQDamage()
    local eDamage = GetEDamage()
    
    -- Simple Q LastHit - same logic as Clear
    if self.Menu.lasthit.useQ:Value() and Ready(_Q) and qDamage > 0 then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.isEnemy and minion.alive and minion.visible then
                local distance = GetDistance(myHero.pos, minion.pos)
                if distance <= 475 and CanKillMinion(minion, qDamage) then
                    Control.CastSpell(HK_Q, minion.pos)
                    return
                end
            end
        end
    end
    
    -- Simple E LastHit - same logic as Clear
    if self.Menu.lasthit.useE:Value() and Ready(_E) and eDamage > 0 then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.isEnemy and minion.alive and minion.visible and not HasEBuff(minion) and IsSafeToE(minion, self) then
                local distance = GetDistance(myHero.pos, minion.pos)
                if distance <= 475 and CanKillMinion(minion, eDamage) then
                    Control.CastSpell(HK_E, minion)
                    -- TEMPORAL: Print minion buffs after E (REMOVE LATER)
                    DelayAction(function()
                        local buffCount = minion.buffCount or 0
                        for j = 0, buffCount do
                            local buff = minion:GetBuff(j)
                            if buff and buff.valid and buff.name then
                            end
                        end
                    end, 0.1)
                    return
                end
            end
        end
    end
end

-- Get best target for combo
function Yasuo:GetBestComboTarget()
    local bestTarget = nil
    local bestScore = 0
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and not hero.dead and hero.visible then
            local distance = GetDistance(myHero.pos, hero.pos)
            if distance <= 1200 then -- Extended range for E possibilities
                -- Calculate health percentage safely
                local healthPercent = hero.maxHealth > 0 and (hero.health / hero.maxHealth * 100) or 100
                
                -- Score based on priority: low health, close distance, no E buff
                local score = (100 - healthPercent) + (1200 - distance) / 10
                
                -- Bonus if we can E to them
                if distance <= 475 and not HasEBuff(hero) then
                    score = score + 50
                end
                
                -- Bonus if they're immobile (with safety check)
                if _G.GGPrediction and _G.GGPrediction.GetImmobileDuration then
                    local immobileDuration = _G.GGPrediction:GetImmobileDuration(hero)
                    if immobileDuration and immobileDuration > 0 then
                        score = score + 100
                    end
                end
                
                if score > bestScore then
                    bestScore = score
                    bestTarget = hero
                end
            end
        end
    end
    
    return bestTarget
end

-- Check if we can use ultimate (enemy is knocked up)
function Yasuo:CanUseUltimate(target)
    if not target or not target.valid or target.dead or not target.visible then return false end
    -- print("Checking if we can use ultimate on target: " .. target.charName)
    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and (buff.type == 30 or buff.type == 31) and buff.count > 0 then
            return true
        end
    end
    return false
end

-- Check if we're in a 1v1 situation
function Yasuo:IsOneVsOneSituation(target, checkRange)
    if not target or not target.valid then return false end
    
    checkRange = checkRange or 1500 -- Default range to check for other enemies
    local enemyCount = 0
    
    -- Count enemy champions in range
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and not hero.dead and hero.visible then
            local distance = GetDistance(myHero.pos, hero.pos)
            if distance <= checkRange then
                enemyCount = enemyCount + 1
            end
        end
    end
    
    -- 1v1 if only 1 enemy in range (our target)
    return enemyCount == 1
end

-- Get minion for gap closing towards target
function Yasuo:GetMinionForGapClose(target)
    local bestMinion = nil
    local bestScore = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible and not HasEBuff(minion) and IsSafeToE(minion, self) then
            local distanceToMinion = GetDistance(myHero.pos, minion.pos)
            if distanceToMinion <= 475 then -- E range
                -- Calculate if this minion gets us closer to target
                local distanceFromMinionToTarget = GetDistance(minion.pos, target.pos)
                local currentDistanceToTarget = GetDistance(myHero.pos, target.pos)
                
                if distanceFromMinionToTarget < currentDistanceToTarget then
                    -- Score based on how much closer we get
                    local score = currentDistanceToTarget - distanceFromMinionToTarget
                    
                    -- Bonus for closer minions (easier to reach)
                    score = score + (475 - distanceToMinion) / 10
                    
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

-- Get secondary target (enemy champion) when main target is airborne
function Yasuo:GetSecondaryTarget(mainTarget, range)
    local bestTarget = nil
    local bestScore = 0
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and hero ~= mainTarget and not hero.dead and hero.visible then
            local distance = GetDistance(myHero.pos, hero.pos)
            if distance <= range then
                -- Calculate health percentage safely
                local healthPercent = hero.maxHealth > 0 and (hero.health / hero.maxHealth * 100) or 100
                
                -- Score based on priority: low health, close distance, no E buff
                local score = (100 - healthPercent) + (range - distance) / 10
                
                -- Bonus if we can E to them
                if distance <= 475 and not HasEBuff(hero) then
                    score = score + 100
                end
                
                if score > bestScore then
                    bestScore = score
                    bestTarget = hero
                end
            end
        end
    end
    
    return bestTarget
end

-- Get minion near the target (for advanced combo when target is airborne)
function Yasuo:GetMinionNearTarget(target, range)
    local bestMinion = nil
    local closestDistance = math.huge
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible and not HasEBuff(minion) and IsSafeToE(minion, self) then
            local distanceToTarget = GetDistance(minion.pos, target.pos)
            local distanceToMinion = GetDistance(myHero.pos, minion.pos)
            
            -- Minion should be close to target and within E range
            if distanceToTarget <= range and distanceToMinion <= 475 then
                -- Prefer minions closer to us for easier E
                if distanceToMinion < closestDistance then
                    closestDistance = distanceToMinion
                    bestMinion = minion
                end
            end
        end
    end
    
    return bestMinion
end
function Yasuo:GetBestMinionForEQ()
    local bestMinion = nil
    local maxMinions = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible and not HasEBuff(minion) and IsSafeToE(minion, self) then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= 475 then -- E range
                -- Count minions around this position for Q
                local minionsAroundTarget = self:CountMinionsAroundPosition(minion.pos, 250)
                if minionsAroundTarget >= self.Menu.clear.minMinions:Value() and minionsAroundTarget > maxMinions then
                    maxMinions = minionsAroundTarget
                    bestMinion = minion
                end
            end
        end
    end
    
    return bestMinion
end

-- Get nearest enemy champion for harass
function Yasuo:GetNearestEnemy(range)
    local nearestEnemy = nil
    local nearestDistance = math.huge
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and not hero.dead and hero.visible then
            local distance = GetDistance(myHero.pos, hero.pos)
            if distance <= range and distance < nearestDistance then
                nearestDistance = distance
                nearestEnemy = hero
            end
        end
    end
    
    return nearestEnemy
end

-- Get best minion for harass (close to us and allows Q to hit enemy)
function Yasuo:GetMinionForHarass(enemy)
    local bestMinion = nil
    local bestScore = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible and not HasEBuff(minion) and IsSafeToE(minion, self) then
            local distanceToMinion = GetDistance(myHero.pos, minion.pos)
            if distanceToMinion <= 475 then -- E range
                -- Calculate if Q from minion position can hit enemy
                local distanceFromMinionToEnemy = GetDistance(minion.pos, enemy.pos)
                
                -- More lenient range check - if enemy is reasonably close to minion
                if distanceFromMinionToEnemy <= 600 then -- Extended range for Q possibility
                    -- Score based on how close minion is to us (closer = better)
                    local score = 500 - distanceToMinion
                    
                    -- Bonus if minion is between us and enemy (better positioning)
                    local distanceToEnemy = GetDistance(myHero.pos, enemy.pos)
                    if distanceToMinion < distanceToEnemy then
                        score = score + 100
                    end
                    
                    -- Bonus for closer minion-to-enemy distance
                    if distanceFromMinionToEnemy <= 475 then
                        score = score + 200 -- Big bonus for guaranteed Q range
                    else
                        score = score + (100 - (distanceFromMinionToEnemy - 475)) -- Gradual bonus
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

function Yasuo:CountMinionsAroundPosition(pos, range)
    local count = 0
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible then
            local distance = GetDistance(pos, minion.pos)
            if distance <= range then
                count = count + 1
            end
        end
    end
    return count
end

function Yasuo:GetBestMinionForQClear()
    local bestMinion = nil
    local bestScore = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= 475 then -- Q range
                -- Prioritize cannon minions and closer minions
                local score = minion.maxHealth > 300 and 100 or 50 -- Cannon minion bonus
                score = score + (500 - distance) -- Closer is better
                
                if score > bestScore then
                    bestScore = score
                    bestMinion = minion
                end
            end
        end
    end
    
    return bestMinion
end

function Yasuo:GetBestMinionForEClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible and not HasEBuff(minion) and IsSafeToE(minion, self) then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= 475 then -- E range
                return minion
            end
        end
    end
    return nil
end

function Yasuo:GetLastHitMinionQ(qDamage)
    local bestMinion = nil
    local lowestHealth = math.huge
    
    -- Use the same minion iteration method as LaneClear
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= 475 and CanKillMinion(minion, qDamage) then -- Q range is 475
                -- Prefer minions with lower health (closer to dying)
                if minion.health < lowestHealth then
                    lowestHealth = minion.health
                    bestMinion = minion
                end
            end
        end
    end
    
    return bestMinion
end

function Yasuo:GetLastHitMinionE(eDamage)
    local bestMinion = nil
    local lowestHealth = math.huge
    
    -- Use the same minion iteration method as LaneClear
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible and not HasEBuff(minion) and IsSafeToE(minion, self) then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= 475 and CanKillMinion(minion, eDamage) then -- E range is 475
                -- Prefer minions with lower health (closer to dying)
                if minion.health < lowestHealth then
                    lowestHealth = minion.health
                    bestMinion = minion
                end
            end
        end
    end
    
    return bestMinion
end

-- Initialize
function Yasuo:GetBestMinionForSmartEQ(eDamage, qDamage)
    local bestMinion = nil
    local bestValue = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible and not HasEBuff(minion) and IsSafeToE(minion, self) then
            local distanceToMinion = GetDistance(myHero.pos, minion.pos)
            if distanceToMinion <= 475 then -- E range
                -- Check if this minion can be killed by E
                local canKillWithE = minion.health <= eDamage
                
                -- Calculate value: prioritize killing minions and closer targets
                local value = 0
                if canKillWithE then
                    value = value + 100 -- High priority for killing
                end
                
                -- Add distance bonus (closer = better)
                value = value + (50 - distanceToMinion * 0.1)
                
                -- Check if there are Q targets near this minion after E
                local futurePos = minion.pos
                local nearbyMinions = 0
                local nearbyKillable = 0
                
                for j = 1, Game.MinionCount() do
                    local nearMinion = Game.Minion(j)
                    if nearMinion and nearMinion ~= minion and nearMinion.isEnemy and nearMinion.alive and nearMinion.visible then
                        if GetDistance(futurePos, nearMinion.pos) <= 475 then -- Q range after E
                            nearbyMinions = nearbyMinions + 1
                            if nearMinion.health <= qDamage then
                                nearbyKillable = nearbyKillable + 1
                            end
                        end
                    end
                end
                
                -- Bonus for having Q targets nearby
                value = value + (nearbyMinions * 10) + (nearbyKillable * 20)
                
                if value > bestValue then
                    bestValue = value
                    bestMinion = minion
                end
            end
        end
    end
    
    return bestMinion
end

function Yasuo:CheckAutoWindwall()
    if not Ready(_W) then return end
    
    -- Check for incoming projectiles in range
    for i = 1, Game.MissileCount() do
        local missile = Game.Missile(i)
        if missile and missile.isEnemy and missile.pos then
            local distanceToMissile = GetDistance(myHero.pos, missile.pos)
            local detectionRange = self.Menu.windwall.range:Value()
            if distanceToMissile <= detectionRange then
                -- Use blockspells
                local requireBlocking = false
                -- print(missile.name)

                for i = 1, #blockSpells do
                    local missileLowerCase = string.lower(missile.name)
                    if string.find(missileLowerCase, blockSpells[i]) then
                        requireBlocking = true
                        break
                    end
                end
                -- print(missile.activeSpell)
                -- Simple check: if missile is close and we haven't used W recently
                if GetTickCount() - self.lastWindwallTime > 500 and requireBlocking then -- 0.5s cooldown
                    -- Cast W towards the missile position
                    Control.CastSpell(HK_W, missile.pos)
                    self.lastWindwallTime = GetTickCount()
                    break -- Only cast one W per check
                    
                end
            end
        end
    end
end

-- Combo Logic System Functions
function Yasuo:HandleEQ3FlashCombo()
    -- CRITICAL: Check if Q3 (tornado) is ready - this combo ONLY works with Q3!
    -- Also respect the menu option for requiring Q3
    if self.Menu.comboLogic.requireQ3Ready:Value() then
        if not HasQ3() or not Ready(_Q) then
            return
        end
    else
        -- Even if user disabled the option, E-Q3-Flash still needs Q3 to work properly
        if not HasQ3() or not Ready(_Q) then
            return
        end
    end
    
    -- Check if Flash is available
    local flashSpell = myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" and SUMMONER_1 or 
                      (myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" and SUMMONER_2 or nil)
    
    if not flashSpell or not Ready(flashSpell) then 
        return 
    end
    
    -- Automatically find best target for combo
    local target = self:GetBestEQ3FlashTarget()
    if not target then 
        return 
    end
    
    -- Find best unit (minion or enemy) to E onto for optimal positioning
    local bestUnit = self:GetBestUnitForEQ3Flash(target)
    if not bestUnit then 
        return 
    end
    
    -- Debug info
    local targetName = target.charName or "Unknown"
    local unitType = "Unknown"
    local unitName = "Unknown"
    
    if bestUnit.charName then
        unitType = "Champion"
        unitName = bestUnit.charName
    elseif bestUnit.team == 300 then
        unitType = "Monster"
        unitName = "Jungle Monster"
    else
        unitType = "Minion" 
        unitName = "Lane Minion"
    end
    
    -- Start the combo
    self.comboLogicState = "executing_eq3flash"
    self.comboLogicTarget = target
    self.eq3FlashStep = 1
    self.comboLogicTimer = GetTickCount()
    
    -- Execute first step immediately (E to best unit + Q simultaneously towards target)
    if Ready(_E) and not HasEBuff(bestUnit) and IsSafeToE(bestUnit, self) then
        -- Cast E on the positioning unit
        Control.CastSpell(HK_E, bestUnit)
        
        -- Cast Q with a small delay after E (0.1 seconds)
        DelayAction(function()
            if Ready(_Q) and HasQ3() and self.comboLogicState == "executing_eq3flash" then
                -- ONLY use Q3 for this combo - it's E-Q3-Flash, not E-Q-Flash!
                -- Q3 is required because it has knockup effect which enables the Flash follow-up
                local prediction, hitChance = GetQ3Prediction(target)
                local minHitChance = self.Menu.prediction.hitChance:Value()
                
                if self.Menu.prediction.useQ3Pred:Value() and prediction and hitChance >= minHitChance then
                    local predPos = Vector(prediction.x, myHero.pos.y, prediction.z)
                    Control.CastSpell(HK_Q, predPos)
                else
                    Control.CastSpell(HK_Q, target.pos)
                end
                
                -- Cast Flash with 0.2 second delay after Q3 (tornado)
                DelayAction(function()
                    -- Only Flash if: 1) Q3 was used, 2) combo still active, 3) target still valid
                    if self.Menu.comboLogic.flashAfterQ3:Value() and self.comboLogicState == "executing_eq3flash" and 
                       self.comboLogicTarget and self.comboLogicTarget.valid and not self.comboLogicTarget.dead then
                        
                        -- Re-check Flash availability within DelayAction
                        local flashSpell = myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" and SUMMONER_1 or 
                                          (myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" and SUMMONER_2 or nil)
                        
                        if flashSpell and Ready(flashSpell) then
                            -- Get updated target position
                            local currentTarget = self.comboLogicTarget
                            local flashPos = currentTarget.pos
                            local distance = GetDistance(myHero.pos, currentTarget.pos)
                            
                            -- Flash closer to target if too far, but not too close
                            if distance > 200 then
                                local direction = (currentTarget.pos - myHero.pos):Normalized()  
                                flashPos = myHero.pos + direction * math.min(400, distance - 150)
                            end
                            
                            -- Manually press Flash key and cast to position
                            Control.SetCursorPos(flashPos)
                            if flashSpell == SUMMONER_1 then
                                Control.KeyDown(HK_SUMMONER_1)
                                Control.KeyUp(HK_SUMMONER_1)
                            else
                                Control.KeyDown(HK_SUMMONER_2)
                                Control.KeyUp(HK_SUMMONER_2)
                            end
                        else
                            local f1Name = myHero:GetSpellData(SUMMONER_1).name or "none"
                            local f2Name = myHero:GetSpellData(SUMMONER_2).name or "none"
                            local f1Ready = Ready(SUMMONER_1)
                            local f2Ready = Ready(SUMMONER_2)
                        end
                    end
                    -- Reset combo state after flash attempt
                    self:ResetComboLogic()
                end, 0.2) -- 0.4 second delay for Flash (increased from 0.2)
            end
        end, 0.1) -- 0.1 second delay for Q after E
        
        self.eq3FlashStep = 2 -- Go to flash step
        
    else
        -- Reset if can't execute
        self:ResetComboLogic()
    end
end

function Yasuo:GetBestEQ3FlashTarget()
    local bestTarget = nil
    local bestScore = 0
    local maxRange = self.Menu.comboLogic.eq3flashRange:Value()
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and not hero.dead and hero.visible then
            local distance = GetDistance(myHero.pos, hero.pos)
            if distance <= maxRange then
                -- Calculate health percentage safely
                local healthPercent = hero.maxHealth > 0 and (hero.health / hero.maxHealth * 100) or 100
                
                -- Score based on priority: low health, reasonable distance
                local score = (100 - healthPercent) * 2 + (maxRange - distance) / 10
                
                -- Bonus for isolated targets
                local nearbyEnemies = 0
                for j = 1, Game.HeroCount() do
                    local otherHero = Game.Hero(j)
                    if otherHero and otherHero.isEnemy and otherHero ~= hero and not otherHero.dead and otherHero.visible then
                        if GetDistance(hero.pos, otherHero.pos) <= 600 then
                            nearbyEnemies = nearbyEnemies + 1
                        end
                    end
                end
                
                if nearbyEnemies == 0 then
                    score = score + 50 -- Bonus for isolated target
                end
                
                if score > bestScore then
                    bestScore = score
                    bestTarget = hero
                end
            end
        end
    end
    
    return bestTarget
end

function Yasuo:ExecuteComboLogic()
    if self.comboLogicState == "executing_eq3flash" then
        self:ExecuteEQ3FlashCombo()
    end
end

function Yasuo:ExecuteEQ3FlashCombo()
    local target = self.comboLogicTarget
    if not target or not target.valid or target.dead then
        self:ResetComboLogic()
        return
    end
    
    local timeSinceStart = GetTickCount() - self.comboLogicTimer
    
    -- Safety timeout - reset if combo takes too long
    if timeSinceStart > 2000 then -- 2 seconds timeout
        self:ResetComboLogic()
    end
end

function Yasuo:GetBestUnitForEQ3Flash(target)
    if not target or not target.valid then return nil end
    
    local bestUnit = nil
    local bestScore = 0
    local flashRange = self.Menu.comboLogic.flashRange:Value() -- Use configurable Flash range
    
    -- Check enemy champions first (excluding our target if it's a champion)
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and hero ~= target and not hero.dead and hero.visible and 
           not HasEBuff(hero) and IsSafeToE(hero, self) then
            local distanceToHero = GetDistance(myHero.pos, hero.pos)
            if distanceToHero <= 475 then -- E range
                -- Calculate position after E to hero
                local distanceFromHeroToTarget = GetDistance(hero.pos, target.pos)
                
                -- FLASH DISTANCE CHECK: Target must be within Flash range after E
                if distanceFromHeroToTarget <= flashRange then
                    -- We want to be in good Q3 range (200-1000) after E - more flexible range
                    if distanceFromHeroToTarget >= 200 and distanceFromHeroToTarget <= 1000 then
                        -- Score based on optimal positioning for Q3
                        local optimalDistance = 600 -- Sweet spot for Q3
                        local distancePenalty = math.abs(distanceFromHeroToTarget - optimalDistance)
                        local score = 3000 - distancePenalty -- Higher score for champions
                        
                        -- Bonus for closer heroes (easier to E)
                        score = score + (475 - distanceToHero) / 5
                        
                        -- Extra bonus for being in optimal Flash range (200-350 units)
                        if distanceFromHeroToTarget >= 200 and distanceFromHeroToTarget <= 350 then
                            score = score + 500
                        end
                        
                        if score > bestScore then
                            bestScore = score
                            bestUnit = hero
                        end
                    end
                end
            end
        end
    end
    
    -- Check jungle monsters
    for i = 1, Game.MinionCount() do
        local monster = Game.Minion(i)
        if monster and monster.team == 300 and monster.alive and monster.visible and -- Jungle monsters have team 300
           not HasEBuff(monster) and IsSafeToE(monster, self) then
            local distanceToMonster = GetDistance(myHero.pos, monster.pos)
            if distanceToMonster <= 475 then -- E range
                -- Calculate position after E to monster
                local distanceFromMonsterToTarget = GetDistance(monster.pos, target.pos)
                
                -- FLASH DISTANCE CHECK: Target must be within Flash range after E
                if distanceFromMonsterToTarget <= flashRange then
                    -- We want to be in good Q3 range (200-1000) after E
                    if distanceFromMonsterToTarget >= 200 and distanceFromMonsterToTarget <= 1000 then
                        -- Score based on optimal positioning for Q3
                        local optimalDistance = 600 -- Sweet spot for Q3
                        local distancePenalty = math.abs(distanceFromMonsterToTarget - optimalDistance)
                        local score = 2000 - distancePenalty -- Medium score for jungle monsters
                        
                        -- Bonus for closer monsters (easier to E)
                        score = score + (475 - distanceToMonster) / 5
                        
                        -- Extra bonus for large monsters (more reliable)
                        if monster.maxHealth > 1000 then
                            score = score + 300
                        end
                        
                        -- Extra bonus for being in optimal Flash range (200-350 units)
                        if distanceFromMonsterToTarget >= 200 and distanceFromMonsterToTarget <= 350 then
                            score = score + 400
                        end
                        
                        if score > bestScore then
                            bestScore = score
                            bestUnit = monster
                        end
                    end
                end
            end
        end
    end
                    
    -- Check minions if no good champion or monster found
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.isEnemy and minion.alive and minion.visible and 
           not HasEBuff(minion) and IsSafeToE(minion, self) then
            local distanceToMinion = GetDistance(myHero.pos, minion.pos)
            if distanceToMinion <= 475 then -- E range
                -- Calculate position after E to minion
                local distanceFromMinionToTarget = GetDistance(minion.pos, target.pos)
                
                -- FLASH DISTANCE CHECK: Target must be within Flash range after E
                if distanceFromMinionToTarget <= flashRange then
                    -- We want to be in good Q3 range (200-1000) after E - more flexible range
                    if distanceFromMinionToTarget >= 200 and distanceFromMinionToTarget <= 1000 then
                        -- Score based on optimal positioning for Q3
                        local optimalDistance = 600 -- Sweet spot for Q3
                        local distancePenalty = math.abs(distanceFromMinionToTarget - optimalDistance)
                        local score = 1000 - distancePenalty -- Lower score for minions but still viable
                        
                        -- Bonus for closer minions (easier to E)
                        score = score + (475 - distanceToMinion) / 5
                        
                        -- Extra bonus for minions that are cannon or super minions (more reliable)
                        if minion.charName and (string.find(minion.charName, "Cannon") or string.find(minion.charName, "Super")) then
                            score = score + 200
                        end
                        
                        -- Extra bonus for being in optimal Flash range (200-350 units)
                        if distanceFromMinionToTarget >= 200 and distanceFromMinionToTarget <= 350 then
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
    
    -- Debug: Print why no unit was found if bestUnit is nil
    if not bestUnit then
        local debugInfo = "E-Q3-Flash Debug: No valid unit found. Checking nearby units:"
        local unitCount = 0
        
        -- Check what units are available
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.isEnemy and hero ~= target and not hero.dead and hero.visible then
                local distance = GetDistance(myHero.pos, hero.pos)
                unitCount = unitCount + 1
                if distance <= 475 then
                    local hasEBuff = HasEBuff(hero)
                    local isSafe = IsSafeToE(hero, self)
                    local distanceToTarget = GetDistance(hero.pos, target.pos)
                    local withinFlashRange = distanceToTarget <= flashRange
                    -- print(string.format("Champion %s: dist=%.0f, E-buff=%s, safe=%s, target-dist=%.0f, flash-ok=%s", 
                    --       hero.charName, distance, tostring(hasEBuff), tostring(isSafe), distanceToTarget, tostring(withinFlashRange)))
                end
            end
        end
        
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and ((minion.isEnemy and minion.alive) or minion.team == 300) and minion.visible then
                local distance = GetDistance(myHero.pos, minion.pos)
                unitCount = unitCount + 1
                if distance <= 475 then
                    local hasEBuff = HasEBuff(minion)
                    local isSafe = IsSafeToE(minion, self)
                    local unitType = minion.team == 300 and "Monster" or "Minion"
                    -- print(string.format("%s: dist=%.0f, E-buff=%s, safe=%s", unitType, distance, tostring(hasEBuff), tostring(isSafe)))
                end
            end
        end
        
        -- print(string.format("Total units checked: %d", unitCount))
    end
    
    return bestUnit
end

function Yasuo:ResetComboLogic()
    self.comboLogicState = "idle"
    self.comboLogicTarget = nil
    self.eq3FlashStep = 0
    self.comboLogicTimer = 0
end

Yasuo()