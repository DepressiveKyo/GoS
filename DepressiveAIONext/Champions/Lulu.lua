local VERSION = "1.0"
if _G.__DEPRESSIVE_NEXT_LULU_LOADED then return end
if myHero.charName ~= "Lulu" then return end
_G.__DEPRESSIVE_NEXT_LULU_LOADED = true

-- Required libraries for evade system
require "MapPositionGOS"
require "DamageLib"
require "2DGeometry"

-- Prediction library load (DepressivePrediction)
local DepressivePrediction = require("DepressivePrediction")
if not DepressivePrediction then
    print("[Lulu] DepressivePrediction not found, using basic prediction")
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
    return sd and sd.level > 0 and sd.currentCd == 0 and sd.mana <= myHero.mana and Game.CanUseSpell(slot) == 0 
end

local function MyHeroNotReady()
    return myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading)
end

-- Spell ranges based on wiki data
local SPELL_RANGES = {
    [_Q] = 950,  -- Glitterlance
    [_W] = 650,  -- Whimsy
    [_E] = 650,  -- Help, Pix!
    [_R] = 900   -- Wild Growth
}

local function InRange(slot, target)
    if not target then return false end
    local r = SPELL_RANGES[slot]
    if not r then return false end
    -- Use DepressivePrediction's effective range calculation if available
    if DepressivePrediction and DepressivePrediction.IsInEffectiveRange then
        return DepressivePrediction.IsInEffectiveRange(myHero, target, r, true)
    end
    return Dist2D(myHero.pos, target.pos) <= r + 5 -- small buffer
end

-- Enemy detection system
local _EnemyCache = {t = 0, list = {}}
local function GetEnemyHeroes()
    local now = Game.Timer and Game.Timer() or os.clock()
    if now - _EnemyCache.t > 0.25 then
        local L = {}
        for i = 1, Game.HeroCount() do 
            local h = Game.Hero(i)
            if h and h.team ~= myHero.team and IsValid(h) then 
                L[#L + 1] = h 
            end
        end
        _EnemyCache.list = L
        _EnemyCache.t = now
    end
    return _EnemyCache.list
end

-- Ally detection system
local _AllyCache = {t = 0, list = {}}
local function GetAllyHeroes()
    local now = Game.Timer and Game.Timer() or os.clock()
    if now - _AllyCache.t > 0.25 then
        local L = {}
        for i = 1, Game.HeroCount() do 
            local h = Game.Hero(i)
            if h and h.team == myHero.team and h.charName ~= myHero.charName and IsValid(h) then 
                L[#L + 1] = h 
            end
        end
        _AllyCache.list = L
        _AllyCache.t = now
    end
    return _AllyCache.list
end

local function GetTarget(range)
    local best, bd = nil, 1e9
    local enemies = GetEnemyHeroes()
    
    for _, e in ipairs(enemies) do 
        local d = Dist2D(myHero.pos, e.pos)
        if d < range and d < bd then 
            best = e
            bd = d 
        end 
    end
    
    return best
end

-- Damage calculations based on wiki data
local function QDamage(target)
    local q = myHero:GetSpellData(_Q).level
    if q == 0 then return 0 end
    local base = ({60, 95, 130, 165, 200})[q] or 0
    local ap = myHero.ap * 0.5
    return base + ap
end

local function EDamage(target)
    local e = myHero:GetSpellData(_E).level
    if e == 0 then return 0 end
    local base = ({80, 120, 160, 200, 240})[e] or 0
    return base + myHero.ap * 0.4
end

local function RDamage(target)
    local r = myHero:GetSpellData(_R).level
    if r == 0 then return 0 end
    local base = ({300, 450, 600})[r] or 0
    return base + myHero.ap * 0.5
end

-- Spell blocking logic from DepressiveActivator
local function ShouldBlockSpell(enemy, spellName, spellSlot)
    if not enemy or not enemy.activeSpell or not enemy.activeSpell.valid then
        return false
    end
    
    local activeSpell = enemy.activeSpell
    if not activeSpell.name then return false end
    
    -- Check if the spell is targeting us or an ally
    local isTargetingUs = activeSpell.target == myHero.handle
    local isTargetingAlly = false
    local targetAlly = nil
    
    for _, ally in ipairs(GetAllyHeroes()) do
        if activeSpell.target == ally.handle then
            isTargetingAlly = true
            targetAlly = ally
            break
        end
    end
    
    if not isTargetingUs and not isTargetingAlly then
        return false
    end
    
    -- Check if we should block this specific spell
    local shouldBlock = false
    
    -- Q, W, E, R spell blocking
    if activeSpell.name == enemy:GetSpellData(_Q).name or
       activeSpell.name == enemy:GetSpellData(_W).name or
       activeSpell.name == enemy:GetSpellData(_E).name or
       activeSpell.name == enemy:GetSpellData(_R).name then
        shouldBlock = true
    end
    
    -- Special cases (only spell-based attacks, no basic attacks)
    local specialSpells = {
        "GarenQAttack", "LeonaShieldOfDaybreakAttack", "RenektonExecute", 
        "RenektonSuperExecute", "PowerFistAttack", "PykeQ"
    }
    
    for _, specialSpell in ipairs(specialSpells) do
        if activeSpell.name == specialSpell then
            shouldBlock = true
            break
        end
    end
    
    return shouldBlock, isTargetingUs, targetAlly
end

-- Buff detection for W buffing allies
local WBuffs = {
    ["Ashe"] = {"AsheQ"},
    ["Hecarim"] = {"HecarimRamp"},
    ["Kaisa"] = {"KaisaE"},
    ["Kayle"] = {"KayleE"},
    ["Kennen"] = {"KennenShurikenStorm"},
    ["KogMaw"] = {"KogMawBioArcaneBarrage"},
    ["MasterYi"] = {"Highlander"},
    ["Quinn"] = {"QuinnE"},
    ["Rammus"] = {"PowerBall"},
    ["Rengar"] = {"RengarR"},
    ["Samira"] = {"SamiraE"},
    ["Singed"] = {"InsanityPotion"},
    ["Skarner"] = {"SkarnerImpale"},
    ["Tristana"] = {"TristanaE"},
    ["Twitch"] = {"TwitchFullAutomatic"},
    ["Varus"] = {"VarusR"},
    ["Vayne"] = {"VayneInquisition"},
    ["Xayah"] = {"XayahW"},
}

local function ShouldBuffAlly(ally)
    if not ally or not ally.activeSpell or not ally.activeSpell.valid then
        return false
    end
    
    local buffs = WBuffs[ally.charName]
    if not buffs then return false end
    
    for _, buffName in ipairs(buffs) do
        if ally.activeSpell.name == buffName then
            return true
        end
    end
    
    return false
end

-- Check if ally already has Lulu's E shield
local function HasLuluShield(ally)
    if not ally then return false end
    
    for i = 0, ally.buffCount do
        local buff = ally:GetBuff(i)
        if buff and buff.name and buff.name:lower():find("lulu") and buff.name:lower():find("pix") then
            return true
        end
    end
    return false
end

-- Check if ally is on shield cooldown
local function IsOnShieldCooldown(self, ally)
    if not ally then return true end
    local allyHandle = ally.handle
    local now = Game.Timer()
    local cooldownTime = self.Menu and self.Menu.auto and self.Menu.auto.shieldCooldown and self.Menu.auto.shieldCooldown:Value() or self.shieldCooldownTime
    
    if self.shieldCooldowns[allyHandle] then
        if now - self.shieldCooldowns[allyHandle] < cooldownTime then
            return true
        else
            -- Remove expired cooldown
            self.shieldCooldowns[allyHandle] = nil
        end
    end
    return false
end

-- Set shield cooldown for ally
local function SetShieldCooldown(self, ally)
    if ally then
        self.shieldCooldowns[ally.handle] = Game.Timer()
    end
end

-- Class
local Lulu = {}
Lulu.__index = Lulu

function Lulu:__init()
    local o = setmetatable({}, Lulu)
    o.lastCastTimes = {[_Q] = 0, [_W] = 0, [_E] = 0, [_R] = 0}
    o.castDelay = 0.25
    o.shieldCooldowns = {} -- Track shield cooldowns per ally
    o.shieldCooldownTime = 3.0 -- Default 3 seconds cooldown between shields on same ally
    o.Menu = o:CreateMenu()
    
    -- Initialize enemy and ally detection at start
    Callback.Add("Load", function()
        GetEnemyHeroes()
        GetAllyHeroes()
    end)
    
    return o
end

function Lulu:CreateMenu()
    local M = MenuElement({type = MENU, id = "DepressiveLulu", name = "Depressive - Lulu"})
    M:MenuElement({name = " ", drop = {"Version " .. VERSION}})

    M:MenuElement({type = MENU, id = "combo", name = "Combo"})
    M.combo:MenuElement({type = MENU, id = "spells", name = "Spells"})
    M.combo:MenuElement({type = MENU, id = "whimsy", name = "Whimsy (W) Logic"})
    M.combo:MenuElement({type = MENU, id = "wildgrowth", name = "Wild Growth (R) Logic"})
    M.combo:MenuElement({id = "mana", name = "Min Mana % (Combo)", value = 0, min = 0, max = 100, identifier = "%"})

    -- Spells
    M.combo.spells:MenuElement({id = "useQ", name = "Use Q (Glitterlance)", value = true})
    M.combo.spells:MenuElement({id = "useW", name = "Use W (Whimsy)", value = true})
    M.combo.spells:MenuElement({id = "useE", name = "Use E (Help, Pix!)", value = true})
    M.combo.spells:MenuElement({id = "useR", name = "Use R (Wild Growth)", value = true})

    -- Whimsy Logic
    M.combo.whimsy:MenuElement({id = "blockSpells", name = "Block Enemy Spells", value = true})
    M.combo.whimsy:MenuElement({id = "buffAllies", name = "Buff Ally Spells", value = true})
    M.combo.whimsy:MenuElement({id = "interruptChannels", name = "Interrupt Channels", value = true})
    M.combo.whimsy:MenuElement({id = "healthThreshold", name = "Use if HP <=", value = 80, min = 5, max = 100, step = 5, identifier = "%"})

    -- Wild Growth Logic
    M.combo.wildgrowth:MenuElement({id = "minEnemies", name = "Min Enemies Around Ally", value = 1, min = 1, max = 5, step = 1})
    M.combo.wildgrowth:MenuElement({id = "allyHealthThreshold", name = "Ally HP <=", value = 60, min = 5, max = 100, step = 5, identifier = "%"})
    M.combo.wildgrowth:MenuElement({id = "selfHealthThreshold", name = "Self HP <=", value = 40, min = 5, max = 100, step = 5, identifier = "%"})

    M:MenuElement({type = MENU, id = "harass", name = "Harass"})
    M.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
    M.harass:MenuElement({id = "useE", name = "Use E (Shield)", value = false})
    M.harass:MenuElement({id = "mana", name = "Min Mana %", value = 45, min = 0, max = 100, identifier = "%"})

    M:MenuElement({type = MENU, id = "auto", name = "Auto Protection"})
    M.auto:MenuElement({id = "useW", name = "Auto W (Block Spells)", value = true})
    M.auto:MenuElement({id = "useR", name = "Auto R (Save Allies)", value = true})
    M.auto:MenuElement({id = "rHealthThreshold", name = "R Save HP <=", value = 35, min = 5, max = 100, step = 5, identifier = "%"})

    M:MenuElement({type = MENU, id = "block", name = "Block System"})
    M.block:MenuElement({id = "enabled", name = "Enable Block", value = true})
    M.block:MenuElement({id = "useE", name = "Use E (Help, Pix!) to Block", value = true})
    M.block:MenuElement({id = "protectSelf", name = "Protect Self", value = true})
    M.block:MenuElement({id = "protectAllies", name = "Protect Allies", value = true})
    M.block:MenuElement({id = "healthThreshold", name = "Use if HP <=", value = 80, min = 5, max = 100, step = 5, identifier = "%"})
    M.block:MenuElement({id = "aggressiveMode", name = "Aggressive Mode (block more spells)", value = true})
    M.block:MenuElement({id = "debugMode", name = "Debug Mode (print when blocking)", value = false})

    M:MenuElement({type = MENU, id = "draw", name = "Drawing"})
    M.draw:MenuElement({id = "ranges", name = "Master Toggle", value = true})
    M.draw:MenuElement({id = "dq", name = "Q Range", value = true})
    M.draw:MenuElement({id = "dwe", name = "W/E Range", value = true})
    M.draw:MenuElement({id = "dr", name = "R Range", value = false})
    M.draw:MenuElement({id = "bright", name = "High Visibility Colors", value = true})
    M.draw:MenuElement({id = "debug", name = "Debug (print draw issues)", value = false})

    -- Backwards compatibility aliases
    local c = M.combo
    local function alias(k, tbl, tk) c[k] = tbl[tk] end
    alias("useQ", c.spells, "useQ")
    alias("useW", c.spells, "useW")
    alias("useE", c.spells, "useE")
    alias("useR", c.spells, "useR")

    return M
end

function Lulu:Mode()
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then 
        local M = _G.SDK.Orbwalker.Modes
        if M[_G.SDK.ORBWALKER_MODE_COMBO] or M.Combo then return "Combo" end
        if M[_G.SDK.ORBWALKER_MODE_HARASS] or M.Harass then return "Harass" end
        if M[_G.SDK.ORBWALKER_MODE_LANECLEAR] or M.Clear or M.LaneClear then return "Clear" end 
    end
    if _G.GOS and _G.GOS.GetMode then 
        local m = _G.GOS:GetMode()
        if m == 1 then return "Combo" elseif m == 2 then return "Harass" elseif m == 3 then return "Clear" end 
    end
    return "None"
end

function Lulu:OnTick()
    if MyHeroNotReady() then return end
    
    local mode = self:Mode()
    local target = GetTarget(1000)
    
    -- Always run block system first (highest priority)
    self:BlockSystem()
    
    -- Always run auto protection
    self:AutoProtection()
    
    if mode == "Combo" then 
        self:Combo(target)
    elseif mode == "Harass" then 
        self:Harass(target)
    end
end

function Lulu:CastQ(target)
    if not Ready(_Q) or not target then return false end
    if Game.Timer() - self.lastCastTimes[_Q] < self.castDelay then return false end
    if not self.Menu or not self.Menu.combo or not self.Menu.combo.spells or not self.Menu.combo.spells.useQ or not self.Menu.combo.spells.useQ:Value() then return false end
    
    -- Use DepressivePrediction for Q (Glitterlance)
    local pred = _G.DepressivePrediction.SpellPrediction({
        Type = _G.DepressivePrediction.SPELLTYPE_LINE,
        Speed = 1450,
        Range = 950,
        Delay = 0.25,
        Radius = 60,
        Collision = false,
        CollisionTypes = {}
    })
    
    local result = pred:GetPrediction(target, myHero)
    if result and result.HitChance >= _G.DepressivePrediction.HITCHANCE_NORMAL then
        Control.CastSpell(HK_Q, result.CastPosition)
        self.lastCastTimes[_Q] = Game.Timer()
        return true
    end
    
    return false
end

function Lulu:CastW(target, isAlly)
    if not Ready(_W) then return false end
    if Game.Timer() - self.lastCastTimes[_W] < self.castDelay then return false end
    if not target then return false end
    
    -- Check if we should use W
    local shouldUse = false
    
    if isAlly then
        -- Buff ally
        if self.Menu.combo.whimsy.buffAllies:Value() and ShouldBuffAlly(target) then
            shouldUse = true
        end
    else
        -- Block enemy spell
        if self.Menu.combo.whimsy.blockSpells:Value() then
            local shouldBlock, isTargetingUs, targetAlly = ShouldBlockSpell(target, nil, nil)
            if shouldBlock then
                shouldUse = true
            end
        end
    end
    
    if shouldUse then
        Control.CastSpell(HK_W, target)
        self.lastCastTimes[_W] = Game.Timer()
        return true
    end
    
    return false
end

function Lulu:CastE(target, isAlly)
    if not Ready(_E) then return false end
    if Game.Timer() - self.lastCastTimes[_E] < self.castDelay then return false end
    if not target then return false end
    
    -- Check if target already has shield (only for allies)
    if isAlly and HasLuluShield(target) then return false end
    
    -- Check shield cooldown (only for allies)
    if isAlly and IsOnShieldCooldown(self, target) then return false end
    
    -- E is targeted spell (Help, Pix!) - no prediction needed
    Control.CastSpell(HK_E, target)
    self.lastCastTimes[_E] = Game.Timer()
    
    -- Set cooldown for allies
    if isAlly then
        SetShieldCooldown(self, target)
    end
    
    return true
end

function Lulu:CastR(target)
    if not Ready(_R) then return false end
    if Game.Timer() - self.lastCastTimes[_R] < self.castDelay then return false end
    if not target then return false end
    
    -- R is targeted spell (Wild Growth) - no prediction needed
    Control.CastSpell(HK_R, target)
    self.lastCastTimes[_R] = Game.Timer()
    
    
    return true
end

function Lulu:Combo(target)
    if not target then return end
    
    -- Check mana gate
    if self.Menu and self.Menu.combo and self.Menu.combo.mana and (myHero.mana/myHero.maxMana*100) < self.Menu.combo.mana:Value() then return end
    
    -- Cast Q for damage
    if self.Menu.combo.spells.useQ:Value() then
        self:CastQ(target)
    end
    
    -- Cast W to polymorph enemy
    if self.Menu.combo.spells.useW:Value() then
        self:CastW(target, false)
    end
    
    -- Cast E to shield self or damage enemy
    if self.Menu.combo.spells.useE:Value() then
        if Dist2D(myHero.pos, target.pos) <= SPELL_RANGES[_E] then
            self:CastE(target, false) -- Damage enemy
        end
    end
    
    -- Cast R on self or allies if low health
    if self.Menu.combo.spells.useR:Value() then
        local myHpPct = (myHero.health / myHero.maxHealth) * 100
        
        -- Check allies first
        for _, ally in ipairs(GetAllyHeroes()) do
            if Dist2D(myHero.pos, ally.pos) <= SPELL_RANGES[_R] then
                local allyHpPct = (ally.health / ally.maxHealth) * 100
                if allyHpPct <= self.Menu.combo.wildgrowth.allyHealthThreshold:Value() then
                    -- Check if there are enemies around the ally
                    local enemyCount = 0
                    for _, enemy in ipairs(GetEnemyHeroes()) do
                        if Dist2D(ally.pos, enemy.pos) <= 400 then
                            enemyCount = enemyCount + 1
                        end
                    end
                    
                    if enemyCount >= self.Menu.combo.wildgrowth.minEnemies:Value() then
                        self:CastR(ally)
                        return -- Exit after casting R
                    end
                end
            end
        end
        
        -- Cast R on self if low health
        if myHpPct <= self.Menu.combo.wildgrowth.selfHealthThreshold:Value() then
            local enemyCount = 0
            for _, enemy in ipairs(GetEnemyHeroes()) do
                if Dist2D(myHero.pos, enemy.pos) <= 400 then
                    enemyCount = enemyCount + 1
                end
            end
            
            if enemyCount >= self.Menu.combo.wildgrowth.minEnemies:Value() then
                self:CastR(myHero)
            end
        end
    end
end

function Lulu:Harass(target)
    if not target then return end
    if myHero.mana/myHero.maxMana*100 < self.Menu.harass.mana:Value() then return end
    
    if self.Menu.harass.useQ:Value() then 
        self:CastQ(target) 
    end
    if self.Menu.harass.useE:Value() then 
        self:CastE(target, false) 
    end
end

-- Evade system functions from DepressiveActivator
local function ClosestPointOnLineSegment(p, p1, p2)
    local px = p.x
    local pz = p.z
    local ax = p1.x
    local az = p1.z
    local bx = p2.x
    local bz = p2.z
    local bxax = bx - ax
    local bzaz = bz - az
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    if (t < 0) then
        return p1, false
    end
    if (t > 1) then
        return p2, false
    end
    return {x = ax + t * bxax, z = az + t * bzaz}, true
end

local function IsProjectileDangerous(unit, spell, targetUnit, aggressiveMode)
    if not unit or not spell or not spell.valid then return false end
    
    local targetUnit = targetUnit or myHero
    local aggressiveMode = aggressiveMode or false
    
    -- Check if spell is directly targeting the target unit
    if spell.target == targetUnit.handle then
        return true
    end
    
    local distanceToTarget = Dist2D(unit.pos, targetUnit.pos)
    
    -- For skillshots, check if they're in range and potentially dangerous
    if spell.type == 0 and spell.speed > 0 then -- Skillshot
        local maxRange = aggressiveMode and 1200 or 1000
        if distanceToTarget <= maxRange then
            return true
        end
    end
    
    -- For targeted spells, check if they're in range
    if spell.type == 1 then -- Targeted spell
        local maxRange = aggressiveMode and 1000 or 800
        if distanceToTarget <= maxRange then
            return true
        end
    end
    
    -- For other spell types, check if they're in range
    local maxRange = aggressiveMode and 800 or 600
    if distanceToTarget <= maxRange then
        return true
    end
    
    return false
end

function Lulu:BlockSystem()
    if not self.Menu.block.enabled:Value() or not Ready(_E) then return end
    
    local myHpPct = (myHero.health / myHero.maxHealth) * 100
    
    for _, enemy in ipairs(GetEnemyHeroes()) do
        if not enemy or not enemy.valid or enemy.dead or not enemy.visible then
            goto continueEnemy
        end
        
        local eSpell = enemy.activeSpell
        if eSpell and eSpell.valid and not eSpell.isStopped then
            -- First priority: Check if spell is dangerous and targeting allies
            if self.Menu.block.protectAllies:Value() then
                for _, ally in ipairs(GetAllyHeroes()) do
                    if IsProjectileDangerous(enemy, eSpell, ally, self.Menu.block.aggressiveMode:Value()) and Dist2D(myHero.pos, ally.pos) <= SPELL_RANGES[_E] then
                        local allyHpPct = (ally.health / ally.maxHealth) * 100
                        if allyHpPct <= self.Menu.block.healthThreshold:Value() then
                            -- Use E to shield ally only if they don't already have shield and not on cooldown
                            if not HasLuluShield(ally) and not IsOnShieldCooldown(self, ally) then
                                if self.Menu.block.debugMode:Value() then
                                    print("[Lulu Block] Shielding ally " .. ally.charName .. " from " .. enemy.charName .. " spell: " .. (eSpell.name or "unknown"))
                                end
                                Control.CastSpell(HK_E, ally)
                                SetShieldCooldown(self, ally)
                                return -- Exit after first block
                            end
                        end
                    end
                end
            end
            
            -- Second priority: Check if spell is dangerous and targeting us
            if self.Menu.block.protectSelf:Value() and IsProjectileDangerous(enemy, eSpell, myHero, self.Menu.block.aggressiveMode:Value()) then
                if myHpPct <= self.Menu.block.healthThreshold:Value() then
                    -- Use E to shield ourselves only if we don't already have shield and not on cooldown
                    if not HasLuluShield(myHero) and not IsOnShieldCooldown(self, myHero) then
                        if self.Menu.block.debugMode:Value() then
                            print("[Lulu Block] Shielding self from " .. enemy.charName .. " spell: " .. (eSpell.name or "unknown"))
                        end
                        Control.CastSpell(HK_E, myHero)
                        SetShieldCooldown(self, myHero)
                        return -- Exit after first block
                    end
                end
            end
        end
        
        ::continueEnemy::
    end
end

function Lulu:AutoProtection()
    if not self.Menu.auto.useW:Value() and not self.Menu.auto.useR:Value() then
        return
    end
    
    local myHpPct = (myHero.health / myHero.maxHealth) * 100
    
    -- Auto W (Whimsy) - Block enemy spells
    if self.Menu.auto.useW:Value() and Ready(_W) then
        for _, enemy in ipairs(GetEnemyHeroes()) do
            if Dist2D(myHero.pos, enemy.pos) <= SPELL_RANGES[_W] then
                local shouldBlock, isTargetingUs, targetAlly = ShouldBlockSpell(enemy, nil, nil)
                if shouldBlock and myHpPct <= self.Menu.combo.whimsy.healthThreshold:Value() then
                    self:CastW(enemy, false)
                    break
                end
            end
        end
    end
    
    
    -- Auto R (Wild Growth) - Save allies only when critically low
    if self.Menu.auto.useR:Value() and Ready(_R) then
        for _, ally in ipairs(GetAllyHeroes()) do
            if Dist2D(myHero.pos, ally.pos) <= SPELL_RANGES[_R] then
                local allyHpPct = (ally.health / ally.maxHealth) * 100
                if allyHpPct <= self.Menu.auto.rHealthThreshold:Value() then
                    -- Only use R when ally is critically low and enemies nearby
                    local enemyCount = 0
                    for _, enemy in ipairs(GetEnemyHeroes()) do
                        if Dist2D(ally.pos, enemy.pos) <= 500 then
                            enemyCount = enemyCount + 1
                        end
                    end
                    
                    if enemyCount > 0 or allyHpPct < 25 then
                        self:CastR(ally)
                        break
                    end
                end
            end
        end
        
        -- Save self only when critically low
        if myHpPct <= self.Menu.auto.rHealthThreshold:Value() then
            local enemyCount = 0
            for _, enemy in ipairs(GetEnemyHeroes()) do
                if Dist2D(myHero.pos, enemy.pos) <= 500 then
                    enemyCount = enemyCount + 1
                end
            end
            
            if enemyCount > 0 or myHpPct < 20 then
                self:CastR(myHero)
            end
        end
    end
end

function Lulu:OnDraw()
    local draw = self.Menu.draw
    if not draw or not draw.ranges:Value() then return end
    local useBright = draw.bright and draw.bright:Value()
    local alphaMain = useBright and 160 or 70
    local alphaSub = useBright and 140 or 55
    local hasDrawLib = (Draw and Draw.Circle and Draw.Color)
    local hasLegacy = (DrawCircle and DrawColor)
    if not hasDrawLib and not hasLegacy then
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
        if draw.dq:Value() and Ready(_Q) then 
            Circle(myHero.pos, 950, Col(alphaMain, 120, 200, 255)) 
        end
        if draw.dwe:Value() and (Ready(_W) or Ready(_E)) then 
            Circle(myHero.pos, 650, Col(alphaSub, 255, 120, 255)) 
        end
        if draw.dr:Value() and Ready(_R) then 
            Circle(myHero.pos, 900, Col(alphaMain, 255, 200, 0)) 
        end
    end)
    if not ok and draw.debug and draw.debug:Value() then
        print("[Lulu Draw Error] " .. tostring(err))
    end
end

local function SafeInitLulu()
    if not MenuElement then
        return false
    end
    local ok, obj = pcall(function() return Lulu:__init() end)
    if not ok or not obj then
        return false
    end
    _G.DepressiveLulu = obj
    _G.__DEPRESSIVE_NEXT_LULU_LOADED = true
    _G.__LULU_DEPRESSIVE_LOADED = true
    _G.DepressiveAIONextLoadedChampion = true
    
    -- Force initial enemy and ally detection
    DelayAction(function()
        GetEnemyHeroes()
        GetAllyHeroes()
    end, 1.0)
    
    return true
end

if not SafeInitLulu() then
    local retries = 0
    Callback.Add("Tick", function()
        if _G.__DEPRESSIVE_NEXT_LULU_LOADED then return end
        if SafeInitLulu() then return end
        retries = retries + 1
        if retries > 120 then -- ~2s
            Callback.Del("Tick", _G.__LULU_RETRY_TICK)
        end
    end)
end

-- Register callbacks
Callback.Add("Tick", function()
    if _G.DepressiveLulu then _G.DepressiveLulu:OnTick() end
end)

Callback.Add("Draw", function()
    if _G.DepressiveLulu then _G.DepressiveLulu:OnDraw() end
end)
