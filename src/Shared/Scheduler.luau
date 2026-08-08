local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Planck = require(ReplicatedStorage.Packages.Planck)
local Scheduler = Planck.Scheduler

local PlanckJabby = require(ReplicatedStorage.Packages.PlanckJabby)
local PlanckRunService = require(ReplicatedStorage.Packages.PlanckRunService)

local RunServicePlugin = PlanckRunService.Plugin.new()
local JabbyPlugin = PlanckJabby.new()

local World = require("./World")

return Scheduler.new(World):addPlugin(JabbyPlugin):addPlugin(RunServicePlugin)
