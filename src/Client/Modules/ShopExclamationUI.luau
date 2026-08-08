local TweenService = game:GetService("TweenService")

local EXCLAMATION_BOUNCE_INTERVAL = 2.4
local EXCLAMATION_BOUNCE_SCALE = 1.18

local MainGui: ScreenGui? = nil
local Exclamation: GuiObject? = nil
local LastExclamationBounce = 0
local ExclamationBounceActive = false
local DidOpenShop = false

local function Tween(InstanceToTween: Instance, Info: TweenInfo, Properties)
    local CreatedTween = TweenService:Create(InstanceToTween, Info, Properties)
    CreatedTween:Play()

    return CreatedTween
end

local function Get_Or_Create_Scale(GuiObject: GuiObject, ScaleName: string): UIScale
    local Scale = GuiObject:FindFirstChild(ScaleName)

    if Scale and Scale:IsA("UIScale") then
        return Scale
    end

    Scale = Instance.new("UIScale")
    Scale.Name = ScaleName
    Scale.Scale = 1
    Scale.Parent = GuiObject

    return Scale
end

local function Get_Hud_Shop_Exclamation(): GuiObject?
    if not MainGui then
        return nil
    end

    local Hud = MainGui:FindFirstChild("Hud Frame")
    local Buttons = Hud and Hud:FindFirstChild("Buttons")
    local ShopButton = Buttons and Buttons:FindFirstChild("Shop")
    local Candidate = ShopButton and ShopButton:FindFirstChild("Exclamation")

    if Candidate and Candidate:IsA("GuiObject") then
        return Candidate
    end

    return nil
end

local function Bounce_Exclamation()
    if not Exclamation or ExclamationBounceActive then
        return
    end

    ExclamationBounceActive = true

    local Scale = Get_Or_Create_Scale(Exclamation, "ExclamationBounceScale")

    Tween(Scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = EXCLAMATION_BOUNCE_SCALE,
    })

    task.delay(0.16, function()
        if Exclamation and Exclamation.Parent then
            Tween(Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Scale = 1,
            })
        end

        task.delay(0.18, function()
            ExclamationBounceActive = false
        end)
    end)
end

local function Update_Exclamation()
    if not Exclamation or not Exclamation.Parent then
        Exclamation = Get_Hud_Shop_Exclamation()
    end

    if not Exclamation then
        return
    end

    if DidOpenShop then
        Exclamation.Visible = false
        return
    end

    Exclamation.Visible = true

    local Now = os.clock()

    if Now - LastExclamationBounce >= EXCLAMATION_BOUNCE_INTERVAL then
        LastExclamationBounce = Now
        Bounce_Exclamation()
    end
end

local ShopExclamationUI = {}

function ShopExclamationUI.Initialize(Gui: ScreenGui)
    MainGui = Gui
    Exclamation = Get_Hud_Shop_Exclamation()
    LastExclamationBounce = 0
    ExclamationBounceActive = false
    DidOpenShop = false

    if Exclamation then
        Exclamation.Visible = true
    end
end

function ShopExclamationUI.MarkShopOpened()
    DidOpenShop = true

    if not Exclamation or not Exclamation.Parent then
        Exclamation = Get_Hud_Shop_Exclamation()
    end

    if Exclamation then
        Exclamation.Visible = false
    end
end

function ShopExclamationUI.Step()
    Update_Exclamation()
end

return table.freeze(ShopExclamationUI)
