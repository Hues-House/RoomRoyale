# Room Royale public-beta readiness audit

> Historical record read from `D:\code\RoomRoyale\docs\public-beta-readiness-audit-2026-08-30.md` on 2026-08-30. This copy records the state before the repository setup.

Date: 2026-08-30
Verified Studio target: `Room Royale`
PlaceId: `82272152451005`
Universe/GameId: `10383493285`

## Executive summary

The live place is a functioning one-player Shop -> Style -> Judge -> Results loop, but it is not public-beta ready for Xbox or cross-device UI yet.

Highest-priority release blockers:

1. Xbox lobby navigation has no selected GUI object, so Button A or D-pad input cannot enter a round.
2. Phone inventory UI uses fixed 1160px geometry and clips at iPhone width.
3. Safe-area handling is inconsistent across runtime-created ScreenGuis.
4. Style and Judge controller focus, confirm, and back flows are incomplete.
5. Profile loading is not protected against `LoadProfileAsync` errors.
6. Multiplayer voting, pickup, placement, and zero-data FTUE still need evidence.

No place content, cloud place, publish operation, or explicit DataStore test was changed by this audit. Studio was returned to Edit mode with the default viewport.

## Current architecture map

- `RoundManager` owns round phases: Lobby -> Shop -> Style -> Judge -> Results.
- Shop: `StoreSetup` spawns the inventory; `CartService` owns cart state and pickup validation; `CartController`, `ShopTargeting`, prompts, and `PickupEffect` provide client interaction and HUD.
- Style: `RoomService` owns room creation and server placement validation; `StyleController` owns the styling panel and owned collection; `PlacementController` owns the placement ghost, grid, rotation, and confirm or cancel flow.
- Judge: `JudgeService` owns touring, vote collection, scoring, and reveals; `JudgeClient` renders tour, voting, reveal, and leaderboard UI.
- Shared UI: `UITheme` owns palette and responsive scaling; `UIStateManager` exists but currently registers only CartHUD and PlacementHUD.
- Persistence: `ProgressionService` uses ProfileService with `PlayerProgression_v1_PS`; the old raw store is intentionally not migrated.

## Five-step wayfinder plan

1. Complete repository engineering-skill setup: local Markdown issues under `.scratch/` and single-context domain docs.
2. Implement the smallest P0 slice: Xbox focus or navigation, consistent safe-area policy, and responsive inventory layout.
3. Re-run iPhone, iPad, Xbox, and desktop acceptance checks.
4. Prove pickup, placement, multiplayer voting, zero-data FTUE, and persistence failure behavior.
5. Gate public beta on persistence hardening, asset normalization, and the acceptance matrix.

## Device acceptance matrix

| Target | Result | Evidence |
|---|---|---|
| iPhone 17 Pro | Partial | Full one-player loop completed; inventory tray clips at 874x402; pickup and placement not proven |
| iPad Pro M5 13-inch | Partial | 15-slot tray fits; custom GRAB or BOOST controls were absent because simulator input flags made `UITheme.IsTouch()` false |
| Xbox One | Blocked | R2 moved the cart; lobby `SelectedObject=nil`; Button A or D-pad did not enter the queue; boost label showed `Press Shift` |
| Multiplayer judge | Unverified | One-player reveal reported `voters=0`, `leaderboard=1` |
| Persistence | Release gate | ProfileService reported live saves; profile-load failure handling remains incomplete |

The game is configured as `LandscapeSensor`; portrait acceptance was not run.

## Verified playtest evidence

### iPhone 17 Pro

- Runtime started successfully.
- Farmhouse Shop phase displayed with 77 shop items.
- Style spawned one room and displayed the styling UI.
- Judge displayed `Room 1 of 1`.
- Reveal completed with `voters=0` and `leaderboard=1`.
- Results completed and returned the player to the hub.
- No runtime exceptions appeared in the console.

### iPad Pro M5

- Lobby and Shop rendered at 1376x1032.
- The inventory tray fit the tablet viewport.
- The tablet simulator reported `TouchEnabled=true`, `KeyboardEnabled=true`, and the game therefore treated it as non-touch; the custom cart touch controls were hidden.

### Xbox One

- Lobby Play button was visible and `Selectable=true`, but `GuiService.SelectedObject` was `nil`.
- Button A and D-pad input did not enter the queue.
- R2 changed the cart position while `InCart=true`, proving the drive binding is active.
- The Shop HUD displayed `Press Shift` after gamepad interaction, indicating stale input-mode labeling.

## Smallest implementation slice

1. Add a shared controller-focus or input-mode path that selects the visible lobby CTA, exposes phase-specific focus targets, supports confirm or back, and updates labels from `LastInputTypeChanged`.
2. Apply one safe-area policy to every interactive runtime ScreenGui, especially `RoundClient`, `PlacementController`, `PromptController`, `JudgeClient`, and `LobbyBoutiqueClient`.
3. Reflow or size the 15-slot phone inventory tray from the viewport instead of using a fixed 1160px width.
4. Re-test on the three device presets before adding new features.

## Other release gates

- Protect `ProgressionService` profile loading with an explicit error, retry, or recovery path.
- Decide whether the owned collection is an intended Style bonus or a Shop bypass; current UI intentionally allows owned items to enter placement.
- Prove normal-control pickup and cart-to-Style transfer.
- Prove actual placement, wall or floor styling, multiplayer judging, and vote submission.
- Test zero-data FTUE without relying on the existing saved profile.
- Normalize nine ItemAssets models missing PrimaryPart and verify bounds, roots, collision policy, placement surfaces, and viewport framing.
- Keep `CardboardBox` catalog metadata aligned or remove the non-showroom orphan deliberately.

## Item generator assessment

The in-Studio item generator is appropriate for a small furniture or decor POC. Production assets still need direct `ReplicatedStorage.ItemAssets` entries with exact ItemId or catalog metadata, a stable PrimaryPart or Root, clean visual parts, placement-surface classification, collision policy, viewport framing, and validated bounds.

## Repository setup prerequisite

The requested setup skill was accessible and read. The current repository has no remote, `.scratch/`, `docs/agents/`, `CONTEXT.md`, or `docs/adr/`, and no triage skill is installed.

Recommended configuration for the future GitHub sync:

- Issue tracker: local Markdown under `.scratch/` until the GitHub repository exists.
- Triage labels: omit; the triage skill is not installed.
- Domain docs: single-context layout.

This configuration was not written during the audit because the setup skill requires confirmation before creating those files.

## Next owner action

Confirm the local-Markdown or single-context setup, then approve the first P0 implementation slice for the live Studio scripts. Do not publish or overwrite the cloud place until the device and persistence gates pass.
