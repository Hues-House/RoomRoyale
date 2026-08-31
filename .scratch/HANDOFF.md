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

There is one blocking bug: players cannot move in the multiplayer lobby or during Style,
but can during Shop, and solo is entirely fine. Start there. The handoff has the evidence
gathered so far and the leading hypothesis. Do not trust the hypothesis, it is explicitly
unconfirmed.

Verify every fix against a running game rather than by reading the diff. Do not publish to
the live place.
<!-- END PROMPT -->

---

## Read this first: the code is not backed up

Every code change from session 2 exists **only in the local Studio datamodel**. It is not in
git, and this repo has no source in it (`src/` is empty by design). The git history contains
documentation only.

Changed in Studio and uncommitted anywhere: `RoundManager`, `ProgressionService`, `UITheme`,
`PickupEffect`, `CartController`, `CartService`, `RoomService`, `JudgeClient`, and a new
`ZZ_FreezeDiagnostic`.

Saving the place file is the only thing that makes this durable. Publishing is out of bounds.

---

## The blocking bug

**Symptom, reported by the user from a live server-plus-clients test.** Cannot move in the
multiplayer lobby. Cannot move during Style. CAN move during Shop. Solo is entirely fine.

**Ruled out.** `VERIFIED` from the user's server log: the freeze happens on a clean boot with
**no round running**, so no cart and no Style room exist. CartService and RoomService cannot
explain the lobby case. None of the new fault-isolation warnings fired.

**Leading hypothesis, `UNVERIFIED`.** The character rig is wrong. Diagnostic output from a
solo run:

```
ws=16 plat=false sit=false anchored=false state=Running owner=<self> weld=false
motor6d on=0 off=0
constraints=[14 x BallSocketConstraint: NeckBallSocket, WaistBallSocket,
             LeftElbowBallSocket, RightKneeBallSocket, ...]
```

The rig has **zero Motor6Ds** and 14 joint-named BallSocketConstraints. Those names do not
come from this codebase. `CartCollision` names its ragdoll parts `RagdollBSC` with
attachments `RagdollAtt0` and `RagdollAtt1`, none of which are present. This points at a
Studio avatar-joint or physics-character beta feature. It could not be confirmed in script
because `StarterPlayer.AvatarJointUpgrade` is not a property in this Studio build.

**Certain regardless of whether that is the freeze cause.** Every ragdoll recovery path in
the place is dead code against this rig:

- `ServerScriptService.RoomService`, `wakeCharacterForTeleport`: re-enables Motor6Ds that do
  not exist and destroys `RagdollBSC` which does not exist.
- `ServerScriptService.JudgeService`: same pattern, same no-op.
- `ServerScriptService.CartCollision`, `ragdollPlayer`: ragdolls by disabling limb Motor6Ds.
  With none present, both the ragdoll and its recovery are silently broken.

**First two actions next session.** Check Studio Beta Features for an avatar joint or physics
character upgrade, disable it, retest multiplayer. Then read the `[FREEZE]` lines from a real
multiplayer run. The `owner=` field is the single highest-value datum: a root owned by
`SERVER` rather than by the player means that client physically cannot move their character,
and that failure mode exists only in a real server/client split, which matches the symptom
shape exactly.

The diagnostic is `ServerScriptService.ZZ_FreezeDiagnostic`, logging each player at spawn+2s
and spawn+8s. It is **temporary, delete it once diagnosed**.

---

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

## Ranked plan to an actual good place

1. **Make the code durable.** Save the place. Everything above lives only in a local Studio
   datamodel.
2. **The multiplayer movement freeze.** Nothing else matters until players can move. Start
   with the rig, see the blocking bug section.
3. **MCP reachability for multiplayer testing.** A server-plus-clients session registers extra
   studio instances, but every call to them returns "Client proxy is out of date, restart to
   update", and they later vanish from the listing. While this holds, no multiplayer behaviour
   can be observed directly and the loop degrades to edit, ask the user, guess. Fixing this is
   worth more than any single bug fix.
4. **Zero-data FTUE.** `StarterPlayer.StarterPlayerScripts.FtueController` gates purely on
   `snapshot.roundsFinished == 0` with no persisted flag. The test account reads
   `roundsFinished=3`, so the FTUE has **never once been displayed in any session**. Every
   beta player will be zero-data. Testing needs a fresh account or a profile reset, and Studio
   is writing to **live** DataStores, so a reset is destructive and is the user's call.
5. **Verify the results panel in a real round**, not by driving attributes.
6. **Phone verification on a real device.** The tray solver is only probe-verified.
7. **Shared theme attributes.** `chooseThemes` in `RoundManager` writes the theme onto `game`
   attributes, which two concurrent lobbies would clobber. Note `game:SetAttribute` does not
   replicate to clients at all, which is why `RoundThemeReplicator` exists. Untouched.
8. **Deferred polish**, all open, all deprioritised: Xbox focus and input mode (nothing in the
   place ever assigns `SelectedObject` or connects `LastInputTypeChanged`); the ScreenGui inset
   consolidation (13 runtime ScreenGuis across three conventions); cart capacity 15 duplicated
   at five sites; grabbed store items leaked to `ServerStorage`; `processedRoundRewards`
   growing unbounded; and `JoinRoundClient`, which is fully dead UI behind a permanently
   invisible button.

---

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
- **Multi-client sessions are unreachable.** See ranked item 3.
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

- Do not publish or overwrite the cloud place.
- `src/` in the repo is empty except for `.gitkeep`. It is not source.
- Local `.rbxl` and `.rbxlx` files on the Desktop are stale. Do not audit against them.
- Keep server validation authoritative. `PlaceItem` in RoomService is already
  server-authoritative over a per-round inventory built from cart contents, and it gates on
  `RoundPhase == "Style"`. Do not regress that.

## Cleanup owed

- Delete `ServerScriptService.ZZ_FreezeDiagnostic` once the freeze is diagnosed.
- Keep the CartService and RoomService `pcall` isolation and warnings.
