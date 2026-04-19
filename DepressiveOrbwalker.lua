local __name__ = "DepressiveOrbwalker"
local __version__ = 1.8

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
	local cbs = DepressiveOrbUpdate.Callbacks
	for i = 1, #cbs do
		local updater = cbs[i]
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

local DEG_TO_RAD = math_pi / 180.0
local RAD_TO_DEG = 180.0 / math_pi

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
		pos = { x = a, y = nil, z = b }
	elseif a and b then
		pos = { x = a, y = b }
	elseif a then
		pos = a.pos or a
	end
	return pos
end

local function ResolveHandle(unitOrHandle)
	if type(unitOrHandle) == "userdata" then
		return unitOrHandle.handle
	end
	return unitOrHandle
end

local function ResolveObject(unitOrHandle, handles)
	if type(unitOrHandle) == "userdata" then
		return unitOrHandle
	end
	return handles[unitOrHandle]
end

local function GetAttackFlightTime(attacker, targetPos, speed)
	if speed and speed > 0 then
		return GetDistance(attacker.pos, targetPos) / speed
	end
	return 0
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

local AUTO_SAFE_RESET_TIMEOUT = 2000

local FPSOptimizer = {
    enabled = true,
    targetFPS = 60,
    currentFPS = 60,
    frameTime = 0,
    lastFrameTime = 0,

    tickCounter = 0,
    lastTickTime = 0,

    tickInterval = 16,
    cacheInterval = 100,

    highLoadMode = false,
    skipNextTick = false,
    skipNextDraw = false,

    _heroPool = {},
    _minionPool = {},
    _objectPool = {},

    cachedHeroes = {},
    cachedMinions = {},
    cachedObjects = {},
    lastCacheUpdate = 0,

    smartCacheEnabled = true,
    currentOrbwalkerMode = ORBWALKER_MODE_NONE,
    lastModeCheck = 0,
    modeCheckInterval = 50,

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

        if self.lastFrameTime > 0 then
            self.frameTime = currentTime - self.lastFrameTime
            self.currentFPS = math_min(1000 / math_max(self.frameTime, 1), 120)
        end
        self.lastFrameTime = currentTime

        if self.currentFPS < 30 then
            self.highLoadMode = true
            self.tickInterval = 33
            self.cacheInterval = 200
        elseif self.currentFPS < 45 then
            self.highLoadMode = true
            self.tickInterval = 25
            self.cacheInterval = 150
        else
            self.highLoadMode = false
            self.tickInterval = 16
            self.cacheInterval = 100
        end

        local pingMs = (Game.Latency and Game.Latency() or 0)
        if pingMs >= 120 then
            self.tickInterval = math_max(10, self.tickInterval - 6)
        elseif pingMs >= 70 then
            self.tickInterval = math_max(12, self.tickInterval - 3)
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

    WipeTable = function(self, t)
        for i = #t, 1, -1 do
            t[i] = nil
        end
    end,

    UpdateObjectCache = function(self)
        local currentTime = GetTickCount()
        if currentTime - self.lastCacheUpdate < self.cacheInterval then
            return
        end
        self.lastCacheUpdate = currentTime

        local config = self:GetCacheConfig()
        local myPos = myHero.pos
        local cacheRangeSq = config.cacheRange * config.cacheRange

        local heroes = self.cachedHeroes
        if config.cacheHeroes then
            self:WipeTable(heroes)
            local heroCount = GameHeroCount()
            local hc = 0
            for i = 1, heroCount do
                local hero = GameHero(i)
                if hero and hero.valid and not hero.dead and hero.isEnemy then
                    hc = hc + 1
                    heroes[hc] = hero
                end
            end
        else
            self:WipeTable(heroes)
        end

        local minions = self.cachedMinions
        if config.cacheMinions then
            self:WipeTable(minions)
            local minionCount = GameMinionCount()
            local mc = 0
            for i = 1, minionCount do
                local minion = GameMinion(i)
                if minion and minion.valid and not minion.dead and minion.isEnemy then
                    if GetDistanceSq(minion.pos, myPos) <= cacheRangeSq then
                        mc = mc + 1
                        minions[mc] = minion
                    end
                end
            end
        else
            self:WipeTable(self.cachedMinions)
        end
    end,

    GetCachedHeroes = function(self)
        local config = self:GetCacheConfig()
        if config.cacheHeroes then
            return self.cachedHeroes
        end
        return self._heroPool
    end,

    GetCachedMinions = function(self)
        local config = self:GetCacheConfig()
        if config.cacheMinions then
            return self.cachedMinions
        end
        return self._minionPool
    end,

    OptimizeLoop = function(self, collection, maxProcessPerTick)
        maxProcessPerTick = maxProcessPerTick or (self.highLoadMode and 3 or 10)

        local collectionSize = #collection
        if collectionSize <= maxProcessPerTick then
            return collection
        end

        local chunks = math_ceil(collectionSize / maxProcessPerTick)
        local startIdx = ((self.tickCounter - 1) % chunks) * maxProcessPerTick + 1
        local endIdx = math_min(startIdx + maxProcessPerTick - 1, collectionSize)

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

		local drawRangeSq = 1690000
		local textMergeRangeSq = 2500
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
			local drawRangeSq = 1300 * 1300
			local textMergeRangeSq = 50 * 50
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
		local debugRangeSq = 1000 * 1000
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
		elseif enemy then
		end
		if enemy then
		end
	end,

	OnTick = function(self)
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
		local currentTime = GetTickCount()
		if self.lastGwenMistDetection and currentTime - self.lastGwenMistDetection < 200 then
			return
		end
		self.lastGwenMistDetection = currentTime

		local unitPos = unit.pos
		local count = GameObjectCount()
		if count and count > 0 and count < 100000 then
			local maxObjects = FPSOptimizer.highLoadMode and 20 or 100
			local processed = 0

			for i = 1, math_min(count, maxObjects) do
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
				local detectRangeSq = 1000 * 1000
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
		if(myHero.range == 575) then
			commandRange = 830
		end
		local myPos = myHero.pos
		local commandRangeSq = commandRange * commandRange
		local objRangeSq = 350 * 350
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

		for _, key in pairs(oKeys) do
			if (msg == KEY_DOWN and wParam == key) then
				self.TempCacheBuffer = {m = GameTimer(), w = GameTimer(), t = GameTimer(), p = GameTimer()}
				return
			end
		end

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
		FPSOptimizer:Update()
		FPSOptimizer:UpdateObjectCache()

		local buffs = self.Buffs
		local k = next(buffs)
		while k do
			local nextK = next(buffs, k)
			buffs[k] = nil
			k = nextK
		end

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
		if FPSOptimizer.enabled and FPSOptimizer.smartCacheEnabled then
			local config = FPSOptimizer:GetCacheConfig()

			if not config.cacheHeroes then
				local result = {}
				for i = 1, #self.ExtraHeroes do
					table_insert(result, self.ExtraHeroes[i])
				end
				return result
			end

			if not FPSOptimizer:ShouldUpdateCache() and #FPSOptimizer.cachedHeroes > 0 then
				local result = {}
				for i = 1, #FPSOptimizer.cachedHeroes do
					local hero = FPSOptimizer.cachedHeroes[i]
					table_insert(result, hero)
				end

				for i = 1, #self.ExtraHeroes do
					table_insert(result, self.ExtraHeroes[i])
				end
				return result
			end
		end

		if not self.HeroesSaved then
			self.HeroesSaved = true
			self.ExtraHeroesSaved = true
			local count = GameHeroCount()
			if count and count > 0 and count < 1000 then
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
		if FPSOptimizer.enabled and FPSOptimizer.smartCacheEnabled then
			local config = FPSOptimizer:GetCacheConfig()

			if not config.cacheMinions then
				local result = {}

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

				for i = 1, #self.ExtraUnits do
					table_insert(result, self.ExtraUnits[i])
				end
				return result
			end

			if not FPSOptimizer:ShouldUpdateCache() and #FPSOptimizer.cachedMinions > 0 then
				local result = {}
				for i = 1, #FPSOptimizer.cachedMinions do
					table_insert(result, FPSOptimizer.cachedMinions[i])
				end

				for i = 1, #self.ExtraUnits do
					table_insert(result, self.ExtraUnits[i])
				end
				return result
			end
		end

		if not self.MinionsSaved then
			self.MinionsSaved = true
			self.ExtraUnitsSaved = true
			local cachedMinions = self:FetchCachedMinions()
			local count = #cachedMinions
			if count and count > 0 and count < 1000 then
				local maxProcess = FPSOptimizer.highLoadMode and 10 or count
				local processed = 0
				local enemyMinionCount = 0

				for i = 1, count do
					local o = cachedMinions[i]
					if o and o.valid and o.visible and o.isTargetable and not o.dead then
						if not o.isImmortal or o.charName:lower() == "sru_atakhan" then
							if o.isEnemy then
								table_insert(self.Minions, o)
								enemyMinionCount = enemyMinionCount + 1
							elseif processed < maxProcess then
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
        self.Orbwalker.General:MenuElement({id = 'UnderMouseCast', name = 'Under-mouse Force Attack', value = false})
        self.Orbwalker.General:MenuElement({id = 'UnderMouseKey', name = 'Under-mouse Force Key', key = string.byte('C')})
        self.Orbwalker.General:MenuElement({id = 'FastKiting', name = 'Fast Kiting', value = true})
        self.Orbwalker.General:MenuElement({id = 'LaneClearHeroes', name = 'LaneClear Heroes', value = true})
        self.Orbwalker.General:MenuElement({id = 'AttackRange', name = 'AARange = RealRange - X', value = 35, min = 0, max = 35, step = 1})
        self.Orbwalker.General:MenuElement({id = 'HoldRadius', name = 'Hold Radius', value = 0, min = 0, max = 250, step = 10})
        self.Orbwalker.General:MenuElement({id = 'ExtraWindUpTime', name = 'Extra WindUpTime', value = 0, min = -25, max = 75, step = 5})

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

Menu:CreateMain()
Menu:CreateTarget()
Menu:CreateOrbwalker()
Menu:CreateDrawings()
Menu:CreateGeneral()

if Menu.Main.FPSOptimization and Menu.Main.FPSOptimization.SmartCacheConfig then
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
	PrepHitable = Draw.Color(255, 100, 200, 255),
	drawcolor1 = Draw.Color(150, 255, 255, 255),
	drawcolor2 = Draw.Color(150, 239, 159, 55),
}

local DrawThrottle = {
	lastDrawTime = {},
	throttleDelay = 16,

	CanDraw = function(self, key)
		local now = GetTickCount()
		if self.lastDrawTime[key] == nil or (now - self.lastDrawTime[key]) >= self.throttleDelay then
			self.lastDrawTime[key] = now
			return true
		end
		return false
	end,
}

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

		[3091] = function(args)
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

		[3094] = function(args)
			if Buff:GetBuffStacks(args.From, "itemstatikshankcharge") == 100 then
				args.RawMagical = args.RawMagical + 40
			end
		end,

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
					args.RawMagical = 9999
				end
			end
			if args.Target.team == 300 then
				args.RawMagical = math_min(300, args.RawMagical)
			end
		end,
		["Jhin"] = function(args)
			if myHero.hudAmmo==1 then
				args.CriticalStrike = true
				args.CalculatedPhysical = args.CalculatedPhysical
					+ math_min(0.25, 0.1 + 0.05 * math_ceil(args.From.levelData.lvl / 5))
						* (args.Target.maxHealth - args.Target.health)*0.66
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
			local JhinAD= ((((59+4.7*(myHero.levelData.lvl-1)*(0.7025+(0.0175*(myHero.levelData.lvl-1)))))*(levelAD[math_max(math_min(myHero.levelData.lvl, 18), 1)]+myHero.critChance*0.3+0.25*(myHero.attackSpeed-1)))+myHero.bonusDamage)
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
			local JhinAD= ((((59+4.7*(myHero.levelData.lvl-1)*(0.7025+(0.0175*(myHero.levelData.lvl-1)))))*(levelAD[math_max(math_min(myHero.levelData.lvl, 18), 1)]+myHero.critChance*0.3+0.25*(myHero.attackSpeed-1)))+myHero.bonusDamage)
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
			then
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

		["Nautilus"] = {{ Slot = _W, Key = HK_W }},
		["Nidalee"] = {{ Slot = _Q, Key = HK_Q, Name = "Takedown" }},
		["Nasus"] = {{ Slot = _Q, Key = HK_Q }},
		["Olaf"] = {{ Slot = _W, Key = HK_W }},
		["RekSai"] = {{ Slot = _Q, Key = HK_Q, Name = "RekSaiQ" }},
		["Renekton"] = {{ Slot = _W, Key = HK_W }},
		["Rengar"] = {{ Slot = _Q, Key = HK_Q }},

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

		for _cAri = 1, #championAttackResets do
			local attackReset = championAttackResets[_cAri]
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
						self.AttackResetSuccess = true
						self.AttackResetTimeout = GetTickCount()
						self.AttackResetTimer = GetTickCount()
						return true
					end
					if self.AttackResetSuccess and GetTickCount() > self.AttackResetTimeout + 200 then
						self.AttackResetSuccess = false
					end
					return false
				end
			elseif Buff:ContainsBuffs(myHero, self.AttackResetBuff)  then
				if not self.AttackResetSuccess then
					self.AttackResetSuccess = true

					return true
				end
				return false
			end
			if self.AttackResetSuccess then
				self.AttackResetSuccess = false
			end
			return false
		end
		if self.AttackResetSuccess then
			self.AttackResetSuccess = false

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
							if Control.CastSpell(self.HK, unit.pos) then
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
							if Control.CastSpell(self.HK, unit.pos) then
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

	Spell.ControlKeyDown(key)
end

SummonerSpell = {
	SpellNames = {
		"SummonerHeal",
		"SummonerHaste",
		"SummonerBarrier",
		"SummonerExhaust",
		"SummonerFlash",
		"SummonerTeleport",
		"SummonerSmite",
		"SummonerBoost",
		"SummonerDot",
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
		return
	end,
}

Item = {
	ItemQss = { 6035, 3139, 3140 },
	CachedItems = {},
	Hotkey = nil,
	CleanseStartTime = GetTickCount(),

	OnTick = function(self)
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

Object = {
	UndyingBuffs = {
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

		local cachedminions = Cached:GetMinions()

		if range and range > 1500 then
			local count = GameMinionCount()
			if count and count > 0 then
				local myPos = myHero.pos
				local rangeSq = range and (range + (bbox and 100 or 0)) * (range + (bbox and 100 or 0)) or nil
				for i = 1, count do
					local obj = GameMinion(i)
					if obj and obj.valid and obj.visible and obj.isTargetable and not obj.dead and obj.isEnemy then
						if not immortal or not obj.isImmortal then
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
			local myPos = myHero.pos
			for i = 1, #cachedminions do
				local obj = cachedminions[i]
				if obj and obj.isEnemy and (not immortal or not obj.isImmortal) then
					if not range then
						table_insert(result, obj)
					else
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
			local maxRangeSq = 150 * 150
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

			local extraRange = enemy.boundingRadius
			if	Object.IsCaitlyn then
				if _G.CTRLCait==nil	and (
						Buff:GetBuffDuration(enemy, "caitlynwsight") > 0.75
						or Buff:HasBuff(enemy, "eternals_caitlyneheadshottracker")
					)
				then
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
				local _plants = Cached:GetPlants()
				for _pi = 1, #_plants do local obj = _plants[_pi]
					if obj and obj.charName:lower() == "gangplankbarrel" then
						table.insert(validBarrels, obj)
					end
				end
				for _bi = 1, #validBarrels do local barrel = validBarrels[_bi]
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

Object:OnEnemyHeroLoad(function(args)
    local priority = Data:GetHeroPriority(args.charName) or 1
    Target.MenuPriorities:MenuElement({id = args.charName, name = args.charName, value = priority, min = 1, max = 5, step = 1})
end)

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
		local aMultiplier = 1.75 - (Target:GetPriority(a) * 0.15) +(distmultiplier*(math_max(math_min(a.distance,maxdist),mindist)/math_max(math_min(b.distance,maxdist),mindist)))
		local bMultiplier = 1.75 - (Target:GetPriority(b) * 0.15) +(distmultiplier*(math_max(math_min(b.distance,maxdist),mindist)/math_max(math_min(a.distance,maxdist),mindist)))

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
		local params = Target.MenuPriorities
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
			return a.health < b.health
		end

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
	InFlightMissiles = {},
	InFlightDamage = {},
	Spells = {},
	LastHitHandle = 0,
	LaneClearHandle = 0,

	AddSpell = function(self, class)
		table_insert(self.Spells, class)
	end,

	OnTick = function(self)
		local attackRange, structures, pos, speed, windup, time, anim
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
		for i = 1, #self.Spells do
			self.Spells[i]:Reset()
		end
		if Orbwalker.IsNone or Orbwalker.Modes[ORBWALKER_MODE_COMBO] then
			return
		end
		self.IsLastHitable = false
		self.ShouldRemoveObjects = true
		self.StaticAutoAttackDamage = Damage:GetStaticAutoAttackDamage(myHero, true)

		local myPos = myHero.pos
		attackRange = myHero.range + myHero.boundingRadius
		local filterRangeSq = 2000 * 2000
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
		local timer = GameTimer()
		local handles = self.Handles
		local activeAttacks = self.ActiveAttacks
		for handle, obj in pairs(handles) do
			local s = obj.activeSpell
			if s and s.valid and s.isAutoAttack then
				local endTime = s.endTime
				local animation = s.animation
				local windup = s.windup
				local targetHandle = ResolveHandle(s.target)
				if endTime and animation and windup and targetHandle and endTime > timer then
					activeAttacks[handle] = {
						Speed = s.speed or 0,
						EndTime = endTime,
						AnimationTime = animation,
						WindUpTime = windup,
						StartTime = endTime - animation,
						Target = targetHandle,
					}
				end
			end
		end
		for handle, obj in pairs(self.AllyMinionsHandles) do
			if obj and obj.valid and obj.visible and obj.alive then
				handles[handle] = obj
				local s = obj.activeSpell
				if s and s.valid and s.isAutoAttack then
					local endTime = s.endTime
					local animation = s.animation
					local windup = s.windup
					local targetHandle = ResolveHandle(s.target)
					if endTime and animation and windup and targetHandle and endTime > timer then
						activeAttacks[handle] = {
							Speed = s.speed or 0,
							EndTime = endTime,
							AnimationTime = animation,
							WindUpTime = windup,
							StartTime = endTime - animation,
							Target = targetHandle,
						}
					end
				elseif obj.attackData and obj.attackData.target then
					local ad = obj.attackData
					local targetHandle = ResolveHandle(ad.target)
					if ad.endTime and ad.animationTime and ad.windUpTime and targetHandle and timer - ad.endTime < 1.25 then
						activeAttacks[handle] = {
							Speed = ad.projectileSpeed or 0,
							EndTime = ad.endTime,
							AnimationTime = ad.animationTime,
							WindUpTime = ad.windUpTime,
							StartTime = ad.endTime - ad.animationTime,
							Target = targetHandle,
						}
					end
				end
			end
		end
		self:UpdateMissiles()
		pos = myHero.pos
		speed = Attack:GetProjectileSpeed()
		windup = Attack:GetWindup()
		time = windup - self.ExtraFarmDelay:Value() * 0.001
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

		for i = 1, #self.Spells do
			self.Spells[i]:Tick()
		end
	end,

	OnDraw = function(self)
		local drawings = self.MenuDrawings
		if not drawings.Enabled:Value() or not drawings.LastHittableMinions:Value() then
			return
		end

		local farmMinions = self.FarmMinions
		local farmCount = #farmMinions

		if farmCount == 0 then
			return
		end

		local colorLastHit = Color.LastHitable
		local colorAlmost = Color.AlmostLastHitable
		local colorPrep = Color.PrepHitable

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
						elseif args.PrepHitable then
							Draw.Circle(pos, radius, 1, colorPrep)
						elseif args.AlmostLastHitable then
							Draw.Circle(pos, radius, 1, colorAlmost)
						end
					end
				end
			end
		end
	end,

	UpdateMissiles = function(self)
		local timer = GameTimer()
		self.InFlightDamage = {}
		for nid, m in pairs(self.InFlightMissiles) do
			if timer >= m.landTime + 0.3 then
				self.InFlightMissiles[nid] = nil
			end
		end
		if Game.MissileCount and Game.Missile then
			local count = Game.MissileCount()
			local handles = self.Handles
			for i = 1, count do
				local mis = Game.Missile(i)
				if mis and mis.missileData then
					local md = mis.missileData
					local nid = mis.networkID or 0
					if nid > 0 and not self.InFlightMissiles[nid] then
						local ownerHandle = ResolveHandle(md.owner)
						local targetHandle = ResolveHandle(md.target)
						local ownerObj = ownerHandle == myHero.handle and myHero or ResolveObject(md.owner, handles)
						local targetObj = ResolveObject(md.target, handles)
						if ownerHandle and targetHandle and ownerObj and targetObj and md.speed and md.speed > 0 then
							local missileName = md.name or ""
							local isBasicAttack = missileName == "" or missileName:lower():find("basicattack")
							if isBasicAttack and ownerObj.team == Data.AllyTeam and targetObj.team == Data.EnemyTeam then
								local damage = Damage:GetAutoAttackDamage(ownerObj, targetObj) or 0
								if damage > 0 then
									self.InFlightMissiles[nid] = {
										ownerHandle = ownerHandle,
										targetHandle = targetHandle,
										landTime = timer + (GetDistance(mis.pos, targetObj.pos) / md.speed),
										damage = damage,
									}
								end
							end
						end
					end
				end
			end
		end
		for nid, m in pairs(self.InFlightMissiles) do
			if m.landTime > timer then
				local bucket = self.InFlightDamage[m.targetHandle]
				if not bucket then
					bucket = {}
					self.InFlightDamage[m.targetHandle] = bucket
				end
				bucket[#bucket + 1] = {
					landTime = m.landTime,
					damage = m.damage,
					ownerHandle = m.ownerHandle,
				}
			end
		end
	end,

	GetInFlightDamageBefore = function(self, targetHandle, beforeTime)
		local bucket = self.InFlightDamage[targetHandle]
		if not bucket then
			return 0
		end
		local timer = GameTimer()
		local total = 0
		for i = 1, #bucket do
			local m = bucket[i]
			local activeAttack = self.ActiveAttacks[m.ownerHandle]
			local isTrackedByActiveAttack = activeAttack and activeAttack.Target == targetHandle
			if not isTrackedByActiveAttack and m.landTime > timer and m.landTime - timer < beforeTime then
				total = total + m.damage
			end
		end
		return total
	end,

	HasInFlightMissileBefore = function(self, ownerHandle, targetHandle, beforeTime)
		local bucket = self.InFlightDamage[targetHandle]
		if not bucket then
			return false
		end
		local timer = GameTimer()
		for i = 1, #bucket do
			local m = bucket[i]
			if m.ownerHandle == ownerHandle and m.landTime > timer and m.landTime - timer < beforeTime then
				return true
			end
		end
		return false
	end,

	GetPrediction = function(self, target, time)
		local timer, pos, team, handle, health, attackers
		timer = GameTimer()
		pos = target.pos
		handle = target.handle
		if self.TargetsHealth[handle] == nil then
			self.TargetsHealth[handle] = target.health + Data:GetTotalShield(target)
		end
		health = self.TargetsHealth[handle]
		for attackerHandle, attack in pairs(self.ActiveAttacks) do
			local c = 0
			local attacker = self.Handles[attackerHandle]
			if attacker and attack.Target == handle then
				local speed, startT, flyT, endT, damage
				speed = attack.Speed
				startT = attack.StartTime
				flyT = speed > 0 and GetDistance(attacker.pos, pos) / speed or 0
				endT = (startT + attack.WindUpTime + flyT) - timer
				if endT > 0 and endT < time then
					c = c + 1
					if self.AttackersDamage[attackerHandle] == nil then
						self.AttackersDamage[attackerHandle] = {}
					end
					if self.AttackersDamage[attackerHandle][handle] == nil then
						self.AttackersDamage[attackerHandle][handle] = Damage:GetAutoAttackDamage(attacker, target)
					end
					damage = self.AttackersDamage[attackerHandle][handle]
					health = health - damage
				end
			end
		end
		return health
	end,

	LocalGetPrediction = function(self, target, time)
		local timer, pos, team, handle, health, attackers, turretAttacked
		turretAttacked = false
		timer = GameTimer()
		pos = target.pos
		handle = target.handle
		if self.TargetsHealth[handle] == nil then
			self.TargetsHealth[handle] = target.health + Data:GetTotalShield(target)
		end
		health = self.TargetsHealth[handle]
		local handles = {}
		for attackerHandle, attack in pairs(self.ActiveAttacks) do
			local attacker = self.Handles[attackerHandle]
			if attacker and attacker.valid and attacker.visible and attacker.alive and attack.Target == handle then
				local speed, startT, flyT, endT, damage
				speed = attack.Speed
				startT = attack.StartTime
				flyT = speed > 0 and GetDistance(attacker.pos, pos) / speed or 0
				endT = (startT + attack.WindUpTime + flyT) - timer
				if endT < 0 and timer - attack.EndTime < 1.25 then
					endT = attack.WindUpTime + flyT
					endT = timer > attack.EndTime and endT or endT + (attack.EndTime - timer)
					startT = timer > attack.EndTime and timer or attack.EndTime
				end
				if endT > 0 and endT < time then
					handles[attackerHandle] = true
					if self.AttackersDamage[attackerHandle] == nil then
						self.AttackersDamage[attackerHandle] = {}
					end
					if self.AttackersDamage[attackerHandle][handle] == nil then
						self.AttackersDamage[attackerHandle][handle] = Damage:GetAutoAttackDamage(attacker, target)
					end
					damage = self.AttackersDamage[attackerHandle][handle]
					local c = 1
					while endT < time do
						if attackerHandle == self.AllyTurretHandle then
							turretAttacked = true
						else
							health = health - damage
						end
						endT = (startT + attack.WindUpTime + flyT + c * attack.AnimationTime) - timer
						c = c + 1
						if c > 10 then
							health = self.TargetsHealth[handle]
							break
						end
					end
				end
			end
		end
		for attackerHandle, obj in pairs(self.AllyMinionsHandles) do
			if handles[attackerHandle] == nil and obj and obj.valid and obj.visible and obj.alive then
				local aaData = obj.attackData
				local isMoving = obj.pathing.hasMovePath
				if
					aaData == nil
					or aaData.target == nil
					or self.Handles[aaData.target] == nil
					or isMoving
					or self.ActiveAttacks[attackerHandle] == nil
				then
					local distance = GetDistance(obj.pos, pos)
					local range = Data:GetAutoAttackRange(obj, target)
					local extraRange = isMoving and 250 or 0
					if distance < range + extraRange then
						local speed, flyT, endT, damage
						speed = aaData.projectileSpeed
						distance = distance > range and range or distance
						flyT = speed > 0 and distance / speed or 0
						endT = aaData.windUpTime + flyT
						if endT < time then
							if self.AttackersDamage[attackerHandle] == nil then
								self.AttackersDamage[attackerHandle] = {}
							end
							if self.AttackersDamage[attackerHandle][handle] == nil then
								self.AttackersDamage[attackerHandle][handle] = Damage:GetAutoAttackDamage(obj, target)
							end
							damage = self.AttackersDamage[attackerHandle][handle]
							local c = 1
							while endT < time do
								health = health - damage
								endT = aaData.windUpTime + flyT + c * aaData.animationTime
								c = c + 1
								if c > 10 then
									health = self.TargetsHealth[handle]
									break
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
		self.TargetsHealth[handle] = currentHealth
		health = self:GetPrediction(target, time)
		lastHitable = false
		almostLastHitable = false
		almostalmost = false
		unkillable = false
		if (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(target)) then
			damage=({50, 67, 84, 101, 118})[myHero:GetSpellData(_W).level] + 0.6 * myHero.ap
		end

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

		if health - damage < 0 then
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

		if self.StrictLastHit and self.StrictLastHit:Value() then
			return {
				LastHitable = lastHitable,
				Unkillable = unkillable,
				AlmostLastHitable = false,
				PredictedHP = health,
				Minion = target,
				AlmostAlmost = false,
				Time = time,
			}
		end
		local turretAttack, extraTime, almostHealth, almostAlmostHealth, turretAttacked
		turretAttack = self.AllyTurret ~= nil and self.AllyTurret.attackData or nil
		extraTime = (1.5 - anim) * 0.3
		extraTime = extraTime < 0 and 0 or extraTime
		almostHealth, turretAttacked = self:LocalGetPrediction(target, anim + time + extraTime)
		if (target.charName == "SRU_ChaosMinionSiege" or target.charName == "SRU_OrderMinionSiege") then
			almostHealth, turretAttacked = self:LocalGetPrediction(target, anim + time*1.4 + extraTime)
		end
		if almostHealth < 0 then
			almostLastHitable = true
			self.ShouldWaitTime = GetTickCount()
		elseif almostHealth - damage < 0 then
			almostLastHitable = true
		elseif currentHealth ~= almostHealth then
			almostAlmostHealth, turretAttacked = self:LocalGetPrediction(
				target,
				1.25 * anim + 1.25 * time + extraTime
			)
			if almostAlmostHealth - damage < 0 then
				almostalmost = true
			end
		end

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
			local nearTurret = true
			local isTurretTarget = turretAttack and turretAttack.target == handle or false

			local turretAnimTime = (turretAttack and turretAttack.animationTime and turretAttack.animationTime > 0)
				and turretAttack.animationTime or 1.20048
			local turretWindUp = (turretAttack and turretAttack.windUpTime and turretAttack.windUpTime > 0)
				and turretAttack.windUpTime or 0.16686
			local turretProjSpeed = (turretAttack and turretAttack.projectileSpeed and turretAttack.projectileSpeed > 0)
				and turretAttack.projectileSpeed or 1200
			local turretStartTime = (turretAttack and turretAttack.endTime)
				and (turretAttack.endTime - turretAnimTime) or timer
			local turretFlyTime = (self.AllyTurret and self.AllyTurret.valid)
				and (GetDistance(self.AllyTurret.pos, target.pos) / turretProjSpeed) or 0
			local turretDamage = (self.AllyTurret and self.AllyTurret.valid)
				and Damage:GetAutoAttackDamage(self.AllyTurret, target) or 0

			local prepHitable = false
			if turretDamage > 0 and self.AllyTurret and self.AllyTurret.valid then
				local myDamage = damage
				local turretArrival = turretStartTime + turretWindUp + turretFlyTime
				local simHealth = currentHealth
				if turretArrival > timer then
					simHealth = self:LocalGetPrediction(target, turretArrival - timer)
				end

				while turretArrival < timer and turretArrival + turretAnimTime * 10 > timer do
					turretArrival = turretArrival + turretAnimTime
				end

				for shot = 1, 6 do
					local arrivalTime = turretArrival + (shot - 1) * turretAnimTime
					local timeFromNow = arrivalTime - timer
					if timeFromNow < 0 then
						simHealth = simHealth - turretDamage
					elseif timeFromNow < 8.0 then
						local healthAfterShot = simHealth - turretDamage
						if healthAfterShot > 0 and healthAfterShot <= myDamage then
							if not lastHitable and simHealth > myDamage then
								local healthAfterMyHit = simHealth - myDamage
								if healthAfterMyHit > 0 then
									local healthAfterMyHitAndTurret = healthAfterMyHit - turretDamage
									if healthAfterMyHitAndTurret > 0 and healthAfterMyHitAndTurret <= myDamage then
										prepHitable = true
									end
								end
							end
						elseif healthAfterShot <= 0 and simHealth > myDamage then
							local healthAfterMyHit = simHealth - myDamage
							if healthAfterMyHit > 0 and healthAfterMyHit > turretDamage then
								local afterBoth = healthAfterMyHit - turretDamage
								if afterBoth > 0 and afterBoth <= myDamage then
									prepHitable = true
								end
							end
						end
						simHealth = simHealth - turretDamage
					end
					if simHealth <= 0 then break end
				end
			end

			local turretHits = 0
			if turretDamage > 0 and target.maxHealth > 0 then
				turretHits = math_ceil(target.maxHealth / turretDamage)
				turretHits = math_min(turretHits, 10) - 1
			end

			return {
				LastHitable = lastHitable,
				Unkillable = unkillable,
				AlmostLastHitable = almostLastHitable,
				PredictedHP = health,
				Minion = target,
				AlmostAlmost = almostalmost,
				Time = time,
				PrepHitable = prepHitable,
				NearTurret = nearTurret,
				IsTurretTarget = isTurretTarget,
				TurretHits = turretHits,
				TurretDamage = turretDamage,
				TurretFlyDelay = turretFlyTime,
				TurretStart = turretStartTime,
				TurretWindup = turretWindUp,
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
			PrepHitable = false,
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

	GetLastHitTarget = function(self)
		local min = 10000000
		local result = nil
		for i = 1, #self.FarmMinions do
			local minion = self.FarmMinions[i]
			if
				Object:IsValid(minion.Minion)
				and minion.LastHitable
				and (minion.PredictedHP < min or (minion.Minion.charName == "SRU_ChaosMinionSiege" or minion.Minion.charName == "SRU_OrderMinionSiege"))
				and (Data:IsInAutoAttackRange(myHero, minion.Minion) or (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(minion.Minion)))
			then
				min = minion.PredictedHP
				result = minion.Minion
				self.LastHitHandle = result.handle
				if minion.Minion.charName == "SRU_ChaosMinionSiege" or minion.Minion.charName == "SRU_OrderMinionSiege" then
					break
				end
			end
		end
		return result
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
		local laneMinion = nil
		local num = 10000
		for i = 1, #self.FarmMinions do
			local minion = self.FarmMinions[i]
			if Data:IsInAutoAttackRange(myHero, minion.Minion) or (Object.IsAzir and ChampionInfo:IsInAzirSoldierRange(minion.Minion)) then
				if minion.PredictedHP < num and not minion.AlmostAlmost and not minion.AlmostLastHitable then
					num = minion.PredictedHP
					laneMinion = minion.Minion
				end
			end
		end
		return laneMinion
	end,

	GetLaneClearTarget = function(self)
		local LastHitPriority = Menu.Orbwalker.Farming.LastHitPriority:Value()
		local LaneClearHeroes = Menu.Orbwalker.General.LaneClearHeroes:Value()
		local structure = #self.EnemyStructuresInAttackRange > 0 and self.EnemyStructuresInAttackRange[1] or nil
		local other = #self.EnemyWardsInAttackRange > 0 and self.EnemyWardsInAttackRange[1] or nil
		if structure ~= nil then
			if not LastHitPriority then
				return structure
			end
			if self.IsLastHitable then
				return self:GetLastHitTarget()
			end
			if other ~= nil then
				return other
			end
			if LastHitPriority and not self:ShouldWait() then
				return structure
			end
		else
			if not LastHitPriority and LaneClearHeroes then
				local hero = Target:GetComboTarget()
				if hero ~= nil then
					return hero
				end
			end
			if self.IsLastHitable then
				return self:GetLastHitTarget()
			end
			if self:ShouldWait() then
				return nil
			end
			if LastHitPriority and LaneClearHeroes then
				local hero = Target:GetComboTarget()
				if hero ~= nil then
					return hero
				end
			end
			local plants = self:GetPlantsTarget()
			if plants ~= nil then
				return plants
			end
			local laneMinion = self:GetLaneMinion()
			if laneMinion ~= nil then
				self.LaneClearHandle = laneMinion.handle
				return laneMinion
			end
			if other ~= nil then
				return other
			end
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
				local k = nil
				if AttackKey and type(AttackKey.Key) == 'function' then
					local ok, v = pcall(AttackKey.Key, AttackKey)
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
			local isTargetUnitSpell = (not b and a and a.pos ~= nil)
			if Cursor.Step > 0 and not isTargetUnitSpell then
				return false
			end

			if not b then
				if not (Vector(pos):To2D().onScreen) then return false end
			end

			if a and (a.x or a[1]) then
				if (GetDistance(Game.mousePos(), pos)) < 2 then
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

SmoothMouse = {
    isMoving = false,
    startPos = {x = 0, y = 0},
    targetPos = {x = 0, y = 0},
    currentPos = {x = 0, y = 0},
    startTime = 0,
    totalDistance = 0,
    speed = 3.5,
    acceleration = 1.2,
    movementType = "normal",
    onCompleteCallback = nil,
	lastCursorSetTick = 0,
	minSetIntervalMs = 3,
	minTeleportDistance = 3,

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

        local dx = targetX - self.startPos.x
        local dy = targetY - self.startPos.y
        self.totalDistance = math_sqrt(dx * dx + dy * dy)

	self.speed = math_max(0.5, MenuSmoothSpeed:Value())
	self.acceleration = math_max(0.8, MenuSmoothAcceleration:Value())

		if movementType == "toTarget" then
			self.speed = self.speed * 1.8
		elseif movementType == "return" then
			self.speed = self.speed * 0.9
		end

		if self.totalDistance <= self.minTeleportDistance then
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

        local perpX = -dy / self.totalDistance
        local perpY = dx / self.totalDistance

        local random1 = (math_random(-randomness, randomness) / 100.0) * self.totalDistance
        local random2 = (math_random(-randomness, randomness) / 100.0) * self.totalDistance

        self.controlPoint1.x = self.startPos.x + dx * 0.25 + perpX * random1
        self.controlPoint1.y = self.startPos.y + dy * 0.25 + perpY * random1

        self.controlPoint2.x = self.startPos.x + dx * 0.75 + perpX * random2
        self.controlPoint2.y = self.startPos.y + dy * 0.75 + perpY * random2
    end,

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

		local normalizedTime
		if baseTime <= 0 or baseTime ~= baseTime then
			normalizedTime = 1
		else
			normalizedTime = elapsed / baseTime
		end

	if normalizedTime >= 0.99 then
            Control.SetCursorPos(math_floor(self.targetPos.x), math_floor(self.targetPos.y))
            self.isMoving = false

            if self.onCompleteCallback then
                self.onCompleteCallback()
                self.onCompleteCallback = nil
            end

            return true
        end

        local t = normalizedTime
        if self.acceleration > 1.0 then
            t = t < 0.5 and
                (self.acceleration * t * t) / (2 * ((self.acceleration - 1) * t + 1)) or
                1 - (self.acceleration * (1 - t) * (1 - t)) / (2 * ((self.acceleration - 1) * (1 - t) + 1))
        end

        local pos = self:BezierLerp(math_min(t, 1.0))

		local now = GetTickCount()
		if (now - self.lastCursorSetTick) >= self.minSetIntervalMs then
			Control.SetCursorPos(math_floor(pos.x + 0.5), math_floor(pos.y + 0.5))
			self.lastCursorSetTick = now
		end
        self.currentPos = pos

        return false
    end,

    IsMoving = function(self)
        return self.isMoving
    end,

	Stop = function(self)
		self.isMoving = false
		self.onCompleteCallback = nil
    end
}

Cursor = {
	Step = 0,
	SmoothMovementActive = false,
	OriginalCursorPosition = nil,
	LastStepTick = 0,

	Add = function(self, key, castPos)
		if GameIsChatOpen() then
			return false
		end
		if type(key) == "table" then
            self.Keys = key
        else
            self.Keys = { key }
        end

		local currentCursorPos = Game.cursorPos()
		if not self.OriginalCursorPosition and currentCursorPos and currentCursorPos.x and currentCursorPos.y then
			self.OriginalCursorPosition = { x = math_floor(currentCursorPos.x), y = math_floor(currentCursorPos.y) }
			self.CursorPos = { x = self.OriginalCursorPosition.x, y = self.OriginalCursorPosition.y }
		end
		self.CastPos = castPos
		if self.CastPos ~= nil then
			self.IsTarget = self.CastPos.pos ~= nil
			self.correctedCastPos = self.CastPos
			self.IsMouseClick = key == MOUSEEVENTF_RIGHTDOWN
			self.Timer = GetTickCount() + MenuDelay:Value()
			self.SmoothMovementActive = false
			self:StepSetToCastPos()
			if not self.SmoothMovementActive then
				self:StepPressKey()
			end

			self.LastStepTick = GetTickCount()
		end
	end,

	StepReady = function(self)
		if EvadeSupport then
			self:Add(MOUSEEVENTF_RIGHTDOWN, EvadeSupport)
			EvadeSupport = nil
		end
	end,

	StopSmoothMovement = function(self)
		if self.SmoothMovementActive then
			SmoothMouse:Stop()
			self.SmoothMovementActive = false
		end
	end,

	ForceReset = function(self)
		if self.SmoothMovementActive then
			SmoothMouse:Stop()
			self.SmoothMovementActive = false
		end

		self.Step = 0
		self.OriginalCursorPosition = nil
		self.CursorPos = nil
		self.CastPos = nil
		self.Timer = 0
		self.Keys = nil
		self.LastStepTick = 0

		pcall(function()
			Control.mouse_event(MOUSEEVENTF_RIGHTUP)
			Control.mouse_event(MOUSEEVENTF_LEFTUP)
		end)
	end,

	StepSetToCastPos = function(self)
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
			if self.CastPos.z ~= nil then
				pos = Vector(self.CastPos.x, myHero.pos.y, self.CastPos.z):To2D()
			else
				pos = Vector({ x = self.CastPos.x, y = self.CastPos.y })
			end
		end
		self.correctedCastPos = pos

		self.LastStepTick = GetTickCount()

		local cursorPos = Game.cursorPos()
		local distToCursor = math_sqrt((pos.x - cursorPos.x)^2 + (pos.y - cursorPos.y)^2)

				if MenuSmoothMouse:Value() then
			if distToCursor <= 10 then
				Control.SetCursorPos(pos.x, pos.y)

				self.Timer = GetTickCount() + MenuDelay:Value() + 30
				self.Step = 1
				else
				SmoothMouse:Start(pos.x, pos.y, "toTarget", function()

					self.SmoothMovementActive = false
					self.Step = 1
					self.Timer = GetTickCount() + MenuDelay:Value() + 50
					self.LastStepTick = GetTickCount()
				end)
				self.SmoothMovementActive = true
			end
		else
			Control.SetCursorPos(pos.x, pos.y)
		end
	end,

	StepPressKey = function(self)
		self.Timer = GetTickCount() + MenuDelay:Value() + 30
		self.Step = 1
		self.LastStepTick = GetTickCount()
	end,

	ExecuteAction = function(self)
		if GameIsChatOpen() then
			self.Step = 0
			self.SmoothMovementActive = false
			self.OriginalCursorPosition = nil
			self.CursorPos = nil
			return
		end

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

		local expected = self.correctedCastPos
		if expected and expected.x and expected.y then
			local cursorPos = Game.cursorPos()
			if cursorPos and (math_sqrt((cursorPos.x - expected.x)^2 + (cursorPos.y - expected.y)^2) > 4) then
				Control.SetCursorPos(math_floor(expected.x + 0.5), math_floor(expected.y + 0.5))
			end
		end

		if self.IsMouseClick then
			Control.mouse_event(MOUSEEVENTF_RIGHTDOWN)
			Control.mouse_event(MOUSEEVENTF_RIGHTUP)
		else
			for _ki = 1, #self.Keys do local key = self.Keys[_ki]

				if Control.IsKeyDown(key) and myHero.activeSpell.isCharging then
					Control.KeyUp(key)
				else
					Control.KeyDown(key)
					Control.KeyUp(key)
				end
			end
		end

		self.Step = 2
		self.LastStepTick = GetTickCount()
	end,

	StepWaitForResponse = function(self)
		local expected = self.correctedCastPos
		if not expected or not expected.x or not expected.y then
			self:ExecuteAction()
			return
		end
		local cursorPos = Game.cursorPos()
		local dist = 9999
		if cursorPos then
			dist = math_sqrt((cursorPos.x - expected.x)^2 + (cursorPos.y - expected.y)^2)
		end
	local now = GetTickCount()
	local timeout = self.Timer or (now + MenuDelay:Value() + 50)

		local threshold = 5
		if dist <= threshold then
			self:ExecuteAction()
			return
		end

	if now >= timeout then
			Control.SetCursorPos(math_floor(expected.x + 0.5), math_floor(expected.y + 0.5))

			self.Timer = now + 30
			if now >= self.Timer then
				self:ExecuteAction()
			end
			return
		end

		if MenuMultipleTimes:Value() then
			self._lastReinforce = self._lastReinforce or 0
			if now - self._lastReinforce > 20 then
				Control.SetCursorPos(math_floor(expected.x + 0.5), math_floor(expected.y + 0.5))
				self._lastReinforce = now
			end
		end
	end,

	StepSetToCursorPos = function(self)
		local returnPos = self.OriginalCursorPosition or self.CursorPos
		if not returnPos or not returnPos.x or not returnPos.y then
			self.Step = 0
			return
		end

		local cursorPos = Game.cursorPos()
		local distToReturn = math_sqrt((returnPos.x - cursorPos.x)^2 + (returnPos.y - cursorPos.y)^2)

		if MenuSmoothMouse:Value() then
			if distToReturn <= 15 then
				Control.SetCursorPos(returnPos.x, returnPos.y)
				self.Step = 0
				self.OriginalCursorPosition = nil
				self.CursorPos = nil
			else
				SmoothMouse:Start(returnPos.x, returnPos.y, "return", function()

					self.Step = 0

					self.OriginalCursorPosition = nil
					self.CursorPos = nil
					self.LastStepTick = GetTickCount()
				end)
				self.SmoothMovementActive = true
			end
		else
			Control.SetCursorPos(returnPos.x, returnPos.y)
			self.Step = 0
			self.OriginalCursorPosition = nil
			self.CursorPos = nil
		end
		self.Timer = GetTickCount() + MenuDelay:Value()

		self.LastStepTick = GetTickCount()

		if not MenuSmoothMouse:Value() then
			self.Step = 3
		end
	end,

	StepWaitForReady = function(self)
		if not (self.SmoothMovementActive and SmoothMouse:IsMoving()) then
			if self.SmoothMovementActive then
				self.SmoothMovementActive = false
			end
			self.Step = 0
		end
	end,

	OnTick = function(self)
		if SmoothMouse:IsMoving() then
			SmoothMouse:Update()
		end

		if Data and Data:Stop() and self.Step and self.Step > 0 then
			self:ForceReset()
			Movement.MoveTimer = 0
			return
		end

		if self.Step and self.Step > 0 then
			local now = GetTickCount()
			local safeResetEnabled = true
			local timeout = AUTO_SAFE_RESET_TIMEOUT

			if GameIsChatOpen() or (not GameIsOnTop()) then
				self:ForceReset()
				Movement.MoveTimer = 0
				return
			end
			if safeResetEnabled and self.LastStepTick and self.LastStepTick > 0 and (now - self.LastStepTick) >= timeout then
				self:ForceReset()

				Movement.MoveTimer = 0
			end
		end

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
		if not MenuDrawCursor:Value() then
			return
		end

		Draw.Circle(mousePos, 150, 1, Color.Cursor)

		if MenuSmoothMouse:Value() and SmoothMouse:IsMoving() then
			local targetPos = SmoothMouse.targetPos
			if targetPos then
				local myY = myHero.pos.y
				Draw.Circle(Vector(targetPos.x, myY, targetPos.y), 75, 2, Color.Yellow)

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
	CastEndTime = 0,
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
			for i = 1, #Orbwalker.OnAttackCb do
				local ok, err = pcall(Orbwalker.OnAttackCb[i])
				if not ok then print("[Orbwalker] OnAttack callback error: " .. tostring(err)) end
			end
			self.CastEndTime = spell.castEndTime
			self.AttackWindup = spell.windup
			self.ServerStart = self.CastEndTime - self.AttackWindup
			self.AttackAnimation = spell.animation
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
		if _G.DepressiveEvade and _G.DepressiveEvade.ShouldEvade then
			pcall(_G.DepressiveEvade.ShouldEvade, _G.DepressiveEvade)
		end

		if not FPSOptimizer:ShouldTick() then
			return
		end

		if not self.Menu.Enabled:Value() then
			return
		end

		if myHero.dead then
			return
		end

		self.Modes = self:GetModes()
		local modes = self.Modes

		local isNone = not (modes[ORBWALKER_MODE_COMBO] or modes[ORBWALKER_MODE_HARASS]
			or modes[ORBWALKER_MODE_LANECLEAR] or modes[ORBWALKER_MODE_JUNGLECLEAR]
			or modes[ORBWALKER_MODE_LASTHIT] or modes[ORBWALKER_MODE_FLEE]
			or modes[ORBWALKER_MODE_SPACING])
		self.IsNone = isNone

		if modes[ORBWALKER_MODE_COMBO] then
			Control.KeyDown(HK_TCO)
		else
			Control.KeyUp(HK_TCO)
		end

		if Cursor.Step > 0 or Data:Stop() or isNone then
			self.LastSkippedState = true
			return
		end
		self.LastSkippedState = false

		if not FPSOptimizer.highLoadMode or (FPSOptimizer.tickCounter % 2 == 0) then
			self:Orbwalk()
		end
	end,

	OnDraw = function(self)
		if not self.Menu.Enabled:Value() then
			return
		end

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
		if unit == nil or unit.isMe then
			local endTime = myHero.attackData.endTime
			local anim = myHero.attackData.animationTime
			local windup = myHero.attackData.windUpTime
			local extra = (self.Menu.General.ExtraWindUpTime:Value() * 0.001)

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

				local target = self.LastTarget
				if target and target.valid and target.visible and target.pos:To2D().onScreen then
					local function CastSlot(slot, hk)
						if GameCanUseSpell(slot) == 0 then
							Control.CastSpell(hk, target)

							if myHero.charName == "Riven" and slot == _Q then
								Attack.Reset = true
								Attack.LocalStart = GameTimer() - 0.25

								self.PostAttackTimer = GameTimer() - 0.2
							elseif myHero.charName == "Zeri" and slot == _Q then
								Attack.Reset = true
								Attack.LocalStart = GameTimer() - 0.4
								self.PostAttackTimer = GameTimer() - 0.35
							end
							return true
						end
						return false
					end

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
		local enemies = Object:GetEnemyHeroes(2000, false, true)
		if #enemies == 0 then
			return nil
		end

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

		local myRange = Data:GetAutoAttackRange(myHero, target)
		local enemyRange = Data:GetAutoAttackRange(target, myHero)

		local safetyMargin = 50
		local optimalDistance = myRange - safetyMargin

		local direction = (myPos - targetPos):Normalized()

		if distance <= myRange and distance <= enemyRange then
			local retreatDistance = enemyRange - distance + safetyMargin + 50
			local retreatPos = myPos + direction * retreatDistance
			return retreatPos
		elseif distance > myRange and distance <= enemyRange then
			local retreatDistance = enemyRange - distance + safetyMargin + 100
			local retreatPos = myPos + direction * retreatDistance
			return retreatPos
		elseif distance <= myRange and distance > enemyRange then
			if distance < optimalDistance then
				return nil
			else
				local approachDistance = distance - optimalDistance
				local approachPos = myPos - direction * math_min(approachDistance, 50)
				return approachPos
			end
		elseif distance > myRange and distance > enemyRange then
			local approachDistance = distance - optimalDistance
			local approachPos = myPos - direction * math_min(approachDistance, 100)
			return approachPos
		end

		return nil
	end,

	Orbwalk = function(self)
		if GameIsChatOpen() then
			return
		end

		if Menu.Orbwalker.General.UnderMouseCast:Value()
		   and Menu.Orbwalker.General.UnderMouseKey:Value()
		   and Game.GetUnderMouseObject then
			local obj = Game.GetUnderMouseObject()
			if obj and obj.valid and obj.alive and not obj.dead and obj.isEnemy
			   and Data:IsInAutoAttackRange(myHero, obj) then
				if self:Attack(obj) then return end
			end
		end

		if self.Modes and self.Modes[ORBWALKER_MODE_SPACING] then
			local spacingTarget = self:GetSpacingTarget()
			if spacingTarget and Object:IsValid(spacingTarget) then
				if self:Attack(spacingTarget) then
					return
				end

				local spacingPos = self:GetSpacingPosition(spacingTarget)
				if spacingPos then
					self.ForceMovement = spacingPos
					self:Move()
					self.ForceMovement = nil
					return
				end
			end
		end

		if not self:Attack(self:GetTarget()) then
			self:Move()
		end
	end,
}

PathPrediction = {
	SamplePosition = function(self, unit, secondsAhead)
		if not unit or not unit.pathing or not unit.pathing.hasMovePath then
			return unit and unit.pos or nil
		end
		local path = unit.pathing
		local pathCount = path.pathCount or 0
		local idx = path.pathIndex or 1
		if pathCount == 0 or idx > pathCount then return unit.pos end
		local moveSpeed = unit.ms or unit.movementSpeed or 335
		local travelDist = moveSpeed * secondsAhead
		local curPos = unit.pos
		for i = idx, pathCount do
			local ok, segEnd = pcall(function() return unit:GetPath(i) end)
			if not ok or not segEnd then break end
			local dx = segEnd.x - curPos.x
			local dz = (segEnd.z or segEnd.y) - (curPos.z or curPos.y)
			local segLen = math_sqrt(dx*dx + dz*dz)
			if segLen >= travelDist and segLen > 0 then
				local frac = travelDist / segLen
				return {
					x = curPos.x + dx * frac,
					y = curPos.y,
					z = (curPos.z or curPos.y) + dz * frac
				}
			end
			travelDist = travelDist - segLen
			curPos = segEnd
		end
		return curPos
	end,

	WillBeOutOfRange = function(self, attacker, target, windup)
		if not target.pathing or not target.pathing.hasMovePath then return false end
		local travelT = windup or 0.25
		local futurePos = self:SamplePosition(target, travelT)
		if not futurePos then return false end
		local ap = attacker.pos
		local dx = ap.x - futurePos.x
		local dz = (ap.z or ap.y) - (futurePos.z or futurePos.y)
		local distSq = dx*dx + dz*dz
		local range = (attacker.range or 500) + (attacker.boundingRadius or 0) + (target.boundingRadius or 0)
		return distSq > range * range
	end,

	IsDashingToward = function(self, unit)
		if not unit or not unit.pathing or not unit.pathing.isDashing then return false end
		local ep = unit.pathing.endPos
		if not ep then return false end
		local mp = myHero.pos
		local curDist = GetDistance(mp, unit.pos)
		local endDist = GetDistance(mp, ep)
		return endDist < curDist - 100
	end,
}
_G.SDK = _G.SDK or {}
_G.SDK.PathPrediction = PathPrediction

TurretAggro = {
	NextShot = 0,
	CurrentTarget = nil,
	LastEndTime = 0,
	TurretAttackInterval = 0.83,

	OnTick = function(self)
		local turret = Health.AllyTurret
		if not turret or not turret.valid then
			self.NextShot = 0
			self.CurrentTarget = nil
			return
		end
		local ad = turret.attackData
		if ad and ad.endTime and ad.endTime > self.LastEndTime then
			self.LastEndTime = ad.endTime
			self.CurrentTarget = ad.target

			local turretAS = (turret.attackSpeed or 0.83)
			self.TurretAttackInterval = 1.0 / math_max(0.5, turretAS)
			self.NextShot = ad.endTime + self.TurretAttackInterval
		end
	end,

	IsUnderEnemyTurretAggro = function(self)
		local count = GameTurretCount and GameTurretCount() or 0
		for i = 1, count do
			local t = GameTurret(i)
			if t and t.valid and t.team ~= TEAM_ALLY and not t.dead then
				local dist = GetDistance(myHero.pos, t.pos)
				if dist < 775 + (myHero.boundingRadius or 0) then
					return true, t
				end
			end
		end
		return false, nil
	end,

	GetEnemyTurretNextShot = function(self, turret)
		if not turret or not turret.attackData then return 0 end
		local ad = turret.attackData
		if not ad.endTime then return 0 end
		local remaining = ad.endTime - GameTimer()
		return math_max(0, remaining)
	end,

	SafeToAttackChamp = function(self)
		local under, turret = self:IsUnderEnemyTurretAggro()
		if not under then return true end

		local ad = turret.attackData
		if not ad or not ad.target then return false end

		local nextShot = self:GetEnemyTurretNextShot(turret)
		local windup = (myHero.attackData and myHero.attackData.windUpTime) or 0.25
		return nextShot > windup + 0.1
	end,
}
_G.SDK = _G.SDK or {}
_G.SDK.TurretAggro = TurretAggro

Orbwalker:RegisterMenuKey(ORBWALKER_MODE_COMBO, Menu.Orbwalker.Keys.Combo)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_HARASS, Menu.Orbwalker.Keys.Harass)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_LASTHIT, Menu.Orbwalker.Keys.LastHit)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_LANECLEAR, Menu.Orbwalker.Keys.LaneClear)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_JUNGLECLEAR, Menu.Orbwalker.Keys.Jungle)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_FLEE, Menu.Orbwalker.Keys.Flee)
Orbwalker:RegisterMenuKey(ORBWALKER_MODE_SPACING, Menu.Orbwalker.Keys.Spacing)

_G.SDK = _G.SDK or {}
_G.SDK.OnDraw = _G.SDK.OnDraw or {}
_G.SDK.OnTick = _G.SDK.OnTick or {}
_G.SDK.OnWndMsg = _G.SDK.OnWndMsg or {}

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

Callback.Add("Load", function()
	ChampionInfo:OnLoad()

	Object:OnLoad()

	local ticks = SDK.OnTick
	local draws = SDK.OnDraw
	local wndmsgs = SDK.OnWndMsg
	if Game.Latency() < 250 then _G.LATENCY = Game.Latency() else _G.LATENCY = Menu.Main.Latency:Value() end

	Callback.Add("Draw", function()

		if GameIsChatOpen() then
			LastChatOpenTimer = GetTickCount()
		end

		Cached:Reset()
		Cursor:OnTick()
		Action:OnTick()
		Attack:OnTick()
		Orbwalker:OnTick()

		local tickCount = #ticks
		for i = 1, tickCount do
			local fn = ticks[i]
			if fn then fn() end
		end

		if Menu.Main.Drawings.Enabled:Value() then
			Target:OnDraw()
			Cursor:OnDraw()
			Orbwalker:OnDraw()
			Health:OnDraw()

			local drawCount = #draws
			for i = 1, drawCount do
				local fn = draws[i]
				if fn then fn() end
			end

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
	end)

	Callback.Add("Tick", function()

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
		if _G.SDK and _G.SDK.TurretAggro then _G.SDK.TurretAggro:OnTick() end
	end)

	Callback.Add("WndMsg", function(msg, wParam)
		Data:WndMsg(msg, wParam)
		Spell:WndMsg(msg, wParam)
		Target:WndMsg(msg, wParam)
		Cached:WndMsg(msg, wParam)

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
