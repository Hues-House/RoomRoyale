# Movement and physics workstream

Date: 2026-09-09. Status: current-source planning; implementation and Studio acceptance have not started.

The current source root is `D:/code/RoomRoyale`. The C: repository is an older bootstrap and does not describe the current game. Source links below point to the current D: project. No gameplay source, saved place, or Studio session was changed by this workstream.

The movement goal is to make the cart enjoyable through store aisles, rollers, banks, and jumps while preserving usable furniture selection and the transition into Style. Keep the v4 charged jump, airborne dive, and recognizable furniture stacks as the comparison baseline.

## Establish the current baseline

Use [the current documentation index](../README.md), [agent guide](../../AGENTS.md), [refinement plan](../refinement-plan-2026-09-08.md), and [verification guide](../verification.md). These supersede the old C: system maps and August audit wherever current source or evidence differs.

| State | Evidence and limits |
|---|---|
| Main Test | `src/` owns managed scripts. The complete `places/RoomRoyale-Test.rbxlx` includes Studio-owned assets. Main Test uses the older showroom/cart and complete rounds for separate cohorts. Configured Test PlaceId is `86511797738570`. |
| Hillside M1 | `packages/RideRuntime/` and `prototype/cart-lab/` own canonical cart source. `places/RoomRoyale-Hillside.rbxlx` contains the separate candidate. Camera-relative movement, separate Drift input, load effects, capacity feedback, and checkout exist. The session ends with a demonstration collection, not the main Style/Judge flow. |
| Completed M1 evidence | [M1 report](../cart-refinement-m1-2026-09-08.md) records 33 engine checks on server-owned assemblies with synthetic input, desktop E pickup, no-fit rejection, and checkout. These are prior results, not tests repeated here. |
| Remaining M1 acceptance | Physical mouse orbit, gamepad camera, touch camera and thumbstick, client release/cancel behavior, narrow-phone HUD, live wall recovery, and repaired cargo geometry/suction suite remain open. Crash replay does not execute live ragdoll. |
| September 9 proposals | Five physics briefs are explicitly unaccepted and unimplemented. Later briefs supersede parts of earlier ones. One-button input and continuous contact are proposed candidates, not already approved replacements for M1. |

Read-only inspection verified the following source details:

- [Profiles.lua](../../packages/RideRuntime/Profiles.lua) defines `BodySize = Vector3.new(5, 1, 7)`, `RideHeight = 2.5`, `ProbeLength = 3.5`, `GroundContactMargin = 0.35`, `CruiseSpeed = 44`, and `ArcadeSpeedCeiling = 120`. The body dimensions are not the full rider-and-cargo swept envelope.
- [Chassis.lua](../../packages/RideRuntime/Chassis.lua) computes `grounded = groundCount >= 2`, rejects support below `MinSupportNormalY`, and applies drive, grip, brake, drift, and boost through a grounded branch. `ArcadeSpeedCeiling` bounds assist gain, not gravity-driven speed. The current source has no quadratic overspeed drag.
- [Gesture.lua](../../packages/RideRuntime/Gesture.lua) takes separate `held` and `drift` booleans. Its modes are `Idle`, `JumpCharge`, `Drift`, and `Dive`.
- [Client.client.lua](../../prototype/cart-lab/Client.client.lua) reads raw movement, tracks jump/drift/brake separately, queues input edges, and cancels actions on focus/menu conditions. Raw movement must remain distinct from camera-resolved driving direction.
- [Server.server.lua](../../prototype/cart-lab/Server.server.lua) assigns cart network ownership to the player and uses `ResetVersion` during reset/recovery. [Crashes.lua](../../prototype/cart-lab/Crashes.lua) evaluates potential wall hits at `Normal.Y <= 0.55` and temporarily owns ragdoll parts on the server. Full authority and recovery behavior require deeper inspection and live checks.

The M1 engine comparison provides a useful regression baseline:

| Measurement | Empty | Full |
|---|---:|---:|
| Time to speed 40 | 1.1333 seconds | 1.6000 seconds |
| Stop distance from 40 | 8.0713 studs | 10.8433 studs |
| Stop time from 40 | 0.4667 seconds | 0.6000 seconds |
| Charged launch speed | 26 | 26 |
| Jump rise | 3.2273 studs | 3.2273 studs |

Preserve the direction of the load effect and the enjoyable jump. New physics may change exact measurements; report the comparison rather than silently updating expected values.

## Resolve proposal conflicts before coding

Use the [handling brief](../cart-handling-weight-brief-2026-09-09.md), [air brief](../cart-air-tricks-turning-brief-2026-09-09.md), [control brief](../cart-control-model-brief-2026-09-09.md), [one-button brief](../cart-one-button-input-brief-2026-09-09.md), and [contact brief](../cart-contact-model-brief-2026-09-09.md) in their documented supersession order. Preserve one force solver in the proposed contact candidate. Do not resurrect the superseded ground-velocity/air-force split.

Several details need a concrete design resolution before accepting the candidate:

1. The one-button brief says every release before `TapSeconds = 0.12` is a plain hop, but suggests drift commitment after `DriftEngageSeconds = 0.1`. A turn held for 0.11 seconds falls into both rules. Gate irreversible drift commitment until tap eligibility ends, or revise the thresholds explicitly. Test that boundary first alongside the camera-only regression.
2. Ground intent uses raw lateral input. Air tricks include forward/back rotation in the earlier brief. The proposed `lateral` scalar alone cannot represent pitch tricks. Choose a typed raw movement vector, or explicit raw lateral and longitudinal fields, while keeping resolved driving steer separate.
3. The one-button brief leaves ground-to-air hold carry undecided. Carrying a hold can turn a charged jump into an immediate dive/trick. Compare carry and fresh-press behavior in an isolated candidate using identical terrain and inputs.
4. The contact brief says `ProbeLength` must exceed `RideHeight + GroundContactMargin + ContactFalloff`. Its proposed 4.25 is less than 2.5 + 0.35 + 1.5 = 4.35. Define what probe distance measures, then reconcile this relation before accepting constants.
5. The proposed `smoothstep(0.05, 0.30, Normal.Y)` gives zero traction contact at a vertical surface. Lowering the support cutoff alone does not prove vert riding. Record support force, contact, speed, normal, and height through the transition to determine whether momentum and springs deliver the intended climb.
6. Contact blending must cover support-relative velocity and surface-normal accumulation as well as drive force. Current sums use only probes within the hard grounded range. Reporting a smooth contact scalar while retaining discontinuous normals can leave the original pop.
7. Raising base air gravity from 0.5 toward 0.85 with launch speed unchanged reduces flat-jump rise. That conflicts with preserving the enjoyed jump unless the candidate is accepted through comparison. Treat ramp pop and flat jump as separate measurements.
8. Drag exemption during drift or boost and a claimed absolute terminal ceiling need reconciliation. Gravity still acts during those exemptions. Test downhill drift and repeated boost, not just held throttle; specify the permitted transient overspeed instead of calling an assist budget a hard speed limit.
9. Quarter-pipe support and wall-crash classification must change together. `Crashes.lua` currently considers steep surfaces potential walls. Preserve intentional ordinary-wall crashes without ejecting riders on authored park transitions.

## Assign source ownership

| Owner | Primary source | Shared boundary |
|---|---|---|
| Movement | `packages/RideRuntime/{Chassis,Profiles,Gesture,CameraDirection}.lua` | Own solver, profile, input intent, telemetry, and movement acceptance. Keep shared ride code canonical. |
| Movement | `prototype/cart-lab/{Client.client,Crashes,Runner,Feedback}.lua` | Coordinate action prompts and HUD with the UI owner. Preserve camera and rider recovery. |
| Environment | `prototype/superstore/PracticePark.lua`, market construction, and authored geometry | Supply tagged/identified rideable surfaces, physical measurements, test routes, safe landings, and clear shopping bays. Final surface metadata scheme remains a joint design decision. |
| Gameplay integration | `src/ServerScriptService/RoundManager.server.lua`, `RoomService.server.lua`, and round integration source | Cohort lifecycle, checkout deadline, completed collection, and actual Style consumption. `RoundPhase` and `RoundId` are per player; global `GamePhase` stays `Hub`. |
| Shared, one editor at a time | `prototype/cart-lab/Server.server.lua`, `ShoppingSession.lua`, `Shopping.lua`, `Cargo.lua`, `PickupRules.lua` | Cart owner/recovery, authoritative stock and capacity, cargo identity, final checkout, and client target agreement. Gameplay owns final collection policy; movement owns chassis lifecycle. |

The orchestrator identifies the exact saved scene and controls Studio access. A local Studio window with PlaceId 0 is not sufficient evidence of the intended source or scene. Keep build output distinct from canonical source and retain Studio-owned assets when saving a candidate.

## Agree on a measurable environment contract

All geometry and tuning values below are trial conditions or existing brief targets. None is an accepted store dimension. Measure the current Hillside course and cart before the environment agent commits a finished layout.

Let `W`, `L`, and `H` describe the largest observed rider-and-loaded-cart envelope. Start from the 5-by-1-by-7 chassis, then measure actual cargo, pose, camera clearance, and colliders separately. Keep readable stacks rather than shrinking every piece to satisfy lane width.

| Area | Contract and measurable acceptance |
|---|---|
| Main shopping route | Every core furniture/decor section and checkout is reachable without jumping or trick input. Trial two-way lanes at 3 `W`, intersections at 4 `W`, then widen against measured turn radius and visibility. Two loaded carts pass ten times without shelf contact. |
| Pickup bays | Keep a flat approach at least the measured full-load braking distance plus one cart length before the intended stop point. A player can select either of two adjacent pieces using the displayed target. Server pickup rules agree with that target. |
| Fast line | Size banks and corners from measured turn radius at 30, 60, and 80 studs per second, as applicable to the accepted profile. Mark and separate the fast line before it merges into a shopping lane. No jump landing ends in a pickup queue. |
| Terminal speed | The handling brief proposes 78 to 82 studs per second after testing the steepest drivable slope. Hold throttle for eight seconds and establish convergence. Repeat while loaded, drifting, and boosting; record peak transient speed and its allowed duration. |
| Rollers and lips | Record proposed `contact`, existing grounded boolean, speed, normal, and support force at 60 Hz. The contact brief's trial target is no contact step greater than about 0.3 across a lip at 30 and 60 speed. Compare actual crest pop and bump retention against M1. |
| Quarter pipe | Test 10 and 50 studs-per-second entries. A slow rider slides back without sticking. Faster entry gains height in proportion to entry speed. Ordinary store walls remain nonrideable at aisle-reachable speed and retain intended crash recovery. |
| Jump and landing | Preserve the flat charged-jump comparison, then measure ramp height against lip pitch and speed. Broad connected-floor bypasses and recoverable misses come first. Clean landing trial retains at least 95% horizontal speed; bad-landing loss is bounded by the accepted profile. |
| Pump gain | Flat-ground button holds add no pump speed. A valid roller adds at most the configured gain and does not refill its budget through contact chatter. Compare throttle-free coasting with the same line and held pump input. |
| Recovery | Preserve the existing wall-ejection and pose-restoration behavior. Set a beta recovery-time target after measuring M1. In ten reset, missed-line, and wall-impact trials, return to a valid nearby route with expected cargo and no stuck input. |
| Devices | Desktop, physical gamepad, actual touch phone, and tablet complete steering, braking, intended jump/drift/dive, grab, reset, and camera use. Menus, focus loss, text entry, and dismount require a fresh action press. Narrow-phone layout remains a release gate. |
| Network | Cart simulation ownership remains distinct from server authority over seating, pickup, stock, capacity, checkout, and rewards. At least two clients observe consistent recoveries and collections. Wrong-owner, wrong-round, and stale recovery requests cannot change state. |
| Performance | Record actual device and frame rate with full cargo and intended player count. Compare 30 and 60 frames per second plus normal and added-latency conditions. Select latency conditions and performance budgets with the orchestrator; do not claim server fixtures prove phone performance. |

Keep stunt awards as bounded movement boost until gameplay explicitly connects a verified route achievement to progression. A client-reported trick or cart position must not grant currency, wins, or permanent designs.

## Prioritize implementation tickets

These are proposed tickets. They do not mark any runtime behavior complete.

| ID | Priority/dependency | Work | Acceptance criteria |
|---|---|---|---|
| MP-01 | P0, first | Verify current source revision and exact candidate scene. Finish M1's interrupted comparison. | Repaired cargo suite, real wall recovery, desktop/gamepad/touch camera, and cancel/release flows have new evidence or named remaining failures. Preserve current artifacts and compare source hashes. |
| MP-02 | P0, MP-01 | Add terminal-speed control and lateral acceleration limits as an isolated handling candidate. Resolve drift/boost overspeed exemption. | Steepest-slope speed converges; 30/60/80 turn radii increase as designed; acceleration and braking retain full-load differences. Existing drift budgets and charged jumps remain functional. Publish measured current-versus-candidate values for a feel comparison. |
| MP-03 | P1, MP-02 | Add contact telemetry without behavior changes, then replace discrete traction branches in a separate increment. | First capture shows the current market/park contact distribution. Next capture proves smoother crest departure and normal/support transitions without hidden speed gain. Gesture still receives an explicit hysteretic boolean. |
| MP-04 | P1, isolated from MP-03 initially | Build the proposed one-button candidate with raw intent and resolved tap/hold rules. | Camera-only movement cannot cause drift. Tests cover 0.09/0.11/0.13-second turn-holds, jump-to-drift conversion, exactly one entry hop, counter-steer, threshold noise, and air direction axes. Real controls cancel correctly. Compare hold-carry/fresh-press variants before choosing. |
| MP-05 | P1, MP-03; environment agreement | Make intended park transitions rideable and coordinate crash classification. Add bounded pump gain only after support works. | Quarter-pipe slow/fast entry checks pass. Store walls preserve intended crash response. Pump gains nothing on flat ground and no more than the configured budget on repeated rollers. Ten missed lines recover with correct cargo and avatar state. |
| MP-06 | P1, MP-04 and MP-05 | Add optional ramp pop, dive payoff, and tricks in successive candidates if they improve shopping routes. | Ramp pop scales and caps; aligned downslope dive gains bounded speed; flat dive has bounded penalty; a clean full rotation grants boost once and an incomplete rotation does not. Cart and future board profiles stay separate. |
| MP-07 | P0 beta gate, gameplay milestone 2 | Integrate cart lifecycle with cohort-owned checkout and actual Style consumption. | Two players shop, check out, style, judge, and reach Results with exact piece/variant identity. End Shop during suction, a jump, ejection, and recovery. No delayed remount, duplicate transfer, or destroyed collection. Another active cohort and a neighborhood player remain unaffected. |
| MP-08 | P0 beta gate, assembled store | Repeat device, multiplayer, saved-scene, and first-time-user acceptance. | Normal input completes a full route and round on every supported device. At least two real clients and the chosen server-capacity scenario pass. Record pickup errors, reset counts, lap time, loaded phone performance, and checkout success. Save full scenes and compare managed sources. |

One-button input and continuous contact remain proposed work until a reviewed candidate establishes the desired result. MP-02 can investigate the observed handling problem without silently accepting every later mechanic. Optional tricks do not hold the full round integration hostage.

## Build the smallest playable slice

Use the existing Hillside market and one existing pump route as the baseline. The environment agent improves two adjacent, clearly labeled shopping sections with a flat route, an optional roller/bank line, and a safe return to checkout. Use real cargo and visible fit feedback. Preserve the current charged jump and dive while the first handling comparison runs.

First verify two players can steer, stop, choose pieces, traverse either route, recover, and checkout. Then connect that same collection to the main Style/Judge/Results cycle through gameplay milestone 2. A demonstration collection does not close the integration gate. A lap driven by a synthetic server-owned chassis does not close input feel.

Use the existing `tests/ride/Gesture.spec.lua`, `CameraDirection.spec.lua`, `CartRefinementAcceptance.lua`, `HandlingAcceptance.lua`, `PhysicsAcceptance.lua`, `DriftPhysicsAcceptance.lua`, crash replay/geometry drivers, and `tests/superstore/ParkRideAcceptance.lua` before inventing another test system. Read each driver's controls before running it. Pure tests, engine fixtures, real client input, and physical-device evidence answer different questions.

Each acceptance record needs the source revision, complete scene identity, device/input, network owner, player count, frame rate, latency setting, cargo load, route, attempt count, measurements, outcome, and artifact location. Update the current implementation report only after changing and testing its owning runtime.
