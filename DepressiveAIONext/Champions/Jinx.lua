local VERSION = "2.0"
local SCRIPT_NAME = "DepressiveJinx"

if _G.__DEPRESSIVE_NEXT_JINX_LOADED then return end
if myHero.charName ~= "Jinx" then return end
_G.__DEPRESSIVE_NEXT_JINX_LOADED = true
_G.DepressiveAIONextLoadedChampion = true

pcall(require, "GGPrediction")
pcall(require, "DepressivePrediction")

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
local PRED_ENGINE_DEPRESSIVE = 2

local BASE_AA_RANGE = 525
local Q_BONUS_RANGE = {100, 125, 150, 175, 200}
local W_RANGE = 1450
local W_SPEED = 3300
local W_DELAY_BASE = 0.6
local W_DELAY_MIN = 0.4
local W_RADIUS = 60
local E_RANGE = 925
local E_DELAY = 0.4
local E_RADIUS = 115
local E_SPEED = 1100
local E_ARM_TIME = 0.5
local E_ROOT_DURATION = 1.5
local W_BASE_DAMAGE = {10, 70, 130, 190, 250}
local W_AD_RATIO = 2.0
local E_BASE_DAMAGE = {70, 120, 170, 220, 270}
local R_BASE_MIN = {25, 40, 55}
local R_BASE_MAX = {250, 400, 550}
local R_AD_MIN = 0.15
local R_AD_MAX = 1.50
local R_MISSING_HP = {0.25, 0.30, 0.35}
local ROCKET_MANA_COST = 20
local FISHBONES_SPLASH_RADIUS = 250
local MODE_CACHE_DURATION = 0.05
local HERO_CACHE_COMBAT = 0.08
local HERO_CACHE_IDLE = 0.16
local MINION_CACHE_COMBAT = 0.10
local MINION_CACHE_IDLE = 0.20
local COUNT_CACHE_DURATION = 0.05
local TARGET_CACHE_DURATION = 0.05
local COLLISION_CACHE_DURATION = 0.06
local IMMOBILE_CACHE_DURATION = 0.05
local DRAW_CACHE_DURATION = 0.12

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
    immobile = {}
}

local function Vec(x, y, z)
    if Vector then
        return Vector(x, y, z)
    end

    return {x = x, y = y, z = z}
end

local function Dist(a, b)
    local p1, p2 = a.pos or a, b.pos or b
    if not p1 or not p2 then return math_huge end
    local dx, dz = p1.x - p2.x, (p1.z or p1.y) - (p2.z or p2.y)
    return math_sqrt(dx*dx + dz*dz)
end

local function DistSqr(a, b)
    local p1, p2 = a.pos or a, b.pos or b
    if not p1 or not p2 then return math_huge end
    local dx, dz = p1.x - p2.x, (p1.z or p1.y) - (p2.z or p2.y)
    return dx*dx + dz*dz
end

local function Extend(from, to, distance)
    local p1, p2 = from.pos or from, to.pos or to
    local dx, dz = p2.x - p1.x, (p2.z or p2.y) - (p1.z or p1.y)
    local len = math_sqrt(dx*dx + dz*dz)
    if len < 0.001 then return Vec(p1.x, myHero.pos.y, p1.z or p1.y) end
    return Vec(p1.x + dx/len*distance, myHero.pos.y, (p1.z or p1.y) + dz/len*distance)
end

local function PointOnLineSegment(p, a, b, radius)
    local px, pz = (p.pos or p).x, ((p.pos or p).z or (p.pos or p).y)
    local ax, az = (a.pos or a).x, ((a.pos or a).z or (a.pos or a).y)
    local bx, bz = (b.pos or b).x, ((b.pos or b).z or (b.pos or b).y)
    local dx, dz = bx - ax, bz - az
    local lenSq = dx*dx + dz*dz
    if lenSq < 0.001 then return false end
    local t = math_max(0, math_min(1, ((px-ax)*dx + (pz-az)*dz) / lenSq))
    local cx, cz = ax + t*dx, az + t*dz
    local ddx, ddz = px - cx, pz - cz
    return (ddx*ddx + ddz*ddz) <= radius * radius
end

local function RGBA(a, r, g, b)
    if Draw and Draw.Color then
        return Draw.Color(a, r, g, b)
    end

    return 0
end

local function DrawCircle3D(p, r, w, c)
    if Draw and Draw.Circle then
        Draw.Circle(p, r, w, c)
    end
end

local function IsValid(u)
    return u and u.valid and u.visible and not u.dead and u.isTargetable
end

local function IsValidTarget(u, range)
    if not IsValid(u) or u.team ~= TEAM_ENEMY then return false end
    return not range or Dist(myHero, u) <= range
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
    return tostring(math_floor((range or 0) + 0.5))
end

local function GetPositionKey(pos, range)
    local p = pos.pos or pos
    return math_floor(p.x / 50) .. ":" .. math_floor((p.z or p.y) / 50) .. ":" .. GetRangeKey(range)
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

local function IsOrbwalkerAttacking()
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.IsAutoAttacking then
        local ok, r = pcall(function() return _G.SDK.Orbwalker:IsAutoAttacking() end)
        if ok then return r end
    end
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
        elseif S.ORBWALKER_MODE_SPACING and M[S.ORBWALKER_MODE_SPACING] then
            mode = "Combo"
        elseif S.ORBWALKER_MODE_HARASS and M[S.ORBWALKER_MODE_HARASS] then
            mode = "Harass"
        elseif (S.ORBWALKER_MODE_LANECLEAR and M[S.ORBWALKER_MODE_LANECLEAR]) or (S.ORBWALKER_MODE_JUNGLECLEAR and M[S.ORBWALKER_MODE_JUNGLECLEAR]) then
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
    if not range then
        return PerfCache.heroes.all
    end

    local key = GetRangeKey(range)
    local cached = PerfCache.heroes.byRange[key]
    local now = GameTimer()
    if cached and now - cached.tick < COUNT_CACHE_DURATION then
        return cached.data
    end

    local out = {}
    for i = 1, #PerfCache.heroes.all do
        local h = PerfCache.heroes.all[i]
        if Dist(myHero, h) <= range then
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
        if DistSqr(unit, h) < rsq then
            count = count + 1
        end
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
        if DistSqr(pos, m) <= rsq then
            count = count + 1
        end
    end

    PerfCache.minionCount[key] = {tick = now, value = count}
    return count
end

local CC_TYPES = {
    [5] = true,
    [8] = true,
    [9] = true,
    [11] = true,
    [22] = true,
    [24] = true,
    [28] = true,
    [29] = true,
    [30] = true
}

local function GetBuff(unit, buffName)
    if not unit or not unit.buffCount then
        return nil
    end

    for i = 0, unit.buffCount do
        local b = unit:GetBuff(i)
        if b and b.count > 0 and b.name == buffName then
            return b
        end
    end

    return nil
end

local function IsImmobile(unit)
    if not unit or not unit.buffCount then
        return false, 0
    end

    local key = unit.networkID or 0
    local now = GameTimer()
    local cached = PerfCache.immobile[key]
    if cached and cached.buffCount == unit.buffCount and now - cached.tick < IMMOBILE_CACHE_DURATION then
        return cached.value, cached.duration
    end

    if not unit or not unit.buffCount then
        return false, 0
    end

    local best = 0
    for i = 0, unit.buffCount do
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
    if not unit or not unit.pathing or not unit.pathing.isDashing then
        return false
    end

    local ep = unit.pathing.endPos
    return ep and Dist(myHero.pos, ep) < Dist(myHero.pos, unit.pos)
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

local function GetWDamage(target)
    local l = myHero:GetSpellData(_W).level
    if not l or l == 0 then return 0 end
    return CalcPhysDmg(target, W_BASE_DAMAGE[l] + W_AD_RATIO * (myHero.totalDamage or 0))
end

local function GetRSpeed(target)
    local d = Dist(myHero, target)
    return d > 1350 and (1350 * 1700 + (d - 1350) * 2200) / d or 1700
end

local function GetRDamage(target)
    local lvl = myHero:GetSpellData(_R).level
    if not lvl or lvl == 0 then return 0 end
    local d = Dist(myHero, target)
    local ratio = math_min(1.0, math_max(0.1, d / 1500))
    local baseDmg = R_BASE_MIN[lvl] + (R_BASE_MAX[lvl] - R_BASE_MIN[lvl]) * ratio
    local adDmg = (R_AD_MIN + (R_AD_MAX - R_AD_MIN) * ratio) * (myHero.bonusDamage or 0)
    local missingHP = R_MISSING_HP[lvl] * (target.maxHealth - target.health)
    return CalcPhysDmg(target, baseDmg + adDmg + missingHP)
end

local function GetAADamage(target)
    local ad = myHero.totalDamage or 0
    return CalcPhysDmg(target, ad)
end
local function GetWDelay()
    local totalAS = myHero.attackSpeed or 1.0
    local baseAS = 0.625
    local bonusAS = math_max(0, totalAS - baseAS) / baseAS
    local ratio = math_min(1.0, bonusAS / 2.5)
    return W_DELAY_BASE - ratio * (W_DELAY_BASE - W_DELAY_MIN)
end

local function IsLineBlocked(source, target, width)
    RefreshCollisionMinionCache()
    local srcPos = source.pos or source
    local tgtPos = target.pos or target
    local key = GetPositionKey(srcPos, width) .. ":" .. GetPositionKey(tgtPos, width)
    local cached = PerfCache.lineCollision[key]
    local now = GameTimer()
    if cached and now - cached.tick < COLLISION_CACHE_DURATION then
        return cached.value
    end
    local blocked = false
    for i = 1, #PerfCache.collisionMinions.all do
        local m = PerfCache.collisionMinions.all[i]
        if PointOnLineSegment(m, srcPos, tgtPos, width + (m.boundingRadius or 30)) then
            blocked = true
            break
        end
    end
    PerfCache.lineCollision[key] = {tick = now, value = blocked}
    return blocked
end

local function IsRBlockedByChampion(source, target, width)
    RefreshEnemyHeroCache()
    local srcPos = source.pos or source
    local tgtPos = target.pos or target
    local targetId = target.networkID or 0
    local key = GetPositionKey(srcPos, width) .. ":" .. GetPositionKey(tgtPos, width) .. ":" .. tostring(targetId)
    local cached = PerfCache.championCollision[key]
    local now = GameTimer()
    if cached and now - cached.tick < COLLISION_CACHE_DURATION then
        return cached.value
    end
    local blocked = false
    for i = 1, #PerfCache.heroes.all do
        local h = PerfCache.heroes.all[i]
        if h.networkID ~= targetId and PointOnLineSegment(h, srcPos, tgtPos, width + (h.boundingRadius or 50)) then
            blocked = true
            break
        end
    end
    PerfCache.championCollision[key] = {tick = now, value = blocked}
    return blocked
end

local ADC_LIST = {
    ["Vayne"]=true,["Jinx"]=true,["Caitlyn"]=true,["Tristana"]=true,["Ashe"]=true,["Draven"]=true,
    ["Lucian"]=true,["KogMaw"]=true,["Twitch"]=true,["Kalista"]=true,["Sivir"]=true,["MissFortune"]=true,
    ["Jhin"]=true,["Xayah"]=true,["Aphelios"]=true,["Samira"]=true,["Zeri"]=true,["Smolder"]=true,
    ["Kindred"]=true,["Graves"]=true,["Ezreal"]=true,["Varus"]=true,["Kaisa"]=true,["Nilah"]=true,
}

local function GetTarget(range, isFishBones)
    local key = GetRangeKey(range) .. ":" .. tostring(isFishBones and 1 or 0)
    local now = GameTimer()
    local cached = PerfCache.target[key]
    if cached and now - cached.tick < TARGET_CACHE_DURATION and IsValidTarget(cached.target, range) then
        return cached.target
    end
    local best, bestScore = nil, -math_huge
    local heroes = GetEnemyHeroes(range)
    for i = 1, #heroes do
        local h = heroes[i]
        if IsValidTarget(h, range) then
            local score = 0
            local hpPct = h.health / math_max(1, h.maxHealth)
            local d = Dist(myHero, h)

            if hpPct <= 0.25 then score = score + 200
            elseif hpPct <= 0.40 then score = score + 120
            elseif hpPct <= 0.60 then score = score + 50
            end

            if ADC_LIST[h.charName] then
                score = score + 60
                if hpPct <= 0.30 then score = score + 80 end
            end

            if isFishBones then
                local nearby = GetEnemyCount(FISHBONES_SPLASH_RADIUS, h)
                if nearby >= 2 then score = score + nearby * 40 end
            end

            score = score + (range - d) / range * 25

            score = score + (1 - hpPct) * 40

            if score > bestScore then bestScore = score; best = h end
        end
    end
    PerfCache.target[key] = {tick = now, target = best}
    return best
end

local Jinx = {}; Jinx.__index = Jinx

function Jinx:Create()
    local self = setmetatable({}, Jinx)

    self.lastTick = 0
    self.lastWCast, self.lastECast, self.lastRCast, self.lastQSwap = 0, 0, 0, 0

    self.isFishBones = false
    self.powPowStacks = 0
    self.minigunRange = BASE_AA_RANGE
    self.rocketRange = BASE_AA_RANGE
    self.rocketPokeMode = false

    self.isExcited = false
    self.excitedExpire = 0
    self.excitedStacks = 0

    self.wHitTime = 0
    self.wHitTarget = nil
    self.drawCache = {tick = 0, range = 0, rEnemies = {}}
    self:LoadMenu()
    self:LoadCallbacks()
    print("[" .. SCRIPT_NAME .. "] Loaded v" .. VERSION)
    return self
end

function Jinx:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveJinx", name = SCRIPT_NAME})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. VERSION}})
    self.Menu:MenuElement({type = MENU, id = "pred", name = "Prediction"})
    self.Menu.pred:MenuElement({id = "engine", name = "Prediction Engine", drop = {"GGPrediction", "DepressivePrediction"}, value = PRED_ENGINE_GG})
    self.Menu.pred:MenuElement({id = "wHitChance", name = "W Hit Chance", value = 3, min = 1, max = 6, step = 1})
    self.Menu.pred:MenuElement({id = "rHitChance", name = "R Hit Chance", value = 2, min = 1, max = 6, step = 1})

    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Smart Q toggle", value = true})
    self.Menu.combo:MenuElement({id = "useW", name = "Use W out of AA range", value = true})
    self.Menu.combo:MenuElement({id = "useE", name = "Use E on CC'd target", value = true})
    self.Menu.combo:MenuElement({id = "useR", name = "Use R execute", value = true})
    self.Menu.combo:MenuElement({id = "comboMana", name = "Min mana %", value = 10, min = 0, max = 100, step = 5, identifier = "%"})
    self.Menu.combo:MenuElement({id = "aoeCount", name = "Min enemies for rocket AoE", value = 2, min = 2, max = 5})

    self.Menu:MenuElement({type = MENU, id = "qTune", name = "Q Toggle Tuning"})
    self.Menu.qTune:MenuElement({id = "rocketPoke", name = "1-rocket-poke pattern (swap back after 1 auto)", value = true})
    self.Menu.qTune:MenuElement({id = "preserveStacks", name = "Preserve 3 Pow-Pow stacks (delay swap)", value = true})
    self.Menu.qTune:MenuElement({id = "stackGrace", name = "Grace period before swap at 3 stacks (ms)", value = 500, min = 200, max = 1500, step = 50})
    self.Menu.qTune:MenuElement({id = "turretMinigun", name = "Force minigun on turrets", value = true})
    self.Menu.qTune:MenuElement({id = "rocketMana", name = "Min mana % for rockets", value = 25, min = 0, max = 80, step = 5, identifier = "%"})
    self.Menu.qTune:MenuElement({id = "excitedRockets", name = "Use rockets during Get Excited (cleanup)", value = true})

    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useW", name = "W poke", value = true})
    self.Menu.harass:MenuElement({id = "useQ", name = "Rocket poke (1 auto)", value = true})
    self.Menu.harass:MenuElement({id = "harassMana", name = "Min mana %", value = 40, min = 0, max = 100, step = 5, identifier = "%"})

    self.Menu:MenuElement({type = MENU, id = "clear", name = "Clear"})
    self.Menu.clear:MenuElement({id = "rocketAOE", name = "Rockets for AoE clear", value = true})
    self.Menu.clear:MenuElement({id = "minMinions", name = "Min minions for rockets", value = 3, min = 2, max = 6})
    self.Menu.clear:MenuElement({id = "clearMana", name = "Min mana % for rockets", value = 50, min = 0, max = 100, step = 5, identifier = "%"})

    self.Menu:MenuElement({type = MENU, id = "autoE", name = "Auto E"})
    self.Menu.autoE:MenuElement({id = "onCC", name = "E on CC'd enemies", value = true})
    self.Menu.autoE:MenuElement({id = "ccDuration", name = "Min CC remaining (accounts for arm time)", value = 1.2, min = 0.5, max = 3.0, step = 0.1})
    self.Menu.autoE:MenuElement({id = "antiDash", name = "E anti-dash", value = true})
    self.Menu.autoE:MenuElement({id = "selfPeel", name = "E self-peel vs melee", value = true})
    self.Menu.autoE:MenuElement({id = "peelRange", name = "Self-peel trigger range", value = 350, min = 200, max = 500, step = 25})
    self.Menu.autoE:MenuElement({id = "chainWE", name = "W to E combo (E after W slows)", value = true})

    self.Menu:MenuElement({type = MENU, id = "ult", name = "R Execute"})
    self.Menu.ult:MenuElement({id = "autoR", name = "Auto R killable (global scan)", value = true})
    self.Menu.ult:MenuElement({id = "semiKey", name = "Semi-manual R key", key = string.byte("T")})
    self.Menu.ult:MenuElement({id = "minRange", name = "Min R distance", value = 700, min = 0, max = 2000, step = 50})
    self.Menu.ult:MenuElement({id = "maxRange", name = "Max R distance (auto)", value = 3000, min = 1000, max = 12500, step = 250})
    self.Menu.ult:MenuElement({id = "semiRange", name = "Max R distance (semi key)", value = 5000, min = 1000, max = 12500, step = 250})
    self.Menu.ult:MenuElement({id = "overkill", name = "Don't R if killable with 3 autos", value = true})
    self.Menu.ult:MenuElement({id = "collision", name = "Check R collision (skip if blocked)", value = true})
    self.Menu.ult:MenuElement({id = "multiR", name = "R into enemy cluster", value = true})
    self.Menu.ult:MenuElement({id = "multiCount", name = "Min enemies for cluster R", value = 3, min = 2, max = 5})

    self.Menu:MenuElement({type = MENU, id = "ks", name = "Killsteal"})
    self.Menu.ks:MenuElement({id = "useW", name = "W killsteal", value = true})
    self.Menu.ks:MenuElement({id = "useR", name = "R killsteal", value = true})

    self.Menu:MenuElement({type = MENU, id = "flee", name = "Flee"})
    self.Menu.flee:MenuElement({id = "useE", name = "E at feet", value = true})
    self.Menu.flee:MenuElement({id = "useW", name = "W closest chaser", value = true})

    self.Menu:MenuElement({type = MENU, id = "draw", name = "Drawings"})
    self.Menu.draw:MenuElement({id = "enable", name = "Enable drawings", value = true})
    self.Menu.draw:MenuElement({id = "aaRange", name = "AA range (weapon color)", value = true})
    self.Menu.draw:MenuElement({id = "wRange", name = "W range", value = false})
    self.Menu.draw:MenuElement({id = "rDmg", name = "R damage + killable indicator", value = true})
    self.Menu.draw:MenuElement({id = "weapon", name = "Current weapon and stacks", value = true})
    self.Menu.draw:MenuElement({id = "excited", name = "Get Excited! indicator", value = true})
end

function Jinx:LoadCallbacks()
    Callback.Add("Tick", function() self:OnTick() end)
    Callback.Add("Draw", function() self:OnDraw() end)
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.OnPostAttack then
        _G.SDK.Orbwalker:OnPostAttack(function() self:OnPostAttack() end)
    end
end

function Jinx:GetSelectedPredictionEngine()
    local selected = self.Menu and self.Menu.pred and self.Menu.pred.engine and self.Menu.pred.engine:Value() or PRED_ENGINE_GG
    if selected == PRED_ENGINE_DEPRESSIVE then
        if _G.DepressivePrediction and type(_G.DepressivePrediction.GetPrediction) == "function" then return PRED_ENGINE_DEPRESSIVE end
        if _G.GGPrediction and type(_G.GGPrediction.SpellPrediction) == "function" then return PRED_ENGINE_GG end
    else
        if _G.GGPrediction and type(_G.GGPrediction.SpellPrediction) == "function" then return PRED_ENGINE_GG end
        if _G.DepressivePrediction and type(_G.DepressivePrediction.GetPrediction) == "function" then return PRED_ENGINE_DEPRESSIVE end
    end
    return 0
end

function Jinx:NormalizeGGHitChance(prediction)
    if not _G.GGPrediction or not prediction or not prediction.CastPosition then return 0 end
    if prediction:CanHit(_G.GGPrediction.HITCHANCE_IMMOBILE) then return 6 end
    if prediction:CanHit(_G.GGPrediction.HITCHANCE_HIGH) then return 4 end
    if prediction:CanHit(_G.GGPrediction.HITCHANCE_NORMAL) then return 3 end
    return 2
end

function Jinx:GetPredictionRequiredHitChance(spellKey)
    if spellKey == "R" then return self.Menu.pred.rHitChance:Value() end
    return self.Menu.pred.wHitChance:Value()
end

function Jinx:GetSpellPredictionData(target, spellKey)
    if spellKey == "R" then
        return self.Menu.ult.maxRange:Value(), 0.6, GetRSpeed(target), 140, false
    end
    return W_RANGE, GetWDelay(), W_SPEED, W_RADIUS, true
end

function Jinx:GetFallbackPrediction(target, delay)
    return self:PredictPosition(target, delay)
end

function Jinx:GetPredictedCastPosition(target, spellKey)
    if not target or not IsValid(target) then return nil, 0 end

    local range, delay, speed, radius, collision = self:GetSpellPredictionData(target, spellKey)
    local required = self:GetPredictionRequiredHitChance(spellKey)
    local engine = self:GetSelectedPredictionEngine()

    local function fromGG()
        if not (_G.GGPrediction and type(_G.GGPrediction.SpellPrediction) == "function") then return nil, 0 end
        local prediction = _G.GGPrediction:SpellPrediction({
            Type = _G.GGPrediction.SPELLTYPE_LINE,
            Delay = delay,
            Radius = radius,
            Range = range,
            Speed = speed,
            Collision = collision
        })
        prediction:GetPrediction(target, myHero)
        local castPos = prediction.CastPosition
        if castPos and castPos.x and castPos.z then
            return Vec(castPos.x, castPos.y or myHero.pos.y, castPos.z), self:NormalizeGGHitChance(prediction)
        end
        return nil, 0
    end

    local function fromDepressive()
        if not (_G.DepressivePrediction and type(_G.DepressivePrediction.GetPrediction) == "function") then return nil, 0 end
        local pred = _G.DepressivePrediction.GetPrediction(target, {
            type = "linear",
            speed = speed,
            range = range,
            delay = delay,
            radius = radius,
            collision = collision,
            collisionTypes = collision and {_G.DepressivePrediction.COLLISION_MINION} or {}
        })
        if pred then
            local castPos = pred.castPos or pred.CastPosition
            if castPos then
                return Vec(castPos.x, castPos.y or myHero.pos.y, castPos.z), pred.hitChance or pred.HitChance or 0
            end
        end
        return nil, 0
    end

    local castPos, hitChance
    if engine == PRED_ENGINE_DEPRESSIVE then
        castPos, hitChance = fromDepressive()
        if not castPos then castPos, hitChance = fromGG() end
    else
        castPos, hitChance = fromGG()
        if not castPos then castPos, hitChance = fromDepressive() end
    end

    if not castPos then
        castPos = self:GetFallbackPrediction(target, delay + (speed < math_huge and Dist(myHero, target) / speed or 0))
        hitChance = 3
    end

    if not castPos or Dist(myHero.pos, castPos) > range + 20 or hitChance < required then
        return nil, hitChance
    end

    return castPos, hitChance
end

function Jinx:UpdateQ()
    local br = myHero.boundingRadius or 0
    local range = myHero.range or BASE_AA_RANGE
    local qLvl = myHero:GetSpellData(_Q).level or 0

    local fishBuff = GetBuff(myHero, "JinxQ")
    local powBuff = GetBuff(myHero, "jinxqicon")

    if fishBuff then
        self.isFishBones = true
        self.rocketRange = range + br
        self.minigunRange = BASE_AA_RANGE + br
    elseif powBuff then
        self.isFishBones = false
        self.minigunRange = range + br
        if qLvl > 0 then
            self.rocketRange = self.minigunRange + Q_BONUS_RANGE[qLvl]
        end
    else
        self.minigunRange = BASE_AA_RANGE + br
        if qLvl > 0 then
            self.rocketRange = self.minigunRange + Q_BONUS_RANGE[qLvl]
        end
        self.isFishBones = range > BASE_AA_RANGE + 50
    end

    local rampBuff = GetBuff(myHero, "jinxqramp")
    self.powPowStacks = rampBuff and rampBuff.count or 0
end

function Jinx:SwapQ()
    if not Ready(_Q) or GameTimer() - self.lastQSwap < 0.30 then return false end
    Control.CastSpell(HK_Q)
    self.lastQSwap = GameTimer()
    return true
end

function Jinx:GetCurrentRange()
    return self.isFishBones and self.rocketRange or self.minigunRange
end


    local now = GameTimer()
    if not myHero.buffCount then return end
    self.isExcited = false
    self.excitedStacks = 0
    for i = 0, myHero.buffCount do
        local b = myHero:GetBuff(i)
        if b and b.count > 0 and b.expireTime and b.expireTime > now and b.name then
            local nm = string_lower(b.name)
            if string_find(nm, "jinxpassive", 1, true)
                or string_find(nm, "getexcited", 1, true)
                or string_find(nm, "jinxpassivekill", 1, true) then
                self.isExcited = true
                self.excitedExpire = b.expireTime
                self.excitedStacks = b.count
                return
            end
        end
    end
end

function Jinx:SmartToggle(target, mode)
    if not Ready(_Q) or not target then return end
    if GameTimer() - self.lastQSwap < 0.30 then return end

    local dist = Dist(myHero, target)
    local tbr = target.boundingRadius or 0
    local inMinigun = dist <= self.minigunRange + tbr
    local inRocket = dist <= self.rocketRange + tbr
    local enemies = GetEnemyCount(FISHBONES_SPLASH_RADIUS, target)
    local aoeThreshold = self.Menu.combo.aoeCount:Value()
    local lowMana = ManaPercent() < self.Menu.qTune.rocketMana:Value()

    if self.rocketPokeMode and self.isFishBones and inMinigun and enemies < aoeThreshold then
        self.rocketPokeMode = false
        self:SwapQ()
        return
    end

    if self.Menu.qTune.turretMinigun:Value() then
        local orbTarget = nil
        if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.GetTarget then
            local ok, t = pcall(function() return _G.SDK.Orbwalker:GetTarget() end)
            if ok and t then orbTarget = t end
        end
        if orbTarget and orbTarget.type and orbTarget.type == 3 then
            if self.isFishBones then self:SwapQ() end
            return
        end
    end

    if lowMana then
        if self.isFishBones then self:SwapQ() end
        return
    end

    if self.isExcited and self.Menu.qTune.excitedRockets:Value() then
        if not self.isFishBones and enemies >= 2 and inRocket then
            self:SwapQ()
            return
        end
        if self.isFishBones then
            if inMinigun and enemies < aoeThreshold then
                self:SwapQ()
                return
            end
            if inRocket and enemies >= aoeThreshold then return end
        end
    end

    if self.isFishBones then

        if inMinigun and enemies < aoeThreshold then

            self:SwapQ()
        end
    else

        if not inMinigun and inRocket then
            if self.Menu.qTune.rocketPoke:Value() then
                self.rocketPokeMode = true
            end
            self:SwapQ()
        elseif inMinigun and enemies >= aoeThreshold and inRocket then
            self:SwapQ()
        elseif self.Menu.qTune.preserveStacks:Value() and self.powPowStacks == 3 and not inMinigun and inRocket then

            if dist > self.minigunRange + tbr + 100 then
                if self.Menu.qTune.rocketPoke:Value() then
                    self.rocketPokeMode = true
                end
                self:SwapQ()
            end

        end
    end
end

function Jinx:PredictPosition(target, delay)
    if not target or not IsValid(target) then return nil end
    local hasPath = target.pathing and target.pathing.hasMovePath
    if hasPath and target.ms and target.ms > 0 and target.pathing.endPos then
        local predDist = target.ms * delay * 0.75
        return Extend(target.pos, target.pathing.endPos, predDist)
    end
    return Vec(target.pos.x, target.pos.y, target.pos.z)
end

function Jinx:CastW(target)
    if not Ready(_W) or GameTimer() - self.lastWCast < 0.40 then return false end
    if not target or not IsValid(target) then return false end
    local d = Dist(myHero, target)
    if d > W_RANGE then return false end
    if IsOrbwalkerAttacking() then return false end

    local delay = GetWDelay()
    local travelTime = d / W_SPEED
    local castPos = self:GetPredictedCastPosition(target, "W")
    if not castPos then
        castPos = self:PredictPosition(target, delay + travelTime)
    end
    if not castPos or Dist(myHero.pos, castPos) > W_RANGE then
        castPos = Vec(target.pos.x, target.pos.y, target.pos.z)
    end

    if IsLineBlocked(myHero, castPos, W_RADIUS) then return false end

    Control.CastSpell(HK_W, castPos)
    self.lastWCast = GameTimer()

    self.wHitTime = GameTimer() + delay + travelTime
    self.wHitTarget = target
    return true
end

function Jinx:CastE(pos)
    if not Ready(_E) or GameTimer() - self.lastECast < 0.40 then return false end
    if Dist(myHero.pos, pos) > E_RANGE then return false end
    Control.CastSpell(HK_E, pos)
    self.lastECast = GameTimer()
    return true
end

function Jinx:AutoE()
    if not Ready(_E) then return end
    local eEnemies = GetEnemyHeroes(E_RANGE)

    if self.Menu.autoE.chainWE:Value() and self.wHitTarget then
        local now = GameTimer()
        if now >= self.wHitTime and now <= self.wHitTime + 1.5 then
            local t = self.wHitTarget
            if IsValid(t) and Dist(myHero, t) <= E_RANGE then

                local predPos = self:PredictPosition(t, E_DELAY + E_ARM_TIME)
                if predPos and Dist(myHero.pos, predPos) <= E_RANGE then
                    self:CastE(predPos)
                    self.wHitTarget = nil
                    return
                end
            end
        end

        if now > self.wHitTime + 2.0 then self.wHitTarget = nil end
    end

    if self.Menu.autoE.onCC:Value() then
        local minDur = self.Menu.autoE.ccDuration:Value()
        for i = 1, #eEnemies do
            local e = eEnemies[i]
            local imm, dur = IsImmobile(e)
            if imm and dur >= minDur then

                self:CastE(Vec(e.pos.x, e.pos.y, e.pos.z))
                return
            end
        end
    end

    if self.Menu.autoE.antiDash:Value() then
        for i = 1, #eEnemies do
            local e = eEnemies[i]
            if IsDashingToward(e) and e.pathing.endPos then
                local endPos = e.pathing.endPos
                if Dist(myHero.pos, endPos) < E_RANGE then
                    self:CastE(Vec(endPos.x, myHero.pos.y, endPos.z))
                    return
                end
            end
        end
    end

    if self.Menu.autoE.selfPeel:Value() then
        local pr = self.Menu.autoE.peelRange:Value()
        for _, e in ipairs(GetEnemyHeroes(pr)) do
            if (e.range or 0) <= 300 then
                self:CastE(Vec(myHero.pos.x, myHero.pos.y, myHero.pos.z))
                return
            end
        end
    end
end

function Jinx:CastR(target)
    if not Ready(_R) or GameTimer() - self.lastRCast < 0.50 then return false end
    if not target or not IsValid(target) then return false end

    local d = Dist(myHero, target)
    local speed = GetRSpeed(target)
    local delay = 0.6
    local travelTime = d / speed

    local castPos = self:GetPredictedCastPosition(target, "R")
    if not castPos then
        castPos = self:PredictPosition(target, delay + travelTime)
    end
    if not castPos then castPos = Vec(target.pos.x, target.pos.y, target.pos.z) end

    if self.Menu.ult.collision:Value() then
        if IsRBlockedByChampion(myHero, castPos, 70) then return false end
    end

    Control.CastSpell(HK_R, castPos)
    self.lastRCast = GameTimer()
    return true
end

function Jinx:ExecuteR()
    if not self.Menu.ult.autoR:Value() or not Ready(_R) then return end

    local minRange = self.Menu.ult.minRange:Value()
    local maxRange = self.Menu.ult.maxRange:Value()
    local overkill = self.Menu.ult.overkill:Value()
    local enemies = GetEnemyHeroes(maxRange)

    for i = 1, #enemies do
        local e = enemies[i]
        local d = Dist(myHero, e)
        if d >= minRange and d <= maxRange then
            local rDmg = GetRDamage(e)
            if rDmg >= e.health then

                if overkill then
                    local aaRange = self:GetCurrentRange() + (e.boundingRadius or 0)
                    if d <= aaRange + 50 then
                        local aaDmg = GetAADamage(e)
                        if e.health <= aaDmg * 3 then
                            goto skipR
                        end
                    end
                end
                self:CastR(e)
                return
            end
            ::skipR::
        end
    end

    if self.Menu.ult.multiR:Value() then
        local multiCount = self.Menu.ult.multiCount:Value()
        for i = 1, #enemies do
            local e = enemies[i]
            local d = Dist(myHero, e)
            if d >= minRange and GetEnemyCount(400, e) >= multiCount then
                self:CastR(e)
                return
            end
        end
    end
end

function Jinx:SemiR()
    if not self.Menu.ult.semiKey:Value() or not Ready(_R) then return end
    local range = self.Menu.ult.semiRange:Value()
    local target = GetTarget(range, self.isFishBones)
    if target and Dist(myHero, target) >= self.Menu.ult.minRange:Value() then
        self:CastR(target)
    end
end

function Jinx:KillSteal()
    local mode = ActiveMode ~= "None" and ActiveMode or GetMode()
    if mode == "Combo" then return end

    if self.Menu.ks.useW:Value() and Ready(_W) and not IsOrbwalkerAttacking() then
        for _, e in ipairs(GetEnemyHeroes(W_RANGE)) do
            if GetWDamage(e) >= e.health then
                if not IsLineBlocked(myHero, e, W_RADIUS) then
                    self:CastW(e)
                    return
                end
            end
        end
    end

    if self.Menu.ks.useR:Value() and Ready(_R) then
        local minR = self.Menu.ult.minRange:Value()
        local maxR = self.Menu.ult.maxRange:Value()
        local enemies = GetEnemyHeroes(maxR)
        for i = 1, #enemies do
            local e = enemies[i]
            local d = Dist(myHero, e)
            if d >= minR and d <= maxR and GetRDamage(e) >= e.health then
                self:CastR(e)
                return
            end
        end
    end
end

function Jinx:OnPostAttack()
    local mode = GetMode()

    if self.rocketPokeMode and self.isFishBones then
        self.rocketPokeMode = false
        self:SwapQ()
        return
    end

    if mode ~= "Combo" and mode ~= "Harass" then return end

    local target = GetTarget(W_RANGE, self.isFishBones)
    if not target then return end

    local currentRange = self:GetCurrentRange() + (target.boundingRadius or 0)

    if Ready(_W) then
        if mode == "Combo" and self.Menu.combo.useW:Value() and Dist(myHero, target) > currentRange then
            self:CastW(target)
            return
        end
        if mode == "Harass" and self.Menu.harass.useW:Value() and ManaPercent() >= self.Menu.harass.harassMana:Value() then
            if Dist(myHero, target) > currentRange then
                self:CastW(target)
                return
            end
        end
    end
end

function Jinx:Combo()
    if ManaPercent() < self.Menu.combo.comboMana:Value() then return end

    local target = GetTarget(self.rocketRange + 100, self.isFishBones)
    if not target then return end

    if self.Menu.combo.useQ:Value() then
        self:SmartToggle(target, "Combo")
    end

    if self.Menu.combo.useE:Value() and Ready(_E) and Dist(myHero, target) <= E_RANGE then
        local imm, dur = IsImmobile(target)
        if imm and dur >= (E_DELAY + E_ARM_TIME + 0.2) then
            self:CastE(Vec(target.pos.x, target.pos.y, target.pos.z))
        end
    end

    if self.Menu.combo.useR:Value() then
        self:ExecuteR()
    end
end

function Jinx:Harass()
    if ManaPercent() < self.Menu.harass.harassMana:Value() then return end

    local target = GetTarget(self.rocketRange + 100, self.isFishBones)
    if not target then return end

    if self.Menu.harass.useQ:Value() and Ready(_Q) then
        local dist = Dist(myHero, target)
        local tbr = target.boundingRadius or 0
        if not self.isFishBones and dist > self.minigunRange + tbr and dist <= self.rocketRange + tbr then
            self.rocketPokeMode = true
            self:SwapQ()
        elseif self.isFishBones and dist <= self.minigunRange + tbr then
            self:SwapQ()
        end
    end
end

function Jinx:Clear()
    if not Ready(_Q) then return end

    if self.Menu.clear.rocketAOE:Value() and ManaPercent() >= self.Menu.clear.clearMana:Value() then
        if not self.isFishBones then
            local minCount = self.Menu.clear.minMinions:Value()
            local count = GetMinionCount(self.minigunRange + 50, myHero.pos)
            if count >= minCount then
                self:SwapQ()
            end
        end
    end

    if self.isFishBones then
        if ManaPercent() < self.Menu.clear.clearMana:Value() or not self.Menu.clear.rocketAOE:Value() then
            self:SwapQ()
        end
    end
end

function Jinx:Flee()
    if self.Menu.flee.useE:Value() and Ready(_E) then
        self:CastE(Vec(myHero.pos.x, myHero.pos.y, myHero.pos.z))
    end
    if self.Menu.flee.useW:Value() and Ready(_W) and not IsOrbwalkerAttacking() then
        local target = GetTarget(W_RANGE, false)
        if target then self:CastW(target) end
    end
end

function Jinx:UpdateDrawCache()
    local now = GameTimer()
    local range = self.Menu.ult.maxRange:Value()
    if self.drawCache and now - self.drawCache.tick < DRAW_CACHE_DURATION and self.drawCache.range == range then
        return
    end

    local rEnemies = {}
    local enemies = GetEnemyHeroes(range)
    for i = 1, #enemies do
        local e = enemies[i]
        local sp = e.pos:To2D()
        if sp and sp.onScreen then
            local rDmg = GetRDamage(e)
            rEnemies[#rEnemies + 1] = {
                enemy = e,
                damage = rDmg,
                kill = rDmg >= e.health
            }
        end
    end

    self.drawCache = {
        tick = now,
        range = range,
        rEnemies = rEnemies
    }
end

function Jinx:OnTick()
    local now = GameTimer()
    if now - self.lastTick < 0.05 then return end
    self.lastTick = now
    local mode = GetMode()
    ActiveMode = mode

    self:UpdateQ()
    self:UpdateExcited()

    if MyHeroNotReady() or myHero.isChanneling then return end

    self:AutoE()
    self:SemiR()
    self:KillSteal()

    if mode == "Combo" then self:Combo()
    elseif mode == "Harass" then self:Harass()
    elseif mode == "Clear" then self:Clear()
    elseif mode == "Flee" then self:Flee()

    elseif mode == "None" or mode == "LastHit" then
        if self.isFishBones and Ready(_Q) then self:SwapQ() end
    end
end

function Jinx:OnDraw()
    if not self.Menu.draw.enable:Value() or myHero.dead then return end
    if self.Menu.draw.rDmg:Value() then
        self:UpdateDrawCache()
    end

    if self.Menu.draw.aaRange:Value() then
        local r = self:GetCurrentRange()
        local c = self.isFishBones and RGBA(150, 255, 100, 50) or RGBA(150, 50, 180, 255)
        DrawCircle3D(myHero.pos, r, 1, c)

        if self.isFishBones then
            DrawCircle3D(myHero.pos, self.minigunRange, 1, RGBA(80, 50, 180, 255))
        end
    end

    if self.Menu.draw.wRange:Value() and Ready(_W) then
        DrawCircle3D(myHero.pos, W_RANGE, 1, RGBA(100, 100, 100, 255))
    end

    if self.Menu.draw.weapon:Value() and Draw and Draw.Text then
        local sp = myHero.pos:To2D()
        if sp and sp.onScreen then
            local txt, col
            if self.isFishBones then
                txt = "ROCKETS"
                col = RGBA(255, 255, 100, 50)
            else
                txt = string_format("MINIGUN [%d]", self.powPowStacks)
                col = RGBA(255, 50, 180, 255)
            end
            Draw.Text(txt, 16, sp.x - 30, sp.y + 30, col)
        end
    end

    if self.Menu.draw.excited:Value() and self.isExcited and Draw and Draw.Text then
        local sp = myHero.pos:To2D()
        if sp and sp.onScreen then
            local remaining = math_max(0, self.excitedExpire - GameTimer())
            Draw.Text(string_format("GET EXCITED! %.1fs", remaining), 18, sp.x - 55, sp.y + 48, RGBA(255, 255, 0, 200))
        end
    end

    if self.Menu.draw.rDmg:Value() and Draw and Draw.Text then
        local rEnemies = self.drawCache and self.drawCache.rEnemies or {}
        for i = 1, #rEnemies do
            local entry = rEnemies[i]
            local e = entry.enemy
            local sp = e.pos:To2D()
            if sp and sp.onScreen then
                local col = entry.kill and RGBA(255, 255, 50, 50) or RGBA(200, 200, 200, 200)
                Draw.Text(string_format("R: %.0f", entry.damage), 14, sp.x - 20, sp.y - 30, col)
                if entry.kill then
                    Draw.Text("KILLABLE", 14, sp.x - 28, sp.y - 45, RGBA(255, 255, 0, 0))
                end
            end
        end
    end
end

Jinx:Create()
