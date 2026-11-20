--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

export type PartConfig = {
    Name: string,
    Size: Vector3,
    Position: Vector3,
    Color: Color3?,
    Material: Enum.Material?,
    Transparency: number?,
    CanCollide: boolean?,
}

export type ContainerConfig = {
    Size: Vector3,
    Pos: Vector3,
    Color: Color3,
}

export type ShelfConfig = {
    Pos: Vector3,
    Size: Vector3,
    Levels: number,
    Color: Color3?,
}

export type PropConfig = {
    Type: "BarrelStack" | "PalletStack" | "Crate" | "ServerRack" | "Desk",
    Pos: Vector3,
    RotationY: number?,
    Color: Color3?,
}

export type CatwalkConfig = {
    Pos: Vector3,
    Size: Vector3,
    StairsPos: Vector3?,
}

export type PipeConfig = {
    From: Vector3,
    To: Vector3,
    Radius: number?,
    Color: Color3?,
}

export type CameraConfig = {
    Pos: Vector3,
    Dir: Vector3,
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
    Shelves: { ShelfConfig },
    Props: { PropConfig },
    Catwalks: { CatwalkConfig },
    Pipes: { PipeConfig },
    Lamps: { Vector3 },
    Lasers: { { Pos: Vector3, Size: Vector3 } },
    Cameras: { CameraConfig },
    Vault: {
        DoorPos: Vector3,
        DoorSize: Vector3,
        Walls: { PartConfig },
        LootPositions: { Vector3 },
    },
    ExtractionPos: Vector3,
    WeaponSpawns: { Vector3 },
    GuardSpawns: { Vector3 },
    GuardWaypoints: { Vector3 },
    KeycardSpawns: { Vector3 },
    AdditionalLootSpawns: { Vector3 },
}

local mapRegistry: { [string]: MapConfig } = {}

-- =========================================================================
-- 1. КАРТА: INDUSTRIAL WAREHOUSE ("Логистический комплекс Apex")
-- Атмосфера: огромный индустриальный склад с рядами стеллажей, паллетами,
-- мостиками под крышей и зоной погрузки.
-- =========================================================================
mapRegistry["Warehouse"] = {
    Id = "Warehouse",
    NameKey = "Map_Warehouse_Name",
    Name = Locale.Get("Map_Warehouse_Name"),
    FloorSize = Vector3.new(160, 10, 160),
    Walls = {
        -- Внешний периметр
        { Name = "WallNorth", Size = Vector3.new(160, 32, 4), Position = Vector3.new(0, 16, -80), Color = Color3.fromRGB(42, 46, 52), Material = Enum.Material.Concrete },
        { Name = "WallSouth", Size = Vector3.new(160, 32, 4), Position = Vector3.new(0, 16, 80), Color = Color3.fromRGB(42, 46, 52), Material = Enum.Material.Concrete },
        { Name = "WallWest", Size = Vector3.new(4, 32, 160), Position = Vector3.new(-80, 16, 0), Color = Color3.fromRGB(42, 46, 52), Material = Enum.Material.Concrete },
        { Name = "WallEast", Size = Vector3.new(4, 32, 160), Position = Vector3.new(80, 16, 0), Color = Color3.fromRGB(42, 46, 52), Material = Enum.Material.Concrete },

        -- Офис диспетчера / охраны на возвышении (Security Office)
        { Name = "OfficeFloor", Size = Vector3.new(28, 1, 22), Position = Vector3.new(-60, 12, -65), Color = Color3.fromRGB(55, 60, 70), Material = Enum.Material.Metal },
        { Name = "OfficeWallS", Size = Vector3.new(28, 12, 1), Position = Vector3.new(-60, 18, -54), Color = Color3.fromRGB(60, 65, 75), Material = Enum.Material.Concrete },
        { Name = "OfficeWallE", Size = Vector3.new(1, 12, 22), Position = Vector3.new(-46, 18, -65), Color = Color3.fromRGB(60, 65, 75), Material = Enum.Material.Concrete },
        { Name = "OfficeWindow", Size = Vector3.new(18, 6, 1.2), Position = Vector3.new(-60, 16, -54), Color = Color3.fromRGB(130, 180, 210), Material = Enum.Material.Glass, Transparency = 0.6, CanCollide = false },

        -- Зона погрузки / перегородки зоны разгрузки
        { Name = "LoadingBayWall", Size = Vector3.new(3, 14, 50), Position = Vector3.new(40, 7, 30), Color = Color3.fromRGB(50, 54, 62), Material = Enum.Material.Metal },
    },
    Pillars = {
        Vector3.new(-40, 15, -40), Vector3.new(40, 15, -40),
        Vector3.new(-40, 15, 40), Vector3.new(40, 15, 40),
        Vector3.new(0, 15, -40), Vector3.new(0, 15, 40),
    },
    Beams = {
        { Name = "BeamNorth", Size = Vector3.new(150, 2, 4), Position = Vector3.new(0, 26, -40), Color = Color3.fromRGB(80, 85, 95) },
        { Name = "BeamSouth", Size = Vector3.new(150, 2, 4), Position = Vector3.new(0, 26, 40), Color = Color3.fromRGB(80, 85, 95) },
        { Name = "BeamCenter", Size = Vector3.new(4, 2, 150), Position = Vector3.new(0, 26, 0), Color = Color3.fromRGB(70, 75, 85) },
    },
    Containers = {
        { Pos = Vector3.new(55, 6, 40), Size = Vector3.new(14, 12, 28), Color = Color3.fromRGB(150, 45, 45) },
        { Pos = Vector3.new(55, 18, 40), Size = Vector3.new(14, 12, 26), Color = Color3.fromRGB(45, 85, 155) },
        { Pos = Vector3.new(-55, 6, 45), Size = Vector3.new(28, 12, 14), Color = Color3.fromRGB(45, 125, 65) },
    },
    Shelves = {
        -- 3 высоких ряда складских стеллажей с ящиками
        { Pos = Vector3.new(-25, 9, -15), Size = Vector3.new(8, 18, 36), Levels = 3, Color = Color3.fromRGB(190, 85, 25) },
        { Pos = Vector3.new(5, 9, -15), Size = Vector3.new(8, 18, 36), Levels = 3, Color = Color3.fromRGB(40, 100, 170) },
        { Pos = Vector3.new(-25, 9, 25), Size = Vector3.new(8, 18, 36), Levels = 3, Color = Color3.fromRGB(190, 85, 25) },
    },
    Props = {
        -- Паллеты и бочки в зоне погрузки и у стен
        { Type = "PalletStack", Pos = Vector3.new(35, 1.5, 15) },
        { Type = "PalletStack", Pos = Vector3.new(35, 1.5, 45) },
        { Type = "BarrelStack", Pos = Vector3.new(20, 2.5, 50), Color = Color3.fromRGB(180, 45, 45) },
        { Type = "BarrelStack", Pos = Vector3.new(-65, 2.5, 10), Color = Color3.fromRGB(45, 130, 60) },
        { Type = "Crate", Pos = Vector3.new(-38, 2, -15), Color = Color3.fromRGB(160, 120, 75) },
        { Type = "Crate", Pos = Vector3.new(-38, 2, 25), Color = Color3.fromRGB(160, 120, 75) },
        { Type = "Desk", Pos = Vector3.new(-60, 13.5, -68) },
        { Type = "ServerRack", Pos = Vector3.new(-70, 14, -68) },
    },
    Catwalks = {
        -- Подвесной мостик второго этажа вдоль северной стены с лестницей
        { Pos = Vector3.new(0, 14, -65), Size = Vector3.new(90, 1.5, 8), StairsPos = Vector3.new(45, 7, -65) },
    },
    Pipes = {
        { From = Vector3.new(-78, 22, -70), To = Vector3.new(-78, 22, 70), Radius = 1.2, Color = Color3.fromRGB(185, 140, 35) },
        { From = Vector3.new(-78, 24, 0), To = Vector3.new(78, 24, 0), Radius = 1.0, Color = Color3.fromRGB(90, 95, 105) },
    },
    Lamps = {
        Vector3.new(0, 22, -78), Vector3.new(0, 22, 78),
        Vector3.new(-78, 22, 0), Vector3.new(78, 22, 0),
        Vector3.new(-60, 22, -65), Vector3.new(0, 22, 0),
    },
    Lasers = {
        { Pos = Vector3.new(50, 2.5, -20), Size = Vector3.new(18, 0.4, 0.4) },
        { Pos = Vector3.new(-25, 2.5, 5), Size = Vector3.new(16, 0.4, 0.4) },
        { Pos = Vector3.new(5, 2.5, 5), Size = Vector3.new(16, 0.4, 0.4) },
    },
    Cameras = {
        { Pos = Vector3.new(-45, 18, -50), Dir = Vector3.new(0.5, -0.4, 0.7) },
        { Pos = Vector3.new(65, 20, -10), Dir = Vector3.new(-0.6, -0.4, -0.6) },
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
            Vector3.new(55, 1.5, -35),
        }
    },
    ExtractionPos = Vector3.new(0, 4, 70),
    WeaponSpawns = {
        Vector3.new(-60, 14, -68), -- В офисе охраны
        Vector3.new(0, 15.5, -65),  -- На мостике
        Vector3.new(-25, 19, -15),  -- На верхнем ярусе стеллажа
    },
    GuardSpawns = {
        Vector3.new(10, 3, 10),
    },
    GuardWaypoints = {
        Vector3.new(-35, 3, 40),
        Vector3.new(-35, 3, -15),
        Vector3.new(20, 3, -15),
        Vector3.new(40, 3, -15),
        Vector3.new(40, 3, 45),
        Vector3.new(0, 3, 15),
    },
    KeycardSpawns = {
        Vector3.new(-60, 14.5, -68), -- На столе в офисе охраны
        Vector3.new(-25, 18.5, 25),  -- На верхнем ярусе стеллажа
    },
    AdditionalLootSpawns = {
        Vector3.new(-25, 6.5, -15),
        Vector3.new(-25, 12.5, -15),
        Vector3.new(5, 6.5, -15),
        Vector3.new(5, 12.5, -15),
        Vector3.new(-25, 6.5, 25),
        Vector3.new(35, 2.5, 15),
        Vector3.new(55, 12.5, 40),
    }
}

-- =========================================================================
-- 2. КАРТА: ARCHIVE VAULT ("Депозитарий Centurion")
-- Атмосфера: секретный подземный архив/банк: коридорная система, серверная,
-- стеклянные перегородки, офис начальника и бронированное хранилище.
-- =========================================================================
mapRegistry["Archive"] = {
    Id = "Archive",
    NameKey = "Map_Archive_Name",
    Name = Locale.Get("Map_Archive_Name"),
    FloorSize = Vector3.new(150, 10, 150),
    Walls = {
        -- Внешние бронированные стены
        { Name = "WallNorth", Size = Vector3.new(150, 24, 4), Position = Vector3.new(0, 12, -75), Color = Color3.fromRGB(30, 34, 40), Material = Enum.Material.Concrete },
        { Name = "WallSouth", Size = Vector3.new(150, 24, 4), Position = Vector3.new(0, 12, 75), Color = Color3.fromRGB(30, 34, 40), Material = Enum.Material.Concrete },
        { Name = "WallWest", Size = Vector3.new(4, 24, 150), Position = Vector3.new(-75, 12, 0), Color = Color3.fromRGB(30, 34, 40), Material = Enum.Material.Concrete },
        { Name = "WallEast", Size = Vector3.new(4, 24, 150), Position = Vector3.new(75, 12, 0), Color = Color3.fromRGB(30, 34, 40), Material = Enum.Material.Concrete },

        -- Центральный коридор и стены серверной (Восточное крыло)
        { Name = "ServerWallW", Size = Vector3.new(2, 22, 60), Position = Vector3.new(25, 11, -15), Color = Color3.fromRGB(40, 45, 55), Material = Enum.Material.Metal },
        { Name = "ServerWallS", Size = Vector3.new(50, 22, 2), Position = Vector3.new(50, 11, 15), Color = Color3.fromRGB(40, 45, 55), Material = Enum.Material.Metal },

        -- Офис охраны и комната досмотра (Западное крыло)
        { Name = "SecWallE", Size = Vector3.new(2, 22, 50), Position = Vector3.new(-25, 11, -20), Color = Color3.fromRGB(40, 45, 55), Material = Enum.Material.Metal },
        { Name = "SecWallS", Size = Vector3.new(50, 22, 2), Position = Vector3.new(-50, 11, 5), Color = Color3.fromRGB(40, 45, 55), Material = Enum.Material.Metal },
        { Name = "SecWindow", Size = Vector3.new(1, 8, 20), Position = Vector3.new(-25, 10, -20), Color = Color3.fromRGB(120, 170, 210), Material = Enum.Material.Glass, Transparency = 0.5, CanCollide = false },

        -- Защитный тамбур перед хранилищем
        { Name = "AirlockWallW", Size = Vector3.new(2, 22, 30), Position = Vector3.new(-18, 11, -55), Color = Color3.fromRGB(50, 55, 65), Material = Enum.Material.DiamondPlate },
        { Name = "AirlockWallE", Size = Vector3.new(2, 22, 30), Position = Vector3.new(18, 11, -55), Color = Color3.fromRGB(50, 55, 65), Material = Enum.Material.DiamondPlate },
    },
    Pillars = {
        Vector3.new(-50, 12, 40), Vector3.new(50, 12, 40),
        Vector3.new(-50, 12, -45), Vector3.new(50, 12, -45),
    },
    Beams = {
        { Name = "ArchiveBeam1", Size = Vector3.new(140, 2, 3), Position = Vector3.new(0, 20, 35), Color = Color3.fromRGB(60, 65, 75) },
        { Name = "ArchiveBeam2", Size = Vector3.new(140, 2, 3), Position = Vector3.new(0, 20, -35), Color = Color3.fromRGB(60, 65, 75) },
    },
    Containers = {},
    Shelves = {},
    Props = {
        -- Серверная: ряды серверов с диодами
        { Type = "ServerRack", Pos = Vector3.new(40, 6, -30), RotationY = 0 },
        { Type = "ServerRack", Pos = Vector3.new(55, 6, -30), RotationY = 0 },
        { Type = "ServerRack", Pos = Vector3.new(40, 6, -15), RotationY = 0 },
        { Type = "ServerRack", Pos = Vector3.new(55, 6, -15), RotationY = 0 },
        { Type = "ServerRack", Pos = Vector3.new(40, 6, 0), RotationY = 0 },
        { Type = "ServerRack", Pos = Vector3.new(55, 6, 0), RotationY = 0 },

        -- Офис охраны: столы с мониторами, сейфы
        { Type = "Desk", Pos = Vector3.new(-45, 2, -15) },
        { Type = "Desk", Pos = Vector3.new(-60, 2, -15) },
        { Type = "Crate", Pos = Vector3.new(-65, 2, -35), Color = Color3.fromRGB(70, 75, 85) },
        { Type = "Crate", Pos = Vector3.new(-55, 2, -35), Color = Color3.fromRGB(70, 75, 85) },

        -- Зона ожидания / холл южного сектора
        { Type = "PalletStack", Pos = Vector3.new(-20, 1.5, 45) },
        { Type = "PalletStack", Pos = Vector3.new(20, 1.5, 45) },
        { Type = "BarrelStack", Pos = Vector3.new(-45, 2.5, 55), Color = Color3.fromRGB(40, 70, 130) },
        { Type = "BarrelStack", Pos = Vector3.new(45, 2.5, 55), Color = Color3.fromRGB(40, 70, 130) },
    },
    Catwalks = {
        -- Верхняя галерея наблюдения над главным холлом
        { Pos = Vector3.new(0, 13, 35), Size = Vector3.new(60, 1.5, 8), StairsPos = Vector3.new(30, 6.5, 35) },
    },
    Pipes = {
        { From = Vector3.new(25, 18, -40), To = Vector3.new(25, 18, 15), Radius = 0.8, Color = Color3.fromRGB(60, 140, 210) },
        { From = Vector3.new(-25, 18, -40), To = Vector3.new(-25, 18, 5), Radius = 0.8, Color = Color3.fromRGB(200, 150, 40) },
    },
    Lamps = {
        Vector3.new(0, 18, -20), Vector3.new(0, 18, 20),
        Vector3.new(50, 18, -15), Vector3.new(-50, 18, -15),
        Vector3.new(0, 18, -60),
    },
    Lasers = {
        -- Лазерная сетка в тамбуре хранилища
        { Pos = Vector3.new(0, 2.5, -45), Size = Vector3.new(34, 0.4, 0.4) },
        { Pos = Vector3.new(0, 6.0, -52), Size = Vector3.new(34, 0.4, 0.4) },
        { Pos = Vector3.new(0, 2.5, -60), Size = Vector3.new(34, 0.4, 0.4) },
    },
    Cameras = {
        { Pos = Vector3.new(0, 18, -35), Dir = Vector3.new(0, -0.4, -0.8) }, -- Смотрит на вход в тамбур
        { Pos = Vector3.new(-20, 18, 15), Dir = Vector3.new(0.6, -0.4, 0.6) }, -- Холл
        { Pos = Vector3.new(26, 18, -15), Dir = Vector3.new(0.7, -0.4, -0.5) }, -- Серверная
    },
    Vault = {
        DoorPos = Vector3.new(0, 6, -68),
        DoorSize = Vector3.new(16, 12, 2.5),
        Walls = {
            { Name = "VaultW", Size = Vector3.new(2, 14, 18), Position = Vector3.new(-10, 7, -72), Color = Color3.fromRGB(20, 24, 30), Material = Enum.Material.Metal },
            { Name = "VaultE", Size = Vector3.new(2, 14, 18), Position = Vector3.new(10, 7, -72), Color = Color3.fromRGB(20, 24, 30), Material = Enum.Material.Metal },
            { Name = "VaultRoof", Size = Vector3.new(20, 2, 18), Position = Vector3.new(0, 14, -72), Color = Color3.fromRGB(20, 24, 30), Material = Enum.Material.Metal },
        },
        LootPositions = {
            Vector3.new(-4, 1.5, -72),
            Vector3.new(4, 1.5, -72),
            Vector3.new(0, 1.5, -74),
        }
    },
    ExtractionPos = Vector3.new(0, 4, 65),
    WeaponSpawns = {
        Vector3.new(-45, 3.5, -15), -- В кабинете охраны
        Vector3.new(40, 11, -30),   -- На сервере
        Vector3.new(0, 14.5, 35),   -- На верхнем мостике
    },
    GuardSpawns = {
        Vector3.new(0, 3, 0),
    },
    GuardWaypoints = {
        Vector3.new(0, 3, 40),
        Vector3.new(0, 3, -35),
        Vector3.new(45, 3, -15),
        Vector3.new(0, 3, 0),
        Vector3.new(-45, 3, -15),
    },
    KeycardSpawns = {
        Vector3.new(-60, 3.5, -15), -- В сейфе кабинета охраны
        Vector3.new(55, 10.5, 0),   -- На дальнем сервере
    },
    AdditionalLootSpawns = {
        Vector3.new(40, 1.5, -30),
        Vector3.new(55, 1.5, -15),
        Vector3.new(-50, 1.5, -30),
        Vector3.new(0, 14.5, 35),
        Vector3.new(20, 2.5, 45),
    }
}

-- =========================================================================
-- 3. КАРТА: CARGO DOCKS ("Морской грузовой терминал")
-- Атмосфера: открытая портовая зона, морские контейнеры в 3 яруса,
-- портовый козловой кран, смотровые вышки и лабиринты проходов.
-- =========================================================================
mapRegistry["Docks"] = {
    Id = "Docks",
    NameKey = "Map_Docks_Name",
    Name = Locale.Get("Map_Docks_Name"),
    FloorSize = Vector3.new(170, 10, 170),
    Walls = {
        { Name = "DockWallN", Size = Vector3.new(170, 36, 4), Position = Vector3.new(0, 18, -85), Color = Color3.fromRGB(38, 42, 48), Material = Enum.Material.Concrete },
        { Name = "DockWallS", Size = Vector3.new(170, 36, 4), Position = Vector3.new(0, 18, 85), Color = Color3.fromRGB(38, 42, 48), Material = Enum.Material.Concrete },
        { Name = "DockWallW", Size = Vector3.new(4, 36, 170), Position = Vector3.new(-85, 18, 0), Color = Color3.fromRGB(38, 42, 48), Material = Enum.Material.Concrete },
        { Name = "DockWallE", Size = Vector3.new(4, 36, 170), Position = Vector3.new(85, 18, 0), Color = Color3.fromRGB(38, 42, 48), Material = Enum.Material.Concrete },

        -- Портовая смотровая вышка охраны (Watchtower)
        { Name = "TowerPlatform", Size = Vector3.new(16, 2, 16), Position = Vector3.new(-65, 20, -65), Color = Color3.fromRGB(60, 65, 75), Material = Enum.Material.DiamondPlate },
        { Name = "TowerLeg1", Size = Vector3.new(2, 20, 2), Position = Vector3.new(-71, 10, -71), Color = Color3.fromRGB(45, 50, 60), Material = Enum.Material.Metal },
        { Name = "TowerLeg2", Size = Vector3.new(2, 20, 2), Position = Vector3.new(-59, 10, -71), Color = Color3.fromRGB(45, 50, 60), Material = Enum.Material.Metal },
        { Name = "TowerLeg3", Size = Vector3.new(2, 20, 2), Position = Vector3.new(-71, 10, -59), Color = Color3.fromRGB(45, 50, 60), Material = Enum.Material.Metal },
        { Name = "TowerLeg4", Size = Vector3.new(2, 20, 2), Position = Vector3.new(-59, 10, -59), Color = Color3.fromRGB(45, 50, 60), Material = Enum.Material.Metal },
    },
    Pillars = {
        Vector3.new(-50, 18, -50), Vector3.new(50, 18, -50),
        Vector3.new(-50, 18, 50), Vector3.new(50, 18, 50),
    },
    Beams = {
        -- Рельсовая рама огромного портового крана
        { Name = "CraneBeam1", Size = Vector3.new(140, 4, 6), Position = Vector3.new(0, 28, -25), Color = Color3.fromRGB(210, 160, 30), Material = Enum.Material.Metal },
        { Name = "CraneBeam2", Size = Vector3.new(140, 4, 6), Position = Vector3.new(0, 28, 25), Color = Color3.fromRGB(210, 160, 30), Material = Enum.Material.Metal },
        { Name = "CraneCross1", Size = Vector3.new(6, 4, 56), Position = Vector3.new(-30, 30, 0), Color = Color3.fromRGB(190, 140, 25), Material = Enum.Material.Metal },
        { Name = "CraneCross2", Size = Vector3.new(6, 4, 56), Position = Vector3.new(30, 30, 0), Color = Color3.fromRGB(190, 140, 25), Material = Enum.Material.Metal },
    },
    Containers = {
        -- 1-й ярус (Y = 6)
        { Pos = Vector3.new(-40, 6, -30), Size = Vector3.new(14, 12, 32), Color = Color3.fromRGB(180, 40, 40) },
        { Pos = Vector3.new(-40, 6, 15), Size = Vector3.new(14, 12, 32), Color = Color3.fromRGB(40, 80, 170) },
        { Pos = Vector3.new(40, 6, -20), Size = Vector3.new(14, 12, 32), Color = Color3.fromRGB(45, 140, 70) },
        { Pos = Vector3.new(40, 6, 25), Size = Vector3.new(14, 12, 32), Color = Color3.fromRGB(190, 110, 30) },
        { Pos = Vector3.new(0, 6, 45), Size = Vector3.new(32, 12, 14), Color = Color3.fromRGB(80, 85, 95) },

        -- 2-й ярус (Y = 18)
        { Pos = Vector3.new(-40, 18, -30), Size = Vector3.new(14, 12, 30), Color = Color3.fromRGB(50, 90, 180) },
        { Pos = Vector3.new(40, 18, -20), Size = Vector3.new(14, 12, 30), Color = Color3.fromRGB(185, 45, 45) },
        { Pos = Vector3.new(0, 18, 45), Size = Vector3.new(30, 12, 14), Color = Color3.fromRGB(170, 120, 35) },

        -- 3-й ярус (Y = 30) - экстремальная высота для крюка
        { Pos = Vector3.new(-40, 30, -30), Size = Vector3.new(14, 12, 26), Color = Color3.fromRGB(75, 80, 90) },
    },
    Shelves = {},
    Props = {
        { Type = "BarrelStack", Pos = Vector3.new(-15, 2.5, -45), Color = Color3.fromRGB(200, 45, 45) },
        { Type = "BarrelStack", Pos = Vector3.new(15, 2.5, -45), Color = Color3.fromRGB(200, 45, 45) },
        { Type = "BarrelStack", Pos = Vector3.new(-20, 2.5, 15), Color = Color3.fromRGB(45, 120, 180) },
        { Type = "PalletStack", Pos = Vector3.new(20, 1.5, 0) },
        { Type = "PalletStack", Pos = Vector3.new(-20, 1.5, -10) },
        { Type = "Crate", Pos = Vector3.new(15, 2, 25), Color = Color3.fromRGB(150, 110, 70) },
        { Type = "Crate", Pos = Vector3.new(-15, 2, 25), Color = Color3.fromRGB(150, 110, 70) },
    },
    Catwalks = {
        -- Подвесной мостик между контейнерами 2-го яруса
        { Pos = Vector3.new(0, 18, -20), Size = Vector3.new(66, 1.5, 6) },
    },
    Pipes = {
        { From = Vector3.new(-83, 10, -50), To = Vector3.new(-83, 10, 50), Radius = 1.2, Color = Color3.fromRGB(180, 50, 40) },
        { From = Vector3.new(83, 10, -50), To = Vector3.new(83, 10, 50), Radius = 1.2, Color = Color3.fromRGB(40, 120, 180) },
    },
    Lamps = {
        Vector3.new(0, 24, -83), Vector3.new(0, 24, 83),
        Vector3.new(-83, 24, 0), Vector3.new(83, 24, 0),
        Vector3.new(-65, 22, -65), -- Прожектор вышки
    },
    Lasers = {
        { Pos = Vector3.new(-40, 2.5, -5), Size = Vector3.new(14, 0.4, 0.4) },
        { Pos = Vector3.new(40, 2.5, 2), Size = Vector3.new(14, 0.4, 0.4) },
        { Pos = Vector3.new(0, 2.5, -60), Size = Vector3.new(26, 0.4, 0.4) },
    },
    Cameras = {
        { Pos = Vector3.new(-65, 21, -65), Dir = Vector3.new(0.6, -0.3, 0.6) }, -- С вышки на весь порт
        { Pos = Vector3.new(0, 28, -25), Dir = Vector3.new(0, -0.5, -0.7) },  -- С крана на хранилище
    },
    Vault = {
        DoorPos = Vector3.new(0, 6, -70),
        DoorSize = Vector3.new(16, 12, 1.5),
        Walls = {
            { Name = "VaultDockW", Size = Vector3.new(2, 14, 20), Position = Vector3.new(-12, 7, -76), Color = Color3.fromRGB(30, 35, 42), Material = Enum.Material.Metal },
            { Name = "VaultDockE", Size = Vector3.new(2, 14, 20), Position = Vector3.new(12, 7, -76), Color = Color3.fromRGB(30, 35, 42), Material = Enum.Material.Metal },
            { Name = "VaultDockRoof", Size = Vector3.new(24, 2, 20), Position = Vector3.new(0, 14, -76), Color = Color3.fromRGB(30, 35, 42), Material = Enum.Material.Metal },
        },
        LootPositions = {
            Vector3.new(-5, 1.5, -75),
            Vector3.new(5, 1.5, -75),
            Vector3.new(0, 1.5, -77),
        }
    },
    ExtractionPos = Vector3.new(0, 4, 75),
    WeaponSpawns = {
        Vector3.new(-65, 21.5, -65), -- На смотровой вышке!
        Vector3.new(0, 31, 0),       -- На стреле портового крана!
        Vector3.new(40, 24.5, -20),  -- На 2 ярусе контейнеров
    },
    GuardSpawns = {
        Vector3.new(0, 3, -10),
    },
    GuardWaypoints = {
        Vector3.new(-25, 3, -30),
        Vector3.new(-25, 3, 30),
        Vector3.new(25, 3, 30),
        Vector3.new(25, 3, -30),
        Vector3.new(0, 3, -50),
    },
    KeycardSpawns = {
        Vector3.new(-65, 21.5, -65), -- В будке на смотровой вышке
        Vector3.new(-40, 36.5, -30), -- На вершине 3-го яруса контейнеров!
    },
    AdditionalLootSpawns = {
        Vector3.new(-40, 12.5, -30),
        Vector3.new(-40, 24.5, -30),
        Vector3.new(40, 12.5, -20),
        Vector3.new(0, 19, -20),
        Vector3.new(20, 2.5, 0),
        Vector3.new(-15, 3.5, 25),
    }
}

local MapConfigs = {}

function MapConfigs.Get(id: string): MapConfig
    return mapRegistry[id] or mapRegistry["Warehouse"]
end

function MapConfigs.GetMapList(): { MapConfig }
    return {
        mapRegistry["Warehouse"],
        mapRegistry["Archive"],
        mapRegistry["Docks"],
    }
end

function MapConfigs.PickRandom(): MapConfig
    local ids = { "Warehouse", "Archive", "Docks" }
    local pickedId = ids[math.random(1, #ids)]
    return mapRegistry[pickedId]
end

return MapConfigs
