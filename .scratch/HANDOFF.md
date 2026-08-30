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

---

# Session 2 (2026-08-30, later)

Same verified/reported discipline as above. Studio left in Edit mode.

## Shipped and verified

**Queue deadlock (was item 1).** One root cause, not the two separate strandings
recorded above. `effectiveMin()` reads `#Players:GetPlayers()`, so server population is
one side of the arm/disarm comparison, but only `JoinQueue` and `LeaveQueue` ever
re-evaluated it. Collapsed the four scattered re-arm branches into one idempotent
`reevaluateQueue()`, called from queue joins and leaves plus new `PlayerAdded` and
`PlayerRemoving` hooks.

Escalation found on top of the reported bug: `cancelQueue()` ran `task.cancel(queueThread)`
from *inside* `queueThread`. On a thread that has already yielded, that kills it
mid-statement before `queueActive = false`, latching `queueActive` true and blocking every
future countdown for the life of the server. `cancelQueue` now clears state first and never
cancels its own thread. Also changed `fireQueueRound` so the player minimum gates *arming*
the countdown, not firing it, so a player joining mid-countdown cannot strand the queue.

**Verified** two ways. An isolated harness reproduced the latch (`queueActive=true`,
execution dead inside `cancelQueue`) and passes after the fix. In Play, the real client
path `RequestJoinQueue:FireServer()` produced a full solo start through to
`[StoreSetup] Populated TheShowroom with 77 items`.

**Population-change path: now VERIFIED**, and it caught a defect in the first fix.

The multi-client windows could not be driven (their MCP proxy reports "out of date"), so the
queue block was instead extracted from `RoundManager.Source` at runtime, `loadstring`-ed with
a stubbed Players service, and driven through five scenarios. This runs the REAL shipped
lines, not a re-implementation, and it is cheap to re-run. See "Queue harness" below.

The first version of `reevaluateQueue` cancelled a countdown whenever `effectiveMin()` rose,
so a player joining the server mid-countdown killed the lobby before `fireQueueRound` could
apply its "committed lobby fires anyway" rule. Two different intents had been collapsed into
one function. `reevaluateQueue` is now arm-only, and cancelling belongs to `LeaveQueue`,
where the queue itself actually shrank. 11/11 scenarios pass, including the original
three-online-one-queued deadlock, full-lobby immediate start, and requeue after cancel.

**Profile-load recovery (was item 5).** CONFIRMED by source read, not inherited.
`Players.PlayerAdded:Connect(loadProfile)` and `loadProfile` handled a nil return but not a
throw. Now four attempts with linear backoff, a warn per failure, an early bail if the
player leaves mid-retry, and a kick instead of leaving them profile-less. **Verified** on
the happy path only; the outage path was not induced.

## Phone UI (was item 2), narrowed

Scoped to playability rather than the full inset consolidation, per the user's "core loop,
not polish debt". The consolidation is still open.

- `UITheme.IsTouch()` now keys off `not MouseEnabled` instead of `not KeyboardEnabled`, so a
  tablet with a paired keyboard stops falling through to the desktop branch.
- `UITheme.ControlCornerInset()` is now proportional, `clamp(minAxis * 0.32, 90, 150)`. The
  flat 150 was 40% of the height on a small landscape phone.
- New `UITheme.ActionBandBottom/Top/Left` and `ActionButtonSize` make UITheme the single
  authority on where the GRAB/BOOST buttons sit. CartController positions from it and
  PickupEffect avoids it. Previously both guessed independently and disagreed.
- CartController's `TOUCH_CORNER = 90` is gone. Its own comment admitted it did not clear
  the jump corner. On a phone it rendered at ~121px against a ~128px corner, putting GRAB
  under the jump button, the one control a player needs most during Shop.
- PickupEffect's fixed 1160px tray is gone, along with its inverted bespoke scaler. The tray
  is now solved against the viewport: a UIGridLayout wrapping to up to 3 rows, trying both a
  bottom placement between the control corners and a lifted placement above them, picking
  the largest slot among candidates that clear the action band.

**Verified.** A geometry probe (`execute_luau`, Edit mode) calling the real UITheme covers 8
device presets: 7/8 clean. iPhone SE landscape (667x375) degrades to a 39px slot, 5px under
the 44px target, with no collision and no clipping. In Play, 11/11 live assertions passed on
desktop and the touch branch was exercised by forcing `IsTouch` and swapping CurrentCamera.

**NOT verified.** The two-row phone layout on a real phone viewport. MCP cannot resize the
Studio viewport, so the phone path is proven by the mirror probe only.

## Corrections to the audit doc and to Session 1

The read-only UI audit overturned 7 of 12 inherited claims. Chiefly: there are **13**
runtime ScreenGuis, not 10. **Five** call `ApplySafeArea`, not three. Cart capacity 15 is
duplicated at **five** sites, not four (CartController has its own `CART_CAPACITY`
alongside CartService's). JudgeClient is *not* a bespoke scaler. And most usefully,
`UITheme.ControlCornerInset()` already existed, already returned 150 on touch, and had
**zero call sites** anywhere in the place. The correct abstraction was written and never
wired up, which is the root cause behind three of the reported symptoms.

## Studio MCP gotchas, additions

- `script_read` **ignores its line-range arguments** and always returns the whole file. For
  large scripts it blows the token cap. Use `execute_luau` in Edit mode to slice
  `Instance.Source` instead. This is the single biggest context saver.
- `script_grep` line offsets are **not a per-file constant** (-39 in UITheme, varying in
  CartController). They cannot be corrected for. Confirm every hit with a read.
- `_G` set by a game script is **not** visible to `execute_luau`. Drive gameplay through the
  real RemoteEvents from the Client datamodel instead.
- `game:SetAttribute` does **not** replicate to clients. Client-side reads of `QueueCount`,
  `RoundThemeLabel` etc. are always nil. `RoundThemeReplicator` exists for this reason.
- `task.cancel` on the currently-running thread behaves differently depending on whether it
  has yielded. A `task.spawn` closure on its first synchronous resumption survives; a thread
  that has yielded dies mid-statement. This masked the queue bug on first probe.

## Ranked plan, remaining

1. **Prove multiplayer.** Now blocks closing out the queue fix, not just the old item 7.
   Needs two clients.
2. **Zero-data FTUE.** Untested still. FTUE gates on `snapshot.roundsFinished == 0`; the test
   account reads `roundsFinished=3`, so the FTUE has never actually been displayed in any
   session. Testing it needs a fresh account or a deliberate profile reset. Studio is writing
   to **live** DataStores, so a reset is destructive and was not done.
3. **Shared theme attributes** (old item 3). Untouched.
4. Xbox focus, leaks and hygiene, and the ScreenGui inset consolidation. All still open,
   all deprioritized as polish.


## Queue harness (re-runnable)

`execute_luau` in Edit mode, no Play needed, ~8s. Slice `RoundManager.Source` from the line
containing `local function cancelQueue` (minus 4, to catch its comment) to the line before
`function RoundManager.IsInRound`. Prepend stubs for `Players` (a table with `GetPlayers`),
`CFG` (set `QUEUE_WAIT = 1` so scenarios run fast), `playerQueue`, `playerRoundMap`,
`queueThread`, `queueEndsAt`, `queueActive`, `reevaluateQueue`, `broadcastQueue` and
`startRoundForCohort`. Append a return exposing `RoundManager`, `reevaluateQueue` and the
state getters. `loadstring` IS available in this context.

Two things the harness must get right, both of which produced false results first time.
Model `leaveServer` as LeaveQueue FIRST and removal from the roster SECOND, because Roblox
fires `PlayerRemoving` while the player is still inside `Players`. And drain `playerQueue`
between scenarios, not just the roster, or leftover queued players inflate the next cohort.

## Session 2 status at close

Verified against the running game: queue arming and firing, solo round start through to
`[StoreSetup] Populated TheShowroom with 77 items`, clean boot with zero errors, the desktop
tray geometry, the action band, and 11/11 live UI assertions.

Verified against real shipped source via harness: all queue state-machine behaviour.

Still NOT verified: the two-row phone tray on a real phone viewport (MCP cannot resize the
Studio viewport, so it is proven by an 8-preset geometry probe only), the profile-load
outage path, and anything requiring genuinely concurrent players, chiefly cart-to-Style
transfer, placement isolation and voting.

Next session, highest value first: zero-data FTUE on a fresh account (it has never once been
displayed, the test profile reads `roundsFinished=3`), then real two-client cart and voting,
then the shared theme attributes on `game`.

---

# Session 2 addendum: multiplayer bugs reported from a live 3-client test

User report: cannot move in the multiplayer lobby or during Style, CAN move during Shop,
and solo is fine. Also, final results are not displayed on lobby return.

## Results not displayed: ROOT CAUSE FOUND AND FIXED

`JudgeClient` line ~684 read `if phase ~= "Judge" then hideJudgePanels() end`. `VoteReveal`
populates the reveal panel while the phase is still Judge. RoundManager then advances to
Results, the `RoundPhase` attribute change fires, and the panel is wiped at the exact moment
it becomes relevant. Nobody has ever seen the final scores.

Fixed by keeping the panel through Results and clearing it when `RoundPhase` goes nil on
lobby return. The same edit also removed an early `return` on Shop/Style that skipped the
hide entirely, which left a stale reveal panel up if Judge ran straight into the next Shop.

**This bug is phase-driven, not player-count driven. It reproduces solo.** Verified solo by
driving the `RoundPhase` attribute through Judge, Results and lobby return: the panel now
survives Judge to Results and clears on return. NOT verified in a real round.

## Movement freeze: hypothesis, NOT confirmed

`CartService` is the only thing that zeroes `WalkSpeed`/`JumpPower` and sets
`PlatformStand = true`, and it welds the character to the cart body (`attachPlayerToCart`,
~line 361-395). That explains the exact symptom shape: a player who is never detached can
still "move" during Shop because they are driving the cart, and is frozen everywhere else.

Both `CartService.onRoundPhaseChanged` and `RoomService.spawnStyleRooms` processed the
cohort in **bare synchronous loops**. One player throwing aborts the loop, so every player
after them is never detached (CartService) or never teleported and never woken by
`wakeCharacterForTeleport` (RoomService). Solo can never surface this because there is
nobody after you in the cohort.

Both loops are now per-player fault-isolated with `pcall` plus a named warn, and CartService
has a last-resort force-unfreeze that destroys the DriverWeld and restores humanoid
defaults even when the tidy path fails.

**This is a fix for the failure CLASS plus instrumentation. The underlying thrower has NOT
been identified.** Next multiplayer run, grep the SERVER console for:

    [CartService] despawn failed for <name> at <phase>: <err>
    [CartService] force-unfroze <name>
    [RoomService] style room failed for <name>: <err>
    [RoomService] teleportToRoom failed for <name>: <err>
    [RoomService] only N/M style rooms built

Any of those names the real root cause in one line. If NONE appear and players are still
frozen, the cause is not loop abortion and the next suspects are `setCharacterCartPhysics`
(RoomService `wakeCharacterForTeleport` destroys the player's cart at line 442-446, which
could race CartService's detach) and the client `ControlModule`.

## Blocker for this work

The MCP could not reach the user's server or client windows. They registered as three
unnamed studio instances, then every call returned "Client proxy is out of date, restart to
update", and they later vanished from `list_roblox_studios` entirely. **All multiplayer
verification is currently blocked on this.** Next session, resolve MCP reachability of the
multi-client session FIRST, before attempting any multiplayer fix, or the loop is
edit-blind-guess-repeat.

## Lobby freeze: hypothesis narrowed hard, cause NOT yet confirmed

User's server log from the failing multiplayer run was a **clean boot with no round running**
and none of the new CartService/RoomService warnings. That kills the loop-abortion
hypothesis for the LOBBY freeze outright. No cart exists in the lobby.

A temporary diagnostic (`ServerScriptService.ZZ_FreezeDiagnostic`, **DELETE WHEN DONE**)
logs each player's humanoid/physics state at spawn+2s and spawn+8s. Run solo it reported:

    ws=16 plat=false sit=false anchored=false state=Running owner=<self> weld=false
    motor6d on=0 off=0
    constraints=[14 x BallSocketConstraint: NeckBallSocket, WaistBallSocket,
                 LeftElbowBallSocket, RightKneeBallSocket, ...]

**The character rig has ZERO Motor6Ds and 14 joint-named BallSocketConstraints.** That is
not what CartCollision creates: its ragdoll constraints are named `RagdollBSC` with
attachments `RagdollAtt0`/`RagdollAtt1`. These `*BallSocket` names come from the avatar rig
itself, which strongly suggests a Studio avatar-joint/physics-character beta feature is
enabled. `StarterPlayer.AvatarJointUpgrade` does not exist as a property in this Studio
build, so it could not be confirmed in script.

Consequences that are certain regardless of the cause:

- `RoomService.wakeCharacterForTeleport` line ~452 re-enables `Motor6D`s. There are none.
- `JudgeService` line ~138 does the same. Also a no-op.
- Both also destroy only `RagdollBSC` / `RagdollAtt0` / `RagdollAtt1`, none of which exist.
- `CartCollision.ragdollPlayer` disables limb `Motor6D`s to ragdoll. With no Motor6Ds the
  ragdoll and its recovery are both silently broken.

So every ragdoll-recovery path in the place is dead code against the current rig. Solo still
walks because the HumanoidRootPart drives movement regardless, which is exactly why this
never showed up in solo testing.

**Next session, first two actions.** Check Studio Beta Features for an avatar joint or
physics-character upgrade and disable it, then retest multiplayer. And read the `[FREEZE]`
lines from a real multiplayer run: the `owner=` field is the highest-value single datum,
because a character whose root is owned by SERVER (not the player) cannot be moved by that
player's client, and that failure mode exists only in a real server/client split.

## Cleanup owed

- `ServerScriptService.ZZ_FreezeDiagnostic` is TEMPORARY. Delete it once diagnosed.
- The `[CartService]`/`[RoomService]` pcall isolation and warnings should stay; they are a
  real fix for a real class, independent of the lobby freeze.
