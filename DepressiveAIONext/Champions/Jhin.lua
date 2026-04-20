local VERSION = "1.0"
local SCRIPT_NAME = "DepressiveJhin"

if _G.__DEPRESSIVE_NEXT_JHIN_LOADED then return end
if myHero.charName ~= "Jhin" then return end
_G.__DEPRESSIVE_NEXT_JHIN_LOADED = true
_G.DepressiveAIONextLoadedChampion = true

pcall(require, "GGPrediction")
local math_floor  = math.floor
local math_huge   = math.huge
local math_max    = math.max
local math_min    = math.min
local math_sqrt   = math.sqrt
local math_abs    = math.abs
local string_find = string.find
local string_lower = string.lower
local string_format = string.format
local table_insert = table.insert
local pairs       = pairs
local ipairs      = ipairs
local pcall       = pcall
local Game        = _G.Game
local Control     = _G.Control
local Draw        = _G.Draw
local Vector      = _G.Vector
local myHero      = _G.myHero
local GameTimer   = Game.Timer
local GameHeroCount = Game.HeroCount
local GameHero    = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion  = Game.Minion
local _Q, _W, _E, _R = 0, 1, 2, 3
local HK_Q        = HK_Q or _Q
local HK_W        = HK_W or _W
local HK_E        = HK_E or _E
local HK_R        = HK_R or _R
local TEAM_ALLY   = myHero.team
local TEAM_ENEMY  = (TEAM_ALLY == 100 and 200) or 100
local PRED_ENGINE_GG = 1

local AA_RANGE_BASE   = 550

local PASSIVE_MAX_SHOTS  = 4
local PASSIVE_RELOAD_T   = 2.5
local PASSIVE_IDLE_T     = 10.0
local PASSIVE_4TH_MISSING = {0.15, 0.20, 0.25}
local PASSIVE_4TH_CRIT_MULT = 1.75

local Q_RANGE         = 600
local Q_BASE_DAMAGE   = {45, 80, 115, 150, 185}
local Q_AD_RATIO      = 0.65
local Q_BOUNCE_MULT   = 1.35

local W_RANGE         = 2550
local W_SPEED         = 5000
local W_DELAY         = 0.25
local W_RADIUS        = 40
local W_BASE_DAMAGE   = {50, 80, 110, 140, 170}
local W_BAD_RATIO     = 0.65
local W_ROOT_DURATION = 1.5

local E_RANGE         = 750
local E_POST_ATTACK_RANGE = 400
local E_ARM_TIME      = 1.0
local E_BLOOM_DELAY   = 2.0
local E_RADIUS        = 160
local E_BASE_DAMAGE   = {120, 150, 180, 210, 240}
local E_AP_RATIO      = 0.12

local R_RANGE_MAX     = 3500
local R_BASE_MIN      = {40, 100, 160}
local R_BASE_MAX      = {140, 350, 560}
local R_BAD_MIN       = 0.20
local R_BAD_MAX       = 0.70
local R_MISSING_SCALE = 0.025
local R_SHOT_COUNT    = 4
local R_INTER_SHOT    = 0.8
local R_4TH_CRIT_MULT = 2.0

local SCRIPT_TICK_INTERVAL = 0.02
local Q_CAST_BUFFER    = 0.15
local W_CAST_BUFFER    = 0.20
local E_CAST_BUFFER    = 0.20
local R_START_BUFFER   = 0.60
local R_HANDLE_INTERVAL = 0.05

local MODE_CACHE_DURATION    = 0.05
local HERO_CACHE_COMBAT      = 0.08
local HERO_CACHE_IDLE        = 0.16
local MINION_CACHE_COMBAT    = 0.10
local MINION_CACHE_IDLE      = 0.20
local COUNT_CACHE_DURATION   = 0.05
local TARGET_CACHE_DURATION  = 0.05
local COLLISION_CACHE_DURATION = 0.06
local IMMOBILE_CACHE_DURATION = 0.05
local MARK_CACHE_DURATION    = 0.10
local BUFF_NAME_CACHE_DURATION = 0.10
local PREDICTION_CACHE_DURATION = 0.04
local DRAW_CACHE_DURATION    = 0.12
local HERO_TYPE              = myHero.type
local R_CONE_COS_SQR         = 0.7409
local SPELLKEY_TO_INT        = {W = 1}

local ActiveMode = "None"
local PerfCache = {
    mode = {tick = 0, value = "None"},
    heroes = {tick = 0, all = {}, byRange = {}},
    enemyMinions = {tick = 0, all = {}, byRange = {}},
    collisionMinions = {tick = 0, all = {}},
    enemyCount = {},
    minionCount = {},
    target = {},
    lineCollision = {},
    championCollision = {},
    immobile = {},
    marked = {},
    buffNames = {},
    prediction = {},
    dmgValid = {},
}

local function Vec(x, y, z)
    if Vector then return Vector(x, y, z) end
    return {x = x, y = y, z = z}
end

local function Dist(a, b)
    local p1, p2 = a.pos or a, b.pos or b
    if not p1 or not p2 then return math_huge end
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return math_sqrt(dx * dx + dz * dz)
end

local function DistSqr(a, b)
    local p1, p2 = a.pos or a, b.pos or b
    if not p1 or not p2 then return math_huge end
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return dx * dx + dz * dz
end

local function Extend(from, to, distance)
    local f = from.pos or from
    local t = to.pos or to
    local dx, dz = t.x - f.x, (t.z or t.y) - (f.z or f.y)
    local d = math_sqrt(dx * dx + dz * dz)
    if d < 1 then return Vec(f.x, f.y or 0, f.z or f.y or 0) end
    local k = distance / d
    return Vec(f.x + dx * k, f.y or 0, (f.z or f.y) + dz * k)
end

local function NormalizeDirection(from, to)
    local f = from.pos or from
    local t = to.pos or to
    local dx, dz = t.x - f.x, (t.z or t.y) - (f.z or f.y)
    local lenSq = dx * dx + dz * dz
    if lenSq < 1 then return nil, nil end
    local invLen = 1 / math_sqrt(lenSq)
    return dx * invLen, dz * invLen
end

local function PointOnLineSegment(p, a, b, radius)
    local pp = p.pos or p
    local ax, az = a.x, a.z or a.y
    local bx, bz = b.x, b.z or b.y
    local px, pz = pp.x, pp.z or pp.y
    local abx, abz = bx - ax, bz - az
    local apx, apz = px - ax, pz - az
    local abLenSq = abx * abx + abz * abz
    if abLenSq < 1 then return false end
    local t = (apx * abx + apz * abz) / abLenSq
    if t < 0 or t > 1 then return false end
    local cx, cz = ax + t * abx, az + t * abz
    local dx, dz = px - cx, pz - cz
    return (dx * dx + dz * dz) <= radius * radius
end

local function RGBA(a, r, g, b)
    if Draw and Draw.Color then return Draw.Color(a, r, g, b) end
    return {a = a, r = r, g = g, b = b}
end

local function DrawCircle3D(p, r, w, c)
    if not Draw or not Draw.Circle then return end
    Draw.Circle(p, r, w, c)
end

local function IsValid(u)
    return u and u.valid and not u.dead and u.visible
end

local function IsInRange(source, target, range)
    if not range then return true end
    return DistSqr(source, target) <= range * range
end

local function IsValidTarget(u, range)
    if not IsValid(u) then return false end
    if range and not IsInRange(myHero, u, range) then return false end
    return true
end

local UNTARGETABLE_BUFFS = {
    "kayler", "fizze", "vladimirsanguinepool", "zhonyasringshield",
    "stopwatch", "chronoshift", "undyingrage", "kindredrnodeathbuff",
    "willrevive", "zacrebirthready", "untargetable",
}
local SPELL_SHIELD_BUFFS = {
    "sivirshield", "nocturneshroudofdarkness", "bansheesveil",
    "edgeofnight", "morganae",
}
local PHYSICAL_IMMUNE_BUFFS = {
    "jaxcounterstrike", "shenwbuff", "pantheonpassive",
}
local BLIND_BUFFS = { "blind", "teemoblind" }

local function GetActiveBuffNames(unit)
    if not unit or not unit.buffCount then return nil end
    local key = unit.networkID or 0
    local now = GameTimer()
    local cached = PerfCache.buffNames[key]
    if cached and cached.buffCount == unit.buffCount and now - cached.tick < BUFF_NAME_CACHE_DURATION then
        return cached.names
    end

    local names = {}
    for i = 0, unit.buffCount - 1 do
        local b = unit:GetBuff(i)
        if b and b.count and b.count > 0 and b.name and b.expireTime and b.expireTime > now then
            names[#names + 1] = string_lower(b.name)
        end
    end
    PerfCache.buffNames[key] = {tick = now, buffCount = unit.buffCount, names = names}
    return names
end

local function HasBuffByName(unit, name)
    local names = GetActiveBuffNames(unit)
    if not names then return false end
    for i = 1, #names do
        if string_find(names[i], name, 1, true) then return true end
    end
    return false
end

local DT_TO_INT = {AA = 1, spell = 2, physical = 3, magic = 4}

local function CanTakeDamage(target, damageType)
    if not target or not target.valid or target.dead then return false end
    if target.isTargetable == false then return false end

    local bc = target.buffCount or 0
    local key = (target.networkID or 0) * 16 + (DT_TO_INT[damageType] or 0)
    local cached = PerfCache.dmgValid[key]
    if cached and cached.buffCount == bc then
        return cached.value
    end

    local result = true
    if target.isImmortal then
        if target.charName and string_lower(target.charName) ~= "sru_atakhan" then
            result = false
        end
    end
    if result then
        for i = 1, #UNTARGETABLE_BUFFS do
            if HasBuffByName(target, UNTARGETABLE_BUFFS[i]) then result = false; break end
        end
    end
    if result then
        if damageType == "AA" then
            for i = 1, #BLIND_BUFFS do
                if HasBuffByName(myHero, BLIND_BUFFS[i]) then result = false; break end
            end
            if result then
                for i = 1, #PHYSICAL_IMMUNE_BUFFS do
                    if HasBuffByName(target, PHYSICAL_IMMUNE_BUFFS[i]) then result = false; break end
                end
            end
        elseif damageType == "spell" or damageType == "physical" or damageType == "magic" then
            for i = 1, #SPELL_SHIELD_BUFFS do
                if HasBuffByName(target, SPELL_SHIELD_BUFFS[i]) then result = false; break end
            end
        end
    end

    PerfCache.dmgValid[key] = {buffCount = bc, value = result}
    return result
end

local function Ready(slot)
    return Game.CanUseSpell(slot) == 0
end

local function ManaPercent()
    return myHero.maxMana > 0 and (myHero.mana / myHero.maxMana * 100) or 100
end

local function MyHeroNotReady()
    if Game.IsChatOpen() then return true end
    if _G.JustEvade and _G.JustEvade:Evading() then return true end
    if _G.ExtLibEvade and _G.ExtLibEvade.Evading then return true end
    return myHero.dead
end

local function IsCombatMode(mode)
    return mode == "Combo" or mode == "Harass" or mode == "Clear" or mode == "Flee"
end

local function GetHeroCacheDuration()
    return IsCombatMode(ActiveMode) and HERO_CACHE_COMBAT or HERO_CACHE_IDLE
end

local function GetMinionCacheDuration()
    return IsCombatMode(ActiveMode) and MINION_CACHE_COMBAT or MINION_CACHE_IDLE
end

local function GetRangeKey(range)
    return math_floor((range or 0) + 0.5)
end

local function GetPositionKey(pos, range)
    local p = pos.pos or pos
    return math_floor(p.x / 50) * 10000000000
         + math_floor((p.z or p.y) / 50) * 10000
         + GetRangeKey(range)
end

local function RefreshEnemyHeroCache()
    local now = GameTimer()
    if now - PerfCache.heroes.tick < GetHeroCacheDuration() then return end
    local all = {}
    for i = 1, GameHeroCount() do
        local h = GameHero(i)
        if IsValid(h) and h.team == TEAM_ENEMY then
            all[#all + 1] = h
        end
    end
    PerfCache.heroes.tick = now
    PerfCache.heroes.all = all
    PerfCache.heroes.byRange = {}
    PerfCache.enemyCount = {}
    PerfCache.target = {}
    PerfCache.championCollision = {}
    PerfCache.immobile = {}
    PerfCache.marked = {}
    PerfCache.buffNames = {}
    PerfCache.prediction = {}
    PerfCache.dmgValid = {}
end

local function RefreshEnemyMinionCache()
    local now = GameTimer()
    if now - PerfCache.enemyMinions.tick < GetMinionCacheDuration() then return end
    local all = {}
    for i = 1, GameMinionCount() do
        local m = GameMinion(i)
        if m and m.valid and not m.dead and m.team == TEAM_ENEMY then
            all[#all + 1] = m
        end
    end
    PerfCache.enemyMinions.tick = now
    PerfCache.enemyMinions.all = all
    PerfCache.enemyMinions.byRange = {}
    PerfCache.minionCount = {}
end

local function RefreshCollisionMinionCache()
    local now = GameTimer()
    if now - PerfCache.collisionMinions.tick < GetMinionCacheDuration() then return end
    local all = {}
    for i = 1, GameMinionCount() do
        local m = GameMinion(i)
        if m and m.valid and not m.dead and m.team ~= TEAM_ALLY then
            all[#all + 1] = m
        end
    end
    PerfCache.collisionMinions.tick = now
    PerfCache.collisionMinions.all = all
    PerfCache.lineCollision = {}
end

local _orbwalkerAttackFn = nil
local function IsOrbwalkerAttacking()
    if not _orbwalkerAttackFn then
        local ow = _G.SDK and _G.SDK.Orbwalker
        if ow and ow.IsAutoAttacking then
            _orbwalkerAttackFn = function() return ow:IsAutoAttacking() end
        else
            return false
        end
    end
    local ok, r = pcall(_orbwalkerAttackFn)
    if ok then return r end
    return false
end

local function GetMode()
    local now = GameTimer()
    if now - PerfCache.mode.tick < MODE_CACHE_DURATION then
        return PerfCache.mode.value
    end

    local mode = "None"
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then
        local M, S = _G.SDK.Orbwalker.Modes, _G.SDK
        if S.ORBWALKER_MODE_COMBO and M[S.ORBWALKER_MODE_COMBO] then
            mode = "Combo"
        elseif S.ORBWALKER_MODE_HARASS and M[S.ORBWALKER_MODE_HARASS] then
            mode = "Harass"
        elseif S.ORBWALKER_MODE_LANECLEAR and M[S.ORBWALKER_MODE_LANECLEAR] then
            mode = "Clear"
        elseif S.ORBWALKER_MODE_LASTHIT and M[S.ORBWALKER_MODE_LASTHIT] then
            mode = "LastHit"
        elseif S.ORBWALKER_MODE_FLEE and M[S.ORBWALKER_MODE_FLEE] then
            mode = "Flee"
        end
    end

    PerfCache.mode.tick = now
    PerfCache.mode.value = mode
    return mode
end

local function GetEnemyHeroes(range)
    RefreshEnemyHeroCache()
    if not range then return PerfCache.heroes.all end
    local key = GetRangeKey(range)
    local cached = PerfCache.heroes.byRange[key]
    local now = GameTimer()
    if cached and now - cached.tick < COUNT_CACHE_DURATION then
        return cached.data
    end
    local out = {}
    local rangeSq = range * range
    for i = 1, #PerfCache.heroes.all do
        local h = PerfCache.heroes.all[i]
        if DistSqr(myHero, h) <= rangeSq then
            out[#out + 1] = h
        end
    end
    PerfCache.heroes.byRange[key] = {tick = now, data = out}
    return out
end

local function GetEnemyCount(range, unit)
    RefreshEnemyHeroCache()
    local key = GetPositionKey(unit, range)
    local cached = PerfCache.enemyCount[key]
    local now = GameTimer()
    if cached and now - cached.tick < COUNT_CACHE_DURATION then
        return cached.value
    end
    local count, rsq = 0, range * range
    for i = 1, #PerfCache.heroes.all do
        local h = PerfCache.heroes.all[i]
        if DistSqr(unit, h) < rsq then count = count + 1 end
    end
    PerfCache.enemyCount[key] = {tick = now, value = count}
    return count
end

local function GetMinionCount(range, pos)
    RefreshEnemyMinionCache()
    local key = GetPositionKey(pos, range)
    local cached = PerfCache.minionCount[key]
    local now = GameTimer()
    if cached and now - cached.tick < COUNT_CACHE_DURATION then
        return cached.value
    end
    local count, rsq = 0, range * range
    for i = 1, #PerfCache.enemyMinions.all do
        local m = PerfCache.enemyMinions.all[i]
        if DistSqr(pos, m) <= rsq then count = count + 1 end
    end
    PerfCache.minionCount[key] = {tick = now, value = count}
    return count
end

local CC_TYPES = {[5]=true,[8]=true,[12]=true,[22]=true,[23]=true,[25]=true,[29]=true,[30]=true,[31]=true,[33]=true,[34]=true,[35]=true}

local function GetBuff(unit, buffName)
    if not unit or not unit.buffCount then return nil end
    for i = 0, unit.buffCount - 1 do
        local b = unit:GetBuff(i)
        if b and b.count > 0 and b.name == buffName then return b end
    end
    return nil
end

local function IsImmobile(unit)
    if not unit or not unit.buffCount then return false, 0 end
    local key = unit.networkID or 0
    local now = GameTimer()
    local cached = PerfCache.immobile[key]
    if cached and cached.buffCount == unit.buffCount and now - cached.tick < IMMOBILE_CACHE_DURATION then
        return cached.value, cached.duration
    end
    local best = 0
    for i = 0, unit.buffCount - 1 do
        local b = unit:GetBuff(i)
        if b and b.count > 0 and b.expireTime and b.expireTime > now and CC_TYPES[b.type] then
            best = math_max(best, b.expireTime - now)
        end
    end
    local value = best > 0
    PerfCache.immobile[key] = {tick = now, buffCount = unit.buffCount, value = value, duration = best}
    return value, best
end

local function IsDashingToward(unit)
    if not unit or not unit.pathing or not unit.pathing.isDashing then return false end
    local ep = unit.pathing.endPos
    return ep and Dist(myHero.pos, ep) < Dist(myHero.pos, unit.pos)
end

local MARK_BUFF_NAMES = {
    "jhinespotteddebuff",
    "jhinespotted",
    "jhinespotteddebuffext",
    "jhinespotted_debuff",
    "jhinemark",
    "jhinpassivemark",
}

local RecentDamageLedger = {}

local function IsMarked(unit)
    if not unit or not unit.buffCount then return false end
    local key = unit.networkID or 0
    local now = GameTimer()
    local cached = PerfCache.marked[key]
    if cached and cached.buffCount == unit.buffCount and now - cached.tick < MARK_CACHE_DURATION then
        return cached.value
    end
    local found = false
    local names = GetActiveBuffNames(unit)
    if names then
        for i = 1, #names do
            local nm = names[i]
            if string_find(nm, "jhin", 1, true) and string_find(nm, "spotted", 1, true) then
                found = true; break
            end
            for j = 1, #MARK_BUFF_NAMES do
                if nm == MARK_BUFF_NAMES[j] then found = true; break end
            end
            if found then break end
        end
    end

    if not found then
        local ts = RecentDamageLedger[key]
        if ts and now - ts <= 4.0 then found = true end
    end

    PerfCache.marked[key] = {tick = now, buffCount = unit.buffCount, value = found}
    return found
end

local function CalcPhysDmg(target, raw)
    local arm = target.armor or 0
    local effArm = arm * (1 - (myHero.armorPenPercent or 0)) - (myHero.armorPen or 0)
    return raw * (effArm >= 0 and (100 / (100 + effArm)) or (2 - 100 / (100 - effArm)))
end

local function CalcMagicDmg(target, raw)
    local mr = target.magicResist or 0
    local effMR = mr * (1 - (myHero.magicPenPercent or 0)) - (myHero.magicPen or 0)
    return raw * (effMR >= 0 and (100 / (100 + effMR)) or (2 - 100 / (100 - effMR)))
end

local function GetQDmg(target)
    local l = myHero:GetSpellData(_Q).level
    if not l or l == 0 then return 0 end
    return CalcPhysDmg(target, Q_BASE_DAMAGE[l] + Q_AD_RATIO * (myHero.totalDamage or 0))
end

local function GetWDmg(target)
    local l = myHero:GetSpellData(_W).level
    if not l or l == 0 then return 0 end
    return CalcPhysDmg(target, W_BASE_DAMAGE[l] + W_BAD_RATIO * (myHero.bonusDamage or 0))
end

local function GetEDmg(target)
    local l = myHero:GetSpellData(_E).level
    if not l or l == 0 then return 0 end
    return CalcMagicDmg(target, E_BASE_DAMAGE[l] + E_AP_RATIO * (myHero.ap or 0))
end

local function GetRBracket()
    local lvl = (myHero.levelData and myHero.levelData.lvl) or myHero.level or 1
    if lvl >= 13 then return 3 end
    if lvl >= 7  then return 2 end
    return 1
end

local function GetAACritMult()
    local cc = math_min(1.0, myHero.critChance or 0)

    if cc <= 0 then return 1.0 end
    return 1.0 + cc * 0.75
end

local function Get4thShotDmg(target)
    local raw = (myHero.totalDamage or 0) * PASSIVE_4TH_CRIT_MULT
    local missing = math_max(0, (target.maxHealth or 0) - (target.health or 0))
    local bracket = GetRBracket()
    raw = raw + missing * PASSIVE_4TH_MISSING[bracket]
    return CalcPhysDmg(target, raw)
end

local function GetAADmg(target, isFourth)
    if isFourth then return Get4thShotDmg(target) end
    local ad = myHero.totalDamage or 0
    return CalcPhysDmg(target, ad * GetAACritMult())
end

local function GetRShotDmg(target, isFourth)
    local br = GetRBracket()
    local mhp = target.maxHealth or 1
    local missingPct = math_min(1.0, math_max(0, ((mhp - (target.health or 0)) / mhp)))

    local baseDmg = R_BASE_MIN[br] + (R_BASE_MAX[br] - R_BASE_MIN[br]) * missingPct
    local adDmg = (R_BAD_MIN + (R_BAD_MAX - R_BAD_MIN) * missingPct) * (myHero.bonusDamage or 0)
    local raw = baseDmg + adDmg
    if isFourth then raw = raw * R_4TH_CRIT_MULT end
    return CalcPhysDmg(target, raw)
end

local function IsLineBlocked(source, target, width)
    RefreshCollisionMinionCache()
    local srcPos = source.pos or source
    local tgtPos = target.pos or target
    local srcKey = GetPositionKey(srcPos, width)
    local tgtKey = GetPositionKey(tgtPos, width)
    local bucket = PerfCache.lineCollision[srcKey]
    local now = GameTimer()
    if bucket then
        local cached = bucket[tgtKey]
        if cached and now - cached.tick < COLLISION_CACHE_DURATION then
            return cached.value
        end
    else
        bucket = {}
        PerfCache.lineCollision[srcKey] = bucket
    end
    local blocked = false
    for i = 1, #PerfCache.collisionMinions.all do
        local m = PerfCache.collisionMinions.all[i]
        if PointOnLineSegment(m, srcPos, tgtPos, width + (m.boundingRadius or 30)) then
            blocked = true; break
        end
    end
    bucket[tgtKey] = {tick = now, value = blocked}
    return blocked
end

local function IsChampionInLine(source, target, width)
    RefreshEnemyHeroCache()
    local srcPos = source.pos or source
    local tgtPos = target.pos or target
    local srcKey = GetPositionKey(srcPos, width)
    local tgtKey = GetPositionKey(tgtPos, width)
    local targetId = target.networkID or 0
    local bucket = PerfCache.championCollision[srcKey]
    local now = GameTimer()
    if bucket then
        local cached = bucket[tgtKey]
        if cached and cached.targetId == targetId and now - cached.tick < COLLISION_CACHE_DURATION then
            return cached.blocked, cached.unit
        end
    else
        bucket = {}
        PerfCache.championCollision[srcKey] = bucket
    end

    for i = 1, #PerfCache.heroes.all do
        local h = PerfCache.heroes.all[i]
        if h.networkID ~= targetId and IsValid(h) then
            if PointOnLineSegment(h, srcPos, tgtPos, width + (h.boundingRadius or 50)) then
                bucket[tgtKey] = {tick = now, targetId = targetId, blocked = true, unit = h}
                return true, h
            end
        end
    end
    bucket[tgtKey] = {tick = now, targetId = targetId, blocked = false, unit = nil}
    return false, nil
end

local ADC_LIST = {
    ["Vayne"]=true,["Jinx"]=true,["Caitlyn"]=true,["Tristana"]=true,["Ashe"]=true,["Draven"]=true,
    ["Lucian"]=true,["KogMaw"]=true,["Twitch"]=true,["Kalista"]=true,["Sivir"]=true,["MissFortune"]=true,
    ["Jhin"]=true,["Xayah"]=true,["Aphelios"]=true,["Samira"]=true,["Zeri"]=true,["Smolder"]=true,
    ["Kindred"]=true,["Graves"]=true,["Ezreal"]=true,["Varus"]=true,["Kaisa"]=true,["Nilah"]=true,
}

local function GetTarget(range, preferMarked)
    local key = GetRangeKey(range) * 2 + (preferMarked and 1 or 0)
    local now = GameTimer()
    local cached = PerfCache.target[key]
    if cached and now - cached.tick < TARGET_CACHE_DURATION and IsValidTarget(cached.target, range) then
        return cached.target
    end

    if _G.SDK and _G.SDK.TargetSelector then
        local sel = _G.SDK.TargetSelector.SelectedTarget
        if sel and IsValidTarget(sel, range) then
            PerfCache.target[key] = {tick = now, target = sel}
            return sel
        end
    end

    local best, bestScore = nil, -math_huge
    local heroes = GetEnemyHeroes(range)
    for i = 1, #heroes do
        local h = heroes[i]
        local score = 0
        local hpPct = h.health / math_max(1, h.maxHealth)
        local d = Dist(myHero, h)
        if hpPct <= 0.25 then score = score + 220
        elseif hpPct <= 0.40 then score = score + 130
        elseif hpPct <= 0.60 then score = score + 55 end
        if ADC_LIST[h.charName] then
            score = score + 60
            if hpPct <= 0.30 then score = score + 80 end
        end
        if preferMarked and IsMarked(h) then score = score + 150 end
        score = score + (range - d) / range * 25
        score = score + (1 - hpPct) * 40
        if score > bestScore then bestScore = score; best = h end
    end
    PerfCache.target[key] = {tick = now, target = best}
    return best
end

local Jhin = {}; Jhin.__index = Jhin

function Jhin:Create()
    local self = setmetatable({}, Jhin)
    self.lastTick = 0
    self.lastQCast, self.lastWCast, self.lastECast, self.lastRCast = 0, 0, 0, 0

    self.shotsFired = 0
    self.lastShotTime = 0
    self.isReloading = false
    self.reloadUntil = 0

    self.rChanneling = false
    self.rChannelStart = 0
    self.rShotsTaken = 0
    self.rLastShot = 0
    self._lastRHandleTick = 0
    self._lastLedgerClean = 0
    self.postAttackTarget = nil
    self.wPredictionGG = nil
    self.rAimData = nil

    self.drawCache = {tick = 0, rEnemies = {}}
    self:BuildPredictions()
    self:LoadMenu()
    self:LoadCallbacks()
    print("[" .. SCRIPT_NAME .. "] Loaded v" .. VERSION)
    return self
end

function Jhin:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveJhin", name = SCRIPT_NAME})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. VERSION}})

    self.Menu:MenuElement({type = MENU, id = "pred", name = "Prediction"})
    self.Menu.pred:MenuElement({id = "engine", name = "Prediction Engine", drop = {"GGPrediction"}, value = PRED_ENGINE_GG})
    self.Menu.pred:MenuElement({id = "wHitChance", name = "W Hit Chance", value = 4, min = 1, max = 6, step = 1})

    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Use Q in combo", value = true})
    self.Menu.combo:MenuElement({id = "qOutsideAA", name = "Q only when out of AA range", value = false})
    self.Menu.combo:MenuElement({id = "useW", name = "Use W on marked target", value = true})
    self.Menu.combo:MenuElement({id = "useWImmobile", name = "Use W on immobile target (no mark needed)", value = true})
    self.Menu.combo:MenuElement({id = "useE", name = "Use E (trap) behind target", value = true})
    self.Menu.combo:MenuElement({id = "useR", name = "Use R for execute (manual key below)", value = true})
    self.Menu.combo:MenuElement({id = "comboMana", name = "Min mana %", value = 15, min = 0, max = 100, step = 5, identifier = "%"})

    self.Menu:MenuElement({type = MENU, id = "fourth", name = "4th Shot"})
    self.Menu.fourth:MenuElement({id = "override", name = "Orbwalker override on 4th shot", value = true})
    self.Menu.fourth:MenuElement({id = "saveForHero", name = "Hold 4th shot for heroes (skip minions if hero in range)", value = true})
    self.Menu.fourth:MenuElement({id = "holdRange", name = "Hold range (scan for heroes within)", value = 1000, min = 500, max = 1800, step = 50})
    self.Menu.fourth:MenuElement({id = "killPriority", name = "Prioritize killable hero on 4th shot", value = true})

    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useQ", name = "Q poke (when target isolated)", value = true})
    self.Menu.harass:MenuElement({id = "useW", name = "W poke (marked or low HP)", value = true})
    self.Menu.harass:MenuElement({id = "harassMana", name = "Min mana %", value = 40, min = 0, max = 100, step = 5, identifier = "%"})

    self.Menu:MenuElement({type = MENU, id = "clear", name = "Clear"})
    self.Menu.clear:MenuElement({id = "useQ", name = "Q for lane clear (bounce kills)", value = true})
    self.Menu.clear:MenuElement({id = "qMinMinions", name = "Min minions for Q (bounce chain)", value = 3, min = 2, max = 4})
    self.Menu.clear:MenuElement({id = "useE", name = "E for wave / jungle camp", value = true})
    self.Menu.clear:MenuElement({id = "eMinMinions", name = "Min minions in trap radius", value = 3, min = 2, max = 6})
    self.Menu.clear:MenuElement({id = "clearMana", name = "Min mana %", value = 40, min = 0, max = 100, step = 5, identifier = "%"})

    self.Menu:MenuElement({type = MENU, id = "autoW", name = "Auto W"})
    self.Menu.autoW:MenuElement({id = "onMarked", name = "Auto W on marked enemies", value = true})
    self.Menu.autoW:MenuElement({id = "onImmobile", name = "Auto W on immobile enemies", value = true})
    self.Menu.autoW:MenuElement({id = "minCCDuration", name = "Min CC remaining (s)", value = 0.4, min = 0.2, max = 2.0, step = 0.05})
    self.Menu.autoW:MenuElement({id = "minRange", name = "Min distance (avoid point-blank)", value = 300, min = 0, max = 1500, step = 50})
    self.Menu.autoW:MenuElement({id = "maxRange", name = "Max distance", value = 2550, min = 1000, max = 2550, step = 50})
    self.Menu.autoW:MenuElement({id = "collisionMinion", name = "Check minion collision (W pierces, usually off)", value = false})
    self.Menu.autoW:MenuElement({id = "collisionChamp", name = "Check champion collision (stop on non-target champ)", value = true})
    self.Menu.autoW:MenuElement({id = "modes", name = "Enable in modes", drop = {"Always", "Combo+Harass only", "Never (KS only)"}, value = 2})

    self.Menu:MenuElement({type = MENU, id = "autoE", name = "Auto E (traps)"})
    self.Menu.autoE:MenuElement({id = "selfPeel", name = "E at feet when melee close (peel)", value = true})
    self.Menu.autoE:MenuElement({id = "peelRange", name = "Peel trigger range", value = 350, min = 200, max = 600, step = 25})
    self.Menu.autoE:MenuElement({id = "onCC", name = "E on CC'd enemies", value = true})
    self.Menu.autoE:MenuElement({id = "ccMinDuration", name = "Min CC remaining (accounts for arm time)", value = 1.3, min = 0.5, max = 3.0, step = 0.1})
    self.Menu.autoE:MenuElement({id = "onPath", name = "E ahead of fleeing/path enemies", value = true})
    self.Menu.autoE:MenuElement({id = "pathLead", name = "Seconds to lead prediction", value = 1.2, min = 0.5, max = 2.5, step = 0.1})
    self.Menu.autoE:MenuElement({id = "saveCharge", name = "Keep 1 charge spare (don't drop both)", value = true})
    self.Menu.autoE:MenuElement({id = "modes", name = "Enable in modes", drop = {"Always", "Combo+Harass only", "Off"}, value = 1})

    self.Menu:MenuElement({type = MENU, id = "ult", name = "R (Curtain Call)"})
    self.Menu.ult:MenuElement({id = "semiKey", name = "Semi-manual R start key", key = string.byte("T")})
    self.Menu.ult:MenuElement({id = "autoRecast", name = "Auto-recast R shots during channel", value = true})
    self.Menu.ult:MenuElement({id = "killsteal", name = "R killsteal (start channel if 4th shot kills)", value = true})
    self.Menu.ult:MenuElement({id = "ksMinRange", name = "KS min distance", value = 1200, min = 0, max = 3500, step = 50})
    self.Menu.ult:MenuElement({id = "ksMaxRange", name = "KS max distance", value = 3500, min = 1000, max = 3500, step = 50})
    self.Menu.ult:MenuElement({id = "autoCancel", name = "Auto-cancel if no more targets", value = true})

    self.Menu:MenuElement({type = MENU, id = "ks", name = "Killsteal"})
    self.Menu.ks:MenuElement({id = "useQ", name = "Q killsteal", value = true})
    self.Menu.ks:MenuElement({id = "useW", name = "W killsteal", value = true})

    self.Menu:MenuElement({type = MENU, id = "flee", name = "Flee"})
    self.Menu.flee:MenuElement({id = "useE", name = "Drop E behind (slow chaser)", value = true})

    self.Menu:MenuElement({type = MENU, id = "draw", name = "Drawings"})
    self.Menu.draw:MenuElement({id = "enable", name = "Enable drawings", value = true})
    self.Menu.draw:MenuElement({id = "aaRange", name = "AA range", value = true})
    self.Menu.draw:MenuElement({id = "wRange", name = "W range", value = false})
    self.Menu.draw:MenuElement({id = "eRange", name = "E range", value = true})
    self.Menu.draw:MenuElement({id = "rRange", name = "R range (when channeling)", value = true})
    self.Menu.draw:MenuElement({id = "shots", name = "Shot counter (1..4)", value = true})
    self.Menu.draw:MenuElement({id = "reload", name = "Reload indicator", value = true})
    self.Menu.draw:MenuElement({id = "marked", name = "Marked enemies", value = true})
    self.Menu.draw:MenuElement({id = "rDmg", name = "R shot damage + killable on enemies", value = true})
end

function Jhin:LoadCallbacks()
    Callback.Add("Tick", function() self:OnTick() end)
    Callback.Add("Draw", function() self:OnDraw() end)
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.OnPostAttack then
        _G.SDK.Orbwalker:OnPostAttack(function(...) self:OnPostAttack(...) end)
    end
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.OnPreAttack then
        _G.SDK.Orbwalker:OnPreAttack(function(...) self:OnPreAttack(...) end)
    end
end

function Jhin:BuildPredictions()
    if not (_G.GGPrediction and type(_G.GGPrediction.SpellPrediction) == "function") then return end
    local gg = _G.GGPrediction
    self.wPredictionGG = gg:SpellPrediction({
        Type = gg.SPELLTYPE_LINE,
        Delay = W_DELAY,
        Radius = W_RADIUS,
        Range = W_RANGE,
        Speed = W_SPEED,
        Collision = false,
    })
end

function Jhin:GetGGPredictionObject(spellKey)
    local prediction = spellKey == "W" and self.wPredictionGG or nil
    if not prediction and _G.GGPrediction and type(_G.GGPrediction.SpellPrediction) == "function" then
        self:BuildPredictions()
        prediction = spellKey == "W" and self.wPredictionGG or nil
    end
    return prediction
end

function Jhin:GetSelectedPredictionEngine()
    if _G.GGPrediction and type(_G.GGPrediction.SpellPrediction) == "function" then return PRED_ENGINE_GG end
    return 0
end

function Jhin:NormalizeGGHitChance(prediction)
    if not _G.GGPrediction or not prediction or not prediction.CastPosition then return 0 end
    if prediction:CanHit(_G.GGPrediction.HITCHANCE_IMMOBILE) then return 6 end
    if prediction:CanHit(_G.GGPrediction.HITCHANCE_HIGH) then return 4 end
    if prediction:CanHit(_G.GGPrediction.HITCHANCE_NORMAL) then return 3 end
    return 2
end

function Jhin:GetPredictionRequiredHitChance(spellKey)
    if spellKey == "W" then return self.Menu.pred.wHitChance:Value() end
    return 0
end

function Jhin:GetSpellPredictionData(target, spellKey)
    if spellKey == "W" then
        return W_RANGE, W_DELAY, W_SPEED, W_RADIUS, false
    end
    return nil
end

function Jhin:PredictPosition(target, delay)
    if not target or not IsValid(target) then return nil end
    local hasPath = target.pathing and target.pathing.hasMovePath
    if hasPath and target.ms and target.ms > 0 and target.pathing.endPos then
        local predDist = target.ms * delay * 0.75
        return Extend(target.pos, target.pathing.endPos, predDist)
    end
    return Vec(target.pos.x, target.pos.y, target.pos.z)
end

function Jhin:GetPredictedCastPosition(target, spellKey)
    if not target or not IsValid(target) then return nil, 0 end
    local range, delay, speed = self:GetSpellPredictionData(target, spellKey)
    if not range then return nil, 0 end
    local required = self:GetPredictionRequiredHitChance(spellKey)
    local now = GameTimer()
    local cacheKey = (target.networkID or 0) * 8 + (SPELLKEY_TO_INT[spellKey] or 0)
    local cached = PerfCache.prediction[cacheKey]
    if cached and now - cached.tick < PREDICTION_CACHE_DURATION then
        local cachedPos = cached.castPos ~= false and cached.castPos or nil
        if not cachedPos or cached.hitChance < required then
            return nil, cached.hitChance
        end
        return cachedPos, cached.hitChance
    end

    local castPos, hitChance = nil, 0
    if self:GetSelectedPredictionEngine() == PRED_ENGINE_GG then
        local prediction = self:GetGGPredictionObject(spellKey)
        if prediction then
            prediction:GetPrediction(target, myHero)
            local rawPos = prediction.CastPosition
            if rawPos and rawPos.x and rawPos.z then
                castPos = Vec(rawPos.x, rawPos.y or myHero.pos.y, rawPos.z)
                hitChance = self:NormalizeGGHitChance(prediction)
            end
        end
    end
    if not castPos then
        local travel = (speed < math_huge and Dist(myHero, target) / speed) or 0
        castPos = self:PredictPosition(target, delay + travel)
        hitChance = 3
    end

    local validPos = castPos and IsInRange(myHero.pos, castPos, range + 20) and castPos or nil
    PerfCache.prediction[cacheKey] = {tick = now, castPos = validPos or false, hitChance = hitChance}

    if not validPos or hitChance < required then
        return nil, hitChance
    end
    return validPos, hitChance
end

local RELOAD_BUFF_NAMES = { "jhinpassivereload", "jhinreload", "jhinpassiveempty" }

local function HasReloadBuff(unit)
    local names = GetActiveBuffNames(unit)
    if not names then return false end
    for i = 1, #names do
        local nm = names[i]
        for j = 1, #RELOAD_BUFF_NAMES do
            if nm == RELOAD_BUFF_NAMES[j] then return true end
        end
    end
    return false
end

function Jhin:UpdateShotState()
    local now = GameTimer()

    if HasReloadBuff(myHero) then
        if not self.isReloading then
            self.isReloading = true
            self.reloadUntil = now + PASSIVE_RELOAD_T
        end
        self.shotsFired = 0
        return
    else
        if self.isReloading then
            self.isReloading = false
            self.shotsFired = 0
        end
    end

    if self.shotsFired > 0 and self.lastShotTime > 0 and (now - self.lastShotTime) > PASSIVE_IDLE_T then
        self.shotsFired = 0
    end
end

function Jhin:IsFourthShotReady()
    return not self.isReloading and self.shotsFired == (PASSIVE_MAX_SHOTS - 1)
end

function Jhin:CastQ(target)
    if not Ready(_Q) or GameTimer() - self.lastQCast < Q_CAST_BUFFER then return false end
    if not target or not IsValid(target) then return false end
    if Dist(myHero, target) > Q_RANGE + (target.boundingRadius or 0) then return false end
    if not CanTakeDamage(target, "spell") then return false end
    Control.CastSpell(HK_Q, target)
    self.lastQCast = GameTimer()
    return true
end

function Jhin:CastW(target, forceCollisionOff)
    if not Ready(_W) or GameTimer() - self.lastWCast < W_CAST_BUFFER then return false end
    if not target or not IsValid(target) then return false end
    local d = Dist(myHero, target)
    if d > W_RANGE then return false end
    if d < self.Menu.autoW.minRange:Value() then return false end
    if not CanTakeDamage(target, "physical") then return false end

    local castPos = self:GetPredictedCastPosition(target, "W")
    if not castPos then return false end

    if not forceCollisionOff then
        if self.Menu.autoW.collisionMinion:Value() and IsLineBlocked(myHero, castPos, W_RADIUS) then
            return false
        end
        if self.Menu.autoW.collisionChamp:Value() then
            local blocked, _ = IsChampionInLine(myHero, target, W_RADIUS)
            if blocked then return false end
        end
    end

    Control.CastSpell(HK_W, castPos)
    self.lastWCast = GameTimer()
    return true
end

function Jhin:CastE(pos)
    if not Ready(_E) or GameTimer() - self.lastECast < E_CAST_BUFFER then return false end
    if not pos then return false end
    local p = pos.pos or pos
    if Dist(myHero.pos, p) > E_RANGE then return false end
    Control.CastSpell(HK_E, Vec(p.x, p.y or myHero.pos.y, p.z or p.y))
    self.lastECast = GameTimer()
    return true
end

function Jhin:StartR()
    if not Ready(_R) or GameTimer() - self.lastRCast < R_START_BUFFER then return false end
    Control.CastSpell(HK_R)
    self.lastRCast = GameTimer()
    self.rShotsTaken = 0
    self.rChanneling = true
    self.rChannelStart = GameTimer()
    self.rAimData = nil
    return true
end

function Jhin:UpdateRChannelAim(spell)
    local activeSpell = spell or myHero.activeSpell
    if not (activeSpell and activeSpell.valid and activeSpell.startPos and activeSpell.placementPos) then return false end
    local dirX, dirZ = NormalizeDirection(activeSpell.startPos, activeSpell.placementPos)
    if not dirX then return false end
    self.rAimData = {
        startX = activeSpell.startPos.x,
        startZ = activeSpell.startPos.z or activeSpell.startPos.y,
        dirX = dirX,
        dirZ = dirZ,
    }
    return true
end

function Jhin:IsUnitInRZone(unit)
    local aim = self.rAimData
    if not aim or not unit or not unit.pos then return true end
    local ux = unit.pos.x - aim.startX
    local uz = (unit.pos.z or unit.pos.y) - aim.startZ
    local distSq = ux * ux + uz * uz
    if distSq < 1 then return true end
    if distSq > R_RANGE_MAX * R_RANGE_MAX then return false end
    local dot = ux * aim.dirX + uz * aim.dirZ
    if dot <= 0 then return false end
    return dot * dot >= distSq * R_CONE_COS_SQR
end

function Jhin:CastRShot(target)
    if not target or not IsValid(target) then return false end
    local now = GameTimer()
    if now - self.rLastShot < R_INTER_SHOT then return false end
    if Dist(myHero, target) > R_RANGE_MAX then return false end
    self:UpdateRChannelAim()
    if not self:IsUnitInRZone(target) then return false end

    local p = target.pos
    if not p then return false end

    Control.CastSpell(HK_R, Vec(p.x, p.y or myHero.pos.y, p.z or p.y))
    self.rLastShot = now
    self.rShotsTaken = self.rShotsTaken + 1
    if self.rShotsTaken >= R_SHOT_COUNT then
        self.rChanneling = false
        self.rAimData = nil
    end
    return true
end

function Jhin:CancelR()

    if self.rChanneling and Ready(_R) then
        Control.CastSpell(HK_R)
    end
    self.rChanneling = false
    self.rAimData = nil
end

local R_CHANNEL_BUFFS = { "jhinrshotbuff", "jhinrwindup", "jhinrchannel" }

function Jhin:DetectChannel()

    if myHero.activeSpell and myHero.activeSpell.valid and myHero.activeSpell.name then
        local nm = string_lower(myHero.activeSpell.name)
        if string_find(nm, "jhinr", 1, true) then
            if not self.rChanneling then
                self.rChanneling = true
                self.rChannelStart = GameTimer()
                self.rShotsTaken = 0
            end
            self:UpdateRChannelAim(myHero.activeSpell)
            return true
        end
    end
    for i = 1, #R_CHANNEL_BUFFS do
        if HasBuffByName(myHero, R_CHANNEL_BUFFS[i]) then
            if not self.rChanneling then
                self.rChanneling = true
                self.rChannelStart = GameTimer()
            end
            return true
        end
    end

    if self.rChanneling and (GameTimer() - self.rLastShot) > 0.3 and (GameTimer() - self.rChannelStart) > 0.5 then

        self.rChanneling = false
        self.rAimData = nil
    end
    return self.rChanneling
end

function Jhin:AutoW()
    if not Ready(_W) or self.rChanneling or IsOrbwalkerAttacking() then return end

    local modeGate = self.Menu.autoW.modes:Value()
    local mode = ActiveMode
    if modeGate == 3 then return end
    if modeGate == 2 and mode ~= "Combo" and mode ~= "Harass" then return end

    local maxR = self.Menu.autoW.maxRange:Value()
    local onMarked = self.Menu.autoW.onMarked:Value()
    local onImmo = self.Menu.autoW.onImmobile:Value()
    local minCC = self.Menu.autoW.minCCDuration:Value()
    local enemies = GetEnemyHeroes(maxR)

    local markedFallback = nil
    for i = 1, #enemies do
        local e = enemies[i]
        if IsValidTarget(e, maxR) and CanTakeDamage(e, "physical") then
            if onImmo then
                local imm, dur = IsImmobile(e)
                if imm and dur >= (W_DELAY + minCC) then
                    if self:CastW(e) then return end
                end
            end
            if onMarked and not markedFallback and IsMarked(e) then
                markedFallback = e
            end
        end
    end

    if markedFallback then self:CastW(markedFallback) end
end

function Jhin:CountECharges()

    local sd = myHero:GetSpellData(_E)
    if sd and sd.ammo then return sd.ammo end
    if sd and sd.currentAmmo then return sd.currentAmmo end
    return Ready(_E) and 1 or 0
end

function Jhin:AutoE()
    if not Ready(_E) or self.rChanneling then return end
    local gate = self.Menu.autoE.modes:Value()
    if gate == 3 then return end
    if gate == 2 and ActiveMode ~= "Combo" and ActiveMode ~= "Harass" then return end

    local charges = self:CountECharges()
    if self.Menu.autoE.saveCharge:Value() and charges < 2 then

    end

    if self.Menu.autoE.selfPeel:Value() then
        local pr = self.Menu.autoE.peelRange:Value()
        local threats = GetEnemyHeroes(pr)
        for i = 1, #threats do
            local e = threats[i]
            if (e.range or 500) <= 300 and IsValidTarget(e, pr) then
                if self:CastE(myHero.pos) then return end
            end
        end
    end

    local saveGate = self.Menu.autoE.saveCharge:Value() and charges < 2

    if not saveGate and self.Menu.autoE.onCC:Value() then
        local minDur = self.Menu.autoE.ccMinDuration:Value()
        local enemies = GetEnemyHeroes(E_RANGE)
        for i = 1, #enemies do
            local e = enemies[i]
            local imm, dur = IsImmobile(e)
            if imm and dur >= minDur and IsValidTarget(e, E_RANGE) then
                if self:CastE(Vec(e.pos.x, e.pos.y, e.pos.z)) then return end
            end
        end
    end

    if not saveGate and self.Menu.autoE.onPath:Value() then
        local lead = self.Menu.autoE.pathLead:Value()
        local enemies = GetEnemyHeroes(E_RANGE + 200)
        for i = 1, #enemies do
            local e = enemies[i]
            if IsValidTarget(e, E_RANGE + 200) and e.pathing and e.pathing.hasMovePath and e.ms and e.ms > 0 and e.pathing.endPos then

                local dNow = Dist(myHero, e)
                local dEnd = Dist(myHero.pos, e.pathing.endPos)
                if dEnd > dNow + 50 then
                    local predDist = e.ms * lead
                    local predPos = Extend(e.pos, e.pathing.endPos, predDist)
                    if Dist(myHero.pos, predPos) <= E_RANGE then
                        if self:CastE(predPos) then return end
                    end
                end
            end
        end
    end
end

function Jhin:HandleRChannel()
    if not self.rChanneling then return end
    if not self.Menu.ult.autoRecast:Value() then return end
    if self.rShotsTaken >= R_SHOT_COUNT then return end

    local now = GameTimer()

    if now - self._lastRHandleTick < R_HANDLE_INTERVAL then return end
    self._lastRHandleTick = now
    if now - self.rLastShot < R_INTER_SHOT then return end
    self:UpdateRChannelAim()

    local target = GetTarget(R_RANGE_MAX, true)
    if target and not self:IsUnitInRZone(target) then
        target = nil
    end
    if not target then
        local enemies = GetEnemyHeroes(R_RANGE_MAX)
        for i = 1, #enemies do
            local e = enemies[i]
            if IsValidTarget(e, R_RANGE_MAX) and CanTakeDamage(e, "physical") and self:IsUnitInRZone(e) then
                target = e
                break
            end
        end
    end
    if target then
        self:CastRShot(target)
    elseif self.Menu.ult.autoCancel:Value() and self.rShotsTaken < (R_SHOT_COUNT - 1) then
        self:CancelR()
    end
end

function Jhin:TryRStart()
    if not Ready(_R) or self.rChanneling then return end
    if not self.Menu.ult.killsteal:Value() then return end
    local minR = self.Menu.ult.ksMinRange:Value()
    local maxR = self.Menu.ult.ksMaxRange:Value()
    local enemies = GetEnemyHeroes(maxR)
    for i = 1, #enemies do
        local e = enemies[i]
        if IsValidTarget(e, maxR) and CanTakeDamage(e, "physical") then
            local d = Dist(myHero, e)
            if d >= minR and d <= maxR then

                if GetRShotDmg(e, false) >= e.health then
                    self:StartR()
                    return
                end

                if GetRShotDmg(e, true) >= e.health and e.health / math_max(1, e.maxHealth) <= 0.25 then
                    self:StartR()
                    return
                end
            end
        end
    end
end

function Jhin:SemiR()
    if not self.Menu.ult.semiKey:Value() or not Ready(_R) or self.rChanneling then return end
    self:StartR()
end

function Jhin:KillSteal()
    if self.rChanneling then return end

    if self.Menu.ks.useQ:Value() and Ready(_Q) then
        local heroes = GetEnemyHeroes(Q_RANGE + 50)
        for i = 1, #heroes do
            local e = heroes[i]
            if IsValidTarget(e, Q_RANGE + (e.boundingRadius or 0))
               and CanTakeDamage(e, "spell")
               and GetQDmg(e) >= e.health then
                if self:CastQ(e) then return end
            end
        end
    end

    if self.Menu.ks.useW:Value() and Ready(_W) and not IsOrbwalkerAttacking() then
        local heroes = GetEnemyHeroes(W_RANGE)
        for i = 1, #heroes do
            local e = heroes[i]
            if IsValidTarget(e, W_RANGE)
               and CanTakeDamage(e, "physical")
               and GetWDmg(e) >= e.health then

                if self:CastW(e) then return end
            end
        end
    end
end

function Jhin:OnPreAttack(args)
    self.postAttackTarget = args and type(args) == "table" and args.Process ~= false and args.Target and IsValid(args.Target) and args.Target or nil
    if not self.Menu.fourth.override:Value() then return end
    if not self:IsFourthShotReady() then return end

    local aaRange = (myHero.range or AA_RANGE_BASE) + (myHero.boundingRadius or 0)
    local heroes = GetEnemyHeroes(aaRange + 65)
    local attackTarget = args and args.Target or nil
    if self.Menu.fourth.saveForHero:Value() and attackTarget and attackTarget.type ~= HERO_TYPE and #heroes == 0 then
        local scanRange = self.Menu.fourth.holdRange:Value()
        if #GetEnemyHeroes(scanRange) > 0 then
            if args and type(args) == "table" then
                args.Process = false
            end
            self.postAttackTarget = nil
            return
        end
    end

    local best, bestScore = nil, -math_huge
    for i = 1, #heroes do
        local e = heroes[i]
        if IsValidTarget(e, aaRange + (e.boundingRadius or 0)) and CanTakeDamage(e, "AA") then
            local d = Dist(myHero, e)
            local dmg = Get4thShotDmg(e)
            local score = 0
            if self.Menu.fourth.killPriority:Value() and dmg >= e.health then score = score + 10000 end
            score = score + (1 - (e.health / math_max(1, e.maxHealth))) * 200
            if ADC_LIST[e.charName] then score = score + 60 end
            score = score + (aaRange - d) / aaRange * 20
            if score > bestScore then bestScore = score; best = e end
        end
    end

    if best and args and type(args) == "table" then
        args.Target = best
    end
    if args and type(args) == "table" and args.Process ~= false and args.Target and IsValid(args.Target) then
        self.postAttackTarget = args.Target
    end
    if best and _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.ForceTarget then
        pcall(function() _G.SDK.Orbwalker:ForceTarget(best) end)
    end
end

function Jhin:OnPostAttack(target)

    self.shotsFired = self.shotsFired + 1
    self.lastShotTime = GameTimer()
    if self.shotsFired >= PASSIVE_MAX_SHOTS then

        self.shotsFired = PASSIVE_MAX_SHOTS
    end

    local attackTarget = target
    if not IsValid(attackTarget) and self.postAttackTarget and IsValid(self.postAttackTarget) then
        attackTarget = self.postAttackTarget
    end
    if not IsValid(attackTarget) and _G.SDK and _G.SDK.Orbwalker and IsValid(_G.SDK.Orbwalker.LastTarget) then
        attackTarget = _G.SDK.Orbwalker.LastTarget
    end
    self.postAttackTarget = nil

    if attackTarget and attackTarget.team == TEAM_ENEMY and attackTarget.networkID then
        RecentDamageLedger[attackTarget.networkID] = GameTimer()
    end

    local mode = GetMode()
    if mode ~= "Combo" and mode ~= "Harass" then return end

    local isEnemyHeroAttackTarget = attackTarget
        and attackTarget.type == HERO_TYPE
        and attackTarget.team == TEAM_ENEMY
        and IsValid(attackTarget)

    if mode == "Combo" then
        local minMana = self.Menu.combo.comboMana:Value()
        if ManaPercent() >= minMana and self.Menu.combo.useE:Value() and Ready(_E) and isEnemyHeroAttackTarget then
            if IsInRange(myHero, attackTarget, E_POST_ATTACK_RANGE) then
                if self:CastE(attackTarget.pos) then return end
            end
        end
    end

    if self.shotsFired == PASSIVE_MAX_SHOTS then return end

    local tgt = isEnemyHeroAttackTarget and IsValidTarget(attackTarget, W_RANGE) and attackTarget or GetTarget(W_RANGE, true)
    if not tgt then return end

    if Ready(_W) then
        local inAA = Dist(myHero, tgt) <= ((myHero.range or AA_RANGE_BASE) + (tgt.boundingRadius or 0))
        if mode == "Combo" then
            local minMana = self.Menu.combo.comboMana:Value()
            if ManaPercent() >= minMana and self.Menu.combo.useW:Value() then

                if IsMarked(tgt) or IsImmobile(tgt) then
                    self:CastW(tgt)
                end
            end
        elseif mode == "Harass" then
            if ManaPercent() >= self.Menu.harass.harassMana:Value() and self.Menu.harass.useW:Value() and not inAA and IsMarked(tgt) then
                self:CastW(tgt)
            end
        end
    end
end

function Jhin:Combo()
    if ManaPercent() < self.Menu.combo.comboMana:Value() then return end
    if self.rChanneling then return end

    local target = GetTarget(W_RANGE, true)
    if not target or not CanTakeDamage(target, "physical") then return end
    local d = Dist(myHero, target)
    local aaRange = (myHero.range or AA_RANGE_BASE) + (target.boundingRadius or 0)

    if self.Menu.combo.useQ:Value() and Ready(_Q) and d <= Q_RANGE + (target.boundingRadius or 0) then
        local qGate = not self.Menu.combo.qOutsideAA:Value() or d > aaRange
        if qGate and CanTakeDamage(target, "spell") then
            self:CastQ(target)
        end
    end

    if self.Menu.combo.useW:Value() and Ready(_W) and not IsOrbwalkerAttacking() then
        local wantMarked = IsMarked(target)
        local wantImmobile = self.Menu.combo.useWImmobile:Value() and IsImmobile(target)
        if (wantMarked or wantImmobile) and d >= self.Menu.autoW.minRange:Value() then
            self:CastW(target)
        end
    end

    if self.Menu.combo.useR:Value() then
        self:TryRStart()
    end
end

function Jhin:Harass()
    if ManaPercent() < self.Menu.harass.harassMana:Value() then return end
    if self.rChanneling then return end

    local target = GetTarget(W_RANGE, true)
    if not target then return end

    if self.Menu.harass.useQ:Value() and Ready(_Q) and Dist(myHero, target) <= Q_RANGE then

        if CanTakeDamage(target, "spell") then self:CastQ(target) end
    end

    if self.Menu.harass.useW:Value() and Ready(_W) and IsMarked(target) and not IsOrbwalkerAttacking() then
        self:CastW(target)
    end
end

function Jhin:Clear()
    if self.rChanneling then return end
    if ManaPercent() < self.Menu.clear.clearMana:Value() then return end

    if self.Menu.clear.useQ:Value() and Ready(_Q) then
        RefreshEnemyMinionCache()
        local minMin = self.Menu.clear.qMinMinions:Value()
        local qRangeSq = Q_RANGE * Q_RANGE
        local inRangeCount = 0
        local killableMinion = nil
        for i = 1, #PerfCache.enemyMinions.all do
            local m = PerfCache.enemyMinions.all[i]
            if DistSqr(myHero, m) <= qRangeSq then
                inRangeCount = inRangeCount + 1
                if not killableMinion and GetQDmg(m) >= (m.health or 0) then
                    killableMinion = m
                end
            end
        end
        if killableMinion and inRangeCount >= minMin then
            self:CastQ(killableMinion)
        end
    end

    if self.Menu.clear.useE:Value() and Ready(_E) then
        local minMin = self.Menu.clear.eMinMinions:Value()
        local eRangeSq = E_RANGE * E_RANGE

        RefreshEnemyMinionCache()
        local bestM, bestN = nil, 0
        for i = 1, #PerfCache.enemyMinions.all do
            local m = PerfCache.enemyMinions.all[i]
            if DistSqr(myHero, m) <= eRangeSq then
                local n = GetMinionCount(E_RADIUS, m)
                if n > bestN then bestN = n; bestM = m end
            end
        end
        if bestM and bestN >= minMin then
            self:CastE(Vec(bestM.pos.x, bestM.pos.y, bestM.pos.z))
        end
    end
end

function Jhin:Flee()
    if self.Menu.flee.useE:Value() and Ready(_E) then
        self:CastE(myHero.pos)
    end
end

function Jhin:UpdateDrawCache()
    local now = GameTimer()
    if self.drawCache and now - self.drawCache.tick < DRAW_CACHE_DURATION then return end

    local rEnemies = {}
    local enemies = GetEnemyHeroes(R_RANGE_MAX)
    local isFourth = self.rChanneling and ((self.rShotsTaken + 1) == R_SHOT_COUNT)
    for i = 1, #enemies do
        local e = enemies[i]
        local sp = e.pos:To2D()
        if sp and sp.onScreen then
            local shotDmg = GetRShotDmg(e, isFourth)
            rEnemies[#rEnemies + 1] = {
                enemy = e,
                damage = shotDmg,
                kill = shotDmg >= e.health,
                marked = IsMarked(e),
                screenX = sp.x,
                screenY = sp.y,
            }
        end
    end

    self.drawCache = {tick = now, rEnemies = rEnemies}
end

function Jhin:OnTick()
    local now = GameTimer()
    if now - self.lastTick < SCRIPT_TICK_INTERVAL then return end
    self.lastTick = now

    local mode = GetMode()
    ActiveMode = mode

    self:UpdateShotState()
    self:DetectChannel()

    if now - self._lastLedgerClean > 1.0 then
        self._lastLedgerClean = now
        for id, ts in pairs(RecentDamageLedger) do
            if now - ts > 5.0 then RecentDamageLedger[id] = nil end
        end
    end

    if MyHeroNotReady() then return end

    if self.rChanneling then
        self:HandleRChannel()
        return
    end

    if myHero.isChanneling then return end

    self:AutoW()
    self:AutoE()
    self:KillSteal()
    self:SemiR()

    if mode == "Combo" then self:Combo()
    elseif mode == "Harass" then self:Harass()
    elseif mode == "Clear" then self:Clear()
    elseif mode == "Flee" then self:Flee()
    end
end

function Jhin:OnDraw()
    if not self.Menu.draw.enable:Value() or myHero.dead then return end

    if self.Menu.draw.rDmg:Value() or self.Menu.draw.marked:Value() then self:UpdateDrawCache() end

    if self.Menu.draw.aaRange:Value() then
        DrawCircle3D(myHero.pos, (myHero.range or AA_RANGE_BASE) + 50, 1, RGBA(150, 200, 50, 50))
    end
    if self.Menu.draw.wRange:Value() and Ready(_W) then
        DrawCircle3D(myHero.pos, W_RANGE, 1, RGBA(100, 100, 100, 255))
    end
    if self.Menu.draw.eRange:Value() and Ready(_E) then
        DrawCircle3D(myHero.pos, E_RANGE, 1, RGBA(100, 200, 100, 255))
    end
    if self.Menu.draw.rRange:Value() and self.rChanneling then
        DrawCircle3D(myHero.pos, R_RANGE_MAX, 1, RGBA(120, 255, 50, 50))
    end

    local _sp, _spDone = nil, false
    local function getSP()
        if not _spDone then _sp = myHero.pos:To2D(); _spDone = true end
        return _sp
    end

    if self.Menu.draw.shots:Value() and Draw and Draw.Text then
        local sp = getSP()
        if sp and sp.onScreen then
            local txt
            if self.isReloading then
                txt = "RELOADING"
            else
                local remaining = PASSIVE_MAX_SHOTS - self.shotsFired
                txt = string_format("SHOTS: %d/%d", remaining, PASSIVE_MAX_SHOTS)
            end
            local col = (self.shotsFired == PASSIVE_MAX_SHOTS - 1) and RGBA(255, 255, 200, 50) or RGBA(255, 200, 200, 200)
            Draw.Text(txt, 16, sp.x - 35, sp.y + 30, col)
        end
    end

    if self.Menu.draw.reload:Value() and self.isReloading and Draw and Draw.Text then
        local sp = getSP()
        if sp and sp.onScreen then
            local remaining = math_max(0, self.reloadUntil - GameTimer())
            Draw.Text(string_format("reload %.1fs", remaining), 14, sp.x - 25, sp.y + 50, RGBA(255, 255, 180, 180))
        end
    end

    if self.Menu.draw.marked:Value() and Draw and Draw.Text then
        local rEnemies = self.drawCache and self.drawCache.rEnemies or {}
        for i = 1, #rEnemies do
            local entry = rEnemies[i]
            if entry.marked then
                Draw.Text("MARKED", 14, entry.screenX - 22, entry.screenY - 30, RGBA(255, 255, 80, 80))
            end
        end
    end

    if self.Menu.draw.rDmg:Value() and Draw and Draw.Text then
        local rEnemies = self.drawCache and self.drawCache.rEnemies or {}
        for i = 1, #rEnemies do
            local entry = rEnemies[i]
            local col = entry.kill and RGBA(255, 255, 50, 50) or RGBA(200, 200, 200, 200)
            Draw.Text(string_format("R shot: %.0f", entry.damage), 14, entry.screenX - 25, entry.screenY - 45, col)
            if entry.kill then
                Draw.Text("KILLABLE", 14, entry.screenX - 28, entry.screenY - 60, RGBA(255, 255, 0, 0))
            end
        end
    end
end

Jhin:Create()
