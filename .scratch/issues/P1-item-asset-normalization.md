---
title: Normalize ItemAssets before public beta
status: open
priority: P1
source: docs/public-beta-readiness-audit-2026-08-30.md
---

## Problem

Nine ItemAssets models are missing PrimaryPart. Asset bounds, roots, collision policy, placement surfaces, and viewport framing are not yet proven for public-beta use.

## Acceptance

- Every production ItemAsset has a stable PrimaryPart or Root.
- Catalog metadata matches the model ItemId.
- Bounds fit the intended room and inventory presentation.
- Collision behavior is explicit for shop, carried, placed, and viewport contexts.
- Floor or wall placement classification is validated for each item.
- The CardboardBox catalog entry is aligned with the showroom set or deliberately removed.
