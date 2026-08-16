# Pokémon gender — Phase 6

## Architecture

`pokemon_gender.lua` is the sole owner of Pokémon gender. Its public API is:

```lua
pokemonGender.getMonGender(mon, gameOrData)
pokemonGender.getGenderRatio(mon, gameOrData)
pokemonGender.symbol(mon, gameOrData)
pokemonGender.inspect(mon, gameOrData) -- development diagnostic only
```

`getMonGender` returns `MALE`, `FEMALE`, or `GENDERLESS`. The module is
exported as `kanto_ascendant.pokemonGender`; there is no public gameplay menu
or editable gender value.

## Generation-II calculation

The implementation was verified against
[pret/pokecrystal's `GetGender`](https://github.com/pret/pokecrystal/blob/master/engine/pokemon/mon_stats.asm),
the Crystal disassembly's authoritative routine. `breeding_data.lua` already
contains the canonical 251-species Gen-II female-rate class:

| Stored value | Result |
|---:|---|
| `-1` | genderless |
| `0` | 100% male |
| `1` | 12.5% female |
| `2` | 25% female |
| `4` | 50% female |
| `6` | 75% female |
| `8` | 100% female |

For rate classes 1, 2, 4 and 6, the Pokémon is female exactly when
`Attack DV < femaleRate * 2`; otherwise it is male. This is equivalent to
Crystal's original combined Attack/Speed-DV byte comparison because every
canonical ratio boundary ends in hexadecimal `F`. The result is deterministic
for a species and Attack DV.

## Save and source behavior

Gender is not stored on Pokémon and no migration runs. Existing party and box
Pokémon immediately receive their stable result from their saved DVs. Wild,
starter, gift, trade, static and scripted Pokémon use the same resolver after
their normal constructor/script supplies DVs. A record without an Attack DV is
treated as Attack DV 0, matching the engine's zero-initialized DV behavior;
no second random-generation mechanism exists.

The pre-existing Route 5 Day-Care now calls this central resolver instead of
maintaining its own gender formula. Phase 6 does not change compatibility,
egg creation, inheritance, hatching or any other breeding behavior.

## UI and diagnostics

The existing Gen-I Party, Status, PC and battle-HUD surfaces show a subtle `♂`/`♀` marker
where the original layout has room. Genderless Pokémon show no marker. The
modern storage grid shows the selected Pokémon's marker beside its level.
Long names are never overwritten merely to force a marker.

Nidoran♀ and Nidoran♂ retain their canonical always-female/always-male rate
even when their Attack DV would imply the opposite for a mixed-gender species.
Party and Status views do not append an adjacent duplicate to the glyph already
present in the species name. In battle, Crystal's separate gender cell beside
level/status is retained, so the inherent sex remains independently visible.

Crystal itself has one normal and one Shiny Front/Back picture per species; it
does not provide later-generation male/female sprite variants. Gender changes
rules and presentation markers, not the selected Pokémon picture.

`inspect` provides species, dex number, Attack DV, stored ratio and derived
result to development tools and tests only. It is not connected to a release
gameplay screen.

## Phase 8 status

Final review found no unresolved correctness or save-compatibility defect in
the central resolver. It remains the single gender source for UI and Day-Care;
existing Pokémon acquire the same deterministic result on load without a save
migration. Renderer-backed acceptance additionally covers female, male,
genderless and both Nidoran species in battle.
