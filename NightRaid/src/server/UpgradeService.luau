--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local LoadoutService = require(script.Parent:WaitForChild("LoadoutService"))

local UpgradeService = {}

function UpgradeService.Init()
    Remotes.BuyUpgrade.OnServerEvent:Connect(function(player: Player, upgradeKey: any)
        if Remotes.CurrentPhase.Value ~= "LobbyPhase" then return end
        if type(upgradeKey) ~= "string" then return end

        local leaderstats = player:FindFirstChild("leaderstats")
        local cash = leaderstats and leaderstats:FindFirstChild("Cash") :: IntValue?
        if not cash then return end

        local upg = DataService.GetUpgrades(player)
        local currentLvl = (upg :: any)[upgradeKey] or 0

        local canBuy, newCash, newLvl = LootLogic.CanPurchaseUpgrade(cash.Value, upgradeKey, currentLvl)
        if canBuy then
            cash.Value = newCash
            local upgDict: { [string]: any } = upg
            upgDict[upgradeKey] = newLvl
            DataService.SetUpgrades(player, upg)
            DataService.SavePlayerData(player)

            local curLoadout = LoadoutService.GetActiveLoadout(player)
            LoadoutService.ApplyLoadout(player, curLoadout)

            local upgName = LootLogic.UpgradesConfig[upgradeKey].NameKey and Locale.Get(LootLogic.UpgradesConfig[upgradeKey].NameKey) or LootLogic.UpgradesConfig[upgradeKey].Name
            Remotes.UpgradesUpdated:FireClient(player, upg, false)
            Remotes.InventoryUpdated:FireClient(
                player,
                {},
                Locale.Format("PurchasedUpgradeNotice", upgName, newLvl)
            )
        end
    end)
end

return UpgradeService
