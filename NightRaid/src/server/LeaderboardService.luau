--!strict
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local LeaderboardService = {}

local isStudio = RunService:IsStudio()
local CashLeaderboardStore: OrderedDataStore? = nil

pcall(function()
    CashLeaderboardStore = DataStoreService:GetOrderedDataStore("WeeklyCashLeaderboard_v1")
end)

function LeaderboardService.RecordPlayerCash(userId: number, totalCash: number)
    if isStudio or not CashLeaderboardStore then return end
    task.spawn(function()
        pcall(function()
            if CashLeaderboardStore then
                CashLeaderboardStore:SetAsync(tostring(userId), math.floor(totalCash))
            end
        end)
    end)
end

function LeaderboardService.GetTopPlayers(): { { UserId: number, Value: number } }
    if not CashLeaderboardStore then return {} end

    local results = {}
    local success, pages = pcall(function()
        if CashLeaderboardStore then
            return CashLeaderboardStore:GetSortedAsync(false, 10)
        end
        return nil
    end)

    if success and pages then
        local entries = pages:GetCurrentPage()
        for _, entry in ipairs(entries) do
            table.insert(results, {
                UserId = tonumber(entry.key) or 0,
                Value = entry.value,
            })
        end
    end

    return results
end

return LeaderboardService
