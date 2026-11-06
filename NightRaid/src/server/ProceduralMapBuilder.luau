local MapBuilder = {}

local ARENA_SIZE = 160
local FLOOR_TOP = 0
local FLOOR_LOOT_HEIGHT = FLOOR_TOP + 0.7

local function rotate(position: Vector3, turns: number): Vector3
    for _ = 1, turns % 4 do
        position = Vector3.new(-position.Z, position.Y, position.X)
    end
    return position
end

function MapBuilder.BuildFacility(seed: number?, onVaultAlarm: ((Player, Vector3) -> ())?)
    local random = Random.new(seed or math.floor(os.clock() * 1000000))
    local rotation = random:NextInteger(0, 3)

    local old = workspace:FindFirstChild("HeistFacility")
    if old then old:Destroy() end

    local facility = Instance.new("Folder")
    facility.Name = "HeistFacility"
    facility.Parent = workspace

    local function part(
        name: string,
        size: Vector3,
        position: Vector3,
        color: Color3,
        material: Enum.Material?,
        transparency: number?
    )
        local object = Instance.new("Part")
        object.Name = name
        object.Size = size
        object.Position = position
        object.Anchored = true
        object.Material = material or Enum.Material.Concrete
        object.Color = color
        object.Transparency = transparency or 0
        object.CastShadow = false
        object.TopSurface = Enum.SurfaceType.Smooth
        object.BottomSurface = Enum.SurfaceType.Smooth
        object.Parent = facility
        return object
    end

    local function place(
        name: string,
        size: Vector3,
        position: Vector3,
        color: Color3,
        material: Enum.Material?,
        transparency: number?
    )
        if rotation % 2 == 1 then
            size = Vector3.new(size.Z, size.Y, size.X)
        end
        return part(name, size, rotate(position, rotation), color, material, transparency)
    end

    local concrete = Color3.fromRGB(37, 40, 46)
    local wallColor = Color3.fromRGB(48, 53, 61)
    local steel = Color3.fromRGB(66, 73, 82)
    local darkSteel = Color3.fromRGB(25, 29, 35)
    local amber = Color3.fromRGB(255, 145, 45)
    local cyan = Color3.fromRGB(35, 190, 205)

    -- Main industrial shell.
    part("Floor", Vector3.new(ARENA_SIZE, 10, ARENA_SIZE), Vector3.new(0, -5, 0), concrete)
    part("Roof", Vector3.new(ARENA_SIZE, 2, ARENA_SIZE), Vector3.new(0, 32, 0), darkSteel)
    for _, wall in ipairs({
        { Vector3.new(160, 32, 4), Vector3.new(0, 16, -80) },
        { Vector3.new(160, 32, 4), Vector3.new(0, 16, 80) },
        { Vector3.new(4, 32, 160), Vector3.new(-80, 16, 0) },
        { Vector3.new(4, 32, 160), Vector3.new(80, 16, 0) },
    }) do
        part("PerimeterWall", wall[1], wall[2], wallColor)
    end

    -- A central security checkpoint separates the entrance from the facility.
    -- The wide middle opening keeps the route readable and navigable.
    place("CheckpointWest", Vector3.new(2, 15, 44), Vector3.new(-45, 7.5, 24), wallColor)
    place("CheckpointEast", Vector3.new(2, 15, 44), Vector3.new(45, 7.5, 24), wallColor)
    place("CheckpointHeader", Vector3.new(92, 4, 2), Vector3.new(0, 15, 24), darkSteel)

    -- Short partitions define the storage and security sectors without blocking patrol routes.
    place("StoragePartitionA", Vector3.new(2, 12, 20), Vector3.new(-63, 6, -22), wallColor)
    place("StoragePartitionB", Vector3.new(24, 12, 2), Vector3.new(-50, 6, -32), wallColor)
    place("SecurityPartitionA", Vector3.new(2, 12, 20), Vector3.new(63, 6, -22), wallColor)
    place("SecurityPartitionB", Vector3.new(24, 12, 2), Vector3.new(50, 6, -32), wallColor)

    -- Vault room with a proper doorway and an interactive security door.
    place("VaultWest", Vector3.new(2, 14, 20), Vector3.new(-12, 7, -52), darkSteel)
    place("VaultEast", Vector3.new(2, 14, 20), Vector3.new(12, 7, -52), darkSteel)
    place("VaultNorth", Vector3.new(26, 14, 2), Vector3.new(0, 7, -62), darkSteel)
    place("VaultRoof", Vector3.new(26, 2, 22), Vector3.new(0, 14, -52), darkSteel)

    local door = place("VaultDoor", Vector3.new(9, 12, 1.5), Vector3.new(0, 6, -42), Color3.fromRGB(145, 48, 42), Enum.Material.DiamondPlate)
    local doorPanel = Instance.new("Part")
    doorPanel.Name = "VaultDoorPanel"
    doorPanel.Size = Vector3.new(0.35, 8, 0.35)
    doorPanel.Position = door.Position + Vector3.new(-3, 0, -0.9)
    doorPanel.Anchored = true
    doorPanel.Material = Enum.Material.Neon
    doorPanel.Color = amber
    doorPanel.CanCollide = false
    doorPanel.CastShadow = false
    doorPanel.Parent = facility

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Взломать"
    prompt.ObjectText = "Сейфовая дверь"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 2.5
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = door

    prompt.Triggered:Connect(function(player)
        if player:GetAttribute("Eliminated") then return end
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 or not prompt.Enabled then return end

        prompt.Enabled = false
        door.Transparency = 0.8
        door.CanCollide = false
        door.Color = Color3.fromRGB(50, 200, 80)
        doorPanel.Color = Color3.fromRGB(50, 255, 120)
        if onVaultAlarm then
            onVaultAlarm(player, door.Position)
        end
    end)

    -- Painted floor lanes and sector markers make the layout easier to read.
    place("EntranceLane", Vector3.new(5, 0.15, 42), Vector3.new(0, 0.08, 56), amber, Enum.Material.Neon, 0.35)
    place("MainAisle", Vector3.new(3, 0.12, 76), Vector3.new(0, 0.07, -13), cyan, Enum.Material.Neon, 0.55)
    place("StorageLane", Vector3.new(3, 0.12, 28), Vector3.new(-52, 0.07, -18), amber, Enum.Material.Neon, 0.55)
    place("SecurityLane", Vector3.new(3, 0.12, 28), Vector3.new(52, 0.07, -18), Color3.fromRGB(220, 55, 55), Enum.Material.Neon, 0.55)

    -- Industrial support columns, ceiling beams and cable trays.
    for _, x in ipairs({ -70, -35, 35, 70 }) do
        for _, z in ipairs({ -68, 0, 48 }) do
            place("SupportColumn", Vector3.new(3, 27, 3), Vector3.new(x, 13.5, z), darkSteel, Enum.Material.Metal)
            place("ColumnBase", Vector3.new(5, 1, 5), Vector3.new(x, 0.5, z), steel, Enum.Material.DiamondPlate)
        end
    end
    for _, z in ipairs({ -68, -5, 48 }) do
        place("CeilingBeam", Vector3.new(150, 1.5, 2), Vector3.new(0, 29, z), steel, Enum.Material.Metal)
    end
    place("CableTray", Vector3.new(2, 1, 130), Vector3.new(-22, 26, 0), steel, Enum.Material.Metal)
    place("CableTray", Vector3.new(2, 1, 130), Vector3.new(22, 26, 0), steel, Enum.Material.Metal)

    -- Equipment props replace the repetitive shipping-container look.
    local function equipment(name: string, position: Vector3, size: Vector3, accent: Color3)
        local body = place(name, size, position, steel, Enum.Material.Metal)
        local panelPosition = position + Vector3.new(0, 0, size.Z / 2 + 0.08)
        local panel = place(name .. "Panel", Vector3.new(size.X * 0.55, size.Y * 0.45, 0.15), panelPosition, darkSteel, Enum.Material.Metal)
        local indicator = place(name .. "Indicator", Vector3.new(0.35, 0.35, 0.2), panelPosition + Vector3.new(0, 0, 0.12), accent, Enum.Material.Neon)
        indicator.CanCollide = false
        return body, panel
    end

    equipment("GeneratorUnit", Vector3.new(-52, 5, -48), Vector3.new(12, 10, 8), amber)
    equipment("PowerControl", Vector3.new(52, 5, -48), Vector3.new(10, 10, 8), cyan)
    equipment("ServerRack", Vector3.new(-58, 6, 4), Vector3.new(7, 12, 7), cyan)
    equipment("SecurityConsole", Vector3.new(58, 5, 4), Vector3.new(9, 10, 7), Color3.fromRGB(220, 55, 55))

    -- Low cover objects are useful in gameplay and visually break up the open floor.
    local covers = {
        Vector3.new(-35, 2.5, 5),
        Vector3.new(35, 2.5, 5),
        Vector3.new(-20, 2.5, 42),
        Vector3.new(20, 2.5, 42),
        Vector3.new(-45, 2.5, -5),
        Vector3.new(45, 2.5, -5),
    }
    for i = #covers, 2, -1 do
        local j = random:NextInteger(1, i)
        covers[i], covers[j] = covers[j], covers[i]
    end
    for i = 1, 4 do
        local size = Vector3.new(random:NextInteger(7, 11), 5, random:NextInteger(5, 8))
        place("LowCover", size, covers[i], darkSteel, Enum.Material.Metal)
        place("CoverStripe", Vector3.new(size.X * 0.8, 0.2, 0.25), covers[i] + Vector3.new(0, 1.2, size.Z / 2 + 0.14), amber, Enum.Material.Neon)
    end

    -- Ceiling lamps and colored status lights.
    for _, position in ipairs({
        Vector3.new(-55, 27, -55),
        Vector3.new(0, 27, -20),
        Vector3.new(55, 27, -55),
        Vector3.new(-55, 27, 38),
        Vector3.new(0, 27, 58),
        Vector3.new(55, 27, 38),
    }) do
        local lamp = place("IndustrialLamp", Vector3.new(5, 0.8, 2), position, amber, Enum.Material.Neon)
        local light = Instance.new("PointLight")
        light.Range = 28
        light.Brightness = 1.2
        light.Color = amber
        light.Parent = lamp
    end

    local loot = {}
    -- Loot is deliberately placed on the floor, not above props.
    -- SpawnLootItem creates a 1.4-stud item, so Y=0.7 puts its bottom on the floor.
    local floorSlots = {
        Vector3.new(-55, FLOOR_LOOT_HEIGHT, -20),
        Vector3.new(-42, FLOOR_LOOT_HEIGHT, 12),
        Vector3.new(-18, FLOOR_LOOT_HEIGHT, 8),
        Vector3.new(18, FLOOR_LOOT_HEIGHT, 8),
        Vector3.new(42, FLOOR_LOOT_HEIGHT, 12),
        Vector3.new(55, FLOOR_LOOT_HEIGHT, -20),
        Vector3.new(-8, FLOOR_LOOT_HEIGHT, -25),
        Vector3.new(8, FLOOR_LOOT_HEIGHT, 42),
    }
    for i = #floorSlots, 2, -1 do
        local j = random:NextInteger(1, i)
        floorSlots[i], floorSlots[j] = floorSlots[j], floorSlots[i]
    end
    for i = 1, 6 do
        table.insert(loot, rotate(floorSlots[i], rotation))
    end

    local lasers = {
        { Pos = rotate(Vector3.new(-48, 2.5, -5), rotation), Size = rotation % 2 == 1 and Vector3.new(0.4, 0.4, 28) or Vector3.new(28, 0.4, 0.4) },
        { Pos = rotate(Vector3.new(48, 2.5, -5), rotation), Size = rotation % 2 == 1 and Vector3.new(0.4, 0.4, 28) or Vector3.new(28, 0.4, 0.4) },
        { Pos = rotate(Vector3.new(0, 2.5, -30), rotation), Size = rotation % 2 == 1 and Vector3.new(0.4, 0.4, 18) or Vector3.new(18, 0.4, 0.4) },
    }

    local patrol = {
        Vector3.new(-55, 3, -25),
        Vector3.new(0, 3, -25),
        Vector3.new(55, 3, -25),
        Vector3.new(55, 3, 38),
        Vector3.new(0, 3, 48),
        Vector3.new(-55, 3, 38),
    }
    for i, point in ipairs(patrol) do
        patrol[i] = rotate(point, rotation)
    end

    return {
        LootSpawnPoints = loot,
        LaserConfigs = lasers,
        GuardWaypoints = patrol,
        GuardSpawnPosition = rotate(Vector3.new(0, 3, -15), rotation),
        ExtractionPosition = rotate(Vector3.new(0, 4, 70), rotation),
        RaidSpawnPosition = rotate(Vector3.new(0, 3, 65), rotation),
        VaultLootPosition = rotate(Vector3.new(0, FLOOR_LOOT_HEIGHT, -52), rotation),
        TaserPositions = {
            rotate(Vector3.new(-35, 1.3, 8), rotation),
            rotate(Vector3.new(35, 1.3, 8), rotation),
        },
        Rotation = rotation,
    }
end

return MapBuilder
