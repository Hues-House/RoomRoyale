---
title: Restore Xbox focus and phase input
status: open
priority: P0
source: docs/public-beta-readiness-audit-2026-08-30.md
---

## Problem

The lobby Play button is selectable but no GUI object is selected. Xbox Button A and D-pad input therefore cannot enter a round. Shop labels can also show keyboard text after gamepad input.

## Scope

- Select the visible lobby call to action when the lobby UI opens.
- Expose one focus target for each interactive phase panel.
- Map controller confirm and back actions to the active phase.
- Update action labels from `UserInputService.LastInputTypeChanged`.

## Acceptance

- Xbox Button A or D-pad input enters the queue from the lobby.
- Focus remains on a visible, selectable control after every phase transition.
- Style and Judge support controller focus, confirm, and back without mouse input.
- Shop prompts show gamepad actions after gamepad input.
- Keyboard and touch flows still work in desktop and phone checks.
