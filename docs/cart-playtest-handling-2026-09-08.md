# Cart handling playtest revision

The September 8 feedback overrides the earlier modest-jump/native-gravity baseline. This revision is local and unpublished. Mechanics testing used only CartLab Studio `bedb2a9b-faa6-4835-a71c-5c842b124cc8`.

## Driving and jumping

Ordinary steering now grips sooner, turns less sharply and coasts to a stop sooner. Drift still keeps its separate loose grip and earned additive boost. Suspension damping and upright alignment are stronger.

Hold Space/JUMP while starting straight to charge; release to jump. A new press while airborne dives until release. Holding the original drift hop does not accidentally dive. Air gravity is half normal away from support; dive gravity is 2.2 times normal. Grounded slopes retain normal gravity and momentum. Lift ends as soon as suspension probes reconnect, which fixes a hover found by the engine acceptance test.

Strong jumps choose one stable cosmetic pose for that flight: extended Superman, side kick or heel kick. Physical cart rotation is unchanged. The pose eases out during descent. Runner supports both Motor6D and AnimationConstraint rigs.

## Camera and recovery

The old camera overwrote its Scriptable CFrame every render. An actual right-drag test rotated it zero degrees. The revised camera uses Roblox's native Custom camera with an invisible, noncolliding focus above and ahead of the cart. It starts 28 studs away at a 15.95-degree downward angle; players can zoom between 12 and at least 38 studs. Tall cargo expands the maximum distance. Native right-drag, touch-drag and right stick own orbit. Camera settings restore on detach. Accepted input also clears a stale window-focus latch reproduced in Studio.

Crashes keep the incoming speed through a 0.3-second contact interval and allow 0.4 studs of horizontal tolerance for replicated contact positions. A regression using real Blockcast/overlap queries failed before this change and passes afterward. Braking before contact, low-speed bumps, glances and ram approach without contact still reject ejection.

After the rider's seat weld is removed, the cart is parked at its ride height for the 1.6-second recovery. This prevents client-owned suspension loss from sinking the visual wheels below the floor. Recovery and cancellation unpark it before remounting. Cargo is preserved.

## Measured results

| Acceptance check | Result |
| --- | --- |
| Full charge, same level floor | 0.868 to 3.230 studs peak rise, 3.72 times higher |
| Float flight | 0.183 to 0.533 seconds airborne |
| New airborne press after 0.14 seconds | 0.283-second flight; horizontal landing speed 43.989 retained |
| Release throttle at 44 | After two seconds, speed 16 versus 38 before |
| Ordinary full turn | Maximum slip 16.0 degrees versus 27.6 before; body remained upright |
| Real mounted wall impact via W | Ejection 33.9 ms after first replicated contact; baseline attempt missed ejection |
| Cart during ejection | Minimum body Y 2.50, recovery 1.602 seconds, remounted, rider health 100 |
| Empty/full terrain route | Both passed; downhill peaks 89.46/89.50, supported bank landings 63.61/61.70 |
| Drift regression | 44 to 52 held to 67.57 release; loaded 85 to 93 to 108.61; incoming 135 retained |
| Gesture/replay/geometry checks | 29 gesture scenarios, 14 source replay cases, seven real geometry cases passed |

The engine measurements and actual client pose sample are in [the evidence file](evidence/cart-playtest-handling-2026-09-08.json). `tests/ride/HandlingAcceptance.lua` runs seven parallel real assemblies with current and restored baseline profiles. Inject it as a ModuleScript into a local Play server and invoke it with `ReplicatedStorage.RideRuntime`. `tools/Build-CartLab.ps1` compiles all modules and runs the gesture suite; `tests/ride/Run-CrashReplay.ps1` runs the recorded crash cases.

The Studio mouse tool generated zero movement deltas, so native orbit and actual touch/controller operation still need hands-on verification. The camera's final type, focus, distance and pitch were measured in the client. These changes do not establish phone performance or multiplayer latency acceptance. Root records integrated market/park footage separately.

The final review also gates cart actions and raw movement on `GuiService.MenuIsOpen`. Opening the Roblox menu clears held jump/brake state and queued gesture edges. Accepted input cannot rearm focus while that menu is open. The touch action now reads JUMP to match the practice-park guide. This follow-up compiled and retained all 29 gesture cases; the integrated menu check belongs to the final client playtest.

## Roblox references

Roblox documents Custom as the default camera mode and Scriptable as having no default behavior in [CameraType](https://create.roblox.com/docs/reference/engine/enums/CameraType). Its [default bindings](https://github.com/Roblox/creator-docs/blob/main/content/en-us/includes/default-bindings.md) specify right mouse, secondary stick and touch-drag camera orbit. [VectorForce](https://create.roblox.com/docs/reference/engine/classes/VectorForce) documents applying world-space forces at the assembly center of mass, used here for float/dive without changing workspace gravity.
