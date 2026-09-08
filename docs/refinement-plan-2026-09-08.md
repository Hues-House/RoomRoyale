# Room Royale refinement plan

Agreed direction from the September 7-8 playtest and design discussion. The user accepted the recommendations on round judging, progression pacing, furniture quantities, and earned artwork and rug designs. Milestone 1 now has a local implementation candidate; the [milestone 1 report](cart-refinement-m1-2026-09-08.md) distinguishes completed desktop/engine checks from remaining acceptance. Milestones 2-5 remain planned work.

The [Hillside v4 report](playtest-iteration-v4-2026-09-08.md) describes the tested prototype. This plan supersedes its independent camera steering and jump sound direction. It also supersedes the older permanent-inventory and automatic rarity-scoring rules where those conflict with the decisions here.

## A round and a neighborhood both reward play

A round must be fun and rewarding on its own. A theme sparks an idea, shopping introduces choices and improvisation, styling transforms a room, and the tour lets players discover and appreciate other designs. Results offer both **Play again** and **Back to neighborhood**. Returning home is an available payoff between rounds.

Long-term progression starts with a small empty house and no owned ride. Other players' homes and rideables show what can be earned. Players complete rounds, buy furniture, decorate their homes, and save for rides. Skill improves through shopping, decorating, and seeing how other players interpret themes.

The first implementation includes one skateboard. Strollers, scooters, and bikes are later ride choices supported by the same ownership and equip flow. The neighborhood park gives those purchases a visible use. No exact order or price ladder for the later rides was agreed.

## The agreed rules

| Area | Decision |
| --- | --- |
| Cart movement | Preserve the v4 jumps, airborne dive, grip, and recognizable stacked furniture that the user enjoyed. |
| Steering | Movement follows camera-relative direction. WASD, the left controller stick, or the touch thumbstick provides movement. Mouse movement, the right controller stick, or right-side touch drag aims the camera. Holding forward while turning the camera turns the cart. Looking while stopped does not accelerate. |
| Jump and drift | Camera heading corrections must not count as deliberate drift input. Preserve reliable charged jumps while turning the view. |
| Cart load | Show an animated capacity meter, the next item's space requirement, and clear nearly-full and full states. Separate current cargo from the delivered collection. |
| Weight | Make acceleration slower and braking distance longer with a heavy cart. Use loaded poses and settling animation. Preserve enjoyable jump height and responsive steering. Exact coefficients require playtesting. |
| Sound | Remove the spring boing from jump. Preserve separate control of other sound cues. |
| Judging | Players judge theme interpretation and the finished room. Automatic checks help explain the theme and recognize participation. Item rarity contributes no automatic winning points. |
| Competition inventory | Use that round's collected pieces and shared basic decorating tools. Permanent physical furniture is for houses. Owned neighborhood rides do not replace the round's shared shopping carts. |
| Permanent designs | Earn artwork and rug designs permanently. During Style, apply a design to a compatible painting or rug collected in that round. In a house, apply the design to compatible furniture the player owns. A design can be reused across those pieces. |
| Rare designs | Reward recognizable accomplishments. Initial examples are a first-win print, artwork for wins across several themes, and a rug for completing a difficult shopping route and checking out its special find. Exact thresholds and art are still to be tuned. |
| Discovery | Inspect a piece during a room tour or house visit to see its name and how the design was earned. Attractive designs may influence player votes; the agreed restriction concerns automatic rarity points and free physical pieces. |
| Furniture ownership | Buy individual quantities, including affordable duplicates and matching sets. Two matching chairs must be possible. Earned artwork and rug designs remain reusable unlocks. |
| Early progression | A participating newcomer who has not won can afford meaningful furniture after two completed rounds and a basic ride after four to six total rounds, allowing for the furniture purchase. Winning accelerates progress. |
| Reward feedback | Show the earned amount and progress toward a chosen purchase after the first round. Set prices and awards together against the target pacing. |

## UI follows the player's activity

The interface needs a coherent redesign across the session. The same visual language carries from shopping to styling, judging, and purchasing.

| Activity | Information and actions to prioritize |
| --- | --- |
| Arriving | Own house, the next round, visible shops, and the skate park. Use useful floating signs and a clear next action. |
| Shopping | Theme, time remaining, cargo capacity, the nearby piece, and checkout direction. Animate a pickup into the capacity meter. |
| Styling | Collected pieces, placement, rotation, color, undo, and compatible earned designs. Keep the selected piece and available action clear. |
| Judging | The room, theme, creator, voting action, and an inspect action for interesting pieces. The room remains the focus. |
| Results | Outcome, earned reward, progress toward a purchase, Play again, and Back to neighborhood. |
| Buying and furnishing | Price, quantity, ownership, preview, and placement. Distinguish buying a physical piece from applying an earned design. |
| Riding | Only the equipped ride's actions. The skateboard exposes Jump, Kickflip, and Grab, with readable input prompts for each device. |

The control scheme is a Room Royale design choice. The researched games use different approaches. [Rocket Racing's documented touch controls](https://www.fortnite.com/news/shift-into-high-gear-with-rocket-racing-v28-10?lang=en-US) use directional controls with optional automatic acceleration. [Skate's simplified preset](https://www.ea.com/able/resources/skate) puts pushing and braking on the left stick. These examples support reducing input effort, but do not establish camera steering as a universal vehicle convention.

[Roblox's UI guidance](https://create.roblox.com/docs/production/game-design/ui-ux-design) recommends prioritizing the player's current action. Its [cross-platform guidance](https://create.roblox.com/docs/projects/cross-platform) covers input-specific prompts and adaptable layouts. Actual mouse, touch, and controller testing remains part of acceptance.

## Build sequence

### 1. Refine the approved cart

The first change combines camera-relative steering, explicit jump and drift intent, clearer capacity feedback, noticeable weight, and removal of the jump boing. The v4 movement and cargo evidence remain the comparison baseline.

Implementation status: the local candidate uses a separate Drift action, animated capacity and fit feedback, and stronger load effects. Engine checks and desktop pickup/checkout evidence exist. Phone/controller acceptance and the interrupted cargo comparison still need completion. The [implementation brief](cart-refinement-implementation-brief-2026-09-08.md) records the assigned scope.

Acceptance: an unfamiliar player can identify a full cart, predict whether a nearby piece fits, and find checkout. Empty and loaded runs show the intended acceleration and braking difference. A camera turn during charge preserves the charge. Mouse, touch, and controller inputs release correctly after menus and focus changes. Stacking, suction, jumping, and wall recovery retain their existing behavior.

### 2. Connect the complete round

The main game's neighborhood and round lifecycle use the new market and cart. Checkout finishes and records each piece's identity and variant before the market is unloaded. The actual styling inventory consumes that completed collection. Player judging and results complete the cycle. Play again re-enters the queue, while Back to neighborhood returns control to neighborhood activities.

The main game already supports separate round cohorts, while the prototype has one current shopping session. Integration keeps each session, theme, stock pool, collection, and result attached to its own round. The final checkout deadline and transition must have one owner, so delayed suction and phase changes cannot race each other.

Acceptance: two players finish Shop, Style, Judge, and Results using the pieces they actually checked out. They can replay or return home. A player remaining in the neighborhood stays there. A second active round cannot overwrite the first round's theme, stock, inventory, or rewards. Furniture remains available after the market instance is released.

### 3. Make the first purchases work

Physical furniture ownership gains quantities. New profiles follow the earned-first-purchase direction, and awards and catalog prices meet the accepted pacing. Existing ownership and house placements migrate without losing purchased pieces. A chosen purchase appears in reward progress, and the player can buy and place matching furniture.

Acceptance uses isolated preview profiles. A fresh participating profile reaches the two-round furniture target and the four-to-six-round ride target after spending on furniture. Buying and placing two matching chairs succeeds. Placing a third without owning it fails. Moving or storing a chair preserves the owned count. Rejoining restores furniture, balance, and placement. Repeat purchase or reward delivery cannot duplicate a charge or grant.

### 4. Add the first earned designs

A small collection of artwork and rug designs connects achievements, styling, house decoration, and inspection. Collected pieces retain their own physical count and identity when a design is applied. Achievement grants use verified round results and checkout events.

Acceptance: a locked design explains how it is earned. An unlocked design persists after rejoining and applies only to a compatible collected or owned piece. It grants no extra physical copy and no automatic rarity points. Other players see the correct design and can inspect its name and earning condition.

### 5. Put the skateboard and megaramp in the neighborhood

One purchasable skateboard has animated pushing, coasting, charged ollies, a Kickflip button, and a held Grab button. Catches and landings start forgiving. Board tuning remains separate from the approved cart. Physical purchase and equip persistence use the progression work from milestone 3. Initial movement and geometry prototypes can run alongside milestones 2-4.

The park contains a large roll-in, gap, broad landing, quarter pipe, and a fast route back to the top. It is visible from the neighborhood and has space to watch. Bigger airtime comes from the ramp first, preserving ordinary cart jumping. Misses allow fast retries.

Acceptance: the player buys, equips, rides, removes, and re-equips the board, including after rejoining. Push animation matches acceleration, tricks respond to explicit input, and landing restores the riding pose. Both cart and board traverse their intended park routes. Quarter-pipe transitions do not trigger wall ejection or leave a rider below the surface. Ordinary walls still cause the intended cart crash response.

## Current implementation gaps

These are source observations, not new product decisions:

- [RoundManager](../src/ServerScriptService/RoundManager.server.lua) still acquires the older showroom and cart system. [StoreSession](../prototype/superstore/StoreSession.server.lua) starts the standalone Hillside session. Its Style phase delivers a demonstration collection, without invoking the main styling and judging flow.
- [RoomService](../src/ServerScriptService/RoomService.server.lua) reduces cart contents to item-ID counts and adds every permanently owned item. Integration must preserve per-piece variants and remove the permanent physical inventory grant.
- [ProgressionConfig](../src/ReplicatedStorage/ProgressionConfig.lua) starts a new profile with 400 Bucks. The current catalog has immediately affordable furniture. Rewards also include rarity bonuses. These values need reconciliation with the agreed pacing and judging rules.
- [ProgressionService](../src/ServerScriptService/ProgressionService.lua) rejects duplicate furniture purchases and limits placement to one of each type. Quantity migration must update purchases, snapshots, placement, save loading, and the corresponding UI together. Its profile sanitizer preserves known fields, so quantities, design unlocks, ride ownership, and achievement progress need explicit serialization and migration. Aggregate wins alone cannot establish wins across several themes.
- [ProgressionClient](../src/StarterPlayer/StarterPlayerScripts/ProgressionClient.client.lua) also exposes owned physical furniture during Style. Both client inventory presentation and server inventory authority must follow the new collection rules.
- [JudgeService](../src/ServerScriptService/JudgeService.server.lua) currently combines automatic and player scoring. The ranking and reward calculation must agree on the new player-judged outcome.
- [PracticePark](../prototype/superstore/PracticePark.lua) can build at a supplied origin. The ride runtime rejects very steep support, and crash detection treats steep surfaces as potential walls. Quarter pipes require surface-aware behavior as well as geometry.
- The script project does not contain every Studio-owned asset. A Rojo script build alone does not prove that a complete playable neighborhood place has been reproduced. See the [source-tree note](../src/README.md).

Exact prices, earning thresholds, the final voting presentation, and detailed trick bindings are tuning and implementation work. Solo and tied results need an explicit rule before competitive-win achievements ship. None of these pending details changes the accepted player experience above.

The first full playtest of this plan is a complete competition followed by its neighborhood payoff. The [round-integration draft](round-integration-implementation-brief-2026-09-08.md) prepares that work while preserving the remaining product decisions. Later playtests exercise repeat-round enjoyment, purchase pacing, earned designs, and the first owned ride. The existing [v4 evidence](playtest-iteration-v4-2026-09-08.md) establishes the cart baseline; the milestone 1 candidate does not complete the whole plan.
