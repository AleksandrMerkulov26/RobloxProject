local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local PathfindingService = game:GetService("PathfindingService")

-- ========================================================
-- 1. СЕТЕВАЯ ИНФРАСТРУКТУРА (ГАРАНТИРОВАННОЕ СОЗДАНИЕ В ПЕРВУЮ ОЧЕРЕДЬ)
-- ========================================================
local networkFolder = ReplicatedStorage:FindFirstChild("Network")
if not networkFolder then
    networkFolder = Instance.new("Folder")
    networkFolder.Name = "Network"
    networkFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string, classType: string)
    local existing = networkFolder:FindFirstChild(name)
    if existing then return existing end
    local remote = Instance.new(classType)
    remote.Name = name
    remote.Parent = networkFolder
    return remote
end

local currentPhaseValue = getOrCreateRemote("CurrentPhase", "StringValue")
currentPhaseValue.Value = "LobbyPhase"

local stateChangedEvent = getOrCreateRemote("StateChanged", "RemoteEvent")
local inventoryUpdatedEvent = getOrCreateRemote("InventoryUpdated", "RemoteEvent")
local extractionProgressEvent = getOrCreateRemote("ExtractionProgress", "RemoteEvent")
local dropItemEvent = getOrCreateRemote("DropItem", "RemoteEvent")
local selectLoadoutEvent = getOrCreateRemote("SelectLoadout", "RemoteEvent")
local loadoutAppliedEvent = getOrCreateRemote("LoadoutApplied", "RemoteEvent")
local makeNoiseEvent = getOrCreateRemote("MakeNoise", "RemoteEvent")
local raidSummaryEvent = getOrCreateRemote("ShowRaidSummary", "RemoteEvent")
local throwSmokeEvent = getOrCreateRemote("ThrowSmoke", "RemoteEvent")
local fireTaserEvent = getOrCreateRemote("FireTaser", "RemoteEvent")
local buyUpgradeEvent = getOrCreateRemote("BuyUpgrade", "RemoteEvent")
local upgradesUpdatedEvent = getOrCreateRemote("UpgradesUpdated", "RemoteEvent")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))

-- Настройки освещения склада
Lighting.ClockTime = 0
Lighting.Brightness = 0
Lighting.Ambient = Color3.fromRGB(30, 32, 38)
Lighting.OutdoorAmbient = Color3.fromRGB(30, 32, 38)
Lighting.FogColor = Color3.fromRGB(10, 10, 15)
Lighting.FogEnd = 160
Lighting.FogStart = 30
Lighting.GlobalShadows = false

-- ========================================================
-- 2. БАЗА ДАННЫХ DATASTORE
-- ========================================================
local PlayerDataStore = nil
local dataStoreAvailable = false
local dsSuccess = pcall(function()
    PlayerDataStore = DataStoreService:GetDataStore("PlayerProgress_v3")
end)
if dsSuccess and PlayerDataStore then
    dataStoreAvailable = true
    print("[СЕРВЕР]: DataStore подключен.")
end

-- ========================================================
-- 3. ПАПКИ И СОСТОЯНИЕ МИРА
-- ========================================================
local lootContainer = workspace:FindFirstChild("LootItems")
if not lootContainer then
    lootContainer = Instance.new("Folder")
    lootContainer.Name = "LootItems"
    lootContainer.Parent = workspace
end
lootContainer.Name = "LootItems"

local weaponsContainer = workspace:FindFirstChild("GroundWeapons")
if not weaponsContainer then
    weaponsContainer = Instance.new("Folder")
    weaponsContainer.Name = "GroundWeapons"
    weaponsContainer.Parent = workspace
end
weaponsContainer.Name = "GroundWeapons"

local hazardsContainer = workspace:FindFirstChild("Hazards")
if not hazardsContainer then
    hazardsContainer = Instance.new("Folder")
    hazardsContainer.Name = "Hazards"
    hazardsContainer.Parent = workspace
end
hazardsContainer.Name = "Hazards"

local smokesContainer = workspace:FindFirstChild("Smokes")
if not smokesContainer then
    smokesContainer = Instance.new("Folder")
    smokesContainer.Name = "Smokes"
    smokesContainer.Parent = workspace
end
smokesContainer.Name = "Smokes"

local playerInventories = {}
local extractingPlayers = {}
local playerActiveLoadouts = {}
local playerUpgrades = {}
-- Сохранять данные можно только после успешного чтения DataStore.
local playerDataLoaded = {}
local remoteActionTimes = {}
local currentSuspiciousNoise = nil
local guardStunnedUntil = 0

local function canPerformAction(player, actionName, cooldown)
    local now = os.clock()
    local actions = remoteActionTimes[player]
    if not actions then
        actions = {}
        remoteActionTimes[player] = actions
    end

    local lastAction = actions[actionName]
    if lastAction and now - lastAction < cooldown then
        return false
    end

    actions[actionName] = now
    return true
end

local function isFiniteVector3(value)
    return typeof(value) == "Vector3"
        and value.X == value.X and math.abs(value.X) < 100000
        and value.Y == value.Y and math.abs(value.Y) < 100000
        and value.Z == value.Z and math.abs(value.Z) < 100000
end

-- ========================================================
-- 4. ГЕНЕРАТОР КАРТЫ С УТОЛЩЕННЫМ ПОЛОМ И СКУПЩИКОМ
-- ========================================================
local function BuildFacility()
    local oldFacility = workspace:FindFirstChild("HeistFacility")
    if oldFacility then oldFacility:Destroy() end

    local facility = Instance.new("Folder")
    facility.Name = "HeistFacility"
    facility.Parent = workspace

    local lootSpawnPoints = {}

    local function createWall(name, size, pos, color, material)
        local part = Instance.new("Part")
        part.Name = name
        part.Size = size
        part.Position = pos
        part.Anchored = true
        part.Material = material or Enum.Material.Concrete
        part.Color = color or Color3.fromRGB(45, 48, 55)
        part.CastShadow = false
        part.Parent = facility
        return part
    end

    -- Утолщенный пол ангара (толщина 10 studs)
    for x = -60, 60, 40 do
        for z = -60, 60, 40 do
            createWall("FloorTile", Vector3.new(40, 10, 40), Vector3.new(x, -5, z), Color3.fromRGB(30, 32, 36))
        end
    end

    createWall("WallNorth", Vector3.new(160, 32, 4), Vector3.new(0, 16, -80))
    createWall("WallSouth", Vector3.new(160, 32, 4), Vector3.new(0, 16, 80))
    createWall("WallWest", Vector3.new(4, 32, 160), Vector3.new(-80, 16, 0))
    createWall("WallEast", Vector3.new(4, 32, 160), Vector3.new(80, 16, 0))

    for x = -60, 60, 40 do
        for z = -60, 60, 40 do
            createWall("RoofTile", Vector3.new(40, 2, 40), Vector3.new(x, 32, z), Color3.fromRGB(20, 22, 25))
        end
    end

    local columnCoords = {
        Vector3.new(-40, 15, -40), Vector3.new(40, 15, -40),
        Vector3.new(-40, 15, 40), Vector3.new(40, 15, 40)
    }
    for _, cPos in columnCoords do
        createWall("Pillar", Vector3.new(4, 30, 4), Vector3.new(cPos.X, 15, cPos.Z), Color3.fromRGB(60, 65, 75), Enum.Material.Metal)
    end

    createWall("BeamNorth", Vector3.new(80, 2, 4), Vector3.new(0, 24, -40), Color3.fromRGB(80, 85, 95), Enum.Material.Metal)
    createWall("BeamSouth", Vector3.new(80, 2, 4), Vector3.new(0, 24, 40), Color3.fromRGB(80, 85, 95), Enum.Material.Metal)

    local containers = {
        { Pos = Vector3.new(-25, 6, -20), Size = Vector3.new(14, 12, 28), Color = Color3.fromRGB(150, 40, 40) },
        { Pos = Vector3.new(30, 6, -15), Size = Vector3.new(28, 12, 14), Color = Color3.fromRGB(40, 80, 150) },
        { Pos = Vector3.new(-20, 6, 30), Size = Vector3.new(24, 12, 14), Color = Color3.fromRGB(45, 120, 60) },
        { Pos = Vector3.new(25, 6, 35), Size = Vector3.new(14, 12, 24), Color = Color3.fromRGB(160, 100, 30) },
        { Pos = Vector3.new(-25, 18, -20), Size = Vector3.new(14, 12, 24), Color = Color3.fromRGB(70, 75, 85) }
    }

    for _, c in containers do
        createWall("Container", c.Size, c.Pos, c.Color, Enum.Material.DiamondPlate)
        table.insert(lootSpawnPoints, c.Pos + Vector3.new(0, c.Size.Y / 2 + 1.5, 0))
    end

    table.insert(lootSpawnPoints, Vector3.new(0, 1.5, 0))
    table.insert(lootSpawnPoints, Vector3.new(-50, 1.5, -50))
    table.insert(lootSpawnPoints, Vector3.new(50, 1.5, 50))
    table.insert(lootSpawnPoints, Vector3.new(-50, 1.5, 50))
    table.insert(lootSpawnPoints, Vector3.new(50, 1.5, -50))

    local lampPositions = {
        Vector3.new(0, 20, -78), Vector3.new(0, 20, 78),
        Vector3.new(-78, 20, 0), Vector3.new(78, 20, 0)
    }
    for _, lPos in lampPositions do
        local lampPart = createWall("LampPart", Vector3.new(4, 1, 1), lPos, Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
        local pLight = Instance.new("PointLight")
        pLight.Range = 25
        pLight.Brightness = 1.0
        pLight.Color = Color3.fromRGB(255, 140, 50)
        pLight.Shadows = false
        pLight.Parent = lampPart
    end

    -- Запертое хранилище
    createWall("VaultWallW", Vector3.new(2, 14, 20), Vector3.new(50, 7, -30), Color3.fromRGB(20, 22, 25), Enum.Material.Metal)
    createWall("VaultWallN", Vector3.new(20, 14, 2), Vector3.new(60, 7, -40), Color3.fromRGB(20, 22, 25), Enum.Material.Metal)
    createWall("VaultRoof", Vector3.new(20, 2, 20), Vector3.new(60, 14, -30), Color3.fromRGB(15, 18, 20), Enum.Material.Metal)

    local vaultDoor = createWall("VaultDoor", Vector3.new(18, 12, 1.5), Vector3.new(60, 6, -20), Color3.fromRGB(180, 50, 50), Enum.Material.DiamondPlate)
    local doorPrompt = Instance.new("ProximityPrompt")
    doorPrompt.ActionText = "Взломать"
    doorPrompt.ObjectText = "Сейфовая дверь"
    doorPrompt.KeyboardKeyCode = Enum.KeyCode.E
    doorPrompt.HoldDuration = 2.5
    doorPrompt.MaxActivationDistance = 9
    doorPrompt.RequiresLineOfSight = false
    doorPrompt.Parent = vaultDoor

    doorPrompt.Triggered:Connect(function(player)
        doorPrompt.Enabled = false
        vaultDoor.Transparency = 0.8
        vaultDoor.CanCollide = false
        vaultDoor.Color = Color3.fromRGB(50, 200, 80)
        currentSuspiciousNoise = { Position = vaultDoor.Position, Radius = 120, Timestamp = os.clock() }
        local inv = playerInventories[player]
        if inv then inventoryUpdatedEvent:FireClient(player, inv, "Сработала сирена сейфа!") end
    end)

    table.insert(lootSpawnPoints, Vector3.new(60, 1.5, -30))
    table.insert(lootSpawnPoints, Vector3.new(65, 1.5, -35))

    -- Убежище лобби (Safehouse на Y = 117)
    createWall("SafeFloor", Vector3.new(40, 6, 40), Vector3.new(0, 117, 0), Color3.fromRGB(25, 28, 35), Enum.Material.SmoothPlastic)
    createWall("SafeWallN", Vector3.new(40, 12, 2), Vector3.new(0, 126, -20), Color3.fromRGB(35, 40, 48))
    createWall("SafeWallS", Vector3.new(40, 12, 2), Vector3.new(0, 126, 20), Color3.fromRGB(35, 40, 48))
    createWall("SafeWallW", Vector3.new(2, 12, 40), Vector3.new(-20, 126, 0), Color3.fromRGB(35, 40, 48))
    createWall("SafeWallE", Vector3.new(2, 12, 40), Vector3.new(20, 126, 0), Color3.fromRGB(35, 40, 48))
    createWall("SafeRoof", Vector3.new(40, 2, 40), Vector3.new(0, 132, 0), Color3.fromRGB(20, 22, 26))

    local safeLight = Instance.new("PointLight")
    safeLight.Range = 35
    safeLight.Brightness = 2.5
    safeLight.Color = Color3.fromRGB(220, 240, 255)
    safeLight.Shadows = false
    safeLight.Parent = workspace

    -- NPC Скупщика (Черный рынок)
    local counter = createWall("DealerCounter", Vector3.new(12, 4, 3), Vector3.new(0, 122, -14), Color3.fromRGB(40, 30, 20), Enum.Material.Wood)
    createWall("DealerNPC", Vector3.new(2, 5, 2), Vector3.new(0, 123.5, -16.5), Color3.fromRGB(15, 15, 20), Enum.Material.SmoothPlastic)
    
    local dealerPrompt = Instance.new("ProximityPrompt")
    dealerPrompt.ActionText = "Чёрный Рынок"
    dealerPrompt.ObjectText = "Скупщик"
    dealerPrompt.KeyboardKeyCode = Enum.KeyCode.E
    dealerPrompt.HoldDuration = 0
    dealerPrompt.MaxActivationDistance = 9
    dealerPrompt.RequiresLineOfSight = false
    dealerPrompt.Parent = counter

    dealerPrompt.Triggered:Connect(function(player)
        local upg = playerUpgrades[player] or { Pockets = 0, SmokeStarter = 0, Battery = 0 }
        upgradesUpdatedEvent:FireClient(player, upg, true)
    end)

    return lootSpawnPoints
end

local activeLootPositions = BuildFacility()

-- ========================================================
-- 5. ХАЗАРДЫ: ЛАЗЕРЫ
-- ========================================================
local function SpawnLasers()
    hazardsContainer:ClearAllChildren()
    local laserConfigs = {
        { Pos = Vector3.new(0, 2.5, -15), Size = Vector3.new(50, 0.4, 0.4) },
        { Pos = Vector3.new(0, 2.5, 25), Size = Vector3.new(50, 0.4, 0.4) },
        { Pos = Vector3.new(60, 2.5, -20), Size = Vector3.new(18, 0.4, 0.4) }
    }
    for _, lData in laserConfigs do
        local laser = Instance.new("Part")
        laser.Name = "AlarmLaser"
        laser.Size = lData.Size
        laser.Position = lData.Pos
        laser.Anchored = true
        laser.CanCollide = false
        laser.Material = Enum.Material.Neon
        laser.Color = Color3.fromRGB(255, 0, 50)
        laser.CastShadow = false
        laser.Parent = hazardsContainer

        laser.Touched:Connect(function(hit)
            local char = hit.Parent
            local pHum = char and char:FindFirstChildOfClass("Humanoid")
            local player = Players:GetPlayerFromCharacter(char)
            if pHum and player and not (playerInventories[player] and playerInventories[player].Escaped) then
                pHum:TakeDamage(10)
                currentSuspiciousNoise = { Position = laser.Position, Radius = 90, Timestamp = os.clock() }
                local inv = playerInventories[player]
                if inv then inventoryUpdatedEvent:FireClient(player, inv, "ТРЕВОГА: Пересечен лазер!") end
            end
        end)
    end
end

-- ========================================================
-- 6. ОРУЖИЕ НА ПОЛУ
-- ========================================================
local function SpawnGroundWeapon(spawnPos)
    local weaponPart = Instance.new("Part")
    weaponPart.Name = "TaserPickup"
    weaponPart.Size = Vector3.new(1.8, 0.6, 1.2)
    weaponPart.CFrame = CFrame.new(spawnPos)
    weaponPart.Material = Enum.Material.Metal
    weaponPart.Color = Color3.fromRGB(240, 200, 30)
    weaponPart.Anchored = true
    weaponPart.CanCollide = false
    weaponPart.CastShadow = false
    weaponPart.Parent = weaponsContainer

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Взять"
    prompt.ObjectText = "Тайзер охраны"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.2
    prompt.MaxActivationDistance = 8
    prompt.RequiresLineOfSight = false
    prompt.Parent = weaponPart

    prompt.Triggered:Connect(function(player)
        local backpack = player:FindFirstChild("Backpack")
        if not backpack
            or backpack:FindFirstChild("Taser")
            or (player.Character and player.Character:FindFirstChild("Taser"))
        then
            return
        end

        local tool = Instance.new("Tool")
        tool.Name = "Taser"
        tool.RequiresHandle = true
        tool.CanBeDropped = true

        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(1.4, 0.6, 1.0)
        handle.Color = Color3.fromRGB(240, 200, 30)
        handle.Material = Enum.Material.Metal
        handle.Parent = tool

        tool.Parent = backpack
        weaponPart:Destroy()

        local inv = playerInventories[player]
        if inv then
            inventoryUpdatedEvent:FireClient(player, inv, "Подобран шокер [ЛКМ чтобы выстрелить]")
        end
    end)
end

-- ========================================================
-- 7. ВЫСТРЕЛ ТАЙЗЕРА И ДЫМ
-- ========================================================
fireTaserEvent.OnServerEvent:Connect(function(player, targetPos)
    if currentPhaseValue.Value ~= "LootPhase" or not isFiniteVector3(targetPos) then return end
    if not canPerformAction(player, "FireTaser", 1.0) then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local tool = char and char:FindFirstChild("Taser")
    if not hrp or not humanoid or humanoid.Health <= 0 or not tool then return end

    local direction = targetPos - hrp.Position
    if direction.Magnitude < 1 or direction.Magnitude > 50 then return end

    -- Проверяем попадание трассировкой на сервере, а не по координате от клиента.
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { char }
    local hit = workspace:Raycast(hrp.Position, direction, rayParams)

    local guard = workspace:FindFirstChild("GuardNPC")
    if guard and guard.PrimaryPart and hit and hit.Instance:IsDescendantOf(guard) then
        guardStunnedUntil = os.clock() + 5.0
        currentSuspiciousNoise = nil
        local inv = playerInventories[player]
        if inv then
            inventoryUpdatedEvent:FireClient(player, inv, "Охранник оглушен электрошоком на 5 секунд!")
        end
    end

    -- Валидный выстрел расходует тайзер даже при промахе.
    tool:Destroy()
end)

throwSmokeEvent.OnServerEvent:Connect(function(player)
    if currentPhaseValue.Value ~= "LootPhase" then return end
    if not canPerformAction(player, "ThrowSmoke", 10.0) then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return end

    -- Точка дыма рассчитывается сервером; клиент не может размещать дым где угодно.
    local spawnPos = hrp.Position + hrp.CFrame.LookVector * 10
    local smokeCloud = Instance.new("Part")
    smokeCloud.Name = "SmokeCloud"
    smokeCloud.Shape = Enum.PartType.Ball
    smokeCloud.Size = Vector3.new(24, 18, 24)
    smokeCloud.Position = spawnPos
    smokeCloud.Anchored = true
    smokeCloud.CanCollide = false
    smokeCloud.Material = Enum.Material.ForceField
    smokeCloud.Color = Color3.fromRGB(180, 180, 180)
    smokeCloud.Transparency = 0.35
    smokeCloud.CastShadow = false
    smokeCloud.Parent = smokesContainer

    task.delay(7.0, function()
        if smokeCloud and smokeCloud.Parent then smokeCloud:Destroy() end
    end)
end)

-- ========================================================
-- 8. ИНВЕНТАРЬ И ПОДБОР ЛУТА
-- ========================================================
local function ApplyLoadoutToPlayer(player, loadout)
    playerActiveLoadouts[player] = loadout
    local upg = playerUpgrades[player] or { Pockets = 0, SmokeStarter = 0, Battery = 0 }
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = loadout.WalkSpeed
        end
    end
    loadoutAppliedEvent:FireClient(player, loadout, upg)
end

local function SpawnLootItem(lootData, spawnPosition)
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
    prompt.ActionText = "Взять"
    prompt.ObjectText = string.format("%s ($%d | %.1f кг)", lootData.Name, lootData.Value, lootData.Weight)
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.2
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = itemPart

    prompt.Triggered:Connect(function(player)
        local inv = playerInventories[player]
        local currentLoadout = playerActiveLoadouts[player] or Config.Loadouts[1]
        local upg = playerUpgrades[player] or { Pockets = 0 }
        local effectiveMaxWeight = LootLogic.GetEffectiveMaxWeight(currentLoadout.MaxWeight, upg.Pockets)
        if not inv or inv.Escaped then return end

        if not LootLogic.CanAddItem(inv.TotalWeight, lootData.Weight, effectiveMaxWeight) then
            inventoryUpdatedEvent:FireClient(player, inv, "Рюкзак переполнен!")
            return
        end

        table.insert(inv.Items, lootData)
        inv.TotalWeight += lootData.Weight
        inv.TotalValue += lootData.Value

        local character = player.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = LootLogic.CalculateWalkSpeed(inv.TotalWeight, effectiveMaxWeight, currentLoadout.WalkSpeed, Config.MinWalkSpeed)
            end
        end

        itemPart:Destroy()
        inventoryUpdatedEvent:FireClient(player, inv, string.format("+%s ($%d)", lootData.Name, lootData.Value))
    end)
end

dropItemEvent.OnServerEvent:Connect(function(player, itemIndex)
    local inv = playerInventories[player]
    local currentLoadout = playerActiveLoadouts[player] or Config.Loadouts[1]
    local upg = playerUpgrades[player] or { Pockets = 0 }
    local effectiveMaxWeight = LootLogic.GetEffectiveMaxWeight(currentLoadout.MaxWeight, upg.Pockets)
    if not inv or inv.Escaped or not inv.Items[itemIndex] then return end

    local droppedItem = table.remove(inv.Items, itemIndex)
    inv.TotalWeight -= droppedItem.Weight
    inv.TotalValue -= droppedItem.Value

    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if humanoid then
            humanoid.WalkSpeed = LootLogic.CalculateWalkSpeed(inv.TotalWeight, effectiveMaxWeight, currentLoadout.WalkSpeed, Config.MinWalkSpeed)
        end
        if hrp then
            SpawnLootItem(droppedItem, hrp.Position + hrp.CFrame.LookVector * 3)
        end
    end

    inventoryUpdatedEvent:FireClient(player, inv, string.format("Выброшено: %s", droppedItem.Name))
end)

local function SavePlayerData(player)
    if not dataStoreAvailable then return false end
    if not playerDataLoaded[player] then
        warn(string.format("[DataStore] Пропуск сохранения %s: данные не были успешно загружены.", player.Name))
        return false
    end

    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    if not cash then return false end

    local upg = playerUpgrades[player] or { Pockets = 0, SmokeStarter = 0, Battery = 0 }
    local dataToSave = {
        Cash = math.max(0, math.floor(cash.Value)),
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

    if not success then
        warn(string.format("[DataStore] Не удалось сохранить данные %s: %s", player.Name, tostring(err)))
        return false
    end

    return true
end

buyUpgradeEvent.OnServerEvent:Connect(function(player, upgradeKey)
    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    if not cash then return end

    local upg = playerUpgrades[player] or { Pockets = 0, SmokeStarter = 0, Battery = 0 }
    local currentLvl = upg[upgradeKey] or 0

    local canBuy, newCash, newLvl = LootLogic.CanPurchaseUpgrade(cash.Value, upgradeKey, currentLvl)
    if canBuy then
        cash.Value = newCash
        upg[upgradeKey] = newLvl
        playerUpgrades[player] = upg
        SavePlayerData(player)

        local curLoadout = playerActiveLoadouts[player] or Config.Loadouts[1]
        ApplyLoadoutToPlayer(player, curLoadout)

        upgradesUpdatedEvent:FireClient(player, upg, false)
        local inv = playerInventories[player]
        if inv then inventoryUpdatedEvent:FireClient(player, inv, string.format("Куплено: %s (Ур. %d)!", LootLogic.UpgradesConfig[upgradeKey].Name, newLvl)) end
    end
end)

selectLoadoutEvent.OnServerEvent:Connect(function(player, loadoutId)
    local targetLoadout = nil
    for _, l in Config.Loadouts do
        if l.Id == loadoutId then targetLoadout = l break end
    end
    if not targetLoadout then return end

    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    if not cash then return end

    if targetLoadout.Cost > 0 then
        local canBuy, newCash = LootLogic.CanAffordLoadout(cash.Value, targetLoadout.Cost)
        if not canBuy then return end
        cash.Value = newCash
        SavePlayerData(player)
    end

    ApplyLoadoutToPlayer(player, targetLoadout)
    local inv = playerInventories[player]
    if inv then inventoryUpdatedEvent:FireClient(player, inv, string.format("Экипирован сет: %s!", targetLoadout.Name)) end
end)

local function InitPlayer(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local cash = Instance.new("IntValue")
    cash.Name = "Cash"
    cash.Value = 0
    cash.Parent = leaderstats

    playerUpgrades[player] = { Pockets = 0, SmokeStarter = 0, Battery = 0 }
    playerDataLoaded[player] = false

    if dataStoreAvailable then
        local key = "Player_" .. player.UserId
        local success, savedData = pcall(function()
            return PlayerDataStore:GetAsync(key)
        end)

        if success then
            -- Успешный GetAsync без записи означает нового игрока, это тоже валидное состояние.
            playerDataLoaded[player] = true
            if type(savedData) == "table" then
                if type(savedData.Cash) == "number" and savedData.Cash == savedData.Cash then
                    cash.Value = math.clamp(math.floor(savedData.Cash), 0, 2000000000)
                end

                local savedUpgrades = savedData.Upgrades
                if type(savedUpgrades) == "table" then
                    playerUpgrades[player] = {
                        Pockets = type(savedUpgrades.Pockets) == "number"
                            and math.clamp(math.floor(savedUpgrades.Pockets), 0, 3) or 0,
                        SmokeStarter = type(savedUpgrades.SmokeStarter) == "number"
                            and math.clamp(math.floor(savedUpgrades.SmokeStarter), 0, 2) or 0,
                        Battery = type(savedUpgrades.Battery) == "number"
                            and math.clamp(math.floor(savedUpgrades.Battery), 0, 3) or 0,
                    }
                end
            elseif type(savedData) == "number" then
                cash.Value = math.clamp(math.floor(savedData), 0, 2000000000)
            end
        else
            -- Не сохраняем нулевые значения поверх старых данных при временной ошибке чтения.
            warn(string.format("[DataStore] Не удалось загрузить данные %s: %s", player.Name, tostring(savedData)))
        end
    end

    playerInventories[player] = { TotalValue = 0, TotalWeight = 0, Items = {}, Escaped = false }
    ApplyLoadoutToPlayer(player, Config.Loadouts[1])

    player.CharacterAdded:Connect(function(char)
        task.wait(0.2)
        if currentPhaseValue.Value == "LobbyPhase" then
            char:PivotTo(CFrame.new(0, 123, 0))
        else
            char:PivotTo(CFrame.new(0, 3, -65))
        end

        local hum = char:WaitForChild("Humanoid")
        local hrp = char:WaitForChild("HumanoidRootPart")
        local fallY = 0
        local inFreefall = false

        hum.StateChanged:Connect(function(old, new)
            if new == Enum.HumanoidStateType.Freefall then
                fallY = hrp.Position.Y
                inFreefall = true
            elseif new == Enum.HumanoidStateType.Landed and inFreefall then
                inFreefall = false
                local dropped = fallY - hrp.Position.Y
                if dropped > 14 then
                    local inv = playerInventories[player]
                    if inv then
                        local remItems, brokenItems, newW, newV = LootLogic.ProcessFallDamage(inv.Items, dropped, 14)
                        inv.Items = remItems
                        inv.TotalWeight = newW
                        inv.TotalValue = newV

                        for _, broken in ipairs(brokenItems) do
                            inventoryUpdatedEvent:FireClient(player, inv, string.format("ВАШ ПРЕДМЕТ РАЗБИЛСЯ: %s!", broken.Name))
                        end
                    end
                end
            end
        end)
    end)
end

Players.PlayerAdded:Connect(InitPlayer)
Players.PlayerRemoving:Connect(function(player)
    SavePlayerData(player)
    playerInventories[player] = nil
    playerActiveLoadouts[player] = nil
    playerUpgrades[player] = nil
    playerDataLoaded[player] = nil
    remoteActionTimes[player] = nil
    extractingPlayers[player] = nil
end)

for _, p in Players:GetPlayers() do InitPlayer(p) end

makeNoiseEvent.OnServerEvent:Connect(function(player)
    if currentPhaseValue.Value ~= "LootPhase" then return end
    if not canPerformAction(player, "MakeNoise", 0.75) then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return end

    -- Координаты и радиус задаёт сервер, а не клиент.
    currentSuspiciousNoise = {
        Position = hrp.Position,
        Radius = 40,
        Timestamp = os.clock()
    }
end)

-- ========================================================
-- 9. ИИ ОХРАННИКА
-- ========================================================
local function CreateGuardNPC(spawnPos)
    local oldGuard = workspace:FindFirstChild("GuardNPC")
    if oldGuard then oldGuard:Destroy() end

    local model = Instance.new("Model")
    model.Name = "GuardNPC"

    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2.4, 5, 2.4)
    root.Color = Color3.fromRGB(25, 28, 35)
    root.Material = Enum.Material.Metal
    root.CFrame = CFrame.new(spawnPos)
    root.CanCollide = true
    root.CastShadow = false
    root.Parent = model
    model.PrimaryPart = root

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.4, 1.4, 1.4)
    head.Color = Color3.fromRGB(255, 60, 60)
    head.Material = Enum.Material.Neon
    head.CFrame = root.CFrame * CFrame.new(0, 2.5, -0.3)
    head.CanCollide = false
    head.CastShadow = false
    head.Parent = model

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = head
    weld.Parent = head

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 140, 0, 30)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.Text = "[ПАТРУЛЬ]"
    statusLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
    statusLabel.Font = Enum.Font.GothamBlack
    statusLabel.TextSize = 13
    statusLabel.BackgroundTransparency = 1
    statusLabel.Parent = bb

    local light = Instance.new("SpotLight")
    light.Range = 55
    light.Angle = 70
    light.Brightness = 8.5
    light.Color = Color3.fromRGB(255, 140, 40)
    light.Face = Enum.NormalId.Front
    light.Shadows = false
    light.Parent = head

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 300
    humanoid.Health = 300
    humanoid.WalkSpeed = 14
    humanoid.Parent = model

    model.Parent = workspace

    local waypoints = {
        Vector3.new(-45, 3, -45),
        Vector3.new(45, 3, -45),
        Vector3.new(50, 3, -15),
        Vector3.new(45, 3, 45),
        Vector3.new(-45, 3, 45),
        Vector3.new(0, 3, 0)
    }
    local currentWaypointIndex = 1
    local currentState = "Patrol"
    local investigateTarget = nil

    local function NavigateTo(dest)
        local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = false })
        local s = pcall(function() path:ComputeAsync(root.Position, dest) end)
        if s and path.Status == Enum.PathStatus.Success then
            local pts = path:GetWaypoints()
            for i = 2, math.min(#pts, 4) do
                if not model.Parent or humanoid.Health <= 0 then break end
                humanoid:MoveTo(pts[i].Position)
                task.wait(0.35)
            end
        else
            humanoid:MoveTo(dest)
            task.wait(0.35)
        end
    end

    task.spawn(function()
        while model.Parent and humanoid.Health > 0 do
            task.wait(0.15)

            if os.clock() < guardStunnedUntil then
                statusLabel.Text = "[ОГЛУШЁН ЭЛЕКТРОШОКОМ]"
                statusLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
                light.Color = Color3.fromRGB(0, 180, 255)
                humanoid.WalkSpeed = 0
                continue
            end

            local inSmoke = false
            for _, smoke in smokesContainer:GetChildren() do
                if (root.Position - smoke.Position).Magnitude <= 14 then
                    inSmoke = true
                    break
                end
            end

            if inSmoke then
                statusLabel.Text = "[ОСЛЕПЛЕН ДЫМОМ]"
                statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                light.Color = Color3.fromRGB(120, 120, 120)
                humanoid.WalkSpeed = 5
                task.wait(0.5)
                continue
            end

            local targetChar = nil
            for _, player in Players:GetPlayers() do
                local char = player.Character
                local pHrp = char and char:FindFirstChild("HumanoidRootPart")
                local pHum = char and char:FindFirstChildOfClass("Humanoid")

                if pHrp and pHum and pHum.Health > 0 and not (playerInventories[player] and playerInventories[player].Escaped) then
                    if LootLogic.IsPlayerDetected(root.Position, root.CFrame.LookVector, pHrp.Position, 55, 0.35, 12) then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = { model, char, smokesContainer }
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude

                        local hit = workspace:Raycast(root.Position, pHrp.Position - root.Position, rayParams)
                        if not hit then
                            targetChar = char
                            break
                        end
                    end
                end
            end

            if targetChar then
                currentState = "Chase"
                statusLabel.Text = "[ТРЕВОГА: ПОГОНЯ]"
                statusLabel.TextColor3 = Color3.fromRGB(255, 30, 30)
                light.Color = Color3.fromRGB(255, 0, 0)
                humanoid.WalkSpeed = 20.5
                humanoid:MoveTo(targetChar.HumanoidRootPart.Position)

                if (targetChar.HumanoidRootPart.Position - root.Position).Magnitude <= 5.0 then
                    local tHum = targetChar:FindFirstChildOfClass("Humanoid")
                    if tHum then tHum:TakeDamage(25) task.wait(0.5) end
                end
            else
                if currentSuspiciousNoise and (os.clock() - currentSuspiciousNoise.Timestamp) < 6.0 then
                    if LootLogic.IsNoiseAudible(root.Position, currentSuspiciousNoise.Position, currentSuspiciousNoise.Radius) then
                        currentState = "Investigate"
                        investigateTarget = currentSuspiciousNoise.Position
                        currentSuspiciousNoise = nil
                    end
                end

                if currentState == "Investigate" and investigateTarget then
                    statusLabel.Text = "[ПОИСК ШУМА]"
                    statusLabel.TextColor3 = Color3.fromRGB(255, 230, 0)
                    light.Color = Color3.fromRGB(255, 220, 30)
                    humanoid.WalkSpeed = 16
                    NavigateTo(investigateTarget)
                    if (root.Position - investigateTarget).Magnitude <= 8 then
                        task.wait(0.8)
                        currentState = "Patrol"
                        investigateTarget = nil
                    end
                else
                    currentState = "Patrol"
                    statusLabel.Text = "[ПАТРУЛИРОВАНИЕ]"
                    statusLabel.TextColor3 = Color3.fromRGB(255, 160, 50)
                    light.Color = Color3.fromRGB(255, 140, 40)
                    humanoid.WalkSpeed = 13.5
                    local dest = waypoints[currentWaypointIndex]
                    NavigateTo(dest)
                    if (root.Position - dest).Magnitude <= 7 then
                        currentWaypointIndex = (currentWaypointIndex % #waypoints) + 1
                        task.wait(0.5)
                    end
                end
            end
        end
    end)

    return model
end

-- ========================================================
-- 10. ЭВАКУАЦИЯ И ЦИКЛ РАУНДОВ
-- ========================================================
local function CreateExtractionZone()
    local oldZone = workspace:FindFirstChild("ExtractionZone")
    if oldZone then oldZone:Destroy() end

    local zone = Instance.new("Part")
    zone.Name = "ExtractionZone"
    zone.Size = Vector3.new(22, 8, 22)
    zone.Position = Vector3.new(0, 4, 70)
    zone.Anchored = true
    zone.CanCollide = false
    zone.CanQuery = false
    zone.CanTouch = true
    zone.Material = Enum.Material.ForceField
    zone.Color = Color3.fromRGB(0, 255, 140)
    zone.Transparency = 0.5
    zone.CastShadow = false
    zone.Parent = workspace

    local pad = Instance.new("Part")
    pad.Name = "ExtractionPad"
    pad.Size = Vector3.new(22, 0.4, 22)
    pad.Position = Vector3.new(0, 0.2, 70)
    pad.Anchored = true
    pad.CanCollide = true
    pad.Material = Enum.Material.DiamondPlate
    pad.Color = Color3.fromRGB(40, 45, 55)
    pad.CastShadow = false
    pad.Parent = zone

    return zone
end

local function ResetPlayersForRound()
    for player, inv in playerInventories do
        inv.TotalValue = 0
        inv.TotalWeight = 0
        inv.Items = {}
        inv.Escaped = false
        ApplyLoadoutToPlayer(player, playerActiveLoadouts[player] or Config.Loadouts[1])
        inventoryUpdatedEvent:FireClient(player, inv, "Новый рейд! Загляните к Скупщику в убежище.")
    end
end

task.spawn(function()
    while true do
        ResetPlayersForRound()

        -- Фаза Лобби
        currentPhaseValue.Value = "LobbyPhase"
        for _, p in Players:GetPlayers() do
            if p.Character then p.Character:PivotTo(CFrame.new(math.random(-8, 8), 123, math.random(-8, 8))) end
        end
        stateChangedEvent:FireAllClients("LobbyPhase", Config.LobbyDuration)
        task.wait(Config.LobbyDuration)

        -- Фаза Сбора Лута
        currentPhaseValue.Value = "LootPhase"
        for _, p in Players:GetPlayers() do
            if p.Character then p.Character:PivotTo(CFrame.new(Vector3.new(math.random(-15, 15), 3, -65))) end
        end

        lootContainer:ClearAllChildren()
        weaponsContainer:ClearAllChildren()

        for _, pos in activeLootPositions do
            local item = Config.LootTable[math.random(1, #Config.LootTable)]
            SpawnLootItem(item, pos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
        end

        SpawnGroundWeapon(Vector3.new(30, 13.5, -15))
        SpawnGroundWeapon(Vector3.new(-20, 13.5, 30))

        SpawnLasers()
        CreateGuardNPC(Vector3.new(-15, 3, -15))
        stateChangedEvent:FireAllClients("LootPhase", Config.LootDuration)
        task.wait(Config.LootDuration)

        -- Фаза Эвакуации
        currentPhaseValue.Value = "ExtractionPhase"
        local zone = CreateExtractionZone()
        stateChangedEvent:FireAllClients("ExtractionPhase", Config.ExtractionDuration)

        local phaseEnd = os.clock() + Config.ExtractionDuration
        while os.clock() < phaseEnd do
            task.wait(0.2)

            local overlap = OverlapParams.new()
            overlap.FilterType = Enum.RaycastFilterType.Include
            local chars = {}
            for _, player in Players:GetPlayers() do
                if player.Character then table.insert(chars, player.Character) end
            end
            overlap.FilterDescendantsInstances = chars

            local touchingParts = workspace:GetPartsInPart(zone, overlap)
            local inZone = {}
            for _, part in touchingParts do
                local pl = Players:GetPlayerFromCharacter(part.Parent)
                if pl then inZone[pl] = true end
            end

            for player, _ in inZone do
                local inv = playerInventories[player]
                if inv and not inv.Escaped then
                    if not extractingPlayers[player] then extractingPlayers[player] = os.clock() end
                    local rem = math.max(0, 5 - (os.clock() - extractingPlayers[player]))
                    extractionProgressEvent:FireClient(player, rem, false)

                    if rem <= 0 then
                        inv.Escaped = true
                        extractingPlayers[player] = nil
                        extractionProgressEvent:FireClient(player, 0, true)

                        local leaderstats = player:FindFirstChild("leaderstats")
                        local cash = leaderstats and leaderstats:FindFirstChild("Cash")
                        if cash then cash.Value += inv.TotalValue end
                        SavePlayerData(player)

                        raidSummaryEvent:FireClient(player, true, inv.TotalValue, #inv.Items, (cash and cash.Value) or 0)
                        if player.Character then player.Character:PivotTo(CFrame.new(0, 123, 0)) end
                    end
                end
            end

            for player, _ in extractingPlayers do
                if not inZone[player] then
                    extractingPlayers[player] = nil
                    extractionProgressEvent:FireClient(player, -1, false)
                end
            end
        end

        for player, inv in playerInventories do
            if not inv.Escaped then
                local leaderstats = player:FindFirstChild("leaderstats")
                local cash = leaderstats and leaderstats:FindFirstChild("Cash")
                raidSummaryEvent:FireClient(player, false, 0, 0, (cash and cash.Value) or 0)
            end
        end

        if zone then zone:Destroy() end
        local guard = workspace:FindFirstChild("GuardNPC")
        if guard then guard:Destroy() end
    end
end)

print("[СЕРВЕР]: Сервер готов. Network и цикл раундов функционируют.")