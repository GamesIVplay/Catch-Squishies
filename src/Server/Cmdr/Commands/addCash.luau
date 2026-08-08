return {
    Name = "addCash",
    Aliases = {},
    Description = "Adds cash to a player.",
    Group = "Admin",
    Args = {
        {
            Type = "player",
            Name = "player",
            Description = "The player to add cash to.",
        },
        {
            Type = "positiveInteger",
            Name = "amount",
            Description = "The amount of cash to add.",
        },
    },
}
