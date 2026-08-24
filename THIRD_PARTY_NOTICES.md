# Third-Party Notices

## Pokémon Crystal Johto Masters music data

The chip-music event data for the Johto Masters Indigo Plateau map theme and
Rival battle theme is reproducibly transcribed from the local
`pret/pokecrystal` disassembly at revision
`8e8f7e20052a596371a77022f0392c285e51bbf1`:

https://github.com/pret/pokecrystal

The build consumes `audio/music/indigoplateau.asm`,
`audio/music/rivalbattle.asm`, `audio/drumkits.asm`, and
`audio/wave_samples.asm`. It emits Game Boy chip-program data only; no PCM or
OGG recording is bundled. Pokémon music is © Nintendo / Creatures Inc. /
GAME FREAK inc. and is used only in this unofficial, non-commercial fan mod.

## Pokémon Crystal battle sprites

The bundled normal and shiny front/back battle sprites for Johto Pokémon
#152-251 are the Pokémon Crystal sprite set distributed through Pokémon
Database:

https://pokemondb.net/sprites

Pokémon and Pokémon character names are trademarks of Nintendo, Creatures
Inc. and GAME FREAK inc. Kanto Ascendant is an unofficial, non-commercial fan
mod and is not affiliated with or endorsed by them.

The bundled normal and shiny Kanto #001-151 back sprites are the Pokémon
Crystal set mirrored by the PokeAPI sprites repository:

https://github.com/PokeAPI/sprites

## Pokémon legacy cries

The bundled OGG cries for Johto Pokémon #152-251 come from the PokéAPI cries
repository's legacy set:

https://github.com/PokeAPI/cries

That repository is distributed under CC0 1.0 Universal and states that the
audio content is Copyright The Pokémon Company. Kanto Ascendant uses the
files only in this unofficial, non-commercial fan mod.

The same PokeAPI legacy-cry source supplies the nine narrowly registered
species cries #252-260 bundled for Kanto Ascendant's authored content.

## Bundled species sprites #252-260

The normal/shiny front and back battle sprites for species #252-260 come from
the PokeAPI sprites repository's Ruby/Sapphire set:

https://github.com/PokeAPI/sprites

Only these nine species are registered. No Hoenn region, encounter table or
intermediate National-Dex catalogue is bundled or implied.

## Targeted later-evolution compatibility set

The normal/shiny front and back sprites for Kanto Ascendant's narrowly
registered private entries #261-279 and their legacy cries are sourced from
the public PokeAPI sprite and cry mirrors:

https://github.com/PokeAPI/sprites

https://github.com/PokeAPI/cries

This set contains only seventeen later evolutions of existing Kanto/Johto
families plus Azurill and Wynaut. It does not include a Sinnoh region or a
general Generation-IV encounter catalogue.

Their canonical HGSS level-up and personal data are generated from the
`pret/pokeheartgold` disassembly at revision
`a37967ab0fb35b74b51c5ea33e272ca872697344`:

https://github.com/pret/pokeheartgold

## Pokémon Crystal animated sprites

The bundled normal and shiny front-animation frames for all Pokémon #001-251
are generated from the Pokémon Crystal GIF mirrors maintained in the PokeAPI
sprites repository:

https://github.com/PokeAPI/sprites

The numbered-frame and timing integration is compatible with **Crystal
Animated Sprites with Shiny Visuals** and its Voxel fork:

https://github.com/distilledorion-sketch/crystal_animated_sprites_with_shiny_visuals

https://github.com/LOW-K3YS/crystal_animated_sprites_with_shiny_visuals

Unown uses the bundled static Crystal form-A image because the source mirrors
do not provide a generic animated #201 GIF.

### Authored private-slot Crystal motion (#252-279)

Twenty-one of Ascendant's twenty-eight registered private catalogue species
have normal/shiny front-animation poses from the pokecrystal-ready
Crystal-style packs authored by **Nuuk**. Ambipom, Mismagius, Lickilicky,
Rhyperior, Tangrowth, Yanmega and Wynaut use their exact authored sprite sheets,
palettes and `anim.asm` scripts from **Pokémon Polished Crystal**, pinned to
source commit `4a440ffdecd821ae1b724d6df88280a3f89f158d`. In both source formats the
scripts determine the exact pose order and timing; Ascendant does not
manufacture motion by shifting or deforming a still image. Supplied rear art
contains one pose and therefore remains intentionally static.

Private slot numbers are never treated as National-Dex identities: for
example, slot #263 is Honchkrow (source Dex #430), not Zigzagoon. The source
pack states that the sprites are free to use or edit, must not be used for
profit, and must not be claimed as one's own. Kanto Ascendant is a
non-commercial fan mod. Source-author links supplied with the pack:

https://www.deviantart.com/nuukiie

https://twitter.com/nuukiie

Polished Crystal source and its authoritative contributor credits:

https://github.com/Rangi42/polishedcrystal

https://github.com/Rangi42/polishedcrystal/blob/4a440ffdecd821ae1b724d6df88280a3f89f158d/CREDITS.md

The source credits explicitly identify Scarlax for Ambipom and Rhyperior
animation work, bloodless with SoupPotato for Mismagius, EeveeEe1999 for
Lickilicky animation work, and additional project contributors for the source
sprite catalogue. The pinned repository does not contain a top-level license
file; this non-commercial fan mod therefore preserves the upstream project and
artist attribution without claiming ownership or a broader license grant.

## Mega-form battle sprites

The bundled 96×96 normal/shiny front/back masters for all 30 supported
official Mega forms come from the PokeAPI sprites repository:

https://github.com/PokeAPI/sprites

The repository mirrors the recognizable Gen-V-style Pokémon Showdown/Smogon
sprite set. Kanto Ascendant preserves each master without interpolation and
builds side-aware idle loops using integer-pixel movement only.

Three authored Mega forms use the supplied four-view normal/shiny PokeAPI
masters from the fixed `PokeAPI/sprites` source commit
`c10459b...` (front/back, normal/shiny). They are retained as static approved
poses: no unlicensed or fabricated animation frames were added. Pokémon and
Pokémon character artwork are © Nintendo / Creatures Inc. / GAME FREAK inc.;
PokeAPI is credited solely as the source mirror.

The twelve copied masters were checked byte-for-byte against the supplied
source bundle. Their SHA-256 values are: form A front
`f920703c485165c83bd5d52c637554789ab0e46967719d76170794e1d4ab9ea0`, back
`16b2e0875a6816c4d684bd574c1eb9fa7d1f9368a7fec87c4d2ee30d3e29e5f7`, shiny
front `7aff84f61953aaff1040f0492244875b585d301f88ad87091c4abd9dd391f2dc`
and shiny back `749a748794a6dee6b4972685953438879bf86823e18ef6729f4506b1794acf31`;
form B front `256aa57db96b64309c046aafd8444908e1c3fcf13a9e50e8d36512a37327e255`,
back `27af96a91224f07ef30577797aebf0e85de87747647a90250deb9d0662b9fd7a`,
shiny front `74131a04d43ad1a9629b9ebb183e0316be3058a2c2a4a512ed0e4c6cde30cbab`
and shiny back `9fcce75883ee180f6ec54a8f64039ada8ee224c20aa4f8e00e60b11ac4c0afea`;
form C front `3d89edb7a293dc97ea1ce6e9b6f79d08d6a3751fe30a6ab2ac868bd3a9bdeb5c`,
back `057ca4fd7472b0206ce87c8a600b1017b759873ff29a6e4cf4031217abfee2f2`,
shiny front `8952862af30f83bf949e159c4586b6fef18d912b8dcb99f1442e20b1a91a15fe`
and shiny back `a8288eb726c12a836d10040f4bd267f25f94acac9d8facc2ea19b86c8c3b4062`.

Ascendant Typhlosion is an original Kanto Ascendant fan design. Its front
flame movement is derived from the bundled Pokémon Crystal #157 animation and
timing described above.

## Yellow Jessie, James, and Meowth staged battle art

The Yellow-only staged opponent picture showing Jessie, James, and Meowth is
fan art derived from one OpenAI ImageGen RGBA output selected and explicitly
approved by the Kanto Ascendant maintainer on 2026-08-20. The exact source
artifact is `exec-37308b82-3890-4a98-beea-d7279431bfa7`, SHA-256
`8d4b4af1515b304cb6b1121bceb00078b142706558e589790d6dca5ce137736a`.
The source-only master is excluded from launcher packages. The independently
rendered 64px and 128px runtime surfaces, their full hashes, direct-transform
recipes and the dated approval receipt are documented in the shipped
`assets/yellow_jessie_james/PROVENANCE.json`.

This project-level visual approval is not a claim of ownership or a broader
distribution-rights grant for the underlying Pokémon characters. The art is
used only in this unofficial, non-commercial fan project. If its sealed
runtime authority is unavailable, Kanto Ascendant uses the separately
credited bundled Yellow duo picture or the player's ROM-derived native Yellow
picture; it never substitutes a generic Rocket character as that identity.

## Gorochu guest species

Gorochu is based on the discarded Raichu evolution described by Pokémon
designer Atsuko Nishida: a thunder-god-like creature with horns and fangs.
No official complete sprite, statistics or evolution method is known.

https://www.pokemon.com/us/pokemon-news/creator-profile-the-creators-of-pikachu

Kanto Ascendant's battle sprites, shiny palette, follower, expressions,
statistics, Pokédex prose and Storm Bond evolution are an original
non-commercial fan interpretation created for this project. They are not
official Game Freak assets or canon data.

## Wilds of Kanto 1.12.2

Kanto Ascendant bundles a scoped copy of the spawn, ambient-town, renderer
and behaviour core from **Wilds of Kanto / Overworld Spawn Mod 1.12.2**:

https://github.com/YoDrehDenSwagAuf/overworld-spawn-mod/releases/tag/v1.12.2

The standalone mod's follower controller and settings menus are not started;
Kanto Ascendant retains ownership of those surfaces. The upstream MIT license
and its third-party asset notices are shipped unchanged in
`vendor/wilds_1_12_2/LICENSE` and
`vendor/wilds_1_12_2/THIRD_PARTY_NOTICES.md`.

## PokeWilds follower sprites

The bundled normal and shiny six-pose Johto overworld sheets are sourced from
the PokeWilds project:

https://github.com/SheerSt/pokewilds

Kanto Ascendant converts the sheets into Gen1 Recomp's follower layout at
runtime and uses the same derived images for the 2D and voxel renderers.
Unown is derived from its bundled Crystal art because the source project does
not provide the same six-pose sheet for it.

## Crystal Clear Kanto follower sprites

The bundled six-pose Kanto #001-151 overworld sheets were adapted from
PokéPC Followers:

https://github.com/gamecorner-033/PokePCFollowers

That project credits ShockSlayer and the makers of Pokémon Crystal Clear for
the Gen-I/II follower artwork. The source repository does not publish a
separate software or art license; Kanto Ascendant therefore records the exact
provenance and uses the sheets only in this unofficial, non-commercial fan
mod. No PokéPC code or runtime dependency is bundled.

The #001-151 shiny follower variants retain those exact six-pose silhouettes
and are deterministic palette derivatives. Their two authored colour roles are
matched to the corresponding normal palette indices from Pokémon Crystal and
replaced with the same species' shiny indices from `pret/pokecrystal`, pinned
to commit `7a7881d0d62e0ddbd82dcf10e7116807487ac651`. Transparency, black pixels,
geometry and animation frames remain unchanged; the complete per-species
mapping and input/output hashes ship in
`assets/followers_kanto/shiny/palette_contract.json`.

Follower EX was evaluated as an integration/reference target, but no
Followers EX source code, package or artwork is bundled. Kanto Ascendant's
native follower controller and registry work without that mod, and the two
runtime controllers are now declared incompatible to prevent overlapping
hooks.

Gorochu's six-pose normal and shiny walkers are Kanto Ascendant adaptations
of the bundled PokéPC/Crystal Clear Raichu sheet. They retain the Raichu gait
and grounding while adding Gorochu-specific palettes, horn and markings, so
the same provenance and non-commercial-use caution apply to those derivatives.

## Crystal Animated Sprites with Shiny Visuals v1.5

The grayscale Crystal front animations, Kanto normal/shiny/grayscale back
sprites, trainer/player portraits and Tower Ghost presentation assets are
derived from release `v1.5` of **Crystal Animated Sprites with Shiny Visuals**:

https://github.com/distilledorion-sketch/crystal_animated_sprites_with_shiny_visuals/releases/tag/v1.5

The reproducible import is pinned to Git commit
`9d48cc921da4db88043cb2a14e9f8803aefffad7`; its exact file-level record is
packaged as `assets/crystal_v15/provenance.json`. The upstream repository does
not publish a separate license. Pokémon character artwork remains copyright
of its respective owners and is used only in this unofficial, non-commercial
fan project.

Kanto Ascendant does not replace its existing normal/shiny #001-251 animation
pack, party/follower sheets, shiny reveal, Mega forms or Voxel compatibility.
The v1.5 material is an additive presentation layer and yields to the external
Crystal mod when that package is active.

## Pokémon FireRed / LeafGreen PC interface atlas

The FireRed / LeafGreen PC skin samples the unmodified `PC Interface` sheet
published by The Spriters Resource:

https://www.spriters-resource.com/game_boy_advance/pokemonfireredleafgreen/asset/3861/

The source page names `yoursavior` as uploader and `fabnt` as contributor; the
sheet itself states that credit is not required. Kanto Ascendant nevertheless
retains those names, the source URL and the exact source hash in
`assets/ui/frlg_pc/PROVENANCE.md`. Runtime nearest-neighbour quads select the
terminal patterns and twelve Box wallpapers; the atlas is not repainted or
split into derivative files.

## Pokémon FireRed / LeafGreen Bag UI sheet

The FireRed Bag samples the maintainer-supplied, unmodified 704×560
`assets/bag-ui-sheet.png`. The local source did not include an original page,
uploader, contributor or separate license, so Kanto Ascendant makes no further
attribution or ownership claim. Its exact hash and treatment are recorded in
`assets/BAG_UI_PROVENANCE.md`; a missing sheet falls back to code-drawn shapes.

Pokémon FireRed / LeafGreen and the original game artwork remain copyright of
their respective rights holders. These assets are used only in this
unofficial, non-commercial fan project.

## Kanto Ascendant trainer pictures

Public packages do not contain the native FireRed/LeafGreen trainer-front PNGs.
The 42 compact Kanto opponent cards remain the edition-original Gen-I pictures
generated from the user's own ROM. Red's compact player front likewise uses the
ROM-derived Gen-I image.

Red, Blue and Casey's five-frame 64×64 upper-body throws, Blue and Casey's
project fronts, the approved Kanto opponent Voxel redraws and the three 128×128
Voxel standing pictures are Kanto Ascendant adaptations. They remain separate
from the native 2D fallback and are not removed by that fallback.

## Pokémon Channel Raichu voice clips

The seven short partner-Raichu reactions are one-bit mono derivatives of
Raichu voice clips from Pokémon Channel, using this compilation as the source:

https://www.youtube.com/watch?v=H-jbBEdY47E

The source video was published by NintendoTV64 and credits the voice
performance to Urara Takano. Pokémon Channel and the original audio are
copyright Nintendo. Kanto Ascendant uses the derived clips only in this
unofficial, non-commercial fan mod and does not redistribute the full source
recording.

## All Pokémon Catchable 151 Mod

Kanto Ascendant's version-independent encounter planning was informed by
**All Pokémon Catchable 151 Mod** by Wowabox (Darklinkduck). Kanto Ascendant's
implementation adds its own modes, reward path, missing Bulbasaur path, safe
storage handling and authored Mew-event compatibility.

MIT License

Copyright (c) 2026 Wowabox (Darklinkduck)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
