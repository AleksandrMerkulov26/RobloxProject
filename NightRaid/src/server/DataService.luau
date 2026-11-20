--!strict
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local _Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RaidProgression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaidProgression"))
local ContractService = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ContractService"))

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
local playerTrophies: { [Player]: { [string]: boolean } } = {}
local playerCosmetics: { [Player]: { Owned: { [string]: boolean }, EquippedMask: string?, EquippedGrapple: string? } } = {}
local playerHideoutDecos: { [Player]: { [string]: boolean } } = {}
export type PlayerContractsData = {
    Day: number,
    Completed: { [string]: boolean },
    Progress: { [string]: number },
}

local playerContracts: { [Player]: PlayerContractsData } = {}

function DataService.IsDataLoaded(player: Player): boolean
    return playerDataLoaded[player] == true
end

function DataService.GetTrophies(player: Player): { [string]: boolean }
    return playerTrophies[player] or {}
end

function DataService.UnlockTrophy(player: Player, trophyId: string): boolean
    local trophies = playerTrophies[player]
    if not trophies then
        trophies = {}
        playerTrophies[player] = trophies
    end
    if not trophies[trophyId] then
        trophies[trophyId] = true
        return true
    end
    return false
end

function DataService.GetCosmetics(player: Player): { Owned: { [string]: boolean }, EquippedMask: string?, EquippedGrapple: string? }
    return playerCosmetics[player] or { Owned = {}, EquippedMask = nil, EquippedGrapple = nil }
end

function DataService.SetCosmetics(player: Player, data: { Owned: { [string]: boolean }, EquippedMask: string?, EquippedGrapple: string? })
    playerCosmetics[player] = data
end

function DataService.GetContracts(player: Player): PlayerContractsData
    local currentDay = ContractService.GetDayNumber()
    local data = playerContracts[player]
    if not data or data.Day ~= currentDay then
        local freshData: PlayerContractsData = {
            Day = currentDay,
            Completed = {},
            Progress = {},
        }
        playerContracts[player] = freshData
        return freshData
    end
    return data
end

function DataService.CheckAndCompleteContract(player: Player, contractId: string, currentAmount: number): (boolean, number)
    local data = DataService.GetContracts(player)
    if data.Completed[contractId] then
        return false, 0
    end

    local targetContract = nil
    for _, c in ipairs(ContractService.GetDailyContracts()) do
        if c.Id == contractId then
            targetContract = c
            break
        end
    end
    if not targetContract then return false, 0 end

    data.Progress[contractId] = math.max(data.Progress[contractId] or 0, currentAmount)
    if data.Progress[contractId] >= targetContract.TargetAmount then
        data.Completed[contractId] = true
        local leaderstats = player:FindFirstChild("leaderstats")
        local cash = leaderstats and leaderstats:FindFirstChild("Cash") :: IntValue?
        if cash then
            cash.Value += targetContract.RewardCash
        end
        return true, targetContract.RewardCash
    end
    return false, 0
end

function DataService.GetHideoutDecos(player: Player): { [string]: boolean }
    return playerHideoutDecos[player] or {}
end

function DataService.UnlockHideoutDeco(player: Player, decoId: string): boolean
    local decos = playerHideoutDecos[player]
    if not decos then
        decos = {}
        playerHideoutDecos[player] = decos
    end
    if not decos[decoId] then
        decos[decoId] = true
        return true
    end
    return false
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

function DataService.LoadPlayerData(player: Player): boolean
    local rawLeaderstats = player:FindFirstChild("leaderstats")
    local leaderstatsFolder: Instance
    if rawLeaderstats then
        leaderstatsFolder = rawLeaderstats
    else
        local newFolder = Instance.new("Folder")
        newFolder.Name = "leaderstats"
        newFolder.Parent = player
        leaderstatsFolder = newFolder
    end

    local existingCash = leaderstatsFolder:FindFirstChild("Cash")
    local cash: IntValue
    if existingCash and existingCash:IsA("IntValue") then
        cash = existingCash
    else
        cash = Instance.new("IntValue")
        cash.Name = "Cash"
        cash.Value = 0
        cash.Parent = leaderstatsFolder
    end

    local existingRaids = leaderstatsFolder:FindFirstChild("Raids")
    local raids: IntValue
    if existingRaids and existingRaids:IsA("IntValue") then
        raids = existingRaids
    else
        raids = Instance.new("IntValue")
        raids.Name = "Raids"
        raids.Value = 0
        raids.Parent = leaderstatsFolder
    end

    local existingStreak = leaderstatsFolder:FindFirstChild("Streak")
    local streak: IntValue
    if existingStreak and existingStreak:IsA("IntValue") then
        streak = existingStreak
    else
        streak = Instance.new("IntValue")
        streak.Name = "Streak"
        streak.Value = 0
        streak.Parent = leaderstatsFolder
    end

    playerUpgrades[player] = { Pockets = 0, SmokeStarter = 0, Battery = 0 }
    playerOwnedLoadouts[player] = { Default = true }
    playerHideoutData[player] = { Version = 1, Level = 1 }
    playerTrophies[player] = {}
    playerCosmetics[player] = { Owned = { DefaultGrapple = true }, EquippedMask = nil, EquippedGrapple = "DefaultGrapple" }
    playerHideoutDecos[player] = {}
    playerContracts[player] = { Day = ContractService.GetDayNumber(), Completed = {}, Progress = {} }
    playerDataLoaded[player] = false

    if dataStoreAvailable and PlayerDataStore then
        local key = "Player_" .. player.UserId
        local success, savedData = false, nil

        -- До 3 попыток чтения при временных сбоях сети DataStore
        for attempt = 1, 3 do
            success, savedData = pcall(function()
                return PlayerDataStore:GetAsync(key)
            end)
            if success then break end
            if attempt < 3 then
                task.wait(1.0)
            end
        end

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

                if type(savedData.Trophies) == "table" then
                    playerTrophies[player] = savedData.Trophies
                end

                if type(savedData.Cosmetics) == "table" then
                    playerCosmetics[player] = {
                        Owned = type(savedData.Cosmetics.Owned) == "table" and savedData.Cosmetics.Owned or { DefaultGrapple = true },
                        EquippedMask = savedData.Cosmetics.EquippedMask,
                        EquippedGrapple = savedData.Cosmetics.EquippedGrapple or "DefaultGrapple",
                    }
                end

                if type(savedData.HideoutDecos) == "table" then
                    playerHideoutDecos[player] = savedData.HideoutDecos
                end

                local currentDay = ContractService.GetDayNumber()
                if type(savedData.Contracts) == "table" and savedData.Contracts.Day == currentDay then
                    playerContracts[player] = {
                        Day = currentDay,
                        Completed = type(savedData.Contracts.Completed) == "table" and savedData.Contracts.Completed or {},
                        Progress = type(savedData.Contracts.Progress) == "table" and savedData.Contracts.Progress or {},
                    }
                else
                    playerContracts[player] = {
                        Day = currentDay,
                        Completed = {},
                        Progress = {},
                    }
                end
            elseif type(savedData) == "number" then
                cash.Value = math.clamp(math.floor(savedData), 0, 2000000000)
            end
        else
            warn(string.format("[DataService] Failed to load data for %s after retries: %s", player.Name, tostring(savedData)))
            return false
        end
    elseif TEST_MODE then
        -- Studio can continue with session-only data if DataStore access is unavailable.
        warn("[DataService] Studio session is running without DataStore persistence.")
        playerDataLoaded[player] = true
    else
        warn("[DataService] DataStore unavailable; refusing to initialize a player with temporary data.")
        return false
    end

    return playerDataLoaded[player] == true
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
        },
        Trophies = playerTrophies[player] or {},
        Cosmetics = playerCosmetics[player] or { Owned = { DefaultGrapple = true }, EquippedMask = nil, EquippedGrapple = "DefaultGrapple" },
        HideoutDecos = playerHideoutDecos[player] or {},
        Contracts = playerContracts[player] or { Day = ContractService.GetDayNumber(), Completed = {}, Progress = {} },
    }

    local success, err = pcall(function()
        PlayerDataStore:UpdateAsync("Player_" .. player.UserId, function(oldValue)
            if type(oldValue) == "table" and type(oldValue.Version) == "number" then
                dataToSave.Hideout.Version = math.max(dataToSave.Hideout.Version, oldValue.Version)
            end
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
    playerTrophies[player] = nil
    playerCosmetics[player] = nil
    playerHideoutDecos[player] = nil
    playerContracts[player] = nil
    playerSaveInProgress[player] = nil
end

-- Периодический автосейв всех активных игроков каждые 180 секунд
task.spawn(function()
    while true do
        task.wait(180)
        for player, isLoaded in pairs(playerDataLoaded) do
            if isLoaded and player.Parent == _Players then
                DataService.SavePlayerData(player)
                task.wait(0.25)
            end
        end
    end
end)

return DataService
