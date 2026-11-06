local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TEST_MODE = RunService:IsStudio()

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))

local player = Players.LocalPlayer

-- ==========================================
-- БЕЗОПАСНОЕ ПОДКЛЮЧЕНИЕ К NETWORK (БЕЗ INFINITE YIELD)
-- ==========================================
local networkFolder = ReplicatedStorage:WaitForChild("Network", 10)
if not networkFolder then
    warn("[КЛИЕНТ ОШИБКА]: Сетевая папка Network не найдена! Проверьте консоль сервера.")
    return
end

local currentPhaseValue = networkFolder:WaitForChild("CurrentPhase")
local stateChangedEvent = networkFolder:WaitForChild("StateChanged")
local inventoryUpdatedEvent = networkFolder:WaitForChild("InventoryUpdated")
local extractionProgressEvent = networkFolder:WaitForChild("ExtractionProgress")
local dropItemEvent = networkFolder:WaitForChild("DropItem")
local selectLoadoutEvent = networkFolder:WaitForChild("SelectLoadout")
local loadoutsUpdatedEvent = networkFolder:WaitForChild("LoadoutsUpdated")
local getOwnedLoadoutsFunction = networkFolder:WaitForChild("GetOwnedLoadouts")
local loadoutAppliedEvent = networkFolder:WaitForChild("LoadoutApplied")
local makeNoiseEvent = networkFolder:WaitForChild("MakeNoise")
local raidSummaryEvent = networkFolder:WaitForChild("ShowRaidSummary")
local throwSmokeEvent = networkFolder:WaitForChild("ThrowSmoke")
local fireTaserEvent = networkFolder:WaitForChild("FireTaser")
local buyUpgradeEvent = networkFolder:WaitForChild("BuyUpgrade")
local upgradesUpdatedEvent = networkFolder:WaitForChild("UpgradesUpdated")
local openHideoutStationEvent = networkFolder:WaitForChild("OpenHideoutStation")
local nightEventEvent = networkFolder:WaitForChild("NightEvent")
local currentNightEventValue = networkFolder:WaitForChild("CurrentNightEvent")
local getRaidStatusFunction = networkFolder:WaitForChild("GetRaidStatus")
local startRaidEvent = networkFolder:WaitForChild("StartRaid")

local currentInventoryData = { TotalValue = 0, TotalWeight = 0, Items = {} }
local currentLoadout = Config.Loadouts[1]
local ownedLoadouts = { Default = true }
local currentUpgrades = { Pockets = 0, SmokeStarter = 0, Battery = 0 }

-- ==========================================
-- ЗВУКИ (SFX)
-- ==========================================
local function PlayLocalSFX(soundType)
    local sound = Instance.new("Sound")
    sound.Volume = 0.6
    sound.Parent = SoundService

    if soundType == "Grapple" then
        sound.SoundId = "rbxassetid://9114223171"
        sound.Pitch = 1.3
    elseif soundType == "Alarm" then
        sound.SoundId = "rbxassetid://9114223847"
        sound.Pitch = 0.9
        sound.Volume = 0.8
    elseif soundType == "Pickup" then
        sound.SoundId = "rbxassetid://9114221762"
        sound.Pitch = 1.2
    elseif soundType == "Smoke" then
        sound.SoundId = "rbxassetid://9114222474"
        sound.Pitch = 0.8
    end

    sound:Play()
    sound.Ended:Connect(function() sound:Destroy() end)
end

-- ==========================================
-- ПРИЦЕЛ (CROSSHAIR)
-- ==========================================
local function CreateCrosshair()
    local playerGui = player:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CrosshairGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local dot = Instance.new("Frame")
    dot.Name = "CrosshairDot"
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.new(0.5, 0, 0.5, 0)
    dot.BackgroundColor3 = Color3.fromRGB(0, 255, 180)
    dot.BorderSizePixel = 0
    dot.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot
end

task.spawn(CreateCrosshair)

-- ==========================================
-- СТАБИЛИЗИРОВАННЫЙ ФОНАРЬ (F)
-- ==========================================
local isFlashlightOn = false

local lightAnchor = workspace:FindFirstChild("ClientFlashlightRig")
if lightAnchor then lightAnchor:Destroy() end

lightAnchor = Instance.new("Part")
lightAnchor.Name = "ClientFlashlightRig"
lightAnchor.Transparency = 1
lightAnchor.CanCollide = false
lightAnchor.CanQuery = false
lightAnchor.CanTouch = false
lightAnchor.CastShadow = false
lightAnchor.Anchored = true
lightAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
lightAnchor.Parent = workspace

local spotBeam = Instance.new("SpotLight")
spotBeam.Name = "Beam"
spotBeam.Range = LootLogic.GetEffectiveFlashlightRange(75, currentUpgrades.Battery)
spotBeam.Angle = 70
spotBeam.Brightness = 3.5
spotBeam.Color = Color3.fromRGB(255, 250, 235)
spotBeam.Face = Enum.NormalId.Front
spotBeam.Shadows = false
spotBeam.Enabled = false
spotBeam.Parent = lightAnchor

local fillPoint = Instance.new("PointLight")
fillPoint.Name = "Fill"
fillPoint.Range = 25
fillPoint.Brightness = 1.0
fillPoint.Color = Color3.fromRGB(255, 250, 235)
fillPoint.Shadows = false
fillPoint.Enabled = false
fillPoint.Parent = lightAnchor

RunService.RenderStepped:Connect(function()
    if not isFlashlightOn then return end

    local char = player.Character
    local head = char and char:FindFirstChild("Head")
    if head then
        local camCFrame = workspace.CurrentCamera.CFrame
        lightAnchor.CFrame = CFrame.lookAt(head.Position, head.Position + camCFrame.LookVector)
    end
end)

local function ToggleFlashlight()
    isFlashlightOn = not isFlashlightOn
    spotBeam.Enabled = isFlashlightOn
    fillPoint.Enabled = isFlashlightOn
end

-- ==========================================
-- КРЮК-КОШКА (КЛАВИША Q)
-- ==========================================
local isGrappling = false
local alignPos = nil
local activeBeam = nil
local ropePart = nil
local updateConn = nil

local function StopGrapple(boost: boolean)
    if not isGrappling then return end
    isGrappling = false

    if updateConn then
        updateConn:Disconnect()
        updateConn = nil
    end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if hum then
        hum.AutoRotate = true
        hum.PlatformStand = false
    end

    if hrp then
        hrp.AssemblyAngularVelocity = Vector3.zero
        if boost then
            local fwd = workspace.CurrentCamera.CFrame.LookVector
            hrp.AssemblyLinearVelocity = Vector3.new(fwd.X * 25, 30, fwd.Z * 25)
        else
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.5, math.clamp(v.Y, -20, 20), v.Z * 0.5)
        end
    end

    if alignPos then alignPos:Destroy() alignPos = nil end
    if activeBeam then activeBeam:Destroy() activeBeam = nil end
    if ropePart then ropePart:Destroy() ropePart = nil end
end

local function FireGrapple()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 or isGrappling then return end

    local cam = workspace.CurrentCamera
    local vSize = cam.ViewportSize
    local centerRay = cam:ViewportPointToRay(vSize.X / 2, vSize.Y / 2)

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { char, lightAnchor }
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local maxDist = currentLoadout.GrappleDistance or Config.GrappleDistance
    local hit = workspace:Raycast(centerRay.Origin, centerRay.Direction * maxDist, rayParams)
    if not hit or not hit.Instance then return end

    local targetPos = hit.Position
    isGrappling = true

    PlayLocalSFX("Grapple")
    makeNoiseEvent:FireServer(hrp.Position, 40)

    ropePart = Instance.new("Part")
    ropePart.Size = Vector3.new(0.5, 0.5, 0.5)
    ropePart.Position = targetPos
    ropePart.Anchored = true
    ropePart.CanCollide = false
    ropePart.Transparency = 1
    ropePart.Parent = workspace

    local att0 = Instance.new("Attachment")
    att0.Parent = hrp
    local att1 = Instance.new("Attachment")
    att1.Parent = ropePart

    activeBeam = Instance.new("Beam")
    activeBeam.Attachment0 = att0
    activeBeam.Attachment1 = att1
    activeBeam.Width0 = 0.2
    activeBeam.Width1 = 0.1
    activeBeam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 180))
    activeBeam.FaceCamera = true
    activeBeam.LightEmission = 1
    activeBeam.Parent = hrp

    alignPos = Instance.new("AlignPosition")
    alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
    alignPos.Attachment0 = att0
    alignPos.Attachment1 = att1
    alignPos.MaxForce = 1e6
    alignPos.MaxVelocity = currentLoadout.GrappleSpeed or Config.GrapplePullSpeed
    alignPos.Responsiveness = 45
    alignPos.Parent = hrp

    hum.AutoRotate = false

    local startTime = os.clock()
    local lastDist = (targetPos - hrp.Position).Magnitude

    updateConn = RunService.Heartbeat:Connect(function()
        if not isGrappling or not hrp.Parent then
            StopGrapple(false)
            return
        end

        local dist = (targetPos - hrp.Position).Magnitude
        local elapsed = os.clock() - startTime

        if dist <= 7.0 then
            StopGrapple(true)
            return
        end

        if elapsed > 1.8 or (elapsed > 0.4 and math.abs(dist - lastDist) < 0.05) then
            StopGrapple(false)
            return
        end

        lastDist = dist
    end)
end

-- ==========================================
-- ДЫМ (G)
-- ==========================================
local smokeCooldown = false
local function ThrowSmoke()
    if smokeCooldown then return end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    smokeCooldown = true
    PlayLocalSFX("Smoke")
    throwSmokeEvent:FireServer()

    task.delay(10, function() smokeCooldown = false end)
end

-- ==========================================
-- ОБРАБОТКА ВВОДА (E — ТОЛЬКО ВЗАИМОДЕЙСТВИЕ, Q — КРЮК)
-- ==========================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.Q then
        if isGrappling then StopGrapple(false) else FireGrapple() end
    elseif input.KeyCode == Enum.KeyCode.F then
        ToggleFlashlight()
    elseif input.KeyCode == Enum.KeyCode.G then
        ThrowSmoke()
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        local char = player.Character
        if char and char:FindFirstChild("Taser") then
            local cam = workspace.CurrentCamera
            local ray = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
            fireTaserEvent:FireServer(ray.Origin + ray.Direction * 35)
            PlayLocalSFX("Alarm")
        end
    end
end)

-- ==========================================
-- ИНТЕРФЕЙС HUD, РЮКЗАК И РЫНОК
-- ==========================================
local function CreateMainUI()
    local playerGui = player:WaitForChild("PlayerGui")
    local hud = Instance.new("ScreenGui")
    hud.Parent = playerGui
    hud.Name = "ExtractionHUD"
    hud.ResetOnSpawn = false

    -- Карточка статуса
    local card = Instance.new("Frame")
    card.Parent = hud
    card.Size = UDim2.new(0, 250, 0, 155)
    card.Position = UDim2.new(1, -265, 0, 20)
    card.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
    card.BackgroundTransparency = 0.2
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local lootLabel = Instance.new("TextLabel")
    lootLabel.Parent = card
    lootLabel.Size = UDim2.new(1, -20, 0, 20)
    lootLabel.Position = UDim2.new(0, 10, 0, 6)
    lootLabel.Text = "Добыча: $0"
    lootLabel.TextColor3 = Color3.fromRGB(0, 255, 180)
    lootLabel.TextSize = 17
    lootLabel.Font = Enum.Font.GothamBold
    lootLabel.TextXAlignment = Enum.TextXAlignment.Left
    lootLabel.BackgroundTransparency = 1

    local cashLabel = Instance.new("TextLabel")
    cashLabel.Parent = card
    cashLabel.Size = UDim2.new(1, -20, 0, 20)
    cashLabel.Position = UDim2.new(0, 10, 0, 30)
    cashLabel.Text = "Баланс: $0"
    cashLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    cashLabel.TextSize = 14
    cashLabel.Font = Enum.Font.GothamBold
    cashLabel.TextXAlignment = Enum.TextXAlignment.Left
    cashLabel.BackgroundTransparency = 1

    local leaderstats = player:WaitForChild("leaderstats", 10)
    local cashValue = leaderstats and leaderstats:WaitForChild("Cash", 5)
    if cashValue then
        cashLabel.Text = string.format("Баланс: $%d", cashValue.Value)
        cashValue:GetPropertyChangedSignal("Value"):Connect(function()
            cashLabel.Text = string.format("Баланс: $%d", cashValue.Value)
        end)
    else
        warn("[КЛИЕНТ]: Не удалось найти leaderstats.Cash для отображения баланса.")
    end

    local extractionLabel = Instance.new("TextLabel")
    extractionLabel.Parent = card
    extractionLabel.Size = UDim2.new(1, -20, 0, 20)
    extractionLabel.Position = UDim2.new(0, 10, 0, 78)
    extractionLabel.Text = "Эвакуация: не активна"
    extractionLabel.TextColor3 = Color3.fromRGB(160, 170, 185)
    extractionLabel.TextSize = 12
    extractionLabel.BackgroundTransparency = 1

    local summaryModal = Instance.new("Frame")
    summaryModal.Parent = hud
    summaryModal.Size = UDim2.new(0, 380, 0, 230)
    summaryModal.AnchorPoint = Vector2.new(0.5, 0.5)
    summaryModal.Position = UDim2.new(0.5, 0, 0.5, 0)
    summaryModal.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
    summaryModal.Visible = false
    summaryModal.ZIndex = 70
    Instance.new("UICorner", summaryModal).CornerRadius = UDim.new(0, 12)

    local summaryTitle = Instance.new("TextLabel")
    summaryTitle.Parent = summaryModal
    summaryTitle.Size = UDim2.new(1, -30, 0, 42)
    summaryTitle.Position = UDim2.new(0, 15, 0, 12)
    summaryTitle.BackgroundTransparency = 1
    summaryTitle.Font = Enum.Font.GothamBlack
    summaryTitle.TextSize = 20
    summaryTitle.TextColor3 = Color3.fromRGB(0, 255, 180)
    summaryTitle.ZIndex = 71

    local summaryDetails = Instance.new("TextLabel")
    summaryDetails.Parent = summaryModal
    summaryDetails.Size = UDim2.new(1, -40, 0, 105)
    summaryDetails.Position = UDim2.new(0, 20, 0, 62)
    summaryDetails.BackgroundTransparency = 1
    summaryDetails.Font = Enum.Font.GothamMedium
    summaryDetails.TextSize = 16
    summaryDetails.TextColor3 = Color3.fromRGB(230, 235, 240)
    summaryDetails.TextXAlignment = Enum.TextXAlignment.Left
    summaryDetails.TextYAlignment = Enum.TextYAlignment.Center
    summaryDetails.TextWrapped = true
    summaryDetails.ZIndex = 71

    local summaryClose = Instance.new("TextButton")
    summaryClose.Parent = summaryModal
    summaryClose.Size = UDim2.new(1, -40, 0, 36)
    summaryClose.Position = UDim2.new(0, 20, 1, -48)
    summaryClose.Text = "Продолжить"
    summaryClose.BackgroundColor3 = Color3.fromRGB(35, 115, 95)
    summaryClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    summaryClose.Font = Enum.Font.GothamBold
    summaryClose.ZIndex = 71
    Instance.new("UICorner", summaryClose).CornerRadius = UDim.new(0, 6)
    summaryClose.MouseButton1Click:Connect(function()
        summaryModal.Visible = false
    end)

    local weightLabel = Instance.new("TextLabel")
    weightLabel.Parent = card
    weightLabel.Size = UDim2.new(1, -20, 0, 20)
    weightLabel.Position = UDim2.new(0, 10, 0, 54)
    local effMaxW = LootLogic.GetEffectiveMaxWeight(currentLoadout.MaxWeight, currentUpgrades.Pockets)
    weightLabel.Text = string.format("Вес: 0.0 / %.1f кг [B]", effMaxW)
    weightLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    weightLabel.TextSize = 13
    weightLabel.Font = Enum.Font.GothamMedium
    weightLabel.TextXAlignment = Enum.TextXAlignment.Left
    weightLabel.BackgroundTransparency = 1

    local controlsHint = Instance.new("TextLabel")
    controlsHint.Parent = card
    controlsHint.Size = UDim2.new(1, -20, 0, 20)
    controlsHint.Position = UDim2.new(0, 10, 0, 100)
    controlsHint.Text = "[E] Взять | [Q] Крюк | [F] Свет | [G] Дым"
    controlsHint.TextColor3 = Color3.fromRGB(150, 160, 180)
    controlsHint.TextSize = 11
    controlsHint.Font = Enum.Font.Gotham
    controlsHint.TextXAlignment = Enum.TextXAlignment.Left
    controlsHint.BackgroundTransparency = 1

    -- Окно рюкзака (B)
    local invModal = Instance.new("Frame")
    invModal.Parent = hud
    invModal.Size = UDim2.new(0, 440, 0, 380)
    invModal.Position = UDim2.new(0.5, -220, 0.5, -190)
    invModal.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
    invModal.Visible = false
    invModal.ZIndex = 15
    Instance.new("UICorner", invModal).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Parent = invModal
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 15, 0, 5)
    title.Text = "РЮКЗАК НАЛЁТЧИКА [B чтобы закрыть]"
    title.TextColor3 = Color3.fromRGB(0, 255, 180)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1
    title.ZIndex = 16

    local scroll = Instance.new("ScrollingFrame")
    scroll.Parent = invModal
    scroll.Size = UDim2.new(1, -30, 1, -60)
    scroll.Position = UDim2.new(0, 15, 0, 45)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 5
    scroll.ZIndex = 16
    Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 6)

    local function RefreshInventoryList()
        for _, child in scroll:GetChildren() do
            if child:IsA("Frame") then child:Destroy() end
        end

        for index, item in ipairs(currentInventoryData.Items) do
            local row = Instance.new("Frame")
            row.Parent = scroll
            row.Size = UDim2.new(1, -10, 0, 44)
            row.BackgroundColor3 = Color3.fromRGB(28, 33, 42)
            row.ZIndex = 17
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Parent = row
            nameLabel.Size = UDim2.new(0.65, 0, 1, 0)
            nameLabel.Position = UDim2.new(0, 10, 0, 0)
            nameLabel.Text = string.format("%s ($%d, %.1f кг%s)", item.Name, item.Value, item.Weight, item.Fragile and " [ХРУПКОЕ]" or "")
            nameLabel.TextColor3 = item.Fragile and Color3.fromRGB(255, 140, 180) or Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 12
            nameLabel.Font = Enum.Font.GothamMedium
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.BackgroundTransparency = 1
            nameLabel.ZIndex = 18

            local dropBtn = Instance.new("TextButton")
            dropBtn.Parent = row
            dropBtn.Size = UDim2.new(0, 85, 0, 28)
            dropBtn.Position = UDim2.new(1, -95, 0.5, -14)
            dropBtn.Text = "Сбросить"
            dropBtn.BackgroundColor3 = Color3.fromRGB(160, 45, 45)
            dropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            dropBtn.Font = Enum.Font.GothamBold
            dropBtn.TextSize = 11
            dropBtn.ZIndex = 18
            Instance.new("UICorner", dropBtn).CornerRadius = UDim.new(0, 4)

            dropBtn.MouseButton1Click:Connect(function()
                dropItemEvent:FireServer(index)
            end)
        end
    end

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.B then
            invModal.Visible = not invModal.Visible
            if invModal.Visible then RefreshInventoryList() end
        end
    end)

    -- Комплекты: покупка навсегда, повторный выбор бесплатный.
    local loadoutModal = Instance.new("Frame")
    loadoutModal.Parent = hud
    loadoutModal.Name = "LoadoutModal"
    loadoutModal.Size = UDim2.new(0, 500, 0, 300)
    loadoutModal.AnchorPoint = Vector2.new(0.5, 0.5)
    loadoutModal.Position = UDim2.new(0.5, 0, 0.5, 0)
    loadoutModal.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
    loadoutModal.Visible = false
    loadoutModal.ZIndex = 55
    Instance.new("UICorner", loadoutModal).CornerRadius = UDim.new(0, 12)

    local loadoutTitle = Instance.new("TextLabel")
    loadoutTitle.Parent = loadoutModal
    loadoutTitle.Size = UDim2.new(1, -60, 0, 42)
    loadoutTitle.Position = UDim2.new(0, 18, 0, 8)
    loadoutTitle.BackgroundTransparency = 1
    loadoutTitle.Text = "КОМПЛЕКТЫ"
    loadoutTitle.TextColor3 = Color3.fromRGB(240, 180, 40)
    loadoutTitle.Font = Enum.Font.GothamBlack
    loadoutTitle.TextSize = 18
    loadoutTitle.TextXAlignment = Enum.TextXAlignment.Left
    loadoutTitle.ZIndex = 56

    local loadoutClose = Instance.new("TextButton")
    loadoutClose.Parent = loadoutModal
    loadoutClose.Size = UDim2.new(0, 32, 0, 32)
    loadoutClose.Position = UDim2.new(1, -44, 0, 10)
    loadoutClose.Text = "X"
    loadoutClose.ZIndex = 56
    loadoutClose.MouseButton1Click:Connect(function() loadoutModal.Visible = false end)

    local loadoutScroll = Instance.new("ScrollingFrame")
    loadoutScroll.Parent = loadoutModal
    loadoutScroll.Size = UDim2.new(1, -32, 1, -62)
    loadoutScroll.Position = UDim2.new(0, 16, 0, 52)
    loadoutScroll.BackgroundTransparency = 1
    loadoutScroll.BorderSizePixel = 0
    loadoutScroll.CanvasSize = UDim2.new(0, 0, 0, #Config.Loadouts * 88)
    loadoutScroll.ZIndex = 56
    local loadoutLayout = Instance.new("UIListLayout")
    loadoutLayout.Padding = UDim.new(0, 8)
    loadoutLayout.Parent = loadoutScroll

    local function RefreshLoadoutsUI()
        for _, child in loadoutScroll:GetChildren() do
            if child:IsA("Frame") then child:Destroy() end
        end

        for index, loadout in ipairs(Config.Loadouts) do
            local isOwned = ownedLoadouts[loadout.Id] == true
            local isEquipped = currentLoadout.Id == loadout.Id
            local row = Instance.new("Frame")
            row.Parent = loadoutScroll
            row.Size = UDim2.new(1, -8, 0, 78)
            row.BackgroundColor3 = Color3.fromRGB(28, 33, 42)
            row.LayoutOrder = index
            row.ZIndex = 57
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

            local info = Instance.new("TextLabel")
            info.Parent = row
            info.Size = UDim2.new(1, -150, 1, -8)
            info.Position = UDim2.new(0, 12, 0, 4)
            info.BackgroundTransparency = 1
            info.Text = string.format("%s\n%s", loadout.Name, loadout.Description)
            info.TextColor3 = Color3.fromRGB(235, 240, 245)
            info.Font = Enum.Font.GothamMedium
            info.TextSize = 12
            info.TextWrapped = true
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.ZIndex = 58

            local action = Instance.new("TextButton")
            action.Parent = row
            action.Size = UDim2.new(0, 124, 0, 38)
            action.Position = UDim2.new(1, -136, 0.5, -19)
            action.Font = Enum.Font.GothamBold
            action.TextSize = 12
            action.ZIndex = 58
            Instance.new("UICorner", action).CornerRadius = UDim.new(0, 6)

            if isEquipped then
                action.Text = "ЭКИПИРОВАН"
                action.BackgroundColor3 = Color3.fromRGB(45, 105, 85)
                action.TextColor3 = Color3.fromRGB(255, 255, 255)
                action.Active = false
                action.AutoButtonColor = false
            elseif isOwned then
                action.Text = "ВЫБРАТЬ"
                action.BackgroundColor3 = Color3.fromRGB(45, 105, 155)
                action.TextColor3 = Color3.fromRGB(255, 255, 255)
                action.MouseButton1Click:Connect(function()
                    selectLoadoutEvent:FireServer(loadout.Id)
                end)
            else
                action.Text = TEST_MODE and "ПОЛУЧИТЬ БЕСПЛАТНО" or string.format("КУПИТЬ $%d", loadout.Cost)
                action.BackgroundColor3 = Color3.fromRGB(190, 115, 30)
                action.TextColor3 = Color3.fromRGB(255, 255, 255)
                action.MouseButton1Click:Connect(function()
                    selectLoadoutEvent:FireServer(loadout.Id)
                end)
            end
        end
        loadoutScroll.CanvasSize = UDim2.new(0, 0, 0, #Config.Loadouts * 86)
    end

    local loadoutsButton = Instance.new("TextButton")
    loadoutsButton.Parent = card
    loadoutsButton.Size = UDim2.new(0, 108, 0, 25)
    loadoutsButton.Position = UDim2.new(1, -118, 0, 122)
    loadoutsButton.Text = "Комплекты [L]"
    loadoutsButton.TextSize = 11
    loadoutsButton.Font = Enum.Font.GothamBold
    loadoutsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    loadoutsButton.BackgroundColor3 = Color3.fromRGB(45, 85, 125)
    loadoutsButton.ZIndex = 10
    Instance.new("UICorner", loadoutsButton).CornerRadius = UDim.new(0, 5)
    loadoutsButton.MouseButton1Click:Connect(function()
        loadoutModal.Visible = not loadoutModal.Visible
        if loadoutModal.Visible then RefreshLoadoutsUI() end
    end)

    loadoutsUpdatedEvent.OnClientEvent:Connect(function(newOwnedLoadouts)
        if type(newOwnedLoadouts) == "table" then
            ownedLoadouts = newOwnedLoadouts
            if loadoutModal.Visible then RefreshLoadoutsUI() end
        end
    end)

    -- RemoteEvent может прийти до создания HUD, поэтому запрашиваем актуальное состояние.
    local ownershipSuccess, savedOwnedLoadouts = pcall(function()
        return getOwnedLoadoutsFunction:InvokeServer()
    end)
    if ownershipSuccess and type(savedOwnedLoadouts) == "table" then
        ownedLoadouts = savedOwnedLoadouts
    end

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.L then
            loadoutModal.Visible = not loadoutModal.Visible
            if loadoutModal.Visible then RefreshLoadoutsUI() end
        end
    end)

    -- Черный рынок
    local marketModal = Instance.new("Frame")
    marketModal.Parent = hud
    marketModal.Name = "MarketModal"
    marketModal.Size = UDim2.new(0, 520, 0, 320)
    marketModal.Position = UDim2.new(0.5, -260, 0.5, -160)
    marketModal.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
    marketModal.Visible = false
    marketModal.ZIndex = 50
    Instance.new("UICorner", marketModal).CornerRadius = UDim.new(0, 12)

    local mTitle = Instance.new("TextLabel")
    mTitle.Parent = marketModal
    mTitle.Size = UDim2.new(1, -40, 0, 45)
    mTitle.Position = UDim2.new(0, 20, 0, 8)
    mTitle.Text = "ЧЁРНЫЙ РЫНОК: АПГРЕЙДЫ"
    mTitle.TextColor3 = Color3.fromRGB(240, 180, 40)
    mTitle.Font = Enum.Font.GothamBlack
    mTitle.TextSize = 16
    mTitle.TextXAlignment = Enum.TextXAlignment.Left
    mTitle.BackgroundTransparency = 1
    mTitle.ZIndex = 51

    local mClose = Instance.new("TextButton")
    mClose.Parent = marketModal
    mClose.Size = UDim2.new(0, 32, 0, 32)
    mClose.Position = UDim2.new(1, -42, 0, 12)
    mClose.Text = "X"
    mClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    mClose.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
    mClose.Font = Enum.Font.GothamBold
    mClose.ZIndex = 52
    Instance.new("UICorner", mClose).CornerRadius = UDim.new(0, 6)
    mClose.MouseButton1Click:Connect(function() marketModal.Visible = false end)

    local mScroll = Instance.new("ScrollingFrame")
    mScroll.Parent = marketModal
    mScroll.Size = UDim2.new(1, -40, 1, -70)
    mScroll.Position = UDim2.new(0, 20, 0, 55)
    mScroll.BackgroundTransparency = 1
    mScroll.BorderSizePixel = 0
    mScroll.ZIndex = 51
    Instance.new("UIListLayout", mScroll).Padding = UDim.new(0, 8)

    local function RefreshMarketUI()
        for _, child in mScroll:GetChildren() do
            if child:IsA("Frame") then child:Destroy() end
        end

        for uKey, uData in pairs(LootLogic.UpgradesConfig) do
            local currentLvl = currentUpgrades[uKey] or 0
            local nextCost = LootLogic.GetUpgradeCost(uKey, currentLvl)

            local row = Instance.new("Frame")
            row.Parent = mScroll
            row.Size = UDim2.new(1, -10, 0, 60)
            row.BackgroundColor3 = Color3.fromRGB(28, 33, 42)
            row.ZIndex = 52
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

            local infoLabel = Instance.new("TextLabel")
            infoLabel.Parent = row
            infoLabel.Size = UDim2.new(0.65, 0, 1, 0)
            infoLabel.Position = UDim2.new(0, 12, 0, 0)
            infoLabel.Text = string.format("%s (Ур. %d/%d)\nБонус: +%d за уровень", uData.Name, currentLvl, uData.MaxLevel, uData.BonusPerLevel)
            infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            infoLabel.Font = Enum.Font.GothamMedium
            infoLabel.TextSize = 12
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            infoLabel.BackgroundTransparency = 1
            infoLabel.ZIndex = 53

            local buyBtn = Instance.new("TextButton")
            buyBtn.Parent = row
            buyBtn.Size = UDim2.new(0, 110, 0, 36)
            buyBtn.Position = UDim2.new(1, -120, 0.5, -18)
            buyBtn.ZIndex = 53
            Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 6)

            if nextCost then
                buyBtn.Text = string.format("Купить ($%d)", nextCost)
                buyBtn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
                buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                buyBtn.MouseButton1Click:Connect(function()
                    buyUpgradeEvent:FireServer(uKey)
                end)
            else
                buyBtn.Text = "МАКС. УРОВЕНЬ"
                buyBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
                buyBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end
    end

    upgradesUpdatedEvent.OnClientEvent:Connect(function(newUpgrades, openUI)
        currentUpgrades = newUpgrades
        spotBeam.Range = LootLogic.GetEffectiveFlashlightRange(75, currentUpgrades.Battery)
        local effW = LootLogic.GetEffectiveMaxWeight(currentLoadout.MaxWeight, currentUpgrades.Pockets)
        weightLabel.Text = string.format("Вес: %.1f / %.1f кг [B]", currentInventoryData.TotalWeight, effW)

        if openUI then marketModal.Visible = true end
        if marketModal.Visible then RefreshMarketUI() end
    end)

    -- Forward declarations let the station callback access the command room UI below.
    local commandModal
    local RefreshCommandRoom

    -- Station prompts open the existing interfaces instead of duplicating their logic.
    openHideoutStationEvent.OnClientEvent:Connect(function(stationName)
        print("[HideoutStation][CLIENT] Received:", stationName, "Phase:", currentPhaseValue.Value)

        if stationName == "Armory" then
            marketModal.Visible = false
            loadoutModal.Visible = true
            RefreshLoadoutsUI()
        elseif stationName == "Workshop" then
            loadoutModal.Visible = false
            marketModal.Visible = true
            RefreshMarketUI()
        elseif stationName == "Command" then
            commandModal.Visible = true
            RefreshCommandRoom()
        end
    end)

    -- Command room: live raid roster and local spectator camera controls.
    commandModal = Instance.new("Frame")
    commandModal.Name = "CommandRoomModal"
    commandModal.Parent = hud
    commandModal.Size = UDim2.new(0, 480, 0, 340)
    commandModal.AnchorPoint = Vector2.new(0.5, 0.5)
    commandModal.Position = UDim2.new(0.5, 0, 0.5, 0)
    commandModal.BackgroundColor3 = Color3.fromRGB(15, 23, 29)
    commandModal.Visible = false
    commandModal.ZIndex = 70
    Instance.new("UICorner", commandModal).CornerRadius = UDim.new(0, 10)

    local commandTitle = Instance.new("TextLabel")
    commandTitle.Parent = commandModal
    commandTitle.Size = UDim2.new(1, -110, 0, 42)
    commandTitle.Position = UDim2.new(0, 16, 0, 8)
    commandTitle.BackgroundTransparency = 1
    commandTitle.Text = "ЦЕНТР УПРАВЛЕНИЯ РЕЙДОМ"
    commandTitle.TextColor3 = Color3.fromRGB(100, 220, 160)
    commandTitle.Font = Enum.Font.GothamBold
    commandTitle.TextSize = 16
    commandTitle.TextXAlignment = Enum.TextXAlignment.Left
    commandTitle.ZIndex = 71

    local commandClose = Instance.new("TextButton")
    commandClose.Parent = commandModal
    commandClose.Size = UDim2.new(0, 34, 0, 30)
    commandClose.Position = UDim2.new(1, -46, 0, 10)
    commandClose.Text = "X"
    commandClose.TextColor3 = Color3.new(1, 1, 1)
    commandClose.BackgroundColor3 = Color3.fromRGB(135, 45, 45)
    commandClose.Font = Enum.Font.GothamBold
    commandClose.ZIndex = 72
    commandClose.MouseButton1Click:Connect(function()
        commandModal.Visible = false
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local camera = workspace.CurrentCamera
            camera.CameraSubject = humanoid
        end
    end)

    local commandRefresh = Instance.new("TextButton")
    commandRefresh.Parent = commandModal
    commandRefresh.Size = UDim2.new(0, 110, 0, 30)
    commandRefresh.Position = UDim2.new(1, -164, 0, 10)
    commandRefresh.Text = "Обновить"
    commandRefresh.TextColor3 = Color3.new(1, 1, 1)
    commandRefresh.BackgroundColor3 = Color3.fromRGB(45, 90, 115)
    commandRefresh.Font = Enum.Font.GothamBold
    commandRefresh.ZIndex = 72

    local commandStatus = Instance.new("TextLabel")
    commandStatus.Parent = commandModal
    commandStatus.Size = UDim2.new(1, -32, 0, 24)
    commandStatus.Position = UDim2.new(0, 16, 0, 48)
    commandStatus.BackgroundTransparency = 1
    commandStatus.Text = "Состояние игроков"
    commandStatus.TextColor3 = Color3.fromRGB(180, 195, 205)
    commandStatus.Font = Enum.Font.Gotham
    commandStatus.TextSize = 12
    commandStatus.TextXAlignment = Enum.TextXAlignment.Left
    commandStatus.ZIndex = 71

    local commandList = Instance.new("ScrollingFrame")
    commandList.Parent = commandModal
    commandList.Size = UDim2.new(1, -32, 1, -88)
    commandList.Position = UDim2.new(0, 16, 0, 78)
    commandList.BackgroundTransparency = 1
    commandList.BorderSizePixel = 0
    commandList.ScrollBarThickness = 5
    commandList.ZIndex = 71
    local commandLayout = Instance.new("UIListLayout")
    commandLayout.Padding = UDim.new(0, 6)
    commandLayout.Parent = commandList

    RefreshCommandRoom = function()
        for _, child in commandList:GetChildren() do
            if child:IsA("Frame") then child:Destroy() end
        end

        local success, roster = pcall(function()
            return getRaidStatusFunction:InvokeServer()
        end)
        if not success or type(roster) ~= "table" then
            commandStatus.Text = "Не удалось получить состояние рейда"
            return
        end

        local activeCount = 0
        for index, entry in ipairs(roster) do
            if entry.CanSpectate then activeCount += 1 end
            local row = Instance.new("Frame")
            row.Parent = commandList
            row.Size = UDim2.new(1, -8, 0, 48)
            row.BackgroundColor3 = Color3.fromRGB(27, 37, 44)
            row.LayoutOrder = index
            row.ZIndex = 72
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Parent = row
            nameLabel.Size = UDim2.new(0.62, 0, 1, 0)
            nameLabel.Position = UDim2.new(0, 12, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = entry.DisplayName .. "  —  " .. entry.Status
            nameLabel.TextColor3 = Color3.fromRGB(230, 235, 240)
            nameLabel.Font = Enum.Font.GothamMedium
            nameLabel.TextSize = 12
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.ZIndex = 73

            if entry.CanSpectate then
                local watchButton = Instance.new("TextButton")
                watchButton.Parent = row
                watchButton.Size = UDim2.new(0, 112, 0, 30)
                watchButton.Position = UDim2.new(1, -122, 0.5, -15)
                watchButton.Text = "НАБЛЮДАТЬ"
                watchButton.TextColor3 = Color3.new(1, 1, 1)
                watchButton.BackgroundColor3 = Color3.fromRGB(40, 115, 85)
                watchButton.Font = Enum.Font.GothamBold
                watchButton.TextSize = 11
                watchButton.ZIndex = 73
                watchButton.MouseButton1Click:Connect(function()
                    local target = Players:GetPlayerByUserId(entry.UserId)
                    local targetCharacter = target and target.Character
                    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
                    if targetHumanoid and targetHumanoid.Health > 0 then
                        local camera = workspace.CurrentCamera
                        camera.CameraSubject = targetHumanoid
                        commandStatus.Text = "Наблюдение: " .. entry.DisplayName
                    else
                        commandStatus.Text = "Игрок больше недоступен для наблюдения"
                    end
                end)
            end
        end

        commandStatus.Text = string.format("Игроков в рейде: %d · Обновляй список вручную", activeCount)
        commandList.CanvasSize = UDim2.new(0, 0, 0, #roster * 54)
    end

    commandRefresh.MouseButton1Click:Connect(RefreshCommandRoom)

    loadoutAppliedEvent.OnClientEvent:Connect(function(appliedLoadout, appliedUpgrades)
        currentLoadout = appliedLoadout
        if appliedUpgrades then currentUpgrades = appliedUpgrades end
        spotBeam.Range = LootLogic.GetEffectiveFlashlightRange(75, currentUpgrades.Battery)
        local effW = LootLogic.GetEffectiveMaxWeight(currentLoadout.MaxWeight, currentUpgrades.Pockets)
        weightLabel.Text = string.format("Вес: %.1f / %.1f кг [B]", currentInventoryData.TotalWeight, effW)
        if loadoutModal.Visible then RefreshLoadoutsUI() end
    end)

    inventoryUpdatedEvent.OnClientEvent:Connect(function(invData, message)
        currentInventoryData = invData
        lootLabel.Text = string.format("Добыча: $%d", invData.TotalValue)
        local effW = LootLogic.GetEffectiveMaxWeight(currentLoadout.MaxWeight, currentUpgrades.Pockets)
        weightLabel.Text = string.format("Вес: %.1f / %.1f кг [B]", invData.TotalWeight, effW)

        if invModal.Visible then RefreshInventoryList() end
        if message then PlayLocalSFX("Pickup") end
    end)

    extractionProgressEvent.OnClientEvent:Connect(function(remaining, completed)
        if completed then
            extractionLabel.Text = "Эвакуация: успешно!"
        elseif remaining < 0 then
            extractionLabel.Text = "Эвакуация: прервана"
        else
            extractionLabel.Text = string.format("Эвакуация: %.1f сек", remaining)
        end
    end)

    raidSummaryEvent.OnClientEvent:Connect(function(escaped, lootValue, itemCount, totalCash)
        summaryTitle.Text = escaped and "ЭВАКУАЦИЯ УСПЕШНА" or "РЕЙД НЕ ЗАВЕРШЁН"
        summaryTitle.TextColor3 = escaped and Color3.fromRGB(0, 255, 180) or Color3.fromRGB(255, 130, 100)
        summaryDetails.Text = escaped
            and string.format("Вынесено предметов: %d\nСтоимость добычи: $%d\nПостоянный баланс: $%d", itemCount, lootValue, totalCash)
            or string.format("Эвакуация не состоялась.\nДобыча потеряна.\nПостоянный баланс: $%d", totalCash)
        summaryModal.Visible = true
    end)
end

task.spawn(CreateMainUI)

-- ==========================================
-- ТАЙМЕР РАУНДА
-- ==========================================
local function CreateTimerUI()
    local playerGui = player:WaitForChild("PlayerGui")
    local timerGui = Instance.new("ScreenGui")
    timerGui.Parent = playerGui
    timerGui.Name = "TimerHUD"
    timerGui.ResetOnSpawn = false

    local topBar = Instance.new("Frame")
    topBar.Parent = timerGui
    topBar.Size = UDim2.new(0, 260, 0, 45)
    topBar.Position = UDim2.new(0.5, -130, 0, 15)
    topBar.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
    topBar.BackgroundTransparency = 0.2
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

    local phaseLabel = Instance.new("TextLabel")
    phaseLabel.Parent = topBar
    phaseLabel.Size = UDim2.new(1, 0, 1, 0)
    phaseLabel.Text = "Загрузка..."
    phaseLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    phaseLabel.TextSize = 16
    phaseLabel.Font = Enum.Font.GothamBold
    phaseLabel.BackgroundTransparency = 1

    local startRaidButton = Instance.new("TextButton")
    startRaidButton.Parent = timerGui
    startRaidButton.Size = UDim2.new(0, 220, 0, 42)
    startRaidButton.Position = UDim2.new(0.5, -110, 0, 68)
    startRaidButton.BackgroundColor3 = Color3.fromRGB(35, 135, 85)
    startRaidButton.TextColor3 = Color3.new(1, 1, 1)
    startRaidButton.Text = "НАЧАТЬ РЕЙД"
    startRaidButton.Font = Enum.Font.GothamBold
    startRaidButton.TextSize = 15
    startRaidButton.Visible = currentPhaseValue.Value == "LobbyPhase"
    Instance.new("UICorner", startRaidButton).CornerRadius = UDim.new(0, 8)

    startRaidButton.MouseButton1Click:Connect(function()
        if currentPhaseValue.Value ~= "LobbyPhase" then return end
        startRaidButton.Active = false
        startRaidButton.Text = "ЗАПРОС..."
        startRaidEvent:FireServer()
        -- If the server rejects the request (for example, outside the hideout),
        -- allow the player to try again after moving to the correct location.
        task.delay(1.5, function()
            if currentPhaseValue.Value == "LobbyPhase" then
                startRaidButton.Active = true
                startRaidButton.Text = "НАЧАТЬ РЕЙД"
            end
        end)
    end)

    -- A newer phase invalidates the timer task from the previous phase.
    local timerGeneration = 0

    stateChangedEvent.OnClientEvent:Connect(function(phase, dur)
        startRaidButton.Visible = phase == "LobbyPhase"
        startRaidButton.Active = phase == "LobbyPhase"
        startRaidButton.Text = "НАЧАТЬ РЕЙД"
        if phase == "LobbyPhase" then
            phaseLabel.Text = "Убежище — ожидание запуска"
            phaseLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        end
        timerGeneration += 1
        local currentGeneration = timerGeneration
        local finish = os.clock() + dur
        task.spawn(function()
            while currentGeneration == timerGeneration and os.clock() < finish do
                local left = math.ceil(finish - os.clock())
                if phase == "LobbyPhase" then
                    phaseLabel.Text = string.format("Убежище: %d сек", left)
                    phaseLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
                elseif phase == "LootPhase" then
                    phaseLabel.Text = string.format("Сбор лута: %d сек", left)
                    phaseLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
                elseif phase == "ExtractionPhase" then
                    phaseLabel.Text = string.format("ЭВАКУАЦИЯ: %d сек!", left)
                    phaseLabel.TextColor3 = Color3.fromRGB(0, 255, 140)
                end
                task.wait(1)
            end
        end)
    end)
end

task.spawn(CreateTimerUI)


-- ==========================================
-- ИНДИКАТОР НОЧНОГО СОБЫТИЯ
-- ==========================================
local function CreateNightEventUI()
    local playerGui = player:WaitForChild("PlayerGui")
    local oldGui = playerGui:FindFirstChild("NightEventGui")
    if oldGui then oldGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NightEventGui"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local banner = Instance.new("Frame")
    banner.Name = "Banner"
    banner.Size = UDim2.new(0, 430, 0, 94)
    banner.Position = UDim2.new(0.5, -215, 0, 24)
    banner.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
    banner.BackgroundTransparency = 0.12
    banner.Visible = false
    banner.Parent = gui
    Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 32)
    title.Position = UDim2.new(0, 10, 0, 7)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 21
    title.TextColor3 = Color3.fromRGB(255, 200, 80)
    title.Text = ""
    title.Parent = banner

    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(1, -24, 0, 44)
    description.Position = UDim2.new(0, 12, 0, 42)
    description.BackgroundTransparency = 1
    description.Font = Enum.Font.GothamMedium
    description.TextSize = 13
    description.TextWrapped = true
    description.TextColor3 = Color3.fromRGB(235, 235, 235)
    description.Text = ""
    description.Parent = banner

    local generation = 0
    local function refreshCurrentEvent()
        local eventName = currentNightEventValue.Value
        if eventName == "" then
            banner.Visible = false
        else
            title.Text = eventName
            banner.Visible = true
        end
    end

    currentNightEventValue.Changed:Connect(refreshCurrentEvent)
    nightEventEvent.OnClientEvent:Connect(function(_eventId, eventName, eventDescription)
        if type(eventName) ~= "string" or eventName == "" then return end
        generation += 1
        local currentGeneration = generation
        title.Text = eventName
        description.Text = type(eventDescription) == "string" and eventDescription or ""
        banner.Visible = true

        task.delay(7, function()
            if currentGeneration == generation and currentNightEventValue.Value == "" then
                banner.Visible = false
            end
        end)
    end)

    refreshCurrentEvent()
end

task.spawn(CreateNightEventUI)

print("[КЛИЕНТ]: Клиентский контроллер активен. Сбор [E], Крюк [Q], Фонарь [F], Дым [G].")