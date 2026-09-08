# Cart refinement milestone 1 candidate

September 8, 2026. Implementation checkout `codex/cart-refinement-20260908`, baseline `6587ce30797f5ae347281a504edf2ceb6e797c2e`. This is a local review candidate. Main-game integration and publication are not part of this change.

## Playable artifact

Open `build/superstore/RoomRoyale-Hillside-M1-Candidate.rbxlx` in Studio and press Play. The normal `tools/Start-HillsidePlaytest.ps1` now builds and opens that filename. `-BuildOnly` performs no Studio operation. On this machine the existing Luau tools are in `D:/code/RoomRoyale/.scratch/generated/luau`.

The final on-disk build includes the source below. Its runtime sources were exercised in the separately opened candidate, with the evidence limits below. A late repair to the cargo acceptance test was compiled but could not be rerun in Studio after the user stopped computer use.

## Implemented behavior

- `CameraDirection` converts keyboard, controller, and touch movement through horizontal camera heading. Raw stick input has one deadzone. Forward input converges toward camera direction; rear-half input reverses, including S+D. Looking without movement produces no drive acceleration.
- `Gesture` consumes separate jump and drift intent. Jump uses Space, A or R1, or JUMP. Drift uses Ctrl, L1, or DRIFT. Brake uses Shift, L2, or BRAKE. Jump takes priority on simultaneous presses; pressing drift during a jump charge does not replace it. Menu, focus loss, text entry, dismount, and reset cancel held actions.
- The existing native camera uses a cart focus part, keeping the seated character out of Roblox's vehicle-camera path. Physical mouse, touch, and controller camera usability remains unverified in this pass.
- `Shopping` owns the animated capacity meter, used/free space, delivered count, focused piece, and fit result. GRAB sends that displayed piece's numeric pickup ID. Shared `PickupRules` supplies range, support, visibility and capacity rules; the server still checks ownership, seating, stock, phase and capacity before adding cargo. Native pickup prompts are disabled to avoid a second target.
- Full load reduces drive acceleration by 30 percent and braking acceleration by 25 percent. Steering response keeps its existing load coefficient. Charged jump values remain unchanged. Rider posture blends with load, and cargo additions/removals add a small upward settling motion without changing piece identity or stack layout.
- The jump sound cue is removed. Landing, pickup, checkout, drift, boost, dive and crash cues remain. Hillside has a Controls button with device-specific jump, drift and brake prompts.

## Completed checks

[The build log](evidence/cart-refinement-m1/build.txt) records 25 gesture scenarios, camera cardinal/diagonal/rest/reverse/deadzone/pitch checks, 10,201 capacity comparisons against shopping-session admission, candidate selection, shopping deadlines and checkout rules, all prototype Luau compilation, and the Hillside build.

[Repository validation](evidence/cart-refinement-m1/repository.txt) confirms project paths and 54 main script paths/classes/disabled states/source hashes. [Crash replay](evidence/cart-refinement-m1/crash-replay.txt) passes all 14 scenarios. Replay stubs geometry queries and does not exercise ragdoll execution.

[The engine report](evidence/cart-refinement-m1/physics.json) passed 33 checks on 17 parallel server-owned assemblies with synthetic camera headings and action inputs:

| Measurement | Empty | Full |
| --- | --- | --- |
| Time to speed 40 | 1.1333 s | 1.6000 s |
| Braking start speed | 40 | 40 |
| Braking distance | 8.0713 studs | 10.8433 studs |
| Braking time | 0.4667 s | 0.6000 s |
| Charged launch speed | 26 | 26 |
| Jump rise | 3.2273 studs | 3.2273 studs |

All camera direction fixtures converged, including reverse, S+D and steep pitch. Rotating a camera with zero movement input produced zero displacement. Holding explicit drift through Chassis produced exactly one entry hop. Charging while camera heading changed preserved the full jump and did not drift. These are real physics results with synthetic inputs, not physical-device feel tests.

The mounted player's normal E action picked up two Crescent sofas, showing 80 used and 20 free. The same focused sofa then displayed its 40-space requirement and no-fit result; another E request was rejected. Moving the mounted cart through checkout cleared cargo and retained two delivered pieces. [Structured observations](evidence/cart-refinement-m1/client-observations.json) distinguish these real remote/HUD results from fixture checks. The capacity endpoints and visible stack were captured; intermediate tween timing was not measured.

- [Desktop loaded cart](evidence/cart-refinement-m1/desktop-loaded.png)
- [Desktop no-fit feedback](evidence/cart-refinement-m1/desktop-no-fit.png)
- [Desktop empty cargo and two checked-out pieces](evidence/cart-refinement-m1/desktop-checkout.png)

## Saved snapshot

The tracked `places/RoomRoyale-Hillside.rbxlx` was updated using XML file operations only. [The preservation report](evidence/cart-refinement-m1/snapshot-sync.json) records 13 managed script updates and four added modules, with all other parsed scene content and existing referents preserved. [Snapshot verification](evidence/cart-refinement-m1/snapshot-verification.json) confirms 30 Hillside managed scripts with zero mismatches. The main Test snapshot was unchanged and still matches 54 managed scripts. No Studio save or export occurred during file-only completion.

[Artifact hashes](evidence/cart-refinement-m1/artifacts.json) identify the final build and saved snapshots. The in-memory Studio candidate can differ from the final disk build's late test repair; reopen the disk artifact only when computer use is authorized again.

## Interrupted and remaining acceptance

The user stopped all computer use before the phone pass completed. No further Studio, screenshot, input, or window operations were performed after that instruction. File-only compilation, packaging and documentation continued.

The last known visible candidate was Studio instance `12dbf6d8-2f65-45df-9296-a123c13334d4`, local PlaceId 0, in Play after choosing iPhone 7 landscape 667×375. A valid phone HUD screenshot was not captured. The earlier hidden candidate instance `ad618878-53b4-4b70-bd53-f6043c9bffce` was stopped in Edit. Both opened the same candidate filename; the visible instance had the current 30 canonical scripts installed before acceptance. The first hidden instance supplied only an early keyboard drive/brake observation. Main Test `86511797738570` and pre-existing prototype windows were not changed. Window cleanup was not attempted after the stop. No repeating input helper was scheduled; the interrupted bounded activation/capture call's completion is unknown.

The old cargo assertion compared `GetDescendants()` by array index. Studio returned the same parts in different orders, so that check failed. The repaired assertion consumes matching parts by name, class, scale, appearance, mesh identity and transform in each model's bounding frame. Bounding frames account for unreplicated model pivots while retaining each part's arrangement. The first repair that compared raw model pivots also failed because the source and generated template have different pivot origins. The final bounding-frame repair compiles, but its engine rerun is outstanding. Visible two-sofa identity and successful checkout do not close the complete cargo geometry/suction suite.

Still required before acceptance is complete:

- The repaired cargo template/stack/suction suite and live wall-recovery/ragdoll checks. Crash replay is the completed automated comparison.
- Phone HUD overlap, safe-area and touch-button layout, including the new DRIFT and RESET positions.
- Physical mouse orbit, right-stick camera, touch camera drag and thumbstick feel. No nonzero native camera-input measurement was completed.
- Actual client jump/drift rapid releases and cancellations through menus, focus changes and text entry. Pure gesture tests cover the state rules; the engine fixture covers Chassis integration.
- Subjective loaded steering/posture/settling, near-full/full HUD, and sound-toggle usability. The file and engine evidence do not substitute for these player checks.

## Hands-on checklist

1. Drive forward and aim the camera around a corner; stop looking while stationary, then reverse with S and S+D.
2. Hold Jump while turning the camera, release, then press again in the air to dive. Hold Drift separately. Open a menu during each held action and verify a fresh press is required afterward.
3. Grab a sofa twice, read the third sofa's no-fit result, then checkout and verify that cargo clears while delivered count remains.
4. Compare empty and full acceleration/braking, and confirm that jumping stays enjoyable and the rider/cargo settle after unloading.
5. Use Controls on a controller and a narrow landscape phone. Check that the HUD and touch actions remain readable and reachable.
