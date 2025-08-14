-- DepressiveAIONext Core Loader
-- Handles automatic updates and champion script dispatch

-- Guard against multiple executions (avoid spam)
if _G.DepressiveAIONextLoaded then
    return
end
_G.DepressiveAIONextLoaded = true
_G.DepressiveAIONextMissingChamps = _G.DepressiveAIONextMissingChamps or {}

local AIOPath = COMMON_PATH .. "DepressiveAIONext/"
local VersionFile = AIOPath .. "currentVersion.lua"
local UpdateScript = AIOPath .. "newVersion.lua"

-- Auto include update script
if FileExist and FileExist(UpdateScript) then
    dofile(UpdateScript)
else
    print("[DepressiveAIONext] Missing update script")
end

if not FileExist or not FileExist(VersionFile) then
    print("[DepressiveAIONext] Version file missing; waiting for download")
else
    dofile(VersionFile)
end

local function LoadChampion()
    local champName = myHero.charName
    local champPath = AIOPath .. "Champions/" .. champName .. ".lua"
    if FileExist and FileExist(champPath) then
        dofile(champPath)
        print("[DepressiveAIONext] Loaded champion module: " .. champName)
    else
        if not _G.DepressiveAIONextMissingChamps[champName] then
            _G.DepressiveAIONextMissingChamps[champName] = true
            print("[DepressiveAIONext] No module for " .. champName)
        end
    end
end

DelayAction(function()
    LoadChampion()
end, 0.5)

print("[DepressiveAIONext] Core initialized")
