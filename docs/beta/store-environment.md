# Store environment build package

Prepared 2026-09-09. Status: planning complete for this assignment; no new geometry built, installed, saved or played.

The current source repository is `D:\code\RoomRoyale`. The C: bootstrap is stale. Source links below deliberately point to the current D: project.

## Baseline and approved direction

Build on the existing Hillside market and pump park. Turn its open prototype displays into a cohesive furniture store while preserving its flat shopping routes, visible tube checkout, jumps, dive, recognizable stacked cargo, limited special finds and quick recovery. The requested environment ultimately needs built Roblox geometry and a verified round integration. This document alone does not deliver either.

The current [documentation index](../README.md), [agent guide](../../AGENTS.md) and [refinement plan](../refinement-plan-2026-09-08.md) supersede the old C: system map for current-state claims. The approved plan connects the new market to the main game's cohorts, real Style inventory, Judge and Results. Checkout must settle each piece and variant before unloading a market. Permanent physical furniture belongs in houses. Special-route accomplishments can later unlock earned artwork or rug designs; rarity supplies no automatic winning points.

The [main Test snapshot](../../places/RoomRoyale-Test.rbxlx) has the complete neighborhood and older round cart. The [Hillside snapshot](../../places/RoomRoyale-Hillside.rbxlx) contains the separate market and milestone-1 cart candidate. Its current session ends in a demonstration collection. Main uses a 15-item cart; Hillside uses a 100-space cart. These are separate implementations, not interchangeable constraints. See [game systems](../game_systems.md), [UI systems](../ui_system.md) and [vocabulary](../../CONTEXT.md).

The orchestrator must resolve which existing Studio scene is the approved editing baseline before installing geometry. The observed Warehouse-Repair and Warehouse-Slice sessions with PlaceId 0 have not been reconciled with the saved Hillside scene by this assignment. Do not overwrite one based on its window title.

## What the current source actually builds

These dimensions are read from [Store.lua](../../prototype/superstore/Store.lua), [Props.lua](../../prototype/superstore/Props.lua) and [PracticePark.lua](../../prototype/superstore/PracticePark.lua), not newly proposed dimensions.

| Element | Current source |
| --- | --- |
| Market floor | 320 by 320, top at Y=0, centered at X=0, Z=0 |
| Arrival | `MarketSpawn` at 0, 2.5, 112; entrance wordmark at Z=128 |
| Checkout | Center 0, 0, -96; zone 66 by 12 by 36; tube delivery target 0, 26, -96 |
| Clear routes | Center spine 34 wide; outer lanes 30 wide at X=-72 and 72; end links at Z=100 and -125 |
| Main departments | Living at -42, 50; Dining at 42, 50; Bedroom at -42, -5; Plants + lights at 42, -5 |
| Finishing touches | Rug and books around X=-43 and 43, Z=-62 |
| Shopping bays | 13 by 18, with distinct StockId and VariantId; 13 source definitions total |
| Jump trails | At X=-116 and 116; successive surface heights 2.8, 5.6 and 8.4; special chair and halo lamp on final decks |
| Limited stock | One of each special find; `requireLanding=true`; stock does not ordinarily restock until the next round |
| Garden detour | An 18-wide rolling outside route with botanical books, west of the market |
| Park | Default origin X=310; continuous 24-wide roller loop, banked turns, separate trick launch/landing and solid miss floor |

The [v4 report](../playtest-iteration-v4-2026-09-08.md) records 1,962 park support raycasts with no failures and a server-owned chassis loop run. It also links mounted keyboard footage. These results support preserving the geometry baseline; they do not prove a mounted phone rider, multiplayer congestion or the new proposed layout. The milestone-1 candidate still has input and cargo acceptance outstanding.

## Cohesive store concept

Keep the name Hillside Market during the first build pass unless the orchestrator resolves a product rename. Frame it as a garden showroom with pale timber portal frames, cream wall panels, broad skylight strips, low room displays and a mint checkout tube. The jump trails become raised display terraces around the store. The park reads as the same building's recreation court through the east opening.

Build architectural rhythm around the existing usable routes. Do not start by shrinking the 320-stud floor or surrounding the checkout spine with shelving. First turn each existing department into a recognizable room vignette with visible stock beside it. The requested integration of shopping and obstacle play comes from terrace trails and an additional rolling route immediately beside departments, while the complete park remains available through the existing east connection.

Proposed art treatment, all untested in the final camera:

| Element | Build instruction |
| --- | --- |
| Palette | Reuse `Geometry.colors`: cream, wood and ink for architecture; lilac Living, peach Dining, blue Bedroom, yellow Lighting and mint Plants |
| Floor | Retain warm neutral base; mint marks checkout navigation, narrow department-color inlays mark stock boundaries |
| Walls | Broad cream panels on the outer boundary, interrupted by open garden bays; no opaque walls between center spine and departments |
| Structure | Repeated timber frames along outer edges; proposed 32-stud clear underside over regular driving areas, revised against full cargo and jump-camera envelope |
| Stock islands | Low plinths and mats, open on two sides; large pieces single-depth; small decor spaced for deliberate focus selection |
| Silhouettes | Rounded corners, thick planter edges, visibly supported shelving; furniture supplies detail while the shell stays simple |
| Signs | One department name plus silhouette icon at each entrance; checkout remains the highest and most visible navigation marker |
| Light | Broad daylight and gentle warm pools over furniture; no flashing obstacles or dense neon strips |

Use the [physical scale standard](../../authoring/art-study/physical-scale-standard.md) and real furniture bounds. Do not enlarge every piece merely to fill the warehouse. Keep material texture scale consistent with the measured avatar and furniture studies. Check inherited texture permissions in the intended Test experience.

## Route graph and adjacency

Keep store-local coordinates below. Existing coordinates are source facts; proposed connections and clearances are layout hypotheses that need mounted play. Future placement into cohort instances must transform every route, stock anchor, checkout target and recovery position together.

| Node | X, Z | Role |
| --- | --- | --- |
| A | 0, 112 | Arrival and initial checkout view |
| F | 0, 100 | Front cross aisle |
| L1 / R1 | -72 / 72, 50 | Living / Dining stop |
| L2 / R2 | -72 / 72, -5 | Bedroom / Plants + lights stop |
| L3 / R3 | -72 / 72, -62 | Finishing touches stop |
| B | 0, -125 | Rear return link |
| C | 0, -96 | Checkout |
| P | 160, 90 | East opening toward existing park connector |

Flat shopping graph: `A <-> F`, `F <-> L1 <-> L2 <-> L3 <-> B`, `F <-> R1 <-> R2 <-> R3 <-> B`, with center-spine access from F to C and the rear link from B to C. Provide level crossovers between the two outer lanes through the center near Z=23 and Z=-37 only after checking stock bounds and cart turning. The existing floor supports these connections; the proposal is to keep them visibly clear as architecture is added.

Living sits beside Dining so a first trip can collect a sofa, table and chairs. Bedroom sits behind Living; Plants + lights sits behind Dining. Finishing touches catches the final choice near checkout. Split the Plants + lights stock into clearly signed sub-bays without moving the whole department or inventing new catalogue categories. Add a dedicated artwork sub-bay only once compatible actual stock exists. Color is never the sole identifier.

Optional skill graph retains each existing trail: front outside entry -> first launch -> first landing -> special-find deck -> rear descent -> B -> C. The garden path remains a gentler west-side option. Flat shoppers can reach every core furnishing category. The special limited variant can remain route-gated as already approved; do not make a basic theme impossible because the only ordinary chair is on a jump deck.

Proposed integrated pump branch: run an 18-to-24-stud-wide rolling ribbon inside the east terrace corridor, roughly X=98, from Z=78 to -82. It links front Dining to rear finishing touches and checkout, visibly alongside departments. Keep the X=72 flat lane intact. Start with low rollers below Y=2.5 and a filled tabletop below Y=3.5. Those are untested starting dimensions, not tuning commitments. The existing right jump trail occupies the same general corridor, so first block out the branch and trail together, then move the trail outward only if both retain clear separate riding and landing envelopes. Do not stack crossing airborne routes. If the corridor cannot fit both, replace the right trail's approach with the rolling branch while preserving its special-find landing deck and test the changed challenge.

The full park stays east via `F -> P -> park apron -> pump loop / trick branch`. A timed shopper should distinguish “Checkout” from “Practice park” at this junction. The neighborhood megaramp is the later approved milestone, with roll-in, gap, broad landing, quarter pipe and fast retry route. It must remain a separate deliverable from dressing the market.

## Item access, collision and recovery

Preserve current pickup IDs, variant IDs, space and weight metadata, finite stock, required landing height and checkout identity. Environment authoring must not silently convert a variant into a different item or add duplicate unlimited stock. The proposed store uses the prototype pickup authority and shared `PickupRules` after integration; the older main `ShopTargeting` and CartService path remains relevant until the orchestrator replaces that owner deliberately.

Keep current 13 by 18 bay footprints for the first pass, then resize only where actual normalized bounds demand it. A player should stop beside an item without occupying the primary through lane. Each small piece needs a clear approach and focus region. Test camera-relative steering, stacked cargo occlusion, touch fallback and controller target choice using the current input candidate. A prompt's 15-stud display distance is not proof the server will accept every approach.

Retain the 34-stud center and 30-stud outer clear lanes, including sign supports and planter collisions. Set nonfunctional trim to noncolliding and nonqueryable. Give ride surfaces continuous collision profiles and preserve the tested seam overlap in the park ribbon builder. Display stock and architectural support require separate collision decisions; never make an entire shelf queryable merely for its sign.

Missed jumps land on the existing solid floor. Keep space below and beside terraces open enough to drive out, with no stock inside cavities. Add proposed named level recovery pads near arrival, rear return and park apron after measuring full cart bounds. Runtime recovery must preserve valid cargo, respect the owning round and avoid another player's cart. Movement owns recovery logic; environment supplies clear landing space and pad transforms.

From arrival, checkout must remain visible above ordinary furniture and through the proposed architecture. From each department, the player must see a checkout arrow and at least one clear exit. Repeat that view with a tall full stack and the phone HUD active. Stock labels may appear close up; do not let every department sign and stock label compete at the same distance.

## Source ownership and integration risks

Environment owns `prototype/superstore/Store.lua`, `Geometry.lua`, geometry-related `Props.lua`, and `PracticePark.lua`, subject to orchestrator assignment. Movement owns `packages/RideRuntime/` and movement, cargo and crash runtime in `prototype/cart-lab/`. Gameplay owns cohort integration, final checkout deadline, Style consumption, judging, currency, XP and progression. Shared-file changes need an assigned writer.

`Store.build()` currently destroys a global `workspace.CartLab`, parents its own world to Workspace and changes global Lighting. This is a standalone builder, not yet a cohort-safe store factory. Integration must remove those assumptions before two concurrent stores can exist. Proposed contract: accept an owning parent, store-local transform and round-scoped stock configuration; return that store's world, spawn, stock, checkout zones and recovery points. Final API belongs to the round integration owner. Geometry must not independently choose phases or release itself while checkout still has items in flight.

`PracticePark.build(world, optionalOrigin)` already supports an origin, but it replaces a same-named child under that world. Keep that containment deliberate. The neighborhood park should have its own owner and lifecycle, independent of a timed market unload. Do not change neighborhood lighting by constructing a round store.

Before final collision authoring, movement supplies measured cart footprint, loaded stack/camera envelope, turn diameter, boosted braking distance, roller curvature tolerance, landing behavior and recovery. New quarter pipes depend on surface-aware support and wall classification. September 9 one-button/contact briefs remain proposals according to the current index; the environment must not assume a new input scheme or contact solver has shipped.

## First playable delivery

Deliver the arrival-to-Living-to-checkout route, the left special-find trail and the proposed east rolling approach as a reviewable section in the approved scene. Keep the other existing stock reachable. Complete one Living display with final materials and signage to establish the art reference. Build source and actual Roblox geometry together; use generated models or native parts that remain editable.

Acceptance for this section:

1. A new player identifies Living and checkout from the initial camera, collects a normal piece, and completes the tube delivery with normal controls.
2. An empty and a loaded cart drive the preserved flat shopping lap, stop at bays and reverse without snagging new architecture.
3. A mounted driver completes and misses the left jump trail; the special find still rejects grabs from below and retains the correct variant through checkout.
4. The new rolling approach is traversable slowly and with intentional speed; misses return to floor without trapping cargo or riders.
5. Two real clients contend for a limited find and pass a stopped shopper without geometry-created deadlock.
6. Capture ordinary driving-camera and overhead views, including phone HUD. Record build, input, client count, results and failures. Existing videos that omit ScreenGui do not establish new sign/HUD readability.

## Complete beta environment delivery

After that section passes, finish the remaining department architecture, signs, stocked displays, integrated rolling route, terrace edges, garden and park connection. Preserve the broad shopping lanes and checkout landmark throughout. Then integrate through the orchestrator's cohort store lifecycle and run real decorating rounds.

Required artifacts are the owning source changes, editable assets, complete saved approved scene, stock-and-variant manifest, layout coordinates, collision notes, before/after views and an acceptance report. Run relevant repository builds and `tools/Verify-PlaceSnapshots.py` after scene/source synchronization. A scripts-only Rojo build cannot replace the complete scene or prove its authored assets survive.

Environment release acceptance:

- Every active stock definition is reachable under its intended route rule, matches its visible variant, and transfers through checkout into actual Style inventory before store release.
- Every active theme has viable ordinary shopping choices. Special-route finds reward skill without automatic rarity winning points. Achievement hooks use verified route and checkout records only when that later system exists.
- At least two clients complete the real Shop -> Style -> Judge -> Results flow. Two active cohorts and a player in the neighborhood keep their store geometry, stock, checkout targets and collections isolated.
- Run at intended server capacity as a separate congestion check, including near-full cargo at checkout, missed jumps, disconnects and the Shop deadline during suction or flight.
- Desktop, narrow landscape phone, tablet and controller can navigate, focus stock and find checkout. Record physical input separately from Studio emulation.
- Measure phone frame time, physics and memory with mounted loaded carts, real stock and final architecture. Establish a device budget with the orchestrator before declaring performance accepted.
- Validate roots, bounds, scale, shelf/cargo/placed collisions, texture permissions and thumbnails against the current asset inventory. Do not repeat the old audit's missing-root count as a current fact.
- Verify scenery and the neighborhood park survive the correct lifecycles, while each finished cohort's temporary store cleans up without interrupting another.

The [current verification checklist](../verification.md) governs wider release gates. This work package does not claim that profile, new-player, progression, device or publication acceptance is complete. Saving, committing, saving to Roblox and opening public beta are separate outcomes.
