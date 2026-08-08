local Mutations = require(script.Parent.Mutations)

type Dumpling = {
    Rarity: string,
    IncomePerSec: number,
    CustomStrength: number?,
    Image: string,
}

type GetModelFunction = (Dumpling_Name: string, Mutation: string?) -> Model?

type DumplingsModule = {
    [string]: Dumpling | GetModelFunction,
    GetModel: GetModelFunction,
}

local Dumplings: { [string]: Dumpling } = {
    -- Common
    Brown = {
        Rarity = "Common",
        IncomePerSec = 5,
        Image = "rbxassetid://84725351486791",
    },
    White = {
        Rarity = "Common",
        IncomePerSec = 10,
        Image = "rbxassetid://78625615593474",
    },
    Pink = {
        Rarity = "Common",
        IncomePerSec = 15,
        Image = "rbxassetid://135008199031031",
    },
    Woven = {
        Rarity = "Common",
        IncomePerSec = 20,
        Image = "rbxassetid://94667454081194",
    },
    Cookie = {
        Rarity = "Common",
        IncomePerSec = 25,
        Image = "rbxassetid://112717315395218",
    },

    -- Rare
    JellyFish = {
        Rarity = "Rare",
        IncomePerSec = 42,
        Image = "rbxassetid://74619127940387",
    },
    Black = {
        Rarity = "Rare",
        IncomePerSec = 68,
        Image = "rbxassetid://115746743548959",
    },
    Panda = {
        Rarity = "Rare",
        IncomePerSec = 105,
        Image = "rbxassetid://86942110847516",
    },
    Owl = {
        Rarity = "Rare",
        IncomePerSec = 130,
        Image = "rbxassetid://73210531710253",
    },
    Strawberry = {
        Rarity = "Rare",
        IncomePerSec = 168,
        Image = "rbxassetid://101636865814946",
    },

    -- Epic
    Lava = {
        Rarity = "Epic",
        IncomePerSec = 273,
        Image = "rbxassetid://112047324650605",
    },
    Pastel = {
        Rarity = "Epic",
        IncomePerSec = 378,
        Image = "rbxassetid://133636894905722",
    },
    Cloud = {
        Rarity = "Epic",
        IncomePerSec = 536,
        Image = "rbxassetid://129718434300332",
    },
    Galaxy = {
        Rarity = "Epic",
        IncomePerSec = 642,
        Image = "rbxassetid://130468132902996",
    },
    Thunder = {
        Rarity = "Epic",
        IncomePerSec = 747,
        Image = "rbxassetid://132223422240173",
    },

    -- Legendary
    Rainbow = {
        Rarity = "Legendary",
        IncomePerSec = 1_389,
        Image = "rbxassetid://77687013369969",
    },
    Cyber = {
        Rarity = "Legendary",
        IncomePerSec = 2_167,
        Image = "rbxassetid://103371209723794",
    },
    Snow = {
        Rarity = "Legendary",
        IncomePerSec = 2_944,
        Image = "rbxassetid://105305220507975",
    },
    Catus = {
        Rarity = "Legendary",
        IncomePerSec = 4_111,
        Image = "rbxassetid://113094793719868",
    },

    -- Secret
    Fire = {
        Rarity = "Secret",
        IncomePerSec = 6_750,
        Image = "rbxassetid://113652539759421",
    },
    Dino = {
        Rarity = "Secret",
        IncomePerSec = 9_000,
        Image = "rbxassetid://84878227139204",
    },
    Neon = {
        Rarity = "Secret",
        IncomePerSec = 11_250,
        Image = "rbxassetid://103535193981399",
    },

    -- Prismatic
    Holographic = {
        Rarity = "Prismatic",
        IncomePerSec = 17_125,
        Image = "rbxassetid://121718481989793",
    },
    Unicorn = {
        Rarity = "Prismatic",
        IncomePerSec = 21_375,
        Image = "rbxassetid://140117257664889",
    },
    Crystal = {
        Rarity = "Prismatic",
        IncomePerSec = 25_625,
        Image = "rbxassetid://109912113653362",
    },
    Geode = {
        Rarity = "Prismatic",
        IncomePerSec = 29_875,
        Image = "rbxassetid://129543825756375",
    },

    -- Divine
    Plasma = {
        Rarity = "Divine",
        IncomePerSec = 41_667,
        Image = "rbxassetid://93074229994632",
    },
    Alien = {
        Rarity = "Divine",
        IncomePerSec = 49_000,
        Image = "rbxassetid://110364693139652",
    },
    Pizza = {
        Rarity = "Divine",
        IncomePerSec = 56_333,
        Image = "rbxassetid://126479619936932",
    },

    -- Exotic
    Fox = {
        Rarity = "Exotic",
        IncomePerSec = 76_667,
        Image = "rbxassetid://138246697590303",
    },
    Bunny = {
        Rarity = "Exotic",
        IncomePerSec = 90_000,
        Image = "rbxassetid://133596191191225",
    },
    Whale = {
        Rarity = "Exotic",
        IncomePerSec = 110_000,
        Image = "rbxassetid://122713896480346",
    },

    -- Transcended
    Paw = {
        Rarity = "Transcended",
        IncomePerSec = 140_000,
        Image = "rbxassetid://105912794180814",
    },
    Mushroom = {
        Rarity = "Transcended",
        IncomePerSec = 160_000,
        Image = "rbxassetid://83621952583999",
    },
    Pixel = {
        Rarity = "Transcended",
        IncomePerSec = 190_000,
        Image = "rbxassetid://108166219163893",
    },
}

local MODEL_NAME_OVERRIDES = {}

local function Find_Model_In_Folder(Models_Folder: Instance, Model_Name: string): Model?
    local Direct_Model = Models_Folder:FindFirstChild(Model_Name)

    if Direct_Model and Direct_Model:IsA("Model") then
        return Direct_Model
    end

    local Recursive_Model = Models_Folder:FindFirstChild(Model_Name, true)

    if Recursive_Model and Recursive_Model:IsA("Model") then
        return Recursive_Model
    end

    return nil
end

local function Find_Dumpling_Model(Dumpling_Models: Folder, Model_Name: string, Mutation: string?): Model?
    local MutationName = Mutations.Normalize("Dumpling", Mutation)
    local MutationFolder = Dumpling_Models:FindFirstChild(MutationName)

    if MutationFolder and MutationFolder:IsA("Folder") then
        local MutationModel = Find_Model_In_Folder(MutationFolder, Model_Name)

        if MutationModel then
            return MutationModel
        end
    end

    if MutationName ~= Mutations.Normal then
        local NormalFolder = Dumpling_Models:FindFirstChild(Mutations.Normal)

        if NormalFolder and NormalFolder:IsA("Folder") then
            local NormalModel = Find_Model_In_Folder(NormalFolder, Model_Name)

            if NormalModel then
                return NormalModel
            end
        end
    end

    return Find_Model_In_Folder(Dumpling_Models, Model_Name)
end

local function Get_Dumpling_Models(): Folder?
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Dumpling_Models = Assets and Assets:FindFirstChild("Dumplings")

    if Dumpling_Models and Dumpling_Models:IsA("Folder") then
        return Dumpling_Models
    end

    return nil
end

local GetModel: GetModelFunction = function(Dumpling_Name: string, Mutation: string?): Model?
    local Dumpling_Data = Dumplings[Dumpling_Name]

    if type(Dumpling_Data) ~= "table" then
        return nil
    end

    local Dumpling_Models = Get_Dumpling_Models()

    if not Dumpling_Models then
        return nil
    end

    local Model_Name = MODEL_NAME_OVERRIDES[Dumpling_Name] or Dumpling_Name
    local Model = Find_Dumpling_Model(Dumpling_Models, Model_Name, Mutation)

    if Model and Model:IsA("Model") then
        return Model
    end

    return nil
end

local function Verify_Dumpling_Model_Integrity()
    local Dumpling_Models = Get_Dumpling_Models()

    assert(Dumpling_Models, "Missing ReplicatedStorage.Assets.Dumplings for dumpling integrity check")

    for Dumpling_Name, Dumpling_Data in Dumplings do
        if type(Dumpling_Data) ~= "table" then
            continue
        end

        local Model_Name = MODEL_NAME_OVERRIDES[Dumpling_Name] or Dumpling_Name
        local Model = GetModel(Dumpling_Name)

        assert(Model and Model:IsA("Model"), `Missing dumpling model "{Model_Name}" for Dumplings.{Dumpling_Name}`)
    end
end

local Dumplings_Module = Dumplings :: DumplingsModule
Dumplings_Module.GetModel = GetModel

Verify_Dumpling_Model_Integrity()

return table.freeze(Dumplings_Module)
