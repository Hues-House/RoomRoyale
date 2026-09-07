# Roblox source tree

Rojo maps the folders below into Roblox services:

- `ReplicatedStorage/` for shared modules, remotes, and assets.
- `ServerScriptService/` for server authorities.
- `ServerStorage/` for server-only templates and assets.
- `Workspace/` for authored map content.
- `StarterGui/` for authored UI.
- `StarterPlayer/StarterPlayerScripts/` for client controllers.

The active test-place scripts were imported on September 6, 2026. This tree is now the source of truth for script changes. Check the owning system in `docs/game_systems.md` or `docs/ui_system.md` before editing it.

Map geometry, terrain, furniture models, and other non-script instances remain Studio-owned until they receive an explicit Rojo representation. Do not assume a successful script build reproduces the full place.
