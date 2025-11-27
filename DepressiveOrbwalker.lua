local __name__ = "DepressiveOrbwalker"
local __version__ = 1.6

if _G.DepressiveOrbUpdate then
	return
end
_G.DepressiveOrbUpdate = {}
do
	function DepressiveOrbUpdate:__init()
		self.Callbacks = {}
	end

	function DepressiveOrbUpdate:DownloadFile(url, path)
		DownloadFileAsync(url, path, function() end)
	end

	function DepressiveOrbUpdate:Trim(s)
		local from = s:match("^%s*()")
		return from > #s and "" or s:match(".*%S", from)
	end

	function DepressiveOrbUpdate:ReadFile(path)
		local result = {}
		local file = io.open(path, "r")
		if file then
			for line in file:lines() do
				local str = self:Trim(line)
				if #str > 0 then
					table.insert(result, str)
				end
			end
			file:close()
		end
		return result
	end

	function DepressiveOrbUpdate:New(args)
		local updater = {}
		function updater:__init()
			self.Step = 1
			self.Version = type(args.version) == "number" and args.version or tonumber(args.version)
			self.VersionUrl = args.versionUrl
			self.VersionPath = args.versionPath
			self.ScriptUrl = args.scriptUrl
			self.ScriptPath = args.scriptPath
			self.ScriptName = args.scriptName
			self.VersionTimer = GetTickCount()
			self:DownloadVersion()
		end
		function updater:DownloadVersion()
			if not FileExist(self.ScriptPath) then
				self.Step = 4
				DepressiveOrbUpdate:DownloadFile(self.ScriptUrl, self.ScriptPath)
				self.ScriptTimer = GetTickCount()
				return
			end
			DepressiveOrbUpdate:DownloadFile(self.VersionUrl, self.VersionPath)
		end
		function updater:OnTick()
			if self.Step == 0 then
				return
			end
			if self.Step == 1 then
				if GetTickCount() > self.VersionTimer + 1000 then
					local response = DepressiveOrbUpdate:ReadFile(self.VersionPath)
					if #response > 0 and tonumber(response[1]) > self.Version then
						self.Step = 2
						self.NewVersion = response[1]
						DepressiveOrbUpdate:DownloadFile(self.ScriptUrl, self.ScriptPath)
						self.ScriptTimer = GetTickCount()
					else
						self.Step = 3
					end
				end
			end
			if self.Step == 2 then
				if GetTickCount() > self.ScriptTimer + 1000 then
					self.Step = 0
					print(
						self.ScriptName
							.. " - new update found! ["
							.. tostring(self.Version)
							.. " -> "
							.. self.NewVersion
							.. "] Please 2xf6!"
					)
				end
				return
			end
			if self.Step == 3 then
				self.Step = 0
				return
			end
			if self.Step == 4 then
				if GetTickCount() > self.ScriptTimer + 1000 then
					self.Step = 0
					print(self.ScriptName .. " - downloaded! Please 2xf6!")
				end
			end
		end
		function updater:CanUpdate()
			local response = DepressiveOrbUpdate:ReadFile(self.VersionPath)
			return #response > 0 and tonumber(response[1]) > self.Version
		end
		updater:__init()
		table.insert(self.Callbacks, updater)
		return updater
	end
	DepressiveOrbUpdate:__init()
end

Callback.Add("Tick", function()
	for _, updater in ipairs(DepressiveOrbUpdate.Callbacks) do
		if updater.Step > 0 then
			updater:OnTick()
		end
	end
end)

if
	DepressiveOrbUpdate:New({
		version = __version__,
		scriptName = __name__,
		scriptPath = SCRIPT_PATH .. "DepressiveOrbwalker.lua",
		scriptUrl = "https://raw.githubusercontent.com/DepressiveKyo/GoS/master/DepressiveOrbwalker.lua",
		versionPath = SCRIPT_PATH .. "DepressiveOrbwalker.version",
		versionUrl = "https://raw.githubusercontent.com/DepressiveKyo/GoS/master/DepressiveOrbwalker.version",
	}):CanUpdate()
then
	return
end

--#region headers

-- OPTIMIZACIÓN: Localizar todas las funciones de math en el scope local
local math_huge = math.huge
local math_pi = math.pi
local math_ceil = assert(math.ceil)
local math_floor = assert(math.floor)
local math_min = assert(math.min)
local math_max = assert(math.max)
local math_atan = assert(math.atan)
local math_random = assert(math.random)
local math_sqrt = assert(math.sqrt)
local math_abs = assert(math.abs)

local table_sort = assert(table.sort)
local table_remove = assert(table.remove)
local table_insert = assert(table.insert)

-- OPTIMIZACIÓN: Localizar variables globales frecuentemente usadas
local myHero = myHero
local os = os
local math = math
local Game = Game
local Vector = Vector
local Control = Control
local Draw = Draw
local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local tonumber = tonumber
local GetTickCount = GetTickCount
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local next = next
local string_format = string.format
local string_lower = string.lower
local string_find = string.find

local GameTimer = Game.Timer
local GameIsOnTop = Game.IsOnTop
local GameIsChatOpen = Game.IsChatOpen
local GameCanUseSpell = Game.CanUseSpell
local GameWard = Game.Ward
local GameHero = Game.Hero
local GameObject = Game.Object
local GameTurret = Game.Turret
local GameMinion = Game.Minion
local GameWardCount = Game.WardCount
local GameHeroCount = Game.HeroCount
local GameObjectCount = Game.ObjectCount
local GameTurretCount = Game.TurretCount
local GameMinionCount = Game.MinionCount

-- OPTIMIZACIÓN: Constantes matemáticas precalculadas
local DEG_TO_RAD = math_pi / 180.0
local RAD_TO_DEG = 180.0 / math_pi

--#endregion

--#region methods

-- OPTIMIZACIÓN: IsInRange sin crear tablas intermedias
local function IsInRange(p1, p2, range)
	local pos1, pos2
	if p1.pos then pos1 = p1.pos else pos1 = p1 end
	if p2 then
		if p2.pos then pos2 = p2.pos else pos2 = p2 end
	else
		pos2 = myHero.pos
	end
	local dx = pos1.x - pos2.x
	local dy = (pos1.z or pos1.y) - (pos2.z or pos2.y)
	return dx * dx + dy * dy <= range * range
end

-- OPTIMIZACIÓN: GetDistance con sqrt local
local function GetDistance(p1, p2)
	local pos1, pos2
	if p1.pos then pos1 = p1.pos else pos1 = p1 end
	if p2 then
		if p2.pos then pos2 = p2.pos else pos2 = p2 end
	else
		pos2 = myHero.pos
	end
	local dx = pos1.x - pos2.x
	local dy = (pos1.z or pos1.y) - (pos2.z or pos2.y)
	return math_sqrt(dx * dx + dy * dy)
end

-- OPTIMIZACIÓN: GetDistanceSq para comparaciones de rango (evita sqrt)
local function GetDistanceSq(p1, p2)
	local pos1, pos2
	if p1.pos then pos1 = p1.pos else pos1 = p1 end
	if p2 then
		if p2.pos then pos2 = p2.pos else pos2 = p2 end
	else
		pos2 = myHero.pos
	end
	local dx = pos1.x - pos2.x
	local dy = (pos1.z or pos1.y) - (pos2.z or pos2.y)
	return dx * dx + dy * dy
end

-- OPTIMIZACIÓN: Polar con constante precalculada
local function Polar(v1)
	local x = v1.x
	local z = v1.z or v1.y
	if x == 0 then
		if z > 0 then
			return 90
		end
		return z < 0 and 270 or 0
	end
	local theta = math_atan(z / x) * RAD_TO_DEG
	if x < 0 then
		theta = theta + 180
	end
	if theta < 0 then
		theta = theta + 360
	end
	return theta
end

local function AngleBetween(vec1, vec2)
	local theta = Polar(vec1) - Polar(vec2)
	if theta < 0 then
		theta = theta + 360
	end
	if theta > 180 then
		theta = 360 - theta
	end
	return theta
end

local function IsFacing(source, target, angle)
	angle = angle or 90
	target = target.pos or Vector(target)
	return AngleBetween(source.dir, target - source.pos) < angle
end

local function Base64Decode(data)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = string.gsub(data, "[^" .. b .. "=]", "")
	return (
		data:gsub(".", function(x)
			if x == "=" then
				return ""
			end
			local r, f = "", (b:find(x) - 1)
			for i = 6, 1, -1 do
				r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
			end
			return r
		end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
			if #x ~= 8 then
				return ""
			end
			local c = 0
			for i = 1, 8 do
				c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
			end
			return string.char(c)
		end)
	)
end

local function GetControlPos(a, b, c)
	local pos
	if a and b and c then
		-- Interprets as (x, z, unused) for 3D world coordinates
		-- The y (height) will be determined at conversion time using myHero.pos.y
		pos = { x = a, y = nil, z = b }  -- Note: y is nil, will use myHero.pos.y when needed
	elseif a and b then
		pos = { x = a, y = b }
	elseif a then
		pos = a.pos or a
	end
	return pos
end

local function CastKey(key)
	if key == MOUSEEVENTF_RIGHTDOWN then
		Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
		Control.mouse_event(MOUSEEVENTF_RIGHTUP)
	else
		Control.KeyDown(key)
		Control.KeyUp(key)
	end
end

local function GetBuffTypes(menu)
	--[[enum class BuffType {
		Internal = 0,
		Aura = 1,
		CombatEnchancer = 2,
		CombatDehancer = 3,
		SpellShield = 4,
		Stun = 5,
		Invisibility = 6,
		Silence = 7,
		Taunt = 8,
		Berserk = 9,
		Polymorph = 10,
		Slow = 11,
		Snare = 12,
		Damage = 13,
		Heal = 14,
		Haste = 15,
		SpellImmunity = 16,
		PhysicalImmunity = 17,
		Invulnerability = 18,
		AttackSpeedSlow = 19,
		NearSight = 20,
		Fear = 22,
		Charm = 23,
		Poison = 24,
		Suppression = 25,
		Blind = 26,
		Counter = 27,
		Currency = 21,
		Shred = 28,
		Flee = 29,
		Knockup = 30,
		Knockback = 31,
		Disarm = 32,
		Grounded = 33,
		Drowsy = 34,
		Asleep = 35,
		Obscured = 36,
		ClickProofToEnemies = 37,
		Unkillable = 38
	};
	--]]
	return {
		[5] = menu.Stun:Value(),
		[12] = menu.Snare:Value(),
		[25] = menu.Supress:Value(),
		[30] = menu.Knockup:Value(),
		[22] = menu.Fear:Value(),
		[23] = menu.Charm:Value(),
		[8] = menu.Taunt:Value(),
		[31] = menu.Knockback:Value(),
		[26] = menu.Blind:Value(),
		[32] = menu.Disarm:Value(),
	}
end

--#endregion

local ChampionInfo, Cached, Menu, Color, Action, Buff, Damage, Data, Spell, SummonerSpell, Item, Object, Target, Orbwalker, Movement, Cursor, Health, Attack, EvadeSupport, SmoothMouse

local DAMAGE_TYPE_PHYSICAL = 0
local DAMAGE_TYPE_MAGICAL = 1
local DAMAGE_TYPE_TRUE = 2

local ORBWALKER_MODE_NONE = -1
local ORBWALKER_MODE_COMBO = 0
local ORBWALKER_MODE_HARASS = 1
local ORBWALKER_MODE_LANECLEAR = 2
local ORBWALKER_MODE_JUNGLECLEAR = 3
local ORBWALKER_MODE_LASTHIT = 4
local ORBWALKER_MODE_FLEE = 5
local ORBWALKER_MODE_SPACING = 6

-- Auto Safe Reset configuration (always enabled)
local AUTO_SAFE_RESET_TIMEOUT = 2000 -- ms

--#region FPS Optimization System
local FPSOptimizer = {
    -- Configuración de optimización
    enabled = true,
    targetFPS = 60,
    currentFPS = 60,
    frameTime = 0,
    lastFrameTime = 0,
    
    -- Contadores y timers
    tickCounter = 0,
    lastTickTime = 0,
    
    -- Intervalos dinámicos (en milisegundos)
    tickInterval = 16,      -- ~60 FPS
    cacheInterval = 100,    -- Cache refresh rate
    
    -- Flags de estado
    highLoadMode = false,
    skipNextTick = false,
    skipNextDraw = false,
    
    -- OPTIMIZACIÓN: Pool de tablas para evitar garbage collection
    _heroPool = {},
    _minionPool = {},
    _objectPool = {},
    
    -- Cache de objetos para reducir llamadas API
    cachedHeroes = {},
    cachedMinions = {},
    cachedObjects = {},
    lastCacheUpdate = 0,
    
    -- Sistema de caché inteligente basado en modos
    smartCacheEnabled = true,
    currentOrbwalkerMode = ORBWALKER_MODE_NONE,
    lastModeCheck = 0,
    modeCheckInterval = 50, -- ms
    
    -- Configuración de caché por modo
    cacheConfig = {
        [ORBWALKER_MODE_COMBO] = {
            cacheHeroes = true,
            cacheMinions = false,
            cacheRange = 1500
        },
        [ORBWALKER_MODE_HARASS] = {
            cacheHeroes = true,
            cacheMinions = true,
            cacheRange = 1200
        },
        [ORBWALKER_MODE_LANECLEAR] = {
            cacheHeroes = true,
            cacheMinions = true,
            cacheRange = 1000
        },
        [ORBWALKER_MODE_JUNGLECLEAR] = {
            cacheHeroes = true,
            cacheMinions = true,
            cacheRange = 1000
        },
        [ORBWALKER_MODE_LASTHIT] = {
            cacheHeroes = true,
            cacheMinions = true,
            cacheRange = 800
        },
        [ORBWALKER_MODE_FLEE] = {
            cacheHeroes = true,
            cacheMinions = true,
            cacheRange = 2000
        },
        [ORBWALKER_MODE_SPACING] = {
            cacheHeroes = true,
            cacheMinions = false,
            cacheRange = 1500
        },
        [ORBWALKER_MODE_NONE] = {
            cacheHeroes = true,
            cacheMinions = true,
            cacheRange = 1500
        }
    },
    
    GetCurrentOrbwalkerMode = function(self)
        local currentTime = GetTickCount()
        if currentTime - self.lastModeCheck < self.modeCheckInterval then
            return self.currentOrbwalkerMode
        end
        
        self.lastModeCheck = currentTime
        
        -- Detectar modo actual del orbwalker (OPTIMIZADO: acceso directo)
        if Orbwalker and Orbwalker.Modes then
            local modes = Orbwalker.Modes
            if modes[ORBWALKER_MODE_COMBO] then
                self.currentOrbwalkerMode = ORBWALKER_MODE_COMBO
            elseif modes[ORBWALKER_MODE_HARASS] then
                self.currentOrbwalkerMode = ORBWALKER_MODE_HARASS
            elseif modes[ORBWALKER_MODE_LANECLEAR] then
                self.currentOrbwalkerMode = ORBWALKER_MODE_LANECLEAR
            elseif modes[ORBWALKER_MODE_JUNGLECLEAR] then
                self.currentOrbwalkerMode = ORBWALKER_MODE_JUNGLECLEAR
            elseif modes[ORBWALKER_MODE_LASTHIT] then
                self.currentOrbwalkerMode = ORBWALKER_MODE_LASTHIT
            elseif modes[ORBWALKER_MODE_FLEE] then
                self.currentOrbwalkerMode = ORBWALKER_MODE_FLEE
            elseif modes[ORBWALKER_MODE_SPACING] then
                self.currentOrbwalkerMode = ORBWALKER_MODE_SPACING
            else
                self.currentOrbwalkerMode = ORBWALKER_MODE_NONE
            end
        else
            self.currentOrbwalkerMode = ORBWALKER_MODE_NONE
        end
        
        return self.currentOrbwalkerMode
    end,
    
    GetCacheConfig = function(self)
        local mode = self:GetCurrentOrbwalkerMode()
        return self.cacheConfig[mode] or self.cacheConfig[ORBWALKER_MODE_NONE]
    end,
    
    Update = function(self)
        local currentTime = GetTickCount()
        
        -- Calcular FPS actual
        if self.lastFrameTime > 0 then
            self.frameTime = currentTime - self.lastFrameTime
            self.currentFPS = math_min(1000 / math_max(self.frameTime, 1), 120)
        end
        self.lastFrameTime = currentTime
        
        -- Ajustar intervalos basado en FPS
        if self.currentFPS < 30 then
            -- FPS bajo - modo de alta carga
            self.highLoadMode = true
            self.tickInterval = 33    -- ~30 FPS
            self.cacheInterval = 200  -- Menos actualizaciones de cache
        elseif self.currentFPS < 45 then
            -- FPS medio
            self.highLoadMode = true
            self.tickInterval = 25    -- ~40 FPS
            self.cacheInterval = 150
        else
            -- FPS alto - modo normal
            self.highLoadMode = false
            self.tickInterval = 16    -- ~60 FPS
            self.cacheInterval = 100
        end
    end,
    
    ShouldTick = function(self)
        local currentTime = GetTickCount()
        if currentTime - self.lastTickTime >= self.tickInterval then
            self.lastTickTime = currentTime
            self.tickCounter = self.tickCounter + 1
            return true
        end
        return false
    end,
    
    ShouldUpdateCache = function(self)
        local currentTime = GetTickCount()
        return currentTime - self.lastCacheUpdate >= self.cacheInterval
    end,
    
    -- OPTIMIZACIÓN: Limpiar tabla sin crear nueva (más eficiente para GC)
    WipeTable = function(self, t)
        for i = #t, 1, -1 do
            t[i] = nil
        end
    end,
    
    UpdateObjectCache = function(self)
        if not self:ShouldUpdateCache() then
            return
        end
        
        local currentTime = GetTickCount()
        self.lastCacheUpdate = currentTime
        
        local config = self:GetCacheConfig()
        local myPos = myHero.pos
        local cacheRangeSq = config.cacheRange * config.cacheRange  -- Pre-calcular rango al cuadrado
        
        -- Cache heroes solo si está habilitado para el modo actual
        if config.cacheHeroes then
            -- OPTIMIZACIÓN: Limpiar tabla sin crear nueva
            self:WipeTable(self.cachedHeroes)
            local heroCount = GameHeroCount()
            for i = 1, heroCount do
                local hero = GameHero(i)
                if hero and hero.valid and not hero.dead and hero.isEnemy then
                    -- Always cache heroes regardless of range (important for long range spells)
                    table_insert(self.cachedHeroes, hero)
                end
            end
        else
            -- Limpiar cache de heroes si no está habilitado
            self:WipeTable(self.cachedHeroes)
        end
        
        -- Cache minions solo si está habilitado para el modo actual
        if config.cacheMinions then
            self:WipeTable(self.cachedMinions)
            local minionCount = GameMinionCount()
            for i = 1, minionCount do
                local minion = GameMinion(i)
                if minion and minion.valid and not minion.dead and minion.isEnemy then
                    -- Usar GetDistanceSq para evitar cálculo de sqrt (más rápido)
                    if GetDistanceSq(minion.pos, myPos) <= cacheRangeSq then
                        table_insert(self.cachedMinions, minion)
                    end
                end
            end
        else
            -- Limpiar cache de minions si no está habilitado
            self:WipeTable(self.cachedMinions)
        end
    end,
    
    GetCachedHeroes = function(self)
        local config = self:GetCacheConfig()
        if config.cacheHeroes then
            return self.cachedHeroes
        end
        return self._heroPool -- Retorna tabla vacía reutilizable
    end,
    
    GetCachedMinions = function(self)
        local config = self:GetCacheConfig()
        if config.cacheMinions then
            return self.cachedMinions
        end
        return self._minionPool
    end,
    
    -- Optimización de loops pesados con chunking
    OptimizeLoop = function(self, collection, maxProcessPerTick)
        maxProcessPerTick = maxProcessPerTick or (self.highLoadMode and 3 or 10)
        
        local collectionSize = #collection
        if collectionSize <= maxProcessPerTick then
            return collection
        end
        
        -- Procesar solo una parte de la colección por tick
        local chunks = math_ceil(collectionSize / maxProcessPerTick)
        local startIdx = ((self.tickCounter - 1) % chunks) * maxProcessPerTick + 1
        local endIdx = math_min(startIdx + maxProcessPerTick - 1, collectionSize)
        
        -- OPTIMIZACIÓN: Reutilizar tabla del pool
        local optimizedCollection = self._objectPool
        self:WipeTable(optimizedCollection)
        
        for i = startIdx, endIdx do
            local item = collection[i]
            if item then
                table_insert(optimizedCollection, item)
            end
        end
        
        return optimizedCollection
    end,
    
    -- Función para obtener información del modo actual (para debugging)
    GetModeInfo = function(self)
        local mode = self:GetCurrentOrbwalkerMode()
        local config = self:GetCacheConfig()
        local modeNames = {
            [ORBWALKER_MODE_NONE] = "NONE",
            [ORBWALKER_MODE_COMBO] = "COMBO",
            [ORBWALKER_MODE_HARASS] = "HARASS", 
            [ORBWALKER_MODE_LANECLEAR] = "LANECLEAR",
            [ORBWALKER_MODE_JUNGLECLEAR] = "JUNGLECLEAR",
            [ORBWALKER_MODE_LASTHIT] = "LASTHIT",
            [ORBWALKER_MODE_FLEE] = "FLEE",
            [ORBWALKER_MODE_SPACING] = "SPACING"
        }
        
        return {
            mode = modeNames[mode] or "UNKNOWN",
            cacheHeroes = config.cacheHeroes,
            cacheMinions = config.cacheMinions,
            cacheRange = config.cacheRange,
            cachedHeroesCount = #self.cachedHeroes,
            cachedMinionsCount = #self.cachedMinions
        }
    end
}
--#endregion

local SORT_AUTO = 1
local SORT_CLOSEST = 2
local SORT_NEAR_MOUSE = 3
local SORT_LOWEST_HEALTH = 4
local SORT_LOWEST_MAX_HEALTH = 5
local SORT_HIGHEST_PRIORITY = 6
local SORT_MOST_STACK = 7
local SORT_MOST_AD = 8
local SORT_MOST_AP = 9
local SORT_LESS_CAST = 10
local SORT_LESS_ATTACK = 11
local SORT_SMART = 12

local ItemSlots = { ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6, ITEM_7 }
local ItemKeys = { HK_ITEM_1, HK_ITEM_2, HK_ITEM_3, HK_ITEM_4, HK_ITEM_5, HK_ITEM_6, HK_ITEM_7 }

local LastChatOpenTimer = 0

ChampionInfo = {

	GwenMistObject = nil,
	GwenMistPos = nil,
	GwenMistEndTime = 0,
	lastGwenMistDetection = 0,

	AzirSoldiers = {},

	OnLoad = function(self) end,

	DrawObjects = function(self)
		local text = {}
		local mePos = myHero.pos
		-- OPTIMIZACIÓN: Constantes precalculadas
		local drawRangeSq = 1690000  -- 1300 * 1300
		local textMergeRangeSq = 2500  -- 50 * 50
		local objectCount = GameObjectCount()
		
		for i = 1, objectCount do
			local obj = GameObject(i)
			if obj then
				local pos = obj.pos
				if pos and GetDistanceSq(mePos, pos) <= drawRangeSq then
					Draw.Circle(pos, 10)
					local pos2D = pos:To2D()
					local contains = false
					local textCount = #text
					for j = 1, textCount do
						local t = text[j]
						if GetDistanceSq(pos2D, t[1]) <= textMergeRangeSq then
							contains = true
							t[2] = t[2] .. tostring(obj.handle) .. " " .. obj.name .. "\n"
							break
						end
					end
					if not contains then
						table_insert(text, { pos2D, tostring(obj.handle) .. " " .. obj.name .. "\n" })
					end
				end
			end
		end
		for i = 1, #text do
			Draw.Text(text[i][2], text[i][1])
		end
	end,

	DrawObject = function(self, obj)
		local text = {}
		local mePos = myHero.pos
		if obj then
			local pos = obj.pos
			local drawRangeSq = 1300 * 1300  -- Pre-calcular rango al cuadrado
			local textMergeRangeSq = 50 * 50  -- Pre-calcular rango de merge al cuadrado
			if pos and GetDistanceSq(mePos, pos) <= drawRangeSq then
				Draw.Circle(pos, 10)
				local pos2D = pos:To2D()
				local contains = false
				for j = 1, #text do
					local t = text[j]
					if GetDistanceSq(pos2D, t[1]) <= textMergeRangeSq then
						contains = true
						t[2] = t[2] .. tostring(obj.handle) .. " " .. obj.name .. "\n"
						break
					end
				end
				if not contains then
					table.insert(text, { pos2D, tostring(obj.handle) .. " " .. obj.name .. "\n" })
				end
			end
		end
		for i = 1, #text do
			Draw.Text(text[i][2], text[i][1])
		end
	end,

	GwenDebug = function(self)
		local enemy = nil
		local enemies = Object:GetEnemyHeroes()
		local myPos = myHero.pos
		local debugRangeSq = 1000 * 1000  -- Pre-calcular rango al cuadrado
		for i = 1, #enemies do
			if GetDistanceSq(enemies[i].pos, myPos) <= debugRangeSq then
				enemy = enemies[i]
				break
			end
		end
		if Buff:HasBuff(myHero, "gwenwuntargetabilitymanager") then
			if not self:IsGwenMistValid() then
				self:DetectGwenMist(myHero)
			end
			self:DrawObject(self.GwenMistObject)
			--print(GetDistance(enemy.pos, self.GwenMistObject.pos))
			--self:DrawObjects()
		elseif enemy then
			--print(GetDistance(enemy.pos, myHero.pos))
		end
		if enemy then
			--print("Gwen is targetable to dummyTarget?: " .. tostring(self:CustomIsTargetable(myHero, enemy)))
		end
	end,

	OnTick = function(self)
		--self:GwenDebug()
		if Object.IsAzir then
			self:DetectAzirSoldiers()
		end
	end,

	CustomIsTargetable = function(self, enemy, ally)
		ally = ally or myHero
				if  Buff:HasBuff(enemy, "gwenwuntargetabilitymanager") then
					if not self:IsGwenMistValid() then
						self:DetectGwenMist(enemy)
					end
					--print(GetDistance(self.GwenMistObject.pos, ally.pos))
					if self.GwenMistObject and
					GetDistance(self.GwenMistObject.pos,
					ally.pos) >= 425 then
						return false
					end
				end
		return true
	end,

	IsGwenMistValid = function(self)
		if os.clock() >= self.GwenMistEndTime then
			self.GwenMistObject = nil
			self.GwenMistPos = nil
		end
		if self.GwenMistObject then
			local name = self.GwenMistObject.name
			if name and name:find("_W_MistArea") then
				local pos = self.GwenMistObject.pos
				if pos and GetDistance(self.GwenMistPos, pos) < 1200 then
					return true
				end
			end
		end
		return false
	end,

	DetectGwenMist = function(self, unit)
		-- Optimización FPS: Limitar frecuencia de detección
		local currentTime = GetTickCount()
		if self.lastGwenMistDetection and currentTime - self.lastGwenMistDetection < 200 then
			return
		end
		self.lastGwenMistDetection = currentTime
		
		local unitPos = unit.pos
		local count = GameObjectCount()
		if count and count > 0 and count < 100000 then
			-- Optimización FPS: Limitar objetos procesados
			local maxObjects = FPSOptimizer.highLoadMode and 20 or 100
			local processed = 0
			
			for i = 1, math.min(count, maxObjects) do
				if processed >= maxObjects then
					break
				end
				
				local o = GameObject(i)
				if o then
					local pos = o.pos
					if pos and GetDistance(unitPos, pos) < 600 then
						local name = o.name
						if name and name:find("_W_MistArea") then
							self.GwenMistObject = o
							self.GwenMistPos = o.pos
							self.GwenMistEndTime = os.clock()
								+ Buff:GetBuffDuration(unit, "gwenwuntargetabilitymanager")
							break
						end
						processed = processed + 1
					end
				end
			end
		end
	end,

	DetectAzirSoldiers = function(self)
		for i = #self.AzirSoldiers, 1, -1 do
			local soldier = self.AzirSoldiers[i]
			if soldier and (soldier.health == 0 or soldier.name ~= "AzirSoldier") then
				table_remove(self.AzirSoldiers, i)
			end
		end
		local activeSpell = myHero.activeSpell
		if activeSpell and activeSpell.valid then
			if activeSpell.name == "AzirWSpawnSoldier" then
				local myPos = myHero.pos
				local detectRangeSq = 1000 * 1000  -- Pre-calcular rango al cuadrado
				for i = 1, GameObjectCount() do
					local obj = GameObject(i)
					if obj and obj.name == "AzirSoldier" and GetDistanceSq(myPos, obj.pos) <= detectRangeSq then
						table_insert(self.AzirSoldiers, obj)
					end
				end
			end
		end
	end,

	IsInAzirSoldierRange = function(self, obj)
		local result = false
		local commandRange = 780
		if(myHero.range == 575) then -- Lethal Tempo grants 50 attack range. Hacky fix.
			commandRange = 830
		end
		local myPos = myHero.pos
		local commandRangeSq = commandRange * commandRange  -- Pre-calcular rango al cuadrado
		local objRangeSq = 350 * 350  -- Pre-calcular rango al cuadrado
		for i = 1, #self.AzirSoldiers do
			local soldier = self.AzirSoldiers[i]
			if
				soldier
				and soldier.name == "AzirSoldier"
				and soldier.health > 0
				and GetDistanceSq(soldier, myPos) <= commandRangeSq
				and GetDistanceSq(soldier, obj.pos) <= objRangeSq
			then
				result = true
			end
		end
		return result
	end,
}

Cached = {

	OtherMinions = {
		["apheliosturret"] = true,
		["fiddlestickseffigy"] = true,
		["gangplankbarrel"] = true,
		["heimertyellow"] = true,
		["heimertblue"] = true,
		["illaoiminion"] = true,
		["jhintrap"] = true,
		["kalistaspawn"] = true,
		["nidaleespear"] = true,
		["sennasoul"] = true,
		["teemomushroom"] = true,
		["yorickwinvisible"] = true,
		["zyragraspingplant"] = true,
		["zyrathornplant"] = true,
		["sru_plant_health"] = true,
		["sru_plant_satchel"] = true,
		["sru_plant_vision"] = true,
		["sru_plant_demon"] = true,
		["cherry_plant_powerup"] = true
	},

	Minions = {},
	TempCachedMinions = {},
	TempCachedWards = {},
	TempCachedTurrets = {},
	TempCachedPlants = {},
	ExtraHeroes = {},
	ExtraUnits = {},
	Turrets = {},
	Wards = {},
	Plants = {},
	Heroes = {},
	Buffs = {},
	HeroesSaved = false,
	MinionsSaved = false,
	ExtraHeroesSaved = false,
	ExtraUnitsSaved = false,
	TurretsSaved = false,
	WardsSaved = false,
	PlantsSaved = false,
	TempCacheBuffer = {m = GameTimer(), w = GameTimer(), t = GameTimer(), p = GameTimer()},
	TempCacheTimeout = 1,

	WndMsg = function(self, msg, wParam)
		local oKeys = {}
		--Fetch hotkeys for orbwalker modes
		if(Orbwalker.MenuKeys) then
			oKeys = {}
			if Orbwalker.MenuKeys[ORBWALKER_MODE_COMBO][1] then
				table_insert(oKeys, Orbwalker.MenuKeys[ORBWALKER_MODE_COMBO][1]:Key())
			end
			if Orbwalker.MenuKeys[ORBWALKER_MODE_FLEE][1] then
				table_insert(oKeys, Orbwalker.MenuKeys[ORBWALKER_MODE_FLEE][1]:Key())
			end
			if Orbwalker.MenuKeys[ORBWALKER_MODE_HARASS][1] then
				table_insert(oKeys, Orbwalker.MenuKeys[ORBWALKER_MODE_HARASS][1]:Key())
			end
			if Orbwalker.MenuKeys[ORBWALKER_MODE_LANECLEAR][1] then
				table_insert(oKeys, Orbwalker.MenuKeys[ORBWALKER_MODE_LANECLEAR][1]:Key())
			end
			if Orbwalker.MenuKeys[ORBWALKER_MODE_JUNGLECLEAR][1] then
				table_insert(oKeys, Orbwalker.MenuKeys[ORBWALKER_MODE_JUNGLECLEAR][1]:Key())
			end
			if Orbwalker.MenuKeys[ORBWALKER_MODE_LASTHIT][1] then
				table_insert(oKeys, Orbwalker.MenuKeys[ORBWALKER_MODE_LASTHIT][1]:Key())
			end
			if Orbwalker.MenuKeys[ORBWALKER_MODE_SPACING][1] then
				table_insert(oKeys, Orbwalker.MenuKeys[ORBWALKER_MODE_SPACING][1]:Key())
			end
		end

		--If we press an orbwalker hotkey, reset our buffer so we immediately cache new minions (we only do this once per button press to prevent lag)
		for _, key in pairs(oKeys) do
			if (msg == KEY_DOWN and wParam == key) then
				self.TempCacheBuffer = {m = GameTimer(), w = GameTimer(), t = GameTimer(), p = GameTimer()}
				return
			end
		end
		
		-- Interrupt smooth movement on user input (debounced)
		local WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MOUSEMOVE = 0x0201, 0x0204, 0x0200
		if msg == WM_LBUTTONDOWN or msg == WM_RBUTTONDOWN or msg == WM_MOUSEMOVE then
			if MenuSmoothMouse and MenuSmoothMouse:Value() and SmoothMouse and SmoothMouse.IsMoving and SmoothMouse:IsMoving() then
				self.UserInputDebounceMs = self.UserInputDebounceMs or 80
				local now = GetTickCount()
				if not self.LastUserInputTick or (now - self.LastUserInputTick) >= self.UserInputDebounceMs then
					SmoothMouse:Stop()
					Cursor:StopSmoothMovement()
					self.LastUserInputTick = now
				end
			end
		end
	end,

	Reset = function(self)
		-- Actualizar FPSOptimizer y cache de objetos
		FPSOptimizer:Update()
		FPSOptimizer:UpdateObjectCache()
		
		-- OPTIMIZACIÓN: Limpiar buffs usando next() (más eficiente que pairs + tabla temporal)
		local buffs = self.Buffs
		local k = next(buffs)
		while k do
			local nextK = next(buffs, k)
			buffs[k] = nil
			k = nextK
		end
		
		-- OPTIMIZACIÓN: Limpiar tablas usando índice inverso directamente
		if self.HeroesSaved then
			local heroes = self.Heroes
			for i = #heroes, 1, -1 do
				heroes[i] = nil
			end
			self.HeroesSaved = false
		end
		if self.MinionsSaved then
			local minions = self.Minions
			for i = #minions, 1, -1 do
				minions[i] = nil
			end
			self.MinionsSaved = false
		end
		if self.ExtraHeroesSaved then
			local extraHeroes = self.ExtraHeroes
			for i = #extraHeroes, 1, -1 do
				local u = extraHeroes[i]
				if not (u and u.valid and u.visible and u.isTargetable and not u.dead and not u.isImmortal) then
					extraHeroes[i] = nil
				end
			end
			self.ExtraHeroesSaved = false
		end
		if self.ExtraUnitsSaved then
			local extraUnits = self.ExtraUnits
			for i = #extraUnits, 1, -1 do
				local u = extraUnits[i]
				if u and u.valid and u.visible and u.isTargetable and not u.dead and not u.isImmortal then
					self.ExtraUnitsSaved = true
				else
					extraUnits[i] = nil
				end
			end
			self.ExtraUnitsSaved = false
		end
		if self.TurretsSaved then
			local turrets = self.Turrets
			for i = #turrets, 1, -1 do
				turrets[i] = nil
			end
			self.TurretsSaved = false
		end
		if self.WardsSaved then
			local wards = self.Wards
			for i = #wards, 1, -1 do
				wards[i] = nil
			end
			self.WardsSaved = false
		end
		if self.PlantsSaved then
			local plants = self.Plants
			for i = #plants, 1, -1 do
				plants[i] = nil
			end
			self.PlantsSaved = false
		end
	end,

	Buff = function(self, b)
		local class = {}
		local members = {}
		local metatable = {}
		local _b = b
		function metatable.__index(s, k)
			if members[k] == nil then
				if k == "duration" then
					members[k] = _b.duration
				elseif k == "count" then
					members[k] = _b.count
				elseif k == "stacks" then
					members[k] = _b.stacks
				else
					members[k] = _b[k]
				end
			end
			return members[k]
		end
		setmetatable(class, metatable)
		return class
	end,

	GetHeroes = function(self)
		-- Sistema de caché inteligente basado en modo del orbwalker
		if FPSOptimizer.enabled and FPSOptimizer.smartCacheEnabled then
			local config = FPSOptimizer:GetCacheConfig()
			
			-- Si el modo actual no requiere cachear heroes, retornar solo extra heroes
			if not config.cacheHeroes then
				local result = {}
				for i = 1, #self.ExtraHeroes do
					table_insert(result, self.ExtraHeroes[i])
				end
				return result
			end
			
			-- Usar cache del FPSOptimizer si está disponible y actualizado
			if not FPSOptimizer:ShouldUpdateCache() and #FPSOptimizer.cachedHeroes > 0 then
				local result = {}
				for i = 1, #FPSOptimizer.cachedHeroes do
					local hero = FPSOptimizer.cachedHeroes[i]
					table_insert(result, hero)
				end
				-- Agregar heroes extra cacheados
				for i = 1, #self.ExtraHeroes do
					table_insert(result, self.ExtraHeroes[i])
				end
				return result
			end
		end
		
		-- Fallback al sistema original si el cache no está disponible
		if not self.HeroesSaved then
			self.HeroesSaved = true
			self.ExtraHeroesSaved = true
			local count = GameHeroCount()
			if count and count > 0 and count < 1000 then
				-- Optimización: Procesar en chunks si hay muchos heroes
				local maxProcess = FPSOptimizer.highLoadMode and 3 or count
				local processed = 0
				
				for i = 1, count do
					if processed >= maxProcess then
						break
					end
					
					local o = GameHero(i)
					if o and o.valid and o.visible and o.isTargetable and not o.dead then
						table_insert(self.Heroes, o)
						processed = processed + 1
					end
				end
			end

			for i = 1, #self.ExtraHeroes do
				local e = self.ExtraHeroes[i]
				table_insert(self.Heroes, e)
			end
		end
		return self.Heroes
	end,

	AddCachedHero = function(self, unit)
		local extraHeroes = self.ExtraHeroes
		local unitNetID = unit.networkID
		for i = 1, #extraHeroes do
			if extraHeroes[i].networkID == unitNetID then
				return false
			end
		end
		table_insert(extraHeroes, unit)
	end,

	AddCachedMinion = function(self, unit)
		local unitNetID = unit.networkID
		local extraUnits = self.ExtraUnits
		for i = 1, #extraUnits do
			if extraUnits[i].networkID == unitNetID then
				return false
			end
		end
		local minions = self.Minions
		for i = 1, #minions do
			if minions[i].networkID == unitNetID then
				return false
			end
		end
		table_insert(extraUnits, unit)
	end,

	GetMinions = function(self)
		-- Sistema de caché inteligente basado en modo del orbwalker
		if FPSOptimizer.enabled and FPSOptimizer.smartCacheEnabled then
			local config = FPSOptimizer:GetCacheConfig()
			
			-- Si el modo actual no requiere cachear minions, retornar solo extra units
			-- PERO siempre incluir minions enemigos para detección de colisiones de hechizos
			if not config.cacheMinions then
				local result = {}
				-- Asegurar que incluimos minions enemigos para detección de colisiones
				-- Esto es crítico para que GGPrediction funcione correctamente
				local count = GameMinionCount()
				if count and count > 0 then
					for i = 1, count do
						local o = GameMinion(i)
						if o and o.valid and o.visible and o.isTargetable and not o.dead and o.isEnemy then
							if not o.isImmortal or o.charName:lower() == "sru_atakhan" then
								table_insert(result, o)
							end
						end
					end
				end
				-- Agregar unidades extra
				for i = 1, #self.ExtraUnits do
					table_insert(result, self.ExtraUnits[i])
				end
				return result
			end
			
			-- Usar cache del FPSOptimizer si está disponible y actualizado
			if not FPSOptimizer:ShouldUpdateCache() and #FPSOptimizer.cachedMinions > 0 then
				local result = {}
				for i = 1, #FPSOptimizer.cachedMinions do
					table_insert(result, FPSOptimizer.cachedMinions[i])
				end
				-- Agregar unidades extra
				for i = 1, #self.ExtraUnits do
					table_insert(result, self.ExtraUnits[i])
				end
				return result
			end
		end
		
		-- Fallback al sistema original
		if not self.MinionsSaved then
			self.MinionsSaved = true
			self.ExtraUnitsSaved = true
			local cachedMinions = self:FetchCachedMinions()
			local count = #cachedMinions
			if count and count > 0 and count < 1000 then
				-- Optimización: Procesar en chunks si hay muchos minions
				-- PERO nunca limitar minions enemigos para detección de colisiones
				local maxProcess = FPSOptimizer.highLoadMode and 10 or count
				local processed = 0
				local enemyMinionCount = 0
				
				for i = 1, count do
					local o = cachedMinions[i]
					if o and o.valid and o.visible and o.isTargetable and not o.dead then
						if not o.isImmortal or o.charName:lower() == "sru_atakhan" then
							-- Siempre incluir minions enemigos (necesarios para detección de colisiones)
							if o.isEnemy then
								table_insert(self.Minions, o)
								enemyMinionCount = enemyMinionCount + 1
							elseif processed < maxProcess then
								-- Limitar solo minions aliados si es necesario
								table_insert(self.Minions, o)
								processed = processed + 1
							end
						end
					end
				end
			end

			for i = 1, #self.ExtraUnits do
				local e = self.ExtraUnits[i]
				table_insert(self.Minions, e)
			end
		end
		return self.Minions
	end,

	FetchCachedMinions = function (self)
		if self.TempCacheBuffer.m <= GameTimer() then
			self.TempCachedMinions = {}
			local count = GameMinionCount()
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = GameMinion(i)
					if o and o.valid and o.visible and o.isTargetable and not o.dead then
						if not o.isImmortal or o.charName:lower() == "sru_atakhan" then
							table_insert(self.TempCachedMinions, o)
						end
					end
				end
			end
			self.TempCacheBuffer.m = self.TempCacheBuffer.m + self.TempCacheTimeout
			return self.TempCachedMinions
		end

		return self.TempCachedMinions
	end,

	GetTurrets = function(self)
		if not self.TurretsSaved then
			self.TurretsSaved = true
			local cachedTurrets = self:FetchCachedTurrets()
			local count = #cachedTurrets
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = cachedTurrets[i]
					if o and o.valid and o.visible and o.isTargetable and not o.dead and not o.isImmortal then
						table_insert(self.Turrets, o)
					end
				end
			end
		end
		return self.Turrets
	end,

	FetchCachedTurrets = function (self)
		if self.TempCacheBuffer.t < GameTimer() then
			self.TempCachedTurrets = {}
			local count = GameTurretCount()
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = GameTurret(i)
					if o and o.valid and o.visible and o.isTargetable and not o.dead and not o.isImmortal then
						table_insert(self.TempCachedTurrets, o)
					end
				end
			end
			self.TempCacheBuffer.t = self.TempCacheBuffer.t + self.TempCacheTimeout
			return self.TempCachedTurrets
		end

		return self.TempCachedTurrets
	end,

	GetWards = function(self)
		if not self.WardsSaved then
			self.WardsSaved = true
			local cachedWards = self:FetchCachedWards()
			local count = #cachedWards
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = cachedWards[i]
					if o and o.valid and o.visible and o.isTargetable and not o.dead and not o.isImmortal then
						table_insert(self.Wards, o)
					end
				end
			end
		end
		return self.Wards
	end,

	FetchCachedWards = function (self)
		if self.TempCacheBuffer.w < GameTimer() then
			self.TempCachedWards = {}
			local count = GameWardCount()
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = GameWard(i)
					if o and o.valid and o.visible and o.isTargetable and not o.dead and not o.isImmortal then
						table_insert(self.TempCachedWards, o)
					end
				end
			end
			self.TempCacheBuffer.w = self.TempCacheBuffer.w + self.TempCacheTimeout
			return self.TempCachedWards
		end

		return self.TempCachedWards
	end,
	
	GetPlants = function(self)
		if not self.PlantsSaved then
			self.PlantsSaved = true
			local cachedPlants = self:FetchCachedPlants()
			local count = #cachedPlants
			if count and count > 0 and count < 1000 then
				for i = 1, count do
					local o = cachedPlants[i]
					if o and o.valid and o.visible and o.isTargetable and not o.dead and not o.isImmortal then
						table_insert(self.Plants, o)
					end
				end
			end
		end
		return self.Plants
	end,

	FetchCachedPlants = function(self)
		if self.TempCacheBuffer.p <= GameTimer() then
			self.TempCachedPlants = {}
			local count = GameObjectCount()
			if count and count > 0 and count < 100000 then
				for i = 1, count do
					local o = GameObject(i)
					if o and o.type == Obj_AI_Minion and o.isEnemy and o.valid and o.visible and o.isTargetable and not o.dead and not o.isImmortal then
						local charName = o.charName:lower()
						if self.OtherMinions[charName] then
							table_insert(self.TempCachedPlants, o)
						end
					end
				end
			end
			self.TempCacheBuffer.p = self.TempCacheBuffer.p + self.TempCacheTimeout
			return self.TempCachedPlants
		end

		return self.TempCachedPlants
	end,

	GetBuffs = function(self, o)
		if o == nil then
			return {}
		end
		local id = o.networkID
		if self.Buffs[id] == nil then
			local count = o.buffCount
			if count and count >= 0 and count < 10000 then
				local b, b2 = nil, nil
				local buffs = {}
				for i = 0, count do
					b = o:GetBuff(i)
					if b then
						b2 = self:Buff(b)
						if b2.count > 0 then
							table_insert(buffs, b2)
						end
					end
				end
				self.Buffs[id] = buffs
			end
		end
		return self.Buffs[id] or {}
	end,
}
-- stylua: ignore start
Menu = {

    Main = nil,
    Target = nil,
    Orbwalker = nil,

    CreateMain = function(self)
        self.Main = MenuElement({id = "DepressiveOrbwalker", name = "Depressive - Orbwalker", type = MENU})
    end,

    CreateTarget = function(self)
        self.Target = self.Main:MenuElement({id = 'Target', name = 'Target Selector', type = MENU})
        self.Target:MenuElement({id = 'Priorities', name = 'Priorities', type = MENU})
        self.Target:MenuElement({id = 'SelectedTarget', name = 'Selected Target', value = true})
        self.Target:MenuElement({id = 'OnlySelectedTarget', name = 'Only Selected Target', value = false})
	self.Target:MenuElement({id = 'SortMode' .. myHero.charName, name = 'Sort Mode', value = SORT_SMART, drop = {'Auto', 'Closest', 'Near Mouse', 'Lowest HP', 'Lowest MaxHP', 'Highest Priority', 'Most Stack', 'Most AD', 'Most AP', 'Less Cast', 'Less Attack', 'Smart AI'}})
		self.Target:MenuElement({id = 'mindistance', name = 'mindistance', value = 400, min = 100, max = 600, step=25 })
		self.Target:MenuElement({id = 'maxdistance', name = 'maxdistance', value = 800, min = 100, max = 1500, step=25 })
		self.Target:MenuElement({id = 'distmultiplier', name = 'distance multiplier', value = 0.5, min = 0, max = 1, step=0.01 })
		-- Smart Target Selector options
		self.Target:MenuElement({id = 'SmartAI', name = 'Smart AI', type = MENU})
		self.Target.SmartAI:MenuElement({id = 'UseDamageCalc', name = 'Use Damage Calculation to detect killable targets', value = false})
		self.Target.SmartAI:MenuElement({id = 'MinHpPercent', name = 'Low HP percent (fallback)', value = 25, min = 0, max = 100, step = 1})
		self.Target.SmartAI:MenuElement({id = 'RangeOffset', name = 'Range Offset (px)', value = 50, min = 0, max = 500, step = 5})
	end,

    CreateOrbwalker = function(self)
        self.Orbwalker = self.Main:MenuElement({id = 'Orbwalker', name = 'Orbwalker', type = MENU})
        self.Orbwalker:MenuElement({id = 'Enabled', name = 'Enabled', value = true})
        self.Orbwalker:MenuElement({id = 'MovementEnabled', name = 'Movement Enabled', value = true})
        self.Orbwalker:MenuElement({id = 'AttackEnabled', name = 'Attack Enabled', value = true})
        self.Orbwalker:MenuElement({id = 'Keys', name = 'Keys', type = MENU})
        self.Orbwalker.Keys:MenuElement({id = 'Combo', name = 'Combo Key', key = string.byte(' ')})
        self.Orbwalker.Keys:MenuElement({id = 'Harass', name = 'Harass Key', key = string.byte('C')})
        self.Orbwalker.Keys:MenuElement({id = 'LastHit', name = 'LastHit Key', key = string.byte('X')})
        self.Orbwalker.Keys:MenuElement({id = 'LaneClear', name = 'LaneClear Key', key = string.byte('V')})
        self.Orbwalker.Keys:MenuElement({id = 'Jungle', name = 'Jungle Key', key = string.byte('V')})
        self.Orbwalker.Keys:MenuElement({id = 'Flee', name = 'Flee Key', key = string.byte('A')})
        self.Orbwalker.Keys:MenuElement({id = 'Spacing', name = 'Auto Spacing Key', key = string.byte('Z'), tooltip = 'Maintains optimal distance: enemy in your range, you out of enemy range'})
        self.Orbwalker.Keys:MenuElement({id = 'HoldKey', name = 'Hold Key', key = string.byte('H'), tooltip = 'Should be same in game keybinds'})
        self.Orbwalker:MenuElement({id = 'General', name = 'General', type = MENU})
        self.Orbwalker.General:MenuElement({id = 'AttackBarrel', name = 'Attack Gangplank Barrel', value = true})
        self.Orbwalker.General:MenuElement({id = 'AttackPlants', name = 'Attack Plants(LaneClear Mode)', value = false})
        self.Orbwalker.General:MenuElement({id = 'HarassFarm', name = 'Farm In Harass Mode', value = true})
        self.Orbwalker.General:MenuElement({id = 'AttackResetting', name = 'Attack Resetting', value = true})
        self.Orbwalker.General:MenuElement({id = 'FastKiting', name = 'Fast Kiting', value = true})
        self.Orbwalker.General:MenuElement({id = 'LaneClearHeroes', name = 'LaneClear Heroes', value = true})
        self.Orbwalker.General:MenuElement({id = 'AttackRange', name = 'AARange = RealRange - X', value = 35, min = 0, max = 35, step = 1})
        self.Orbwalker.General:MenuElement({id = 'HoldRadius', name = 'Hold Radius', value = 0, min = 0, max = 250, step = 10})
        self.Orbwalker.General:MenuElement({id = 'ExtraWindUpTime', name = 'Extra WindUpTime', value = 0, min = -25, max = 75, step = 5})
	-- Attack Cancel (post-AA spell cast) options
	self.Orbwalker.General:MenuElement({id = 'CancelQ', name = 'Cancel: Cast Q after AA', value = false})
	self.Orbwalker.General:MenuElement({id = 'CancelW', name = 'Cancel: Cast W after AA', value = false})
	self.Orbwalker.General:MenuElement({id = 'CancelE', name = 'Cancel: Cast E after AA', value = false})
	self.Orbwalker.General:MenuElement({id = 'CancelR', name = 'Cancel: Cast R after AA', value = false})
        self.Orbwalker:MenuElement({id = 'Farming', name = 'Farming Settings', type = MENU})
        self.Orbwalker.Farming:MenuElement({id = 'LastHitPriority', name = 'Priorize Last Hit over Harass', value = true})
        self.Orbwalker.Farming:MenuElement({id = 'PushPriority', name = 'Priorize Push over Freeze', value = true})
        self.Orbwalker.Farming:MenuElement({id = 'ExtraFarmDelay', name = 'ExtraFarmDelay', value = 0, min = -80, max = 80, step = 10})
    end,

    CreateDrawings = function(self)
        self.Main:MenuElement({id = 'Drawings', name = 'Drawings', type = MENU})
        self.Main.Drawings:MenuElement({id = 'Enabled', name = 'Enabled', value = true})
        self.Main.Drawings:MenuElement({id = 'Cursor', name = 'Cursor', value = true})
        self.Main.Drawings:MenuElement({id = 'Range', name = 'AutoAttack Range', value = true})
        self.Main.Drawings:MenuElement({id = 'EnemyRange', name = 'Enemy AutoAttack Range', value = true})
        self.Main.Drawings:MenuElement({id = 'HoldRadius', name = 'Hold Radius', value = false})
        self.Main.Drawings:MenuElement({id = 'LastHittableMinions', name = 'Last Hittable Minions', value = true})
        self.Main.Drawings:MenuElement({id = 'SelectedTarget', name = 'Selected Target', value = true})
        self.Main.Drawings:MenuElement({id = 'SmartCacheInfo', name = 'Smart Cache Info (Debug)', value = false})
    end,

    CreateGeneral = function(self)
        self.Main:MenuElement({name = '', type = SPACE, id = 'GeneralSpace'})
        self.Main:MenuElement({id = 'AttackTKey', name = 'Attack Target Key', key = string.byte('U'), tooltip = 'You should bind this one in ingame settings'})
        self.Main:MenuElement({id = 'Latency', name = 'Ping [ms]', value = 50, min = 0, max = 120, step = 1, callback = function(value) _G.LATENCY = value end})
        self.Main:MenuElement({id = 'SetCursorMultipleTimes', name = 'Set Cursor Position Multiple Times', value = false})
        self.Main:MenuElement({id = 'CursorDelay', name = 'Cursor Delay', value = 5, min = 1, max = 50, step = 1})
		self.Main:MenuElement({id = 'Humanizer', name = 'min dist b/t move commands', value = 120, min = 0, max = 300, step = 5})
	self.Main:MenuElement({name = '', type = SPACE, id = 'SmoothSpace'})
        self.Main:MenuElement({id = 'SmoothMouse', name = 'Smooth Mouse Movement', value = true})
        self.Main:MenuElement({id = 'SmoothSpeed', name = 'Smooth Speed (pixels/ms)', value = 80, min = 1.0, max = 100.0, step = 1.0})
        self.Main:MenuElement({id = 'SmoothAcceleration', name = 'Mouse Acceleration', value = 5, min = 1.0, max = 5.0, step = 0.1})
        self.Main:MenuElement({id = 'SmoothRandomness', name = 'Movement Randomness', value = 5, min = 0, max = 20, step = 1})
        self.Main:MenuElement({name = '', type = SPACE, id = 'FPSOptimizationSpace'})
        self.Main:MenuElement({id = 'FPSOptimization', name = '[FPS] Optimization System', type = MENU})
        self.Main.FPSOptimization:MenuElement({id = 'Enabled', name = 'Enable FPS Optimization', value = true, callback = function(value) FPSOptimizer.enabled = value end})
	self.Main.FPSOptimization:MenuElement({id = 'TargetFPS', name = 'Target FPS', value = 60, min = 30, max = 200, step = 10, callback = function(value) FPSOptimizer.targetFPS = value end})
        self.Main.FPSOptimization:MenuElement({id = 'SmartCache', name = 'Smart Object Caching', value = true, callback = function(value) FPSOptimizer.smartCacheEnabled = value end})
        self.Main.FPSOptimization:MenuElement({id = 'ChunkProcessing', name = 'Chunk Processing (High Load)', value = true})
        self.Main.FPSOptimization:MenuElement({name = '', type = SPACE, id = 'SmartCacheSpace'})
        self.Main.FPSOptimization:MenuElement({id = 'SmartCacheConfig', name = 'Smart Cache Configuration', type = MENU})
        self.Main.FPSOptimization.SmartCacheConfig:MenuElement({id = 'ComboCacheHeroes', name = 'Cache Heroes in Combo', value = true, callback = function(value) FPSOptimizer.cacheConfig[ORBWALKER_MODE_COMBO].cacheHeroes = value end})
        self.Main.FPSOptimization.SmartCacheConfig:MenuElement({id = 'ComboCacheMinions', name = 'Cache Minions in Combo', value = false, callback = function(value) FPSOptimizer.cacheConfig[ORBWALKER_MODE_COMBO].cacheMinions = value end})
        self.Main.FPSOptimization.SmartCacheConfig:MenuElement({id = 'HarassCacheHeroes', name = 'Cache Heroes in Harass', value = true, callback = function(value) FPSOptimizer.cacheConfig[ORBWALKER_MODE_HARASS].cacheHeroes = value end})
        self.Main.FPSOptimization.SmartCacheConfig:MenuElement({id = 'HarassCacheMinions', name = 'Cache Minions in Harass', value = true, callback = function(value) FPSOptimizer.cacheConfig[ORBWALKER_MODE_HARASS].cacheMinions = value end})
        self.Main.FPSOptimization.SmartCacheConfig:MenuElement({id = 'LaneClearCacheHeroes', name = 'Cache Heroes in LaneClear', value = false, callback = function(value) FPSOptimizer.cacheConfig[ORBWALKER_MODE_LANECLEAR].cacheHeroes = value end})
        self.Main.FPSOptimization.SmartCacheConfig:MenuElement({id = 'LaneClearCacheMinions', name = 'Cache Minions in LaneClear', value = true, callback = function(value) FPSOptimizer.cacheConfig[ORBWALKER_MODE_LANECLEAR].cacheMinions = value end})
        self.Main.FPSOptimization.SmartCacheConfig:MenuElement({id = 'LastHitCacheHeroes', name = 'Cache Heroes in LastHit', value = false, callback = function(value) FPSOptimizer.cacheConfig[ORBWALKER_MODE_LASTHIT].cacheHeroes = value end})
	self.Main.FPSOptimization.SmartCacheConfig:MenuElement({id = 'LastHitCacheMinions', name = 'Cache Minions in LastHit', value = true, callback = function(value) FPSOptimizer.cacheConfig[ORBWALKER_MODE_LASTHIT].cacheMinions = value end})
    end,
}
-- stylua: ignore end

Menu:CreateMain()
Menu:CreateTarget()
Menu:CreateOrbwalker()
Menu:CreateDrawings()
Menu:CreateGeneral()

-- Inicializar configuraciones del sistema de caché inteligente
if Menu.Main.FPSOptimization and Menu.Main.FPSOptimization.SmartCacheConfig then
    -- Sincronizar valores del menú con la configuración del FPSOptimizer
    Menu.Main.FPSOptimization.SmartCacheConfig.ComboCacheHeroes:Value(FPSOptimizer.cacheConfig[ORBWALKER_MODE_COMBO].cacheHeroes)
    Menu.Main.FPSOptimization.SmartCacheConfig.ComboCacheMinions:Value(FPSOptimizer.cacheConfig[ORBWALKER_MODE_COMBO].cacheMinions)
    Menu.Main.FPSOptimization.SmartCacheConfig.HarassCacheHeroes:Value(FPSOptimizer.cacheConfig[ORBWALKER_MODE_HARASS].cacheHeroes)
    Menu.Main.FPSOptimization.SmartCacheConfig.HarassCacheMinions:Value(FPSOptimizer.cacheConfig[ORBWALKER_MODE_HARASS].cacheMinions)
    Menu.Main.FPSOptimization.SmartCacheConfig.LaneClearCacheHeroes:Value(FPSOptimizer.cacheConfig[ORBWALKER_MODE_LANECLEAR].cacheHeroes)
    Menu.Main.FPSOptimization.SmartCacheConfig.LaneClearCacheMinions:Value(FPSOptimizer.cacheConfig[ORBWALKER_MODE_LANECLEAR].cacheMinions)
    Menu.Main.FPSOptimization.SmartCacheConfig.LastHitCacheHeroes:Value(FPSOptimizer.cacheConfig[ORBWALKER_MODE_LASTHIT].cacheHeroes)
    Menu.Main.FPSOptimization.SmartCacheConfig.LastHitCacheMinions:Value(FPSOptimizer.cacheConfig[ORBWALKER_MODE_LASTHIT].cacheMinions)
end

_G.LATENCY = Game.Latency() < 250 and Game.Latency() or Menu.Main.Latency:Value()

Color = {
	LightGreen = Draw.Color(255, 144, 238, 144),
	OrangeRed = Draw.Color(255, 255, 69, 0),
	Black = Draw.Color(255, 0, 0, 0),
	Red = Draw.Color(255, 255, 0, 0),
	Yellow = Draw.Color(255, 255, 255, 0),
	DarkRed = Draw.Color(255, 204, 0, 0),
	AlmostLastHitable = Draw.Color(255, 239, 159, 55),
	LastHitable = Draw.Color(255, 255, 255, 255),
	Range = Draw.Color(150, 49, 210, 0),
	EnemyRange = Draw.Color(150, 255, 0, 0),
	Cursor = Draw.Color(255, 0, 255, 0),
	drawcolor1 = Draw.Color(150, 255, 255, 255),
	drawcolor2 = Draw.Color(150, 239, 159, 55),
}

--#region FPS Optimization Utilities
-- Throttle expensive draw operations
local DrawThrottle = {
	lastDrawTime = {},
	throttleDelay = 16, -- 1000ms / 60fps
	
	CanDraw = function(self, key)
		local now = GetTickCount()
		if self.lastDrawTime[key] == nil or (now - self.lastDrawTime[key]) >= self.throttleDelay then
			self.lastDrawTime[key] = now
			return true
		end
		return false
	end,
}

--#endregion

Action = {

	Tasks = {},

	OnTick = function(self)
		local tasks = self.Tasks
		local currentTime = os.clock()
		for i = #tasks, 1, -1 do
			local task = tasks[i]
			if currentTime >= task[2] then
				if task[1]() or currentTime >= task[3] then
					table_remove(tasks, i)
				end
			end
		end
	end,

	Add = function(self, task, startTime, endTime)
		startTime = startTime or 0
		endTime = endTime or 10000
		table_insert(self.Tasks, { task, os.clock() + startTime, os.clock() + startTime + endTime })
	end,
}

Buff = {

	GetBuffDuration = function(self, unit, name)
		name = name:lower()
		local result = 0
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if buff.name:lower() == name then
				local duration = buff.duration
				if duration > result then
					result = duration
				end
			end
		end
		return result
	end,

	GetBuffs = function(self, unit)
		return Cached:GetBuffs(unit)
	end,

	GetBuff = function(self, unit, name)
		name = name:lower()
		local result = nil
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if buff.name:lower() == name then
				result = buff
				break
			end
		end
		return result
	end,

	HasBuffContainsName = function(self, unit, name)
		name = name:lower()
		local buffs = Cached:GetBuffs(unit)
		local result = false
		for i = 1, #buffs do
			if buffs[i].name:lower():find(name) then
				result = true
				break
			end
		end
		return result
	end,

	GetBuffExpire = function(self, unit, name)
		name = name:lower()
		local result = 0
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if buff.name:lower() == name then
				local expireTime = buff.expireTime
				if expireTime > result then
					result = expireTime
				end
			end
		end
		return result
	end,

	HasBuffContainsNameCount = function(self, unit, name)
		name = name:lower()
		local buffs = Cached:GetBuffs(unit)
		local result = 0
		for i = 1, #buffs do
			if buffs[i].name:lower():find(name) then
				result = result + 1
			end
		end
		return result
	end,

	ContainsBuffs = function(self, unit, arr)
		local buffs = Cached:GetBuffs(unit)
		local result = false
		for i = 1, #buffs do
			if arr[buffs[i].name:lower()] then
				result = true
				break
			end
		end
		return result
	end,

	HasBuff = function(self, unit, name)
		if name == nil then
			print("HasBuff: name is nil")
			return "ayaya"
		end
		name = name:lower()
		local buffs = Cached:GetBuffs(unit)
		local result = false
		for i = 1, #buffs do
			if buffs[i].name:lower() == name then
				result = true
				break
			end
		end
		return result
	end,

	HasBuffTypes = function(self, unit, arr)
		local buffs = Cached:GetBuffs(unit)
		local result = false
		for i = 1, #buffs do
			if arr[buffs[i].type] then
				result = true
				break
			end
		end
		return result
	end,

	GetBuffCount = function(self, unit, name)
		name = name:lower()
		local result = 0
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if buff.name:lower() == name then
				local count = buff.count
				if count > result then
					result = count
				end
			end
		end
		return result
	end,

	GetBuffStacks = function(self, unit, name)
		name = name:lower()
		local result = 0
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if buff.name:lower() == name then
				local count = buff.stacks
				if count > result then
					result = count
				end
			end
		end
		return result
	end,
	
	GetBuffStartTime = function(self, unit, name)
		name = name:lower()
		local result = 0
		local buff = nil
		local buffs = Cached:GetBuffs(unit)
		for i = 1, #buffs do
			buff = buffs[i]
			if buff.name:lower() == name then
				local time = buff.startTime
				if time > result then
					result = time
				end
			end
		end
		return result
	end,

	Print = function(self, target)
		local result = ""
		local buffs = self:GetBuffs(target)
		for i = 1, #buffs do
			local buff = buffs[i]
			result = result .. buff.name .. ": count=" .. buff.count .. " duration=" .. tostring(buff.duration) .. "\n"
		end
		local pos2D = target.pos:To2D()
		local posX = pos2D.x - 50
		local posY = pos2D.y
		Draw.Text(result, 22, posX + 50, posY - 15)
	end,
}

Damage = {

	BaseTurrets = {
		["SRUAP_Turret_Order3"] = true,
		["SRUAP_Turret_Order4"] = true,
		["SRUAP_Turret_Chaos3"] = true,
		["SRUAP_Turret_Chaos4"] = true,
	},

	TurretToMinionPercent = {
		["SRU_ChaosMinionMelee"] = 0.43,
		["SRU_ChaosMinionRanged"] = 0.68,
		["SRU_ChaosMinionSiege"] = 0.14,
		["SRU_ChaosMinionSuper"] = 0.05,
		["SRU_OrderMinionMelee"] = 0.43,
		["SRU_OrderMinionRanged"] = 0.68,
		["SRU_OrderMinionSiege"] = 0.14,
		["SRU_OrderMinionSuper"] = 0.05,
		["HA_ChaosMinionMelee"] = 0.43,
		["HA_ChaosMinionRanged"] = 0.68,
		["HA_ChaosMinionSiege"] = 0.14,
		["HA_ChaosMinionSuper"] = 0.05,
		["HA_OrderMinionMelee"] = 0.43,
		["HA_OrderMinionRanged"] = 0.68,
		["HA_OrderMinionSiege"] = 0.14,
		["HA_OrderMinionSuper"] = 0.05,
	},

	HeroStaticDamage = {
		["Yunara"] = function(args)
			local level = args.From:GetSpellData(_Q).level
			if level > 0 then
				args.RawMagical = args.RawMagical +  5 * level + 0.2 * args.From.ap
			end
		end,
		["Ashe"] = function(args)
			local level = args.From:GetSpellData(_Q).level
			if Buff:HasBuff(args.From, "asheqattack") then
				args.RawTotal = args.RawTotal * (1.025 + 0.075 * level)
			end
		end,
		["Jayce"] = function(args)
			local level = args.From.levelData.lvl
			local t = level < 6 and 25 or (level < 11 and 65 or level < 16 and 105 or 145)
			if Buff:HasBuff(args.From, "jaycepassivemeleeattack") then
				args.RawMagical = args.RawMagical + t + 0.25 * args.From.bonusDamage
			end
		end,
		["Neeko"] = function(args)
			if Buff:HasBuff(args.From, "neekowpassiveready") then
				local level = args.From:GetSpellData(_W).level
				if level > 0 then
					args.RawMagical = args.RawMagical + (35 * level - 5) + 0.6 * args.From.ap
				end	
			end
		end,
		["Ziggs"] = function(args)
			local t = { 20, 24, 28, 32, 36, 40, 48, 56, 64, 72, 80, 88, 100, 112, 124, 136, 148, 160 }
			if Buff:HasBuff(args.From, "ziggsshortfuse") then
				args.RawMagical = args.RawMagical + t[math_max(math_min(args.From.levelData.lvl, 18), 1)] + 0.5 * args.From.ap
			end
		end,
		["Zeri"] = function(args)
			args.RawTotal = args.RawTotal * 0
			args.RawPhysical = args.RawTotal
			local level = args.From.levelData.lvl
			if Buff:HasBuff(myHero, "zeriqpassiveready") then
				args.RawMagical = 70 + 5 * level + args.From.ap * 1.1
			else
				args.RawMagical = 10 + (15 / 17) * (level - 1) * (0.7025 + 0.0175 * (level-1)) + args.From.ap * 0.03
			end
		end,
		["Caitlyn"] = function(args)
			if Buff:HasBuff(args.From, "caitlynpassivedriver") then
				local modCrit = 1.4875 + (Item:HasItem(args.From, 3031) and 0.34 or 0)
				local level = args.From.levelData.lvl
				local t = level < 7 and 1.1 or (level < 13 and 1.15 or 1.2)
				if args.TargetIsMinion then
					args.RawPhysical = args.RawPhysical
						+ (t + (modCrit * args.From.critChance)) * args.From.totalDamage
				else
					t = level < 7 and 0.6 or (level < 13 and 0.9 or 1.2)
					args.RawPhysical = args.RawPhysical
						+ (t + (modCrit * args.From.critChance)) * args.From.totalDamage
				end
			end
		end,
		["Corki"] = function(args)
			args.CalculatedTrue = args.CalculatedTrue + 0.15 * args.From.totalDamage
		end,
		["Diana"] = function(args)
			if Buff:GetBuffCount(args.From, "dianapassivemarker") == 2 then
				local level = args.From.levelData.lvl
				args.RawMagical = args.RawMagical
					+ math_max(15 + 5 * level, -10 + 10 * level, -60 + 15 * level, -125 + 20 * level, -200 + 25 * level)
					+ 0.8 * args.From.ap
			end
		end,
		["Draven"] = function(args)
			if Buff:HasBuff(args.From, "DravenSpinningAttack") then
				local level = args.From:GetSpellData(_Q).level
				args.RawPhysical = args.RawPhysical + 25 + 5 * level + (0.55 + 0.1 * level) * args.From.bonusDamage
			end
		end,
		["Fizz"] = function(args)
			if Buff:HasBuff(args.From, "fizzw") then
				args.RawMagical = args.RawMagical+ (30 + 20 * args.From:GetSpellData(_W).level) +0.5 * args.From.ap
			end
		end,
		["Hwei"] = function(args)
			if Buff:HasBuff(args.From, "HweiWEBuffCounter") then
				local amnt = 0
				if(args.From:GetSpellData(_Q).name == "HweiQ") then
					amnt = ({20, 30, 40, 50, 60})[args.From:GetSpellData(_W).level] + (args.From.ap * 0.15)
				else
					amnt = 20 + (args.From.ap * 0.15)
				end
				args.RawMagical = args.RawMagical + amnt
			end
		end,
		["Kassadin"] = function(args)
			if Game.CanUseSpell(1)==8 then
				args.RawMagical = args.RawMagical+ (25 + 25 * args.From:GetSpellData(_W).level) +0.8 * args.From.ap
			end
		end,
		["Graves"] = function(args)
			local t = { 70, 71, 72, 74, 75, 76, 78, 80, 81, 83, 85, 87, 89, 91, 95, 96, 97, 100 }
			args.RawTotal = args.RawTotal * t[math_max(math_min(args.From.levelData.lvl, 18), 1)] * 0.01
		end,
		["Jinx"] = function(args)
			if Buff:HasBuff(args.From, "JinxQ") then
				args.RawPhysical = args.RawPhysical + args.From.totalDamage * 0.1
			end
		end,
		["Kayle"] = function(args)
			local level = args.From:GetSpellData(_E).level
			if level > 0 then
				if Buff:HasBuff(args.From, "JudicatorRighteousFury") then
					args.RawMagical = args.RawMagical + 10 + 10 * level + 0.3 * args.From.ap
				else
					args.RawMagical = args.RawMagical + 5 + 5 * level + 0.15 * args.From.ap
				end
			end
		end,
		["Nasus"] = function(args)
			if Buff:HasBuff(args.From, "NasusQ") then
				args.RawPhysical = args.RawPhysical
					+ math_max(Buff:GetBuffStacks(args.From, "NasusQStacks"), 0)
					+ 10
					+ 20 * args.From:GetSpellData(_Q).level
			end
		end,
		["Thresh"] = function(args)
			local level = args.From:GetSpellData(_E).level
			if level > 0 then
				local damage = math_max(Buff:GetBuffCount(args.From, "threshpassivesouls"), 0)
					+ (0.5 + 0.3 * level) * args.From.totalDamage
				if Buff:HasBuff(args.From, "threshqpassive4") then
					damage = damage * 1
				elseif Buff:HasBuff(args.From, "threshqpassive3") then
					damage = damage * 0.5
				elseif Buff:HasBuff(args.From, "threshqpassive2") then
					damage = damage * 1 / 3
				else
					damage = damage * 0.25
				end
				args.RawMagical = args.RawMagical + damage
			end
		end,
		["TwistedFate"] = function(args)
			if Buff:HasBuff(args.From, "cardmasterstackparticle") then
				args.RawMagical = args.RawMagical + 40 + 25 * args.From:GetSpellData(_E).level + 0.75 * args.From.bonusDamage + 0.5 * args.From.ap
			end
			if Buff:HasBuff(args.From, "BlueCardPreAttack") then
				args.DamageType = DAMAGE_TYPE_MAGICAL
				args.RawMagical = args.RawMagical + (20 + 20 * args.From:GetSpellData(_W).level + args.From.totalDamage + 1.15 * args.From.ap) * (1 + 0.575 * args.From.critChance)
			elseif Buff:HasBuff(args.From, "RedCardPreAttack") then
				args.DamageType = DAMAGE_TYPE_MAGICAL
				args.RawMagical = args.RawMagical + (15 + 15 * args.From:GetSpellData(_W).level + args.From.totalDamage + 0.7 * args.From.ap) * (1 + 0.35 * args.From.critChance)
			elseif Buff:HasBuff(args.From, "GoldCardPreAttack") then
				args.DamageType = DAMAGE_TYPE_MAGICAL
				args.RawMagical = args.RawMagical + (7.5 + 7.5 * args.From:GetSpellData(_W).level + args.From.totalDamage + 0.5 * args.From.ap) * (1 + 0.25 * args.From.critChance)
			end
		end,
		["Varus"] = function(args)
			local level = args.From:GetSpellData(_W).level
			if level > 0 then
				args.RawMagical = args.RawMagical + 6 * level + 0.35 * args.From.ap
			end
		end,
		["Viktor"] = function(args)
			if Buff:HasBuff(args.From, "ViktorQReturn") then
				args.DamageType = DAMAGE_TYPE_MAGICAL
				args.RawMagical = args.RawMagical + (25 * args.From:GetSpellData(_Q).level - 5) + 0.6 * args.From.ap
			end
		end,
		["Vayne"] = function(args)
			if Buff:HasBuff(args.From, "vaynetumblebonus") then
				args.RawPhysical = args.RawPhysical
					+ (0.65 + 0.1 * args.From:GetSpellData(_Q).level) * args.From.totalDamage + 0.5 * args.From.ap
			end
		end,
	},

	ItemStaticDamage = {
		[1043] = function(args)
			args.RawPhysical = args.RawPhysical + 15
		end,
		[3144] = function(args)
			if not args.TargetIsMinion then
				args.RawMagical = args.RawMagical + 40
			end
		end,
		-- [3085] = function(args)
			-- args.RawMagical = args.RawMagical + 30
		-- end,
		[3091] = function(args)
			-- local t = { 15, 15, 15, 15, 15, 15, 15, 15, 25, 35, 45, 55, 65, 75, 76.25, 77.5, 78.75, 80 }
			-- args.RawMagical = args.RawMagical + t[math_max(math_min(args.From.levelData.lvl, 18), 1)]
			args.RawMagical = args.RawMagical + 45
		end,
		[3115] = function(args)
			args.RawMagical = args.RawMagical + 15 + 0.15 * args.From.ap
		end,
		[3124] = function(args)
			args.RawMagical = args.RawMagical + 30
		end,
		[3302] = function(args)
			args.RawMagical = args.RawMagical + 30
		end,
		-- [6670] = function(args)
			-- if args.TargetIsMinion then
				-- args.RawPhysical = args.RawPhysical + 20
			-- end
		-- end,
		-- [2015] = function(args)
			-- if Buff:GetBuffStacks(args.From, "itemstatikshankcharge") == 100 then
				-- args.RawMagical = args.RawMagical + 60
			-- end
		-- end,
		-- [3087] = function(args)
			-- if Buff:GetBuffStacks(args.From, "itemstatikshankcharge") == 100 then
				-- if args.TargetIsMinion then
					-- args.RawMagical = args.RawMagical + 150
				-- else
					-- args.RawMagical = args.RawMagical + 90
				-- end
			-- end
		-- end,
		[3094] = function(args)
			if Buff:GetBuffStacks(args.From, "itemstatikshankcharge") == 100 then
				args.RawMagical = args.RawMagical + 40
			end
		end,
		-- [3095] = function(args)
			-- if Buff:GetBuffStacks(args.From, "itemstatikshankcharge") == 100 then
				-- args.RawMagical = args.RawMagical + 100
			-- end
		-- end,
		[6699] = function(args)
			if Buff:GetBuffStacks(args.From, "itemstatikshankcharge") == 100 then
				args.RawPhysical = args.RawPhysical + 100
			end
		end,
		[3057] = function(args)
			if Buff:HasBuff(args.From, "sheen") then
				args.RawPhysical = args.RawPhysical + 1.0 * args.From.baseDamage
			end
		end,
		[6662] = function(args)
			if Buff:HasBuff(args.From, "6662buff") then
				args.RawPhysical = args.RawPhysical + 1.0 * args.From.baseDamage
			end
		end,
		[3078] = function(args)
			if Buff:HasBuff(args.From, "3078trinityforce") then
				args.RawPhysical = args.RawPhysical + 2.0 * args.From.baseDamage
			end
		end,
		-- [3508] = function(args)
			-- if Buff:HasBuff(args.From, "3508buff") then
				-- args.RawPhysical = args.RawPhysical + 1.4 * args.From.baseDamage + 0.2 * args.From.bonusDamage
			-- end
		-- end,
		[3100] = function(args)
			if Buff:HasBuff(args.From, "lichbane") then
				args.RawMagical = args.RawMagical + 0.75 * args.From.baseDamage + 0.4 * args.From.ap
			end
		end,
	},

	HeroPassiveDamage = {
		["Ashe"] = function(args)
			if Buff:HasBuff(args.Target, "ashepassiveslow") then
				local modCrit = 0.75 + (Item:HasItem(args.From, 3031) and 0.4 or 0)
				args.RawTotal = args.RawTotal * (1.0 + (modCrit * args.From.critChance))
			end
		end,
		["KogMaw"] = function(args)
			local level = args.From:GetSpellData(_W).level
			if Buff:HasBuff(args.From, "kogmawbioarcanebarrage") then
				args.RawMagical = args.RawMagical + ((2.25 + 0.75 * level) + args.From.ap/100)/100 * args.Target.maxHealth
			end
		end,
		["Zeri"] = function(args)
			local level = args.From.levelData.lvl
			if Buff:HasBuff(myHero, "zeriqpassiveready") then
				args.RawMagical = args.RawMagical
					+ (1 + (10 / 17) * (level - 1)) / 100 * args.Target.maxHealth
			else
				if args.Target.health < 60 + (90 / 17) * (level - 1) + args.From.ap * 0.18 then
					args.RawMagical = 9999 --(Execute targets, < this health)
				end
			end
			if args.Target.team == 300 then
				args.RawMagical = math.min(300, args.RawMagical)
			end
		end,
		["Jhin"] = function(args)
			if myHero.hudAmmo==1 then
				args.CriticalStrike = true
				args.CalculatedPhysical = args.CalculatedPhysical
					+ math_min(0.25, 0.1 + 0.05 * math_ceil(args.From.levelData.lvl / 5))
						* (args.Target.maxHealth - args.Target.health)*0.66 --shortcut for dealing with crit multipliers
			end
		end,
		["Lux"] = function(args)
			if Buff:HasBuff(args.Target, "LuxIlluminatingFraulein") then
				args.RawMagical = 20 + args.From.levelData.lvl * 10 + args.From.ap * 0.25
			end
		end,
		["Orianna"] = function(args)
			local level = math_ceil(args.From.levelData.lvl / 3)
			args.RawMagical = args.RawMagical + 2 + 8 * level + 0.15 * args.From.ap
			if args.Target.handle == args.From.attackData.target then
				args.RawMagical = args.RawMagical
					+ math_max(Buff:GetBuffCount(args.From, "orianapowerdaggerdisplay"), 0)
						* (0.4 + 1.6 * level + 0.03 * args.From.ap)
			end
		end,
		["Quinn"] = function(args)
			if Buff:HasBuff(args.Target, "QuinnW") then
				local level = args.From.levelData.lvl
				args.RawPhysical = args.RawPhysical + 10 + level * 5 + (0.14 + 0.02 * level) * args.From.totalDamage
			end
		end,
		["Teemo"] = function(args)
			local Edata = myHero:GetSpellData(_E)
			if Edata.level > 0 then
				args.RawMagical = Edata.level * 10 + 0.30 * args.From.ap
			end
		end,
		["Vayne"] = function(args)
			if Buff:GetBuffCount(args.Target, "VayneSilveredDebuff") == 2 then
				local level = args.From:GetSpellData(_W).level
				args.CalculatedTrue = args.CalculatedTrue
					+ math_max((0.05 + 0.01 * level) * args.Target.maxHealth, 35 + 15 * level)
			end
		end,
		["Zed"] = function(args)
			if
				100 * args.Target.health / args.Target.maxHealth <= 50 and not Buff:HasBuff(args.From, "zedpassivecd")
			then
				args.RawMagical = args.RawMagical
					+ args.Target.maxHealth * (4 + 2 * math_ceil(args.From.levelData.lvl / 6)) * 0.01
			end
		end,
	},

	IsBaseTurret = function(self, name)
		if self.BaseTurrets[name] then
			return true
		end
		return false
	end,

	SetHeroStaticDamage = function(self, args)
		local s = self.HeroStaticDamage[args.From.charName]
		if s then
			s(args)
		end
	end,

	SetItemStaticDamage = function(self, id, args)
		local s = self.ItemStaticDamage[id]
		if s then
			s(args)
		end
	end,

	SetHeroPassiveDamage = function(self, args)
		local s = self.HeroPassiveDamage[args.From.charName]
		if s then
			s(args)
		end
	end,

	CalculateDamage = function(self, from, target, damageType, rawDamage, isAbility, isAutoAttackOrTargetted)
		if from == nil or target == nil then
			return 0
		end
		if isAbility == nil then
			isAbility = true
		end
		if isAutoAttackOrTargetted == nil then
			isAutoAttackOrTargetted = false
		end
		local fromIsMinion = from.type == Obj_AI_Minion
		local targetIsMinion = target.type == Obj_AI_Minion
		local baseResistance = 0
		local bonusResistance = 0
		local penetrationFlat = 0
		local penetrationPercent = 0
		local bonusPenetrationPercent = 0
		if damageType == DAMAGE_TYPE_PHYSICAL then
			baseResistance = math_max(target.armor - target.bonusArmor, 0)
			bonusResistance = target.bonusArmor
			penetrationFlat = from.armorPen
			penetrationPercent = from.armorPenPercent
			bonusPenetrationPercent = from.bonusArmorPenPercent
			-- Minions return wrong percent values.
			if fromIsMinion then
				penetrationFlat = 0
				penetrationPercent = 0
				bonusPenetrationPercent = 0
			elseif from.type == Obj_AI_Turret then
				penetrationPercent = self:IsBaseTurret(from.charName) and 0.75 or 0.3
				penetrationFlat = 0
				bonusPenetrationPercent = 0
			end
		elseif damageType == DAMAGE_TYPE_MAGICAL then
			baseResistance = math_max(target.magicResist - target.bonusMagicResist, 0)
			bonusResistance = target.bonusMagicResist
			penetrationFlat = from.magicPen
			penetrationPercent = from.magicPenPercent
			bonusPenetrationPercent = 0
		elseif damageType == DAMAGE_TYPE_TRUE then
			return rawDamage
		end
		local resistance = baseResistance + bonusResistance
		if resistance > 0 then
			if penetrationPercent > 0 then
				baseResistance = baseResistance * penetrationPercent
				bonusResistance = bonusResistance * penetrationPercent
			end
			if bonusPenetrationPercent > 0 then
				bonusResistance = bonusResistance * bonusPenetrationPercent
			end
			resistance = baseResistance + bonusResistance
			resistance = resistance - penetrationFlat
		end
		local percentMod = 1
		-- Penetration cant reduce resistance below 0.
		if resistance >= 0 then
			percentMod = percentMod * (100 / (100 + resistance))
		else
			percentMod = percentMod * (2 - 100 / (100 - resistance))
		end
		local flatPassive = 0
		local percentPassive = 1
		if fromIsMinion and targetIsMinion then
			percentPassive = percentPassive * (1 + from.bonusDamagePercent)
		end
		local flatReceived = 0
		if not isAbility and targetIsMinion then
			flatReceived = flatReceived - target.flatDamageReduction
		end
		return math_max(percentPassive * percentMod * (rawDamage + flatPassive) + flatReceived, 0)
	end,

	GetStaticAutoAttackDamage = function(self, from, targetIsMinion)
		local args = {
			From = from,
			RawTotal = from.totalDamage,
			RawPhysical = 0,
			RawMagical = 0,
			CalculatedTrue = 0,
			CalculatedPhysical = 0,
			CalculatedMagical = 0,
			DamageType = DAMAGE_TYPE_PHYSICAL,
			TargetIsMinion = targetIsMinion,
		}
		if from.charName=="Jhin" then
			local levelAD = { 1.04, 1.05, 1.06, 1.07, 1.08, 1.09, 1.1, 1.11, 1.12, 1.14, 1.16, 1.2, 1.24, 1.28, 1.32, 1.36, 1.40, 1.44}
			local JhinAD= ((((59+4.7*(myHero.levelData.lvl-1)*(0.7025+(0.0175*(myHero.levelData.lvl-1)))))*(levelAD[math.max(math.min(myHero.levelData.lvl, 18), 1)]+myHero.critChance*0.3+0.25*(myHero.attackSpeed-1)))+myHero.bonusDamage)
			args.RawTotal=JhinAD

		end

		self:SetHeroStaticDamage(args)
		local HashSet = {}
		for i = 1, #ItemSlots do
			local slot = ItemSlots[i]
			local item = args.From:GetItemData(slot)
			if item ~= nil and item.itemID > 0 then
				if HashSet[item.itemID] == nil then
					self:SetItemStaticDamage(item.itemID, args)
					HashSet[item.itemID] = true
				end
			end
		end
		return args
	end,

	GetHeroAutoAttackDamage = function(self, from, target, static)
		local args = {
			From = from,
			Target = target,
			RawTotal = static.RawTotal,
			RawPhysical = static.RawPhysical,
			RawMagical = static.RawMagical,
			CalculatedTrue = static.CalculatedTrue,
			CalculatedPhysical = static.CalculatedPhysical,
			CalculatedMagical = static.CalculatedMagical,
			DamageType = static.DamageType,
			TargetIsMinion = target.type == Obj_AI_Minion,
			CriticalStrike = false,
		}
		if args.TargetIsMinion and args.Target.maxHealth <= 6 then
			return 1
		end
		self:SetHeroPassiveDamage(args)
		if args.DamageType == DAMAGE_TYPE_PHYSICAL then
			args.RawPhysical = args.RawPhysical + args.RawTotal
		elseif args.DamageType == DAMAGE_TYPE_MAGICAL then
			args.RawMagical = args.RawMagical + args.RawTotal
		elseif args.DamageType == DAMAGE_TYPE_TRUE then
			args.CalculatedTrue = args.CalculatedTrue + args.RawTotal
		end

		if args.RawPhysical > 0 then
			args.CalculatedPhysical = args.CalculatedPhysical
				+ self:CalculateDamage(
					from,
					target,
					DAMAGE_TYPE_PHYSICAL,
					args.RawPhysical,
					false,
					args.DamageType == DAMAGE_TYPE_PHYSICAL
				)
		end
		if args.RawMagical > 0 then
			args.CalculatedMagical = args.CalculatedMagical
				+ self:CalculateDamage(
					from,
					target,
					DAMAGE_TYPE_MAGICAL,
					args.RawMagical,
					false,
					args.DamageType == DAMAGE_TYPE_MAGICAL
				)
		end
		-- Focus passive from Doran items and Tear of the Goddess
		if args.TargetIsMinion and args.Target.maxHealth > 6 then
			if Item:HasItem(from, 1054) or Item:HasItem(from, 1056) or Item:HasItem(from, 3070) then
				args.CalculatedPhysical = args.CalculatedPhysical + 5
			end
		end
		local percentMod = 1
		if args.From.critChance - 1 == 0 or args.CriticalStrike then
			percentMod = percentMod * self:GetCriticalStrikePercent(args.From)
		end
		return percentMod * args.CalculatedPhysical + args.CalculatedMagical + args.CalculatedTrue
	end,

	GetAutoAttackDamage = function(self, from, target, respectPassives)
		if respectPassives == nil then
			respectPassives = true
		end
		if from == nil or target == nil then
			return 0
		end
		local targetIsMinion = target.type == Obj_AI_Minion
		if respectPassives and from.type == Obj_AI_Hero then
			if from.charName=="Graves" then
				if target.distance<target.boundingRadius/0.212 then
					return self:GetHeroAutoAttackDamage(from, target, self:GetStaticAutoAttackDamage(from, targetIsMinion))*2
				end
				return self:GetHeroAutoAttackDamage(from, target, self:GetStaticAutoAttackDamage(from, targetIsMinion))*1.33
			end
--[[ 			if myHero.hudAmmo==1 then
				print(self:GetHeroAutoAttackDamage(from, target, self:GetStaticAutoAttackDamage(from, targetIsMinion)))
			end ]]
			return self:GetHeroAutoAttackDamage(from, target, self:GetStaticAutoAttackDamage(from, targetIsMinion))
		end

		if targetIsMinion then
			if target.maxHealth <= 6 then
				return 1
			end
			if from.type == Obj_AI_Turret and not self:IsBaseTurret(from.charName) then
				local percentMod = self.TurretToMinionPercent[target.charName]
				if percentMod ~= nil then
					return target.maxHealth * percentMod
				end
			end
		end
		if from.charName=="Jhin" then
			local levelAD = { 1.04, 1.05, 1.06, 1.07, 1.08, 1.09, 1.1, 1.11, 1.12, 1.14, 1.16, 1.2, 1.24, 1.28, 1.32, 1.36, 1.40, 1.44}
			local JhinAD= ((((59+4.7*(myHero.levelData.lvl-1)*(0.7025+(0.0175*(myHero.levelData.lvl-1)))))*(levelAD[math.max(math.min(myHero.levelData.lvl, 18), 1)]+myHero.critChance*0.3+0.25*(myHero.attackSpeed-1)))+myHero.bonusDamage)
			return self:CalculateDamage(from, target, DAMAGE_TYPE_PHYSICAL, JhinAD, false, true)
		end

		return self:CalculateDamage(from, target, DAMAGE_TYPE_PHYSICAL, from.totalDamage, false, true)
	end,

	GetCriticalStrikePercent = function(self, from)
		local baseCriticalDamage = 1.75
		local percentMod = 1
		local fixedMod = 0
		if from.charName == "Jhin" then
			percentMod = 0.86
		elseif from.charName == "XinZhao" then
			baseCriticalDamage = baseCriticalDamage - (0.875 - 0.125 * from:GetSpellData(_W).level)
		-- elseif from.charName == "Yasuo" then
			-- percentMod = 0.9
		elseif from.charName == "Yunara" then
			baseCriticalDamage = baseCriticalDamage * (1.1 + 0.001 * from.ap)
		end
		return baseCriticalDamage * percentMod
	end,
}

Data = {

	JungleTeam = 300,
	AllyTeam = myHero.team,
	EnemyTeam = 300 - myHero.team,
	HeroName = myHero.charName,

	ChannelingBuffs = {
		["Caitlyn"] = function()
			return Buff:HasBuff(myHero, "CaitlynAceintheHole")
		end,
		["FiddleSticks"] = function()
			return Buff:HasBuff(myHero, "Drain") or Buff:HasBuff(myHero, "Crowstorm")
		end,
		["Galio"] = function()
			return Buff:HasBuff(myHero, "GalioIdolOfDurand")
		end,
		["Janna"] = function()
			return Buff:HasBuff(myHero, "ReapTheWhirlwind")
		end,
		["Kaisa"] = function()
			return Buff:HasBuff(myHero, "KaisaE")
		end,
		["Karthus"] = function()
			return Buff:HasBuff(myHero, "karthusfallenonecastsound")
		end,
		["Katarina"] = function()
			return Buff:HasBuff(myHero, "katarinarsound")
		end,
		["Lucian"] = function()
			return Buff:HasBuff(myHero, "LucianR")
		end,
		["Malzahar"] = function()
			return Buff:HasBuff(myHero, "alzaharnethergraspsound")
		end,
		["MissFortune"] = function()
			return Buff:HasBuff(myHero, "missfortunebulletsound")
		end,
		["Nunu"] = function()
			return Buff:HasBuff(myHero, "AbsoluteZero")
		end,
		["Pantheon"] = function()
			return Buff:HasBuff(myHero, "pantheonesound") or Buff:HasBuff(myHero, "PantheonRJump")
		end,
		["Shen"] = function()
			return Buff:HasBuff(myHero, "shenstandunitedlock")
		end,
		["TwistedFate"] = function()
			return Buff:HasBuff(myHero, "Destiny")
		end,
		["Urgot"] = function()
			return Buff:HasBuff(myHero, "UrgotSwap2")
		end,
		["Varus"] = function()
			return Buff:HasBuff(myHero, "VarusQ")
		end,
		["Velkoz"] = function()
			return Buff:HasBuff(myHero, "VelkozR")
		end,
		["Vi"] = function()
			return Buff:HasBuff(myHero, "ViQ")
		end,
		["Vladimir"] = function()
			return Buff:HasBuff(myHero, "VladimirE")
		end,
		["Warwick"] = function()
			return Buff:HasBuff(myHero, "infiniteduresssound")
		end,
		["Xerath"] = function()
			return Buff:HasBuff(myHero, "XerathArcanopulseChargeUp") or Buff:HasBuff(myHero, "XerathLocusOfPower2")
		end,
	},

	SpecialWindup = {
		["Yunara"] = function()
			if Buff:HasBuff(myHero, "YunaraQ") then
				return 0.09
			end
			return nil
		end,
		["TwistedFate"] = function()
			if
				Buff:HasBuff(myHero, "BlueCardPreAttack")
				or Buff:HasBuff(myHero, "RedCardPreAttack")
				or Buff:HasBuff(myHero, "GoldCardPreAttack")
			then
				return 0.125
			end
			return nil
		end,
		["Jayce"] = function()
			if Buff:HasBuff(myHero, "JayceHyperCharge") then
				return 0.125
			end
			return nil
		end,
		["Aphelios"] = function()
			if Buff:HasBuff(myHero, "ApheliosCrescendumManager") then
				return 0.1067
			end
			return nil
		end,
	},

	AllowMovement = {
		["Kaisa"] = function()
			return Buff:HasBuff(myHero, "KaisaE")
		end,
		["Lucian"] = function()
			return Buff:HasBuff(myHero, "LucianR")
		end,
		["Varus"] = function()
			return Buff:HasBuff(myHero, "VarusQ")
		end,
		["Vi"] = function()
			return Buff:HasBuff(myHero, "ViQ")
		end,
		["Vladimir"] = function()
			return Buff:HasBuff(myHero, "VladimirE")
		end,
		["Xerath"] = function()
			return Buff:HasBuff(myHero, "XerathArcanopulseChargeUp")
		end,
	},

	DisableAttackSpells = {
		["Renata"] = function(spell)
			local name = spell.name
			return (name == "RenataQ" or name == "RenataE" or name == "RenataR")
				and spell.castEndTime - Game.Timer() > 0.05
		end,
		
		["Caitlyn"] = function(spell)
			local name = spell.name
			if (name == "CaitlynQ" or name == "CaitlynE" or name == "CaitlynW" or name == "CaitlynR")and spell.endTime - Game.Timer() > 0.04 then
				--print(Game.Timer())
			end 
			return (name == "CaitlynQ" or name == "CaitlynE" or name == "CaitlynW" or name == "CaitlynR")and spell.endTime - Game.Timer() > 0.04
		end,
	},

	DisableAttackBuffs = {
		["Renata"] = function()
			return Buff:HasBuff(myHero, "renataqselfroot") or Buff:HasBuff(myHero, "RenataQRecast")
		end,
		["Urgot"] = function()
			return Buff:HasBuff(myHero, "UrgotW")
		end,
		["Darius"] = function()
			return Buff:HasBuff(myHero, "dariusqcast")
		end,
		["Graves"] = function()
			if myHero.hudAmmo == 0 then
				return true
			end
			return false
		end,
		["Jhin"] = function()
			if myHero.hudAmmo == 0 then
				return true
			end
			return false
		end,
	},

	SpecialMissileSpeeds = {
		["Yunara"] = function()
			if Buff:HasBuff(myHero, "YunaraQ") then
				return 10000
			end
			return nil
		end,
		["Hwei"] = function()
			return 3470
		end,
		["Aphelios"] = function()
			if Buff:HasBuff(myHero, "ApheliosCrescendumManager") then
				return 3500
			elseif Buff:HasBuff(myHero, "ApheliosCalibrumManager") then
				return 3000
			elseif Buff:HasBuff(myHero, "ApheliosInfernumManager") then
				return 1700
			elseif Buff:HasBuff(myHero, "ApheliosSeverumManager") then
				return math.huge
			end
			return 1500
		end,
		["Caitlyn"] = function()
			if Buff:HasBuff(myHero, "caitlynpassivedriver") then
				return 3000
			end
			return nil
		end,
		["Graves"] = function()
			return 3800
		end,
		["Seraphine"] = function()
			return 1800
		end,
		["Anivia"] = function()
			return 1600
		end,
		["Illaoi"] = function()
			if Buff:HasBuff(myHero, "IllaoiW") then
				return 1600
			end
			return nil
		end,
		["Jayce"] = function()
			if myHero:GetSpellData(_Q).name=="JayceShockBlast" then
				return 2000
			end
			return nil
		end,
        ["Viktor"] = function()
            if Buff:HasBuff(myHero, "ViktorQReturn") then
                return 5000
            end
            return nil
        end,
		["Jhin"] = function()
			if myHero.hudAmmo==1 then
				return 3000
			end
			return nil
		end,
		["Jinx"] = function()
			if Buff:HasBuff(myHero, "JinxQ") then
				return 2000
			end
			return nil
		end,
		["Poppy"] = function()
			if Buff:HasBuff(myHero, "poppypassivebuff") then
				return 1600
			end
			return nil
		end,
		["Twitch"] = function()
			if Buff:HasBuff(myHero, "TwitchFullAutomatic") then
				return 5000
			end
			return nil
		end,
		["Kayle"] = function()
			if Buff:HasBuff(myHero, "KayleE") then
				return 1750
			end
			return nil
		end,
	},

	--25.14
	HEROES = {
		Aatrox = { 3, true, 0.651 },
		Ahri = { 4, false, 0.668 },
		Akali = { 4, true, 0.625 },
		Akshan = { 5, false, 0.638 },
		Alistar = { 1, true, 0.625 },
		Ambessa = { 2, true, 0.625 },
		Amumu = { 1, true, 0.736 },
		Anivia = { 4, false, 0.625 },
		Annie = { 4, false, 0.61 },
		Aphelios = { 5, false, 0.665 },
		Ashe = { 5, false, 0.658 },
		AurelionSol = { 4, false, 0.625 },
		Aurora = { 4, false, 0.668 },
		Azir = { 4, true, 0.625 },
		Bard = { 3, false, 0.625 },
		Belveth = { 4, true, 0.85 },
		Blitzcrank = { 1, true, 0.625 },
		Brand = { 4, false, 0.625 },
		Braum = { 1, true, 0.644 },
		Briar = { 4, true, 0.664 },
		Caitlyn = { 5, false, 0.681 },
		Camille = { 3, true, 0.644 },
		Cassiopeia = { 4, false, 0.647 },
		Chogath = { 1, true, 0.658 },
		Corki = { 5, false, 0.644 },
		Darius = { 2, true, 0.625 },
		Diana = { 4, true, 0.625 },
		DrMundo = { 1, true, 0.67 },
		Draven = { 5, false, 0.679 },
		Ekko = { 4, true, 0.688 },
		Elise = { 3, false, 0.625 },
		Evelynn = { 4, true, 0.667 },
		Ezreal = { 5, false, 0.625 },
		FiddleSticks = { 3, false, 0.625 },
		Fiora = { 3, true, 0.69 },
		Fizz = { 4, true, 0.658 },
		Galio = { 1, true, 0.625 },
		Gangplank = { 4, true, 0.658 },
		Garen = { 1, true, 0.625 },
		Gnar = { 1, false, 0.625 },
		Gragas = { 2, true, 0.675 },
		Graves = { 4, false, 0.475 },
		Gwen = { 4, true, 0.69 },
		Hecarim = { 2, true, 0.67 },
		Heimerdinger = { 3, false, 0.625 },
		Hwei = { 4, false, 0.69 },
		Illaoi = { 3, true, 0.625 },
		Irelia = { 3, true, 0.656 },
		Ivern = { 1, true, 0.644 },
		Janna = { 2, false, 0.625 },
		JarvanIV = { 3, true, 0.658 },
		Jax = { 3, true, 0.638 },
		Jayce = { 4, false, 0.658 },
		Jhin = { 5, false, 0.625 },
		Jinx = { 5, false, 0.625 },
		KSante = { 1, true, 0.625 },
		Kaisa = { 5, false, 0.644 },
		Kalista = { 5, false, 0.694 },
		Karma = { 4, false, 0.625 },
		Karthus = { 4, false, 0.625 },
		Kassadin = { 4, true, 0.64 },
		Katarina = { 4, true, 0.658 },
		Kayle = { 4, false, 0.625 },
		Kayn = { 4, true, 0.669 },
		Kennen = { 4, false, 0.625 },
		Khazix = { 4, true, 0.668 },
		Kindred = { 4, false, 0.625 },
		Kled = { 2, true, 0.625 },
		KogMaw = { 5, false, 0.665 },
		Leblanc = { 4, false, 0.658 },
		LeeSin = { 3, true, 0.651 },
		Leona = { 1, true, 0.625 },
		Lillia = { 4, false, 0.625 },
		Lissandra = { 4, false, 0.656 },
		Lucian = { 5, false, 0.638 },
		Lulu = { 3, false, 0.625 },
		Lux = { 4, false, 0.669 },
		Malphite = { 1, true, 0.736 },
		Malzahar = { 3, false, 0.625 },
		Maokai = { 2, true, 0.8 },
		MasterYi = { 5, true, 0.679 },
		Mel = { 4, false, 0.625 },
		Milio = { 3, false, 0.625 },
		MissFortune = { 5, false, 0.656 },
		MonkeyKing = { 3, true, 0.69 },
		Mordekaiser = { 4, true, 0.625 },
		Morgana = { 3, false, 0.625 },
		Naafiri = { 4, true, 0.663 },
		Nami = { 3, false, 0.644 },
		Nasus = { 2, true, 0.638 },
		Nautilus = { 1, true, 0.706 },
		Neeko = { 4, false, 0.625 },
		Nidalee = { 4, false, 0.638 },
		Nilah = { 5, true, 0.697 },
		Nocturne = { 4, true, 0.721 },
		Nunu = { 2, true, 0.625 },
		Olaf = { 2, true, 0.694 },
		Orianna = { 4, false, 0.658 },
		Ornn = { 2, true, 0.625 },
		Pantheon = { 3, true, 0.658 },
		Poppy = { 2, true, 0.658 },
		Pyke = { 4, true, 0.667 },
		Qiyana = { 4, true, 0.688 },
		Quinn = { 5, false, 0.668 },
		Rakan = { 3, true, 0.635 },
		Rammus = { 1, true, 0.7 },
		RekSai = { 2, true, 0.667 },
		Rell = { 1, true, 0.625 },
		Renata = { 2, false, 0.625 },
		Renekton = { 2, true, 0.665 },
		Rengar = { 4, true, 0.667 },
		Riven = { 4, true, 0.625 },
		Rumble = { 4, true, 0.644 },
		Ryze = { 4, false, 0.658 },
		Samira = { 5, false, 0.658 },
		Sejuani = { 2, true, 0.688 },
		Senna = { 5, false, 0.625 },
		Seraphine = { 3, false, 0.669 },
		Sett = { 2, true, 0.625 },
		Shaco = { 4, true, 0.694 },
		Shen = { 1, true, 0.751 },
		Shyvana = { 2, true, 0.658 },
		Singed = { 1, true, 0.7 },
		Sion = { 1, true, 0.679 },
		Sivir = { 5, false, 0.625 },
		Skarner = { 2, true, 0.625 },
		Smolder = { 5, false, 0.638 },
		Sona = { 3, false, 0.644 },
		Soraka = { 3, false, 0.625 },
		Swain = { 3, false, 0.625 },
		Sylas = { 4, true, 0.645 },
		Syndra = { 4, false, 0.625 },
		TahmKench = { 1, true, 0.658 },
		Taliyah = { 4, false, 0.625 },
		Talon = { 4, true, 0.625 },
		Taric = { 1, true, 0.625 },
		Teemo = { 4, false, 0.69 },
		Thresh = { 1, true, 0.625 },
		Tristana = { 5, false, 0.656 },
		Trundle = { 2, true, 0.67 },
		Tryndamere = { 4, true, 0.67 },
		TwistedFate = { 4, false, 0.651 },
		Twitch = { 5, false, 0.679 },
		Udyr = { 2, true, 0.65 },
		Urgot = { 2, true, 0.625 },
		Varus = { 5, false, 0.658 },
		Vayne = { 5, false, 0.658 },
		Veigar = { 4, false, 0.625 },
		Velkoz = { 4, false, 0.643 },
		Vex = { 4, false, 0.669 },
		Vi = { 2, true, 0.644 },
		Viego = { 4, true, 0.658 },
		Viktor = { 4, false, 0.658 },
		Vladimir = { 3, false, 0.658 },
		Volibear = { 2, true, 0.625 },
		Warwick = { 2, true, 0.638 },
		Xayah = { 5, false, 0.658 },
		Xerath = { 4, false, 0.658 },
		XinZhao = { 3, true, 0.645 },
		Yasuo = { 4, true, 0.697 },
		Yone = { 4, true, 0.625 },
		Yorick = { 2, true, 0.625 },
		Yunara = { 5, false, 0.65 },
		Yuumi = { 3, false, 0.625 },
		Zac = { 1, true, 0.736 },
		Zed = { 4, true, 0.651 },
		Zeri = { 5, false, 0.658 },
		Ziggs = { 4, false, 0.656 },
		Zilean = { 3, false, 0.658 },
		Zoe = { 4, false, 0.658 },
		Zyra = { 2, false, 0.681 },
		Zaahen = { 4, true, 0.625 },
	},

	HeroSpecialMelees = {
		["Elise"] = function()
			return myHero.range < 200
		end,
		["Gnar"] = function()
			return myHero.range < 200
		end,
		["Jayce"] = function()
			return myHero.range < 200
		end,
		["Kayle"] = function()
			return myHero.range < 200
		end,
		["Nidalee"] = function()
			return myHero.range < 200
		end,
	},

	IsAttackSpell = {
		["YunaraQCrit"] = true,
		["YunaraQCrit2"] = true,
		["ViktorQBuff"] = true,
		["CaitlynPassiveMissile"] = true,
		["GarenQAttack"] = true,
		["KennenMegaProc"] = true,
		["QuinnWEnhanced"] = true,
		["BlueCardPreAttack"] = true,
		["RedCardPreAttack"] = true,
		["GoldCardPreAttack"] = true,
		-- 9.9 patch
		["RenektonSuperExecute"] = true,
		["RenektonExecute"] = true,
		["XinZhaoQThrust1"] = true,
		["XinZhaoQThrust2"] = true,
		["XinZhaoQThrust3"] = true,
		["MasterYiDoubleStrike"] = true,
	},

	IsNotAttack = {
		["GravesAutoAttackRecoil"] = true,
		["LeonaShieldOfDaybreakAttack"] = true,
	},

	MinionRange = {
		["SRU_ChaosMinionMelee"] = 110,
		["SRU_ChaosMinionRanged"] = 550,
		["SRU_ChaosMinionSiege"] = 300,
		["SRU_ChaosMinionSuper"] = 170,
		["SRU_OrderMinionMelee"] = 110,
		["SRU_OrderMinionRanged"] = 550,
		["SRU_OrderMinionSiege"] = 300,
		["SRU_OrderMinionSuper"] = 170,
		["HA_ChaosMinionMelee"] = 110,
		["HA_ChaosMinionRanged"] = 550,
		["HA_ChaosMinionSiege"] = 300,
		["HA_ChaosMinionSuper"] = 170,
		["HA_OrderMinionMelee"] = 110,
		["HA_OrderMinionRanged"] = 550,
		["HA_OrderMinionSiege"] = 300,
		["HA_OrderMinionSuper"] = 170,
	},

	ExtraAttackRanges = {
		["Caitlyn"] = function(target)
			if
				target
				and (
					Buff:GetBuffDuration(target, "caitlynwsight") > 0.75
					or Buff:HasBuff(target, "eternals_caitlyneheadshottracker")
				)
			then --Buff:GetBuffDuration(enemy, "eternals_caitlyneheadshottracker") > 0.75
				--print(Game.Timer())
			
				--	print(Buff:GetBuffDuration(target, "caitlynwsight"), Buff:HasBuff(target, "eternals_caitlyneheadshottracker"))
				return 425
			end
			return 0
		end,
	},

	AttackResets = {
		["Ashe"] = {{ Slot = _Q, Key = HK_Q }},
		["Blitzcrank"] = {{ Slot = _E, Key = HK_E }},
		["Camille"] = {{ Slot = _Q, Key = HK_Q }},
		["Chogath"] = {{ Slot = _E, Key = HK_E }},
		["Darius"] = {{ Slot = _W, Key = HK_W }},
		["DrMundo"] = {{ Slot = _E, Key = HK_E }},
		["Elise"] = {{ Slot = _W, Key = HK_W, Name = "EliseSpiderW" }},
		["Fiora"] = {{ Slot = _E, Key = HK_E }},
		["Fizz"] = {{ Slot = _W, Key = HK_W }},
		["Garen"] = {{ Slot = _Q, Key = HK_Q }},
		["Graves"] = {{ Slot = _E, Key = HK_E, OnCast = true, CanCancel = true }},
		["Gwen"] = {{ Slot = _E, Key = HK_E, OnCast = true }},
		["Kassadin"] = {{ Slot = _W, Key = HK_W }},
		["Illaoi"] = {{ Slot = _W, Key = HK_W }},
		["Jax"] = {{ Slot = _W, Key = HK_W }},
		["Jayce"] = {{ Slot = _W, Key = HK_W, Name = "JayceHyperCharge" }},
		["Kayle"] = {{ Slot = _E, Key = HK_E }},
		["Katarina"] = {{ Slot = _E, Key = HK_E, CanCancel = true, OnCast = true }},
		["Kindred"] = {{ Slot = _Q, Key = HK_Q }},
		["KSante"] = {
			{ Slot = _E, Key = HK_E, CanCancel = true, OnCast = true },
			{ Slot = _Q, Key = HK_Q }  
		},
		["Leona"] = {{ Slot = _Q, Key = HK_Q }},
		["Lucian"] = {{ Slot = _E, Key = HK_E, OnCast = true, CanCancel = true, Buff = { ["lucianpassivebuff"] = true }}},
		["MasterYi"] = {{ Slot = _W, Key = HK_W }},
		--["Mordekaiser"] = {{ Slot = _Q, Key = HK_Q }},
		["Nautilus"] = {{ Slot = _W, Key = HK_W }},
		["Nidalee"] = {{ Slot = _Q, Key = HK_Q, Name = "Takedown" }},
		["Nasus"] = {{ Slot = _Q, Key = HK_Q }},
		["Olaf"] = {{ Slot = _W, Key = HK_W }},
		["RekSai"] = {{ Slot = _Q, Key = HK_Q, Name = "RekSaiQ" }},
		["Renekton"] = {{ Slot = _W, Key = HK_W }},
		["Rengar"] = {{ Slot = _Q, Key = HK_Q }},
		--["Riven"] = {{ Slot = _Q, Key = HK_Q }},
		-- RIVEN BUFFS ["Riven"] = {'riventricleavesoundone', 'riventricleavesoundtwo', 'riventricleavesoundthree'},
		["Sejuani"] = {{ Slot = _E, Key = HK_E, ReadyCheck = true, ActiveCheck = true, SpellName = "SejuaniE2" }},
		["Shyvana"] = {{ Slot = _Q, Key = HK_Q }},
		["Sivir"] = {{ Slot = _W, Key = HK_W }},
		["Trundle"] = {{ Slot = _Q, Key = HK_Q }},
		["Talon"] = {{ Slot = _Q, Key = HK_Q }},
		["Vayne"] = {{ Slot = _Q, Key = HK_Q, Buff = { ["vaynetumblebonus"] = true }, CanCancel = true }},
		["Vi"] = {{ Slot = _E, Key = HK_E }},
		["Volibear"] = {{ Slot = _Q, Key = HK_Q }},
		["MonkeyKing"] = {{ Slot = _Q, Key = HK_Q }},
		["XinZhao"] = {{ Slot = _Q, Key = HK_Q }},
		["Yorick"] = {{ Slot = _Q, Key = HK_Q, Name = "YorickQ" }},
		["Yunara"] = {{ Slot = _Q, Key = HK_Q }},
		["Zaahen"] = {{ Slot = _Q, Key = HK_Q }},
	},

	WndMsg = function(self, msg, wParam)
		if not self.AttackResets then
			return
		end
	
		local championAttackResets = self.AttackResets[myHero.charName]
		if not championAttackResets then
			return
		end
	
		for _, attackReset in ipairs(championAttackResets) do
			local AttackResetKey = attackReset.Key
			local AttackResetActiveSpell = attackReset.ActiveCheck
			local AttackResetIsReady = attackReset.ReadyCheck
			local AttackResetName = attackReset.Name
			local AttackResetSpellName = attackReset.SpellName
	
			if
				not self.AttackResetSuccess
				and not Control.IsKeyDown(8)
				and not GameIsChatOpen()
				and wParam == AttackResetKey
			then
				local checkNum = Object.IsRiven and 400 or 600
				if GetTickCount() <= self.AttackResetTimer + checkNum then
					return
				end
				if AttackResetIsReady and GameCanUseSpell(attackReset.Slot) ~= 0 then
					return
				end
				local spellData = myHero:GetSpellData(attackReset.Slot)
				if
					(Object.IsRiven or spellData.mana <= myHero.mana)
					and spellData.currentCd == 0
					and (not AttackResetName or spellData.name == AttackResetName)
				then
					if AttackResetActiveSpell then
						self.AttackResetTimer = GetTickCount()
						local startTime = GetTickCount() + 400
						Action:Add(function()
							local s = myHero.activeSpell
							if s and s.valid and s.name == AttackResetSpellName then
								self.AttackResetTimer = GetTickCount()
								self.AttackResetSuccess = true
								return true
							end
							if GetTickCount() < startTime then
								return false
							end
							return true
						end)
						return
					end
					self.AttackResetTimer = GetTickCount()
					if Object.IsKindred then
						Orbwalker:SetMovement(false)
						local setTime = GetTickCount() + 550
						Action:Add(function()
							if GetTickCount() < setTime then
								return false
							end
							Orbwalker:SetMovement(true)
							return true
						end)
						return
					end
					self.AttackResetSuccess = true
				end
			end
		end
	end,

	IdEquals = function(self, a, b)
		if a == nil or b == nil then
			return false
		end
		return a.networkID == b.networkID
	end,

	GetAutoAttackRange = function(self, from, target)
		local result = from.range
		local fromType = from.type
		if fromType == Obj_AI_Minion then
			local fromName = from.charName
			result = self.MinionRange[fromName] ~= nil and self.MinionRange[fromName] or 0
		elseif fromType == Obj_AI_Turret then
			result = 775
		end
		if target then
			local targetType = target.type
			if targetType == Obj_AI_Barracks then
				result = result + 270
			elseif targetType == Obj_AI_Nexus then
				result = result + 380
			else
				result = result + from.boundingRadius + target.boundingRadius
				if targetType == Obj_AI_Hero and self.ExtraAttackRange then
					result = result + self.ExtraAttackRange(target)
				end
			end
		else
			result = result + from.boundingRadius + 35
		end
		return result
	end,

	IsInAutoAttackRange = function(self, from, target, extrarange)
		local range = extrarange or 0
		return IsInRange(from.pos, target.pos, self:GetAutoAttackRange(from, target) + range)
	end,

	IsInAutoAttackRange2 = function(self, from, target, extrarange)
		local range = self:GetAutoAttackRange(from, target) + (extrarange or 0)
		if IsInRange(from.pos, target.pos, range) and IsInRange(from.pos, target.posTo, range) then
			return true
		end
		return false
	end,

	CanResetAttack = function(self)
		if self.AttackReset == nil then
			return false
		end
		if self.AttackResetCanCancel then
			if self.AttackResetOnCast then
				if self.AttackResetBuff == nil or Buff:ContainsBuffs(myHero, self.AttackResetBuff) then
					local spellData = myHero:GetSpellData(self.AttackResetSlot)
					local startTime = spellData.castTime - spellData.cd
					if
						not self.AttackResetSuccess
						and GameTimer() - startTime > 0.075
						and GameTimer() - startTime < 0.5
						and GetTickCount() > self.AttackResetTimer + 1000
					then
						--print('Reset Cast, Buff ' .. tostring(os.clock()))
						self.AttackResetSuccess = true
						self.AttackResetTimeout = GetTickCount()
						self.AttackResetTimer = GetTickCount()
						return true
					end
					if self.AttackResetSuccess and GetTickCount() > self.AttackResetTimeout + 200 then
						--print('Reset Timeout')
						self.AttackResetSuccess = false
					end
					return false
				end
			elseif Buff:ContainsBuffs(myHero, self.AttackResetBuff)  then
				if not self.AttackResetSuccess then
					self.AttackResetSuccess = true
					--print('Reset Buff')
					return true
				end
				return false
			end
			if self.AttackResetSuccess then
				--print('Remove Reset')
				self.AttackResetSuccess = false
			end
			return false
		end
		if self.AttackResetSuccess then
			self.AttackResetSuccess = false
			--print("AA RESET STOP !")
			return true
		end
		return false
	end,

	IsAttack = function(self, name)
		if self.IsAttackSpell[name] then
			return true
		end
		if self.IsNotAttack[name] then
			return false
		end
		return name:lower():find("attack")
	end,

	GetLatency = function(self)
		return LATENCY * 0.001
	end,

	HeroCanMove = function(self)
		if self.IsChanneling and self.IsChanneling() then
			if self.CanAllowMovement == nil or (not self.CanAllowMovement()) then
				return false
			end
		end
		return true
	end,

	HeroCanAttack = function(self)
		if self.IsChanneling and self.IsChanneling() then
			return false
		end
		if self.CanDisableAttack and self.CanDisableAttack() then
			return false
		end
		if self.CanDisableAttackSpell then
			local spell = myHero.activeSpell
			if spell and spell.valid and self.CanDisableAttackSpell(spell) then
				return false
			end
		end
		if  Buff:HasBuffTypes(myHero, { [32] = true }) or (Buff:HasBuffTypes(myHero, { [26] = true}) and myHero.charName~="Azir") then
			return false
		end
		return true
	end,

	IsMelee = function(self)
		if self.IsHeroMelee or (self.IsHeroSpecialMelee and self.IsHeroSpecialMelee()) then
			return true
		end
		return false
	end,

	GetHeroPriority = function(self, name)
		local p = self.HEROES[name]
		return p and p[1] or 5
	end,

	GetHeroData = function(self, obj)
		if obj == nil then
			return {}
		end
		local id = obj.networkID
		if id == nil or id <= 0 then
			return {}
		end
		local name = obj.charName
		if name == nil then
			return {}
		end
		if self.HEROES[name] == nil and not name:lower():find("dummy") then
			return {}
		end
		local Team = obj.team
		local IsEnemy = obj.isEnemy
		local IsAlly = obj.isAlly
		if Team == nil or Team < 100 or Team > 200 or IsEnemy == nil or IsAlly == nil or IsEnemy == IsAlly then
			return {}
		end
		return {
			valid = true,
			isEnemy = IsEnemy,
			isAlly = IsAlly,
			networkID = id,
			charName = name,
			team = Team,
			unit = obj,
		}
	end,

	GetTotalShield = function(self, obj)
		local shieldAd, shieldAp
		shieldAd = obj.shieldAD
		shieldAp = obj.shieldAP
		return (shieldAd and shieldAd or 0) + (shieldAp and shieldAp or 0)
	end,

	GetBuildingBBox = function(self, unit)
		local type = unit.type
		if type == Obj_AI_Barracks then
			return 270
		end
		if type == Obj_AI_Nexus then
			return 380
		end
		return 0
	end,

	Stop = function(self)
		return GameIsChatOpen()
			or (ExtLibEvade and ExtLibEvade.Evading)
			or (JustEvade and JustEvade.Evading())
			or (not GameIsOnTop())
	end,
}

Data.IsChanneling = Data.ChannelingBuffs[Data.HeroName]
Data.CanAllowMovement = Data.AllowMovement[Data.HeroName]
Data.CanDisableAttackSpell = Data.DisableAttackSpells[Data.HeroName]
Data.CanDisableAttack = Data.DisableAttackBuffs[Data.HeroName]
Data.SpecialMissileSpeed = Data.SpecialMissileSpeeds[Data.HeroName]
Data.IsHeroMelee = Data.HEROES[Data.HeroName][2]
Data.IsHeroSpecialMelee = Data.HeroSpecialMelees[Data.HeroName]
Data.ExtraAttackRange = Data.ExtraAttackRanges[Data.HeroName]
Data.AttackReset = Data.AttackResets[Data.HeroName]
if Data.AttackReset ~= nil then
	Data.AttackResetSuccess = false
	Data.AttackResetSlot = Data.AttackReset.Slot
	Data.AttackResetBuff = Data.AttackReset.Buff
	Data.AttackResetOnCast = Data.AttackReset.OnCast
	Data.AttackResetCanCancel = Data.AttackReset.CanCancel
	Data.AttackResetTimer = 0
	Data.AttackResetTimeout = 0
end

Spell = {

	QTimer = 0,
	WTimer = 0,
	ETimer = 0,
	RTimer = 0,
	QkTimer = 0,
	WkTimer = 0,
	EkTimer = 0,
	RkTimer = 0,
	OnSpellCastCb = {},
	ControlKeyDown = _G.Control.KeyDown,

	OnSpellCast = function(self, cb)
		table_insert(self.OnSpellCastCb, cb)
	end,

	WndMsg = function(self, msg, wParam)
		local timer = GameTimer()
		if wParam == HK_Q then
			if timer > self.QkTimer + 0.5 and GameCanUseSpell(_Q) == 0 then
				self.QkTimer = timer
			end
			return
		end
		if wParam == HK_W then
			if timer > self.WkTimer + 0.5 and GameCanUseSpell(_W) == 0 then
				self.WkTimer = timer
			end
			return
		end
		if wParam == HK_E then
			if timer > self.EkTimer + 0.5 and GameCanUseSpell(_E) == 0 then
				self.EkTimer = timer
			end
			return
		end
		if wParam == HK_R then
			if timer > self.RkTimer + 0.5 and GameCanUseSpell(_R) == 0 then
				self.RkTimer = timer
			end
			return
		end
	end,

	IsReady = function(self, spell, delays)
		if Cursor.Step > 0 then
			return false
		end
		if not self:CanTakeAction(delays) then
			return false
		end
		return GameCanUseSpell(spell) == 0
	end,

	CanTakeAction = function(self, delays)
		if delays == nil then
			return true
		end
		local t = GameTimer()
		local q = t - delays.q
		local w = t - delays.w
		local e = t - delays.e
		local r = t - delays.r
		if q < self.QkTimer or q < self.QTimer then
			return false
		end
		if w < self.WkTimer or w < self.WTimer then
			return false
		end
		if e < self.EkTimer or e < self.ETimer then
			return false
		end
		if r < self.RkTimer or r < self.RTimer then
			return false
		end
		return true
	end,

	SpellClear = function(self, spell, spelldata, isReady, canLastHit, canLaneClear, getDamage)
		local hk
		if spell == _Q then
			hk = HK_Q
		elseif spell == _W then
			hk = HK_W
		elseif spell == _E then
			hk = HK_E
		elseif spell == _R then
			hk = HK_R
		end
		Health:AddSpell({
			HK = hk,
			spell = spell,
			isReady = isReady,
			canLastHit = canLastHit,
			canLaneClear = canLaneClear,
			getDamage = getDamage,
			SpellPrediction = spelldata,
			Radius = spelldata.Radius,
			Delay = spelldata.Delay,
			Speed = spelldata.Speed,
			Range = spelldata.Range,
			ShouldWaitTime = 0,
			IsLastHitable = false,
			LastHitHandle = 0,
			LaneClearHandle = 0,
			FarmMinions = {},

		GetLastHitTargets = function(self)
			local result = {}
			local farmMinions = self.FarmMinions
			local lastHitHandle = Health.LastHitHandle
			for i = 1, #farmMinions do
				local minion = farmMinions[i]
				if minion.LastHitable then
					local unit = minion.Minion
					if unit.handle ~= lastHitHandle then
						table_insert(result, unit)
					end
				end
			end
			return result
		end,

		GetLaneClearTargets = function(self)
			local result = {}
			local farmMinions = self.FarmMinions
			local laneClearHandle = Health.LaneClearHandle
			for i = 1, #farmMinions do
				local minion = farmMinions[i]
				local unit = minion.Minion
				if unit.handle ~= laneClearHandle then
					table_insert(result, unit)
				end
			end
			return result
		end,

			ShouldWait = function(self)
				-- Convertir a milisegundos para consistencia con Health:ShouldWait
				return GetTickCount() < self.ShouldWaitTime + 1000
			end,

			SetLastHitable = function(self, target, time, damage)
				local hpPred = Health:GetPrediction(target, time)
				local lastHitable = false
				local almostLastHitable = false
				if hpPred <= damage then
					lastHitable = true
					self.IsLastHitable = true
				elseif Health:GetPrediction(target, myHero:GetSpellData(self.spell).cd + (time * 3)) <= damage then
					almostLastHitable = true
					-- Usar GetTickCount() para consistencia con ShouldWait en Health
					self.ShouldWaitTime = GetTickCount()
				end
				return {
					LastHitable = lastHitable,
					Unkillable = hpPred < 0,
					Time = time,
					AlmostLastHitable = almostLastHitable,
					PredictedHP = hpPred,
					Minion = target,
				}
			end,

			Reset = function(self)
				for i = 1, #self.FarmMinions do
					table_remove(self.FarmMinions, i)
				end
				self.IsLastHitable = false
				self.LastHitHandle = 0
				self.LaneClearHandle = 0
			end,

			Tick = function(self)
				if Cursor.Step > 0 or Orbwalker:IsAutoAttacking() or not self.isReady() then
					return
				end
				local isLastHit = self.canLastHit()
					and (Orbwalker.Modes[ORBWALKER_MODE_LASTHIT] or Orbwalker.Modes[ORBWALKER_MODE_LANECLEAR])
				local isLaneClear = self.canLaneClear() and Orbwalker.Modes[ORBWALKER_MODE_LANECLEAR]
				if not isLastHit and not isLaneClear then
					return
				end
				if myHero:GetSpellData(self.spell).level == 0 then
					return
				end
				if myHero.mana < myHero:GetSpellData(self.spell).mana then
					return
				end
				if GameCanUseSpell(self.spell) ~= 0 and myHero:GetSpellData(self.spell).currentCd > 0.5 then
					return
				end
				local targets = Object:GetEnemyMinions(self.Range, false, false)
				for i = 1, #targets do
					local target = targets[i]
					table_insert(
						self.FarmMinions,
						self:SetLastHitable(
							target,
							self.Delay + target.distance / self.Speed + Data:GetLatency(),
							self.getDamage()
						)
					)
				end
				if self.IsLastHitable and (isLastHit or isLaneClear) then
					local targets = self:GetLastHitTargets()
					for i = 1, #targets do
						local unit = targets[i]
						if unit.alive then
							--self.SpellPrediction:GetPrediction(unit, myHero)
							if Control.CastSpell(self.HK, unit.pos) then
								--if self.SpellPrediction:CanHit() and Control.CastSpell(self.HK, self.SpellPrediction.CastPosition) then
								self.LastHitHandle = unit.handle
								Orbwalker:SetAttack(false)
								Action:Add(function()
									Orbwalker:SetAttack(true)
								end, self.Delay + (unit.distance / self.Speed) + 0.05, 0)
								break
							end
						end
					end
				end
				if isLaneClear and self.LastHitHandle == 0 and not self:ShouldWait() then
					local targets = self:GetLaneClearTargets()
					for i = 1, #targets do
						local unit = targets[i]
						if unit.alive then
							--self.SpellPrediction:GetPrediction(unit, myHero)
							if Control.CastSpell(self.HK, unit.pos) then
								--if self.SpellPrediction:CanHit() and Control.CastSpell(self.HK, self.SpellPrediction.CastPosition) then
								self.LaneClearHandle = unit.handle
							end
						end
					end
				end
				local targets = self.FarmMinions
				for i = 1, #targets do
					local minion = targets[i]
					if minion.LastHitable then
						Draw.Circle(minion.Minion.pos, 50, 1, Color.drawcolor1)
					elseif minion.AlmostLastHitable then
						Draw.Circle(minion.Minion.pos, 50, 1,  Color.drawcolor2)
					end
				end
			end,
		})
	end,
}

_G.Control.KeyDown = function(key)
	if key == HK_Q then
		local timer = GameTimer()
		if timer > Spell.QTimer + 0.5 and GameCanUseSpell(_Q) == 0 then
			Spell.QTimer = timer
			for i = 1, #Spell.OnSpellCastCb do
				Spell.OnSpellCastCb[i](_Q)
			end
		end
	end
	if key == HK_W then
		local timer = GameTimer()
		if timer > Spell.WTimer + 0.5 and GameCanUseSpell(_W) == 0 then
			Spell.WTimer = timer
			for i = 1, #Spell.OnSpellCastCb do
				Spell.OnSpellCastCb[i](_W)
			end
		end
	end
	if key == HK_E then
		local timer = GameTimer()
		if timer > Spell.ETimer + 0.5 and GameCanUseSpell(_E) == 0 then
			Spell.ETimer = timer
			for i = 1, #Spell.OnSpellCastCb do
				Spell.OnSpellCastCb[i](_E)
			end
		end
	end
	if key == HK_R then
		local timer = GameTimer()
		if timer > Spell.RTimer + 0.5 and GameCanUseSpell(_R) == 0 then
			Spell.RTimer = timer
			for i = 1, #Spell.OnSpellCastCb do
				Spell.OnSpellCastCb[i](_R)
			end
		end
	end
--	print(key..Game.Timer())
	Spell.ControlKeyDown(key)
end

SummonerSpell = {

	SpellNames = {
		"SummonerHeal", --1 heal
		"SummonerHaste", --2 ghost
		"SummonerBarrier", --3 barrier
		"SummonerExhaust", --4 exhaust
		"SummonerFlash", --5 flash
		"SummonerTeleport", --6 teleport
		"SummonerSmite", --7 smite
		"SummonerBoost", --8 cleanse
		"SummonerDot", --9 ignite
	},

	Spell = {
		{
			Id = 0,
			Ready = false,
		},
		{
			Id = 0,
			Ready = false,
		},
	},

	CleanseStartTime = GetTickCount(),

	OnTick = function(self)
		-- SummonerSpells functionality removed
		return
	end,
}

-- SummonerSpells functionality removed

Item = {

	ItemQss = { 6035, 3139, 3140 },
	CachedItems = {},
	Hotkey = nil,
	CleanseStartTime = GetTickCount(),

	OnTick = function(self)
		-- Items functionality removed
		return
	end,

	GetItemById = function(self, unit, id)
		local networkID = unit.networkID
		if self.CachedItems[networkID] == nil then
			local t = {}
			for i = 1, #ItemSlots do
				local slot = ItemSlots[i]
				local item = unit:GetItemData(slot)
				if item ~= nil and item.itemID ~= nil and item.itemID > 0 then
					t[item.itemID] = i
				end
			end
			self.CachedItems[networkID] = t
		end
		return self.CachedItems[networkID][id]
	end,

	IsReady = function(self, unit, id)
		local item = self:GetItemById(unit, id)
		if item and myHero:GetSpellData(ItemSlots[item]).currentCd == 0 then
			self.Hotkey = ItemKeys[item]
			return true
		end
		return false
	end,

	HasItem = function(self, unit, id)
		return self:GetItemById(unit, id) ~= nil
	end,
}

-- Items functionality removed

Object = {

	UndyingBuffs = {
		--["zhonyasringshield"] = true,
		["kindredrnodeathbuff"] = true,
		["ChronoShift"] = true,
		["UndyingRage"] = true,
		["JaxE"] = true,
	},

	AllyBuildings = {},
	EnemyBuildings = {},
	AllyHeroesInGame = {},
	EnemyHeroesInGame = {},
	EnemyHeroCb = {},
	AllyHeroCb = {},
	CachedHeroes = {},
	CachedMinions = {},
	CachedTurrets = {},
	CachedWards = {},
	IsAzir = myHero.charName == "Azir",
	IsAphelios = myHero.charName == "Aphelios",
	IsKalista = myHero.charName == "Kalista",
	IsCaitlyn = myHero.charName == "Caitlyn",
	IsRiven = myHero.charName == "Riven",
	IsKindred = myHero.charName == "Kindred",
	IsNasus = myHero.charName == "Nasus",
	OnLoad = function(self)
		for i = 1, GameObjectCount() do

			local object = GameObject(i)
			if object and (object.type == Obj_AI_Barracks or object.type == Obj_AI_Nexus) then
				if object.isEnemy then
					table_insert(self.EnemyBuildings, object)
				elseif object.isAlly then
					table_insert(self.AllyBuildings, object)
				end
			end
		end
		Action:Add(function()
			local success = 0
			local allyHeroesInGame = self.AllyHeroesInGame
			local enemyHeroesInGame = self.EnemyHeroesInGame
			local allyHeroCb = self.AllyHeroCb
			local enemyHeroCb = self.EnemyHeroCb
			for i = 1, GameHeroCount() do
				local args = Data:GetHeroData(GameHero(i))
				if args.valid and args.isAlly and allyHeroesInGame[args.networkID] == nil then
					allyHeroesInGame[args.networkID] = true
					for j = 1, #allyHeroCb do
						allyHeroCb[j](args)
					end
				end
				if args.valid and args.isEnemy then
					if enemyHeroesInGame[args.networkID] == nil then
						enemyHeroesInGame[args.networkID] = true
						for j = 1, #enemyHeroCb do
							enemyHeroCb[j](args)
						end
					end
					success = success + 1
				end
			end
			return success >= 5
		end, 1, 100)
	end,

	OnAllyHeroLoad = function(self, cb)
		table_insert(self.AllyHeroCb, cb)
	end,

	OnEnemyHeroLoad = function(self, cb)
		table_insert(self.EnemyHeroCb, cb)
	end,

	IsFacing = function(self, source, target, angle)
		return IsFacing(source, target, angle)
	end,

	IsValid = function(self, unit)
		return unit and unit.valid and unit.visible and unit.isTargetable and not unit.dead
	end,

	IsHeroImmortal = function(self, unit, isAttack)
		local hp
		hp = 100 * (unit.health / unit.maxHealth)
		self.UndyingBuffs["kindredrnodeathbuff"] = hp <= 10.1
		self.UndyingBuffs["ChronoShift"] = hp < 15
		self.UndyingBuffs["chronorevive"] = hp < 15
		self.UndyingBuffs["UndyingRage"] = hp < 15
	self.UndyingBuffs["JaxE"] = isAttack
	self.UndyingBuffs["ShenWBuff"] = isAttack
	local undyingBuffs = self.UndyingBuffs
	for buffName, isActive in pairs(undyingBuffs) do
		if isActive and Buff:HasBuff(unit, buffName) then
			local bufff = Buff:GetBuff(unit, buffName)
			if isAttack then
				if myHero.charName == "Azir" then
					return false
				end
				if bufff.duration >= myHero.attackData.windUpTime + (unit.distance/Attack:GetProjectileSpeed())+Data:GetLatency()/2 then
					return true
				end
			else
				return true
			end
		end
	end
		-- anivia passive, olaf R, ... if unit.isImmortal and not Buff:HasBuff(unit, 'willrevive') and not Buff:HasBuff(unit, 'zacrebirthready') then return true end
		return false
	end,

	GetHeroes = function(self, range, bbox, immortal, isAttack)
		local result = {}
		local a = self:GetEnemyHeroes(range, bbox, immortal, isAttack)
		local b = self:GetAllyHeroes(range, bbox, immortal, isAttack)
		for i = 1, #a do
			table_insert(result, a[i])
		end
		for i = 1, #b do
			table_insert(result, b[i])
		end
		return result
	end,

	GetEnemyHeroes = function(self, range, bbox, immortal, isAttack)
		local result = {}
		local cachedHeroes = Cached:GetHeroes()
		for i = 1, #cachedHeroes do
			local hero = cachedHeroes[i]
			if hero.isEnemy and self:IsValid(hero) and ((not immortal or not self:IsHeroImmortal(hero, isAttack)) or (Object.IsKindred and Orbwalker:KindredETarget(hero))) then
				if not range or hero.distance < range + (bbox and hero.boundingRadius or 0) then
					table_insert(result, hero)
				end
			end
		end
		return result
	end,

	GetAllyHeroes = function(self, range, bbox, immortal, isAttack)
		local result = {}
		local cachedHeroes = Cached:GetHeroes()
		for i = 1, #cachedHeroes do
			local hero = cachedHeroes[i]
			if hero.isAlly and self:IsValid(hero) and (not immortal or not self:IsHeroImmortal(hero, isAttack)) then
				if not range or hero.distance < range + (bbox and hero.boundingRadius or 0) then
					table_insert(result, hero)
				end
			end
		end
		return result
	end,

	GetMinions = function(self, range, bbox, immortal)
		local result = {}
		local a = self:GetEnemyMinions(range, bbox, immortal)
		local b = self:GetAllyMinions(range, bbox, immortal)
		for i = 1, #a do
			table_insert(result, a[i])
		end
		for i = 1, #b do
			table_insert(result, b[i])
		end
		return result
	end,

	GetEnemyMinions = function(self, range, bbox, immortal)
		local result = {}
		-- Para detección de colisiones, necesitamos todos los minions, no solo los cercanos
		-- Si el rango es muy grande (como para detección de colisiones), usar caché completo
		local cachedminions = Cached:GetMinions()
		-- Si no hay suficientes minions en el caché o el rango es muy grande, buscar directamente
		if range and range > 1500 then
			-- Rango grande sugiere detección de colisiones, buscar todos los minions enemigos
			local count = GameMinionCount()
			if count and count > 0 then
				local myPos = myHero.pos
				local rangeSq = range and (range + (bbox and 100 or 0)) * (range + (bbox and 100 or 0)) or nil  -- Aproximación para evitar calcular boundingRadius en cada iteración
				for i = 1, count do
					local obj = GameMinion(i)
					if obj and obj.valid and obj.visible and obj.isTargetable and not obj.dead and obj.isEnemy then
						if not immortal or not obj.isImmortal then
							-- Verificar rango dinámicamente usando GetDistanceSq (más rápido)
							if not range then
								table_insert(result, obj)
							else
								local objRadius = bbox and obj.boundingRadius or 0
								local totalRangeSq = (range + objRadius) * (range + objRadius)
								if GetDistanceSq(myPos, obj.pos) <= totalRangeSq then
									table_insert(result, obj)
								end
							end
						end
					end
				end
			end
		else
			-- Para rangos pequeños, usar el caché (más eficiente)
			local myPos = myHero.pos
			for i = 1, #cachedminions do
				local obj = cachedminions[i]
				if obj and obj.isEnemy and (not immortal or not obj.isImmortal) then
					if not range then
						table_insert(result, obj)
					else
						-- Usar GetDistanceSq para comparaciones más rápidas
						local objRadius = bbox and obj.boundingRadius or 0
						local totalRangeSq = (range + objRadius) * (range + objRadius)
						local objDistanceSq = obj.distance and (obj.distance * obj.distance) or GetDistanceSq(myPos, obj.pos)
						if objDistanceSq <= totalRangeSq then
							table_insert(result, obj)
						end
					end
				end
			end
		end
		return result
	end,

	GetMonsters = function(self, range, bbox, immortal)
		local result = {}
		local cachedminions = Cached:GetMinions()
		for i = 1, #cachedminions do
			local obj = cachedminions[i]
			if obj.isEnemy and obj.team == 300 and (not immortal or not obj.isImmortal) then
				if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetAllyMinions = function(self, range, bbox, immortal)
		local result = {}
		local cachedminions = Cached:GetMinions()
		for i = 1, #cachedminions do
			local obj = cachedminions[i]
			if obj.isAlly and obj.team < 300 and (not immortal or not obj.isImmortal) then
				if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetOtherMinions = function(self, range, bbox, immortal)
		local result = {}
		local a = self:GetOtherAllyMinions(range, bbox, immortal)
		local b = self:GetOtherEnemyMinions(range, bbox, immortal)
		for i = 1, #a do
			table_insert(result, a[i])
		end
		for i = 1, #b do
			table_insert(result, b[i])
		end
		return result
	end,

	GetOtherAllyMinions = function(self, range)
		local result = {}
		local cachedwards = Cached:GetWards()
		for i = 1, #cachedwards do
			local obj = cachedwards[i]
			if obj.isAlly and (not range or obj.distance < range) then
				table_insert(result, obj)
			end
		end
		return result
	end,

	GetOtherEnemyMinions = function(self, range)
		local result = {}
		local cachedwards = Cached:GetWards()
		for i = 1, #cachedwards do
			local obj = cachedwards[i]
			if obj.isEnemy and (not range or obj.distance < range) then
				table_insert(result, obj)
			end
		end
		return result
	end,

	GetPlants = function(self, range)
		local result = {}
		local cachedplants = Cached:GetPlants()
		for i = 1, #cachedplants do
			local obj = cachedplants[i]
			if not range or obj.distance < range then
				table_insert(result, obj)
			end
		end
		return result
	end,

	GetTurrets = function(self, range, bbox, immortal)
		local result = {}
		local a = self:GetEnemyTurrets(range, bbox, immortal)
		local b = self:GetAllyTurrets(range, bbox, immortal)
		for i = 1, #a do
			table_insert(result, a[i])
		end
		for i = 1, #b do
			table_insert(result, b[i])
		end
		return result
	end,

	GetEnemyTurrets = function(self, range, bbox, immortal)
		local result = {}
		local cachedturrets = Cached:GetTurrets()
		for i = 1, #cachedturrets do
			local obj = cachedturrets[i]
			if obj.isEnemy and (not immortal or not obj.isImmortal) then
				if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetAllyTurrets = function(self, range, bbox, immortal)
		local result = {}
		local cachedturrets = Cached:GetTurrets()
		for i = 1, #cachedturrets do
			local obj = cachedturrets[i]
			if obj.isAlly then
				if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetEnemyBuildings = function(self, range, bbox)
		local result = {}
		for i = 1, #self.EnemyBuildings do
			local obj = self.EnemyBuildings[i]
			if obj and obj.valid and obj.visible and obj.isTargetable and not obj.dead and not obj.isImmortal then
				if not range or obj.distance < range + (bbox and Data:GetBuildingBBox(obj) or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetAllyBuildings = function(self, range, bbox)
		local result = {}
		for i = 1, #self.AllyBuildings do
			local obj = self.AllyBuildings[i]
			if obj and obj.valid and obj.visible and obj.isTargetable and not obj.dead and not obj.isImmortal then
				if not range or obj.distance < range + (bbox and Data:GetBuildingBBox(obj) or 0) then
					table_insert(result, obj)
				end
			end
		end
		return result
	end,

	GetAllStructures = function(self, range, bbox)
		local result = {}
		for i = 1, #self.AllyBuildings do
			local obj = self.AllyBuildings[i]
			if obj and obj.valid and obj.visible and obj.isTargetable and not obj.dead and not obj.isImmortal then
				if not range or obj.distance < range + (bbox and Data:GetBuildingBBox(obj) or 0) then
					table_insert(result, obj)
				end
			end
		end
		for i = 1, #self.EnemyBuildings do
			local obj = self.EnemyBuildings[i]
			if obj and obj.valid and obj.visible and obj.isTargetable and not obj.dead and not obj.isImmortal then
				if not range or obj.distance < range + (bbox and Data:GetBuildingBBox(obj) or 0) then
					table_insert(result, obj)
				end
			end
		end
		local cachedturrets = Cached:GetTurrets()
		for i = 1, #cachedturrets do
			local obj = cachedturrets[i]
			if not range or obj.distance < range + (bbox and obj.boundingRadius or 0) then
				table_insert(result, obj)
			end
		end
		return result
	end,
}

Object:OnEnemyHeroLoad(function(args)
	if args.charName == "Mel" then
		Object.UndyingBuffs["MelWReflect"] = true
		return
	end
	if args.charName == "Kayle" then
		Object.UndyingBuffs["KayleR"] = true
		return
	end
	if args.charName == "Taric" then
		Object.UndyingBuffs["TaricR"] = true
		return
	end
	if args.charName == "Kindred" then
		Object.UndyingBuffs["kindredrnodeathbuff"] = true
		return
	end
	if args.charName == "Zilean" then
		Object.UndyingBuffs["ChronoShift"] = true
		Object.UndyingBuffs["chronorevive"] = true
		return
	end
	if args.charName == "Tryndamere" then
		Object.UndyingBuffs["UndyingRage"] = true
		return
	end
	if args.charName == "Jax" then
		Object.UndyingBuffs["JaxE"] = true
		return
	end
	if args.charName == "Fiora" then
		Object.UndyingBuffs["FioraW"] = true
		return
	end
	if args.charName == "Aatrox" then
		Object.UndyingBuffs["aatroxpassivedeath"] = true
		return
	end
	if args.charName == "Vladimir" then
		Object.UndyingBuffs["VladimirSanguinePool"] = true
		return
	end
	if args.charName == "KogMaw" then
		Object.UndyingBuffs["KogMawIcathianSurprise"] = true
		return
	end
	if args.charName == "Karthus" then
		Object.UndyingBuffs["KarthusDeathDefiedBuff"] = true
		return
	end
	if args.charName == "Shen" then
		Object.UndyingBuffs["ShenWBuff"] = true
		return
	end
	if args.charName == "Samira" then
		Object.UndyingBuffs["SamiraW"] = true
		return
	end
end)

Target = {

	SelectionTick = 0,
	Selected = nil,
	CurrentSort = nil,
	CurrentSortMode = 0,
	CurrentDamage = nil,
--	lastNetProc=0,
--	lastCaitWProc=0,
	--lastCaitWEnemy=nil,
	ActiveStackBuffs = { "BraumMark" },

	StackBuffs = {
		["Vayne"] = { "VayneSilverDebuff" },
		["TahmKench"] = { "tahmkenchpdebuffcounter" },
		["Kennen"] = { "kennenmarkofstorm" },
		["Darius"] = { "DariusHemo" },
		["Ekko"] = { "EkkoStacks" },
		["Gnar"] = { "GnarWProc" },
		["Kalista"] = { "KalistaExpungeMarker" },
		["Kindred"] = { "KindredHitCharge", "kindredecharge" },
		["Tristana"] = { "tristanaecharge" },
		["Twitch"] = { "TwitchDeadlyVenom" },
		["Varus"] = { "VarusWDebuff" },
		["Velkoz"] = { "VelkozResearchStack" },
		["Vi"] = { "ViWProc" },
	},

	MenuAARange = Menu.Orbwalker.General.AttackRange,
	MenuPriorities = Menu.Target.Priorities,
	MenuDrawSelected = Menu.Main.Drawings.SelectedTarget,
	MenuTableSortMode = Menu.Target["SortMode" .. myHero.charName],
	MenuCheckSelected = Menu.Target.SelectedTarget,
	MenuCheckSelectedOnly = Menu.Target.OnlySelectedTarget,

	WndMsg = function(self, msg, wParam)
		if msg == WM_LBUTTONDOWN and self.MenuCheckSelected:Value() and GetTickCount() > self.SelectionTick + 100 then
			self.Selected = nil
			local maxRangeSq = 150 * 150  -- Pre-calcular rango máximo al cuadrado
			local numSq = maxRangeSq
			local pos = Vector(mousePos)
			local enemies = Object:GetEnemyHeroes()
			for i = 1, #enemies do
				local enemy = enemies[i]
				if enemy.pos:ToScreen().onScreen then
					local distanceSq = GetDistanceSq(pos, enemy.pos)
					if distanceSq <= maxRangeSq and distanceSq < numSq then
						self.Selected = enemy
						numSq = distanceSq
					end
				end
			end
			self.SelectionTick = GetTickCount()
		end
	end,

	OnDraw = function(self)
		-- OPTIMIZACIÓN: Early exits
		if not self.MenuDrawSelected:Value() then
			return
		end
		
		local selected = self.Selected
		if not selected then
			return
		end
		
		if not Object:IsValid(selected) then
			return
		end
		
		-- OPTIMIZACIÓN: Screen check para evitar dibujar fuera de pantalla
		local pos = selected.pos
		if pos then
			local pos2D = pos:To2D()
			if pos2D.onScreen then
				Draw.Circle(pos, 150, 1, Color.DarkRed)
			end
		end
	end,

	OnTick = function(self)
		local sortMode = self.MenuTableSortMode:Value()
		if sortMode ~= self.CurrentSortMode then
			self.CurrentSortMode = sortMode
			self.CurrentSort = self.SortModes[sortMode]
		end
	end,

	GetTarget = function(self, a, dmgType, isAttack)
		a = a or 20000
		dmgType = dmgType or 1
		self.CurrentDamage = dmgType
		if
			self.MenuCheckSelected:Value()
			and Object:IsValid(self.Selected)
			and ChampionInfo:CustomIsTargetable(self.Selected)
			and (Object:IsHeroImmortal(self.Selected, isAttack)==false or (Object.IsKindred and Orbwalker:KindredETarget(self.Selected)))
		then
			if type(a) == "number" then
				if self.Selected.distance < a then
					return self.Selected
				end
			else
				local ok
				for i = 1, #a do
					if a[i].networkID == self.Selected.networkID then
						ok = true
						break
					end
				end
				if ok then
					return self.Selected
				end
			end
			if self.MenuCheckSelectedOnly:Value() then
				return nil
			end
		end
		if type(a) == "number" then
			a = Object:GetEnemyHeroes(a, false, true, isAttack)
		end
		for i = #a, 1, -1 do
			if not ChampionInfo:CustomIsTargetable(a[i]) then
				table_remove(a, i)
			end
		end
		if self.CurrentSortMode == SORT_MOST_STACK then
			local stackA = {}
			for i = 1, #a do
				local obj = a[i]
				for j = 1, #self.ActiveStackBuffs do
					if Buff:HasBuff(obj, self.ActiveStackBuffs[j]) then
						table_insert(stackA, obj)
					end
				end
			end
			local sortMode = (#stackA == 0 and SORT_AUTO or SORT_MOST_STACK)
			if sortMode == SORT_MOST_STACK then
				a = stackA
			end
			local cmp = self.SortModes[sortMode]
			if type(cmp) ~= "function" then
				cmp = self.SortModes[SORT_AUTO]
			end
			if type(cmp) ~= "function" then
				cmp = function(a, b) return a.distance < b.distance end
			end
			table_sort(a, cmp)
		else
			local cmp = self.CurrentSort
			if type(cmp) ~= "function" then
				cmp = self.SortModes[SORT_AUTO]
			end
			if type(cmp) ~= "function" then
				cmp = function(a, b) return a.distance < b.distance end
			end
			table_sort(a, cmp)
		end
		return (#a == 0 and nil or a[1])
	end,

	GetTargets = function(self, a, dmgType, isAttack)
		a = a or 20000
		dmgType = dmgType or 1
		self.CurrentDamage = dmgType
		if
			self.MenuCheckSelected:Value()
			and Object:IsValid(self.Selected)
			and ChampionInfo:CustomIsTargetable(self.Selected)
			and (Object:IsHeroImmortal(self.Selected, isAttack)==false or (Object.IsKindred and Orbwalker:KindredETarget(self.Selected)))
		then
			if type(a) == "number" then
				if self.Selected.distance < a then
					return {self.Selected}
				end
			else
				local ok
				for i = 1, #a do
					if a[i].networkID == self.Selected.networkID then
						ok = true
						break
					end
				end
				if ok then
					return {self.Selected}
				end
			end
			if self.MenuCheckSelectedOnly:Value() then
				return nil
			end
		end
		if type(a) == "number" then
			a = Object:GetEnemyHeroes(a, false, true, isAttack)
		end
		for i = #a, 1, -1 do
			if not ChampionInfo:CustomIsTargetable(a[i]) then
				table_remove(a, i)
			end
		end
		if self.CurrentSortMode == SORT_MOST_STACK then
			local stackA = {}
			for i = 1, #a do
				local obj = a[i]
				for j = 1, #self.ActiveStackBuffs do
					if Buff:HasBuff(obj, self.ActiveStackBuffs[j]) then
						table_insert(stackA, obj)
					end
				end
			end
			local sortMode = (#stackA == 0 and SORT_AUTO or SORT_MOST_STACK)
			if sortMode == SORT_MOST_STACK then
				a = stackA
			end
			table_sort(a, self.SortModes[sortMode])
		else
			table_sort(a, self.CurrentSort)
		end
		return (#a == 0 and nil or a)
	end,

	GetPriority = function(self, unit)
		local name = unit.charName
		if self.MenuPriorities[name] then
			return self.MenuPriorities[name]:Value()
		end
		if Data.HEROES[name] then
			return Data.HEROES[name][1]
		end
		return 1
	end,

	GetComboTarget = function(self, dmgType)
		dmgType = dmgType or DAMAGE_TYPE_PHYSICAL
		local menuRange = self.MenuAARange:Value()
		local attackRange = myHero.range + myHero.boundingRadius - menuRange
		local enemies = Object:GetEnemyHeroes(false, false, true, true)
		local enemiesaa = {}
		for i = 1, #enemies do
			local enemy = enemies[i]
			--print(myHero.range)
			local extraRange = enemy.boundingRadius
			if	Object.IsCaitlyn then		
				if _G.CTRLCait==nil	and (
						Buff:GetBuffDuration(enemy, "caitlynwsight") > 0.75
						or Buff:HasBuff(enemy, "eternals_caitlyneheadshottracker")
					)
				then
					--	print(Game.Timer())
					--	print(Buff:GetBuffDuration(enemy, "caitlynwsight"), Buff:HasBuff(enemy, "eternals_caitlyneheadshottracker"))
					extraRange = extraRange + 425
				end

				if _G.CTRLCait~=nil then
					if Buff:HasBuff(enemy, "eternals_caitlyneheadshottracker") and _G.lastEProc+3<Game.Timer() then
						extraRange = extraRange + 425
					elseif Buff:GetBuffDuration(enemy, "caitlynwsight") > 0.75 and (_G.lastWProc[enemy.networkID]==nil or _G.lastWProc[enemy.networkID]+3<Game.Timer()) then
						extraRange = extraRange + 425
					end
				end
			end
			if Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(enemy) then
				table_insert(enemiesaa, enemy)
			elseif enemy.distance < attackRange + extraRange then
				table_insert(enemiesaa, enemy)
			end
			if Menu.Orbwalker.General.AttackBarrel:Value() and enemy.charName == "Gangplank" then
				local validBarrels = {}
				for _, obj in ipairs(Cached:GetPlants()) do
					if obj and obj.charName:lower() == "gangplankbarrel" then
						table.insert(validBarrels, obj)
					end
				end
				for _, barrel in ipairs(validBarrels) do
					if barrel then
						if barrel.health <= 1 and barrel.distance <= attackRange + barrel.boundingRadius then
							return barrel
						end
						local time = Attack:GetWindup() + (barrel.distance - myHero.boundingRadius - barrel.boundingRadius) / Attack:GetProjectileSpeed() + Data:GetLatency() / 2
						local barrelBuffStartTime = Buff:GetBuffStartTime(barrel, "gangplankebarrelactive")
						if barrel.health <= 2 then
							local healthDecayRate = enemy.levelData.lvl >= 13 and 0.5 or (enemy.levelData.lvl >= 7 and 1 or 2)
							local nextHealthDecayTime = Game.Timer() < barrelBuffStartTime + healthDecayRate and barrelBuffStartTime + healthDecayRate or barrelBuffStartTime + healthDecayRate * 2
							if nextHealthDecayTime <= Game.Timer() + time and barrel.distance <= attackRange + barrel.boundingRadius then
								return barrel
							end
						end
					end
				end
			end
		end
		return self:GetTarget(enemiesaa, dmgType, true)
	end,
}

-- stylua: ignore start
Object:OnEnemyHeroLoad(function(args)
    local priority = Data:GetHeroPriority(args.charName) or 1
    Target.MenuPriorities:MenuElement({id = args.charName, name = args.charName, value = priority, min = 1, max = 5, step = 1})
end)
-- stylua: ignore end

if Target.StackBuffs[myHero.charName] then
	for i, buffName in pairs(Target.StackBuffs[myHero.charName]) do
		table_insert(Target.ActiveStackBuffs, buffName)
	end
end

Target.SortModes = {
	[SORT_AUTO] = function(a, b)
		local mindist= Menu.Target.mindistance:Value()
		local maxdist= Menu.Target.maxdistance:Value()
		local distmultiplier=Menu.Target.distmultiplier:Value()
		local aMultiplier = 1.75 - (Target:GetPriority(a) * 0.15) +(distmultiplier*(math.max(math.min(a.distance,maxdist),mindist)/math.max(math.min(b.distance,maxdist),mindist)))
		local bMultiplier = 1.75 - (Target:GetPriority(b) * 0.15) +(distmultiplier*(math.max(math.min(b.distance,maxdist),mindist)/math.max(math.min(a.distance,maxdist),mindist)))
		
		local aDef, bDef = 0, 0
		if Target.CurrentDamage == DAMAGE_TYPE_MAGICAL then
			local magicPen, magicPenPercent = myHero.magicPen, myHero.magicPenPercent
			aDef = math_max(0, aMultiplier * (a.magicResist - magicPen) * magicPenPercent)
			bDef = math_max(0, bMultiplier * (b.magicResist - magicPen) * magicPenPercent)
		elseif Target.CurrentDamage == DAMAGE_TYPE_PHYSICAL then
			local armorPen, bonusArmorPenPercent = myHero.armorPen, myHero.bonusArmorPenPercent
			aDef = math_max(0, aMultiplier * (a.armor - armorPen) * bonusArmorPenPercent)
			bDef = math_max(0, bMultiplier * (b.armor - armorPen) * bonusArmorPenPercent)
		end
		return (a.health * aMultiplier * ((100 + aDef) / 100)) - a.ap - (a.totalDamage * a.attackSpeed * 2)
			< (b.health * bMultiplier * ((100 + bDef) / 100)) - b.ap - (b.totalDamage * b.attackSpeed * 2)
	end,
	
	

	[SORT_CLOSEST] = function(a, b)
		return a.distance < b.distance
	end,

	[SORT_NEAR_MOUSE] = function(a, b)
		return GetDistance(a.pos, Vector(mousePos)) < GetDistance(b.pos, Vector(mousePos))
	end,

	[SORT_LOWEST_HEALTH] = function(a, b)
		return a.health < b.health
	end,

	[SORT_LOWEST_MAX_HEALTH] = function(a, b)
		return a.maxHealth < b.maxHealth
	end,

	[SORT_HIGHEST_PRIORITY] = function(a, b)
		return Target:GetPriority(a) > Target:GetPriority(b)
	end,

	[SORT_MOST_STACK] = function(a, b)
		local aMax = 0
		for i, buffName in pairs(Target.ActiveStackBuffs) do
			local buff = Buff:GetBuff(a, buffName)
			if buff then
				aMax = math_max(aMax, math_max(buff.Count, buff.Stacks))
			end
		end
		local bMax = 0
		for i, buffName in pairs(Target.ActiveStackBuffs) do
			local buff = Buff:GetBuff(b, buffName)
			if buff then
				bMax = math_max(bMax, math_max(buff.Count, buff.Stacks))
			end
		end
		return aMax > bMax
	end,

	[SORT_MOST_AD] = function(a, b)
		return a.totalDamage > b.totalDamage
	end,

	[SORT_MOST_AP] = function(a, b)
		return a.ap > b.ap
	end,

	[SORT_LESS_CAST] = function(a, b)
		local aMultiplier = 1.75 - Target:GetPriority(a) * 0.15
		local bMultiplier = 1.75 - Target:GetPriority(b) * 0.15
		local aDef, bDef = 0, 0
		local magicPen, magicPenPercent = myHero.magicPen, myHero.magicPenPercent
		aDef = math_max(0, aMultiplier * (a.magicResist - magicPen) * magicPenPercent)
		bDef = math_max(0, bMultiplier * (b.magicResist - magicPen) * magicPenPercent)
		return (a.health * aMultiplier * ((100 + aDef) / 100)) - a.ap - (a.totalDamage * a.attackSpeed * 2)
			< (b.health * bMultiplier * ((100 + bDef) / 100)) - b.ap - (b.totalDamage * b.attackSpeed * 2)
	end,

	[SORT_LESS_ATTACK] = function(a, b)
		local aMultiplier = 1.75 - Target:GetPriority(a) * 0.15
		local bMultiplier = 1.75 - Target:GetPriority(b) * 0.15
		local aDef, bDef = 0, 0
		local armorPen, bonusArmorPenPercent = myHero.armorPen, myHero.bonusArmorPenPercent
		aDef = math_max(0, aMultiplier * (a.armor - armorPen) * bonusArmorPenPercent)
		bDef = math_max(0, bMultiplier * (b.armor - armorPen) * bonusArmorPenPercent)
		return (a.health * aMultiplier * ((100 + aDef) / 100)) - a.ap - (a.totalDamage * a.attackSpeed * 2)
			< (b.health * bMultiplier * ((100 + bDef) / 100)) - b.ap - (b.totalDamage * b.attackSpeed * 2)
	end,

	[SORT_SMART] = function(a, b)
		-- Smart AI: Favor killable enemies within reach. Otherwise prefer closest.
		local params = Target.MenuPriorities -- not used; keep compatibility
		local rangeOffset = Menu.Target.SmartAI.RangeOffset:Value()
		local reach = myHero.range + myHero.boundingRadius + rangeOffset
		local function isKillable(unit)
			if not unit or not unit.valid then return false end
			if unit.distance > reach then return false end
			if Menu.Target.SmartAI.UseDamageCalc:Value() then
				local dmg = Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_PHYSICAL, myHero.totalDamage, false, true)
				return dmg >= unit.health
			else
				local percent = Menu.Target.SmartAI.MinHpPercent:Value() / 100
				return unit.health <= (unit.maxHealth * percent)
			end
		end
		local aKill = isKillable(a)
		local bKill = isKillable(b)
		if aKill and not bKill then
			return true
		elseif not aKill and bKill then
			return false
		elseif aKill and bKill then
			-- Both killable: pick lower health first
			return a.health < b.health
		end
		-- Otherwise, prefer closest
		return a.distance < b.distance
	end,
}

Target.CurrentSortMode = Target.MenuTableSortMode:Value()
Target.CurrentSort = Target.SortModes[Target.CurrentSortMode]

Health = {

	ExtraFarmDelay = Menu.Orbwalker.Farming.ExtraFarmDelay,
	MenuDrawings = Menu.Main.Drawings,
	IsLastHitable = false,
	ShouldRemoveObjects = false,
	ShouldWaitTime = 0,
	OnUnkillableC = {},
	ActiveAttacks = {},
	AllyTurret = nil,
	AllyTurretHandle = nil,
	StaticAutoAttackDamage = nil,
	FarmMinions = {},
	Handles = {},
	AllyMinionsHandles = {},
	EnemyWardsInAttackRange = {},
	EnemyMinionsInAttackRange = {},
	JungleMinionsInAttackRange = {},
	PlantsMinionsInAttackRange = {},
	EnemyStructuresInAttackRange = {},
	CachedWards = {},
	CachedPlants = {},
	CachedMinions = {},
	TargetsHealth = {},
	AttackersDamage = {},
	Spells = {},
	LastHitHandle = 0,
	LaneClearHandle = 0,

	AddSpell = function(self, class)
		table_insert(self.Spells, class)
	end,

	OnTick = function(self)
		local attackRange, structures, pos, speed, windup, time, anim
		-- RESET ALL
		if self.ShouldRemoveObjects then
			self.ShouldRemoveObjects = false
			self.AllyTurret = nil
			self.AllyTurretHandle = nil
			self.StaticAutoAttackDamage = nil
			self.FarmMinions = {}
			self.EnemyWardsInAttackRange = {}
			self.EnemyMinionsInAttackRange = {}
			self.JungleMinionsInAttackRange = {}
			self.PlantsMinionsInAttackRange = {}
			self.EnemyStructuresInAttackRange = {}
			self.AttackersDamage = {}
			self.ActiveAttacks = {}
			self.AllyMinionsHandles = {}
			self.TargetsHealth = {}
			self.Handles = {}
			self.CachedMinions = {}
			self.CachedWards = {}
			self.CachedPlants = {}
		end
		-- SPELLS
		for i = 1, #self.Spells do
			self.Spells[i]:Reset()
		end
		if Orbwalker.IsNone or Orbwalker.Modes[ORBWALKER_MODE_COMBO] then
			return
		end
		self.IsLastHitable = false
		self.ShouldRemoveObjects = true
		self.StaticAutoAttackDamage = Damage:GetStaticAutoAttackDamage(myHero, true)
		-- SET OBJECTS
		-- Cachear posición y rangos para evitar accesos repetitivos
		local myPos = myHero.pos
		attackRange = myHero.range + myHero.boundingRadius
		local filterRangeSq = 2000 * 2000  -- Pre-calcular rango al cuadrado para filtrado
		local cachedminions = Cached:GetMinions()
		for i = 1, #cachedminions do
			local obj = cachedminions[i]
			if GetDistanceSq(myPos, obj.pos) <= filterRangeSq then
				table_insert(self.CachedMinions, obj)
			end
		end
		local cachedwards = Cached:GetWards()
		for i = 1, #cachedwards do
			local obj = cachedwards[i]
			if obj.isEnemy and GetDistanceSq(myPos, obj.pos) <= filterRangeSq then
				table_insert(self.CachedWards, obj)
			end
		end
		local cachedplants = Cached:GetPlants()
		for i = 1, #cachedplants do
			local obj = cachedplants[i]
			if GetDistanceSq(myPos, obj.pos) <= filterRangeSq then
				table_insert(self.CachedPlants, obj)
			end
		end
		-- Pre-calcular rangos al cuadrado para comparaciones más rápidas
		local attackRangeSq = attackRange * attackRange
		for i = 1, #self.CachedMinions do
			local obj = self.CachedMinions[i]
			local handle = obj.handle
			self.Handles[handle] = obj
			local team = obj.team
			if team == Data.AllyTeam then
				self.AllyMinionsHandles[handle] = obj
			elseif team == Data.EnemyTeam then
				local objRadius = obj.boundingRadius
				local totalRangeSq = (attackRange + objRadius) * (attackRange + objRadius)
				if
					GetDistanceSq(myPos, obj.pos) <= totalRangeSq
					or (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(obj))
				then
					table_insert(self.EnemyMinionsInAttackRange, obj)
				end
			elseif team == Data.JungleTeam then
				local objRadius = obj.boundingRadius
				local totalRangeSq = (attackRange + objRadius) * (attackRange + objRadius)
				if
					GetDistanceSq(myPos, obj.pos) <= totalRangeSq
					or (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(obj))
				then
					table_insert(self.JungleMinionsInAttackRange, obj)
				end
			end
		end
		local wardRangeSq = (attackRange + 35) * (attackRange + 35)
		for i = 1, #self.CachedWards do
			local obj = self.CachedWards[i]
			if GetDistanceSq(myPos, obj.pos) <= wardRangeSq then
				table_insert(self.EnemyWardsInAttackRange, obj)
			end
		end
		for i = 1, #self.CachedPlants do
			local obj = self.CachedPlants[i]
			local objName = obj.charName:lower()
			local plantRangeSq = (attackRange + obj.boundingRadius) * (attackRange + obj.boundingRadius)
			if GetDistanceSq(myPos, obj.pos) <= plantRangeSq then
				if myHero.charName == "Senna" and objName == "sennasoul" then
					local time = Attack:GetWindup() + obj.distance / Attack:GetProjectileSpeed()
					local value= {LastHitable = true, Unkillable = false, AlmostLastHitable = false, PredictedHP = 1, Minion = obj,	AlmostAlmost = false, Time = time}
					self.IsLastHitable = true
					table_insert(self.FarmMinions, value)
				elseif objName ~= "sennasoul" and objName ~= "gangplankbarrel" then
					if Menu.Orbwalker.General.AttackPlants:Value() or obj.team ~= 300 or objName == "sru_plant_demon" then
						table_insert(self.PlantsMinionsInAttackRange, obj)
					end
				end
			end
		end
		structures = Object:GetAllStructures(2000)
		for i = 1, #structures do
			local obj = structures[i]
			local objType = obj.type
			if objType == Obj_AI_Turret then
				self.Handles[obj.handle] = obj
				if obj.team == Data.AllyTeam then
					self.AllyTurret = obj
					self.AllyTurretHandle = obj.handle
				end
			end
			if obj.team == Data.EnemyTeam then
				local objRadius = 0
				if objType == Obj_AI_Barracks then
					objRadius = 270
				elseif objType == Obj_AI_Nexus then
					objRadius = 380
				elseif objType == Obj_AI_Turret then
					objRadius = obj.boundingRadius
				end
				local structureRangeSq = (attackRange + objRadius) * (attackRange + objRadius)
				if GetDistanceSq(myPos, obj.pos) <= structureRangeSq then
					table_insert(self.EnemyStructuresInAttackRange, obj)
				end
			end
		end
	-- ON ATTACK
	local timer = GameTimer()
	local handles = self.Handles
	local activeAttacks = self.ActiveAttacks
	for handle, obj in pairs(handles) do
		local s = obj.activeSpell
		if s and s.valid and s.isAutoAttack then
			local endTime = s.endTime
			local speed = s.speed
			local animation = s.animation
			local windup = s.windup
			local target = s.target
			if endTime and speed and animation and windup and target and endTime > timer then
				activeAttacks[handle] = {
					Speed = speed,
					EndTime = endTime,
					AnimationTime = animation,
					WindUpTime = windup,
					StartTime = endTime - animation,
					Target = target,
				}
			end
		end
	end
		-- SET FARM MINIONS
		pos = myHero.pos
		speed = Attack:GetProjectileSpeed()
		windup = Attack:GetWindup()
		time = windup - self.ExtraFarmDelay:Value() * 0.001 --why is this -getlatency here? i isbjorn might try removing it -- - Data:GetLatency()
		anim = Attack:GetAnimation()
		for i = 1, #self.EnemyMinionsInAttackRange do
			local target = self.EnemyMinionsInAttackRange[i]
			table_insert(
				self.FarmMinions,
				self:SetLastHitable(
					target,
					anim,
					time + (speed > 0 and GetDistance(myHero.pos, target.pos) / speed or 0),
					Damage:GetAutoAttackDamage(myHero, target, self.StaticAutoAttackDamage)
				)
			)
		end

		-- SPELLS
		for i = 1, #self.Spells do
			self.Spells[i]:Tick()
		end
	end,

	OnDraw = function(self)
		-- OPTIMIZACIÓN: Early exit si los draws están deshabilitados
		local drawings = self.MenuDrawings
		if not drawings.Enabled:Value() or not drawings.LastHittableMinions:Value() then
			return
		end
		
		local farmMinions = self.FarmMinions
		local farmCount = #farmMinions
		
		-- OPTIMIZACIÓN: Early exit si no hay minions
		if farmCount == 0 then
			return
		end
		
		-- OPTIMIZACIÓN: Cachear colores fuera del loop
		local colorLastHit = Color.LastHitable
		local colorAlmost = Color.AlmostLastHitable
		
		for i = 1, farmCount do
			local args = farmMinions[i]
			local minion = args.Minion
			if minion and minion.valid and minion.visible and not minion.dead then
				local pos = minion.pos
				if pos then
					local pos2D = pos:To2D()
					if pos2D.onScreen then
						local radius = math_max(65, minion.boundingRadius)
						if args.LastHitable then
							Draw.Circle(pos, radius, 1, colorLastHit)
						elseif args.AlmostLastHitable then
							Draw.Circle(pos, radius, 1, colorAlmost)
						end
					end
				end
			end
		end
	end,

	GetPrediction = function(self, target, time)
		local timer, handle, health
		timer = GameTimer()
		handle = target.handle
		-- Validar que el target sigue siendo válido
		if not Object:IsValid(target) then
			return 0
		end
		if self.TargetsHealth[handle] == nil then
			self.TargetsHealth[handle] = target.health + Data:GetTotalShield(target)
		end
		health = self.TargetsHealth[handle]
		local activeAttacks = self.ActiveAttacks
		local handles = self.Handles
		local attackersDamage = self.AttackersDamage
		local targetPos = target.pos -- Usar posición actual del target
		for attackerHandle, attack in pairs(activeAttacks) do
			local attacker = handles[attackerHandle]
			if attacker and attacker.valid and attacker.visible and attacker.alive and attack.Target == handle then
				local speed, startT, flyT, endT, damage
				speed = attack.Speed
				if speed <= 0 then
					speed = 2000 -- Velocidad por defecto si no está definida
				end
				startT = attack.StartTime
				flyT = GetDistance(attacker.pos, targetPos) / speed
				endT = (startT + attack.WindUpTime + flyT) - timer
				if endT > 0 and endT < time then
					if attackersDamage[attackerHandle] == nil then
						attackersDamage[attackerHandle] = {}
					end
					if attackersDamage[attackerHandle][handle] == nil then
						attackersDamage[attackerHandle][handle] = Damage:GetAutoAttackDamage(attacker, target)
					end
					damage = attackersDamage[attackerHandle][handle]
					if damage and damage > 0 then
						health = health - damage
					end
				end
			end
		end
		return health
	end,

	LocalGetPrediction = function(self, target, time)
		local timer, handle, health, turretAttacked
		turretAttacked = false
		timer = GameTimer()
		handle = target.handle
		-- Validar que el target sigue siendo válido
		if not Object:IsValid(target) then
			return 0, false
		end
		if self.TargetsHealth[handle] == nil then
			self.TargetsHealth[handle] = target.health + Data:GetTotalShield(target)
		end
		health = self.TargetsHealth[handle]
		local handles = {}
		local activeAttacks = self.ActiveAttacks
		local selfHandles = self.Handles
		local attackersDamage = self.AttackersDamage
		local allyTurretHandle = self.AllyTurretHandle
		local targetPos = target.pos -- Usar posición actual del target
		for attackerHandle, attack in pairs(activeAttacks) do
			local attacker = selfHandles[attackerHandle]
			if attacker and attacker.valid and attacker.visible and attacker.alive and attack.Target == handle then
				-- Validar que tenemos todos los datos necesarios
				if attack.WindUpTime and attack.AnimationTime then
					local speed, startT, flyT, endT, damage
					speed = attack.Speed
					if speed <= 0 then
						speed = 2000 -- Velocidad por defecto si no está definida
					end
					startT = attack.StartTime
					flyT = GetDistance(attacker.pos, targetPos) / speed
					endT = (startT + attack.WindUpTime + flyT) - timer
					-- laneClear - manejar ataques recientemente completados
					if endT < 0 and attack.EndTime and timer - attack.EndTime < 1.25 then
						endT = attack.WindUpTime + flyT
						endT = timer > attack.EndTime and endT or endT + (attack.EndTime - timer)
						startT = timer > attack.EndTime and timer or attack.EndTime
					end
					if endT > 0 and endT < time then
						handles[attackerHandle] = true
						-- damage
						if attackersDamage[attackerHandle] == nil then
							attackersDamage[attackerHandle] = {}
						end
						if attackersDamage[attackerHandle][handle] == nil then
							attackersDamage[attackerHandle][handle] = Damage:GetAutoAttackDamage(attacker, target)
						end
						damage = attackersDamage[attackerHandle][handle]
						if damage and damage > 0 then
							-- laneClear
							local c = 1
							local maxIterations = 10
							local predictedHealth = health
							while endT < time and c <= maxIterations do
								if attackerHandle == allyTurretHandle then
									turretAttacked = true
								else
									predictedHealth = predictedHealth - damage
								end
								endT = (startT + attack.WindUpTime + flyT + c * attack.AnimationTime) - timer
								c = c + 1
							end
							if c <= maxIterations then
								health = predictedHealth
							else
							-- Si excedimos iteraciones, recalcular desde health base con predicción conservadora
							local timeRemaining = math_max(0, time - endT)
							local estimatedHits = math_ceil(timeRemaining / (attack.AnimationTime or 1))
							health = health - (damage * math_min(estimatedHits, 5))
							end
						end
					end
				end
			end
		end
		-- laneClear - predicción de minions aliados
		local allyMinionsHandles = self.AllyMinionsHandles
		for attackerHandle, obj in pairs(allyMinionsHandles) do
			if handles[attackerHandle] == nil and obj and obj.valid and obj.visible and obj.alive then
				local aaData = obj.attackData
				if aaData and aaData.target and aaData.projectileSpeed and aaData.windUpTime and aaData.animationTime then
					local isMoving = obj.pathing.hasMovePath
					local targetInRange = self.Handles[aaData.target] ~= nil
					if (not targetInRange or isMoving or self.ActiveAttacks[attackerHandle] == nil) then
						local objPos = obj.pos
						local distance = GetDistance(objPos, targetPos)
						local range = Data:GetAutoAttackRange(obj, target)
						local extraRange = isMoving and 250 or 0
						if distance < range + extraRange then
							local speed, flyT, endT, damage
							speed = aaData.projectileSpeed
							if speed <= 0 then
								speed = 2000 -- Velocidad por defecto
							end
							distance = distance > range and range or distance
							flyT = distance / speed
							endT = aaData.windUpTime + flyT
							if endT < time then
								if self.AttackersDamage[attackerHandle] == nil then
									self.AttackersDamage[attackerHandle] = {}
								end
								if self.AttackersDamage[attackerHandle][handle] == nil then
									self.AttackersDamage[attackerHandle][handle] = Damage:GetAutoAttackDamage(obj, target)
								end
								damage = self.AttackersDamage[attackerHandle][handle]
								if damage and damage > 0 then
									local c = 1
									local maxIterations = 10
									local predictedHealth = health
									while endT < time and c <= maxIterations do
										predictedHealth = predictedHealth - damage
										endT = aaData.windUpTime + flyT + c * aaData.animationTime
										c = c + 1
									end
									if c <= maxIterations then
										health = predictedHealth
									else
										-- Estimación conservadora si excedimos iteraciones
										local timeRemaining = math_max(0, time - endT)
										local estimatedHits = math_ceil(timeRemaining / (aaData.animationTime or 1))
										health = health - (damage * math_min(estimatedHits, 5))
									end
								end
							end
						end
					end
				end
			end
		end
		return health, turretAttacked
	end,

	SetLastHitable = function(self, target, anim, time, damage)
		local timer, handle, currentHealth, health, lastHitable, almostLastHitable, almostalmost, unkillable
		timer = GameTimer()
		handle = target.handle
		currentHealth = target.health + Data:GetTotalShield(target)
		-- Actualizar TargetsHealth solo si:
		-- 1. Es nil (primera vez)
		-- 2. El health actual es significativamente mayor (regeneración/heal, con tolerancia de 5 HP)
		-- Esto preserva la predicción de daño acumulado mientras maneja regeneración
		local storedHealth = self.TargetsHealth[handle]
		if storedHealth == nil then
			self.TargetsHealth[handle] = currentHealth
		elseif currentHealth > storedHealth + 5 then
			-- Health aumentó significativamente (regeneración o heal)
			self.TargetsHealth[handle] = currentHealth
		elseif currentHealth < storedHealth - target.maxHealth * 0.1 then
			-- Health bajó más del 10% del max health, probablemente recibió daño no rastreado
			-- Actualizar para evitar predicciones incorrectas
			self.TargetsHealth[handle] = currentHealth
		end
		health = self:GetPrediction(target, time)
		lastHitable = false
		almostLastHitable = false
		almostalmost = false
		unkillable = false
		if (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(target)) then
			damage=({50, 67, 84, 101, 118})[myHero:GetSpellData(_W).level] + 0.6 * myHero.ap
		end
		-- unkillable
		if health < 0 then
			unkillable = true
			for i = 1, #self.OnUnkillableC do
				self.OnUnkillableC[i](target)
			end
			return {
				LastHitable = lastHitable,
				Unkillable = unkillable,
				AlmostLastHitable = almostLastHitable,
				PredictedHP = health,
				Minion = target,
				AlmostAlmost = almostalmost,
				Time = time,
			}
		end
		-- lasthitable
		if health <= damage then
			lastHitable = true
			self.IsLastHitable = true
			return {
				LastHitable = lastHitable,
				Unkillable = unkillable,
				AlmostLastHitable = almostLastHitable,
				PredictedHP = health,
				Minion = target,
				AlmostAlmost = almostalmost,
				Time = time,
			}
		end
		-- almost lasthitable
		local turretAttack, extraTime, almostHealth, almostAlmostHealth, turretAttacked
		turretAttack = self.AllyTurret ~= nil and self.AllyTurret.attackData or nil
		extraTime = (1.5 - anim) * 0.3
		extraTime = extraTime < 0 and 0 or extraTime
		almostHealth, turretAttacked = self:LocalGetPrediction(target, anim + time + extraTime) -- + 0.25
		if (target.charName == "SRU_ChaosMinionSiege" or target.charName == "SRU_OrderMinionSiege") then
			almostHealth, turretAttacked = self:LocalGetPrediction(target, anim + time*1.4 + extraTime)
		end
		if almostHealth < 0 then
--[[ 			if (target.charName == "SRU_ChaosMinionSiege" or target.charName == "SRU_OrderMinionSiege") then
				print("Siege Minionalmost")
			end ]]
			almostLastHitable = true
			self.ShouldWaitTime = GetTickCount()
		elseif almostHealth <= damage then
			almostLastHitable = true
		elseif currentHealth ~= almostHealth then
			almostAlmostHealth, turretAttacked = self:LocalGetPrediction(
				target,
				1.25 * anim + 1.25 * time + extraTime -- removed +0.5 just to test
			)
			if almostAlmostHealth <= damage then
				almostalmost = true
			end
		end
		-- under turret, turret attackdata: 1.20048 0.16686 1200
		if
			turretAttacked
			or (turretAttack and turretAttack.target == handle)
			or (
				self.AllyTurret
				and self.AllyTurret.valid
				and (
					Data:IsInAutoAttackRange(self.AllyTurret, target)
					or Data:IsInAutoAttackRange2(self.AllyTurret, target)
				)
			)
		then
			local nearTurret, isTurretTarget, maxHP, startTime, windUpTime, flyTime, turretDamage, turretHits
			nearTurret = true
			isTurretTarget = turretAttack and turretAttack.target == handle or false
			maxHP = target.maxHealth
			if turretAttack and turretAttack.endTime then
				startTime = turretAttack.endTime - 1.20048
			else
				startTime = timer
			end
			windUpTime = 0.16686
			if self.AllyTurret and self.AllyTurret.valid then
				flyTime = GetDistance(self.AllyTurret.pos, target.pos) / 1200
			else
				flyTime = 0
			end
			if self.AllyTurret and self.AllyTurret.valid then
				turretDamage = Damage:GetAutoAttackDamage(self.AllyTurret, target)
			else
				turretDamage = 0
			end
			-- Calcular hits de torre de forma más eficiente y segura
			if turretDamage > 0 and maxHP > 0 then
				turretHits = math_ceil(maxHP / turretDamage)
				-- Limitar a máximo 10 hits para evitar cálculos erróneos
				turretHits = math_min(turretHits, 10)
				turretHits = turretHits - 1
			else
				turretHits = 0
			end
			return {
				LastHitable = lastHitable,
				Unkillable = unkillable,
				AlmostLastHitable = almostLastHitable,
				PredictedHP = health,
				Minion = target,
				AlmostAlmost = almostalmost,
				Time = time,
				-- turret
				NearTurret = nearTurret,
				IsTurretTarget = isTurretTarget,
				TurretHits = turretHits,
				TurretDamage = turretDamage,
				TurretFlyDelay = flyTime,
				TurretStart = startTime,
				TurretWindup = windUpTime,
			}
		end
		return {
			LastHitable = lastHitable,
			Unkillable = health < 0,
			AlmostLastHitable = almostLastHitable,
			PredictedHP = health,
			Minion = target,
			AlmostAlmost = almostalmost,
			Time = time,
		}
	end,

	ShouldWait = function(self)
		return GetTickCount() < self.ShouldWaitTime + 250
	end,

	GetPlantsTarget = function(self)
		if #self.PlantsMinionsInAttackRange > 0 then
			table_sort(self.PlantsMinionsInAttackRange, function(a, b)
				return a.maxHealth > b.maxHealth
			end)
			return self.PlantsMinionsInAttackRange[1]
		end
		return nil
	end,

	GetJungleTarget = function(self)
		if #self.JungleMinionsInAttackRange > 0 then
			table_sort(self.JungleMinionsInAttackRange, function(a, b)
				return a.maxHealth > b.maxHealth
			end)
			return self.JungleMinionsInAttackRange[1]
		end
		return #self.EnemyWardsInAttackRange > 0 and self.EnemyWardsInAttackRange[1] or nil
	end,

	-- Función auxiliar para obtener prioridad del tipo de minion
	GetMinionPriority = function(self, charName)
		-- Cannon minion (Siege) - Prioridad 1 (máxima)
		if charName == "SRU_ChaosMinionSiege" or charName == "SRU_OrderMinionSiege" then
			return 1
		-- Melee minion - Prioridad 2
		elseif charName == "SRU_ChaosMinionMelee" or charName == "SRU_OrderMinionMelee" then
			return 2
		-- Caster minion (Ranged) - Prioridad 3
		elseif charName == "SRU_ChaosMinionRanged" or charName == "SRU_OrderMinionRanged" then
			return 3
		end
		-- Otros tipos de minions - Prioridad 4
		return 4
	end,

	GetLastHitTarget = function(self)
		local bestTarget = nil
		local bestPriority = math_huge
		local bestHP = math_huge
		
		for i = 1, #self.FarmMinions do
			local minion = self.FarmMinions[i]
			if minion and Object:IsValid(minion.Minion) and minion.LastHitable then
				local isInRange = Data:IsInAutoAttackRange(myHero, minion.Minion) 
					or (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(minion.Minion))
				if isInRange then
					local charName = minion.Minion.charName
					local priority = self:GetMinionPriority(charName)
					local predictedHP = minion.PredictedHP or math_huge
					
					-- Priorizar por tipo de minion primero, luego por HP más bajo
					local shouldSelect = false
					if priority < bestPriority then
						-- Tipo de minion con mayor prioridad
						shouldSelect = true
					elseif priority == bestPriority and predictedHP < bestHP then
						-- Mismo tipo, pero menos HP (más cerca de morir)
						shouldSelect = true
					end
					
					if shouldSelect then
						bestTarget = minion.Minion
						bestPriority = priority
						bestHP = predictedHP
						self.LastHitHandle = bestTarget.handle
					end
				end
			end
		end
		
		return bestTarget
	end,

	GetHarassTarget = function(self)
		if not Menu.Orbwalker.General.HarassFarm:Value() then
			return Target:GetComboTarget()
		end
		local LastHitPriority = Menu.Orbwalker.Farming.LastHitPriority:Value()
		local structure = #self.EnemyStructuresInAttackRange > 0 and self.EnemyStructuresInAttackRange[1] or nil
		if structure ~= nil then
			if not LastHitPriority then
				return structure
			end
			if self.IsLastHitable then
				return self:GetLastHitTarget()
			end
			if LastHitPriority and not self:ShouldWait() then
				return structure
			end
		else
			if not LastHitPriority then
				local hero = Target:GetComboTarget()
				if hero ~= nil then
					return hero
				end
			end
			if self.IsLastHitable then
				return self:GetLastHitTarget()
			end
			if LastHitPriority and not self:ShouldWait() then
				local hero = Target:GetComboTarget()
				if hero ~= nil then
					return hero
				end
			end
		end
	end,

	GetLaneMinion = function(self)
		-- Primero verificar si hay minions lasthitable (no debería llegar aquí si GetLaneClearTarget funciona bien, pero por seguridad)
		if self.IsLastHitable then
			local lastHitTarget = self:GetLastHitTarget()
			if lastHitTarget ~= nil then
				return lastHitTarget
			end
		end
		
		-- Buscar minion para lane clear, priorizando por tipo y HP
		local bestMinion = nil
		local bestPriority = math_huge
		local bestHP = math_huge
		
		for i = 1, #self.FarmMinions do
			local minion = self.FarmMinions[i]
			if minion and Object:IsValid(minion.Minion) then
				local isInRange = Data:IsInAutoAttackRange(myHero, minion.Minion) 
					or (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(minion.Minion))
				if isInRange then
					-- Ignorar minions que están casi lasthitable (deben ser manejados por lasthit)
					if not minion.AlmostAlmost and not minion.AlmostLastHitable then
						local charName = minion.Minion.charName
						local priority = self:GetMinionPriority(charName)
						local predictedHP = minion.PredictedHP or math_huge
						
						-- Priorizar por tipo de minion, luego por HP más bajo para clear más rápido
						local shouldSelect = false
						if priority < bestPriority then
							shouldSelect = true
						elseif priority == bestPriority and predictedHP < bestHP then
							shouldSelect = true
						end
						
						if shouldSelect then
							bestMinion = minion.Minion
							bestPriority = priority
							bestHP = predictedHP
						end
					end
				end
			end
		end
		
		return bestMinion
	end,

	GetLaneClearTarget = function(self)
		local LastHitPriority = Menu.Orbwalker.Farming.LastHitPriority:Value()
		local LaneClearHeroes = Menu.Orbwalker.General.LaneClearHeroes:Value()
		local structure = #self.EnemyStructuresInAttackRange > 0 and self.EnemyStructuresInAttackRange[1] or nil
		local other = #self.EnemyWardsInAttackRange > 0 and self.EnemyWardsInAttackRange[1] or nil
		
		-- PRIORIDAD 1: SIEMPRE priorizar lasthit antes de clear durante laneclear
		if self.IsLastHitable then
			local lastHitTarget = self:GetLastHitTarget()
			if lastHitTarget ~= nil then
				return lastHitTarget
			end
		end
		
		-- PRIORIDAD 2: Estructuras (torres, inhibidores, etc.)
		if structure ~= nil then
			if not LastHitPriority then
				return structure
			end
			-- Si LastHitPriority está activo, esperar un poco antes de atacar estructura
			if not self:ShouldWait() then
				return structure
			end
		end
		
		-- PRIORIDAD 3: Wards enemigas
		if other ~= nil then
			return other
		end
		
		-- PRIORIDAD 4: Héroes enemigos (solo si LaneClearHeroes está activo)
		if LaneClearHeroes then
			local hero = Target:GetComboTarget()
			if hero ~= nil then
				-- Solo atacar héroe si no hay LastHitPriority o si no estamos esperando
				if not LastHitPriority or not self:ShouldWait() then
					return hero
				end
			end
		end
		
		-- PRIORIDAD 5: Lane clear normal (solo si no hay lasthit disponible)
		-- Esperar un poco si hay minions casi lasthitable
		if self:ShouldWait() then
			return nil
		end
		
		-- Buscar minion para lane clear
		local laneMinion = self:GetLaneMinion()
		if laneMinion ~= nil then
			self.LaneClearHandle = laneMinion.handle
			return laneMinion
		end
		
		return nil
	end,
}

Movement = {

	MoveTimer = 0,

	GetHumanizer = function(self)
		local min = 100
		local max = 150
		return max <= min and min or math_random(min, max)
	end,
}

do
	_G.LevelUpKeyTimer = 0

	Callback.Add("WndMsg", function(msg, wParam)
		if msg == HK_LUS or wParam == HK_LUS then
			_G.LevelUpKeyTimer = GetTickCount()
		end
	end)

	local AttackKey = Menu.Main.AttackTKey
	local FastKiting = Menu.Orbwalker.General.FastKiting

	_G.Control.Evade = function(a)
			if GameIsChatOpen() then
				return false
			end
		local pos = GetControlPos(a)
		if pos and EvadeSupport == nil then
			if Cursor.Step == 0 then
				Cursor:Add(MOUSEEVENTF_RIGHTDOWN, pos)
				return true
			end
			EvadeSupport = pos
			return true
		end
		return false
	end

	_G.Control.Attack = function(target)
			if GameIsChatOpen() then
				return false
			end
		if target then
				-- Prefer the user-configured AttackTKey; fallback to right-click if not set
				local k = nil
				if AttackKey and type(AttackKey.Key) == 'function' then
					local ok, v = pcall(function() return AttackKey:Key() end)
					if ok and v and v ~= 0 then k = v end
				end
				if not k or k == 0 then k = MOUSEEVENTF_RIGHTDOWN end
				Cursor:Add(k, target)
			if FastKiting:Value() then
				Movement.MoveTimer = 0
			end
			return true
		end
		return false
	end

	_G.Control.CastSpell = function(key, a, b, c)
			if GameIsChatOpen() then
				return false
			end
		local pos = GetControlPos(a, b, c)
		if pos then
			if Cursor.Step > 0 then
				return false
			end

			if not b then
				if not (Vector(pos):To2D().onScreen) then return false end
			end

			if a and (a.x or a[1]) then
				if (GetDistance(Game.mousePos(), pos)) < 2 then
					--return false
				end	
			end
			
			if not b and a.pos then
				Cursor:Add(key, a)
			else
				Cursor:Add(key, pos)
			end
			return true
		end
		if not a then
			CastKey(key)
			return true
		end
		return false
	end

	_G.Control.Hold = function(key)
			if GameIsChatOpen() then
				return false
			end
		CastKey(key)
		Movement.MoveTimer = 0
		Orbwalker.CanHoldPosition = false
		return true
	end

	_G.Control.Move = function(a, b, c)
			if GameIsChatOpen() then
				return false
			end
		if Cursor.Step > 0 or GetTickCount() < Movement.MoveTimer then
			return false
		end
		local pos = GetControlPos(a, b, c)
		if pos then
			Cursor:Add(MOUSEEVENTF_RIGHTDOWN, pos)
		elseif not a then
			if myHero.pathing.hasMovePath and GetDistance(mousePos, myHero.pathing.endPos) < Menu.Main.Humanizer:Value() then
				return false
			end
			CastKey(MOUSEEVENTF_RIGHTDOWN)
		end
		Movement.MoveTimer = GetTickCount() + Movement:GetHumanizer()
		Orbwalker.CanHoldPosition = true
		return true
	end
end

local MenuMultipleTimes = Menu.Main.SetCursorMultipleTimes
local MenuDelay = Menu.Main.CursorDelay
local MenuDrawCursor = Menu.Main.Drawings.Cursor
local MenuSmoothMouse = Menu.Main.SmoothMouse
local MenuSmoothSpeed = Menu.Main.SmoothSpeed
local MenuSmoothAcceleration = Menu.Main.SmoothAcceleration
local MenuSmoothRandomness = Menu.Main.SmoothRandomness

-- Smooth Mouse Movement System - OPTIMIZED FOR MINIMAL DELAY
SmoothMouse = {
    isMoving = false,
    startPos = {x = 0, y = 0},
    targetPos = {x = 0, y = 0},
    currentPos = {x = 0, y = 0},
    startTime = 0,
    totalDistance = 0,
    speed = 3.5,
    acceleration = 1.2,
    movementType = "normal", -- "toTarget", "return", "normal"
    onCompleteCallback = nil, -- Función a ejecutar cuando termine el movimiento
	lastCursorSetTick = 0,
	minSetIntervalMs = 3, -- OPTIMIZED: 3ms rate limit (~333 Hz) para mejor responsividad
	minTeleportDistance = 3, -- OPTIMIZED: Reduced from 5 para más precisión en distancias cortas
    
    -- Bezier curve control points for natural movement
    controlPoint1 = {x = 0, y = 0},
    controlPoint2 = {x = 0, y = 0},
    
	Start = function(self, targetX, targetY, movementType, onComplete)
        local currentCursor = Game.cursorPos()
        self.startPos.x = currentCursor.x
        self.startPos.y = currentCursor.y
        self.currentPos.x = currentCursor.x
        self.currentPos.y = currentCursor.y
        self.targetPos.x = targetX
        self.targetPos.y = targetY
        self.startTime = GetTickCount()
        self.movementType = movementType or "normal"
        self.onCompleteCallback = onComplete
        
        -- Calculate distance
        local dx = targetX - self.startPos.x
        local dy = targetY - self.startPos.y
        self.totalDistance = math.sqrt(dx * dx + dy * dy)
        
        -- Set speed and acceleration from menu
	self.speed = math_max(0.5, MenuSmoothSpeed:Value()) -- OPTIMIZED: Allow faster speeds
	self.acceleration = math_max(0.8, MenuSmoothAcceleration:Value()) -- OPTIMIZED: Allow better control
        
        -- OPTIMIZED: Hacer los movimientos al target significativamente más rápidos
		if movementType == "toTarget" then
			self.speed = self.speed * 1.8 -- OPTIMIZED: Increased from 1.35 for better responsivity
		elseif movementType == "return" then
			self.speed = self.speed * 0.9 -- OPTIMIZED: Return slightly slower for stability
		end

		-- OPTIMIZED: Para distancias pequeñas usar teleport directo (más rápido)
		if self.totalDistance <= self.minTeleportDistance then
            -- Direct instant move for very small distances
            Control.SetCursorPos(targetX, targetY)
            self.isMoving = false
            if self.onCompleteCallback then
                self.onCompleteCallback()
            end
        else
            self.isMoving = true
            self:GenerateControlPoints()
        end
    end,
    
    GenerateControlPoints = function(self)
	local randomness = math_max(0, math_min(MenuSmoothRandomness:Value(), 20))
        local dx = self.targetPos.x - self.startPos.x
        local dy = self.targetPos.y - self.startPos.y
        
        -- Create natural curved path
        local perpX = -dy / self.totalDistance
        local perpY = dx / self.totalDistance
        
        -- Add randomness to control points
        local random1 = (math_random(-randomness, randomness) / 100.0) * self.totalDistance
        local random2 = (math_random(-randomness, randomness) / 100.0) * self.totalDistance
        
        self.controlPoint1.x = self.startPos.x + dx * 0.25 + perpX * random1
        self.controlPoint1.y = self.startPos.y + dy * 0.25 + perpY * random1
        
        self.controlPoint2.x = self.startPos.x + dx * 0.75 + perpX * random2
        self.controlPoint2.y = self.startPos.y + dy * 0.75 + perpY * random2
    end,
    
    -- Cubic Bezier interpolation
    BezierLerp = function(self, t)
        local invT = 1.0 - t
        local invT2 = invT * invT
        local invT3 = invT2 * invT
        local t2 = t * t
        local t3 = t2 * t
        
        local x = invT3 * self.startPos.x + 
                 3 * invT2 * t * self.controlPoint1.x +
                 3 * invT * t2 * self.controlPoint2.x +
                 t3 * self.targetPos.x
                 
        local y = invT3 * self.startPos.y + 
                 3 * invT2 * t * self.controlPoint1.y +
                 3 * invT * t2 * self.controlPoint2.y +
                 t3 * self.targetPos.y
                 
        return {x = x, y = y}
    end,
    
    Update = function(self)
        if not self.isMoving then
            return false
        end
        
        local elapsed = GetTickCount() - self.startTime
        local baseTime = self.totalDistance / self.speed
		-- Safety: avoid division by zero; if baseTime <= 0 interpret as completed
		local normalizedTime
		if baseTime <= 0 or baseTime ~= baseTime then -- check NaN or zero
			normalizedTime = 1
		else
			-- Apply acceleration curve (starts slow, speeds up, then slows down)
			normalizedTime = elapsed / baseTime
		end
        
        -- OPTIMIZED: Early termination check with buffer for precision
	if normalizedTime >= 0.99 then
            -- Movement essentially complete - snap to target
            Control.SetCursorPos(math.floor(self.targetPos.x), math.floor(self.targetPos.y))
            self.isMoving = false
            
            -- Execute callback if provided
            if self.onCompleteCallback then
                self.onCompleteCallback()
                self.onCompleteCallback = nil -- Clear callback after execution
            end
            
            return true
        end
        
        -- Ease-in-out function for natural acceleration
        local t = normalizedTime
        if self.acceleration > 1.0 then
            t = t < 0.5 and 
                (self.acceleration * t * t) / (2 * ((self.acceleration - 1) * t + 1)) or
                1 - (self.acceleration * (1 - t) * (1 - t)) / (2 * ((self.acceleration - 1) * (1 - t) + 1))
        end
        
        -- Calculate position using Bezier curve
        local pos = self:BezierLerp(math_min(t, 1.0))
        
		-- OPTIMIZED: Aggressive rate-limiting with adaptive timing
		local now = GetTickCount()
		if (now - self.lastCursorSetTick) >= self.minSetIntervalMs then
			Control.SetCursorPos(math.floor(pos.x + 0.5), math.floor(pos.y + 0.5)) -- Better rounding
			self.lastCursorSetTick = now
		end
        self.currentPos = pos
        
        return false -- Still moving
    end,
    
    IsMoving = function(self)
        return self.isMoving
    end,
    
	Stop = function(self)
		self.isMoving = false
		self.onCompleteCallback = nil -- Clear callback when stopping
    end
}

Cursor = {

	Step = 0,
	SmoothMovementActive = false,
	OriginalCursorPosition = nil, -- posición original inmutable durante la acción
	LastStepTick = 0,

	Add = function(self, key, castPos)
		-- If chat is open, do not queue cursor actions
		if GameIsChatOpen() then
			return false
		end
		if type(key) == "table" then
            self.Keys = key
        else
            self.Keys = { key }  -- store it in a table format for consistency
        end
		-- Capturar posición original del cursor SOLO si no existe aún (no recapturar en trayecto)
		local currentCursorPos = Game.cursorPos()
		if not self.OriginalCursorPosition and currentCursorPos and currentCursorPos.x and currentCursorPos.y then
			self.OriginalCursorPosition = { x = math.floor(currentCursorPos.x), y = math.floor(currentCursorPos.y) }
			self.CursorPos = { x = self.OriginalCursorPosition.x, y = self.OriginalCursorPosition.y }
		end
		self.CastPos = castPos
		if self.CastPos ~= nil then
			self.IsTarget = self.CastPos.pos ~= nil
			self.correctedCastPos = self.CastPos
			self.IsMouseClick = key == MOUSEEVENTF_RIGHTDOWN
			self.Timer = GetTickCount() + MenuDelay:Value()
			self.SmoothMovementActive = false
			self:StepSetToCastPos() -- Now handles both smooth and direct movement
			if not self.SmoothMovementActive then
				self:StepPressKey()
			end
			-- Mark last step tick to watch for stuck state
			self.LastStepTick = GetTickCount()
		end
	end,

	StepReady = function(self)
		if EvadeSupport then
			self:Add(MOUSEEVENTF_RIGHTDOWN, EvadeSupport)
			EvadeSupport = nil
		end
	end,

	-- Function to stop smooth movement immediately
	StopSmoothMovement = function(self)
		if self.SmoothMovementActive then
			SmoothMouse:Stop()
			self.SmoothMovementActive = false
			-- No limpiar OriginalCursorPosition aquí; se limpia al finalizar StepSetToCursorPos
		end
	end,

	-- Force cancel any active cursor action and reset state
	ForceReset = function(self)
		-- Stop smooth movement and clear flags
		if self.SmoothMovementActive then
			SmoothMouse:Stop()
			self.SmoothMovementActive = false
		end
		-- Reset step, original position and timer
		self.Step = 0
		self.OriginalCursorPosition = nil
		self.CursorPos = nil
		self.CastPos = nil
		self.Timer = 0
		self.Keys = nil
		self.LastStepTick = 0
		-- Release potential stuck mouse press and notify operator
		pcall(function()
			Control.mouse_event(MOUSEEVENTF_RIGHTUP)
			Control.mouse_event(MOUSEEVENTF_LEFTUP)
		end)
		-- Debug prints removed: ForceReset runs silently now
	end,

	StepSetToCastPos = function(self)
		-- Do not proceed when chat is open
		if GameIsChatOpen() then
			self.Step = 0
			self.OriginalCursorPosition = nil
			self.CursorPos = nil
			return
		end
		local pos
		if self.IsTarget then
			pos = self.CastPos.pos:To2D()
			if self.CastPos.charName == "GangplankBarrel" then
				pos.y=pos.y-((69/1440)*Game.Resolution().y)
			end
			if self.CastPos.charName:lower():find("chaosminion") or self.CastPos.charName:lower():find("orderminion") then
				pos.y=pos.y-((25/1440)*Game.Resolution().y)
			end
		else
			-- Check if we have 3D coordinates (x, z)
			if self.CastPos.z ~= nil then
				-- 3D world coordinates: use myHero.pos.y as height reference
				pos = Vector(self.CastPos.x, myHero.pos.y, self.CastPos.z):To2D()
			else
				-- 2D screen coordinates or pre-calculated position
				pos = Vector({ x = self.CastPos.x, y = self.CastPos.y })
			end
		end
		self.correctedCastPos = pos
		-- whenever we set a new target, refresh last step tick
		self.LastStepTick = GetTickCount()
		
		-- OPTIMIZED: Check distance to current cursor for smart movement
		local cursorPos = Game.cursorPos()
		local distToCursor = math.sqrt((pos.x - cursorPos.x)^2 + (pos.y - cursorPos.y)^2)
		
		-- Always use smooth movement if enabled
				if MenuSmoothMouse:Value() then
			-- OPTIMIZED: Use slower/no smooth for very small distances
			if distToCursor <= 10 then
				-- Very close: teleport directly
				Control.SetCursorPos(pos.x, pos.y)
				-- Use wait state to verify before executing action
				self.Timer = GetTickCount() + MenuDelay:Value() + 30
				self.Step = 1
				else
				-- Use smooth movement for longer distances
				SmoothMouse:Start(pos.x, pos.y, "toTarget", function()
					-- Instead of executing action directly when movement completes, switch to WAIT state
					-- This ensures we verify the cursor is actually at the target position before pressing key
					self.SmoothMovementActive = false
					self.Step = 1
					self.Timer = GetTickCount() + MenuDelay:Value() + 50 -- small safety margin
					self.LastStepTick = GetTickCount()
				end)
				self.SmoothMovementActive = true
			end
		else
			-- Direct teleport only if smooth is disabled
			Control.SetCursorPos(pos.x, pos.y)
		end
	end,

	StepPressKey = function(self)
		-- Always transition to WAIT state before pressing key, so the StepWaitForResponse can verify
		-- cursor pos and apply any final reinforcement (reposition) before executing.
		self.Timer = GetTickCount() + MenuDelay:Value() + 30 -- small safety margin
		self.Step = 1
		self.LastStepTick = GetTickCount()
	end,

	-- Nueva función para ejecutar la acción directamente
	ExecuteAction = function(self)
		-- If chat opened while waiting, cancel the execution
		if GameIsChatOpen() then
			self.Step = 0
			self.SmoothMovementActive = false
			self.OriginalCursorPosition = nil
			self.CursorPos = nil
			return
		end
		-- Reset smooth movement flag
		if self.SmoothMovementActive then
			self.SmoothMovementActive = false
		end
		
		if self.CastPos.type then
			if self.CastPos.type ~= Obj_AI_Hero or self.CastPos.charName == "GangplankBarrel" then
				if Control.IsKeyDown(HK_TCO) then
					Control.KeyUp(HK_TCO)
				end
			end
		end
		
		-- Ejecutar acción inmediatamente sin verificaciones
		-- A direct execution after the wait: double-check cursor is where we expect
		local expected = self.correctedCastPos
		if expected and expected.x and expected.y then
			local cursorPos = Game.cursorPos()
			if cursorPos and (math.sqrt((cursorPos.x - expected.x)^2 + (cursorPos.y - expected.y)^2) > 4) then
				-- Reinforce exact cursor position before executing
				Control.SetCursorPos(math.floor(expected.x + 0.5), math.floor(expected.y + 0.5))
			end
		end

		if self.IsMouseClick then
			Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
			Control.mouse_event(MOUSEEVENTF_RIGHTUP)
		else
			for _, key in ipairs(self.Keys) do
				-- Ejecutar sin verificar posición del cursor
				if Control.IsKeyDown(key) and myHero.activeSpell.isCharging then
					Control.KeyUp(key)
				else
					Control.KeyDown(key)
					Control.KeyUp(key)
				end
			end
		end
		
		-- Pasar directamente al retorno
		self.Step = 2
		self.LastStepTick = GetTickCount()
	end,

	StepWaitForResponse = function(self)
		-- Wait until the cursor is at the correctedCastPos, or timeout
		local expected = self.correctedCastPos
		if not expected or not expected.x or not expected.y then
			-- No expected pos: execute directly
			self:ExecuteAction()
			return
		end
		local cursorPos = Game.cursorPos()
		local dist = 9999
		if cursorPos then
			dist = math.sqrt((cursorPos.x - expected.x)^2 + (cursorPos.y - expected.y)^2)
		end
	local now = GetTickCount()
	local timeout = self.Timer or (now + MenuDelay:Value() + 50)

		-- If within small threshold, or timer exceeded, execute the action
		local threshold = 5
		if dist <= threshold then
			self:ExecuteAction()
			return
		end

	if now >= timeout then
			-- Timeout reached - try to reinforce cursor position once
			Control.SetCursorPos(math.floor(expected.x + 0.5), math.floor(expected.y + 0.5))
			-- Allow a short additional delay to let OS/game register the pos, then execute
			self.Timer = now + 30
			if now >= self.Timer then
				self:ExecuteAction()
			end
			return
		end
		-- If configured, reinforce cursor position multiple times while waiting
		if MenuMultipleTimes:Value() then
			self._lastReinforce = self._lastReinforce or 0
			if now - self._lastReinforce > 20 then
				Control.SetCursorPos(math.floor(expected.x + 0.5), math.floor(expected.y + 0.5))
				self._lastReinforce = now
			end
		end
	end,

	StepSetToCursorPos = function(self)
		-- Esta función maneja el retorno del mouse a la posición original
		-- Si smoothness está activado, usa movimiento suave para retornar
		
		-- Usar SIEMPRE la posición original inmutable si está disponible
		local returnPos = self.OriginalCursorPosition or self.CursorPos
		if not returnPos or not returnPos.x or not returnPos.y then
			-- Sin posición válida, finalizar sin mover
			self.Step = 0
			return
		end
		
		-- OPTIMIZED: Check distance for smart return behavior
		local cursorPos = Game.cursorPos()
		local distToReturn = math.sqrt((returnPos.x - cursorPos.x)^2 + (returnPos.y - cursorPos.y)^2)
		
		if MenuSmoothMouse:Value() then
			-- OPTIMIZED: Skip smooth return for very small distances
			if distToReturn <= 15 then
				-- Already close to original position: instant return
				Control.SetCursorPos(returnPos.x, returnPos.y)
				self.Step = 0
				self.OriginalCursorPosition = nil
				self.CursorPos = nil
			else
				-- Usar movimiento suave para retornar a la posición original del cursor
				SmoothMouse:Start(returnPos.x, returnPos.y, "return", function()
					-- Cuando termine el retorno, finalizar el proceso
					self.Step = 0
					-- Limpiar posición original SOLO al finalizar el retorno
					self.OriginalCursorPosition = nil
					self.CursorPos = nil
					self.LastStepTick = GetTickCount()
				end)
				self.SmoothMovementActive = true
			end
		else
			-- Retorno instantáneo (método tradicional)
			Control.SetCursorPos(returnPos.x, returnPos.y)
			self.Step = 0
			self.OriginalCursorPosition = nil
			self.CursorPos = nil
		end
		self.Timer = GetTickCount() + MenuDelay:Value()
		-- Update LastStepTick used for watchdog
		self.LastStepTick = GetTickCount()
		-- No cambiar Step aquí si usamos smoothness, el callback lo hará
		if not MenuSmoothMouse:Value() then
			self.Step = 3
		end
	end,

	StepWaitForReady = function(self)
		-- Si no hay movimiento suave activo, finalizar inmediatamente
		if not (self.SmoothMovementActive and SmoothMouse:IsMoving()) then
			if self.SmoothMovementActive then
				self.SmoothMovementActive = false
			end
			self.Step = 0
		end
		-- Si hay movimiento suave, el callback se encargará de cambiar el Step
	end,

	OnTick = function(self)
		-- Update smooth mouse movement
		if SmoothMouse:IsMoving() then
			SmoothMouse:Update()
		end

		-- If Data:Stop is signaled (chat open / evade / not top), ensure we reset any pending cursor action
		if Data and Data:Stop() and self.Step and self.Step > 0 then
			self:ForceReset()
			Movement.MoveTimer = 0
			return
		end
		-- Watchdog: recover from stuck Step states
		if self.Step and self.Step > 0 then
			local now = GetTickCount()
			local safeResetEnabled = true
			local timeout = AUTO_SAFE_RESET_TIMEOUT
			-- Extra safety: if the game loses focus or chat opens, force reset immediately
			if GameIsChatOpen() or (not GameIsOnTop()) then
				self:ForceReset()
				Movement.MoveTimer = 0
				return
			end
			if safeResetEnabled and self.LastStepTick and self.LastStepTick > 0 and (now - self.LastStepTick) >= timeout then
				-- Reset everything gracefully
				self:ForceReset()
				-- Reset movement timer to ensure immediate new actions
				Movement.MoveTimer = 0
			end
		end
		-- Evitar recapturas de cursor mientras hay movimiento suave activo
		-- self.OriginalCursorPosition se define en Add y se limpia al final del retorno
		
		local step = self.Step
		if step == 0 then
			self:StepReady()
		elseif step == 1 then
			self:StepWaitForResponse()
		elseif step == 2 then
			self:StepSetToCursorPos()
		elseif step == 3 then
			self:StepWaitForReady()
		end
	end,

	OnDraw = function(self)
		-- OPTIMIZACIÓN: Early exit
		if not MenuDrawCursor:Value() then
			return
		end
		
		Draw.Circle(mousePos, 150, 1, Color.Cursor)
		
		-- Draw smooth movement path if active
		if MenuSmoothMouse:Value() and SmoothMouse:IsMoving() then
			local targetPos = SmoothMouse.targetPos
			if targetPos then
				-- Draw current target position
				local myY = myHero.pos.y
				Draw.Circle(Vector(targetPos.x, myY, targetPos.y), 75, 2, Color.Yellow)
				
				-- OPTIMIZACIÓN: Draw bezier curve path con menos creaciones de Vector
				local colorLine = Color.LightGreen
				local steps = 10
				local prevPos = SmoothMouse:BezierLerp(0)
				
				for i = 1, steps do
					local t = i / steps
					local currPos = SmoothMouse:BezierLerp(t)
					Draw.Line(
						Vector(prevPos.x, myY, prevPos.y):To2D(),
						Vector(currPos.x, myY, currPos.y):To2D(),
						1, colorLine
					)
					prevPos = currPos
				end
			end
			-- No debug cursor info (removed, per user request)
		end
	end,
}

Attack = {

	TestDamage = false,
	TestCount = 0,
	TestStartTime = 0,
	IsGraves = myHero.charName == "Graves",
	SpecialWindup = Data.SpecialWindup[myHero.charName],
	IsJhin = myHero.charName == "Jhin",
	IsAphelios = myHero.charName == "Aphelios",
	BaseAttackSpeed = Data.HEROES[Data.HeroName][3],
	BaseWindupTime = nil,
	Reset = false,
	ServerStart = 0,
	CastEndTime = 1,
	LocalStart = 0,
	AttackWindup = 0,
	AttackAnimation = 0,
	IsSenna = myHero.charName == "Senna",

	OnTick = function(self)
		if Data:CanResetAttack() and Orbwalker.Menu.General.AttackResetting:Value() then
			self.Reset = true
		end
		local spell = myHero.activeSpell
		if
			spell
			and spell.valid
			and spell.target > 0
			and spell.castEndTime > self.CastEndTime
			and (spell.isAutoAttack or Data:IsAttack(spell.name))
		then
			-- spell.isAutoAttack then  and GameTimer() < self.LocalStart + 0.2
			for i = 1, #Orbwalker.OnAttackCb do
				Orbwalker.OnAttackCb[i]()
			end
			self.CastEndTime = spell.castEndTime
			self.AttackWindup = spell.windup
			self.ServerStart = self.CastEndTime - self.AttackWindup
			self.AttackAnimation = spell.animation
			if self.TestDamage then
				if self.TestCount == 0 then
					self.TestStartTime = GameTimer()
				end
				self.TestCount = self.TestCount + 1
				if self.TestCount == 5 then
					--print('5 attacks in time: ' .. tostring(GameTimer() - self.TestStartTime) .. '[sec]')
					self.TestCount = 0
					self.TestStartTime = 0
				end
			end
		end
	end,

	GetWindup = function(self)
		if self.IsJhin then
			return self.AttackWindup
		end
		if self.IsGraves then
			return myHero.attackData.windUpTime * 0.2
		end
		if self.SpecialWindup then
			local windup = self.SpecialWindup()
			if windup then
				return windup
			end
		end
		if self.BaseWindupTime then
			return math_max(self.AttackWindup, 1 / (myHero.attackSpeed * self.BaseAttackSpeed) / self.BaseWindupTime)
		end
		local data = myHero.attackData
		if data.animationTime > 0 and data.windUpTime > 0 then
			self.BaseWindupTime = data.animationTime / data.windUpTime
		end
		return math_max(self.AttackWindup, myHero.attackData.windUpTime)
	end,

	GetAnimation = function(self)
		if self.IsJhin then
			return self.AttackAnimation
		end
		if self.IsGraves then
			return myHero.attackData.animationTime * 0.9
		end
		if self.IsAphelios and Buff:HasBuff(myHero, "ApheliosCrescendumManager") then
		 return 1.1 / (myHero.attackSpeed * self.BaseAttackSpeed)
		end

		return 1 / (myHero.attackSpeed * self.BaseAttackSpeed)
	end,

	GetProjectileSpeed = function(self)
		if Data.IsHeroMelee or (Data.IsHeroSpecialMelee and Data.IsHeroSpecialMelee()) then
			return math_huge
		end
		if Data.SpecialMissileSpeed then
			local speed = Data.SpecialMissileSpeed()
			if speed then
				return speed
			end
		end
		local speed = myHero.attackData.projectileSpeed
		if speed > 0 then
			return speed
		end
		return math_huge
	end,

	IsReady = function(self)
		if myHero.charName=="Sion" and myHero.attackData.state==STATE_ATTACK then
			return true
		end
		if self.CastEndTime > self.LocalStart then
			if self.Reset or GameTimer() >= self.ServerStart + self:GetAnimation() - Data:GetLatency() - 0.01 then
				return true
			end
			return false
		end

		if GameTimer() < self.LocalStart + 0.2 then
			return false
		end
		if myHero.charName=="Rengar" and Game.CanUseSpell(_Q)~=8 and myHero:GetSpellData(63).castTime+myHero.attackData.windDownTime>Game.Timer()+10+LATENCY * 0.001 then
			return false
		end

		return true
	end,

	GetAttackCastTime = function(self, num)
		num = num or 0
		return self:GetWindup()
			- Data:GetLatency()
			+ num
			+ 0.025
			+ (Orbwalker.Menu.General.ExtraWindUpTime:Value() * 0.001)
	end,

	IsActive = function(self, num)
		num = num or 0
		if self.CastEndTime > self.LocalStart then
			if
				GameTimer()
				>= self.ServerStart
					+ self:GetWindup()
					- Data:GetLatency()
					+ 0.025
					+ num
					+ (Orbwalker.Menu.General.ExtraWindUpTime:Value() * 0.001)
			then
				return false
			end
			return true
		end
		if GameTimer() < self.LocalStart + 0.2 then
			return true
		end
		return false
	end,

	IsBefore = function(self, multipier)
		return GameTimer() > self.LocalStart + multipier * self:GetAnimation()
	end,
}

Orbwalker = {

	LastTarget = nil,
	CanHoldPosition = true,
	PostAttackTimer = 0,
	IsNone = true,
	OnPreAttackCb = {},
	OnPostAttackCb = {},
	OnPostAttackTickCb = {},
	OnAttackCb = {},
	OnMoveCb = {},
	Menu = Menu.Orbwalker,
	MenuDrawings = Menu.Main.Drawings,
	HoldPositionButton = Menu.Orbwalker.Keys.HoldKey,

	MenuKeys = {
		[ORBWALKER_MODE_COMBO] = {},
		[ORBWALKER_MODE_HARASS] = {},
		[ORBWALKER_MODE_LANECLEAR] = {},
		[ORBWALKER_MODE_JUNGLECLEAR] = {},
		[ORBWALKER_MODE_LASTHIT] = {},
		[ORBWALKER_MODE_FLEE] = {},
		[ORBWALKER_MODE_SPACING] = {},
	},

	Modes = {
		[ORBWALKER_MODE_COMBO] = false,
		[ORBWALKER_MODE_HARASS] = false,
		[ORBWALKER_MODE_LANECLEAR] = false,
		[ORBWALKER_MODE_JUNGLECLEAR] = false,
		[ORBWALKER_MODE_LASTHIT] = false,
		[ORBWALKER_MODE_FLEE] = false,
		[ORBWALKER_MODE_SPACING] = false,
	},

	ForceMovement = nil,
	ForceTarget = nil,
	PostAttackBool = false,
	AttackEnabled = true,
	MovementEnabled = true,

	CanAttackC = function()
		return true
	end,

	CanMoveC = function()
		return true
	end,

	OnTick = function(self)
		-- Optimización FPS: Salir temprano si no debe procesar este tick
		-- Integración ligera con DepressiveEvade: evaluar amenazas antes de orbwalk
		if _G.DepressiveEvade and _G.DepressiveEvade.ShouldEvade then
			pcall(function()
				_G.DepressiveEvade:ShouldEvade()
			end)
		end

		if not FPSOptimizer:ShouldTick() then
			return
		end
		
		if not self.Menu.Enabled:Value() then
			return
		end
		
		-- Early exits para mejor rendimiento
		if myHero.dead then
			return
		end
		
		-- Cache modes solo cuando es necesario
		local isNone = self:HasMode(ORBWALKER_MODE_NONE)
		self.IsNone = isNone
		self.Modes = self:GetModes()
		
		if self:HasMode(ORBWALKER_MODE_COMBO) and not myHero.dead then
			Control.KeyDown(HK_TCO)
		else
			Control.KeyUp(HK_TCO)
		end
		
		-- Early skip reasons tracking for diagnostics
		local skipReason = nil
		if Cursor.Step > 0 then
			skipReason = "Cursor.Step>0"
		end
		if Data:Stop() then
			skipReason = (skipReason and skipReason .. ",DataStop" or "DataStop")
		end
		if isNone then
			skipReason = (skipReason and skipReason .. ",ModeNone" or "ModeNone")
		end
		if skipReason then
			self.LastSkippedState = true
			return
		else
			self.LastSkippedState = false
		end
		
		-- Solo ejecutar orbwalk si no estamos en modo de alta carga o es un tick crítico
		if not FPSOptimizer.highLoadMode or (FPSOptimizer.tickCounter % 2 == 0) then
			self:Orbwalk()
		end
	end,

	OnDraw = function(self)
		if not self.Menu.Enabled:Value() then
			return
		end
		
		-- OPTIMIZACIÓN: Cachear posición y drawings menu
		local myPos = myHero.pos
		local drawings = self.MenuDrawings
		
		if drawings.Range:Value() then
			Draw.Circle(myPos, Data:GetAutoAttackRange(myHero), 1, Color.Range)
		end
		if drawings.HoldRadius:Value() then
			Draw.Circle(myPos, self.Menu.General.HoldRadius:Value(), 1, Color.LightGreen)
		end
		if drawings.EnemyRange:Value() then
			local enemies = Object:GetEnemyHeroes()
			local enemyCount = #enemies
			if enemyCount > 0 then
				-- OPTIMIZACIÓN: Cachear colores fuera del loop
				local colorRange = Color.Range
				local colorEnemy = Color.EnemyRange
				for i = 1, enemyCount do
					local enemy = enemies[i]
					local enemyPos = enemy.pos
					if enemyPos then
						local pos2D = enemyPos:To2D()
						if pos2D.onScreen then
							local range = Data:GetAutoAttackRange(enemy, myHero)
							local inRange = IsInRange(enemy, myHero, range)
							Draw.Circle(enemyPos, range, 1, inRange and colorEnemy or colorRange)
						end
					end
				end
			end
		end

		-- Debug / Safe Reset Info (OPTIMIZACIÓN: usar string.format)
		if Menu.Main.Drawings.SmartCacheInfo:Value() then
			local x, y = 20, 50
			local modeInfo = FPSOptimizer:GetModeInfo()
			local info = string_format(
				"Orbwalker: step=%d | smooth=%s | moveIn=%d | mode=%s hH=%d hM=%d",
				Cursor.Step or 0,
				tostring(SmoothMouse:IsMoving()),
				math_max(0, Movement.MoveTimer - GetTickCount()),
				modeInfo.mode,
				modeInfo.cachedHeroesCount or 0,
				modeInfo.cachedMinionsCount or 0
			)
			Draw.Text(info, 16, x, y)
		end
	end,

	RegisterMenuKey = function(self, mode, key)
		table_insert(self.MenuKeys[mode], key)
	end,

	ResetMovement = function(self)
		Movement.MoveTimer = 0
	end,

	GetModes = function(self)
		return {
			[ORBWALKER_MODE_COMBO] = self:HasMode(ORBWALKER_MODE_COMBO),
			[ORBWALKER_MODE_HARASS] = self:HasMode(ORBWALKER_MODE_HARASS),
			[ORBWALKER_MODE_LANECLEAR] = self:HasMode(ORBWALKER_MODE_LANECLEAR),
			[ORBWALKER_MODE_JUNGLECLEAR] = self:HasMode(ORBWALKER_MODE_JUNGLECLEAR),
			[ORBWALKER_MODE_LASTHIT] = self:HasMode(ORBWALKER_MODE_LASTHIT),
			[ORBWALKER_MODE_FLEE] = self:HasMode(ORBWALKER_MODE_FLEE),
			[ORBWALKER_MODE_SPACING] = self:HasMode(ORBWALKER_MODE_SPACING),
		}
	end,

	HasMode = function(self, mode)
		if mode == ORBWALKER_MODE_NONE then
			for _, value in pairs(self:GetModes()) do
				if value then
					return false
				end
			end
			return true
		end
		for i = 1, #self.MenuKeys[mode] do
			local key = self.MenuKeys[mode][i]
			if key:Value() then
				return true
			end
		end
		return false
	end,

	OnPreAttack = function(self, func)
		table_insert(self.OnPreAttackCb, func)
	end,

	OnPostAttack = function(self, func)
		table_insert(self.OnPostAttackCb, func)
	end,

	OnPostAttackTick = function(self, func)
		table_insert(self.OnPostAttackTickCb, func)
	end,

	OnAttack = function(self, func)
		table_insert(self.OnAttackCb, func)
	end,

	OnPreMovement = function(self, func)
		table_insert(self.OnMoveCb, func)
	end,

	CanAttackEvent = function(self, func)
		self.CanAttackC = func
	end,

	CanMoveEvent = function(self, func)
		self.CanMoveC = func
	end,

	__OnAutoAttackReset = function(self)
		Attack.Reset = true
	end,

	SetMovement = function(self, boolean)
		self.MovementEnabled = boolean
	end,

	SetAttack = function(self, boolean)
		self.AttackEnabled = boolean
	end,

	IsEnabled = function(self)
		return true
	end,

	IsAutoAttacking = function(self, unit)
		-- Refined timing similar a Orbwalker.lua: usar fin de animación - anim + windup + extra
		if unit == nil or unit.isMe then
			local endTime = myHero.attackData.endTime
			local anim = myHero.attackData.animationTime
			local windup = myHero.attackData.windUpTime
			local extra = (self.Menu.General.ExtraWindUpTime:Value() * 0.001)
			-- Latency compensation (similar formula: latency*1.5 - 0.09 para movimiento, pero aquí más conservador)
			local latencyAdjust = Data:GetLatency() * 1.5 - 0.05
			local adjusted = endTime - anim + windup + extra
			return GameTimer() - adjusted + latencyAdjust < 0
		end
		return GameTimer() < unit.attackData.endTime - unit.attackData.windDownTime
	end,

	CanMove = function(self, unit)
		if unit == nil or unit.isMe then
			if not self.CanMoveC() then
				return false
			end
			if (JustEvade and JustEvade.Evading()) or (ExtLibEvade and ExtLibEvade.Evading) then
				return false
			end
	 		if myHero.charName == "Kalista" then
				return true
			end
			if not Data:HeroCanMove() then
				return false
			end
			return not Attack:IsActive()
		end
		local attackData = unit.attackData
		return GameTimer() > attackData.endTime - attackData.windDownTime
	end,

	CanAttack = function(self, unit)
		if unit == nil or unit.isMe then
			if not self.CanAttackC() then
				return false
			end
			if (JustEvade and JustEvade.Evading()) or (ExtLibEvade and ExtLibEvade.Evading) then
				return false
			end
			if not Data:HeroCanAttack() then
				return false
			end
			return Attack:IsReady()
		end
		return GameTimer() > unit.attackData.endTime
	end,

	KindredETarget = function(self, unit)
		if (unit and Buff:HasBuff(unit,"kindredecharge"))==false then
			return false
		end
		local particleCount = Game.ParticleCount()
		for i = particleCount, 1, -1 do
			local obj = Game.Particle(i)
			if obj and obj.type == "obj_GeneralParticleEmitter" and obj.name:lower():find("kindred_base_e_stack_3")  then
				return false
			end
		end
		return true
	end,
	GetTarget = function(self)
		if
			Object:IsValid(self.ForceTarget)
			and ChampionInfo:CustomIsTargetable(self.ForceTarget)
			and (Object:IsHeroImmortal(self.ForceTarget, true)==false or (Object.IsKindred and (self:KindredETarget(self.ForceTarget))))
		then

			return self.ForceTarget
		end
		if self.Modes[ORBWALKER_MODE_COMBO] then
			return Target:GetComboTarget()
		end
		if self.Modes[ORBWALKER_MODE_LASTHIT] then
			return Health:GetLastHitTarget()
		end
		if self.Modes[ORBWALKER_MODE_JUNGLECLEAR] then
			local jungle = Health:GetJungleTarget()
			if jungle ~= nil then
				return jungle
			end
		end
		if self.Modes[ORBWALKER_MODE_LANECLEAR] then
			local plants = Health:GetPlantsTarget()
			if plants ~= nil then
				return plants
			end
			return Health:GetLaneClearTarget()
		end
		if self.Modes[ORBWALKER_MODE_HARASS] then
			return Health:GetHarassTarget()
		end
		return nil
	end,

	OnUnkillableMinion = function(self, cb)
		table_insert(Health.OnUnkillableMinionCallbacks, cb)
	end,

	Attack = function(self, unit)
		if not self.Menu.AttackEnabled:Value() then
			return
		end
		if GameIsChatOpen() or Data:Stop() then
			return
		end
		if self.AttackEnabled and unit and unit.valid and unit.visible and unit.pos:To2D().onScreen then
			self.LastTarget = unit
			if self:CanAttack() then
				local args = { Target = unit, Process = true }
				for i = 1, #self.OnPreAttackCb do
					self.OnPreAttackCb[i](args)
				end
				if args.Process then
					if args.Target and not ChampionInfo:CustomIsTargetable(args.Target) then
						args.Target = Target:GetComboTarget()
					end
					if args.Target then
						self.LastTarget = args.Target
						local targetpos = args.Target.pos
						local attackpos = targetpos:ToScreen().onScreen and args.Target
							or myHero.pos:Extended(targetpos, 800)
						if Control.Attack(attackpos) then
							Attack.Reset = false
							Attack.LocalStart = GameTimer()
							self.PostAttackBool = true
						end
					end
					return true
				end
			end
		end
		return false
	end,

	Move = function(self)
		if not self.Menu.MovementEnabled:Value() then
			return
		end
		if GameIsChatOpen() or Data:Stop() then
			return
		end
		if self.MovementEnabled and self:CanMove() then
			if self.PostAttackBool and not Attack:IsActive(0.025) then
				for i = 1, #self.OnPostAttackCb do
					self.OnPostAttackCb[i]()
				end
				self.PostAttackTimer = GameTimer()
				self.PostAttackBool = false
				-- Intento de cancelación: lanzar hechizo configurado inmediatamente tras windup
				local target = self.LastTarget
				if target and target.valid and target.visible and target.pos:To2D().onScreen then
					local function CastSlot(slot, hk)
						if GameCanUseSpell(slot) == 0 then
							Control.CastSpell(hk, target)
							-- Riven: Q resetea el básico inmediatamente, no esperamos windup
							if myHero.charName == "Riven" and slot == _Q then
								-- Forzar reset instantáneo del ataque para permitir nuevo AA enseguida
								Attack.Reset = true
								Attack.LocalStart = GameTimer() - 0.25 -- adelanta la ventana para IsReady/IsActive
								-- También marcar PostAttackTimer para que no bloquee siguiente AA
								self.PostAttackTimer = GameTimer() - 0.2
							elseif myHero.charName == "Zeri" and slot == _Q then
								-- Zeri Q debe sincronizar con ataque, no esperar windup
								-- Lanzar Q durante el windup para combo óptimo
								Attack.Reset = true
								Attack.LocalStart = GameTimer() - 0.4 -- Adelantar más para sincronizar con windup de Zeri (0.658s)
								self.PostAttackTimer = GameTimer() - 0.35
							end
							return true
						end
						return false
					end
					-- Prioridad Q > W > E > R según toggles
					if self.Menu.General.CancelQ:Value() and CastSlot(_Q, HK_Q) then goto afterCancel end
					if self.Menu.General.CancelW:Value() and CastSlot(_W, HK_W) then goto afterCancel end
					if self.Menu.General.CancelE:Value() and CastSlot(_E, HK_E) then goto afterCancel end
					if self.Menu.General.CancelR:Value() and CastSlot(_R, HK_R) then goto afterCancel end
				end
				::afterCancel::
			end
			if not Attack:IsActive(0.025) and GameTimer() < self.PostAttackTimer + 1 then
				for i = 1, #self.OnPostAttackTickCb do
					self.OnPostAttackTickCb[i](self.PostAttackTimer)
				end
			end
			local mePos = myHero.pos
			if IsInRange(mePos, mousePos, self.Menu.General.HoldRadius:Value()) then
				if self.CanHoldPosition then
					Control.Hold(self.HoldPositionButton:Key())
				end
				return
			end
			if GetTickCount() > Movement.MoveTimer then

				local args = { Target = nil, Process = true }
				for i = 1, #self.OnMoveCb do
					self.OnMoveCb[i](args)
				end
				if not args.Process then
					return
				end
				if self.ForceMovement ~= nil then
					Control.Move(self.ForceMovement)
					return
				end
				if args.Target ~= nil then
					if args.Target.x then
						args.Target = Vector(args.Target)
					elseif args.Target.pos then
						args.Target = args.Target.pos
					end
					Control.Move(args.Target)
					return
				end
				local pos = IsInRange(mePos, mousePos, 100) and mePos:Extend(mousePos, 100) or nil
				Control.Move(pos)
			end
		end
	end,

	GetSpacingTarget = function(self)
		-- Encuentra el enemigo más cercano para hacer spacing
		local enemies = Object:GetEnemyHeroes(2000, false, true)
		if #enemies == 0 then
			return nil
		end
		
		-- Ordenar por distancia y retornar el más cercano
		table_sort(enemies, function(a, b)
			return GetDistance(myHero.pos, a.pos) < GetDistance(myHero.pos, b.pos)
		end)
		
		return enemies[1]
	end,

	GetSpacingPosition = function(self, target)
		if not target or not Object:IsValid(target) then
			return nil
		end
		
		local myPos = myHero.pos
		local targetPos = target.pos
		local distance = GetDistance(myPos, targetPos)
		
		-- Obtener rangos de ataque
		local myRange = Data:GetAutoAttackRange(myHero, target)
		local enemyRange = Data:GetAutoAttackRange(target, myHero)
		
		-- Margen de seguridad (evitar estar justo en el borde)
		local safetyMargin = 50
		local optimalDistance = myRange - safetyMargin
		
		-- Calcular dirección desde el enemigo hacia nosotros
		local direction = (myPos - targetPos):Normalized()
		
		-- Si el enemigo está dentro de nuestro rango pero nosotros estamos dentro de su rango
		if distance <= myRange and distance <= enemyRange then
			-- Retroceder: alejarse del enemigo
			local retreatDistance = enemyRange - distance + safetyMargin + 50
			local retreatPos = myPos + direction * retreatDistance
			return retreatPos
		-- Si el enemigo está fuera de nuestro rango pero dentro de su rango
		elseif distance > myRange and distance <= enemyRange then
			-- Retroceder más agresivamente
			local retreatDistance = enemyRange - distance + safetyMargin + 100
			local retreatPos = myPos + direction * retreatDistance
			return retreatPos
		-- Si el enemigo está dentro de nuestro rango pero fuera del suyo
		elseif distance <= myRange and distance > enemyRange then
			-- Acercarse ligeramente para mantener distancia óptima
			if distance < optimalDistance then
				-- Ya estamos en posición óptima, no moverse
				return nil
			else
				-- Acercarse un poco para estar en rango óptimo
				local approachDistance = distance - optimalDistance
				local approachPos = myPos - direction * math_min(approachDistance, 50)
				return approachPos
			end
		-- Si el enemigo está fuera de ambos rangos
		elseif distance > myRange and distance > enemyRange then
			-- Acercarse para entrar en nuestro rango
			local approachDistance = distance - optimalDistance
			local approachPos = myPos - direction * math_min(approachDistance, 100)
			return approachPos
		end
		
		return nil
	end,

	Orbwalk = function(self)
		if GameIsChatOpen() or Data:Stop() then
			return
		end
		
		-- Modo Auto Spacing: mantener distancia óptima
		if self:HasMode(ORBWALKER_MODE_SPACING) then
			local spacingTarget = self:GetSpacingTarget()
			if spacingTarget and Object:IsValid(spacingTarget) then
				-- Intentar atacar si está a rango
				if self:Attack(spacingTarget) then
					return
				end
				
				-- Calcular posición de spacing
				local spacingPos = self:GetSpacingPosition(spacingTarget)
				if spacingPos then
					-- Forzar movimiento hacia la posición de spacing
					self.ForceMovement = spacingPos
					self:Move()
					self.ForceMovement = nil
					return
				end
			end
		end
		
		-- Lógica normal de orbwalk
		if not self:Attack(self:GetTarget()) then
			self:Move()
		end
	end,
}

Orbwalker:RegisterMenuKey(ORBWALKER_MODE_COMBO, Menu.Orbwalker.Keys.Combo)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_HARASS, Menu.Orbwalker.Keys.Harass)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_LASTHIT, Menu.Orbwalker.Keys.LastHit)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_LANECLEAR, Menu.Orbwalker.Keys.LaneClear)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_JUNGLECLEAR, Menu.Orbwalker.Keys.Jungle)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_FLEE, Menu.Orbwalker.Keys.Flee)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_SPACING, Menu.Orbwalker.Keys.Spacing)

-- Merge into existing global SDK if present, otherwise create a new SDK table.
_G.SDK = _G.SDK or {}
_G.SDK.OnDraw = _G.SDK.OnDraw or {}
_G.SDK.OnTick = _G.SDK.OnTick or {}
_G.SDK.OnWndMsg = _G.SDK.OnWndMsg or {}
-- SIEMPRE usar nuestros módulos para asegurar compatibilidad con GGAIO y otros scripts
_G.SDK.Menu = Menu
_G.SDK.Color = Color
_G.SDK.Action = Action
_G.SDK.BuffManager = Buff
_G.SDK.Damage = Damage
_G.SDK.Data = Data
_G.SDK.Spell = Spell
_G.SDK.SummonerSpell = SummonerSpell
_G.SDK.ItemManager = Item
_G.SDK.ObjectManager = Object
_G.SDK.TargetSelector = Target
_G.SDK.HealthPrediction = Health
_G.SDK.Cursor = Cursor
_G.SDK.Attack = Attack
-- CRÍTICO: SIEMPRE sobrescribir Orbwalker para asegurar compatibilidad con GGAIO
-- GGAIO.lua espera que _G.SDK.Orbwalker sea nuestro DepressiveOrbwalker
_G.SDK.Orbwalker = Orbwalker
_G.SDK.Cached = Cached
_G.SDK.Movement = Movement
_G.SDK.DAMAGE_TYPE_PHYSICAL = DAMAGE_TYPE_PHYSICAL
_G.SDK.DAMAGE_TYPE_MAGICAL = DAMAGE_TYPE_MAGICAL
_G.SDK.DAMAGE_TYPE_TRUE = DAMAGE_TYPE_TRUE
_G.SDK.ORBWALKER_MODE_NONE = ORBWALKER_MODE_NONE
_G.SDK.ORBWALKER_MODE_COMBO = ORBWALKER_MODE_COMBO
_G.SDK.ORBWALKER_MODE_HARASS = ORBWALKER_MODE_HARASS
_G.SDK.ORBWALKER_MODE_LANECLEAR = ORBWALKER_MODE_LANECLEAR
_G.SDK.ORBWALKER_MODE_JUNGLECLEAR = ORBWALKER_MODE_JUNGLECLEAR
_G.SDK.ORBWALKER_MODE_LASTHIT = ORBWALKER_MODE_LASTHIT
_G.SDK.ORBWALKER_MODE_FLEE = ORBWALKER_MODE_FLEE
_G.SDK.ORBWALKER_MODE_SPACING = ORBWALKER_MODE_SPACING
if _G.SDK.IsRecalling == nil then
	_G.SDK.IsRecalling = function(unit)
		if Buff:HasBuff(unit, "recall") then
			return true
		end
		local as = unit.activeSpell
		if as and as.valid and as.name == "recall" then
			return true
		end
		return false
	end
end

--[[tickTest = 2
drawTest = 2]]
Callback.Add("Load", function()
	ChampionInfo:OnLoad()

	Object:OnLoad()

	local ticks = SDK.OnTick
	local draws = SDK.OnDraw
	local wndmsgs = SDK.OnWndMsg
	if Game.Latency() < 250 then _G.LATENCY = Game.Latency() else _G.LATENCY = Menu.Main.Latency:Value() end

	Callback.Add("Draw", function()
		--[[local as = myHero.activeSpell
		if as and as.valid then
			print(as.name)
			print(as.castEndTime - Game.Timer())
		end
		Buff:Print(myHero)]]
		--[[local target = Target:GetTarget(2000)
		if target then
			if
				Buff:GetBuffDuration(target, "caitlynwsight") > 0.75
				or Buff:HasBuff(target, "eternals_caitlyneheadshottracker")
			then
				print("caitlynwsight  " .. os.clock())
			end
			--print(target.distance .. ' ' .. tostring(myHero.range + myHero.boundingRadius + target.boundingRadius))
			Buff:Print(target)
		end
		Buff:Print(myHero)

		if Buff:HasBuff(myHero, "caitlynpassivedriver") then
			print("myHero caitlynpassivedriver")
		end

		if drawTest ~= 2 then
			print("DRAW")
		end
		drawTest = 1]]
	
		-- Track chat open timer
		if GameIsChatOpen() then
			LastChatOpenTimer = GetTickCount()
		end

		-- OPTIMIZACIÓN: Reset y ticks esenciales
		Cached:Reset()
		Cursor:OnTick()
		Action:OnTick()
		Attack:OnTick()
		Orbwalker:OnTick()
		
		-- OPTIMIZACIÓN: Ejecutar callbacks de tick sin pcall para mayor velocidad
		local tickCount = #ticks
		for i = 1, tickCount do
			local fn = ticks[i]
			if fn then fn() end
		end
		
		-- Solo procesar draws si están habilitados
		if Menu.Main.Drawings.Enabled:Value() then
			Target:OnDraw()
			Cursor:OnDraw()
			Orbwalker:OnDraw()
			Health:OnDraw()
			
			-- OPTIMIZACIÓN: Ejecutar callbacks de draw
			local drawCount = #draws
			for i = 1, drawCount do
				local fn = draws[i]
				if fn then fn() end
			end
			
			-- Mostrar información de debug del sistema de caché inteligente
			if Menu.Main.Drawings.SmartCacheInfo:Value() and FPSOptimizer.enabled and FPSOptimizer.smartCacheEnabled then
				local modeInfo = FPSOptimizer:GetModeInfo()
				local debugText = string_format(
					"Smart Cache: %s | Heroes: %d | Minions: %d | Range: %d | FPS: %.0f",
					modeInfo.mode,
					modeInfo.cachedHeroesCount,
					modeInfo.cachedMinionsCount,
					modeInfo.cacheRange,
					FPSOptimizer.currentFPS
				)
				Draw.Text(debugText, 14, 10, 200)
			end
		end
		--drawTest = 2
	end)

	Callback.Add("Tick", function()
		--[[if tickTest ~= 2 then
			print("TICK")
		end
		tickTest = 1
		if Item:HasItem(myHero, 3031) then
			print("ok " .. os.clock())
		end]]
		--print(myHero.critChance)
		_G.LATENCY = Game.Latency() < 250 and Game.Latency() or Menu.Main.Latency:Value()
		if GameIsChatOpen() then
			LastChatOpenTimer = GetTickCount()
		end

		Cached:Reset()
		ChampionInfo:OnTick()
		SummonerSpell:OnTick()
		Item:OnTick()
		Target:OnTick()
		Health:OnTick()
		--tickTest = 2
	end)

	Callback.Add("WndMsg", function(msg, wParam)
		Data:WndMsg(msg, wParam)
		Spell:WndMsg(msg, wParam)
		Target:WndMsg(msg, wParam)
		Cached:WndMsg(msg, wParam)
		-- OPTIMIZACIÓN: Cachear longitud
		local wndmsgCount = #wndmsgs
		for i = 1, wndmsgCount do
			local fn = wndmsgs[i]
			if fn then fn(msg, wParam) end
		end
	end)

	if _G.Orbwalker then
		_G.Orbwalker.Enabled:Value(false)
		_G.Orbwalker.Drawings.Enabled:Value(false)
	end
	
	-- Asegurar que nuestro Orbwalker esté registrado después de que todos los scripts se carguen
	-- Esto es crítico para compatibilidad con GGAIO y otros scripts que dependen de _G.SDK.Orbwalker
	Callback.Add("Load", function()
		_G.SDK = _G.SDK or {}
		_G.SDK.Orbwalker = Orbwalker
		_G.SDK.Menu = Menu
		_G.SDK.TargetSelector = Target
		_G.SDK.ObjectManager = Object
		_G.SDK.Attack = Attack
		_G.SDK.Data = Data
		_G.SDK.HealthPrediction = Health
		_G.SDK.BuffManager = Buff
		_G.SDK.Damage = Damage
		_G.SDK.Spell = Spell
		_G.SDK.Cursor = Cursor
	end)
end)
