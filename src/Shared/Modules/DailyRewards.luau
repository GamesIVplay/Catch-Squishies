type Reward = {
    Type: "Squishy",
    Kind: "Slime" | "Dumpling",
    Name: string,
    Time: number,
}

local DAILY_REWARD_SECONDS = 12 * 60 * 60

local DailyRewards: { [number]: Reward } = {}

DailyRewards[1] = {
    Type = "Squishy",
    Kind = "Slime",
    Name = "Shinobi",
    Time = DAILY_REWARD_SECONDS,
}

DailyRewards[2] = {
    Type = "Squishy",
    Kind = "Dumpling",
    Name = "Panda",
    Time = DAILY_REWARD_SECONDS,
}

DailyRewards[3] = {
    Type = "Squishy",
    Kind = "Slime",
    Name = "Honey",
    Time = DAILY_REWARD_SECONDS,
}

DailyRewards[4] = {
    Type = "Squishy",
    Kind = "Dumpling",
    Name = "Owl",
    Time = DAILY_REWARD_SECONDS,
}

DailyRewards[5] = {
    Type = "Squishy",
    Kind = "Slime",
    Name = "King",
    Time = DAILY_REWARD_SECONDS,
}

DailyRewards[6] = {
    Type = "Squishy",
    Kind = "Dumpling",
    Name = "Strawberry",
    Time = DAILY_REWARD_SECONDS,
}

DailyRewards[7] = {
    Type = "Squishy",
    Kind = "Dumpling",
    Name = "Crystal",
    Time = DAILY_REWARD_SECONDS,
}

DailyRewards[8] = {
    Type = "Squishy",
    Kind = "Dumpling",
    Name = "Bunny",
    Time = DAILY_REWARD_SECONDS,
}

return table.freeze(DailyRewards)
