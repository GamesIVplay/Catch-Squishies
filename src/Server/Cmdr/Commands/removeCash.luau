return {
    Name = "removeCash",
    Aliases = {},
    Description = "Removes cash from a player.",
    Group = "Admin",
    Args = {
        {
            Type = "player",
            Name = "player",
            Description = "The player to remove cash from.",
        },
        {
            Type = "positiveInteger",
            Name = "amount",
            Description = "The amount of cash to remove.",
        },
    },
}
