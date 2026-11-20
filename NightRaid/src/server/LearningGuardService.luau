--!strict
local Players = game:GetService("Players")

local LearningGuardService = {}

-- Тепловая карта популярности зон склада (адаптивная сетка 4x4)
local zoneHeatMap: { [string]: number } = {}
local currentRaidPositions: { Vector3 } = {}
local currentFloorSize: Vector3 = Vector3.new(160, 10, 160)

function LearningGuardService.SetMapFloorSize(floorSize: Vector3)
    currentFloorSize = floorSize
end

local function getZoneKey(pos: Vector3): string
    local halfX = currentFloorSize.X / 2
    local halfZ = currentFloorSize.Z / 2
    local stepX = currentFloorSize.X / 4
    local stepZ = currentFloorSize.Z / 4
    local cellX = math.clamp(math.floor((pos.X + halfX) / stepX), 0, 3)
    local cellZ = math.clamp(math.floor((pos.Z + halfZ) / stepZ), 0, 3)
    return string.format("%d_%d", cellX, cellZ)
end

local function getZoneCenter(cellX: number, cellZ: number): Vector3
    local halfX = currentFloorSize.X / 2
    local halfZ = currentFloorSize.Z / 2
    local stepX = currentFloorSize.X / 4
    local stepZ = currentFloorSize.Z / 4
    local x = -halfX + (cellX * stepX) + (stepX / 2)
    local z = -halfZ + (cellZ * stepZ) + (stepZ / 2)
    return Vector3.new(x, 3, z)
end

function LearningGuardService.ResetSession()
    zoneHeatMap = {}
    currentRaidPositions = {}
end

function LearningGuardService.TrackPlayerPositions()
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then
            table.insert(currentRaidPositions, hrp.Position)
            local key = getZoneKey(hrp.Position)
            zoneHeatMap[key] = (zoneHeatMap[key] or 0) + 1
        end
    end
end

function LearningGuardService.OnRaidFinished()
    print("[LearningGuards] Raid route heat summary:")
    for key, count in pairs(zoneHeatMap) do
        print(string.format("  Zone %s: %d player visits", key, count))
    end
end

-- Возвращает модифицированный список вейпоинтов для патруля охранника,
-- смещенный в сторону наиболее популярных маршрутов игроков!
function LearningGuardService.GetAdaptiveWaypoints(defaultWaypoints: { Vector3 }): { Vector3 }
    local highestZone: string? = nil
    local highestVisits = 0

    for key, count in pairs(zoneHeatMap) do
        if count > highestVisits then
            highestVisits = count
            highestZone = key
        end
    end

    if not highestZone or highestVisits < 3 then
        return defaultWaypoints
    end

    local cellX, cellZ = highestZone:match("^(%d+)_(%d+)$")
    if not cellX or not cellZ then
        return defaultWaypoints
    end

    local hotspotCenter = getZoneCenter(tonumber(cellX) or 0, tonumber(cellZ) or 0)
    print(string.format("[LearningGuards] Guard adapted patrol toward hotspot zone %s (%s)", highestZone, tostring(hotspotCenter)))

    local adaptedWaypoints = {}
    for _, wp in ipairs(defaultWaypoints) do
        table.insert(adaptedWaypoints, wp)
    end

    -- Вставляем горячую точку в маршрут патруля охраны
    table.insert(adaptedWaypoints, 2, hotspotCenter)
    return adaptedWaypoints
end

return LearningGuardService
