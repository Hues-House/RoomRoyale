# Saved Studio scenes

These scenes originate from complete native Roblox Studio XML saves from September 8, 2026 UTC. Hillside's managed scripts were subsequently updated on disk for the milestone-1 candidate, preserving the rest of its scene.

| Scene | Open it for |
| --- | --- |
| [RoomRoyale-Test.rbxlx](RoomRoyale-Test.rbxlx) | Current neighborhood, houses, main decorating rounds, furniture assets and editable authoring content. Also saved to Roblox Test place `86511797738570`, universe `10764620924`. |
| [RoomRoyale-Hillside.rbxlx](RoomRoyale-Hillside.rbxlx) | Current standalone market, cart and pump-park playtest. The map builds when Play starts. This local prototype is separate from the main Test game. |

The Test scene includes retained authoring modules and disabled archive scripts. Its 54 managed scripts match `default.project.json`; all 30 Hillside managed scripts match `superstore.project.json`. [Current verification evidence](../docs/evidence/cart-refinement-m1/snapshot-verification.json) records source comparisons and scene hashes. [The preservation report](../docs/evidence/cart-refinement-m1/snapshot-sync.json) records the file-only Hillside update. Run `python tools/Verify-PlaceSnapshots.py` after changing managed source or a snapshot. Use `tools/Sync-HillsideSnapshot.py` for a dry-run preview of managed Hillside script updates and `--write` to apply them.

For source work, use the project paths in [README](../README.md). The main Rojo project contains managed scripts and does not reconstruct the complete scene on its own. Snapshot verification compares managed script source, class and disabled state; it does not test gameplay or asset permission access on another account. Meshes/textures backed by Roblox asset IDs still require appropriate Roblox access.

Hillside contains the [milestone-1 cart candidate](../docs/cart-refinement-m1-2026-09-08.md), with remaining playtest acceptance. Main-game integration and milestones 2–5 of the [approved refinement plan](../docs/refinement-plan-2026-09-08.md) remain future work. The candidate update used file operations only; it did not save, export or publish through Studio.
