## Project Identity
This project is a Roblox multiplayer decorating competition game built around a fast `Shop -> Style -> Judge` loop.

Core loop:
1. A round theme is revealed
2. Players rush through the shop in shopping carts
3. They grab furniture, decor, and accent pieces that fit the round
4. Everyone enters their own style space
5. Players place, rotate, tint, and style their room
6. The rooms are toured and judged
7. The best-designed space wins the round

## Current Game Framing
Old extraction / robot-world / home-return canon is deprecated for this project.

Current concept:
- this is a stylish, fast-paced design competition
- the fantasy is shopping quickly, making smart picks, and transforming a blank space
- the fun comes from theme interpretation, strong silhouettes, clever item choices, and room reveals
- shopping carts are part of the identity and add energy to the shop phase
- the game should feel easy to understand, fun to spectate, and satisfying to judge

## Emotional Feel
Shop phase:
- lively
- fast
- playful
- slightly chaotic
- readable

Style phase:
- cozy
- creative
- expressive
- satisfying
- aspirational

Judge phase:
- showy
- rewarding
- social
- stylish
- clear

Everything in the game should support this fantasy:
- race
- gather
- design
- reveal
- judge

## Design Pillars
1. Shopping should feel fun, quick, and memorable.
2. Styling should feel expressive without being overwhelming.
3. Themes should be broad, relatable, and easy to play into.
4. Rooms should be readable at a glance and fun to judge.
5. The game should feel stylish, cozy, and playful rather than noisy or simulator-like.

## What To Preserve
- Short, readable Roblox-friendly rounds
- Strong shop-to-style momentum
- Kid-readable furniture silhouettes
- Clear theme communication
- Fast room readability during judging
- Simple but expressive placement tools
- Premium-feeling UI without clutter

## Avoid
- Extraction, survival, or post-apocalypse framing
- Lore that conflicts with the decorating-competition concept
- Harsh punishment or mean-spirited round flow
- Overly cluttered rooms that are hard to read
- Tiny over-detailed assets that break placement clarity
- UI that feels noisy, cramped, or overly simulator-like

## Guidance For Code, UI, And Features
When making changes, optimize for:
- faster and clearer shop decisions
- better theme readability
- stronger room transformation payoff
- better judging and spectating moments
- cleaner placement and furniture interaction

New features should strengthen at least one of:
- shopping excitement
- styling creativity
- judging clarity
- replayable round variety

## Room And Asset Direction
Style rooms should feel:
- modern
- open
- believable
- decoration-friendly
- easy to read during judging

Furniture and decor should generally be:
- readable from gameplay distance
- collision-friendly
- easy to place on a simple grid
- varied enough to support multiple broad themes

Prefer:
- clear silhouettes
- modern loft / showroom-friendly pieces
- soft neutrals plus a few strong accent items
- blank-slate room shells with good wall space

Avoid:
- oversized meshes
- baked-in clutter everywhere
- hard-to-place shapes
- fixed room details that overpower the round theme

## UI Tone
UI should feel:
- cozy
- stylish
- clear
- premium
- readable for kids

UI should not feel:
- loud
- cheap
- cluttered
- overly tiny
- generic simulator spam

## Naming And Writing Tone
Prefer:
- playful
- concise
- stylish
- welcoming
- easy to understand quickly

Avoid:
- gritty or survival-game wording
- overly edgy phrasing
- lore-heavy explanation where simple wording works better
- overly formal or mechanical language

## Writing Source
`AGENTS.md` is currently the source of truth for project direction and player-facing tone.

`docs/writing_guide.md` is legacy and may still reflect an older game concept.
Until that file is rewritten, do not let it override the current `Shop -> Style -> Judge` direction described here.
