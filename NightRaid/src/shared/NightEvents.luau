--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

-- Ночные события: случайный модификатор, меняющий условия каждого рейда.
local NightEvents = {}

NightEvents.None = {
    Id = "None",
    NameKey = "",
    DescKey = "",
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
        NameKey = "Event_Blackout_Name",
        DescKey = "Event_Blackout_Desc",
        Name = Locale.Get("Event_Blackout_Name"),
        Description = Locale.Get("Event_Blackout_Desc"),
        Weight = 3,
        GuardViewMultiplier = 0.7,
        GuardSpeedMultiplier = 1,
        LootValueMultiplier = 1.25,
        Darkness = true,
    },
    {
        Id = "RedAlert",
        NameKey = "Event_RedAlert_Name",
        DescKey = "Event_RedAlert_Desc",
        Name = Locale.Get("Event_RedAlert_Name"),
        Description = Locale.Get("Event_RedAlert_Desc"),
        Weight = 2,
        GuardViewMultiplier = 1.2,
        GuardSpeedMultiplier = 1.1,
        LootValueMultiplier = 1.5,
        Darkness = false,
    },
    {
        Id = "Jackpot",
        NameKey = "Event_Jackpot_Name",
        DescKey = "Event_Jackpot_Desc",
        Name = Locale.Get("Event_Jackpot_Name"),
        Description = Locale.Get("Event_Jackpot_Desc"),
        Weight = 2,
        GuardViewMultiplier = 1,
        GuardSpeedMultiplier = 1,
        LootValueMultiplier = 1,
        Darkness = false,
        JackpotLoot = {
            Id = "Crown",
            NameKey = "Loot_Crown",
            Name = Locale.Get("Loot_Crown"),
            Value = 2500,
            Weight = 10,
            Color = Color3.fromRGB(255, 200, 40),
            Fragile = false,
        },
    },
    {
        Id = "Calm",
        NameKey = "Event_Calm_Name",
        DescKey = "Event_Calm_Desc",
        Name = Locale.Get("Event_Calm_Name"),
        Description = Locale.Get("Event_Calm_Desc"),
        Weight = 3,
        GuardViewMultiplier = 1,
        GuardSpeedMultiplier = 1,
        LootValueMultiplier = 1,
        Darkness = false,
    },
    {
        Id = "PowerSurge",
        NameKey = "Event_PowerSurge_Name",
        DescKey = "Event_PowerSurge_Desc",
        Name = Locale.Get("Event_PowerSurge_Name"),
        Description = Locale.Get("Event_PowerSurge_Desc"),
        Weight = 2,
        GuardViewMultiplier = 1.1,
        GuardSpeedMultiplier = 1.3,
        LootValueMultiplier = 1.3,
        Darkness = false,
        LasersDisabled = true,
    },
    {
        Id = "ThickFog",
        NameKey = "Event_ThickFog_Name",
        DescKey = "Event_ThickFog_Desc",
        Name = Locale.Get("Event_ThickFog_Name"),
        Description = Locale.Get("Event_ThickFog_Desc"),
        Weight = 2,
        GuardViewMultiplier = 0.5,
        GuardSpeedMultiplier = 0.95,
        LootValueMultiplier = 1.2,
        Darkness = false,
        HeavyFog = true,
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

function NightEvents.ScaleLootValue(lootData: any, multiplier: number)
    if multiplier == 1 then
        return lootData
    end

    return {
        Id = lootData.Id,
        NameKey = lootData.NameKey,
        Name = lootData.Name,
        Value = math.floor(lootData.Value * multiplier + 0.5),
        Weight = lootData.Weight,
        Color = lootData.Color,
        Fragile = lootData.Fragile,
    }
end

function NightEvents.ApplyToAwareness(awareness: any, event: any)
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
