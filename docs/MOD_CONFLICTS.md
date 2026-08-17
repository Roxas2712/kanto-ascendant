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
| Built-in Kanto-151 encounter plan | `all_pokemon_catchable_151_mod` | standalone All Pokémon Catchable |
| Integrated party and summary UI | `modern_party_ui` | `piftee/gen1recomp-modern-party-ui` |
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
| Other Voxel Ascendant builds | `VOXEL_ASCENDANT@<0.1.0-rc.1 \|\| >=3.0.0-0` | official baseline through 2.x is admitted best-effort |
| Other Battle Art builds | `BATTLE_ART_VOXEL_FORK@<1.9.0 \|\| >=3.0.0-0` | official `absol89/DramaticShapeVoxelMod` baseline through 2.x is admitted best-effort |
| Other PotatoVoxel builds | `potato_voxel@<1.7.2 \|\| >=3.0.0-0` | official baseline through 2.x is admitted best-effort; upstream `LOGS TO DEV` is ON by default |
| Renderer archives currently broken on 0.1.90 | `DRAMATIC_SHAPE` | `TERRARIUM`, `ds_fp_ceiling` |
| Other Dramaless builds | `DRAMALESS_SHAPE@<1.6.2-ST.190.1 \|\| >=3.0.0-0` | official baseline through 2.x is admitted best-effort; all 2.x builds are native-only |

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
Use stable manifest IDs and canonical `owner/repository` slugs. Language packs
remain supported partners. Official Voxel Ascendant, Battle
Art, Dramaless and PotatoVoxel packages are admitted from the table's baseline
through 2.x on a best-effort basis. Every Dramaless 2.x build is renderer-native;
only exact `2.0.2` receives the fixed camera control. Only exact Battle Art
`1.9.2` receives its bounded optional-cache repair. Other in-range releases
receive the common closed capability surface and never inherit an exact
adapter. PotatoVoxel retains its camera, HUD, quality settings and cache; its
upstream `LOGS TO DEV` option is ON by default and can be disabled.

Supported-series admission avoids a KASC update for every renderer release,
but is not a guarantee for every upstream change. Roll the external renderer
back if an update breaks compatibility. Canonical repositories are the support
contract; rich managers and runtime metadata reject explicit mismatches, while
stock 0.1.90 primarily enforces the ID/version fence. Renderer packages
conflict with each other, so install exactly one.
The current
standalone shiny-indicator release
is a hard conflict: it overlaps built-in presentation hooks and still uses
APIs denied by the reviewed sandbox. Pre-baseline and 3.x renderer builds,
unversioned packages, Dramatic Shape, Terrarium and First Person do not work in
this compatibility set. Standalone Wilds is a hard conflict because
Ascendant bundles the living-world core. Useful Bag and Quick Select are hard
conflicts now that their complete replacement systems are configurable inside
Ascendant. All Pokémon Catchable is a hard conflict because Ascendant owns the
complete Kanto-151 encounter/reward plan. Modern Party UI is a hard conflict
because Ascendant owns the same party, summary, icon, gender and animation
hooks.
The standalone Nuzlocke is likewise a hard conflict because Ascendant now
owns encounter limits, fainting and blackout handling. Its rules are kept out
of the global options tree and ordinary Player PCs. Configure them through
**ASC RUN** at the **KASC Terminal in Professor Oak's Lab**; after the explicit
start confirmation, the selected run contract remains read-only.
