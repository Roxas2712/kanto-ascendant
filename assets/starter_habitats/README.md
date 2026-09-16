# Compact starter-habitat runtime assets (6.7)

Runtime authority is the reviewed Map Studio V2.1 project with SHA-256
`322e29447f7481a12d71b14fd50cfebf8d5b2220b3c2622f62339ad79b576e31`.
The preserved twelve-map merge payload is `maps-v2.1.json` (SHA-256
`5914a290836d65d3af79747290a9cab15f764bd55e54df6c7427944f893ba66b`).

`tilesets-v2.1.json` contains only the three source tileset records consumed by
these maps. `access-v3.1.json` is the narrow runtime projection of canonical
Access V3.1 contract SHA-256
`453e35e5adb1233d0fbd72855b4b3f66ee0ab507a0aeda2ba55eab0a54bebd19`.
It contains only the sixteen starter destinations, exact edge cells, durable
reveal receipt ids and safe LAND returns; it does not modify a source map or
the reveal controller. The rejected V2 coordinates are explicitly excluded.

The Gen-II Johto atlas is the same local pokecrystal-derived Map Studio source
already used by Kanto Ascendant's Johto passages. `sector_stone.png` and
`sector_mystic.png` are the matching local Hidden Evolution Map Studio custom
atlases. The runtime does not synthesize or repaint either atlas.

The JSON source still calls the maps visual candidates and preserves its old
editor fallback. `starter_habitats.lua` is the explicit production conversion:
it retains blocks/collision/Voxel metadata, discards placeholder entities and
editor return loops, and supplies checked runtime access, exit and encounter
contracts.
