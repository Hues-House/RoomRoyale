# Verification and remaining acceptance

This is the current verification entry point. It carries forward unresolved device, multiplayer, persistence, new-player, and asset checks from the earlier release audit. Older symptoms are not assumed to remain unchanged: some fixes now exist in source, while current end-to-end evidence is still required.

Saving Studio work and syncing GitHub preserve the build. Those actions do not establish release readiness or completion of the [approved refinement plan](refinement-plan-2026-09-08.md).

## Saved state and repeatable checks

The complete main scene is [RoomRoyale-Test.rbxlx](../places/RoomRoyale-Test.rbxlx). The main Test was also saved to Roblox, PlaceId `86511797738570`, GameId `10764620924`. The separate [Hillside scene](../places/RoomRoyale-Hillside.rbxlx) remains a local prototype. No Live publication occurred during this sync.

The [current saved-place report](evidence/cart-refinement-m1/snapshot-verification.json) records snapshot hashes and managed-script comparisons with fresh Rojo builds: 54 main and 30 Hillside scripts, with zero mismatches. Additional scripts preserved in a scene are listed separately; they are not silently treated as managed source. The earlier [Studio sync report](evidence/studio-repo-sync.json) records the pre-refinement snapshots.

Run the repository and snapshot checks from the root:

```powershell
pwsh -NoProfile -File tools/validate-repo.ps1
pwsh -NoProfile -File tools/Verify-RojoBuild.ps1
python tools/Verify-PlaceSnapshots.py
pwsh -NoProfile -File tools/Start-HillsidePlaytest.ps1 -BuildOnly
pwsh -NoProfile -File tests/ride/Run-CrashReplay.ps1
```

These commands require PowerShell 7, Rojo, Python 3, and the Luau CLI tools. [The cart lab guide](cart-lab.md) gives installation links and the `-LuauDirectory` option. The tested toolchain is Rojo 7.6.1 and Luau 0.737. Snapshot verification uses only the Python standard library and Rojo.

Current pure checks cover 25 explicit-intent gesture scenarios, camera direction, 10,201 capacity comparisons, shopping-session rules, and 14 crash replay scenarios. Compilation and packaging checks cover the main and prototype source. They do not simulate Roblox physics or prove device usability.

The [milestone-1 candidate report](cart-refinement-m1-2026-09-08.md) adds 33 real-physics checks and desktop ScreenGui pickup/checkout evidence. Phone capture, physical-device feel, live cancellation checks, and the repaired cargo-suite rerun remain open because computer use was stopped.

## Current engine evidence

| Evidence | What it establishes | What it leaves open |
| --- | --- | --- |
| [Cart milestone 1](cart-refinement-m1-2026-09-08.md) | Camera-relative chassis direction, explicit drift, empty/full physics comparison, and desktop pickup/checkout HUD | Phone/controller/mouse feel, client cancellations, repaired cargo suite, and live wall recovery |
| [Neighborhood build](neighborhood-build-2026-09-07.md) | Cottage geometry, doors, lot reservation and restoration, supported house placement, and saved coordinates | Eight simultaneous networked clients, a live delayed-profile disconnect, and all catalog pivot conventions |
| [Hillside v4](playtest-iteration-v4-2026-09-08.md) | Market navigation, item routes, current cargo and checkout, pump-loop surfaces, and actual movement recordings | Main-game integration, device feel, phone performance, and subjective sound quality |
| [Handling](cart-playtest-handling-2026-09-08.md) | Chassis jump comparison, wall impact and recovery, dive, and pose restoration | Full device and network conditions |
| [Cargo](cart-playtest-cargo-2026-09-08.md) | Exact-model stacks, variant export, pickup rules, and finite stock | Actual main Style inventory consumption after integration |

The v4 video capture omits ScreenGui HUD. It cannot establish HUD readability. Some prototype checks use a server-owned chassis or staged pickup positions; their reports state those conditions.

## Device and UI acceptance

Run the complete player flow on desktop, a narrow landscape phone, a tablet, and Xbox or a controller. Existing reference viewports include 874 by 402 for the phone and 1376 by 1032 for the tablet. Physical-device input and performance checks supplement Studio presets.

- Enter and leave the queue using the device's normal input.
- Keep controller focus on a visible, selectable control through every phase. Confirm and back must work during styling and judging without a mouse.
- Update prompts when the active input device changes. A touch-capable device with a keyboard attached must still expose usable touch actions.
- Keep interactive controls within the usable screen area and clear of the Roblox top bar. Check the banner, placement controls, prompts, inventory, votes, and results together.
- Fit all inventory contents and preserve selection and drop actions on narrow screens. `PickupEffect` now contains responsive reflow; rerun actual phone acceptance rather than relying on its old fixed-width failure.
- Verify mouse orbit, touch camera drag, gamepad camera control, and action release after menus or focus changes in the current prototype.
- Measure a mounted rider with a loaded cart on a phone. The earlier variable-frame-rate Studio recordings do not establish a mobile performance budget.

When camera-relative steering and the new HUD ship, repeat these checks against the refinement plan's charge, drift, load, and checkout criteria.

## Multiplayer rounds and ownership

Use at least two real clients for one complete shopping, styling, judging, and results cycle. Each player receives the correct collection, can place and customize only their own room's pieces, and sees the correct reveal. Reject self-votes and verify that submitted votes reach the intended room's result.

Exercise two active round cohorts while another player remains in the neighborhood. Themes, store stock, inventory, and rewards must stay with their own round. Disconnect during shopping, house loading, and judging, then confirm cleanup and remaining players' progress.

Hillside's standalone timed session does not prove these main-game behaviors. After integration, confirm that checkout finishes and preserves each piece before the store is released.

## Profiles, purchases, and new players

`ProgressionService` now catches profile-load errors, retries up to four attempts, logs failures, and removes a player when data cannot load. The old audit's missing-error-handler description is superseded. Forced-error acceptance remains required.

Use isolated profiles to prove:

- A load failure leaves no partially initialized owner, house, purchase state, or round reward state.
- A successful retry creates one profile session. Leaving during loading releases the acquired session and restores the lot.
- An unavailable profile system gives an explicit player-visible outcome. The current source can fall back to an in-session profile; the user must not mistake temporary progress for a saved result.
- Purchase and reward delivery charge or grant once. Rejoining restores the saved balance, owned furniture, finishes, and placements.
- A new profile reaches the neighborhood, completes a round, receives the intended reward, and reloads that result without relying on an existing tester profile.

For fixture mutations, set `ServerStorage.NeighborhoodPreviewProfiles = true` before Play, confirm the mock selector is active, and restore it afterward. Acceptance scripts must not overwrite ordinary player records. Quantity, earned-design, and ride serialization tests are part of the corresponding future refinement milestones.

## Production asset acceptance

Audit the current ItemAssets inventory rather than reusing the earlier missing-root count. Every production piece needs matching ItemId metadata, a stable root or PrimaryPart, sensible bounds and scale, and a validated placement surface.

Check collision and visibility separately while the item is on a shelf, carried, placed, and shown in a viewport thumbnail. Verify the intended support for floor, wall, ceiling, and tabletop pieces. Resolve unused catalog entries deliberately, including the earlier CardboardBox mismatch if it remains.

Load mesh and texture assets with the actual Test experience and intended player permissions. The local prototype reported permission errors for some inherited material textures. Editable furniture studies and generated candidates still need production collision, material, catalog, and placement checks before becoming ordinary stock.
