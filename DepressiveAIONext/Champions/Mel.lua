local VERSION = "0.1"
if _G.__DEPRESSIVE_NEXT_MEL_LOADED then return end
if myHero.charName ~= "Mel" then return end
_G.__DEPRESSIVE_NEXT_MEL_LOADED = true

-- Prediction library load (DepressivePrediction)
local DepressivePrediction = nil
local ok, result = pcall(function() return require("DepressivePrediction") end)
if ok and result then
    DepressivePrediction = result
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

local function Ready(slot) local sd=myHero:GetSpellData(slot); return sd and sd.level>0 and sd.currentCd==0 and sd.mana<=myHero.mana and Game.CanUseSpell(slot)==0 end

local function MyHeroNotReady()
    return myHero.dead or Game.IsChatOpen() or (_G.JustEvade and _G.JustEvade:Evading()) or (_G.ExtLibEvade and _G.ExtLibEvade.Evading)
end

-- Spell ranges based on wiki data
local SPELL_RANGES = {[_Q]=950,[_E]=1050,[_R]=0} -- Q=950, E=1050, R is global target
local function InRange(slot, target)
    if not target then return false end
    local r = SPELL_RANGES[slot]
    if not r then return false end
    -- Use DepressivePrediction's effective range calculation if available
    if DepressivePrediction and type(DepressivePrediction) == "table" and DepressivePrediction.IsInEffectiveRange then
        return DepressivePrediction.IsInEffectiveRange(myHero, target, r, true)
    end
    return Dist2D(myHero.pos, target.pos) <= r + 5 -- small buffer
end

-- Enemy detection system (exactly like Akali)
local _EnemyCache={t=0,list={}}
local function GetEnemyHeroes()
    local now=Game.Timer and Game.Timer() or os.clock()
    if now-_EnemyCache.t>0.25 then
        local L={}
        for i=1,Game.HeroCount() do 
            local h=Game.Hero(i)
            if h and h.team~=myHero.team and IsValid(h) then 
                L[#L+1]=h 
            end
        end
        _EnemyCache.list=L; _EnemyCache.t=now
    end
    return _EnemyCache.list
end

local function GetTarget(range)
    local best,bd=nil,1e9
    local enemies = GetEnemyHeroes()
    
    for _,e in ipairs(enemies) do 
        local d=Dist2D(myHero.pos,e.pos)
        if d<range and d<bd then best=e; bd=d end 
    end
    
    return best
end

-- Damage calculations based on wiki data
local function QDamage(target)
    local q = myHero:GetSpellData(_Q).level; if q==0 then return 0 end
    local base = ({13,15.5,18,20.5,23})[q] or 0
    local ap = myHero.ap * 0.085
    local bolts = ({6,7,8,9,10})[q] or 6
    return (base + ap) * bolts
end


local function EDamage(target)
    local e = myHero:GetSpellData(_E).level; if e==0 then return 0 end
    local base = ({40,60,80,100,120})[e] or 0
    return base + myHero.ap * 0.4
end

local function RDamage(target)
    local r = myHero:GetSpellData(_R).level; if r==0 then return 0 end
    local base = ({200,300,400})[r] or 0
    return base + myHero.ap * 0.6
end

-- Searing Brilliance damage (passive)
local function SearingBrillianceDamage()
    local level = myHero.level
    local base = 8 + (level - 1) * 1.13 -- 8-25 based on level
    return base + myHero.ap * 0.01
end

-- Overwhelm damage calculation
local function OverwhelmDamage(target, stacks)
    if not target or not stacks or stacks <= 0 then return 0 end
    local r = myHero:GetSpellData(_R).level; if r==0 then r=1 end
    local base = ({50,60,70,80})[r] or 50
    local perStack = ({2,3,4,5})[r] or 2
    local baseDmg = base + myHero.ap * 0.1
    local stackDmg = perStack + myHero.ap * 0.0075
    return baseDmg + (stackDmg * (stacks - 1))
end

local function TotalComboDamage(t)
    if not t then return 0 end
    local dmg = 0
    if Ready(_Q) then dmg = dmg + QDamage(t) end
    if Ready(_E) then dmg = dmg + EDamage(t) end
    if Ready(_R) then dmg = dmg + RDamage(t) end
    -- Add Searing Brilliance potential (9 stacks max)
    dmg = dmg + SearingBrillianceDamage() * 9
    return dmg
end

-- Simple casting without prediction

-- Track Searing Brilliance stacks
local function GetSearingBrillianceStacks()
    for i=0, myHero.buffCount do
        local buff = myHero:GetBuff(i)
        if buff and buff.name and buff.name:lower():find("mel") and buff.name:lower():find("searing") then
            return buff.stacks or buff.count or 0
        end
    end
    return 0
end

-- Track Overwhelm stacks on target
local function GetOverwhelmStacks(target)
    if not target then return 0 end
    for i=0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and buff.name and buff.name:lower():find("overwhelm") then
            return buff.stacks or buff.count or 0
        end
    end
    return 0
end

-- Check if target can be executed by Overwhelm
local function CanExecuteWithOverwhelm(target)
    if not target then return false end
    local stacks = GetOverwhelmStacks(target)
    if stacks <= 0 then return false end
    local storedDmg = OverwhelmDamage(target, stacks)
    return storedDmg >= target.health
end

-- Class
local Mel = {}
Mel.__index = Mel

function Mel:__init()
    local o = setmetatable({}, Mel)
    o.lastCastTimes = {[_Q]=0,[_E]=0,[_R]=0}
    o.castDelay = 0.25
    o.Menu = o:CreateMenu()
    
    -- Initialize enemy detection at start
    Callback.Add("Load", function()
        -- Force initial enemy detection
        GetEnemyHeroes()
    end)
    
    return o
end

function Mel:CreateMenu()
    local M = MenuElement({type=MENU,id="DepressiveMel", name="Depressive - Mel"})
    M:MenuElement({name=" ", drop={"Version "..VERSION}})

    M:MenuElement({type=MENU,id="combo", name="Combo"})
    M.combo:MenuElement({type=MENU,id="spells", name="Spells"})
    M.combo:MenuElement({type=MENU,id="overwhelm", name="Overwhelm Logic"})
    M.combo:MenuElement({type=MENU,id="searing", name="Searing Brilliance"})
    M.combo:MenuElement({id="mana", name="Min Mana % (Combo)", value=0, min=0, max=100, identifier="%"})

    -- Spells
    M.combo.spells:MenuElement({id="useQ", name="Use Q (Radiant Volley)", value=true})
    M.combo.spells:MenuElement({id="useE", name="Use E (Solar Snare)", value=true})
    M.combo.spells:MenuElement({id="useR", name="Use R (Soul's Reflection)", value=true})

    -- Overwhelm Logic
    M.combo.overwhelm:MenuElement({id="prioritizeExecute", name="Prioritize Overwhelm Execute", value=true})
    M.combo.overwhelm:MenuElement({id="minStacksForExecute", name="Min Stacks for Execute", value=3, min=1, max=10, step=1})
    M.combo.overwhelm:MenuElement({id="executeThreshold", name="Execute HP Threshold %", value=25, min=5, max=50, step=5, identifier="%"})
    M.combo.overwhelm:MenuElement({id="rMinStacks", name="R Min Overwhelm Stacks", value=25, min=1, max=30, step=1})

    -- Searing Brilliance
    M.combo.searing:MenuElement({id="autoConsume", name="Auto Consume Searing Stacks", value=true})
    M.combo.searing:MenuElement({id="minStacksToConsume", name="Min Stacks to Consume", value=3, min=1, max=9, step=1})
    M.combo.searing:MenuElement({id="consumeOnExecute", name="Consume on Overwhelm Execute", value=true})
    

    M:MenuElement({type=MENU,id="harass", name="Harass"})
    M.harass:MenuElement({id="useQ", name="Use Q", value=true})
    M.harass:MenuElement({id="useE", name="Use E", value=false})
    M.harass:MenuElement({id="mana", name="Min Mana %", value=45,min=0,max=100,identifier="%"})

    M:MenuElement({type=MENU,id="clear", name="Lane Clear"})
    M.clear:MenuElement({id="useQ", name="Use Q", value=true})
    M.clear:MenuElement({id="qMin", name="Q if hits >= X minions", value=3,min=1,max=7,step=1})
    M.clear:MenuElement({id="mana", name="Min Mana %", value=45,min=0,max=100,identifier="%"})

    -- Prediction menu removed - using simple casting

    M:MenuElement({type=MENU,id="draw", name="Drawing"})
    M.draw:MenuElement({id="ranges", name="Master Toggle", value=true})
    M.draw:MenuElement({id="dq", name="Q Range", value=true})
    M.draw:MenuElement({id="de", name="E Range", value=false})
    M.draw:MenuElement({id="overwhelm", name="Show Overwhelm Stacks", value=true})
    M.draw:MenuElement({id="bright", name="High Visibility Colors", value=true})

    -- Backwards compatibility aliases
    local c = M.combo
    local function alias(k, tbl, tk) c[k] = tbl[tk] end
    alias("useQ", c.spells, "useQ"); alias("useW", c.spells, "useW"); alias("useE", c.spells, "useE"); alias("useR", c.spells, "useR")

    return M
end

function Mel:Mode()
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then local M=_G.SDK.Orbwalker.Modes; if M[_G.SDK.ORBWALKER_MODE_COMBO] or M.Combo then return "Combo" end; if M[_G.SDK.ORBWALKER_MODE_HARASS] or M.Harass then return "Harass" end; if M[_G.SDK.ORBWALKER_MODE_LANECLEAR] or M.Clear or M.LaneClear then return "Clear" end end
    if _G.GOS and _G.GOS.GetMode then local m=_G.GOS:GetMode(); if m==1 then return "Combo" elseif m==2 then return "Harass" elseif m==3 then return "Clear" end end
    return "None"
end

function Mel:OnTick()
    if MyHeroNotReady() then return end
    
    
    local mode = self:Mode()
    local target = GetTarget(1000)
    
    if mode=="Combo" then self:Combo(target)
    elseif mode=="Harass" then self:Harass(target)
    elseif mode=="Clear" then self:Clear()
    end
end

function Mel:CastQ(target)
    if not Ready(_Q) or not target or not IsValid(target) then return false end
    if Game.Timer() - self.lastCastTimes[_Q] < self.castDelay then return false end
    if not self.Menu or not self.Menu.combo or not self.Menu.combo.spells or not self.Menu.combo.spells.useQ or not self.Menu.combo.spells.useQ:Value() then return false end
    
    -- Verificar que estamos en rango
    if not InRange(_Q, target) then return false end
    
    -- Usar predicción de DepressivePrediction mejorada
    if DepressivePrediction and type(DepressivePrediction) == "table" and DepressivePrediction.SpellPrediction then
        local pred = DepressivePrediction.SpellPrediction({
            Type = DepressivePrediction.SPELLTYPE_LINE,
            Speed = 2000,
            Range = 950,
            Delay = 0.25,
            Radius = 80, -- Radio más amplio para mejor hit
            Collision = true,
            CollisionTypes = {DepressivePrediction.COLLISION_MINION, DepressivePrediction.COLLISION_HERO}
        })
        
        local result = pred:GetPrediction(target, myHero)
        if result and result.HitChance >= DepressivePrediction.HITCHANCE_NORMAL then
            -- Verificar que la posición de cast sea válida
            if result.CastPosition and Dist2D(myHero.pos, result.CastPosition) <= 950 then
                Control.CastSpell(HK_Q, result.CastPosition)
                self.lastCastTimes[_Q] = Game.Timer()
                return true
            end
        end
    else
        -- Fallback: casting simple hacia el target
        local targetPos = target.pos
        if targetPos and Dist2D(myHero.pos, targetPos) <= 950 then
            Control.CastSpell(HK_Q, targetPos)
            self.lastCastTimes[_Q] = Game.Timer()
            return true
        end
    end
    
    return false
end


function Mel:CastE(target)
    if not Ready(_E) or not target or not IsValid(target) then return false end
    if not self.Menu or not self.Menu.combo or not self.Menu.combo.spells or not self.Menu.combo.spells.useE or not self.Menu.combo.spells.useE:Value() then return false end
    if Game.Timer() - self.lastCastTimes[_E] < self.castDelay then return false end
    
    -- Verificar que estamos en rango
    if not InRange(_E, target) then return false end
    
    -- E es skillshot (Solar Snare) - usar predicción mejorada
    if DepressivePrediction and type(DepressivePrediction) == "table" and DepressivePrediction.SpellPrediction then
        local pred = DepressivePrediction.SpellPrediction({
            Type = DepressivePrediction.SPELLTYPE_LINE,
            Speed = 1200, -- Velocidad más precisa
            Range = 1050,
            Delay = 0.25,
            Radius = 100, -- Radio más amplio para mejor hit
            Collision = true,
            CollisionTypes = {DepressivePrediction.COLLISION_MINION, DepressivePrediction.COLLISION_HERO}
        })
        
        local result = pred:GetPrediction(target, myHero)
        if result and result.HitChance >= DepressivePrediction.HITCHANCE_NORMAL then
            -- Verificar que la posición de cast sea válida
            if result.CastPosition and Dist2D(myHero.pos, result.CastPosition) <= 1050 then
                Control.CastSpell(HK_E, result.CastPosition)
                self.lastCastTimes[_E] = Game.Timer()
                return true
            end
        end
    else
        -- Fallback: casting simple hacia el target
        local targetPos = target.pos
        if targetPos and Dist2D(myHero.pos, targetPos) <= 1050 then
            Control.CastSpell(HK_E, targetPos)
            self.lastCastTimes[_E] = Game.Timer()
            return true
        end
    end
    
    return false
end

function Mel:CastR(target)
    if not Ready(_R) or not self.Menu or not self.Menu.combo or not self.Menu.combo.spells or not self.Menu.combo.spells.useR or not self.Menu.combo.spells.useR:Value() then 
        return false 
    end
    if Game.Timer() - self.lastCastTimes[_R] < self.castDelay then 
        return false 
    end
    
    -- Verificar stacks mínimos de Overwhelm
    local minStacks = self.Menu.combo.overwhelm.rMinStacks:Value()
    local currentStacks = GetOverwhelmStacks(target)
    if currentStacks < minStacks then 
        return false 
    end
    
    -- R es target global (Golden Eclipse) - no necesita predicción
    Control.CastSpell(HK_R)
    self.lastCastTimes[_R] = Game.Timer()
    return true
end

function Mel:ConsumeSearingBrilliance(target)
    if not target or not self.Menu.combo.searing.autoConsume:Value() then return end
    local stacks = GetSearingBrillianceStacks()
    if stacks < self.Menu.combo.searing.minStacksToConsume:Value() then return end
    
    -- Consume stacks with basic attack
    Control.Attack(target)
end

function Mel:Combo(target)
    if not target then return end
    
    -- Check mana gate
    if self.Menu and self.Menu.combo and self.Menu.combo.mana and (myHero.mana/myHero.maxMana*100) < self.Menu.combo.mana:Value() then return end
    
    self:CastQ(target)
    self:CastE(target)
    self:CastR(target)
    -- W solo se usa para rebotar skillshots, no en combo
end

function Mel:Harass(target)
    if not target then return end
    if myHero.mana/myHero.maxMana*100 < self.Menu.harass.mana:Value() then return end
    
    if self.Menu.harass.useQ:Value() then self:CastQ(target) end
    if self.Menu.harass.useE:Value() then self:CastE(target) end
    -- W solo se usa para rebotar skillshots, no en harass
end

function Mel:Clear()
    if myHero.mana/myHero.maxMana*100 < self.Menu.clear.mana:Value() then return end
    if self.Menu.clear.useQ:Value() and Ready(_Q) then
        for i=1,Game.MinionCount() do
            local m=Game.Minion(i)
            if m and m.team~=myHero.team and not m.dead and Dist2D(myHero.pos,m.pos)<=950 then
                Control.CastSpell(HK_Q,m.pos); return
            end
        end
    end
end

function Mel:OnDraw()
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
        if draw.dq:Value() and Ready(_Q) then Circle(myHero.pos,950, Col(alphaMain,120,200,255)) end
        if draw.de:Value() and Ready(_E) then Circle(myHero.pos,1050, Col(alphaSub,255,120,255)) end
        
        -- Show Overwhelm stacks on enemies
        if draw.overwhelm:Value() then
            for _,enemy in ipairs(GetEnemyHeroes()) do
                local stacks = GetOverwhelmStacks(enemy)
                if stacks > 0 then
                    local txt = "Overwhelm: "..stacks
                    if Draw.Text then 
                        Draw.Text(txt, 14, enemy.pos2D.x-30, enemy.pos2D.y-20, Col(255,255,100,200))
                    elseif DrawText then 
                        DrawText(txt,14,enemy.pos2D.x-30,enemy.pos2D.y-20,Col(255,255,100,200))
                    end
                end
            end
        end
        
    end)
end

local function SafeInitMel()
    if not MenuElement then
        return false
    end
    local ok, obj = pcall(function() return Mel:__init() end)
    if not ok or not obj then
        return false
    end
    _G.DepressiveMel = obj
    _G.__DEPRESSIVE_NEXT_MEL_LOADED = true
    _G.__MEL_DEPRESSIVE_LOADED = true
    _G.DepressiveAIONextLoadedChampion = true
    
    -- Force initial enemy detection
    DelayAction(function()
        GetEnemyHeroes()
    end, 1.0)
    
    return true
end

if not SafeInitMel() then
    local retries = 0
    Callback.Add("Tick", function()
        if _G.__DEPRESSIVE_NEXT_MEL_LOADED then return end
        if SafeInitMel() then return end
        retries = retries + 1
        if retries > 120 then -- ~2s
            Callback.Del("Tick", _G.__MEL_RETRY_TICK)
        end
    end)
end

-- Register callbacks
Callback.Add("Tick", function()
    if _G.DepressiveMel then _G.DepressiveMel:OnTick() end
end)

Callback.Add("Draw", function()
    if _G.DepressiveMel then _G.DepressiveMel:OnDraw() end
end)
