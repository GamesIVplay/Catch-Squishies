# Agent Workflow

- Roblox/Luau repo using Rojo, Pesde, Blink, Selene, and StyLua.
- Do not edit `src/` gameplay code unless user explicitly asks.
- Edit networking in `.config/blink/`; generated output goes in `network/`.
- Prefer `sh scripts/check.sh` before handoff.
- Use `sh scripts/setup.sh` for first-time setup.
- Use `sh scripts/serve.sh` for Studio sync.
- Keep changes narrow. Do not delete generated or user files unless asked.

- Buy effect: `src/Client/Modules/BuyEffect.luau`
- Collect effect: `src/Client/Modules/CollectEffect.luau`
- Minigame click effect: `src/Client/Modules/MinigameClickEffect.luau`

Networking:

- Buy effects replicate for plot upgrades, not local-only shop purchases.
- Collect effects replicate for plot cash collection.
- Lasso shop purchase effects should remain local-only unless the user says otherwise.

## Cmdr/admin commands

Important files:

- Cmdr server boot: `src/Server/Scripts/Cmdr.server.luau`
- Commands: `src/Server/Cmdr/Commands`
- Types: `src/Server/Cmdr/Types`
- Shared command helpers: `src/Server/Cmdr/Util.luau`

Current custom commands include cash, lasso, plot-area, and squishy helpers. Keep command names camelCase, for example:

- `addCash`
- `removeCash`
- `setCash`
- `addLasso`
- `giveSquishy`
- `getSquishies`
- `resetAreas`
- `unlockAreas`

`giveSquishy` gives one configured squishy. `getSquishies` is an admin bulk grant that gives all configured squishies to the target player.

## Data/profile

Important files:

- Profile schema/migrations: `src/Server/Modules/Profile.luau`
- Load/save to ECS components: `src/Server/Systems/PlayerSession.luau`
- Component definitions: `src/Shared/Components.luau`
- Server-to-client replication: `src/Server/Systems/Data_Sender.luau`

Rules:

- Add new persistent fields to `ProfileData`, template, migration, PlayerSession mapping, component definitions, and replication if needed.
- Normalize old data defensively. Live player data may have older shapes.
- Use existing component replication instead of adding one-off remotes when possible.
- `Data_Sender` normalizes and compares replicated components on `Phases.Runservice.Last`. Large table components like owned squishies, owned food, hotbar, index, and event state can become a server cost center.
- For frequent small changes, prefer dirty/versioned component updates or narrow remotes over repeatedly deep-copying full tables.

## Number formatting

Use `Util.Abbreviate_Number(value, 1)` for scripted display numbers unless the user explicitly wants a different format. Shared helpers like `InventoryMath.FormatIncome` and `InventoryMath.FormatWeightKg` should be preferred over duplicating formatting.

## Common pitfalls

- Do not make lasso physics constraints pull the player.
- Do not hand-edit generated network files.
- Do not add more huge local/function blocks to already large client systems if a small module is cleaner.
- Do not update UI by relying on runtime-only state if persistent server data should be authoritative.
- Do not break protected hotbar slots `1-3`.
- Do not make prompts visible to non-owners.
- Do not use squishy/character parts in map-only raycasts.
- Do not hide visuals by only changing parent UI text; hide the containing frame/object when the UI has a frame for that field.
- Do not remove throttles/LOD/caches to make behavior simpler.
- Do not put recursive instance searches, cloning, or animation loading inside a frame loop.
- Do not add full-array replication for one-item inventory, plot, or index updates without checking bandwidth and server copy cost.
