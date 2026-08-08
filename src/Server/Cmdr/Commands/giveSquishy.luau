return {
    Name = "giveSquishy",
    Aliases = {},
    Description = "Adds a squishy to a player's inventory.",
    Group = "Admin",
    Args = {
        {
            Type = "player",
            Name = "player",
            Description = "The player to give the squishy to.",
        },
        {
            Type = "squishy",
            Name = "squishy",
            Description = "The squishy to give.",
        },
        {
            Type = "primaryMutation",
            Name = "primaryMutation",
            Description = "Optional primary mutation. Use Random for a normal roll or Normal for no mutation.",
            Optional = true,
        },
        {
            Type = "number",
            Name = "weight",
            Description = "Optional squishy weight.",
            Optional = true,
        },
    },
}
