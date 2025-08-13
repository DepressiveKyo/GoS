local LOADER_VERSION = 1.06
local DEPRESSIVE_PATH = COMMON_PATH .. "Depressive/" -- local storage path (unchanged locally)
local CHAMPIONS_PATH = DEPRESSIVE_PATH .. "Champions/"
local UTILITY_PATH = DEPRESSIVE_PATH .. "Utility/"
local LOADER_FILE = "DepressiveLoader.lua"
local LOADER_VERSION_FILE = "DepressiveLoader.version"

-- Remote raw base now only uses the single 'Depressive' folder at repo root
local GITHUB_BASE = "https://raw.githubusercontent.com/DepressiveKyo/GoS/main/Depressive/"
local GITHUB_CHAMPIONS_BASE = GITHUB_BASE .. "Champions/"

local function FileExists(path)
    local f = io.open(path, "r") if f then f:close() return true end return false
end

local function ReadFirstLine(path)
    local f = io.open(path, "r") if not f then return nil end local l = f:read("*l") f:close() return l
end

local function DownloadFile(folder, fileName, base)
    base = base or GITHUB_BASE
    local start = os.clock()
    DownloadFileAsync(base .. fileName, folder .. fileName, function() end)
    repeat until os.clock() - start > 3 or FileExists(folder .. fileName)
end

local function AutoUpdateLoader()
    DownloadFile(DEPRESSIVE_PATH, LOADER_VERSION_FILE, GITHUB_BASE)
    local remote = tonumber(ReadFirstLine(DEPRESSIVE_PATH .. LOADER_VERSION_FILE)) or LOADER_VERSION
    if remote > LOADER_VERSION then
        DownloadFile(DEPRESSIVE_PATH, LOADER_FILE, GITHUB_BASE)
        print(string.format("[DepressiveLoader] Updated to v%.2f. Please reload (F6)", remote))
    else
        print(string.format("[DepressiveLoader] v%.2f loaded", LOADER_VERSION))
    end
end

AutoUpdateLoader()

-- Utility auto-update (e.g., DepressivePrediction)
local function EnsureUtilityUpdated(fileName, inUtilityFolder)
    if not fileName then return end
    local base = fileName:gsub("%.lua$", "")
    local verFile = base .. ".version"
    local targetFolder = inUtilityFolder and UTILITY_PATH or DEPRESSIVE_PATH
    DownloadFile(targetFolder, verFile, GITHUB_BASE .. (inUtilityFolder and "Utility/" or ""))
    local remoteVer = tonumber(ReadFirstLine(targetFolder .. verFile))
    if not remoteVer then return end
    local localLine = ReadFirstLine(targetFolder .. fileName)
    local localVer = localLine and tonumber(localLine:match("scriptVersion%s*=%s*([%d%.]+)"))
    if (not FileExists(targetFolder .. fileName)) or (not localVer) or (remoteVer > localVer) then
        DownloadFile(targetFolder, fileName, GITHUB_BASE .. (inUtilityFolder and "Utility/" or ""))
        print(string.format("[DepressiveLoader] Updated utility %s (remote %.2f)", base, remoteVer))
        return true
    end
    return false
end

-- List of core utilities to keep updated and preload
local CORE_UTILITIES = {
    { file = "DepressivePrediction.lua", req = "DepressivePrediction", folder = "Utility", auto = true },
    { file = "DepressiveActivatorG.lua", req = "DepressiveActivatorG", folder = "Utility", auto = false },
    { file = "DepressiveAutoSmite.lua", req = "DepressiveAutoSmite", folder = "Utility", auto = false },
}

local UtilityModules = {}
for _, u in ipairs(CORE_UTILITIES) do
    local inUtil = (u.folder == "Utility")
    EnsureUtilityUpdated(u.file, inUtil)
    if u.auto then
        local reqPath = inUtil and ("Depressive/Utility/" .. u.req) or ("Depressive/" .. u.req)
        local ok, mod = pcall(function() return require(reqPath) end)
        if not ok then ok, mod = pcall(function() return require(u.req) end) end
        if ok then UtilityModules[u.req] = mod end
    end
end

-- Simple utility master menu
local UtilityMenu = nil
if _G.MenuElement then
    UtilityMenu = MenuElement({ type = MENU, id = "DepressiveUtilityRoot", name = "Depressive Utility" })
    UtilityMenu:MenuElement({ id = "info", name = "Toggle extra utilities", value = true })
    UtilityMenu:MenuElement({ id = "enableActivator", name = "Enable Activator", value = false })
    UtilityMenu:MenuElement({ id = "enableSmite", name = "Enable AutoSmite", value = false })
end

local function TryLoadOptionalUtility(reqName)
    local path = "Depressive/Utility/" .. reqName
    local ok, mod = pcall(function() return require(path) end)
    if not ok then ok, mod = pcall(function() return require(reqName) end) end
    if ok then UtilityModules[reqName] = mod return true end
    return false
end

Callback.Add("Tick", function()
    if UtilityMenu then
        if UtilityMenu.enableActivator:Value() and not UtilityModules["DepressiveActivatorG"] then
            TryLoadOptionalUtility("DepressiveActivatorG")
        end
        if UtilityMenu.enableSmite:Value() and not UtilityModules["DepressiveAutoSmite"] then
            TryLoadOptionalUtility("DepressiveAutoSmite")
        end
    end
end)

local function EnsureChampionUpdated(info)
    if not info or not info.file then return end
    local base = info.file:gsub("%.lua$", "")
    local verFile = base .. ".version"
    DownloadFile(CHAMPIONS_PATH, verFile, GITHUB_CHAMPIONS_BASE)
    local remoteVer = tonumber(ReadFirstLine(CHAMPIONS_PATH .. verFile))
    if not remoteVer then return end
    local localLine = ReadFirstLine(CHAMPIONS_PATH .. info.file)
    local localVer = localLine and tonumber(localLine:match("scriptVersion%s*=%s*([%d%.]+)"))
    if (not FileExists(CHAMPIONS_PATH .. info.file)) or (not localVer) or (remoteVer > localVer) then
        DownloadFile(CHAMPIONS_PATH, info.file, GITHUB_CHAMPIONS_BASE)
        print(string.format("[DepressiveLoader] Updated %s -> %s (remote %.2f)", base, info.file, remoteVer))
        return true
    end
    return false
end

local function RequireChampion(info)
    if not info then return false, "no data" end
    local baseName = info.file:gsub("%.lua$", "")
    -- First try new folder structure
    local ok, mod = pcall(function() return require("Depressive/Champions/" .. baseName) end)
    if ok then
        if type(mod) == "table" then
            return true, mod
        else
            -- Module loaded but didn't return a table (many legacy scripts). Accept and wrap.
            return true, {}
        end
    end
    -- Fallback to root (legacy placement)
    ok, mod = pcall(function() return require(baseName) end)
    if ok then
        if type(mod) == "table" then
            print("[DepressiveLoader] Loaded legacy root champion file: " .. info.file .. " (consider moving to Common/Depressive/Champions)")
            return true, mod
        else
            return true, {}
        end
    end
    return false, mod
end

-- Menu removed (only auto-load logic retained)

local champName = myHero.charName or ""
local module = nil

-- Optional aliases if in-game name differs from file suffix
local NameAlias = NameAlias or {
    Camille = "Camille"
}

local actualName = NameAlias[champName] or champName

-- Build info table on the fly (after actualName is defined)
local dynInfo = { file = "Depressive" .. actualName .. ".lua" }

-- Attempt update + load
if actualName ~= "" then
    if not FileExists(CHAMPIONS_PATH .. dynInfo.file) then
        EnsureChampionUpdated(dynInfo)
    else
        -- Still perform update check to catch newer version
        EnsureChampionUpdated(dynInfo)
    end
    local ok, modOrErr = RequireChampion(dynInfo)
    if ok and type(modOrErr) == "table" then
        module = modOrErr
        if module.Init then pcall(function() module:Init() end) end
        print("[DepressiveLoader] Loaded "..actualName)
    else
        print("[DepressiveLoader] Error loading "..actualName..": "..tostring(modOrErr))
    end
else
    print("[DepressiveLoader] No champion name detected.")
end

if module then
    if module.Tick then
        Callback.Add("Tick", function() pcall(function() module:Tick() end) end)
    end
    if module.Draw then
        Callback.Add("Draw", function() pcall(function() module:Draw() end) end)
    end
end

return {Version = LOADER_VERSION, Module = module}
