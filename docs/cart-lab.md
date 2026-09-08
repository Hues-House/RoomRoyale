# Cart lab

The cart lab is an isolated movement test course. It uses the same cart and ride modules as the Hillside milestone-1 candidate, with a smaller course for repeatable handling, cargo, and crash checks. It contains no main-game round scripts or player DataStores.

For the current market and pump park, open [RoomRoyale-Hillside.rbxlx](../places/RoomRoyale-Hillside.rbxlx). [The milestone-1 report](cart-refinement-m1-2026-09-08.md) records the current candidate and remaining acceptance. [The v4 report](playtest-iteration-v4-2026-09-08.md) records the earlier baseline. The [refinement plan](refinement-plan-2026-09-08.md) contains the accepted implementation sequence.

## Install and build

Use PowerShell 7, the [Rojo CLI](https://rojo.space/docs/v7/getting-started/installation/), and the two CLI executables from the [official Luau 0.737 release](https://github.com/luau-lang/luau/releases/tag/0.737). The verified toolchain is Rojo 7.6.1 and Luau 0.737. Studio is needed to play a built place.

Add `rojo` to `PATH`. For Luau, either add both `luau` and `luau-compile` to `PATH` or pass their directory:

```powershell
pwsh -NoProfile -File tools/Build-CartLab.ps1 -LuauDirectory 'C:\tools\luau'
```

Replace that example directory with the location of both executables. `tools/Resolve-Luau.ps1` uses an explicit directory first, then `PATH`, then the optional local `.scratch/generated/luau` directory. The ignored local fallback is not required on a fresh checkout.

The build runs the gesture suite, compiles the lab source, and writes `build/RoomRoyale-CartLab.rbxlx`. Open that file in Studio and press Play.

Build the complete Hillside prototype without opening another Studio window with:

```powershell
pwsh -NoProfile -File tools/Start-HillsidePlaytest.ps1 -BuildOnly -LuauDirectory 'C:\tools\luau'
```

The Hillside build also runs camera-direction, pickup-capacity and shopping-session rules and compiles its store and park modules. Its generated output is `build/superstore/RoomRoyale-Hillside-M1-Candidate.rbxlx`.

## Current controls

| Action | Keyboard and mouse | Gamepad | Touch |
| --- | --- | --- | --- |
| Drive and steer | WASD | Left stick | Movement stick |
| Orbit camera | Right mouse drag | Right stick | Right-side drag |
| Charge jump or dive | Space | R1 or A | JUMP |
| Drift | Ctrl | L1 | DRIFT |
| Brake | Left Shift | L2 | BRAKE |
| Grab nearby piece | E | X | GRAB |
| Return to start | R | Y | RESET |

Hold JUMP to charge and release to launch, including while steering. DRIFT selects the separate hop-and-drift action; release spends earned boost. A new JUMP press in the air holds a dive, and release returns to float.

The charge takes 0.35 seconds to fill. The candidate preserves v4's charged jumps, reduced air gravity, and airborne dive. Movement follows the horizontal camera heading; looking while stationary supplies no drive input. The spring jump cue is removed. Physical-device camera feel remains unverified.

## What to exercise

1. Drive the same course empty and with a sofa, table, and chair. Those example pieces use 97 of 100 cart space. Compare acceleration, braking, and support at slope transitions.
2. Charge a jump, turn after starting the charge, and release. Re-press in the air to dive. Confirm that landing restores the riding pose.
3. Start a drift while moving and release its earned boost. Brake, open a menu, or lose focus to exercise action cancellation.
4. Grab pieces, inspect their recognizable stacks, and drive through checkout. Cargo space clears and the delivered collection preserves the pieces' identity and variant.
5. Hit the marked wall with a committed approach. The rider ejects, the cart stays supported, and recovery preserves cargo. Test gentle contact and glancing scrapes separately.
6. With another client, exercise a decisive ram, protection during recovery, and ownership of both carts.

The lab begins in free play. During a running lab server, `ServerStorage.StartCartLabRound:Invoke(45)` starts a short timed shopping fixture. Shop closes before the checkout grace ends, then settlement produces the demonstration Style collection. This does not start the main game's styling or judging systems.

## Checks and evidence

The current pure gesture suite passes 25 scenarios. Camera-direction checks cover movement headings, reverse, pitch and rest. Pickup rules include 10,201 capacity comparisons against session admission. The shopping-session suite checks phase deadlines, capacity, settlement, and exported identity. Run the crash source replay separately:

```powershell
pwsh -NoProfile -File tests/ride/Run-CrashReplay.ps1 -LuauDirectory 'C:\tools\luau'
```

The current replay passes 14 scenarios. These checks exercise rules without simulating Roblox physics.

Engine acceptance modules live in `tests/ride/` and `tests/superstore/`. They cover actual chassis handling, crashes, stacked cargo, park geometry, and park traversal. The [milestone-1 report](cart-refinement-m1-2026-09-08.md) records current physics and desktop evidence, plus the interrupted phone run and outstanding cargo-suite rerun. Earlier setup and results are in the [handling report](cart-playtest-handling-2026-09-08.md), [cargo report](cart-playtest-cargo-2026-09-08.md), and [Hillside report](playtest-iteration-v4-2026-09-08.md). Source compilation does not replace those engine checks.

Actual touch, gamepad, mouse feel, phone performance, and the complete integrated round remain subject to [current acceptance](verification.md). The avatar presentation targets R15. R6 presentation has not been implemented.

## Source ownership

`packages/RideRuntime/` owns `CameraDirection`, `Chassis`, `Gesture`, and `Profiles`. `prototype/cart-lab/` owns the cart server, input, `Shopping` HUD, `PickupRules`, cargo, crash, audio, rider pose, and presentation modules. Both prototype projects reference these canonical files directly. The cart's editable Blender and GLB sources are described in [the flatbed guide](../authoring/cart-flatbed/README.md).

`default.project.json` still uses the main game's older cart. Integration must carry completed checkout records into the real Style inventory while keeping each round's collection and result isolated.
