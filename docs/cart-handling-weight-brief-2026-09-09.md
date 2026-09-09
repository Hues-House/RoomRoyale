# Cart handling: weight and control brief

September 9, 2026. Written against `bb6d5d9` (Refine Hillside cart controls and capacity feedback). Target module set is `packages/RideRuntime/`. Do not edit the stale copy under `build/cart-mechanics-v3/`.

Complaint: the cart is too fast and gets away from the player. The goal is a heavier cart with tighter control that still builds momentum downhill and off jumps, and still rewards a player who learns it.

> Superseded diagnosis. The older build referenced here is not the one that felt better. See [the control model brief](cart-control-model-brief-2026-09-09.md), which identifies the real prior system in `src/`. The specific changes below still stand; the reasoning for them changed.

## What the code actually does today

I read `Chassis.lua`, `Gesture.lua`, `Profiles.lua`, and `CameraDirection.lua`, and worked the numbers against Roblox default gravity of 196.2 studs/s². Five things explain the feel.

### 1. Nothing bounds top speed

`ArcadeSpeedCeiling = 120` reads like a speed cap but is not one. It only limits how much the drift and boost budgets may add (`Chassis.lua:305`). Gravity is not budgeted. Holding throttle downhill gives drive acceleration of zero above cruise speed, and the only opposing term is `RollingDeceleration = 0.65` studs/s². On a 15 degree slope, gravity pulls at 50.8 studs/s² along the surface. Net acceleration downhill is about 50 studs/s², so two seconds of hill adds 100 studs/s, and there is no speed at which it stops.

That is the headline bug. Cruise speed is 44 and the cart routinely runs at two to three times that.

### 2. Airborne means half gravity, zero drag, and no grip

The not-grounded branch applies only a small lateral correction. There is no drag term at all, so horizontal speed is perfectly conserved in the air. `AirGravityScale = 0.5` then doubles the hang time. Any bump that breaks ground contact hands the player free distance at whatever speed they arrived with.

Ground contact breaks easily. `SeparatingSpeed = 7` drops a probe as soon as the body pulls away faster than 7 studs/s, `ProbeLength = 3.5` leaves only one stud of probe below the 2.5 ride height, and grounded requires two of four probes. Rolling terrain at speed puts the cart in the air-physics branch constantly.

### 3. Steering yaw rate does not fall with speed

`turnScale = clamp(speed / SteerReferenceSpeed, 0, 1)` saturates at 13 studs/s. Above that the cart turns at the full `TurnRate = 1.9` rad/s at any speed. Implied lateral acceleration is speed times yaw rate: 84 studs/s² at cruise, 228 studs/s² at 120. The cart is asked to corner at 1.16 g while looking like a shopping trolley.

### 4. Grip snaps velocity onto heading

`GripResponse = 7` with `GripAcceleration = 220` studs/s² pulls the velocity vector onto the heading with a 0.14 second time constant and 1.1 g of authority. Combined with point 3, the cart is on rails right up to the moment it is not. That is where out-of-control comes from. There is no progressive slide, just grip and then no grip.

### 5. Steering input reaches full lock almost instantly

`SteeringResponse = 18` fills the steering filter in about 0.06 seconds. `CameraDirection.resolve` normalizes heading error by pi/3, so any camera error past 60 degrees is already full lock. A keyboard tap is a full-lock command.

Braking is not the problem. `BrakeAcceleration = 95` stops the cart from 44 in 10 studs. It stops it from 120 in 76 studs, and 101 when loaded. Braking only feels weak because the speeds are wrong.

## Changes to make

Work in this order. Each step is independently playable, so stop and feel it before moving on.

### A. Give the cart a terminal speed instead of a clamp

Add overspeed drag that is zero at or below cruise and grows with the square of the excess. A hard clamp would kill the downhill build-up. Quadratic drag keeps the acceleration curve and just flattens its tail.

```
excess = max(speed - CruiseSpeed, 0)
overspeedDrag = OverspeedDrag * (excess / OverspeedRange) ^ 2
```

Start with `OverspeedDrag = 60` studs/s² and `OverspeedRange = 36`. On a 15 degree slope that settles near cruise plus 36. Measure the steepest drivable slope in the actual place file and re-derive the constants so terminal speed lands at 78 to 82. Do not keep my numbers if the terrain disagrees.

Two constraints on the implementation. Apply the same drag in the air at reduced strength, around 0.4 of the ground value, so a long jump no longer conserves speed exactly. And keep it inside the existing `carryingDrift or boosting` exemption, otherwise the drift and boost budgets get eaten and `DriftPhysicsAcceptance.lua:130` fails.

Drop `ArcadeSpeedCeiling` from 120 to the new terminal speed so the assist budgets and the physical limit agree.

### B. Cap lateral acceleration rather than yaw rate

Replace the `SteerReferenceSpeed` saturation with a friction cap, keeping the low-speed ramp so the cart still turns from rest.

```
lateralCap = if drifting then DriftLateralAcceleration else MaxLateralAcceleration
effectiveTurnRate = min(TurnRate, lateralCap / max(speed, 1))
```

Start with `MaxLateralAcceleration = 90` and `DriftLateralAcceleration = 130`. At cruise this changes nothing, which is deliberate, because handling at 44 is fine today. At 80 the yaw rate falls to 1.13 rad/s and the turn radius grows to 71 studs. High speed goes wide, and that is what makes speed feel like a commitment.

### C. Make grip progressive

Cut `GripAcceleration` from 220 to about 110 and `GripResponse` from 7 to 5.5. Leave the drift values alone, since 65 and 1.25 are already loose. Overdriving the steering should now push the cart into a slide the player can see coming and correct, instead of holding and then letting go all at once.

### D. Keep the cart on the ground, and charge for bad landings

> The grounded hysteresis proposed here is superseded by the continuous contact value in [the contact model brief](cart-contact-model-brief-2026-09-09.md). The probe length raise, the gravity change, and the landing penalty still stand.

Raise `SeparatingSpeed` to 10 and `ProbeLength` to 4.25 so small crests stop launching the cart. Add hysteresis: once grounded, require all four probes to miss for two consecutive frames before switching to air physics.

Raise `AirGravityScale` from 0.5 to 0.75. Keep `DiveGravityScale` at 2.2 so the dive still reads as a distinct action.

Then add a landing penalty. This is the single change that will most make the cart feel heavy. On the frame grounded goes false to true, scale horizontal speed by a factor derived from impact quality. A landing with low vertical speed and velocity aligned to both heading and surface normal keeps everything. A flat slam or a sideways landing loses up to 25 percent. Expose the maximum loss and the vertical-speed threshold in the profile.

This is the skill ceiling. Speed off a jump becomes something the player earns by lining the landing up, not something the physics hands them for driving off a lip.

### E. Calm the steering input

Lower `SteeringResponse` from 18 to 9, and return to center at roughly twice the rate of steering away from it. Widen the `CameraDirection.resolve` normalization from pi/3 to pi/2 so full lock needs a 90 degree heading error.

### Leave alone

Drift tier timings, drift and boost budget sizes, charged jump speeds, `ClimbAssist`, the dive, and every load coefficient. None of them cause this, and they carry the reward structure.

## Verification

Update the existing acceptance drivers for the new ceiling and turn model: `DriftPhysicsAcceptance.lua`, `HandlingAcceptance.lua`, `PhysicsAcceptance.lua`, `CartRefinementAcceptance.lua`.

Add checks for the four behaviors this brief introduces.

1. Terminal speed. Drive the steepest slope with throttle held for eight seconds. Speed converges and stays within a few studs/s of the target, and never exceeds `ArcadeSpeedCeiling`.
2. Turn radius against speed. Full steering lock at 30, 60, and 80 studs/s produces radii that grow monotonically, and lateral acceleration never exceeds `MaxLateralAcceleration` by more than a small margin.
3. Landing bleed. A clean landing keeps at least 95 percent of horizontal speed. A sideways or flat-slam landing loses close to the configured maximum.
4. Bump retention. Driving a rolling section at cruise stays grounded, where the current build goes airborne.

Report measured empty and loaded numbers the way the milestone-1 report does. Numbers alone will not settle this, so finish with a hands-on pass: one downhill run, one jump line, and one tight corner taken too fast on purpose.
