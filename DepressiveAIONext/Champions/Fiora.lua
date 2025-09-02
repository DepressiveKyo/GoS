-- DepressiveAIONext compatibility guard
if _G.__DEPRESSIVE_NEXT_FIORA_LOADED then return end
_G.__DEPRESSIVE_NEXT_FIORA_LOADED = true

local Version = 1.0
local Name = "DepressiveFiora"

-- Hero validation
local Heroes = {"Fiora"}

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
    print("[Fiora] DepressivePrediction not found, using fallback prediction")
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

local function HasBuff(unit, buffname)
    if not unit or not unit.buffCount then return false end
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffname and buff.count > 0 then 
            return true
        end
    end
    return false
end

-- Anti-CC helper functions
local DetectedSpells = {}
local Units = {}

local function VectorPointProjectionOnLineSegment(v1, v2, v)
    -- Validate inputs
    if not v1 or not v2 or not v then
        return nil, nil, false
    end
    
    local cx, cy, ax, ay, bx, by = v.x, v.z, v1.x, v1.z, v2.x, v2.z
    
    -- Check if any coordinate is nil
    if not cx or not cy or not ax or not ay or not bx or not by then
        return nil, nil, false
    end
    
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = { x = ax + rL * (bx - ax), z = ay + rL * (by - ay) }
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or { x = ax + rS * (bx - ax), z = ay + rS * (by - ay) }
    return pointSegment, pointLine, isOnSegment
end

local function CalculateEndPos(startPos, placementPos, unitPos, range, radius, collision, type)
    local range = range or 3000
    local endPos = startPos:Extended(placementPos, range)
    if type == "circular" or type == "rectangular" then
        if range > 0 then 
            if GetDistance(unitPos, placementPos) < range then 
                endPos = placementPos 
            end
        else 
            endPos = unitPos 
        end
    elseif collision then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == myHero.team and minion.alive and GetDistance(minion.pos, startPos) < range then
                local col = VectorPointProjectionOnLineSegment(startPos, placementPos, minion.pos)
                if col and GetDistance(col, minion.pos) < (radius + minion.boundingRadius / 2) then
                    range = GetDistance(startPos, col)
                    endPos = startPos:Extended(placementPos, range)
                    break
                end
            end
        end
    end
    return endPos, range
end

local function CalculateCollisionTime(startPos, endPos, unitPos, startTime, speed, delay)
    local pos = startPos:Extended(endPos, speed * (Game.Timer() - delay - startTime))
    return GetDistance(unitPos, pos) / speed
end

local function OnProcessSpell()
    for i = 1, #Units do
        local unit = Units[i].unit
        local last = Units[i].spell
        local spell = unit.activeSpell
        if spell and last ~= (spell.name .. spell.endTime) and unit.activeSpell.isChanneling then
            Units[i].spell = spell.name .. spell.endTime
            return unit, spell
        end
    end
    return nil, nil
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
local function getdmg(spell, target, source)
    if not target or not source then return 0 end
    
    local baseDamage = 0
    local apRatio = 0
    local adRatio = 0
    
    if spell == "AA" then
        baseDamage = source.totalDamage
    elseif spell == "Q" then
        baseDamage = 65 + (source:GetSpellData(_Q).level - 1) * 20
        adRatio = 0.95
    elseif spell == "W" then
        baseDamage = 75 + (source:GetSpellData(_W).level - 1) * 25
        apRatio = 0.6
    elseif spell == "E" then
        baseDamage = 0 -- E doesn't deal damage, just resets AA
    elseif spell == "R" then
        baseDamage = 0 -- R doesn't deal damage directly
    end
    
    local totalDamage = baseDamage + (source.totalDamage * adRatio) + (source.ap * apRatio)
    
    -- Basic armor/magic resist calculation
    local finalDamage = totalDamage * (100 / (100 + target.armor))
    
    return finalDamage
end

-- CC Spells Database
local CCSpells = {
    ["AatroxW"] = {charName = "Aatrox", displayName = "Infernal Chains", slot = _W, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 80, collision = true},
    ["AhriSeduce"] = {charName = "Ahri", displayName = "Seduce", slot = _E, type = "linear", speed = 1500, range = 975, delay = 0.25, radius = 60, collision = true},
    ["AkaliR"] = {charName = "Akali", displayName = "Perfect Execution [First]", slot = _R, type = "linear", speed = 1800, range = 525, delay = 0, radius = 65, collision = false},
    ["Pulverize"] = {charName = "Alistar", displayName = "Pulverize", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 365, collision = false},
    ["BandageToss"] = {charName = "Amumu", displayName = "Bandage Toss", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.25, radius = 80, collision = true},
    ["CurseoftheSadMummy"] = {charName = "Amumu", displayName = "Curse of the Sad Mummy", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 550, collision = false},
    ["FlashFrostSpell"] = {charName = "Anivia", displayName = "Flash Frost", slot = _Q, type = "linear", speed = 850, range = 1100, delay = 0.25, radius = 110, collision = false},
    ["EnchantedCrystalArrow"] = {charName = "Ashe", displayName = "Enchanted Crystal Arrow", slot = _R, type = "linear", speed = 1600, range = 25000, delay = 0.25, radius = 130, collision = false},
    ["AurelionSolQ"] = {charName = "AurelionSol", displayName = "Starsurge", slot = _Q, type = "linear", speed = 850, range = 25000, delay = 0, radius = 110, collision = false},
    ["AzirR"] = {charName = "Azir", displayName = "Emperor's Divide", slot = _R, type = "linear", speed = 1400, range = 500, delay = 0.3, radius = 250, collision = false},
    ["BardQ"] = {charName = "Bard", displayName = "Cosmic Binding", slot = _Q, type = "linear", speed = 1500, range = 950, delay = 0.25, radius = 60, collision = true},
    ["BardR"] = {charName = "Bard", displayName = "Tempered Fate", slot = _R, type = "circular", speed = 2100, range = 3400, delay = 0.5, radius = 350, collision = false},
    ["RocketGrab"] = {charName = "Blitzcrank", displayName = "Rocket Grab", slot = _Q, type = "linear", speed = 1800, range = 1150, delay = 0.25, radius = 140, collision = true},
    ["BrandQ"] = {charName = "Brand", displayName = "Sear", slot = _Q, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 60, collision = true},
    ["BraumQ"] = {charName = "Braum", displayName = "Winter's Bite", slot = _Q, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, collision = true},
    ["BraumR"] = {charName = "Braum", displayName = "Glacial Fissure", slot = _R, type = "linear", speed = 1400, range = 1250, delay = 0.5, radius = 115, collision = false},
    ["CamilleE"] = {charName = "Camille", displayName = "Hookshot [First]", slot = _E, type = "linear", speed = 1900, range = 800, delay = 0, radius = 60, collision = false},
    ["CamilleEDash2"] = {charName = "Camille", displayName = "Hookshot [Second]", slot = _E, type = "linear", speed = 1900, range = 400, delay = 0, radius = 60, collision = false},
    ["CaitlynYordleTrap"] = {charName = "Caitlyn", displayName = "Yordle Trap", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 0.25, radius = 75, collision = false},
    ["CaitlynEntrapment"] = {charName = "Caitlyn", displayName = "Entrapment", slot = _E, type = "linear", speed = 1600, range = 750, delay = 0.15, radius = 70, collision = true},
    ["CassiopeiaW"] = {charName = "Cassiopeia", displayName = "Miasma", slot = _W, type = "circular", speed = 2500, range = 800, delay = 0.75, radius = 160, collision = false},
    ["Rupture"] = {charName = "Chogath", displayName = "Rupture", slot = _Q, type = "circular", speed = math.huge, range = 950, delay = 1.2, radius = 250, collision = false},
    ["InfectedCleaverMissile"] = {charName = "DrMundo", displayName = "Infected Cleaver", slot = _Q, type = "linear", speed = 2000, range = 975, delay = 0.25, radius = 60, collision = true},
    ["DravenDoubleShot"] = {charName = "Draven", displayName = "Double Shot", slot = _E, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 130, collision = false},
    ["DariusE"] = {charName = "Darius", displayName = "Apprehend", slot = _E, type = "linear", speed = math.huge, range = 535, delay = 0.25, radius = 140, collision = false},
    ["DariusR"] = {charName = "Darius", displayName = "Noxian Guillotine", slot = _R, type = "targeted", range = 460, cc = true},
    ["EkkoQ"] = {charName = "Ekko", displayName = "Timewinder", slot = _Q, type = "linear", speed = 1650, range = 1175, delay = 0.25, radius = 60, collision = false},
    ["EkkoW"] = {charName = "Ekko", displayName = "Parallel Convergence", slot = _W, type = "circular", speed = math.huge, range = 1600, delay = 3.35, radius = 400, collision = false},
    ["EliseHumanE"] = {charName = "Elise", displayName = "Cocoon", slot = _E, type = "linear", speed = 1600, range = 1075, delay = 0.25, radius = 55, collision = true},
    ["FizzR"] = {charName = "Fizz", displayName = "Chum the Waters", slot = _R, type = "linear", speed = 1300, range = 1300, delay = 0.25, radius = 150, collision = false},
    ["GalioE"] = {charName = "Galio", displayName = "Justice Punch", slot = _E, type = "linear", speed = 2300, range = 650, delay = 0.4, radius = 160, collision = false},
    ["GarenQ"] = {charName = "Garen", displayName = "Decisive Strike", slot = _Q, type = "targeted", range = 225},
    ["GnarQMissile"] = {charName = "Gnar", displayName = "Boomerang Throw", slot = _Q, type = "linear", speed = 2500, range = 1125, delay = 0.25, radius = 55, collision = false},
    ["GnarBigQMissile"] = {charName = "Gnar", displayName = "Boulder Toss", slot = _Q, type = "linear", speed = 2100, range = 1125, delay = 0.5, radius = 90, collision = true},
    ["GnarBigW"] = {charName = "Gnar", displayName = "Wallop", slot = _W, type = "linear", speed = math.huge, range = 575, delay = 0.6, radius = 100, collision = false},
    ["GnarR"] = {charName = "Gnar", displayName = "GNAR!", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 475, collision = false},
    ["GragasQ"] = {charName = "Gragas", displayName = "Barrel Roll", slot = _Q, type = "circular", speed = 1000, range = 850, delay = 0.25, radius = 275, collision = false},
    ["GragasR"] = {charName = "Gragas", displayName = "Explosive Cask", slot = _R, type = "circular", speed = 1800, range = 1000, delay = 0.25, radius = 400, collision = false},
    ["GravesSmokeGrenade"] = {charName = "Graves", displayName = "Smoke Grenade", slot = _W, type = "circular", speed = 1500, range = 950, delay = 0.15, radius = 250, collision = false},
    ["HeimerdingerE"] = {charName = "Heimerdinger", displayName = "CH-2 Electron Storm Grenade", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, collision = false},
    ["HeimerdingerEUlt"] = {charName = "Heimerdinger", displayName = "CH-2 Electron Storm Grenade", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, collision = false},
    ["HecarimUlt"] = {charName = "Hecarim", displayName = "Onslaught of Shadows", slot = _R, type = "linear", speed = 1100, range = 1650, delay = 0.2, radius = 280, collision = false},
    ["IllaoiE"] = {charName = "Illaoi", displayName = "Test of Spirit", slot = _E, type = "linear", speed = 1900, range = 900, delay = 0.25, radius = 50, collision = true},
    ["IreliaR"] = {charName = "Irelia", displayName = "Vanguard's Edge", slot = _R, type = "linear", speed = 2000, range = 950, delay = 0.4, radius = 160, collision = false},
    ["IvernQ"] = {charName = "Ivern", displayName = "Rootcaller", slot = _Q, type = "linear", speed = 1300, range = 1075, delay = 0.25, radius = 80, collision = true},
    ["JarvanIVDragonStrike"] = {charName = "JarvanIV", displayName = "Dragon Strike", slot = _Q, type = "linear", speed = math.huge, range = 770, delay = 0.4, radius = 70, collision = false},
    ["JhinW"] = {charName = "Jhin", displayName = "Deadly Flourish", slot = _W, type = "linear", speed = 5000, range = 2550, delay = 0.75, radius = 40, collision = false},
    ["JhinE"] = {charName = "Jhin", displayName = "Captive Audience", slot = _E, type = "circular", speed = 1600, range = 750, delay = 0.25, radius = 130, collision = false},
    ["JinxWMissile"] = {charName = "Jinx", displayName = "Zap!", slot = _W, type = "linear", speed = 3300, range = 1450, delay = 0.6, radius = 60, collision = true},
    ["KarmaQ"] = {charName = "Karma", displayName = "Inner Flame", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 60, collision = true},
    ["KarmaQMantra"] = {charName = "Karma", displayName = "Inner Flame [Mantra]", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 80, collision = true},
    ["KayleQ"] = {charName = "Kayle", displayName = "Radiant Blast", slot = _Q, type = "linear", speed = 2000, range = 850, delay = 0.5, radius = 60, collision = false},
    ["KaynW"] = {charName = "Kayn", displayName = "Blade's Reach", slot = _W, type = "linear", speed = math.huge, range = 700, delay = 0.55, radius = 90, collision = false},
    ["KhazixWLong"] = {charName = "Khazix", displayName = "Void Spike [Threeway]", slot = _W, type = "threeway", speed = 1700, range = 1000, delay = 0.25, radius = 70, angle = 23, collision = true},
    ["KledQ"] = {charName = "Kled", displayName = "Beartrap on a Rope", slot = _Q, type = "linear", speed = 1600, range = 800, delay = 0.25, radius = 45, collision = true},
    ["KogMawVoidOozeMissile"] = {charName = "KogMaw", displayName = "Void Ooze", slot = _E, type = "linear", speed = 1400, range = 1360, delay = 0.25, radius = 120, collision = false},
    ["LeblancE"] = {charName = "Leblanc", displayName = "Ethereal Chains [Standard]", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, collision = true},
    ["LeblancRE"] = {charName = "Leblanc", displayName = "Ethereal Chains [Ultimate]", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, collision = true},
    ["LeonaZenithBlade"] = {charName = "Leona", displayName = "Zenith Blade", slot = _E, type = "linear", speed = 2000, range = 875, delay = 0.25, radius = 70, collision = false},
    ["LeonaSolarFlare"] = {charName = "Leona", displayName = "Solar Flare", slot = _R, type = "circular", speed = math.huge, range = 1200, delay = 0.85, radius = 300, collision = false},
    ["LilliaE"] = {charName = "Lillia", displayName = "Lillia E", slot = _E, type = "linear", speed = 1500, range = 750, delay = 0.4, radius = 150, collision = false},
    ["LissandraQMissile"] = {charName = "Lissandra", displayName = "Ice Shard", slot = _Q, type = "linear", speed = 2200, range = 750, delay = 0.25, radius = 75, collision = false},
    ["LuluQ"] = {charName = "Lulu", displayName = "Glitterlance", slot = _Q, type = "linear", speed = 1450, range = 925, delay = 0.25, radius = 60, collision = false},
    ["LuxLightBinding"] = {charName = "Lux", displayName = "Light Binding", slot = _Q, type = "linear", speed = 1200, range = 1175, delay = 0.25, radius = 50, collision = false},
    ["LuxLightStrikeKugel"] = {charName = "Lux", displayName = "Light Strike Kugel", slot = _E, type = "circular", speed = 1200, range = 1100, delay = 0.25, radius = 300, collision = true},
    ["Landslide"] = {charName = "Malphite", displayName = "Ground Slam", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.242, radius = 400, collision = false},
    ["UFSlash"] = {charName = "Malphite", displayName = "Unstoppable Force", slot = _R, type = "circular", speed = 1835, range = 1000, delay = 0, radius = 300, collision = false},
    ["MalzaharQ"] = {charName = "Malzahar", displayName = "Call of the Void", slot = _Q, type = "rectangular", speed = 1600, range = 900, delay = 0.5, radius = 400, radius2 = 100, collision = false},
    ["MaokaiQ"] = {charName = "Maokai", displayName = "Bramble Smash", slot = _Q, type = "linear", speed = 1600, range = 600, delay = 0.375, radius = 110, collision = false},
    ["MorganaQ"] = {charName = "Morgana", displayName = "Dark Binding", slot = _Q, type = "linear", speed = 1200, range = 1250, delay = 0.25, radius = 70, collision = true},
    ["MordekaiserE"] = {charName = "Mordekaiser", displayName = "Death's Grasp", slot = _E, type = "linear", speed = math.huge, range = 900, delay = 0.9, radius = 140, collision = false},
    ["NamiQ"] = {charName = "Nami", displayName = "Aqua Prison", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 1, radius = 180, collision = false},
    ["NamiRMissile"] = {charName = "Nami", displayName = "Tidal Wave", slot = _R, type = "linear", speed = 850, range = 2750, delay = 0.5, radius = 250, collision = false},
    ["NautilusAnchorDragMissile"] = {charName = "Nautilus", displayName = "Dredge Line", slot = _Q, type = "linear", speed = 2000, range = 925, delay = 0.25, radius = 90, collision = true},
    ["NeekoQ"] = {charName = "Neeko", displayName = "Blooming Burst", slot = _Q, type = "circular", speed = 1500, range = 800, delay = 0.25, radius = 200, collision = false},
    ["NeekoE"] = {charName = "Neeko", displayName = "Tangle-Barbs", slot = _E, type = "linear", speed = 1400, range = 1000, delay = 0.25, radius = 65, collision = false},
    ["NunuR"] = {charName = "Nunu", displayName = "Absolute Zero", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 3, radius = 650, collision = false},
    ["OlafAxeThrowCast"] = {charName = "Olaf", displayName = "Undertow", slot = _Q, type = "linear", speed = 1600, range = 1000, delay = 0.25, radius = 90, collision = false},
    ["OrnnQ"] = {charName = "Ornn", displayName = "Volcanic Rupture", slot = _Q, type = "linear", speed = 1800, range = 800, delay = 0.3, radius = 65, collision = false},
    ["OrnnE"] = {charName = "Ornn", displayName = "Searing Charge", slot = _E, type = "linear", speed = 1600, range = 800, delay = 0.35, radius = 150, collision = false},
    ["OrnnRCharge"] = {charName = "Ornn", displayName = "Call of the Forge God", slot = _R, type = "linear", speed = 1650, range = 2500, delay = 0.5, radius = 200, collision = false},
    ["PoppyQSpell"] = {charName = "Poppy", displayName = "Hammer Shock", slot = _Q, type = "linear", speed = math.huge, range = 430, delay = 0.332, radius = 100, collision = false},
    ["PoppyRSpell"] = {charName = "Poppy", displayName = "Keeper's Verdict", slot = _R, type = "linear", speed = 2000, range = 1200, delay = 0.33, radius = 100, collision = false},
    ["PykeQMelee"] = {charName = "Pyke", displayName = "Bone Skewer [Melee]", slot = _Q, type = "linear", speed = math.huge, range = 400, delay = 0.25, radius = 70, collision = false},
    ["PykeQRange"] = {charName = "Pyke", displayName = "Bone Skewer [Range]", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.2, radius = 70, collision = true},
    ["PykeE"] = {charName = "Pyke", displayName = "Phantom Undertow", slot = _E, type = "linear", speed = 3000, range = 25000, delay = 0, radius = 110, collision = false},
    ["QiyanaR"] = {charName = "Qiyana", displayName = "Supreme Display of Talent", slot = _R, type = "linear", speed = 2000, range = 950, delay = 0.25, radius = 190, collision = false},
    ["RakanW"] = {charName = "Rakan", displayName = "Grand Entrance", slot = _W, type = "circular", speed = math.huge, range = 650, delay = 0.7, radius = 265, collision = false},
    ["RengarE"] = {charName = "Rengar", displayName = "Bola Strike", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, collision = true},
    ["RumbleGrenade"] = {charName = "Rumble", displayName = "Electro Harpoon", slot = _E, type = "linear", speed = 2000, range = 850, delay = 0.25, radius = 60, collision = true},
    ["SeraphineE"] = {charName = "Seraphine", displayName = "Beat Drop", slot = _E, type = "linear", speed = 500, range = 1300, delay = 0.25, radius = 35, collision = false},
    ["SettE"] = {charName = "Sett", displayName = "Facebreaker", slot = _E, type = "linear", speed = math.huge, range = 490, delay = 0.25, radius = 175, collision = false},
    ["SennaW"] = {charName = "Senna", displayName = "Last Embrace", slot = _W, type = "linear", speed = 1150, range = 1300, delay = 0.25, radius = 60, collision = true},
    ["SejuaniR"] = {charName = "Sejuani", displayName = "Glacial Prison", slot = _R, type = "linear", speed = 1600, range = 1300, delay = 0.25, radius = 120, collision = false},
    ["ShyvanaTransformLeap"] = {charName = "Shyvana", displayName = "Transform Leap", slot = _R, type = "linear", speed = 700, range = 850, delay = 0.25, radius = 150, collision = false},
    ["ShenE"] = {charName = "Shen", displayName = "Shadow Dash", slot = _E, type = "linear", speed = 1200, range = 600, delay = 0, radius = 60, collision = false},
    ["SionQ"] = {charName = "Sion", displayName = "Decimating Smash", slot = _Q, type = "linear", speed = math.huge, range = 750, delay = 2, radius = 150, collision = false},
    ["SionE"] = {charName = "Sion", displayName = "Roar of the Slayer", slot = _E, type = "linear", speed = 1800, range = 800, delay = 0.25, radius = 80, collision = false},
    ["SkarnerFractureMissile"] = {charName = "Skarner", displayName = "Fracture", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, collision = false},
    ["SonaR"] = {charName = "Sona", displayName = "Crescendo", slot = _R, type = "linear", speed = 2400, range = 1000, delay = 0.25, radius = 140, collision = false},
    ["SorakaQ"] = {charName = "Soraka", displayName = "Starcall", slot = _Q, type = "circular", speed = 1150, range = 810, delay = 0.25, radius = 235, collision = false},
    ["SwainW"] = {charName = "Swain", displayName = "Vision of Empire", slot = _W, type = "circular", speed = math.huge, range = 3500, delay = 1.5, radius = 300, collision = false},
    ["SwainE"] = {charName = "Swain", displayName = "Nevermove", slot = _E, type = "linear", speed = 1800, range = 850, delay = 0.25, radius = 85, collision = false},
    ["TahmKenchQ"] = {charName = "TahmKench", displayName = "Tongue Lash", slot = _Q, type = "linear", speed = 2800, range = 800, delay = 0.25, radius = 70, collision = true},
    ["TaliyahWVC"] = {charName = "Taliyah", displayName = "Seismic Shove", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.85, radius = 150, collision = false},
    ["TaliyahR"] = {charName = "Taliyah", displayName = "Weaver's Wall", slot = _R, type = "linear", speed = 1700, range = 3000, delay = 1, radius = 120, collision = false},
    ["ThreshE"] = {charName = "Thresh", displayName = "Flay", slot = _E, type = "linear", speed = math.huge, range = 500, delay = 0.389, radius = 110, collision = true},
    ["ThreshQ"] = {charName = "Thresh", displayName = "Death Sentence", slot = _Q, type = "linear", speed = 1900, range = 1100, delay = 0.5, radius = 70, collision = true},
    ["TristanaW"] = {charName = "Tristana", displayName = "Rocket Jump", slot = _W, type = "circular", speed = 1100, range = 900, delay = 0.25, radius = 300, collision = false},
    ["UrgotE"] = {charName = "Urgot", displayName = "Disdain", slot = _E, type = "linear", speed = 1540, range = 475, delay = 0.45, radius = 100, collision = false},
    ["UrgotR"] = {charName = "Urgot", displayName = "Fear Beyond Death", slot = _R, type = "linear", speed = 3200, range = 1600, delay = 0.4, radius = 80, collision = false},
    ["VarusE"] = {charName = "Varus", displayName = "Hail of Arrows", slot = _E, type = "linear", speed = 1500, range = 925, delay = 0.242, radius = 260, collision = false},
    ["VarusR"] = {charName = "Varus", displayName = "Chain of Corruption", slot = _R, type = "linear", speed = 1950, range = 1200, delay = 0.25, radius = 120, collision = false},
    ["VelkozQ"] = {charName = "Velkoz", displayName = "Plasma Fission", slot = _Q, type = "linear", speed = 1300, range = 1050, delay = 0.25, radius = 50, collision = true},
    ["VelkozE"] = {charName = "Velkoz", displayName = "Tectonic Disruption", slot = _E, type = "circular", speed = math.huge, range = 800, delay = 0.8, radius = 185, collision = false},
    ["ViQ"] = {charName = "Vi", displayName = "Vault Breaker", slot = _Q, type = "linear", speed = 1500, range = 725, delay = 0, radius = 90, collision = false},
    ["ViktorGravitonField"] = {charName = "Viktor", displayName = "Graviton Field", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 1.75, radius = 270, collision = false},
    ["WarwickR"] = {charName = "Warwick", displayName = "Infinite Duress", slot = _R, type = "linear", speed = 1800, range = 3000, delay = 0.1, radius = 55, collision = false},
    ["XerathArcaneBarrage2"] = {charName = "Xerath", displayName = "Arcane Barrage", slot = _W, type = "circular", speed = math.huge, range = 1000, delay = 0.75, radius = 235, collision = false},
    ["XerathMageSpear"] = {charName = "Xerath", displayName = "Mage Spear", slot = _E, type = "linear", speed = 1400, range = 1050, delay = 0.2, radius = 60, collision = true},
    ["XinZhaoW"] = {charName = "XinZhao", displayName = "Wind Becomes Lightning", slot = _W, type = "linear", speed = 5000, range = 900, delay = 0.5, radius = 40, collision = false},
    ["YasuoQ3Mis"] = {charName = "Yasuo", displayName = "Yasuo Q3", slot = _Q, type = "linear", speed = 1200, range = 1000, delay = 0.339, radius = 80, collision = false},
    ["ZacQ"] = {charName = "Zac", displayName = "Stretching Strikes", slot = _Q, type = "linear", speed = 2800, range = 800, delay = 0.33, radius = 120, collision = false},
    ["ZiggsW"] = {charName = "Ziggs", displayName = "Satchel Charge", slot = _W, type = "circular", speed = 1750, range = 1000, delay = 0.25, radius = 240, collision = false},
    ["ZiggsE"] = {charName = "Ziggs", displayName = "Hexplosive Minefield", slot = _E, type = "circular", speed = 1800, range = 900, delay = 0.25, radius = 250, collision = false},
    ["ZileanQ"] = {charName = "Zilean", displayName = "Time Bomb", slot = _Q, type = "circular", speed = math.huge, range = 900, delay = 0.8, radius = 150, collision = false},
    ["ZoeE"] = {charName = "Zoe", displayName = "Sleepy Trouble Bubble", slot = _E, type = "linear", speed = 1700, range = 800, delay = 0.3, radius = 50, collision = true},
    ["ZyraE"] = {charName = "Zyra", displayName = "Grasping Roots", slot = _E, type = "linear", speed = 1150, range = 1100, delay = 0.25, radius = 70, collision = false},
    ["ZyraR"] = {charName = "Zyra", displayName = "Stranglethorns", slot = _R, type = "circular", speed = math.huge, range = 700, delay = 2, radius = 500, collision = false},
    ["BrandConflagration"] = {charName = "Brand", slot = _R, type = "targeted", displayName = "Conflagration", range = 625, cc = true},
    ["JarvanIVCataclysm"] = {charName = "JarvanIV", slot = _R, type = "targeted", displayName = "Cataclysm", range = 650},
    ["JayceThunderingBlow"] = {charName = "Jayce", slot = _E, type = "targeted", displayName = "Thundering Blow", range = 240},
    ["BlindMonkRKick"] = {charName = "LeeSin", slot = _R, type = "targeted", displayName = "Dragon's Rage", range = 375},
    ["LissandraR"] = {charName = "Lissandra", slot = _R, type = "targeted", displayName = "Frozen Tomb", range = 550},
    ["SeismicShard"] = {charName = "Malphite", slot = _Q, type = "targeted", displayName = "Seismic Shard", range = 625, cc = true},
    ["AlZaharNetherGrasp"] = {charName = "Malzahar", slot = _R, type = "targeted", displayName = "Nether Grasp", range = 700},
    ["MaokaiW"] = {charName = "Maokai", slot = _W, type = "targeted", displayName = "Twisted Advance", range = 525},
    ["NautilusR"] = {charName = "Nautilus", slot = _R, type = "targeted", displayName = "Depth Charge", range = 825},
    ["PoppyE"] = {charName = "Poppy", slot = _E, type = "targeted", displayName = "Heroic Charge", range = 475},
    ["RyzeW"] = {charName = "Ryze", slot = _W, type = "targeted", displayName = "Rune Prison", range = 615},
    ["Fling"] = {charName = "Singed", slot = _E, type = "targeted", displayName = "Fling", range = 125},
    ["SkarnerImpale"] = {charName = "Skarner", slot = _R, type = "targeted", displayName = "Impale", range = 350},
    ["TahmKenchW"] = {charName = "TahmKench", slot = _W, type = "targeted", displayName = "Devour", range = 250},
    ["TristanaR"] = {charName = "Tristana", slot = _R, type = "targeted", displayName = "Buster Shot", range = 669},
    ["TeemoQ"] = {charName = "Teemo", slot = _Q, type = "targeted", displayName = "Blinding Dart", range = 680},
    ["VeigarPrimordialBurst"] = {charName = "Veigar", slot = _R, type = "targeted", displayName = "Primordial Burst", range = 650},
    ["VolibearQ"] = {charName = "Volibear", displayName = "Thundering Smash", slot = _Q, type = "targeted", range = 200},
    ["YoneQ3"] = {charName = "Yone", displayName = "Mortal Steel [Storm]", slot = _Q, type = "linear", speed = 1500, range = 1050, delay = 0.25, radius = 80, collision = false},
    ["YoneR"] = {charName = "Yone", displayName = "Fate Sealed", slot = _R, type = "linear", speed = math.huge, range = 1000, delay = 0.75, radius = 112.5, collision = false}
}

-- Spell definitions
local SPELL_RANGES = {
    Q = 400,
    W = 750,
    R = 500
}

local SPELL_SPEEDS = {
    Q = 2000,
    W = 3200
}

local SPELL_DELAYS = {
    Q = 0.25,
    W = 0.75
}

local SPELL_RADIUS = {
    Q = 70,
    W = 70
}



-- Main class
class "DepressiveFiora"

function DepressiveFiora:__init()
    print("[Fiora Debug] Constructor iniciando...")
    self.Menu = nil
    self.PassiveVitals = {}
    self.UltimateVitals = {}
    self.LastScan = Game.Timer()
    
    -- Initialize Units for anti-CC
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.team ~= myHero.team then
            table.insert(Units, {unit = hero, spell = ""})
        end
    end
    
    print("[Fiora Debug] Creando menú...")
    self:CreateMenu()
    print("[Fiora Debug] Configurando callbacks...")
    self:SetupCallbacks()
    
    print("[DepressiveFiora] Script loaded successfully! Version " .. Version)
end

function DepressiveFiora:CreateMenu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveFiora", name = "Depressive - Fiora"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    -- Combo Menu
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
    self.Menu.Combo:MenuElement({id = "AntiCC", name = "Anti-CC with W", value = true})
    self.Menu.Combo:MenuElement({id = "AntiCCSpells", name = "Block CC Spells", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "Use R", value = true})
    self.Menu.Combo:MenuElement({id = "PriorityVitals", name = "Priority Vitals", value = true})
    self.Menu.Combo:MenuElement({id = "UltimateVitals", name = "Ultimate Vitals", value = true})
    
    -- Harass Menu
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "Use Q", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "Use E", value = true})
    
    -- Clear Menu
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "Use E", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana %", value = 40, min = 0, max = 100})
    
    -- KillSteal Menu
    self.Menu:MenuElement({type = MENU, id = "KillSteal", name = "KillSteal"})
    self.Menu.KillSteal:MenuElement({id = "UseQ", name = "Use Q", value = true})
    -- W is now only used for anti-CC, not for killsteal
    
    -- Draw Menu
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "Draw"})
    self.Menu.Draw:MenuElement({id = "DrawQ", name = "Draw Q Range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawW", name = "Draw W Range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawR", name = "Draw R Range", value = false})
    self.Menu.Draw:MenuElement({id = "DrawVitals", name = "Draw Vitals", value = true})
    self.Menu.Draw:MenuElement({id = "DebugVitals", name = "Debug Vitals in Chat", value = true})
end

function DepressiveFiora:SetupCallbacks()
    print("[Fiora Debug] Registrando callback Tick...")
    Callback.Add("Tick", function() self:Tick() end)
    print("[Fiora Debug] Registrando callback Draw...")
    Callback.Add("Draw", function() self:Draw() end)
    print("[Fiora Debug] Callbacks registrados correctamente")
end

function scanEnemyFioraObjects()
    local detectedVitals = {}
    local target = GetTarget(1000)
    
    -- Only scan if there's an enemy nearby
    if not target then 
        return detectedVitals 
    end
    

    
    -- Scan all objects near the enemy
    local totalObjects = Game.ObjectCount()
    
    for i = 1, totalObjects do
        local obj = Game.Object(i)
        if obj then
            -- Only process objects near the enemy (within 200 units)
            if GetDistance(target.pos, obj.pos) <= 500 then
                if obj.name:find("Fiora") then
                    if obj.name:find("SE") then
                        local offsetPos = Vector(obj.pos.x - 150, obj.pos.y, obj.pos.z) -- Left
                        table.insert(detectedVitals, {object = obj, direction = "SE", position = offsetPos})
                    elseif obj.name:find("SW") then
                        local offsetPos = Vector(obj.pos.x, obj.pos.y, obj.pos.z - 150) -- Up
                        table.insert(detectedVitals, {object = obj, direction = "SW", position = offsetPos})
                    elseif obj.name:find("NE") then
                        local offsetPos = Vector(obj.pos.x, obj.pos.y, obj.pos.z + 150) -- Down
                        table.insert(detectedVitals, {object = obj, direction = "NE", position = offsetPos})
                    elseif obj.name:find("NW") then
                        local offsetPos = Vector(obj.pos.x + 150, obj.pos.y, obj.pos.z) -- Right
                        table.insert(detectedVitals, {object = obj, direction = "NW", position = offsetPos})
                    end
                end
            end
        end
    end
    
    return detectedVitals
end

function DepressiveFiora:Tick()
    if myHero.dead or not myHero.valid then return end
    
    local mode = Mode()
    
    if mode == "Combo" then
        self:Combo()
    elseif mode == "Harass" then
        self:Harass()
    elseif mode == "Clear" then
        self:Clear()
    end
    
    -- Anti-CC with W
    if self.Menu.Combo.AntiCC:Value() and Ready(_W) then
        self:AntiCC()
    end
    
    -- Anti-CC Spells
    if self.Menu.Combo.AntiCCSpells:Value() and Ready(_W) then
        self:ProcessSpell()
        for i, spell in ipairs(DetectedSpells) do
            self:UseW(i, spell)
        end
    end
    
    self:KillSteal()

end

function DepressiveFiora:GetVitalPosition(vital)
    if not vital or not vital.object or not vital.type then return nil end
    local pos = vital.object.pos
    local offset = vital.type.Offset
    return Vector(pos.x + offset.x, pos.y + offset.y, pos.z + offset.z)
end

function DepressiveFiora:Combo()
    local target = GetTarget(700)
    if not target then return end
    
    -- Anti-CC with W during combo
    if self.Menu.Combo.AntiCC:Value() and Ready(_W) then
        self:AntiCC()
    end
    
    -- Anti-CC Spells during combo
    if self.Menu.Combo.AntiCCSpells:Value() and Ready(_W) then
        self:ProcessSpell()
        for i, spell in ipairs(DetectedSpells) do
            self:UseW(i, spell)
        end
    end
    
    -- Use R if enabled
    if self.Menu.Combo.UseR:Value() and Ready(_R) and GetDistance(myHero.pos, target.pos) <= SPELL_RANGES.R then
        if HasBuff(target, "fiorarmark") or GetEnemyCount(600) >= 2 then
            Control.CastSpell(HK_R, target)
        end
    end
    
    -- Use Q only on vitals (always prioritize vitals)
    if self.Menu.Combo.UseQ:Value() and Ready(_Q) then
        local detectedVitals = scanEnemyFioraObjects()
        local vitalToHit = nil
        
        -- Find closest vital to hit
        for _, vital in ipairs(detectedVitals) do
            if GetDistance(myHero.pos, vital.position) <= SPELL_RANGES.Q then
                if not vitalToHit or GetDistance(myHero.pos, vital.position) < GetDistance(myHero.pos, vitalToHit.position) then
                    vitalToHit = vital
                end
            end
        end
        
        -- Only use Q if vital found
        if vitalToHit then
            local qPosition = vitalToHit.position
            
            -- Adjust Q position based on vital direction for better hit chance
            if vitalToHit.direction == "SE" then
                -- Move slightly more to the left for SE vital
                qPosition = Vector(vitalToHit.position.x - 50, vitalToHit.position.y, vitalToHit.position.z)
            elseif vitalToHit.direction == "SW" then
                -- Move slightly more up for SW vital
                qPosition = Vector(vitalToHit.position.x, vitalToHit.position.y, vitalToHit.position.z - 50)
            elseif vitalToHit.direction == "NE" then
                -- Move slightly more down for NE vital
                qPosition = Vector(vitalToHit.position.x, vitalToHit.position.y, vitalToHit.position.z + 50)
            elseif vitalToHit.direction == "NW" then
                -- Move slightly more to the right for NW vital
                qPosition = Vector(vitalToHit.position.x + 50, vitalToHit.position.y, vitalToHit.position.z)
            end
            
            Control.CastSpell(HK_Q, qPosition)
        end
        -- No Q on target if no vitals found (only vitals or killsteal)
    end
    
    -- W is now only used for anti-CC, not in combo
    -- Removed W from combo logic to preserve it only for anti-CC
    
    -- Use E if enabled
    if self.Menu.Combo.UseE:Value() and Ready(_E) and GetDistance(myHero.pos, target.pos) <= 250 then
        Control.CastSpell(HK_E)
    end
end

function DepressiveFiora:Harass()
    local target = GetTarget(400)
    if not target then return end
    
    if self.Menu.Harass.UseQ:Value() and Ready(_Q) and GetDistance(myHero.pos, target.pos) <= SPELL_RANGES.Q then
        Control.CastSpell(HK_Q, target.pos)
    end
    
    if self.Menu.Harass.UseE:Value() and Ready(_E) and GetDistance(myHero.pos, target.pos) <= 250 then
        Control.CastSpell(HK_E)
    end
end

function DepressiveFiora:Clear()
    if myHero.mana / myHero.maxMana < self.Menu.Clear.Mana:Value() / 100 then return end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.valid and minion.team ~= myHero.team and GetDistance(myHero.pos, minion.pos) <= 500 then
            if self.Menu.Clear.UseQ:Value() and Ready(_Q) and GetDistance(myHero.pos, minion.pos) <= SPELL_RANGES.Q then
                Control.CastSpell(HK_Q, minion.pos)
            end
            
            if self.Menu.Clear.UseE:Value() and Ready(_E) and GetDistance(myHero.pos, minion.pos) <= 250 then
                Control.CastSpell(HK_E)
            end
        end
    end
end



function DepressiveFiora:AntiCC()
    -- Check if we're being CC'd
    if myHero.isStunned or myHero.isRooted or myHero.isTaunted or myHero.isCharmed or myHero.isSuppressed then
        -- Use W to break CC
        Control.CastSpell(HK_W, myHero.pos)
        return
    end
end

function DepressiveFiora:ProcessSpell()
    local unit, spell = OnProcessSpell()
    if unit and unit.isEnemy and spell and CCSpells[spell.name] and Ready(_W) then
        if GetDistance(myHero.pos, unit.pos) > 3000 then return end
        
        local detected = CCSpells[spell.name]
        local type = detected.type
        
        if type == "targeted" then
            if spell.target == myHero.handle then 
                Control.CastSpell(HK_W, unit.pos)
                table.remove(DetectedSpells, i)
            end
        else
            local startPos = Vector(spell.startPos)
            local placementPos = Vector(spell.placementPos)
            local unitPos = unit.pos
            local radius = detected.radius
            local range = detected.range
            local col = detected.collision
            local type = detected.type
            local endPos, range2 = CalculateEndPos(startPos, placementPos, unitPos, range, radius, col, type)
            
            table.insert(DetectedSpells, {
                startPos = startPos, 
                endPos = endPos, 
                startTime = Game.Timer(), 
                speed = detected.speed, 
                range = range2, 
                delay = detected.delay, 
                radius = radius, 
                radius2 = detected.radius2 or nil, 
                angle = detected.angle or nil, 
                type = type, 
                collision = col
            })
        end
    end
end

function DepressiveFiora:UseW(i, s)
    local startPos = s.startPos
    local endPos = s.endPos
    local travelTime = 0
    
    if s.speed == math.huge then 
        travelTime = s.delay 
    else 
        travelTime = s.range / s.speed + s.delay 
    end
    
    if s.type == "rectangular" then
        local startPosition = endPos - Vector(endPos - startPos):Normalized():Perpendicular() * (s.radius2 or 400)
        local endPosition = endPos + Vector(endPos - startPos):Normalized():Perpendicular() * (s.radius2 or 400)
        startPos = startPosition
        endPos = endPosition
    end
    
    if s.startTime + travelTime > Game.Timer() then
        local col = VectorPointProjectionOnLineSegment(startPos, endPos, myHero.pos)
        if s.type == "circular" or s.type == "linear" then 
            if GetDistance(myHero.pos, endPos) < (s.radius + myHero.boundingRadius) ^ 2 or 
               (col and GetDistance(myHero.pos, col) < (s.radius + myHero.boundingRadius * 1.25) ^ 2) then
                local t = s.speed ~= math.huge and CalculateCollisionTime(startPos, endPos, myHero.pos, s.startTime, s.speed, s.delay) or 0.29
                if t < 0.4 then
                    Control.CastSpell(HK_W, s.startPos)
                end
            end
        end
    else 
        table.remove(DetectedSpells, i) 
    end
end

function DepressiveFiora:KillSteal()
    local target = GetTarget(800)
    if not target then return end
    
    if self.Menu.KillSteal.UseQ:Value() and Ready(_Q) and GetDistance(myHero.pos, target.pos) <= SPELL_RANGES.Q then
        local damage = getdmg("Q", target, myHero)
        if damage > target.health then
            Control.CastSpell(HK_Q, target.pos)
        end
    end
    
    -- W is now only used for anti-CC, not for killsteal
end

function DepressiveFiora:Draw()
    if myHero.dead then return end
    
    if self.Menu.Draw.DrawQ:Value() and Ready(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGES.Q, 1, Draw.Color(255, 255, 255, 255))
    end
    
    if self.Menu.Draw.DrawW:Value() and Ready(_W) then
        Draw.Circle(myHero.pos, SPELL_RANGES.W, 1, Draw.Color(255, 255, 0, 255))
    end
    
    if self.Menu.Draw.DrawR:Value() and Ready(_R) then
        Draw.Circle(myHero.pos, SPELL_RANGES.R, 1, Draw.Color(255, 0, 255, 255))
    end
    
    
end

-- Initialize the script
print("[Fiora Debug] Script iniciando...")
_G.DepressiveFiora = DepressiveFiora()
print("[Fiora Debug] Script inicializado correctamente")
