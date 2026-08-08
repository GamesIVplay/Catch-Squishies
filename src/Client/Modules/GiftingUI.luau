local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedFirst.Network)

local RobuxProducts = require(ReplicatedStorage.Shared.Modules.RobuxProducts)
local Util = require(ReplicatedStorage.Shared.Modules.Util)

local LocalPlayer = Players.LocalPlayer

local GENERATED_ATTRIBUTE = "GeneratedGiftPlayer"
local GIFT_BUTTON_BOUND_ATTRIBUTE = "GiftButtonBound"

local GIFT_PRODUCT_OVERRIDES = {
    VoidLasso = "VoidLassoGift",
}

local MainGui: ScreenGui? = nil
local BindButtonMotion: ((GuiButton) -> ())? = nil
local IsUiBlocked: (() -> boolean)? = nil
local OpenFrame: ((string, boolean?) -> ())? = nil
local CurrentProductKey: string? = nil
local PendingGiftPrompts: { [string]: boolean } = {}
local PlayerListBound = false

local function Find_By_Path(Root: Instance?, Path: { string }): Instance?
    local Current = Root

    for _, Name in Path do
        if not Current then
            return nil
        end

        Current = Current:FindFirstChild(Name)
    end

    return Current
end

local function Get_Frames(): Instance?
    return MainGui and MainGui:FindFirstChild("Frames") or nil
end

local function Get_Gift_Frame(): GuiObject?
    local Frames = Get_Frames()
    local GiftFrame = Frames and Frames:FindFirstChild("Gifting")

    return if GiftFrame and GiftFrame:IsA("GuiObject") then GiftFrame else nil
end

local function Get_Lasso_Content(): Instance?
    local Frames = Get_Frames()
    local LassoShop = Frames and Frames:FindFirstChild("LassoShop")

    return LassoShop and (LassoShop:FindFirstChild("Content") or LassoShop:FindFirstChild("content")) or nil
end

local function Get_Food_Content(): Instance?
    local Frames = Get_Frames()
    local FoodShop = Frames and Frames:FindFirstChild("FoodShop")

    return FoodShop and (FoodShop:FindFirstChild("content") or FoodShop:FindFirstChild("Content")) or nil
end

local function Set_Text(Container: Instance, LabelName: string, Text: string)
    local Label = Container:FindFirstChild(LabelName, true)

    if Label and Label:IsA("TextLabel") then
        Label.Text = Text
    end
end

local function Set_Player_Image(Container: Instance, Image: string)
    local Display = Container:FindFirstChild("Display", true)
    local CharacterDisplay = Display and Display:FindFirstChild("characterdisplay", true)

    if CharacterDisplay and CharacterDisplay:IsA("ImageLabel") then
        CharacterDisplay.Image = Image
    end
end

local function Bind_Motion(Button: Instance?)
    if Button and Button:IsA("GuiButton") and BindButtonMotion then
        BindButtonMotion(Button)
    end
end

local function Get_Gift_Prompt_Key(TargetUserId: number, ProductKey: string): string
    return `{TargetUserId}:{ProductKey}`
end

local function Clear_Generated(List: Instance)
    for _, Child in List:GetChildren() do
        if Child:GetAttribute(GENERATED_ATTRIBUTE) then
            Child:Destroy()
        end
    end
end

local function Resolve_Gift_Product_Key(ProductKey: string): string?
    local GiftProductKey = GIFT_PRODUCT_OVERRIDES[ProductKey] or ProductKey
    local Product = RobuxProducts.Get(GiftProductKey)

    if
        type(Product) ~= "table"
        or Product.Kind ~= "Product"
        or type(Product.ProductId) ~= "number"
        or (Product.GrantKind ~= "Food" and Product.GrantKind ~= "Lasso")
    then
        return nil
    end

    return Product.Key
end

local function Populate_Gift_Frame()
    local GiftFrame = Get_Gift_Frame()
    local ProductKey = CurrentProductKey

    if not GiftFrame or not ProductKey then
        return
    end

    local List = GiftFrame:FindFirstChild("Content")
    local Template = List and List:FindFirstChild("Template")

    if not List or not Template or not Template:IsA("GuiObject") then
        return
    end

    Template.Visible = false
    Clear_Generated(List)

    local LayoutOrder = 0

    for _, Player in Players:GetPlayers() do
        if Player == LocalPlayer then
            continue
        end

        LayoutOrder += 1

        local Clone = Template:Clone()
        Clone.Name = tostring(Player.UserId)
        Clone.LayoutOrder = LayoutOrder
        Clone:SetAttribute(GENERATED_ATTRIBUTE, true)
        Clone.Visible = true
        Clone.Parent = List

        Set_Text(Clone, "DisplayName", Player.DisplayName)
        Set_Text(Clone, "Username", `@{Player.Name}`)

        local GiftButton = Clone:FindFirstChild("Gift")

        if GiftButton and GiftButton:IsA("GuiButton") then
            Bind_Motion(GiftButton)
            GiftButton.Activated:Connect(function()
                if IsUiBlocked and IsUiBlocked() then
                    return
                end

                PendingGiftPrompts[Get_Gift_Prompt_Key(Player.UserId, ProductKey)] = true
                Network.PrepareGift.Fire({
                    TargetUserId = Player.UserId,
                    ProductKey = ProductKey,
                })
            end)
        end

        task.spawn(function()
            local Success, PlayerInfo = pcall(Util.Get_Player_Info, Player.UserId)

            if not Success or type(PlayerInfo) ~= "table" or not Clone.Parent then
                return
            end

            if type(PlayerInfo.Name) == "string" then
                Set_Text(Clone, "Username", `@{PlayerInfo.Name}`)
            end

            if type(PlayerInfo.Image) == "string" then
                Set_Player_Image(Clone, PlayerInfo.Image)
            end
        end)
    end
end

local function Open_Gift_Frame(ProductKey: string)
    local GiftProductKey = Resolve_Gift_Product_Key(ProductKey)

    if not GiftProductKey then
        return
    end

    CurrentProductKey = GiftProductKey
    Populate_Gift_Frame()

    if OpenFrame then
        OpenFrame("Gifting", true)
        return
    end

    local GiftFrame = Get_Gift_Frame()

    if GiftFrame then
        GiftFrame.Visible = true
    end
end

local function Bind_Gift_Button(Button: Instance?, ProductKey: string)
    if not Button or not Button:IsA("GuiButton") then
        return
    end

    Bind_Motion(Button)

    if Button:GetAttribute(GIFT_BUTTON_BOUND_ATTRIBUTE) then
        return
    end

    Button:SetAttribute(GIFT_BUTTON_BOUND_ATTRIBUTE, true)
    Button.Activated:Connect(function()
        if IsUiBlocked and IsUiBlocked() then
            return
        end

        Open_Gift_Frame(ProductKey)
    end)
end

local function Bind_Lasso_Gift_Buttons()
    local Content = Get_Lasso_Content()

    if not Content then
        return
    end

    for _, ButtonConfig in RobuxProducts.LassoShopButtons do
        local Product = RobuxProducts.Get(ButtonConfig.Key)
        local Card = Product and Find_By_Path(Content, ButtonConfig.Path)
        local Button = Card and (Card:FindFirstChild("Gift") or Card:FindFirstChild("Gift Button"))

        if Product and Button then
            Bind_Gift_Button(Button, Product.Key)
        end
    end
end

local function Bind_Food_Gift_Buttons()
    local Content = Get_Food_Content()

    if not Content then
        return
    end

    for _, ButtonConfig in RobuxProducts.FoodShopButtons do
        local Product = RobuxProducts.Get(ButtonConfig.Key)
        local Card = Product and Find_By_Path(Content, ButtonConfig.Path)
        local Button = Card and (Card:FindFirstChild("Gift Button") or Card:FindFirstChild("Gift"))

        if Product and Button then
            Bind_Gift_Button(Button, Product.Key)
        end
    end
end

local function Bind_Player_List_Changes()
    if PlayerListBound then
        return
    end

    PlayerListBound = true

    Players.PlayerAdded:Connect(function()
        if CurrentProductKey then
            Populate_Gift_Frame()
        end
    end)

    Players.PlayerRemoving:Connect(function()
        if CurrentProductKey then
            task.defer(Populate_Gift_Frame)
        end
    end)
end

local function Handle_Gift_Prepared()
    for _, Data in Network.GiftPrepared.Iter() do
        if
            type(Data) ~= "table"
            or type(Data.TargetUserId) ~= "number"
            or type(Data.ProductKey) ~= "string"
            or type(Data.ProductId) ~= "number"
        then
            continue
        end

        local PromptKey = Get_Gift_Prompt_Key(Data.TargetUserId, Data.ProductKey)

        if not PendingGiftPrompts[PromptKey] then
            continue
        end

        PendingGiftPrompts[PromptKey] = nil
        MarketplaceService:PromptProductPurchase(LocalPlayer, Data.ProductId)
    end
end

local function Bind_All()
    Bind_Player_List_Changes()
    Bind_Lasso_Gift_Buttons()
    Bind_Food_Gift_Buttons()
    Handle_Gift_Prepared()
end

local GiftingUI = {}

function GiftingUI.Initialize(
    Gui: ScreenGui,
    ButtonMotion: (GuiButton) -> (),
    UiBlocked: () -> boolean,
    FrameOpener: (string, boolean?) -> ()
)
    MainGui = Gui
    BindButtonMotion = ButtonMotion
    IsUiBlocked = UiBlocked
    OpenFrame = FrameOpener

    Bind_All()
end

function GiftingUI.Step()
    Bind_All()
end

return table.freeze(GiftingUI)
