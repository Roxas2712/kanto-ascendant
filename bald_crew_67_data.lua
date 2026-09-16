-- Kanto Ascendant 6.7 Youngster Crew roster intake.
--
-- Loaded through bald_crew_67_card.lua. The card's readiness gate keeps the
-- vanilla cave open until the complete roster, reward contract and activation
-- are approved. No placeholder may ever reach a battle.

local MAX_DVS = {
  hp = 15, attack = 15, defense = 15, speed = 15, special = 15,
}

local MAX_STAT_EXP = {
  hp = 65535, attack = 65535, defense = 65535, speed = 65535,
  special = 65535,
}

local D = {
  version = 1,
  ready = true,
  requiredSignatureSpecies = { RAICHU = true, GOROCHU = true },
  opponents = {},
}

D.opponents.omega_dias = {
  id = "omega_dias",
  displayName = "OmegaDIAS",
  sourceLabel = "maintainer screenshots 2026-08-30",
  ready = true,
  team = {
    { species="DRAGONITE", nickname="Drake", level=100,
      moves={"DRAGON_RAGE","SURF","ICE_BEAM","IRON_TAIL"} },
    { species="GENGAR", nickname="Ace", level=100,
      moves={"PSYCHIC_M","GIGA_DRAIN","SHADOW_BALL","THUNDERBOLT"} },
    { species="TYRANITAR", nickname="Harogon", level=100,
      moves={"EARTHQUAKE","ROCK_SLIDE","THRASH","CRUNCH"} },
    { species="CHARIZARD", nickname="LizarDon", level=100,
      moves={"FLAMETHROWER","EARTHQUAKE","DRAGON_RAGE","SLASH"} },
    { species="KINGDRA", nickname="King", level=100,
      moves={"SURF","HYDRO_PUMP","DRAGON_RAGE","ICE_BEAM"} },
    -- The screenshot shows the ordinary species label. Keep nickname nil
    -- until the maintainer confirms that uppercase RAICHU is an actual name.
    { species="RAICHU", nickname=nil, visibleName="RAICHU", level=100,
      moves={"THUNDERBOLT","THUNDER","DOUBLE_TEAM","IRON_TAIL"} },
  },
}

D.opponents.james = {
  id = "james",
  displayName = "James",
  sourceLabel = "maintainer Discord screenshots 2026-08-30",
  ready = true, -- Maintainer explicitly retained the original six on 2026-09-15.
  signatureSpeciesExemption = true, -- Do not replace a personal team member.
  dvs = MAX_DVS,
  statExp = MAX_STAT_EXP,
  team = {
    { species="MEWTWO", nickname="Prometheus", level=100,
      moves={"PSYCHIC_M","BARRIER","AMNESIA","RECOVER"} },
    { species="SUICUNE", nickname="Zephyr", level=100,
      moves={"SURF","BLIZZARD","TOXIC","REST"} },
    { species="ZAPDOS", nickname="Raiden", level=100,
      moves={"THUNDERBOLT","DRILL_PECK","LIGHT_SCREEN","THUNDER_WAVE"} },
    { species="SNORLAX", nickname="Gluttony", level=100,
      moves={"BODY_SLAM","EARTHQUAKE","REST","REFLECT"} },
    { species="TYRANITAR", nickname="Atlas", level=100,
      moves={"EARTHQUAKE","ROCK_SLIDE","CRUNCH","FIRE_BLAST"} },
    { species="DRAGONITE", nickname="Kairyu", level=100,
      moves={"THUNDERBOLT","BLIZZARD","WRAP","THUNDER_WAVE"} },
  },
}

D.opponents.ag64 = {
  id = "ag64",
  displayName = "AG64",
  sourceLabel = "maintainer screenshots 2026-08-30",
  ready = true,
  team = {
    { species="GOLEM", nickname=nil, visibleName="GOLEM", level=100,
      moves={"DIG","EARTHQUAKE","ROCK_THROW","MEGA_PUNCH"} },
    { species="EXEGGUTOR", nickname=nil, visibleName="EXEGGUTOR", level=100,
      moves={"PSYCHIC_M","GIGA_DRAIN","SLUDGE_BOMB","SOLARBEAM"} },
    { species="BLAZIKEN", nickname=nil, visibleName="BLAZIKEN", level=100,
      moves={"SLASH","PECK","DOUBLE_KICK","FIRE_BLAST"} },
    { species="POLITOED", nickname=nil, visibleName="POLITOED", level=100,
      moves={"BUBBLEBEAM","BODY_SLAM","ICE_BEAM","HYDRO_PUMP"} },
    { species="GOROCHU", nickname=nil, visibleName="GOROCHU", level=100,
      moves={"THUNDER","IRON_TAIL","SWIFT","QUICK_ATTACK"} },
    { species="GENGAR", nickname=nil, visibleName="GENGAR", level=100,
      shiny=true,
      moves={"SHADOW_BALL","DREAM_EATER","NIGHT_SHADE","HYPNOSIS"} },
  },
}

D.opponents.tav = {
  id = "tav",
  displayName = "Tav",
  sourceLabel = "maintainer screenshots 2026-08-30",
  ready = true,
  team = {
    { species="GOROCHU", nickname=nil, visibleName="GOROCHU", level=100,
      moves={"THUNDERBOLT","BITE","THUNDER_WAVE","LIGHT_SCREEN"} },
    { species="DRAGONITE", nickname=nil, visibleName="DRAGONITE", level=100,
      moves={"ICE_BEAM","SURF","REFLECT","THUNDERBOLT"} },
    { species="TYRANITAR", nickname=nil, visibleName="TYRANITAR", level=100,
      moves={"EARTHQUAKE","ROCK_SLIDE","BODY_SLAM","CRUNCH"} },
    -- The submitted Scizor deliberately shows only two learned moves.
    { species="SCIZOR", nickname=nil, visibleName="SCIZOR", level=100,
      moves={"SLASH","SWORDS_DANCE"} },
    { species="NIDOKING", nickname=nil, visibleName="NIDOKING", level=100,
      moves={"EARTHQUAKE","DOUBLE_KICK","FIRE_BLAST","SHADOW_BALL"} },
    { species="SKARMORY", nickname=nil, visibleName="SKARMORY", level=100,
      moves={"SWIFT","REST","SKY_ATTACK","IRON_TAIL"} },
  },
}

D.opponents.pandy = {
  id = "pandy",
  displayName = "Pandy", -- Native font has no accented a; identity/key stays unchanged.
  sourceLabel = "maintainer concept plus local proposal 2026-08-31",
  ready = true, -- Maintainer accepted the existing proposal on 2026-09-15.
  secretFinalBoss = true,
  fullRestoreBefore = true,
  lossPolicy = "restart_entire_seven_trainer_run",
  clearCompletedBlocksOnLoss = true,
  restartOpponentIndex = 1,
  developerMegaOverride = {
    enemyActivations = 12,
    playerActivations = 1,
    scope = "this_battle_only",
  },
  dvs = MAX_DVS,
  statExp = MAX_STAT_EXP,
  team = {
    { species="GENGAR", nickname="BREAKPOINT", level=100,
      megaForm="GENGAR", moves={"HYPNOSIS","DREAM_EATER","THUNDERBOLT","EXPLOSION"} },
    { species="SLOWBRO", nickname="DEADLOCK", level=100,
      megaForm="SLOWBRO", moves={"SURF","PSYCHIC_M","AMNESIA","REST"} },
    { species="METAGROSS", nickname="COMPILER", level=100,
      megaForm="METAGROSS", megaKey="form:10076", moves={"METEOR_MASH","EARTHQUAKE","PSYCHIC_M","AGILITY"} },
    { species="RAICHU", nickname="OVERCLOCK", level=100,
      megaForm="RAICHU_Y", moves={"THUNDERBOLT","SURF","THUNDER_WAVE","DOUBLE_TEAM"} },
    { species="MEWTWO", nickname="ROOT", level=100,
      megaForm="MEWTWO_Y", moves={"PSYCHIC_M","BLIZZARD","AMNESIA","RECOVER"} },
    { species="RAYQUAZA", nickname="MAIN", level=100, shiny=true,
      megaForm="RAYQUAZA", megaKey="form:10079", activationKind="dragon_ascent",
      moves={"DRAGON_ASCENT","EXTREMESPEED","EARTHQUAKE","SWORDS_DANCE"} },
  },
}

D.order = { "omega_dias", "james", "chibi_gaming", "tav", "ya_dad", "ag64" }
D.opponents.pandy.phaseTwo = {
  id='pandy',ready=true,dvs=MAX_DVS,statExp=MAX_STAT_EXP,
  sourceLabel='Maintainer-authorized cheat-code reserve, 2026-09-16',
  team={
    {species='KANGASKHAN',nickname='SCRATCHPAD',level=100,megaForm='KANGASKHAN',
      ability='SCRAPPY',item='LIFE_ORB',moves={'FAKE_OUT','DOUBLE_EDGE','EARTHQUAKE','SUCKER_PUNCH'}},
    {species='VENUSAUR',nickname='FIREWALL',level=100,megaForm='VENUSAUR',
      ability='CHLOROPHYLL',item='BLACK_SLUDGE',moves={'GIGA_DRAIN','SLUDGE_BOMB','SLEEP_POWDER','SYNTHESIS'}},
    {species='GYARADOS',nickname='STACKTRACE',level=100,megaForm='GYARADOS',
      ability='INTIMIDATE',item='LEFTOVERS',moves={'DRAGON_DANCE','WATERFALL','CRUNCH','EARTHQUAKE'}},
    {species='ALAKAZAM',nickname='SEGFAULT',level=100,megaForm='ALAKAZAM',
      ability='MAGIC_GUARD',item='FOCUS_SASH',moves={'PSYCHIC_M','FOCUS_BLAST','SHADOW_BALL','ENCORE'}},
    {species='BLAZIKEN',nickname='HOTFIX',level=100,megaForm='BLAZIKEN',
      ability='SPEED_BOOST',item='LIFE_ORB',moves={'PROTECT','SWORDS_DANCE','FLARE_BLITZ','HI_JUMP_KICK'}},
    {species='TYRANITAR',nickname='KERNEL',level=100,megaForm='TYRANITAR',
      ability='SAND_STREAM',item='LEFTOVERS',moves={'DRAGON_DANCE','STONE_EDGE','CRUNCH','EARTHQUAKE'}},
  },
}
D.secretFinalOpponent = "pandy"

-- Personal submissions remain authoritative; absent teams are never invented.
D.opponents.chibi_gaming = {
  id="chibi_gaming", displayName="Chibi Gaming", ready=true,
  sourceLabel="six maintainer screenshots; confirmed Chibi attribution 2026-09-15",
  team={
    {species="TYPHLOSION", nickname="Lavia", gender="female", level=100,
      moves={"FLAMETHROWER","FLAME_WHEEL","EARTHQUAKE","BLAST_BURN"}},
    {species="ESPEON", nickname="Espy", gender="male", level=100,
      moves={"PSYBEAM","DOUBLE_TEAM","SWIFT","PSYCHIC_M"}},
    {species="VENUSAUR", nickname="Rose", gender="male", level=100,
      moves={"RAZOR_LEAF","SLEEP_POWDER","GIGA_DRAIN","FRENZY_PLANT"}},
    {species="ARTICUNO", nickname="Arctic", level=100,
      moves={"ICE_BEAM","BLIZZARD","AGILITY","REST"}},
    {species="GOROCHU", nickname="Elrina", level=100,
      moves={"THUNDERBOLT","BODY_SLAM","THUNDER","THUNDER_WAVE"}},
    {species="BLASTOISE", nickname="Aqua", gender="male", level=100,
      moves={"SURF","EARTHQUAKE","ICE_BEAM","HYDRO_CANNON"}},
  },
}
D.opponents.ya_dad = {
  id="ya_dad", displayName="Ya Dad", ready=true, signatureSpeciesExemption=true,
  sourceLabel="maintainer party screenshot 2026-09-16; max training and optimized sets requested",
  dvs=MAX_DVS, statExp=MAX_STAT_EXP,
  -- Family/order and the four visible sexes come from the submission.
  -- Levels, training, abilities, items and moves below are an authored build.
  -- Follow-up explicitly requests full evolution, including KASC's Gorochu.
  team={
    {species="VENUSAUR",gender="male",level=100,ability="OVERGROW",item="BLACK_SLUDGE",
      moves={"GIGA_DRAIN","SLUDGE_BOMB","SLEEP_POWDER","SYNTHESIS"}},
    {species="MEW",level=100,ability="SYNCHRONIZE",item="LEFTOVERS",
      moves={"PSYCHIC_M","AURA_SPHERE","CALM_MIND","SOFTBOILED"}},
    {species="BLASTOISE",gender="female",level=100,ability="TORRENT",item="LEFTOVERS",
      moves={"SCALD","ICE_BEAM","AURA_SPHERE","DARK_PULSE"}},
    {species="GOROCHU",gender="female",level=100,ability="STATIC",item="LIFE_ORB",
      moves={"THUNDERBOLT","GRASS_KNOT","KNOCK_OFF","BRICK_BREAK"}},
    {species="CHARIZARD",level=100,ability="BLAZE",item="LIFE_ORB",
      moves={"FLAMETHROWER","AIR_SLASH","DRAGON_PULSE","ROOST"}},
    {species="UMBREON",gender="male",level=100,ability="SYNCHRONIZE",item="LEFTOVERS",
      moves={"FOUL_PLAY","PSYCHIC_M","WISH","PROTECT"}},
  },
}
-- Preserve the authored strengthening without misattributing or activating it.
-- This proposal is outside opponents and cannot become a battle roster.
D.unassignedStrengthenedProposal = {
  ready=false,
  sourceLabel="authored adaptation of Chibi screenshots; trainer assignment unresolved",
  -- The maintainer explicitly requested a strong adaptation. Species and
  -- nicknames stay personal; max training and the move changes are authored,
  -- not claimed to have been read from the screenshots.
  dvs=MAX_DVS, statExp=MAX_STAT_EXP,
  team={
    {species="TYPHLOSION", nickname="Lavia", gender="female", level=100,
      moves={"FLAMETHROWER","THUNDERPUNCH","EARTHQUAKE","BLAST_BURN"}},
    {species="ESPEON", nickname="Espy", gender="male", level=100,
      moves={"PSYCHIC_M","CALM_MIND","SHADOW_BALL","MORNING_SUN"}},
    {species="VENUSAUR", nickname="Rose", gender="male", level=100,
      moves={"SLEEP_POWDER","GIGA_DRAIN","SLUDGE_BOMB","FRENZY_PLANT"}},
    {species="ARTICUNO", nickname="Arctic", level=100,
      moves={"ICE_BEAM","REFLECT","TOXIC","REST"}},
    {species="GOROCHU", nickname="Elrina", level=100,
      moves={"THUNDERBOLT","BODY_SLAM","FLAMETHROWER","THUNDER_WAVE"}},
    {species="BLASTOISE", nickname="Aqua", gender="male", level=100,
      moves={"SURF","EARTHQUAKE","ICE_BEAM","HYDRO_CANNON"}},
  },
}
D.opponents.fabelle_moon = { id="fabelle_moon", displayName="FabelleMoon",
  gender="female", trainerClass="KA_BALD_CREW_FEMALE", sprite="SPRITE_KA_BALD_CREW_FEMALE",
  characterArt="bald_crew_female_v1", ready=true,
  sourceLabel="maintainer Fabelle Moon team image 2026-09-16; strong build explicitly requested",
  signatureSpeciesExemption=true, -- Her Pikachu must not be replaced by Raichu/Gorochu.
  dvs=MAX_DVS, statExp=MAX_STAT_EXP,
  -- Authored strategy, not stats/items/moves claimed to be visible in the image.
  -- These are the full Gen-VI/VII sets. The eventual encounter adapter must
  -- use the active generation's learnset/item/ability rules, never force an epoch.
  team={
    {species="BUTTERFREE",level=100,ability="COMPOUND_EYES",item="FOCUS_SASH",
      moves={"SLEEP_POWDER","QUIVER_DANCE","BUG_BUZZ","GIGA_DRAIN"}},
    {species="VAPOREON",level=100,ability="WATER_ABSORB",item="LEFTOVERS",
      moves={"SCALD","ICE_BEAM","WISH","PROTECT"}},
    {species="NOCTOWL",level=100,ability="TINTED_LENS",item="LEFTOVERS",
      moves={"AIR_SLASH","HYPER_VOICE","PSYCHIC_M","ROOST"}},
    {species="RAPIDASH",level=100,ability="FLASH_FIRE",item="LIFE_ORB",
      moves={"FLARE_BLITZ","DRILL_RUN","MEGAHORN","WILD_CHARGE"}},
    {species="NINETALES",level=100,ability="FLASH_FIRE",item="LIFE_ORB",
      moves={"NASTY_PLOT","FLAMETHROWER","ENERGY_BALL","DARK_PULSE"}},
    {species="PIKACHU",level=100,ability="STATIC",item="LIGHT_BALL",
      moves={"FAKE_OUT","THUNDERBOLT","GRASS_KNOT","ENCORE"}},
  } }
D.order = { "omega_dias", "chibi_gaming", "tav", "ya_dad", "ag64", "james", "fabelle_moon", "pandy" }
-- Fabelle belongs to the second endurance block; only Pandy starts fresh.
D.blocks = { 1, 1, 1, 4, 4, 4, 4, 8 }
for _,id in ipairs(D.order)do
  local row=D.opponents[id]
  if row.gender~='female'then
    row.trainerClass='KA_BALD_CREW_'..id:upper()
    row.sprite='SPRITE_KA_BALD_CREW_MALE'
  end
end
D.instance = { map="KA_BALD_CREW_MT_MOON_1F", index=1995,
  host="MT_MOON_1F", entrance="ROUTE_4", entry={14,34}, requiredItem="HM_FLY",
  returnPoint={18,6}, rearReturnPoint={24,6}, frontDoor={18,5},rearDoor={24,5},
  restartPoint={16,6},
  sealedStockMaps={MT_MOON_1F=true,MT_MOON_B1F=true,MT_MOON_B2F=true} }
D.activation={approved=true,kind="champion_steps_item",item="HM_FLY",steps=134}
D.rewardContract={approved=true,id="bald-crew-20260916-pikachu-v1",
  items={{item="MASTER_BALL",qty=7},{item="LATIASITE",qty=1},{item="LATIOSITE",qty=1}},
  choices={{id="shiny_pikachu",species="PIKACHU",level=50,shiny=true}},
  card="bald_crew_champion",title="bald_crew_secret_boss"}
return D
