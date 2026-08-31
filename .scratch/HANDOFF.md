# Room Royale handoff

Written 2026-08-30 at the close of session 2. Supersedes
`HANDOFF-archive-2026-08-30.md`, which holds the raw session-1 and session-2 notes and is
worth opening only for detail this document compresses.

**Read the Evidence ledger before trusting any claim here.** Every statement is tagged.
`VERIFIED` means observed against a running game. `HARNESS` means observed against real
shipped source driven by stubs. `PROBE` means it came from a model of the code, not the
code. `UNVERIFIED` means nobody has ever executed it. The distinction is load-bearing: the
original audit document was wrong about seven of twelve claims precisely because it blurred
this line.

---

## Fresh-session prompt

<!-- BEGIN PROMPT -->
I'm picking up work on Room Royale, my Roblox decorating game. The goal is a playable
multiplayer beta. Read `.scratch/HANDOFF.md` first, then `AGENTS.md` and `CONTEXT.md`.

The repo at D:\code\RoomRoyale is documentation-only. All game source lives in the live
Roblox place and Studio is the source of truth. Connect over the Roblox Studio MCP before
anything else and read the "Studio MCP gotchas" section first, it will save several wasted
round trips.

Do not test multiplayer in Studio's server-and-clients mode. It does not bind a movement
controller, so clients cannot walk, and it cost two sessions before anyone noticed the game
was fine. Publish to the test place in the same universe and join it with real clients. See
ADR 0002.

Verify every fix against a running game rather than by reading the diff. Never publish to the
live place.
<!-- END PROMPT -->

---

## Read this first: the code is safer than session 2 believed

Team Create is enabled on this place, so the datamodel persists in the cloud rather than only
on one disk. Session 2's claim that the code existed only locally was wrong. It is still not
in git, and this repo has no source in it (`src/` is empty by design).

Studio Script Sync is the fix and it is agreed: two-way sync between Studio and `src/`, no Rojo
migration. It syncs scripts only, so the 108 ItemAssets, every ScreenGui and all world geometry
stay inside the place file regardless.

Changed in Studio and uncommitted anywhere: `RoundManager`, `ProgressionService`, `UITheme`,
`PickupEffect`, `CartController`, `CartService`, `RoomService`, `JudgeClient`, and a new
`ZZ_FreezeDiagnostic`.

Publishing to the **test place** is now the verification method, not a hazard. See ADR 0002.
The live place stays off limits.

---

## The blocking bug that wasn't

**Closed 2026-08-31.** `VERIFIED` against a real server.

The symptom was real: in Studio's server-and-clients mode, a client cannot move. The cause
is Studio, not the game. The same build published to a test place and joined from a real
client moves normally.

The evidence that settled it, from a client-side diagnostic:

```
move=0,0,0  ctrl=0,0,0  ws=16  state=Running
activeController=NO ACTIVE CONTROLLER
KeyboardEnabled=true GamepadEnabled=false MouseEnabled=true TouchEnabled=false
boundActions=[EmotesMenuToggleAction, ..., RbxCameraKeypress, ...]   <- no movement actions
```

Roblox's own ControlModule selected no movement controller, so nothing translated W into
motion. Camera modules bound normally, which is why the camera worked and the character did
not. The humanoid was healthy throughout: WalkSpeed 16, not platform-standing, not anchored,
network ownership held by the client.

**Falsified along the way, each with evidence, so nobody re-opens them:**

- `StreamingEnabled`. Set to false, freeze persisted.
- Network ownership. `owner=Player1`, not SERVER. This was the handoff's leading hypothesis.
- `DevComputerMovementMode`. `UserChoice` on every mode, not `Scriptable`.
- Input capability. `KeyboardEnabled=true`, so the harness was not claiming a missing keyboard.
- Today's edits. The months-old published build, untouched, also runs fine on the current
  platform, and the current build runs fine when published.

**The rig question is still open and now cheap.** Studio reported a character with 20 parts,
14 BallSocketConstraints and zero Motor6Ds, and reported it differently between solo and
multiplayer runs. That observation drove the conclusion that every ragdoll recovery path is
dead code. Since Studio's rig reporting is now known to be unreliable, that conclusion is
`UNVERIFIED` again. Read `[CFREEZE] ... motor6d=` from a real server before acting on it. If
the rig is a normal R15, ramming already works and the ragdoll work disappears.

## Evidence ledger

### VERIFIED against a running game

- Clean boot, zero errors, across several Play sessions after all edits.
- Solo queue through the real client path (`Events.RequestJoinQueue:FireServer()`) starts a
  round: `Round <id> -> Shop`, `[StoreSetup] Populated TheShowroom with 77 items`.
- Profile load happy path (`[HousingService] House built for <name>`).
- Desktop inventory tray: `1156x88`, `UIGridLayout` `CellSize 68`, 15 slots present,
  `Slot_1 AbsoluteSize 68,68`, `trayScale=1.000`.
- 11/11 live UI assertions on desktop covering the action band, GRAB and BOOST positions,
  grid layout, slot touch target, and tray width against budget.
- UITheme touch branch live, by forcing `IsTouch` and swapping `CurrentCamera`:
  `scale=1.409 corner=150 ActionBand bottom=185.4 top=337.6 left=1477.8`.
- Results reveal panel survives the Judge to Results transition and clears on lobby return,
  driven by setting the `RoundPhase` attribute directly.

### HARNESS, real shipped source with stubbed Players

- 11/11 queue state-machine scenarios, including the original deadlock, a player joining
  mid-countdown, requeue after cancel, and a full six-player lobby starting immediately.
- Recipe is in the archive under "Queue harness". `loadstring` IS available inside
  `execute_luau`. Two traps that produced false results first time: model `PlayerRemoving` as
  LeaveQueue-then-roster-removal, because Roblox fires it while the player is still in
  `Players`; and drain `playerQueue` between scenarios, not just the roster.

### PROBE, a model of the code rather than the code

- Inventory tray geometry across 8 device presets, 7 clean. iPhone SE landscape (667x375)
  degrades to a 39px slot, 5px under the 44px touch target, with no collision and no
  clipping. That is the intended graceful fallback.

### UNVERIFIED, nobody has executed these

- The two-row phone tray on a real phone viewport. MCP cannot resize the Studio viewport, so
  the phone path has never been rendered.
- The profile-load outage path. The retry and kick were never triggered.
- `JudgeClient` hiding judge panels on Shop. A test caught a real leak here, the fix was
  applied, and it was **not re-run**. Re-verify this first, it is cheap.
- The CartService and RoomService fault isolation actually firing.
- Anything requiring concurrent players: cart-to-Style transfer, placement isolation, voting.
- Zero-data FTUE. See ranked item 4.

---

## What was fixed in session 2

**Queue deadlock, root-caused and fixed.** `effectiveMin()` in `RoundManager` reads the live
player count, so server population is one side of the arm comparison, but only queue joins
and leaves re-evaluated it. Four scattered re-arm branches were collapsed into one
`reevaluateQueue()`, called from queue changes plus new `PlayerAdded` and `PlayerRemoving`
hooks. Separately, `cancelQueue()` cancelled the thread it was running on, which on an
already-yielded thread kills it mid-statement before clearing `queueActive`, latching it true
and blocking every later countdown for the life of the server.

A subtlety worth preserving: the player minimum gates **arming** the countdown, not firing
it. `reevaluateQueue` only ever arms. Cancelling belongs to `LeaveQueue`, where the queue
itself shrank. Collapsing those two intents into one function was a real defect caught by the
harness, not by review.

**Results panel, root-caused and fixed.** `JudgeClient` read
`if phase ~= "Judge" then hideJudgePanels() end`. `VoteReveal` populates the panel while the
phase is still Judge, then the move to Results wiped it instantly. Nobody had ever seen the
final scores. Phase-driven, not player-count driven, so it reproduced solo.

**Profile-load recovery.** `LoadProfileAsync` handled a nil return but not a throw, so a
DataStore outage killed the `PlayerAdded` thread and left the player in-server with no
profile at all: no leaderstats, no currency, every purchase refused, round rewards dropped.
Now four attempts with linear backoff, a warn per failure, an early bail if the player leaves
mid-retry, and a kick.

**Phone playability.** `UITheme.IsTouch()` now keys off the absence of a mouse rather than the
absence of a keyboard, so tablets with paired keyboards stop taking the desktop branch.
`ControlCornerInset()` is proportional rather than a flat 150, which was 40% of the height on
a small landscape phone. New `ActionBandBottom`, `ActionBandTop` and `ActionBandLeft` make
UITheme the single authority on where GRAB and BOOST sit, so CartController and PickupEffect
stop disagreeing about the same screen region. The fixed 1160px tray and its inverted bespoke
scaler are gone, replaced by a solver that wraps to up to three rows and avoids the action
band.

Worth knowing: `ControlCornerInset()` already existed with **zero call sites** before this
work. The correct abstraction had been written and never wired up, which was the root cause
behind three separately-reported symptoms.

**Fault isolation.** CartService and RoomService walked the cohort in bare synchronous loops,
so one player throwing stranded everyone after them, invisible in solo by construction. Both
are now per-player `pcall` with named warnings, and CartService has a force-unfreeze fallback.
This fixes a real class. It is not the lobby freeze.

---

## Ranked plan to a beta

Beta means: a public place where players earn Style Bucks in rounds, buy Owned items, and
decorate a persistent House in the Neighborhood. Housing, currency and the shop already exist
and work. See `CONTEXT.md`.

1. **Read the rig from a real server.** One F9 log line. Decides whether ramming and every
   ragdoll recovery path already work, or whether that is a real workstream. Nothing else
   should be planned until this is known.
2. **Set up Studio Script Sync into `src/`.** Gets 55 scripts into git. Non-script instances
   stay in the place file, so this is a partial answer, but it is the whole code half.
3. **Prove one real multiplayer round end to end on the test place.** Cart-to-Style transfer,
   placement isolation, voting, room reveals, scores. Every one of these is `UNVERIFIED` and
   all of them are now testable for the first time.
4. **Zero-data FTUE.** `FtueController` gates on `roundsFinished == 0` and has never displayed
   in any session. 100% of beta players are zero-data. Needs a fresh account, because Studio
   writes to live DataStores and a profile reset is destructive.
5. **Xbox focus and input.** Nothing in the place assigns `GuiService.SelectedObject` or
   connects `LastInputTypeChanged`. The lobby Play button cannot be reached with a controller.
6. **Aesthetic themes.** `ThemeDatabase.AestheticThemes` has exactly one entry,
   `overall_style`. Half of every theme pair has been a constant in every round ever played.
7. **Item overhaul.** 108 catalog entries across 8 mechanical themes, 9 missing PrimaryPart.
   Needs consistent size, placement metadata and enough variety that two players build
   visibly different rooms from the same theme. This is content work with a schedule.
8. **Griefing containment.** Ramming is in, recorded in ADR 0001. Shield exists after a
   knockout. Checkout zones and a shorter Shop phase are the plan and are not built.
9. **Phone verification on a real device.** The tray solver is only probe-verified.
10. **Deferred polish.** Shared theme attributes clobbering across concurrent lobbies; the
    ScreenGui inset consolidation across 13 runtime ScreenGuis; cart capacity 15 duplicated at
    five sites; grabbed store items leaked to `ServerStorage`; `processedRoundRewards` growing
    unbounded; `JoinRoundClient` is fully dead UI behind a permanently invisible button.

## Studio MCP gotchas

These cost real time. Read before the first tool call.

- **`script_read` ignores its line-range arguments** and always returns the whole file,
  blowing the token cap on large scripts. Slice `Instance.Source` inside `execute_luau`
  instead. This is the single biggest context saver.
- **`script_grep` line numbers do not match `script_read` line numbers**, and the offset is
  not constant per file. Never cite a grep line number.
- `script_read`, `script_grep` and `inspect_instance` only work in **Edit mode**. Starting
  Play removes the Edit datamodel. Stop Play before reading source.
- **`_G` set by a game script is not visible to `execute_luau`.** Drive gameplay through the
  real RemoteEvents from the Client datamodel instead.
- **`game:SetAttribute` does not replicate to clients.** Client-side reads of `QueueCount`,
  `RoundThemeLabel` and similar are always nil.
- **`loadstring` IS available** inside `execute_luau`, which is what makes the queue harness
  possible.
- **`task.cancel` on the currently running thread behaves differently** depending on whether
  it has yielded. A `task.spawn` closure on its first synchronous resumption survives. A
  thread that has yielded dies mid-statement. This masked the queue bug on the first probe and
  nearly produced a confident wrong diagnosis.
- **Studio server-and-clients mode does not bind a movement controller.** Clients cannot walk.
  This is not a game bug. Use the test place instead. This single line would have saved two
  sessions.
- **Multi-client sessions are unreachable over MCP.** Extra studio instances register, then
  every call returns "Client proxy is out of date" and they vanish.
- **The viewport cannot be resized via MCP**, so phone layout cannot be rendered.
- `screen_capture` is scaled relative to the real viewport, so clicking coordinates read off a
  screenshot silently misses. Pass `instance_path` to `user_mouse_input` instead.
- `wait_time_ms` is capped at 10000. Chain waits, but keep chains to about four or the request
  times out.
- A solo player can start a round, so solo testing needs no bypass. A round is roughly 10s
  queue, 90s Shop, 120s Style, then Judge and 8s Results.
- Studio instance is `Room Royale (placeId: 82272152451005)`, matching the live place in
  CONTEXT.md, so every edit is to the real game. Leave Studio in Edit mode when finishing.

---

## Ground rules

- Never publish or overwrite the **live** place. The test place in the same universe is the
  verification target and publishing to it is expected.
- `src/` in the repo is empty except for `.gitkeep`. It is not source.
- Local `.rbxl` and `.rbxlx` files on the Desktop are stale. Do not audit against them.
- Keep server validation authoritative. `PlaceItem` in RoomService is already
  server-authoritative over a per-round inventory built from cart contents, and it gates on
  `RoundPhase == "Style"`. Do not regress that.

## Cleanup owed

- Delete `ServerScriptService.ZZ_FreezeDiagnostic` and
  `StarterPlayer.StarterPlayerScripts.ZZ_ClientFreezeDiagnostic`. Both are published to the
  test place. Keep them only until the rig is read from a real server, then remove both.
- Keep the CartService and RoomService `pcall` isolation and warnings.
