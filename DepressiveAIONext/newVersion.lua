-- DepressiveAIONext Auto-Updater (improved)
local BASE_URL          = "https://raw.githubusercontent.com/DepressiveKyo/GoS/main/DepressiveAIONext/"
local VERSION_URL       = BASE_URL .. "currentVersion.lua"
local LOCAL_PATH        = COMMON_PATH .. "DepressiveAIONext/"
local LOCAL_VERSIONFILE = LOCAL_PATH .. "currentVersion.lua"
local CHAMPIONS_PATH    = LOCAL_PATH .. "Champions/"

-- Cache de resultados de FileExists
local fileExistsCache = {}

local function FileExists(path)
    -- Usar FileExist si está disponible (más rápido)
    if FileExist then return FileExist(path) end
    
    -- Verificar cache primero
    if fileExistsCache[path] ~= nil then
        return fileExistsCache[path]
    end
    
    local f = io.open(path, "r")
    local exists = f ~= nil
    if f then f:close() end
    
    -- Cachear resultado
    fileExistsCache[path] = exists
    return exists
end

local function Download(url, path, cb)
    DownloadFileAsync(url, path, function()
        if cb then cb(true) end
    end)
end

-- Lee la versión local desde el archivo .version del campeón
local function ReadLocalChampionVersion(champName)
    local versionFile = CHAMPIONS_PATH .. champName .. ".version"
    if not FileExists(versionFile) then
        return 0
    end
    
    local f = io.open(versionFile, "r")
    if not f then return 0 end
    
    local content = f:read("*all")
    f:close()
    
    if content then
        -- Limpiar espacios y saltos de línea
        content = content:gsub("%s+", "")
        local version = tonumber(content)
        return version or 0
    end
    return 0
end

-- Escribe la versión en el archivo .version del campeón
local function WriteLocalChampionVersion(champName, version)
    local versionFile = CHAMPIONS_PATH .. champName .. ".version"
    local f = io.open(versionFile, "w")
    if f then
        f:write(tostring(version))
        f:close()
        -- Invalidar cache
        fileExistsCache[versionFile] = true
        return true
    end
    return false
end

-- Optimización: DeepCopy con límite de profundidad para evitar stack overflow
local function DeepCopy(tbl, depth)
    depth = depth or 0
    if depth > 10 then -- Límite de seguridad
        return tbl
    end
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k,v in pairs(tbl) do 
        out[k] = DeepCopy(v, depth + 1) 
    end
    return out
end

local function LoadRemoteVersions(cb)
    Download(VERSION_URL, LOCAL_VERSIONFILE, function()
        -- Invalidar cache cuando se descarga el archivo
        fileExistsCache[LOCAL_VERSIONFILE] = nil
        
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

local function UpdateCore(remote)
    if remote.Core and remote.Core.Version then
        local localCoreVersion = ReadLocalChampionVersion("Core")
        if remote.Core.Version > localCoreVersion then
            print(string.format("[DepressiveAIONext] Core update %0.2f -> %0.2f", localCoreVersion, remote.Core.Version))
            WriteLocalChampionVersion("Core", remote.Core.Version)
        end
    end
end

local function UpdateChampions(remote)
    if not remote.Champions then return end
    _G.DepressiveAIONextPending = _G.DepressiveAIONextPending or {count = 0}
    
    for champ, info in pairs(remote.Champions) do
        local remoteVersion = info.Version or 0
        local localVersion = ReadLocalChampionVersion(champ)
        local champPath = CHAMPIONS_PATH .. champ .. ".lua"
        
        -- Verificar si necesita actualización:
        -- 1. La versión remota es diferente a la local
        -- 2. El archivo .lua no existe
        local needsUpdate = (remoteVersion ~= localVersion) or (not FileExists(champPath))
        
        if needsUpdate then
            if remoteVersion ~= localVersion then
                print(string.format("[DepressiveAIONext] Updating %s (v%.2f -> v%.2f)", champ, localVersion, remoteVersion))
            else
                print(string.format("[DepressiveAIONext] Downloading %s (v%.2f)", champ, remoteVersion))
            end
            
            _G.DepressiveAIONextPending.count = _G.DepressiveAIONextPending.count + 1
            local fileName = "Champions/" .. champ .. ".lua"
            
            Download(BASE_URL .. fileName, champPath, function()
                -- Actualizar el archivo .version local con la nueva versión
                WriteLocalChampionVersion(champ, remoteVersion)
                -- Invalidar cache cuando se descarga un archivo
                fileExistsCache[champPath] = true
                _G.DepressiveAIONextPending.count = math.max(0, (_G.DepressiveAIONextPending.count or 1) - 1)
            end)
        end
    end
end

local function StartUpdate()
    LoadRemoteVersions(function(remoteData)
        if not remoteData then
            print("[DepressiveAIONext] Remote version check failed")
            _G.DepressiveAIONextUpdated = true
            return
        end
        UpdateCore(remoteData)
        UpdateChampions(remoteData)
        -- Poll until downloads finish then signal ready
        local startTime = os.clock()
        local lastCheckTime = 0
        local checkInterval = 0.1 -- Verificar cada 100ms en lugar de cada tick (optimización)
        local updaterTick
        updaterTick = function()
            -- Throttle: no verificar en cada tick
            local currentTime = os.clock()
            if currentTime - lastCheckTime < checkInterval then
                return
            end
            lastCheckTime = currentTime
            
            if (not _G.DepressiveAIONextPending) or (_G.DepressiveAIONextPending.count == 0) or (currentTime - startTime > 10) then
                if not _G.DepressiveAIONextUpdatePrinted then
                    print("[DepressiveAIONext] Update check complete")
                    _G.DepressiveAIONextUpdatePrinted = true
                end
                _G.DepressiveAIONextUpdated = true
                Callback.Del("Tick", updaterTick)
            end
        end
        Callback.Add("Tick", updaterTick)
    end)
end

StartUpdate()
