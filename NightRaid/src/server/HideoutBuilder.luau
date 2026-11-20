--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

-- Builds a personal underground hideout with readable lighting and detailed stations.
local HideoutBuilder = {}

local PLOT_SPACING = 100
local PLOT_ORIGIN = Vector3.new(300, 120, 0)

local COLORS = {
    floor = Color3.fromRGB(38, 43, 51),
    wall = Color3.fromRGB(55, 62, 72),
    dark = Color3.fromRGB(25, 29, 36),
    metal = Color3.fromRGB(83, 94, 108),
    warm = Color3.fromRGB(255, 190, 105),
    blue = Color3.fromRGB(90, 190, 235),
    green = Color3.fromRGB(100, 205, 145),
    red = Color3.fromRGB(220, 90, 75),
}

local function createPart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, options: { transparency: number?, canCollide: boolean? }?): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Position = position
    part.Anchored = true
    part.Material = material or Enum.Material.Concrete
    part.Color = color
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    if options then
        if options.transparency then part.Transparency = options.transparency end
        if options.canCollide ~= nil then part.CanCollide = options.canCollide end
    end
    part.Parent = parent
    return part
end

local function addLight(parent: Instance, name: string, color: Color3, brightness: number, range: number, position: Vector3)
    local fixture = createPart(parent, name, Vector3.new(5, 0.25, 1), position, color, Enum.Material.Neon, { canCollide = false })
    local light = Instance.new("PointLight")
    light.Name = "AreaLight"
    light.Color = color
    light.Brightness = brightness
    light.Range = range
    light.Shadows = false
    light.Parent = fixture
    return fixture
end

local function addLabel(parent: Instance, title: string, accent: Color3, center: Vector3)
    local board = createPart(parent, "StationSign", Vector3.new(10, 2.2, 0.35), center + Vector3.new(0, 5.2, -7), COLORS.dark, Enum.Material.Metal)
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.CanvasSize = Vector2.new(600, 140)
    gui.Parent = board

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = accent
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = gui
end

local function addZone(parent: Instance, name: string, title: string, center: Vector3, accent: Color3, stationType: string)
    local zone = Instance.new("Model")
    zone.Name = name
    zone.Parent = parent

    createPart(zone, "RaisedPlatform", Vector3.new(27, 0.35, 21), center + Vector3.new(0, 0.2, 0), COLORS.dark, Enum.Material.Metal)
    createPart(zone, "Floor", Vector3.new(26, 0.2, 20), center + Vector3.new(0, 0.45, 0), COLORS.floor, Enum.Material.Concrete)

    createPart(zone, "AccentStrip", Vector3.new(22, 0.12, 0.35), center + Vector3.new(0, 0.62, 9.2), accent, Enum.Material.Neon, { canCollide = false })

    local console = createPart(zone, "MainStation", Vector3.new(8, 3.2, 2), center + Vector3.new(0, 2.25, -5), COLORS.metal, Enum.Material.Metal)
    createPart(zone, "ConsoleScreen", Vector3.new(6.8, 1.8, 0.15), console.Position + Vector3.new(0, 0.45, -1.08), accent, Enum.Material.Neon, { canCollide = false })
    addLabel(zone, title, accent, center)

    if stationType == "Armory" then
        for i = -1, 1 do
            local rack = createPart(zone, "WeaponRack", Vector3.new(1, 5, 7), center + Vector3.new(i * 8, 3, 4), COLORS.metal, Enum.Material.DiamondPlate)
            createPart(zone, "RackShelf", Vector3.new(1.4, 0.25, 7.5), rack.Position + Vector3.new(0, -1, 0), COLORS.warm, Enum.Material.Metal)
            for j = -1, 1 do
                createPart(zone, "DisplayWeapon", Vector3.new(0.25, 0.35, 4), rack.Position + Vector3.new(0.7, j * 1.25, 0), COLORS.dark, Enum.Material.Metal, { canCollide = false })
            end
        end
    elseif stationType == "Workshop" then
        createPart(zone, "Workbench", Vector3.new(12, 1, 3), center + Vector3.new(0, 2, 4), COLORS.metal, Enum.Material.DiamondPlate)
        for i = -2, 2 do
            createPart(zone, "Tool", Vector3.new(0.35, 2 + (i % 2), 0.35), center + Vector3.new(i * 2, 3.4, 3), accent, Enum.Material.Metal)
        end
        createPart(zone, "StorageCabinet", Vector3.new(3, 5, 3), center + Vector3.new(10, 3, -3), COLORS.dark, Enum.Material.Metal)
    elseif stationType == "Command" then
        for i = -1, 1 do
            local screen = createPart(zone, "Monitor", Vector3.new(5, 3, 0.3), center + Vector3.new(i * 6, 4, 2), COLORS.dark, Enum.Material.Metal)
            createPart(zone, "MonitorDisplay", Vector3.new(4.5, 2.5, 0.12), screen.Position + Vector3.new(0, 0, -0.22), COLORS.blue, Enum.Material.Neon, { canCollide = false })
        end
        createPart(zone, "OperatorDesk", Vector3.new(18, 1, 3), center + Vector3.new(0, 2, 6), COLORS.metal, Enum.Material.Metal)
    elseif stationType == "Living" then
        createPart(zone, "BunkBed", Vector3.new(7, 1, 3), center + Vector3.new(-5, 1.6, 3), COLORS.metal, Enum.Material.Metal)
        createPart(zone, "Mattress", Vector3.new(6.6, 0.45, 2.7), center + Vector3.new(-5, 2.3, 3), Color3.fromRGB(75, 95, 112), Enum.Material.Fabric)
        createPart(zone, "Locker", Vector3.new(3, 6, 3), center + Vector3.new(9, 3, -2), COLORS.metal, Enum.Material.Metal)
        createPart(zone, "Seat", Vector3.new(4, 1, 2), center + Vector3.new(4, 1.2, 5), Color3.fromRGB(85, 65, 52), Enum.Material.Fabric)
    end

    addLight(zone, "StationLight", accent, 2.2, 24, center + Vector3.new(0, 9, 0))

    local stationPrompt = Instance.new("ProximityPrompt")
    stationPrompt.Name = "StationPrompt"
    stationPrompt.ActionText = Locale.Get("Select")
    stationPrompt.ObjectText = title
    stationPrompt.KeyboardKeyCode = Enum.KeyCode.E
    stationPrompt.HoldDuration = 0
    stationPrompt.MaxActivationDistance = 10
    stationPrompt.RequiresLineOfSight = false
    stationPrompt.Parent = console

    return zone, stationPrompt
end

function HideoutBuilder.Build(userId: number, slot: number, savedData: any): (Model, CFrame, ProximityPrompt, { [string]: ProximityPrompt })
    local plotPosition = PLOT_ORIGIN + Vector3.new(((slot - 1) % 4) * PLOT_SPACING, 0, math.floor((slot - 1) / 4) * PLOT_SPACING)
    local model = Instance.new("Model")
    model.Name = "Hideout_" .. tostring(userId)
    model:SetAttribute("OwnerUserId", userId)
    model:SetAttribute("Level", savedData.Level or 1)

    local hideouts = workspace:FindFirstChild("Hideouts")
    if not hideouts then
        hideouts = Instance.new("Folder")
        hideouts.Name = "Hideouts"
        hideouts.Parent = workspace
    end
    model.Parent = hideouts

    local x, y, z = plotPosition.X, plotPosition.Y, plotPosition.Z
    createPart(model, "Foundation", Vector3.new(64, 4, 54), Vector3.new(x, y, z), COLORS.dark, Enum.Material.Metal)
    createPart(model, "BackWall", Vector3.new(64, 18, 2), Vector3.new(x, y + 11, z - 26), COLORS.wall, Enum.Material.Concrete)
    createPart(model, "LeftWall", Vector3.new(2, 18, 54), Vector3.new(x - 31, y + 11, z), COLORS.wall, Enum.Material.Concrete)
    createPart(model, "RightWall", Vector3.new(2, 18, 54), Vector3.new(x + 31, y + 11, z), COLORS.wall, Enum.Material.Concrete)
    createPart(model, "Roof", Vector3.new(64, 2, 54), Vector3.new(x, y + 21, z), COLORS.dark, Enum.Material.Metal)

    addLight(model, "CeilingLight_A", COLORS.warm, 3.5, 38, Vector3.new(x - 16, y + 19, z - 12))
    addLight(model, "CeilingLight_B", COLORS.warm, 3.5, 38, Vector3.new(x + 16, y + 19, z - 12))
    addLight(model, "CeilingLight_C", COLORS.warm, 3.5, 38, Vector3.new(x - 16, y + 19, z + 13))
    addLight(model, "CeilingLight_D", COLORS.warm, 3.5, 38, Vector3.new(x + 16, y + 19, z + 13))

    local stationPrompts = {}
    local _, armoryPrompt = addZone(model, "Armory", Locale.Get("StationArmory"), Vector3.new(x - 17, y + 2.2, z - 10), COLORS.warm, "Armory")
    local _, workshopPrompt = addZone(model, "Workshop", Locale.Get("StationWorkshop"), Vector3.new(x + 17, y + 2.2, z - 10), COLORS.blue, "Workshop")
    local _, commandPrompt = addZone(model, "Command", Locale.Get("StationCommand"), Vector3.new(x - 17, y + 2.2, z + 13), COLORS.green, "Command")
    local _, wardrobePrompt = addZone(model, "Wardrobe", "Магазин масок и гардероб", Vector3.new(x + 17, y + 2.2, z + 13), Color3.fromRGB(185, 140, 220), "Wardrobe")

    stationPrompts.Armory = armoryPrompt
    stationPrompts.Workshop = workshopPrompt
    stationPrompts.Command = commandPrompt
    stationPrompts.Wardrobe = wardrobePrompt

    -- Неоновая вывеска синдиката над базой
    local signPart = createPart(model, "NeonSign", Vector3.new(24, 2, 0.4), Vector3.new(x, y + 15, z - 25), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
    local signBB = Instance.new("BillboardGui")
    signBB.Size = UDim2.new(0, 320, 0, 50)
    signBB.AlwaysOnTop = false
    signBB.Parent = signPart
    local signLabel = Instance.new("TextLabel")
    signLabel.Size = UDim2.new(1, 0, 1, 0)
    signLabel.Text = "★ NIGHT RAID: SYNDICATE DEN ★"
    signLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
    signLabel.Font = Enum.Font.GothamBlack
    signLabel.TextSize = 16
    signLabel.BackgroundTransparency = 1
    signLabel.Parent = signBB

    -- Диван и столик в зоне отдыха
    createPart(model, "LivingSofa", Vector3.new(10, 2.5, 4), Vector3.new(x + 22, y + 3.2, z + 18), Color3.fromRGB(45, 30, 25), Enum.Material.Leather)
    createPart(model, "LivingTable", Vector3.new(6, 1.8, 3), Vector3.new(x + 22, y + 2.9, z + 13), Color3.fromRGB(60, 45, 35), Enum.Material.Wood)

    -- =========================================================================
    -- ВИЗУАЛЬНАЯ ТРОФЕЙНАЯ ВИТРИНА (Trophy Pedestals)
    -- =========================================================================
    local trophies = savedData.Trophies or {}
    local trophyList = {
        { Id = "Crown", Name = "Корона Синдиката", Color = Color3.fromRGB(255, 215, 0), Pos = Vector3.new(x - 12, y + 3, z - 21) },
        { Id = "GoldBar", Name = "Золотой слиток", Color = Color3.fromRGB(255, 190, 30), Pos = Vector3.new(x - 4, y + 3, z - 21) },
        { Id = "DiamondNecklace", Name = "Алмазное колье", Color = Color3.fromRGB(180, 255, 255), Pos = Vector3.new(x + 4, y + 3, z - 21) },
        { Id = "PrototypeLaser", Name = "Прототип лазера", Color = Color3.fromRGB(255, 50, 100), Pos = Vector3.new(x + 12, y + 3, z - 21) },
    }

    for _, tData in ipairs(trophyList) do
        -- Мраморный постамент
        createPart(model, "Pedestal_" .. tData.Id, Vector3.new(3, 3, 3), tData.Pos, Color3.fromRGB(30, 33, 40), Enum.Material.Marble)
        -- Стеклянный колпак
        createPart(model, "GlassCover_" .. tData.Id, Vector3.new(2.8, 2.6, 2.8), tData.Pos + Vector3.new(0, 2.8, 0), Color3.fromRGB(200, 230, 255), Enum.Material.Glass, { transparency = 0.7, canCollide = false })

        -- Подсветка постамента
        local pLight = Instance.new("PointLight")
        pLight.Range = 8
        pLight.Brightness = 1.5
        pLight.Color = tData.Color
        pLight.Parent = model:FindFirstChild("Pedestal_" .. tData.Id)

        local isUnlocked = trophies[tData.Id] == true
        local trophyItem = createPart(
            model,
            "TrophyItem_" .. tData.Id,
            Vector3.new(1.2, 1.2, 1.2),
            tData.Pos + Vector3.new(0, 2.5, 0),
            isUnlocked and tData.Color or Color3.fromRGB(60, 65, 75),
            isUnlocked and Enum.Material.Neon or Enum.Material.Metal,
            { transparency = isUnlocked and 0 or 0.7, canCollide = false }
        )

        local tBB = Instance.new("BillboardGui")
        tBB.Size = UDim2.new(0, 120, 0, 25)
        tBB.StudsOffset = Vector3.new(0, 2.2, 0)
        tBB.AlwaysOnTop = true
        tBB.Parent = trophyItem

        local tLabel = Instance.new("TextLabel")
        tLabel.Size = UDim2.new(1, 0, 1, 0)
        tLabel.Text = isUnlocked and string.format("★ %s ★", tData.Name) or string.format("[🔒 %s]", tData.Name)
        tLabel.TextColor3 = isUnlocked and Color3.fromRGB(255, 230, 100) or Color3.fromRGB(150, 150, 160)
        tLabel.Font = Enum.Font.GothamBold
        tLabel.TextSize = 11
        tLabel.BackgroundTransparency = 1
        tLabel.Parent = tBB
    end

    local counter = createPart(model, "DealerCounter", Vector3.new(8, 3, 2), Vector3.new(x, y + 3.5, z - 23), Color3.fromRGB(75, 49, 31), Enum.Material.Wood)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = Locale.Get("OpenMarketPrompt")
    prompt.ObjectText = Locale.Get("StationDealer")
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = counter

    local spawnCFrame = CFrame.new(x, y + 5, z + 20)
    return model, spawnCFrame, prompt, stationPrompts
end

return HideoutBuilder
