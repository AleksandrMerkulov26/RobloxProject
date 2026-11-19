--!strict
local Players = game:GetService("Players")
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

function CoopService.SetDependencies(deps: {
    IsPlayerEliminated: (player: Player) -> boolean,
    OnPlayerFullyDied: (player: Player) -> (),
    GetPlayerRole: (player: Player) -> string,
})
    isPlayerEliminatedFn = deps.IsPlayerEliminated
    onPlayerFullyDiedFn = deps.OnPlayerFullyDied
    getPlayerRoleFn = deps.GetPlayerRole
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

function CoopService.DownPlayer(player: Player)
    if downedPlayers[player] then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    player:SetAttribute("IsDowned", true)
    hum.WalkSpeed = 3 -- Ползком
    hum.AutoRotate = false

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

function CoopService.RevivePlayer(downedPlayer: Player, rescuer: Player)
    local data = downedPlayers[downedPlayer]
    if not data then return end

    CoopService.ClearDowned(downedPlayer)

    local char = downedPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = 45 -- Поднят с частью здоровья
        hum.AutoRotate = true
    end

    downedPlayer:SetAttribute("IsDowned", false)
    Remotes.PlayerDownedState:FireAllClients(downedPlayer, false)

    Remotes.InventoryUpdated:FireClient(downedPlayer, {}, Locale.Get("RevivedNotice"))
    Remotes.InventoryUpdated:FireClient(rescuer, {}, Locale.Format("RevivedTeammateNotice", downedPlayer.DisplayName))
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
end

function CoopService.CalculateCoopBonusPercent(survivingCount: number): number
    if survivingCount <= 1 then
        return 0
    end
    -- +15% за каждого выжившего напарника (до +45% для четверых)
    return math.min((survivingCount - 1) * 15, 45)
end

return CoopService
