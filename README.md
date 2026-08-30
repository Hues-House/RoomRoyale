# Room Royale

Room Royale is a Roblox decorating competition built around a fast `Shop -> Style -> Judge` loop.

The game is currently documentation-first in this repository. The live Roblox place remains the source of truth for runtime behavior until Studio scripts are imported into the Rojo tree on purpose.

## Project layout

- `AGENTS.md` defines the product direction and player-facing tone.
- `CONTEXT.md` defines the project vocabulary.
- `default.project.json` maps the repository into Roblox services through Rojo.
- `src/` is the future source tree for Luau scripts and shared assets.
- `docs/` contains system maps and release-readiness records.
- `.scratch/issues/` contains the local Markdown backlog from the public-beta audit.
- `tools/validate-repo.ps1` checks the repository structure and builds the Rojo project.

The `rbxlx_extract/`, `rbxlx_extract_updated/`, and `_gdd_extract/` folders are local legacy references. Git ignores them because the audit marks the extracted scripts as stale.

## Roblox workflow

Install or make Rojo available on your `PATH`, then run the repository check:

```powershell
.\tools\validate-repo.ps1
```

To build a local place file from the current source tree, run:

```powershell
New-Item -ItemType Directory -Force build | Out-Null
rojo build default.project.json --output build\RoomRoyale.rbxlx
```

Open the generated place in Roblox Studio for local inspection. Do not publish or overwrite the live place until the device, multiplayer, and persistence gates in [the public-beta audit](docs/public-beta-readiness-audit-2026-08-30.md) pass.

## Read before changing game code

1. Read [AGENTS.md](AGENTS.md).
2. Read [CONTEXT.md](CONTEXT.md).
3. Read [the game systems map](docs/game_systems.md).
4. Read [the UI systems map](docs/ui_system.md) when a change touches player-facing interaction.
5. Check the matching issue in `.scratch/issues/` before starting work.

Keep server validation authoritative. Keep shop focus in one place. Keep cart capacity synchronized across the server and the two client displays.
