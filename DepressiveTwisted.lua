local Heroes = {"TwistedFate"}

-- Hero validation
if not table.contains(Heroes, myHero.charName) then return end

-- Constants and globals
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local TableInsert = table.insert

local lastMove = 0
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
    if not p1 or not p2 then return math.huge end
    return math.sqrt(GetDistanceSqr(p1, p2))
end

local function IsValid(unit)
    if not unit then return false end
    return unit.valid and unit.isTargetable and unit.alive and unit.visible and not unit.dead and unit.health > 0
end

local function Ready(spell)
    local spellState = Game.CanUseSpell(spell)
    return spellState == READY
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

-- Twisted Fate Class
class "TwistedFate"

function TwistedFate:__init()
    -- Spell data
    self.Q = {
        range = 1450,
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
        range = 5500, -- Global range
        delay = 1.5,
        type = "global"
    }
    
    -- State tracking
    self.currentCard = CARD_TYPES.NONE
    self.cardSelectStartTime = 0
    self.cardCycleIndex = 1
    self.isSelectingCard = false
    self.lastWCast = 0
    self.lastPick = 0
    self.toSelect = "NONE"
    self.rPressed = false -- Track if R was pressed for priority gold card selection
    self.rPressedTime = nil -- Track when R was pressed for timeout
    
    -- Load units
    OnAllyHeroLoad(function(hero) TableInsert(Allys, hero) end)
    OnEnemyHeroLoad(function(hero) TableInsert(Enemys, hero) end)
    
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
    self.Menu.combo:MenuElement({id = "useIgnite", name = "Use Ignite", value = true})
    self.Menu.combo:MenuElement({id = "qBeforeW", name = "Q before W combo", value = true})
    self.Menu.combo:MenuElement({id = "prioritizeGold", name = "Prioritize Gold Card", value = true})
    self.Menu.combo:MenuElement({id = "onlyGoldIfKillable", name = "Gold only if killable", value = false})
    
    -- Harass
    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.harass:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.harass:MenuElement({id = "preferBlue", name = "Prefer Blue Card", value = true})
    self.Menu.harass:MenuElement({id = "manaThreshold", name = "Min Mana %", value = 40, min = 0, max = 100, step = 5})
    
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
    
    -- Draw R Range
    if self.Menu.drawing.R:Value() and Ready(_R) then
        Draw.Circle(myPos, 1500, Draw.Color(80, 255, 20, 147)) -- Visual range, not actual
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
    if myHero.dead or Game.IsChatOpen() then
        return
    end
    
    -- Check for evade systems
    if (_G.JustEvade and _G.JustEvade:Evading()) or 
       (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or
       (_G.Evade and _G.Evade.Evading) then
        return
    end
    
    -- Update card selection state
    self:UpdateCardState()
    
    -- Card picking logic (main card selection system)
    self:CardPick()
    
    -- Orbwalker integration
    if _G.SDK and _G.SDK.Orbwalker then
        if _G.SDK.Orbwalker.Modes[0] then -- Combo
            self:Combo()
        elseif _G.SDK.Orbwalker.Modes[1] then -- Harass
            self:Harass()
        elseif _G.SDK.Orbwalker.Modes[2] then -- Lane Clear
            self:Clear()
        elseif _G.SDK.Orbwalker.Modes[3] then -- Last Hit
            self:LastHit()
        elseif _G.SDK.Orbwalker.Modes[4] then -- Flee
            self:Flee()
        end
    end
end

function TwistedFate:OnWndMsg(msg, wParam)
    -- WM_KEYDOWN = 0x0100
    if msg == 0x0100 then
        -- Check if R key was pressed (R = 0x52)
        if wParam == 0x52 then -- R key
            if Ready(_R) then
                self.rPressed = true -- Mark that R was pressed for priority selection
                self.rPressedTime = GetTickCount() -- Add timestamp for timeout
                -- Auto select gold card when R is pressed
                if Ready(_W) and myHero:GetSpellData(_W).name == "PickACard" then
                    -- Force gold card selection when using R
                    self.toSelect = "GOLD"
                    self:EnableOrb(false)
                    Control.CastSpell(HK_W)
                    self:EnableOrb(true)
                    self.lastPick = GetTickCount()
                elseif Ready(_W) and myHero:GetSpellData(_W).name ~= "PickACard" then
                    -- If W is ready but not in card selection, activate it first
                    self.toSelect = "GOLD"
                    self:EnableOrb(false)
                    Control.CastSpell(HK_W)
                    self:EnableOrb(true)
                    self.lastPick = GetTickCount()
                elseif not Ready(_W) and self.currentCard == CARD_TYPES.NONE then
                    -- If W is not ready, prepare to select gold card when it becomes available
                    self.toSelect = "GOLD"
                end
            end
        end
    end
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
            self.cardSelectStartTime = GetTickCount()
            self.cardCycleIndex = 1
        end
        
        -- Determine current card based on time elapsed
        local timeElapsed = (GetTickCount() - self.cardSelectStartTime) / 1000
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
        if _G.SDK.Orbwalker.Modes[0] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[1] then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[2] then
            return "Clear"
        elseif _G.SDK.Orbwalker.Modes[3] then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[4] then
            return "Flee"
        end
    end
    return "None"
end

function TwistedFate:CardPick()
    local Mode = self:GetMode()
    local WName = myHero:GetSpellData(_W).name
    local WStatus = myHero:GetSpellData(_W).toggleState

    -- Reset toSelect if W was used
    if WStatus == 2 then
        self.toSelect = "NONE"
        self.rPressed = false -- Reset R flag when card is used
        self.rPressedTime = nil -- Clear timestamp
    end

    -- Reset R flag if too much time has passed (timeout after 3 seconds)
    if self.rPressed and self.rPressedTime and (GetTickCount() - self.rPressedTime) > 3000 then
        self.rPressed = false
        self.rPressedTime = nil
    end

    -- Reset R flag if R is not ready anymore (R was actually cast)
    if self.rPressed and not Ready(_R) then
        self.rPressed = false
        self.rPressedTime = nil
    end

    -- Priority: R key pressed - always select gold card
    if self.rPressed and Ready(_W) and WName == "PickACard" and GetTickCount() > self.lastPick + 500 then
        self.toSelect = "GOLD"
        if Ready(_W) and self.toSelect ~= "NONE" then
            self:EnableOrb(false)
            Control.CastSpell(HK_W)
            self:EnableOrb(true)
            self.lastPick = GetTickCount()
        end
        return -- Exit early to prioritize R selection
    end

    if Mode == "Combo" then
        local target = self:GetHeroTarget(myHero.range + 300)
        if self.Menu.combo.useW:Value() then
            if Ready(_W) and WName == "PickACard" and target and GetTickCount() > self.lastPick + 500 then
                local manaPercent = myHero.mana / myHero.maxMana * 100
                if manaPercent >= 30 then -- Always gold card if mana above 30%
                    self.toSelect = "GOLD"
                else
                    self.toSelect = "BLUE"
                end
                if self.toSelect ~= "NONE" and Ready(_W) then
                    self:EnableOrb(false)
                    Control.CastSpell(HK_W)
                    self:EnableOrb(true)
                    self.lastPick = GetTickCount()
                end
            end
        end
    end

    if Mode == "Harass" then
        local target = self:GetHeroTarget(self.Q.range)
        if self.Menu.harass.useW:Value() then
            if Ready(_W) and WName == "PickACard" and target and GetTickCount() > self.lastPick + 500 then
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
                        self:EnableOrb(false)
                        Control.CastSpell(HK_W)
                        self:EnableOrb(true)
                        self.lastPick = GetTickCount()
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
                self:EnableOrb(false)
                Control.CastSpell(HK_W)
                self:EnableOrb(true)
                self.lastPick = GetTickCount()
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
        if enabled then
            _G.SDK.Orbwalker:SetMovement(true)
            _G.SDK.Orbwalker:SetAttack(true)
        else
            _G.SDK.Orbwalker:SetMovement(false)
            _G.SDK.Orbwalker:SetAttack(false)
        end
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
    
    -- New logic: Always gold card if mana above 30%
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent >= 30 then
        return CARD_TYPES.GOLD
    else
        return CARD_TYPES.BLUE -- Mana restoration when low
    end
end

function TwistedFate:GetHarassCard()
    local target = self:GetHeroTarget(800)
    local manaPercent = myHero.mana / myHero.maxMana * 100
    
    -- Check mana threshold first
    if manaPercent < self.Menu.harass.manaThreshold:Value() then
        return CARD_TYPES.BLUE -- Need mana
    end
    
    -- Prefer blue card for mana sustain
    if self.Menu.harass.preferBlue:Value() and manaPercent < 60 then
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
    if self.Menu.combo.qBeforeW:Value() and self.Menu.combo.useQ:Value() and Ready(_Q) and 
       self.currentCard == CARD_TYPES.NONE then
        self:CastQ(target)
    end
    
    -- Use selected card
    if self.Menu.combo.useW:Value() and self.currentCard ~= CARD_TYPES.NONE then
        self:UseSelectedCard(target)
    end
    
    -- Use Q after card or if no card combo
    if self.Menu.combo.useQ:Value() and Ready(_Q) and 
       (not self.Menu.combo.qBeforeW:Value() or self.currentCard ~= CARD_TYPES.NONE) then
        self:CastQ(target)
    end
    
    -- Use Ignite
    if self.Menu.combo.useIgnite:Value() then
        self:UseIgnite(target)
    end
end

function TwistedFate:Harass()
    local target = self:GetHeroTarget(self.Q.range)
    if not target then return end
    
    -- Check mana threshold
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.harass.manaThreshold:Value() then return end
    
    -- Use Q
    if self.Menu.harass.useQ:Value() and Ready(_Q) then
        self:CastQ(target)
    end
    
    -- Use selected card
    if self.Menu.harass.useW:Value() and self.currentCard ~= CARD_TYPES.NONE then
        self:UseSelectedCard(target)
    end
end

function TwistedFate:Clear()
    -- Use Q for wave clear (only if mana is above 30%)
    if self.Menu.clear.useQ:Value() and Ready(_Q) then
        local manaPercent = myHero.mana / myHero.maxMana * 100
        if manaPercent >= 30 then -- Mana detector: don't use Q if mana below 30%
            local minions = self:GetMinionsInRange(self.Q.range)
            if #minions >= self.Menu.clear.minMinionsQ:Value() then
                local bestPos = self:GetBestQPositionForMinions(minions)
                if bestPos then
                    Control.CastSpell(HK_Q, bestPos)
                end
            end
        end
    end
    
    -- Use selected card for wave clear
    if self.Menu.clear.useW:Value() and self.currentCard ~= CARD_TYPES.NONE then
        local minion = self:GetBestMinionForCard()
        if minion then
            self:UseSelectedCard(minion)
        end
    end
end

function TwistedFate:LastHit()
    -- Use Q for last hit
    if self.Menu.lasthit.useQ:Value() and Ready(_Q) then
        local minion = self:GetLastHitMinionQ()
        if minion then
            self:CastQ(minion)
        end
    end
    
    -- Use selected card for last hit
    if self.Menu.lasthit.useW:Value() and self.currentCard ~= CARD_TYPES.NONE then
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
    if self.Menu.flee.useQ:Value() and Ready(_Q) then
        local closestEnemy = self:GetClosestEnemy(enemies)
        if closestEnemy then
            self:CastQ(closestEnemy)
        end
    end
    
    -- Use Gold Card for stun
    if self.Menu.flee.useW:Value() then
        if self.currentCard == CARD_TYPES.GOLD then
            local closestEnemy = self:GetClosestEnemy(enemies)
            if closestEnemy and GetDistance(myHero.pos, closestEnemy.pos) <= 600 then
                self:UseSelectedCard(closestEnemy)
            end
        end
    end
    
    -- Use R to escape if in danger
    if self.Menu.flee.useR:Value() and Ready(_R) and myHero.health / myHero.maxHealth < 0.3 then
        local safePos = self:GetSafeFleePosition()
        if safePos then
            Control.CastSpell(HK_R, safePos)
        end
    end
end

-- Spell casting functions
function TwistedFate:CastQ(target)
    if not Ready(_Q) or not target then return false end
    
    local prediction = self:GetQPrediction(target)
    if prediction then
        Control.CastSpell(HK_Q, prediction)
        return true
    end
    
    return false
end

function TwistedFate:GetQPrediction(target)
    if not target then return nil end
    
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > self.Q.range then return nil end
    
    -- Use GoS prediction
    local prediction = target:GetPrediction(self.Q.speed, self.Q.delay + Game.Latency())
    if not prediction then return nil end
    
    local predictedDistance = GetDistance(myHero.pos, prediction)
    if predictedDistance > self.Q.range then return nil end
    
    -- Check collision with minions
    if self.Q.collision then
        local collision = target:GetCollision(self.Q.width, self.Q.speed, self.Q.delay)
        if collision > 0 then
            -- Try to find position that avoids collision
            return self:FindQPositionAvoidingCollision(target, prediction)
        end
    end
    
    return prediction
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

function TwistedFate:UseIgnite(target)
    if not target then return false end
    
    local igniteSlot = self:GetIgniteSlot()
    if not igniteSlot or not Ready(igniteSlot) then return false end
    
    local distance = GetDistance(myHero.pos, target.pos)
    if distance > 600 then return false end
    
    local igniteDamage = self:GetIgniteDamage(target)
    if target.health <= igniteDamage then
        Control.CastSpell(igniteSlot, target)
        return true
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
    if Ready(_Q) then
        totalDamage = totalDamage + self:GetQDamage(target)
    end
    
    -- W damage (based on current/selected card)
    if self.currentCard ~= CARD_TYPES.NONE or Ready(_W) then
        totalDamage = totalDamage + self:GetWDamage(target)
    end
    
    -- Auto attack damage
    totalDamage = totalDamage + self:GetAADamage(target)
    
    -- Ignite damage
    if self:GetIgniteSlot() and Ready(self:GetIgniteSlot()) then
        totalDamage = totalDamage + self:GetIgniteDamage(target)
    end
    
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

function TwistedFate:GetIgniteDamage(target)
    if not target then return 0 end
    
    local level = myHero.levelData.lvl
    local baseDamage = 70 + 5 * level
    
    return baseDamage
end

function TwistedFate:GetIgniteSlot()
    local igniteID = 14 -- Ignite summoner spell ID
    
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" then
        return SUMMONER_1
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" then
        return SUMMONER_2
    end
    
    return nil
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

-- Initialize
DelayAction(function()
    _G.TwistedFate = TwistedFate()
end, math.max(0.07, 5 - Game.Timer()))
