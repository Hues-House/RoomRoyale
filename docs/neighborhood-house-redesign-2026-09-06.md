# Neighborhood and starter House redesign

Recommend eight detached cottages around a compact shared green, paired with a completely new furniture, decor and finish collection. Build one complete street-to-interior section first: public path, front garden, porch, working door, enclosed room, and purpose-made blockout pieces for the new collection. A smaller, well-made starter House should feel like something worth keeping before the player buys anything.

The user clarified during this task that all current items are placeholders. None of them is a production art commitment. Measurements below diagnose the existing experience; they do not nominate existing models for polish or retention. The redesign includes a full new collection of furniture, decor, small objects, rugs, lights, plants and textures.

This is a design and technical brief, not an implementation or a play-test report. The inspection took place September 6, 2026 Pacific time, September 7 UTC, on branch `codex/live-place-source-sync`, with source baseline `d7c8644`. No Studio objects, scripts, camera properties, play state, or saved place were changed. Nothing was published.

## Evidence and limits

The [structured Studio capture](evidence/neighborhood-house-2026-09-06.json) records selected map landmarks, the complete stored RoomTemplate and CartTemplate hierarchies, bounds for 96 ItemAssets, collision properties, and lighting. Its [capture notes](evidence/neighborhood-house-capture.md) explain how to repeat the read-only queries. Repeated instance paths in the JSON represent distinct siblings with duplicate names.

Three evidence classes matter here:

| Evidence | What it establishes | What it does not establish |
| --- | --- | --- |
| Edit inspection through Studio MCP | Actual stored geometry, hierarchy, sizes, flags and asset bounds in test PlaceId `86511797738570` | Runtime placement, profile behavior, loaded player avatars or multiplayer experience |
| Current viewport capture, without camera overrides | Paths across large grass expanses, isolated plaza dressing, a flat boutique front, a separate rectangular landmass behind it | The whole district or a runtime starter House; the view contains neither instantiated player houses nor runtime plaza floor |
| Verified repository source | Current construction rules and control flow, including defects described below | That these paths have successfully run in this task |

Studio remained in Edit mode. `Workspace.HousingDistrict`, `ServerStorage.HouseShellDecor`, and runtime player houses were absent. `Workspace.Plots` and `Workspace.HouseSamples` were empty. Do not start Play merely to obtain prettier evidence: it runs gameplay and can load real profiles.

There are two material baseline discrepancies. The stored Neighborhood is Version 4, while `NeighborhoodBootstrap.lua` generates Version 7 and replaces an older folder at startup. The stored RoomTemplate has a 60 by 52 floor; `RoomService` destroys that template at startup and creates a 52 by 44 room. The stored template cannot be used to certify the runtime House.

The inspected `game.GameId` is `10764620924`. `CONTEXT.md` describes the Live place universe as `10383493285` and says the Test place shares it. This inspection does not establish the actual relationship to production. Reconcile that identity before any future persistence test; do not infer isolation from the word Test.

## What creates the world now

| Current owner | Behavior and evidence anchor | Proposed responsibility |
| --- | --- | --- |
| [NeighborhoodBootstrap](../src/ServerScriptService/NeighborhoodBootstrap.lua), `EnsureAll` | Builds/replaces `Workspace.Neighborhood`; ground, water in v7, plaza dressing, boutique facade, 16-wide boulevard and eight branch walks | Build public geometry from one versioned Neighborhood layout, with no profile or player-house ownership |
| [LobbyBootstrap](../src/ServerScriptService/LobbyBootstrap.server.lua), `buildLobbyArea` and final task | Creates a separate `LobbyArea` floor, queue ring and purchase displays; calls Neighborhood `EnsureAll` | Keep purchase-display behavior; consume shared spawn, queue and boutique anchors. Public floor geometry has one builder |
| [RoomService](../src/ServerScriptService/RoomService.server.lua), `buildRoomTemplate` | Rebuilds the open-front competition room, including ceiling, three walls and invisible safety geometry | Own temporary Style rooms. Stop providing the persistent House template |
| [HouseShellBuilder](../src/ServerScriptService/HouseShellBuilder.lua), `GetShell` | Caches v13 cottage dressing in ServerStorage, sized around that competition room | Evolve into a complete House template builder with matching exterior, interior, openings, surfaces and collision |
| [HousingService](../src/ServerScriptService/HousingService.lua), `buildHouseRoom` | Clones RoomTemplate, strips named objects, grafts cottage shell, adds paint liners and light, assigns one of eight slots in HousingDistrict, populates saved items | Own session lot assignment, House lifecycle and authoritative House mutations; assemble a complete template without name-based surgery |
| [HousingBootstrap](../src/ServerScriptService/HousingBootstrap.server.lua) | Defers Housing initialization after requiring ProgressionService; house loading polls for a profile | Explicitly await profile readiness and template readiness. A deferred tick is not a dependency contract |
| [ProgressionService](../src/ServerScriptService/ProgressionService.lua), `SaveHousePlacement` | Owns profile data, item ownership, one placement per item and 30-placement limit | Continue profile authority; serialize versioned House-local state after spatial validation |
| [HousingClient](../src/StarterPlayer/StarterPlayerScripts/HousingClient.client.lua) | Polls own-house bounds every 0.5 seconds and relays move/cancel events | Derive local entry detection from replicated House geometry metadata; handle streaming removal |
| [StyleController](../src/StarterPlayer/StarterPlayerScripts/StyleController.client.lua) and [PlacementController](../src/StarterPlayer/StarterPlayerScripts/PlacementController.client.lua) | Unified Decorate panel and shared ghost/input pipeline; House mode uses Owned items and HousePlaceSave | Preserve shared interaction, but pass an explicit House or Style-room context to placement |
| Studio-owned non-script assets | ItemAssets, CartTemplate, old RoomTemplate, trees, terrain and map snapshots are outside the imported source boundary | Import assets selectively with provenance and hashes; leave archives and unrelated geometry outside the managed root |

`AGENTS.md` and `CONTEXT.md` still define the product. The March system maps contain stale implementation claims: current RoundManager uses per-player `RoundPhase` and cohorts, and StyleController already supports House decoration. Preserve that behavior. A House lasts across rounds; a Style room is discarded. A lot is an internal session location, not the player's permanent House identity.

## Concrete problems

### Spatial and visual composition

1. The district has circulation lines without convincing frontages. The inspected main path is 16 by 350, centered at Z 13; its source successor centers it at Z 15. Eight 62 by 8 walks reach X ±70 at rows Z 130, 40, -50 and -140. Housing assigns centers X ±90. Source geometry puts porch steps about 57 to 60 studs from the boulevard center, so branch walks extend beneath the porch and toward the facade instead of ending at a designed lot threshold.
2. Four rows spaced 90 studs apart leave large gaps between houses whose street-facing width is about 52. All houses on one side are allocated before the other side. Low population therefore exposes long, empty stretches and one-sided occupancy. Unoccupied slots have no permanent lot or cottage model in the current housing lifecycle.
3. The base is a 332 by 582 rectangular ground slab. The screenshot shows a second slab behind the boutique, with abrupt exposed edges. Large regular shapes, sparse clusters and no deliberate edge treatment make the world feel assembled from separate tests. Source v7 adds a collidable sea safety floor; it does not by itself fix frontage or shoreline composition.
4. The 114-wide boutique is a 1.2-thick wall. Its non-colliding 8 by 9 door sits in front of a continuous colliding wall. It advertises an entrance that the geometry does not provide. Purchase displays are built separately by LobbyBootstrap. Give the boutique either a real shallow interior or an unmistakable open storefront.
5. The source House has an 18-stud room height, approximately 35-stud roof ridge and 16-stud roof rise. Its fixed door panel is 11 wide and 13 tall. Against furniture such as the 6.22-wide TrackLoveseat and 2.64-high SlatDiningTable, the room reads as a hall wearing a cottage facade. The starter's 2,288-square-stud floor also asks too much of a small initial collection.
6. Exterior windows are glass and trim laid against solid facade/wall parts. Interior liners retain solid walls behind the side windows. These are decorative window symbols, not openings with reciprocal views. The front foundation strip also spans the door at low level; it is non-colliding, but visually cuts across the opening.
7. Most generated parts disable shadows. The stored Neighborhood has 417 BaseParts, 106 collidable parts, only 12 shadow-casting parts, no MeshParts, no prompts and no constraints. Lighting has ambient and outdoor ambient around RGB 70, diffuse scale 1 and two Sky instances. That supports a flat-lighting concern; it does not prove a particular lamp's runtime appearance. Enable deliberate structural and foliage shadows and test a small set of lights before changing global exposure.
8. Furniture proportions vary sharply. Stored `NightStand` is 6.70 tall versus `OakNightstand` at 2.16; legacy DiningTable spans 10.40 by 15.10 versus SlatDiningTable at 6.72 by 3.22. Some bounds include sets or unusual orientation, so inspect each candidate before rescaling it. Nine models lack PrimaryPart. The existing asset-normalization issue is still valid.

### Interaction and system defects

| Finding | Concrete consequence | Required change |
| --- | --- | --- |
| Shell `FrontDoorOpen` is anchored, non-colliding and has no door behavior | The user walks through a visually closed panel. The stored template's differently oriented door is not the runtime shell | Build one actual opening and a hinged visual leaf with authoritative open/closed state |
| HousingClient uses half-bounds 22 by 20 by 18; GetHouseInfo reports 40 by 30 by 18; source floor is 52 by 44 | The Decorate button can disappear near usable room edges; different consumers disagree on what the House is | Replicate one geometry descriptor with House pivot, room volumes and surface IDs |
| PlacementController searches directly under Workspace for House and plot, while HousingService parents both inside HousingDistrict/HouseRoom | House overlap and wall/ceiling ownership checks miss the House; a missing plot returns unrestricted floor placement | Resolve the explicit House model once, and reject placement while required geometry is absent |
| Floor validation checks one point; overlap compares world-axis deltas; house built-ins are ignored | Large or rotated pieces can cross walls, entrances and lot boundaries. A green ghost is not reliable evidence of a legal placement | Validate complete footprints against room polygons, obstacles and reserved circulation on both preview and server paths |
| HousePlaceSave calls SaveHousePlacement before checking asset existence and its loose 60-stud center-distance bound | Profile data can accept a placement that the world then rejects. It lacks CFrame type/finite checks, surface and doorway validation | Validate the request fully before changing either profile state or visible items; send an explicit result |
| Placement CFrames are saved and restored in world space; slot allocation depends on join order | Rejoining on another side or row restores furniture at the prior world location | Store House-local transforms and migrate old placements before moving lots |
| Move destroys the item and removes its saved placement before opening the ghost | Cancel, death or interruption leaves the arrangement changed and may lose per-placement appearance | Keep the original placement until a validated move commits; cancel leaves it intact |
| House item appearance handlers change instances only; restore uses source assets | Tint/material changes on furniture do not survive reload, although wall/floor paint does | Persist allowed appearance channels per placement |
| ConfirmPlacement exits after firing, without server acknowledgment | A rejected item looks like a completed action | Remain pending until accepted or show a useful rejection and restore the preview |
| Eight slots, with no overflow house; RoundManager's six-player cap is per cohort | The round cap does not establish an eight-player server limit. A ninth connected player can lack a House | Verify actual server capacity, then provide enough slots or an explicit overflow neighborhood before rollout |

These are code-path findings, not newly reproduced runtime bugs. Keep their acceptance checks in the implementation plan.

## Scale and proportion guide

Use studs as the authored unit. Roblox's standard length conversion is 1 stud = 0.28 m, but gameplay clearance must be checked against avatars and the third-person camera rather than copied from real house plans. The values below are proposed project targets, not Roblox requirements. [Roblox units](https://create.roblox.com/docs/physics/units)

Choose a nominal 5.5-stud avatar for the first blockout and test small, nominal and tall/wide supported avatars. Measure the actual allowed avatar envelope before freezing dimensions. Use 1-stud building layout increments, 0.5-stud furniture translation and an optional 0.25-stud decor mode. Preserve 90-degree default rotation initially; test 15-degree fine rotation once rotated-footprint validation works. Snap in House-local coordinates.

| Element | Initial target in studs | Acceptance intent |
| --- | --- | --- |
| Starter House | 34 wide by 28 deep exterior; 32 by 26 clear interior | About 832 square studs, 64% less floor than the current source room; leave useful blank walls |
| Height and roof | 11.5 clear ceiling; eave about 12.5; ridge about 18.5 above floor | Camera clears furniture without a cavernous room; roof stays subordinate to the House |
| Walls and trim | 0.75 to 1 structural thickness; 0.1 to 0.2 paint liner; trim relief 0.15 to 0.35 | Visible depth at openings, no coplanar paint layers, no tiny snagging collision |
| Front door | 5 clear width by 8 clear height; leaf about 0.25 thick, jambs outside clear aperture | Tall/wide avatar can enter with door fully open; reserve swing plus 0.5 margin |
| Interior connection | 6-wide opening between main room and nook; avoid narrow halls in starter | Two players can pass through the opening without furniture blocking it |
| Windows | 4 to 6 wide, 4.5 to 5.5 high; sill 3 to 3.5 above floor | Real aperture with inward and outward views; useful wall space below/beside it |
| Porch | 12 wide by 7 deep; clear standing area at least 6 by 6 | Door swing, a guest and one small prop fit together |
| Threshold and steps | Floor/porch height difference at most 0.1; approach risers 0.3 to 0.5, treads at least 1.5 | Walk into the House without jumping; use a simple ramp collider if steps snag |
| Lot | 44 frontage by 46 deep; House centered with 5 side yards; rear yard about 9 | Front garden, porch and sidewalk have separate, readable edges |
| Sidewalk and lot path | 8 public sidewalk; 6 clear lot approach; decorative planting stays outside | Comfortable two-player movement and a clear route from every frontage |
| Shared neighborhood lane | 16 clear, widened to about 20 at social corners; flush accessible crossings | Reads as a small residential lane rather than a highway or gold-bordered corridor |
| Furnished circulation | 4 clear around primary furniture; 6 on entrance-to-room route; 8 by 8 social turning space | Two visitors can enter, turn and leave a furnished House |
| Living zone | Roughly 18 by 20 to 24 | Fits sofa, chair, rug, table and circulation without requiring a dozen purchases |
| Sleeping nook | Roughly 12 by 14, connected through an open or wide partition | Bed with 3 to 4 clear beside/at foot; no mandatory bathroom simulation |
| Kitchen/display corner | About 10 to 14 wide by 8 to 10 deep | A short counter or dining set can establish a second activity without fixed clutter |
| Seating | Sofa 6 to 8.5 wide, 3 to 4 deep; seat height 1.7 to 2 | Build new reference seating to these dimensions and test avatar seat alignment |
| Tables | Coffee table 3 to 5 wide, 1.5 to 2 high; dining table 5 to 7 by 3 to 4, 2.6 to 3 high | Paired chair/table heights feel usable; a coffee table does not dwarf its sofa |
| Bed/storage | Bed footprint around 6 by 8; nightstand 1.8 to 2.5 high; tall storage 6 to 8 high | Author related items together so their dimensions work as a family |
| Cart and driving clearance | Stored cart visual bounds about 3.37 wide by 5.83 long by 4.79 high; reserve 5 by 8 including rider, 8-wide single passage, 14 to 16 for passing, 14 to 16 turning pad | Measure the moving assembly and rider swept path before approving a driveable route |

Carts remain part of Shop. The recommended neighborhood is walkable and has no ram gameplay or requirement to fit a cart through the front door. A future delivery cart can park at a frontage bay. If neighborhood driving becomes a feature, test its turning and collision separately instead of enlarging every House to accommodate it.

The starter zoning should be readable without floor labels: living space to one side of the entry, a short kitchen/display wall at the rear, and a sleeping nook behind a partial partition. Start with new movable free essentials using the same Owned-item system. Keep the House attractive when empty through wood tone, daylight, proportions and trim. Earned or purchased pieces add identity; basic habitability is not an upgrade.

## Three directions

These are alternatives for the same game, not escalating quality tiers. Scores are design judgments on a 1-to-5 scale where 5 is best. Implementation ease includes asset and placement complexity.

| Direction | Layout and starter House | Social visibility | Sense of ownership | Ease | Main tradeoff |
| --- | --- | --- | --- | --- | --- |
| A. Porch street | Two short facing rows, planted bends, small front gardens; narrow 30 by 30 bungalow | 3 | 5 | 5 | Closest to current code, but empty slots and long sightlines still need careful handling |
| B. Pocket green, recommended | Eight detached cottages facing a shared green and a continuous small lane; 34 by 28 cottage with a usable porch | 5 | 5 | 4 | More deliberate corner/site work; fixed capacity must be reconciled with server population |
| C. Courtyard mews | Two groups of four attached homes around paved courts; 24 by 34 starter with a deep living room | 5 | 3 | 3 | Efficient land use and strong enclosure, but shared walls complicate expansion, camera occlusion and exterior ownership |

A is the fastest route to a conventional residential street. C offers the strongest urban enclosure, but its shared facades make individual upgrades harder and its deeper rooms risk dark corners. Choose B because the green gives even one player a complete place to arrive, while detached Houses remain legible and individually editable. It retains playful shopping energy at the boutique and makes the residential area calmer.

### Recommended composition

Use the following as a dimensioned blockout, translated through one Neighborhood origin so it does not silently collide with the Shop and Style-room islands. Local X/Z plan coordinates, floor datum Y=0:

| Component | Proposed placement |
| --- | --- |
| Shared green | 68 by 68, centered at 0,0; trees frame corners and leave views to porches |
| Lane and sidewalk | 16-wide square loop immediately outside the green, then an 8-wide outer sidewalk; soften the visual corners while keeping simple collision |
| Eight House centers | X ±24, Z ±82, and X ±82, Z ±24; fronts face the green |
| Lot envelope | 44 by 46 around each House, rotated with the House. No intersecting lot rectangles; the two lots on each side have a 4-stud gap |
| Porch and approach | Porch projects 7 from the 28-deep House; its outer edge is about 61 from center, meeting the sidewalk edge at 58 through a short garden path |
| Arrival | Spawn on the north edge of the green, near the lane. Queue occupies a distinct inset pad with an opt-in entrance, outside through traffic |
| Boutique | A shallow, real building in one corner outside the loop, connected by a short crossing; reserve the exact footprint after checking round-island bounds |

This arrangement bounds the eight lots within approximately 210 by 210 studs before boutique and landscape margins. It is a compact plan, not a promise that the old 332 by 582 slab can be replaced without moving other systems. See the [layout sketch](evidence/neighborhood-house-directions.svg).

Every slot keeps a coherent cottage exterior and garden when unoccupied. Show a quiet available nameplate, with no fabricated resident activity. Assign occupied Houses around the green instead of filling one distant side first. Empty interiors need no saved furniture. Individual exterior color, porch plants and a physical nameplate make ownership readable at eye level; avoid labels floating over rooflines.

Use warm off-white plaster, muted sage or clay doors, mid-tone wood floors and a restrained roof palette. Keep structural edges crisp with slight bevels on authored pieces. Use fewer, larger foliage masses with believable trunks and shadow, and flower beds with a defined boundary. Reserve emissive materials for small lamps. The current neon flowers and unshaded trim should not set the material language.

## Technical design

### One spatial definition

Introduce one House definition for footprint, floor datum, surfaces, door openings, entry volumes and reserved circulation. One Neighborhood definition owns lot transforms and public anchors. Generate detection volumes, walls and placement constraints from these definitions; do not repeat room width in client constants.

Proposed runtime structure, with names internal to the implementation:

```text
Workspace
  Neighborhood
    PublicGeometry
    Anchors: Spawn, QueueEntry, BoutiqueEntry
    Lots
      Lot_01
        LotBounds
        House
          Structure
          Surfaces
          Doors
          Volumes
          ExteriorDetails
          PlacedItems
```

Each House has `HouseId`, `OwnerUserId`, `LotId`, `TemplateId` and `TemplateVersion`. A server registry resolves HouseId to its current model and transform. Clients get a replicated descriptor and resolve by identity rather than a string search at Workspace root. Update HousingClient, StyleController, PlacementController and server handlers together when adopting this hierarchy. Keep the existing runtime names until those callers migrate.

Build templates with no player connections, then bind behavior after cloning. House construction must not wait on or strip a Style-room template. A deterministic generator may cache complete templates by definition version. Its output is disposable; source definitions remain canonical. Use a local seeded `Random` object for variation instead of changing global random state.

### Functional doors and transitions

Use a real 5 by 8 clear opening through structure and paint liners. The door leaf is a Model whose pivot sits on the jamb hinge axis. Panels and handle move with that leaf; frame, threshold and prompt anchor stay fixed. A facade panel placed in front of an intact wall is not an entrance.

The server owns `Closed -> Opening -> Open -> Closing`, the target angle and transition revision. Start with a scripted anchored door, about 95 degrees of travel in 0.35 seconds. Server movement is the reference behavior; add client interpolation only if multiplayer measurements justify it. Avoid free physics hinges for this slice because decorative doors need predictable interaction more than physical simulation.

Use a simple doorway blocker while fully closed and non-colliding visual leaf parts while moving. Disable the blocker when opening begins. On closing, check the threshold and swing zone for occupants, defer closure while occupied, and enable the blocker only after the closed pose is reached and the aperture is clear. Recheck while closing and reopen if someone enters. Document that this first implementation allows passage during the animation rather than pushing avatars with the leaf.

A shared custom ProximityPrompt shows Open or Close for keyboard, touch and controller. PromptController renders it; one server door controller handles behavior. Suppress competing paint/move prompts when the player intends to enter. Validate House/door identity, actual player proximity, request rate and state on the server. Client-editable prompt properties do not establish authority. [Roblox client/server boundary guidance](https://create.roblox.com/docs/scripting/security/client-server-boundary)

Visitors may operate unlocked doors and look around. Only the owner may decorate. Start with public visits and no paid door locks. Door state is session state, not profile data. Keep one continuous world space from lane to room, without teleporting to a distant duplicate interior. Test the actual doorway with camera rotation, two players moving in opposite directions, respawn and streaming re-entry.

### Placement, inventory and persistence

Use an explicit placement context containing HouseId, template version, origin, allowed surface IDs and placement limits. The server derives the owner's House rather than trusting a requested owner. Keep temporary Style-room placements under RoomService and persistent mutations under HousingService. Share pure geometric validation where useful, while preserving separate inventories and phase rules.

On a House request, validate payload types, finite transforms, length limits, profile readiness, per-player phase, ownership, asset availability, allowed appearance values, full rotated footprint, support surface, player distance, overlap, room volume and door/circulation exclusion. Resolve surfaces by stable IDs such as `living.floor` and `entry.wall.left`. Decorative knobs, foliage, glass and invisible helpers must not become accidental placement surfaces. Explicit query filtering is separate from physical collision.

Validate before profile mutation. Prepare the clone, commit the accepted record and world change through one server path, then acknowledge with request ID and placement ID. Retrying the same request returns the same result. A move edits the same placement ID and keeps the old transform until accepted. Unknown assets or failed restores go to an owned, unplaced recovery list with a visible message; they are not silently lost.

The current one-active-placement-per-item rule cannot support two matching dining chairs or repeated small objects. Before the new collection ships, distinguish catalog item IDs from owned instances or owned quantities, and make placement consume one available owned copy. Keep the current limit only for an initial compatibility fixture; choose the production placement budget from furnished-room and performance measurements. Small objects should not make a House feel full after a handful of furniture pieces. Starter grants must be idempotent and use the same inventory and placement path. Do not turn the round collection into permanent inventory.

Proposed persisted House data:

```text
houseSchemaVersion
templateId, templateVersion
placements[placementId]
  itemId, ownedInstanceId or quantity reservation, assetVersion
  localPosition, localRotation
  surfaceId
  supportPlacementId when resting on another piece
  appearance channels
surfaces[surfaceId]
  color, allowed material/finish
```

`worldCFrame = houseOrigin * localCFrame`. Store the inverse transform when accepting placement. LotId is a session assignment and is not required to reproduce the House on another lot. Save appearance channels independently of MeshPart geometry and preserve semantic surface IDs across compatible template revisions.

Migrate existing world-space records before reallocating Houses. Old data does not store the original lot or template version. Compare a placement group against the known legacy eight transforms and bounds; convert only when one original layout is unambiguous. Keep a copy of the original record and migration version. Ambiguous, malformed or out-of-bounds records return to owned inventory through a recovery flow. Never guess by using the newly assigned lot, discard purchases, or force old furniture into the smaller room. Re-running migration must produce no further changes.

ProgressionService and its existing ProfileService session lock remain the profile owners. A failed profile load must leave a clear loading/retry state and prohibit edits to an empty fallback House. Queue transitions cancel pending previews, not accepted placements. Reconcile the GameId discrepancy and use an explicitly isolated test-data namespace or offline profile fixtures for the first persistence tests.

### Multiplayer and streaming

Keep House shells and accepted furniture server-created so everyone sees the same place. The owner leaving releases the session lot and removes personal state only after profile lifecycle handling; the unoccupied shell remains. Entering a round leaves the House visible to visitors. Visiting another House never grants placement, paint or pickup authority.

Streaming is enabled in the inspected place. Start with the static shell and doorway as an Atomic model; handle PlacedItems as individually complete models and use a ready descriptor before enabling decoration. Atomic models stream their existing descendants together, but later-added descendants need separate handling. Do not make the entire Neighborhood permanently resident just to hide missing-instance bugs. [Model streaming modes](https://create.roblox.com/docs/reference/engine/enums/ModelStreamingMode), [streaming techniques](https://create.roblox.com/docs/workspace/streaming/techniques)

A streamed-out House closes its local editor and removes stale prompt/ghost connections. Streaming back in reads current state rather than replaying old door events. Furniture revisions and request acknowledgments let the owner distinguish a pending action from accepted state. Validate with at least two clients and then the intended server population; the six-player round cohort limit is not a housing capacity guarantee.

## A completely new item and finish collection

Build the House and its contents as one art project. The current library is a measurement reference and migration input, not a collection to normalize into production. Replace the whole placeholder catalog through explicit content releases. Keep existing IDs and entitlement records traceable until each has a deliberate replacement or recovery outcome.

The shared visual rules are rounded but readable silhouettes, modest bevels, tactile materials, clear contact with floors and tables, and restrained texture contrast. Choose one neutral base family first, then playful color and retro accents that mix at the same scale. A player should be able to combine pieces across families without one looking like a dollhouse object beside another.

Suggested collection scope for planning, subject to the first art review:

| Category | Proposed first full collection | Authoring requirements |
| --- | --- | --- |
| Furniture | About 28 base designs spanning sofas, chairs, stools, beds, dining/coffee/side tables, desks, storage, shelves, kitchen and bath pieces | Coordinated seats, table heights, bed/nightstand heights, foot clearances and intentional material channels |
| Lighting | About 10 table, floor, pendant, ceiling and wall designs | Fixture geometry plus controlled light behavior; explicit mounting, cord policy and ceiling clearance |
| Plants | About 8 tabletop, floor, hanging and porch designs | Designed foliage silhouettes; reusable pots; low collision cost and readable scale |
| Wall decor | About 12 art, mirror, clock, shelf and textile designs | Back contact pivot, consistent wall offset, authored frame/art treatment and replaceable material channels |
| Small objects | About 18 books, trays, bowls, mugs, vases, candles, toys and personal objects | Table/shelf support, stable base, useful grouping; individual pieces and sets have explicit footprints |
| Rugs and soft goods | About 10 rug/runner forms and patterns, with cushions/throws developed alongside seating | Low floor profile, consistent pattern scale, curated layering and no hundreds-of-Parts fibers |
| Surface finishes | About 36 coordinated swatches across paint/plaster, wood, tile/stone, fabric, rug patterns and exterior finishes | Authored tileable textures where needed, repeat scale in studs, restrained roughness/normal detail and a shared palette |

These roughly 86 placeable designs and 36 finish swatches are a proposed commissioning scope, not completed content or a fixed release promise. A colorway is not automatically a new mesh or new purchase. Track geometry designs, finish variants and store entries separately. Include public-world assets, especially trees, planters, benches, boutique displays and the cart's visual skin, in the same style guide. Cart physics can remain independently tested while its presentation changes.

Commission in complete room sets. The first authored set should contain a sofa, chair, coffee table, bed, nightstand, storage piece, rug, floor lamp, framed art, plant and a small-object group, plus a restrained wall/floor/fabric finish palette. Before expanding, place the set in the proposed House and compare an empty room, a free starter arrangement and a personalized arrangement. Free basics need the same quality as premium pieces; premium purchases buy distinct style and choice.

Small objects change the placement model. Add explicit support planes on tables and shelves, a parent/support placement ID and a relative transform for supported decor. Validate the support footprint and carry its children when moving it. Define pickup behavior for an occupied shelf or table before shipping stacking. Allow rugs beneath furniture and wall art above it through placement layers, rather than treating every bounds intersection as a blocker. Keep walkable routes and door swing exclusions independent of those decorative overlap permissions.

For finishes, preserve paintable channels such as upholstery, wood, metal and ceramic; do not flatten a multi-material model by tinting every part identically. A texture needs a source image, dimensions, intended repeat scale, color space/map role, Roblox asset reference and preview on the actual House surface. Build a small finish sampler alongside the first room, then review it in daylight and lamp light. Patterns should remain readable from normal camera distance and avoid heavy visual noise when several surfaces use them together.

Every new catalog entry needs ItemId, display name, category, theme tags, size class, placement layer/support rules, available finishes, thumbnail framing, shop representation, owned-copy policy and reward/purchase source. Shopping pickups may use a compact display representation, while the placed item uses the full furniture model; both must point to the same catalog identity. Review theme coverage across Shop, Style and Judge so the new collection still supports the competition.

Replace placeholders with a mapping table from legacy item ID to new item/owned-copy grant or an explicit recovery decision. Preserve purchased and earned ownership, handle unavailable replacements visibly, and never reinterpret one old chair as an arbitrary new paid item without a reviewed mapping. Saved placements require both the House schema migration and content replacement migration. Larger or differently shaped replacements must be revalidated; return them to owned inventory if they no longer fit.

## Primitives, authored assets and Rojo

| Build well with Parts, code and simple materials | Author as MeshParts or in Blender when polishing |
| --- | --- |
| Lot boundaries, paths, curb ramps, collision, room shells, segmented wall openings, thresholds and paint surfaces | Beveled furniture, upholstered forms, readable seams and rounded silhouettes |
| A functioning door's pivot, leaf blockout, state, collision and prompts | Final door panel bevels, handle and hinges, still attached to the same moving leaf |
| Modular roof massing, porch decks, columns, simple trim and planter boxes | Roof edges, gutters, curved porch details and select repeated architectural accents |
| Flat rugs, simple shelves, picture frames and broad color/material variation | Drapery, shaped ceramics, wicker, complex plants and trees with designed silhouettes |
| Low-count temporary street furniture and site blockouts | Hero public bench, lantern and tree kits reused throughout the district |

Do not build upholstery or foliage out of hundreds of tiny Parts to avoid asset authoring. The current FauxFurRug contains 149 BaseParts, CeilingFan 249 and Guitar 198, while several useful furniture assets are single MeshParts. These are cost warning signs, not measured frame-time results. A MeshPart is also not automatically efficient: collision, texture count, transparency, triangles and draw behavior still matter.

Keep structural collision simple and separate from decorative detail. Use a few proxy boxes for furniture where appropriate. A doorway must remain open in collision even if its visual wall becomes a mesh. PreciseConvexDecomposition has the highest collision cost and still does not guarantee an exact visual match. [Roblox collision guidance](https://create.roblox.com/docs/workspace/collisions)

### Source asset contract

Future repository locations, to create during implementation rather than as empty runtime folders now:

```text
src/ReplicatedStorage/Housing/HouseDefinitions.lua
src/ReplicatedStorage/Housing/PlacementGeometry.lua
src/ServerScriptService/Housing/HouseTemplateBuilder.lua
src/ServerScriptService/Housing/NeighborhoodLayout.lua
src/ServerStorage/HousingAssets/<asset>.rbxmx
assets/housing/source/<asset>.blend
assets/housing/exports/<asset>.fbx
assets/housing/manifest.json
```

Each authored asset needs a stable catalog ID and version, source file/hash, export hash, Roblox mesh/texture IDs, creator or license provenance, expected bounds in studs, pivot convention, material channels, collision policy, placement surface and preview orientation. Floor assets use a bottom contact pivot; wall assets use a back contact plane; door assets use the hinge axis. Import a calibration cube and one known furniture piece to verify scale and axes instead of trusting exporter defaults. [Roblox Blender setup](https://create.roblox.com/docs/art/blender)

Use text definitions and generators for repeatable geometry, and `.rbxmx` for reviewable authored model assemblies with asset references. Rojo supports model files and `.model.json`; binary art sources live outside `src/` and may use Git LFS once configured. Do not map `.blend` or `.fbx` directly as Roblox instances. [Rojo sync details](https://rojo.space/docs/v7/sync-details/)

Import newly authored assets through a versioned workflow with expected bounds, hierarchy, collision and visual evidence. Treat placeholder replacement as a catalog migration, not an instruction to polish the existing meshes. Rojo does not upload mesh content. Its documented live-sync limitations include `MeshPart.MeshId`, so prove each mesh change with a fresh build or controlled reimport before assuming live sync applied it. Changing a manifest string alone is insufficient. [Rojo sync limitations](https://rojo.space/docs/v7/sync-details/)

The current Rojo project maps service folders with `$path` but no explicit unknown-instance policy. Before any future live connection, set and verify preservation at mixed-ownership service roots and strict replacement only inside the new managed Housing asset root. Rojo's default unknown-instance behavior differs when `$path` is present. `servePlaceIds` restricts the target; it does not preserve untracked models. [Rojo project format](https://rojo.space/docs/v7/project-format/)

Make the ownership handoff one-way: capture a selected Studio asset, normalize and verify its repository representation, compare the built instance, then declare that managed asset repository-owned. Do not keep editing both copies. Runtime-generated Neighborhood and House instances are outputs and should not also be imported as independently edited source assets. Keep NewLoft archives excluded and all behavior in Luau files, with no embedded scripts in furniture models.

## Staged implementation and acceptance

Each stage ends with recorded evidence and a local commit. A build alone cannot establish that doors, camera or multiplayer work. Use a disposable built place or an explicitly approved test session for runtime checks, with isolated profile fixtures until the data identity is resolved.

| Stage | Deliverable | Acceptance and evidence |
| --- | --- | --- |
| 0. This brief | Measured evidence, alternatives, ownership and scale decisions | Documentation links and JSON validate; source baseline and Rojo build remain unchanged; Studio still Edit |
| 1. One inhabited frontage | Dedicated House definition and builder, one 34 by 28 cottage, small lot/path section, real windows, door, six purpose-made blockout pieces for the new collection; isolated from profile writes and existing district | Two avatar sizes plus wide avatar walk both directions without jumping; two clients agree on door state; occupied closure cannot trap a player; camera can enter and turn; new reference pieces fit with circulation. Capture eye-level approach, threshold, seated-height interior and top-down dimension views |
| 2. Safe decoration and persistence | Explicit House context, authoritative geometry checks, server acknowledgment, transactional move, local-coordinate schema and old-data recovery | Wrong owner, wrong surface, malformed CFrame, nonfinite values, out-of-room footprint, blocked entry and stale request are rejected before mutation. Place/rotate/paint, cancel move, die mid-preview, leave/rejoin on opposite lot and repeat migration with no lost item or layout drift |
| 3. Compact neighborhood | Eight coherent lots, public green/lane, real boutique frontage, queue/spawn anchors, empty-slot state, capacity handling | At low population the place still feels complete; nearest House visible from arrival; target less than 15 seconds unhurried travel to any porch from spawn, measured at actual walking speed; no overlap with round islands; queue never catches through traffic; eight and overflow join/leave cases handled |
| 4a. New collection proof | Author the first complete room set and finish sampler; implement owned copies, support surfaces and rug/decor layering | New assets fit together and furnish the starter with clear circulation; a table and its small objects move together; two matching chairs consume two owned copies; lamps visibly affect the room; materials hold up at normal camera distance |
| 4b. Full content production | Build furniture, lighting, plants, wall decor, small objects, rugs and finish families from the approved set; replace placeholders through the catalog mapping | Every production item has stable pivot, approved bounds, appearance channels, theme tags, collision and shop/placement representations. Verify replacement ownership and restored arrangements; compare mobile frame time, memory and draw metrics against stage 3; review complete rooms rather than isolated asset thumbnails |
| 5. Integration gates | Housing plus concurrent Shop/Style/Judge activity and real persistence in the verified test environment | Two clients visit and decorate while another cohort plays; accepted furniture stays visible across rounds; streaming out/in restores interaction; owner departure/reassignment is safe; touch and controller can enter, decorate, cancel and exit; regression checks preserve existing round inventory and judging |

Initial performance targets are hypotheses to measure: keep the first shell below 150 BaseParts before furniture, avoid per-frame loops per House, and share door handling centrally. Profile an eight-House scene at the 30-placement limit with representative expensive items and then at actual server capacity. Aim for stable 30 fps on the chosen lower-end mobile target and 60 fps on the desktop reference; record devices, settings and percentile frame times. Adjust art budgets from those results rather than claiming that a part-count limit guarantees performance.

Stages 2 and 5 should include the existing [profile recovery](../.scratch/issues/P1-profile-load-recovery.md), [multiplayer evidence](../.scratch/issues/P1-multiplayer-round-evidence.md) and [new-player flow](../.scratch/issues/P1-zero-data-ftue.md) acceptance work. Carry the [asset normalization issue's](../.scratch/issues/P1-item-asset-normalization.md) pivot, bounds and collision acceptance criteria into the new collection, rather than spending the art budget normalizing disposable placeholders. House item migration must land before a new layout can touch existing profiles.

For future source changes, preserve the September import manifest as historical evidence. Intentional edits will no longer match it. Record the reviewed changes separately and continue build-versus-current-source verification; do not rewrite the captured import merely to turn a baseline comparison green.

## First implementation slice

Build one complete cottage frontage in a disposable Rojo-built fixture: a 34 by 28 House with an 11.5 clear ceiling, a 5 by 8 working door, real window openings, a 12 by 7 porch, a short garden path and six new blockout pieces: sofa, chair, coffee table, bed, rug and lamp. Prove entry, camera, scale and two-client door behavior before replacing the district, then use that fixture to approve the first fully authored room set and finishes. Keep profile-backed decoration out of the first fixture; repair placement authority and local-coordinate persistence in the next stage before migrating players.
