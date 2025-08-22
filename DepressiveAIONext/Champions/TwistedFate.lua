-- DepressiveAIONext integration guard (prevents double loading)
if _G.DepressiveAIONext_TwistedFateLoaded then return end
_G.DepressiveAIONext_TwistedFateLoaded = true

-- Champion whitelist
local Heroes = {"TwistedFate"}

-- Fallback contains (in case table.contains is missing in some loaders)
local function _contains(t, v)
    for i = 1, #t do if t[i] == v then return true end end
    return false
end

-- Hero validation (supports environments without table.contains)
if not (table.contains and table.contains(Heroes, myHero.charName) or _contains(Heroes, myHero.charName)) then return end

-- Explicit require to align with other DepressiveAIONext champion modules
pcall(function()
    if not _G.DepressivePrediction then
        require("DepressivePrediction")
    end
end)

-- Load DepressivePrediction library
local function LoadPrediction()
    if not _G.DepressivePrediction then
        local success, err = pcall(function()
            require "DepressivePrediction"
        end)
        if not success then
            print("Failed to load DepressivePrediction: " .. tostring(err))
            return false
        end
    end
    return _G.DepressivePrediction ~= nil
end

-- Try to load prediction
LoadPrediction()

local Prediction = _G.DepressivePrediction

-- Constants and globals
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameCanUseSpell = Game.CanUseSpell
local GameTimer = Game.Timer
local TableInsert = table.insert


local HK_U = 0x55  -- U key for manual gold card selection
local HK_I = 0x49  -- I key for manual red card selection
local HK_MB4 = 0x05  -- MB4 (Mouse Button 4 - Side button)
local HK_MB5 = 0x06  -- MB5 (Mouse Button 5 - Side button)


local lastMove = 0
local lastQCast = 0
local lastWCast = 0
local lastRCast = 0
local Enemys = {}
local Allys = {}
local myHero = myHero

-- Card types enum
local CARD_TYPES = {
    NONE = 0,
    BLUE = 1,
    RED = 2,
    GOLD = 3
}

-- Build types enum
local BUILD_TYPES = {
    UNKNOWN = 0,
    AP = 1,
    AD = 2,
    HYBRID = 3
}

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
        if hero and hero.isAlly then
            cb(hero)
        end
    end
end

local function OnEnemyHeroLoad(cb)
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero and hero.isEnemy then
            cb(hero)
        end
    end
end

local function GetEnemyHeroes()
    local _EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.isEnemy and IsValid(hero) then
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
        if IsValid(enemy) and enemy.visible then
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
        if buff and buff.count > 0 and buff.name:lower():find(buffname:lower()) then
            return true
        end
    end
    return false
end

-- Twisted Fate Class
class "TwistedFate"

function TwistedFate:__init()
    -- Spell data
    self.Q = {
        range = 1500,
        speed = 1000,
        delay = 0.25,
        width = 40,
        collision = true,
        type = "linear"
    }
    
    self.W = {
        range = 0, -- Empowered auto-attack
        delay = 0.25,
        cardCycle = {CARD_TYPES.BLUE, CARD_TYPES.RED, CARD_TYPES.GOLD},
        cycleTime = 0.5, -- Time between each card change
        maxHoldTime = 6.0 -- Max time to hold a card
    }
    
    self.E = {
        -- Passive ability, no active cast
        attackSpeedBonus = true
    }
    
    self.R = {
        range = 5500, -- Global range (level 1 base)
        delay = 1.5,
        type = "global"
    }
    
    -- Get dynamic R range based on level
    self.GetRRange = function(self)
        if not IsSpellLearned(_R) then return 0 end
        local level = myHero:GetSpellData(_R).level
        if level == 0 then return 0 end
        
        -- Twisted Fate R range scales: 5500/6500/7500
        local ranges = {5500, 6500, 7500}
        return ranges[level] or 5500
    end
    
    -- State tracking
    self.currentCard = CARD_TYPES.NONE
    self.cardSelectStartTime = 0
    self.cardCycleIndex = 1
    self.isSelectingCard = false
    self.toSelect = "NONE"
    self.rPressed = false -- Track if R was pressed for priority gold card selection
    self.rPressedTime = nil -- Track when R was pressed for timeout
    self.lastPick = 0 -- Initialize lastPick to prevent nil errors
    self.lastAutoHarass = 0 -- Track last auto harass cast
    
    -- Initialize global timers
    lastQCast = 0
    lastWCast = 0
    lastRCast = 0
    
    -- Load units
    OnAllyHeroLoad(function(hero) TableInsert(Allys, hero) end)
    OnEnemyHeroLoad(function(hero) TableInsert(Enemys, hero) end)
    
    -- Initialize enemy list
    Enemys = GetEnemyHeroes()
    
    -- Orbwalker integration
    if _G.SDK and _G.SDK.Orbwalker then
        _G.SDK.Orbwalker:OnPreMovement(function() 
            if self.isSelectingCard then
                return false -- Block movement while selecting card
            end
        end)
        
        _G.SDK.Orbwalker:OnPostAttack(function()
            -- Reset after using Pick A Card
            if self.currentCard ~= CARD_TYPES.NONE then
                self.currentCard = CARD_TYPES.NONE
                self.isSelectingCard = false
            end
        end)
    end
    
    self:LoadMenu()
    
    -- Callbacks
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("WndMsg", function(msg, wParam) self:OnWndMsg(msg, wParam) end)
end

function TwistedFate:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "TwistedFate", name = "Twisted Fate - Depressive"})
    self.Menu:MenuElement({name = "Ping", id = "ping", value = 20, min = 0, max = 300, step = 1})
    
    -- Auto Card Selection System
    self.Menu:MenuElement({type = MENU, id = "cardselect", name = "Auto Card Selection"})
    self.Menu.cardselect:MenuElement({id = "enabled", name = "Enable Auto Card Selection", value = true})
    self.Menu.cardselect:MenuElement({id = "smartSelect", name = "Smart Card Selection", value = true})
    self.Menu.cardselect:MenuElement({id = "goldPriority", name = "Gold Card Priority", value = true})
    self.Menu.cardselect:MenuElement({id = "blueForHarass", name = "Blue Card for Harass", value = true})
    self.Menu.cardselect:MenuElement({id = "redForWaveclear", name = "Red Card for Waveclear", value = true})
    self.Menu.cardselect:MenuElement({id = "goldForKill", name = "Gold Card for Kill Potential", value = true})
    self.Menu.cardselect:MenuElement({id = "anticipateSelect", name = "Anticipate Card Selection", value = true})
    
    -- Build Selection System
    self.Menu:MenuElement({type = MENU, id = "build", name = "Build Type"})
    self.Menu.build:MenuElement({id = "buildType", name = "Select Build Type", value = 2, drop = {"AP", "AD", "Hybrid"}})
    
    -- Combo
    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.combo:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.combo:MenuElement({id = "qBeforeW", name = "Q before W combo", value = true})
    self.Menu.combo:MenuElement({id = "prioritizeGold", name = "Prioritize Gold Card", value = true})
    self.Menu.combo:MenuElement({id = "onlyGoldIfKillable", name = "Gold only if killable", value = false})
    self.Menu.combo:MenuElement({id = "comboRange", name = "Combo Range", value = 600, min = 200, max = 1000, step = 50})
    
    -- Harass
    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.harass:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.harass:MenuElement({id = "preferBlue", name = "Prefer Blue Card", value = true})
    self.Menu.harass:MenuElement({id = "manaThreshold", name = "Min Mana %", value = 40, min = 0, max = 100, step = 5})
    self.Menu.harass:MenuElement({id = "autoHarass", name = "Auto Harass Q Key", key = string.byte("V")})
    self.Menu.harass:MenuElement({id = "autoHarassRange", name = "Auto Harass Range", value = 1200, min = 600, max = 1500, step = 50})
    self.Menu.harass:MenuElement({id = "autoHarassMana", name = "Auto Harass Min Mana %", value = 50, min = 20, max = 80, step = 5})
    
    -- Clear
    self.Menu:MenuElement({type = MENU, id = "clear", name = "Lane Clear"})
    self.Menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.clear:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.clear:MenuElement({id = "preferRed", name = "Prefer Red Card", value = true})
    self.Menu.clear:MenuElement({id = "minMinionsQ", name = "Min minions for Q", value = 3, min = 1, max = 6})
    self.Menu.clear:MenuElement({id = "useWForMana", name = "Use Blue Card for Mana", value = true})
    self.Menu.clear:MenuElement({id = "manaThreshold", name = "Mana threshold for Blue", value = 30, min = 0, max = 80, step = 5})
    
    -- LastHit
    self.Menu:MenuElement({type = MENU, id = "lasthit", name = "Last Hit"})
    self.Menu.lasthit:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.lasthit:MenuElement({id = "useW", name = "Use W (Blue Card)", value = true})
    self.Menu.lasthit:MenuElement({id = "onlyBlueCard", name = "Only Blue Card for Mana", value = true})
    
    -- Flee
    self.Menu:MenuElement({type = MENU, id = "flee", name = "Flee"})
    self.Menu.flee:MenuElement({id = "useQ", name = "Use Q to slow enemies", value = true})
    self.Menu.flee:MenuElement({id = "useW", name = "Use W (Gold Card)", value = true})
    self.Menu.flee:MenuElement({id = "useR", name = "Use R to escape", value = true})
    
    -- Advanced
    self.Menu:MenuElement({type = MENU, id = "advanced", name = "Advanced Settings"})
    self.Menu.advanced:MenuElement({id = "cardTiming", name = "Card Selection Timing", value = 0.1, min = 0.1, max = 0.8, step = 0.1})
    self.Menu.advanced:MenuElement({id = "anticipationTime", name = "Card Anticipation Time", value = 0.5, min = 0.5, max = 2.0, step = 0.1})
    self.Menu.advanced:MenuElement({id = "qPrediction", name = "Q Prediction Accuracy", value = 0.5, min = 0.5, max = 1.0, step = 0.1})
    self.Menu.advanced:MenuElement({id = "blueCardManaThreshold", name = "Blue Card Max Mana %", value = 60, min = 0, max = 100, step = 5})
    self.Menu.advanced:MenuElement({id = "manualGoldCard", name = "Manual Gold Card Key", key = string.byte("U")})
    self.Menu.advanced:MenuElement({id = "manualRedCard", name = "Manual Red Card Key", key = string.byte("I")})
    self.Menu.advanced:MenuElement({id = "mb4Action", name = "MB4 Action", value = 1, drop = {"Gold Card", "Red Card", "Blue Card", "Disabled"}})
    self.Menu.advanced:MenuElement({id = "mb5Action", name = "MB5 Action", value = 2, drop = {"Gold Card", "Red Card", "Blue Card", "Disabled"}})
    
    -- Drawing
    self.Menu:MenuElement({type = MENU, id = "drawing", name = "Drawing"})
    self.Menu.drawing:MenuElement({id = "Q", name = "Draw Q Range", value = true})
    self.Menu.drawing:MenuElement({id = "W", name = "Draw W Status", value = true})
    self.Menu.drawing:MenuElement({id = "R", name = "Draw R Range", value = false})
    self.Menu.drawing:MenuElement({id = "buildType", name = "Draw Build Type", value = true})
    self.Menu.drawing:MenuElement({id = "cardStatus", name = "Draw Card Status", value = true})
    self.Menu.drawing:MenuElement({id = "killable", name = "Draw Killable Enemies", value = true})
end

function TwistedFate:Draw()
    if myHero.dead then return end
    
    local myPos = myHero.pos
    
    -- Draw Q Range
    if self.Menu.drawing.Q:Value() and Ready(_Q) then
        Draw.Circle(myPos, self.Q.range, Draw.Color(80, 255, 165, 0))
    end
    
    -- Draw R Range Circle on Map (always visible when learned)
    if self.Menu.drawing.R:Value() and IsSpellLearned(_R) then
        local rRange = self:GetRRange()
        if rRange > 0 then
            -- Always draw the R range circle when R is learned
            local rangeColor = Ready(_R) and Draw.Color(120, 255, 215, 0) or Draw.Color(60, 150, 150, 150)
            local innerColor = Ready(_R) and Draw.Color(80, 255, 215, 0) or Draw.Color(40, 150, 150, 150)
            
            -- Draw the full R range circle around the hero (ALWAYS VISIBLE)
            Draw.Circle(myPos, rRange, rangeColor) -- Gold circle showing max range on main map
            
            -- Draw inner circle at 75% range for reference
            local innerRange = rRange * 0.75
            Draw.Circle(myPos, innerRange, innerColor) -- Lighter gold inner circle on main map
            
            -- Draw R range circle on MINIMAP (this is what you want!)
            Draw.CircleMinimap(myPos, rRange, rangeColor) -- R range on minimap
            Draw.CircleMinimap(myPos, innerRange, innerColor) -- Inner range on minimap
            
            -- Draw range text above player
            local readyText = Ready(_R) and "READY" or ("CD: " .. math.ceil(myHero:GetSpellData(_R).currentCd) .. "s")
            local rangeText = "R Range: " .. math.floor(rRange) .. " units - " .. readyText
            local levelText = "Level " .. myHero:GetSpellData(_R).level .. " Ultimate"
            local textColor = Ready(_R) and Draw.Color(255, 255, 215, 0) or Draw.Color(255, 150, 150, 150)
            
            Draw.Text(rangeText, 16, myPos:To2D().x - 80, myPos:To2D().y - 140, textColor)
            Draw.Text(levelText, 14, myPos:To2D().x - 50, myPos:To2D().y - 120, Draw.Color(255, 200, 200, 200))
        end
        
        -- Draw R targeting circle at cursor when R is pressed/active (SEPARATE SYSTEM)
        if Ready(_R) and (self.rPressed or myHero.activeSpell.name == "Gate") then
            local cursorPos = Game.mousePos()  -- Fixed: added parentheses to call the function
            if cursorPos then
                -- Only show cursor targeting if within range
                local distanceToCursor = GetDistance(myHero.pos, cursorPos)
                local rRange = self:GetRRange()
                
                if distanceToCursor <= rRange then
                    -- Draw circle at cursor position showing R landing area
                    Draw.Circle(cursorPos, 200, Draw.Color(200, 255, 100, 100)) -- Red circle for landing
                    Draw.Circle(cursorPos, 400, Draw.Color(150, 255, 50, 50)) -- Outer effect area
                    
                    -- Draw text at cursor
                    local cursorScreen = cursorPos:To2D()
                    if cursorScreen.onScreen then
                        Draw.Text("R LANDING", 16, cursorScreen.x - 35, cursorScreen.y - 40, Draw.Color(255, 255, 255, 255))
                        local distanceText = math.floor(distanceToCursor) .. "/" .. math.floor(rRange)
                        Draw.Text(distanceText, 12, cursorScreen.x - 20, cursorScreen.y - 20, Draw.Color(255, 200, 200, 200))
                    end
                else
                    -- Show out of range indicator
                    local cursorScreen = cursorPos:To2D()
                    if cursorScreen.onScreen then
                        Draw.Text("OUT OF RANGE", 16, cursorScreen.x - 45, cursorScreen.y - 40, Draw.Color(255, 255, 0, 0))
                        local distanceText = math.floor(distanceToCursor) .. "/" .. math.floor(rRange)
                        Draw.Text(distanceText, 12, cursorScreen.x - 20, cursorScreen.y - 20, Draw.Color(255, 255, 0, 0))
                    end
                end
            end
        end
    end
    
    -- Draw Build Type
    if self.Menu.drawing.buildType:Value() then
        local buildText = "Build: "
        local buildColor = Draw.Color(255, 255, 255, 255)
        local buildValue = self.Menu.build.buildType:Value()
        
        if buildValue == 1 then
            buildText = buildText .. "AP"
            buildColor = Draw.Color(255, 0, 100, 255)
        elseif buildValue == 2 then
            buildText = buildText .. "AD"
            buildColor = Draw.Color(255, 255, 100, 0)
        elseif buildValue == 3 then
            buildText = buildText .. "Hybrid"
            buildColor = Draw.Color(255, 255, 0, 255)
        end
        
        Draw.Text(buildText, 20, myPos:To2D().x - 50, myPos:To2D().y - 100, buildColor)
    end
    
    -- Draw Card Status
    if self.Menu.drawing.cardStatus:Value() then
        local cardText = "Card: "
        local cardColor = Draw.Color(255, 255, 255, 255)
        local wSpellName = myHero:GetSpellData(_W).name
        
        if self.currentCard == CARD_TYPES.BLUE then
            cardText = cardText .. "BLUE"
            cardColor = Draw.Color(255, 100, 150, 255)
        elseif self.currentCard == CARD_TYPES.RED then
            cardText = cardText .. "RED"  
            cardColor = Draw.Color(255, 255, 100, 100)
        elseif self.currentCard == CARD_TYPES.GOLD then
            cardText = cardText .. "GOLD"
            cardColor = Draw.Color(255, 255, 215, 0)
        else
            cardText = cardText .. (self.isSelectingCard and "SELECTING..." or "NONE")
        end
        
        -- Add debug info about W spell name
        cardText = cardText .. " (" .. wSpellName .. ")"
        
        Draw.Text(cardText, 18, myPos:To2D().x - 50, myPos:To2D().y - 80, cardColor)
    end
    
    -- Draw Auto Harass Status (InfoBox)
    -- Get the current key from menu settings with error protection
    local currentKey = self.Menu.harass.autoHarass:Key()
    local keyText = "V" -- Default fallback
    
    -- Safe conversion of key code to character
    if currentKey and currentKey > 0 and currentKey <= 255 then
        local success, result = pcall(string.char, currentKey)
        if success and result then
            keyText = result:upper()
        end
    end
    
    -- Check if auto harass is active (key is being held down)
    local isAutoHarassActive = false
    if currentKey then
        isAutoHarassActive = Control.IsKeyDown(currentKey)
    end
    
    if isAutoHarassActive then
        local boxX = 50
        local boxY = 50
        local boxWidth = 220
        local boxHeight = 80
        
        -- Background box
        Draw.Rect(boxX - 5, boxY - 5, boxWidth + 10, boxHeight + 10, Draw.Color(150, 0, 0, 0))
        Draw.Rect(boxX, boxY, boxWidth, boxHeight, Draw.Color(100, 50, 150, 50))
        
        -- Title
        Draw.Text("AUTO HARASS Q", 16, boxX + 10, boxY + 5, Draw.Color(255, 0, 255, 0))
        
        -- Status with dynamic key display
        local statusText = "STATUS: ACTIVE (Hold " .. keyText .. ")"
        local statusColor = Draw.Color(255, 0, 255, 0)
        Draw.Text(statusText, 14, boxX + 10, boxY + 25, statusColor)
        
        -- Control info
        local controlText = "Hold: " .. keyText .. " key to activate"
        Draw.Text(controlText, 12, boxX + 10, boxY + 45, Draw.Color(255, 200, 200, 200))
        
        -- Mana info
        local manaPercent = math.floor(myHero.mana / myHero.maxMana * 100)
        local manaText = "MANA: " .. manaPercent .. "% (Min: " .. self.Menu.harass.manaThreshold:Value() .. "%)"
        local manaColor = manaPercent >= self.Menu.harass.manaThreshold:Value() and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 100, 100)
        Draw.Text(manaText, 12, boxX + 10, boxY + 62, manaColor)
    else
        local boxX = 50
        local boxY = 50
        local boxWidth = 220
        local boxHeight = 60
        
        -- Background box (darker for inactive)
        Draw.Rect(boxX - 5, boxY - 5, boxWidth + 10, boxHeight + 10, Draw.Color(150, 0, 0, 0))
        Draw.Rect(boxX, boxY, boxWidth, boxHeight, Draw.Color(100, 100, 50, 50))
        
        -- Title
        Draw.Text("AUTO HARASS Q", 16, boxX + 10, boxY + 5, Draw.Color(255, 150, 150, 150))
        
        -- Status
        local statusText = "STATUS: INACTIVE"
        local statusColor = Draw.Color(255, 255, 100, 100)
        Draw.Text(statusText, 14, boxX + 10, boxY + 25, statusColor)
        
        -- Control info
        local controlText = "Hold: " .. keyText .. " key to activate"
        Draw.Text(controlText, 12, boxX + 10, boxY + 42, Draw.Color(255, 150, 150, 150))
    end
    
    -- Draw Killable Enemies
    if self.Menu.drawing.killable:Value() then
        for i = 1, #Enemys do
            local enemy = Enemys[i]
            if IsValid(enemy) and enemy.visible then
                if self:IsKillable(enemy) then
                    Draw.Circle(enemy.pos, enemy.boundingRadius + 50, Draw.Color(150, 255, 0, 0))
                    Draw.Text("KILLABLE", 16, enemy.pos:To2D().x - 30, enemy.pos:To2D().y - 40, Draw.Color(255, 255, 0, 0))
                end
            end
        end
    end

end

function TwistedFate:Tick()
    if MyHeroNotReady() then return end
    
    -- Update enemy heroes list periodically
    if math.floor(GameTimer())%5==0 then
        Enemys = GetEnemyHeroes()
    end
    
    local Mode = self:GetMode()
    
    -- Update card selection state
    self:UpdateCardState()
    
    -- Auto Harass Q (independent of orbwalker mode)
    self:AutoHarass()
    
    -- Card picking logic (main card selection system)
    self:CardPick()
    
    -- Execute mode-specific logic
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

function TwistedFate:OnWndMsg(msg, wParam)
    -- WM_KEYDOWN = 0x0100, WM_XBUTTONDOWN = 0x020B
    if msg == 0x0100 or msg == 0x020B then
        -- Check if R key was pressed (R = 0x52)
        if wParam == 0x52 then -- R key
            -- Check if R is learned first
            if not IsSpellLearned(_R) then
                return
            end
            
            if Ready(_R) then
                self.rPressed = true -- Mark that R was pressed for priority selection
                self.rPressedTime = GameTimer() -- Use GameTimer for consistency
                -- Auto select gold card when R is pressed
                if IsSpellLearned(_W) and Ready(_W) and myHero:GetSpellData(_W).name == "PickACard" then
                    -- Force gold card selection when using R
                    self.toSelect = "GOLD"
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                elseif IsSpellLearned(_W) and Ready(_W) and myHero:GetSpellData(_W).name ~= "PickACard" then
                    -- If W is ready but not in card selection, activate it first
                    self.toSelect = "GOLD"
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                elseif self.currentCard == CARD_TYPES.NONE then
                    -- If W is not ready, prepare to select gold card when it becomes available
                    self.toSelect = "GOLD"
                end
            end
        -- Check if manual gold card key was pressed (U key = 0x55)
        elseif wParam == 0x55 then -- U key for manual gold card
            if IsSpellLearned(_W) then
                if Ready(_W) and myHero:GetSpellData(_W).name == "PickACard" then
                    -- If already in card selection, force gold card
                    self.toSelect = "GOLD"
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                elseif Ready(_W) and myHero:GetSpellData(_W).name ~= "PickACard" then
                    -- If W is ready but not in card selection, activate it and prepare gold card
                    self.toSelect = "GOLD"
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                else
                    -- If W is not ready, prepare to select gold card when it becomes available
                    self.toSelect = "GOLD"
                end
            end
        -- Check if manual red card key was pressed (I key = 0x49)
        elseif wParam == 0x49 then -- I key for manual red card
            if IsSpellLearned(_W) then
                if Ready(_W) and myHero:GetSpellData(_W).name == "PickACard" then
                    -- If already in card selection, force red card
                    self.toSelect = "RED"
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                elseif Ready(_W) and myHero:GetSpellData(_W).name ~= "PickACard" then
                    -- If W is ready but not in card selection, activate it and prepare red card
                    self.toSelect = "RED"
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                else
                    -- If W is not ready, prepare to select red card when it becomes available
                    self.toSelect = "RED"
                end
            end
        -- Check if MB4 was pressed (MB4 = 0x05)
        elseif wParam == 0x05 then -- MB4 (Mouse Button 4)
            local mb4Action = self.Menu.advanced.mb4Action:Value()
            if mb4Action ~= 4 and IsSpellLearned(_W) then -- Not disabled
                local cardType = "NONE"
                if mb4Action == 1 then cardType = "GOLD"
                elseif mb4Action == 2 then cardType = "RED"
                elseif mb4Action == 3 then cardType = "BLUE"
                end
                
                if Ready(_W) and myHero:GetSpellData(_W).name == "PickACard" then
                    -- If already in card selection, force selected card
                    self.toSelect = cardType
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                elseif Ready(_W) and myHero:GetSpellData(_W).name ~= "PickACard" then
                    -- If W is ready but not in card selection, activate it and prepare card
                    self.toSelect = cardType
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                else
                    -- If W is not ready, prepare to select card when it becomes available
                    self.toSelect = cardType
                end
            end
        -- Check if MB5 was pressed (MB5 = 0x06)
        elseif wParam == 0x06 then -- MB5 (Mouse Button 5)
            local mb5Action = self.Menu.advanced.mb5Action:Value()
            if mb5Action ~= 4 and IsSpellLearned(_W) then -- Not disabled
                local cardType = "NONE"
                if mb5Action == 1 then cardType = "GOLD"
                elseif mb5Action == 2 then cardType = "RED"
                elseif mb5Action == 3 then cardType = "BLUE"
                end
                
                if Ready(_W) and myHero:GetSpellData(_W).name == "PickACard" then
                    -- If already in card selection, force selected card
                    self.toSelect = cardType
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                elseif Ready(_W) and myHero:GetSpellData(_W).name ~= "PickACard" then
                    -- If W is ready but not in card selection, activate it and prepare card
                    self.toSelect = cardType
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                else
                    -- If W is not ready, prepare to select card when it becomes available
                    self.toSelect = cardType
                end
            end
        end
    end
    
    -- End of input handling
end

function TwistedFate:GetBuildType()
    local buildValue = self.Menu.build.buildType:Value()
    if buildValue == 1 then
        return BUILD_TYPES.AP
    elseif buildValue == 2 then
        return BUILD_TYPES.AD
    elseif buildValue == 3 then
        return BUILD_TYPES.HYBRID
    end
    return BUILD_TYPES.AD -- Default fallback
end

function TwistedFate:UpdateCardState()
    -- Get the current W spell name to determine card state
    local wSpellName = myHero:GetSpellData(_W).name
    local wToggleState = myHero:GetSpellData(_W).toggleState
    
    -- Check if we're currently in card selection (Pick A Card active)
    if wSpellName == "PickACard" then
        self.isSelectingCard = true
        if self.cardSelectStartTime == 0 then
            self.cardSelectStartTime = GameTimer()
            self.cardCycleIndex = 1
        end
        
        -- Determine current card based on time elapsed
        local timeElapsed = GameTimer() - self.cardSelectStartTime
        local cyclePosition = math.floor(timeElapsed / self.W.cycleTime) % 3 + 1
        self.currentCard = self.W.cardCycle[cyclePosition]
        
    elseif wSpellName == "BlueCardLock" then
        self.currentCard = CARD_TYPES.BLUE
        self.isSelectingCard = false
        self.cardSelectStartTime = 0
    elseif wSpellName == "RedCardLock" then
        self.currentCard = CARD_TYPES.RED
        self.isSelectingCard = false
        self.cardSelectStartTime = 0
    elseif wSpellName == "GoldCardLock" then
        self.currentCard = CARD_TYPES.GOLD
        self.isSelectingCard = false
        self.cardSelectStartTime = 0
    else
        -- No card selected or W not active
        self.currentCard = CARD_TYPES.NONE
        self.isSelectingCard = false
        self.cardSelectStartTime = 0
    end
    
    -- Reset if toggle state indicates card was used
    if wToggleState == 2 then
        self.currentCard = CARD_TYPES.NONE
        self.isSelectingCard = false
        self.cardSelectStartTime = 0
    end
end

function TwistedFate:GetMode()
    if _G.SDK and _G.SDK.Orbwalker then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or 
               _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then
            return "Clear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    end
    return "None"
end

function TwistedFate:CardPick()
    local Mode = self:GetMode()
    local WName = myHero:GetSpellData(_W).name
    local WStatus = myHero:GetSpellData(_W).toggleState

    -- Early exit if W is not learned
    if not IsSpellLearned(_W) then
        return
    end

    -- Reset toSelect if W was used
    if WStatus == 2 then
        self.toSelect = "NONE"
        self.rPressed = false -- Reset R flag when card is used
        self.rPressedTime = nil -- Clear timestamp
    end

    -- Reset R flag if too much time has passed (timeout after 3 seconds)
    if self.rPressed and self.rPressedTime and (GameTimer() - self.rPressedTime) > 3.0 then
        self.rPressed = false
        self.rPressedTime = nil
    end

    -- Reset R flag if R is not ready anymore (R was actually cast)
    if self.rPressed and not Ready(_R) then
        self.rPressed = false
        self.rPressedTime = nil
    end

    -- Priority: R key pressed - always select gold card
    if self.rPressed and IsSpellLearned(_R) and Ready(_W) and WName == "PickACard" and 
       GameTimer() - lastWCast > 0.5 then
        self.toSelect = "GOLD"
        Control.CastSpell(HK_W)
        lastWCast = GameTimer()
        return -- Exit early to prioritize R selection
    end

    if Mode == "Combo" then
        local target = self:GetHeroTarget(myHero.range + self.Menu.combo.comboRange:Value()) -- Use slider value for combo range
        if self.Menu.combo.useW:Value() and target then
            if Ready(_W) and WName == "PickACard" and GameTimer() - lastWCast > 0.5 then
                local manaPercent = myHero.mana / myHero.maxMana * 100
                local blueCardThreshold = self.Menu.advanced.blueCardManaThreshold:Value()
                
                -- Use blue card only if mana is below threshold, otherwise use gold card
                if manaPercent <= blueCardThreshold then
                    self.toSelect = "BLUE"
                else
                    self.toSelect = "GOLD"
                end
                
                if self.toSelect ~= "NONE" and Ready(_W) then
                    Control.CastSpell(HK_W)
                    lastWCast = GameTimer()
                end
            end
        end
    end

    if Mode == "Harass" then
        local target = self:GetHeroTarget(self.Q.range)
        if self.Menu.harass.useW:Value() and target then
            if Ready(_W) and WName == "PickACard" and GameTimer() - lastWCast > 0.5 then
                local manaPercent = myHero.mana / myHero.maxMana * 100
                if manaPercent >= self.Menu.harass.manaThreshold:Value() then
                    if self.Menu.harass.preferBlue:Value() and myHero.mana / myHero.maxMana < 0.6 then
                        self.toSelect = "BLUE"
                    elseif target.health / target.maxHealth < 0.4 then
                        self.toSelect = "GOLD"
                    else
                        self.toSelect = "BLUE"
                    end
                    if self.toSelect ~= "NONE" and Ready(_W) then
                        Control.CastSpell(HK_W)
                        lastWCast = GameTimer()
                    end
                end
            end
        end
    end

    if Mode == "Clear" then
        if self.Menu.clear.useW:Value() then
            if Ready(_W) and WName == "PickACard" and GetTickCount() > self.lastPick + 500 then
                for i = 1, Game.MinionCount() do
                    local target = Game.Minion(i)
                    if target and IsValid(target) and target.isEnemy then
                        if GetDistance(myHero.pos, target.pos) <= myHero.range + 150 then
                            local manaThreshold = self.Menu.clear.manaThreshold:Value() / 100
                            if self.Menu.clear.useWForMana:Value() and myHero.mana / myHero.maxMana < manaThreshold then
                                self.toSelect = "BLUE"
                            elseif myHero.mana / myHero.maxMana >= manaThreshold and self.Menu.clear.preferRed:Value() then
                                local minions = self:GetMinionsInRange(myHero.range + 150)
                                if #minions >= 2 then
                                    self.toSelect = "RED"
                                else
                                    self.toSelect = "BLUE"
                                end
                            else
                                self.toSelect = "BLUE"
                            end
                            if Ready(_W) and self.toSelect ~= "NONE" then
                                self:EnableOrb(false)
                                Control.CastSpell(HK_W)
                                self:EnableOrb(true)
                                self.lastPick = GetTickCount()
                            end
                            break -- Exit loop after finding first valid minion
                        end
                    end
                end
            end
        end
    end

    if Mode == "LastHit" then
        if self.Menu.lasthit.useW:Value() then
            local lastHitMinion = self:GetLastHitMinion()
            if Ready(_W) and WName == "PickACard" and lastHitMinion and GetTickCount() > self.lastPick + 500 then
                self.toSelect = "BLUE" -- Always blue for last hit (mana restoration)
                if Ready(_W) and self.toSelect ~= "NONE" then
                    self:EnableOrb(false)
                    Control.CastSpell(HK_W)
                    self:EnableOrb(true)
                    self.lastPick = GetTickCount()
                end
            end
        end
    end

    if Mode == "Flee" then
        local enemies = self:GetEnemiesInRange(800)
        if self.Menu.flee.useW:Value() and #enemies > 0 then
            if Ready(_W) and WName == "PickACard" and GetTickCount() > self.lastPick + 500 then
                self.toSelect = "GOLD" -- Gold card for stun to escape
                if Ready(_W) and self.toSelect ~= "NONE" then
                    self:EnableOrb(false)
                    Control.CastSpell(HK_W)
                    self:EnableOrb(true)
                    self.lastPick = GetTickCount()
                end
            end
        end
    end

    -- Special case: Gold card during R (Gate)
    if self:HasBuff(myHero, "Gate") then
        local nearbyEnemies = self:GetEnemiesInRange(1200)
        if #nearbyEnemies > 0 then
            if Ready(_W) and WName == "PickACard" and GetTickCount() > self.lastPick + 500 then
                self.toSelect = "GOLD"
                if Ready(_W) then
                    self:EnableOrb(false)
                    Control.CastSpell(HK_W)
                    self:EnableOrb(true)
                    self.lastPick = GetTickCount()
                end
            end
        end
    end

    -- Lock in the desired card when it appears
    if Ready(_W) then
        if (self.toSelect == "GOLD" and WName == "GoldCardLock") or
           (self.toSelect == "RED" and WName == "RedCardLock") or
           (self.toSelect == "BLUE" and WName == "BlueCardLock") then
            self:EnableOrb(false)
            Control.CastSpell(HK_W)
            self:EnableOrb(true)
            self.toSelect = "NONE"
        end
    end
end

function TwistedFate:EnableOrb(enabled)
    if _G.SDK and _G.SDK.Orbwalker then
        _G.SDK.Orbwalker:SetMovement(enabled)
        _G.SDK.Orbwalker:SetAttack(enabled)
    end
end

function TwistedFate:HasBuff(unit, buffName)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name:lower():find(buffName:lower()) then
            return true
        end
    end
    return false
end

function TwistedFate:GetDesiredCard()
    if _G.SDK and _G.SDK.Orbwalker then
        if _G.SDK.Orbwalker.Modes[0] then -- Combo
            return self:GetComboCard()
        elseif _G.SDK.Orbwalker.Modes[1] then -- Harass
            return self:GetHarassCard()
        elseif _G.SDK.Orbwalker.Modes[2] then -- Lane Clear
            return self:GetClearCard()
        elseif _G.SDK.Orbwalker.Modes[3] then -- Last Hit
            return self:GetLastHitCard()
        elseif _G.SDK.Orbwalker.Modes[4] then -- Flee
            return CARD_TYPES.GOLD
        end
    end
    
    return CARD_TYPES.BLUE -- Default to blue card
end

function TwistedFate:GetComboCard()
    local target = self:GetHeroTarget(800)
    if not target then return CARD_TYPES.BLUE end
    
    local manaPercent = myHero.mana / myHero.maxMana * 100
    local blueCardThreshold = self.Menu.advanced.blueCardManaThreshold:Value()
    
    -- Use blue card only if mana is below threshold, otherwise use gold card
    if manaPercent <= blueCardThreshold then
        return CARD_TYPES.BLUE -- Mana restoration when below threshold
    else
        return CARD_TYPES.GOLD -- Gold card when above threshold
    end
end

function TwistedFate:GetHarassCard()
    local target = self:GetHeroTarget(800)
    local manaPercent = myHero.mana / myHero.maxMana * 100
    local blueCardThreshold = self.Menu.advanced.blueCardManaThreshold:Value()
    
    -- Check mana threshold first
    if manaPercent < self.Menu.harass.manaThreshold:Value() then
        return CARD_TYPES.BLUE -- Need mana
    end
    
    -- Use blue card if below threshold or prefer blue is enabled and we're below 60%
    if manaPercent <= blueCardThreshold or (self.Menu.harass.preferBlue:Value() and manaPercent < 60) then
        return CARD_TYPES.BLUE
    end
    
    -- Gold card for low health targets
    if target and target.health / target.maxHealth < 0.4 then
        return CARD_TYPES.GOLD
    end
    
    return CARD_TYPES.BLUE -- Default for harass
end

function TwistedFate:GetClearCard()
    local minions = self:GetMinionsInRange(600)
    local manaPercent = myHero.mana / myHero.maxMana * 100
    
    -- Mana restoration priority when below threshold (consistent with CardPick logic)
    if self.Menu.clear.useWForMana:Value() and manaPercent < self.Menu.clear.manaThreshold:Value() then
        return CARD_TYPES.BLUE
    end
    
    -- Red card for multiple minions if we have enough mana
    if self.Menu.clear.preferRed:Value() and #minions >= 2 and manaPercent >= self.Menu.clear.manaThreshold:Value() then
        return CARD_TYPES.RED
    end
    
    return CARD_TYPES.BLUE -- Default for wave clear
end

function TwistedFate:GetLastHitCard()
    if self.Menu.lasthit.onlyBlueCard:Value() then
        return CARD_TYPES.BLUE
    end
    
    return CARD_TYPES.BLUE
end

function TwistedFate:Combo()
    local target = self:GetHeroTarget(self.Q.range)
    if not target then return end
    
    -- Q before W combo
    if self.Menu.combo.qBeforeW:Value() and self.Menu.combo.useQ:Value() and 
       IsSpellLearned(_Q) and Ready(_Q) and self.currentCard == CARD_TYPES.NONE then
        self:CastQ(target)
    end
    
    -- Use selected card
    if self.Menu.combo.useW:Value() and IsSpellLearned(_W) and self.currentCard ~= CARD_TYPES.NONE then
        self:UseSelectedCard(target)
    end
    
    -- Use Q after card or if no card combo
    if self.Menu.combo.useQ:Value() and IsSpellLearned(_Q) and Ready(_Q) and 
       (not self.Menu.combo.qBeforeW:Value() or self.currentCard ~= CARD_TYPES.NONE) then
        self:CastQ(target)
    end
end

function TwistedFate:Harass()
    local target = self:GetHeroTarget(self.Q.range)
    if not target then return end
    
    -- Check mana threshold
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.harass.manaThreshold:Value() then return end
    
    -- Use Q
    if self.Menu.harass.useQ:Value() and IsSpellLearned(_Q) and Ready(_Q) then
        self:CastQ(target)
    end
    
    -- Use selected card
    if self.Menu.harass.useW:Value() and IsSpellLearned(_W) and self.currentCard ~= CARD_TYPES.NONE then
        self:UseSelectedCard(target)
    end
end

function TwistedFate:Clear()
    -- Use Q for wave clear (only if mana is above 30%)
    if self.Menu.clear.useQ:Value() and IsSpellLearned(_Q) and Ready(_Q) then
        local manaPercent = myHero.mana / myHero.maxMana * 100
        if manaPercent >= 30 then -- Mana detector: don't use Q if mana below 30%
            local minions = self:GetMinionsInRange(self.Q.range)
            if #minions >= self.Menu.clear.minMinionsQ:Value() then
                -- Use the closest minion as target to properly use CastQ function
                local targetMinion = minions[1] -- Get first minion as target
                if targetMinion then
                    self:CastQ(targetMinion) -- Use proper CastQ function with cooldown checks
                end
            end
        end
    end
    
    -- Use selected card for wave clear
    if self.Menu.clear.useW:Value() and IsSpellLearned(_W) and self.currentCard ~= CARD_TYPES.NONE then
        local minion = self:GetBestMinionForCard()
        if minion then
            self:UseSelectedCard(minion)
        end
    end
end

function TwistedFate:LastHit()
    -- Use Q for last hit
    if self.Menu.lasthit.useQ:Value() and IsSpellLearned(_Q) and Ready(_Q) then
        local minion = self:GetLastHitMinionQ()
        if minion then
            self:CastQ(minion)
        end
    end
    
    -- Use selected card for last hit
    if self.Menu.lasthit.useW:Value() and IsSpellLearned(_W) and self.currentCard ~= CARD_TYPES.NONE then
        local minion = self:GetLastHitMinion()
        if minion and self:CanLastHitWithCard(minion) then
            self:UseSelectedCard(minion)
        end
    end
end

function TwistedFate:Flee()
    local enemies = self:GetEnemiesInRange(1200)
    if #enemies == 0 then return end
    
    -- Use Q to slow pursuers
    if self.Menu.flee.useQ:Value() and IsSpellLearned(_Q) and Ready(_Q) then
        local closestEnemy = self:GetClosestEnemy(enemies)
        if closestEnemy then
            self:CastQ(closestEnemy)
        end
    end
    
    -- Use Gold Card for stun
    if self.Menu.flee.useW:Value() and IsSpellLearned(_W) then
        if self.currentCard == CARD_TYPES.GOLD then
            local closestEnemy = self:GetClosestEnemy(enemies)
            if closestEnemy and GetDistance(myHero.pos, closestEnemy.pos) <= 600 then
                self:UseSelectedCard(closestEnemy)
            end
        end
    end
    
    -- Use R to escape if in danger
    if self.Menu.flee.useR:Value() and IsSpellLearned(_R) and Ready(_R) and 
       myHero.health / myHero.maxHealth < 0.3 then
        local safePos = self:GetSafeFleePosition()
        if safePos then
            Control.CastSpell(HK_R, safePos)
        end
    end
end

-- Spell casting functions
function TwistedFate:CastQ(target)
    -- Prevent spam with improved timing check
    if GameTimer() - lastQCast < 0.3 then -- Reduced from 0.5 to 0.3
        return false
    end
    
    -- Check if Q is learned first
    if not IsSpellLearned(_Q) then
        return false
    end
    
    -- Check if Q is ready using improved Ready function
    if not Ready(_Q) then
        return false
    end

    if not target or not IsValid(target) then 
        return false 
    end
    
    -- Check range
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > self.Q.range then
        return false
    end
    
    -- Use DepressivePrediction for better accuracy
    local prediction = self:GetQPrediction(target)
    if not prediction then 
        return false
    end
    
    -- Cast spell
    Control.CastSpell(HK_Q, prediction)
    lastQCast = GameTimer() -- Update global timer
    
    return true
end

function TwistedFate:GetQPrediction(target)
    if not target then return nil end
    
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > self.Q.range then return nil end
    
    -- Try to use DepressivePrediction if available
    if Prediction then
        -- Create spell data for DepressivePrediction
        local qSpell = Prediction.SpellPrediction({
            Type = 0, -- SPELLTYPE_LINE
            Speed = self.Q.speed,
            Range = self.Q.range,
            Delay = self.Q.delay,
            Radius = self.Q.width,
            Collision = self.Q.collision,
            CollisionTypes = {0}, -- COLLISION_MINION
            UseBoundingRadius = true
        })
        
        -- Get prediction
        local predictionResult = qSpell:GetPrediction(target, myHero.pos)
        
        -- Check hit chance
        if predictionResult.HitChance >= 3 then -- HITCHANCE_NORMAL or better
            -- Return the predicted cast position
            if predictionResult.CastPosition then
                return Vector(predictionResult.CastPosition.x, myHero.pos.y, predictionResult.CastPosition.z)
            end
        end
    end
    
    -- Fallback to basic prediction if DepressivePrediction fails or is not available
    if target.GetPrediction then
        local prediction = target:GetPrediction(self.Q.speed, self.Q.delay + Game.Latency())
        if prediction then
            local predictedDistance = GetDistance(myHero.pos, prediction)
            if predictedDistance <= self.Q.range then
                return prediction
            end
        end
    end
    
    -- Final fallback: current position
    return target.pos
end

function TwistedFate:FindQPositionAvoidingCollision(target, originalPrediction)
    -- Try positions slightly offset from the original prediction
    local offsets = {
        Vector(50, 0, 0),
        Vector(-50, 0, 0),
        Vector(0, 0, 50),
        Vector(0, 0, -50),
        Vector(35, 0, 35),
        Vector(-35, 0, -35),
        Vector(35, 0, -35),
        Vector(-35, 0, 35)
    }
    
    for i = 1, #offsets do
        local testPos = originalPrediction + offsets[i]
        local testDistance = GetDistance(myHero.pos, testPos)
        
        if testDistance <= self.Q.range then
            -- Create a temporary target at this position to test collision
            local collision = target:GetCollision(self.Q.width, self.Q.speed, self.Q.delay)
            if collision == 0 then
                return testPos
            end
        end
    end
    
    return nil -- No valid position found
end

function TwistedFate:UseSelectedCard(target)
    if not target or self.currentCard == CARD_TYPES.NONE then return false end
    
    local wSpellName = myHero:GetSpellData(_W).name
    local distance = GetDistance(myHero.pos, target.pos)
    
    -- Check if we have a card ready to use
    if wSpellName == "BlueCardLock" or wSpellName == "RedCardLock" or wSpellName == "GoldCardLock" then
        -- For champions, use normal attack range + some buffer
        if target.type == Obj_AI_Hero then
            if distance <= 600 then -- Slightly longer than normal attack range
                if _G.SDK and _G.SDK.Orbwalker then
                    _G.SDK.Orbwalker:Attack(target)
                else
                    Control.Attack(target)
                end
                return true
            end
        else
            -- For minions, use normal attack range
            if distance <= myHero.range + 100 then
                if _G.SDK and _G.SDK.Orbwalker then
                    _G.SDK.Orbwalker:Attack(target)
                else
                    Control.Attack(target)
                end
                return true
            end
        end
    end
    
    return false
end

-- Utility functions
function TwistedFate:GetHeroTarget(range)
    local bestTarget = nil
    local bestPriority = 0
    
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if IsValid(enemy) and enemy.visible then
            local distance = GetDistance(myHero.pos, enemy.pos)
            if distance <= range then
                local priority = self:GetTargetPriority(enemy)
                if priority > bestPriority then
                    bestPriority = priority
                    bestTarget = enemy
                end
            end
        end
    end
    
    return bestTarget
end

function TwistedFate:AutoHarass()
    -- Check if auto harass key is being held down
    local currentKey = self.Menu.harass.autoHarass:Key()
    if not currentKey or not Control.IsKeyDown(currentKey) then
        return
    end
    
    -- Same logic as Harass() function but activated by key
    local target = self:GetHeroTarget(self.Q.range)
    if not target then return end
    
    -- Check mana threshold (use harass mana threshold)
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.harass.manaThreshold:Value() then return end
    
    -- Cooldown between auto harass casts (prevent spam)
    if GameTimer() - self.lastAutoHarass < 0.5 then
        return
    end
    
    -- Use Q (same as harass)
    if self.Menu.harass.useQ:Value() and IsSpellLearned(_Q) and Ready(_Q) then
        if self:CastQ(target) then
            self.lastAutoHarass = GameTimer()
        end
    end
    
    -- Use selected card (same as harass)
    if self.Menu.harass.useW:Value() and IsSpellLearned(_W) and self.currentCard ~= CARD_TYPES.NONE then
        if self:UseSelectedCard(target) then
            self.lastAutoHarass = GameTimer()
        end
    end
end

function TwistedFate:GetTargetPriority(enemy)
    local priority = 0
    
    -- Base priority by champion type
    if enemy.charName:find("ADC") or enemy.charName:find("Carry") then
        priority = priority + 5
    elseif enemy.charName:find("Support") then
        priority = priority + 2
    else
        priority = priority + 3
    end
    
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
    
    return priority
end

function TwistedFate:IsKillable(target)
    if not target then return false end
    
    local totalDamage = 0
    
    -- Q damage
    if IsSpellLearned(_Q) and Ready(_Q) then
        totalDamage = totalDamage + self:GetQDamage(target)
    end
    
    -- W damage (based on current/selected card)
    if IsSpellLearned(_W) and (self.currentCard ~= CARD_TYPES.NONE) then
        totalDamage = totalDamage + self:GetWDamage(target)
    end
    
    -- Auto attack damage
    totalDamage = totalDamage + self:GetAADamage(target)
    
    return target.health <= totalDamage * 0.9 -- 90% certainty factor
end

function TwistedFate:GetQDamage(target)
    if not target then return 0 end
    
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end
    
    local baseDamage = {60, 105, 150, 195, 240}
    local apRatio = 0.65
    local adRatio = 1.0
    
    local damage = baseDamage[level]
    local buildType = self:GetBuildType()
    
    if buildType == BUILD_TYPES.AP or buildType == BUILD_TYPES.HYBRID then
        damage = damage + myHero.ap * apRatio
    end
    
    if buildType == BUILD_TYPES.AD or buildType == BUILD_TYPES.HYBRID then
        damage = damage + (myHero.totalDamage - myHero.baseDamage) * adRatio
    end
    
    -- Calculate magic resistance reduction
    local magicResist = target.magicResist
    local reduction = magicResist / (magicResist + 100)
    
    return damage * (1 - reduction)
end

function TwistedFate:GetWDamage(target)
    if not target then return 0 end
    
    local level = myHero:GetSpellData(_W).level
    if level == 0 then return 0 end
    
    local baseDamage = {40, 60, 80, 100, 120}
    local apRatio = 1.0
    local adRatio = 1.0
    
    local damage = baseDamage[level]
    
    -- Card-specific bonuses
    if self.currentCard == CARD_TYPES.BLUE then
        damage = damage -- Blue card has no extra damage, but restores mana
    elseif self.currentCard == CARD_TYPES.RED then
        damage = damage -- Red card has same damage but AOE
    elseif self.currentCard == CARD_TYPES.GOLD then
        damage = damage + 15 -- Gold card has slight bonus damage plus stun
    end
    
    local buildType = self:GetBuildType()
    
    if buildType == BUILD_TYPES.AP or buildType == BUILD_TYPES.HYBRID then
        damage = damage + myHero.ap * apRatio
    end
    
    if buildType == BUILD_TYPES.AD or buildType == BUILD_TYPES.HYBRID then
        damage = damage + (myHero.totalDamage - myHero.baseDamage) * adRatio
    end
    
    -- W damage is magic damage
    local magicResist = target.magicResist
    local reduction = magicResist / (magicResist + 100)
    
    return damage * (1 - reduction)
end

function TwistedFate:GetAADamage(target)
    if not target then return 0 end
    
    local damage = myHero.totalDamage
    
    -- Calculate armor reduction
    local armor = target.armor
    local reduction = armor / (armor + 100)
    
    return damage * (1 - reduction)
end

-- Minion and positioning functions
function TwistedFate:GetMinionsInRange(range)
    local minions = {}
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and IsValid(minion) and minion.isEnemy then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= range then
                TableInsert(minions, minion)
            end
        end
    end
    
    return minions
end

function TwistedFate:GetEnemiesInRange(range)
    local enemies = {}
    
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if IsValid(enemy) and enemy.visible then
            local distance = GetDistance(myHero.pos, enemy.pos)
            if distance <= range then
                TableInsert(enemies, enemy)
            end
        end
    end
    
    return enemies
end

function TwistedFate:GetLastHitMinion()
    local minions = self:GetMinionsInRange(myHero.range + 100)
    local bestMinion = nil
    
    for i = 1, #minions do
        local minion = minions[i]
        local damage = self:GetAADamage(minion)
        
        if minion.health <= damage and minion.health > damage * 0.7 then
            if not bestMinion or minion.health > bestMinion.health then
                bestMinion = minion
            end
        end
    end
    
    return bestMinion
end

function TwistedFate:GetLastHitMinionQ()
    local minions = self:GetMinionsInRange(self.Q.range)
    local bestMinion = nil
    
    for i = 1, #minions do
        local minion = minions[i]
        local damage = self:GetQDamage(minion)
        
        if minion.health <= damage and minion.health > damage * 0.7 then
            if not bestMinion or minion.health > bestMinion.health then
                bestMinion = minion
            end
        end
    end
    
    return bestMinion
end

function TwistedFate:CanLastHitWithCard(minion)
    if not minion then return false end
    
    local damage = self:GetWDamage(minion) + self:GetAADamage(minion)
    return minion.health <= damage and minion.health > damage * 0.7
end

function TwistedFate:GetBestMinionForCard()
    local minions = self:GetMinionsInRange(myHero.range + 100)
    if #minions == 0 then return nil end
    
    -- For red card, prefer position that hits multiple minions
    if self.currentCard == CARD_TYPES.RED then
        return self:GetBestRedCardMinion(minions)
    end
    
    -- For other cards, just get closest minion
    local closestMinion = nil
    local closestDistance = math.huge
    
    for i = 1, #minions do
        local minion = minions[i]
        local distance = GetDistance(myHero.pos, minion.pos)
        if distance < closestDistance then
            closestDistance = distance
            closestMinion = minion
        end
    end
    
    return closestMinion
end

function TwistedFate:GetBestRedCardMinion(minions)
    local bestMinion = nil
    local bestCount = 0
    
    for i = 1, #minions do
        local minion = minions[i]
        local count = self:CountMinionsInRadius(minion.pos, 200) -- Red card AOE radius
        
        if count > bestCount then
            bestCount = count
            bestMinion = minion
        end
    end
    
    return bestMinion or minions[1]
end

function TwistedFate:CountMinionsInRadius(pos, radius)
    local count = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and IsValid(minion) and minion.isEnemy then
            local distance = GetDistance(pos, minion.pos)
            if distance <= radius then
                count = count + 1
            end
        end
    end
    
    return count
end

function TwistedFate:GetBestQPositionForMinions(minions)
    if #minions == 0 then return nil end
    
    -- Find position that hits the most minions
    local bestPos = nil
    local bestCount = 0
    
    for i = 1, #minions do
        local minion = minions[i]
        local count = 0
        
        -- Count how many minions would be hit if we target this position
        for j = 1, #minions do
            local otherMinion = minions[j]
            local distance = GetDistance(minion.pos, otherMinion.pos)
            if distance <= self.Q.width then
                count = count + 1
            end
        end
        
        if count > bestCount then
            bestCount = count
            bestPos = minion.pos
        end
    end
    
    return bestPos
end

function TwistedFate:GetClosestEnemy(enemies)
    if #enemies == 0 then return nil end
    
    local closest = nil
    local closestDistance = math.huge
    
    for i = 1, #enemies do
        local enemy = enemies[i]
        local distance = GetDistance(myHero.pos, enemy.pos)
        if distance < closestDistance then
            closestDistance = distance
            closest = enemy
        end
    end
    
    return closest
end

function TwistedFate:ShouldEngage(target)
    if not target then return false end
    
    -- Simple engagement logic - can be expanded
    local myHealthPercent = myHero.health / myHero.maxHealth
    local targetHealthPercent = target.health / target.maxHealth
    
    -- Engage if we have health advantage or target is low
    return myHealthPercent > 0.4 and (myHealthPercent > targetHealthPercent or targetHealthPercent < 0.5)
end

function TwistedFate:GetSafeFleePosition()
    -- Simple flee position calculation - move towards base/tower
    local myPos = myHero.pos
    local basePos = Vector(400, 185, 400) -- Approximate base position (needs adjustment per map)
    
    local direction = (basePos - myPos):Normalized()
    local fleePos = myPos + direction * 1200
    
    return fleePos
end

function TwistedFate:GetRRange()
    if not IsSpellLearned(_R) then return 0 end
    
    local level = myHero:GetSpellData(_R).level
    if level == 0 then return 0 end
    
    -- R Range by level: 5500 at all levels (global)
    return 5500
end

-- Initialize
DelayAction(function()
    -- Wait for DepressivePrediction to be fully loaded
    if not _G.DepressivePrediction then
        print("Waiting for DepressivePrediction to load...")
        DelayAction(function()
            if _G.DepressivePrediction then
        _G.TwistedFate = TwistedFate()
        _G.DepressiveAIONextLoadedChampion = true
                print("Twisted Fate loaded successfully with DepressivePrediction!")
            else
                print("ERROR: DepressivePrediction failed to load, loading Twisted Fate anyway...")
        _G.TwistedFate = TwistedFate()
        _G.DepressiveAIONextLoadedChampion = true
            end
        end, 1.0)
    else
    _G.TwistedFate = TwistedFate()
    _G.DepressiveAIONextLoadedChampion = true
        print("Twisted Fate loaded successfully with DepressivePrediction!")
    end
end, math.max(0.07, 5 - Game.Timer()))
