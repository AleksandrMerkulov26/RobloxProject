--!strict
local CosmeticsConfig = {}

export type CosmeticItem = {
    Id: string,
    Name: string,
    Category: "Mask" | "Grapple",
    Cost: number,
    Description: string,
    Color: Color3?,
    NeonColor: Color3?,
}

CosmeticsConfig.Items = {
    -- Маски
    {
        Id = "Balaclava",
        Name = "Тактическая балаклава",
        Category = "Mask",
        Cost = 500,
        Description = "Классический черный подшлемник оперативника. Скрывает личность.",
        Color = Color3.fromRGB(25, 25, 30),
    },
    {
        Id = "OniCyber",
        Name = "Кибер-маска Они",
        Category = "Mask",
        Cost = 1500,
        Description = "Устрашающая японская маска демона со светящимися красными клыками.",
        Color = Color3.fromRGB(40, 20, 20),
        NeonColor = Color3.fromRGB(255, 40, 40),
    },
    {
        Id = "NightVision",
        Name = "Тактический ПНВ",
        Category = "Mask",
        Cost = 2800,
        Description = "Четырехокулярный тактический прибор ночного видения с изумрудной подсветкой.",
        Color = Color3.fromRGB(35, 40, 45),
        NeonColor = Color3.fromRGB(50, 255, 120),
    },
    {
        Id = "GoldHeist",
        Name = "Золотая маска Синдиката",
        Category = "Mask",
        Cost = 6000,
        Description = "Чистое золото высшей пробы. Знак элитного грабителя высшей лиги.",
        Color = Color3.fromRGB(255, 205, 35),
        NeonColor = Color3.fromRGB(255, 235, 120),
    },

    -- Скины на кошку-крюк
    {
        Id = "NeonGrapple",
        Name = "Кибер-лазерный трос",
        Category = "Grapple",
        Cost = 1200,
        Description = "Светящийся бирюзовый кабель захвата с неоновым шлейфом.",
        NeonColor = Color3.fromRGB(0, 255, 230),
    },
    {
        Id = "GoldChain",
        Name = "Золотая цепь захвата",
        Category = "Grapple",
        Cost = 4500,
        Description = "Тяжелая позолоченная цепь для самых стильных зацепов.",
        Color = Color3.fromRGB(255, 215, 0),
        NeonColor = Color3.fromRGB(255, 230, 80),
    },
}

function CosmeticsConfig.GetItem(id: string): CosmeticItem?
    for _, item in ipairs(CosmeticsConfig.Items) do
        if item.Id == id then
            return item
        end
    end
    return nil
end

return CosmeticsConfig
