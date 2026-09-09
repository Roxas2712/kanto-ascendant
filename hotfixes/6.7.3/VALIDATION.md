KASC 6.7.3 fixes the circular Story Level Cap calculation. STORY uses the authored milestone team plus difficulty, independently of player party levels. Before adaptive battle scaling, the current mandatory trainer receives that fixed ceiling. CUSTOM and OFF retain their policy.

Released engine 0.2.56 does not call pokemon.level_cap. The controller therefore also clamps the final exp.gain award after reward multipliers and guards Rare Candy through the existing ItemEffects API. Over-level records retain their level and EXP; excess new EXP is discarded. Day Care already uses the controller directly. No save schema change.

Validation: 517 assertions pass: controller 87, adaptive trainer policy 88, menu 30, Day Care 12, plus 50 assertions for each of Red/Blue/Yellow against released engine 0.2.56 and the earlier LevelCap engine source (version 0.0.0-dev). Tests execute in native LÖVE against the extracted release package. The original 6.7.2 controller fails the new engine test: level 30 instead of the Misty cap of 21. These are integration/fixture tests, not a physical Android playthrough.

Package payload differs from verified public 6.7.2 only in story_level_cap.lua, manifest.json, and .modkit/pack.json. The pack receipt also repairs stale 6.7.2 life_of_rival/manifest hashes without changing those runtime fixes. Every listed file hash was verified. Cards retain IDs, label art, save scope, options, and VASC 3.0.13 pins; native Card codec and exact feed resolution passed for all three editions.

Rollback: reinstall the unchanged public kanto_ascendant-6.7.2.zip from release v6.7.2 (SHA-256 fa7054c819839dc05531c94b98c240f4475692a9fffbe88bc2700f895724cdcf). The previous Cards release is v1.3.0-rc.19. No save migration is required.
