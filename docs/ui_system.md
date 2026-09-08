# UI and input systems

This map describes the current repository source as reviewed on September 8, 2026. The main game and Hillside prototype build different interfaces. [The refinement plan](refinement-plan-2026-09-08.md) is the accepted next UI direction; the broad redesign remains unimplemented.

## Main game ownership

Main client controllers are in `src/StarterPlayer/StarterPlayerScripts/`. Shared UI modules are in `src/ReplicatedStorage/`.

| UI or interaction | Owner |
| --- | --- |
| Shared colors, fonts, and widget styling | [UITheme](../src/ReplicatedStorage/UITheme.lua) |
| Registered widget visibility by activity | [UIStateManager](../src/ReplicatedStorage/UIStateManager.lua) |
| 3D catalog thumbnails | [ViewportIcon](../src/ReplicatedStorage/ViewportIcon.lua) |
| Round phase, theme, and timer banner | [RoundClient](../src/StarterPlayer/StarterPlayerScripts/RoundClient.client.lua) |
| Neighborhood card and queue status | [LobbyClient](../src/StarterPlayer/StarterPlayerScripts/LobbyClient.client.lua), [JoinRoundClient](../src/StarterPlayer/StarterPlayerScripts/JoinRoundClient.client.lua) |
| New-player guidance | [FtueController](../src/StarterPlayer/StarterPlayerScripts/FtueController.client.lua) |
| Currency, purchase panel, owned furniture, and reward toasts | [ProgressionClient](../src/StarterPlayer/StarterPlayerScripts/ProgressionClient.client.lua) |
| In-world purchase pedestals and their feedback | [LobbyBoutiqueClient](../src/StarterPlayer/StarterPlayerScripts/LobbyBoutiqueClient.client.lua) |
| Own-house detection and build-mode handoff | [HousingClient](../src/StarterPlayer/StarterPlayerScripts/HousingClient.client.lua) |
| Focused shop item selection | [ShopTargeting](../src/ReplicatedStorage/ShopTargeting.lua) |
| Bottom action prompt | [PromptController](../src/StarterPlayer/StarterPlayerScripts/PromptController.client.lua) |
| Floating prompt on the focused piece | [StoreItemPrompt](../src/StarterPlayer/StarterPlayerScripts/StoreItemPrompt.client.lua) |
| Main cart input, count, capacity, boost, and touch buttons | [CartController](../src/StarterPlayer/StarterPlayerScripts/CartController.client.lua) |
| Main cart item tray, pickup toast, and cargo presentation | [PickupEffect](../src/StarterPlayer/StarterPlayerScripts/PickupEffect.client.lua) |
| Style inventory, surface colors, and item appearance panel | [StyleController](../src/StarterPlayer/StarterPlayerScripts/StyleController.client.lua) |
| Placement ghost and placement input | [PlacementController](../src/StarterPlayer/StarterPlayerScripts/PlacementController.client.lua), [PlacementBridge](../src/ReplicatedStorage/PlacementBridge.lua) |
| Room tour, token votes, reveal, and leaderboard | [JudgeClient](../src/StarterPlayer/StarterPlayerScripts/JudgeClient.client.lua) |

`UIStateManager` derives its state from the local player's `RoundPhase` and `IsBuildMode`. `HousingClient` sets `InOwnHouse` for neighborhood decorating entry. These signals keep a player at home independent of another cohort's round.

The main shop's three visual consumers use `ShopTargeting` for the same focused piece. `CartService` remains the pickup authority. Main cart capacity is 15 items; its server cap, `CartController` display, and `PickupEffect` slot count must agree.

`StyleController` serves both competition styling and house decoration through the surrounding state and inventory sources. `ProgressionClient` still exposes owned physical furniture during Style. This is an implementation gap against the agreed round-collection rules.

The main result screen still presents automatic scoring fields from `JudgeService`. Play again, Back to neighborhood, purchase-goal progress, and inspectable earned designs are accepted next work.

## Hillside prototype ownership

| UI or interaction | Canonical source |
| --- | --- |
| Driving input, touch actions, native camera setup, capacity, charge, and session HUD | [Cart client](../prototype/cart-lab/Client.client.lua) |
| Timed session, practice and market buttons, contextual guide, and sound toggle | [StoreClient](../prototype/superstore/StoreClient.client.lua) |
| Visible item stacks and checkout motion | [Cargo](../prototype/cart-lab/Cargo.lua) |
| Rider pose and airborne tricks | [Runner](../prototype/cart-lab/Runner.lua) |
| Wheel, drift, charge, and boost visual effects | [Feedback](../prototype/cart-lab/Feedback.lua) |
| Sound samples, voice limits, and cue cooldowns | [Audio](../prototype/cart-lab/Audio.lua) |
| Floating market signs and route geometry | [Store](../prototype/superstore/Store.lua), [PracticePark](../prototype/superstore/PracticePark.lua) |

The Hillside and cart-lab projects both consume the canonical cart modules directly. Shared input or HUD changes belong in `prototype/cart-lab/`.

### Current controls and feedback

WASD or the left stick drives and steers. Right mouse drag, right-side touch drag, or the right stick orbits the camera independently. A straight press and hold of Space or JUMP charges a jump. Pressing while steering selects the hop-and-drift path. A new airborne press holds a dive; releasing returns to float. Brake, grab, and reset have separate actions.

The HUD displays `Cart space ... / 100` and `Saved ...`, with a small capacity bar and contextual checkout guidance. Full capacity already rejects a pickup, but the user reported that the filling state and weight difference were unclear. The current maximum load reduces acceleration by 12 percent and steering response by 8 percent. The jump still uses the spring sound that the user asked to remove.

The v4 camera uses Roblox's native orbit around a cart focus with an initial 28-stud distance. Mouse orbit, actual touch, controller behavior, and phone layout still need hands-on acceptance. Code inspection and zero-delta mouse-tool output do not prove usable camera input.

## Accepted next UI

The refinement plan defines the next player experience:

| Activity | Priority |
| --- | --- |
| Arrival | Recognize the player's house, the next round, the shops, and the park. Present one clear next action. |
| Shopping | Read theme, remaining time, cargo capacity, the next piece's space cost, and checkout direction. Make pickup, nearly-full, and full states visible. |
| Styling | Keep the selected piece and placement action clear. Expose compatible earned designs alongside the collected inventory. |
| Judging | Prioritize the room, theme, creator, vote, and piece inspection. |
| Results | Show outcome, reward, progress toward a chosen purchase, Play again, and Back to neighborhood. |
| Buying and furnishing | Distinguish quantity, price, ownership, preview, and placement from applying a reusable design. |
| Riding | Show only actions for the equipped ride with current-device prompts. The first skateboard adds explicit Kickflip and Grab. |

Camera-relative movement is an accepted change. Holding forward while turning the camera should turn the cart, while looking at rest should not accelerate it. Camera correction must not accidentally select drift during a charged jump. The larger megaramp and stronger loaded feel preserve the cart movement and stacked cargo the user enjoyed.

## Verification boundaries

An input change needs mouse, touch, and controller checks for motion, release, menus, and focus changes. A HUD change needs a narrow screen and the relevant Roblox inset. State transitions need the full shopping, styling, judging, results, and neighborhood sequence.

The v4 recordings omit ScreenGui HUD because of the capture path. They demonstrate movement and checkout but cannot establish HUD readability. The [playtest report](playtest-iteration-v4-2026-09-08.md) records these limits and links the actual evidence.

The [current acceptance checklist](verification.md) keeps phone layout, controller focus, input switching, and safe-area checks visible after the older issue files are archived.
