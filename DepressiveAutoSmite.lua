local Heroes = {"All"} -- Works for all heroes

-- Constants and globals
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local myHero = myHero

-- Jungle monsters that can be smited
local SmiteableMonsters = {
    -- Dragons
    ["SRU_Dragon_Air"] = {name = "Air Dragon", priority = 8},
    ["SRU_Dragon_Earth"] = {name = "Earth Dragon", priority = 8},
    ["SRU_Dragon_Fire"] = {name = "Fire Dragon", priority = 8},
    ["SRU_Dragon_Water"] = {name = "Water Dragon", priority = 8},
    ["SRU_Dragon_Elder"] = {name = "Elder Dragon", priority = 10},
    ["SRU_Dragon_Ruined"] = {name = "Ruined Dragon", priority = 8},
    ["SRU_Dragon_Chemtech"] = {name = "Chemtech Dragon", priority = 8},
    ["SRU_Dragon_Hextech"] = {name = "Hextech Dragon", priority = 8},
    
    -- Baron and Horde
    ["SRU_Baron"] = {name = "Baron Nashor", priority = 10},
    ["SRU_Horde"] = {name = "Voidgrub Horde", priority = 9},
    ["SRU_Atakhan"] = {name = "Atakhan", priority = 10},
    
    -- Rift Herald
    ["SRU_RiftHerald"] = {name = "Rift Herald", priority = 9},
    
    -- Blue/Red Buff
    ["SRU_Blue"] = {name = "Blue Sentinel", priority = 7},
    ["SRU_Red"] = {name = "Red Brambleback", priority = 7},
    
    -- Krugs
    ["SRU_Krug"] = {name = "Ancient Krug", priority = 5},
    ["SRU_KrugMini"] = {name = "Krug", priority = 3},
    
    -- Gromp
    ["SRU_Gromp"] = {name = "Gromp", priority = 5},
    
    -- Wolves
    ["SRU_Murkwolf"] = {name = "Greater Murk Wolf", priority = 5},
    ["SRU_MurkwolfMini"] = {name = "Murk Wolf", priority = 3},
    
    -- Raptors
    ["SRU_Razorbeak"] = {name = "Crimson Raptor", priority = 5},
    ["SRU_RazorbeakMini"] = {name = "Raptor", priority = 3},
    
    -- River Scuttler
    ["Sru_Crab"] = {name = "Rift Scuttler", priority = 4}
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
    self.Menu:MenuElement({id = "keyToggle", name = "Toggle Key", key = string.byte("F"), toggle = true, value = false})
    self.Menu:MenuElement({id = "onlyKey", name = "Only when key pressed", value = false})
    
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
end

function AutoSmite:Draw()
    if myHero.dead then return end
    
    if self.Menu.drawing.smiteRange:Value() and SmiteReady() then
        Draw.Circle(myHero.pos, self.smiteRange, Draw.Color(100, 0xFF, 0xFF, 0x00))
    end
    
    if self.Menu.drawing.smiteInfo:Value() then
        local smiteDamage = self:GetSmiteDamage()
        local text = string.format("Smite Damage: %d", smiteDamage)
        Draw.Text(text, 20, myHero.pos2D.x - 100, myHero.pos2D.y - 50, Draw.Color(255, 255, 255, 255))
    end
    
    if self.Menu.drawing.smiteDamage:Value() then
        for i = 1, GameMinionCount() do
            local minion = GameMinion(i)
            if IsValid(minion) and SmiteableMonsters[minion.charName] then
                local distance = GetDistance(myHero.pos, minion.pos)
                if distance <= 1500 then
                    local smiteDamage = self:GetSmiteDamage(minion)
                    local color = Draw.Color(255, 0, 255, 0)
                    if minion.health <= smiteDamage then
                        color = Draw.Color(255, 255, 0, 0)
                    end
                    
                    local text = string.format("HP: %d | Smite: %d", math.floor(minion.health), smiteDamage)
                    Draw.Text(text, 16, minion.pos2D.x - 50, minion.pos2D.y - 30, color)
                    
                    if minion.health <= smiteDamage and distance <= self.smiteRange then
                        Draw.Circle(minion.pos, 100, color)
                    end
                end
            end
        end
    end
end

function AutoSmite:Tick()
    if myHero.dead or Game.IsChatOpen() or not SmiteReady() then
        return
    end
    
    if not self.Menu.enabled:Value() then return end
    
    if self.Menu.onlyKey:Value() and not self.Menu.keyToggle:Value() then
        return
    end
    
    if self.lastSmiteTick + self.Menu.safety.delayMs:Value() > GetTickCount() then
        return
    end
    
    local target = self:GetBestSmiteTarget()
    if target then
        local smiteDamage = self:GetSmiteDamage(target)
        
        if target.health <= smiteDamage then
            if self:IsSafeToSmite(target) then
                if CastSmite(target) then
                    self.lastSmiteTick = GetTickCount()
                end
            end
        end
    end
end

function AutoSmite:GetBestSmiteTarget()
    local bestTarget = nil
    local bestPriority = 0
    
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        
        if IsValid(minion) and SmiteableMonsters[minion.charName] then
            local distance = GetDistance(myHero.pos, minion.pos)
            local smiteDamage = self:GetSmiteDamage(minion)
            
            -- Check if in smite range and can be killed by smite
            if distance <= self.smiteRange and minion.health <= smiteDamage then
                local monsterData = SmiteableMonsters[minion.charName]
                
                -- Check if this monster type is enabled
                if self:IsMonsterTypeEnabled(minion.charName) then
                    -- Priority based on monster importance and health percentage
                    local priority = monsterData.priority
                    
                    -- Prioritize monsters that are closer to death
                    local healthPercentage = minion.health / minion.maxHealth
                    priority = priority + (1 - healthPercentage) * 2
                    
                    -- Prioritize closer monsters slightly
                    priority = priority + (1 - distance / self.smiteRange) * 0.5
                    
                    if priority > bestPriority then
                        bestPriority = priority
                        bestTarget = minion
                    end
                end
            end
        end
    end
    
    return bestTarget
end

function AutoSmite:IsMonsterTypeEnabled(charName)
    local monsterData = SmiteableMonsters[charName]
    if not monsterData then return false end
    
    -- Dragons
    if charName:find("Dragon") then
        return self.Menu.monsters.dragon:Value()
    end
    
    -- Baron
    if charName == "SRU_Baron" then
        return self.Menu.monsters.baron:Value()
    end
    
    -- Atakhan
    if charName == "SRU_Atakhan" then
        return self.Menu.monsters.atakhan:Value()
    end
    
    -- Voidgrub Horde
    if charName == "SRU_Horde" then
        return self.Menu.monsters.horde:Value()
    end
    
    -- Rift Herald
    if charName == "SRU_RiftHerald" then
        return self.Menu.monsters.herald:Value()
    end
    
    -- Blue/Red Buffs
    if charName == "SRU_Blue" or charName == "SRU_Red" then
        return self.Menu.monsters.buffs:Value()
    end
    
    -- Scuttle Crab
    if charName == "Sru_Crab" then
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