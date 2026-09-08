# Main Test source

This tree owns the main Test game's managed Luau scripts. `default.project.json` maps them into Roblox services. [Game systems](../docs/game_systems.md) and [UI systems](../docs/ui_system.md) identify the owner of each behavior.

Open [places/RoomRoyale-Test.rbxlx](../places/RoomRoyale-Test.rbxlx) for the complete Studio scene. It includes the map, terrain, furniture models, and other instances outside this script tree. The main Test was also saved to Roblox, PlaceId `86511797738570`, GameId `10764620924`.

The separate Hillside prototype uses `packages/RideRuntime/`, `prototype/cart-lab/`, and `prototype/superstore/`. Those mechanics have not yet been integrated into this main source tree. [The refinement plan](../docs/refinement-plan-2026-09-08.md) records the approved integration and progression changes.

After changing main scripts and saving the matching Studio place, run:

```powershell
pwsh -NoProfile -File tools/Verify-RojoBuild.ps1
python tools/Verify-PlaceSnapshots.py
```

Run these commands from the repository root with Rojo on `PATH` and Python 3 installed. The first verifies the script package. The second compares the managed script paths, classes, disabled states, and normalized sources in fresh builds against both saved scenes. It also reports additional scripts preserved in each scene.

The [sync evidence](../docs/evidence/studio-repo-sync.json) records the saved snapshots and their comparison. [Verification](../docs/verification.md) lists the device, multiplayer, persistence, and asset checks that remain open.
