return {
    Name = "addLasso",
    Aliases = {},
    Description = "Adds and equips a lasso for a player.",
    Group = "Admin",
    Args = {
        {
            Type = "player",
            Name = "player",
            Description = "The player to add the lasso to.",
        },
        {
            Type = "lasso",
            Name = "lasso",
            Description = "The lasso to add.",
        },
    },
}
