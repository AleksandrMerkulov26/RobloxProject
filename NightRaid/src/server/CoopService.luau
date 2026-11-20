--!strict
local _Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local CoopService = {}

local downedPlayers: { [Player]: { BleedoutEnd: number, Prompt: ProximityPrompt? } } = {}
local sharedAlertLevel: number = 0
local lastAlertUpdateTime: number = os.clock()

local isPlayerEliminatedFn: ((player: Player) -> boolean)?
local onPlayerFullyDiedFn: ((player: Player) -> ())?
local getPlayerRoleFn: ((player: Player) -> string)?
local restorePlayerSpeedFn: ((player: Player) -> ())?

function CoopService.SetDependencies(deps: {
    IsPlayerEliminated: (player: Player) -> boolean,
    OnPlayerFullyDied: (player: Player) -> (),
    GetPlayerRole: (player: Player) -> string,
    RestorePlayerSpeed: ((player: Player) -> ())?,
})
    isPlayerEliminatedFn = deps.IsPlayerEliminated
    onPlayerFullyDiedFn = deps.OnPlayerFullyDied
    getPlayerRoleFn = deps.GetPlayerRole
    restorePlayerSpeedFn = deps.RestorePlayerSpeed
end

function CoopService.IsDowned(player: Player): boolean
    return downedPlayers[player] ~= nil
end

function CoopService.GetSharedAlertLevel(): number
    return sharedAlertLevel
end

function CoopService.ResetAlert()
    sharedAlertLevel = 0
    Remotes.AlertLevelChanged:FireAllClients(0)
end

function CoopService.AddAlert(amount: number)
    sharedAlertLevel = math.clamp(sharedAlertLevel + amount, 0, 100)
    lastAlertUpdateTime = os.clock()
    Remotes.AlertLevelChanged:FireAllClients(sharedAlertLevel)
end

-- Цикл затухания тревоги при отсутствии шума
task.spawn(function()
    while true do
        task.wait(1.5)
        if os.clock() - lastAlertUpdateTime > 4.0 and sharedAlertLevel > 0 then
            sharedAlertLevel = math.max(0, sharedAlertLevel - 3)
            Remotes.AlertLevelChanged:FireAllClients(sharedAlertLevel)
        end
    end
end)

local function enableRagdoll(char: Model)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end
    for _, motor in char:GetDescendants() do
        if motor:IsA("Motor6D") and motor.Name ~= "RootJoint" then
            local p0 = motor.Part0
            local p1 = motor.Part1
            if p0 and p1 then
                local a0 = Instance.new("Attachment")
                a0.Name = "RagdollAttach0"
                a0.CFrame = motor.C0
                a0.Parent = p0

                local a1 = Instance.new("Attachment")
                a1.Name = "RagdollAttach1"
                a1.CFrame = motor.C1
                a1.Parent = p1

                local socket = Instance.new("BallSocketConstraint")
                socket.Name = "RagdollSocket"
                socket.Attachment0 = a0
                socket.Attachment1 = a1
                socket.LimitsEnabled = true
                socket.TwistLimitsEnabled = true
                socket.Parent = p1

                motor.Enabled = false
            end
        end
    end
end

local function disableRagdoll(char: Model)
    for _, desc in char:GetDescendants() do
        if desc.Name == "RagdollSocket" or desc.Name == "RagdollAttach0" or desc.Name == "RagdollAttach1" then
            desc:Destroy()
        elseif desc:IsA("Motor6D") then
            desc.Enabled = true
        end
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

function CoopService.DownPlayer(player: Player)
    if downedPlayers[player] then return end

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    player:SetAttribute("IsDowned", true)
    hum.WalkSpeed = 0
    hum.AutoRotate = false
    enableRagdoll(char)

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "RevivePrompt"
    prompt.ActionText = Locale.Get("RevivePrompt")
    prompt.ObjectText = player.DisplayName
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 3.0
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = hrp

    downedPlayers[player] = {
        BleedoutEnd = os.clock() + 30.0,
        Prompt = prompt,
    }

    Remotes.PlayerDownedState:FireAllClients(player, true)
    Remotes.InventoryUpdated:FireClient(player, {}, Locale.Get("DownedNotice"))

    prompt.PromptButtonHoldBegan:Connect(function(rescuer: Player)
        -- Support специалист поднимает напарников в 2 раза быстрее!
        local role = getPlayerRoleFn and getPlayerRoleFn(rescuer) or "Default"
        if role == "Support" then
            prompt.HoldDuration = 1.5
        else
            prompt.HoldDuration = 3.0
        end
    end)

    prompt.Triggered:Connect(function(rescuer: Player)
        if rescuer == player then return end
        if isPlayerEliminatedFn and isPlayerEliminatedFn(rescuer) then return end
        if CoopService.IsDowned(rescuer) then return end

        CoopService.RevivePlayer(player, rescuer)
    end)

    -- Таймер кровотечения (30 секунд)
    task.spawn(function()
        local data = downedPlayers[player]
        while data and os.clock() < data.BleedoutEnd do
            task.wait(0.5)
            data = downedPlayers[player]
        end

        -- Если не спасли за 30 секунд
        if downedPlayers[player] then
            CoopService.ClearDowned(player)
            if onPlayerFullyDiedFn then
                onPlayerFullyDiedFn(player)
            end
        end
    end)
end

function CoopService.RevivePlayer(downedPlayer: Player, rescuer: Player): boolean
    -- All revive entry points (ProximityPrompt and RemoteEvent) pass through
    -- this server-side validation. Never trust the client to decide eligibility.
    if downedPlayer == rescuer then return false end
    if downedPlayer.Parent ~= _Players or rescuer.Parent ~= _Players then return false end

    local phase = Remotes.CurrentPhase.Value
    if phase ~= "LootPhase" and phase ~= "ExtractionPhase" then return false end
    if not downedPlayers[downedPlayer] then return false end
    if CoopService.IsDowned(rescuer) then return false end
    if isPlayerEliminatedFn and (isPlayerEliminatedFn(downedPlayer) or isPlayerEliminatedFn(rescuer)) then
        return false
    end

    local downedChar = downedPlayer.Character
    local rescuerChar = rescuer.Character
    local downedRoot = downedChar and downedChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    local rescuerRoot = rescuerChar and rescuerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
    local downedHumanoid = downedChar and downedChar:FindFirstChildOfClass("Humanoid")
    local rescuerHumanoid = rescuerChar and rescuerChar:FindFirstChildOfClass("Humanoid")

    if not downedRoot or not rescuerRoot or not downedHumanoid or not rescuerHumanoid then
        return false
    end
    if downedHumanoid.Health <= 0 or rescuerHumanoid.Health <= 0 then return false end
    if (downedRoot.Position - rescuerRoot.Position).Magnitude > 9 then return false end

    local data = downedPlayers[downedPlayer]
    if not data then return false end

    CoopService.ClearDowned(downedPlayer)

    local char = downedPlayer.Character
    if char then
        disableRagdoll(char)
    end

    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = 45 -- Поднят с частью здоровья
        hum.AutoRotate = true
        if restorePlayerSpeedFn then
            restorePlayerSpeedFn(downedPlayer)
        else
            hum.WalkSpeed = 16
        end
    end

    downedPlayer:SetAttribute("IsDowned", false)
    Remotes.PlayerDownedState:FireAllClients(downedPlayer, false)

    Remotes.InventoryUpdated:FireClient(downedPlayer, {}, Locale.Get("RevivedNotice"))
    Remotes.InventoryUpdated:FireClient(rescuer, {}, Locale.Format("RevivedTeammateNotice", downedPlayer.DisplayName))
    return true
end

function CoopService.ClearDowned(player: Player)
    local data = downedPlayers[player]
    if data then
        if data.Prompt then
            data.Prompt:Destroy()
        end
        downedPlayers[player] = nil
    end
    player:SetAttribute("IsDowned", false)
    if player.Character then
        disableRagdoll(player.Character)
    end
end

function CoopService.CalculateCoopBonusPercent(survivingCount: number): number
    if survivingCount <= 1 then
        return 0
    end
    -- +15% за каждого выжившего напарника (до +45% для четверых)
    return math.min((survivingCount - 1) * 15, 45)
end

return CoopService
