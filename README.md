# Catch Squishies

Roblox/Luau game built with Rojo, Pesde, Blink, Selene, and StyLua.

## Setup

```sh
sh scripts/setup.sh
```

## Common Commands

```sh
sh scripts/generate-network.sh
sh scripts/install-packages.sh
sh scripts/sourcemap.sh
sh scripts/serve.sh
sh scripts/check.sh
```

## Workflow

- Edit Blink files in `.config/blink/`, then run `sh scripts/generate-network.sh`.
- `network/`, `roblox_packages/`, and `sourcemap.json` are generated.
- Run `sh scripts/check.sh` before pushing.
