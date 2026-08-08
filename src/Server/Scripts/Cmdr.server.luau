local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Admins = require(ServerScriptService.Server.Modules.Admins)
local Cmdr = require(ReplicatedStorage.Packages.cmdr)

local Server = ServerScriptService.Server
local CmdrFolder = Server:WaitForChild("Cmdr")

Cmdr:RegisterHook("BeforeRun", function(Context)
    if Context.Group == "Help" then
        return nil
    end

    local Executor = Context.Executor

    if typeof(Executor) == "Instance" and Executor:IsA("Player") and Admins.Is_Admin(Executor) then
        return nil
    end

    return "You are not allowed to use this command."
end)

Cmdr:RegisterDefaultCommands({ "Help" })
Cmdr:RegisterTypesIn(CmdrFolder:WaitForChild("Types"))
Cmdr:RegisterCommandsIn(CmdrFolder:WaitForChild("Commands"))
