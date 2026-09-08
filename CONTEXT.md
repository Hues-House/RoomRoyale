# Room Royale vocabulary

These terms describe the current product direction. [Game systems](docs/game_systems.md) records implemented behavior. [The refinement plan](docs/refinement-plan-2026-09-08.md) records accepted changes that remain to build.

## Rounds

| Term | Meaning |
| --- | --- |
| Round | One `Shop -> Style -> Judge -> Results` cycle for an opted-in group of players. Several round cohorts can exist in one server. |
| Cohort | The players assigned to one round and its `RoundId`. |
| Theme | The design prompt used to choose pieces, style a room, and judge its interpretation. |
| Shop | The timed phase for driving a standard shopping cart and collecting pieces. |
| Style | The timed phase for arranging and customizing the round collection. |
| Judge | The room tour and player voting phase. |
| Results | The round outcome and reward presentation. Play again and Back to neighborhood are approved next actions, not current completed UI. |
| Style room | A player's temporary competition room. It is separate from their permanent house. |
| Room reveal | The presentation of a styled room to the other players. |
| Appreciation vote | The current token vote submitted for another player's room. The final voting presentation remains to be refined. |

## Shopping and decorating

| Term | Meaning |
| --- | --- |
| Store item or piece | Furniture, decor, or an accent piece available during Shop. |
| Cart | The shopping vehicle that carries a player's current cargo. Owned neighborhood rides remain separate from round carts. |
| Cargo | Pieces physically carried on the cart before checkout. |
| Cart space | The prototype's capacity budget. Pieces consume different amounts of its 100-space limit. The older main cart instead has a 15-item limit. |
| Checkout | The place where cargo is delivered. Hillside animates the carried pieces through a tube. |
| Delivered collection | Pieces successfully checked out in the current shopping session. Prototype code also calls these pieces banked or saved. |
| Round collection | The temporary pieces available during Style. The approved rule uses collected pieces, shared basic tools, and compatible earned designs. The main code still grants owned furniture as well. |
| Variant | The specific model or appearance of a piece. Hillside preserves variant identity through pickup and checkout. |
| Placement | One piece positioned in a style room. |
| Earned design | A permanent artwork or rug appearance unlocked through an accomplishment. This planned system applies designs to compatible physical pieces without granting more pieces. |
| Limited item | A special store piece with constrained stock or a route requirement. Hillside's limited stock replenishes at the next round. |

## Neighborhood and progression

| Term | Meaning |
| --- | --- |
| Neighborhood | The shared area available between rounds, with houses, shops, and social riding. Internal code also uses `Hub` and `Lobby`. |
| House | A player's permanent decorating space. Its furniture and finishes survive rejoining. |
| Lot | One address in the neighborhood that holds an occupied or vacant house. |
| House placement | A saved furniture instance positioned relative to its house. Current new records use `house-local-v2`. |
| Style Bucks | The progression currency earned through rounds and spent on furniture. |
| Owned furniture | Physical furniture bought for a house. Purchasable quantities and duplicate pieces are approved next work. Current code stores ownership by item type. |
| Ride | An owned neighborhood skateboard, stroller, scooter, or bike in the approved direction. The first planned implementation is one skateboard. |
| Achievement | A verified accomplishment that can unlock a permanent design. Initial targets and persistence are planned. |

The round and the neighborhood each reward play. The house provides an additional reason to return, while decorating rounds remain enjoyable independently.

## Source and verification

| Term | Meaning |
| --- | --- |
| Main Test game | The managed `src/` game and its Studio-owned scene in Test PlaceId `86511797738570`, GameId `10764620924`. The complete local snapshot is [RoomRoyale-Test.rbxlx](places/RoomRoyale-Test.rbxlx), and the main Test was saved to Roblox during this sync. |
| Hillside v4 | The separately built market and pump-park prototype, saved locally as [RoomRoyale-Hillside.rbxlx](places/RoomRoyale-Hillside.rbxlx). Its final Style state is a collection demonstration, not the main decorating round. |
| Saved place snapshot | A full Studio place file that preserves scene instances as well as scripts. The repository keeps the current snapshots in `places/`. |
| Rojo script build | The output of `default.project.json`. It verifies packaged scripts but does not contain the complete main Test scene. |
| Published place | A version saved to Roblox through a publication action. Local saves and Git commits do not establish publication. |
| Acceptance evidence | Recorded checks of the actual behavior, including environment, results, and remaining limits. |

The main implementation still calculates automatic theme and rarity contributions alongside player votes. These are existing scoring fields, not the agreed judging policy. The refinement plan removes automatic rarity winning points and centers the finished room and its theme interpretation.
