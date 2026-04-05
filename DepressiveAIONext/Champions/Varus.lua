local VERSION = "1.0"
local SCRIPT_NAME = "DepressiveVarus"

if _G.__DEPRESSIVE_NEXT_VARUS_LOADED then return end
if myHero.charName ~= "Varus" then return end
_G.__DEPRESSIVE_NEXT_VARUS_LOADED = true
_G.DepressiveAIONextLoadedChampion = true

pcall(require, "GGPrediction")

local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local string_lower = string.lower
local pairs = pairs
local pcall = pcall

local Game = _G.Game
local Control = _G.Control
local Draw = _G.Draw
local Vector = _G.Vector
local myHero = _G.myHero

local GameTimer = Game.Timer
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero

local _Q, _W, _E, _R = 0, 1, 2, 3
local HK_Q = HK_Q or _Q
local HK_W = HK_W or _W
local HK_E = HK_E or _E
local HK_R = HK_R or _R

local TEAM_ALLY = myHero.team
local TEAM_ENEMY = (TEAM_ALLY == 100 and 200) or 100

local Q_MIN_RANGE = 925
local Q_MAX_RANGE = 1600
local Q_SPEED = 1900
local Q_DELAY = 0.10
local Q_RADIUS = 70
local Q_CHARGE_TIME = 1.25
local Q_MAX_HOLD = 4.0
local Q_DAMAGE_BASE = {10, 47, 83, 120, 157}
local Q_DAMAGE_FULL = {15, 70, 125, 180, 235}
local Q_BONUS_AD_RATIO_MIN = 1.30
local Q_BONUS_AD_RATIO_FULL = 1.65
local E_RANGE = 925
local E_DELAY = 0.242
local E_SPEED = 1500
local E_RADIUS = 260
local E_DAMAGE_BASE = {60, 100, 140, 180, 220}
local E_BONUS_AD_RATIO = 1.00
local R_RANGE = 1200
local R_DELAY = 0.25
local R_SPEED = 1950
local R_RADIUS = 120
local BLIGHT_STACK_PCT = {0.03, 0.035, 0.04, 0.045, 0.05}
local BLIGHT_AP_PCT_PER_100 = 0.025
local W_ACTIVE_MISSING_HP_PCT = {0.06, 0.08, 0.10, 0.12, 0.14}
local Q_RELEASE_W_DELAY = 0.06
local DETONATE_LOCKOUT = 0.45
local R_FOLLOWUP_WINDOW = 2.5

local function Vec(x, y, z)
    if Vector then
        return Vector(x, y, z)
    end
    return {x = x, y = y, z = z}
end

local function Dist(a, b)
    local p1, p2 = a.pos or a, b.pos or b
    if not p1 or not p2 then return math_huge end
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return math_sqrt(dx * dx + dz * dz)
end

local function IsValid(unit)
    return unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable
end

local function IsValidTarget(unit, range)
    if not IsValid(unit) or unit.team ~= TEAM_ENEMY then return false end
    return not range or Dist(myHero, unit) <= range
end

local function Ready(slot)
    local sd = myHero:GetSpellData(slot)
    if not sd or sd.level == 0 then return false end
    return sd.currentCd == 0 and Game.CanUseSpell(slot) == 0
end

local function MyHeroNotReady()
    if Game.IsChatOpen() then return true end
    if _G.JustEvade and _G.JustEvade:Evading() then return true end
    if _G.ExtLibEvade and _G.ExtLibEvade.Evading then return true end
    return myHero.dead
end

local function GetMode()
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then
        local M, S = _G.SDK.Orbwalker.Modes, _G.SDK
        if S.ORBWALKER_MODE_COMBO and M[S.ORBWALKER_MODE_COMBO] then return "Combo" end
        if S.ORBWALKER_MODE_SPACING and M[S.ORBWALKER_MODE_SPACING] then return "Combo" end
        if S.ORBWALKER_MODE_HARASS and M[S.ORBWALKER_MODE_HARASS] then return "Harass" end
        if S.ORBWALKER_MODE_LANECLEAR and M[S.ORBWALKER_MODE_LANECLEAR] then return "Clear" end
        if S.ORBWALKER_MODE_JUNGLECLEAR and M[S.ORBWALKER_MODE_JUNGLECLEAR] then return "Jungle" end
        if S.ORBWALKER_MODE_LASTHIT and M[S.ORBWALKER_MODE_LASTHIT] then return "LastHit" end
        if S.ORBWALKER_MODE_FLEE and M[S.ORBWALKER_MODE_FLEE] then return "Flee" end
    end
    return "None"
end

local function SDKDamage(from, target, dmgType, raw)
    if _G.SDK and _G.SDK.Damage and _G.SDK.Damage.CalculateDamage then
        local ok, damage = pcall(function()
            return _G.SDK.Damage:CalculateDamage(from, target, dmgType, raw)
        end)
        if ok and damage then
            return damage
        end
    end
    return raw * 0.7
end

local function PhysicalDamage(target, raw)
    return SDKDamage(myHero, target, _G.SDK and _G.SDK.DAMAGE_TYPE_PHYSICAL or 1, raw)
end

local function MagicDamage(target, raw)
    return SDKDamage(myHero, target, _G.SDK and _G.SDK.DAMAGE_TYPE_MAGICAL or 2, raw)
end

local function GetBuff(unit, buffName)
    if not unit or not unit.buffCount then return nil end
    local search = string_lower(buffName)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count and buff.count > 0 and buff.name and string_lower(buff.name) == search then
            return buff
        end
    end
    return nil
end

local function HasQBuff()
    return GetBuff(myHero, "varusq") ~= nil
end

local function GetBlightStacks(target)
    local buff = GetBuff(target, "varuswdebuff")
    if not buff then return 0 end
    return buff.count or buff.stacks or 0
end

local function GetCurrentQRange(chargeTime)
    local pct = math_min(math_max(chargeTime / Q_CHARGE_TIME, 0), 1)
    return Q_MIN_RANGE + (Q_MAX_RANGE - Q_MIN_RANGE) * pct
end

local function GetChargeScalar(chargeTime)
    local pct = math_min(math_max(chargeTime / Q_CHARGE_TIME, 0), 1)
    return 0.5 + (0.5 * pct)
end

local function NormalizeGGHitChance(prediction)
    if not _G.GGPrediction or not prediction or not prediction.CastPosition then return 0 end
    if prediction:CanHit(_G.GGPrediction.HITCHANCE_IMMOBILE) then return 6 end
    if prediction:CanHit(_G.GGPrediction.HITCHANCE_HIGH) then return 4 end
    if prediction:CanHit(_G.GGPrediction.HITCHANCE_NORMAL) then return 3 end
    return 2
end

local Varus = {}
Varus.__index = Varus

function Varus:Create()
    local self = setmetatable({}, Varus)
    self.qChargeStart = 0
    self.qReleaseTarget = nil
    self.qReleasePos = nil
    self.wCastTime = 0
    self.wUsedThisCharge = false
    self.lastQStartAttempt = 0
    self.lastDetonateCastTime = 0
    self.lastDetonateSpell = nil
    self.lastRCastTime = 0
    self.rFollowupTarget = nil
    self.rFollowupReadyTime = 0
    self.rFollowupExpireTime = 0
    self.drawTarget = nil
    self:LoadMenu()
    self:LoadCallbacks()
    print("[" .. SCRIPT_NAME .. "] Loaded v" .. VERSION)
    return self
end

function Varus:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveVarus", name = SCRIPT_NAME})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. VERSION}})

    self.Menu:MenuElement({type = MENU, id = "pred", name = "Prediction"})
    self.Menu.pred:MenuElement({id = "qHitChance", name = "Q Hit Chance", value = 3, min = 1, max = 6, step = 1})

    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.Menu.combo:MenuElement({id = "useWQ", name = "Use W with Q on stacks", value = true})
    self.Menu.combo:MenuElement({id = "minStacks", name = "Min W stacks", value = 3, min = 1, max = 3, step = 1})
    self.Menu.combo:MenuElement({id = "useE", name = "Use E to pop stacks", value = true})
    self.Menu.combo:MenuElement({id = "eMinStacks", name = "E min stacks", value = 2, min = 2, max = 3, step = 1})

    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useWQ", name = "Use W with Q on stacks", value = false})
    self.Menu.harass:MenuElement({id = "minStacks", name = "Min W stacks", value = 3, min = 1, max = 3, step = 1})
    self.Menu.harass:MenuElement({id = "useE", name = "Use E to pop stacks", value = false})
    self.Menu.harass:MenuElement({id = "eMinStacks", name = "E min stacks", value = 2, min = 2, max = 3, step = 1})

    self.Menu:MenuElement({type = MENU, id = "ks", name = "Killsteal"})
    self.Menu.ks:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.ks:MenuElement({id = "useWQ", name = "Use W + Q", value = true})
    self.Menu.ks:MenuElement({id = "qHitChance", name = "KS Q Hit Chance", value = 3, min = 1, max = 6, step = 1})
    self.Menu.ks:MenuElement({id = "useE", name = "Use E", value = true})
    self.Menu.ks:MenuElement({id = "eHitChance", name = "KS E Hit Chance", value = 3, min = 1, max = 6, step = 1})

    self.Menu:MenuElement({type = MENU, id = "rlogic", name = "R Logic"})
    self.Menu.rlogic:MenuElement({id = "useAntiDash", name = "Use R anti-dash", value = true})
    self.Menu.rlogic:MenuElement({id = "useAntiMelee", name = "Use R anti-melee", value = true})
    self.Menu.rlogic:MenuElement({id = "antiMeleeRange", name = "Anti-melee range", value = 500, min = 200, max = 500, step = 25})
    self.Menu.rlogic:MenuElement({id = "rHitChance", name = "R Hit Chance", value = 3, min = 1, max = 6, step = 1})

    self.Menu:MenuElement({type = MENU, id = "draw", name = "Draw"})
    self.Menu.draw:MenuElement({id = "showTarget", name = "Draw WQ kill target", value = true})
    self.Menu.draw:MenuElement({id = "drawRange", name = "Draw Q max range", value = true})
end

function Varus:LoadCallbacks()
    Callback.Add("Tick", function() self:OnTick() end)
    Callback.Add("Draw", function() self:OnDraw() end)
end

function Varus:GetPredictedCastPosition(target, range)
    if not target or not IsValid(target) or not (_G.GGPrediction and _G.GGPrediction.SpellPrediction) then return nil, 0 end

    local prediction = _G.GGPrediction:SpellPrediction({
        Type = _G.GGPrediction.SPELLTYPE_LINE,
        Delay = Q_DELAY,
        Radius = Q_RADIUS,
        Range = range,
        Speed = Q_SPEED,
        Collision = false
    })
    prediction:GetPrediction(target, myHero)
    local castPos = prediction.CastPosition
    if castPos and castPos.x and castPos.z then
        return Vec(castPos.x, castPos.y or myHero.pos.y, castPos.z), NormalizeGGHitChance(prediction)
    end
    return nil, 0
end

function Varus:GetEPredictedCastPosition(target)
    if not target or not IsValid(target) or not (_G.GGPrediction and _G.GGPrediction.SpellPrediction) then return nil, 0 end

    local prediction = _G.GGPrediction:SpellPrediction({
        Type = _G.GGPrediction.SPELLTYPE_CIRCLE,
        Delay = E_DELAY,
        Radius = E_RADIUS,
        Range = E_RANGE,
        Speed = E_SPEED,
        Collision = false
    })
    prediction:GetPrediction(target, myHero)
    local castPos = prediction.CastPosition
    if castPos and castPos.x and castPos.z then
        return Vec(castPos.x, castPos.y or myHero.pos.y, castPos.z), NormalizeGGHitChance(prediction)
    end
    return nil, 0
end

function Varus:GetRPredictedCastPosition(target)
    if not target or not IsValid(target) or not (_G.GGPrediction and _G.GGPrediction.SpellPrediction) then return nil, 0 end

    local prediction = _G.GGPrediction:SpellPrediction({
        Type = _G.GGPrediction.SPELLTYPE_LINE,
        Delay = R_DELAY,
        Radius = R_RADIUS,
        Range = R_RANGE,
        Speed = R_SPEED,
        Collision = false
    })
    prediction:GetPrediction(target, myHero)
    local castPos = prediction.CastPosition
    if castPos and castPos.x and castPos.z then
        return Vec(castPos.x, castPos.y or myHero.pos.y, castPos.z), NormalizeGGHitChance(prediction)
    end
    return nil, 0
end

function Varus:GetQDamage(target, chargeTime)
    if not target then return 0 end
    if _G.getdmg then
        local ok, damage = pcall(function()
            return _G.getdmg("Q", target, myHero)
        end)
        if ok and damage and damage > 0 then
            return damage * GetChargeScalar(chargeTime)
        end
    end

    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end

    local bonusAD = math_max(0, (myHero.bonusDamage or 0))
    local pct = math_min(math_max(chargeTime / Q_CHARGE_TIME, 0), 1)
    local base = Q_DAMAGE_BASE[level] + (Q_DAMAGE_FULL[level] - Q_DAMAGE_BASE[level]) * pct
    local ratio = Q_BONUS_AD_RATIO_MIN + ((Q_BONUS_AD_RATIO_FULL - Q_BONUS_AD_RATIO_MIN) * pct)
    return PhysicalDamage(target, base + bonusAD * ratio)
end

function Varus:GetWQActiveDamage(target, chargeTime)
    local wLevel = myHero:GetSpellData(_W).level
    if not target or wLevel == 0 then return 0 end

    local missingHealth = math_max(0, target.maxHealth - target.health)
    if missingHealth <= 0 then return 0 end

    local chargePct = math_min(math_max(chargeTime / Q_CHARGE_TIME, 0), 1)
    local ratio = W_ACTIVE_MISSING_HP_PCT[wLevel] * (1 + 0.5 * chargePct)
    return MagicDamage(target, missingHealth * ratio)
end

function Varus:GetEDamage(target)
    if not target then return 0 end
    if _G.getdmg then
        local ok, damage = pcall(function()
            return _G.getdmg("E", target, myHero)
        end)
        if ok and damage and damage > 0 then
            return damage
        end
    end

    local level = myHero:GetSpellData(_E).level
    if level == 0 then return 0 end

    local bonusAD = math_max(0, myHero.bonusDamage or 0)
    return PhysicalDamage(target, E_DAMAGE_BASE[level] + bonusAD * E_BONUS_AD_RATIO)
end

function Varus:GetBlightDetonationDamage(target, stacks)
    local wLevel = myHero:GetSpellData(_W).level
    if not target or wLevel == 0 or stacks <= 0 then return 0 end

    local ap = myHero.ap or 0
    local pctPerStack = BLIGHT_STACK_PCT[wLevel] + ((ap / 100) * BLIGHT_AP_PCT_PER_100)
    local raw = math_max(0, target.maxHealth * pctPerStack * stacks)
    return MagicDamage(target, raw)
end

function Varus:GetModeSettings(mode)
    if mode == "Combo" then
        return self.Menu.combo.useWQ:Value(), self.Menu.combo.minStacks:Value()
    end
    if mode == "Harass" then
        return false, self.Menu.harass.minStacks:Value()
    end
    return false, 99
end

function Varus:GetTarget(range)
    if _G.SDK and _G.SDK.TargetSelector then
        local selected = _G.SDK.TargetSelector.SelectedTarget
        if selected and IsValidTarget(selected, range) then return selected end
        local ok, target = pcall(function()
            return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL)
        end)
        if ok and target and IsValidTarget(target, range) then
            return target
        end
    end

    local best, bestHealth = nil, math_huge
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if IsValidTarget(hero, range) and hero.health < bestHealth then
            best = hero
            bestHealth = hero.health
        end
    end
    return best
end

function Varus:GetKSRequiredHitChance()
    if self.Menu and self.Menu.ks and self.Menu.ks.qHitChance then
        return self.Menu.ks.qHitChance:Value()
    end
    return self.Menu.pred.qHitChance:Value()
end

function Varus:GetERequiredHitChance()
    if self.Menu and self.Menu.ks and self.Menu.ks.eHitChance then
        return self.Menu.ks.eHitChance:Value()
    end
    return self.Menu.pred.qHitChance:Value()
end

function Varus:GetRRequiredHitChance()
    if self.Menu and self.Menu.rlogic and self.Menu.rlogic.rHitChance then
        return self.Menu.rlogic.rHitChance:Value()
    end
    return self.Menu.pred.qHitChance:Value()
end

function Varus:CanUseAnotherDetonator(spellName, ignoreLockout)
    if ignoreLockout then return true end
    if self.lastDetonateCastTime <= 0 then return true end
    if GameTimer() - self.lastDetonateCastTime > DETONATE_LOCKOUT then return true end
    return self.lastDetonateSpell == spellName
end

function Varus:RegisterDetonatorCast(spellName)
    self.lastDetonateCastTime = GameTimer()
    self.lastDetonateSpell = spellName
end

function Varus:CanCastR()
    if not Ready(_R) then return false end
    if GameTimer() - self.lastRCastTime < 0.50 then return false end
    return true
end

function Varus:CastRAtTarget(target, castPos)
    if not target or not castPos or not self:CanCastR() then return false end
    if Dist(myHero, castPos) > R_RANGE then return false end
    Control.CastSpell(HK_R, castPos)
    local now = GameTimer()
    self.lastRCastTime = now
    local travelTime = R_DELAY + (Dist(myHero, target) / R_SPEED)
    self.rFollowupTarget = target
    self.rFollowupReadyTime = now + travelTime
    self.rFollowupExpireTime = now + travelTime + R_FOLLOWUP_WINDOW
    self.drawTarget = target
    return true
end

function Varus:FindQKillTarget(range, chargeTime, allowW)
    if not self.Menu.ks.useQ:Value() then return nil, nil, 0, false end
    if not Ready(_Q) and not HasQBuff() then return nil, nil, 0, false end

    local requiredHit = self:GetKSRequiredHitChance()
    local bestTarget, bestPos, bestDamage, bestUseW = nil, nil, 0, false

    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy, range) then
            local castPos, hitChance = self:GetPredictedCastPosition(enemy, range)
            if castPos and hitChance >= requiredHit and Dist(myHero, castPos) <= range then
                local qDamage = self:GetQDamage(enemy, chargeTime)
                local totalDamage = qDamage
                local useWNow = false

                if allowW and self.Menu.ks.useWQ:Value() and Ready(_W) then
                    local wDamage = self:GetWQActiveDamage(enemy, chargeTime)
                    if totalDamage + wDamage >= enemy.health then
                        totalDamage = totalDamage + wDamage
                        useWNow = true
                    end
                end

                if totalDamage >= enemy.health then
                    if not bestTarget or enemy.health < bestTarget.health then
                        bestTarget = enemy
                        bestPos = castPos
                        bestDamage = totalDamage
                        bestUseW = useWNow
                    end
                end
            end
        end
    end

    return bestTarget, bestPos, bestDamage, bestUseW
end

function Varus:GetEModeSettings(mode)
    if mode == "Combo" then
        return self.Menu.combo.useE:Value(), self.Menu.combo.eMinStacks:Value()
    end
    if mode == "Harass" then
        return self.Menu.harass.useE:Value(), self.Menu.harass.eMinStacks:Value()
    end
    return false, 99
end

function Varus:FindEKillTarget()
    if not self.Menu.ks.useE:Value() or not Ready(_E) then return nil, nil end

    local requiredHit = self:GetERequiredHitChance()
    local bestTarget, bestPos = nil, nil

    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy, E_RANGE) then
            local castPos, hitChance = self:GetEPredictedCastPosition(enemy)
            if castPos and hitChance >= requiredHit then
                local stacks = GetBlightStacks(enemy)
                local totalDamage = self:GetEDamage(enemy) + self:GetBlightDetonationDamage(enemy, stacks)
                if totalDamage >= enemy.health then
                    if not bestTarget or enemy.health < bestTarget.health then
                        bestTarget = enemy
                        bestPos = castPos
                    end
                end
            end
        end
    end

    return bestTarget, bestPos
end

function Varus:FindEStackTarget(mode)
    if mode == "Harass" then return nil, nil end
    local enabled, minStacks = self:GetEModeSettings(mode)
    if not enabled or not Ready(_E) or HasQBuff() then return nil, nil end
    if not self:CanUseAnotherDetonator("E", false) then return nil, nil end

    local requiredHit = self:GetERequiredHitChance()
    local bestTarget, bestPos, bestStacks = nil, nil, 0

    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy, E_RANGE) then
            local stacks = GetBlightStacks(enemy)
            if stacks >= minStacks then
                local castPos, hitChance = self:GetEPredictedCastPosition(enemy)
                if castPos and hitChance >= requiredHit then
                    if not bestTarget or stacks > bestStacks or (stacks == bestStacks and enemy.health < bestTarget.health) then
                        bestTarget = enemy
                        bestPos = castPos
                        bestStacks = stacks
                    end
                end
            end
        end
    end

    return bestTarget, bestPos
end

function Varus:FindHarassETarget()
    if not Ready(_E) or HasQBuff() then return nil, nil end
    if not self.Menu.harass.useE:Value() then return nil, nil end

    local requiredHit = self:GetERequiredHitChance()
    local target = self:GetTarget(E_RANGE)
    if not target then return nil, nil end

    local castPos, hitChance = self:GetEPredictedCastPosition(target)
    if castPos and hitChance >= requiredHit then
        return target, castPos
    end
    return nil, nil
end

function Varus:TryCastE(mode)
    local ksTarget, ksPos = self:FindEKillTarget()
    if ksTarget and ksPos then
        Control.CastSpell(HK_E, ksPos)
        self:RegisterDetonatorCast("E")
        self.drawTarget = ksTarget
        return true
    end

    if mode == "Harass" then
        local harassTarget, harassPos = self:FindHarassETarget()
        if harassTarget and harassPos then
            Control.CastSpell(HK_E, harassPos)
            self.drawTarget = harassTarget
            return true
        end
        return false
    end

    local target, castPos = self:FindEStackTarget(mode)
    if target and castPos then
        Control.CastSpell(HK_E, castPos)
        self:RegisterDetonatorCast("E")
        self.drawTarget = target
        return true
    end

    return false
end

function Varus:ClearRFollowup()
    self.rFollowupTarget = nil
    self.rFollowupReadyTime = 0
    self.rFollowupExpireTime = 0
end

function Varus:HasActiveRFollowup()
    if not self.rFollowupTarget then return false end
    local now = GameTimer()
    if now > self.rFollowupExpireTime then
        self:ClearRFollowup()
        return false
    end
    if not IsValid(self.rFollowupTarget) then
        self:ClearRFollowup()
        return false
    end
    return true
end

function Varus:HandleRFollowup(mode)
    if not self:HasActiveRFollowup() then return false end

    local now = GameTimer()
    local target = self.rFollowupTarget
    self.drawTarget = target

    if now < self.rFollowupReadyTime then
        return true
    end

    local stacks = GetBlightStacks(target)
    if stacks <= 0 and now > self.rFollowupReadyTime + 0.75 then
        self:ClearRFollowup()
        return false
    end

    local eEnabled, eMinStacks = self:GetEModeSettings(mode)
    local qEnabled, qMinStacks = self:GetModeSettings(mode)
    local canUseE = eEnabled and Ready(_E) and stacks >= eMinStacks and Dist(myHero, target) <= E_RANGE
    local canUseQ = qEnabled and Ready(_Q) and myHero:GetSpellData(_W).level > 0 and stacks >= qMinStacks and Dist(myHero, target) <= Q_MAX_RANGE

    if canUseE then
        local ksPos = nil
        local totalDamage = self:GetEDamage(target) + self:GetBlightDetonationDamage(target, stacks)
        local castPos, hitChance = self:GetEPredictedCastPosition(target)
        if castPos and hitChance >= self:GetERequiredHitChance() then
            ksPos = castPos
        end

        if totalDamage >= target.health and ksPos then
            Control.CastSpell(HK_E, ksPos)
            self:RegisterDetonatorCast("E")
            self:ClearRFollowup()
            return true
        end
    end

    if canUseQ then
        self:StartQCharge(target, true)
        self:ClearRFollowup()
        return true
    end

    if canUseE then
        local castPos, hitChance = self:GetEPredictedCastPosition(target)
        if castPos and hitChance >= self:GetERequiredHitChance() then
            Control.CastSpell(HK_E, castPos)
            self:RegisterDetonatorCast("E")
            self:ClearRFollowup()
            return true
        end
    end

    if not canUseE and not canUseQ and now > self.rFollowupReadyTime + 1.25 then
        self:ClearRFollowup()
        return false
    end

    return true
end

function Varus:TryRAntiDash()
    if not self.Menu.rlogic.useAntiDash:Value() or not self:CanCastR() then return false end

    local requiredHit = math_min(self:GetRRequiredHitChance(), 3)
    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy, R_RANGE) and enemy.pathing and enemy.pathing.isDashing then
            local endPos = enemy.pathing.endPos or enemy.posTo or enemy.pos
            local threateningDash = endPos and Dist(myHero, endPos) <= self.Menu.rlogic.antiMeleeRange:Value() + 100
            local castPos, hitChance = self:GetRPredictedCastPosition(enemy)
            if threateningDash and castPos and hitChance >= requiredHit then
                return self:CastRAtTarget(enemy, castPos)
            end
        end
    end
    return false
end

function Varus:TryRAntiMelee()
    if not self.Menu.rlogic.useAntiMelee:Value() or not self:CanCastR() then return false end

    local requiredHit = math_min(self:GetRRequiredHitChance(), 3)
    local antiMeleeRange = self.Menu.rlogic.antiMeleeRange:Value()
    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy, antiMeleeRange + 50) then
            local isMelee = (enemy.range or 0) <= 325
            local distance = Dist(myHero, enemy)
            local pathing = enemy.pathing
            local closingIn = false
            if pathing and pathing.hasMovePath then
                local endPos = pathing.endPos or enemy.posTo
                if endPos and Dist(myHero, endPos) <= distance then
                    closingIn = true
                end
            end

            if isMelee and distance <= antiMeleeRange and (closingIn or distance <= antiMeleeRange - 40) then
                local castPos, hitChance = self:GetRPredictedCastPosition(enemy)
                if castPos and hitChance >= requiredHit then
                    return self:CastRAtTarget(enemy, castPos)
                end
                if enemy.pos then
                    return self:CastRAtTarget(enemy, enemy.pos)
                end
            end
        end
    end
    return false
end

function Varus:TryCastR(mode)
    if self:TryRAntiDash() then return true end
    if self:TryRAntiMelee() then return true end
    return false
end

function Varus:FindStackTarget(mode, range)
    local enabled, minStacks = self:GetModeSettings(mode)
    if not enabled or myHero:GetSpellData(_W).level == 0 then
        return nil, nil, 0, 0
    end

    local bestTarget, bestPos, bestStacks = nil, nil, 0
    local requiredHit = self.Menu.pred.qHitChance:Value()

    for i = 1, GameHeroCount() do
        local enemy = GameHero(i)
        if IsValidTarget(enemy, range) then
            local stacks = GetBlightStacks(enemy)
            if stacks >= minStacks then
                local castPos, hitChance = self:GetPredictedCastPosition(enemy, range)
                if castPos and hitChance >= requiredHit and Dist(myHero, castPos) <= range then
                    if not bestTarget or stacks > bestStacks or (stacks == bestStacks and enemy.health < bestTarget.health) then
                        bestTarget = enemy
                        bestPos = castPos
                        bestStacks = stacks
                    end
                end
            end
        end
    end

    return bestTarget, bestPos, bestStacks, 0
end

function Varus:GetReleaseFallbackTarget(mode, range, chargeTime)
    local ksTarget, ksCastPos, _, ksUseW = self:FindQKillTarget(range, chargeTime, true)
    if ksTarget then
        return ksTarget, ksCastPos or ksTarget.pos, ksUseW
    end

    if mode == "Harass" then
        local harassTarget = self:GetTarget(range)
        if harassTarget then
            local harassCastPos, hitChance = self:GetPredictedCastPosition(harassTarget, range)
            if harassCastPos and hitChance >= self.Menu.pred.qHitChance:Value() then
                return harassTarget, harassCastPos, false
            end
            if Dist(myHero, harassTarget) <= range then
                return harassTarget, harassTarget.pos, false
            end
        end
    end

    local stackTarget, stackCastPos = self:FindStackTarget(mode, range)
    if stackTarget then
        return stackTarget, stackCastPos or stackTarget.pos, true
    end

    if self.qReleaseTarget and IsValidTarget(self.qReleaseTarget, range) then
        return self.qReleaseTarget, self.qReleasePos or self.qReleaseTarget.pos, self.wUsedThisCharge
    end

    return nil, nil, false
end

function Varus:StartQCharge(target, ignoreLockout)
    if not Ready(_Q) or HasQBuff() then return false end
    if not self:CanUseAnotherDetonator("Q", ignoreLockout) then return false end
    if GameTimer() - self.lastQStartAttempt < 0.20 then return false end
    self.lastQStartAttempt = GameTimer()
    self.qReleaseTarget = target
    self.qReleasePos = nil
    self.qChargeStart = GameTimer()
    self.wCastTime = 0
    self.wUsedThisCharge = false
    Control.KeyDown(HK_Q)
    return true
end

function Varus:HandleChargedQ(mode)
    local now = GameTimer()
    if self.qChargeStart <= 0 then
        self.qChargeStart = now
    end

    local chargeTime = math_max(0, now - self.qChargeStart)
    local currentRange = GetCurrentQRange(chargeTime)
    local target, castPos, wantW = nil, nil, false

    if mode == "Harass" then
        target = self:GetTarget(currentRange)
        if target then
            local hitChance = 0
            castPos, hitChance = self:GetPredictedCastPosition(target, currentRange)
            if not (castPos and hitChance >= self.Menu.pred.qHitChance:Value()) then
                castPos = nil
            end
        end
    else
        target, castPos = self:FindStackTarget(mode, currentRange)
        wantW = true
    end

    local ksTarget, ksCastPos, _, ksUseW = self:FindQKillTarget(currentRange, chargeTime, true)
    if ksTarget and ksCastPos then
        target = ksTarget
        castPos = ksCastPos
        wantW = ksUseW
    end
    self.drawTarget = target

    if mode == "Harass" and chargeTime < Q_CHARGE_TIME then
        if target then
            self.qReleaseTarget = target
            self.qReleasePos = castPos or target.pos
        end
        return
    end

    if chargeTime >= Q_CHARGE_TIME then
        local fallbackTarget, fallbackPos, fallbackWantW = self:GetReleaseFallbackTarget(mode, currentRange, chargeTime)
        if not target and fallbackTarget then
            target = fallbackTarget
            castPos = fallbackPos
            wantW = fallbackWantW
            self.drawTarget = target
        elseif target and not castPos then
            castPos = fallbackPos or (target and target.pos) or nil
            if fallbackTarget == target then
                wantW = fallbackWantW
            end
        end
    end

    if not target or not castPos then
        if chargeTime >= Q_MAX_HOLD then
            Control.KeyUp(HK_Q)
            self.qChargeStart = 0
            self.qReleaseTarget = nil
            self.qReleasePos = nil
            self.wUsedThisCharge = false
        end
        return
    end

    if Dist(myHero, castPos) > currentRange then
        if chargeTime >= Q_CHARGE_TIME and target and target.pos and Dist(myHero, target.pos) <= currentRange then
            castPos = target.pos
        else
            return
        end
    end

    self.qReleaseTarget = target
    self.qReleasePos = castPos

    if wantW and not self.wUsedThisCharge and Ready(_W) then
        Control.KeyDown(HK_W)
        Control.KeyUp(HK_W)
        self.wCastTime = now
        self.wUsedThisCharge = true
        return
    end

    if wantW and self.wUsedThisCharge and (now - self.wCastTime) < Q_RELEASE_W_DELAY then
        return
    end

    Control.CastSpell(HK_Q, castPos)
    self:RegisterDetonatorCast("Q")
    self.qChargeStart = 0
    self.qReleaseTarget = nil
    self.qReleasePos = nil
    self.wUsedThisCharge = false
end

function Varus:OnTick()
    if MyHeroNotReady() then return end

    local mode = GetMode()
    if mode ~= "Combo" and mode ~= "Harass" then
        self.drawTarget = nil
        self:ClearRFollowup()
        if not HasQBuff() then
            self.qChargeStart = 0
            self.qReleaseTarget = nil
            self.qReleasePos = nil
            self.wUsedThisCharge = false
        end
        return
    end

    if HasQBuff() then
        self:HandleChargedQ(mode)
        return
    end

    if self:HandleRFollowup(mode) then
        return
    end

    if self:TryCastR(mode) then
        return
    end

    if self:TryCastE(mode) then
        return
    end

    if not Ready(_Q) then
        self.drawTarget = nil
        return
    end

    local ksTarget = self:FindQKillTarget(Q_MAX_RANGE, Q_CHARGE_TIME, true)
    if ksTarget then
        self:StartQCharge(ksTarget, true)
        self.drawTarget = ksTarget
        return
    end

    if mode == "Harass" then
        local harassTarget = self:GetTarget(Q_MAX_RANGE)
        self.drawTarget = harassTarget
        if harassTarget then
            self:StartQCharge(harassTarget, true)
        end
        return
    end

    if not Ready(_W) or myHero:GetSpellData(_W).level == 0 then
        self.drawTarget = nil
        return
    end

    local target = self:GetTarget(Q_MAX_RANGE)
    self.drawTarget = target
    if not target then return end

    local stackTarget = self:FindStackTarget(mode, Q_MAX_RANGE)
    if stackTarget then
        self:StartQCharge(stackTarget)
    end
end

function Varus:OnDraw()
    if not self.Menu then return end

    if self.Menu.draw.drawRange:Value() and Draw and Draw.Circle then
        Draw.Circle(myHero.pos, Q_MAX_RANGE, 1, Draw.Color(80, 180, 120, 255))
    end

    if self.Menu.draw.showTarget:Value() and self.drawTarget and IsValid(self.drawTarget) then
        Draw.Circle(self.drawTarget.pos, 90, 2, Draw.Color(160, 255, 80, 80))
    end
end

if not _G.DepressiveVarusInstance then
    _G.DepressiveVarusInstance = Varus:Create()
end
