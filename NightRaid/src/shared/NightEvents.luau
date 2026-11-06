-- Ночные события: случайный модификатор, меняющий условия каждого рейда.
-- Модуль не обращается к Workspace или Lighting: его функции легко тестировать.
local NightEvents = {}

NightEvents.None = {
    Id = "None",
    Name = "",
    Description = "",
    Weight = 0,
    GuardViewMultiplier = 1,
    GuardSpeedMultiplier = 1,
    LootValueMultiplier = 1,
    Darkness = false,
    JackpotLoot = nil,
}

NightEvents.Events = {
    {
        Id = "Blackout",
        Name = "ЧЁРНАЯ НОЧЬ",
        Description = "Свет отключён. Охранник видит хуже, но и вам сложнее ориентироваться. Добыча дороже на 25%.",
        Weight = 3,
        GuardViewMultiplier = 0.7,
        GuardSpeedMultiplier = 1,
        LootValueMultiplier = 1.25,
        Darkness = true,
    },
    {
        Id = "RedAlert",
        Name = "КРАСНАЯ ТРЕВОГА",
        Description = "Охрана быстрее и зорче. Зато вся добыча стоит на 50% больше.",
        Weight = 2,
        GuardViewMultiplier = 1.2,
        GuardSpeedMultiplier = 1.1,
        LootValueMultiplier = 1.5,
        Darkness = false,
    },
    {
        Id = "Jackpot",
        Name = "ДЖЕКПОТ",
        Description = "В запертом хранилище спрятана Золотая корона. Вскройте дверь и успейте её вынести!",
        Weight = 2,
        GuardViewMultiplier = 1,
        GuardSpeedMultiplier = 1,
        LootValueMultiplier = 1,
        Darkness = false,
        JackpotLoot = {
            Name = "Золотая корона",
            Value = 2500,
            Weight = 10,
            Color = Color3.fromRGB(255, 200, 40),
            Fragile = false,
        },
    },
    {
        Id = "Calm",
        Name = "ТИХАЯ НОЧЬ",
        Description = "Всё спокойно. Обычный рейд — идеальная возможность освоиться.",
        Weight = 3,
        GuardViewMultiplier = 1,
        GuardSpeedMultiplier = 1,
        LootValueMultiplier = 1,
        Darkness = false,
    },
}

function NightEvents.Pick(roll: number)
    local totalWeight = 0
    for _, event in ipairs(NightEvents.Events) do
        totalWeight += event.Weight
    end

    local target = math.clamp(roll, 0, 0.999999) * totalWeight
    local accumulated = 0
    for _, event in ipairs(NightEvents.Events) do
        accumulated += event.Weight
        if target < accumulated then
            return event
        end
    end

    return NightEvents.Events[#NightEvents.Events]
end

function NightEvents.ScaleLootValue(lootData, multiplier: number)
    if multiplier == 1 then
        return lootData
    end

    return {
        Name = lootData.Name,
        Value = math.floor(lootData.Value * multiplier + 0.5),
        Weight = lootData.Weight,
        Color = lootData.Color,
        Fragile = lootData.Fragile,
    }
end

function NightEvents.ApplyToAwareness(awareness, event)
    local viewMultiplier = event.GuardViewMultiplier or 1
    local speedMultiplier = event.GuardSpeedMultiplier or 1

    return {
        ViewDistance = awareness.ViewDistance * viewMultiplier,
        FovDotThreshold = awareness.FovDotThreshold,
        PatrolSpeed = awareness.PatrolSpeed * speedMultiplier,
        SearchSpeed = awareness.SearchSpeed * speedMultiplier,
        InvestigateSpeed = awareness.InvestigateSpeed * speedMultiplier,
    }
end

return NightEvents
