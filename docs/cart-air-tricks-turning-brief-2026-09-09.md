# Cart air, tricks, and turning brief

September 9, 2026. Written against `bb6d5d9`. Companion to the [weight and control brief](cart-handling-weight-brief-2026-09-09.md); read that one first, because the terminal speed and lateral cap it defines are what make everything here safe to add. Target module set is `packages/RideRuntime/`. Do not edit the stale copy under `build/cart-mechanics-v3/`.

> Superseded diagnosis. The older build referenced here is not the one that felt better. See [the control model brief](cart-control-model-brief-2026-09-09.md), which identifies the real prior system in `src/`. The specific changes below still stand; the reasoning for them changed.

## The older build is still on disk, and the diff explains the regression

`build/cart-mechanics-v3/packages/RideRuntime/Profiles.lua` is dated September 7 at 14:48. That puts it before the revision 4 rework, which responded to the September 7 evening feedback, and before the September 8 refinement commit. It is the tuning from before any of the recent work, and it is the only older copy on disk. Git will not help here, because the repository consolidation at `6587ce3` is the first commit that contains the file at all.

Against current:

| Constant | Sept 7 | Current | Effect of the change |
| --- | --- | --- | --- |
| `TurnRate` | 2.25 | 1.9 | Cart rotates less willingly |
| `GripResponse` | 4.2 | 7 | Velocity snaps to heading in 0.14 s instead of 0.24 s |
| `GripAcceleration` | 145 | 220 | Lateral authority up from 0.74 g to 1.12 g |
| `AlignmentResponse` | 14 | 20 | Body chases the heading harder |
| `AlignmentTorquePerMass` | 260 | 400 | And with 54 percent more torque to do it |
| `SteeringResponse` | 13 | 18 | Full lock in 0.06 s instead of 0.08 s |
| `CoastDeceleration` | 3 | 14 | Letting off the throttle now scrubs speed |
| `AirSteerRadians` | 0.65 | 1.2 | Air steering budget nearly doubled |
| `AirLateralAcceleration` | 5 | 12 | Air steering authority up 2.4x |

Two of these were deliberate. [The revision 4 doc](playtest-iteration-v4-2026-09-08.md) records the charged jump rising 3.72 times, from 0.868 to 3.230 studs, along with 0.5 air gravity and the 2.2 dive, and describes the handling change as more grip and less coasting. Those came out of the September 7 evening feedback, so do not revert them blindly. The taller jump and the dive are worth keeping. The grip, alignment, and coast-drag changes are what this brief argues against, and the tuning table below separates them.

This is why the older build felt better, and the pattern is consistent. The older tuning turned faster but gripped and aligned softer. That combination gives the player a slip angle to hold and read. The cart rotates, the velocity follows a beat later, and the gap between the two is the thing you steer with.

Revision 4 inverted it. Lower turn rate with much harder grip and alignment means the cart rotates less but drags its velocity around instantly. There is no slip angle to work with, so the cart is either pointed where you want or violently correcting. That reads as darty and rigid, and it is the same rigidity that makes high speed feel uncontrollable.

The coast drag change matters too. At `CoastDeceleration = 14` you lose speed the moment you release the throttle, so players hold throttle permanently, which puts them in the 0.65 studs/s² rolling-drag branch that has no bound on downhill speed. The two changes together produced the runaway. Fix the bound with overspeed drag from the companion brief, then restore low coast drag so coasting is a real option again.

### Turning: restore the older grip and turn feel, keep the new speed limits

Set `TurnRate = 2.25`, `GripResponse = 4.2`, `GripAcceleration = 145`, `AlignmentResponse = 14`, `AlignmentTorquePerMass = 260`, `SteeringResponse = 13`, `CoastDeceleration = 3`.

This supersedes the grip numbers in the companion brief, which I derived from scratch before finding the older tree. Use the values that already shipped and felt right.

That turn rate is only safe because the companion brief adds the lateral acceleration cap. Keep both. At cruise you get the older handling exactly, and above roughly 60 studs/s the cap takes over and the turn opens up.

## Air time

The older build had no `AirGravityScale` at all, so it fell at full gravity with a 0.87-stud hop. Revision 4 set 0.5 and raised the jump 3.72 times, which is the right direction but lands as constant float rather than air time you earn. Keep the taller jump. Trade some of the float for control.

Make hang time a resource tied to doing something:

- Base `AirGravityScale = 0.85`. Falls with weight, lands when you expect it to.
- While a trick is actively rotating, ease it toward 0.55 so a committed trick buys the time to finish it.
- Keep `DiveGravityScale = 2.2` for the fast fall.

The charged hop is still not where air comes from. `ChargedHopSpeed = 26` at 0.85 g gives about 2 studs of rise and a third of a second, which is more than the old build had and still not enough to trick in. Real air has to come from terrain, so add a pop off ramps: when a jump input fires while the surface pitches up along the direction of travel, scale the launch by both the pitch and the current speed. Hitting a lip fast and timing the pop should be worth several times a flat hop. Cap the bonus in the profile.

> Input scheme superseded. Jump and drift share one button. See [the one-button input brief](cart-one-button-input-brief-2026-09-09.md). Physics recommendations below are unaffected.

## Tricks

Feed trick rewards into `gesture.boostSeconds`, the same channel drift release already uses. `Chassis:step` picks that up at line 268 and the budget and ceiling logic already bounds it. Nothing downstream needs new plumbing, and tricks cannot break the speed model.

### Input, without adding a button

Touch already carries JUMP, DRIFT, BRAKE, GRAB, and RESET. A sixth button will not fit a narrow landscape phone, so overload what the player already holds.

Drift is unused in the air. Make it the trick modifier. While airborne with drift held, the movement axes drive rotation instead of air steering:

- Left or right rotates yaw, for spins.
- Forward or back rotates pitch, for flips.
- Held with no movement input is a grab pose.

That maps cleanly to all three platforms. Keyboard is Ctrl plus WASD, gamepad is L1 plus the left stick, and touch is the DRIFT button plus the movement stick. No new binding, and drift keeps its single meaning of "commit to something risky."

Two client-side details. `CameraDirection.resolve` converts the stick through camera heading, which is meaningless mid-flip, so bypass the resolver and use raw axes while trick mode is active. And on touch, confirm the movement stick and the right-side camera drag do not fight during a trick.

### Rotation and landing

`AlignOrientation` currently forces the body to heading-with-normal-up every frame, so tricks need it to yield. Swap the alignment target to the trick-accumulated orientation while rotating, then blend back to level as the cart approaches the ground. Do not simply disable it, or a botched trick leaves the cart tumbling with no recovery.

Track total rotation per axis while airborne. On landing:

- Rotation within about 30 degrees of level converts accumulated spins and flips into boost seconds. Scale by completed rotations, not raw degrees, so a 340 degree spin pays nothing and a full 360 pays properly.
- Rotation outside that window is a bad landing. Use the landing bleed from the companion brief and take the full penalty.

That is the whole risk model. You choose when to stop rotating, and getting greedy costs you the speed you were carrying.

### Air steering

Restore `AirSteerRadians = 0.65` and `AirLateralAcceleration = 5`, and exempt trick rotation from that budget. Air steering is for lining up a landing. Tricks are a separate system, and they should not compete for the same allowance.

## Pumping

Space is already the fast fall. `Gesture` puts a mid-air press into `Dive` mode and `DiveGravityScale = 2.2` drops the cart at over twice gravity. The Alto's Odyssey feel you are describing is mostly there; what is missing is the payoff. In Alto, diving into a downslope is how you build speed, and diving flat is how you lose it.

Make the dive pay:

1. Landing while diving, on a surface that falls away along the direction of travel, converts vertical speed into forward speed. Scale by how well the velocity lines up with the slope. A dive into a matched downslope should be the fastest way to gain speed on the whole map.
2. Landing while diving on flat or rising ground takes an amplified version of the landing bleed. Diving is a commitment, not a free "get down faster."

Then add ground pumping on the same button. Hold Space while grounded and passing through a compression, meaning the surface pitch swings from downhill toward uphill, and convert suspension compression into forward acceleration. Gate it on actually being in a compression so it cannot be spammed on flat ground. Cap the per-compression gain in the profile and route it through the boost budget so the speed ceiling still holds.

Space now means jump on the ground, fast fall in the air, and pump through a valley. All three are contextual, all three use one button, and it is identical on keyboard, A or R1, and the touch JUMP button.

## Implementation notes

`Gesture.Mode` is a string union of `Idle`, `JumpCharge`, `Drift`, and `Dive`. Adding `Trick` touches `tests/ride/Gesture.spec.lua`, which asserts on mode strings in about twenty places. Keep the new mode out of the existing transitions rather than reworking them, since drift on the ground and trick in the air can share a button without sharing a state.

Order the work so each stage is playable on its own. Turning first, because it is a profile change and will tell you immediately whether v3 was really the better feel. Then air gravity and the ramp pop. Then dive payoff and pumping. Tricks last, since they are the only part that needs new state and new alignment handling.

## Verification

Beyond the companion brief's checks:

1. Turn feel comparison. Same corner at 30 and 60 studs/s, recording peak slip angle and time to settle, against both the older profile and the current one. The restored profile should show a larger, longer-lived slip angle.
2. Ramp pop. Launch height scales with approach speed and lip pitch, and is capped.
3. Dive payoff. A dive into a matched downslope gains speed. The same dive onto flat ground loses more than a non-dive landing.
4. Pump gating. Holding the pump on flat ground gains nothing. Holding it through a valley gains a bounded amount.
5. Trick scoring. A clean 360 pays boost, a 340 pays nothing, and an unlevel landing takes the full bleed.
6. Cross-platform input. Trick rotation works from keyboard, gamepad stick, and touch stick, and the touch trick stick does not fight camera drag.

Do the turning comparison hands-on before building anything else. If the restored turning does not feel better, the rest of this brief is built on a wrong premise and I want to know early.
