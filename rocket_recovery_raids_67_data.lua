-- Kanto Ascendant 6.7 Rocket recovery raid contract.
-- Later HMs are intentionally absent: in this project WATERFALL and other
-- later field-labelled moves are battle attacks only, never map keys.

return {
  schema = "kanto-ascendant-rocket-raids-data/v1",
  instances = {
    { id="celadon_relay", map="KA_ROCKET_SILPH_RELAY_1F", fights=3,
      hostMap="SILPH_CO_1F", entrance="SILPH_CO_1F",
      location={en="SILPH CO. RELAY",de="SILPH-CO.-RELAIS"},
      lead="JESSIE_JAMES_MEOWTH", card="rocket_raid_jessie_james" },
    { id="lavender_relay", map="KA_ROCKET_TOWER_RELAY_1F", fights=3,
      hostMap="POKEMON_TOWER_1F", entrance="POKEMON_TOWER_1F",
      location={en="POKEMON TOWER RELAY",de="POKÉMON-TURM-RELAIS"},
      lead="JESSIE_JAMES_MEOWTH", card="rocket_raid_meowth" },
    { id="cerulean_relay", map="KA_ROCKET_CERULEAN_RELAY_1F", fights=4,
      hostMap="CERULEAN_CAVE_1F", entrance="CERULEAN_CAVE_1F",
      location={en="CERULEAN CAVE RELAY",de="AZURIA-HÖHLENRELAIS"},
      lead="JESSIE_JAMES_MEOWTH", card="rocket_raid_executive" },
    { id="viridian_command", map="KA_ROCKET_SILPH_COMMAND_1F", fights=4,
      hostMap="SILPH_CO_1F", entrance="SILPH_CO_1F",
      location={en="SILPH CO. COMMAND RAID",de="SILPH-CO.-KOMMANDORAID"},
      lead="GIOVANNI", card="rocket_raid_giovanni" },
  },
  -- These are authored capture leads, not direct Box gifts. Runtime may only
  -- activate a row after its complete species/assets/encounter contract is
  -- registered; otherwise the ordinary raid roster remains playable.
  contraband = {
    { key="darkrai_dream", species="DARKRAI", originEpoch=4,
      level=70, instance="lavender_relay", mode="post_raid_encounter" },
    { key="genesect_project", species="GENESECT", originEpoch=5,
      level=70, instance="cerulean_relay", mode="post_raid_encounter" },
    { key="regigigas_power", species="REGIGIGAS", originEpoch=4,
      level=75, instance="viridian_command", mode="giovanni_then_encounter" },
    { key="zygarde_cells", species="ZYGARDE_10", originEpoch=6,
      level=70,
      instances={"celadon_relay","lavender_relay","cerulean_relay",
        "viridian_command"}, mode="four_cell_encounter" },
  },
  moveRewards = {
    { epoch=1, move="SWORDS_DANCE", item="TM_SWORDS_DANCE", number=3, delivery="tm" },
    { epoch=1, move="FIRE_BLAST", item="TM_FIRE_BLAST", number=38, delivery="tm" },
    { epoch=1, move="THUNDER", item="TM_THUNDER", number=25, delivery="tm" },
    { epoch=2, move="THIEF", item="TM_THIEF", number=46, delivery="tm" },
    { epoch=2, move="SHADOW_BALL", item="TM_SHADOW_BALL", number=30, delivery="tm" },
    { epoch=2, move="IRON_TAIL", item="TM_IRON_TAIL", number=23, delivery="tm" },
    { epoch=3, move="OVERHEAT", item="TM_OVERHEAT", number=50, delivery="tm" },
    { epoch=3, move="AERIAL_ACE", item="TM_AERIAL_ACE", number=40, delivery="tm" },
    { epoch=3, move="BULK_UP", item="TM_BULK_UP", number=8, delivery="tm" },
    { epoch=4, move="DARK_PULSE", item="TM_DARK_PULSE", number=79, delivery="tm" },
    { epoch=4, move="X_SCISSOR", item="TM_X_SCISSOR", number=81, delivery="tm" },
    { epoch=4, move="U_TURN", item="TM_U_TURN", number=89, delivery="tm" },
    { epoch=5, move="VOLT_SWITCH", item="TM_VOLT_SWITCH", number=72, delivery="tm" },
    { epoch=6, move="DAZZLING_GLEAM", item="TM_DAZZLING_GLEAM", number=99, delivery="tm" },
  },
  forbiddenFieldRewards = {
    CUT=true, FLY=true, SURF=true, STRENGTH=true, FLASH=true,
    WHIRLPOOL=true, WATERFALL=true, ROCK_SMASH=true, DIVE=true,
    ROCK_CLIMB=true, DEFOG=true,
  },
}
