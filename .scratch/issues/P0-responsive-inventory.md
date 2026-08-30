---
title: Reflow the 15-slot phone inventory tray
status: open
priority: P0
source: docs/public-beta-readiness-audit-2026-08-30.md
---

## Problem

The shop inventory tray uses fixed 1160px geometry. It clips at the iPhone viewport even though the 15-item cart capacity is correct.

## Scope

Size the tray and slots from the available viewport. Preserve 15 slots, readable item thumbnails, and the existing drop interaction.

## Acceptance

- The full tray fits at the verified iPhone 17 Pro viewport of 874x402.
- The full tray fits on the iPad Pro M5 preset.
- Slot drop works with touch, mouse, and controller input.
- The three capacity values remain synchronized at 15.
