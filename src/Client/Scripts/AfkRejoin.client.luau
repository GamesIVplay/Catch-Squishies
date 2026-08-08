if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local Local_Player = Players.LocalPlayer

local AFK_LIMIT = 15 * 60

local LastInputTime = os.clock()

local function Mark_Active()
    LastInputTime = os.clock()
end

UserInputService.InputBegan:Connect(Mark_Active)
UserInputService.InputChanged:Connect(Mark_Active)
UserInputService.TouchStarted:Connect(Mark_Active)

RunService.RenderStepped:Connect(function()
    if UserInputService:GetMouseDelta().Magnitude > 0 then
        Mark_Active()
    end
end)

task.spawn(function()
    while true do
        task.wait(5)

        if os.clock() - LastInputTime >= AFK_LIMIT then
            pcall(function()
                TeleportService:Teleport(game.PlaceId, Local_Player)
            end)
            break
        end
    end
end)
