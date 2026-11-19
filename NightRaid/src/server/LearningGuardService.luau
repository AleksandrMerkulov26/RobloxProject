--!strict
local Players = game:GetService("Players")

local LearningGuardService = {}

-- Тепловая карта популярности зон склада (сетка 4x4)
-- Сетка от -80 до +80 по X и Z с шагом 40 studs
local zoneHeatMap: { [string]: number } = {}
local currentRaidPositions: { Vector3 } = {}

local function getZoneKey(pos: Vector3): string
    local cellX = math.clamp(math.floor((pos.X + 80) / 40), 0, 3)
    local cellZ = math.clamp(math.floor((pos.Z + 80) / 40), 0, 3)
    return string.format("%d_%d", cellX, cellZ)
end

local function getZoneCenter(cellX: number, cellZ: number): Vector3
    local x = -80 + (cellX * 40) + 20
    local z = -80 + (cellZ * 40) + 20
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
