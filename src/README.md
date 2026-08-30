# Roblox source tree

Rojo maps the folders below into Roblox services:

- `ReplicatedStorage/` for shared modules, remotes, and assets.
- `ServerScriptService/` for server authorities.
- `ServerStorage/` for server-only templates and assets.
- `Workspace/` for authored map content.
- `StarterGui/` for authored UI.
- `StarterPlayer/StarterPlayerScripts/` for client controllers.

Import live Studio scripts here only after checking the owning system in `docs/game_systems.md` or `docs/ui_system.md`. Keep the live place as the runtime source of truth until the imported tree has passed the acceptance checks.
