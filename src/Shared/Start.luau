_G.IN_DEV = false
_G.JECS_DEBUG = false
_G.Mock = false

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Phases = require("./Phases")
local Scheduler = require("./Scheduler")
local World = require("./World")

local Jabby = require(ReplicatedStorage.Packages.Jabby)

local Log = require("./Log")

local function Setup_Jabby()
    Jabby.set_check_function(function(Player)
        if Player.UserId == 3439160531 then
            return true
        else
            return false
        end
    end)

    if RunService:IsClient() then
        local client = Jabby.obtain_client()

        local function create_widget(_, state)
            if state ~= Enum.UserInputState.Begin then
                return
            end
            client.spawn_app(client.apps.home, nil)
        end

        ContextActionService:BindAction("Open Jabby Home", create_widget, false, Enum.KeyCode.F4)
    end

    Jabby.register({
        applet = Jabby.applets.world,
        name = "Catch Squishies",
        configuration = {
            world = World,
        },
    } :: any)
end

return function(Systems)
    if #Systems > 0 then
        Scheduler:addSystems(Systems)
            :run(Phases.InitPhases.PreInit)
            :run(Phases.InitPhases.Init)
            :run(Phases.InitPhases.PostInit)
    else
        Log.Warn("There are 0 systems")
    end

    Setup_Jabby()
end
