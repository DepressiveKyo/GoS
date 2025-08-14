local ok, loader = pcall(function() return require("Depressive/DepressiveLoader") end)
if not ok then
    PrintChat("[Depressive AIO] Error cargando DepressiveLoader: "..tostring(loader))
    return { Loaded = false }
end

return {
    Loaded = loader.Module ~= nil,
    Loader = loader
}

