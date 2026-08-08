return {
    Name = "setCash",
    Aliases = {},
    Description = "Sets a player's cash.",
    Group = "Admin",
    Args = {
        {
            Type = "player",
            Name = "player",
            Description = "The player to set cash for.",
        },
        {
            Type = "nonNegativeInteger",
            Name = "amount",
            Description = "The cash value to set.",
        },
    },
}
