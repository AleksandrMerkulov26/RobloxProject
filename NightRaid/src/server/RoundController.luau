--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local LootLogic = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LootLogic"))
local NightEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NightEvents"))
local RaidProgression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaidProgression"))
local Locale = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local Remotes = require(script.Parent:WaitForChild("Remotes"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local LootService = require(script.Parent:WaitForChild("LootService"))
local LoadoutService = require(script.Parent:WaitForChild("LoadoutService"))
local GuardAI = require(script.Parent:WaitForChild("GuardAI"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local MapConfigs = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapConfigs"))
local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local CoopService = require(script.Parent:WaitForChild("CoopService"))
local ReplayService = require(script.Parent:WaitForChild("ReplayService"))
local LearningGuardService = require(script.Parent:WaitForChild("LearningGuardService"))

local RoundController = {}
type MapConfig = MapConfigs.MapConfig

local currentMapConfig: MapConfig = MapConfigs.Get("Warehouse")

-- Lighting defaults
local BASE_AMBIENT = Color3.fromRGB(30, 32, 38)
local BASE_OUTDOOR_AMBIENT = Color3.fromRGB(30, 32, 38)
local BASE_FOG_END = 160

Lighting.ClockTime = 0
Lighting.Brightness = 0
Lighting.Ambient = BASE_AMBIENT
Lighting.OutdoorAmbient = BASE_OUTDOOR_AMBIENT
Lighting.FogColor = Color3.fromRGB(10, 10, 15)
Lighting.FogEnd = BASE_FOG_END
Lighting.FogStart = 30
Lighting.GlobalShadows = false

local activeNightEvent = NightEvents.None
local raidStartRequested = false
local extractingPlayers: { [Player]: number } = {}
local activeLootPositions: { Vector3 } = {}

-- Dependencies
local isPlayerEliminatedFn: ((player: Player) -> boolean)?
local resetPlayerForRoundFn: ((player: Player) -> ())?
local getHideoutSpawnFn: ((player: Player) -> CFrame)?

function RoundController.SetDependencies(deps: {
    IsPlayerEliminated: (player: Player) -> boolean,
    ResetPlayerForRound: (player: Player) -> (),
    GetHideoutSpawn: (player: Player) -> CFrame,
})
    isPlayerEliminatedFn = deps.IsPlayerEliminated
    resetPlayerForRoundFn = deps.ResetPlayerForRound
    getHideoutSpawnFn = deps.GetHideoutSpawn
end

function RoundController.GetActiveNightEvent()
    return activeNightEvent
end

function RoundController.InitFacility()
    -- Initial setup, map will be dynamically built per raid
end

local function BuildRaidMap(mapConfig: MapConfig)
    currentMapConfig = mapConfig
    activeLootPositions = MapBuilder.BuildMap(mapConfig, function(doorPosition: Vector3, player: Player, withKeycard: boolean)
        if withKeycard then
            GuardAI.RegisterNoise(doorPosition, 30)
            CoopService.AddAlert(10)
            local inv = LootService.GetInventory(player)
            if inv then
                Remotes.InventoryUpdated:FireClient(player, inv, Locale.Get("VaultUnlockedWithKeycard"))
            end
        else
            GuardAI.RegisterNoise(doorPosition, 120)
            CoopService.AddAlert(40)
            local inv = LootService.GetInventory(player)
            if inv then
                Remotes.InventoryUpdated:FireClient(player, inv, Locale.Get("AlarmSafe"))
            end
        end
    end)
end

local function SetFacilityLampsEnabled(enabled: boolean)
    local facility = workspace:FindFirstChild("HeistFacility")
    if not facility then return end
    for _, descendant in facility:GetDescendants() do
        if descendant:IsA("PointLight") then
            descendant.Enabled = enabled
        end
    end
end

local function ApplyNightEvent(event: any)
    activeNightEvent = event
    Remotes.CurrentNightEvent.Value = event.Name

    if event.Darkness then
        Lighting.Ambient = Color3.fromRGB(8, 9, 12)
        Lighting.OutdoorAmbient = Color3.fromRGB(8, 9, 12)
        Lighting.FogEnd = 110
        SetFacilityLampsEnabled(false)
    elseif event.HeavyFog then
        Lighting.FogStart = 10
        Lighting.FogEnd = 65
        Lighting.FogColor = Color3.fromRGB(25, 25, 30)
    end

    Remotes.NightEvent:FireAllClients(event.Id, event.Name, event.Description)
end

local function ClearNightEvent()
    activeNightEvent = NightEvents.None
    Remotes.CurrentNightEvent.Value = ""
    Lighting.Ambient = BASE_AMBIENT
    Lighting.OutdoorAmbient = BASE_OUTDOOR_AMBIENT
    Lighting.FogEnd = BASE_FOG_END
    SetFacilityLampsEnabled(true)
end

local function CreateExtractionZone(): Part
    local oldZone = workspace:FindFirstChild("ExtractionZone")
    if oldZone then oldZone:Destroy() end

    local pos = currentMapConfig.ExtractionPos
    local zone = Instance.new("Part")
    zone.Name = "ExtractionZone"
    zone.Size = Vector3.new(22, 8, 22)
    zone.Position = pos
    zone.Anchored = true
    zone.CanCollide = false
    zone.CanQuery = false
    zone.CanTouch = true
    zone.Material = Enum.Material.ForceField
    zone.Color = Color3.fromRGB(0, 255, 140)
    zone.Transparency = 0.5
    zone.CastShadow = false
    zone.Parent = workspace

    local pad = Instance.new("Part")
    pad.Name = "ExtractionPad"
    pad.Size = Vector3.new(22, 0.4, 22)
    pad.Position = Vector3.new(pos.X, 0.2, pos.Z)
    pad.Anchored = true
    pad.CanCollide = true
    pad.Material = Enum.Material.DiamondPlate
    pad.Color = Color3.fromRGB(40, 45, 55)
    pad.CastShadow = false
    pad.Parent = zone

    return zone
end

-- Network listeners
Remotes.StartRaid.OnServerEvent:Connect(function(player: Player)
    if Remotes.CurrentPhase.Value ~= "LobbyPhase" or raidStartRequested then return end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return end

    local spawnPos = getHideoutSpawnFn and getHideoutSpawnFn(player).Position or Vector3.zero
    if (root.Position - spawnPos).Magnitude > 45 then
        warn("[RoundController] Start rejected: player is not inside their hideout")
        return
    end

    raidStartRequested = true
    print("[RoundController] Start requested by", player.Name)
end)

function RoundController.StartGameLoop()
    task.spawn(function()
        while true do
            -- 1. ЛОББИ ФАЗА
            Remotes.CurrentPhase.Value = "LobbyPhase"
            raidStartRequested = false

            for _, player in Players:GetPlayers() do
                if resetPlayerForRoundFn then
                    resetPlayerForRoundFn(player)
                end
                if player.Character and getHideoutSpawnFn then
                    local spawnCFrame = getHideoutSpawnFn(player)
                    player.Character:PivotTo(spawnCFrame * CFrame.new(math.random(-6, 6), 0, math.random(-6, 6)))
                end
            end

            Remotes.StateChanged:FireAllClients("LobbyPhase", 0)

            while not raidStartRequested do
                task.wait(0.2)
            end

            -- 2. ФАЗА СБОРА ЛУТА
            Remotes.CurrentPhase.Value = "LootPhase"
            CoopService.ResetAlert()

            local selectedMap = MapConfigs.PickRandom()
            BuildRaidMap(selectedMap)

            for _, player in Players:GetPlayers() do
                if player.Character then
                    player.Character:PivotTo(CFrame.new(Vector3.new(math.random(-15, 15), 3, -math.floor(selectedMap.FloorSize.Z / 2) + 15)))
                end
                Remotes.InventoryUpdated:FireClient(player, {}, Locale.Format("MapAnnounce", Locale.Get(selectedMap.NameKey)))
            end

            LootService.ClearWorldLoot()
            MapBuilder.ClearGroundWeapons()

            local nightEvent = NightEvents.Pick(math.random())
            for _, pos in activeLootPositions do
                local baseItem = Config.LootTable[math.random(1, #Config.LootTable)]
                local item = NightEvents.ScaleLootValue(baseItem, nightEvent.LootValueMultiplier)
                LootService.SpawnLootItem(item, pos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
            end

            if nightEvent.JackpotLoot then
                local vaultLootPos = selectedMap.Vault.LootPositions[1] or Vector3.new(0, 1.5, 0)
                LootService.SpawnLootItem(nightEvent.JackpotLoot, vaultLootPos)
            end

            MapBuilder.SpawnKeycard(selectedMap.KeycardSpawns)
            MapBuilder.SpawnGroundWeapons(selectedMap.WeaponSpawns)

            if not nightEvent.LasersDisabled then
                MapBuilder.SpawnLasers(selectedMap.Lasers, function(player: Player, laserPos: Vector3)
                    GuardAI.RegisterNoise(laserPos, 90)
                    CoopService.AddAlert(15)
                    local inv = LootService.GetInventory(player)
                    if inv then
                        Remotes.InventoryUpdated:FireClient(player, inv, Locale.Get("AlarmLaser"))
                    end
                end)
            end

            GuardAI.ClearAllEntities()
            ReplayService.StartRecording()

            local guardSpawn = selectedMap.GuardSpawns[1] or Vector3.new(-15, 3, -15)
            local guardModel = GuardAI.SpawnGuard(guardSpawn)
            GuardAI.SpawnPatrolDog(guardSpawn + Vector3.new(10, 0, 10))
            GuardAI.SpawnCamera(Vector3.new(0, 20, 0), Vector3.new(0, -0.3, 1))

            Remotes.StateChanged:FireAllClients("LootPhase", Config.LootDuration)
            ApplyNightEvent(nightEvent)
            AnalyticsService.OnRaidStarted(#Players:GetPlayers(), nightEvent.Id)

            -- Запись повтора и обучающейся тепловой карты во время фазы лута
            local lootPhaseEnd = os.clock() + Config.LootDuration
            local lastHeatTrack = os.clock()
            while os.clock() < lootPhaseEnd do
                task.wait(0.25)
                ReplayService.RecordSnapshot(guardModel)
                if os.clock() - lastHeatTrack >= 3.0 then
                    lastHeatTrack = os.clock()
                    LearningGuardService.TrackPlayerPositions()
                end
            end

            -- 3. ФАЗА ЭВАКУАЦИИ
            Remotes.CurrentPhase.Value = "ExtractionPhase"
            local zone = CreateExtractionZone()
            Remotes.StateChanged:FireAllClients("ExtractionPhase", Config.ExtractionDuration)

            local phaseEnd = os.clock() + Config.ExtractionDuration
            while os.clock() < phaseEnd do
                task.wait(0.25)
                ReplayService.RecordSnapshot(guardModel)

                local overlap = OverlapParams.new()
                overlap.FilterType = Enum.RaycastFilterType.Include
                local chars = {}
                for _, player in Players:GetPlayers() do
                    if player.Character then table.insert(chars, player.Character) end
                end
                overlap.FilterDescendantsInstances = chars

                local touchingParts = workspace:GetPartsInPart(zone, overlap)
                local inZone: { [Player]: boolean } = {}
                for _, part in touchingParts do
                    local character = part:FindFirstAncestorOfClass("Model")
                    local pl = character and Players:GetPlayerFromCharacter(character)
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if pl and character == pl.Character and humanoid and humanoid.Health > 0
                        and not (isPlayerEliminatedFn and isPlayerEliminatedFn(pl)) then
                        inZone[pl] = true
                    end
                end

                for player, _ in inZone do
                    local inv = LootService.GetInventory(player)
                    if inv and not inv.Escaped then
                        if not extractingPlayers[player] then
                            extractingPlayers[player] = os.clock()
                        end
                        local rem = math.max(0, 5 - (os.clock() - extractingPlayers[player]))
                        Remotes.ExtractionProgress:FireClient(player, rem, false)

                        if rem <= 0 then
                            inv.Escaped = true
                            extractingPlayers[player] = nil
                            Remotes.ExtractionProgress:FireClient(player, 0, true)

                            local leaderstats = player:FindFirstChild("leaderstats")
                            local cash = leaderstats and leaderstats:FindFirstChild("Cash") :: IntValue?
                            local raidsStat = leaderstats and leaderstats:FindFirstChild("Raids") :: IntValue?
                            local streakStat = leaderstats and leaderstats:FindFirstChild("Streak") :: IntValue?
                            local prevStreak = streakStat and streakStat.Value or 0

                            local alivePlayersCount = 0
                            for _, p in Players:GetPlayers() do
                                if not (isPlayerEliminatedFn and isPlayerEliminatedFn(p)) then
                                    alivePlayersCount += 1
                                end
                            end
                            local coopBonusPercent = CoopService.CalculateCoopBonusPercent(alivePlayersCount)

                            local streakPayout = LootLogic.ApplyStreakBonus(inv.TotalValue, prevStreak)
                            local payout = math.floor(streakPayout * (100 + coopBonusPercent) / 100)
                            if cash then cash.Value += payout end

                            local updatedRaids, updatedStreak = RaidProgression.ApplyOutcome(
                                raidsStat and raidsStat.Value or 0,
                                prevStreak,
                                true
                            )
                            if raidsStat then raidsStat.Value = updatedRaids end
                            if streakStat then streakStat.Value = updatedStreak end
                            DataService.SavePlayerData(player)

                            local bonusPercent = LootLogic.GetStreakBonusPercent(prevStreak)
                            if bonusPercent > 0 then
                                Remotes.InventoryUpdated:FireClient(player, inv, Locale.Format(
                                    "StreakBonusNotification", prevStreak, bonusPercent
                                ))
                            end
                            if coopBonusPercent > 0 then
                                Remotes.InventoryUpdated:FireClient(player, inv, Locale.Format(
                                    "TeamBonusNotice", coopBonusPercent
                                ))
                            end

                            Remotes.ShowRaidSummary:FireClient(player, true, payout, #inv.Items, (cash and cash.Value) or 0)
                            local currentLoadout = LoadoutService.GetActiveLoadout(player)
                            AnalyticsService.OnPlayerEscaped(player, payout, #inv.Items, currentLoadout.Id)
                            if player.Character and getHideoutSpawnFn then
                                player.Character:PivotTo(getHideoutSpawnFn(player))
                            end
                        end
                    end
                end

                for player, _ in extractingPlayers do
                    if not inZone[player] then
                        extractingPlayers[player] = nil
                        Remotes.ExtractionProgress:FireClient(player, -1, false)
                    end
                end
            end

            -- Завершение раунда: сброс серии тем, кто не эвакуировался
            local escapedCount = 0
            local eliminatedCount = 0

            for _, player in Players:GetPlayers() do
                local inv = LootService.GetInventory(player)
                if inv and inv.Escaped then
                    escapedCount += 1
                elseif inv and not inv.Escaped then
                    eliminatedCount += 1
                    local leaderstats = player:FindFirstChild("leaderstats")
                    local cash = leaderstats and leaderstats:FindFirstChild("Cash") :: IntValue?
                    local streakStat = leaderstats and leaderstats:FindFirstChild("Streak") :: IntValue?
                    if streakStat then
                        local _, updatedStreak = RaidProgression.ApplyOutcome(
                            leaderstats and leaderstats:FindFirstChild("Raids") and (leaderstats:FindFirstChild("Raids") :: IntValue).Value or 0,
                            streakStat.Value,
                            false
                        )
                        streakStat.Value = updatedStreak
                        DataService.SavePlayerData(player)
                    end
                    Remotes.ShowRaidSummary:FireClient(player, false, 0, 0, (cash and cash.Value) or 0)
                    local curLoadout = LoadoutService.GetActiveLoadout(player)
                    AnalyticsService.OnPlayerEliminated(player, "Timeout", curLoadout.Id)
                end
            end

            AnalyticsService.OnRaidEnded(escapedCount, eliminatedCount, #Players:GetPlayers())

            ReplayService.StopRecording()
            LearningGuardService.OnRaidFinished()

            if zone then zone:Destroy() end
            ClearNightEvent()
            GuardAI.ClearAllEntities()
        end
    end)
end

return RoundController
