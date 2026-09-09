# Gameplay systems workstream

Prepared on 2026-09-09. Status: planning and source review only. No gameplay code, Studio scene, saved profile, or publication was changed.

## Use the actual project

The current project is `D:\code\RoomRoyale`. The C: bootstrap documents are stale and must not define implementation. Source paths below are relative to the D: project unless an absolute path is given.

Read the current [agent guide](../../AGENTS.md), [documentation entry point](../README.md), [accepted refinement plan](../refinement-plan-2026-09-08.md), and [vocabulary](../../CONTEXT.md). The [milestone 2 integration brief](../round-integration-implementation-brief-2026-09-08.md) is a planning draft. Its open judging decisions are not already approved.

The main Test has a neighborhood and cohort-based decorating rounds. Hillside is the separate market, cart, and pump-park prototype. Its final Style state demonstrates a collection; it is not the main Style and Judge flow. Main Test is PlaceId `86511797738570`, GameId `10764620924`. The complete scenes are `places/RoomRoyale-Test.rbxlx` and `places/RoomRoyale-Hillside.rbxlx`. A script-only Rojo build cannot replace either scene.

The September 9 README identifies a milestone-1 cart candidate with remaining acceptance and milestones 2–5 still unimplemented. This workstream connects the whole round before expanding purchases and earned designs. The September 9 physics briefs have their own proposal status and belong to movement planning.

## Accepted direction and current gaps

The following decisions come from the accepted refinement plan, not this workstream's recommendations:

- Rounds remain enjoyable independently of progression. Houses and rides provide additional goals between rounds.
- New players start with a small empty house and no owned ride.
- Round collection contains that round's collected pieces and shared basic decorating tools. Permanent physical furniture belongs in houses.
- Earned artwork and rug designs can customize compatible pieces collected in a round. They grant no extra physical copies.
- Players judge theme interpretation and the finished room. Automatic rarity contributes no winning points.
- Players can buy furniture quantities, including two matching chairs. Existing ownership and house placements must survive migration.
- A participating newcomer who has not won can afford meaningful furniture after two completed rounds and the basic ride after four to six total rounds, after that furniture purchase. Winning accelerates progress.
- Results shows the outcome, reward, purchase progress, Play again, and Back to neighborhood. One skateboard is the first owned ride.

The current [game systems map](../game_systems.md) and [UI map](../ui_system.md) identify the owning source. Current source inspection and the M2 source review establish these remaining gaps:

| Evidence | Consequence |
| --- | --- |
| `RoundManager.server.lua` maintains `RoundId` and `RoundPhase`, but theme publication still has global consumers | Never use global `GamePhase` as a participant's phase. It stays `Hub`. A second cohort must not change another round's theme. |
| M2 source review identifies one startup session in the prototype and mutable shared template names | Extract one round-owned shopping runtime. Multiple copies of the startup script do not provide isolation. |
| `RoomService` currently reduces pieces to item counts and grants owned furniture | Carry exact piece identity and variants into Style, and remove the permanent furniture grant from the competition path only. |
| `ProgressionConfig.lua` starts with 400 Style Bucks, gives 35 base Bucks and 30 base XP, then adds score, theme, rarity, rank, and win terms | Prices, awards, and new-profile defaults need reconciliation with accepted pacing. Current numbers are not the approved target. |
| `JudgeService.server.lua` sums appreciation, mechanical, and participation scores, then assigns sequential ranks after alphabetical tiebreaking | Ranking must become player-judged. Equal totals must not acquire a hidden alphabetical winner. |
| `ProgressionService.AwardRoundResults` uses an in-memory processed-round table and infers wins from `rank == 1` | Explicit outcome eligibility and persistent per-player reward identity are required before reliable achievements and replay recovery. |
| `ProgressionService` catches load exceptions, retries four times, and releases a late-acquired profile when its player has left | The historical missing-error-handler finding is superseded. Forced-failure acceptance still remains. |
| The service creates temporary in-session data when ProfileService is unavailable | The player must not mistake temporary progress for saved progress. That fallback cannot become an ordinary saved default profile. |
| `FtueController` shows contextual phase hints until `roundsFinished > 0` | Guidance exists, but checkout, new Results actions, first purchases, and an actual zero-data flow need acceptance. |

Current [verification requirements](../verification.md) supersede historical bug descriptions. For example, `PickupEffect` now has responsive reflow. Re-test narrow-screen behavior instead of assuming the old fixed-width bug remains.

## Ownership and coordination

| Responsibility | Owner and source |
| --- | --- |
| Cohorts, queue, phase deadlines, replay and return membership | Gameplay integration owner, `src/ServerScriptService/RoundManager.server.lua` |
| Round shopping runtime and final checkout handoff | Gameplay integration owner with movement review, extracted from `prototype/cart-lab/Server.server.lua` and `ShoppingSession.lua` |
| Cart forces, controls, and cart presentation | Movement owner, canonical `packages/RideRuntime/` and `prototype/cart-lab/` modules |
| Market allocation, section labels, route and checkout geometry | Environment owner, `prototype/superstore/` geometry modules, through the agreed round-runtime interface |
| Exact delivered pieces and competition placement | Gameplay, `RoomService.server.lua`, `StyleController.client.lua`, `PlacementController.client.lua` |
| Judge rules and result payload | Gameplay, `JudgeService.server.lua`, `JudgeClient.client.lua` |
| Style Bucks, XP, quantities, receipt serialization, designs and achievement records | Gameplay, `ProgressionService.lua`, `ProgressionConfig.lua`, `PersistentStoreCatalog.lua` |
| House quantities and placement migration | Gameplay with house source review, `HousingService.lua` and progression serialization |
| Arrival, onboarding, purchases and Results interaction | Gameplay, `LobbyClient`, `JoinRoundClient`, `FtueController`, `ProgressionClient`, `LobbyBoutiqueClient`, and `JudgeClient` |
| Shared HUD and input conventions | Root assigns one writer for `UITheme`, `UIStateManager`, and shared input contracts |

Every edited file has one writer. Gameplay specifies the collection and phase contract before movement or environment adopts it. Root integrates shared modules and owns the Studio session. Store geometry must not own phase changes, and cart animation must not decide whether a deposit counts.

## Dependency-ordered tickets

All tickets are proposed work packages. None is complete because this document exists. Each completed ticket needs a source revision, the actual scene, reproducible steps, device and player count, observed result, and remaining limits.

### GS-01: Lock the M2 contracts and remove hidden shared round state

Depends on root identifying the current Test scene and assigning shared files. Use the M2 draft as the starting design.

Define a round context with membership, theme, server deadlines, stock ownership, market allocation, and completed collections. Keep one network boundary that resolves the authenticated player to their current round. Scope pickup IDs, template references, timers, votes, and result messages to that context. Migrate global theme readers as well as the writers.

Acceptance: run two independent shopping sessions with overlapping item names. One session cannot reset the other's stock or player state. A neighborhood player receives neither round's controls or timer. Late messages from an old RoundId cannot change a player's new activity. Source inspection identifies every remaining global theme consumer before integration closes.

### GS-02: Connect checkout to actual Style inventory

Depends on GS-01 and movement's usable cart candidate. Environment supplies a playable market with reachable checkout.

Give `RoundManager` the deadlines and one finalization call. Pickup closes, the visible checkout grace closes, and server settlement finishes before the market is released. Repeat finalization returns the same completed snapshot. Accepted deposits count even if their suction animation finishes late. Preserve the existing visible rule for unchecked cargo.

Carry `RoundId`, `ownerUserId`, `pieceId`, `itemId`, `templateKey`, `variantId`, appearance, and placement state through the handoff. Two matching chairs are two owned records. Moving or storing a piece changes that record, never its physical count. Preserve templates until every Style and Judge consumer has finished. Full-size placed furniture must not inherit the cart's 86-percent presentation scale.

Remove permanent physical furniture from competition inventory in both `RoomService` and `ProgressionClient`. House decoration continues to use permanent ownership. Empty checkout provides an empty physical collection plus shared basics, with clear feedback.

Acceptance: two real clients check out distinct variants and duplicate pieces, then place, rotate, move, and store them in separate rooms. Destroy their market before placing the last piece. Start a new market with the same catalog names and prove the first room's appearance survives. Test deposits on either side of the deadline, delayed suction, disconnect during closing, stale placement, another player's piece, and repeated finalization. Each accepted physical piece exists once.

### GS-03: Settle outcome rules and complete Judge and Results

Depends on GS-02. The tied-win policy must be recorded before implementing competitive awards. Other integration work can continue while that narrow decision is pending.

Preserve the existing 0–3 appreciation presentation for the first integration. The server validates cohort membership, current room, deadline, finite integer token range, and one submission per room. No self-vote or cross-cohort vote counts. Winning score uses player votes only. Theme and participation feedback remain explanatory.

Create one finalized result per player and round, with explicit participation and competitive-win eligibility. Rewards consume that result rather than inferring a win from rank. Present outcome, actual awarded or pending reward, Play again, and Back to neighborhood. The panel remains readable independently of the existing eight-second teleport timer.

Acceptance: three or more clients submit known votes for known rooms. Independently calculate the expected outcome. Test invalid numeric values, duplicate votes, expired votes, self-votes, wrong-cohort votes, no votes, solo, ties, and departure during tour. Play again queues exactly once after releasing old membership. Back to neighborhood releases membership without queuing. Repeated clicks and late old Results messages cannot move a player out of their newer activity.

### GS-04: Verify first arrival and normal input across the full session

Depends on GS-02 for Shop and Style, and GS-03 for the complete loop. UI fixes can begin earlier in separately assigned files.

Use the existing onboarding controller and queue UI. Introduce the empty house, next round, shops, and park with one clear next action. Add contextual checkout guidance and brief placement, rotation, voting, and purchase explanations. Guidance stays skippable and never requires owned furniture or a ride. Do not claim a reward was earned just because the phase changed.

Acceptance: a fresh isolated profile starts in its empty house neighborhood and completes a round with no console-triggered pickup or placement. It can replay or go home. Repeat the action chain on desktop, a narrow landscape phone, tablet with keyboard capability present, and controller. Verify queue entry and exit, visible controller focus, confirm and back, safe area, input hint switching, full inventory access, touch checkout controls, placement, votes, and both Results actions. Use 874 by 402 and 1376 by 1032 as reference viewports, followed by physical input acceptance. Complete a second round to expose stale UI and cleanup bugs.

### GS-05: Prove failure handling and durable, nonduplicating rewards

Depends on GS-01 for identity and GS-03 for finalized results. Failure injection can begin before the whole integration finishes.

Retain the current profile namespace unless a tested migration requires otherwise. Test the existing bounded load recovery, late disconnect release, temporary fallback, and session-loss behavior. Expose whether progress is persistent, loading, or temporary. Never save fallback defaults over existing data.

Add a reward receipt scoped by durable round identity, player identity, and reward kind. Apply the receipt and balance change through the same owned profile mutation. Preserve receipt fields through `sanitizeProfile`. Do not mark the whole round processed before individually unavailable players have a defined outcome. Use explicit competitive-win eligibility for wins and future achievements.

Acceptance: repeated result delivery changes each balance once. Delayed delivery to a loading profile has a documented, tested outcome. Rejoin restores the same receipt, balance, XP, and earned win. A profile-load exception, four failed attempts, missing ProfileService, delayed load followed by departure, and session release leave no partial lot or owner state. Inject save failure and shutdown between result finalization and persistence. Record the actual persistence guarantee and leave any lost acknowledged reward as a release blocker. An in-memory processed-round table does not prove crash recovery.

Use `ServerStorage.NeighborhoodPreviewProfiles = true` before Play for fixture mutations and confirm that the mock path is active. Restore ordinary configuration and remove temporary drivers afterward. Mock checks do not alone establish real DataStore durability; use the supported isolated persistence acceptance path before claiming it.

### GS-06: Deliver furniture quantities and accepted purchase pacing

Depends on GS-03 and GS-05. This is refinement milestone 3.

Update ownership, purchase validation, snapshots, UI, house placement, and serialization together. Migrate existing item-type ownership to quantities without losing already-owned pieces or saved placements. Preserve `house-local-v2` records and retained legacy placements. Storing a house piece frees that owned copy; it does not sell or duplicate it.

Tune new-profile currency, Style Bucks awards, XP, and catalog prices against the accepted two-round furniture and four-to-six-round ride targets. Show the first award and progress toward a selected purchase. A win advances the goal sooner. Existing saved balances must not be reset to the new starting amount.

Acceptance: a participating, nonwinning fresh profile buys meaningful furniture after round two and the basic skateboard by round four to six after that purchase. Buy and place two matching chairs. Reject a third without sufficient ownership. Move and store a chair without changing total ownership. Rejoin and restore balance, quantity, finishes, and placements. Duplicate purchase requests charge and grant once. Check XP thresholds and first-purchase level requirements so an invisible level gate cannot break the currency pacing.

### GS-07: Add a small earned-design system

Depends on GS-03, GS-05, and GS-06. This is refinement milestone 4.

Ship a small set of artwork and rug designs with explicit compatibility and earning conditions. Use verified results for win-based progress and verified checkout events for route achievements. Store the actual theme history needed for multi-theme achievements. Aggregate wins cannot establish wins across several themes.

Acceptance: a locked design explains its condition. A qualifying accomplishment grants it once and it survives rejoin. Apply it to a compatible collected round piece and a compatible owned house piece. It creates no extra physical copy and no automatic rarity score. Other players see the correct design and inspect its name and earning condition. Solo and tie behavior follows the settled competitive-win policy.

### GS-08: Evaluate theme voting after the complete cycle works

Depends on GS-04 and environment's supported-theme coverage. Theme voting is a recommendation, not an accepted requirement in the refinement plan.

Recommend a short pre-round choice among three supported themes only if it improves replay interest without lengthening the queue. Call it Choose a theme and keep its ballots separate from Judge appreciation votes. One queued participant gets one replaceable ballot. Close through a server deadline. Choose tied or unvoted options through a recorded server seed. Automatic theme selection remains the first-slice behavior.

Acceptance if selected: normal desktop, touch, and controller ballots work. Replacement, departure, no ballot, ties, and late requests select one valid theme for that cohort only. Every offered theme has viable pieces on the accessible floor route. Voting never changes appreciation tokens, progression, another cohort's theme, or neighborhood activity.

## Recommendations for unresolved details

These proposals preserve the approved direction. Root should record the chosen values and outcome policy before the dependent implementation ticket.

### Economy starting point

Use existing Style Bucks and XP, physical house furniture quantities, reusable earned designs, and one purchasable skateboard. Do not replace that direction with a cosmetic-only shop or remove winner acceleration.

A simple tuning fixture starts a new profile at zero Bucks, awards 50 Bucks for verified participation, and adds 25 for an eligible competitive win. A useful pair of chairs costs 100 Bucks and the basic skateboard costs 150. A nonwinner buys the pair after two rounds, then the board after five total rounds. This demonstrates the accepted pacing algebra; it does not set final catalog prices. Existing balance and ownership remain intact.

Keep XP as visible progress, with a modest win bonus and no early level requirement that delays those purchases. Evaluate the existing XP curve before replacing it. Avoid coupling baseline earnings to rarity, lobby pickup farming, vote quantity, or repeated client actions. Review every current currency source when checking the pacing. Awards, prices, starting money, and level restrictions must be tested as one economy.

### Solo, ties, and missing votes

The M2 draft proposes participation rewards without competitive wins for solo rounds, shared places for equal totals, and no competitive win when no votes are submitted. Recommend adopting those defaults.

For the remaining tied-win decision, recommend shared displayed rank with no competitive-win achievement unless a unique top room emerges from a valid player-vote result. Both tied players still receive their participation reward. This is a recommendation, not an accepted rule. If shared winners are preferred, represent that explicitly in the finalized result and test both currency and design grants accordingly.

For a two-player round, test mutual voting and the cost of strategic withholding before treating the result as sufficient evidence for rare achievements. Basic progression must remain achievable without a win. A room's mechanical theme match must never become the fallback winning score when appreciation data is missing.

### Departures during Judge

Keep equal scheduled viewing time and shuffle the room order within each cohort. Freeze room snapshots independently of owner characters. Define a comparable vote sample before implementing churn scoring. A reasonable beta proposal removes a departed voter's partial tour votes from the ranked comparison, then uses a sample with equal eligible voting opportunities for every room. If no comparable sample remains, show an unranked reveal and participation rewards. Test the denominator after self-vote exclusion; removing partial votes alone does not guarantee equal opportunities.

Do not introduce normalization silently into the player-vote rule. Record the chosen procedure, its two-player behavior, and expected examples in GS-03. Validation prevents forged votes; it does not prove resistance to collusion.

## Edge-case acceptance matrix

| Case | Required outcome |
| --- | --- |
| No queued players | No round, empty market, or reward is created. Neighborhood remains available. |
| One queued player | Provide a clear bounded start or waiting state. A solo round follows the settled participation-only rule and cannot grant competitive wins. |
| Queue departure at countdown end | Remove the player once. Start or cancel according to one queue rule without an abandoned timer. |
| Late join during another round | Remain in neighborhood or queue for a new cohort. Never inherit the active cohort's stock, timer, or voting rights. |
| Neighborhood player during two active cohorts | House controls and purchases remain usable. Round controls do not appear and rewards do not cross cohorts. |
| Disconnect before checkout closes | Settle already-accepted deposits through the same server deadline. Clean up rider callbacks without losing another player's stock. |
| Empty checkout | Show honestly empty round furniture and shared basics. No permanent house furniture is granted. |
| Disconnect before a qualifying completion | Use the recorded completion eligibility rule. Do not fabricate a win or claim an unearned reward was lost. |
| Owner leaves during Judge | Keep a valid frozen room available. The tour cannot wait forever for a missing avatar. |
| Voter leaves mid-tour | Apply the settled comparable-sample rule and recalculate explicit competitive eligibility. |
| Everyone leaves | Release that cohort's world, templates, callbacks, and memberships without touching another cohort. Settle any already-earned receipts through the supported profile lifetime. |
| Equal totals or no submitted votes | Show the settled shared-rank or unranked outcome. Do not use alphabetical order or mechanical points to invent a winner. |
| Rejoin | Restore permanent data. Rejoin the neighborhood or next-round queue unless explicit same-server round restoration is implemented. Do not promise cross-server room recovery. |
| Repeated Results or purchase actions | One receipt, one balance change, one purchase quantity grant, and one chosen activity. |
| Profile unavailable | Explain loading, failure, or temporary status. Preserve saved ownership and house placements. Never overwrite existing records with defaults. |
| Old result after a newer round begins | Reject the stale activity transition. A legitimate pending receipt remains bound to its original round. |

## First playable slice and release gates

The first end-to-end slice is refinement milestone 2: two real players enter from the neighborhood, collect and check out Hillside pieces, style those exact variants in real rooms, appreciate each other's rooms, view player-judged Results, then choose replay or home. A third player stays in the neighborhood. A second active cohort proves stock, theme, collection, and reward isolation. Automatic theme choice is sufficient for this slice.

Follow with milestone 3's empty-profile purchase payoff, then milestone 4's small earned-design collection. The owned skateboard's runtime belongs to the movement workstream, while gameplay owns its purchase, ownership, equip persistence, and goal feedback. Its park geometry belongs to environment.

Run the relevant pure tests and build checks, preserve the complete Test scene, and run `tools/Verify-PlaceSnapshots.py`. These establish source and scene consistency. Actual Studio and physical-device checks establish the player experience. The historical audit, script packaging, solo prototype, and a saved Roblox Test version each leave the current cross-device, persistence-failure, multiplayer, and first-player acceptance gates open until tested.

Root reports that this planning session's repository validation passes and all 54 managed main scripts and 30 managed Hillside scripts match their saved scenes, with zero mismatches. The main scene preserves 106 additional scene scripts. This establishes a current source baseline, not acceptance of the proposed integration. Prior physics and device measurements remain historical evidence for their named builds.

Root should close beta readiness only after the full round, concurrent cohorts, failed-profile recovery, nonduplicating rewards, migrated quantities, zero-data purchase pacing, and normal-device interaction pass with recorded evidence. Theme voting remains optional unless selected as beta scope. Publication is a separate action from implementing and verifying this workstream.
