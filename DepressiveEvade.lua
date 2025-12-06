local Version = 1.0
local __name__ = "DepressiveEvade"
local __version__ = Version

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTOUPDATE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════
if _G.DepressiveEvadeUpdate then return end
_G.DepressiveEvadeUpdate = {}

do
    local Updater = _G.DepressiveEvadeUpdate
    Updater.Callbacks = {}
    
    function Updater:DownloadFile(url, path)
        DownloadFileAsync(url, path, function() end)
    end
    
    function Updater:Trim(s)
        local from = s:match("^%s*()")
        return from > #s and "" or s:match(".*%S", from)
    end
    
    function Updater:ReadFile(path)
        local result = {}
        local file = io.open(path, "r")
        if file then
            for line in file:lines() do
                local str = self:Trim(line)
                if #str > 0 then
                    result[#result + 1] = str
                end
            end
            file:close()
        end
        return result
    end
    
    function Updater:New(args)
        local updater = {
            Step = 1,
            Version = tonumber(args.version) or 0,
            VersionUrl = args.versionUrl,
            VersionPath = args.versionPath,
            ScriptUrl = args.scriptUrl,
            ScriptPath = args.scriptPath,
            ScriptName = args.scriptName,
            VersionTimer = GetTickCount()
        }
        
        function updater:DownloadVersion()
            if not FileExist(self.ScriptPath) then
                self.Step = 4
                Updater:DownloadFile(self.ScriptUrl, self.ScriptPath)
                self.ScriptTimer = GetTickCount()
                return
            end
            Updater:DownloadFile(self.VersionUrl, self.VersionPath)
        end
        
        function updater:OnTick()
            if self.Step == 0 then return end
            
            if self.Step == 1 and GetTickCount() > self.VersionTimer + 1000 then
                local response = Updater:ReadFile(self.VersionPath)
                if #response > 0 and tonumber(response[1]) > self.Version then
                    self.Step = 2
                    self.NewVersion = response[1]
                    Updater:DownloadFile(self.ScriptUrl, self.ScriptPath)
                    self.ScriptTimer = GetTickCount()
                else
                    self.Step = 3
                end
            elseif self.Step == 2 and GetTickCount() > self.ScriptTimer + 1000 then
                self.Step = 0
                print(self.ScriptName .. " - new update found! [" .. tostring(self.Version) .. " -> " .. self.NewVersion .. "] Please 2xf6!")
            elseif self.Step == 3 then
                self.Step = 0
            elseif self.Step == 4 and GetTickCount() > self.ScriptTimer + 1000 then
                self.Step = 0
                print(self.ScriptName .. " - downloaded! Please 2xf6!")
            end
        end
        
        function updater:CanUpdate()
            local response = Updater:ReadFile(self.VersionPath)
            return #response > 0 and tonumber(response[1]) > self.Version
        end
        
        updater:DownloadVersion()
        self.Callbacks[#self.Callbacks + 1] = updater
        return updater
    end
end

Callback.Add("Tick", function()
    for i = 1, #_G.DepressiveEvadeUpdate.Callbacks do
        local updater = _G.DepressiveEvadeUpdate.Callbacks[i]
        if updater.Step > 0 then
            updater:OnTick()
        end
    end
end)

if _G.DepressiveEvadeUpdate:New({
    version = __version__,
    scriptName = __name__,
    scriptPath = SCRIPT_PATH .. "DepressiveEvade.lua",
    scriptUrl = "https://raw.githubusercontent.com/DepressiveKyo/GoS/refs/heads/main/DepressiveEvade.lua",
    versionPath = SCRIPT_PATH .. "DepressiveEvade.version",
    versionUrl = "https://raw.githubusercontent.com/DepressiveKyo/GoS/refs/heads/main/DepressiveEvade.version",
}):CanUpdate() then
    return
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LOCALIZED FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════
MathAbs, MathAtan, MathAtan2, MathAcos, MathCeil, MathCos, MathDeg, MathFloor, MathHuge, MathMax, MathMin, MathPi, MathRad, MathSin, MathSqrt = math.abs, math.atan, math.atan2, math.acos, math.ceil, math.cos, math.deg, math.floor, math.huge, math.max, math.min, math.pi, math.rad, math.sin, math.sqrt
local GameCanUseSpell, GameLatency, GameTimer, GameHeroCount, GameHero, GameMinionCount, GameMinion, GameMissileCount, GameMissile = Game.CanUseSpell, Game.Latency, Game.Timer, Game.HeroCount, Game.Hero, Game.MinionCount, Game.Minion, Game.MissileCount, Game.Missile
local DrawCircle, DrawColor, DrawLine, DrawText, ControlKeyUp, ControlKeyDown, ControlMouseEvent, ControlSetCursorPos = Draw.Circle, Draw.Color, Draw.Line, Draw.Text, Control.KeyUp, Control.KeyDown, Control.mouse_event, Control.SetCursorPos
local TableInsert, TableRemove, TableSort = table.insert, table.remove, table.sort

-- WASD Movement Keys (hardcoded)
local KEY_W = string.byte("W")
local KEY_A = string.byte("A")
local KEY_S = string.byte("S")
local KEY_D = string.byte("D")

require "2DGeometry"
require 'MapPositionGOS'

-- Map detection and override menu
local DETECTED_MAP_ID = Game.mapID
local DETECTED_MAP_NAME = (Game.mapName and tostring(Game.mapName)) or ""
print("[DepressiveEvade] Detected mapID:", DETECTED_MAP_ID)
print("[DepressiveEvade] mapName:", DETECTED_MAP_NAME)

local function _resolveMapType()
	local mt = (MapPosition and MapPosition.GetMapType and MapPosition:GetMapType()) or (_G.MapType) or "unknown"
	if mt == "unknown" then
		local lower = DETECTED_MAP_NAME:lower()
		if DETECTED_MAP_ID == 11 or lower:find("rift") then
			mt = "summoners_rift"
		elseif DETECTED_MAP_ID == 12 or lower:find("abyss") or lower:find("aram") then
			mt = "howling_abyss"
		elseif (type(DETECTED_MAP_ID) == "number" and DETECTED_MAP_ID >= 30 and DETECTED_MAP_ID <= 35) or lower:find("arena") then
			mt = "arena"
		end
	end
	return mt
end

local _detectedMapType = _resolveMapType()
_G.MapType = _detectedMapType


local SpellDatabase = {
	["Aatrox"] = {
		["AatroxQ"] = { displayName = "The Darkin Blade [First]", missileName = "AatroxQ", slot = _Q, type = "linear", speed = MathHuge, range = 650, delay = 0.6, radius = 130, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["AatroxQ2"] = { displayName = "The Darkin Blade [Second]", missileName = "AatroxQ2", slot = _Q, type = "polygon", speed = MathHuge, range = 500, delay = 0.6, radius = 200, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["AatroxQ3"] = { displayName = "The Darkin Blade [Third]", missileName = "AatroxQ3", slot = _Q, type = "circular", speed = MathHuge, range = 200, delay = 0.6, radius = 300, danger = 4, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["AatroxW"] = { displayName = "Infernal Chains", missileName = "AatroxW", slot = _W, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 80, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Ahri"] = {
		["AhriQ"] = { missileName = "AhriQ", displayName = "Orb of Deception", slot = _Q, type = "linear", speed = 2500, range = 880, delay = 0.25, radius = 100, danger = 2, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["AhriE"] = { displayName = "Seduce",  missileName = "AhriE", slot = _E, type = "linear", speed = 1500, range = 975, delay = 0.25, radius = 60, danger = 1, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Akali"] = {
		["AkaliQ"] = { displayName = "Five Point Strike", missileName = "AkaliQ", slot = _Q, type = "conic", speed = 3200, range = 550, delay = 0.25, radius = 60, angle = 45, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = false, exception = false, extend = true},
		["AkaliE"] = { displayName = "Shuriken Flip", missileName = "AkaliE", slot = _E, type = "linear", speed = 1800, range = 825, delay = 0.25, radius = 70, danger = 2, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["AkaliR"] = { displayName = "Perfect Execution [First]", slot = _R, type = "linear", speed = 1800, range = 675, delay = 0, radius = 65, danger = 4, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["AkaliRb"] = { displayName = "Perfect Execution [Second]", slot = _R, type = "linear", speed = 3600, range = 525, delay = 0, radius = 65, danger = 4, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Akshan"] = {
		["AkshanQ"] = { displayName = "Avengerang", missileName = "AkshanQ", slot = _Q, type = "linear", speed = 1500, range = 850, delay = 0.25, radius = 60, danger = 2, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["AkshanQReturn"] = { displayName = "Avengerang (Return)", missileName = "AkshanQReturn", slot = _Q, type = "linear", speed = 2400, range = 850, delay = 0.25, radius = 60, danger = 2, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Ambessa"] = {
	["AmbessaQ"] = { displayName = "Cunning Sweep", missileName = "AmbessaQ", slot = _Q, type = "conic", speed = MathHuge, range = 650, delay = 0.25, radius = 0, angle = 180, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = true},
	["AmbessaQ2"] = { displayName = "Sundering Slam", missileName = "AmbessaQ2", slot = _Q, type = "linear", speed = MathHuge, range = 650, delay = 0.25, radius = 60, danger = 2, cc = false, collision = false, windwall = false, hitbox = true, fow = true, exception = false, extend = true},
		["AmbessaW"] = { displayName = "Repudiation", slot = _W, type = "circular", speed = MathHuge, range = 325, delay = 0.25, radius = 325, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["AmbessaE"] = { displayName = "Lacerate", slot = _E, type = "circular", speed = MathHuge, range = 325, delay = 0, radius = 325, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["AmbessaR"] = { displayName = "Public Execution", slot = _R, type = "linear", speed = MathHuge, range = 2500, delay = 0.25, radius = 150, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Aurora"] = {
		["AuroraQ"] = { displayName = "Twofold Hex", missileName = "AuroraQ", slot = _Q, type = "linear", speed = 1550, range = 900, delay = 0.25, radius = 60, danger = 2, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	["AuroraR"] = { displayName = "Between Worlds", missileName = "AuroraR", slot = _R, type = "linear", speed = 1200, range = 825, delay = 0.25, radius = 120, danger = 4, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Alistar"] = {
		["Pulverize"] = { displayName = "Pulverize", slot = _Q, type = "circular", speed = MathHuge, range = 0, delay = 0.25, radius = 365, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Amumu"] = {
	["BandageToss"] = { displayName = "Bandage Toss", missileName = "BandageToss", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.25, radius = 80, danger = 3, cc = true, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["CurseoftheSadMummy"] = { displayName = "Curse of the Sad Mummy", slot = _R, type = "circular", speed = MathHuge, range = 0, delay = 0.25, radius = 550, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Anivia"] = {
		["FlashFrostSpell"] = { displayName = "Flash Frost", missileName = "FlashFrostSpell", slot = _Q, type = "linear", speed = 950, range = 1100, delay = 0.25, radius = 110, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Annie"] = {
		["AnnieW"] = { displayName = "Incinerate", missileName = "AnnieW", slot = _W, type = "conic", speed = MathHuge, range = 600, delay = 0.25, radius = 0, angle = 50, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["AnnieQ"] = { displayName = "Disintegrate", missileName = "AnnieQ", slot = _Q, type = "linear", speed = 1700, range = 625, delay = 0.25, radius = 65, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["AnnieR"] = { displayName = "Summon: Tibbers", slot = _R, type = "circular", speed = MathHuge, range = 600, delay = 0.25, radius = 290, danger = 5, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Aphelios"] = {
		["ApheliosCalibrumQ"] = { displayName = "Moonshot", missileName = "ApheliosCalibrumQ", slot = _Q, type = "linear", speed = 1850, range = 1450, delay = 0.35, radius = 60, danger = 1, cc = false, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	["ApheliosInfernumQ"] = { displayName = "Duskwave", slot = _Q, type = "conic", speed = 1500, range = 850, delay = 0.25, radius = 65, angle = 45, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = false, exception = false, extend = true},
	["ApheliosR"] = { displayName = "Moonlight Vigil", missileName = "ApheliosR", slot = _R, type = "linear", speed = 2050, range = 1600, delay = 0.5, radius = 125, danger = 3, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Ashe"] = {
	["Volley"] = { displayName = "Volley", missileName = "Volley", slot = _W, type = "conic", speed = 2000, range = 1200, delay = 0.25, radius = 20, angle = 40, danger = 2, cc = true, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["EnchantedCrystalArrow"] = { displayName = "Enchanted Crystal Arrow", missileName = "EnchantedCrystalArrow", slot = _R, type = "linear", speed = 1600, range = 12500, delay = 0.25, radius = 130, danger = 4, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["AurelionSol"] = {
		--["AurelionSolQ"] = { displayName = "Starsurge", missileName = "AurelionSolQMissile", slot = _Q, type = "linear", speed = 850, range = 1075, delay = 0, radius = 110, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	["AurelionSolR"] = { displayName = "Voice of Light", missileName = "AurelionSolR", slot = _R, type = "linear", speed = 4500, range = 1500, delay = 0.35, radius = 120, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Azir"] = {
		["AzirR"] = { displayName = "Emperor's Divide", missileName = "AzirR", slot = _R, type = "linear", speed = 1400, range = 500, delay = 0.3, radius = 250, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["BelVeth"] = {
	["BelvethQ"] = { displayName = "Void Surge", missileName = "BelvethQ", slot = _Q, type = "linear", speed = 1200, range = 450, delay = 0.0, radius = 100, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["BelvethW"] = { displayName = "Above and Below", slot = _W, type = "linear", speed = 500, range = 715, delay = 0.5, radius = 200, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["BelvethE"] = { displayName = "Royal Maelstrom", slot = _E, type = "circular", speed = MathHuge, range = 0.0, delay = 1.5, radius = 500, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["BelvethR"] = { displayName = "Endless Banquet", slot = _R, type = "circular", speed = MathHuge, range = 275, delay = 1.0, radius = 500, danger = 4, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Bard"] = {
	["BardQ"] = { displayName = "Cosmic Binding", missileName = "BardQ", slot = _Q, type = "linear", speed = 1500, range = 950, delay = 0.25, radius = 60, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	["BardR"] = { displayName = "Tempered Fate", missileName = "BardR", slot = _R, type = "circular", speed = 2100, range = 3400, delay = 0.5, radius = 350, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = false},
	},
	["Blitzcrank"] = {
	["RocketGrab"] = { displayName = "Rocket Grab", missileName = "RocketGrab", slot = _Q, type = "linear", speed = 1800, range = 1150, delay = 0.25, radius = 70, danger = 3, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["StaticField"] = { displayName = "Static Field", slot = _R, type = "circular", speed = MathHuge, range = 0, delay = 0.25, radius = 600, danger = 4, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Brand"] = {
		["BrandQ"] = { displayName = "Sear", missileName = "BrandQ", slot = _Q, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 60, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["BrandW"] = { displayName = "Pillar of Flame", slot = _W, type = "circular", speed = MathHuge, range = 900, delay = 0.85, radius = 250, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Braum"] = {
		["BraumQ"] = { displayName = "Winter's Bite", missileName = "BraumQ", slot = _Q, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, danger = 3, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["BraumR"] = { displayName = "Glacial Fissure", missileName = "BraumR", slot = _R, type = "linear", speed = 1400, range = 1250, delay = 0.5, radius = 115, danger = 4, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Briar"] = {
		--["BriarQ"] = { displayName = "Head Rush", slot = _Q, type = "linear", speed = 1600, range = 475, delay = 0.25, radius = 80, danger = 3, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		--["BriarW"] = { displayName = "Blood Frenzy / Snack Attack", slot = _W, type = "circular", speed = MathHuge, range = 350, delay = 0.25, radius = 350, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["BriarE"] = { displayName = "Chilling Scream", slot = _E, type = "circular", speed = MathHuge, range = 400, delay = 0.5, radius = 400, danger = 3, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["BriarR"] = { displayName = "Certain Death", missileName = "BriarR", slot = _R, type = "linear", speed = 1400, range = 1400, delay = 0.25, radius = 120, danger = 4, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Caitlyn"] = {
		["CaitlynPiltoverPeacemaker"] = { displayName = "Piltover Peacemaker", missileName = "CaitlynQ", slot = _Q, type = "linear", speed = 2200, range = 1250, delay = 0.625, radius = 90, danger = 1, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["CaitlynYordleTrap"] = { displayName = "Yordle Trap", slot = _W, type = "circular", speed = MathHuge, range = 800, delay = 0.35, radius = 75, danger = 1, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["CaitlynEntrapment"] = { displayName = "Entrapment", missileName = "CaitlynE", slot = _E, type = "linear", speed = 1600, range = 750, delay = 0.15, radius = 70, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Camille"] = {
	["CamilleE"] = { displayName = "Hookshot [First]", missileName = "CamilleE", slot = _E, type = "linear", speed = 1900, range = 800, delay = 0, radius = 60, danger = 1, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["CamilleEDash2"] = { displayName = "Hookshot [Second]", slot = _E, type = "linear", speed = 1900, range = 400, delay = 0, radius = 60, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Cassiopeia"] = {
		["CassiopeiaQ"] = { displayName = "Noxious Blast", slot = _Q, type = "circular", speed = MathHuge, range = 850, delay = 0.75, radius = 150, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["CassiopeiaW"] = { displayName = "Miasma", slot = _W, type = "circular", speed = 2500, range = 800, delay = 0.75, radius = 160, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = false, exception = false, extend = false},
		["CassiopeiaR"] = { displayName = "Petrifying Gaze", slot = _R, type = "conic", speed = MathHuge, range = 825, delay = 0.5, radius = 0, angle = 80, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Chogath"] = {
		["Rupture"] = { displayName = "Rupture", slot = _Q, type = "circular", speed = MathHuge, range = 950, delay = 1.2, radius = 250, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["FeralScream"] = { displayName = "Feral Scream", slot = _W, type = "conic", speed = MathHuge, range = 650, delay = 0.5, radius = 0, angle = 56, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Corki"] = {
	["PhosphorusBomb"] = { displayName = "Phosphorus Bomb", missileName = "PhosphorusBomb", slot = _Q, type = "circular", speed = 1000, range = 825, delay = 0.25, radius = 250, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
	["MissileBarrageMissile"] = { displayName = "Missile Barrage [Standard]", missileName = "MissileBarrage", slot = _R, type = "linear", speed = 2000, range = 1300, delay = 0.175, radius = 40, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	["MissileBarrageMissile2"] = { displayName = "Missile Barrage [Big]", missileName = "MissileBarrage", slot = _R, type = "linear", speed = 2000, range = 1500, delay = 0.175, radius = 40, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Diana"] = {
		["DianaQ"] = { displayName = "Crescent Strike", missileName = "DianaQ", slot = _Q, type = "circular", speed = 1900, range = 900, delay = 0.25, radius = 185, danger = 2, cc = false, collision = true, windwall = true, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Draven"] = {
	["DravenDoubleShot"] = { displayName = "Double Shot", missileName = "DravenDoubleShot", slot = _E, type = "linear", speed = 1600, range = 1050, delay = 0.25, radius = 130, danger = 3, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	--["DravenSpinning"] = { displayName = "Spinning Axe", missileName = "DravenSpinning", slot = _Q, type = "linear", speed = 1600, range = 1100, delay = 0.1, radius = 55, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = false},
		["DravenRCast"] = { displayName = "Whirling Death", missileName = "DravenRCast", slot = _R, type = "linear", speed = 2000, range = 12500, delay = 0.25, radius = 160, danger = 4, cc = false, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
	},
	["DrMundo"] = {
		["DrMundoQ"] = { displayName = "Infected Bonesaw", missileName = "DrMundoQ", slot = _Q, type = "linear", speed = 2000, range = 990, delay = 0.25, radius = 120, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Ekko"] = {
		["EkkoQ"] = { displayName = "Timewinder", missileName = "EkkoQ", slot = _Q, type = "linear", speed = 1650, range = 1175, delay = 0.25, radius = 60, danger = 1, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["EkkoW"] = { displayName = "Parallel Convergence", slot = _W, type = "circular", speed = MathHuge, range = 1600, delay = 3.35, radius = 400, danger = 1, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Elise"] = {
		["EliseHumanE"] = { displayName = "Cocoon", missileName = "EliseHumanE", slot = _E, type = "linear", speed = 1600, range = 1075, delay = 0.25, radius = 55, danger = 1, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Evelynn"] = {
		["EvelynnQ"] = { displayName = "Hate Spike", missileName = "EvelynnQ", slot = _Q, type = "linear", speed = 2400, range = 800, delay = 0.25, radius = 60, danger = 2, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["EvelynnR"] = { displayName = "Last Caress", slot = _R, type = "conic", speed = MathHuge, range = 450, delay = 0.35, radius = 180, angle = 180, danger = 5, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Ezreal"] = {
		["EzrealQ"] = { displayName = "Mystic Shot", missileName = "EzrealQ", slot = _Q, type = "linear", speed = 2000, range = 1150, delay = 0.25, radius = 60, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["EzrealW"] = { displayName = "Essence Flux", missileName = "EzrealW", slot = _W, type = "linear", speed = 2000, range = 1150, delay = 0.25, radius = 60, danger = 1, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["EzrealR"] = { displayName = "Trueshot Barrage", missileName = "EzrealR", slot = _R, type = "linear", speed = 2000, range = 12500, delay = 1, radius = 160, danger = 4, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Fiora"] = {
		["FioraW"] = { displayName = "Riposte", slot = _W, type = "linear", speed = 3200, range = 750, delay = 0.75, radius = 70, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Fizz"] = {
		["FizzR"] = { displayName = "Chum the Waters", missileName = "FizzR", slot = _R, type = "linear", speed = 1300, range = 1300, delay = 0.25, radius = 150, danger = 5, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Galio"] = {
	["GalioQ"] = { displayName = "Winds of War", missileName = "GalioQ", slot = _Q, type = "circular", speed = 1150, range = 825, delay = 0.25, radius = 235, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["GalioE"] = { displayName = "Justice Punch", slot = _E, type = "linear", speed = 2300, range = 650, delay = 0.4, radius = 160, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Gnar"] = {
	["GnarQMissile"] = { displayName = "Boomerang Throw", missileName = "GnarQ", slot = _Q, type = "linear", speed = 2500, range = 1125, delay = 0.25, radius = 55, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	["GnarBigQMissile"] = { displayName = "Boulder Toss", missileName = "GnarQ", slot = _Q, type = "linear", speed = 2100, range = 1125, delay = 0.5, radius = 90, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["GnarBigW"] = { displayName = "Wallop", slot = _W, type = "linear", speed = MathHuge, range = 575, delay = 0.6, radius = 100, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		--["GnarE"] = { displayName = "Hop", slot = _E, type = "circular", speed = 900, range = 475, delay = 0.25, radius = 160, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		--["GnarBigE"] = { displayName = "Crunch", slot = _E, type = "circular", speed = 800, range = 600, delay = 0.25, radius = 375, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["GnarR"] = { displayName = "GNAR!", slot = _R, type = "circular", speed = MathHuge, range = 0, delay = 0.25, radius = 475, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Gragas"] = {
	["GragasQ"] = { displayName = "Barrel Roll", missileName = "GragasQ", slot = _Q, type = "circular", speed = 1000, range = 850, delay = 0.25, radius = 275, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
	["GragasE"] = { displayName = "Body Slam", slot = _E, type = "linear", speed = 900, range = 600, delay = 0.25, radius = 170, danger = 2, cc = true, collision = true, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	["GragasR"] = { displayName = "Explosive Cask", missileName = "GragasR", slot = _R, type = "circular", speed = 1800, range = 1000, delay = 0.25, radius = 400, danger = 5, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
	},
	["Graves"] = {
		["GravesQLineSpell"] = { displayName = "End of the Line", slot = _Q, type = "polygon", speed = MathHuge, range = 800, delay = 1.4, radius = 20, danger = 1, cc = false, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
		["GravesSmokeGrenade"] = { displayName = "Smoke Grenade", missileName = "GravesSmokeGrenadeBoom", slot = _W, type = "circular", speed = 1500, range = 950, delay = 0.15, radius = 250, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["GravesChargeShot"] = { displayName = "Charge Shot", missileName = "GravesChargeShotShot", slot = _R, type = "polygon", speed = 2100, range = 1000, delay = 0.25, radius = 100, danger = 5, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Gwen"] = {
	["GwenQ"] = { displayName = "Snip Snip!", missileName = "GwenQ", slot = _Q, type = "circular", speed = 1500, range = 450, delay = 0, radius = 275, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	["GwenR"] = { displayName = "Needlework", missileName = "GwenR", slot = _R, type = "linear", speed = 1800, range = 1230, delay = 0.25, radius = 250, danger = 3, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Hecarim"] = {
		["HecarimRapidSlash"] = { displayName = "Rampage", slot = _Q, type = "linear", speed = MathHuge, range = 350, delay = 0.25, radius = 90, danger = 2, cc = false, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["HecarimW"] = { displayName = "Spirit of Dread", slot = _W, type = "circular", speed = MathHuge, range = 0, delay = 0.25, radius = 425, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = false},
		["HecarimRamp"] = { displayName = "Devastating Charge", slot = _E, type = "linear", speed = MathHuge, range = 700, delay = 0, radius = 90, danger = 2, cc = true, collision = true, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["HecarimUlt"] = { displayName = "Onslaught of Shadows", missileName = "HecarimUlt", slot = _R, type = "linear", speed = 1100, range = 1650, delay = 0.2, radius = 280, danger = 4, cc = true, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Heimerdinger"] = {
		["HeimerdingerQ"] = { displayName = "H-28 G Evolution Turret", slot = _Q, type = "circular", speed = MathHuge, range = 900, delay = 0, radius = 80, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["HeimerdingerW"] = { displayName = "Hextech Micro-Rockets", missileName = "HeimerdingerW", slot = _W, type = "linear", speed = 2050, range = 1325, delay = 0.25, radius = 100, danger = 2, cc = false, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
		["HeimerdingerR"] = { displayName = "UPGRADE!!!", slot = _R, type = "circular", speed = MathHuge, range = 1000, delay = 0, radius = 180, danger = 3, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["HeimerdingerE"] = { displayName = "CH-2 Electron Storm Grenade", missileName = "HeimerdingerESpell", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["HeimerdingerEUlt"] = { displayName = "CH-2 Electron Storm Grenade [Ult]", missileName = "HeimerdingerESpell_ult", slot = _E, type = "circular", speed = 1200, range = 970, delay = 0.25, radius = 250, danger = 3, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
	},
	["Hwei"] = {
		["HweiQ"] = { displayName = "Subject: Disaster", slot = _Q, type = "linear", speed = MathHuge, range = 0, delay = 0.25, radius = 0, danger = 4, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["HweiQQ"] = { displayName = "Devastating Fire", missileName = "HweiQQ", slot = _Q, type = "linear", speed = 2600, range = 1200, delay = 0.125, radius = 60, danger = 4, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["HweiQE"] = { displayName = "Severing Bolt", missileName = "HweiQE", slot = _Q, type = "linear", speed = 1600, range = 1500, delay = 0.25, radius = 70, danger = 3, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["HweiQW"] = { displayName = "Devastating Fire [Quick Follow]", missileName = "HweiQW", slot = _Q, type = "linear", speed = 2600, range = 1200, delay = 0.125, radius = 60, danger = 4, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		--["HweiWQ"] = { displayName = "Devastating Fire [Serenity]", missileName = "HweiWQ", slot = _Q, type = "linear", speed = 2600, range = 1200, delay = 0.125, radius = 60, danger = 4, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["HweiE"] = { displayName = "Subject: Torment", missileName = "HweiE", slot = _E, type = "linear", speed = 1600, range = 1200, delay = 0.25, radius = 100, danger = 3, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["HweiEE"] = { displayName = "Grim Visage", missileName = "HweiEE", slot = _E, type = "linear", speed = 1400, range = 1100, delay = 0.25, radius = 70, danger = 3, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["HweiEQ"] = { displayName = "Gaze of the Abyss", missileName = "HweiEQ", slot = _E, type = "linear", speed = 1250, range = 1300, delay = 0.25, radius = 60, danger = 3, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["HweiR"] = { displayName = "Spiraling Despair", missileName = "HweiR", slot = _R, type = "linear", speed = 1200, range = 1200, delay = 0.25, radius = 150, danger = 4, cc = true, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Illaoi"] = {
		["IllaoiQ"] = { displayName = "Tentacle Smash", slot = _Q, type = "linear", speed = MathHuge, range = 850, delay = 0.75, radius = 100, danger = 2, cc = false, collision = true, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["IllaoiE"] = { displayName = "Test of Spirit", missileName = "IllaoiEMis", slot = _E, type = "linear", speed = 1900, range = 900, delay = 0.25, radius = 50, danger = 1, cc = false, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["IllaoiR"] = { displayName = "Leap of Faith", slot = _R, type = "circular", speed = MathHuge, range = 0, delay = 0.25, radius = 475, danger = 5, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Irelia"] = {
		--["IreliaE2"] = { displayName = "Flawless Duet (Recast)", slot = _E, type = "targeted", speed = MathHuge, range = 1550, delay = 0.0, radius = 70, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = false},
		--["IreliaQ"] = { displayName = "Bladesurge", slot = _Q, type = "linear", speed = MathHuge, range = 650, delay = 0.25, radius = 60, danger = 1, cc = false, collision = false, windwall = false, hitbox = true, fow = true, exception = false, extend = true},
		["IreliaW2"] = { displayName = "Defiant Dance", slot = _W, type = "linear", speed = MathHuge, range = 825, delay = 0.25, radius = 120, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	--["IreliaEParticleMissile"] = { displayName = "Flawless Duet", missileName = "IreliaE", slot = _E, type = "linear", speed = MathHuge, range = 1550, delay = 0.5, radius = 70, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = true, exception = true, extend = false},
		["IreliaR"] = { displayName = "Vanguard's Edge", missileName = "IreliaR", slot = _R, type = "linear", speed = 2000, range = 950, delay = 0.4, radius = 160, danger = 4, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Ivern"] = {
		["IvernQ"] = { displayName = "Rootcaller", missileName = "IvernQ", slot = _Q, type = "linear", speed = 1300, range = 1075, delay = 0.25, radius = 80, danger = 1, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Janna"] = {
		["HowlingGaleSpell"] = { displayName = "Howling Gale", missileName = "HowlingGaleSpell", slot = _Q, type = "linear", speed = 667, range = 1750, radius = 100, danger = 2, cc = true, collision = false, windwall = true, fow = true, exception = true, extend = false},
	},
	["JarvanIV"] = {
		["JarvanIVDragonStrike"] = { displayName = "Dragon Strike", slot = _Q, type = "linear", speed = MathHuge, range = 770, delay = 0.4, radius = 70, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["JarvanIVDemacianStandard"] = { displayName = "Demacian Standard", slot = _E, type = "circular", speed = 3440, range = 860, delay = 0, radius = 175, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Jayce"] = {
		["JayceShockBlast"] = { displayName = "Shock Blast [Standard]", missileName = "JayceShockBlastMis", slot = _Q, type = "linear", speed = 1450, range = 1050, delay = 0.214, radius = 70, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["JayceShockBlastWallMis"] = { displayName = "Shock Blast [Accelerated]", missileName = "JayceShockBlastWallMis", slot = _Q, type = "linear", speed = 2350, range = 1600, delay = 0.152, radius = 115, danger = 3, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = true, extend = false},
	},
	["Jax"] = {
		--["JaxQ"] = { displayName = "Leap Strike", slot = _Q, type = "targeted", speed = MathHuge, range = 700, delay = 0, radius = 0, danger = 1, cc = false, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		--["JaxW"] = { displayName = "Empower", slot = _W, type = "linear", speed = MathHuge, range = 1, delay = 0.0, radius = 0, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		--["JaxE"] = { displayName = "Counter Strike", slot = _E, type = "circular", speed = MathHuge, range = 0, delay = 0.25, radius = 225, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		--["JaxR"] = { displayName = "Grandmaster-at-Arms", slot = _R, type = "circular", speed = MathHuge, range = 0, delay = 0.0, radius = 200, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Jhin"] = {
		["JhinW"] = { displayName = "Deadly Flourish", missileName = "JhinW", slot = _W, type = "linear", speed = 5000, range = 2550, delay = 0.75, radius = 40, danger = 1, cc = true, collision = false, windwall = true, hitbox = false, fow = false, exception = false, extend = true},
		["JhinE"] = { displayName = "Captive Audience", missileName = "JhinETrap", slot = _E, type = "circular", speed = 1600, range = 750, delay = 0.25, radius = 130, danger = 1, cc = true, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = false},
	["JhinRShot"] = { displayName = "Curtain Call", missileName = "JhinR", slot = _R, type = "linear", speed = 5000, range = 3500, delay = 0.25, radius = 80, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Jinx"] = {
		["JinxWMissile"] = { displayName = "Zap!", missileName = "JinxWMissile", slot = _W, type = "linear", speed = 3300, range = 1450, delay = 0.6, radius = 60, danger = 1, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["JinxEHit"] = { displayName = "Flame Chompers!", missileName = "JinxEHit", slot = _E, type = "polygon", speed = 1100, range = 900, delay = 1.5, radius = 120, danger = 1, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["JinxR"] = { displayName = "Super Mega Death Rocket!", missileName = "JinxR", slot = _R, type = "linear", speed = 1700, range = 12500, delay = 0.6, radius = 140, danger = 4, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Kaisa"] = {
		["KaisaW"] = { displayName = "Void Seeker", missileName = "KaisaW", slot = _W, type = "linear", speed = 1750, range = 3000, delay = 0.4, radius = 100, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Kalista"] = {
		["KalistaMysticShot"] = { displayName = "Pierce", missileName = "KalistaMysticShot", slot = _Q, type = "linear", speed = 2400, range = 1150, delay = 0.25, radius = 40, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Karma"] = {
		["KarmaQ"] = { displayName = "Inner Flame", missileName = "KarmaQ", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 60, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	["KarmaQMantra"] = { displayName = "Inner Flame [Mantra]", missileName = "KarmaQ", slot = _Q, type = "linear", speed = 1700, range = 950, delay = 0.25, radius = 80, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Karthus"] = {
		["KarthusLayWasteA1"] = { displayName = "Lay Waste [1]", slot = _Q, type = "circular", speed = MathHuge, range = 875, delay = 0.9, radius = 175, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["KarthusLayWasteA2"] = { displayName = "Lay Waste [2]", slot = _Q, type = "circular", speed = MathHuge, range = 875, delay = 0.9, radius = 175, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["KarthusLayWasteA3"] = { displayName = "Lay Waste [3]", slot = _Q, type = "circular", speed = MathHuge, range = 875, delay = 0.9, radius = 175, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Kassadin"] = {
		["ForcePulse"] = { displayName = "Force Pulse", slot = _E, type = "conic", speed = MathHuge, range = 600, delay = 0.3, radius = 0, angle = 80, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["RiftWalk"] = { displayName = "Rift Walk", slot = _R, type = "circular", speed = MathHuge, range = 500, delay = 0.25, radius = 250, danger = 3, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Kayle"] = {
	["KayleQ"] = { displayName = "Radiant Blast", missileName = "KayleQ", slot = _Q, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 60, danger = 1, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Kayn"] = {
		--["KaynQ"] = { displayName = "Reaping Slash", slot = _Q, type = "circular", speed = MathHuge, range = 0, delay = 0.15, radius = 350, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	["KaynW"] = { displayName = "Blade's Reach", missileName = "KaynW", slot = _W, type = "linear", speed = MathHuge, range = 700, delay = 0.55, radius = 90, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Kennen"] = {
		["KennenShurikenHurlMissile1"] = { displayName = "Shuriken Hurl", missileName = "KennenShurikenHurlMissile1", slot = _Q, type = "linear", speed = 1700, range = 1050, delay = 0.175, radius = 50, danger = 2, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Khazix"] = {
	["KhazixW"] = { displayName = "Void Spike [Standard]", missileName = "KhazixW", slot = _W, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 70, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["KhazixWLong"] = { displayName = "Void Spike [Threeway]", slot = _W, type = "threeway", speed = 1700, range = 1000, delay = 0.25, radius = 70, angle = 23, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
	},
	["Kled"] = {
		["KledQ"] = { displayName = "Beartrap on a Rope", missileName = "KledQ", slot = _Q, type = "linear", speed = 1600, range = 800, delay = 0.25, radius = 45, danger = 1, cc = true, collision = false, windwall = true, fow = true, exception = false, extend = true},
		["KledRiderQ"] = { displayName = "Pocket Pistol", missileName = "KledRiderQMissile", slot = _Q, type = "conic", speed = 3000, range = 700, delay = 0.25, radius = 0, angle = 25, danger = 3, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		--["KledEDash"] = { displayName = "Jousting", slot = _E, type = "linear", speed = 1100, range = 550, delay = 0, radius = 90, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["KogMaw"] = {
		["KogMawQ"] = { displayName = "Caustic Spittle", missileName = "KogMawQ", slot = _Q, type = "linear", speed = 1650, range = 1175, delay = 0.25, radius = 70, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["KogMawVoidOozeMissile"] = { displayName = "Void Ooze", missileName = "KogMawVoidOoze", slot = _E, type = "linear", speed = 1400, range = 1360, delay = 0.25, radius = 120, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["KogMawLivingArtillery"] = { displayName = "Living Artillery", slot = _R, type = "circular", speed = MathHuge, range = 1300, delay = 1.1, radius = 200, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["KSante"] = {
		["KSanteQ"] = { displayName = "KSante Q", missileName = "KSanteQ", slot = _Q, type = "linear", speed = 1800, range = 465, delay = 0.25, radius = 75, danger = 1, cc = false, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["KSanteQ3"] = { displayName = "KSante Q3", missileName = "KSanteQ3", slot = _Q, type = "linear", speed = 1100, range = 750, delay = 0.34, radius = 70, danger = 3, cc = false, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
	},
	["Leblanc"] = {
		["LeblancE"] = { displayName = "Ethereal Chains [Standard]", missileName = "LeblancEMissile", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, danger = 1, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["LeblancRE"] = { displayName = "Ethereal Chains [Ultimate]", missileName = "LeblancREMissile", slot = _E, type = "linear", speed = 1750, range = 925, delay = 0.25, radius = 55, danger = 1, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["LeeSin"] = {
		["LeeSinQOne"] = { displayName = "Sonic Wave", missileName = "LeeSinQOne", slot = _Q, type = "linear", speed = 1800, range = 1100, delay = 0.25, radius = 60, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Leona"] = {
		["LeonaZenithBlade"] = { displayName = "Zenith Blade", missileName = "LeonaZenithBlade", slot = _E, type = "linear", speed = 2000, range = 875, delay = 0.25, radius = 70, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["LeonaSolarFlare"] = { displayName = "Solar Flare", slot = _R, type = "circular", speed = MathHuge, range = 1200, delay = 0.85, radius = 300, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Lillia"] = {
		--["LilliaQ"] = { displayName = "Blooming Blows", slot = _Q, type = "circular", speed = MathHuge, range = 450, delay = 0.25, radius = 200, danger = 1, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["LilliaW"] = { displayName = "Watch Out! Eep!", slot = _W, type = "circular", speed = MathHuge, range = 500, delay = 0.25, radius = 250, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["LilliaE"] = { displayName = "Swirlseed", missileName = "LilliaE", slot = _E, type = "linear", speed = 1500, range = 750, delay = 0.4, radius = 150, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		--["LilliaR"] = { displayName = "Lilting Lullaby", slot = _R, type = "circular", speed = MathHuge, range = 700, delay = 1.25, radius = 700, danger = 4, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Lissandra"] = {
		["LissandraQMissile"] = { displayName = "Ice Shard", missileName = "LissandraQ", slot = _Q, type = "linear", speed = 2200, range = 750, delay = 0.25, radius = 75, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["LissandraEMissile"] = { displayName = "Glacial Path", missileName = "LissandraE", slot = _E, type = "linear", speed = 850, range = 1025, delay = 0.25, radius = 125, danger = 2, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Lucian"] = {
		["LucianQ"] = { displayName = "Piercing Light", missileName = "LucianQ", slot = _Q, type = "linear", speed = MathHuge, range = 900, delay = 0.35, radius = 65, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["LucianW"] = { displayName = "Ardent Blaze", missileName = "LucianW", slot = _W, type = "linear", speed = 1600, range = 900, delay = 0.25, radius = 80, danger = 2, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	["LucianR"] = { displayName = "The Culling", missileName = "LucianR", slot = _R, type = "linear", speed = MathHuge, range = 2000, delay = 0.25, radius = 120, danger = 4, cc = false, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Lulu"] = {
		["LuluQ"] = { displayName = "Glitterlance", missileName = "LuluQ", slot = _Q, type = "linear", speed = 1450, range = 925, delay = 0.25, radius = 60, danger = 1, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Lux"] = {
		["LuxLightBinding"] = { displayName = "Light Binding", missileName = "LuxLightBinding", slot = _Q, type = "linear", speed = 1200, range = 1175, delay = 0.25, radius = 70, danger = 1, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["LuxLightStrikeKugel"] = { displayName = "Light Strike Kugel", missileName = "LuxLightStrikeKugel", slot = _E, type = "circular", speed = 1200, range = 1100, delay = 0.25, radius = 300, danger = 3, cc = true, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["LuxMaliceCannon"] = { displayName = "Malice Cannon", missileName = "LuxR", slot = _R, type = "linear", speed = MathHuge, range = 3340, delay = 1, radius = 120, danger = 4, cc = false, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Malphite"] = {
	--["SeismicShard"] = { displayName = "Seismic Shard", missileName = "SeismicShard", slot = _Q, type = "linear", speed = 1200, range = 625, delay = 0.25, radius = 60, danger = 1, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	--	["Landslide"] = { displayName = "Ground Slam", slot = _E, type = "circular", speed = MathHuge, range = 0, delay = 0.242, radius = 400, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["UFSlash"] = { displayName = "Unstoppable Force", missileName = "UFSlash", slot = _R, type = "circular", speed = 1835, range = 1000, delay = 0, radius = 300, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Malzahar"] = {
		["MalzaharQ"] = { displayName = "Call of the Void", slot = _Q, type = "rectangular", speed = 1600, range = 900, delay = 0.5, radius = 100, danger = 1, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Maokai"] = {
		["MaokaiQ"] = { displayName = "Bramble Smash", missileName = "MaokaiQMissile", slot = _Q, type = "linear", speed = 1600, range = 600, delay = 0.375, radius = 110, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["MissFortune"] = {
		["MissFortuneBulletTime"] = { displayName = "Bullet Time", slot = _R, type = "conic", speed = 2000, range = 1400, delay = 0.25, radius = 100, angle = 34, danger = 4, cc = false, collision = false, windwall = true, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Mel"] = {
		["MelQ"] = { displayName = "Radiant Volley", missileName = "MelQ", slot = _Q, type = "linear", speed = 2000, range = 950, delay = 0.25, radius = 80, danger = 2, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["MelE"] = { displayName = "Solar Snare", missileName = "MelE", slot = _E, type = "linear", speed = 1200, range = 1050, delay = 0.25, radius = 100, danger = 3, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		--["MelW"] = { displayName = "Rebuttal", slot = _W, type = "circular", speed = MathHuge, range = 700, delay = 0, radius = 120, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		--["MelR"] = { displayName = "Soul's Reflection", slot = _R, type = "targeted", speed = MathHuge, range = 0, delay = 0.25, radius = 0, danger = 3, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Milio"] = {
		["MilioQ"] = { displayName = "Fire Kick", missileName = "MilioQ", slot = _Q, type = "linear", speed = 1200, range = 1200, delay = 0, radius = 60, danger = 1, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		--["MilioE"] = { displayName = "Warm Hugs", missileName = "MilioE", slot = _E, type = "linear", speed = 1500, range = 650, delay = 0.05, radius = 60, danger = 1, cc = false, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
		--["MilioW"] = { displayName = "Cozy Campfire", slot = _W, type = "circular", speed = MathHuge, range = 350, delay = 0.25, radius = 250, danger = 1, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		--["MilioR"] = { displayName = "Breath of Life", slot = _R, type = "circular", speed = MathHuge, range = 700, delay = 0.25, radius = 700, danger = 3, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
	},
	["Mordekaiser"] = {
		["MordekaiserQ"] = { displayName = "Obliterate", slot = _Q, type = "polygon", speed = MathHuge, range = 675, delay = 0.4, radius = 200, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["MordekaiserE"] = { displayName = "Death's Grasp", slot = _E, type = "polygon", speed = MathHuge, range = 900, delay = 0.9, radius = 140, danger = 3, cc = true, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = false},
	},
	["Morgana"] = {
		["MorganaQ"] = { displayName = "Dark Binding", missileName = "MorganaQ", slot = _Q, type = "linear", speed = 1200, range = 1250, delay = 0.25, radius = 70, danger = 1, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Naafiri"] = {
	["NaafiriQ"] = { displayName = "Naafiri", missileName = "NaafiriQ", slot = _Q, type = "linear", speed = 1200, range = 900, delay = 0.25, radius = 50, danger = 1, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	["NaafiriQRecast"] = { displayName = "Naafiri Recast", missileName = "NaafiriQRecast", slot = _Q, type = "linear", speed = 1200, range = 900, delay = 0.25, radius = 50, danger = 2, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
    },
	["Nami"] = {
		["NamiQ"] = { displayName = "Aqua Prison", missileName = "NamiQ", slot = _Q, type = "circular", speed = MathHuge, range = 875, delay = 1, radius = 180, danger = 1, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["NamiRMissile"] = { displayName = "Tidal Wave", missileName = "NamiR", slot = _R, type = "linear", speed = 850, range = 2750, delay = 0.5, radius = 250, danger = 3, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Nautilus"] = {
		["NautilusAnchorDragMissile"] = { displayName = "Dredge Line", missileName = "NautilusAnchorDragMissile", slot = _Q, type = "linear", speed = 2000, range = 925, delay = 0.25, radius = 90, danger = 3, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Neeko"] = {
		["NeekoQ"] = { displayName = "Blooming Burst", missileName = "NeekoQ", slot = _Q, type = "circular", speed = 1500, range = 800, delay = 0.25, radius = 200, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["NeekoE"] = { displayName = "Tangle-Barbs", missileName = "NeekoE", slot = _E, type = "linear", speed = 1300, range = 1000, delay = 0.25, radius = 70, danger = 1, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Nidalee"] = {
		["JavelinToss"] = { displayName = "Javelin Toss", missileName = "JavelinToss", slot = _Q, type = "linear", speed = 1300, range = 1500, delay = 0.25, radius = 40, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["Bushwhack"] = { displayName = "Bushwhack", slot = _W, type = "circular", speed = MathHuge, range = 900, delay = 1.25, radius = 85, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["Swipe"] = { displayName = "Swipe", slot = _E, type = "conic", speed = MathHuge, range = 350, delay = 0.25, radius = 0, angle = 180, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Nilah"] = {
	["NilahQ"] = { displayName = "Formless Blade", missileName = "NilahQ", slot = _Q, type = "linear", speed = 500, range = 600, delay = 0.25, radius = 150, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = false},
	--["NilahE"] = { displayName = "Slipstream", missileName = "NilahE", slot = _E, type = "linear", speed = 2200, range = 550, delay = 0.00, radius = 150, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = false},
	["NilahR"] = { displayName = "Apotheosis", missileName = "NilahR", slot = _R, type = "circular", speed = MathHuge, range = 0, delay = 1.0, radius = 450, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = false},
	},
	["Nocturne"] = {
		["NocturneDuskbringer"] = { displayName = "Duskbringer", missileName = "NocturneDuskbringer", slot = _Q, type = "linear", speed = 1600, range = 1200, delay = 0.25, radius = 60, danger = 2, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Nunu"] = {
		["NunuR"] = { displayName = "Absolute Zero", slot = _R, type = "circular", speed = MathHuge, range = 0, delay = 3, radius = 650, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Olaf"] = {
		["OlafAxeThrowCast"] = { displayName = "Undertow", missileName = "OlafAxeThrow", slot = _Q, type = "linear", speed = 1600, range = 1000, delay = 0.25, radius = 90, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = false},
	},
	["Orianna"] = {
		["OrianaIzuna"] = { displayName = "Command: Attack", missileName = "OrianaIzuna", slot = _Q, type = "polygon", speed = 1400, range = 825, radius = 80, danger = 2, cc = false, collision = false, windwall = false, fow = true, exception = true, extend = false},
		["OrianaDetonateCommand"] = { displayName = "Command: Shockwave", missileName = "OrianaDetonateCommand", slot = _R, type = "circular", speed = MathHuge, range = 1095, delay = 0.25, radius = 300, danger = 4, cc = true, collision = false, windwall = false, hitbox = true, fow = true, exception = false, extend = false},
	},
	["Ornn"] = {
		["OrnnQ"] = { displayName = "Volcanic Rupture", slot = _Q, type = "linear", speed = 1800, range = 800, delay = 0.3, radius = 65, danger = 1, cc = true, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
		["OrnnE"] = { displayName = "Searing Charge", slot = _E, type = "linear", speed = 1600, range = 800, delay = 0.35, radius = 150, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["OrnnRCharge"] = { displayName = "Call of the Forge God", missileName = "OrnnR", slot = _R, type = "linear", speed = 1650, range = 2500, delay = 0.5, radius = 200, danger = 3, cc = true, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
	},
	["Pantheon"] = {
		["PantheonQTap"] = { displayName = "Comet Spear [Melee]", slot = _Q, type = "linear", speed = MathHuge, range = 575, delay = 0.25, radius = 80, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["PantheonQMissile"] = { displayName = "Comet Spear [Range]", missileName = "PantheonQMissile", slot = _Q, type = "linear", speed = 2700, range = 1200, delay = 0.25, radius = 60, danger = 2, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["PantheonR"] = { displayName = "Grand Starfall", slot = _R, type = "linear", speed = 2250, range = 1350, delay = 4, radius = 250, danger = 3, cc = false, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = false},
	},
	["Poppy"] = {
		["PoppyQSpell"] = { displayName = "Hammer Shock", slot = _Q, type = "linear", speed = MathHuge, range = 430, delay = 0.332, radius = 100, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["PoppyRSpell"] = { displayName = "Keeper's Verdict", missileName = "PoppyR", slot = _R, type = "linear", speed = 2000, range = 1200, delay = 0.33, radius = 100, danger = 3, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Pyke"] = {
		["PykeQMelee"] = { displayName = "Bone Skewer [Melee]", slot = _Q, type = "linear", speed = MathHuge, range = 400, delay = 0.25, radius = 70, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["PykeQRange"] = { displayName = "Bone Skewer [Range]", missileName = "PykeQRange", slot = _Q, type = "linear", speed = 2000, range = 1100, delay = 0.2, radius = 70, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["PykeE"] = { displayName = "Phantom Undertow", slot = _E, type = "linear", speed = 3000, range = 12500, delay = 0, radius = 110, danger = 2, cc = true, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["PykeR"] = { displayName = "Death from Below", slot = _R, type = "circular", speed = MathHuge, range = 750, delay = 0.5, radius = 100, danger = 5, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Qiyana"] = {
		["QiyanaQ"] = { displayName = "Edge of Ixtal", slot = _Q, type = "linear", speed = MathHuge, range = 500, delay = 0.25, radius = 60, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["QiyanaQ_Grass"] = { displayName = "Edge of Ixtal [Grass]", slot = _Q, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 70, danger = 2, cc = false, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
		["QiyanaQ_Rock"] = { displayName = "Edge of Ixtal [Rock]", slot = _Q, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 70, danger = 2, cc = false, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
		["QiyanaQ_Water"] = { displayName = "Edge of Ixtal [Water]", slot = _Q, type = "linear", speed = 1600, range = 925, delay = 0.25, radius = 70, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
		["QiyanaR"] = { displayName = "Supreme Display of Talent", slot = _R, type = "linear", speed = 2000, range = 950, delay = 0.25, radius = 190, danger = 4, cc = true, collision = false, windwall = true, hitbox = true, fow = false, exception = false, extend = true},
	},
	["Quinn"] = {
		["QuinnQ"] = { displayName = "Blinding Assault", missileName = "QuinnQ", slot = _Q, type = "linear", speed = 1550, range = 1025, delay = 0.25, radius = 60, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Rakan"] = {
		["RakanQ"] = { displayName = "Gleaming Quill", missileName = "RakanQMis", slot = _Q, type = "linear", speed = 1850, range = 850, delay = 0.25, radius = 65, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["RakanW"] = { displayName = "Grand Entrance", slot = _W, type = "circular", speed = MathHuge, range = 650, delay = 0.7, radius = 265, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["RekSai"] = {
		["RekSaiQBurrowed"] = { displayName = "Prey Seeker", missileName = "RekSaiQBurrowedMis", slot = _Q, type = "linear", speed = 1950, range = 1625, delay = 0.125, radius = 65, danger = 2, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Rell"] = {
		["RellQ"] = { displayName = "Shattering Strike", slot = _Q, type = "linear", speed = MathHuge, range = 685, delay = 0.35, radius = 80, danger = 2, cc = false, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["RellW"] = { displayName = "Crash Down", slot = _W, type = "linear", speed = MathHuge, range = 500, delay = 0.625, radius = 200, danger = 3, cc = true, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["RellE"] = { displayName = "Attract and Repel", slot = _E, type = "linear", speed = MathHuge, range = 1500, delay = 0.35, radius = 250, danger = 3, cc = true, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["RellR"] = { displayName = "Magnet Storm", slot = _R,  type = "circular", speed = MathHuge, range = 0, delay = 0.25, radius = 400, danger = 5, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	--["Renekton"] = {
	--	["RenektonSliceAndDice"] = { displayName = "Slice and Dice", slot = _E, type = "linear", speed = 1125, range = 450, delay = 0.25, radius = 65, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	--},
	["Rengar"] = {
		["RengarE"] = { displayName = "Bola Strike", missileName = "RengarEMis", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, danger = 1, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Riven"] = {
		["RivenIzunaBlade"] = { displayName = "Wind Slash", slot = _R, type = "conic", speed = 1600, range = 900, delay = 0.25, radius = 0, angle = 75, danger = 5, cc = false, collision = false, windwall = true, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Rumble"] = {
		["RumbleGrenade"] = { displayName = "Electro Harpoon", missileName = "RumbleGrenadeMissile", slot = _E, type = "linear", speed = 2000, range = 850, delay = 0.25, radius = 60, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Ryze"] = {
		["RyzeQ"] = { displayName = "Overload", missileName = "RyzeQ", slot = _Q, type = "linear", speed = 1700, range = 1000, delay = 0.25, radius = 55, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Semira"] = {
		["SemiraQGun"] = { displayName = "Flair", missileName = "SamiraQGun", slot = _Q, type = "linear", speed = 2600, range = 1000, delay = 0.25, radius = 60, danger = 1, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Sejuani"] = {
		["SejuaniR"] = { displayName = "Glacial Prison", missileName = "SejuaniRMissile", slot = _R, type = "linear", speed = 1600, range = 1300, delay = 0.25, radius = 120, danger = 5, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Senna"] = {
		["SennaQCast"] = { displayName = "Piercing Darkness", slot = _Q, type = "linear", speed = MathHuge, range = 1400, delay = 0.4, radius = 80, danger = 2, cc = false, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["SennaW"] = { displayName = "Last Embrace", missileName = "SennaW", slot = _W, type = "linear", speed = 1150, range = 1300, delay = 0.25, radius = 60, danger = 1, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["SennaR"] = { displayName = "Dawning Shadow", missileName = "SennaRWarningMis", slot = _R, type = "linear", speed = 20000, range = 12500, delay = 1, radius = 180, danger = 4, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Seraphine"] = {
		["SeraphineQCast"] = { displayName = "High Note", missileName = "SeraphineQInitialMissile", slot = _Q, type = "circular", speed = 1200, range = 900, delay = 0.25, radius = 350, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["SeraphineECast"] = { displayName = "Beat Drop", missileName = "SeraphineEMissile", slot = _E, type = "linear", speed = 1200, range = 1300, delay = 0.25, radius = 70, danger = 1, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["SeraphineR"] = { displayName = "Encore", missileName = "SeraphineR", slot = _R, type = "linear", speed = 1600, range = 1300, delay = 0.5, radius = 160, danger = 3, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Sett"] = {
		["SettW"] = { displayName = "Haymaker", slot = _W, type = "polygon", speed = MathHuge, range = 790, delay = 0.75, radius = 160, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["SettE"] = { displayName = "Facebreaker", slot = _E, type = "polygon", speed = MathHuge, range = 490, delay = 0.25, radius = 175, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	--["Shen"] = {
	--	["ShenE"] = { displayName = "Shadow Dash", slot = _E, type = "linear", speed = 1200, range = 600, delay = 0, radius = 60, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	--},
	["Shyvana"] = {
		["ShyvanaFireball"] = { displayName = "Flame Breath [Standard]", missileName = "ShyvanaFireballMissile", slot = _E, type = "linear", speed = 1575, range = 925, delay = 0.25, radius = 60, danger = 1, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["ShyvanaFireballDragon2"] = { displayName = "Flame Breath [Dragon]", missileName = "ShyvanaFireballDragonMissile", slot = _E, type = "linear", speed = 1575, range = 975, delay = 0.333, radius = 60, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["ShyvanaTransformLeap"] = { displayName = "Transform Leap", slot = _R, type = "linear", speed = 700, range = 850, delay = 0.25, radius = 150, danger = 4, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Sion"] = {
		["SionQ"] = { displayName = "Decimating Smash", slot = _Q, type = "linear", speed = MathHuge, range = 750, delay = 2, radius = 150, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["SionE"] = { displayName = "Roar of the Slayer", missileName = "SionEMissile", slot = _E, type = "linear", speed = 1800, range = 800, delay = 0.25, radius = 80, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Sivir"] = {
		["SivirQ"] = { displayName = "Boomerang Blade", missileName = "SivirQMissile", slot = _Q, type = "linear", speed = 1350, range = 1250, delay = 0.25, radius = 90, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		--new siver speed 1450 outward 1200 in/return
	},
	["Skarner"] = {
		["SkarnerFractureMissile"] = { displayName = "Fracture", missileName = "SkarnerFractureMissile", slot = _E, type = "linear", speed = 1500, range = 1000, delay = 0.25, radius = 70, danger = 1, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Sona"] = {
		["SonaR"] = { displayName = "Crescendo", missileName = "SonaRMissile", slot = _R, type = "linear", speed = 2400, range = 1000, delay = 0.25, radius = 140, danger = 5, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Soraka"] = {
		["SorakaQ"] = { displayName = "Starcall", missileName = "SorakaQMissile", slot = _Q, type = "circular", speed = 1150, range = 810, delay = 0.25, radius = 235, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = false},
	},
	["Swain"] = {
		["SwainQ"] = { displayName = "Death's Hand", slot = _Q, type = "conic", speed = 5000, range = 725, delay = 0.25, radius = 0, angle = 60, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = false, exception = false, extend = true},
		["SwainW"] = { displayName = "Vision of Empire", slot = _W, type = "circular", speed = MathHuge, range = 3500, delay = 1.5, radius = 300, danger = 1, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["SwainE"] = { displayName = "Nevermove", slot = _E, type = "linear", speed = 1800, range = 850, delay = 0.25, radius = 85, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Sylas"] = {
		["SylasQ"] = { displayName = "Chain Lash", slot = _Q, type = "polygon", speed = MathHuge, range = 775, delay = 0.4, radius = 45, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["SylasE2"] = { displayName = "Abduct", missileName = "SylasE2Mis", slot = _E, type = "linear", speed = 1600, range = 850, delay = 0.25, radius = 60, danger = 2, cc = true, collision = true, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Syndra"] = {
		["SyndraQSpell"] = { displayName = "Dark Sphere", missileName = "SyndraQSpell", slot = _Q, type = "circular", speed = MathHuge, range = 800, delay = 0.625, radius = 200, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = true, exception = true, extend = false},
		--["SyndraWCast"] = { displayName = "Force of Will", slot = _W, type = "circular", speed = 1450, range = 950, delay = 0.25, radius = 225, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["SyndraESphereMissile"] = { displayName = "Scatter the Weak [Sphere]", missileName = "SyndraESphere", slot = _E, type = "linear", speed = 2000, range = 1250, delay = 0.25, radius = 100, danger = 3, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = true, extend = false},
	},
	["TahmKench"] = {
		["TahmKenchQ"] = { displayName = "Tongue Lash", missileName = "TahmKenchQMissile", slot = _Q, type = "linear", speed = 2800, range = 900, delay = 0.25, radius = 70, danger = 2, cc = true, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Taliyah"] = {
		["TaliyahQMis"] = { displayName = "Threaded Volley", missileName = "TaliyahQMis", slot = _Q, type = "linear", speed = 3600, range = 1000, radius = 100, danger = 2, cc = false, collision = true, windwall = true, fow = true, exception = true, extend = true},
		["TaliyahWVC"] = { displayName = "Seismic Shove", slot = _W, type = "circular", speed = MathHuge, range = 900, delay = 0.85, radius = 150, danger = 1, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["TaliyahE"] = { displayName = "Unraveled Earth", slot = _E, type = "conic", speed = 2000, range = 800, delay = 0.45, radius = 0, angle = 80, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["TaliyahR"] = { displayName = "Weaver's Wall", missileName = "TaliyahRMis", slot = _R, type = "linear", speed = 1700, range = 3000, delay = 1, radius = 120, danger = 1, cc = true, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Talon"] = {
		["TalonW"] = { displayName = "Rake", missileName = "TalonWMissileOne", slot = _W, type = "conic", speed = 2500, range = 650, delay = 0.25, radius = 75, angle = 26, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Thresh"] = {
		["ThreshQ"] = { displayName = "Death Sentence", missileName = "ThreshQMissile", slot = _Q, type = "linear", speed = 1900, range = 1100, delay = 0.5, radius = 70, danger = 1, cc = true, collision = true, windwall = true, hitbox = false, fow = true, exception = true, extend = true},
		["ThreshEFlay"] = { displayName = "Flay", slot = _E, type = "polygon", speed = MathHuge, range = 500, delay = 0.389, radius = 110, danger = 3, cc = true, collision = true, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Tristana"] = {
		["TristanaW"] = { displayName = "Rocket Jump", slot = _W, type = "circular", speed = 1100, range = 900, delay = 0.25, radius = 300, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Tryndamere"] = {
		["TryndamereE"] = { displayName = "Spinning Slash", slot = _E, type = "linear", speed = 1300, range = 660, delay = 0, radius = 225, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["TwistedFate"] = {
		["WildCards"] = { displayName = "Wild Cards", missileName = "SealFateMissile", slot = _Q, type = "threeway", speed = 1000, range = 1450, delay = 0.25, radius = 40, angle = 28, danger = 1, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Urgot"] = {
		["UrgotQ"] = { displayName = "Corrosive Charge", missileName = "UrgotQMissile", slot = _Q, type = "circular", speed = MathHuge, range = 800, delay = 0.6, radius = 180, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["UrgotE"] = { displayName = "Disdain", slot = _E, type = "linear", speed = 1540, range = 475, delay = 0.45, radius = 100, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["UrgotR"] = { displayName = "Fear Beyond Death", missileName = "UrgotR", slot = _R, type = "linear", speed = 3200, range = 1600, delay = 0.5, radius = 80, danger = 4, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Varus"] = {
		["VarusQMissile"] = { displayName = "Piercing Arrow", missileName = "VarusQMissile", slot = _Q, type = "linear", speed = 1900, range = 1525, radius = 70, danger = 1, cc = false, collision = false, windwall = true, fow = true, exception = true, extend = true},
		["VarusE"] = { displayName = "Hail of Arrows", missileName = "VarusEMissile", slot = _E, type = "circular", speed = 1500, range = 925, delay = 0.242, radius = 260, danger = 3, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["VarusR"] = { displayName = "Chain of Corruption", missileName = "VarusRMissile", slot = _R, type = "linear", speed = 1500, range = 1200, delay = 0.25, radius = 120, danger = 4, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Veigar"] = {
		["VeigarBalefulStrike"] = { displayName = "Baleful Strike", missileName = "VeigarBalefulStrikeMis", slot = _Q, type = "linear", speed = 2200, range = 900, delay = 0.25, radius = 70, danger = 2, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["VeigarDarkMatter"] = { displayName = "Dark Matter", slot = _W, type = "circular", speed = MathHuge, range = 900, delay = 1.25, radius = 200, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["VeigarEventHorizon"] = { displayName = "Event Horizon", missileName = "VeigarEventHorizon", slot = _E, type = "circular", speed = MathHuge, range = 725, delay = 3.5, radius = 390, danger = 4, cc = true, collision = false, windwall = false, hitbox = true, fow = true, exception = false, extend = false},
	},
	["Vex"] = {
		["VexQ"] = { displayName = "Vex Q Bolt", missileName = "VexQ", slot = _Q, type = "polygon", speed = 2200, range = 1200, delay = 0.15, radius = 80, danger = 3, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Velkoz"] = {
		["VelkozQMissileSplit"] = { displayName = "Plasma Fission [Split]", missileName = "VelkozQMissileSplit", slot = _Q, type = "linear", speed = 2100, range = 1100, radius = 45, danger = 2, cc = true, collision = true, windwall = true, hitbox = false, fow = true, exception = true, extend = false},
		["VelkozQ"] = { displayName = "Plasma Fission", missileName = "VelkozQMissile", slot = _Q, type = "linear", speed = 1300, range = 1050, delay = 0.25, radius = 50, danger = 1, cc = true, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["VelkozW"] = { displayName = "Void Rift", missileName = "VelkozWMissile", slot = _W, type = "linear", speed = 1700, range = 1050, delay = 0.25, radius = 87.5, danger = 1, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["VelkozE"] = { displayName = "Tectonic Disruption", slot = _E, type = "circular", speed = MathHuge, range = 800, delay = 0.8, radius = 185, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
	["Vi"] = {
		["ViQ"] = { displayName = "Vault Breaker", slot = _Q, type = "linear", speed = 1500, range = 725, delay = 0, radius = 90, danger = 2, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Viego"] = {
		["ViegoW"] = { displayName = "Spectral Maw", missileName = "ViegoWMissile", slot = _W, type = "linear", speed = 1300, range = 760, delay = 0, radius = 90, danger = 3, cc = true, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Viktor"] = {
		["ViktorGravitonField"] = { displayName = "Graviton Field", slot = _W, type = "circular", speed = MathHuge, range = 800, delay = 1.75, radius = 270, danger = 1, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["ViktorDeathRayMissile"] = { displayName = "Death Ray", missileName = "ViktorDeathRayMissile", slot = _E, type = "linear", speed = 1050, range = 700, radius = 80, danger = 2, cc = false, collision = false, windwall = true, fow = true, exception = true, extend = true},
	},
	--["Vladimir"] = {
	--	["VladimirHemoplague"] = { displayName = "Hemoplague", slot = _R, type = "circular", speed = MathHuge, range = 700, delay = 0.389, radius = 350, danger = 3, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	--},
	["Warwick"] = {
		["WarwickR"] = { displayName = "Infinite Duress", slot = _R, type = "linear", speed = 1800, range = 3000, delay = 0.1, radius = 55, danger = 4, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Xayah"] = {
		["XayahQ"] = { displayName = "Double Daggers", missileName = "XayahQ", slot = _Q, type = "linear", speed = 2075, range = 1100, delay = 0.5, radius = 45, danger = 1, cc = false, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Xerath"] = {
		--["XerathArcanopulseCharge"] = { displayName = "Arcanopulse", slot = _Q, type = "linear", speed = MathHuge, range = 1400, delay = 0.5, radius = 90, danger = 2, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
		["XerathArcaneBarrage2"] = { displayName = "Arcane Barrage", slot = _W, type = "circular", speed = MathHuge, range = 1000, delay = 0.75, radius = 235, danger = 3, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["XerathMageSpear"] = { displayName = "Mage Spear", missileName = "XerathMageSpearMissile", slot = _E, type = "linear", speed = 1400, range = 1050, delay = 0.2, radius = 60, danger = 1, cc = true, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["XerathLocusOfPower2"] = { displayName = "Rite of the Arcane", missileName = "XerathLocusOfPower2", slot = _R, type = "circular", speed = MathHuge, range = 5000, delay = 0.7, radius = 200, danger = 3, cc = false, collision = false, windwall = false, hitbox = false, fow = true, exception = true, extend = false},
	},
	["XinZhao"] = {
		["XinZhaoW"] = { displayName = "Wind Becomes Lightning", slot = _W, type = "linear", speed = 5000, range = 900, delay = 0.5, radius = 40, danger = 1, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = true},
	},
	["Yasuo"] = {
		["YasuoQ1"] = { displayName = "Steel Tempest", slot = _Q, type = "linear", speed = 1500, range = 475, delay = 0.25, radius = 40, danger = 1, cc = false, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["YasuoQ2"] = { displayName = "Steel Wind Rising", slot = _Q, type = "linear", speed = 1500, range = 475, delay = 0.25, radius = 40, danger = 1, cc = false, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["YasuoQ3"] = { displayName = "Gathering Storm", missileName = "YasuoQ3", slot = _Q, type = "linear", speed = 1200, range = 1100, delay = 0.03, radius = 90, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
	},
	["Yone"] = {
		["YoneQ"] = { displayName = "Mortal Steel [Sword]", slot = _Q, type = "linear", speed = MathHuge, range = 450, delay = 0.25, radius = 40, danger = 1, cc = false, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
		["YoneQ3"] = { displayName = "Mortal Steel [Storm]", missileName = "YoneQ3Missile", slot = _Q, type = "linear", speed = 1500, range = 1050, delay = 0.25, radius = 80, danger = 2, cc = true, collision = false, windwall = true, hitbox = true, fow = true, exception = false, extend = true},
		["YoneR"] = { displayName = "Fate Sealed", slot = _R, type = "linear", speed = MathHuge, range = 1000, delay = 0.75, radius = 112.5, danger = 5, cc = true, collision = false, windwall = false, hitbox = true, fow = false, exception = false, extend = true},
	},
	["Zac"] = {
		["ZacQ"] = { displayName = "Stretching Strikes", missileName = "ZacQMissile", slot = _Q, type = "linear", speed = 2800, range = 800, delay = 0.33, radius = 120, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		--ZacE
	},
	["Zed"] = {
		["ZedQ"] = { displayName = "Razor Shuriken", missileName = "ZedQMissile", slot = _Q, type = "linear", speed = 1700, range = 900, delay = 0.25, radius = 50, danger = 1, cc = false, collision = false, windwall = true, hitbox = true, fow = true, exception = true, extend = true},
	},
	["Zeri"] = {
		["ZeriQ"] = { displayName = "Burst Fire", missileName = "ZeriQMissile", slot = _Q, type = "linear", speed = 1500, range = 840, delay = 0.25, radius = 80, danger = 2, cc = false, collision = true, windwall = true, hitbox = true, fow = true, exception = true, extend = true},
	},
	["Ziggs"] = {
		["ZiggsQ"] = { displayName = "Bouncing Bomb", missileName = "ZiggsQSpell", slot = _Q, type = "polygon", speed = 1750, range = 850, delay = 0.25, radius = 150, danger = 1, cc = false, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["ZiggsW"] = { displayName = "Satchel Charge", missileName = "ZiggsW", slot = _W, type = "circular", speed = 1750, range = 1000, delay = 0.25, radius = 240, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["ZiggsE"] = { displayName = "Hexplosive Minefield", missileName = "ZiggsE", slot = _E, type = "circular", speed = 1800, range = 900, delay = 0.25, radius = 250, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
		["ZiggsR"] = { displayName = "Mega Inferno Bomb", missileName = "ZiggsRBoom", slot = _R, type = "circular", speed = 1550, range = 5000, delay = 0.375, radius = 480, danger = 4, cc = false, collision = false, windwall = false, hitbox = false, fow = true, exception = false, extend = false},
	},
	["Zilean"] = {
		["ZileanQ"] = { displayName = "Time Bomb", missileName = "ZileanQMissile", slot = _Q, type = "circular", speed = MathHuge, range = 900, delay = 0.8, radius = 150, danger = 2, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = false},
	},
	["Zoe"] = {
		["ZoeQMissile"] = { displayName = "Paddle Star [First]", missileName = "ZoeQMissile", slot = _Q, type = "linear", speed = 1200, range = 800, delay = 0.25, radius = 50, danger = 1, cc = false, collision = true, windwall = true, hitbox = false, fow = true, exception = true, extend = true},
		["ZoeQMis2"] = { displayName = "Paddle Star [Second]", missileName = "ZoeQMis2", slot = _Q, type = "linear", speed = 2500, range = 1600, delay = 0, radius = 70, danger = 2, cc = false, collision = true, windwall = true, hitbox = false, fow = true, exception = true, extend = true},
		["ZoeE"] = { displayName = "Sleepy Trouble Bubble", missileName = "ZoeEMis", slot = _E, type = "linear", speed = 1700, range = 800, delay = 0.3, radius = 50, danger = 2, cc = true, collision = true, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
	},
	["Zyra"] = {
		["ZyraQ"] = { displayName = "Deadly Spines", slot = _Q, type = "rectangular", speed = MathHuge, range = 800, delay = 0.825, radius = 200, danger = 1, cc = false, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
		["ZyraE"] = { displayName = "Grasping Roots", missileName = "ZyraE", slot = _E, type = "linear", speed = 1150, range = 1100, delay = 0.25, radius = 70, danger = 1, cc = true, collision = false, windwall = true, hitbox = false, fow = true, exception = false, extend = true},
		["ZyraR"] = { displayName = "Stranglethorns", slot = _R, type = "circular", speed = MathHuge, range = 700, delay = 2, radius = 500, danger = 4, cc = true, collision = false, windwall = false, hitbox = false, fow = false, exception = false, extend = false},
	},
}

local EvadeSpells = {
	["Ahri"] = {
		[3] = { type = 1, displayName = "Spirit Rush", name = "AhriQ-", danger = 4, range = 450, slot = _R, slot2 = HK_R},
	},
	["Annie"] = {
		[2] = { type = 2, displayName = "Molten Shield", name = "AnnieE-", danger = 2, slot = _E, slot2 = HK_E},
	},
	["Blitzcrank"] = {
		[1] = { type = 2, displayName = "Overdrive", name = "BlitzcrankW-", danger = 3, slot = _W, slot2 = HK_W},
	},
	["Corki"] = {
		[1] = { type = 1, displayName = "Valkyrie", name = "CorkiW-", danger = 4, range = 600, slot = _W, slot2 = HK_W},
	},
	["Draven"] = {
		[1] = { type = 2, displayName = "Blood Rush", name = "DravenW-", danger = 3, slot = _W, slot2 = HK_W},
	},
	["Ekko"] = {
		[2] = { type = 1, displayName = "Phase Dive", name = "EkkoE-", danger = 2, range = 325, slot = _E, slot2 = HK_E},
	},
	["Ezreal"] = {
		[2] = { type = 1, displayName = "Arcane Shift", name = "EzrealE-", danger = 3, range = 475, slot = _E, slot2 = HK_E},
	},
	["Fiora"] = {
		[0] = { type = 1, displayName = "Lunge", name = "FioraQ-", danger = 1, range = 400, slot = _Q, slot2 = HK_Q},
		[1] = { type = 7, displayName = "Riposte", name = "FioraW-", danger = 2, range = 750, slot = _W, slot2 = HK_W},
	},
	["Fizz"] = {
		[2] = { type = 3, displayName = "Playful", name = "FizzE-", danger = 3, slot = _E, slot2 = HK_E},
	},
	["Garen"] = {
		[0] = { type = 2, displayName = "Decisive Strike", name = "GarenQ-", danger = 3, slot = _Q, slot2 = HK_Q},
	},
	["Gnar"] = {
		[2] = { type = 1, displayName = "Hop/Crunch", name = "GnarE-", range = 475, danger = 3, slot = _E, slot2 = HK_E},
	},
	["Gragas"] = {
		[2] = { type = 1, displayName = "Body Slam", name = "GragasE-", range = 600, danger = 3, slot = _E, slot2 = HK_E},
	},
	["Graves"] = {
		[2] = { type = 1, displayName = "Quickdraw", name = "GravesE-", range = 425, danger = 1, slot = _E, slot2 = HK_E},
	},
	["Kaisa"] = {
		[2] = { type = 2, displayName = "Supercharge", name = "KaisaE-", danger = 2, slot = _E, slot2 = HK_E},
	},
	["Karma"] = {
		[2] = { type = 2, displayName = "Inspire", name = "KarmaE-", danger = 3, slot = _E, slot2 = HK_E},
	},
	["Kassadin"] = {
		[3] = { type = 1, displayName = "Riftwalk", name = "KassadinR-", range = 500, danger = 3, slot = _R, slot2 = HK_R},
	},
	["Katarina"] = {
		[1] = { type = 2, displayName = "Preparation", name = "KatarinaW-", danger = 3, slot = _W, slot2 = HK_W},
	},
	["Kayn"] = {
		[0] = { type = 1, displayName = "Reaping Slash", name = "KaynQ-", danger = 2, slot = _Q, slot2 = HK_Q},
	},
	["Kennen"] = {
		[2] = { type = 2, displayName = "Lightning Rush", name = "KennenE-", danger = 3, slot = _E, slot2 = HK_E},
	},
	["Khazix"] = {
		[2] = { type = 1, displayName = "Leap", name = "KhazixE-", range = 700, danger = 3, slot = _E, slot2 = HK_E},
	},
	["Kindred"] = {
		[0] = { type = 1, displayName = "Dance of Arrows", name = "KindredQ-", range = 340, danger = 1, slot = _Q, slot2 = HK_Q},
	},
	["Kled"] = {
		[2] = { type = 1, displayName = "Jousting", name = "KledE-", range = 550, danger = 3, slot = _E, slot2 = HK_E},
	},
	["Leblanc"] = {
		[1] = { type = 1, displayName = "Distortion", name = "LeblancW-", range = 600, danger = 3, slot = _W, slot2 = HK_W},
	},
	["Lucian"] = {
		[2] = { type = 1, displayName = "Relentless Pursuit", name = "LucianE-", range = 425, danger = 3, slot = _E, slot2 = HK_E},
	},
	["MasterYi"] = {
		[0] = { type = 4, displayName = "Alpha Strike", name = "MasterYiQ-", range = 600, danger = 3, slot = _Q, slot2 = HK_Q},
	},
	["Morgana"] = {
		[2] = { type = 5, displayName = "Black Shield", name = "MorganaE-", danger = 2, slot = _E, slot2 = HK_E},
	},
	["Pyke"] = {
		[2] = { type = 1, displayName = "Phantom Undertow", name = "PykeE-", range = 550, danger = 3, slot = _E, slot2 = HK_E},
	},
	["Rakan"] = {
		[1] = { type = 1, displayName = "Grand Entrance", name = "RakanW-", range = 600, danger = 3, slot = _W, slot2 = HK_W},
	},
	["Renekton"] = {
		[2] = { type = 1, displayName = "Slice and Dice", name = "RenektonE-", range = 450, danger = 3, slot = _E, slot2 = HK_E},
	},
	["Riven"] = {
		[2] = { type = 1, displayName = "Valor", name = "RivenE-", range = 325, danger = 2, slot = _E, slot2 = HK_E},
	},
	["Rumble"] = {
		[1] = { type = 2, displayName = "Scrap Shield", name = "RumbleW-", danger = 2, slot = _W, slot2 = HK_W},
	},
	["Sejuani"] = {
		[0] = { type = 1, displayName = "Arctic Assault", name = "SejuaniQ-", danger = 3, slot = _Q, slot2 = HK_Q},
	},
	["Shaco"] = {
		[0] = { type = 1, displayName = "Deceive", name = "ShacoQ-", range = 400, danger = 3, slot = _Q, slot2 = HK_Q},
	},
	["Shen"] = {
		[2] = { type = 1, displayName = "Shadow Dash", name = "ShenE-", range = 600, danger = 4, slot = _E, slot2 = HK_E},
	},
	["Shyvana"] = {
		[1] = { type = 2, displayName = "Burnout", name = "ShyvanaW-", danger = 3, slot = _W, slot2 = HK_W},
	},
	["Sivir"] = {
		[2] = { type = 5, displayName = "Spell Shield", name = "SivirE-", danger = 2, slot = _E, slot2 = HK_E},
	},
	["Skarner"] = {
		[1] = { type = 2, displayName = "Crystalline Exoskeleton", name = "SkarnerW-", danger = 3, slot = _W, slot2 = HK_W},
	},
	["Sona"] = {
		[2] = { type = 2, displayName = "Song of Celerity", name = "SonaE-", danger = 3, slot = _E, slot2 = HK_E},
	},
	["Teemo"] = {
		[1] = { type = 2, displayName = "Move Quick", name = "TeemoW-", danger = 3, slot = _W, slot2 = HK_W},
	},
	["Tryndamere"] = {
		[2] = { type = 1, displayName = "Spinning Slash", name = "TryndamereE-", range = 660, danger = 3, slot = _E, slot2 = HK_E},
	},
	["Udyr"] = {
		[2] = { type = 2, displayName = "Bear Stance", name = "UdyrE-", danger = 1, slot = _E, slot2 = HK_E},
	},
	["Vayne"] = {
		[0] = { type = 1, displayName = "Tumble", name = "VayneQ-", range = 300, danger = 1, slot = _Q, slot2 = HK_Q},
	},
	["Vi"] = {
		[0] = { type = 1, displayName = "Vault Breaker", name = "ViQ-", range = 250, danger = 3, slot = _Q, slot2 = HK_Q},
	},
	["Vladimir"] = {
		[1] = { type = 3, displayName = "Sanguine Pool", name = "VladimirW-", danger = 3, slot = _W, slot2 = HK_W},
	},
	["Volibear"] = {
		[0] = { type = 2, displayName = "Rolling Thunder", name = "VolibearQ-", danger = 3, slot = _Q, slot2 = HK_Q},
	},
	["Xayah"] = {
		[3] = { type = 3, displayName = "Featherstorm", name = "XayahR-", danger = 5, slot = _R, slot2 = HK_R},
	},
	["Yasuo"] = {
		[1] = { type = 6, displayName = "Wind Wall", name = "YasuoW-", danger = 2, slot = _W, slot2 = HK_W},
	},
	["Zed"] = {
		[3] = { type = 4, displayName = "Death Mark", name = "ZedR-", range = 625, danger = 4, slot = _R, slot2 = HK_R},
	},
	["Zeri"] = {
		[2] = { type = 1, displayName = "Spark Surge", name = "ZeriE-", range = 300, danger = 2, slot = _E, slot2 = HK_E},
	},
	["Zilean"] = {
		[2] = { type = 2, displayName = "Time Warp", name = "ZileanE-", danger = 3, slot = _E, slot2 = HK_E},
	},
}

local Buffs = {
	["Caitlyn"] = "CaitlynAceintheHole",
	["Belveth"] = "BevethE",
	--["FiddleSticks"] = "DrainChannel", "Crowstorm",
	["Katarina"] = "katarinarsound",
	["MissFortune"] = "missfortunebulletsound",
	["VelKoz"] = "VelkozR",
	["Xerath"] = "XerathLocusOfPower2",
	["Vladimir"] = "VladimirW",
	["Warwick"] = "warwickrsound"
}

--[[ ["CaitlynAceintheHole"] = {Name = "Caitlyn", displayname = "R | Ace in the Hole", spellname = "CaitlynAceintheHole"},
["Crowstorm"] = {Name = "FiddleSticks", displayname = "R | Crowstorm", spellname = "Crowstorm"},
["DrainChannel"] = {Name = "FiddleSticks", displayname = "W | Drain", spellname = "DrainChannel"},
["GalioIdolOfDurand"] = {Name = "Galio", displayname = "R | Idol of Durand", spellname = "GalioIdolOfDurand"},
["ReapTheWhirlwind"] = {Name = "Janna", displayname = "R | Monsoon", spellname = "ReapTheWhirlwind"},
["KarthusFallenOne"] = {Name = "Karthus", displayname = "R | Requiem", spellname = "KarthusFallenOne"},
["KatarinaR"] = {Name = "Katarina", displayname = "R | Death Lotus", spellname = "KatarinaR"},
["LucianR"] = {Name = "Lucian", displayname = "R | The Culling", spellname = "LucianR"},
["AlZaharNetherGrasp"] = {Name = "Malzahar", displayname = "R | Nether Grasp", spellname = "AlZaharNetherGrasp"},
["Meditate"] = {Name = "MasterYi", displayname = "W | Meditate", spellname = "Meditate"},
["MissFortuneBulletTime"] = {Name = "MissFortune", displayname = "R | Bullet Time", spellname = "MissFortuneBulletTime"},
["AbsoluteZero"] = {Name = "Nunu", displayname = "R | Absoulte Zero", spellname = "AbsoluteZero"},
["PantheonRJump"] = {Name = "Pantheon", displayname = "R | Jump", spellname = "PantheonRJump"},
["PantheonRFall"] = {Name = "Pantheon", displayname = "R | Fall", spellname = "PantheonRFall"},
["ShenStandUnited"] = {Name = "Shen", displayname = "R | Stand United", spellname = "ShenStandUnited"},
["Destiny"] = {Name = "TwistedFate", displayname = "R | Destiny", spellname = "Destiny"},
["UrgotSwap2"] = {Name = "Urgot", displayname = "R | Hyper-Kinetic Position Reverser", spellname = "UrgotSwap2"},
["VarusQ"] = {Name = "Varus", displayname = "Q | Piercing Arrow", spellname = "VarusQ"},
["VelkozR"] = {Name = "Velkoz", displayname = "R | Lifeform Disintegration Ray", spellname = "VelkozR"},
["InfiniteDuress"] = {Name = "Warwick", displayname = "R | Infinite Duress", spellname = "InfiniteDuress"},

["CaitlynAceintheHole"] 	= {charName = "Caitlyn", 		slot = _R, 	 	displayName = "Ace in the Hole"},
["Crowstorm"] 				= {charName = "Fiddlesticks", 	slot = _R, 	 	displayName = "Crowstorm"},
["GalioR"] 					= {charName = "Galio", 			slot = _R, 	 	displayName = "Hero's Entrance"},
["KarthusFallenOne"]	 	= {charName = "Karthus", 		slot = _R, 		displayName = "Requiem"},
["KatarinaR"] 				= {charName = "Katarina", 		slot = _R,  	displayName = "Death Lotus"},
["LucianR"] 				= {charName = "Lucian", 		slot = _R, 		displayName = "The Culling"},
["AlZaharNetherGrasp"] 		= {charName = "Malzahar", 		slot = _R, 		displayName = "Nether Grasp"},
["MissFortuneBulletTime"] 	= {charName = "MissFortune", 	slot = _R, 		displayName = "Bullet Time"},
["AbsoluteZero"] 			= {charName = "Nunu", 			slot = _R, 		displayName = "Absolute Zero"},
["PantheonRFall"] 			= {charName = "Pantheon", 		slot = _R, 		displayName = "Grand Skyfall [Fall]"},
["PantheonRJump"] 			= {charName = "Pantheon", 		slot = _R, 	 	displayName = "Grand Skyfall [Jump]"},
["ShenR"] 					= {charName = "Shen", 			slot = _R, 		displayName = "Stand United"},
["Destiny"] 				= {charName = "TwistedFate", 	slot = _R, 	 	displayName = "Destiny"},
["VelKozR"] 				= {charName = "VelKoz", 		slot = _R,  	displayName = "Life Form Disintegration Ray"},
["XerathLocusOfPower2"] 	= {charName = "Xerath", 		slot = _R, 	 	displayName = "Rite of the Arcane"},
["ZacR"] 					= {charName = "Zac", 			slot = _R,  	displayName = "Let's Bounce!"} ]]

local Minions = {
	["SRU_ChaosMinionSuper"] = true,
	["SRU_OrderMinionSuper"] = true,
	["HA_ChaosMinionSuper"] = true,
	["HA_OrderMinionSuper"] = true,
	["SRU_ChaosMinionRanged"] = true,
	["SRU_OrderMinionRanged"] = true,
	["HA_ChaosMinionRanged"] = true,
	["HA_OrderMinionRanged"] = true,
	["SRU_ChaosMinionMelee"] = true,
	["SRU_OrderMinionMelee"] = true,
	["HA_ChaosMinionMelee"] = true,
	["HA_OrderMinionMelee"] = true,
	["SRU_ChaosMinionSiege"] = true,
	["SRU_OrderMinionSiege"] = true,
	["HA_ChaosMinionSiege"] = true,
	["HA_OrderMinionSiege"] = true
}

local function Class()		
	local cls = {}; cls.__index = cls		
	return setmetatable(cls, {__call = function (c, ...)		
		local instance = setmetatable({}, cls)		
		if cls.__init then cls.__init(instance, ...) end		
		return instance		
	end})		
end

--[[
	┌─┐┌─┐┬┌┐┌┌┬┐
	├─┘│ │││││ │ 
	┴  └─┘┴┘└┘ ┴ 
--]]

local function IsPoint(p)
	return p and p.x and type(p.x) == "number" and (p.y and type(p.y) == "number")
end

local function Round(v)
	return v < 0 and MathCeil(v - 0.5) or MathFloor(v + 0.5)
end

local Point2D = Class()

function Point2D:__init(x, y)
	if not x then self.x, self.y = 0, 0
	elseif not y then self.x, self.y = x.x, x.y
	else self.x = x; if y and type(y) == "number" then self.y = y end end
end

function Point2D:__type()
	return "Point2D"
end

function Point2D:__eq(p)
	return self.x == p.x and self.y == p.y
end

function Point2D:__add(p)
	-- Safe addition: return self if p is not a Point2D-like table
	if not IsPoint(p) then return Point2D(self) end
	return Point2D(self.x + p.x, self.y + p.y)
end

function Point2D:__sub(p)
	-- Safe subtraction: return self if p is not a Point2D-like table
	if not IsPoint(p) then return Point2D(self) end
	return Point2D(self.x - p.x, self.y - p.y)
end

function Point2D.__mul(a, b)
	if type(a) == "number" and IsPoint(b) then
		return Point2D(b.x * a, b.y * a)
	elseif type(b) == "number" and IsPoint(a) then
		return Point2D(a.x * b, a.y * b)
	end
end

function Point2D.__div(a, b)
	if type(a) == "number" and IsPoint(b) then
		return Point2D(a / b.x, a / b.y)
	else
		return Point2D(a.x / b, a.y / b)
	end
end

function Point2D:__tostring()
	return "("..self.x..", "..self.y..")"
end

function Point2D:Clone()
	return Point2D(self)
end

function Point2D:Extended(to, distance)
	-- Safely handle missing distance argument (avoid nil multiplication)
	distance = tonumber(distance) or 0
	local diff = Point2D(to) - self
	local dir = diff:Normalized()
	if not dir then return Point2D(self) end
	return self + dir * distance
end

function Point2D:Magnitude()
	return MathSqrt(self:MagnitudeSquared())
end

function Point2D:MagnitudeSquared(p)
	local p = p and Point2D(p) or self
	return self.x * self.x + self.y * self.y
end

function Point2D:Normalize()
	local dist = self:Magnitude()
	self.x, self.y = self.x / dist, self.y / dist
end

function Point2D:Normalized()
	local p = self:Clone()
	local dist = p:Magnitude()
	if dist > 0 then
		p.x, p.y = p.x / dist, p.y / dist
	end
	return p
end

function Point2D:Perpendicular()
	return Point2D(-self.y, self.x)
end

function Point2D:Perpendicular2()
	return Point2D(self.y, -self.x)
end

function Point2D:Rotate(phi)
	local c, s = MathCos(phi), MathSin(phi)
	self.x, self.y = self.x * c + self.y * s, self.y * c - self.x * s
end

function Point2D:Rotated(phi)
	local p = self:Clone()
	p:Rotate(phi); return p
end

function Point2D:Round()
	local p = self:Clone()
	p.x, p.y = Round(p.x), Round(p.y)
	return p
end

--[[
	┬  ┬┌─┐┬─┐┌┬┐┌─┐─┐ ┬
	└┐┌┘├┤ ├┬┘ │ ├┤ ┌┴┬┘
	 └┘ └─┘┴└─ ┴ └─┘┴ └─
--]]

local Vertex = {}

function Vertex:New(x, y, alpha, intersection)
	local new = {x = x, y = y, next = nil, prev = nil, nextPoly = nil, neighbor = nil,
		intersection = intersection, entry = nil, visited = false, alpha = alpha or 0}
	setmetatable(new, self)
	self.__index = self
	return new
end

function Vertex:InitLoop()
	local last = self:GetLast()
	last.prev.next = self
	self.prev = last.prev
end

function Vertex:Insert(first, last)
	local res = first
	while res ~= last and res.alpha < self.alpha do res = res.next end
	self.next = res
	self.prev = res.prev
	if self.prev then self.prev.next = self end
	self.next.prev = self
end

function Vertex:GetLast()
	local res = self
	while res.next and res.next ~= self do res = res.next end
	return res
end

function Vertex:GetNextNonIntersection()
	local res = self
	while res and res.intersection do res = res.next end
	return res
end

function Vertex:GetFirstVertexOfIntersection()
	local res = self
	while true do
		res = res.next
		if not res then break end
		if res == self then break end
		if res.intersection and not res.visited then break end
	end
	return res
end

--[[
	─┐ ┬┌─┐┌─┐┬ ┬ ┬┌─┐┌─┐┌┐┌
	┌┴┬┘├─┘│ ││ └┬┘│ ┬│ ││││
	┴ └─┴  └─┘┴─┘┴ └─┘└─┘┘└┘
--]]

local XPolygon = Class()

function XPolygon:__init()
end

function XPolygon:InitVertices(poly)
	local first, current = nil, nil
	for i = 1, #poly do
		if current then
			current.next = Vertex:New(poly[i].x, poly[i].y)
			current.next.prev = current
			current = current.next
		else
			current = Vertex:New(poly[i].x, poly[i].y)
			first = current
		end
	end
	local next = Vertex:New(first.x, first.y, 1)
	current.next = next
	next.prev = current
	return first, current
end

function XPolygon:FindIntersectionsForClip(subjPoly, clipPoly)
	local found, subject = false, subjPoly
	while subject.next do
		if not subject.intersection then
			local clip = clipPoly
			while clip.next do
				if not clip.intersection then
					local subjNext = subject.next:GetNextNonIntersection()
					local clipNext = clip.next:GetNextNonIntersection()
					local int, segs = self:Intersection(subject, subjNext, clip, clipNext)
					if int and segs then
						found = true
						local alpha1 = self:Distance(subject, int) / self:Distance(subject, subjNext)
						local alpha2 = self:Distance(clip, int) / self:Distance(clip, clipNext)
						local subjectInter = Vertex:New(int.x, int.y, alpha1, true)
						local clipInter = Vertex:New(int.x, int.y, alpha2, true)
						subjectInter.neighbor = clipInter
						clipInter.neighbor = subjectInter
						subjectInter:Insert(subject, subjNext)
						clipInter:Insert(clip, clipNext)
					end
				end
				clip = clip.next
			end
		end
		subject = subject.next
	end
	return found
end

function XPolygon:IdentifyIntersectionType(subjList, clipList, clipPoly, subjPoly, operation)
	local se = self:IsPointInPolygon(clipPoly, subjList)
	if operation == "intersection" then se = not se end
	local subject = subjList
	while subject do
		if subject.intersection then
			subject.entry = se
			se = not se
		end
		subject = subject.next
	end
	local ce = not self:IsPointInPolygon(subjPoly, clipList)
	if operation == "union" then ce = not ce end
	local clip = clipList
	while clip do
		if clip.intersection then
			clip.entry = ce
			ce = not ce
		end
		clip = clip.next
	end
end

function XPolygon:GetClipResult(subjList, clipList)
	subjList:InitLoop(); clipList:InitLoop()
	local walker, result = nil, {}
	while true do
		walker = subjList:GetFirstVertexOfIntersection()
		if walker == subjList then break end
		while true do
			if walker.visited then break end
			walker.visited = true
			walker = walker.neighbor
			TableInsert(result, Point2D(walker.x, walker.y))
			local forward = walker.entry
			while true do
				walker.visited = true
				walker = forward and walker.next or walker.prev
				if walker.intersection then break
				else TableInsert(result, Point2D(walker.x, walker.y)) end
			end
		end
	end
	return result
end

function XPolygon:ClipPolygons(subj, clip, op)
	local result = {}
	local subjList, l1 = self:InitVertices(subj)
	local clipList, l2 = self:InitVertices(clip)
	local ints = self:FindIntersectionsForClip(subjList, clipList)
	if ints then
		self:IdentifyIntersectionType(subjList, clipList, clip, subj, op)
		result = self:GetClipResult(subjList, clipList)
	else
		local inside = self:IsPointInPolygon(clip, subj[1])
		local outside = self:IsPointInPolygon(subj, clip[1])
		if op == "union" then
			if inside then return clip, nil
			elseif outside then return subj, nil end
		elseif op == "intersection" then
			if inside then return subj, nil
			elseif outside then return clip, nil end
		end
		return subj, clip
	end
	return result, nil
end

function XPolygon:CrossProduct(p1, p2)
	return p1.x * p2.y - p1.y * p2.x
end

function XPolygon:Distance(p1, p2)
	return MathSqrt(self:DistanceSquared(p1, p2))
end

function XPolygon:DistanceSquared(p1, p2)
	local dx, dy = p2.x - p1.x, p2.y - p1.y
	return dx * dx + dy * dy
end

function XPolygon:Intersection(a1, b1, a2, b2)
	local a1, b1, a2, b2 = Point2D(a1), Point2D(b1), Point2D(a2), Point2D(b2)
	local r, s = Point2D(b1 - a1), Point2D(b2 - a2); local x = self:CrossProduct(r, s)
	local t, u = self:CrossProduct(a2 - a1, s) / x, self:CrossProduct(a2 - a1, r) / x
	return Point2D(a1 + t * r), t >= 0 and t <= 1 and u >= 0 and u <= 1
end

function XPolygon:IsPointInPolygon(poly, point)
	local result, j = false, #poly
	for i = 1, #poly do
		if poly[i].y < point.y and poly[j].y >= point.y or poly[j].y < point.y and poly[i].y >= point.y then
			if poly[i].x + (point.y - poly[i].y) / (poly[j].y - poly[i].y) * (poly[j].x - poly[i].x) < point.x then
				result = not result
			end
		end
		j = i
	end
	return result
end

function XPolygon:OffsetPolygon(poly, offset)
	local result = {}
	for i, point in ipairs(poly) do
		local j, k = i - 1, i + 1
		if j < 1 then j = #poly end; if k > #poly then k = 1 end
		local p1, p2, p3 = poly[j], poly[i], poly[k]
		local n1 = Point2D(p2 - p1):Normalized():Perpendicular() * offset
		local a, b = Point2D(p1 + n1), Point2D(p2 + n1)
		local n2 = Point2D(p3 - p2):Normalized():Perpendicular() * offset
		local c, d = Point2D(p2 + n2), Point2D(p3 + n2)
		local int = self:Intersection(a, b, c, d)
		local dist = self:Distance(p2, int)
		local dot = (p1.x - p2.x) * (p3.x - p2.x) + (p1.y - p2.y) * (p3.y - p2.y)
		local cross = (p1.x - p2.x) * (p3.y - p2.y) - (p1.y - p2.y) * (p3.x - p2.x)
		local angle = MathAtan2(cross, dot)
		if dist > offset and angle > 0 then
			local ex = p2 + Point2D(int - p2):Normalized() * offset
			local dir = Point2D(ex - p2):Perpendicular():Normalized() * dist
			local e, f = Point2D(ex - dir), Point2D(ex + dir)
			local i1 = self:Intersection(e, f, a, b); local i2 = self:Intersection(e, f, c, d)
			TableInsert(result, i1); TableInsert(result, i2)
		else
			TableInsert(result, int)
		end
    end
    return result
end

local DEvade = Class()

DEvade.SafePos = nil

function DEvade:__init()
	self.DoD, self.Evading, self.InsidePath, self.Loaded = false, false, false, false
	-- Robotic resume movement state + direction lock
	self.ResumePos, self._wasEvading = nil, false
	self._evadeDir = nil -- normalized Point2D vector of initial evade direction
	self._mousePosOrig, self._mouseDirOrig = nil, nil -- original mouse target and direction on evade start
	self._collisionDetected, self._blockingMinion = false, nil -- using minion as shield
	self._currentThreat = nil -- spell name currently being actively evaded (passes danger threshold)
	self.ExtendedPos, self.Flash, self.Flash2, self.FlashRange, self.MousePos, self.MyHeroPos, self.SafePos = nil, nil, nil, nil, nil, nil, nil
	self.Debug, self.DodgeableSpells, self.DetectedSpells, self.Enemies, self.EvadeSpellData, self.OnCreateMisCBs, self.OnImpDodgeCBs, self.OnProcSpellCBs = {}, {}, {}, {}, {}, {}, {}, {}
	self.DebugDetectedMissiles = self.DebugDetectedMissiles or {}
	self.DebugDetectedMissing = self.DebugDetectedMissing or {}
	self.DDTimer, self.DebugTimer, self.MoveTimer, self.MissileID, self.OldTimer, self.NewTimer = 0, 0, 0, 0, 0, 0
	-- Memory optimization: limit spell tracking
	self._maxDetectedSpells = 32
	self._lastHealthPercent = 100
	self.SpellSlot = {[_Q] = "Q", [_W] = "W", [_E] = "E", [_R] = "R"}
	-- Movement throttling (same as DepressiveEvade3.lua)
	self._lastMoveTime = 0
	self._moveThrottle = 0.01 -- Throttle movement commands (10ms minimum between moves)
	-- WASD Movement state tracking
	self._wasdKeysPressed = {
		W = false,
		A = false,
		S = false,
		D = false
	}
		-- WASD key press timestamps (para timeout de seguridad)
	self._wasdKeyPressTime = {
		W = nil,
		A = nil,
		S = nil,
		D = nil
	}
	self._wasdKeyTimeout = 0.5 -- Máximo 500ms con tecla presionada
	self._lastWASDMoveTime = 0
	self._wasdMoveThrottle = 0.05 -- Throttle WASD movement (50ms minimum between WASD updates)
	-- WASD direction persistence (hysteresis)
	self._currentWASDDirection = nil -- Current active WASD direction
	self._lastWASDChangeTime = 0
	self._wasdChangeCooldown = 0.15 -- Minimum time between direction changes (150ms)
	self._wasdKeyTimeout = 0.5 -- Máximo tiempo que una tecla puede estar presionada (500ms)
	self._lockedWASDSpell = nil -- Track which spell the current direction is locked to (spell name)
	self._lockedWASDSpellTime = 0 -- When the direction was locked to this spell
	for i = 1, GameHeroCount() do
		local unit = GameHero(i)
		if unit and unit.team ~= myHero.team then TableInsert(self.Enemies, {unit = unit, spell = nil, missile = nil}) end
	end
	TableSort(self.Enemies, function(a, b) return a.unit.charName < b.unit.charName end)
	local _ver = "1.0" -- static version placeholder; update as needed
	self.JEMenu = MenuElement({type = MENU, id = "DepressiveEvade", name = "Depressive - Evade v".._ver})
	self.JEMenu:MenuElement({id = "Core", name = "Core Settings", type = MENU})
	-- Removed humanizer / smoothing options for deterministic robotic movement
	self.JEMenu.Core:MenuElement({id = "LimitRange", name = "Limit Detection Range", value = true})
	self.JEMenu.Core:MenuElement({id = "GP", name = "Average Game Ping", value = 50, min = 0, max = 250, step = 5})
	self.JEMenu.Core:MenuElement({id = "CQ", name = "Circle Segments Quality", value = 16, min = 10, max = 25, step = 1})
	self.JEMenu.Core:MenuElement({id = "DS", name = "Diagonal Search Step", value = 20, min = 5, max = 100, step = 5})
	self.JEMenu.Core:MenuElement({id = "DC", name = "Diagonal Points Count", value = 4, min = 1, max = 8, step = 1})
	self.JEMenu.Core:MenuElement({id = "LR", name = "Limited Detection Range", value = 5250, min = 500, max = 10000, step = 250})
	self.JEMenu:MenuElement({id = "Main", name = "Main Settings", type = MENU})
	-- Toggleable main enable with hotkey K (robotic style)
	self.JEMenu.Main:MenuElement({id = "Evade", name = "Enable Evade", key = string.byte("K"), toggle = true, value = true})
	self.JEMenu.Main:MenuElement({id = "Dodge", name = "Dodge Spells", value = true})
	self.JEMenu.Main:MenuElement({id = "Draw", name = "Draw Spells", value = true})
	self.JEMenu.Main:MenuElement({id = "Missile", name = "Enable Missile Detection", value = false})
	self.JEMenu.Main:MenuElement({id = "MissileLog", name = "Log missile names (debug)", value = false})
	-- Compatibility option: use double click if single clicks fail (mirrors DepressiveEvade option)
	self.JEMenu.Main:MenuElement({id = "DoubleClick", name = "Use double click (if single clicks fail)", value = true})
	self.JEMenu.Main:MenuElement({id = "UseWASD", name = "Use WASD Movement (League WASD Mode)", value = false})
	self.JEMenu.Main:MenuElement({id = "WASDDebug", name = "Draw WASD Directions Debug", value = false})
	self.JEMenu.Main:MenuElement({id = "WASDLog", name = "Log WASD Selection (Debug)", value = false})
	self.JEMenu.Main:MenuElement({id = "Debug", name = "Debug Evade Points", value = false})
	self.JEMenu.Main:MenuElement({id = "Status", name = "Draw Evade Status", value = false})
	self.JEMenu.Main:MenuElement({id = "SafePos", name = "Draw Safe Position", value = false})
	self.JEMenu.Main:MenuElement({id = "DD", name = "Dodge Only Dangerous", key = string.byte("N")})
	self.JEMenu.Main:MenuElement({id = "dangerLevelToEvade", name = "Danger Level to Evade", value = 1, min = 1, max = 5, step = 1})
	self.JEMenu.Main:MenuElement({id = "EvadeSpellColor", name = "Evade Spell Color", color = DrawColor(192, 255, 0, 0)})
	self.JEMenu.Main:MenuElement({id = "LowDangerSpellColor", name = "Low Danger Draw Color", color = DrawColor(192, 255, 255, 0)})
	-- Collision-based blocking settings
	self.JEMenu.Main:MenuElement({id = "collisionRange", name = "Collision Block Range", value = 500, min = 100, max = 1000, step = 50})
	self.JEMenu.Main:MenuElement({id = "forceArena", name = "Force Arena Map", value = false})
	self.JEMenu.Main:MenuElement({id = "forceMapType", name = "Forzar tipo de mapa", value = 1, drop = {"Auto", "Summoner's Rift", "Howling Abyss", "Arena"}})
	self.JEMenu.Main:MenuElement({id = "Arrow", name = "Dodge Arrow Color", color = DrawColor(192, 255, 255, 0)})
	self.JEMenu.Main:MenuElement({id = "SPC", name = "Safe Position Color", color = DrawColor(192, 255, 255, 255)})
	self.JEMenu.Main:MenuElement({id = "SC", name = "Detected Spell Color", color = DrawColor(192, 255, 255, 255)})
	self.JEMenu:MenuElement({id = "Spells", name = "Spell Settings", type = MENU})
	DelayAction(function()
		self.JEMenu.Spells:MenuElement({id = "DSpells", name = "Dodgeable Spells:", type = SPACE})
		for _, data in ipairs(self.Enemies) do
			local enemy = data.unit.charName
			if SpellDatabase[enemy] then
				for j, spell in pairs(SpellDatabase[enemy]) do
					if not self.JEMenu.Spells[j] then
						self.JEMenu.Spells:MenuElement({id = j, name = ""..enemy.." "..self.SpellSlot[spell.slot].." - "..spell.displayName, type = MENU})
						self.JEMenu.Spells[j]:MenuElement({id = "Dodge"..j, name = "Dodge Spell", value = true})
						self.JEMenu.Spells[j]:MenuElement({id = "Draw"..j, name = "Draw Spell", value = true})
						self.JEMenu.Spells[j]:MenuElement({id = "Force"..j, name = "Force To Dodge", value = spell.danger >= 2})
						if spell.fow then self.JEMenu.Spells[j]:MenuElement({id = "FOW"..j, name = "FOW Detection", value = true}) end
						self.JEMenu.Spells[j]:MenuElement({id = "HP"..j, name = "%HP To Dodge Spell", value = 100, min = 0, max = 100, step = 5})
						self.JEMenu.Spells[j]:MenuElement({id = "ER"..j, name = "Extra Radius", value = 5, min = 0, max = 100, step = 5})
						self.JEMenu.Spells[j]:MenuElement({id = "Danger"..j, name = "Danger Level", value = (spell.danger or 1), min = 1, max = 5, step = 1})
					end
				end
			end
		end
		self.JEMenu.Spells:MenuElement({id = "ESpells", name = "Evading Spells:", type = SPACE})
		local eS = EvadeSpells[myHero.charName]
		if eS then
			for i = 0, 3 do
				if eS[i] then
					self.JEMenu.Spells:MenuElement({id = eS[i].name, name = ""..myHero.charName.." "..self.SpellSlot[eS[i].slot].." - "..eS[i].displayName, type = MENU})
					self.JEMenu.Spells[eS[i].name]:MenuElement({id = "US"..eS[i].name, name = "Use Spell", value = true})
					self.JEMenu.Spells[eS[i].name]:MenuElement({id = "Danger"..eS[i].name, name = "Danger Level > ", value = (eS[i].danger or 1), min = 1, max = 5, step = 1})
				end
			end
		end
	end, 0.04)
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	self.SpecialSpells = {
		["PantheonR"] = function(sP, eP, data)
			local sP2, eP2 = Point2D(eP):Extended(sP, 1150), self:AppendVector(sP, eP, 200)
			return self:RectangleToPolygon(sP2, eP2, data.radius, self.BoundingRadius),
				self:RectangleToPolygon(sP2, eP2, data.radius) end,
		["ZoeE"] = function(sP, eP, data)
			local p1 = self:CircleToPolygon(eP, data.radius + self.BoundingRadius, self.JEMenu.Core.CQ:Value())
			local p2 = self:CircleToPolygon(eP, data.radius, self.JEMenu.Core.CQ:Value())
			self:AddSpell(p1, p2, sP, eP, data, MathHuge, data.range, 5, 250, "ZoeE")
			return p1, p2 end,
		["AatroxQ2"] = function(sP, eP, data)
			local dir = Point2D(sP - eP):Perpendicular():Normalized()*data.radius
			local s1, s2 = Point2D(sP - dir), Point2D(sP + dir)
			local e1, e2 = self:Rotate(s1, eP, MathRad(40)), self:Rotate(s2, eP, -MathRad(40))
			local path = {s1, e1, e2, s2}
			return XPolygon:OffsetPolygon(path, self.BoundingRadius), path end,
		["GravesQLineSpell"] = function(sP, eP, data)
			local s1 = eP - Point2D(eP - sP):Perpendicular():Normalized() * 240
			local e1 = eP + Point2D(eP - sP):Perpendicular():Normalized() * 240
			local p1, p2 = self:RectangleToPolygon(sP, eP, data.radius), self:RectangleToPolygon(s1, e1, 150)
			local path = XPolygon:ClipPolygons(p1, p2, "union")
			return XPolygon:OffsetPolygon(path, self.BoundingRadius), path end,
		["GravesChargeShot"] = function(sP, eP, data)
			local p1, e1 = self:RectangleToPolygon(sP, eP, data.radius), self:AppendVector(sP, eP, 700)
			local dir = Point2D(eP - e1):Perpendicular():Normalized() * 350
			local path = {p1[2], p1[3], Point2D(e1 - dir), Point2D(e1 + dir), p1[4], p1[1]}
			return XPolygon:OffsetPolygon(path, self.BoundingRadius), path end,
		["JinxE"] = function(sP, eP, data)
			local quality = self.JEMenu.Core.CQ:Value()
			local p1 = self:CircleToPolygon(eP, data.radius, quality)
			local dir = Point2D(eP - sP):Perpendicular():Normalized() * 175
			local pos1, pos2 = Point2D(eP + dir), Point2D(eP - dir)
			local p2 = self:CircleToPolygon(pos1, data.radius, quality)
			local p3 = self:CircleToPolygon(pos2, data.radius, quality)
			local p4 = XPolygon:ClipPolygons(p1, p2, "union")
			local path = XPolygon:ClipPolygons(p3, p4, "union")
			return XPolygon:OffsetPolygon(path, self.BoundingRadius), path end,
		["MordekaiserQ"] = function(sP, eP, data)
			local dir = Point2D(eP - sP):Perpendicular():Normalized() * 75
			local s1, s2 = Point2D(sP - dir), Point2D(sP + dir)
			local e1 = self:Rotate(s1, Point2D(s1):Extended(eP, 675), -MathRad(18))
			local e2 = self:Rotate(s2, Point2D(s2):Extended(eP, 675), MathRad(18))
			local path = {s1, e1, e2, s2}
			return XPolygon:OffsetPolygon(path, self.BoundingRadius), path end,
		["MordekaiserE"] = function(sP, eP, data)
			local endPos
			if self:Distance(sP, eP) > data.range then
				endPos = Point2D(sP):Extended(eP, data.range)
			else
				local sP = Point2D(eP):Extended(sP, data.range)
				sP = self:PrependVector(sP, eP, 200)
				endPos = self:AppendVector(sP, eP, 200)
			end
			local path = self:RectangleToPolygon(sP, endPos, data.radius)
			return XPolygon:OffsetPolygon(path, self.BoundingRadius), path end,
		["OrianaIzuna"] = function(sP, eP, data)
			local p1 = self:RectangleToPolygon(sP, eP, data.radius)
			local p2 = self:CircleToPolygon(eP, 135, self.JEMenu.Core.CQ:Value())
			local path = XPolygon:ClipPolygons(p1, p2, "union")
			return XPolygon:OffsetPolygon(path, self.BoundingRadius), path end,
		["RellW"] = function(sP, eP, data)
			local sP2, eP2 = Point2D(eP):Extended(sP, 500), self:AppendVector(sP, eP, 200)
			return self:RectangleToPolygon(sP2, eP2, data.radius, self.BoundingRadius),
				self:RectangleToPolygon(sP2, eP2, data.radius) end,
		["SettW"] = function(sP, eP, data)
			local sPos = self:AppendVector(eP, sP, -40)
			local ePos = Point2D(sPos):Extended(eP, data.range)
			local dir = Point2D(ePos - sPos):Perpendicular():Normalized() * data.radius
			local s1, s2 = Point2D(sPos - dir), Point2D(sPos + dir)
			local e1 = self:Rotate(s1, Point2D(s1):Extended(ePos, data.range), -MathRad(30))
			local e2 = self:Rotate(s2, Point2D(s2):Extended(ePos, data.range), MathRad(30))
			local path = {s1, e1, e2, s2}
			return XPolygon:OffsetPolygon(path, self.BoundingRadius), path end,
		["SettE"] = function(sP, eP, data)
			local sPos = Point2D(sP):Extended(eP, -data.range)
			return self:RectangleToPolygon(sPos, eP, data.radius, self.BoundingRadius),
				self:RectangleToPolygon(sPos, eP, data.radius) end,
		["SylasQ"] = function(sP, eP, data)
			local dir = Point2D(eP - sP):Perpendicular():Normalized() * 100
			local s1, s2 = Point2D(sP - dir), Point2D(sP + dir)
			local e1 = self:Rotate(s1, Point2D(s1):Extended(eP, data.range), MathRad(3))
			local e2 = self:Rotate(s2, Point2D(s2):Extended(eP, data.range), -MathRad(3))
			local p1, p2 = self:RectangleToPolygon(s1, e1, data.radius), self:RectangleToPolygon(s2, e2, data.radius)
			local p3 = self:CircleToPolygon(eP, 180, self.JEMenu.Core.CQ:Value())
			local path = XPolygon:ClipPolygons(p1, p2, "union")
			return XPolygon:OffsetPolygon(path, self.BoundingRadius), path end,
		["ThreshEFlay"] = function(sP, eP, data)
			local sPos = Point2D(sP):Extended(eP, -data.range)
			return self:RectangleToPolygon(sPos, eP, data.radius, self.BoundingRadius),
				self:RectangleToPolygon(sPos, eP, data.radius) end,
		["ZiggsQ"] = function(sP, eP, data)
			local quality = self.JEMenu.Core.CQ:Value()
			local p1, bp1 = self:CircleToPolygon(eP, data.radius, quality),
				self:CircleToPolygon(eP, data.radius + self.BoundingRadius, quality)
			local e1 = Point2D(sP):Extended(eP, 1.4 * self:Distance(sP, eP))
			local p2, bp2 = self:CircleToPolygon(e1, data.radius, quality),
				self:CircleToPolygon(e1, data.radius + self.BoundingRadius, quality)
			local e2 = Point2D(eP):Extended(e1, 1.69 * self:Distance(eP, e1))
			local p3, bp3 = self:CircleToPolygon(e2, data.radius, quality),
				self:CircleToPolygon(e2, data.radius + self.BoundingRadius, quality)
			self:AddSpell(bp1, p1, sP, eP, data, data.speed, data.range, 0.25, data.radius, "ZiggsQ")
			self:AddSpell(bp2, p2, sP, eP, data, data.speed, data.range, 0.75, data.radius, "ZiggsQ")
			self:AddSpell(bp3, p3, sP, eP, data, data.speed, data.range, 1.25, data.radius, "ZiggsQ")
			return nil, nil end,
		["VexQ"] = function(sP, eP, data)
			local quality = self.JEMenu.Core.CQ:Value()
			local vec1 = sP:Extended(eP, 500)
			local p1, p2 = self:RectangleToPolygon(sP, vec1, 160), self:RectangleToPolygon(sP, vec1, 160, self.boundingRadius)
			local p1Skinnyy, p2Skinny = self:RectangleToPolygon(vec1, eP, 80), self:RectangleToPolygon(vec1, eP, 80, self.boundingRadius)
			self:AddSpell(p1, p2, sP, eP, data, 600, 500, 0.15, 160, "VexQ")
			self:AddSpell(p1Skinnyy, p2Skinny, sP, eP, data, 3200, data.range, 0.93, 80, "VexQ")
			return nil, nil end,
	}
	self.SpellTypes = {
		["linear"] = function(sP, eP, data)
			return self:RectangleToPolygon(sP, eP, data.radius, self.BoundingRadius),
				self:RectangleToPolygon(sP, eP, data.radius) end,
		["threeway"] = function(sP, eP, data)
			return self:RectangleToPolygon(sP, eP, data.radius, self.BoundingRadius),
				self:RectangleToPolygon(sP, eP, data.radius) end,
		["rectangular"] = function(sP, eP, data)
			local dir = Point2D(eP - sP):Perpendicular():Normalized() * (data.radius2 or 400)
			local sP2, eP2 = Point2D(eP - dir), Point2D(eP + dir)
			return self:RectangleToPolygon(sP2, eP2, data.radius / 2, self.BoundingRadius),
				self:RectangleToPolygon(sP2, eP2, data.radius / 2) end,
		["circular"] = function(sP, eP, data)
			local quality = self.JEMenu.Core.CQ:Value()
			return self:CircleToPolygon(eP, data.radius + self.BoundingRadius, quality),
				self:CircleToPolygon(eP, data.radius, quality) end,
		["conic"] = function(sP, eP, data)
			local path = self:ConeToPolygon(sP, eP, data.angle)
			return XPolygon:OffsetPolygon(path, self.BoundingRadius), path end,
		["polygon"] = function(sP, eP, data)
			return self:RectangleToPolygon(sP, eP, data.radius, self.BoundingRadius),
				self:RectangleToPolygon(sP, eP, data.radius) end
	}
	DelayAction(function()
		self:LoadEvadeSpells()
		DelayAction(function()
			if self.Flash then
			self.JEMenu.Spells:MenuElement({id = "Flash", name = myHero.charName.." - Summoner Flash", type = MENU})
			self.JEMenu.Spells.Flash:MenuElement({id = "US", name = "Use Flash", value = true})
			self.JEMenu.Spells.Flash:MenuElement({id = "Danger", name = "Danger Level > ", value = 4, min = 1, max = 5, step = 1})
			end
		end, 0.05)
		self.Loaded = true
		-- Use nil instead of numeric 0 as placeholder for no safe position
		self.SafePos = nil
	end, 0.05)
end

function DEvade:DrawArrow(startPos, endPos, color)
	local p1 = endPos-(Point2D(startPos-endPos):Normalized()*30):Perpendicular()+Point2D(startPos-endPos):Normalized()*30
	local p2 = endPos-(Point2D(startPos-endPos):Normalized()*30):Perpendicular2()+Point2D(startPos-endPos):Normalized()*30
	local startPos, endPos, p1, p2 = self:FixPos(startPos), self:FixPos(endPos), self:FixPos(p1), self:FixPos(p2)
	DrawLine(startPos.x, startPos.y, endPos.x, endPos.y, 1, color)
	DrawLine(p1.x, p1.y, endPos.x, endPos.y, 1, color)
	DrawLine(p2.x, p2.y, endPos.x, endPos.y, 1, color)
end

function DEvade:DrawPolygon(poly, y, color)
	local path = {}
	for i = 1, #poly do path[i] = self:FixPos(poly[i], y) end
	DrawLine(path[#path].x, path[#path].y, path[1].x, path[1].y, 0.5, color)
	for i = 1, #path - 1 do DrawLine(path[i].x, path[i].y, path[i + 1].x, path[i + 1].y, 0.5, color) end
end

function DEvade:DrawText(text, size, pos, x, y, color)
	DrawText(text, size, pos.x + x, pos.y + y, color)
end

function DEvade:AppendVector(pos1, pos2, dist)
	return pos2 + Point2D(pos2 - pos1):Normalized() * dist
end

function DEvade:CalculateEndPos(startPos, placementPos, unitPos, speed, range, radius, collision, type, extend)
	local endPos = Point2D(startPos):Extended(placementPos, range)
	if not extend then
		if range > 0 then if self:Distance(unitPos, placementPos) < range then endPos = placementPos end
		else endPos = unitPos end
	else
		if type == "linear" then
			if speed ~= MathHuge then endPos = self:AppendVector(startPos, endPos, radius) end
			if collision then
				local startPos, minions = Point2D(startPos):Extended(placementPos, 45), {}
				for i = 1, GameMinionCount() do
					local minion = GameMinion(i); local minionPos = self:To2D(minion.pos)
					if minion and minion.team == myHero.team and minion.valid and Minions[minion.charName] and
						self:Distance(minionPos, startPos) <= range and minion.maxHealth > 295 and minion.health > 5 then
							local col = self:ClosestPointOnSegment(startPos, placementPos, minionPos)
							if col and self:Distance(col, minionPos) < ((minion.boundingRadius or 45) / 2 + radius) then
								TableInsert(minions, minionPos)
						end
					end
				end
				if #minions > 0 then
					TableSort(minions, function(a, b) return
						self:DistanceSquared(a, startPos) <
						self:DistanceSquared(b, startPos) end)
					local range2 = self:Distance(startPos, minions[1])
					local endPos = Point2D(startPos):Extended(placementPos, range2)
					return endPos, range2
				end
			end
		end
	end
	return endPos, not extend and
		self:Distance(startPos, endPos) or range
end

function DEvade:CircleToPolygon(pos, radius, quality)
	local points = {}
	for i = 0, (quality or 16) - 1 do
		local angle = 2 * MathPi / quality * (i + 0.5)
		local cx, cy = pos.x + radius * MathCos(angle), pos.y + radius * MathSin(angle)
		TableInsert(points, Point2D(cx, cy):Round())
	end
    return points
end

function DEvade:ClosestPointOnSegment(s1, s2, pt)
	local ab = Point2D(s2 - s1)
	local t = ((pt.x - s1.x) * ab.x + (pt.y - s1.y) * ab.y) / (ab.x * ab.x + ab.y * ab.y)
	return t < 0 and Point2D(s1) or (t > 1 and Point2D(s2) or Point2D(s1 + t * ab))
end

function DEvade:ConeToPolygon(startPos, endPos, angle)
	local angle, points = MathRad(angle), {}
	TableInsert(points, Point2D(startPos))
	for i = -angle / 2, angle / 2, angle / 5 do
		local rotated = Point2D(endPos - startPos):Rotated(i)
		TableInsert(points, Point2D(startPos + rotated):Round())
	end
	return points
end

function DEvade:CrossProduct(p1, p2)
	return p1.x * p2.y - p1.y * p2.x
end

function DEvade:Distance(p1, p2)
	return MathSqrt(self:DistanceSquared(p1, p2))
end

function DEvade:DistanceSquared(p1, p2)
	return (p2.x - p1.x) ^ 2 + (p2.y - p1.y) ^ 2
end

function DEvade:DotProduct(p1, p2)
	return p1.x * p2.x + p1.y * p2.y
end

function DEvade:FindIntersections(poly, p1, p2)
	local intersections = {}
	for i = 1, #poly do
		local startPos, endPos = poly[i], poly[i == #poly and 1 or (i + 1)]
		local int = self:LineSegmentIntersection(startPos, endPos, p1, p2)
		if int then TableInsert(intersections, int:Round()) end
	end
	return intersections
end

function DEvade:FixPos(pos, y)
	return Vector(pos.x, y or myHero.pos.y, pos.y):To2D()
end

-- Calculate minimum distance to nearby enemies (avoid moving toward enemies)
function DEvade:GetMinDistanceToEnemies(pos)
	if not pos then return math.huge end
	local minDist = math.huge
	local enemyCount = #self.Enemies
	for i = 1, enemyCount do
		local enemy = self.Enemies[i]
		if enemy and enemy.unit and enemy.unit.valid and not enemy.unit.dead then
			local enemyPos = self:To2D(enemy.unit.pos)
			local dist = self:Distance(pos, enemyPos)
			if dist < minDist then
				minDist = dist
			end
		end
	end
	return minDist
end

-- Check if position is too close to enemies (reject if within danger range)
function DEvade:IsTooCloseToEnemies(pos, dangerRange)
	dangerRange = dangerRange or 600 -- Default danger range: 600 units
	local minDist = self:GetMinDistanceToEnemies(pos)
	return minDist < dangerRange
end

function DEvade:GetBestEvadePos(spells, radius, mode, extra, force)
	-- During evasion, NEVER use MousePos - always prioritize closest safe position
	local evadeModes = {
		[1] = function(a, b) return self:DistanceSquared(a, self.MyHeroPos) < self:DistanceSquared(b, self.MyHeroPos) end,
		[2] = function(a, b) 
			-- If currently evading, ignore MousePos and use closest position
			if self.Evading then
				return self:DistanceSquared(a, self.MyHeroPos) < self:DistanceSquared(b, self.MyHeroPos)
			else
				-- Only use MousePos when NOT evading
				local mPos = self.MyHeroPos:Extended(self.MousePos, radius + self.BoundingRadius)
				return self:DistanceSquared(a, mPos) < self:DistanceSquared(b, mPos)
			end
		end
	}
	local points = {}
	for i, spell in ipairs(spells) do
		local poly = spell.path
		for j = 1, #poly do
			local startPos, endPos = poly[j], poly[j == #poly and 1 or (j + 1)]
			local original = self:ClosestPointOnSegment(startPos, endPos, self.MyHeroPos)
			local distSqr = self:DistanceSquared(original, self.MyHeroPos)
			if distSqr <= 360000 then
				if force then
					local candidate = self:AppendVector(self.MyHeroPos, original, 5)
					if distSqr <= 160000 and not self:IsDangerous(candidate)
						and not MapPosition:inWall(self:To3D(candidate)) then
							TableInsert(points, candidate) end
				else
					local direction = Point2D(endPos - startPos):Normalized()
					local step = self.JEMenu.Core.DC:Value()
					for k = -step, step, 1 do
						local candidate = Point2D(original + k * self.JEMenu.Core.DS:Value() * direction)
						local extended = self:AppendVector(self.MyHeroPos, candidate, self.BoundingRadius)
						candidate = self:AppendVector(self.MyHeroPos, candidate, 5)
						if self:IsSafePos(candidate, extra) and not
							MapPosition:inWall(self:To3D(extended)) then TableInsert(points, candidate) end
					end
				end
			end
		end
	end
	if #points > 0 then
		-- Filter out points that are too close to enemies (avoid moving toward enemies)
		local filteredPoints = {}
		local myDistToEnemies = self:GetMinDistanceToEnemies(self.MyHeroPos)
		
		for _, point in ipairs(points) do
			local pointDistToEnemies = self:GetMinDistanceToEnemies(point)
			-- Rechazar si está más cerca de enemigos que la posición actual Y está muy cerca (< 400 unidades)
			if pointDistToEnemies >= myDistToEnemies or pointDistToEnemies >= 400 then
				TableInsert(filteredPoints, point)
			end
		end
		
		-- Si después del filtro no hay puntos, usar los originales pero con penalización
		if #filteredPoints == 0 then
			filteredPoints = points
		end
		
		-- Sort by mode, but also prefer positions further from enemies
		TableSort(filteredPoints, function(a, b)
			-- First use the original mode sorting
			local modeResult = evadeModes[mode](a, b)
			if modeResult ~= nil then
				-- But also prefer positions further from enemies
				local distA = self:GetMinDistanceToEnemies(a)
				local distB = self:GetMinDistanceToEnemies(b)
				if math.abs(distA - distB) > 100 then -- Si hay diferencia significativa
					return distA > distB -- Preferir la que está más lejos de enemigos
				end
				return modeResult
			end
			return false
		end)
		
		if self.JEMenu.Main.Debug:Value() then
			self.Debug = force and {filteredPoints[1]} or filteredPoints
		end
		return filteredPoints[1]
	end
	return nil
end

function DEvade:GetExtendedSafePos(pos)
	-- Robotic: no smoothing/humanizer, just use the given pos deterministically
	return pos
end

function DEvade:GetMovePath()
	return self:IsMoving() and myHero.pathing.endPos ~= nil
		and self:To2D(myHero.pathing.endPos) or nil
end

function DEvade:GetPaths(startPos, endPos, data, name)
	local path, path2
	if self.SpecialSpells[name] then
		path, path2 = self.SpecialSpells[name](startPos, endPos, data)
		if name ~= "ZoeE" then return path, path2 end
	end
	return self.SpellTypes[data.type](startPos, endPos, data)
end

function DEvade:IsAboutToHit(spell, pos, extra)
	local evadeSpell = #self.EvadeSpellData > 0 and self.EvadeSpellData[extra or 1] or nil
	if extra and evadeSpell and evadeSpell.type ~= 2 then return false end
	local moveSpeed = self:GetMovementSpeed(extra, evadeSpell)
	if moveSpeed == MathHuge then return false end
	local myPos = Point2D(self.MyHeroPos)
	local diff, pos = GameTimer() - spell.startTime, self:AppendVector(myPos, pos, 99999)
	if spell.speed ~= MathHuge and spell.type == "linear" or spell.type == "threeway" then
		if spell.delay > 0 and diff <= spell.delay then
			myPos = Point2D(myPos):Extended(pos, (spell.delay - diff) * moveSpeed)
			if not self:IsPointInPolygon(spell.path, myPos) then return false end
		end
		local va = Point2D(pos - myPos):Normalized() * moveSpeed
		local vb = Point2D(spell.endPos - spell.position):Normalized() * spell.speed
		local da, db = Point2D(myPos - spell.position), Point2D(va - vb)
		local a, b = self:DotProduct(db, db), 2 * self:DotProduct(da, db)
		local c = self:DotProduct(da, da) - (spell.radius + self.BoundingRadius * 2) ^ 2
		local delta = b * b - 4 * a * c
		if delta >= 0 then
			local rtDelta = MathSqrt(delta)
			local t1, t2 = (-b + rtDelta) / (2 * a), (-b - rtDelta) / (2 * a)
			return MathMax(t1, t2) >= 0
		end
		return false
	end
	local t = MathMax(0, spell.range / spell.speed + spell.delay - diff - 0.07)
	return self:IsPointInPolygon(spell.path, myPos:Extended(pos, moveSpeed * t))
end

function DEvade:IsDangerous(pos)
	for i, s in ipairs(self.DetectedSpells) do
		if self:IsPointInPolygon(s.path, pos) then return true end
	end
	return false
end

function DEvade:IsPointInPolygon(poly, point)
	local result, j = false, #poly
	for i = 1, #poly do
		if poly[i].y < point.y and poly[j].y >= point.y or poly[j].y < point.y and poly[i].y >= point.y then
			if poly[i].x + (point.y - poly[i].y) / (poly[j].y - poly[i].y) * (poly[j].x - poly[i].x) < point.x then
				result = not result
			end
		end
		j = i
	end
	return result
end

function DEvade:IsSafePos(pos, extra)
	local dodgeableCount = #self.DodgeableSpells
	for i = 1, dodgeableCount do
		local s = self.DodgeableSpells[i]
		if not s then goto continue end -- Defensive check: ensure spell is not nil
		if self:IsPointInPolygon(s.path, pos) or self:IsAboutToHit(s, pos, extra) then 
			return false 
		end
		::continue::
	end
	return true
end

function DEvade:LineSegmentIntersection(a1, b1, a2, b2)
	local r, s = Point2D(b1 - a1), Point2D(b2 - a2); local x = self:CrossProduct(r, s)
	local t, u = self:CrossProduct(a2 - a1, s) / x, self:CrossProduct(a2 - a1, r) / x
	return x ~= 0 and t >= 0 and t <= 1 and u >= 0 and u <= 1 and Point2D(a1 + t * r) or nil
end

function DEvade:Magnitude(p)
	return MathSqrt(self:MagnitudeSquared(p))
end

function DEvade:MagnitudeSquared(p)
	return p.x * p.x + p.y * p.y
end

function DEvade:PrependVector(pos1, pos2, dist)
	return pos1 + Point2D(pos2 - pos1):Normalized() * dist
end

function DEvade:RectangleToPolygon(startPos, endPos, radius, offset)
	local offset = offset or 0
	local dir = Point2D(endPos - startPos):Normalized()
	local perp = (radius + offset) * dir:Perpendicular()
	return {Point2D(startPos + perp - offset * dir), Point2D(startPos - perp - offset * dir),
		Point2D(endPos - perp + offset * dir), Point2D(endPos + perp + offset * dir)}
end

function DEvade:Rotate(startPos, endPos, theta)
	local dx, dy = endPos.x - startPos.x, endPos.y - startPos.y
	local px, py = dx * MathCos(theta) - dy * MathSin(theta), dx * MathSin(theta) + dy * MathCos(theta)
	return Point2D(px + startPos.x, py + startPos.y)
end

function DEvade:SafePosition()
	return self.SafePos and self:To3D(self.SafePos) or nil
end

function DEvade:To2D(pos)
	return Point2D(pos.x, pos.z or pos.y)
end

function DEvade:To3D(pos)
	-- Defensive: ensure pos is a 2D point-like table before indexing
	if not pos or type(pos) ~= "table" or (type(pos.x) ~= "number" and type(pos[1]) ~= "number") then
		return nil
	end
	return Vector(pos.x, myHero.pos.y, pos.y)
end


-- Simple 2D candidate and scoring helpers adapted from DepressiveEvade3 logic
function DEvade:GetDodgeCandidates(distance)
	local myPos = Point2D(self.MyHeroPos)
	local candidates = {}
	distance = tonumber(distance) or 325
	for i = 0, 7 do
		local angle = MathRad(i * 45)
		local dir = Point2D(MathCos(angle), MathSin(angle))
		table.insert(candidates, Point2D(myPos + dir * distance))
	end
	return candidates
end

-- Get WASD-only dodge candidates (8 directions: 4 cardinal + 4 diagonal)
-- Returns candidates with direction labels for debug visualization
-- If spell is provided, prioritizes perpendicular directions to the spell
function DEvade:GetWASDDodgeCandidates(distance, spell)
	local myPos = Point2D(self.MyHeroPos)
	local candidates = {}
	distance = tonumber(distance) or 325
	
	-- In League of Legends 2D coordinate system:
	-- X positive = East (Right/D)
	-- Y positive = typically South (Down/S) in most implementations
	-- But we need to verify: if Y increases upward, then W is negative Y
	
	-- 8 WASD directions (normalized vectors)
	-- Format: {pos = Point2D, dir = "W/A/S/D/WA/WD/SA/SD", keys = {W, A, S, D}}
	local wasdDirs = {
		-- Direcciones cardinales (CORREGIDAS)
		{dir = Point2D(0, 1), name = "W", keys = {W = true}},       -- Norte = Y positivo
		{dir = Point2D(-1, 0), name = "A", keys = {A = true}},      -- Oeste = X negativo
		{dir = Point2D(0, -1), name = "S", keys = {S = true}},      -- Sur = Y negativo
		{dir = Point2D(1, 0), name = "D", keys = {D = true}},       -- Este = X positivo
		-- Direcciones diagonales (CORREGIDAS)
		{dir = Point2D(-1, 1):Normalized(), name = "WA", keys = {W = true, A = true}},   -- Noroeste
		{dir = Point2D(1, 1):Normalized(), name = "WD", keys = {W = true, D = true}},    -- Noreste
		{dir = Point2D(-1, -1):Normalized(), name = "SA", keys = {S = true, A = true}},  -- Suroeste
		{dir = Point2D(1, -1):Normalized(), name = "SD", keys = {S = true, D = true}},   -- Sureste
	}
	
	-- Calculate spell direction if spell is provided (to prioritize perpendicular directions)
	local spellDir = nil
	local perpDirs = {}
	if spell and spell.position and spell.endPos then
		-- Calculate the closest point on the spell path to the hero
		local closestPoint = self:ClosestPointOnSegment(spell.position, spell.endPos, myPos)
		
		-- Calculate direction from hero to closest point on spell path
		local heroToSpellPath = Point2D(closestPoint - myPos)
		local distToPath = self:Magnitude(heroToSpellPath)
		
		-- Get the spell's travel direction
		spellDir = Point2D(spell.endPos - spell.position):Normalized()
		
		-- If hero is close to the spell path, use perpendicular to spell direction
		-- If hero is far, calculate direction relative to hero's position
		if distToPath < 500 then
			-- Hero is close to path - use perpendicular to spell direction
			local perp1 = spellDir:Perpendicular():Normalized()
			local perp2 = spellDir:Perpendicular2():Normalized()
			perpDirs = {perp1, perp2}
		else
			-- Hero is far from path - calculate direction from hero to path, then perpendicular
			if distToPath > 0 then
				local heroToPathDir = heroToSpellPath:Normalized()
				-- Perpendicular directions relative to hero-to-path direction
				local perp1 = heroToPathDir:Perpendicular():Normalized()
				local perp2 = heroToPathDir:Perpendicular2():Normalized()
				-- Also include perpendiculars to spell direction as backup
				local perp3 = spellDir:Perpendicular():Normalized()
				local perp4 = spellDir:Perpendicular2():Normalized()
				perpDirs = {perp1, perp2, perp3, perp4}
			else
				-- Fallback: use spell direction perpendiculars
				local perp1 = spellDir:Perpendicular():Normalized()
				local perp2 = spellDir:Perpendicular2():Normalized()
				perpDirs = {perp1, perp2}
			end
		end
	end
	
	for _, dirData in ipairs(wasdDirs) do
		local targetPos = Point2D(myPos + dirData.dir * distance)
		
		-- Calculate alignment score with perpendicular direction (higher = better for dodging)
		local perpScore = 0
		if spellDir and #perpDirs > 0 then
			-- Calculate direction from hero to closest point on spell path
			local closestPoint = self:ClosestPointOnSegment(spell.position, spell.endPos, myPos)
			local heroToPath = Point2D(closestPoint - myPos)
			local heroDistToPath = self:Magnitude(heroToPath)
			local heroToPathDir = heroDistToPath > 0 and heroToPath:Normalized() or nil
			
			-- Detect if spell comes from the side (horizontal movement: A/D direction)
			-- Check if spell direction is primarily horizontal (left/right)
			local spellDirHorizontal = math.abs(spellDir.x) > math.abs(spellDir.y) * 1.5
			-- Check if candidate direction is horizontal (A/D)
			local candidateDirHorizontal = math.abs(dirData.dir.x) > math.abs(dirData.dir.y) * 1.5
			-- Check if candidate direction is vertical (W/S)
			local candidateDirVertical = math.abs(dirData.dir.y) > math.abs(dirData.dir.x) * 1.5
			
			-- CRITICAL: When spell comes from side (horizontal), heavily prioritize vertical movement (W/S)
			if spellDirHorizontal then
				if candidateDirVertical then
					-- Vertical movement (W/S) when spell is horizontal - STRONG bonus
					perpScore = perpScore + 15 -- Very large bonus
				elseif candidateDirHorizontal then
					-- Horizontal movement (A/D) when spell is horizontal - STRONG penalty
					perpScore = perpScore - 20 -- Very large penalty
				end
			end
			
			-- Detect if spell comes from top/bottom (vertical movement: W/S direction)
			local spellDirVertical = math.abs(spellDir.y) > math.abs(spellDir.x) * 1.5
			if spellDirVertical then
				if candidateDirHorizontal then
					-- Horizontal movement (A/D) when spell is vertical - STRONG bonus
					perpScore = perpScore + 15 -- Very large bonus
				elseif candidateDirVertical then
					-- Vertical movement (W/S) when spell is vertical - STRONG penalty
					perpScore = perpScore - 20 -- Very large penalty
				end
			end
			
			-- Calculate if this direction moves AWAY from the spell path (most important)
			local awayFromPathScore = 0
			if heroToPathDir then
				local towardPath = self:DotProduct(dirData.dir, heroToPathDir)
				-- Negative dot product = moving away from path (good!)
				-- Positive dot product = moving toward path (bad!)
				
				-- CRITICAL: When hero is very close, this becomes MUCH more important
				local isHeroVeryClose = heroDistToPath < ((spell.radius or 60) + self.BoundingRadius + 150)
				local closeMultiplier = isHeroVeryClose and 5 or 1 -- 5x when very close
				
				if towardPath < -0.1 then
					-- Moving away from spell path - STRONG bonus
					awayFromPathScore = math.abs(towardPath) * 10 * closeMultiplier -- Much larger bonus when close
				elseif towardPath > 0.3 then
					-- Moving toward the spell path - STRONG penalty
					awayFromPathScore = -towardPath * 10 * closeMultiplier -- Much larger penalty when close
				end
			end
			
			-- Find the best alignment with any perpendicular direction
			local bestAlignment = 0
			for _, perpDir in ipairs(perpDirs) do
				local alignment = math.abs(self:DotProduct(dirData.dir, perpDir))
				if alignment > bestAlignment then
					bestAlignment = alignment
				end
			end
			perpScore = perpScore + bestAlignment * 2 + awayFromPathScore -- Weight perpendicular alignment
			
			-- Penalize directions that align with spell direction (moving along spell path)
			local spellAlignment = math.abs(self:DotProduct(dirData.dir, spellDir))
			if spellAlignment > 0.5 then
				perpScore = perpScore - spellAlignment * 10 -- Very heavy penalty for moving along spell (increased)
			elseif spellAlignment > 0.3 then
				perpScore = perpScore - spellAlignment * 5 -- Heavy penalty (increased)
			end
		end
		
		TableInsert(candidates, {
			pos = targetPos,
			dir = dirData.name,
			keys = dirData.keys,
			direction = dirData.dir,
			perpScore = perpScore -- Store for sorting/prioritization
		})
	end
	
	-- Sort by perpendicular score (best perpendicular directions first)
	-- But don't completely exclude non-perpendicular directions - they might still be safe
	if spellDir then
		TableSort(candidates, function(a, b)
			-- Prioritize perpendicular, but don't completely exclude others
			-- If scores are close (within 0.2), consider them equal
			if math.abs(a.perpScore - b.perpScore) < 0.2 then
				return false -- Keep original order if scores are similar
			end
			return a.perpScore > b.perpScore
		end)
	end
	
	return candidates
end

function DEvade:CandidateUnsafeCount(pt, ignoreSpell)
	local count = 0
	for i = 1, #self.DetectedSpells do
		local s = self.DetectedSpells[i]
		if s ~= ignoreSpell then
			if self:IsPointInPolygon(s.path, pt) then count = count + 1 end
		end
	end
	return count
end

function DEvade:ShouldDodge(spell)
	if not spell then return false, 0 end
	
	-- Calculate time to impact more accurately
	local t = self:GetTimeToSpellHit(spell)
	local reaction = (self.JEMenu.Main.ReactionTime and self.JEMenu.Main.ReactionTime:Value()) or 0.5
	
	-- IMPORTANT: Only dodge if time to impact is POSITIVE and sufficient (not when already hitting)
	-- Add latency compensation for early reaction
	local latency = (Game.Latency and Game.Latency() or 0) / 1000
	local minTimeToDodge = reaction + latency + 0.1 -- Minimum time needed to dodge
	
	-- If time is negative or too small, spell is already hitting or about to hit - too late to dodge
	if t <= 0 or t < minTimeToDodge then
		return false, t
	end
	
	-- Check if hero is inside polygon OR spell path is close enough to be dangerous
	local isInside = self:IsPointInPolygon(spell.path, self.MyHeroPos)
	local isClose = false
	
	if spell.position and spell.endPos then
		local closest = self:ClosestPointOnSegment(spell.position, spell.endPos, self.MyHeroPos)
		local distToPath = self:Distance(closest, self.MyHeroPos)
		local dangerRadius = (spell.radius or 60) + self.BoundingRadius + 50 -- Smaller margin for more precise detection
		isClose = distToPath <= dangerRadius
	end
	
	-- Only dodge if we have enough time AND (inside polygon or close to path)
	-- This ensures we dodge BEFORE impact, not when already hitting
	if (isInside or isClose) and t >= minTimeToDodge and t <= (reaction + 1.0) then
		return true, t
	end
	
	return false, 0
end

function DEvade:GetBestDodgePosition(spell)
	local baseDist = (self.JEMenu.Main.DodgeDistance and self.JEMenu.Main.DodgeDistance:Value()) or 325
	local useWASD = self:IsWASDMode()
	
	-- Calculate distance to path to determine if we need more distance
	local dist = baseDist
	if spell and spell.position and spell.endPos then
		local myPos = Point2D(self.MyHeroPos)
		local heroClosest = self:ClosestPointOnSegment(spell.position, spell.endPos, myPos)
		local heroToPath = Point2D(heroClosest - myPos)
		local heroDistToPath = self:Magnitude(heroToPath)
		local minSafeDist = (spell.radius or 60) + self.BoundingRadius + 150
		
		-- If hero is very close to path, increase dodge distance to escape faster
		if heroDistToPath < minSafeDist then
			-- Increase distance more when closer
			local closenessRatio = math.max(0, 1 - (heroDistToPath / minSafeDist))
			dist = baseDist + (closenessRatio * 200) -- Up to 200 extra units when very close
		end
	end
	
	-- Use WASD candidates if WASD mode is enabled
	local candidates, wasdCandidates = nil, nil
	if useWASD then
		-- Pass spell to prioritize perpendicular directions
		wasdCandidates = self:GetWASDDodgeCandidates(dist, spell)
		-- Convert WASD candidates to regular format for compatibility
		candidates = {}
		for _, wasdCand in ipairs(wasdCandidates) do
			TableInsert(candidates, wasdCand.pos)
		end
		-- Store WASD data for debug visualization
		self._lastWASDCandidates = wasdCandidates
	else
		candidates = self:GetDodgeCandidates(dist)
		self._lastWASDCandidates = nil
	end
	
	local best, bestScore, bestDistPath = nil, 1e9, -1
	local bestWASDDir = nil -- Store which WASD direction was selected
	local myPos = Point2D(self.MyHeroPos)
	local mousePos = Point2D(self.MousePos or self.MyHeroPos)
	local mouseDir = Point2D(mousePos - myPos):Normalized()
	
	-- Get current distance to enemies to compare
	local myDistToEnemies = self:GetMinDistanceToEnemies(myPos)
	
	-- First pass: collect all candidates with their safety scores
	local allCandidates = {}
	
	for i, cand in ipairs(candidates) do
		local candidateData = {
			pos = cand,
			wasdDir = useWASD and wasdCandidates and wasdCandidates[i] or nil,
			index = i,
			rejected = false,
			rejectionReason = nil,
			safetyScore = 0
		}
		
		-- Check if position is in wall (hard rejection - can't move into walls)
		if MapPosition:inWall(self:To3D(cand)) then
			candidateData.rejected = true
			candidateData.rejectionReason = "wall"
			TableInsert(allCandidates, candidateData)
			goto continue_candidate
		end
		
		-- Check if position is safe from ALL spells
		local isSafe = self:IsSafePos(cand, nil)
		if not isSafe then
			candidateData.safetyScore = candidateData.safetyScore - 1000 -- Heavy penalty but don't reject yet
		end
		
		-- Check if candidate is inside the spell's path polygon (hard rejection)
		if spell and self:IsPointInPolygon(spell.path, cand) then
			candidateData.rejected = true
			candidateData.rejectionReason = "inside_spell_path"
			TableInsert(allCandidates, candidateData)
			goto continue_candidate
		end
		
		-- Calculate spell-related metrics
		local spellDir = nil
		local candDir = Point2D(cand - myPos):Normalized()
		local distToPath = 0
		local alignmentWithSpell = 0
		local movingAway = false
		
		if spell and spell.position and spell.endPos then
			spellDir = Point2D(spell.endPos - spell.position):Normalized()
			
			-- Calculate closest point on spell path to HERO (not candidate)
			local heroClosest = self:ClosestPointOnSegment(spell.position, spell.endPos, myPos)
			local heroToPath = Point2D(heroClosest - myPos)
			local heroDistToPath = self:Magnitude(heroToPath)
			
			-- Calculate closest point on spell path to CANDIDATE
			local closest = self:ClosestPointOnSegment(spell.position, spell.endPos, cand)
			distToPath = self:Distance(closest, cand)
			
			-- Calculate if we're moving away from the spell path
			local toClosest = Point2D(closest - myPos):Normalized()
			movingAway = self:DotProduct(candDir, toClosest) < 0
			
			-- Calculate alignment with spell direction
			alignmentWithSpell = self:DotProduct(candDir, spellDir)
			
			-- Calculate if we're moving toward or away from the spell path (from hero's perspective)
			local heroToPathDir = heroDistToPath > 0 and heroToPath:Normalized() or nil
			local movingTowardPath = false
			if heroToPathDir then
				movingTowardPath = self:DotProduct(candDir, heroToPathDir) > 0.3
			end
			
			-- Penalize strong alignment with spell (moving toward it)
			if alignmentWithSpell > 0.8 then
				candidateData.safetyScore = candidateData.safetyScore - 500 -- Very dangerous
			elseif alignmentWithSpell > 0.6 then
				candidateData.safetyScore = candidateData.safetyScore - 200 -- Dangerous
			end
			
			-- Penalize moving toward the spell path when hero is far from it
			if heroDistToPath > 300 and movingTowardPath then
				candidateData.safetyScore = candidateData.safetyScore - 300 -- Moving toward path when far
			end
			
			-- CRITICAL: Heavily penalize being too close to spell path, especially if not moving away
			local minSafeDistance = (spell.radius or 60) + self.BoundingRadius + (movingAway and 50 or 100)
			if distToPath < minSafeDistance then
				if not movingAway then
					candidateData.safetyScore = candidateData.safetyScore - 500 -- Very close and moving toward - very dangerous
				else
					candidateData.safetyScore = candidateData.safetyScore - 150 -- Close but moving away - still risky
				end
			else
				-- Bonus for being far from path AND moving away
				if movingAway and distToPath > minSafeDistance + 100 then
					candidateData.safetyScore = candidateData.safetyScore + 100 -- Good: far and moving away
				end
			end
			
			-- CRITICAL: When hero is very close to path, give massive bonus to candidates that are far from path
			local isHeroVeryClose = heroDistToPath < ((spell.radius or 60) + self.BoundingRadius + 150)
			if isHeroVeryClose then
				-- Bonus based on how far the candidate is from the path
				local distanceBonus = (distToPath - heroDistToPath) * 2 -- Bonus for increasing distance
				if distanceBonus > 0 then
					candidateData.safetyScore = candidateData.safetyScore - distanceBonus -- Negative = better (lower score)
				end
				
				-- Extra bonus if moving away when close
				if movingAway then
					candidateData.safetyScore = candidateData.safetyScore - 300 -- Large bonus
				end
			end
			
			-- CRITICAL: Calculate if candidate is moving AWAY from spell path (from hero's perspective)
			-- This is the most important factor when spell comes from side
			if heroToPathDir then
				local candTowardPath = self:DotProduct(candDir, heroToPathDir)
				
				-- CRITICAL: When hero is very close to path, prioritize moving away MUCH more
				local isVeryClose = heroDistToPath < ((spell.radius or 60) + self.BoundingRadius + 100)
				local closeMultiplier = isVeryClose and 3 or 1 -- 3x bonus/penalty when very close
				
				if candTowardPath > 0.2 then
					-- Moving toward spell path - very dangerous when spell comes from side
					candidateData.safetyScore = candidateData.safetyScore - (400 * closeMultiplier)
				elseif candTowardPath < -0.2 then
					-- Moving away from spell path - very good when spell comes from side
					-- When close, this is CRITICAL - give massive bonus
					candidateData.safetyScore = candidateData.safetyScore + (200 * closeMultiplier)
					
					-- Extra bonus if very close and moving away - this is the most important thing
					if isVeryClose then
						candidateData.safetyScore = candidateData.safetyScore + 500 -- Massive bonus for moving away when close
					end
				end
			end
			
			-- CRITICAL: Detect when spell comes from side and prioritize perpendicular movement
			-- Check if spell direction is primarily horizontal (A/D direction)
			local spellDirHorizontal = math.abs(spellDir.x) > math.abs(spellDir.y) * 1.5
			-- Check if spell direction is primarily vertical (W/S direction)
			local spellDirVertical = math.abs(spellDir.y) > math.abs(spellDir.x) * 1.5
			
			-- Check candidate direction alignment
			local candidateDirHorizontal = math.abs(candDir.x) > math.abs(candDir.y) * 1.5
			local candidateDirVertical = math.abs(candDir.y) > math.abs(candDir.x) * 1.5
			
			-- When spell comes from side (horizontal), prioritize vertical movement (W/S)
			if spellDirHorizontal then
				if candidateDirVertical then
					-- Moving vertically (W/S) when spell is horizontal - STRONG bonus
					candidateData.safetyScore = candidateData.safetyScore + 300
				elseif candidateDirHorizontal then
					-- Moving horizontally (A/D) when spell is horizontal - STRONG penalty
					candidateData.safetyScore = candidateData.safetyScore - 600
				end
			end
			
			-- When spell comes from top/bottom (vertical), prioritize horizontal movement (A/D)
			if spellDirVertical then
				if candidateDirHorizontal then
					-- Moving horizontally (A/D) when spell is vertical - STRONG bonus
					candidateData.safetyScore = candidateData.safetyScore + 300
				elseif candidateDirVertical then
					-- Moving vertically (W/S) when spell is vertical - STRONG penalty
					candidateData.safetyScore = candidateData.safetyScore - 600
				end
			end
			
			-- Additional penalty for moving in same direction as spell (alignment)
			local absAlignment = math.abs(alignmentWithSpell)
			if absAlignment > 0.7 then
				-- Very aligned with spell direction - VERY dangerous
				candidateData.safetyScore = candidateData.safetyScore - 800
			elseif absAlignment > 0.5 then
				-- Aligned with spell direction - dangerous
				candidateData.safetyScore = candidateData.safetyScore - 400
			end
		end
		
		-- Check distance to enemies
		local candDistToEnemies = self:GetMinDistanceToEnemies(cand)
		if candDistToEnemies < myDistToEnemies then
			if candDistToEnemies < 400 then
				candidateData.safetyScore = candidateData.safetyScore - 400 -- Very close to enemies
			else
				candidateData.safetyScore = candidateData.safetyScore - 100 -- Closer to enemies
			end
		else
			candidateData.safetyScore = candidateData.safetyScore + 50 -- Bonus for moving away from enemies
		end
		
		-- Store calculated values for scoring
		candidateData.distToPath = distToPath
		candidateData.alignmentWithSpell = alignmentWithSpell
		candidateData.movingAway = movingAway
		candidateData.candDistToEnemies = candDistToEnemies
		candidateData.isSafe = isSafe
		
		TableInsert(allCandidates, candidateData)
		::continue_candidate::
	end
	
	-- Separate candidates into safe and unsafe
	local safeCandidates = {}
	local unsafeCandidates = {}
	
	for _, candData in ipairs(allCandidates) do
		if candData.rejected then
			-- Skip completely rejected candidates
		elseif candData.isSafe and candData.safetyScore >= -100 then
			TableInsert(safeCandidates, candData)
		else
			TableInsert(unsafeCandidates, candData)
		end
	end
	
	-- Use safe candidates if available, otherwise use unsafe (better than nothing)
	local candidatesToEvaluate = #safeCandidates > 0 and safeCandidates or unsafeCandidates
	
	if #candidatesToEvaluate == 0 then
		-- No candidates at all - this shouldn't happen, but log it
		if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.WASDLog and self.JEMenu.Main.WASDLog:Value() then
			print("[WASD Evade] ERROR: No candidates available at all!")
		end
		return nil, 1e9
	end
	
	-- Now score the candidates
	for _, candData in ipairs(candidatesToEvaluate) do
		local cand = candData.pos
		local distToPath = candData.distToPath or 0
		local movingAwayFromPath = candData.movingAway or false
		local candDistToEnemies = candData.candDistToEnemies or myDistToEnemies
		
		local unsafe = self:CandidateUnsafeCount(cand, spell)
		
		-- CRITICAL: Heavily penalize positions that are too close to the spell path
		-- But be more lenient if moving away from the path
		local pathPenalty = 0
		if spell and distToPath > 0 then
			local minSafeDist = (spell.radius or 60) + self.BoundingRadius + (movingAwayFromPath and 100 or 150)
			if distToPath < minSafeDist then
				-- Less penalty if moving away from path
				local penaltyMultiplier = movingAwayFromPath and 5 or 10
				pathPenalty = (minSafeDist - distToPath) * penaltyMultiplier
			end
		end
		
		local bias = 0
		if mouseDir and mouseDir.x then
			local candDir = Point2D(cand - myPos):Normalized()
			bias = 1 - math.max(-1, math.min(1, self:DotProduct(candDir, mouseDir)))
		end
		
		-- Score: penalizar posiciones cerca de enemigos, premiar posiciones lejos de enemigos
		local enemyPenalty = 0
		if candDistToEnemies < myDistToEnemies then
			-- Penalizar si se acerca a enemigos
			enemyPenalty = (myDistToEnemies - candDistToEnemies) / 100 -- Penalty proporcional a cuánto se acerca
		else
			-- Premiar si se aleja de enemigos
			enemyPenalty = -(candDistToEnemies - myDistToEnemies) / 200 -- Bonus por alejarse
		end
		
		-- Calculate additional bonus for moving away from spell path (critical for side-coming spells)
		local awayFromPathBonus = 0
		if spell and spell.position and spell.endPos then
			local heroClosest = self:ClosestPointOnSegment(spell.position, spell.endPos, myPos)
			local heroToPath = Point2D(heroClosest - myPos)
			local heroToPathDir = self:Magnitude(heroToPath) > 0 and heroToPath:Normalized() or nil
			
			if heroToPathDir then
				local candDir = Point2D(cand - myPos):Normalized()
				local towardPath = self:DotProduct(candDir, heroToPathDir)
				
				-- CRITICAL: Strong bonus for moving away from path (negative dot = away)
				if towardPath < -0.1 then
					awayFromPathBonus = -math.abs(towardPath) * 100 -- Large bonus (negative = good)
				elseif towardPath > 0.2 then
					awayFromPathBonus = towardPath * 200 -- Large penalty for moving toward path
				end
			end
		end
		
		-- Score: lower is better, so we add penalties and subtract bonuses
		-- Include safety score in final score
		-- Bonus for moving away from spell path
		local awayBonus = movingAwayFromPath and -(distToPath / 500) or 0
		local score = unsafe + bias + pathPenalty + enemyPenalty - (distToPath / 1000) + awayBonus + candData.safetyScore + awayFromPathBonus
		
		-- More lenient: only heavily penalize if very close AND not moving away
		if distToPath > 0 and distToPath < ((spell and spell.radius or 60) + self.BoundingRadius + 50) then
			if not movingAwayFromPath then
				score = score + 300 -- Heavy penalty for positions too close to path and moving toward it
			else
				score = score + 50 -- Smaller penalty if moving away
			end
		end
		
		-- HYSTERESIS: Give bonus to current direction to prevent frequent changes
		if useWASD and candData.wasdDir and self._currentWASDDirection then
			if candData.wasdDir.dir == self._currentWASDDirection.dir then
				-- Same direction as current - give significant bonus to maintain it
				score = score - 50 -- Negative = bonus (lower score is better)
				
				-- Extra bonus if current direction is still safe
				if candData.isSafe and candData.safetyScore >= -50 then
					score = score - 30 -- Additional bonus for safe current direction
				end
			end
		end
		
		-- Only consider this candidate if we don't have a locked direction for this spell
		-- This prevents evaluating other directions when we should maintain the locked one
		local shouldConsiderCandidate = true
		if useWASD and spell and spell.name then
			local spellId = spell.name
			if spell.position then
				local posHash = math.floor((spell.position.x + spell.position.y) / 100)
				spellId = spellId .. "_" .. tostring(posHash)
			end
			if self._lockedWASDSpell == spellId and self._currentWASDDirection then
				-- We have a locked direction for this spell - only consider candidates if they match
				if not candData.wasdDir or candData.wasdDir.dir ~= self._currentWASDDirection.dir then
					shouldConsiderCandidate = false -- Skip this candidate, we're maintaining locked direction
				end
			end
		end
		
		if shouldConsiderCandidate and (score < bestScore or (math.abs(score - bestScore) < 1e-6 and distToPath > bestDistPath)) then
			bestScore = score; bestDistPath = distToPath; best = cand
			-- Store WASD direction info if using WASD mode
			if useWASD and candData.wasdDir then
				bestWASDDir = candData.wasdDir
			end
		end
	end
	
	-- Store best WASD direction for debug visualization
	if useWASD then
		local now = GameTimer()
		local shouldChangeDirection = true
		local spellIdentifier = nil
		
		-- Create unique identifier for the spell we're dodging
		if spell and spell.name then
			-- Use spell name as identifier (most spells have unique names)
			-- For spells with same name, we can add position or time to differentiate
			spellIdentifier = spell.name
			if spell.position then
				-- Add rough position to handle multiple instances of same spell
				local posHash = math.floor((spell.position.x + spell.position.y) / 100)
				spellIdentifier = spellIdentifier .. "_" .. tostring(posHash)
			end
		end
		
		-- HISTÉRESIS MEJORADA: En lugar de mantener la dirección bloqueada a toda costa,
		-- permitir cambio si la nueva dirección es SIGNIFICATIVAMENTE mejor
		if self._currentWASDDirection and spellIdentifier and self._lockedWASDSpell == spellIdentifier then
			local currentDirCandidate = nil
			local currentDirScore = math.huge
			
			-- Encontrar el candidato de la dirección actual
			for _, candData in ipairs(allCandidates) do
				if candData.wasdDir and candData.wasdDir.dir == self._currentWASDDirection.dir then
					currentDirCandidate = candData
					break
				end
			end
			
			if currentDirCandidate then
				-- Si la dirección actual está en muro o dentro del hechizo, cambiar inmediatamente
				if currentDirCandidate.rejected then
					shouldChangeDirection = true
					self._lockedWASDSpell = nil -- Clear lock since direction is rejected
				else
					-- Comparar scores: solo mantener si la diferencia es pequeña
					local scoreDiff = bestScore - currentDirCandidate.safetyScore
					
					if scoreDiff > 100 then  -- La nueva es MUCHO mejor
						shouldChangeDirection = true
					elseif currentDirCandidate.safetyScore >= 0 then  -- Actual es segura
						shouldChangeDirection = false
						bestWASDDir = self._currentWASDDirection
				best = currentDirCandidate.pos
						bestDistPath = currentDirCandidate.distToPath or 0
						-- Recalcular score para display
						bestScore = currentDirCandidate.safetyScore
					else
						shouldChangeDirection = true
					end
				end
			else
				shouldChangeDirection = true
			end
		elseif self._currentWASDDirection and spellIdentifier and self._lockedWASDSpell ~= spellIdentifier then
			-- Different spell - allow direction change and lock to new spell
			shouldChangeDirection = true
		elseif not self._currentWASDDirection or not self._lockedWASDSpell then
			-- No locked direction yet - allow selection and lock it
			shouldChangeDirection = true
		end
		
		-- Update current direction if we're changing
		if shouldChangeDirection and bestWASDDir then
			if not self._currentWASDDirection or self._currentWASDDirection.dir ~= bestWASDDir.dir then
				self._currentWASDDirection = bestWASDDir
				self._lastWASDChangeTime = now
				-- Lock direction to this spell
				if spellIdentifier then
					self._lockedWASDSpell = spellIdentifier
					self._lockedWASDSpellTime = now
				end
			elseif spellIdentifier and self._lockedWASDSpell ~= spellIdentifier then
				-- Same direction but different spell - update lock
				self._lockedWASDSpell = spellIdentifier
				self._lockedWASDSpellTime = now
			end
		end
		
		self._bestWASDDirection = bestWASDDir
		
		-- Debug logging for WASD selection
		if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.WASDLog and self.JEMenu.Main.WASDLog:Value() then
			if bestWASDDir then
				local changeInfo = shouldChangeDirection and "CHANGED" or "MAINTAINED"
				local spellInfo = spellIdentifier and (" [" .. (spell.name or "unknown") .. "]") or ""
				print(string.format("[WASD Evade] %s direction: %s, Score: %.2f, DistToPath: %.1f%s", 
					changeInfo, bestWASDDir.dir, bestScore, bestDistPath, spellInfo))
			else
				print("[WASD Evade] No valid direction found!")
			end
		end
	else
		self._bestWASDDirection = nil
		self._currentWASDDirection = nil
		self._lockedWASDSpell = nil
	end
	
	return best, bestScore
end

function DEvade:AddSpell(p1, p2, sP, eP, data, speed, range, delay, radius, name)
	-- Memory optimization: limit spell tracking to prevent memory leaks
	if #self.DetectedSpells >= self._maxDetectedSpells then
		TableRemove(self.DetectedSpells, 1)
	end
	
	TableInsert(self.DetectedSpells, {
		path = p1, path2 = p2, position = sP, startPos = sP, endPos = eP, speed = speed, range = range,
		delay = delay, radius = radius, radius2 = data.radius2, angle = data.angle, name = name,
		startTime = GameTimer() - self.JEMenu.Core.GP:Value() / 2000, type = data.type,
		danger = self:SpellMenuValue(name, "Danger"..name, data.danger or 1), cc = data.cc,
		collision = data.collision, windwall = data.windwall, y = data.y,
		_collisionChecked = false, _lastUpdateTime = nil
	})
end

function DEvade:CopyTable(tab)
	local copy = {}
	for key, val in pairs(tab) do copy[key] = val end
	return copy
end

function DEvade:CreateMissile(func)
	TableInsert(self.OnCreateMisCBs, func)
end

function DEvade:GetDodgeableSpells()
	local result, skipped = {}, {}
	local threshold = self.JEMenu.Main.dangerLevelToEvade:Value()
	local dodgeEnabled = self.JEMenu.Main.Dodge:Value()
	local healthPercent = self:GetHealthPercent()
	local detectedCount = #self.DetectedSpells
	
	-- Cache DoD flag to avoid repeated table lookups
	local isDoDMode = self.DoD
	
	for i = detectedCount, 1, -1 do
		local s = self.DetectedSpells[i]
		self:SpellManager(i, s)
		
		if dodgeEnabled then
			local okMenu = self:SpellMenuValue(s.name, "Dodge"..s.name, true)
			if okMenu then
				local hpOk = healthPercent <= self:SpellMenuValue(s.name, "HP"..s.name, 100)
				if hpOk then
					local passes = s.danger >= threshold and (isDoDMode and s.danger >= 4 or not isDoDMode)
					if passes then
						-- Always try to dodge - system will handle it if no escape route exists
						TableInsert(result, s)
					else 
						TableInsert(skipped, s) 
					end
				end
			end
		end
	end
	
	-- Store skipped for draw-only usage
	self._lowDangerSpells = skipped
	return result
end

function DEvade:GetHealthPercent()
	return myHero.health / myHero.maxHealth * 100
end

-- Kept for compatibility but not used - always try to dodge
function DEvade:IsSpellAvoidable(spell)
	-- Always return true - let CoreManager handle the dodge attempt
	return true
end

function DEvade:GetMovementSpeed(extra, evadeSpell)
	local moveSpeed = myHero.ms or 315
	if not extra then return moveSpeed end; if not evadeSpell then return 9999 end
	local lvl, name = myHero:GetSpellData(evadeSpell.slot).level or 1, evadeSpell.name
	if lvl == nil or lvl == 0 then return moveSpeed end
	if name == "AnnieE-" then return (1.20 + 0.30 / 17 * (myHero.levelData.lvl - 1)) * moveSpeed
	elseif name == "AkaliW-" then return ({1.30, 1.35, 1.40, 1.45, 1.50})[lvl] * moveSpeed
	elseif name == "AhriW-" then return 1.40 * moveSpeed
	elseif name == "BlitzcrankW-" then return ({1.7, 1.75, 1.80, 1.85, 1.90})[lvl] * moveSpeed
	elseif name == "DravenW-" then return ({1.5, 1.55, 1.60, 1.65, 1.70})[lvl] * moveSpeed
	elseif name == "GarenQ-" then return 1.35 * moveSpeed
	elseif name == "KaisaE-" then return ({1.55, 1.60, 1.65, 1.70, 1.75})[lvl] * moveSpeed  -- need myHero.bonusattackSpeed for +1% per 1% Bonus attack speed
	elseif name == "KayleW-" then return ({1.24, 1.28, 1.32, 1.36, 1.40})[lvl] + (0.08 * MathFloor(myHero.ap / 100)) * moveSpeed
	elseif name == "KatarinaW-" then return ({1.50, 1.60, 1.70, 1.80, 1.90})[lvl] * moveSpeed
	elseif name == "KennenE-" then return 2 * moveSpeed
	elseif name == "RumbleW-" then return ({1.10, 1.15, 1.20, 1.25, 1.30})[lvl] * moveSpeed
	elseif name == "ShyvanaW-" then return ({1.30, 1.35, 1.40, 1.45, 1.50})[lvl] + (0.08 * MathFloor(myHero.ap / 100)) * moveSpeed -- +8% per 100 AP
	elseif name == "SkarnerW-" then return ({1.08, 1.10, 1.12, 1.14, 1.16})[lvl] * moveSpeed
	elseif name == "SonaE-" then return 1.20 + (0.02 * MathFloor(myHero.ap / 100)) * moveSpeed  -- Aura bonus to allies would be ({1.1, 1.11, 1.12, 1.13, 1.14})[lvl] + (0.02 * MathFloor(myHero.ap / 100)) * moveSpeed
	elseif name == "TeemoW-" then return ({1.20, 1.28, 1.26, 1.44, 1.52})[lvl] * moveSpeed
	elseif name == "UdyrE-" then return ({1.15, 1.20, 1.25, 1.30, 1.35, 1.40})[lvl] * moveSpeed
	elseif name == "VolibearQ-" then return ({1.10, 1.14, 1.18, 1.22, 1.26})[lvl] * moveSpeed end
	return moveSpeed
end

-- Safe spell menu value accessor (handles missing allied spell menus in Arena)
function DEvade:SpellMenuValue(spellName, menuId, default)
	local ok, val
	if not self.JEMenu or not self.JEMenu.Spells then return default end
	local spellMenu = self.JEMenu.Spells[spellName]
	if spellMenu and spellMenu[menuId] then
		ok, val = pcall(function() return spellMenu[menuId]:Value() end)
		if ok and val ~= nil then return val end
	end
	return default
end

-- Arena detection helper
function DEvade:IsArena()
	local forced = self:GetForcedMapType()
	if forced == "arena" then return true end
	if self.JEMenu and self.JEMenu.Main.forceArena and self.JEMenu.Main.forceArena:Value() then return true end -- legacy toggle
	if _detectedMapType == "arena" or _G.MapType == "arena" then return true end
	return false
end

function DEvade:GetForcedMapType()
	if not (self.JEMenu and self.JEMenu.Main.forceMapType) then return nil end
	local idx = self.JEMenu.Main.forceMapType:Value()
	if idx == 2 then return "summoners_rift" end
	if idx == 3 then return "howling_abyss" end
	if idx == 4 then return "arena" end
	return nil
end

-- Expand enemy list to include allies (except myHero) in Arena once
function DEvade:ExpandArenaUnits()
	if self._arenaExpanded then return end
	for i = 1, GameHeroCount() do
		local u = GameHero(i)
		if u and u.valid and not u.dead and u ~= myHero then
			local already = false
			for _, entry in ipairs(self.Enemies) do if entry.unit == u then already = true break end end
			if not already then TableInsert(self.Enemies, {unit = u, spell = nil, missile = nil}) end
		end
	end
	TableSort(self.Enemies, function(a,b) return a.unit.charName < b.unit.charName end)
	self._arenaExpanded = true
end

function DEvade:HasBuff(buffName)
	for i = 0, myHero.buffCount do
	local buff = myHero:GetBuff(i)
	if buff.name == buffName and buff.count > 0 then return true end
	end
	return false
end

function DEvade:ImpossibleDodge(func)
	TableInsert(self.OnImpDodgeCBs, func)
end

function DEvade:IsMoving()
	return myHero.pos.x - MathFloor(myHero.pos.x) ~= 0
end

function DEvade:IsReady(spell)
	return GameCanUseSpell(spell) == 0
end

-- Helper function to check if WASD mode is enabled
function DEvade:IsWASDMode()
	return self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.UseWASD and self.JEMenu.Main.UseWASD:Value()
end

-- Move using WASD keys (for League of Legends WASD movement mode)
-- Uses only the 8 discrete WASD directions (4 cardinal + 4 diagonal)
function DEvade:MoveToPosWASD(pos)
	-- Validate pos before proceeding
	if not pos or (type(pos) ~= "table") or (not pos.x or not pos.y) then
		return false
	end
	
	-- Ensure pos is a Point2D
	local pos2D = Point2D(pos)
	if not pos2D or not pos2D.x or not pos2D.y then
		return false
	end
	
	-- Throttle WASD movement updates
	local now = GameTimer()
	if self._lastWASDMoveTime and (now - self._lastWASDMoveTime) < self._wasdMoveThrottle then
		return false
	end
	
	-- Calculate direction from current position to target
	local myPos = Point2D(self.MyHeroPos)
	local dir = Point2D(pos2D - myPos)
	local dist = self:Magnitude(dir)
	
	-- If too close, release all keys and return
	if dist < 50 then
		self:ReleaseAllWASDKeys()
		return false
	end
	
	-- Use the best WASD direction if available (from GetBestDodgePosition)
	-- This ensures we only use the 8 discrete directions
	local shouldPressW, shouldPressS, shouldPressA, shouldPressD = false, false, false, false
	
	if self._bestWASDDirection and self._bestWASDDirection.keys then
		-- Use the selected WASD direction keys
		shouldPressW = self._bestWASDDirection.keys.W == true
		shouldPressS = self._bestWASDDirection.keys.S == true
		shouldPressA = self._bestWASDDirection.keys.A == true
		shouldPressD = self._bestWASDDirection.keys.D == true
	else
		-- Fallback: calculate direction and snap to nearest WASD direction
		dir = dir:Normalized()

		-- En League of Legends:
		-- - X positivo = Este (D), X negativo = Oeste (A)
		-- - Y/Z positivo = Norte (W), Y/Z negativo = Sur (S)
		-- NOTA: En el sistema 2D del script, Y representa la coordenada Z del mundo
		local threshold = 0.3

		-- Determinar qué teclas presionar (sin inversión de Y)
		shouldPressW = dir.y > threshold   -- Norte = Y positivo
		shouldPressS = dir.y < -threshold  -- Sur = Y negativo
		shouldPressA = dir.x < -threshold  -- Oeste = X negativo
		shouldPressD = dir.x > threshold   -- Este = X positivo
	end
	
	-- Release keys that shouldn't be pressed
	if not shouldPressW and self._wasdKeysPressed.W then
		pcall(function() ControlKeyUp(KEY_W) end)
		self._wasdKeysPressed.W = false
		self._wasdKeyPressTime.W = now  -- AGREGAR ESTA LÍNEA

	end
	if not shouldPressS and self._wasdKeysPressed.S then
		pcall(function() ControlKeyUp(KEY_S) end)
		self._wasdKeysPressed.S = false
		self._wasdKeyPressTime.S = now  -- AGREGAR ESTA LÍNEA
	end
	if not shouldPressA and self._wasdKeysPressed.A then
		pcall(function() ControlKeyUp(KEY_A) end)
		self._wasdKeysPressed.A = false
		self._wasdKeyPressTime.A = now  -- AGREGAR ESTA LÍNEA
	end
	if not shouldPressD and self._wasdKeysPressed.D then
		pcall(function() ControlKeyUp(KEY_D) end)
		self._wasdKeysPressed.D = false
		self._wasdKeyPressTime.D = now  -- AGREGAR ESTA LÍNEA
	end
	
	-- Press keys that should be pressed
	if shouldPressW and not self._wasdKeysPressed.W then
		pcall(function() ControlKeyDown(KEY_W) end)
		self._wasdKeysPressed.W = true
		self._wasdKeyPressTime.W = now  -- AGREGAR ESTA LÍNEA
	end
	if shouldPressS and not self._wasdKeysPressed.S then
		pcall(function() ControlKeyDown(KEY_S) end)
		self._wasdKeysPressed.S = true
		self._wasdKeyPressTime.S = now  -- AGREGAR ESTA LÍNEA
	end
	if shouldPressA and not self._wasdKeysPressed.A then
		pcall(function() ControlKeyDown(KEY_A) end)
		self._wasdKeysPressed.A = true
		self._wasdKeyPressTime.A = now  -- AGREGAR ESTA LÍNEA
	end
	if shouldPressD and not self._wasdKeysPressed.D then
		pcall(function() ControlKeyDown(KEY_D) end)
		self._wasdKeysPressed.D = true
		self._wasdKeyPressTime.D = now  -- AGREGAR ESTA LÍNEA
	end
	
	self._lastWASDMoveTime = now
	self._lastMovePos = { x = pos2D.x, y = pos2D.y }
	self._lastMoveTime = now
	
	if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
		local keys = {}
		if shouldPressW then TableInsert(keys, "W") end
		if shouldPressA then TableInsert(keys, "A") end
		if shouldPressS then TableInsert(keys, "S") end
		if shouldPressD then TableInsert(keys, "D") end
		print(string.format("[Depressive Evade] WASD Move to (%.1f, %.1f) - Keys: %s", pos2D.x, pos2D.y, table.concat(keys, "+")))
	end
	
	return true
end

function DEvade:ReleaseAllWASDKeys()
    if self._wasdKeysPressed.W then
        pcall(function() ControlKeyUp(KEY_W) end)
        self._wasdKeysPressed.W = false
    end
    if self._wasdKeysPressed.A then
        pcall(function() ControlKeyUp(KEY_A) end)
        self._wasdKeysPressed.A = false
    end
    if self._wasdKeysPressed.S then
        pcall(function() ControlKeyUp(KEY_S) end)
        self._wasdKeysPressed.S = false
    end
    if self._wasdKeysPressed.D then
        pcall(function() ControlKeyUp(KEY_D) end)
        self._wasdKeysPressed.D = false
    end
    
    -- AGREGAR: Limpiar timestamps
    if self._wasdKeyPressTime then
        self._wasdKeyPressTime = {W = nil, A = nil, S = nil, D = nil}
    end
    
    -- AGREGAR: Limpiar dirección actual para evitar problemas en el siguiente evade
    self._currentWASDDirection = nil
    self._bestWASDDirection = nil
end

-- Verificar timeout de teclas WASD para evitar teclas atascadas
function DEvade:CheckWASDKeyTimeout()
    local now = GameTimer()
    local keys = {
        {name = "W", key = KEY_W},
        {name = "A", key = KEY_A},
        {name = "S", key = KEY_S},
        {name = "D", key = KEY_D}
    }
    
    for _, k in ipairs(keys) do
        if self._wasdKeysPressed[k.name] and self._wasdKeyPressTime[k.name] then
            if (now - self._wasdKeyPressTime[k.name]) > self._wasdKeyTimeout then
                -- Tecla presionada demasiado tiempo - liberar
                pcall(function() ControlKeyUp(k.key) end)
                self._wasdKeysPressed[k.name] = false
                self._wasdKeyPressTime[k.name] = nil
                
                if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.WASDLog and self.JEMenu.Main.WASDLog:Value() then
                    print(string.format("[WASD Evade] TIMEOUT: Released %s key (stuck)", k.name))
                end
            end
        end
    end
end

function DEvade:MoveToPos(pos)
	-- Validate pos before proceeding - ensure it's a valid 2D position
	if not pos or (type(pos) ~= "table") or (not pos.x or not pos.y) then
		return false
	end
	
	-- Ensure pos is a Point2D
	local pos2D = Point2D(pos)
	if not pos2D or not pos2D.x or not pos2D.y then
		return false
	end
	
	-- THROTTLING: Same as DepressiveEvade3.lua - evitar spam de comandos de movimiento
	local now = GameTimer()
	if self._lastMoveTime and (now - self._lastMoveTime) < self._moveThrottle then
		return false
	end
	
	-- Check if target is too close to last move position (evitar micro-movimientos) - igual que DepressiveEvade3.lua
	if self._lastMovePos then
		local dx = pos2D.x - self._lastMovePos.x
		local dy = pos2D.y - self._lastMovePos.y
		local distSq = dx * dx + dy * dy
		if distSq < 100 then -- Si está a menos de 10 unidades, no mover
			return false
		end
	end
	
	-- During evasion: always move (constant movement)
	-- Outside evasion: avoid unnecessary move commands
	if not self.Evading then
		if self._lastMovePos and self:DistanceSquared(self._lastMovePos, pos2D) < 2500 then
			return false
		end
		
		-- Reject move commands that point toward missile vectors or through their paths
		if self:ShouldRejectMove(pos2D) then
			-- Prefer moving laterally along locked evade direction if available
			if self._evadeDir then
				local lateral = Point2D(self.MyHeroPos):Extended(Point2D(self.MyHeroPos + self._evadeDir * 800), self.BoundingRadius * 2)
				pos2D = lateral
			else
				-- Derive a lateral direction from the nearest missile
				local s = self.DodgeableSpells[1]
				if s then
					local perp = self:PerpFromMissile(s)
					local lateral = Point2D(self.MyHeroPos):Extended(Point2D(self.MyHeroPos + perp * 800), self.BoundingRadius * 2)
					pos2D = lateral
					self._evadeDir = perp
					if _G.DepressiveEvade then _G.DepressiveEvade._lastEvadeDirection = self._evadeDir end
				end
			end
		end
	end
	
	-- Check if WASD movement is enabled
	-- CRITICAL: In WASD mode, NEVER use mouse - only use WASD keys
	if self:IsWASDMode() then
		-- Use WASD movement ONLY - never use mouse in WASD mode
		-- Don't fall through to mouse methods even if WASD fails
		return self:MoveToPosWASD(pos2D)
	end
	
	-- Convert 2D target to 3D ONLY for movement command
	local target3D = Vector(pos2D.x, myHero.pos.y, pos2D.y)
	
	-- ============================================
	-- MÉTODO 1: SDK Control.Evade (COMENTADO - NO FUNCIONA)
	-- ============================================
	--[[
	if _G.SDK and _G.Control and _G.Control.Evade then
		local ok = pcall(function() _G.Control.Evade(target3D) end)
		if ok then
			self._lastMovePos = { x = pos2D.x, y = pos2D.y }
			self._lastMoveTime = now
			if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
				print(string.format("[Depressive Evade] Moved to (%.1f, %.1f) using SDK Control.Evade", pos2D.x, pos2D.y))
			end
			return true
		end
	end
	--]]
	
	-- CRITICAL: Never use mouse if WASD mode is enabled
	if self:IsWASDMode() then
		return false
	end
	
	-- Project to screen (necesario para métodos 2 y 4)
	local screenPos
	if Renderer and Renderer.WorldToScreen then
		screenPos = Renderer.WorldToScreen(target3D)
	else
		-- fallback: use Vector(...):To2D which is often available as a projection
		local fix = target3D:To2D()
		if fix and fix.x and fix.y then
			screenPos = { x = fix.x, y = fix.y }
		end
	end
	
	-- ============================================
	-- MÉTODO 2: Control.RightClick (ACTIVO - MÉTODO FINAL)
	-- ============================================
	-- CRITICAL: Never use mouse if WASD mode is enabled
	if not self:IsWASDMode() and Control and Control.RightClick and screenPos and screenPos.x and screenPos.y then
		-- Primero mover el cursor a la posición en pantalla
		local ok1, err1 = pcall(function() 
			Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
		end)
		if ok1 then
			-- Luego hacer click derecho directamente con las coordenadas de pantalla
			local ok2, err2 = pcall(function() 
				Control.RightClick(MathFloor(screenPos.x), MathFloor(screenPos.y))
			end)
			if ok2 then
				self._lastMovePos = { x = pos2D.x, y = pos2D.y }
				self._lastMoveTime = now
				if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
					print(string.format("[Depressive Evade] Moved to (%.1f, %.1f) using Control.RightClick", pos2D.x, pos2D.y))
				end
				return true
			else
				-- Si RightClick falla, intentar con Vector2
				if screenPos.x and screenPos.y then
					local ok3 = pcall(function() 
						Control.RightClick({x = MathFloor(screenPos.x), y = MathFloor(screenPos.y)})
					end)
					if ok3 then
						self._lastMovePos = { x = pos2D.x, y = pos2D.y }
						self._lastMoveTime = now
						if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
							print(string.format("[Depressive Evade] Moved to (%.1f, %.1f) using Control.RightClick(Vector2)", pos2D.x, pos2D.y))
						end
						return true
					end
				end
			end
		end
	end
	
	-- ============================================
	-- MÉTODO 3: Cursor:Add + ExecuteAction (COMENTADO - DESCOMENTA PARA PROBAR)
	-- ============================================
	--[[
	if Cursor and Cursor.Add then
		local castPos = { x = target3D.x, y = target3D.y, z = target3D.z }
		-- IMPORTANTE: Solo agregar RIGHTDOWN, NO RIGHTUP (igual que DepressiveEvade3.lua)
		Cursor:Add(MOUSEEVENTF_RIGHTDOWN, castPos)
		if Cursor.ExecuteAction then
			local ok = pcall(function() Cursor:ExecuteAction() end)
			if ok then
				self._lastMovePos = { x = pos2D.x, y = pos2D.y }
				self._lastMoveTime = now
				if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
					print(string.format("[Depressive Evade] Moved to (%.1f, %.1f) using Cursor:Add + ExecuteAction", pos2D.x, pos2D.y))
				end
				return true
			end
		else
			-- Fallback: drive Cursor state machine directly
			if Cursor.StepSetToCastPos then pcall(function() Cursor:StepSetToCastPos() end) end
			if Cursor.StepPressKey then pcall(function() Cursor:StepPressKey() end) end
			self._lastMovePos = { x = pos2D.x, y = pos2D.y }
			self._lastMoveTime = now
			if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
				print(string.format("[Depressive Evade] Moved to (%.1f, %.1f) using Cursor state machine", pos2D.x, pos2D.y))
			end
			return true
		end
	end
	--]]
	
	-- ============================================
	-- MÉTODO 4: SetCursorPos + mouse_event (COMENTADO - DESCOMENTA PARA PROBAR)
	-- ============================================
	--[[
	if screenPos and screenPos.x and screenPos.y then
		ControlSetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
		ControlMouseEvent(MOUSEEVENTF_RIGHTDOWN)
		ControlMouseEvent(MOUSEEVENTF_RIGHTUP)
		if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.DoubleClick and self.JEMenu.Main.DoubleClick:Value() then
			ControlMouseEvent(MOUSEEVENTF_RIGHTDOWN)
			ControlMouseEvent(MOUSEEVENTF_RIGHTUP)
		end
		self._lastMovePos = { x = pos2D.x, y = pos2D.y }
		self._lastMoveTime = now
		if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
			print(string.format("[Depressive Evade] Moved to (%.1f, %.1f) using SetCursorPos + mouse_event", pos2D.x, pos2D.y))
		end
		return true
	end
	--]]
	
	return false
end

-- Decide if a requested move would head into a missile or cross its vector
function DEvade:ShouldRejectMove(pos)
	if not pos then return false end
	local dirToPos = Point2D(pos - self.MyHeroPos)
	local magnitude = self:Magnitude(dirToPos)
	if magnitude == 0 then return false end
	dirToPos = dirToPos:Normalized()
	
	-- If we have a locked evade direction and the move aligns with it, don't reject
	if self._evadeDir and self:DotProduct(dirToPos, self._evadeDir) > 0.7 then
		return false
	end
	
	local dodgeableCount = #self.DodgeableSpells
	for i = 1, dodgeableCount do
		local s = self.DodgeableSpells[i]
		if not s then goto continue end -- Defensive check: ensure spell is not nil
		local sdir = self:MissileDir(s)
		
		-- Heading approximately toward the missile vector?
		if self:DotProduct(dirToPos, sdir) > 0.5 then return true end
		
		-- Does our segment cross the missile segment?
		local cross = self:LineSegmentIntersection(self.MyHeroPos, Point2D(pos), s.position, s.endPos)
		if cross ~= nil then return true end
		
		-- Would our path re-enter the spell polygon?
		if self:IsPointInPolygon(s.path, Point2D(pos)) then return true end
		::continue::
	end
	return false
end

-- Get missile direction (normalized) for a dodgeable spell
function DEvade:MissileDir(s)
	local d = Point2D(s.endPos - s.position)
	if self:Magnitude(d) == 0 then return Point2D(1, 0) end
	return d:Normalized()
end

-- Choose a perpendicular direction away from the missile path
function DEvade:PerpFromMissile(s)
	local d = self:MissileDir(s)
	local p = d:Perpendicular():Normalized()
	local cand1 = Point2D(self.MyHeroPos) + p * (self.BoundingRadius + 120)
	local cand2 = Point2D(self.MyHeroPos) - p * (self.BoundingRadius + 120)
	local ok1 = self:IsSafePos(cand1, nil) and not MapPosition:inWall(self:To3D(cand1))
	local ok2 = self:IsSafePos(cand2, nil) and not MapPosition:inWall(self:To3D(cand2))
	if ok1 and not ok2 then return p end
	if ok2 and not ok1 then return p * -1 end
	-- If both valid, prefer matching previously locked direction if any
	if self._evadeDir and self:DotProduct(self._evadeDir, p) > 0 then return p end
	return ok1 and p or (ok2 and (p * -1) or p)
end

function DEvade:ProcessSpell(func)
	TableInsert(self.OnProcSpellCBs, func)
end

function DEvade:SpellExistsThenRemove(name)
	for i = #self.DetectedSpells, 1, -1 do
		local s = self.DetectedSpells[i]
		if name == s.name then TableRemove(self.DetectedSpells, i); return end
	end
end

-- Public/internal: reset a specific threat so it can be detected again later
function DEvade:ResetThreat(spell)
	if type(spell) == "table" and spell.name then
		self:SpellExistsThenRemove(spell.name)
	elseif type(spell) == "string" then
		self:SpellExistsThenRemove(spell)
	end
end

function DEvade:ValidTarget(target, range)
	local range = range or MathHuge
	return target and target.valid and target.visible and not target.dead and
		self:DistanceSquared(self.MyHeroPos, self:To2D(target.pos)) <= range * range
end

-- Reset all internal evade state
function DEvade:ResetEvadeState()
	self.Evading, self.SafePos, self.ExtendedPos = false, nil, nil
	self.ResumePos, self._evadeDir = nil, nil
	self._mousePosOrig, self._mouseDirOrig = nil, nil
	self._collisionDetected, self._blockingMinion = false, nil
	self._currentThreat = nil
	-- Clear movement tracking to prevent returning to old positions
	self._lastMovePos = nil
	self._lastDodgeTarget = nil
	-- Reset WASD direction tracking when evading stops
	self._currentWASDDirection = nil
	self._lastWASDChangeTime = 0
	self._lockedWASDSpell = nil
	self._lockedWASDSpellTime = 0
	-- Release all WASD keys when evading stops
	if self:IsWASDMode() then
		self:ReleaseAllWASDKeys()
	end
	if _G.DepressiveEvade then
		_G.DepressiveEvade._lastEvadeDirection = nil
		_G.DepressiveEvade._collisionDetected = false
		_G.DepressiveEvade._currentThreat = nil
	end
end

--[[
	┌─┐┬  ┬┌─┐┌┬┐┌─┐
	├┤ └┐┌┘├─┤ ││├┤ 
	└─┘ └┘ ┴ ┴─┴┘└─┘
--]]

function DEvade:LoadEvadeSpells()
	if myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" then self.Flash, self.Flash2, self.FlashRange = HK_SUMMONER_1, SUMMONER_1, myHero:GetSpellData(SUMMONER_1).range
	elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" then self.Flash, self.Flash2, self.FlashRange = HK_SUMMONER_2, SUMMONER_2, myHero:GetSpellData(SUMMONER_2).range end

	for i = 0, 3 do
		local eS = EvadeSpells[myHero.charName]
		if eS and eS[i] then TableInsert(self.EvadeSpellData, {name = eS[i].name, slot = eS[i].slot, slot2 = eS[i].slot2, range = eS[i].range, type = eS[i].type}) end
	end
end

function DEvade:Tick()
	if self:IsWASDMode() then
		self:CheckWASDKeyTimeout()
	end
	if not self.JEMenu.Main.Evade:Value() or GameTimer() < 5 then return end
	self.DoD = self.JEMenu.Main.DD:Value() == true
	self.BoundingRadius = myHero.boundingRadius or 65
	self.MyHeroPos, self.MousePos = self:To2D(myHero.pos), self:To2D(mousePos)
	if myHero.dead then 
		-- Release WASD keys when hero is dead
		if self:IsWASDMode() then
			self:ReleaseAllWASDKeys()
		end
		return 
	end
	
	-- Arena unit expansion (include allies) so we process all spells in Arena
	if self:IsArena() then self:ExpandArenaUnits() end
	
	-- Cache enemy count for optimization
	local enemyCount = #self.Enemies
	
	-- Process spells - with early return optimization
	for i = 1, enemyCount do
		local enemyData = self.Enemies[i]
		local unit = enemyData.unit
		if unit and unit.valid and not unit.dead then
			local active = unit.activeSpell
			if active and active.valid and enemyData.spell ~= active.name .. active.endTime and active.isChanneling then
				enemyData.spell = active.name .. active.endTime
				self:OnProcessSpell(unit, active)
				-- Early exit for callbacks if many
				local cbCount = #self.OnProcSpellCBs
				if cbCount > 0 then
					for j = 1, cbCount do
						self.OnProcSpellCBs[j](unit, active)
					end
				end
			end
		end
	end
	
	-- Missile detection - optimized with early exit
	if self.JEMenu.Main.Missile:Value() then
		local missileCount = GameMissileCount()
		if missileCount > 0 then
			for i = 1, missileCount do
				local mis = GameMissile(i)
				if mis then
					local data = mis.missileData
					local owner = data.owner
					-- Find owner unit
					for j = 1, enemyCount do
						local unit = self.Enemies[j].unit
						if unit.handle == owner then
							local id = tonumber(mis.networkID)
							if self.MissileID < id then
								self.MissileID = id
								self:OnCreateMissile(unit, data)
								local cbCount = #self.OnCreateMisCBs
								if cbCount > 0 then
									for k = 1, cbCount do
										self.OnCreateMisCBs[k](unit, data)
									end
								end
							end
							break
						end
					end
				end
			end
		end
	end
	
	-- Main evade logic
	local dodgeableCount = #self.DodgeableSpells
	if dodgeableCount > 0 then
		-- AGGRESSIVE: Execute DodgeSpell IMMEDIATELY when spells are detected (not waiting for Evading flag)
		-- This makes the evade react as soon as a spell is detected
		self:DodgeSpell()
		
		-- Pre-check: try dash on first dangerous spell if we have evade spells
		if not self.Evading and self.EvadeSpellData and #self.EvadeSpellData > 0 then
			-- Check if first spell is in danger radius
			local firstSpell = self.DodgeableSpells[1]
			if firstSpell and self:IsPointInPolygon(firstSpell.path, self.MyHeroPos) then
				-- We're in danger! Try to use dash immediately
				self:TryUseDashSpell(firstSpell)
			end
		end
		
		local result = 0
		for i = 1, dodgeableCount do
			local spell = self.DodgeableSpells[i]
			if spell then -- Defensive check: ensure spell is not nil
				result = result + self:CoreManager(spell)
			end
		end
		
		-- Intersection prediction - only if not already evading
		local movePath = not self.Evading and self:GetMovePath() or nil
		if movePath then
			local ints = {}
			for i = 1, dodgeableCount do
				local s = self.DodgeableSpells[i]
				if s and s.path then -- Defensive check: ensure spell is not nil
					local poly = s.path
					if not self:IsPointInPolygon(poly, self.MyHeroPos) then
						local findInts = self:FindIntersections(poly, self.MyHeroPos, movePath)
						local intCount = #findInts
						if intCount > 0 then
							for j = 1, intCount do
								TableInsert(ints, findInts[j])
							end
						end
					end
				end
			end
			
			if #ints > 0 then
				TableSort(ints, function(a, b) return
					self:DistanceSquared(self.MyHeroPos, a) <
					self:DistanceSquared(self.MyHeroPos, b) end)
				local movePos = self:PrependVector(self.MyHeroPos,
					ints[1], self.BoundingRadius / 2)
				self:MoveToPos(movePos)
			end
		end
		
		if result == 0 then
			-- finished evading; resume original movement if stored
			if self.Evading and self.ResumePos then
				self:MoveToPos(self.ResumePos)
			end
			self:ResetEvadeState()
		end
	else
		if self.JEMenu.Main.Debug:Value() then self.Debug = {} end
		-- no dodgeable spells; if we were evading, resume once
		if self.Evading and self.ResumePos then
			self:MoveToPos(self.ResumePos)
		end
		self:ResetEvadeState()
		-- Release WASD keys when no spells to dodge
		if self:IsWASDMode() then
			self:ReleaseAllWASDKeys()
		end
	end
	
	if _G.GOS then
		_G.GOS.BlockAttack = self.Evading
		_G.GOS.BlockMovement = self.Evading
	end
end

function DEvade:CoreManager(s)
	if not s then return 0 end -- Defensive check: ensure spell is not nil
	if self:IsPointInPolygon(s.path, self.MyHeroPos) then
		if self.OldTimer ~= self.NewTimer then
			local evadeSpells = self.EvadeSpellData
			-- Safely check Flash availability
			local flashUsage = false
			if self.Flash2 and self.Flash then
				flashUsage = self.JEMenu.Spells.Flash and self.JEMenu.Spells.Flash.US and self.JEMenu.Spells.Flash.US:Value()
					and self:IsReady(self.Flash2) and self.JEMenu.Spells.Flash.Danger and s.danger >= self.JEMenu.Spells.Flash.Danger:Value()
			end
			-- Direction lock: prefer lateral movement perpendicular to current missile
			local safePos = nil
			-- Track current threat only if passes danger threshold
			local threshold = self.JEMenu.Main.dangerLevelToEvade:Value()
			if s.danger >= threshold then
				self._currentThreat = s.name
			else
				self._currentThreat = nil
			end
					-- Collision shield detection - optimized with early exit and minion cache
			self._collisionDetected, self._blockingMinion, self._blockingSpellName = false, nil, nil
			if s.collision and not s._collisionChecked then
				local bestMinion, bestDist = nil, MathHuge
				local rangeLimit = self.JEMenu.Main.collisionRange:Value()
				local rangeLimitSqr = rangeLimit * rangeLimit
				local startP, endP = s.startPos, s.endPos
				local minionCount = GameMinionCount()
				
				-- Early exit if no minions
				if minionCount > 0 then
					for i = 1, minionCount do
						local m = GameMinion(i)
						if m and m.valid and not m.dead and m.team == myHero.team then
							local m2d = self:To2D(m.pos)
							local distHero = self:DistanceSquared(self.MyHeroPos, m2d)
							
							if distHero <= rangeLimitSqr then
								local blocks = false
								-- Prefer Geometry:PointOnLineSegment if available
								if Geometry and Geometry.PointOnLineSegment then
									local rad = s.radius + m.boundingRadius + self.BoundingRadius
									blocks = Geometry:PointOnLineSegment(m.pos, self:To3D(startP), self:To3D(endP), rad)
								else
									-- Fallback: project m onto line segment in 2D and check distance to segment
									local segDir = Point2D(endP - startP)
									local segLenSqr = self:DistanceSquared(startP, endP)
									if segLenSqr > 0 then
										local t = self:DotProduct(Point2D(m2d - startP), segDir) / segLenSqr
										if t >= 0 and t <= 1 then
											local proj = Point2D(startP + segDir * t)
											local distToLine = self:Magnitude(Point2D(m2d - proj))
											blocks = distToLine <= (s.radius + m.boundingRadius + self.BoundingRadius)
										end
									end
								end
								
								if blocks and distHero < bestDist then 
									bestDist = distHero
									bestMinion = m 
								end
							end
						end
					end
				end
				
				if bestMinion then
					self._collisionDetected, self._blockingMinion = true, bestMinion
					self._blockingSpellName = s.name
					-- Anchor safePos behind minion relative to missile direction
					local missileDir = Point2D(endP - startP):Normalized()
					local behind = self:To2D(bestMinion.pos) - missileDir * (bestMinion.boundingRadius + self.BoundingRadius + 15)
					-- If already safe behind, we avoid lateral movement
					if self:IsSafePos(behind, nil) and not MapPosition:inWall(self:To3D(behind)) then
						self.SafePos, self.ExtendedPos = behind, behind
						if not self.Evading then
							self.ResumePos = self:GetMovePath() or self.MousePos
						end
						self.Evading = true
						if not self._evadeDir then
							self._evadeDir = Point2D(behind - self.MyHeroPos):Normalized()
						end
						if _G.DepressiveEvade then _G.DepressiveEvade._collisionDetected = true end
						-- Reset current threat so it can be re-detected later if needed
						self:ResetThreat(s.name)
						self.OldTimer = self.NewTimer
						s._collisionChecked = true
						return 1
					end
				end
				s._collisionChecked = true
			end
			-- Try to use dash spell if available - PRIORITY USE
		if not safePos and self.EvadeSpellData and #self.EvadeSpellData > 0 then
			for i = 1, #self.EvadeSpellData do
				local eSpell = self.EvadeSpellData[i]
				-- Type 1 = dash spells (Vayne Q, Lucian E, etc.)
				if eSpell.type == 1 and self:IsReady(eSpell.slot) then
					-- Calculate spell direction
					local spellDir = self:MissileDir(s)
					local perpDir = spellDir:Perpendicular():Normalized()
					local dashDist = eSpell.range or 300
					
					-- Distance to spell for strategy selection
					local distToSpell = self:Distance(self.MyHeroPos, Point2D(s.position))
					
					-- Create list of candidates
					local candidates = {}
					
					-- Always start with perpendicular (most reliable)
					table.insert(candidates, Point2D(self.MyHeroPos) + perpDir * dashDist)
					table.insert(candidates, Point2D(self.MyHeroPos) - perpDir * dashDist)
					
				-- For close range, try many more angles
				if distToSpell < 400 then
					for angle = -180, 180, 45 do
						if angle ~= 90 and angle ~= -90 then
							local rad = MathRad(angle)
							local dir = Point2D(MathCos(rad), MathSin(rad))
							table.insert(candidates, Point2D(self.MyHeroPos) + dir * dashDist)
						end
					end
				else
					-- Medium-long range: simpler strategy
					table.insert(candidates, Point2D(self.MyHeroPos) - spellDir * dashDist)
					
					local diagDir1 = (perpDir - spellDir):Normalized()
					table.insert(candidates, Point2D(self.MyHeroPos) + diagDir1 * dashDist)
					
					local diagDir2 = (perpDir * -1 - spellDir):Normalized()
					table.insert(candidates, Point2D(self.MyHeroPos) + diagDir2 * dashDist)
				end
				
				-- Score each candidate: prefer positions FURTHEST from spell and SAFEST
				local scoredCandidates = {}
				for _, dashTarget in ipairs(candidates) do
					-- Check if safe FIRST
					if self:IsSafePos(dashTarget, nil) and not MapPosition:inWall(self:To3D(dashTarget)) then
						-- Score based on distance from spell (higher = better)
						local distFromSpell = self:Distance(dashTarget, Point2D(s.position))
						table.insert(scoredCandidates, {pos = dashTarget, score = distFromSpell})
					end
				end
				
			-- Sort by score (descending) - choose the position FURTHEST from spell
			if #scoredCandidates > 0 then
				table.sort(scoredCandidates, function(a, b) return a.score > b.score end)
				local bestDashTarget = scoredCandidates[1].pos
				-- Get screen position from 2D position (only create 3D Vector at last moment)
				local screenPos = nil
				if Renderer and Renderer.WorldToScreen then
					local temp3D = Vector(bestDashTarget.x, myHero.pos.y, bestDashTarget.y)
					screenPos = Renderer.WorldToScreen(temp3D)
				else
					local temp3D = Vector(bestDashTarget.x, myHero.pos.y, bestDashTarget.y)
					if temp3D and temp3D.To2D then
						screenPos = temp3D:To2D()
					end
				end
				if screenPos and (not screenPos.onScreen or screenPos.onScreen) then
					-- CRITICAL: Don't move mouse in WASD mode - only press keys
					if not self:IsWASDMode() then
						Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
					end
					Control.KeyDown(eSpell.slot2)
					Control.KeyUp(eSpell.slot2)
					self.SafePos, self.Evading = bestDashTarget, true
					self.OldTimer = self.NewTimer
					return 1
				end
			end
				end
			end
		end
			
			if self._evadeDir then
				local proj = self:AppendVector(self.MyHeroPos, Point2D(self.MyHeroPos + self._evadeDir * 500), 0)
				-- try to step along the locked direction until we find a safe point
				for step = 1, 6 do
					local cand = Point2D(self.MyHeroPos):Extended(Point2D(self.MyHeroPos + self._evadeDir * 900), step * (self.BoundingRadius + 50))
					if self:IsSafePos(cand, nil) and not MapPosition:inWall(self:To3D(cand)) then
						safePos = cand; break
					end
				end
			end
			if not safePos then
				-- Try explicit perpendicular step first
				local perp = self:PerpFromMissile(s)
				local cand = Point2D(self.MyHeroPos):Extended(Point2D(self.MyHeroPos + perp * 900), self.BoundingRadius + 150)
				if self:IsSafePos(cand, nil) and not MapPosition:inWall(self:To3D(cand)) then
					safePos = cand
				else
					safePos = self:GetBestEvadePos(self.DodgeableSpells, s.radius, 2, nil, false)
				end
			end
		if safePos then
			if not self.Evading then
				-- capture original movement to resume later (robotic style)
				self.ResumePos = self:GetMovePath() or self.MousePos
				self._mousePosOrig = self.MousePos
				local md = Point2D(self.MousePos - self.MyHeroPos)
				self._mouseDirOrig = (self:Magnitude(md) > 0) and md:Normalized() or nil
			end
			self.ExtendedPos = self:GetExtendedSafePos(safePos)
			-- lock lateral direction at first evade using missile perpendicular
			if not self._evadeDir then
				local perp = self:PerpFromMissile(s)
				self._evadeDir = perp
			end
			if _G.DepressiveEvade then _G.DepressiveEvade._lastEvadeDirection = self._evadeDir end
			self.SafePos, self.Evading = safePos, true
			-- Try to use dash spell if available and threat is very close
			self:TryUseDashSpell(s)
		elseif evadeSpells and #evadeSpells > 0 or flashUsage then
				local result = 0
				for i = 1, #evadeSpells do
					local alternPos = self:GetBestEvadePos(self.DodgeableSpells, s.radius, 1, i, false)
					result = self:Avoid(s, alternPos, evadeSpells[i])
					if result > 0 then
						if result == 1 then
							if not self.Evading then
								self.ResumePos = self:GetMovePath() or self.MousePos
								self._mousePosOrig = self.MousePos
								local md = Point2D(self.MousePos - self.MyHeroPos)
								self._mouseDirOrig = (self:Magnitude(md) > 0) and md:Normalized() or nil
							end
							self.ExtendedPos = self:GetExtendedSafePos(alternPos)
							if not self._evadeDir then
								local perp = self:PerpFromMissile(s)
								self._evadeDir = perp
							end
							if _G.DepressiveEvade then _G.DepressiveEvade._lastEvadeDirection = self._evadeDir end
							self.SafePos, self.Evading = alternPos, true
						end
						break
					end
				end
			if result == 0 then
				local dodgePos = self:GetBestEvadePos(self.DodgeableSpells, s.radius, 1, true, true)
				if dodgePos then
					if flashUsage and type(self.FlashRange) == "number" then
						local flashPos = Point2D(self.MyHeroPos):Extended(dodgePos, self.FlashRange)
						if flashPos then
							-- Use 2D position for flash (only create 3D Vector at last moment)
							local screenPos = nil
							if Renderer and Renderer.WorldToScreen then
								local temp3D = Vector(flashPos.x, myHero.pos.y, flashPos.y)
								screenPos = Renderer.WorldToScreen(temp3D)
							else
								local temp3D = Vector(flashPos.x, myHero.pos.y, flashPos.y)
								if temp3D and temp3D.To2D then
									screenPos = temp3D:To2D()
								end
							end
							if screenPos and (not screenPos.onScreen or screenPos.onScreen) then
								result = 1
								-- CRITICAL: Don't move mouse in WASD mode - only press keys
								if not self:IsWASDMode() then
									Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
								end
								Control.KeyDown(self.Flash)
								Control.KeyUp(self.Flash)
							end
						end
					elseif self:SpellMenuValue(s.name, "Force"..s.name, false) then
							if not self.Evading then
								self.ResumePos = self:GetMovePath() or self.MousePos
							end
							self.ExtendedPos = self:GetExtendedSafePos(dodgePos)
							if not self._evadeDir then
								local dir = Point2D(self.ExtendedPos - self.MyHeroPos)
								if dir:Magnitude() > 0 then self._evadeDir = dir:Normalized() end
							end
							self.SafePos, self.Evading = dodgePos, true
						end
					end
				end
				if result == 0 then
					for i = 1, #self.OnImpDodgeCBs do self.OnImpDodgeCBs[i](s.danger) end
				end
			else
				for i = 1, #self.OnImpDodgeCBs do self.OnImpDodgeCBs[i](s.danger) end
			end
			self.OldTimer = self.NewTimer
		end
		return 1
	end
	return 0
end

function DEvade:SpellManager(i, s)
	local currentTime = GameTimer()
	if s.startTime + s.range / s.speed + s.delay > currentTime then
		-- Only regenerate polygon if missile has moved significantly
		if s.speed ~= MathHuge and s.startTime + s.delay < currentTime then
			if s.type == "linear" or s.type == "threeway" then
				local rng = s.speed * (currentTime - s.startTime - s.delay)
				local sP = Point2D(s.startPos):Extended(s.endPos, rng)
				
				-- Cache last update to avoid excessive polygon regeneration
				if s._lastUpdateTime == nil or (currentTime - s._lastUpdateTime) > 0.016 then
					s.position = sP
					s.path = self:RectangleToPolygon(sP, s.endPos, s.radius, self.BoundingRadius)
					s.path2 = self:RectangleToPolygon(sP, s.endPos, s.radius)
					s._lastUpdateTime = currentTime
				else
					s.position = sP
				end
			end
		end
	else 
		TableRemove(self.DetectedSpells, i)
	end
end

function DEvade:DodgeSpell()
	if Buffs and Buffs[myHero.charName] and self:HasBuff(Buffs[myHero.charName]) then
		self.SafePos, self.ExtendedPos = nil, nil
	end

	-- If using collision shield, hold position (no movement) behind minion
	if self._collisionDetected and self._blockingMinion then
		return
	end

	-- Ensure we have current dodgeable spells cached
	self.DodgeableSpells = self:GetDodgeableSpells()
	
	-- Clear locked WASD direction if the spell is no longer dodgeable
	if self._lockedWASDSpell and self:IsWASDMode() then
		local spellStillActive = false
		for i = 1, #self.DodgeableSpells do
			local s = self.DodgeableSpells[i]
			if s and s.name then
				local spellIdentifier = s.name
				if s.position then
					local posHash = math.floor((s.position.x + s.position.y) / 100)
					spellIdentifier = spellIdentifier .. "_" .. tostring(posHash)
				end
				if spellIdentifier == self._lockedWASDSpell then
					spellStillActive = true
					break
				end
			end
		end
		if not spellStillActive then
			-- Locked spell is no longer active - clear the lock
			self._lockedWASDSpell = nil
			self._lockedWASDSpellTime = 0
		end
	end

	-- Check ALL dodgeable spells and dodge BEFORE impact (not when already hitting)
	for i = 1, #self.DodgeableSpells do
		local s = self.DodgeableSpells[i]
		if not s then goto continue end -- Skip if spell is nil
		
		-- Use ShouldDodge which checks time to impact - only dodge if we have enough time
		local should, tth = self:ShouldDodge(s)
		
		-- Only execute movement if ShouldDodge returns true (meaning we have time to dodge)
		-- This ensures we dodge BEFORE impact, not when already hitting
		if should and tth > 0 then
			local best = self:GetBestDodgePosition(s)
			if best then
				-- set safe pos and perform a single movement command toward it IMMEDIATELY
				self.SafePos = best
				self.ExtendedPos = nil
				self.Evading = true
				if not self.ResumePos then self.ResumePos = self:GetMovePath() or self.MousePos end
				-- Use existing MoveToPos which uses Cursor/Add or SetCursorPos fallback
				-- Execute immediately without delay
				pcall(function() self:MoveToPos(best) end)
				return 1
			end
		end
		::continue::
	end

	-- Fallback: continue moving to calculated safe/extended pos (robotic continuous movement)
	local moveTarget = self.ExtendedPos or self.SafePos
	if moveTarget then
		self:MoveToPos(moveTarget)
		self._lastDodgeTarget = Point2D(moveTarget)
	elseif self._evadeDir then
		local forward = Point2D(self.MyHeroPos):Extended(Point2D(self.MyHeroPos + self._evadeDir * 900), self.BoundingRadius * 2)
		self:MoveToPos(forward)
		self._lastDodgeTarget = forward
	end
end

-- Try to use dash spell (Vayne Q, Lucian E, etc.) if threat is very close
function DEvade:TryUseDashSpell(spell)
	if not spell or not self.EvadeSpellData or #self.EvadeSpellData == 0 then return end
	
	-- Threat is detected, try to use a dash spell immediately (more aggressive)
	for i = 1, #self.EvadeSpellData do
		local eSpell = self.EvadeSpellData[i]
		-- Type 1 = dash spells (Vayne Q, Lucian E, Ekko E, etc.)
		if eSpell.type == 1 then
			-- Check if spell is ready
			if self:IsReady(eSpell.slot) then
				-- Calculate spell direction and perpendicular
				local spellDir = self:MissileDir(spell)
				local perpDir = spellDir:Perpendicular():Normalized()
				local dashDist = eSpell.range or 300
				
				-- Distance to spell for strategy selection
				local distToSpell = self:Distance(self.MyHeroPos, Point2D(spell.position))
				
				-- Create candidates list - more options for close range
				local candidates = {}
				
				-- Always try perpendicular directions first (most reliable)
				table.insert(candidates, Point2D(self.MyHeroPos) + perpDir * dashDist)
				table.insert(candidates, Point2D(self.MyHeroPos) - perpDir * dashDist)
				
			-- For close range, add more aggressive options
			if distToSpell < 400 then
				-- At close range, try all diagonal combinations
				for angle = -180, 180, 45 do
					if angle ~= 90 and angle ~= -90 then -- Skip the spell direction
						local rad = MathRad(angle)
						local dir = Point2D(MathCos(rad), MathSin(rad))
						table.insert(candidates, Point2D(self.MyHeroPos) + dir * dashDist)
					end
				end
			else
				-- Medium-long range: use backwards and diagonal
				table.insert(candidates, Point2D(self.MyHeroPos) - spellDir * dashDist)
				
				local diagDir1 = (perpDir - spellDir):Normalized()
				table.insert(candidates, Point2D(self.MyHeroPos) + diagDir1 * dashDist)
				
				local diagDir2 = (perpDir * -1 - spellDir):Normalized()
				table.insert(candidates, Point2D(self.MyHeroPos) + diagDir2 * dashDist)
			end
			
			-- Score each candidate: prefer positions FURTHEST from spell and SAFEST
			local scoredCandidates = {}
			for _, dashTarget in ipairs(candidates) do
				-- Check if safe FIRST
				if self:IsSafePos(dashTarget, nil) and not MapPosition:inWall(self:To3D(dashTarget)) then
					-- Score based on distance from spell (higher = better)
					local distFromSpell = self:Distance(dashTarget, Point2D(spell.position))
					table.insert(scoredCandidates, {pos = dashTarget, score = distFromSpell})
				end
			end
			
			-- Sort by score (descending) - choose the position FURTHEST from spell
			if #scoredCandidates > 0 then
				table.sort(scoredCandidates, function(a, b) return a.score > b.score end)
				local bestDashTarget = scoredCandidates[1].pos
				-- Get screen position from 2D position (only create 3D Vector at last moment)
				local screenPos = nil
				if Renderer and Renderer.WorldToScreen then
					local temp3D = Vector(bestDashTarget.x, myHero.pos.y, bestDashTarget.y)
					screenPos = Renderer.WorldToScreen(temp3D)
				else
					local temp3D = Vector(bestDashTarget.x, myHero.pos.y, bestDashTarget.y)
					if temp3D and temp3D.To2D then
						screenPos = temp3D:To2D()
					end
				end
				if screenPos and (not screenPos.onScreen or screenPos.onScreen) then
					-- CRITICAL: Don't move mouse in WASD mode - only press keys
					if not self:IsWASDMode() then
						Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
					end
					-- Press and release the spell key
					Control.KeyDown(eSpell.slot2)
					Control.KeyUp(eSpell.slot2)
					return true
				end
			end
			end
		end
	end
	return false
end

function DEvade:GetTimeToSpellHit(spell)
    if not spell then return 0 end
    
    -- Hechizos instantáneos
    if spell.speed == MathHuge then
        local timeLeft = (spell.startTime + spell.delay) - GameTimer()
        return math.max(0.05, timeLeft)  -- Mínimo 50ms para reacción
    end
    
    local currentTime = GameTimer()
    local elapsedTime = currentTime - spell.startTime
    
    -- Calcular posición actual del proyectil
    local traveledDist = 0
    if elapsedTime > spell.delay then
        traveledDist = spell.speed * (elapsedTime - spell.delay)
    end
    
    -- Calcular distancia al punto más cercano del héroe
    local closest = self:ClosestPointOnSegment(spell.position, spell.endPos, self.MyHeroPos)
    local distToHero = self:Distance(spell.startPos, closest)
    
    -- Si el proyectil ya pasó el punto más cercano
    if traveledDist >= distToHero then
        return 0
    end
    
    -- Tiempo restante
    local remainingDist = distToHero - traveledDist
    return remainingDist / spell.speed
end

function DEvade:Avoid(spell, dodgePos, data)
	if self:IsReady(data.slot) and self.JEMenu.Spells[data.name]["US"..data.name]:Value()
		and spell.danger >= self.JEMenu.Spells[data.name]["Danger"..data.name]:Value() then
		if dodgePos and (data.type == 1 or data.type == 2) then
			if data.type == 1 then
				-- Dash: use 2D position converted to screen coordinates (only create 3D Vector at last moment)
				local dashPos = Point2D(self.MyHeroPos):Extended(dodgePos, data.range)
				local screenPos = nil
				if Renderer and Renderer.WorldToScreen then
					local temp3D = Vector(dashPos.x, myHero.pos.y, dashPos.y)
					screenPos = Renderer.WorldToScreen(temp3D)
				else
					local temp3D = Vector(dashPos.x, myHero.pos.y, dashPos.y)
					if temp3D and temp3D.To2D then
						screenPos = temp3D:To2D()
					end
				end
				if screenPos and (not screenPos.onScreen or screenPos.onScreen) then
					-- CRITICAL: Don't move mouse in WASD mode - only press keys
					if not self:IsWASDMode() then
						Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
					end
					Control.KeyDown(data.slot2)
					Control.KeyUp(data.slot2)
				end
				return 1
			elseif data.type == 2 then 
				-- Shield: cast on self
				local screenPos = myHero.pos:To2D()
				if screenPos and screenPos.onScreen then
					-- CRITICAL: Don't move mouse in WASD mode - only press keys
					if not self:IsWASDMode() then
						Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
					end
					Control.KeyDown(data.slot2)
					Control.KeyUp(data.slot2)
				end
				return 1 
			end
		elseif data.type == 3 then 
			-- Buff: cast on self
			local screenPos = myHero.pos:To2D()
			if screenPos and screenPos.onScreen then
				-- CRITICAL: Don't move mouse in WASD mode - only press keys
				if not self:IsWASDMode() then
					Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
				end
				Control.KeyDown(data.slot2)
				Control.KeyUp(data.slot2)
			end
			return 2
		elseif data.type == 4 then
			-- Target spell
			for i = 1, GameHeroCount() do
				local enemy = GameHero(i)
				if enemy and self:ValidTarget(enemy, data.range) and myHero.team ~= enemy.team then
					local screenPos = enemy.pos:To2D()
					if screenPos and screenPos.onScreen then
						-- CRITICAL: Don't move mouse in WASD mode - only press keys
						if not self:IsWASDMode() then
							Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
						end
						Control.KeyDown(data.slot2)
						Control.KeyUp(data.slot2)
					end
					return 2
				end
			end
		elseif data.type == 5 and spell.cc then
			-- CC spell on self
			local screenPos = myHero.pos:To2D()
			if screenPos and screenPos.onScreen then
				-- CRITICAL: Don't move mouse in WASD mode - only press keys
				if not self:IsWASDMode() then
					Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
				end
				Control.KeyDown(data.slot2)
				Control.KeyUp(data.slot2)
			end
			return 2
		elseif data.type == 6 and spell.windwall then
			-- Windwall: position-based (use 2D only, create 3D Vector at last moment)
			local wallPos = Point2D(self.MyHeroPos):Extended(spell.position, 100)
			if _G.SDK then _G.SDK.Orbwalker:SetAttack(false);
				_G.SDK.Orbwalker:SetMovement(false) end
			DelayAction(function()
				local screenPos = nil
				if Renderer and Renderer.WorldToScreen then
					local temp3D = Vector(wallPos.x, myHero.pos.y, wallPos.y)
					screenPos = Renderer.WorldToScreen(temp3D)
				else
					local temp3D = Vector(wallPos.x, myHero.pos.y, wallPos.y)
					if temp3D and temp3D.To2D then
						screenPos = temp3D:To2D()
					end
				end
				if screenPos and (not screenPos.onScreen or screenPos.onScreen) then
					-- CRITICAL: Don't move mouse in WASD mode - only press keys
					if not self:IsWASDMode() then
						Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
					end
					Control.KeyDown(data.slot2)
					Control.KeyUp(data.slot2)
				end
				DelayAction(function()
					if _G.SDK then _G.SDK.Orbwalker:SetAttack(true); _G.SDK.Orbwalker:SetMovement(true) end
				end, 0.01)
			end, 0.01)
			return 2
		elseif data.type == 7 and spell.cc then
			-- Portal spell (use 2D only, create 3D Vector at last moment)
			local spellPos2D = Point2D(spell.position)
			local screenPos = nil
			if Renderer and Renderer.WorldToScreen then
				local temp3D = Vector(spellPos2D.x, myHero.pos.y, spellPos2D.y)
				screenPos = Renderer.WorldToScreen(temp3D)
			else
				local temp3D = Vector(spellPos2D.x, myHero.pos.y, spellPos2D.y)
				if temp3D and temp3D.To2D then
					screenPos = temp3D:To2D()
				end
			end
			if screenPos and (not screenPos.onScreen or screenPos.onScreen) then
				-- CRITICAL: Don't move mouse in WASD mode - only press keys
				if not self:IsWASDMode() then
					Control.SetCursorPos(MathFloor(screenPos.x), MathFloor(screenPos.y))
				end
				Control.KeyDown(data.slot2)
				Control.KeyUp(data.slot2)
			end
			return 2
		end
	end
	return 0
end

function DEvade:Draw()
	local evadeEnabled = self.JEMenu.Main.Evade:Value()

	-- Cache menu values to avoid repeated lookups
	local drawEnabled = self.JEMenu.Main.Draw:Value()
	local statusEnabled = self.JEMenu.Main.Status:Value()
	local safePosEnabled = self.JEMenu.Main.SafePos:Value()
	local debugEnabled = self.JEMenu.Main.Debug:Value()
	
	self.DodgeableSpells = self:GetDodgeableSpells()
	
	if statusEnabled then
		if not evadeEnabled then
			-- Show clearly that the evade toggle is off
			self:DrawText("Depressive - Evade: OFF", 14, myHero.pos2D, -95, 45, DrawColor(224, 200, 200, 200))
		elseif self.DoD then
			self:DrawText("Depressive - Evade: DANGEROUS ONLY", 14, myHero.pos2D, -115, 45, DrawColor(224, 255, 255, 0))
		else
			self:DrawText("Depressive - Evade: ON", 14, myHero.pos2D, -95, 45, DrawColor(224, 0, 255, 120))
		end
	end
	
	-- Only draw safe position visuals if we actually have a valid 2D point
	if #self.DetectedSpells > 0 and self.Evading and safePosEnabled then
		local sp = self.SafePos
		if type(sp) == "table" and sp.x and sp.y then
			local sp3 = self:To3D(sp)
			if sp3 then
				DrawCircle(sp3, self.BoundingRadius, 0.5, self.JEMenu.Main.SPC:Value())
			end
			self:DrawArrow(self.MyHeroPos, sp, self.JEMenu.Main.Arrow:Value())
			-- draw resume line for robotic clarity
			if self.ResumePos and type(self.ResumePos) == "table" and self.ResumePos.x and self.ResumePos.y then
				self:DrawArrow(sp, self.ResumePos, DrawColor(160, 120, 200, 255))
			end
		end
	end
	
	-- Draw WASD directions debug visualization
	local useWASD = self:IsWASDMode()
	local wasdDebugEnabled = self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.WASDDebug and self.JEMenu.Main.WASDDebug:Value()
	if useWASD and wasdDebugEnabled and self._lastWASDCandidates and #self._lastWASDCandidates > 0 then
		local myPos3D = self:To3D(self.MyHeroPos)
		if myPos3D then
			-- Get current hero position for relative calculations
			local currentHeroPos = Point2D(self.MyHeroPos)
			local dist = (self.JEMenu.Main.DodgeDistance and self.JEMenu.Main.DodgeDistance:Value()) or 325
			
			-- Colors for different states
			local normalColor = DrawColor(180, 100, 100, 100)  -- Gray for available directions
			local selectedColor = DrawColor(255, 0, 255, 0)     -- Green for selected direction
			local unsafeColor = DrawColor(255, 255, 0, 0)        -- Red for unsafe directions
			
			for _, wasdCand in ipairs(self._lastWASDCandidates) do
				-- Recalculate position relative to current hero position (so circles follow hero)
				local directionVec = wasdCand.direction
				if directionVec then
					-- Use the direction vector from the candidate to calculate new position relative to current hero pos
					local candPos = Point2D(currentHeroPos + directionVec * dist)
					local cand3D = self:To3D(candPos)
					if cand3D then
						-- Determine color based on safety and selection
						local isSelected = self._bestWASDDirection and self._bestWASDDirection.dir == wasdCand.dir
						local isSafe = self:IsSafePos(candPos, nil) and not MapPosition:inWall(cand3D)
						
						local color = normalColor
						if isSelected then
							color = selectedColor
						elseif not isSafe then
							color = unsafeColor
						end
						
						-- Draw line from hero to candidate position
						local hero2D = self:To2D(myPos3D)
						DrawLine(hero2D.x, hero2D.y, candPos.x, candPos.y, 2, color)
						
						-- Draw circle at candidate position
						DrawCircle(cand3D, 30, 1, color)
						
						-- Draw direction label (W, A, S, D, etc.)
						local labelColor = isSelected and DrawColor(255, 255, 255, 255) or DrawColor(200, 200, 200, 200)
						if Renderer and Renderer.WorldToScreen then
							local screenPos = Renderer.WorldToScreen(cand3D)
							if screenPos and screenPos.x and screenPos.y then
								-- Use the SDK DrawText directly with screen coordinates
								DrawText(wasdCand.dir, 12, screenPos.x - 5, screenPos.y - 5, labelColor)
							else
								-- Fallback: use 2D position with custom DrawText
								local cand2D = self:To2D(cand3D)
								if cand2D then
									self:DrawText(wasdCand.dir, 12, cand2D, -5, -5, labelColor)
								end
							end
						else
							-- Fallback: use 2D position with custom DrawText
							local cand2D = self:To2D(cand3D)
							if cand2D then
								self:DrawText(wasdCand.dir, 12, cand2D, -5, -5, labelColor)
							end
						end
					end
				end
			end
			
			-- Draw selected direction highlight
			if self._bestWASDDirection and self.Evading then
				-- Recalculate best position relative to current hero position
				local bestDir = self._bestWASDDirection.direction
				if bestDir then
					local bestPos = Point2D(currentHeroPos + bestDir * dist)
					local best3D = self:To3D(bestPos)
					if best3D then
						-- Draw larger circle for selected direction
						DrawCircle(best3D, 50, 2, selectedColor)
						-- Draw thicker line
						local hero2D = self:To2D(myPos3D)
						DrawLine(hero2D.x, hero2D.y, bestPos.x, bestPos.y, 3, selectedColor)
					end
				end
			end
		end
	end
	
	if drawEnabled then
		if debugEnabled then
			local debugCount = #self.Debug
			for i = 1, debugCount do
				DrawCircle(self:To3D(self.Debug[i]), self.BoundingRadius, 0.5, DrawColor(192, 255, 255, 0))
			end
		end
		
		local evadeColor = self.JEMenu.Main.EvadeSpellColor:Value()
		local lowColor = self.JEMenu.Main.LowDangerSpellColor:Value()
		
		-- Draw high danger (being considered for evade)
		local dodgeableCount = #self.DodgeableSpells
		for i = 1, dodgeableCount do
			local s = self.DodgeableSpells[i]
			if not s then goto continue end -- Defensive check: ensure spell is not nil
			if self:SpellMenuValue(s.name, "Draw"..s.name, true) then
				self:DrawPolygon(s.path2, s.y, evadeColor)
			end
			::continue::
		end
		
		-- Draw low danger (skipped) spells - only if there are any
		if self._lowDangerSpells then
			local lowDangerCount = #self._lowDangerSpells
			if lowDangerCount > 0 then
				for i = 1, lowDangerCount do
					local s = self._lowDangerSpells[i]
					if not s then goto continue end -- Defensive check: ensure spell is not nil
					if self:SpellMenuValue(s.name, "Draw"..s.name, true) then
						self:DrawPolygon(s.path2, s.y, lowColor)
					end
					::continue::
				end
			end
		end
	end
end

function DEvade:OnProcessSpell(unit, spell)
	if unit and spell then
		-- In Arena: process allied & enemy spells (exclude self unless Flash)
		if unit.team ~= myHero.team or (self:IsArena() and unit ~= myHero) then
			local unitPos, name = self:To2D(unit.pos), spell.name
			if self.JEMenu.Core.LimitRange:Value() and self:Distance(self.MyHeroPos, unitPos)
				> self.JEMenu.Core.LR:Value() then return end
			if SpellDatabase[unit.charName] and SpellDatabase[unit.charName][name] then
				local data = self:CopyTable(SpellDatabase[unit.charName][name])
				if data.exception then return end
				local startPos, placementPos = self:To2D(spell.startPos), self:To2D(spell.placementPos)
				local endPos, range = self:CalculateEndPos(startPos, placementPos, unitPos, data.speed, data.range, data.radius, data.collision, data.type, data.extend)
				if unit.charName == "Yasuo" or unit.charName == "Yone" then endPos = startPos + self:To2D(unit.dir) * data.range end
				local extraRange = 0
				if self.JEMenu.Spells[name] and self.JEMenu.Spells[name]["ER"..name] then
					extraRange = self.JEMenu.Spells[name]["ER"..name]:Value() or 0
				end
				data.range, data.radius, data.y = range, data.radius + extraRange, spell.placementPos.y
				local path, path2 = self:GetPaths(startPos, endPos, data, name)
				if path == nil then return end
				if name == "VelkozQ" then self:SpellExistsThenRemove("VelkozQ"); return end
				self:AddSpell(path, path2, startPos, endPos, data, data.speed, range, data.delay, data.radius, name)
				if data.type == "threeway" then
					for i = 1, 2 do
						local eP = i == 1 and self:Rotate(startPos, endPos, MathRad(data.angle)) or
											self:Rotate(startPos, endPos, -MathRad(data.angle))
						local p1 = self:RectangleToPolygon(startPos, eP, data.radius, self.BoundingRadius)
						local p2 = self:RectangleToPolygon(startPos, eP, data.radius)
						self:AddSpell(p1, p2, startPos, eP, data, data.speed, range, data.delay, data.radius, name)
					end
				end
				self.NewTimer = GameTimer()
				
				-- IMMEDIATE REACTION: Check if this spell should be dodged and execute movement immediately
				-- This ensures movement happens as soon as spell is processed, not waiting for next Tick()
				self.DodgeableSpells = self:GetDodgeableSpells()
				if #self.DodgeableSpells > 0 then
					-- Check the most recent spell (last one added)
					local recentSpell = self.DodgeableSpells[#self.DodgeableSpells]
					if recentSpell then
						local should, tth = self:ShouldDodge(recentSpell)
						if should and tth > 0 then
							local best = self:GetBestDodgePosition(recentSpell)
							if best then
								-- Execute movement IMMEDIATELY when spell is processed
								self.SafePos = best
								self.ExtendedPos = nil
								self.Evading = true
								if not self.ResumePos then self.ResumePos = self:GetMovePath() or self.MousePos end
								pcall(function() self:MoveToPos(best) end)
								if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
									print(string.format("[Depressive Evade] IMMEDIATE DODGE (ProcessSpell): %s detected, moving to (%.1f, %.1f), time to hit: %.3f", 
										name, best.x, best.y, tth))
								end
							end
						end
					end
				end
			end
		elseif unit == myHero and spell.name == "SummonerFlash" then
			self.NewTimer, self.SafePos, self.ExtendedPos = GameTimer(), nil, nil
		end
	end
end

function DEvade:OnCreateMissile(unit, missile)
	local name, unitPos = missile.name, self:To2D(unit.pos)
	-- Debug: log missile names if requested by menu
			if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
				if not self.DebugDetectedMissiles[name] then
					self.DebugDetectedMissiles[name] = true
					print("[Depressive Evade] Missile Created: ", name, " by ", unit.charName, " from:", missile.startPos.x, missile.startPos.y, "->", missile.endPos.x, missile.endPos.y)
				end
			end
	-- Defensive checks: ensure name and SpellDatabase entries exist and avoid nil patterns
	if not name or string.find(name, "ttack", 1, true) or not SpellDatabase[unit.charName] then return end
	if self.JEMenu.Core.LimitRange:Value() and self:Distance(self.MyHeroPos, unitPos)
		> self.JEMenu.Core.LR:Value() then return end
	local menuName = ""
	for i, val in pairs(SpellDatabase[unit.charName]) do
		if val.fow then
			local tested = val.missileName
			-- Only test if missileName is a non-empty string; use plain search for safety
			if tested and type(tested) == "string" and tested ~= "" then
				if string.find(name, tested, 1, true) then menuName = i break end
			else
				-- If missileName is missing, we might want to discover/populate it later.
				-- Keep a small debug log here if MissileLog is enabled (non-intrusive)
						if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
							if not self.DebugDetectedMissing[unit.charName .. ":" .. (i or "")] then
								self.DebugDetectedMissing[unit.charName .. ":" .. (i or "")] = true
								print("[Depressive Evade] Missing missileName for ", unit.charName, " -> ", i)
							end
						end
			end
		end
	end
	if menuName == "" then
		-- Unrecognized missile: log details to help fix DB entries
		if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
			print("[Depressive Evade] Unrecognized missile: ", name, " by ", unit.charName)
		end
		return
	end
	local data = self:CopyTable(SpellDatabase[unit.charName][menuName])
	-- Guard menu lookups with the safe accessor to avoid nil indexing
	local fowSetting = self:SpellMenuValue(menuName, "FOW"..menuName, false)
	local extraRange = self:SpellMenuValue(menuName, "ER"..menuName, 0)
	if fowSetting and ((not unit.visible and not data.exception) or (data.exception and unit.visible)) then
		local startPos, placementPos = self:To2D(missile.startPos), self:To2D(missile.endPos)
		local endPos, range = self:CalculateEndPos(startPos, placementPos, unitPos, data.speed, data.range, data.radius, data.collision, data.type, data.extend)
		data.range, data.radius, data.y = range, data.radius + (extraRange or 0), missile.endPos.y
		local path, path2 = self:GetPaths(startPos, endPos, data, name)
		if path == nil then return end
		if menuName == "VelkozQMissileSplit" then self:SpellExistsThenRemove("VelkozQ")
		elseif menuName == "JayceShockBlastWallMis" then self:SpellExistsThenRemove("JayceShockBlast") end
		self:AddSpell(path, path2, startPos, endPos, data, data.speed, range, 0, data.radius, menuName)
		if data.type == "threeway" then
			for i = 1, 2 do
				local eP = i == 1 and self:Rotate(startPos, endPos, MathRad(data.angle)) or
										self:Rotate(startPos, endPos, -MathRad(data.angle))
				local p1 = self:RectangleToPolygon(startPos, eP, data.radius, self.BoundingRadius)
				local p2 = self:RectangleToPolygon(startPos, eP, data.radius)
				self:AddSpell(p1, p2, startPos, eP, data, data.speed, range, 0, data.radius, menuName)
			end
		end
		self.NewTimer = GameTimer()
		
		-- IMMEDIATE REACTION: Check if this spell should be dodged and execute movement immediately
		-- This ensures movement happens as soon as missile is detected, not waiting for next Tick()
		self.DodgeableSpells = self:GetDodgeableSpells()
		if #self.DodgeableSpells > 0 then
			-- Check the most recent spell (last one added)
			local recentSpell = self.DodgeableSpells[#self.DodgeableSpells]
			if recentSpell then
				local should, tth = self:ShouldDodge(recentSpell)
				if should and tth > 0 then
					local best = self:GetBestDodgePosition(recentSpell)
					if best then
						-- Execute movement IMMEDIATELY when missile is detected
						self.SafePos = best
						self.ExtendedPos = nil
						self.Evading = true
						if not self.ResumePos then self.ResumePos = self:GetMovePath() or self.MousePos end
						pcall(function() self:MoveToPos(best) end)
						if self.JEMenu and self.JEMenu.Main and self.JEMenu.Main.MissileLog and self.JEMenu.Main.MissileLog:Value() then
							print(string.format("[Depressive Evade] IMMEDIATE DODGE: %s detected, moving to (%.1f, %.1f), time to hit: %.3f", 
								menuName, best.x, best.y, tth))
						end
					end
				end
			end
		end
	end
end

function OnLoad()
	print("Loading Depressive - Evade...")
	DelayAction(function()
		DEvade:__init()
		if DEvade.JEMenu and DEvade.JEMenu.Main and DEvade.JEMenu.Main.MissileLog and DEvade.JEMenu.Main.MissileLog:Value() then
			DEvade:PrintMissingFowMissiles()
		end
		print("Depressive - Evade successfully loaded!")
		ReleaseEvadeAPI(); --AutoUpdate()
	end, MathMax(0.07, 30 - GameTimer()))
end

-- API

function ReleaseEvadeAPI()
	_G.DepressiveEvade = {
		Loaded = function() return DEvade.Loaded end,
		Evading = function() return DEvade.Evading end,
		IsDangerous = function(self, pos) return DEvade:IsDangerous(DEvade:To2D(pos)) end,
		SafePos = function(self) return DEvade:SafePosition() end,
		ResetEvadeState = function(self) DEvade:ResetEvadeState() end,
		ResetThreat = function(self, spell) DEvade:ResetThreat(spell) end,
		CurrentThreat = function() return DEvade._currentThreat end,
		OnImpossibleDodge = function(self, func) DEvade:ImpossibleDodge(func) end,
		OnCreateMissile = function(self, func) DEvade:CreateMissile(func) end,
		OnProcessSpell = function(self, func) DEvade:ProcessSpell(func) end
	}
	-- Backwards compatibility: keep old global name pointing to the new API table
	_G.JustEvade = _G.DepressiveEvade
end

function DEvade:PrintMissingFowMissiles()
	local missing = {}
	for champ, spells in pairs(SpellDatabase) do
		for key, val in pairs(spells) do
			if val.fow and not val.missileName then
				TableInsert(missing, champ .. "." .. key)
			end
		end
	end
	if #missing > 0 then
		print('[Depressive Evade] FOW spells without missileName entries: ' .. table.concat(missing, ', '))
	else
		print('[Depressive Evade] No FOW spells missing missileName entries found.')
	end
end