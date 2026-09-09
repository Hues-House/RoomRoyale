# One-button jump, drift, dive, and trick

September 9, 2026. Supersedes the input sections of the [air and tricks brief](cart-air-tricks-turning-brief-2026-09-09.md) and the button conflict noted in the [control model brief](cart-control-model-brief-2026-09-09.md). Physics recommendations in both are unaffected.

Decision: jump and drift share one button. Hold it going straight and you charge a jump. Hold it while turning and you drift. Mario Kart World.

## This is what the build before last did, and the reason it was dropped was a bug

The pre-refinement `Gesture.lua` chose drift at the press edge on steering magnitude:

```lua
elseif math.abs(input.steer) > config.SteeringDeadzone then
    self._mode = "Drift"
```

The September 8 refinement replaced that with a separate Drift button, because charging a jump kept producing accidental drifts. That symptom was real. The cause was not the shared button.

The old client fed the raw lateral stick axis into that check, `math.clamp(readMovement().X, -1, 1)` at `Client.client.lua:49` in the September 7 tree. The refinement introduced `CameraDirection.resolve`, which converts movement through the camera heading and returns a steer value that is nonzero whenever the cart is not already pointed where the camera faces. Feed that into a drift test and the cart drifts because you looked sideways, not because you turned. Splitting the buttons hid it.

Two more things made it worse. The decision was sampled on a single press-edge frame, so one noisy value committed you for the whole hold. And the deadzone tested against was `SteeringDeadzone = 0.18`, low enough that a keyboard tap or thumbstick drift crosses it.

Fix the input source and the debounce, and the shared button works.

## The rule

One rule, on the ground and in the air. Hold the button. What you do with the stick decides what happens.

| | No directional input | Directional input |
| --- | --- | --- |
| Grounded | Charge a jump. Release launches. | Drift. Release spends the charge as boost. |
| Airborne | Dive. Fast fall at 2.2 g. | Trick. Rotate. Land level to bank it. |

A tap, meaning release before the tap threshold, is always a plain hop and never anything else. That is the escape hatch. If a player wants to hop mid-corner without committing to a drift, they tap.

The two consequences worth stating plainly. You cannot charge a jump while turning, which is the cost of one button and is how Mario Kart behaves. And once a drift engages, the jump charge is discarded and release gives boost rather than a jump. Make that a one-way door, because a mode that can flip back is unreadable at speed.

## What the implementation must get right

**Take the drift axis from raw movement, never from the resolver.** In `Gesture.Input`, replace the `drift` boolean with `lateral`, and document at the type that it must be the raw movement axis. `CameraDirection.resolve` output is for driving only. Naming it `lateral` rather than `steer` is deliberate, so nobody wires the resolved steer back in six months from now.

**Decide over time, not on one frame.** Drift engages when the raw axis stays past its threshold for a sustained window, the cart is grounded, and speed is at or above `MinDriftSpeed`. Suggested starting values, all in the profile:

- `DriftEngageAxis = 0.5`, well above the 0.18 steering deadzone
- `DriftEngageSeconds = 0.1`
- `TapSeconds = 0.12`, below which a release is a plain hop
- `MinDriftSpeed = 14`, unchanged

**Give the drift hysteresis.** Once engaged, maintain it down to an axis of about 0.15, and hold it through roughly 0.35 seconds of centered stick. Counter-steering inside a drift is a core skill and it must not drop the drift.

**Keep the entry hop where it is.** Drift entry already fires `HopSpeed`. Under this scheme it fires when the drift engages rather than on the press, so it lands up to 0.1 seconds later. That is close to the Mario Kart hop timing anyway. Do not add a second hop on press, or the charged jump has nothing left to charge from.

**Apply the same gate in the air.** Dive against trick uses the same raw axis and the same engage window, so the player learns one rule instead of two.

## What this buys on mobile

Touch loses a button. The layout goes from JUMP, DRIFT, BRAKE, GRAB, RESET to JUMP, BRAKE, GRAB, RESET, and JUMP alone covers jumping, drifting, diving, and tricks. That is the whole reason to do this, and it is worth the lost jump-while-turning.

The scheme also stops depending on a button the touch player has to reach for while already holding the movement stick and dragging the camera. On a narrow landscape phone, drift and camera drag competed for the same thumb. Now the drift decision comes from the stick that thumb is already on.

Keyboard is Space, gamepad is A or R1, touch is JUMP. One binding per platform, and the device prompt text collapses to one line.

## Cost

`tests/ride/Gesture.spec.lua` was rewritten for the two-button model in the last commit, 504 lines changed. This rewrites it again. That is real churn and I would rather say so than bury it. The state machine itself is smaller under this design, since drift and jump charge become branches of one held state instead of two independent ones.

New cases the spec needs:

1. Press straight, hold, release. Charged jump, no drift.
2. Press while turning, hold. Drift engages after the window, with exactly one entry hop.
3. Press straight, charge, then turn. Converts to drift, jump charge discarded, release gives boost.
4. Press while turning, release under the tap threshold. Plain hop, no drift.
5. Camera rotation with zero movement input, button held. No drift, ever. This is the regression test for the bug that caused the split.
6. Counter-steer through center during a drift. Drift survives.
7. Axis crossing the engage threshold for less than the engage window. No drift.
8. Airborne press with no direction against with direction. Dive against trick.

Case five is the one that matters. Write it first.

## Open question

Tricks now sit on the same button as everything else, which means a player holding the button through a jump goes from charging, to airborne, to diving or tricking, on one continuous hold. Decide whether the hold carries across the ground-to-air transition or whether the air state requires a fresh press. Mario Kart requires the press to be live at the lip, which argues for carrying it. I lean that way, but it is a feel question and belongs in the same playtest as the ground handling comparison.
