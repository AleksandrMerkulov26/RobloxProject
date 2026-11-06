-- Deterministic tests for pure raid progression rules.
-- Run in CI with: lune run tests/RaidProgression.spec.luau
local RaidProgression = require("../src/shared/RaidProgression")

local total = 0
local failed = 0

local function expect(name, actual, expected)
    total += 1
    if actual ~= expected then
        failed += 1
        error(string.format("[FAIL] %s: expected %s, got %s", name, tostring(expected), tostring(actual)))
    end
    print(string.format("[PASS] %s", name))
end

local normalized = RaidProgression.NormalizeStats(12.9, 7)
expect("stats floor raid count", normalized.Raids, 12)
expect("stats clamp streak to five", normalized.Streak, 5)

normalized = RaidProgression.NormalizeStats(-10, -2)
expect("negative raid count clamps to zero", normalized.Raids, 0)
expect("negative streak clamps to zero", normalized.Streak, 0)

normalized = RaidProgression.NormalizeStats("bad", math.huge)
expect("invalid raid count uses safe default", normalized.Raids, 0)
expect("infinite streak uses safe default", normalized.Streak, 0)

expect("loot drops during loot phase", RaidProgression.ShouldDropLoot("LootPhase", false, 2), true)
expect("loot drops during extraction phase", RaidProgression.ShouldDropLoot("ExtractionPhase", false, 1), true)
expect("no loot drops in lobby", RaidProgression.ShouldDropLoot("LobbyPhase", false, 2), false)
expect("escaped player does not drop loot", RaidProgression.ShouldDropLoot("ExtractionPhase", true, 2), false)
expect("empty inventory does not create a drop", RaidProgression.ShouldDropLoot("LootPhase", false, 0), false)

expect("dead player waits during loot phase", RaidProgression.ShouldRespawn(true, "LootPhase"), false)
expect("dead player waits during extraction phase", RaidProgression.ShouldRespawn(true, "ExtractionPhase"), false)
expect("dead player can respawn in lobby", RaidProgression.ShouldRespawn(true, "LobbyPhase"), true)
expect("living player is not respawned in lobby", RaidProgression.ShouldRespawn(false, "LobbyPhase"), false)

local raids, streak = RaidProgression.ApplyOutcome(10, 0, true)
expect("successful raid increments total", raids, 11)
expect("first success starts streak", streak, 1)

raids, streak = RaidProgression.ApplyOutcome(11, 4, true)
expect("successful raid increments total again", raids, 12)
expect("streak caps at five", streak, 5)

raids, streak = RaidProgression.ApplyOutcome(12, 4, false)
expect("failed raid does not increment total", raids, 12)
expect("failed raid resets streak", streak, 0)

raids, streak = RaidProgression.ApplyOutcome(12, 5, true)
expect("success after cap still increments total", raids, 13)
expect("success after cap keeps streak capped", streak, 5)

print(string.format("RaidProgression: %d checks passed.", total))
