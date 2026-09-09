# Current documentation

The repository contains two working builds and one approved plan. The main Test game has the neighborhood and complete decorating rounds. Hillside is the separate cart, market, and pump-park prototype, now with a [milestone-1 cart candidate](cart-refinement-m1-2026-09-08.md). [The refinement plan](refinement-plan-2026-09-08.md) connects them and defines the next features. Milestone 1 has remaining playtest acceptance; milestones 2–5 remain unimplemented. The [proposed cart physics](#proposed-cart-physics) briefs are separate from that plan and none has been accepted.

Open the complete [main Test snapshot](../places/RoomRoyale-Test.rbxlx) or [Hillside snapshot](../places/RoomRoyale-Hillside.rbxlx) in Studio. The main Test was also saved to Roblox. Hillside remains a local prototype, and this sync did not publish Live.

## Start here

| Document | Use it for |
| --- | --- |
| [Pro beta architecture kickoff](beta/pro-architecture-kickoff.md) | Shared architecture, three workstream plans, model routing, and executable implementation handoffs |
| [Beta orchestration and work packages](beta/README.md) | Integration ownership, specialist findings, work queue, and baseline evidence |
| [Project status and workflow](../README.md) | Build boundaries, source locations, and verification commands |
| [Agent guide](../AGENTS.md) | Working rules and product constraints |
| [Refinement plan](refinement-plan-2026-09-08.md) | Accepted decisions, build sequence, implementation gaps, and acceptance criteria |
| [Cart implementation brief](cart-refinement-implementation-brief-2026-09-08.md) | Milestone-1 scope and implementation handoff |
| [Round integration draft](round-integration-implementation-brief-2026-09-08.md) | Proposed milestone-2 implementation, ownership boundaries, and open judging decision |
| [Game systems](game_systems.md) | Current server ownership and integration boundaries |
| [UI systems](ui_system.md) | Current input, HUD, inventory, and presentation ownership |
| [Vocabulary](../CONTEXT.md) | Round, house, cargo, collection, ownership, and earned-design terms |
| [Writing guide](writing_guide.md) | Player-facing words and feedback examples |
| [Verification](verification.md) | Current checks, saved-place comparison, and outstanding release acceptance |
| [Cart lab](cart-lab.md) | Tool setup, current ride controls, and the isolated movement test course |

## Proposed cart physics

Five briefs dated September 9 propose the cart handling, air, and park-riding work. None is implemented, and no build has been played against any of them. Later briefs supersede parts of earlier ones, so read them in this order and check each brief's own supersede notes before acting on a number.

| Document | Status and scope |
| --- | --- |
| [Handling and weight brief](cart-handling-weight-brief-2026-09-09.md) | Terminal speed, lateral acceleration cap, progressive grip, landing bleed. Its diagnosis and its grounded hysteresis are superseded |
| [Air and tricks brief](cart-air-tricks-turning-brief-2026-09-09.md) | Air gravity, ramp pop, dive payoff, trick scoring, pumping. Its diagnosis and input scheme are superseded |
| [Control model brief](cart-control-model-brief-2026-09-09.md) | Ground-feel numbers read from the shipped `src/` controller. Its split-by-contact recommendation is superseded |
| [One-button input brief](cart-one-button-input-brief-2026-09-09.md) | Current. Jump, drift, dive, and trick on one button, and the input-plumbing bug that split them |
| [Contact model brief](cart-contact-model-brief-2026-09-09.md) | Current. One force solver with a continuous ground-contact value, plus what vert riding and pumping need |

The first three carry tuning tables that still stand even where their reasoning was replaced. The last two settle the input scheme and the physics architecture.

## Implemented work and evidence

| Document | What its evidence covers |
| --- | --- |
| [Neighborhood build](neighborhood-build-2026-09-07.md) | Eight cottages, doors, lot lifecycle, house-local saved placements, and verified source installation |
| [Cart milestone-1 candidate](cart-refinement-m1-2026-09-08.md) | Camera-relative controls, capacity feedback, loaded physics, desktop pickup/checkout, and interrupted acceptance |
| [Hillside v4 playtest](playtest-iteration-v4-2026-09-08.md) | Earlier market and pump-park baseline, movement, stacking, checkout, limited stock, and known device limits |
| [Handling playtest](cart-playtest-handling-2026-09-08.md) | Charged jumps, airborne dive, wall ejection and recovery, and movement regression checks |
| [Cargo playtest](cart-playtest-cargo-2026-09-08.md) | Exact-model stacking, variant identity, checkout, and inventory boundaries |
| [Design research](playtest-design-research-2026-09-08.md) | Sourced Roblox guidance and game examples, separated from project recommendations |
| [Current saved-place verification](evidence/cart-refinement-m1/snapshot-verification.json) | Managed script comparison between fresh builds and both complete saved scenes after milestone 1 |

The reports link their captured JSON results in `docs/evidence/`. Test measurements describe the named build and environment. They do not establish a Live release or completion of later plans.

## Editable assets

| Document | Asset workflow |
| --- | --- |
| [Procedural furniture catalog](procedural-furniture-catalog.md) | Native furniture generators, candidates, and Studio installation |
| [Furniture art study](../authoring/art-study/README.md) | Blender and GLB sources, private Roblox assets, review gallery, and verification |
| [Physical scale standard](../authoring/art-study/physical-scale-standard.md) | Furniture dimensions and avatar-relative proportions |
| [Cart flatbed](../authoring/cart-flatbed/README.md) | Editable cart model, dimensions, and asset checks |

Update the current owning document when behavior changes. Keep accepted future work in the refinement plan and past experiments in Git history or local backups. A dated report remains useful when it is the evidence for the current implementation; its older product proposals do not override the accepted plan.
