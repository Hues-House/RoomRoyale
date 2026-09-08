# Saved Studio scenes

These are complete native Roblox Studio XML saves from September 8, 2026 UTC.

| Scene | Open it for |
| --- | --- |
| [RoomRoyale-Test.rbxlx](RoomRoyale-Test.rbxlx) | Current neighborhood, houses, main decorating rounds, furniture assets and editable authoring content. Also saved to Roblox Test place `86511797738570`, universe `10764620924`. |
| [RoomRoyale-Hillside.rbxlx](RoomRoyale-Hillside.rbxlx) | Current standalone market, cart and pump-park playtest. The map builds when Play starts. This local prototype is separate from the main Test game. |

The Test scene includes retained authoring modules and disabled archive scripts. Its 54 managed scripts match `default.project.json`; all 26 Hillside scripts match `superstore.project.json`. [Verification evidence](../docs/evidence/studio-repo-sync.json) records source comparisons and scene hashes. Replace these snapshots when their owning code or Studio assets change, then run `python tools/Verify-PlaceSnapshots.py --report docs/evidence/studio-repo-sync.json` from the repository root.

For source work, use the project paths in [README](../README.md). The main Rojo project contains managed scripts and does not reconstruct the complete scene on its own. Snapshot verification compares managed script source, class and disabled state; it does not test gameplay or asset permission access on another account. Meshes/textures backed by Roblox asset IDs still require appropriate Roblox access.

The [approved refinement plan](../docs/refinement-plan-2026-09-08.md) is future work. These saves do not implement it or publish an update to the Live game.
