---
title: Prove the zero-data first-time player flow
status: open
priority: P1
source: docs/public-beta-readiness-audit-2026-08-30.md
---

## Problem

The current loop was tested with an existing saved profile. The game has no evidence that a new player can complete the first round with zero saved data.

## Acceptance

- A player with no existing profile reaches the lobby without errors.
- The player can complete Shop, Style, Judge, and Results.
- The player receives the intended starting collection and progression state.
- The profile saves the result and loads the same state on the next session.
