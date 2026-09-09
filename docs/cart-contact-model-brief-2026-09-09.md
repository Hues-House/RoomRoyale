# Continuous contact: one physics system for road, park, and air

September 9, 2026. Written against `bb6d5d9`. This supersedes the split-by-contact recommendation in [the control model brief](cart-control-model-brief-2026-09-09.md), which proposed commanding velocity on the ground and applying forces in the air. Keep one force solver. Everything else in that brief still stands, as does [the handling brief](cart-handling-weight-brief-2026-09-09.md) and [the air and tricks brief](cart-air-tricks-turning-brief-2026-09-09.md). Target module set is `packages/RideRuntime/`.

The goal is a chassis that rides a road, a pump track, and a quarter pipe without switching models, so one tuning pass serves the cart, the skateboard, and every later ride.

## Two authorities was the wrong answer

The control model brief argued for commanded horizontal velocity on the ground because it bounds top speed by construction. It does, and that is genuinely attractive. It also makes vert riding impossible. A quarter pipe is speed traded for height on a curved surface while still in contact, and a capped velocity command overwrites exactly the quantity that trade produces. `DownhillGain` covers a hill. It does not cover a transition.

So the bound has to come from a drag term rather than from the architecture. That is section A of the handling brief, and under this brief it stops being optional. More on the cost at the end.

## The code already has two contact notions and neither is continuous

`Chassis:step` counts probes twice.

- `groundCount` counts probes whose hit distance is within `RideHeight + GroundContactMargin`, which is 2.85 studs. [Line 185](../packages/RideRuntime/Chassis.lua:185) turns that into `grounded = groundCount >= 2`.
- `supportCount` counts probes that hit anything at all and are not separating. It is used once, at [line 342](../packages/RideRuntime/Chassis.lua:342), to decide whether air gravity applies.

Both are integers derived from the same loop, and the interesting part of that loop is already a smooth number. Each probe computes a spring force from its own compression. The information is there. It gets thrown away at the comparison.

Three hard rejections sit above the count, and each one is a cliff:

| Line | Test | Cliff |
| --- | --- | --- |
| 158 | `hit.Normal.Y < MinSupportNormalY` | All support vanishes past 72.5 degrees of surface pitch |
| 166 | `normalVelocity > SeparatingSpeed` | A probe pulling away at 7.01 studs/s contributes nothing |
| 185 | `groundCount >= 2` | Two probes is fully grounded, one is fully airborne |

The visible symptoms are the ones the handling brief already lists. Rolling terrain flips the cart into air physics constantly. What matters more here is what happens at a ramp lip, where all three fire within a few frames of each other. Drive, grip, brake, drift, and boost all live inside `if input.enabled and grounded` at [line 276](../packages/RideRuntime/Chassis.lua:276), so they switch off together. The surface normal snaps from the real normal to world up at [line 190](../packages/RideRuntime/Chassis.lua:190). Gravity halves. The cart pops.

Adding hysteresis to the boolean, as section D of the handling brief proposes, makes the pop later and less frequent. It does not make it smaller. For a park you need it gone.

## The change

Compute one number, `contact`, in the range 0 to 1, and multiply the traction terms by it instead of branching on it.

Per probe, replace each rejection with a ramp and take the product:

```
pitchWeight   = smoothstep(MinSupportNormalY, MinSupportNormalY + ContactNormalBand, hit.Normal.Y)
releaseWeight = 1 - clamp(normalVelocity / SeparatingSpeed, 0, 1)
depthWeight   = clamp((ProbeLength - distance) / ContactFalloff, 0, 1)
probeContact  = pitchWeight * releaseWeight * depthWeight
```

Then `contact = sum(probeContact) / #probes`.

`releaseWeight` is 1 whenever the probe is being pressed into the surface, since `normalVelocity` is negative there. It only fades as the probe pulls away, which is the behavior the existing threshold was reaching for.

With `contact` in hand, the branches collapse:

| Today | Under contact |
| --- | --- |
| `if grounded then` drive, grip, brake, drift, boost | Multiply each acceleration by `contact` |
| `elseif not grounded then` air steering correction | Multiply by `1 - contact` |
| `targetNormal = if grounded then normalSum else yAxis` | `unitOr(normalSum, yAxis):Lerp(yAxis, 1 - contact)` |
| `normalResponse` picked by branch | Lerp `NormalResponse` and `AirAlignmentResponse` by `contact` |
| `AlignmentResponse` picked by branch | Lerp by `contact` |
| Air gravity applied when `supportCount == 0` | Scale the gravity offset by `1 - contact` |
| `airSteerRemaining` refilled when grounded | Refill at a rate proportional to `contact` |

Ground and air stop being two codepaths. They become the two ends of one.

## Vert

Two things block a quarter pipe today, and both are cheap.

**The pitch gate is more conservative than the spring requires.** The spring at [line 172](../packages/RideRuntime/Chassis.lua:172) already scales its gravity-cancelling term by `hit.Normal.Y`, so on a vertical wall it resists penetration and holds the cart up not at all. The physics is already right for vert. Only the gate above it says otherwise. Drop `MinSupportNormalY` toward 0.05 and let `ContactNormalBand` carry the transition. A cart that arrives at a wall too slowly slides back down under gravity, which is what should happen.

**The probe direction is biased toward world up.** [Line 148](../packages/RideRuntime/Chassis.lua:148) builds the ray from `body.CFrame.UpVector + Vector3.yAxis * 0.15`. On a flat floor that bias is a useful stabilizer. On a wall it aims the probes 8 degrees off the surface and shortens their reach. Fade the bias out with the vertical component of the current normal.

Expect one regression in the store from the first change. The cart will hold shelf faces and aisle walls it used to slide off, given enough speed. I think that is a feature in a game that is about to have a pump park, but check it in the market before you check it in the park.

## Pumping falls out

Once `contact` exists, per-probe compression is already a number you carry. Pumping is compression converted to thrust, which the air and tricks brief asks for as a new mechanic gated on detecting a valley. Under this model it is the derivative of a value the solver already computes. Add thrust proportional to the rate at which total compression falls while the player holds the button, cap it in the profile, and route it through the boost budget as that brief specifies. No valley detector.

## New profile constants

| Constant | Start at | Meaning |
| --- | --- | --- |
| `ContactFalloff` | 1.5 | Studs of probe travel over which contact fades to zero |
| `ContactNormalBand` | 0.25 | Width of the surface-pitch ramp above `MinSupportNormalY` |
| `MinSupportNormalY` | 0.05, from 0.3 | Steepest supported surface |
| `ProbeLength` | 4.25, from 3.5 | Must exceed `RideHeight + GroundContactMargin + ContactFalloff` |
| `GroundedEnterContact` | 0.5 | Contact above which `Gesture` sees grounded |
| `GroundedExitContact` | 0.2 | Contact below which it sees airborne |

`ProbeLength` at 4.25 gives a ramp from 2.75 to 4.25, which is 1.5 studs. That is the same raise section D of the handling brief asks for, arrived at from a different direction.

## What still needs a boolean

`Gesture` does. `stepEvents` takes `grounded` at [line 203](../packages/RideRuntime/Chassis.lua:203) and the state machine needs a definite answer, because drift is a ground action and tricks are an air action and a mode cannot be 40 percent of each. Threshold `contact` with the two constants above and hold the last value between them. Report the boolean in telemetry as it is reported now, so the HUD and the acceptance drivers keep working, and add `contact` alongside it rather than replacing it.

The ledge grace belongs in that hysteresis too. `LedgeGraceSeconds` is currently a `Gesture` concern and can stay one.

## Cost, stated plainly

**Overspeed drag becomes load-bearing.** Under the discarded split model, top speed was bounded by construction. It is not any more, and quadratic overspeed drag is the only thing between the player and the 50 studs/s² of downhill acceleration the handling brief measured. Build section A first, measure it against the steepest slope in `RoomRoyale-Hillside.rbxlx` rather than against my numbers, and do not start this brief until terminal speed converges.

**Twenty assertions on `grounded` across seven test files.** `CartRefinementAcceptance`, `DriftPhysicsAcceptance`, `HandlingAcceptance`, `PhysicsAcceptance`, `Gesture.spec`, `Envelope`, and `ParkRideAcceptance` all read it. Keeping the boolean in telemetry means most of them survive untouched. The ones that will move are the bump-retention and landing checks, which measure the thing this brief changes.

**Tuning gets harder before it gets easier.** Every traction constant is now multiplied by a value that varies across a jump instead of switching. Effective grip at a lip is lower than the profile number suggests. Expect to raise `GripAcceleration` above whatever the handling brief settles on, and tune it on a crest rather than on flat ground.

## Order

1. Overspeed drag and the lateral cap, sections A and B of the handling brief. Terminal speed must converge before anything here is measurable.
2. `contact` as a computed value, reported in telemetry, changing no behavior. Drive the market and the park and record it against the boolean.
3. Multiply the traction terms by it. Blend the normal and both alignment responses. This is the change that removes the pop.
4. Threshold for `Gesture`, with hysteresis.
5. Relax the pitch gate and fade the probe bias. Vert becomes possible here, not before.
6. Pumping from compression rate.

Steps 2 and 3 are separable and step 2 is free. Do not skip it. A recording of `contact` across a lip is the evidence that decides whether `ContactFalloff` is 1.5 or 3.

## Verification

Beyond the checks the other three briefs list:

1. Contact across a lip. Recorded at 60 Hz over a ramp crest at 30 and 60 studs/s, `contact` falls monotonically to zero with no single-frame step larger than about 0.3.
2. No pop. Vertical speed on leaving a crest at cruise is lower than the current build's, and the departure angle matches the lip pitch within a few degrees.
3. Bump retention. A rolling section at cruise keeps `contact` above `GroundedExitContact` throughout, where the current build reports airborne.
4. Quarter pipe. Entering a transition at 50 studs/s carries the cart up the wall, and the height reached scales with entry speed. Entering at 10 studs/s slides back down without sticking.
5. Store surfaces. No wall in the Hillside market can be ridden at any speed a player can reach in an aisle. If one can, fix the geometry or gate wall support on speed, and record which.
6. Pump gain. Riding a pump track roller without touching the throttle gains speed, and the gain per roller stays under the profile cap.
7. Gesture parity. The existing gesture suite passes unchanged against the thresholded boolean.

Check 4 is the one this brief exists for. If it does not work, the continuous model bought nothing that hysteresis would not have bought more cheaply, and I would rather find that out at step 5 than after the park is built.
