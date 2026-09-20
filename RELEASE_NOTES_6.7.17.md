# Kanto Ascendant 6.7.17

World encounter artwork and Hoenn compatibility for Voxel Ascendant 3.0.34. Includes the occupied PC-box visibility fix from 6.7.16.

- Bundles species-specific native sheets and detailed voxel fronts for Groudon, Kyogre and Rayquaza, without requiring the optional follower archive.
- Adds 682 existing authored Crystal/Emerald animation frames for 22 world encounter species. VASC uses these as pixel-art fallbacks; selected available HD and Stadium providers retain priority. Frame timings and original artwork are preserved.
- Fixes the Deoxys puzzle triangle's runtime cell/pixel position so its visual location and interaction position move together through the puzzle. Encounter and capture gates remain intact.
- Corrects RED/BLUE/GREEN trial visibility in the voxel camera using world depth, while retaining the intended puzzle visibility radius. Older renderers retain a guarded fallback.
- Avoids projecting flat 2D world-surround padding into voxel views; native 2D surroundings remain available.

Install **Kanto-Ascendant-6.7.17.zip** and **Voxel Ascendant 3.0.34** for the combined scenery/animation update. An optional installer backs up the existing mod and preserves omitted downloaded sprites. Existing saves and HD downloads do not need to be deleted.

Native encounter/puzzle checks and focused regression tests passed. This update does not claim a complete redesign of every Hoenn room or a full new playthrough on physical mobile hardware.
