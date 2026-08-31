# Room Royale context

Room Royale is a multiplayer decorating competition. Players shop for pieces, style a personal room, and judge the finished rooms against a shared theme.

## The round

**Round**:
A complete `Shop -> Style -> Judge -> Results` cycle for the players in one server.
_Avoid_: Match, mission, run

**Theme**:
The design prompt that guides item choices and gives the judge phase a shared basis.
_Avoid_: Quest, objective, challenge

**Shop**:
The timed phase where players race through the store in carts and collect pieces for the theme.
_Avoid_: Extraction, scavenger hunt, loot run

**Style**:
The timed phase where each player arranges and customizes pieces in their own room.
_Avoid_: Build mode, home phase, decorating mode

**Judge**:
The phase where players tour the rooms and submit appreciation votes.
_Avoid_: Combat, contest screen, scoring screen

**Results**:
The phase where the game reveals scores, ranks the rooms, and returns players to the lobby.
_Avoid_: End screen, payout screen

## Rooms and pieces

**Style room**:
The room assigned to one player for a round. It is the space other players tour during judging, and it is discarded when the round ends.
_Avoid_: Plot, base, house (a House is the persistent thing)

**Store item**:
A furniture, decor, or accent piece that a player can collect during Shop.
_Avoid_: Loot, pickup, prop

**Cart**:
The player-owned shopping vehicle used to move through Shop and carry collected items.
_Avoid_: Vehicle, inventory carrier

**Round collection**:
The set of pieces the player can use during Style after Shop transfers the round's cart contents. It lasts one round.
_Avoid_: Owned items, permanent inventory, stash, loadout

**Placement**:
Putting a collected piece into a style room at a chosen position, rotation, surface, or appearance.
_Avoid_: Spawn, drop, deploy

**Room reveal**:
The moment in Judge when a styled room is presented to the other players for viewing and voting.
_Avoid_: Showcase, presentation, reveal screen

## Judging

**Appreciation vote**:
A player's token allocation to another player's room during Judge.
_Avoid_: Like, upvote, rating

**Mechanical theme score**:
The part of a room's result based on how its placed pieces match the required and bonus pieces for the theme.
_Avoid_: Objective score, compliance score

**Aesthetic score**:
The part of a room's result based on appreciation votes from other players.
_Avoid_: Style points, popularity score

## Shop conflict

**Ram**:
Driving a Cart into another player's Cart hard enough to knock the rider out. It is the main way a Shop player expresses skill and the reason boost and drift matter.
_Avoid_: Attack, hit, grief

**Knockout**:
The state a rammed rider enters on a hard impact. The rider is thrown, briefly loses control, and can drop a carried Store item.
_Avoid_: Stun, death, downed

**Shield**:
The protection a Shop player can use to survive a Ram without being knocked out.
_Avoid_: Armor, powerup, buff

**Checkout zone**:
A place in the Shop where a loaded player is safe from Rams and can end their Shop phase early.
_Avoid_: Extraction point, safe room, exit

## Persistence and progression

**House**:
The room a player owns permanently and decorates between rounds. Unlike a Style room it survives rejoining, and it is the reason to keep playing past one round.
_Avoid_: Style room, plot, base, apartment

**Style Bucks**:
The currency a player earns by finishing rounds and spends on Owned items.
_Avoid_: Coins, cash, points

**Owned item**:
A piece the player has bought with Style Bucks and can place in their House forever. Distinct from the Round collection, which is temporary.
_Avoid_: Owned collection, unlock, inventory item

**Neighborhood**:
The persistent shared space players occupy between rounds. Every player's House sits here, and it is where a player spends Style Bucks and decorates.
_Avoid_: Lobby, hub, plots, town

**House placement**:
An Owned item positioned in a House. It persists across sessions, unlike a Placement in a Style room.
_Avoid_: Save slot, decoration

## Project and release terms

**Live place**:
The published Roblox place identified by PlaceId `82272152451005` and Universe/GameId `10383493285`.
_Avoid_: Production build, cloud file

**Reference snapshot**:
A local extraction or document that records a past Studio state. It can explain history but cannot override the live place or current project direction.
_Avoid_: Source of truth, backup build

**Acceptance check**:
A repeatable device, multiplayer, or persistence test with a visible result that supports a release decision.
_Avoid_: Smoke test, spot check

**Public-beta gate**:
A required acceptance result that must pass before the game is opened to public-beta players.
_Avoid_: Nice-to-have, polish item
