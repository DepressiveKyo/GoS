local LOADER_VERSION = 1.01
local DEPRESSIVE_PATH = COMMON_PATH .. "Depressive/"
local CHAMPIONS_PATH = DEPRESSIVE_PATH .. "Champions/"
local LOADER_FILE = "DepressiveLoader.lua"
local LOADER_VERSION_FILE = "DepressiveLoader.version"

-- Your real GitHub raw base
local GITHUB_BASE = "https://raw.githubusercontent.com/DepressiveKyo/GoS/main/Common/Depressive/"
local GITHUB_CHAMPIONS_BASE = GITHUB_BASE .. "Champions/"

-- Supported champions (file names inside Champions/)
local Supported = {
        Camille   = {file = "DepressiveCamille.lua"},
        Caitlyn   = {file = "DepressiveCaitlyn.lua"},
        Draven    = {file = "DepressiveDraven.lua"},
        Gwen      = {file = "DepressiveGwen.lua"},
        Hwei      = {file = "DepressiveHwei.lua"},
        Irelia    = {file = "DepressiveIrelia.lua"},
        Jinx      = {file = "DepressiveJinxSimple.lua", alias = "Jinx (Simple)"},
        Rengar    = {file = "DepressiveRengar.lua"},
        Thresh    = {file = "DepressiveThresh.lua"},
        Vayne     = {file = "DepressiveVayne.lua"},
        Zed       = {file = "DepressiveZed.lua"},
        Zeri      = {file = "DepressiveZeri.lua"},
}

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
    if ok and type(mod) == "table" then return true, mod end
    -- Fallback to root (legacy placement)
    ok, mod = pcall(function() return require(baseName) end)
    if ok and type(mod) == "table" then
        print("[DepressiveLoader] Loaded legacy root champion file: " .. info.file .. " (consider moving to Common/Depressive/Champions)")
        return true, mod
    end
    return false, mod
end

local rootMenu
if _G.MenuElement then
    rootMenu = MenuElement({id = "DepressiveLoader", name = "Depressive Loader", type = MENU})
    rootMenu:MenuElement({id = "Info", name = "Info", type = MENU})
    rootMenu.Info:MenuElement({id = "Version", name = string.format("Loader v%.2f", LOADER_VERSION)})
    rootMenu:MenuElement({id = "Champion", name = "Champion", type = MENU})
    local list = {}
    for k,v in pairs(Supported) do list[#list+1] = v.alias or k end
    table.sort(list)
    rootMenu.Champion:MenuElement({id = "Supported", name = "Soportados ("..#list..")", drop = {table.concat(list, ", ")}})
    rootMenu:MenuElement({id = "Settings", name = "Settings", type = MENU})
    rootMenu.Settings:MenuElement({id = "AutoUpdateChamp", name = "Auto-update Champion", value = true})
    rootMenu.Settings:MenuElement({id = "EnableChampion", name = "Enable Champion Logic", value = true})
end

local champName = myHero.charName
local info = Supported[champName]
local module = nil

if info then
    if rootMenu then rootMenu.Info:MenuElement({id = "Status", name = "Status: Preparing..."}) end
    if not FileExists(CHAMPIONS_PATH .. info.file) then
        -- try first-time download into Champions folder
        EnsureChampionUpdated(info)
    elseif rootMenu and rootMenu.Settings.AutoUpdateChamp:Value() then EnsureChampionUpdated(info) end
    local ok, modOrErr = RequireChampion(info)
    if ok and type(modOrErr) == "table" then
        module = modOrErr
        if module.Init and rootMenu then pcall(function() module:Init(rootMenu) end) end
        if rootMenu then
            rootMenu.Info.Status:Remove()
            rootMenu.Info:MenuElement({id = "Status", name = "Status: Loaded "..champName})
        end
        print("[DepressiveLoader] Cargado "..champName)
    else
        if rootMenu then
            rootMenu.Info.Status:Remove()
            rootMenu.Info:MenuElement({id = "Status", name = "Status: Load Error"})
        end
        print("[DepressiveLoader] Error loading "..champName..": "..tostring(modOrErr))
    end
else
    print("[DepressiveLoader] Unsupported champion: "..champName)
    if rootMenu then rootMenu.Info:MenuElement({id = "Status", name = "Estado: No soportado"}) end
end

if module then
    if module.Tick then
        Callback.Add("Tick", function()
            if rootMenu and not rootMenu.Settings.EnableChampion:Value() then return end
            pcall(function() module:Tick() end)
        end)
    end
    if module.Draw then
        Callback.Add("Draw", function()
            if rootMenu and not rootMenu.Settings.EnableChampion:Value() then return end
            pcall(function() module:Draw() end)
        end)
    end
end

return {Version = LOADER_VERSION, Supported = Supported, Module = module}
