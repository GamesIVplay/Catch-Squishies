return {
    Name = "stopGlobalEvent",
    Aliases = {},
    Description = "Stops one event or every active event on every server.",
    Group = "Admin",
    Args = {
        {
            Type = "event",
            Name = "event",
            Description = "Optional event to stop. Leave blank to stop all.",
            Optional = true,
        },
    },
}
