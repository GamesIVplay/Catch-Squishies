return {
    Name = "startGlobalEvent",
    Aliases = {},
    Description = "Starts an event on every server.",
    Group = "Admin",
    Args = {
        {
            Type = "event",
            Name = "event",
            Description = "The event to start.",
        },
        {
            Type = "number",
            Name = "duration",
            Description = "Optional duration in seconds.",
            Optional = true,
        },
    },
}
