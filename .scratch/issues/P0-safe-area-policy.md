---
title: Apply one safe-area policy to runtime UI
status: open
priority: P0
source: docs/public-beta-readiness-audit-2026-08-30.md
---

## Problem

Runtime-created ScreenGuis use different inset behavior. Panels can overlap the Roblox top bar or move into unsafe edges on phones, tablets, and controllers.

## Scope

Apply one documented safe-area policy to `RoundClient`, `PlacementController`, `PromptController`, `JudgeClient`, and `LobbyBoutiqueClient`. Keep each screen owner responsible for its own layout.

## Acceptance

- Interactive controls remain inside the safe area on iPhone 17 Pro, iPad Pro M5, Xbox, and desktop presets.
- The RoundClient banner does not overlap phase panels.
- Style placement controls and Judge controls remain reachable without a mouse.
- The policy is written beside the shared UI rules so new ScreenGuis follow it.
