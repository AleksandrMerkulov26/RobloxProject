-- Pure raid progression rules shared by the server and deterministic tests.
-- Keeping these decisions outside the server loop makes them testable without
-- simulating the full Roblox game world.
local RaidProgression = {}

RaidProgression.MaxRaidCount = 2000000000
RaidProgression.MaxStreak = 5

local function toSafeInteger(value: any, fallback: number): number
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end

    return math.floor(value)
end

function RaidProgression.NormalizeStats(raids: any, streak: any)
    return {
        Raids = math.clamp(toSafeInteger(raids, 0), 0, RaidProgression.MaxRaidCount),
        Streak = math.clamp(toSafeInteger(streak, 0), 0, RaidProgression.MaxStreak),
    }
end

function RaidProgression.ShouldDropLoot(phase: string, escaped: boolean, itemCount: number): boolean
    local raidIsActive = phase == "LootPhase" or phase == "ExtractionPhase"
    return raidIsActive and not escaped and itemCount > 0
end

function RaidProgression.ShouldRespawn(isDead: boolean, phase: string): boolean
    return isDead and phase == "LobbyPhase"
end

function RaidProgression.ApplyOutcome(raids: any, streak: any, escaped: boolean)
    local stats = RaidProgression.NormalizeStats(raids, streak)

    if not escaped then
        stats.Streak = 0
        return stats.Raids, stats.Streak
    end

    stats.Raids = math.min(stats.Raids + 1, RaidProgression.MaxRaidCount)
    stats.Streak = math.min(stats.Streak + 1, RaidProgression.MaxStreak)
    return stats.Raids, stats.Streak
end

return RaidProgression
