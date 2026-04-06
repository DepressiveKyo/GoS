if _G.__DEPRESSIVE_NEXT_FIORA_LOADED then return end
_G.__DEPRESSIVE_NEXT_FIORA_LOADED = true

local Version = 2.2

local Heroes = {"Fiora"}
if not table.contains(Heroes, myHero.charName) then return end

local function ResolveLoadedTable(globalName, ...)
    local lib = rawget(_G, globalName)
    if type(lib) == "table" then
        return lib
    end

    for i = 1, select("#", ...) do
        local ok, loaded = pcall(require, select(i, ...))
        if ok then
            lib = rawget(_G, globalName)
            if type(lib) == "table" then
                return lib
            end
            if type(loaded) == "table" then
                return loaded
            end
        end
    end

    return nil
end

local GGPrediction = ResolveLoadedTable("GGPrediction", "GGPrediction", "Common/GGPrediction")
local MapPosition = ResolveLoadedTable("MapPosition", "MapPositionGOS", "Common/MapPositionGOS")

local math_sqrt = math.sqrt
local math_abs = math.abs
local math_acos = math.acos
local math_min = math.min
local math_max = math.max
local math_huge = math.huge
local math_floor = math.floor
local string_find = string.find
local string_lower = string.lower

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
local GameCanUseSpell = Game.CanUseSpell
local GameIsChatOpen = Game.IsChatOpen
local ControlCastSpell = Control.CastSpell
local ControlMove = Control.Move
local DrawCircle = Draw.Circle
local DrawLine = Draw.Line
local DrawColor = Draw.Color

local _Q, _W, _E, _R = 0, 1, 2, 3
local HK_Q = HK_Q or _Q
local HK_W = HK_W or _W
local HK_E = HK_E or _E
local HK_R = HK_R or _R
local SPELL_RANGE_Q = 400
local SPELL_RANGE_Q_SQR = 160000
local SPELL_RANGE_W = 750
local SPELL_RANGE_W_SQR = 562500
local SPELL_RANGE_R = 500
local SPELL_RANGE_R_SQR = 250000
local Q_TARGET_FAR_CAST_EXTRA = 60
local Q_VITAL_FAR_CAST_EXTRA = 18
local MODE_CACHE_DURATION = 0.05
local HERO_CACHE_COMBAT = 0.08
local HERO_CACHE_IDLE = 0.16
local MINION_CACHE_COMBAT = 0.10
local MINION_CACHE_IDLE = 0.20
local RANGE_CACHE_DURATION = 0.05
local TARGET_CACHE_DURATION = 0.05
local BUFF_CACHE_DURATION = 0.05
local VITAL_OBJECT_CACHE_COMBAT = 0.08
local VITAL_OBJECT_CACHE_IDLE = 0.14
local VITAL_OWNER_RANGE_SQR = 300 * 300
local WALLJUMP_CHECK_DISTANCE = 200
local WALLJUMP_CAST_DISTANCE = 395
local WALLJUMP_HEIGHT_TOLERANCE = 225
local WALLJUMP_CAST_DELAY = 0.15
local WALLJUMP_PREWALL_BUFFER = 18
local WALLJUMP_TOUCH_EXTRA = 10
local LOAD_DELAY_TIME = 5
local GG_HITCHANCE_NORMAL = GGPrediction and GGPrediction.HITCHANCE_NORMAL or nil
local GG_Q_PREDICTION = GGPrediction and GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_CIRCLE,
    Delay = 0.15,
    Radius = 70,
    Range = SPELL_RANGE_Q,
    Speed = 2000,
    Collision = false
}) or nil
local GG_W_PREDICTION = GGPrediction and GGPrediction:SpellPrediction({
    Type = GGPrediction.SPELLTYPE_LINE,
    Delay = 0.75,
    Radius = 70,
    Range = SPELL_RANGE_W,
    Speed = 3200,
    Collision = false
}) or nil

local ActiveMode = "None"
local PerfCache = {
    mode = {tick = 0, value = nil},
    enemyHeroes = {tick = 0, all = {}, byRange = {}},
    enemyMinions = {tick = 0, all = {}, byRange = {}},
    vitalObjects = {tick = 0, all = {}},
    target = {},
    buffSearch = {}
}

local SPELL_SLOT_LABELS = {
    [-1] = "P",
    [_Q] = "Q",
    [_W] = "W",
    [_E] = "E",
    [_R] = "R"
}

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
    ["DariusE"] = {charName = "Darius", displayName = "Apprehend", missileName = "DariusAxeGrabCone", slot = _E, type = "conic", speed = 2000, range = 535, delay = 0.25, radius = 300, angle = 45, cc = true, danger = 4, collision = false},
    ["DariusR"] = {charName = "Darius", displayName = "Noxian Guillotine", slot = _R, type = "targeted", aliases = {"DariusExecute"}, range = 460, cc = true, danger = 5},
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
    ["PowerFistAttack"] = {charName = "Blitzcrank", slot = _E, type = "targeted", displayName = "Power Fist", range = 250, cc = true, danger = 4},
    ["GarenQAttack"] = {charName = "Garen", slot = _Q, type = "targeted", displayName = "Decisive Strike", range = 250, cc = true, danger = 3},
    ["LeonaShieldOfDaybreak"] = {charName = "Leona", slot = _Q, type = "targeted", displayName = "Shield of Daybreak", range = 250, cc = true, danger = 4},
    ["LeonaShieldOfDaybreakAttack"] = {charName = "Leona", slot = _Q, type = "targeted", displayName = "Shield of Daybreak", range = 250, cc = true, danger = 4},
    ["MaokaiW"] = {charName = "Maokai", slot = _W, type = "targeted", displayName = "Twisted Advance", range = 525},
    ["NautilusRavageStrikeAttack"] = {charName = "Nautilus", slot = -1, type = "targeted", displayName = "Staggering Blow", range = 250, cc = true, danger = 3},
    ["NautilusR"] = {charName = "Nautilus", slot = _R, type = "targeted", displayName = "Depth Charge", range = 825},
    ["PoppyE"] = {charName = "Poppy", slot = _E, type = "targeted", displayName = "Heroic Charge", range = 475},
    ["RenektonPreExecute"] = {charName = "Renekton", slot = _W, type = "targeted", displayName = "Ruthless Predator", range = 250, cc = true, danger = 3},
    ["RenektonExecute"] = {charName = "Renekton", slot = _W, type = "targeted", displayName = "Ruthless Predator", range = 250, cc = true, danger = 3},
    ["RenektonSuperExecute"] = {charName = "Renekton", slot = _W, type = "targeted", displayName = "Ruthless Predator", range = 250, cc = true, danger = 4},
    ["RyzeW"] = {charName = "Ryze", slot = _W, type = "targeted", displayName = "Rune Prison", range = 615},
    ["Fling"] = {charName = "Singed", slot = _E, type = "targeted", displayName = "Fling", range = 125},
    ["SkarnerImpale"] = {charName = "Skarner", slot = _R, type = "targeted", displayName = "Impale", range = 350},
    ["SettR"] = {charName = "Sett", slot = _R, type = "targeted", displayName = "The Show Stopper", range = 400, cc = true, danger = 5},
    ["TahmKenchW"] = {charName = "TahmKench", slot = _W, type = "targeted", displayName = "Devour", range = 250},
    ["TristanaR"] = {charName = "Tristana", slot = _R, type = "targeted", displayName = "Buster Shot", range = 669},
    ["TeemoQ"] = {charName = "Teemo", slot = _Q, type = "targeted", displayName = "Blinding Dart", range = 680},
    ["VeigarPrimordialBurst"] = {charName = "Veigar", slot = _R, type = "targeted", displayName = "Primordial Burst", range = 650},
    ["VayneCondemn"] = {charName = "Vayne", slot = _E, type = "targeted", displayName = "Condemn", missileName = "VayneCondemnMissile", range = 550, cc = true, danger = 3},
    ["VolibearQ"] = {charName = "Volibear", displayName = "Thundering Smash", slot = _Q, type = "targeted", range = 200},
    ["VolibearQAttack"] = {charName = "Volibear", displayName = "Thundering Smash", slot = _Q, type = "targeted", range = 200, cc = true, danger = 3},
    ["YoneQ3"] = {charName = "Yone", displayName = "Mortal Steel [Storm]", slot = _Q, type = "linear", speed = 1500, range = 1050, delay = 0.25, radius = 80, collision = false},
    ["YoneR"] = {charName = "Yone", displayName = "Fate Sealed", slot = _R, type = "linear", speed = math.huge, range = 1000, delay = 0.75, radius = 112.5, collision = false}
}

local RiposteMenuSpells = {}
local RiposteSpellLookup = {}
local RiposteMenuLookup = {}
local RipostePrimaryByDisplayKey = {}

local RIPOSTE_EXTRA_SPELLS = {
    ["AatroxQ"] = {charName = "Aatrox", displayName = "The Darkin Blade [First]", slot = _Q, type = "linear", speed = math.huge, range = 650, delay = 0.6, radius = 130, danger = 3, cc = true, collision = false},
    ["AatroxQ2"] = {charName = "Aatrox", displayName = "The Darkin Blade [Second]", slot = _Q, type = "polygon", speed = math.huge, range = 500, delay = 0.6, radius = 200, danger = 3, cc = true, collision = false},
    ["AatroxQ3"] = {charName = "Aatrox", displayName = "The Darkin Blade [Third]", slot = _Q, type = "circular", speed = math.huge, range = 200, delay = 0.6, radius = 300, danger = 4, cc = true, collision = false},
    ["AatroxW"] = {charName = "Aatrox", displayName = "Infernal Chains", missileName = "AatroxW", slot = _W, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 80, danger = 2, cc = true, collision = true},
    ["AhriQ"] = {charName = "Ahri", displayName = "Orb of Deception", missileName = "AhriOrbMissile", slot = _Q, type = "linear", speed = 2500, range = 880, delay = 0.25, radius = 100, danger = 2, cc = false, collision = false},
    ["AhriE"] = {charName = "Ahri", displayName = "Seduce", missileName = "AhriSeduceMissile", slot = _E, type = "linear", speed = 1500, range = 975, delay = 0.25, radius = 60, danger = 1, cc = true, collision = true},
    ["AkaliQ"] = {charName = "Akali", displayName = "Five Point Strike", slot = _Q, type = "conic", speed = 3200, range = 550, delay = 0.25, radius = 60, angle = 45, danger = 2, cc = false, collision = false},
    ["AkaliE"] = {charName = "Akali", displayName = "Shuriken Flip", missileName = "AkaliEMis", slot = _E, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 70, danger = 2, cc = false, collision = true},
    ["AkaliR"] = {charName = "Akali", displayName = "Perfect Execution [First]", slot = _R, type = "linear", speed = 1800, range = 675, delay = 0, radius = 65, danger = 4, cc = true, collision = false},
    ["AkaliRb"] = {charName = "Akali", displayName = "Perfect Execution [Second]", slot = _R, type = "linear", speed = 3600, range = 525, delay = 0, radius = 65, danger = 4, cc = false, collision = false},
    ["AkshanQ"] = {charName = "Akshan", displayName = "Avengerang", missileName = "AkshanQ", slot = _Q, type = "linear", speed = 1500, range = 850, delay = 0.25, radius = 60, danger = 2, cc = false, collision = false},
    ["AmbessaR"] = {charName = "Ambessa", displayName = "Public Execution", missileName = "AmbessaR", slot = _R, type = "linear", speed = math.huge, range = 2500, delay = 0.25, radius = 150, danger = 5, cc = true, collision = false},
    ["AuroraQ"] = {charName = "Aurora", displayName = "Twofold Hex", missileName = "AuroraQ", slot = _Q, type = "linear", speed = 1550, range = 900, delay = 0.25, radius = 60, danger = 2, cc = false, collision = true},
    ["AuroraE"] = {charName = "Aurora", displayName = "The Weirding", missileName = "AuroraE", slot = _E, type = "circular", speed = math.huge, range = 825, delay = 0.25, radius = 80, danger = 3, cc = true, collision = false},
    ["Pulverize"] = {charName = "Alistar", displayName = "Pulverize", slot = _Q, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 365, danger = 3, cc = true, collision = false},
    ["BandageToss"] = {charName = "Amumu", displayName = "Bandage Toss", missileName = "SadMummyBandageToss", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.25, radius = 80, danger = 3, cc = true, collision = true},
    ["CurseoftheSadMummy"] = {charName = "Amumu", displayName = "Curse of the Sad Mummy", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 550, danger = 5, cc = true, collision = false},
    ["FlashFrostSpell"] = {charName = "Anivia", displayName = "Flash Frost", missileName = "FlashFrostSpell", slot = _Q, type = "linear", speed = 950, range = 1100, delay = 0.25, radius = 110, danger = 2, cc = true, collision = false},
    ["AnnieW"] = {charName = "Annie", displayName = "Incinerate", slot = _W, type = "conic", speed = math.huge, range = 600, delay = 0.25, radius = 0, angle = 50, danger = 2, cc = false, collision = false},
    ["AnnieR"] = {charName = "Annie", displayName = "Summon: Tibbers", slot = _R, type = "circular", speed = math.huge, range = 600, delay = 0.25, radius = 290, danger = 5, cc = false, collision = false},
    ["ApheliosCalibrumQ"] = {charName = "Aphelios", displayName = "Moonshot", missileName = "ApheliosCalibrumQ", slot = _Q, type = "linear", speed = 1850, range = 1450, delay = 0.35, radius = 60, danger = 1, cc = false, collision = true},
    ["ApheliosInfernumQ"] = {charName = "Aphelios", displayName = "Duskwave", slot = _Q, type = "conic", speed = 1500, range = 850, delay = 0.25, radius = 65, angle = 45, danger = 2, cc = false, collision = false},
    ["ApheliosR"] = {charName = "Aphelios", displayName = "Moonlight Vigil", missileName = "ApheliosRMis", slot = _R, type = "linear", speed = 2050, range = 1600, delay = 0.5, radius = 125, danger = 3, cc = false, collision = false},
    ["Volley"] = {charName = "Ashe", displayName = "Volley", missileName = "VolleyRightAttack", slot = _W, type = "conic", speed = 2000, range = 1200, delay = 0.25, radius = 20, angle = 40, danger = 2, cc = true, collision = true},
    ["EnchantedCrystalArrow"] = {charName = "Ashe", displayName = "Enchanted Crystal Arrow", missileName = "EnchantedCrystalArrow", slot = _R, type = "linear", speed = 1600, range = 12500, delay = 0.25, radius = 130, danger = 4, cc = true, collision = false},
    ["AurelionSolQ"] = {charName = "AurelionSol", displayName = "Starsurge", missileName = "AurelionSolQMissile", slot = _Q, type = "linear", speed = 850, range = 1075, delay = 0, radius = 110, danger = 2, cc = true, collision = false},
    ["AurelionSolR"] = {charName = "AurelionSol", displayName = "Voice of Light", slot = _R, type = "linear", speed = 4500, range = 1500, delay = 0.35, radius = 120, danger = 5, cc = true, collision = false},
    ["AzirR"] = {charName = "Azir", displayName = "Emperor's Divide", slot = _R, type = "linear", speed = 1400, range = 500, delay = 0.3, radius = 250, danger = 5, cc = true, collision = false},
    ["BelvethQ"] = {charName = "BelVeth", displayName = "Void Surge", slot = _Q, type = "linear", speed = 1200, range = 450, delay = 0.0, radius = 100, danger = 1, cc = false, collision = false},
    ["BelvethW"] = {charName = "BelVeth", displayName = "Above and Below", slot = _W, type = "linear", speed = 500, range = 715, delay = 0.5, radius = 200, danger = 3, cc = true, collision = false},
    ["BelvethE"] = {charName = "BelVeth", displayName = "Royal Maelstrom", slot = _E, type = "circular", speed = math.huge, range = 0.0, delay = 1.5, radius = 500, danger = 2, cc = false, collision = false},
    ["BelvethR"] = {charName = "BelVeth", displayName = "Endless Banquet", slot = _R, type = "circular", speed = math.huge, range = 275, delay = 1.0, radius = 500, danger = 4, cc = true, collision = false},
    ["BardQ"] = {charName = "Bard", displayName = "Cosmic Binding", missileName = "BardQMissile", slot = _Q, type = "linear", speed = 1500, range = 950, delay = 0.25, radius = 60, danger = 2, cc = true, collision = true},
    ["BardR"] = {charName = "Bard", displayName = "Tempered Fate", missileName = "BardRMissile", slot = _R, type = "circular", speed = 2100, range = 3400, delay = 0.5, radius = 350, danger = 2, cc = true, collision = false},
    ["RocketGrab"] = {charName = "Blitzcrank", displayName = "Rocket Grab", missileName = "RocketGrabMissile", slot = _Q, type = "linear", speed = 1800, range = 1150, delay = 0.25, radius = 70, danger = 3, cc = true, collision = true},
    ["StaticField"] = {charName = "Blitzcrank", displayName = "Static Field", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 600, danger = 4, cc = true, collision = false},
    ["BrandQ"] = {charName = "Brand", displayName = "Sear", missileName = "BrandQMissile", slot = _Q, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 60, danger = 1, cc = false, collision = true},
    ["BrandW"] = {charName = "Brand", displayName = "Pillar of Flame", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.85, radius = 250, danger = 2, cc = false, collision = false},
    ["BriarR"] = {charName = "Briar", displayName = "Certain Death", missileName = "BriarR", slot = _R, type = "linear", speed = 1400, range = 1400, delay = 0.25, radius = 120, danger = 4, cc = true, collision = false},
    ["BraumQ"] = {charName = "Braum", displayName = "Winter's Bite", missileName = "BraumQMissile", slot = _Q, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, danger = 3, cc = true, collision = true},
    ["BraumR"] = {charName = "Braum", displayName = "Glacial Fissure", missileName = "BraumRMissile", slot = _R, type = "linear", speed = 1400, range = 1250, delay = 0.5, radius = 115, danger = 4, cc = true, collision = false},
    ["CaitlynPiltoverPeacemaker"] = {charName = "Caitlyn", displayName = "Piltover Peacemaker", missileName = "CaitlynPiltoverPeacemaker", slot = _Q, type = "linear", speed = 2200, range = 1250, delay = 0.625, radius = 90, danger = 1, cc = false, collision = false},
    ["CaitlynYordleTrap"] = {charName = "Caitlyn", displayName = "Yordle Trap", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 0.35, radius = 75, danger = 1, cc = true, collision = false},
    ["CaitlynEntrapment"] = {charName = "Caitlyn", displayName = "Entrapment", missileName = "CaitlynEntrapment", slot = _E, type = "linear", speed = 1600, range = 750, delay = 0.15, radius = 70, danger = 2, cc = true, collision = true},
    ["CamilleE"] = {charName = "Camille", displayName = "Hookshot [First]", missileName = "CamilleEMissile", slot = _E, type = "linear", speed = 1900, range = 800, delay = 0, radius = 60, danger = 1, cc = false, collision = false},
    ["CamilleEDash2"] = {charName = "Camille", displayName = "Hookshot [Second]", slot = _E, type = "linear", speed = 1900, range = 400, delay = 0, radius = 60, danger = 2, cc = true, collision = false},
    ["CassiopeiaQ"] = {charName = "Cassiopeia", displayName = "Noxious Blast", slot = _Q, type = "circular", speed = math.huge, range = 850, delay = 0.75, radius = 150, danger = 2, cc = false, collision = false},
    ["CassiopeiaW"] = {charName = "Cassiopeia", displayName = "Miasma", slot = _W, type = "circular", speed = 2500, range = 800, delay = 0.75, radius = 160, danger = 2, cc = true, collision = false},
    ["CassiopeiaR"] = {charName = "Cassiopeia", displayName = "Petrifying Gaze", slot = _R, type = "conic", speed = math.huge, range = 825, delay = 0.5, radius = 0, angle = 80, danger = 5, cc = true, collision = false},
    ["Rupture"] = {charName = "Chogath", displayName = "Rupture", slot = _Q, type = "circular", speed = math.huge, range = 950, delay = 1.2, radius = 250, danger = 2, cc = true, collision = false},
    ["FeralScream"] = {charName = "Chogath", displayName = "Feral Scream", slot = _W, type = "conic", speed = math.huge, range = 650, delay = 0.5, radius = 0, angle = 56, danger = 2, cc = true, collision = false},
    ["PhosphorusBomb"] = {charName = "Corki", displayName = "Phosphorus Bomb", missileName = "PhosphorusBombMissile", slot = _Q, type = "circular", speed = 1000, range = 825, delay = 0.25, radius = 250, danger = 2, cc = false, collision = false},
    ["MissileBarrageMissile"] = {charName = "Corki", displayName = "Missile Barrage [Standard]", missileName = "MissileBarrageMissile", slot = _R, type = "linear", speed = 2000, range = 1300, delay = 0.175, radius = 40, danger = 1, cc = false, collision = true},
    ["MissileBarrageMissile2"] = {charName = "Corki", displayName = "Missile Barrage [Big]", missileName = "MissileBarrageMissile2", slot = _R, type = "linear", speed = 2000, range = 1500, delay = 0.175, radius = 40, danger = 1, cc = false, collision = true},
    ["DianaQ"] = {charName = "Diana", displayName = "Crescent Strike", slot = _Q, type = "circular", speed = 1900, range = 900, delay = 0.25, radius = 185, danger = 2, cc = false, collision = true},
    ["DravenDoubleShot"] = {charName = "Draven", displayName = "Double Shot", missileName = "DravenDoubleShotMissile", slot = _E, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 130, danger = 3, cc = true, collision = false},
    ["DravenRCast"] = {charName = "Draven", displayName = "Whirling Death", slot = _R, type = "linear", speed = 2000, range = 12500, delay = 0.25, radius = 160, danger = 4, cc = false, collision = false},
    ["DrMundoQ"] = {charName = "DrMundo", displayName = "Infected Bonesaw", missileName = "DrMundoQ", slot = _Q, type = "linear", speed = 2000, range = 990, delay = 0.25, radius = 120, danger = 2, cc = true, collision = true},
    ["EkkoQ"] = {charName = "Ekko", displayName = "Timewinder", missileName = "EkkoQMis", slot = _Q, type = "linear", speed = 1650, range = 1175, delay = 0.25, radius = 60, danger = 1, cc = true, collision = false},
    ["EkkoW"] = {charName = "Ekko", displayName = "Parallel Convergence", slot = _W, type = "circular", speed = math.huge, range = 1600, delay = 3.35, radius = 400, danger = 1, cc = true, collision = false},
    ["EliseHumanE"] = {charName = "Elise", displayName = "Cocoon", missileName = "EliseHumanE", slot = _E, type = "linear", speed = 1600, range = 1075, delay = 0.25, radius = 55, danger = 1, cc = true, collision = true},
    ["EvelynnQ"] = {charName = "Evelynn", displayName = "Hate Spike", missileName = "EvelynnQ", slot = _Q, type = "linear", speed = 2400, range = 800, delay = 0.25, radius = 60, danger = 2, cc = false, collision = true},
    ["EvelynnR"] = {charName = "Evelynn", displayName = "Last Caress", slot = _R, type = "conic", speed = math.huge, range = 450, delay = 0.35, radius = 180, angle = 180, danger = 5, cc = false, collision = false},
    ["EzrealQ"] = {charName = "Ezreal", displayName = "Mystic Shot", missileName = "EzrealQ", slot = _Q, type = "linear", speed = 2000, range = 1150, delay = 0.25, radius = 60, danger = 1, cc = false, collision = true},
    ["EzrealW"] = {charName = "Ezreal", displayName = "Essence Flux", missileName = "EzrealW", slot = _W, type = "linear", speed = 2000, range = 1150, delay = 0.25, radius = 60, danger = 1, cc = false, collision = false},
    ["EzrealR"] = {charName = "Ezreal", displayName = "Trueshot Barrage", missileName = "EzrealR", slot = _R, type = "linear", speed = 2000, range = 12500, delay = 1, radius = 160, danger = 4, cc = false, collision = false},
    ["FioraW"] = {charName = "Fiora", displayName = "Riposte", slot = _W, type = "linear", speed = 3200, range = 750, delay = 0.75, radius = 70, danger = 2, cc = true, collision = false},
    ["FizzR"] = {charName = "Fizz", displayName = "Chum the Waters", missileName = "FizzRMissile", slot = _R, type = "linear", speed = 1300, range = 1300, delay = 0.25, radius = 150, danger = 5, cc = true, collision = false},
    ["GalioQ"] = {charName = "Galio", displayName = "Winds of War", missileName = "GalioQMissile", slot = _Q, type = "circular", speed = 1150, range = 825, delay = 0.25, radius = 235, danger = 2, cc = false, collision = false},
    ["GalioE"] = {charName = "Galio", displayName = "Justice Punch", slot = _E, type = "linear", speed = 2300, range = 650, delay = 0.4, radius = 160, danger = 3, cc = true, collision = false},
    ["GnarQMissile"] = {charName = "Gnar", displayName = "Boomerang Throw", missileName = "GnarQMissile", slot = _Q, type = "linear", speed = 2500, range = 1125, delay = 0.25, radius = 55, danger = 2, cc = true, collision = false},
    ["GnarBigQMissile"] = {charName = "Gnar", displayName = "Boulder Toss", missileName = "GnarBigQMissile", slot = _Q, type = "linear", speed = 2100, range = 1125, delay = 0.5, radius = 90, danger = 2, cc = true, collision = true},
    ["GnarBigW"] = {charName = "Gnar", displayName = "Wallop", slot = _W, type = "linear", speed = math.huge, range = 575, delay = 0.6, radius = 100, danger = 3, cc = true, collision = false},
    ["GnarR"] = {charName = "Gnar", displayName = "GNAR!", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 475, danger = 5, cc = true, collision = false},
    ["GragasQ"] = {charName = "Gragas", displayName = "Barrel Roll", missileName = "GragasQMissile", slot = _Q, type = "circular", speed = 1000, range = 850, delay = 0.25, radius = 275, danger = 2, cc = true, collision = false},
    ["GragasR"] = {charName = "Gragas", displayName = "Explosive Cask", missileName = "GragasRBoom", slot = _R, type = "circular", speed = 1800, range = 1000, delay = 0.25, radius = 400, danger = 5, cc = true, collision = false},
    ["GravesQLineSpell"] = {charName = "Graves", displayName = "End of the Line", slot = _Q, type = "polygon", speed = math.huge, range = 800, delay = 1.4, radius = 20, danger = 1, cc = false, collision = false},
    ["GravesSmokeGrenade"] = {charName = "Graves", displayName = "Smoke Grenade", missileName = "GravesSmokeGrenadeBoom", slot = _W, type = "circular", speed = 1500, range = 950, delay = 0.15, radius = 250, danger = 2, cc = true, collision = false},
    ["GravesChargeShot"] = {charName = "Graves", displayName = "Charge Shot", missileName = "GravesChargeShotShot", slot = _R, type = "polygon", speed = 2100, range = 1000, delay = 0.25, radius = 100, danger = 5, cc = false, collision = false},
    ["GwenQ"] = {charName = "Gwen", displayName = "Snip Snip!", slot = _Q, type = "circular", speed = 1500, range = 450, delay = 0, radius = 275, danger = 2, cc = false, collision = false},
    ["GwenR"] = {charName = "Gwen", displayName = "Needlework", missileName = "GwenRMissile", slot = _R, type = "linear", speed = 1800, range = 1230, delay = 0.25, radius = 250, danger = 3, cc = true, collision = false},
    ["HecarimUlt"] = {charName = "Hecarim", displayName = "Onslaught of Shadows", missileName = "HecarimUltMissile", slot = _R, type = "linear", speed = 1100, range = 1650, delay = 0.2, radius = 280, danger = 4, cc = true, collision = false},
    ["HeimerdingerW"] = {charName = "Heimerdinger", displayName = "Hextech Micro-Rockets", slot = _W, type = "linear", speed = 2050, range = 1325, delay = 0.25, radius = 100, danger = 2, cc = false, collision = false},
    ["HeimerdingerE"] = {charName = "Heimerdinger", displayName = "CH-2 Electron Storm Grenade", missileName = "HeimerdingerESpell", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, danger = 2, cc = true, collision = false},
    ["HeimerdingerEUlt"] = {charName = "Heimerdinger", displayName = "CH-2 Electron Storm Grenade [Ult]", missileName = "HeimerdingerESpell_ult", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, danger = 3, cc = true, collision = false},
    ["HweiQQ"] = {charName = "Hwei", displayName = "Devastating Fire", missileName = "HweiQQ", slot = _Q, type = "linear", speed = 1900, range = 1100, delay = 0.25, radius = 85, danger = 4, cc = false, collision = true},
    ["HweiQW"] = {charName = "Hwei", displayName = "Severing Bolt", missileName = "HweiQW", slot = _Q, type = "circular", speed = math.huge, range = 1900, delay = 1.075, radius = 205, danger = 4, cc = false, collision = false},
    ["HweiQE"] = {charName = "Hwei", displayName = "Molten Fissure", missileName = "HweiQE", slot = _Q, type = "linear", speed = 1100, range = 1200, delay = 0.7, radius = 200, danger = 3, cc = true, collision = false},
    ["HweiEQ"] = {charName = "Hwei", displayName = "Grim Visage", missileName = "HweiEQ", slot = _E, type = "linear", speed = 1200, range = 1025, delay = 0.25, radius = 85, danger = 3, cc = true, collision = false},
    ["HweiEW"] = {charName = "Hwei", displayName = "Gaze of the Abyss", missileName = "HweiEW", slot = _E, type = "circular", speed = 1600, range = 925, delay = 0.25, radius = 350, danger = 3, cc = true, collision = false},
    ["HweiEE"] = {charName = "Hwei", displayName = "Crushing Maw", missileName = "HweiEE", slot = _E, type = "circular", speed = math.huge, range = 800, delay = 0.627, radius = 145, danger = 3, cc = true, collision = false},
    ["HweiR"] = {charName = "Hwei", displayName = "Spiraling Despair", missileName = "HweiR", slot = _R, type = "linear", speed = 1200, range = 1300, delay = 0.5, radius = 200, danger = 4, cc = true, collision = false},
    ["IllaoiQ"] = {charName = "Illaoi", displayName = "Tentacle Smash", slot = _Q, type = "linear", speed = math.huge, range = 850, delay = 0.75, radius = 100, danger = 2, cc = false, collision = true},
    ["IllaoiE"] = {charName = "Illaoi", displayName = "Test of Spirit", missileName = "IllaoiEMis", slot = _E, type = "linear", speed = 1900, range = 900, delay = 0.25, radius = 50, danger = 1, cc = false, collision = true},
    ["IreliaW2"] = {charName = "Irelia", displayName = "Defiant Dance", slot = _W, type = "linear", speed = math.huge, range = 825, delay = 0.25, radius = 120, danger = 3, cc = true, collision = false},
    ["IreliaR"] = {charName = "Irelia", displayName = "Vanguard's Edge", missileName = "IreliaR", slot = _R, type = "linear", speed = 2000, range = 950, delay = 0.4, radius = 160, danger = 4, cc = true, collision = false},
    ["IvernQ"] = {charName = "Ivern", displayName = "Rootcaller", missileName = "IvernQ", slot = _Q, type = "linear", speed = 1300, range = 1075, delay = 0.25, radius = 80, danger = 1, cc = true, collision = true},
    ["HowlingGaleSpell"] = {charName = "Janna", displayName = "Howling Gale", missileName = "HowlingGaleSpell", slot = _Q, type = "linear", speed = 667, range = 1750, radius = 100, danger = 2, cc = true, collision = false},
    ["JarvanIVDragonStrike"] = {charName = "JarvanIV", displayName = "Dragon Strike", slot = _Q, type = "linear", speed = math.huge, range = 770, delay = 0.4, radius = 70, danger = 2, cc = true, collision = false},
    ["JarvanIVDemacianStandard"] = {charName = "JarvanIV", displayName = "Demacian Standard", slot = _E, type = "circular", speed = 3440, range = 860, delay = 0, radius = 175, danger = 2, cc = false, collision = false},
    ["JayceShockBlast"] = {charName = "Jayce", displayName = "Shock Blast [Standard]", missileName = "JayceShockBlastMis", slot = _Q, type = "linear", speed = 1450, range = 1050, delay = 0.214, radius = 70, danger = 1, cc = false, collision = true},
    ["JayceShockBlastWallMis"] = {charName = "Jayce", displayName = "Shock Blast [Accelerated]", missileName = "JayceShockBlastWallMis", slot = _Q, type = "linear", speed = 2350, range = 1600, delay = 0.152, radius = 115, danger = 3, cc = false, collision = true},
    ["JhinW"] = {charName = "Jhin", displayName = "Deadly Flourish", slot = _W, type = "linear", speed = 5000, range = 2550, delay = 0.75, radius = 40, danger = 1, cc = true, collision = false},
    ["JhinE"] = {charName = "Jhin", displayName = "Captive Audience", missileName = "JhinETrap", slot = _E, type = "circular", speed = 1600, range = 750, delay = 0.25, radius = 130, danger = 1, cc = true, collision = false},
    ["JhinRShot"] = {charName = "Jhin", displayName = "Curtain Call", missileName = "JhinRShotMis", slot = _R, type = "linear", speed = 5000, range = 3500, delay = 0.25, radius = 80, danger = 2, cc = true, collision = false},
    ["JinxWMissile"] = {charName = "Jinx", displayName = "Zap!", missileName = "JinxWMissile", slot = _W, type = "linear", speed = 3300, range = 1450, delay = 0.6, radius = 60, danger = 1, cc = true, collision = true},
    ["JinxEHit"] = {charName = "Jinx", displayName = "Flame Chompers!", missileName = "JinxEHit", slot = _E, type = "polygon", speed = 1100, range = 900, delay = 1.5, radius = 120, danger = 1, cc = true, collision = false},
    ["JinxR"] = {charName = "Jinx", displayName = "Super Mega Death Rocket!", missileName = "JinxR", slot = _R, type = "linear", speed = 1700, range = 12500, delay = 0.6, radius = 140, danger = 4, cc = false, collision = false},
    ["KaisaW"] = {charName = "Kaisa", displayName = "Void Seeker", missileName = "KaisaW", slot = _W, type = "linear", speed = 1750, range = 3000, delay = 0.4, radius = 100, danger = 1, cc = false, collision = true},
    ["KalistaMysticShot"] = {charName = "Kalista", displayName = "Pierce", missileName = "KalistaMysticShotMisTrue", slot = _Q, type = "linear", speed = 2400, range = 1150, delay = 0.25, radius = 40, danger = 1, cc = false, collision = true},
    ["KarmaQ"] = {charName = "Karma", displayName = "Inner Flame", missileName = "KarmaQMissile", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 60, danger = 2, cc = true, collision = true},
    ["KarmaQMantra"] = {charName = "Karma", displayName = "Inner Flame [Mantra]", missileName = "KarmaQMissileMantra", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 80, danger = 2, cc = true, collision = true},
    ["KarthusLayWasteA1"] = {charName = "Karthus", displayName = "Lay Waste [1]", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.9, radius = 175, danger = 1, cc = false, collision = false},
    ["KarthusLayWasteA2"] = {charName = "Karthus", displayName = "Lay Waste [2]", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.9, radius = 175, danger = 1, cc = false, collision = false},
    ["KarthusLayWasteA3"] = {charName = "Karthus", displayName = "Lay Waste [3]", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 0.9, radius = 175, danger = 1, cc = false, collision = false},
    ["ForcePulse"] = {charName = "Kassadin", displayName = "Force Pulse", slot = _E, type = "conic", speed = math.huge, range = 600, delay = 0.3, radius = 0, angle = 80, danger = 3, cc = true, collision = false},
    ["RiftWalk"] = {charName = "Kassadin", displayName = "Rift Walk", slot = _R, type = "circular", speed = math.huge, range = 500, delay = 0.25, radius = 250, danger = 3, cc = false, collision = false},
    ["KayleQ"] = {charName = "Kayle", displayName = "Radiant Blast", missileName = "KayleQMis", slot = _Q, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 60, danger = 1, cc = true, collision = false},
    ["KaynW"] = {charName = "Kayn", displayName = "Blade's Reach", slot = _W, type = "linear", speed = math.huge, range = 700, delay = 0.55, radius = 90, danger = 2, cc = true, collision = false},
    ["KennenShurikenHurlMissile1"] = {charName = "Kennen", displayName = "Shuriken Hurl", missileName = "KennenShurikenHurlMissile1", slot = _Q, type = "linear", speed = 1700, range = 1050, delay = 0.175, radius = 50, danger = 2, cc = false, collision = true},
    ["KhazixW"] = {charName = "Khazix", displayName = "Void Spike [Standard]", missileName = "KhazixWMissile", slot = _W, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, danger = 1, cc = false, collision = true},
    ["KhazixWLong"] = {charName = "Khazix", displayName = "Void Spike [Threeway]", slot = _W, type = "threeway", speed = 1700, range = 1000, delay = 0.25, radius = 70, angle = 23, danger = 2, cc = true, collision = true},
    ["KledQ"] = {charName = "Kled", displayName = "Beartrap on a Rope", missileName = "KledQMissile", slot = _Q, type = "linear", speed = 1600, range = 800, delay = 0.25, radius = 45, danger = 1, cc = true, collision = false},
    ["KledRiderQ"] = {charName = "Kled", displayName = "Pocket Pistol", missileName = "KledRiderQMissile", slot = _Q, type = "conic", speed = 3000, range = 700, delay = 0.25, radius = 0, angle = 25, danger = 3, cc = false, collision = false},
    ["KogMawQ"] = {charName = "KogMaw", displayName = "Caustic Spittle", missileName = "KogMawQ", slot = _Q, type = "linear", speed = 1650, range = 1175, delay = 0.25, radius = 70, danger = 1, cc = false, collision = true},
    ["KogMawVoidOozeMissile"] = {charName = "KogMaw", displayName = "Void Ooze", missileName = "KogMawVoidOozeMissile", slot = _E, type = "linear", speed = 1400, range = 1360, delay = 0.25, radius = 120, danger = 2, cc = true, collision = false},
    ["KogMawLivingArtillery"] = {charName = "KogMaw", displayName = "Living Artillery", slot = _R, type = "circular", speed = math.huge, range = 1300, delay = 1.1, radius = 200, danger = 1, cc = false, collision = false},
    ["KSanteQ"] = {charName = "KSante", displayName = "KSante Q", missileName = "KSanteQ", slot = _Q, type = "linear", speed = 1800, range = 465, delay = 0.25, radius = 75, danger = 1, cc = false, collision = false},
    ["KSanteQ3"] = {charName = "KSante", displayName = "KSante Q3", missileName = "KSanteQ3", slot = _Q, type = "linear", speed = 1100, range = 750, delay = 0.34, radius = 70, danger = 3, cc = false, collision = false},
    ["LeblancE"] = {charName = "Leblanc", displayName = "Ethereal Chains [Standard]", missileName = "LeblancEMissile", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, danger = 1, cc = true, collision = true},
    ["LeblancRE"] = {charName = "Leblanc", displayName = "Ethereal Chains [Ultimate]", missileName = "LeblancREMissile", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, danger = 1, cc = true, collision = true},
    ["BlindMonkQOne"] = {charName = "LeeSin", displayName = "Sonic Wave", missileName = "BlindMonkQOne", slot = _Q, type = "linear", speed = 1800, range = 1100, delay = 0.25, radius = 60, danger = 1, cc = false, collision = true},
    ["LeonaZenithBlade"] = {charName = "Leona", displayName = "Zenith Blade", missileName = "LeonaZenithBladeMissile", slot = _E, type = "linear", speed = 2000, range = 875, delay = 0.25, radius = 70, danger = 2, cc = true, collision = false},
    ["LeonaSolarFlare"] = {charName = "Leona", displayName = "Solar Flare", slot = _R, type = "circular", speed = math.huge, range = 1200, delay = 0.85, radius = 300, danger = 5, cc = true, collision = false},
    ["LilliaE"] = {charName = "Lillia", displayName = "Swirlseed", missileName = "LilliaE", slot = _E, type = "linear", speed = 1500, range = 750, delay = 0.4, radius = 150, danger = 2, cc = true, collision = false},
    ["LissandraQMissile"] = {charName = "Lissandra", displayName = "Ice Shard", missileName = "LissandraQMissile", slot = _Q, type = "linear", speed = 2200, range = 750, delay = 0.25, radius = 75, danger = 2, cc = true, collision = false},
    ["LissandraEMissile"] = {charName = "Lissandra", displayName = "Glacial Path", missileName = "LissandraEMissile", slot = _E, type = "linear", speed = 850, range = 1025, delay = 0.25, radius = 125, danger = 2, cc = false, collision = false},
    ["LucianQ"] = {charName = "Lucian", displayName = "Piercing Light", slot = _Q, type = "linear", speed = math.huge, range = 900, delay = 0.35, radius = 65, danger = 2, cc = false, collision = false},
    ["LucianW"] = {charName = "Lucian", displayName = "Ardent Blaze", missileName = "LucianW", slot = _W, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 80, danger = 2, cc = false, collision = true},
    ["LuluQ"] = {charName = "Lulu", displayName = "Glitterlance", missileName = "LuluQMissile", slot = _Q, type = "linear", speed = 1450, range = 925, delay = 0.25, radius = 60, danger = 1, cc = true, collision = false},
    ["LuxLightBinding"] = {charName = "Lux", displayName = "Light Binding", missileName = "LuxLightBindingDummy", slot = _Q, type = "linear", speed = 1200, range = 1175, delay = 0.25, radius = 70, danger = 1, cc = true, collision = false},
    ["LuxLightStrikeKugel"] = {charName = "Lux", displayName = "Light Strike Kugel", missileName = "LuxLightStrikeKugel", slot = _E, type = "circular", speed = 1200, range = 1100, delay = 0.25, radius = 300, danger = 3, cc = true, collision = true},
    ["LuxMaliceCannon"] = {charName = "Lux", displayName = "Malice Cannon", missileName = "LuxRVfxMis", slot = _R, type = "linear", speed = math.huge, range = 3340, delay = 1, radius = 120, danger = 4, cc = false, collision = false},
    ["Landslide"] = {charName = "Malphite", displayName = "Ground Slam", slot = _E, type = "circular", speed = math.huge, range = 0, delay = 0.242, radius = 400, danger = 2, cc = true, collision = false},
    ["MalzaharQ"] = {charName = "Malzahar", displayName = "Call of the Void", slot = _Q, type = "rectangular", speed = 1600, range = 900, delay = 0.5, radius = 100, danger = 1, cc = true, collision = false},
    ["MaokaiQ"] = {charName = "Maokai", displayName = "Bramble Smash", missileName = "MaokaiQMissile", slot = _Q, type = "linear", speed = 1600, range = 600, delay = 0.375, radius = 110, danger = 2, cc = true, collision = false},
    ["MissFortuneBulletTime"] = {charName = "MissFortune", displayName = "Bullet Time", slot = _R, type = "conic", speed = 2000, range = 1400, delay = 0.25, radius = 100, angle = 34, danger = 4, cc = false, collision = false},
    ["MelQ"] = {charName = "Mel", displayName = "Radiant Volley", missileName = "MelQ", slot = _Q, type = "linear", speed = 2000, range = 950, delay = 0.25, radius = 80, danger = 2, cc = false, collision = true},
    ["MelE"] = {charName = "Mel", displayName = "Solar Snare", missileName = "MelE", slot = _E, type = "linear", speed = 1200, range = 1050, delay = 0.25, radius = 100, danger = 3, cc = true, collision = true},
    ["MilioQ"] = {charName = "Milio", displayName = "Fire Kick", missileName = "MilioQMissile", slot = _Q, type = "linear", speed = 1200, range = 1000, delay = 0, radius = 60, danger = 1, cc = true, collision = false},
    ["MordekaiserQ"] = {charName = "Mordekaiser", displayName = "Obliterate", slot = _Q, type = "polygon", speed = math.huge, range = 675, delay = 0.4, radius = 200, danger = 2, cc = false, collision = false},
    ["MordekaiserE"] = {charName = "Mordekaiser", displayName = "Death's Grasp", slot = _E, type = "polygon", speed = math.huge, range = 900, delay = 0.9, radius = 140, danger = 3, cc = true, collision = false},
    ["MorganaQ"] = {charName = "Morgana", displayName = "Dark Binding", missileName = "MorganaQ", slot = _Q, type = "linear", speed = 1200, range = 1250, delay = 0.25, radius = 70, danger = 1, cc = true, collision = true},
    ["NaafiriQ"] = {charName = "Naafiri", displayName = "Naafiri", slot = _Q, type = "linear", speed = 1200, range = 900, delay = 0.25, radius = 50, danger = 1, cc = false, collision = false},
    ["NaafiriQRecast"] = {charName = "Naafiri", displayName = "Naafiri Recast", slot = _Q, type = "linear", speed = 1200, range = 900, delay = 0.25, radius = 50, danger = 2, cc = false, collision = false},
    ["NamiQ"] = {charName = "Nami", displayName = "Aqua Prison", missileName = "NamiQMissile", slot = _Q, type = "circular", speed = math.huge, range = 875, delay = 1, radius = 180, danger = 1, cc = true, collision = false},
    ["NamiRMissile"] = {charName = "Nami", displayName = "Tidal Wave", missileName = "NamiRMissile", slot = _R, type = "linear", speed = 850, range = 2750, delay = 0.5, radius = 250, danger = 3, cc = true, collision = false},
    ["NautilusAnchorDragMissile"] = {charName = "Nautilus", displayName = "Dredge Line", missileName = "NautilusAnchorDragMissile", slot = _Q, type = "linear", speed = 2000, range = 925, delay = 0.25, radius = 90, danger = 3, cc = true, collision = true},
    ["NeekoQ"] = {charName = "Neeko", displayName = "Blooming Burst", missileName = "NeekoQ", slot = _Q, type = "circular", speed = 1500, range = 800, delay = 0.25, radius = 200, danger = 2, cc = true, collision = false},
    ["NeekoE"] = {charName = "Neeko", displayName = "Tangle-Barbs", missileName = "NeekoE", slot = _E, type = "linear", speed = 1300, range = 1000, delay = 0.25, radius = 70, danger = 1, cc = true, collision = false},
    ["JavelinToss"] = {charName = "Nidalee", displayName = "Javelin Toss", missileName = "JavelinToss", slot = _Q, type = "linear", speed = 1300, range = 1500, delay = 0.25, radius = 40, danger = 1, cc = false, collision = true},
    ["Bushwhack"] = {charName = "Nidalee", displayName = "Bushwhack", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 1.25, radius = 85, danger = 1, cc = false, collision = false},
    ["Swipe"] = {charName = "Nidalee", displayName = "Swipe", slot = _E, type = "conic", speed = math.huge, range = 350, delay = 0.25, radius = 0, angle = 180, danger = 2, cc = false, collision = false},
    ["NilahQ"] = {charName = "Nilah", displayName = "Formless Blade", slot = _Q, type = "linear", speed = 500, range = 600, delay = 0.25, radius = 150, danger = 2, cc = false, collision = false},
    ["NilahE"] = {charName = "Nilah", displayName = "Slipstream", slot = _E, type = "linear", speed = 2200, range = 550, delay = 0.00, radius = 150, danger = 2, cc = false, collision = false},
    ["NilahR"] = {charName = "Nilah", displayName = "Apotheosis", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 1.0, radius = 450, danger = 5, cc = true, collision = false},
    ["NocturneDuskbringer"] = {charName = "Nocturne", displayName = "Duskbringer", missileName = "NocturneDuskbringer", slot = _Q, type = "linear", speed = 1600, range = 1200, delay = 0.25, radius = 60, danger = 2, cc = false, collision = false},
    ["NunuR"] = {charName = "Nunu", displayName = "Absolute Zero", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 3, radius = 650, danger = 5, cc = true, collision = false},
    ["OlafAxeThrowCast"] = {charName = "Olaf", displayName = "Undertow", missileName = "OlafAxeThrow", slot = _Q, type = "linear", speed = 1600, range = 1000, delay = 0.25, radius = 90, danger = 2, cc = true, collision = false},
    ["OrianaIzuna"] = {charName = "Orianna", displayName = "Command: Attack", missileName = "OrianaIzuna", slot = _Q, type = "polygon", speed = 1400, range = 825, radius = 80, danger = 2, cc = false, collision = false},
    ["OrnnQ"] = {charName = "Ornn", displayName = "Volcanic Rupture", slot = _Q, type = "linear", speed = 1800, range = 800, delay = 0.3, radius = 65, danger = 1, cc = true, collision = false},
    ["OrnnE"] = {charName = "Ornn", displayName = "Searing Charge", slot = _E, type = "linear", speed = 1600, range = 800, delay = 0.35, radius = 150, danger = 3, cc = true, collision = false},
    ["OrnnRCharge"] = {charName = "Ornn", displayName = "Call of the Forge God", slot = _R, type = "linear", speed = 1650, range = 2500, delay = 0.5, radius = 200, danger = 3, cc = true, collision = false},
    ["PantheonQTap"] = {charName = "Pantheon", displayName = "Comet Spear [Melee]", slot = _Q, type = "linear", speed = math.huge, range = 575, delay = 0.25, radius = 80, danger = 2, cc = false, collision = false},
    ["PantheonQMissile"] = {charName = "Pantheon", displayName = "Comet Spear [Range]", missileName = "PantheonQMissile", slot = _Q, type = "linear", speed = 2700, range = 1200, delay = 0.25, radius = 60, danger = 2, cc = false, collision = false},
    ["PantheonR"] = {charName = "Pantheon", displayName = "Grand Starfall", slot = _R, type = "linear", speed = 2250, range = 1350, delay = 4, radius = 250, danger = 3, cc = false, collision = false},
    ["PoppyQSpell"] = {charName = "Poppy", displayName = "Hammer Shock", slot = _Q, type = "linear", speed = math.huge, range = 430, delay = 0.332, radius = 100, danger = 2, cc = true, collision = false},
    ["PoppyRSpell"] = {charName = "Poppy", displayName = "Keeper's Verdict", missileName = "PoppyRMissile", slot = _R, type = "linear", speed = 2000, range = 1200, delay = 0.33, radius = 100, danger = 3, cc = true, collision = false},
    ["PykeQMelee"] = {charName = "Pyke", displayName = "Bone Skewer [Melee]", slot = _Q, type = "linear", speed = math.huge, range = 400, delay = 0.25, radius = 70, danger = 2, cc = true, collision = false},
    ["PykeQRange"] = {charName = "Pyke", displayName = "Bone Skewer [Range]", missileName = "PykeQRange", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.2, radius = 70, danger = 2, cc = true, collision = true},
    ["PykeE"] = {charName = "Pyke", displayName = "Phantom Undertow", slot = _E, type = "linear", speed = 3000, range = 12500, delay = 0, radius = 110, danger = 2, cc = true, collision = false},
    ["PykeR"] = {charName = "Pyke", displayName = "Death from Below", slot = _R, type = "circular", speed = math.huge, range = 750, delay = 0.5, radius = 100, danger = 5, cc = false, collision = false},
    ["QiyanaQ"] = {charName = "Qiyana", displayName = "Edge of Ixtal", slot = _Q, type = "linear", speed = math.huge, range = 500, delay = 0.25, radius = 60, danger = 2, cc = false, collision = false},
    ["QiyanaQ_Grass"] = {charName = "Qiyana", displayName = "Edge of Ixtal [Grass]", slot = _Q, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 70, danger = 2, cc = false, collision = false},
    ["QiyanaQ_Rock"] = {charName = "Qiyana", displayName = "Edge of Ixtal [Rock]", slot = _Q, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 70, danger = 2, cc = false, collision = false},
    ["QiyanaQ_Water"] = {charName = "Qiyana", displayName = "Edge of Ixtal [Water]", slot = _Q, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 70, danger = 2, cc = true, collision = false},
    ["QiyanaR"] = {charName = "Qiyana", displayName = "Supreme Display of Talent", slot = _R, type = "linear", speed = 2000, range = 950, delay = 0.25, radius = 190, danger = 4, cc = true, collision = false},
    ["QuinnQ"] = {charName = "Quinn", displayName = "Blinding Assault", missileName = "QuinnQ", slot = _Q, type = "linear", speed = 1550, range = 1025, delay = 0.25, radius = 60, danger = 1, cc = false, collision = true},
    ["RakanQ"] = {charName = "Rakan", displayName = "Gleaming Quill", missileName = "RakanQMis", slot = _Q, type = "linear", speed = 1850, range = 850, delay = 0.25, radius = 65, danger = 1, cc = false, collision = true},
    ["RakanW"] = {charName = "Rakan", displayName = "Grand Entrance", slot = _W, type = "circular", speed = math.huge, range = 650, delay = 0.7, radius = 265, danger = 3, cc = true, collision = false},
    ["RekSaiQBurrowed"] = {charName = "RekSai", displayName = "Prey Seeker", missileName = "RekSaiQBurrowedMis", slot = _Q, type = "linear", speed = 1950, range = 1625, delay = 0.125, radius = 65, danger = 2, cc = false, collision = true},
    ["RellQ"] = {charName = "Rell", displayName = "Shattering Strike", slot = _Q, type = "linear", speed = math.huge, range = 685, delay = 0.35, radius = 80, danger = 2, cc = false, collision = false},
    ["RellW"] = {charName = "Rell", displayName = "Crash Down", slot = _W, type = "linear", speed = math.huge, range = 500, delay = 0.625, radius = 200, danger = 3, cc = true, collision = false},
    ["RellE"] = {charName = "Rell", displayName = "Attract and Repel", slot = _E, type = "linear", speed = math.huge, range = 1500, delay = 0.35, radius = 250, danger = 3, cc = true, collision = false},
    ["RellR"] = {charName = "Rell", displayName = "Magnet Storm", slot = _R, type = "circular", speed = math.huge, range = 0, delay = 0.25, radius = 400, danger = 5, cc = true, collision = false},
    ["RenataQ"] = {charName = "Renata", displayName = "Handshake", missileName = "RenataQ", slot = _Q, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 70, danger = 2, cc = true, collision = true},
    ["RenataE"] = {charName = "Renata", displayName = "Loyalty Program", missileName = "RenataE", slot = _E, type = "linear", speed = 1450, range = 1000, delay = 0.25, radius = 110, danger = 2, cc = true, collision = false},
    ["RenataR"] = {charName = "Renata", displayName = "Hostile Takeover", missileName = "RenataR", slot = _R, type = "linear", speed = 1500, range = 2000, delay = 0.25, radius = 120, danger = 5, cc = true, collision = false},
    ["RengarE"] = {charName = "Rengar", displayName = "Bola Strike", missileName = "RengarEMis", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, danger = 1, cc = true, collision = true},
    ["RivenIzunaBlade"] = {charName = "Riven", displayName = "Wind Slash", slot = _R, type = "conic", speed = 1600, range = 900, delay = 0.25, radius = 0, angle = 75, danger = 5, cc = false, collision = false},
    ["RumbleGrenade"] = {charName = "Rumble", displayName = "Electro Harpoon", missileName = "RumbleGrenadeMissile", slot = _E, type = "linear", speed = 2000, range = 850, delay = 0.25, radius = 60, danger = 2, cc = true, collision = true},
    ["RyzeQ"] = {charName = "Ryze", displayName = "Overload", missileName = "RyzeQ", slot = _Q, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 55, danger = 1, cc = false, collision = true},
    ["SamiraQ"] = {charName = "Samira", displayName = "Flair", missileName = "SamiraQ", slot = _Q, type = "linear", speed = 2000, range = 1000, delay = 0.25, radius = 70, danger = 2, cc = false, collision = true},
    ["SejuaniR"] = {charName = "Sejuani", displayName = "Glacial Prison", missileName = "SejuaniRMissile", slot = _R, type = "linear", speed = 1600, range = 1300, delay = 0.25, radius = 120, danger = 5, cc = true, collision = false},
    ["SennaQCast"] = {charName = "Senna", displayName = "Piercing Darkness", slot = _Q, type = "linear", speed = math.huge, range = 1400, delay = 0.4, radius = 80, danger = 2, cc = false, collision = false},
    ["SennaW"] = {charName = "Senna", displayName = "Last Embrace", missileName = "SennaW", slot = _W, type = "linear", speed = 1150, range = 1300, delay = 0.25, radius = 60, danger = 1, cc = true, collision = true},
    ["SennaR"] = {charName = "Senna", displayName = "Dawning Shadow", missileName = "SennaRWarningMis", slot = _R, type = "linear", speed = 20000, range = 12500, delay = 1, radius = 180, danger = 4, cc = false, collision = false},
    ["SeraphineQCast"] = {charName = "Seraphine", displayName = "High Note", missileName = "SeraphineQInitialMissile", slot = _Q, type = "circular", speed = 1200, range = 900, delay = 0.25, radius = 350, danger = 2, cc = false, collision = false},
    ["SeraphineECast"] = {charName = "Seraphine", displayName = "Beat Drop", missileName = "SeraphineEMissile", slot = _E, type = "linear", speed = 1200, range = 1300, delay = 0.25, radius = 70, danger = 1, cc = true, collision = false},
    ["SeraphineR"] = {charName = "Seraphine", displayName = "Encore", missileName = "SeraphineR", slot = _R, type = "linear", speed = 1600, range = 1300, delay = 0.5, radius = 160, danger = 3, cc = true, collision = false},
    ["SettW"] = {charName = "Sett", displayName = "Haymaker", slot = _W, type = "polygon", speed = math.huge, range = 790, delay = 0.75, radius = 160, danger = 2, cc = false, collision = false},
    ["SettE"] = {charName = "Sett", displayName = "Facebreaker", slot = _E, type = "polygon", speed = math.huge, range = 490, delay = 0.25, radius = 175, danger = 3, cc = true, collision = false},
    ["ShenE"] = {charName = "Shen", displayName = "Shadow Dash", missileName = "ShenE", slot = _E, type = "linear", speed = 1200, range = 600, delay = 0, radius = 60, danger = 2, cc = true, collision = false},
    ["ShyvanaFireball"] = {charName = "Shyvana", displayName = "Flame Breath [Standard]", missileName = "ShyvanaFireballMissile", slot = _E, type = "linear", speed = 1575, range = 925, delay = 0.25, radius = 60, danger = 1, cc = false, collision = false},
    ["ShyvanaFireballDragon2"] = {charName = "Shyvana", displayName = "Flame Breath [Dragon]", missileName = "ShyvanaFireballDragonMissile", slot = _E, type = "linear", speed = 1575, range = 975, delay = 0.333, radius = 60, danger = 2, cc = false, collision = false},
    ["ShyvanaTransformLeap"] = {charName = "Shyvana", displayName = "Transform Leap", slot = _R, type = "linear", speed = 700, range = 850, delay = 0.25, radius = 150, danger = 4, cc = true, collision = false},
    ["SionQ"] = {charName = "Sion", displayName = "Decimating Smash", slot = _Q, type = "linear", speed = math.huge, range = 750, delay = 2, radius = 150, danger = 3, cc = true, collision = false},
    ["SionE"] = {charName = "Sion", displayName = "Roar of the Slayer", missileName = "SionEMissile", slot = _E, type = "linear", speed = 1800, range = 800, delay = 0.25, radius = 80, danger = 2, cc = true, collision = false},
    ["SivirQ"] = {charName = "Sivir", displayName = "Boomerang Blade", missileName = "SivirQMissile", slot = _Q, type = "linear", speed = 1350, range = 1250, delay = 0.25, radius = 90, danger = 2, cc = false, collision = false},
    ["SkarnerFractureMissile"] = {charName = "Skarner", displayName = "Fracture", missileName = "SkarnerFractureMissile", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, danger = 1, cc = true, collision = false},
    ["SmolderW"] = {charName = "Smolder", displayName = "Achooo!", missileName = "SmolderW", slot = _W, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 80, danger = 2, cc = true, collision = false},
    ["SmolderR"] = {charName = "Smolder", displayName = "MMOOOMMMM!", missileName = "SmolderR", slot = _R, type = "linear", speed = 1500, range = 2000, delay = 0.25, radius = 120, danger = 5, cc = true, collision = false},
    ["SonaR"] = {charName = "Sona", displayName = "Crescendo", missileName = "SonaRMissile", slot = _R, type = "linear", speed = 2400, range = 1000, delay = 0.25, radius = 140, danger = 5, cc = true, collision = false},
    ["SorakaQ"] = {charName = "Soraka", displayName = "Starcall", missileName = "SorakaQMissile", slot = _Q, type = "circular", speed = 1150, range = 810, delay = 0.25, radius = 235, danger = 2, cc = true, collision = false},
    ["SwainQ"] = {charName = "Swain", displayName = "Death's Hand", slot = _Q, type = "conic", speed = 5000, range = 725, delay = 0.25, radius = 0, angle = 60, danger = 2, cc = false, collision = false},
    ["SwainW"] = {charName = "Swain", displayName = "Vision of Empire", slot = _W, type = "circular", speed = math.huge, range = 3500, delay = 1.5, radius = 300, danger = 1, cc = true, collision = false},
    ["SwainE"] = {charName = "Swain", displayName = "Nevermove", slot = _E, type = "linear", speed = 1800, range = 850, delay = 0.25, radius = 85, danger = 2, cc = true, collision = false},
    ["SylasQ"] = {charName = "Sylas", displayName = "Chain Lash", slot = _Q, type = "polygon", speed = math.huge, range = 775, delay = 0.4, radius = 45, danger = 2, cc = true, collision = false},
    ["SylasE2"] = {charName = "Sylas", displayName = "Abduct", missileName = "SylasE2Mis", slot = _E, type = "linear", speed = 1600, range = 850, delay = 0.25, radius = 60, danger = 2, cc = true, collision = true},
    ["SyndraQSpell"] = {charName = "Syndra", displayName = "Dark Sphere", missileName = "SyndraQSpell", slot = _Q, type = "circular", speed = math.huge, range = 800, delay = 0.625, radius = 200, danger = 2, cc = false, collision = false},
    ["SyndraE"] = {charName = "Syndra", displayName = "Scatter the Weak [Standard]", slot = _E, type = "conic", speed = 1600, range = 700, delay = 0.25, radius = 0, angle = 40, danger = 3, cc = true, collision = false},
    ["SyndraESphereMissile"] = {charName = "Syndra", displayName = "Scatter the Weak [Sphere]", missileName = "SyndraESphereMissile", slot = _E, type = "linear", speed = 2000, range = 1250, delay = 0.25, radius = 100, danger = 3, cc = true, collision = false},
    ["TahmKenchQ"] = {charName = "TahmKench", displayName = "Tongue Lash", missileName = "TahmKenchQMissile", slot = _Q, type = "linear", speed = 2800, range = 900, delay = 0.25, radius = 70, danger = 2, cc = true, collision = true},
    ["TaliyahQMis"] = {charName = "Taliyah", displayName = "Threaded Volley", missileName = "TaliyahQMis", slot = _Q, type = "linear", speed = 3600, range = 1000, radius = 100, danger = 2, cc = false, collision = true},
    ["TaliyahWVC"] = {charName = "Taliyah", displayName = "Seismic Shove", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 0.85, radius = 150, danger = 1, cc = true, collision = false},
    ["TaliyahE"] = {charName = "Taliyah", displayName = "Unraveled Earth", slot = _E, type = "conic", speed = 2000, range = 800, delay = 0.45, radius = 0, angle = 80, danger = 2, cc = true, collision = false},
    ["TaliyahR"] = {charName = "Taliyah", displayName = "Weaver's Wall", missileName = "TaliyahRMis", slot = _R, type = "linear", speed = 1700, range = 3000, delay = 1, radius = 120, danger = 1, cc = true, collision = false},
    ["TalonW"] = {charName = "Talon", displayName = "Rake", missileName = "TalonWMissileOne", slot = _W, type = "conic", speed = 2500, range = 650, delay = 0.25, radius = 75, angle = 26, danger = 2, cc = true, collision = false},
    ["TaricE"] = {charName = "Taric", displayName = "Dazzle", missileName = "TaricE", slot = _E, type = "linear", speed = 1600, range = 950, delay = 0.25, radius = 80, danger = 2, cc = true, collision = false},
    ["ThreshQ"] = {charName = "Thresh", displayName = "Death Sentence", missileName = "ThreshQMissile", slot = _Q, type = "linear", speed = 1900, range = 1100, delay = 0.5, radius = 70, danger = 1, cc = true, collision = true},
    ["ThreshEFlay"] = {charName = "Thresh", displayName = "Flay", slot = _E, type = "polygon", speed = math.huge, range = 500, delay = 0.389, radius = 110, danger = 3, cc = true, collision = true},
    ["TristanaW"] = {charName = "Tristana", displayName = "Rocket Jump", slot = _W, type = "circular", speed = 1100, range = 900, delay = 0.25, radius = 300, danger = 2, cc = true, collision = false},
    ["TryndamereE"] = {charName = "Tryndamere", displayName = "Spinning Slash", slot = _E, type = "linear", speed = 1300, range = 660, delay = 0, radius = 225, danger = 2, cc = false, collision = false},
    ["WildCards"] = {charName = "TwistedFate", displayName = "Wild Cards", missileName = "SealFateMissile", slot = _Q, type = "threeway", speed = 1000, range = 1450, delay = 0.25, radius = 40, angle = 28, danger = 1, cc = false, collision = false},
    ["UrgotQ"] = {charName = "Urgot", displayName = "Corrosive Charge", missileName = "UrgotQMissile", slot = _Q, type = "circular", speed = math.huge, range = 800, delay = 0.6, radius = 180, danger = 2, cc = true, collision = false},
    ["UrgotE"] = {charName = "Urgot", displayName = "Disdain", slot = _E, type = "linear", speed = 1540, range = 475, delay = 0.45, radius = 100, danger = 2, cc = true, collision = false},
    ["UrgotR"] = {charName = "Urgot", displayName = "Fear Beyond Death", missileName = "UrgotR", slot = _R, type = "linear", speed = 3200, range = 1600, delay = 0.5, radius = 80, danger = 4, cc = true, collision = false},
    ["VarusQMissile"] = {charName = "Varus", displayName = "Piercing Arrow", missileName = "VarusQMissile", slot = _Q, type = "linear", speed = 1900, range = 1525, radius = 70, danger = 1, cc = false, collision = false},
    ["VarusE"] = {charName = "Varus", displayName = "Hail of Arrows", missileName = "VarusEMissile", slot = _E, type = "circular", speed = 1500, range = 925, delay = 0.242, radius = 260, danger = 3, cc = true, collision = false},
    ["VarusR"] = {charName = "Varus", displayName = "Chain of Corruption", missileName = "VarusRMissile", slot = _R, type = "linear", speed = 1500, range = 1200, delay = 0.25, radius = 120, danger = 4, cc = true, collision = false},
    ["VeigarBalefulStrike"] = {charName = "Veigar", displayName = "Baleful Strike", missileName = "VeigarBalefulStrikeMis", slot = _Q, type = "linear", speed = 2200, range = 900, delay = 0.25, radius = 70, danger = 2, cc = false, collision = false},
    ["VeigarDarkMatter"] = {charName = "Veigar", displayName = "Dark Matter", slot = _W, type = "circular", speed = math.huge, range = 900, delay = 1.25, radius = 200, danger = 1, cc = false, collision = false},
    ["VexQ"] = {charName = "Vex", displayName = "Vex Q Bolt", missileName = "VexQ", slot = _Q, type = "polygon", speed = 2200, range = 1200, delay = 0.15, radius = 80, danger = 3, cc = true, collision = false},
    ["VelkozQMissileSplit"] = {charName = "Velkoz", displayName = "Plasma Fission [Split]", missileName = "VelkozQMissileSplit", slot = _Q, type = "linear", speed = 2100, range = 1100, radius = 45, danger = 2, cc = true, collision = true},
    ["VelkozQ"] = {charName = "Velkoz", displayName = "Plasma Fission", missileName = "VelkozQMissile", slot = _Q, type = "linear", speed = 1300, range = 1050, delay = 0.25, radius = 50, danger = 1, cc = true, collision = true},
    ["VelkozW"] = {charName = "Velkoz", displayName = "Void Rift", missileName = "VelkozWMissile", slot = _W, type = "linear", speed = 1700, range = 1050, delay = 0.25, radius = 87.5, danger = 1, cc = false, collision = false},
    ["VelkozE"] = {charName = "Velkoz", displayName = "Tectonic Disruption", slot = _E, type = "circular", speed = math.huge, range = 800, delay = 0.8, radius = 185, danger = 2, cc = true, collision = false},
    ["ViQ"] = {charName = "Vi", displayName = "Vault Breaker", slot = _Q, type = "linear", speed = 1500, range = 725, delay = 0, radius = 90, danger = 2, cc = true, collision = false},
    ["ViegoW"] = {charName = "Viego", displayName = "Spectral Maw", missileName = "ViegoWMissile", slot = _W, type = "linear", speed = 1300, range = 760, delay = 0, radius = 90, danger = 3, cc = true, collision = true},
    ["ViktorGravitonField"] = {charName = "Viktor", displayName = "Graviton Field", slot = _W, type = "circular", speed = math.huge, range = 800, delay = 1.75, radius = 270, danger = 1, cc = true, collision = false},
    ["ViktorDeathRayMissile"] = {charName = "Viktor", displayName = "Death Ray", missileName = "ViktorDeathRayMissile", slot = _E, type = "linear", speed = 1050, range = 700, radius = 80, danger = 2, cc = false, collision = false},
    ["VolibearE"] = {charName = "Volibear", displayName = "Sky Splitter", missileName = "VolibearE", slot = _E, type = "linear", speed = 1600, range = 950, delay = 0.25, radius = 80, danger = 2, cc = true, collision = false},
    ["WarwickR"] = {charName = "Warwick", displayName = "Infinite Duress", slot = _R, type = "linear", speed = 1800, range = 3000, delay = 0.1, radius = 55, danger = 4, cc = true, collision = false},
    ["XayahQ"] = {charName = "Xayah", displayName = "Double Daggers", missileName = "XayahQ", slot = _Q, type = "linear", speed = 2075, range = 1100, delay = 0.5, radius = 45, danger = 1, cc = false, collision = false},
    ["XerathArcaneBarrage2"] = {charName = "Xerath", displayName = "Arcane Barrage", slot = _W, type = "circular", speed = math.huge, range = 1000, delay = 0.75, radius = 235, danger = 3, cc = true, collision = false},
    ["XerathMageSpear"] = {charName = "Xerath", displayName = "Mage Spear", missileName = "XerathMageSpearMissile", slot = _E, type = "linear", speed = 1400, range = 1050, delay = 0.2, radius = 60, danger = 1, cc = true, collision = true},
    ["XerathLocusPulse"] = {charName = "Xerath", displayName = "Rite of the Arcane", missileName = "XerathLocusPulse", slot = _R, type = "circular", speed = math.huge, range = 5000, delay = 0.7, radius = 200, danger = 3, cc = false, collision = false},
    ["XinZhaoW"] = {charName = "XinZhao", displayName = "Wind Becomes Lightning", slot = _W, type = "linear", speed = 5000, range = 900, delay = 0.5, radius = 40, danger = 1, cc = true, collision = false},
    ["YasuoQ1"] = {charName = "Yasuo", displayName = "Steel Tempest", slot = _Q, type = "linear", speed = 1500, range = 475, delay = 0.25, radius = 40, danger = 1, cc = false, collision = false},
    ["YasuoQ2"] = {charName = "Yasuo", displayName = "Steel Wind Rising", slot = _Q, type = "linear", speed = 1500, range = 475, delay = 0.25, radius = 40, danger = 1, cc = false, collision = false},
    ["YasuoQ3"] = {charName = "Yasuo", displayName = "Gathering Storm", missileName = "YasuoQ3Mis", slot = _Q, type = "linear", speed = 1200, range = 1100, delay = 0.03, radius = 90, danger = 2, cc = true, collision = false},
    ["YoneQ"] = {charName = "Yone", displayName = "Mortal Steel [Sword]", slot = _Q, type = "linear", speed = math.huge, range = 450, delay = 0.25, radius = 40, danger = 1, cc = false, collision = false},
    ["YoneQ3"] = {charName = "Yone", displayName = "Mortal Steel [Storm]", missileName = "YoneQ3Missile", slot = _Q, type = "linear", speed = 1500, range = 1050, delay = 0.25, radius = 80, danger = 2, cc = true, collision = false},
    ["YoneW"] = {charName = "Yone", displayName = "Spirit Cleave", slot = _W, type = "conic", speed = math.huge, range = 600, delay = 0.375, radius = 0, angle = 80, danger = 1, cc = false, collision = false},
    ["YoneR"] = {charName = "Yone", displayName = "Fate Sealed", slot = _R, type = "linear", speed = math.huge, range = 1000, delay = 0.75, radius = 112.5, danger = 5, cc = true, collision = false},
    ["YorickE"] = {charName = "Yorick", displayName = "Mourning Mist", missileName = "YorickE", slot = _E, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 80, danger = 2, cc = true, collision = false},
    ["ZacQ"] = {charName = "Zac", displayName = "Stretching Strikes", missileName = "ZacQMissile", slot = _Q, type = "linear", speed = 2800, range = 800, delay = 0.33, radius = 120, danger = 2, cc = true, collision = false},
    ["ZaahenW"] = {charName = "Zaahen", displayName = "Zaahen W", slot = _W, type = "linear", speed = 1600, range = 850, delay = 0.5, radius = 35, danger = 3, cc = true, collision = false},
    ["ZedQ"] = {charName = "Zed", displayName = "Razor Shuriken", missileName = "ZedQMissile", slot = _Q, type = "linear", speed = 1700, range = 900, delay = 0.25, radius = 50, danger = 1, cc = false, collision = false},
    ["ZeriQ"] = {charName = "Zeri", displayName = "Burst Fire", missileName = "ZeriQMissile", slot = _Q, type = "linear", speed = 1500, range = 840, delay = 0.25, radius = 80, danger = 2, cc = false, collision = true},
    ["ZiggsQ"] = {charName = "Ziggs", displayName = "Bouncing Bomb", missileName = "ZiggsQSpell", slot = _Q, type = "polygon", speed = 1750, range = 850, delay = 0.25, radius = 150, danger = 1, cc = false, collision = true},
    ["ZiggsW"] = {charName = "Ziggs", displayName = "Satchel Charge", missileName = "ZiggsW", slot = _W, type = "circular", speed = 1750, range = 1000, delay = 0.25, radius = 240, danger = 2, cc = true, collision = false},
    ["ZiggsE"] = {charName = "Ziggs", displayName = "Hexplosive Minefield", missileName = "ZiggsE", slot = _E, type = "circular", speed = 1800, range = 900, delay = 0.25, radius = 250, danger = 2, cc = true, collision = false},
    ["ZiggsR"] = {charName = "Ziggs", displayName = "Mega Inferno Bomb", missileName = "ZiggsRBoom", slot = _R, type = "circular", speed = 1550, range = 5000, delay = 0.375, radius = 480, danger = 4, cc = false, collision = false},
    ["ZileanQ"] = {charName = "Zilean", displayName = "Time Bomb", missileName = "ZileanQMissile", slot = _Q, type = "circular", speed = math.huge, range = 900, delay = 0.8, radius = 150, danger = 2, cc = true, collision = false},
    ["ZoeQMissile"] = {charName = "Zoe", displayName = "Paddle Star [First]", missileName = "ZoeQMissile", slot = _Q, type = "linear", speed = 1200, range = 800, delay = 0.25, radius = 50, danger = 1, cc = false, collision = true},
    ["ZoeQMis2"] = {charName = "Zoe", displayName = "Paddle Star [Second]", missileName = "ZoeQMis2", slot = _Q, type = "linear", speed = 2500, range = 1600, delay = 0, radius = 70, danger = 2, cc = false, collision = true},
    ["ZoeE"] = {charName = "Zoe", displayName = "Sleepy Trouble Bubble", missileName = "ZoeEMis", slot = _E, type = "linear", speed = 1700, range = 800, delay = 0.3, radius = 50, danger = 2, cc = true, collision = true},
    ["ZyraQ"] = {charName = "Zyra", displayName = "Deadly Spines", slot = _Q, type = "rectangular", speed = math.huge, range = 800, delay = 0.825, radius = 200, danger = 1, cc = false, collision = false},
    ["ZyraE"] = {charName = "Zyra", displayName = "Grasping Roots", missileName = "ZyraE", slot = _E, type = "linear", speed = 1150, range = 1100, delay = 0.25, radius = 70, danger = 1, cc = true, collision = false},
    ["ZyraR"] = {charName = "Zyra", displayName = "Stranglethorns", slot = _R, type = "circular", speed = math.huge, range = 700, delay = 2, radius = 500, danger = 4, cc = true, collision = false},
}

local function GetRiposteDisplayKey(spellName, data)
    return (data.charName or "?") .. "|" .. tostring(data.slot or "?") .. "|" .. string_lower(data.displayName or spellName)
end

local function RegisterRiposteSpell(spellName, data, aliases, forceLookup)
    if type(spellName) ~= "string" or spellName == "" or type(data) ~= "table" then
        return
    end

    local displayKey = GetRiposteDisplayKey(spellName, data)
    local menuSpellName = RipostePrimaryByDisplayKey[displayKey]

    if not menuSpellName then
        menuSpellName = spellName
        RipostePrimaryByDisplayKey[displayKey] = menuSpellName
        RiposteMenuSpells[menuSpellName] = data
    else
        local menuData = RiposteMenuSpells[menuSpellName]
        if menuData then
            if data.defaultEnabled then
                menuData.defaultEnabled = true
            end
            if data.cc then
                menuData.cc = true
            end
        end
    end

    if forceLookup or not RiposteSpellLookup[spellName] then
        RiposteSpellLookup[spellName] = data
    end
    RiposteMenuLookup[spellName] = menuSpellName

    if aliases then
        for i = 1, #aliases do
            local alias = aliases[i]
            if type(alias) == "string" and alias ~= "" then
                if forceLookup or not RiposteSpellLookup[alias] then
                    RiposteSpellLookup[alias] = data
                end
                RiposteMenuLookup[alias] = menuSpellName
            end
        end
    end
end

local function NormalizeRiposteSpellData(spellName, spellData, defaultDanger, defaultEnabled)
    if type(spellData) ~= "table" then
        return nil
    end

    return {
        charName = spellData.charName,
        displayName = spellData.displayName or spellName,
        missileName = spellData.missileName,
        slot = spellData.slot,
        type = spellData.type,
        speed = spellData.speed or math_huge,
        range = spellData.range or 0,
        delay = spellData.delay or 0,
        radius = spellData.radius or 0,
        radius2 = spellData.radius2,
        angle = spellData.angle,
        collision = spellData.collision == true,
        danger = spellData.danger or defaultDanger or 1,
        cc = spellData.cc == true,
        defaultEnabled = defaultEnabled
    }
end

local function BuildRiposteAliases(spellData)
    if type(spellData) ~= "table" then
        return nil
    end

    local aliases = {}
    if type(spellData.missileName) == "string" and spellData.missileName ~= "" then
        aliases[#aliases + 1] = spellData.missileName
    end

    if type(spellData.aliases) == "table" then
        for i = 1, #spellData.aliases do
            local alias = spellData.aliases[i]
            if type(alias) == "string" and alias ~= "" then
                aliases[#aliases + 1] = alias
            end
        end
    end

    if #aliases > 0 then
        return aliases
    end

    return nil
end

local function BuildRiposteSpellMaps()
    for spellName, data in pairs(RIPOSTE_EXTRA_SPELLS) do
        local normalized = NormalizeRiposteSpellData(spellName, data, 1, data.cc == true)
        if normalized then
            RegisterRiposteSpell(spellName, normalized, BuildRiposteAliases(data), false)
        end
    end

    for spellName, data in pairs(CCSpells) do
        local normalized = NormalizeRiposteSpellData(spellName, data, 3, data.defaultEnabled ~= false)
        RegisterRiposteSpell(spellName, normalized, BuildRiposteAliases(data), true)
    end
end

BuildRiposteSpellMaps()

local function GetDistanceSqr(p1, p2)
    local pos1 = p1.pos or p1
    local pos2 = p2.pos or p2
    local dx = pos1.x - pos2.x
    local dz = pos1.z - pos2.z
    return dx * dx + dz * dz
end

local function IsValid(unit)
    return unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable
end

local function Ready(slot)
    return myHero:GetSpellData(slot).currentCd == 0 and myHero:GetSpellData(slot).level > 0 and GameCanUseSpell(slot) == 0
end

local function ExtendVector(from, to, dist)
    local dx = to.x - from.x
    local dz = to.z - from.z
    local d = math_sqrt(dx * dx + dz * dz)
    if d == 0 then return to end
    return Vector(from.x + dx / d * dist, from.y or to.y, from.z + dz / d * dist)
end

local function IsWall(pos)
    if not MapPosition or type(MapPosition) ~= "table" or type(MapPosition.inWall) ~= "function" or not pos then
        return false
    end

    local ok, result = pcall(function() return MapPosition:inWall(pos) end)
    return ok and not not result or false
end

local function GetWallIntersection(startPos, endPos)
    if not MapPosition or type(MapPosition) ~= "table" or type(MapPosition.getIntersectionPoint3D) ~= "function" then
        return nil
    end

    local ok, result = pcall(function() return MapPosition:getIntersectionPoint3D(startPos, endPos) end)
    if ok and result then
        return Vector(result)
    end

    return nil
end

local function SetForcedMovement(pos)
    local orbwalker = _G.SDK and _G.SDK.Orbwalker
    if orbwalker then
        orbwalker.ForceMovement = pos
    elseif pos then
        ControlMove(pos)
    end
end

local function ClearForcedMovement()
    local orbwalker = _G.SDK and _G.SDK.Orbwalker
    if orbwalker then
        orbwalker.ForceMovement = nil
    end
end

local function GetGGPredictionPosition(prediction, target, hitChance)
    if not GGPrediction or not prediction or not IsValid(target) then
        return nil, nil
    end

    prediction:GetPrediction(target, myHero)
    if prediction:CanHit(hitChance or GG_HITCHANCE_NORMAL) then
        local castPos = prediction.CastPosition and Vector(prediction.CastPosition) or nil
        local unitPos = prediction.UnitPosition and Vector(prediction.UnitPosition) or castPos
        return castPos, unitPos
    end

    return nil, nil
end

local function GetWallJumpData()
    if not mousePos then
        return nil
    end

    local startPos = myHero.pos
    local approachPos = ExtendVector(startPos, mousePos, WALLJUMP_CHECK_DISTANCE)
    local castPos = ExtendVector(startPos, mousePos, WALLJUMP_CAST_DISTANCE)
    local holdPos = ExtendVector(startPos, mousePos, myHero.boundingRadius + 25)
    local wallPoint = GetWallIntersection(startPos, castPos)
    local wallDistance = wallPoint and math_sqrt(GetDistanceSqr(startPos, wallPoint)) or math_huge
    local touchDistance = (myHero.boundingRadius or 35) + WALLJUMP_TOUCH_EXTRA
    local nearWall = wallPoint ~= nil or IsWall(approachPos)
    local preWallPos = wallPoint and ExtendVector(
        startPos,
        wallPoint,
        math_max(0, wallDistance - WALLJUMP_PREWALL_BUFFER)
    ) or approachPos

    if wallPoint then
        holdPos = preWallPos
    end

    local canCast = wallPoint
        and wallDistance <= touchDistance
        and not IsWall(castPos)
        and math_abs(mousePos.y - startPos.y) < WALLJUMP_HEIGHT_TOLERANCE

    return {
        approachPos = approachPos,
        castPos = castPos,
        holdPos = holdPos,
        preWallPos = preWallPos,
        wallPoint = wallPoint,
        wallDistance = wallDistance,
        touchDistance = touchDistance,
        nearWall = nearWall,
        canCast = canCast
    }
end

local function HasBuff(unit, buffName)
    if not unit or not unit.buffCount or not buffName then
        return false
    end

    local now = GameTimer()
    local unitId = unit.networkID or 0
    local searchName = string_lower(buffName)
    local cached = PerfCache.buffSearch[unitId]
    if cached and cached.buffCount == unit.buffCount and cached.searchName == searchName and now - cached.tick < BUFF_CACHE_DURATION then
        return cached.value
    end

    local found = false
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name and string_find(string_lower(buff.name), searchName, 1, true) then
            found = true
            break
        end
    end

    PerfCache.buffSearch[unitId] = {
        tick = now,
        buffCount = unit.buffCount,
        searchName = searchName,
        value = found
    }

    return found
end

local function IsCombatMode(mode)
    return mode == "Combo" or mode == "Harass" or mode == "Clear"
end

local function GetHeroCacheDuration()
    return IsCombatMode(ActiveMode) and HERO_CACHE_COMBAT or HERO_CACHE_IDLE
end

local function GetMinionCacheDuration()
    return IsCombatMode(ActiveMode) and MINION_CACHE_COMBAT or MINION_CACHE_IDLE
end

local function GetVitalObjectCacheDuration()
    return IsCombatMode(ActiveMode) and VITAL_OBJECT_CACHE_COMBAT or VITAL_OBJECT_CACHE_IDLE
end

local function GetRangeKey(range)
    return tostring(math_floor((range or 0) + 0.5))
end

local function RefreshEnemyHeroCache()
    local now = GameTimer()
    if now - PerfCache.enemyHeroes.tick < GetHeroCacheDuration() then
        return
    end

    local enemies = {}
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero and hero.team ~= myHero.team and IsValid(hero) then
            enemies[#enemies + 1] = hero
        end
    end

    PerfCache.enemyHeroes.tick = now
    PerfCache.enemyHeroes.all = enemies
    PerfCache.enemyHeroes.byRange = {}
    PerfCache.target = {}
end

local function GetEnemyHeroes(range)
    RefreshEnemyHeroCache()
    if not range then
        return PerfCache.enemyHeroes.all
    end

    local key = GetRangeKey(range)
    local cached = PerfCache.enemyHeroes.byRange[key]
    local now = GameTimer()
    if cached and now - cached.tick < RANGE_CACHE_DURATION then
        return cached.data
    end

    local rangeSqr = range * range
    local enemies = PerfCache.enemyHeroes.all
    local filtered = {}
    for i = 1, #enemies do
        local hero = enemies[i]
        if GetDistanceSqr(myHero, hero) <= rangeSqr then
            filtered[#filtered + 1] = hero
        end
    end

    PerfCache.enemyHeroes.byRange[key] = {tick = now, data = filtered}
    return filtered
end

local function RefreshEnemyMinionCache()
    local now = GameTimer()
    if now - PerfCache.enemyMinions.tick < GetMinionCacheDuration() then
        return
    end

    local minions = {}
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and minion.team ~= myHero.team and IsValid(minion) then
            minions[#minions + 1] = minion
        end
    end

    PerfCache.enemyMinions.tick = now
    PerfCache.enemyMinions.all = minions
    PerfCache.enemyMinions.byRange = {}
end

local function GetEnemyMinions(range)
    RefreshEnemyMinionCache()
    if not range then
        return PerfCache.enemyMinions.all
    end

    local key = GetRangeKey(range)
    local cached = PerfCache.enemyMinions.byRange[key]
    local now = GameTimer()
    if cached and now - cached.tick < RANGE_CACHE_DURATION then
        return cached.data
    end

    local rangeSqr = range * range
    local minions = PerfCache.enemyMinions.all
    local filtered = {}
    for i = 1, #minions do
        local minion = minions[i]
        if GetDistanceSqr(myHero, minion) <= rangeSqr then
            filtered[#filtered + 1] = minion
        end
    end

    PerfCache.enemyMinions.byRange[key] = {tick = now, data = filtered}
    return filtered
end

local function RefreshVitalObjectCache()
    local now = GameTimer()
    if now - PerfCache.vitalObjects.tick < GetVitalObjectCacheDuration() then
        return
    end

    local objects = {}
    for i = 1, GameObjectCount() do
        local obj = GameObject(i)
        if obj and obj.name and obj.pos then
            local name = obj.name
            if string_find(name, "Fiora", 1, true) and (string_find(name, "Passive", 1, true) or string_find(name, "R_", 1, true)) then
                objects[#objects + 1] = obj
            end
        end
    end

    PerfCache.vitalObjects.tick = now
    PerfCache.vitalObjects.all = objects
end

local function GetVitalObjects()
    RefreshVitalObjectCache()
    return PerfCache.vitalObjects.all
end

local function MyHeroNotReady()
    if myHero.dead or GameIsChatOpen() then
        return true
    end
    if _G.JustEvade and _G.JustEvade:Evading() then
        return true
    end
    if _G.ExtLibEvade and _G.ExtLibEvade.Evading then
        return true
    end
    return false
end

local function Mode()
    local now = GameTimer()
    if now - PerfCache.mode.tick < MODE_CACHE_DURATION then
        return PerfCache.mode.value
    end

    local mode = nil
    if _G.SDK and _G.SDK.Orbwalker then
        local orbwalker = _G.SDK.Orbwalker
        local comboMode = _G.SDK.ORBWALKER_MODE_COMBO
        local harassMode = _G.SDK.ORBWALKER_MODE_HARASS
        local laneClearMode = _G.SDK.ORBWALKER_MODE_LANECLEAR
        local laneClearsMode = _G.SDK.ORBWALKER_MODE_LANECLEARS
        local jungleMode = _G.SDK.ORBWALKER_MODE_JUNGLECLEAR
        local fleeMode = _G.SDK.ORBWALKER_MODE_FLEE

        if comboMode and orbwalker:HasMode(comboMode) then mode = "Combo"
        elseif harassMode and orbwalker:HasMode(harassMode) then mode = "Harass"
        elseif (laneClearMode and orbwalker:HasMode(laneClearMode))
            or (laneClearsMode and orbwalker:HasMode(laneClearsMode))
            or (jungleMode and orbwalker:HasMode(jungleMode)) then
            mode = "Clear"
        elseif fleeMode and orbwalker:HasMode(fleeMode) then
            mode = "Flee"
        end
    elseif _G.GOS then
        mode = _G.GOS:GetMode()
    end

    ActiveMode = mode or "None"
    PerfCache.mode.tick = now
    PerfCache.mode.value = mode
    return mode
end

local VitalSystem = {
    Vitals = {},
    LastScan = 0,
    ScanInterval = 0.1,
    VitalPadding = 38,
    QOffset = 18,
}

local VITAL_OFFSETS = {
    ["NW"] = {x = 1, z = 0},
    ["NE"] = {x = 0, z = 1},
    ["SE"] = {x = -1, z = 0},
    ["SW"] = {x = 0, z = -1},
}

function VitalSystem:GetDirection(name)
    if name:find("_nw") or name:find("NW") then return "NW"
    elseif name:find("_ne") or name:find("NE") then return "NE"
    elseif name:find("_se") or name:find("SE") then return "SE"
    elseif name:find("_sw") or name:find("SW") then return "SW"
    end
    return nil
end

function VitalSystem:GetVitalDistance(target)
    return (target and target.boundingRadius or 65) + self.VitalPadding
end

function VitalSystem:Scan()
    local now = GameTimer()
    if now - self.LastScan < self.ScanInterval then
        return self.Vitals
    end
    self.LastScan = now
    
    for k in pairs(self.Vitals) do self.Vitals[k] = nil end
    local vitalCount = 0
    local heroes = GetEnemyHeroes()
    local minions = GetEnemyMinions()
    
    local objects = GetVitalObjects()
    for i = 1, #objects do
        local obj = objects[i]
        local dir = self:GetDirection(obj.name)
        if dir then
            local owner = nil
            local minDistSqr = VITAL_OWNER_RANGE_SQR

            for j = 1, #heroes do
                local hero = heroes[j]
                local distSqr = GetDistanceSqr(obj.pos, hero.pos)
                if distSqr < minDistSqr then
                    minDistSqr = distSqr
                    owner = hero
                end
            end

            if not owner then
                for j = 1, #minions do
                    local minion = minions[j]
                    local distSqr = GetDistanceSqr(obj.pos, minion.pos)
                    if distSqr < minDistSqr then
                        minDistSqr = distSqr
                        owner = minion
                    end
                end
            end

            if owner then
                local offset = VITAL_OFFSETS[dir]
                local vitalDistance = self:GetVitalDistance(owner)
                local vitalPos = Vector(
                    owner.pos.x + offset.x * vitalDistance,
                    owner.pos.y,
                    owner.pos.z + offset.z * vitalDistance
                )

                local qPos = Vector(
                    vitalPos.x + offset.x * self.QOffset,
                    vitalPos.y,
                    vitalPos.z + offset.z * self.QOffset
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

local function GetPredictedVitalQPos(vital)
    if not vital or not vital.target or not vital.dir then
        return nil
    end

    local _, predictedTargetPos = GetGGPredictionPosition(GG_Q_PREDICTION, vital.target, GG_HITCHANCE_NORMAL)
    local offset = predictedTargetPos and VITAL_OFFSETS[vital.dir] or nil
    if not predictedTargetPos or not offset then
        return nil
    end

    local vitalDistance = VitalSystem:GetVitalDistance(vital.target)
    local vitalPos = Vector(
        predictedTargetPos.x + offset.x * vitalDistance,
        vital.target.pos.y,
        predictedTargetPos.z + offset.z * vitalDistance
    )

    local qPos = Vector(
        vitalPos.x + offset.x * VitalSystem.QOffset,
        vitalPos.y,
        vitalPos.z + offset.z * VitalSystem.QOffset
    )

    if GetDistanceSqr(myHero.pos, qPos) <= SPELL_RANGE_Q_SQR then
        return qPos
    end

    return nil
end

local function GetExtendedQCastPosition(basePos, extraDistance)
    if not basePos then
        return nil
    end

    local distSqr = GetDistanceSqr(myHero.pos, basePos)
    if distSqr > SPELL_RANGE_Q_SQR then
        return nil
    end

    local dist = math_sqrt(distSqr)
    if dist == 0 or extraDistance <= 0 then
        return basePos
    end

    local desiredDistance = math_min(SPELL_RANGE_Q, dist + extraDistance)
    if desiredDistance <= dist then
        return basePos
    end

    return ExtendVector(myHero.pos, basePos, desiredDistance)
end

local function GetQCastPosition(target, onlyVital)
    if not IsValid(target) then
        return nil
    end

    local vital = VitalSystem:GetBest(target)
    if vital and vital.qPos then
        local predictedVitalQPos = GetPredictedVitalQPos(vital)
        if predictedVitalQPos then
            return GetExtendedQCastPosition(predictedVitalQPos, Q_VITAL_FAR_CAST_EXTRA) or predictedVitalQPos
        end
        return GetExtendedQCastPosition(vital.qPos, Q_VITAL_FAR_CAST_EXTRA) or vital.qPos
    end

    if not onlyVital then
        local predictedCastPos = GetGGPredictionPosition(GG_Q_PREDICTION, target, GG_HITCHANCE_NORMAL)
        if predictedCastPos and GetDistanceSqr(myHero.pos, predictedCastPos) <= SPELL_RANGE_Q_SQR then
            return GetExtendedQCastPosition(predictedCastPos, Q_TARGET_FAR_CAST_EXTRA) or predictedCastPos
        end

        if GetDistanceSqr(myHero, target) <= SPELL_RANGE_Q_SQR then
            return GetExtendedQCastPosition(target.pos, Q_TARGET_FAR_CAST_EXTRA) or target.pos
        end
    end

    return nil
end

local function CastQTarget(target, onlyVital)
    local castPos = GetQCastPosition(target, onlyVital)
    if not castPos then
        return false
    end

    ControlCastSpell(HK_Q, castPos)
    return true
end

local function GetRiposteAimPosition(spell)
    local target = spell and spell.caster or nil
    if IsValid(target) and GetDistanceSqr(myHero, target) <= SPELL_RANGE_W_SQR then
        local predictedCastPos = GetGGPredictionPosition(GG_W_PREDICTION, target, GG_HITCHANCE_NORMAL)
        if predictedCastPos and GetDistanceSqr(myHero.pos, predictedCastPos) <= SPELL_RANGE_W_SQR then
            return predictedCastPos
        end
        return target.pos
    end

    return spell and ((spell.caster and spell.caster.pos) or spell.startPos) or myHero.pos
end

local function GetSpellSlotLabel(slot)
    return SPELL_SLOT_LABELS[slot] or "?"
end

local function BuildRiposteSkillLabel(spellName, data)
    local slotLabel = GetSpellSlotLabel(data.slot)
    local displayName = data.displayName or spellName
    return string.format("[%s] %s", slotLabel, displayName)
end

local function CollectEnemyRiposteSpells()
    local result = {}

    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero and hero.isEnemy then
            local spellList = {}
            for spellName, data in pairs(RiposteMenuSpells) do
                if data.charName == hero.charName then
                    spellList[#spellList + 1] = {
                        spellName = spellName,
                        data = data
                    }
                end
            end

            if #spellList > 0 then
                table.sort(spellList, function(a, b)
                    local slotA = a.data.slot or 99
                    local slotB = b.data.slot or 99
                    if slotA == slotB then
                        return (a.data.displayName or a.spellName) < (b.data.displayName or b.spellName)
                    end
                    return slotA < slotB
                end)

                result[#result + 1] = {
                    hero = hero,
                    spells = spellList
                }
            end
        end
    end

    table.sort(result, function(a, b)
        return a.hero.charName < b.hero.charName
    end)

    return result
end

local function GetTrackedRiposteSpellData(spellName)
    return RiposteSpellLookup[spellName]
end

local function GetRiposteSpellMenuOption(spellName, data)
    local instance = _G.DepressiveFioraInstance
    local comboMenu = instance and instance.Menu and instance.Menu.Combo
    local riposteMenu = comboMenu and comboMenu.RiposteSkills
    local championMenu = riposteMenu and data and data.charName and riposteMenu[data.charName]
    local menuSpellName = RiposteMenuLookup[spellName] or spellName
    local spellOption = championMenu and championMenu[menuSpellName]
    return spellOption
end

local function IsRiposteSpellEnabled(spellName, data)
    local option = GetRiposteSpellMenuOption(spellName, data)
    if option and option.Value then
        return option:Value()
    end
    return true
end

local RiposteSystem = {
    Spells = {},
    SpellKeys = {},
    LastProcess = 0,
    ProcessInterval = 0.02,
    TrackPersistTime = 0.12,
    TrackExpireSlack = 0.08,
    MaxTrackLifetime = 1.5,
}

local function GetSpellVectorPosition(pos)
    if pos and pos.x and pos.z then
        return Vector(pos)
    end
    return nil
end

local function GetSpellStartPosition(caster, spell)
    local startPos = GetSpellVectorPosition(spell and spell.startPos)
    if startPos then
        return startPos
    end
    if caster and caster.pos then
        return Vector(caster.pos)
    end
    return myHero.pos
end

local function GetSpellDirectionEndPosition(caster, startPos, data)
    if not caster or not caster.pos or not caster.dir or not caster.dir.x or not caster.dir.z or not data or not data.range or data.range <= 0 then
        return nil
    end

    local dirPoint = Vector(caster.pos.x + caster.dir.x, startPos.y, caster.pos.z + caster.dir.z)
    return ExtendVector(startPos, dirPoint, data.range)
end

local function GetSpellEndPosition(caster, spell, data, startPos)
    local rawEnd = GetSpellVectorPosition(spell and (spell.placementPos or spell.endPos or spell.targetPos))
    if rawEnd then
        if data and data.range and data.range > 0 and data.type ~= "targeted" and data.type ~= "circular" then
            if GetDistanceSqr(startPos, rawEnd) > 25 * 25 then
                return ExtendVector(startPos, rawEnd, data.range)
            end
        else
            return rawEnd
        end
    end

    return GetSpellDirectionEndPosition(caster, startPos, data) or rawEnd or startPos
end

function RiposteSystem:GetSpellKey(caster, spell)
    local spellTime = spell.endTime or spell.castEndTime or spell.startTime or 0
    return caster.networkID .. ":" .. tostring(spell.name) .. ":" .. math_floor(spellTime * 20)
end

function RiposteSystem:RemoveTrackedSpell(index)
    local trackedSpell = self.Spells[index]
    if trackedSpell then
        self.SpellKeys[trackedSpell.key] = nil
        table_remove(self.Spells, index)
    end
end

function RiposteSystem:UpsertTrackedSpell(key, caster, spellName, data, now, timeToHit, startPos, endPos)
    local trackedSpell = self.SpellKeys[key]
    if trackedSpell then
        trackedSpell.spellName = spellName
        trackedSpell.caster = caster
        trackedSpell.data = data
        trackedSpell.time = now
        trackedSpell.hitTime = timeToHit
        trackedSpell.lastSeen = now
        trackedSpell.startPos = startPos
        trackedSpell.endPos = endPos
        return trackedSpell
    end

    trackedSpell = {
        key = key,
        spellName = spellName,
        caster = caster,
        data = data,
        time = now,
        createdAt = now,
        lastSeen = now,
        hitTime = timeToHit,
        startPos = startPos,
        endPos = endPos,
    }
    self.SpellKeys[key] = trackedSpell
    table_insert(self.Spells, trackedSpell)
    return trackedSpell
end

function RiposteSystem:Process()
    local now = GameTimer()
    if now - self.LastProcess < self.ProcessInterval then return end
    self.LastProcess = now
    
    for i = #self.Spells, 1, -1 do
        local trackedSpell = self.Spells[i]
        local unseenTime = now - (trackedSpell.lastSeen or trackedSpell.time)
        local age = now - (trackedSpell.createdAt or trackedSpell.time)
        local timeLeft = trackedSpell.hitTime - (now - trackedSpell.time)
        if unseenTime > self.TrackPersistTime or age > self.MaxTrackLifetime or timeLeft < -self.TrackExpireSlack then
            self:RemoveTrackedSpell(i)
        end
    end
    
    local enemies = GetEnemyHeroes()
    for i = 1, #enemies do
        local enemy = enemies[i]
        local spell = enemy.activeSpell
        if spell and spell.valid and spell.name then
            local data = GetTrackedRiposteSpellData(spell.name)
            if data and IsRiposteSpellEnabled(spell.name, data) then
                local key = self:GetSpellKey(enemy, spell)
                local trackedSpell = self.SpellKeys[key]
                local willHit, timeToHit, startPos, endPos = self:WillHit(enemy, spell, data)
                if willHit then
                    self:UpsertTrackedSpell(key, enemy, spell.name, data, now, timeToHit, startPos, endPos)
                elseif trackedSpell then
                    trackedSpell.lastSeen = now
                end
            end
        end
    end
end

function RiposteSystem:WillHit(caster, spell, data)
    local myPos = myHero.pos
    local startPos = GetSpellStartPosition(caster, spell)
    local endPos = GetSpellEndPosition(caster, spell, data, startPos)
    
    if data.type == "targeted" then
        if spell.target == myHero.handle then
            return true, data.delay, startPos, endPos
        end

        local explicitTargetPos = GetSpellVectorPosition(spell.targetPos or spell.placementPos or spell.endPos)
        if explicitTargetPos and data.range > 0 then
            local castRange = data.range + caster.boundingRadius + myHero.boundingRadius + 75
            local targetPadding = (data.radius or 0) + myHero.boundingRadius + 100
            if GetDistanceSqr(caster, myHero) <= castRange * castRange and GetDistanceSqr(explicitTargetPos, myPos) <= targetPadding * targetPadding then
                return true, data.delay, startPos, explicitTargetPos
            end
        end
    elseif data.type == "linear" or data.type == "polygon" or data.type == "rectangular" or data.type == "threeway" then
        local radius = data.radius2 or data.radius or 0
        local distSqr = GetDistanceSqr(caster, myHero)
        if distSqr > (data.range + 200) * (data.range + 200) then return false, 0, startPos, endPos end
        
        local dx = endPos.x - startPos.x
        local dz = endPos.z - startPos.z
        local len = math_sqrt(dx*dx + dz*dz)
        if len == 0 then return false, 0, startPos, endPos end
        
        dx, dz = dx/len, dz/len
        local tx = myPos.x - startPos.x
        local tz = myPos.z - startPos.z
        local proj = tx*dx + tz*dz
        
        if proj < 0 or proj > data.range then return false, 0, startPos, endPos end
        
        local closestX = startPos.x + dx * proj
        local closestZ = startPos.z + dz * proj
        local distToLine = math_sqrt((myPos.x-closestX)^2 + (myPos.z-closestZ)^2)
        
        if distToLine <= radius + myHero.boundingRadius + 20 then
            local time = data.speed == math_huge and data.delay or (proj / data.speed + data.delay)
            return true, time, startPos, endPos
        end
    elseif data.type == "conic" then
        local dx = endPos.x - startPos.x
        local dz = endPos.z - startPos.z
        local len = math_sqrt(dx * dx + dz * dz)
        if len == 0 then return false, 0, startPos, endPos end

        local tx = myPos.x - startPos.x
        local tz = myPos.z - startPos.z
        local dist = math_sqrt(tx * tx + tz * tz)
        if dist == 0 then
            return true, data.delay, startPos, endPos
        end

        if dist > data.range + myHero.boundingRadius then
            return false, 0, startPos, endPos
        end

        local dot = (dx * tx + dz * tz) / (len * dist)
        dot = math_max(-1, math_min(1, dot))
        local halfAngle = ((data.angle or 45) * 0.5) * math.pi / 180
        local anglePadding = math.atan(((data.radius or 0) + myHero.boundingRadius + 20) / math_max(dist, 1))
        if math_acos(dot) <= halfAngle + anglePadding then
            return true, data.delay, startPos, endPos
        end
    elseif data.type == "circular" then
        local center = data.range > 0 and endPos or caster.pos
        local distSqr = GetDistanceSqr(myPos, center)
        if distSqr <= (data.radius + myHero.boundingRadius)^2 then
            return true, data.delay, startPos, endPos
        end
    end
    
    return false, 0, startPos, endPos
end

function RiposteSystem:ShouldParry(minDanger)
    local now = GameTimer()
    local best = nil
    local bestDanger = 0
    
    for i = 1, #self.Spells do
        local s = self.Spells[i]
        local timeLeft = s.hitTime - (now - s.time)
        if timeLeft > 0 and timeLeft < 0.75 and IsRiposteSpellEnabled(s.spellName, s.data) then
            local danger = s.data.danger or 3
            if danger >= minDanger and danger > bestDanger then
                bestDanger = danger
                best = s
            end
        end
    end
    
    return best
end

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

local function GetTarget(range)
    local key = GetRangeKey(range)
    local now = GameTimer()
    local cached = PerfCache.target[key]
    if cached and now - cached.tick < TARGET_CACHE_DURATION and IsValid(cached.target) and GetDistanceSqr(myHero, cached.target) <= range * range then
        return cached.target
    end

    if _G.SDK and _G.SDK.TargetSelector then
        local t = _G.SDK.TargetSelector:GetTarget(range)
        if t and IsValid(t) then
            PerfCache.target[key] = {tick = now, target = t}
            return t
        end
    end
    
    local best, bestHP = nil, math_huge
    local rangeSqr = range * range
    local enemies = GetEnemyHeroes(range)
    
    for i = 1, #enemies do
        local enemy = enemies[i]
        local distSqr = GetDistanceSqr(myHero, enemy)
        if distSqr <= rangeSqr and enemy.health < bestHP then
            bestHP = enemy.health
            best = enemy
        end
    end

    PerfCache.target[key] = {tick = now, target = best}
    
    return best
end

class "DepressiveFiora"

function DepressiveFiora:__init()
    self.LastWallJumpCast = 0
    self:CreateMenu()
    Callback.Add("Tick", function() self:OnTick() end)
    Callback.Add("Draw", function() self:OnDraw() end)
    print("[DepressiveFiora] v" .. Version .. " loaded!")
end

function DepressiveFiora:CreateMenu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveFiora", name = "Depressive - Fiora"})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "[Combo]"})
    self.Menu.Combo:MenuElement({id = "Q", name = "Use Q", value = true})
    self.Menu.Combo:MenuElement({id = "QVital", name = "Q Only Vitals", value = true})
    self.Menu.Combo:MenuElement({id = "W", name = "Auto Riposte", value = true})
    self.Menu.Combo:MenuElement({id = "WDanger", name = "Min Danger Level", value = 1, min = 1, max = 5})
    self.Menu.Combo:MenuElement({id = "E", name = "Use E", value = true})
    self.Menu.Combo:MenuElement({id = "R", name = "Use R", value = true})
    self.Menu.Combo:MenuElement({id = "RHP", name = "R if Enemy HP% <", value = 70, min = 10, max = 100})
    self.Menu.Combo:MenuElement({type = MENU, id = "RiposteSkills", name = "Riposte Skills:"})
    self:CreateRiposteSkillMenu()
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "[Harass]"})
    self.Menu.Harass:MenuElement({id = "Q", name = "Use Q", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana%", value = 30, min = 0, max = 100})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "[Clear]"})
    self.Menu.Clear:MenuElement({id = "Q", name = "Use Q", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana%", value = 40, min = 0, max = 100})
    
    self.Menu:MenuElement({type = MENU, id = "KS", name = "[KillSteal]"})
    self.Menu.KS:MenuElement({id = "Q", name = "Use Q", value = true})

    self.Menu:MenuElement({type = MENU, id = "WJ", name = "[Walljump]"})
    self.Menu.WJ:MenuElement({id = "Use", name = "Use Walljump", value = true})
    self.Menu.WJ:MenuElement({id = "Key", name = "Walljump Key", key = string.byte("G"), toggle = false})
    
    self.Menu:MenuElement({type = MENU, id = "Draw", name = "[Draw]"})
    self.Menu.Draw:MenuElement({id = "Q", name = "Draw Q", value = true})
    self.Menu.Draw:MenuElement({id = "Vital", name = "Draw Vitals", value = true})
    self.Menu.Draw:MenuElement({id = "Path", name = "Draw Q Path", value = true})
    self.Menu.Draw:MenuElement({id = "WJ", name = "Draw Walljump", value = true})
end

function DepressiveFiora:CreateRiposteSkillMenu()
    local riposteMenu = self.Menu and self.Menu.Combo and self.Menu.Combo.RiposteSkills
    if not riposteMenu then
        return
    end

    local enemySpellData = CollectEnemyRiposteSpells()
    if #enemySpellData == 0 then
        riposteMenu:MenuElement({id = "Empty", name = "No tracked enemy skills", value = false})
        return
    end

    for i = 1, #enemySpellData do
        local enemyData = enemySpellData[i]
        local enemy = enemyData.hero
        riposteMenu:MenuElement({type = MENU, id = enemy.charName, name = enemy.charName})

        local championMenu = riposteMenu[enemy.charName]
        for j = 1, #enemyData.spells do
            local spellEntry = enemyData.spells[j]
            championMenu:MenuElement({
                id = spellEntry.spellName,
                name = BuildRiposteSkillLabel(spellEntry.spellName, spellEntry.data),
                value = spellEntry.data.defaultEnabled ~= false
            })
        end
    end
end

function DepressiveFiora:HandleWallJump()
    if not self.Menu.WJ.Use:Value() or not self.Menu.WJ.Key:Value() or not MapPosition then
        ClearForcedMovement()
        return false
    end

    local jump = GetWallJumpData()
    if not jump then
        ClearForcedMovement()
        return false
    end

    if jump.canCast then
        if Ready(_Q) then
            local now = GameTimer()
            if now - self.LastWallJumpCast >= WALLJUMP_CAST_DELAY then
                self.LastWallJumpCast = now
                ControlCastSpell(HK_Q, jump.castPos)
            end
        else
            SetForcedMovement(jump.holdPos)
        end
    elseif jump.nearWall then
        SetForcedMovement(jump.preWallPos or jump.holdPos)
    else
        SetForcedMovement(jump.approachPos)
    end

    return true
end

function DepressiveFiora:OnTick()
    if MyHeroNotReady() then
        ClearForcedMovement()
        return
    end

    if self:HandleWallJump() then
        return
    end
    
    if self.Menu.Combo.W:Value() and Ready(_W) then
        RiposteSystem:Process()
        local spell = RiposteSystem:ShouldParry(self.Menu.Combo.WDanger:Value())
        if spell then
            local dir = GetRiposteAimPosition(spell)
            ControlCastSpell(HK_W, dir)
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
    
    if self.Menu.KS.Q:Value() then
        self:KillSteal()
    end
end

function DepressiveFiora:Combo()
    local target = GetTarget(550)
    if not target then return end
    
    local distSqr = GetDistanceSqr(myHero, target)
    
    if self.Menu.Combo.R:Value() and Ready(_R) and distSqr <= SPELL_RANGE_R_SQR then
        local hpPct = target.health / target.maxHealth * 100
        if hpPct <= self.Menu.Combo.RHP:Value() and not HasBuff(target, "fiorarmark") then
            ControlCastSpell(HK_R, target)
            return
        end
    end
    
    if self.Menu.Combo.Q:Value() and Ready(_Q) and CastQTarget(target, self.Menu.Combo.QVital:Value()) then
        return
    end
    
    if self.Menu.Combo.E:Value() and Ready(_E) and distSqr <= 62500 then
        ControlCastSpell(HK_E)
    end
end

function DepressiveFiora:Harass()
    if myHero.mana / myHero.maxMana * 100 < self.Menu.Harass.Mana:Value() then return end
    
    local target = GetTarget(SPELL_RANGE_Q + 50)
    if not target then return end
    
    if self.Menu.Harass.Q:Value() and Ready(_Q) then
        CastQTarget(target, true)
    end
end

function DepressiveFiora:Clear()
    if myHero.mana / myHero.maxMana * 100 < self.Menu.Clear.Mana:Value() then return end
    if not self.Menu.Clear.Q:Value() or not Ready(_Q) then return end
    
    local best, bestHP = nil, math_huge
    local minions = GetEnemyMinions(SPELL_RANGE_Q)
    for i = 1, #minions do
        local minion = minions[i]
        if minion.health < bestHP then
            bestHP = minion.health
            best = minion
        end
    end
    
    if best then
        ControlCastSpell(HK_Q, best.pos)
    end
end

function DepressiveFiora:KillSteal()
    if not Ready(_Q) then return end
    
    local enemies = GetEnemyHeroes(SPELL_RANGE_Q)
    for i = 1, #enemies do
        local enemy = enemies[i]
        if CanKill(enemy) and CastQTarget(enemy, false) then
            return
        end
    end
end

function DepressiveFiora:OnDraw()
    if myHero.dead or not self.Menu.Draw then return end
    
    local myPos = myHero.pos
    local myScreen = myPos:To2D()
    
    if self.Menu.Draw.Q:Value() and Ready(_Q) then
        DrawCircle(myPos, SPELL_RANGE_Q, 1, DrawColor(200, 100, 200, 255))
    end

    if self.Menu.Draw.WJ:Value() and self.Menu.WJ.Use:Value() and self.Menu.WJ.Key:Value() and MapPosition then
        local jump = GetWallJumpData()
        if jump then
            local color = jump.canCast and DrawColor(220, 80, 255, 120)
                or jump.nearWall and DrawColor(220, 255, 80, 80)
                or DrawColor(160, 255, 255, 255)
            DrawCircle(jump.approachPos, 20, 1, color)
            DrawCircle(jump.castPos, 30, 2, color)
            if jump.wallPoint then
                DrawCircle(jump.wallPoint, 18, 2, DrawColor(220, 255, 220, 0))
                DrawCircle(jump.preWallPos, 18, 2, DrawColor(220, 0, 220, 255))
            end
        end
    end
    
    if self.Menu.Draw.Vital:Value() then
        local vitals = VitalSystem:Scan()
        for i = 1, #vitals do
            local v = vitals[i]
            if v.pos then
                DrawCircle(v.pos, 35, 2, DrawColor(255, 255, 215, 0))
                
                if self.Menu.Draw.Path:Value() and v.qPos and myScreen and myScreen.x > 0 then
                    local distSqr = GetDistanceSqr(myPos, v.qPos)
                    if distSqr <= SPELL_RANGE_Q_SQR then
                        local qScreen = v.qPos:To2D()
                        if myScreen and qScreen and myScreen.x > 0 and qScreen.x > 0 then
                            DrawLine(myScreen, qScreen, 2, DrawColor(180, 0, 255, 0))
                        end
                    end
                end
            end
        end
    end
end

local function LoadDepressiveFiora()
    if _G.DepressiveFioraInstance then
        return
    end

    _G.DepressiveFioraInstance = DepressiveFiora()
end

if GameTimer() >= LOAD_DELAY_TIME then
    LoadDepressiveFiora()
elseif type(DelayAction) == "function" then
    DelayAction(LoadDepressiveFiora, LOAD_DELAY_TIME - GameTimer())
else
    Callback.Add("Tick", function()
        if GameTimer() >= LOAD_DELAY_TIME then
            LoadDepressiveFiora()
        end
    end)
end
