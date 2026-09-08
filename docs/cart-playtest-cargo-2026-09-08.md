# Shelf furniture, cart stacking, and checkout

The old cargo renderer made a generic miniature from `itemId`. A designer chair became a three-part block chair, and each item used a fixed tier height. The shelf model never entered the cargo presentation path. The same approximation appeared in checkout and the room preview.

`ItemPresentation.lua` now captures the actual stock display once per stock variant. The replicated template preserves its parts, designer mesh and texture IDs, colors, materials, and original transparency. It removes prompts, scripts, UI, joints, constraints, and other gameplay objects before parenting the template. Cosmetic parts are anchored and cannot collide, touch, or answer queries. Each receipt and cargo record carries its collection GUID, template ID, and variant ID. The exported collection preserves those fields together with the item name, color, and rarity.

Cart furniture uses 86% of the shelf dimensions. The room preview uses the original shelf dimensions. [Roblox Model scaling](https://create.roblox.com/docs/reference/engine/classes/Model#ScaleTo) keeps the geometry proportional. Templates store stock-local part positions and set the local pivot explicitly on each clone because [Model.WorldPivot does not replicate](https://create.roblox.com/docs/reference/engine/classes/Model#WorldPivot).

The stack measures each model's bounds and places broad items first. Smaller pieces use available deck space or sit above furniture that already occupies it. Vertical separation follows actual furniture height, with a 0.08-stud gap. The rear edge stays ahead of the runner. Cosmetic lean rotates the pile together. A local `CargoVisualHeight` attribute lets the camera account for larger loads. Capacity remains 100 space, with the existing minimum eight-space cost.

Checkout detaches the actual rendered cargo models and animates those same instances into the tube. It handles both event orderings, whether the collection records disappear before or after the deposit receipt. Furniture keeps its full cargo scale for the first 70% of suction and compresses at the opening. Checkout uses the zone's authored `TubeDestination`. The room delivery clones the same variant at full shelf size and packs it within a 42-by-30-stud area, adding height if a very large repeated collection fills the floor.

Special stock can opt into `finiteStock = 1` and `requireLanding = true`. Its remaining quantity resets when the next timed round starts; ordinary stock still replenishes after six seconds. The server rejects pickups more than four vertical studs from the cart. Landing-required stock also needs a collidable floor within 4.5 studs below the cart at the reward platform's elevation. Ejected carts cannot grab or check out.

The trusted `ServerStorage.MoveCartLabTo` binding moves a mounted cart during free shopping and preserves the collection. It rejects timed rounds and ejected carts. The store uses it for travel between the market and practice park.

`ServerStorage.StartCartLabFreeShopping` returns a completed prototype round to free shopping. It clears the completed collection and delivery visuals, replenishes stock, restores mounted market carts, and removes the timed-phase attributes. It rejects active timed rounds. Calling it in existing free shopping preserves the current cargo. The practice button can invoke it after the collection preview, then call `MoveCartLabTo` once it returns.

## Verification

Source compilation passes for the cargo renderer, shared presentation module, host, session, Props, and acceptance module. `tests/ride/ShoppingSession.spec.lua` passes the existing capacity, deadline, repeated deposit, and discard cases plus two same-item-ID variants preserving their distinct collection GUIDs and template IDs through atomic banking and a copied export.

`tests/superstore/CargoAcceptance.lua` runs against actual Roblox instances and the production cargo renderer. `runTemplates()` compares every replicated template to its current shelf display. Run it before collecting stock. `runClient(Cargo, player)` creates an isolated legal load from the installed shelf templates, checks exact parts, mesh IDs, finishes, scale, measured non-overlap, upward stack height, same-instance suction for both replication orderings, and full-size delivery. It cleans up its renderer and fixture. Studio results are recorded by the integration task separately; compilation alone does not establish visual acceptance.

Device performance and a subjective judgment of the larger pile while driving still need playtesting. This is the standalone shopping prototype. The production furniture catalog and decorating placement pipeline remain separate integrations.

The fresh integration Studio passed the real renderer fixture with four items using all 100 space. Their measured pile height was 7.261 studs. Exact parts, mesh IDs, finishes, both deposit replication orderings, full-size delivery, and non-overlap passed. Two actual `Chair` pickups from different stock bays preserved distinct GUIDs and template/variant IDs through checkout export. A limited chair rejected the below-platform grab, accepted the on-platform grab, stayed claimed past ordinary replenishment, and reset to one at the next round. [Recorded engine evidence](evidence/cart-cargo-playtest-2026-09-08.json) identifies the staged positions and the content revision.

The later content pass makes the limited finds visually distinct. The right trail offers an `OrbitLamp`, a luminous circular halo above a ceramic plinth. The left trail offers a lilac finish of the bentwood chair. Ordinary lamp templates are unchanged. This content addition requires the final fresh-build template check and visual review.
