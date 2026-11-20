--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local LoadoutService = {}
local TEST_MODE = RunService:IsStudio()

local playerActiveLoadouts: { [Player]: any } = {}

function LoadoutService.GetActiveLoadout(player: Player)
    return playerActiveLoadouts[player] or Config.Loadouts[1]
end

function LoadoutService.ApplyLoadout(player: Player, loadout: any)
    playerActiveLoadouts[player] = loadout
    local upg = DataService.GetUpgrades(player)
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = loadout.WalkSpeed
        end
    end
    Remotes.LoadoutApplied:FireClient(player, loadout, upg)
end

function LoadoutService.SendOwnedLoadouts(player: Player)
    Remotes.LoadoutsUpdated:FireClient(player, DataService.GetOwnedLoadouts(player))
end

function LoadoutService.InitPlayer(player: Player)
    LoadoutService.ApplyLoadout(player, Config.Loadouts[1])
    LoadoutService.SendOwnedLoadouts(player)
end

function LoadoutService.RemovePlayer(player: Player)
    playerActiveLoadouts[player] = nil
end

-- Network handlers
Remotes.GetOwnedLoadouts.OnServerInvoke = function(player: Player)
    return DataService.GetOwnedLoadouts(player)
end

Remotes.SelectLoadout.OnServerEvent:Connect(function(player: Player, loadoutId: any)
    if Remotes.CurrentPhase.Value ~= "LobbyPhase" then return end
    if type(loadoutId) ~= "string" or #loadoutId > 32 then return end

    local targetLoadout = nil
    for _, loadout in ipairs(Config.Loadouts) do
        if loadout.Id == loadoutId then
            targetLoadout = loadout
            break
        end
    end
    if not targetLoadout then return end

    local owned = DataService.GetOwnedLoadouts(player)
    if not owned[targetLoadout.Id] then
        if not TEST_MODE then
            local leaderstats = player:FindFirstChild("leaderstats")
            local cash = leaderstats and leaderstats:FindFirstChild("Cash") :: IntValue?
            if not cash then return end

            local canBuy, newCash = LootLogic.CanAffordLoadout(cash.Value, targetLoadout.Cost)
            if not canBuy then
                return
            end

            cash.Value = newCash
        end

        owned[targetLoadout.Id] = true
        DataService.SetOwnedLoadouts(player, owned)

        if not DataService.SavePlayerData(player) and not TEST_MODE then
            owned[targetLoadout.Id] = nil
            DataService.SetOwnedLoadouts(player, owned)
            local leaderstats = player:FindFirstChild("leaderstats")
            local cash = leaderstats and leaderstats:FindFirstChild("Cash") :: IntValue?
            if cash then cash.Value += targetLoadout.Cost end
            LoadoutService.SendOwnedLoadouts(player)
            return
        end
    end

    LoadoutService.ApplyLoadout(player, targetLoadout)
    LoadoutService.SendOwnedLoadouts(player)
end)

return LoadoutService
