# Original generated sofa draft

This archive preserves the native Studio procedural-generation result used to investigate the furniture workflow on September 7, 2026. It is a reference, outside the authoring project's Rojo mapping.

- Target: Room Royale - Test, place 86511797738570.
- Generation name: Sofa.
- Generation ID: `fea86c53-22c5-4a71-80e9-5a0b66d93cde`.
- Job ID: `097ac210-bf51-4659-b070-d6128cdd8dfd`.
- Studio reference: `ServerStorage.RoomRoyaleFurnitureReferences.SofaAIDraft`.

The prompt used the user's wording:

> One genuinely good procedural sofa generator could produce hundreds of visually distinct sofas without you maintaining hundreds of models. They're parameter-driven models whose geometry/materials/etc. regenerate based on attributes. The target experience is cozy, playful, tactile, proportional, and desirable to decorate with earned or purchased decor.

[source.zip](source.zip) contains the generator and all four dependency ModuleScripts read from Studio. [source-manifest.json](source-manifest.json) records their saved UTF-8 byte lengths and SHA-256 hashes. Every archive entry was read back and hash-checked before removing the loose duplicate files.

The draft had recognizable rolled arms but only basic color/material controls and a 9.5 by 10 by 10 model Size around much smaller geometry. The collection uses `authoring/furniture/SofaGenerator.lua` and its small CSG helper instead. The archive has not been installed into the game source or embedded in any baked catalog item.
