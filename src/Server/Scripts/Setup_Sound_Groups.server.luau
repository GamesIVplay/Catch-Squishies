local SoundService = game:GetService("SoundService")

for _, SoundGroup: Instance in SoundService:GetChildren() do
    if not SoundGroup:IsA("SoundGroup") then
        continue
    end

    for _, Sound in SoundGroup:GetDescendants() do
        if not Sound:IsA("Sound") then
            continue
        end

        Sound.SoundGroup = SoundGroup
    end
end
