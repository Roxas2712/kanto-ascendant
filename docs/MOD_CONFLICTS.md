# Kanto Ascendant conflict guard

The stock-0.1.90 guard is the classic `conflicts` array in `manifest.json`.
It matches exact manifest IDs and runs before a mod entry point. The adjacent
`compatibility_conflicts` rows retain canonical GitHub repositories, affected
systems and concise German/English explanations for later launchers, but
stock 0.1.90 ignores that richer field. Release safety never depends on it.

Current conflicts:

| Feature owner | Canonical manifest ID | Additional known IDs |
| --- | --- | --- |
| Bundled living world / Wilds | `overworld_wild_spawns` | — |
| Bundled trainer rematches | `trainer_rematch` | — |
| Followers EX | `FOLLOWERS_EX` | — |
| PokéPC Followers | `PokePCFollowers_VoxelMerge` | `pokepc_followers_rb`, `pokepcfollowers`, `gamecorner-033/PokePCFollowers` |
| External Quality of Life package | `quality_of_life` | `quality_of_life_pr9_test` |
| Crystal Animated Sprites + shiny visuals | `crystal_animated_sprites_with_shiny_visuals` | official and LOW-K3YS repositories |
| Standalone shiny indicators | `shiny_indicators` | `Deftones565/gen1recomp-mod-shiny-indicators` |
| Gen-II gender / breeding owners | `gender_mod` | `WizzStar/PKMN-G1R-Gender-Mod` plus known gender/breeding aliases |
| Useful Bag | `useful_bag` | `ShaneMcGovernIE/useful-bag` |
| Quick Select | `jj_quick_select` | `Roxas2712/pokemon-quick-select` |
| Nuzlocke | `nuzlocke` | `bryanthaboi/nuzlocke` |
| Kanto Reforged (unreviewed combination) | `Kanto-Reforged` | repository `1Jamie/Kanto-Reforged` is documentation only on stock 0.1.90 |
| Other Battle Art builds | `BATTLE_ART_VOXEL_FORK@<1.9.0 \|\| >1.9.0` | only separate upstream `1.9.0` from `absol89/DramaticShapeVoxelMod` is admitted |
| Exact PotatoVoxel release | `potato_voxel@<1.7.2 \|\| >1.7.2` | only `ShaneMcGovernIE/potato_voxel` 1.7.2 is admitted; upstream `LOGS TO DEV` is ON by default |
| Renderer archives currently broken on 0.1.90 | `DRAMATIC_SHAPE` | `TERRARIUM`, `ds_fp_ceiling` |
| Other Dramaless builds | `DRAMALESS_SHAPE@<1.6.2-ST.190.1 \|\| >1.6.2-ST.190.1 <2.0.2 \|\| >2.0.2` | only the hardened `1.6.2-ST.190.1` transition build and exact official `2.0.2` release are admitted |

These packages overlap Ascendant's native follower, party, renderer and QoL
hooks. Crystal/shiny presentation and Attack-DV gender/breeding are also fully
owned by Ascendant. They are deliberately one-sided conflicts: when an old configuration
starts with both mods enabled, Ascendant is the declaring mod and therefore
enters the engine's `conflict` state while the external package remains
available. The loader error names the conflicting ID.

The mod-manager selection screen uses the same manifest data. Enabling
Ascendant while a listed package is active opens the engine's **CONFLICTS
WITH / DISABLE IT FIRST** notice and does not commit the toggle. The reverse
selection is also blocked by the manager's bidirectional conflict check. Newer
launchers may additionally match a package's normalized `github` field and show
the declared reason and resolution before changing the enabled state. The
stock-0.1.90 launcher cannot enforce repository aliases, so a renamed foreign
manifest ID does not match this release's hard gate.

To extend the guard, add the other package's exact manifest `id` to
`manifest.json`, document it in the table above and add it to
`tests/mod_conflicts_test.lua`. Never match display names or folder names.
Use stable manifest IDs and canonical `owner/repository` slugs. Language packs,
the recommended `VOXEL_ASCENDANT 0.1.1` package, its already reviewed
`0.1.0-rc.1` predecessor for existing installations, the exact reviewed
`DRAMALESS_SHAPE 1.6.2-ST.190.1` transition build, and catchable-151 remain
supported partners. Exact upstream `DRAMALESS_SHAPE 2.0.2` is also supported
in renderer-native mode: its world, battle cards and HUD remain native-owned,
while an exact-shape resolver exposes only the reviewed camera-preset control.
Its official release ZIP SHA-256 is
`85e2f866bd7badce4c5d97ccbf1f8b88b2a9fd30ec0659454c187d7398b808a7`.
Exact upstream `BATTLE_ART_VOXEL_FORK 1.9.0` is also a
supported, separately installed renderer; Kanto Ascendant neither bundles nor
mutates its assets, camera or options and consumes only a local allowlisted facade.
Exact upstream `potato_voxel 1.7.2` is supported through the same closed-facade
rule while retaining its own camera, HUD, quality settings and cache. It requests
network access and sends diagnostic logs when its upstream `LOGS TO DEV` option
is ON (the default); users can turn that option OFF. Renderer packages conflict
with each other, so install only one. Voxel Ascendant, PotatoVoxel, Battle Art
and Dramaless are alternatives and must never be enabled together.
The current
standalone shiny-indicator release
is a hard conflict: it overlaps built-in presentation hooks and still uses
APIs denied by the reviewed sandbox. Battle Art 1.8.3, unreviewed future Battle
Art releases, Dramatic Shape, unreviewed PotatoVoxel versions, Terrarium and First Person do not
work in this exact compatibility set. Stock 0.1.90 blocks them through classic
ID/version rules; exact Battle Art 1.9.0 is exempt. Other Dramaless versions are
rejected while `1.6.2-ST.190.1` and exact official `2.0.2` remain explicitly
safe. Standalone Wilds is a hard conflict because
Ascendant bundles the living-world core. Useful Bag and Quick Select are hard conflicts now that their complete
replacement systems are configurable inside Ascendant.
The standalone Nuzlocke is likewise a hard conflict because Ascendant now
owns encounter limits, fainting and blackout handling. Its rules are kept out
of the global options tree and ordinary Player PCs. Configure them through
**ASC RUN** at the **KASC Terminal in Professor Oak's Lab**; after the explicit
start confirmation, the selected run contract remains read-only.
