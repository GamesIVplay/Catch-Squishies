local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventMutations = require(ReplicatedStorage.Shared.Modules.EventMutations)
local ModelVFX = require(script.Parent.ModelVFX)

local EventMutationVFX = {}

local VFX_ATTRIBUTE = "EventMutationVFX"
local VFX_EVENT_ATTRIBUTE = "EventMutation"
local VFX_KEY_ATTRIBUTE = "EventMutationVFXKey"
local EVENT_ATTACHMENT_PRIORITY = {
    "EventMutationAttachment",
    "MutationAttachment",
    "Attachment",
    "SquishyOverheadAttachment",
    "WalkingSquishyOverheadAttachment",
}

local function Get_Vfx_Folder(): Folder?
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Folder = Assets and Assets:FindFirstChild("EventsMutations")

    return if Folder and Folder:IsA("Folder") then Folder else nil
end

local function Clear_Old_Vfx(Attachment: Attachment)
    for _, Child in Attachment:GetChildren() do
        if Child:GetAttribute(VFX_ATTRIBUTE) == true then
            Child:Destroy()
        end
    end
end

function EventMutationVFX.Sync(Model: Model, MutationList: any)
    local NormalizedList = EventMutations.NormalizeList(MutationList)
    local VfxScale = ModelVFX.GetModelVfxScale(Model)
    local Key = `{EventMutations.EncodeAttribute(NormalizedList)}:{math.floor(VfxScale * 100 + 0.5)}`

    if Model:GetAttribute(VFX_KEY_ATTRIBUTE) == Key then
        return
    end

    local Attachment = ModelVFX.FindTargetAttachment(Model, EVENT_ATTACHMENT_PRIORITY)

    if not Attachment then
        return
    end

    local VfxFolder = Get_Vfx_Folder()

    Clear_Old_Vfx(Attachment)

    if VfxFolder then
        for _, EventName in NormalizedList do
            local EventFolder = VfxFolder:FindFirstChild(EventName)

            if not EventFolder then
                continue
            end

            for _, VfxObject in EventFolder:GetChildren() do
                local Clone = VfxObject:Clone()
                Clone.Name = `EventMutationVFX_{EventName}_{VfxObject.Name}`
                Clone:SetAttribute(VFX_ATTRIBUTE, true)
                Clone:SetAttribute(VFX_EVENT_ATTRIBUTE, EventName)
                ModelVFX.ScaleInstance(Clone, VfxScale)
                ModelVFX.Enable(Clone)
                Clone.Parent = Attachment
            end
        end
    end

    Model:SetAttribute(VFX_KEY_ATTRIBUTE, Key)
end

return table.freeze(EventMutationVFX)
