-- Studio-side smoke tests for the pure raid progression rules.
-- These run inside Roblox Studio's server test place, not in headless CI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RaidProgression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RaidProgression"))

local checks = {
    { "dead player respawns during raid", RaidProgression.ShouldRespawn(true, "LootPhase"), true },
    { "dead player respawns during extraction", RaidProgression.ShouldRespawn(true, "ExtractionPhase"), true },
    { "death during raid marks player eliminated", RaidProgression.ShouldEliminate("LootPhase"), true },
    { "death in lobby does not mark player eliminated", RaidProgression.ShouldEliminate("LobbyPhase"), false },
    { "dead player respawns in lobby", RaidProgression.ShouldRespawn(true, "LobbyPhase"), true },
    { "living player is not respawned", RaidProgression.ShouldRespawn(false, "LobbyPhase"), false },
    { "loot drops during active loot phase", RaidProgression.ShouldDropLoot("LootPhase", false, 1), true },
    { "escaped player keeps loot", RaidProgression.ShouldDropLoot("ExtractionPhase", true, 1), false },
    { "empty inventory creates no drop", RaidProgression.ShouldDropLoot("LootPhase", false, 0), false },
}

local passed = 0
for _, check in ipairs(checks) do
    local name, actual, expected = check[1], check[2], check[3]
    if actual == expected then
        passed += 1
        print("[PASS][RaidProgression] " .. name)
    else
        error(string.format("[FAIL][RaidProgression] %s: expected %s, got %s", name, tostring(expected), tostring(actual)))
    end
end

print(string.format("[RaidProgression] Studio smoke tests passed: %d/%d", passed, #checks))
