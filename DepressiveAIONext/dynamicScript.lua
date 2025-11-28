-- DepressiveAIONext Dynamic Loader
-- Minimal skeleton; expand with orbwalker integration, prediction selection, etc.

local heroesLoaded = false
local Allies, Enemies = {}, {}
-- Cachear valores de team (no cambian durante la partida)
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team

-- Cache para evitar recargar unidades innecesariamente
local lastHeroCount = 0

local function LoadUnits()
    local heroCount = Game.HeroCount()
    
    -- Solo recargar si el número de heroes cambió (optimización)
    if heroesLoaded and heroCount == lastHeroCount then
        return
    end
    
    -- Limpiar arrays antes de recargar
    for i = 1, #Allies do Allies[i] = nil end
    for i = 1, #Enemies do Enemies[i] = nil end
    
    for i = 1, heroCount do
        local hero = Game.Hero(i)
        if hero and hero.valid then
            if hero.team == TEAM_ALLY and hero ~= myHero then 
                Allies[#Allies+1] = hero
            elseif hero.team == TEAM_ENEMY then 
                Enemies[#Enemies+1] = hero 
            end
        end
    end
    
    lastHeroCount = heroCount
    heroesLoaded = true
end

local function IsValid(unit)
    return unit and unit.valid and unit.alive and unit.visible and unit.isTargetable and unit.health > 0
end

local function GetTarget(range)
    if _G.SDK and _G.SDK.TargetSelector then
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL)
    elseif _G.PremiumOrbwalker then
        return _G.PremiumOrbwalker:GetTarget(range)
    elseif _G.GOS then
        return GOS:GetTarget(range, myHero.ap > myHero.totalDamage and "AP" or "AD")
    end
end

-- Cache para el modo del orbwalker (evitar accesos repetitivos)
local cachedMode = nil
local lastModeCheck = 0
local modeCheckInterval = 0.05 -- Verificar cada 50ms

local function Mode()
    -- Throttle: cachear resultado por un breve período
    local currentTime = os.clock()
    if cachedMode and (currentTime - lastModeCheck) < modeCheckInterval then
        return cachedMode
    end
    
    lastModeCheck = currentTime
    
    if _G.SDK then
        local OW = _G.SDK.Orbwalker.Modes
        if OW[_G.SDK.ORBWALKER_MODE_COMBO] then 
            cachedMode = "Combo"
            return cachedMode
        end
        if OW[_G.SDK.ORBWALKER_MODE_HARASS] then 
            cachedMode = "Harass"
            return cachedMode
        end
        if OW[_G.SDK.ORBWALKER_MODE_LANECLEAR] or OW[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then 
            cachedMode = "Clear"
            return cachedMode
        end
        if OW[_G.SDK.ORBWALKER_MODE_LASTHIT] then 
            cachedMode = "LastHit"
            return cachedMode
        end
        if OW[_G.SDK.ORBWALKER_MODE_FLEE] then 
            cachedMode = "Flee"
            return cachedMode
        end
    end
    
    cachedMode = "None"
    return cachedMode
end

-- Throttle para evitar cargar unidades en cada tick
local lastLoadCheck = 0
local loadCheckInterval = 0.5 -- Verificar cada 500ms

Callback.Add("Tick", function()
    -- Solo verificar periódicamente si no están cargadas
    if not heroesLoaded then
        local currentTime = os.clock()
        if currentTime - lastLoadCheck >= loadCheckInterval then
            lastLoadCheck = currentTime
            LoadUnits()
        end
    end
end)

print("[DepressiveAIONext] dynamicScript loaded")
