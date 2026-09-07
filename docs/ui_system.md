# UI System Map

Last updated: March 25, 2026 (post-beta-polish pass)

## Purpose
This document is the working UI architecture map for the live `Shop and Shine` place.

Use it when:
- Claude or Codex needs to find the right script quickly
- adjusting placement, opacity, size, or styling of on-screen UI
- changing interaction flow without introducing duplicate logic
- deciding whether a change belongs in a `LocalScript`, `ModuleScript`, or server script

This is an implementation map, not a tone doc.

For game direction and player-facing tone, use [AGENTS.md](/C:/Users/jaked/Documents/New%20project/AGENTS.md).
For non-UI gameplay system ownership, use [docs/game_systems.md](/C:/Users/jaked/Documents/New%20project/docs/game_systems.md).

Do not use older handoff notes or extracted snapshots as the source of truth for UI architecture. The live Studio place and this doc should win.

## Source Of Truth
- `src/` is the source of truth for UI scripts imported from the test place on September 6, 2026.
- The Studio test place still owns UI instances that runtime scripts do not create and that have not been imported into Rojo.
- Local extracted Lua files in `rbxlx_extract/` and `rbxlx_extract_updated/` are reference-only and may be stale.
- Shared UI palette, typography, radii, and helper factories live in `ReplicatedStorage.UITheme`.

## High-Level Structure
The current UI is intentionally split by responsibility:

- `RoundClient`: top phase/theme/timer banner
- `PromptController`: bottom-center custom prompt chip
- `StoreItemPrompt`: in-world shop hover prompt
- `CartController`: cart HUD, boost pill, cart controls, cart highlight
- `PickupEffect`: bottom inventory/item bar, pickup toast, cart slot visuals
- `StyleController`: style phase panel, floating customize card, wall/floor/item styling UI
- `JudgeClient`: judge phase cards, voting UI, reveal UI

This split is good and should stay.

What must stay centralized:
- shop item target selection
- global theme styling
- shared event names / replicated state

## Core Rule
If multiple scripts need to show the same state, one place should decide that state and the other scripts should render it.

Current examples:
- Good: `ShopTargeting` decides which shop item is focused, and multiple UI scripts read from it.
- Bad: a future script independently raycasts for "nearest" or "hovered" items and disagrees with `ShopTargeting`.

## Live UI Ownership Map

### Shared Modules

#### `ReplicatedStorage.UITheme`
Owns:
- shared color palette
- font choices
- corner radius presets
- stroke presets
- padding presets
- phase color helpers
- convenience UI builders like `MakeCard`, `MakePanel`, `MakeButton`

Edit here when changing:
- project-wide palette
- overall warmth / softness
- shared border strength
- common typography feel

Do not:
- put per-screen layout positions here
- put phase-specific interaction logic here

#### `ReplicatedStorage.ShopTargeting`
Owns:
- unified shop item target resolution
- hover target resolution from `mouse.Target`
- nearest-item fallback for touch-only flows
- range checks
- player-to-item distance checks
- human-readable item names for prompts

Key API:
- `DEFAULT_DISTANCE`
- `ResolveStoreItem(instance)`
- `GetStoreItemPosition(item)`
- `IsStoreItemAvailable(item)`
- `GetDistanceToPlayer(player, item)`
- `IsInRange(player, item, maxDistance)`
- `GetDisplayName(item)`
- `GetPointedStoreItem(target)`
- `FindNearestStoreItem(player, maxDistance)`
- `GetShopFocusTarget(player, pointedTarget, maxDistance, allowNearestFallback)`

This is the current source of truth for shop focus.

Edit here when changing:
- hover targeting rules
- pickup distance feel
- mouse vs touch fallback behavior

Do not:
- build GUI here
- fire remote events here

#### `ReplicatedStorage.ViewportIcon`
Owns:
- creating `ViewportFrame` item thumbnails from `ReplicatedStorage.ItemAssets`
- 3D icon framing and camera setup
- emoji fallback by item category

Edit here when changing:
- item thumbnail camera angle
- icon lighting
- fallback emoji table
- viewport cleanup behavior

## Client UI Scripts

### `StarterPlayer.StarterPlayerScripts.RoundClient`
Phase ownership:
- all phases

Owns:
- centered top phase/theme/timer card
- round theme label in the banner
- countdown text
- timer fill bar
- entrance / exit tween for the banner
- responsive banner scale

Main visual controls:
- `bg.Size`
- `bg.Position`
- `BANNER_SHOW_POS` (varies by phase: Lobby=52, Shop=52, Default=52)
- `bg.BackgroundTransparency`
- `accentBar.Size`
- `phaseLabel.TextSize` (31px)
- `timerLabel.TextSize` (20px)
- `themeSubtitle.TextSize` (17px)
- `timerTrack.Size`
- `timerTrack.BackgroundTransparency`

Use this file when changing:
- top banner placement
- top banner size
- top banner opacity
- progress bar visuals

Current beta-polish notes:
- `RoundClient` is now the primary round-context HUD for shop, style, judge, and results.
- Avoid reintroducing a second persistent theme card in shop or style.
- The top banner respects the Roblox top inset and uses a centered content block so title text stays clear of the core top-left strip.
- Title and subtitle sizing were increased during the March 25 polish pass for better readability on desktop and tablet.
- The banner uses a subtle center backing plate and stronger text contrast so theme copy stays readable over bright store ceilings.
- The live layout is a focused centered card at the top of the screen, not a full-width strip.
- Lobby uses its own lower resting offset; Shop sits a bit higher; remaining phases share a middle default offset.
- Theme subtitle copy is a single line per round, preferring the main prompt over concatenating both hint and prompt.
- The first reveal snaps directly to its resting position instead of tweening in partially clipped on initial Lobby load.
- The banner is not auto-hidden in `Lobby` after `RoundEnded`; only `Results` collapses the top card automatically.
- **The banner bottom edge lands at approximately Y=148 (showY=52 + height=96). Any panel that must clear the banner should use Y ≥ 164.**

### `StarterPlayer.StarterPlayerScripts.PromptController`
Phase ownership:
- generic prompts across phases
- shop bottom prompt override

Owns:
- bottom-center prompt pill
- generic custom `ProximityPrompt` rendering
- hold-progress fill
- shop `E` / gamepad pickup prompt when on foot
- prompt placement by phase
- suppression of conflicting prompts in shop and style

Important behavior:
- In `Shop`, this does not trust raw `ProximityPrompt` state for item pickup.
- It asks `ShopTargeting` for the focused item and renders the bottom prompt from that target.

Main visual controls:
- `root.Size`
- `root.Position` (Y offset by phase: Shop=-222, Style=-96, Judge=-84, Default=-92)
- `root.BackgroundTransparency`
- `keyBubble.Size`
- `keyBubble.BackgroundTransparency`
- `actionLabel.TextSize`
- `objectLabel.TextSize`
- `progressTrack.BackgroundTransparency`
- `updatePromptLayout()`

Use this file when changing:
- bottom prompt placement
- bottom prompt width/height
- bottom prompt opacity
- keyboard/gamepad pickup feel when on foot

Current beta-polish notes:
- The shop prompt uses device-aware labels: `E`, `X`, and `Tap`.
- Vertical offset is tuned to clear the larger bottom tray.

Do not:
- add separate shop hover targeting here
- create world-space hover billboards here

### `StarterPlayer.StarterPlayerScripts.StoreItemPrompt`
Phase ownership:
- shop only

Owns:
- floating `BillboardGui` prompt for the currently focused shop item
- hover ring size and prompt chip visuals
- item rarity ring colors
- "Click to grab" / "Tap to grab" / "Drive closer" messaging

Important behavior:
- This is visual-only.
- It uses `ShopTargeting` and stays in sync with `PromptController` and `CartController`.

Main visual controls:
- `PROMPT_SIZE` (132×70)
- `NORMAL_RING_SIZE` (40)
- `FOCUS_RING_SIZE` (50)
- `bb.StudsOffset`
- ring / pill / action transparencies in `updatePromptVisual`
- `action.Size`
- `pill.Size`
- `emojiLabel.TextSize`

Use this file when changing:
- on-item prompt size
- hover prompt opacity
- on-item prompt height above furniture
- rarity ring readability

Do not:
- fire pickup remotes directly from this script
- add independent nearest-item selection logic

Current beta-polish notes:
- The focused prompt is slightly enlarged and in-range contrast strengthened so hover prompts stay readable while driving.

### `StarterPlayer.StarterPlayerScripts.CartController`
Phase ownership:
- shop only

Owns:
- cart driving input (keyboard, gamepad, touch)
- boost mechanic and boost HUD pill
- cart count pill (top-left)
- cart capacity bar
- item highlight (`SelectionBox` + `Highlight`) on focused store items
- push animation playback
- drift and spark/dust particle effects
- wheel sounds
- touch button layout via `ContextActionService`

Cart capacity: **15 items** (matches server `CartService.CART_CAPACITY`).

Main visual controls:
- `cartBadge.Size` (148×52, top-left)
- `cartBadge.Position` (UDim2.new(0, 14, 0, 56))
- `cartLabel.TextSize` (22px)
- `cartMetaLabel.TextSize` (10px)
- `cartBarFill` capacity bar
- `boostFrame.Size` (200×42)
- `boostFrame.Position` (UDim2.new(0.5, 0, 1, -150)) — sits 26px above the inventory tray top edge
- `TOUCH_POSITIONS` table for touch button placement

Use this file when changing:
- cart count display
- boost indicator position or style
- touch control button layout
- cart highlight color or style

Current beta-polish notes:
- Legacy `grabHint` Frame and its two TextLabel children have been removed. The grab state is shown via `StoreItemPrompt` BillboardGui only.
- Touch controls are laid out around the larger bottom shop tray.
- Boost frame is at `Y -150` to clear the inventory tray top edge.
- Cart capacity bumped to 15.

Do not:
- re-add a separate grab hint overlay here
- add independent nearest-item raycasting

### `StarterPlayer.StarterPlayerScripts.PickupEffect`
Phase ownership:
- shop only (inventory bar), pickup animation fires on `CartItemAdded`

Owns:
- bottom inventory slot tray (15 slots, 68px each, tray 1160px wide)
- pickup toast notification
- 3D item boxes glued to cart body in world space
- ViewportFrame 3D icons in inventory slots
- slot drop interaction (`RequestDropCartItem`)

Main visual controls:
- `MAX_ITEMS` = 15
- `invFrame.Size` (UDim2.new(0, 1160, 0, 104))
- `invFrame.Position` (UDim2.new(0.5, 0, 1, -20))
- `SLOT_SIZE` = 68
- `pickupToast.Size` (UDim2.new(0, 280, 0, 44))
- `pickupToast.BackgroundTransparency` (0.08 — nearly opaque)
- `pickupToast.TextSize` (18px, Heavy font)
- `pickupToast.Position` resting at `Y -178`, spawn at `Y -162`, fade-out at `Y -158`
- `pickupToast` stroke: `Sage`, thickness 1.5, transparency 0.18

Use this file when changing:
- inventory tray size or slot count
- pickup toast visibility, size, or position
- 3D cart box layout or cart-follow behavior
- slot drop behavior

Current beta-polish notes:
- Slot count expanded to 15 to match new cart capacity.
- Toast is now large, nearly opaque, Heavy font at 18px — clearly readable above the tray.
- Toast resting position is `Y -178`, well above the tray top edge (`Y -124`).
- Tray width expanded from 840 to 1160 to fit 15 slots at 68px each with padding.

### `StarterPlayer.StarterPlayerScripts.StyleController`
Phase ownership:
- style only

Owns:
- right-side style panel (300px wide, vertically centered)
- item tab (cart contents as 3D icons, click to place)
- walls tab (color swatches → `SetRoomSurface`)
- floor tab (material + color swatches → `SetRoomSurface`)
- floating customize card for placed items and surfaces
- room prompt suppression in `PromptController`

Main visual controls:
- `panel.Size` (UDim2.new(0, 300, 0, 404))
- `panel.Position` (UDim2.new(1, -16, 0.5, 0), right edge anchored)
- `customizeToggle.Position` (UDim2.new(1, -22, 1, -22), bottom-right)
- `headerCard`, `tabBar`, `content` internal layout

Use this file when changing:
- style panel size or position
- tab layout or content areas
- floating customize popup
- surface/item color and material pickers

Current beta-polish notes:
- Panel is right-side anchored at 50% vertical — no collision with bottom zone.
- `customizeToggle` is bottom-right anchored — no collision with bottom-center tray or prompt.

Known debt:
- `StyleController` is large and may eventually be worth splitting into: style panel, floating customize popup, and surface prompt billboards.

### `StarterPlayer.StarterPlayerScripts.JudgeClient`
Phase ownership:
- judge only

Owns:
- theme card (shown briefly at judge phase start)
- tour panel (room tour overlay)
- vote panel (token voting UI)
- reveal panel (score breakdown + leaderboard)
- leaderboard
- voter avatar row
- keyboard / gamepad vote focus and submission

Main visual controls:
- `themeCard.Size` (352×132)
- `themeCard.Position` (UDim2.new(0.5, -176, 0, 70))
- `tourPanel.Size` (UDim2.new(0.7, 0, 0, 90)) — 70% screen width, responsive
- `tourPanel.Position` (UDim2.new(0.5, 0, 0, 164)) — clears the RoundClient banner bottom edge (Y≈148)
- `tourPanel.AnchorPoint` (0.5, 0)
- `votePanel.Size` (UDim2.new(0.88, 0, 0, 216)) — 88% screen width, responsive
- `votePanel.Position` (UDim2.new(0.5, 0, 1, -232))
- `votePanel.AnchorPoint` (0.5, 0)
- token buttons: `UDim2.new(0.22, 0, 1, 0)` — 22% of row width each, scale-based
- token layout padding: `UDim.new(0.025, 0)` — proportional gap
- selected token highlighted via `UIScale` (1.06×), not size swap
- `revealPanel.Size` (UDim2.new(0.88, 0, 0, 400)) — 88% screen width, responsive
- `revealPanel.AnchorPoint` (0.5, 0.5)
- `revealPanel.Position` (UDim2.new(0.5, 0, 0.5, 0)) — true center
- `revealPanel` entrance tween: slides from `Y=0.62` to `Y=0.5` with transparency `1→0.12`
- `breakdownFrame.Size` (UDim2.new(0.5, -18, 1, -80))
- `leaderboardFrame.Size` (UDim2.new(0.5, -18, 1, -80))
- `backdrop.BackgroundTransparency`

Use this file when changing:
- judge overlay card sizes
- voting row button style
- reveal panel layout
- leaderboard row presentation

Current beta-polish notes:
- All judge panels are now responsive (scale-relative widths) — no fixed pixel widths that break at non-standard resolutions.
- Tour panel clears the RoundClient banner by sitting at `Y=164`.
- Token button selection state uses `UIScale` instead of swapping `Size` values, which works correctly at any panel width.
- Reveal panel entrance tween fades in and slides up rather than popping in from a fixed pixel offset.
- Nil-guards added on `payload.personal` and `payload.mechanicalTheme` in the `VoteReveal` handler so a malformed server payload cannot crash the client.
- Shop/style reminder cards are no longer part of the active flow; `RoundClient` owns round context.
- Vote selection supports click, keyboard, and controller from the same local state.

### `StarterPlayer.StarterPlayerScripts.PlacementController`
Phase ownership:
- style only

Current relevance to UI:
- not a primary HUD owner
- responsible for placement interaction state and ghost behavior
- should be considered whenever style click interactions change

If changing style click flow, coordinate with:
- `StyleController`
- `PlacementBridge`

### `StarterPlayer.StarterPlayerScripts.CartImpactEffects`
Current relevance:
- presentation/effects, not primary HUD layout

### `StarterPlayer.StarterPlayerScripts.RagdollController`
Current relevance:
- gameplay/state visuals, not primary HUD layout

## Server Scripts That Support UI

### `ServerScriptService.CartService`
Owns:
- server cart spawn/mount state
- server cart contents
- validation for item pickup
- **server-side cart capacity enforcement** (`CART_CAPACITY = 15`)
- click/tap pickup via `ClickDetector`
- drop cart item flow
- cart display item rebuilds
- enabling/disabling shop pickup infrastructure

Critical UI-adjacent rule:
- client chooses a target item visually
- server validates that target before pickup
- **server enforces the 15-item cap in `addItemToCart` — client-side check is supplementary only**

Shop pickup entry points:
- `RequestGrabItem`
- `ClickDetector.MouseClick`

This script should remain the final pickup authority.

### `ServerScriptService.StoreSetup`
Owns:
- spawning and tagging store items
- item attributes like `ItemId`, `ItemName`, `Claimed`

UI relevance:
- `StoreItemPrompt` and `ShopTargeting` rely on `StoreItem` tags and item attributes created here

### `ServerScriptService.RoundManager`
UI relevance:
- phase progression
- timer state
- drives remote events consumed by `RoundClient`, `StyleController`, and `JudgeClient`

### `ServerScriptService.JudgeService`
UI relevance:
- sends judge-tour, vote, and reveal payloads consumed by `JudgeClient`
- `VoteReveal` payload shape: `{ mechanicalTheme, aestheticTheme, personal, leaderboard, revealDuration }`
- `personal` contains: `rank, userId, name, aesthetic, mechanical, participation, total, voters, mechanicalBreakdown`
- `mechanicalBreakdown` contains: `score, requiredMet, matchedRequired, missingRequired, matchedBonus`

### `ServerScriptService.RoomService`
UI relevance:
- style-room ownership and surface/item state used during style and judge phases

## Event And Data Flow

### Shared Replicated Folder
`ReplicatedStorage.Events`

Current major UI-consumed events include:
- `PhaseChanged`
- `TimerTick`
- `RoundStarted`
- `RoundEnded`
- `RequestGrabItem`
- `CartItemAdded`
- `CartCountChanged`
- `GetCartContents`
- `RequestDropCartItem`
- `RequestCartDismount`
- `SetRoomSurface`
- `SetItemAppearance`
- `ResetItemAppearance`
- `PickupPlacedItem`
- `ItemPlaced`
- `OpenSurfacePicker`
- `OpenItemAppearance`
- `JudgePhaseStart`
- `TeleportToRoom`
- `SubmitVote`
- `VoteReveal`

## Phase-by-Phase Ownership

### Shop Phase
Visual owners:
- `RoundClient`: top banner
- `CartController`: cart pill, boost pill, touch controls, highlight
- `PickupEffect`: bottom inventory tray (15 slots)
- `PromptController`: bottom-center action prompt
- `StoreItemPrompt`: in-world hover prompt

Interaction owners:
- `ShopTargeting`: current focused item
- `CartService`: server pickup validation + capacity cap

### Style Phase
Visual owners:
- `RoundClient`: top banner
- `StyleController`: panel, tabs, customize toggle, popup, room prompts
- `PromptController`: generic custom prompts, with surface prompt suppression

Interaction owners:
- `PlacementController`
- `PlacementBridge`
- `StyleController`
- server surface/item remotes

### Judge Phase
Visual owners:
- `JudgeClient`: all judge panels (tour, vote, reveal)
- `RoundClient`: top phase banner

Interaction owners:
- `JudgeService`
- `JudgeClient`

## Visual Tuning Guide
When editing visuals, use this rule:

- shared color / font / stroke feel: `UITheme`
- top banner: `RoundClient`
- bottom prompt: `PromptController`
- on-item shop prompt: `StoreItemPrompt`
- cart and boost pills: `CartController`
- bottom item bar: `PickupEffect`
- style panel / floating popup: `StyleController`
- judge overlays: `JudgeClient`

### Fast "Where Do I Edit This?" Map
- Theme bar too big or opaque → `RoundClient`
- Bottom `E` prompt too low/high → `PromptController`
- Hover ring too strong → `StoreItemPrompt`
- Cart count pill too visible → `CartController`
- Boost indicator position → `CartController` (`boostFrame.Position`, currently `Y -150`)
- Item tray too tall or too small for touch → `PickupEffect`
- Item tray slot count → `PickupEffect` (`MAX_ITEMS`) AND `CartController` (`CART_CAPACITY`) AND `CartService` (`CART_CAPACITY`) — all three must match
- Pickup toast too small/invisible → `PickupEffect` (`pickupToast` size, transparency, font)
- Style panel too intrusive → `StyleController`
- Judge vote buttons too small → `JudgeClient` token button `Size`
- Judge tour panel overlapping banner → `JudgeClient` `tourPanel.Position` Y offset (must be ≥ 164)
- Reveal panel not showing → `JudgeClient` `VoteReveal` handler + `revealPanel` visibility

## Rules To Preserve

### 1. One Shop Focus Source
All shop item focus logic stays in `ShopTargeting`.

Affected scripts:
- `PromptController`
- `StoreItemPrompt`
- `CartController`

Do not add a separate nearest-item pass in any of those scripts.

### 2. UITheme Owns Shared Style
If a color or font is meant to feel global, define or reference it in `UITheme` instead of repeating raw `Color3.fromRGB(...)` values.

### 3. Server Validates Pickup
All pickup must be validated in `CartService`, even if the client prompt/hover UI changes. The server also enforces the capacity cap — do not rely on the client check alone.

### 4. Visual Scripts Stay Area-Based
Prefer separate scripts by screen area or phase.

Good:
- one script for shop hover prompt
- one script for bottom inventory tray
- one script for top banner

Risky:
- one script randomly moving another script's HUD
- multiple scripts building the same widget

### 5. Cart Capacity Must Stay In Sync
`CART_CAPACITY` exists in three places and all three must always match:
- `CartService` (server authority, enforces the cap)
- `CartController` (client display)
- `PickupEffect` (`MAX_ITEMS`, drives slot count)

Current value: **15**

### 6. Judge Panels Must Clear The Banner
The RoundClient banner bottom edge is at approximately `Y=148` during judge phase. Any judge panel that appears near the top of the screen must use `Y ≥ 164` to avoid overlap.

## Known UI Debt
- `StyleController` is doing a lot and may eventually be worth splitting into: style panel, floating customize popup, surface prompt billboards.
- `CartController` legacy `grabHint` stubs have been removed as of March 25 pass.
- `PromptController` still juggles generic prompts and custom shop behavior in one place.
- `docs/claude_handoff.md` is outdated and should not be used for current UI assumptions.
- `JudgeClient` uses local `makeCorner`/`makeStroke`/`makeLabel` helpers rather than UITheme factories. These are intentional (different stroke transparency targets for dark-adjacent surfaces) but worth eventually reconciling.

## Recommended Read Order For UI Work
If a model or dev is starting UI work, read in this order:

1. [AGENTS.md](/C:/Users/jaked/Documents/New%20project/AGENTS.md)
2. [docs/ui_system.md](/C:/Users/jaked/Documents/New%20project/docs/ui_system.md)
3. `ReplicatedStorage.UITheme`
4. `ReplicatedStorage.ShopTargeting`
5. the phase-specific UI script being edited
6. the related server script if interaction behavior is involved

## Short Summary
The UI system is organized by screen area and phase.

The most important implementation rules:
- keep layout ownership split by UI area
- keep shared logic centralized
- keep cart capacity in sync across all three locations (server + CartController + PickupEffect)

For shop specifically:
- `ShopTargeting` chooses the item
- `PromptController`, `StoreItemPrompt`, and `CartController` display that choice in different ways
- `CartService` validates and executes pickup, and enforces the 15-item cap

That separation should be preserved as the project evolves.
