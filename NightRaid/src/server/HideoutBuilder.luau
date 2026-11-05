-- Builds one private hideout plot for an online player.
-- Progress is stored separately in PlayerDataStore and survives server shutdowns.
local HideoutBuilder = {}

local PLOT_SPACING = 100
local PLOT_ORIGIN = Vector3.new(300, 120, 0)

local function createPart(parent, name, size, position, color, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Position = position
    part.Anchored = true
    part.Material = material or Enum.Material.Concrete
    part.Color = color
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function addZone(parent, name, title, position, accent)
    local zone = Instance.new("Model")
    zone.Name = name
    zone.Parent = parent

    local floor = createPart(zone, "Floor", Vector3.new(22, 1, 18), position, Color3.fromRGB(35, 40, 49), Enum.Material.Metal)
    local console = createPart(zone, "Console", Vector3.new(5, 3, 2), position + Vector3.new(0, 2, -5), accent, Enum.Material.Neon)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ZoneTitle"
    billboard.Size = UDim2.fromOffset(220, 44)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = console

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.fromRGB(240, 245, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboard

    return floor
end

function HideoutBuilder.Build(userId, slot, savedData)
    local plotPosition = PLOT_ORIGIN + Vector3.new(((slot - 1) % 4) * PLOT_SPACING, 0, math.floor((slot - 1) / 4) * PLOT_SPACING)
    local model = Instance.new("Model")
    model.Name = "Hideout_" .. tostring(userId)
    model:SetAttribute("OwnerUserId", userId)
    model:SetAttribute("Level", savedData.Level or 1)
    model.Parent = workspace:FindFirstChild("Hideouts") or Instance.new("Folder", workspace)
    model.Parent.Name = "Hideouts"

    local x, y, z = plotPosition.X, plotPosition.Y, plotPosition.Z
    createPart(model, "Foundation", Vector3.new(64, 4, 54), Vector3.new(x, y, z), Color3.fromRGB(22, 26, 34), Enum.Material.Metal)
    createPart(model, "BackWall", Vector3.new(64, 18, 2), Vector3.new(x, y + 11, z - 26), Color3.fromRGB(40, 47, 59))
    createPart(model, "LeftWall", Vector3.new(2, 18, 54), Vector3.new(x - 31, y + 11, z), Color3.fromRGB(40, 47, 59))
    createPart(model, "RightWall", Vector3.new(2, 18, 54), Vector3.new(x + 31, y + 11, z), Color3.fromRGB(40, 47, 59))
    createPart(model, "Roof", Vector3.new(64, 2, 54), Vector3.new(x, y + 21, z), Color3.fromRGB(18, 21, 28), Enum.Material.Metal)

    addZone(model, "Armory", "АРСЕНАЛ", Vector3.new(x - 20, y + 2.5, z - 10), Color3.fromRGB(190, 145, 55))
    addZone(model, "Workshop", "МАСТЕРСКАЯ", Vector3.new(x + 20, y + 2.5, z - 10), Color3.fromRGB(70, 150, 190))
    addZone(model, "Command", "УПРАВЛЕНИЕ", Vector3.new(x - 20, y + 2.5, z + 12), Color3.fromRGB(80, 170, 130))
    addZone(model, "Living", "ЖИЛОЙ СЕКТОР", Vector3.new(x + 20, y + 2.5, z + 12), Color3.fromRGB(150, 100, 180))

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
