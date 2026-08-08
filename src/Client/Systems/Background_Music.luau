local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Log = require(ReplicatedStorage.Shared.Log)
local Phases = require(ReplicatedStorage.Shared.Phases)

local MusicSoundGroupName = "Music"
local MusicStarted = false

local function Get_Music_Sound_Group(): SoundGroup?
    local MusicGroup = SoundService:FindFirstChild(MusicSoundGroupName)

    if MusicGroup and MusicGroup:IsA("SoundGroup") then
        return MusicGroup
    end

    return nil
end

local function Get_Music_Tracks(): { Sound }
    local MusicGroup = Get_Music_Sound_Group()

    if not MusicGroup then
        Log.Warn(`SoundService.{MusicSoundGroupName} SoundGroup was not found`)
        return {}
    end

    local Tracks = {}

    for _, Descendant in MusicGroup:GetDescendants() do
        if Descendant:IsA("Sound") then
            table.insert(Tracks, Descendant)
        end
    end

    return Tracks
end

local function Shuffle<T>(List: { T }): { T }
    local Shuffled = table.clone(List)

    for Index = #Shuffled, 2, -1 do
        local SwapIndex = math.random(1, Index)
        Shuffled[Index], Shuffled[SwapIndex] = Shuffled[SwapIndex], Shuffled[Index]
    end

    return Shuffled
end

local function Stop_And_Reset_Tracks(Tracks: { Sound })
    for _, Track in Tracks do
        Track.Looped = false
        Track:Stop()
        Track.TimePosition = 0
    end
end

local function Play_Music_Loop(InitialTracks: { Sound })
    task.spawn(function()
        local LastPlayed: Sound? = nil
        local Tracks = InitialTracks

        while true do
            if #Tracks == 0 then
                task.wait(5)
                Tracks = Get_Music_Tracks()
                Stop_And_Reset_Tracks(Tracks)
                continue
            end

            local Queue = Shuffle(Tracks)

            if #Queue > 1 and LastPlayed and Queue[1] == LastPlayed then
                Queue[1], Queue[2] = Queue[2], Queue[1]
            end

            for _, Track in Queue do
                if not Track.Parent then
                    continue
                end

                Track.Looped = false
                Track.TimePosition = 0
                Track:Play()
                Track.Ended:Wait()
                LastPlayed = Track
            end

            Tracks = Get_Music_Tracks()
        end
    end)
end

local function Start_Music()
    if MusicStarted then
        return
    end

    MusicStarted = true

    local Tracks = Get_Music_Tracks()

    if #Tracks == 0 then
        Log.Warn(`SoundService.{MusicSoundGroupName} has no music tracks`)
    end

    Stop_And_Reset_Tracks(Tracks)
    Play_Music_Loop(Tracks)
end

return {
    name = script.Name,
    phase = Phases.InitPhases.PostInit,
    system = Start_Music,
    runConditions = {},
}
