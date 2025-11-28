-- DepressiveAIONext Core Loader
-- Handles automatic updates and champion script dispatch

-- Guard against multiple executions (avoid spam)
if _G.DepressiveAIONextLoaded then
    return
end
_G.DepressiveAIONextLoaded = true
_G.DepressiveAIONextMissingChamps = _G.DepressiveAIONextMissingChamps or {}

local AIOPath = COMMON_PATH .. "DepressiveAIONext/"
-- Cache de resultados de FileExists
local fileExistsCache = {}

local function FileExists(path)
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

local VersionFile = AIOPath .. "currentVersion.lua"
local UpdateScript = AIOPath .. "newVersion.lua"

-- Auto include update script
if FileExists(UpdateScript) then
    dofile(UpdateScript)
else
    print("[DepressiveAIONext] Missing update script")
    _G.DepressiveAIONextUpdated = true
end

if not FileExists(VersionFile) then
    print("[DepressiveAIONext] Version file missing; waiting for download")
else
    dofile(VersionFile)
end

-- Cachear nombre del campeón y ruta para evitar recalcular
local cachedChampName = nil
local cachedChampPath = nil

local function LoadChampion()
    -- Cachear nombre del campeón (no cambia durante la partida)
    if not cachedChampName then
        cachedChampName = myHero.charName
        cachedChampPath = AIOPath .. "Champions/" .. cachedChampName .. ".lua"
    end
    
    if FileExists(cachedChampPath) then
        local ok, err = pcall(dofile, cachedChampPath)
        if ok then
            print("[DepressiveAIONext] Loaded champion module: " .. cachedChampName)
        else
            print("[DepressiveAIONext] Error loading champion module: " .. tostring(err))
        end
    else
        if not _G.DepressiveAIONextMissingChamps[cachedChampName] then
            _G.DepressiveAIONextMissingChamps[cachedChampName] = true
            print("[DepressiveAIONext] No module for " .. cachedChampName)
        end
    end
end

-- Initial attempt removed to wait for updates
-- DelayAction(function() LoadChampion() end, 0.5)

-- Retry loader until update finishes or champion loads
local retryStart = os.clock()
local maxRetryDuration = 60 -- extended window to allow late file arrival
local lastCheckTime = 0
local checkInterval = 0.1 -- Verificar cada 100ms en lugar de cada tick (optimización)

local championTick
championTick = function()
    if _G.DepressiveAIONextLoadedChampion then
        Callback.Del("Tick", championTick)
        return
    end

    -- Enforce update check completion
    if not _G.DepressiveAIONextUpdated then
        if os.clock() - retryStart > 15 then
            print("[DepressiveAIONext] Update timeout - forcing load")
            _G.DepressiveAIONextUpdated = true
        else
            return
        end
    end
    
    -- Throttle: no verificar en cada tick, solo cada cierto intervalo
    local currentTime = os.clock()
    if currentTime - lastCheckTime < checkInterval then
        return
    end
    lastCheckTime = currentTime
    
    -- Usar valores cacheados
    if not cachedChampName then
        cachedChampName = myHero.charName
        cachedChampPath = AIOPath .. "Champions/" .. cachedChampName .. ".lua"
    end
    
    if FileExists(cachedChampPath) then
        LoadChampion()
        _G.DepressiveAIONextLoadedChampion = true
        Callback.Del("Tick", championTick)
        return
    end
    
    if _G.DepressiveAIONextUpdated and not _G.DepressiveAIONextMissingAfterUpdatePrinted then
        print("[DepressiveAIONext] Champion script still missing after update phase (will keep retrying)")
        _G.DepressiveAIONextMissingAfterUpdatePrinted = true
    end
    
    if currentTime - retryStart > maxRetryDuration then
        if not _G.DepressiveAIONextChampionTimeoutPrinted then
            print("[DepressiveAIONext] Champion load timeout ("..cachedChampName..")")
            _G.DepressiveAIONextChampionTimeoutPrinted = true
        end
        Callback.Del("Tick", championTick)
    end
end
Callback.Add("Tick", championTick)

print("[DepressiveAIONext] Core initialized")
