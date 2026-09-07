# Room Royale

Room Royale is a Roblox decorating competition built around a fast `Shop -> Style -> Judge` loop.

The active Luau source from the `Room Royale - Test` place is managed in this repository through Rojo. The Studio place still owns map geometry, terrain, models, and other instances that have not been imported yet.

`docs/studio-source-manifest.json` records the Studio baseline used for the import, and `docs/studio-source-capture-2026-09-06.json` preserves the matching 57-script Studio inventory. Run both source verifiers before syncing repository changes back into Studio.

## Project layout

- `AGENTS.md` defines the product direction and player-facing tone.
- `CONTEXT.md` defines the project vocabulary.
- `default.project.json` maps the repository into Roblox services through Rojo.
- `src/` contains the managed Luau scripts and is the source of truth for script changes.
- `docs/` contains system maps and release-readiness records.
- `.scratch/issues/` contains the local Markdown backlog from the public-beta audit.
- `tools/validate-repo.ps1` checks the repository structure and builds the Rojo project.
- `tools/Verify-StudioSourceManifest.ps1` checks the imported files against the captured Studio baseline.
- `tools/Verify-RojoBuild.ps1` proves that a fresh Rojo build preserves script paths, classes, disabled states, and source.

The `rbxlx_extract/`, `rbxlx_extract_updated/`, and `_gdd_extract/` folders are local legacy references. Git ignores them because the verified `src/` tree has replaced those stale extracts.

## Roblox workflow

Install or make Rojo available on your `PATH`. The repository tools require PowerShell 7 or newer (`pwsh`). Run the repository check:

```powershell
pwsh -NoProfile -File .\tools\validate-repo.ps1
```

Verify the imported source boundary:

```powershell
pwsh -NoProfile -File .\tools\Verify-StudioSourceManifest.ps1
pwsh -NoProfile -File .\tools\Verify-RojoBuild.ps1
```

To build a local place file from the current source tree, run:

```powershell
New-Item -ItemType Directory -Force build | Out-Null
rojo build default.project.json --output build\RoomRoyale.rbxlx
```

Open the generated place in Roblox Studio for local inspection. Rojo live sync is restricted to test PlaceId `86511797738570`. Do not publish or overwrite the live place until the device, multiplayer, and persistence gates in [the public-beta audit](docs/public-beta-readiness-audit-2026-08-30.md) pass.

## Read before changing game code

1. Read [AGENTS.md](AGENTS.md).
2. Read [CONTEXT.md](CONTEXT.md).
3. Read [the game systems map](docs/game_systems.md).
4. Read [the UI systems map](docs/ui_system.md) when a change touches player-facing interaction.
5. Check the matching issue in `.scratch/issues/` before starting work.

Keep server validation authoritative. Keep shop focus in one place. Keep cart capacity synchronized across the server and the two client displays.
