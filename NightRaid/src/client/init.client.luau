--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TEST_MODE = RunService:IsStudio()

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))
local CosmeticsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticsConfig"))

local player = Players.LocalPlayer

-- ==========================================
-- БЕЗОПАСНОЕ ПОДКЛЮЧЕНИЕ К NETWORK
-- ==========================================
local networkFolder = ReplicatedStorage:WaitForChild("Network", 10)
if not networkFolder then
    warn("[Client Error]: Network folder not found!")
    return
end

local currentPhaseValue = networkFolder:WaitForChild("CurrentPhase") :: StringValue
local stateChangedEvent = networkFolder:WaitForChild("StateChanged") :: RemoteEvent
local inventoryUpdatedEvent = networkFolder:WaitForChild("InventoryUpdated") :: RemoteEvent
local extractionProgressEvent = networkFolder:WaitForChild("ExtractionProgress") :: RemoteEvent
local dropItemEvent = networkFolder:WaitForChild("DropItem") :: RemoteEvent
local selectLoadoutEvent = networkFolder:WaitForChild("SelectLoadout") :: RemoteEvent
local loadoutsUpdatedEvent = networkFolder:WaitForChild("LoadoutsUpdated") :: RemoteEvent
local getOwnedLoadoutsFunction = networkFolder:WaitForChild("GetOwnedLoadouts") :: RemoteFunction
local loadoutAppliedEvent = networkFolder:WaitForChild("LoadoutApplied") :: RemoteEvent
local makeNoiseEvent = networkFolder:WaitForChild("MakeNoise") :: RemoteEvent
local raidSummaryEvent = networkFolder:WaitForChild("ShowRaidSummary") :: RemoteEvent
local throwSmokeEvent = networkFolder:WaitForChild("ThrowSmoke") :: RemoteEvent
local fireTaserEvent = networkFolder:WaitForChild("FireTaser") :: RemoteEvent
local buyUpgradeEvent = networkFolder:WaitForChild("BuyUpgrade") :: RemoteEvent
local upgradesUpdatedEvent = networkFolder:WaitForChild("UpgradesUpdated") :: RemoteEvent
local openHideoutStationEvent = networkFolder:WaitForChild("OpenHideoutStation") :: RemoteEvent
local nightEventEvent = networkFolder:WaitForChild("NightEvent") :: RemoteEvent
local currentNightEventValue = networkFolder:WaitForChild("CurrentNightEvent") :: StringValue
local getRaidStatusFunction = networkFolder:WaitForChild("GetRaidStatus") :: RemoteFunction
local getRaidReplayFunction = networkFolder:WaitForChild("GetRaidReplay") :: RemoteFunction
local startRaidEvent = networkFolder:WaitForChild("StartRaid") :: RemoteEvent
local alertLevelChangedEvent = networkFolder:WaitForChild("AlertLevelChanged") :: RemoteEvent
local playerDownedStateEvent = networkFolder:WaitForChild("PlayerDownedState") :: RemoteEvent
local toggleCrouchEvent = networkFolder:WaitForChild("ToggleCrouch") :: RemoteEvent
local buyCosmeticEvent = networkFolder:WaitForChild("BuyCosmetic") :: RemoteEvent
local equipCosmeticEvent = networkFolder:WaitForChild("EquipCosmetic") :: RemoteEvent
local cosmeticsUpdatedEvent = networkFolder:WaitForChild("CosmeticsUpdated") :: RemoteEvent
local trophiesUpdatedEvent = networkFolder:WaitForChild("TrophiesUpdated") :: RemoteEvent
local radioPingEvent = networkFolder:WaitForChild("RadioPing") :: RemoteEvent
local grappleEffectEvent = networkFolder:WaitForChild("GrappleEffect") :: RemoteEvent
local contractsUpdatedEvent = networkFolder:WaitForChild("ContractsUpdated") :: RemoteEvent
local _hideoutDecoUpdatedEvent = networkFolder:WaitForChild("HideoutDecoUpdated") :: RemoteEvent
local _buyHideoutDecoEvent = networkFolder:WaitForChild("BuyHideoutDeco") :: RemoteEvent
local getDailyContractsFunction = networkFolder:WaitForChild("GetDailyContracts") :: RemoteFunction
local getLeaderboardFunction = networkFolder:WaitForChild("GetLeaderboard") :: RemoteFunction

local currentInventoryData = { TotalValue = 0, TotalWeight = 0, Items = {} }
local currentLoadout = Config.Loadouts[1]
local ownedLoadouts: { [string]: boolean } = { Default = true }
local currentUpgrades = { Pockets = 0, SmokeStarter = 0, Battery = 0 }

-- ==========================================
-- ЗВУКИ (SFX С ПРЕДЗАГРУЗКОЙ И ПРИВЯЗКОЙ К КАМЕРЕ)
-- ==========================================
local ContentProvider = game:GetService("ContentProvider")
local soundCacheFolder = Instance.new("Folder")
soundCacheFolder.Name = "SoundCache"
soundCacheFolder.Parent = workspace.CurrentCamera

local soundTemplates: { [string]: Sound } = {}
local SFX_CONFIG: { [string]: { Id: string, Speed: number, Volume: number } } = {
    Grapple = { Id = "rbxassetid://9120972321", Speed = 1.3, Volume = 1.2 },
    Alarm = { Id = "rbxassetid://9119661709", Speed = 0.9, Volume = 1.5 },
    Pickup = { Id = "rbxassetid://9116394545", Speed = 1.2, Volume = 1.4 },
    Smoke = { Id = "rbxassetid://15675021174", Speed = 1.1, Volume = 1.1 },
    Heartbeat = { Id = "rbxassetid://1841124374", Speed = 0.8, Volume = 1.3 },
    RadioChirp = { Id = "rbxassetid://6667292683", Speed = 1.4, Volume = 1.3 },
    CrouchStep = { Id = "rbxassetid://9114785786", Speed = 1.5, Volume = 0.75 },
    TaserZap = { Id = "rbxassetid://9116275998", Speed = 1.2, Volume = 1.4 },
}

for soundType, cfg in SFX_CONFIG do
    local s = Instance.new("Sound")
    s.Name = soundType
    s.SoundId = cfg.Id
    s.PlaybackSpeed = cfg.Speed
    s.Volume = cfg.Volume
    s.Parent = soundCacheFolder
    soundTemplates[soundType] = s
end

task.spawn(function()
    local toPreload = {}
    for _, s in soundTemplates do
        table.insert(toPreload, s)
    end
    pcall(function()
        ContentProvider:PreloadAsync(toPreload)
    end)
end)

local function PlayLocalSFX(soundType: string)
    local template = soundTemplates[soundType]
    if not template then return end

    local sound = template:Clone()
    sound.Parent = workspace.CurrentCamera or SoundService
    pcall(function()
        sound:Play()
    end)
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
    task.delay(4, function()
        if sound.Parent then
            sound:Destroy()
        end
    end)
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

local existingLightAnchor = workspace:FindFirstChild("ClientFlashlightRig")
if existingLightAnchor then
    existingLightAnchor:Destroy()
end

local lightAnchor: Part = Instance.new("Part")
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
    if not isFlashlightOn or not lightAnchor then return end

    local char = player.Character
    local head = char and char:FindFirstChild("Head") :: BasePart?
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
local alignPos: AlignPosition? = nil
local activeBeam: Beam? = nil
local ropePart: Part? = nil
local updateConn: RBXScriptConnection? = nil

local function StopGrapple(boost: boolean)
    if not isGrappling then return end
    isGrappling = false

    if updateConn then
        updateConn:Disconnect()
        updateConn = nil
    end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
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

    if alignPos then
        alignPos:Destroy()
        alignPos = nil
    end
    if activeBeam then
        activeBeam:Destroy()
        activeBeam = nil
    end
    if ropePart then
        ropePart:Destroy()
        ropePart = nil
    end

    grappleEffectEvent:FireServer(Vector3.zero, false)
end

local function FireGrapple()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
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

    grappleEffectEvent:FireServer(targetPos, true)
    PlayLocalSFX("Grapple")
    makeNoiseEvent:FireServer()

    local newRope = Instance.new("Part")
    newRope.Size = Vector3.new(0.5, 0.5, 0.5)
    newRope.Position = targetPos
    newRope.Anchored = true
    newRope.CanCollide = false
    newRope.Transparency = 1
    newRope.Parent = workspace
    ropePart = newRope

    local att0 = Instance.new("Attachment")
    att0.Parent = hrp
    local att1 = Instance.new("Attachment")
    att1.Parent = newRope

    local newBeam = Instance.new("Beam")
    newBeam.Attachment0 = att0
    newBeam.Attachment1 = att1
    newBeam.Width0 = 0.2
    newBeam.Width1 = 0.1
    newBeam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 180))
    newBeam.FaceCamera = true
    newBeam.LightEmission = 1
    newBeam.Parent = hrp
    activeBeam = newBeam

    local newAlignPos = Instance.new("AlignPosition")
    newAlignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
    newAlignPos.Attachment0 = att0
    newAlignPos.Attachment1 = att1
    newAlignPos.MaxForce = 1e6
    newAlignPos.MaxVelocity = currentLoadout.GrappleSpeed or Config.GrapplePullSpeed
    newAlignPos.Responsiveness = 45
    newAlignPos.Parent = hrp
    alignPos = newAlignPos

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

-- Сетевая репликация троса крюка для других игроков в коопе
local otherPlayerGrapples: { [Player]: { Rope: Part, Beam: Beam } } = {}

grappleEffectEvent.OnClientEvent:Connect(function(sourcePlayer: Player, targetPos: Vector3, isActive: boolean)
    if sourcePlayer == player then return end

    local existing = otherPlayerGrapples[sourcePlayer]
    if existing then
        if existing.Beam then existing.Beam:Destroy() end
        if existing.Rope then existing.Rope:Destroy() end
        otherPlayerGrapples[sourcePlayer] = nil
    end

    if isActive then
        local sChar = sourcePlayer.Character
        local sRoot = sChar and sChar:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not sRoot then return end

        local rPart = Instance.new("Part")
        rPart.Name = "NetworkRopePart"
        rPart.Size = Vector3.new(0.5, 0.5, 0.5)
        rPart.Position = targetPos
        rPart.Anchored = true
        rPart.CanCollide = false
        rPart.Transparency = 1
        rPart.Parent = workspace

        local a0 = Instance.new("Attachment")
        a0.Parent = sRoot
        local a1 = Instance.new("Attachment")
        a1.Parent = rPart

        local beam = Instance.new("Beam")
        beam.Attachment0 = a0
        beam.Attachment1 = a1
        beam.Width0 = 0.2
        beam.Width1 = 0.1
        beam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 180))
        beam.FaceCamera = true
        beam.LightEmission = 1
        beam.Parent = sRoot

        local sfxTemplate = soundTemplates["Grapple"]
        if sfxTemplate then
            local sound = sfxTemplate:Clone()
            sound.Parent = sRoot
            sound:Play()
            sound.Ended:Connect(function() sound:Destroy() end)
            task.delay(3, function() if sound.Parent then sound:Destroy() end end)
        end

        otherPlayerGrapples[sourcePlayer] = { Rope = rPart, Beam = beam }
    end
end)

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
-- СКРЫТНОСТЬ И ПРИСЕДАНИЕ (C / Ctrl)
-- ==========================================
local isCrouched = false
local function ToggleCrouch()
    isCrouched = not isCrouched
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.CameraOffset = if isCrouched then Vector3.new(0, -1.2, 0) else Vector3.zero
    end
    toggleCrouchEvent:FireServer(isCrouched)
    PlayLocalSFX("CrouchStep")
end

-- ==========================================
-- ТАКТИЧЕСКИЙ РАДИО-ПИНГ (V)
-- ==========================================
local function TriggerRadioPing()
    local cam = workspace.CurrentCamera
    local ray = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { player.Character :: Instance }
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local hit = workspace:Raycast(ray.Origin, ray.Direction * 150, rayParams)
    local pingPos = hit and hit.Position or (ray.Origin + ray.Direction * 60)
    radioPingEvent:FireServer(pingPos, "Danger")
end

radioPingEvent.OnClientEvent:Connect(function(senderPlayer: Player, pingPos: Vector3, pingType: string)
    PlayLocalSFX("RadioChirp")
    local marker = Instance.new("Part")
    marker.Name = "RadioPingMarker"
    marker.Size = Vector3.new(1.2, 1.2, 1.2)
    marker.Position = pingPos
    marker.Transparency = 1
    marker.Anchored = true
    marker.CanCollide = false
    marker.Parent = workspace

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 160, 0, 36)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = marker

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Text = string.format("📍 [%s]: ОПАСНОСТЬ!", senderPlayer.DisplayName)
    lbl.TextColor3 = Color3.fromRGB(255, 60, 60)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 12
    lbl.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
    lbl.BackgroundTransparency = 0.2
    lbl.Parent = bb
    local crn = Instance.new("UICorner")
    crn.CornerRadius = UDim.new(0, 6)
    crn.Parent = lbl

    task.delay(5.0, function()
        if marker then marker:Destroy() end
    end)
end)

-- ==========================================
-- АТМОСФЕРНЫЙ ПУЛЬС СЕРДЦЕБИЕНИЯ (САСПЕНС)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.6)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local guard = workspace:FindFirstChild("GuardNPC")
        local guardHrp = guard and guard:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp and guardHrp and currentPhaseValue.Value == "LootPhase" then
            local dist = (hrp.Position - guardHrp.Position).Magnitude
            if dist <= 45 then
                PlayLocalSFX("Heartbeat")
                task.wait(math.clamp(dist / 45, 0.35, 1.0))
            end
        end
    end
end)

-- ==========================================
-- ОБРАБОТКА ВВОДА (PC, GAMEPAD & MOBILE VIA ContextActionService)
-- ==========================================
local function handleGrappleAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
    if inputState == Enum.UserInputState.Begin then
        if isGrappling then StopGrapple(false) else FireGrapple() end
        return Enum.ContextActionResult.Sink
    end
    return Enum.ContextActionResult.Pass
end

local function handleFlashlightAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
    if inputState == Enum.UserInputState.Begin then
        ToggleFlashlight()
        return Enum.ContextActionResult.Sink
    end
    return Enum.ContextActionResult.Pass
end

local function handleSmokeAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
    if inputState == Enum.UserInputState.Begin then
        ThrowSmoke()
        return Enum.ContextActionResult.Sink
    end
    return Enum.ContextActionResult.Pass
end

local function handleCrouchAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
    if inputState == Enum.UserInputState.Begin then
        ToggleCrouch()
        return Enum.ContextActionResult.Sink
    end
    return Enum.ContextActionResult.Pass
end

local function handleRadioPingAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
    if inputState == Enum.UserInputState.Begin then
        TriggerRadioPing()
        return Enum.ContextActionResult.Sink
    end
    return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("GrappleAction", handleGrappleAction, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
ContextActionService:SetTitle("GrappleAction", "🪝")
ContextActionService:SetPosition("GrappleAction", UDim2.new(1, -85, 1, -165))

ContextActionService:BindAction("FlashlightAction", handleFlashlightAction, true, Enum.KeyCode.F, Enum.KeyCode.DPadUp)
ContextActionService:SetTitle("FlashlightAction", "🔦")
ContextActionService:SetPosition("FlashlightAction", UDim2.new(1, -85, 1, -235))

ContextActionService:BindAction("SmokeAction", handleSmokeAction, true, Enum.KeyCode.G, Enum.KeyCode.DPadDown)
ContextActionService:SetTitle("SmokeAction", "💨")
ContextActionService:SetPosition("SmokeAction", UDim2.new(1, -155, 1, -165))

ContextActionService:BindAction("CrouchAction", handleCrouchAction, true, Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("CrouchAction", "🚶")
ContextActionService:SetPosition("CrouchAction", UDim2.new(1, -155, 1, -235))

ContextActionService:BindAction("RadioPingAction", handleRadioPingAction, false, Enum.KeyCode.V, Enum.KeyCode.ButtonR3)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton3 then
        TriggerRadioPing()
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
        local char = player.Character
        if char and char:FindFirstChild("Taser") then
            local cam = workspace.CurrentCamera
            local ray = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
            fireTaserEvent:FireServer(ray.Origin + ray.Direction * 35)
            PlayLocalSFX("TaserZap")
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
    card.Size = UDim2.new(0, 250, 0, 175)
    card.Position = UDim2.new(1, -265, 0, 20)
    card.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
    card.BackgroundTransparency = 0.2
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local alertLabel = Instance.new("TextLabel")
    alertLabel.Parent = card
    alertLabel.Size = UDim2.new(1, -20, 0, 18)
    alertLabel.Position = UDim2.new(0, 10, 0, 122)
    alertLabel.Text = Locale.Format("AlertLevelText", 0)
    alertLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    alertLabel.TextSize = 11
    alertLabel.Font = Enum.Font.GothamBold
    alertLabel.TextXAlignment = Enum.TextXAlignment.Left
    alertLabel.BackgroundTransparency = 1

    alertLevelChangedEvent.OnClientEvent:Connect(function(level: number)
        alertLabel.Text = Locale.Format("AlertLevelText", level)
        if level >= 75 then
            alertLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        elseif level >= 40 then
            alertLabel.TextColor3 = Color3.fromRGB(255, 170, 40)
        elseif level > 0 then
            alertLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
        else
            alertLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
        end
    end)

    playerDownedStateEvent.OnClientEvent:Connect(function(targetPlayer: Player, isDowned: boolean)
        if targetPlayer == player then
            if isDowned then
                PlayLocalSFX("Alarm")
            else
                PlayLocalSFX("Pickup")
            end
        end
    end)

    trophiesUpdatedEvent.OnClientEvent:Connect(function(_trophies: { [string]: boolean })
        PlayLocalSFX("Pickup")
    end)

    local lootLabel = Instance.new("TextLabel")
    lootLabel.Parent = card
    lootLabel.Size = UDim2.new(1, -20, 0, 20)
    lootLabel.Position = UDim2.new(0, 10, 0, 6)
    lootLabel.Text = Locale.Format("LootLabel", 0)
    lootLabel.TextColor3 = Color3.fromRGB(0, 255, 180)
    lootLabel.TextSize = 17
    lootLabel.Font = Enum.Font.GothamBold
    lootLabel.TextXAlignment = Enum.TextXAlignment.Left
    lootLabel.BackgroundTransparency = 1

    local cashLabel = Instance.new("TextLabel")
    cashLabel.Parent = card
    cashLabel.Size = UDim2.new(1, -20, 0, 20)
    cashLabel.Position = UDim2.new(0, 10, 0, 30)
    cashLabel.Text = Locale.Format("BalanceLabel", 0)
    cashLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    cashLabel.TextSize = 14
    cashLabel.Font = Enum.Font.GothamBold
    cashLabel.TextXAlignment = Enum.TextXAlignment.Left
    cashLabel.BackgroundTransparency = 1

    local leaderstats = player:WaitForChild("leaderstats", 10)
    local cashValue = leaderstats and leaderstats:WaitForChild("Cash", 5) :: IntValue?
    if cashValue then
        cashLabel.Text = Locale.Format("BalanceLabel", cashValue.Value)
        cashValue:GetPropertyChangedSignal("Value"):Connect(function()
            cashLabel.Text = Locale.Format("BalanceLabel", cashValue.Value)
        end)
    end

    local extractionLabel = Instance.new("TextLabel")
    extractionLabel.Parent = card
    extractionLabel.Size = UDim2.new(1, -20, 0, 20)
    extractionLabel.Position = UDim2.new(0, 10, 0, 78)
    extractionLabel.Text = Locale.Get("ExtractionInactive")
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
    summaryClose.Size = UDim2.new(0.48, -10, 0, 36)
    summaryClose.Position = UDim2.new(0, 15, 1, -48)
    summaryClose.Text = Locale.Get("SummaryContinue")
    summaryClose.BackgroundColor3 = Color3.fromRGB(35, 115, 95)
    summaryClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    summaryClose.Font = Enum.Font.GothamBold
    summaryClose.ZIndex = 71
    Instance.new("UICorner", summaryClose).CornerRadius = UDim.new(0, 6)
    summaryClose.MouseButton1Click:Connect(function()
        summaryModal.Visible = false
    end)

    local replayButton = Instance.new("TextButton")
    replayButton.Parent = summaryModal
    replayButton.Size = UDim2.new(0.48, -10, 0, 36)
    replayButton.Position = UDim2.new(0.52, 5, 1, -48)
    replayButton.Text = Locale.Get("ViewReplayButton")
    replayButton.BackgroundColor3 = Color3.fromRGB(45, 95, 145)
    replayButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    replayButton.Font = Enum.Font.GothamBold
    replayButton.TextSize = 12
    replayButton.ZIndex = 71
    Instance.new("UICorner", replayButton).CornerRadius = UDim.new(0, 6)

    -- Окно тактического реплея
    local replayModal = Instance.new("Frame")
    replayModal.Parent = hud
    replayModal.Size = UDim2.new(0, 340, 0, 380)
    replayModal.AnchorPoint = Vector2.new(0.5, 0.5)
    replayModal.Position = UDim2.new(0.5, 0, 0.5, 0)
    replayModal.BackgroundColor3 = Color3.fromRGB(15, 20, 26)
    replayModal.Visible = false
    replayModal.ZIndex = 80
    Instance.new("UICorner", replayModal).CornerRadius = UDim.new(0, 12)

    local repTitle = Instance.new("TextLabel")
    repTitle.Parent = replayModal
    repTitle.Size = UDim2.new(1, -50, 0, 36)
    repTitle.Position = UDim2.new(0, 15, 0, 8)
    repTitle.Text = Locale.Get("ReplayTitle")
    repTitle.TextColor3 = Color3.fromRGB(0, 255, 180)
    repTitle.Font = Enum.Font.GothamBold
    repTitle.TextSize = 14
    repTitle.TextXAlignment = Enum.TextXAlignment.Left
    repTitle.BackgroundTransparency = 1
    repTitle.ZIndex = 81

    local isPlayingReplay = false

    local repClose = Instance.new("TextButton")
    repClose.Parent = replayModal
    repClose.Size = UDim2.new(0, 30, 0, 30)
    repClose.Position = UDim2.new(1, -38, 0, 10)
    repClose.Text = "X"
    repClose.TextColor3 = Color3.new(1, 1, 1)
    repClose.BackgroundColor3 = Color3.fromRGB(130, 40, 40)
    repClose.Font = Enum.Font.GothamBold
    repClose.ZIndex = 82
    Instance.new("UICorner", repClose).CornerRadius = UDim.new(0, 6)
    repClose.MouseButton1Click:Connect(function()
        replayModal.Visible = false
        isPlayingReplay = false
    end)

    local mapCanvas = Instance.new("Frame")
    mapCanvas.Parent = replayModal
    mapCanvas.Size = UDim2.new(0, 300, 0, 300)
    mapCanvas.Position = UDim2.new(0.5, -150, 0, 48)
    mapCanvas.BackgroundColor3 = Color3.fromRGB(24, 30, 38)
    mapCanvas.ZIndex = 81
    Instance.new("UICorner", mapCanvas).CornerRadius = UDim.new(0, 8)

    local playerDot = Instance.new("Frame")
    playerDot.Size = UDim2.new(0, 10, 0, 10)
    playerDot.AnchorPoint = Vector2.new(0.5, 0.5)
    playerDot.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
    playerDot.ZIndex = 83
    Instance.new("UICorner", playerDot).CornerRadius = UDim.new(1, 0)
    playerDot.Parent = mapCanvas

    local guardDot = Instance.new("Frame")
    guardDot.Size = UDim2.new(0, 12, 0, 12)
    guardDot.AnchorPoint = Vector2.new(0.5, 0.5)
    guardDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    guardDot.ZIndex = 83
    Instance.new("UICorner", guardDot).CornerRadius = UDim.new(1, 0)
    guardDot.Parent = mapCanvas

    local repLegend = Instance.new("TextLabel")
    repLegend.Parent = replayModal
    repLegend.Size = UDim2.new(1, -20, 0, 20)
    repLegend.Position = UDim2.new(0, 10, 1, -24)
    repLegend.Text = Locale.Get("ReplayLegend")
    repLegend.TextColor3 = Color3.fromRGB(160, 175, 190)
    repLegend.Font = Enum.Font.Gotham
    repLegend.TextSize = 11
    repLegend.BackgroundTransparency = 1
    repLegend.ZIndex = 81

    replayButton.MouseButton1Click:Connect(function()
        local success, frames = pcall(function()
            return getRaidReplayFunction:InvokeServer()
        end)
        if not success or type(frames) ~= "table" or #frames == 0 then return end

        replayModal.Visible = true
        isPlayingReplay = true

        task.spawn(function()
            for _, f in ipairs(frames) do
                if not replayModal.Visible or not isPlayingReplay then break end
                -- Преобразование мировых координат (-80..+80) в координаты канваса (0..300)
                local px = math.clamp((f.PX + 80) / 160 * 300, 0, 300)
                local pz = math.clamp((f.PZ + 80) / 160 * 300, 0, 300)
                playerDot.Position = UDim2.new(0, px, 0, pz)
                playerDot.BackgroundColor3 = f.Downed and Color3.fromRGB(255, 180, 50) or Color3.fromRGB(0, 255, 150)

                local gx = math.clamp((f.GX + 80) / 160 * 300, 0, 300)
                local gz = math.clamp((f.GZ + 80) / 160 * 300, 0, 300)
                guardDot.Position = UDim2.new(0, gx, 0, gz)

                task.wait(0.1)
            end
            isPlayingReplay = false
        end)
    end)

    local weightLabel = Instance.new("TextLabel")
    weightLabel.Parent = card
    weightLabel.Size = UDim2.new(1, -20, 0, 20)
    weightLabel.Position = UDim2.new(0, 10, 0, 54)
    local effMaxW = LootLogic.GetEffectiveMaxWeight(currentLoadout.MaxWeight, currentUpgrades.Pockets)
    weightLabel.Text = Locale.Format("WeightLabel", 0.0, effMaxW)
    weightLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    weightLabel.TextSize = 13
    weightLabel.Font = Enum.Font.GothamMedium
    weightLabel.TextXAlignment = Enum.TextXAlignment.Left
    weightLabel.BackgroundTransparency = 1

    local controlsHint = Instance.new("TextLabel")
    controlsHint.Parent = card
    controlsHint.Size = UDim2.new(1, -20, 0, 20)
    controlsHint.Position = UDim2.new(0, 10, 0, 100)
    controlsHint.Text = Locale.Get("ControlsHint")
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
    title.Text = Locale.Get("BackpackTitle")
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

            local itemName = item.NameKey and Locale.Get(item.NameKey) or item.Name
            local fragileTag = item.Fragile and (" " .. Locale.Get("FragileTag")) or ""

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Parent = row
            nameLabel.Size = UDim2.new(0.65, 0, 1, 0)
            nameLabel.Position = UDim2.new(0, 10, 0, 0)
            nameLabel.Text = string.format("%s ($%d, %.1f kg%s)", itemName, item.Value, item.Weight, fragileTag)
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
            dropBtn.Text = Locale.Get("DropButton")
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

    local function handleInventoryAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject)
        if inputState == Enum.UserInputState.Begin then
            invModal.Visible = not invModal.Visible
            if invModal.Visible then RefreshInventoryList() end
            return Enum.ContextActionResult.Sink
        end
        return Enum.ContextActionResult.Pass
    end

    ContextActionService:BindAction("ToggleInventory", handleInventoryAction, true, Enum.KeyCode.B, Enum.KeyCode.DPadLeft)
    ContextActionService:SetTitle("ToggleInventory", "🎒")
    ContextActionService:SetPosition("ToggleInventory", UDim2.new(1, -225, 1, -165))

    -- Комплекты
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
    loadoutTitle.Text = Locale.Get("LoadoutsTitle")
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

            local lName = loadout.NameKey and Locale.Get(loadout.NameKey) or loadout.Name
            local lDesc = loadout.DescKey and Locale.Get(loadout.DescKey) or loadout.Description

            local info = Instance.new("TextLabel")
            info.Parent = row
            info.Size = UDim2.new(1, -150, 1, -8)
            info.Position = UDim2.new(0, 12, 0, 4)
            info.BackgroundTransparency = 1
            info.Text = string.format("%s\n%s", lName, lDesc)
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
                action.Text = Locale.Get("Equipped")
                action.BackgroundColor3 = Color3.fromRGB(45, 105, 85)
                action.TextColor3 = Color3.fromRGB(255, 255, 255)
                action.Active = false
                action.AutoButtonColor = false
            elseif isOwned then
                action.Text = Locale.Get("Select")
                action.BackgroundColor3 = Color3.fromRGB(45, 105, 155)
                action.TextColor3 = Color3.fromRGB(255, 255, 255)
                action.MouseButton1Click:Connect(function()
                    selectLoadoutEvent:FireServer(loadout.Id)
                end)
            else
                action.Text = TEST_MODE and Locale.Get("GetFree") or Locale.Format("BuyCost", loadout.Cost)
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
    loadoutsButton.Size = UDim2.new(0, 108, 0, 24)
    loadoutsButton.Position = UDim2.new(1, -118, 0, 144)
    loadoutsButton.Text = Locale.Get("LoadoutsButton")
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
    mTitle.Text = Locale.Get("MarketTitle")
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

            local upgName = uData.NameKey and Locale.Get(uData.NameKey) or uData.Name

            local infoLabel = Instance.new("TextLabel")
            infoLabel.Parent = row
            infoLabel.Size = UDim2.new(0.65, 0, 1, 0)
            infoLabel.Position = UDim2.new(0, 12, 0, 0)
            infoLabel.Text = Locale.Format("UpgradeLevelInfo", upgName, currentLvl, uData.MaxLevel, uData.BonusPerLevel)
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
                buyBtn.Text = Locale.Format("BuyUpgradeCost", nextCost)
                buyBtn.BackgroundColor3 = Color3.fromRGB(220, 140, 30)
                buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                buyBtn.MouseButton1Click:Connect(function()
                    buyUpgradeEvent:FireServer(uKey)
                end)
            else
                buyBtn.Text = Locale.Get("MaxLevel")
                buyBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
                buyBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
            end
        end
    end

    upgradesUpdatedEvent.OnClientEvent:Connect(function(newUpgrades, openUI)
        currentUpgrades = newUpgrades
        spotBeam.Range = LootLogic.GetEffectiveFlashlightRange(75, currentUpgrades.Battery)
        local effW = LootLogic.GetEffectiveMaxWeight(currentLoadout.MaxWeight, currentUpgrades.Pockets)
        weightLabel.Text = Locale.Format("WeightLabel", currentInventoryData.TotalWeight, effW)

        if openUI then marketModal.Visible = true end
        if marketModal.Visible then RefreshMarketUI() end
    end)

    -- =========================================================================
    -- ГАРДЕРОБ И МАГАЗИН МАСОК (Wardrobe Modal)
    -- =========================================================================
    local playerCosmeticsData: { Owned: { [string]: boolean }, EquippedMask: string?, EquippedGrapple: string? } = {
        Owned = { DefaultGrapple = true },
        EquippedMask = nil,
        EquippedGrapple = "DefaultGrapple"
    }

    local wardrobeModal = Instance.new("Frame")
    wardrobeModal.Name = "WardrobeModal"
    wardrobeModal.Parent = hud
    wardrobeModal.Size = UDim2.new(0, 540, 0, 360)
    wardrobeModal.AnchorPoint = Vector2.new(0.5, 0.5)
    wardrobeModal.Position = UDim2.new(0.5, 0, 0.5, 0)
    wardrobeModal.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    wardrobeModal.Visible = false
    wardrobeModal.ZIndex = 80
    Instance.new("UICorner", wardrobeModal).CornerRadius = UDim.new(0, 12)

    local wTitle = Instance.new("TextLabel")
    wTitle.Parent = wardrobeModal
    wTitle.Size = UDim2.new(1, -50, 0, 45)
    wTitle.Position = UDim2.new(0, 20, 0, 8)
    wTitle.Text = "🎭 ГАРДЕРОБ И МАГАЗИН МАСОК"
    wTitle.TextColor3 = Color3.fromRGB(255, 140, 220)
    wTitle.Font = Enum.Font.GothamBlack
    wTitle.TextSize = 18
    wTitle.TextXAlignment = Enum.TextXAlignment.Left
    wTitle.BackgroundTransparency = 1
    wTitle.ZIndex = 81

    local wClose = Instance.new("TextButton")
    wClose.Parent = wardrobeModal
    wClose.Size = UDim2.new(0, 32, 0, 32)
    wClose.Position = UDim2.new(1, -42, 0, 10)
    wClose.Text = "X"
    wClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    wClose.Font = Enum.Font.GothamBold
    wClose.TextSize = 14
    wClose.BackgroundColor3 = Color3.fromRGB(45, 50, 60)
    wClose.ZIndex = 81
    Instance.new("UICorner", wClose).CornerRadius = UDim.new(0, 8)
    wClose.MouseButton1Click:Connect(function()
        wardrobeModal.Visible = false
    end)

    local wList = Instance.new("ScrollingFrame")
    wList.Parent = wardrobeModal
    wList.Size = UDim2.new(1, -32, 1, -65)
    wList.Position = UDim2.new(0, 16, 0, 55)
    wList.BackgroundTransparency = 1
    wList.BorderSizePixel = 0
    wList.ScrollBarThickness = 5
    wList.ZIndex = 81
    local wLayout = Instance.new("UIListLayout")
    wLayout.Padding = UDim.new(0, 8)
    wLayout.Parent = wList

    local function RefreshWardrobeUI()
        for _, child in wList:GetChildren() do
            if child:IsA("Frame") then child:Destroy() end
        end

        local items = CosmeticsConfig.Items
        for _, item in ipairs(items) do
            local card = Instance.new("Frame")
            card.Parent = wList
            card.Size = UDim2.new(1, -8, 0, 65)
            card.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
            card.ZIndex = 82
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Parent = card
            nameLbl.Size = UDim2.new(1, -160, 0, 22)
            nameLbl.Position = UDim2.new(0, 12, 0, 8)
            nameLbl.Text = string.format("%s [%s]", item.Name, item.Category == "Mask" and "Маска" or "Скин крюка")
            nameLbl.TextColor3 = Color3.fromRGB(240, 240, 250)
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 14
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.BackgroundTransparency = 1
            nameLbl.ZIndex = 83

            local descLbl = Instance.new("TextLabel")
            descLbl.Parent = card
            descLbl.Size = UDim2.new(1, -160, 0, 26)
            descLbl.Position = UDim2.new(0, 12, 0, 32)
            descLbl.Text = item.Description
            descLbl.TextColor3 = Color3.fromRGB(160, 170, 185)
            descLbl.Font = Enum.Font.Gotham
            descLbl.TextSize = 11
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
            descLbl.TextWrapped = true
            descLbl.BackgroundTransparency = 1
            descLbl.ZIndex = 83

            local actionBtn = Instance.new("TextButton")
            actionBtn.Parent = card
            actionBtn.Size = UDim2.new(0, 130, 0, 36)
            actionBtn.Position = UDim2.new(1, -142, 0.5, -18)
            actionBtn.Font = Enum.Font.GothamBold
            actionBtn.TextSize = 13
            actionBtn.ZIndex = 83
            Instance.new("UICorner", actionBtn).CornerRadius = UDim.new(0, 6)

            local isOwned = playerCosmeticsData.Owned[item.Id] == true
            local isEquipped = (item.Category == "Mask" and playerCosmeticsData.EquippedMask == item.Id)
                or (item.Category == "Grapple" and playerCosmeticsData.EquippedGrapple == item.Id)

            if isEquipped then
                actionBtn.Text = "★ НАДЕТО"
                actionBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 90)
                actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                actionBtn.MouseButton1Click:Connect(function()
                    equipCosmeticEvent:FireServer(item.Id)
                end)
            elseif isOwned then
                actionBtn.Text = "НАДЕТЬ"
                actionBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 220)
                actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                actionBtn.MouseButton1Click:Connect(function()
                    equipCosmeticEvent:FireServer(item.Id)
                end)
            else
                actionBtn.Text = string.format("КУПИТЬ ($%d)", item.Cost)
                actionBtn.BackgroundColor3 = Color3.fromRGB(220, 150, 30)
                actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                actionBtn.MouseButton1Click:Connect(function()
                    buyCosmeticEvent:FireServer(item.Id)
                end)
            end
        end

        wList.CanvasSize = UDim2.new(0, 0, 0, #items * 74)
    end

    cosmeticsUpdatedEvent.OnClientEvent:Connect(function(newCosmetics)
        if type(newCosmetics) == "table" then
            playerCosmeticsData = newCosmetics
            if wardrobeModal.Visible then
                RefreshWardrobeUI()
            end
        end
    end)

    local commandModal
    local RefreshCommandRoom

    openHideoutStationEvent.OnClientEvent:Connect(function(stationName)
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
        elseif stationName == "Wardrobe" then
            marketModal.Visible = false
            loadoutModal.Visible = false
            commandModal.Visible = false
            wardrobeModal.Visible = true
            RefreshWardrobeUI()
        end
    end)

    -- Command room
    commandModal = Instance.new("Frame")
    commandModal.Name = "CommandRoomModal"
    commandModal.Parent = hud
    commandModal.Size = UDim2.new(0, 520, 0, 390)
    commandModal.AnchorPoint = Vector2.new(0.5, 0.5)
    commandModal.Position = UDim2.new(0.5, 0, 0.5, 0)
    commandModal.BackgroundColor3 = Color3.fromRGB(15, 23, 29)
    commandModal.Visible = false
    commandModal.ZIndex = 70
    Instance.new("UICorner", commandModal).CornerRadius = UDim.new(0, 10)

    local commandTitle = Instance.new("TextLabel")
    commandTitle.Parent = commandModal
    commandTitle.Size = UDim2.new(1, -170, 0, 36)
    commandTitle.Position = UDim2.new(0, 16, 0, 8)
    commandTitle.BackgroundTransparency = 1
    commandTitle.Text = Locale.Get("CommandTitle")
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
    commandRefresh.Size = UDim2.new(0, 100, 0, 30)
    commandRefresh.Position = UDim2.new(1, -154, 0, 10)
    commandRefresh.Text = Locale.Get("CommandRefresh")
    commandRefresh.TextColor3 = Color3.new(1, 1, 1)
    commandRefresh.BackgroundColor3 = Color3.fromRGB(45, 90, 115)
    commandRefresh.Font = Enum.Font.GothamBold
    commandRefresh.TextSize = 12
    commandRefresh.ZIndex = 72

    -- Вкладки управления (Контракты / Лидерборд / Отряд)
    local activeCommandTab = "Contracts"
    local tabContainer = Instance.new("Frame")
    tabContainer.Parent = commandModal
    tabContainer.Size = UDim2.new(1, -32, 0, 32)
    tabContainer.Position = UDim2.new(0, 16, 0, 46)
    tabContainer.BackgroundTransparency = 1
    tabContainer.ZIndex = 71

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 8)
    tabLayout.Parent = tabContainer

    local tabBtns: { [string]: TextButton } = {}

    local function createTabBtn(id: string, label: string)
        local btn = Instance.new("TextButton")
        btn.Name = "Tab_" .. id
        btn.Parent = tabContainer
        btn.Size = UDim2.new(0.31, 0, 1, 0)
        btn.Text = label
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.ZIndex = 72
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        tabBtns[id] = btn
        return btn
    end

    local tabContractsBtn = createTabBtn("Contracts", "📋 " .. Locale.Get("TabContracts"))
    local tabLeaderboardBtn = createTabBtn("Leaderboard", "🏆 " .. Locale.Get("TabLeaderboard"))
    local tabSquadBtn = createTabBtn("Squad", "📡 " .. Locale.Get("TabSpectate"))

    local commandStatus = Instance.new("TextLabel")
    commandStatus.Parent = commandModal
    commandStatus.Size = UDim2.new(1, -32, 0, 20)
    commandStatus.Position = UDim2.new(0, 16, 0, 82)
    commandStatus.BackgroundTransparency = 1
    commandStatus.Text = ""
    commandStatus.TextColor3 = Color3.fromRGB(180, 195, 205)
    commandStatus.Font = Enum.Font.Gotham
    commandStatus.TextSize = 11
    commandStatus.TextXAlignment = Enum.TextXAlignment.Left
    commandStatus.ZIndex = 71

    local commandList = Instance.new("ScrollingFrame")
    commandList.Parent = commandModal
    commandList.Size = UDim2.new(1, -32, 1, -112)
    commandList.Position = UDim2.new(0, 16, 0, 104)
    commandList.BackgroundTransparency = 1
    commandList.BorderSizePixel = 0
    commandList.ScrollBarThickness = 5
    commandList.ZIndex = 71
    local commandLayout = Instance.new("UIListLayout")
    commandLayout.Padding = UDim.new(0, 6)
    commandLayout.Parent = commandList

    local function updateTabStyles()
        for id, btn in tabBtns do
            if id == activeCommandTab then
                btn.BackgroundColor3 = Color3.fromRGB(40, 120, 95)
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                btn.BackgroundColor3 = Color3.fromRGB(24, 32, 40)
                btn.TextColor3 = Color3.fromRGB(160, 175, 185)
            end
        end
    end

    RefreshCommandRoom = function()
        for _, child in commandList:GetChildren() do
            if child:IsA("Frame") then child:Destroy() end
        end
        updateTabStyles()

        if activeCommandTab == "Contracts" then
            commandStatus.Text = Locale.Get("ContractsModalTitle")
            local success, data = pcall(function()
                return getDailyContractsFunction:InvokeServer()
            end)
            if not success or type(data) ~= "table" or type(data.Contracts) ~= "table" then
                commandStatus.Text = Locale.Get("CommandFailed")
                return
            end

            local contracts = data.Contracts
            local completedMap = data.Completed or {}
            local progressMap = data.Progress or {}

            for index, contract in ipairs(contracts) do
                local card = Instance.new("Frame")
                card.Parent = commandList
                card.Size = UDim2.new(1, -8, 0, 64)
                card.BackgroundColor3 = Color3.fromRGB(25, 34, 42)
                card.LayoutOrder = index
                card.ZIndex = 72
                Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

                local isDone = completedMap[contract.Id] == true

                local titleLabel = Instance.new("TextLabel")
                titleLabel.Parent = card
                titleLabel.Size = UDim2.new(1, -130, 0, 24)
                titleLabel.Position = UDim2.new(0, 12, 0, 8)
                titleLabel.BackgroundTransparency = 1
                titleLabel.Text = contract.Title
                titleLabel.TextColor3 = isDone and Color3.fromRGB(140, 230, 170) or Color3.fromRGB(240, 245, 250)
                titleLabel.Font = Enum.Font.GothamBold
                titleLabel.TextSize = 13
                titleLabel.TextXAlignment = Enum.TextXAlignment.Left
                titleLabel.ZIndex = 73

                local rewardLabel = Instance.new("TextLabel")
                rewardLabel.Parent = card
                rewardLabel.Size = UDim2.new(0.5, 0, 0, 20)
                rewardLabel.Position = UDim2.new(0, 12, 0, 34)
                rewardLabel.BackgroundTransparency = 1
                rewardLabel.Text = Locale.Format("ContractReward", contract.RewardCash)
                rewardLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
                rewardLabel.Font = Enum.Font.GothamMedium
                rewardLabel.TextSize = 12
                rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
                rewardLabel.ZIndex = 73

                local statusBadge = Instance.new("TextLabel")
                statusBadge.Parent = card
                statusBadge.Size = UDim2.new(0, 110, 0, 28)
                statusBadge.Position = UDim2.new(1, -120, 0.5, -14)
                statusBadge.Font = Enum.Font.GothamBold
                statusBadge.TextSize = 11
                statusBadge.ZIndex = 73
                Instance.new("UICorner", statusBadge).CornerRadius = UDim.new(0, 4)

                if isDone then
                    statusBadge.Text = "✔ " .. Locale.Get("ContractCompleted")
                    statusBadge.BackgroundColor3 = Color3.fromRGB(30, 110, 65)
                    statusBadge.TextColor3 = Color3.fromRGB(210, 255, 220)
                else
                    local curProg = progressMap[contract.Id] or 0
                    statusBadge.Text = string.format("%d / %d", math.min(curProg, contract.TargetAmount), contract.TargetAmount)
                    statusBadge.BackgroundColor3 = Color3.fromRGB(45, 55, 68)
                    statusBadge.TextColor3 = Color3.fromRGB(210, 220, 230)
                end
            end
            commandList.CanvasSize = UDim2.new(0, 0, 0, #contracts * 70)

        elseif activeCommandTab == "Leaderboard" then
            commandStatus.Text = Locale.Get("LeaderboardTitle")
            local success, topPlayers = pcall(function()
                return getLeaderboardFunction:InvokeServer()
            end)
            if not success or type(topPlayers) ~= "table" then
                commandStatus.Text = Locale.Get("CommandFailed")
                return
            end

            if #topPlayers == 0 then
                local emptyLabel = Instance.new("TextLabel")
                emptyLabel.Parent = commandList
                emptyLabel.Size = UDim2.new(1, -8, 0, 48)
                emptyLabel.BackgroundTransparency = 1
                emptyLabel.Text = Locale.Get("LeaderboardEmpty")
                emptyLabel.TextColor3 = Color3.fromRGB(160, 175, 185)
                emptyLabel.Font = Enum.Font.Gotham
                emptyLabel.TextSize = 13
                emptyLabel.ZIndex = 72
                commandList.CanvasSize = UDim2.new(0, 0, 0, 60)
            else
                for index, entry in ipairs(topPlayers) do
                    local row = Instance.new("Frame")
                    row.Parent = commandList
                    row.Size = UDim2.new(1, -8, 0, 44)
                    row.BackgroundColor3 = index == 1 and Color3.fromRGB(35, 45, 50) or Color3.fromRGB(25, 34, 42)
                    row.LayoutOrder = index
                    row.ZIndex = 72
                    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

                    local rankColor = Color3.fromRGB(210, 220, 230)
                    if index == 1 then
                        rankColor = Color3.fromRGB(255, 215, 60)
                    elseif index == 2 then
                        rankColor = Color3.fromRGB(200, 215, 225)
                    elseif index == 3 then
                        rankColor = Color3.fromRGB(205, 140, 90)
                    end

                    local rankLabel = Instance.new("TextLabel")
                    rankLabel.Parent = row
                    rankLabel.Size = UDim2.new(0, 44, 1, 0)
                    rankLabel.Position = UDim2.new(0, 10, 0, 0)
                    rankLabel.BackgroundTransparency = 1
                    rankLabel.Text = "#" .. tostring(index)
                    rankLabel.TextColor3 = rankColor
                    rankLabel.Font = Enum.Font.GothamBlack
                    rankLabel.TextSize = 14
                    rankLabel.TextXAlignment = Enum.TextXAlignment.Left
                    rankLabel.ZIndex = 73

                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Parent = row
                    nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
                    nameLabel.Position = UDim2.new(0, 56, 0, 0)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.Text = entry.UserName or ("Player_" .. tostring(entry.UserId))
                    nameLabel.TextColor3 = Color3.fromRGB(240, 245, 250)
                    nameLabel.Font = Enum.Font.GothamMedium
                    nameLabel.TextSize = 13
                    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                    nameLabel.ZIndex = 73

                    local cashLabel = Instance.new("TextLabel")
                    cashLabel.Parent = row
                    cashLabel.Size = UDim2.new(0, 120, 1, 0)
                    cashLabel.Position = UDim2.new(1, -130, 0, 0)
                    cashLabel.BackgroundTransparency = 1
                    cashLabel.Text = "$" .. tostring(entry.Value)
                    cashLabel.TextColor3 = Color3.fromRGB(100, 225, 160)
                    cashLabel.Font = Enum.Font.GothamBold
                    cashLabel.TextSize = 13
                    cashLabel.TextXAlignment = Enum.TextXAlignment.Right
                    cashLabel.ZIndex = 73
                end
                commandList.CanvasSize = UDim2.new(0, 0, 0, #topPlayers * 50)
            end

        elseif activeCommandTab == "Squad" then
            local success, roster = pcall(function()
                return getRaidStatusFunction:InvokeServer()
            end)
            if not success or type(roster) ~= "table" then
                commandStatus.Text = Locale.Get("CommandFailed")
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
                    watchButton.Text = Locale.Get("CommandSpectate")
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
                            commandStatus.Text = Locale.Format("SpectatingTarget", entry.DisplayName)
                        else
                            commandStatus.Text = Locale.Get("SpectateUnavailable")
                        end
                    end)
                end
            end

            commandStatus.Text = Locale.Format("CommandActiveCount", activeCount)
            commandList.CanvasSize = UDim2.new(0, 0, 0, #roster * 54)
        end
    end

    tabContractsBtn.MouseButton1Click:Connect(function()
        activeCommandTab = "Contracts"
        RefreshCommandRoom()
    end)

    tabLeaderboardBtn.MouseButton1Click:Connect(function()
        activeCommandTab = "Leaderboard"
        RefreshCommandRoom()
    end)

    tabSquadBtn.MouseButton1Click:Connect(function()
        activeCommandTab = "Squad"
        RefreshCommandRoom()
    end)

    commandRefresh.MouseButton1Click:Connect(RefreshCommandRoom)

    contractsUpdatedEvent.OnClientEvent:Connect(function()
        if commandModal.Visible and activeCommandTab == "Contracts" then
            RefreshCommandRoom()
        end
    end)

    loadoutAppliedEvent.OnClientEvent:Connect(function(appliedLoadout, appliedUpgrades)
        currentLoadout = appliedLoadout
        if appliedUpgrades then currentUpgrades = appliedUpgrades end
        spotBeam.Range = LootLogic.GetEffectiveFlashlightRange(75, currentUpgrades.Battery)
        local effW = LootLogic.GetEffectiveMaxWeight(currentLoadout.MaxWeight, currentUpgrades.Pockets)
        weightLabel.Text = Locale.Format("WeightLabel", currentInventoryData.TotalWeight, effW)
        if loadoutModal.Visible then RefreshLoadoutsUI() end
    end)

    inventoryUpdatedEvent.OnClientEvent:Connect(function(invData, message)
        if invData and invData.TotalValue ~= nil then
            currentInventoryData = invData
            lootLabel.Text = Locale.Format("LootLabel", invData.TotalValue)
            local effW = LootLogic.GetEffectiveMaxWeight(currentLoadout.MaxWeight, currentUpgrades.Pockets)
            weightLabel.Text = Locale.Format("WeightLabel", invData.TotalWeight, effW)
            if invModal.Visible then RefreshInventoryList() end
        end
        if message then
            PlayLocalSFX("Pickup")
        end
    end)

    extractionProgressEvent.OnClientEvent:Connect(function(remaining, completed)
        if completed then
            extractionLabel.Text = Locale.Get("ExtractionSuccess")
        elseif remaining < 0 then
            extractionLabel.Text = Locale.Get("ExtractionAborted")
        else
            extractionLabel.Text = Locale.Format("ExtractionProgress", remaining)
        end
    end)

    raidSummaryEvent.OnClientEvent:Connect(function(escaped, lootValue, itemCount, totalCash)
        summaryTitle.Text = escaped and Locale.Get("SummarySuccessTitle") or Locale.Get("SummaryFailedTitle")
        summaryTitle.TextColor3 = escaped and Color3.fromRGB(0, 255, 180) or Color3.fromRGB(255, 130, 100)
        summaryDetails.Text = escaped
            and Locale.Format("SummarySuccessDetails", itemCount, lootValue, totalCash)
            or Locale.Format("SummaryFailedDetails", totalCash)
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
    phaseLabel.Text = "..."
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
    startRaidButton.Text = Locale.Get("StartRaidButton")
    startRaidButton.Font = Enum.Font.GothamBold
    startRaidButton.TextSize = 15
    startRaidButton.Visible = currentPhaseValue.Value == "LobbyPhase"
    Instance.new("UICorner", startRaidButton).CornerRadius = UDim.new(0, 8)

    startRaidButton.MouseButton1Click:Connect(function()
        if currentPhaseValue.Value ~= "LobbyPhase" then return end
        startRaidButton.Active = false
        startRaidButton.Text = Locale.Get("StartRaidRequest")
        startRaidEvent:FireServer()
        task.delay(1.5, function()
            if currentPhaseValue.Value == "LobbyPhase" then
                startRaidButton.Active = true
                startRaidButton.Text = Locale.Get("StartRaidButton")
            end
        end)
    end)

    local timerGeneration = 0

    stateChangedEvent.OnClientEvent:Connect(function(phase, dur)
        startRaidButton.Visible = phase == "LobbyPhase"
        startRaidButton.Active = phase == "LobbyPhase"
        startRaidButton.Text = Locale.Get("StartRaidButton")
        if phase == "LobbyPhase" then
            phaseLabel.Text = Locale.Get("LobbyPhaseWaiting")
            phaseLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        end
        timerGeneration += 1
        local currentGeneration = timerGeneration
        local finish = os.clock() + dur
        task.spawn(function()
            while currentGeneration == timerGeneration and os.clock() < finish do
                local left = math.ceil(finish - os.clock())
                if phase == "LobbyPhase" then
                    phaseLabel.Text = Locale.Format("LobbyPhaseTimer", left)
                    phaseLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
                elseif phase == "LootPhase" then
                    phaseLabel.Text = Locale.Format("LootPhaseTimer", left)
                    phaseLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
                elseif phase == "ExtractionPhase" then
                    phaseLabel.Text = Locale.Format("ExtractionPhaseTimer", left)
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

    local TweenService = game:GetService("TweenService")

    local banner = Instance.new("Frame")
    banner.Name = "Banner"
    banner.Size = UDim2.new(0, 390, 0, 82)
    banner.Position = UDim2.new(0.5, -195, 0, -100)
    banner.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
    banner.BackgroundTransparency = 0.08
    banner.Visible = false
    banner.Parent = gui
    Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 7)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(255, 200, 80)
    title.Text = ""
    title.Parent = banner

    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(1, -24, 0, 36)
    description.Position = UDim2.new(0, 12, 0, 39)
    description.BackgroundTransparency = 1
    description.Font = Enum.Font.GothamMedium
    description.TextSize = 12
    description.TextWrapped = true
    description.TextColor3 = Color3.fromRGB(235, 235, 235)
    description.Text = ""
    description.Parent = banner

    local generation = 0
    local visiblePosition = UDim2.new(0.5, -195, 0, 20)
    local hiddenPosition = UDim2.new(0.5, -195, 0, -100)

    local function showEvent(eventName: string, eventDesc: string)
        if type(eventName) ~= "string" or eventName == "" then return end
        generation += 1
        local currentGeneration = generation
        title.Text = eventName
        description.Text = type(eventDesc) == "string" and eventDesc or ""
        banner.Visible = true
        banner.Position = hiddenPosition
        banner.BackgroundTransparency = 0.08

        TweenService:Create(
            banner,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Position = visiblePosition }
        ):Play()

        task.delay(5, function()
            if currentGeneration ~= generation then return end
            local hideTween = TweenService:Create(
                banner,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Position = hiddenPosition, BackgroundTransparency = 1 }
            )
            hideTween:Play()
            hideTween.Completed:Wait()
            if currentGeneration == generation then
                banner.Visible = false
            end
        end)
    end

    nightEventEvent.OnClientEvent:Connect(function(eventId, eventName, eventDescription)
        local translatedName = Locale.Get("Event_" .. tostring(eventId) .. "_Name")
        local translatedDesc = Locale.Get("Event_" .. tostring(eventId) .. "_Desc")
        showEvent(translatedName ~= ("Event_" .. tostring(eventId) .. "_Name") and translatedName or eventName,
                  translatedDesc ~= ("Event_" .. tostring(eventId) .. "_Desc") and translatedDesc or eventDescription)
    end)

    if currentNightEventValue.Value ~= "" then
        showEvent(currentNightEventValue.Value, "")
    end
end

task.spawn(CreateNightEventUI)
