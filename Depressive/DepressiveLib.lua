local DepressiveLib = {}
DepressiveLib.__version = 1.02
-- Mirror for loader compatibility (loader searches scriptVersion = x.y)
local scriptVersion = DepressiveLib.__version

-- Performance cap: any range query will be clamped to this
local MAX_RANGE = 2000

-- Clamp helper must exist before any function references it
local function ClampRange(r)
    r = r or 0
    if r > MAX_RANGE then return MAX_RANGE elseif r < 0 then return 0 end
    return r
end
DepressiveLib.ClampRange = ClampRange

-- Internal caches
local Allies, Enemies, Minions = {}, {}, {}
-- Cached squared distances to myHero for fast in-range checks when querying from myHero position
local EnemyDist2, AllyDist2 = {}, {}
local LastHeroScan, LastMinionScan, ScanInterval = 0, 0, 0.33

local function SafeTime()
    return (Game and Game.Timer and Game.Timer()) or os.clock()
end

-- Basic validation
function DepressiveLib.IsValid(unit)
    return unit and unit.valid and unit.visible and unit.isTargetable and not unit.dead and unit.health > 0
end

function DepressiveLib.Ready(slot)
    if not myHero then return false end
    if Game and Game.CanUseSpell then return Game.CanUseSpell(slot) == 0 end
    local sd = myHero.GetSpellData and myHero:GetSpellData(slot)
    if not sd or sd.level == 0 then return false end
    return sd.currentCd == 0
end

function DepressiveLib.MyHeroNotReady()
    return not myHero or myHero.dead or (myHero.isChanneling) or (myHero.activeSpell and myHero.activeSpell.valid)
end

-- Mode detection
function DepressiveLib.GetMode()
    if _G.EOWLoaded and EOW and EOW.Mode then
        local ok, mode = pcall(function() return EOW:Mode() end)
        if ok and mode then
            if mode == 1 then return "Combo" elseif mode == 2 then return "Harass" elseif mode == 3 then return "LaneClear" elseif mode == 4 then return "LastHit" end
        end
    end
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then
        local O = _G.SDK.Orbwalker
        if O.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then return "Combo" end
        if O.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then return "Harass" end
        if O.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then return "LaneClear" end
        if O.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then return "LastHit" end
    end
    if _G.GOS and GOS.GetMode then return GOS:GetMode() end
    return ""
end

-- Target selection
function DepressiveLib.GetTarget(range, damageType)
    range = ClampRange(range)
    damageType = damageType or "AD"
    if _G.GOS and GOS.GetTarget then return GOS:GetTarget(range, damageType) end
    if _G.EOWLoaded and EOW and EOW.GetTarget then return EOW:GetTarget(range) end
    if _G.SDK and _G.SDK.TargetSelector then
        if damageType == "AP" then
            return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
        else
            return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL)
        end
    end
    local chosen, bestHealth = nil, math.huge
    for _, e in ipairs(Enemies) do
        if DepressiveLib.IsValid(e) and e.distance <= range and e.health < bestHealth then
            chosen, bestHealth = e, e.health
        end
    end
    return chosen
end

-- Buff helpers
function DepressiveLib.HasBuff(unit, buffname)
    if not DepressiveLib.IsValid(unit) then return false end
    local lname = buffname:lower()
    for i = 0, unit.buffCount do
        local b = unit:GetBuff(i)
        if b and b.count > 0 and b.name and b.name:lower() == lname then return true end
    end
    return false
end

function DepressiveLib.GetBuffData(unit, buffname)
    if not DepressiveLib.IsValid(unit) then return nil end
    local lname = buffname:lower()
    for i = 0, unit.buffCount do
        local b = unit:GetBuff(i)
        if b and b.count > 0 and b.name and b.name:lower() == lname then return b end
    end
    return nil
end

-- Scanners
local function ScanHeroes()
    Allies, Enemies = {}, {}
    EnemyDist2, AllyDist2 = {}, {}
    local hc = Game.HeroCount() or 0
    local mh = myHero
    local mhx, mhz
    if mh then mhx, mhz = mh.pos.x, mh.pos.z end
    for i = 1, hc do
        local h = Game.Hero(i)
        if h and h.team then
            if h.isAlly then
                Allies[#Allies+1] = h
                if mhx then
                    local dx, dz = h.pos.x - mhx, h.pos.z - mhz
                    AllyDist2[h.networkID] = dx*dx + dz*dz
                end
            elseif h.isEnemy then
                Enemies[#Enemies+1] = h
                if mhx then
                    local dx, dz = h.pos.x - mhx, h.pos.z - mhz
                    EnemyDist2[h.networkID] = dx*dx + dz*dz
                end
            end
        end
    end
end

local function ScanMinions()
    Minions = {}
    local mc = Game.MinionCount() or 0
    for i = 1, mc do
        local m = Game.Minion(i)
        if m and m.team and DepressiveLib.IsValid(m) then Minions[#Minions+1] = m end
    end
end

function DepressiveLib.RefreshCaches(force)
    local t = SafeTime()
    if force or t - LastHeroScan > ScanInterval then ScanHeroes(); LastHeroScan = t end
    if force or t - LastMinionScan > ScanInterval then ScanMinions(); LastMinionScan = t end
end

-- Iterators
function DepressiveLib.ForEachEnemy(fn) for _, e in ipairs(Enemies) do if fn(e) == false then break end end end
function DepressiveLib.ForEachAlly(fn) for _, a in ipairs(Allies) do if fn(a) == false then break end end end
function DepressiveLib.ForEachMinion(fn) for _, m in ipairs(Minions) do if fn(m) == false then break end end end

-- Counting
local function Dist(a,b) return (a.x-b.x)*(a.x-b.x)+(a.z-b.z)*(a.z-b.z) end
function DepressiveLib.CountEnemiesInRange(pos, range)
    range = ClampRange(range)
    local r2, c = range*range, 0
    local mh = myHero
    if mh and pos == mh.pos then
        for _, e in ipairs(Enemies) do
            if DepressiveLib.IsValid(e) then
                local d2 = EnemyDist2[e.networkID]
                if d2 and d2 <= r2 then c = c + 1 end
            end
        end
        return c
    end
    for _, e in ipairs(Enemies) do if DepressiveLib.IsValid(e) and Dist(pos, e.pos) <= r2 then c = c + 1 end end
    return c
end
function DepressiveLib.CountAlliesInRange(pos, range)
    range = ClampRange(range)
    local r2, c = range*range, 0
    local mh = myHero
    if mh and pos == mh.pos then
        for _, a in ipairs(Allies) do
            if DepressiveLib.IsValid(a) then
                local d2 = AllyDist2[a.networkID]
                if d2 and d2 <= r2 then c = c + 1 end
            end
        end
        return c
    end
    for _, a in ipairs(Allies) do if DepressiveLib.IsValid(a) and Dist(pos, a.pos) <= r2 then c = c + 1 end end
    return c
end

-- Simple linear prediction
function DepressiveLib.LinearPrediction(target, speed, delay)
    if not DepressiveLib.IsValid(target) then return nil end
    speed = speed or math.huge
    delay = delay or 0.25
    local tPos = target.pos
    if speed == math.huge then return tPos end
    local travel = (myHero.pos:DistanceTo(tPos) / speed) + delay
    if target.pathing and target.pathing.hasMovePath and target.pathing.endPos then
        local dir = (target.pathing.endPos - tPos):Normalized()
        return tPos + dir * target.ms * travel
    end
    return tPos
end

-- DamageLib bridge
local hasDmg = false
pcall(function() require("DamageLib") hasDmg = type(_G.getdmg) == "function" end)
function DepressiveLib.GetDamage(spell, target)
    if hasDmg then
        local ok, val = pcall(function() return _G.getdmg(spell, target, myHero) end)
        if ok and val then return val end
    end
    return 0
end

-- Casting helper
function DepressiveLib.CastSpellFast(hk, pos, skipRangeCheck, range)
    if not hk then return false end
    if pos and not skipRangeCheck and range and myHero.pos:DistanceTo(pos) > range then return false end
    if pos then Control.CastSpell(hk, pos) else Control.CastSpell(hk) end
    return true
end

-- Auto cache refresh
Callback.Add("Tick", function() DepressiveLib.RefreshCaches(false) end)

-- =========================
-- Additional shared helpers (generalized utilities)
-- =========================

function DepressiveLib.SetMovement(bool)
    if _G.GOS then GOS.BlockMovement = not bool end
    if _G.EOWLoaded and EOW and EOW.SetMovements then EOW:SetMovements(bool) end
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.SetMovement then _G.SDK.Orbwalker:SetMovement(bool) end
end

function DepressiveLib.GetMinionCount(range, pos)
    local p = (pos and (pos.pos or pos)) or myHero.pos
    local r2, c = range * range, 0
    for _, m in ipairs(Minions) do
        if m.isEnemy and DepressiveLib.IsValid(m) and ((p.x-m.pos.x)^2 + (p.z-m.pos.z)^2) <= r2 then
            c = c + 1
        end
    end
    return c
end

function DepressiveLib.PercentHP(unit)
    unit = unit or myHero
    if not unit or unit.maxHealth == 0 then return 0 end
    return (unit.health / unit.maxHealth) * 100
end
function DepressiveLib.PercentMP(unit)
    unit = unit or myHero
    if not unit or unit.maxMana == 0 then return 0 end
    return (unit.mana / unit.maxMana) * 100
end

function DepressiveLib.GetBuffStacks(unit, buffname)
    local b = DepressiveLib.GetBuffData(unit, buffname)
    return b and b.count or 0
end

local ImmobileBuffTypes = {
    [5] = true,[11] = true,[21] = true,[22] = true,[24] = true,[29] = true,[30] = true,[18] = true,[8] = true,
}
function DepressiveLib.IsImmobile(unit)
    if not DepressiveLib.IsValid(unit) then return false end
    for i = 0, unit.buffCount do
        local b = unit:GetBuff(i)
        if b and b.count > 0 and ImmobileBuffTypes[b.type] and b.duration > 0 then return true end
    end
    return false
end

function DepressiveLib.IsFacing(source, target, angle)
    if not (DepressiveLib.IsValid(source) and DepressiveLib.IsValid(target)) then return false end
    angle = angle or 90
    local v1 = (target.pos - source.pos):Normalized()
    local v2 = (source.pos + (source.dir or v1) * 100 - source.pos):Normalized()
    local a = math.deg(math.acos(math.max(-1, math.min(1, v1.x * v2.x + v1.z * v2.z))))
    return a < angle / 2
end

function DepressiveLib.GetPathLength(unit)
    if not DepressiveLib.IsValid(unit) or not unit.pathing or not unit.pathing.hasMovePath then return 0 end
    local result, last = 0, unit.pos
    for i = unit.pathing.pathIndex, unit.pathing.pathCount do
        local p = unit.pathing:GetPath(i)
        result = result + last:DistanceTo(p)
        last = p
    end
    return result
end

function DepressiveLib.IsDashing(unit)
    return unit and unit.pathing and unit.pathing.isDashing
end

local EnemyTurrets, LastTurretScan, TurretScanInterval = {}, 0, 2
local function ScanTurrets()
    EnemyTurrets = {}
    local tc = Game.TurretCount and Game.TurretCount() or 0
    for i = 1, tc do
        local t = Game.Turret(i)
        if t and t.isEnemy and not t.dead then EnemyTurrets[#EnemyTurrets+1] = t end
    end
end
function DepressiveLib.UnderEnemyTurret(pos)
    pos = pos or myHero.pos
    local tNow = SafeTime()
    if tNow - LastTurretScan > TurretScanInterval then ScanTurrets(); LastTurretScan = tNow end
    for _, t in ipairs(EnemyTurrets) do if t.pos:DistanceTo(pos) < 915 then return true end end
    return false
end

if type(_G.ConvertToHitChance) ~= "function" then
    function _G.ConvertToHitChance(menuVal, predHC)
        if type(predHC) == "number" then return predHC >= (menuVal + 1) end
        return true
    end
end

function DepressiveLib.GetPredPos(target, speed, delay, width)
    if not DepressiveLib.IsValid(target) then return nil end
    if _G.DepressivePrediction and type(_G.DepressivePrediction.GetPrediction) == "function" then
        local data = { speed = speed or math.huge, delay = delay or 0.25, width = width or 60, range = 2000, collision = false, type = "linear" }
        local res = _G.DepressivePrediction:GetPrediction(target, data)
        if res and res.castPos then return res.castPos end
    end
    return DepressiveLib.LinearPrediction(target, speed, delay)
end

function DepressiveLib.GetBestLinearFarmPos(range, width, minions)
    range = ClampRange(range)
    width = width or 60
    minions = minions or Minions
    local bestPos, bestHit = nil, 0
    for i = 1, #minions do
        local m1 = minions[i]
        if m1.isEnemy and DepressiveLib.IsValid(m1) and m1.distance <= range then
            local p1 = m1.pos
            local hit = 1
            for j = 1, #minions do
                if i ~= j then
                    local m2 = minions[j]
                    if m2.isEnemy and DepressiveLib.IsValid(m2) and m2.distance <= range then
                        -- Approximation: treat as cluster width box
                        if math.abs(m2.pos.x - p1.x) <= width and math.abs(m2.pos.z - p1.z) <= width then
                            hit = hit + 1
                        end
                    end
                end
            end
            if hit > bestHit then bestHit, bestPos = hit, p1 end
        end
    end
    return bestPos, bestHit
end

return DepressiveLib
