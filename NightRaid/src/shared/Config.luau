--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local Config = {
    -- Тайминги раундов (Фаза 1: расширенные раунды)
    LobbyDuration = 0, -- Лобби ждёт ручного запуска рейда.
    LootDuration = 90, -- 1.5 минуты на проникновение, поиск ключ-карты и взлом
    ExtractionDuration = 30, -- 30 секунд на эвакуацию с тяжелым лутом

    -- Базовые параметры
    MaxInventoryWeight = 25,
    BaseWalkSpeed = 16,
    MinWalkSpeed = 8,
    GrappleDistance = 150,
    GrapplePullSpeed = 95,

    -- Доступные автосеты
    Loadouts = {
        {
            Id = "Default",
            NameKey = "Loadout_Default_Name",
            DescKey = "Loadout_Default_Desc",
            Name = Locale.Get("Loadout_Default_Name"),
            Description = Locale.Get("Loadout_Default_Desc"),
            Cost = 0,
            WalkSpeed = 16,
            MaxWeight = 25,
            GrappleDistance = 150,
            GrappleSpeed = 95,
        },
        {
            Id = "Scout",
            NameKey = "Loadout_Scout_Name",
            DescKey = "Loadout_Scout_Desc",
            Name = Locale.Get("Loadout_Scout_Name"),
            Description = Locale.Get("Loadout_Scout_Desc"),
            Cost = 350,
            WalkSpeed = 20,
            MaxWeight = 16,
            GrappleDistance = 210,
            GrappleSpeed = 120,
        },
        {
            Id = "Mule",
            NameKey = "Loadout_Mule_Name",
            DescKey = "Loadout_Mule_Desc",
            Name = Locale.Get("Loadout_Mule_Name"),
            Description = Locale.Get("Loadout_Mule_Desc"),
            Cost = 600,
            WalkSpeed = 14,
            MaxWeight = 50,
            GrappleDistance = 130,
            GrappleSpeed = 85,
        },
        {
            Id = "Support",
            NameKey = "Loadout_Support_Name",
            DescKey = "Loadout_Support_Desc",
            Name = Locale.Get("Loadout_Support_Name"),
            Description = Locale.Get("Loadout_Support_Desc"),
            Cost = 500,
            WalkSpeed = 16,
            MaxWeight = 22,
            GrappleDistance = 160,
            GrappleSpeed = 100,
            Role = "Support",
        }
    },

    -- Категории лута (хрупкие, тяжелые, редкие)
    LootTable = {
        { Id = "Watch", NameKey = "Loot_Watch", Name = Locale.Get("Loot_Watch"), Value = 150, Weight = 1.5, Color = Color3.fromRGB(255, 215, 0), Fragile = false, Tier = "Common" },
        { Id = "Chip", NameKey = "Loot_Chip", Name = Locale.Get("Loot_Chip"), Value = 300, Weight = 2.0, Color = Color3.fromRGB(0, 180, 255), Fragile = false, Tier = "Common" },
        { Id = "EncryptedDrive", NameKey = "Loot_EncryptedDrive", Name = Locale.Get("Loot_EncryptedDrive"), Value = 450, Weight = 0.8, Color = Color3.fromRGB(120, 220, 255), Fragile = false, Tier = "Uncommon" },
        { Id = "Vase", NameKey = "Loot_Vase", Name = Locale.Get("Loot_Vase"), Value = 550, Weight = 4.0, Color = Color3.fromRGB(255, 120, 180), Fragile = true, Tier = "Uncommon" },
        { Id = "Platinum", NameKey = "Loot_Platinum", Name = Locale.Get("Loot_Platinum"), Value = 650, Weight = 8.0, Color = Color3.fromRGB(220, 220, 230), Fragile = false, Tier = "Rare" },
        { Id = "DiamondNecklace", NameKey = "Loot_DiamondNecklace", Name = Locale.Get("Loot_DiamondNecklace"), Value = 850, Weight = 1.0, Color = Color3.fromRGB(180, 255, 255), Fragile = true, Tier = "Rare" },
        { Id = "Safe", NameKey = "Loot_Safe", Name = Locale.Get("Loot_Safe"), Value = 950, Weight = 14.0, Color = Color3.fromRGB(50, 50, 50), Fragile = false, Tier = "Rare" },
        { Id = "RolexCase", NameKey = "Loot_RolexCase", Name = Locale.Get("Loot_RolexCase"), Value = 1200, Weight = 4.0, Color = Color3.fromRGB(255, 180, 50), Fragile = false, Tier = "Rare" },
        { Id = "GoldBar", NameKey = "Loot_GoldBar", Name = Locale.Get("Loot_GoldBar"), Value = 1500, Weight = 12.0, Color = Color3.fromRGB(255, 200, 30), Fragile = false, Tier = "Legendary" },
        { Id = "PrototypeLaser", NameKey = "Loot_PrototypeLaser", Name = Locale.Get("Loot_PrototypeLaser"), Value = 2000, Weight = 3.5, Color = Color3.fromRGB(255, 40, 100), Fragile = true, Tier = "Legendary" },
    }
}

return Config
