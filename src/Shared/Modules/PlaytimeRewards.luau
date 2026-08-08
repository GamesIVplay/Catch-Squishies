type Reward = {
    Time: number,
    Type: "Cash" | "Squishy",
    Amount: number?,
    Kind: "Slime" | "Dumpling"?,
    Name: string?,
}

local PlaytimeRewards: { [number]: Reward } = {}

PlaytimeRewards[1] = {
    Time = 3 * 60,
    Type = "Cash",
    Amount = 500,
}

PlaytimeRewards[2] = {
    Time = 5 * 60,
    Type = "Cash",
    Amount = 5_000,
}

PlaytimeRewards[3] = {
    Time = 10 * 60,
    Type = "Squishy",
    Kind = "Slime",
    Name = "Double",
}

PlaytimeRewards[4] = {
    Time = 15 * 60,
    Type = "Cash",
    Amount = 25_000,
}

PlaytimeRewards[5] = {
    Time = 25 * 60,
    Type = "Squishy",
    Kind = "Dumpling",
    Name = "Cloud",
}

PlaytimeRewards[6] = {
    Time = 35 * 60,
    Type = "Cash",
    Amount = 50_000,
}

PlaytimeRewards[7] = {
    Time = 45 * 60,
    Type = "Cash",
    Amount = 75_000,
}

PlaytimeRewards[8] = {
    Time = 60 * 60,
    Type = "Squishy",
    Kind = "Dumpling",
    Name = "Cyber",
}

PlaytimeRewards[9] = {
    Time = 75 * 60,
    Type = "Squishy",
    Kind = "Slime",
    Name = "Spike",
}

PlaytimeRewards[10] = {
    Time = 90 * 60,
    Type = "Cash",
    Amount = 100_000,
}

PlaytimeRewards[11] = {
    Time = 105 * 60,
    Type = "Cash",
    Amount = 300_000,
}

PlaytimeRewards[12] = {
    Time = 120 * 60,
    Type = "Squishy",
    Kind = "Dumpling",
    Name = "Unicorn",
}

return table.freeze(PlaytimeRewards)
