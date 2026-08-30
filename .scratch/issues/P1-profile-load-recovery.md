---
title: Add profile-load failure recovery
status: open
priority: P1
source: docs/public-beta-readiness-audit-2026-08-30.md
---

## Problem

`ProgressionService` does not protect the `LoadProfileAsync` failure path. A transient profile-service error can leave a player without a clear retry or recovery result.

## Scope

Define the player-visible failure state, retry behavior, and safe server cleanup path. Preserve the existing `PlayerProgression_v1_PS` store and do not migrate the old raw store as part of this issue.

## Acceptance

- A forced profile-load failure does not leave a partially initialized player state.
- The server logs the failure with enough context to diagnose it.
- The player receives a clear retry or recovery result.
- A successful retry loads the profile once and does not duplicate session state.
