local Version = 1.0
local Name = "Depressive - Zed"

-- Protección contra carga múltiple
if _G.DepressiveZedLoaded then return end
_G.DepressiveZedLoaded = true

-- Validación del campeón
local Heroes = {"Zed"}
if not table.contains(Heroes, myHero.charName) then return end

-- Marcar como cargado para DepressiveAIONext
_G.DepressiveAIONextLoadedChampion = true

-- Cargar sistema de predicción
require("DepressivePrediction")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
    end
end, 1.0)

-- Constantes de teclas
local HK_Q = HK_Q or _Q
local HK_W = HK_W or _W
local HK_E = HK_E or _E
local HK_R = HK_R or _R

-- Constantes de hechizos
local SPELL_RANGE = {
    Q = 900,
    W = 650,
    E = 300,
    R = 625
}

local SPELL_SPEED = {
    Q = 1700,
    W = math.huge,
    E = math.huge,
    R = math.huge
}

local SPELL_DELAY = {
    Q = 0.25,
    W = 0.5,
    E = 0.05,
    R = 0.25
}

local SPELL_RADIUS = {
    Q = 50,
    W = 100,
    E = 300,
    R = 0
}

-- Sistema de sombras mejorado
local Wshadow = nil
local Rshadow = nil
local WTime = 0
local RTime = 0
local Shadows = {}

-- Cache para optimización de FPS
local lastShadowScan = 0
local lastHeroScan = 0
local EnemyHeroes = {}
local CachedMinions = {}

-- Intervalos de actualización (ajustables para FPS)
local UpdateIntervals = {
    shadowScan = 0.1,     -- Escaneo de sombras cada 0.1s (más frecuente)
    heroScan = 0.5,       -- Lista de héroes cada 0.5s
    minionScan = 0.3,     -- Minions cada 0.3s
    damageCalc = 0.4      -- Cálculos de daño cada 0.4s
}



-- Funciones de utilidad optimizadas
local function GetDistance2D(p1, p2)
    if not p1 or not p2 then return math.huge end
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

local function Ready(spell)
    if not spell then return false end
    local spellData = myHero:GetSpellData(spell)
    if not spellData then return false end
    return spellData.currentCd == 0 and Game.CanUseSpell(spell) == 0
end

local function IsValidTarget(target, range)
    if not target then return false end
    if target.dead or not target.visible or not target.isTargetable then return false end
    if target.team == myHero.team then return false end
    if range and GetDistance2D(myHero.pos, target.pos) > range then return false end
    return true
end



-- Detector de Death Mark optimizado
local function IsDeathMarkBuffName(name)
    if not name then return false end
    local n = string.lower(name)
    return n:find("death") and n:find("mark") or n:find("zedr") or n:find("ulttargetmark")
end

local function HasDeathMark(target)
    if not target or not target.valid then return false end
    for i = 0, target.buffCount do
        local buff = target:GetBuff(i)
        if buff and buff.count and buff.count > 0 and IsDeathMarkBuffName(buff.name) then
            return true
        end
    end
    return false
end

-- Sistema de cache de enemigos optimizado
local function RefreshEnemyHeroes()
    EnemyHeroes = {}
    for i = 1, Game.HeroCount() do
        local h = Game.Hero(i)
        if h and h.team ~= myHero.team and not h.isAlly and not h.isMe then
            table.insert(EnemyHeroes, h)
        end
    end
end

local function GetEnemyHeroes()
    local now = Game.Timer()
    if now - lastHeroScan > UpdateIntervals.heroScan then
        RefreshEnemyHeroes()
        lastHeroScan = now
    end
    return EnemyHeroes
end

-- Sistema de sombras mejorado
local function FindZedShadows()
    -- Limpiar sombras expiradas
    if Wshadow ~= nil and (WTime + 5) < Game.Timer() then
        WTime = 0
        Wshadow = nil
    end
    if Rshadow ~= nil and (RTime + 6.5) < Game.Timer() then
        RTime = 0
        Rshadow = nil
    end

    -- Escaneo más frecuente para FPS
    local now = Game.Timer()
    if now - lastShadowScan < UpdateIntervals.shadowScan then return end
    lastShadowScan = now

    Shadows = {}
    local found = {}
    
    -- PRIORIDAD 1: Agregar sombras conocidas (W y R) si están activas
    if Wshadow and WTime > 0 and (Game.Timer() - WTime) < 5 then
        local d = GetDistance2D(myHero.pos, Wshadow)
        if d <= 2000 then
            table.insert(found, {pos = Wshadow, dist = d, type = "W"})
        end
    end
    
    if Rshadow and RTime > 0 and (Game.Timer() - RTime) < 6.5 then
        local d = GetDistance2D(myHero.pos, Rshadow)
        if d <= 2000 then
            table.insert(found, {pos = Rshadow, dist = d, type = "R"})
        end
    end
    
    -- PRIORIDAD 2: Escanear objetos del mundo para sombras adicionales
    for i = 1, math.min(Game.ObjectCount(), 100) do
        local obj = Game.Object(i)
        if obj and obj.pos and not obj.dead then
            local name = string.lower(obj.name or obj.charName or "")
            -- Buscar sombras de Zed específicamente
            if name:find("shadow") or name:find("zed") or name:find("clone") then
                local d = GetDistance2D(myHero.pos, obj.pos)
                if d <= 2000 then
                    -- Verificar que no sea una sombra ya conocida
                    local isKnown = false
                    for _, known in ipairs(found) do
                        if GetDistance2D(known.pos, obj.pos) < 50 then
                            isKnown = true
                            break
                        end
                    end
                    if not isKnown then
                        table.insert(found, {pos = Vector(obj.pos.x, myHero.pos.y, obj.pos.z), dist = d, type = "World"})
                    end
                end
            end
        end
    end
    
    -- PRIORIDAD 3: También escanear minions por si acaso
    for i = 1, math.min(Game.MinionCount(), 50) do
        local minion = Game.Minion(i)
        if minion and minion.pos and not minion.dead then
            local name = string.lower(minion.name or minion.charName or "")
            if name:find("shadow") or name:find("zed") or name:find("clone") then
                local d = GetDistance2D(myHero.pos, minion.pos)
                if d <= 2000 then
                    -- Verificar que no sea una sombra ya conocida
                    local isKnown = false
                    for _, known in ipairs(found) do
                        if GetDistance2D(known.pos, minion.pos) < 50 then
                            isKnown = true
                            break
                        end
                    end
                    if not isKnown then
                        table.insert(found, {pos = Vector(minion.pos.x, myHero.pos.y, minion.pos.z), dist = d, type = "Minion"})
                    end
                end
            end
        end
    end
    
    -- Ordenar por distancia y tomar los más cercanos
    table.sort(found, function(a,b) return a.dist < b.dist end)
    for i = 1, math.min(#found, 3) do
        Shadows[i] = found[i].pos
    end
end

-- Cálculos de daño optimizados
local function GetQDamage(target, isFromShadow)
    local level = myHero:GetSpellData(_Q).level
    if level == 0 then return 0 end
    
    local baseDamage = {80, 115, 150, 185, 220}
    local bonusAD = myHero.totalDamage - myHero.baseDamage
    local damage = baseDamage[level] + (bonusAD * 1.0)
    
    if isFromShadow then
        damage = damage * 0.6
    end
    
    return damage
end

local function GetEDamage()
    local level = myHero:GetSpellData(_E).level
    if level == 0 then return 0 end
    
    local baseDamage = {65, 90, 115, 140, 165}
    local bonusAD = myHero.totalDamage - myHero.baseDamage
    return baseDamage[level] + (bonusAD * 0.8)
end

local function GetRDamage(target)
    local level = myHero:GetSpellData(_R).level
    if level == 0 then return 0 end
    
    local baseDamage = {65, 90, 115}
    local bonusAD = myHero.totalDamage - myHero.baseDamage
    local rDamage = baseDamage[level] + (bonusAD * 0.5)
    
    -- Daño del pop del Death Mark
    if HasDeathMark(target) then
        rDamage = rDamage + (GetQDamage(target) + GetEDamage()) * 0.25
    end
    
    return rDamage
end

-- Predicción optimizada
local function GetPrediction(target, spell)
    if not target or not target.valid then return nil, 0 end
    
    -- Verificar si DepressivePrediction está disponible
    if _G.DepressivePrediction and _G.DepressivePrediction.GetPrediction then
        local spellRange = SPELL_RANGE[spell] or 900
        local spellSpeed = SPELL_SPEED[spell] or 1200
        local spellDelay = SPELL_DELAY[spell] or 0.25
        local spellRadius = SPELL_RADIUS[spell] or 50
        
        local pred = _G.DepressivePrediction.GetPrediction(target, {
            range = spellRange,
            speed = spellSpeed,
            delay = spellDelay,
            radius = spellRadius,
            type = "linear"
        })
        
        if pred and pred.castPos then
            return {x = pred.castPos.x, z = pred.castPos.z}, pred.hitChance or 2
        end
    end
    
    -- Fallback: predicción simple
    return {x = target.pos.x, z = target.pos.z}, 2
end

-- Variables globales del script
local Zed = {
    wCastTime = 0,
    wDelay = 0.2,
    lastActionTime = 0,
    damageCache = {},
    lastDamageCacheTime = 0,
    comboState = "idle",
    comboTarget = nil,
    lastWCastTime = 0, -- Para evitar doble cast de W
    keysPressed = {
        space = false,
        c = false,
        v = false,
        x = false
    }
}

-- Funciones auxiliares que deben definirse antes de las principales
local function GetBestTarget()
    local bestTarget = nil
    local bestPriority = -1e9
    
    local enemies = GetEnemyHeroes()
    for _, enemy in ipairs(enemies) do
        if IsValidTarget(enemy, 2000) then
            local priority = 0
            local healthPercent = (enemy.health / enemy.maxHealth)
            priority = priority + (1 - healthPercent)
            local distance = GetDistance2D(myHero.pos, enemy.pos)
            priority = priority + (2000 - distance) / 2000
            
            if priority > bestPriority then
                bestPriority = priority
                bestTarget = enemy
            end
        end
    end
    
    return bestTarget
end

local function CalculateTotalDamage(target)
    if not target then return 0 end
    
    local now = Game.Timer()
    if Zed.damageCache[target.networkID] and (now - Zed.lastDamageCacheTime) < UpdateIntervals.damageCalc then
        return Zed.damageCache[target.networkID]
    end
    
    local totalDamage = 0
    
    -- Q damage
    if Ready(_Q) then
        totalDamage = totalDamage + GetQDamage(target, false)
        for i = 1, #Shadows do
            totalDamage = totalDamage + GetQDamage(target, true)
        end
    end
    
    -- E damage
    if Ready(_E) then
        totalDamage = totalDamage + GetEDamage()
        for i = 1, #Shadows do
            totalDamage = totalDamage + GetEDamage()
        end
    end
    
    -- R damage
    if Ready(_R) then
        totalDamage = totalDamage + GetRDamage(target)
    end
    
    -- Cache del resultado
    Zed.damageCache[target.networkID] = totalDamage
    Zed.lastDamageCacheTime = now
    
    return totalDamage
end

local function GetBestWPositionForClear(minions)
    local bestPos = nil
    local bestCount = 0
    local minMinions = (Zed and Zed.Menu and Zed.Menu.clear and Zed.Menu.clear.minMinions:Value()) or 2
    
    for _, minion in ipairs(minions) do
        local d = GetDistance2D(myHero.pos, minion.pos)
        if d <= SPELL_RANGE.W then
            local count = 0
            for _, otherMinion in ipairs(minions) do
                if GetDistance2D(minion.pos, otherMinion.pos) <= SPELL_RANGE.E then
                    count = count + 1
                end
            end
            
            if count >= minMinions and count > bestCount then
                bestCount = count
                bestPos = minion.pos
            end
        end
    end
    
    return bestPos
end

local function CountMinionsInLine(startPos, endPos, minions)
    local count = 0
    local direction = (endPos - startPos):Normalized()
    local distance = GetDistance2D(startPos, endPos)
    
    for _, minion in ipairs(minions) do
        local minionPos = minion.pos
        local projection = ((minionPos - startPos):DotProduct(direction))
        
        if projection >= 0 and projection <= distance then
            local pointOnLine = startPos + (direction * projection)
            local distanceToLine = GetDistance2D(minionPos, pointOnLine)
            
            if distanceToLine <= SPELL_RADIUS.Q then
                count = count + 1
            end
        end
    end
    
    return count
end

local function GetBestQPositionForClear(minions)
    local bestPos = nil
    local maxMinions = 0
    
    for _, minion in ipairs(minions) do
        local d = GetDistance2D(myHero.pos, minion.pos)
        if d <= SPELL_RANGE.Q then
            local hitCount = CountMinionsInLine(myHero.pos, minion.pos, minions)
            if hitCount > maxMinions then
                maxMinions = hitCount
                bestPos = minion.pos
            end
        end
    end
    
    return bestPos
end

local function GetBestWPositionForJungle(minions)
    local bestPos = nil
    local bestCount = 0
    
    for _, minion in ipairs(minions) do
        local d = GetDistance2D(myHero.pos, minion.pos)
        if d <= SPELL_RANGE.W then
            local count = 0
            for _, otherMinion in ipairs(minions) do
                if GetDistance2D(minion.pos, otherMinion.pos) <= SPELL_RANGE.E then
                    count = count + 1
                end
            end
            
            if count > bestCount then
                bestCount = count
                bestPos = minion.pos
            end
        end
    end
    
    return bestPos
end

local function GetBestQPositionForJungle(minions)
    local bestPos = nil
    local maxHealth = 0
    
    for _, minion in ipairs(minions) do
        local d = GetDistance2D(myHero.pos, minion.pos)
        if d <= SPELL_RANGE.Q then
            if minion.maxHealth and minion.maxHealth > maxHealth then
                maxHealth = minion.maxHealth
                bestPos = minion.pos
            end
        end
    end
    
    return bestPos
end

local function LoadMenu()
    Zed.Menu = MenuElement({type = MENU, id = "DepressiveZed", name = "Depressive - Zed"})
    
    -- Combo
    Zed.Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    Zed.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
    Zed.Menu.combo:MenuElement({id = "useW", name = "Use W", value = true})
    Zed.Menu.combo:MenuElement({id = "useE", name = "Use E", value = true})
    Zed.Menu.combo:MenuElement({id = "useR", name = "Use R", value = true})
    Zed.Menu.combo:MenuElement({id = "minHitChance", name = "Min Hit Chance", value = 3, min = 1, max = 6, step = 1})
    Zed.Menu.combo:MenuElement({id = "wDelay", name = "Delay after W (s)", value = 0.20, min = 0.00, max = 0.60, step = 0.05})
    Zed.Menu.combo:MenuElement({id = "extendQRange", name = "Extend Q Range with W", value = true})

    Zed.Menu.combo:MenuElement({id = "smartCombo", name = "Smart W-E-R-Q Combo", value = true})
    Zed.Menu.combo:MenuElement({id = "comboMode", name = "Combo Mode", value = 1, min = 1, max = 2, step = 1, tooltip = "1 = Smart W-E-R-Q, 2 = Standard R-W-E-Q"})
    Zed.Menu.combo:MenuElement({id = "smartComboRange", name = "Smart Combo Max Range", value = 100, min = 50, max = 200, step = 10, tooltip = "Additional range for smart combo execution"})
    
    -- Harass
    Zed.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    Zed.Menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
    Zed.Menu.harass:MenuElement({id = "useW", name = "Use W", value = true})
    Zed.Menu.harass:MenuElement({id = "useE", name = "Use E", value = true})
    Zed.Menu.harass:MenuElement({id = "manaPercent", name = "Min Mana %", value = 40, min = 20, max = 80, step = 5})
    
    -- Clear
    Zed.Menu:MenuElement({type = MENU, id = "clear", name = "Lane Clear"})
    Zed.Menu.clear:MenuElement({id = "useQ", name = "Use Q", value = true})
    Zed.Menu.clear:MenuElement({id = "useW", name = "Use W", value = true})
    Zed.Menu.clear:MenuElement({id = "useE", name = "Use E", value = true})
    Zed.Menu.clear:MenuElement({id = "minMinions", name = "Min minions for W", value = 1, min = 1, max = 6, step = 1})
    Zed.Menu.clear:MenuElement({id = "manaPercent", name = "Min Mana %", value = 30, min = 10, max = 70, step = 5})
    
    -- Jungle
    Zed.Menu:MenuElement({type = MENU, id = "jungle", name = "Jungle Clear"})
    Zed.Menu.jungle:MenuElement({id = "useQ", name = "Use Q", value = true})
    Zed.Menu.jungle:MenuElement({id = "useW", name = "Use W", value = true})
    Zed.Menu.jungle:MenuElement({id = "useE", name = "Use E", value = true})
    

    
    -- Drawing
    Zed.Menu:MenuElement({type = MENU, id = "drawing", name = "Drawing"})
    Zed.Menu.drawing:MenuElement({id = "ranges", name = "Show Ranges", value = true})
    Zed.Menu.drawing:MenuElement({id = "damage", name = "Show Damage", value = true})
    
    -- Automation
    Zed.Menu:MenuElement({type = MENU, id = "auto", name = "Automation"})
    Zed.Menu.auto:MenuElement({id = "autoE", name = "Auto E on shadows", value = true})
end

-- Funciones de automatización que deben definirse antes de Tick
local function AutoE()
    if not Ready(_E) then return end
    
    local enemies = GetEnemyHeroes()
    for _, enemy in ipairs(enemies) do
        if IsValidTarget(enemy, 2000) then
            -- Verificar si el enemigo está en rango de E desde Zed
            if GetDistance2D(myHero.pos, enemy.pos) <= SPELL_RANGE.E then
                Control.CastSpell(HK_E)
                return
            end
            
            -- Verificar si la sombra W puede golpear (más precisa)
            if Wshadow and WTime > 0 and (Game.Timer() - WTime) < 5 then
                if GetDistance2D(Wshadow, enemy.pos) <= SPELL_RANGE.E then
                    Control.CastSpell(HK_E)
                    return
                end
            end
            
            -- Verificar si la sombra R puede golpear (más precisa)
            if Rshadow and RTime > 0 and (Game.Timer() - RTime) < 6.5 then
                if GetDistance2D(Rshadow, enemy.pos) <= SPELL_RANGE.E then
                    Control.CastSpell(HK_E)
                    return
                end
            end
            
            -- Verificar si alguna sombra adicional del escaneo puede golpear
            for _, shadowPos in ipairs(Shadows) do
                if shadowPos and GetDistance2D(shadowPos, enemy.pos) <= SPELL_RANGE.E then
                    Control.CastSpell(HK_E)
                    return
                end
            end
        end
    end
end

-- Funciones de casting que deben definirse antes de las funciones principales

-- Función para verificar si W está en forma de sombra (W2)
local function IsWShadowActive()
    local wSpellData = myHero:GetSpellData(_W)
    return wSpellData and wSpellData.name == "ZedW2"
end

-- Función para verificar si se puede usar W (no está en forma de sombra)
local function CanUseW()
    -- Verificar que W esté disponible y no esté en forma de sombra
    if not Ready(_W) or IsWShadowActive() then return false end
    
    -- Verificar que no se haya lanzado W recientemente (evitar doble cast)
    local now = Game.Timer()
    if now - Zed.lastWCastTime < 0.1 then return false end
    
    return true
end

-- Función para verificar si R está en forma de sombra (R2)
local function IsRShadowActive()
    local rSpellData = myHero:GetSpellData(_R)
    return rSpellData and rSpellData.name == "ZedR2"
end

local function CastQ(target)
    if not Ready(_Q) or not target then return false end
    
    -- Verificar que Zed esté inicializado
    if not Zed then return false end
    
    -- Verificar delay de W
    if Zed.wCastTime > 0 and (Game.Timer() - Zed.wCastTime) < Zed.wDelay then
        return false
    end
    
    local distance = GetDistance2D(myHero.pos, target.pos)
    local minHitChance = (Zed.Menu and Zed.Menu.combo and Zed.Menu.combo.minHitChance:Value()) or 3
    
    -- Cast directo si está en rango de Q desde Zed
    if distance <= SPELL_RANGE.Q then
        local pred, hitChance = GetPrediction(target, "Q")
        if pred and hitChance >= minHitChance then
            Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
            return true
        end
    end
    
    -- Si está fuera del rango de Q, intentar extender el rango con W
    if distance > SPELL_RANGE.Q then
        -- Verificar si la extensión de rango está habilitada
        local extendRange = (Zed.Menu and Zed.Menu.combo and Zed.Menu.combo.extendQRange:Value()) or true
        
        if extendRange then
            -- Verificar si W está disponible y no está en forma de sombra
            if CanUseW() then
                -- Calcular posición óptima para W que ponga al objetivo en rango de Q
                local direction = (target.pos - myHero.pos):Normalized()
                local wCastPos = myHero.pos + direction * (SPELL_RANGE.W - 50) -- Un poco menos del rango máximo de W
                
                -- Verificar que la posición esté dentro del rango de W
                if GetDistance2D(myHero.pos, wCastPos) <= SPELL_RANGE.W then
                    -- Lanzar W para extender el rango
                    Control.CastSpell(HK_W, wCastPos)
                    Zed.wCastTime = Game.Timer()
                    Zed.lastWCastTime = Game.Timer()
                    WTime = Game.Timer()
                    Wshadow = Vector(wCastPos.x, wCastPos.y, wCastPos.z)
                    
                    -- Esperar un pequeño delay y luego lanzar Q
                    DelayAction(function()
                        if Ready(_Q) and IsValidTarget(target) then
                            local pred, hitChance = GetPrediction(target, "Q")
                            if pred and hitChance >= minHitChance then
                                Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                            end
                        end
                    end, Zed.wDelay + 0.1) -- Delay de W + pequeño margen
                    
                    return true
                end
            end
        end
        
        -- Si W no está disponible o la extensión está deshabilitada, intentar desde sombras existentes
        for _, shadowPos in ipairs(Shadows) do
            if GetDistance2D(shadowPos, target.pos) <= SPELL_RANGE.Q then
                local pred, hitChance = GetPrediction(target, "Q")
                if pred and hitChance >= minHitChance then
                    Control.CastSpell(HK_Q, Vector(pred.x, myHero.pos.y, pred.z))
                    return true
                end
            end
        end
    end
    
    return false
end

local function CastW(target)
    if not Ready(_W) or not target then return false end
    
    -- Verificar que Zed esté inicializado
    if not Zed then return false end
    
    -- Verificar que W esté disponible (no en forma de sombra)
    if not CanUseW() then return false end
    
    -- Verificar que Q o E estén disponibles para follow-up
    if not Ready(_Q) and not Ready(_E) then return false end
    
    local distance = GetDistance2D(myHero.pos, target.pos)
    local minHitChance = (Zed.Menu and Zed.Menu.combo and Zed.Menu.combo.minHitChance:Value()) or 3
    
    if distance <= SPELL_RANGE.W then
        local pred, hitChance = GetPrediction(target, "W")
        if pred and hitChance >= minHitChance then
            Control.CastSpell(HK_W, Vector(pred.x, myHero.pos.y, pred.z))
            Zed.wCastTime = Game.Timer()
            Zed.lastWCastTime = Game.Timer()
            WTime = Game.Timer()
            Wshadow = Vector(pred.x, myHero.pos.y, pred.z)
            return true
        end
    end
    
    return false
end



local function CastE()
    if not Ready(_E) then return false end
    
    -- Verificar delay de W
    if Zed.wCastTime > 0 and (Game.Timer() - Zed.wCastTime) < Zed.wDelay then
        return false
    end
    
    local enemies = GetEnemyHeroes()
    for _, enemy in ipairs(enemies) do
        if IsValidTarget(enemy, 2000) then
            local canCastE = false
            
            -- Verificar si el enemigo está en rango de E desde Zed
            if GetDistance2D(myHero.pos, enemy.pos) <= SPELL_RANGE.E then
                canCastE = true
            end
            
            -- Verificar si la sombra W puede golpear (más precisa)
            if Wshadow and WTime > 0 and (Game.Timer() - WTime) < 5 then
                if GetDistance2D(Wshadow, enemy.pos) <= SPELL_RANGE.E then
                    canCastE = true
                end
            end
            
            -- Verificar si la sombra R puede golpear (más precisa)
            if Rshadow and RTime > 0 and (Game.Timer() - RTime) < 6.5 then
                if GetDistance2D(Rshadow, enemy.pos) <= SPELL_RANGE.E then
                    canCastE = true
                end
            end
            
            -- Verificar si alguna sombra adicional del escaneo puede golpear
            for _, shadowPos in ipairs(Shadows) do
                if shadowPos and GetDistance2D(shadowPos, enemy.pos) <= SPELL_RANGE.E then
                    canCastE = true
                    break
                end
            end
            
            if canCastE then
                Control.CastSpell(HK_E)
                return true
            end
        end
    end
    
    return false
end

local function CastR(target)
    if not Ready(_R) or not target then return false end
    
    -- Verificar que R esté disponible (no R2)
    if IsRShadowActive() then return false end
    
    local distance = GetDistance2D(myHero.pos, target.pos)
    if distance > SPELL_RANGE.R then return false end
    
    Control.CastSpell(HK_R, target.pos)
    RTime = Game.Timer()
    Rshadow = Vector(myHero.pos.x, myHero.pos.y, myHero.pos.z)
    return true
end

-- Funciones principales que deben definirse después de las funciones de casting

-- Función para verificar si el combo inteligente es viable
local function IsSmartComboViable(target)
    if not target then return false end
    
    local distance = GetDistance2D(myHero.pos, target.pos)
    local additionalRange = (Zed.Menu.combo.smartComboRange and Zed.Menu.combo.smartComboRange:Value()) or 100
    local maxComboRange = SPELL_RANGE.W + SPELL_RANGE.E + additionalRange -- Rango máximo del combo
    
    -- Verificar rango
    if distance > maxComboRange then return false end
    
    -- Verificar que todas las habilidades necesarias estén disponibles
    local hasW = Zed.Menu.combo.useW:Value() and CanUseW()
    local hasE = Zed.Menu.combo.useE:Value() and Ready(_E)
    local hasR = Zed.Menu.combo.useR:Value() and Ready(_R) and not IsRShadowActive()
    local hasQ = Zed.Menu.combo.useQ:Value() and Ready(_Q)
    
    -- El combo necesita al menos W y E, y preferiblemente R y Q
    return hasW and hasE and (hasR or hasQ)
end

-- Función para el combo inteligente W-E-R-Q
local function SmartWERQCombo(target)
    if not target then return false end
    
    -- Verificar si se lanzó W recientemente para evitar doble cast
    local now = Game.Timer()
    if now - Zed.lastWCastTime < 0.1 then return false end
    
    -- Verificar si el combo es viable
    if not IsSmartComboViable(target) then return false end
    
    -- PASO 1: W - Posicionar sombra cerca del objetivo
    if Zed.Menu.combo.useW:Value() and CanUseW() then
        -- Calcular posición óptima para W que ponga al objetivo en rango de E
        local direction = (target.pos - myHero.pos):Normalized()
        local wCastPos = myHero.pos + direction * (SPELL_RANGE.W - 100)
        
        -- Verificar que la posición esté dentro del rango de W
        if GetDistance2D(myHero.pos, wCastPos) <= SPELL_RANGE.W then
            Control.CastSpell(HK_W, wCastPos)
            Zed.wCastTime = Game.Timer()
            Zed.lastWCastTime = Game.Timer()
            WTime = Game.Timer()
            Wshadow = Vector(wCastPos.x, wCastPos.y, wCastPos.z)
            
            -- Esperar un pequeño delay y continuar con el combo
            DelayAction(function()
                if IsValidTarget(target) then
                    -- PASO 2: E - Ralentizar al objetivo desde ambas posiciones
                    if Zed.Menu.combo.useE:Value() and Ready(_E) then
                        Control.CastSpell(HK_E)
                        
                        -- PASO 3: R - Usar ultimate inmediatamente después de E
                        DelayAction(function()
                            if Zed.Menu.combo.useR:Value() and Ready(_R) and not IsRShadowActive() then
                                if GetDistance2D(myHero.pos, target.pos) <= SPELL_RANGE.R then
                                    Control.CastSpell(HK_R, target.pos)
                                    RTime = Game.Timer()
                                    Rshadow = Vector(myHero.pos.x, myHero.pos.y, myHero.pos.z)
                                    
                                    -- PASO 4: Q - Lanzar Q después de R para maximizar daño del Death Mark
                                    DelayAction(function()
                                        if Zed.Menu.combo.useQ:Value() and Ready(_Q) and IsValidTarget(target) then
                                            CastQ(target)
                                        end
                                    end, 0.1) -- Pequeño delay para asegurar que R se complete
                                end
                            end
                        end, 0.05) -- Delay muy corto entre E y R
                    end
                end
            end, Zed.wDelay + 0.05) -- Delay de W + pequeño margen
            
            return true
        end
    end
    
    return false
end

-- Función para el combo estándar R-W-E-Q
local function StandardCombo(target)
    if not target then return false end
    
    -- Verificar si se lanzó W recientemente para evitar doble cast
    local now = Game.Timer()
    if now - Zed.lastWCastTime < 0.1 then return false end
    
    -- R primero si está disponible
    if Zed.Menu.combo.useR:Value() and Ready(_R) and not IsRShadowActive() then
        if CastR(target) then return true end
    end
    
    -- W si está disponible
    if Zed.Menu.combo.useW:Value() and CanUseW() then
        if CastW(target) then return true end
    end
    
    -- E después de W
    if Zed.Menu.combo.useE:Value() and Ready(_E) then
        if CastE() then return true end
    end
    
    -- Q último
    if Zed.Menu.combo.useQ:Value() and Ready(_Q) then
        CastQ(target)
        return true
    end
    
    return false
end

local function Combo()
    local target = GetBestTarget()
    if not target then return end
    
    -- Verificar que Zed esté inicializado
    if not Zed or not Zed.Menu then return end
    
    local comboMode = (Zed.Menu.combo.comboMode and Zed.Menu.combo.comboMode:Value()) or 1
    
    if comboMode == 1 and Zed.Menu.combo.smartCombo:Value() then
        -- Intentar combo inteligente W-E-R-Q primero
        if SmartWERQCombo(target) then return end
        
        -- Si el combo inteligente no es viable, fallback al combo estándar
        if StandardCombo(target) then return end
    else
        -- Combo estándar R-W-E-Q
        if StandardCombo(target) then return end
    end
end

local function Harass()
    local target = GetBestTarget()
    if not target then return end
    
    -- Verificar que Zed esté inicializado
    if not Zed or not Zed.Menu then return end
    
    local manaPercent = (myHero.mana / myHero.maxMana) * 100
    if manaPercent < (Zed.Menu.harass and Zed.Menu.harass.manaPercent:Value() or 40) then return end
    
    -- W-Q harass (solo si Q o E están disponibles)
    if Zed.Menu.harass and Zed.Menu.harass.useW:Value() and CanUseW() then
        -- Verificar que Q o E estén disponibles para follow-up
        if Ready(_Q) or Ready(_E) then
            local distance = GetDistance2D(myHero.pos, target.pos)
            if distance <= SPELL_RANGE.Q then
                if CastW(target) then return end
            end
        end
    end
    
    -- E
    if Zed.Menu.harass and Zed.Menu.harass.useE:Value() then
        if CastE() then return end
    end
    
    -- Q
    if Zed.Menu.harass and Zed.Menu.harass.useQ:Value() then
        CastQ(target)
    end
end

local function Clear()
    -- Verificar que Zed esté inicializado
    if not Zed or not Zed.Menu then return end
    
    local manaPercent = (myHero.mana / myHero.maxMana) * 100
    if manaPercent < (Zed.Menu.clear and Zed.Menu.clear.manaPercent:Value() or 30) then return end
    
    -- Obtener minions
    local minions = {}
    for i = 1, Game.MinionCount() do
        local m = Game.Minion(i)
        if m and m.isEnemy and not m.dead and GetDistance2D(myHero.pos, m.pos) <= 1500 then
            table.insert(minions, m)
        end
    end
    
    if #minions == 0 then return end
    
    -- W para múltiples minions (solo si Q o E están disponibles)
    if Zed.Menu.clear and Zed.Menu.clear.useW:Value() and CanUseW() then
        -- Verificar que Q o E estén disponibles para follow-up
        if Ready(_Q) or Ready(_E) then
            local bestPos = GetBestWPositionForClear(minions)
            if bestPos then
                Control.CastSpell(HK_W, bestPos)
                Zed.lastWCastTime = Game.Timer()
                return
            end
        end
    end
    
    -- E
    if Zed.Menu.clear and Zed.Menu.clear.useE:Value() and Ready(_E) then
        local minionsInRange = 0
        for _, minion in ipairs(minions) do
            if GetDistance2D(myHero.pos, minion.pos) <= SPELL_RANGE.E then
                minionsInRange = minionsInRange + 1
            end
        end
        
        if minionsInRange >= 1 then
            Control.CastSpell(HK_E)
            return
        end
    end
    
    -- Q
    if Zed.Menu.clear and Zed.Menu.clear.useQ:Value() and Ready(_Q) then
        local bestQPos = GetBestQPositionForClear(minions)
        if bestQPos then
            Control.CastSpell(HK_Q, bestQPos)
        end
    end
end

local function JungleClear()
    -- Verificar que Zed esté inicializado
    if not Zed or not Zed.Menu then return end
    
    -- Similar a Clear pero para monstruos neutrales
    local minions = {}
    for i = 1, Game.MinionCount() do
        local m = Game.Minion(i)
        if m and m.team == 300 and not m.dead and GetDistance2D(myHero.pos, m.pos) <= 1500 then
            table.insert(minions, m)
        end
    end
    
    if #minions == 0 then return end
    
    -- W (solo si Q o E están disponibles)
    if Zed.Menu.jungle and Zed.Menu.jungle.useW:Value() and CanUseW() then
        -- Verificar que Q o E estén disponibles para follow-up
        if Ready(_Q) or Ready(_E) then
            local bestPos = GetBestWPositionForJungle(minions)
            if bestPos then
                Control.CastSpell(HK_W, bestPos)
                Zed.lastWCastTime = Game.Timer()
                return
            end
        end
    end
    
    -- E
    if Zed.Menu.jungle and Zed.Menu.jungle.useE:Value() and Ready(_E) then
        for _, minion in ipairs(minions) do
            if GetDistance2D(myHero.pos, minion.pos) <= SPELL_RANGE.E then
                Control.CastSpell(HK_E)
                return
            end
        end
    end
    
    -- Q
    if Zed.Menu.jungle and Zed.Menu.jungle.useQ:Value() and Ready(_Q) then
        local bestQPos = GetBestQPositionForJungle(minions)
        if bestQPos then
            Control.CastSpell(HK_Q, bestQPos)
        end
    end
end

-- Función Tick que debe definirse después de las funciones principales
local function Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    -- Verificar que Zed esté inicializado
    if not Zed then return end
    
    -- Actualizar sombras
    FindZedShadows()
    

    
    -- Auto E
    if Zed.Menu and Zed.Menu.auto and Zed.Menu.auto.autoE:Value() then
        AutoE()
    end
    
    -- Detectar teclas
    if Zed.keysPressed and Zed.keysPressed.space then
        Combo()
    elseif Zed.keysPressed and Zed.keysPressed.c then
        Harass()
    elseif Zed.keysPressed and Zed.keysPressed.v then
        Clear()
    elseif Zed.keysPressed and Zed.keysPressed.x then
        JungleClear()
    end
    
    -- Sincronizar delay
    if Zed.Menu and Zed.Menu.combo and Zed.Menu.combo.wDelay then
        Zed.wDelay = Zed.Menu.combo.wDelay:Value()
    end
end

local function OnWndMsg(msg, wParam)
    -- Verificar que Zed esté inicializado
    if not Zed or not Zed.keysPressed then return end
    
    -- Detectar teclas automáticamente
    if msg == 0x0100 then -- KEY_DOWN
        if wParam == 32 then -- Space
            Zed.keysPressed.space = true
        elseif wParam == string.byte("C") then
            Zed.keysPressed.c = true
        elseif wParam == string.byte("V") then
            Zed.keysPressed.v = true
        elseif wParam == string.byte("X") then
            Zed.keysPressed.x = true
        end
    elseif msg == 0x0101 then -- KEY_UP
        if wParam == 32 then -- Space
            Zed.keysPressed.space = false
        elseif wParam == string.byte("C") then
            Zed.keysPressed.c = false
        elseif wParam == string.byte("V") then
            Zed.keysPressed.v = false
        elseif wParam == string.byte("X") then
            Zed.keysPressed.x = false
        end
    end
end

-- Función Draw que debe definirse antes de InitializeZed
local function DrawZed()
    if myHero.dead then return end
    
    -- Verificar que Zed esté inicializado
    if not Zed or not Zed.Menu then return end
    
    -- Draw ranges
    if Zed.Menu.drawing and Zed.Menu.drawing.ranges:Value() then
        if Zed.Menu.combo and Zed.Menu.combo.useQ:Value() and Ready(_Q) then
            Draw.Circle(myHero.pos, SPELL_RANGE.Q, 2, Draw.Color(100, 255, 255, 0))
        end
        if Zed.Menu.combo and Zed.Menu.combo.useW:Value() and Ready(_W) and myHero:GetSpellData(_W).name ~= "ZedW2" then
            Draw.Circle(myHero.pos, SPELL_RANGE.W, 2, Draw.Color(100, 0, 255, 0))
        end
        if Zed.Menu.combo and Zed.Menu.combo.useE:Value() and Ready(_E) then
            Draw.Circle(myHero.pos, SPELL_RANGE.E, 2, Draw.Color(100, 255, 0, 255))
        end
        if Zed.Menu.combo and Zed.Menu.combo.useR:Value() and Ready(_R) and myHero:GetSpellData(_R).name ~= "ZedR2" then
            Draw.Circle(myHero.pos, SPELL_RANGE.R, 2, Draw.Color(100, 255, 0, 0))
        end
    end
    
    -- Draw damage
    if Zed.Menu.drawing and Zed.Menu.drawing.damage:Value() then
        local enemies = GetEnemyHeroes()
        for _, enemy in ipairs(enemies) do
            if IsValidTarget(enemy, 2000) then
                local totalDamage = CalculateTotalDamage(enemy)
                local killable = enemy.health <= totalDamage
                local color = killable and Draw.Color(255, 255, 0, 0) or Draw.Color(255, 255, 255, 255)
                local pct = (totalDamage > 0 and enemy.health > 0) and ((totalDamage / enemy.health) * 100) or 0
                local text = string.format("DMG: %d (%.0f%%)", math.floor(totalDamage), pct)
                if killable then text = "KILLABLE - " .. text end
                

                
                if enemy.pos2D then
                    Draw.Text(text, 16, enemy.pos2D.x - 50, enemy.pos2D.y + 30, color)
                end
            end
        end
    end
    

end

-- Función de inicialización
local function InitializeZed()
    LoadMenu()
    

    
    -- Callbacks
    Callback.Add("Tick", function() Tick() end)
    Callback.Add("Draw", function() DrawZed() end)
    Callback.Add("WndMsg", function(msg, wParam) OnWndMsg(msg, wParam) end)
end



-- Inicializar el script
DelayAction(function()
    InitializeZed()
    _G.DepressiveZed = Zed
end, 1.0)
