-- DepressiveAIONext Core Loader
-- Handles automatic updates and champion script dispatch

-- Guard against multiple executions (avoid spam)
if _G.DepressiveAIONextLoaded then
    return
end
_G.DepressiveAIONextLoaded = true
_G.DepressiveAIONextMissingChamps = _G.DepressiveAIONextMissingChamps or {}

local AIOPath = COMMON_PATH .. "DepressiveAIONext/"
local function FileExists(path)
    if FileExist then return FileExist(path) end
    local f = io.open(path, "r"); if f then f:close(); return true end; return false
end
local VersionFile = AIOPath .. "currentVersion.lua"
local UpdateScript = AIOPath .. "newVersion.lua"

-- Auto include update script
if FileExists(UpdateScript) then
    dofile(UpdateScript)
else
    print("[DepressiveAIONext] Missing update script")
end

if not FileExists(VersionFile) then
    print("[DepressiveAIONext] Version file missing; waiting for download")
else
    dofile(VersionFile)
end

local function LoadChampion()
    local champName = myHero.charName
    local champPath = AIOPath .. "Champions/" .. champName .. ".lua"
    if FileExists(champPath) then
        dofile(champPath)
        print("[DepressiveAIONext] Loaded champion module: " .. champName)
    else
        if not _G.DepressiveAIONextMissingChamps[champName] then
            _G.DepressiveAIONextMissingChamps[champName] = true
            print("[DepressiveAIONext] No module for " .. champName)
        end
    end
end

-- Initial attempt after short delay
DelayAction(function() LoadChampion() end, 0.5)

-- Retry loader until update finishes or champion loads
local retryStart = os.clock()
Callback.Add("Tick", function()
    if _G.DepressiveAIONextLoadedChampion then return Callback.Del("Tick", _G.DepressiveAIONextChampionTick) end
    local champName = myHero.charName
    local champPath = AIOPath .. "Champions/" .. champName .. ".lua"
    if FileExists(champPath) then
        LoadChampion()
        _G.DepressiveAIONextLoadedChampion = true
        return
    end
    if _G.DepressiveAIONextUpdated then
        -- Final attempt after updates flagged complete
        if FileExists(champPath) then
            LoadChampion(); _G.DepressiveAIONextLoadedChampion = true; return
        else
            print("[DepressiveAIONext] Champion script still missing after update phase")
            return Callback.Del("Tick", _G.DepressiveAIONextChampionTick)
        end
    end
    if os.clock() - retryStart > 12 then
        print("[DepressiveAIONext] Champion load timeout")
        Callback.Del("Tick", _G.DepressiveAIONextChampionTick)
    end
end)

print("[DepressiveAIONext] Core initialized")
