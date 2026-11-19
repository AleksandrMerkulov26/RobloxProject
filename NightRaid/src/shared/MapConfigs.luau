--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

export type PartConfig = {
    Name: string,
    Size: Vector3,
    Position: Vector3,
    Color: Color3?,
    Material: Enum.Material?,
}

export type ContainerConfig = {
    Size: Vector3,
    Pos: Vector3,
    Color: Color3,
}

export type MapConfig = {
    Id: string,
    NameKey: string,
    Name: string,
    FloorSize: Vector3,
    Walls: { PartConfig },
    Pillars: { Vector3 },
    Beams: { PartConfig },
    Containers: { ContainerConfig },
    Lamps: { Vector3 },
    Lasers: { { Pos: Vector3, Size: Vector3 } },
    Vault: {
        DoorPos: Vector3,
        DoorSize: Vector3,
        Walls: { PartConfig },
        LootPositions: { Vector3 },
    },
    ExtractionPos: Vector3,
    WeaponSpawns: { Vector3 },
    GuardSpawns: { Vector3 },
    KeycardSpawns: { Vector3 },
    AdditionalLootSpawns: { Vector3 },
}

local MapConfigs: { [string]: MapConfig } = {}

-- 1. КАРТА: INDUSTRIAL WAREHOUSE (Классический ангар)
MapConfigs["Warehouse"] = {
    Id = "Warehouse",
    NameKey = "Map_Warehouse_Name",
    Name = Locale.Get("Map_Warehouse_Name"),
    FloorSize = Vector3.new(160, 10, 160),
    Walls = {
        { Name = "WallNorth", Size = Vector3.new(160, 32, 4), Position = Vector3.new(0, 16, -80) },
        { Name = "WallSouth", Size = Vector3.new(160, 32, 4), Position = Vector3.new(0, 16, 80) },
        { Name = "WallWest", Size = Vector3.new(4, 32, 160), Position = Vector3.new(-80, 16, 0) },
        { Name = "WallEast", Size = Vector3.new(4, 32, 160), Position = Vector3.new(80, 16, 0) },
    },
    Pillars = {
        Vector3.new(-40, 15, -40), Vector3.new(40, 15, -40),
        Vector3.new(-40, 15, 40), Vector3.new(40, 15, 40)
    },
    Beams = {
        { Name = "BeamNorth", Size = Vector3.new(80, 2, 4), Position = Vector3.new(0, 24, -40) },
        { Name = "BeamSouth", Size = Vector3.new(80, 2, 4), Position = Vector3.new(0, 24, 40) },
    },
    Containers = {
        { Pos = Vector3.new(-25, 6, -20), Size = Vector3.new(14, 12, 28), Color = Color3.fromRGB(150, 40, 40) },
        { Pos = Vector3.new(30, 6, -15), Size = Vector3.new(28, 12, 14), Color = Color3.fromRGB(40, 80, 150) },
        { Pos = Vector3.new(-20, 6, 30), Size = Vector3.new(24, 12, 14), Color = Color3.fromRGB(45, 120, 60) },
        { Pos = Vector3.new(25, 6, 35), Size = Vector3.new(14, 12, 24), Color = Color3.fromRGB(160, 100, 30) },
        { Pos = Vector3.new(-25, 18, -20), Size = Vector3.new(14, 12, 24), Color = Color3.fromRGB(70, 75, 85) }
    },
    Lamps = {
        Vector3.new(0, 20, -78), Vector3.new(0, 20, 78),
        Vector3.new(-78, 20, 0), Vector3.new(78, 20, 0)
    },
    Lasers = {
        { Pos = Vector3.new(0, 2.5, -15), Size = Vector3.new(50, 0.4, 0.4) },
        { Pos = Vector3.new(0, 2.5, 25), Size = Vector3.new(50, 0.4, 0.4) },
        { Pos = Vector3.new(60, 2.5, -20), Size = Vector3.new(18, 0.4, 0.4) }
    },
    Vault = {
        DoorPos = Vector3.new(60, 6, -20),
        DoorSize = Vector3.new(18, 12, 1.5),
        Walls = {
            { Name = "VaultWallW", Size = Vector3.new(2, 14, 20), Position = Vector3.new(50, 7, -30) },
            { Name = "VaultWallN", Size = Vector3.new(20, 14, 2), Position = Vector3.new(60, 7, -40) },
            { Name = "VaultRoof", Size = Vector3.new(20, 2, 20), Position = Vector3.new(60, 14, -30) },
        },
        LootPositions = {
            Vector3.new(60, 1.5, -30),
            Vector3.new(65, 1.5, -35),
        }
    },
    ExtractionPos = Vector3.new(0, 4, 70),
    WeaponSpawns = {
        Vector3.new(30, 13.5, -15),
        Vector3.new(-20, 13.5, 30),
    },
    GuardSpawns = {
        Vector3.new(-15, 3, -15),
    },
    KeycardSpawns = {
        Vector3.new(-25, 12.5, -20),
        Vector3.new(25, 12.5, 35),
    },
    AdditionalLootSpawns = {
        Vector3.new(0, 1.5, 0),
        Vector3.new(-50, 1.5, -50),
        Vector3.new(50, 1.5, 50),
        Vector3.new(-50, 1.5, 50),
        Vector3.new(50, 1.5, -50),
    }
}

-- 2. КАРТА: ARCHIVE VAULT (Подземный депозитарий / архив с коридорами)
MapConfigs["Archive"] = {
    Id = "Archive",
    NameKey = "Map_Archive_Name",
    Name = Locale.Get("Map_Archive_Name"),
    FloorSize = Vector3.new(150, 10, 150),
    Walls = {
        { Name = "WallNorth", Size = Vector3.new(150, 24, 4), Position = Vector3.new(0, 12, -75), Color = Color3.fromRGB(35, 40, 48), Material = Enum.Material.Concrete },
        { Name = "WallSouth", Size = Vector3.new(150, 24, 4), Position = Vector3.new(0, 12, 75), Color = Color3.fromRGB(35, 40, 48), Material = Enum.Material.Concrete },
        { Name = "WallWest", Size = Vector3.new(4, 24, 150), Position = Vector3.new(-75, 12, 0), Color = Color3.fromRGB(35, 40, 48), Material = Enum.Material.Concrete },
        { Name = "WallEast", Size = Vector3.new(4, 24, 150), Position = Vector3.new(75, 12, 0), Color = Color3.fromRGB(35, 40, 48), Material = Enum.Material.Concrete },
        -- Внутренние перегородки депозитария
        { Name = "PartitionA", Size = Vector3.new(60, 20, 3), Position = Vector3.new(-30, 10, -25), Color = Color3.fromRGB(48, 54, 64), Material = Enum.Material.Metal },
        { Name = "PartitionB", Size = Vector3.new(60, 20, 3), Position = Vector3.new(30, 10, 25), Color = Color3.fromRGB(48, 54, 64), Material = Enum.Material.Metal },
        { Name = "ArchiveRow1", Size = Vector3.new(4, 14, 45), Position = Vector3.new(-15, 7, 10), Color = Color3.fromRGB(60, 65, 75), Material = Enum.Material.DiamondPlate },
        { Name = "ArchiveRow2", Size = Vector3.new(4, 14, 45), Position = Vector3.new(15, 7, -10), Color = Color3.fromRGB(60, 65, 75), Material = Enum.Material.DiamondPlate },
    },
    Pillars = {
        Vector3.new(-35, 12, -35), Vector3.new(35, 12, -35),
        Vector3.new(-35, 12, 35), Vector3.new(35, 12, 35)
    },
    Beams = {
        { Name = "VaultRailingNorth", Size = Vector3.new(90, 2, 3), Position = Vector3.new(0, 18, -30) },
        { Name = "VaultRailingSouth", Size = Vector3.new(90, 2, 3), Position = Vector3.new(0, 18, 30) },
    },
    Containers = {
        { Pos = Vector3.new(-45, 4, 10), Size = Vector3.new(8, 8, 20), Color = Color3.fromRGB(45, 55, 70) },
        { Pos = Vector3.new(45, 4, -10), Size = Vector3.new(8, 8, 20), Color = Color3.fromRGB(45, 55, 70) },
        { Pos = Vector3.new(0, 4, -50), Size = Vector3.new(24, 8, 8), Color = Color3.fromRGB(30, 40, 50) },
    },
    Lamps = {
        Vector3.new(-30, 18, -73), Vector3.new(30, 18, -73),
        Vector3.new(-30, 18, 73), Vector3.new(30, 18, 73),
        Vector3.new(-73, 18, 0), Vector3.new(73, 18, 0),
    },
    Lasers = {
        { Pos = Vector3.new(-15, 2.5, -25), Size = Vector3.new(30, 0.4, 0.4) },
        { Pos = Vector3.new(15, 2.5, 25), Size = Vector3.new(30, 0.4, 0.4) },
        { Pos = Vector3.new(0, 2.5, 0), Size = Vector3.new(28, 0.4, 0.4) }
    },
    Vault = {
        DoorPos = Vector3.new(0, 6, -65),
        DoorSize = Vector3.new(16, 12, 1.5),
        Walls = {
            { Name = "VaultW", Size = Vector3.new(2, 14, 18), Position = Vector3.new(-10, 7, -72) },
            { Name = "VaultE", Size = Vector3.new(2, 14, 18), Position = Vector3.new(10, 7, -72) },
            { Name = "VaultRoof", Size = Vector3.new(20, 2, 18), Position = Vector3.new(0, 14, -72) },
        },
        LootPositions = {
            Vector3.new(-4, 1.5, -70),
            Vector3.new(4, 1.5, -70),
        }
    },
    ExtractionPos = Vector3.new(0, 4, 65),
    WeaponSpawns = {
        Vector3.new(-30, 9, -25),
        Vector3.new(30, 9, 25),
    },
    GuardSpawns = {
        Vector3.new(0, 3, 15),
    },
    KeycardSpawns = {
        Vector3.new(-45, 8.5, 10),
        Vector3.new(45, 8.5, -10),
    },
    AdditionalLootSpawns = {
        Vector3.new(-40, 1.5, -50),
        Vector3.new(40, 1.5, 50),
        Vector3.new(-30, 1.5, 0),
        Vector3.new(30, 1.5, 0),
        Vector3.new(0, 8.5, -50),
    }
}

-- 3. КАРТА: CARGO DOCKS (Морской терминал с вертикальным геймплеем)
MapConfigs["Docks"] = {
    Id = "Docks",
    NameKey = "Map_Docks_Name",
    Name = Locale.Get("Map_Docks_Name"),
    FloorSize = Vector3.new(170, 10, 170),
    Walls = {
        { Name = "DockWallN", Size = Vector3.new(170, 36, 4), Position = Vector3.new(0, 18, -85) },
        { Name = "DockWallS", Size = Vector3.new(170, 36, 4), Position = Vector3.new(0, 18, 85) },
        { Name = "DockWallW", Size = Vector3.new(4, 36, 170), Position = Vector3.new(-85, 18, 0) },
        { Name = "DockWallE", Size = Vector3.new(4, 36, 170), Position = Vector3.new(85, 18, 0) },
    },
    Pillars = {
        Vector3.new(-50, 18, -50), Vector3.new(50, 18, -50),
        Vector3.new(-50, 18, 50), Vector3.new(50, 18, 50)
    },
    Beams = {
        { Name = "CraneBeam1", Size = Vector3.new(120, 3, 5), Position = Vector3.new(0, 28, -25), Color = Color3.fromRGB(180, 140, 30), Material = Enum.Material.Metal },
        { Name = "CraneBeam2", Size = Vector3.new(120, 3, 5), Position = Vector3.new(0, 28, 25), Color = Color3.fromRGB(180, 140, 30), Material = Enum.Material.Metal },
    },
    Containers = {
        -- Высокие двухъярусные и трехъярусные штабели для использования крюка
        { Pos = Vector3.new(-35, 6, -30), Size = Vector3.new(14, 12, 30), Color = Color3.fromRGB(175, 45, 45) },
        { Pos = Vector3.new(-35, 18, -30), Size = Vector3.new(14, 12, 28), Color = Color3.fromRGB(50, 80, 160) },
        { Pos = Vector3.new(35, 6, 20), Size = Vector3.new(14, 12, 30), Color = Color3.fromRGB(45, 130, 70) },
        { Pos = Vector3.new(35, 18, 20), Size = Vector3.new(14, 12, 26), Color = Color3.fromRGB(190, 110, 35) },
        { Pos = Vector3.new(0, 6, 40), Size = Vector3.new(30, 12, 14), Color = Color3.fromRGB(90, 95, 105) },
        { Pos = Vector3.new(-20, 6, 15), Size = Vector3.new(16, 12, 16), Color = Color3.fromRGB(140, 60, 130) },
    },
    Lamps = {
        Vector3.new(0, 24, -83), Vector3.new(0, 24, 83),
        Vector3.new(-83, 24, 0), Vector3.new(83, 24, 0)
    },
    Lasers = {
        { Pos = Vector3.new(0, 2.5, -5), Size = Vector3.new(65, 0.4, 0.4) },
        { Pos = Vector3.new(35, 2.5, -45), Size = Vector3.new(35, 0.4, 0.4) },
        { Pos = Vector3.new(-35, 2.5, 45), Size = Vector3.new(35, 0.4, 0.4) }
    },
    Vault = {
        DoorPos = Vector3.new(-55, 6, -55),
        DoorSize = Vector3.new(16, 12, 1.5),
        Walls = {
            { Name = "VaultBack", Size = Vector3.new(20, 14, 2), Position = Vector3.new(-55, 7, -66) },
            { Name = "VaultSide", Size = Vector3.new(2, 14, 20), Position = Vector3.new(-66, 7, -55) },
            { Name = "VaultRoof", Size = Vector3.new(22, 2, 22), Position = Vector3.new(-55, 14, -55) },
        },
        LootPositions = {
            Vector3.new(-55, 1.5, -60),
            Vector3.new(-60, 1.5, -60),
        }
    },
    ExtractionPos = Vector3.new(0, 4, 75),
    WeaponSpawns = {
        Vector3.new(-35, 24.5, -30),
        Vector3.new(35, 24.5, 20),
    },
    GuardSpawns = {
        Vector3.new(10, 3, -10),
    },
    KeycardSpawns = {
        Vector3.new(0, 12.5, 40),
        Vector3.new(-20, 12.5, 15),
    },
    AdditionalLootSpawns = {
        Vector3.new(-35, 12.5, -30),
        Vector3.new(35, 12.5, 20),
        Vector3.new(0, 1.5, 0),
        Vector3.new(-60, 1.5, 20),
        Vector3.new(60, 1.5, -20),
    }
}

function MapConfigs.GetMapList(): { MapConfig }
    return {
        MapConfigs["Warehouse"],
        MapConfigs["Archive"],
        MapConfigs["Docks"]
    }
end

function MapConfigs.Get(mapId: string): MapConfig
    return MapConfigs[mapId] or MapConfigs["Warehouse"]
end

function MapConfigs.PickRandom(): MapConfig
    local list = MapConfigs.GetMapList()
    return list[math.random(1, #list)]
end

return MapConfigs
