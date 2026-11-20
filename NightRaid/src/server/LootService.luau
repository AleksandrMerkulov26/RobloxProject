--!strict
local _Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local LootService = {}

local existingContainer = workspace:FindFirstChild("LootItems")
local lootContainer: Folder
if existingContainer and existingContainer:IsA("Folder") then
    lootContainer = existingContainer
else
    local folder = Instance.new("Folder")
    folder.Name = "LootItems"
    folder.Parent = workspace
    lootContainer = folder
end

export type ItemData = {
    Id: string?,
    Name: string,
    NameKey: string?,
    Value: number,
    Weight: number,
    Color: Color3,
    Fragile: boolean?,
    Tier: string?,
}

export type InventoryData = {
    TotalValue: number,
    TotalWeight: number,
    Items: { ItemData },
    Escaped: boolean,
}

local playerInventories: { [Player]: InventoryData } = {}

-- Forward references set by other services if needed
local getEffectiveMaxWeightFn: ((player: Player) -> number)?
local getActiveLoadoutFn: ((player: Player) -> any)?
local isPlayerEliminatedFn: ((player: Player) -> boolean)?
local isPlayerDownedFn: ((player: Player) -> boolean)?

function LootService.SetDependencies(deps: {
    GetEffectiveMaxWeight: (player: Player) -> number,
    GetActiveLoadout: (player: Player) -> any,
    IsPlayerEliminated: (player: Player) -> boolean,
    IsPlayerDowned: ((player: Player) -> boolean)?,
})
    getEffectiveMaxWeightFn = deps.GetEffectiveMaxWeight
    getActiveLoadoutFn = deps.GetActiveLoadout
    isPlayerEliminatedFn = deps.IsPlayerEliminated
    isPlayerDownedFn = deps.IsPlayerDowned
end

function LootService.GetInventory(player: Player): InventoryData?
    return playerInventories[player]
end

function LootService.InitPlayer(player: Player)
    playerInventories[player] = {
        TotalValue = 0,
        TotalWeight = 0,
        Items = {},
        Escaped = false,
    }
end

function LootService.RemovePlayer(player: Player)
    playerInventories[player] = nil
end

function LootService.ResetForRound(player: Player)
    local inv = playerInventories[player]
    if inv then
        inv.TotalValue = 0
        inv.TotalWeight = 0
        inv.Items = {}
        inv.Escaped = false
        Remotes.InventoryUpdated:FireClient(player, inv, "Новый рейд! Загляните к Скупщику в убежище.")
    end
end

function LootService.ClearWorldLoot()
    if lootContainer then
        lootContainer:ClearAllChildren()
    end
end

function LootService.SpawnLootItem(lootData: ItemData, spawnPosition: Vector3)
    local itemPart = Instance.new("Part")
    itemPart.Name = lootData.Name
    itemPart.Size = Vector3.new(1.4, 1.4, 1.4)
    itemPart.Material = Enum.Material.Neon
    itemPart.Color = lootData.Color
    itemPart.CFrame = CFrame.new(spawnPosition)
    itemPart.Anchored = false
    itemPart.CanCollide = true
    itemPart.CastShadow = false
    itemPart.Parent = lootContainer

    local prompt = Instance.new("ProximityPrompt")
    local itemName = lootData.NameKey and Locale.Get(lootData.NameKey) or lootData.Name
    prompt.ActionText = Locale.Get("TakePrompt")
    prompt.ObjectText = string.format("%s ($%d | %.1f kg)", itemName, lootData.Value, lootData.Weight)
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.2
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = itemPart

    local isClaimed = false

    prompt.Triggered:Connect(function(player: Player)
        if isClaimed then return end

        local phase = Remotes.CurrentPhase.Value
        if phase ~= "LootPhase" and phase ~= "ExtractionPhase" then return end

        local inv = playerInventories[player]
        if not inv or inv.Escaped then return end
        if isPlayerEliminatedFn and isPlayerEliminatedFn(player) then return end
        if isPlayerDownedFn and isPlayerDownedFn(player) then return end

        local effectiveMaxWeight = getEffectiveMaxWeightFn and getEffectiveMaxWeightFn(player) or Config.MaxInventoryWeight
        local currentLoadout = getActiveLoadoutFn and getActiveLoadoutFn(player) or Config.Loadouts[1]

        if not LootLogic.CanAddItem(inv.TotalWeight, lootData.Weight, effectiveMaxWeight) then
            Remotes.InventoryUpdated:FireClient(player, inv, Locale.Get("BackpackFull"))
            return
        end

        isClaimed = true
        prompt.Enabled = false

        table.insert(inv.Items, lootData)
        inv.TotalWeight += lootData.Weight
        inv.TotalValue += lootData.Value

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = LootLogic.CalculateWalkSpeed(
                inv.TotalWeight,
                effectiveMaxWeight,
                currentLoadout.WalkSpeed,
                Config.MinWalkSpeed
            )
        end

        itemPart:Destroy()
        Remotes.InventoryUpdated:FireClient(player, inv, string.format("+%s ($%d)", itemName, lootData.Value))
    end)
end

function LootService.HandleFallDamage(player: Player, fallDistance: number)
    local inv = playerInventories[player]
    if not inv or inv.Escaped then return end
    if isPlayerEliminatedFn and isPlayerEliminatedFn(player) then return end

    if fallDistance > 14 then
        local remItems, brokenItems, newW, newV = LootLogic.ProcessFallDamage(inv.Items, fallDistance, 14)
        inv.Items = remItems
        inv.TotalWeight = newW
        inv.TotalValue = newV

        local effectiveMaxWeight = getEffectiveMaxWeightFn and getEffectiveMaxWeightFn(player) or Config.MaxInventoryWeight
        local currentLoadout = getActiveLoadoutFn and getActiveLoadoutFn(player) or Config.Loadouts[1]
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = LootLogic.CalculateWalkSpeed(
                inv.TotalWeight,
                effectiveMaxWeight,
                currentLoadout.WalkSpeed,
                Config.MinWalkSpeed
            )
        end

        for _, broken in ipairs(brokenItems) do
            local brokenName = broken.NameKey and Locale.Get(broken.NameKey) or broken.Name
            Remotes.InventoryUpdated:FireClient(player, inv, Locale.Format("ItemBrokenFall", brokenName))
        end
    end
end

function LootService.HandlePlayerDeath(player: Player, deathPosition: Vector3, shouldDropLoot: boolean)
    local inv = playerInventories[player]
    if not inv then return end

    if shouldDropLoot and #inv.Items > 0 then
        local droppedItems = LootLogic.GetDeathDropItems(inv.Items)
        for index, item in ipairs(droppedItems) do
            local angle = (index / math.max(#droppedItems, 1)) * math.pi * 2
            local offset = Vector3.new(math.cos(angle) * 3, 1.5, math.sin(angle) * 3)
            LootService.SpawnLootItem(item, deathPosition + offset)
        end

        local lostValue = inv.TotalValue
        inv.Items = {}
        inv.TotalWeight = 0
        inv.TotalValue = 0
        Remotes.InventoryUpdated:FireClient(
            player,
            inv,
            Locale.Format("RaidEliminatedLootLost", lostValue)
        )
    else
        Remotes.InventoryUpdated:FireClient(player, inv, Locale.Get("RaidEliminated"))
    end
end

-- Network listeners
Remotes.DropItem.OnServerEvent:Connect(function(player: Player, itemIndex: any)
    local inv = playerInventories[player]
    if not inv or inv.Escaped then return end
    if isPlayerEliminatedFn and isPlayerEliminatedFn(player) then return end

    if typeof(itemIndex) ~= "number"
        or itemIndex ~= itemIndex
        or itemIndex % 1 ~= 0
        or itemIndex < 1
        or itemIndex > #inv.Items then
        return
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or humanoid.Health <= 0 or not hrp then return end

    local effectiveMaxWeight = getEffectiveMaxWeightFn and getEffectiveMaxWeightFn(player) or Config.MaxInventoryWeight
    local currentLoadout = getActiveLoadoutFn and getActiveLoadoutFn(player) or Config.Loadouts[1]

    local droppedItem = table.remove(inv.Items, itemIndex)
    if droppedItem then
        inv.TotalWeight -= droppedItem.Weight
        inv.TotalValue -= droppedItem.Value
        humanoid.WalkSpeed = LootLogic.CalculateWalkSpeed(
            inv.TotalWeight,
            effectiveMaxWeight,
            currentLoadout.WalkSpeed,
            Config.MinWalkSpeed
        )
        local droppedName = droppedItem.NameKey and Locale.Get(droppedItem.NameKey) or droppedItem.Name
        LootService.SpawnLootItem(droppedItem, hrp.Position + hrp.CFrame.LookVector * 3)
        Remotes.InventoryUpdated:FireClient(player, inv, Locale.Format("ItemDropped", droppedName))
    end
end)

return LootService
