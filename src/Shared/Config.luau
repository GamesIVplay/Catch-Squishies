return table.freeze({
    FoodRestockTime = 60 * 5,
    OnboardingFunnelName = "OnboardingV7",
    OnboardingSubeventFunnelName = "OnboardingV7Subevents",
    LassoProgressionFunnelName = "LassoProgressionV1",
    DailyRewardsFunnelName = "DailyRewardsV1",
    PlaytimeRewardsFunnelName = "PlaytimeRewardsV1",
    PlotUpgradeFunnelName = "PlotUpgradesV1",
    SellValueSeconds = 30,
    SquishyInventoryCap = 250,

    Overheads = table.freeze({
        RoamingMaxDistance = 70,
        PlotOwnMaxDistance = 60,
        PlotOtherPlayerMaxDistance = 50,
    }),

    Index = table.freeze({
        ClaimRewardSeconds = 15,
    }),
})
