export type NotificationType = "Success" | "Info" | "Warning" | "Error" | "Reward" | "Announcement"

export type NotificationData = {
    Text: string,
    Duration: number?,
    Type: NotificationType,
    Gradient: string?,
}

local Pending: { NotificationData } = {}

local LocalNotifications = {}

function LocalNotifications.Push(Text: string, Type: NotificationType?, Duration: number?, Gradient: string?)
    if Text == "" then
        return
    end

    table.insert(Pending, {
        Text = Text,
        Type = Type or "Info",
        Duration = Duration,
        Gradient = Gradient,
    })
end

function LocalNotifications.Pop_All(): { NotificationData }
    if #Pending <= 0 then
        return {}
    end

    local Result = Pending

    Pending = {}

    return Result
end

return table.freeze(LocalNotifications)
