# Complete-round integration brief

Status: planning draft for milestone 2. Milestone 1 has a local candidate with remaining acceptance recorded in its [report](cart-refinement-m1-2026-09-08.md). Round integration has not started.

## Player outcome

Join a round from the neighborhood, interpret a theme, collect and check out furniture in Hillside, arrange those same pieces in a room, tour and vote on other rooms, then receive results with Play again and Back to neighborhood. A player who stays home remains free to decorate or explore while other groups compete.

Use the accepted rules and pacing direction in the [refinement plan](refinement-plan-2026-09-08.md). This milestone establishes the complete competition. Furniture quantities, economy tuning, earned designs, and owned rides follow in their existing sequence.

## Source facts that determine the design

- `RoundManager.server.lua` owns cohorts and player `RoundId`/`RoundPhase`, but still publishes global theme attributes and releases a showroom before announcing Style.
- `prototype/cart-lab/Server.server.lua` creates one course, one current round, and a player-state map at startup. Beginning shopping resets the stock and every player's session. Installing several copies does not establish independent rounds.
- `ShoppingSession.lua` already separates carried and checked-out pieces, has ordered shopping/checkout/style deadlines, and exports piece identity and variant metadata. Reuse these rules.
- `ItemPresentation.capture` stores templates by name in one `CartItemTemplates` folder and destroys an existing template with the same name. Templates therefore need a round namespace or immutable catalog identity before markets can overlap.
- Milestone 1's shopping HUD targets `CartLabPickup` tags and sends the displayed pickup ID. During integration, scope both that candidate list and its phase/deadline source to the player's market. A pickup index is local to a market; resolve it using the server's player-to-round membership.
- `RoomService.server.lua` reduces cart contents to item-ID counts, adds permanent furniture, and places generic catalog models. Both inventory authority and model creation must consume the completed piece records instead.
- `JudgeService.server.lua` adds automatic theme and rarity-derived values to player votes and breaks ties into sequential ranks. `ProgressionService.AwardRoundResults` treats every first rank as a win. Outcome eligibility must be explicit when those rules change.

## Ownership and handoff

Extract a per-round shopping runtime from the prototype startup script. A round owns its market instance, finite stock, rider sessions, deadlines, theme, and completed collections. Keep one network boundary that resolves the authenticated player to their active round, rather than starting a remote handler and all-player listener for every market. Standalone prototypes become small callers of the same runtime once the main integration works.

`RoundManager` remains the phase owner. It chooses the theme and absolute deadlines once. The shopping runtime applies those deadlines to pickup, checkout, and settlement. Client timers display server deadlines; animation completion never decides whether a piece was delivered.

Illustrative caller sequence, with final names to follow the source:

```lua
local shopping = ShoppingRound.start(roundContext, marketAllocation)
local collection = shopping:finishCheckout()
RoundCollections.install(roundContext.id, collection)
shopping:releaseMarket()
setPhase(roundContext, "Style")
-- RoomService consumes RoundCollections for this RoundId.
-- Collections and their templates survive through Judge and Results.
```

`finishCheckout` is the single finalization boundary. It returns the same completed snapshot when called again. Pickup closes first, the visible checkout grace closes next, and final settlement precedes Style. A server-accepted deposit remains checked out even if its client animation is delayed. Unchecked cargo follows the existing closing rule. Cleanup cancels callbacks that belong to that round and can run more than once.

The collection and template lifetime must outlast the market. Use round-scoped templates or stable immutable templates with explicit ownership. Release them only when the round no longer has styling rooms, pending reveals, or collection consumers. A second round must neither replace nor delete them.

## Per-piece competition inventory

Carry these fields across checkout, inventory presentation, placement, moving, and inspection:

| Field | Meaning |
| --- | --- |
| RoundId and ownerUserId | Which collection may use the piece |
| pieceId | Unique identity of one collected physical copy |
| itemId | Catalog metadata and valid placement behavior |
| templateKey and variantId | Exact captured appearance with a stable template reference |
| appearance | Supported color and customization state |
| placement state | Available or placed, with the room-owned placement identity |

Preserve the existing exported entry ID as the piece ID if its uniqueness is established. Two matching chairs are two records. Moving a chair changes the same record; storing it makes that record available again. A stale or repeated placement request cannot create an extra piece. Grouping identical entries in the UI is allowed, but the server still resolves a specific owned record.

Place the full-size furniture represented by its template. The cart's visual carrying scale is not the styling scale. Validate compatibility with the catalog's floor, wall, tabletop, or other supported placement surface. Preserve the source variant through placement ghosts and inventory previews as well as the final model.

Remove permanent physical furniture from competition inventory on both server and client. House decoration keeps its existing ownership path. Empty checkout produces an honestly empty furniture inventory plus the agreed shared basic decorating tools; it must not silently grant a house collection or fabricate purchases.

## Theme, judging, and results

Send theme, phase, timer, and result payloads for a specific round. Migrate main UI consumers away from global theme attributes, including fallback readers and the theme replicator. A neighborhood player must not inherit another group's timer or shopping controls.

Keep the existing room tour and 0-3 appreciation vote presentation for the first integration unless the user changes that decision. Validate the voter, active round, current room, vote window, and one submission per room on the server. Reject self-votes and votes for another cohort. Ranking uses player votes only. Theme guidance and participation feedback remain separate from winning points; item rarity contributes no ranking bonus.

Working proposal awaiting session feedback: solo rounds receive participation rewards but no competitive win. Equal vote totals share a place. Zero-vote results do not grant competitive wins. Decide tied-win eligibility explicitly before dispatching the results portion; do not inherit alphabetical tie-breaking or infer a win from `rank == 1`. Two-player mutual voting and disconnected voters belong in that review.

Create one finalized result per round and player. Reward delivery uses that result's identity and explicit competitive-win eligibility, so replayed callbacks do not grant again. Reconcile the existing reward calculation with the finalized player-vote outcome and eligibility. Currency and XP tuning, target prices, the first-purchase curve, and broader profile migration stay in milestone 3. Do not claim cross-server reward retry guarantees from an in-memory processed-round table.

Results shows the outcome, earned reward, Play again, and Back to neighborhood. Play again releases the finished membership and queues the player exactly once. Back to neighborhood releases membership without queuing. Duplicate clicks and an old results screen cannot affect a newer round. Keep a results panel available long enough to read; its lifetime should not depend on the current eight-second teleport timer. Purchase-goal progress joins this panel with milestone 3.

## Implementation order

1. Define the per-round shopping and collection contracts. Prove two independent stock/session sets and template lifetimes before wiring the main round.
2. Connect the refined market/cart to `RoundManager`, centralize closing and settlement, and move the completed records into real Style inventory and placement. End this unit with Shop-to-Style playable in the complete Test scene.
3. Migrate theme and phase UI consumers, remove old cart/showroom runtime ownership for the main round, and verify the neighborhood remains independent.
4. Apply the settled judging rule, reward handoff, and both results actions. End this unit with the complete two-player cycle.

Main source must consume the canonical refined ride/cart code. Remove replaced callers and startup scripts in the same integration; avoid leaving old cart input or pickup handlers active beside the new runtime. Preserve Studio-owned neighborhood assets when assembling the candidate scene. A script-only Rojo build is not the complete scene.

Assign each edited file to one writer. The integration owner makes changes to shared lifecycle and input contracts; parallel workers return proposed changes for those files rather than overwriting each other's work. Verify every consumer when a contract changes, including engine acceptance drivers.

## Playable acceptance

- Two actual clients complete Shop, Style, Judge, and Results with their own checked-out furniture. Include identical copies, distinct variants, placement, movement, and return-to-inventory.
- Complete placement after the corresponding market has actually been destroyed. Start another market with overlapping item names and prove the first room's appearance is unchanged.
- Exercise pickup and checkout on either side of their deadlines, delayed suction, repeated finalization, and disconnect during closing. Each accepted piece appears once; unchecked pieces follow the visible rule.
- Run a second cohort concurrently while another player stays in the neighborhood. Themes, stock, timers, controls, inventory, votes, and rewards stay independent.
- Attempt an unavailable piece, another player's piece, a stale placement, a self-vote, an out-of-round vote, and a repeated reward delivery. Reject them without corrupting valid play.
- Verify solo, ties, no submitted votes, and a player leaving during a tour under the settled outcome rules.
- Exercise replay, return home, repeated button clicks, and a previous result arriving late. The player ends in exactly one intended activity.
- Use isolated preview profiles for reward fixtures. Verify the actual reward and resulting saved state through the project's supported profile path, recording remaining persistence limits.
- Complete desktop flow and responsive HUD acceptance, then record physical touch/controller and multiplayer evidence precisely. Camera feel and phone performance require their own live checks.

Deliver a complete local Test candidate, source/saved-place comparison, focused automated and Studio evidence, and a concise whole-round playtest checklist. Roblox publication is a distinct later action.
