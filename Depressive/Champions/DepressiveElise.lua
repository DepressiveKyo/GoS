local Elise = { __version = 1.17 }
local scriptVersion = Elise.__version -- Loader version detector (keep within top ~50 lines)

if myHero.charName ~= "Elise" then return Elise end

-- Core lib
local DepressiveLib = _G.DepressiveLib or require("Depressive/DepressiveLib") or require("Common/Depressive/DepressiveLib")
if not DepressiveLib then
    print("[DepressiveElise] DepressiveLib missing - abort")
    return Elise
end

-- Optional prediction (soft load)
pcall(function() if not _G.DepressivePrediction then require("Depressive/Utility/DepressivePrediction") end end)
local DP = _G.DepressivePrediction

-- Shortcuts (only stable ones from Lib)
local Ready     = DepressiveLib.Ready
local IsValid   = DepressiveLib.IsValid
local GetMode   = DepressiveLib.GetMode
local GetTarget = function(r) return DepressiveLib.GetTarget(r, "AP") end
local PercentMP = DepressiveLib.PercentMP or function(hero) return hero.mana/hero.maxMana*100 end
local CastFast  = DepressiveLib.CastSpellFast or function(k, posOrUnit) if type(posOrUnit)=="table" and posOrUnit.pos then Control.CastSpell(k, posOrUnit.pos) elseif type(posOrUnit)=="userdata" and posOrUnit.pos then Control.CastSpell(k, posOrUnit.pos) elseif posOrUnit and posOrUnit.x then Control.CastSpell(k, posOrUnit) else Control.CastSpell(k) end end
local HasBuff   = DepressiveLib.HasBuff

local _Q,_W,_E,_R = 0,1,2,3

-- Human form spell data (approx)
local HQ = {range=625}
local HW = {range=950, radius=210, delay=0.25, speed=math.huge}
local HE = {range=1075, width=55, delay=0.25, speed=1600}
-- Spider form
local SQ = {range=475}
local SW = {range=0}
local SE = {range=750}

-- Simple state
local Menu

-- Prediction wrappers (hitchance >=2)
local function PredictLinear(target, data)
    if not IsValid(target) then return nil end
    if DP and DP.GetPrediction then
        local predData = {speed = data.speed, delay = data.delay, range = data.range, radius = data.width or data.radius or 60, collision = true, type = "linear", collisionTypes = {"minion"}}
        local res = DP:GetPrediction(target, predData)
        if res and res.castPos and res.hitChance and res.hitChance >= 2 then return res.castPos end
    end
    return target.pos
end
local function PredictCircular(target, data)
    if not IsValid(target) then return nil end
    if DP and DP.GetPrediction then
        local predData = {speed = data.speed or math.huge, delay = data.delay, range = data.range, radius = data.radius or 200, collision = false, type = "circular"}
        local res = DP:GetPrediction(target, predData)
        if res and res.castPos and res.hitChance and res.hitChance >= 2 then return res.castPos end
    end
    return target.pos
end

local function InSpider()
    return (HasBuff and HasBuff(myHero, "EliseR")) or (myHero:GetSpellData(_Q).name:lower():find("spider") ~= nil)
end

-- Cast helpers
local function CastHumanQ(target)
    if not Ready(_Q) or not target or not IsValid(target) or target.distance > HQ.range+50 then return end
    CastFast(HK_Q, target)
end
local function CastHumanW(target)
    if not Ready(_W) or not target or not IsValid(target) or target.distance > HW.range+75 then return end
    local pos = PredictCircular(target, HW)
    if pos and myHero.pos:DistanceTo(pos) <= HW.range+25 then CastFast(HK_W, pos, true, HW.range+40) end
end
local function CastHumanE(target)
    if not Ready(_E) or not target or not IsValid(target) or target.distance > HE.range+75 then return end
    local pos = PredictLinear(target, HE)
    if pos and myHero.pos:DistanceTo(pos) <= HE.range+25 then CastFast(HK_E, pos, true, HE.range+40) end
end
local function CastSpiderQ(target)
    if not Ready(_Q) or not target or not IsValid(target) or target.distance > SQ.range+35 then return end
    CastFast(HK_Q, target)
end
local function CastSpiderW()
    if not Ready(_W) then return end
    CastFast(HK_W)
end
local function CastR()
    if not Ready(_R) then return end
    CastFast(HK_R)
end

-- Modes
local function Combo()
    local t = GetTarget(1075)
    if not t then return end
    if not InSpider() then
        if Menu.combo.useE:Value() then CastHumanE(t) end
        if Menu.combo.useQ:Value() then CastHumanQ(t) end
        if Menu.combo.useW:Value() then CastHumanW(t) end
        if Menu.combo.useR:Value() and Ready(_R) and (not Ready(_Q) and not Ready(_W) and not Ready(_E)) then CastR() end
    else
        if Menu.combo.useQ:Value() then CastSpiderQ(t) end
        if Menu.combo.useW:Value() then CastSpiderW() end
        if Menu.combo.useR:Value() and Ready(_R) and (not Ready(_Q) and not Ready(_W)) then CastR() end
    end
end
local function Harass()
    if PercentMP(myHero) < Menu.harass.mana:Value() then return end
    local t = GetTarget(900)
    if not t then return end
    if not InSpider() then
        if Menu.harass.useQ:Value() then CastHumanQ(t) end
        if Menu.harass.useW:Value() then CastHumanW(t) end
        if Menu.harass.useE:Value() then CastHumanE(t) end
    end
end
local function LaneClear()
    if PercentMP(myHero) < Menu.clear.mana:Value() then return end
    if not InSpider() then
        if Menu.clear.useW:Value() and Ready(_W) then
            local pos, hit = DepressiveLib.GetBestCircularFarmPos and DepressiveLib.GetBestCircularFarmPos(HW.range, HW.radius) or (DepressiveLib.GetBestLinearFarmPos and DepressiveLib.GetBestLinearFarmPos(HW.range, HW.radius))
            if pos and hit and hit >= Menu.clear.wMin:Value() then CastFast(HK_W, pos, true, HW.range+40) end
        end
        if Menu.clear.useQ:Value() and Ready(_Q) then
            DepressiveLib.ForEachMinion(function(m)
                if m.isEnemy and IsValid(m) and m.distance < HQ.range and m.health < m.maxHealth*0.45 then CastFast(HK_Q, m) end
            end)
        end
        if Menu.clear.useR:Value() and Ready(_R) and (not Ready(_Q) and not Ready(_W)) then CastR() end
    else
        if Menu.clear.useQ:Value() and Ready(_Q) then
            DepressiveLib.ForEachMinion(function(m)
                if m.isEnemy and IsValid(m) and m.distance < SQ.range and m.health < m.maxHealth*0.35 then CastFast(HK_Q, m) end
            end)
        end
        if Menu.clear.useW:Value() and Ready(_W) then CastSpiderW() end
        if Menu.clear.useR:Value() and Ready(_R) and (not Ready(_Q) and not Ready(_W)) then CastR() end
    end
end
local function LastHit()
    if not Menu.lasthit.useQ:Value() then return end
    if InSpider() then return end
    if not Ready(_Q) then return end
    DepressiveLib.ForEachMinion(function(m)
        if m.isEnemy and IsValid(m) and m.distance < HQ.range then
            local dmg = DepressiveLib.GetDamage and DepressiveLib.GetDamage("Q", m) or 0
            if dmg > 0 and m.health < dmg * 0.95 then CastFast(HK_Q, m) end
        end
    end)
end

-- Drawing
local function DrawRanges()
    if myHero.dead or not Menu then return end
    if Draw and Draw.Circle then
        if Menu.draw.q:Value() and Ready(_Q) then Draw.Circle(myHero.pos, (InSpider() and SQ.range or HQ.range), 1, Draw.Color(150,120,220,255)) end
        if Menu.draw.w:Value() and Ready(_W) and not InSpider() then Draw.Circle(myHero.pos, HW.range, 1, Draw.Color(150,180,120,255)) end
        if Menu.draw.e:Value() and Ready(_E) and not InSpider() then Draw.Circle(myHero.pos, HE.range, 1, Draw.Color(150,255,180,120)) end
        if Menu.draw.r:Value() and Ready(_R) then Draw.Circle(myHero.pos, 1000, 1, Draw.Color(120,255,80,80)) end
    end
end

-- Public API required by Loader
function Elise:Init()
    if _G.DepressiveEnsureMapPosition then _G.DepressiveEnsureMapPosition() end
    if _G.MenuElement then
        Menu = MenuElement({type = MENU, id = "DepressiveElise", name = "Depressive Elise"})
        Menu:MenuElement({name = "Version", drop = {string.format("v%.2f", self.__version)}})
        Menu:MenuElement({type=MENU, id="combo", name="Combo"})
        Menu.combo:MenuElement({id="useQ", name="Use Q", value=true})
        Menu.combo:MenuElement({id="useW", name="Use W", value=true})
        Menu.combo:MenuElement({id="useE", name="Use E", value=true})
        Menu.combo:MenuElement({id="useR", name="Use R (form swap)", value=true})
        Menu:MenuElement({type=MENU, id="harass", name="Harass"})
        Menu.harass:MenuElement({id="useQ", name="Use Q", value=true})
        Menu.harass:MenuElement({id="useW", name="Use W", value=true})
        Menu.harass:MenuElement({id="useE", name="Use E", value=false})
        Menu.harass:MenuElement({id="mana", name="Min Mana%", value=45, min=0, max=100, step=1})
        Menu:MenuElement({type=MENU, id="clear", name="Lane/Jungle Clear"})
        Menu.clear:MenuElement({id="useQ", name="Use Q", value=true})
        Menu.clear:MenuElement({id="useW", name="Use W", value=true})
        Menu.clear:MenuElement({id="useR", name="Use R (swap)", value=true})
        Menu.clear:MenuElement({id="wMin", name="W min minions", value=3, min=1, max=8, step=1})
        Menu.clear:MenuElement({id="mana", name="Min Mana%", value=40, min=0, max=100, step=1})
        Menu:MenuElement({type=MENU, id="lasthit", name="Last Hit"})
        Menu.lasthit:MenuElement({id="useQ", name="Use Q", value=true})
        Menu:MenuElement({type=MENU, id="draw", name="Draw"})
        Menu.draw:MenuElement({id="q", name="Draw Q", value=true})
        Menu.draw:MenuElement({id="w", name="Draw W (human)", value=false})
        Menu.draw:MenuElement({id="e", name="Draw E (human)", value=false})
        Menu.draw:MenuElement({id="r", name="Draw R range (visual approx)", value=false})
    else
        Menu = {combo={useQ=true,useW=true,useE=true,useR=true},harass={useQ=true,useW=true,useE=false,mana=45},clear={useQ=true,useW=true,useR=true,wMin=3,mana=40},lasthit={useQ=true},draw={q=true,w=false,e=false,r=false}}
    end
    print(string.format("[DepressiveElise] loaded v%.2f", self.__version))
end

function Elise:Tick()
    if DepressiveLib.MyHeroNotReady and DepressiveLib.MyHeroNotReady() then return end
    local mode = GetMode()
    if mode == "Combo" then Combo()
    elseif mode == "Harass" then Harass()
    elseif mode == "LaneClear" or mode == "Clear" then LaneClear()
    elseif mode == "LastHit" then LastHit() end
end

function Elise:Draw()
    DrawRanges()
end
return Elise
return Elise
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
    
    -- Prediction Settings
    self.Menu:MenuElement({type = MENU, id = "prediction", name = "Prediction Settings"})
    self.Menu.prediction:MenuElement({id = "status", name = "DepressivePrediction Status", type = _G.SPACE})
    self.Menu.prediction:MenuElement({id = "useAdvanced", name = "Use Advanced Prediction", value = true})
    self.Menu.prediction:MenuElement({id = "hitChanceE", name = "E Min Hit Chance", value = 3, min = 1, max = 6, step = 1})
    self.Menu.prediction:MenuElement({id = "hitChanceW", name = "W Min Hit Chance", value = 2, min = 1, max = 6, step = 1})
    
    -- Drawing
    self.Menu:MenuElement({type = MENU, id = "drawing", name = "Drawing"})
    self.Menu.drawing:MenuElement({id = "Q", name = "Draw Q Range", value = true})
    self.Menu.drawing:MenuElement({id = "W", name = "Draw W Range", value = true})
    self.Menu.drawing:MenuElement({id = "E", name = "Draw E Range", value = true})
    self.Menu.drawing:MenuElement({id = "form", name = "Draw Current Form", value = true})
    self.Menu.drawing:MenuElement({id = "rappel", name = "Draw Rappel Status", value = true})
    self.Menu.drawing:MenuElement({id = "killable", name = "Draw Killable Enemies", value = true})
    self.Menu.drawing:MenuElement({id = "cooldowns", name = "Draw Cooldown InfoBox", value = true})
    self.Menu.drawing:MenuElement({id = "predictionInfo", name = "Show Prediction Status", value = true})
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
    
    -- Draw Prediction Status
    if self.Menu.drawing.predictionInfo:Value() then
        local predStatus = PredictionLib and "DepressivePrediction: ACTIVE" or "DepressivePrediction: NOT FOUND"
        local predColor = PredictionLib and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 0, 0)
        Draw.Text(predStatus, 14, myPos:To2D().x - 80, myPos:To2D().y + 50, predColor)
        
        if PredictionLib then
            local advancedStatus = self.Menu.prediction.useAdvanced:Value() and "Advanced: ON" or "Advanced: OFF"
            local advancedColor = self.Menu.prediction.useAdvanced:Value() and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 255, 255)
            Draw.Text(advancedStatus, 12, myPos:To2D().x - 50, myPos:To2D().y + 65, advancedColor)
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
    
    -- Update prediction library unit tracking if available
    if PredictionLib then
        for i = 1, #Enemys do
            local enemy = Enemys[i]
            if enemy and enemy.valid then
                -- This updates the prediction library's internal tracking
                pcall(function()
                    PredictionLib.GetPredictedPosition(enemy, 0.1) -- Update tracking
                end)
            end
        end
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
    local target = self:GetBestTarget("combo", self.Menu.combo.comboRange:Value())
    if not target then
        -- Fallback to regular target selection
        target = self:GetHeroTarget(self.Menu.combo.comboRange:Value())
    end
    if not target then return end
    
    local distance = GetDistance(myHero.pos, target.pos)
    
    -- ALWAYS START WITH HUMAN FORM FIRST
    if self.currentForm == FORM_TYPES.HUMAN then
        local usedSpell = false
        
        -- Cast E (Cocoon) first for CC - use enhanced target validation
        if self.Menu.combo.useE:Value() and Ready(_E) and 
           self:IsValidPredictionTarget(target, "E") then
            if self:CastE(target) then
                usedSpell = true
                self.combatState.usedHumanSpells = true
            end
        end
        
        -- Cast Q - use enhanced target validation
        if self.Menu.combo.useQ:Value() and Ready(_Q) and 
           self:IsValidPredictionTarget(target, "Q") then
            if self:CastQ(target) then
                usedSpell = true
                self.combatState.usedHumanSpells = true
            end
        end
        
        -- Cast W - use enhanced target validation
        if self.Menu.combo.useW:Value() and Ready(_W) and 
           self:IsValidPredictionTarget(target, "W") then
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
    
    local target = self:GetBestTarget("E", self.E.range)
    if not target then
        -- Fallback to regular target selection
        target = self:GetHeroTarget(self.E.range)
    end
    if not target then return end
    
    -- Check mana threshold
    local manaPercent = myHero.mana / myHero.maxMana * 100
    if manaPercent < self.Menu.harass.manaThreshold:Value() then return end
    
    local distance = GetDistance(myHero.pos, target.pos)
    
    -- Cast E for CC - use enhanced validation
    if self.Menu.harass.useE:Value() and Ready(_E) and 
       self:IsValidPredictionTarget(target, "E") then
        self:CastE(target)
    end
    
    -- Cast Q - use enhanced validation
    if self.Menu.harass.useQ:Value() and Ready(_Q) and 
       self:IsValidPredictionTarget(target, "Q") then
        self:CastQ(target)
    end
    
    -- Cast W - use enhanced validation
    if self.Menu.harass.useW:Value() and Ready(_W) and 
       self:IsValidPredictionTarget(target, "W") then
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
    
    -- Use DepressivePrediction library if available and enabled
    if PredictionLib and self.Menu.prediction.useAdvanced:Value() then
        local spell = PredictionLib.SpellPrediction({
            Type = 0, -- SPELLTYPE_LINE
            Speed = self.E.speed,
            Range = self.E.range,
            Delay = self.E.delay,
            Radius = self.E.width,
            Collision = self.E.collision,
            CollisionTypes = {0} -- COLLISION_MINION
        })
        
        local prediction = spell:GetPrediction(target, myHero.pos)
        local minHitChance = self.Menu.prediction.hitChanceE:Value()
        
        if prediction and prediction.HitChance >= minHitChance then
            return prediction.CastPosition
        end
        
        return nil
    end
    
    -- Fallback to basic prediction if DepressivePrediction is not available
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
    
    -- Use DepressivePrediction library if available and enabled
    if PredictionLib and self.Menu.prediction.useAdvanced:Value() then
        local spell = PredictionLib.SpellPrediction({
            Type = 1, -- SPELLTYPE_CIRCLE
            Speed = self.W.speed,
            Range = self.W.range,
            Delay = self.W.delay,
            Radius = self.W.width,
            Collision = self.W.collision,
            CollisionTypes = {}
        })
        
        local prediction = spell:GetPrediction(target, myHero.pos)
        local minHitChance = self.Menu.prediction.hitChanceW:Value()
        
        if prediction and prediction.HitChance >= minHitChance then
            return prediction.CastPosition
        end
        
        return nil
    end
    
    -- Fallback to basic prediction if DepressivePrediction is not available
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

-- Enhanced target selection for specific spells
function Elise:GetBestTarget(spellType, range)
    local bestTarget = nil
    local bestScore = 0
    
    for i = 1, #Enemys do
        local enemy = Enemys[i]
        if self:IsValidPredictionTarget(enemy, spellType) then
            local distance = GetDistance(myHero.pos, enemy.pos)
            if distance <= range then
                local priority = self:GetTargetPriority(enemy)
                
                -- Add spell-specific scoring
                if spellType == "E" and self.currentForm == FORM_TYPES.HUMAN then
                    -- Prefer targets we can follow up on
                    if distance <= self.SpiderQ.range + 200 then
                        priority = priority + 3
                    end
                    
                    -- Avoid very close targets for cocoon
                    if distance < 250 then
                        priority = priority - 2
                    end
                elseif spellType == "Q" and self.currentForm == FORM_TYPES.SPIDER then
                    -- Spider Q for gap closing - prefer targets in follow-up range
                    if distance <= self.SpiderQ.range and distance > 150 then
                        priority = priority + 2
                    end
                end
                
                if priority > bestScore then
                    bestTarget = enemy
                    bestScore = priority
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
    
    -- Prediction-based priority adjustment
    if PredictionLib then
        local trackingInfo = PredictionLib.GetTrackingInfo(enemy)
        if trackingInfo and trackingInfo.movementPattern then
            -- Prioritize targets with more predictable movement
            local movementData = trackingInfo.movementPattern
            if movementData.avgVelocity then
                local avgSpeed = math.sqrt(movementData.avgVelocity.x^2 + movementData.avgVelocity.z^2)
                if avgSpeed < 100 then -- Slow or stationary targets
                    priority = priority + 2
                elseif avgSpeed > 400 then -- Fast moving targets
                    priority = priority - 1
                end
            end
        end
    end
    
    return priority
end

-- Enhanced target validation using prediction library
function Elise:IsValidPredictionTarget(target, spellType)
    if not target or not IsValid(target) then return false end
    
    -- Basic validation
    local distance = GetDistance(myHero.pos, target.pos)
    local maxRange = 0
    
    if spellType == "Q" then
        maxRange = self.currentForm == FORM_TYPES.HUMAN and self.Q.range or self.SpiderQ.range
    elseif spellType == "W" then
        maxRange = self.currentForm == FORM_TYPES.HUMAN and self.W.range or self.SpiderW.range
    elseif spellType == "E" then
        maxRange = self.currentForm == FORM_TYPES.HUMAN and self.E.range or self.SpiderE.range
    end
    
    if distance > maxRange then return false end
    
    -- Use prediction library for better validation if available
    if PredictionLib then
        local spell = nil
        
        if spellType == "E" and self.currentForm == FORM_TYPES.HUMAN then
            spell = PredictionLib.SpellPrediction({
                Type = 0, -- SPELLTYPE_LINE
                Speed = self.E.speed,
                Range = self.E.range,
                Delay = self.E.delay,
                Radius = self.E.width,
                Collision = self.E.collision,
                CollisionTypes = {0} -- COLLISION_MINION
            })
        elseif spellType == "W" and self.currentForm == FORM_TYPES.HUMAN then
            spell = PredictionLib.SpellPrediction({
                Type = 1, -- SPELLTYPE_CIRCLE
                Speed = self.W.speed,
                Range = self.W.range,
                Delay = self.W.delay,
                Radius = self.W.width,
                Collision = false,
                CollisionTypes = {}
            })
        elseif spellType == "Q" then
            -- Q is targeted, just check range and line of sight
            return distance <= maxRange
        end
        
        if spell then
            local prediction = spell:GetPrediction(target, myHero.pos)
            return prediction and prediction.HitChance >= 2 -- HITCHANCE_LOW or higher
        end
    end
    
    return true -- Fallback to basic validation
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
    -- Check for DepressivePrediction one more time before initializing Elise
    if _G.DepressivePrediction then
        PredictionLib = _G.DepressivePrediction
        print("DepressiveElise: DepressivePrediction integrated successfully!")
    else
        print("DepressiveElise: Running without DepressivePrediction (basic prediction will be used)")
    end
    
    _G.Elise = Elise()
    print("DepressiveElise: Loaded successfully!")
end, math.max(0.2, 5 - Game.Timer()))
