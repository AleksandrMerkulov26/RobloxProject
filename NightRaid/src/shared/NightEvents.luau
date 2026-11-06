-- Ночные события: случайный модификатор, который меняет каждый рейд.
-- Модуль чисто логический (без обращений к workspace/Lighting), поэтому его
-- можно тестировать в TestRunner без запуска игры. Эффекты применяет сервер.
local NightEvents = {}

-- Нейтральное состояние: используется между рейдами и как значение по умолчанию.
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

-- Weight — относительная частота выпадения (сумма весов не обязана быть 100).
NightEvents.Events = {
    {
        Id = "Blackout",
        Name = "ЧЁРНАЯ НОЧЬ",
        Description = "Свет отключён. Охранник видит хуже, но и вы почти ничего не видите. Добыча дороже на 25%.",
        Weight = 3,
        GuardViewMultiplier = 0.7,
        GuardSpeedMultiplier = 1,
        LootValueMultiplier = 1.25,
        Darkness = true,
    },
    {
        Id = "RedAlert",
        Name = "КРАСНАЯ ТРЕВОГА",
        Description = "Охрана на взводе: быстрее и зорче. Зато вся добыча стоит на 50% больше.",
        Weight = 2,
        GuardViewMultiplier = 1.2,
        GuardSpeedMultiplier = 1.1,
        LootValueMultiplier = 1.5,
        Darkness = false,
    },
    {
        Id = "Jackpot",
        Name = "ДЖЕКПОТ",
        Description = "В запертом хранилище лежит Золотая корона. Вскройте дверь и успейте её вынести!",
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
        Description = "Всё спокойно. Обычный рейд — идеально, чтобы освоиться.",
        Weight = 3,
        GuardViewMultiplier = 1,
        GuardSpeedMultiplier = 1,
        LootValueMultiplier = 1,
        Darkness = false,
    },
}

-- roll: число от 0 до 1 (обычно math.random()). Передаётся снаружи, чтобы выбор был
-- детерминированным в тестах. Значения вне диапазона обрезаются.
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

-- Возвращает копию предмета с изменённой стоимостью. Исходная запись Config не меняется.
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

-- Масштабирует параметры зрения и скорости охранника. Возвращает новую таблицу.
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
