local LightingService = game:GetService("Lighting")

local Lighting = {}

local LIGHTING_PROPERTIES = table.freeze({
    "Ambient",
    "Brightness",
    "ColorShift_Bottom",
    "ColorShift_Top",
    "EnvironmentDiffuseScale",
    "EnvironmentSpecularScale",
    "GlobalShadows",
    "OutdoorAmbient",
    "ShadowSoftness",
    "ClockTime",
    "GeographicLatitude",
    "ExposureCompensation",
})

function Lighting.Save(Name: string): Configuration
    local Config = Instance.new("Configuration")
    Config.Name = Name

    for _, PropertyName in LIGHTING_PROPERTIES do
        Config:SetAttribute(PropertyName, LightingService[PropertyName])
    end

    return Config
end

function Lighting.Load(Config: Configuration)
    for _, Inst in LightingService:GetChildren() do
        Inst:Destroy()
    end

    for _, Inst in Config:GetChildren() do
        Inst:Clone().Parent = LightingService
    end

    for _, PropertyName in LIGHTING_PROPERTIES do
        local Value = Config:GetAttribute(PropertyName)

        if Value ~= nil then
            LightingService[PropertyName] = Value
        end
    end
end

return table.freeze(Lighting)
