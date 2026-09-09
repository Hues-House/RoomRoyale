# Cart control model: what the old build actually did

September 9, 2026. This supersedes the diagnosis in the [weight and control brief](cart-handling-weight-brief-2026-09-09.md) and the tuning-table argument in the [air and tricks brief](cart-air-tricks-turning-brief-2026-09-09.md). The specific changes in both still stand. The reason they are needed is different from what I first wrote, and bigger.

## I was comparing the wrong two builds

My first two briefs compared the current prototype against `build/cart-mechanics-v3`, dated September 7. Both are the same system with different numbers. The build you remember is older than that and is not a tuning variant at all.

It is still in the repository, live, at [`CartController.client.lua`](../src/StarterPlayer/StarterPlayerScripts/CartController.client.lua) and [`CartService.server.lua`](../src/ServerScriptService/CartService.server.lua). Git shows one commit touching them, `d7c8644` on September 6, "import verified Studio source into Rojo." That is an import of the published place, so the code itself is months old and predates the cart model change.

The main game still runs it. The new chassis lives only in `packages/RideRuntime` and the prototypes, and the September 8 refinement brief explicitly ruled out touching `src/`. So both systems are shipping side by side right now, and the one you liked is the one players are still using.

## The two systems are not comparable by tuning

The old controller commands velocity. The new one applies forces.

`CartService.server.lua:490` builds a `LinearVelocity` constraint with `MaxAxesForce = Vector3.new(110000, 0, 110000)`. Zero force on Y. Every frame the client computes a target horizontal velocity and writes it to `VectorVelocity`, and an `AngularVelocity` with 90000 torque commands the yaw directly.

That one line is the whole design, and it is better than I would have guessed.

- **Horizontal speed cannot run away.** It is overwritten every frame with what the player asked for. Gravity contributes nothing horizontally, so there is no hill in the game that can build speed you did not command. The runaway I diagnosed in the first brief is structurally impossible here.
- **Vertical is untouched.** Zero force on Y means jumps and falling are real physics at full gravity. Jump is a direct `AssemblyLinearVelocity += Vector3.new(0, 24, 0)` on a 0.7 second cooldown.
- **Yaw is commanded, not negotiated.** The cart points where you steer, immediately. No alignment spring, no grip solver, no slip to fight.

The new chassis replaced all three with springs, `AlignOrientation`, and a grip solver, and inherited an unbounded speed model as a side effect. That is why it feels out of control. It is not that the numbers drifted. It is that nothing is holding the wheel any more.

## What the old build had that the new one lost

| Behavior | Old controller | Current chassis |
| --- | --- | --- |
| Top speed | Commanded, 44, hard by construction | Emergent, unbounded downhill |
| Turn rate | 2.9, drift 4.35 | 1.9, drift 2.7 |
| Turning at low speed | `steerScale` floors at 0.2, so you can turn near standstill | Scales to zero below 13 studs/s |
| Lateral slide | Direct bleed, `SideDeceleration = 48`, drift 9.6 | Rotation-based grip solver |
| Drift | Hold jump plus steer above 10 studs/s, commanded velocity lerps 82 percent toward real momentum | Separate button, charge tiers, budget injection |
| Boost | Own button, 0.4 s, 1.7x speed and 4x acceleration, 3.6 s cooldown | Earned from drift charge, budget-limited |
| Steering input | Raw, no smoothing filter | Filtered at response 18 |

The 0.2 `steerScale` floor deserves calling out on its own. The old cart turns while nearly stopped. The current one multiplies turn rate by `speed / 13` with no floor, so at walking pace it barely responds. In a shop full of aisles that difference is felt constantly, and it is a one-line fix.

The unsmoothed raw steering also feels better here rather than worse, because yaw is commanded. Smoothing exists in the new system to hide the lag between heading and velocity. Remove the lag and you do not need the filter.

## Recommendation: split the model by contact

> Superseded. Keep one force solver and scale its traction terms by a continuous contact value instead of switching authorities at the ground boundary. See [the contact model brief](cart-contact-model-brief-2026-09-09.md). The ground-feel numbers below still stand.

Do not revert. The new chassis is what makes air, terrain, the dive, and tricks possible, and the old controller cannot do any of that, since it flattens the problem to a horizontal velocity command. Take the authority back without giving up the simulation.

**On the ground, command velocity like the old build.** Compute a target horizontal velocity and drive toward it, instead of accumulating whatever the force solver produces. Speed is then bounded by construction and the first brief's overspeed drag becomes unnecessary.

**Let the ground target grow with the slope.** This is the part the old build genuinely lacked, and it is what you asked for. Make the commanded target rise with how steeply the surface falls away along the direction of travel, and cap it in the profile:

```
targetSpeed = MaxSpeed + DownhillGain * max(-slopePitch, 0)
```

Momentum builds down a hill, holds while the hill lasts, and decays when the ground levels out. The player still cannot exceed the cap, and the build-up is a curve you can feel rather than an integration that never stops.

**In the air, keep the force model.** Release the horizontal command entirely on leaving the ground, so momentum carries. Air steering, dive, pump, and tricks all stay as the air-and-tricks brief describes. Landing is where the two models meet, so the landing bleed and the trick payout both belong on that transition.

**Restore the ground feel from the old numbers.** `TurnRate` 2.9 with drift at 1.5x, the 0.2 `steerScale` floor, direct lateral bleed at 48 with drift at 9.6, and the 82 percent momentum lerp during drift. Drop the steering smoothing filter once yaw is commanded again.

**Reconsider the standalone boost, but do not assume it.** The old build had a 0.4 second, 1.7x boost on its own button with a 3.6 second cooldown, and it is more legible than the drift-charge budget because the player picks the moment. It also costs a button, which cuts against the one-button decision. Under Mario Kart rules the drift release is the boost, so try that first and only add the button back if boost never feels available enough.

> Input scheme superseded. Jump and drift share one button. See [the one-button input brief](cart-one-button-input-brief-2026-09-09.md). Physics recommendations below are unaffected.

## Cross-platform

The old controller already binds forward, reverse, left, right, grab, hop/drift, and boost across keyboard, gamepad, and touch, with device-aware prompt text driven by `GetLastInputType`. Read that binding block before designing new input. It solves the problem the air-and-tricks brief works around, and reusing it is cheaper than reinventing it.

The button question is settled. Jump and drift share one button, as the old build had it, and the one-button brief covers why the accidental drifts that motivated the split were an input-plumbing bug rather than a problem with the scheme.

## What to do first

Play the published Test place and the Hillside prototype back to back, on the same hill, in one sitting. Everything above is read from source and worked out on paper. I have run neither build. If the old one confirms what its code implies, the split-by-contact model is the way forward and the rest of the work follows from it.
