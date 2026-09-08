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
| Driving input, touch actions, native camera setup, charge, and session HUD | [Cart client](../prototype/cart-lab/Client.client.lua) |
| Timed session, practice and market buttons, contextual guide, and sound toggle | [StoreClient](../prototype/superstore/StoreClient.client.lua) |
| Capacity, focused piece and pickup request | [Shopping](../prototype/cart-lab/Shopping.lua), [PickupRules](../prototype/cart-lab/PickupRules.lua) |
| Visible item stacks and checkout motion | [Cargo](../prototype/cart-lab/Cargo.lua) |
| Rider pose and airborne tricks | [Runner](../prototype/cart-lab/Runner.lua) |
| Wheel, drift, charge, and boost visual effects | [Feedback](../prototype/cart-lab/Feedback.lua) |
| Sound samples, voice limits, and cue cooldowns | [Audio](../prototype/cart-lab/Audio.lua) |
| Floating market signs and route geometry | [Store](../prototype/superstore/Store.lua), [PracticePark](../prototype/superstore/PracticePark.lua) |

The Hillside and cart-lab projects both consume the canonical cart modules directly. Shared input or HUD changes belong in `prototype/cart-lab/`.

### Current controls and feedback

The milestone-1 candidate uses camera-relative WASD, controller and touch movement. `CameraDirection` resolves movement through the horizontal camera heading. Jump uses Space, A/R1 or JUMP; drift uses Ctrl, L1 or DRIFT; brake uses Shift, L2 or BRAKE. Separate drift intent lets camera corrections coexist with jump charge. Menus, focus loss, text entry and dismount cancel held actions. Hillside's Controls button exposes device-specific action prompts.

`Shopping.lua` owns the animated used/free capacity, delivered count, focused merchandise and fit result. `PickupRules.lua` supplies shared targeting rules. GRAB sends the displayed pickup ID, while the server validates pickup eligibility. Full-load acceleration falls by 30 percent and braking acceleration by 25 percent. The jump cue is removed.

The [milestone-1 report](cart-refinement-m1-2026-09-08.md) contains desktop ScreenGui evidence and paired engine measurements. The user stopped computer use before phone capture and the repaired cargo-suite rerun. Physical mouse, touch, controller, safe-area and subjective feel checks remain open.

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

The milestone-1 candidate implements camera-relative movement and stronger load effects. Holding forward while turning the camera turns the cart, while looking at rest supplies no drive input. Separate drift intent preserves charged jumps during camera correction. Device acceptance remains open. The larger megaramp belongs to a later milestone.

## Verification boundaries

An input change needs mouse, touch, and controller checks for motion, release, menus, and focus changes. A HUD change needs a narrow screen and the relevant Roblox inset. State transitions need the full shopping, styling, judging, results, and neighborhood sequence.

The v4 recordings omit ScreenGui HUD because of the capture path. They demonstrate movement and checkout but cannot establish HUD readability. The [playtest report](playtest-iteration-v4-2026-09-08.md) records these limits and links the actual evidence.

The [current acceptance checklist](verification.md) keeps phone layout, controller focus, input switching, and safe-area checks visible after the older issue files are archived.
