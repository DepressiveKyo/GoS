-- DepressiveAIONext compatibility guard
if _G.__DEPRESSIVE_NEXT_FIORA_LOADED then return end
_G.__DEPRESSIVE_NEXT_FIORA_LOADED = true

local Version = 2.1
local Name = "DepressiveFiora"

-- Hero validation
local Heroes = {"Fiora"}
if not table.contains(Heroes, myHero.charName) then return end

-- Load prediction system
require("DepressivePrediction")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
    end
end, 1.0)

-- ═══════════════════════════════════════════════════════════════════════════
-- LOCALIZED FUNCTIONS (Performance optimization)
-- ═══════════════════════════════════════════════════════════════════════════
local math_sqrt = math.sqrt
local math_min = math.min
local math_max = math.max
local math_huge = math.huge
local math_floor = math.floor

local table_insert = table.insert
local table_remove = table.remove

local Game = Game
local Control = Control
local Draw = Draw
local myHero = myHero
local Vector = Vector

local GameTimer = Game.Timer
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameObjectCount = Game.ObjectCount
local GameObject = Game.Object

-- ═══════════════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════════
local _Q, _W, _E, _R = 0, 1, 2, 3
local SPELL_RANGE_Q = 400
local SPELL_RANGE_Q_SQR = 160000
local SPELL_RANGE_W = 750
local SPELL_RANGE_W_SQR = 562500
local SPELL_RANGE_R = 500
local SPELL_RANGE_R_SQR = 250000

-- ═══════════════════════════════════════════════════════════════════════════
-- CC SPELLS DATABASE (Reduced - only high priority)
-- ═══════════════════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS (Optimized)
-- ═══════════════════════════════════════════════════════════════════════════
local function GetDistanceSqr(p1, p2)
    local pos1 = p1.pos or p1
    local pos2 = p2.pos or p2
    local dx = pos1.x - pos2.x
    local dz = pos1.z - pos2.z
    return dx * dx + dz * dz
end

local function GetDistance(p1, p2)
    return math_sqrt(GetDistanceSqr(p1, p2))
end

local function IsValid(unit)
    return unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable
end

local function Ready(slot)
    return myHero:GetSpellData(slot).currentCd == 0 and myHero:GetSpellData(slot).level > 0 and Game.CanUseSpell(slot) == 0
end

local function ExtendVector(from, to, dist)
    local dx = to.x - from.x
    local dz = to.z - from.z
    local d = math_sqrt(dx * dx + dz * dz)
    if d == 0 then return to end
    return Vector(from.x + dx / d * dist, from.y or to.y, from.z + dz / d * dist)
end

local function HasBuff(unit, buffName)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name:lower():find(buffName) then
            return true
        end
    end
    return false
end

-- Mode function
local function Mode()
    if _G.SDK and _G.SDK.Orbwalker then
        if _G.SDK.Orbwalker:HasMode(_G.SDK.ORBWALKER_MODE_COMBO) then return "Combo"
        elseif _G.SDK.Orbwalker:HasMode(_G.SDK.ORBWALKER_MODE_HARASS) then return "Harass"
        elseif _G.SDK.Orbwalker:HasMode(_G.SDK.ORBWALKER_MODE_LANECLEAR) then return "Clear"
        elseif _G.SDK.Orbwalker:HasMode(_G.SDK.ORBWALKER_MODE_FLEE) then return "Flee"
        end
    elseif _G.GOS then return _G.GOS:GetMode()
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VITAL SYSTEM (Optimized)
-- ═══════════════════════════════════════════════════════════════════════════
local VitalSystem = {
    Vitals = {},
    LastScan = 0,
    ScanInterval = 0.1, -- Reduced scan frequency
    VitalDist = 140,
    QOffset = 50,
}

local VITAL_OFFSETS = {
    ["NW"] = {x = 1, z = 1},
    ["NE"] = {x = -1, z = 1},
    ["SE"] = {x = -1, z = -1},
    ["SW"] = {x = 1, z = -1},
}

local INV_SQRT2 = 1 / math_sqrt(2)

function VitalSystem:GetDirection(name)
    if name:find("_nw") or name:find("NW") then return "NW"
    elseif name:find("_ne") or name:find("NE") then return "NE"
    elseif name:find("_se") or name:find("SE") then return "SE"
    elseif name:find("_sw") or name:find("SW") then return "SW"
    end
    return nil
end

function VitalSystem:Scan()
    local now = GameTimer()
    if now - self.LastScan < self.ScanInterval then
        return self.Vitals
    end
    self.LastScan = now
    
    -- Clear and reuse table
    for k in pairs(self.Vitals) do self.Vitals[k] = nil end
    local vitalCount = 0
    
    local objCount = GameObjectCount()
    for i = 1, objCount do
        local obj = GameObject(i)
        if obj and obj.name and obj.pos then
            local name = obj.name
            if name:find("Fiora") and (name:find("Passive") or name:find("R_")) then
                local dir = self:GetDirection(name)
                if dir then
                    -- Find owner
                    local owner = nil
                    local minDistSqr = 90000 -- 300^2
                    
                    for j = 1, GameHeroCount() do
                        local h = GameHero(j)
                        if h and h.team ~= myHero.team and IsValid(h) then
                            local distSqr = GetDistanceSqr(obj.pos, h.pos)
                            if distSqr < minDistSqr then
                                minDistSqr = distSqr
                                owner = h
                            end
                        end
                    end
                    
                    if not owner then
                        for j = 1, GameMinionCount() do
                            local m = GameMinion(j)
                            if m and m.team ~= myHero.team and IsValid(m) then
                                local distSqr = GetDistanceSqr(obj.pos, m.pos)
                                if distSqr < minDistSqr then
                                    minDistSqr = distSqr
                                    owner = m
                                end
                            end
                        end
                    end
                    
                    if owner then
                        local offset = VITAL_OFFSETS[dir]
                        local vitalPos = Vector(
                            owner.pos.x + offset.x * INV_SQRT2 * self.VitalDist,
                            owner.pos.y,
                            owner.pos.z + offset.z * INV_SQRT2 * self.VitalDist
                        )
                        
                        local qPos = Vector(
                            vitalPos.x + offset.x * INV_SQRT2 * self.QOffset,
                            vitalPos.y,
                            vitalPos.z + offset.z * INV_SQRT2 * self.QOffset
                        )
                        
                        vitalCount = vitalCount + 1
                        self.Vitals[vitalCount] = {
                            target = owner,
                            dir = dir,
                            pos = vitalPos,
                            qPos = qPos
                        }
                    end
                end
            end
        end
    end
    
    return self.Vitals
end

function VitalSystem:GetBest(target)
    local vitals = self:Scan()
    local best = nil
    local bestDistSqr = math_huge
    local myPos = myHero.pos
    
    for i = 1, #vitals do
        local v = vitals[i]
        if v.target and v.target.networkID == target.networkID then
            local distSqr = GetDistanceSqr(myPos, v.qPos)
            if distSqr < bestDistSqr and distSqr <= SPELL_RANGE_Q_SQR then
                bestDistSqr = distSqr
                best = v
            end
        end
    end
    
    return best
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RIPOSTE SYSTEM (Optimized)
-- ═══════════════════════════════════════════════════════════════════════════
local RiposteSystem = {
    Spells = {},
    LastProcess = 0,
    ProcessInterval = 0.05,
}

function RiposteSystem:Process()
    local now = GameTimer()
    if now - self.LastProcess < self.ProcessInterval then return end
    self.LastProcess = now
    
    -- Clean old
    for i = #self.Spells, 1, -1 do
        if now - self.Spells[i].time > 1.5 then
            table_remove(self.Spells, i)
        end
    end
    
    -- Detect new
    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if enemy and enemy.team ~= myHero.team and not enemy.dead then
            local spell = enemy.activeSpell
            if spell and spell.valid and spell.name then
                local data = CCSpells[spell.name]
                if data then
                    local key = enemy.networkID .. spell.name .. math_floor(spell.endTime * 10)
                    local found = false
                    for j = 1, #self.Spells do
                        if self.Spells[j].key == key then found = true break end
                    end
                    
                    if not found then
                        local willHit, timeToHit = self:WillHit(enemy, spell, data)
                        if willHit then
                            table_insert(self.Spells, {
                                key = key,
                                caster = enemy,
                                data = data,
                                time = now,
                                hitTime = timeToHit,
                                startPos = Vector(spell.startPos),
                                endPos = Vector(spell.placementPos),
                            })
                        end
                    end
                end
            end
        end
    end
end

function RiposteSystem:WillHit(caster, spell, data)
    local myPos = myHero.pos
    local startPos = Vector(spell.startPos)
    local endPos = Vector(spell.placementPos)
    
    if data.type == "targeted" then
        if spell.target == myHero.handle then
            return true, data.delay
        end
    elseif data.type == "linear" then
        local distSqr = GetDistanceSqr(caster, myHero)
        if distSqr > (data.range + 200) * (data.range + 200) then return false, 0 end
        
        local dx = endPos.x - startPos.x
        local dz = endPos.z - startPos.z
        local len = math_sqrt(dx*dx + dz*dz)
        if len == 0 then return false, 0 end
        
        dx, dz = dx/len, dz/len
        local tx = myPos.x - startPos.x
        local tz = myPos.z - startPos.z
        local proj = tx*dx + tz*dz
        
        if proj < 0 or proj > data.range then return false, 0 end
        
        local closestX = startPos.x + dx * proj
        local closestZ = startPos.z + dz * proj
        local distToLine = math_sqrt((myPos.x-closestX)^2 + (myPos.z-closestZ)^2)
        
        if distToLine <= data.radius + myHero.boundingRadius + 20 then
            local time = data.speed == math_huge and data.delay or (proj / data.speed + data.delay)
            return true, time
        end
    elseif data.type == "circular" then
        local center = data.range > 0 and endPos or caster.pos
        local distSqr = GetDistanceSqr(myPos, center)
        if distSqr <= (data.radius + myHero.boundingRadius)^2 then
            return true, data.delay
        end
    end
    
    return false, 0
end

function RiposteSystem:ShouldParry(minDanger)
    local now = GameTimer()
    local best = nil
    local bestDanger = 0
    
    for i = 1, #self.Spells do
        local s = self.Spells[i]
        local timeLeft = s.hitTime - (now - s.time)
        if timeLeft > 0 and timeLeft < 0.75 then
            local danger = s.data.danger or 3
            if danger >= minDanger and danger > bestDanger then
                bestDanger = danger
                best = s
            end
        end
    end
    
    return best
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DAMAGE CALCULATOR (Simplified)
-- ═══════════════════════════════════════════════════════════════════════════
local function GetQDamage(target)
    local lvl = myHero:GetSpellData(_Q).level
    if lvl == 0 then return 0 end
    local base = 65 + lvl * 5
    local dmg = base + myHero.totalDamage * (0.9 + lvl * 0.05)
    return dmg * (100 / (100 + target.armor))
end

local function GetVitalDamage(target)
    local bonusAD = myHero.totalDamage - myHero.baseDamage
    return target.maxHealth * (0.025 + bonusAD / 100 * 0.045)
end

local function CanKill(target)
    return GetQDamage(target) + GetVitalDamage(target) >= target.health
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TARGET SELECTOR (Simplified)
-- ═══════════════════════════════════════════════════════════════════════════
local function GetTarget(range)
    if _G.SDK and _G.SDK.TargetSelector then
        local t = _G.SDK.TargetSelector:GetTarget(range)
        if t and IsValid(t) then return t end
    end
    
    local best, bestHP = nil, math_huge
    local rangeSqr = range * range
    
    for i = 1, GameHeroCount() do
        local h = GameHero(i)
        if h and h.team ~= myHero.team and IsValid(h) then
            local distSqr = GetDistanceSqr(myHero, h)
            if distSqr <= rangeSqr and h.health < bestHP then
                bestHP = h.health
                best = h
            end
        end
    end
    
    return best
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN CLASS
-- ═══════════════════════════════════════════════════════════════════════════
class "DepressiveFiora"

function DepressiveFiora:__init()
    self:CreateMenu()
    Callback.Add("Tick", function() self:OnTick() end)
    Callback.Add("Draw", function() self:OnDraw() end)
    print("[DepressiveFiora] v" .. Version .. " loaded!")
end

function DepressiveFiora:CreateMenu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveFiora", name = "Depressive - Fiora"})
    
    -- Combo
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "[Combo]"})
    self.Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
    self.Menu.Combo:MenuElement({id = "QVital", name = "Q Only Vitals", value = true})
    self.Menu.Combo:MenuElement({id = "W", name = "Auto Riposte", value = true})
    self.Menu.Combo:MenuElement({id = "WDanger", name = "Min Danger Level", value = 1, min = 1, max = 5})
    self.Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
    self.Menu.Combo:MenuElement({id = "R", name = "Use R", value = true})
    self.Menu.Combo:MenuElement({id = "RHP", name = "R if Enemy HP% <", value = 70, min = 10, max = 100})
    
    -- Harass
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "[Harass]"})
    self.Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana%", value = 30, min = 0, max = 100})
    
    -- Clear
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "[Clear]"})
    self.Menu.Clear:MenuElement({id = "Q", name = "Use Q", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana%", value = 40, min = 0, max = 100})
    
    -- KillSteal
    self.Menu:MenuElement({type = MENU, id = "KS", name = "[KillSteal]"})
    self.Menu.KS:MenuElement({id = "Q", name = "Use Q", value = true})
    
    -- Draw
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "[Draw]"})
    self.Menu.Draw:MenuElement({id = "Q", name = "Draw Q", value = true})
    self.Menu.Draw:MenuElement({id = "Vital", name = "Draw Vitals", value = true})
    self.Menu.Draw:MenuElement({id = "Path", name = "Draw Q Path", value = true})
end

function DepressiveFiora:OnTick()
    if myHero.dead then return end
    
    -- Riposte (always active)
    if self.Menu.Combo.W:Value() and Ready(_W) then
        RiposteSystem:Process()
        local spell = RiposteSystem:ShouldParry(self.Menu.Combo.WDanger:Value())
        if spell then
            local dir = spell.caster and spell.caster.pos or spell.startPos
            Control.CastSpell(HK_W, dir)
            return
        end
    end
    
    local mode = Mode()
    
    if mode == "Combo" then
        self:Combo()
    elseif mode == "Harass" then
        self:Harass()
    elseif mode == "Clear" then
        self:Clear()
    end
    
    -- KillSteal
    if self.Menu.KS.Q:Value() then
        self:KillSteal()
    end
end

function DepressiveFiora:Combo()
    local target = GetTarget(550)
    if not target then return end
    
    local distSqr = GetDistanceSqr(myHero, target)
    
    -- R
    if self.Menu.Combo.R:Value() and Ready(_R) and distSqr <= SPELL_RANGE_R_SQR then
        local hpPct = target.health / target.maxHealth * 100
        if hpPct <= self.Menu.Combo.RHP:Value() and not HasBuff(target, "fiorarmark") then
            Control.CastSpell(HK_R, target)
            return
        end
    end
    
    -- Q
    if self.Menu.Combo.Q:Value() and Ready(_Q) then
        local vital = VitalSystem:GetBest(target)
        if vital then
            Control.CastSpell(HK_Q, vital.qPos)
            return
        elseif not self.Menu.Combo.QVital:Value() and distSqr <= SPELL_RANGE_Q_SQR then
            Control.CastSpell(HK_Q, target.pos)
            return
        end
    end
    
    -- E
    if self.Menu.Combo.E:Value() and Ready(_E) and distSqr <= 62500 then -- 250^2
        Control.CastSpell(HK_E)
    end
end

function DepressiveFiora:Harass()
    if myHero.mana / myHero.maxMana * 100 < self.Menu.Harass.Mana:Value() then return end
    
    local target = GetTarget(SPELL_RANGE_Q + 50)
    if not target then return end
    
    if self.Menu.Harass.Q:Value() and Ready(_Q) then
        local vital = VitalSystem:GetBest(target)
        if vital then
            Control.CastSpell(HK_Q, vital.qPos)
        end
    end
end

function DepressiveFiora:Clear()
    if myHero.mana / myHero.maxMana * 100 < self.Menu.Clear.Mana:Value() then return end
    if not self.Menu.Clear.Q:Value() or not Ready(_Q) then return end
    
    local best, bestHP = nil, math_huge
    for i = 1, GameMinionCount() do
        local m = GameMinion(i)
        if m and m.team ~= myHero.team and IsValid(m) then
            local distSqr = GetDistanceSqr(myHero, m)
            if distSqr <= SPELL_RANGE_Q_SQR and m.health < bestHP then
                bestHP = m.health
                best = m
            end
        end
    end
    
    if best then
        Control.CastSpell(HK_Q, best.pos)
    end
end

function DepressiveFiora:KillSteal()
    if not Ready(_Q) then return end
    
    for i = 1, GameHeroCount() do
        local h = GameHero(i)
        if h and h.team ~= myHero.team and IsValid(h) then
            local distSqr = GetDistanceSqr(myHero, h)
            if distSqr <= SPELL_RANGE_Q_SQR and CanKill(h) then
                local vital = VitalSystem:GetBest(h)
                Control.CastSpell(HK_Q, vital and vital.qPos or h.pos)
                return
            end
        end
    end
end

function DepressiveFiora:OnDraw()
    if myHero.dead or not self.Menu.Draw then return end
    
    local myPos = myHero.pos
    
    -- Q Range
    if self.Menu.Draw.Q:Value() and Ready(_Q) then
        Draw.Circle(myPos, SPELL_RANGE_Q, 1, Draw.Color(200, 100, 200, 255))
    end
    
    -- Vitals
    if self.Menu.Draw.Vital:Value() then
        local vitals = VitalSystem:Scan()
        for i = 1, #vitals do
            local v = vitals[i]
            if v.pos then
                Draw.Circle(v.pos, 35, 2, Draw.Color(255, 255, 215, 0))
                
                -- Path
                if self.Menu.Draw.Path:Value() and v.qPos then
                    local distSqr = GetDistanceSqr(myPos, v.qPos)
                    if distSqr <= SPELL_RANGE_Q_SQR then
                        local myScreen = myPos:To2D()
                        local qScreen = v.qPos:To2D()
                        if myScreen and qScreen and myScreen.x > 0 and qScreen.x > 0 then
                            Draw.Line(myScreen, qScreen, 2, Draw.Color(180, 0, 255, 0))
                        end
                    end
                end
            end
        end
    end
end

-- Initialize
if not _G.DepressiveFioraInstance then
    _G.DepressiveFioraInstance = DepressiveFiora()
end