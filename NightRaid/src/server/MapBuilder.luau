--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))
local MapConfigs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfigs"))
type MapConfig = MapConfigs.MapConfig

local MapBuilder = {}

local weaponsContainer = workspace:FindFirstChild("GroundWeapons") :: Folder?
if not weaponsContainer then
    local folder = Instance.new("Folder")
    folder.Name = "GroundWeapons"
    folder.Parent = workspace
    weaponsContainer = folder
end

local hazardsContainer = workspace:FindFirstChild("Hazards") :: Folder?
if not hazardsContainer then
    local folder = Instance.new("Folder")
    folder.Name = "Hazards"
    folder.Parent = workspace
    hazardsContainer = folder
end

local objectivesContainer = workspace:FindFirstChild("Objectives") :: Folder?
if not objectivesContainer then
    local folder = Instance.new("Folder")
    folder.Name = "Objectives"
    folder.Parent = workspace
    objectivesContainer = folder
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

    local function createPart(
        name: string,
        size: Vector3,
        pos: Vector3,
        color: Color3?,
        material: Enum.Material?,
        transparency: number?,
        canCollide: boolean?
    ): Part
        local part = Instance.new("Part")
        part.Name = name
        part.Size = size
        part.Position = pos
        part.Anchored = true
        part.Material = material or Enum.Material.Concrete
        part.Color = color or Color3.fromRGB(45, 48, 55)
        part.Transparency = transparency or 0
        part.CanCollide = if canCollide ~= nil then canCollide else true
        part.CastShadow = false
        part.Parent = facility
        return part
    end

    -- 1. Пол с плитками и вариативностью
    local floorTileSize = 40
    local halfX = math.floor(mapConfig.FloorSize.X / 2)
    local halfZ = math.floor(mapConfig.FloorSize.Z / 2)
    for x = -halfX + 20, halfX - 20, floorTileSize do
        for z = -halfZ + 20, halfZ - 20, floorTileSize do
            local tileColor = if ((x + z) / floorTileSize) % 2 == 0
                then Color3.fromRGB(32, 34, 38)
                else Color3.fromRGB(28, 30, 34)
            createPart("FloorTile", Vector3.new(floorTileSize, 10, floorTileSize), Vector3.new(x, -5, z), tileColor, Enum.Material.Concrete)
        end
    end

    -- 2. Внешние стены и перегородки
    for _, wall in ipairs(mapConfig.Walls) do
        createPart(wall.Name, wall.Size, wall.Position, wall.Color, wall.Material, wall.Transparency, wall.CanCollide)
    end

    -- 3. Крыша
    createPart("Roof", Vector3.new(mapConfig.FloorSize.X, 2, mapConfig.FloorSize.Z), Vector3.new(0, 34, 0), Color3.fromRGB(20, 22, 25), Enum.Material.Metal)

    -- 4. Опорные колонны
    for _, pPos in ipairs(mapConfig.Pillars) do
        createPart("Pillar", Vector3.new(4, 32, 4), pPos, Color3.fromRGB(60, 65, 75), Enum.Material.Metal)
    end

    -- 5. Подвесные балки
    for _, beam in ipairs(mapConfig.Beams) do
        createPart(beam.Name, beam.Size, beam.Position, beam.Color or Color3.fromRGB(80, 85, 95), beam.Material or Enum.Material.Metal)
    end

    -- 6. Контейнеры
    for _, c in ipairs(mapConfig.Containers) do
        local container = createPart("Container", c.Size, c.Pos, c.Color, Enum.Material.DiamondPlate)
        table.insert(lootSpawnPoints, c.Pos + Vector3.new(0, c.Size.Y / 2 + 1.5, 0))

        -- Углы контейнера для реализма
        createPart("ContTrimT", Vector3.new(c.Size.X + 0.4, 0.6, c.Size.Z + 0.4), c.Pos + Vector3.new(0, c.Size.Y / 2, 0), Color3.fromRGB(30, 32, 36), Enum.Material.Metal)
        createPart("ContTrimB", Vector3.new(c.Size.X + 0.4, 0.6, c.Size.Z + 0.4), c.Pos - Vector3.new(0, c.Size.Y / 2, 0), Color3.fromRGB(30, 32, 36), Enum.Material.Metal)
    end

    -- 7. Индустриальные многоярусные стеллажи (Shelves)
    if mapConfig.Shelves then
        for sIdx, shelf in ipairs(mapConfig.Shelves) do
            local sPos = shelf.Pos
            local sSize = shelf.Size
            local levels = shelf.Levels or 3
            local shelfColor = shelf.Color or Color3.fromRGB(190, 85, 25)

            -- 4 вертикальные стойки
            local hx = sSize.X / 2 - 0.4
            local hz = sSize.Z / 2 - 0.4
            local cornerOffsets = {
                Vector3.new(-hx, 0, -hz),
                Vector3.new(hx, 0, -hz),
                Vector3.new(-hx, 0, hz),
                Vector3.new(hx, 0, hz),
            }
            for _, cOff in ipairs(cornerOffsets) do
                createPart("ShelfPost", Vector3.new(0.8, sSize.Y, 0.8), sPos + cOff, shelfColor, Enum.Material.Metal)
            end

            -- Полки на уровнях
            local levelHeight = sSize.Y / levels
            for lvl = 1, levels do
                local curY = (sPos.Y - sSize.Y / 2) + (lvl * levelHeight)
                local plank = createPart("ShelfPlank", Vector3.new(sSize.X, 0.4, sSize.Z), Vector3.new(sPos.X, curY, sPos.Z), Color3.fromRGB(120, 85, 55), Enum.Material.Wood)

                -- Картонные коробки на полках
                for bIdx = -1, 1 do
                    local boxPos = Vector3.new(sPos.X, curY + 1.2, sPos.Z + (bIdx * (sSize.Z / 3.5)))
                    createPart("CardboardBox", Vector3.new(sSize.X * 0.7, 2, sSize.Z / 4), boxPos, Color3.fromRGB(165, 125, 75), Enum.Material.WoodPlanks)
                end

                -- Точка лута на полке
                table.insert(lootSpawnPoints, Vector3.new(sPos.X, curY + 2.5, sPos.Z))
            end
        end
    end

    -- 8. Пропсы и мебель (Props)
    if mapConfig.Props then
        for _, prop in ipairs(mapConfig.Props) do
            local pPos = prop.Pos
            local pType = prop.Type

            if pType == "BarrelStack" then
                local bColor = prop.Color or Color3.fromRGB(180, 45, 45)
                local barrelOffsets = {
                    Vector3.new(-1.6, 0, -1.6),
                    Vector3.new(1.6, 0, -1.6),
                    Vector3.new(0, 0, 1.4),
                    Vector3.new(0, 4.2, 0), -- 4-я бочка сверху
                }
                for _, bOff in ipairs(barrelOffsets) do
                    local barrel = Instance.new("Part")
                    barrel.Name = "MetalBarrel"
                    barrel.Shape = Enum.PartType.Cylinder
                    barrel.Size = Vector3.new(4.2, 3.2, 3.2)
                    barrel.CFrame = CFrame.new(pPos + bOff) * CFrame.Angles(0, 0, math.rad(90))
                    barrel.Color = bColor
                    barrel.Material = Enum.Material.Metal
                    barrel.Anchored = true
                    barrel.CastShadow = false
                    barrel.Parent = facility
                end
            elseif pType == "PalletStack" then
                for pIdx = 0, 3 do
                    createPart("Pallet", Vector3.new(6, 0.8, 6), pPos + Vector3.new(0, pIdx * 0.8, 0), Color3.fromRGB(140, 105, 65), Enum.Material.WoodPlanks)
                end
            elseif pType == "Crate" then
                local cColor = prop.Color or Color3.fromRGB(150, 115, 70)
                createPart("CargoCrate", Vector3.new(5, 5, 5), pPos, cColor, Enum.Material.WoodPlanks)
                -- Стальная обвязка ящика
                createPart("CrateBand", Vector3.new(5.2, 0.4, 5.2), pPos, Color3.fromRGB(50, 55, 65), Enum.Material.Metal)
            elseif pType == "ServerRack" then
                createPart("ServerFrame", Vector3.new(4, 9, 3), pPos, Color3.fromRGB(25, 28, 35), Enum.Material.Metal)
                -- Мигающие неоновые диоды
                local led1 = createPart("ServerLED_G", Vector3.new(3.4, 0.3, 0.2), pPos + Vector3.new(0, 2, 1.5), Color3.fromRGB(50, 255, 100), Enum.Material.Neon)
                local led2 = createPart("ServerLED_B", Vector3.new(3.4, 0.3, 0.2), pPos + Vector3.new(0, 0, 1.5), Color3.fromRGB(60, 180, 255), Enum.Material.Neon)
                local led3 = createPart("ServerLED_R", Vector3.new(3.4, 0.3, 0.2), pPos - Vector3.new(0, 2, 1.5), Color3.fromRGB(255, 80, 60), Enum.Material.Neon)
            elseif pType == "Desk" then
                createPart("DeskTop", Vector3.new(8, 0.6, 4), pPos + Vector3.new(0, 1.5, 0), Color3.fromRGB(65, 70, 80), Enum.Material.SmoothPlastic)
                createPart("DeskLegL", Vector3.new(0.6, 3, 3.6), pPos + Vector3.new(-3.6, 0, 0), Color3.fromRGB(40, 45, 50), Enum.Material.Metal)
                createPart("DeskLegR", Vector3.new(0.6, 3, 3.6), pPos + Vector3.new(3.6, 0, 0), Color3.fromRGB(40, 45, 50), Enum.Material.Metal)
                -- Монитор компьютера
                createPart("MonitorStand", Vector3.new(0.8, 1, 0.8), pPos + Vector3.new(0, 2.3, 0), Color3.fromRGB(30, 32, 38), Enum.Material.Metal)
                createPart("MonitorScreen", Vector3.new(3.2, 2.0, 0.3), pPos + Vector3.new(0, 3.3, 0), Color3.fromRGB(80, 190, 255), Enum.Material.Neon)
            end
        end
    end

    -- 9. Подвесные мостики (Catwalks) с перилами и лестницами
    if mapConfig.Catwalks then
        for _, cw in ipairs(mapConfig.Catwalks) do
            local cwPos = cw.Pos
            local cwSize = cw.Size
            createPart("CatwalkDeck", cwSize, cwPos, Color3.fromRGB(55, 60, 70), Enum.Material.DiamondPlate)

            -- Перила по бокам (Handrails)
            local railHeight = 3.5
            local railThickness = 0.4
            -- Левые перила
            createPart("RailLeft", Vector3.new(cwSize.X, railThickness, railThickness), cwPos + Vector3.new(0, railHeight, -cwSize.Z / 2), Color3.fromRGB(220, 160, 40), Enum.Material.Metal)
            createPart("RailLeftMid", Vector3.new(cwSize.X, railThickness, railThickness), cwPos + Vector3.new(0, railHeight / 2, -cwSize.Z / 2), Color3.fromRGB(80, 85, 95), Enum.Material.Metal)
            -- Правые перила
            createPart("RailRight", Vector3.new(cwSize.X, railThickness, railThickness), cwPos + Vector3.new(0, railHeight, cwSize.Z / 2), Color3.fromRGB(220, 160, 40), Enum.Material.Metal)
            createPart("RailRightMid", Vector3.new(cwSize.X, railThickness, railThickness), cwPos + Vector3.new(0, railHeight / 2, cwSize.Z / 2), Color3.fromRGB(80, 85, 95), Enum.Material.Metal)

            -- Лестница, если указана
            if cw.StairsPos then
                local stPos = cw.StairsPos
                local rampLength = math.sqrt(math.pow(cwPos.Y, 2) + 200)
                local ramp = createPart("CatwalkStairs", Vector3.new(6, 1, 28), stPos, Color3.fromRGB(65, 70, 80), Enum.Material.DiamondPlate)
                ramp.CFrame = CFrame.new(stPos) * CFrame.Angles(math.rad(30), 0, 0)
            end
        end
    end

    -- 10. Промышленные трубы (Pipes)
    if mapConfig.Pipes then
        for _, pipe in ipairs(mapConfig.Pipes) do
            local delta = pipe.To - pipe.From
            local length = delta.Magnitude
            local mid = (pipe.From + pipe.To) / 2
            local radius = pipe.Radius or 1.0
            local pColor = pipe.Color or Color3.fromRGB(190, 150, 40)

            local pPart = Instance.new("Part")
            pPart.Name = "IndustrialPipe"
            pPart.Shape = Enum.PartType.Cylinder
            pPart.Size = Vector3.new(length, radius * 2, radius * 2)
            pPart.CFrame = CFrame.lookAt(mid, pipe.To) * CFrame.Angles(0, math.rad(90), 0)
            pPart.Color = pColor
            pPart.Material = Enum.Material.Metal
            pPart.Anchored = true
            pPart.CastShadow = false
            pPart.Parent = facility
        end
    end

    -- 11. Дополнительные точки спавна лута
    for _, lPos in ipairs(mapConfig.AdditionalLootSpawns) do
        table.insert(lootSpawnPoints, lPos)
    end

    -- 12. Освещение (настенные лампы)
    for _, lPos in ipairs(mapConfig.Lamps) do
        local lampPart = createPart("LampPart", Vector3.new(4, 1, 1), lPos, Color3.fromRGB(255, 140, 50), Enum.Material.Neon)
        local pLight = Instance.new("PointLight")
        pLight.Range = 32
        pLight.Brightness = 1.2
        pLight.Color = Color3.fromRGB(255, 160, 70)
        pLight.Shadows = false
        pLight.Parent = lampPart
    end

    -- 13. Предупреждающая напольная полосатая разметка перед хранилищем
    local vPos = mapConfig.Vault.DoorPos
    local stripePad = createPart("SafetyStripe", Vector3.new(mapConfig.Vault.DoorSize.X + 6, 0.1, 8), vPos + Vector3.new(0, -vPos.Y + 0.1, 4), Color3.fromRGB(230, 180, 20), Enum.Material.Metal)
    local subStripe = createPart("SafetyStripeBlack", Vector3.new(mapConfig.Vault.DoorSize.X + 6, 0.12, 1.2), vPos + Vector3.new(0, -vPos.Y + 0.12, 4), Color3.fromRGB(25, 25, 25), Enum.Material.Metal)

    -- 14. Хранилище с дверью и терминалом
    for _, vWall in ipairs(mapConfig.Vault.Walls) do
        createPart(vWall.Name, vWall.Size, vWall.Position, vWall.Color or Color3.fromRGB(20, 22, 25), vWall.Material or Enum.Material.Metal)
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
        if player:GetAttribute("Eliminated") == true or player:GetAttribute("IsDowned") == true then return end
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
    cardPart.Position = chosenPos
    cardPart.Anchored = true
    cardPart.CanCollide = false
    cardPart.Material = Enum.Material.Neon
    cardPart.Color = Color3.fromRGB(0, 255, 200)
    cardPart.CastShadow = false
    cardPart.Parent = objectivesContainer

    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(0, 255, 200)
    light.Range = 10
    light.Brightness = 2.0
    light.Parent = cardPart

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = Locale.Get("TakePrompt")
    prompt.ObjectText = Locale.Get("KeycardName")
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 8
    prompt.RequiresLineOfSight = false
    prompt.Parent = cardPart

    local isCardClaimed = false
    prompt.Triggered:Connect(function(player: Player)
        if isCardClaimed then return end
        if player:GetAttribute("Eliminated") == true or player:GetAttribute("IsDowned") == true then return end
        local backpack = player:FindFirstChild("Backpack")
        if not backpack then return end

        isCardClaimed = true
        prompt.Enabled = false

        local tool = Instance.new("Tool")
        tool.Name = "Keycard"
        tool.RequiresHandle = true
        tool.CanBeDropped = false

        local handle = Instance.new("Part")
        handle.Name = "Handle"
        handle.Size = Vector3.new(1.2, 0.2, 0.8)
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
        prompt.HoldDuration = 0.5
        prompt.MaxActivationDistance = 8
        prompt.RequiresLineOfSight = false
        prompt.Parent = weaponPart

        local isWeaponClaimed = false
        prompt.Triggered:Connect(function(player: Player)
            if isWeaponClaimed then return end
            if player:GetAttribute("Eliminated") == true or player:GetAttribute("IsDowned") == true then return end
            local backpack = player:FindFirstChild("Backpack")
            if not backpack then return end

            isWeaponClaimed = true
            prompt.Enabled = false

            local tool = Instance.new("Tool")
            tool.Name = "Taser"
            tool.RequiresHandle = true
            tool.CanBeDropped = false

            local handle = Instance.new("Part")
            handle.Name = "Handle"
            handle.Size = Vector3.new(1.8, 0.6, 1.2)
            handle.Color = Color3.fromRGB(240, 200, 30)
            handle.Material = Enum.Material.Metal
            handle.Parent = tool

            tool.Parent = backpack
            weaponPart:Destroy()
        end)
    end
end

return MapBuilder
