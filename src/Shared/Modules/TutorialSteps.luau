local Config = require(script.Parent.Parent.Config)

local TutorialSteps = {}

TutorialSteps.Version = 7
TutorialSteps.StartStep = 1
TutorialSteps.CompleteStep = 5
TutorialSteps.OnboardingFunnelName = Config.OnboardingFunnelName
TutorialSteps.OnboardingSubeventFunnelName = Config.OnboardingSubeventFunnelName
TutorialSteps.CompleteFunnelStep = 6

TutorialSteps.CatchFirst = 1
TutorialSteps.PlaceFirst = 2
TutorialSteps.CollectCash = 3
TutorialSteps.BuyNextLasso = 4
TutorialSteps.Complete = 5

TutorialSteps.EquipLasso = 6
TutorialSteps.CatchStrong = 7
TutorialSteps.PlaceStrong = 8
TutorialSteps.CollectCashAgain = 9
TutorialSteps.BuyFood = 10
TutorialSteps.FeedStrong = 11
TutorialSteps.EquipHammer = 12
TutorialSteps.PickupOld = 13
TutorialSteps.SellOld = 14

TutorialSteps.FirstRole = "First"
TutorialSteps.StrongRole = "Strong"
TutorialSteps.NextLasso = "Metal"
TutorialSteps.FeedName = "Farmers Feed"
TutorialSteps.BlockedMessage = "Complete the tutorial first"
TutorialSteps.TargetUserIdAttribute = "TutorialTargetUserId"
TutorialSteps.TargetStepAttribute = "TutorialTargetStep"
TutorialSteps.StationaryTargetAttribute = "TutorialStationaryTarget"

TutorialSteps.OnboardingFunnelSteps = {
    [1] = "Player Joined",
    [2] = "Catch First Squishy",
    [3] = "Place First Squishy",
    [4] = "Collect Cash",
    [5] = "Buy Metal Lasso",
    [6] = "Tutorial Complete",
}

TutorialSteps.CompletedActionFunnelSteps = {
    [TutorialSteps.CatchFirst] = 2,
    [TutorialSteps.PlaceFirst] = 3,
    [TutorialSteps.CollectCash] = 4,
    [TutorialSteps.BuyNextLasso] = 5,
}

TutorialSteps.Subevents = {
    ReachedFirstTutorialSquishy = {
        Step = 1,
        Name = "Reached First Tutorial Squishy",
    },
    ReachedPlotFirst = {
        Step = 2,
        Name = "Reached Plot First",
    },
    OpenedLassoShop = {
        Step = 3,
        Name = "Opened Lasso Shop",
    },
    ReachedStrongTutorialSquishy = {
        Step = 4,
        Name = "Reached Strong Tutorial Squishy",
    },
    ReachedPlotStrong = {
        Step = 5,
        Name = "Reached Plot Strong",
    },
    OpenedFoodShop = {
        Step = 6,
        Name = "Opened Food Shop",
    },
    EquippedFarmersFeed = {
        Step = 7,
        Name = "Equipped Farmers Feed",
    },
    ReachedFeedTarget = {
        Step = 8,
        Name = "Reached Feed Target",
    },
}

TutorialSteps.Steps = {
    [1] = { Text = "Catch your first Squishy." },
    [2] = { Text = "Go to your pen and place it." },
    [3] = { Text = "Collect cash from your Squishy." },
    [4] = { Text = "Buy the Metal Lasso." },
    [5] = { Text = nil },
}

function TutorialSteps.Get_Text(Step: number): string?
    local Data = TutorialSteps.Steps[Step]

    return if Data then Data.Text else nil
end

function TutorialSteps.Get_Funnel_Name(Step: number): string
    local Name = TutorialSteps.OnboardingFunnelSteps[Step]

    return if type(Name) == "string" then Name else `Onboarding Step {Step}`
end

function TutorialSteps.Get_Completed_Action_Funnel_Step(Step: number): number?
    Step = TutorialSteps.Normalize_Step(Step)

    return TutorialSteps.CompletedActionFunnelSteps[Step]
end

function TutorialSteps.Get_Subevent_Data(SubeventName: any): { Step: number, Name: string }?
    if type(SubeventName) ~= "string" then
        return nil
    end

    local Data = TutorialSteps.Subevents[SubeventName]

    return if type(Data) == "table" then Data else nil
end

function TutorialSteps.Normalize_Step(Step: number?): number
    Step = tonumber(Step) or TutorialSteps.StartStep

    return math.clamp(math.floor(Step), TutorialSteps.StartStep, TutorialSteps.CompleteStep)
end

function TutorialSteps.Is_Complete(Step: number?): boolean
    return TutorialSteps.Normalize_Step(Step) >= TutorialSteps.CompleteStep
end

function TutorialSteps.Is_Catch_Step(Step: number?): boolean
    Step = TutorialSteps.Normalize_Step(Step)

    return Step == TutorialSteps.CatchFirst or Step == TutorialSteps.CatchStrong
end

function TutorialSteps.Is_Catch_Rarity_Allowed(Step: number?, Rarity: any): boolean
    Step = TutorialSteps.Normalize_Step(Step)

    if Step == TutorialSteps.CatchFirst then
        return Rarity == "Common"
    end

    if Step == TutorialSteps.CatchStrong then
        return Rarity == "Rare" or Rarity == "Epic"
    end

    return false
end

function TutorialSteps.Is_Tutorial_Visible_Rarity(Rarity: any): boolean
    return Rarity == "Common" or Rarity == "Rare"
end

function TutorialSteps.Is_Tutorial_Rarity_Visible_For_Step(Step: number?, Rarity: any): boolean
    Step = TutorialSteps.Normalize_Step(Step)

    if Step >= TutorialSteps.CatchStrong then
        return Rarity == "Common" or Rarity == "Rare" or Rarity == "Epic"
    end

    return TutorialSteps.Is_Tutorial_Visible_Rarity(Rarity)
end

return table.freeze(TutorialSteps)
