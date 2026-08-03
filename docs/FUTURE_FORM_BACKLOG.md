# Future Form Backlog

These are visual concepts supplied by the project owner for possible later
expansions. They are not implemented, not approved for release and not part
of the official Mega catalog.

The local reference copies live in `art_review/future_forms_max_s/` and are
excluded from the distributable ModKit package. The images visibly credit
“MAX S”, but their original URLs and redistribution permission are currently
unknown. They must not be shipped until source and licensing are documented.

## Saved concepts

| Reference | Proposed form | Concept typing | Current blocker |
|---|---|---|---|
| `01_mega_mew_y_psychic_electric.png` | Mega Mew Y | Psychic/Electric | Fan form; new art and quest required |
| `02_mega_mew_x_psychic_fairy.png` | Mega Mew X | Psychic/Fairy | Fairy battle type is not implemented |
| `03_mega_celebi_y_psychic_grass.png` | Mega Celebi Y | Psychic/Grass | Fan form; new art and quest required |
| `04_mega_celebi_x_psychic.png` | Mega Celebi X | Psychic | Fan form; new art and quest required |
| `05_mega_jirachi_x_steel_fairy.png` | Mega Jirachi X | Steel/Fairy | Jirachi #385 and Fairy are outside current scope |
| `06_mega_jirachi_y_steel_psychic.png` | Mega Jirachi Y | Steel/Psychic | Jirachi #385 is outside the #001–251 Pokédex |

## Type-system status

### Implemented

- **Steel** is a real physical battle type. Its Generation-II effectiveness
  rows, immunities and resistances are registered in `postgame_species.lua`.
  Steelix, Scizor, Skarmory, Forretress, Magnemite and Magneton use it.
- **Dark** is a real special battle type with its Generation-II chart.

### Not implemented

- **Fairy is not currently a battle type.** Occurrences such as
  `SPRITE_FAIRY`, Celebi's party icon or a Pokédex classification are visual
  or descriptive labels, not damage typing.

If Fairy is added later, it should be registered as a special type in this
Gen-I-style engine with an explicit modern matchup table:

- Fairy attacks are strong against Fighting, Dragon and Dark.
- Fairy attacks are resisted by Fire, Poison and Steel.
- Fairy defenders resist Fighting, Bug and Dark.
- Fairy defenders are immune to Dragon.
- Fairy defenders are weak to Poison and Steel.

The implementation decision must also state whether existing #001–251
species receive modern Fairy retcons. Candidates include Cleffa/Clefairy/
Clefable, Igglybuff/Jigglypuff/Wigglytuff, Mr. Mime, Togepi/Togetic,
Marill/Azumarill and Snubbull/Granbull. Adding the type only to future fan
forms would be mechanically possible but inconsistent.

## Suggested eventual roles

- **Mega Mew X – Psychic/Fairy:** flexible support and special bulk.
- **Mega Mew Y – Psychic/Electric:** fast special attacker.
- **Mega Celebi X – Psychic:** defensive time/space specialist that sheds
  Celebi's many Grass weaknesses.
- **Mega Celebi Y – Psychic/Grass:** fast nature-oriented special form.
- **Mega Jirachi X – Steel/Fairy:** bulky wish/support form.
- **Mega Jirachi Y – Steel/Psychic:** offensive classic-typing form.

Every future implementation must follow `docs/MEGA_FORM_PIPELINE.md`, receive
new Crystal-style and four-shade normal/shiny front/back art, and ship with a
story unlock rather than appearing silently in the Stone Case.
