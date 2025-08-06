local Heroes = {"All"} -- Works for all heroes

-- Constants and globals
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local myHero = myHero

-- Jungle monsters that can be smited (all keys in lowercase)
local SmiteableMonsters = {
    -- Dragons (multiple possible names)
    ["sru_dragon_air"] = {name = "Air Dragon", priority = 8},
    ["sru_dragon_earth"] = {name = "Earth Dragon", priority = 8},
    ["sru_dragon_fire"] = {name = "Fire Dragon", priority = 8},
    ["sru_dragon_water"] = {name = "Water Dragon", priority = 8},
    ["sru_dragon_elder"] = {name = "Elder Dragon", priority = 10},
    ["sru_dragon_ruined"] = {name = "Ruined Dragon", priority = 8},
    ["sru_dragon_chemtech"] = {name = "Chemtech Dragon", priority = 8},
    ["sru_dragon_hextech"] = {name = "Hextech Dragon", priority = 8},
    
    -- Alternative dragon names (in case of name changes)
    ["sru_dragon_cloud"] = {name = "Cloud Dragon", priority = 8},
    ["sru_dragon_mountain"] = {name = "Mountain Dragon", priority = 8},
    ["sru_dragon_ocean"] = {name = "Ocean Dragon", priority = 8},
    ["sru_dragon_infernal"] = {name = "Infernal Dragon", priority = 8},
    ["sru_dragon_wind"] = {name = "Wind Dragon", priority = 8},
    ["sru_dragon_lightning"] = {name = "Lightning Dragon", priority = 8},
    
    -- Baron and Horde
    ["sru_baron"] = {name = "Baron Nashor", priority = 10},
    ["sru_horde"] = {name = "Voidgrub Horde", priority = 9},
    ["sru_atakhan"] = {name = "Atakhan", priority = 10},
    
    -- Rift Herald
    ["sru_riftherald"] = {name = "Rift Herald", priority = 9},
    
    -- Blue/Red Buff
    ["sru_blue"] = {name = "Blue Sentinel", priority = 7},
    ["sru_red"] = {name = "Red Brambleback", priority = 7},
    
    -- Krugs
    ["sru_krug"] = {name = "Ancient Krug", priority = 5},
    ["sru_krugmini"] = {name = "Krug", priority = 3},
    
    -- Gromp
    ["sru_gromp"] = {name = "Gromp", priority = 5},
    
    -- Wolves
    ["sru_murkwolf"] = {name = "Greater Murk Wolf", priority = 5},
    ["sru_murkwolfmini"] = {name = "Murk Wolf", priority = 3},
    
    -- Raptors
    ["sru_razorbeak"] = {name = "Crimson Raptor", priority = 5},
    ["sru_razorbeakmini"] = {name = "Raptor", priority = 3},
    
    -- River Scuttler
    ["sru_crab"] = {name = "Rift Scuttler", priority = 4}
}

-- Utility functions
local function GetDistance(p1, p2)
    if not p1 or not p2 then return math.huge end
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

local function IsValid(unit)
    return unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and not unit.dead and unit.health > 0
end

local function HasSmite()
    local summ1 = myHero:GetSpellData(SUMMONER_1)
    local summ2 = myHero:GetSpellData(SUMMONER_2)
    
    local smiteNames = {
        "SummonerSmite",
        "S5_SummonerSmiteDuel",
        "S5_SummonerSmitePlayerGanker",
        "SummonerSmiteAvatarOffensive",
        "SummonerSmiteAvatarUtility",
        "SummonerSmiteAvatarDefensive"
    }
    
    for _, smiteName in pairs(smiteNames) do
        if summ1.name == smiteName or summ2.name == smiteName then
            return true
        end
    end
    
    return false
end

local function SmiteReady()
    local summ1 = myHero:GetSpellData(SUMMONER_1)
    local summ2 = myHero:GetSpellData(SUMMONER_2)
    
    local smiteNames = {
        "SummonerSmite",
        "S5_SummonerSmiteDuel",
        "S5_SummonerSmitePlayerGanker",
        "SummonerSmiteAvatarOffensive",
        "SummonerSmiteAvatarUtility",
        "SummonerSmiteAvatarDefensive"
    }
    
    for _, smiteName in pairs(smiteNames) do
        if summ1.name == smiteName then
            return summ1.currentCd == 0
        elseif summ2.name == smiteName then
            return summ2.currentCd == 0
        end
    end
    
    return false
end

local function CastSmite(target)
    -- Verify target is still valid before attempting to cast
    if not target or not IsValid(target) then
        return false
    end
    
    local summ1 = myHero:GetSpellData(SUMMONER_1)
    local summ2 = myHero:GetSpellData(SUMMONER_2)
    
    local smiteNames = {
        "SummonerSmite",
        "S5_SummonerSmiteDuel",
        "S5_SummonerSmitePlayerGanker",
        "SummonerSmiteAvatarOffensive",
        "SummonerSmiteAvatarUtility",
        "SummonerSmiteAvatarDefensive"
    }
    
    for _, smiteName in pairs(smiteNames) do
        if summ1.name == smiteName and summ1.currentCd == 0 then
            Control.CastSpell(HK_SUMMONER_1, target)
            return true
        elseif summ2.name == smiteName and summ2.currentCd == 0 then
            Control.CastSpell(HK_SUMMONER_2, target)
            return true
        end
    end
    
    return false
end

-- AutoSmite Class
class "AutoSmite"

function AutoSmite:__init()
    if not HasSmite() then
        return
    end
    
    self.lastSmiteTick = GetTickCount()
    self.smiteRange = 500
    
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function AutoSmite:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "AutoSmite", name = "AutoSmite - Depressive"})
    
    -- Main Settings
    self.Menu:MenuElement({id = "enabled", name = "Enable AutoSmite", value = true})
    
    -- Monster Priority
    self.Menu:MenuElement({type = MENU, id = "monsters", name = "Monster Settings"})
    self.Menu.monsters:MenuElement({id = "dragon", name = "Auto Smite Dragons", value = true})
    self.Menu.monsters:MenuElement({id = "baron", name = "Auto Smite Baron", value = true})
    self.Menu.monsters:MenuElement({id = "atakhan", name = "Auto Smite Atakhan", value = true})
    self.Menu.monsters:MenuElement({id = "horde", name = "Auto Smite Voidgrub Horde", value = true})
    self.Menu.monsters:MenuElement({id = "herald", name = "Auto Smite Rift Herald", value = true})
    self.Menu.monsters:MenuElement({id = "buffs", name = "Auto Smite Blue/Red Buff", value = true})
    self.Menu.monsters:MenuElement({id = "camps", name = "Auto Smite Jungle Camps", value = false})
    self.Menu.monsters:MenuElement({id = "scuttle", name = "Auto Smite Scuttle Crab", value = false})
    
    -- Safety Settings
    self.Menu:MenuElement({type = MENU, id = "safety", name = "Safety Settings"})
    self.Menu.safety:MenuElement({id = "enemyRange", name = "Check enemy range", value = 1000, min = 500, max = 2000, step = 100})
    self.Menu.safety:MenuElement({id = "onlySecure", name = "Only secure (don't steal)", value = false})
    self.Menu.safety:MenuElement({id = "delayMs", name = "Reaction delay (ms)", value = 0, min = 0, max = 500, step = 25})
    
    -- Drawing
    self.Menu:MenuElement({type = MENU, id = "drawing", name = "Drawing"})
    self.Menu.drawing:MenuElement({id = "smiteRange", name = "Draw Smite Range", value = true})
    self.Menu.drawing:MenuElement({id = "smiteDamage", name = "Show Smite Damage on Monsters", value = true})
    self.Menu.drawing:MenuElement({id = "smiteInfo", name = "Show Smite Info", value = true})
    
    -- Debug
    self.Menu:MenuElement({type = MENU, id = "debug", name = "Debug"})
    self.Menu.debug:MenuElement({id = "printMonsters", name = "Print Monster Names (Console)", value = false})
    self.Menu.debug:MenuElement({id = "showUnknown", name = "Show Unknown Monsters", value = false})
end

function AutoSmite:Draw()
    if myHero.dead then return end
    
    if self.Menu.drawing.smiteRange:Value() and SmiteReady() then
        Draw.Circle(myHero.pos, self.smiteRange, Draw.Color(100, 0xFF, 0xFF, 0x00))
    end
    
    if self.Menu.drawing.smiteInfo:Value() and SmiteReady() then
        local smiteDamage = self:GetSmiteDamage()
        local text = string.format("Smite Damage: %d", smiteDamage)
        local color = Draw.Color(255, 255, 255, 255)
        if smiteDamage == 0 then
            text = "Smite: Not Ready"
            color = Draw.Color(255, 255, 0, 0)
        end
        Draw.Text(text, 20, myHero.pos2D.x - 100, myHero.pos2D.y - 50, color)
    elseif self.Menu.drawing.smiteInfo:Value() and not SmiteReady() then
        local text = "Smite: On Cooldown"
        Draw.Text(text, 20, myHero.pos2D.x - 100, myHero.pos2D.y - 50, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.drawing.smiteDamage:Value() and SmiteReady() then
        local heroPos = myHero.pos
        local smiteRange = self.smiteRange
        
        for i = 1, GameMinionCount() do
            local minion = GameMinion(i)
            local lowerCharName = minion.charName and string.lower(minion.charName) or ""
            if IsValid(minion) and SmiteableMonsters[lowerCharName] then
                local distance = GetDistance(heroPos, minion.pos)
                -- Only draw for monsters in smite range to improve performance
                if distance <= smiteRange then
                    local smiteDamage = self:GetSmiteDamage(minion)
                    local color = Draw.Color(255, 0, 255, 0)
                    if minion.health <= smiteDamage and smiteDamage > 0 then
                        color = Draw.Color(255, 255, 0, 0)
                    end
                    
                    local text = string.format("HP: %d | Smite: %d", math.floor(minion.health), smiteDamage)
                    if smiteDamage == 0 then
                        text = string.format("HP: %d | Smite: CD", math.floor(minion.health))
                        color = Draw.Color(255, 128, 128, 128)
                    end
                    Draw.Text(text, 16, minion.pos2D.x - 50, minion.pos2D.y - 30, color)
                    
                    if minion.health <= smiteDamage and smiteDamage > 0 then
                        Draw.Circle(minion.pos, 100, color)
                    end
                end
            end
        end
    end
end
    end
end

function AutoSmite:Tick()
    -- Primary checks: hero status, chat status, and smite availability
    if myHero.dead or Game.IsChatOpen() or not SmiteReady() then
        return
    end
    
    if not self.Menu.enabled:Value() then return end
    
    -- Respect reaction delay setting
    if self.lastSmiteTick + self.Menu.safety.delayMs:Value() > GetTickCount() then
        return
    end
    
    local target = self:GetBestSmiteTarget()
    if target then
        -- Double check smite is still ready before calculating damage (optimization)
        if not SmiteReady() then
            return
        end
        
        local smiteDamage = self:GetSmiteDamage(target)
        
        if target.health <= smiteDamage then
            if self:IsSafeToSmite(target) then
                -- Final check before casting (safety measure)
                if SmiteReady() and CastSmite(target) then
                    self.lastSmiteTick = GetTickCount()
                end
            end
        end
    end
end

function AutoSmite:GetBestSmiteTarget()
    local bestTarget = nil
    local bestPriority = 0
    local smiteRange = self.smiteRange
    local heroPos = myHero.pos
    
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        
        if IsValid(minion) then
            local lowerCharName = minion.charName and string.lower(minion.charName) or ""
            
            -- Debug: Print all monster names if enabled
            if self.Menu.debug.printMonsters:Value() and minion.charName and minion.charName ~= "" then
                local distance = GetDistance(heroPos, minion.pos)
                if distance <= smiteRange * 2 then  -- Extended range for debug
                    print("DEBUG - Monster found: " .. minion.charName .. " (lower: " .. lowerCharName .. ") | Distance: " .. math.floor(distance))
                end
            end
            
            -- Debug: Show unknown monsters
            if self.Menu.debug.showUnknown:Value() and not SmiteableMonsters[lowerCharName] and minion.charName and minion.charName ~= "" then
                local distance = GetDistance(heroPos, minion.pos)
                if distance <= smiteRange * 2 and string.find(lowerCharName, "sru") then
                    print("UNKNOWN MONSTER: " .. minion.charName .. " (lower: " .. lowerCharName .. ") | Distance: " .. math.floor(distance))
                end
            end
            
            if SmiteableMonsters[lowerCharName] then
                -- Pre-calculate distance once
                local distance = GetDistance(heroPos, minion.pos)
                
                -- Only process if in smite range (optimize by checking distance first)
                if distance <= smiteRange then
                    local smiteDamage = self:GetSmiteDamage(minion)
                    
                    -- Check if can be killed by smite
                    if minion.health <= smiteDamage then
                        local monsterData = SmiteableMonsters[lowerCharName]
                        
                        -- Check if this monster type is enabled
                        if self:IsMonsterTypeEnabled(lowerCharName) then
                            -- Simplified priority calculation (less CPU intensive)
                            local priority = monsterData.priority
                            
                            -- Small bonus for closer monsters
                            if distance < smiteRange * 0.5 then
                                priority = priority + 1
                            end
                            
                            if priority > bestPriority then
                                bestPriority = priority
                                bestTarget = minion
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget
end

function AutoSmite:IsMonsterTypeEnabled(charName)
    -- Convert to lowercase for consistent comparison
    local lowerCharName = string.lower(charName)
    local monsterData = SmiteableMonsters[lowerCharName]
    
    -- Auto-detect dragons and add them if missing
    if string.find(lowerCharName, "sru_dragon") and not monsterData then
        local priority = 8  -- Default dragon priority
        if string.find(lowerCharName, "elder") then
            priority = 10
        end
        SmiteableMonsters[lowerCharName] = {name = charName, priority = priority}
        print("AUTO-DETECTED NEW DRAGON: " .. charName .. " (lower: " .. lowerCharName .. ") | Priority: " .. priority)
        monsterData = SmiteableMonsters[lowerCharName]
    end
    
    if not monsterData then return false end
    
    -- Dragons (expanded detection for all possible dragon names)
    if lowerCharName == "sru_dragon_air" or 
       lowerCharName == "sru_dragon_earth" or 
       lowerCharName == "sru_dragon_fire" or 
       lowerCharName == "sru_dragon_water" or 
       lowerCharName == "sru_dragon_elder" or 
       lowerCharName == "sru_dragon_ruined" or 
       lowerCharName == "sru_dragon_chemtech" or 
       lowerCharName == "sru_dragon_hextech" or
       lowerCharName == "sru_dragon_cloud" or
       lowerCharName == "sru_dragon_mountain" or
       lowerCharName == "sru_dragon_ocean" or
       lowerCharName == "sru_dragon_infernal" or
       lowerCharName == "sru_dragon_wind" or
       lowerCharName == "sru_dragon_lightning" or
       string.find(lowerCharName, "sru_dragon") then  -- Catch-all for any dragon
        return self.Menu.monsters.dragon:Value()
    end
    
    -- Baron
    if lowerCharName == "sru_baron" then
        return self.Menu.monsters.baron:Value()
    end
    
    -- Atakhan
    if lowerCharName == "sru_atakhan" then
        return self.Menu.monsters.atakhan:Value()
    end
    
    -- Voidgrub Horde
    if lowerCharName == "sru_horde" then
        return self.Menu.monsters.horde:Value()
    end
    
    -- Rift Herald
    if lowerCharName == "sru_riftherald" then
        return self.Menu.monsters.herald:Value()
    end
    
    -- Blue/Red Buffs
    if lowerCharName == "sru_blue" or lowerCharName == "sru_red" then
        return self.Menu.monsters.buffs:Value()
    end
    
    -- Scuttle Crab
    if lowerCharName == "sru_crab" then
        return self.Menu.monsters.scuttle:Value()
    end
    
    -- Other jungle camps
    return self.Menu.monsters.camps:Value()
end

function AutoSmite:IsSafeToSmite(target)
    -- Always safe if we don't care about enemies
    if self.Menu.safety.enemyRange:Value() == 0 then
        return true
    end
    
    -- Check for nearby enemies
    local enemyRange = self.Menu.safety.enemyRange:Value()
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if IsValid(hero) and hero.isEnemy then
            local distance = GetDistance(target.pos, hero.pos)
            if distance <= enemyRange then
                -- If "only secure" is enabled, don't smite if enemies are nearby
                if self.Menu.safety.onlySecure:Value() then
                    return false
                end
                
                -- Otherwise, it's still safe (we can steal)
                return true
            end
        end
    end
    
    return true
end

function AutoSmite:GetSmiteSlot()
    local summ1 = myHero:GetSpellData(SUMMONER_1)
    local summ2 = myHero:GetSpellData(SUMMONER_2)
    
    if summ1.name == "SummonerSmite" or 
       summ1.name == "S5_SummonerSmiteDuel" or
       summ1.name == "S5_SummonerSmitePlayerGanker" or
       summ1.name == "SummonerSmiteAvatarOffensive" or
       summ1.name == "SummonerSmiteAvatarUtility" or
       summ1.name == "SummonerSmiteAvatarDefensive" then
        return SUMMONER_1
    elseif summ2.name == "SummonerSmite" or 
           summ2.name == "S5_SummonerSmiteDuel" or
           summ2.name == "S5_SummonerSmitePlayerGanker" or
           summ2.name == "SummonerSmiteAvatarOffensive" or
           summ2.name == "SummonerSmiteAvatarUtility" or
           summ2.name == "SummonerSmiteAvatarDefensive" then
        return SUMMONER_2
    end
    return nil
end

function AutoSmite:GetSmiteDamage(unit)
    -- Return 0 damage if smite is not ready
    if not SmiteReady() then
        return 0
    end
    
    local SmiteDamage = 600
    local SmiteUnleashedDamage = 900
    local SmitePrimalDamage = 1200
    local SmiteAdvDamageHero = 80 + 80 / 17 * (myHero.levelData.lvl - 1)
    
    local smiteSlot = self:GetSmiteSlot()
    if not smiteSlot then return 0 end
    
    local smiteSpell = myHero:GetSpellData(smiteSlot)
    if not smiteSpell then return 0 end
    
    if unit and unit.type == Obj_AI_Hero then
        if smiteSpell.name == "S5_SummonerSmiteDuel" or
           smiteSpell.name == "S5_SummonerSmitePlayerGanker" then
            return SmiteAdvDamageHero
        elseif smiteSpell.name == 'SummonerSmiteAvatarOffensive' or
               smiteSpell.name == 'SummonerSmiteAvatarUtility' or
               smiteSpell.name == 'SummonerSmiteAvatarDefensive' then
            return SmiteAdvDamageHero
        end
    else
        if smiteSpell.name == "SummonerSmite" then
            return SmiteDamage
        elseif smiteSpell.name == "S5_SummonerSmiteDuel" or
               smiteSpell.name == "S5_SummonerSmitePlayerGanker" then
            return SmiteUnleashedDamage
        elseif smiteSpell.name == 'SummonerSmiteAvatarOffensive' or
               smiteSpell.name == 'SummonerSmiteAvatarUtility' or
               smiteSpell.name == 'SummonerSmiteAvatarDefensive' then
            return SmitePrimalDamage
        end
    end
    
    return 0
end

-- Initialize the script
DelayAction(function()
    if HasSmite() then
        _G.AutoSmite = AutoSmite()
    else
        print("AutoSmite: Smite not found, script not loaded")
    end
end, 3.0)
