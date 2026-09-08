# Hillside Market and pump park, playtest revision 4

This revision implements the September 7 evening feedback. It supersedes the older modest-jump, native-air-gravity and segmented Hillside layout decisions. The Hillside project consumes the canonical ride and cart modules directly. The prototype remains separate from production `src`, the live place, and the published Test place.

Open [the saved Hillside scene](../places/RoomRoyale-Hillside.rbxlx) in Roblox Studio and press Play. To rebuild and open it, run `pwsh -File tools/Start-HillsidePlaytest.ps1`. Add `-BuildOnly` to verify and build without opening another window. The build checks 29 gesture scenarios, shopping-session rules, Luau compilation, and Rojo packaging.

The market now has one level shopping floor, a clear center path to checkout, two broad outside shopping lanes, low displays and floating signs. Two raised jump trails end in a limited lilac chair and an Orbit halo lamp. The garden path offers an easier outside detour. The checkout tube is visible from the starting camera. The separate pump park connects through the east side and is also reachable with Try the skate park. Practice works again after a completed timed round.

The park has a continuous 24-stud-wide roller loop, broad banked turns, and an optional trick jump with a solid floor under missed landings. It is a reusable `PracticePark.build(world, optionalOrigin)` module for later neighborhood integration. It is currently beside the standalone market.

| Control | Behavior |
| --- | --- |
| WASD / left stick | Drive and steer |
| Right mouse drag / right-side touch drag / right stick | Native Roblox camera orbit |
| Start straight, hold Space or JUMP, then release | Charge and launch |
| Start steering while pressing Space or JUMP | Small hop into drift; release spends earned boost |
| Press Space or JUMP again in the air | Hold to dive; release to float |
| Shift / BRAKE | Brake |
| E / GRAB | Collect nearby furniture |
| R / RESET | Return to the market entrance |

Charged jump peak rose from 0.868 to 3.230 studs in the controlled floor comparison, 3.72 times higher. Air gravity is 0.5 times normal; holding the new airborne press uses 2.2 times gravity. Ordinary steering has more grip and less coasting. Strong launches select one of three cosmetic flight poses. Physical cart rotation remains predictable for landing.

Cargo clones the shelf's exact model at 86% scale, preserves variant identity, and stacks using its actual bounds. A 100-space fixture made a 7.261-stud-tall stack with no overlapping bounding boxes. The same carried Instances enter the tube; delivered room pieces use full shelf scale. The recorded shopping run collected the sofa, table and chair with E, carried 97 space, then drove through checkout and banked all three. Limited pieces reject grabs from below their platforms, remain claimed after the ordinary restock interval and replenish with the next round.

Wall ejection occurred 33.9 ms after the first replicated contact in the mounted keyboard test. The cart stayed at ride height during the 1.6-second recovery, remounted, and preserved the load. Menu input now cancels driving and held actions. Camera state uses native orbit with an initial 28-stud distance, rather than overwriting the view every frame.

| Evidence | What it establishes |
| --- | --- |
| [Handling results](evidence/cart-playtest-handling-2026-09-08.json) | Actual assemblies, baseline jump comparison, real W-driven wall impact, recovery, terrain/drift regression and rider pose restoration |
| [Cargo results](evidence/cart-cargo-playtest-2026-09-08.json) | Real renderer, both receipt/replication orderings, real pickup remotes, variant export, finite stock and platform guards |
| [Integrated results](evidence/hillside-integrated-v4-2026-09-08.json) | Final 13 templates including the halo lamp, 135 flat route samples, three clear lanes, camera distance, audio loads, after-round practice and keyboard recordings |
| [Park surface results](evidence/hillside-park-v4-2026-09-08.json) | 1,962 actual raycasts, including 894 joins, with no failures after correcting triangle seams |
| [Park ride results](evidence/hillside-park-ride-v4-2026-09-08.json) | Real Chassis follows the entire 144-node pump loop. The observed run took 12.85 seconds, peaked at 54.06 speed and finished at 51.13 without leaving the track or losing support. This uses a server-owned body, not a mounted rider. |

Current gameplay clips are saved in the repository: [checkout](evidence/hillside-checkout-v4.mp4), [pump loop](evidence/hillside-pump-v4.mp4), and [trick jump](evidence/hillside-trick-v4.mp4). All retain real timing. Native video capture omits the ScreenGui HUD. `hillside-pump-v4` uses the normal camera and real W, Space, airborne re-press and brake inputs. `hillside-trick-v4` uses a temporary side camera and real keyboard inputs. `hillside-checkout-v4` uses a temporary side camera, staged pickup positions with real E presses, and a real drive through the tube. Each has GIF and MP4 versions; contact sheets were inspected before sharing. Temporary review cameras are unbound afterward.

The sound palette replaces the repeated electronic ping with short pop, spring, whoosh, chime, wood and wheel samples. Group volume, per-cue cooldowns and an eight-voice cap keep repeated effects bounded. Checkout completion waits until the last item finishes. All six assets loaded successfully and the audio recording contains a nonzero signal. [The audio preview](evidence/hillside-audio-v4.mp3) is a sequential in-game cue preview. The model could not listen to that audio, so subjective sound quality still needs the user's audition.

Audio sources are public Creator Store results checked in this pass: [pop](https://create.roblox.com/store/asset/6586979979), [spring](https://create.roblox.com/store/asset/2772396665), [Pro Sound Effects whoosh](https://create.roblox.com/store/asset/9120709477), [chime](https://create.roblox.com/store/asset/99980076888596), [Pro Sound Effects wood thud](https://create.roblox.com/store/asset/9126267420), and [Pro Sound Effects bicycle landing](https://create.roblox.com/store/asset/9113426478).

The [research brief](playtest-design-research-2026-09-08.md) links Roblox guidance and first-party examples from Grow a Garden, Dress to Impress and Nintendo. It separates documented patterns from recommendations; the reference games were not played during this pass.

Hands-on checks remain for mouse orbit, touch/controller behavior, Escape-menu input and phone performance. The Studio mouse tool returned zero movement deltas, and its keyboard tool rejected the protected Escape key. The camera implementation and menu guard were checked in code, but those tool limitations do not prove actual device interaction. Studio recordings ran at variable frame rates with several windows open; they do not establish a phone performance budget. Some inherited furniture roughness/metalness texture assets reported permission errors in the local place; exact model/variant copying and geometry still passed.

For tonight, start with one shopping lap without explanation, a full cart checkout, then the pump rollers and trick gap. Judge the charge arc, dive timing, camera framing of a tall stack and the sound preview separately. The main tuning values are in `packages/RideRuntime/Profiles.lua`, shared directly by both prototype projects.
