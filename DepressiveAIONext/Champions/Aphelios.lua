-- DepressiveAIONext compatibility guard
if _G.__DEPRESSIVE_NEXT_APHELIOS_LOADED then return end
_G.__DEPRESSIVE_NEXT_APHELIOS_LOADED = true

local Version = 1.0
local Name = "DepressiveAphelios"

-- Hero validation
local Heroes = {"Aphelios"}

-- Helper function for table.contains
local function tableContains(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then return true end
    end
    return false
end

if not tableContains(Heroes, myHero.charName) then return end

-- Load required libraries
local PredictionLoaded = false
local success = pcall(function()
    require("DepressivePrediction")
    if _G.DepressivePrediction then
        PredictionLoaded = true
    end
end)

if not success then
    print("[Aphelios] DepressivePrediction not found, using fallback prediction")
end

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

-- Utility Functions
local function GetDistance(p1, p2)
    if not p1 or not p2 then return math.huge end
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

local function IsValid(unit)
    return unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable
end

local function Ready(slot)
    local sd = myHero:GetSpellData(slot)
    return sd and sd.level > 0 and sd.currentCd == 0 and Game.CanUseSpell(slot) == 0
end

local function GetTarget(range)
    local best, bd = nil, math.huge
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.team ~= myHero.team and IsValid(hero) then
            local d = GetDistance(myHero.pos, hero.pos)
            if d < range and d < bd then
                best = hero
                bd = d
            end
        end
    end
    return best
end

local function GetEnemyCount(range)
    local count = 0
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.team ~= myHero.team and IsValid(hero) and GetDistance(myHero.pos, hero.pos) <= range then
            count = count + 1
        end
    end
    return count
end

local function GetAllyCount(range)
    local count = 0
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.team == myHero.team and IsValid(hero) and GetDistance(myHero.pos, hero.pos) <= range then
            count = count + 1
        end
    end
    return count
end

-- Mode function for orbwalker compatibility
local function Mode()
    if _G.PremiumOrbwalker then
        return _G.PremiumOrbwalker:GetMode()
    elseif _G.GOS and _G.GOS.GetMode then
        return _G.GOS:GetMode()
    elseif _G.SDK and _G.SDK.Orbwalker then
        return _G.SDK.Orbwalker.Mode()
    else
        return "Combo" -- Default fallback
    end
end

-- Basic damage calculation function
local function getdmg(spell, target, source, stage, level)
    if not target or not source then return 0 end
    
    local baseDamage = 0
    local apRatio = 0
    local adRatio = 0
    
    if spell == "AA" then
        baseDamage = source.totalDamage
    elseif spell == "Q" then
        if stage == 1 then -- Calibrum
            baseDamage = 60 + (level or 1) * 20
            adRatio = 0.6
        elseif stage == 4 then -- Infernum
            baseDamage = 25 + (level or 1) * 15
            adRatio = 0.8
        end
    elseif spell == "R" then
        if stage == 1 then
            baseDamage = 125 + (level or 1) * 75
            adRatio = 0.2
        elseif stage == 2 then
            baseDamage = 125 + (level or 1) * 75
            adRatio = 0.3
        end
    end
    
    local totalDamage = baseDamage + (source.totalDamage * adRatio) + (source.ap * apRatio)
    
    -- Basic armor/magic resist calculation
    local finalDamage = totalDamage * (100 / (100 + target.armor))
    
    return finalDamage
end

-- Spell definitions
local SPELL_RANGES = {
    QSniper = 1450,
    QFlame = 850,
    QBounce = 475,
    QHeal = 620,
    QSlow = 650,
    R = 1300
}

local SPELL_SPEEDS = {
    QSniper = 1850,
    QFlame = 1850,
    R = 1000
}

local SPELL_DELAYS = {
    QSniper = 0.25,
    QFlame = 0.25,
    R = 0.25
}

local SPELL_RADIUS = {
    QSniper = 60,
    QFlame = 100,
    R = 110
}

-- Weapon definitions based on the table and sequential order
local WeaponTypes = {
    ["Calibrum"] = {Type = "Calibrum", Purpose = "Long-range poke", Priority = 1, Order = 1},
    ["Severum"] = {Type = "Severum", Purpose = "Sustain and healing", Priority = 2, Order = 2},
    ["Gravitum"] = {Type = "Gravitum", Purpose = "Crowd control (slow/root)", Priority = 3, Order = 3},
    ["Infernum"] = {Type = "Infernum", Purpose = "Area damage (AoE)", Priority = 4, Order = 4},
    ["Crescendum"] = {Type = "Crescendum", Purpose = "Sustained melee damage", Priority = 5, Order = 5}
}

-- Weapon order for sequential cycling
local WeaponOrder = {"Calibrum", "Severum", "Gravitum", "Infernum", "Crescendum"}

-- Weapon combination system with intelligent priorities
local WeaponCombinations = {
    ["Teamfight"] = {Main = "Infernum", Off = "Gravitum", Name = "Infernum + Gravitum", Priority = 1},
    ["DPS"] = {Main = "Crescendum", Off = "Calibrum", Name = "Crescendum + Calibrum", Priority = 2},
    ["Poke"] = {Main = "Calibrum", Off = "Severum", Name = "Calibrum + Severum", Priority = 3},
    ["Kite"] = {Main = "Severum", Off = "Gravitum", Name = "Severum + Gravitum", Priority = 4}
}

-- Main class
class "DepressiveAphelios"

function DepressiveAphelios:__init()
    self.EnemyLoaded = false
    self.MainHand = "None"
    self.OffHand = "None"
    self.FlameQR = Game.Timer()
    self.SniperQR = Game.Timer()
    self.SlowQR = Game.Timer()
    self.BounceQR = Game.Timer()
    self.HealQR = Game.Timer()
    self.CanRoot = false
    self.CanRange = false
    self.CurrentCombination = "None"
    self.TargetCombination = "None"
    self.WeaponPriority = {}
    self.WeaponToConsume = nil
    self.target = nil
    
    self:Menu()
    self:Spells()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("OnPreAttack", function(args) self:OnPreAttack(args) end)
    Callback.Add("OnPostAttack", function() self:OnPostAttack() end)
    Callback.Add("OnPostAttackTick", function(args) self:OnPostAttackTick(args) end)
end

function DepressiveAphelios:Menu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveAphelios", name = "Depressive Aphelios"})
    
    -- Weapon combinations menu
    self.Menu:MenuElement({id = "Combinations", name = "Weapon Combinations", type = MENU})
    self.Menu.Combinations:MenuElement({id = "AutoSwitch", name = "Auto Weapon Switch", value = true})
    self.Menu.Combinations:MenuElement({id = "TeamfightMode", name = "Teamfight Mode (Infernum + Gravitum)", value = true})
    self.Menu.Combinations:MenuElement({id = "DPSMode", name = "DPS Mode (Crescendum + Calibrum)", value = true})
    self.Menu.Combinations:MenuElement({id = "PokeMode", name = "Poke Mode (Calibrum + Severum)", value = true})
    self.Menu.Combinations:MenuElement({id = "KiteMode", name = "Kite Mode (Severum + Gravitum)", value = true})
    
    -- Combo menu
    self.Menu:MenuElement({id = "ComboMode", name = "Combo", type = MENU})
    self.Menu.ComboMode:MenuElement({id = "UseQ", name = "Use Q in Combo", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseW", name = "Switch Weapons", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseQPassive", name = "Range Attack Marked Targets", value = true})
    self.Menu.ComboMode:MenuElement({id = "UseR", name = "Use R in Combo", value = true})
    
    -- Harass menu
    self.Menu:MenuElement({id = "HarassMode", name = "Harass", type = MENU})
    self.Menu.HarassMode:MenuElement({id = "UseQ", name = "Use Q in Harass", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseW", name = "Switch Weapons", value = true})
    self.Menu.HarassMode:MenuElement({id = "UseQPassive", name = "Range Attack Marked Targets", value = true})
    
    -- Clear menu
    self.Menu:MenuElement({id = "ClearMode", name = "Clear", type = MENU})
    self.Menu.ClearMode:MenuElement({id = "UseQ", name = "Use Q in Clear", value = true})
    self.Menu.ClearMode:MenuElement({id = "UseW", name = "Switch Weapons", value = true})
    self.Menu.ClearMode:MenuElement({id = "UseR", name = "Use R in Clear", value = false})
    self.Menu.ClearMode:MenuElement({id = "OnlyWithEnemies", name = "Only use abilities when enemies nearby", value = true})
    self.Menu.ClearMode:MenuElement({id = "EnemyRange", name = "Enemy detection range", value = 1000, min = 500, max = 1500, step = 100})
    
    -- LastHit menu
    self.Menu:MenuElement({id = "LastHitMode", name = "LastHit", type = MENU})
    self.Menu.LastHitMode:MenuElement({id = "UseQ", name = "Use Q in LastHit", value = true})
    self.Menu.LastHitMode:MenuElement({id = "UseW", name = "Switch Weapons", value = true})
    
    -- Flee menu
    self.Menu:MenuElement({id = "FleeMode", name = "Flee", type = MENU})
    self.Menu.FleeMode:MenuElement({id = "UseQ", name = "Use Q in Flee", value = true})
    self.Menu.FleeMode:MenuElement({id = "UseW", name = "Switch Weapons", value = true})
    self.Menu.FleeMode:MenuElement({id = "UseR", name = "Use R in Flee", value = true})
    
    -- Kill steal menu
    self.Menu:MenuElement({id = "KSMode", name = "Kill Steal", type = MENU})
    self.Menu.KSMode:MenuElement({id = "UseQFlame", name = "Use Infernum Q for KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseQSniper", name = "Use Calibrum Q for KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseQPassive", name = "KS Marked Targets with Calibrum", value = true})
    self.Menu.KSMode:MenuElement({id = "UseW", name = "Switch Weapons for KS", value = true})
    self.Menu.KSMode:MenuElement({id = "UseR", name = "Use R for KS", value = true})
    
    -- Draw menu
    self.Menu:MenuElement({id = "Draw", name = "Draw", type = MENU})
    self.Menu.Draw:MenuElement({id = "UseDraws", name = "Enable Draws", value = true})
    self.Menu.Draw:MenuElement({id = "ShowCombination", name = "Show Current Combination", value = true})
    self.Menu.Draw:MenuElement({id = "ShowTarget", name = "Show Target Combination", value = true})
end

function DepressiveAphelios:Spells()
    self.QSniperSpell = {speed = SPELL_SPEEDS.QSniper, range = SPELL_RANGES.QSniper, delay = SPELL_DELAYS.QSniper, radius = SPELL_RADIUS.QSniper, collision = {"minion"}, type = "linear"}
    self.QFlameSpell = {speed = SPELL_SPEEDS.QFlame, range = SPELL_RANGES.QFlame, delay = SPELL_DELAYS.QFlame, radius = SPELL_RADIUS.QFlame, collision = {}, type = "linear"}
    self.RAllSpell = {speed = SPELL_SPEEDS.R, range = SPELL_RANGES.R, delay = SPELL_DELAYS.R, radius = SPELL_RADIUS.R, collision = {}, type = "linear"}
end

function DepressiveAphelios:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    
    if self.EnemyLoaded == false then
        local CountEnemy = 0
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.team ~= myHero.team then
                CountEnemy = CountEnemy + 1
            end
        end
        if CountEnemy < 1 then
            -- Wait for enemies to load
        else
            self.EnemyLoaded = true
            PrintChat("Enemies Loaded")
        end
    end
    
    self.target = GetTarget(3000)
    
    -- Handle Severum Q attack disable
    if _G.SDK and _G.SDK.BuffManager:HasBuff(myHero, "ApheliosSeverumQ") then
        self:SetAttack(false)
    else
        self:SetAttack(true)
    end
    
    self.OffHand = self:GetOffHand()
    self.MainHand = self:GetGun()
    
    -- Update current combination
    self:UpdateCurrentCombination()
    
    -- Determine target combination
    self:DetermineTargetCombination()
    
    -- Update weapon priority
    self:UpdateWeaponPriority()
    
    self:GetTargetBuffs()
    self:KS()
    
    -- Call appropriate mode function based on current orbwalker mode
    local currentMode = Mode()
    if currentMode == "Combo" then
        self:Combo()
    elseif currentMode == "Harass" then
        self:Harass()
    elseif currentMode == "Clear" then
        self:Clear()
    elseif currentMode == "LastHit" then
        self:LastHit()
    elseif currentMode == "Flee" then
        self:Flee()
    else
        -- Default to Combo for any other mode
        self:Combo()
    end
end

function DepressiveAphelios:UpdateCurrentCombination()
    for comboType, weapons in pairs(WeaponCombinations) do
        -- Check both directions: Main-Off and Off-Main
        if (self.MainHand == weapons.Main and self.OffHand == weapons.Off) or
           (self.MainHand == weapons.Off and self.OffHand == weapons.Main) then
            self.CurrentCombination = comboType
            return
        end
    end
    self.CurrentCombination = "None"
end

function DepressiveAphelios:DetermineTargetCombination()
    local enemyCount = GetEnemyCount(1300)
    local allyCount = GetAllyCount(1300)
    local myHealth = myHero.health / myHero.maxHealth
    local targetDistance = self.target and GetDistance(self.target.pos, myHero.pos) or 1000
    
    -- Initialize all possible combinations with their scores
    self.AllCombinations = {}
    
    -- Check which modes are enabled in menu
    local teamfightEnabled = self.Menu.Combinations.TeamfightMode:Value()
    local dpsEnabled = self.Menu.Combinations.DPSMode:Value()
    local pokeEnabled = self.Menu.Combinations.PokeMode:Value()
    local kiteEnabled = self.Menu.Combinations.KiteMode:Value()
    
    -- Score each combination based on current situation
    if teamfightEnabled then
        local teamfightScore = self:CalculateCombinationScore("Teamfight", enemyCount, allyCount, targetDistance, myHealth)
        table.insert(self.AllCombinations, {type = "Teamfight", score = teamfightScore})
    end
    
    if dpsEnabled then
        local dpsScore = self:CalculateCombinationScore("DPS", enemyCount, allyCount, targetDistance, myHealth)
        table.insert(self.AllCombinations, {type = "DPS", score = dpsScore})
    end
    
    if pokeEnabled then
        local pokeScore = self:CalculateCombinationScore("Poke", enemyCount, allyCount, targetDistance, myHealth)
        table.insert(self.AllCombinations, {type = "Poke", score = pokeScore})
    end
    
    if kiteEnabled then
        local kiteScore = self:CalculateCombinationScore("Kite", enemyCount, allyCount, targetDistance, myHealth)
        table.insert(self.AllCombinations, {type = "Kite", score = kiteScore})
    end
    
    -- Sort combinations by score (highest first)
    table.sort(self.AllCombinations, function(a, b) return a.score > b.score end)
    
    -- Set the best combination as target
    if #self.AllCombinations > 0 then
        self.TargetCombination = self.AllCombinations[1].type
    else
        self.TargetCombination = "None"
    end
    
    -- Store all combinations for weapon priority calculation
    self.AvailableCombinations = self.AllCombinations
end

function DepressiveAphelios:CalculateCombinationScore(comboType, enemyCount, allyCount, targetDistance, myHealth)
    local score = 0
    
    if comboType == "Teamfight" then
        -- Teamfight: Best for multiple enemies with allies
        if enemyCount >= 3 then score = score + 50 end
        if allyCount >= 2 then score = score + 30 end
        if enemyCount >= 2 then score = score + 20 end
        if targetDistance < 600 then score = score + 15 end
        -- Bonus for teamfight situations
        score = score + (enemyCount * 10)
        
    elseif comboType == "DPS" then
        -- DPS: Best for 1v1 and close combat
        if enemyCount == 1 then score = score + 40 end
        if targetDistance < 400 then score = score + 35 end
        if targetDistance < 600 then score = score + 25 end
        if targetDistance < 800 then score = score + 15 end
        -- Penalty for multiple enemies
        if enemyCount > 1 then score = score - 20 end
        
    elseif comboType == "Poke" then
        -- Poke: Best for long range and safety
        if targetDistance > 800 then score = score + 40 end
        if targetDistance > 600 then score = score + 25 end
        if enemyCount == 1 then score = score + 20 end
        if myHealth < 0.7 then score = score + 15 end
        -- Penalty for close combat
        if targetDistance < 400 then score = score - 30 end
        
    elseif comboType == "Kite" then
        -- Kite: Best for survival and control
        if myHealth < 0.6 then score = score + 40 end
        if enemyCount >= 2 then score = score + 30 end
        if targetDistance > 400 then score = score + 20 end
        if allyCount >= 1 then score = score + 15 end
        -- Bonus for survival situations
        score = score + (enemyCount * 5)
    end
    
    -- Base score for all combinations
    score = score + 10
    
    return score
end

function DepressiveAphelios:UpdateWeaponPriority()
    self.WeaponPriority = {}
    
    -- Check all available combinations and find the best weapons to seek
    if self.AvailableCombinations and #self.AvailableCombinations > 0 then
        local weaponScores = {}
        
        -- Score each weapon based on all available combinations
        for _, combo in ipairs(self.AvailableCombinations) do
            local targetWeapons = WeaponCombinations[combo.type]
            if targetWeapons then
                -- Check if we already have this combination
                local hasMainInMain = (self.MainHand == targetWeapons.Main)
                local hasOffInOff = (self.OffHand == targetWeapons.Off)
                local hasMainInOff = (self.OffHand == targetWeapons.Main)
                local hasOffInMain = (self.MainHand == targetWeapons.Off)
                local hasCompleteCombo = (hasMainInMain and hasOffInOff) or (hasMainInOff and hasOffInMain)
                
                if not hasCompleteCombo then
                    -- Score each weapon needed for this combination
                    local mainWeapon = targetWeapons.Main
                    local offWeapon = targetWeapons.Off
                    
                    -- Check if we already have these weapons
                    local hasMain = (self.MainHand == mainWeapon or self.OffHand == mainWeapon)
                    local hasOff = (self.MainHand == offWeapon or self.OffHand == offWeapon)
                    
                    -- Score weapons we don't have
                    if not hasMain then
                        weaponScores[mainWeapon] = (weaponScores[mainWeapon] or 0) + combo.score
                    end
                    if not hasOff then
                        weaponScores[offWeapon] = (weaponScores[offWeapon] or 0) + combo.score
                    end
                end
            end
        end
        
        -- Sort weapons by score and add to priority list
        local sortedWeapons = {}
        for weapon, score in pairs(weaponScores) do
            table.insert(sortedWeapons, {weapon = weapon, score = score})
        end
        
        table.sort(sortedWeapons, function(a, b) return a.score > b.score end)
        
        -- Add top weapons to priority list
        for _, weaponData in ipairs(sortedWeapons) do
            if self.MainHand ~= weaponData.weapon and self.OffHand ~= weaponData.weapon then
                table.insert(self.WeaponPriority, weaponData.weapon)
            end
        end
    end
end

function DepressiveAphelios:FindOptimalWeaponToSeek(targetWeapons)
    local myHealth = myHero.health / myHero.maxHealth
    local enemyCount = GetEnemyCount(800)
    local targetDistance = self.target and GetDistance(self.target.pos, myHero.pos) or 1000
    
    -- Get current weapon positions in the cycle
    local currentMainOrder = self:GetWeaponOrder(self.MainHand)
    local currentOffOrder = self:GetWeaponOrder(self.OffHand)
    local targetMainOrder = self:GetWeaponOrder(targetWeapons.Main)
    local targetOffOrder = self:GetWeaponOrder(targetWeapons.Off)
    
    -- Check if we already have either target weapon
    local hasMainWeapon = (self.MainHand == targetWeapons.Main or self.OffHand == targetWeapons.Main)
    local hasOffWeapon = (self.MainHand == targetWeapons.Off or self.OffHand == targetWeapons.Off)
    
    -- If we have both weapons, we shouldn't be seeking anything
    if hasMainWeapon and hasOffWeapon then
        return nil
    end
    
    -- If we have one weapon, seek the other one
    if hasMainWeapon and not hasOffWeapon then
        return targetWeapons.Off
    elseif hasOffWeapon and not hasMainWeapon then
        return targetWeapons.Main
    end
    
    -- If we have neither weapon, calculate which one is closer
    local stepsToMain = self:CalculateStepsToWeapon(currentMainOrder, currentOffOrder, targetMainOrder)
    local stepsToOff = self:CalculateStepsToWeapon(currentMainOrder, currentOffOrder, targetOffOrder)
    
    -- Determine which weapon is closer to get
    local weaponToSeek = nil
    local reason = ""
    
    -- Removed health-based urgency - control from 100% health
    local isUrgent = (enemyCount >= 3) or (targetDistance < 200)
    
    if isUrgent then
        -- In urgent situations, prioritize the closest weapon regardless of type
        if stepsToMain <= stepsToOff then
            weaponToSeek = targetWeapons.Main
            reason = "URGENT: Main weapon closer (" .. stepsToMain .. " steps)"
        else
            weaponToSeek = targetWeapons.Off
            reason = "URGENT: Off weapon closer (" .. stepsToOff .. " steps)"
        end
    else
        -- In normal situations, consider both distance and weapon usefulness
        -- But first check if we already have one of the weapons
        local hasMainWeapon = (self.MainHand == targetWeapons.Main or self.OffHand == targetWeapons.Main)
        local hasOffWeapon = (self.MainHand == targetWeapons.Off or self.OffHand == targetWeapons.Off)
        
        if hasMainWeapon and not hasOffWeapon then
            -- We have the main weapon, seek the off weapon
            weaponToSeek = targetWeapons.Off
            reason = "Have main weapon, seeking off weapon (" .. stepsToOff .. " steps)"
        elseif hasOffWeapon and not hasMainWeapon then
            -- We have the off weapon, seek the main weapon
            weaponToSeek = targetWeapons.Main
            reason = "Have off weapon, seeking main weapon (" .. stepsToMain .. " steps)"
        else
            -- We have neither weapon, use spell data to determine optimal choice
            local nextWeapon = self:GetNextWeapon()
            local weaponAfterNext = self:GetWeaponAfterNext()
            
            if nextWeapon and weaponAfterNext then
                -- Check if either target weapon is coming up soon
                if nextWeapon == targetWeapons.Main then
                    weaponToSeek = targetWeapons.Main
                    reason = "Main weapon is next in cycle"
                elseif nextWeapon == targetWeapons.Off then
                    weaponToSeek = targetWeapons.Off
                    reason = "Off weapon is next in cycle"
                elseif weaponAfterNext == targetWeapons.Main then
                    weaponToSeek = targetWeapons.Main
                    reason = "Main weapon is 2 steps away"
                elseif weaponAfterNext == targetWeapons.Off then
                    weaponToSeek = targetWeapons.Off
                    reason = "Off weapon is 2 steps away"
                else
                    -- Neither is coming soon, use normal logic
                    local mainUseful = self:IsWeaponUsefulForSituation(targetWeapons.Main)
                    local offUseful = self:IsWeaponUsefulForSituation(targetWeapons.Off)
                    
                    if mainUseful and offUseful then
                        -- Both are useful, prioritize based on situation
                        local mainPriority = self:GetWeaponPriority(targetWeapons.Main)
                        local offPriority = self:GetWeaponPriority(targetWeapons.Off)
                        
                        if mainPriority > offPriority then
                            weaponToSeek = targetWeapons.Main
                            reason = "Main weapon higher priority (" .. mainPriority .. " vs " .. offPriority .. ")"
                        elseif offPriority > mainPriority then
                            weaponToSeek = targetWeapons.Off
                            reason = "Off weapon higher priority (" .. offPriority .. " vs " .. mainPriority .. ")"
                        else
                            -- Same priority, choose the closer one
                            if stepsToMain <= stepsToOff then
                                weaponToSeek = targetWeapons.Main
                                reason = "Same priority, Main closer (" .. stepsToMain .. " steps)"
                            else
                                weaponToSeek = targetWeapons.Off
                                reason = "Same priority, Off closer (" .. stepsToOff .. " steps)"
                            end
                        end
                    elseif mainUseful then
                        weaponToSeek = targetWeapons.Main
                        reason = "Main weapon useful (" .. stepsToMain .. " steps)"
                    elseif offUseful then
                        weaponToSeek = targetWeapons.Off
                        reason = "Off weapon useful (" .. stepsToOff .. " steps)"
                    else
                        -- Neither is particularly useful, choose the closest
                        if stepsToMain <= stepsToOff then
                            weaponToSeek = targetWeapons.Main
                            reason = "Closest weapon: Main (" .. stepsToMain .. " steps)"
                        else
                            weaponToSeek = targetWeapons.Off
                            reason = "Closest weapon: Off (" .. stepsToOff .. " steps)"
                        end
                    end
                end
            else
                -- Fallback to normal logic if spell data is not available
                local mainUseful = self:IsWeaponUsefulForSituation(targetWeapons.Main)
                local offUseful = self:IsWeaponUsefulForSituation(targetWeapons.Off)
                
                if mainUseful and offUseful then
                    -- Both are useful, prioritize based on situation
                    local mainPriority = self:GetWeaponPriority(targetWeapons.Main)
                    local offPriority = self:GetWeaponPriority(targetWeapons.Off)
                    
                    if mainPriority > offPriority then
                        weaponToSeek = targetWeapons.Main
                        reason = "Main weapon higher priority (" .. mainPriority .. " vs " .. offPriority .. ")"
                    elseif offPriority > mainPriority then
                        weaponToSeek = targetWeapons.Off
                        reason = "Off weapon higher priority (" .. offPriority .. " vs " .. mainPriority .. ")"
                    else
                        -- Same priority, choose the closer one
                        if stepsToMain <= stepsToOff then
                            weaponToSeek = targetWeapons.Main
                            reason = "Same priority, Main closer (" .. stepsToMain .. " steps)"
                        else
                            weaponToSeek = targetWeapons.Off
                            reason = "Same priority, Off closer (" .. stepsToOff .. " steps)"
                        end
                    end
                elseif mainUseful then
                    weaponToSeek = targetWeapons.Main
                    reason = "Main weapon useful (" .. stepsToMain .. " steps)"
                elseif offUseful then
                    weaponToSeek = targetWeapons.Off
                    reason = "Off weapon useful (" .. stepsToOff .. " steps)"
                else
                    -- Neither is particularly useful, choose the closest
                    if stepsToMain <= stepsToOff then
                        weaponToSeek = targetWeapons.Main
                        reason = "Closest weapon: Main (" .. stepsToMain .. " steps)"
                    else
                        weaponToSeek = targetWeapons.Off
                        reason = "Closest weapon: Off (" .. stepsToOff .. " steps)"
                    end
                end
            end
        end
    end
    
    return weaponToSeek
end

function DepressiveAphelios:IsWeaponUsefulForSituation(weaponType)
    local myHealth = myHero.health / myHero.maxHealth
    local enemyCount = GetEnemyCount(800)
    local targetDistance = self.target and GetDistance(self.target.pos, myHero.pos) or 1000
    
    -- Basic usefulness check based on target combination
    local isBasicUseful = false
    if self.TargetCombination == "Teamfight" then
        isBasicUseful = (weaponType == "Infernum" or weaponType == "Gravitum")
    elseif self.TargetCombination == "DPS" then
        isBasicUseful = (weaponType == "Crescendum" or weaponType == "Calibrum")
    elseif self.TargetCombination == "Poke" then
        isBasicUseful = (weaponType == "Calibrum" or weaponType == "Severum")
    elseif self.TargetCombination == "Kite" then
        isBasicUseful = (weaponType == "Severum" or weaponType == "Gravitum")
    end
    
    if not isBasicUseful then
        return false
    end
    
    -- Advanced usefulness check based on current situation
    if weaponType == "Infernum" then
        -- Infernum is more useful when there are multiple enemies close
        return enemyCount >= 2 and targetDistance < 600
    elseif weaponType == "Gravitum" then
        -- Gravitum is more useful when we need control (multiple enemies or low health)
        return enemyCount >= 2 or myHealth < 0.5
    elseif weaponType == "Crescendum" then
        -- Crescendum is more useful in close combat
        return targetDistance < 400
    elseif weaponType == "Calibrum" then
        -- Calibrum is more useful at medium-long range
        return targetDistance > 500
    elseif weaponType == "Severum" then
        -- Severum is more useful when we need sustain (low health or extended fights)
        return myHealth < 0.7 or enemyCount >= 2
    end
    
    return true -- Default to useful if basic check passes
end

function DepressiveAphelios:GetWeaponPriority(weaponType)
    local myHealth = myHero.health / myHero.maxHealth
    local enemyCount = GetEnemyCount(800)
    local targetDistance = self.target and GetDistance(self.target.pos, myHero.pos) or 1000
    local currentMode = Mode()
    
    -- Base priority (0-10 scale)
    local priority = 5
    
    -- Adjust priority based on weapon type and situation
    if weaponType == "Infernum" then
        priority = 5
        if enemyCount >= 3 then priority = priority + 3 end -- Multiple enemies
        if targetDistance < 500 then priority = priority + 2 end -- Close range
        if currentMode == "Clear" then priority = priority + 1 end -- Good for farming
        
    elseif weaponType == "Gravitum" then
        priority = 4
        if enemyCount >= 2 then priority = priority + 3 end -- Control needed
        if myHealth < 0.6 then priority = priority + 2 end -- Low health
        if currentMode == "Flee" then priority = priority + 2 end -- Good for escape
        
    elseif weaponType == "Crescendum" then
        priority = 6
        if targetDistance < 300 then priority = priority + 3 end -- Close combat
        if enemyCount == 1 then priority = priority + 2 end -- 1v1 situation
        if currentMode == "Combo" then priority = priority + 1 end -- Good for combo
        
    elseif weaponType == "Calibrum" then
        priority = 5
        if targetDistance > 600 then priority = priority + 3 end -- Long range
        if enemyCount == 1 then priority = priority + 2 end -- 1v1 situation
        if currentMode == "Harass" then priority = priority + 1 end -- Good for harass
        
    elseif weaponType == "Severum" then
        priority = 4
        if myHealth < 0.7 then priority = priority + 4 end -- Low health
        if enemyCount >= 2 then priority = priority + 2 end -- Multiple enemies
        if currentMode == "Flee" then priority = priority + 2 end -- Good for escape
    end
    
    -- Additional situational modifiers
    if self.TargetCombination == "Teamfight" and (weaponType == "Infernum" or weaponType == "Gravitum") then
        priority = priority + 2
    elseif self.TargetCombination == "DPS" and (weaponType == "Crescendum" or weaponType == "Calibrum") then
        priority = priority + 2
    elseif self.TargetCombination == "Poke" and (weaponType == "Calibrum" or weaponType == "Severum") then
        priority = priority + 2
    elseif self.TargetCombination == "Kite" and (weaponType == "Severum" or weaponType == "Gravitum") then
        priority = priority + 2
    end
    
    return priority
end

function DepressiveAphelios:GetWeaponOrder(weaponType)
    for weaponName, weaponData in pairs(WeaponTypes) do
        if weaponData.Type == weaponType then
            return weaponData.Order
        end
    end
    return 0
end

function DepressiveAphelios:GetNextWeapon()
    -- Read the E spell data to determine the next weapon in the cycle
    local spellData = myHero:GetSpellData(_E)
    if not spellData or not spellData.name then return nil end
    
    local spellName = spellData.name:lower()
    
    -- Map spell names to weapon types
    if spellName:find("calibrum") then
        return "Calibrum"
    elseif spellName:find("severum") then
        return "Severum"
    elseif spellName:find("gravitum") then
        return "Gravitum"
    elseif spellName:find("infernum") then
        return "Infernum"
    elseif spellName:find("crescendum") then
        return "Crescendum"
    end
    
    return nil
end

function DepressiveAphelios:GetWeaponAfterNext()
    -- Get the weapon that comes after the next weapon
    local nextWeapon = self:GetNextWeapon()
    if not nextWeapon then return nil end
    
    -- Map the cycle: Calibrum -> Severum -> Gravitum -> Infernum -> Crescendum -> Calibrum
    local weaponCycle = {
        ["Calibrum"] = "Severum",
        ["Severum"] = "Gravitum", 
        ["Gravitum"] = "Infernum",
        ["Infernum"] = "Crescendum",
        ["Crescendum"] = "Calibrum"
    }
    
    return weaponCycle[nextWeapon]
end

function DepressiveAphelios:CalculateStepsToWeapon(currentMainOrder, currentOffOrder, targetOrder)
    if currentMainOrder == targetOrder or currentOffOrder == targetOrder then
        return 0 -- Already have the weapon
    end
    
    -- Calculate minimum steps needed to reach target weapon
    local stepsFromMain = self:CalculateStepsBetween(currentMainOrder, targetOrder)
    local stepsFromOff = self:CalculateStepsBetween(currentOffOrder, targetOrder)
    
    return math.min(stepsFromMain, stepsFromOff)
end

function DepressiveAphelios:CalculateStepsBetween(fromOrder, toOrder)
    if fromOrder == 0 or toOrder == 0 then
        return 999 -- Invalid weapon, high cost
    end
    
    local totalWeapons = 5
    local directSteps = math.abs(toOrder - fromOrder)
    local wrapSteps = totalWeapons - directSteps
    
    return math.min(directSteps, wrapSteps)
end

function DepressiveAphelios:Draw()
    if not self.Menu.Draw.UseDraws:Value() then return end
    
    -- Draw attack range
    Draw.Circle(myHero.pos, 225, 1, Draw.Color(255, 0, 191, 255))
    
    if myHero.activeSpell.valid then
        local attacktargetpos = myHero.activeSpell.placementPos
        local vectargetpos = Vector(attacktargetpos.x, attacktargetpos.y, attacktargetpos.z)
        Draw.Circle(vectargetpos, 225, 1, Draw.Color(255, 0, 191, 255))
    end
    
    -- Draw weapon information in different positions (vertical spacing)
    Draw.Text("Main Weapon: " .. self.MainHand, 25, 770, 900, Draw.Color(0xFF32CD32))
    Draw.Text("Off Hand: " .. self.OffHand, 25, 770, 925, Draw.Color(0xFF0000FF))
    
    -- Draw current combination if available
    if self.Menu.Draw.ShowCombination:Value() and self.CurrentCombination ~= "None" then
        local comboColor = Draw.Color(0xFF00FF00)
        local comboText = WeaponCombinations[self.CurrentCombination].Name
        local direction = ""
        if self.MainHand == WeaponCombinations[self.CurrentCombination].Main then
            direction = " (Main-Off)"
        else
            direction = " (Off-Main)"
        end
        Draw.Text("Current: " .. comboText .. direction, 25, 770, 950, comboColor)
    end
    
    -- Draw target combination if different from current
    if self.Menu.Draw.ShowTarget:Value() and self.TargetCombination ~= "None" and self.TargetCombination ~= self.CurrentCombination then
        local targetColor = Draw.Color(0xFFFFFF00)
        local targetText = WeaponCombinations[self.TargetCombination].Name
        Draw.Text("Target: " .. targetText, 25, 770, 975, targetColor)
    end
    

    
    -- Show status message (separate position)
    if self.CurrentCombination == "None" and self.TargetCombination ~= "None" then
        Draw.Text("No active combination - seeking weapons", 25, 1200, 900, Draw.Color(0xFFFF0000))
    elseif self.CurrentCombination ~= "None" and self.CurrentCombination == self.TargetCombination then
        Draw.Text("Optimal combination active", 25, 1200, 900, Draw.Color(0xFF00FF00))
    end
    

end

function DepressiveAphelios:SetMovement(bool)
    if _G.PremiumOrbwalker then
        _G.PremiumOrbwalker:SetAttack(bool)
        _G.PremiumOrbwalker:SetMovement(bool)        
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
    end
end

function DepressiveAphelios:SetAttack(bool)
    if _G.PremiumOrbwalker then
        _G.PremiumOrbwalker:SetAttack(bool)    
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetAttack(bool)
    end
end

function DepressiveAphelios:OnPreAttack(args)
    self.Attacked = 0
end

function DepressiveAphelios:OnPostAttack()
    if self.Attacked == 0 then
        self.Attacked = 1
        self.Casted = 0
    end
end

function DepressiveAphelios:OnPostAttackTick(args)
    if self.Attacked == 0 then
        self.Attacked = 1
        self.Casted = 0
    end
end

function DepressiveAphelios:KS()
    local Qstage = 1
    local Rstage = 1
    local QspellType = self.QSniperSpell
    
    if self.MainHand == "Infernum" then
        QspellType = self.QFlameSpell
        Qstage = 4
        Rstage = 2
    end
    
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if enemy and enemy.team ~= myHero.team and IsValid(enemy) and GetDistance(enemy.pos, myHero.pos) <= 1100 then
            -- KS with Calibrum range attack
            if _G.SDK and _G.SDK.BuffManager:HasBuff(enemy, "aphelioscalibrumbonusrangedebuff") and GetDistance(enemy.pos, myHero.pos) > 650 then
                local AADmg = getdmg("AA", enemy, myHero)
                if _G.SDK and _G.SDK.Orbwalker:CanAttack() and self.Menu.KSMode.UseQPassive:Value() and enemy.health < AADmg then
                    Control.Attack(enemy)
                elseif _G.SDK and _G.SDK.Orbwalker:CanAttack() and Mode() == "Combo" and self.Menu.ComboMode.UseQPassive:Value() and (not IsValid(self.target) or GetDistance(self.target.pos, myHero.pos) > 650) then
                    Control.Attack(enemy)
                elseif _G.SDK and _G.SDK.Orbwalker:CanAttack() and Mode() == "Harass" and self.Menu.HarassMode.UseQPassive:Value() and (not IsValid(self.target) or GetDistance(self.target.pos, myHero.pos) > 650) then
                    Control.Attack(enemy)
                end
            end
            
            -- KS with Q
            if self:CanUse(_Q, "KS") then
                local QDmg = getdmg("Q", enemy, myHero, Qstage, myHero:GetSpellData(_Q).level)
                if enemy.health < QDmg then
                    if CheckPredictionSystem() then
                        -- Use the full spell prediction system that includes collision detection
                        local spellPred = _G.DepressivePrediction.SpellPrediction(QspellType)
                        local prediction = spellPred:GetPrediction(enemy, myHero)
                        
                        if prediction and prediction.CastPosition and prediction.HitChance >= _G.DepressivePrediction.HITCHANCE_NORMAL then
                            Control.CastSpell(HK_Q, {x = prediction.CastPosition.x, y = myHero.pos.y, z = prediction.CastPosition.z})
                        end
                    else
                        -- Fallback prediction
                        Control.CastSpell(HK_Q, enemy.pos)
                    end
                end
            end
            
            -- KS with R
            if self:CanUse(_R, "KS") and GetDistance(enemy.pos, myHero.pos) > 650 then
                local RDmg = getdmg("R", enemy, myHero, Rstage, myHero:GetSpellData(_R).level)
                local AADmg = getdmg("AA", enemy, myHero)
                if enemy.health < RDmg + AADmg * 0.8 then
                    self:UseRAll(enemy)
                end
            end
        end
    end
end

function DepressiveAphelios:GetOffHand()
    if _G.SDK and _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffCalibrum") then
        return "Calibrum" 
    elseif _G.SDK and _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffGravitum") then
        return "Gravitum" 
    elseif _G.SDK and _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffSeverum") then
        return "Severum" 
    elseif _G.SDK and _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffCrescendum") then
        return "Crescendum" 
    elseif _G.SDK and _G.SDK.BuffManager:HasBuff(myHero, "ApheliosOffHandBuffInfernum") then
        return "Infernum" 
    end
    return "None"
end

function DepressiveAphelios:GetGun()
    local spellData = myHero:GetSpellData(_Q)
    if spellData.name == "ApheliosCalibrumQ" then
        return "Calibrum" 
    elseif spellData.name == "ApheliosGravitumQ" then
        return "Gravitum" 
    elseif spellData.name == "ApheliosSeverumQ" then
        return "Severum" 
    elseif spellData.name == "ApheliosCrescendumQ" then
        return "Crescendum" 
    elseif spellData.name == "ApheliosInfernumQ" then
        return "Infernum" 
    end
    return "None"
end

function DepressiveAphelios:UseQSniper(unit)
    if CheckPredictionSystem() then
        -- Use the full spell prediction system that includes collision detection
        local spellPred = _G.DepressivePrediction.SpellPrediction(self.QSniperSpell)
        local prediction = spellPred:GetPrediction(unit, myHero)
        
        if prediction and prediction.CastPosition and prediction.HitChance >= _G.DepressivePrediction.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, {x = prediction.CastPosition.x, y = myHero.pos.y, z = prediction.CastPosition.z})
        else
            -- Fallback to direct cast if prediction fails
            Control.CastSpell(HK_Q, unit.pos)
        end
    else
        -- Fallback prediction
        Control.CastSpell(HK_Q, unit.pos)
    end
end

function DepressiveAphelios:UseRAll(unit)
    if CheckPredictionSystem() then
        -- Use the full spell prediction system that includes collision detection
        local spellPred = _G.DepressivePrediction.SpellPrediction(self.RAllSpell)
        local prediction = spellPred:GetPrediction(unit, myHero)
        
        if prediction and prediction.CastPosition and prediction.HitChance >= _G.DepressivePrediction.HITCHANCE_NORMAL then
            local castPos3D = {x = prediction.CastPosition.x, y = myHero.pos.y, z = prediction.CastPosition.z}
            if GetDistance(castPos3D, myHero.pos) <= SPELL_RANGES.R then
                Control.CastSpell(HK_R, castPos3D)
            end
        else
            -- Fallback to direct cast if prediction fails
            if GetDistance(unit.pos, myHero.pos) <= SPELL_RANGES.R then
                Control.CastSpell(HK_R, unit.pos)
            end
        end
    else
        -- Fallback prediction
        if GetDistance(unit.pos, myHero.pos) <= SPELL_RANGES.R then
            Control.CastSpell(HK_R, unit.pos)
        end
    end
end

function DepressiveAphelios:UseQFlame(unit)
    if CheckPredictionSystem() then
        -- Use the full spell prediction system that includes collision detection
        local spellPred = _G.DepressivePrediction.SpellPrediction(self.QFlameSpell)
        local prediction = spellPred:GetPrediction(unit, myHero)
        
        if prediction and prediction.CastPosition and prediction.HitChance >= _G.DepressivePrediction.HITCHANCE_NORMAL then
            Control.CastSpell(HK_Q, {x = prediction.CastPosition.x, y = myHero.pos.y, z = prediction.CastPosition.z})
        else
            -- Fallback to direct cast if prediction fails
            Control.CastSpell(HK_Q, unit.pos)
        end
    else
        -- Fallback prediction
        Control.CastSpell(HK_Q, unit.pos)
    end
end

function DepressiveAphelios:GetTargetBuffs()
    if self.target then
        self.CanRoot = _G.SDK and _G.SDK.BuffManager:HasBuff(self.target, "ApheliosGravitumDebuff")
        self.CanRange = _G.SDK and _G.SDK.BuffManager:HasBuff(self.target, "aphelioscalibrumbonusrangedebuff")
    end
end

function DepressiveAphelios:CanUse(spell, mode)
    if spell == _Q then
        if mode == "Combo" and Ready(spell) and self.Menu.ComboMode.UseQ:Value() then
            return true
        elseif mode == "Harass" and Ready(spell) and self.Menu.HarassMode.UseQ:Value() then
            return true
        elseif mode == "Clear" and Ready(spell) and self.Menu.ClearMode.UseQ:Value() then
            return true -- Allow Q in Clear mode for farming
        elseif mode == "LastHit" and Ready(spell) and self.Menu.LastHitMode.UseQ:Value() then
            return true -- Allow Q in LastHit mode for securing minions
        elseif mode == "Flee" and Ready(spell) and self.Menu.FleeMode.UseQ:Value() then
            return true -- Allow Q in Flee mode for escape
        elseif mode == "KS" and Ready(spell) and self.MainHand == "Infernum" and self.Menu.KSMode.UseQFlame:Value() then
            return true
        elseif mode == "KS" and Ready(spell) and self.MainHand == "Calibrum" and self.Menu.KSMode.UseQSniper:Value() then
            return true
        end
    elseif spell == _W then
        if mode == "Combo" and Ready(spell) and self.Menu.ComboMode.UseW:Value() then
            return true
        elseif mode == "Harass" and Ready(spell) and self.Menu.HarassMode.UseW:Value() then
            return true
        elseif mode == "Clear" and Ready(spell) and self.Menu.ClearMode.UseW:Value() then
            return true -- Allow W in Clear mode for weapon switching
        elseif mode == "LastHit" and Ready(spell) and self.Menu.LastHitMode.UseW:Value() then
            return true -- Allow W in LastHit mode for weapon switching
        elseif mode == "Flee" and Ready(spell) and self.Menu.FleeMode.UseW:Value() then
            return true -- Allow W in Flee mode for weapon switching
        elseif mode == "KS" and Ready(spell) and self.Menu.KSMode.UseW:Value() then
            return true
        end
    elseif spell == _R then
        if mode == "Combo" and Ready(spell) and self.Menu.ComboMode.UseR:Value() then
            return true
        elseif mode == "Harass" and Ready(spell) then
            return true -- Allow R in Harass mode
        elseif mode == "Clear" and Ready(spell) and self.Menu.ClearMode.UseR:Value() then
            return true -- Allow R in Clear mode for wave clear
        elseif mode == "Flee" and Ready(spell) and self.Menu.FleeMode.UseR:Value() then
            return true -- Allow R in Flee mode for escape
        elseif mode == "KS" and Ready(spell) and self.Menu.KSMode.UseR:Value() then
            return true
        end
    end
    return false
end



function DepressiveAphelios:Combo()
    if not self.target then return end
    
    -- Auto weapon switch logic - WORK IN ALL MODES
    if self.Menu.Combinations.AutoSwitch:Value() and self:ShouldSwitchWeapons() then
        self:SwitchToTargetWeapons()
    end
    
    -- WORK IN ALL ORBWALKER MODES, not just Combo and Harass
    local currentMode = Mode()
    
    -- Combo logic based on combinations - ALL MODES
    if self.CurrentCombination == "Teamfight" then
        self:TeamfightCombo()
    elseif self.CurrentCombination == "DPS" then
        self:DPSCombo()
    elseif self.CurrentCombination == "Poke" then
        self:PokeCombo()
    elseif self.CurrentCombination == "Kite" then
        self:KiteCombo()
    else
        -- Always use default combo when no specific combination
        self:DefaultCombo()
    end
end

function DepressiveAphelios:ShouldSwitchWeapons()
    if not self.AvailableCombinations or #self.AvailableCombinations == 0 then return false end
    
    -- Check if we have any complete combination
    for _, combo in ipairs(self.AvailableCombinations) do
        local targetWeapons = WeaponCombinations[combo.type]
        if targetWeapons then
            local hasMainInMain = (self.MainHand == targetWeapons.Main)
            local hasOffInOff = (self.OffHand == targetWeapons.Off)
            local hasMainInOff = (self.OffHand == targetWeapons.Main)
            local hasOffInMain = (self.MainHand == targetWeapons.Off)
            local hasCompleteCombo = (hasMainInMain and hasOffInOff) or (hasMainInOff and hasOffInMain)
            
            if hasCompleteCombo then
                return false -- We have a complete combination, don't switch
            end
        end
    end
    
    -- Check if any weapon we need is close in the cycle
    local weaponScores = {}
    
    -- Score each weapon based on all available combinations
    for _, combo in ipairs(self.AvailableCombinations) do
        local targetWeapons = WeaponCombinations[combo.type]
        if targetWeapons then
            local mainWeapon = targetWeapons.Main
            local offWeapon = targetWeapons.Off
            
            -- Check if we already have these weapons
            local hasMain = (self.MainHand == mainWeapon or self.OffHand == mainWeapon)
            local hasOff = (self.MainHand == offWeapon or self.OffHand == offWeapon)
            
            -- Score weapons we don't have
            if not hasMain then
                local mainOrder = self:GetWeaponOrder(mainWeapon)
                local mainHandOrder = self:GetWeaponOrder(self.MainHand)
                local offHandOrder = self:GetWeaponOrder(self.OffHand)
                
                local stepsFromMain = self:CalculateStepsBetween(mainHandOrder, mainOrder)
                local stepsFromOff = self:CalculateStepsBetween(offHandOrder, mainOrder)
                local closestSteps = math.min(stepsFromMain, stepsFromOff)
                
                weaponScores[mainWeapon] = (weaponScores[mainWeapon] or 0) + (combo.score / (closestSteps + 1))
            end
            
            if not hasOff then
                local offOrder = self:GetWeaponOrder(offWeapon)
                local mainHandOrder = self:GetWeaponOrder(self.MainHand)
                local offHandOrder = self:GetWeaponOrder(self.OffHand)
                
                local stepsFromMain = self:CalculateStepsBetween(mainHandOrder, offOrder)
                local stepsFromOff = self:CalculateStepsBetween(offHandOrder, offOrder)
                local closestSteps = math.min(stepsFromMain, stepsFromOff)
                
                weaponScores[offWeapon] = (weaponScores[offWeapon] or 0) + (combo.score / (closestSteps + 1))
            end
        end
    end
    
    -- Check if any weapon with high score is close (within 2 steps)
    for weapon, score in pairs(weaponScores) do
        if score > 10 then -- High priority weapon
            local weaponOrder = self:GetWeaponOrder(weapon)
            local mainHandOrder = self:GetWeaponOrder(self.MainHand)
            local offHandOrder = self:GetWeaponOrder(self.OffHand)
            
            local stepsFromMain = self:CalculateStepsBetween(mainHandOrder, weaponOrder)
            local stepsFromOff = self:CalculateStepsBetween(offHandOrder, weaponOrder)
            
            if stepsFromMain <= 2 or stepsFromOff <= 2 then
                return true
            end
        end
    end
    
    -- Only check distance for safety
    local targetDistance = self.target and GetDistance(self.target.pos, myHero.pos) or 1000
    if targetDistance < 150 then return false end
    
    return false
end

function DepressiveAphelios:HasUsefulWeaponForCurrentSituation()
    if not self.AvailableCombinations or #self.AvailableCombinations == 0 then return false end
    
    -- Check if current weapons are useful for any available combination
    for _, combo in ipairs(self.AvailableCombinations) do
        local targetWeapons = WeaponCombinations[combo.type]
        if targetWeapons then
            -- Check if we have either weapon from this combination
            if self.MainHand == targetWeapons.Main or self.OffHand == targetWeapons.Main or
               self.MainHand == targetWeapons.Off or self.OffHand == targetWeapons.Off then
                return true
            end
        end
    end
    
    return false
end

function DepressiveAphelios:IsWeaponCloseInCycle(weaponType)
    -- Check if a weapon is close in the cycle (within 1-2 steps)
    local targetOrder = self:GetWeaponOrder(weaponType)
    local mainOrder = self:GetWeaponOrder(self.MainHand)
    local offOrder = self:GetWeaponOrder(self.OffHand)
    
    local stepsFromMain = self:CalculateStepsBetween(mainOrder, targetOrder)
    local stepsFromOff = self:CalculateStepsBetween(offOrder, targetOrder)
    
    -- Consider "close" if within 2 steps
    return stepsFromMain <= 2 or stepsFromOff <= 2
end

function DepressiveAphelios:SwitchToTargetWeapons()
    if not self.AvailableCombinations or #self.AvailableCombinations == 0 then return end
    
    -- Check if we have any complete combination
    for _, combo in ipairs(self.AvailableCombinations) do
        local targetWeapons = WeaponCombinations[combo.type]
        if targetWeapons then
            local hasMainInMain = (self.MainHand == targetWeapons.Main)
            local hasOffInOff = (self.OffHand == targetWeapons.Off)
            local hasMainInOff = (self.OffHand == targetWeapons.Main)
            local hasOffInMain = (self.MainHand == targetWeapons.Off)
            local hasCompleteCombo = (hasMainInMain and hasOffInOff) or (hasMainInOff and hasOffInMain)
            
            if hasCompleteCombo then
                return -- We have a complete combination, don't switch
            end
        end
    end
    
    -- Find the best weapon to seek based on all available combinations
    local weaponScores = {}
    
    -- Score each weapon based on all available combinations
    for _, combo in ipairs(self.AvailableCombinations) do
        local targetWeapons = WeaponCombinations[combo.type]
        if targetWeapons then
            local mainWeapon = targetWeapons.Main
            local offWeapon = targetWeapons.Off
            
            -- Check if we already have these weapons
            local hasMain = (self.MainHand == mainWeapon or self.OffHand == mainWeapon)
            local hasOff = (self.MainHand == offWeapon or self.OffHand == offWeapon)
            
            -- Score weapons we don't have
            if not hasMain then
                local mainOrder = self:GetWeaponOrder(mainWeapon)
                local mainHandOrder = self:GetWeaponOrder(self.MainHand)
                local offHandOrder = self:GetWeaponOrder(self.OffHand)
                
                local stepsFromMain = self:CalculateStepsBetween(mainHandOrder, mainOrder)
                local stepsFromOff = self:CalculateStepsBetween(offHandOrder, mainOrder)
                local closestSteps = math.min(stepsFromMain, stepsFromOff)
                
                weaponScores[mainWeapon] = (weaponScores[mainWeapon] or 0) + (combo.score / (closestSteps + 1))
            end
            
            if not hasOff then
                local offOrder = self:GetWeaponOrder(offWeapon)
                local mainHandOrder = self:GetWeaponOrder(self.MainHand)
                local offHandOrder = self:GetWeaponOrder(self.OffHand)
                
                local stepsFromMain = self:CalculateStepsBetween(mainHandOrder, offOrder)
                local stepsFromOff = self:CalculateStepsBetween(offHandOrder, offOrder)
                local closestSteps = math.min(stepsFromMain, stepsFromOff)
                
                weaponScores[offWeapon] = (weaponScores[offWeapon] or 0) + (combo.score / (closestSteps + 1))
            end
        end
    end
    
    -- Find the weapon with the highest score
    local bestWeapon = nil
    local bestScore = 0
    
    for weapon, score in pairs(weaponScores) do
        if score > bestScore then
            bestScore = score
            bestWeapon = weapon
        end
    end
    
    -- Only switch if the best weapon is close in the cycle (within 2 steps)
    if bestWeapon then
        local weaponOrder = self:GetWeaponOrder(bestWeapon)
        local mainOrder = self:GetWeaponOrder(self.MainHand)
        local offOrder = self:GetWeaponOrder(self.OffHand)
        
        local stepsFromMain = self:CalculateStepsBetween(mainOrder, weaponOrder)
        local stepsFromOff = self:CalculateStepsBetween(offOrder, weaponOrder)
        
        -- Only switch if the weapon is within 2 steps
        if stepsFromMain <= 2 or stepsFromOff <= 2 then
            -- Switch weapons if W is ready and cooldown is over
            if self:CanUse(_W, Mode()) and self:CanSwitchWeapons() then
                self:SwitchWeapons()
                return
            end
        end
    end
    
    -- If we can't switch weapons, try to consume ammo to cycle faster
    if self:CanUse(_Q, Mode()) and self:ShouldUseQToConsumeAmmo() then
        self:UseQToConsumeAmmo()
    end
end

function DepressiveAphelios:IsGoodTimeToSwitch()
    -- Check if W is ready
    if not Ready(_W) then
        return false
    end
    
    -- Check cooldown (reduced from 5.0 to 2.0 seconds for more aggressive switching)
    if not self.LastWeaponSwitch then
        self.LastWeaponSwitch = 0
    end
    
    if Game.Timer() - self.LastWeaponSwitch < 2.0 then
        return false
    end
    
    -- Only check for extreme situations
    local targetDistance = self.target and GetDistance(self.target.pos, myHero.pos) or 1000
    if targetDistance < 100 then
        return false
    end
    
    -- Allow switching in most situations
    return true
end

function DepressiveAphelios:IsInCriticalSituation()
    local enemyCount = GetEnemyCount(600)
    local targetDistance = self.target and GetDistance(self.target.pos, myHero.pos) or 1000
    
    -- Removed health restrictions - control from 100% health
    -- Only check for extreme situations
    if targetDistance < 150 then return true end
    
    return false
end

function DepressiveAphelios:CanSwitchWeapons()
    -- Check if W is ready
    if not Ready(_W) then
        return false
    end
    
    -- Check cooldown (reduced from 5.0 to 2.0 seconds for more aggressive switching)
    if not self.LastWeaponSwitch then
        self.LastWeaponSwitch = 0
    end
    
    if Game.Timer() - self.LastWeaponSwitch < 2.0 then
        return false
    end
    
    -- Check if it's a good time to switch
    return self:IsGoodTimeToSwitch()
end

function DepressiveAphelios:SwitchWeapons()
    if self:CanSwitchWeapons() then
        Control.CastSpell(HK_W)
        self.LastWeaponSwitch = Game.Timer()
        return true
    end
    return false
end

function DepressiveAphelios:ShouldUseQToConsumeAmmo()
    if not self.AvailableCombinations or #self.AvailableCombinations == 0 then return false end
    
    -- Check if we have any complete combination
    for _, combo in ipairs(self.AvailableCombinations) do
        local targetWeapons = WeaponCombinations[combo.type]
        if targetWeapons then
            local hasMainInMain = (self.MainHand == targetWeapons.Main)
            local hasOffInOff = (self.OffHand == targetWeapons.Off)
            local hasMainInOff = (self.OffHand == targetWeapons.Main)
            local hasOffInMain = (self.MainHand == targetWeapons.Off)
            local hasCompleteCombo = (hasMainInMain and hasOffInOff) or (hasMainInOff and hasOffInMain)
            
            if hasCompleteCombo then
                return false -- We have a complete combination, don't consume anything
            end
        end
    end
    
    -- Find the weapon that's least useful for all combinations
    local weaponScores = {}
    
    -- Initialize scores for current weapons
    weaponScores[self.MainHand] = 0
    weaponScores[self.OffHand] = 0
    
    -- Score each weapon based on all available combinations
    for _, combo in ipairs(self.AvailableCombinations) do
        local targetWeapons = WeaponCombinations[combo.type]
        if targetWeapons then
            -- Check if current weapons are useful for this combination
            if self.MainHand == targetWeapons.Main or self.MainHand == targetWeapons.Off then
                weaponScores[self.MainHand] = weaponScores[self.MainHand] + combo.score
            end
            if self.OffHand == targetWeapons.Main or self.OffHand == targetWeapons.Off then
                weaponScores[self.OffHand] = weaponScores[self.OffHand] + combo.score
            end
        end
    end
    
    -- Find the weapon with the lowest score (least useful)
    local weaponToConsume = nil
    local lowestScore = math.huge
    
    for weapon, score in pairs(weaponScores) do
        if score < lowestScore then
            lowestScore = score
            weaponToConsume = weapon
        end
    end
    
    if weaponToConsume then
        self.WeaponToConsume = weaponToConsume
        return true
    end
    
    return false
end

function DepressiveAphelios:GetWeaponSeekingReason(weaponType)
    local enemyCount = GetEnemyCount(800)
    local targetDistance = self.target and GetDistance(self.target.pos, myHero.pos) or 1000
    
    if weaponType == "Infernum" then
        return "AoE damage for teamfight"
    elseif weaponType == "Gravitum" then
        return "Crowd control for safety"
    elseif weaponType == "Crescendum" then
        return "Sustained damage for 1v1"
    elseif weaponType == "Calibrum" then
        return "Long-range poke"
    elseif weaponType == "Severum" then
        return "Sustain for extended fights"
    end
    
    return nil
end

function DepressiveAphelios:UseQToConsumeAmmo()
    -- Use Q to consume ammo and cycle through weapons faster
    
    -- If we need to consume a specific weapon, switch to it first
    if self.WeaponToConsume and self.WeaponToConsume ~= self.MainHand then
        self:SwitchWeapons()
        return
    end
    
    -- If we don't have a specific weapon to consume, don't consume any weapon
    if not self.WeaponToConsume then
        return
    end
    
    if self.MainHand == "Calibrum" then
        -- Use Calibrum Q on minions or monsters to consume ammo
        local target = self:GetMinionOrMonsterTarget(SPELL_RANGES.QSniper)
        if target then
            self:UseQSniper(target)
        else
            -- Use on ground if no target
            local castPos = myHero.pos + (myHero.pos - myHero.pos):Normalized() * 500
            Control.CastSpell(HK_Q, castPos)
        end
    elseif self.MainHand == "Infernum" then
        -- Use Infernum Q on minions or monsters
        local target = self:GetMinionOrMonsterTarget(SPELL_RANGES.QFlame)
        if target then
            self:UseQFlame(target)
        else
            -- Use on ground if no target
            local castPos = myHero.pos + (myHero.pos - myHero.pos):Normalized() * 300
            Control.CastSpell(HK_Q, castPos)
        end
    elseif self.MainHand == "Crescendum" then
        -- Use Crescendum Q on minions or monsters
        local target = self:GetMinionOrMonsterTarget(SPELL_RANGES.QBounce)
        if target then
            -- Use prediction for Crescendum Q
            if CheckPredictionSystem() then
                local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
                local unitPos, castPos, timeToHit = _G.DepressivePrediction.GetPrediction(
                    target,
                    sourcePos2D,
                    0, -- speed for targeted spell
                    0.25, -- delay
                    100 -- radius
                )
                if castPos and castPos.x and castPos.z then
                    Control.CastSpell(HK_Q, {x = castPos.x, y = myHero.pos.y, z = castPos.z})
                else
                    Control.CastSpell(HK_Q, target.pos)
                end
            else
                Control.CastSpell(HK_Q, target.pos)
            end
        end
    elseif self.MainHand == "Severum" then
        -- Use Severum Q to heal (safe to use)
        Control.CastSpell(HK_Q)
    elseif self.MainHand == "Gravitum" then
        -- Use Gravitum Q on minions or monsters
        local target = self:GetMinionOrMonsterTarget(SPELL_RANGES.QSlow)
        if target then
            -- Gravitum Q is targeted, cast on the target
            Control.CastSpell(HK_Q, target.pos)
        else
            -- If no target, try to cast on ground to consume ammo
            local castPos = myHero.pos + (myHero.pos - myHero.pos):Normalized() * 300
            Control.CastSpell(HK_Q, castPos)
        end
    end
end

function DepressiveAphelios:GetMinionOrMonsterTarget(range)
    -- Get minion or monster target for consuming ammo
    local bestTarget = nil
    local bestDistance = range
    
    -- Check enemy minions first (closest)
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and IsValid(minion) then
            local distance = GetDistance(minion.pos, myHero.pos)
            if distance <= range and distance < bestDistance then
                bestTarget = minion
                bestDistance = distance
            end
        end
    end
    
    -- If no enemy minions, check jungle monsters
    if not bestTarget then
        for i = 1, Game.MinionCount() do
            local monster = Game.Minion(i)
            if monster and monster.team == 300 and IsValid(monster) then
                local distance = GetDistance(monster.pos, myHero.pos)
                if distance <= range and distance < bestDistance then
                    bestTarget = monster
                    bestDistance = distance
                end
            end
        end
    end
    
    return bestTarget
end

function DepressiveAphelios:TeamfightCombo()
    -- Infernum + Gravitum: Control + Massive area damage (both directions)
    if (self.MainHand == "Infernum" and self.OffHand == "Gravitum") or (self.MainHand == "Gravitum" and self.OffHand == "Infernum") then
        -- Use Infernum Q for area damage
        if self.MainHand == "Infernum" and self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QFlame then
            self:UseQFlame(self.target)
        elseif self.OffHand == "Infernum" and self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QFlame then
            -- Switch to use Infernum Q
            self:SwitchWeapons()
        end
        
        -- Use W to switch to Gravitum when needed
        if self:CanUse(_W, Mode()) then
            if GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QSlow then
                if self.MainHand == "Gravitum" then
                    -- Already have Gravitum in main hand
                else
                    self:SwitchWeapons()
                end
            end
        end
        
        -- Use Gravitum Q for control (ALWAYS when available)
        if self.MainHand == "Gravitum" and self:CanUse(_Q, Mode()) then
            if self.CanRoot then
                Control.CastSpell(HK_Q)
            elseif IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QSlow then
                Control.CastSpell(HK_Q, self.target.pos)
            end
        elseif self.OffHand == "Gravitum" and self:CanUse(_Q, Mode()) then
            -- Switch to use Gravitum Q
            self:SwitchWeapons()
        end
        
        -- Use R for massive damage
        if self:CanUse(_R, Mode()) and GetEnemyCount(SPELL_RANGES.R) >= 2 then
            self:UseRAll(self.target)
        end
    end
end

function DepressiveAphelios:DPSCombo()
    -- Crescendum + Calibrum: Chakrams + Range (both directions)
    if (self.MainHand == "Crescendum" and self.OffHand == "Calibrum") or (self.MainHand == "Calibrum" and self.OffHand == "Crescendum") then
        -- Use Crescendum Q to generate chakrams
        if self.MainHand == "Crescendum" and self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QBounce then
            -- Use prediction for Crescendum Q
            if CheckPredictionSystem() then
                local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
                local unitPos, castPos, timeToHit = _G.DepressivePrediction.GetPrediction(
                    self.target,
                    sourcePos2D,
                    0, -- speed for targeted spell
                    0.25, -- delay
                    100 -- radius
                )
                if castPos and castPos.x and castPos.z then
                    Control.CastSpell(HK_Q, {x = castPos.x, y = myHero.pos.y, z = castPos.z})
                else
                    Control.CastSpell(HK_Q, self.target.pos)
                end
            else
                Control.CastSpell(HK_Q, self.target.pos)
            end
        elseif self.OffHand == "Crescendum" and self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QBounce then
            -- Switch to use Crescendum Q
            self:SwitchWeapons()
        end
        
        -- Use W to switch to Calibrum when needed
        if self:CanUse(_W, Mode()) then
            if GetDistance(self.target.pos, myHero.pos) > SPELL_RANGES.QBounce then
                if self.MainHand == "Calibrum" then
                    -- Already have Calibrum in main hand
                else
                    self:SwitchWeapons()
                end
            end
        end
        
        -- Use R for range damage (only with 2+ enemies)
        if self:CanUse(_R, Mode()) and GetEnemyCount(SPELL_RANGES.R) >= 2 and GetDistance(self.target.pos, myHero.pos) > 650 then
            self:UseRAll(self.target)
        end
    end
end

function DepressiveAphelios:PokeCombo()
    -- Calibrum + Severum: Safety + Poke (both directions)
    if (self.MainHand == "Calibrum" and self.OffHand == "Severum") or (self.MainHand == "Severum" and self.OffHand == "Calibrum") then
        -- Use Calibrum Q for poke
        if self.MainHand == "Calibrum" and self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QSniper then
            self:UseQSniper(self.target)
        elseif self.OffHand == "Calibrum" and self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QSniper then
            -- Switch to use Calibrum Q
            self:SwitchWeapons()
        end
        
        -- Use W to switch to Severum when needed
        if self:CanUse(_W, Mode()) then
            if myHero.health < myHero.maxHealth * 0.5 then
                if self.MainHand == "Severum" then
                    -- Already have Severum in main hand
                else
                    self:SwitchWeapons()
                end
            end
        end
        
        -- Use R for range poke (only with 2+ enemies)
        if self:CanUse(_R, Mode()) and GetEnemyCount(SPELL_RANGES.R) >= 2 and GetDistance(self.target.pos, myHero.pos) > 650 then
            self:UseRAll(self.target)
        end
    end
end

function DepressiveAphelios:KiteCombo()
    -- Severum + Gravitum: Healing + Slow (both directions)
    if (self.MainHand == "Severum" and self.OffHand == "Gravitum") or (self.MainHand == "Gravitum" and self.OffHand == "Severum") then
        -- Use Severum Q for healing
        if self.MainHand == "Severum" and self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QHeal then
            Control.CastSpell(HK_Q)
        elseif self.OffHand == "Severum" and self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QHeal then
            -- Switch to use Severum Q
            self:SwitchWeapons()
        end
        
        -- Use W to switch to Gravitum when needed
        if self:CanUse(_W, Mode()) then
            if GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QSlow then
                if self.MainHand == "Gravitum" then
                    -- Already have Gravitum in main hand
                else
                    self:SwitchWeapons()
                end
            end
        end
        
        -- Use Gravitum Q for control (ALWAYS when available)
        if self.MainHand == "Gravitum" and self:CanUse(_Q, Mode()) then
            if self.CanRoot then
                Control.CastSpell(HK_Q)
            elseif IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QSlow then
                Control.CastSpell(HK_Q, self.target.pos)
            end
        elseif self.OffHand == "Gravitum" and self:CanUse(_Q, Mode()) then
            -- Switch to use Gravitum Q
            self:SwitchWeapons()
        end
        
        -- Use R for control
        if self:CanUse(_R, Mode()) and GetEnemyCount(SPELL_RANGES.R) >= 2 then
            self:UseRAll(self.target)
        end
    end
end

function DepressiveAphelios:DefaultCombo()
    -- Default combo when we don't have a specific combination
    if self.MainHand == "Calibrum" then
        -- Use Calibrum Q for poke and damage
        if self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QSniper then
            self:UseQSniper(self.target)
        end
    elseif self.MainHand == "Infernum" then
        -- Use Infernum Q for area damage
        if self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QFlame then
            self:UseQFlame(self.target)
        end
    elseif self.MainHand == "Crescendum" then
        -- Use Crescendum Q for sustained damage
        if self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QBounce then
            -- Use prediction for Crescendum Q
            if CheckPredictionSystem() then
                local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
                local unitPos, castPos, timeToHit = _G.DepressivePrediction.GetPrediction(
                    self.target,
                    sourcePos2D,
                    0, -- speed for targeted spell
                    0.25, -- delay
                    100 -- radius
                )
                if castPos and castPos.x and castPos.z then
                    Control.CastSpell(HK_Q, {x = castPos.x, y = myHero.pos.y, z = castPos.z})
                else
                    Control.CastSpell(HK_Q, self.target.pos)
                end
            else
                Control.CastSpell(HK_Q, self.target.pos)
            end
        end
    elseif self.MainHand == "Severum" then
        -- Use Severum Q for healing
        if self:CanUse(_Q, Mode()) and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QHeal then
            Control.CastSpell(HK_Q)
        end
    elseif self.MainHand == "Gravitum" then
        -- Use Gravitum Q for root - ALWAYS use it when available
        if self:CanUse(_Q, Mode()) then
            if self.CanRoot then
                -- If target has slow debuff, use Q to root
                Control.CastSpell(HK_Q)
            elseif IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.QSlow then
                -- If target is in range, use Q to apply slow
                Control.CastSpell(HK_Q, self.target.pos)
            else
                -- Use Q on ground to apply slow in area
                local castPos = myHero.pos + (myHero.pos - myHero.pos):Normalized() * 300
                Control.CastSpell(HK_Q, castPos)
            end
        end
    end
    
    -- Use R if available and target is in range (only with 2+ enemies)
    if self:CanUse(_R, Mode()) and GetEnemyCount(SPELL_RANGES.R) >= 2 and IsValid(self.target) and GetDistance(self.target.pos, myHero.pos) <= SPELL_RANGES.R then
        self:UseRAll(self.target)
    end
end

function DepressiveAphelios:Harass()
    if not self.target then return end
    if Mode() == "Harass" then
        -- Harass logic similar to combo but less aggressive
        self:DefaultCombo()
    end
end

function DepressiveAphelios:Clear()
    if Mode() == "Clear" then
        -- Clear mode: focus on farming minions and jungle
        local minionTarget = self:GetMinionOrMonsterTarget(SPELL_RANGES.QSniper)
        local enemyRange = self.Menu.ClearMode.EnemyRange:Value()
        local enemyCount = GetEnemyCount(enemyRange)
        
        -- Check if we should only use abilities when enemies are nearby
        local shouldUseAbilities = true
        if self.Menu.ClearMode.OnlyWithEnemies:Value() then
            shouldUseAbilities = (enemyCount > 0)
        end
        
        -- Only use abilities if conditions are met
        if shouldUseAbilities then
            if minionTarget then
                -- Use Q for farming
                if self:CanUse(_Q, Mode()) then
                    if self.MainHand == "Calibrum" then
                        self:UseQSniper(minionTarget)
                    elseif self.MainHand == "Infernum" then
                        self:UseQFlame(minionTarget)
                    elseif self.MainHand == "Crescendum" then
                        -- Use prediction for Crescendum Q
                        if CheckPredictionSystem() then
                            local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
                            local unitPos, castPos, timeToHit = _G.DepressivePrediction.GetPrediction(
                                minionTarget,
                                sourcePos2D,
                                0, -- speed for targeted spell
                                0.25, -- delay
                                100 -- radius
                            )
                            if castPos and castPos.x and castPos.z then
                                Control.CastSpell(HK_Q, {x = castPos.x, y = myHero.pos.y, z = castPos.z})
                            else
                                Control.CastSpell(HK_Q, minionTarget.pos)
                            end
                        else
                            Control.CastSpell(HK_Q, minionTarget.pos)
                        end
                    elseif self.MainHand == "Severum" then
                        Control.CastSpell(HK_Q)
                    elseif self.MainHand == "Gravitum" then
                        Control.CastSpell(HK_Q, minionTarget.pos)
                    end
                end
                
                -- Use R for wave clear if enabled and multiple enemies
                if self:CanUse(_R, Mode()) and enemyCount >= 2 then
                    self:UseRAll(minionTarget)
                end
            end
        else
            -- No enemies nearby or safety mode enabled, just farm with auto attacks
            -- This prevents wasting mana when safe
            if self.Menu.ClearMode.OnlyWithEnemies:Value() and enemyCount == 0 then
                
            end
        end
    end
end

function DepressiveAphelios:LastHit()
    if Mode() == "LastHit" then
        -- LastHit mode: secure minions with low health
        local minionTarget = self:GetMinionOrMonsterTarget(SPELL_RANGES.QSniper)
        
        if minionTarget then
            -- Calculate damage to see if we can kill the minion
            local QDmg = getdmg("Q", minionTarget, myHero, 1, myHero:GetSpellData(_Q).level)
            
            if minionTarget.health <= QDmg then
                -- Use Q to secure the kill
                if self:CanUse(_Q, Mode()) then
                    if self.MainHand == "Calibrum" then
                        self:UseQSniper(minionTarget)
                    elseif self.MainHand == "Infernum" then
                        self:UseQFlame(minionTarget)
                    elseif self.MainHand == "Crescendum" then
                        -- Use prediction for Crescendum Q
                        if CheckPredictionSystem() then
                            local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
                            local unitPos, castPos, timeToHit = _G.DepressivePrediction.GetPrediction(
                                minionTarget,
                                sourcePos2D,
                                0, -- speed for targeted spell
                                0.25, -- delay
                                100 -- radius
                            )
                            if castPos and castPos.x and castPos.z then
                                Control.CastSpell(HK_Q, {x = castPos.x, y = myHero.pos.y, z = castPos.z})
                            else
                                Control.CastSpell(HK_Q, minionTarget.pos)
                            end
                        else
                            Control.CastSpell(HK_Q, minionTarget.pos)
                        end
                    elseif self.MainHand == "Severum" then
                        Control.CastSpell(HK_Q)
                    elseif self.MainHand == "Gravitum" then
                        Control.CastSpell(HK_Q, minionTarget.pos)
                    end
                end
            end
        end
    end
end

function DepressiveAphelios:Flee()
    if Mode() == "Flee" then
        -- Flee mode: escape and survive
        local enemyCount = GetEnemyCount(800)
        
        -- Use Q for escape/self-defense
        if self:CanUse(_Q, Mode()) then
            if self.MainHand == "Calibrum" then
                -- Use Calibrum Q to slow enemies chasing us
                local closestEnemy = self:GetClosestEnemy(SPELL_RANGES.QSniper)
                if closestEnemy then
                    self:UseQSniper(closestEnemy)
                end
            elseif self.MainHand == "Infernum" then
                -- Use Infernum Q for area damage to deter chasers
                local closestEnemy = self:GetClosestEnemy(SPELL_RANGES.QFlame)
                if closestEnemy then
                    self:UseQFlame(closestEnemy)
                end
            elseif self.MainHand == "Severum" then
                -- Use Severum Q for healing
                Control.CastSpell(HK_Q)
            elseif self.MainHand == "Gravitum" then
                -- Use Gravitum Q to root chasers - ALWAYS use it
                local closestEnemy = self:GetClosestEnemy(SPELL_RANGES.QSlow)
                if closestEnemy then
                    if self.CanRoot then
                        Control.CastSpell(HK_Q)
                    else
                        Control.CastSpell(HK_Q, closestEnemy.pos)
                    end
                else
                    -- Use Q on ground to create slow area
                    local castPos = myHero.pos + (myHero.pos - myHero.pos):Normalized() * 300
                    Control.CastSpell(HK_Q, castPos)
                end
            end
        end
        
        -- Use R for escape if multiple enemies
        if self:CanUse(_R, Mode()) and enemyCount >= 2 then
            local closestEnemy = self:GetClosestEnemy(SPELL_RANGES.R)
            if closestEnemy then
                self:UseRAll(closestEnemy)
            end
        end
    end
end

function DepressiveAphelios:GetClosestEnemy(range)
    local closest = nil
    local closestDistance = range
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.team ~= myHero.team and IsValid(hero) then
            local distance = GetDistance(myHero.pos, hero.pos)
            if distance <= range and distance < closestDistance then
                closest = hero
                closestDistance = distance
            end
        end
    end
    
    return closest
end

-- Initialize for DepressiveAIONext
if myHero.charName == "Aphelios" then
    _G.DepressiveApheliosInstance = DepressiveAphelios()
    _G.DepressiveAIONextLoadedChampion = true
end
