-- DepressiveAIONext compatibility guard
if _G.__DEPRESSIVE_NEXT_YASUO_LOADED then return end
_G.__DEPRESSIVE_NEXT_YASUO_LOADED = true

local Version = 3.2
local Name = "DepressiveYasuo2"

-- Hero validation
local Heroes = {"Yasuo"}
if not table.contains(Heroes, myHero.charName) then return end

-- Load prediction system
require("DepressivePrediction")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
    end
end, 1.0)

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

-- Use engine-provided HK_* constants directly (no local overrides)

-- Windows message constants
local KEY_DOWN = KEY_DOWN or 0x0100
local KEY_UP = KEY_UP or 0x0101
local HK_CTRL = HK_CTRL or 0x11 -- VK_CONTROL fallback for Ctrl key

-- Spell slot constants
local _Q = 0
local _W = 1
local _E = 2
local _R = 3

-- Hotkey constants for abilities
local HK_Q = HK_Q or _Q
local HK_W = HK_W or _W
local HK_E = HK_E or _E
local HK_R = HK_R or _R

-- Constants
local SPELL_RANGE = {
    Q = 475,
    Q3 = 900,
    E = 475,
    R = 1200
}

local SPELL_SPEED = {
    Q = math.huge,
    Q3 = 1200,
    E = math.huge
}

local SPELL_DELAY = {
    Q = 0.4,
    Q3 = 0.4,
    E = 0.1,
    R = 0.5
}

local SPELL_RADIUS = {
    Q = 20,
    Q3 = 90,
    E = 100
}

-- Blockable Spells Database (from Yasuo3.lua)
local BlockableSpells = {
    -- AATROX
    ["AatroxW"] = {charName = "Aatrox", displayName = "Infernal Chains", slot = 1, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 80, collision = true},
    
    -- AHRI
    ["AhriQ"] = {charName = "Ahri", displayName = "Orb of Deception", slot = 0, type = "linear", speed = 2500, range = 880, delay = 0.25, radius = 100, collision = false},
    ["AhriE"] = {charName = "Ahri", displayName = "Charm", slot = 2, type = "linear", speed = 1500, range = 975, delay = 0.25, radius = 60, collision = true},
    
    -- AKALI
    ["AkaliQ"] = {charName = "Akali", displayName = "Five Point Strike", slot = 0, type = "conic", speed = 3200, range = 550, delay = 0.25, radius = 60, angle = 45, collision = false},
    ["AkaliE"] = {charName = "Akali", displayName = "Shuriken Flip", slot = 2, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 70, collision = true},
    
    -- AMUMU
    ["BandageToss"] = {charName = "Amumu", displayName = "Bandage Toss", slot = 0, type = "linear", speed = 2000, range = 1100, delay = 0.25, radius = 80, collision = true},
    
    -- ANIVIA
    ["FlashFrostSpell"] = {charName = "Anivia", displayName = "Flash Frost", slot = 0, type = "linear", speed = 950, range = 1100, delay = 0.25, radius = 110, collision = false},
    
    -- APHELIOS
    ["ApheliosCalibrumQ"] = {charName = "Aphelios", displayName = "Moonshot", slot = 0, type = "linear", speed = 1850, range = 1450, delay = 0.35, radius = 60, collision = true},
    ["ApheliosInfernumQ"] = {charName = "Aphelios", displayName = "Duskwave", slot = 0, type = "conic", speed = 1500, range = 850, delay = 0.25, radius = 65, angle = 45, collision = false},
    ["ApheliosR"] = {charName = "Aphelios", displayName = "Moonlight Vigil", slot = 3, type = "linear", speed = 2050, range = 1600, delay = 0.5, radius = 125, collision = false},
    
    -- ASHE
    ["Volley"] = {charName = "Ashe", displayName = "Volley", slot = 1, type = "conic", speed = 2000, range = 1200, delay = 0.25, radius = 20, angle = 40, collision = true},
    ["EnchantedCrystalArrow"] = {charName = "Ashe", displayName = "Enchanted Crystal Arrow", slot = 3, type = "linear", speed = 1600, range = 12500, delay = 0.25, radius = 130, collision = false},
    
    -- AURELION SOL
    ["AurelionSolQ"] = {charName = "AurelionSol", displayName = "Starsurge", slot = 0, type = "linear", speed = 850, range = 1075, delay = 0, radius = 110, collision = false},
    
    -- BARD
    ["BardQ"] = {charName = "Bard", displayName = "Cosmic Binding", slot = 0, type = "linear", speed = 1500, range = 950, delay = 0.25, radius = 60, collision = true},
    
    -- BLITZCRANK
    ["RocketGrab"] = {charName = "Blitzcrank", displayName = "Rocket Grab", slot = 0, type = "linear", speed = 1800, range = 1150, delay = 0.25, radius = 70, collision = true},
    
    -- BRAND
    ["BrandQ"] = {charName = "Brand", displayName = "Sear", slot = 0, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 60, collision = true},
    
    -- BRAUM
    ["BraumQ"] = {charName = "Braum", displayName = "Winter's Bite", slot = 0, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, collision = true},
    ["BraumR"] = {charName = "Braum", displayName = "Glacial Fissure", slot = 3, type = "linear", speed = 1400, range = 1250, delay = 0.5, radius = 115, collision = false},
    
    -- CAITLYN
    ["CaitlynPiltoverPeacemaker"] = {charName = "Caitlyn", displayName = "Piltover Peacemaker", slot = 0, type = "linear", speed = 2200, range = 1250, delay = 0.625, radius = 90, collision = false},
    ["CaitlynEntrapment"] = {charName = "Caitlyn", displayName = "Entrapment", slot = 2, type = "linear", speed = 1600, range = 750, delay = 0.15, radius = 70, collision = true},
    
    -- CAMILLE
    ["CamilleE"] = {charName = "Camille", displayName = "Hookshot [First]", slot = 2, type = "linear", speed = 1900, range = 800, delay = 0, radius = 60, collision = false},
    ["CamilleEDash2"] = {charName = "Camille", displayName = "Hookshot [Second]", slot = 2, type = "linear", speed = 1900, range = 400, delay = 0, radius = 60, collision = false},
    
    -- CASSIOPEIA
    ["CassiopeiaW"] = {charName = "Cassiopeia", displayName = "Miasma", slot = 1, type = "circular", speed = 2500, range = 800, delay = 0.75, radius = 160, collision = false},
    
    -- CORKI
    ["PhosphorusBomb"] = {charName = "Corki", displayName = "Phosphorus Bomb", slot = 0, type = "circular", speed = 1000, range = 825, delay = 0.25, radius = 250, collision = false},
    ["MissileBarrageMissile"] = {charName = "Corki", displayName = "Missile Barrage [Standard]", slot = 3, type = "linear", speed = 2000, range = 1300, delay = 0.175, radius = 40, collision = true},
    ["MissileBarrageMissile2"] = {charName = "Corki", displayName = "Missile Barrage [Big]", slot = 3, type = "linear", speed = 2000, range = 1500, delay = 0.175, radius = 40, collision = true},
    
    -- DIANA
    ["DianaQ"] = {charName = "Diana", displayName = "Crescent Strike", slot = 0, type = "circular", speed = 1900, range = 900, delay = 0.25, radius = 185, collision = true},
    
    -- DRAVEN
    ["DravenDoubleShot"] = {charName = "Draven", displayName = "Double Shot", slot = 2, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 130, collision = false},
    ["DravenRCast"] = {charName = "Draven", displayName = "Whirling Death", slot = 3, type = "linear", speed = 2000, range = 12500, delay = 0.25, radius = 160, collision = false},
    
    -- DR MUNDO
    ["DrMundoQ"] = {charName = "DrMundo", displayName = "Infected Bonesaw", slot = 0, type = "linear", speed = 2000, range = 990, delay = 0.25, radius = 120, collision = true},
    
    -- EKKO
    ["EkkoQ"] = {charName = "Ekko", displayName = "Timewinder", slot = 0, type = "linear", speed = 1650, range = 1175, delay = 0.25, radius = 60, collision = false},
    
    -- ELISE
    ["EliseHumanE"] = {charName = "Elise", displayName = "Cocoon", slot = 2, type = "linear", speed = 1600, range = 1075, delay = 0.25, radius = 55, collision = true},
    
    -- EVELYNN
    ["EvelynnQ"] = {charName = "Evelynn", displayName = "Hate Spike", slot = 0, type = "linear", speed = 2400, range = 800, delay = 0.25, radius = 60, collision = true},
    
    -- EZREAL
    ["EzrealQ"] = {charName = "Ezreal", displayName = "Mystic Shot", slot = 0, type = "linear", speed = 2000, range = 1150, delay = 0.25, radius = 60, collision = true},
    ["EzrealW"] = {charName = "Ezreal", displayName = "Essence Flux", slot = 1, type = "linear", speed = 2000, range = 1150, delay = 0.25, radius = 60, collision = false},
    ["EzrealR"] = {charName = "Ezreal", displayName = "Trueshot Barrage", slot = 3, type = "linear", speed = 2000, range = 12500, delay = 1, radius = 160, collision = false},
    
    -- FIORA
    ["FioraW"] = {charName = "Fiora", displayName = "Riposte", slot = 1, type = "linear", speed = 3200, range = 750, delay = 0.75, radius = 70, collision = false},
    
    -- FIZZ
    ["FizzR"] = {charName = "Fizz", displayName = "Chum the Waters", slot = 3, type = "linear", speed = 1300, range = 1300, delay = 0.25, radius = 150, collision = false},
    
    -- GALIO
    ["GalioQ"] = {charName = "Galio", displayName = "Winds of War", slot = 0, type = "circular", speed = 1150, range = 825, delay = 0.25, radius = 235, collision = false},
    
    -- GNAR
    ["GnarQMissile"] = {charName = "Gnar", displayName = "Boomerang Throw", slot = 0, type = "linear", speed = 2500, range = 1125, delay = 0.25, radius = 55, collision = false},
    ["GnarBigQMissile"] = {charName = "Gnar", displayName = "Boulder Toss", slot = 0, type = "linear", speed = 2100, range = 1125, delay = 0.5, radius = 90, collision = true},
    
    -- GRAGAS
    ["GragasQ"] = {charName = "Gragas", displayName = "Barrel Roll", slot = 0, type = "circular", speed = 1000, range = 850, delay = 0.25, radius = 275, collision = false},
    ["GragasR"] = {charName = "Gragas", displayName = "Explosive Cask", slot = 3, type = "circular", speed = 1800, range = 1000, delay = 0.25, radius = 400, collision = false},
    
    -- GRAVES
    ["GravesQLineSpell"] = {charName = "Graves", displayName = "End of the Line", slot = 0, type = "linear", speed = math.huge, range = 800, delay = 1.4, radius = 20, collision = false},
    ["GravesSmokeGrenade"] = {charName = "Graves", displayName = "Smoke Grenade", slot = 1, type = "circular", speed = 1500, range = 950, delay = 0.15, radius = 250, collision = false},
    ["GravesChargeShot"] = {charName = "Graves", displayName = "Charge Shot", slot = 3, type = "linear", speed = 2100, range = 1000, delay = 0.25, radius = 100, collision = false},
    
    -- GWEN
    ["GwenQ"] = {charName = "Gwen", displayName = "Snip Snip!", slot = 0, type = "circular", speed = 1500, range = 450, delay = 0, radius = 275, collision = false},
    ["GwenR"] = {charName = "Gwen", displayName = "Needlework", slot = 3, type = "linear", speed = 1800, range = 1230, delay = 0.25, radius = 250, collision = false},
    
    -- HEIMERDINGER
    ["HeimerdingerW"] = {charName = "Heimerdinger", displayName = "Hextech Micro-Rockets", slot = 1, type = "linear", speed = 2050, range = 1325, delay = 0.25, radius = 100, collision = false},
    ["HeimerdingerE"] = {charName = "Heimerdinger", displayName = "CH-2 Electron Storm Grenade", slot = 2, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, collision = false},
    ["HeimerdingerEUlt"] = {charName = "Heimerdinger", displayName = "CH-2 Electron Storm Grenade [Ult]", slot = 2, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, collision = false},
    
    -- ILLAOI
    ["IllaoiE"] = {charName = "Illaoi", displayName = "Test of Spirit", slot = 2, type = "linear", speed = 1900, range = 900, delay = 0.25, radius = 50, collision = true},
    
    -- IRELIA
    ["IreliaR"] = {charName = "Irelia", displayName = "Vanguard's Edge", slot = 3, type = "linear", speed = 2000, range = 950, delay = 0.4, radius = 160, collision = false},
    
    -- IVERN
    ["IvernQ"] = {charName = "Ivern", displayName = "Rootcaller", slot = 0, type = "linear", speed = 1300, range = 1075, delay = 0.25, radius = 80, collision = true},
    
    -- JANNA
    ["HowlingGaleSpell"] = {charName = "Janna", displayName = "Howling Gale", slot = 0, type = "linear", speed = 667, range = 1750, delay = 0, radius = 100, collision = false},
    
    -- JAYCE
    ["JayceShockBlast"] = {charName = "Jayce", displayName = "Shock Blast [Standard]", slot = 0, type = "linear", speed = 1450, range = 1050, delay = 0.214, radius = 70, collision = true},
    ["JayceShockBlastWallMis"] = {charName = "Jayce", displayName = "Shock Blast [Accelerated]", slot = 0, type = "linear", speed = 2350, range = 1600, delay = 0.152, radius = 115, collision = true},
    
    -- JHIN
    ["JhinW"] = {charName = "Jhin", displayName = "Deadly Flourish", slot = 1, type = "linear", speed = 5000, range = 2550, delay = 0.75, radius = 40, collision = false},
    ["JhinRShot"] = {charName = "Jhin", displayName = "Curtain Call", slot = 3, type = "linear", speed = 5000, range = 3500, delay = 0.25, radius = 80, collision = false},
    
    -- JINX
    ["JinxWMissile"] = {charName = "Jinx", displayName = "Zap!", slot = 1, type = "linear", speed = 3300, range = 1450, delay = 0.6, radius = 60, collision = true},
    ["JinxEHit"] = {charName = "Jinx", displayName = "Flame Chompers!", slot = 2, type = "linear", speed = 1100, range = 900, delay = 1.5, radius = 120, collision = false},
    ["JinxR"] = {charName = "Jinx", displayName = "Super Mega Death Rocket!", slot = 3, type = "linear", speed = 1700, range = 12500, delay = 0.6, radius = 140, collision = false},
    
    -- KAISA
    ["KaisaW"] = {charName = "Kaisa", displayName = "Void Seeker", slot = 1, type = "linear", speed = 1750, range = 3000, delay = 0.4, radius = 100, collision = true},
    
    -- KALISTA
    ["KalistaMysticShot"] = {charName = "Kalista", displayName = "Pierce", slot = 0, type = "linear", speed = 2400, range = 1150, delay = 0.25, radius = 40, collision = true},
    
    -- KARMA
    ["KarmaQ"] = {charName = "Karma", displayName = "Inner Flame", slot = 0, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 60, collision = true},
    ["KarmaQMantra"] = {charName = "Karma", displayName = "Inner Flame [Mantra]", slot = 0, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 80, collision = true},
    
    -- KAYLE
    ["KayleQ"] = {charName = "Kayle", displayName = "Radiant Blast", slot = 0, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 60, collision = false},
    
    -- KENNEN
    ["KennenShurikenHurlMissile1"] = {charName = "Kennen", displayName = "Shuriken Hurl", slot = 0, type = "linear", speed = 1700, range = 1050, delay = 0.175, radius = 50, collision = true},
    
    -- KHAZIX
    ["KhazixW"] = {charName = "Khazix", displayName = "Void Spike [Standard]", slot = 1, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, collision = true},
    ["KhazixWLong"] = {charName = "Khazix", displayName = "Void Spike [Threeway]", slot = 1, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, collision = true},
    
    -- KLED
    ["KledQ"] = {charName = "Kled", displayName = "Beartrap on a Rope", slot = 0, type = "linear", speed = 1600, range = 800, delay = 0.25, radius = 45, collision = false},
    ["KledRiderQ"] = {charName = "Kled", displayName = "Pocket Pistol", slot = 0, type = "conic", speed = 3000, range = 700, delay = 0.25, radius = 0, angle = 25, collision = false},
    
    -- KOGMAW
    ["KogMawQ"] = {charName = "KogMaw", displayName = "Caustic Spittle", slot = 0, type = "linear", speed = 1650, range = 1175, delay = 0.25, radius = 70, collision = true},
    ["KogMawVoidOozeMissile"] = {charName = "KogMaw", displayName = "Void Ooze", slot = 2, type = "linear", speed = 1400, range = 1360, delay = 0.25, radius = 120, collision = false},
    
    -- KSANTE
    ["KSanteQ3"] = {charName = "KSante", displayName = "KSante Q3", slot = 0, type = "linear", speed = 1100, range = 750, delay = 0.34, radius = 70, collision = false},
    
    -- LEBLANC
    ["LeblancE"] = {charName = "Leblanc", displayName = "Ethereal Chains [Standard]", slot = 2, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, collision = true},
    ["LeblancRE"] = {charName = "Leblanc", displayName = "Ethereal Chains [Ultimate]", slot = 2, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, collision = true},
    
    -- LEE SIN
    ["BlindMonkQOne"] = {charName = "LeeSin", displayName = "Sonic Wave", slot = 0, type = "linear", speed = 1800, range = 1100, delay = 0.25, radius = 60, collision = true},
    
    -- LEONA
    ["LeonaZenithBlade"] = {charName = "Leona", displayName = "Zenith Blade", slot = 2, type = "linear", speed = 2000, range = 875, delay = 0.25, radius = 70, collision = false},
    
    -- LISSANDRA
    ["LissandraQMissile"] = {charName = "Lissandra", displayName = "Ice Shard", slot = 0, type = "linear", speed = 2200, range = 750, delay = 0.25, radius = 75, collision = false},
    ["LissandraEMissile"] = {charName = "Lissandra", displayName = "Glacial Path", slot = 2, type = "linear", speed = 850, range = 1025, delay = 0.25, radius = 125, collision = false},
    
    -- LUCIAN
    ["LucianW"] = {charName = "Lucian", displayName = "Ardent Blaze", slot = 1, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 80, collision = true},
    
    -- LULU
    ["LuluQ"] = {charName = "Lulu", displayName = "Glitterlance", slot = 0, type = "linear", speed = 1450, range = 925, delay = 0.25, radius = 60, collision = false},
    
    -- LUX
    ["LuxLightBinding"] = {charName = "Lux", displayName = "Light Binding", slot = 0, type = "linear", speed = 1200, range = 1175, delay = 0.25, radius = 70, collision = false},
    ["LuxLightStrikeKugel"] = {charName = "Lux", displayName = "Light Strike Kugel", slot = 2, type = "circular", speed = 1200, range = 1100, delay = 0.25, radius = 300, collision = true},
    
    -- MAOKAI
    ["MaokaiQ"] = {charName = "Maokai", displayName = "Bramble Smash", slot = 0, type = "linear", speed = 1600, range = 600, delay = 0.375, radius = 110, collision = false},
    
    -- MISS FORTUNE
    ["MissFortuneBulletTime"] = {charName = "MissFortune", displayName = "Bullet Time", slot = 3, type = "conic", speed = 2000, range = 1400, delay = 0.25, radius = 100, angle = 34, collision = false},
    
    -- MILIO
    ["MilioQ"] = {charName = "Milio", displayName = "Fire Kick", slot = 0, type = "linear", speed = 1200, range = 1000, delay = 0, radius = 60, collision = false},
    
    -- MORDEKAISER
    ["MordekaiserE"] = {charName = "Mordekaiser", displayName = "Death's Grasp", slot = 2, type = "linear", speed = math.huge, range = 900, delay = 0.9, radius = 140, collision = false},
    
    -- MORGANA
    ["MorganaQ"] = {charName = "Morgana", displayName = "Dark Binding", slot = 0, type = "linear", speed = 1200, range = 1250, delay = 0.25, radius = 70, collision = true},
    
    -- NAAFIRI
    ["NaafiriQ"] = {charName = "Naafiri", displayName = "Naafiri", slot = 0, type = "linear", speed = 1200, range = 900, delay = 0.25, radius = 50, collision = false},
    ["NaafiriQRecast"] = {charName = "Naafiri", displayName = "Naafiri Recast", slot = 0, type = "linear", speed = 1200, range = 900, delay = 0.25, radius = 50, collision = false},
    
    -- NAMI
    ["NamiQ"] = {charName = "Nami", displayName = "Aqua Prison", slot = 0, type = "circular", speed = math.huge, range = 875, delay = 1, radius = 180, collision = false},
    ["NamiRMissile"] = {charName = "Nami", displayName = "Tidal Wave", slot = 3, type = "linear", speed = 850, range = 2750, delay = 0.5, radius = 250, collision = false},
    
    -- NAUTILUS
    ["NautilusAnchorDragMissile"] = {charName = "Nautilus", displayName = "Dredge Line", slot = 0, type = "linear", speed = 2000, range = 925, delay = 0.25, radius = 90, collision = true},
    
    -- NEEKO
    ["NeekoQ"] = {charName = "Neeko", displayName = "Blooming Burst", slot = 0, type = "circular", speed = 1500, range = 800, delay = 0.25, radius = 200, collision = false},
    ["NeekoE"] = {charName = "Neeko", displayName = "Tangle-Barbs", slot = 2, type = "linear", speed = 1300, range = 1000, delay = 0.25, radius = 70, collision = false},
    
    -- NIDALEE
    ["JavelinToss"] = {charName = "Nidalee", displayName = "Javelin Toss", slot = 0, type = "linear", speed = 1300, range = 1500, delay = 0.25, radius = 40, collision = true},
    
    -- NOCTURNE
    ["NocturneDuskbringer"] = {charName = "Nocturne", displayName = "Duskbringer", slot = 0, type = "linear", speed = 1600, range = 1200, delay = 0.25, radius = 60, collision = false},
    
    -- OLAF
    ["OlafAxeThrowCast"] = {charName = "Olaf", displayName = "Undertow", slot = 0, type = "linear", speed = 1600, range = 1000, delay = 0.25, radius = 90, collision = false},
    
    -- ORNN
    ["OrnnQ"] = {charName = "Ornn", displayName = "Volcanic Rupture", slot = 0, type = "linear", speed = 1800, range = 800, delay = 0.3, radius = 65, collision = false},
    ["OrnnRCharge"] = {charName = "Ornn", displayName = "Call of the Forge God", slot = 3, type = "linear", speed = 1650, range = 2500, delay = 0.5, radius = 200, collision = false},
    
    -- PANTHEON
    ["PantheonQMissile"] = {charName = "Pantheon", displayName = "Comet Spear [Range]", slot = 0, type = "linear", speed = 2700, range = 1200, delay = 0.25, radius = 60, collision = false},
    ["PantheonR"] = {charName = "Pantheon", displayName = "Grand Starfall", slot = 3, type = "linear", speed = 2250, range = 1350, delay = 4, radius = 250, collision = false},
    
    -- POPPY
    ["PoppyRSpell"] = {charName = "Poppy", displayName = "Keeper's Verdict", slot = 3, type = "linear", speed = 2000, range = 1200, delay = 0.33, radius = 100, collision = false},
    
    -- PYKE
    ["PykeQRange"] = {charName = "Pyke", displayName = "Bone Skewer [Range]", slot = 0, type = "linear", speed = 2000, range = 1100, delay = 0.2, radius = 70, collision = true},
    
    -- QIYANA
    ["QiyanaQ_Grass"] = {charName = "Qiyana", displayName = "Edge of Ixtal [Grass]", slot = 0, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 70, collision = false},
    ["QiyanaQ_Rock"] = {charName = "Qiyana", displayName = "Edge of Ixtal [Rock]", slot = 0, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 70, collision = false},
    ["QiyanaQ_Water"] = {charName = "Qiyana", displayName = "Edge of Ixtal [Water]", slot = 0, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 70, collision = false},
    ["QiyanaR"] = {charName = "Qiyana", displayName = "Supreme Display of Talent", slot = 3, type = "linear", speed = 2000, range = 950, delay = 0.25, radius = 190, collision = false},
    
    -- QUINN
    ["QuinnQ"] = {charName = "Quinn", displayName = "Blinding Assault", slot = 0, type = "linear", speed = 1550, range = 1025, delay = 0.25, radius = 60, collision = true},
    
    -- RAKAN
    ["RakanQ"] = {charName = "Rakan", displayName = "Gleaming Quill", slot = 0, type = "linear", speed = 1850, range = 850, delay = 0.25, radius = 65, collision = true},
    
    -- REKSAI
    ["RekSaiQBurrowed"] = {charName = "RekSai", displayName = "Prey Seeker", slot = 0, type = "linear", speed = 1950, range = 1625, delay = 0.125, radius = 65, collision = true},
    
    -- RENGAR
    ["RengarE"] = {charName = "Rengar", displayName = "Bola Strike", slot = 2, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, collision = true},
    
    -- RIVEN
    ["RivenIzunaBlade"] = {charName = "Riven", displayName = "Wind Slash", slot = 3, type = "conic", speed = 1600, range = 900, delay = 0.25, radius = 0, angle = 75, collision = false},
    
    -- RUMBLE
    ["RumbleGrenade"] = {charName = "Rumble", displayName = "Electro Harpoon", slot = 2, type = "linear", speed = 2000, range = 850, delay = 0.25, radius = 60, collision = true},
    
    -- RYZE
    ["RyzeQ"] = {charName = "Ryze", displayName = "Overload", slot = 0, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 55, collision = true},
    
    -- SAMIRA
    ["SemiraQGun"] = {charName = "Samira", displayName = "Flair", slot = 0, type = "linear", speed = 2600, range = 1000, delay = 0.25, radius = 60, collision = true},
    
    -- SEJUANI
    ["SejuaniR"] = {charName = "Sejuani", displayName = "Glacial Prison", slot = 3, type = "linear", speed = 1600, range = 1300, delay = 0.25, radius = 120, collision = false},
    
    -- SENNA
    ["SennaW"] = {charName = "Senna", displayName = "Last Embrace", slot = 1, type = "linear", speed = 1150, range = 1300, delay = 0.25, radius = 60, collision = true},
    ["SennaR"] = {charName = "Senna", displayName = "Dawning Shadow", slot = 3, type = "linear", speed = 20000, range = 12500, delay = 1, radius = 180, collision = false},
    
    -- SERAPHINE
    ["SeraphineQCast"] = {charName = "Seraphine", displayName = "High Note", slot = 0, type = "circular", speed = 1200, range = 900, delay = 0.25, radius = 350, collision = false},
    ["SeraphineECast"] = {charName = "Seraphine", displayName = "Beat Drop", slot = 2, type = "linear", speed = 1200, range = 1300, delay = 0.25, radius = 70, collision = false},
    ["SeraphineR"] = {charName = "Seraphine", displayName = "Encore", slot = 3, type = "linear", speed = 1600, range = 1300, delay = 0.5, radius = 160, collision = false},
    
    -- SHYVANA
    ["ShyvanaFireball"] = {charName = "Shyvana", displayName = "Flame Breath [Standard]", slot = 2, type = "linear", speed = 1575, range = 925, delay = 0.25, radius = 60, collision = false},
    ["ShyvanaFireballDragon2"] = {charName = "Shyvana", displayName = "Flame Breath [Dragon]", slot = 2, type = "linear", speed = 1575, range = 975, delay = 0.333, radius = 60, collision = false},
    
    -- SION
    ["SionE"] = {charName = "Sion", displayName = "Roar of the Slayer", slot = 2, type = "linear", speed = 1800, range = 800, delay = 0.25, radius = 80, collision = false},
    
    -- SIVIR
    ["SivirQ"] = {charName = "Sivir", displayName = "Boomerang Blade", slot = 0, type = "linear", speed = 1350, range = 1250, delay = 0.25, radius = 90, collision = false},
    
    -- SKARNER
    ["SkarnerFractureMissile"] = {charName = "Skarner", displayName = "Fracture", slot = 2, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, collision = false},
    
    -- SONA
    ["SonaR"] = {charName = "Sona", displayName = "Crescendo", slot = 3, type = "linear", speed = 2400, range = 1000, delay = 0.25, radius = 140, collision = false},
    
    -- SWAIN
    ["SwainQ"] = {charName = "Swain", displayName = "Death's Hand", slot = 0, type = "conic", speed = 5000, range = 725, delay = 0.25, radius = 0, angle = 60, collision = false},
    ["SwainE"] = {charName = "Swain", displayName = "Nevermove", slot = 2, type = "linear", speed = 1800, range = 850, delay = 0.25, radius = 85, collision = false},
    
    -- SYLAS
    ["SylasE2"] = {charName = "Sylas", displayName = "Abduct", slot = 2, type = "linear", speed = 1600, range = 850, delay = 0.25, radius = 60, collision = true},
    
    -- SYNDRA
    ["SyndraE"] = {charName = "Syndra", displayName = "Scatter the Weak [Standard]", slot = 2, type = "conic", speed = 1600, range = 700, delay = 0.25, radius = 0, angle = 40, collision = false},
    ["SyndraESphereMissile"] = {charName = "Syndra", displayName = "Scatter the Weak [Sphere]", slot = 2, type = "linear", speed = 2000, range = 1250, delay = 0.25, radius = 100, collision = false},
    
    -- TAHM KENCH
    ["TahmKenchQ"] = {charName = "TahmKench", displayName = "Tongue Lash", slot = 0, type = "linear", speed = 2800, range = 900, delay = 0.25, radius = 70, collision = true},
    
    -- TALIYAH
    ["TaliyahQMis"] = {charName = "Taliyah", displayName = "Threaded Volley", slot = 0, type = "linear", speed = 3600, range = 1000, delay = 0, radius = 100, collision = true},
    
    -- TALON
    ["TalonW"] = {charName = "Talon", displayName = "Rake", slot = 1, type = "conic", speed = 2500, range = 650, delay = 0.25, radius = 75, angle = 26, collision = false},
    
    -- THRESH
    ["ThreshQ"] = {charName = "Thresh", displayName = "Death Sentence", slot = 0, type = "linear", speed = 1900, range = 1100, delay = 0.5, radius = 70, collision = true},
    
    -- TWISTED FATE
    ["WildCards"] = {charName = "TwistedFate", displayName = "Wild Cards", slot = 0, type = "linear", speed = 1000, range = 1450, delay = 0.25, radius = 40, collision = false},
    
    -- URGOT
    ["UrgotQ"] = {charName = "Urgot", displayName = "Corrosive Charge", slot = 0, type = "circular", speed = math.huge, range = 800, delay = 0.6, radius = 180, collision = false},
    ["UrgotR"] = {charName = "Urgot", displayName = "Fear Beyond Death", slot = 3, type = "linear", speed = 3200, range = 1600, delay = 0.5, radius = 80, collision = false},
    
    -- VARUS
    ["VarusQMissile"] = {charName = "Varus", displayName = "Piercing Arrow", slot = 0, type = "linear", speed = 1900, range = 1525, delay = 0, radius = 70, collision = false},
    ["VarusE"] = {charName = "Varus", displayName = "Hail of Arrows", slot = 2, type = "circular", speed = 1500, range = 925, delay = 0.242, radius = 260, collision = false},
    ["VarusR"] = {charName = "Varus", displayName = "Chain of Corruption", slot = 3, type = "linear", speed = 1500, range = 1200, delay = 0.25, radius = 120, collision = false},
    
    -- VEIGAR
    ["VeigarBalefulStrike"] = {charName = "Veigar", displayName = "Baleful Strike", slot = 0, type = "linear", speed = 2200, range = 900, delay = 0.25, radius = 70, collision = false},
    
    -- VELKOZ
    ["VelkozQMissileSplit"] = {charName = "Velkoz", displayName = "Plasma Fission [Split]", slot = 0, type = "linear", speed = 2100, range = 1100, delay = 0, radius = 45, collision = true},
    ["VelkozQ"] = {charName = "Velkoz", displayName = "Plasma Fission", slot = 0, type = "linear", speed = 1300, range = 1050, delay = 0.25, radius = 50, collision = true},
    ["VelkozW"] = {charName = "Velkoz", displayName = "Void Rift", slot = 1, type = "linear", speed = 1700, range = 1050, delay = 0.25, radius = 87.5, collision = false},
    
    -- VEX
    ["VexQ"] = {charName = "Vex", displayName = "Vex Q Bolt", slot = 0, type = "linear", speed = 2200, range = 1200, delay = 0.15, radius = 80, collision = false},
    
    -- VIEGO
    ["ViegoW"] = {charName = "Viego", displayName = "Spectral Maw", slot = 1, type = "linear", speed = 1300, range = 760, delay = 0, radius = 90, collision = true},
    
    -- VIKTOR
    ["ViktorDeathRayMissile"] = {charName = "Viktor", displayName = "Death Ray", slot = 2, type = "linear", speed = 1050, range = 700, delay = 0, radius = 80, collision = false},
    
    -- XAYAH
    ["XayahQ"] = {charName = "Xayah", displayName = "Double Daggers", slot = 0, type = "linear", speed = 2075, range = 1100, delay = 0.5, radius = 45, collision = false},
    
    -- XERATH
    ["XerathMageSpear"] = {charName = "Xerath", displayName = "Mage Spear", slot = 2, type = "linear", speed = 1400, range = 1050, delay = 0.2, radius = 60, collision = true},
    
    -- YASUO
    ["YasuoQ3"] = {charName = "Yasuo", displayName = "Gathering Storm", slot = 0, type = "linear", speed = 1200, range = 1100, delay = 0.03, radius = 90, collision = false},
    
    -- YONE
    ["YoneQ3"] = {charName = "Yone", displayName = "Mortal Steel [Storm]", slot = 0, type = "linear", speed = 1500, range = 1050, delay = 0.25, radius = 80, collision = false},
    
    -- ZAC
    ["ZacQ"] = {charName = "Zac", displayName = "Stretching Strikes", slot = 0, type = "linear", speed = 2800, range = 800, delay = 0.33, radius = 120, collision = false},
    
    -- ZED
    ["ZedQ"] = {charName = "Zed", displayName = "Razor Shuriken", slot = 0, type = "linear", speed = 1700, range = 900, delay = 0.25, radius = 50, collision = false},
    
    -- ZERI
    ["ZeriQ"] = {charName = "Zeri", displayName = "Burst Fire", slot = 0, type = "linear", speed = 1500, range = 840, delay = 0.25, radius = 80, collision = true},
    
    -- ZIGGS
    ["ZiggsQ"] = {charName = "Ziggs", displayName = "Bouncing Bomb", slot = 0, type = "linear", speed = 1750, range = 850, delay = 0.25, radius = 150, collision = true},
    ["ZiggsW"] = {charName = "Ziggs", displayName = "Satchel Charge", slot = 1, type = "circular", speed = 1750, range = 1000, delay = 0.25, radius = 240, collision = false},
    ["ZiggsE"] = {charName = "Ziggs", displayName = "Hexplosive Minefield", slot = 2, type = "circular", speed = 1800, range = 900, delay = 0.25, radius = 250, collision = false},
    
    -- ZILEAN
    ["ZileanQ"] = {charName = "Zilean", displayName = "Time Bomb", slot = 0, type = "circular", speed = math.huge, range = 900, delay = 0.8, radius = 150, collision = false},
    
    -- ZOE
    ["ZoeQMissile"] = {charName = "Zoe", displayName = "Paddle Star [First]", slot = 0, type = "linear", speed = 1200, range = 800, delay = 0.25, radius = 50, collision = true},
    ["ZoeQMis2"] = {charName = "Zoe", displayName = "Paddle Star [Second]", slot = 0, type = "linear", speed = 2500, range = 1600, delay = 0, radius = 70, collision = true},
    ["ZoeE"] = {charName = "Zoe", displayName = "Sleepy Trouble Bubble", slot = 2, type = "linear", speed = 1700, range = 800, delay = 0.3, radius = 50, collision = true},
    
    -- ZYRA
    ["ZyraE"] = {charName = "Zyra", displayName = "Grasping Roots", slot = 2, type = "linear", speed = 1150, range = 1100, delay = 0.25, radius = 70, collision = false},
}

-- Auto W system variables
local DetectedSpells = {}
local Units = {}

-- Utility Functions - 2D Only
local function GetDistance(p1, p2)
    if not p1 or not p2 then return math.huge end
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

local function GetDistance2D(p1, p2)
    if not p1 or not p2 then return math.huge end
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

-- Geometry helpers for line-based skillshots (2D)
local function Normalize2D(v)
    local len = math.sqrt(v.x * v.x + v.z * v.z)
    if len == 0 then return {x = 0, z = 0}, 0 end
    return {x = v.x / len, z = v.z / len}, len
end

-- Returns perpendicular distance from point p to the ray (from -> from + dir*range)
local function PointToRayDistance2D(from, dir, range, p)
    -- project AP onto dir
    local apx, apz = p.x - from.x, p.z - from.z
    local t = apx * dir.x + apz * dir.z
    if t < 0 or t > range then return math.huge end
    -- perpendicular distance = |AP - t*dir|
    local px = apx - t * dir.x
    local pz = apz - t * dir.z
    return math.sqrt(px * px + pz * pz), t
end

-- Count enemy minions within width of a line from 'from' towards 'toDir', up to 'range'
local function CountLineMinions(from, dir, range, width)
    local count = 0
    for i = 1, Game.MinionCount() do
        local m = Game.Minion(i)
        if m and not m.dead and m.team ~= myHero.team then
            local p = {x = m.pos.x, z = m.pos.z}
            local d = PointToRayDistance2D(from, dir, range, p)
            if type(d) == "number" then
                if d <= width then
                    count = count + 1
                end
            else
                local dist = d
                if dist <= width then
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- Find the best aim direction from a position to hit most minions with a line skill
local function BestQLineFrom(from, range, width)
    local bestCount, bestDir = 0, nil
    -- Use each minion direction as candidate
    for i = 1, Game.MinionCount() do
        local m = Game.Minion(i)
        if m and not m.dead and m.team ~= myHero.team then
            local to = {x = m.pos.x - from.x, z = m.pos.z - from.z}
            local dir, len = Normalize2D(to)
            if len > 0 then
                local c = CountLineMinions(from, dir, range, width)
                if c > bestCount then
                    bestCount, bestDir = c, dir
                end
            end
        end
    end
    return bestCount, bestDir
end

-- Optimized helpers for FPS stability
-- Cached enemy minions (2D) to reduce per-tick scanning
local _minionCacheTime, _minionCachePos, _minionCacheRange, _minionCacheList = 0, {x = 0, z = 0}, 0, {}
local function GetEnemyMinions2D(range)
    local now = Game.Timer()
    local hx, hz = myHero.pos.x, myHero.pos.z
    local dx, dz = hx - _minionCachePos.x, hz - _minionCachePos.z
    local moved2 = dx*dx + dz*dz
    local stale = (now - _minionCacheTime) > 0.10 or moved2 > (60*60) or range > (_minionCacheRange - 50)
    if stale then
        local list = {}
        for i = 1, Game.MinionCount() do
            local m = Game.Minion(i)
            if m and not m.dead and m.team ~= myHero.team then
                local mx, mz = m.pos.x, m.pos.z
                local ddx, ddz = mx - hx, mz - hz
                if not range or (ddx*ddx + ddz*ddz) <= (range*range) then
                    list[#list+1] = {x = mx, z = mz, obj = m}
                end
            end
        end
        _minionCacheList = list
        _minionCacheTime = now
        _minionCachePos = {x = hx, z = hz}
        _minionCacheRange = range or 2000
    end
    return _minionCacheList
end

local function BestQLineFromAngles(from, range, width, minions, angleStep)
    local step = angleStep or 30 -- degrees
    local bestCount, bestDirX, bestDirZ = 0, nil, nil
    local w2 = width * width
    for deg = 0, 330, step do
        local rad = math.rad(deg)
        local dirx, dirz = math.cos(rad), math.sin(rad)
        local count = 0
        for i = 1, #minions do
            local p = minions[i]
            local dx = p.x - from.x
            local dz = p.z - from.z
            local t = dx * dirx + dz * dirz
            if t >= 0 and t <= range then
                local px = dx - t * dirx
                local pz = dz - t * dirz
                local perp2 = px * px + pz * pz
                if perp2 <= w2 then
                    count = count + 1
                end
            end
        end
        if count > bestCount then
            bestCount, bestDirX, bestDirZ = count, dirx, dirz
            if bestCount >= 5 then -- early exit for large hits
                break
            end
        end
    end
    return bestCount, bestDirX, bestDirZ
end

local function AnyEnemyHeroesInRange2D(pos2D, range)
    for i = 1, Game.HeroCount() do
        local h = Game.Hero(i)
        if h and h.team ~= myHero.team and not h.dead and h.visible then
            local hp2d = {x = h.pos.x, z = h.pos.z}
            if GetDistance2D(pos2D, hp2d) <= range then
                return true
            end
        end
    end
    return false
end

local function Ready(spell)
    if not spell then return false end
    local spellData = myHero:GetSpellData(spell)
    if not spellData or spellData.level == 0 then return false end
    return spellData.currentCd == 0 and Game.CanUseSpell(spell) == 0
end

local function IsValidTarget(target, range)
    if not target then return false end
    if target.dead or not target.visible or not target.isTargetable then return false end
    if target.team == myHero.team then return false end
    if range and GetDistance(myHero.pos, target.pos) > range then return false end
    return true
end

local function HasQ3()
    local spellData = myHero:GetSpellData(_Q)
    return spellData and spellData.name == "YasuoQ3Wrapper"
end

local function HasEBuff(target)
    -- Robust check: some summoned pets may not expose `.valid`; rely on existence and not dead
    if not target or target.dead then return false end

    local count = target.buffCount or 0
    -- Iterate 0..count-1 safely
    for i = 0, count - 1 do
        local buff = target:GetBuff(i)
        if buff and buff.count and buff.count > 0 and buff.name == "YasuoE" then
            return true
        end
    end
    return false
end

-- Check if Q is ready or will be ready after E dash
-- E resets Q cooldown to 0.5s when hitting a target
local function IsQReadyForEQ()
    local qData = myHero:GetSpellData(_Q)
    if not qData then return false end
    
    local qCooldown = qData.currentCd
    
    -- Q is ready now
    if qCooldown == 0 then return true end
    
    -- Q will be ready after E (E resets Q cd to 0.5s or less)
    -- So if Q cd is <= 0.5s, E will make it ready
    if qCooldown <= 0.5 then return true end
    
    return false
end

-- Additional function from YasuoThePackGod for general buff checking
local function HasBuff(unit, name)
    if not unit then return false end
    local count = unit.buffCount or 0
    for i = 0, count - 1 do
        local buff = unit:GetBuff(i)
        if buff and buff.count and buff.count > 0 and buff.name == name then
            return true, buff.count
        end
    end
    return false
end

local function IsUnderEnemyTurret(position, safetyRange)
    safetyRange = safetyRange or 900
    for i = 1, Game.TurretCount() do
        local turret = Game.Turret(i)
        if turret and turret.isEnemy and not turret.dead then
            local turretPos2D = {x = turret.pos.x, z = turret.pos.z}
            local targetPos2D = {x = position.x, z = position.z}
            if GetDistance2D(targetPos2D, turretPos2D) < safetyRange then
                return true
            end
        end
    end
    return false
end

-- Calculate position after E dash for turret safety check
local function CalculateEPosition(target)
    if not target or not target.pos then return nil end
    
    local heroPos = myHero.pos
    local targetPos = target.pos
    
    -- E dash distance is approximately 475 units, but we land slightly before the target
    local dashDistance = 475 - 50 -- Land 50 units before target
    local direction = (targetPos - heroPos):Normalized()
    local finalPosition = heroPos + (direction * dashDistance)
    
    return {x = finalPosition.x, z = finalPosition.z}
end

local function GetQDamage()
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end
    local baseDamage = {20, 40, 60, 80, 100}
    local adRatio = 1.05
    local totalAD = myHero.totalDamage
    return baseDamage[level] + (totalAD * adRatio)
end

local function GetEDamage()
    local level = myHero:GetSpellData(_E).level
    if level == 0 then return 0 end
    local baseDamage = {60, 70, 80, 90, 100}
    local apRatio = 0.6
    local totalAP = myHero.ap
    return baseDamage[level] + (totalAP * apRatio)
end

-- Prediction Functions - Using DepressivePrediction directly
local function GetPrediction(target, spell)
    if not target or not target.valid then return nil, 0 end
    
    -- Check if DepressivePrediction is properly loaded
    if CheckPredictionSystem() then
        local spellData = {}
        
        -- Dynamic spell data based on Q state
        if spell == "Q" or spell == "Q3" then
            if HasQ3() then
                -- Q3 (tornado) has longer range and different properties
                spellData = {
                    range = SPELL_RANGE.Q3,
                    speed = SPELL_SPEED.Q3,
                    delay = SPELL_DELAY.Q3,
                    radius = SPELL_RADIUS.Q3
                }
            else
                -- Q1/Q2 normal range
                spellData = {
                    range = SPELL_RANGE.Q,
                    speed = SPELL_SPEED.Q,
                    delay = SPELL_DELAY.Q,
                    radius = SPELL_RADIUS.Q
                }
            end
        else
            -- Other spells use direct lookup
            spellData = {
                range = SPELL_RANGE[spell],
                speed = SPELL_SPEED[spell],
                delay = SPELL_DELAY[spell],
                radius = SPELL_RADIUS[spell]
            }
        end
        
        -- Use DepressivePrediction direct API - 2D only
        local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
        
        local unitPos, castPos, timeToHit = _G.DepressivePrediction.GetPrediction(
            target,
            sourcePos2D,
            spellData.speed,
            spellData.delay,
            spellData.radius
        )
        
        if castPos and castPos.x and castPos.z then
            local hitChance = 4 -- Default to HIGH hit chance with DepressivePrediction
            -- Return 2D position only
            return {x = castPos.x, z = castPos.z}, hitChance
        end
    end
    
    -- Fallback prediction - 2D only
    return {x = target.pos.x, z = target.pos.z}, 2
end

-- Main Yasuo Class
class "DepressiveYasuo2"

function DepressiveYasuo2:__init()
    -- Walljump System
    self.walljumpSpots = {}
    self.selectedWalljumpSpot = nil
    self.walljumpExecuting = false
    self.walljumpStep = 0
    self.currentSequence = nil
    self.tempWalljumpPos = nil
    self.walljumpInitialPos = nil -- Track initial position for distance checking
    self.walljumpMovingToInitial = false -- Track if we're moving to initial position
    self.walljumpDelayStartTime = nil -- Track delay timer at initial position
    self.walljumpStartTime = nil -- Track when walljump started
    self.walljumpLastPosition = nil -- Track last known position
    self.walljumpStuckTime = nil -- Track if stuck in same position
    self.walljumpSpellWaitTime = nil -- Track if waiting for spells
    
    -- Cache variables for FPS optimization
    self.lastDrawUpdate = 0
    self.cachedSpellInfo = nil
    
    -- Combo System
    self.comboState = "idle"
    self.comboTarget = nil
    self.comboTimer = 0
    self.lastActionTime = 0
    
    -- Gapcloser System
    self.gapcloseTarget = nil
    self.gapcloseMinion = nil
    
    -- Safety System
    self.turretSafetyEnabled = true
    self.safetyRange = 900
    
    -- Key state tracking for automatic hotkeys
    self.keysPressed = {
        space = false,   -- 32 - Combo
        v = false,       -- 86 - Lane Clear  
        x = false,       -- 88 - Last Hit
        a = false,       -- 65 - Flee
        c = false        -- 67 - Harass
    }
    
    -- Beyblade (E-Q3-Flash) System
    self.beybladeState = "idle" -- idle, executing_beyblade
    self.beybladeTarget = nil
    self.beybladeStep = 0
    self.beybladeTimer = 0

    -- Q3 Animation Cancel
    self.prevHasQ3 = HasQ3()
    self.lastQ3CancelTime = 0
    self.q3CancelLock = false
    self.lastQ3CastStartTime = nil -- track unique cast to avoid duplicate cancels
    
    -- Auto W System
    self.EnemyHeroes = {}
    self.EnemySpells = {}
    self.LastEnemyScan = 0
    self.lastEnemyScanTime = 0
    
    self:LoadMenu()
    self:LoadWalljumpSpots()
    
    -- Callbacks
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("WndMsg", function(msg, wParam) self:OnWndMsg(msg, wParam) end)
    -- Note: No ProcessSpell callback in GoS core; rely on activeSpell polling instead
end

function DepressiveYasuo2:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveYasuo2", name = "Depressive - Yasuo"})
    
    -- Combo System
    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo System"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.combo:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.combo:MenuElement({id = "useR", name = "Use R", value = true})
    self.Menu.combo:MenuElement({id = "minHitChance", name = "Min Hit Chance", value = 3, min = 1, max = 6, step = 1})
    self.Menu.combo:MenuElement({id = "eqCombo", name = "E-Q Combo", value = true})
    self.Menu.combo:MenuElement({id = "smartEChase", name = "Smart E Chase (chain minions)", value = true})
    self.Menu.combo:MenuElement({id = "aggressiveMovement", name = "Aggressive Movement (More E-Q)", value = true})
    self.Menu.combo:MenuElement({id = "movementStyle", name = "Movement Style", drop = {"Balanced", "Aggressive", "Very Aggressive"}, value = 2})
    
    -- Ultimate Settings (inspired by YasuoThePackGod)
    self.Menu:MenuElement({type = MENU, id = "ultimate", name = "Ultimate Settings"})
    self.Menu.ultimate:MenuElement({id = "minEnemiesR", name = "Min Enemies for R", value = 1, min = 1, max = 5, step = 1})
    self.Menu.ultimate:MenuElement({id = "maxHpForR", name = "Max HP% to R Single Target", value = 60, min = 20, max = 100, step = 5})
    self.Menu.ultimate:MenuElement({id = "allow1v1R", name = "Allow R in 1v1 if Killable", value = true})
    self.Menu.ultimate:MenuElement({id = "killableThreshold", name = "Killable HP Threshold %", value = 35, min = 15, max = 60, step = 5})
    self.Menu.ultimate:MenuElement({id = "prioritizeADC", name = "Prioritize ADC/Mid for R", value = true})
    self.Menu.ultimate:MenuElement({id = "teamfightR", name = "Use R in Teamfights (2+ enemies)", value = true})
    
    -- Gapcloser System
    self.Menu:MenuElement({type = MENU, id = "gapcloser", name = "Gapcloser System"})
    self.Menu.gapcloser:MenuElement({id = "enabled", name = "Enable Gapcloser", value = true})
    self.Menu.gapcloser:MenuElement({id = "maxRange", name = "Max Gapcloser Range", value = 1200, min = 600, max = 1500, step = 50})
    self.Menu.gapcloser:MenuElement({id = "useMinions", name = "Use Minions for Gapclosing", value = true})
    self.Menu.gapcloser:MenuElement({id = "checkTurret", name = "Check Turret Safety", value = true})
    
    -- Walljump System
    self.Menu:MenuElement({type = MENU, id = "walljump", name = "Walljump System"})
    self.Menu.walljump:MenuElement({id = "enabled", name = "Enable Walljump", value = true})
    self.Menu.walljump:MenuElement({id = "executeKey", name = "Execute Walljump", key = string.byte("Z"), toggle = false})
    self.Menu.walljump:MenuElement({id = "cancelKey", name = "Cancel Walljump", key = string.byte("B"), toggle = false})
    self.Menu.walljump:MenuElement({id = "selectionRange", name = "Selection Range", value = 300, min = 100, max = 500, step = 50})
    
    -- Turret Safety
    self.Menu:MenuElement({type = MENU, id = "safety", name = "Turret Safety"})
    self.Menu.safety:MenuElement({id = "enabled", name = "Enable Turret Safety", value = true})
    self.Menu.safety:MenuElement({id = "range", name = "Safety Range", value = 900, min = 700, max = 1100, step = 50})
    self.Menu.safety:MenuElement({id = "allowLowHP", name = "Allow under turret if enemy HP < %", value = 20, min = 10, max = 40, step = 5})
    
    -- Harass
    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useE", name = "Use E on minions", value = true})
    self.Menu.harass:MenuElement({id = "useQ", name = "Use Q after E", value = true})
    
    -- Clear
    self.Menu:MenuElement({type = MENU, id = "clear", name = "Lane Clear"})
    self.Menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.clear:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.clear:MenuElement({id = "fluidEQ", name = "Fluid E-Q Clear (more aggressive)", value = true})
    self.Menu.clear:MenuElement({id = "stackQ", name = "Stack Q on minions", value = true})
    self.Menu.clear:MenuElement({id = "allowEUnderTurret", name = "Allow E under Enemy Turret", value = false})
    self.Menu.clear:MenuElement({id = "smartEClear", name = "Smart E Clear (reposition with E)", value = true})
    self.Menu.clear:MenuElement({id = "qLasthit", name = "Use Q to last-hit (freeze-friendly)", value = true})
    self.Menu.clear:MenuElement({id = "avoidSmartENearEnemy", name = "Avoid Smart E if enemy hero within", value = 1200, min = 800, max = 2000, step = 100})
    self.Menu.clear:MenuElement({id = "useQ3InClear", name = "Use Q3 in clear if 3+ minions", value = false})
    
    -- Drawing
    self.Menu:MenuElement({type = MENU, id = "drawing", name = "Drawing"})
    self.Menu.drawing:MenuElement({id = "walljumpSpots", name = "Draw Walljump Spots", value = true})
    self.Menu.drawing:MenuElement({id = "ranges", name = "Draw Ranges", value = true})
    self.Menu.drawing:MenuElement({id = "prediction", name = "Draw Predictions", value = true})
    self.Menu.drawing:MenuElement({id = "status", name = "Draw Status", value = true})
    
    -- Q3 Animation Cancel
    self.Menu:MenuElement({type = MENU, id = "q3cancel", name = "Q3 Animation Cancel"})
    self.Menu.q3cancel:MenuElement({id = "enabled", name = "Enable Q3 cancel", value = true})
    self.Menu.q3cancel:MenuElement({id = "useCtrl3", name = "Use Ctrl+3 (dance) to cancel", value = true})
    self.Menu.q3cancel:MenuElement({id = "delay", name = "Delay after cast (ms)", value = 35, min = 0, max = 120, step = 5})
    
    -- Beyblade System (E-Q3-Flash Combo)
    self.Menu:MenuElement({type = MENU, id = "beyblade", name = "Beyblade (E-Q3-Flash)"})
    self.Menu.beyblade:MenuElement({id = "enabled", name = "Enable Beyblade Combo", value = true})
    self.Menu.beyblade:MenuElement({id = "key", name = "Beyblade Key", key = string.byte("T"), toggle = false})
    self.Menu.beyblade:MenuElement({id = "maxRange", name = "Max Target Range", value = 1100, min = 600, max = 1200, step = 50})
    self.Menu.beyblade:MenuElement({id = "flashRange", name = "Flash Range", value = 450, min = 350, max = 450, step = 25})
    self.Menu.beyblade:MenuElement({id = "autoFlash", name = "Auto Flash after Q3", value = true})
    self.Menu.beyblade:MenuElement({id = "requireQ3", name = "Only use when Q3 ready", value = true})
    self.Menu.beyblade:MenuElement({id = "minHitChance", name = "Min Q3 Hit Chance", value = 3, min = 1, max = 6, step = 1})

    -- Auto W (Wind Wall)
    self.Menu:MenuElement({type = MENU, id = "autoW", name = "Auto W (Wind Wall)"})
    self.Menu.autoW:MenuElement({id = "enabled", name = "Enable Auto W", value = true})
    self.Menu.autoW:MenuElement({id = "blockSkillshots", name = "Block Skillshots", value = true})
    self.Menu.autoW:MenuElement({id = "blockTargeted", name = "Block Targeted Spells", value = true})
    self.Menu.autoW:MenuElement({id = "blockUltimates", name = "Block Ultimates", value = true})
    self.Menu.autoW:MenuElement({id = "reactionTime", name = "Reaction Time (ms)", value = 250, min = 0, max = 500, step = 25})
    self.Menu.autoW:MenuElement({id = "lowHPProtection", name = "Low HP Protection (<20%)", value = true})

    -- Performance
    self.Menu:MenuElement({type = MENU, id = "performance", name = "Performance"})
    self.Menu.performance:MenuElement({id = "lowFPSMode", name = "Low FPS Mode", value = true})
    self.Menu.performance:MenuElement({id = "scanRange", name = "Scan Range (units)", value = 1500, min = 1000, max = 2500, step = 100})
    self.Menu.performance:MenuElement({id = "angleStep", name = "Angle Step for Q lines (deg)", value = 30, min = 15, max = 60, step = 5})
    self.Menu.performance:MenuElement({id = "heavyInterval", name = "Heavy Eval Interval (ms)", value = 120, min = 60, max = 240, step = 10})
    self.Menu.performance:MenuElement({id = "maxCandidates", name = "Max Candidates per Heavy Eval", value = 12, min = 6, max = 24, step = 2})
    self.Menu.performance:MenuElement({id = "throttleDrawPred", name = "Throttle Draw Prediction", value = true})
    self.Menu.performance:MenuElement({id = "drawPredInterval", name = "Draw Pred Interval (ms)", value = 150, min = 60, max = 300, step = 10})
end

-- ProcessSpell: detect manual Q3 casts and trigger animation cancel
function DepressiveYasuo2:OnProcessSpell(unit, spell)
    if not unit or not unit.isMe or not spell or not spell.name then return end
    if not self.Menu or not self.Menu.q3cancel or not self.Menu.q3cancel.enabled:Value() then return end
    if self.walljumpExecuting or (self.beybladeState and self.beybladeState ~= "idle") then return end

    -- Normalize name and look for Yasuo Q3 specifically
    local sname = string.lower(spell.name)
    -- Match broad patterns to be robust across wrappers: contains both 'yasuo' and 'q3'
    if sname:find("yasuo") and sname:find("q3") then
        if not self.q3CancelLock then
            self.q3CancelLock = true
            local delaySec = (self.Menu.q3cancel.delay:Value() or 35) / 1000
            DelayAction(function()
                self:PerformQ3CancelAction()
                self.lastQ3CancelTime = Game.Timer()
            end, delaySec)
        end
    end
end

function DepressiveYasuo2:LoadWalljumpSpots()
    -- Default walljump spots for Summoner's Rift - 2D coordinates
    self.walljumpSpots = {
        -- Custom Raptors Walljump
        {
            name = "Raptor Tower",
            position = {x = 7194, z = 5136},
            sequence = {
                {type = "cast", spell = _E, position = {x = 6973, z = 5372}, delay = 0.1}, -- E a posición exacta especificada
                {type = "cast", spell = _Q, position = {x = 6973, z = 5372}, delay = 0.15}, -- Q en la misma posición (EQ combo)
                {type = "cast", spell = _E, position = {x = 6811, z = 5528}, delay = 0.4} -- E final a posición exacta especificada
            }
        },
        -- Custom Multi-Position Walljump
        {
            name = "Raptor Tower",
            position = {x = 7638, z = 9828}, -- Posición inicial (Custom Spot 2)
            sequence = {
                {type = "cast", spell = _E, position = {x = 7856, z = 9630}, delay = 0.1}, -- E a posición 3
                {type = "cast", spell = _Q, position = {x = 7856, z = 9630}, delay = 0.15}, -- Q en posición 3 (EQ combo)
                {type = "cast", spell = _E, position = {x = 7997, z = 9486}, delay = 0.4} -- E final a posición 4
            }
        },
        -- W Start Combo (Updated from new recording)
        {
            name = "Bait Enemy",
            position = {x = 8230, z = 3140}, -- Posición inicial
            sequence = {
                {type = "cast", spell = _E, position = {x = 8272, z = 2694}, delay = 0.1}, -- E inicial
                {type = "cast", spell = _Q, position = {x = 8272, z = 2694}, delay = 0.2}, -- Q en la misma posición (EQ combo)
                {type = "click", position = {x = 8640, z = 2644}, delay = 0.4}, -- Click de posicionamiento
                {type = "cast", spell = _E, position = {x = 8488, z = 2740}, delay = 0.6} -- E final después de 0.5s
            }
        },
        {
            name = "Bait Enemy",
            position = {x = 6611, z = 11706}, -- Posición inicial
            sequence = {
                {type = "cast", spell = _E, position = {x = 6561, z = 12153}, delay = 0.1}, -- E inicial (EQ combo)
                {type = "cast", spell = _Q, position = {x = 6561, z = 12153}, delay = 0.2}, -- Q en la misma posición (EQ combo)
                {type = "click", position = {x = 6158, z = 12238}, delay = 0.4}, -- Click de posicionamiento
                {type = "cast", spell = _E, position = {x = 6346, z = 12148}, delay = 0.7} -- E final
            }
        },
        {
            name = "River Escape",
            position = {x = 7208, z = 5975}, -- Posición inicial
            sequence = {
                {type = "cast", spell = _E, position = {x = 6957, z = 5599}, delay = 0.1}, -- E inicial (EQ combo)
                {type = "cast", spell = _Q, position = {x = 6957, z = 5599}, delay = 0.2}, -- Q en la misma posición (EQ combo)
                {type = "click", position = {x = 6730, z = 5433}, delay = 0.2}, -- Click de posicionamiento (0.2s como especificaste)
                {type = "cast", spell = _E, position = {x = 6780, z = 5543}, delay = 0.4} -- E final
            }
        },
        {
            name = "Gromp Jump",
            position = {x = 2267, z = 8410}, -- Posición inicial
            sequence = {
                {type = "cast", spell = _E, position = {x = 2095, z = 8428}, delay = 0.1} -- E directo al gromp
            }
        },
    }
end

function DepressiveYasuo2:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    -- Auto W System - Simple and direct
    if self.Menu.autoW and self.Menu.autoW.enabled and self.Menu.autoW.enabled:Value() and Ready(_W) then
        self:AutoWindWall()
    end
    
    -- Cancel walljump
    if self.Menu.walljump.cancelKey:Value() then
        self:CancelWalljump()
    end
    
    -- Execute walljump directamente al más cercano al mouse (tecla Z)
    if self.Menu.walljump.executeKey:Value() and not self.walljumpExecuting then
        self:ExecuteClosestWalljumpToMouse()
    end
    
    -- Execute ongoing walljump
    if self.walljumpExecuting then
        self:CheckWalljumpStatus()
        self:ExecuteWalljumpSequence()
    end
    
    -- Beyblade System (E-Q3-Flash Combo)
    if self.Menu.beyblade.enabled:Value() and self.Menu.beyblade.key:Value() then
        self:HandleBeyblade()
    end
    
    -- Execute ongoing beyblade combo
    if self.beybladeState ~= "idle" then
        self:ExecuteBeybladeCombo()
    end
    
    -- Automatic hotkeys detection
    -- Space - Combo
    if self.keysPressed.space then
        self:Combo()
    end
    
    -- V - Lane Clear
    if self.keysPressed.v then
        self:Clear()
    end
    
    -- X - Last Hit
    if self.keysPressed.x then
        self:LastHit()
    end
    
    -- A - Flee
    if self.keysPressed.a then
        self:Flee()
    end
    
    -- C - Harass
    if self.keysPressed.c then
        self:Harass()
    end

    -- Q3 animation cancel handler
    -- 1) Detect via activeSpell (no ProcessSpell callback available)
    self:DetectQ3ActiveSpell()
    -- 2) Fallback detection via Q state transition
    self:HandleQ3Cancel()
end

-- Poll-based Q3 cast detection using activeSpell
function DepressiveYasuo2:DetectQ3ActiveSpell()
    if not self.Menu or not self.Menu.q3cancel or not self.Menu.q3cancel.enabled:Value() then return end
    if self.q3CancelLock then return end
    if self.walljumpExecuting or (self.beybladeState and self.beybladeState ~= "idle") then return end

    local as = myHero.activeSpell
    if as and as.valid then
        local sname = as.name and string.lower(as.name) or ""
        -- robust match for Yasuo Q3
        if sname:find("yasuo") and sname:find("q3") then
            local startT = as.startTime or 0
            if not self.lastQ3CastStartTime or self.lastQ3CastStartTime ~= startT then
                self.lastQ3CastStartTime = startT
                self.q3CancelLock = true
                local delaySec = (self.Menu.q3cancel.delay:Value() or 35) / 1000
                DelayAction(function()
                    self:PerformQ3CancelAction()
                    self.lastQ3CancelTime = Game.Timer()
                end, delaySec)
            end
        end
    end
    -- unlock when Q cooldown ends
    local qData = myHero:GetSpellData(_Q)
    if self.q3CancelLock and qData and qData.currentCd == 0 then
        self.q3CancelLock = false
    end
end

function DepressiveYasuo2:Draw()
    if myHero.dead then return end
    
    local currentTimer = Game.Timer()
    
    -- Draw walljump spots - 2D only
    if self.Menu.drawing.walljumpSpots:Value() and #self.walljumpSpots > 0 then
        for i, spot in ipairs(self.walljumpSpots) do
            local color = Draw.Color(255, 255, 255, 0)
            local spotPos2D = Vector(spot.position.x, myHero.pos.y, spot.position.z)
            Draw.Circle(spotPos2D, 100, 3, color)
            Draw.Text(spot.name, 12, spotPos2D:To2D(), color)
        end
    end
    
    -- Draw selection range for walljumps - 2D circle
    if self.Menu.drawing.ranges:Value() then
        Draw.Circle(myHero.pos, self.Menu.walljump.selectionRange:Value(), 2, Draw.Color(100, 255, 255, 255))
    end
    
    -- Draw ranges - 2D circles
    if self.Menu.drawing.ranges:Value() then
        if Ready(_Q) then
            local range = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
            Draw.Circle(myHero.pos, range, 2, Draw.Color(100, 0, 255, 0))
        end
        
        if Ready(_E) then
            Draw.Circle(myHero.pos, SPELL_RANGE.E, 2, Draw.Color(100, 255, 0, 255))
        end
    end
    
    -- Draw status
    if self.Menu.drawing.status:Value() then
        local statusText = "Ready"
        
        if self.beybladeState ~= "idle" then
            statusText = "Executing Beyblade: Step " .. self.beybladeStep
        elseif self.walljumpExecuting then
            statusText = "Executing Walljump: Step " .. self.walljumpStep
        elseif self.comboState ~= "idle" then
            statusText = "Combo State: " .. self.comboState
        end
        
        Draw.Text(statusText, 16, 100, 100, Draw.Color(255, 255, 255, 255))
        
        -- Show prediction system status
        local predStatus = CheckPredictionSystem() and "DepressivePrediction: LOADED" or "DepressivePrediction: NOT LOADED"
        Draw.Text(predStatus, 14, 100, 120, CheckPredictionSystem() and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 0, 0))
        
        if not self.lastDrawUpdate or currentTimer - self.lastDrawUpdate > 0.1 then
            self.lastDrawUpdate = currentTimer
            self.cachedSpellInfo = {
                q = HasQ3() and "Q3 Ready" or string.format("Q: %.1f", myHero:GetSpellData(_Q).currentCd),
                e = string.format("E: %.1f", myHero:GetSpellData(_E).currentCd),
                r = string.format("R: %.1f", myHero:GetSpellData(_R).currentCd)
            }
        end
        
        if self.cachedSpellInfo then
            Draw.Text(self.cachedSpellInfo.q, 14, 100, 140, Draw.Color(255, 255, 255, 255))
            Draw.Text(self.cachedSpellInfo.e, 14, 100, 155, Draw.Color(255, 255, 255, 255))
            Draw.Text(self.cachedSpellInfo.r, 14, 100, 170, Draw.Color(255, 255, 255, 255))
        end
    end
    
    -- Predictions
    if self.Menu.drawing.prediction:Value() then
        local throttle = self.Menu.performance and self.Menu.performance.throttleDrawPred:Value()
        local interval = (self.Menu.performance and self.Menu.performance.drawPredInterval:Value() or 150) / 1000
        local now = Game.Timer()
        if not throttle or now - (self.lastDrawUpdate or 0) >= interval then
            for i = 1, Game.HeroCount() do
                local hero = Game.Hero(i)
                if IsValidTarget(hero, 800) then
                    local pred, hitChance = GetPrediction(hero, "Q")
                    if pred and hitChance >= self.Menu.combo.minHitChance:Value() then
                        local predPos2D = Vector(pred.x, myHero.pos.y, pred.z)
                        Draw.Circle(predPos2D, 50, 3, Draw.Color(255, 0, 255, 0))
                    end
                end
            end
            self.lastDrawUpdate = now
        end
    end
end

function DepressiveYasuo2:OnWndMsg(msg, wParam)
    -- Handle automatic hotkeys
    if msg == KEY_DOWN then
        if wParam == 32 then -- Space key
            self.keysPressed.space = true
        elseif wParam == 81 then -- Q key
            -- If player manually presses Q while holding Q3, schedule the cancel
            if self.Menu and self.Menu.q3cancel and self.Menu.q3cancel.enabled:Value() then
                if HasQ3() and not self.q3CancelLock and not self.walljumpExecuting and (not self.beybladeState or self.beybladeState == "idle") then
                    self.q3CancelLock = true
                    local delaySec = (self.Menu.q3cancel.delay:Value() or 35) / 1000
                    DelayAction(function()
                        self:PerformQ3CancelAction()
                        self.lastQ3CancelTime = Game.Timer()
                    end, delaySec)
                end
            end
        elseif wParam == 86 then -- V key
            self.keysPressed.v = true
        elseif wParam == 88 then -- X key
            self.keysPressed.x = true
        elseif wParam == 65 then -- A key
            self.keysPressed.a = true
        elseif wParam == 67 then -- C key
            self.keysPressed.c = true
        end
    elseif msg == KEY_UP then
        if wParam == 32 then -- Space key
            self.keysPressed.space = false
        elseif wParam == 86 then -- V key
            self.keysPressed.v = false
        elseif wParam == 88 then -- X key
            self.keysPressed.x = false
        elseif wParam == 65 then -- A key
            self.keysPressed.a = false
        elseif wParam == 67 then -- C key
            self.keysPressed.c = false
        end
    end
end

function DepressiveYasuo2:ExecuteClosestWalljumpToMouse()
    if self.walljumpExecuting then return end
    
    local mousePos = Game.mousePos()
    local mousePos2D = {x = mousePos.x, z = mousePos.z}
    local closestSpot = nil
    local closestDistance = math.huge
    local maxRange = self.Menu.walljump.selectionRange:Value()
    
    -- Buscar el walljump más cercano al mouse dentro del rango
    for i, spot in ipairs(self.walljumpSpots) do
        local spotPos2D = {x = spot.position.x, z = spot.position.z}
        local distance = GetDistance2D(mousePos2D, spotPos2D)
        
        if distance < maxRange and distance < closestDistance then
            closestDistance = distance
            closestSpot = i
        end
    end
    
    -- Si encontramos un walljump cercano al mouse, ejecutarlo directamente
    if closestSpot then
        self.selectedWalljumpSpot = closestSpot
        self:StartWalljump()
    end
end

function DepressiveYasuo2:AddWalljumpSpot(position)
    local spotName = "Custom Spot " .. (#self.walljumpSpots + 1)
    local newSpot = {
        name = spotName,
        position = {x = position.x, z = position.z},
        sequence = {
            {type = "move", position = {x = position.x - 150, z = position.z - 150}, delay = 0.1},
            {type = "cast", spell = _E, target = "minion", delay = 0.2},
            {type = "move", position = {x = position.x + 150, z = position.z + 150}, delay = 0.1}
        }
    }
    
    table.insert(self.walljumpSpots, newSpot)
end

function DepressiveYasuo2:StartWalljump()
    if not self.selectedWalljumpSpot or self.walljumpExecuting then return end
    
    local spot = self.walljumpSpots[self.selectedWalljumpSpot]
    if not spot then return end
    
    -- ALWAYS move to the initial position first, regardless of current position
    local initialPos = Vector(spot.position.x, myHero.pos.y, spot.position.z)
    Control.Move(initialPos)
    
    -- Store initial position for distance checking
    self.walljumpInitialPos = {x = spot.position.x, z = spot.position.z}
    self.walljumpMovingToInitial = true
    
    self.walljumpExecuting = true
    self.walljumpStep = 1
    self.currentSequence = spot.sequence
    self.lastActionTime = Game.Timer()
    
    -- Initialize verification variables
    self.walljumpStartTime = Game.Timer()
    self.walljumpLastPosition = {x = myHero.pos.x, z = myHero.pos.z}
    self.walljumpStuckTime = nil
end

function DepressiveYasuo2:IsSafeToEInClear(target)
    if not target then return false end
    
    -- Si la opción de permitir E bajo torre está activada, no verificar seguridad
    if self.Menu.clear.allowEUnderTurret:Value() then
        return true
    end
    
    -- Calcular la posición después del dash E
    local ePosition = CalculateEPosition(target)
    if not ePosition then return false end
    
    -- Verificar si la posición después del E está bajo torre enemiga
    local safetyRange = self.Menu.safety.range:Value()
    return not IsUnderEnemyTurret(ePosition, safetyRange)
end

function DepressiveYasuo2:IsSafeToE(target)
    if not target then return false end
    
    -- Para combos normales, siempre usar el sistema de seguridad general
    if not self.Menu.safety.enabled:Value() then
        return true
    end
    
    -- Calcular la posición después del dash E
    local ePosition = CalculateEPosition(target)
    if not ePosition then return false end
    
    -- Verificar si la posición después del E está bajo torre enemiga
    local safetyRange = self.Menu.safety.range:Value()
    local isUnderTurret = IsUnderEnemyTurret(ePosition, safetyRange)
    
    -- Si está bajo torre, verificar si el enemigo tiene poca vida para permitir la jugada
    if isUnderTurret and target.health then
        local allowLowHP = self.Menu.safety.allowLowHP:Value()
        local hpPercent = (target.health / target.maxHealth) * 100
        return hpPercent <= allowLowHP
    end
    
    return not isUnderTurret
end

function DepressiveYasuo2:BeybladeCombo()
    local target = self:GetBestTarget()
    if not target or not Ready(_E) or not Ready(_Q) then return end

    local flashSlot = self:GetSummonerSpellSlot("SummonerFlash")
    if not flashSlot or not Ready(flashSlot) then return end

    self.comboState = "beyblade"
    self.comboTarget = target

    -- E to minion or target
    local eTarget = self:GetBestMinionForEQ(target) or target

    if not HasEBuff(eTarget) and GetDistance(myHero.pos, eTarget.pos) <= SPELL_RANGE.E then
        Control.CastSpell(HK_E, eTarget)

        DelayAction(function()
            if Ready(_Q) then
                Control.CastSpell(HK_Q)

                DelayAction(function()
                    if Ready(flashSlot) then
                        local flashPos = myHero.pos:Extended(target.pos, 400)
                        Control.CastSpell(flashSlot, flashPos)

                        DelayAction(function()
                            if Ready(_Q) and HasQ3() then
                                local pred, hitChance = GetPrediction(target, "Q3")
                                if pred and hitChance >= 2 then
                                    Control.CastSpell(HK_Q, pred)
                                else
                                    Control.CastSpell(HK_Q, target.pos)
                                end

                                DelayAction(function()
                                    if Ready(_R) and self:CanUseUltimate(target) then
                                        Control.CastSpell(HK_R)
                                    end
                                    self.comboState = "idle"
                                end, 0.3)
                            end
                        end, 0.2)
                    end
                end, 0.15)
            end
        end, 0.1)
    end
end

function DepressiveYasuo2:CheckWalljumpStatus()
    if not self.walljumpExecuting then return end

    local currentTime = Game.Timer()

    -- Global timeout for a walljump attempt
    if self.walljumpStartTime and currentTime - self.walljumpStartTime > 6 then
        self:ResetWalljumpState("Walljump timeout")
        return
    end

    -- Stuck detection (no movement for too long)
    local currPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    if self.walljumpLastPosition then
        local dist = GetDistance2D(currPos2D, self.walljumpLastPosition)
        if dist < 5 then
            if not self.walljumpStuckTime then
                self.walljumpStuckTime = currentTime
            elseif currentTime - self.walljumpStuckTime > 1.5 then
                self:ResetWalljumpState("Stuck in place")
                return
            end
        else
            self.walljumpLastPosition = {x = currPos2D.x, z = currPos2D.z}
            self.walljumpStuckTime = nil
        end
    else
        self.walljumpLastPosition = {x = currPos2D.x, z = currPos2D.z}
    end

    -- Check if spells are not available when they should be
    if self.currentSequence and self.walljumpStep <= #self.currentSequence then
        local action = self.currentSequence[self.walljumpStep]
        if action and action.type == "cast" then
            if action.spell == _E and not Ready(_E) then
                -- E should be available for walljump, if not available for too long, reset
                if not self.walljumpSpellWaitTime then
                    self.walljumpSpellWaitTime = currentTime
                elseif currentTime - self.walljumpSpellWaitTime > 5 then
                    self:ResetWalljumpState("E spell not available")
                    return
                end
            elseif action.spell == _Q and not Ready(_Q) then
                -- Q should be available, if not available for too long, reset
                if not self.walljumpSpellWaitTime then
                    self.walljumpSpellWaitTime = currentTime
                elseif currentTime - self.walljumpSpellWaitTime > 5 then
                    self:ResetWalljumpState("Q spell not available")
                    return
                end
            else
                -- Reset spell wait time if casting other type or spell ready
                self.walljumpSpellWaitTime = nil
            end
        else
            -- Reset spell wait time if not casting
            self.walljumpSpellWaitTime = nil
        end
    end
end

function DepressiveYasuo2:ResetWalljumpState(reason)
    if reason then
        -- Optional: you can remove this print if you don't want debug info
        -- print("Walljump reset: " .. reason)
    end
    
    self.walljumpExecuting = false
    self.walljumpStep = 0
    self.currentSequence = nil
    self.selectedWalljumpSpot = nil
    self.walljumpInitialPos = nil
    self.walljumpMovingToInitial = false
    self.walljumpDelayStartTime = nil
    self.walljumpStartTime = nil
    self.walljumpLastPosition = nil
    self.walljumpStuckTime = nil
    self.walljumpSpellWaitTime = nil
end

function DepressiveYasuo2:ExecuteWalljumpSequence()
    if not self.currentSequence or self.walljumpStep > #self.currentSequence then
        self:CompleteWalljump()
        return
    end
    
    -- Check if we're still moving to initial position
    if self.walljumpMovingToInitial and self.walljumpInitialPos then
        local currentPos2D = {x = myHero.pos.x, z = myHero.pos.z}
        local distanceToInitial = GetDistance2D(currentPos2D, self.walljumpInitialPos)
        
        if distanceToInitial <= 15 then
            -- First time reaching position - set delay timer
            if not self.walljumpDelayStartTime then
                self.walljumpDelayStartTime = Game.Timer()
            end
            
            local currentTime = Game.Timer()
            if currentTime - self.walljumpDelayStartTime >= 0 then -- Sin delay
                self.walljumpMovingToInitial = false
                self.walljumpDelayStartTime = nil
                self.lastActionTime = Game.Timer() -- Reset timer to start sequence
            else
                -- Still waiting, don't execute sequence yet
                return
            end
        else
            -- Still moving to initial position, reset delay timer if it was set
            self.walljumpDelayStartTime = nil
            return
        end
    end
    
    local currentTime = Game.Timer()
    local action = self.currentSequence[self.walljumpStep]
    
    -- Frame-perfect timing
    if currentTime - self.lastActionTime >= action.delay then
        if action.type == "move" then
            local movePos2D = Vector(action.position.x, myHero.pos.y, action.position.z)
            Control.Move(movePos2D)
            
        elseif action.type == "cast" then
            if action.spell == _E then
                if action.position then
                    -- Cast E to specific position
                    local ePos2D = Vector(action.position.x, myHero.pos.y, action.position.z)
                    Control.CastSpell(HK_E, ePos2D)
                else
                    -- Cast E to target
                    local target = self:FindWalljumpTarget(action.target)
                    if target and Ready(_E) then
                        Control.CastSpell(HK_E, target)
                    end
                end
            elseif action.spell == _W then
                if Ready(_W) then
                    -- Check if there's a specific position for W cast
                    if action.position then
                        local wPos2D = Vector(action.position.x, myHero.pos.y, action.position.z)
                        Control.CastSpell(HK_W, wPos2D)
                    else
                        Control.CastSpell(HK_W)
                    end
                end
            elseif action.spell == _Q then
                if Ready(_Q) then
                    -- Check if there's a specific position for Q cast
                    if action.position then
                        local qPos2D = Vector(action.position.x, myHero.pos.y, action.position.z)
                        Control.CastSpell(HK_Q, qPos2D)
                    else
                        Control.CastSpell(HK_Q)
                    end
                end
            end
        elseif action.type == "click" then
            -- Move to click position instead of using mouse events
            local clickPos2D = Vector(action.position.x, myHero.pos.y, action.position.z)
            Control.Move(clickPos2D)
        end
        
        self.walljumpStep = self.walljumpStep + 1
        self.lastActionTime = currentTime
    end
end

function DepressiveYasuo2:FindWalljumpTarget(targetType)
    if targetType == "minion" then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E and not HasEBuff(minion) then
                    return minion
                end
            end
        end
    elseif targetType == "krug" or targetType == "raptor" then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team == 300 and not minion.dead then -- Jungle monsters
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E and not HasEBuff(minion) then
                    if targetType == "krug" and minion.charName:find("Krug") then
                        return minion
                    elseif targetType == "raptor" and minion.charName:find("Raptor") then
                        return minion
                    end
                end
            end
        end
    end
    return nil
end

function DepressiveYasuo2:CompleteWalljump()
    -- Add 0.5 second delay at exact position to prevent return movement
    DelayAction(function()
        self:ResetWalljumpState("Walljump completed successfully")
    end, 0.5)
end

function DepressiveYasuo2:CancelWalljump()
    if self.walljumpExecuting then
        self:ResetWalljumpState("Walljump cancelled by user")
    end
end

-- Combo Functions
function DepressiveYasuo2:Combo()
    local target = self:GetBestTarget()
    if not target then 
        return 
    end
    
    -- Auto stack Q when not in combat (priority system)
    if not self:IsInCombat() then
        self:StackQ()
        return
    end
    
    -- Check Q readiness and state
    local qSpellData = myHero:GetSpellData(_Q)
    local qReady = Ready(_Q)
    local qWillBeReadyAfterE = IsQReadyForEQ() -- Use the new helper function
    local hasQ3 = HasQ3()
    
    -- Get positions and distances
    local basicAttackRange = myHero.range + myHero.boundingRadius + target.boundingRadius
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local distanceToTarget = GetDistance2D(heroPos2D, targetPos2D)
    local isChasing = self:IsChasingTarget(target)
    
    -- PRIORITY 1: Ultimate combo (advanced airborne detection)
    if self.Menu.combo.useR:Value() and Ready(_R) then
        -- Check for knocked up enemies in range
        local knockedUpCount = self:CountKnockedUpEnemies(SPELL_RANGE.R, myHero.pos)
        local minEnemiesRequired = self.Menu.ultimate.minEnemiesR:Value()
        
        -- 1v1 Logic: Allow R on single target if they are killable
        local canUseR1v1 = false
        if knockedUpCount == 1 and self.Menu.ultimate.allow1v1R:Value() then
            local singleTarget = self:GetKnockedUpTarget()
            if singleTarget and self:IsTargetKillableWithR(singleTarget) then
                canUseR1v1 = true
            end
        end
        
        if knockedUpCount >= minEnemiesRequired or canUseR1v1 then
            -- Find the best target to R (prioritize low HP or multiple enemies)
            local bestRTarget = nil
            local bestScore = 0
            
            for i = 1, Game.HeroCount() do
                local enemy = Game.Hero(i)
                if IsValidTarget(enemy, SPELL_RANGE.R) and self:CanUseUltimate(enemy) then
                    local score = 100 -- Base score
                    local hpPercent = enemy.health / enemy.maxHealth
                    
                    -- HIGHEST PRIORITY: Killable targets (1v1 logic)
                    if self:IsTargetKillableWithR(enemy) then
                        score = score + 1000 -- Massive priority for killable targets
                    end
                    
                    -- For single target: check HP threshold (unless killable)
                    if knockedUpCount == 1 and hpPercent > (self.Menu.ultimate.maxHpForR:Value() / 100) and not self:IsTargetKillableWithR(enemy) then
                        score = 0 -- Don't use R on high HP single targets unless killable
                    else
                        -- Prioritize low HP enemies (higher chance to kill)
                        if hpPercent < 0.3 then
                            score = score + 200
                        elseif hpPercent < 0.5 then
                            score = score + 100
                        end
                        
                        -- Bonus for multiple enemies nearby (teamfight)
                        if self.Menu.ultimate.teamfightR:Value() then
                            local nearbyEnemies = self:CountKnockedUpEnemies(400, enemy.pos)
                            if nearbyEnemies >= 2 then
                                score = score + (nearbyEnemies * 75)
                            end
                        end
                        
                        -- Prioritize ADC and Mid laners
                        if self.Menu.ultimate.prioritizeADC:Value() and self:IsHighPriorityTarget(enemy) then
                            score = score + 100
                        end
                    end
                    
                    if score > bestScore and score > 0 then
                        bestScore = score
                        bestRTarget = enemy
                    end
                end
            end
            
            if bestRTarget then
                Control.CastSpell(HK_R, bestRTarget)
                return
            end
        end
    end
    
    -- PRIORITY 2: Q3 Tornado (highest priority damage spell)
    if self.Menu.combo.useQ:Value() and qReady and hasQ3 then
        local q3Pred, q3Chance = GetPrediction(target, "Q3")
        if q3Pred and q3Chance >= self.Menu.combo.minHitChance:Value() and distanceToTarget <= SPELL_RANGE.Q3 then
            Control.CastSpell(HK_Q, Vector(q3Pred.x, myHero.pos.y, q3Pred.z))
            return
        end
    end
    
    -- PRIORITY 3: E-Q3 Combo (gap close into tornado) - SOLO DIRECTO AL ENEMIGO
    if hasQ3 and qReady and Ready(_E) and isChasing and distanceToTarget > SPELL_RANGE.Q3 and distanceToTarget <= SPELL_RANGE.E then
        -- Con Q3 cargada, SOLO usar E directo al target, NO a minions
        if not HasEBuff(target) then
            if self:IsSafeToE(target) then
                Control.CastSpell(HK_E, target)
                DelayAction(function()
                    if Ready(_Q) and HasQ3() then
                        local pred, chance = GetPrediction(target, "Q3")
                        if pred and chance >= 2 then
                            Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                        end
                    end
                end, 0.1)
                return
            end
        end
    end
    
    -- PRIORITY 4: Advanced E-Q Combo (standard combo) - SOLO si NO tienes Q3
    -- CRITICAL: Only use E if Q is ready or will be ready after E (cd <= 0.5s)
    if self.Menu.combo.useE:Value() and self.Menu.combo.useQ:Value() and Ready(_E) and isChasing and qWillBeReadyAfterE and not hasQ3 then
        -- Direct E-Q on target
        if not HasEBuff(target) and distanceToTarget <= SPELL_RANGE.E and self:IsSafeToE(target) then
            Control.CastSpell(HK_E, target)
            local qDelay = qReady and 0.1 or 0.2 -- Shorter delay if Q is ready
            DelayAction(function()
                if Ready(_Q) then
                    local pred, chance = GetPrediction(target, "Q")
                    if pred and chance >= self.Menu.combo.minHitChance:Value() then
                        Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                    end
                end
            end, qDelay)
            return
        end
        
        -- E-Q through minions (improved logic) - ONLY if Q is ready or will be ready
        if isChasing and distanceToTarget <= 700 then
            local bestMinion = self:GetBestMinionForEQ(target)
            if bestMinion and not HasEBuff(bestMinion) and self:IsSafeToE(bestMinion) then
                Control.CastSpell(HK_E, bestMinion)
                local qDelay = qReady and 0.15 or 0.25
                DelayAction(function()
                    if Ready(_Q) then
                        local pred, chance = GetPrediction(target, "Q")
                        if pred and chance >= self.Menu.combo.minHitChance:Value() then
                            Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                        end
                    end
                end, qDelay)
                return
            end
        end
    end
    
    -- PRIORITY 5: Smart E Chase / Gapcloser for positioning
    if Ready(_E) and isChasing and distanceToTarget > basicAttackRange then
        if self.Menu.combo.smartEChase:Value() then
            if self:SmartEChase(target) then return end
        end
        if self.Menu.gapcloser.enabled:Value() then
            if self:ManualGapcloser() then return end
        end
    end
    
    -- PRIORITY 6: Basic Q for poke/stack
    if self.Menu.combo.useQ:Value() and qReady and not hasQ3 then
        local qRange = SPELL_RANGE.Q
        if distanceToTarget <= qRange then
            local pred, chance = GetPrediction(target, "Q")
            if pred and chance >= self.Menu.combo.minHitChance:Value() then
                Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                return
            end
        end
    end
    
    -- PRIORITY 7: Basic E for gap closing
    if self.Menu.combo.useE:Value() and Ready(_E) and isChasing and not HasEBuff(target) then
        if distanceToTarget <= SPELL_RANGE.E and distanceToTarget > basicAttackRange then
            if self:IsSafeToE(target) then
                Control.CastSpell(HK_E, target)
                return
            end
        end
    end
end

-- Smart E Chase: chain E through minions that reduce distance to target safely
function DepressiveYasuo2:SmartEChase(target)
    if not target or not target.valid then return false end
    -- Don’t override direct E if target is in E range and safe
    if not HasEBuff(target) then
        local d = GetDistance(myHero.pos, target.pos)
        if d <= SPELL_RANGE.E and self:IsSafeToE(target) then
            Control.CastSpell(HK_E, target)
            return true
        end
    end
    -- Find best minion to E that decreases distance to target and is safe
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local currentDist = GetDistance2D(heroPos2D, targetPos2D)
    local best, bestGain = nil, 0
    for i = 1, Game.MinionCount() do
        local m = Game.Minion(i)
        if m and not m.dead and m.team ~= myHero.team and not HasEBuff(m) then
            local mPos2D = {x = m.pos.x, z = m.pos.z}
            if GetDistance2D(heroPos2D, mPos2D) <= SPELL_RANGE.E then
                -- estimate Yasuo’s position after E
                local after = self:CalculateEPosition(mPos2D)
                local newDist = GetDistance2D(after, targetPos2D)
                if newDist + 10 < currentDist then -- must be strictly closer
                    -- Safety check
                    if self:IsSafeToE(m) then
                        local gain = currentDist - newDist
                        if gain > bestGain then
                            bestGain, best = gain, m
                        end
                    end
                end
            end
        end
    end
    if best then
        Control.CastSpell(HK_E, best)
        return true
    end
    return false
end

-- Q3 Animation Cancel: perform a tiny action shortly after Q3 is fired to reduce end-lag
function DepressiveYasuo2:HandleQ3Cancel()
    if not self.Menu.q3cancel or not self.Menu.q3cancel.enabled:Value() then return end
    if self.walljumpExecuting or (self.beybladeState and self.beybladeState ~= "idle") then return end
    -- Only relevant when Q3 is actually being used (tornado)
    local hasQ3Now = HasQ3()

    -- Detect Q3 cast by checking Q state dropping from Q3 -> Q1 wrapper and Q going on cooldown
    local qData = myHero:GetSpellData(_Q)
    local qOnCD = qData and qData.currentCd and qData.currentCd > 0

    -- When we had Q3 and now Q is on CD, assume we just cast Q3
    if self.prevHasQ3 and qOnCD and not self.q3CancelLock then
        self.q3CancelLock = true
        local delaySec = (self.Menu.q3cancel.delay:Value() or 35) / 1000
        DelayAction(function()
            self:PerformQ3CancelAction()
            self.lastQ3CancelTime = Game.Timer()
        end, delaySec)
    end

    -- Reset lock when Q becomes ready again
    if self.q3CancelLock and qData and qData.currentCd == 0 then
        self.q3CancelLock = false
    end

    self.prevHasQ3 = hasQ3Now
end

-- Execute the action that cancels Q3 end-lag (Ctrl+3 dance by default)
function DepressiveYasuo2:PerformQ3CancelAction()
    local pressTime = 0.02
    if self.Menu.q3cancel and self.Menu.q3cancel.useCtrl3 and self.Menu.q3cancel.useCtrl3:Value() then
        -- Prefer native emote key if available, otherwise press the '3' key with Ctrl
        local key3 = _G.HK_EMOTE3 or _G.HK_3 or string.byte("3") or 51
        Control.KeyDown(HK_CTRL)
        Control.KeyDown(key3)
        DelayAction(function()
            Control.KeyUp(key3)
            Control.KeyUp(HK_CTRL)
        end, pressTime)
    else
        -- Fallback: tiny move to current position
        if myHero and myHero.pos then
            Control.Move(myHero.pos)
        end
    end
end

function DepressiveYasuo2:BeybladeCombo()
    local target = self:GetBestTarget()
    if not target or not Ready(_E) or not Ready(_Q) then return end

    local flashSlot = self:GetSummonerSpellSlot("SummonerFlash")
    if not flashSlot or not Ready(flashSlot) then return end

    self.comboState = "beyblade"
    self.comboTarget = target

    -- E to minion or target
    local eTarget = self:GetBestMinionForEQ(target) or target

    if not HasEBuff(eTarget) and GetDistance(myHero.pos, eTarget.pos) <= SPELL_RANGE.E then
        Control.CastSpell(HK_E, eTarget)

        DelayAction(function()
            if Ready(_Q) then
                Control.CastSpell(HK_Q)

                DelayAction(function()
                    if Ready(flashSlot) then
                        local flashPos = myHero.pos:Extended(target.pos, 400)
                        Control.CastSpell(flashSlot, flashPos)

                        DelayAction(function()
                            if Ready(_Q) and HasQ3() then
                                local pred, hitChance = GetPrediction(target, "Q3")
                                if pred and hitChance >= 2 then
                                    Control.CastSpell(HK_Q, pred)
                                else
                                    Control.CastSpell(HK_Q, target.pos)
                                end

                                DelayAction(function()
                                    if Ready(_R) and self:CanUseUltimate(target) then
                                        Control.CastSpell(HK_R)
                                    end
                                    self.comboState = "idle"
                                end, 0.3)
                            end
                        end, 0.2)
                    end
                end, 0.15)
            end
        end, 0.1)
    end
end

function DepressiveYasuo2:EQ3FlashCombo()
    local target = self:GetBestTarget()
    if not target or not HasQ3() or not Ready(_E) or not Ready(_Q) then return end
    
    local flashSlot = self:GetSummonerSpellSlot("SummonerFlash")
    if not flashSlot or not Ready(flashSlot) then return end
    
    -- Start combo
    self.comboState = "eq3flash"
    self.comboTarget = target
    
    -- Find minion or use target directly
    local eTarget = self:GetBestMinionForEQ(target) or target
    
    if not HasEBuff(eTarget) and GetDistance(myHero.pos, eTarget.pos) <= SPELL_RANGE.E then
        Control.CastSpell(HK_E, eTarget)
        
        DelayAction(function()
            if Ready(_Q) and HasQ3() then
                local pred, hitChance = GetPrediction(target, "Q3")
                if pred and hitChance >= 2 then
                    Control.CastSpell(HK_Q, pred)
                else
                    Control.CastSpell(HK_Q, target.pos)
                end
                
                -- Flash after Q3
                DelayAction(function()
                    if Ready(flashSlot) then
                        local flashPos = myHero.pos:Extended(target.pos, 400)
                        Control.CastSpell(flashSlot, flashPos)
                    end
                    self.comboState = "idle"
                end, 0.2)
            end
        end, 0.1)
    end
end

function DepressiveYasuo2:BeybladeCombo()
    local target = self:GetBestTarget()
    if not target or not Ready(_E) or not Ready(_Q) then return end
    
    local flashSlot = self:GetSummonerSpellSlot("SummonerFlash")
    if not flashSlot or not Ready(flashSlot) then return end
    
    self.comboState = "beyblade"
    self.comboTarget = target
    
    -- E to minion or target
    local eTarget = self:GetBestMinionForEQ(target) or target
    
    if not HasEBuff(eTarget) and GetDistance(myHero.pos, eTarget.pos) <= SPELL_RANGE.E then
        Control.CastSpell(HK_E, eTarget)
        
        DelayAction(function()
            if Ready(_Q) then
                Control.CastSpell(HK_Q)
                
                DelayAction(function()
                    if Ready(flashSlot) then
                        local flashPos = myHero.pos:Extended(target.pos, 400)
                        Control.CastSpell(flashSlot, flashPos)
                        
                        DelayAction(function()
                            if Ready(_Q) and HasQ3() then
                                local pred, hitChance = GetPrediction(target, "Q3")
                                if pred and hitChance >= 2 then
                                    Control.CastSpell(HK_Q, pred)
                                else
                                    Control.CastSpell(HK_Q, target.pos)
                                end
                                
                                DelayAction(function()
                                    if Ready(_R) and self:CanUseUltimate(target) then
                                        Control.CastSpell(HK_R)
                                    end
                                    self.comboState = "idle"
                                end, 0.3)
                            end
                        end, 0.2)
                    end
                end, 0.15)
            end
        end, 0.1)
    end
end

function DepressiveYasuo2:Clear()
    if not self.Menu.clear.useQ:Value() and not self.Menu.clear.useE:Value() then return end
    
    -- Check Q state
    local qReady = Ready(_Q)
    local eReady = Ready(_E)
    local hasQ3 = HasQ3()
    
    -- PRIORITY 1: E-Q Combo SOLO si hay 2+ minions para hitear (sin Q3)
    -- Más eficiente: solo usa E-Q cuando vale la pena (múltiples minions)
    if self.Menu.clear.fluidEQ:Value() and self.Menu.clear.useE:Value() and self.Menu.clear.useQ:Value() and eReady and qReady and not hasQ3 then
        local scanR = (self.Menu.performance and self.Menu.performance.scanRange:Value()) or 1500
        local minions2D = GetEnemyMinions2D(scanR)
        local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
        local qRange = SPELL_RANGE.Q
        
        local bestMinion = nil
        local bestScore = 0
        local bestMinionsInQ = 0
        
        -- Buscar el mejor minion para E que permita hitear 2+ minions con Q
        for i = 1, #minions2D do
            local minion = minions2D[i].obj
            if minion and not HasEBuff(minion) then
                local minionPos2D = minions2D[i]
                local distance = GetDistance2D(heroPos2D, minionPos2D)
                
                if distance <= SPELL_RANGE.E then
                    -- Calcular posición después de E
                    local futurePos = self:CalculateEPosition(minionPos2D)
                    
                    -- Contar cuántos minions estarán en rango de Q después de E
                    local minionsInQ = 0
                    for j = 1, #minions2D do
                        local otherMinion = minions2D[j].obj
                        if otherMinion then
                            local dist = GetDistance2D(futurePos, {x = otherMinion.pos.x, z = otherMinion.pos.z})
                            if dist <= qRange then
                                minionsInQ = minionsInQ + 1
                            end
                        end
                    end
                    
                    -- SOLO usar E-Q si podemos hitear 2+ minions
                    if minionsInQ >= 2 then
                        local score = minionsInQ * 100
                        
                        -- Bonus por estar más cerca
                        score = score + (SPELL_RANGE.E - distance) / 10
                        
                        if score > bestScore then
                            local isSafe = true
                            if self.Menu.clear.eSafetyCheck and self.Menu.clear.eSafetyCheck:Value() then
                                isSafe = self:IsPositionSafeFromEnemyAA(futurePos)
                            end
                            
                            if isSafe then
                                bestScore = score
                                bestMinion = minion
                                bestMinionsInQ = minionsInQ
                            end
                        end
                    end
                end
            end
        end
        
        -- Si encontramos un minion que permite hitear 2+, usar E-Q
        if bestMinion and bestMinionsInQ >= 2 then
            Control.CastSpell(HK_E, bestMinion)
            -- Usar Q inmediatamente después de E para hitear múltiples minions
            DelayAction(function()
                if Ready(_Q) then
                    local qPos = self:GetBestQPositionAfterE()
                    if qPos then
                        Control.CastSpell(HK_Q, qPos)
                    end
                end
            end, 0.15)
            return
        end
    end
    
    -- PRIORITY 2: E SOLO para lasthit (si no hay oportunidad de E-Q múltiple)
    -- Solo lasthitea con E cuando el minion va a morir
    if self.Menu.clear.useE:Value() and eReady then
        local eDamage = GetEDamage()
        local scanR = (self.Menu.performance and self.Menu.performance.scanRange:Value()) or 1500
        local minions2D = GetEnemyMinions2D(scanR)
        local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
        
        local bestMinion = nil
        local bestScore = 0
        
        for i = 1, #minions2D do
            local minion = minions2D[i].obj
            if minion and not HasEBuff(minion) then
                local minionPos2D = minions2D[i]
                local distance = GetDistance2D(heroPos2D, minionPos2D)
                
                if distance <= SPELL_RANGE.E then
                    -- SOLO usar E si el minion muere con el daño de E (lasthit)
                    if minion.health <= eDamage then
                        local score = 1000
                        
                        -- Bonus si es un cannon minion (más oro)
                        if minion.charName:find("Siege") or minion.charName:find("Super") then
                            score = score + 200
                        end
                        
                        -- Preferir minions más cercanos
                        score = score + (SPELL_RANGE.E - distance) / 10
                        
                        if score > bestScore then
                            local finalPos = self:CalculateEPosition(minionPos2D)
                            local isSafe = true
                            
                            if self.Menu.clear.eSafetyCheck and self.Menu.clear.eSafetyCheck:Value() then
                                isSafe = self:IsPositionSafeFromEnemyAA(finalPos)
                            end
                            
                            if isSafe then
                                bestScore = score
                                bestMinion = minion
                            end
                        end
                    end
                end
            end
        end
        
        if bestMinion then
            Control.CastSpell(HK_E, bestMinion)
            return
        end
    end
    
    -- PRIORITY 3: Q3 para clear si está disponible
    -- Usar Q3 en clear para pushear rápido la wave
    if self.Menu.clear.useQ:Value() and qReady and hasQ3 then
        local scanR = (self.Menu.performance and self.Menu.performance.scanRange:Value()) or 1500
        local minions2D = GetEnemyMinions2D(scanR)
        local bestPos = nil
        local maxCount = 0
        local qRange = SPELL_RANGE.Q3
        
        -- Buscar la mejor posición para hitear múltiples minions con Q3
        for i = 1, #minions2D do
            local minion = minions2D[i].obj
            if minion then
                local minionPos = minion.pos
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                local minionPos2D = {x = minionPos.x, z = minionPos.z}
                local distance = GetDistance2D(heroPos2D, minionPos2D)
                
                if distance <= qRange then
                    local count = 0
                    -- Contar minions en el radio de Q3
                    for j = 1, #minions2D do
                        local other = minions2D[j].obj
                        if other then
                            local dist = GetDistance(minionPos, other.pos)
                            if dist <= SPELL_RADIUS.Q3 then
                                count = count + 1
                            end
                        end
                    end
                    
                    -- Usar Q3 si hay al menos 1 minion (siempre usar para clear)
                    if count > maxCount then
                        maxCount = count
                        bestPos = Vector(minionPos.x, myHero.pos.y, minionPos.z)
                    end
                end
            end
        end
        
        if bestPos then
            Control.CastSpell(HK_Q, bestPos)
            return
        end
    end
    
    -- PRIORITY 4: Q normal para clear (si no tenemos Q3)
    if self.Menu.clear.useQ:Value() and qReady and not hasQ3 then
        local bestQPos = self:GetBestQPosition()
        if bestQPos then
            Control.CastSpell(HK_Q, bestQPos)
            return
        end
    end
end

-- Get best Q target for clearing
function DepressiveYasuo2:GetBestQTarget()
    local qRange = SPELL_RANGE.Q
    local bestTarget = nil
    local bestScore = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead then
            local distance = GetDistance2D(myHero.pos, minion.pos)
            if distance <= qRange then
                local score = 100
                score = score + (qRange - distance) / 10
                
                -- Bonus for low health minion
                if minion.health < minion.maxHealth * 0.5 then
                    score = score + 20
                end
                
                if score > bestScore then
                    bestScore = score
                    bestTarget = minion
                end
            end
        end
    end
    
    return bestTarget
end

-- Helper function: Check if position is safe from enemy basic attacks
function DepressiveYasuo2:IsPositionSafeFromEnemyAA(position)
    if not position then return true end
    
    local safetyMargin = 100 -- Extra safety margin
    
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if enemy and enemy.team ~= myHero.team and not enemy.dead and enemy.visible then
            -- Get enemy's actual attack range
            local enemyAARange = enemy.range or 550 -- Default to 550 if range not available
            local totalRange = enemyAARange + safetyMargin
            
            local distance = GetDistance2D(position, enemy.pos)
            if distance <= totalRange then
                return false -- Position is within enemy AA range + safety margin
            end
        end
    end
    
    return true -- Position is safe
end

function DepressiveYasuo2:LastHit()
    if not Ready(_Q) and not Ready(_E) then return end
    
    -- Find minions that can be last hit with Q
    if Ready(_Q) then
        local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                
                if GetDistance2D(heroPos2D, minionPos2D) <= qRange then
                    local qDamage = GetQDamage()
                    if minion.health <= qDamage and minion.health > myHero.totalDamage then
                        Control.CastSpell(HK_Q, minion.pos)
                        return
                    end
                end
            end
        end
    end
    
    -- Find minions that can be last hit with E
    if Ready(_E) then
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead and not HasEBuff(minion) then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
                
                if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E then
                    local eDamage = GetEDamage()
                    if minion.health <= eDamage and minion.health > myHero.totalDamage then
                        Control.CastSpell(HK_E, minion)
                        return
                    end
                end
            end
        end
    end
end

function DepressiveYasuo2:Flee()
    if not Ready(_E) then return end
    
    local mousePos = Game.mousePos()
    local mousePos2D = {x = mousePos.x, z = mousePos.z}
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    
    -- Buscar el mejor minion para hacer gapcloser hacia el mouse
    local bestMinion = nil
    local bestScore = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and not minion.dead and not HasEBuff(minion) then
            -- SOLO minions enemigos (team diferente) o neutrales (jungle monsters, team 300)
            if minion.team ~= myHero.team and (minion.team == 300 or minion.team ~= myHero.team) then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                local distanceToMinion = GetDistance2D(heroPos2D, minionPos2D)
                
                -- Verificar que el minion esté en rango de E
                if distanceToMinion <= SPELL_RANGE.E then
                    -- Calcular si el E nos acerca al mouse
                    local currentDistanceToMouse = GetDistance2D(heroPos2D, mousePos2D)
                    local minionToMouseDistance = GetDistance2D(minionPos2D, mousePos2D)
                    
                    -- Solo considerar minions que nos acerquen al mouse
                    if minionToMouseDistance < currentDistanceToMouse then
                        local score = currentDistanceToMouse - minionToMouseDistance -- Más score = más cerca del mouse
                        
                        -- Bonus para minions que están en la dirección del mouse
                        local heroToMouse = {x = mousePos2D.x - heroPos2D.x, z = mousePos2D.z - heroPos2D.z}
                        local heroToMinion = {x = minionPos2D.x - heroPos2D.x, z = minionPos2D.z - heroPos2D.z}
                        
                        -- Producto escalar normalizado para verificar dirección similar
                        local heroToMouseMag = math.sqrt(heroToMouse.x^2 + heroToMouse.z^2)
                        local heroToMinionMag = math.sqrt(heroToMinion.x^2 + heroToMinion.z^2)
                        
                        if heroToMouseMag > 0 and heroToMinionMag > 0 then
                            local dotProduct = (heroToMouse.x * heroToMinion.x + heroToMouse.z * heroToMinion.z) / (heroToMouseMag * heroToMinionMag)
                            
                            -- Si el minion está en buena dirección hacia el mouse (coseno > 0.3)
                            if dotProduct > 0.3 then
                                score = score + (dotProduct * 200) -- Bonus por buena dirección
                            end
                        end
                        
                        -- Penalty por estar bajo torre enemiga (pero permitirlo si es para escapar)
                        local ePosition = CalculateEPosition(minion)
                        if ePosition and IsUnderEnemyTurret(ePosition, self.Menu.safety.range:Value()) then
                            score = score - 100 -- Penalty menor para escape
                        end
                        
                        -- Bonus extra para jungle monsters (team 300) ya que son más seguros para escape
                        if minion.team == 300 then
                            score = score + 50
                        end
                        
                        if score > bestScore then
                            bestScore = score
                            bestMinion = minion
                        end
                    end
                end
            end
        end
    end
    
    -- Ejecutar E al mejor minion encontrado
    if bestMinion and bestScore > 0 then
        Control.CastSpell(HK_E, bestMinion)
    end
end

-- Helper Functions
function DepressiveYasuo2:IsInCombat()
    -- Check if we're in combat with enemies (within 1000 units)
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if IsValidTarget(enemy, 1000) then
            return true
        end
    end
    return false
end

function DepressiveYasuo2:IsChasingTarget(target)
    -- Consider chasing when engaging keys are held and target is outside AA and Q range
    if not target or not target.valid then return false end
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local distanceToTarget = GetDistance2D(heroPos2D, targetPos2D)
    local aaRange = (myHero.range or 150) + (myHero.boundingRadius or 35) + (target.boundingRadius or 35)
    local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
    local engaging = self.keysPressed and (self.keysPressed.space or self.keysPressed.c)
    return engaging and distanceToTarget > math.min(qRange, aaRange) + 25
end

function DepressiveYasuo2:StackQ()
    -- Smart Q stacking system - prioritize minions over monsters
    if not Ready(_Q) or HasQ3() then return end
    
    local qRange = SPELL_RANGE.Q
    local bestTarget = nil
    local bestScore = 0
    
    -- Priority 1: Minions (easier to hit, more reliable)
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= qRange then
                local score = 100 -- Base score for minions
                
                -- Prefer closer minions
                score = score + (qRange - distance) / 10
                
                -- Prefer low HP minions (easier to predict)
                if minion.health < minion.maxHealth * 0.5 then
                    score = score + 20
                end
                
                if score > bestScore then
                    bestScore = score
                    bestTarget = minion
                end
            end
        end
    end
    
    -- Priority 2: Jungle monsters (if no minions available)
    if not bestTarget then
        for i = 1, Game.MinionCount() do
            local monster = Game.Minion(i)
            if monster and monster.team == 300 and not monster.dead then -- Neutral monsters
                local distance = GetDistance(myHero.pos, monster.pos)
                if distance <= qRange then
                    local score = 80 -- Lower base score than minions
                    score = score + (qRange - distance) / 10
                    
                    if score > bestScore then
                        bestScore = score
                        bestTarget = monster
                    end
                end
            end
        end
    end
    
    -- Cast Q on best target
    if bestTarget then
        local pred, chance = GetPrediction(bestTarget, "Q")
        if pred and chance >= 2 then
            Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
        else
            Control.CastSpell(HK_Q, bestTarget.pos)
        end
    end
end

function DepressiveYasuo2:GetBestMinionForEQ(target)
    local bestMinion = nil
    local bestScore = 0
    local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
    local qRadius = HasQ3() and SPELL_RADIUS.Q3 or SPELL_RADIUS.Q
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local scanR = (self.Menu.performance and self.Menu.performance.scanRange:Value()) or 1500
    local minions2D = GetEnemyMinions2D(scanR)
    
    -- CRITICAL: Check if Q is ready or will be ready after E dash
    -- E resets Q cooldown to 0.5s, so if Q cd <= 0.5s, it will be ready after E
    if not IsQReadyForEQ() then
        return nil -- Q not ready, don't use E
    end
    
    -- Get movement style from menu
    local movementStyle = self.Menu.combo.movementStyle:Value()
    local aggressiveMovement = self.Menu.combo.aggressiveMovement:Value()
    
    -- Multipliers based on movement style
    local dashBonusMultiplier = 1.0
    local flankBonusMultiplier = 1.0
    local safetyPenaltyMultiplier = 1.0
    
    if movementStyle == 1 then -- Balanced
        dashBonusMultiplier = 1.5
        flankBonusMultiplier = 1.0
        safetyPenaltyMultiplier = 1.5
    elseif movementStyle == 2 then -- Aggressive
        dashBonusMultiplier = 2.5
        flankBonusMultiplier = 1.5
        safetyPenaltyMultiplier = 1.0
    elseif movementStyle == 3 then -- Very Aggressive
        dashBonusMultiplier = 3.5
        flankBonusMultiplier = 2.0
        safetyPenaltyMultiplier = 0.5
    end
    
    for i = 1, #minions2D do
        local minion = minions2D[i].obj
        if minion and not HasEBuff(minion) then
            local minionPos2D = minions2D[i]
            
            -- Check if minion is in E range
            if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E then
                -- Calculate position after E dash (250 units past minion)
                local dashEndPos = self:CalculateEPosition(minionPos2D)
                local dashEndPos2D = {x = dashEndPos.x, z = dashEndPos.z}
                
                -- Calculate Q circle/area position after E
                -- Q casts from dash end position
                local distFromDashToTarget = GetDistance2D(dashEndPos2D, targetPos2D)
                
                -- Check if target is within Q range from dash end position
                if distFromDashToTarget <= qRange then
                    -- Calculate if target is within Q circle/radius
                    -- For Q3 (tornado), it's a wider circle
                    -- For Q1/Q2, it's a smaller circle around Yasuo
                    local willHitTarget = false
                    
                    if HasQ3() then
                        -- Q3 creates a circular AoE around the cast position
                        -- Target needs to be within radius of the Q3 circle
                        willHitTarget = distFromDashToTarget <= qRange
                    else
                        -- Q1/Q2 is a circle around Yasuo after dash
                        -- Target needs to be within the circular slash range
                        willHitTarget = distFromDashToTarget <= qRange
                    end
                    
                    if willHitTarget then
                        -- Score based on optimal positioning
                        local score = 1000
                        
                        -- MOVEMENT BONUS: Prefer minions that create more movement/mobility
                        local dashDistance = GetDistance2D(heroPos2D, dashEndPos2D)
                        score = score + (dashDistance * 2 * dashBonusMultiplier) -- Reward longer dashes
                        
                        -- Prefer positions where we dash TOWARDS the target
                        local heroToTargetDist = GetDistance2D(heroPos2D, targetPos2D)
                        local dashEndToTargetDist = GetDistance2D(dashEndPos2D, targetPos2D)
                        if dashEndToTargetDist < heroToTargetDist then
                            score = score + (300 * dashBonusMultiplier) -- Big bonus for getting closer
                        end
                        
                        -- OPTIMAL Q RANGE BONUS: Prefer hitting at optimal range
                        local optimalRange = qRange * 0.6 -- Sweet spot at 60% of max range
                        local rangeDiff = math.abs(distFromDashToTarget - optimalRange)
                        score = score + (200 - rangeDiff) -- Bonus for being near optimal range
                        
                        -- Q3 positioning bonus (tornado is wider and better for hitting)
                        if HasQ3() then
                            score = score + 250
                            -- Extra bonus if we can hit multiple enemies with Q3
                            local enemiesInQ3Range = 0
                            for j = 1, Game.HeroCount() do
                                local enemy = Game.Hero(j)
                                if enemy and enemy.isEnemy and not enemy.dead then
                                    local enemyPos2D = {x = enemy.pos.x, z = enemy.pos.z}
                                    if GetDistance2D(dashEndPos2D, enemyPos2D) <= qRange then
                                        enemiesInQ3Range = enemiesInQ3Range + 1
                                    end
                                end
                            end
                            if enemiesInQ3Range >= 2 then
                                score = score + 400 -- Big bonus for multi-target Q3
                            end
                        end
                        
                        -- ANGLE/DIRECTION BONUS: Prefer flanking/side angles
                        local dx1 = targetPos2D.x - heroPos2D.x
                        local dz1 = targetPos2D.z - heroPos2D.z
                        local dx2 = dashEndPos2D.x - heroPos2D.x
                        local dz2 = dashEndPos2D.z - heroPos2D.z
                        local dotProduct = (dx1 * dx2 + dz1 * dz2) / (math.sqrt(dx1*dx1 + dz1*dz1) * math.sqrt(dx2*dx2 + dz2*dz2) + 0.001)
                        
                        -- Reward perpendicular/flanking angles (more unpredictable movement)
                        if dotProduct > -0.3 and dotProduct < 0.7 then
                            score = score + (150 * flankBonusMultiplier) -- Bonus for side angles
                        end
                        
                        -- Bonus for circling/orbiting around target (very aggressive playstyle)
                        if aggressiveMovement then
                            -- Calculate if we're moving perpendicular to target (circling)
                            if dotProduct > -0.2 and dotProduct < 0.2 then
                                score = score + (200 * flankBonusMultiplier) -- Extra bonus for perpendicular movement
                            end
                        end
                        
                        -- Safety check: don't dash into dangerous areas
                        if IsUnderEnemyTurret(dashEndPos) then
                            score = score - (500 * safetyPenaltyMultiplier) -- Penalty for tower dives
                        end
                        
                        -- Penalty for low HP minions (might die during E)
                        if minion.health < GetEDamage() * 1.2 then
                            score = score - 100
                        end
                        
                        -- Final check: verify target is actually within the circular AoE
                        -- This ensures the E-Q circle will definitely hit
                        if score > bestScore then
                            bestScore = score
                            bestMinion = minion
                        end
                    end
                end
            end
        end
    end
    
    return bestMinion
end

function DepressiveYasuo2:GetBestQ3Position()
    if not HasQ3() then return nil end
    
    local bestPos = nil
    local bestScore = 0
    local qRange = SPELL_RANGE.Q3
    local scanR = (self.Menu.performance and self.Menu.performance.scanRange:Value()) or 1500
    local minions2D = GetEnemyMinions2D(scanR)
    
    -- Check around each minion to find best Q3 position
    for i = 1, #minions2D do
        local minion = minions2D[i].obj
        if minion then
            local minionPos = minion.pos
            if GetDistance(myHero.pos, minionPos) <= qRange then
                local score = 1
                
                -- Count other minions that would be hit
                for j = 1, #minions2D do
                    local otherMinion = minions2D[j].obj
                    if otherMinion and otherMinion ~= minion then
                        if GetDistance(minionPos, otherMinion.pos) <= SPELL_RADIUS.Q3 then
                            score = score + 1
                        end
                    end
                end
                
                if score > bestScore and score >= 2 then -- At least 2 minions
                    bestScore = score
                    bestPos = Vector(minionPos.x, myHero.pos.y, minionPos.z)
                end
            end
        end
    end
    
    return bestPos
end

function DepressiveYasuo2:GetBestLasthitMinion(eDamage)
    local bestMinion = nil
    local bestScore = 0
    local scanR = (self.Menu.performance and self.Menu.performance.scanRange:Value()) or 1500
    local minions2D = GetEnemyMinions2D(scanR)
    
    for i = 1, #minions2D do
        local minion = minions2D[i].obj
        if minion and not HasEBuff(minion) then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= SPELL_RANGE.E and minion.health <= eDamage then
                local score = 100
                
                -- Prefer closer minions
                score = score + (SPELL_RANGE.E - distance) / 10
                
                -- Bonus if it's a cannon minion
                if minion.charName:find("Siege") or minion.charName:find("Super") then
                    score = score + 50
                end
                
                if score > bestScore then
                    bestScore = score
                    bestMinion = minion
                end
            end
        end
    end
    
    return bestMinion
end

function DepressiveYasuo2:GetBestClearMinion()
    local bestMinion = nil
    local bestScore = 0
    local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
    local scanR = (self.Menu.performance and self.Menu.performance.scanRange:Value()) or 1500
    local minions2D = GetEnemyMinions2D(scanR)
    
    for i = 1, #minions2D do
        local minion = minions2D[i].obj
        if minion and not HasEBuff(minion) then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= SPELL_RANGE.E then
                -- Calculate future position after E
                local futurePos = self:CalculateEPosition({x = minion.pos.x, z = minion.pos.z})
                
                -- Count minions that will be in Q range after E
                local minionsInRange = 0
                for j = 1, #minions2D do
                    local otherMinion = minions2D[j].obj
                    if otherMinion then
                        local otherDistance = GetDistance2D(futurePos, {x = otherMinion.pos.x, z = otherMinion.pos.z})
                        if otherDistance <= qRange then
                            minionsInRange = minionsInRange + 1
                        end
                    end
                end
                
                if minionsInRange >= 2 then -- At least 2 minions for efficiency
                    local score = minionsInRange * 100
                    
                    if score > bestScore then
                        bestScore = score
                        bestMinion = minion
                    end
                end
            end
        end
    end
    
    return bestMinion
end

function DepressiveYasuo2:GetBestQPosition()
    local bestPos = nil
    local bestScore = 0
    local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
    local scanR = (self.Menu.performance and self.Menu.performance.scanRange:Value()) or 1500
    local minions2D = GetEnemyMinions2D(scanR)
    
    for i = 1, #minions2D do
        local minion = minions2D[i].obj
        if minion then
            local distance = GetDistance(myHero.pos, minion.pos)
            if distance <= qRange then
                local score = 1
                local minionPos = minion.pos
                
                -- Count other minions in range
                for j = 1, #minions2D do
                    local otherMinion = minions2D[j].obj
                    if otherMinion and otherMinion ~= minion then
                        local otherDistance = GetDistance(minionPos, otherMinion.pos)
                        local radius = HasQ3() and SPELL_RADIUS.Q3 or SPELL_RADIUS.Q
                        if otherDistance <= radius then
                            score = score + 1
                        end
                    end
                end
                
                if score > bestScore then
                    bestScore = score
                    bestPos = Vector(minionPos.x, myHero.pos.y, minionPos.z)
                end
            end
        end
    end
    
    return bestPos
end

function DepressiveYasuo2:GetBestQPositionAfterE()
    -- Use current position as the position after E (simplified)
    return self:GetBestQPosition()
end

function DepressiveYasuo2:GetBestMinionForHarass(target)
    return self:GetBestMinionForEQ(target)
end

function DepressiveYasuo2:GetBestMinionForQ()
    local qRange = HasQ3() and SPELL_RANGE.Q3 or SPELL_RANGE.Q
    local scanR = (self.Menu.performance and self.Menu.performance.scanRange:Value()) or 1500
    local minions2D = GetEnemyMinions2D(scanR)
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    for i = 1, #minions2D do
        local minion = minions2D[i].obj
        if minion and GetDistance2D(heroPos2D, minions2D[i]) <= qRange then
            return minion
        end
    end
    return nil
end

function DepressiveYasuo2:GetBestMinionForE()
    local scanR = (self.Menu.performance and self.Menu.performance.scanRange:Value()) or 1500
    local minions2D = GetEnemyMinions2D(scanR)
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    for i = 1, #minions2D do
        local minion = minions2D[i].obj
        if minion and GetDistance2D(heroPos2D, minions2D[i]) <= SPELL_RANGE.E and not HasEBuff(minion) then
            return minion
        end
    end
    return nil
end

function DepressiveYasuo2:GetMinionChainToTarget(target)
    local chain = {}
    local currentPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local maxChainLength = 3
    
    for chainStep = 1, maxChainLength do
        local bestMinion = nil
        local bestDistance = math.huge
        
        for i = 1, Game.MinionCount() do
            local minion = Game.Minion(i)
            if minion and minion.team ~= myHero.team and not minion.dead then
                local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
                if GetDistance2D(currentPos2D, minionPos2D) <= SPELL_RANGE.E and not HasEBuff(minion) then
                    local distToTarget = GetDistance2D(minionPos2D, targetPos2D)
                    if distToTarget < bestDistance then
                        bestDistance = distToTarget
                        bestMinion = minion
                    end
                end
            end
        end
        
        if bestMinion and bestDistance < GetDistance2D(currentPos2D, targetPos2D) then
            table.insert(chain, bestMinion)
            currentPos2D = {x = bestMinion.pos.x, z = bestMinion.pos.z}
            
            -- If we can reach target from this minion, we're done
            if GetDistance2D(currentPos2D, targetPos2D) <= SPELL_RANGE.E then
                break
            end
        else
            break
        end
    end
    
    return chain
end

function DepressiveYasuo2:GetBestTarget()
    local bestTarget = nil
    local bestPriority = 0
    local bestDistance = math.huge
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if IsValidTarget(hero, 1200) then
            local distance = GetDistance(myHero.pos, hero.pos)
            local priority = 1
            
            -- Prioritize low HP targets
            if hero.health / hero.maxHealth < 0.3 then
                priority = priority + 3
            elseif hero.health / hero.maxHealth < 0.5 then
                priority = priority + 2
            end
            
            -- Prioritize AD carries and mid laners
            if hero.charName:find("Jinx") or hero.charName:find("Caitlyn") or hero.charName:find("Ashe") or 
               hero.charName:find("Ahri") or hero.charName:find("Zed") or hero.charName:find("Yasuo") then
                priority = priority + 2
            end
            
            -- Prefer closer targets if same priority
            if priority > bestPriority or (priority == bestPriority and distance < bestDistance) then
                bestTarget = hero
                bestPriority = priority
                bestDistance = distance
            end
        end
    end
    
    return bestTarget
end

function DepressiveYasuo2:ManualGapcloser()
    local target = self:GetBestTarget()
    if not target or not self.Menu.gapcloser.enabled:Value() then 
        return false 
    end
    
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local distance = GetDistance2D(heroPos2D, targetPos2D)
    
    -- Don't gapclose if we're already close enough for basic abilities
    if distance <= SPELL_RANGE.Q then
        return false
    end
    
    if distance <= SPELL_RANGE.E and not HasEBuff(target) then
        -- Direct E to target
        if not self.Menu.gapcloser.checkTurret:Value() or self:IsSafeToE(target) then
            Control.CastSpell(HK_E, target)
            return true
        end
    elseif distance <= self.Menu.gapcloser.maxRange:Value() and self.Menu.gapcloser.useMinions:Value() then
        -- Use minions to gapclose
        local gapcloseMinion = self:FindGapcloseMinion(target)
        if gapcloseMinion then
            if not self.Menu.gapcloser.checkTurret:Value() or self:IsSafeToE(gapcloseMinion) then
                Control.CastSpell(HK_E, gapcloseMinion)
                return true
            end
        end
    end
    
    return false
end

function DepressiveYasuo2:FindGapcloseMinion(target)
    local bestMinion = nil
    local bestScore = 0
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local currentDistanceToTarget = GetDistance2D(heroPos2D, targetPos2D)
    
    local minionCount = 0
    local validMinions = 0
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        minionCount = minionCount + 1
        
        if minion and minion.team ~= myHero.team and not minion.dead and not HasEBuff(minion) then
            local minionPos2D = {x = minion.pos.x, z = minion.pos.z}
            
            -- Check if minion is in E range from current position
            if GetDistance2D(heroPos2D, minionPos2D) <= SPELL_RANGE.E then
                validMinions = validMinions + 1
                
                -- Calculate future position after E (Yasuo stops behind the target)
                local futurePos2D = self:CalculateEPosition(minionPos2D)
                
                -- Calculate distance from future position to enemy
                local futureDistanceToTarget = GetDistance2D(futurePos2D, targetPos2D)
                
                -- Only consider minions that actually bring us closer to the enemy
                if futureDistanceToTarget < currentDistanceToTarget then
                    -- Calculate how much closer we get (improvement score)
                    local improvement = currentDistanceToTarget - futureDistanceToTarget
                    
                    -- Bonus score if we can reach target after E
                    local reachBonus = 0
                    if futureDistanceToTarget <= SPELL_RANGE.E then
                        reachBonus = 300 -- High priority if we can reach target directly after
                    elseif futureDistanceToTarget <= SPELL_RANGE.Q then
                        reachBonus = 150 -- Medium priority if we can Q after
                    end
                    
                    local totalScore = improvement + reachBonus
                    
                    if totalScore > bestScore then
                        bestScore = totalScore
                        bestMinion = minion
                    end
                end
            end
        end
    end
    
    return bestMinion
end

function DepressiveYasuo2:CalculateEPosition(targetPos2D)
    -- Calculate where Yasuo will be after E
    -- Yasuo dashes TOWARDS the target and stops just behind it (approximately 65 units past the target center)
    local heroPos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local dashDistance = 65 -- Yasuo stops 65 units past the target center
    
    -- Calculate direction from hero TO target (E direction)
    local dx = targetPos2D.x - heroPos2D.x
    local dz = targetPos2D.z - heroPos2D.z
    local distance = math.sqrt(dx * dx + dz * dz)
    
    -- Normalize direction vector
    if distance > 0 then
        dx = dx / distance
        dz = dz / distance
    else
        -- If positions are identical, use default direction
        dx = 0
        dz = 1
    end
    
    -- Calculate final position (past the target in the direction of the dash)
    local finalPos2D = {
        x = targetPos2D.x + (dx * dashDistance),
        z = targetPos2D.z + (dz * dashDistance)
    }
    
    return finalPos2D
end

function DepressiveYasuo2:Harass()
    local target = self:GetBestTarget()
    if not target then return end
    local isChasing = self:IsChasingTarget(target)
    
    -- Find minion for harass
    if self.Menu.harass.useE:Value() and Ready(_E) and isChasing then
        local harassMinion = self:GetBestMinionForEQ(target)
        if harassMinion and not HasEBuff(harassMinion) then
            Control.CastSpell(HK_E, harassMinion)
            
            if self.Menu.harass.useQ:Value() then
                DelayAction(function()
                    if Ready(_Q) then
                        local pred, hitChance = GetPrediction(target, "Q")
                        if pred and hitChance >= 2 then
                            Control.CastSpell(HK_Q, pred)
                        else
                            Control.CastSpell(HK_Q, target.pos)
                        end
                    end
                end, 0.15)
            end
        end
    end
end

function DepressiveYasuo2:IsSafeToE(target)
    if not self.Menu.safety.enabled:Value() then return true end
    
    local safetyRange = self.Menu.safety.range:Value()
    local allowLowHP = self.Menu.safety.allowLowHP:Value()
    
    -- Allow if target is low HP
    if target.health and target.maxHealth then
        if target.health / target.maxHealth * 100 <= allowLowHP then
            return true
        end
    end
    
    -- Check if we would be under turret after E - calculate Yasuo's position after E
    local targetPos2D = {x = target.pos.x, z = target.pos.z}
    local futurePos2D = self:CalculateEPosition(targetPos2D)
    return not IsUnderEnemyTurret(futurePos2D, safetyRange)
end

function DepressiveYasuo2:CanUseUltimate(target)
    if not target or not Ready(_R) then return false end
    
    -- Use YasuoThePackGod's precise airborne detection method
    -- Check for knockup/airborne buff types (type 30 and 31 are the correct ones)
    local buffCount = target.buffCount or 0
    for i = 0, buffCount - 1 do
        local buff = target:GetBuff(i)
        if buff and buff.count > 0 then
            local bType = buff.type
            -- Type 30 = Airborne, Type 31 = Knockup (YasuoThePackGod method)
            if bType == 30 or bType == 31 then
                return true
            end
        end
    end
    
    return false
end

function DepressiveYasuo2:CountKnockedUpEnemies(range, position)
    -- Similar to YasuoThePackGod's KnockCount function
    local pos = position or myHero.pos
    local count = 0
    local rangeSq = range * range
    
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if IsValidTarget(enemy) then
            local distanceSq = GetDistance(pos, enemy.pos) * GetDistance(pos, enemy.pos)
            if distanceSq < rangeSq and self:CanUseUltimate(enemy) then
                count = count + 1
            end
        end
    end
    
    return count
end

function DepressiveYasuo2:GetKnockedUpTarget()
    -- Get the first knocked up target in R range
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if IsValidTarget(enemy, SPELL_RANGE.R) and self:CanUseUltimate(enemy) then
            return enemy
        end
    end
    return nil
end

function DepressiveYasuo2:IsTargetKillableWithR(target)
    if not target then return false end
    
    -- Get target's current HP percentage
    local hpPercent = (target.health / target.maxHealth) * 100
    
    -- Check if target is below killable threshold
    if hpPercent <= self.Menu.ultimate.killableThreshold:Value() then
        return true
    end
    
    -- Advanced killable calculation (estimate R damage + follow-up damage)
    local estimatedRDamage = self:CalculateRDamage(target)
    local estimatedFollowUpDamage = self:CalculateFollowUpDamage(target)
    local totalDamage = estimatedRDamage + estimatedFollowUpDamage
    
    -- Add safety margin (consider armor/MR reductions)
    local effectiveDamage = totalDamage * 0.8 -- 20% safety margin
    
    return target.health <= effectiveDamage
end

function DepressiveYasuo2:CalculateRDamage(target)
    if not target then return 0 end
    
    -- R damage calculation (200/300/400 + 150% bonus AD per enemy hit)
    local rLevel = myHero:GetSpellData(_R).level
    if rLevel == 0 then return 0 end
    
    local baseDamage = {200, 300, 400}
    local bonusAD = myHero.totalDamage - myHero.baseDamage
    local rDamage = baseDamage[rLevel] + (bonusAD * 1.5)
    
    -- Consider armor reduction (simplified)
    local targetArmor = target.armor
    local armorReduction = 100 / (100 + targetArmor)
    
    return rDamage * armorReduction
end

function DepressiveYasuo2:CalculateFollowUpDamage(target)
    if not target then return 0 end
    
    local totalDamage = 0
    
    -- Q damage if available
    if Ready(_Q) then
        totalDamage = totalDamage + GetQDamage() * 0.7 -- Consider armor
    end
    
    -- E damage if available
    if Ready(_E) and not HasEBuff(target) then
        totalDamage = totalDamage + GetEDamage() * 0.7 -- Consider MR
    end
    
    -- Auto attack damage (1-2 autos after R)
    totalDamage = totalDamage + (myHero.totalDamage * 1.5 * 0.7) -- 1.5 autos with armor consideration
    
    return totalDamage
end

function DepressiveYasuo2:IsHighPriorityTarget(target)
    if not target then return false end
    
    -- Check if target is ADC, Mid laner, or other high priority champions
    local priorityChamps = {
        "Jinx", "Caitlyn", "Ashe", "Vayne", "Tristana", "Lucian", "Ezreal", "Jhin", "MissFortune", "Sivir",
        "Ahri", "Zed", "Yasuo", "Azir", "Syndra", "LeBlanc", "Katarina", "Kassadin", "Orianna", "Viktor",
        "Veigar", "Annie", "Brand", "Xerath", "Lux", "Velkoz", "Ziggs", "Cassiopeia", "Ryze", "Twisted"
    }
    
    for _, champName in ipairs(priorityChamps) do
        if target.charName:find(champName) then
            return true
        end
    end
    
    return false
end

function DepressiveYasuo2:GetSummonerSpellSlot(spellName)
    -- Get summoner spell slot by name
    local summ1 = myHero:GetSpellData(SUMMONER_1)
    local summ2 = myHero:GetSpellData(SUMMONER_2)
    
    if summ1 and summ1.name == spellName then
        return SUMMONER_1
    elseif summ2 and summ2.name == spellName then
        return SUMMONER_2
    end
    
    return nil
end

function DepressiveYasuo2:AdvancedComboLogic(target)
    -- Advanced combo decision making based on game state
    local myHealth = myHero.health / myHero.maxHealth
    local targetHealth = target.health / target.maxHealth
    local hasQ3 = HasQ3()
    local qReady = Ready(_Q)
    local eReady = Ready(_E)
    local rReady = Ready(_R)
    
    -- Aggressive combo (when ahead or target is low)
    if targetHealth < 0.4 or myHealth > 0.7 then
        if hasQ3 and qReady and eReady then
            return "eq3_aggressive"
        elseif eReady and qReady then
            return "eq_aggressive"
        end
    end
    
    -- Safe combo (when behind or low health)
    if myHealth < 0.5 or targetHealth > 0.8 then
        if hasQ3 and qReady then
            return "q3_safe"
        elseif qReady then
            return "q_poke"
        end
    end
    
    -- Standard combo
    return "standard"
end

-- Beyblade System (E-Q3-Flash Combo) Functions - Enhanced with cursor targeting
-- Now supports:
-- 1. Cursor targeting: Selects champion under cursor when pressing T
-- 2. Champion E targets: Can use enemy champions for E positioning
-- 3. Smart fallback: Uses best target if no cursor target found
function DepressiveYasuo2:HandleBeyblade()
    -- Check if Q3 is ready (essential for Beyblade)
    if not HasQ3() or not Ready(_Q) then return end
    
    -- Check if Flash is available
    local flashSlot = self:GetFlashSlot()
    if not flashSlot or not Ready(flashSlot) then return end
    
    -- Find best target for Beyblade (prioritize cursor target)
    local target = self:GetBestBeybladeTargetWithCursor()
    if not target then return end
    
    -- Find best unit to E onto for optimal positioning (including champions)
    local bestUnit = self:GetBestUnitForBeyblade(target)
    if not bestUnit then return end
    
    -- Start the Beyblade combo
    self.beybladeState = "executing_beyblade"
    self.beybladeTarget = target
    self.beybladeStep = 1
    self.beybladeTimer = Game.Timer()
    
    -- Execute first step immediately (E to positioning unit)
    if Ready(_E) and not HasEBuff(bestUnit) then
        Control.CastSpell(HK_E, bestUnit)
        
        -- Queue Q3 with small delay
        DelayAction(function()
            if Ready(_Q) and HasQ3() and self.beybladeState == "executing_beyblade" then
                local pred, chance = DepressivePrediction.GetPrediction(self.beybladeTarget, "Q3")
                local minHitChance = self.Menu.beyblade and self.Menu.beyblade.minHitChance and self.Menu.beyblade.minHitChance:Value() or 2
                
                if pred and chance >= minHitChance then
                    Control.CastSpell(HK_Q, pred)
                else
                    Control.CastSpell(HK_Q, self.beybladeTarget.pos)
                end
                
                -- Queue Flash with delay after Q3
                DelayAction(function()
                    if self.beybladeState == "executing_beyblade" and 
                       self.beybladeTarget and self.beybladeTarget.valid and not self.beybladeTarget.dead then
                        
                        local flashSlot = self:GetFlashSlot()
                        if flashSlot and Ready(flashSlot) then
                            local currentTarget = self.beybladeTarget
                            local distance = GetDistance2D(myHero.pos, currentTarget.pos)
                            
                            -- Calculate optimal flash position (usar máxima distancia del flash)
                            local flashRange = 450 -- Rango máximo del Flash
                            local direction = (currentTarget.pos - myHero.pos):Normalized()
                            
                            -- Siempre flashear la máxima distancia posible hacia el objetivo
                            local flashPos = myHero.pos + direction * flashRange
                            
                            -- Execute Flash
                            Control.SetCursorPos(flashPos)
                            if flashSlot == SUMMONER_1 then
                                Control.KeyDown(HK_SUMMONER_1)
                                Control.KeyUp(HK_SUMMONER_1)
                            else
                                Control.KeyDown(HK_SUMMONER_2)
                                Control.KeyUp(HK_SUMMONER_2)
                            end
                            
                            -- Queue R after Flash if target is airborne and killable
                            DelayAction(function()
                                if Ready(_R) and self:IsTargetAirborne(currentTarget) and self:CanKillWithR(currentTarget) then
                                    Control.CastSpell(HK_R, currentTarget)
                                end
                            end, 0.1)
                        end
                        
                        -- Reset combo state
                        self:ResetBeyblade()
                    end
                end, 0.2)
            end
        end, 0.1)
    end
end

function DepressiveYasuo2:ExecuteBeybladeCombo()
    -- Safety timeout - reset if combo takes too long
    local timeSinceStart = Game.Timer() - self.beybladeTimer
    if timeSinceStart > 2.0 then -- 2 seconds timeout
        self:ResetBeyblade()
    end
    
    -- Check if target is still valid
    if not self.beybladeTarget or not self.beybladeTarget.valid or self.beybladeTarget.dead then
        self:ResetBeyblade()
    end
end

-- Get best target for Beyblade combo with cursor priority - Enhanced version
function DepressiveYasuo2:GetBestBeybladeTargetWithCursor()
    local bestTarget = nil
    local bestScore = 0
    local maxRange = self.Menu.beyblade and self.Menu.beyblade.maxRange and self.Menu.beyblade.maxRange:Value() or 2000
    
    -- Get mouse position for cursor targeting
    local mousePos = Game.mousePos()
    local mousePos2D = {x = mousePos.x, z = mousePos.z}
    
    -- PRIORITY 1: Check if cursor is over an enemy champion
    local cursorTarget = nil
    local cursorDistance = math.huge
    local cursorRange = self.Menu.beyblade and self.Menu.beyblade.cursorRange and self.Menu.beyblade.cursorRange:Value() or 300
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if IsValidTarget(hero, maxRange) then
            local heroPos2D = {x = hero.pos.x, z = hero.pos.z}
            local distanceToCursor = GetDistance2D(mousePos2D, heroPos2D)
            
            -- If cursor is close to this hero (within configured range), prioritize it
            if distanceToCursor <= cursorRange then
                if distanceToCursor < cursorDistance then
                    cursorDistance = distanceToCursor
                    cursorTarget = hero
                end
            end
        end
    end
    
    -- If we found a cursor target, use it with highest priority
    if cursorTarget then
        return cursorTarget
    end
    
    -- PRIORITY 2: If no cursor target, use smart targeting
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if IsValidTarget(hero, maxRange) then
            local distance = GetDistance2D(myHero.pos, hero.pos)
            local healthPercent = hero.health / hero.maxHealth
            
            -- Score based on priority and health
            local score = 1000
            
            -- Prioritize low health targets
            if healthPercent < 0.5 then
                score = score + 500
            elseif healthPercent < 0.7 then
                score = score + 200
            end
            
            -- Prioritize closer targets
            score = score + (maxRange - distance) / 10
            
            -- Prioritize fleeing targets
            if self:IsEnemyFleeing(hero) then
                score = score + 300
            end
            
            -- Prioritize ADC and Mid laners
            local charName = hero.charName:lower()
            if string.find(charName, "jinx") or string.find(charName, "caitlyn") or 
               string.find(charName, "ashe") or string.find(charName, "vayne") or
               string.find(charName, "ahri") or string.find(charName, "zed") or
               string.find(charName, "yasuo") then
                score = score + 300
            end
            
            if score > bestScore then
                bestScore = score
                bestTarget = hero
            end
        end
    end
    
    return bestTarget
end

function DepressiveYasuo2:GetBestBeybladeTarget()
    local bestTarget = nil
    local bestScore = 0
    local maxRange = self.Menu.beyblade.maxRange:Value()
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if IsValidTarget(hero, maxRange) then
            local distance = GetDistance(myHero.pos, hero.pos)
            local healthPercent = hero.health / hero.maxHealth
            
            -- Score based on priority and health
            local score = 1000
            
            -- Prioritize low health targets
            if healthPercent < 0.5 then
                score = score + 500
            end
            
            -- Prioritize closer targets
            score = score + (maxRange - distance) / 10
            
            -- Prioritize ADC and Mid laners
            if self.Menu.ultimate.prioritizeADC:Value() then
                local charName = hero.charName:lower()
                if string.find(charName, "adc") or string.find(charName, "marksman") or 
                   string.find(charName, "jinx") or string.find(charName, "caitlyn") or 
                   string.find(charName, "ashe") or string.find(charName, "vayne") then
                    score = score + 300
                end
            end
            
            if score > bestScore then
                bestScore = score
                bestTarget = hero
            end
        end
    end
    
    return bestTarget
end

-- Get best unit for Beyblade combo (including champions) - Enhanced version
function DepressiveYasuo2:GetBestUnitForBeyblade(target)
    if not target or not target.valid then return nil end
    
    local bestUnit = nil
    local bestScore = 0
    local flashRange = 450 -- Flash range
    local useChampions = self.Menu.beyblade and self.Menu.beyblade.useChampions and self.Menu.beyblade.useChampions:Value()
    if useChampions == nil then useChampions = true end
    
    -- Check enemy champions first (excluding our target) - HIGHEST PRIORITY
    if useChampions then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero and hero.isEnemy and hero ~= target and not hero.dead and hero.visible and 
               not HasEBuff(hero) then
                local distanceToHero = GetDistance2D(myHero.pos, hero.pos)
                if distanceToHero <= SPELL_RANGE.E then
                    local distanceFromHeroToTarget = GetDistance2D(hero.pos, target.pos)
                    
                    -- Target must be within flash range after E
                    if distanceFromHeroToTarget <= flashRange then
                        if distanceFromHeroToTarget >= 200 and distanceFromHeroToTarget <= 1000 then
                            local optimalDistance = 600
                            local distancePenalty = math.abs(distanceFromHeroToTarget - optimalDistance)
                            local score = 3000 - distancePenalty -- HIGHEST SCORE FOR CHAMPIONS
                            
                            -- Bonus for closer heroes
                            score = score + (SPELL_RANGE.E - distanceToHero) / 5
                            
                            if score > bestScore then
                                bestScore = score
                                bestUnit = hero
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Check minions and jungle monsters (including red buff birds)
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.alive and minion.visible and not HasEBuff(minion) then
            local isJungleMonster = minion.team == 300
            local isEnemyMinion = minion.isEnemy
            
            if isJungleMonster or isEnemyMinion then
                local distanceToMinion = GetDistance2D(myHero.pos, minion.pos)
                if distanceToMinion <= SPELL_RANGE.E then
                    local distanceFromMinionToTarget = GetDistance2D(minion.pos, target.pos)
                    
                    -- Target must be within flash range after E
                    if distanceFromMinionToTarget <= flashRange then
                        if distanceFromMinionToTarget >= 200 and distanceFromMinionToTarget <= 1000 then
                            local optimalDistance = 600
                            local distancePenalty = math.abs(distanceFromMinionToTarget - optimalDistance)
                            local baseScore = isJungleMonster and 2000 or 1000
                            local score = baseScore - distancePenalty
                            
                            -- Bonus for closer minions
                            score = score + (SPELL_RANGE.E - distanceToMinion) / 5
                            
                            -- Bonus for jungle monsters (red buff birds, etc.)
                            if isJungleMonster then
                                score = score + 300
                                
                                -- Extra bonus for red buff birds
                                if minion.charName:find("Red") or minion.charName:find("Raptor") then
                                    score = score + 200
                                end
                            end
                            
                            if score > bestScore then
                                bestScore = score
                                bestUnit = minion
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestUnit
end

function DepressiveYasuo2:GetFlashSpell()
    local flash1 = myHero:GetSpellData(SUMMONER_1)
    local flash2 = myHero:GetSpellData(SUMMONER_2)
    
    if flash1 and flash1.name == "SummonerFlash" then
        return SUMMONER_1
    elseif flash2 and flash2.name == "SummonerFlash" then
        return SUMMONER_2
    end
    
    return nil
end

-- Alias for compatibility with Yasuo3.lua mega combo
function DepressiveYasuo2:GetFlashSlot()
    return self:GetFlashSpell()
end

-- Check if target is airborne (has airborne buff)
function DepressiveYasuo2:IsTargetAirborne(target)
    if not target then 
        return false 
    end
    
    -- Check for knockup/airborne buff types (type 30 and 31)
    local buffCount = target.buffCount or 0
    
    for i = 0, buffCount - 1 do
        local buff = target:GetBuff(i)
        if buff and buff.count and buff.count > 0 then
            local bType = buff.type
            
            -- Type 30 = Airborne, Type 31 = Knockup
            if bType == 30 or bType == 31 then
                return true
            end
        end
    end
    
    return false
end

-- Check if enemy is fleeing
function DepressiveYasuo2:IsEnemyFleeing(target)
    if not target or not target.pathing then return false end
    
    -- Check if target is moving away from us
    if target.pathing.hasMovePath and target.pathing.isDashing then
        -- Target is dashing away
        return true
    elseif target.pathing.hasMovePath and target.pathing.moveDir then
        -- Check movement direction
        local moveDir = target.pathing.moveDir
        if moveDir and moveDir.x and moveDir.z then
            local heroToTarget = (target.pos - myHero.pos):Normalized()
            
            -- Calculate dot product to see if moving away
            local dotProduct = moveDir.x * heroToTarget.x + moveDir.z * heroToTarget.z
            
            -- If dot product is positive, target is moving away from us
            return dotProduct > 0.3
        end
    end
    
    return false
end

-- Check if target can be killed with R
function DepressiveYasuo2:CanKillWithR(target)
    if not target then return false end
    
    -- Get target's current HP percentage
    local hpPercent = (target.health / target.maxHealth) * 100
    local killThreshold = self.Menu and self.Menu.combo and self.Menu.combo.rKillThreshold and self.Menu.combo.rKillThreshold:Value() or 30
    
    -- Check if target HP is below kill threshold
    if hpPercent <= killThreshold then
        return true
    end
    
    -- Advanced killable calculation (estimate R damage + follow-up damage)
    local estimatedRDamage = self:GetRDamage()
    local estimatedFollowUpDamage = self:CalculateFollowUpDamage(target)
    local totalDamage = estimatedRDamage + estimatedFollowUpDamage
    
    -- Add safety margin (consider armor/MR reductions)
    local effectiveDamage = totalDamage * 0.8 -- 20% safety margin
    
    return target.health <= effectiveDamage
end

-- Get R damage
function DepressiveYasuo2:GetRDamage()
    local level = myHero:GetSpellData(_R).level
    if level == 0 then return 0 end
    local baseDamage = {200, 300, 400}
    local adRatio = 1.5
    local totalAD = myHero.totalDamage
    return baseDamage[level] + (totalAD * adRatio)
end

-- Get E damage
function DepressiveYasuo2:GetEDamage()
    local level = myHero:GetSpellData(_E).level
    if level == 0 then return 0 end
    local baseDamage = {60, 70, 80, 90, 100}
    local apRatio = 0.6
    local totalAP = myHero.ap
    return baseDamage[level] + (totalAP * apRatio)
end

-- Get Q damage
function DepressiveYasuo2:GetQDamage()
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end
    local baseDamage = {20, 40, 60, 80, 100}
    local adRatio = 1.05
    local totalAD = myHero.totalDamage
    return baseDamage[level] + (totalAD * adRatio)
end

-- Calculate follow-up damage after R (Q, E, auto attacks)
function DepressiveYasuo2:CalculateFollowUpDamage(target)
    if not target then return 0 end
    
    local totalDamage = 0
    
    -- Q damage if available
    if Ready(_Q) then
        totalDamage = totalDamage + self:GetQDamage() * 0.7 -- Consider armor
    end
    
    -- E damage if available and target doesn't have E buff
    if Ready(_E) and not HasEBuff(target) then
        totalDamage = totalDamage + self:GetEDamage() * 0.7 -- Consider MR
    end
    
    -- Auto attack damage (1-2 autos after R)
    totalDamage = totalDamage + (myHero.totalDamage * 1.5 * 0.7) -- 1.5 autos with armor consideration
    
    return totalDamage
end

-- ============================================
-- AUTO WIND WALL SYSTEM (Nuevo - Simple)
-- ============================================

function DepressiveYasuo2:AutoWindWall()
    -- Scan all enemy heroes cada tick
    for i = 1, Game.HeroCount() do
        local enemy = Game.Hero(i)
        if enemy and enemy.team ~= myHero.team and not enemy.dead then
            local spell = enemy.activeSpell
            
            -- Check if enemy is casting a spell
            if spell and spell.valid and spell.name then
                -- Check if this spell is in our blockable list
                local spellData = BlockableSpells[spell.name]
                
                if spellData then
                    -- Get spell info
                    local startPos = Vector(spell.startPos)
                    local endPos = Vector(spell.placementPos)
                    
                    -- Only block spells coming toward us
                    local distToMe = GetDistance2D(startPos, myHero.pos)
                    if distToMe < spellData.range + 200 then
                        
                        -- Check if spell type is blockable
                        if spellData.type == "linear" then
                            -- Linear skillshot - check if it will hit us
                            if self:WillLinearSpellHitMe(startPos, endPos, spellData.radius) then
                                -- Cast W toward the spell
                                Control.CastSpell(HK_W, startPos)
                                return
                            end
                        elseif spellData.type == "targeted" then
                            -- Targeted spell - check if we are the target
                            if spell.target == myHero.handle then
                                Control.CastSpell(HK_W, enemy.pos)
                                return
                            end
                        elseif spellData.type == "circular" then
                            -- Circular skillshot - check distance to center
                            local distToCenter = GetDistance2D(myHero.pos, endPos)
                            if distToCenter < spellData.radius + myHero.boundingRadius then
                                Control.CastSpell(HK_W, startPos)
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

function DepressiveYasuo2:WillLinearSpellHitMe(startPos, endPos, radius)
    -- Calculate the closest point on the spell line to Yasuo
    local direction = (endPos - startPos):Normalized()
    local yasPos = myHero.pos
    
    -- Vector from start to Yasuo
    local toYasuo = Vector(yasPos.x - startPos.x, 0, yasPos.z - startPos.z)
    
    -- Project Yasuo's position onto the spell line
    local dotProduct = toYasuo.x * direction.x + toYasuo.z * direction.z
    
    -- Clamp to the spell line segment
    local spellLength = GetDistance2D(startPos, endPos)
    if dotProduct < 0 then
        dotProduct = 0
    elseif dotProduct > spellLength then
        dotProduct = spellLength
    end
    
    -- Closest point on the line
    local closestPoint = Vector(
        startPos.x + direction.x * dotProduct,
        myHero.pos.y,
        startPos.z + direction.z * dotProduct
    )
    
    -- Distance from Yasuo to the line
    local distToLine = GetDistance2D(myHero.pos, closestPoint)
    
    -- Check if within radius (with some buffer for Yasuo's size)
    return distToLine < (radius + myHero.boundingRadius + 50)
end

function DepressiveYasuo2:ResetBeyblade()
    self.beybladeState = "idle"
    self.beybladeTarget = nil
    self.beybladeStep = 0
    self.beybladeTimer = 0
end

-- Auto W System Functions
-- Initialize the script (AIONext compatible)
if not _G.DepressiveYasuo2Instance then
    _G.DepressiveYasuo2Instance = DepressiveYasuo2()
    if _G.DepressiveAIONextLoaded then
        _G.DepressiveAIONextLoadedChampion = true
    end
end

