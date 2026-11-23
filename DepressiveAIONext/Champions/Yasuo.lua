local function SafeCd(sd)
    local v = sd and sd.currentCd
    if type(v) ~= "number" or v ~= v or v < 0 or v > 1000 then return 0 end
    return v
end

local CdTotal = {}
local CdStart = {}
local CdBusy = {}

local function CdSane(x)
    return type(x) == "number" and x == x and x >= 0 and x <= 1000
end

local function PanelCd(sd, slot)
    local key = sd and sd.name
    if not key then return 0 end
    local now = Game.Timer()

    local total = sd.cd
    if CdSane(total) and total > 0 then CdTotal[key] = total end

    if slot and Game.CanUseSpell(slot) == 0 then
        if CdBusy[key] then
            local started = CdStart[key]
            if started and now > started then CdTotal[key] = now - started end
            CdBusy[key] = false
        end
        return 0
    end

    if slot and not CdBusy[key] then
        CdBusy[key] = true
        CdStart[key] = now
    end

    local cur = sd.currentCd
    if CdSane(cur) then return cur end

    local t, s = CdTotal[key], CdStart[key]
    if not t or not s then return 0 end
    local left = s + t - now
    if left <= 0 then return 0 end
    return left
end

local VERSION = "9.92"
local SCRIPT_NAME = "DepressiveYasuo"

if _G.__DEPRESSIVE_NEXT_YASUO_LOADED then return end
if myHero.charName ~= "Yasuo" then return end
_G.__DEPRESSIVE_NEXT_YASUO_LOADED = true
_G.DepressiveAIONextLoadedChampion = true

pcall(require, "GGPrediction")
pcall(require, "DamageLib")
pcall(require, "MapPositionGOS")

local math_huge  = math.huge
local math_max   = math.max
local math_min   = math.min
local math_sqrt  = math.sqrt
local math_modf  = math.modf
local pcall      = pcall
local type       = type
local tonumber   = tonumber
local tostring   = tostring
local string_format = string.format
local string_byte   = string.byte
local string_find   = string.find
local setmetatable  = setmetatable

local Game    = _G.Game
local Control = _G.Control
local Draw    = _G.Draw
local Vector  = _G.Vector
local myHero  = _G.myHero

local GameTimer       = Game.Timer
local GameHeroCount   = Game.HeroCount
local GameHero        = Game.Hero
local GameCanUseSpell = Game.CanUseSpell
local GameIsChatOpen  = Game.IsChatOpen
local GameLatency     = Game.Latency
local GameMissileCount = Game.MissileCount
local GameMissile     = Game.Missile
local GameResolution  = Game.Resolution

local _Q, _W, _E, _R = 0, 1, 2, 3
local HK_Q = HK_Q or _Q
local HK_W = HK_W or _W
local HK_E = HK_E or _E
local HK_R = HK_R or _R
local SUM_1 = SUMMONER_1 or 4
local SUM_2 = SUMMONER_2 or 5

local TEAM_ALLY   = myHero.team
local TEAM_ENEMY  = (TEAM_ALLY == 100 and 200) or 100
local TEAM_JUNGLE = 300

local DAMAGE_TYPE_PHYSICAL = 0
local DAMAGE_TYPE_MAGICAL  = 1

local INVULN_TYPE   = 18
local KNOCKUP_TYPE  = 30
local KNOCKBACK_TYPE = 31

local KIT = {
    qRange    = 475,
    qRadius   = 40,
    qSpeed    = math_huge,
    qDelayMax = 0.40,
    qDelayMin = 0.133,
    qASCap    = 0.67,
    qBase     = {20, 45, 70, 95, 120},
    qAD       = 1.05,
    qCircle   = 230,

    q3Range   = 1100,
    q3Radius  = 90,
    q3Speed   = 1200,

    eRange    = 475,
    eDash     = 475,
    eSpeed    = 750,
    eMsShare  = 0.90,
    eBase     = {60, 70, 80, 90, 100},
    eAD       = 0.20,
    eAP       = 0.60,
    eRamp     = 0.25,
    eRampMax  = 2,

    rRange    = 1400,
    rBase     = {200, 350, 500},
    rAD       = 1.50,
    rArmorPen = 0.50,

    baseAS    = 0.697,
    critBonus = 0.675,
    towerRange = 838.5,
    igniteRange = 600,
    wallStep  = 25,
    wallProbe = 400,
    wallPassFrac = 0.70,
}

local F_ERAMP  = 2
local F_SHIELD = 4
local F_KNOCK  = 8
local F_QSTACK = 16

local BUFF_FLAG = {
    YasuoDashScalar = F_ERAMP, yasuodashscalar = F_ERAMP,
    YasuoPassiveShield = F_SHIELD, yasuopassiveshield = F_SHIELD,
    YasuoQ3Stacks = F_QSTACK, yasuoq3stacks = F_QSTACK,
    YasuoQ3Mis = F_KNOCK, yasuoq3mis = F_KNOCK,
    YasuoQ3 = F_KNOCK, yasuoq3 = F_KNOCK,
    YasuoRKnockUpComboRemove = F_KNOCK, yasuorknockupcomboremove = F_KNOCK,
    YasuoRKnockUp = F_KNOCK, yasuorknockup = F_KNOCK,
}

local Q3_WRAPPER = "YasuoQ3Wrapper"

local EMARK_NAMES = {
    YasuoE = true, yasuoe = true,
    YasuoEDebuff = true, yasuoedebuff = true,
    YasuoDashWrapper = true, yasuodashwrapper = true,
}

local LIM = {
    emarkPart  = "_E_timer",
    emarkOwner = "Yasuo",
    emarkSlack = 40,
    particleCap = 2048,
    partMemoCap = 4000,
    nameLogCap = 256,
    selfPartSqr = 22500,
    minionScan = 1200,
    stateScan  = KIT.rRange + 200,
    nearScan   = KIT.eRange + 125,
    turretSqr  = 4000000,
    cellScale  = 0.03030303,
    cellSize   = 33,
    wjQuant    = 64,
    wjSpread   = 160,
}

local P_EMARK  = 1
local P_SHIELD = 2
local P_QSTACK = 4
local P_ERAMP  = 8

local SELF_PART = {
    {"Passive_Shield", P_SHIELD},
    {"_Q_stack", P_QSTACK},
    {"_E_stack", P_ERAMP},
}
local SELF_PART_N = 3

local DANGER = {
    RocketGrab                = {threat = 10},
    ThreshQMissile            = {threat = 10},
    EnchantedCrystalArrow     = {threat = 10},
    MorganaQ                  = {threat = 10},
    FizzR                     = {threat = 10},
    VeigarR                   = {threat = 10},
    SyndraR                   = {threat = 10},
    UrgotR                    = {threat = 10},
    NautilusAnchorDragMissile = {threat = 9},
    SejuaniR                  = {threat = 9},
    LuxLightBinding           = {threat = 9},
    AhriSeduce                = {threat = 9},
    EliseHumanE               = {threat = 9},
    BraumR                    = {threat = 9},
    VarusR                    = {threat = 9},
    PykeQRange                = {threat = 9},
    ZoeE                      = {threat = 9},
    NautilusGrandLine         = {threat = 9},
    LeonaZenithBlade          = {threat = 8},
    NeekoE                    = {threat = 8},
    IreliaR                   = {threat = 8},
    LeblancE                  = {threat = 8},
    LeblancRE                 = {threat = 8},
    SylasE2                   = {threat = 8},
    BandageToss               = {threat = 8},
    BardQ                     = {threat = 8},
    NamiRMissile              = {threat = 8},
    EzrealR                   = {threat = 8},
    JinxR                     = {threat = 8},
    DravenRCast               = {threat = 8},
    HeimerdingerEUlt          = {threat = 8},
    VayneCondemn              = {threat = 8},
    GoldCardPreAttack         = {threat = 8},
    BlindMonkQOne             = {threat = 7},
    IvernQ                    = {threat = 7},
    HowlingGaleSpell          = {threat = 7},
    GravesChargeShot          = {threat = 7},
    FlashFrostSpell           = {threat = 7},
    GragasR                   = {threat = 7},
    IllaoiE                   = {threat = 7},
    SennaR                    = {threat = 7},
    XerathMageSpear           = {threat = 7},
    ZyraE                     = {threat = 7},
    AnnieQ                    = {threat = 7},
    TristanaR                 = {threat = 7},
    PoppyRSpell               = {threat = 7},
    YasuoQ3Mis                = {threat = 7},
    AatroxW                   = {threat = 7},
    ApheliosR                 = {threat = 7},
    ShyvanaFireballDragon2    = {threat = 7},
    FioraW                    = {threat = 7},
    NamiQ                     = {threat = 7},
    SyndraE                   = {threat = 7},
    CaitlynEntrapment         = {threat = 6},
    JayceShockBlastWallMis    = {threat = 6},
    KarmaQMantra              = {threat = 6},
    RengarE                   = {threat = 6},
    SennaW                    = {threat = 6},
    ZoeQMis2                  = {threat = 6},
    BrandQ                    = {threat = 6},
    BraumQ                    = {threat = 6},
    EkkoQ                     = {threat = 6},
    JhinRShot                 = {threat = 6},
    KledQ                     = {threat = 6},
    JavelinToss               = {threat = 6},
    HeimerdingerE             = {threat = 6},
    AkaliE                    = {threat = 6},
    DravenDoubleShot          = {threat = 6},
    CamilleE                  = {threat = 6},
    FiddleSticksQ             = {threat = 6},
    BrandR                    = {threat = 6},
    CaitlynPiltoverPeacemaker = {threat = 5},
    JinxWMissile              = {threat = 5},
    KaisaW                    = {threat = 5},
    AhriOrbofDeception        = {threat = 5},
    JayceShockBlast           = {threat = 5},
    KarmaQ                    = {threat = 5},
    KennenShurikenHurlMissile1 = {threat = 5},
    LissandraQMissile         = {threat = 5},
    ZedQ                      = {threat = 5},
    ZoeQMissile               = {threat = 5},
    TalonW                    = {threat = 5},
    GnarBigQMissile           = {threat = 5},
    PantheonQ                 = {threat = 5},
    QuinnQ                    = {threat = 5},
    RekSaiQBurrowed           = {threat = 5},
    ShyvanaFireball           = {threat = 5},
    SionE                     = {threat = 5},
    SkarnerFractureMissile    = {threat = 5},
    TahmKenchQ                = {threat = 5},
    VarusQMissile             = {threat = 5},
    ViktorDeathRayMissile     = {threat = 5},
    LuluWTwo                  = {threat = 5},
    MissileBarrageMissile2    = {threat = 5},
    RedCardPreAttack          = {threat = 5},
    DianaQ                    = {threat = 5},
    Frostbite                 = {threat = 5},
    BlindingDart              = {threat = 5},
    ApheliosCalibrumQ         = {threat = 5},
    EzrealQ                   = {threat = 4},
    SivirQ                    = {threat = 4},
    Volley                    = {threat = 4},
    GragasQ                   = {threat = 4},
    LuluQ                     = {threat = 4},
    NeekoQ                    = {threat = 4},
    NocturneDuskbringer       = {threat = 4},
    OlafAxeThrowCast          = {threat = 4},
    RyzeQ                     = {threat = 4},
    VeigarBalefulStrike       = {threat = 4},
    VelkozQ                   = {threat = 4},
    KogMawVoidOozeMissile     = {threat = 4},
    GangplankQProceed         = {threat = 4},
    KayleQ                    = {threat = 4},
    CassiopeiaE               = {threat = 4},
    PhosphorusBomb            = {threat = 4},
    MissileBarrageMissile     = {threat = 4},
    InfectedCleaverMissile    = {threat = 4},
    EliseHumanQ               = {threat = 4},
    EvelynnQ                  = {threat = 4},
    GnarQMissile              = {threat = 4},
    NullLance                 = {threat = 4},
    KalistaMysticShot         = {threat = 4},
    KhazixW                   = {threat = 4},
    LeblancQ                  = {threat = 4},
    SeismicShard              = {threat = 4},
    MaokaiQ                   = {threat = 4},
    MissFortuneRicochetShot   = {threat = 4},
    RumbleGrenade             = {threat = 4},
    TaliyahQMis               = {threat = 4},
    WildCards                 = {threat = 4},
    XayahQ                    = {threat = 4},
    SowTheWind                = {threat = 4},
    GalioQ                    = {threat = 4},
    GravesSmokeGrenade        = {threat = 4},
    EzrealW                   = {threat = 3},
    NamiW                     = {threat = 3},
    KatarinaQ                 = {threat = 3},
    KogMawQ                   = {threat = 3},
    LissandraEMissile         = {threat = 3},
    LucianW                   = {threat = 3},
    RyzeE                     = {threat = 3},
    TwoShivPoison             = {threat = 3},
    VelkozW                   = {threat = 3},
    ZiggsQ                    = {threat = 3},
    RakanQ                    = {threat = 3},
    BlueCardPreAttack         = {threat = 3},
}

local DANGER_NAMES = {}
local DANGER_COUNT = 0
for name in pairs(DANGER) do
    DANGER_COUNT = DANGER_COUNT + 1
    DANGER_NAMES[DANGER_COUNT] = name
end
table.sort(DANGER_NAMES)


local TICK = 0
local NOW  = 0

local S = {
    myX = 0, myZ = 0, myY = 0,
    hp = 1, maxHp = 1, hpPct = 1,
    ms = 325, br = 65,
    ad = 0, bonusAD = 0, ap = 0, crit = 0,
    aaRange = 175,
    qLv = 0, eLv = 0, rLv = 0,
    qR = false, wR = false, eR = false, rR = false,
    qCd = 0,
    wCd = 0,
    eCd = 0,
    rCd = 0,
    qDelay = 0.40,
    hasQ3 = false,
    qStacks = 0,
    eRampStacks = 0,
    shield = false,
    flowPct = 0,
    dashing = false,
    casting = false,
    towerSqr = 0,
    shieldPart = false,
    qStackPart = 0,
    eRampPart = 0,
    mode = "None",
    lat = 0.03,
    eDelay = 0.30,
    nearE = 0,
    nearA = 0,
}

local EHo, EHx, EHz, EHd, EHbr = {}, {}, {}, {}, {}
local EHh, EHhp, EHknock, EHmark, EHinvuln = {}, {}, {}, {}, {}
local EHn = 0

local CMo, CMx, CMz, CMbr = {}, {}, {}, {}
local CMpx, CMpz, CMps = {}, {}, {}
local CMn = 0

local JMo, JMx, JMz, JMbr = {}, {}, {}, {}
local JMn = 0

local EMX, EMZ = {}, {}
local EMn = 0

local PartIsMark = {}
local PartSeen = 0

local PartNameSeen = {}
local PartNameN = 0

local DUo, DUx, DUz, DUsafe, DUwall, DUhero = {}, {}, {}, {}, {}, {}
local DUn = 0

local TTx, TTz = {}, {}
local TTn = 0

local MissileThreat = {}
local MissileSeen = 0

local MEMO = {
    cx = nil, cz = nil, hit = false,
    rank = {}, stamp = {},
    missSeen = {}, missN = 0,
}

local PQs, PQx, PQz = {}, {}, {}
local P3s, P3x, P3z = {}, {}, {}
local DMs, DMv = {}, {}

local Menu
local MapPos
local tsTick = -1
local tsIdx = 0

local function DistSqr(ax, az, bx, bz)
    local dx, dz = ax - bx, az - bz
    return dx * dx + dz * dz
end

local function IsValid(unit)
    if not unit or not unit.valid or not unit.visible then return false end
    if unit.dead or not unit.isTargetable then return false end
    local hp = unit.health
    return hp ~= nil and hp > 0
end

local function IsValidUnit(unit)
    if not unit or not unit.valid or unit.dead then return false end
    if not unit.isTargetable then return false end
    local hp = unit.health
    return hp ~= nil and hp > 0
end

local function ShouldWait()
    return myHero.dead or GameIsChatOpen()
        or (_G.JustEvade and _G.JustEvade:Evading())
        or (_G.ExtLibEvade and _G.ExtLibEvade.Evading)
end

local function GetMode()
    local sdk = _G.SDK
    if sdk and sdk.Orbwalker and sdk.Orbwalker.Modes then
        local M = sdk.Orbwalker.Modes
        if M[sdk.ORBWALKER_MODE_COMBO] then return "Combo" end
        if M[sdk.ORBWALKER_MODE_SPACING] then return "Combo" end
        if M[sdk.ORBWALKER_MODE_HARASS] then return "Harass" end
        if M[sdk.ORBWALKER_MODE_LANECLEAR] then return "Clear" end
        if M[sdk.ORBWALKER_MODE_JUNGLECLEAR] then return "Clear" end
        if M[sdk.ORBWALKER_MODE_LASTHIT] then return "LastHit" end
        if M[sdk.ORBWALKER_MODE_FLEE] then return "Flee" end
    end
    return "None"
end

local function CanMove()
    local sdk = _G.SDK
    if sdk and sdk.Orbwalker and sdk.Orbwalker.CanMove then
        return sdk.Orbwalker:CanMove(myHero) ~= false
    end
    return true
end

local function SetAttack(on)
    local sdk = _G.SDK
    if sdk and sdk.Orbwalker and sdk.Orbwalker.SetAttack then
        sdk.Orbwalker:SetAttack(on)
    end
end

local function IsCasting()
    local cast = myHero.activeSpell
    if not cast or type(cast.valid) ~= "boolean" or not cast.valid then return false end
    local a, b = cast.startTime, cast.castEndTime
    if type(a) ~= "number" or type(b) ~= "number" then return false end
    return NOW >= a and NOW <= b
end

local function Mitigate(target, dmgType, raw)
    if raw <= 0 then return 0 end
    local sdk = _G.SDK
    if sdk and sdk.Damage and sdk.Damage.CalculateDamage then
        return sdk.Damage:CalculateDamage(myHero, target, dmgType, raw) or 0
    end
    local res = (dmgType == DAMAGE_TYPE_PHYSICAL and target.armor or target.magicResist) or 0
    if res >= 0 then return raw * 100 / (100 + res) end
    return raw * (2 - 100 / (100 - res))
end

local function MitigatePen(target, raw, pen)
    if raw <= 0 then return 0 end
    local res = (target.armor or 0) * (1 - pen)
    if res >= 0 then return raw * 100 / (100 + res) end
    return raw * (2 - 100 / (100 - res))
end

local function HasFlag(flags, flag)
    return flags % (flag * 2) >= flag
end

local function ScanUnit(unit)
    local knock, invuln, flags, ramp, qst = false, false, 0, 0, 0
    local cached = _G.SDK and _G.SDK.Cached
    local buffs = cached and cached.GetBuffs and cached:GetBuffs(unit)
    if buffs then
        for i = 1, #buffs do
            local b = buffs[i]
            local t = b.type
            if t == KNOCKUP_TYPE or t == KNOCKBACK_TYPE then
                knock = true
            elseif t == INVULN_TYPE then
                invuln = true
            end
            local f = BUFF_FLAG[b.name]
            if f then
                local c = tonumber(b.count) or 0
                if c > 0 then
                    if f == F_KNOCK then knock = true
                    elseif f == F_ERAMP then ramp = c
                    elseif f == F_QSTACK then qst = c
                    else flags = flags + f end
                end
            end
        end
        return knock, invuln, flags, ramp, qst
    end
    local total = unit.buffCount
    if type(total) ~= "number" then return knock, invuln, flags, ramp, qst end
    for i = 0, total - 1 do
        local b = unit:GetBuff(i)
        if b then
            local c = tonumber(b.count) or 0
            if c > 0 then
                local t = b.type
                if t == KNOCKUP_TYPE or t == KNOCKBACK_TYPE then
                    knock = true
                elseif t == INVULN_TYPE then
                    invuln = true
                end
                local f = BUFF_FLAG[b.name]
                if f then
                    if f == F_KNOCK then knock = true
                    elseif f == F_ERAMP then ramp = c
                    elseif f == F_QSTACK then qst = c
                    else flags = flags + f end
                end
            end
        end
    end
    return knock, invuln, flags, ramp, qst
end

local function SourceIsMine(b)
    local nid = b.sourcenID
    if nid ~= nil and nid == myHero.networkID then return true end
    local nm = b.sourceName
    if type(nm) == "string" and nm ~= "" and nm == myHero.charName then return true end
    return false
end

local function AnyDashable()
    local base = KIT.eRange
    for i = 1, CMn do
        local r = base + CMbr[i]
        if DistSqr(CMx[i], CMz[i], S.myX, S.myZ) <= r * r then return true end
    end
    for i = 1, JMn do
        local r = base + JMbr[i]
        if DistSqr(JMx[i], JMz[i], S.myX, S.myZ) <= r * r then return true end
    end
    for i = 1, EHn do
        local r = base + EHbr[i]
        if DistSqr(EHx[i], EHz[i], S.myX, S.myZ) <= r * r then return true end
    end
    return false
end

local function PartOwnerLabel(px, pz)
    for k = 1, EHn do
        if DistSqr(px, pz, EHx[k], EHz[k]) <= 160000 then
            return EHo[k].charName or "hero"
        end
    end
    for k = 1, CMn do
        if DistSqr(px, pz, CMx[k], CMz[k]) <= 40000 then return "minion" end
    end
    for k = 1, JMn do
        if DistSqr(px, pz, JMx[k], JMz[k]) <= 40000 then return "monster" end
    end
    if DistSqr(px, pz, S.myX, S.myZ) <= LIM.selfPartSqr then return "MYSELF" end
    return nil
end

local function ClassifyParticle(nm)
    if nm == nil then return 0 end
    if string_find(nm, LIM.emarkOwner, 1, true) == nil then return 0 end
    if string_find(nm, LIM.emarkPart, 1, true) ~= nil then return P_EMARK end
    for i = 1, SELF_PART_N do
        local e = SELF_PART[i]
        if string_find(nm, e[1], 1, true) ~= nil then return e[2] end
    end
    return 0
end

local function ScanParticles()
    EMn = 0
    local mode = S.mode
    local needSelf = mode == "Combo" or mode == "Harass"
    local needMark = S.eR and AnyDashable()
    local needNames = Menu ~= nil and Menu.debug.partNames:Value() == true
    if needSelf then
        S.shieldPart = false
        S.qStackPart = 0
        S.eRampPart = 0
    end
    if not needMark and not needSelf and not needNames then return end
    if type(Game.ParticleCount) ~= "function" or type(Game.Particle) ~= "function" then
        return
    end
    local total = Game.ParticleCount()
    if type(total) ~= "number" or total <= 0 then return end
    local cap = LIM.particleCap
    if total > cap then total = cap end
    if PartSeen > LIM.partMemoCap then
        PartIsMark = {}
        PartSeen = 0
    end
    local n = 0
    for i = 1, total do
        local p = Game.Particle(i)
        if p then
            local id = p.networkID
            local code = PartIsMark[id]
            if code == nil then
                local nm = p.name
                code = ClassifyParticle(nm)
                PartIsMark[id] = code
                PartSeen = PartSeen + 1
                if needNames and nm ~= nil and PartNameSeen[nm] == nil
                   and string_find(nm, LIM.emarkOwner, 1, true) ~= nil then
                    if PartNameN > LIM.nameLogCap then
                        PartNameSeen = {}
                        PartNameN = 0
                    end
                    PartNameSeen[nm] = true
                    PartNameN = PartNameN + 1
                    local pos = p.pos
                    print(string_format("[Yasuo] PNAME %q code=%d on=%s",
                        nm, code, (pos and PartOwnerLabel(pos.x, pos.z)) or "far"))
                end
            end
            if code == P_EMARK then
                if needMark then
                    local pos = p.pos
                    if pos then
                        n = n + 1
                        EMX[n], EMZ[n] = pos.x, pos.z
                    end
                end
            elseif code ~= 0 and needSelf then
                local pos = p.pos
                if pos and DistSqr(pos.x, pos.z, S.myX, S.myZ) <= LIM.selfPartSqr then
                    if code == P_SHIELD then
                        S.shieldPart = true
                    elseif code == P_QSTACK then
                        S.qStackPart = S.qStackPart + 1
                    else
                        S.eRampPart = S.eRampPart + 1
                    end
                end
            end
        end
    end
    EMn = n
    if not needSelf then return end
    if S.shieldPart then S.shield = true end
    if S.qStackPart > 0 and S.qStacks == 0 then S.qStacks = S.qStackPart end
    if S.eRampPart > 0 and S.eRampStacks == 0 then
        S.eRampStacks = math_min(S.eRampPart, KIT.eRampMax)
    end
end

local function MarkedByParticle(ux, uz, br)
    if EMn == 0 then return false end
    local reach = br + LIM.emarkSlack
    local rs = reach * reach
    for i = 1, EMn do
        if DistSqr(ux, uz, EMX[i], EMZ[i]) <= rs then return true end
    end
    return false
end

local function MineAndOwned(b, name)
    if type(name) ~= "string" then return false end
    if string_find(name, LIM.emarkOwner, 1, true) == nil then return false end
    local t = b.type
    if t == KNOCKUP_TYPE or t == KNOCKBACK_TYPE then return false end
    return SourceIsMine(b)
end

local function MarkedByBuff(unit, bySource)
    local sourced = false
    local cached = _G.SDK and _G.SDK.Cached
    local buffs = cached and cached.GetBuffs and cached:GetBuffs(unit)
    if buffs then
        for i = 1, #buffs do
            local b = buffs[i]
            local n = b.name
            if n ~= nil and EMARK_NAMES[n] and (tonumber(b.count) or 1) > 0 then
                return true
            end
            if bySource and not sourced and MineAndOwned(b, n) then
                sourced = true
            end
        end
        return sourced
    end
    local total = unit.buffCount
    if type(total) ~= "number" then return false end
    for i = 0, total - 1 do
        local b = unit:GetBuff(i)
        if b then
            local n = b.name
            if n ~= nil and EMARK_NAMES[n] and (tonumber(b.count) or 1) > 0 then
                return true
            end
            if bySource and not sourced and MineAndOwned(b, n) then
                sourced = true
            end
        end
    end
    return sourced
end

local function MarkedByE(unit, ux, uz, br)
    if MarkedByParticle(ux, uz, br) then return true end
    if Menu == nil then return false end
    return MarkedByBuff(unit, Menu.combo.eMarkBySource:Value() == true)
end

local function SyncSelf()
    local p = myHero.pos
    S.myX, S.myY, S.myZ = p.x, p.y, p.z
    S.hp = myHero.health
    S.maxHp = math_max(myHero.maxHealth, 1)
    S.hpPct = S.hp / S.maxHp
    S.ms = math_max(myHero.ms or 325, 1)
    S.br = myHero.boundingRadius or 65
    S.ad = math_max(myHero.totalDamage or 0, 0)
    S.bonusAD = math_max(myHero.bonusDamage or 0, 0)
    S.ap = math_max(myHero.ap or 0, 0)
    S.crit = math_min(math_max(myHero.critChance or 0, 0), 1)
    S.aaRange = (myHero.range or 175) + S.br
    S.lat = (GameLatency and GameLatency() or 30) * 0.0005

    local q, w, e, r = myHero:GetSpellData(_Q), myHero:GetSpellData(_W),
        myHero:GetSpellData(_E), myHero:GetSpellData(_R)
    S.qLv, S.eLv, S.rLv = q.level, e.level, r.level
    S.qCd = PanelCd(q, _Q)
    S.qR = SafeCd(q) == 0 and q.level > 0 and GameCanUseSpell(_Q) == 0
    S.wCd = PanelCd(w, _W)
    S.wR = SafeCd(w) == 0 and w.level > 0 and GameCanUseSpell(_W) == 0
    S.eCd = PanelCd(e, _E)
    S.eR = e.level > 0 and GameCanUseSpell(_E) == 0
    S.rCd = PanelCd(r, _R)
    S.rR = SafeCd(r) == 0 and r.level > 0 and GameCanUseSpell(_R) == 0
    S.hasQ3 = q.name == Q3_WRAPPER

    local as = myHero.attackSpeed or KIT.baseAS
    local bonus = math_max(0, as / KIT.baseAS - 1)
    local delay = math_max(KIT.qDelayMin, KIT.qDelayMax * (1 - math_min(bonus, KIT.qASCap)))
    local cast = myHero.activeSpell
    if cast and cast.valid == true and type(cast.windup) == "number" and cast.windup > 0 then
        local nm = cast.name
        if nm == "YasuoQ1" or nm == "YasuoQ2" or nm == "YasuoQ3" then
            delay = cast.windup
        end
    end
    S.qDelay = delay

    local path = myHero.pathing
    S.dashing = path ~= nil and path.isDashing == true
    S.casting = IsCasting()
    S.mode = GetMode()

    local flow = myHero.maxMana
    S.flowPct = (flow > 0 and myHero.mana / flow * 100) or 0

    local _, _, flags, ramp, qst = ScanUnit(myHero)
    S.shield = HasFlag(flags, F_SHIELD)
    S.eRampStacks = ramp
    S.qStacks = qst

    local ammo = tonumber(q.ammo)
    if ammo and ammo > 0 and ammo <= 2 and S.qStacks == 0 then
        S.qStacks = ammo
    end

    S.eDelay = KIT.eDash / (KIT.eSpeed + S.ms * KIT.eMsShare) + S.lat
end

local function SyncEnemies()
    local n, near = 0, 0
    local allies = 0
    for i = 1, GameHeroCount() do
        local h = GameHero(i)
        if IsValid(h) then
            local p = h.pos
            if h.team == TEAM_ENEMY then
                n = n + 1
                EHo[n] = h
                EHh[n] = h.handle
                EHx[n], EHz[n] = p.x, p.z
                EHd[n] = h.distance
                EHbr[n] = h.boundingRadius or 0
                EHhp[n] = h.health
                if EHd[n] <= LIM.stateScan then
                    local knock, invuln = ScanUnit(h)
                    EHknock[n] = knock
                    EHinvuln[n] = invuln
                else
                    EHknock[n] = false
                    EHinvuln[n] = false
                end
                if EHd[n] <= 1400 then near = near + 1 end
            elseif h ~= myHero then
                if DistSqr(p.x, p.z, S.myX, S.myZ) <= 1960000 then
                    allies = allies + 1
                end
            end
        end
    end
    for i = EHn, n + 1, -1 do EHo[i] = nil end
    EHn = n
    S.nearE = near
    S.nearA = allies
end

local function SyncMarks()
    for i = 1, EHn do
        EHmark[i] = EHd[i] <= KIT.rRange and MarkedByE(EHo[i], EHx[i], EHz[i], EHbr[i]) or false
    end
end

local function SyncMinions()
    local sdk = _G.SDK
    local om = sdk and sdk.ObjectManager
    local scan = (S.mode == "Clear" and LIM.minionScan) or LIM.nearScan
    local n = 0
    local list = om and om:GetEnemyMinions(scan)
    if list then
        for i = 1, #list do
            local u = list[i]
            if IsValidUnit(u) and u.team ~= TEAM_JUNGLE then
                n = n + 1
                local p = u.pos
                CMo[n] = u
                CMx[n], CMz[n] = p.x, p.z
                CMbr[n] = u.boundingRadius or 0
            end
        end
    end
    for i = CMn, n + 1, -1 do CMo[i] = nil end
    CMn = n

    local m = 0
    local mobs = om and om:GetMonsters(scan)
    if mobs then
        for i = 1, #mobs do
            local u = mobs[i]
            if IsValidUnit(u) then
                m = m + 1
                local p = u.pos
                JMo[m] = u
                JMx[m], JMz[m] = p.x, p.z
                JMbr[m] = u.boundingRadius or 60
            end
        end
    end
    for i = JMn, m + 1, -1 do JMo[i] = nil end
    JMn = m
end

local function SyncTurrets()
    local sdk = _G.SDK
    local om = sdk and sdk.ObjectManager
    local list = om and om.GetEnemyTurrets and om:GetEnemyTurrets()
    local n = 0
    if list then
        for i = 1, #list do
            local t = list[i]
            if t and not t.dead then
                local p = t.pos
                if DistSqr(p.x, p.z, S.myX, S.myZ) <= LIM.turretSqr then
                    n = n + 1
                    TTx[n], TTz[n] = p.x, p.z
                end
            end
        end
    end
    TTn = n
    local r = KIT.towerRange + S.br * 0.5
    S.towerSqr = r * r
end

local function SafeFromTurrets(x, z)
    if TTn == 0 then return true end
    local rs = S.towerSqr
    for i = 1, TTn do
        if DistSqr(x, z, TTx[i], TTz[i]) < rs then return false end
    end
    return true
end

local WALL_PROBE = {x = 0, y = 0, z = 0}
local function WallMap()
    if MapPos then return MapPos end
    MapPos = _G.MapPosition
    if not MapPos then
        pcall(require, "MapPositionGOS")
        MapPos = _G.MapPosition
    end
    return MapPos
end

local function CellWall(map, cx, cz)
    if cx == MEMO.cx and cz == MEMO.cz then return MEMO.hit end
    WALL_PROBE.x, WALL_PROBE.z = cx, cz
    local hit = map:inWall(WALL_PROBE, true)
    hit = hit ~= nil and hit ~= false and hit ~= 0
    MEMO.cx, MEMO.cz, MEMO.hit = cx, cz, hit
    return hit
end

local function ScanWall(dx, dz)
    local map = WallMap()
    if not map then return false end

    local size = LIM.cellSize
    local px, pz = S.myX, S.myZ
    local cx = math_modf(px * LIM.cellScale)
    local cz = math_modf(pz * LIM.cellScale)

    local stepX = (dx > 0 and 1) or (dx < 0 and -1) or 0
    local stepZ = (dz > 0 and 1) or (dz < 0 and -1) or 0

    local tMaxX, tDeltaX = math_huge, math_huge
    if stepX ~= 0 then
        local edge = (stepX > 0 and (cx + 1) or cx) * size
        tMaxX = (edge - px) / dx
        tDeltaX = size / (dx < 0 and -dx or dx)
    end

    local tMaxZ, tDeltaZ = math_huge, math_huge
    if stepZ ~= 0 then
        local edge = (stepZ > 0 and (cz + 1) or cz) * size
        tMaxZ = (edge - pz) / dz
        tDeltaZ = size / (dz < 0 and -dz or dz)
    end

    if tDeltaX == math_huge and tDeltaZ == math_huge then return false end

    local land = KIT.eDash
    local limit = land + KIT.wallProbe
    local t, enter, leave = 0, -1, -1

    while t < limit do
        if enter < 0 and t >= land then return false end
        local hit = CellWall(map, cx, cz)
        if hit then
            if enter < 0 then
                if t <= 0 then return false end
                enter = t
            end
        elseif enter >= 0 then
            leave = t
            break
        end
        if tMaxX < tMaxZ then
            t = tMaxX
            cx = cx + stepX
            tMaxX = tMaxX + tDeltaX
        else
            t = tMaxZ
            cz = cz + stepZ
            tMaxZ = tMaxZ + tDeltaZ
        end
    end

    if enter < 0 or enter >= land then return false end
    if leave < 0 then return false end
    if leave <= land then return 1 end
    if land - enter > (leave - enter) * KIT.wallPassFrac then return 2 end
    return false
end

local function DashCrossesWall(ex, ez)
    if not WallMap() then return false end
    local dx, dz = ex - S.myX, ez - S.myZ
    local len = math_sqrt(dx * dx + dz * dz)
    if len < 1 then return false end
    dx, dz = dx / len, dz / len
    local q = LIM.wjQuant
    local key = (math_modf(dx * q) + q) * LIM.wjSpread + math_modf(dz * q) + q
    local stamp, rankOf = MEMO.stamp, MEMO.rank
    if stamp[key] == TICK then return rankOf[key] end
    local rank = ScanWall(dx, dz)
    stamp[key] = TICK
    rankOf[key] = rank
    return rank
end

local EBlk = {}
local EBlkN = 0

local function ClearEBlock()
    if EBlkN == 0 then return end
    EBlk = {}
    EBlkN = 0
end

local function BlockE(unit)
    local h = unit.handle
    if h == nil or EBlk[h] ~= nil then return end
    EBlk[h] = true
    EBlkN = EBlkN + 1
end

local function IsEBlocked(unit)
    if EBlkN == 0 then return false end
    local h = unit.handle
    return h ~= nil and EBlk[h] ~= nil
end

local function PushDash(n, unit, ux, uz, isHero, needWall, marked)
    if marked then return n end
    local dx, dz = ux - S.myX, uz - S.myZ
    local len = math_sqrt(dx * dx + dz * dz)
    if len < 1 then return n end
    local ex = S.myX + dx / len * KIT.eDash
    local ez = S.myZ + dz / len * KIT.eDash
    n = n + 1
    DUo[n] = unit
    DUx[n], DUz[n] = ex, ez
    DUsafe[n] = SafeFromTurrets(ex, ez)
    DUwall[n] = needWall and DashCrossesWall(ex, ez) or false
    DUhero[n] = isHero
    return n
end

local function SyncDashTargets(needWall)
    if S.dashing or not S.eR then ClearEBlock() end
    local n, blocked = 0, 0
    local base = KIT.eRange
    for i = 1, CMn do
        local reach = base + CMbr[i]
        if DistSqr(CMx[i], CMz[i], S.myX, S.myZ) <= reach * reach then
            local u = CMo[i]
            if IsEBlocked(u) then
                blocked = blocked + 1
            else
                n = PushDash(n, u, CMx[i], CMz[i], false, needWall,
                    MarkedByE(u, CMx[i], CMz[i], CMbr[i]))
            end
        end
    end
    for i = 1, JMn do
        local reach = base + JMbr[i]
        if DistSqr(JMx[i], JMz[i], S.myX, S.myZ) <= reach * reach then
            local u = JMo[i]
            if IsEBlocked(u) then
                blocked = blocked + 1
            else
                n = PushDash(n, u, JMx[i], JMz[i], false, needWall,
                    MarkedByE(u, JMx[i], JMz[i], JMbr[i]))
            end
        end
    end
    for i = 1, EHn do
        local reach = base + EHbr[i]
        if DistSqr(EHx[i], EHz[i], S.myX, S.myZ) <= reach * reach then
            local u = EHo[i]
            if IsEBlocked(u) then
                blocked = blocked + 1
            else
                n = PushDash(n, u, EHx[i], EHz[i], true, needWall, EHmark[i])
            end
        end
    end
    for i = DUn, n + 1, -1 do DUo[i] = nil end
    DUn = n
    if n == 0 and blocked > 0 then ClearEBlock() end
end

local function PredictXZ(unit, delay, kx, kz)
    local px, pz = kx, kz
    if px == nil then
        local p = unit.pos
        px, pz = p.x, p.z
    end
    if delay <= 0 then return px, pz end
    local path = unit.pathing
    if not path then return px, pz end
    if path.isDashing then
        local e = path.endPos
        if e then return e.x, e.z end
        return px, pz
    end
    if not path.hasMovePath then return px, pz end
    local ms = unit.ms
    if not ms or ms <= 0 then return px, pz end
    local remain = delay
    local lx, lz = px, pz
    for i = path.pathIndex, path.pathCount do
        local node = unit:GetPath(i)
        if not node then break end
        local nx, nz = node.x, node.z
        local seg = math_sqrt(DistSqr(nx, nz, lx, lz))
        if seg < 1 then
            lx, lz = nx, nz
        else
            local segTime = seg / ms
            if remain > segTime then
                remain = remain - segTime
                lx, lz = nx, nz
            else
                local t = ms * remain / seg
                return lx + (nx - lx) * t, lz + (nz - lz) * t
            end
        end
    end
    return lx, lz
end

local function HealthAfter(unit, t)
    local sdk = _G.SDK
    if sdk and sdk.HealthPrediction then
        return sdk.HealthPrediction:GetPrediction(unit, t) or unit.health
    end
    return unit.health
end

local function ProjectOnSegment(ax, az, bx, bz, cx, cz)
    local abx, abz = bx - ax, bz - az
    local denom = abx * abx + abz * abz
    if denom < 1 then return ax, az, false end
    local raw = ((cx - ax) * abx + (cz - az) * abz) / denom
    local clamped = (raw < 0 and 0) or (raw > 1 and 1) or raw
    return ax + clamped * abx, az + clamped * abz, clamped == raw
end

local GGPred = {Q = nil, Q3 = nil}
local function EnsurePred()
    if GGPred.Q then return true end
    local gg = _G.GGPrediction
    if not (gg and type(gg.SpellPrediction) == "function") then return false end
    GGPred.Q = gg:SpellPrediction({Type = gg.SPELLTYPE_LINE, Delay = KIT.qDelayMax,
        Radius = KIT.qRadius, Range = KIT.qRange, Speed = KIT.qSpeed, Collision = false})
    GGPred.Q3 = gg:SpellPrediction({Type = gg.SPELLTYPE_LINE, Delay = KIT.qDelayMax,
        Radius = KIT.q3Radius, Range = KIT.q3Range, Speed = KIT.q3Speed, Collision = false})
    return true
end

local function HitChanceOf(menuVal)
    local gg = _G.GGPrediction
    if not gg then return 0 end
    if menuVal == 1 then return gg.HITCHANCE_NORMAL end
    if menuVal == 2 then return gg.HITCHANCE_HIGH end
    return gg.HITCHANCE_IMMOBILE
end

local function Evaluate(pred, target, want)
    pred.Delay = S.qDelay
    pred:GetPrediction(target, myHero)
    local cp = pred.CastPosition
    if not cp or not cp.x or not cp.z then return nil, nil end
    if not pred:CanHit(want) then return nil, nil end
    return cp.x, cp.z
end

local function PredQ(i, want)
    if PQs[i] ~= TICK then
        PQs[i] = TICK
        if EnsurePred() then
            PQx[i], PQz[i] = Evaluate(GGPred.Q, EHo[i], want)
        else
            PQx[i], PQz[i] = nil, nil
        end
    end
    return PQx[i], PQz[i]
end

local function PredQ3(i, want)
    if P3s[i] ~= TICK then
        P3s[i] = TICK
        if EnsurePred() then
            P3x[i], P3z[i] = Evaluate(GGPred.Q3, EHo[i], want)
        else
            P3x[i], P3z[i] = nil, nil
        end
    end
    return P3x[i], P3z[i]
end

local function LibDamage(key, target)
    local fn = _G.getdmg
    if type(fn) ~= "function" then return 0 end
    local ok, dmg = pcall(fn, key, target, myHero)
    if ok and type(dmg) == "number" and dmg > 0 then return dmg end
    return 0
end

local function ERawDamage()
    local lv = S.eLv
    if lv == 0 then return 0 end
    local ramp = 1 + KIT.eRamp * math_min(S.eRampStacks, KIT.eRampMax)
    return KIT.eBase[lv] * ramp + KIT.eAD * S.bonusAD + KIT.eAP * S.ap
end

local Yasuo = {}
Yasuo.__index = Yasuo

function Yasuo.New()
    local o = setmetatable({}, Yasuo)
    o.qHeld = false
    o.attackOn = nil
    o.dumpHeld = false
    o.seen = {}
    o.seenN = 0
    o:LoadMenu()
    return o
end

function Yasuo:AllowAttack(on)
    if self.attackOn == on then return end
    SetAttack(on)
    self.attackOn = on
end

function Yasuo:DumpUnit(who, unit, everything)
    local total = unit.buffCount
    local p = unit.pos
    local br = unit.boundingRadius or 60
    print(string_format("[Yasuo] %s nID=%s buffCount=%s marked=%s byPart=%s",
        who, tostring(unit.networkID), tostring(total),
        tostring(MarkedByE(unit, p.x, p.z, br)),
        tostring(MarkedByParticle(p.x, p.z, br))))
    if type(total) ~= "number" then return end
    for i = 0, total - 1 do
        local b = unit:GetBuff(i)
        if b then
            local n = b.name
            local nt = type(n)
            local nlen = (nt == "string" and #n) or -1
            local key = who .. "|" .. i .. "|" .. tostring(n) .. "|" .. tostring(b.type)
            if everything or not self.seen[key] then
                if self.seenN > LIM.nameLogCap then
                    self.seen = {}
                    self.seenN = 0
                end
                self.seen[key] = true
                self.seenN = self.seenN + 1
                print(string_format(
                    "[Yasuo]   [%d] name=%q nt=%s len=%d count=%s stacks=%s type=%s srcName=%s srcID=%s",
                    i, tostring(n), nt, nlen, tostring(b.count), tostring(b.stacks),
                    tostring(b.type), tostring(b.sourceName), tostring(b.sourcenID)))
            end
        end
    end
end

function Yasuo:DumpParticles()
    if type(Game.ParticleCount) ~= "function" or type(Game.Particle) ~= "function" then
        print("[Yasuo] particle API missing")
        return
    end
    local total = Game.ParticleCount()
    if type(total) ~= "number" or total <= 0 then
        print("[Yasuo] ParticleCount=" .. tostring(total))
        return
    end
    print(string_format("[Yasuo] ParticleCount=%d", total))
    if total > 2048 then total = 2048 end
    local near = 0
    for i = 1, total do
        local p = Game.Particle(i)
        if p and p.pos then
            local who = PartOwnerLabel(p.pos.x, p.pos.z)
            if who then
                near = near + 1
                print(string_format("[Yasuo]   PART on %s name=%q type=%s code=%d",
                    who, tostring(p.name), tostring(p.type),
                    ClassifyParticle(p.name)))
            end
        end
    end
    print(string_format("[Yasuo] particles near units: %d", near))
end

function Yasuo:Debug()
    local node = Menu.debug
    local key = node.dumpKey:Value() == true
    local edge = key and not self.dumpHeld
    self.dumpHeld = key
    if not edge and not node.watch:Value() then return end

    for i = 1, EHn do
        if EHd[i] <= 1200 then
            self:DumpUnit(EHo[i].charName or "enemy", EHo[i], edge)
        end
    end
    for k = 1, DUn do
        local u = DUo[k]
        self:DumpUnit(tostring(u.charName or u.name or "unit"), u, edge)
    end
    if edge then
        print(string_format("[Yasuo] SELF nID=%s charName=%s dashCands=%d eMarks=%d eR=%s eCd=%.2f canUseE=%s dashing=%s",
            tostring(myHero.networkID), tostring(myHero.charName),
            DUn, EMn, tostring(S.eR), S.eCd, tostring(GameCanUseSpell(_E)),
            tostring(S.dashing)))
        local q = myHero:GetSpellData(_Q)
        print(string_format("[Yasuo] QDATA name=%s ammo=%s ammoTime=%s ammoCd=%s ammoCurrentCd=%s toggle=%s",
            tostring(q.name), tostring(q.ammo), tostring(q.ammoTime),
            tostring(q.ammoCd), tostring(q.ammoCurrentCd), tostring(q.toggleState)))
        print(string_format("[Yasuo] SELFFLAGS shield=%s qStacks=%s eRamp=%s shieldPart=%s qPart=%s ePart=%s",
            tostring(S.shield), tostring(S.qStacks), tostring(S.eRampStacks),
            tostring(S.shieldPart), tostring(S.qStackPart), tostring(S.eRampPart)))
        self:DumpUnit("MYSELF", myHero, true)
        if node.particles:Value() then self:DumpParticles() end
    end
end

function Yasuo:QDamage(i)
    if S.qLv == 0 then return 0 end
    local target = EHo[i]
    local dmg = LibDamage("Q", target)
    if dmg > 0 then return dmg end
    return Mitigate(target, DAMAGE_TYPE_PHYSICAL, KIT.qBase[S.qLv] + KIT.qAD * S.ad)
end

function Yasuo:EDamage(i)
    if S.eLv == 0 then return 0 end
    local target = EHo[i]
    local dmg = LibDamage("E", target)
    if dmg > 0 then
        return dmg * (1 + KIT.eRamp * math_min(S.eRampStacks, KIT.eRampMax))
    end
    return Mitigate(target, DAMAGE_TYPE_MAGICAL, ERawDamage())
end

function Yasuo:RDamage(i)
    if S.rLv == 0 then return 0 end
    local raw = KIT.rBase[S.rLv] + KIT.rAD * S.bonusAD
    return MitigatePen(EHo[i], raw, KIT.rArmorPen)
end

function Yasuo:AADamage(i)
    local target = EHo[i]
    local mod = 1 + S.crit * KIT.critBonus
    local raw = LibDamage("AA", target)
    if raw > 0 then return raw * mod end
    return Mitigate(target, DAMAGE_TYPE_PHYSICAL, S.ad * mod)
end

function Yasuo:IgniteSlot()
    if myHero:GetSpellData(SUM_1).name == "SummonerDot" and GameCanUseSpell(SUM_1) == 0 then
        return SUM_1, HK_SUMMONER_1 or 4
    end
    if myHero:GetSpellData(SUM_2).name == "SummonerDot" and GameCanUseSpell(SUM_2) == 0 then
        return SUM_2, HK_SUMMONER_2 or 5
    end
    return nil, nil
end

function Yasuo:IgniteDamage()
    local slot = self:IgniteSlot()
    if not slot then return 0 end
    return 50 + 20 * (myHero.levelData and myHero.levelData.lvl or 1)
end

function Yasuo:ComboDamage(i)
    if DMs[i] == TICK then return DMv[i] end
    DMs[i] = TICK
    local total = 0
    if S.qR then
        total = total + self:QDamage(i) * (S.hasQ3 and 1 or 2)
    end
    if S.eR and not EHmark[i] then
        total = total + self:EDamage(i)
    end
    local rUseful = S.rR and (S.hasQ3 or EHknock[i])
    if rUseful then
        total = total + self:RDamage(i)
    end
    local aa = self:AADamage(i)
    total = total + aa * ((rUseful or S.hasQ3) and 3 or 2)
    DMv[i] = total
    return total
end

function Yasuo:Killable(i)
    return self:ComboDamage(i) >= EHhp[i]
end

function Yasuo:Pick()
    if tsTick == TICK then return tsIdx end
    tsTick = TICK
    tsIdx = 0
    local sdk = _G.SDK
    if not (sdk and sdk.TargetSelector and sdk.ObjectManager) then return 0 end
    local widest = Menu.combo.eGapRange:Value()
    if KIT.q3Range > widest then widest = KIT.q3Range end
    local heroes = sdk.ObjectManager:GetEnemyHeroes(widest, false)
    local picked = sdk.TargetSelector:GetTarget(heroes)
    if picked then
        local h = picked.handle
        for i = 1, EHn do
            if EHh[i] == h then
                tsIdx = i
                break
            end
        end
    end
    return tsIdx
end

function Yasuo:InRange(i, range)
    return EHd[i] <= range + EHbr[i]
end

function Yasuo:Target(range)
    local i = self:Pick()
    if i ~= 0 and not EHinvuln[i] and self:InRange(i, range) then return i end
    local best, bestHp = 0, math_huge
    for k = 1, EHn do
        if not EHinvuln[k] and self:InRange(k, range) and EHhp[k] < bestHp then
            best, bestHp = k, EHhp[k]
        end
    end
    return best
end

function Yasuo:TradeOk()
    local node = Menu.combo.trade
    if not node.enable:Value() then return true end
    if node.antiGank:Value() and S.nearE >= S.nearA + 2 then return false end
    if node.shield:Value() and not S.shield then
        if S.flowPct < node.flowPct:Value() then return false end
    end
    return true
end

function Yasuo:EQWillHit(ex, ez, px, pz, br)
    local reach = KIT.qCircle + br
    return DistSqr(ex, ez, px, pz) <= reach * reach
end

function Yasuo:BestEToTarget(i, avoidTower)
    local px, pz = PredictXZ(EHo[i], S.eDelay, EHx[i], EHz[i])
    local br = EHbr[i]
    local currentSqr = DistSqr(S.myX, S.myZ, px, pz)
    local qSoon = S.qCd <= S.eDelay + 0.1 and S.qLv > 0
    local bestIdx, bestDistSqr, bestEQ = 0, math_huge, false
    for k = 1, DUn do
        if not (avoidTower and not DUsafe[k]) then
            local ex, ez = DUx[k], DUz[k]
            local d2 = DistSqr(ex, ez, px, pz)
            local eq = qSoon and self:EQWillHit(ex, ez, px, pz, br)
            if eq then
                if not bestEQ or d2 < bestDistSqr then
                    bestIdx, bestDistSqr, bestEQ = k, d2, true
                end
            elseif not bestEQ and d2 < bestDistSqr and d2 < currentSqr then
                bestIdx, bestDistSqr = k, d2
            end
        end
    end
    return bestIdx, bestDistSqr, bestEQ, currentSqr
end

function Yasuo:BestEToCursor(avoidTower)
    local mp = mousePos
    if not mp then return 0, math_huge end
    local mx, mz = mp.x, mp.z
    local bestIdx, bestDistSqr = 0, math_huge
    for k = 1, DUn do
        if not (avoidTower and not DUsafe[k]) then
            local d2 = DistSqr(DUx[k], DUz[k], mx, mz)
            if d2 < bestDistSqr then
                bestIdx, bestDistSqr = k, d2
            end
        end
    end
    return bestIdx, bestDistSqr
end

function Yasuo:BestEToward(tx, tz, avoidTower, preferHero)
    local current = DistSqr(S.myX, S.myZ, tx, tz)
    local bestIdx, bestDistSqr, bestHero = 0, math_huge, false
    for k = 1, DUn do
        if not (avoidTower and not DUsafe[k]) then
            local d2 = DistSqr(DUx[k], DUz[k], tx, tz)
            if d2 < current then
                local isHero = DUhero[k]
                if bestIdx == 0
                    or (preferHero and isHero and not bestHero)
                    or (d2 < bestDistSqr and (not preferHero or isHero == bestHero)) then
                    bestIdx, bestDistSqr, bestHero = k, d2, isHero
                end
            end
        end
    end
    return bestIdx
end

function Yasuo:CastE(k)
    if not S.eR or S.dashing then return false end
    local unit = DUo[k]
    if not unit then return false end
    Control.CastSpell(HK_E, unit)
    BlockE(unit)
    return true
end

function Yasuo:SaveCursor()
    if self.cursorBackX then return end
    local cp = _G.cursorPos
    if cp then
        self.cursorBackX, self.cursorBackY = cp.x, cp.y
    end
end

function Yasuo:CastAtUnit(key, unit)
    if not unit then return false end
    local p = unit.pos
    if p == nil then return false end
    local p2 = unit.pos2D
    if p2 == nil or p2.onScreen ~= true then return false end
    self:SaveCursor()
    Control.CastSpell(key, p)
    return true
end

function Yasuo:CastEAimed(k)
    if not S.eR or S.dashing then return false end
    local unit = DUo[k]
    if not self:CastAtUnit(HK_E, unit) then return false end
    BlockE(unit)
    return true
end

function Yasuo:CastQ(i, want)
    if not S.qR or S.dashing or S.hasQ3 or S.casting then return false end
    if not CanMove() then return false end
    if not self:InRange(i, KIT.qRange) then return false end
    local cx, cz = PredQ(i, want)
    if not cx then return false end
    self:SaveCursor()
    Control.CastSpell(HK_Q, Vector(cx, S.myY, cz))
    return true
end

function Yasuo:CastQ3(i, want)
    if not S.qR or S.dashing or not S.hasQ3 or S.casting then return false end
    if not CanMove() then return false end
    if not self:InRange(i, KIT.q3Range) then return false end
    local cx, cz = PredQ3(i, want)
    if not cx then return false end
    self:SaveCursor()
    Control.CastSpell(HK_Q, Vector(cx, S.myY, cz))
    return true
end

function Yasuo:CastQAt(x, z)
    if not S.qR or S.dashing or S.casting or not CanMove() then return false end
    self:SaveCursor()
    Control.CastSpell(HK_Q, Vector(x, S.myY, z))
    return true
end

function Yasuo:HoldQ()
    if not S.qR then return false end
    Control.KeyDown(HK_Q)
    self.qHeld = true
    self:AllowAttack(false)
    return true
end

function Yasuo:ReleaseQ()
    if not self.qHeld then return end
    Control.KeyUp(HK_Q)
    self.qHeld = false
    self:AllowAttack(true)
end

function Yasuo:DashQ()
    if not S.dashing or not S.qR then return false end
    if not Menu.combo.qInDash:Value() then return false end
    for i = 1, EHn do
        if not EHinvuln[i] then
            local px, pz = PredictXZ(EHo[i], S.lat, EHx[i], EHz[i])
            if self:EQWillHit(S.myX, S.myZ, px, pz, EHbr[i]) then
                return self:HoldQ()
            end
        end
    end
    local rs = KIT.qCircle * KIT.qCircle
    for i = 1, CMn do
        if DistSqr(S.myX, S.myZ, CMx[i], CMz[i]) <= rs then return self:HoldQ() end
    end
    for i = 1, JMn do
        if DistSqr(S.myX, S.myZ, JMx[i], JMz[i]) <= rs then return self:HoldQ() end
    end
    return false
end

function Yasuo:Ultimate()
    if not S.rR or S.rLv == 0 then return false end
    local node = Menu.ult
    if not node.team:Value() then return false end
    if S.dashing then
        if node.noRDash:Value() then return false end
    end
    local need = node.teamMin:Value()
    local bestIdx, bestCount = 0, 0
    for i = 1, EHn do
        if EHknock[i] and not EHinvuln[i] and self:InRange(i, KIT.rRange) then
            local count = 1
            for j = 1, EHn do
                if j ~= i and EHknock[j]
                    and DistSqr(EHx[i], EHz[i], EHx[j], EHz[j]) < 160000 then
                    count = count + 1
                end
            end
            if count > bestCount then
                bestIdx, bestCount = i, count
            end
        end
    end
    if bestIdx == 0 then return false end
    if bestCount < need and not self:Killable(bestIdx) then return false end
    return self:CastAtUnit(HK_R, EHo[bestIdx])
end

function Yasuo:Airblade()
    if not Menu.ult.airblade:Value() then return false end
    if not S.rR or not S.eR or S.dashing then return false end
    local bestIdx = 0
    for i = 1, EHn do
        if EHknock[i] and not EHinvuln[i] and self:InRange(i, KIT.rRange) then
            bestIdx = i
            break
        end
    end
    if bestIdx == 0 then return false end
    if EHd[bestIdx] <= KIT.rRange - KIT.eDash then return false end
    local k = self:BestEToward(EHx[bestIdx], EHz[bestIdx], Menu.combo.noETower:Value(), true)
    if k == 0 then return false end
    return self:CastE(k)
end

function Yasuo:Ignite()
    local node = Menu.combo.ign
    if not node.use:Value() then return false end
    local slot, key = self:IgniteSlot()
    if not slot then return false end
    local ignite = self:IgniteDamage()
    local killOnly = node.mode:Value() == 1
    for i = 1, EHn do
        if not EHinvuln[i] and self:InRange(i, KIT.igniteRange) then
            if ignite >= EHhp[i] then
                return self:CastAtUnit(key, EHo[i])
            end
            if not killOnly and self:ComboDamage(i) + ignite >= EHhp[i] then
                return self:CastAtUnit(key, EHo[i])
            end
        end
    end
    return false
end

function Yasuo:Combo()
    local node = Menu.combo
    local trade = self:TradeOk()

    if node.useE:Value() and S.eR and trade and not S.dashing then
        local gap = node.eGapRange:Value()
        local i = self:Target(gap)
        if i ~= 0 then

            local mode = node.eMode:Value()
            if mode == 3 then
                mode = (EHd[i] > S.aaRange + 100 and 1) or 2
            end
            if mode == 1 then
                local k, d2, eq, currentSqr = self:BestEToTarget(i, node.noETower:Value())
                if k ~= 0 then
                    local closes = d2 < currentSqr
                    local onTarget = DUo[k] == EHo[i]
                    local allow = closes or eq or onTarget
                    if allow and (EHd[i] > S.aaRange or eq or node.eEngage:Value() or onTarget) then
                        if self:CastE(k) then return true end
                    end
                end
            else
                local k, d2 = self:BestEToCursor(node.noETower:Value())
                if k ~= 0 and mousePos then
                    local cursorSqr = DistSqr(S.myX, S.myZ, mousePos.x, mousePos.z)
                    if d2 < cursorSqr and self:CastE(k) then return true end
                end
            end
        end
    end

    if node.useQ3:Value() and S.hasQ3 then
        local want = HitChanceOf(Menu.pred.hcQ3:Value())
        local bestIdx, bestHp = 0, math_huge
        for i = 1, EHn do
            if not EHinvuln[i] and self:InRange(i, KIT.q3Range) then
                if self:Killable(i) and EHhp[i] < bestHp then
                    bestIdx, bestHp = i, EHhp[i]
                end
            end
        end
        if bestIdx == 0 then
            bestIdx = self:Target(KIT.q3Range)
        end
        if bestIdx ~= 0 then

            if self:CastQ3(bestIdx, want) then return true end
        end
    end

    if node.useQ:Value() and not S.hasQ3 then
        local want = HitChanceOf(Menu.pred.hcQ:Value())
        local i = self:Target(KIT.qRange)
        if i ~= 0 and self:CastQ(i, want) then return true end
        if node.stackQ:Value() and self:StackQ() then return true end
    end

    return self:Ignite()
end

function Yasuo:StackQ()
    if not S.qR or S.hasQ3 or S.dashing or S.casting then return false end
    local reach = KIT.qRange + 20
    local rs = reach * reach
    local bx, bz, best, bestD = nil, nil, 0, math_huge
    for i = 1, CMn do
        local d2 = DistSqr(CMx[i], CMz[i], S.myX, S.myZ)
        if d2 <= rs then
            local c = self:CountCircle(CMx[i], CMz[i], CMn, CMx, CMz)
            if c > best or (c == best and d2 < bestD) then
                bx, bz, best, bestD = CMx[i], CMz[i], c, d2
            end
        end
    end
    if bx then return self:CastQAt(bx, bz) end
    for i = 1, JMn do
        local d2 = DistSqr(JMx[i], JMz[i], S.myX, S.myZ)
        if d2 <= rs then
            local c = self:CountCircle(JMx[i], JMz[i], JMn, JMx, JMz)
            if c > best or (c == best and d2 < bestD) then
                bx, bz, best, bestD = JMx[i], JMz[i], c, d2
            end
        end
    end
    if bx then return self:CastQAt(bx, bz) end
    return false
end

function Yasuo:Harass()
    local node = Menu.harass
    if node.useQ3:Value() and S.hasQ3 then
        local i = self:Target(KIT.q3Range)
        if i ~= 0 and self:CastQ3(i, HitChanceOf(Menu.pred.hcQ3:Value())) then return true end
    end
    if node.useQ:Value() and not S.hasQ3 then
        local i = self:Target(KIT.qRange)
        if i ~= 0 and self:CastQ(i, HitChanceOf(Menu.pred.hcQ:Value())) then return true end
    end
    if node.stackQ:Value() then return self:StackQ() end
    return false
end

function Yasuo:MinionPred(i)
    if CMps[i] ~= TICK then
        CMps[i] = TICK
        local d = math_sqrt(DistSqr(CMx[i], CMz[i], S.myX, S.myZ))
        CMpx[i], CMpz[i] = PredictXZ(CMo[i], S.qDelay + d / KIT.q3Speed, CMx[i], CMz[i])
    end
    return CMpx[i], CMpz[i]
end

function Yasuo:CountQ3Line(tx, tz)
    local count = 0
    local reachBase = KIT.q3Radius
    local q3Sqr = KIT.q3Range * KIT.q3Range
    for i = 1, CMn do
        if DistSqr(CMx[i], CMz[i], S.myX, S.myZ) <= q3Sqr then
            local px, pz = self:MinionPred(i)
            local jx, jz, onSeg = ProjectOnSegment(S.myX, S.myZ, tx, tz, px, pz)
            if onSeg then
                local reach = reachBase + CMbr[i]
                if DistSqr(px, pz, jx, jz) <= reach * reach then
                    count = count + 1
                end
            end
        end
    end
    return count
end

function Yasuo:CountCircle(cx, cz, n, xs, zs)
    local count = 0
    local r = KIT.qCircle * KIT.qCircle
    for i = 1, n do
        if DistSqr(xs[i], zs[i], cx, cz) <= r then count = count + 1 end
    end
    return count
end

function Yasuo:Clear()
    local node = Menu.clear
    if JMn > 0 then
        if node.useQ3:Value() and S.hasQ3 then
            local q3Sqr = KIT.q3Range * KIT.q3Range
            local bx, bz, best = nil, nil, 0
            for i = 1, JMn do
                if DistSqr(JMx[i], JMz[i], S.myX, S.myZ) <= q3Sqr then
                    local c = self:CountCircle(JMx[i], JMz[i], JMn, JMx, JMz)
                    if c > best then bx, bz, best = JMx[i], JMz[i], c end
                end
            end
            if bx and self:CastQAt(bx, bz) then return true end
        end
        if node.useQ:Value() and not S.hasQ3 then
            local rs = (KIT.qRange + 20) * (KIT.qRange + 20)
            for i = 1, JMn do
                if DistSqr(JMx[i], JMz[i], S.myX, S.myZ) <= rs then
                    if self:CastQAt(JMx[i], JMz[i]) then return true end
                end
            end
        end
        if node.useE:Value() and S.eR and not S.dashing and CanMove() then
            local k = 0
            for j = 1, DUn do
                if not DUhero[j] and (not node.noETower:Value() or DUsafe[j]) then
                    k = j
                    break
                end
            end
            if k ~= 0 and self:CastE(k) then return true end
        end
        return false
    end

    if node.useQ3:Value() and S.hasQ3 then
        local q3Sqr = KIT.q3Range * KIT.q3Range
        local bx, bz, best = nil, nil, node.q3Min:Value()
        for i = 1, CMn do
            if DistSqr(CMx[i], CMz[i], S.myX, S.myZ) <= q3Sqr then
                local c = self:CountQ3Line(CMx[i], CMz[i])
                if c >= best then bx, bz, best = CMx[i], CMz[i], c end
            end
        end
        if bx and self:CastQAt(bx, bz) then return true end
    end

    if node.useQ:Value() and not S.hasQ3 then
        local rs = KIT.qRange * KIT.qRange
        local bx, bz, best = nil, nil, 0
        for i = 1, CMn do
            if DistSqr(CMx[i], CMz[i], S.myX, S.myZ) <= rs then
                local c = self:CountCircle(CMx[i], CMz[i], CMn, CMx, CMz)
                if c > best then bx, bz, best = CMx[i], CMz[i], c end
            end
        end
        if bx and self:CastQAt(bx, bz) then return true end
    end

    if node.useE:Value() and S.eR and not S.dashing and CanMove() then
        local lastHitOnly = node.eLH:Value() == 1
        local eRaw = ERawDamage()
        for k = 1, DUn do
            if not DUhero[k] and (not node.noETower:Value() or DUsafe[k]) then
                local unit = DUo[k]
                if not lastHitOnly then
                    if self:CastE(k) then return true end
                elseif eRaw > 0 and HealthAfter(unit, S.eDelay)
                    <= Mitigate(unit, DAMAGE_TYPE_MAGICAL, eRaw) then
                    if self:CastE(k) then return true end
                end
            end
        end
    end
    return false
end

function Yasuo:LastHit()
    local node = Menu.lasthit
    if node.useQ:Value() and not S.hasQ3 and S.qR then
        local rs = (KIT.qRange + 20) * (KIT.qRange + 20)
        local qDmg = (KIT.qBase[math_max(S.qLv, 1)] or 0) + KIT.qAD * S.ad
        for i = 1, CMn do
            if DistSqr(CMx[i], CMz[i], S.myX, S.myZ) <= rs then
                if HealthAfter(CMo[i], S.qDelay) <= qDmg then
                    if self:CastQAt(CMx[i], CMz[i]) then return true end
                end
            end
        end
    end
    if node.useE:Value() and S.eR and not S.dashing and CanMove() then
        local eRaw = ERawDamage()
        for k = 1, DUn do
            if not DUhero[k] and (not node.noETower:Value() or DUsafe[k]) then
                local unit = DUo[k]
                if eRaw > 0 and HealthAfter(unit, S.eDelay)
                    <= Mitigate(unit, DAMAGE_TYPE_MAGICAL, eRaw) then
                    if self:CastE(k) then return true end
                end
            end
        end
    end
    return false
end

function Yasuo:Flee()
    local node = Menu.flee
    if node.useE:Value() and S.eR and not S.dashing and mousePos then
        local k, d2 = self:BestEToCursor(node.noETower:Value())
        if k ~= 0 and d2 < DistSqr(S.myX, S.myZ, mousePos.x, mousePos.z) then
            if self:CastE(k) then return true end
        end
    end
    if node.useQ3:Value() and S.hasQ3 then
        local i = self:Target(KIT.q3Range)
        if i ~= 0 and self:CastQ3(i, HitChanceOf(Menu.pred.hcQ3:Value())) then return true end
    end
    if node.useQ:Value() and not S.hasQ3 then
        local i = self:Target(KIT.qRange)
        if i ~= 0 and self:CastQ(i, HitChanceOf(Menu.pred.hcQ:Value())) then return true end
        return self:StackQ()
    end
    return false
end

function Yasuo:WallJump()
    if not S.eR or S.dashing then return false end
    local mp = mousePos
    if not mp then return false end
    local mx, mz = mp.x, mp.z
    local reach = Menu.walljump.range:Value()
    local reachSqr = reach * reach
    local allowPush = Menu.walljump.push:Value()
    local bestIdx, bestDistSqr, bestRank = 0, 0, 3
    for k = 1, DUn do
        local rank = DUwall[k]
        if rank and (rank == 1 or allowPush) then
            local d2 = DistSqr(DUx[k], DUz[k], mx, mz)
            if d2 <= reachSqr and (rank < bestRank or (rank == bestRank and d2 < bestDistSqr)) then
                bestIdx, bestDistSqr, bestRank = k, d2, rank
            end
        end
    end
    if bestIdx == 0 then return false end
    return self:CastEAimed(bestIdx)
end

function Yasuo:WindWall()
    local node = Menu.windwall
    local logMiss = Menu.debug.missNames:Value() == true
    local canCast = node.enable:Value() == true and S.wR
        and not (node.onlyCombo:Value() and S.mode ~= "Combo")
    if not canCast and not logMiss then return false end

    local minThreat = node.minThreat:Value()
    local lowHp = S.hpPct * 100 < node.hpSafe:Value()
    local bestThreat, bestX, bestZ = 0, nil, nil
    local scanSqr = 2800 * 2800
    local hitBase = S.br * 1.3

    if MissileSeen > LIM.partMemoCap then
        MissileThreat = {}
        MissileSeen = 0
    end
    local count = (GameMissileCount and GameMissileCount()) or 0
    for i = 1, count do
        local m = GameMissile(i)
        if m and m.valid and m.isEnemy then
            local mp = m.pos
            if mp and DistSqr(mp.x, mp.z, S.myX, S.myZ) < scanSqr then
                local id = m.networkID
                local info = MissileThreat[id]
                if info == nil then
                    local nm = m.name
                    info = DANGER[nm] or false
                    MissileThreat[id] = info
                    MissileSeen = MissileSeen + 1
                    if not info and logMiss and type(nm) == "string" and nm ~= ""
                        and MEMO.missSeen[nm] == nil then
                        if MEMO.missN > LIM.nameLogCap then
                            MEMO.missSeen = {}
                            MEMO.missN = 0
                        end
                        MEMO.missSeen[nm] = true
                        MEMO.missN = MEMO.missN + 1
                        print(string_format("[Yasuo] MISSILE %q from %s", nm,
                            PartOwnerLabel(mp.x, mp.z) or "far"))
                    end
                end
                if info then
                    local threat = info.threat + (lowHp and 3 or 0)
                    local gate = node.spells[m.name]
                    if (not gate or gate:Value()) and threat > bestThreat
                        and (threat >= minThreat or lowHp) then
                        local a, b = m.startPos, m.endPos
                        if a and b then
                            local jx, jz, onSeg = ProjectOnSegment(a.x, a.z, b.x, b.z, S.myX, S.myZ)
                            if onSeg and (jx - mp.x) * (b.x - a.x) + (jz - mp.z) * (b.z - a.z) > 0 then
                                local reach = (m.width or 70) * 0.5 + hitBase
                                if DistSqr(S.myX, S.myZ, jx, jz) < reach * reach then
                                    bestThreat, bestX, bestZ = threat, mp.x, mp.z
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for i = 1, EHn do
        if EHd[i] * EHd[i] < scanSqr then
            local spell = EHo[i].activeSpell
            if spell and spell.valid == true then
                local info = DANGER[spell.name]
                if info then
                    local threat = info.threat + (lowHp and 3 or 0)
                    local gate = node.spells[spell.name]
                    if (not gate or gate:Value()) and threat > bestThreat
                        and (threat >= minThreat or lowHp) then
                        local hit = false
                        local tgt = spell.target
                        if tgt ~= nil and (tgt == myHero or tgt == myHero.handle
                            or tgt == myHero.networkID) then
                            hit = true
                        else
                            local sp = spell.startPos
                            local ep = spell.toPos or spell.placementPos
                            local sx = (sp and sp.x) or EHx[i]
                            local sz = (sp and sp.z) or EHz[i]
                            local ex = (ep and ep.x) or S.myX
                            local ez = (ep and ep.z) or S.myZ
                            if DistSqr(ex, ez, EHx[i], EHz[i]) < 2500 then
                                ex, ez = S.myX, S.myZ
                            end
                            local jx, jz, onSeg = ProjectOnSegment(sx, sz, ex, ez, S.myX, S.myZ)
                            if onSeg then
                                local reach = (spell.width or 100) * 0.5 + hitBase
                                hit = DistSqr(S.myX, S.myZ, jx, jz) < reach * reach
                            end
                        end
                        if hit then
                            bestThreat, bestX, bestZ = threat, EHx[i], EHz[i]
                        end
                    end
                end
            end
        end
    end

    if not bestX or not canCast then return false end
    self:SaveCursor()
    Control.CastSpell(HK_W, Vector(bestX, S.myY, bestZ))
    return true
end

function Yasuo:LoadMenu()
    Menu = MenuElement({type = MENU, id = "yasuoDepressive", name = "[DepressiveAIONext] Yasuo"})
    Menu:MenuElement({name = " ", drop = {"The Wind Samurai v" .. VERSION}})

    Menu:MenuElement({type = MENU, id = "combo", name = "[Combo] Settings"})
    Menu.combo:MenuElement({id = "useQ", name = "Use [Q1/Q2]", value = true})
    Menu.combo:MenuElement({id = "useQ3", name = "Use [Q3]", value = true})
    Menu.combo:MenuElement({id = "useE", name = "Use [E]", value = true})
    Menu.combo:MenuElement({id = "eMode", name = "[E] Logic", value = 3, drop = {"Towards Target", "Towards Cursor", "Smart (Auto)"}})
    Menu.combo:MenuElement({id = "eGapRange", name = "[E] Gap Close Range", value = 900, min = 475, max = 1800, step = 25})
    Menu.combo:MenuElement({id = "noETower", name = "Don't [E] into Tower", value = true})
    Menu.combo:MenuElement({id = "qInDash", name = "[Q] Always cast while dashing", value = true})
    Menu.combo:MenuElement({id = "eEngage", name = "[E Engage] Path through minions", value = true})
    Menu.combo:MenuElement({id = "stackQ", name = "Stack Q on minions if no target", value = true})
    Menu.combo:MenuElement({id = "eMarkBySource", name = "[E] Mark fallback: any buff of mine", value = false})
    Menu.combo:MenuElement({type = MENU, id = "ign", name = "Ignite Settings"})
    Menu.combo.ign:MenuElement({id = "use", name = "Use Ignite", value = true})
    Menu.combo.ign:MenuElement({id = "mode", name = "Mode", value = 2, drop = {"Kill Steal Only", "In Fight if Killable"}})
    Menu.combo:MenuElement({type = MENU, id = "trade", name = "Smart Trade Optimizer"})
    Menu.combo.trade:MenuElement({id = "enable", name = "Enable Smart Trading", value = true})
    Menu.combo.trade:MenuElement({id = "shield", name = "Prefer trading with Flow Shield", value = true})
    Menu.combo.trade:MenuElement({id = "flowPct", name = "Min Flow % to engage", value = 80, min = 0, max = 100, step = 5})
    Menu.combo.trade:MenuElement({id = "antiGank", name = "Anti-Gank: limit E if outnumbered", value = true})

    Menu:MenuElement({type = MENU, id = "ult", name = "[Ultimate] Settings"})
    Menu.ult:MenuElement({id = "team", name = "[R] on airborne", value = true})
    Menu.ult:MenuElement({id = "teamMin", name = "  Min enemies airborne", value = 2, min = 1, max = 5})
    Menu.ult:MenuElement({id = "airblade", name = "[Airblade] E towards airborne, then R", value = true})
    Menu.ult:MenuElement({id = "noRDash", name = "Don't R while dashing", value = true})

    Menu:MenuElement({type = MENU, id = "harass", name = "[Harass] Settings"})
    Menu.harass:MenuElement({id = "useQ", name = "Use [Q1/Q2]", value = true})
    Menu.harass:MenuElement({id = "useQ3", name = "Use [Q3]", value = true})
    Menu.harass:MenuElement({id = "stackQ", name = "Stack Q on minions", value = true})

    Menu:MenuElement({type = MENU, id = "clear", name = "[Lane/Jungle Clear] Settings"})
    Menu.clear:MenuElement({id = "useQ", name = "Use [Q1/Q2]", value = true})
    Menu.clear:MenuElement({id = "useQ3", name = "Use [Q3]", value = true})
    Menu.clear:MenuElement({id = "q3Min", name = "  Min minions for [Q3]", value = 3, min = 1, max = 7})
    Menu.clear:MenuElement({id = "useE", name = "Use [E]", value = true})
    Menu.clear:MenuElement({id = "eLH", name = "  [E] Logic", value = 1, drop = {"Last Hit Only", "Always"}})
    Menu.clear:MenuElement({id = "noETower", name = "Don't [E] into Tower", value = true})

    Menu:MenuElement({type = MENU, id = "lasthit", name = "[LastHit] Settings"})
    Menu.lasthit:MenuElement({id = "useQ", name = "Use [Q1/Q2]", value = true})
    Menu.lasthit:MenuElement({id = "useE", name = "Use [E]", value = true})
    Menu.lasthit:MenuElement({id = "noETower", name = "Don't [E] into Tower", value = true})

    Menu:MenuElement({type = MENU, id = "flee", name = "[Flee] Settings"})
    Menu.flee:MenuElement({id = "useE", name = "Use [E] to flee", value = true})
    Menu.flee:MenuElement({id = "noETower", name = "Don't [E] into Tower", value = true})
    Menu.flee:MenuElement({id = "useQ3", name = "Use [Q3] while fleeing", value = true})
    Menu.flee:MenuElement({id = "useQ", name = "Use [Q1/Q2] while fleeing", value = true})

    Menu:MenuElement({type = MENU, id = "walljump", name = "[Wall Jump] Settings"})
    Menu.walljump:MenuElement({id = "key", name = "Wall Jump Key", key = string_byte("Z")})
    Menu.walljump:MenuElement({id = "range", name = "Cursor Search Radius", value = 350, min = 100, max = 900, step = 25})
    Menu.walljump:MenuElement({id = "push", name = "Allow Push Through Wall", value = true})
    Menu.walljump:MenuElement({id = "draw", name = "Show Wall Jump Indicator", value = true})

    Menu:MenuElement({type = MENU, id = "windwall", name = "[Wind Wall] Settings"})
    Menu.windwall:MenuElement({id = "enable", name = "Enable Auto Wind Wall", value = true})
    Menu.windwall:MenuElement({id = "onlyCombo", name = "Only in Combo Mode", value = false})
    Menu.windwall:MenuElement({id = "minThreat", name = "Min Threat Score to block", value = 5, min = 1, max = 10})
    Menu.windwall:MenuElement({id = "hpSafe", name = "Always block if HP% below", value = 40, min = 5, max = 100, step = 5})
    Menu.windwall:MenuElement({type = MENU, id = "spells", name = "Spells to Block"})
    for i = 1, DANGER_COUNT do
        local name = DANGER_NAMES[i]
        Menu.windwall.spells:MenuElement({id = name, name = name, value = true})
    end

    Menu:MenuElement({type = MENU, id = "pred", name = "[Prediction] Settings"})
    Menu.pred:MenuElement({name = " ", drop = {"Engine: GGPrediction"}})
    Menu.pred:MenuElement({id = "hcQ", name = "Hitchance [Q]", value = 1, drop = {"Normal", "High", "Immobile"}})
    Menu.pred:MenuElement({id = "hcQ3", name = "Hitchance [Q3]", value = 2, drop = {"Normal", "High", "Immobile"}})

    Menu:MenuElement({type = MENU, id = "debug", name = "[Debug] Buff Dump"})
    Menu.debug:MenuElement({id = "watch", name = "Print each new buff name once", value = false})
    Menu.debug:MenuElement({id = "dumpKey", name = "Dump every buff now", key = string_byte("J")})
    Menu.debug:MenuElement({id = "particles", name = "Also dump particles near units", value = false})
    Menu.debug:MenuElement({id = "partNames", name = "Log every new particle name with 'Yasuo'", value = false})
    Menu.debug:MenuElement({id = "missNames", name = "Log unknown enemy missile names", value = false})

    Menu:MenuElement({type = MENU, id = "draw", name = "[Drawing] Settings"})
    Menu.draw:MenuElement({id = "qRange", name = "Draw [Q] Range", value = true})
    Menu.draw:MenuElement({id = "q3Range", name = "Draw [Q3] Range", value = true})
    Menu.draw:MenuElement({id = "eRange", name = "Draw [E] Range", value = true})
    Menu.draw:MenuElement({id = "eGap", name = "Draw [E] Gap Close Range", value = false})
    Menu.draw:MenuElement({id = "rRange", name = "Draw [R] Range", value = false})
    Menu.draw:MenuElement({id = "killable", name = "Draw Kill Indicator", value = true})
    Menu.draw:MenuElement({id = "flow", name = "Draw Flow Shield Status", value = true})
    Menu.draw:MenuElement({id = "qStacks", name = "Draw [Q] Stacks", value = true})
    Menu.draw:MenuElement({id = "eDashPos", name = "Draw [E] Dash Positions", value = true})
    Menu.draw:MenuElement({id = "panel", name = "Status Panel (Wall / Mark / Flow / Cooldowns)", value = true})
end

function Yasuo:Tick()
    TICK = TICK + 1
    NOW = GameTimer()

    if self.cursorBackX then
        Control.SetCursorPos(self.cursorBackX, self.cursorBackY)
        self.cursorBackX, self.cursorBackY = nil, nil
    end

    if self.qHeld then self:ReleaseQ() end

    if ShouldWait() then
        self.wjDraw = false
        self:AllowAttack(true)
        return
    end

    SyncSelf()
    SyncMinions()
    SyncEnemies()
    ScanParticles()
    SyncMarks()
    SyncTurrets()
    local wjHeld = Menu.walljump.key:Value() == true and S.eR and not S.dashing
    local wjShow = not S.dashing and Menu.walljump.draw:Value()
        and Menu.draw.eDashPos:Value()
    self.wjDraw = wjHeld or wjShow
    SyncDashTargets(self.wjDraw)
    self:Debug()

    self:WindWall()

    if self:DashQ() then return end

    if wjHeld and self:WallJump() then return end

    local mode = S.mode
    if mode == "None" then
        return
    end

    if mode == "Combo" then
        if self:Ultimate() then return end
        if self:Airblade() then return end
        self:Combo()
    elseif mode == "Harass" then
        self:Harass()
    elseif mode == "Clear" then
        self:Clear()
    elseif mode == "LastHit" then
        self:LastHit()
    elseif mode == "Flee" then
        self:Flee()
    end
end

local COL = {
    q    = Draw and Draw.Color and Draw.Color(80, 255, 255, 255),
    q3   = Draw and Draw.Color and Draw.Color(80, 255, 100, 100),
    e    = Draw and Draw.Color and Draw.Color(80, 100, 255, 100),
    egap = Draw and Draw.Color and Draw.Color(50, 100, 200, 255),
    r    = Draw and Draw.Color and Draw.Color(50, 255, 200, 50),
    shield = Draw and Draw.Color and Draw.Color(255, 50, 200, 255),
}
local COL_KILL   = Draw and Draw.Color and Draw.Color(255, 255, 30, 30)
local COL_WALL   = Draw and Draw.Color and Draw.Color(200, 255, 0, 255)
local COL_PUSH   = Draw and Draw.Color and Draw.Color(200, 255, 170, 0)
local COL_DASH   = Draw and Draw.Color and Draw.Color(90, 150, 150, 150)
local COL_UNSAFE = Draw and Draw.Color and Draw.Color(180, 255, 0, 0)

local PANEL = {
    bg     = Draw and Draw.Color and Draw.Color(180, 10, 10, 15),
    bord   = Draw and Draw.Color and Draw.Color(255, 200, 50, 50),
    rdy    = Draw and Draw.Color and Draw.Color(255, 50, 255, 50),
    cd     = Draw and Draw.Color and Draw.Color(255, 255, 80, 80),
    off    = Draw and Draw.Color and Draw.Color(255, 130, 130, 130),
    mark   = Draw and Draw.Color and Draw.Color(255, 255, 80, 255),
    flow   = Draw and Draw.Color and Draw.Color(255, 255, 255, 0),
    shield = Draw and Draw.Color and Draw.Color(255, 0, 255, 0),
}

local PC = {
    tick = -1,
    x = 810,
    y = 870,
    marked = 0,
    markText = "MARK 0",
    flowText = "FLOW 0",
    shield = false,
    cdText = {"Q", "W", "E", "R"},
    cdReady = {false, false, false, false},
}

function Yasuo:Draw()
    if myHero.dead or not Menu then return end
    local pos = myHero.pos
    local node = Menu.draw

    if node.qRange:Value() and not S.hasQ3 then
        Draw.Circle(pos, KIT.qRange, 1, COL.q)
    end
    if node.q3Range:Value() and S.hasQ3 then
        Draw.Circle(pos, KIT.q3Range, 1, COL.q3)
    end
    if node.eRange:Value() then
        Draw.Circle(pos, KIT.eRange, 1, COL.e)
    end
    if node.eGap:Value() then
        Draw.Circle(pos, Menu.combo.eGapRange:Value(), 1, COL.egap)
    end
    if node.rRange:Value() then
        Draw.Circle(pos, KIT.rRange, 1, COL.r)
    end

    if node.eDashPos:Value() then
        for k = 1, DUn do
            local rank = DUwall[k]
            local col = (rank == 1 and COL_WALL) or (rank == 2 and COL_PUSH)
                or (DUsafe[k] and COL_DASH) or COL_UNSAFE
            Draw.Circle(Vector(DUx[k], S.myY, DUz[k]), 55, 2, col)
        end
    elseif self.wjDraw and Menu.walljump.draw:Value() then
        for k = 1, DUn do
            local rank = DUwall[k]
            if rank then
                Draw.Circle(Vector(DUx[k], S.myY, DUz[k]), 55, 2,
                    (rank == 2 and COL_PUSH) or COL_WALL)
            end
        end
    end

    if node.killable:Value() then
        for i = 1, EHn do
            if not EHinvuln[i] then
                local p2 = EHo[i].pos2D
                if p2 ~= nil and p2.onScreen == true and self:Killable(i) then
                    Draw.Text("KILL", 22, p2.x - 18, p2.y - 36, COL_KILL)
                end
            end
        end
    end

    if node.flow:Value() then
        local p2 = myHero.pos2D
        if p2 and p2.onScreen then
            local txt = (S.shield and "SHIELD") or string_format("%d%%", S.flowPct)
            Draw.Text(txt, 18, p2.x - 20, p2.y + 24, COL.shield)
        end
    end

    if node.qStacks:Value() and not S.hasQ3 then
        local p2 = myHero.pos2D
        if p2 and p2.onScreen then
            Draw.Text("Q " .. S.qStacks .. "/2", 18, p2.x - 16, p2.y + 44, COL.q3)
        end
    end

    if node.panel:Value() then
        self:DrawPanel()
    end
end

function Yasuo:DrawPanel()
    if PC.tick ~= TICK then
        PC.tick = TICK

        local res = GameResolution and GameResolution()
        if res and res.x and res.y then
            PC.x = res.x / 2 - 150
            PC.y = res.y - 210
        end

        local marked = 0
        for i = 1, EHn do
            if EHmark[i] then marked = marked + 1 end
        end
        if marked ~= PC.marked then
            PC.marked = marked
            PC.markText = string_format("MARK %d", marked)
        end

        PC.shield = S.shield
        PC.flowText = (S.shield and "SHIELD") or string_format("FLOW %d", S.flowPct)

        local cdText, cdReady = PC.cdText, PC.cdReady
        cdReady[1], cdReady[2], cdReady[3], cdReady[4] = S.qR, S.wR, S.eR, S.rR
        local qn = (S.hasQ3 and "Q3") or "Q"
        cdText[1] = (S.qR and (qn .. " RDY")) or string_format("%s %.1f", qn, S.qCd)
        cdText[2] = (S.wR and "W RDY") or string_format("W %.1f", S.wCd)
        cdText[3] = (S.eR and "E RDY") or string_format("E %.1f", S.eCd)
        cdText[4] = (S.rR and "R RDY") or string_format("R %.1f", S.rCd)
    end

    local x, y = PC.x, PC.y

    if Draw.Rect then
        Draw.Rect(x, y, 300, 56, PANEL.bg)
        Draw.Rect(x, y, 300, 2, PANEL.bord)
    end

    local wallOn = Menu.windwall.enable:Value() == true
    local wallCol = (wallOn and PANEL.rdy) or PANEL.off
    Draw.Text("WALL", 12, x + 10, y + 8, wallCol)
    Draw.Text((wallOn and "ON") or "off", 12, x + 62, y + 8, wallCol)

    Draw.Text(PC.markText, 12, x + 110, y + 8, (PC.marked > 0 and PANEL.mark) or PANEL.off)
    Draw.Text(PC.flowText, 12, x + 200, y + 8, (PC.shield and PANEL.shield) or PANEL.flow)

    local cdText, cdReady = PC.cdText, PC.cdReady
    for i = 1, 4 do
        Draw.Text(cdText[i], 12, x + 10 + (i - 1) * 72, y + 32, (cdReady[i] and PANEL.rdy) or PANEL.cd)
    end
end

local function Init()
    if not MenuElement or not _G.SDK then return false end
    MapPos = _G.MapPosition
    local ok, obj = pcall(Yasuo.New)
    if not ok or not obj then
        print("[" .. SCRIPT_NAME .. "] init failed: " .. tostring(obj))
        return false
    end
    _G.DepressiveYasuoInstance = obj

    Callback.Add("Tick", function() obj:Tick() end)
    Callback.Add("Draw", function() obj:Draw() end)

    print("[" .. SCRIPT_NAME .. "] Loaded v" .. VERSION)
    return true
end

if not _G.DepressiveYasuoInstance and not Init() then
    local retries = 0
    local retryTick
    retryTick = function()
        if _G.DepressiveYasuoInstance then Callback.Del("Tick", retryTick) return end
        retries = retries + 1
        if Init() or retries > 600 then
            Callback.Del("Tick", retryTick)
        end
    end
    Callback.Add("Tick", retryTick)
end
