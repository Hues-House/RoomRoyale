# Room Royale

Room Royale is a Roblox decorating competition with a permanent neighborhood. The round is `Shop -> Style -> Judge -> Results`. Houses, furniture purchases, and rides give players longer-term goals between rounds.

The repository is [Hues-House/RoomRoyale](https://github.com/Hues-House/RoomRoyale). Start with the status below before reviewing or changing the game.

## Open the saved places

- [RoomRoyale-Test.rbxlx](places/RoomRoyale-Test.rbxlx) is the complete main Test scene, including Studio-owned maps and assets. The main Test place was also saved to Roblox, PlaceId `86511797738570`, GameId `10764620924`.
- [RoomRoyale-Hillside.rbxlx](places/RoomRoyale-Hillside.rbxlx) is the saved standalone Hillside cart-refinement candidate. Open it in Studio and press Play to test the market, camera-relative driving, stacked cargo, and pump park.

Hillside remains a local prototype. The [milestone 1 report](docs/cart-refinement-m1-2026-09-08.md) records the candidate, source comparisons, desktop evidence, and remaining acceptance. No Live version was published.

## Current state

| Work | What exists | Source |
| --- | --- | --- |
| Main Test game | Eight cottage lots, working house doors, saved house furniture, purchase pedestals, and complete decorating rounds for separate player cohorts. It still uses the older showroom and cart. | [src](src/README.md), [neighborhood report](docs/neighborhood-build-2026-09-07.md) |
| Hillside cart-refinement candidate | Camera-relative steering, separate Drift input, animated capacity and nearby-piece fit feedback, stronger load effects, and jump-boing removal build on the v4 market, stacked furniture, jumps, dive, checkout, and park. Its shopping session still ends with a demonstration collection. | [Milestone 1 report](docs/cart-refinement-m1-2026-09-08.md), [cart runtime](prototype/cart-lab), [ride runtime](packages/RideRuntime) |
| Approved next work | Full round integration, furniture quantities and purchase pacing, earned designs, player-led judging, and an owned skateboard with a megaramp. | [Refinement plan](docs/refinement-plan-2026-09-08.md), [round-integration draft](docs/round-integration-implementation-brief-2026-09-08.md) |

Milestone 1 has an implemented local candidate with desktop and engine evidence. Phone/controller acceptance and the remaining cargo check are still open. Milestones 2-5 remain unimplemented. Hillside is separate from the main Test game; the complete game still uses its older cart and showroom.

## Read the project

1. [AGENTS.md](AGENTS.md) defines how to work on the current game.
2. [The refinement plan](docs/refinement-plan-2026-09-08.md) records accepted decisions, implementation gaps, and acceptance criteria.
3. [Game systems](docs/game_systems.md) and [UI systems](docs/ui_system.md) map behavior to its owning source.
4. [The documentation index](docs/README.md) links the current evidence and asset workflows.

[CONTEXT.md](CONTEXT.md) defines terms. [The writing guide](docs/writing_guide.md) defines player-facing language. Code records implemented behavior; the refinement plan records intended behavior where the two differ.

## Build and inspect

Use PowerShell 7 and the [Rojo CLI](https://rojo.space/docs/v7/getting-started/installation/) on `PATH`. Prototype checks also need `luau` and `luau-compile` from the [official Luau 0.737 release](https://github.com/luau-lang/luau/releases/tag/0.737). The verified toolchain is Rojo 7.6.1 and Luau 0.737.

The main project maps managed scripts into the Test place. A fresh `default.project.json` build contains the managed scripts. Open the saved Test snapshot above for the complete scene and its Studio-owned models, map instances, and terrain.

```powershell
pwsh -NoProfile -File .\tools\validate-repo.ps1
pwsh -NoProfile -File .\tools\Verify-RojoBuild.ps1
```

Compare both complete place snapshots with fresh Rojo builds using Python 3 and its standard library:

```powershell
python tools/Verify-PlaceSnapshots.py
```

Build and open the standalone Hillside playtest with:

```powershell
pwsh -NoProfile -File .\tools\Start-HillsidePlaytest.ps1
```

Add `-BuildOnly` to check and build without opening Studio. If Luau is outside `PATH`, add `-LuauDirectory 'C:\tools\luau'` with the directory containing both executables. The resolver checks that argument first, then `PATH`, then the optional local `.scratch/generated/luau` directory.

The generated output is `build/superstore/RoomRoyale-Hillside-M1-Candidate.rbxlx`. The [cart lab guide](docs/cart-lab.md) covers the smaller movement test course and its checks. [Verification](docs/verification.md) records current evidence and remaining device, multiplayer, persistence, and asset acceptance.

## Source and assets

| Path | Responsibility |
| --- | --- |
| `src/` | Main Test game's managed Luau source |
| `packages/RideRuntime/` | Shared prototype chassis, tuning, and gesture rules |
| `prototype/cart-lab/` | Prototype cart, cargo, crash, feedback, and shopping-session systems |
| `prototype/superstore/` | Hillside market, park, and session presentation |
| `places/` | Complete saved Studio scenes for the main Test game and Hillside prototype |
| `authoring/` | Editable furniture and cart assets, generators, and Studio installers |
| `tests/` and `tools/` | Build checks and repeatable acceptance drivers |
| `docs/evidence/` | Captured results supporting the current reports |
| `build/` | Ignored generated places, recordings, and local working artifacts |

Both prototype projects map their shared modules directly from `packages/RideRuntime/` and `prototype/cart-lab/`. Save source changes and corresponding Studio changes together, then compare the saved places. Saving locally, saving to Roblox, and publishing a Live version are distinct results.
