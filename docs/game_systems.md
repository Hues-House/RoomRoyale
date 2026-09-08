# Game systems

This map describes repository source as reviewed on September 8, 2026. The main Test game and Hillside v4 are separate implementations. [The refinement plan](refinement-plan-2026-09-08.md) defines their integration and the approved changes to controls, competition inventory, judging, and progression.

## Main Test game

All paths in this section are below `src/`. `default.project.json` maps these scripts into Roblox services. [RoomRoyale-Test.rbxlx](../places/RoomRoyale-Test.rbxlx) preserves the complete scene, including Studio-owned assets. The main Test was also saved to Roblox during this sync.

| Responsibility | Owning source |
| --- | --- |
| Queue and round lifecycle | [RoundManager](../src/ServerScriptService/RoundManager.server.lua) |
| Main showroom and per-round store instances | [ShowroomBootstrap](../src/ServerScriptService/ShowroomBootstrap.lua), [StoreSetup](../src/ServerScriptService/StoreSetup.server.lua) |
| Main cart, pickup, contents, and capacity | [CartService](../src/ServerScriptService/CartService.server.lua) |
| Main cart impacts | [CartCollision](../src/ServerScriptService/CartCollision.server.lua) |
| Competition rooms, inventory, placement, and appearance | [RoomService](../src/ServerScriptService/RoomService.server.lua) |
| Room tours, votes, scoring, and result rewards | [JudgeService](../src/ServerScriptService/JudgeService.server.lua) |
| Neighborhood layout and common buildings | [NeighborhoodLayout](../src/ReplicatedStorage/NeighborhoodLayout.lua), [NeighborhoodBootstrap](../src/ServerScriptService/NeighborhoodBootstrap.lua) |
| Cottage construction, door motion, and lot lifecycle | [HouseTemplateBuilder](../src/ServerScriptService/HouseTemplateBuilder.lua), [HouseDoorController](../src/ServerScriptService/HouseDoorController.lua), [HouseLotService](../src/ServerScriptService/HouseLotService.lua) |
| Player houses, support validation, and saved positions | [HousingService](../src/ServerScriptService/HousingService.lua), [HousePlacementGeometry](../src/ServerScriptService/HousePlacementGeometry.lua) |
| Profiles, purchases, ownership, and house records | [ProgressionService](../src/ServerScriptService/ProgressionService.lua), [ProfileService](../src/ServerStorage/ProfileService.lua) |
| Progression values and purchase catalog | [ProgressionConfig](../src/ReplicatedStorage/ProgressionConfig.lua), [PersistentStoreCatalog](../src/ReplicatedStorage/PersistentStoreCatalog.lua) |
| Item and theme metadata | [ItemDatabase](../src/ReplicatedStorage/ItemDatabase.lua), [ItemCatalogData](../src/ReplicatedStorage/ItemCatalogData.lua), [ThemeDatabase](../src/ReplicatedStorage/ThemeDatabase.lua) |

### Round ownership

The neighborhood remains available while opted-in cohorts play rounds. `RoundManager` records each active round and its player membership. It sets player `RoundPhase` and `RoundId` attributes, sends `RoundPhaseChanged` to that cohort, and fires `RoundPhaseServer(roundId, phase, cohort)` for server systems.

`GamePhase` stays `Hub`. It does not represent an individual player's round. Themes are stored on the round, but `chooseThemes` and `RoundThemeReplicator` also publish global theme attributes. Those remaining shared values are an integration risk when rounds overlap.

The current configured Shop duration is 90 seconds and Style duration is 120 seconds. Judge invokes the cohort's tour and vote sequence. Results returns the cohort to the plaza. Queue size and timing are in `RoundManager`'s `CFG` table.

The main cart has a server-enforced 15-item limit. `CartController` and `PickupEffect` duplicate that count for their displays. `ShopTargeting` supplies the focused item to the client; `CartService` validates the pickup request.

At Style start, `RoomService` turns cart contents into item-ID counts and adds permanent owned furniture. `JudgeService` combines player votes with automatic theme and rarity contributions. Both behaviors differ from the approved competition rules.

### Houses and progression

Eight cottage lots surround the central green. `HouseLotService` keeps a visible vacant house while an owner's profile loads, replaces it when the owner house is ready, and restores a vacancy after departure. The three shop buildings exist, while the existing purchase pedestals remain the active purchasing interface.

`HousingService` restores player furniture and finishes into the cottage shell. New placement records use `house-local-v2`, so furniture moves with the player's house when its lot changes. Unplaceable legacy records remain saved for later repositioning. [The neighborhood report](neighborhood-build-2026-09-07.md) records the geometry and lifecycle checks.

`ProgressionService` uses ProfileService with the configured store name plus `_PS`. Studio uses mock profiles only when `ServerStorage.NeighborhoodPreviewProfiles` is true before Play. Ordinary Test sessions use the configured saved profiles.

Current profiles start with 400 Style Bucks. Furniture ownership is keyed by item type, duplicate purchases are rejected, and placement is limited to one copy of a type. Quantity purchases, ride ownership, earned designs, achievement progress, and the accepted first-purchase pacing remain to build. The profile sanitizer must explicitly preserve their future fields.

## Hillside v4 prototype

`superstore.project.json` builds this standalone place. `StoreSession` runs a 150-second shopping demonstration through the cart runtime. It does not invoke the main `RoundManager`, `RoomService`, or `JudgeService`.

| Responsibility | Canonical source |
| --- | --- |
| Chassis forces, ground support, and air behavior | [Chassis](../packages/RideRuntime/Chassis.lua) |
| Handling and load coefficients | [Profiles](../packages/RideRuntime/Profiles.lua) |
| Charge, drift, release, and dive intent | [Gesture](../packages/RideRuntime/Gesture.lua) |
| Cart spawn, pickup authority, finite stock, replicated cargo, and session endpoints | [Cart server](../prototype/cart-lab/Server.server.lua) |
| Shopping deadlines, checkout settlement, and exported collection | [ShoppingSession](../prototype/cart-lab/ShoppingSession.lua) |
| Exact template and variant identity | [ItemPresentation](../prototype/cart-lab/ItemPresentation.lua) |
| Visible cargo stack and tube animation | [Cargo](../prototype/cart-lab/Cargo.lua) |
| Wall impact and rider recovery | [Crashes](../prototype/cart-lab/Crashes.lua), [Runner](../prototype/cart-lab/Runner.lua) |
| Market and item routes | [Store](../prototype/superstore/Store.lua), [Geometry](../prototype/superstore/Geometry.lua), [Props](../prototype/superstore/Props.lua) |
| Pump loop and trick route | [PracticePark](../prototype/superstore/PracticePark.lua) |
| Practice, market, and timed-round requests | [StoreSession](../prototype/superstore/StoreSession.server.lua) |

Both `superstore.project.json` and `cart-lab.project.json` map the canonical ride and cart modules directly. [RoomRoyale-Hillside.rbxlx](../places/RoomRoyale-Hillside.rbxlx) is the complete saved local prototype.

The prototype uses a 100-space cart. Cargo copies the shelf model at 86 percent scale, stacks from its actual bounds, and preserves item and variant identity through checkout. The market has an open floor, floating signs, limited-item jump routes, and a separate east-side pump park. Its Style state exposes a demonstration collection.

The current controls use cart steering with independent native camera orbit. Charged jumps, reduced air gravity, a second airborne press for dive, cosmetic flight poses, and wall recovery are implemented. The spring jump cue remains. [The v4 report](playtest-iteration-v4-2026-09-08.md) contains measured results and remaining device checks.

## Integration boundaries

These are current gaps with accepted next work, not completed features:

- Replace the main showroom and cart through the cohort lifecycle. Keep each round's theme, stock, collection, and result isolated.
- Finish checkout settlement and preserve each piece's identity and variant before releasing the store. `RoundManager` currently releases the main store before announcing Style.
- Feed the actual delivered collection into the real styling room. Apply the agreed house-only rule to permanent physical furniture in both server inventory and client presentation.
- Reconcile judging, reward calculation, profile serialization, and pricing with the approved progression rules.
- Separate deliberate drift input from camera-relative steering corrections.
- Test quarter-pipe support and crash classification before adding the planned megaramp and skateboard.

Acceptance drivers live in `tests/ride`, `tests/superstore`, and the neighborhood tools. Pure Luau and Rojo checks establish rules and packaging. Actual Studio runs establish geometry, physics, replication, and input behavior within the limits recorded in each report.

[Verification](verification.md) lists the remaining release requirements. `tools/Verify-PlaceSnapshots.py` compares each saved scene's managed scripts with a fresh Rojo build and records extra scene scripts separately.
