--!nolint BuiltinGlobalWrite
-- Deterministic tests for pure gameplay rules.
-- Run in CI with: lune run tests/RaidProgression.spec.luau

-- NightEvents defines a Color3 value for its rare loot at module load time.
-- This tiny stub keeps the pure event data testable outside Roblox.
if not Color3 then
    Color3 = {
        fromRGB = function(r, g, b)
            return { R = r, G = g, B = b }
        end,
    }
end

-- MapConfigs is data-only for these tests, but its module constructs Roblox
-- value types at load time. Provide minimal deterministic stand-ins.
if not Vector3 then
    Vector3 = {
        new = function(x, y, z)
            return { X = x, Y = y, Z = z }
        end,
    }
end

if not Enum then
    Enum = {
        Material = setmetatable({}, {
            __index = function(_, materialName)
                return materialName
            end,
        }),
    }
end

if not Random then
    Random = {
        new = function(_seed)
            return {
                NextInteger = function(_, minValue, _maxValue)
                    return minValue
                end,
            }
        end,
    }
end

if not game then
    game = {
        GetService = function(_, serviceName)
            if serviceName == "ReplicatedStorage" then
                return {
                    WaitForChild = function(_, childName)
                        if childName == "Shared" then
                            return {
                                WaitForChild = function(_, modName)
                                    if modName == "Locale" then
                                        return {
                                            Get = function(key) return key end,
                                            Format = function(key, ...) return key end,
                                        }
                                    end
                                    return {}
                                end
                            }
                        end
                        return {}
                    end
                }
            end
            return {}
        end
    }
end

-- Roblox accepts ModuleScript instances in require(), while Lune's require()
-- accepts module paths. Translate the mocked Locale ModuleScript to a tiny
-- deterministic implementation and delegate all string paths to native require.
local nativeRequire = require
require = function(module)
    if type(module) == "table" then
        return {
            Get = function(key) return key end,
            Format = function(key, ...) return key end,
        }
    end

    return nativeRequire(module)
end

local RaidProgression = require("../src/shared/RaidProgression")
local LootLogic = require("../src/shared/LootLogic")
local NightEvents = require("../src/shared/NightEvents")
local MapConfigs = require("../src/shared/MapConfigs")
local CosmeticsConfig = require("../src/shared/CosmeticsConfig")
local ContractService = require("../src/shared/ContractService")

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

expect("dead player respawns during loot phase", RaidProgression.ShouldRespawn(true, "LootPhase"), true)
expect("dead player respawns during extraction phase", RaidProgression.ShouldRespawn(true, "ExtractionPhase"), true)
expect("dead player respawns in lobby", RaidProgression.ShouldRespawn(true, "LobbyPhase"), true)
expect("living player is not respawned", RaidProgression.ShouldRespawn(false, "LootPhase"), false)
expect("death during loot phase eliminates player", RaidProgression.ShouldEliminate("LootPhase"), true)
expect("death during extraction eliminates player", RaidProgression.ShouldEliminate("ExtractionPhase"), true)
expect("death in lobby does not eliminate player", RaidProgression.ShouldEliminate("LobbyPhase"), false)

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
expect("edge roll 0.0 picks first event (Blackout)", NightEvents.Pick(0.0).Id, "Blackout")
expect("Blackout is selected at low roll", NightEvents.Pick(0.1).Id, "Blackout")
expect("Red Alert is selected at middle roll", NightEvents.Pick(0.3).Id, "RedAlert")
expect("Jackpot is selected at jackpot roll", NightEvents.Pick(0.4).Id, "Jackpot")
expect("Calm is selected at high roll", NightEvents.Pick(0.6).Id, "Calm")
expect("edge roll 0.999999 picks last event (ThickFog)", NightEvents.Pick(0.999999).Id, "ThickFog")
expect("negative roll is clamped to Blackout", NightEvents.Pick(-1.0).Id, "Blackout")
expect("roll exceeding 1.0 is clamped to ThickFog", NightEvents.Pick(2.5).Id, "ThickFog")
local jackpotEvent = NightEvents.Pick(0.4)
local jackpotItem = jackpotEvent.JackpotLoot
expect("Jackpot contains golden crown id", jackpotItem and jackpotItem.Id, "Crown")
expect("Blackout enables darkness", NightEvents.Pick(0.1).Darkness, true)
expect("Calm does not enable darkness", NightEvents.Pick(0.6).Darkness, false)

local awareness = {
    ViewDistance = 55,
    FovDotThreshold = 0.35,
    PatrolSpeed = 13.5,
    SearchSpeed = 16,
    InvestigateSpeed = 16,
}
local blackout = NightEvents.ApplyToAwareness(awareness, NightEvents.Pick(0.1))
expect("Blackout reduces guard view distance", blackout.ViewDistance, 38.5)
local redAlert = NightEvents.ApplyToAwareness(awareness, NightEvents.Pick(0.3))
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

-- Walk speed curve based on inventory weight ratio.
expect("empty inventory gives base walk speed", LootLogic.CalculateWalkSpeed(0, 20, 16, 8), 16)
expect("half-filled backpack gives half speed penalty", LootLogic.CalculateWalkSpeed(10, 20, 16, 8), 12)
expect("full backpack gives minimum walk speed", LootLogic.CalculateWalkSpeed(20, 20, 16, 8), 8)
expect("overfilled backpack does not drop below minimum speed", LootLogic.CalculateWalkSpeed(30, 20, 16, 8), 8)

-- Fall damage and fragile items breaking.
local testPack = {
    { Name = "Watch", Weight = 1.5, Value = 150, Fragile = false },
    { Name = "Vase", Weight = 4.0, Value = 550, Fragile = true },
    { Name = "Ingot", Weight = 8.0, Value = 450, Fragile = false },
}
local safeRem, safeBroken = LootLogic.ProcessFallDamage(testPack, 10, 14)
expect("safe fall does not break fragile loot", #safeBroken, 0)
expect("safe fall retains all items", #safeRem, 3)

local hardRem, hardBroken, newW, newV = LootLogic.ProcessFallDamage(testPack, 18, 14)
expect("fall above threshold breaks fragile item", #hardBroken, 1)
expect("non-fragile items are retained", #hardRem, 2)
expect("weight is recalculated after break", newW, 9.5)
expect("value is recalculated after break", newV, 600)

-- Upgrade costs and purchases.
expect("base upgrade cost at level 0", LootLogic.GetUpgradeCost("Pockets", 0), 500)
expect("upgrade cost at max level is nil", LootLogic.GetUpgradeCost("Pockets", 3), nil)

local canBuy, newCash, newLvl = LootLogic.CanPurchaseUpgrade(1000, "Pockets", 0)
expect("can purchase upgrade with sufficient funds", canBuy, true)
expect("cash deducted accurately", newCash, 500)
expect("level incremented by 1", newLvl, 1)

local failBuy, unchCash = LootLogic.CanPurchaseUpgrade(200, "Pockets", 0)
expect("cannot purchase upgrade with insufficient funds", failBuy, false)
expect("cash left untouched upon rejection", unchCash, 200)

expect("effective max weight includes upgrade bonus", LootLogic.GetEffectiveMaxWeight(25, 2), 35)
expect("effective flashlight range includes battery bonus", LootLogic.GetEffectiveFlashlightRange(75, 1), 90)

-- Phase 1: Data-driven maps checks
local maps = MapConfigs.GetMapList()
expect("three maps configured in data-driven system", #maps, 3)
expect("warehouse map exists", MapConfigs.Get("Warehouse").Id, "Warehouse")
expect("archive vault map exists", MapConfigs.Get("Archive").Id, "Archive")
expect("cargo docks map exists", MapConfigs.Get("Docks").Id, "Docks")
expect("archive map has keycard spawns", #MapConfigs.Get("Archive").KeycardSpawns > 0, true)
expect("cargo docks has vertical crane beams", #MapConfigs.Get("Docks").Beams > 0, true)

-- Cosmetics catalog checks
expect("cosmetics catalog contains items", #CosmeticsConfig.Items >= 4, true)
expect("balaclava mask exists", CosmeticsConfig.GetItem("Balaclava") ~= nil, true)
expect("oni cyber mask exists", CosmeticsConfig.GetItem("OniCyber") ~= nil, true)
expect("neon grapple skin exists", CosmeticsConfig.GetItem("NeonGrapple") ~= nil, true)

-- Daily contracts checks
local dayNum = ContractService.GetDayNumber()
expect("day number is valid positive integer", dayNum > 0, true)
local contracts = ContractService.GetDailyContracts()
expect("daily contracts returns 3 entries", #contracts, 3)
expect("first contract has reward", contracts[1].RewardCash > 0, true)
expect("first contract has target", contracts[1].TargetAmount > 0, true)

print(string.format("Gameplay unit tests: %d checks, %d failures.", total, #failures))
if #failures > 0 then
    error(table.concat(failures, "\n"))
end
