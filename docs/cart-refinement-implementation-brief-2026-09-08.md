# Cart refinement implementation brief

Status: implemented local candidate, with completed checks and remaining acceptance in the [milestone 1 report](cart-refinement-m1-2026-09-08.md). Computer use stopped at the user's request before phone and remaining cargo acceptance finished. This is milestone 1 of the [approved refinement plan](refinement-plan-2026-09-08.md). Milestones 2-5 remain separate assignments.

## Outcome

A player can steer the cart by aiming the camera, charge a jump without accidentally drifting, understand whether the next piece fits, and feel the difference between empty and loaded shopping trips. Preserve the v4 jumps, airborne dive, recognizable furniture stacks, checkout suction, grip, and wall recovery.

## Working arrangement

- Baseline: commit `6587ce30797f5ae347281a504edf2ceb6e797c2e`.
- Implementation checkout: `D:\code\RoomRoyale--cart-refinement`, branch `codex/cart-refinement-20260908`.
- The parent session owns this brief and the next round-integration brief. Astra owns milestone-1 source, focused verification, and its implementation report.
- Read `AGENTS.md`, the approved refinement plan, `docs/game_systems.md`, `docs/ui_system.md`, and `docs/verification.md` before editing. Use `CONTEXT.md` and `docs/writing_guide.md` for player language.
- Keep edits in this checkout. Use the canonical ride/cart modules consumed by both prototype projects. The parent session reviews the result before integrating it into the main checkout.

## Player behavior

### Driving and actions

1. Convert the player's movement direction through the camera's horizontal heading. WASD, the left controller stick, and the touch movement stick all follow that rule. Holding forward while aiming the camera turns the cart. Looking with no movement input produces no drive acceleration. Maintain a usable stop, reverse, and turn-at-low-speed behavior.
2. Keep camera aiming available through mouse, right controller stick, and right-side touch drag. Check native camera behavior while seated; do not equate reading a camera heading with proving a usable camera.
3. Separate deliberate drift intent from heading corrections used by the controller. Jump must remain reliable while looking or steering. The first-playtest decision is a distinct Drift action: Ctrl on keyboard, L1 on controller, and a touch Drift button. Jump stays on Space, A/R1, and touch Jump. Check the added touch control against the narrow-screen layout; these bindings remain open to playtest feedback.
4. Preserve charge timing, charged jump height, airborne dive, and recovery. Menu opening, focus loss, text input, dismount, and ejection cancel held actions without firing an unintended jump or boost. Resuming control requires a fresh action press.

### Capacity and weight

1. Animate the capacity meter as authoritative cargo changes. Display used and available cart space, readable nearly-full/full states, and the focused piece's space requirement with a clear fit/no-fit result.
2. Use consistent targeting for the displayed candidate and the pickup request. Keep the server authoritative over distance, stock, capacity, and pickup eligibility.
3. Distinguish cargo still on the cart from pieces already checked out. Prioritize theme, time, capacity, the nearby piece, and checkout guidance. Use device-aware prompts and a layout that fits a narrow landscape phone.
4. Make a full cart accelerate more slowly and take longer to brake than an empty cart. Keep steering responsive and jump height enjoyable. Start with conservative, clearly noticeable coefficients and document measured empty/loaded comparisons; final tuning follows playtest feedback.
5. Add loaded rider posture and cargo settling feedback where the existing animation systems own those behaviors. Preserve exact piece identity, visible scale, and stacking bounds.

### Audio

Remove the spring boing from jumping. Keep other cues and their existing independent controls usable. Do not introduce a replacement jump sample merely to fill the silence.

## Implementation boundaries

Trace the current input-to-chassis-to-gesture path and cargo-to-HUD path before editing. Send the parent a short description of the intended module boundaries and chosen drift binding, then continue without waiting for routine implementation approval.

Prefer a pure camera-direction resolver and explicit action intent feeding the existing chassis/gesture systems. Keep cart tuning in the shared ride profile. Update every actual consumer of changed internal input shapes, including tests and acceptance drivers. Preserve server validation at existing remote boundaries.

Main-game round integration, permanent inventory, progression prices, scoring, achievements, skateboard work, and park geometry redesign belong to later milestones. Avoid changing `src/` or the main Test scene for this assignment. Preserve the complete saved places and record any deliberate snapshot updates separately from generated build output. No Roblox publication is part of this assignment.

## Verification and completion

Run the relevant repository, prototype build, gesture/session, and crash replay checks from `docs/verification.md`. Add focused checks for the new behavioral risks rather than tests that repeat implementation constants.

The evidence must cover:

- Camera headings at cardinal and diagonal directions, no-input camera motion, low-speed turn/reverse, analog deadzones, and steep camera pitch.
- Jump press and charge while camera heading changes, explicit drift, rapid release/repress, airborne dive, and cancellation through menu/focus changes.
- Capacity boundaries, a piece that does not fit, pickup animation, checkout clearing cargo while preserving the delivered count, and matching client/server pickup eligibility.
- Empty and loaded acceleration, braking from comparable speed, charged jump preservation, settling/pose restoration, and the existing cargo/crash behavior.
- Actual Studio execution of the changed input-to-chassis and cargo-to-HUD paths. Capture the HUD itself for desktop and a narrow landscape viewport; viewport-only recordings do not establish HUD acceptance.

Use a separately built local prototype for engine acceptance. Identify its Studio instance before edits and coordinate sole ownership of that instance with the parent. Keep ordinary player profiles and the main Test scene out of prototype acceptance.

Deliver a runnable local Hillside candidate, the reviewed source changes, a concise report with exact checks and evidence paths, and a short hands-on playtest checklist. Distinguish automated/synthetic input checks from physical mouse, touch, controller, and subjective feel acceptance. Report an unavailable verification path precisely and complete the available checks.

Stop at the milestone-1 candidate. The parent will assess its artifacts and handle the next assignment.
