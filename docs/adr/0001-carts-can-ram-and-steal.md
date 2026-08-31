# Carts can ram, ragdoll, and steal

Room Royale's Shop phase is a cart race, and the cart is meant to be the part of the
game a player can visibly get better at. We considered keeping Shop non-contact, which
matches `AGENTS.md`'s "avoid harsh punishment or mean-spirited round flow" and keeps
Shop purely about item knowledge and routing. We chose contact instead: carts collide,
a hard enough hit ragdolls the rider, and a ragdolled rider can drop a carried piece for
someone else to take. Ramming is the skill ceiling. Without it, boost and drift have
nothing to be good at, and Shop is a timed collection task rather than a race.

## Consequences

- `AGENTS.md` and the Judge entry in `CONTEXT.md` are now wrong where they forbid combat
  and mean-spirited flow. That prohibition applies to Judge and Results, not to Shop.
- Losing a piece to another player has to read as funny rather than punishing. The
  flying ragdoll is the payoff, not the loss.
- A player who only rams and never shops must be able to fail. Griefing containment is a
  release gate, not a polish item: a Shield and one or more checkout zones where a loaded
  player is safe.
- Every ragdoll needs a recovery that cannot get stuck. A permanent ragdoll is a lost
  round for that player, and the current recovery path is broken.
