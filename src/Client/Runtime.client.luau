if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Dumplings = require(ReplicatedStorage.Shared.Modules.Dumplings)
local ExpressivePrompts = require(ReplicatedStorage.Packages.ExpressivePrompts)
local Foods = require(ReplicatedStorage.Shared.Modules.Foods)
local Lassos = require(ReplicatedStorage.Shared.Modules.Lassos)
local Log = require(ReplicatedStorage.Shared.Log)
local Slimes = require(ReplicatedStorage.Shared.Modules.Slimes)
local Start = require(ReplicatedStorage.Shared.Start)

local PRELOAD_BATCH_SIZE = 100

local function Add_Image_To_Preload(Images: { string }, Seen: { [string]: boolean }, Image: any)
    if type(Image) ~= "string" or Image == "" or Seen[Image] then
        return
    end

    Seen[Image] = true
    table.insert(Images, Image)
end

local function Collect_Config_Images(): { string }
    local Images = {}
    local Seen = {}

    for _, LassoData in Lassos.Data do
        Add_Image_To_Preload(Images, Seen, LassoData.Image)
    end

    for _, SlimeData in Slimes do
        if type(SlimeData) == "table" then
            Add_Image_To_Preload(Images, Seen, SlimeData.Image)
        end
    end

    for _, DumplingData in Dumplings do
        if type(DumplingData) == "table" then
            Add_Image_To_Preload(Images, Seen, DumplingData.Image)
        end
    end

    for _, FoodData in Foods.Data do
        Add_Image_To_Preload(Images, Seen, FoodData.Image)
    end

    return Images
end

local function Preload_In_Batches(Assets: { any }): number
    local PreloadedCount = 0

    for StartIndex = 1, #Assets, PRELOAD_BATCH_SIZE do
        local Batch = {}
        local EndIndex = math.min(StartIndex + PRELOAD_BATCH_SIZE - 1, #Assets)

        for Index = StartIndex, EndIndex do
            table.insert(Batch, Assets[Index])
        end

        local Success, Error = pcall(function()
            ContentProvider:PreloadAsync(Batch)
        end)

        if Success then
            PreloadedCount += #Batch
        else
            Log.Warn(`Asset preload batch failed: {Error}`)
        end
    end

    return PreloadedCount
end

task.spawn(function()
    local Assets = game:GetDescendants()
    local Images = Collect_Config_Images()

    for _, Image in Images do
        table.insert(Assets, Image)
    end

    local PreloadedCount = Preload_In_Batches(Assets)

    Log.Info(`{PreloadedCount}/{#Assets} assets preloaded ({#Images} config images)`)
end)

repeat
    local Success = pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
        StarterGui:SetCore("ResetButtonCallback", false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, true)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    end)

    if not Success then
        task.wait(1)
    end
until Success == true

local Systems = {}
local Systems_Folder = script.Parent:FindFirstChild("Systems")

if Systems_Folder then
    for _, ModuleScript in Systems_Folder:GetChildren() do
        if not ModuleScript:IsA("ModuleScript") then
            continue
        end

        table.insert(Systems, require(ModuleScript))
    end
end

ExpressivePrompts.Config.SubTextColor = Color3.fromRGB(165, 242, 2)
ExpressivePrompts.Config.ActionTextFont = Enum.Font.FredokaOne
ExpressivePrompts.Config.ObjectTextFont = Enum.Font.FredokaOne
ExpressivePrompts.Config.ProgressBarTransparency = 0
ExpressivePrompts.Config.ProgressBarColor = Color3.fromRGB(165, 242, 2)
ExpressivePrompts.Config.BackgroundTransparency = 0.3
ExpressivePrompts.Init()
Start(Systems)

require(game:GetService("ReplicatedFirst").Network).ClientLoaded.Fire()
