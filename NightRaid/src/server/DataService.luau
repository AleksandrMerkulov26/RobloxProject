--!strict
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RaidProgression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaidProgression"))

local DataService = {}

local TEST_MODE = RunService:IsStudio()
local PlayerDataStore = nil
local dataStoreAvailable = false

local dsSuccess = pcall(function()
    local dataStoreName = TEST_MODE and "PlayerProgress_Test_v1" or "PlayerProgress_v3"
    PlayerDataStore = DataStoreService:GetDataStore(dataStoreName)
end)
if dsSuccess and PlayerDataStore then
    dataStoreAvailable = true
    print("[DataService]: DataStore connected (" .. (TEST_MODE and "Test" or "Production") .. ").")
end

local playerDataLoaded: { [Player]: boolean } = {}
local playerSaveInProgress: { [Player]: boolean? } = {}
local playerOwnedLoadouts: { [Player]: { [string]: boolean } } = {}
local playerUpgrades: { [Player]: { Pockets: number, SmokeStarter: number, Battery: number } } = {}
local playerHideoutData: { [Player]: { Version: number, Level: number } } = {}

function DataService.IsDataLoaded(player: Player): boolean
    return playerDataLoaded[player] == true
end

function DataService.GetUpgrades(player: Player)
    return playerUpgrades[player] or { Pockets = 0, SmokeStarter = 0, Battery = 0 }
end

function DataService.SetUpgrades(player: Player, upgrades: { Pockets: number, SmokeStarter: number, Battery: number })
    playerUpgrades[player] = upgrades
end

function DataService.GetOwnedLoadouts(player: Player): { [string]: boolean }
    return playerOwnedLoadouts[player] or { Default = true }
end

function DataService.SetOwnedLoadouts(player: Player, owned: { [string]: boolean })
    playerOwnedLoadouts[player] = owned
end

function DataService.GetHideoutData(player: Player): { Version: number, Level: number }
    return playerHideoutData[player] or { Version = 1, Level = 1 }
end

function DataService.SetHideoutData(player: Player, data: { Version: number, Level: number })
    playerHideoutData[player] = data
end

function DataService.LoadPlayerData(player: Player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

    local cash = leaderstats:FindFirstChild("Cash") :: IntValue?
    if not cash then
        cash = Instance.new("IntValue")
        cash.Name = "Cash"
        cash.Value = 0
        cash.Parent = leaderstats
    end

    local raids = leaderstats:FindFirstChild("Raids") :: IntValue?
    if not raids then
        raids = Instance.new("IntValue")
        raids.Name = "Raids"
        raids.Value = 0
        raids.Parent = leaderstats
    end

    local streak = leaderstats:FindFirstChild("Streak") :: IntValue?
    if not streak then
        streak = Instance.new("IntValue")
        streak.Name = "Streak"
        streak.Value = 0
        streak.Parent = leaderstats
    end

    playerUpgrades[player] = { Pockets = 0, SmokeStarter = 0, Battery = 0 }
    playerOwnedLoadouts[player] = { Default = true }
    playerHideoutData[player] = { Version = 1, Level = 1 }
    playerDataLoaded[player] = false

    if dataStoreAvailable and PlayerDataStore then
        local key = "Player_" .. player.UserId
        local success, savedData = pcall(function()
            return PlayerDataStore:GetAsync(key)
        end)

        if success then
            playerDataLoaded[player] = true
            if type(savedData) == "table" then
                if type(savedData.Cash) == "number" and savedData.Cash == savedData.Cash then
                    cash.Value = math.clamp(math.floor(savedData.Cash), 0, 2000000000)
                end

                local normalized = RaidProgression.NormalizeStats(savedData.Raids, savedData.Streak)
                raids.Value = normalized.Raids
                streak.Value = normalized.Streak

                if type(savedData.OwnedLoadouts) == "table" then
                    local owned = { Default = true }
                    for _, loadout in ipairs(Config.Loadouts) do
                        if loadout.Cost > 0 and savedData.OwnedLoadouts[loadout.Id] == true then
                            owned[loadout.Id] = true
                        end
                    end
                    playerOwnedLoadouts[player] = owned
                end

                if type(savedData.Upgrades) == "table" then
                    local upg = savedData.Upgrades
                    playerUpgrades[player] = {
                        Pockets = type(upg.Pockets) == "number" and math.clamp(math.floor(upg.Pockets), 0, 3) or 0,
                        SmokeStarter = type(upg.SmokeStarter) == "number" and math.clamp(math.floor(upg.SmokeStarter), 0, 2) or 0,
                        Battery = type(upg.Battery) == "number" and math.clamp(math.floor(upg.Battery), 0, 3) or 0,
                    }
                end

                if type(savedData.Hideout) == "table" then
                    playerHideoutData[player] = {
                        Version = 1,
                        Level = type(savedData.Hideout.Level) == "number" and math.clamp(math.floor(savedData.Hideout.Level), 1, 10) or 1,
                    }
                end
            elseif type(savedData) == "number" then
                cash.Value = math.clamp(math.floor(savedData), 0, 2000000000)
            end
        else
            warn(string.format("[DataService] Failed to load data for %s: %s", player.Name, tostring(savedData)))
        end
    else
        playerDataLoaded[player] = true
    end
end

function DataService.SavePlayerData(player: Player): boolean
    if not dataStoreAvailable or not PlayerDataStore then return false end

    while playerSaveInProgress[player] do
        task.wait(0.05)
    end

    if not playerDataLoaded[player] then
        warn(string.format("[DataService] Skipping save for %s: data was not loaded successfully.", player.Name))
        return false
    end

    playerSaveInProgress[player] = true

    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash") :: IntValue?
    if not cash then
        playerSaveInProgress[player] = nil
        return false
    end

    local upg = playerUpgrades[player] or { Pockets = 0, SmokeStarter = 0, Battery = 0 }
    local raidsStat = leaderstats and leaderstats:FindFirstChild("Raids") :: IntValue?
    local streakStat = leaderstats and leaderstats:FindFirstChild("Streak") :: IntValue?

    local owned = { Default = true }
    for _, loadout in ipairs(Config.Loadouts) do
        if loadout.Cost > 0 and playerOwnedLoadouts[player] and playerOwnedLoadouts[player][loadout.Id] == true then
            owned[loadout.Id] = true
        end
    end

    local normalized = RaidProgression.NormalizeStats(
        raidsStat and raidsStat.Value or 0,
        streakStat and streakStat.Value or 0
    )

    local dataToSave = {
        Cash = math.max(0, math.floor(cash.Value)),
        Raids = normalized.Raids,
        Streak = normalized.Streak,
        OwnedLoadouts = owned,
        Hideout = {
            Version = 1,
            Level = math.clamp(math.floor((playerHideoutData[player] and playerHideoutData[player].Level) or 1), 1, 10),
        },
        Upgrades = {
            Pockets = math.clamp(math.floor(upg.Pockets or 0), 0, 3),
            SmokeStarter = math.clamp(math.floor(upg.SmokeStarter or 0), 0, 2),
            Battery = math.clamp(math.floor(upg.Battery or 0), 0, 3),
        }
    }

    local success, err = pcall(function()
        PlayerDataStore:UpdateAsync("Player_" .. player.UserId, function()
            return dataToSave
        end)
    end)

    playerSaveInProgress[player] = nil

    if not success then
        warn(string.format("[DataService] Failed to save data for %s: %s", player.Name, tostring(err)))
        return false
    end

    return true
end

function DataService.RemovePlayer(player: Player)
    DataService.SavePlayerData(player)
    playerDataLoaded[player] = nil
    playerOwnedLoadouts[player] = nil
    playerUpgrades[player] = nil
    playerHideoutData[player] = nil
    playerSaveInProgress[player] = nil
end

return DataService
