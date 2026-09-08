# Current documentation

The repository contains two working builds and one approved plan. The main Test game has the neighborhood and complete decorating rounds. Hillside v4 is the separate cart, market, and pump-park prototype. [The refinement plan](refinement-plan-2026-09-08.md) connects them and defines the next features; those changes remain unimplemented.

Open the complete [main Test snapshot](../places/RoomRoyale-Test.rbxlx) or [Hillside snapshot](../places/RoomRoyale-Hillside.rbxlx) in Studio. The main Test was also saved to Roblox. Hillside remains a local prototype, and this sync did not publish Live.

## Start here

| Document | Use it for |
| --- | --- |
| [Project status and workflow](../README.md) | Build boundaries, source locations, and verification commands |
| [Agent guide](../AGENTS.md) | Working rules and product constraints |
| [Refinement plan](refinement-plan-2026-09-08.md) | Accepted decisions, build sequence, implementation gaps, and acceptance criteria |
| [Game systems](game_systems.md) | Current server ownership and integration boundaries |
| [UI systems](ui_system.md) | Current input, HUD, inventory, and presentation ownership |
| [Vocabulary](../CONTEXT.md) | Round, house, cargo, collection, ownership, and earned-design terms |
| [Writing guide](writing_guide.md) | Player-facing words and feedback examples |
| [Verification](verification.md) | Current checks, saved-place comparison, and outstanding release acceptance |
| [Cart lab](cart-lab.md) | Tool setup, current ride controls, and the isolated movement test course |

## Implemented work and evidence

| Document | What its evidence covers |
| --- | --- |
| [Neighborhood build](neighborhood-build-2026-09-07.md) | Eight cottages, doors, lot lifecycle, house-local saved placements, and verified source installation |
| [Hillside v4 playtest](playtest-iteration-v4-2026-09-08.md) | Current market and pump park, movement, stacking, checkout, limited stock, and known device limits |
| [Handling playtest](cart-playtest-handling-2026-09-08.md) | Charged jumps, airborne dive, wall ejection and recovery, and movement regression checks |
| [Cargo playtest](cart-playtest-cargo-2026-09-08.md) | Exact-model stacking, variant identity, checkout, and inventory boundaries |
| [Design research](playtest-design-research-2026-09-08.md) | Sourced Roblox guidance and game examples, separated from project recommendations |
| [Saved-place verification](evidence/studio-repo-sync.json) | Managed script comparison between fresh builds and both complete saved Studio scenes |

The reports link their captured JSON results in `docs/evidence/`. Test measurements describe the named build and environment. They do not establish a Live release or completion of later plans.

## Editable assets

| Document | Asset workflow |
| --- | --- |
| [Procedural furniture catalog](procedural-furniture-catalog.md) | Native furniture generators, candidates, and Studio installation |
| [Furniture art study](../authoring/art-study/README.md) | Blender and GLB sources, private Roblox assets, review gallery, and verification |
| [Physical scale standard](../authoring/art-study/physical-scale-standard.md) | Furniture dimensions and avatar-relative proportions |
| [Cart flatbed](../authoring/cart-flatbed/README.md) | Editable cart model, dimensions, and asset checks |

Update the current owning document when behavior changes. Keep accepted future work in the refinement plan and past experiments in Git history or local backups. A dated report remains useful when it is the evidence for the current implementation; its older product proposals do not override the accepted plan.
