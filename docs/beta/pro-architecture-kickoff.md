# Start Room Royale beta architecture

You are the lead architect for Room Royale's open-beta effort. Produce the architecture and executable handoffs for movement/physics, store environment/3D construction, and gameplay/progression. The user wants this work kicked off. Finish with concrete first assignments that implementation orchestrators can execute.

This assignment replaces the earlier suggestion to use Pro only for an optional review. Pro now owns the shared architecture, the three workstream plans, and their reconciliation. Existing `docs/beta` work packages are evidence and starting proposals. Improve them against current source instead of treating them as approved architecture.

## Read the supplied project

For a GitHub-connected session, read this file and the referenced source directly from the current checkout of `Hues-House/RoomRoyale`. The committed source and complete saved scenes are available in this repository; the local ZIP is optional. Record the revision you read and do not assume access to the original Windows filesystem.

The original local working repository is `D:\code\RoomRoyale`. Use your current checkout of this GitHub repository when working elsewhere. `C:\Users\jaked\Documents\New project` is a stale bootstrap where the initial Codex task opened.

If supplied a ZIP, extract it and read `project/` as a source snapshot. `HANDOFF-MANIFEST.json` records its origin, revision, working changes, included files and hashes. The snapshot includes current uncommitted September 9 briefs. A remote session cannot access the user's D: filesystem by knowing its path. Use the attached source. If archive extraction is unavailable, state that limitation and identify the minimum missing files while completing work supported by this brief.

Read in this order:

1. `AGENTS.md`, `README.md`, `docs/README.md`, and `CONTEXT.md`.
2. `docs/refinement-plan-2026-09-08.md`, the accepted product decisions and milestone sequence.
3. `docs/game_systems.md`, `docs/ui_system.md`, and `docs/round-integration-implementation-brief-2026-09-08.md`.
4. `docs/verification.md`, `docs/cart-refinement-m1-2026-09-08.md`, and `docs/beta/baseline-snapshots-2026-09-09.json`.
5. The three `docs/beta` work packages. Trace their important claims to the owning source.
6. Relevant physics and asset documents below as you design each workstream.

At handoff creation, the repository's HEAD was `bb6d5d9`. The working tree then contained Claude's modified documentation index and five untracked September 9 cart briefs. Those files are included in this GitHub handoff. Preserve their content and proposal status. Recheck the revision and working tree on local implementation before applying this plan.

The latest local baseline check passed repository validation and the main Rojo source comparison. Saved-place comparison found 54 main managed scripts and 30 Hillside managed scripts with zero mismatches. The complete Test scene also contains 106 additional saved scripts. These checks were run during setup on September 9. They establish source/snapshot consistency, not beta readiness or new gameplay acceptance.

The source bundle is not a runnable replacement for the complete Roblox scenes. It omits large `.rbxlx`, `.blend`, mesh and texture binaries except selected reference images. Main Test is `places/RoomRoyale-Test.rbxlx`, Test PlaceId `86511797738570`, GameId `10764620924`. Hillside is `places/RoomRoyale-Hillside.rbxlx`. Local implementation must preserve those complete scenes. Previously observed Warehouse-Repair and Warehouse-Slice Studio windows are unverified local prototypes with PlaceId/GameId zero; their names alone do not select a baseline.

## Preserve the intended game

Room Royale is a stylish, playful Roblox decorating competition. Players rush through a store with shopping carts, collect furniture and decor for a theme, style their room, tour and judge rooms, see Results, and choose Play again or Back to neighborhood.

The user specifically wants a cohesive, usable furniture store that integrates obstacle-course, skatepark, pump-track and jump elements. Departments and pickup areas must remain obvious. Provide an ordinary shopping route and optional skill routes with forgiving recovery. The approved special finds can remain on difficult routes.

The accepted refinement plan also establishes:

- Independent round cohorts while other players remain in the neighborhood.
- A small empty newcomer house and no owned ride. Houses and rides add goals between enjoyable rounds.
- That round's collected physical pieces plus shared basic tools during Style. Permanent physical furniture belongs in houses.
- Physical furniture quantities, including matching duplicates. Earned artwork and rug designs are reusable unlocks for compatible pieces.
- Player judging determines the winning outcome. Rarity contributes no automatic winning points.
- A participating newcomer can buy meaningful furniture after two completed rounds and a basic ride after four to six total rounds, including the furniture spending. Winning accelerates progression.
- The first owned ride is a skateboard. Later rides are outside the first implementation.

Exact prices, XP curves, achievement thresholds and some voting rules remain design work. Existing defaults and the beta reports' arithmetic fixtures are not selected product values. Preserve accepted decisions and identify any proposed beta scope cuts explicitly.

## Route work by capability

Use a mixed team. The Astra specialists remain hands-on builders as well as workstream leads.

| Work | Starting assignment | Required result |
| --- | --- | --- |
| Shared and workstream architecture | GPT-6 Pro session | Source-grounded contracts, dependencies, decisions, first tickets and verification plan |
| Lead integration and workstream orchestration | GPT-6 Astra high | Review assignments, resolve interfaces, integrate, verify and escalate |
| Store composition, 3D modeling, art direction, lighting, visual iteration and difficult spatial work | GPT-6 Astra high; use xhigh for a named unresolved problem | Editable assets, built Roblox scene, visual and gameplay evidence |
| Novel physics solver work, hard debugging, cohort integration and persistence migration | Astra specialist where uncertainty remains | Reproduction/experiment, correct implementation and relevant runtime evidence |
| Bounded implementation with settled interfaces and observable acceptance | GPT-5.6 Luna max | Small reviewable change with exact checks and a truthful evidence report |

Luna max is the preferred implementation worker, not a mandatory destination for every task. Higher effort does not establish model equivalence. Do not demote 3D construction to Luna merely because Pro has written a plan. Astra owns the visual decisions and can implement them directly with Blender and Roblox tools. Luna can implement approved repeated modules, asset metadata and catalog wiring, mechanical migrations and tests. Assign technical art details such as collision and LOD to Astra when visual or physics judgment is still needed.

Evaluate the first Luna tickets using acceptance success, correction work and total time. If a worker exposes a contract gap, repeats the same unresolved failure, or needs aesthetic/physics judgment, the orchestrator takes over or escalates. It should not issue repeated longer prompts while avoiding the actual problem. Reserve Pro follow-ups for architecture changes and difficult decisions.

The original session exposes four concurrent slots total. For that limit, schedule one lead, one active workstream orchestrator, and two workers, or one lead with hands-on specialists when that produces more progress. Keep all three workstream queues durable and rotate them. Discover actual limits in the implementation environment; do not assume nested delegation creates more capacity. Avoid filling every slot with managers.

Custom agent configurations already exist under `.codex`. They currently use Astra high for the lead and specialist roles. Those configs do not activate Pro or background work. Include the exact Luna-max worker configuration and the orchestration updates needed to implement this routing. Preserve unrelated user settings and existing permissions.

## Design the shared architecture first

Trace the actual main and prototype execution paths before deciding module boundaries. Name the owning modules, important types and function signatures. Put illustrative skeletons in the architecture documents; avoid inserting nonfunctional stubs into shipping source.

Resolve these shared boundaries before separately expanding the workstreams:

- A round owns its cohort, theme, market allocation, stock, cart sessions, deadlines, completed collections and result identity.
- `RoundManager` remains phase owner. Main game participant state uses player `RoundId` and `RoundPhase`; global `GamePhase` remains `Hub`.
- Pickup closes, checkout settles once, exact piece/variant identity transfers, and only then is the market released. Completed collections and templates survive through Style and Judge.
- Shopping clients resolve targets and time from their own round. The server resolves authenticated player membership before changing stock, inventory, purchases, placement, votes or rewards.
- Movement publishes a measured loaded-cart turn/braking/jump envelope. Environment authors routes and stock pads against it. Untested dimensions remain hypotheses.
- One file has one writer. One lead controls Studio installations, Play state and scene saves. Separate Git checkouts do not isolate a shared Studio or Blender session.

The current prototype is not already safe to instantiate once per cohort. `Store.build()` replaces global `workspace.CartLab` and changes global lighting. The shopping startup and template storage also have global assumptions. Design one coherent extraction and migrate its callers; do not multiply global remote listeners and startup scripts.

## Movement and physics architecture

Read the five September 9 briefs in the current index's supersede order: handling/weight, air/tricks, control model, one-button input, then continuous contact. The index explicitly calls them unaccepted proposals. Later briefs supersede earlier proposals, while the accepted refinement plan still defines the baseline. Recommend candidate choices and experiments without claiming those choices have been user-approved or implemented.

Trace `packages/RideRuntime/`, `prototype/cart-lab/`, relevant acceptance drivers, and the main cart integration boundaries. Preserve the user's tested v4 jumps, dive and recognizable cargo. The M1 candidate has camera-relative driving, a separate Drift action, load effects and capacity feedback, with device and cargo acceptance still open.

Resolve or provide bounded experiments for:

- Raw movement intent versus camera-resolved steering. Camera motion alone must not cause deliberate drift.
- The proposed 0.10-second drift engagement versus the promise that every release before 0.12 seconds is a plain hop.
- Whether jump hold carries into airborne dive/trick and how both lateral and longitudinal trick input are represented.
- Terminal-speed convergence and lateral acceleration limits before changing the contact solver.
- Probe reach arithmetic: the proposed 4.25 length is shorter than 2.5 ride height + 0.35 margin + 1.5 falloff.
- Continuous support versus traction near vertical surfaces, alignment, compression/pumping and contact hysteresis.
- Quarter-pipe support versus current crash classification that can treat steep surfaces as ordinary walls.
- Charge, drift, loaded braking, jumps, recovery and action cancellation across real input devices.

Specify telemetry, measurable comparisons, regressions to preserve and the order of experiments. Do not choose final handling numbers from prose alone. Cart and skateboard tuning must remain independently adjustable.

## Environment and 3D construction architecture

Read `prototype/superstore/Store.lua`, `Props.lua`, `PracticePark.lua`, the Hillside evidence, `docs/beta/store-environment.md`, `authoring/art-study/README.md`, its `physical-scale-standard.md`, `authoring/cart-flatbed/README.md`, and `docs/procedural-furniture-catalog.md`.

The asset history matters. The first procedural catalog was rejected for repetitive silhouettes, small scale and block construction. The later three-piece mesh study prefers Blender for deliberate furniture shapes. Its sofa, chair and lamp are visual candidates with remaining production work. Existing images are historical reference, not proof of a finished store.

Specify the store's spatial arrangement, department adjacency, route graph, stock/checkout placement, architectural kit, materials, lighting and sightlines. Build on the actual Hillside floor, departments, jump trails, garden route and park. Develop optional riding routes alongside shopping decisions. Resolve the link between the market's park elements and the approved neighborhood skatepark.

Assign an Astra environment builder to carry this through blockout, a finished sample section, actual camera inspection, riding/pickup tests, and full-store expansion. Plan a small number of meaningful layout comparisons where the choice is unresolved. A successful delivery includes:

- Editable Blender or native Roblox authoring sources and a regeneration/export path.
- Models at the established avatar-relative scale with readable silhouettes, suitable pivots, support surfaces, collision and appearance channels.
- Roblox import and runtime persistence, material/texture permissions, catalog metadata, thumbnail and placement behavior where relevant.
- A complete preserved scene, not a script-only rebuild that drops Studio-owned assets.
- Gameplay-camera captures on the ordinary route, pickup pads, jump approach/landing and checkout. Include loaded carts and narrow-screen visibility.
- Measured device/scene performance under stated conditions. Determine suitable asset budgets from those measurements.

Blender and Roblox MCP tools were exposed in the preparation session. Verify actual connection and capabilities in the execution session. Source inspection and a rendered concept cannot prove an imported Roblox asset is playable. Keep upload permissions and Live publication separate from local authoring work.

## Gameplay and progression architecture

Trace the main `src/` phase, room, placement, judging, progression and UI consumers alongside prototype `ShoppingSession`, item presentation, checkout and cargo rules.

Cover first arrival and onboarding, queue/game start, themes, every phase transition, exact per-piece Style inventory, tours, votes, Results, replay/home, currency/XP, first purchases, quantity ownership, saved-data migration, earned designs and the first ride.

Distinguish theme selection from appreciation voting. The integration draft proposes retaining the existing 0-3 appreciation presentation initially. Decide the intended solo, tie and no-vote behavior explicitly before competitive-win rewards or achievements ship. Recommend a rule and its rationale. Do not derive wins from `rank == 1` or retain hidden automatic rarity winning points.

Design for two concurrent cohorts plus a neighborhood player. Handle delayed checkout animations, destroyed markets, identical item names and distinct variants, late joins, departures, stale results, replay button duplication, out-of-round requests and duplicate reward/purchase delivery. An in-memory processed-round table does not establish cross-server durability.

Keep physical furniture quantities, reusable designs and ride ownership distinct. Show a tested economy model meeting the accepted newcomer pacing, including an early furniture purchase before the ride. Define what XP means and unlocks without inventing paid competitive advantages. Preserve existing balances, ownership and house placements through serialization changes. Use isolated preview profiles for fixture mutations and preserve current profile-load recovery.

## Produce the implementation handoff

Return these artifacts as files, or clearly separated complete documents if file output is unavailable:

1. `beta-architecture.md`: shared contracts, source ownership, dependency graph, chosen decisions versus unresolved experiments, release scope and acceptance gates.
2. `movement-architecture.md`: solver/input design, tuning experiment order, types/interfaces, code ownership and first tickets.
3. `environment-architecture.md`: buildable 3D/store specification, asset workflow, Astra responsibilities, geometry/movement contract and visual/playable acceptance.
4. `gameplay-architecture.md`: round/collection/result/profile contracts, onboarding and full-session flows, economy/XP/quantity plan and migration verification.
5. `implementation-queue.md`: ordered tickets and ready-to-send prompts for the lead and each workstream orchestrator. Include the exact next assignment rather than asking another agent to invent the plan.

Each first ticket names its player outcome, source/scene inputs, editable files, dependencies, selected model and effort, concrete change, acceptance checks, evidence to save, escalation condition and stop condition. Assign at least one real Astra construction ticket and one suitable Luna implementation ticket. State which tasks can run together under the actual concurrency limit.

Perform a final reconciliation across all four architecture documents. Check that movement limits, stock/checkout ownership, template lifetimes, shared files and verification requirements agree. Resolve contradictions in the documents before handing them to separate orchestrators.

Recommend the smallest first playable candidate: a polished section with two departments, an ordinary route, optional riding elements and checkout, feeding the exact checked-out pieces into the main game's real Style placement. Continue the queue through complete multiplayer Judge/Results, replay/home, and the accepted neighborhood progression milestones. The first slice does not replace the requirement for a full cohesive store.

Finish by giving the user the exact launch prompt for the implementation lead, which artifact to attach, the first runnable tickets and only those decisions that block them. If this Pro session has explicitly authorized execution tools, it may dispatch the ready first assignments after architecture reconciliation. Otherwise provide a complete handoff and accurately state that execution has not started. Never claim to have launched agents, built assets, run Studio acceptance or enabled scheduled work without actual evidence.

Make routine reversible choices autonomously. Preserve accepted product decisions. Reserve user questions for substantive unresolved choices that block a specific step; keep independent architecture work moving. Do not turn uncertainty about a later feature into a reason to withhold the first executable handoff.
