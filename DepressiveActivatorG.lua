-- Cargar librerías necesarias
require "MapPositionGOS"

-- Configuración del menú
local menu = MenuElement({id = "DepressiveActivator", name = "Depressive Activator", type = MENU})
menu:MenuElement({id = "enabled", name = "Enable Script", value = true})

-- Verificar que el juego esté cargado
if not myHero then return end

-- Variables para casting global
local castSpell = {state = 0, tick = GetTickCount(), casting = GetTickCount() - 1000, mouse = mousePos}

-- Función para obtener distancia
local function GetDistance(p1, p2)
    if not p1 or not p2 then return math.huge end
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return math.sqrt(dx * dx + dz * dz)
end

-- Función para casting global (basada en SimbleActivator)
local function CastSpellMM(spell, pos, range, delay)
    local range = range or math.huge
    local delay = delay or 250
    local ticker = GetTickCount()
    
    if castSpell.state == 0 and GetDistance(myHero.pos, pos) < range and ticker - castSpell.casting > delay + Game.Latency() then
        castSpell.state = 1
        castSpell.mouse = mousePos
        castSpell.tick = ticker
    end
    
    if castSpell.state == 1 then
        if ticker - castSpell.tick < Game.Latency() then
            local castPosMM = pos:ToMM()
            if castPosMM then
                Control.SetCursorPos(castPosMM.x, castPosMM.y)
                Control.KeyDown(spell)
                Control.KeyUp(spell)
                castSpell.casting = ticker + delay
                DelayAction(function()
                    if castSpell.state == 1 then
                        Control.SetCursorPos(castSpell.mouse)
                        castSpell.state = 0
                    end
                end, Game.Latency()/1000)
            end
        end
        if ticker - castSpell.casting > Game.Latency() then
            Control.SetCursorPos(castSpell.mouse)
            castSpell.state = 0
        end
    end
end

-- Función para verificar line of sight usando MapPosition
local function HasLineOfSight(startPos, endPos)
    if MapPosition then
        return MapPosition:inWall(startPos) == false and MapPosition:inWall(endPos) == false
    end
    -- Fallback simple si no hay librería disponible
    return true
end

-- Auto Activator Menu
menu:MenuElement({id = "autoActivator", name = "Auto Items Activator", type = MENU})
menu.autoActivator:MenuElement({id = "enabled", name = "Enable Auto Activator", value = true})

-- Support Items Menu
menu.autoActivator:MenuElement({id = "supportItems", name = "Support Items", type = MENU})

menu.autoActivator.supportItems:MenuElement({id = "redencion", name = "Auto Redemption (3107)", type = MENU})
menu.autoActivator.supportItems.redencion:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.supportItems.redencion:MenuElement({id = "allyHpPct", name = "If ally HP% lower than", value = 25, min = 5, max = 95, step = 5})
menu.autoActivator.supportItems.redencion:MenuElement({id = "myHpPct", name = "If my HP% lower than", value = 30, min = 5, max = 95, step = 5})
menu.autoActivator.supportItems.redencion:MenuElement({id = "drawRange", name = "Draw Redemption Range", value = true})
menu.autoActivator.supportItems.redencion:MenuElement({id = "maxRange", name = "Max Cast Range", value = 5500, min = 1000, max = 5500, step = 250})
menu.autoActivator.supportItems.redencion:MenuElement({id = "globalCast", name = "Enable Global Cast", value = true})

menu.autoActivator.supportItems:MenuElement({id = "locket", name = "Auto Locket of Solari (3190)", type = MENU})
menu.autoActivator.supportItems.locket:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.supportItems.locket:MenuElement({id = "allyHpPct", name = "If ally HP% lower than", value = 30, min = 5, max = 95, step = 5})
menu.autoActivator.supportItems.locket:MenuElement({id = "myHpPct", name = "If my HP% lower than", value = 35, min = 5, max = 95, step = 5})
menu.autoActivator.supportItems.locket:MenuElement({id = "allyCount", name = "If allies nearby >=", value = 1, min = 0, max = 4, step = 1})

menu.autoActivator.supportItems:MenuElement({id = "mikaels", name = "Auto Mikael's Blessing (3222)", type = MENU})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "removeCCTypes", name = "Remove CC types", value = true})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "allyHpPct", name = "If ally HP% lower than", value = 60, min = 5, max = 95, step = 5})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "range", name = "Ally range", value = 600, min = 400, max = 1000, step = 50})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "ccStun", name = "Remove Stun", value = true})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "ccSnare", name = "Remove Snare/Root", value = true})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "ccTaunt", name = "Remove Taunt", value = true})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "ccCharm", name = "Remove Charm", value = true})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "ccFear", name = "Remove Fear", value = true})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "ccSuppression", name = "Remove Suppression", value = true})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "ccSilence", name = "Remove Silence", value = true})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "ccSlow", name = "Remove Slow", value = false})
menu.autoActivator.supportItems.mikaels:MenuElement({id = "ccKnockdown", name = "Remove Knockdown", value = true})

menu.autoActivator.supportItems:MenuElement({id = "promesa", name = "Auto Knight's Vow (3109)", type = MENU})
menu.autoActivator.supportItems.promesa:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.supportItems.promesa:MenuElement({id = "allyHpPct", name = "If ally HP% lower than", value = 35, min = 5, max = 95, step = 5})
menu.autoActivator.supportItems.promesa:MenuElement({id = "range", name = "Ally range", value = 800, min = 400, max = 1200, step = 50})

menu.autoActivator.supportItems:MenuElement({id = "shurelya", name = "Auto Shurelya (2065)", type = MENU})
menu.autoActivator.supportItems.shurelya:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.supportItems.shurelya:MenuElement({id = "enemyRange", name = "If enemy closer than", value = 800, min = 400, max = 1200, step = 50})
menu.autoActivator.supportItems.shurelya:MenuElement({id = "allyCount", name = "If allies nearby >=", value = 1, min = 0, max = 4, step = 1})

-- Fighter Items Menu
menu.autoActivator:MenuElement({id = "fighterItems", name = "Fighter Items", type = MENU})

menu.autoActivator.fighterItems:MenuElement({id = "tiamat", name = "Auto Tiamat (3077)", type = MENU})
menu.autoActivator.fighterItems.tiamat:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.fighterItems.tiamat:MenuElement({id = "enemyCount", name = "If enemies nearby >=", value = 2, min = 1, max = 5, step = 1})
menu.autoActivator.fighterItems.tiamat:MenuElement({id = "range", name = "Detection range", value = 400, min = 200, max = 800, step = 50})

menu.autoActivator.fighterItems:MenuElement({id = "profanehydra", name = "Auto Profane Hydra (6698)", type = MENU})
menu.autoActivator.fighterItems.profanehydra:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.fighterItems.profanehydra:MenuElement({id = "enemyCount", name = "If enemies nearby >=", value = 2, min = 1, max = 5, step = 1})
menu.autoActivator.fighterItems.profanehydra:MenuElement({id = "range", name = "Detection range", value = 400, min = 200, max = 800, step = 50})

menu.autoActivator.fighterItems:MenuElement({id = "ravenoushydra", name = "Auto Ravenous Hydra (3074)", type = MENU})
menu.autoActivator.fighterItems.ravenoushydra:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.fighterItems.ravenoushydra:MenuElement({id = "enemyCount", name = "If enemies nearby >=", value = 2, min = 1, max = 5, step = 1})
menu.autoActivator.fighterItems.ravenoushydra:MenuElement({id = "range", name = "Detection range", value = 400, min = 200, max = 800, step = 50})

menu.autoActivator.fighterItems:MenuElement({id = "titanichydra", name = "Auto Titanic Hydra (3748)", type = MENU})
menu.autoActivator.fighterItems.titanichydra:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.fighterItems.titanichydra:MenuElement({id = "enemyCount", name = "If enemies nearby >=", value = 2, min = 1, max = 5, step = 1})
menu.autoActivator.fighterItems.titanichydra:MenuElement({id = "range", name = "Detection range", value = 400, min = 200, max = 800, step = 50})

menu.autoActivator.fighterItems:MenuElement({id = "stridebreaker", name = "Auto Stridebreaker (6631)", type = MENU})
menu.autoActivator.fighterItems.stridebreaker:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.fighterItems.stridebreaker:MenuElement({id = "enemyCount", name = "If enemies nearby >=", value = 1, min = 1, max = 5, step = 1})
menu.autoActivator.fighterItems.stridebreaker:MenuElement({id = "range", name = "Detection range", value = 600, min = 300, max = 900, step = 50})
menu.autoActivator.fighterItems.stridebreaker:MenuElement({id = "useInCombo", name = "Only in combo", value = true})

menu.autoActivator.fighterItems:MenuElement({id = "youmu", name = "Auto Youmuu's Ghostblade (3142)", type = MENU})
menu.autoActivator.fighterItems.youmu:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.fighterItems.youmu:MenuElement({id = "enemyRange", name = "If enemy closer than", value = 700, min = 400, max = 1000, step = 50})
menu.autoActivator.fighterItems.youmu:MenuElement({id = "useInCombo", name = "Only in combo", value = true})

menu.autoActivator.fighterItems:MenuElement({id = "rocketbelt", name = "Auto Hextech Rocketbelt (3152)", type = MENU})
menu.autoActivator.fighterItems.rocketbelt:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.fighterItems.rocketbelt:MenuElement({id = "useInCombo", name = "Only in combo", value = false})

-- Defensive Items Menu
menu.autoActivator:MenuElement({id = "defensiveItems", name = "Defensive Items", type = MENU})

menu.autoActivator.defensiveItems:MenuElement({id = "stopwatch", name = "Auto Stopwatch (2420)", type = MENU})
menu.autoActivator.defensiveItems.stopwatch:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.defensiveItems.stopwatch:MenuElement({id = "myHpPct", name = "If my HP% lower than", value = 15, min = 5, max = 50, step = 5})
menu.autoActivator.defensiveItems.stopwatch:MenuElement({id = "enemyCount", name = "If enemies nearby >=", value = 1, min = 1, max = 5, step = 1})

menu.autoActivator.defensiveItems:MenuElement({id = "zhonya", name = "Auto Zhonya's Hourglass (3157)", type = MENU})
menu.autoActivator.defensiveItems.zhonya:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.defensiveItems.zhonya:MenuElement({id = "myHpPct", name = "If my HP% lower than", value = 25, min = 5, max = 50, step = 5})
menu.autoActivator.defensiveItems.zhonya:MenuElement({id = "enemyCount", name = "If enemies nearby >=", value = 1, min = 1, max = 5, step = 1})

menu.autoActivator.defensiveItems:MenuElement({id = "randuin", name = "Auto Randuin's Omen (3143)", type = MENU})
menu.autoActivator.defensiveItems.randuin:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.defensiveItems.randuin:MenuElement({id = "enemyCount", name = "If enemies nearby >=", value = 2, min = 1, max = 5, step = 1})
menu.autoActivator.defensiveItems.randuin:MenuElement({id = "range", name = "Detection range", value = 500, min = 300, max = 700, step = 50})

-- Cleanse Items Menu
menu.autoActivator:MenuElement({id = "cleanseItems", name = "CC Cleanse Items", type = MENU})

menu.autoActivator.cleanseItems:MenuElement({id = "fajin", name = "Auto Quicksilver (3140)", type = MENU})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "removeCCTypes", name = "Remove CC types", value = true})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "ccStun", name = "Remove Stun", value = true})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "ccSnare", name = "Remove Snare/Root", value = true})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "ccTaunt", name = "Remove Taunt", value = true})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "ccCharm", name = "Remove Charm", value = true})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "ccFear", name = "Remove Fear", value = true})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "ccSuppression", name = "Remove Suppression", value = true})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "ccSilence", name = "Remove Silence", value = true})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "ccSlow", name = "Remove Slow", value = false})
menu.autoActivator.cleanseItems.fajin:MenuElement({id = "ccKnockdown", name = "Remove Knockdown", value = true})

menu.autoActivator.cleanseItems:MenuElement({id = "cimitarra", name = "Auto Mercurial Scimitar (3139)", type = MENU})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "removeCCTypes", name = "Remove CC types", value = true})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "ccStun", name = "Remove Stun", value = true})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "ccSnare", name = "Remove Snare/Root", value = true})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "ccTaunt", name = "Remove Taunt", value = true})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "ccCharm", name = "Remove Charm", value = true})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "ccFear", name = "Remove Fear", value = true})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "ccSuppression", name = "Remove Suppression", value = true})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "ccSilence", name = "Remove Silence", value = true})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "ccSlow", name = "Remove Slow", value = false})
menu.autoActivator.cleanseItems.cimitarra:MenuElement({id = "ccKnockdown", name = "Remove Knockdown", value = true})

-- Consumable Items Menu
menu.autoActivator:MenuElement({id = "consumableItems", name = "Consumable Items", type = MENU})

menu.autoActivator.consumableItems:MenuElement({id = "healthpot", name = "Auto Health Potion (2003)", type = MENU})
menu.autoActivator.consumableItems.healthpot:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.consumableItems.healthpot:MenuElement({id = "myHpPct", name = "If my HP% lower than", value = 50, min = 5, max = 95, step = 5})

menu.autoActivator.consumableItems:MenuElement({id = "refillpot", name = "Auto Refillable Potion (2031)", type = MENU})
menu.autoActivator.consumableItems.refillpot:MenuElement({id = "enabled", name = "Enable", value = true})
menu.autoActivator.consumableItems.refillpot:MenuElement({id = "myHpPct", name = "If my HP% lower than", value = 50, min = 5, max = 95, step = 5})

-- Summoners Activator Menu
menu:MenuElement({id = "summonersActivator", name = "Summoners Activator", type = MENU})
menu.summonersActivator:MenuElement({id = "enabled", name = "Enable Summoners Activator", value = true})

-- Auto summoners configuration
menu.summonersActivator:MenuElement({id = "heal", name = "Auto Heal", type = MENU})
menu.summonersActivator.heal:MenuElement({id = "enabled", name = "Enable", value = true})
menu.summonersActivator.heal:MenuElement({id = "myHpPct", name = "If my HP% lower than", value = 25, min = 5, max = 95, step = 5})
menu.summonersActivator.heal:MenuElement({id = "allyHpPct", name = "If ally HP% lower than", value = 30, min = 5, max = 95, step = 5})
menu.summonersActivator.heal:MenuElement({id = "allyRange", name = "Ally detection range", value = 850, min = 400, max = 1200, step = 50})

menu.summonersActivator:MenuElement({id = "barrier", name = "Auto Barrier", type = MENU})
menu.summonersActivator.barrier:MenuElement({id = "enabled", name = "Enable", value = true})
menu.summonersActivator.barrier:MenuElement({id = "myHpPct", name = "If my HP% lower than", value = 20, min = 5, max = 95, step = 5})
menu.summonersActivator.barrier:MenuElement({id = "enemyCount", name = "If enemies nearby >=", value = 1, min = 1, max = 5, step = 1})

menu.summonersActivator:MenuElement({id = "cleanse", name = "Auto Cleanse", type = MENU})
menu.summonersActivator.cleanse:MenuElement({id = "enabled", name = "Enable", value = true})
menu.summonersActivator.cleanse:MenuElement({id = "removeCCTypes", name = "Remove CC types", value = true})
menu.summonersActivator.cleanse:MenuElement({id = "ccStun", name = "Remove Stun", value = true})
menu.summonersActivator.cleanse:MenuElement({id = "ccSnare", name = "Remove Snare/Root", value = true})
menu.summonersActivator.cleanse:MenuElement({id = "ccTaunt", name = "Remove Taunt", value = true})
menu.summonersActivator.cleanse:MenuElement({id = "ccCharm", name = "Remove Charm", value = true})
menu.summonersActivator.cleanse:MenuElement({id = "ccFear", name = "Remove Fear", value = true})
menu.summonersActivator.cleanse:MenuElement({id = "ccSuppression", name = "Remove Suppression", value = true})
menu.summonersActivator.cleanse:MenuElement({id = "ccSilence", name = "Remove Silence", value = true})
menu.summonersActivator.cleanse:MenuElement({id = "ccSlow", name = "Remove Slow", value = false})
menu.summonersActivator.cleanse:MenuElement({id = "ccKnockdown", name = "Remove Knockdown", value = true})

menu.summonersActivator:MenuElement({id = "ghost", name = "Auto Ghost", type = MENU})
menu.summonersActivator.ghost:MenuElement({id = "enabled", name = "Enable", value = true})
menu.summonersActivator.ghost:MenuElement({id = "enemyRange", name = "If enemy closer than", value = 800, min = 400, max = 1200, step = 50})
menu.summonersActivator.ghost:MenuElement({id = "useInCombo", name = "Only in combo", value = true})

menu.summonersActivator:MenuElement({id = "exhaust", name = "Auto Exhaust", type = MENU})
menu.summonersActivator.exhaust:MenuElement({id = "enabled", name = "Enable", value = true})
menu.summonersActivator.exhaust:MenuElement({id = "enemyRange", name = "Enemy range", value = 650, min = 400, max = 800, step = 50})
menu.summonersActivator.exhaust:MenuElement({id = "myHpPct", name = "If my HP% lower than", value = 40, min = 5, max = 95, step = 5})
menu.summonersActivator.exhaust:MenuElement({id = "targetHighestDamage", name = "Target highest damage dealer", value = true})

menu.summonersActivator:MenuElement({id = "ignite", name = "Auto Ignite", type = MENU})
menu.summonersActivator.ignite:MenuElement({id = "enabled", name = "Enable", value = true})
menu.summonersActivator.ignite:MenuElement({id = "enemyRange", name = "Enemy range", value = 600, min = 400, max = 800, step = 50})
menu.summonersActivator.ignite:MenuElement({id = "enemyHpPct", name = "If enemy HP% lower than", value = 25, min = 5, max = 50, step = 5})
menu.summonersActivator.ignite:MenuElement({id = "killable", name = "Only if killable with ignite", value = true})

-- Tabla de items con sus IDs y configuración de slots
local itemList = {
    -- Support Items
    {key = "redencion", id = 3107, keyCode = 0x31, category = "support"},
    {key = "locket", id = 3190, keyCode = 0x53, category = "support"},
    {key = "mikaels", id = 3222, keyCode = 0x54, category = "support"},
    {key = "promesa", id = 3109, keyCode = 0x36, category = "support"},
    {key = "shurelya", id = 2065, keyCode = 0x35, category = "support"},
    
    -- Fighter Items
    {key = "tiamat", id = 3077, keyCode = 0x32, category = "fighter"},
    {key = "profanehydra", id = 6698, keyCode = 0x52, category = "fighter"},
    {key = "ravenoushydra", id = 3074, keyCode = 0x55, category = "fighter"},
    {key = "titanichydra", id = 3748, keyCode = 0x54, category = "fighter"},
    {key = "stridebreaker", id = 6631, keyCode = 0x56, category = "fighter"},
    {key = "youmu", id = 3142, keyCode = 0x39, category = "fighter"},
    {key = "rocketbelt", id = 3152, keyCode = 0x37, category = "fighter"},
    
    -- Defensive Items
    {key = "stopwatch", id = 2420, keyCode = 0x34, category = "defensive"},
    {key = "zhonya", id = 3157, keyCode = 0x30, category = "defensive"},
    {key = "randuin", id = 3143, keyCode = 0x38, category = "defensive"},
    
    -- Cleanse Items
    {key = "fajin", id = 3140, keyCode = 0x33, category = "cleanse"},
    {key = "cimitarra", id = 3139, keyCode = 0x4E, category = "cleanse"},
    
    -- Consumable Items
    {key = "healthpot", id = 2003, keyCode = 0x51, category = "consumable"},
    {key = "refillpot", id = 2031, keyCode = 0x52, category = "consumable"}
}

-- Tabla de summoners con sus IDs (sin slot fijo - se detecta dinámicamente)
local summonerList = {
    {key = "heal", id = 7}, -- Heal
    {key = "barrier", id = 21}, -- Barrier  
    {key = "cleanse", id = 1}, -- Cleanse
    {key = "ghost", id = 6}, -- Ghost
    {key = "exhaust", id = 3}, -- Exhaust
    {key = "ignite", id = 14} -- Ignite
}

-- Tabla para prevenir spam de summoners
local summonerLastUsed = {
    [7] = 0,   -- Heal
    [21] = 0,  -- Barrier
    [1] = 0,   -- Cleanse
    [6] = 0,   -- Ghost
    [3] = 0,   -- Exhaust
    [14] = 0   -- Ignite
}

-- Tabla para prevenir spam de items (cooldown tracking)
local itemLastUsed = {
    [3107] = 0, -- Redención
    [3077] = 0, -- Tiamat
    [3140] = 0, -- Fajín
    [2420] = 0, -- Stopwatch
    [2065] = 0, -- Shurelya
    [3109] = 0, -- Promesa
    [3152] = 0, -- Rocketbelt
    [3143] = 0, -- Randuin
    [3142] = 0, -- Youmu
    [3157] = 0, -- Zhonya
    [3139] = 0, -- Cimitarra
    [2003] = 0, -- Health Potion
    [2031] = 0, -- Refillable Potion
    [6698] = 0, -- Profane Hydra
    [3190] = 0, -- Locket
    [3222] = 0, -- Mikaels
    [3074] = 0, -- Ravenous Hydra
    [3748] = 0, -- Titanic Hydra
    [6631] = 0  -- Stridebreaker
}

-- Variable global para prevenir uso múltiple de CC cleanse
local lastCCCleanseUsed = 0

-- Función Ready como SimbleActivator
local function Ready(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0
end

-- Función para verificar si el héroe está recalleando
local function IsRecallingOrInFountain()
    -- Verificar si está recalleando (channeling recall)
    if myHero.isChanneling then
        local activeSpell = myHero.activeSpell
        if activeSpell and activeSpell.name then
            -- Recall spell names variants
            if activeSpell.name:find("Recall") or activeSpell.name:find("recall") or 
               activeSpell.name:find("TeleportHome") or activeSpell.name:find("Base") then
                return true
            end
        end
    end
    
    return false
end

-- Función para encontrar summoner por ID
local function FindSummonerSpell(summonerID)
    local spell1 = myHero:GetSpellData(SUMMONER_1)
    local spell2 = myHero:GetSpellData(SUMMONER_2)
    
    -- Mapeo de nombres a IDs de summoners (siguiendo el patrón de GGOrbwalker)
    local summonerNames = {
        [7] = "SummonerHeal",     -- Heal
        [21] = "SummonerBarrier", -- Barrier  
        [1] = "SummonerBoost",    -- Cleanse
        [6] = "SummonerHaste",    -- Ghost
        [3] = "SummonerExhaust",  -- Exhaust
        [14] = "SummonerDot"      -- Ignite
    }
    
    -- Verificar slot 1
    if spell1.name and spell1.name == summonerNames[summonerID] then
        return SUMMONER_1
    end
    
    -- Verificar slot 2
    if spell2.name and spell2.name == summonerNames[summonerID] then
        return SUMMONER_2
    end
    
    return nil
end

-- Función para usar summoner spell
local function UseSummonerSpell(summonerID, target)
    -- Verificar si el héroe está muerto
    if myHero.dead then return false end
    
    local slot = FindSummonerSpell(summonerID)
    if not slot then return false end
    
    -- Verificar disponibilidad del spell usando Ready (como SimbleActivator)
    if not Ready(slot) then
        return false
    end
    
    -- Prevenir spam - solo usar si han pasado al menos 2 segundos desde el último uso
    local currentTime = Game.Timer()
    if currentTime - summonerLastUsed[summonerID] >= 2.0 then
        -- Usar las constantes correctas HK_SUMMONER_1 y HK_SUMMONER_2
        local hotkey = (slot == SUMMONER_1) and HK_SUMMONER_1 or HK_SUMMONER_2
        
        -- Cleanse (1) se usa en nosotros mismos, siempre con myHero como target
        if summonerID == 1 then
            Control.CastSpell(hotkey, myHero)
        -- Summoners con target (Exhaust, Ignite)
        elseif target and (summonerID == 3 or summonerID == 14) then
            Control.CastSpell(hotkey, target.pos)
        -- Summoners sin target (Heal, Barrier, Ghost)
        else
            Control.CastSpell(hotkey)
        end
        
        summonerLastUsed[summonerID] = currentTime
        
        return true
    else
        return false
    end
    return false
end

-- Función para obtener el enemigo con mayor daño
local function GetHighestDamageEnemy(range)
    local highestDamageEnemy = nil
    local highestDamage = 0
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid and not hero.dead and not hero.isAlly and hero.visible then
            if myHero.pos:DistanceTo(hero.pos) <= range then
                local damage = hero.totalDamage -- Approximate damage metric
                if damage > highestDamage then
                    highestDamage = damage
                    highestDamageEnemy = hero
                end
            end
        end
    end
    
    return highestDamageEnemy
end

-- Función para calcular daño de ignite
local function GetIgniteDamage()
    local level = myHero.levelData.lvl
    return 70 + (5 * level) -- Base ignite damage formula
end

-- Mapeo de slots a ITEM_X según especificaciones
local slotToItem = {
    [6] = ITEM_1,   -- Slot 6 → ITEM_1 (tecla 1)
    [7] = ITEM_2,   -- Slot 7 → ITEM_2 (tecla 2)
    [8] = ITEM_3,   -- Slot 8 → ITEM_3 (tecla 3)
    [9] = ITEM_4,   -- Slot 9 → ITEM_4 (tecla 4)
    [10] = ITEM_5,  -- Slot 10 → ITEM_5 (tecla 5)
    [11] = ITEM_6,  -- Slot 11 → ITEM_6 (tecla 6)
    [12] = ITEM_7   -- Slot 12 → ITEM_7 (tecla 7) - TRINKET
}

-- ItemHotKey mapping similar to dnsActivator
local ItemHotKey = {
    [ITEM_1] = HK_ITEM_1,
    [ITEM_2] = HK_ITEM_2,
    [ITEM_3] = HK_ITEM_3,
    [ITEM_4] = HK_ITEM_4,
    [ITEM_5] = HK_ITEM_5,
    [ITEM_6] = HK_ITEM_6,
    [ITEM_7] = HK_ITEM_7
}

-- Función para encontrar item por ID (como 2aCtrlCActivator)
local function GetItemSlot(unit, itemID)
    for i = ITEM_1, ITEM_7 do
        if unit:GetItemData(i).itemID == itemID then
            return i
        end
    end
    return 0
end

-- Función para encontrar item por ID en slots específicos
local function FindItemInSlots(itemID)
    for slot = 6, 12 do
        local item = myHero:GetItemData(slot)
        if item and item.itemID == itemID and item.stacks > 0 then
            return slot, slotToItem[slot]
        end
    end
    return nil, nil
end

-- Función para obtener enemigo más cercano
local function GetClosestEnemy()
    local closestEnemy = nil
    local closestDistance = math.huge
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid and not hero.dead and not hero.isAlly and hero.visible then
            local distance = myHero.pos:DistanceTo(hero.pos)
            if distance < closestDistance then
                closestDistance = distance
                closestEnemy = hero
            end
        end
    end
    
    return closestEnemy, closestDistance
end

-- Función para usar item por slot específico
-- Función para usar item por slot específico (como 2aCtrlCActivator)
local function UseItemBySlot(slot, itemID)
    -- Verificar si el héroe está muerto
    if myHero.dead then return false end
    
    -- Usar método de 2aCtrlCActivator
    local itemSlot = GetItemSlot(myHero, itemID)
    if itemSlot > 0 and myHero:GetSpellData(itemSlot).currentCd == 0 then
        -- Verificar cooldown de uso anterior para prevenir spam
        local currentTime = Game.Timer()
        if itemID and itemLastUsed[itemID] and currentTime - itemLastUsed[itemID] < 1.0 then
            return false -- Evitar spam de 1 segundo
        end
        
        -- Para Hydras y la mayoría de ítems activables, usar sin posición
        local hydraItems = {3077, 6698, 3074, 3748} -- Tiamat, Profane, Ravenous, Titanic
        local isHydraItem = false
        for _, hydraID in ipairs(hydraItems) do
            if itemID == hydraID then
                isHydraItem = true
                break
            end
        end
        
        if isHydraItem then
            -- Titanic Hydra (3748) necesita un target
            if itemID == 3748 then
                local closestEnemy, closestDistance = GetClosestEnemy()
                if closestEnemy and closestDistance and closestDistance <= 400 then
                    if ItemHotKey[itemSlot] then
                        Control.CastSpell(ItemHotKey[itemSlot], closestEnemy.pos)
                    end
                else
                    -- Fallback: usar hacia la posición del mouse
                    if ItemHotKey[itemSlot] then
                        Control.CastSpell(ItemHotKey[itemSlot], Game.mousePos())
                    end
                end
            else
                -- Otras hydras se usan sin posición (como 2aCtrlCActivator)
                if ItemHotKey[itemSlot] then
                    Control.CastSpell(ItemHotKey[itemSlot])
                end
            end
        else
            -- Otros ítems (como 2aCtrlCActivator)
            if ItemHotKey[itemSlot] then
                Control.CastSpell(ItemHotKey[itemSlot])
            end
        end
        
        -- Actualizar el último uso del item
        if itemID then
            itemLastUsed[itemID] = currentTime
            -- Si es un item de CC cleanse, actualizar el cooldown global
            if itemID == 3140 or itemID == 3139 then -- Quicksilver o Mercurial Scimitar
                lastCCCleanseUsed = currentTime
            end
        end
        
        return true
    end
    return false
end

-- Función para usar item por slot específico con posición (para Redención, usando método 2aCtrlCActivator)
local function UseItemBySlotAtPosition(slot, itemID, position)
    -- Para Redención (3107), se puede usar incluso si estás muerto
    if itemID ~= 3107 and myHero.dead then return false end
    
    -- Usar método de 2aCtrlCActivator
    local itemSlot = GetItemSlot(myHero, itemID)
    if itemSlot > 0 and myHero:GetSpellData(itemSlot).currentCd == 0 then
        -- Verificar cooldown de uso anterior para prevenir spam
        local currentTime = Game.Timer()
        if itemID and itemLastUsed[itemID] and currentTime - itemLastUsed[itemID] < 1.0 then
            return false -- Evitar spam de 1 segundo
        end
        
        -- Usar posición específica si se proporciona, sino usar posición propia
        local targetPos = position or myHero.pos
        
        -- Para casting global con Redención (como SimbleActivator)
        if itemID == 3107 and menu.autoActivator.supportItems.redencion and menu.autoActivator.supportItems.redencion.globalCast:Value() then
            local distance = GetDistance(myHero.pos, targetPos)
            -- Usar casting directo si está dentro del rango normal de casting (5500 = rango máximo de Redención)
            if distance <= 5500 then
                -- Verificar si está en pantalla para decidir método de casting
                local screenPos = targetPos:To2D()
                if screenPos.onScreen and distance <= 1200 then
                    -- Casting directo para objetivos en pantalla y cercanos
                    if ItemHotKey[itemSlot] then
                        Control.CastSpell(ItemHotKey[itemSlot], targetPos)
                    end
                else
                    -- Casting global usando minimapa para objetivos lejanos o fuera de pantalla
                    if ItemHotKey[itemSlot] then
                        CastSpellMM(ItemHotKey[itemSlot], targetPos, 5500)
                    end
                end
            else
                -- Si está fuera del rango máximo, intentar casting global de todas formas
                if ItemHotKey[itemSlot] then
                    CastSpellMM(ItemHotKey[itemSlot], targetPos, 5500)
                end
            end
        else
            -- Casting normal directo para otros items o si global cast está deshabilitado
            if ItemHotKey[itemSlot] then
                Control.CastSpell(ItemHotKey[itemSlot], targetPos)
            end
        end
        
        -- Actualizar el último uso del item
        if itemID then
            itemLastUsed[itemID] = currentTime
        end
        
        return true
    end
    return false
end

-- Función para contar enemigos cercanos
local function GetEnemyCount(range)
    local count = 0
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid and not hero.dead and not hero.isAlly and hero.visible then
            if myHero.pos:DistanceTo(hero.pos) <= range then
                count = count + 1
            end
        end
    end
    return count
end

-- Función para contar aliados cercanos
local function GetAllyCount(range)
    local count = 0
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid and not hero.dead and hero.visible and hero.isAlly and hero.networkID ~= myHero.networkID then
            local distance = myHero.pos:DistanceTo(hero.pos)
            if distance <= range then
                count = count + 1
            end
        end
    end
    return count
end

-- Función para obtener aliados cercanos
local function GetNearbyAllies(range)
    local allies = {}
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid and not hero.dead and hero.visible and hero.isAlly and hero.networkID ~= myHero.networkID then
            local distance = myHero.pos:DistanceTo(hero.pos)
            if distance <= range then
                table.insert(allies, {hero = hero, distance = distance})
            end
        end
    end
    return allies, #allies
end

-- Función para obtener aliado con menor HP en rango
local function GetLowestHpAlly(range)
    local lowestHpAlly = nil
    local lowestHpPct = 100
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid and not hero.dead and hero.visible and hero.isAlly then
            local distance = myHero.pos:DistanceTo(hero.pos)
            if distance <= range then
                local hpPct = (hero.health / hero.maxHealth) * 100
                if hpPct < lowestHpPct then
                    lowestHpPct = hpPct
                    lowestHpAlly = hero
                end
            end
        end
    end
    
    return lowestHpAlly, lowestHpPct
end

-- Función para obtener aliado con menor HP (solo aliados visibles)
local function GetLowestHpAllyVisible(range)
    local lowestHpAlly = nil
    local lowestHpPct = 100
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid and not hero.dead and hero.isAlly and hero.visible then
            local distance = myHero.pos:DistanceTo(hero.pos)
            if distance <= range then
                local hpPct = (hero.health / hero.maxHealth) * 100
                if hpPct < lowestHpPct then
                    lowestHpPct = hpPct
                    lowestHpAlly = hero
                end
            end
        end
    end
    
    return lowestHpAlly, lowestHpPct
end

-- Función para obtener aliado con menor HP (incluye aliados no visibles - global)
local function GetLowestHpAllyGlobal(range)
    local lowestHpAlly = nil
    local lowestHpPct = 100
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.valid and not hero.dead and hero.isAlly then
            local distance = myHero.pos:DistanceTo(hero.pos)
            if distance <= range then
                -- Para modo global, usar tanto aliados visibles como no visibles, incluyendo a uno mismo, pero NO aliados muertos
                local hpPct = (hero.health / hero.maxHealth) * 100
                if hpPct < lowestHpPct then
                    lowestHpPct = hpPct
                    lowestHpAlly = hero
                end
            end
        end
    end
    
    return lowestHpAlly, lowestHpPct
end

-- Función para verificar si un item está disponible para usar
local function IsItemAvailable(itemID, slot, itemSlot)
    -- Verificar si el héroe está muerto
    if myHero.dead then return false end
    
    -- Verificar si el item existe en el slot
    local itemData = myHero:GetItemData(slot)
    if not itemData or itemData.itemID ~= itemID then
        return false
    end
    
    -- Para la mayoría de items, verificar que tenga al menos 1 stack
    -- Para items como pociones que pueden tener múltiples stacks, verificar > 0
    if itemData.stacks < 1 then
        return false
    end
    
    -- Verificar si el item está en cooldown del juego
    if myHero:GetSpellData(itemSlot).currentCd > 0 then
        return false
    end
    
    -- Verificar cooldown personalizado para evitar spam
    local currentTime = Game.Timer()
    if itemLastUsed[itemID] and currentTime - itemLastUsed[itemID] < 1.0 then
        return false
    end
    
    return true
end

-- Función para verificar si tenemos Redención disponible
local function HasRedemptionAvailable()
    local slot, itemSlot = FindItemInSlots(3107)
    if slot and itemSlot then
        return IsItemAvailable(3107, slot, itemSlot), slot
    end
    return false, nil
end

-- Función para dibujar el rango de Redención
local function DrawRedemptionRange()
    if not menu.autoActivator.supportItems.redencion or not menu.autoActivator.supportItems.redencion.drawRange:Value() then return end
    
    local hasRedemption, slot = HasRedemptionAvailable()
    if hasRedemption then
        local redemptionRange = menu.autoActivator.supportItems.redencion.maxRange:Value()
        Draw.CircleMinimap(myHero.pos, redemptionRange, 2, Draw.Color(100, 0, 255, 0)) -- Verde semitransparente en el minimapa
    end
end



-- Función para procesar los ítems Hydra pendientes
local function IsUnderCC(settings)
    settings = settings or {}
    
    -- Mapeo de tipos de buff usando números (como SimbleActivator)
    local CleanBuffs = {
        [5]  = settings.ccStun and settings.ccStun:Value(),         -- Stun
        [7]  = settings.ccSilence and settings.ccSilence:Value(),   -- Silence
        [8]  = settings.ccTaunt and settings.ccTaunt:Value(),       -- Taunt
        [9]  = settings.ccSuppression and settings.ccSuppression:Value(), -- Polymorph
        [10] = settings.ccSlow and settings.ccSlow:Value(),         -- Slow
        [11] = settings.ccSnare and settings.ccSnare:Value(),       -- Snare/Root
        [21] = settings.ccFear and settings.ccFear:Value(),         -- Fear
        [22] = settings.ccCharm and settings.ccCharm:Value(),       -- Charm
        [24] = settings.ccSuppression and settings.ccSuppression:Value(), -- Suppression
        [31] = settings.ccKnockdown and settings.ccKnockdown:Value() -- Disarm/Knockdown
    }
    
    -- Verificar si el héroe tiene buffs de CC
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.count > 0 then
            local buffType = buff.type
            
            -- Verificar si es un tipo de CC que queremos limpiar
            if CleanBuffs[buffType] then
                return true
            end
        end
    end
    
    return false
end

-- Función para detectar crowd control en un aliado específico
local function IsAllyUnderCC(ally, settings)
    settings = settings or {}
    if not ally then return false end
    
    -- Mapeo de tipos de buff usando números (como SimbleActivator)
    local CleanBuffs = {
        [5]  = settings.ccStun and settings.ccStun:Value(),         -- Stun
        [7]  = settings.ccSilence and settings.ccSilence:Value(),   -- Silence
        [8]  = settings.ccTaunt and settings.ccTaunt:Value(),       -- Taunt
        [9]  = settings.ccSuppression and settings.ccSuppression:Value(), -- Polymorph
        [10] = settings.ccSlow and settings.ccSlow:Value(),         -- Slow
        [11] = settings.ccSnare and settings.ccSnare:Value(),       -- Snare/Root
        [21] = settings.ccFear and settings.ccFear:Value(),         -- Fear
        [22] = settings.ccCharm and settings.ccCharm:Value(),       -- Charm
        [24] = settings.ccSuppression and settings.ccSuppression:Value(), -- Suppression
        [31] = settings.ccKnockdown and settings.ccKnockdown:Value() -- Disarm/Knockdown
    }
    
    -- Verificar si el aliado tiene buffs de CC
    for i = 0, ally.buffCount do
        local buff = ally:GetBuff(i)
        if buff and buff.count > 0 then
            local buffType = buff.type
            -- Verificar si es un tipo de CC que queremos limpiar
            if CleanBuffs[buffType] then
                return true, ally
            end
        end
    end
    
    return false
end

-- Función para verificar si un summoner está disponible
local function IsSummonerAvailable(summonerID)
    -- Verificar si el héroe está muerto
    if myHero.dead then return false end
    
    local slot = FindSummonerSpell(summonerID)
    if not slot then return false end
    
    -- Verificar si está listo usando la función Ready
    if not Ready(slot) then
        return false
    end
    
    -- Verificar cooldown personalizado para evitar spam
    local currentTime = Game.Timer()
    if summonerLastUsed[summonerID] and currentTime - summonerLastUsed[summonerID] < 2.0 then
        return false
    end
    
    return true
end

-- Función para verificar si algún CC cleanse fue usado recientemente
local function IsCCCleanseAvailable()
    local currentTime = Game.Timer()
    -- Verificar si algún CC cleanse fue usado en los últimos 0.5 segundos
    return currentTime - lastCCCleanseUsed >= 0.1
end

-- Función para detectar situaciones peligrosas
local function IsInDanger()
    local enemyCount = GetEnemyCount(800)
    local closestEnemy, closestDistance = GetClosestEnemy()
    local myHpPct = (myHero.health / myHero.maxHealth) * 100
    
    -- Peligro por HP bajo
    if myHpPct <= 20 and enemyCount >= 1 then
        return true, "low_hp"
    end
    
    -- Peligro por muchos enemigos cerca
    if enemyCount >= 3 then
        return true, "surrounded"
    end
    
    -- Peligro por enemigo muy cerca persiguiendo
    if closestEnemy and closestDistance and closestDistance <= 400 then
        -- Verificar si el enemigo se está moviendo hacia nosotros
        if closestEnemy.pathing and closestEnemy.pathing.hasMovePath then
            local enemyTarget = closestEnemy.pathing.endPos
            if GetDistance(enemyTarget, myHero.pos) < GetDistance(closestEnemy.pos, myHero.pos) then
                return true, "being_chased"
            end
        end
    end
    
    -- Peligro por proyectiles dirigidos hacia nosotros
    local dangerousProjectiles = 0
    for i = 1, Game.MissileCount() do
        local missile = Game.Missile(i)
        if missile and missile.valid and not missile.isAlly then
            local missileEndPos = missile.endPos
            if GetDistance(missileEndPos, myHero.pos) <= 200 then
                dangerousProjectiles = dangerousProjectiles + 1
            end
        end
    end
    
    if dangerousProjectiles >= 2 then
        return true, "incoming_damage"
    end
    
    return false, "safe"
end

-- Función para verificar disponibilidad de CC cleanse con prioridad
local function GetAvailableCCCleanse()
    -- Prioridad: 1. Quicksilver (3140), 2. Mercurial Scimitar (3139), 3. Cleanse (1)
    
    -- Verificar Quicksilver Sash (3140) primero
    local qssSlot, qssItemSlot = FindItemInSlots(3140)
    if qssSlot and qssItemSlot and menu.autoActivator.cleanseItems.fajin and menu.autoActivator.cleanseItems.fajin.enabled:Value() then
        if IsItemAvailable(3140, qssSlot, qssItemSlot) then
            return "quicksilver", qssSlot, 3140
        end
    end
    
    -- Verificar Mercurial Scimitar (3139) segundo
    local scimitarSlot, scimitarItemSlot = FindItemInSlots(3139)
    if scimitarSlot and scimitarItemSlot and menu.autoActivator.cleanseItems.cimitarra and menu.autoActivator.cleanseItems.cimitarra.enabled:Value() then
        if IsItemAvailable(3139, scimitarSlot, scimitarItemSlot) then
            return "scimitar", scimitarSlot, 3139
        end
    end
    
    -- Verificar Cleanse (1) último
    if menu.summonersActivator.cleanse.enabled:Value() and IsSummonerAvailable(1) then
        return "cleanse", nil, 1
    end
    
    return nil, nil, nil
end

-- Función principal del Summoners Activator
local function SummonersActivator()
    if not menu.summonersActivator.enabled:Value() then return end
    
    -- Verificar si estamos recalleando o en la fuente
    if IsRecallingOrInFountain() then
        return
    end
    
    -- Verificar si el héroe está muerto
    if myHero.dead then return end
    
    local myHpPct = (myHero.health / myHero.maxHealth) * 100
    local closestEnemy, closestEnemyDistance = GetClosestEnemy()
    
    -- Heal (7)
    if menu.summonersActivator.heal.enabled:Value() and IsSummonerAvailable(7) then
        local settings = menu.summonersActivator.heal
        local shouldUse = false
        
        -- Check my HP
        if myHpPct <= settings.myHpPct:Value() then
            shouldUse = true
        else
            -- Check ally HP
            local ally, allyHpPct = GetLowestHpAlly(settings.allyRange:Value())
            if ally and allyHpPct <= settings.allyHpPct:Value() then
                shouldUse = true
            end
        end
        
        if shouldUse then
            UseSummonerSpell(7)
        end
    end
    
    -- Barrier (21)
    if menu.summonersActivator.barrier.enabled:Value() and IsSummonerAvailable(21) then
        local settings = menu.summonersActivator.barrier
        local enemyCount = GetEnemyCount(600)
        
        if myHpPct <= settings.myHpPct:Value() and enemyCount >= settings.enemyCount:Value() then
            UseSummonerSpell(21)
        end
    end
    
    -- Cleanse (1) - Usar solo si no hay items CC cleanse disponibles (prioridad baja)
    if menu.summonersActivator.cleanse.enabled:Value() and IsSummonerAvailable(1) then
        local settings = menu.summonersActivator.cleanse
        
        -- Debug: Verificar si está bajo CC
        local isUnderCC = IsUnderCC(settings)
        local removeCCEnabled = settings.removeCCTypes:Value()
        local ccCleanseAvailable = IsCCCleanseAvailable()
        
        if isUnderCC and removeCCEnabled and ccCleanseAvailable then
            -- Verificar si hay items CC cleanse disponibles primero
            local cleanseType, cleanseSlot, cleanseItemID = GetAvailableCCCleanse()
            -- Solo usar cleanse si no hay items disponibles
            if cleanseType == "cleanse" then
                -- Cleanse se usa sin target
                if UseSummonerSpell(1) then
                    lastCCCleanseUsed = Game.Timer()
                end
            end
        end
    end
    
    -- Ghost (6)
    if menu.summonersActivator.ghost.enabled:Value() and IsSummonerAvailable(6) then
        local settings = menu.summonersActivator.ghost
        
        if closestEnemyDistance and closestEnemyDistance <= settings.enemyRange:Value() then
            if not settings.useInCombo:Value() or (settings.useInCombo:Value() and _G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]) then
                UseSummonerSpell(6)
            end
        end
    end
    
    -- Exhaust (3)
    if menu.summonersActivator.exhaust.enabled:Value() and IsSummonerAvailable(3) then
        local settings = menu.summonersActivator.exhaust
        
        if myHpPct <= settings.myHpPct:Value() then
            local target = nil
            if settings.targetHighestDamage:Value() then
                target = GetHighestDamageEnemy(settings.enemyRange:Value())
            else
                target = closestEnemy
                if target and myHero.pos:DistanceTo(target.pos) > settings.enemyRange:Value() then
                    target = nil
                end
            end
            
            if target then
                UseSummonerSpell(3, target)
            end
        end
    end
    
    -- Ignite (14)
    if menu.summonersActivator.ignite.enabled:Value() and IsSummonerAvailable(14) then
        local settings = menu.summonersActivator.ignite
        
        for i = 1, Game.HeroCount() do
            local enemy = Game.Hero(i)
            if enemy and enemy.valid and not enemy.dead and not enemy.isAlly and enemy.visible then
                local distance = myHero.pos:DistanceTo(enemy.pos)
                if distance <= settings.enemyRange:Value() then
                    local enemyHpPct = (enemy.health / enemy.maxHealth) * 100
                    if enemyHpPct <= settings.enemyHpPct:Value() then
                        if not settings.killable:Value() or (settings.killable:Value() and enemy.health <= GetIgniteDamage()) then
                            UseSummonerSpell(14, enemy)
                            break
                        end
                    end
                end
            end
        end
    end
end

-- Función para verificar condiciones de items de área
local function CheckAreaItemConditions(itemID, settings)
    local conditions = {
        allyCount = 0,
        enemyCount = 0,
        myHp = (myHero.health / myHero.maxHealth) * 100,
        closestEnemyDistance = nil,
        shouldActivate = false
    }
    
    local closestEnemy, closestEnemyDistance = GetClosestEnemy()
    conditions.closestEnemyDistance = closestEnemyDistance
    
    -- Shurelya (2065) - Verificación específica
    if itemID == 2065 then
        conditions.allyCount = GetAllyCount(800)
        conditions.shouldActivate = closestEnemyDistance and closestEnemyDistance <= settings.enemyRange:Value() and conditions.allyCount >= settings.allyCount:Value()
        
    -- Locket of Solari (3190) - Verificación específica  
    elseif itemID == 3190 then
        local ally, allyHpPct = GetLowestHpAlly(800)
        conditions.allyCount = GetAllyCount(800)
        conditions.lowestAllyHp = allyHpPct
        
        -- Verificar si hay aliado con HP bajo Y suficientes aliados cerca
        if ally and ally.valid and not ally.dead and allyHpPct <= settings.allyHpPct:Value() and conditions.allyCount >= settings.allyCount:Value() then
            conditions.shouldActivate = true
        -- O si mi HP está bajo Y hay suficientes aliados
        elseif conditions.myHp <= settings.myHpPct:Value() and conditions.allyCount >= settings.allyCount:Value() then
            conditions.shouldActivate = true
        end
        
    -- Redención (3107) - Verificación específica
    elseif itemID == 3107 then
        local ally, allyHpPct = GetLowestHpAlly(5500) -- Rango largo de Redención
        conditions.lowestAllyHp = allyHpPct
        conditions.allyCount = GetAllyCount(5500)
        
        -- Verificar si hay un aliado válido y su HP está por debajo del umbral
        if ally and ally.valid and not ally.dead and allyHpPct <= settings.allyHpPct:Value() then
            conditions.shouldActivate = true
        -- Solo usar en mí mismo si mi HP está por debajo del umbral
        elseif conditions.myHp <= settings.myHpPct:Value() then
            conditions.shouldActivate = true
        end
    end
    
    return conditions
end

-- Función principal del Auto Activador
local function AutoActivator()
    if not menu.autoActivator.enabled:Value() then return end
    
    -- Verificar si el héroe está muerto
    if myHero.dead then return end
    
    local myHpPct = (myHero.health / myHero.maxHealth) * 100
    local closestEnemy, closestEnemyDistance = GetClosestEnemy()
    
    -- Función helper para obtener configuraciones del menú según categoría
    local function getMenuSettings(item)
        if item.category == "support" then
            return menu.autoActivator.supportItems[item.key]
        elseif item.category == "fighter" then
            return menu.autoActivator.fighterItems[item.key]
        elseif item.category == "defensive" then
            return menu.autoActivator.defensiveItems[item.key]
        elseif item.category == "cleanse" then
            return menu.autoActivator.cleanseItems[item.key]
        elseif item.category == "consumable" then
            return menu.autoActivator.consumableItems[item.key]
        end
        return nil
    end
    
    -- Iterar por cada item y verificar condiciones
    for _, item in ipairs(itemList) do
        local slot, itemSlot = FindItemInSlots(item.id)
        local settings = getMenuSettings(item)
        
        if slot and itemSlot and settings and settings.enabled:Value() then
            -- Verificar disponibilidad del item antes de hacer cálculos costosos
            if not IsItemAvailable(item.id, slot, itemSlot) then
                goto continue
            end
            
            local shouldUse = false
            
            -- Redención (3107) - Lógica con casting global usando MapPosition
            if item.id == 3107 then
                local targetPosition = nil
                local ally = nil
                local allyHpPct = 100
                
                local maxRange = settings.maxRange:Value()
                local globalCastEnabled = settings.globalCast:Value()
                
                -- Buscar aliado con menor HP según configuración global
                if globalCastEnabled then
                    ally, allyHpPct = GetLowestHpAllyGlobal(maxRange)
                else
                    ally, allyHpPct = GetLowestHpAllyVisible(maxRange)
                end
                
                -- Verificar si hay un aliado válido que necesite curación (incluyendo aliados no muertos)
                if ally and ally.valid and not ally.dead and allyHpPct <= settings.allyHpPct:Value() then
                    shouldUse = true
                    targetPosition = ally.pos
                -- Solo usar en mí mismo si mi HP está por debajo del umbral Y no estoy muerto
                elseif not myHero.dead and myHpPct <= settings.myHpPct:Value() then
                    shouldUse = true
                    targetPosition = myHero.pos
                end
                
                -- Usar Redención si se cumplen las condiciones usando la función especial
                if shouldUse and targetPosition then
                    local success = UseItemBySlotAtPosition(slot, item.id, targetPosition)
                    if success then
                        goto continue -- Salir después de usar exitosamente
                    end
                end
            
            -- Hydras (3077, 6698, 3074, 3748) - Tiamat, Profane Hydra, Ravenous Hydra, Titanic Hydra
            elseif item.id == 3077 or item.id == 6698 or item.id == 3074 or item.id == 3748 then
                local enemyCount = GetEnemyCount(settings.range:Value())
                -- Solo usar si hay suficientes enemigos cercanos
                if enemyCount >= settings.enemyCount:Value() and enemyCount > 0 then
                    shouldUse = true
                end
            
            -- Stridebreaker (6631)
            elseif item.id == 6631 then
                local enemyCount = GetEnemyCount(settings.range:Value())
                if enemyCount >= settings.enemyCount:Value() and enemyCount > 0 then
                    if not settings.useInCombo:Value() or (settings.useInCombo:Value() and _G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]) then
                        shouldUse = true
                    end
                end
            
            -- Fajín (3140) - Quicksilver Sash con prioridad CC cleanse
            elseif item.id == 3140 then
                -- Solo usar si estoy bajo CC y las configuraciones lo permiten
                if IsUnderCC(settings) and settings.removeCCTypes:Value() and IsCCCleanseAvailable() then
                    local cleanseType, cleanseSlot, cleanseItemID = GetAvailableCCCleanse()
                    if cleanseType == "quicksilver" then
                        shouldUse = true
                    end
                end
            
            -- Stopwatch (2420) - Usar solo basado en HP y enemigos cercanos
            elseif item.id == 2420 then
                local enemyCount = GetEnemyCount(600)
                -- Solo usar si cumple las condiciones básicas del menú
                if myHpPct <= settings.myHpPct:Value() and enemyCount >= settings.enemyCount:Value() then
                    shouldUse = true
                end
            
            -- Shurelya (2065)
            elseif item.id == 2065 then
                local conditions = CheckAreaItemConditions(item.id, settings)
                shouldUse = conditions.shouldActivate
            
            -- Promesa del caballero (3109) - Knight's Vow - Usar en aliado con HP bajo
            elseif item.id == 3109 then
                local ally, allyHpPct = GetLowestHpAlly(settings.range:Value())
                -- Solo usar si hay un aliado válido con HP bajo
                if ally and ally.valid and not ally.dead and allyHpPct <= settings.allyHpPct:Value() then
                    -- Usar Knight's Vow en el aliado específico
                    local itemSlot = slotToItem[slot]
                    if itemSlot then
                        Control.CastSpell(ItemHotKey[itemSlot], ally.pos)
                        itemLastUsed[item.id] = Game.Timer()
                        shouldUse = false -- Ya se usó directamente
                    end
                end
            
            -- Hextech Rocketbelt (3152) - Usar cuando hay enemigo visible
            elseif item.id == 3152 then
                if closestEnemy then
                    local inCombo = _G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
                    
                    -- Debug: Descomentar para diagnóstico
                    -- print("Rocketbelt Debug - Enemy found:", closestEnemy.charName, "InCombo:", inCombo, "UseInCombo:", settings.useInCombo:Value())
                    
                    -- Usar si no requiere combo O si está en combo
                    if not settings.useInCombo:Value() or inCombo then
                        -- Usar Rocketbelt hacia la posición del enemigo o hacia donde apunta el mouse como respaldo
                        local itemSlot = slotToItem[slot]
                        if itemSlot then
                            local targetPos = closestEnemy.pos or Game.mousePos()
                            Control.CastSpell(ItemHotKey[itemSlot], targetPos)
                            itemLastUsed[item.id] = Game.Timer()
                            shouldUse = false -- Ya se usó directamente
                        end
                    end
                end
            
            -- Randuin (3143)
            elseif item.id == 3143 then
                local enemyCount = GetEnemyCount(settings.range:Value())
                if enemyCount >= settings.enemyCount:Value() then
                    shouldUse = true
                end
            
            -- Youmu (3142) - Usar para engage, chase o escape
            elseif item.id == 3142 then
                local inDanger, dangerType = IsInDanger()
                local inCombo = _G.SDK and _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO]
                
                -- Usar para engage/combo
                local shouldUseForEngage = closestEnemyDistance and closestEnemyDistance <= settings.enemyRange:Value() and 
                                         (not settings.useInCombo:Value() or inCombo)
                
                -- Usar para escape cuando estamos en peligro
                local shouldUseForEscape = inDanger and (dangerType == "being_chased" or dangerType == "surrounded")
                
                if shouldUseForEngage or shouldUseForEscape then
                    shouldUse = true
                end
            
            -- Zhonya (3157) - Usar solo basado en HP y enemigos cercanos
            elseif item.id == 3157 then
                local enemyCount = GetEnemyCount(600)
                -- Debug: Imprimir valores para diagnóstico
                -- print("Zhonya Debug - HP:", myHpPct, "Required:", settings.myHpPct:Value(), "EnemyCount:", enemyCount, "Required:", settings.enemyCount:Value())
                -- Solo usar si cumple las condiciones básicas del menú
                if myHpPct <= settings.myHpPct:Value() and enemyCount >= settings.enemyCount:Value() then
                    shouldUse = true
                end
            
            -- Cimitarra (3139) - Mercurial Scimitar con prioridad CC cleanse
            elseif item.id == 3139 then
                if IsUnderCC(settings) and settings.removeCCTypes:Value() and IsCCCleanseAvailable() then
                    local cleanseType, cleanseSlot, cleanseItemID = GetAvailableCCCleanse()
                    if cleanseType == "scimitar" then
                        shouldUse = true
                    end
                end
            
            -- Health Potion (2003) - No usar si ya hay buff de poción
            elseif item.id == 2003 then
                -- Verificar si ya tiene buff de poción activa
                local hasHealthPotionBuff = false
                for i = 0, myHero.buffCount do
                    local buff = myHero:GetBuff(i)
                    if buff and buff.count > 0 then
                        local buffName = buff.name:lower()
                        if buffName:find("itemhealthpotion") or buffName:find("regenpot") or buffName:find("healthpot") then
                            hasHealthPotionBuff = true
                            break
                        end
                    end
                end
                
                -- Solo usar si mi HP está bajo y no hay buff de poción
                if not hasHealthPotionBuff and myHpPct <= settings.myHpPct:Value() then
                    shouldUse = true
                end
            
            -- Refillable Potion (2031) - No usar si ya hay buff de poción
            elseif item.id == 2031 then
                -- Verificar si ya tiene buff de poción activa
                local hasRefillPotionBuff = false
                for i = 0, myHero.buffCount do
                    local buff = myHero:GetBuff(i)
                    if buff and buff.count > 0 then
                        local buffName = buff.name:lower()
                        if buffName:find("itemhealthpotion") or buffName:find("regenpot") or buffName:find("healthpot") or 
                           buffName:find("itemcrystalflask") or buffName:find("refillpot") then
                            hasRefillPotionBuff = true
                            break
                        end
                    end
                end
                
                -- Solo usar si mi HP está bajo y no hay buff de poción y tiene al menos 1 stack
                local itemData = myHero:GetItemData(slot)
                if not hasRefillPotionBuff and myHpPct <= settings.myHpPct:Value() and itemData and itemData.stacks > 0 then
                    shouldUse = true
                end
            
            -- Locket of Solari (3190)
            elseif item.id == 3190 then
                local conditions = CheckAreaItemConditions(item.id, settings)
                shouldUse = conditions.shouldActivate
            
            -- Mikael's Blessing (3222) - Usar en aliado con CC y HP bajo (incluido yo mismo)
            elseif item.id == 3222 then
                if settings.removeCCTypes:Value() then
                    -- Buscar aliado bajo CC en rango con HP bajo (incluido yo mismo)
                    local bestTarget = nil
                    local lowestHpPct = 100
                    
                    -- Verificar primero a mí mismo
                    if IsUnderCC(settings) then
                        local myHpPct = (myHero.health / myHero.maxHealth) * 100
                        if myHpPct <= settings.allyHpPct:Value() then
                            bestTarget = myHero
                            lowestHpPct = myHpPct
                        end
                    end
                    
                    -- Verificar aliados (excluyendo a mí mismo para evitar duplicados)
                    for i = 1, Game.HeroCount() do
                        local ally = Game.Hero(i)
                        if ally and ally.valid and not ally.dead and ally.isAlly and ally.networkID ~= myHero.networkID then
                            if myHero.pos:DistanceTo(ally.pos) <= settings.range:Value() then
                                local allyHpPct = (ally.health / ally.maxHealth) * 100
                                -- Verificar tanto HP como CC
                                if allyHpPct <= settings.allyHpPct:Value() and IsAllyUnderCC(ally, settings) then
                                    -- Seleccionar al aliado con menor HP que esté bajo CC
                                    if allyHpPct < lowestHpPct then
                                        lowestHpPct = allyHpPct
                                        bestTarget = ally
                                    end
                                end
                            end
                        end
                    end
                    
                    if bestTarget then
                        -- Usar Mikael's en el mejor target
                        local itemSlot = slotToItem[slot]
                        if itemSlot then
                            Control.CastSpell(ItemHotKey[itemSlot], bestTarget.pos)
                            itemLastUsed[item.id] = Game.Timer()
                            shouldUse = false -- Ya se usó directamente
                        end
                    end
                end
            end
            
            -- Usar el item si se cumplen las condiciones
            if shouldUse then
                UseItemBySlot(slot, item.id)
            end
            
            ::continue:: -- Label para saltar al siguiente item
        end
    end
end

-- Función para imprimir item ID del slot 6
-- local function PrintSlot6ItemID()
--     local item = myHero:GetItemData(6)
--     if item and item.itemID and item.itemID > 0 then
--         print("Slot 6 Item ID: " .. item.itemID .. " | Stacks: " .. (item.stacks or 0))
--     else
--         print("Slot 6: Empty or no item")
--     end
-- end

-- Callback principal
Callback.Add("Tick", function()
    if not menu.enabled:Value() then return end
    
    -- Verificar si el héroe está muerto antes de cualquier activación
    if myHero.dead then return end
    
    -- Auto Activador
    AutoActivator()
    
    -- PrintSlot6ItemID()

    -- Summoners Activator
    SummonersActivator()
end)

-- Callback para dibujar
Callback.Add("Draw", function()
    if not menu.enabled:Value() then return end
    
    -- Dibujar rango de Redención
    DrawRedemptionRange()
end)

-- Callback de carga
Callback.Add("Load", function()
    -- Script cargado exitosamente
end)
