local VERSION = "0.22"
if _G.__DEPRESSIVE_NEXT_AHRI_LOADED then return end
if myHero.charName ~= "Ahri" then return end

-- Prediction library load (DepressivePrediction)
local DepressivePrediction = require("DepressivePrediction")
if not DepressivePrediction then
    if print then print("[Ahri] DepressivePrediction not found, using fallback") end
end

-- MapPosition (wall detection) assumed loaded by core; fallback attempt
if not MapPosition or not MapPosition.inWall then
    pcall(function() require("MapPositionGOS") end)
end

-- Utility shortcuts
local MathHuge = math.huge
local function Dist2D(a,b)
    if not a or not b then return MathHuge end
    local dx = a.x - b.x; local dz = (a.z or a.y) - (b.z or b.y)
    return math.sqrt(dx*dx + dz*dz)
end
local function Dist2DSqr(a,b)
    if not a or not b then return MathHuge end
    local dx = a.x - b.x; local dz = (a.z or a.y) - (b.z or b.y)
    return dx*dx + dz*dz
end

local function IsValid(unit)
    return unit and unit.valid and unit.visible and not unit.dead and unit.isTargetable
end

local function Ready(slot)
    local sd = myHero:GetSpellData(slot)
    return sd and sd.level > 0 and sd.currentCd == 0 and Game.CanUseSpell(slot) == 0
end

-- Simple in-range check (2D) for spells
local SPELL_RANGES = {[_Q]=880,[_W]=700,[_E]=975, R=450}
local function InRange(slot, target)
    if not target then return false end
    local r = SPELL_RANGES[slot] or (slot==_R and SPELL_RANGES.R)
    if not r then return false end
    return Dist2D(myHero.pos, target.pos) <= r + 5 -- small buffer
end

-- Summoner spell detection
local function GetFlashSlot()
    for _, slot in ipairs({SUMMONER_1, SUMMONER_2}) do
        local s = myHero:GetSpellData(slot)
        if s and s.name == "SummonerFlash" and s.currentCd == 0 and Game.CanUseSpell(slot) == 0 then
            local hk = (slot == SUMMONER_1 and HK_SUMMONER_1) or HK_SUMMONER_2
            return slot, hk
        end
    end
    return nil, nil
end

-- Basic cached enemy list (refresh each 0.25s)
local enemyCache = {t=0,list={}}
-- Basic cached enemy minion list (refresh each 0.25s)
local minionCache = {t=0,list={}}
local function GetEnemies()
    local now = Game.Timer()
    if now - enemyCache.t > 0.25 then
        local tmp = {}
        for i=1,Game.HeroCount() do
            local e = Game.Hero(i)
            if e and e.team ~= myHero.team and IsValid(e) then tmp[#tmp+1]=e end
        end
        enemyCache.list = tmp; enemyCache.t = now
    end
    return enemyCache.list
end

local function GetEnemyMinions()
    local now = Game.Timer()
    if now - minionCache.t > 0.25 then
        local tmp = {}
        for i=1, Game.MinionCount() do
            local m = Game.Minion(i)
            if m and m.team ~= myHero.team and m.valid and not m.dead and m.isTargetable then
                tmp[#tmp+1] = m
            end
        end
        minionCache.list = tmp; minionCache.t = now
    end
    return minionCache.list
end

local function GetTarget(range)
    local best,bd = nil, MathHuge
    for _,e in ipairs(GetEnemies()) do
        local d = Dist2D(myHero.pos, e.pos)
        if d < range and d < bd then best=e; bd=d end
    end
    return best
end

-- Simple damage estimate (very rough); can be extended
local function QDamage(target)
    local q = myHero:GetSpellData(_Q).level; if q==0 then return 0 end
    local base = ({40,65,90,115,140})[q] or 0
    return base + myHero.ap * 0.35
end
local function WDamage(target)
    local w = myHero:GetSpellData(_W).level; if w==0 then return 0 end
    local base = ({60,90,120,150,180})[w] or 0
    return base + myHero.ap * 0.3
end
local function EDamage(target)
    local e = myHero:GetSpellData(_E).level; if e==0 then return 0 end
    local base = ({70,110,150,190,230})[e] or 0
    return base + myHero.ap * 0.4
end
local function RDamage(target)
    local r = myHero:GetSpellData(_R).level; if r==0 then return 0 end
    local base = ({70,110,150})[r] or 0
    return base + myHero.ap * 0.25
end
local function TotalComboDamage(t)
    if not t then return 0 end
    local dmg = 0
    if Ready(_Q) then dmg = dmg + QDamage(t)*1.8 -- orb out+back approx
    end
    if Ready(_W) then dmg = dmg + WDamage(t)
    end
    if Ready(_E) then dmg = dmg + EDamage(t)
    end
    if Ready(_R) then dmg = dmg + RDamage(t)*3 -- potential 3 charges
    end
    return dmg
end

-- Hitchance mapping (using DepressivePrediction)
local function DepressiveHitchanceOK(needed, got)
    local map = {2,3,4,5,6} -- Low->Immobile
    return (got or 0) >= (map[(needed or 1)+1] or 3)
end

-- Prediction based casts using DepressivePrediction
local function CastQPred(target, needed)
    if not target then return false end
    if not DepressivePrediction then return false end
    
    local hitchance = DepressivePrediction.HITCHANCE_NORMAL
    
    -- Map menu value to prediction constant
    if needed == 0 then hitchance = DepressivePrediction.HITCHANCE_LOW
    elseif needed == 1 then hitchance = DepressivePrediction.HITCHANCE_NORMAL
    elseif needed == 2 then hitchance = DepressivePrediction.HITCHANCE_HIGH
    elseif needed == 3 then hitchance = DepressivePrediction.HITCHANCE_VERYHIGH
    elseif needed == 4 then hitchance = DepressivePrediction.HITCHANCE_IMMOBILE
    end
    
    local prediction = DepressivePrediction.SpellPrediction({
        Type = DepressivePrediction.SPELLTYPE_LINE,
        Speed = 1550,
        Range = 880,
        Delay = 0.25,
        Radius = 90,
        Collision = false
    })
    
    local result = prediction:GetPrediction(target, myHero)
    if result and result.HitChance >= hitchance and result.CastPosition then
        Control.CastSpell(HK_Q, result.CastPosition)
        return true
    end
    return false
end

local function CastEPred(target, needed)
    if not target then return false end
    if not DepressivePrediction then return false end
    
    local hitchance = DepressivePrediction.HITCHANCE_NORMAL
    
    -- Map menu value to prediction constant
    if needed == 0 then hitchance = DepressivePrediction.HITCHANCE_LOW
    elseif needed == 1 then hitchance = DepressivePrediction.HITCHANCE_NORMAL
    elseif needed == 2 then hitchance = DepressivePrediction.HITCHANCE_HIGH
    elseif needed == 3 then hitchance = DepressivePrediction.HITCHANCE_VERYHIGH
    elseif needed == 4 then hitchance = DepressivePrediction.HITCHANCE_IMMOBILE
    end
    
    local prediction = DepressivePrediction.SpellPrediction({
        Type = DepressivePrediction.SPELLTYPE_LINE,
        Speed = 1600,
        Range = 975,
        Delay = 0.25,
        Radius = 60,
        Collision = true,
        CollisionTypes = {DepressivePrediction.COLLISION_MINION}
    })
    
    local result = prediction:GetPrediction(target, myHero)
    if result and result.HitChance >= hitchance and result.CastPosition then
        Control.CastSpell(HK_E, result.CastPosition)
        return true
    end
    return false
end

local function GetEPredPosition(target)
    if not target or not DepressivePrediction then return target.pos, 3 end
    
    local prediction = DepressivePrediction.SpellPrediction({
        Type = DepressivePrediction.SPELLTYPE_LINE,
        Speed = 1600,
        Range = 975,
        Delay = 0.25,
        Radius = 60,
        Collision = true,
        CollisionTypes = {DepressivePrediction.COLLISION_MINION}
    })
    
    local result = prediction:GetPrediction(target, myHero)
    if result and result.CastPosition then
        return result.CastPosition, result.HitChance or 3
    end
    return target.pos, 3
end

-- Manual simple minion collision check for E fallback (in case prediction object not used)
local function EMinionCollision(fromPos, toPos, target)
    local segDX = toPos.x - fromPos.x
    local segDZ = toPos.z - fromPos.z
    local segLenSqr = segDX*segDX + segDZ*segDZ
    if segLenSqr == 0 then return false end
    local radius = 60 -- E width
    local minions = GetEnemyMinions()
    for i=1, #minions do
        local m = minions[i]
        if m and m.team ~= myHero.team and not m.dead and (not target or m.networkID ~= target.networkID) then
            local vx = m.pos.x - fromPos.x
            local vz = m.pos.z - fromPos.z
            local t = (vx*segDX + vz*segDZ) / segLenSqr
            if t > 0 and t < 1 then
                local projx = fromPos.x + segDX * t
                local projz = fromPos.z + segDZ * t
                local dx = m.pos.x - projx
                local dz = m.pos.z - projz
                local distSqr = dx*dx + dz*dz
                if distSqr < (radius+45)*(radius+45) then -- 45 approximate minion radius
                    return true
                end
            end
        end
    end
    return false
end

-- Wall crossing / dash evaluation for R
local function IsWallBetween(a,b)
    if not a or not b or not MapPosition or not MapPosition.intersectsWall then return false end
    return MapPosition:intersectsWall(a,b)
end

local function GetRDashes(target)
    local res = {}
    if not target then return res end
    local base = myHero.pos
    local maxR = 450
    local samples = 24
    for i=1,samples do
        local ang = (2*math.pi/samples) * i
        local dir = Vector(math.cos(ang), 0, math.sin(ang))
        local p = base + dir * maxR
        local crossesWall = IsWallBetween(base, p)
        local dTarget = Dist2D(p,target.pos)
        local improve = dTarget < Dist2D(base,target.pos)
        res[#res+1] = {pos=p, crosses=crossesWall, improve=improve, score=(improve and 1 or 0) + (crossesWall and 0.3 or 0)}
    end
    table.sort(res,function(a,b) return a.score>b.score end)
    return res
end

-- E-Flash logic: cast E then flash shortly after to extend charm (NOT Flash-E)
local pendingEFlash = nil -- legacy (unused)
local lastInstantEFlash = 0
local scheduledEFlash = nil -- {time, hk, pos}
local lastCastTimes = {[_Q]=0,[_W]=0,[_E]=0,[_R]=0}
local CAST_DELAY = 0.55
local R_CHAIN_DELAY = 1.2
local function ClampFlashPos(targetPos)
    local maxFlash = 400
    local dir = (targetPos - myHero.pos)
    local len = math.sqrt((dir.x*dir.x)+(dir.z*dir.z))
    if len == 0 then return myHero.pos end
    if len <= maxFlash then return targetPos end
    local scale = maxFlash/len
    return myHero.pos + Vector(dir.x*scale, 0, dir.z*scale)
end
local function TryEFlash(target)
    if not target then return end
    local now = Game.Timer()
    if now - lastInstantEFlash < 0.25 then return end -- throttle
    if scheduledEFlash then return end -- already queued
    local flashSlot, flashHK = GetFlashSlot(); if not flashSlot then return end
    if not Ready(_E) then return end
    local ERange, flashRange = 975, 400
    local dist = Dist2D(myHero.pos, target.pos)
    -- Only if OUT of E range but inside E+Flash total window
    if dist <= ERange or dist > (ERange + flashRange) then return end
    local predPos, hc = GetEPredPosition(target)
    if not predPos then return end
    -- Clamp cast position inside normal E range so engine accepts the cast BEFORE we flash
    local castPos = predPos
    local dCast = Dist2D(myHero.pos, castPos)
    if dCast > ERange then
        local dir = (castPos - myHero.pos)
        local len = math.sqrt(dir.x*dir.x + dir.z*dir.z)
        if len > 0 then
            local scale = (ERange - 20) / len -- buffer
            castPos = myHero.pos + Vector(dir.x*scale, 0, dir.z*scale)
        else
            castPos = myHero.pos
        end
    end
    Control.CastSpell(HK_E, castPos)
    local flashPos = ClampFlashPos(target.pos)
    scheduledEFlash = {time = now + 0.10, hk = flashHK, pos = flashPos}
    lastInstantEFlash = now
end

-- R tracking via AhriR buff (stack 1 => active, stack 0 => inactive)
local lastRBuffState = 0
local function GetBuffByName(unit, name)
    for i=0, unit.buffCount do
        local b = unit:GetBuff(i)
        if b and b.name and b.name:lower() == name then return b end
    end
end
local function TrackR()
    local selfObj = _G.DepressiveAhri
    if not selfObj then return end

    -- Attempt to get buff (common names)
    local buff = GetBuffByName(myHero,"ahrir") or GetBuffByName(myHero,"ahriR") or GetBuffByName(myHero,"AhriR")

    -- Determine if R is active by stacks > 0
    local stacks = 0
    if buff and buff.duration and buff.duration > 0 then
        stacks = (buff.stacks or buff.count or 0)
    end
    local active = stacks > 0

    -- Activation (first cast already used 1 charge, 2 remaining)
    if active and not selfObj.rActive then
        selfObj.rActive = true
        selfObj.rChargesRemaining = 2
        selfObj.rExpireTime = Game.Timer() + (buff and buff.duration or 10)
        selfObj.rLock = false
    end

    -- Buff ended (all charges used or expired)
    if (not active) and selfObj.rActive then
        selfObj.rActive = false
        selfObj.rChargesRemaining = 0
        selfObj.rLock = false
    end

    -- Time expiration
    if selfObj.rActive and Game.Timer() > selfObj.rExpireTime then
        selfObj.rActive = false
        selfObj.rChargesRemaining = 0
        selfObj.rLock = false
    end

    -- If for some reason we mark 0 charges while buff continues, block until finished
    if selfObj.rActive and selfObj.rChargesRemaining <= 0 then
        selfObj.rLock = true
    end
end

Callback.Add("Tick", function()
    if not _G.DepressiveAhri or myHero.dead then return end
    -- R toggleState debug (prints only when value changes)
    do
        _G.__AhriLastRToggle = _G.__AhriLastRToggle or nil
        local sd = myHero:GetSpellData(_R)
        local ts = sd and sd.toggleState or nil
        if ts ~= _G.__AhriLastRToggle then
            _G.__AhriLastRToggle = ts
            if print then print(string.format("[Ahri] R toggleState = %s", tostring(ts))) end
        end
    end
    -- legacy pendingEFlash removed (instant flash now)
    TrackR()
    _G.DepressiveAhri:OnTick()
end)

-- Class
local Ahri = {}
Ahri.__index = Ahri

function Ahri:__init()
    local o = setmetatable({}, Ahri)
    o.rCharges = 0
    o.lastRUpdate = 0
    o.rActive = false
    o.rLock = false
    o.lastComboTime = 0
    o.eFlashUsed = false
    o.rChargesRemaining = 0
    o.rExpireTime = 0
    -- Performance caches
    o.lastClearScanTime = 0
    o.clearScanInterval = 0.30
    o.cachedClearQPos = nil
    o.cachedClearQCount = 0
    o.Menu = o:CreateMenu()
    if print then print("[Depressive - Ahri] Loaded v"..VERSION) end
    return o
end

function Ahri:CreateMenu()
    local M = MenuElement({type=MENU,id="DepressiveAhri", name="Depressive - Ahri"})
    M:MenuElement({name=" ", drop={"Version "..VERSION}})

    M:MenuElement({type=MENU,id="combo", name="Combo"})
    M.combo:MenuElement({type=MENU,id="spells", name="Spells"})
    M.combo:MenuElement({type=MENU,id="rlogic", name="R Logic"})
    M.combo:MenuElement({type=MENU,id="rsafety", name="R Safety"})
    M.combo:MenuElement({type=MENU,id="rmanual", name="R Manual"})
    M.combo:MenuElement({type=MENU,id="antimelee", name="Anti-Melee"})
    M.combo:MenuElement({id="mana", name="Min Mana % (Combo)", value=0, min=0, max=100, identifier="%"})

    -- Spells
    M.combo.spells:MenuElement({id="useQ", name="Use Q", value=true})
    M.combo.spells:MenuElement({id="useW", name="Use W", value=true})
    M.combo.spells:MenuElement({id="useE", name="Use E", value=true})
    M.combo.spells:MenuElement({id="useR", name="Use R (auto logic)", value=true})

    -- R Logic
    M.combo.rlogic:MenuElement({id="rPrefer", name="R Prefer Final Dist", value=500, min=200, max=1000, step=25})
    M.combo.rlogic:MenuElement({id="rChase", name="Enable Chase Logic", value=true})
    M.combo.rlogic:MenuElement({id="rChaseMin", name="R Chase Min Dist", value=600, min=100, max=1200, step=25})
    M.combo.rlogic:MenuElement({id="rChaseFollowMin", name="R Follow Min Dist", value=520, min=100, max=1200, step=25})
    M.combo.rlogic:MenuElement({id="autoChainR", name="Auto-Chain R Charges", value=true})
    M.combo.rlogic:MenuElement({id="rWall", name="Allow Wall R Dashes", value=true})
    M.combo.rlogic:MenuElement({id="rKillable", name="R if Killable", value=true})

    -- R Safety
    M.combo.rsafety:MenuElement({id="rMaxEnemiesEnd", name="R End Max Enemies (0=ignore)", value=2, min=0, max=5, step=1})
    M.combo.rsafety:MenuElement({id="rMinAllyRatio", name="Ally:Enemy Ratio x100", value=90, min=0, max=300, step=10})
    M.combo.rsafety:MenuElement({id="rNoMeleeCluster", name="Block if >=2 melee <350", value=true})
    M.combo.rsafety:MenuElement({id="rMinHpToDive", name="Min HP% to ignore safety", value=70, min=0, max=100, step=5, identifier="%"})
    M.combo.rsafety:MenuElement({id="rForceKillWindow", name="Override safety if killable", value=true})

    -- R Manual
    M.combo.rmanual:MenuElement({id="manualRKey", name="Manual R Key", key=string.byte("T"), toggle=false})
    M.combo.rmanual:MenuElement({id="escapeRKey", name="Escape R Key", key=string.byte("Z"), toggle=false})
    M.combo.rmanual:MenuElement({id="mouseRKey", name="R To Mouse Key", key=string.byte("Y"), toggle=false})
    M.combo.rmanual:MenuElement({id="manualOnly", name="Manual Only (Disable Auto R)", value=false})

    -- Anti-Melee
    M.combo.antimelee:MenuElement({id="antiMelee", name="Enable Anti-Melee R", value=true})
    M.combo.antimelee:MenuElement({id="antiMeleeRange", name="Trigger Dist", value=250, min=100, max=450, step=10})
    M.combo.antimelee:MenuElement({id="antiMeleeMin", name="Min Enemies", value=1, min=1, max=5, step=1})
    M.combo.antimelee:MenuElement({id="antiMeleeHp", name="Min HP%", value=65, min=0, max=100, identifier="%"})
    M.combo.antimelee:MenuElement({id="antiMeleePrefer", name="Desired Dist", value=650, min=400, max=900, step=25})

    -- Backwards compatibility aliases
    local c = M.combo
    local function alias(k, tbl, tk) c[k] = tbl[tk] end
    alias("useQ", c.spells, "useQ"); alias("useW", c.spells, "useW"); alias("useE", c.spells, "useE"); alias("useR", c.spells, "useR")
    alias("rPrefer", c.rlogic, "rPrefer"); alias("rChase", c.rlogic, "rChase"); alias("rChaseMin", c.rlogic, "rChaseMin")
    alias("rChaseFollowMin", c.rlogic, "rChaseFollowMin"); alias("autoChainR", c.rlogic, "autoChainR"); alias("rWall", c.rlogic, "rWall")
    alias("rKillable", c.rlogic, "rKillable")
    alias("rMaxEnemiesEnd", c.rsafety, "rMaxEnemiesEnd"); alias("rMinAllyRatio", c.rsafety, "rMinAllyRatio")
    alias("rNoMeleeCluster", c.rsafety, "rNoMeleeCluster"); alias("rMinHpToDive", c.rsafety, "rMinHpToDive"); alias("rForceKillWindow", c.rsafety, "rForceKillWindow")
    alias("manualRKey", c.rmanual, "manualRKey"); alias("escapeRKey", c.rmanual, "escapeRKey")
    alias("antiMelee", c.antimelee, "antiMelee"); alias("antiMeleeRange", c.antimelee, "antiMeleeRange")
    alias("antiMeleeMin", c.antimelee, "antiMeleeMin"); alias("antiMeleeHp", c.antimelee, "antiMeleeHp"); alias("antiMeleePrefer", c.antimelee, "antiMeleePrefer")

    M:MenuElement({type=MENU,id="eflash", name="E-Flash"})
    M.eflash:MenuElement({id="enable", name="Enable E-Flash (E then Flash)", value=true})
    M.eflash:MenuElement({id="key", name="E-Flash Key", key=string.byte("G"), toggle=false})
    M.eflash:MenuElement({id="onlyKill", name="Only if target Killable", value=false})

    M:MenuElement({type=MENU,id="harass", name="Harass"})
    M.harass:MenuElement({id="useQ", name="Use Q", value=true})
    M.harass:MenuElement({id="useW", name="Use W", value=true})
    M.harass:MenuElement({id="useE", name="Use E", value=false})
    M.harass:MenuElement({id="mana", name="Min Mana %", value=45,min=0,max=100,identifier="%"})

    M:MenuElement({type=MENU,id="clear", name="Lane Clear"})
    M.clear:MenuElement({id="useQ", name="Use Q", value=true})
    M.clear:MenuElement({id="qMin", name="Q if hits >= X minions", value=3,min=1,max=7,step=1})
    M.clear:MenuElement({id="mana", name="Min Mana %", value=45,min=0,max=100,identifier="%"})

    M:MenuElement({type=MENU,id="pred", name="Prediction"})
    M.pred:MenuElement({name=" ", drop={"Using DepressivePrediction"}})
    M.pred:MenuElement({id="QHit", name="Q Hitchance", value=2, drop={"Low","Normal","High","VeryHigh","Immobile"}})
    M.pred:MenuElement({id="EHit", name="E Hitchance", value=2, drop={"Low","Normal","High","VeryHigh","Immobile"}})

    M:MenuElement({type=MENU,id="draw", name="Drawing"})
    M.draw:MenuElement({id="ranges", name="Master Toggle", value=true})
    M.draw:MenuElement({id="dq", name="Q Range", value=true})
    M.draw:MenuElement({id="dw", name="W Range", value=true})
    M.draw:MenuElement({id="de", name="E Range", value=true})
    M.draw:MenuElement({id="dr", name="R Range", value=true})
    M.draw:MenuElement({id="showRPaths", name="Show R Candidates", value=true})
    M.draw:MenuElement({id="eFlash", name="E-Flash Ext Range", value=true})
    M.draw:MenuElement({id="bright", name="High Visibility Colors", value=true})
    M.draw:MenuElement({id="debug", name="Debug (print draw issues)", value=false})
    M.draw:MenuElement({id="rToggle", name="Show R toggleState", value=true})


    -- Debug / Utility
    M:MenuElement({type=MENU,id="debugTools", name="Debug / Tools"})
    -- VK_NUMPAD1 = 0x61; will attempt to use that scancode; if it fails user can rebind
    M.debugTools:MenuElement({id="printBuffsKey", name="Print Buffs (NumPad1)", key=0x61, toggle=false})

    return M
end

function Ahri:Mode()
    -- Try different orbwalkers in order of preference
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then
        local M = _G.SDK.Orbwalker.Modes
        if M[_G.SDK.ORBWALKER_MODE_COMBO] then return "Combo" end
        if M[_G.SDK.ORBWALKER_MODE_HARASS] then return "Harass" end
        if M[_G.SDK.ORBWALKER_MODE_LANECLEAR] or M[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] then return "Clear" end
    end
    if _G.GOS and _G.GOS.GetMode then
        local m = _G.GOS:GetMode()
        if m==1 then return "Combo" elseif m==2 then return "Harass" elseif m==3 then return "Clear" end
    end
    return "None"
end

function Ahri:OnTick()
    local mode = self:Mode()
    local target = GetTarget(1300)
    if self.rActive and Game.Timer() > self.rExpireTime then
        self.rActive = false
        self.rChargesRemaining = 0
    end
    -- Execute scheduled flash for E-Flash combo
    if scheduledEFlash and Game.Timer() >= scheduledEFlash.time then
        local flashSlot = GetFlashSlot()
        if flashSlot then
            Control.CastSpell(scheduledEFlash.hk, scheduledEFlash.pos)
        end
        scheduledEFlash = nil
    end
    if self.Menu.eflash.enable:Value() and self.Menu.eflash.key:Value() then
        if target and (not self.Menu.eflash.onlyKill:Value() or target.health < TotalComboDamage(target)) then
            TryEFlash(target)
        end
    end
    -- Manual R logic (independent from orbwalker mode)
    -- Escape key has highest priority
    if self.Menu and self.Menu.combo and self.Menu.combo.rmanual then
        local rm = self.Menu.combo.rmanual
        -- Escape R: best escape dash scoring; ignores auto logic gating
        if rm.escapeRKey:Value() then
            if target or self.rActive or Ready(_R) then
                -- reuse ExecuteR in escape mode; pass current target (maybe nil)
                self:ExecuteR(target, true)
                return -- do not process further same tick (avoid double casting)
            end
        end
        -- R to mouse position key
        if rm.mouseRKey:Value() then
            self:RToMouse()
            -- don't return; allow offensive manual below if desired (user can hold both)
        end
        -- Offensive manual R: attempt dash following full safety / scoring logic regardless of auto trigger conditions
        if rm.manualRKey:Value() then
            if not target then target = GetTarget(1300) end
            if target then
                self:ExecuteR(target, false)
            end
        end
    end
    if mode=="Combo" then self:Combo(target)
    elseif mode=="Harass" then self:Harass(target)
    elseif mode=="Clear" then self:Clear()
    end

    -- On-demand buff print (edge-triggered while key held, throttled)
    if self.Menu and self.Menu.debugTools and self.Menu.debugTools.printBuffsKey and self.Menu.debugTools.printBuffsKey:Value() then
        local now = Game.Timer()
        self._lastBuffPrint = self._lastBuffPrint or 0
        if now - self._lastBuffPrint > 0.4 then
            self._lastBuffPrint = now
            -- Give me the spelldata of R
            local spellData = myHero:GetSpellData(_R)
            print(spellData)
            print("Buffs on me:")
            -- New logic: if "AhriR" buff exists and buff.stacks > 0, R is available
        end
    end
end

function Ahri:CastQ(target)
    if self.Menu and self.Menu.combo and self.Menu.combo.mana and (myHero.mana/myHero.maxMana*100) < self.Menu.combo.mana:Value() then return end
    if not (target and self.Menu.combo.useQ:Value() and Ready(_Q) and InRange(_Q,target)) then return end
    if Game.Timer() - lastCastTimes[_Q] < CAST_DELAY then return end
    local needed = self.Menu.pred and self.Menu.pred.QHit and self.Menu.pred.QHit:Value() or 1
    if not CastQPred(target, needed) then
        -- fallback direct cast
        Control.CastSpell(HK_Q, target.pos)
    end
    lastCastTimes[_Q] = Game.Timer()
end
function Ahri:CastE(target)
    if self.Menu and self.Menu.combo and self.Menu.combo.mana and (myHero.mana/myHero.maxMana*100) < self.Menu.combo.mana:Value() then return end
    if not (target and self.Menu.combo.useE:Value() and Ready(_E) and InRange(_E,target)) then return end
    if Game.Timer() - lastCastTimes[_E] < CAST_DELAY then return end
    local needed = self.Menu.pred and self.Menu.pred.EHit and self.Menu.pred.EHit:Value() or 1
    if not CastEPred(target, needed) then
        -- Only fallback if no minion collision on direct line
        if not EMinionCollision(myHero.pos, target.pos, target) then
            Control.CastSpell(HK_E, target.pos)
        end
    end
    lastCastTimes[_E] = Game.Timer()
end
function Ahri:CastW(target)
    if self.Menu and self.Menu.combo and self.Menu.combo.mana and (myHero.mana/myHero.maxMana*100) < self.Menu.combo.mana:Value() then return end
    if target and self.Menu.combo.useW:Value() and Ready(_W) and InRange(_W, target) then
        if Game.Timer() - lastCastTimes[_W] < CAST_DELAY then return end
        Control.CastSpell(HK_W)
        lastCastTimes[_W] = Game.Timer()
    end
end

function Ahri:ShouldAutoR(target)
    if self.Menu and self.Menu.combo and self.Menu.combo.rmanual and self.Menu.combo.rmanual.manualOnly and self.Menu.combo.rmanual.manualOnly:Value() then return false end
    if not target or not self.Menu.combo.useR:Value() then return false end
    if self.rLock then return false end
    if self.rActive and self.rChargesRemaining<=0 then return false end
    if not self.rActive then
        if not Ready(_R) then return false end
        if self.Menu.combo.rKillable:Value() and target.health < TotalComboDamage(target)*0.6 then return true end
        if self.Menu.combo.rChase:Value() then
            local d = Dist2D(myHero.pos,target.pos)
            local minD = self.Menu.combo.rChaseMin:Value()
            if d>minD and d<1000 then return true end
        end
        return false
    else
        if self.rChargesRemaining <= 0 then return false end
        -- Only auto spend remaining charges if enabled or kill secure
        if not self.Menu.combo.autoChainR:Value() then
            if self.Menu.combo.rKillable:Value() and target.health < TotalComboDamage(target)*0.9 then
                return true
            end
            return false
        end
        if self.Menu.combo.rKillable:Value() and target.health < TotalComboDamage(target)*0.9 then return true end
        if self.Menu.combo.rChase:Value() then
            local d = Dist2D(myHero.pos,target.pos)
            local followMin = self.Menu.combo.rChaseFollowMin:Value()
            if d>followMin and d<1050 then return true end
        end
        return false
    end
end

-- Defensive anti-melee R logic
function Ahri:DoAntiMeleeR()
    local menu = self.Menu.combo
    if not menu.antiMelee or not menu.antiMelee:Value() then return false end
    -- Only use anti-melee for the first dash (don't chain defensive dashes automatically)
    if self.rActive then return false end
    local myHpPct = myHero.health / myHero.maxHealth * 100
    local hpThresh = menu.antiMeleeHp:Value()
    if hpThresh < 100 and myHpPct > hpThresh then return false end -- if set to 100 = always allow
    local triggerDist = menu.antiMeleeRange:Value()
    local minReq = menu.antiMeleeMin:Value()
    local threats = {}
    for i=1,Game.HeroCount() do
        local e = Game.Hero(i)
        if e and e.team~=myHero.team and not e.dead and e.isTargetable then
            local dist = Dist2D(myHero.pos,e.pos)
            local erange = (e.range or 550)
            local isMelee = erange < 350 -- heuristic
            if isMelee and dist < triggerDist+50 then -- small buffer
                threats[#threats+1] = {obj=e, dist=dist}
            end
        end
    end
    if #threats < minReq then return false end
    -- Need R availability
    if (not self.rActive and not Ready(_R)) or (self.rActive and self.rChargesRemaining<=0) then return false end
    -- Generate candidate positions (circle around Ahri)
    local bestPos, bestScore = nil, -1e9
    local desired = menu.antiMeleePrefer:Value()
    for i=1,16 do
        local ang = (2*math.pi/16)*i
        local pos = myHero.pos + Vector(math.cos(ang)*450, 0, math.sin(ang)*450)
        -- Score: maximize min distance to each threat after dash, and closeness to desired distance from closest threat
        local minAfter = 1e9
        local sumAfter = 0
        for _,t in ipairs(threats) do
            local d = Dist2D(pos, t.obj.pos)
            if d < minAfter then minAfter = d end
            sumAfter = sumAfter + d
        end
        local avgAfter = sumAfter / #threats
        local desiredScore = -math.abs(avgAfter - desired)
        -- Penalize wall if walls not allowed
        local wallPenalty = 0
        if MapPosition and MapPosition.intersectsWall and MapPosition:inWall(pos) then wallPenalty = wallPenalty - 400 end
        local score = minAfter*1.2 + desiredScore + wallPenalty
        if score > bestScore then bestScore = score; bestPos = pos end
    end
    if bestPos then
        Control.CastSpell(HK_R, bestPos)
        return true
    end
    return false
end

function Ahri:ExecuteR(target, escape)
    if self.rLock then return end
    if (not self.rActive and not Ready(_R)) or (self.rActive and self.rChargesRemaining<=0) then return end
    local needDelay = self.rActive and R_CHAIN_DELAY or CAST_DELAY
    if Game.Timer() - lastCastTimes[_R] < needDelay then return end
    local dashes = target and GetRDashes(target) or {}
    local castPos
    if escape then
        local enemies = GetEnemies(); local worst= -1e9
        for _,d in ipairs(dashes) do
            local minDist=1e9
            for _,e in ipairs(enemies) do
                local dist = Dist2D(d.pos,e.pos); if dist < minDist then minDist=dist end
            end
            local score = minDist + (d.crosses and 150 or 0)
            if score>worst then worst=score; castPos=d.pos end
        end
    else
        -- Re-score candidates to prefer ending near preferred distance (not too close)
        local prefer = self.Menu.combo.rPrefer:Value()
        local bestScore = -math.huge
        local cfg = self.Menu.combo
        local maxEnemiesEnd = cfg.rMaxEnemiesEnd:Value()
        local minAllyRatio = cfg.rMinAllyRatio:Value() / 100 -- allies >= ratio * enemies
        local blockMeleeCluster = cfg.rNoMeleeCluster:Value()
        local hpOk = (myHero.health / myHero.maxHealth * 100) >= cfg.rMinHpToDive:Value()
        local allowKillOverride = cfg.rForceKillWindow:Value()
        local function CountNearby(pos, team, range)
            local count=0
            for i=1,Game.HeroCount() do
                local h=Game.Hero(i)
                if h and h.valid and not h.dead and h.isTargetable and h.team==team and Dist2DSqr(pos,h.pos) <= range*range then
                    count = count + 1
                end
            end
            return count
        end
        local function CountMeleeEnemies(pos, range)
            local c=0
            for i=1,Game.HeroCount() do
                local h=Game.Hero(i)
                if h and h.valid and not h.dead and h.team~=myHero.team and h.isTargetable and Dist2DSqr(pos,h.pos) <= range*range then
                    local er = h.range or 550
                    if er < 350 then c=c+1 end
                end
            end
            return c
        end
        for _,d in ipairs(dashes) do
            local distAfter = Dist2D(d.pos, target.pos)
            local distScore = -math.abs(distAfter - prefer)
            if distAfter < prefer*0.75 then distScore = distScore - 150 end
            if d.improve or (cfg.rWall:Value() and d.crosses) then
                -- Safety filters
                local enemiesEnd = CountNearby(d.pos, target.team, 600)
                local alliesEnd = CountNearby(d.pos, myHero.team, 600)
                local meleeCluster = CountMeleeEnemies(d.pos, 350)
                local safe = true
                if maxEnemiesEnd > 0 and enemiesEnd > maxEnemiesEnd and not hpOk then safe=false end
                if blockMeleeCluster and meleeCluster >=2 and not hpOk then safe=false end
                if minAllyRatio > 0 and alliesEnd > 0 and enemiesEnd > 0 and (alliesEnd / enemiesEnd) < minAllyRatio and not hpOk then safe=false end
                -- Override safety if killable and option enabled
                if not safe and allowKillOverride and self.Menu.combo.rKillable:Value() then
                    local wouldKill = (TotalComboDamage and TotalComboDamage(target) or 0) >= target.health
                    if wouldKill then safe = true end
                end
                if safe then
                    local wallBonus = (d.crosses and cfg.rWall:Value()) and 20 or 0
                    local score = distScore + wallBonus - (enemiesEnd*5) + (alliesEnd*3)
                    if score > bestScore then
                        bestScore = score
                        castPos = d.pos
                    end
                end
            end
        end
    end
    if castPos then
        -- Final safety: do not cast if charges depleted
        if self.rActive and self.rChargesRemaining<=0 then return end
        Control.CastSpell(HK_R, castPos)
        lastCastTimes[_R] = Game.Timer()
        if self.rActive and self.rChargesRemaining>0 then
            self.rChargesRemaining = math.max(0, self.rChargesRemaining - 1)
            if self.rChargesRemaining<=0 then
                self.rActive=false
                self.rLock = true
            end
        end
    end
end

function Ahri:Combo(target)
    -- Always evaluate defensive anti-melee first (independent of target)
    if self:DoAntiMeleeR() then return end
    if not target then return end
    -- Mana gate for offensive combo spells (does not block defensive R logic)
    local comboManaOK = true
    if self.Menu and self.Menu.combo and self.Menu.combo.mana then
        comboManaOK = (myHero.mana/myHero.maxMana*100) >= self.Menu.combo.mana:Value()
    end
    -- Cast W before attempting any R (requested change). Only if mana ok.
    if comboManaOK then self:CastW(target) end
    -- Auto logic only here (manual handled globally in OnTick)
    if self:ShouldAutoR(target) then
        self:ExecuteR(target,false)
    end
    if comboManaOK then
        self:CastE(target)
        self:CastQ(target)
        -- W already attempted pre-R; try again only if not on cooldown and still not cast (low impact duplicate check handled by cooldown gate)
        self:CastW(target)
    end
end

-- Cast R toward current mouse position (or cursor), clamped to max dash distance.
function Ahri:RToMouse()
    if self.rLock then return end
    local mouse = (mousePos or _G.mousePos or _G.cursorPos or myHero.pos)
    if not mouse then return end
    if (not self.rActive and not Ready(_R)) or (self.rActive and self.rChargesRemaining<=0) then return end
    local needDelay = self.rActive and R_CHAIN_DELAY or CAST_DELAY
    if Game.Timer() - lastCastTimes[_R] < needDelay then return end
    local base = myHero.pos
    local dx = mouse.x - base.x
    local dz = (mouse.z or mouse.y) - base.z
    local len = math.sqrt(dx*dx + dz*dz)
    if len == 0 then return end
    local maxR = 450
    local scale = (len > maxR) and (maxR/len) or 1
    local castPos = base + Vector(dx*scale, 0, dz*scale)
    Control.CastSpell(HK_R, castPos)
    lastCastTimes[_R] = Game.Timer()
    if self.rActive and self.rChargesRemaining>0 then
        self.rChargesRemaining = math.max(0, self.rChargesRemaining - 1)
        if self.rChargesRemaining<=0 then
            self.rActive=false
            self.rLock = true
        end
    end
end

function Ahri:Harass(target)
    if not target then return end
    if myHero.mana/myHero.maxMana*100 < self.Menu.harass.mana:Value() then return end
    if self.Menu.harass.useE:Value() then self:CastE(target) end
    if self.Menu.harass.useQ:Value() then self:CastQ(target) end
    if self.Menu.harass.useW:Value() then self:CastW(target) end
end

function Ahri:Clear()
    if myHero.mana/myHero.maxMana*100 < self.Menu.clear.mana:Value() then return end
    if self.Menu.clear.useQ:Value() and Ready(_Q) then
        local now = Game.Timer()
        if now - self.lastClearScanTime >= self.clearScanInterval then
            self.lastClearScanTime = now
            local minions = GetEnemyMinions()
            local bestPos,bestCount=nil,0
            local len = #minions
            for i=1,len do
                local m = minions[i]
                local count = 0
                local mp = m.pos
                for j=i,len do -- j=i forward reduces duplicate distance checks
                    local m2 = minions[j]
                    if Dist2DSqr(mp, m2.pos) < (90*90) then count = count + 1 end
                end
                if count > bestCount then
                    bestCount = count
                    bestPos = mp
                end
            end
            self.cachedClearQPos = bestPos
            self.cachedClearQCount = bestCount
        end
        if self.cachedClearQPos and self.cachedClearQCount >= self.Menu.clear.qMin:Value() then
            Control.CastSpell(HK_Q, self.cachedClearQPos)
        end
    end
end

function Ahri:OnDraw()
    local draw = self.Menu.draw
    if not draw or not draw.ranges:Value() then return end
    local useBright = draw.bright and draw.bright:Value()
    local alphaMain = useBright and 160 or 70
    local alphaSub = useBright and 140 or 55
    local alphaPath = useBright and 170 or 120
    local hasDrawLib = (Draw and Draw.Circle and Draw.Color)
    local hasLegacy = (DrawCircle and DrawColor)
    if not hasDrawLib and not hasLegacy then
        if draw.debug and draw.debug:Value() then print("[Ahri Draw] No drawing library available") end
        return
    end
    local function Circle(pos, radius, color)
        if hasDrawLib then
            Draw.Circle(pos, radius, 1, color)
        elseif hasLegacy then
            DrawCircle(pos, radius, 1, color)
        end
    end
    local function Col(a,r,g,b)
        if hasDrawLib then return Draw.Color(a,r,g,b) end
        if DrawColor then return DrawColor(a,r,g,b) end
        return 0xFFFFFFFF
    end
    local ok, err = pcall(function()
        if draw.dq:Value() and Ready(_Q) then Circle(myHero.pos,880, Col(alphaMain,120,200,255)) end
        if draw.dw:Value() and Ready(_W) then Circle(myHero.pos,700, Col(alphaSub,120,255,120)) end
        if draw.de:Value() and Ready(_E) then Circle(myHero.pos,975, Col(alphaMain,255,120,255)) end
        if draw.dr:Value() and (Ready(_R) or self.rActive) then Circle(myHero.pos,450, Col(alphaSub,255,255,120)) end
        if draw.eFlash:Value() then
            local flash = GetFlashSlot()
            if flash and Ready(_E) then Circle(myHero.pos, 975+400, Col(alphaSub,255,255,0)) end
        end
        if draw.showRPaths:Value() and (Ready(_R) or self.rActive) then
            local target = GetTarget(1300)
            if target then
                local list = GetRDashes(target)
                for i=1, math.min(6,#list) do
                    local d = list[i]
                    Circle(d.pos, 40, d.crosses and Col(alphaPath,255,80,80) or Col(alphaPath,80,160,255))
                end
            end
        end
        if self.rActive then
            local txt = string.format("R Charges: %d (%.1fs)", self.rChargesRemaining, math.max(0, self.rExpireTime-Game.Timer()))
            if Draw.Text then Draw.Text(txt, 14, myHero.pos2D.x-40, myHero.pos2D.y-15, Col(255,255,200,80)) elseif DrawText then DrawText(txt,14,myHero.pos2D.x-40,myHero.pos2D.y-15,Col(255,255,200,80)) end
        end
        if draw.rToggle and draw.rToggle:Value() then
            local sd = myHero:GetSpellData(_R)
            local ts = sd and sd.toggleState or "nil"
            local txt2 = "R toggleState: "..tostring(ts)
            local yOffset = self.rActive and 0 or -15
            if Draw.Text then Draw.Text(txt2, 14, myHero.pos2D.x-40, myHero.pos2D.y-30 + yOffset, Col(255,200,255,120)) elseif DrawText then DrawText(txt2,14,myHero.pos2D.x-40,myHero.pos2D.y-30 + yOffset,Col(255,200,255,120)) end
        end
    end)
    if not ok and draw.debug and draw.debug:Value() then
        print("[Ahri Draw Error] "..tostring(err))
    end
end

local function SafeInitAhri()
    if not MenuElement then
        if print then print("[Depressive - Ahri] MenuElement not ready, retry next tick") end
        return false
    end
    local ok, obj = pcall(function() return Ahri:__init() end)
    if not ok or not obj then
        if print then print("[Depressive - Ahri] Init error: "..tostring(obj)) end
        return false
    end
    _G.DepressiveAhri = obj
    _G.__DEPRESSIVE_NEXT_AHRI_LOADED = true
    _G.__AHRI_DEPRESSIVE_LOADED = true
    _G.DepressiveAIONextLoadedChampion = true
    if print then print("[Depressive - Ahri] Initialized") end
    return true
end

if not SafeInitAhri() then
    local retries = 0
    Callback.Add("Tick", function()
        if _G.__DEPRESSIVE_NEXT_AHRI_LOADED then return end
        if SafeInitAhri() then return end
        retries = retries + 1
        if retries > 120 then -- ~2s
            if print then print("[Depressive - Ahri] Failed to init after retries") end
            Callback.Del("Tick", _G.__AHRI_RETRY_TICK)
        end
    end)
end

-- Draw callback registration
Callback.Add("Draw", function()
    if _G.DepressiveAhri then _G.DepressiveAhri:OnDraw() end
end)
