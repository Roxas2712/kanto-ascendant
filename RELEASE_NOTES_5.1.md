# Kanto Ascendant 5.1.1 — Complete Crystal Animation Pack

Kanto Ascendant now bundles the complete animated Pokémon Crystal roster.
Normal and shiny front animations for every Pokémon #001-251 are included
with their original timing. **Crystal Animated Sprites with Shiny Visuals**
remains supported, but is no longer required for Kanto.

## What changed

- Every Kanto and Johto species has bundled normal and shiny Crystal frames.
- `KANTO CRYSTAL ART` independently switches #001-151 between the bundled
  Crystal fronts and the original Gen-I art.
- Original 2D battles animate the opponent and retain the authentic player
  back sprite.
- Dramatic Shape's staged Voxel battles animate both front-facing Pokémon.
- The optional external Crystal mod automatically retains Kanto ownership
  when present, so both controllers never animate the same battler.
- Duplicate shiny presentation is suppressed only where another visual mod
  owns it; Johto keeps Ascendant's sparkle, chime and Shiny Dex behavior.
- Mega Evolution keeps its correct form art even when the Crystal mod is
  enabled.
- A new `CRYSTAL ANIMATION` option can disable the motion while keeping the
  bundled static Crystal art.

Unown remains a static authentic Crystal form-A image because Crystal stores
its letter forms separately and the public source has no generic animated
#201 sheet.

## Compatibility tested

- Kanto Ascendant alone in the original 2D battle layout
- Kanto Ascendant + Dramatic Shape in a staged Voxel battle
- Kanto Ascendant alone with bundled Kanto and Johto animations
- Kanto Ascendant + the LOW-K3YS Voxel fork of Crystal Animated Sprites
- External animated shiny Kanto versus Ascendant animated shiny Johto
- Mega-sprite priority and species-specific shiny-effect ownership
- Red, Blue and Yellow imported-ROM clients

All five ROM-free suites pass **3,996 checks**, and existing Kanto Ascendant
saves remain compatible.

## Installation

Download `kanto-ascendant-5.1.1.zip` and import it through the Gen1 Recomp
launcher. The identical `.modpkg` is provided for launcher versions using
that extension. Do not enable a second mod that registers a complete Johto
species roster.

For Voxel battles, use the compatible visual-mod fork:

https://github.com/LOW-K3YS/crystal_animated_sprites_with_shiny_visuals
