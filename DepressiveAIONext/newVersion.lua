-- DepressiveAIONext Auto-Updater (improved)
local BASE_URL          = "https://raw.githubusercontent.com/DepressiveKyo/GoS/main/DepressiveAIONext/"
local VERSION_URL       = BASE_URL .. "currentVersion.lua"
local LOCAL_PATH        = COMMON_PATH .. "DepressiveAIONext/"
local LOCAL_VERSIONFILE = LOCAL_PATH .. "currentVersion.lua"

local function FileExists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function Download(url, path, cb)
    DownloadFileAsync(url, path, function()
    if cb then cb(true) end
    end)
end

local function DeepCopy(tbl)
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k,v in pairs(tbl) do out[k] = DeepCopy(v) end
    return out
end

local function LoadLocalVersions()
    if FileExists(LOCAL_VERSIONFILE) then
        local ok, err = pcall(dofile, LOCAL_VERSIONFILE)
        if not ok then
            print("[DepressiveAIONext] Error reading local versions: "..tostring(err))
            return { Core = {Version = 0}, Champions = {} }
        end
        if type(Data) == "table" then
            local copy = DeepCopy(Data)
            Data = nil -- limpiamos para reutilizar variable con remoto
            return copy
        end
    end
    return { Core = {Version = 0}, Champions = {} }
end

local function LoadRemoteVersions(cb)
    Download(VERSION_URL, LOCAL_VERSIONFILE, function()
        if not FileExists(LOCAL_VERSIONFILE) then
            print("[DepressiveAIONext] Could not download currentVersion.lua")
            if cb then cb(nil) end
            return
        end
        local ok, err = pcall(dofile, LOCAL_VERSIONFILE)
        if not ok then
            print("[DepressiveAIONext] Error loading remote versions: "..tostring(err))
            if cb then cb(nil) end
            return
        end
        if cb then cb(Data) end
    end)
end

local function UpdateCore(remote, localData)
    if remote.Core and remote.Core.Version and (remote.Core.Version > (localData.Core.Version or 0)) then
        print(string.format("[DepressiveAIONext] Core update %0.2f -> %0.2f", localData.Core.Version or 0, remote.Core.Version))
    -- Here you could download extra core files if you split them later.
    end
end

local function UpdateChampions(remote, localData)
    if not remote.Champions then return end
    _G.DepressiveAIONextPending = _G.DepressiveAIONextPending or {count = 0}
    for champ, info in pairs(remote.Champions) do
        local localEntry = localData.Champions[champ]
        local needs = (not localEntry) or (info.Version or 0) > (localEntry.Version or 0)
        if needs then
            local fileName = string.format("Champions/%s.lua", champ)
            print(string.format("[DepressiveAIONext] Downloading %s (v%0.2f)", champ, info.Version or 0))
            _G.DepressiveAIONextPending.count = _G.DepressiveAIONextPending.count + 1
            Download(BASE_URL .. fileName, LOCAL_PATH .. fileName, function()
                _G.DepressiveAIONextPending.count = math.max(0, (_G.DepressiveAIONextPending.count or 1) - 1)
            end)
        end
    end
end

local function StartUpdate()
    local localData = LoadLocalVersions()
    LoadRemoteVersions(function(remoteData)
        if not remoteData then return end
        UpdateCore(remoteData, localData)
        UpdateChampions(remoteData, localData)
        -- Poll until downloads finish then signal ready
        local startTime = os.clock()
        Callback.Add("Tick", function()
            if (not _G.DepressiveAIONextPending) or (_G.DepressiveAIONextPending.count == 0) or (os.clock() - startTime > 10) then
                print("[DepressiveAIONext] Update check complete")
                _G.DepressiveAIONextUpdated = true
                return Callback.Del("Tick", _G.LastCallback)
            end
        end)
    end)
end

StartUpdate()
