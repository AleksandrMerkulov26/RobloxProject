--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))
local RaidProgression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaidProgression"))
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local Remotes = require(script:WaitForChild("Remotes"))
local DataService = require(script:WaitForChild("DataService"))
local LootService = require(script:WaitForChild("LootService"))
local LoadoutService = require(script:WaitForChild("LoadoutService"))
local UpgradeService = require(script:WaitForChild("UpgradeService"))
local GuardAI = require(script:WaitForChild("GuardAI"))
local RoundController = require(script:WaitForChild("RoundController"))
local HideoutBuilder = require(script:WaitForChild("HideoutBuilder"))
local AnalyticsService = require(script:WaitForChild("AnalyticsService"))
local CoopService = require(script:WaitForChild("CoopService"))
local ReplayService = require(script:WaitForChild("ReplayService"))

-- Инициализация систем
UpgradeService.Init()
RoundController.InitFacility()

-- Убежища и элиминации
local playerHideouts: { [Player]: { Model: Model, SpawnCFrame: CFrame, Data: any } } = {}
local playerHideoutSlots: { [Player]: number } = {}
local hideoutSlotOwners: { [number]: Player? } = {}
local eliminatedPlayers: { [Player]: boolean } = {}
local remoteActionTimes: { [Player]: { [string]: number } } = {}

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

local function loadCharacterForPlayer(player: Player)
    if player.Parent == Players then
        pcall(function()
            player:LoadCharacterAsync()
        end)
    end
end

local function canPerformAction(player: Player, actionName: string, cooldown: number): boolean
    local now = os.clock()
    local actions = remoteActionTimes[player]
    if not actions then
        actions = {}
        remoteActionTimes[player] = actions
    end

    local lastAction = actions[actionName]
    if lastAction and now - lastAction < cooldown then
        return false
    end

    actions[actionName] = now
    return true
end

local function isPlayerEliminated(player: Player): boolean
    return eliminatedPlayers[player] == true
end

local function getEffectiveMaxWeight(player: Player): number
    local loadout = LoadoutService.GetActiveLoadout(player)
    local upg = DataService.GetUpgrades(player)
    return LootLogic.GetEffectiveMaxWeight(loadout.MaxWeight, upg.Pockets)
end

local function getHideoutSpawn(player: Player): CFrame
    local hideout = playerHideouts[player]
    return hideout and hideout.SpawnCFrame or CFrame.new(0, 123, 0)
end

-- Внедрение зависимостей в сервисы
LootService.SetDependencies({
    GetEffectiveMaxWeight = getEffectiveMaxWeight,
    GetActiveLoadout = function(player: Player) return LoadoutService.GetActiveLoadout(player) end,
    IsPlayerEliminated = isPlayerEliminated,
})

GuardAI.SetDependencies({
    IsPlayerEliminated = isPlayerEliminated,
    GetActiveNightEvent = function() return RoundController.GetActiveNightEvent() end,
})

RoundController.SetDependencies({
    IsPlayerEliminated = isPlayerEliminated,
    ResetPlayerForRound = function(player: Player)
        eliminatedPlayers[player] = false
        player:SetAttribute("Eliminated", false)
        LootService.ResetForRound(player)
        local curLoadout = LoadoutService.GetActiveLoadout(player)
        LoadoutService.ApplyLoadout(player, curLoadout)

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            pcall(function() player:LoadCharacterAsync() end)
        end
    end,
    GetHideoutSpawn = getHideoutSpawn,
})

local function AllocateHideoutSlot(player: Player): number
    for slot = 1, math.max(Players.MaxPlayers, 1) do
        if not hideoutSlotOwners[slot] then
            hideoutSlotOwners[slot] = player
            playerHideoutSlots[player] = slot
            return slot
        end
    end
    local slot = Players.MaxPlayers + 1
    while hideoutSlotOwners[slot] do slot += 1 end
    hideoutSlotOwners[slot] = player
    playerHideoutSlots[player] = slot
    return slot
end

local function handlePlayerElimination(player: Player, hrpPosition: Vector3)
    local phase = Remotes.CurrentPhase.Value
    local raidIsActive = RaidProgression.ShouldEliminate(phase)
    if raidIsActive then
        eliminatedPlayers[player] = true
        player:SetAttribute("Eliminated", true)
        local curLoadout = LoadoutService.GetActiveLoadout(player)
        AnalyticsService.OnPlayerEliminated(player, "GuardOrHazard", curLoadout.Id)
    end

    local inv = LootService.GetInventory(player)
    local shouldDrop = inv and RaidProgression.ShouldDropLoot(phase, inv.Escaped, #inv.Items) or false
    LootService.HandlePlayerDeath(player, hrpPosition, shouldDrop)

    task.delay(2, function()
        if player.Parent == Players then
            loadCharacterForPlayer(player)
        end
    end)
end

CoopService.SetDependencies({
    IsPlayerEliminated = isPlayerEliminated,
    OnPlayerFullyDied = function(player: Player)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local pos = hrp and hrp.Position or Vector3.zero
        handlePlayerElimination(player, pos)
    end,
    GetPlayerRole = function(player: Player)
        local loadout = LoadoutService.GetActiveLoadout(player)
        return loadout.Role or "Default"
    end,
})

local function InitPlayer(player: Player)
    DataService.LoadPlayerData(player)

    local slot = AllocateHideoutSlot(player)
    local hideoutData = DataService.GetHideoutData(player)
    local hideoutModel, spawnCFrame, dealerPrompt, stationPrompts = HideoutBuilder.Build(player.UserId, slot, hideoutData)

    playerHideouts[player] = {
        Model = hideoutModel,
        SpawnCFrame = spawnCFrame,
        Data = hideoutData,
    }

    dealerPrompt.Triggered:Connect(function(triggeringPlayer: Player)
        if triggeringPlayer ~= player then return end
        local upg = DataService.GetUpgrades(player)
        Remotes.UpgradesUpdated:FireClient(player, upg, true)
    end)

    for stationName, stationPrompt in stationPrompts :: { [string]: ProximityPrompt } do
        stationPrompt.Triggered:Connect(function(triggeringPlayer: Player)
            if triggeringPlayer ~= player then return end
            Remotes.OpenHideoutStation:FireClient(player, stationName)
        end)
    end

    eliminatedPlayers[player] = false
    player:SetAttribute("Eliminated", false)

    LootService.InitPlayer(player)
    LoadoutService.InitPlayer(player)

    player.CharacterAdded:Connect(function(char: Model)
        task.wait(0.2)
        if Remotes.CurrentPhase.Value == "LobbyPhase" or eliminatedPlayers[player] then
            char:PivotTo(getHideoutSpawn(player))
        else
            char:PivotTo(CFrame.new(0, 3, -65))
        end

        local hum = char:WaitForChild("Humanoid") :: Humanoid
        local hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
        local activeLoadout = LoadoutService.GetActiveLoadout(player)
        hum.WalkSpeed = activeLoadout.WalkSpeed

        hum.Died:Connect(function()
            local phase = Remotes.CurrentPhase.Value
            local raidIsActive = RaidProgression.ShouldEliminate(phase)

            if raidIsActive and not CoopService.IsDowned(player) then
                -- Во время рейда сначала отправляем игрока в нокаут для помощи от напарников
                hum.Health = 1
                CoopService.DownPlayer(player)
            else
                handlePlayerElimination(player, hrp.Position)
            end
        end)

        local fallY = 0
        local inFreefall = false

        hum.StateChanged:Connect(function(_, new)
            if new == Enum.HumanoidStateType.Freefall then
                fallY = hrp.Position.Y
                inFreefall = true
            elseif new == Enum.HumanoidStateType.Landed and inFreefall then
                inFreefall = false
                local dropped = fallY - hrp.Position.Y
                LootService.HandleFallDamage(player, dropped)
            end
        end)
    end)

    task.spawn(loadCharacterForPlayer, player)
end

-- Наблюдение за рейдом из убежища
Remotes.GetRaidStatus.OnServerInvoke = function(requestingPlayer: Player)
    local hideout = playerHideouts[requestingPlayer]
    local character = requestingPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local commandZone = hideout and hideout.Model and hideout.Model:FindFirstChild("Command")
    local commandConsole = commandZone and commandZone:FindFirstChild("MainStation") :: BasePart?

    if not hideout or not hideout.Model or not hideout.Model.Parent
        or not root or not commandConsole
        or (root.Position - commandConsole.Position).Magnitude > 18 then
        return {}
    end

    local result = {}
    local phase = Remotes.CurrentPhase.Value
    for _, targetPlayer in Players:GetPlayers() do
        if targetPlayer ~= requestingPlayer then
            local inventory = LootService.GetInventory(targetPlayer)
            local targetChar = targetPlayer.Character
            local humanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
            local isAlive = humanoid ~= nil and humanoid.Health > 0
            local escaped = inventory ~= nil and inventory.Escaped == true
            local status = Locale.Get("StatusWaiting")
            local canSpectate = false

            if escaped then
                status = Locale.Get("StatusEscaped")
            elseif phase == "LootPhase" or phase == "ExtractionPhase" then
                if isAlive then
                    status = Locale.Get("StatusInRaid")
                    canSpectate = true
                else
                    status = Locale.Get("StatusEliminated")
                end
            end

            table.insert(result, {
                UserId = targetPlayer.UserId,
                DisplayName = targetPlayer.DisplayName,
                Status = status,
                CanSpectate = canSpectate,
            })
        end
    end

    table.sort(result, function(a, b) return a.DisplayName < b.DisplayName end)
    return result
end

Remotes.GetRaidReplay.OnServerInvoke = function(player: Player)
    return ReplayService.GetReplayDataForPlayer(player.UserId)
end

-- Действия игрока: Тайзер, Дым, Шум
Remotes.FireTaser.OnServerEvent:Connect(function(player: Player, targetPos: any)
    if Remotes.CurrentPhase.Value ~= "LootPhase" or eliminatedPlayers[player] then return end
    if typeof(targetPos) ~= "Vector3" then return end
    if not canPerformAction(player, "FireTaser", 1.0) then return end

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local tool = char:FindFirstChild("Taser")
    if not hrp or not humanoid or humanoid.Health <= 0 or not tool then return end

    local direction = targetPos - hrp.Position
    if direction.Magnitude < 1 or direction.Magnitude > 50 then return end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { char :: Instance }
    local hit = workspace:Raycast(hrp.Position, direction, rayParams)

    local guard = workspace:FindFirstChild("GuardNPC")
    if guard and guard.PrimaryPart and hit and hit.Instance:IsDescendantOf(guard) then
        GuardAI.Stun(5.0)
        local inv = LootService.GetInventory(player)
        if inv then
            Remotes.InventoryUpdated:FireClient(player, inv, Locale.Get("TaserStunSuccess"))
        end
    end

    tool:Destroy()
end)

Remotes.ThrowSmoke.OnServerEvent:Connect(function(player: Player)
    if Remotes.CurrentPhase.Value ~= "LootPhase" or eliminatedPlayers[player] then return end
    if not canPerformAction(player, "ThrowSmoke", 10.0) then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return end

    local spawnPos = hrp.Position + hrp.CFrame.LookVector * 10
    local smokeCloud = Instance.new("Part")
    smokeCloud.Name = "SmokeCloud"
    smokeCloud.Shape = Enum.PartType.Ball
    smokeCloud.Size = Vector3.new(24, 18, 24)
    smokeCloud.Position = spawnPos
    smokeCloud.Anchored = true
    smokeCloud.CanCollide = false
    smokeCloud.Material = Enum.Material.ForceField
    smokeCloud.Color = Color3.fromRGB(180, 180, 180)
    smokeCloud.Transparency = 0.35
    smokeCloud.CastShadow = false
    smokeCloud.Parent = smokesContainer

    task.delay(7.0, function()
        if smokeCloud and smokeCloud.Parent then smokeCloud:Destroy() end
    end)
end)

Remotes.MakeNoise.OnServerEvent:Connect(function(player: Player)
    if Remotes.CurrentPhase.Value ~= "LootPhase" or eliminatedPlayers[player] then return end
    if not canPerformAction(player, "MakeNoise", 0.75) then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return end

    GuardAI.RegisterNoise(hrp.Position, 40)
end)

-- Подключение игроков
Players.PlayerAdded:Connect(InitPlayer)
Players.PlayerRemoving:Connect(function(player: Player)
    -- Если игрок вышел во время рейда с лутом, дропаем его на месте выхода для напарников
    local phase = Remotes.CurrentPhase.Value
    if (phase == "LootPhase" or phase == "ExtractionPhase") and not isPlayerEliminated(player) then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local pos = hrp and hrp.Position or Vector3.new(0, 3, 0)
        local inv = LootService.GetInventory(player)
        if inv and #inv.Items > 0 then
            LootService.HandlePlayerDeath(player, pos, true)
        end
    end

    CoopService.ClearDowned(player)
    DataService.RemovePlayer(player)

    local hideout = playerHideouts[player]
    if hideout and hideout.Model then hideout.Model:Destroy() end

    local slot = playerHideoutSlots[player]
    if slot then hideoutSlotOwners[slot] = nil end

    playerHideouts[player] = nil
    playerHideoutSlots[player] = nil
    eliminatedPlayers[player] = nil
    remoteActionTimes[player] = nil

    LootService.RemovePlayer(player)
    LoadoutService.RemovePlayer(player)
end)

for _, p in Players:GetPlayers() do
    InitPlayer(p)
end

-- Корректное завершение работы сервера
game:BindToClose(function()
    local playersToSave = Players:GetPlayers()
    local pending = #playersToSave
    if pending == 0 then return end

    for _, player in playersToSave do
        task.spawn(function()
            DataService.SavePlayerData(player)
            pending -= 1
        end)
    end

    local deadline = os.clock() + 25
    while pending > 0 and os.clock() < deadline do
        task.wait(0.1)
    end
end)

-- Запуск игрового цикла
RoundController.StartGameLoop()

print("[СЕРВЕР]: Инициализация завершена. Модульная архитектура активна.")
