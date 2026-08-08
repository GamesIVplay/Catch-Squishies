local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local MarketPlaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Log = require("../Log")

local Camera = workspace.CurrentCamera

local Util = {}

function Util.Wait_For_Child_And_Destroy(Parent, ToDestroy, Timeout)
    local Instance = Parent:WaitForChild(ToDestroy, Timeout)
    if not Instance then
        return
    end
    Instance:Destroy()
end

function Util.IsEven(Number)
    return Util.IsInteger(Number) and Number % 2 == 0
end

function Util.IsPositive(Number)
    return Number > 0
end

function Util.IsInteger(Number)
    return Number % 1 == 0
end

function Util.Is_Positive_Integer(Number)
    return Util.IsPositive(Number) and Util.IsInteger(Number)
end

function Util.Is_Non_Negative(Number)
    return Number >= 0
end

function Util.Clone_Children_To(Inst, Target)
    for _, Child in Inst:GetChildren() do
        Child:Clone().Parent = Target
    end
end

function Util.Clone_Children_To_And_Rename(Inst, Target, Name)
    for _, Child in Inst:GetChildren() do
        local Clone = Child:Clone()
        Clone.Name = Name
        Clone.Parent = Target
    end
end

function Util.Destroy_Descendents_With_Name(Inst, Name, Delay)
    Delay = Delay or 0
    for _, Descendent in Inst:GetDescendants() do
        if Descendent.Name == Name then
            Descendent:Destroy()
            Debris:AddItem(Descendent, Delay)
        end
    end
end

function Util.CopyTable(T, Deep)
    if not Deep then
        return (table.clone(T))
    end

    local function DeepCopy(Tbl)
        local TCopy = table.clone(Tbl)
        for Index, Value in TCopy do
            if type(Value) == "table" then
                TCopy[Index] = DeepCopy(Value)
            end
        end
        return TCopy
    end

    return (DeepCopy(T))
end

function Util.TablesAreEqual(T1, T2)
    if T1 == T2 then
        return true
    end
    if type(T1) ~= "table" or type(T2) ~= "table" then
        return false
    end

    for I, V in next, T1 do
        local Other = T2[I]
        if type(V) == "table" and type(Other) == "table" then
            if not Util.TablesAreEqual(V, Other) then
                return false
            end
        else
            if Other ~= V then
                return false
            end
        end
    end

    for I, V in next, T2 do
        local Other = T1[I]
        if type(V) == "table" and type(Other) == "table" then
            if not Util.TablesAreEqual(V, Other) then
                return false
            end
        else
            if Other ~= V then
                return false
            end
        end
    end

    return true
end

function Util.Tween_Model_Scale(StartScale, EndScale, TweenInfo, Model)
    local Elapsed = 0
    local TweenConnection

    local function OnStep(DeltaTime)
        Elapsed = math.min(Elapsed + DeltaTime, TweenInfo.Time)
        local Alpha = TweenService:GetValue(Elapsed / TweenInfo.Time, TweenInfo.EasingStyle, TweenInfo.EasingDirection)
        local Scale = StartScale + Alpha * (EndScale - StartScale)

        Model:ScaleTo(Scale)

        if Elapsed == TweenInfo.Time then
            TweenConnection:Disconnect()
        end
    end

    TweenConnection = RunService.Heartbeat:Connect(OnStep)

    return TweenConnection
end

function Util.Format_Number_With_Commas(Number)
    local String = tostring(math.floor(Number))
    local Formatted = String:reverse():gsub("(%d%d%d)", "%1,"):reverse()

    if Formatted:sub(1, 1) == "," then
        Formatted = Formatted:sub(2)
    end

    return Formatted
end

function Util.Seconds_To_Days(Seconds)
    return math.floor(Seconds / 86400)
end

function Util.Seconds_To_Hours(Seconds)
    return math.floor((Seconds % 86400) / 3600)
end

function Util.Seconds_To_Minutes(Seconds)
    return math.floor((Seconds % 3600) / 60)
end

function Util.Minutes_To_Seconds(Minutes)
    return math.floor(Minutes * 60)
end

function Util.Hours_To_Seconds(Hours)
    return math.floor(Hours * 3600)
end

function Util.Format_Seconds(Seconds)
    local Hours = Util.Seconds_To_Hours(Seconds)
    local minutes = Util.Seconds_To_Minutes(Seconds)
    local seconds = Seconds % 60
    return string.format("%02i:%02i:%02i", Hours, minutes, seconds)
end

function Util.Seconds_Until_End_Of_Week(Seconds)
    local CurrentTime = Seconds or os.time()
    local CurrentDate = os.date("!*t", CurrentTime)

    local DaysUntilEnd = (7 - ((CurrentDate.wday - 2) % 7))

    local EndDate = {
        year = CurrentDate.year,
        month = CurrentDate.month,
        day = CurrentDate.day + DaysUntilEnd,
        hour = 23,
        min = 59,
        sec = 59,
        isdst = false,
    }

    local EndOfWeek = os.time(EndDate)

    return EndOfWeek - CurrentTime
end

function Util.BreakdownTime(Seconds)
    return {
        Days = Util.Seconds_To_Days(Seconds),
        Hours = Util.Seconds_To_Hours(Seconds),
        Minutes = Util.Seconds_To_Minutes(Seconds),
        Seconds = Seconds % 60,
    }
end

function Util.Get_Weekly_Countdown_String()
    local SecondsLeft = Util.Seconds_Until_End_Of_Week()
    local Data = Util.BreakdownTime(SecondsLeft)
    return string.format("%dd %02dh %02dm %02ds", Data.Days, Data.Hours, Data.Minutes, Data.Seconds)
end

function Util.Get_Random_Color()
    local R = math.random(0, 255)
    local G = math.random(0, 255)
    local B = math.random(0, 255)
    return Color3.fromRGB(R, G, B)
end

function Util.LerpColor(C1, C2, T)
    return Color3.new(C1.R + (C2.R - C1.R) * T, C1.G + (C2.G - C1.G) * T, C1.B + (C2.B - C1.B) * T)
end

function Util.GetColorAtAlpha(Sequence, Alpha)
    local Keypoints = Sequence.Keypoints
    for I = 1, #Keypoints - 1 do
        local A = Keypoints[I]
        local B = Keypoints[I + 1]
        if Alpha >= A.Time and Alpha <= B.Time then
            local Range = B.Time - A.Time
            local T = (Alpha - A.Time) / Range
            return Util.LerpColor(A.Value, B.Value, T)
        end
    end
    return Keypoints[#Keypoints].Value
end

function Util.Lerp(Start, End, Percent)
    return Start + (End - Start) * Percent
end

function Util.ApplyGradientToText(Text, Sequence)
    local Result = ""
    local Length = #Text

    if Length == 1 then
        local Color = Util.GetColorAtAlpha(Sequence, 0.5)
        return string.format(
            "<font color='rgb(%d, %d, %d)'>%s</font>",
            math.floor(Color.R * 255),
            math.floor(Color.G * 255),
            math.floor(Color.B * 255),
            Text
        )
    end

    for I = 1, Length do
        local Alpha = (I - 1) / (Length - 1)
        local Color = Util.GetColorAtAlpha(Sequence, Alpha)
        local R, G, B = math.floor(Color.R * 255), math.floor(Color.G * 255), math.floor(Color.B * 255)
        local Char = Text:sub(I, I)
        Result ..= string.format("<font color='rgb(%d, %d, %d)'>%s</font>", R, G, B, Char)
    end

    return Result
end

function Util.ToggleLowGraphics(Enabled)
    if Enabled then
        for _, Inst in workspace:GetDescendants() do
            if not CollectionService:HasTag(Inst, "LowGraphics") then
                CollectionService:AddTag(Inst, "LowGraphics")
            end

            if Inst:IsA("BasePart") then
                Inst:SetAttribute("OriginalMaterial", Inst.Material)
                Inst.CastShadow = false
                Inst.Material = Enum.Material.SmoothPlastic
            elseif Inst:IsA("Decal") then
                Inst:SetAttribute("OriginalTransparency", Inst.Transparency)
                Inst.Transparency = 1
            end
        end
    else
        for _, Inst in CollectionService:GetTagged("LowGraphics") do
            CollectionService:RemoveTag(Inst, "LowGraphics")

            if Inst:IsA("BasePart") then
                local OriginalMaterial = (Inst:GetAttribute("OriginalMaterial"))
                if OriginalMaterial then
                    Inst.Material = OriginalMaterial
                    Inst:SetAttribute("OriginalMaterials", nil)
                end
                Inst.CastShadow = true
            elseif Inst:IsA("Decal") then
                local OriginalTransparency = (Inst:GetAttribute("OriginalTransparency"))
                if OriginalTransparency then
                    Inst.Transparency = OriginalTransparency
                    Inst:SetAttribute("OriginalTransparency", nil)
                end
            end
        end
    end
end

function Util.Number_To_Roman_Numerical(Number)
    if Number <= 0 then
        return "None"
    end

    local RomanNumerals = {
        [1000] = "M",
        [900] = "CM",
        [500] = "D",
        [400] = "CD",
        [100] = "C",
        [90] = "XC",
        [50] = "L",
        [40] = "XL",
        [10] = "X",
        [9] = "IX",
        [5] = "V",
        [4] = "IV",
        [1] = "I",
    }

    local Result = ""
    local Remaining = math.floor(Number)
    local Values = table.create(13)

    for Value in RomanNumerals do
        table.insert(Values, Value)
    end
    table.sort(Values, function(a, b)
        return a > b
    end)

    for _, Value in Values do
        while Remaining >= Value do
            Result ..= RomanNumerals[Value]
            Remaining -= Value
        end
    end

    return Result
end

function Util.Cleanup(Task)
    if typeof(Task) == "Instance" then
        Task:Destroy()
    elseif typeof(Task) == "RBXScriptConnection" then
        Task:Disconnect()
    elseif type(Task) == "thread" then
        coroutine.close(Task :: any)
    elseif type(Task) == "function" then
        Task()
    elseif type(Task) == "table" then
        local HasDisconnect = type(Task.Disconnect) == "function"
        local HasDisconnectAll = type(Task.DisconnectAll) == "function"

        if HasDisconnect then
            Task:Disconnect()
        elseif HasDisconnectAll then
            Task:DisconnectAll()
        else
            error("Unsupported table Task type")
        end
    else
        error("Unsupported Task type: " .. typeof(Task))
    end
end

local PlayerInfoCache = {}

function Util.Get_Player_Info(UserId): { Name: string, Image: string }
    if PlayerInfoCache[UserId] then
        return PlayerInfoCache[UserId]
    end
    local PlayerName = Players:GetNameFromUserIdAsync(UserId)
    local Image = Players:GetUserThumbnailAsync(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    PlayerInfoCache[UserId] = { Name = PlayerName, Image = Image }
    return PlayerInfoCache[UserId]
end

function Util.Fraction_To_Percent(Numerator, Denominator)
    if Denominator == 0 then
        return "Undefined (division by zero)"
    end
    local Percent = math.floor((Numerator / Denominator) * 100)
    return string.format("%d%%", Percent)
end

local GraphemesPerColorLoop = 16
local ColorSaturation = 0.75

function Util.Get_Rainbow_Text(Text: string)
    local RainbowText = ""
    local CurrentColorIndex = Random.new():NextNumber() * GraphemesPerColorLoop
    for First, Last in utf8.graphemes(Text) do
        local Grapheme = Text:sub(First, Last)
        local IsColoredGrapheme = Grapheme ~= " "

        RainbowText ..= if not IsColoredGrapheme
            then Grapheme
            else ('<font color="#%s">%s</font>'):format(
                Color3.fromHSV(CurrentColorIndex / GraphemesPerColorLoop % 1, ColorSaturation, 1):ToHex(),
                Grapheme
            )

        if IsColoredGrapheme then
            CurrentColorIndex += 1
        end
    end
    return RainbowText
end

function Util.Raycast_From_Mouse(Mouse_Position: Vector2, Distance: number, RayCastParams: RaycastParams)
    local ViewportSize = Camera.ViewportSize
    local Theta = (Camera.FieldOfView / 2) * (math.pi / 180)

    local AR = ViewportSize.X / ViewportSize.Y
    local L = -Camera.NearPlaneZ * math.tan(Theta)
    local Half_Size = ViewportSize / 2

    Mouse_Position = (Mouse_Position - Half_Size) / Half_Size
    Mouse_Position = Vector2.new(Mouse_Position.X * AR, Mouse_Position.Y)

    local Front = Vector3.FromAxis(Enum.Axis.Z) * Camera.NearPlaneZ
    local Right = Vector3.FromAxis(Enum.Axis.X) * Mouse_Position.x * L
    local Up = Vector3.FromAxis(Enum.Axis.Y) * -Mouse_Position.y * L

    local Localized = Camera.CFrame:VectorToWorldSpace(Front + Right + Up)
    local LocalizedUnit = Localized.Unit

    return workspace:Raycast(Camera.CFrame.Position, LocalizedUnit * Distance, RayCastParams)
end

function Util.Get_Gamepass_Info(Id: number)
    local Attempts = 0

    local Success, Info
    repeat
        Success, Info = pcall(function()
            return MarketPlaceService:GetProductInfoAsync(Id, Enum.InfoType.GamePass)
        end)

        if Success then
            return Info
        else
            Attempts = Attempts + 1

            warn("Attempt " .. Attempts .. " failed to retrieve gamepass info")
            task.wait(1)
        end
    until Success or Attempts >= 3

    if not Success or not Info then
        Log.Warn("Failed to retrieve gamepass info after 3 attempts")
    end

    return
end

function Util.Get_Product_Info(Id: number)
    local Attempts = 0

    local Success, Info
    repeat
        Success, Info = pcall(function()
            return MarketPlaceService:GetProductInfoAsync(Id, Enum.InfoType.Product)
        end)

        if Success then
            return Info
        else
            Attempts = Attempts + 1

            warn("Attempt " .. Attempts .. " failed to retrieve product info")
            task.wait(1)
        end
    until Success or Attempts >= 3

    if not Success or not Info then
        Log.Warn("Failed to retrieve product info after 3 attempts")
    end

    return
end

function Util.RoundToDecimals(Num, NumDecimals)
    local mult = 10 ^ (NumDecimals or 0)
    return math.floor(Num * mult + 0.5) / mult
end

local Abbreviations = {
    "K",
    "M",
    "B",
    "T",
    "QD",
    "QT",
    "SXT",
    "SEPT",
    "OCT",
    "NON",
    "DEC",
    "UDEC",
    "DDEC",
}

function Util.Abbreviate_Number(Number: number, Decimals: number?)
    if Number < 1000 then
        return tostring(Number)
    end

    Decimals = Decimals or 1

    local Digits = math.floor(math.log10(Number)) + 1
    local Index = math.min(#Abbreviations, math.floor((Digits - 1) / 3))
    local Visible = Number / math.pow(10, Index * 3 - Decimals :: number)
    local Suffix = Abbreviations[Index] --[[.. "+"]]

    local Front = Visible / math.pow(10, Decimals :: number)
    local Back = Visible % math.pow(10, Decimals :: number)

    if Decimals > 0 and Back > 0 then
        return string.format("%i.%0." .. tostring(Decimals) .. "i%s", Front, Back, Suffix)
    else
        return string.format("%i%s", Front, Suffix)
    end
end

function Util.Format_Percent(Percent: number): string
    Percent = math.floor(Percent + 0.5)

    if Percent > 0 then
        return `+{Percent}%`
    elseif Percent < 0 then
        return `{Percent}%`
    else
        return "0%"
    end
end

function Util.Is_Us_Dst(UtcTime: number): boolean
    local Year = tonumber(os.date("!%Y", UtcTime))

    local function GetNthSunday(Month: number, N: number)
        local FirstOfMonth = os.time({
            year = Year,
            month = Month,
            day = 1,
            hour = 0,
            min = 0,
            sec = 0,
            isdst = false,
        })

        local FirstWeekday = tonumber(os.date("!%w", FirstOfMonth)) -- 0 = Sunday
        local FirstSundayOffset = (7 - FirstWeekday) % 7
        local Day = 1 + FirstSundayOffset + (7 * (N - 1))

        return os.time({
            year = Year,
            month = Month,
            day = Day,
            hour = 2,
            min = 0,
            sec = 0,
            isdst = false,
        })
    end

    local DstStart = GetNthSunday(3, 2) -- March (2nd Sunday)
    local DstEnd = GetNthSunday(11, 1) -- November (1st Sunday)

    return UtcTime >= DstStart and UtcTime < DstEnd
end

function Util.Get_Est_Offset(UtcTime: number?): number
    local NowUtc = UtcTime or os.time()
    return Util.Is_Us_Dst(NowUtc) and (-4 * 3600) or (-5 * 3600)
end

function Util.Get_Seconds_Until_Next_Interval_Est(IntervalMinutes: number, UtcTime: number?): number
    local IntervalSeconds = IntervalMinutes * 60
    local NowUtc = UtcTime or os.time()

    local EstTime = NowUtc + Util.Get_Est_Offset(NowUtc)
    local Remainder = EstTime % IntervalSeconds

    if Remainder == 0 then
        return 0
    end

    return IntervalSeconds - Remainder
end

return Util
