-- DepressiveAIONext Dynamic Loader
-- Minimal skeleton; expand with orbwalker integration, prediction selection, etc.

local heroesLoaded = false
local Allies, Enemies = {}, {}
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team

local function LoadUnits()
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero.team == TEAM_ALLY and hero ~= myHero then Allies[#Allies+1] = hero
        elseif hero.team == TEAM_ENEMY then Enemies[#Enemies+1] = hero end
    end
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

local function Mode()
    if _G.SDK then
        local OW = _G.SDK.Orbwalker.Modes
        if OW[_G.SDK.ORBWALKER_MODE_COMBO] then return "Combo" end
        if OW[_G.SDK.ORBWALKER_MODE_HARASS] then return "Harass" end
        if OW[_G.SDK.ORBWALKER_MODE_LANECLEAR] or OW[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then return "Clear" end
        if OW[_G.SDK.ORBWALKER_MODE_LASTHIT] then return "LastHit" end
        if OW[_G.SDK.ORBWALKER_MODE_FLEE] then return "Flee" end
    end
    return "None"
end

Callback.Add("Tick", function()
    if not heroesLoaded then LoadUnits() end
end)

print("[DepressiveAIONext] dynamicScript loaded")
