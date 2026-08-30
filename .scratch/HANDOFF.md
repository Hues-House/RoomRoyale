# Room Royale session handoff

Written 2026-08-30 at the end of a wayfinder session. Everything below labelled
**verified** was reproduced against the running place in this session. Everything
labelled **reported** came from a read-only audit agent and has not been executed.
Treat the distinction as load-bearing. The previous audit document
(`docs/public-beta-readiness-audit-2026-08-30.md`) contains at least two claims that
turned out to be wrong, listed under "Corrections" below.

---

## Fresh-session prompt

Paste everything between the markers as the opening message of a new session.

<!-- BEGIN PROMPT -->
I'm picking up work on Room Royale, my Roblox decorating game. Goal is to get it
playable and fully functional, with a full pass on phone UI. It's not public yet, so
I care about the core loop working and feeling good, not about polish debt.

Read `.scratch/HANDOFF.md` first, then `AGENTS.md` and `CONTEXT.md`. The repo at
D:\code\RoomRoyale is documentation-only. All game source lives in the live Roblox
place and Studio is the source of truth.

Connect to the live Studio session over the Roblox Studio MCP before doing anything
else, and read the "Studio MCP gotchas" section of the handoff before your first tool
call. It will save you several wasted round trips.

Work through the ranked plan in the handoff in order. Use subagents for read-heavy
audits, they paid off well last session. Verify every fix against the running game
rather than by reading the diff. Do not publish to the live place.
<!-- END PROMPT -->

---

## Where things stand

The game is in better shape than the old audit implies. It boots with zero errors and
a full solo round runs end to end: lobby, Play, queue, theme reveal, Shop with 77
items on a 90s timer, Style with a room shell, Judge, Results. **Verified** by driving
it twice this session.

The real gaps are server authority, multiplayer, device support, and phone UI.

### Done this session

**Server-authoritative round inventory.** `PlaceItem` in RoomService previously
accepted any of the ~100 `ItemAssets` names, unlimited copies, at any time, with no
reference to what the player had collected. Shop was cosmetic. Changes made:

- `CartService` gained a `GetCartContentsServer` BindableFunction, the server-side
  twin of the existing client-facing `GetCartContents`.
- `RoomService` gained `roundInventory[userId][itemId]`, a multiset built at Style
  start from cart contents plus persistent owned items at one placement each, matching
  the rule ProgressionService already uses for house placements.
- `PlaceItem` now requires `RoundPhase == "Style"`, type-checks the CFrame, and
  consumes from the inventory as its last gate before cloning.
- Picking a placed item back up returns it to the inventory.
- Inventory is cleared in `destroyRoomsForCohort` and on `PlayerRemoving`.

**Verified** by firing the remote directly from the client the way a cheat client
would. Four calls, two for an unowned `DiningTable` and two for a `LoftFloorLamp`
owned exactly once, produced exactly one placed item. Pickup then replace then
duplicate attempt produced 0, 1, 1. No console errors.

Regression checked. Hub house decorating routes through `HousePlaceSave`, not
`PlaceItem`, inside `ConfirmPlacement` in PlacementController, so the new phase gate
does not affect the hub loop.

### Corrections to the old audit

- The style room is **not** wall-less. It has a 30-part `VisualShell`. An earlier
  screenshot was taken from a camera angle facing out over the floor edge.
- `RequestStartRound` defaulting its cohort to every player in the server is real but
  reachable only through a BindableFunction. It is server-side only, not a client
  exploit, and was over-ranked.

---

## Ranked plan

1. **Queue deadlock.** **Verified.** `effectiveMin()` in RoundManager returns
   `min(MIN_PLAYERS, #Players:GetPlayers())`, counting the whole server rather than the
   queue. With two players online and one queued, nothing starts, which is correct. But
   when the other player leaves, `LeaveQueue` takes its else branch and only
   re-broadcasts. Nothing re-arms `startQueueCountdown`, so the queued player waits
   forever and has to manually requeue. The same stranding is **reported** via
   `fireQueueRound` when the queue drops below minimum mid-countdown. This bites
   exactly when the game gets traction, so it goes first.

2. **Phone UI full pass.** Requested directly by the user. Detail in its own section
   below.

3. **Shared theme attributes.** **Reported.** `chooseThemes` in RoundManager writes the
   round theme onto `game` attributes. Two concurrent lobbies clobber each other, so
   every client reads whichever round started last. JudgeService scoring is already
   safe because it takes theme ids per round. Move the theme onto the round state and
   replicate per cohort.

4. **Xbox focus and input mode.** **Verified** that `GuiService.SelectedObject` is nil
   while the lobby Play button has `Selectable = true`. **Reported** that this is not a
   broken focus rule but the total absence of one. Nothing in the entire place ever
   assigns `SelectedObject`, sets `Selectable`, `SelectionGroup`, or `NextSelection*`,
   and `LastInputTypeChanged` is never connected anywhere. Every input label is polled
   once at build time and then goes stale, which is why "Press Shift" persists after
   gamepad input. Suggested home is one module in `ReplicatedStorage` beside
   `UIStateManager`, subscribing to the phase state machine that already exists rather
   than adding a seventh phase listener. `JoinRoundClient` is dead code, its button is
   pinned `Visible = false`.

5. **Profile-load recovery.** **Reported.** `LoadProfileAsync` is not wrapped in a
   pcall. If it throws, the thread dies inside the `PlayerAdded` connection and the
   player stays in the server with no profile at all: no leaderstats, no currency
   attributes, every purchase refused, round rewards silently skipped. They can play a
   full round and receive nothing. There is no retry and no kick.

6. **Leaks and hygiene.** **Reported.** Grabbed store items are reparented to
   `ServerStorage` and never destroyed, keeping their `StoreItem` tag.
   `processedRoundRewards` grows unbounded for the server lifetime.
   `SetItemAppearance` and `SetRoomSurface` never type-check `color`, `material`, or
   `itemName`, unlike their neighbours, so a bad value errors mid-loop and leaves an
   item half-recoloured. `StoreSetup` has a slot-0 fallback that aliases a live store
   and whose release clears another lobby's items.

7. **Prove multiplayer.** Nothing about two-player Shop, cart-to-Style transfer,
   placement isolation, or voting has ever been executed. Per-player keying is
   **reported** clean, using `cartContents[userId]`, `StyleRoom_<userId>`, and
   per-round store slots, so this is about evidence rather than suspected bugs.

8. **Zero-data FTUE.** Untested. Every session so far has used an existing profile.

---

## Phone UI full pass

Two root causes produce most of the symptoms, so fix the causes rather than the
screens.

**Root cause one: three coexisting inset conventions.** Ten ScreenGuis are created at
runtime and no script in the place calls `GuiService:GetGuiInset()`. Three use
`UITheme.ApplySafeArea` (LobbyWelcomeGui, StyleGui, StylePopupGui). Five set
`IgnoreGuiInset = true` (PhaseBannerGui, JudgeGui, PromptGui, PlacementMobileGui, the
boutique toast). Two do nothing at all (CartHUD, InventoryGui). CartHUD dodges the
topbar with a magic `UDim2.new(0, 14, 0, 56)` offset. **Verified** on desktop that the
lobby Play button sits flush against the bottom viewport edge, so this is not
phone-only.

**Root cause two: `UITheme.IsTouch()` is wrong.** It is
`TouchEnabled and not KeyboardEnabled`. Any tablet or phone with a paired keyboard
falls through to the desktop branch, losing the 1.12x to 1.5x scale-up, taking the
0.72 to 1.0 shrink instead, getting `ControlCornerInset()` of 0 and narrower content
insets, all while Roblox still renders touch controls. This is why the iPad in the old
audit hid its custom cart controls. Every inset and scale decision in the codebase
keys off this one predicate.

**Inventory tray.** `PickupEffect` sets the tray to a hardcoded 1160 px wide. That
constant is hand-computed as 15 slots at 68 px, plus 14 gaps at 8 px, plus 24 px
padding, which is 1156. At an 874 px viewport with the tray scale clamped at 0.82 the
rendered width is still about 951 px, so it overflows. Derive slot size and tray width
from `ViewportSize.X` minus insets, clamped to `UITheme.TouchTarget` of 44, and
consider wrapping to two rows below a threshold.

**Cart capacity 15 is duplicated four times**, in `CartService` as `CART_CAPACITY`, in
`PickupEffect` as `MAX_ITEMS`, and as bare literals inside two UI strings, "15 slots
left" and "0/15". Export one constant and delete the copies.

**Suggested shape**, consolidating rather than adding a fourth convention. Give
`UITheme` a single `NewScreenGui(name, displayOrder)` that sets ResetOnSpawn,
ZIndexBehavior, DisplayOrder, safe area, and scale. Migrate all ten creation sites to
it, then delete the five `IgnoreGuiInset` lines and the three bespoke per-script scale
functions in RoundClient, PickupEffect, and JudgeClient. Add a `BottomSafeOffset()`
that folds `GetContentInsets().bottom` together with `ControlCornerInset()` and use it
everywhere a control is pinned to the bottom edge.

There are no width breakpoints anywhere, only a min-axis ratio, and no
`UIAspectRatioConstraint` in the place. Only one script derives any size from
`ViewportSize`.

Test presets: iPhone 17 Pro at 874x402, iPad Pro M5 at 1376x1032, desktop, and Xbox.
The game is configured `LandscapeSensor` and portrait has never been tested.

---

## Studio MCP gotchas

These cost real time this session. Read before the first tool call.

- **`script_read` only works in Edit mode.** Starting Play removes the Edit datamodel
  entirely, and `script_read`, `script_grep`, and `inspect_instance` take no
  `datamodel_type` argument, so they bind to Edit and return "Script not found" during
  Play. An audit agent was fully blocked by exactly this. Stop Play before any source
  reading.
- **`script_grep` line numbers do not match `script_read` line numbers.** They are
  offset. Confirm any grep hit with a read before citing or editing by line.
  `multi_edit` matches on strings, so prefer it and avoid line numbers entirely.
- **`screen_capture` is scaled relative to the real viewport.** The capture came back
  1919 px wide while `workspace.CurrentCamera.ViewportSize` was 2412x911. Clicking at
  coordinates read off a screenshot silently misses and produces no log at all. Pass
  `instance_path` to `user_mouse_input` instead, which is exact.
- **`wait_time_ms` is capped at 10000.** Chain several wait actions for longer waits.
  Long chains can still hit a request timeout, so keep them to about four.
- **A solo player can start a round.** `effectiveMin()` collapses the two-player
  minimum to one when only one player is online, so solo Studio testing works with no
  bypass needed. A round is roughly 10s queue, 90s Shop, 120s Style, then Judge.
- Studio instance is named `Room Royale (placeId: 82272152451005)`. The place id
  matches the live place recorded in CONTEXT.md, so every edit is to the real game.
  Leave Studio in Edit mode when finishing.

## Ground rules

- Do not publish or overwrite the cloud place. The device, multiplayer, and
  persistence gates have not passed.
- `src/` in the repo is empty except for `.gitkeep` files. Do not treat it as source.
- Local `.rbxl` and `.rbxlx` files on the Desktop are five months stale. Do not audit
  against them.
- Keep server validation authoritative. That is the theme of the highest-value fixes.
