--!strict
local Players = game:GetService("Players")

local ReplayService = {}

export type ReplayFrame = {
    T: number, -- Время кадра (сек)
    GX: number, -- Guard X
    GZ: number, -- Guard Z
    GAngle: number, -- Guard угол поворота
    Players: { [number]: { X: number, Z: number, Downed: boolean } },
}

local MAX_FRAMES = 240 -- 60 секунд реплея (по 4 кадра в секунду)
local currentReplayBuffer: { ReplayFrame } = {}
local isRecording = false

function ReplayService.StartRecording()
    currentReplayBuffer = {}
    isRecording = true
end

function ReplayService.StopRecording()
    isRecording = false
end

function ReplayService.RecordSnapshot(guardModel: Model?)
    if not isRecording then return end

    local gRoot = guardModel and guardModel.PrimaryPart
    local gx = gRoot and math.floor(gRoot.Position.X) or 0
    local gz = gRoot and math.floor(gRoot.Position.Z) or 0
    local gAngle = gRoot and math.floor(gRoot.Orientation.Y) or 0

    local playerPositions: { [number]: { X: number, Z: number, Downed: boolean } } = {}

    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp then
            playerPositions[player.UserId] = {
                X = math.floor(hrp.Position.X),
                Z = math.floor(hrp.Position.Z),
                Downed = player:GetAttribute("IsDowned") == true,
            }
        end
    end

    local frame: ReplayFrame = {
        T = os.clock(),
        GX = gx,
        GZ = gz,
        GAngle = gAngle,
        Players = playerPositions,
    }

    table.insert(currentReplayBuffer, frame)

    if #currentReplayBuffer > MAX_FRAMES then
        table.remove(currentReplayBuffer, 1)
    end
end

function ReplayService.GetReplayDataForPlayer(userId: number): { { T: number, GX: number, GZ: number, GAngle: number, PX: number, PZ: number, Downed: boolean } }
    local result = {}
    local startTime = currentReplayBuffer[1] and currentReplayBuffer[1].T or os.clock()

    for _, frame in ipairs(currentReplayBuffer) do
        local pData = frame.Players[userId]
        if pData then
            table.insert(result, {
                T = math.floor((frame.T - startTime) * 10) / 10,
                GX = frame.GX,
                GZ = frame.GZ,
                GAngle = frame.GAngle,
                PX = pData.X,
                PZ = pData.Z,
                Downed = pData.Downed,
            })
        end
    end

    return result
end

return ReplayService
