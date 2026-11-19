--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))
local MapConfigs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfigs"))
type MapConfig = MapConfigs.MapConfig

local MapBuilder = {}

local weaponsContainer = workspace:FindFirstChild("GroundWeapons") :: Folder?
if not weaponsContainer then
    weaponsContainer = Instance.new("Folder")
    weaponsContainer.Name = "GroundWeapons"
    weaponsContainer.Parent = workspace
end

local hazardsContainer = workspace:FindFirstChild("Hazards") :: Folder?
if not hazardsContainer then
    hazardsContainer = Instance.new("Folder")
    hazardsContainer.Name = "Hazards"
    hazardsContainer.Parent = workspace
end

local objectivesContainer = workspace:FindFirstChild("Objectives") :: Folder?
if not objectivesContainer then
    objectivesContainer = Instance.new("Folder")
    objectivesContainer.Name = "Objectives"
    objectivesContainer.Parent = workspace
end

function MapBuilder.BuildMap(
    mapConfig: MapConfig,
    onVaultUnlocked: (doorPosition: Vector3, player: Player, withKeycard: boolean) -> ()
): { Vector3 }
    local oldFacility = workspace:FindFirstChild("HeistFacility")
    if oldFacility then oldFacility:Destroy() end

    local facility = Instance.new("Folder")
    facility.Name = "HeistFacility"
    facility.Parent = workspace

    local lootSpawnPoints: { Vector3 } = {}

    local function createPart(name: string, size: Vector3, pos: Vector3, color: Color3?, material: Enum.Material?): Part
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

    -- 1. Пол
    local floorTileSize = 40
    local halfX = math.floor(mapConfig.FloorSize.X / 2)
    local halfZ = math.floor(mapConfig.FloorSize.Z / 2)
    for x = -halfX + 20, halfX - 20, floorTileSize do
        for z = -halfZ + 20, halfZ - 20, floorTileSize do
            createPart("FloorTile", Vector3.new(floorTileSize, 10, floorTileSize), Vector3.new(x, -5, z), Color3.fromRGB(30, 32, 36))
        end
    end

    -- 2. Внешние стены и перегородки
    for _, wall in ipairs(mapConfig.Walls) do
        createPart(wall.Name, wall.Size, wall.Position, wall.Color, wall.Material)
    end

    -- 3. Крыша
    createPart("Roof", Vector3.new(mapConfig.FloorSize.X, 2, mapConfig.FloorSize.Z), Vector3.new(0, 32, 0), Color3.fromRGB(20, 22, 25))

    -- 4. Опорные колонны
    for _, pPos in ipairs(mapConfig.Pillars) do
        createPart("Pillar", Vector3.new(4, 30, 4), pPos, Color3.fromRGB(60, 65, 75), Enum.Material.Metal)
    end

    -- 5. Подвесные балки для крюка
    for _, beam in ipairs(mapConfig.Beams) do
        createPart(beam.Name, beam.Size, beam.Position, beam.Color or Color3.fromRGB(80, 85, 95), beam.Material or Enum.Material.Metal)
    end

    -- 6. Контейнеры и точки спавна на них
    for _, c in ipairs(mapConfig.Containers) do
        createPart("Container", c.Size, c.Pos, c.Color, Enum.Material.DiamondPlate)
        table.insert(lootSpawnPoints, c.Pos + Vector3.new(0, c.Size.Y / 2 + 1.5, 0))
    end

    -- 7. Дополнительные точки спавна лута
    for _, lPos in ipairs(mapConfig.AdditionalLootSpawns) do
        table.insert(lootSpawnPoints, lPos)
    end

    -- 8. Освещение (настенные лампы)
    for _, lPos in ipairs(mapConfig.Lamps) do
        local lampPart = createPart("LampPart", Vector3.new(4, 1, 1), lPos, Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
        local pLight = Instance.new("PointLight")
        pLight.Range = 25
        pLight.Brightness = 1.0
        pLight.Color = Color3.fromRGB(255, 140, 50)
        pLight.Shadows = false
        pLight.Parent = lampPart
    end

    -- 9. Хранилище с дверью и терминалом
    for _, vWall in ipairs(mapConfig.Vault.Walls) do
        createPart(vWall.Name, vWall.Size, vWall.Position, Color3.fromRGB(20, 22, 25), Enum.Material.Metal)
    end

    local vaultDoor = createPart("VaultDoor", mapConfig.Vault.DoorSize, mapConfig.Vault.DoorPos, Color3.fromRGB(180, 50, 50), Enum.Material.DiamondPlate)

    local doorPrompt = Instance.new("ProximityPrompt")
    doorPrompt.ActionText = Locale.Get("HackVaultPrompt")
    doorPrompt.ObjectText = Locale.Get("VaultDoorName")
    doorPrompt.KeyboardKeyCode = Enum.KeyCode.E
    doorPrompt.HoldDuration = 2.0
    doorPrompt.MaxActivationDistance = 9
    doorPrompt.RequiresLineOfSight = false
    doorPrompt.Parent = vaultDoor

    doorPrompt.Triggered:Connect(function(player: Player)
        local character = player.Character
        local hasKeycard = character and character:FindFirstChild("Keycard") ~= nil
            or (player:FindFirstChild("Backpack") and (player:FindFirstChild("Backpack") :: Backpack):FindFirstChild("Keycard") ~= nil)

        doorPrompt.Enabled = false
        vaultDoor.Transparency = 0.8
        vaultDoor.CanCollide = false
        vaultDoor.Color = Color3.fromRGB(50, 200, 80)

        if hasKeycard then
            local card = character and character:FindFirstChild("Keycard") or (player:FindFirstChild("Backpack") and (player:FindFirstChild("Backpack") :: Backpack):FindFirstChild("Keycard"))
            if card then card:Destroy() end
        end

        if onVaultUnlocked then
            onVaultUnlocked(vaultDoor.Position, player, hasKeycard)
        end
    end)

    for _, vLootPos in ipairs(mapConfig.Vault.LootPositions) do
        table.insert(lootSpawnPoints, vLootPos)
    end

    return lootSpawnPoints
end

function MapBuilder.SpawnKeycard(spawnPositions: { Vector3 })
    if not objectivesContainer then return end
    objectivesContainer:ClearAllChildren()

    if #spawnPositions == 0 then return end
    local chosenPos = spawnPositions[math.random(1, #spawnPositions)]

    local cardPart = Instance.new("Part")
    cardPart.Name = "KeycardPickup"
    cardPart.Size = Vector3.new(1.2, 0.2, 0.8)
    cardPart.CFrame = CFrame.new(chosenPos)
    cardPart.Material = Enum.Material.Neon
    cardPart.Color = Color3.fromRGB(0, 255, 200)
    cardPart.Anchored = true
    cardPart.CanCollide = false
    cardPart.CastShadow = false
    cardPart.Parent = objectivesContainer

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = Locale.Get("TakePrompt")
    prompt.ObjectText = Locale.Get("KeycardItemName")
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.2
    prompt.MaxActivationDistance = 8
    prompt.RequiresLineOfSight = false
    prompt.Parent = cardPart

    prompt.Triggered:Connect(function(player: Player)
        local backpack = player:FindFirstChild("Backpack")
        if not backpack or backpack:FindFirstChild("Keycard") then return end

        local tool = Instance.new("Tool")
        tool.Name = "Keycard"
        tool.RequiresHandle = true
        tool.CanBeDropped = true

        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(1.0, 0.2, 0.6)
        handle.Color = Color3.fromRGB(0, 255, 200)
        handle.Material = Enum.Material.Neon
        handle.Parent = tool

        tool.Parent = backpack
        cardPart:Destroy()
    end)
end

function MapBuilder.SpawnLasers(lasersConfig: { { Pos: Vector3, Size: Vector3 } }, onLaserHit: (player: Player, laserPos: Vector3) -> ())
    if not hazardsContainer then return end
    hazardsContainer:ClearAllChildren()

    local playerHitTimes: { [Player]: number } = {}

    for _, lData in ipairs(lasersConfig) do
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
            local player = char and Players:GetPlayerFromCharacter(char)
            if not pHum or not player or pHum.Health <= 0 or player.Character ~= char then return end

            local now = os.clock()
            local lastHit = playerHitTimes[player]
            if lastHit and now - lastHit < 1 then return end

            playerHitTimes[player] = now
            pHum:TakeDamage(10)
            if onLaserHit then
                onLaserHit(player, laser.Position)
            end
        end)
    end
end

function MapBuilder.ClearGroundWeapons()
    if weaponsContainer then
        weaponsContainer:ClearAllChildren()
    end
end

function MapBuilder.SpawnGroundWeapons(spawnPositions: { Vector3 })
    if not weaponsContainer then return end
    weaponsContainer:ClearAllChildren()

    for _, spawnPos in ipairs(spawnPositions) do
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
        prompt.ActionText = Locale.Get("TakePrompt")
        prompt.ObjectText = Locale.Get("TaserPickupName")
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.HoldDuration = 0.2
        prompt.MaxActivationDistance = 8
        prompt.RequiresLineOfSight = false
        prompt.Parent = weaponPart

        prompt.Triggered:Connect(function(player: Player)
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
        end)
    end
end

return MapBuilder
