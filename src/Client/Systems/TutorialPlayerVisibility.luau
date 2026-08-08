local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Phases = require(ReplicatedStorage.Shared.Phases)

type OriginalState = {
    LocalTransparencyModifier: number?,
    Transparency: number?,
    Enabled: boolean?,
    CanCollide: boolean?,
    CanTouch: boolean?,
    CanQuery: boolean?,
}

local SCAN_INTERVAL = 0.25

local OriginalStates: { [Instance]: OriginalState } = setmetatable({}, { __mode = "k" }) :: any
local HiddenCharacters: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local LastScanAt = -math.huge

local function Save_State(InstanceToSave: Instance, State: OriginalState)
    if OriginalStates[InstanceToSave] then
        return
    end

    OriginalStates[InstanceToSave] = State
end

local function Has_Enabled_Property(InstanceToCheck: Instance): boolean
    return InstanceToCheck:IsA("LayerCollector")
        or InstanceToCheck:IsA("BillboardGui")
        or InstanceToCheck:IsA("SurfaceGui")
        or InstanceToCheck:IsA("ParticleEmitter")
        or InstanceToCheck:IsA("Trail")
        or InstanceToCheck:IsA("Beam")
        or InstanceToCheck:IsA("Light")
        or InstanceToCheck:IsA("Highlight")
end

local function Hide_Instance(InstanceToHide: Instance)
    if InstanceToHide:IsA("BasePart") then
        Save_State(InstanceToHide, {
            LocalTransparencyModifier = InstanceToHide.LocalTransparencyModifier,
            CanCollide = InstanceToHide.CanCollide,
            CanTouch = InstanceToHide.CanTouch,
            CanQuery = InstanceToHide.CanQuery,
        })
        InstanceToHide.LocalTransparencyModifier = 1
        InstanceToHide.CanCollide = false
        InstanceToHide.CanTouch = false
        InstanceToHide.CanQuery = false
    elseif InstanceToHide:IsA("Decal") or InstanceToHide:IsA("Texture") then
        Save_State(InstanceToHide, {
            Transparency = InstanceToHide.Transparency,
        })
        InstanceToHide.Transparency = 1
    elseif Has_Enabled_Property(InstanceToHide) then
        local EnabledInstance = InstanceToHide :: any

        Save_State(InstanceToHide, {
            Enabled = EnabledInstance.Enabled,
        })
        EnabledInstance.Enabled = false
    end
end

local function Restore_Instance(InstanceToRestore: Instance)
    local State = OriginalStates[InstanceToRestore]

    if not State then
        return
    end

    if InstanceToRestore:IsA("BasePart") then
        if State.LocalTransparencyModifier ~= nil then
            InstanceToRestore.LocalTransparencyModifier = State.LocalTransparencyModifier
        end

        if State.CanCollide ~= nil then
            InstanceToRestore.CanCollide = State.CanCollide
        end

        if State.CanTouch ~= nil then
            InstanceToRestore.CanTouch = State.CanTouch
        end

        if State.CanQuery ~= nil then
            InstanceToRestore.CanQuery = State.CanQuery
        end
    elseif (InstanceToRestore:IsA("Decal") or InstanceToRestore:IsA("Texture")) and State.Transparency ~= nil then
        InstanceToRestore.Transparency = State.Transparency
    elseif Has_Enabled_Property(InstanceToRestore) and State.Enabled ~= nil then
        (InstanceToRestore :: any).Enabled = State.Enabled
    end

    OriginalStates[InstanceToRestore] = nil
end

local function Set_Character_Hidden(Character: Model, Hidden: boolean)
    if Hidden then
        HiddenCharacters[Character] = true
        Hide_Instance(Character)
    else
        HiddenCharacters[Character] = nil
        Restore_Instance(Character)
    end

    for _, Descendant in Character:GetDescendants() do
        if Hidden then
            Hide_Instance(Descendant)
        else
            Restore_Instance(Descendant)
        end
    end
end

local function Restore_All_Hidden_Characters()
    for Character in HiddenCharacters do
        if Character.Parent then
            Set_Character_Hidden(Character, false)
        else
            HiddenCharacters[Character] = nil
        end
    end
end

return {
    name = script.Name,
    phase = Phases.Runservice.Update,
    system = function()
        local Now = os.clock()

        if Now - LastScanAt < SCAN_INTERVAL then
            return
        end

        LastScanAt = Now

        Restore_All_Hidden_Characters()
    end,
    runConditions = {},
}
