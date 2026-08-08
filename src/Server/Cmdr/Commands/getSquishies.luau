return {
    Name = "getSquishies",
    Aliases = {},
    Description = "Gives every squishy to a player.",
    Group = "Admin",
    Args = {
        {
            Type = "player",
            Name = "player",
            Description = "The player to give every squishy to.",
        },
        {
            Type = "number",
            Name = "weight",
            Description = "Optional squishy weight.",
            Optional = true,
        },
    },
}
