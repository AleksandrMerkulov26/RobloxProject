--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local networkFolder = ReplicatedStorage:FindFirstChild("Network")
if not networkFolder then
    networkFolder = Instance.new("Folder")
    networkFolder.Name = "Network"
    networkFolder.Parent = ReplicatedStorage
end

local function getOrCreate(name: string, className: string): Instance
    local existing = networkFolder:FindFirstChild(name)
    if existing and existing:IsA(className) then
        return existing
    end
    if existing then
        existing:Destroy()
    end
    local instance = Instance.new(className)
    instance.Name = name
    instance.Parent = networkFolder
    return instance
end

-- State & values
Remotes.CurrentPhase = getOrCreate("CurrentPhase", "StringValue") :: StringValue
Remotes.CurrentNightEvent = getOrCreate("CurrentNightEvent", "StringValue") :: StringValue

-- Events
Remotes.StateChanged = getOrCreate("StateChanged", "RemoteEvent") :: RemoteEvent
Remotes.InventoryUpdated = getOrCreate("InventoryUpdated", "RemoteEvent") :: RemoteEvent
Remotes.ExtractionProgress = getOrCreate("ExtractionProgress", "RemoteEvent") :: RemoteEvent
Remotes.DropItem = getOrCreate("DropItem", "RemoteEvent") :: RemoteEvent
Remotes.SelectLoadout = getOrCreate("SelectLoadout", "RemoteEvent") :: RemoteEvent
Remotes.LoadoutApplied = getOrCreate("LoadoutApplied", "RemoteEvent") :: RemoteEvent
Remotes.LoadoutsUpdated = getOrCreate("LoadoutsUpdated", "RemoteEvent") :: RemoteEvent
Remotes.MakeNoise = getOrCreate("MakeNoise", "RemoteEvent") :: RemoteEvent
Remotes.ShowRaidSummary = getOrCreate("ShowRaidSummary", "RemoteEvent") :: RemoteEvent
Remotes.ThrowSmoke = getOrCreate("ThrowSmoke", "RemoteEvent") :: RemoteEvent
Remotes.FireTaser = getOrCreate("FireTaser", "RemoteEvent") :: RemoteEvent
Remotes.BuyUpgrade = getOrCreate("BuyUpgrade", "RemoteEvent") :: RemoteEvent
Remotes.UpgradesUpdated = getOrCreate("UpgradesUpdated", "RemoteEvent") :: RemoteEvent
Remotes.OpenHideoutStation = getOrCreate("OpenHideoutStation", "RemoteEvent") :: RemoteEvent
Remotes.StartRaid = getOrCreate("StartRaid", "RemoteEvent") :: RemoteEvent
Remotes.NightEvent = getOrCreate("NightEvent", "RemoteEvent") :: RemoteEvent
Remotes.AlertLevelChanged = getOrCreate("AlertLevelChanged", "RemoteEvent") :: RemoteEvent
Remotes.RevivePlayer = getOrCreate("RevivePlayer", "RemoteEvent") :: RemoteEvent
Remotes.PlayerDownedState = getOrCreate("PlayerDownedState", "RemoteEvent") :: RemoteEvent
Remotes.ToggleCrouch = getOrCreate("ToggleCrouch", "RemoteEvent") :: RemoteEvent
Remotes.BuyCosmetic = getOrCreate("BuyCosmetic", "RemoteEvent") :: RemoteEvent
Remotes.EquipCosmetic = getOrCreate("EquipCosmetic", "RemoteEvent") :: RemoteEvent
Remotes.CosmeticsUpdated = getOrCreate("CosmeticsUpdated", "RemoteEvent") :: RemoteEvent
Remotes.TrophiesUpdated = getOrCreate("TrophiesUpdated", "RemoteEvent") :: RemoteEvent
Remotes.BuyHideoutDeco = getOrCreate("BuyHideoutDeco", "RemoteEvent") :: RemoteEvent
Remotes.HideoutDecoUpdated = getOrCreate("HideoutDecoUpdated", "RemoteEvent") :: RemoteEvent
Remotes.RadioPing = getOrCreate("RadioPing", "RemoteEvent") :: RemoteEvent
Remotes.GrappleEffect = getOrCreate("GrappleEffect", "RemoteEvent") :: RemoteEvent
Remotes.ContractsUpdated = getOrCreate("ContractsUpdated", "RemoteEvent") :: RemoteEvent

-- Functions
Remotes.GetOwnedLoadouts = getOrCreate("GetOwnedLoadouts", "RemoteFunction") :: RemoteFunction
Remotes.GetRaidStatus = getOrCreate("GetRaidStatus", "RemoteFunction") :: RemoteFunction
Remotes.GetRaidReplay = getOrCreate("GetRaidReplay", "RemoteFunction") :: RemoteFunction
Remotes.GetDailyContracts = getOrCreate("GetDailyContracts", "RemoteFunction") :: RemoteFunction
Remotes.GetLeaderboard = getOrCreate("GetLeaderboard", "RemoteFunction") :: RemoteFunction

return Remotes
