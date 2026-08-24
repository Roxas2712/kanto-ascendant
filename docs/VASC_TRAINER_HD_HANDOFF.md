# KASC HD trainer handoff for VASC

Kanto Ascendant owns trainer identity and the authored combat-front assets.
Voxel Ascendant owns the staged renderer. Neither package may require or load
the other's private files.

## Public boundary

KASC discovers VASC through the runtime mod handle and validates its public
export in `voxel_renderer_compat.lua`. The only trainer source boundary is:

```lua
local overworld = vasc.lib.require("OverworldBattle")
local texture = overworld.sideTexture(battle, side)
```

`lib` must remain a closed public facade. `OverworldBattle.sideTexture` must be
a function. KASC may replace that public function with a wrapper and retain the
renderer-owned function as its delegate; VASC must not import KASC or call a
KASC-private resolver.

VASC may recreate `sideTexture` during its own lifecycle. KASC 6.5.17 records
the exact installed wrapper in
`OverworldBattle.__kantoAscendantApprovedTrainerRelay` and rebinds on
`save.loaded` when the live function identity no longer matches. The boolean
`__ascendantStandingTrainerMirror` is compatibility metadata, not proof that
the wrapper is still active.

## Texture contract

For an authored HD trainer KASC returns the normal public side-texture shape
plus these metadata fields:

- `canvas`: 320 by 288 pixels for a 128px source (`dpiscale = 1`)
- `ax`, `ay`: anchor coordinates in the renderer's original 160 by 144 space
- `trainer`: enemy/native-trainer role marker
- `ascendantHighResTrainer = true`
- `ascendantTrainerSourceScale = 2`
- `ascendantHighResSource`: packaged KASC HD asset path
- `ascendantStandingTrainer`: stable KASC identity
- `ascendantApprovedTrainerResolver`: inspectable ownership receipt

VASC must preserve the logical 160 by 144 card size while sampling the 2x
canvas, keep nearest filtering and use the supplied anchor. It must not first
rasterize the engine's 64px `trainerPic` when
`ascendantHighResTrainer == true`.

The 64px KASC siblings remain intentionally packaged for native 2D and safe
fallback presentation. Deleting them is not part of the VASC contract; staged
combat must select the authored `_hd` source through the public wrapper.

## Acceptance tests

From a compatible Gen1 Recomp checkout with LuaJIT:

```sh
TRAINER_REMATCH_MOD_DIR=/path/to/kanto-ascendant \
VOXEL_ASCENDANT_MOD_DIR=/path/to/voxel-ascendant \
luajit /path/to/kanto-ascendant/tests/vasc_2x_trainer_hd_rebind_test.lua
```

The test loads both public packages, replaces VASC's live `sideTexture` while
leaving the historical marker intact, emits `save.loaded`, and verifies that
Bird Keeper again resolves
`bird_keeper_voxel_front_hd_v2.png` with a 2x texture instead of delegating to
the recreated low-resolution source.

The Legacy Bank and FireRed organizer changes are independently covered by
`tests/legacy_journey_test.lua` and `tests/frlg_pc_interface_test.lua`.
