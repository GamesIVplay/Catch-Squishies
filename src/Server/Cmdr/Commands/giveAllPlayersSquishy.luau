return {
    Name = "giveAllPlayersSquishy",
    Aliases = {},
    Description = "Gives a squishy to every player in this server.",
    Group = "Admin",
    Args = {
        {
            Type = "squishy",
            Name = "squishy",
            Description = "The squishy to give.",
        },
        {
            Type = "primaryMutation",
            Name = "primaryMutation",
            Description = "Optional primary mutation.",
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
