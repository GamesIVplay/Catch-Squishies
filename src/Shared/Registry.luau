local Log = require("./Log")
local World = require("./World")

local Data = {}

local Registry = {}

function Registry.Define(Category, Key, Entity)
    if not Data[Category] then
        Data[Category] = {}
    end
    if Data[Category][Key] then
        Log.Warn("Overwriting existing entity in category: " .. Category .. ", key: " .. tostring(Key))
    end
    Data[Category][Key] = Entity
end

function Registry.Get(Category, Key)
    if not Data[Category] then
        return nil
    end
    return Data[Category][Key]
end

function Registry.Undefine(Category, Key)
    if not Data[Category] then
        Log.Warn("Attempted to undefine a non-existent category: " .. Category)
        return
    end
    Data[Category][Key] = nil
end

function Registry.Delete(Category, Key)
    local Entity = Registry.Get(Category, Key)

    if not Entity then
        return
    end

    Registry.Undefine(Category, Key)

    World:delete(Entity)

    if next(Data[Category]) == nil then
        Data[Category] = nil
    end
end

return Registry
