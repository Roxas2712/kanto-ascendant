# Kanto Ascendant 6.5.2 RC1 – renderer-choice test build

This local release candidate adds the standalone Voxel Ascendant renderer
without making it a Kanto Ascendant dependency.

## Renderer choices

- Native 2D remains the complete default and needs no renderer package.
- `VOXEL_ASCENDANT 0.1.1` is the recommended sandbox-native option for
  voxel overworlds, MAP/DISCS battles and native HEVO wall decals.
- Existing `VOXEL_ASCENDANT 0.1.0-rc.1` installations remain accepted and
  receive the same KASC sprite-anchor/scaling adapter. Updating to `0.1.1` is
  recommended, but it is no longer required to avoid broken battle geometry.
- KASC now selects battle-HUD geometry from an explicit renderer profile, not
  from a global engine/version guess. Voxel Ascendant uses the wide landscape
  edge layout; its HP/status bands, KASC EXP bar, caught icon, party/Safari
  rows and centred text/menu clipping share one current-shot receipt. Hardened
  Dramaless keeps renderer ownership of its existing layout, and native 2D is
  untouched. Battle Art 1.9.0 keeps renderer ownership too; its separate
  enemy/player HUD scale is normalized for EXP, caught, gender, party and
  Safari placement. Missing or stale seams fail back to the native HUD instead of
  hiding, duplicating or drawing over it.
- `DRAMALESS_SHAPE 1.6.2-ST.190.1` remains a reviewed, hardened transition
  alternative.
- Separately installed upstream `BATTLE_ART_VOXEL_FORK 1.9.0` is a third
  reviewed renderer choice. KASC neither copies nor changes its sprites,
  trainers, animations, camera, menus, options or archive. A KASC-local closed facade
  exposes only the reviewed renderer modules needed for worlds, battles, HUDs,
  bundled Wilds and HEVO wall decals.
- Install at most one renderer. Multiple world/battle pipelines deliberately
  conflict rather than drawing the same scene twice.
- Battle Art 1.8.3 and any unreviewed Battle Art version remain blocked; only
  exact upstream 1.9.0 from `absol89/DramaticShapeVoxelMod` is allowed.
- Dramatic Shape, Potato Voxel, Terrarium and First Person are
  blocked because they currently do not work with Gen1 Recomp 0.1.90. Newer
  launchers explain this in English/German and recommend Voxel Ascendant,
  hardened Dramaless or native 2D. The exact hardened Dramaless `.190.1` build
  stays allowed; every other Dramaless version is blocked.

Voxel Ascendant is an independent MIT fork based only on
DramaticShapeVoxelMod v1.6.1 (`790c34e`). It contains no Battle Art or
Gen2-3D-Sprites code, artwork, ROM data or binaries.

## Bound companion

- File: `voxel-ascendant-0.1.1-direct-install.zip`
- SHA-256: `bfc79f04aace1c6f9e12f2145737635b35cca5ef3a8c63fe5a531dd87c1a4141`
- Engine: Gen1Recomp `>=0.1.90`

## Public-art boundary

- The 42 native FireRed/LeafGreen trainer-front PNGs are no longer included.
  Compact Kanto opponent cards use the edition-original Gen-I art generated
  from the user's own ROM.
- Red's compact front/card/Hall-of-Fame portrait likewise uses the ROM-derived
  native Gen-I image.
- Kanto Ascendant's authored Red/Blue/Casey throws, fronts and Voxel standees
  remain included and unchanged. The removal does not disable the HD/Voxel
  trainer presentation.
- Existing saves that selected the retired `FRLG` portrait option migrate to
  `ORIGINAL`; no save or story state is changed.

## Bound alternative renderer

- File: `DRAMALESS_SHAPE-1.6.2-ST.190.1-gen1recomp-0.1.90.zip`
- SHA-256: `1af925bc849cfdf6ba8a15bbe6465f6099cff109e55b0723756d1b4d628ca4d6`
- Engine: Gen1Recomp `>=0.1.90`

## Separately installed Battle Art alternative

- Upstream release: `absol89/DramaticShapeVoxelMod` 1.9.0
- Asset SHA-256: `3ba60ad7dc8443f2a337c147ca8be31ce3661fd549cf9b4e4e000206c3d780c8`
- The asset is not part of, mirrored by or relicensed with Kanto Ascendant.
- Battle Art remains the sole owner of all artwork and presentation options.

## Required private-test client

- File: `gen1recomp-0.1.90-clientfix-rc-A.love`
- SHA-256: `1f0250787f295a60f85b74be95079ecb602329a51ccc4b859aefbe388c932bb3`
- The clientfix supplies the reviewed scoped-storage, sandbox and native 2D
  wall-decal contracts used by this RC.

## Installation for the private test

1. Close the game.
2. Start the supplied Gen1Recomp 0.1.90 clientfix in the isolated test setup.
3. Import the Kanto Ascendant 6.5.2 ZIP itself.
4. Import either Voxel Ascendant, exact upstream Battle Art 1.9.0, the reviewed
   hardened DRAMALESS ST.190.1 package, or neither for native 2D.
5. Do not enable two renderer packages at once; restart after changing the
   active renderer.

This is a user-test RC, not a public upload. Existing Red, Blue and Yellow
saves remain supported and must not be deleted for the test.
