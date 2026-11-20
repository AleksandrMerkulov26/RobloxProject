--!strict
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))
local NightEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NightEvents"))

local GuardAI = {}

local existingSmokes = workspace:FindFirstChild("Smokes")
local smokesContainer: Folder
if existingSmokes and existingSmokes:IsA("Folder") then
    smokesContainer = existingSmokes
else
    local folder = Instance.new("Folder")
    folder.Name = "Smokes"
    folder.Parent = workspace
    smokesContainer = folder
end

local existingSecurity = workspace:FindFirstChild("SecurityEntities")
local securityContainer: Folder
if existingSecurity and existingSecurity:IsA("Folder") then
    securityContainer = existingSecurity
else
    local folder = Instance.new("Folder")
    folder.Name = "SecurityEntities"
    folder.Parent = workspace
    securityContainer = folder
end

local guardStunnedUntil = 0
local guardAlertUntil = 0
local currentSuspiciousNoise: { Position: Vector3, Radius: number, Timestamp: number }? = nil
local activeGuardModel: Model? = nil

local isPlayerEliminatedFn: ((player: Player) -> boolean)?
local getActiveNightEventFn: (() -> any)?

function GuardAI.SetDependencies(deps: {
    IsPlayerEliminated: (player: Player) -> boolean,
    GetActiveNightEvent: () -> any,
})
    isPlayerEliminatedFn = deps.IsPlayerEliminated
    getActiveNightEventFn = deps.GetActiveNightEvent
end

function GuardAI.RegisterNoise(position: Vector3, radius: number)
    currentSuspiciousNoise = {
        Position = position,
        Radius = radius,
        Timestamp = os.clock(),
    }
end

function GuardAI.Stun(duration: number)
    guardStunnedUntil = os.clock() + duration
    currentSuspiciousNoise = nil
end

function GuardAI.GetGuardModel(): Model?
    return activeGuardModel
end

function GuardAI.ClearAllEntities()
    if securityContainer then
        securityContainer:ClearAllChildren()
    end
    local oldGuard = workspace:FindFirstChild("GuardNPC")
    if oldGuard then oldGuard:Destroy() end

    activeGuardModel = nil
    guardAlertUntil = 0
    guardStunnedUntil = 0
    currentSuspiciousNoise = nil
end

-- ========================================================
-- 1. СТАЦИОНАРНАЯ ПОВОРОТНАЯ КАМЕРА НАБЛЮДЕНИЯ
-- ========================================================
function GuardAI.SpawnCamera(mountPos: Vector3, baseDirection: Vector3)
    if not securityContainer then return end

    local camModel = Instance.new("Model")
    camModel.Name = "SecurityCamera"

    local basePart = Instance.new("Part")
    basePart.Name = "CameraBase"
    basePart.Size = Vector3.new(1.5, 1.5, 1.5)
    basePart.Position = mountPos
    basePart.Anchored = true
    basePart.Color = Color3.fromRGB(45, 48, 55)
    basePart.Material = Enum.Material.Metal
    basePart.Parent = camModel

    local headPart = Instance.new("Part")
    headPart.Name = "CameraHead"
    headPart.Size = Vector3.new(1.2, 0.8, 2)
    headPart.Position = mountPos - Vector3.new(0, 0.8, 0)
    headPart.Anchored = true
    headPart.Color = Color3.fromRGB(30, 32, 38)
    headPart.Material = Enum.Material.Metal
    headPart.Parent = camModel
    camModel.PrimaryPart = headPart

    local spotLight = Instance.new("SpotLight")
    spotLight.Name = "CamLight"
    spotLight.Range = 40
    spotLight.Angle = 60
    spotLight.Brightness = 6.0
    spotLight.Color = Color3.fromRGB(120, 255, 120) -- Зеленый в покое
    spotLight.Face = Enum.NormalId.Front
    spotLight.Shadows = false
    spotLight.Parent = headPart

    camModel.Parent = securityContainer

    task.spawn(function()
        local baseCFrame = CFrame.lookAt(headPart.Position, headPart.Position + baseDirection)
        local angle = 0
        local swingSpeed = 0.8
        local alertTimer = 0

        while headPart and headPart.Parent do
            task.wait(0.1)

            -- Поворот камеры туда-обратно
            angle += swingSpeed * 0.1
            local currentYaw = math.sin(angle) * math.rad(40)
            headPart.CFrame = baseCFrame * CFrame.Angles(0, currentYaw, 0)

            -- Проверка игроков в конусе камеры
            local forward = headPart.CFrame.LookVector
            local detected = false

            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                local hum = char and char:FindFirstChildOfClass("Humanoid")

                if hrp and hum and hum.Health > 0 and not (isPlayerEliminatedFn and isPlayerEliminatedFn(player)) then
                    local offset = hrp.Position - headPart.Position
                    local dist = offset.Magnitude
                    local isCrouched = player:GetAttribute("IsCrouched") == true
                    local maxCamDist = if isCrouched then 26 else 38

                    if dist <= maxCamDist then
                        local dirToPlayer = offset.Unit
                        local dot = forward:Dot(dirToPlayer)

                        if dot > 0.65 then -- Внутри конуса ~50 градусов
                            local rayParams = RaycastParams.new()
                            rayParams.FilterDescendantsInstances = { camModel, char, smokesContainer }
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            local hit = workspace:Raycast(headPart.Position, offset, rayParams)
                            if not hit then
                                detected = true
                                break
                            end
                        end
                    end
                end
            end

            if detected then
                alertTimer = os.clock() + 4.0
                spotLight.Color = Color3.fromRGB(255, 30, 30) -- Красный свет тревоги
                GuardAI.RegisterNoise(headPart.Position, 90)
            else
                if os.clock() > alertTimer then
                    spotLight.Color = Color3.fromRGB(120, 255, 120)
                end
            end
        end
    end)
end

-- ========================================================
-- 2. СЛУЖЕБНАЯ ПАТРУЛЬНАЯ СОБАКА
-- ========================================================
function GuardAI.SpawnPatrolDog(spawnPos: Vector3): Model
    local model = Instance.new("Model")
    model.Name = "PatrolDog"

    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2, 2.2, 3)
    root.Color = Color3.fromRGB(80, 50, 30)
    root.Material = Enum.Material.Fabric
    root.CFrame = CFrame.new(spawnPos)
    root.CanCollide = true
    root.Parent = model
    model.PrimaryPart = root

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.2, 1.2, 1.4)
    head.Color = Color3.fromRGB(60, 40, 25)
    head.Material = Enum.Material.Fabric
    head.CFrame = root.CFrame * CFrame.new(0, 0.8, -1.8)
    head.CanCollide = false
    head.Parent = model

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = head
    weld.Parent = head

    local eyes = Instance.new("PointLight")
    eyes.Color = Color3.fromRGB(255, 200, 50)
    eyes.Range = 8
    eyes.Brightness = 2.0
    eyes.Parent = head

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 150
    humanoid.Health = 150
    humanoid.WalkSpeed = 20 -- Быстрая
    humanoid.Parent = model

    model.Parent = securityContainer or workspace

    task.spawn(function()
        local function DogNavigateTo(dest: Vector3)
            local offset = dest - root.Position
            if offset.Magnitude <= 6 then
                humanoid:MoveTo(dest)
                return
            end

            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = { model, securityContainer }
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local hit = workspace:Raycast(root.Position, offset, rayParams)

            if not hit or (hit.Position - dest).Magnitude <= 4 then
                humanoid:MoveTo(dest)
            else
                local path = PathfindingService:CreatePath({
                    AgentRadius = 1.5,
                    AgentHeight = 3.0,
                    AgentCanJump = false,
                })
                local success = pcall(function() path:ComputeAsync(root.Position, dest) end)
                if success and path.Status == Enum.PathStatus.Success then
                    local points = path:GetWaypoints()
                    if #points >= 2 then
                        humanoid:MoveTo(points[2].Position)
                    else
                        humanoid:MoveTo(dest)
                    end
                else
                    humanoid:MoveTo(dest)
                end
            end
        end

        local patrolTarget = spawnPos + Vector3.new(math.random(-25, 25), 0, math.random(-25, 25))

        while model.Parent and humanoid.Health > 0 do
            task.wait(0.2)

            if os.clock() < guardStunnedUntil then
                humanoid.WalkSpeed = 0
                continue
            end

            humanoid.WalkSpeed = 20

            -- Собака очень чувствительна к шуму (радиус 80 studs)
            local hearingTarget: Vector3? = nil
            if currentSuspiciousNoise and (os.clock() - currentSuspiciousNoise.Timestamp) < 6 then
                local distToNoise = (root.Position - currentSuspiciousNoise.Position).Magnitude
                if distToNoise <= (currentSuspiciousNoise.Radius * 1.5) then
                    hearingTarget = currentSuspiciousNoise.Position
                end
            end

            -- Близкое зрение (20 studs)
            local targetPlayerRoot: BasePart? = nil
            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 and not (isPlayerEliminatedFn and isPlayerEliminatedFn(player)) then
                    if (hrp.Position - root.Position).Magnitude <= 20 then
                        targetPlayerRoot = hrp
                        break
                    end
                end
            end

            if targetPlayerRoot then
                -- Погоня и укус
                humanoid.WalkSpeed = 23
                DogNavigateTo(targetPlayerRoot.Position)
                if (targetPlayerRoot.Position - root.Position).Magnitude <= 5 then
                    local targetHum = targetPlayerRoot.Parent and targetPlayerRoot.Parent:FindFirstChildOfClass("Humanoid")
                    if targetHum then
                        targetHum:TakeDamage(15)
                        GuardAI.RegisterNoise(root.Position, 70)
                        task.wait(0.6)
                    end
                end
            elseif hearingTarget then
                -- Бежит к шуму
                DogNavigateTo(hearingTarget)
                if (root.Position - hearingTarget).Magnitude <= 6 then
                    task.wait(1.0)
                end
            else
                -- Патруль
                DogNavigateTo(patrolTarget)
                if (root.Position - patrolTarget).Magnitude <= 6 then
                    patrolTarget = spawnPos + Vector3.new(math.random(-35, 35), 0, math.random(-35, 35))
                    task.wait(1.0)
                end
            end
        end
    end)

    return model
end

-- ========================================================
-- 3. ОСНОВНОЙ ОХРАННИК (GuardNPC)
-- ========================================================
function GuardAI.SpawnGuard(spawnPos: Vector3, customWaypoints: { Vector3 }?): Model
    local oldGuard = workspace:FindFirstChild("GuardNPC")
    if oldGuard then oldGuard:Destroy() end
    guardAlertUntil = 0

    local model = Instance.new("Model")
    model.Name = "GuardNPC"

    local root = Instance.new("Part")
    root.Name = "HumanoidRootPart"
    root.Size = Vector3.new(2.4, 5, 2.4)
    root.Color = Color3.fromRGB(25, 28, 35)
    root.Material = Enum.Material.Metal
    root.CFrame = CFrame.new(spawnPos)
    root.CanCollide = true
    root.CastShadow = false
    root.Parent = model
    model.PrimaryPart = root

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.4, 1.4, 1.4)
    head.Color = Color3.fromRGB(255, 60, 60)
    head.Material = Enum.Material.Neon
    head.CFrame = root.CFrame * CFrame.new(0, 2.5, -0.3)
    head.CanCollide = false
    head.CastShadow = false
    head.Parent = model

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = head
    weld.Parent = head

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 140, 0, 30)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 1, 0)
    statusLabel.Text = "[PATROL]"
    statusLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
    statusLabel.Font = Enum.Font.GothamBlack
    statusLabel.TextSize = 13
    statusLabel.BackgroundTransparency = 1
    statusLabel.Parent = bb

    local light = Instance.new("SpotLight")
    light.Range = 55
    light.Angle = 70
    light.Brightness = 8.5
    light.Color = Color3.fromRGB(255, 140, 40)
    light.Face = Enum.NormalId.Front
    light.Shadows = false
    light.Parent = head

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 300
    humanoid.Health = 300
    humanoid.WalkSpeed = 14
    humanoid.Parent = model

    model.Parent = workspace
    activeGuardModel = model

    local waypoints = customWaypoints or {
        Vector3.new(-45, 3, -45),
        Vector3.new(45, 3, -45),
        Vector3.new(50, 3, -15),
        Vector3.new(45, 3, 45),
        Vector3.new(-45, 3, 45),
        Vector3.new(0, 3, 0),
    }
    local currentWaypointIndex = 1
    local currentState = "Patrol"
    local investigateTarget: Vector3? = nil
    local lastKnownPlayerPosition: Vector3? = nil
    local searchStartedAt: number? = nil
    local searchMoveIssued = false
    local SEARCH_DURATION = 7

    local lastPathComputeTime = 0
    local cachedPathWaypoints: { PathWaypoint } = {}
    local currentPathWaypointIndex = 2
    local cachedPathTarget: Vector3? = nil

    local function NavigateTo(dest: Vector3)
        local offset = dest - root.Position
        if offset.Magnitude <= 6 then
            humanoid:MoveTo(dest)
            return
        end

        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = { model, securityContainer }
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local hit = workspace:Raycast(root.Position, offset, rayParams)

        if not hit or (hit.Position - dest).Magnitude <= 4 then
            humanoid:MoveTo(dest)
            cachedPathTarget = nil
            cachedPathWaypoints = {}
        else
            local now = os.clock()
            local targetMoved = not cachedPathTarget or (cachedPathTarget - dest).Magnitude > 6
            if targetMoved or (now - lastPathComputeTime) > 2.0 then
                lastPathComputeTime = now
                cachedPathTarget = dest
                currentPathWaypointIndex = 2
                local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = false })
                local success = pcall(function() path:ComputeAsync(root.Position, dest) end)
                if success and path.Status == Enum.PathStatus.Success then
                    cachedPathWaypoints = path:GetWaypoints()
                else
                    cachedPathWaypoints = {}
                end
            end

            if #cachedPathWaypoints >= currentPathWaypointIndex then
                local nextPoint = cachedPathWaypoints[currentPathWaypointIndex]
                humanoid:MoveTo(nextPoint.Position)
                if (root.Position - nextPoint.Position).Magnitude <= 4 then
                    currentPathWaypointIndex += 1
                end
            else
                humanoid:MoveTo(dest)
            end
        end
    end

    task.spawn(function()
        while model.Parent and humanoid.Health > 0 do
            task.wait(0.15)

            if os.clock() < guardStunnedUntil then
                statusLabel.Text = "[STUNNED]"
                statusLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
                light.Color = Color3.fromRGB(0, 180, 255)
                humanoid.WalkSpeed = 0
                continue
            end

            local inSmoke = false
            local smokePositions = {}
            if smokesContainer then
                for _, smoke in smokesContainer:GetChildren() do
                    if smoke:IsA("BasePart") then
                        table.insert(smokePositions, smoke.Position)
                        if (root.Position - smoke.Position).Magnitude <= 14 then
                            inSmoke = true
                        end
                    end
                end
            end

            if inSmoke then
                statusLabel.Text = "[BLINDED]"
                statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                light.Color = Color3.fromRGB(120, 120, 120)
                humanoid.WalkSpeed = 5
                task.wait(0.5)
                continue
            end

            local isAlerted = os.clock() < guardAlertUntil
            local activeNightEvent = getActiveNightEventFn and getActiveNightEventFn() or NightEvents.None
            local awareness = NightEvents.ApplyToAwareness(
                LootLogic.GetGuardAwareness(isAlerted),
                activeNightEvent
            )

            local targetChar: Model? = nil
            for _, player in Players:GetPlayers() do
                local char = player.Character
                local playerRoot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                local playerHumanoid = char and char:FindFirstChildOfClass("Humanoid")

                if playerRoot and playerHumanoid and playerHumanoid.Health > 0
                    and not (isPlayerEliminatedFn and isPlayerEliminatedFn(player)) then
                    local smokeBlocksVision = LootLogic.IsVisionBlockedBySmoke(
                        smokePositions, root.Position, playerRoot.Position, 14
                    )
                    local isCrouched = player:GetAttribute("IsCrouched") == true
                    local effViewDist = if isCrouched then awareness.ViewDistance * 0.6 else awareness.ViewDistance
                    local effProxDist = if isCrouched then 5 else 12

                    if not smokeBlocksVision
                        and LootLogic.IsPlayerDetected(
                            root.Position,
                            root.CFrame.LookVector,
                            playerRoot.Position,
                            effViewDist,
                            awareness.FovDotThreshold,
                            effProxDist
                        ) then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = { model, char, smokesContainer }
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        local hit = workspace:Raycast(root.Position, playerRoot.Position - root.Position, rayParams)
                        if not hit then
                            targetChar = char
                            lastKnownPlayerPosition = playerRoot.Position
                            break
                        end
                    end
                end
            end

            if targetChar then
                guardAlertUntil = math.max(guardAlertUntil, os.clock() + 12)
                currentState = "Chase"
                searchStartedAt = nil
                searchMoveIssued = false
                statusLabel.Text = "[ALERT: CHASE]"
                statusLabel.TextColor3 = Color3.fromRGB(255, 30, 30)
                light.Color = Color3.fromRGB(255, 0, 0)
                humanoid.WalkSpeed = 20.5 * (activeNightEvent.GuardSpeedMultiplier or 1)
                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
                if targetRoot then
                    humanoid:MoveTo(targetRoot.Position)
                    if (targetRoot.Position - root.Position).Magnitude <= 5 then
                        local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
                        if targetHumanoid then
                            targetHumanoid:TakeDamage(25)
                            task.wait(0.5)
                        end
                    end
                end
            else
                if currentState == "Chase" and lastKnownPlayerPosition then
                    currentState = "Search"
                    searchStartedAt = os.clock()
                    searchMoveIssued = false
                end

                if currentState ~= "Search" and currentSuspiciousNoise
                    and (os.clock() - currentSuspiciousNoise.Timestamp) < 6
                    and LootLogic.IsNoiseAudible(root.Position, currentSuspiciousNoise.Position, currentSuspiciousNoise.Radius) then
                    guardAlertUntil = math.max(guardAlertUntil, os.clock() + 12)
                    currentState = "Investigate"
                    investigateTarget = currentSuspiciousNoise.Position
                    currentSuspiciousNoise = nil
                end

                if currentState == "Search" and lastKnownPlayerPosition then
                    statusLabel.Text = isAlerted and "[ALERT: SEARCH]" or "[SEARCHING]"
                    statusLabel.TextColor3 = isAlerted and Color3.fromRGB(255, 90, 30) or Color3.fromRGB(255, 220, 30)
                    light.Color = isAlerted and Color3.fromRGB(255, 70, 20) or Color3.fromRGB(255, 200, 20)
                    humanoid.WalkSpeed = awareness.SearchSpeed
                    if not searchMoveIssued then
                        searchMoveIssued = true
                        NavigateTo(lastKnownPlayerPosition)
                    end
                    local searchElapsed = os.clock() - (searchStartedAt or os.clock())
                    if (root.Position - lastKnownPlayerPosition).Magnitude <= 8 then
                        if searchElapsed < SEARCH_DURATION then
                            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, searchElapsed * math.rad(100), 0)
                        else
                            currentState = "Patrol"
                            lastKnownPlayerPosition = nil
                            searchStartedAt = nil
                            searchMoveIssued = false
                        end
                    elseif searchElapsed >= SEARCH_DURATION then
                        currentState = "Patrol"
                        lastKnownPlayerPosition = nil
                        searchStartedAt = nil
                        searchMoveIssued = false
                    end
                elseif currentState == "Investigate" and investigateTarget then
                    statusLabel.Text = isAlerted and "[ALERT: NOISE]" or "[INVESTIGATING]"
                    statusLabel.TextColor3 = isAlerted and Color3.fromRGB(255, 90, 30) or Color3.fromRGB(255, 230, 0)
                    light.Color = isAlerted and Color3.fromRGB(255, 70, 20) or Color3.fromRGB(255, 220, 30)
                    humanoid.WalkSpeed = awareness.InvestigateSpeed
                    NavigateTo(investigateTarget)
                    if (root.Position - investigateTarget).Magnitude <= 8 then
                        task.wait(0.8)
                        currentState = "Patrol"
                        investigateTarget = nil
                    end
                else
                    currentState = "Patrol"
                    statusLabel.Text = isAlerted and "[HIGH ALERT]" or "[PATROLLING]"
                    statusLabel.TextColor3 = isAlerted and Color3.fromRGB(255, 100, 30) or Color3.fromRGB(255, 160, 50)
                    light.Color = isAlerted and Color3.fromRGB(255, 70, 20) or Color3.fromRGB(255, 140, 40)
                    humanoid.WalkSpeed = awareness.PatrolSpeed
                    local dest = waypoints[currentWaypointIndex]
                    NavigateTo(dest)
                    if (root.Position - dest).Magnitude <= 7 then
                        currentWaypointIndex = (currentWaypointIndex % #waypoints) + 1
                        task.wait(0.5)
                    end
                end
            end
        end
    end)

    return model
end

return GuardAI
