# Game Systems Map

Last updated: March 25, 2026 (post-beta-polish pass)

## Purpose
This document maps the primary non-UI systems in the live `Shop and Shine` place.

Use it when:
- Claude or Codex needs to find the correct gameplay script quickly
- changing round flow, store logic, carts, rooms, placement, or judging
- tracing which server script owns a mechanic
- figuring out which shared modules or remotes a feature depends on

This document complements the UI map:
- [docs/ui_system.md](/C:/Users/jaked/Documents/New%20project/docs/ui_system.md)

For project direction and tone, use:
- [AGENTS.md](/C:/Users/jaked/Documents/New%20project/AGENTS.md)

## Source Of Truth
- The live Roblox Studio place is the source of truth for current systems.
- Local extracted snapshots under `rbxlx_extract/` and `rbxlx_extract_updated/` are reference-only and may be stale.
- Older handoff notes and extracted snapshots are legacy reference only and should not be used as the primary architecture source.

## Core Loop
The live game loop is:

1. `Lobby`
2. `Shop`
3. `Style`
4. `Judge`
5. `Results`
6. back to `Lobby`

Primary ownership by phase:
- `RoundManager`: decides the phase and timing
- `StoreSetup` + `CartService` + `CartCollision`: shop
- `RoomService` + `PlacementController` + `StyleController`: style
- `JudgeService` + `JudgeClient`: judge and reveal

## Main Architecture Rule
Server scripts own game state.

Client scripts should:
- render state
- collect player input
- send explicit requests

Server scripts should:
- validate phase
- validate ownership
- validate range or placement
- mutate authoritative state

## Shared Modules

### `ReplicatedStorage.ItemDatabase`
Owns:
- item catalog metadata
- item display names
- item category
- item rarity
- size, weight, price, description
- wall-mounted placement metadata

Important fields:
- `Name`
- `Type`
- `Category`
- `Rarity`
- `Size`
- `Weight`
- `Price`
- `PlacedVariant`
- `PlacementCategory`
- `PlacementSurface`

Important helpers:
- `Get(itemId)`
- `GetByType(itemType)`
- `GetByCategory(category)`
- `GetByRarity(rarity)`
- `IsWallMounted(itemId)`

System impact:
- store categorization
- prompt/category icon selection
- style placement rules
- judge theme matching

### `ReplicatedStorage.ThemeDatabase`
Owns:
- mechanical round themes
- aesthetic theme fallback
- required items for theme scoring
- bonus items for theme scoring
- round theme prompt text

Important helpers:
- `GetMechanicalTheme(themeId)`
- `GetAestheticTheme(themeId)`
- `RollThemePair(seedOrRandom)`

System impact:
- round theme selection
- top-banner theme text
- judge scoring

### `ReplicatedStorage.PlacementBridge`
Owns:
- local-only bridge between `StyleController` and `PlacementController`

Events:
- `SetItem`
- `Toggle`

Purpose:
- lets one client script tell another which item is being placed
- avoids hard coupling between style inventory UI and placement ghost logic

## Phase And Flow Systems

### `ServerScriptService.RoundManager`
Role:
- single source of truth for `GamePhase`

Owns:
- phase sequencing
- per-phase countdowns
- round number
- theme roll at round start
- remote creation for core round events

Current phases:
- `Lobby`
- `Shop`
- `Style`
- `Judge`
- `Results`

Key config:
- `MIN_PLAYERS`
- `LOBBY_WAIT_MAX`
- `LOBBY_COUNTDOWN`
- `SHOP_DURATION`
- `STYLE_DURATION`
- `JUDGE_DURATION`
- `RESULTS_DURATION`
- `SOLO_TEST_MODE`

Important outputs:
- game attribute `GamePhase`
- remotes `PhaseChanged`, `TimerTick`, `RoundStarted`, `RoundEnded`
- bindable `PhaseChangedServer`
- bindable function `RunJudgeSequence`

Important note:
- all major server systems should treat `GamePhase` and `PhaseChangedServer` as the primary phase signal

### `ServerScriptService.RoundThemeReplicator`
Role:
- mirrors theme attributes to both `game` and `ReplicatedStorage`

Why it exists:
- some client systems read round theme attributes from shared replicated locations
- this script keeps those values synced from round-manager output

Owns:
- `RoundThemeId`
- `RoundThemeLabel`
- `RoundThemeHint`
- `RoundThemePrompt`
- `MechanicalThemeId`
- `MechanicalThemeLabel`
- `MechanicalThemeHint`
- `AestheticThemeId`
- `AestheticThemeLabel`
- `AestheticThemeHint`

This is a support system, not the main theme chooser.
`RoundManager` still decides the theme.

## Shop Systems

### `ServerScriptService.StoreSetup`
Role:
- spawns the shop inventory into the world during `Shop`

Owns:
- item spawn grid
- item clone placement
- `StoreItem` tags
- `ItemId`, `ItemName`, `Claimed` attributes on world items
- clearing shop inventory on `Lobby`

Current behavior:
- clones from `ReplicatedStorage.ItemAssets`
- arranges items in a test grid
- creates custom-style `ProximityPrompt`s on spawned items
- responds to `PhaseChangedServer`

Important note:
- `CartService` later disables these legacy-style shop prompts so custom hover/click targeting can own the pickup flow cleanly

### `ReplicatedStorage.ShopTargeting`
Role:
- single source of truth for what shop item the player is focused on

This is documented in more depth in:
- [docs/ui_system.md](/C:/Users/jaked/Documents/New%20project/docs/ui_system.md)

Gameplay importance:
- if shop pickup ever feels inconsistent, inspect this first

### `ServerScriptService.CartService`
Role:
- authoritative cart and pickup system for shop

Owns:
- spawning player-owned carts
- attaching/detaching players to carts
- cart contents state
- **server-side pickup capacity enforcement** (`CART_CAPACITY = 15`)
- pickup validation
- click/tap pickup support
- drop item flow
- cart display items
- cart cleanup on phase change

Cart capacity: **15 items**

Important authoritative responsibilities:
- server validates whether a player can grab a specific store item
- server enforces the 15-item cap inside `addItemToCart` — the check runs before any item is inserted regardless of how the pickup was triggered (remote, ClickDetector, or collision knock)
- server owns cart contents
- server handles dropped or loose store items

Important remotes and bindables created/used:
- `CartItemAdded`
- `CartCountChanged`
- `RequestGrabItem`
- `RequestDropCartItem`
- `GetCartContents`
- `RequestCartDismount`
- `RagdollReattach`
- `EjectFromCart`
- `KnockLooseCartItem`

Important behavior details:
- explicit target item pickup is preferred over nearest-item fallback
- shop item `ClickDetector`s are used for mouse click and touch tap pickup
- legacy `ProximityPrompt`s on shop items are disabled to avoid competing with custom UI
- carts are destroyed when leaving `Shop`
- cart contents are cleared on `Lobby`

When to edit this file:
- pickup distance
- server grab validation
- cart capacity (must also update `CartController.CART_CAPACITY` and `PickupEffect.MAX_ITEMS`)
- cart mount/dismount logic
- click/tap pickup support
- cart inventory authority

### `StarterPlayer.StarterPlayerScripts.CartController`
Role:
- client cart driving and cart-side interaction

Non-UI responsibilities:
- reads input and drives local cart movers
- applies boost behavior
- manages push animation playback
- calls `RequestGrabItem` while in the cart
- uses `ShopTargeting` for focused item selection

This script is both gameplay and UI-adjacent.

Current beta-polish notes:
- Cart capacity bumped to **15** (`CART_CAPACITY = 15`).
- Legacy `grabHint` Frame and TextLabels removed — grab state is shown via `StoreItemPrompt` BillboardGui only.
- Cart touch controls are laid out around the larger shop tray.
- Cart count and boost readability changes live here, but server pickup authority still stays in `CartService`.
- Boost frame position is `Y -150` from bottom, clearing the inventory tray top edge.

### `ServerScriptService.CartCollision`
Role:
- cart-vs-cart collision, impact reaction, ragdoll, and loose-item knockoffs

Owns:
- proximity-based cart hit detection
- push impulse logic
- ragdoll threshold logic
- boost-ram logic
- temporary knock protection after knockdowns
- cart impact remotes

Important outputs:
- remote `RagdollStart`
- remote `RagdollEnd`
- remote `CartImpact`
- bindable `KnockLooseCartItem`

Important behaviors:
- fires `EjectFromCart` before ragdolling
- fires `RagdollReattach` after recovery if still in `Shop`
- can cause cart items to pop loose

This is a core gameplay system for shop chaos and should be treated carefully.

## Style Systems

### `ServerScriptService.RoomService`
Role:
- authoritative style-room system

Owns:
- building the `RoomTemplate`
- cloning one style room per player
- teleporting players into rooms at style start
- destroying rooms on `Lobby` and `Results`
- enabling/disabling room interaction prompts by phase
- server-side item placement
- room surface customization
- item appearance customization
- pickup of placed items back into style flow

Important remotes/functions:
- `PlaceItem`
- `ItemPlaced`
- `SetRoomSurface`
- `SetItemAppearance`
- `ResetItemAppearance`
- `PickupPlacedItem`
- `GetRoomInfo`
- `OpenSurfacePicker`
- `OpenItemAppearance`

Room template includes:
- floor parts
- wall parts
- loft floor and stairs
- bathroom partition
- `SpawnPart`
- `PlotBoundary`
- `PlacedItems` folder
- built-in wall/floor `ProximityPrompt`s for customization

Important ownership rule:
- placement and appearance changes are server-validated per room owner

When to edit this file:
- room layout or geometry
- room spawn positions
- surface prompt wiring
- placement authority
- allowed floor/wall surface sets
- appearance reset logic

### `StarterPlayer.StarterPlayerScripts.StyleController`
Role:
- style-phase player UI and interaction orchestration

Non-UI system responsibilities:
- fetches cart contents for styling
- coordinates with `PlacementBridge`
- opens customization popups for placed items and room surfaces
- reacts to server-driven `OpenSurfacePicker` and `OpenItemAppearance`
- tracks placed items client-side for item tab state

This is covered in the UI doc for screen ownership, but it is also the main style-phase client orchestrator.

### `StarterPlayer.StarterPlayerScripts.PlacementController`
Role:
- client-side placement ghost and placement input system

Owns:
- build mode state
- ghost model preview
- grid snapping
- overlap checks against placed items
- plot boundary checks
- wall-vs-floor placement logic
- rotation
- placement confirm/cancel
- mobile placement buttons (via dedicated `PlacementMobileGui`)

Important inputs:
- `PlacementBridge.SetItem`
- `PlacementBridge.Toggle`
- `PlaceItem` remote
- `PhaseChanged`

Important config:
- `GRID_SIZE`
- `MAX_PLACE_DISTANCE`
- `ALIGN_TO_SURFACE`
- `WALL_NORMAL_MAX_Y`

Important rule:
- client computes a candidate placement
- server still validates and creates the final placed item

Current beta-polish notes:
- Touch placement buttons live in a dedicated `PlacementMobileGui` created by this script.
- `StyleController` still decides which item enters placement, but `PlacementController` owns touch confirm / rotate / cancel actions.

When to edit this file:
- placement feel
- snapping
- ghost validity color rules
- wall-mounted placement rules
- mobile placement controls

### Placement Flow
Current placement flow is:

1. `StyleController` decides which item the player wants to place.
2. `StyleController` fires `PlacementBridge.SetItem`.
3. `StyleController` or input flow fires `PlacementBridge.Toggle`.
4. `PlacementController` enters build mode and shows the ghost.
5. Player rotates / moves / confirms.
6. `PlacementController` sends `PlaceItem` to the server.
7. `RoomService` validates, clones, places, and fires `ItemPlaced`.
8. `StyleController` updates its item UI state.

## Judge Systems

### `ServerScriptService.JudgeService`
Role:
- authoritative judge-phase flow

Owns:
- room order shuffling
- teleporting all players to each room
- vote collection
- mechanical theme scoring
- participation bonus
- leaderboard construction
- reveal payloads

Important remotes:
- `JudgePhaseStart`
- `TeleportToRoom`
- `SubmitVote`
- `VoteReveal`
- bindable `RunJudgeSequence`

`VoteReveal` payload shape fired to each client:
```
{
  mechanicalTheme = { id, label, hint, prompt, required, bonus },
  aestheticTheme  = { id, label, hint },
  personal = {
    rank, userId, name,
    aesthetic, mechanical, participation, total,
    voters = [{ userId, name, tokens }],
    mechanicalBreakdown = {
      score, requiredMet,
      matchedRequired, missingRequired, matchedBonus
    }
  },
  leaderboard = [{ rank, userId, name, total }],
  revealDuration
}
```

Current scoring structure:
- aesthetic score from other players' appreciation tokens
- mechanical score from required/bonus theme item matching
- participation bonus

Important rules:
- players cannot vote for their own room
- vote windows are bound to the current room owner
- reveal payload includes both personal breakdown and full leaderboard

When to edit this file:
- judge room timing
- token count rules
- theme scoring
- leaderboard sort behavior
- reveal payload structure

### `StarterPlayer.StarterPlayerScripts.JudgeClient`
Role:
- judge-phase display and local voting interface

Non-UI system responsibilities:
- submits votes through `SubmitVote`
- tracks current vote owner locally
- shows reveal data from `VoteReveal`

This is mostly UI-driven, but it is the main local participant in the judge pipeline.

Current beta-polish notes:
- Vote selection supports click, keyboard, and controller from one local selection state.
- All panels are now responsive (scale-relative widths) — no fixed pixel widths that break at non-standard resolutions.
- Tour panel sits at `Y=164` to clear the RoundClient banner bottom edge.
- Reveal panel uses `AnchorPoint (0.5, 0.5)` and scale-relative position — no hardcoded pixel offsets.
- Nil-guards added in `VoteReveal` handler for `payload.personal` and `payload.mechanicalTheme`.
- Shop/style reminder cards are no longer treated as the primary round-context HUD; that role belongs to `RoundClient`.

## Shared Remote/Event Strategy

### `ReplicatedStorage.Events`
This folder is the main replicated event surface between systems.

Important pattern:
- `RoundManager`, `CartService`, `RoomService`, and `JudgeService` all create or ensure their own remotes if missing
- this means the scripts are somewhat self-healing, but event names must stay stable

Major categories of events:

Round:
- `PhaseChanged`
- `TimerTick`
- `RoundStarted`
- `RoundEnded`
- `PhaseChangedServer`

Cart/shop:
- `RequestGrabItem`
- `CartItemAdded`
- `CartCountChanged`
- `GetCartContents`
- `RequestDropCartItem`
- `RequestCartDismount`
- `EjectFromCart`
- `RagdollReattach`
- `KnockLooseCartItem`

Style:
- `PlaceItem`
- `ItemPlaced`
- `SetRoomSurface`
- `SetItemAppearance`
- `ResetItemAppearance`
- `PickupPlacedItem`
- `GetRoomInfo`
- `OpenSurfacePicker`
- `OpenItemAppearance`

Judge:
- `JudgePhaseStart`
- `TeleportToRoom`
- `SubmitVote`
- `VoteReveal`
- `RunJudgeSequence`

## Live Instance And Naming Conventions

Current important live instance names:
- `StyleRoom_<userId>`
- `StyleRoom_<userId>_Plot`
- `PlacedItems`
- `StoreItem` tag
- `PlayerCart` tag

Important attributes used across systems:
- `GamePhase`
- `RoundThemeId`
- `RoundThemeLabel`
- `RoundThemeHint`
- `RoundThemePrompt`
- `MechanicalThemeId`
- `MechanicalThemeLabel`
- `AestheticThemeId`
- `OwnerUserId`
- `ItemId`
- `ItemName`
- `Claimed`
- `PlacedBy`
- `InCart`
- `IsBuildMode`
- `KnockProtected`

## What To Preserve
- `RoundManager` stays the phase authority
- `CartService` stays the pickup/cart authority and enforces the 15-item cap server-side
- `RoomService` stays the room and placement authority
- `JudgeService` stays the judging authority
- `ItemDatabase` and `ThemeDatabase` stay shared content metadata sources
- `PlacementBridge` stays the local bridge between style UI and placement ghost logic

## Legacy / Watch-Outs
- `CartController_Legacy` exists in `StarterPlayerScripts` — **Disabled = true**, do not re-enable
- `CartService_Legacy` exists in `ServerScriptService` — **Disabled = true**, do not re-enable
- `TestShopPhaseLock` exists in `ServerScriptService` — **Disabled = true**, dev tool only
- `DummyCartDriver` exists in `ServerScriptService` — **Disabled = true**, dev tool only
- `RoundThemeReplicator` is a support sync layer, not the main theme chooser
- Older handoff notes are legacy and should not be used as current systems documentation

## Cart Capacity — Three-Way Sync Rule
Cart capacity is defined in **three places** and all three must always match:

| Location | Constant | Current Value |
|---|---|---|
| `ServerScriptService.CartService` | `CART_CAPACITY` | **15** |
| `StarterPlayer.StarterPlayerScripts.CartController` | `CART_CAPACITY` | **15** |
| `StarterPlayer.StarterPlayerScripts.PickupEffect` | `MAX_ITEMS` | **15** |

The server value is authoritative — it enforces the hard cap. The client values drive display only. If you change capacity, update all three.

## Recommended Read Order For Non-UI Work

If touching gameplay systems, read in this order:

1. [AGENTS.md](/C:/Users/jaked/Documents/New%20project/AGENTS.md)
2. [docs/game_systems.md](/C:/Users/jaked/Documents/New%20project/docs/game_systems.md)
3. [docs/ui_system.md](/C:/Users/jaked/Documents/New%20project/docs/ui_system.md) if the work touches player-facing interaction
4. `ReplicatedStorage.ItemDatabase`
5. `ReplicatedStorage.ThemeDatabase`
6. `ServerScriptService.RoundManager`
7. the phase-specific authority script you plan to change

Suggested by phase:
- shop: `StoreSetup`, `CartService`, `CartCollision`, `ShopTargeting`
- style: `RoomService`, `PlacementBridge`, `PlacementController`
- judge: `JudgeService`

## Short Summary
The current project is organized around one authority per major gameplay area:

- `RoundManager` controls the round
- `StoreSetup` populates the shop
- `CartService` controls carts, item pickup, and enforces the 15-item cap
- `CartCollision` controls shop impacts and knockdowns
- `RoomService` controls rooms and style-authoritative placement
- `JudgeService` controls touring, voting, and scoring
- `ItemDatabase` and `ThemeDatabase` provide the shared content rules

That separation should stay intact so both Claude and Codex can work quickly without stepping on the wrong system.
