-- Deterministic tests for pure gameplay rules.
-- Run in CI with: lune run tests/RaidProgression.spec.luau

-- NightEvents defines a Color3 value for its rare loot at module load time.
-- This tiny stub keeps the pure event data testable outside Roblox.
Color3 = {
    fromRGB = function(r, g, b)
        return { R = r, G = g, B = b }
    end,
}

local RaidProgression = require("../src/shared/RaidProgression")
local LootLogic = require("../src/shared/LootLogic")
local NightEvents = require("../src/shared/NightEvents")

local total = 0
local failures = {}

local function expect(name, actual, expected)
    total += 1
    if actual ~= expected then
        table.insert(failures, string.format(
            "[FAIL] %s: expected %s, got %s",
            name,
            tostring(expected),
            tostring(actual)
        ))
        return
    end
    print(string.format("[PASS] %s", name))
end

local function expectNear(name, actual, expected, tolerance)
    total += 1
    if math.abs(actual - expected) > tolerance then
        table.insert(failures, string.format(
            "[FAIL] %s: expected approximately %s, got %s",
            name,
            tostring(expected),
            tostring(actual)
        ))
        return
    end
    print(string.format("[PASS] %s", name))
end

-- Raid progression and safe persisted-stat normalization.
local normalized = RaidProgression.NormalizeStats(12.9, 7)
expect("stats floor raid count", normalized.Raids, 12)
expect("stats clamp streak to five", normalized.Streak, 5)

normalized = RaidProgression.NormalizeStats(-10, -2)
expect("negative raid count clamps to zero", normalized.Raids, 0)
expect("negative streak clamps to zero", normalized.Streak, 0)

normalized = RaidProgression.NormalizeStats("bad", math.huge)
expect("invalid raid count uses safe default", normalized.Raids, 0)
expect("infinite streak uses safe default", normalized.Streak, 0)

-- Death-drop and respawn decisions used by the server.
expect("loot drops during loot phase", RaidProgression.ShouldDropLoot("LootPhase", false, 2), true)
expect("loot drops during extraction phase", RaidProgression.ShouldDropLoot("ExtractionPhase", false, 1), true)
expect("no loot drops in lobby", RaidProgression.ShouldDropLoot("LobbyPhase", false, 2), false)
expect("escaped player does not drop loot", RaidProgression.ShouldDropLoot("ExtractionPhase", true, 2), false)
expect("empty inventory does not create a drop", RaidProgression.ShouldDropLoot("LootPhase", false, 0), false)

expect("dead player waits during loot phase", RaidProgression.ShouldRespawn(true, "LootPhase"), false)
expect("dead player waits during extraction phase", RaidProgression.ShouldRespawn(true, "ExtractionPhase"), false)
expect("dead player can respawn in lobby", RaidProgression.ShouldRespawn(true, "LobbyPhase"), true)
expect("living player is not respawned in lobby", RaidProgression.ShouldRespawn(false, "LobbyPhase"), false)

-- Raid outcomes and streak boundaries.
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

raids, streak = RaidProgression.ApplyOutcome(2000000000, 5, true)
expect("raid count does not overflow configured cap", raids, 2000000000)

-- Existing payout functions: first success has no prior-streak bonus.
expect("streak zero gives no bonus", LootLogic.GetStreakBonusPercent(0), 0)
expect("one prior success gives ten percent", LootLogic.GetStreakBonusPercent(1), 10)
expect("five prior successes cap at fifty percent", LootLogic.GetStreakBonusPercent(5), 50)
expect("streak above cap remains fifty percent", LootLogic.GetStreakBonusPercent(9), 50)
expect("payout applies prior streak bonus", LootLogic.ApplyStreakBonus(1000, 3), 1300)
expect("payout rounds down", LootLogic.ApplyStreakBonus(155, 1), 170)

-- Weighted night-event selection and event modifiers.
expect("Blackout is selected at low roll", NightEvents.Pick(0.1).Id, "Blackout")
expect("Red Alert is selected at middle roll", NightEvents.Pick(0.4).Id, "RedAlert")
expect("Jackpot is selected at jackpot roll", NightEvents.Pick(0.6).Id, "Jackpot")
expect("Calm is selected at high roll", NightEvents.Pick(0.9).Id, "Calm")
expect("Jackpot contains golden crown", NightEvents.Pick(0.6).JackpotLoot.Name, "Золотая корона")
expect("Blackout enables darkness", NightEvents.Pick(0.1).Darkness, true)
expect("Calm does not enable darkness", NightEvents.Pick(0.9).Darkness, false)

local awareness = {
    ViewDistance = 55,
    FovDotThreshold = 0.35,
    PatrolSpeed = 13.5,
    SearchSpeed = 16,
    InvestigateSpeed = 16,
}
local blackout = NightEvents.ApplyToAwareness(awareness, NightEvents.Pick(0.1))
expect("Blackout reduces guard view distance", blackout.ViewDistance, 38.5)
local redAlert = NightEvents.ApplyToAwareness(awareness, NightEvents.Pick(0.4))
expect("Red Alert increases guard view distance", redAlert.ViewDistance, 66)
expectNear("Red Alert increases patrol speed", redAlert.PatrolSpeed, 14.85, 0.000001)

local loot = { Name = "Test loot", Value = 100, Weight = 2, Fragile = false }
local scaledLoot = NightEvents.ScaleLootValue(loot, 1.5)
expect("event multiplier scales loot value", scaledLoot.Value, 150)
expect("event multiplier preserves loot weight", scaledLoot.Weight, 2)
expect("scaling does not mutate source loot", loot.Value, 100)

-- Inventory boundary checks used by the existing gameplay code.
expect("item fits exactly into inventory", LootLogic.CanAddItem(20, 5, 25), true)
expect("item exceeding inventory is rejected", LootLogic.CanAddItem(24, 2, 25), false)

print(string.format("Gameplay unit tests: %d checks, %d failures.", total, #failures))
if #failures > 0 then
    error(table.concat(failures, "\n"))
end
