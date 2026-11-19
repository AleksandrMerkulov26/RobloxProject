# NightRaid Architecture & Development Guidelines

## Project Structure
NightRaid is a stealth heist-and-extraction game for Roblox managed via Rojo.

```
src/
├── client/
│   └── init.client.luau      -- LocalPlayer HUD, input (grapple, flashlight, smoke, taser), UI modals
├── server/
│   ├── init.server.luau      -- Lightweight bootstrap script
│   ├── Remotes.luau          -- Central registry for all RemoteEvents and RemoteFunctions
│   ├── DataService.luau      -- Player data persistence (DataStore, safe retries, locks)
│   ├── LootService.luau      -- World loot spawn, inventory sync, drop, fall damage
│   ├── GuardAI.luau          -- Guard NPC lifecycle, state machine, patrol, detection, taser stun
│   ├── LoadoutService.luau   -- Player kits/loadouts selection and validation
│   ├── UpgradeService.luau   -- Black market upgrades and dealer station logic
│   ├── RoundController.luau  -- Game loop (Lobby -> Loot -> Extraction) & night events
│   ├── HideoutBuilder.luau   -- Personal underground player hideouts & stations
│   └── MapBuilder.luau       -- Facility layout & map generation
└── shared/
    ├── Config.luau           -- Game timings, initial loadouts, loot tables
    ├── LootLogic.luau        -- Pure calculation helpers (speed, detection, upgrades, streak)
    ├── NightEvents.luau      -- Raid modifiers & events
    ├── RaidProgression.luau  -- Pure stats normalization & round outcomes
    └── Locale.luau           -- Localization dictionaries (RU/EN) [Planned in Task 0.2]
```

## Core Rules & Conventions
1. **Never trust the client**:
   - Every `RemoteEvent` and `RemoteFunction` must validate caller identity, player state (alive, not eliminated), current round phase, action cooldowns, and argument types/bounds.
2. **Luau Style**:
   - Use strict typing where practical.
   - Keep module dependencies clean without circular references.
   - Do not mix direct Roblox world manipulation with pure testable logic.
3. **One task per session**:
   - Keep changes modular and verified.
4. **Data Safety**:
   - Guard DataStore against overlapping writes per player.
   - Never overwrite loaded data with defaults upon transient read failures.
