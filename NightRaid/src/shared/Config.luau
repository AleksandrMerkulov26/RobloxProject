local Config = {
    -- Тайминги раундов
    LobbyDuration = 0, -- Лобби ждёт ручного запуска рейда.
    LootDuration = 30,
    ExtractionDuration = 15,

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
            Name = "Новобранец",
            Cost = 0,
            WalkSpeed = 16,
            MaxWeight = 25,
            GrappleDistance = 150,
            GrappleSpeed = 95,
            Description = "Базовый сбалансированный комплект налётчика."
        },
        {
            Id = "Scout",
            Name = "Разведчик",
            Cost = 1,
            WalkSpeed = 20,
            MaxWeight = 16,
            GrappleDistance = 210,
            GrappleSpeed = 120,
            Description = "Высокая скорость и дальнобойная кошка, но малый рюкзак."
        },
        {
            Id = "Mule",
            Name = "Тяжеловес",
            Cost = 3,
            WalkSpeed = 14,
            MaxWeight = 50,
            GrappleDistance = 130,
            GrappleSpeed = 85,
            Description = "Огромный рюкзак под ценности и драгоценные слитки."
        }
    },

    -- Категории лута (хрупкие, тяжелые и обычные)
    LootTable = {
        { Name = "Золотые часы", Value = 150, Weight = 1.5, Color = Color3.fromRGB(255, 215, 0), Fragile = false },
        { Name = "Элитная микросхема", Value = 300, Weight = 2.0, Color = Color3.fromRGB(0, 180, 255), Fragile = false },
        { Name = "Хрупкая античная ваза", Value = 550, Weight = 4.0, Color = Color3.fromRGB(255, 120, 180), Fragile = true },
        { Name = "Слиток платины", Value = 450, Weight = 8.0, Color = Color3.fromRGB(220, 220, 230), Fragile = false },
        { Name = "Мини-сейф с облигациями", Value = 900, Weight = 14.0, Color = Color3.fromRGB(50, 50, 50), Fragile = false },
    }
}

return Config