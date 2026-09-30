# Promoted to public KASC 6.7.32

The following candidate test report is historical; this package is the public release.

# Pyro MAP / Sea Terrarium verification — local candidates

Bases: public VASC 3.0.59 and KASC 6.7.31. Isolated source branches and disposable LOVE identity; installed game, real saves and public release endpoints were not modified.

## Native desktop

LOVE 11.5 with the existing 0.1.90 QA host and both candidate sources. Real Blaine trainer battle: MAP provider, blaine_center shape, mid (400,256), Pokémon (376,256)/(424,256). Platform retained in battle furniture and excluded from whole-prop sight removal. Screenshots inspect court, lava and fountain phases. Starts from all four removed edge cells (16/17/32/33 at y=16) load onto safe walkable cells through native map recovery.

Route 20 surfing encounter: side and behind layouts render continuously (60 successful frames each), submerged actors, transparent water, open rim, neutral button, moves menu and attack; portrait touch layout additionally captured. Gorochu remains coloured with the selected HD art. The QA host lacks the user's optional HD human pack, so these screenshots show its fallback trainer artwork.

## Automated checks

- KASC route suite: 1,564 checks, including walkability, lava collision/water exclusion, links, leader/party, identity/rewards and music metadata.
- Sea suite: exact ocean/surf selection, land/Gen2/interior exclusions, both actor depths, trainer heights unchanged, finite geometry, bounded four-entry scene cache, no idle geometry rebuild, no sea dome, optional-water failure latch/release, one cached mesh/program, state restoration and partial-allocation cleanup.
- Blaine geometry suite: v1/v2/v3 ownership, unobstructed platform/bridge, fixed centre, four jets outside native lanes, stairs and OFF behavior. Blaine Terrarium alias remains intact.
- Existing Terrarium locations, zoom, light reuse, effect/dome failure, furniture receipts/light descriptors, battle camera continuity, arena request/query caches pass. Differential arena-result suite: 46 scenarios against public 3.0.59; unchanged unrelated maps and collision/height/camera invalidation.
- Water and existing Terrarium shader variants: 32 stages / 16 linked programs pass Khronos glslang, covering GL/GLES legacy and GLSL3. Native desktop water program compiles and renders.
- Build receipts separately verify every packaged Lua file, archive CRC, file hashes, complete public-baseline preservation, and VASC prepared-model checksums.

## Limits

No physical iOS/Android device run or mobile FPS claim. Desktop portrait touch preview is a layout check. Fountains reuse cached geometry with at most four draws and no full-scene reflection. Surfing chooses Sea; fishing from land keeps the existing scene. No publication was performed for these candidates.
