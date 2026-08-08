local Players = game:GetService("Players")

local RemoteCooldowns = {}

RemoteCooldowns.DefaultSeconds = 0.1

local LastCallByUserId: { [number]: { [string]: number } } = {}

local function Get_Player_Cooldowns(Player: Player): { [string]: number }
    local UserId = Player.UserId
    local Cooldowns = LastCallByUserId[UserId]

    if Cooldowns then
        return Cooldowns
    end

    Cooldowns = {}
    LastCallByUserId[UserId] = Cooldowns

    return Cooldowns
end

function RemoteCooldowns.Allow(Player: Player, RemoteName: string, CooldownSeconds: number?): boolean
    if typeof(Player) ~= "Instance" or not Player:IsA("Player") then
        return false
    end

    if type(RemoteName) ~= "string" or RemoteName == "" then
        return false
    end

    local Now = os.clock()
    local Duration = if type(CooldownSeconds) == "number"
        then math.max(0, CooldownSeconds)
        else RemoteCooldowns.DefaultSeconds
    local Cooldowns = Get_Player_Cooldowns(Player)
    local LastCallAt = Cooldowns[RemoteName]

    if LastCallAt and Now - LastCallAt < Duration then
        return false
    end

    Cooldowns[RemoteName] = Now

    return true
end

Players.PlayerRemoving:Connect(function(Player)
    LastCallByUserId[Player.UserId] = nil
end)

return table.freeze(RemoteCooldowns)
