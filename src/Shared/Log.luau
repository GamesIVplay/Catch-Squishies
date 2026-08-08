local Log = {}

local function createLogFunction(LevelName, LogFn, DevOnly)
    return function(...)
        if DevOnly and not _G.IN_DEV then
            return
        end

        local ModulePath = debug.info(2, "s")
        local ModuleName = ModulePath:match("[^.]+$")

        LogFn(`[{ModuleName}] {LevelName}:`, ...)
    end
end

Log.Debug = createLogFunction("DEBUG", print, true)
Log.Info = createLogFunction("INFO", print, true)
Log.Warn = createLogFunction("WARN", warn, false)

return Log
