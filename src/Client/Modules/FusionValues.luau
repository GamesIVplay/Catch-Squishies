local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Scope = Fusion.scoped(Fusion)

return table.freeze({
    Cash = Scope:Value(0),
    MoneyMultiplier = Scope:Value(1),
    FriendBoost = Scope:Value(0),
    Lasso = Scope:Value("Basic"),
    OwnedLassos = Scope:Value({ "Basic" }),
    OwnedSquishies = Scope:Value({}),
    OwnedFood = Scope:Value({}),
    FoodStock = Scope:Value({}),
    LastFoodRestock = Scope:Value(0),
    HotbarSlots = Scope:Value({}),
    Index = Scope:Value({}),
    ClaimedIndexRewards = Scope:Value({}),
    DailyStart = Scope:Value(0),
    ClaimedDailyRewards = Scope:Value({}),
    TutorialStep = Scope:Value(1),
    TutorialStepReceived = Scope:Value(false),
    PlaytimeStart = Scope:Value(0),
    ClaimedPlaytimeRewards = Scope:Value({}),
    EventState = Scope:Value({
        NextEventAt = 0,
        ActiveEvents = {},
    }),
    PlotSquishies = Scope:Value({}),
    EquippedInventorySlot = Scope:Value(nil),
    EquippedInventoryItemId = Scope:Value(nil),
    ProfileDataReceived = Scope:Value(false),
})
