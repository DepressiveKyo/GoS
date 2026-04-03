local VERSION = 3.0
local SCRIPT_NAME = "DepressiveAatrox"

if _G.__DEPRESSIVE_AATROX_LOADED then return end
if myHero.charName ~= "Aatrox" then return end
_G.__DEPRESSIVE_AATROX_LOADED = true

pcall(require, "GGPrediction")

local GGPredictionLib = _G.GGPrediction
local PRED_ENGINE_GG = 1

local function HasGGPrediction()
    return GGPredictionLib and type(GGPredictionLib.SpellPrediction) == "function"
end

if not HasGGPrediction() then
    print("[" .. SCRIPT_NAME .. "] No prediction library available.")
    return
end

local _Q, _W, _E, _R = 0, 1, 2, 3
local HK_Q, HK_W, HK_E, HK_R = HK_Q, HK_W, HK_E, HK_R

local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameTurretCount = Game.TurretCount
local GameTurret = Game.Turret
local GameTimer = Game.Timer
local GameLatency = Game.Latency

local math_abs = math.abs
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local os_clock = os.clock
local table_insert = table.insert
local table_remove = table.remove

local TEAM_JUNGLE = 300
local QE_RETRY_INTERVAL = 0.015
local QE_EXTRA_WINDOW = 0.24
local LOGIC_TICK_INTERVAL = 0.03
local HERO_CACHE_COMBAT = 0.08
local HERO_CACHE_IDLE = 0.16
local MINION_CACHE_COMBAT = 0.10
local MINION_CACHE_IDLE = 0.20
local TARGET_CACHE_DURATION = 0.05
local COUNT_CACHE_DURATION = 0.05
local PLAN_CACHE_DURATION = 0.05
local POSITION_CACHE_DURATION = 0.20
local W_PULL_DURATION = 1.5
local W_PULL_AREA_RADIUS = 185
local W_PULL_ESCAPE_BUFFER = 55
local W_PULL_BLEND_BUFFER = 0.42
local W_PULL_POST_WINDOW = 0.12
local W_BUFF_PATTERNS = {"aatroxw", "infernalchains"}

local ActiveMode = "None"
local PerfCache = {
    heroes = {tick = 0, all = {}, byRange = {}},
    minions = {tick = 0, lane = {}, jungle = {}, laneByRange = {}, jungleByRange = {}},
    target = {},
    enemyCount = {},
    qPlan = {},
    wall = {},
    turret = {},
}

local SPELL_DATA = {
    Q = {
        [1] = {
            range = 625,
            radius = 180,
            delay = 0.60,
            sweetMin = 505,
            sweetMax = 625,
            sweetMid = 565,
            eDelay = 0.05,
        },
        [2] = {
            range = 475,
            radius = 240,
            delay = 0.60,
            sweetMin = 355,
            sweetMax = 470,
            sweetMid = 415,
            eDelay = 0.05,
        },
        [3] = {
            range = 300,
            radius = 220,
            delay = 0.60,
            sweetMin = 0,
            sweetMax = 180,
            sweetMid = 125,
            eDelay = 0.03,
        },
    },
    W = {
        range = 825,
        radius = 80,
        speed = 1800,
        delay = 0.25,
    },
    E = {
        range = 300,
    },
    R = {
        range = 600,
    },
}

local Aatrox = {
    menu = nil,
    delayed = {},
    qPredictionsGG = {},
    wPredictionGG = nil,
    pendingEDash = nil,
    lastTick = 0,
    lastActionTime = 0,
    lastQTime = 0,
    lastWTime = 0,
    lastETime = 0,
    lastRTime = 0,
    lastSmartPlan = nil,
    lastWCast = nil,
}

local function GetZ(pos)
    return pos.z or pos.y or 0
end

local function Pos2(pos)
    if not pos then return nil end
    return {x = pos.x, z = GetZ(pos)}
end

local function Pos3(pos, y)
    if not pos then return nil end
    local py = y or pos.y or myHero.pos.y
    if _G.Vector then
        return Vector(pos.x, py, GetZ(pos))
    end
    return {x = pos.x, y = py, z = GetZ(pos)}
end

local function DistSqr(a, b)
    local pa = a.pos or a
    local pb = b.pos or b
    local dx = pa.x - pb.x
    local dz = GetZ(pa) - GetZ(pb)
    return dx * dx + dz * dz
end

local function Dist(a, b)
    return math_sqrt(DistSqr(a, b))
end

local function NormalizeVec(vec)
    local len = math_sqrt(vec.x * vec.x + vec.z * vec.z)
    if len < 0.001 then
        return {x = 0, z = 0}
    end
    return {x = vec.x / len, z = vec.z / len}
end

local function Direction(from, to)
    local p1 = from.pos or from
    local p2 = to.pos or to
    return NormalizeVec({
        x = p2.x - p1.x,
        z = GetZ(p2) - GetZ(p1),
    })
end

local function Perpendicular(vec)
    return {x = -vec.z, z = vec.x}
end

local function Dot(a, b)
    return a.x * b.x + a.z * b.z
end

local function Extend(from, to, distance)
    local p = from.pos or from
    local dir = Direction(from, to)
    return {
        x = p.x + dir.x * distance,
        y = p.y or myHero.pos.y,
        z = GetZ(p) + dir.z * distance,
    }
end

local function ClampDashTarget(from, to, maxRange)
    local distance = Dist(from, to)
    if distance <= maxRange then
        return Pos3(to, (from.pos or from).y or myHero.pos.y)
    end
    return Pos3(Extend(from, to, maxRange), (from.pos or from).y or myHero.pos.y)
end

local function Offset(pos, dir, distance)
    return {
        x = pos.x + dir.x * distance,
        y = pos.y or myHero.pos.y,
        z = GetZ(pos) + dir.z * distance,
    }
end

local function Clamp(value, minValue, maxValue)
    return math_max(minValue, math_min(maxValue, value))
end

local function LerpPos(from, to, t)
    return {
        x = from.x + (to.x - from.x) * t,
        y = (from.y or myHero.pos.y) + (((to.y or myHero.pos.y) - (from.y or myHero.pos.y)) * t),
        z = GetZ(from) + (GetZ(to) - GetZ(from)) * t,
    }
end

local function GetBuffRemainingTime(buff)
    if not buff then
        return 0
    end
    if buff.duration and buff.duration > 0 then
        return buff.duration
    end
    if buff.expireTime then
        return math_max(0, buff.expireTime - GameTimer())
    end
    return 0
end

local function IsCombatMode(mode)
    return mode == "Combo" or mode == "Harass" or mode == "Clear" or mode == "Jungle"
end

local function GetHeroCacheDuration()
    return IsCombatMode(ActiveMode) and HERO_CACHE_COMBAT or HERO_CACHE_IDLE
end

local function GetMinionCacheDuration()
    return IsCombatMode(ActiveMode) and MINION_CACHE_COMBAT or MINION_CACHE_IDLE
end

local function GetRangeKey(range)
    return tostring(math_floor((range or 0) + 0.5))
end

local function GetPositionKey(pos, grid)
    local p = pos.pos or pos
    local size = grid or 50
    return tostring(math_floor(p.x / size)) .. ":" .. tostring(math_floor(GetZ(p) / size))
end

local function IsValid(unit)
    return unit and unit.valid and unit.visible and not unit.dead and unit.health > 0 and unit.isTargetable
end

local function Ready(slot)
    local spellData = myHero:GetSpellData(slot)
    return spellData and spellData.level > 0 and spellData.currentCd == 0 and Game.CanUseSpell(slot) == 0
end

local function MyHeroNotReady()
    if myHero.dead then return true end
    if Game.IsChatOpen and Game.IsChatOpen() then return true end
    if _G.JustEvade and _G.JustEvade:Evading() then return true end
    if _G.ExtLibEvade and _G.ExtLibEvade.Evading then return true end
    return false
end

local function GetQPhase()
    local spellName = myHero:GetSpellData(_Q).name
    if spellName == "AatroxQ" then return 1 end
    if spellName == "AatroxQ2" then return 2 end
    if spellName == "AatroxQ3" then return 3 end
    return 0
end

local function GetQData(phase)
    local p = phase or GetQPhase()
    if p == 0 then
        p = 1
    end
    return SPELL_DATA.Q[p]
end

local function GetRequiredHitChance(value)
    return value or 1
end

function Aatrox:GetSelectedPredictionEngine()
    if HasGGPrediction() then
        return PRED_ENGINE_GG
    end
    return 0
end

function Aatrox:NormalizeGGHitChance(prediction)
    if not GGPredictionLib or not prediction or not prediction.CastPosition then
        return 0
    end
    if GGPredictionLib.HITCHANCE_IMMOBILE and prediction:CanHit(GGPredictionLib.HITCHANCE_IMMOBILE) then
        return 4
    end
    if GGPredictionLib.HITCHANCE_VERY_HIGH and prediction:CanHit(GGPredictionLib.HITCHANCE_VERY_HIGH) then
        return 3
    end
    if GGPredictionLib.HITCHANCE_HIGH and prediction:CanHit(GGPredictionLib.HITCHANCE_HIGH) then
        return 2
    end
    if GGPredictionLib.HITCHANCE_NORMAL and prediction:CanHit(GGPredictionLib.HITCHANCE_NORMAL) then
        return 1
    end
    return 0
end

function Aatrox:MeetsRequiredHitChance(hitChance, required, engine)
    if hitChance >= required then
        return true
    end
    if engine == PRED_ENGINE_GG and required == 3 and hitChance >= 2 then
        return true
    end
    return false
end

function Aatrox:Schedule(func, delay)
    table_insert(self.delayed, {
        func = func,
        time = os_clock() + delay,
    })
end

function Aatrox:ProcessDelayed()
    local now = os_clock()
    for i = #self.delayed, 1, -1 do
        if now >= self.delayed[i].time then
            pcall(self.delayed[i].func)
            table_remove(self.delayed, i)
        end
    end
end

function Aatrox:IsPointInWall(pos)
    if not pos or not _G.MapPosition or not MapPosition.inWall then
        return false
    end
    local key = GetPositionKey(pos, 35)
    local now = GameTimer()
    local cached = PerfCache.wall[key]
    if cached and now - cached.tick < POSITION_CACHE_DURATION then
        return cached.value
    end
    local value = MapPosition:inWall({x = pos.x, z = GetZ(pos)}) == true
    PerfCache.wall[key] = {tick = now, value = value}
    return value
end

function Aatrox:IsUnderEnemyTurret(pos)
    local key = GetPositionKey(pos, 60)
    local now = GameTimer()
    local cached = PerfCache.turret[key]
    if cached and now - cached.tick < POSITION_CACHE_DURATION then
        return cached.value
    end
    local value = false
    for i = 1, GameTurretCount() do
        local turret = GameTurret(i)
        if turret and turret.team ~= myHero.team and not turret.dead then
            if DistSqr(turret.pos, pos) <= (875 * 875) then
                value = true
                break
            end
        end
    end
    PerfCache.turret[key] = {tick = now, value = value}
    return value
end

function Aatrox:RefreshHeroCache()
    local now = GameTimer()
    if now - PerfCache.heroes.tick < GetHeroCacheDuration() then
        return
    end
    local all = {}
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero and hero.team ~= myHero.team and IsValid(hero) then
            all[#all + 1] = hero
        end
    end
    PerfCache.heroes = {
        tick = now,
        all = all,
        byRange = {}
    }
    PerfCache.target = {}
    PerfCache.enemyCount = {}
    PerfCache.qPlan = {}
end

function Aatrox:RefreshMinionCache()
    local now = GameTimer()
    if now - PerfCache.minions.tick < GetMinionCacheDuration() then
        return
    end
    local lane = {}
    local jungle = {}
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and not minion.dead and minion.health > 0 then
            if minion.team == TEAM_JUNGLE then
                jungle[#jungle + 1] = minion
            elseif minion.team ~= myHero.team then
                lane[#lane + 1] = minion
            end
        end
    end
    PerfCache.minions = {
        tick = now,
        lane = lane,
        jungle = jungle,
        laneByRange = {},
        jungleByRange = {}
    }
end

function Aatrox:GetEnemyHeroes(range)
    self:RefreshHeroCache()
    if not range then
        return PerfCache.heroes.all
    end
    local key = GetRangeKey(range)
    local cached = PerfCache.heroes.byRange[key]
    if cached then
        return cached
    end
    local result = {}
    local rangeSqr = range * range
    local heroes = PerfCache.heroes.all
    for i = 1, #heroes do
        local hero = heroes[i]
        if DistSqr(myHero.pos, hero.pos) <= rangeSqr then
            result[#result + 1] = hero
        end
    end
    PerfCache.heroes.byRange[key] = result
    return result
end

function Aatrox:GetTarget(range)
    local key = GetRangeKey(range)
    local now = GameTimer()
    local cached = PerfCache.target[key]
    if cached and now - cached.tick < TARGET_CACHE_DURATION and cached.target and IsValid(cached.target) and Dist(myHero.pos, cached.target.pos) <= range then
        return cached.target
    end
    local enemies = self:GetEnemyHeroes(range)
    if #enemies == 0 then
        return nil
    end
    if _G.SDK and _G.SDK.TargetSelector and _G.SDK.TargetSelector.GetTarget then
        local target = _G.SDK.TargetSelector:GetTarget(enemies)
        if target and IsValid(target) then
            PerfCache.target[key] = {tick = now, target = target}
            return target
        end
    end
    local bestTarget, bestScore = nil, -math_huge
    for i = 1, #enemies do
        local enemy = enemies[i]
        local score = (1800 - Dist(myHero.pos, enemy.pos)) + (1 - enemy.health / enemy.maxHealth) * 400
        if score > bestScore then
            bestScore = score
            bestTarget = enemy
        end
    end
    PerfCache.target[key] = {tick = now, target = bestTarget}
    return bestTarget
end

function Aatrox:GetOrbwalkerMode()
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then
        local modes = _G.SDK.Orbwalker.Modes
        if modes[_G.SDK.ORBWALKER_MODE_COMBO] then return "Combo" end
        if modes[_G.SDK.ORBWALKER_MODE_HARASS] then return "Harass" end
        if modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then return "Clear" end
        if modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then return "Jungle" end
        if modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then return "LastHit" end
    end
    if _G.GOS and _G.GOS.GetMode then
        local mode = _G.GOS:GetMode()
        if mode == 1 then return "Combo" end
        if mode == 2 then return "Harass" end
        if mode == 3 then return "Clear" end
    end
    return "None"
end

function Aatrox:GetEnemyCount(range, pos)
    local center = pos or myHero.pos
    local key = GetPositionKey(center, 60) .. ":" .. GetRangeKey(range)
    local now = GameTimer()
    local cached = PerfCache.enemyCount[key]
    if cached and now - cached.tick < COUNT_CACHE_DURATION then
        return cached.value
    end
    local rangeSqr = range * range
    local count = 0
    local heroes = self:GetEnemyHeroes()
    for i = 1, #heroes do
        local hero = heroes[i]
        if DistSqr(center, hero.pos) <= rangeSqr then
            count = count + 1
        end
    end
    PerfCache.enemyCount[key] = {tick = now, value = count}
    return count
end

function Aatrox:GetLaneMinions(range)
    self:RefreshMinionCache()
    if not range then
        return PerfCache.minions.lane
    end
    local key = GetRangeKey(range)
    local cached = PerfCache.minions.laneByRange[key]
    if cached then
        return cached
    end
    local result = {}
    local rangeSqr = range * range
    local lane = PerfCache.minions.lane
    for i = 1, #lane do
        local minion = lane[i]
        if DistSqr(myHero.pos, minion.pos) <= rangeSqr then
            result[#result + 1] = minion
        end
    end
    PerfCache.minions.laneByRange[key] = result
    return result
end

function Aatrox:GetJungleMinions(range)
    self:RefreshMinionCache()
    if not range then
        return PerfCache.minions.jungle
    end
    local key = GetRangeKey(range)
    local cached = PerfCache.minions.jungleByRange[key]
    if cached then
        return cached
    end
    local result = {}
    local rangeSqr = range * range
    local jungle = PerfCache.minions.jungle
    for i = 1, #jungle do
        local minion = jungle[i]
        if DistSqr(myHero.pos, minion.pos) <= rangeSqr then
            result[#result + 1] = minion
        end
    end
    PerfCache.minions.jungleByRange[key] = result
    return result
end

function Aatrox:GetBestMinionCluster(phase)
    local qData = GetQData(phase)
    local bestPos, bestCount = nil, 0
    local laneMinions = self:GetLaneMinions(qData.range + qData.radius)
    local radiusSqr = qData.radius * qData.radius
    local rangeSqr = qData.range * qData.range
    for i = 1, #laneMinions do
        local minion = laneMinions[i]
        if DistSqr(myHero.pos, minion.pos) <= rangeSqr then
            local count = 0
            for j = 1, #laneMinions do
                local other = laneMinions[j]
                if DistSqr(minion.pos, other.pos) <= radiusSqr then
                    count = count + 1
                end
            end
            if count > bestCount then
                bestCount = count
                bestPos = minion.pos
            end
        end
    end
    return bestPos, bestCount
end

function Aatrox:GetBestJungleMonster(range)
    local best, bestHealth = nil, -1
    local maxRange = range or 900
    local monsters = self:GetJungleMinions(maxRange)
    for i = 1, #monsters do
        local minion = monsters[i]
        if minion.maxHealth > bestHealth then
            best = minion
            bestHealth = minion.maxHealth
        end
    end
    return best
end

function Aatrox:IsCastingQ()
    local spell = myHero.activeSpell
    if not spell or not spell.valid or not spell.name then
        return false
    end
    return spell.name == "AatroxQ" or spell.name == "AatroxQ2" or spell.name == "AatroxQ3"
end

function Aatrox:IsRActive()
    for i = 0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.count > 0 and buff.name then
            local lower = string.lower(buff.name)
            if lower:find("aatroxr", 1, true) or lower:find("worldender", 1, true) then
                return true
            end
        end
    end
    return false
end

function Aatrox:CanCast()
    return GameTimer() - self.lastActionTime > 0.08
end

function Aatrox:BuildPredictions()
    self.qPredictionsGG = {}
    for phase = 1, 3 do
        local qData = SPELL_DATA.Q[phase]
        self.qPredictionsGG[phase] = GGPredictionLib:SpellPrediction({
            Type = GGPredictionLib.SPELLTYPE_CIRCLE or GGPredictionLib.SPELLTYPE_CIRCULAR,
            Speed = math_huge,
            Range = qData.range + SPELL_DATA.E.range,
            Delay = qData.delay + GameLatency() / 2000,
            Radius = qData.radius,
            Collision = false,
            UseBoundingRadius = true,
        })
    end
    self.wPredictionGG = GGPredictionLib:SpellPrediction({
        Type = GGPredictionLib.SPELLTYPE_LINE,
        Speed = SPELL_DATA.W.speed,
        Range = SPELL_DATA.W.range,
        Delay = SPELL_DATA.W.delay + GameLatency() / 2000,
        Radius = SPELL_DATA.W.radius,
        Collision = true,
        UseBoundingRadius = true,
    })
end

function Aatrox:GetTargetPrediction(target, phase)
    local prediction = self.qPredictionsGG[phase]
    if not prediction then
        return nil
    end
    prediction:GetPrediction(target, myHero)
    local unitPos = prediction.UnitPosition or prediction.CastPosition or target.pos
    if not unitPos then
        return nil
    end
    local result = {
        raw = prediction,
        unitPos = Pos3(unitPos, target.pos.y),
        hitChance = self:NormalizeGGHitChance(prediction),
        engine = PRED_ENGINE_GG,
    }
    if result and result.unitPos then
        self:ApplyWPullPrediction(target, phase, result)
    end
    return result
end

function Aatrox:GetWPrediction(target)
    local prediction = self.wPredictionGG
    if not prediction then
        return nil
    end
    prediction:GetPrediction(target, myHero)
    local castPos = prediction.CastPosition
    if not castPos then
        return nil
    end
    return {
        castPos = Pos3(castPos, target.pos.y),
        hitChance = self:NormalizeGGHitChance(prediction),
        engine = PRED_ENGINE_GG,
    }
end

function Aatrox:GetTargetMoveDirection(target)
    local endPos = target and (target.posTo or (target.pathing and target.pathing.endPos))
    if not target or not endPos then
        return nil
    end
    if target.pathing and target.pathing.hasMovePath == false then
        return nil
    end
    if DistSqr(target.pos, endPos) < 25 then
        return nil
    end
    return Direction(target.pos, endPos)
end

function Aatrox:FindMatchingBuff(unit, patterns)
    if not unit or not patterns then
        return nil
    end
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name then
            local lower = string.lower(buff.name)
            for j = 1, #patterns do
                if lower:find(patterns[j], 1, true) then
                    return buff
                end
            end
        end
    end
    return nil
end

function Aatrox:GetTrackedWCast(target)
    local tracked = self.lastWCast
    if not tracked or not target or tracked.targetId ~= (target.networkID or 0) then
        return nil
    end
    if GameTimer() > tracked.expireTime then
        return nil
    end
    return tracked
end

function Aatrox:GetWPullState(target)
    if not target then
        return nil
    end
    local tracked = self:GetTrackedWCast(target)
    local buff = self:FindMatchingBuff(target, W_BUFF_PATTERNS)
    if not tracked and not buff then
        return nil
    end

    local centerPos = tracked and tracked.centerPos or target.pos
    if not centerPos then
        return nil
    end

    local now = GameTimer()
    local remaining = tracked and (tracked.pullTime - now) or nil
    local buffRemaining = GetBuffRemainingTime(buff)
    if buffRemaining > 0 then
        remaining = remaining and math_min(remaining, buffRemaining) or buffRemaining
    end
    if remaining == nil then
        remaining = 0
    end
    if remaining < -W_PULL_POST_WINDOW then
        return nil
    end
    remaining = math_max(0, remaining)

    local distToCenter = Dist(target.pos, centerPos)
    local pullRadius = W_PULL_AREA_RADIUS + (target.boundingRadius or 35)
    local likelyPulled = false

    if distToCenter <= pullRadius - W_PULL_ESCAPE_BUFFER then
        likelyPulled = true
    elseif distToCenter <= pullRadius + 15 and remaining > 0 then
        local moveDir = self:GetTargetMoveDirection(target)
        local outwardDir = distToCenter > 5 and Direction(centerPos, target.pos) or nil
        local outwardSpeed = 0
        if moveDir and outwardDir then
            outwardSpeed = math_max(0, Dot(moveDir, outwardDir)) * (target.ms or 345)
        end
        local projectedEscape = outwardSpeed * remaining
        local escapeRequired = math_max(0, pullRadius - distToCenter) + W_PULL_ESCAPE_BUFFER
        likelyPulled = projectedEscape < escapeRequired
    elseif tracked and now <= tracked.pullTime + W_PULL_POST_WINDOW and distToCenter <= pullRadius then
        likelyPulled = true
    end

    if buff and distToCenter > pullRadius + 20 then
        likelyPulled = false
    end

    if not likelyPulled then
        return nil
    end

    return {
        centerPos = Pos3(centerPos, target.pos.y),
        remaining = remaining,
        distToCenter = distToCenter,
        pullRadius = pullRadius,
    }
end

function Aatrox:ApplyWPullPrediction(target, phase, predicted)
    if not predicted or not predicted.unitPos then
        return predicted
    end

    local pullState = self:GetWPullState(target)
    if not pullState then
        return predicted
    end

    local qData = GetQData(phase)
    local qDelay = (qData and qData.delay or 0.60) + GameLatency() / 2000
    local remaining = pullState.remaining or 0
    local forceCenter = remaining <= qDelay + 0.10
    local blendWindow = qDelay + W_PULL_BLEND_BUFFER

    if not forceCenter and remaining > blendWindow then
        return predicted
    end

    local adjustedPos
    local factor = 1
    if forceCenter then
        adjustedPos = pullState.centerPos
    else
        factor = Clamp((blendWindow - remaining) / math_max(0.10, W_PULL_BLEND_BUFFER), 0.20, 0.85)
        adjustedPos = Pos3(LerpPos(predicted.unitPos, pullState.centerPos, factor), target.pos.y)
    end

    predicted.unitPos = adjustedPos
    predicted.hitChance = math_max(predicted.hitChance or 0, forceCenter and 4 or 3)
    predicted.wPull = {
        remaining = remaining,
        factor = factor,
        forced = forceCenter,
        centerPos = pullState.centerPos,
    }
    return predicted
end

function Aatrox:IsSmartEEnabledForPhase(phase)
    if not self.menu.combo.useE:Value() or not self.menu.smartE.enable:Value() then
        return false
    end
    if not Ready(_E) then
        return false
    end
    if phase == 1 then return self.menu.smartE.q1:Value() end
    if phase == 2 then return self.menu.smartE.q2:Value() end
    if phase == 3 then return self.menu.smartE.q3:Value() end
    return false
end

function Aatrox:GetSweetGapForDistance(phase, distance)
    local qData = GetQData(phase)
    if not qData then
        return math_huge
    end
    if distance < qData.sweetMin then
        return qData.sweetMin - distance
    end
    if distance > qData.sweetMax then
        return distance - qData.sweetMax
    end
    return 0
end

function Aatrox:BuildECandidates(targetPos, phase)
    local candidates = {}
    local seen = {}
    local myPos = myHero.pos
    local qData = GetQData(phase)
    local toTarget = Direction(myPos, targetPos)
    local moveDir = self:GetTargetMoveDirection(self.currentTarget)
    local side = Perpendicular(moveDir or toTarget)
    local function addCandidate(pos)
        if not pos then return end
        if self:IsPointInWall(pos) then return end
        local dashDistance = Dist(myPos, pos)
        if dashDistance > SPELL_DATA.E.range + 1 then return end
        local key = tostring(math.floor(pos.x / 25)) .. ":" .. tostring(math.floor(GetZ(pos) / 25))
        if seen[key] then return end
        seen[key] = true
        candidates[#candidates + 1] = Pos3(pos, myHero.pos.y)
    end
    
    addCandidate(myPos)

    if qData then
        local towardHero = {x = -toTarget.x, z = -toTarget.z}
        local sweetAnchors = {
            qData.sweetMid,
            math_max(0, qData.sweetMin + 20),
            math_max(0, qData.sweetMax - 20),
        }
        for i = 1, #sweetAnchors do
            addCandidate(Offset(targetPos, towardHero, sweetAnchors[i]))
        end
        if phase ~= 3 then
            addCandidate(Offset(targetPos, toTarget, qData.sweetMid))
        end
    end
    
    local forwardSteps = {90, 165, 240, 300}
    local backwardSteps = {80, 150, 225, 300}
    local sideSteps = {100, 180, 260}
    
    for i = 1, #forwardSteps do
        addCandidate(Offset(myPos, toTarget, forwardSteps[i]))
    end
    
    if self.menu.smartE.backward:Value() and phase ~= 3 then
        local backward = {x = -toTarget.x, z = -toTarget.z}
        for i = 1, #backwardSteps do
            addCandidate(Offset(myPos, backward, backwardSteps[i]))
        end
    end
    
    if self.menu.smartE.side:Value() then
        for i = 1, #sideSteps do
            addCandidate(Offset(myPos, side, sideSteps[i]))
            addCandidate(Offset(myPos, {x = -side.x, z = -side.z}, sideSteps[i]))
        end
        addCandidate(Offset(Offset(myPos, toTarget, 190), side, 120))
        addCandidate(Offset(Offset(myPos, toTarget, 190), {x = -side.x, z = -side.z}, 120))
    end
    
    if moveDir then
        addCandidate(Offset(myPos, moveDir, 140))
        addCandidate(Offset(myPos, {x = -moveDir.x, z = -moveDir.z}, 140))
    end
    
    return candidates
end

function Aatrox:EvaluateQPlan(phase, targetPos, dashPos)
    local qData = GetQData(phase)
    local myPos = myHero.pos
    local dashVec = {
        x = dashPos.x - myPos.x,
        z = GetZ(dashPos) - GetZ(myPos),
    }
    local dashDistance = math_sqrt(dashVec.x * dashVec.x + dashVec.z * dashVec.z)
    local finalDistance = Dist(dashPos, targetPos)
    if finalDistance > qData.range + 20 then
        return nil
    end
    
    local sweet = finalDistance >= qData.sweetMin and finalDistance <= qData.sweetMax
    local sweetGap = self:GetSweetGapForDistance(phase, finalDistance)
    local distanceError = math_abs(finalDistance - qData.sweetMid)
    local score = sweet and (140 - distanceError * 0.16) or (90 - distanceError * 0.40)
    local targetDir = Direction(myPos, targetPos)
    local dashDir = dashDistance > 1 and NormalizeVec(dashVec) or targetDir
    
    if phase == 1 then
        if finalDistance > qData.sweetMax and Dot(dashDir, targetDir) > 0.3 then
            score = score + 15
        elseif finalDistance < qData.sweetMin and Dot(dashDir, targetDir) < -0.1 then
            score = score + 18
        end
    elseif phase == 2 then
        if finalDistance < qData.sweetMin and Dot(dashDir, targetDir) < -0.1 then
            score = score + 20
        elseif finalDistance > qData.sweetMax and Dot(dashDir, targetDir) > 0.2 then
            score = score + 12
        end
        local sideAmount = math_abs(Dot(dashDir, Perpendicular(targetDir)))
        score = score + sideAmount * 6
    else
        if finalDistance > qData.sweetMax and Dot(dashDir, targetDir) > 0.3 then
            score = score + 24
        elseif finalDistance <= qData.sweetMax then
            score = score + 14
        end
    end
    
    if dashDistance > 0 then
        score = score - dashDistance * 0.03
    end
    
    if not self.menu.smartE.dive:Value() and dashDistance > 0 and self:IsUnderEnemyTurret(dashPos) then
        score = score - 250
    end
    
    local castPos = {
        x = targetPos.x - dashVec.x,
        y = targetPos.y or myHero.pos.y,
        z = GetZ(targetPos) - dashVec.z,
    }
    local castDistance = Dist(myPos, castPos)
    if castDistance > qData.range + 10 then
        return nil
    end
    
    return {
        score = score,
        sweet = sweet,
        sweetGap = sweetGap,
        useE = dashDistance > 12,
        dashPos = Pos3(dashPos, myHero.pos.y),
        dashDistance = dashDistance,
        castPos = Pos3(castPos, myHero.pos.y),
        targetPos = Pos3(targetPos, targetPos.y or myHero.pos.y),
        finalDistance = finalDistance,
    }
end

function Aatrox:ShouldUseEForQ(currentPlan, ePlan, phase)
    if not ePlan or not ePlan.useE then
        return false
    end

    if not currentPlan then
        return true
    end

    if not self.menu.smartE.onlyWhenNeeded:Value() then
        return ePlan.score >= currentPlan.score + self.menu.smartE.minGain:Value()
    end

    if currentPlan.sweet then
        return false
    end

    if ePlan.sweet then
        return true
    end

    local minGain = self.menu.smartE.minGain:Value()
    local minGap = self.menu.smartE.minSweetGap:Value()
    local gapReduction = (currentPlan.sweetGap or math_huge) - (ePlan.sweetGap or math_huge)
    if gapReduction >= minGap and ePlan.score >= currentPlan.score + math_max(4, minGain * 0.5) then
        return true
    end

    local qData = GetQData(phase)
    if qData and currentPlan.finalDistance > qData.range - 25 and ePlan.finalDistance < currentPlan.finalDistance - 35
        and ePlan.score >= currentPlan.score + 4 then
        return true
    end

    return false
end

function Aatrox:GetBestQPlan(target, phase, requiredHitChance)
    local engine = self:GetSelectedPredictionEngine()
    local targetPosKey = GetPositionKey(target.pos, 35)
    local pathKey = target.posTo and GetPositionKey(target.posTo, 60) or "nop"
    local smartEKey = self:IsSmartEEnabledForPhase(phase) and "1" or "0"
    local trackedW = self:GetTrackedWCast(target)
    local wKey = "w0"
    if trackedW and trackedW.centerPos then
        local remainingBucket = math_floor((trackedW.pullTime - GameTimer()) * 10)
        wKey = "w" .. tostring(remainingBucket) .. ":" .. GetPositionKey(trackedW.centerPos, 50)
    elseif self:FindMatchingBuff(target, W_BUFF_PATTERNS) then
        wKey = "wb"
    end
    local key = tostring(target.networkID or 0) .. ":" .. tostring(phase) .. ":" .. tostring(requiredHitChance) .. ":" .. tostring(engine) .. ":" .. smartEKey .. ":" .. wKey .. ":" .. targetPosKey .. ":" .. pathKey
    local now = GameTimer()
    local cached = PerfCache.qPlan[key]
    if cached and now - cached.tick < PLAN_CACHE_DURATION then
        return cached.plan, cached.predicted
    end

    local predicted = self:GetTargetPrediction(target, phase)
    if not predicted or not predicted.unitPos then
        return nil
    end
    if not self:MeetsRequiredHitChance(predicted.hitChance, requiredHitChance, predicted.engine) then
        return nil
    end
    
    local targetPos = predicted.unitPos
    local currentPlan = self:EvaluateQPlan(phase, targetPos, myHero.pos)
    local bestPlan = currentPlan
    local bestEPlan = nil
    local sweetEPlan = nil
    
    if self:IsSmartEEnabledForPhase(phase) then
        local candidates = self:BuildECandidates(targetPos, phase)
        for i = 1, #candidates do
            local plan = self:EvaluateQPlan(phase, targetPos, candidates[i])
            if plan then
                if plan.useE then
                    if not bestEPlan or plan.score > bestEPlan.score then
                        bestEPlan = plan
                    end
                    if plan.sweet and (not sweetEPlan or plan.score > sweetEPlan.score) then
                        sweetEPlan = plan
                    end
                elseif not bestPlan or plan.score > bestPlan.score then
                    bestPlan = plan
                end
            end
        end
    end

    local selectedPlan = bestPlan
    local preferredEPlan = sweetEPlan or bestEPlan
    if self:ShouldUseEForQ(currentPlan, preferredEPlan, phase) then
        selectedPlan = preferredEPlan
    elseif not selectedPlan then
        selectedPlan = preferredEPlan
    end

    if not selectedPlan then
        return nil
    end
    
    PerfCache.qPlan[key] = {
        tick = now,
        plan = selectedPlan,
        predicted = predicted,
    }
    return selectedPlan, predicted
end

function Aatrox:QueueEDuringQ(plan, phase)
    if not plan or not plan.useE or not plan.dashPos then
        return
    end
    local now = GameTimer()
    local startDelay = math_max(0.01, SPELL_DATA.Q[phase].eDelay + GameLatency() / 2000 - 0.01)
    self.pendingEDash = {
        phase = phase,
        dashPos = Pos3(plan.dashPos, myHero.pos.y),
        nextTry = now + startDelay,
        expireTime = now + startDelay + QE_EXTRA_WINDOW + GameLatency() / 1000,
        qTime = self.lastQTime,
        retries = 0,
    }
end

function Aatrox:ProcessPendingEDash()
    local pending = self.pendingEDash
    if not pending then
        return
    end

    local now = GameTimer()
    if myHero.dead or now > pending.expireTime then
        self.pendingEDash = nil
        return
    end
    if not Ready(_E) then
        self.lastETime = now
        self.lastActionTime = now
        self.pendingEDash = nil
        return
    end
    if now < pending.nextTry then
        return
    end

    local qAge = now - (pending.qTime or self.lastQTime or now)
    if not self:IsCastingQ() and qAge > (SPELL_DATA.Q[pending.phase].eDelay + QE_EXTRA_WINDOW) then
        self.pendingEDash = nil
        return
    end

    local castPos = ClampDashTarget(myHero.pos, pending.dashPos, SPELL_DATA.E.range - 5)
    if Dist(myHero.pos, castPos) < 12 then
        self.pendingEDash = nil
        return
    end

    Control.CastSpell(HK_E, castPos)
    pending.nextTry = now + QE_RETRY_INTERVAL
    pending.retries = pending.retries + 1

    if not Ready(_E) then
        self.lastETime = now
        self.lastActionTime = now
        self.pendingEDash = nil
    elseif pending.retries >= 8 and now + QE_RETRY_INTERVAL >= pending.expireTime then
        self.pendingEDash = nil
    end
end

function Aatrox:CastQ(target, menuHitChance)
    if not Ready(_Q) or not self:CanCast() or not target or not IsValid(target) then
        return false
    end
    local phase = GetQPhase()
    if phase == 0 then
        return false
    end
    
    local requiredHitChance = GetRequiredHitChance(menuHitChance)
    local plan = self:GetBestQPlan(target, phase, requiredHitChance)
    if not plan then
        return false
    end
    
    self.lastSmartPlan = plan
    self.pendingEDash = nil
    Control.CastSpell(HK_Q, plan.castPos)
    self.lastQTime = GameTimer()
    self.lastActionTime = GameTimer()
    
    if plan.useE then
        self:QueueEDuringQ(plan, phase)
    end
    
    return true
end

function Aatrox:CastW(target)
    if not Ready(_W) or not self:CanCast() or not target or not IsValid(target) then
        return false
    end
    if not self.menu.combo.useW:Value() then
        return false
    end
    if self:IsCastingQ() then
        return false
    end
    
    local dist = Dist(myHero.pos, target.pos)
    if dist > SPELL_DATA.W.range or dist < 180 then
        return false
    end
    
    local pred = self:GetWPrediction(target)
    if not pred or not self:MeetsRequiredHitChance(pred.hitChance, GetRequiredHitChance(self.menu.pred.wHit:Value()), pred.engine) then
        return false
    end
    
    local castPos = Pos3(pred.castPos or target.pos, target.pos.y)
    Control.CastSpell(HK_W, castPos)
    local castTime = GameTimer()
    local travelTime = SPELL_DATA.W.delay + (Dist(myHero.pos, castPos) / SPELL_DATA.W.speed)
    self.lastWTime = castTime
    self.lastActionTime = castTime
    self.lastWCast = {
        targetId = target.networkID or 0,
        centerPos = castPos,
        castTime = castTime,
        impactTime = castTime + travelTime,
        pullTime = castTime + travelTime + W_PULL_DURATION,
        expireTime = castTime + travelTime + W_PULL_DURATION + W_PULL_POST_WINDOW + 0.20,
    }
    return true
end

function Aatrox:CastR(target)
    if not Ready(_R) or self:IsRActive() or not self:CanCast() then
        return false
    end
    if not self.menu.combo.useR:Value() then
        return false
    end
    
    local hpPercent = myHero.health / myHero.maxHealth * 100
    local closeEnemies = self:GetEnemyCount(SPELL_DATA.R.range, myHero.pos)
    if hpPercent <= self.menu.combo.rHp:Value() or closeEnemies >= self.menu.combo.rEnemies:Value() then
        if not target or Dist(myHero.pos, target.pos) <= 900 then
            Control.CastSpell(HK_R)
            self.lastRTime = GameTimer()
            self.lastActionTime = GameTimer()
            return true
        end
    end
    return false
end

function Aatrox:Combo()
    local target = self:GetTarget(950)
    self.currentTarget = target
    if not target then
        self.lastSmartPlan = nil
        return
    end
    
    self:CastR(target)
    
    local phase = GetQPhase()
    if self.menu.combo.useQ:Value() and phase > 0 then
        if self:CastQ(target, self.menu.pred.comboQ:Value()) then
            return
        end
    end
    
    self:CastW(target)
end

function Aatrox:Harass()
    if not self.menu.harass.useQ:Value() then
        return
    end
    local target = self:GetTarget(850)
    self.currentTarget = target
    if not target then
        self.lastSmartPlan = nil
        return
    end
    
    if GetQPhase() > 0 then
        self:CastQ(target, self.menu.pred.harassQ:Value())
    end
end

function Aatrox:LaneClear()
    if not self.menu.clear.useQ:Value() or not Ready(_Q) then
        return
    end
    local phase = GetQPhase()
    if phase == 0 then
        return
    end
    
    local bestPos, hitCount = self:GetBestMinionCluster(phase)
    if bestPos and hitCount >= self.menu.clear.minMinions:Value() and self:CanCast() then
        Control.CastSpell(HK_Q, bestPos)
        self.lastQTime = GameTimer()
        self.lastActionTime = GameTimer()
    end
end

function Aatrox:JungleClear()
    local monster = self:GetBestJungleMonster(900)
    if not monster then
        return
    end
    self.currentTarget = monster
    
    if self.menu.jungle.useQ:Value() and Ready(_Q) and GetQPhase() > 0 then
        local required = GetRequiredHitChance(1)
        local plan = self:GetBestQPlan(monster, GetQPhase(), required)
        if plan then
            if not plan.useE or self.menu.jungle.useE:Value() then
                Control.CastSpell(HK_Q, plan.castPos)
                self.lastQTime = GameTimer()
                self.lastActionTime = GameTimer()
                if plan.useE and self.menu.jungle.useE:Value() then
                    self:QueueEDuringQ(plan, GetQPhase())
                end
                return
            end
        end
    end
    
    if self.menu.jungle.useW:Value() and Ready(_W) and Dist(myHero.pos, monster.pos) <= SPELL_DATA.W.range and self:CanCast() then
        Control.CastSpell(HK_W, monster.pos)
        self.lastWTime = GameTimer()
        self.lastActionTime = GameTimer()
    end
end

function Aatrox:KillSteal()
    if not self.menu.ks.enable:Value() then
        return
    end
    local enemies = self:GetEnemyHeroes(900)
    local qReady = self.menu.ks.useQ:Value() and Ready(_Q)
    local qPhase = qReady and GetQPhase() or 0
    local qRequired = qPhase > 0 and GetRequiredHitChance(1) or nil
    local wReady = self.menu.ks.useW:Value() and Ready(_W)
    for i = 1, #enemies do
        local enemy = enemies[i]
        if qPhase > 0 then
            self.currentTarget = enemy
            local plan = self:GetBestQPlan(enemy, qPhase, qRequired)
            if plan and enemy.health <= (85 + myHero.totalDamage * 0.70) then
                Control.CastSpell(HK_Q, plan.castPos)
                self.lastQTime = GameTimer()
                self.lastActionTime = GameTimer()
                if plan.useE then
                    self:QueueEDuringQ(plan, qPhase)
                end
                return
            end
        end
        if wReady and Dist(myHero.pos, enemy.pos) <= SPELL_DATA.W.range then
            if enemy.health <= (55 + myHero.totalDamage * 0.40) then
                local pred = self:GetWPrediction(enemy)
                if pred and self:MeetsRequiredHitChance(pred.hitChance, GetRequiredHitChance(1), pred.engine) then
                    Control.CastSpell(HK_W, pred.castPos or enemy.pos)
                    self.lastWTime = GameTimer()
                    self.lastActionTime = GameTimer()
                    return
                end
            end
        end
    end
end

function Aatrox:BuildMenu()
    self.menu = MenuElement({type = MENU, id = "depressiveAatroxNext", name = "[DepressiveAIONext] Aatrox"})
    self.menu:MenuElement({name = " ", drop = {"Version " .. tostring(VERSION)}})
    
    self.menu:MenuElement({type = MENU, id = "combo", name = "[Combo]"})
    self.menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.menu.combo:MenuElement({id = "useW", name = "Use W", value = true})
    self.menu.combo:MenuElement({id = "useE", name = "Use E during Q", value = true})
    self.menu.combo:MenuElement({id = "useR", name = "Use R", value = true})
    self.menu.combo:MenuElement({id = "rHp", name = "R if HP% below", value = 45, min = 5, max = 100, step = 5})
    self.menu.combo:MenuElement({id = "rEnemies", name = "R if enemies >= ", value = 2, min = 1, max = 5, step = 1})
    
    self.menu:MenuElement({type = MENU, id = "smartE", name = "[Smart E]"})
    self.menu.smartE:MenuElement({id = "enable", name = "Enable Smart E", value = true})
    self.menu.smartE:MenuElement({id = "q1", name = "Smart E on Q1", value = true})
    self.menu.smartE:MenuElement({id = "q2", name = "Smart E on Q2", value = true})
    self.menu.smartE:MenuElement({id = "q3", name = "Smart E on Q3", value = true})
    self.menu.smartE:MenuElement({id = "backward", name = "Allow backstep E", value = true})
    self.menu.smartE:MenuElement({id = "side", name = "Allow sidestep E", value = true})
    self.menu.smartE:MenuElement({id = "dive", name = "Allow E under enemy turret", value = false})
    self.menu.smartE:MenuElement({id = "onlyWhenNeeded", name = "Only use E when needed", value = true})
    self.menu.smartE:MenuElement({id = "minGain", name = "Min score gain to spend E", value = 12, min = 0, max = 50, step = 1})
    self.menu.smartE:MenuElement({id = "minSweetGap", name = "Min sweet gap improvement", value = 35, min = 0, max = 120, step = 5})
    
    self.menu:MenuElement({type = MENU, id = "harass", name = "[Harass]"})
    self.menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
    
    self.menu:MenuElement({type = MENU, id = "clear", name = "[Lane Clear]"})
    self.menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.menu.clear:MenuElement({id = "minMinions", name = "Min minions for Q", value = 3, min = 1, max = 6, step = 1})
    
    self.menu:MenuElement({type = MENU, id = "jungle", name = "[Jungle Clear]"})
    self.menu.jungle:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.menu.jungle:MenuElement({id = "useW", name = "Use W", value = true})
    self.menu.jungle:MenuElement({id = "useE", name = "Use Smart E with Q", value = true})
    
    self.menu:MenuElement({type = MENU, id = "ks", name = "[Killsteal]"})
    self.menu.ks:MenuElement({id = "enable", name = "Enable", value = true})
    self.menu.ks:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.menu.ks:MenuElement({id = "useW", name = "Use W", value = true})
    
    self.menu:MenuElement({type = MENU, id = "pred", name = "[Prediction]"})
    self.menu.pred:MenuElement({id = "comboQ", name = "Combo Q hitchance", value = 2, drop = {"Normal", "High", "Very High", "Immobile"}})
    self.menu.pred:MenuElement({id = "harassQ", name = "Harass Q hitchance", value = 2, drop = {"Normal", "High", "Very High", "Immobile"}})
    self.menu.pred:MenuElement({id = "wHit", name = "W hitchance", value = 2, drop = {"Normal", "High", "Very High", "Immobile"}})
    
    self.menu:MenuElement({type = MENU, id = "draw", name = "[Draw]"})
    self.menu.draw:MenuElement({id = "enable", name = "Enable drawings", value = true})
    self.menu.draw:MenuElement({id = "qRange", name = "Draw Q range", value = true})
    self.menu.draw:MenuElement({id = "sweet", name = "Draw sweet spot", value = true})
    self.menu.draw:MenuElement({id = "eRange", name = "Draw E range", value = false})
    self.menu.draw:MenuElement({id = "smartE", name = "Draw Smart E plan", value = true})
end

function Aatrox:OnTick()
    if not self.menu or MyHeroNotReady() then
        return
    end
    
    self:ProcessDelayed()
    self:ProcessPendingEDash()
    if self.pendingEDash then
        return
    end

    local now = GameTimer()
    if now - self.lastTick < LOGIC_TICK_INTERVAL then
        return
    end
    self.lastTick = now
    
    local mode = self:GetOrbwalkerMode()
    ActiveMode = mode
    if mode == "Combo" then
        self:Combo()
    elseif mode == "Harass" then
        self:Harass()
    elseif mode == "Clear" then
        self:LaneClear()
        self:JungleClear()
    elseif mode == "Jungle" then
        self:JungleClear()
    end
    
    self:KillSteal()
end

function Aatrox:OnDraw()
    if not self.menu or myHero.dead or not self.menu.draw.enable:Value() then
        return
    end
    
    local phase = GetQPhase()
    local qData = GetQData(phase > 0 and phase or 1)
    
    if self.menu.draw.qRange:Value() and Ready(_Q) then
        Draw.Circle(myHero.pos, qData.range, 1, Draw.Color(90, 220, 180, 50))
    end
    
    if self.menu.draw.sweet:Value() and Ready(_Q) and phase > 0 then
        if qData.sweetMin > 0 then
            Draw.Circle(myHero.pos, qData.sweetMin, 1, Draw.Color(80, 255, 100, 100))
        end
        Draw.Circle(myHero.pos, qData.sweetMax, 1, Draw.Color(110, 255, 180, 80))
    end
    
    if self.menu.draw.eRange:Value() and Ready(_E) then
        Draw.Circle(myHero.pos, SPELL_DATA.E.range, 1, Draw.Color(90, 120, 200, 255))
    end
    
    if self.menu.draw.smartE:Value() and self.lastSmartPlan and self.lastSmartPlan.useE then
        Draw.Circle(self.lastSmartPlan.dashPos, 45, 1, Draw.Color(170, 255, 90, 40))
        Draw.Circle(self.lastSmartPlan.targetPos, 35, 1, Draw.Color(170, 255, 180, 0))
        if Draw.Line then
            Draw.Line(myHero.pos, self.lastSmartPlan.dashPos, 2, Draw.Color(170, 255, 90, 40))
        end
    end
end

function Aatrox:Init()
    self:BuildMenu()
    self:BuildPredictions()
    Callback.Add("Tick", function() self:OnTick() end)
    Callback.Add("Draw", function() self:OnDraw() end)
    print("[" .. SCRIPT_NAME .. "] loaded.")
end

Aatrox:Init()
