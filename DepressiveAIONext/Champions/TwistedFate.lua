if _G.__DEPRESSIVE_NEXT_TWISTEDFATE_LOADED then return end
if myHero.charName ~= "TwistedFate" then return end

local VERSION = 1.9

pcall(function()
    if not _G.DepressivePrediction then
        require("DepressivePrediction")
    end
end)

local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - TEAM_ALLY
local TEAM_JUNGLE = _G.TEAM_JUNGLE or 300

local GameCanUseSpell = Game.CanUseSpell
local GameHeroCount = Game.HeroCount
local GameHero = Game.Hero
local GameMinionCount = Game.MinionCount
local GameMinion = Game.Minion
local GameTimer = Game.Timer
local GameIsChatOpen = Game.IsChatOpen

local MathHuge = math.huge
local MathMax = math.max
local MathMin = math.min
local MathSqrt = math.sqrt

local CARD_NONE = "NONE"
local CARD_BLUE = "BLUE"
local CARD_RED = "RED"
local CARD_GOLD = "GOLD"

local W_SPELL_READY = "PickACard"
local CARD_LOCK_NAMES = {
    [CARD_BLUE] = "BlueCardLock",
    [CARD_RED] = "RedCardLock",
    [CARD_GOLD] = "GoldCardLock"
}

local HARD_CC_TYPES = {
    [5] = true,
    [8] = true,
    [10] = true,
    [11] = true,
    [12] = true,
    [22] = true,
    [23] = true,
    [24] = true,
    [25] = true,
    [29] = true,
    [30] = true,
    [35] = true
}

local SPELL_Q = {
    range = 1450,
    speed = 1000,
    delay = 0.25,
    width = 40
}

local function GetZ(pos)
    return pos.z or pos.y or 0
end

local function DistanceSqr(a, b)
    local dx = a.x - b.x
    local dz = GetZ(a) - GetZ(b)
    return dx * dx + dz * dz
end

local function Distance(a, b)
    return MathSqrt(DistanceSqr(a, b))
end

local function To3D(pos)
    return Vector(pos.x, myHero.pos.y, GetZ(pos))
end

local function IsValid(unit)
    return unit and unit.valid and not unit.dead and unit.health > 0 and unit.isTargetable
end

local function Ready(slot)
    local spellData = myHero:GetSpellData(slot)
    return spellData and spellData.level > 0 and spellData.currentCd == 0 and GameCanUseSpell(slot) == 0
end

local function ManaPercent()
    if myHero.maxMana <= 0 then
        return 100
    end
    return myHero.mana / myHero.maxMana * 100
end

local function IsUnitInRange(from, unit, range)
    return unit and DistanceSqr(from, unit.pos) <= range * range
end

local function IsPointInRange(from, point, range)
    return point and DistanceSqr(from, point) <= range * range
end

local function PointSegmentDistanceSqr(point, segStart, segEnd)
    local sx = segStart.x
    local sz = GetZ(segStart)
    local ex = segEnd.x
    local ez = GetZ(segEnd)
    local px = point.x
    local pz = GetZ(point)

    local abx = ex - sx
    local abz = ez - sz
    local abLenSqr = abx * abx + abz * abz
    if abLenSqr == 0 then
        local dx = px - sx
        local dz = pz - sz
        return dx * dx + dz * dz
    end

    local apx = px - sx
    local apz = pz - sz
    local t = (apx * abx + apz * abz) / abLenSqr
    t = MathMax(0, MathMin(1, t))

    local cx = sx + abx * t
    local cz = sz + abz * t
    local dx = px - cx
    local dz = pz - cz
    return dx * dx + dz * dz
end

local function HasBuff(unit, buffName)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name and buff.name:lower():find(buffName:lower()) then
            return true
        end
    end
    return false
end

local function IsImmobile(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and HARD_CC_TYPES[buff.type] then
            return true
        end
    end
    return false
end

local TwistedFate = {}
TwistedFate.__index = TwistedFate

function TwistedFate.new()
    local self = setmetatable({}, TwistedFate)
    self:__init()
    return self
end

function TwistedFate:__init()
    self.lastQCast = 0
    self.lastWStart = 0
    self.lastWLock = 0
    self.lastAttackOrder = 0
    self.lastAttackTarget = nil
    self.forceTargetExpire = 0
    self.desiredCard = CARD_NONE
    self.currentCard = CARD_NONE
    self.cycleCard = CARD_NONE
    self.isCycling = false
    self.forceTarget = nil
    self.redPreviewTarget = nil
    self.redPreviewCount = 0
    self.orbAttackEnabled = true
    self.qPrediction = nil
    self.prediction = _G.DepressivePrediction

    self:LoadMenu()

    Callback.Add("Tick", function() self:OnTick() end)
    Callback.Add("Draw", function() self:OnDraw() end)
    Callback.Add("UnLoad", function() self:OnUnload() end)
end

function TwistedFate:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "DepressiveTwistedFate", name = "Depressive Twisted Fate v" .. tostring(VERSION)})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. tostring(VERSION)}})

    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.combo:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.combo:MenuElement({id = "pickRange", name = "Pre-pick range", value = 175, min = 0, max = 350, step = 25})
    self.Menu.combo:MenuElement({id = "blueMana", name = "Use Blue below mana %", value = 25, min = 0, max = 100, step = 5})

    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.harass:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.harass:MenuElement({id = "mana", name = "Min mana %", value = 45, min = 0, max = 100, step = 5})
    self.Menu.harass:MenuElement({id = "pickRange", name = "Pre-pick range", value = 150, min = 0, max = 300, step = 25})

    self.Menu:MenuElement({type = MENU, id = "clear", name = "Lane Clear"})
    self.Menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
    self.Menu.clear:MenuElement({id = "qMana", name = "Min mana % for Q", value = 35, min = 0, max = 100, step = 5})
    self.Menu.clear:MenuElement({id = "qMin", name = "Min minions for Q", value = 3, min = 1, max = 7, step = 1})
    self.Menu.clear:MenuElement({id = "useW", name = "Use W", value = true})
    self.Menu.clear:MenuElement({id = "blueMana", name = "Use Blue below mana %", value = 35, min = 0, max = 100, step = 5})
    self.Menu.clear:MenuElement({id = "redMin", name = "Use Red if it hits", value = 3, min = 2, max = 7, step = 1})
    self.Menu.clear:MenuElement({id = "redRadius", name = "Red splash radius", value = 200, min = 150, max = 275, step = 5})
    self.Menu.clear:MenuElement({id = "useBlueFallback", name = "Fallback to Blue on single target", value = true})
    self.Menu.clear:MenuElement({id = "jungleBlue", name = "Use Blue on jungle", value = true})

    self.Menu:MenuElement({type = MENU, id = "misc", name = "Misc"})
    self.Menu.misc:MenuElement({id = "autoQCC", name = "Auto Q on CC", value = true})
    self.Menu.misc:MenuElement({id = "goldAfterR", name = "Force Gold after R", value = true})
    self.Menu.misc:MenuElement({id = "blockAttackWhilePicking", name = "Block attacks while picking", value = true})

    self.Menu:MenuElement({type = MENU, id = "keys", name = "Manual Cards"})
    self.Menu.keys:MenuElement({id = "gold", name = "Gold card key", key = string.byte("U")})
    self.Menu.keys:MenuElement({id = "red", name = "Red card key", key = string.byte("I")})
    self.Menu.keys:MenuElement({id = "blue", name = "Blue card key", key = string.byte("O")})

    self.Menu:MenuElement({type = MENU, id = "draw", name = "Draw"})
    self.Menu.draw:MenuElement({id = "qRange", name = "Draw Q range", value = true})
    self.Menu.draw:MenuElement({id = "redPreview", name = "Draw red clear target", value = true})
    self.Menu.draw:MenuElement({id = "cardText", name = "Draw card status", value = true})
end

function TwistedFate:OnUnload()
    self:ClearForceTarget()
    self:SetOrbAttackEnabled(true)
end

function TwistedFate:OnTick()
    if myHero.dead or GameIsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) then
        self:ClearForceTarget()
        self:SetOrbAttackEnabled(true)
        return
    end

    self.prediction = self.prediction or _G.DepressivePrediction
    self:UpdateCardState()
    self:HandleManualCardKeys()
    self:HandleGoldAfterR()
    if self:TryLockDesiredCard() then
        self:UpdateCardState()
    end
    self:UpdateRedPreview()

    local mode = self:GetMode()
    local usedForcedTarget = false

    if mode == "Combo" then
        usedForcedTarget = self:HandleCombo()
    elseif mode == "Harass" then
        usedForcedTarget = self:HandleHarass()
    elseif mode == "Clear" then
        usedForcedTarget = self:HandleClear()
    end

    if self:TryLockDesiredCard() then
        self:UpdateCardState()
    end

    if not usedForcedTarget and GameTimer() > self.forceTargetExpire then
        self:ClearForceTarget()
    end

    self:TryStartCardCycle()
    if self:IsQEnabledForMode(mode) then
        self:AutoQOnCC()
    end
    self:UpdateOrbAttackBlock()
end

function TwistedFate:OnDraw()
    if myHero.dead then return end

    if self.Menu.draw.qRange:Value() and Ready(_Q) then
        Draw.Circle(myHero.pos, SPELL_Q.range, Draw.Color(90, 255, 200, 40))
    end

    if self.Menu.draw.redPreview:Value() and self.redPreviewTarget and IsValid(self.redPreviewTarget) then
        local splashRadius = self:GetRedCardRadius()
        Draw.Circle(self.redPreviewTarget.pos, splashRadius, Draw.Color(120, 255, 80, 80))
        local screenPos = self.redPreviewTarget.pos:To2D()
        if screenPos.onScreen then
            Draw.Text("Red: " .. tostring(self.redPreviewCount), 16, screenPos.x - 24, screenPos.y - 32, Draw.Color(255, 255, 220, 120))
        end
    end

    if self.Menu.draw.cardText:Value() then
        local text = "Card: NONE"
        if self.currentCard ~= CARD_NONE then
            text = "Card: " .. self.currentCard
        elseif self.cycleCard ~= CARD_NONE and self.desiredCard ~= CARD_NONE then
            text = "Card: Locking " .. self.desiredCard
        elseif self.desiredCard ~= CARD_NONE then
            text = "Card: Picking " .. self.desiredCard
        elseif self.cycleCard ~= CARD_NONE then
            text = "Card: " .. self.cycleCard .. " (cycle)"
        end
        local pos2D = myHero.pos:To2D()
        Draw.Text(text, 16, pos2D.x - 55, pos2D.y - 65, Draw.Color(255, 255, 255, 255))
    end
end

function TwistedFate:GetMode()
    if _G.SDK and _G.SDK.Orbwalker then
        local modes = _G.SDK.Orbwalker.Modes
        if modes[_G.SDK.ORBWALKER_MODE_COMBO] then return "Combo" end
        if modes[_G.SDK.ORBWALKER_MODE_HARASS] then return "Harass" end
        if modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or modes[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then return "Clear" end
    end
    return "None"
end

function TwistedFate:IsQEnabledForMode(mode)
    if mode == "Combo" then
        return self.Menu.combo.useQ:Value()
    end
    if mode == "Harass" then
        return self.Menu.harass.useQ:Value()
    end
    if mode == "Clear" then
        return self.Menu.clear.useQ:Value()
    end
    return true
end

function TwistedFate:IsWEnabledForMode(mode)
    if mode == "Combo" then
        return self.Menu.combo.useW:Value()
    end
    if mode == "Harass" then
        return self.Menu.harass.useW:Value()
    end
    if mode == "Clear" then
        return self.Menu.clear.useW:Value()
    end
    return true
end

function TwistedFate:GetEnemyHeroes(range)
    local result = {}
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero and hero.team == TEAM_ENEMY and IsValid(hero) and (not range or IsUnitInRange(myHero.pos, hero, range)) then
            result[#result + 1] = hero
        end
    end
    return result
end

function TwistedFate:GetLaneMinions(range)
    local result = {}
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and minion.team == TEAM_ENEMY and IsValid(minion) and (not range or IsUnitInRange(myHero.pos, minion, range)) then
            result[#result + 1] = minion
        end
    end
    return result
end

function TwistedFate:GetJungleMinions(range)
    local result = {}
    for i = 1, GameMinionCount() do
        local minion = GameMinion(i)
        if minion and minion.team == TEAM_JUNGLE and IsValid(minion) and (not range or IsUnitInRange(myHero.pos, minion, range)) then
            result[#result + 1] = minion
        end
    end
    return result
end

function TwistedFate:GetTarget(range)
    if _G.SDK and _G.SDK.TargetSelector then
        local ok, target = pcall(_G.SDK.TargetSelector.GetTarget, _G.SDK.TargetSelector, range, _G.SDK.DAMAGE_TYPE_MAGICAL)
        if ok and target and IsValid(target) then
            return target
        end

        ok, target = pcall(_G.SDK.TargetSelector.GetTarget, _G.SDK.TargetSelector, range)
        if ok and target and IsValid(target) then
            return target
        end
    end

    local bestTarget = nil
    local bestDistance = MathHuge
    local enemies = self:GetEnemyHeroes(range)
    for i = 1, #enemies do
        local enemy = enemies[i]
        local dist = DistanceSqr(myHero.pos, enemy.pos)
        if dist < bestDistance then
            bestDistance = dist
            bestTarget = enemy
        end
    end
    return bestTarget
end

function TwistedFate:GetCardAttackRange(target)
    local myRadius = myHero.boundingRadius or 0
    local targetRadius = target and target.boundingRadius or 0
    return myHero.range + myRadius + targetRadius + 25
end

function TwistedFate:GetRedCardRadius()
    return self.Menu.clear.redRadius:Value() + 25
end

function TwistedFate:IsInCardRange(target, extraRange)
    if not target then return false end
    return Distance(myHero.pos, target.pos) <= self:GetCardAttackRange(target) + (extraRange or 0)
end

function TwistedFate:GetWName()
    local spellData = myHero:GetSpellData(_W)
    return spellData and spellData.name or ""
end

function TwistedFate:GetLockedCard()
    local wName = self:GetWName()
    if wName == CARD_LOCK_NAMES[CARD_BLUE] then return CARD_BLUE end
    if wName == CARD_LOCK_NAMES[CARD_RED] then return CARD_RED end
    if wName == CARD_LOCK_NAMES[CARD_GOLD] then return CARD_GOLD end
    return CARD_NONE
end

function TwistedFate:UpdateCardState()
    local spellData = myHero:GetSpellData(_W)
    local wName = spellData and spellData.name or ""
    local shownCard = CARD_NONE

    if wName == CARD_LOCK_NAMES[CARD_BLUE] then
        shownCard = CARD_BLUE
    elseif wName == CARD_LOCK_NAMES[CARD_RED] then
        shownCard = CARD_RED
    elseif wName == CARD_LOCK_NAMES[CARD_GOLD] then
        shownCard = CARD_GOLD
    end

    self.currentCard = shownCard ~= CARD_NONE and self.desiredCard == CARD_NONE and shownCard or CARD_NONE
    self.cycleCard = shownCard ~= CARD_NONE and self.desiredCard ~= CARD_NONE and shownCard or CARD_NONE
    self.isCycling = self.cycleCard ~= CARD_NONE

    if self.currentCard ~= CARD_NONE then
        self.desiredCard = CARD_NONE
    end

    if self.currentCard == CARD_NONE and self.forceTarget and GameTimer() > self.forceTargetExpire then
        self:ClearForceTarget()
    end
end

function TwistedFate:HandleManualCardKeys()
    if self.Menu.keys.gold:Value() then
        self:RequestCard(CARD_GOLD)
    elseif self.Menu.keys.red:Value() then
        self:RequestCard(CARD_RED)
    elseif self.Menu.keys.blue:Value() then
        self:RequestCard(CARD_BLUE)
    end
end

function TwistedFate:HandleGoldAfterR()
    if self.Menu.misc.goldAfterR:Value() and HasBuff(myHero, "Gate") then
        self:RequestCard(CARD_GOLD)
    end
end

function TwistedFate:RequestCard(card)
    if not card or card == CARD_NONE then return end
    if self.currentCard == card then return end
    self.desiredCard = card

    if not Ready(_W) then
        return
    end

    local wName = self:GetWName()
    if wName == CARD_LOCK_NAMES[card] and GameTimer() - self.lastWLock >= 0.01 then
        Control.CastSpell(HK_W)
        self.lastWLock = GameTimer()
        self.desiredCard = CARD_NONE
        return
    end

    if self.currentCard == CARD_NONE and wName == W_SPELL_READY and GameTimer() - self.lastWStart >= 0.40 then
        Control.CastSpell(HK_W)
        self.lastWStart = GameTimer()
    end
end

function TwistedFate:TryStartCardCycle()
    if self.desiredCard == CARD_NONE then return false end
    if not Ready(_W) then return false end
    if self.currentCard ~= CARD_NONE then return false end
    if self:GetWName() ~= W_SPELL_READY then return false end
    if GameTimer() - self.lastWStart < 0.40 then return false end

    Control.CastSpell(HK_W)
    self.lastWStart = GameTimer()
    return true
end

function TwistedFate:TryLockDesiredCard()
    if self.desiredCard == CARD_NONE then return false end
    if not Ready(_W) then return false end
    if self:GetWName() ~= CARD_LOCK_NAMES[self.desiredCard] then return false end
    if GameTimer() - self.lastWLock < 0.01 then return false end

    Control.CastSpell(HK_W)
    self.lastWLock = GameTimer()
    self.desiredCard = CARD_NONE
    return true
end

function TwistedFate:SetForceTarget(target)
    self.forceTarget = target
    if _G.SDK and _G.SDK.Orbwalker then
        _G.SDK.Orbwalker.ForceTarget = target
    end
end

function TwistedFate:ClearForceTarget()
    self.forceTarget = nil
    self.lastAttackTarget = nil
    if _G.SDK and _G.SDK.Orbwalker then
        _G.SDK.Orbwalker.ForceTarget = nil
    end
end

function TwistedFate:SetOrbAttackEnabled(enabled)
    if self.orbAttackEnabled == enabled then
        return
    end
    if _G.SDK and _G.SDK.Orbwalker then
        _G.SDK.Orbwalker:SetAttack(enabled)
    end
    self.orbAttackEnabled = enabled
end

function TwistedFate:UpdateOrbAttackBlock()
    local shouldBlock = self.Menu.misc.blockAttackWhilePicking:Value()
        and (
            (self.desiredCard ~= CARD_NONE and self.currentCard == CARD_NONE and (GameTimer() - self.lastWStart) <= 1.5)
            or self.isCycling
        )

    self:SetOrbAttackEnabled(not shouldBlock)
end

function TwistedFate:IssueCardAttack(target, extraRange)
    if not target or not IsValid(target) then return false end
    if not self:IsInCardRange(target, extraRange or 0) then return false end

    self:SetOrbAttackEnabled(true)
    self:SetForceTarget(target)
    self.forceTargetExpire = GameTimer() + 0.75

    local targetChanged = self.lastAttackTarget ~= target.networkID
    local canAttackNow = false
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.CanAttack then
        local ok, result = pcall(function()
            return _G.SDK.Orbwalker:CanAttack()
        end)
        canAttackNow = ok and result or false
    end

    if targetChanged or canAttackNow or GameTimer() - self.lastAttackOrder > 0.80 then
        Control.Attack(target)
        self.lastAttackOrder = GameTimer()
        self.lastAttackTarget = target.networkID
    end

    return true
end

function TwistedFate:EnsureQPrediction()
    if self.qPrediction or not self.prediction then
        return
    end

    self.qPrediction = self.prediction.SpellPrediction({
        Type = self.prediction.SPELLTYPE_LINE,
        Speed = SPELL_Q.speed,
        Range = SPELL_Q.range,
        Delay = SPELL_Q.delay,
        Radius = SPELL_Q.width,
        Collision = false,
        UseBoundingRadius = true
    })
end

function TwistedFate:GetQCastPosition(target, minHitChance)
    if not target or not IsValid(target) then return nil end

    self:EnsureQPrediction()
    if self.qPrediction then
        local result = self.qPrediction:GetPrediction(target, myHero)
        if result and result.CastPosition and (result.HitChance or 0) >= minHitChance then
            return To3D(result.CastPosition)
        end
    end

    if target.GetPrediction then
        local ok, prediction = pcall(target.GetPrediction, target, SPELL_Q.speed, SPELL_Q.delay)
        if ok and prediction then
            return To3D(prediction)
        end
    end

    return To3D(target.pos)
end

function TwistedFate:CastQPos(pos)
    if not pos or not Ready(_Q) then return false end
    if GameTimer() - self.lastQCast < 0.25 then return false end
    if not IsPointInRange(myHero.pos, pos, SPELL_Q.range) then return false end

    Control.CastSpell(HK_Q, To3D(pos))
    self.lastQCast = GameTimer()
    return true
end

function TwistedFate:CastQ(target, minHitChance)
    if not target or not Ready(_Q) then return false end
    if not IsUnitInRange(myHero.pos, target, SPELL_Q.range) then
        return false
    end

    local requiredHitChance = minHitChance or (self.prediction and self.prediction.HITCHANCE_HIGH) or 4
    local castPos = self:GetQCastPosition(target, requiredHitChance)
    if not castPos then return false end

    return self:CastQPos(castPos)
end

function TwistedFate:GetBestRedCardTarget(minions)
    local bestTarget = nil
    local bestCount = 0
    local bestDistance = MathHuge
    local splashRadius = self:GetRedCardRadius()
    local splashRadiusSqr = splashRadius * splashRadius

    for i = 1, #minions do
        local centerMinion = minions[i]
        if self:IsInCardRange(centerMinion, 10) then
            local count = 0
            for j = 1, #minions do
                local otherMinion = minions[j]
                if DistanceSqr(centerMinion.pos, otherMinion.pos) <= splashRadiusSqr then
                    count = count + 1
                end
            end

            local distanceToMe = DistanceSqr(myHero.pos, centerMinion.pos)
            if count > bestCount or (count == bestCount and distanceToMe < bestDistance) then
                bestCount = count
                bestDistance = distanceToMe
                bestTarget = centerMinion
            end
        end
    end

    return bestTarget, bestCount
end

function TwistedFate:GetBestSingleFarmTarget(laneMinions, jungleMinions)
    local bestTarget = nil
    local bestHealth = -1
    local bestDistance = MathHuge

    local function consider(unit)
        if self:IsInCardRange(unit, 10) then
            local health = unit.maxHealth or unit.health or 0
            local dist = DistanceSqr(myHero.pos, unit.pos)
            if health > bestHealth or (health == bestHealth and dist < bestDistance) then
                bestHealth = health
                bestDistance = dist
                bestTarget = unit
            end
        end
    end

    for i = 1, #laneMinions do
        consider(laneMinions[i])
    end

    for i = 1, #jungleMinions do
        consider(jungleMinions[i])
    end

    return bestTarget
end

function TwistedFate:GetBestQFarmCast(minions)
    local bestPos = nil
    local bestCount = 0

    for i = 1, #minions do
        local candidate = minions[i]
        if IsPointInRange(myHero.pos, candidate.pos, SPELL_Q.range) then
            local count = 0

            for j = 1, #minions do
                local other = minions[j]
                local radius = SPELL_Q.width + (other.boundingRadius or 0)
                if PointSegmentDistanceSqr(other.pos, myHero.pos, candidate.pos) <= radius * radius then
                    count = count + 1
                end
            end

            if count > bestCount then
                bestCount = count
                bestPos = candidate.pos
            end
        end
    end

    return bestPos and To3D(bestPos) or nil, bestCount
end

function TwistedFate:UpdateRedPreview()
    local laneMinions = self:GetLaneMinions(self:GetCardAttackRange(nil) + 50)
    self.redPreviewTarget, self.redPreviewCount = self:GetBestRedCardTarget(laneMinions)
end

function TwistedFate:AutoQOnCC()
    if not self.Menu.misc.autoQCC:Value() then return false end
    if not Ready(_Q) then return false end

    local enemies = self:GetEnemyHeroes(SPELL_Q.range)
    for i = 1, #enemies do
        local enemy = enemies[i]
        if IsImmobile(enemy) then
            local hitChance = (self.prediction and self.prediction.HITCHANCE_NORMAL) or 3
            return self:CastQ(enemy, hitChance)
        end
    end

    return false
end

function TwistedFate:HandleCombo()
    local allowComboW = self:IsWEnabledForMode("Combo")
    local qTarget = self:GetTarget(SPELL_Q.range)
    local aaTarget = self:GetTarget(self:GetCardAttackRange(nil) + self.Menu.combo.pickRange:Value())
    local usedForcedTarget = false

    if allowComboW and self.currentCard ~= CARD_NONE and aaTarget then
        usedForcedTarget = self:IssueCardAttack(aaTarget, self.Menu.combo.pickRange:Value())
    end

    if allowComboW and self.currentCard == CARD_NONE and aaTarget then
        if ManaPercent() <= self.Menu.combo.blueMana:Value() then
            self:RequestCard(CARD_BLUE)
        else
            self:RequestCard(CARD_GOLD)
        end
    end

    if self.Menu.combo.useQ:Value() and qTarget then
        local shouldHoldQ = allowComboW and aaTarget and self.currentCard == CARD_NONE
        if not shouldHoldQ then
            self:CastQ(qTarget)
        end
    end

    return usedForcedTarget
end

function TwistedFate:HandleHarass()
    if ManaPercent() < self.Menu.harass.mana:Value() then
        return false
    end

    local allowHarassW = self:IsWEnabledForMode("Harass")
    local qTarget = self:GetTarget(SPELL_Q.range)
    local aaSearchRange = self:GetCardAttackRange(nil) + MathMax(self.Menu.harass.pickRange:Value(), 250)
    local aaTarget = self:GetTarget(aaSearchRange)
    local usedForcedTarget = false

    if allowHarassW and self.currentCard ~= CARD_NONE and aaTarget then
        usedForcedTarget = self:IssueCardAttack(aaTarget, self.Menu.harass.pickRange:Value())
    end

    if allowHarassW and self.currentCard == CARD_NONE and aaTarget then
        self:RequestCard(CARD_BLUE)
    end

    local shouldUseHarassQ = self.Menu.harass.useQ:Value() and qTarget and (not allowHarassW or self.currentCard ~= CARD_NONE or not aaTarget)
    if shouldUseHarassQ then
        self:CastQ(qTarget)
    end

    return usedForcedTarget
end

function TwistedFate:HandleClear()
    local laneMinionsAA = self:GetLaneMinions(self:GetCardAttackRange(nil) + 25)
    local allowClearQ = self.Menu.clear.useQ:Value()
    local allowClearW = self:IsWEnabledForMode("Clear")
    local laneMinionsQ = allowClearQ and self:GetLaneMinions(SPELL_Q.range) or {}
    local jungleMinionsAA = allowClearW and self.Menu.clear.jungleBlue:Value() and self:GetJungleMinions(self:GetCardAttackRange(nil) + 25) or {}
    local usedForcedTarget = false
    local requestedCard = false

    local bestRedTarget, bestRedCount = self:GetBestRedCardTarget(laneMinionsAA)
    self.redPreviewTarget = bestRedTarget
    self.redPreviewCount = bestRedCount

    if allowClearW and self.currentCard == CARD_RED and bestRedTarget then
        usedForcedTarget = self:IssueCardAttack(bestRedTarget, 10)
    elseif allowClearW and (self.currentCard == CARD_BLUE or self.currentCard == CARD_GOLD) then
        local blueTarget = self:GetBestSingleFarmTarget(laneMinionsAA, jungleMinionsAA)
        if blueTarget then
            usedForcedTarget = self:IssueCardAttack(blueTarget, 10)
        end
    end

    if allowClearW and self.currentCard == CARD_NONE then
        if ManaPercent() <= self.Menu.clear.blueMana:Value() then
            local blueTarget = self:GetBestSingleFarmTarget(laneMinionsAA, jungleMinionsAA)
            if blueTarget then
                self:RequestCard(CARD_BLUE)
                requestedCard = true
            end
        elseif bestRedTarget and bestRedCount >= self.Menu.clear.redMin:Value() then
            self:RequestCard(CARD_RED)
            requestedCard = true
        elseif self.Menu.clear.useBlueFallback:Value() then
            local blueTarget = self:GetBestSingleFarmTarget(laneMinionsAA, jungleMinionsAA)
            if blueTarget then
                self:RequestCard(CARD_BLUE)
                requestedCard = true
            end
        end
    end

    local cardClearActive = allowClearW and (usedForcedTarget or requestedCard or self.currentCard ~= CARD_NONE or self.desiredCard ~= CARD_NONE or self.isCycling)
    if not cardClearActive and allowClearQ and Ready(_Q) and ManaPercent() >= self.Menu.clear.qMana:Value() then
        local bestPos, bestCount = self:GetBestQFarmCast(laneMinionsQ)
        if bestPos and bestCount >= self.Menu.clear.qMin:Value() then
            self:CastQPos(bestPos)
        end
    end

    return usedForcedTarget
end

local function SafeInitTwistedFate()
    if _G.__DEPRESSIVE_NEXT_TWISTEDFATE_LOADED then
        return true
    end

    if not MenuElement then
        return false
    end

    local ok, obj = pcall(TwistedFate.new)
    if not ok or not obj then
        if print then
            print("[Depressive - TwistedFate] Init error: " .. tostring(obj))
        end
        return false
    end

    _G.DepressiveTwistedFate = obj
    _G.__DEPRESSIVE_NEXT_TWISTEDFATE_LOADED = true
    _G.DepressiveAIONextLoadedChampion = true

    if print then
        print("[Depressive - TwistedFate] v" .. tostring(VERSION) .. " Initialized")
    end

    return true
end

if not SafeInitTwistedFate() then
    local retries = 0
    local retryId
    retryId = Callback.Add("Tick", function()
        if _G.__DEPRESSIVE_NEXT_TWISTEDFATE_LOADED then
            Callback.Del("Tick", retryId)
            return
        end

        if SafeInitTwistedFate() then
            Callback.Del("Tick", retryId)
            return
        end

        retries = retries + 1
        if retries > 120 then
            if print then
                print("[Depressive - TwistedFate] Failed to init after retries")
            end
            Callback.Del("Tick", retryId)
        end
    end)
end
