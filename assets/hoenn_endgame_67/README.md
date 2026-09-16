# Hoenn endgame air tileset

`sector_air.png` and `air-tileset-v1.json` are the exact `air` atlas and
block/collision catalogue exported from the user's Hidden Evolution Map Studio
project on 2026-09-05.

- source project SHA-256: `cb470cbde5cd5693eb9122c68b72f9177927c2f2a31291303662fd5fdc047585`
- atlas SHA-256: `8e5d38917dc2c35f0866b4155e86bb4fa4cdea0604500ca0fa791745066b740f`
- owner: `KASC-66-HOENN-LEGEND-PORTALS`
- use: Rayquaza chamber and its Voxel/2D world surround

The battle actor remains a static 2D sprite in classic battles. The atlas is a
map/background asset and does not opt a battle actor into animation.

## Lavados volcanic surround

`volcano.png` is the pinned 128×40 visual atlas from the reviewed
`lavados_vulkan-3.1.8` source snapshot.

- atlas SHA-256: `f69441cb181061017a591cb389a88e06bdcc479949433b37a64a358c5fc55696`
- owner: `KASC-66-MOLTRES-VOLCANO`
- use: all three user-authored Lavados dungeon floors and their battle surround
- collision contract: deep-copy CAVERN collision/water/warp metadata unchanged;
  only the atlas and visual block 41/border block 125 are Card-local overrides

The native CAVERN tileset and the user's map block arrays are never patched.
Turning off the Lavados Card therefore leaves this additive tileset unused.
