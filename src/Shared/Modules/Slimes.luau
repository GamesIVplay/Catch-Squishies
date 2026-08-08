local Mutations = require(script.Parent.Mutations)

type Slime = {
    Rarity: string,
    IncomePerSec: number,
    CustomStrength: number?,
    Image: string,
}

type GetModelFunction = (Slime_Name: string, Mutation: string?) -> Model?

type SlimesModule = {
    [string]: Slime | GetModelFunction,
    GetModel: GetModelFunction,
}

local Slimes: { [string]: Slime } = {
    -- Common
    Goopy = {
        Rarity = "Common",
        IncomePerSec = 3,
        Image = "rbxassetid://89018318815428",
    },
    Sunset = {
        Rarity = "Common",
        IncomePerSec = 8,
        Image = "rbxassetid://122211936909799",
    },
    Spidey = {
        Rarity = "Common",
        IncomePerSec = 13,
        Image = "rbxassetid://91113815189489",
    },
    Shinobi = {
        Rarity = "Common",
        IncomePerSec = 18,
        Image = "rbxassetid://79505549674557",
    },
    Brutis = {
        Rarity = "Common",
        IncomePerSec = 23,
        Image = "rbxassetid://123220785419001",
    },

    -- Rare
    Builder = {
        Rarity = "Rare",
        IncomePerSec = 30,
        Image = "rbxassetid://110703589271747",
    },
    Dino = {
        Rarity = "Rare",
        IncomePerSec = 55,
        Image = "rbxassetid://77661349834745",
    },
    Antler = {
        Rarity = "Rare",
        IncomePerSec = 80,
        Image = "rbxassetid://98541607666936",
    },
    Pumpkin = {
        Rarity = "Rare",
        IncomePerSec = 92,
        Image = "rbxassetid://132143877319122",
    },
    Leafy = {
        Rarity = "Rare",
        IncomePerSec = 118,
        Image = "rbxassetid://114579787330406",
    },
    Ruby = {
        Rarity = "Rare",
        IncomePerSec = 142,
        Image = "rbxassetid://110362886913373",
    },
    Shelly = {
        Rarity = "Rare",
        IncomePerSec = 155,
        Image = "rbxassetid://103007080587837",
    },
    Buggy = {
        Rarity = "Rare",
        IncomePerSec = 180,
        Image = "rbxassetid://101707702781277",
    },

    -- Epic
    Derpy = {
        Rarity = "Epic",
        IncomePerSec = 220,
        Image = "rbxassetid://139191628815841",
    },
    Glo = {
        Rarity = "Epic",
        IncomePerSec = 325,
        Image = "rbxassetid://98651678477345",
    },
    Fin = {
        Rarity = "Epic",
        IncomePerSec = 431,
        Image = "rbxassetid://129939853835303",
    },
    Petal = {
        Rarity = "Epic",
        IncomePerSec = 484,
        Image = "rbxassetid://97568690559218",
    },
    Ring = {
        Rarity = "Epic",
        IncomePerSec = 589,
        Image = "rbxassetid://71620895874444",
    },
    Double = {
        Rarity = "Epic",
        IncomePerSec = 695,
        Image = "rbxassetid://73007553284221",
    },
    Shark = {
        Rarity = "Epic",
        IncomePerSec = 800,
        Image = "rbxassetid://125980978443520",
    },

    -- Legendary
    Vine = {
        Rarity = "Legendary",
        IncomePerSec = 1_000,
        Image = "rbxassetid://78094009407506",
    },
    Franken = {
        Rarity = "Legendary",
        IncomePerSec = 1_778,
        Image = "rbxassetid://132405683561357",
    },
    Rainy = {
        Rarity = "Legendary",
        IncomePerSec = 2_556,
        Image = "rbxassetid://111103281982107",
    },
    Ember = {
        Rarity = "Legendary",
        IncomePerSec = 3_333,
        Image = "rbxassetid://115121719242464",
    },
    Honey = {
        Rarity = "Legendary",
        IncomePerSec = 3_722,
        Image = "rbxassetid://124579864208422",
    },
    Spike = {
        Rarity = "Legendary",
        IncomePerSec = 4_500,
        Image = "rbxassetid://71593446110465",
    },

    -- Secret
    Cap = {
        Rarity = "Secret",
        IncomePerSec = 6_000,
        Image = "rbxassetid://122343957239275",
    },
    Rocky = {
        Rarity = "Secret",
        IncomePerSec = 7_500,
        Image = "rbxassetid://138516882709413",
    },
    Meow = {
        Rarity = "Secret",
        IncomePerSec = 8_250,
        Image = "rbxassetid://89934308174109",
    },
    King = {
        Rarity = "Secret",
        IncomePerSec = 9_750,
        Image = "rbxassetid://112963501020680",
    },
    Monke = {
        Rarity = "Secret",
        IncomePerSec = 10_500,
        Image = "rbxassetid://82847251784884",
    },
    Octo = {
        Rarity = "Secret",
        IncomePerSec = 12_000,
        Image = "rbxassetid://75391585419668",
    },

    -- Prismatic
    Cacty = {
        Rarity = "Prismatic",
        IncomePerSec = 15_000,
        Image = "rbxassetid://77651723825946",
    },
    Tripple = {
        Rarity = "Prismatic",
        IncomePerSec = 19_250,
        Image = "rbxassetid://92117980987789",
    },
    Orca = {
        Rarity = "Prismatic",
        IncomePerSec = 23_500,
        Image = "rbxassetid://79443440451520",
    },
    Mushy = {
        Rarity = "Prismatic",
        IncomePerSec = 27_750,
        Image = "rbxassetid://80665106274020",
    },
    Icicle = {
        Rarity = "Prismatic",
        IncomePerSec = 32_000,
        Image = "rbxassetid://96628540956218",
    },

    -- Divine
    Trunk = {
        Rarity = "Divine",
        IncomePerSec = 38_000,
        Image = "rbxassetid://107203660022665",
    },
    Axolotl = {
        Rarity = "Divine",
        IncomePerSec = 45_333,
        Image = "rbxassetid://134050263732894",
    },
    Wizzy = {
        Rarity = "Divine",
        IncomePerSec = 52_667,
        Image = "rbxassetid://70799518332000",
    },
    Lotus = {
        Rarity = "Divine",
        IncomePerSec = 60_000,
        Image = "rbxassetid://108984940385794",
    },

    -- Exotic
    Ouchy = {
        Rarity = "Exotic",
        IncomePerSec = 70_000,
        Image = "rbxassetid://74669000073716",
    },
    Unicorn = {
        Rarity = "Exotic",
        IncomePerSec = 83_333,
        Image = "rbxassetid://119623048613787",
    },
    Lucky = {
        Rarity = "Exotic",
        IncomePerSec = 96_667,
        Image = "rbxassetid://134730822916299",
    },
    Broken = {
        Rarity = "Exotic",
        IncomePerSec = 103_333,
        Image = "rbxassetid://116484917175907",
    },

    -- Transcended
    Astro = {
        Rarity = "Transcended",
        IncomePerSec = 130_000,
        Image = "rbxassetid://103815109551209",
    },
    Devil = {
        Rarity = "Transcended",
        IncomePerSec = 150_000,
        Image = "rbxassetid://119151742056293",
    },
    Blackhole = {
        Rarity = "Transcended",
        IncomePerSec = 170_000,
        Image = "rbxassetid://76308052817898",
    },
    Icarus = {
        Rarity = "Transcended",
        IncomePerSec = 180_000,
        Image = "rbxassetid://85425632956976",
    },
    Sunny = {
        Rarity = "Transcended",
        IncomePerSec = 200_000,
        Image = "rbxassetid://97353902566581",
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

local function Find_Slime_Model(Slime_Models: Folder, Model_Name: string, Mutation: string?): Model?
    local MutationName = Mutations.Normalize("Slime", Mutation)
    local MutationFolder = Slime_Models:FindFirstChild(MutationName)

    if MutationFolder and MutationFolder:IsA("Folder") then
        local MutationModel = Find_Model_In_Folder(MutationFolder, Model_Name)

        if MutationModel then
            return MutationModel
        end
    end

    if MutationName ~= Mutations.Normal then
        local NormalFolder = Slime_Models:FindFirstChild(Mutations.Normal)

        if NormalFolder and NormalFolder:IsA("Folder") then
            local NormalModel = Find_Model_In_Folder(NormalFolder, Model_Name)

            if NormalModel then
                return NormalModel
            end
        end
    end

    return Find_Model_In_Folder(Slime_Models, Model_Name)
end

local function Get_Slime_Models(): Folder?
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local Slime_Models = Assets and Assets:FindFirstChild("Slimes")

    if Slime_Models and Slime_Models:IsA("Folder") then
        return Slime_Models
    end

    return nil
end

local GetModel: GetModelFunction = function(Slime_Name: string, Mutation: string?): Model?
    local Slime_Data = Slimes[Slime_Name]

    if type(Slime_Data) ~= "table" then
        return nil
    end

    local Slime_Models = Get_Slime_Models()

    if not Slime_Models then
        return nil
    end

    local Model_Name = MODEL_NAME_OVERRIDES[Slime_Name] or Slime_Name
    local Model = Find_Slime_Model(Slime_Models, Model_Name, Mutation)

    if Model and Model:IsA("Model") then
        return Model
    end

    return nil
end

local function Verify_Slime_Model_Integrity()
    local Slime_Models = Get_Slime_Models()

    assert(Slime_Models, "Missing ReplicatedStorage.Assets.Slimes for slime integrity check")

    for Slime_Name, Slime_Data in Slimes do
        if type(Slime_Data) ~= "table" then
            continue
        end

        local Model_Name = MODEL_NAME_OVERRIDES[Slime_Name] or Slime_Name
        local Model = GetModel(Slime_Name)

        assert(Model and Model:IsA("Model"), `Missing slime model "{Model_Name}" for Slimes.{Slime_Name}`)
    end
end

local Slimes_Module = Slimes :: SlimesModule
Slimes_Module.GetModel = GetModel

Verify_Slime_Model_Integrity()

return table.freeze(Slimes_Module)
