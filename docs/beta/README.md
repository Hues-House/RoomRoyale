# Room Royale beta orchestration

Prepared September 9, 2026. Working source: `D:\code\RoomRoyale`, baseline commit `bb6d5d9`. This task initially opened in `C:\Users\jaked\Documents\New project`, an older bootstrap. Read current source and documentation in the D: repository before implementation.

Start architecture work with [the Pro kickoff](pro-architecture-kickoff.md). The current model routing is Pro for shared and workstream architecture, Astra for orchestration and hands-on specialist work, and Luna max for bounded implementation. The installed agent configs currently define Astra roles; the kickoff asks Pro to provide the worker configuration and reconciled launch assignments.

## Start and resume

1. Read the current repository's `AGENTS.md`, `docs/README.md`, accepted refinement plan, and `docs/verification.md`. Preserve the September 9 physics briefs, their proposal status, and any current working changes.
2. Check branch, working changes, saved-scene identity, toolchain, and this queue. Use the complete Test scene for integration and Hillside for isolated cart/store work. The open Warehouse-Repair and Warehouse-Slice Studio files were inspected read-only; both have PlaceId/GameId zero and prototype scripts. Neither establishes the current full Test state.
3. Run one lead plus at most three specialists. Assign each a bounded ticket, exact editable files, required evidence, and a completion criterion. Reuse the specialist roles when resuming; keep decisions and evidence in this directory.
4. Give each implementation worker an isolated checkout containing the relevant current working changes, or an explicitly disjoint file set. One owner controls each shared file. Git worktrees do not isolate Studio: the lead assigns one Studio writer at a time and identifies the target before installation or Play.
5. Integrate and verify each playable unit before expanding it. Update the queue with actual results, evidence paths, remaining checks, and the next ticket. A document, build, or agent report cannot close a gameplay acceptance gate.

The setup includes reusable project agent configurations. It does not schedule background work, enable Pro mode, change this already-running task's model, or publish Roblox content. Initial specialist sessions inherit the current task's model and effort. New project sessions can load the saved configurations.

## Roles and model policy

These are workload recommendations, not comparative benchmarks on Room Royale. Start at high for difficult work. Escalate a bounded unresolved design or physics problem to xhigh after identifying what the high-effort attempt failed to resolve. Pro owns the initial architecture pass. Use a later Pro follow-up for a difficult decision with a concrete evidence packet.

| Role | Default | Owns |
| --- | --- | --- |
| Lead orchestrator/integrator | GPT-6 Astra, high | Scope, queue, contracts, shared lifecycle, integration, Studio scheduling, beta evidence |
| Movement and physics | GPT-6 Astra, high | Canonical ride solver, gestures, cargo handling, crash/recovery and measured movement envelope |
| Store environment | GPT-6 Astra, high | Hands-on 3D construction, store composition, departments, routes, stock placement, ramps, lighting and visual iteration |
| Gameplay systems | GPT-6 Astra, high | Cohort rounds, checkout-to-Style, onboarding, judging, results, rewards, quantity ownership and progression |
| Bounded implementation worker | GPT-5.6 Luna, max | Settled interfaces, repeatable changes and explicit acceptance checks; worker config follows the architecture handoff |

Use Luna max for bounded implementation once interfaces and acceptance are settled. Astra remains hands-on for modeling, visual judgment, novel physics and difficult integration. Assess the first Luna tickets by verified progress and correction work. Escalate a contract gap or repeated unresolved failure. Do not spend another agent on routine polling.

GPT-6 Astra is exposed by this host's task and subagent tools. No separate `gpt-6-pro` model or Pro-mode launch argument is exposed here. Pro mode and reasoning effort are different settings; max effort is not proof of Pro. Use a separately available GPT-6 Pro session for [the architecture kickoff](pro-architecture-kickoff.md). It produces the shared architecture, three workstream plans and executable handoffs.

Model references checked September 9: [model catalog](https://developers.openai.com/api/docs/models), [Astra model guide](https://developers.openai.com/api/docs/guides/latest-model), [reasoning guidance](https://developers.openai.com/api/docs/guides/reasoning), and [project custom agents](https://learn.chatgpt.com/docs/agent-configuration/subagents).

## Specialist work packages

- [Movement and physics](movement-physics.md). Reconcile the September 9 proposals with the approved M1 candidate before committing control changes. Measure the cart before fixing store dimensions.
- [Store environment](store-environment.md). Build on Hillside's actual market, tested routes, checkout and cargo system. Deliver Roblox geometry and gameplay evidence, not only a concept document.
- [Gameplay systems](gameplay-systems.md). Follow the accepted neighborhood, competition inventory, player judging, first-purchase pacing and earned-design decisions. Preserve independent round cohorts.

The current docs index says the five September 9 physics briefs are proposals and none is accepted. Their supersede notes resolve precedence among those proposals, not permission to silently replace the accepted refinement plan. Reversible comparison candidates can test them while keeping the approved baseline available.

## Shared contracts

Movement publishes measured cruise/boost and downhill speeds, loaded braking distance, turn radius, reliable ramp/landing range, support classification, and recovery behavior. Environment supplies identified test routes and surfaces. Treat every untested dimension as a hypothesis. Shopping must remain possible through a clear ordinary route; optional jumps and difficult routes can retain the approved special finds.

Gameplay owns round identity, absolute deadlines, stock ownership, checkout finalization, completed per-piece collections and result identity. Environment supplies stock anchors and routes, not reward authority. Movement preserves cargo identity and server validation, not round timing. The lead owns changes that cross these boundaries and integrates shared runtime extraction. The current store builder's replacement of global `CartLab` and global lighting writes must be reconciled with concurrent round markets.

UI work belongs to the affected specialist, with the lead checking consistent focus, responsive layout and input prompts across all phases. Placement, assets, persistence and network checks remain release gates even though there are only three specialist roles.

## First shared milestone

Use one polished Hillside shopping section with two recognizable departments, a flat shopping path, a forgiving roller/bank route, one optional jump and a readable checkout. Tune it with the real cart, including a loaded run. Then prove that the exact checked-out pieces reach actual main-game Style placement after the market is released.

This is the first milestone, not the final store. Expand into a complete coherent environment after the movement envelope and inventory handoff pass. The full beta path then completes player judging, results, replay/home, first purchases, earned designs and the approved first ride.

## Work queue

| ID | Owner | Deliverable and acceptance | Initial status |
| --- | --- | --- | --- |
| B00 | Lead | Verify current repository/build/saved-scene baseline and preserve working changes | Passed: repository/Rojo check; saved Test 54 and Hillside 30 managed scripts have zero mismatches; preserve 106 additional Test scene scripts |
| B01 | Movement + lead | Resolve proposal contradictions and capture baseline handling/cargo/device gaps; comparison candidates preserve v4 behavior | Source analysis complete; engine comparison pending |
| B02 | Environment | First finished two-department section with ordinary route, optional riding route, stock and checkout | Work package prepared; construction pending |
| B03 | Lead + gameplay | Per-round shopping runtime, isolated templates, one checkout finalization boundary, exact collection into real Style | Planned; precedes full-store integration |
| B04 | Gameplay | Complete two-player round, cohort-local themes, player-only judging, finalized outcomes, replay/home | Planned; solo/tie win policy must be explicit before awards ship |
| B05 | Gameplay | Fresh-player onboarding, quantities, persistence migration, first furniture after two participating rounds and first ride after four to six total rounds including furniture spending | Planned under accepted pacing |
| B06 | Environment + movement | Complete cohesive store and accepted park routes, measured loaded-cart and device performance | Depends on B01/B02 and integration contracts |
| B07 | Gameplay + lead | Earned designs and first purchasable skateboard under the approved milestone sequence | Planned; any beta scope reduction must be an explicit product decision |
| B08 | Lead, specialists in rotation | Device, concurrent-cohort, persistence-failure, exploit-boundary, asset and full-session evidence | Open; use current verification entry point |

Do not hide integration under any one specialist's broad brief. B03 is the lead's primary implementation responsibility while specialists own bounded domain changes. B01 and B02 can proceed together using provisional geometry; B03 can begin independently of final physics numbers.

## Beta acceptance

Use `docs/verification.md` as the maintained release checklist. The lead must show a complete two-client cycle, a second active cohort plus a neighborhood spectator, fresh-player progression with isolated preview profiles, repeat reward/purchase delivery behavior, preserved saved ownership/placements, usable phone/tablet/controller/desktop flows, and current production asset checks. Record measured performance and device conditions. Ask the user to judge actual movement feel and shopping clarity from a playable candidate.

The accepted plan also expects the neighborhood payoff, earned designs and first skateboard. Cut scope explicitly if a smaller beta is wanted. Saving a local scene, saving Test to Roblox, committing source, and publishing Live are separate actions.

## Current evidence and next dispatch

This setup changed orchestration files only. The specialists inspected current source, and the lead ran repository/Rojo verification and saved-place comparison. See [the fresh snapshot report](baseline-snapshots-2026-09-09.json). Runtime improvements, full-store construction, device acceptance and multiplayer beta acceptance are not complete.

For Pro, start with `docs/beta/pro-architecture-kickoff.md` in the current repository checkout. After Pro returns the reconciled architecture and first tickets, give those artifacts to the implementation lead with: "Act as the Room Royale beta lead. Read the current documentation index, the Pro architecture and its implementation queue. Execute the first ready tickets with Astra specialists and Luna-max workers. Preserve complete scenes and working changes, keep one Studio writer, and report the playable candidate and exact verification evidence."
