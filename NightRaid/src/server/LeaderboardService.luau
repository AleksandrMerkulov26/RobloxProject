--!strict
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LeaderboardService = {}

local isStudio = RunService:IsStudio()
local CashLeaderboardStore: OrderedDataStore? = nil
local inMemoryScores: { [number]: { Name: string, Cash: number } } = {}

pcall(function()
    CashLeaderboardStore = DataStoreService:GetOrderedDataStore("WeeklyCashLeaderboard_v1")
end)

function LeaderboardService.RecordPlayerCash(userId: number, totalCash: number)
    local player = Players:GetPlayerByUserId(userId)
    local name = player and player.DisplayName or ("Player_" .. tostring(userId))
    inMemoryScores[userId] = { Name = name, Cash = math.floor(totalCash) }

    if isStudio or not CashLeaderboardStore then return end
    task.spawn(function()
        pcall(function()
            if CashLeaderboardStore then
                CashLeaderboardStore:SetAsync(tostring(userId), math.floor(totalCash))
            end
        end)
    end)
end

function LeaderboardService.GetTopPlayers(): { { UserId: number, UserName: string, Value: number } }
    local results: { { UserId: number, UserName: string, Value: number } } = {}

    if CashLeaderboardStore and not isStudio then
        local success, pages = pcall(function()
            if CashLeaderboardStore then
                return CashLeaderboardStore:GetSortedAsync(false, 10)
            end
            return nil
        end)

        if success and pages then
            local entries = pages:GetCurrentPage()
            for _, entry in ipairs(entries) do
                local uid = tonumber(entry.key) or 0
                local name = "Agent " .. tostring(uid)
                local p = Players:GetPlayerByUserId(uid)
                if p then
                    name = p.DisplayName
                else
                    pcall(function()
                        name = Players:GetNameFromUserIdAsync(uid)
                    end)
                end
                table.insert(results, {
                    UserId = uid,
                    UserName = name,
                    Value = entry.value,
                })
            end
            return results
        end
    end

    -- In-memory / Studio fallback
    for uid, entry in pairs(inMemoryScores) do
        table.insert(results, {
            UserId = uid,
            UserName = entry.Name,
            Value = entry.Cash,
        })
    end
    table.sort(results, function(a, b) return a.Value > b.Value end)
    while #results > 10 do
        table.remove(results, #results)
    end

    return results
end

return LeaderboardService
