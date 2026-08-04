# Kanto Ascendant 5.2.2 — Android Cry & Follower Hotfix

5.2.1 corrected the oversized Johto back sprites, but two compatibility
problems remained on Android. This follow-up fixes both at their runtime
source:

- Johto fallback cries now derive from the game's native Gen-I cry programs,
  which works consistently across desktop and mobile audio backends.
- All 200 normal and shiny Johto follower sheets are packaged in Gen1
  Recomp's ready-to-render 16×96 layout.
- A renderer-level safety guard keeps PokéPC Followers, Followers EX and
  graphics wrappers from requesting a missing Gen-II sheet, even when
  low-level Lua closure access is unavailable.

Existing Red, Blue and Yellow saves remain compatible. Import
`kanto-ascendant-5.2.2.zip` or the identical `.modpkg` through the launcher.
