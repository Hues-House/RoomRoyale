# Live place source sync

## Goal

Move the active Lua source from the open `Room Royale - Test` Studio place into the Rojo tree without changing or publishing the Studio place.

The sync is complete when all of these checks pass:

- Every in-scope `LuaSourceContainer` has one deterministic file in `src/`.
- A generated manifest records each Studio path, Roblox class, disabled state, byte count, line count, and source hash.
- A verifier compares the imported files with that manifest and reports no missing, extra, or changed scripts.
- `rojo build default.project.json` succeeds from the imported tree.
- The open Studio place remains in Edit mode and is never published or overwritten.

## Scope

The September 6 inventory found 57 Lua source containers and roughly 700 KB of source.

Import into the managed Rojo tree:

- all modules directly under `ReplicatedStorage`
- active gameplay scripts and modules directly under `ServerScriptService`
- `ProfileService` and current Studio tooling under `ServerStorage`
- all scripts directly under `StarterPlayer.StarterPlayerScripts`

Keep out of the runtime tree:

- seven disabled scripts nested in `ServerStorage.NewLoft_Archive`

Those scripts belong to third-party or retired decorative models. Their source will be listed in the inventory manifest as excluded, with the reason recorded, so they cannot silently become runtime code.

## Rigor

This is a high-rigor migration. The live Studio place currently owns the only complete source set. A missing or misclassified script could produce a clean-looking repository that does not rebuild the game.

The migration therefore uses read-only Studio calls, deterministic path mapping, source hashes, a rerunnable verifier, and a Rojo build gate. No Studio edits are part of this phase.

## Work units

1. Capture the live script inventory and pre-sync scene evidence.
2. Import one small module by hand to prove the filename and source-decoding rule.
3. Build a deterministic importer for the remaining scripts.
4. Generate the source manifest and record excluded archive scripts.
5. Verify every imported file against its manifest entry.
6. Run repository validation and a Rojo build.
7. Compare the rebuilt hierarchy with the live script hierarchy.
8. Hand back the verified source boundary before redesigning the Neighborhood.

Each unit must finish as `VERIFIED`, `NOT VERIFIED`, or `INCONCLUSIVE`. Work does not advance on an inconclusive result when the next unit depends on it.
