-- Builds a personal underground hideout with readable lighting and detailed stations.
-- Persistent progression is stored separately in PlayerDataStore.
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

local function createPart(parent, name, size, position, color, material, options)
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

local function addLight(parent, name, color, brightness, range, position)
    local fixture = createPart(parent, name, Vector3.new(5, 0.25, 1), position, color, Enum.Material.Neon, {canCollide = false})
    local light = Instance.new("PointLight")
    light.Name = "AreaLight"
    light.Color = color
    light.Brightness = brightness
    light.Range = range
    light.Shadows = false
    light.Parent = fixture
    return fixture
end

local function addLabel(parent, title, accent, center)
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

local function addZone(parent, name, title, center, accent, stationType)
    local zone = Instance.new("Model")
    zone.Name = name
    zone.Parent = parent

    createPart(zone, "RaisedPlatform", Vector3.new(27, 0.35, 21), center + Vector3.new(0, 0.2, 0), COLORS.dark, Enum.Material.Metal)
    createPart(zone, "Floor", Vector3.new(26, 0.2, 20), center + Vector3.new(0, 0.45, 0), COLORS.floor, Enum.Material.Concrete)

    -- Accent strips make each functional area easy to recognize.
    createPart(zone, "AccentStrip", Vector3.new(22, 0.12, 0.35), center + Vector3.new(0, 0.62, 9.2), accent, Enum.Material.Neon, {canCollide = false})

    local console = createPart(zone, "MainStation", Vector3.new(8, 3.2, 2), center + Vector3.new(0, 2.25, -5), COLORS.metal, Enum.Material.Metal)
    createPart(zone, "ConsoleScreen", Vector3.new(6.8, 1.8, 0.15), console.Position + Vector3.new(0, 0.45, -1.08), accent, Enum.Material.Neon, {canCollide = false})
    addLabel(zone, title, accent, center)

    if stationType == "Armory" then
        for i = -1, 1 do
            local rack = createPart(zone, "WeaponRack", Vector3.new(1, 5, 7), center + Vector3.new(i * 8, 3, 4), COLORS.metal, Enum.Material.DiamondPlate)
            createPart(zone, "RackShelf", Vector3.new(1.4, 0.25, 7.5), rack.Position + Vector3.new(0, -1, 0), COLORS.warm, Enum.Material.Metal)
            for j = -1, 1 do
                createPart(zone, "DisplayWeapon", Vector3.new(0.25, 0.35, 4), rack.Position + Vector3.new(0.7, j * 1.25, 0), COLORS.dark, Enum.Material.Metal, {canCollide = false})
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
            createPart(zone, "MonitorDisplay", Vector3.new(4.5, 2.5, 0.12), screen.Position + Vector3.new(0, 0, -0.22), COLORS.blue, Enum.Material.Neon, {canCollide = false})
        end
        createPart(zone, "OperatorDesk", Vector3.new(18, 1, 3), center + Vector3.new(0, 2, 6), COLORS.metal, Enum.Material.Metal)
    elseif stationType == "Living" then
        createPart(zone, "BunkBed", Vector3.new(7, 1, 3), center + Vector3.new(-5, 1.6, 3), COLORS.metal, Enum.Material.Metal)
        createPart(zone, "Mattress", Vector3.new(6.6, 0.45, 2.7), center + Vector3.new(-5, 2.3, 3), Color3.fromRGB(75, 95, 112), Enum.Material.Fabric)
        createPart(zone, "Locker", Vector3.new(3, 6, 3), center + Vector3.new(9, 3, -2), COLORS.metal, Enum.Material.Metal)
        createPart(zone, "Seat", Vector3.new(4, 1, 2), center + Vector3.new(4, 1.2, 5), Color3.fromRGB(85, 65, 52), Enum.Material.Fabric)
    end

    addLight(zone, "StationLight", accent, 2.2, 24, center + Vector3.new(0, 9, 0))
    return zone
end

function HideoutBuilder.Build(userId, slot, savedData)
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

    -- Main ceiling lights ensure the hideout is usable without a flashlight,
    -- even though the raid map keeps its night-time lighting.
    addLight(model, "CeilingLight_A", COLORS.warm, 3.5, 38, Vector3.new(x - 16, y + 19, z - 12))
    addLight(model, "CeilingLight_B", COLORS.warm, 3.5, 38, Vector3.new(x + 16, y + 19, z - 12))
    addLight(model, "CeilingLight_C", COLORS.warm, 3.5, 38, Vector3.new(x - 16, y + 19, z + 13))
    addLight(model, "CeilingLight_D", COLORS.warm, 3.5, 38, Vector3.new(x + 16, y + 19, z + 13))

    addZone(model, "Armory", "АРСЕНАЛ", Vector3.new(x - 17, y + 2.2, z - 10), COLORS.warm, "Armory")
    addZone(model, "Workshop", "МАСТЕРСКАЯ", Vector3.new(x + 17, y + 2.2, z - 10), COLORS.blue, "Workshop")
    addZone(model, "Command", "УПРАВЛЕНИЕ", Vector3.new(x - 17, y + 2.2, z + 13), COLORS.green, "Command")
    addZone(model, "Living", "ЖИЛОЙ СЕКТОР", Vector3.new(x + 17, y + 2.2, z + 13), Color3.fromRGB(185, 140, 220), "Living")

    local counter = createPart(model, "DealerCounter", Vector3.new(8, 3, 2), Vector3.new(x, y + 3.5, z - 23), Color3.fromRGB(75, 49, 31), Enum.Material.Wood)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Открыть рынок"
    prompt.ObjectText = "Скупщик"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = counter

    local spawnCFrame = CFrame.new(x, y + 5, z + 20)
    return model, spawnCFrame, prompt
end

return HideoutBuilder
