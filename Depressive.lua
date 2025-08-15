local AIO_FOLDER      = "DepressiveAIONext"
local BASE_URL        = "https://raw.githubusercontent.com/DepressiveKyo/GoS/main/" .. AIO_FOLDER .. "/"
local LOCAL_PATH      = COMMON_PATH .. AIO_FOLDER .. "/"
local CORE_FILE       = LOCAL_PATH .. "Core.lua"
local UPDATE_FILE     = LOCAL_PATH .. "newVersion.lua"
local VERSION_FILE    = LOCAL_PATH .. "currentVersion.lua"

local needed = {
    [CORE_FILE] = "Core.lua",
    [UPDATE_FILE] = "newVersion.lua",
    [VERSION_FILE] = "currentVersion.lua", -- will be downloaded on the fly if missing
}

local function FileExists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local pendingDownloads = 0
local function Download(url, path, cb)
    pendingDownloads = pendingDownloads + 1
    DownloadFileAsync(url, path, function()
        pendingDownloads = pendingDownloads - 1
        if cb then cb(path) end
    end)
end

local function EnsureDir()
    -- Directory creation not required here (GoS common path should exist); no temp file creation.
end

local function CheckAndDownload()
    EnsureDir()
    for fullPath, shortName in pairs(needed) do
        if not FileExists(fullPath) then
            print(string.format("[Depressive Loader] Downloading %s...", shortName))
            Download(BASE_URL .. shortName, fullPath, function()
                print(string.format("[Depressive Loader] %s ready", shortName))
            end)
        end
    end
end

local function SafeDofile(path)
    local ok, err = pcall(dofile, path)
    if not ok then
    print("[Depressive Loader] Error loading " .. path .. ": " .. tostring(err))
        return false
    end
    return true
end

local function TryLoadCore()
    if _G.DepressiveAIONextLoaded then
        Callback.Del("Tick", TryLoadCore)
        return
    end
    if pendingDownloads > 0 then return end
    if not FileExists(CORE_FILE) then return end
    if SafeDofile(CORE_FILE) then
        if _G.DepressiveAIONextLoaded then
            print("[Depressive Loader] Core loaded successfully")
        end
        Callback.Del("Tick", TryLoadCore)
    end
end

print("[Depressive Loader] Starting verification...")
CheckAndDownload()

-- Retry each tick until core is available
Callback.Add("Tick", TryLoadCore)

-- Fallback: force attempt after 3 seconds
DelayAction(function()
    TryLoadCore()
    if pendingDownloads == 0 and not FileExists(CORE_FILE) then
    print("[Depressive Loader] Could not obtain Core.lua (check your repo)")
    end
end, 3)

-- Note: Core.lua itself will run the versioning & champion update system.
