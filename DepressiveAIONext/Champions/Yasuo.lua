if _G.__DEPRESSIVE_YASUO_LOADED then return end
_G.__DEPRESSIVE_YASUO_LOADED = true
local Heroes = {"Yasuo"}
if not table.contains(Heroes, myHero.charName) then return end
require("DepressivePrediction")
local PredictionLoaded = false

DelayAction(function()
    PredictionLoaded = _G.DepressivePrediction ~= nil
end, 1.0)
local ScriptVersion = 4.0
local LoadingComplete = false
Callback.Add("Draw", function()
    if not LoadingComplete then
        Draw.Text("[DepressiveYasuo] Waiting for game to load...", 20, myHero.pos2D.x - 120, myHero.pos2D.y + 180, Draw.Color(255, 255, 200, 0))
    end
end)

local GameHeroCount   = Game.HeroCount
local GameHero        = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion      = Game.Minion
local GameTimer       = Game.Timer
local GameLatency     = Game.Latency
local ControlCast     = Control.CastSpell
local ControlKeyDown  = Control.KeyDown
local ControlKeyUp    = Control.KeyUp
local ControlIsKeyDown = Control.IsKeyDown
local DrawCircle      = Draw.Circle
local DrawText        = Draw.Text
local DrawColor       = Draw.Color
local DrawLine        = Draw.Line
local TableInsert     = table.insert
local TableRemove     = table.remove
local MathSqrt        = math.sqrt
local MathMin         = math.min
local MathMax         = math.max
local MathAbs         = math.abs
local MathHuge        = math.huge
local myHero          = myHero

local DangerousSpells = {
    ["RocketGrab"]                = { charName = "Blitzcrank",  delay = 0.25, speed = 1800, isMissile = true,  threat = 10 },
    ["ThreshQMissile"]            = { charName = "Thresh",      delay = 0.50, speed = 1900, isMissile = true,  threat = 10 },
    ["EnchantedCrystalArrow"]     = { charName = "Ashe",        delay = 0.25, speed = 1600, isMissile = true,  threat = 10 },
    ["MorganaQ"]                  = { charName = "Morgana",     delay = 0.25, speed = 1200, isMissile = true,  threat = 10 },
    ["NautilusAnchorDragMissile"] = { charName = "Nautilus",    delay = 0.25, speed = 2000, isMissile = true,  threat = 9 },
    ["SejuaniR"]                  = { charName = "Sejuani",     delay = 0.25, speed = 1600, isMissile = true,  threat = 9 },
    ["LuxLightBinding"]           = { charName = "Lux",         delay = 0.25, speed = 1200, isMissile = true,  threat = 9 },
    ["AhriSeduce"]                = { charName = "Ahri",        delay = 0.25, speed = 1500, isMissile = true,  threat = 9 },
    ["EliseHumanE"]               = { charName = "Elise",       delay = 0.25, speed = 1600, isMissile = true,  threat = 9 },
    ["LeonaZenithBlade"]          = { charName = "Leona",       delay = 0.25, speed = 2000, isMissile = true,  threat = 8 },
    ["BraumR"]                    = { charName = "Braum",       delay = 0.50, speed = 1400, isMissile = true,  threat = 9 },
    ["VarusR"]                    = { charName = "Varus",       delay = 0.25, speed = 1950, isMissile = true,  threat = 9 },
    ["NeekoE"]                    = { charName = "Neeko",       delay = 0.25, speed = 1300, isMissile = true,  threat = 8 },
    ["PykeQRange"]                = { charName = "Pyke",        delay = 0.20, speed = 2000, isMissile = true,  threat = 9 },
    ["FizzR"]                     = { charName = "Fizz",        delay = 0.25, speed = 1300, isMissile = true,  threat = 10 },
    ["IreliaR"]                   = { charName = "Irelia",      delay = 0.40, speed = 2000, isMissile = true,  threat = 8 },
    ["LeblancE"]                  = { charName = "Leblanc",     delay = 0.25, speed = 1750, isMissile = true,  threat = 8 },
    ["LeblancRE"]                 = { charName = "Leblanc",     delay = 0.25, speed = 1750, isMissile = true,  threat = 8 },
    ["SylasE2"]                   = { charName = "Sylas",       delay = 0.25, speed = 1600, isMissile = true,  threat = 8 },
    ["BandageToss"]               = { charName = "Amumu",       delay = 0.25, speed = 2000, isMissile = true,  threat = 8 },
    ["BlindMonkQOne"]             = { charName = "LeeSin",      delay = 0.25, speed = 1800, isMissile = true,  threat = 7 },
    ["IvernQ"]                    = { charName = "Ivern",       delay = 0.25, speed = 1300, isMissile = true,  threat = 7 },
    ["BardQ"]                     = { charName = "Bard",        delay = 0.25, speed = 1500, isMissile = true,  threat = 8 },
    ["NamiRMissile"]              = { charName = "Nami",        delay = 0.50, speed = 850,  isMissile = true,  threat = 8 },
    ["HowlingGaleSpell"]          = { charName = "Janna",       delay = 0.25, speed = 667,  isMissile = true,  threat = 7 },
    ["EzrealR"]                   = { charName = "Ezreal",      delay = 1.00, speed = 2000, isMissile = true,  threat = 8 },
    ["JinxR"]                     = { charName = "Jinx",        delay = 0.60, speed = 1700, isMissile = true,  threat = 8 },
    ["DravenRCast"]               = { charName = "Draven",      delay = 0.25, speed = 2000, isMissile = false, threat = 8 },
    ["GravesChargeShot"]          = { charName = "Graves",      delay = 0.25, speed = 2100, isMissile = true,  threat = 7 },
    ["CaitlynPiltoverPeacemaker"] = { charName = "Caitlyn",     delay = 0.62, speed = 2200, isMissile = true,  threat = 5 },
    ["CaitlynEntrapment"]         = { charName = "Caitlyn",     delay = 0.15, speed = 1600, isMissile = true,  threat = 6 },
    ["EzrealQ"]                   = { charName = "Ezreal",      delay = 0.25, speed = 2000, isMissile = true,  threat = 4 },
    ["EzrealW"]                   = { charName = "Ezreal",      delay = 0.25, speed = 2000, isMissile = true,  threat = 3 },
    ["JinxWMissile"]              = { charName = "Jinx",        delay = 0.60, speed = 3300, isMissile = true,  threat = 5 },
    ["KaisaW"]                    = { charName = "Kaisa",       delay = 0.40, speed = 1750, isMissile = true,  threat = 5 },
    ["SivirQ"]                    = { charName = "Sivir",       delay = 0.25, speed = 1350, isMissile = true,  threat = 4 },
    ["Volley"]                    = { charName = "Ashe",        delay = 0.25, speed = 2000, isMissile = true,  threat = 4 },
    ["AhriOrbofDeception"]        = { charName = "Ahri",        delay = 0.25, speed = 2500, isMissile = true,  threat = 5 },
    ["FlashFrostSpell"]           = { charName = "Anivia",      delay = 0.25, speed = 850,  isMissile = true,  threat = 7 },
    ["BrandQ"]                    = { charName = "Brand",       delay = 0.25, speed = 1600, isMissile = true,  threat = 6 },
    ["BraumQ"]                    = { charName = "Braum",       delay = 0.25, speed = 1700, isMissile = true,  threat = 6 },
    ["EkkoQ"]                     = { charName = "Ekko",        delay = 0.25, speed = 1650, isMissile = true,  threat = 6 },
    ["GragasR"]                   = { charName = "Gragas",      delay = 0.25, speed = 1800, isMissile = true,  threat = 7 },
    ["GragasQ"]                   = { charName = "Gragas",      delay = 0.25, speed = 1000, isMissile = true,  threat = 4 },
    ["IllaoiE"]                   = { charName = "Illaoi",      delay = 0.25, speed = 1900, isMissile = true,  threat = 7 },
    ["JayceShockBlast"]           = { charName = "Jayce",       delay = 0.21, speed = 1450, isMissile = true,  threat = 5 },
    ["JayceShockBlastWallMis"]    = { charName = "Jayce",       delay = 0.15, speed = 2350, isMissile = true,  threat = 6 },
    ["KarmaQ"]                    = { charName = "Karma",       delay = 0.25, speed = 1700, isMissile = true,  threat = 5 },
    ["KarmaQMantra"]              = { charName = "Karma",       delay = 0.25, speed = 1700, isMissile = true,  threat = 6 },
    ["KennenShurikenHurlMissile1"]= { charName = "Kennen",      delay = 0.17, speed = 1700, isMissile = true,  threat = 5 },
    ["LissandraQMissile"]         = { charName = "Lissandra",   delay = 0.25, speed = 2200, isMissile = true,  threat = 5 },
    ["LuluQ"]                     = { charName = "Lulu",        delay = 0.25, speed = 1450, isMissile = true,  threat = 4 },
    ["NeekoQ"]                    = { charName = "Neeko",       delay = 0.25, speed = 1500, isMissile = true,  threat = 4 },
    ["NocturneDuskbringer"]       = { charName = "Nocturne",    delay = 0.25, speed = 1600, isMissile = true,  threat = 4 },
    ["OlafAxeThrowCast"]          = { charName = "Olaf",        delay = 0.25, speed = 1600, isMissile = true,  threat = 4 },
    ["RengarE"]                   = { charName = "Rengar",      delay = 0.25, speed = 1500, isMissile = true,  threat = 6 },
    ["RyzeQ"]                     = { charName = "Ryze",        delay = 0.25, speed = 1700, isMissile = true,  threat = 4 },
    ["SennaW"]                    = { charName = "Senna",       delay = 0.25, speed = 1150, isMissile = true,  threat = 6 },
    ["SennaR"]                    = { charName = "Senna",       delay = 1.00, speed = 20000, isMissile = true, threat = 7 },
    ["TalonW"]                    = { charName = "Talon",       delay = 0.25, speed = 2500, isMissile = true,  threat = 5 },
    ["VeigarBalefulStrike"]       = { charName = "Veigar",      delay = 0.25, speed = 2200, isMissile = true,  threat = 4 },
    ["VelkozQ"]                   = { charName = "Velkoz",      delay = 0.25, speed = 1300, isMissile = true,  threat = 4 },
    ["XerathMageSpear"]           = { charName = "Xerath",      delay = 0.20, speed = 1400, isMissile = true,  threat = 7 },
    ["ZedQ"]                      = { charName = "Zed",         delay = 0.25, speed = 1700, isMissile = true,  threat = 5 },
    ["ZoeE"]                      = { charName = "Zoe",         delay = 0.30, speed = 1700, isMissile = true,  threat = 9 },
    ["ZoeQMissile"]               = { charName = "Zoe",         delay = 0.25, speed = 1200, isMissile = true,  threat = 5 },
    ["ZoeQMis2"]                  = { charName = "Zoe",         delay = 0.00, speed = 2500, isMissile = true,  threat = 6 },
    ["ZyraE"]                     = { charName = "Zyra",        delay = 0.25, speed = 1150, isMissile = true,  threat = 7 },
    ["KogMawVoidOozeMissile"]     = { charName = "KogMaw",      delay = 0.25, speed = 1400, isMissile = true,  threat = 4 },
    ["AnnieQ"]                    = { charName = "Annie",       delay = 0.25, speed = 1400, isMissile = true,  threat = 7 },
    ["Frostbite"]                 = { charName = "Anivia",      delay = 0.25, speed = 1600, isMissile = true,  threat = 5 },
    ["VayneCondemn"]              = { charName = "Vayne",       delay = 0.25, speed = 2200, isMissile = true,  threat = 8 },
    ["VeigarR"]                   = { charName = "Veigar",      delay = 0.25, speed = 500,  isMissile = true,  threat = 10 },
    ["SyndraR"]                   = { charName = "Syndra",      delay = 0.25, speed = 1400, isMissile = true,  threat = 10 },
    ["TristanaR"]                 = { charName = "Tristana",    delay = 0.25, speed = 2000, isMissile = true,  threat = 7 },
    ["NautilusGrandLine"]         = { charName = "Nautilus",    delay = 0.50, speed = 1400, isMissile = true,  threat = 9 },
    ["BrandR"]                    = { charName = "Brand",       delay = 0.25, speed = 1000, isMissile = true,  threat = 6 },
    ["NamiW"]                     = { charName = "Nami",        delay = 0.25, speed = 2000, isMissile = true,  threat = 3 },
    ["GangplankQProceed"]         = { charName = "Gangplank",   delay = 0.25, speed = 2600, isMissile = true,  threat = 4 },
    ["BlindingDart"]              = { charName = "Teemo",       delay = 0.25, speed = 1500, isMissile = true,  threat = 5 },
    ["KayleQ"]                    = { charName = "Kayle",       delay = 0.25, speed = 1600, isMissile = true,  threat = 4 },
    ["PoppyRSpell"]               = { charName = "Poppy",       delay = 0.33, speed = 2000, isMissile = true,  threat = 7 },
    ["YasuoQ3Mis"]                = { charName = "Yasuo",       delay = 0.34, speed = 1200, isMissile = true,  threat = 7 },
    ["AkaliE"]                    = { charName = "Akali",       delay = 0.25, speed = 1800, isMissile = true,  threat = 6 },
    ["AatroxW"]                   = { charName = "Aatrox",      delay = 0.25, speed = 1800, isMissile = true,  threat = 7 },
    ["ApheliosCalibrumQ"]         = { charName = "Aphelios",    delay = 0.35, speed = 1850, isMissile = true,  threat = 5 },
    ["ApheliosR"]                 = { charName = "Aphelios",    delay = 0.50, speed = 2050, isMissile = true,  threat = 7 },
    ["CassiopeiaE"]               = { charName = "Cassiopeia",  delay = 0.15, speed = 2500, isMissile = true,  threat = 4 },
    ["PhosphorusBomb"]            = { charName = "Corki",       delay = 0.25, speed = 1000, isMissile = true,  threat = 4 },
    ["MissileBarrageMissile"]     = { charName = "Corki",       delay = 0.17, speed = 2000, isMissile = true,  threat = 4 },
    ["MissileBarrageMissile2"]    = { charName = "Corki",       delay = 0.17, speed = 2000, isMissile = true,  threat = 5 },
    ["DravenDoubleShot"]          = { charName = "Draven",      delay = 0.25, speed = 1600, isMissile = true,  threat = 6 },
    ["InfectedCleaverMissile"]    = { charName = "DrMundo",     delay = 0.25, speed = 2000, isMissile = true,  threat = 4 },
    ["EliseHumanQ"]               = { charName = "Elise",       delay = 0.25, speed = 2200, isMissile = true,  threat = 4 },
    ["EvelynnQ"]                  = { charName = "Evelynn",     delay = 0.25, speed = 2400, isMissile = true,  threat = 4 },
    ["GnarQMissile"]              = { charName = "Gnar",        delay = 0.25, speed = 2500, isMissile = true,  threat = 4 },
    ["GnarBigQMissile"]           = { charName = "Gnar",        delay = 0.50, speed = 2100, isMissile = true,  threat = 5 },
    ["HeimerdingerE"]             = { charName = "Heimerdinger",delay = 0.25, speed = 1200, isMissile = true,  threat = 6 },
    ["HeimerdingerEUlt"]          = { charName = "Heimerdinger",delay = 0.25, speed = 1200, isMissile = true,  threat = 8 },
    ["JhinRShot"]                 = { charName = "Jhin",        delay = 0.25, speed = 5000, isMissile = true,  threat = 6 },
    ["KatarinaQ"]                 = { charName = "Katarina",    delay = 0.25, speed = 1600, isMissile = true,  threat = 3 },
    ["NullLance"]                 = { charName = "Kassadin",    delay = 0.25, speed = 1400, isMissile = true,  threat = 4 },
    ["KalistaMysticShot"]         = { charName = "Kalista",     delay = 0.25, speed = 2400, isMissile = true,  threat = 4 },
    ["KhazixW"]                   = { charName = "Khazix",      delay = 0.25, speed = 1700, isMissile = true,  threat = 4 },
    ["KledQ"]                     = { charName = "Kled",        delay = 0.25, speed = 1600, isMissile = true,  threat = 6 },
    ["KogMawQ"]                   = { charName = "KogMaw",      delay = 0.25, speed = 1650, isMissile = true,  threat = 3 },
    ["LeblancQ"]                  = { charName = "Leblanc",     delay = 0.25, speed = 2000, isMissile = true,  threat = 4 },
    ["LeblancRQ"]                 = { charName = "Leblanc",     delay = 0.25, speed = 2000, isMissile = true,  threat = 5 },
    ["LissandraEMissile"]         = { charName = "Lissandra",   delay = 0.25, speed = 850,  isMissile = true,  threat = 3 },
    ["LuluWTwo"]                  = { charName = "Lulu",        delay = 0.25, speed = 2250, isMissile = true,  threat = 5 },
    ["LucianW"]                   = { charName = "Lucian",      delay = 0.25, speed = 1600, isMissile = true,  threat = 3 },
    ["LuxLightStrikeKugel"]       = { charName = "Lux",         delay = 0.25, speed = 1200, isMissile = true,  threat = 4 },
    ["SeismicShard"]              = { charName = "Malphite",    delay = 0.25, speed = 1200, isMissile = true,  threat = 4 },
    ["MaokaiQ"]                   = { charName = "Maokai",      delay = 0.37, speed = 1600, isMissile = true,  threat = 4 },
    ["MissFortuneRicochetShot"]   = { charName = "MissFortune", delay = 0.25, speed = 1400, isMissile = true,  threat = 4 },
    ["JavelinToss"]               = { charName = "Nidalee",     delay = 0.25, speed = 1300, isMissile = true,  threat = 6 },
    ["PantheonQ"]                 = { charName = "Pantheon",    delay = 0.25, speed = 1500, isMissile = true,  threat = 5 },
    ["QuinnQ"]                    = { charName = "Quinn",       delay = 0.25, speed = 1550, isMissile = true,  threat = 5 },
    ["RakanQ"]                    = { charName = "Rakan",       delay = 0.25, speed = 1850, isMissile = true,  threat = 3 },
    ["RekSaiQBurrowed"]           = { charName = "RekSai",      delay = 0.13, speed = 1950, isMissile = true,  threat = 5 },
    ["RumbleGrenade"]             = { charName = "Rumble",      delay = 0.25, speed = 2000, isMissile = true,  threat = 4 },
    ["RyzeE"]                     = { charName = "Ryze",        delay = 0.25, speed = 3500, isMissile = true,  threat = 3 },
    ["ShyvanaFireball"]           = { charName = "Shyvana",     delay = 0.25, speed = 1575, isMissile = true,  threat = 5 },
    ["ShyvanaFireballDragon2"]    = { charName = "Shyvana",     delay = 0.33, speed = 1575, isMissile = true,  threat = 7 },
    ["SionE"]                     = { charName = "Sion",        delay = 0.25, speed = 1800, isMissile = true,  threat = 5 },
    ["SkarnerFractureMissile"]    = { charName = "Skarner",     delay = 0.25, speed = 1500, isMissile = true,  threat = 5 },
    ["TwoShivPoison"]             = { charName = "Shaco",       delay = 0.25, speed = 1500, isMissile = true,  threat = 3 },
    ["TahmKenchQ"]                = { charName = "TahmKench",   delay = 0.25, speed = 2800, isMissile = true,  threat = 5 },
    ["TaliyahQMis"]               = { charName = "Taliyah",     delay = 0.25, speed = 3600, isMissile = true,  threat = 4 },
    ["WildCards"]                  = { charName = "TwistedFate", delay = 0.25, speed = 1000, isMissile = true,  threat = 4 },
    ["GoldCardPreAttack"]         = { charName = "TwistedFate", delay = 0,    speed = 1500, isMissile = true,  threat = 8 },
    ["BlueCardPreAttack"]         = { charName = "TwistedFate", delay = 0,    speed = 1500, isMissile = true,  threat = 3 },
    ["RedCardPreAttack"]          = { charName = "TwistedFate", delay = 0,    speed = 1500, isMissile = true,  threat = 5 },
    ["UrgotR"]                    = { charName = "Urgot",       delay = 0.50, speed = 3200, isMissile = true,  threat = 10 },
    ["VarusQMissile"]             = { charName = "Varus",       delay = 0.25, speed = 1900, isMissile = true,  threat = 5 },
    ["VelkozW"]                   = { charName = "Velkoz",      delay = 0.25, speed = 1700, isMissile = true,  threat = 3 },
    ["ViktorPowerTransfer"]       = { charName = "Viktor",      delay = 0.25, speed = 2000, isMissile = true,  threat = 4 },
    ["ViktorDeathRayMissile"]     = { charName = "Viktor",      delay = 0.25, speed = 1050, isMissile = true,  threat = 5 },
    ["XayahQ"]                    = { charName = "Xayah",       delay = 0.50, speed = 2075, isMissile = true,  threat = 4 },
    ["ZiggsQ"]                    = { charName = "Ziggs",       delay = 0.25, speed = 850,  isMissile = true,  threat = 3 },
    ["SowTheWind"]                = { charName = "Janna",       delay = 0.25, speed = 1600, isMissile = true,  threat = 4 },
    ["GalioQ"]                    = { charName = "Galio",       delay = 0.25, speed = 1150, isMissile = true,  threat = 4 },
    ["GravesSmokeGrenade"]        = { charName = "Graves",      delay = 0.15, speed = 1500, isMissile = true,  threat = 4 },
    ["FiddlesticksDarkWind"]      = { charName = "FiddleSticks",delay = 0.25, speed = 1100, isMissile = true,  threat = 3 },
    ["SyndraE"]                   = { charName = "Syndra",      delay = 0.25, speed = 1600, isMissile = false, threat = 7 },
    ["CamilleE"]                  = { charName = "Camille",     delay = 0,    speed = 1900, isMissile = true,  threat = 6 },
    ["DianaQ"]                    = { charName = "Diana",       delay = 0.25, speed = 1900, isMissile = false, threat = 5 },
    ["NamiQ"]                     = { charName = "Nami",        delay = 1.00, speed = MathHuge, isMissile = true, threat = 7 },
    ["FioraW"]                    = { charName = "Fiora",       delay = 0.75, speed = 3200, isMissile = false, threat = 7 },
    ["SennaW"]                    = { charName = "Senna",       delay = 0.25, speed = 1150, isMissile = true,  threat = 6 },

}

local function DistSqr(p1, p2)
    local p2 = p2 or myHero.pos
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return dx * dx + dz * dz
end

local function Dist(p1, p2)
    return MathSqrt(DistSqr(p1, p2 or myHero.pos))
end

local function IsAlive(unit)
    return unit and unit.valid and unit.isTargetable and unit.alive
        and unit.visible and unit.networkID and unit.health > 0 and not unit.dead
end

local function SpellReady(slot)
    return myHero:GetSpellData(slot).currentCd == 0
        and myHero:GetSpellData(slot).level > 0
        and myHero:GetSpellData(slot).mana <= myHero.mana
        and Game.CanUseSpell(slot) == 0
end

local function CountEnemiesInRange(range, pos)
    local p = pos or myHero.pos
    if p.pos then p = p.pos end
    local count = 0
    local rangeSqr = range * range
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero.team ~= myHero.team and IsAlive(hero) and DistSqr(p, hero.pos) < rangeSqr then
            count = count + 1
        end
    end
    return count
end

local function CountAlliesInRange(range, pos)
    local p = pos or myHero.pos
    if p.pos then p = p.pos end
    local count = 0
    local rangeSqr = range * range
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero.isAlly and hero ~= myHero and IsAlive(hero) and DistSqr(p, hero.pos) < rangeSqr then
            count = count + 1
        end
    end
    return count
end

local function CountMinionsInRange(range, pos)
    local p = pos or myHero.pos
    if p.pos then p = p.pos end
    local count = 0
    local rangeSqr = range * range
    for i = 1, GameMinionCount() do
        local m = GameMinion(i)
        if m.team ~= TEAM_ALLY and not m.dead and DistSqr(p, m.pos) < rangeSqr then
            count = count + 1
        end
    end
    return count
end

local function HasBuff(unit, buffName)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name == buffName then
            return true, buff.count, buff.duration
        end
    end
    return false
end

local function IsKnockedUp(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            if buff.type == 30 or buff.type == 31 then
                return true, buff.duration
            end
        end
    end
    return false
end

local function HasQ3(hero)
    return hero:GetSpellData(0).name == "YasuoQ3Wrapper"
end

local function HasFlowShield()
    return HasBuff(myHero, "YasuoPassiveShield") 
end

local function GetFlowPercent()
    local flow = myHero.mana
    local maxFlow = myHero.maxMana
    if maxFlow == 0 then return 0 end
    return (flow / maxFlow) * 100
end

local function PointOnSegmentProjection(segA, segB, point)
    local cx, cy = point.x, point.z
    local ax, ay = segA.x, segA.z
    local bx, by = segB.x, segB.z
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local rS = MathMax(0, MathMin(1, rL))
    local projX = ax + rS * (bx - ax)
    local projZ = ay + rS * (by - ay)
    return projX, projZ, rS == rL
end

local function PredictPosition(unit, delay)
    local predicted = unit.pos
    local remaining = delay
    if not unit.pathing.hasMovePath then
        return predicted
    end
    local lastNode = unit.pos
    for i = unit.pathing.pathIndex, unit.pathing.pathCount do
        local nextNode = unit:GetPath(i)
        local segDist = Dist(lastNode, nextNode)
        local segTime = segDist / unit.ms
        if remaining > segTime then
            remaining = remaining - segTime
            lastNode = nextNode
            predicted = nextNode
        else
            local dir = (nextNode - lastNode):Normalized()
            predicted = lastNode + dir * unit.ms * remaining
            break
        end
    end
    return predicted
end

local function GetHealthPrediction(unit, time)
    if _G.SDK and _G.SDK.Orbwalker then
        return _G.SDK.HealthPrediction:GetPrediction(unit, time)
    elseif _G.PremiumOrbwalker then
        return _G.PremiumOrbwalker:GetHealthPrediction(unit, time)
    end
    return unit.health
end

local function ConvertHitChance(menuVal, hitChance)
    if menuVal == 1 then return hitChance >= 3 end
    if menuVal == 2 then return hitChance >= 4 end
    return hitChance >= 6
end

class "WindSamurai"
local PredictionLoaded = false

function WindSamurai:__init()
    LoadingComplete = true
    self.QData = { speed = MathHuge, range = 475, delay = 0.35, radius = 40, collision = {nil}, type = "linear" }
    self.Q3Data = { speed = 1500, range = 1060, delay = 0.35, radius = 90, collision = {nil}, type = "linear" }
    self.ERange = 475
    self.ESpeed = 715
    self.EDashDist = 475
    self.RRange = 1400
    self.QCircleWidth = 230
    self.eDashCache = {}
    self.comboTarget = nil
    self.lastE = 0
    self.lastQ = 0
    self.lastW = 0
    self.lastMove = 0
    self.lastComboAction = 0
    self.windwallActive = false
    self.blockNextQ = false
    self.pendingUlt = false
    self.lastAirbladeTime = 0
    self.beybladeState = "idle"
    self.beybladeTimer = 0
    self.lockedBeybladeTarget = nil
    self.comboStage = "NEUTRAL" 
    self.tradeScore = 0
    self.heroUnits = {}
    self:CacheHeroes()
    self:BuildMenu()
    self:SetupOrbwalkerHooks()
    self:LoadPrediction()
    Callback.Add("Tick", function() self:OnTick() end)
    Callback.Add("Draw", function() self:OnDraw() end)
end

function WindSamurai:CacheHeroes()
    for i = 1, GameHeroCount() do
        local h = GameHero(i)
        self.heroUnits[i] = { unit = h, lastSpell = nil }
    end
end

function WindSamurai:SetupOrbwalkerHooks()
    if _G.SDK and _G.SDK.Orbwalker then
        _G.SDK.Orbwalker:OnPreMovement(function(args)
            if self.lastMove + 150 > GetTickCount() then
                args.Process = false
            else
                args.Process = true
                self.lastMove = GetTickCount()
            end
        end)
    end
end

function WindSamurai:LoadPrediction()
    if not PredictionLoaded then

        DelayAction(function()
            PredictionLoaded = _G.DepressivePrediction ~= nil
            if PredictionLoaded then
                print("[DepressiveYasuo] DepressivePrediction linked.")
            else
                print("[DepressiveYasuo] DepressivePrediction not ready yet.")
            end
        end, 0.5)
    end
end

function WindSamurai:BuildMenu()
    self.menu = MenuElement({type = MENU, id = "yasuoDepressive", name = "[DepressiveAIONext] Yasuo"})
    self.menu:MenuElement({name = " ", drop = {"The Wind Samurai v" .. ScriptVersion}})
    self.menu:MenuElement({name = "Ping (ms)", id = "ping", value = 30, min = 0, max = 200, step = 5})
    self.menu:MenuElement({type = MENU, id = "combo", name = "[Combo] Settings"})
        self.menu.combo:MenuElement({id = "useQ", name = "Use [Q1/Q2]", value = true})
        self.menu.combo:MenuElement({id = "useQ3", name = "Use [Q3]", value = true})
        self.menu.combo:MenuElement({id = "q3Mode", name = "[Q3] Priority", value = 1, drop = {"Circle (EQ3)", "Line (Ranged)"}})
        self.menu.combo:MenuElement({id = "useE", name = "Use [E]", value = true})
        self.menu.combo:MenuElement({id = "eMode", name = "[E] Logic", value = 1, drop = {"Towards Target", "Towards Cursor", "Smart (Auto)"}})
        self.menu.combo:MenuElement({id = "eGapRange", name = "[E] Gap Close Range", value = 900, min = 475, max = 1800, step = 50})
        self.menu.combo:MenuElement({id = "noETower", name = "Don't [E] into Tower", value = true})
        self.menu.combo:MenuElement({id = "eqCombo", name = "[EQ] Combo (Dash + Q)", value = true})
        self.menu.combo:MenuElement({id = "smartEQ", name = "[Smart EQ] Only Q if circle hits target", value = true})
        self.menu.combo:MenuElement({id = "eEngage", name = "[E Engage] Path through minions to target", value = true})
    self.menu:MenuElement({type = MENU, id = "walljump", name = "[Wall Jump] Settings"})
        self.menu.walljump:MenuElement({id = "key", name = "Wall Jump Key", key = string.byte("Z")})
        self.menu.walljump:MenuElement({id = "draw", name = "Show Wall Jump Indicator", value = true})
        self.menu.combo:MenuElement({type = MENU, id = "ign", name = "Ignite Settings"})
            self.menu.combo.ign:MenuElement({id = "use", name = "Use Ignite", value = true})
            self.menu.combo.ign:MenuElement({id = "mode", name = "Mode", value = 2, drop = {"Kill Steal Only", "In Fight if Killable"}})
        self.menu.combo:MenuElement({type = MENU, id = "trade", name = "Smart Trade Optimizer"})
            self.menu.combo.trade:MenuElement({id = "enable", name = "Enable Smart Trading", value = true})
            self.menu.combo.trade:MenuElement({id = "shield", name = "Prefer trading with Flow Shield", value = true})
            self.menu.combo.trade:MenuElement({id = "flowPct", name = "Min Flow % to engage", value = 80, min = 0, max = 100, step = 5})
            self.menu.combo.trade:MenuElement({id = "antiGank", name = "Anti-Gank: limit E if outnumbered", value = true})
    self.menu:MenuElement({type = MENU, id = "ult", name = "[Ultimate] Settings"})
        self.menu.ult:MenuElement({name = " ", drop = {"--- Teamfight Settings ---"}})
        self.menu.ult:MenuElement({id = "team", name = "[R] in Teamfight", value = true})
        self.menu.ult:MenuElement({id = "teamMin", name = "  Min enemies airborne", value = 2, min = 2, max = 5})
        self.menu.ult:MenuElement({name = " ", drop = {"--- Airblade Settings ---"}})
        self.menu.ult:MenuElement({id = "airblade", name = "[Airblade] EQ -> R", value = true})
        self.menu.ult:MenuElement({id = "noRDash", name = "Don't R while dashing", value = true})
    self.menu:MenuElement({type = MENU, id = "harass", name = "[Harass] Settings"})
        self.menu.harass:MenuElement({id = "useQ", name = "Use [Q1/Q2]", value = true})
        self.menu.harass:MenuElement({id = "useQ3", name = "Use [Q3]", value = true})
        self.menu.harass:MenuElement({id = "stackQ", name = "Stack Q on minions", value = true})
    self.menu:MenuElement({type = MENU, id = "clear", name = "[LaneClear] Settings"})
        self.menu.clear:MenuElement({id = "useQ", name = "Use [Q1/Q2]", value = true})
        self.menu.clear:MenuElement({id = "useQ3", name = "Use [Q3]", value = true})
        self.menu.clear:MenuElement({id = "q3Min", name = "  Min minions for [Q3]", value = 3, min = 1, max = 7})
        self.menu.clear:MenuElement({id = "useE", name = "Use [E]", value = true})
        self.menu.clear:MenuElement({id = "eLH", name = "  [E] Logic", value = 1, drop = {"Last Hit Only", "Always"}})
        self.menu.clear:MenuElement({id = "eqClear", name = "[EQ] Clear (Multi-hit)", value = true})
        self.menu.clear:MenuElement({id = "eqMin", name = "  Min minions for [EQ]", value = 2, min = 2, max = 7})
        self.menu.clear:MenuElement({id = "noETower", name = "Don't [E] into Tower", value = true})
    self.menu:MenuElement({type = MENU, id = "jungle", name = "[JungleClear] Settings"})
        self.menu.jungle:MenuElement({id = "useQ", name = "Use [Q1/Q2]", value = true})
        self.menu.jungle:MenuElement({id = "useQ3", name = "Use [Q3]", value = true})
        self.menu.jungle:MenuElement({id = "useEQ", name = "[EQ] combo on monsters", value = true})
    self.menu:MenuElement({type = MENU, id = "lasthit", name = "[LastHit] Settings"})
        self.menu.lasthit:MenuElement({id = "useQ", name = "Use [Q1/Q2]", value = true})
        self.menu.lasthit:MenuElement({id = "useQ3", name = "Use [Q3]", value = true})
        self.menu.lasthit:MenuElement({id = "useE", name = "Use [E]", value = true})
        self.menu.lasthit:MenuElement({id = "noETower", name = "Don't [E] into Tower", value = true})
    self.menu:MenuElement({type = MENU, id = "flee", name = "[Flee] Settings"})
        self.menu.flee:MenuElement({id = "useE", name = "Use [E] to flee", value = true})
        self.menu.flee:MenuElement({id = "noETower", name = "Don't [E] into Tower", value = true})
        self.menu.flee:MenuElement({id = "useQ3", name = "Use [Q3] while fleeing", value = true})
    self.menu:MenuElement({type = MENU, id = "windwall", name = "[Wind Wall] Settings"})
        self.menu.windwall:MenuElement({id = "enable", name = "Enable Auto Wind Wall", value = true})
        self.menu.windwall:MenuElement({id = "onlyCombo", name = "Only in Combo Mode", value = false})
        self.menu.windwall:MenuElement({id = "minThreat", name = "Min Threat Score to block", value = 5, min = 1, max = 10})
        self.menu.windwall:MenuElement({id = "hpSafe", name = "Always block if HP% below", value = 30, min = 5, max = 80, step = 5})
        self.menu.windwall:MenuElement({type = MENU, id = "spells", name = "Spells to Block"})

    DelayAction(function()
        for i = 1, GameHeroCount() do
            local hero = GameHero(i)
            if hero.team ~= myHero.team then
                for spellName, data in pairs(DangerousSpells) do
                    if data.charName == hero.charName then
                        self.menu.windwall.spells:MenuElement({
                            id = spellName,
                            name = data.charName .. " | " .. spellName .. " [" .. data.threat .. "]",
                            value = (data.threat >= 5)
                        })
                    end
                end
            end
        end
    end, 0.02)
    self.menu:MenuElement({type = MENU, id = "pred", name = "[Prediction] Settings"})
        self.menu.pred:MenuElement({name = " ", drop = {"Engine: DepressivePrediction"}})
        self.menu.pred:MenuElement({id = "hcQ", name = "Hitchance [Q]", value = 1, drop = {"Normal", "High", "Immobile"}})
        self.menu.pred:MenuElement({id = "hcQ3", name = "Hitchance [Q3]", value = 2, drop = {"Normal", "High", "Immobile"}})
    self.menu:MenuElement({type = MENU, id = "draw", name = "[Drawing] Settings"})
        self.menu.draw:MenuElement({id = "qRange", name = "Draw [Q] Range", value = true})
        self.menu.draw:MenuElement({id = "q3Range", name = "Draw [Q3] Range", value = true})
        self.menu.draw:MenuElement({id = "eRange", name = "Draw [E] Range", value = true})
        self.menu.draw:MenuElement({id = "eGap", name = "Draw [E] Gap Close Range", value = false})
        self.menu.draw:MenuElement({id = "rRange", name = "Draw [R] Range", value = false})
        self.menu.draw:MenuElement({id = "killable", name = "Draw Kill Indicator", value = true})
        self.menu.draw:MenuElement({id = "flow", name = "Draw Flow Shield Status", value = true})
        self.menu.draw:MenuElement({id = "qTimer", name = "Draw Q3 Timer", value = true})
        self.menu.draw:MenuElement({id = "comboState", name = "Draw Combo Stage", value = true})
        self.menu.draw:MenuElement({id = "towerDive", name = "Draw Tower Dive Info", value = true})
        self.menu.draw:MenuElement({id = "eDashPos", name = "Draw [E] Future Positions", value = true})
        self.menu.draw:MenuElement({id = "eqCircle", name = "Draw [EQ] Hit Circle Preview", value = true})
    self.menu:MenuElement({type = MENU, id = "airblade", name = "[Airblade] Settings"})
        self.menu.airblade:MenuElement({id = "enabled", name = "Enable Airblade (Key)", value = true})
        self.menu.airblade:MenuElement({id = "key", name = "Airblade Key", key = string.byte("G")})
        self.menu.airblade:MenuElement({id = "qDelay", name = "Q Delay after E (ms)", value = 60, min = 30, max = 150, step = 5})
        self.menu.airblade:MenuElement({id = "autoAirblade", name = "Auto Airblade (when enemy airborne)", value = true})
        self.menu.airblade:MenuElement({id = "championsOnly", name = "Prefer champions as E target", value = true})
    self.menu:MenuElement({type = MENU, id = "beyblade", name = "[Beyblade E+Q3+Flash] Settings"})
        self.menu.beyblade:MenuElement({id = "enabled", name = "Enable Beyblade", value = true})
        self.menu.beyblade:MenuElement({id = "key", name = "Beyblade Key", key = string.byte("T")})
        self.menu.beyblade:MenuElement({id = "cursorDist", name = "Max cursor-to-target dist", value = 500, min = 100, max = 1500, step = 50})
        self.menu.beyblade:MenuElement({id = "maxDist", name = "Max range to target", value = 1200, min = 400, max = 2000, step = 50})
        self.menu.beyblade:MenuElement({id = "flashDist", name = "Flash Distance", value = 400, min = 100, max = 700, step = 25})
        self.menu.beyblade:MenuElement({id = "reqQ3", name = "Only with Q3", value = true})
        self.menu.beyblade:MenuElement({id = "style", name = "Flash Style", value = 1, drop = {"Toward Target", "To Cursor", "Behind Target"}})
        self.menu.beyblade:MenuElement({id = "offset", name = "Behind Offset", value = 75, min = 0, max = 300, step = 25})
end

function WindSamurai:OnTick()
    if myHero.dead or Game.IsChatOpen() then return end
    if (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) then return end
    if ControlIsKeyDown(HK_Q) then
        ControlKeyUp(HK_Q)
    end
    self:RefreshQDelay()
    self:UpdateEDashCache()
    if self.windwallActive and not SpellReady(_W) then
        self.windwallActive = false
    end
    self:UpdateComboStage()
    self:SmartWindWall()
    if self.menu.airblade.enabled:Value() and self.menu.airblade.key:Value() then
        self:ManualAirblade()
    end
    if self.menu.airblade.autoAirblade:Value() then
        self:AutoAirbladeLogic()
    end
    if self.menu.beyblade.enabled:Value() and self.menu.beyblade.key:Value() then
        self:HandleBeyblade()
    end
    if self.beybladeState ~= "idle" then
        self:ExecuteBeybladeCombo()
    end
    if self.pendingUlt then
        self:TryUltimate()
    end
    if self.menu.walljump.key:Value() then
        self:WallJump()
    end
    if _G.SDK.Orbwalker.Modes[0] then
        self.pendingUlt = false
        self:Combo()
        self:TryUltimate()
    elseif _G.SDK.Orbwalker.Modes[1] then
        self:Harass()
    elseif _G.SDK.Orbwalker.Modes[3] then
        self:JungleClear()
        self:LaneClear()
    elseif _G.SDK.Orbwalker.Modes[4] then
        self:LastHit()
    elseif _G.SDK.Orbwalker.Modes[5] then
        self:Flee()
    end
end

function WindSamurai:UpdateComboStage()
    local nearbyEnemies = CountEnemiesInRange(1200)
    local nearbyAllies = CountAlliesInRange(1200)
    local hpPct = myHero.health / myHero.maxHealth
    if nearbyEnemies == 0 then
        self.comboStage = "NEUTRAL"
    elseif hpPct < 0.2 and nearbyEnemies > nearbyAllies then
        self.comboStage = "DISENGAGE"
    elseif nearbyEnemies <= nearbyAllies + 1 then
        self.comboStage = "ALL_IN"
    else
        self.comboStage = "ENGAGING"
    end
end

function WindSamurai:ShouldTrade()
    if not self.menu.combo.trade.enable:Value() then return true end
    if self.menu.combo.trade.antiGank:Value() then
        local enemies = CountEnemiesInRange(1400)
        local allies = CountAlliesInRange(1400)
        if enemies >= allies + 2 then
            return false
        end
    end
    if self.menu.combo.trade.shield:Value() then
        local flowPct = GetFlowPercent()
        if flowPct < self.menu.combo.trade.flowPct:Value() then
            if not HasFlowShield() then
                return false
            end
        end
    end
    return true
end

function WindSamurai:EstimateTowerShots()
    local turrets = _G.SDK.ObjectManager:GetEnemyTurrets()
    local towerRange = 88.5 + 750 + myHero.boundingRadius / 2
    local underTower = false
    for i = 1, #turrets do
        local t = turrets[i]
        if t and not t.dead and Dist(myHero.pos, t.pos) < towerRange then
            underTower = true
            local towerDmg = 180 + 40 * (GameTimer() / 60)
            local armorMod = 100 / (100 + myHero.armor)
            local effectiveDmg = towerDmg * armorMod
            local shotsToKill = math.ceil(myHero.health / effectiveDmg)
            return underTower, shotsToKill, effectiveDmg
        end
    end
    return false, 99, 0
end

function WindSamurai:GetDashEndPos(obj)
    local myPos = Vector(myHero.pos.x, myHero.pos.y, myHero.pos.z)
    local objPos = Vector(obj.pos.x, myHero.pos.y, obj.pos.z)
    return myPos:Extended(objPos, self.EDashDist)
end

function WindSamurai:GetEDelay()
    local eSpeed = self.ESpeed + myHero.ms * 0.95
    return (self.EDashDist / eSpeed + self.menu.ping:Value() / 1000)
end

function WindSamurai:GetEDmgDelay(target)
    local eSpeed = self.ESpeed + myHero.ms * 0.95
    local d = Dist(myHero.pos, target.pos)
    return (d / eSpeed + self.menu.ping:Value() / 1000)
end

function WindSamurai:IsSafePosition(pos)
    local turrets = _G.SDK.ObjectManager:GetEnemyTurrets()
    local range = 88.5 + 750 + myHero.boundingRadius / 2
    local rangeSqr = range * range
    for i = 1, #turrets do
        local t = turrets[i]
        if t and not t.dead and DistSqr(pos, t.pos) < rangeSqr then
            return false
        end
    end
    return true
end

function WindSamurai:UpdateEDashCache()
    if self.lastCacheUpdate and GetTickCount() - self.lastCacheUpdate < 33 then return end
    self.lastCacheUpdate = GetTickCount()
    self.eDashCache = {}
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.ERange)
    local jungle  = _G.SDK.ObjectManager:GetMonsters(self.ERange)
    local heroes  = _G.SDK.ObjectManager:GetEnemyHeroes(self.ERange)

    local function ProcessUnit(unit)
        if IsAlive(unit) and not HasBuff(unit, "YasuoE") then
            local endPos = self:GetDashEndPos(unit)
            local safe = self:IsSafePosition(endPos)
            local wallCross = false
            local dx = endPos.x - myHero.pos.x
            local dz = endPos.z - myHero.pos.z
            local len = MathSqrt(dx * dx + dz * dz)
            if len > 0 then
                dx = dx / len
                dz = dz / len
                local hitWall = false
                local wallStartDist = 0
                for i = 25, 475, 25 do
                    if MapPosition:inWall({x = myHero.pos.x + dx * i, z = myHero.pos.z + dz * i}) then
                        hitWall = true
                        wallStartDist = i
                        break
                    end
                end
                if hitWall then
                    if not MapPosition:inWall(endPos) then
                        wallCross = true
                    else
                        for i = 25, 300, 25 do
                            if not MapPosition:inWall({x = endPos.x + dx * i, z = endPos.z + dz * i}) then
                                local wallThickness = (475 + i) - wallStartDist
                                local penetrated = 475 - wallStartDist
                                if penetrated >= wallThickness / 2 then
                                    wallCross = true
                                end
                                break
                            end
                        end
                    end
                end
            end
            TableInsert(self.eDashCache, {
                unit      = unit,
                endPos    = endPos,
                safe      = safe,
                wallCross = wallCross,
            })
        end
    end
    for i = 1, #minions do ProcessUnit(minions[i]) end
    for i = 1, #jungle do ProcessUnit(jungle[i]) end
    for i = 1, #heroes do ProcessUnit(heroes[i]) end
end

function WindSamurai:WillEQHitTarget(dashEndPos, target)
    if not target or not IsAlive(target) then return false, MathHuge, nil end
    local eDelay = self:GetEDelay()
    local predictedPos = PredictPosition(target, eDelay)
    local d = Dist(dashEndPos, predictedPos)
    local hitRadius = self.QCircleWidth + (target.boundingRadius or 0)
    return d <= hitRadius, d, predictedPos
end

function WindSamurai:RefreshQDelay()
    local spell = myHero.activeSpell
    if spell and spell.valid then
        if spell.name == "YasuoQ1" or spell.name == "YasuoQ2" then
            self.QData.delay = spell.windup
        elseif spell.name == "YasuoQ3" then
            self.Q3Data.delay = spell.windup
        end
    end
end

function WindSamurai:GetTarget(range)
    local heroes = _G.SDK.ObjectManager:GetEnemyHeroes(range, false)
    return _G.SDK.TargetSelector:GetTarget(heroes)
end

function WindSamurai:WallJump()
    if not SpellReady(_E) or myHero.pathing.isDashing then return end
    if self.lastE + 200 > GetTickCount() then return end
    local bestObj = nil
    local bestDist = MathHuge
    local maxCursorDist = 200
    for _, cache in ipairs(self.eDashCache) do
        if cache.wallCross then
            local d = mousePos:DistanceTo(cache.endPos)
            if d < bestDist and d <= maxCursorDist then
                bestDist = d
                bestObj = cache.unit
            end
        end
    end
    if bestObj then
        ControlCast(HK_E, bestObj)
        self.lastE = GetTickCount()
    end
end

function WindSamurai:Combo()
    if self.windwallActive then return end
    self.comboTarget = nil
    if not myHero.pathing.isDashing then
        self.blockNextQ = false
    end
    local canTrade = self:ShouldTrade()
    if self.menu.combo.useE:Value() and SpellReady(_E) and canTrade
        and self.lastE + 120 < GetTickCount() and not myHero.pathing.isDashing then
        local gapRange = self.menu.combo.eGapRange:Value()
        local target = self:GetTarget(gapRange)
        local aaRange = myHero.range + myHero.boundingRadius
        if target then
            self.comboTarget = target
            local eMode = self.menu.combo.eMode:Value()
            local eEngage = self.menu.combo.eEngage:Value()
            if eMode == 3 then
                if Dist(myHero.pos, target.pos) > aaRange + 100 then
                    eMode = 1
                else
                    eMode = 2
                end
            end
            if eMode == 1 then
                local bestObj, bestDist, hitWithEQ, bestEndPos = self:FindBestEToTarget(target, self.menu.combo.noETower:Value())
                if bestObj then
                    local currentDist = Dist(myHero.pos, target.pos)
                    local qReadySoon = myHero:GetSpellData(_Q).currentCd <= self:GetEDelay() + 0.1
                    local isTarget = (bestObj.networkID == target.networkID)
                    if not (bestDist < currentDist or (hitWithEQ and qReadySoon) or isTarget) then
                        for _, cache in ipairs(self.eDashCache) do
                            if cache.unit.networkID == target.networkID and (not self.menu.combo.noETower:Value() or cache.safe) then
                                bestObj = cache.unit
                                bestDist = Dist(cache.endPos, target.pos)
                                hitWithEQ, _ = self:WillEQHitTarget(cache.endPos, target)
                                isTarget = true
                                break
                            end
                        end
                    end
                    if bestDist < currentDist or (hitWithEQ and qReadySoon) or isTarget then
                        local canE = _G.SDK.Orbwalker:CanMove() and (currentDist > aaRange or (hitWithEQ and qReadySoon) or eEngage or isTarget)
                        if canE then
                            ControlCast(HK_E, bestObj)
                            self.lastE = GetTickCount()
                            if self.menu.combo.eqCombo:Value() and hitWithEQ and qReadySoon then
                                self.blockNextQ = true
                                local tmpTarget = target

                                DelayAction(function()
                                    self:ExecuteEQ(tmpTarget)
                                end, self:GetEDelay() - 0.12)
                            end
                        end
                    end
                end
            elseif eMode == 2 then
                local bestObj, bestDist = self:FindBestEToCursor(self.menu.combo.noETower:Value())
                if bestObj and bestDist < mousePos:DistanceTo(myHero.pos) then
                    ControlCast(HK_E, bestObj)
                    self.lastE = GetTickCount()
                    if self.menu.combo.eqCombo:Value() and target then
                        local endPos = self:GetDashEndPos(bestObj)
                        local eqHit = self:WillEQHitTarget(endPos, target)
                        if eqHit then
                            self.blockNextQ = true
                            local tmpTarget = target

                            DelayAction(function()
                                self:ExecuteEQ(tmpTarget)
                            end, self:GetEDelay() - 0.10)
                        end
                    end
                end
            end
        end
    end
    if self.menu.combo.useQ3:Value() and not self.blockNextQ then
        local q3Target = self:GetTarget(self.Q3Data.range)
        if q3Target then
            self:CastQ3(q3Target)
        end
    end
    if self.menu.combo.useQ:Value() then
        local qTarget = self:GetTarget(self.QData.range)
        if qTarget then
            self:CastQ(qTarget)
        elseif self.menu.harass.stackQ:Value() then
            self:StackQOnMinions()
        end
    end
    self:HandleIgnite()
end

function WindSamurai:ExecuteEQ(target)
    if not myHero.pathing.isDashing or not SpellReady(_Q) then return end
    local targetPos = target.pos
    if self.menu.combo.smartEQ:Value() then
        targetPos = PredictPosition(target, 0.1)
    end
    local d = Dist(myHero.pos, targetPos)
    if d <= self.QCircleWidth + (target.boundingRadius or 0) then
        ControlKeyDown(HK_Q)
        if _G.SDK and _G.SDK.Orbwalker then
            _G.SDK.Orbwalker:SetAttack(false)
        end

        DelayAction(function()
            ControlKeyUp(HK_Q)

            DelayAction(function()
                if _G.SDK and _G.SDK.Orbwalker then
                    _G.SDK.Orbwalker:SetAttack(true)
                end
            end, 0.35)
        end, 0.05)
    end
end

function WindSamurai:TryUltimate()
    if not SpellReady(_R) then return end
    local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(self.RRange)
    for i = 1, #enemies do
        local enemy = enemies[i]
        local knocked, duration = IsKnockedUp(enemy)
        if knocked then
            if self.menu.ult.noRDash:Value() and myHero.pathing.isDashing then
                self.pendingUlt = true
                return
            end
            if self.menu.ult.team:Value() then
                local knockCount = self:CountKnockedInRange(400, enemy)
                if knockCount >= self.menu.ult.teamMin:Value() then
                    if self.menu.ult.airblade:Value() and myHero.attackSpeed > 1.33 then
                        local eTarget = self:FindAnyETarget()
                        if eTarget and SpellReady(_E) and Dist(eTarget.pos, enemy.pos) < self.RRange
                            and self.lastE + 120 < GetTickCount() then
                            if myHero:GetSpellData(_Q).currentCd <= (GameLatency() * 0.001 + 1.1) then
                                ControlCast(HK_E, eTarget)
                                self.lastE = GetTickCount()
                            end

                            DelayAction(function()
                                if not myHero.pathing.isDashing and Dist(myHero.pos, enemy.pos) <= self.RRange then
                                    ControlCast(HK_R, enemy)
                                end
                            end, 0.12)
                            self.pendingUlt = false
                            return
                        end
                    end
                    ControlCast(HK_R, enemy)
                    self.pendingUlt = false
                    return
                end
            end
        end
    end
    self.pendingUlt = false
end

function WindSamurai:CountKnockedInRange(range, centerUnit)
    local count = 0
    local rangeSqr = range * range
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero.team ~= myHero.team and IsAlive(hero) and hero ~= centerUnit and DistSqr(centerUnit.pos, hero.pos) < rangeSqr then
            if IsKnockedUp(hero) then
                count = count + 1
            end
        end
    end
    return count + 1
end

function WindSamurai:GetQDamage(target)
    local lvl = myHero:GetSpellData(0).level
    if lvl <= 0 then return 0 end
    local base = ({20, 45, 70, 95, 120})[lvl]
    local ad = myHero.totalDamage
    return _G.SDK.Damage:CalculateDamage(myHero, target, _G.SDK.DAMAGE_TYPE_PHYSICAL, base + ad)
end

function WindSamurai:GetEDamage(target)
    local lvl = myHero:GetSpellData(_E).level
    if lvl <= 0 then return 0 end
    local bonus = 1
    local hasBuff, count = HasBuff(myHero, "YasuoDashScalar")
    if hasBuff then
        bonus = 1 + 0.25 * MathMin(count, 2)
    end
    local base = ({60, 70, 80, 90, 100})[lvl]
    local bonusAD = 0.2 * myHero.bonusDamage
    local ap = 0.6 * myHero.ap
    return CalcMagicalDamage(myHero, target, (base * bonus) + bonusAD + ap)
end

function WindSamurai:GetRDamage(target)
    local lvl = myHero:GetSpellData(_R).level
    if lvl <= 0 then return 0 end
    return getdmg("R", target, myHero) or 0
end

function WindSamurai:GetFullComboDamage(target)
    local qDmg = SpellReady(_Q) and self:GetQDamage(target) * 2 or 0
    local eDmg = SpellReady(_E) and self:GetEDamage(target) or 0
    local rDmg = SpellReady(_R) and self:GetRDamage(target) or 0
    local aaDmg = (getdmg("AA", target, myHero) or 0) * 3
    local ignDmg = self:GetIgniteDamage()
    return qDmg + eDmg + rDmg + aaDmg + ignDmg
end

function WindSamurai:CanKillWithCombo(target)
    return self:GetFullComboDamage(target) >= target.health
end

function WindSamurai:GetIgniteDamage()
    local ign1 = myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Game.CanUseSpell(SUMMONER_1) == 0
    local ign2 = myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Game.CanUseSpell(SUMMONER_2) == 0
    if ign1 or ign2 then
        return 50 + 20 * myHero.levelData.lvl
    end
    return 0
end

function WindSamurai:HandleIgnite()
    if not self.menu.combo.ign.use:Value() then return end
    local ignSlot = nil
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerDot" and Game.CanUseSpell(SUMMONER_1) == 0 then
        ignSlot = HK_SUMMONER_1
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerDot" and Game.CanUseSpell(SUMMONER_2) == 0 then
        ignSlot = HK_SUMMONER_2
    end
    if not ignSlot then return end
    local mode = self.menu.combo.ign.mode:Value()
    local target = self:GetTarget(600)
    if not target then return end
    local ignDmg = 50 + 20 * myHero.levelData.lvl - (target.hpRegen * 3)
    if mode == 1 then
        if ignDmg >= target.health then
            ControlCast(ignSlot, target)
        end
    elseif mode == 2 then
        if self:CanKillWithCombo(target) and Dist(myHero.pos, target.pos) < 600 then
            ControlCast(ignSlot, target)
        end
    end
end

function WindSamurai:Harass()
    if self.windwallActive then return end
    if self.menu.harass.useQ3:Value() then
        local t = self:GetTarget(self.Q3Data.range)
        if t then self:CastQ3(t) end
    end
    if self.menu.harass.useQ:Value() then
        local t = self:GetTarget(self.QData.range)
        if t then
            self:CastQ(t)
        elseif self.menu.harass.stackQ:Value() then
            self:StackQOnMinions()
        end
    end
end

function WindSamurai:StackQOnMinions()
    if self.windwallActive or HasQ3(myHero) then return end
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.QData.range - 50)
    if not next(minions) then return end
    for i = 1, #minions do
        local m = minions[i]
        if SpellReady(_Q) and not myHero.pathing.isDashing
            and _G.SDK.Orbwalker:CanMove(myHero)
            and self.lastQ + 300 < GetTickCount() then
            ControlCast(HK_Q, m.pos)
            self.lastQ = GetTickCount()
            return
        end
    end
end

function WindSamurai:LaneClear()
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.Q3Data.range)
    if not next(minions) or self.windwallActive then return end
    for i = 1, #minions do
        local m = minions[i]
        if self.menu.clear.useQ3:Value() and SpellReady(_Q) and HasQ3(myHero)
            and not myHero.pathing.isDashing and _G.SDK.Orbwalker:CanMove(myHero)
            and self.lastQ + 300 < GetTickCount() then
            local hitCount = self:CountQ3LineHits(m.pos)
            if hitCount >= self.menu.clear.q3Min:Value() then
                ControlCast(HK_Q, m.pos)
                self.lastQ = GetTickCount()
                return
            end
        end
        if self.menu.clear.useQ:Value() and SpellReady(_Q) and not HasQ3(myHero)
            and Dist(myHero.pos, m.pos) < self.QData.range
            and not myHero.pathing.isDashing and _G.SDK.Orbwalker:CanMove(myHero)
            and self.lastQ + 300 < GetTickCount() then
            ControlCast(HK_Q, m.pos)
            self.lastQ = GetTickCount()
            return
        end
        if self.menu.clear.useE:Value() and SpellReady(_E) and not myHero.pathing.isDashing
            and self.lastE + 120 < GetTickCount()
            and Dist(myHero.pos, m.pos) < self.ERange
            and _G.SDK.Orbwalker:CanMove(myHero)
            and not HasBuff(m, "YasuoE") then
            local endPos = self:GetDashEndPos(m)
            local safeE = (not self.menu.clear.noETower:Value()) or self:IsSafePosition(endPos)
            if safeE then
                if self.menu.clear.eqClear:Value() and SpellReady(_Q) then
                    local nearCount = CountMinionsInRange(self.QCircleWidth, m)
                    if nearCount >= self.menu.clear.eqMin:Value() then
                        ControlCast(HK_E, m)
                        self.lastE = GetTickCount()
                        local tmpM = m

                        DelayAction(function()
                            self:ExecuteEQ(tmpM)
                        end, self:GetEDelay() - 0.12)
                        return
                    end
                end
                if self.menu.clear.eLH:Value() == 1 then
                    local delay = self:GetEDmgDelay(m)
                    local hpPred = GetHealthPrediction(m, delay - 0.3)
                    local eDmg = self:GetEDamage(m)
                    if eDmg > hpPred then
                        ControlCast(HK_E, m)
                        self.lastE = GetTickCount()
                        return
                    end
                else
                    ControlCast(HK_E, m)
                    self.lastE = GetTickCount()
                    return
                end
            end
        end
    end
end

function WindSamurai:JungleClear()
    local monsters = _G.SDK.ObjectManager:GetMonsters(self.Q3Data.range)
    if not next(monsters) or self.windwallActive then return end
    for i = 1, #monsters do
        local m = monsters[i]
        if self.menu.jungle.useQ3:Value() and SpellReady(_Q) and HasQ3(myHero)
            and not myHero.pathing.isDashing and _G.SDK.Orbwalker:CanMove(myHero)
            and self.lastQ + 300 < GetTickCount() then
            ControlCast(HK_Q, m.pos)
            self.lastQ = GetTickCount()
            return
        end
        if self.menu.jungle.useQ:Value() and SpellReady(_Q) and not HasQ3(myHero)
            and Dist(myHero.pos, m.pos) < self.QData.range
            and not myHero.pathing.isDashing and _G.SDK.Orbwalker:CanMove(myHero)
            and self.lastQ + 300 < GetTickCount() then
            ControlCast(HK_Q, m.pos)
            self.lastQ = GetTickCount()
            return
        end
        if self.menu.jungle.useEQ:Value() and SpellReady(_E) and not myHero.pathing.isDashing
            and self.lastE + 120 < GetTickCount()
            and Dist(myHero.pos, m.pos) < self.ERange
            and _G.SDK.Orbwalker:CanMove(myHero)
            and not HasBuff(m, "YasuoE") then
            ControlCast(HK_E, m)
            self.lastE = GetTickCount()
            local tmpM = m

            DelayAction(function()
                self:ExecuteEQ(tmpM)
            end, self:GetEDelay() - 0.12)
            return
        end
    end
end

function WindSamurai:LastHit()
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.Q3Data.range)
    if not next(minions) or self.windwallActive then return end
    for i = 1, #minions do
        local m = minions[i]
        if self.menu.lasthit.useQ3:Value() and SpellReady(_Q) and HasQ3(myHero)
            and not myHero.pathing.isDashing and _G.SDK.Orbwalker:CanMove(myHero)
            and self.lastQ + 300 < GetTickCount() then
            local delay = Dist(myHero.pos, m.pos) / 1500 + self.menu.ping:Value() / 1000
            local hpPred = GetHealthPrediction(m, delay)
            if self:GetQDamage(m) > hpPred then
                ControlCast(HK_Q, m.pos)
                self.lastQ = GetTickCount()
                return
            end
        end
        if self.menu.lasthit.useQ:Value() and SpellReady(_Q) and not HasQ3(myHero)
            and Dist(myHero.pos, m.pos) < self.QData.range
            and not myHero.pathing.isDashing and _G.SDK.Orbwalker:CanMove(myHero)
            and self.lastQ + 300 < GetTickCount() then
            if self:GetQDamage(m) > m.health then
                ControlCast(HK_Q, m.pos)
                self.lastQ = GetTickCount()
                return
            end
        end
        if self.menu.lasthit.useE:Value() and SpellReady(_E) and not myHero.pathing.isDashing
            and self.lastE + 120 < GetTickCount()
            and Dist(myHero.pos, m.pos) < self.ERange
            and _G.SDK.Orbwalker:CanMove(myHero)
            and not HasBuff(m, "YasuoE") then
            local delay = self:GetEDmgDelay(m)
            local hpPred = GetHealthPrediction(m, delay - 0.3)
            local eDmg = self:GetEDamage(m)
            if eDmg > hpPred then
                local endPos = self:GetDashEndPos(m)
                local safe = (not self.menu.lasthit.noETower:Value()) or self:IsSafePosition(endPos)
                if safe then
                    ControlCast(HK_E, m)
                    self.lastE = GetTickCount()
                    return
                end
            end
        end
    end
end

function WindSamurai:Flee()
    if self.windwallActive then return end
    if self.menu.flee.useQ3:Value() and SpellReady(_Q) and HasQ3(myHero) then
        local t = self:GetTarget(self.Q3Data.range)
        if t then self:CastQ3(t) end
    end
    if self.menu.flee.useE:Value() and SpellReady(_E) and self.lastE + 120 < GetTickCount()
        and not myHero.pathing.isDashing then
        local bestObj, bestDist = self:FindBestEToCursor(self.menu.flee.noETower:Value())
        if bestObj and bestDist < mousePos:DistanceTo(myHero.pos) then
            ControlCast(HK_E, bestObj)
            self.lastE = GetTickCount()
        end
    end
end

function WindSamurai:CastQ(target)
    if not SpellReady(_Q) or myHero.pathing.isDashing or HasQ3(myHero)
        or self.lastE + 120 > GetTickCount()
        or Dist(myHero.pos, target.pos) > self.QData.range
        or not _G.SDK.Orbwalker:CanMove(myHero)
        or self.lastQ + 300 > GetTickCount() then
        return
    end
    local qPred = _G.DepressivePrediction.GetPrediction(target, {
        type = "linear",
        source = myHero,
        speed = self.QData.speed,
        delay = self.QData.delay,
        radius = self.QData.radius,
        range = self.QData.range,
        collision = false,
    })
    if qPred and qPred.castPos and ConvertHitChance(self.menu.pred.hcQ:Value(), qPred.hitChance or 4) then
        ControlCast(HK_Q, qPred.castPos)
        self.lastQ = GetTickCount()
    end
end

function WindSamurai:CastQ3(target)
    if not SpellReady(_Q) or myHero.pathing.isDashing or not HasQ3(myHero)
        or self.lastE + 120 > GetTickCount()
        or Dist(myHero.pos, target.pos) > self.Q3Data.range
        or not _G.SDK.Orbwalker:CanMove(myHero)
        or self.lastQ + 300 > GetTickCount() then
        return
    end
    local q3Pred = _G.DepressivePrediction.GetPrediction(target, {
        type = "linear",
        source = myHero,
        speed = self.Q3Data.speed,
        delay = self.Q3Data.delay,
        radius = self.Q3Data.radius,
        range = self.Q3Data.range,
        collision = false,
    })
    if q3Pred and q3Pred.castPos and ConvertHitChance(self.menu.pred.hcQ3:Value(), q3Pred.hitChance or 4) then
        ControlCast(HK_Q, q3Pred.castPos)
        self.lastQ = GetTickCount()
    end
end

function WindSamurai:FindBestEToTarget(target, avoidTower)
    local predictedPos = PredictPosition(target, self:GetEDelay())
    local bestObj = nil
    local bestDist = MathHuge
    local bestEQ = false
    local bestEndPos = nil
    local qReadySoon = myHero:GetSpellData(_Q).currentCd <= self:GetEDelay() + 0.1
    for _, cache in ipairs(self.eDashCache) do
        if avoidTower and not cache.safe then goto nextUnit end
        local eqHit, d = self:WillEQHitTarget(cache.endPos, target)
        if eqHit and qReadySoon then
            if not bestEQ or d < bestDist then
                bestObj = cache.unit
                bestDist = d
                bestEQ = true
                bestEndPos = cache.endPos
            end
        elseif not bestEQ then
            local dToTarget = Dist(cache.endPos, predictedPos)
            if dToTarget < bestDist and dToTarget < Dist(myHero.pos, predictedPos) then
                bestObj = cache.unit
                bestDist = dToTarget
                bestEQ = false
                bestEndPos = cache.endPos
            end
        end
        ::nextUnit::
    end
    return bestObj, bestDist, bestEQ, bestEndPos
end

function WindSamurai:FindBestEToCursor(avoidTower)
    local bestObj = nil
    local bestDist = MathHuge
    for _, cache in ipairs(self.eDashCache) do
        if avoidTower and not cache.safe then goto nextUnit end
        local d = mousePos:DistanceTo(cache.endPos)
        if d < bestDist then
            bestDist = d
            bestObj = cache.unit
        end
        ::nextUnit::
    end
    return bestObj, bestDist
end

function WindSamurai:FindAnyETarget()
    for _, cache in ipairs(self.eDashCache) do
        return cache.unit
    end
    return nil
end

function WindSamurai:CountQ3LineHits(targetPos)
    local count = 0
    local minions = _G.SDK.ObjectManager:GetEnemyMinions(self.Q3Data.range)
    for i = 1, #minions do
        local m = minions[i]
        if IsAlive(m) then
            local predicted = PredictPosition(m, self.Q3Data.delay + Dist(myHero.pos, m.pos) / self.Q3Data.speed)
            local projX, projZ, onSeg = PointOnSegmentProjection(myHero.pos, targetPos, predicted)
            if projX and onSeg then
                local projVec = Vector(projX, predicted.y, projZ)
                if Dist(predicted, projVec) <= (m.boundingRadius + self.Q3Data.radius) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

function WindSamurai:SmartWindWall()
    if not self.menu.windwall.enable:Value() then return end
    if self.lastW + 1000 > GetTickCount() or not SpellReady(_W) or self.pendingUlt then return end
    if self.menu.windwall.onlyCombo:Value() and not _G.SDK.Orbwalker.Modes[0] then return end
    local minThreat = self.menu.windwall.minThreat:Value()
    local hpPct = myHero.health / myHero.maxHealth * 100
    local lowHp = hpPct < self.menu.windwall.hpSafe:Value()
    local bestUnit = nil
    local bestThreat = 0
    local bestCastPos = nil
    local missileCount = Game.MissileCount and Game.MissileCount() or 0
    for i = 1, missileCount do
        local missile = Game.Missile(i)
        if missile and missile.valid and missile.isEnemy then
            local info = DangerousSpells[missile.name]
            if info then
                local effectiveThreat = info.threat
                if lowHp then effectiveThreat = effectiveThreat + 3 end
                local spellEnabled = true
                if self.menu.windwall.spells[missile.name] then
                    spellEnabled = self.menu.windwall.spells[missile.name]:Value()
                end
                if spellEnabled and (effectiveThreat >= minThreat or lowHp) then
                    local projX, projZ, onSeg = PointOnSegmentProjection(
                        missile.startPos, missile.endPos, myHero.pos
                    )
                    if onSeg and projX then
                        local projVec = Vector(projX, myHero.pos.y, projZ)
                        local projDist = Dist(myHero.pos, projVec)
                        local hitRadius = (missile.width or 70) / 2 + myHero.boundingRadius * 1.3
                        if projDist < hitRadius and effectiveThreat > bestThreat then
                            bestThreat = effectiveThreat
                            bestCastPos = missile.pos
                            bestUnit = missile.caster or myHero
                        end
                    end
                end
            end
        end
    end
    for i = 1, #self.heroUnits do
        local data = self.heroUnits[i]
        local unit = data.unit
        if unit and unit.isEnemy and IsAlive(unit) and Dist(myHero.pos, unit.pos) <= 2800 then
            local spell = unit.activeSpell
            if spell and spell.valid and spell.name ~= "" then
                local spellId = spell.name .. (spell.endTime or 0)
                if data.lastSpell ~= spellId then
                    data.lastSpell = spellId
                    local info = DangerousSpells[spell.name]
                    if info then
                        local effectiveThreat = info.threat
                        if lowHp then effectiveThreat = effectiveThreat + 3 end
                        local spellEnabled = true
                        if self.menu.windwall.spells[spell.name] then
                            spellEnabled = self.menu.windwall.spells[spell.name]:Value()
                        end
                        if spellEnabled and (effectiveThreat >= minThreat or lowHp) then
                            local spellEnd = spell.toPos or spell.placementPos or spell.startPos
                            local spellStart = spell.startPos or unit.pos
                            local willHit = false
                            if spell.target == myHero.handle then
                                willHit = true
                            else
                                local projX, projZ, onSeg = PointOnSegmentProjection(
                                    Vector(spellStart), Vector(spellEnd), myHero.pos
                                )
                                if onSeg and projX then
                                    local projVec = Vector(projX, myHero.pos.y, projZ)
                                    local projDist = Dist(myHero.pos, projVec)
                                    local hitRadius = ((spell.width or 100) / 2) + myHero.boundingRadius * 1.3
                                    if projDist < hitRadius then
                                        willHit = true
                                    end
                                end
                            end
                            if willHit and effectiveThreat > bestThreat then
                                bestThreat = effectiveThreat
                                bestCastPos = unit.pos
                                bestUnit = unit
                            end
                        end
                    end
                end
            end
        end
    end
    if bestUnit and bestCastPos then
        self.windwallActive = true
        self.lastW = GetTickCount()
        ControlCast(HK_W, bestCastPos)
    else
        self.windwallActive = false
    end
end

function WindSamurai:OnDraw()
    if myHero.dead then return end
    local pos2D = myHero.pos2D
    local pos = myHero.pos
    if self.menu.draw.qRange:Value() and SpellReady(_Q) and not HasQ3(myHero) then
        DrawCircle(pos, self.QData.range, DrawColor(80, 255, 255, 255))
    end
    if self.menu.draw.q3Range:Value() and HasQ3(myHero) then
        DrawCircle(pos, self.Q3Data.range, DrawColor(80, 255, 100, 100))
    end
    if self.menu.draw.eRange:Value() and SpellReady(_E) then
        DrawCircle(pos, self.ERange, DrawColor(80, 100, 255, 100))
    end
    if self.menu.draw.eGap:Value() and SpellReady(_E) then
        DrawCircle(pos, self.menu.combo.eGapRange:Value(), DrawColor(50, 100, 200, 255))
    end
    if self.menu.draw.rRange:Value() and SpellReady(_R) then
        DrawCircle(pos, self.RRange, DrawColor(50, 255, 200, 50))
    end
    if self.menu.draw.flow:Value() then
        local flowPct = GetFlowPercent()
        local hasShield = HasFlowShield()
        local flowColor
        if hasShield then
            flowColor = DrawColor(255, 50, 200, 255)
            DrawText("SHIELD READY", 14, pos2D.x - 30, pos2D.y + 30, flowColor)
        else
            local r = math.floor(255 * (1 - flowPct / 100))
            local g = math.floor(255 * (flowPct / 100))
            flowColor = DrawColor(200, r, g, 50)
            DrawText("Flow: " .. math.floor(flowPct) .. "%", 12, pos2D.x - 20, pos2D.y + 30, flowColor)
        end
    end
    if self.menu.draw.qTimer:Value() and HasQ3(myHero) then
        local qBuff = nil
        for i = 0, myHero.buffCount do
            local buff = myHero:GetBuff(i)
            if buff and buff.count > 0 and buff.name == "YasuoQ3W" then
                qBuff = buff
                break
            end
        end
        if qBuff then
            local remaining = qBuff.expireTime - GameTimer()
            if remaining > 0 then
                local col = remaining > 3 and DrawColor(255, 100, 255, 100)
                    or remaining > 1.5 and DrawColor(255, 255, 255, 50)
                    or DrawColor(255, 255, 80, 80)
                DrawText(string.format("Q3: %.1fs", remaining), 16, pos2D.x - 18, pos2D.y + 45, col)
            end
        end
    end
    if self.menu.draw.comboState:Value() and _G.SDK.Orbwalker.Modes[0] then
        local stageColor = {
            NEUTRAL    = DrawColor(180, 200, 200, 200),
            ENGAGING   = DrawColor(220, 255, 255, 50),
            ALL_IN     = DrawColor(220, 255, 50, 50),
            DISENGAGE  = DrawColor(220, 50, 150, 255)

        }
        DrawText(self.comboStage, 14, pos2D.x - 25, pos2D.y - 30, stageColor[self.comboStage] or DrawColor(255, 255, 255, 255))
    end
    if self.menu.draw.killable:Value() then
        local enemies = _G.SDK.ObjectManager:GetEnemyHeroes(2000)
        for i = 1, #enemies do
            local enemy = enemies[i]
            if IsAlive(enemy) and enemy.pos2D.onScreen then
                local comboDmg = self:GetFullComboDamage(enemy)
                local hpPct = enemy.health / enemy.maxHealth
                if comboDmg >= enemy.health then
                    DrawText("KILLABLE", 14, enemy.pos2D.x - 22, enemy.pos2D.y - 25, DrawColor(255, 255, 30, 30))
                else
                    local dmgPct = MathMin(100, math.floor(comboDmg / enemy.health * 100))
                    local r = math.floor(255 * dmgPct / 100)
                    local g = math.floor(255 * (1 - dmgPct / 100))
                    DrawText(dmgPct .. "% combo", 11, enemy.pos2D.x - 18, enemy.pos2D.y - 20, DrawColor(180, r, g, 50))
                end
            end
        end
    end
    if self.menu.draw.towerDive:Value() then
        local underTower, shots, dmg = self:EstimateTowerShots()
        if underTower then
            local col = shots <= 2 and DrawColor(255, 255, 0, 0) or shots <= 4 and DrawColor(255, 255, 200, 0) or DrawColor(255, 100, 255, 100)
            DrawText("TOWER: ~" .. shots .. " shots left", 14, pos2D.x - 45, pos2D.y + 60, col)
        end
    end
    if self.menu.draw.eDashPos:Value() and #self.eDashCache > 0 then
        local target = self.comboTarget or self:GetTarget(self.menu.combo.eGapRange:Value())
        for _, cache in ipairs(self.eDashCache) do
            local endPos = cache.endPos
            local col = DrawColor(80, 150, 150, 150)
            local eqHit = false
            if cache.wallCross then
                col = DrawColor(220, 0, 200, 255)
            elseif target and IsAlive(target) then
                local willHit, d = self:WillEQHitTarget(endPos, target)
                local currentDist = Dist(myHero.pos, target.pos)
                if willHit then
                    col = DrawColor(200, 0, 255, 0)
                    eqHit = true
                elseif d < currentDist then
                    col = DrawColor(150, 255, 255, 0)
                else
                    col = DrawColor(80, 255, 50, 50)
                end
            end
            DrawCircle(endPos, 55, col)
            if cache.wallCross then
                DrawCircle(endPos, 75, DrawColor(180, 0, 200, 255))
                DrawCircle(endPos, 30, DrawColor(200, 255, 0, 255))
            end
            if eqHit and self.menu.draw.eqCircle:Value() then
                DrawCircle(endPos, self.QCircleWidth, DrawColor(100, 0, 255, 100))
            end
            if not cache.safe then
                DrawCircle(endPos, 35, DrawColor(180, 255, 0, 0))
            end
        end
    end
end

function WindSamurai:GetFlashSlot()
    if myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" and Game.CanUseSpell(SUMMONER_1) == 0 then
        return SUMMONER_1
    elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" and Game.CanUseSpell(SUMMONER_2) == 0 then
        return SUMMONER_2
    end
    return nil
end

function WindSamurai:GetKnockedUpTarget()
    for i = 1, GameHeroCount() do
        local h = GameHero(i)
        if h.team ~= myHero.team and IsAlive(h) and Dist(myHero.pos, h.pos) <= self.RRange then
            if IsKnockedUp(h) then return h end
        end
    end
    return nil
end

function WindSamurai:GetBestMinionForEQ(target)
    if not target then return nil end
    local best, bestDist = nil, MathHuge
    for _, cache in ipairs(self.eDashCache) do
        if not HasBuff(cache.unit, "YasuoE") then
            local d = Dist(cache.endPos, target.pos)
            if d < self.QCircleWidth + (target.boundingRadius or 0) and d < bestDist then
                bestDist = d
                best = cache.unit
            end
        end
    end
    return best
end

function WindSamurai:ManualAirblade()
    if myHero.dead or Game.IsChatOpen() then return end
    local target = self:GetKnockedUpTarget() or self:GetTarget(self.RRange)
    if not target then return end
    if not IsKnockedUp(target) then return end
    if not SpellReady(_R) or not SpellReady(_E) or not SpellReady(_Q) then return end
    if (myHero:GetSpellData(_Q).currentCd or 0) > 0.5 then return end
    if Dist(myHero.pos, target.pos) > self.RRange then return end
    local dashUnit = nil
    if self.menu.airblade.championsOnly:Value() then
        local best, bestD = nil, MathHuge
        for i = 1, GameHeroCount() do
            local h = GameHero(i)
            if h ~= target and h.team ~= myHero.team and IsAlive(h)
                and Dist(myHero.pos, h.pos) <= self.ERange and not HasBuff(h, "YasuoE") then
                local d = Dist(myHero.pos, h.pos)
                if d < bestD then bestD = d ; dashUnit = h end
            end
        end
    end
    if not dashUnit then
        for _, cache in ipairs(self.eDashCache) do
            if not HasBuff(cache.unit, "YasuoE") then dashUnit = cache.unit ; break end
        end
    end
    if not dashUnit or Dist(myHero.pos, dashUnit.pos) > self.ERange then return end
    if not self:IsSafePosition(self:GetDashEndPos(dashUnit)) then return end
    local now = GameTimer()
    if now - self.lastAirbladeTime < 0.3 then return end
    self.lastAirbladeTime = now
    local tmpTarget = target
    local qDelaySec = self.menu.airblade.qDelay:Value() / 1000
    ControlCast(HK_E, dashUnit)

    DelayAction(function()
        if SpellReady(_Q) then
            ControlKeyDown(HK_Q)

            DelayAction(function() ControlKeyUp(HK_Q) end, 0.05)

            DelayAction(function()
                if IsAlive(tmpTarget) and IsKnockedUp(tmpTarget) and SpellReady(_R) then
                    ControlCast(HK_R, tmpTarget)
                end
            end, 0.1)
        end
    end, qDelaySec)
end

function WindSamurai:AutoAirbladeLogic()
    if self.beybladeState ~= "idle" then return end
    if not SpellReady(_R) or not SpellReady(_E) then return end
    if (myHero:GetSpellData(_Q).currentCd or 0) > 0.5 then return end
    local now = GameTimer()
    if now - self.lastAirbladeTime < 1.0 then return end
    for i = 1, GameHeroCount() do
        local target = GameHero(i)
        if target.team ~= myHero.team and IsAlive(target)
            and Dist(myHero.pos, target.pos) <= self.RRange and IsKnockedUp(target) then
            local bestUnit, closestDist = nil, MathHuge
            for _, cache in ipairs(self.eDashCache) do
                if not HasBuff(cache.unit, "YasuoE") then
                    local d = Dist(myHero.pos, cache.unit.pos)
                    if d < closestDist and self:IsSafePosition(cache.endPos) then
                        closestDist = d ; bestUnit = cache.unit
                    end
                end
            end
            if bestUnit then
                self.lastAirbladeTime = now
                local tmpTarget = target
                ControlCast(HK_E, bestUnit)

                DelayAction(function()
                    if SpellReady(_Q) then
                        ControlKeyDown(HK_Q)

                        DelayAction(function() ControlKeyUp(HK_Q) end, 0.05)
                    end
                end, 0.05)

                DelayAction(function()
                    if IsAlive(tmpTarget) and IsKnockedUp(tmpTarget) and SpellReady(_R) then
                        ControlCast(HK_R, tmpTarget)
                    end
                end, 0.15)
                return
            end
        end
    end
end

function WindSamurai:HandleBeyblade()
    if self.beybladeState ~= "idle" then return end
    if self.menu.beyblade.reqQ3:Value() then
        if not HasQ3(myHero) or not SpellReady(_Q) then return end
    else
        if not SpellReady(_Q) then return end
    end
    local target = self:GetBestBeybladeTargetWithCursor()
    if not target then return end
    local flashSlot = self:GetFlashSlot()
    if not flashSlot then return end
    local bestUnit = self:GetBestUnitForBeyblade(target)
    if not bestUnit then return end
    self.beybladeState = "executing"
    self.beybladeTimer = GameTimer()
    self.lockedBeybladeTarget = target
    local targetPosBeforeDash = {x = target.pos.x, z = target.pos.z}
    local flashR     = self.menu.beyblade.flashDist:Value()
    local flashStyle = self.menu.beyblade.style:Value()
    local flashOff   = self.menu.beyblade.offset:Value()
    local tmpFlash   = flashSlot
    ControlCast(HK_E, bestUnit)

    DelayAction(function()
        if SpellReady(_Q) and HasQ3(myHero) then
            ControlKeyDown(HK_Q)

            DelayAction(function() ControlKeyUp(HK_Q) end, 0.05)
        end

        DelayAction(function()
            local tPos = (self.lockedBeybladeTarget and self.lockedBeybladeTarget.valid
                         and self.lockedBeybladeTarget.pos) or targetPosBeforeDash
            local dx   = tPos.x - myHero.pos.x
            local dz   = tPos.z - myHero.pos.z
            local dist = MathSqrt(dx * dx + dz * dz)
            local nx, nz = dx / MathMax(dist, 1), dz / MathMax(dist, 1)
            local flashPos
            if flashStyle == 2 then
                flashPos = mousePos
            elseif flashStyle == 3 then
                flashPos = {x = tPos.x + nx * flashOff, z = tPos.z + nz * flashOff}
            else
                flashPos = {x = myHero.pos.x + nx * MathMin(flashR, dist),
                            z = myHero.pos.z + nz * MathMin(flashR, dist)}
            end
            if flashPos then
                if tmpFlash == SUMMONER_1 then ControlCast(HK_SUMMONER_1, flashPos)
                else                           ControlCast(HK_SUMMONER_2, flashPos) end
            end

            DelayAction(function()
                if self.lockedBeybladeTarget and self.lockedBeybladeTarget.valid then
                    if SpellReady(_R) and IsKnockedUp(self.lockedBeybladeTarget) then
                        ControlCast(HK_R, self.lockedBeybladeTarget)
                    end
                end
                self.beybladeState = "idle"
                self.lockedBeybladeTarget = nil
            end, 0.05)
        end, 0.15)
    end, 0.1)
end

function WindSamurai:GetBestBeybladeTargetWithCursor()
    local cursorRange = self.menu.beyblade.cursorDist:Value()
    local maxDist     = self.menu.beyblade.maxDist:Value()
    local best, closestD = nil, MathHuge
    for i = 1, GameHeroCount() do
        local h = GameHero(i)
        if h.team ~= myHero.team and IsAlive(h) and Dist(myHero.pos, h.pos) <= maxDist then
            local d = Dist(mousePos, h.pos)
            if d <= cursorRange and d < closestD then closestD = d ; best = h end
        end
    end
    return best
end

function WindSamurai:ExecuteBeybladeCombo()
    if GameTimer() - self.beybladeTimer > 2.5 then
        self.beybladeState = "idle"
        self.lockedBeybladeTarget = nil
    end
end

function WindSamurai:GetBestUnitForBeyblade(target)
    if not target then return nil end
    local best, closestGap = nil, MathHuge
    for _, cache in ipairs(self.eDashCache) do
        if not HasBuff(cache.unit, "YasuoE") then
            local distToEnd = Dist(cache.endPos, target.pos)
            if distToEnd < 650 and distToEnd < closestGap then
                closestGap = distToEnd ; best = cache.unit
            end
        end
    end
    return best
end

DelayAction(function()
    require "DamageLib"
    require "MapPositionGOS"
    _G["WindSamurai"]()
    print("[DepressiveAIONext] Yasuo loaded! v" .. ScriptVersion)
end, MathMax(0.07, 30 - GameTimer()))
