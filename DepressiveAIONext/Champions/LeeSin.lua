-- DepressiveAIONext compatibility guard
if _G.__DEPRESSIVE_NEXT_LEESIN_FINAL_LOADED then return end
_G.__DEPRESSIVE_NEXT_LEESIN_FINAL_LOADED = true

local VERSION = "5.3"
local NAME = "DepressiveLeeSin"

-- Hero validation
if myHero.charName ~= "LeeSin" then return end

--------------------------------------------------------------------------------
-- LOCALIZED FUNCTIONS (Performance optimization)
--------------------------------------------------------------------------------
local math_sqrt = math.sqrt
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_huge = math.huge
local math_floor = math.floor

local table_insert = table.insert
local table_sort = table.sort

local pairs = pairs
local ipairs = ipairs

local Game = _G.Game
local Control = _G.Control
local Draw = _G.Draw
local Callback = _G.Callback
local GameTimer = Game.Timer
local GameHeroCount = Game.HeroCount
local GameMinionCount = Game.MinionCount
local GameWardCount = Game.WardCount
local GameTurretCount = Game.TurretCount
local GameHero = Game.Hero
local GameMinion = Game.Minion
local GameWard = Game.Ward
local GameTurret = Game.Turret
local GameCanUseSpell = Game.CanUseSpell
local ControlSetCursorPos = Control.SetCursorPos

if not GameTimer then
    error(NAME .. ": Game.Timer unavailable")
end

--------------------------------------------------------------------------------
-- SPELL SLOT CONSTANTS
--------------------------------------------------------------------------------
local _Q, _W, _E, _R = 0, 1, 2, 3

--------------------------------------------------------------------------------
-- LOAD PREDICTION SYSTEM
--------------------------------------------------------------------------------
require("DepressivePrediction")
local Pred = nil
local PredictionLoaded = false

DelayAction(function()
    if _G.DepressivePrediction then
        Pred = _G.DepressivePrediction
        PredictionLoaded = true
    end
end, 0.5)

--------------------------------------------------------------------------------
-- SPELL DATA
--------------------------------------------------------------------------------
local SpellData = {
    Q = {
        Range = 1200,
        Speed = 1800,
        Delay = 0.25,
        Radius = 60,
        Collision = true
    },
    W = { 
        Range = 700,
        JumpSpeed = 1400
    },
    E = { 
        Range = 350,
        Radius = 350
    },
    R = { 
        Range = 375,
        KickDistance = 700,
        KickWidth = 180,
        CastTime = 0.25
    },
    Flash = { 
        Range = 400
    },
    Smite = {
        Range = 500
    }
}

--------------------------------------------------------------------------------
-- STATE MANAGEMENT
--------------------------------------------------------------------------------
local State = {
    LastCast = 0,
    LastWardPlace = 0,
    LastWardPos = nil,
    
    -- Auto MultiKick (from normal combo)
    AutoMultiKick = {
        Active = false,
        WardJumpTime = 0,
        Target = nil
    },

    -- Extended Insec (Dynamic Q)
    Insec = {
        Active = false,
        PendingRCast = false,
        RCastDelayUntil = 0,
        RCastExpireTime = 0,
        RLastAttempt = 0,
        Step = 0,
        Target = nil,
        QTarget = nil,
        InsecMethod = nil,
        StartTime = 0,
        LastAction = 0,
        WardJumpTime = 0,
        Q2CastTime = 0
    }
}

local LastInsecKeyState = false

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
local function Now()
    return GameTimer()
end

local function IsValid(unit)
    return unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable and unit.health > 0
end

local function GetDistanceSq(p1, p2)
    local dx = p1.x - p2.x
    local dz = (p1.z or p1.y) - (p2.z or p2.y)
    return dx * dx + dz * dz
end

local function GetDistance(p1, p2)
    return math_sqrt(GetDistanceSq(p1, p2))
end

local function ExtendVec(from, to, dist)
    local dx = to.x - from.x
    local dz = (to.z or to.y) - (from.z or from.y)
    local len = math_sqrt(dx * dx + dz * dz)
    if len < 1 then return {x = from.x, z = from.z or from.y} end
    local scale = dist / len
    return {x = from.x + dx * scale, z = (from.z or from.y) + dz * scale}
end

local function NormalizeVec(from, to)
    local dx = to.x - from.x
    local dz = (to.z or to.y) - (from.z or from.y)
    local len = math_sqrt(dx * dx + dz * dz)
    if len < 1 then return {x = 0, z = 0} end
    return {x = dx / len, z = dz / len}
end

local function EnergyPercent()
    return (myHero.mana / myHero.maxMana) * 100
end

local function HealthPercent(unit)
    unit = unit or myHero
    return (unit.health / unit.maxHealth) * 100
end

--------------------------------------------------------------------------------
-- BUFF SYSTEM
--------------------------------------------------------------------------------
local function HasBuff(unit, buffName)
    if not unit or not buffName or not unit.buffCount then return false end
    buffName = buffName:lower()
    for i = 0, unit.buffCount - 1 do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name and buff.name:lower():find(buffName) then
            return true
        end
    end
    return false
end

local function GetBuffStacks(unit, buffName)
    if not unit or not buffName or not unit.buffCount then return 0 end
    buffName = buffName:lower()
    for i = 0, unit.buffCount - 1 do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 and buff.name and buff.name:lower():find(buffName) then
            return buff.count
        end
    end
    return 0
end

local function HasPassive()
    return GetBuffStacks(myHero, "LeeSinPassiveBuff") > 0
end

local QMarkBuffNames = {"blindmonkqone", "leesinqone", "blindmonkqprimed", "leesinq2"}

local function HasQMark(target)
    if not target or not IsValid(target) then return false end
    for i = 1, #QMarkBuffNames do
        if HasBuff(target, QMarkBuffNames[i]) then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- SPELL STATE DETECTION
--------------------------------------------------------------------------------
local function GetSpellName(slot)
    local data = myHero:GetSpellData(slot)
    return data and data.name or ""
end

local function SpellNameMatches(name, patterns)
    for i = 1, #patterns do
        if name:find(patterns[i]) then
            return true
        end
    end
    return false
end

local Q1SpellNames = {"blindmonkqone", "leesinq1", "qone"}
local Q2SpellNames = {"blindmonkqtwo", "leesinq2", "qtwo"}
local W1SpellNames = {"blindmonkwone", "safeguard", "leesinw1", "wone"}
local W2SpellNames = {"blindmonkwtwo", "ironwill", "leesinw2", "wtwo"}
local E1SpellNames = {"blindmonkeone", "tempest", "leesine1", "eone"}
local E2SpellNames = {"blindmonketwo", "cripple", "leesine2", "etwo"}

local function IsReady(slot)
    local data = myHero:GetSpellData(slot)
    if not data or data.level == 0 then return false end
    return data.currentCd == 0 and data.mana <= myHero.mana and GameCanUseSpell(slot) == 0
end

local function HasQ1()
    local name = GetSpellName(_Q):lower()
    return SpellNameMatches(name, Q1SpellNames)
end

local function HasQ2()
    local name = GetSpellName(_Q):lower()
    return SpellNameMatches(name, Q2SpellNames)
end

local function HasW1()
    local name = GetSpellName(_W):lower()
    return SpellNameMatches(name, W1SpellNames)
end

local function HasW2()
    local name = GetSpellName(_W):lower()
    return SpellNameMatches(name, W2SpellNames)
end

local function HasE1()
    local name = GetSpellName(_E):lower()
    return SpellNameMatches(name, E1SpellNames)
end

local function HasE2()
    local name = GetSpellName(_E):lower()
    return SpellNameMatches(name, E2SpellNames)
end

--------------------------------------------------------------------------------
-- ITEM & WARD SYSTEM
--------------------------------------------------------------------------------
local ItemSlotMap = {
    [6] = ITEM_1, [7] = ITEM_2, [8] = ITEM_3,
    [9] = ITEM_4, [10] = ITEM_5, [11] = ITEM_6, [12] = ITEM_7
}

local ItemHotkeyMap = {
    [ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2, [ITEM_3] = HK_ITEM_3,
    [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6,
    [ITEM_7] = HK_ITEM_7
}

local WardItems = {
    [805306368] = true, [3690987520] = true, [3340] = true, [2055] = true,
    [3850] = true, [3851] = true, [3853] = true, [3854] = true, [3855] = true,
    [3857] = true, [3858] = true, [3859] = true, [3860] = true, [3862] = true,
    [3863] = true, [3864] = true, [4638] = true, [4641] = true, [4643] = true,
    [32758] = true, [2056] = true, [2057] = true
}

local function GetWardSlot()
    -- Check trinket slot first (slot 12 / ITEM_7)
    local trinketData = myHero:GetItemData(12)
    if trinketData and trinketData.itemID then
        local sd = myHero:GetSpellData(ITEM_7)
        if sd and (sd.currentCd == nil or sd.currentCd == 0) then
            if GameCanUseSpell(ITEM_7) == 0 then
                return ITEM_7, HK_ITEM_7
            end
        end
    end
    
    -- Check other slots
    for raw = 6, 11 do
        local data = myHero:GetItemData(raw)
        if data and WardItems[data.itemID] then
            local slotConst = ItemSlotMap[raw]
            if slotConst then
                local sd = myHero:GetSpellData(slotConst)
                if sd and (sd.currentCd == nil or sd.currentCd == 0) then
                    local charges = data.stackCount or data.stacks or data.ammo or 1
                    if charges > 0 and GameCanUseSpell(slotConst) == 0 then
                        return slotConst, ItemHotkeyMap[slotConst]
                    end
                end
            end
        end
    end
    
    return nil, nil
end

local function HasWard()
    local slot, _ = GetWardSlot()
    return slot ~= nil
end

--------------------------------------------------------------------------------
-- FLASH SYSTEM
--------------------------------------------------------------------------------
local function GetFlashSlot()
    local spell1 = myHero:GetSpellData(SUMMONER_1)
    local spell2 = myHero:GetSpellData(SUMMONER_2)
    
    if spell1 and spell1.name and spell1.name:find("SummonerFlash") then
        return SUMMONER_1, HK_SUMMONER_1
    end
    if spell2 and spell2.name and spell2.name:find("SummonerFlash") then
        return SUMMONER_2, HK_SUMMONER_2
    end
    return nil, nil
end

local function IsFlashReady()
    local slot, _ = GetFlashSlot()
    if not slot then return false end
    local sd = myHero:GetSpellData(slot)
    return sd and sd.currentCd == 0
end

local function CastFlash(pos)
    local _, hotkey = GetFlashSlot()
    if not hotkey then return false end
    Control.CastSpell(hotkey, pos)
    return true
end

--------------------------------------------------------------------------------
-- SMITE DETECTION (using correct spell names)
--------------------------------------------------------------------------------
local SmiteNames = {
    basic = { "SummonerSmite" },
    unleashed = { "S5_SummonerSmiteDuel", "S5_SummonerSmitePlayerGanker" },
    primal = { "SummonerSmiteAvatarOffensive", "SummonerSmiteAvatarUtility", "SummonerSmiteAvatarDefensive" }
}

local function IsSmiteName(name)
    if not name or name == "" then return false end
    for _, n in ipairs(SmiteNames.basic) do if name == n then return true end end
    for _, n in ipairs(SmiteNames.unleashed) do if name == n then return true end end
    for _, n in ipairs(SmiteNames.primal) do if name == n then return true end end
    return false
end

local function GetSmiteSlot()
    local spell1 = myHero:GetSpellData(SUMMONER_1)
    local spell2 = myHero:GetSpellData(SUMMONER_2)
    
    if spell1 and spell1.name and IsSmiteName(spell1.name) then
        return SUMMONER_1, HK_SUMMONER_1
    end
    if spell2 and spell2.name and IsSmiteName(spell2.name) then
        return SUMMONER_2, HK_SUMMONER_2
    end
    return nil, nil
end

local function IsSmiteReady()
    local slot, _ = GetSmiteSlot()
    if not slot then return false end
    local sd = myHero:GetSpellData(slot)
    if not sd then return false end
    
    -- Check ammo (smite has charges, need at least 1)
    local ammo = sd.ammo or 0
    if ammo < 1 then return false end
    
    -- Check if spell is usable
    return Game.CanUseSpell(slot) == 0
end

local function CastSmite(target)
    -- Verify target is still valid before attempting to cast
    if not target or not IsValid(target) then
        return false
    end
    
    local summ1 = myHero:GetSpellData(SUMMONER_1)
    local summ2 = myHero:GetSpellData(SUMMONER_2)
    
    -- Check SUMMONER_1
    if summ1 and IsSmiteName(summ1.name) and (summ1.ammo or 0) >= 1 and Game.CanUseSpell(SUMMONER_1) == 0 then
        Control.CastSpell(HK_SUMMONER_1, target)
        return true
    end
    
    -- Check SUMMONER_2
    if summ2 and IsSmiteName(summ2.name) and (summ2.ammo or 0) >= 1 and Game.CanUseSpell(SUMMONER_2) == 0 then
        Control.CastSpell(HK_SUMMONER_2, target)
        return true
    end
    
    return false
end

--------------------------------------------------------------------------------
-- TARGET SELECTION
--------------------------------------------------------------------------------
local HeroCache = {
    Enemies = {},
    Allies = {},
    Ready = false
}

local function RefreshHeroCache()
    local enemies = {}
    local allies = {}
    for i = 1, GameHeroCount() do
        local hero = GameHero(i)
        if hero and IsValid(hero) then
            if hero.team == myHero.team then
                if hero.networkID ~= myHero.networkID then
                    allies[#allies + 1] = hero
                end
            else
                enemies[#enemies + 1] = hero
            end
        end
    end
    HeroCache.Enemies = enemies
    HeroCache.Allies = allies
    HeroCache.Ready = true
end

local function GetEnemyHeroes()
    if not HeroCache.Ready then
        RefreshHeroCache()
    end
    return HeroCache.Enemies
end

local function GetAllyHeroes()
    if not HeroCache.Ready then
        RefreshHeroCache()
    end
    return HeroCache.Allies
end

local function GetClosestEnemy(range, from)
    from = from or myHero.pos
    local best, bestDistSq = nil, range * range
    for _, enemy in ipairs(GetEnemyHeroes()) do
        local distSq = GetDistanceSq(from, enemy.pos)
        if distSq < bestDistSq then
            best = enemy
            bestDistSq = distSq
        end
    end
    return best
end

local function GetClosestEnemyToMouse(range)
    return GetClosestEnemy(range, mousePos)
end

local function GetClosestAlly(pos)
    pos = pos or myHero.pos
    local best, bestDist = nil, math_huge
    for _, ally in ipairs(GetAllyHeroes()) do
        local dist = GetDistance(pos, ally.pos)
        if dist < bestDist then
            best = ally
            bestDist = dist
        end
    end
    return best
end

local function GetClosestAllyTurret(pos)
    pos = pos or myHero.pos
    if not GameTurretCount then return nil end
    local best, bestDist = nil, math_huge
    for i = 1, GameTurretCount() do
        local turret = GameTurret(i)
        if turret and turret.team == myHero.team and IsValid(turret) then
            local dist = GetDistance(pos, turret.pos)
            if dist < bestDist then
                best = turret
                bestDist = dist
            end
        end
    end
    return best
end

--------------------------------------------------------------------------------
-- DAMAGE CALCULATION
--------------------------------------------------------------------------------
local function GetQDamage(target)
    if not target then return 0 end
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end
    local bonusAD = (myHero.totalDamage or 0) - (myHero.baseDamage or 0)
    -- Q1 damage
    local q1Damage = ({55, 80, 105, 130, 155})[level] + (bonusAD * 1.0)
    -- Q2 damage (same base + bonus for missing HP, simplified as +50% for low HP targets)
    local q2Damage = ({55, 80, 105, 130, 155})[level] + (bonusAD * 1.0)
    -- Q2 bonus damage based on missing HP (up to 100% more)
    local missingHPPercent = 1 - (target.health / target.maxHealth)
    q2Damage = q2Damage * (1 + missingHPPercent)
    return q1Damage + q2Damage
end

local function GetEDamage(target)
    if not target then return 0 end
    local level = myHero:GetSpellData(_E).level
    if level == 0 then return 0 end
    local bonusAD = (myHero.totalDamage or 0) - (myHero.baseDamage or 0)
    return ({100, 130, 160, 190, 220})[level] + (bonusAD * 1.0)
end

local function GetRDamage(target)
    if not target then return 0 end
    local level = myHero:GetSpellData(_R).level
    if level == 0 then return 0 end
    
    -- Base damage: 175 / 400 / 625
    local baseDamage = ({175, 400, 625})[level]
    
    -- Bonus AD scaling: 200% bonus AD
    local bonusAD = (myHero.totalDamage or 0) - (myHero.baseDamage or 0)
    local adDamage = bonusAD * 2.0
    
    -- Bonus Health damage: 12% / 15% / 18% of target's bonus health
    local bonusHealthPercent = ({0.12, 0.15, 0.18})[level]
    local targetBonusHealth = (target.maxHealth or 0) - (target.baseHealth or target.maxHealth * 0.4)
    if targetBonusHealth < 0 then targetBonusHealth = 0 end
    local healthDamage = targetBonusHealth * bonusHealthPercent
    
    return baseDamage + adDamage + healthDamage
end

local function CanKillWithR(target)
    return target and GetRDamage(target) >= target.health
end

--------------------------------------------------------------------------------
-- COLLISION HELPERS (for Smite + Q combo)
--------------------------------------------------------------------------------
-- Calculate distance from point to line segment
local function PointToLineDistance(point, lineStart, lineEnd)
    local dx = lineEnd.x - lineStart.x
    local dz = lineEnd.z - lineStart.z
    local lineLenSq = dx * dx + dz * dz
    
    if lineLenSq == 0 then
        return GetDistance(point, lineStart)
    end
    
    local t = math_max(0, math_min(1, ((point.x - lineStart.x) * dx + (point.z - lineStart.z) * dz) / lineLenSq))
    local projX = lineStart.x + t * dx
    local projZ = lineStart.z + t * dz
    
    return GetDistance(point, {x = projX, z = projZ})
end

-- Find minion/monster blocking the path between two points
-- Returns: closestMinion, totalBlockingCount
local function FindBlockingMinion(fromPos, toPos)
    local bestMinion = nil
    local bestDist = math_huge
    local totalDist = GetDistance(fromPos, toPos)
    local blockingCount = 0
    
    -- Helper function to check if a unit is blocking
    local function CheckUnit(unit)
        if not unit or not IsValid(unit) then return end
        if unit.team == myHero.team then return end -- Skip allies
        if unit.isHero then return end -- Skip heroes (we want to hit them!)
        
        local unitPos = {x = unit.pos.x, z = unit.pos.z}
        local distFromSource = GetDistance(fromPos, unitPos)
        local distToTarget = GetDistance(unitPos, toPos)
        
        -- Check if unit is actually between source and target
        if distFromSource < totalDist and distToTarget < totalDist then
            local distToLine = PointToLineDistance(unitPos, fromPos, toPos)
            -- Use larger radius for jungle monsters
            local unitRadius = unit.boundingRadius or 65
            if unit.team == 300 then
                unitRadius = math_max(unitRadius, 100) -- Jungle monsters are bigger
            end
            local collisionRadius = SpellData.Q.Radius + unitRadius
            
            if distToLine <= collisionRadius then
                blockingCount = blockingCount + 1
                if distFromSource < bestDist then
                    bestDist = distFromSource
                    bestMinion = unit
                end
            end
        end
    end
    
    -- Check minions (includes lane minions and jungle monsters)
    if GameMinionCount then
        for i = 1, GameMinionCount() do
            CheckUnit(GameMinion(i))
        end
    end
    
    -- Also check using Object Manager if available
    if ObjectManager and ObjectManager.Get then
        local enemies = ObjectManager:Get("enemy", "minions")
        if enemies then
            for _, obj in pairs(enemies) do
                if obj and obj.unit then
                    CheckUnit(obj.unit)
                end
            end
        end
        
        local neutrals = ObjectManager:Get("neutral", "minions") 
        if neutrals then
            for _, obj in pairs(neutrals) do
                if obj and obj.unit then
                    CheckUnit(obj.unit)
                end
            end
        end
    end
    
    return bestMinion, blockingCount
end

--------------------------------------------------------------------------------
-- CAST FUNCTIONS
--------------------------------------------------------------------------------
local function SetCastDelay(seconds)
    State.LastCast = Now() + seconds
end

local function CastQ1(target)
    if not IsReady(_Q) or not HasQ1() or not target then return false end
    if GetDistance(myHero.pos, target.pos) > SpellData.Q.Range then return false end
    
    local castPos = nil
    local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
    local predPos = nil
    
    -- Get predicted position
    if Pred and Pred.GetPrediction then
        local unitPos, pPos, timeToHit = Pred.GetPrediction(
            target, sourcePos2D,
            SpellData.Q.Speed, SpellData.Q.Delay, SpellData.Q.Radius
        )
        
        if pPos and pPos.x and pPos.z then
            predPos = pPos
        else
            return false
        end
    else
        predPos = {x = target.pos.x, z = target.pos.z}
    end
    
    -- Check for blocking minions (returns closest minion and total count)
    local blockingMinion, blockingCount = FindBlockingMinion(sourcePos2D, predPos)
    
    if blockingMinion then
        -- There's a minion blocking - check if we can Smite through
        -- Only try Smite+Q if there's exactly 1 minion blocking
        -- Default to true if menu doesn't exist yet (first load)
        local useSmiteQ = true
        if Menu and Menu.Combo and Menu.Combo.UseSmiteQ then
            useSmiteQ = Menu.Combo.UseSmiteQ:Value()
        end
        local smiteReady = IsSmiteReady()
        
        if blockingCount == 1 and useSmiteQ and smiteReady then
            local minionDist = GetDistance(myHero.pos, blockingMinion.pos)
            if minionDist <= SpellData.Smite.Range then
                -- Smite the minion first, then cast Q after delay
                local smiteResult = CastSmite(blockingMinion)
                if smiteResult then
                    local finalCastPos = Vector(predPos.x, target.pos.y, predPos.z)
                    DelayAction(function()
                        if IsReady(_Q) and HasQ1() and IsValid(target) then
                            Control.CastSpell(HK_Q, finalCastPos)
                        end
                    end, 0.10)
                    SetCastDelay(0.35)
                    return true
                end
            end
        end
        -- Can't smite (multiple minions, no smite, or minion too far), don't cast Q
        return false
    end
    
    -- No collision, cast Q normally
    castPos = Vector(predPos.x, target.pos.y, predPos.z)
    Control.CastSpell(HK_Q, castPos)
    SetCastDelay(0.25)
    return true
end

local function CastQ2()
    if not IsReady(_Q) or not HasQ2() then return false end
    Control.CastSpell(HK_Q)
    SetCastDelay(0.1)
    return true
end

local function CastW(target)
    if not IsReady(_W) or not HasW1() then return false end
    target = target or myHero
    Control.CastSpell(HK_W, target.pos or target)
    SetCastDelay(0.1)
    return true
end

local function CastE()
    if not IsReady(_E) then return false end
    Control.CastSpell(HK_E)
    SetCastDelay(0.1)
    return true
end

local function CastR(target)
    if not IsReady(_R) or not target then return false end
    if GetDistance(myHero.pos, target.pos) > SpellData.R.Range + 50 then return false end
    Control.CastSpell(HK_R, target)
    SetCastDelay(0.25)
    return true
end

--------------------------------------------------------------------------------
-- INSEC POSITION CALCULATION
--------------------------------------------------------------------------------
local Menu = nil

local function GetInsecTarget(target)
    if not Menu then return nil end
    local mode = Menu.Insec.Mode:Value()
    
    if mode == 1 then
        return GetClosestAlly(target.pos) or GetClosestAllyTurret(target.pos) or {pos = myHero.pos}
    elseif mode == 2 then
        return GetClosestAllyTurret(target.pos) or GetClosestAlly(target.pos) or {pos = myHero.pos}
    else
        return {pos = mousePos}
    end
end

local function GetInsecPosition(target)
    local insecTarget = GetInsecTarget(target)
    if not insecTarget then return nil, nil end
    
    local kickDir = NormalizeVec(target.pos, insecTarget.pos)
    local behindPos = {
        x = target.pos.x - kickDir.x * 180,
        z = target.pos.z - kickDir.z * 180
    }
    return behindPos, insecTarget
end

local function ResetExtendedInsecState()
    local I = State.Insec
    I.Active = false
    I.PendingRCast = false
    I.RCastDelayUntil = 0
    I.RCastExpireTime = 0
    I.RLastAttempt = 0
    I.Step = 0
    I.Target = nil
    I.QTarget = nil
    I.InsecMethod = nil
    I.StartTime = 0
    I.LastAction = 0
    I.WardJumpTime = 0
    I.Q2CastTime = 0
end

local function StartExtendedInsec(target)
    if not target or not IsValid(target) then return false end

    local I = State.Insec
    I.Active = true
    I.PendingRCast = false
    I.RCastDelayUntil = 0
    I.RCastExpireTime = 0
    I.RLastAttempt = 0
    I.Step = 0
    I.Target = target
    I.QTarget = nil
    I.InsecMethod = nil
    I.StartTime = Now()
    I.LastAction = 0
    I.WardJumpTime = 0
    I.Q2CastTime = 0
    return true
end

local function FollowCursorToUnit(unit)
    if not ControlSetCursorPos or not unit or not IsValid(unit) or not unit.pos then return end

    local pos2D = unit.pos:To2D()
    if pos2D and pos2D.onScreen then
        pcall(function()
            ControlSetCursorPos(pos2D.x, pos2D.y)
        end)
    end
end

local InsecRCastConfirmNames = {"blindmonkrkick", "dragonrage", "leesinr", "blindmonkr"}

local function HasConfirmedExtendedInsecR()
    local activeSpell = myHero.activeSpell
    local activeName = activeSpell and activeSpell.valid and activeSpell.name and activeSpell.name:lower() or ""
    if activeName ~= "" and SpellNameMatches(activeName, InsecRCastConfirmNames) then
        return true
    end

    local rData = myHero:GetSpellData(_R)
    if not rData or rData.level == 0 then return false end
    return rData.currentCd > 0
end

local function BeginExtendedInsecRCast(delay, alreadyAttempted)
    local I = State.Insec
    local now = Now()
    I.PendingRCast = true
    I.RCastDelayUntil = now + (delay or 0)
    I.RCastExpireTime = I.RCastDelayUntil + 0.45
    I.RLastAttempt = alreadyAttempted and now or 0
end

local function UpdateExtendedInsecRCast()
    local I = State.Insec
    if not I.PendingRCast then return end
    if not I.Target or not IsValid(I.Target) then
        ResetExtendedInsecState()
        return
    end

    if HasConfirmedExtendedInsecR() then
        I.PendingRCast = false
        return
    end

    local now = Now()
    if now < I.RCastDelayUntil then return end
    if now > I.RCastExpireTime then
        I.PendingRCast = false
        return
    end
    if not IsReady(_R) then return end
    if now - I.RLastAttempt < 0.05 then return end
    if GetDistance(myHero.pos, I.Target.pos) > SpellData.R.Range + 100 then return end

    Control.CastSpell(HK_R, I.Target)
    I.RLastAttempt = now
end

--------------------------------------------------------------------------------
-- WARD JUMP SYSTEM (Core function for insec)
--------------------------------------------------------------------------------
local WARD_JUMP_RETRY_COUNT = 3
local WARD_JUMP_RETRY_DELAY = 0.15

local function FindNearestJumpableUnit(pos, maxDist)
    maxDist = maxDist or 400
    local best, bestDist = nil, maxDist
    local myPos = myHero.pos
    
    -- Wards - priority for wards
    if GameWardCount then
        for i = 1, GameWardCount() do
            local ward = GameWard(i)
            if ward and ward.isAlly and IsValid(ward) then
                local distToPos = GetDistance(pos, ward.pos)
                local distToMe = GetDistance(myPos, ward.pos)
                if distToMe <= SpellData.W.Range and distToPos < bestDist then
                    best = ward
                    bestDist = distToPos
                end
            end
        end
    end
    
    -- If we found a ward close enough, use it
    if best and bestDist < 350 then
        return best, bestDist
    end
    
    -- Ally heroes
    for _, ally in ipairs(GetAllyHeroes()) do
        local distToPos = GetDistance(pos, ally.pos)
        local distToMe = GetDistance(myPos, ally.pos)
        if distToMe <= SpellData.W.Range and distToPos < bestDist then
            best = ally
            bestDist = distToPos
        end
    end
    
    -- Ally minions
    if GameMinionCount then
        for i = 1, GameMinionCount() do
            local minion = GameMinion(i)
            if minion and minion.team == myHero.team and IsValid(minion) then
                local distToPos = GetDistance(pos, minion.pos)
                local distToMe = GetDistance(myPos, minion.pos)
                if distToMe <= SpellData.W.Range and distToPos < bestDist then
                    best = minion
                    bestDist = distToPos
                end
            end
        end
    end
    
    return best, bestDist
end

-- Find any ward we can jump to (regardless of target position)
local function FindAnyWardInRange()
    if not GameWardCount then return nil end
    local myPos = myHero.pos
    local best, bestDist = nil, SpellData.W.Range
    
    for i = 1, GameWardCount() do
        local ward = GameWard(i)
        if ward and ward.isAlly and IsValid(ward) then
            local dist = GetDistance(myPos, ward.pos)
            if dist <= SpellData.W.Range and dist < bestDist then
                best = ward
                bestDist = dist
            end
        end
    end
    return best
end

-- Main WardJumpTo function - used for all insec ward jumps
local function WardJumpTo(pos)
    if not pos then return false end
    if not IsReady(_W) or not HasW1() then return false end
    
    local myPos = myHero.pos
    local dist = GetDistance(myPos, pos)
    
    -- Check if we're already at position
    if dist <= 100 then return false end
    
    -- Clamp to W range
    local jumpPos = pos
    if dist > SpellData.W.Range - 50 then
        jumpPos = ExtendVec(myPos, pos, SpellData.W.Range - 50)
    end
    
    -- 1. Check for existing ward near target position
    if GameWardCount then
        local bestWard = nil
        local bestDist = 400
        for i = 1, GameWardCount() do
            local ward = GameWard(i)
            if ward and ward.isAlly and IsValid(ward) then
                local wardToMe = GetDistance(myPos, ward.pos)
                local wardToTarget = GetDistance(ward.pos, jumpPos)
                if wardToMe <= SpellData.W.Range and wardToTarget < bestDist then
                    bestWard = ward
                    bestDist = wardToTarget
                end
            end
        end
        if bestWard then
            Control.CastSpell(HK_W, bestWard)
            return true
        end
    end
    
    -- 2. Check for ally minions/champions near target
    local existingUnit = FindNearestJumpableUnit(jumpPos, 400)
    if existingUnit then
        local unitDist = GetDistance(myPos, existingUnit.pos)
        if unitDist <= SpellData.W.Range then
            Control.CastSpell(HK_W, existingUnit)
            return true
        end
    end
    
    -- 3. Place ward and jump
    if HasWard() then
        local slot, hotkey = GetWardSlot()
        if slot and hotkey then
            local castPos = Vector(jumpPos.x, myPos.y, jumpPos.z)
            
            -- Place ward first
            Control.CastSpell(hotkey, castPos)
            State.LastWardPlace = Now()
            State.LastWardPos = jumpPos
            
            -- Retry a few times while the ward object becomes jumpable.
            for i = 1, WARD_JUMP_RETRY_COUNT do
                DelayAction(function()
                    if not IsReady(_W) or not HasW1() then return end
                    
                    -- Find the ward
                    local ward = nil
                    if GameWardCount then
                        local closestDist = 600
                        for j = 1, GameWardCount() do
                            local w = GameWard(j)
                            if w and w.isAlly and IsValid(w) then
                                local wDist = GetDistance(jumpPos, w.pos)
                                local meToWard = GetDistance(myHero.pos, w.pos)
                                if meToWard <= SpellData.W.Range and wDist < closestDist then
                                    closestDist = wDist
                                    ward = w
                                end
                            end
                        end
                    end
                    
                    if ward then
                        Control.CastSpell(HK_W, ward)
                    end
                end, WARD_JUMP_RETRY_DELAY * i)
            end
            
            return true
        end
    end
    
    return false
end

local function WardJump()
    if not mousePos then return false end
    return WardJumpTo(mousePos)
end

--------------------------------------------------------------------------------
-- FLASH-R COMBOS
--------------------------------------------------------------------------------
local function CastFlashR(target, flashPos)
    if not IsReady(_R) or not target or not flashPos then return false end
    if not IsFlashReady() then return false end
    
    local distAfterFlash = GetDistance(flashPos, target.pos)
    if distAfterFlash > SpellData.R.Range + 100 then return false end

    local trackInsecR = State.Insec.Active and State.Insec.Target and target.networkID == State.Insec.Target.networkID
    if trackInsecR then
        if not CastFlash(flashPos) then return false end
        BeginExtendedInsecRCast(0.03, false)
        return true
    end
    
    CastFlash(flashPos)
    
    DelayAction(function()
        if IsValid(target) and IsReady(_R) then
            local newDist = GetDistance(myHero.pos, target.pos)
            if newDist <= SpellData.R.Range + 100 then
                Control.CastSpell(HK_R, target)
            end
        end
    end, 0.03)
    
    return true
end

local function CastRFlash(target, flashPos)
    if not IsReady(_R) or not target or not flashPos then return false end
    if GetDistance(myHero.pos, target.pos) > SpellData.R.Range + 50 then return false end
    if not IsFlashReady() then return false end
    
    Control.CastSpell(HK_R, target)
    
    DelayAction(function()
        if IsFlashReady() then
            CastFlash(flashPos)
        end
    end, 0.015)
    
    return true
end

--------------------------------------------------------------------------------
-- Q TARGET FINDER (Dynamic Insec)
--------------------------------------------------------------------------------
local function FindQMarkedUnit()
    for _, enemy in ipairs(GetEnemyHeroes()) do
        if HasQMark(enemy) then return enemy end
    end
    
    if GameMinionCount then
        for i = 1, GameMinionCount() do
            local minion = GameMinion(i)
            if minion and IsValid(minion) and HasQMark(minion) then
                return minion
            end
        end
    end
    return nil
end

local function GetAllQTargets(range)
    range = range or SpellData.Q.Range
    local targets = {}
    local myPos = myHero.pos
    
    -- Enemy heroes
    for _, enemy in ipairs(GetEnemyHeroes()) do
        if GetDistance(myPos, enemy.pos) <= range then
            targets[#targets + 1] = {unit = enemy, type = "hero", priority = 10, pos = enemy.pos}
        end
    end
    
    -- Minions and jungle monsters
    if GameMinionCount then
        for i = 1, GameMinionCount() do
            local minion = GameMinion(i)
            if minion and IsValid(minion) and GetDistance(myPos, minion.pos) <= range then
                if minion.team ~= myHero.team then
                    if minion.team == 300 then
                        targets[#targets + 1] = {unit = minion, type = "jungle", priority = 5, pos = minion.pos}
                    else
                        targets[#targets + 1] = {unit = minion, type = "minion", priority = 3, pos = minion.pos}
                    end
                end
            end
        end
    end
    
    return targets
end

-- Evaluate how good a Q target is for insec
-- IMPORTANT: Lee Sin ends Q2 dash ~50-100 units BEFORE the target, not on top of it
local function EvaluateQTargetForInsec(qTarget, insecTarget, insecPos)
    if not qTarget or not qTarget.unit or not IsValid(qTarget.unit) then return -1, false, "invalid" end
    if not insecTarget or not IsValid(insecTarget) then return -1, false, "no_target" end
    if not insecPos then return -1, false, "no_insec_pos" end
    
    local qUnitPos = qTarget.pos
    local targetPos = insecTarget.pos
    local myPos = myHero.pos
    
    -- Calculate where Lee will actually land after Q2
    -- Lee stops ~65 units before the Q target (his attack range from the unit)
    local Q2_STOP_DISTANCE = 65
    local dirToQUnit = NormalizeVec(myPos, qUnitPos)
    local distToQUnit = GetDistance(myPos, qUnitPos)
    
    -- Lee's landing position after Q2
    local landingPos
    if distToQUnit > Q2_STOP_DISTANCE then
        landingPos = {
            x = qUnitPos.x - dirToQUnit.x * Q2_STOP_DISTANCE,
            z = qUnitPos.z - dirToQUnit.z * Q2_STOP_DISTANCE
        }
    else
        landingPos = qUnitPos -- Very close, will land on target
    end
    
    -- Use landing position for distance calculations
    local distQToInsec = GetDistance(landingPos, insecPos)
    local distQToTarget = GetDistance(landingPos, targetPos)
    
    local hasWard = HasWard() and IsReady(_W) and HasW1()
    local hasFlash = Menu and Menu.Insec.UseFlash:Value() and IsFlashReady()
    
    local score = 0
    local canExecute = false
    local method = "none"
    
    -- Q target IS the insec target (direct insec)
    if qTarget.unit.networkID == insecTarget.networkID then
        if hasWard and hasFlash then
            score = 100 + qTarget.priority
            canExecute = true
            method = "direct_ward_flash"
        elseif hasFlash and distQToInsec <= SpellData.Flash.Range + 50 then
            score = 90 + qTarget.priority
            canExecute = true
            method = "direct_flash"
        elseif hasWard and distQToInsec <= SpellData.W.Range + 50 then
            score = 80 + qTarget.priority
            canExecute = true
            method = "direct_ward"
        end
        return score, canExecute, method
    end
    
    -- Q target is NEAR the insec position
    if distQToInsec <= 300 then
        if distQToTarget <= SpellData.R.Range + 100 then
            score = 150 + qTarget.priority
            canExecute = true
            method = "q_near_insec_direct_r"
        elseif hasFlash and distQToTarget <= SpellData.R.Range + SpellData.Flash.Range then
            score = 140 + qTarget.priority
            canExecute = true
            method = "q_near_insec_flash_r"
        end
        return score, canExecute, method
    end
    
    -- Q target puts us in ward range of insec pos
    if distQToInsec <= SpellData.W.Range + 50 and hasWard then
        local distAfterWardToTarget = GetDistance(insecPos, targetPos)
        if distAfterWardToTarget <= SpellData.R.Range + 50 then
            score = 120 + qTarget.priority
            canExecute = true
            method = "q_then_ward_r"
        elseif hasFlash and distAfterWardToTarget <= SpellData.R.Range + SpellData.Flash.Range then
            score = 110 + qTarget.priority
            canExecute = true
            method = "q_then_ward_flash_r"
        end
        return score, canExecute, method
    end
    
    -- Q target puts us in flash range of insec pos
    if distQToInsec <= SpellData.Flash.Range + 50 and hasFlash then
        local distAfterFlashToTarget = GetDistance(insecPos, targetPos)
        if distAfterFlashToTarget <= SpellData.R.Range + 50 then
            score = 100 + qTarget.priority
            canExecute = true
            method = "q_then_flash_r"
        end
        return score, canExecute, method
    end
    
    -- Q target puts us in combined ward+flash range
    if hasWard and hasFlash then
        local combinedRange = SpellData.W.Range + SpellData.Flash.Range
        if distQToInsec <= combinedRange + 50 then
            score = 70 + qTarget.priority
            canExecute = true
            method = "q_ward_flash_r"
        end
    end
    
    -- Gap close only
    local currentDistToInsec = GetDistance(myPos, insecPos)
    local improvement = currentDistToInsec - distQToInsec
    if improvement > 200 then
        score = improvement / 10 + qTarget.priority
        method = "gap_close"
    end
    
    return score, canExecute, method
end

local function FindBestQTargetForInsec(insecTarget, insecPos)
    if not insecTarget or not insecPos then return nil, 0, "none" end
    
    local qTargets = GetAllQTargets(SpellData.Q.Range)
    local bestTarget, bestScore, bestMethod = nil, 0, "none"
    
    for _, qTarget in ipairs(qTargets) do
        local score, canExecute, method = EvaluateQTargetForInsec(qTarget, insecTarget, insecPos)
        
        if canExecute and score > bestScore then
            bestScore = score
            bestTarget = qTarget
            bestMethod = method
        elseif not bestTarget and score > 0 then
            bestScore = score
            bestTarget = qTarget
            bestMethod = method
        end
    end
    
    return bestTarget, bestScore, bestMethod
end

local function CanQHitTarget(target)
    if not target or not IsValid(target) then return false end
    if GetDistance(myHero.pos, target.pos) > SpellData.Q.Range then return false end
    
    if Pred and Pred.GetCollision then
        local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
        local targetPos2D = {x = target.pos.x, z = target.pos.z}
        
        local hasCollision, _ = Pred.GetCollision(
            sourcePos2D, targetPos2D,
            SpellData.Q.Speed, SpellData.Q.Delay, SpellData.Q.Radius,
            {Pred.COLLISION_MINION}, target.networkID
        )
        return not hasCollision
    end
    return true
end

--------------------------------------------------------------------------------
-- MULTI-KICK DETECTION
--------------------------------------------------------------------------------
local function CountMultiKickHits(target, kickDir, enemies)
    if not target or not IsValid(target) then return 0 end
    enemies = enemies or GetEnemyHeroes()
    if not kickDir then
        kickDir = NormalizeVec(myHero.pos, target.pos)
    end
    
    local hits = 0
    for _, enemy in ipairs(enemies) do
        if enemy.networkID ~= target.networkID and IsValid(enemy) then
            local toEnemy = {x = enemy.pos.x - target.pos.x, z = enemy.pos.z - target.pos.z}
            local proj = kickDir.x * toEnemy.x + kickDir.z * toEnemy.z
            
            if proj > 0 and proj <= SpellData.R.KickDistance then
                local closestX = target.pos.x + kickDir.x * proj
                local closestZ = target.pos.z + kickDir.z * proj
                local perpDist = math_sqrt((enemy.pos.x - closestX)^2 + (enemy.pos.z - closestZ)^2)
                if perpDist <= SpellData.R.KickWidth then
                    hits = hits + 1
                end
            end
        end
    end
    return hits
end

local function FindBestMultiKickPosition(target, enemies)
    if not target or not IsValid(target) then return nil, 0, nil end
    
    enemies = enemies or GetEnemyHeroes()
    local bestPos, bestHits, bestDir = nil, 0, nil
    
    for _, enemy in ipairs(enemies) do
        if enemy.networkID ~= target.networkID and IsValid(enemy) then
            local distToEnemy = GetDistance(target.pos, enemy.pos)
            if distToEnemy <= SpellData.R.KickDistance + 200 then
                local kickDir = NormalizeVec(target.pos, enemy.pos)
                local hits = 1 + CountMultiKickHits(target, kickDir, enemies)
                if hits > bestHits then
                    bestHits = hits
                    bestDir = kickDir
                    bestPos = {x = target.pos.x - kickDir.x * 180, z = target.pos.z - kickDir.z * 180}
                end
            end
        end
    end
    return bestPos, bestHits, bestDir
end

-- Find the BEST target and kick direction to maximize multikick hits
-- Returns: bestTarget, bestKickPos, totalHits, kickDir
local function FindBestMultiKickTarget()
    local enemies = GetEnemyHeroes()
    local myPos = myHero.pos
    
    local bestTarget = nil
    local bestKickPos = nil
    local bestHits = 0
    local bestDir = nil
    local bestScore = 0
    
    -- Evaluate each enemy as potential kick target
    for _, kickTarget in ipairs(enemies) do
        if IsValid(kickTarget) then
            -- For each potential target, find best kick direction
            for _, dirTarget in ipairs(enemies) do
                if dirTarget.networkID ~= kickTarget.networkID and IsValid(dirTarget) then
                    local distBetween = GetDistance(kickTarget.pos, dirTarget.pos)
                    
                    -- Check if dirTarget is in potential kick range
                    if distBetween <= SpellData.R.KickDistance + 100 then
                        local kickDir = NormalizeVec(kickTarget.pos, dirTarget.pos)
                        local hits = 1 + CountMultiKickHits(kickTarget, kickDir, enemies)
                        
                        -- Calculate position behind kickTarget (opposite to kick direction)
                        local kickPos = {
                            x = kickTarget.pos.x - kickDir.x * 180,
                            z = kickTarget.pos.z - kickDir.z * 180
                        }
                        
                        -- Calculate score based on hits and reachability
                        local distToKickPos = GetDistance(myPos, kickPos)
                        local distToTarget = GetDistance(myPos, kickTarget.pos)
                        
                        -- Score: prioritize more hits, then closer targets
                        local score = hits * 1000 - distToKickPos
                        
                        if hits > bestHits or (hits == bestHits and score > bestScore) then
                            bestTarget = kickTarget
                            bestKickPos = kickPos
                            bestHits = hits
                            bestDir = kickDir
                            bestScore = score
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget, bestKickPos, bestHits, bestDir
end

--------------------------------------------------------------------------------
-- EXTENDED INSEC (Dynamic Q - Uses WardJumpTo)
--------------------------------------------------------------------------------
local function ExecuteExtendedInsec(target)
    local I = State.Insec
    
    if not target or not IsValid(target) then
        I.Active = false
        I.Step = 0
        return
    end
    
    -- R must be ready for insec
    if not IsReady(_R) then
        I.Active = false
        I.Step = 0
        return
    end
    
    local now = Now()
    local insecPos, insecTarget = GetInsecPosition(target)
    if not insecPos then 
        I.Active = false
        I.Step = 0
        return 
    end
    
    local myPos = myHero.pos
    local distToTarget = GetDistance(myPos, target.pos)
    local distToInsec = GetDistance(myPos, insecPos)
    
    local hasWard = HasWard() and IsReady(_W) and HasW1()
    local hasFlash = Menu.Insec.UseFlash:Value() and IsFlashReady()
    local hasQ1 = HasQ1() and IsReady(_Q)
    local hasQ2 = HasQ2() and IsReady(_Q)
    local hasR = IsReady(_R)
    
    -- STEP 0: Initial Decision
    if I.Step == 0 then
        -- Already in position
        if distToTarget <= SpellData.R.Range and distToInsec < 200 and hasR then
            if CastR(target) then
                BeginExtendedInsecRCast(0, true)
                I.Active = false
                return
            end
        end
        
        -- Flash-R direct
        if hasFlash and hasR and distToInsec <= SpellData.Flash.Range + 30 then
            local distAfterFlash = GetDistance(insecPos, target.pos)
            if distAfterFlash <= SpellData.R.Range + 50 then
                if CastFlash(insecPos) then
                    BeginExtendedInsecRCast(0.03, false)
                    I.Active = false
                    return
                end
            end
        end
        
        -- WardJumpTo + Flash-R
        if hasWard and hasFlash and hasR then
            local totalReach = SpellData.W.Range + SpellData.Flash.Range - 50
            if distToInsec <= totalReach then
                local wardDist = math_min(SpellData.W.Range - 50, distToInsec - SpellData.Flash.Range + 50)
                if wardDist > 100 then
                    local wardPos = ExtendVec(myPos, insecPos, wardDist)
                    WardJumpTo(wardPos)
                    I.Step = 1
                    I.WardJumpTime = now
                    return
                end
            end
        end
        
        -- WardJumpTo direct
        if hasWard and hasR and distToInsec <= SpellData.W.Range then
            WardJumpTo(insecPos)
            I.Step = 2
            I.WardJumpTime = now
            return
        end
        
        -- Q2 if we have mark
        if hasQ2 then
            local markedUnit = FindQMarkedUnit()
            if markedUnit then
                local qTarget = {unit = markedUnit, pos = markedUnit.pos, priority = 5}
                local score, canExecute, method = EvaluateQTargetForInsec(qTarget, target, insecPos)
                if canExecute or score > 30 then
                    I.QTarget = markedUnit
                    I.InsecMethod = method
                    CastQ2()
                    I.Step = 5
                    I.Q2CastTime = now
                    return
                end
            end
        end
        
        -- Q1 to best target
        if hasQ1 then
            local bestQTarget, bestScore, bestMethod = FindBestQTargetForInsec(target, insecPos)
            if bestQTarget and bestScore > 0 and CanQHitTarget(bestQTarget.unit) then
                I.QTarget = bestQTarget.unit
                I.InsecMethod = bestMethod
                CastQ1(bestQTarget.unit)
                I.Step = 4
                I.LastAction = now
                return
            end
            
            -- Fallback Q to target
            if distToTarget <= SpellData.Q.Range and CanQHitTarget(target) then
                I.QTarget = target
                I.InsecMethod = "direct"
                CastQ1(target)
                I.Step = 4
                I.LastAction = now
                return
            end
        end
        
        -- Timeout
        if now - I.StartTime > 4.0 then
            I.Active = false
            I.Step = 0
        end
        return
    end
    
    -- STEP 1: After WardJump, Flash-R
    if I.Step == 1 then
        local timeSinceJump = now - I.WardJumpTime
        if timeSinceJump < 0.25 then return end -- Wait for ward place + jump
        
        -- REFRESH position after ward jump
        myPos = myHero.pos
        distToTarget = GetDistance(myPos, target.pos)
        distToInsec = GetDistance(myPos, insecPos)
        
        if hasFlash and hasR and distToInsec <= SpellData.Flash.Range + 100 then
            if CastFlash(insecPos) then
                BeginExtendedInsecRCast(0.03, false)
                I.Active = false
                I.Step = 0
                return
            end
        end
        
        if hasR and distToTarget <= SpellData.R.Range + 50 then
            if CastR(target) then
                BeginExtendedInsecRCast(0, true)
                I.Active = false
                I.Step = 0
                return
            end
        end
        
        if timeSinceJump > 1.5 then I.Step = 0 end
        return
    end
    
    -- STEP 2: After WardJump, R
    if I.Step == 2 then
        local timeSinceJump = now - I.WardJumpTime
        if timeSinceJump < 0.25 then return end -- Wait for ward place + jump
        
        -- REFRESH position after ward jump
        myPos = myHero.pos
        distToTarget = GetDistance(myPos, target.pos)
        
        if hasR and distToTarget <= SpellData.R.Range + 50 then
            if CastR(target) then
                BeginExtendedInsecRCast(0, true)
                I.Active = false
                I.Step = 0
                return
            end
        end
        
        if hasFlash then
            distToInsec = GetDistance(myPos, insecPos)
            if distToInsec <= SpellData.Flash.Range + 50 then
                if CastFlash(insecPos) then
                    BeginExtendedInsecRCast(0.03, false)
                    I.Active = false
                    I.Step = 0
                    return
                end
            end
        end
        
        if timeSinceJump > 1.5 then I.Step = 0 end
        return
    end
    
    -- STEP 4: Wait for Q1 hit
    if I.Step == 4 then
        if now - I.LastAction > 1.5 then
            I.Step = 0
            return
        end
        
        if hasQ2 then
            local markedUnit = FindQMarkedUnit()
            if markedUnit then
                I.QTarget = markedUnit
                CastQ2()
                I.Step = 5
                I.Q2CastTime = now
            end
        end
        return
    end
    
    -- STEP 5: After Q2, execute insec using WardJumpTo
    -- CRITICAL: Need to recalculate insecPos from new position
    if I.Step == 5 then
        local timeSinceQ2 = now - I.Q2CastTime
        if timeSinceQ2 < 0.4 then return end
        
        -- REFRESH everything after Q2 dash completed
        myPos = myHero.pos
        
        -- RECALCULATE insec position from new location
        insecPos, insecTarget = GetInsecPosition(target)
        if not insecPos then
            I.Active = false
            I.Step = 0
            return
        end
        
        distToTarget = GetDistance(myPos, target.pos)
        distToInsec = GetDistance(myPos, insecPos)
        
        -- Refresh ward availability
        hasWard = HasWard() and IsReady(_W) and HasW1()
        
        -- Direct R - we're already in good position
        if distToTarget <= SpellData.R.Range + 30 and distToInsec < 250 and hasR then
            if CastR(target) then
                BeginExtendedInsecRCast(0, true)
                I.Active = false
                I.Step = 0
                return
            end
        end
        
        -- Flash-R
        if hasFlash and hasR and distToInsec <= SpellData.Flash.Range + 50 then
            local distAfterFlash = GetDistance(insecPos, target.pos)
            if distAfterFlash <= SpellData.R.Range + 50 then
                if CastFlash(insecPos) then
                    BeginExtendedInsecRCast(0.03, false)
                    I.Active = false
                    I.Step = 0
                    return
                end
            end
        end
        
        -- WardJumpTo insec position - this should go BEHIND target
        if hasWard and distToInsec <= SpellData.W.Range then
            WardJumpTo(insecPos)
            I.Step = 2
            I.WardJumpTime = now
            return
        end
        
        -- WardJumpTo + Flash - calculate with actual current position
        if hasWard and hasFlash then
            local wardRange = SpellData.W.Range - 50
            local flashRange = SpellData.Flash.Range - 30
            local totalReach = wardRange + flashRange
            
            if distToInsec <= totalReach then
                local wardDist = distToInsec - flashRange
                if wardDist < 100 then wardDist = 100 end
                if wardDist > wardRange then wardDist = wardRange end
                
                local wardPos = ExtendVec(myPos, insecPos, wardDist)
                WardJumpTo(wardPos)
                I.Step = 1
                I.WardJumpTime = now
                return
            end
        end
        
        -- Just R if close
        if hasR and distToTarget <= SpellData.R.Range + 30 then
            if CastR(target) then
                BeginExtendedInsecRCast(0, true)
                I.Active = false
                I.Step = 0
                return
            end
        end
        
        -- Just Flash
        if hasFlash and distToInsec <= SpellData.Flash.Range + 30 then
            if CastFlash(insecPos) then
                BeginExtendedInsecRCast(0.05, false)
                I.Active = false
                I.Step = 0
                return
            end
        end
        
        if timeSinceQ2 > 1.0 then I.Step = 0 end
        return
    end
    
    -- Global timeout
    if now - I.StartTime > 6.0 then
        I.Active = false
        I.Step = 0
    end
end

--------------------------------------------------------------------------------
-- AUTO MULTIKICK (Automatic when 2+ enemies can be hit)
-- Evaluates ALL enemies to find the best kick target and direction
--------------------------------------------------------------------------------
local function TryAutoMultiKick(target)
    if not Menu.Multi.Enabled:Value() then return false end
    if not Menu.Multi.Auto:Value() then return false end
    if not IsReady(_R) then return false end
    
    local now = Now()
    local myPos = myHero.pos
    
    -- If we're in the middle of a WardJump for MultiKick, wait for it to complete
    if State.AutoMultiKick.Active then
        local timeSinceWardJump = now - State.AutoMultiKick.WardJumpTime
        
        -- Wait for ward jump to complete
        if timeSinceWardJump < 0.25 then
            return true -- Still executing, block other actions
        end
        
        -- Ward jump should be done, try to R
        local savedTarget = State.AutoMultiKick.Target
        if savedTarget and IsValid(savedTarget) and IsReady(_R) then
            local newDist = GetDistance(myPos, savedTarget.pos)
            if newDist <= SpellData.R.Range + 100 then
                CastR(savedTarget)
            end
        end
        
        -- Reset state
        State.AutoMultiKick.Active = false
        State.AutoMultiKick.WardJumpTime = 0
        State.AutoMultiKick.Target = nil
        
        if timeSinceWardJump > 1.0 then
            return false
        end
        return true
    end
    
    -- Find the BEST target globally (not just the passed target)
    local bestTarget, bestKickPos, totalHits, kickDir = FindBestMultiKickTarget()
    
    -- If no good multikick found globally, try with the passed target
    if not bestTarget or totalHits < Menu.Multi.Min:Value() then
        if target and IsValid(target) then
            local multiPos, hitCount, dir = FindBestMultiKickPosition(target)
            if multiPos and hitCount >= Menu.Multi.Min:Value() then
                bestTarget = target
                bestKickPos = multiPos
                totalHits = hitCount
                kickDir = dir
            else
                return false
            end
        else
            return false
        end
    end
    
    local dist = GetDistance(myPos, bestTarget.pos)
    local distToKickPos = GetDistance(myPos, bestKickPos)
    
    local hasWard = HasWard() and IsReady(_W) and HasW1()
    local hasFlash = Menu.Multi.UseFlash:Value() and IsFlashReady()
    
    -- Case 1: Already in R range of best target - check angle
    if dist <= SpellData.R.Range then
        local currentKickDir = NormalizeVec(myPos, bestTarget.pos)
        local dotProduct = currentKickDir.x * kickDir.x + currentKickDir.z * kickDir.z
        
        if dotProduct > 0.7 then
            -- Good angle, just R
            CastR(bestTarget)
            return true
        elseif hasFlash then
            -- Bad angle, use R-Flash to reposition
            local flashDist = math_min(distToKickPos, SpellData.Flash.Range - 30)
            local flashPos = ExtendVec(myPos, bestKickPos, flashDist)
            CastRFlash(bestTarget, flashPos)
            return true
        else
            -- No flash but still hits multiple, R anyway
            CastR(bestTarget)
            return true
        end
    end
    
    -- Case 2: Flash to kick position (instant)
    if hasFlash and distToKickPos <= SpellData.Flash.Range then
        local flashPos = Vector(bestKickPos.x, myPos.y, bestKickPos.z)
        CastFlash(flashPos)
        DelayAction(function()
            if IsValid(bestTarget) and IsReady(_R) then
                local newDist = GetDistance(myHero.pos, bestTarget.pos)
                if newDist <= SpellData.R.Range + 50 then
                    CastR(bestTarget)
                end
            end
        end, 0.05)
        return true
    end
    
    -- Case 3: WardJump to kick position
    if hasWard and distToKickPos <= SpellData.W.Range then
        if WardJumpTo(bestKickPos) then
            State.AutoMultiKick.Active = true
            State.AutoMultiKick.WardJumpTime = now
            State.AutoMultiKick.Target = bestTarget
            return true
        end
    end
    
    -- Case 4: WardJump + Flash combo
    if hasWard and hasFlash then
        local wardRange = SpellData.W.Range - 50
        local flashRange = SpellData.Flash.Range - 50
        
        if distToKickPos <= wardRange + flashRange then
            local wardPos
            if distToKickPos <= wardRange then
                wardPos = bestKickPos
            else
                wardPos = ExtendVec(myPos, bestKickPos, wardRange)
            end
            
            if WardJumpTo(wardPos) then
                local savedTarget = bestTarget
                local savedKickPos = bestKickPos
                
                DelayAction(function()
                    if IsFlashReady() then
                        local currentPos = myHero.pos
                        local remainingDist = GetDistance(currentPos, savedKickPos)
                        if remainingDist > 50 and remainingDist <= SpellData.Flash.Range then
                            local flashTarget = Vector(savedKickPos.x, currentPos.y, savedKickPos.z)
                            CastFlash(flashTarget)
                            
                            DelayAction(function()
                                if IsValid(savedTarget) and IsReady(_R) then
                                    local finalDist = GetDistance(myHero.pos, savedTarget.pos)
                                    if finalDist <= SpellData.R.Range + 50 then
                                        CastR(savedTarget)
                                    end
                                end
                            end, 0.05)
                        end
                    end
                end, 0.20)
                return true
            end
        end
    end
    
    return false
end

--------------------------------------------------------------------------------
-- SMART COMBO - Simple with AutoMultiKick
--------------------------------------------------------------------------------
local function SmartCombo(target)
    if not target or not IsValid(target) then return end
    
    local myPos = myHero.pos
    local dist = GetDistance(myPos, target.pos)
    local hp = HealthPercent()
    
    -- Check if AutoMultiKick is in progress
    if State.AutoMultiKick.Active then
        TryAutoMultiKick(State.AutoMultiKick.Target or target)
        return
    end
    
    -- Priority 1: Auto MultiKick when 2+ enemies can be hit
    if Menu.Combo.UseR:Value() and IsReady(_R) and Menu.Multi.Enabled:Value() and Menu.Multi.Auto:Value() then
        local currentHits = CountMultiKickHits(target)
        
        if currentHits >= Menu.Multi.Min:Value() - 1 then
            if dist <= SpellData.R.Range then
                -- In range, just R
                CastR(target)
                return
            else
                -- Try to get in position (with ward/flash)
                if TryAutoMultiKick(target) then
                    return
                end
            end
        else
            local multiPos, hitCount = FindBestMultiKickPosition(target)
            if hitCount and hitCount >= Menu.Multi.Min:Value() then
                if TryAutoMultiKick(target) then
                    return
                end
            end
        end
    end
    
    -- Priority 2: Shield when low HP
    if Menu.Combo.UseW:Value() and IsReady(_W) and HasW1() and hp < Menu.Combo.WShieldHP:Value() then
        CastW(myHero)
        return
    end
    
    -- Priority 3: Q2 follow up (only if marked on target or close enemy)
    if Menu.Combo.UseQ:Value() and HasQ2() and IsReady(_Q) then
        local qMarkedUnit = FindQMarkedUnit()
        if qMarkedUnit then
            -- Always follow if marked on target
            if qMarkedUnit.networkID == target.networkID then
                CastQ2()
                return
            end
            -- Follow if marked unit is close to target
            local distQToTarget = GetDistance(qMarkedUnit.pos, target.pos)
            if distQToTarget <= 600 then
                CastQ2()
                return
            end
        end
    end
    
    -- Priority 4: Q1 initiate
    if Menu.Combo.UseQ:Value() and HasQ1() and IsReady(_Q) and dist <= SpellData.Q.Range then
        CastQ1(target)
        return
    end
    
    -- Priority 5: E damage
    if Menu.Combo.UseE:Value() and HasE1() and IsReady(_E) and dist <= SpellData.E.Range then
        CastE()
        return
    end
    
    if Menu.Combo.UseE:Value() and HasE2() and IsReady(_E) then
        CastE()
        return
    end
    
    -- Priority 6: R for execute (single target)
    if Menu.Combo.UseR:Value() and IsReady(_R) and dist <= SpellData.R.Range then
        if CanKillWithR(target) then
            CastR(target)
            return
        end
    end
end

--------------------------------------------------------------------------------
-- CLEAR
--------------------------------------------------------------------------------
local function SmartJungleClear()
    if not Menu.Clear.Enabled:Value() then return end
    if EnergyPercent() < Menu.Clear.MinEnergy:Value() then return end
    
    local bestMonster = nil
    if GameMinionCount then
        for i = 1, GameMinionCount() do
            local m = GameMinion(i)
            if m and m.team == 300 and IsValid(m) and GetDistance(myHero.pos, m.pos) <= SpellData.Q.Range then
                if not bestMonster or m.maxHealth > bestMonster.maxHealth then
                    bestMonster = m
                end
            end
        end
    end
    
    if not bestMonster then return end
    
    local dist = GetDistance(myHero.pos, bestMonster.pos)
    
    if Menu.Clear.UseQ:Value() and IsReady(_Q) and HasQ2() then
        CastQ2()
        return
    end
    
    if Menu.Clear.UseQ:Value() and IsReady(_Q) and HasQ1() then
        CastQ1(bestMonster)
        return
    end
    
    if Menu.Clear.UseE:Value() and IsReady(_E) and dist <= SpellData.E.Range then
        CastE()
        return
    end
    
    if Menu.Clear.UseW:Value() and IsReady(_W) and not HasPassive() then
        CastW(myHero)
        return
    end
end

local function SmartLaneClear()
    if not Menu.Clear.Enabled:Value() then return end
    if EnergyPercent() < Menu.Clear.MinEnergy:Value() then return end
    
    local bestMinion = nil
    if GameMinionCount then
        for i = 1, GameMinionCount() do
            local m = GameMinion(i)
            if m and m.team ~= myHero.team and m.team ~= 300 and IsValid(m) then
                if GetDistance(myHero.pos, m.pos) <= SpellData.Q.Range then
                    if not bestMinion or m.health < bestMinion.health then
                        bestMinion = m
                    end
                end
            end
        end
    end
    
    if not bestMinion then return end
    
    if Menu.Clear.UseQ:Value() and IsReady(_Q) and HasQ2() then
        CastQ2()
        return
    end
    
    if Menu.Clear.UseQ:Value() and IsReady(_Q) and HasQ1() then
        CastQ1(bestMinion)
        return
    end
    
    if Menu.Clear.UseE:Value() and IsReady(_E) and GetDistance(myHero.pos, bestMinion.pos) <= SpellData.E.Range then
        CastE()
        return
    end
end

local function IsClearMode()
    return Menu and Menu.Keys.Clear and Menu.Keys.Clear:Value()
end

--------------------------------------------------------------------------------
-- MENU
--------------------------------------------------------------------------------
local function LoadMenu()
    Menu = MenuElement({id = "DepressiveLeeSin2", name = "[Depressive] Lee Sin v" .. VERSION, type = MENU})
    
    Menu:MenuElement({type = MENU, id = "Keys", name = "Keys"})
    Menu.Keys:MenuElement({id = "Combo", name = "Combo", key = string.byte(" ")})
    Menu.Keys:MenuElement({id = "Insec", name = "Extended Insec", key = string.byte("G")})
    Menu.Keys:MenuElement({id = "WardJump", name = "Ward Jump", key = string.byte("A")})
    Menu.Keys:MenuElement({id = "Clear", name = "Clear", key = string.byte("V")})
    
    Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    Menu.Combo:MenuElement({id = "UseQ", name = "Use Q", value = true})
    Menu.Combo:MenuElement({id = "UseSmiteQ", name = "Use Smite + Q (kill minion for Q)", value = true})
    Menu.Combo:MenuElement({id = "SmiteQInfo", name = "^ Smites blocking minion to land Q!", value = true, toggle = false})
    Menu.Combo:MenuElement({id = "UseW", name = "Use W (Shield)", value = true})
    Menu.Combo:MenuElement({id = "WShieldHP", name = "W Shield at HP%", value = 40, min = 10, max = 80, step = 5})
    Menu.Combo:MenuElement({id = "UseE", name = "Use E", value = true})
    Menu.Combo:MenuElement({id = "UseR", name = "Use R (Execute/Multi)", value = true})
    
    Menu:MenuElement({type = MENU, id = "Insec", name = "Extended Insec"})
    Menu.Insec:MenuElement({id = "Enabled", name = "Enable Extended Insec", value = true})
    Menu.Insec:MenuElement({id = "Mode", name = "Kick Target", drop = {"To Ally", "To Turret", "To Cursor"}, value = 1})
    Menu.Insec:MenuElement({id = "UseFlash", name = "Use Flash", value = true})
    
    Menu:MenuElement({type = MENU, id = "Multi", name = "Multi-Kick"})
    Menu.Multi:MenuElement({id = "Enabled", name = "Enable Multi-Kick Detection", value = true})
    Menu.Multi:MenuElement({id = "Auto", name = "Auto MultiKick in Combo (Ward/Flash)", value = true})
    Menu.Multi:MenuElement({id = "UseFlash", name = "Use Flash", value = true})
    Menu.Multi:MenuElement({id = "Min", name = "Min Enemies to Multi-Kick", value = 2, min = 1, max = 4, step = 1})
    Menu.Multi:MenuElement({id = "Draw", name = "Draw Multi-Kick Count", value = true})
    
    Menu:MenuElement({type = MENU, id = "Clear", name = "Clear"})
    Menu.Clear:MenuElement({id = "Enabled", name = "Enable Clear", value = true})
    Menu.Clear:MenuElement({id = "UseQ", name = "Use Q", value = true})
    Menu.Clear:MenuElement({id = "UseW", name = "Use W (Sustain)", value = true})
    Menu.Clear:MenuElement({id = "UseE", name = "Use E", value = true})
    Menu.Clear:MenuElement({id = "MinEnergy", name = "Min Energy%", value = 30, min = 10, max = 80, step = 5})
    
    Menu:MenuElement({type = MENU, id = "Draw", name = "Drawing"})
    Menu.Draw:MenuElement({id = "Enabled", name = "Enable Drawing", value = true})
    Menu.Draw:MenuElement({id = "Q", name = "Q Range", value = true})
    Menu.Draw:MenuElement({id = "W", name = "W Range", value = true})
    Menu.Draw:MenuElement({id = "InsecPos", name = "Insec Position", value = true})
    Menu.Draw:MenuElement({id = "Status", name = "Combo Status", value = true})
    Menu.Draw:MenuElement({id = "DebugMinions", name = "[Debug] Show Minions/Monsters", value = false})
    Menu.Draw:MenuElement({id = "DebugSmiteQ", name = "[Debug] Show Smite+Q Info", value = false})
end

--------------------------------------------------------------------------------
-- TICK
--------------------------------------------------------------------------------
local function OnTick()
    if myHero.dead or not Menu then return end
    RefreshHeroCache()
    
    local comboKey = Menu.Keys.Combo:Value()
    local insecKey = Menu.Keys.Insec:Value()
    local insecPressed = insecKey and not LastInsecKeyState
    LastInsecKeyState = insecKey
    local wardKey = Menu.Keys.WardJump:Value()
    
    -- Ward Jump (hold)
    if wardKey then
        WardJump()
        return
    end
    
    local target = GetClosestEnemy(1500)
    local mouseTarget = GetClosestEnemyToMouse(500)

    -- Extended Insec stays locked on the selected target until R is actually fired.
    if State.Insec.Active or State.Insec.PendingRCast then
        if not IsValid(State.Insec.Target) then
            ResetExtendedInsecState()
        else
            FollowCursorToUnit(State.Insec.Target)
            if State.Insec.Active then
                ExecuteExtendedInsec(State.Insec.Target)
            end
            if State.Insec.PendingRCast then
                UpdateExtendedInsecRCast()
            end
            if not State.Insec.Active and not State.Insec.PendingRCast then
                ResetExtendedInsecState()
            end
            return
        end
    end

    if insecPressed and Menu.Insec.Enabled:Value() then
        local insecTarget = mouseTarget or target
        if StartExtendedInsec(insecTarget) then
            FollowCursorToUnit(State.Insec.Target)
            ExecuteExtendedInsec(State.Insec.Target)
            if State.Insec.PendingRCast then
                UpdateExtendedInsecRCast()
            end
            if not State.Insec.Active and not State.Insec.PendingRCast then
                ResetExtendedInsecState()
            end
            return
        end
    end
    
    -- Combo (hold key)
    if comboKey and target then
        SmartCombo(target)
        return
    end
    
    -- Clear (hold key)
    if IsClearMode() then
        SmartJungleClear()
        SmartLaneClear()
    end
end

--------------------------------------------------------------------------------
-- DRAW
--------------------------------------------------------------------------------
local function OnDraw()
    if myHero.dead or not Menu or not Menu.Draw.Enabled:Value() then return end
    RefreshHeroCache()
    
    local myPos = myHero.pos
    
    if Menu.Draw.Q:Value() and IsReady(_Q) then
        Draw.Circle(myPos, SpellData.Q.Range, 1, Draw.Color(100, 100, 255, 100))
    end
    
    if Menu.Draw.W:Value() and IsReady(_W) then
        Draw.Circle(myPos, SpellData.W.Range, 1, Draw.Color(100, 100, 100, 255))
    end
    
    if Menu.Draw.InsecPos:Value() then
        local drawTarget = (State.Insec.Active and State.Insec.Target) or GetClosestEnemyToMouse(800) or GetClosestEnemy(1500)
        if drawTarget and IsValid(drawTarget) then
            local insecPos, insecTarget = GetInsecPosition(drawTarget)
            if insecPos then
                Draw.Circle(drawTarget.pos, 100, 2, Draw.Color(255, 255, 255, 0))
                Draw.Circle(Vector(insecPos.x, drawTarget.pos.y, insecPos.z), 80, 2, Draw.Color(200, 0, 255, 255))
                
                if insecTarget and insecTarget.pos then
                    local p1 = drawTarget.pos:To2D()
                    local p2 = insecTarget.pos:To2D()
                    if p1 and p2 then
                        Draw.Line(p1.x, p1.y, p2.x, p2.y, 2, Draw.Color(200, 0, 255, 0))
                    end
                end
                
                if State.Insec.Active and State.Insec.QTarget and IsValid(State.Insec.QTarget) then
                    if State.Insec.QTarget.networkID ~= drawTarget.networkID then
                        Draw.Circle(State.Insec.QTarget.pos, 70, 2, Draw.Color(255, 255, 50, 50))
                    end
                end
            end
        end
    end
    
    if Menu.Draw.Status:Value() then
        if State.Insec.Active then
            local stepNames = {[0]="Eval", [1]="Ward+Flash", [2]="Ward+R", [4]="Q1 Wait", [5]="Q2->Insec"}
            Draw.Text("Insec: " .. (stepNames[State.Insec.Step] or "?"), 20, 50, 70, Draw.Color(255, 0, 255, 255))
            
            if State.Insec.QTarget and IsValid(State.Insec.QTarget) then
                Draw.Text("Q->" .. (State.Insec.QTarget.charName or "unit"), 16, 50, 90, Draw.Color(255, 255, 150, 0))
            end
        elseif State.AutoMultiKick.Active then
            Draw.Text("AutoMultiKick Active", 20, 50, 50, Draw.Color(255, 0, 255, 0))
        end
    end
    
    if Menu.Multi.Draw:Value() then
        for _, enemy in ipairs(GetEnemyHeroes()) do
            if GetDistance(myPos, enemy.pos) <= SpellData.R.Range + 200 then
                local hits = CountMultiKickHits(enemy)
                if hits > 0 then
                    local color = hits >= Menu.Multi.Min:Value() and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 100, 0)
                    Draw.Circle(enemy.pos, 100, 2, color)
                    local p = enemy.pos:To2D()
                    if p then
                        Draw.Text("Hits: " .. hits, 16, p.x - 20, p.y - 40, color)
                    end
                end
            end
        end
    end
    
    -- Debug: Show all minions/monsters
    if Menu.Draw.DebugMinions:Value() then
        local minionCount = 0
        if GameMinionCount then
            for i = 1, GameMinionCount() do
                local minion = GameMinion(i)
                if minion and IsValid(minion) then
                    local dist = GetDistance(myPos, minion.pos)
                    if dist <= 1500 then
                        minionCount = minionCount + 1
                        local color
                        if minion.team == myHero.team then
                            color = Draw.Color(150, 0, 255, 0) -- Green for ally
                        elseif minion.team == 300 then
                            color = Draw.Color(200, 255, 165, 0) -- Orange for jungle
                        else
                            color = Draw.Color(200, 255, 0, 0) -- Red for enemy
                        end
                        
                        Draw.Circle(minion.pos, minion.boundingRadius or 50, 2, color)
                        
                        local p = minion.pos:To2D()
                        if p then
                            local teamText = minion.team == 300 and "JG" or tostring(minion.team)
                            Draw.Text(teamText .. " r:" .. math_floor(minion.boundingRadius or 0), 12, p.x - 20, p.y - 30, color)
                        end
                    end
                end
            end
        end
        Draw.Text("Minions in range: " .. minionCount, 16, 50, 130, Draw.Color(255, 255, 255, 255))
    end
    
    -- Debug: Show Smite+Q info
    if Menu.Draw.DebugSmiteQ:Value() then
        local yOffset = 150
        
        -- Smite status
        local smiteSlot, _ = GetSmiteSlot()
        local smiteReady = IsSmiteReady()
        local smiteName = "NO SMITE"
        if smiteSlot then
            local sd = myHero:GetSpellData(smiteSlot)
            if sd and sd.name then
                smiteName = sd.name .. " (ammo: " .. (sd.ammo or 0) .. ")"
            end
        end
        local smiteText = smiteReady and ("Smite: READY - " .. smiteName) or ("Smite: " .. smiteName)
        local smiteColor = smiteReady and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 0, 0)
        Draw.Text(smiteText, 16, 50, yOffset, smiteColor)
        yOffset = yOffset + 20
        
        -- Check for blocking minion to closest enemy
        local target = GetClosestEnemy(SpellData.Q.Range)
        if target then
            local sourcePos2D = {x = myPos.x, z = myPos.z}
            local targetPos2D = {x = target.pos.x, z = target.pos.z}
            local blockingMinion, blockingCount = FindBlockingMinion(sourcePos2D, targetPos2D)
            
            if blockingMinion then
                local minionDist = GetDistance(myPos, blockingMinion.pos)
                local inSmiteRange = minionDist <= SpellData.Smite.Range
                
                -- Show blocking count
                local countColor = blockingCount == 1 and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 0, 0)
                Draw.Text("Blocking Count: " .. blockingCount .. (blockingCount == 1 and " (can Smite+Q!)" or " (too many!)"), 16, 50, yOffset, countColor)
                yOffset = yOffset + 20
                
                Draw.Text("Closest Block dist: " .. math_floor(minionDist), 16, 50, yOffset, Draw.Color(255, 255, 100, 0))
                yOffset = yOffset + 20
                
                local rangeText = inSmiteRange and "In Smite Range: YES" or "In Smite Range: NO (need " .. SpellData.Smite.Range .. ")"
                local rangeColor = inSmiteRange and Draw.Color(255, 0, 255, 0) or Draw.Color(255, 255, 0, 0)
                Draw.Text(rangeText, 16, 50, yOffset, rangeColor)
                yOffset = yOffset + 20
                
                -- Draw circle on blocking minion
                Draw.Circle(blockingMinion.pos, 80, 3, Draw.Color(255, 255, 0, 255)) -- Yellow circle
                
                -- Draw line from Lee to target showing block
                local p1 = myPos:To2D()
                local p2 = target.pos:To2D()
                local pM = blockingMinion.pos:To2D()
                if p1 and p2 then
                    Draw.Line(p1.x, p1.y, p2.x, p2.y, 2, Draw.Color(150, 255, 0, 0))
                end
                if pM then
                    Draw.Text("BLOCK", 14, pM.x - 20, pM.y - 50, Draw.Color(255, 255, 255, 0))
                end
            else
                Draw.Text("Blocking: NO (Q clear!)", 16, 50, yOffset, Draw.Color(255, 0, 255, 0))
            end
        else
            Draw.Text("No target in Q range", 16, 50, yOffset, Draw.Color(255, 150, 150, 150))
        end
    end
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------
local function Init()
    LoadMenu()
    Callback.Add("Tick", OnTick)
    Callback.Add("Draw", OnDraw)
    print("[DepressiveLeeSin] v" .. VERSION .. " loaded! Features: Smite+Q, Fast WardJump, Dynamic Insec")
end

if not _G.__DEPRESSIVE_LEESIN_FINAL_INSTANCE then
    _G.__DEPRESSIVE_LEESIN_FINAL_INSTANCE = true
    Init()
end
