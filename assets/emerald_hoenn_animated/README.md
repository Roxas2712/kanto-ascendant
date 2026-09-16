# Emerald Hoenn animation source boundary

`SOURCE-MANIFEST.json` pins the four maintainer-selected Bulbagarden Archives
categories for National-Dex #252-386. The matrix is complete: 135 identities
times normal/Shiny front/back. Form files remain separate from primary rows.

The APNGs under `upstream` and `forms` are source/audit inputs and are excluded
from the release package. `tools/install_emerald_hoenn_animations.py` emits
all 540 primary surfaces as identity-safe runtime frames under
`assets/crystal_animated`. The current registered rows (#252-260 and
#382-385) use them immediately; the other materialized surfaces remain inert
until their species records are registered.

No numeric inference is permitted for occupied private runtime slots #261-279.
National rows #261-279 are staged under the explicit private runtime range
#3261-3279 while keeping their National number in `sourceDex`. The already
registered Azurill #298 and Wynaut #360 correctly retain their existing private
runtime ids #278/#279. Future Hoenn species must still register their species
key, runtime id and `sourceDex` before their materialized art can become a live
game surface.

Run `tests/emerald_hoenn_apng_source_67_test.py` for the complete 135 x 4
source contract and `tests/emerald_hoenn_animation_67_test.py` for the exact
runtime-materialization contract.
