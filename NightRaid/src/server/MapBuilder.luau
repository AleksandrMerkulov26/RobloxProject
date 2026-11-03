local MapBuilder = {}

function MapBuilder.BuildFacility()
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
        part.Parent = facility
        return part
    end

    -- 1. Пол ангара
    createWall("Floor", Vector3.new(160, 2, 160), Vector3.new(0, -1, 0), Color3.fromRGB(30, 32, 36))

    -- 2. Внешние стены ангара
    createWall("WallNorth", Vector3.new(160, 32, 4), Vector3.new(0, 16, -80))
    createWall("WallSouth", Vector3.new(160, 32, 4), Vector3.new(0, 16, 80))
    createWall("WallWest", Vector3.new(4, 32, 160), Vector3.new(-80, 16, 0))
    createWall("WallEast", Vector3.new(4, 32, 160), Vector3.new(80, 16, 0))

    -- 3. Крыша
    createWall("Roof", Vector3.new(160, 2, 160), Vector3.new(0, 32, 0), Color3.fromRGB(20, 22, 25))

    -- 4. Опорные колонны
    local columnCoords = {
        Vector3.new(-40, 15, -40), Vector3.new(40, 15, -40),
        Vector3.new(-40, 15, 40), Vector3.new(40, 15, 40)
    }

    for _, cPos in columnCoords do
        createWall("Pillar", Vector3.new(4, 30, 4), Vector3.new(cPos.X, 15, cPos.Z), Color3.fromRGB(60, 65, 75), Enum.Material.Metal)
    end

    -- 5. Подвесные балки для крюка
    createWall("BeamNorth", Vector3.new(80, 2, 4), Vector3.new(0, 24, -40), Color3.fromRGB(80, 85, 95), Enum.Material.Metal)
    createWall("BeamSouth", Vector3.new(80, 2, 4), Vector3.new(0, 24, 40), Color3.fromRGB(80, 85, 95), Enum.Material.Metal)
    createWall("BeamWest", Vector3.new(4, 2, 80), Vector3.new(-40, 24, 0), Color3.fromRGB(80, 85, 95), Enum.Material.Metal)
    createWall("BeamEast", Vector3.new(4, 2, 80), Vector3.new(40, 24, 0), Color3.fromRGB(80, 85, 95), Enum.Material.Metal)

    -- 6. Грузовые контейнеры
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

    -- Точки спавна лута на полу
    table.insert(lootSpawnPoints, Vector3.new(0, 1.5, 0))
    table.insert(lootSpawnPoints, Vector3.new(-50, 1.5, -50))
    table.insert(lootSpawnPoints, Vector3.new(50, 1.5, 50))
    table.insert(lootSpawnPoints, Vector3.new(-50, 1.5, 50))
    table.insert(lootSpawnPoints, Vector3.new(50, 1.5, -50))
    table.insert(lootSpawnPoints, Vector3.new(0, 1.5, -60))
    table.insert(lootSpawnPoints, Vector3.new(0, 1.5, 60))

    -- 7. Настенные фонари
    local lampPositions = {
        Vector3.new(0, 20, -78), Vector3.new(0, 20, 78),
        Vector3.new(-78, 20, 0), Vector3.new(78, 20, 0)
    }

    for _, lPos in lampPositions do
        local lampPart = Instance.new("Part")
        lampPart.Size = Vector3.new(4, 1, 1)
        lampPart.Position = lPos
        lampPart.Anchored = true
        lampPart.Material = Enum.Material.Neon
        lampPart.Color = Color3.fromRGB(255, 120, 40)
        lampPart.Parent = facility

        local pLight = Instance.new("PointLight")
        pLight.Range = 30
        pLight.Brightness = 1.2
        pLight.Color = Color3.fromRGB(255, 140, 50)
        pLight.Parent = lampPart
    end

    return lootSpawnPoints
end

return MapBuilder