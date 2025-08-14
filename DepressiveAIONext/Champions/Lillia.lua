local Heroes = {"Lillia"}
if not (myHero and myHero.charName and table.contains and table.contains(Heroes, myHero.charName) or (function()
    for i=1,#Heroes do if Heroes[i]==myHero.charName then return true end end return false end)()) then return end

if _G.DepressiveAIONext_LilliaLoaded then return end
_G.DepressiveAIONext_LilliaLoaded = true

require("DepressivePrediction")

-- (BEGIN Original Script)
local function contains(tbl, value)
    for i = 1, #tbl do if tbl[i] == value then return true end end
    return false
end
-- Hero validation already done above

-- Cached aliases
local GameHeroCount, GameHero, GameTimer, GameMinionCount, GameMinion = Game.HeroCount, Game.Hero, Game.Timer, Game.MinionCount, Game.Minion

-- Perf controls
local Perf = {
    heroScan = 0.50,
    autoCheck = 0.20,
}
local lastHeroScan, lastAutoCheck = 0, 0
local EnemyHeroes = {}

-- State
local lastQCast, lastWCast, lastECast, lastRCast = 0, 0, 0, 0
local moveTo, lastHelperSet = nil, 0
local movementHooked = false

-- Spell data
local Spell = {
    Q = { range = 450, inner = 150, outer = 330, delay = 0.25 },
    W = { range = 500, radius = 150, delay = 0.25 },
    E = { range = 750, radius = 65, speed = 1200, delay = 0.25 },
    R = { range = 1200, delay = 0.50 },
}

local function GetDistance2D(a, b)
    if not a or not b then return math.huge end
    local dx, dz = (a.x or 0) - (b.x or 0), (a.z or 0) - (b.z or 0)
    return math.sqrt(dx*dx + dz*dz)
end
local function IsValid(u)
    return u and u.valid and not u.dead and u.visible
end
local function Ready(slot)
    local sd = myHero:GetSpellData(slot)
    return sd and sd.level > 0 and Game.CanUseSpell(slot) == 0
end

local passiveCache, lastPassiveSweep = {}, 0
local function HasPassive(unit)
    if not unit or not unit.buffCount then return false end
    local id, now = unit.networkID or unit.handle or unit.charName, GameTimer()
    local c = passiveCache[id]
    if c and now - c.t < 0.15 then return c.v end
    local found = false
    for i = 0, unit.buffCount do
        local b = unit:GetBuff(i)
        if b and b.count and b.count > 0 and b.name then
            local n = string.lower(b.name)
            if n:find("lillia") and (n:find("pass") or n:find("dream") or n:find("dust")) then
                found = true; break
            end
        end
    end
    passiveCache[id] = { v = found, t = now }
    if now - lastPassiveSweep > 5.0 then
        for k,v in pairs(passiveCache) do if now - v.t > 10.0 then passiveCache[k] = nil end end
        lastPassiveSweep = now
    end
    return found
end

local function GetMode()
    if _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.Modes then
        local M = _G.SDK.Orbwalker.Modes
        if M and (M[_G.SDK.ORBWALKER_MODE_COMBO] or M.Combo) then return "Combo" end
        if M and (M[_G.SDK.ORBWALKER_MODE_HARASS] or M.Harass) then return "Harass" end
        if M and (M[_G.SDK.ORBWALKER_MODE_LANECLEAR] or M[_G.SDK.ORBWALKER_MODE_JUNGLECLEAR] or M.Clear or M.LaneClear) then return "Clear" end
        if M and (M[_G.SDK.ORBWALKER_MODE_FLEE] or M.Flee) then return "Flee" end
    end
    if _G.GOS and _G.GOS.GetMode then
        local m = (type(_G.GOS.GetMode) == "function" and _G.GOS.GetMode()) or nil
        if m == 1 then return "Combo" elseif m == 2 then return "Harass" elseif m == 3 then return "Clear" elseif m == 4 then return "Flee" end
    end
    if _G.Orbwalker and _G.Orbwalker.GetMode then
        local ok, m = pcall(function() return _G.Orbwalker:GetMode() end)
        if ok then return m end
    end
    return "None"
end

local function RefreshHeroes()
    EnemyHeroes = {}
    for i = 1, GameHeroCount() do
        local h = GameHero(i)
        if h and h.team ~= myHero.team then
            EnemyHeroes[#EnemyHeroes+1] = h
        end
    end
end

local function GetNearestTarget(maxRange)
    local best, bestD = nil, math.huge
    for i = 1, #EnemyHeroes do
        local e = EnemyHeroes[i]
        if IsValid(e) then
            local d = GetDistance2D(myHero.pos, e.pos)
            if d < bestD and d <= (maxRange or 2500) then best, bestD = e, d end
        end
    end
    return best, bestD
end

local function CalcComboDamage(unit)
    if not IsValid(unit) then return 0 end
    local level, ap = myHero.levelData.lvl or 1, myHero.ap or 0
    local total = 0
    if Ready(_Q) then total = total + (30 + 15*level) + ap*0.4 end
    if Ready(_W) then total = total + (70 + 50*level) + ap*0.3 + unit.maxHealth * (0.05 + 0.01*level) end
    if Ready(_E) then total = total + (50 + 20*level) + ap*0.4 end
    if Ready(_R) then total = total + (50 + 50*level) + ap*0.3 end
    return total
end

local menu = MenuElement({id = "Lillia", name = "Depressive - Lillia", type = MENU})
menu:MenuElement({id = "prediction", name = "Prediction", type = MENU})
menu.prediction:MenuElement({id = "hitchance", name = "Min HitChance (1-6)", value = 2, min = 1, max = 6, step = 1})
menu.prediction:MenuElement({id = "advanced", name = "Use DepressivePrediction", value = true})

menu:MenuElement({id = "combo", name = "Combo", type = MENU})
menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
menu.combo:MenuElement({id = "useW", name = "Use W", value = true})
menu.combo:MenuElement({id = "useE", name = "Use E", value = true})
menu.combo:MenuElement({id = "useR", name = "Use R", value = true})
menu.combo:MenuElement({id = "qEdgeOnly", name = "Q only if EDGE true dmg", value = true})
menu.combo:MenuElement({id = "rSingleKill", name = "R single if killable", value = true})

menu:MenuElement({id = "harass", name = "Harass", type = MENU})
menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
menu.harass:MenuElement({id = "useE", name = "Use E", value = true})
menu.harass:MenuElement({id = "mana", name = "Min Mana %", value = 40, min = 0, max = 100, step = 5})

menu:MenuElement({id = "clear", name = "Clear", type = MENU})
menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
menu.clear:MenuElement({id = "useW", name = "Use W", value = true})
menu.clear:MenuElement({id = "minQ", name = "Min minions Q", value = 3, min = 1, max = 6, step = 1})
menu.clear:MenuElement({id = "minW", name = "Min minions W", value = 4, min = 2, max = 8, step = 1})

menu:MenuElement({id = "jungle", name = "Jungle", type = MENU})
menu.jungle:MenuElement({id = "useQ", name = "Use Q", value = true})
menu.jungle:MenuElement({id = "useW", name = "Use W", value = true})
menu.jungle:MenuElement({id = "useE", name = "Use E", value = true})

menu:MenuElement({id = "drawing", name = "Drawing", type = MENU})
menu.drawing:MenuElement({id = "q", name = "Draw Q", value = true})
menu.drawing:MenuElement({id = "w", name = "Draw W", value = true})
menu.drawing:MenuElement({id = "e", name = "Draw E", value = true})
menu.drawing:MenuElement({id = "r", name = "Draw R window", value = true})

menu:MenuElement({id = "perf", name = "Performance", type = MENU})
menu.perf:MenuElement({id = "heroScan", name = "Hero scan (s)", value = Perf.heroScan, min = 0.2, max = 1.5, step = 0.05})
menu.perf:MenuElement({id = "autoCheck", name = "Auto checks (s)", value = Perf.autoCheck, min = 0.05, max = 0.6, step = 0.05})

menu:MenuElement({id = "helper", name = "Q Edge Helper", type = MENU})
menu.helper:MenuElement({id = "enable", name = "Enable helper", value = true})
menu.helper:MenuElement({id = "onlyCombo", name = "Only in Combo", value = true})
menu.helper:MenuElement({id = "maxDistance", name = "Max move distance", value = 450, min = 150, max = 900, step = 25})
menu.helper:MenuElement({id = "draw", name = "Draw helper position", value = true})

local function GetPred(target, spec)
    if menu.prediction.advanced:Value() and _G.DepressivePrediction and type(_G.DepressivePrediction.GetPrediction) == "function" then
        local ok, r1, r2 = pcall(_G.DepressivePrediction.GetPrediction, target, spec)
        if ok then
            if type(r1) == "table" and r1.castPos then return r1.castPos, r1.hitChance or 2
            elseif type(r1) == "table" and r1.x then return r1, (type(r2) == "number" and r2) or 2 end
        end
    end
    return target.pos, 2
end

local function CastQ(target)
    if not Ready(_Q) or not target or not IsValid(target) then return false end
    local now = GameTimer(); if now - lastQCast < 0.20 then return false end
    local d = GetDistance2D(myHero.pos, target.pos); if d > Spell.Q.range then return false end
    if menu.combo.qEdgeOnly:Value() and d < Spell.Q.outer - 40 then return false end
    Control.CastSpell(HK_Q); lastQCast = now; moveTo = nil; return true
end
local function CastW(target)
    if not Ready(_W) or not target or not IsValid(target) then return false end
    local now = GameTimer(); if now - lastWCast < 0.30 then return false end
    local d = GetDistance2D(myHero.pos, target.pos); if d > Spell.W.range + 15 then return false end
    local castPos, hc = GetPred(target,{ range=Spell.W.range, speed=math.huge, delay=Spell.W.delay, radius=Spell.W.radius, type="circular" })
    if castPos and (hc or 0) >= menu.prediction.hitchance:Value() then Control.CastSpell(HK_W, castPos); lastWCast=now; return true end
    return false
end
local function CastE(target)
    if not Ready(_E) or not target or not IsValid(target) then return false end
    local now = GameTimer(); if now - lastECast < 0.25 then return false end
    local d = GetDistance2D(myHero.pos, target.pos); if d > Spell.E.range + 50 then return false end
    local castPos, hc = GetPred(target,{ range=Spell.E.range, speed=Spell.E.speed, delay=Spell.E.delay, radius=Spell.E.radius, type="linear" })
    if castPos and (hc or 0) >= menu.prediction.hitchance:Value() then Control.CastSpell(HK_E, castPos); lastECast=now; return true end
    return false
end
local function CastR()
    if not Ready(_R) then return false end
    local now = GameTimer(); if now - lastRCast < 1.25 then return false end
    if menu.combo.rSingleKill:Value() then
        local t = GetNearestTarget(Spell.R.range)
        if t and IsValid(t) and CalcComboDamage(t) >= t.health then Control.CastSpell(HK_R); lastRCast=now; return true end
    end
    return false
end

local function GetEnemyMinionsIn(range)
    local out = {}; for i=1, GameMinionCount() do local m=GameMinion(i); if m and m.valid and not m.dead and m.isEnemy and GetDistance2D(myHero.pos,m.pos)<=range then out[#out+1]=m end end; return out end
local function GetNeutralMonstersIn(range)
    local out = {}; for i=1, GameMinionCount() do local m=GameMinion(i); if m and m.valid and not m.dead and m.team==300 and GetDistance2D(myHero.pos,m.pos)<=range then out[#out+1]=m end end; return out end

local function ComputeQEdgePosition(target)
    if not target or not target.pos then return nil end
    local desired = (Spell.Q.outer or 330) - 10
    local tx,tz = target.pos.x,target.pos.z; local hx,hz = myHero.pos.x,myHero.pos.z
    local dx,dz = hx-tx,hz-tz; local len = math.sqrt(dx*dx+dz*dz); if len < 1 then return nil end
    local nx,nz = dx/len,dz/len; local px,pz = tx+nx*desired, tz+nz*desired
    local pos = {x=px, y=myHero.pos.y, z=pz}; if MapPosition and MapPosition.inWall and MapPosition:inWall(pos) then return nil end
    return pos
end

local function UpdateHelper()
    if not menu.helper.enable:Value() then moveTo=nil; return end
    if menu.helper.onlyCombo:Value() and GetMode() ~= "Combo" then moveTo=nil; return end
    if not Ready(_Q) then moveTo=nil; return end
    local t = GetNearestTarget(Spell.Q.range + 250); if not t then moveTo=nil; return end
    local pos = ComputeQEdgePosition(t); if not pos then moveTo=nil; return end
    local dist = GetDistance2D(myHero.pos,pos); if dist < 30 or dist > menu.helper.maxDistance:Value() then moveTo=nil; return end
    moveTo = pos; lastHelperSet = GameTimer()
end

local function OnPreMovement(args)
    if not args or not moveTo then return end
    if not menu.helper.enable:Value() then return end
    if menu.helper.onlyCombo:Value() and GetMode() ~= "Combo" then return end
    if not Ready(_Q) then return end
    local d = GetDistance2D(myHero.pos, moveTo); if d < 25 then args.Process=false; return end
    if MapPosition and MapPosition.inWall and MapPosition:inWall(moveTo) then return end
    args.Target = moveTo
end
local function TryHookPreMovement()
    if movementHooked then return end
    if _G.GOS and _G.GOS.Orbwalker and _G.GOS.Orbwalker.OnPreMovement then _G.GOS.Orbwalker:OnPreMovement(OnPreMovement); movementHooked=true
    elseif _G.SDK and _G.SDK.Orbwalker and _G.SDK.Orbwalker.OnPreMovement then _G.SDK.Orbwalker:OnPreMovement(OnPreMovement); movementHooked=true
    elseif _G.Orbwalker and _G.Orbwalker.OnPreMovement then _G.Orbwalker:OnPreMovement(OnPreMovement); movementHooked=true end
end

local function Combo()
    local t = GetNearestTarget(Spell.E.range); if not t then return end
    if menu.combo.useE:Value() then CastE(t) end
    if menu.combo.useW:Value() then CastW(t) end
    if menu.combo.useQ:Value() then CastQ(t) end
    if menu.combo.useR:Value() then CastR() end
end
local function Harass()
    local mp = (myHero.mana and myHero.maxMana and myHero.maxMana>0) and (myHero.mana/myHero.maxMana*100) or 100
    if mp < menu.harass.mana:Value() then return end
    local t = GetNearestTarget(Spell.E.range); if not t then return end
    if menu.harass.useE:Value() then CastE(t) end
    if menu.harass.useQ:Value() then CastQ(t) end
end
local function Clear()
    local enemiesQ = GetEnemyMinionsIn(Spell.Q.range)
    if menu.clear.useQ:Value() and Ready(_Q) and #enemiesQ >= menu.clear.minQ:Value() then Control.CastSpell(HK_Q); lastQCast = GameTimer() end
    local enemiesW = GetEnemyMinionsIn(Spell.W.range)
    if menu.clear.useW:Value() and Ready(_W) and #enemiesW >= menu.clear.minW:Value() then local m=enemiesW[1]; if m and m.pos then Control.CastSpell(HK_W, m.pos); lastWCast = GameTimer() end end
    local monsters = GetNeutralMonstersIn(Spell.E.range)
    if #monsters>0 then local m=monsters[1]; if menu.jungle.useE:Value() then CastE(m) end; if menu.jungle.useW:Value() then CastW(m) end; if menu.jungle.useQ:Value() then CastQ(m) end end
end

local function OnTick()
    local now = GameTimer()
    if now - lastHeroScan > menu.perf.heroScan:Value() then RefreshHeroes(); lastHeroScan = now end
    TryHookPreMovement(); UpdateHelper()
    if moveTo and not movementHooked then if now - lastHelperSet > 0.05 then Control.Move(moveTo); lastHelperSet = now end end
    local mode = GetMode()
    if mode == "Combo" then Combo() elseif mode == "Harass" then Harass() elseif mode == "Clear" or mode == "LaneClear" then Clear() end
end
local function OnDraw()
    if myHero.dead then return end
    if menu.drawing.q:Value() then Draw.Circle(myHero.pos, Spell.Q.range, Draw.Color(120, 0, 255, 0)) end
    if menu.drawing.w:Value() then Draw.Circle(myHero.pos, Spell.W.range, Draw.Color(120, 255, 0, 0)) end
    if menu.drawing.e:Value() then Draw.Circle(myHero.pos, Spell.E.range, Draw.Color(120, 0, 0, 255)) end
    if menu.drawing.r:Value() then Draw.Circle(myHero.pos, Spell.R.range, Draw.Color(120, 255, 0, 255)) end
    if menu.helper.draw:Value() and moveTo then
        Draw.Circle(moveTo, 35, Draw.Color(200, 255, 255, 0))
        local from2d = myHero.pos and myHero.pos.To2D and myHero.pos:To2D() or nil
        local to2d = nil
        if moveTo.To2D then to2d = moveTo:To2D() elseif type(Vector) == "function" then local v = Vector(moveTo.x or 0, moveTo.y or myHero.pos.y, moveTo.z or 0); if v and v.To2D then to2d = v:To2D() end end
        if from2d and to2d and from2d.onScreen and to2d.onScreen then Draw.Line(from2d.x, from2d.y, to2d.x, to2d.y, 1, Draw.Color(150, 255, 255, 0)) end
    end
end

Callback.Add("Tick", OnTick)
Callback.Add("Draw", OnDraw)
print("[DepressiveAIONext] Lillia module loaded")
-- (END Original Script)
