# Room Royale agent guide

Room Royale is a Roblox decorating competition with a permanent neighborhood. A round must be enjoyable on its own. Houses, earned furniture, and rides provide additional goals and social expression between rounds.

## Start with the right state

- Read [README.md](README.md) for the implemented main game, separate Hillside prototype, and approved next work.
- For product decisions, scope, or acceptance criteria, read [the refinement plan](docs/refinement-plan-2026-09-08.md). Its accepted decisions supersede older design notes. Mark a feature implemented only after changing and verifying the owning runtime.
- For gameplay changes, read [game systems](docs/game_systems.md). For controls, HUD, or player interaction, also read [UI systems](docs/ui_system.md).
- For terms and player-facing copy, use [CONTEXT.md](CONTEXT.md) and [the writing guide](docs/writing_guide.md).

## Preserve the approved experience

Rounds follow `Shop -> Style -> Judge -> Results`. Theme interpretation, shopping choices, room transformation, and the reveal should make players want another round. Neighborhood progression starts with an empty house and no owned ride in the approved plan.

Preserve the tested v4 jumps, airborne dive, and recognizable stacked furniture. The milestone 1 prototype candidate uses camera-relative movement with a separate Drift action. The main game still uses the older cart. Read the [milestone 1 report](docs/cart-refinement-m1-2026-09-08.md) for completed checks and remaining acceptance before changing those controls.

Permanent physical furniture belongs in houses under the approved rules. Earned artwork and rug designs can customize compatible pieces collected in a round. Player judging decides the outcome without automatic rarity points. Existing inventory and scoring code still differs from these rules.

## Change the owning source

`src/` owns the main Test game's managed scripts. `packages/RideRuntime/` and `prototype/cart-lab/` own the prototype ride and cart modules. Both prototype projects map those canonical modules directly. Change each shared module in its owning location.

Keep each round's phase, collection, theme, and result attached to its own cohort. `RoundManager` uses player `RoundPhase` and `RoundId` attributes. The global `GamePhase` stays `Hub` and is not the participant's round phase. Remaining global theme attributes need attention during integration.

Keep pickup, inventory, purchases, placement, and rewards authoritative on the server. In the main game, `ShopTargeting` supplies one focused item to the clients and `CartService` validates pickup. Main cart count limits differ from the prototype's space budget; use the correct system's rules.

## Save and verify

The complete current scenes are `places/RoomRoyale-Test.rbxlx` and `places/RoomRoyale-Hillside.rbxlx`. The main Rojo project contains scripts but not every Studio-owned asset. Preserve the full place when saving scene work, then run `tools/Verify-PlaceSnapshots.py`. Identify the Studio place before installing source; the configured Test PlaceId is `86511797738570`.

Use relevant build checks and actual Studio acceptance for the changed behavior. Document which device and multiplayer paths were exercised. Source inspection alone does not prove camera feel, phone layout, or simultaneous networked play.

For release readiness, use [verification](docs/verification.md). It preserves the open device, persistence-failure, multiplayer, new-player, and asset checks. Saving the main Test place to Roblox does not close those acceptance requirements.

Progression tests that mutate fixtures use isolated preview profiles. The current opt-in is `ServerStorage.NeighborhoodPreviewProfiles = true` before Play. Restore ordinary configuration and remove temporary test drivers after acceptance. Preserve existing player ownership and saved placements when changing serialization.

Update the relevant current report and source map with a behavior change. Keep implementation status separate from plans and evidence limits. Save, commit, and publication are distinct results; report only the ones verified.
