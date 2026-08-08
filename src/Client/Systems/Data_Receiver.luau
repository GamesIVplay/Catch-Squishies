local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedFirst.Network)

local FusionValues = require(script.Parent.Parent.Modules.FusionValues)
local Phases = require(ReplicatedStorage.Shared.Phases)

local Data_Bindings = {
    { Name = "Cash", Stream = Network.CashChanged, Target = FusionValues.Cash },
    { Name = "MoneyMultiplier", Stream = Network.MoneyMultiplierChanged, Target = FusionValues.MoneyMultiplier },
    { Name = "FriendBoost", Stream = Network.FriendBoostChanged, Target = FusionValues.FriendBoost },
    { Name = "Lasso", Stream = Network.LassoChanged, Target = FusionValues.Lasso },
    { Name = "OwnedLassos", Stream = Network.OwnedLassosChanged, Target = FusionValues.OwnedLassos },
    { Name = "OwnedSquishies", Stream = Network.OwnedSquishiesChanged, Target = FusionValues.OwnedSquishies },
    { Name = "OwnedFood", Stream = Network.OwnedFoodChanged, Target = FusionValues.OwnedFood },
    { Name = "FoodStock", Stream = Network.FoodStockChanged, Target = FusionValues.FoodStock },
    { Name = "LastFoodRestock", Stream = Network.LastFoodRestockChanged, Target = FusionValues.LastFoodRestock },
    { Name = "EventState", Stream = Network.EventStateChanged, Target = FusionValues.EventState },
    { Name = "HotbarSlots", Stream = Network.HotbarSlotsChanged, Target = FusionValues.HotbarSlots },
    { Name = "Index", Stream = Network.IndexChanged, Target = FusionValues.Index },
    {
        Name = "ClaimedIndexRewards",
        Stream = Network.ClaimedIndexRewardsChanged,
        Target = FusionValues.ClaimedIndexRewards,
    },
    { Name = "DailyStart", Stream = Network.DailyStartChanged, Target = FusionValues.DailyStart },
    {
        Name = "ClaimedDailyRewards",
        Stream = Network.ClaimedDailyRewardsChanged,
        Target = FusionValues.ClaimedDailyRewards,
    },
    {
        Name = "TutorialStep",
        Stream = Network.TutorialStepChanged,
        Target = FusionValues.TutorialStep,
        Received = FusionValues.TutorialStepReceived,
    },
    { Name = "PlaytimeStart", Stream = Network.PlaytimeStartChanged, Target = FusionValues.PlaytimeStart },
    {
        Name = "ClaimedPlaytimeRewards",
        Stream = Network.ClaimedPlaytimeRewardsChanged,
        Target = FusionValues.ClaimedPlaytimeRewards,
    },
}

local Received_Fields = {}
local Received_Field_Count = 0
local Profile_Data_Received = false

local function Apply_Data(Target, Data)
    if type(Target) == "table" and type(Target.set) == "function" then
        Target:set(Data)
    end
end

local function Bind_Stream(Stream, Target): boolean
    if type(Stream) ~= "table" or type(Stream.Iter) ~= "function" then
        return false
    end

    local Received_Data = false

    for _, Data in Stream.Iter() do
        Apply_Data(Target, Data)
        Received_Data = true
    end

    return Received_Data
end

local function Mark_Field_Received(Field_Name: string)
    if Received_Fields[Field_Name] then
        return
    end

    Received_Fields[Field_Name] = true
    Received_Field_Count += 1
end

local function Update_Profile_Data_Received()
    if Profile_Data_Received or Received_Field_Count < #Data_Bindings then
        return
    end

    Profile_Data_Received = true
    FusionValues.ProfileDataReceived:set(true)
end

local function Receive_Data()
    for _, Binding in Data_Bindings do
        local Received_Data = Bind_Stream(Binding.Stream, Binding.Target)

        if Received_Data then
            Mark_Field_Received(Binding.Name)

            if Binding.Received and type(Binding.Received.set) == "function" then
                Binding.Received:set(true)
            end
        end
    end

    Update_Profile_Data_Received()
end

return {
    name = script.Name,
    phase = Phases.Runservice.First,
    system = function()
        Receive_Data()
    end,
    runConditions = {},
}
