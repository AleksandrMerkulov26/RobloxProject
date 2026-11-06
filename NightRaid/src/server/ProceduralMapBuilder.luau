local MapBuilder = {}

local function rotate(position: Vector3, turns: number): Vector3
    for _ = 1, turns % 4 do position = Vector3.new(-position.Z, position.Y, position.X) end
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

    local function part(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?)
        local object = Instance.new("Part")
        object.Name, object.Size, object.Position = name, size, position
        object.Anchored, object.Material, object.Color = true, material or Enum.Material.Concrete, color
        object.CastShadow, object.Parent = false, facility
        return object
    end
    local function place(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?)
        if rotation % 2 == 1 then size = Vector3.new(size.Z, size.Y, size.X) end
        return part(name, size, rotate(position, rotation), color, material)
    end

    part("Floor", Vector3.new(160, 10, 160), Vector3.new(0, -5, 0), Color3.fromRGB(30, 32, 36))
    part("Roof", Vector3.new(160, 2, 160), Vector3.new(0, 32, 0), Color3.fromRGB(20, 22, 25))
    for _, wall in ipairs({
        { Vector3.new(160, 32, 4), Vector3.new(0, 16, -80) },
        { Vector3.new(160, 32, 4), Vector3.new(0, 16, 80) },
        { Vector3.new(4, 32, 160), Vector3.new(-80, 16, 0) },
        { Vector3.new(4, 32, 160), Vector3.new(80, 16, 0) },
    }) do part("PerimeterWall", wall[1], wall[2], Color3.fromRGB(45, 48, 55)) end

    local loot = {}
    local cargo = {
        Vector3.new(-48, 6, -20), Vector3.new(-28, 6, 12), Vector3.new(-48, 6, 32),
        Vector3.new(28, 6, -20), Vector3.new(48, 6, 12), Vector3.new(28, 6, 32),
        Vector3.new(-18, 6, -48), Vector3.new(18, 6, -48),
    }
    for i = #cargo, 2, -1 do local j = random:NextInteger(1, i); cargo[i], cargo[j] = cargo[j], cargo[i] end
    local colors = { Color3.fromRGB(150,40,40), Color3.fromRGB(40,80,150), Color3.fromRGB(45,120,60), Color3.fromRGB(160,100,30) }
    for i = 1, random:NextInteger(5, 7) do
        local size = random:NextInteger(1, 2) == 1 and Vector3.new(14,12,24) or Vector3.new(24,12,14)
        place("CargoContainer", size, cargo[i], colors[random:NextInteger(1,#colors)], Enum.Material.DiamondPlate)
        table.insert(loot, rotate(cargo[i] + Vector3.new(0,7.5,0), rotation))
    end

    local covers = { Vector3.new(-62,3,-5), Vector3.new(-35,3,48), Vector3.new(35,3,48), Vector3.new(62,3,-5), Vector3.new(-8,3,8), Vector3.new(8,3,-12) }
    for i = #covers, 2, -1 do local j = random:NextInteger(1,i); covers[i],covers[j] = covers[j],covers[i] end
    for i = 1, 4 do place("Cover", Vector3.new(random:NextInteger(8,14),6,random:NextInteger(5,9)), covers[i], Color3.fromRGB(65,70,78), Enum.Material.Metal) end

    place("VaultWest", Vector3.new(2,14,20), Vector3.new(-10,7,-48), Color3.fromRGB(20,22,25), Enum.Material.Metal)
    place("VaultEast", Vector3.new(2,14,20), Vector3.new(10,7,-48), Color3.fromRGB(20,22,25), Enum.Material.Metal)
    place("VaultNorth", Vector3.new(20,14,2), Vector3.new(0,7,-58), Color3.fromRGB(20,22,25), Enum.Material.Metal)
    place("VaultRoof", Vector3.new(20,2,20), Vector3.new(0,14,-48), Color3.fromRGB(15,18,20), Enum.Material.Metal)
    local door = place("VaultDoor", Vector3.new(18,12,1.5), Vector3.new(0,6,-38), Color3.fromRGB(180,50,50), Enum.Material.DiamondPlate)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText, prompt.ObjectText, prompt.KeyboardKeyCode = "Взломать", "Сейфовая дверь", Enum.KeyCode.E
    prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 2.5, 9, false
    prompt.Parent = door
    prompt.Triggered:Connect(function(player)
        if player:GetAttribute("Eliminated") then return end
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 or not prompt.Enabled then return end
        prompt.Enabled, door.Transparency, door.CanCollide = false, 0.8, false
        door.Color = Color3.fromRGB(50,200,80)
        if onVaultAlarm then onVaultAlarm(player, door.Position) end
    end)

    for _, position in ipairs({ Vector3.new(0,20,-78), Vector3.new(0,20,78), Vector3.new(-78,20,0), Vector3.new(78,20,0) }) do
        local lamp = place("IndustrialLamp", Vector3.new(4,1,1), position, Color3.fromRGB(255,120,40), Enum.Material.Neon)
        local light = Instance.new("PointLight")
        light.Range, light.Brightness, light.Color = 25, 1, Color3.fromRGB(255,140,50)
        light.Parent = lamp
    end

    local floorSlots = { Vector3.new(-60,1.5,-35), Vector3.new(-20,1.5,20), Vector3.new(20,1.5,20), Vector3.new(60,1.5,-35), Vector3.new(-55,1.5,48), Vector3.new(55,1.5,48), Vector3.new(-5,1.5,-62), Vector3.new(5,1.5,48) }
    for i = #floorSlots, 2, -1 do local j = random:NextInteger(1,i); floorSlots[i],floorSlots[j] = floorSlots[j],floorSlots[i] end
    for i = 1, 5 do table.insert(loot, rotate(floorSlots[i], rotation)) end

    local lasers = {
        { Pos = rotate(Vector3.new(-48,2.5,-5),rotation), Size = rotation%2==1 and Vector3.new(0.4,0.4,28) or Vector3.new(28,0.4,0.4) },
        { Pos = rotate(Vector3.new(48,2.5,-5),rotation), Size = rotation%2==1 and Vector3.new(0.4,0.4,28) or Vector3.new(28,0.4,0.4) },
        { Pos = rotate(Vector3.new(0,2.5,-30),rotation), Size = rotation%2==1 and Vector3.new(0.4,0.4,18) or Vector3.new(18,0.4,0.4) },
    }
    local patrol = { Vector3.new(-55,3,-30), Vector3.new(45,3,-30), Vector3.new(55,3,35), Vector3.new(-45,3,35), Vector3.new(0,3,0) }
    for i,p in ipairs(patrol) do patrol[i] = rotate(p,rotation) end
    return {
        LootSpawnPoints = loot, LaserConfigs = lasers, GuardWaypoints = patrol,
        GuardSpawnPosition = rotate(Vector3.new(-15,3,-15),rotation),
        ExtractionPosition = rotate(Vector3.new(0,4,70),rotation),
        RaidSpawnPosition = rotate(Vector3.new(0,3,65),rotation),
        VaultLootPosition = rotate(Vector3.new(0,1.5,-48),rotation),
        TaserPositions = { rotate(Vector3.new(-35,13.5,8),rotation), rotate(Vector3.new(35,13.5,8),rotation) },
        Rotation = rotation,
    }
end

return MapBuilder
