# KASC 6.7.0-rc.5 — VASC download fallback compatibility

This release explicitly admits **VASC 3.0.0-rc.15.1**, the [HD Download Fallback update](https://github.com/Roxas2712/voxel-ascendant/releases/tag/v3.0.0-rc.15.1). It changes only the KASC manifest and generated package receipt. Gameplay, the RC4 NG+ performance fix, diagnostic-recorder removal, Riolu/Lucario fix and save handling remain byte-identical to RC4.

Install **kanto_ascendant-6.7.0-rc.5.zip** with the new VASC ZIP. [Cards 1.3.0-rc.5](https://github.com/Roxas2712/kasc-cards/releases/tag/v1.3.0-rc.5) pin both exact archives. Close the game before replacing mods, retain saves and mod_storage, and restart. Card IDs and save scope remain unchanged.

Validation: complete archive comparison, every generated pack-entry hash, native Card codec/index checks for all three editions, and exact compatibility-range checks. Previously admitted VASC versions remain allowed; untested future versions remain blocked. This is not a new gameplay or physical-device certification. Previous RC4 assets remain available for rollback.
