--!strict
local AnalyticsService = game:GetService("AnalyticsService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ServerAnalytics = {}

local isStudio = RunService:IsStudio()
local AnalyticsStore = nil

pcall(function()
    AnalyticsStore = DataStoreService:GetDataStore("GameAnalytics_v1")
end)

local currentRaidStartTime: number = 0
local currentRaidNightEventId: string = "None"
local raidPlayerCountAtStart: number = 0

local function safeLogCustom(player: Player?, eventName: string, value: number?, customFields: { [string]: any }?)
    if not isStudio and player and player.Parent == Players then
        pcall(function()
            AnalyticsService:LogCustomEvent(player, eventName, value or 1, customFields or {})
        end)
    end
end

local function incrementCounter(statName: string, amount: number?)
    local amt = amount or 1
    if AnalyticsStore and not isStudio then
        task.spawn(function()
            pcall(function()
                AnalyticsStore:IncrementAsync(statName, amt)
            end)
        end)
    end
end

function ServerAnalytics.OnRaidStarted(playerCount: number, nightEventId: string)
    currentRaidStartTime = os.clock()
    currentRaidNightEventId = nightEventId
    raidPlayerCountAtStart = playerCount

    print(string.format(
        "[Analytics] RAID_START: Players=%d | NightEvent=%s",
        playerCount,
        nightEventId
    ))

    incrementCounter("TotalRaidsStarted")
    incrementCounter("NightEvent_" .. nightEventId)

    for _, player in ipairs(Players:GetPlayers()) do
        safeLogCustom(player, "Raid_Started", 1, {
            NightEvent = nightEventId,
            PlayerCount = playerCount,
        })
    end
end

function ServerAnalytics.OnPlayerEscaped(player: Player, lootValue: number, itemsCount: number, loadoutId: string)
    local duration = math.floor(os.clock() - currentRaidStartTime)
    print(string.format(
        "[Analytics] PLAYER_ESCAPED: %s | Time=%ds | Loot=$%d | Items=%d | Loadout=%s | Event=%s",
        player.Name,
        duration,
        lootValue,
        itemsCount,
        loadoutId,
        currentRaidNightEventId
    ))

    incrementCounter("TotalEscapes")
    incrementCounter("LoadoutUsed_" .. loadoutId)

    safeLogCustom(player, "Raid_Escaped", lootValue, {
        Duration = duration,
        ItemsCount = itemsCount,
        Loadout = loadoutId,
        NightEvent = currentRaidNightEventId,
    })
end

function ServerAnalytics.OnPlayerEliminated(player: Player, cause: string, loadoutId: string)
    local duration = math.floor(os.clock() - currentRaidStartTime)
    print(string.format(
        "[Analytics] PLAYER_ELIMINATED: %s | Cause=%s | Time=%ds | Loadout=%s | Event=%s",
        player.Name,
        cause,
        duration,
        loadoutId,
        currentRaidNightEventId
    ))

    incrementCounter("TotalEliminations")
    incrementCounter("Cause_" .. cause)
    incrementCounter("LoadoutUsed_" .. loadoutId)

    safeLogCustom(player, "Raid_Eliminated", 1, {
        Cause = cause,
        Duration = duration,
        Loadout = loadoutId,
        NightEvent = currentRaidNightEventId,
    })
end

function ServerAnalytics.OnRaidEnded(escapedCount: number, eliminatedCount: number, remainingPlayerCount: number)
    local totalDuration = math.floor(os.clock() - currentRaidStartTime)
    print(string.format(
        "[Analytics] RAID_END: Duration=%ds | Escaped=%d | Eliminated=%d | RemainingPlayers=%d",
        totalDuration,
        escapedCount,
        eliminatedCount,
        remainingPlayerCount
    ))

    incrementCounter("TotalRaidsCompleted")
end

return ServerAnalytics
