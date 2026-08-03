-- Trainer Rematch headless suite. Run from the engine checkout:
--   POKEPORT_DATA_DIR=tests/fixture_data luajit mods/trainer_rematch/tests/trainer_rematch_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = T.fixtures.load()

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/trainer_rematch"
local run = T.sdk.loadMod(modPath, { data = Data })
T.eq(#run.errors, 0, "loads clean")
T.eq(run.mod.manifest.name, "Kanto Ascendant",
  "the full expansion uses its new visible name")
T.eq(run.mod.manifest.id, "trainer_rematch",
  "the stable internal id preserves existing save data")
local ex = run.loader.exports.trainer_rematch
T.neq(ex, nil, "exports reachable")

-- ------------------------------------------------ optional Crystal art seam

T.neq(ex.crystalSprites, nil, "Crystal availability is exported")
T.neq(ex.crystalShinySprites, nil,
  "Crystal shiny availability is exported independently")
local RealRuntime = require("src.mods.Runtime")
local crystalCtx = { species = "RAIKOU", side = "front", trueColor = false }
local crystalPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_front.png", crystalCtx)
if ex.crystalSprites.RAIKOU then
  T.eq(crystalPath:find("assets/crystal/raikou_front.png", 1, true) ~= nil, true,
    "an installed Crystal front sprite is selected")
  T.eq(crystalCtx.trueColor, true, "Crystal art keeps its GBC colors")
else
  T.eq(crystalPath, "fallback_front.png",
    "missing Crystal art automatically uses the original fallback")
end
local crystalShinyMon = {
  species = "RAIKOU",
  dvs = { attack = 10, defense = 10, speed = 10, special = 10, hp = 0 },
}
local crystalShinyCtx = {
  species = "RAIKOU", side = "front", trueColor = false,
  mon = crystalShinyMon,
}
local crystalShinyPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_front.png", crystalShinyCtx)
if ex.crystalShinySprites.RAIKOU then
  T.eq(crystalShinyPath:find(
      "assets/crystal/raikou_front_shiny.png", 1, true) ~= nil, true,
    "a shiny Johto mon selects Crystal's real shiny sprite")
  T.eq(crystalShinyCtx.trueColor, true,
    "the official shiny Crystal palette is kept in true color")
end
run.loader.modOptions.trainer_rematch = { legend_art = "original" }
local originalCtx = { species = "RAIKOU", side = "back", trueColor = false }
local originalPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_back.png", originalCtx)
T.eq(originalPath, "fallback_back.png",
  "the LEGEND ART option can force the original sprite")
T.eq(originalCtx.trueColor, false,
  "the original four-shade sprite stays palette-aware")
run.loader.modOptions.trainer_rematch = nil
T.neq(ex.spriteAssets, nil,
  "sprite preparation for transparent battle and follower art is exported")
T.same(ex.spriteAssets.followerOrder, { 4, 2, 0, 5, 3, 1 },
  "PokeWilds poses map to Gen1 Recomp's down/up/side frame order")
local voxelCtx = {
  species = "RAIKOU", side = "back", trueColor = false,
  data = { pokemon = { RAIKOU = { spriteFront = "voxel_front.png" } } },
}
local voxelPath = RealRuntime.call("pokemon.sprite",
  function() return "voxel_front.png" end, "fallback_back.png", voxelCtx)
if ex.crystalSprites.RAIKOU then
  T.eq(voxelPath:find("assets/crystal/raikou_front.png", 1, true) ~= nil, true,
    "voxel battles preserve Dramatic Shape's front-facing player sprite")
end

local optionRows = {}
for _, row in ipairs(run.loader.optionSchemas.trainer_rematch or {}) do
  optionRows[row.key] = row
end
T.eq(optionRows.language.type, "choice",
  "language can be selected as AUTO, ENGLISH or DEUTSCH")
T.eq(optionRows.team_growth.type, "toggle",
  "class-appropriate party recruitment can be switched off")
T.eq(optionRows.loot_mode.type, "choice",
  "rare rematch loot has OFF, BALANCED and GENEROUS modes")
T.eq(optionRows.rest_min.min, 151,
  "the configurable rematch range starts at Kanto's full Pokédex count")
T.eq(optionRows.rest_max.max, 2510,
  "the configurable rematch range reaches the complete 251 roster times ten")
T.eq(optionRows.kanto_151.type, "choice",
  "all 151 Kanto species support reward, wild and off modes")
T.eq(optionRows.kanto_151.default, "ascendant",
  "Kanto completion defaults to authored rewards instead of random starters")
T.eq(optionRows.kanto_151.label:find("RESTART", 1, true) ~= nil, true,
  "the content-patching KANTO 151 option visibly warns that it needs a restart")
T.eq(optionRows.legend_articuno.type, "choice",
  "Articuno has its own APEX/VANILLA/OFF option")
T.eq(optionRows.shiny_hunts.type, "choice",
  "shiny hunting can use Ascendant boosts or natural 1/8192 odds")
T.eq(optionRows.shiny_effects.type, "toggle",
  "built-in shiny presentation can be switched off")
T.eq(optionRows.shiny_protection.type, "toggle",
  "shiny Pokémon can be protected from accidental PC release")
T.eq(optionRows.shiny_event.type, "toggle",
  "the guaranteed red Gyarados event can be switched off")
T.eq(optionRows.johto_time.type, "choice",
  "Johto friendship branches can follow AUTO, DAY or NIGHT")
T.eq(optionRows.mega_evolution.type, "toggle",
  "official Mega Evolution can be disabled")
T.eq(optionRows.mega_opponents.type, "choice",
  "enemy Mega Evolution supports bosses, all trainers or off")
T.eq(optionRows.legend_mewtwo.type, "choice",
  "Mewtwo has its own APEX/VANILLA/OFF option")
T.eq(optionRows.legend_raikou.type, "toggle",
  "Raikou can be enabled or disabled independently")
T.eq(optionRows.legend_celebi.type, "toggle",
  "Celebi can be enabled or disabled independently")
T.eq(optionRows.legend_mew.type, "toggle",
  "Mew can be enabled or disabled independently")
T.eq(optionRows.mew_profile.type, "choice",
  "Mew can use either its Ascendant or historical distribution profile")
T.eq(optionRows.event_mode.type, "choice",
  "Heritage events can run as cups, roaming hunts or be disabled")
T.eq(optionRows.event_flying_pikachu.type, "toggle",
  "Flying Pikachu can be disabled independently")
T.eq(optionRows.event_rosette.type, "toggle",
  "the in-battle event rosette is optional")
T.eq(optionRows.rocket_story.type, "toggle",
  "Rocket Resurgence can be disabled independently")
T.eq(optionRows.grand_tournament.type, "toggle",
  "the Grand Tournament can be disabled independently")
T.eq(optionRows.ascendant_rules.type, "choice",
  "New Game Plus challenge rules can be relaxed")

-- ------------------------------------------------ tidy Ascendant submenu

;(function()
local ascendantMenu = ex.ascendantMenu
T.neq(ascendantMenu, nil,
  "the centralized Ascendant Start-menu gateway is exported")
local keptRows, groupedRows = ascendantMenu.collect({
  { label = "ITEM" },
  {
    label = "MEGA", ascendantMenu = true,
    ascendantLabel = "MEGA STONES", ascendantOrder = 70,
  },
  {
    label = "JOURNAL", ascendantMenu = true,
    ascendantLabel = "JOURNAL", ascendantOrder = 10,
  },
  { label = "SAVE" },
})
T.eq(#keptRows, 2,
  "the collector preserves ordinary Start-menu rows")
T.eq(keptRows[1].label, "ITEM",
  "ordinary Start-menu row order remains unchanged")
T.eq(keptRows[2].label, "SAVE",
  "the vanilla SAVE anchor remains present")
T.eq(#groupedRows, 2,
  "only explicitly marked Ascendant rows enter the submenu")
T.eq(groupedRows[1].label, "JOURNAL",
  "Ascendant utilities use their intentional logical order")
T.eq(groupedRows[2].label, "MEGA STONES",
  "the submenu can use a clearer label than the compact old Start row")
local _, expandedRows, anyNew = ascendantMenu.collect({
  {
    label = "JOURNAL", ascendantMenu = true,
    ascendantLabel = "JOURNAL", ascendantOrder = 10,
  },
  {
    label = "MEGA", ascendantMenu = true,
    ascendantLabel = "MEGA STONES", ascendantOrder = 70,
  },
  {
    label = "TITLES", ascendantMenu = true,
    ascendantLabel = "TITLES / TROPHIES", ascendantOrder = 80,
  },
})
T.eq(anyNew, true,
  "a utility unlocked after the initial menu visit raises a visible NEW hint")
T.eq(expandedRows[3].right, "NEW",
  "the newly unlocked utility itself carries the NEW marker")

local menuOwned = {}
for id, def in pairs(Data.pokemon) do
  if def.dex and def.dex <= 150 then menuOwned[id] = true end
end
local pushedAscendantMenu
local menuGame = {
  data = Data,
  save = {
    flags = { EVENT_BEAT_CHAMPION_RIVAL = true },
    hallOfFame = { {} },
    pokedex = { seen = menuOwned, owned = menuOwned },
    inventory = {}, bagOrder = {}, party = {},
    player = { name = "RED" }, options = {},
  },
  stack = {
    push = function(_, screen) pushedAscendantMenu = screen end,
  },
}
local megaMenuState = ex.megaEvolution.state()
local priorMegaRing = megaMenuState.ring
megaMenuState.ring = true
local topRows = RealRuntime.call("ui.start_menu.items",
  function(_, rows) return rows end, menuGame, {
    { label = "POKéMON" },
    { label = "ITEM" },
    { label = "SAVE" },
    { label = "OPTION" },
  })
megaMenuState.ring = priorMegaRing
local ascendantRow, ascendantRows = nil, 0
local leakedRows = {
  JOURNAL = true, WORLD = true, WELT = true, JOHTO = true,
  SHINY = true, EVENTS = true, ["CERT."] = true, ZERT = true, MEGA = true,
}
for _, row in ipairs(topRows) do
  if row.label == "ASCENDANT" then
    ascendantRow, ascendantRows = row, ascendantRows + 1
  end
  T.eq(leakedRows[row.label], nil,
    row.label .. " does not leak back into the tidy Start menu")
end
T.eq(ascendantRows, 1,
  "all unlocked utilities produce exactly one ASCENDANT Start row")
T.neq(ascendantRow, nil, "the ASCENDANT Start row is reachable")
ascendantRow.onSelect()
T.neq(pushedAscendantMenu, nil,
  "selecting ASCENDANT opens the dedicated utility list")
T.eq(pushedAscendantMenu.title, "KANTO ASCENDANT",
  "the utility list carries the expansion's full title")
T.eq(#pushedAscendantMenu.items, 8,
  "the fixture exposes every utility whose content is available")
T.same((function()
  local labels = {}
  for _, row in ipairs(pushedAscendantMenu.items) do
    labels[#labels + 1] = row.label
  end
  return labels
end)(), {
  "RESEARCH ATLAS", "JOURNAL", "WORLD STATUS", "SHINY DEX",
  "EVENT ARCHIVE", "MEGA STONES", "FRONTIER EXCHANGE",
  "TITLES / TROPHIES",
}, "available Ascendant utilities are clear and consistently ordered")
end)()

-- ------------------------------------------------ Route 5 Day-Care Plus

local daycare = ex.daycare
T.neq(daycare, nil, "the full Route 5 Day-Care controller is exported")
T.eq(#ex.breedingData, 251,
  "canonical breeding metadata covers every Kanto and Johto species")
T.eq(ex.breedingData[25].gender, 4,
  "Pikachu uses the canonical half-female Attack-DV threshold")
T.eq(ex.breedingData[150].groups[1], "no-eggs",
  "Mewtwo belongs to the unbreedable egg group")
local breedingGame = { data = { pokemon = {
  PICHU = { dex = 172, evolutions = { { species = "PIKACHU" } } },
  PIKACHU = { dex = 25, evolutions = { { species = "RAICHU" } } },
  RAICHU = { dex = 26, evolutions = {} },
  MEWTWO = { dex = 150, evolutions = {} },
  DITTO = { dex = 132, evolutions = {} },
} } }
local femalePikachu = { species = "PIKACHU", dvs = { attack = 7 } }
local malePikachu = { species = "PIKACHU", dvs = { attack = 9 } }
local compatible, eggChance = daycare.compatible(
  breedingGame, femalePikachu, malePikachu)
T.eq(compatible, true, "opposite-gender compatible parents can produce eggs")
T.eq(eggChance, 70, "same-species parents receive the best egg chance")
local legendaryCompatible = daycare.compatible(breedingGame,
  { species = "MEWTWO", dvs = { attack = 8 } },
  { species = "DITTO", dvs = { attack = 9 } })
T.eq(legendaryCompatible, false, "legendary Pokémon cannot breed")
T.eq(daycare.babyFor(breedingGame, "RAICHU"), "PICHU",
  "the evolution graph resolves Raichu eggs to Pichu")
local shinySystem = ex.shinySystem
T.neq(shinySystem, nil,
  "the self-contained Generation-II shiny controller is exported")
T.eq(shinySystem.isShiny(crystalShinyMon), true,
  "Defense/Speed/Special 10 plus a valid Attack DV is shiny")
T.eq(shinySystem.isShiny({
  dvs = { attack = 10, defense = 9, speed = 10, special = 10 },
}), false, "near-miss DV combinations are not shiny")
local femaleShinyParent = {
  species = "PIKACHU",
  dvs = { attack = 7, defense = 10, speed = 10, special = 10, hp = 0 },
}
local maleParent = {
  species = "PIKACHU",
  dvs = { attack = 9, defense = 4, speed = 4, special = 4, hp = 0 },
}
local inheritedRolls = { 10, 3, 10, 10 }
local inheritedIndex = 0
local inherited = daycare.inheritedDVs(
  breedingGame, "PIKACHU", femaleShinyParent, maleParent, function()
    inheritedIndex = inheritedIndex + 1
    return inheritedRolls[inheritedIndex]
  end)
T.eq(inherited.defense, 10,
  "a male Gen-II egg inherits Defense from its female parent")
T.eq(inherited.special, 10,
  "a Gen-II egg inherits the donor's low three Special-DV bits")
T.eq(shinySystem.isShiny({ dvs = inherited }), true,
  "canonical inherited DVs can produce the authentic 1/64 shiny result")
local dittoShiny = {
  species = "DITTO",
  dvs = { attack = 10, defense = 10, speed = 10, special = 10, hp = 0 },
}
local tooSimilar, _ = daycare.compatible(
  breedingGame, femaleShinyParent, dittoShiny)
T.eq(tooSimilar, false,
  "Crystal's matching Defense/Special-DV rule also applies to Ditto")
T.eq(daycare.reserveEgg("TOGEPI", 1024, "TEST RESEARCH", "TOGEPI"), true,
  "research eggs can be reserved at Route 5")
local reservedSpecies, reservedSteps, reservedLocation =
  daycare.researchEggStatus({ save = { party = {} } })
T.eq(reservedSpecies, "TOGEPI", "reserved research egg retains its species")
T.eq(reservedSteps, 1024, "reserved research egg retains its hatch distance")
T.eq(reservedLocation, "reserved", "research egg reports the Day-Care location")

-- ------------------------------------------------ official Mega Evolution

local mega = ex.megaEvolution
T.neq(mega, nil, "the official-species Mega controller is exported")
T.eq(#mega.forms, 30,
  "the Kanto/Johto roster contains the 30 official forms available by July 2026")
local megaSpeciesCount = 0
for _ in pairs(mega.formsBySpecies) do megaSpeciesCount = megaSpeciesCount + 1 end
T.eq(megaSpeciesCount, 27,
  "the official forms belong to exactly 27 of the first 251 species")
T.eq(mega.formsBySpecies.PIKACHU, nil,
  "Pikachu has no invented Mega Evolution")
T.eq(#mega.formsBySpecies.CHARIZARD, 2,
  "Charizard has distinct X and Y stone profiles")
T.eq(#mega.formsBySpecies.MEWTWO, 2,
  "Mewtwo has distinct X and Y stone profiles")
T.eq(#mega.formsBySpecies.RAICHU, 2,
  "Raichu has distinct official X and Y stone profiles")
local xProfile = mega.formsBySpecies.RAICHU[1]
local yProfile = mega.formsBySpecies.RAICHU[2]
local xBonuses = xProfile.bonuses
T.eq(xBonuses.attack > xBonuses.special, true,
  "Mega Raichu X favors physical power")
local yBonuses = yProfile.bonuses
T.eq(yBonuses.speed > yBonuses.defense, true,
  "Mega Raichu Y favors speed")
T.eq(xProfile.stone, "RAICHUNITE_X",
  "Mega Raichu X requires its own stone")
T.eq(yProfile.stone, "RAICHUNITE_Y",
  "Mega Raichu Y requires a different stone")
T.eq(mega.stoneName(xProfile), "RAICHUNITE X",
  "Mega Stone display names never expose internal underscore IDs")
T.eq(mega.caseLabel(mega.formsBySpecies.CHARIZARD[1]), "CHARIZARD X",
  "the compact Stone Case label preserves X/Y form identity")
T.eq(#mega.caseLabel(mega.formsBySpecies.KANGASKHAN[1]) <= 13, true,
  "the longest Stone Case species label fits the Gen-1 menu")
local seenMegaStones = {}
for _, profile in ipairs(mega.forms) do
  local total = profile.bonuses.attack + profile.bonuses.defense
    + profile.bonuses.speed + profile.bonuses.special
  T.eq(total, 100, profile.id .. " adapts exactly +100 points to Gen 1")
  T.eq(seenMegaStones[profile.stone], nil,
    profile.stone .. " belongs to only one Mega form")
  seenMegaStones[profile.stone] = true
end
local boosted = mega.boostedStats({
  mon = { species = "RAICHU", level = 100,
    stats = { hp = 200, attack = 100, defense = 100, speed = 100, special = 100 } },
  curStats = { hp = 200, attack = 100, defense = 100, speed = 100, special = 100 },
}, xProfile)
T.eq(boosted.hp, 200, "Mega Evolution never changes HP")
T.eq(boosted.attack, 180,
  "level-100 Mega Raichu X receives its formula-correct Attack boost")
local megaCtx = {
  species = "RAICHU", side = "front", trueColor = false,
  mon = { species = "RAICHU", _ascMegaForm = "RAICHU_X" },
}
local megaPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "raichu_fallback.png", megaCtx)
T.eq(megaPath:find("assets/mega/mega_raichu_x_front.png", 1, true) ~= nil,
  true, "Mega Raichu X selects its original four-shade front sprite")
T.eq(megaCtx.trueColor, false,
  "Mega sprites remain compatible with Gen-1 palettes")

-- ------------------------------------------------ complete Johto catalogue

local johto = ex.johtoData
T.neq(johto, nil, "the Johto catalogue is exported")
T.eq(#johto.order, 100, "the complete Johto dex contains 100 species")
T.eq(johto.species.CHIKORITA.dex, 152,
  "Chikorita opens the canonical Johto dex at 152")
T.eq(johto.species.RAIKOU.dex, 243,
  "Raikou uses its canonical full-dex number")
T.eq(johto.species.HO_OH.dex, 250,
  "Ho-Oh uses its canonical full-dex number")
T.eq(johto.species.CELEBI.dex, 251,
  "Celebi closes the canonical full dex at 251")
local johtoDex, johtoIds = {}, {}
for _, id in ipairs(johto.order) do
  T.eq(johtoIds[id], nil, id .. " appears once in the species order")
  T.eq(johtoDex[johto.species[id].dex], nil,
    tostring(johto.species[id].dex) .. " is a unique dex number")
  johtoIds[id] = true
  johtoDex[johto.species[id].dex] = true
end
T.eq(johto.evolutions.CHIKORITA[1][2], "BAYLEEF",
  "starter evolution chains are recorded")
T.eq(johto.kantoEvolutions.EEVEE[1][1], "FRIENDSHIP_DAY",
  "Espeon uses the daytime friendship branch")
T.eq(johto.kantoEvolutions.EEVEE[2][1], "FRIENDSHIP_NIGHT",
  "Umbreon uses the nighttime friendship branch")
T.eq(johto.kantoEvolutions.SCYTHER[1][3], "METAL_COAT",
  "Scizor uses Elm's Metal Coat machine")
T.eq(#johto.rewards, 40,
  "forty non-duplicate Johto family rewards fill themed rematches")
T.eq(#johto.eggs, 8, "all eight Generation-II baby lines hatch from eggs")
local eeveePartners = 0
for _, row in ipairs(johto.partnerMilestones) do
  if row.species == "EEVEE" then eeveePartners = eeveePartners + 1 end
end
T.eq(eeveePartners, 2,
  "Elm supplies two Eevee so both friendship branches are obtainable")
T.eq(johto.finalReward, "LARVITAR",
  "Larvitar is reserved for completing every research track")
T.eq(johto.partyIcons.RAIKOU, "QUADRUPED",
  "Raikou uses the standard animated quadruped party icon")
T.eq(johto.partyIcons.ENTEI, "QUADRUPED",
  "Entei uses the standard animated quadruped party icon")
T.eq(johto.partyIcons.SUICUNE, "QUADRUPED",
  "Suicune uses the standard animated quadruped party icon")
T.eq(johto.partyIcons.LUGIA, "BIRD",
  "Lugia uses the standard animated bird party icon")
T.eq(johto.partyIcons.HO_OH, "BIRD",
  "Ho-Oh uses the standard animated bird party icon")
T.eq(johto.partyIcons.CELEBI, "FAIRY",
  "Celebi uses the standard animated Mew-like party icon")

;(function()
local johtoDexTexts, johtoLearnProfiles, johtoTmProfiles = {}, {}, {}
for _, id in ipairs(johto.order) do
  local def = johto.species[id]
  T.eq(type(def.level1), "table",
    id .. " has a species-authentic starting move set")
  T.eq(type(def.learnset), "table",
    id .. " has an explicit Crystal-shaped level-up plan")
  T.eq(type(def.tmhm), "table",
    id .. " has an explicit TM/HM compatibility profile")
  T.eq(type(def.dexEntry), "table",
    id .. " has individual bilingual Pokédex metadata")
  T.eq(type(def.dexEntry.kindEn), "string",
    id .. " has an English Pokédex classification")
  T.eq(type(def.dexEntry.kindDe), "string",
    id .. " has a German Pokédex classification")
  T.eq(def.dexEntry.heightM > 0, true,
    id .. " has its canonical nonzero metric height")
  T.eq(type(def.dexEntry.textEn), "string",
    id .. " has an individual English field-guide entry")
  T.eq(type(def.dexEntry.textDe), "string",
    id .. " has an individual German field-guide entry")
  T.eq(johtoDexTexts[def.dexEntry.textEn], nil,
    id .. " does not reuse another species' English Dex placeholder")
  johtoDexTexts[def.dexEntry.textEn] = id
  local learnSignature = table.concat(def.level1, ",")
  for _, row in ipairs(def.learnset) do
    learnSignature = learnSignature .. ";" .. row.level .. ":" .. row.move
  end
  johtoLearnProfiles[learnSignature] = true
  johtoTmProfiles[table.concat(def.tmhm, ",")] = true
end
local distinctLearnProfiles, distinctTmProfiles = 0, 0
for _ in pairs(johtoLearnProfiles) do distinctLearnProfiles = distinctLearnProfiles + 1 end
for _ in pairs(johtoTmProfiles) do distinctTmProfiles = distinctTmProfiles + 1 end
T.eq(distinctLearnProfiles >= 60, true,
  "Johto no longer collapses into one generic learn plan per primary type")
T.eq(distinctTmProfiles >= 35, true,
  "Johto families receive varied TM/HM compatibility instead of the same ten TMs")
T.eq(johto.species.CHIKORITA.learnset[1].move, "RAZOR_LEAF",
  "Chikorita begins its Crystal-shaped line with Razor Leaf")
T.eq(johto.species.SCIZOR.learnset[2].move, "METAL_CLAW",
  "Scizor learns a defining implemented Steel move")
T.eq(johto.species.HOUNDOOM.learnset[4].move, "CRUNCH",
  "Houndoom's line keeps its defining Dark progression")
T.eq(johto.species.STEELIX.dexEntry.heightM, 9.2,
  "Steelix uses its canonical 9.2-meter Pokédex height")
T.eq(johto.species.LUGIA.dexEntry.kindDe, "TAUCHER",
  "legendary Pokédex classifications are localized too")

local johtoResearch = ex.johtoResearch
T.neq(johtoResearch, nil, "Elm's living-habitat research API is exported")
T.eq(johtoResearch.state().version, 2,
  "existing Johto research saves migrate in place to living habitats")
local blankResearch = {
  starters = {}, rewards = {}, eggsQueued = {}, eggsHatched = {},
}
T.eq(johtoResearch.starterTrialsComplete(blankResearch), false,
  "starter-trial status is queryable without exposing any Dex entry")
T.eq(johtoResearch.finaleUnlocked(blankResearch), false,
  "the Larvitar finale begins locked")
T.eq(johtoResearch.itemUnlocked("SUN_STONE", {
    itemsClaimed = { ["3:SUN_STONE"] = true },
  }), true,
  "the Frontier Exchange can query an earned evolution item cleanly")
T.eq(johtoResearch.itemUnlocked("KINGS_ROCK", {
    itemsClaimed = { ["3:SUN_STONE"] = true },
  }), false,
  "a later evolution item remains locked until its own milestone")
T.eq(johtoResearch.isSpeciesResearched("SKARMORY", blankResearch), false,
  "seeing a mapped Johto species elsewhere cannot bypass Elm's research gate")
T.eq(#johtoResearch.habitatCandidates("ROUTE_1", "grass", blankResearch), 0,
  "an unrevealed Johto family cannot leak into a wild encounter")
local livingResearch = {
  starters = { chikorita = true, cyndaquil = true, totodile = true },
  rewards = { SENTRET = true, HOUNDOUR = true },
  eggsQueued = {}, eggsHatched = {}, finalReward = true,
}
T.eq(johtoResearch.starterTrialsComplete(livingResearch), true,
  "all three completed starter trials are exposed as one clean status")
T.eq(johtoResearch.isSpeciesResearched("FURRET", livingResearch), true,
  "research status follows a revealed specimen through its evolution family")
T.eq(johtoResearch.isSpeciesResearched("TYRANITAR", livingResearch), true,
  "the finale status covers Larvitar's complete evolution family")
local routeOneHabitats =
  johtoResearch.habitatCandidates("ROUTE_1", "grass", livingResearch)
T.eq(#routeOneHabitats, 1,
  "a researched family establishes one permanent thematic habitat")
T.eq(routeOneHabitats[1].species, "SENTRET",
  "Route 1 becomes Sentret habitat only after its research reward")
T.eq(johtoResearch.habitatFor("LARVITAR").map, "VICTORY_ROAD_3F",
  "Larvitar's post-finale habitat is the deepest Victory Road floor")
end)()

local followerCompat = ex.followerCompat
T.neq(followerCompat, nil,
  "Johto follower compatibility is exported")
T.eq(followerCompat.proxySpecies("TYRANITAR", Data), "RHYDON",
  "Tyranitar uses a sturdy existing follower sheet instead of crashing")
T.eq(followerCompat.proxySpecies("LUGIA", Data), "ARTICUNO",
  "Lugia uses the standard legendary-bird follower silhouette")
T.eq(followerCompat.proxySpecies("CELEBI", Data), "MEW",
  "Celebi uses the small Mew-like follower silhouette")
local missingFollowerProxy = {}
for _, id in ipairs(johto.order) do
  local proxy = followerCompat.proxySpecies(id, Data)
  if type(proxy) ~= "string" or proxy == "" then
    missingFollowerProxy[#missingFollowerProxy + 1] = id
  end
end
T.eq(#missingFollowerProxy, 0,
  "every Johto species has a safe 2D/voxel follower fallback")

-- ------------------------------------------------ pure line resolution

T.eq(ex.resolveLine("OPP_YOUNGSTER"):find("shorts", 1, true) ~= nil, true,
  "YOUNGSTER line is in his voice")
T.eq(ex.resolveLine("OPP_LANCE"):find("dragons", 1, true) ~= nil, true,
  "LANCE line is in his voice")
T.eq(ex.resolveLine("OPP_UNUSED_JUGGLER"):find("juggling", 1, true) ~= nil, true,
  "UNUSED_JUGGLER gets a line too")
T.eq(ex.resolveLine("OPP_FIX_YOUNGSTER"), "You're looking\nfor a rematch?",
  "unknown class falls back to the default prompt")
T.eq(ex.resolveLine(nil), "You're looking\nfor a rematch?",
  "nil class falls back to the default prompt")
run.loader.modOptions.trainer_rematch = { language = "de" }
T.eq(ex.language(), "de", "the manual DEUTSCH override selects German")
T.eq(ex.resolveLine("OPP_YOUNGSTER"):find("Shorts", 1, true) ~= nil, true,
  "German rematch dialogue keeps the class voice")
T.eq(ex.resolveDecline("OPP_KOGA"):find("Gift", 1, true) ~= nil, true,
  "German decline dialogue is localized too")
T.eq(ex.restLine(2):find("Schritten", 1, true) ~= nil, true,
  "German cooldown dialogue uses the correct plural")
run.loader.modOptions.trainer_rematch = nil
T.eq(ex.language(), "en", "English remains the standalone AUTO fallback")

-- ------------------------------------------------ pure decline resolution

T.eq(ex.resolveDecline("OPP_YOUNGSTER"):find("scared", 1, true) ~= nil, true,
  "cocky classes mock the refusal")
T.eq(ex.resolveDecline("OPP_KOGA"):find("Fear", 1, true) ~= nil, true,
  "wise classes answer with understanding")
T.eq(ex.resolveDecline("OPP_GENTLEMAN"):find("gentleman", 1, true) ~= nil, true,
  "polite classes stay polite")
T.eq(ex.resolveDecline("OPP_FIX_YOUNGSTER"), "Ha! Scared of\na rematch, are\nyou?",
  "unknown class falls back to the default decline")
T.eq(ex.resolveDecline(nil), "Ha! Scared of\na rematch, are\nyou?",
  "nil class falls back to the default decline")

-- ------------------------------------------------ prize-line filter

T.eq(ex.isPrizeLine("RED got ¥1500\nfor winning!"), true,
  "prize line is filtered out")
T.eq(ex.isPrizeLine("RED defeated\nYOUNGSTER!"), false,
  "defeated line passes")
T.eq(ex.isPrizeLine("You got here\nfor winning\nnothing!"), true,
  "any line mentioning got/for winning is treated as prize text")
T.eq(ex.isPrizeLine(123), false, "non-string texts pass")

-- ------------------------------------------------ rest + growth rules

T.eq(ex.rollRestSteps(function(lo) return lo end, 151, 2510), 151,
  "rest roll includes the lower bound")
T.eq(ex.rollRestSteps(function(_, hi) return hi end, 151, 2510), 2510,
  "rest roll includes the upper bound")
T.eq(ex.rollRestSteps(function(lo) return lo end, 2510, 151), 151,
  "an inverted option range is normalized")
T.eq(ex.rollRestSteps(function(_, hi) return hi end, 128, 256), 2510,
  "untouched legacy defaults migrate to the expanded range")
T.eq(ex.restLine(1):find("1 more step.", 1, true) ~= nil, true,
  "one remaining step uses singular dialogue")
T.eq(ex.restLine(2510):find("2510 more steps.", 1, true) ~= nil, true,
  "rest dialogue tells the player exactly how long is left")
T.eq(ex.nextLevelBoost(0, 2), 2, "the first rematch is two levels stronger")
T.eq(ex.nextLevelBoost(1, 2), 4, "the second rematch grows again")
T.eq(ex.nextLevelBoost(9, 2), 20, "ten default growth tiers reach +20")
T.eq(ex.nextLevelBoost(99, 2), 99,
  "long-running trainers can now reach the natural level-100 ceiling")
local preview = ex.boostedTeam({ { species = "RATTATA", level = 99 },
                                 { species = "EKANS", level = 12 } }, 4)
T.eq(preview[1].level, 100, "preview levels respect the level-100 cap")
T.eq(preview[2].level, 16, "preview levels include the rematch boost")

local fixtureTeam = Data.trainers.OPP_FIX_YOUNGSTER.parties[1]
local noRecruit = ex.recruitTeam(Data, fixtureTeam, "OPP_FIX_YOUNGSTER",
  "FIX_ROUTE_obj_recruit", 0, 2, true)
T.eq(#noRecruit, 2, "the first growth tier does not add a recruit immediately")
local recruited = ex.recruitTeam(Data, fixtureTeam, "OPP_FIX_YOUNGSTER",
  "FIX_ROUTE_obj_recruit", 1, 4, true)
T.eq(#recruited, 3, "the second growth tier recruits one new Pokémon")
T.eq(recruited[3].species, "FIXMON_B",
  "an unknown mod trainer recruits a valid non-duplicate fallback species")
T.eq(recruited[3].recruited, true,
  "new party slots are marked as background-training recruits")
local recruitedAgain = ex.recruitTeam(Data, fixtureTeam, "OPP_FIX_YOUNGSTER",
  "FIX_ROUTE_obj_recruit", 1, 4, true)
T.eq(recruitedAgain[3].species, recruited[3].species,
  "the same trainer keeps a deterministic recruit")
local disabledRecruit = ex.recruitTeam(Data, fixtureTeam, "OPP_FIX_YOUNGSTER",
  "FIX_ROUTE_obj_recruit", 9, 20, false)
T.eq(#disabledRecruit, 2, "TEAM GROWTH off preserves the original party size")
local recruitPoolCount = 0
local forbiddenRecruit = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true, LUGIA = true, HO_OH = true,
  CELEBI = true,
}
for class, pool in pairs(ex.recruitPools) do
  recruitPoolCount = recruitPoolCount + 1
  T.eq(#pool > 0, true, class .. " has a non-empty recruitment pool")
  for _, species in ipairs(pool) do
    T.eq(forbiddenRecruit[species], nil,
      class .. " never recruits legendary Pokémon")
  end
end
T.eq(recruitPoolCount, 47,
  "all 47 trainer classes have a thematic recruitment pool")

T.eq(ex.lootForRoll(1, "balanced",
  { averageLevel = 100, masterUnlocked = false, expAllAvailable = true }), nil,
  "Master Ball rolls are sealed before the Apex Champion")
T.eq(ex.lootForRoll(1, "balanced",
  { averageLevel = 100, masterUnlocked = true }), "MASTER_BALL",
  "the rarest eligible roll awards a Master Ball")
T.eq(ex.lootForRoll(1, "balanced",
  { averageLevel = 79, masterUnlocked = true }), nil,
  "the Master Ball also requires a genuinely high-level rematch")
T.eq(ex.lootForRoll(101, "balanced",
  { averageLevel = 40, expAllAvailable = true }), "EXP_ALL",
  "the functional EXP.ALL/EP-Teiler starts its five-percent balanced band")
T.eq(ex.lootForRoll(600, "balanced",
  { averageLevel = 40, expAllAvailable = true }), "EXP_ALL",
  "the functional EXP.ALL/EP-Teiler fills its five-percent balanced band")
T.eq(ex.lootForRoll(101, "balanced",
  { averageLevel = 40, expAllAvailable = false }), nil,
  "EXP.ALL can only drop once")
T.eq(ex.lootForRoll(101, "balanced",
  { averageLevel = 39, expAllAvailable = true }), nil,
  "EXP.ALL waits for a level-40 rematch")
T.eq(ex.lootForRoll(601, "balanced",
  { averageLevel = 20 }), "RARE_CANDY",
  "Rare Candy starts its five-percent balanced band")
T.eq(ex.lootForRoll(1101, "balanced",
  { averageLevel = 35 }), "PP_UP",
  "level-35 rematches can drop PP Up")
T.eq(ex.lootForRoll(2101, "balanced",
  { averageLevel = 50 }), "MAX_REVIVE",
  "level-50 rematches can drop Max Revive")
T.eq(ex.lootForRoll(2901, "balanced", { averageLevel = 1 }), "NUGGET",
  "Nugget starts its fifteen-percent balanced band")
T.eq(ex.lootForRoll(4401, "balanced",
  { averageLevel = 100, masterUnlocked = true, expAllAvailable = true }), nil,
  "balanced loot keeps the removed percentages as no-drop results")
T.eq(ex.lootForRoll(200, "generous",
  { averageLevel = 100, masterUnlocked = true }), "MASTER_BALL",
  "GENEROUS mode gives the Master Ball its full two-percent band")
T.eq(ex.lootForRoll(201, "generous",
  { averageLevel = 40, expAllAvailable = true }), "EXP_ALL",
  "GENEROUS mode also keeps EXP.ALL at five percent")
T.eq(ex.lootForRoll(701, "generous", { averageLevel = 20 }), "RARE_CANDY",
  "GENEROUS mode also keeps Rare Candy at five percent")
T.eq(ex.lootForRoll(1201, "generous", { averageLevel = 35 }), "PP_UP",
  "GENEROUS mode retains its existing PP Up band")
T.eq(ex.lootForRoll(2701, "generous", { averageLevel = 50 }), "MAX_REVIVE",
  "GENEROUS mode retains its existing Max Revive band")
T.eq(ex.lootForRoll(3901, "generous", { averageLevel = 1 }), "NUGGET",
  "GENEROUS mode keeps Nuggets at fifteen percent")
T.eq(ex.lootForRoll(5401, "generous",
  { averageLevel = 100, masterUnlocked = true, expAllAvailable = true }), nil,
  "GENEROUS leaves reduced reward space as no drop")
T.eq(ex.lootForRoll(1, "off",
  { averageLevel = 100, masterUnlocked = true }), nil,
  "loot can be disabled completely")

-- ------------------------------------------------ post-game progression + rosters

local pg = ex.postgame
local pgd = ex.postgameData
T.neq(pg, nil, "post-game controller is exported")
T.neq(pgd, nil, "post-game roster data is exported")
T.eq(#pgd.gyms, 8, "all eight Kanto leaders join the circuit")
T.eq(#pgd.legendOrder, 10, "ten gated legendary encounters are tracked")
T.neq(pgd.dialogue, nil, "post-game character dialogue is loaded")
local gymDialogueCount = 0
for _, gym in ipairs(pgd.gyms) do
  local writing = pgd.dialogue.gyms[gym.key]
  T.neq(writing, nil, gym.name .. " has character-specific writing")
  for _, tier in ipairs({ "master", "crown" }) do
    local stage = writing[tier]
    T.neq(stage, nil, gym.name .. " has " .. tier .. " dialogue")
    for _, key in ipairs({ "intro", "decline", "win" }) do
      T.eq(type(stage[key].en), "string",
        gym.name .. " " .. tier .. " " .. key .. " has English text")
      T.eq(type(stage[key].de), "string",
        gym.name .. " " .. tier .. " " .. key .. " has German text")
    end
    T.eq(type(stage.rest.one.en), "string",
      gym.name .. " has a singular English rest line")
    T.eq(type(stage.rest.many.de), "string",
      gym.name .. " has a plural German rest line")
  end
  gymDialogueCount = gymDialogueCount + 1
end
T.eq(gymDialogueCount, 8, "all eight leaders have full dialogue sets")
local eliteDialogueCount = 0
for class, writing in pairs(pgd.dialogue.elite) do
  for _, tier in ipairs({ "apex", "crown" }) do
    for _, key in ipairs({ "before", "win", "after" }) do
      T.eq(type(writing[tier][key].en), "string",
        class .. " " .. tier .. " " .. key .. " has English text")
      T.eq(type(writing[tier][key].de), "string",
        class .. " " .. tier .. " " .. key .. " has German text")
    end
  end
  eliteDialogueCount = eliteDialogueCount + 1
end
T.eq(eliteDialogueCount, 5,
  "Lorelei, Bruno, Agatha, Lance and the Champion have full dialogue sets")
T.eq(type(pgd.dialogue.story.oakLegendEvent.en), "string",
  "Oak's first Hall-of-Fame event has English writing")
T.eq(type(pgd.dialogue.story.oakLegendEvent.de), "string",
  "Oak's first Hall-of-Fame event has German writing")
T.eq(pgd.overworldSprites.RAIKOU, "SPRITE_MONSTER",
  "Raikou reuses the standard monster overworld sheet")
T.eq(pgd.overworldSprites.ENTEI, "SPRITE_MONSTER",
  "Entei reuses the standard monster overworld sheet")
T.eq(pgd.overworldSprites.SUICUNE, "SPRITE_MONSTER",
  "Suicune reuses the standard monster overworld sheet")
T.eq(pgd.overworldSprites.LUGIA, "SPRITE_BIRD",
  "Lugia reuses the standard flying overworld sheet")
T.eq(pgd.overworldSprites.HO_OH, "SPRITE_BIRD",
  "Ho-Oh reuses the standard flying overworld sheet")
T.eq(pgd.overworldSprites.CELEBI, "SPRITE_FAIRY",
  "Celebi reuses the small fairy overworld sheet")
T.eq(pgd.roamers.RAIKOU.level, 85,
  "visible and grass Raikou encounters share the intended level")

local pgSave = {
  flags = {}, hallOfFame = {}, pokedex = { seen = {}, owned = {} },
}
local pgState = {
  masterWins = {}, crownWins = {}, eliteApexWins = {},
  eliteCrownWins = {}, catches = {}, roamers = {}, bossRest = {},
}
local oakBase = "OAK: Base-game invitation."
local oakLabel = "_ChampionsRoomOakComeWithMeText"
local oakGame = {
  save = pgSave,
  data = { text = { [oakLabel] = oakBase } },
}
T.eq(pg.applyEliteDialogue("CHAMPIONS_ROOM", oakGame, pgState), true,
  "the first Champion clear installs Oak's event announcement")
T.eq(oakGame.data.text[oakLabel]:find(
    "legendary POKéMON", 1, true) ~= nil, true,
  "Oak foreshadows the growing legendary sightings in English")
run.loader.modOptions.trainer_rematch = { language = "de" }
local germanOakGame = {
  save = { flags = {}, hallOfFame = {} },
  data = { text = { [oakLabel] = oakBase } },
}
T.eq(pg.applyStoryOakDialogue("CHAMPIONS_ROOM", germanOakGame), true,
  "the first Champion announcement can be installed directly")
T.eq(germanOakGame.data.text[oakLabel]:find(
    "Immer häufiger", 1, true) ~= nil
    and germanOakGame.data.text[oakLabel]:find(
      "legendäre", 1, true) ~= nil, true,
  "Oak's event announcement is fully localized in German")
run.loader.modOptions.trainer_rematch = nil
pgSave.flags.EVENT_BEAT_CHAMPION_RIVAL = true
T.eq(pg.applyEliteDialogue("CHAMPIONS_ROOM", oakGame, pgState), false,
  "the first-clear announcement is not reused on later League runs")
T.eq(oakGame.data.text[oakLabel], oakBase,
  "later League runs restore Oak's original invitation")
pgSave.flags.EVENT_BEAT_CHAMPION_RIVAL = nil
T.eq(pg.phaseFor(pgState, pgSave), "story",
  "the circuit stays closed before the Hall of Fame")
pgSave.hallOfFame[1] = {}
T.eq(pg.phaseFor(pgState, pgSave), "master_gyms",
  "the first Hall of Fame opens the Master gyms")
T.eq(pg.applyEliteDialogue("LORELEIS_ROOM",
    { save = pgSave, data = { text = {} } }, pgState), false,
  "the ordinary first Elite Four clear keeps the base-game dialogue")
for _, gym in ipairs(pgd.gyms) do pgState.masterWins[gym.key] = true end
T.eq(pg.allMaster(pgState), true, "all eight Master crests are recognized")
T.eq(pg.phaseFor(pgState, pgSave), "apex_elite",
  "the Master crests unlock the Apex Elite Four")
T.eq(pg.eliteTier(pgState, pgSave), "apex",
  "Apex rosters replace the Elite Four after all Master wins")
T.eq(pg.gymDialogue(pgd.gyms[1], "master", "intro")
    :find("first badge", 1, true) ~= nil, true,
  "Brock's English Master challenge is character-specific")
T.eq(pg.eliteDialogue("OPP_AGATHA", "apex", "before")
    :find("Heheheh", 1, true) ~= nil, true,
  "Agatha's English Apex challenge keeps her voice")
local eliteTextData = { text = {} }
T.eq(pg.applyEliteDialogue("LORELEIS_ROOM",
    { save = pgSave, data = eliteTextData }, pgState), true,
  "entering an active Apex room installs its circuit dialogue")
T.eq(eliteTextData.text._LoreleisRoomLoreleiBeforeBattleText
    :find("Eight masters", 1, true) ~= nil, true,
  "Lorelei's Apex opening replaces the ordinary story opening")
T.eq(eliteTextData.text._LoreleisRoomLoreleiEndBattleText
    :find("perfected", 1, true) ~= nil, true,
  "Lorelei's personal defeat quote is installed too")
run.loader.modOptions.trainer_rematch = { language = "de" }
T.eq(pg.gymDialogue(pgd.gyms[6], "crown", "intro")
    :find("Zukünfte", 1, true) ~= nil, true,
  "Sabrina's German Crown challenge is localized")
T.eq(pg.gymRestDialogue(pgd.gyms[3], "master", 27)
    :find("27 Schritten", 1, true) ~= nil, true,
  "Surge's personal German cooldown reports the exact plural step count")
run.loader.modOptions.trainer_rematch = nil
T.eq(pg.legendaryAvailable("ARTICUNO", pgState, pgSave), false,
  "legendaries stay sealed before the Apex Champion")
run.loader.modOptions.trainer_rematch = { legend_articuno = "vanilla" }
T.eq(pg.legendaryAvailable("ARTICUNO", pgState, pgSave), true,
  "VANILLA Articuno is available without the Apex Champion")
run.loader.modOptions.trainer_rematch = { legend_articuno = "off" }
T.eq(pg.legendaryAvailable("ARTICUNO", pgState, pgSave), false,
  "OFF removes the Articuno encounter")
run.loader.modOptions.trainer_rematch = nil

pgState.apexChampion = true
T.eq(pg.phaseFor(pgState, pgSave), "legend_hunt",
  "the Apex Champion opens the legendary hunt")
T.eq(pg.legendaryAvailable("ARTICUNO", pgState, pgSave), true,
  "the Kanto birds unlock after the Apex Champion")
T.eq(pg.legendaryAvailable("RAIKOU", pgState, pgSave), true,
  "the roaming beasts unlock after the Apex Champion")
T.eq(pg.legendaryAvailable("LUGIA", pgState, pgSave), false,
  "Lugia waits for all three birds")
run.loader.modOptions.trainer_rematch = {
  legend_articuno = "off", legend_zapdos = "off", legend_moltres = "off",
}
T.eq(pg.legendaryAvailable("LUGIA", pgState, pgSave), true,
  "disabled bird encounters do not make Lugia impossible to unlock")
run.loader.modOptions.trainer_rematch = nil
for _, id in ipairs({ "ARTICUNO", "ZAPDOS", "MOLTRES" }) do
  pgState.catches[id] = true
end
T.eq(pg.legendaryAvailable("LUGIA", pgState, pgSave), true,
  "catching all three birds reveals Lugia")
T.eq(pg.legendaryAvailable("HO_OH", pgState, pgSave), false,
  "Ho-Oh waits for all three beasts")
for _, id in ipairs({ "RAIKOU", "ENTEI", "SUICUNE" }) do
  pgState.catches[id] = true
end
T.eq(pg.legendaryAvailable("HO_OH", pgState, pgSave), true,
  "catching all three beasts reveals Ho-Oh")
pgState.catches.LUGIA, pgState.catches.HO_OH = true, true
T.eq(pg.crownUnlocked(pgState, pgSave), true,
  "Lugia and Ho-Oh together unlock the Crown Circuit")
T.eq(pg.legendaryAvailable("CELEBI", pgState, pgSave), true,
  "Celebi becomes the secret final encounter")
T.eq(pg.phaseFor(pgState, pgSave), "crown_gyms",
  "the Crown Circuit starts with the leaders")
for _, gym in ipairs(pgd.gyms) do pgState.crownWins[gym.key] = true end
T.eq(pg.eliteTier(pgState, pgSave), "crown",
  "eight Crown wins replace the Elite Four with level-100 rosters")
T.eq(pg.phaseFor(pgState, pgSave), "crown_elite",
  "the final Elite Four is the last circuit stage")
pgState.crownChampion = true
T.eq(pg.phaseFor(pgState, pgSave), "complete",
  "the Crown Champion completes the expansion")

for _, gym in ipairs(pgd.gyms) do
  T.eq(#gym.master, 6, gym.name .. " has a full Master team")
  T.eq(#gym.crown, 6, gym.name .. " has a full Crown team")
  for _, slot in ipairs(gym.crown) do
    T.eq(slot.level, 100, gym.name .. " Crown slots are level 100")
    T.eq(#slot.moves, 4, gym.name .. " Crown slots have four fixed moves")
  end
end
for class, team in pairs(pgd.apex) do
  T.eq(#team, 6, class .. " has a six-mon Apex roster")
  for _, slot in ipairs(team) do
    T.eq(slot.level >= 90 and slot.level <= 100, true,
      class .. " stays inside the Apex level curve")
  end
end
for class, team in pairs(pgd.crown) do
  for _, slot in ipairs(team) do
    T.eq(slot.level, 100, class .. " Crown roster is level 100")
  end
end
T.eq(pgd.crown.OPP_RIVAL3[1].species, "MEWTWO",
  "the final Champion opens with a legendary")
T.eq(pgd.crown.OPP_RIVAL3[6].species, "HO_OH",
  "the final Champion closes with Ho-Oh")
run.loader.modOptions.trainer_rematch = { legend_raikou = false }
local noRaikou = pg.enabledTeam(pgd.crown.OPP_RIVAL3)
T.eq(noRaikou[2].species, "JOLTEON",
  "disabling Raikou also removes it from boss rosters")
T.eq(pg.gymDialogue(pgd.gyms[3], "crown", "intro")
    :find("No legendary backup", 1, true) ~= nil, true,
  "Surge does not mention Raikou when its option is disabled")
T.eq(pg.eliteDialogue("OPP_RIVAL3", "crown", "before")
    :find("changed", 1, true) ~= nil, true,
  "the Crown Champion acknowledges a legendary option change")
T.eq(pgd.crown.OPP_RIVAL3[2].species, "RAIKOU",
  "option filtering never mutates the canonical Crown roster")
run.loader.modOptions.trainer_rematch = nil

-- ------------------------------------------------ narrative event layer

local event = pg.events
T.neq(event, nil, "the post-game narrative event layer is installed")
local introCount = 0
for _, species in ipairs(pgd.legendOrder) do
  introCount = introCount + 1
  T.eq(type(pgd.dialogue.legendIntros[species].en), "string",
    species .. " has an English cinematic introduction")
  T.eq(type(pgd.dialogue.legendIntros[species].de), "string",
    species .. " has a German cinematic introduction")
end
T.eq(introCount, 10, "all ten legends have cinematic introductions")
local reactionCount = 0
for _, row in pairs(pgd.dialogue.world) do
  reactionCount = reactionCount + 1
  for _, key in ipairs({ "rumor", "apex", "hunt", "crown", "complete" }) do
    T.eq(type(row[key].en), "string",
      "every world reaction phase has English text")
    T.eq(type(row[key].de), "string",
      "every world reaction phase has German text")
  end
end
T.eq(reactionCount, 7,
  "seven witnesses across Kanto react to the post-game events")

local eventSave = {
  flags = { EVENT_BEAT_CHAMPION_RIVAL = true }, hallOfFame = { {} },
  pokedex = { seen = {}, owned = {} },
}
local eventState = {
  masterWins = {}, crownWins = {}, eliteApexWins = {},
  eliteCrownWins = {}, catches = {}, roamers = {}, bossRest = {},
}
eventState.masterWins.brock = true
local earlyLog = event.researchLog(eventState, eventSave)
T.eq(earlyLog:find("OAK RESEARCH LOG", 1, true) ~= nil, true,
  "Oak's research log has an in-world English heading")
T.eq(earlyLog:find("Progress: 1/8", 1, true) ~= nil, true,
  "the research log reports Master Circuit progress")
T.eq(earlyLog:find("SEALED", 1, true) ~= nil, true,
  "the research log explains pre-Apex legendary seals")
T.eq(event.worldReaction("PALLET_TOWN", "PALLETTOWN_FISHER",
    eventState, eventSave):find("sunset", 1, true) ~= nil, true,
  "Pallet Town reacts to the first legendary rumors")

for _, gym in ipairs(pgd.gyms) do eventState.masterWins[gym.key] = true end
eventState.apexChampion = true
eventState.catches.ARTICUNO = true
eventState.roamers.RAIKOU = "ROUTE_10"
local huntLog = event.researchLog(eventState, eventSave)
T.eq(huntLog:find("ARTICUNO:\nCAUGHT", 1, true) ~= nil, true,
  "the research log marks captured legends")
T.eq(huntLog:find("RAIKOU:\nROUTE 10", 1, true) ~= nil, true,
  "the research log reports a roaming beast's current route")
T.eq(event.huntRivalAvailable(eventState, eventSave), true,
  "catching a first legend unlocks the one-time Rival hunt event")
T.eq(#pgd.huntRival.team, 6,
  "the legendary-hunt Rival brings a full adjusted team")
for _, slot in ipairs(pgd.huntRival.team) do
  T.eq(slot.level, 100, "the Rival's hunter team is level 100")
  T.eq(forbiddenRecruit[slot.species], nil,
    "the Rival's hunter team uses no legendary Pokémon")
end
local archive = event.trophyText(eventState, eventSave, {
  a = { rematches = 3 }, b = { rematches = 4 },
})
T.eq(archive:find("FIELD REMATCHES: 7", 1, true) ~= nil, true,
  "the Crown Archive totals all field rematches")
T.eq(archive:find("MASTER CRESTS: 8/8", 1, true) ~= nil, true,
  "the Crown Archive records the Master Circuit")
run.loader.modOptions.trainer_rematch = { language = "de" }
T.eq(event.researchLog(eventState, eventSave)
    :find("EICHS FORSCHUNGSLOG", 1, true) ~= nil, true,
  "the research log is fully localized in German")
T.eq(event.legendIntro("HO_OH")
    :find("Sieben Farben", 1, true) ~= nil, true,
  "Ho-Oh's cinematic introduction follows the selected language")
run.loader.modOptions.trainer_rematch = {
  legend_articuno = "off", legend_zapdos = "off",
  legend_moltres = "off", legend_mewtwo = "off",
  legend_raikou = false, legend_entei = false, legend_suicune = false,
  legend_lugia = false, legend_ho_oh = false, legend_celebi = false,
}
T.eq(event.enabledLegendCount(), 0,
  "the event layer recognizes an all-legendaries-off configuration")
T.eq(event.worldReaction("PALLET_TOWN", "PALLETTOWN_FISHER",
    eventState, eventSave), nil,
  "legendary world rumors disappear when every encounter is disabled")
T.eq(event.huntRivalAvailable(eventState, eventSave), false,
  "the legendary-hunt Rival is skipped when every encounter is disabled")
run.loader.modOptions.trainer_rematch = nil

-- ------------------------------------------------ install (stubbed deps)

local pushed = {}
local calls = { vanillaTalk = 0, engaged = 0, battles = {}, after = 0 }
local game = {
  data = Data,
  save = { money = 3000, inventory = {}, bagOrder = {},
           defeatedTrainers = {}, flags = {}, modData = {},
           player = { name = "RED" },
           party = { { level = 5 }, { level = 6 }, { level = 7 } } },
  stack = { push = function(_, s) table.insert(pushed, s) end },
}
run.loader.modSave = game.save.modData
do
  local onboarding = assert(ex.onboarding)
  T.eq(onboarding.text():find("ASCENDANT", 1, true) ~= nil, true,
    "the one-time 5.0 orientation introduces the Ascendant menu")
  T.eq(onboarding.text():find("ROUTE 5", 1, true) ~= nil, true,
    "the orientation points both new and upgraded saves to Route 5")
  T.eq(onboarding.text():find("ELM", 1, true) ~= nil, true,
    "the orientation introduces Elm's research line in English")
  local onboardingState = onboarding.state()
  onboardingState.shown = false
  T.eq(onboarding.shouldShow(game), false,
    "the 5.0 orientation stays hidden before the Hall of Fame")
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  T.eq(onboarding.shouldShow(game), true,
    "an existing post-game save receives the 5.0 orientation once")
  onboardingState.shown = true
  T.eq(onboarding.shouldShow(game), false,
    "the orientation does not repeat after save, restart or mod re-enable")
end
local textBoxStub = {
  new = function(g, text, onDone, opts)
    return { text = text, onDone = onDone, opts = opts or {} }
  end,
  substitute = function(g, text) return "sub:" .. text end,
}
local Pokemon = require("src.pokemon.Pokemon")
local battleStateStub = {
  newTrainer = function(g, cls, party)
    local record = g.data.trainers[cls]
    local enemyParty = {}
    for _, slot in ipairs(record.parties[party]) do
      local species = g.data.pokemon[slot.species] and slot.species or "FIXMON_A"
      enemyParty[#enemyParty + 1] =
        Pokemon.new(g.data, species, slot.level, function() return 8 end)
    end
    local lead = enemyParty[1]
    local b = { game = g, trainer = record, enemyParty = enemyParty,
                enemy = { mon = lead, curStats = lead.stats,
                          curMoves = lead.moves, shownHP = lead.hp },
                queue = {} }
    calls.battles[#calls.battles + 1] = { cls = cls, party = party, battle = b }
    return b
  end,
  -- vanilla-shaped victory: award money, queue the prize line + a flavor line
  enemyMonFainted = function(self)
    local prize = (self.trainer.baseMoney or 0) * self.enemy.mon.level
    self.game.save.money = self.game.save.money + prize
    self:sayNext(("RED got ¥%d\nfor winning!"):format(prize))
    self:sayNext("RED defeated\nYOUNGSTER!")
  end,
  finish = function(self)
    if self.payDay and self.result == "win" then
      self.game.save.money = self.game.save.money + self.payDay
      self.paid = self.payDay
    end
  end,
}
local runtimeStub = { emit = function(_, name, payload)
  calls.engaged = calls.engaged + 1 end }
local scriptedFlag = { value = false }
local mapScriptsStub = { talkScript = function()
  return scriptedFlag.value end }
local vanillaTalkTo = function() calls.vanillaTalk = calls.vanillaTalk + 1 end
local vanillaEngageTrainer = function(self, npc, onDone)
  calls.vanillaEngaged = (calls.vanillaEngaged or 0) + 1
  game.save.defeatedTrainers[npc.id] = true
  if onDone then onDone() end
end
local overworldStub = {
  talkTo = vanillaTalkTo,
  engageTrainer = vanillaEngageTrainer,
}

local installDeps = {
  overworld = overworldStub, battleState = battleStateStub,
  textBox = textBoxStub, runtime = runtimeStub,
  mapScripts = mapScriptsStub,
  random = function(lo) return lo end,
  lootRandom = function() return 10000 end,
}
ex.install(game, installDeps)

-- A Master Leader already beaten once remains repeatable, but reports the
-- exact boss cooldown before offering another battle.
game.save.hallOfFame = { {} }
game.save.pokedex = { seen = {}, owned = {} }
pg.game = game
local livePostgame = pg.state()
livePostgame.masterWins.brock = true
livePostgame.bossRest["master:brock"] = 42
local masterNpc = {
  def = { trainerClass = "OPP_BROCK" }, frozen = false,
  facePlayer = function() end,
}
local masterOw = { map = { id = "PEWTER_GYM" }, player = {} }
local realTextBoxModule = package.loaded["src.render.TextBox"]
package.loaded["src.render.TextBox"] = textBoxStub
run.loader.modOptions.trainer_rematch = { language = "de" }
T.eq(pg.handleTalk(masterOw, masterNpc, game), true,
  "a resting Master Leader consumes the conversation")
package.loaded["src.render.TextBox"] = realTextBoxModule
T.eq(pushed[#pushed].text:find("42", 1, true) ~= nil, true,
  "a resting Master Leader reports the exact steps remaining")
T.eq(pushed[#pushed].text:find("Schritten", 1, true) ~= nil, true,
  "Master Leader cooldown dialogue follows the selected language")
run.loader.modOptions.trainer_rematch = nil

pushed = {}
local labScientist = {
  def = { name = "OAKSLAB_SCIENTIST1" }, frozen = false,
  facePlayer = function() end,
}
local labOw = {
  map = { id = "OAKS_LAB" }, player = {},
  afterBattle = function() calls.after = calls.after + 1 end,
  pushBattle = function(self, battle) calls.pushedBattle = battle end,
}
package.loaded["src.render.TextBox"] = textBoxStub
T.eq(pg.handleTalk(labOw, labScientist, game), true,
  "Oak's Lab scientist opens the research log after the Hall of Fame")
package.loaded["src.render.TextBox"] = realTextBoxModule
T.eq(pushed[#pushed].text:find("OAK RESEARCH LOG", 1, true) ~= nil, true,
  "the live Lab conversation displays the research log")

livePostgame.apexChampion = true
livePostgame.catches.ARTICUNO = true
pushed = {}
local huntRivalNpc = {
  def = { name = pgd.huntRival.name, trainerClass = pgd.huntRival.class },
  frozen = false,
  facePlayer = function() end,
}
package.loaded["src.render.TextBox"] = textBoxStub
T.eq(pg.handleTalk(labOw, huntRivalNpc, game), true,
  "the legendary-hunt Rival consumes his Lab conversation")
T.eq(type(pushed[#pushed].opts.choice), "function",
  "the Rival event offers its own YES/NO battle prompt")
pushed[#pushed].opts.choice(false)
package.loaded["src.render.TextBox"] = realTextBoxModule
T.eq(pushed[#pushed].text:find("will not", 1, true) ~= nil, true,
  "declining the Rival event gets a character-specific response")
pushed[#pushed].onDone()
T.eq(huntRivalNpc.frozen, false,
  "closing the Rival decline response releases the NPC")

pushed = {}
local huntRivalWinNpc = {
  def = { name = pgd.huntRival.name, trainerClass = pgd.huntRival.class },
  frozen = false,
  facePlayer = function() end,
}
local oldRivalRecord = Data.trainers.OPP_RIVAL3
Data.trainers.OPP_RIVAL3 = {
  baseMoney = 1, parties = { pgd.huntRival.team },
}
local oldBattleStateModule = package.loaded["src.battle.BattleState"]
package.loaded["src.render.TextBox"] = textBoxStub
package.loaded["src.battle.BattleState"] = battleStateStub
T.eq(pg.handleTalk(labOw, huntRivalWinNpc, game), true,
  "the Rival's accepted event is handled in Oak's Lab")
pushed[#pushed].opts.choice(true)
package.loaded["src.battle.BattleState"] = oldBattleStateModule
package.loaded["src.render.TextBox"] = realTextBoxModule
Data.trainers.OPP_RIVAL3 = oldRivalRecord
T.eq(calls.pushedBattle.postgameHuntRival, true,
  "accepting starts the dedicated legendary-hunter battle")
T.eq(calls.pushedBattle.rematch, true,
  "the Rival event is marked as a no-money rematch battle")
calls.pushedBattle.onFinish("win")
T.eq(livePostgame.huntRivalWon, true,
  "winning the Rival event is stored permanently")
T.eq(pushed[#pushed].text:find("Take the data", 1, true) ~= nil, true,
  "the Rival shares his hunt report after losing")
pushed[#pushed].onDone()
T.eq(huntRivalWinNpc.frozen, false,
  "finishing the Rival event releases its NPC")
livePostgame.apexChampion = nil
livePostgame.catches.ARTICUNO = nil
livePostgame.huntRivalWon = nil
calls.battles = {}
calls.pushedBattle = nil
pushed = {}
game.save.hallOfFame = {}

local npcSerial = 0
local function freshNpc(id)
  npcSerial = npcSerial + 1
  local npc = {
    id = id or ("FIX_ROUTE_obj_" .. npcSerial),
    def = { trainerClass = "OPP_FIX_YOUNGSTER", trainerParty = 1,
            text = "X", index = 1 },
    frozen = false,
    facePlayer = function() end,
  }
  local bucket = game.save.modData.trainer_rematch or {}
  game.save.modData.trainer_rematch = bucket
  bucket.trainers = bucket.trainers or {}
  bucket.trainers[npc.id] = { rematches = 0, readyAt = 0 }
  return npc
end
local ow = {
  map = { id = "FIX_ROUTE", def = { label = "FixRoute" } },
  player = {},
  trainerDefeated = function() return true end,
  afterBattle = function() calls.after = calls.after + 1 end,
  pushBattle = function(self, battle) calls.pushedBattle = battle end,
}

-- A0: a defeated trainer whose old save has no mod record is repaired lazily
local lazyNpc = freshNpc("FIX_ROUTE_obj_lazy")
game.save.modData.trainer_rematch.trainers[lazyNpc.id] = nil
overworldStub.talkTo(ow, lazyNpc)
T.eq(pushed[#pushed].text:find("151 more steps.", 1, true) ~= nil, true,
  "a missing defeated-trainer record starts a visible initial rest")
T.eq(pushed[#pushed].opts.choice, nil,
  "the repaired trainer cannot offer an immediate rematch")

-- A: beaten generic trainer -> rematch prompt with the class line
pushed = {}
local npc = freshNpc()
overworldStub.talkTo(ow, npc)
T.eq(#pushed, 1, "rematch prompt pushed")
T.eq(pushed[1].text, ex.resolveLine("OPP_FIX_YOUNGSTER"),
  "prompt shows the class line")
T.eq(type(pushed[1].opts.choice), "function", "prompt carries a YES/NO choice")
T.eq(npc.frozen, true, "npc frozen while the prompt is up")

-- B: YES -> battle starts, flagged as rematch, no victory rewards
pushed[1].opts.choice(true)
T.eq(calls.engaged, 1, "trainer_engaged emitted")
T.eq(#calls.battles, 1, "one battle created")
T.eq(calls.battles[1].cls, "OPP_FIX_YOUNGSTER", "battle uses the npc class")
T.eq(calls.battles[1].party, 1, "battle uses the npc party")
local b = calls.battles[1].battle
T.eq(b.rematch, true, "battle flagged as rematch")
T.eq(b.rematchNumber, 1, "first repeat is identified as rematch one")
T.eq(b.rematchLevelBoost, 2, "first rematch receives the default level boost")
T.eq(b.enemyParty[1].level,
  Data.trainers.OPP_FIX_YOUNGSTER.parties[1][1].level + 2,
  "the actual enemy party is stronger, not just the preview")
local baseLead = Pokemon.new(Data, "FIXMON_A", 5, function() return 8 end)
T.eq(b.enemyParty[1].stats.hp > baseLead.stats.hp, true,
  "the boosted level recalculates real battle stats")
local learnedAtSeven = false
for _, move in ipairs(b.enemyParty[1].moves) do
  if move.id == "FIX_EMBERISH" then learnedAtSeven = true break end
end
T.eq(learnedAtSeven, true, "training can teach newly reached level-up moves")
T.eq(b.endBattleText, "sub:Well fixed!", "loss line still shown")
T.neq(b.onFinish, nil, "onFinish wired")
local afterCount = calls.after
b.onFinish("win")
T.eq(calls.after, afterCount + 1, "afterBattle ran")
T.eq(pushed[#pushed].text:find("FIELD KIT", 1, true) ~= nil, true,
  "the first won rematch awards the optional HM Field Kit")
T.eq(npc.frozen, true,
  "the trainer stays frozen until the Field Kit reward text closes")
pushed[#pushed].onDone()
T.eq(npc.frozen, false, "npc unfrozen after the reward")
local savedState = game.save.modData.trainer_rematch.trainers[npc.id]
T.eq(savedState.rematches, 1, "completed rematch count persists per trainer")
T.eq(ex.remainingSteps(npc.id), 151, "trainer starts the configured rest")

-- B2: the same trainer refuses until enough real world steps pass
pushed = {}
overworldStub.talkTo(ow, npc)
T.eq(#pushed, 1, "resting trainer shows one status box")
T.eq(pushed[1].text:find("151 more steps.", 1, true) ~= nil, true,
  "rest status shows the exact remaining steps")
T.eq(pushed[1].text:find("\f", 1, true) ~= nil, true,
  "the trainer's normal text follows the step status as a second page")
T.eq(pushed[1].text:find("Nice fixture.", 1, true) ~= nil, true,
  "the second cooldown page preserves the normal post-battle line")
T.eq(pushed[1].opts.choice, nil, "resting trainer offers no battle choice")
pushed[1].onDone()
for _ = 1, 150 do run.loader.events:emit("world.stepped", {}) end
T.eq(ex.remainingSteps(npc.id), 1, "only completed world steps count down")
pushed = {}
overworldStub.talkTo(ow, npc)
T.eq(pushed[1].text:find("1 more step.", 1, true) ~= nil, true,
  "the final cooldown step is reported in singular")
run.loader.events:emit("world.stepped", {})
T.eq(ex.remainingSteps(npc.id), 0, "trainer becomes ready at the deadline")
pushed = {}
overworldStub.talkTo(ow, npc)
T.eq(pushed[1].text, ex.resolveLine("OPP_FIX_YOUNGSTER"),
  "the challenge returns after the cooldown")
pushed[1].opts.choice(true)
local b2 = calls.battles[#calls.battles].battle
T.eq(b2.rematchNumber, 2, "the returning trainer starts rematch two")
T.eq(b2.rematchLevelBoost, 4, "the returning trainer has grown again")
T.eq(b2.enemyParty[1].level,
  Data.trainers.OPP_FIX_YOUNGSTER.parties[1][1].level + 4,
  "second-rematch level growth reaches the battle party")
T.eq(#b2.enemyParty, 3,
  "the second growth tier expands a two-Pokémon trainer to three")
T.eq(b2.rematchRecruits, 1,
  "the rematch battle records one newly recruited party member")
T.eq(b2.enemyParty[3].species, "FIXMON_B",
  "the recruited Pokémon is appended to the actual battle party")
T.eq(b2.enemyParty[3].level, 9,
  "the recruit receives the same final rematch level growth")

-- C: NO -> the class reacts, then the vanilla post-battle line as a page
pushed = {}
local npc2 = freshNpc()
overworldStub.talkTo(ow, npc2)
pushed[1].opts.choice(false)
T.eq(#pushed, 2, "decline pushes the reaction box")
T.eq(pushed[2].text:lower():find("scared", 1, true) ~= nil, true,
  "decline shows the class reaction")
T.eq(pushed[2].text:find("Nice fixture.", 1, true) ~= nil, true,
  "vanilla after text kept as a second page")
T.eq(pushed[2].text:find("\f", 1, true) ~= nil, true, "pages joined by \\f")
T.eq(calls.vanillaTalk, 0, "no vanilla fallback on decline with after text")
pushed[2].onDone()
T.eq(npc2.frozen, false, "npc unfrozen after the reaction box")

-- D: decline with no post-battle header -> just the default reaction
pushed = {}
local owNoHeader = {
  map = { id = "SOMEWHERE", def = { label = "Nowhere" } },
  player = {},
  trainerDefeated = function() return true end,
  afterBattle = function() end,
  pushBattle = function() end,
}
local npc3 = freshNpc()
overworldStub.talkTo(owNoHeader, npc3)
pushed[1].opts.choice(false)
T.eq(#pushed, 2, "reaction box pushed without a header")
T.eq(pushed[2].text, ex.resolveDecline("OPP_FIX_YOUNGSTER"),
  "default reaction used when the class has no header")
T.eq(pushed[2].text:find("\f", 1, true) == nil, true,
  "no \\f page when there is no after text")
T.eq(calls.vanillaTalk, 0, "no vanilla fallback on decline without a header")
pushed[2].onDone()
T.eq(npc3.frozen, false, "npc unfrozen after the reaction box")

-- E: unbeaten trainers keep the vanilla flow
calls.vanillaTalk = 0
local owUnbeaten = {
  map = { id = "FIX_ROUTE", def = { label = "FixRoute" } },
  player = {},
  trainerDefeated = function() return false end,
  afterBattle = function() end,
  pushBattle = function() end,
}
overworldStub.talkTo(owUnbeaten, freshNpc())
T.eq(calls.vanillaTalk, 1, "unbeaten trainer uses the vanilla talk")

-- E2: winning the original encounter starts the first rest period
local originalNpc = freshNpc("FIX_ROUTE_obj_original")
local originalDone = 0
local owOriginal = {
  map = ow.map,
  trainerDefeated = function(_, candidate)
    return game.save.defeatedTrainers[candidate.id] == true
  end,
}
overworldStub.engageTrainer(owOriginal, originalNpc, function()
  originalDone = originalDone + 1
end)
T.eq(calls.vanillaEngaged, 1, "the original trainer flow still runs")
T.eq(originalDone, 1, "the original completion callback still runs")
T.eq(ex.remainingSteps(originalNpc.id), 151,
  "a newly beaten trainer is not immediately ready for a rematch")

-- E2b: ignoring a ready trainer does not freeze its strength. The visible
-- cooldown ends first; each additional silent cooldown grows the next team
-- while the trainer remains continuously available.
for _ = 1, 151 do run.loader.events:emit("world.stepped", {}) end
T.eq(ex.remainingSteps(originalNpc.id), 0,
  "the ignored trainer becomes ready after the visible cooldown")
T.eq(ex.trainingCycles(originalNpc.id), 0,
  "becoming ready starts rather than completes the first silent cycle")
for _ = 1, 150 do run.loader.events:emit("world.stepped", {}) end
T.eq(ex.trainingCycles(originalNpc.id), 0,
  "an incomplete silent cycle grants no speculative growth")
run.loader.events:emit("world.stepped", {})
T.eq(ex.trainingCycles(originalNpc.id), 1,
  "a completed silent counter grows an ignored trainer in the background")
T.eq(ex.remainingSteps(originalNpc.id), 0,
  "silent training never makes a ready trainer unavailable again")
pushed = {}
overworldStub.talkTo(ow, originalNpc)
pushed[1].opts.choice(true)
local idleBattle = calls.battles[#calls.battles].battle
T.eq(idleBattle.rematchNumber, 1,
  "the ignored trainer still calls this its first actual rematch")
T.eq(idleBattle.rematchTrainingCycles, 1,
  "the battle records the completed silent training cycle")
T.eq(idleBattle.rematchLevelBoost, 4,
  "one silent cycle raises the first rematch from +2 to +4 levels")

-- E3: enabling the mod on an existing CONTINUE slot seeds old victories
local oldTimerSave = {
  trainer_rematch = {
    step_clock = 100,
    trainers = {
      OLD_TIMER = {
        rematches = 1, trainingCycles = 0,
        readyAt = 228, lastRest = 128,
        nextTrainingAt = 356, lastTraining = 128,
      },
    },
  },
}
run.loader.modSave = oldTimerSave
ex.migrateRestTimers({ random = function(_, hi) return hi end })
local migratedTimer = oldTimerSave.trainer_rematch.trainers.OLD_TIMER
T.eq(migratedTimer.readyAt, 2610,
  "an active legacy cooldown rerolls once into the expanded range")
T.eq(migratedTimer.nextTrainingAt, 5120,
  "the following silent cycle adopts the expanded range too")

local legacySave = {
  defeatedTrainers = { LEGACY_ROUTE_obj_3 = true },
  modData = {},
}
run.loader.modSave = legacySave.modData
run.loader.events:emit("save.loaded", { save = legacySave })
local legacyLeft = ex.remainingSteps("LEGACY_ROUTE_obj_3")
T.eq(legacyLeft >= 151 and legacyLeft <= 2510, true,
  "loaded saves give previously beaten trainers an initial rest")
run.loader.modSave = game.save.modData

-- F: scripted trainers (gym leaders, rivals) keep their flow
calls.vanillaTalk = 0
pushed = {}
scriptedFlag.value = true
overworldStub.talkTo(ow, freshNpc())
T.eq(calls.vanillaTalk, 1, "scripted trainer skips the rematch prompt")
T.eq(#pushed, 0, "no rematch prompt for scripted trainers")
scriptedFlag.value = false

-- G: rematch win awards no money and drops the prize line
local moneyBefore = game.save.money
local rematch = { game = game, rematch = true,
  trainer = { baseMoney = 150, name = "FIX YOUNGSTER" },
  enemy = { mon = { level = 10 } }, queue = {},
  sayNext = function(self, text) table.insert(self.queue, text) end }
battleStateStub.enemyMonFainted(rematch)
T.eq(game.save.money, moneyBefore, "rematch awards no money")
T.eq(#rematch.queue, 1, "prize line dropped")
T.eq(rematch.queue[1], "RED defeated\nYOUNGSTER!", "flavor line kept")
T.eq(rematch.trainer.baseMoney, 150, "shared trainer record untouched")

-- H: the first (non-rematch) fight still pays
moneyBefore = game.save.money
local normal = { game = game, rematch = false,
  trainer = { baseMoney = 150, name = "FIX YOUNGSTER" },
  enemy = { mon = { level = 10 } }, queue = {},
  sayNext = function(self, text) table.insert(self.queue, text) end }
battleStateStub.enemyMonFainted(normal)
T.eq(game.save.money, moneyBefore + 1500, "normal win still pays")
T.eq(#normal.queue, 2, "prize line kept on normal wins")

-- I: Pay Day pays nothing on a rematch
moneyBefore = game.save.money
local pay = { game = game, rematch = true, payDay = 500, result = "win" }
battleStateStub.finish(pay)
T.eq(pay.paid, nil, "pay day suppressed on rematch")
T.eq(game.save.money, moneyBefore, "no money from pay day on rematch")

-- J: Pay Day still pays in normal battles
moneyBefore = game.save.money
local pay2 = { game = game, rematch = false, payDay = 500, result = "win" }
battleStateStub.finish(pay2)
T.eq(pay2.paid, 500, "pay day pays normally")
T.eq(game.save.money, moneyBefore + 500, "money credited normally")

-- K: a class with a marked rematch team (the Yellow Legacy pattern) uses
-- that party for the rematch instead of the trainer's own -- and since
-- the marked team averages far above the player's party, the class warns
-- first and only battles after a second confirmation
Data.trainers["OPP_FIX_MISTY"] = {
  id = "OPP_FIX_MISTY", name = "MISTY", index = 35, baseMoney = 40,
  parties = {
    { { level = 18, species = "STARYU" }, { level = 21, species = "STARMIE" } },
    { { level = 64, species = "SEADRA" }, { level = 65, species = "STARMIE" } },
  },
  rematchIndex = 2,
}
local mistyBattles = #calls.battles
local pushedBefore = #pushed
local mistyNpc = freshNpc()
mistyNpc.def.trainerClass = "OPP_FIX_MISTY"
overworldStub.talkTo(ow, mistyNpc)
T.eq(#pushed, pushedBefore + 1, "the rematch prompt is pushed")
pushed[#pushed].opts.choice(true)
T.eq(#calls.battles, mistyBattles, "no battle yet: the warning comes first")
T.eq(#pushed, pushedBefore + 2, "the strength warning is pushed")
T.eq(pushed[#pushed].text, ex.resolveWarning("OPP_FIX_MISTY"),
  "the warning speaks in the class's default voice")
pushed[#pushed].opts.choice(true)
T.eq(#calls.battles, mistyBattles + 1, "confirming the warning starts the battle")
T.eq(calls.battles[#calls.battles].party, 2,
  "the marked rematch team is used")
T.eq(calls.battles[#calls.battles].battle.rematch, true,
  "the marked-rematch battle is still a rematch")

-- L: declining the warning walks away without a battle
local lBefore = #calls.battles
local pushedL = #pushed
mistyNpc.frozen = false
overworldStub.talkTo(ow, mistyNpc)
pushed[#pushed].opts.choice(true)
pushed[#pushed].opts.choice(false)
T.eq(#calls.battles, lBefore, "declining the warning starts no battle")
T.eq(#pushed, pushedL + 3, "the decline line follows")

-- M: a small level gap skips the warning and battles directly
local lvlBattles = #calls.battles
local pushedM = #pushed
local lvlNpc = freshNpc()
overworldStub.talkTo(ow, lvlNpc)
T.eq(#pushed, pushedM + 1, "the rematch prompt is pushed")
pushed[#pushed].opts.choice(true)
T.eq(#calls.battles, lvlBattles + 1, "a close team battles straight away")
T.eq(calls.battles[#calls.battles].party, 1, "it uses the trainer's own party")

-- N: the level-gap math behind the warning
T.eq(ex.levelGap({ { level = 5 }, { level = 7 } },
  { { level = 64 }, { level = 65 } }), 58.5, "the gap is team average minus party average")
T.eq(ex.levelGap({ { level = 60 }, { level = 60 } },
  { { level = 55 }, { level = 55 } }), -5, "an easier team is a negative gap")
T.eq(ex.levelGap(nil, { { level = 64 } }), nil, "an empty party yields no gap")
T.eq(ex.levelGap({ { level = 5 } }, nil), nil, "an empty team yields no gap")

-- O: successful loot, full-bag reservation and later delivery
Data.items.NUGGET = { id = "NUGGET", name = "NUGGET", price = 5000 }
run.loader.modOptions.trainer_rematch = { loot_mode = "balanced" }
installDeps.lootRandom = function() return 2901 end
game.save.inventory, game.save.bagOrder = {}, {}
pushed = {}
local lootNpc = freshNpc("FIX_ROUTE_obj_loot")
overworldStub.talkTo(ow, lootNpc)
pushed[1].opts.choice(true)
local lootBattle = calls.battles[#calls.battles].battle
lootBattle.onFinish("win")
T.eq(game.save.inventory.NUGGET, 1,
  "a winning eligible rematch puts its rolled Nugget in the Bag")
T.eq(pushed[#pushed].text:find("NUGGET", 1, true) ~= nil, true,
  "the player sees the awarded item after the battle")
T.eq(lootNpc.frozen, true,
  "the trainer remains frozen until the loot message closes")
pushed[#pushed].onDone()
T.eq(lootNpc.frozen, false, "closing the loot message releases the trainer")

game.save.inventory, game.save.bagOrder = {}, {}
for i = 1, 20 do
  local id = "FILLER_" .. i
  game.save.inventory[id] = 1
  game.save.bagOrder[i] = id
end
pushed = {}
local fullNpc = freshNpc("FIX_ROUTE_obj_full_loot")
overworldStub.talkTo(ow, fullNpc)
pushed[1].opts.choice(true)
local fullBattle = calls.battles[#calls.battles].battle
fullBattle.onFinish("win")
local fullState =
  game.save.modData.trainer_rematch.trainers[fullNpc.id]
T.eq(game.save.inventory.NUGGET, nil,
  "a full Bag never destroys or silently inserts the rolled item")
T.eq(fullState.pendingLoot.item, "NUGGET",
  "the trainer keeps an undeliverable reward for the player")
pushed[#pushed].onDone()

pushed = {}
overworldStub.talkTo(ow, fullNpc)
T.eq(pushed[1].text:find("BAG is", 1, true) ~= nil, true,
  "talking again explains that the reserved reward still cannot fit")
T.eq(fullState.pendingLoot.item, "NUGGET",
  "the pending reward survives another full-Bag conversation")
pushed[1].onDone()
game.save.inventory.FILLER_1 = nil
pushed = {}
overworldStub.talkTo(ow, fullNpc)
T.eq(game.save.inventory.NUGGET, 1,
  "making room lets the trainer deliver the reserved reward")
T.eq(fullState.pendingLoot, nil,
  "a delivered pending reward is cleared exactly once")
pushed[1].onDone()
installDeps.lootRandom = function() return 10000 end
run.loader.modOptions.trainer_rematch = nil

-- P: an actual circuit battle receives the personal in-battle defeat quote
game.save.hallOfFame = { {} }
for _, gym in ipairs(pgd.gyms) do livePostgame.masterWins[gym.key] = true end
livePostgame.apexChampion = nil
pg.game = game
local eliteBattle = { kind = "trainer", oppClass = "OPP_LORELEI" }
RealRuntime.emit("battle.started", { battle = eliteBattle })
T.eq(eliteBattle.postgameTier, "apex",
  "an active Elite Four battle is tagged with the Apex tier")
T.eq(eliteBattle.rematch, true,
  "an active Elite Four circuit fight is treated as a no-money rematch")
T.eq(eliteBattle.endBattleText:find("perfected", 1, true) ~= nil, true,
  "the circuit battle receives Lorelei's personal defeat quote")

-- ------------------------------------------------ Kanto Ascendant 2.0 systems

local asc = ex.ascendant
local asd = ex.ascendantData
local heritage = ex.eventArchive
local heritageData = ex.eventData
T.neq(asc, nil, "the Ascendant systems controller is exported")
T.neq(asd, nil, "the Ascendant progression data is exported")
T.neq(heritage, nil, "the permanent Event Archive controller is exported")
T.neq(heritageData, nil, "the historical event profiles are exported")
local longestEventLabelEn, longestEventLabelDe = 0, 0
for _, profile in ipairs(heritageData.profiles) do
  longestEventLabelEn = math.max(longestEventLabelEn, #profile.short.en)
  longestEventLabelDe = math.max(longestEventLabelDe, #profile.short.de)
end
T.eq(longestEventLabelEn <= 10, true,
  "English Event Archive labels leave room for their status")
T.eq(longestEventLabelDe <= 10, true,
  "German Event Archive labels leave room for their status")

T.eq(asc.rematchRank(0).key, "rookie",
  "a new field opponent begins at ROOKIE rank")
T.eq(asc.rematchRank(2).key, "veteran",
  "two completed growth tiers reach VETERAN rank")
T.eq(asc.rematchRank(5).key, "expert",
  "five completed growth tiers reach EXPERT rank")
T.eq(asc.rematchRank(10).key, "master",
  "ten completed growth tiers reach MASTER rank")
T.eq(asc.rematchRank(20).key, "legend",
  "twenty completed growth tiers reach LEGEND rank")
T.eq(asc.rankBonusLoot(7500, "veteran", 10), nil,
  "VETERAN rank no longer inflates the configured loot table")
T.eq(asc.rankBonusLoot(8000, "expert", 20), nil,
  "EXPERT rank no longer adds a hidden Rare Candy band")
T.eq(asc.rankBonusLoot(8500, "master", 35), nil,
  "MASTER rank no longer adds a hidden PP Up band")
T.eq(asc.rankBonusLoot(9000, "legend", 50), nil,
  "LEGEND rank no longer adds a hidden Max Revive band")

T.eq(#asd.ranks, 5, "all five field-trainer ranks are defined")
T.eq(#asd.research, 8, "Oak offers eight sequential research assignments")
T.eq(#asd.achievements, 17, "the Crown Archive tracks all seventeen titles")
T.eq(#asd.rocket, 4, "Rocket Resurgence has four consecutive operations")
T.eq(#asd.tournament.opponents, 6,
  "the Grand Tournament has six rotating level-100 opponents")
T.eq(#asd.tournament.rules, 6,
  "the Grand Tournament rotates six different rulesets")
local leaderMissionCount = 0
for key, quest in pairs(asd.gymQuests) do
  leaderMissionCount = leaderMissionCount + 1
  T.eq(type(quest.intro.en), "string",
    key .. " has English personal-mission dialogue")
  T.eq(type(quest.intro.de), "string",
    key .. " has German personal-mission dialogue")
  T.eq(quest.target > 0, true, key .. " has a measurable mission target")
end
T.eq(leaderMissionCount, 8,
  "all eight Gym Leaders have personal missions")
for _, operation in ipairs(asd.rocket) do
  T.eq(#operation.team, 6,
    operation.key .. " has a complete Rocket resurgence team")
  T.eq(type(operation.before.en), "string",
    operation.key .. " has English Rocket dialogue")
  T.eq(type(operation.before.de), "string",
    operation.key .. " has German Rocket dialogue")
end
T.eq(asd.mew.level, 100, "Mew is the level-100 mythic finale")
T.eq(type(asd.mew.clues.oak.text.en), "string",
  "Oak has the first English Mew clue")
T.eq(type(asd.mew.clues.fuji.text.de), "string",
  "Mr. Fuji has the second German Mew clue")
T.eq(type(asd.mew.clues.lab.text.en), "string",
  "the Cinnabar lab has the final English Mew clue")

T.eq(#heritageData.profiles, 6,
  "the archive contains all six Generation-I Kanto event profiles")
T.eq(#heritageData.catchupOrder, 5,
  "the five non-Mew distributions have a deterministic catch-up order")
local heritageCupCount = 0
for id, cup in pairs(heritageData.cups) do
  heritageCupCount = heritageCupCount + 1
  T.eq(#cup.opponents, 3, id .. " has a complete three-round Heritage Cup")
end
T.eq(heritageCupCount, 5,
  "five badge-gated Heritage Cups award the non-Mew events")
local eventPokemon = setmetatable({}, { __index = Data.pokemon })
for _, id in ipairs({ "MAGIKARP", "PIKACHU", "FEAROW", "RAPIDASH", "MEW" }) do
  eventPokemon[id] = Data.pokemon.FIXMON_A
end
local eventMoves = setmetatable({}, { __index = Data.moves })
for _, id in ipairs({
  "SPLASH", "DRAGON_RAGE", "THUNDERSHOCK", "GROWL", "FLY", "SURF",
  "LEER", "FURY_ATTACK", "PAY_DAY", "EMBER", "FIRE_SPIN", "STOMP", "POUND",
}) do
  eventMoves[id] = { id = id, name = id:gsub("_", " "), pp = 20 }
end
local eventDataSet = setmetatable({
  pokemon = eventPokemon, moves = eventMoves,
}, { __index = Data })
local eventGame = {
  data = eventDataSet,
  save = {
    player = { name = "RED", id = 1234 },
    party = {}, inventory = {}, flags = {},
    pokedex = { seen = {}, owned = {} },
  },
}
local historicalKarp = Pokemon.new(eventDataSet, "MAGIKARP", 5,
  function() return 8 end)
heritage.stampProfile(eventGame, historicalKarp,
  heritage.profile("university_magikarp"), "UNIVERSITY CUP")
T.eq(historicalKarp.level, 15,
  "University Magikarp keeps its historical distribution level")
T.eq(historicalKarp.moves[2].id, "DRAGON_RAGE",
  "University Magikarp keeps its unusual historical move")
T.eq(historicalKarp.eventDistribution.id, "university_magikarp",
  "event provenance is stored directly on the Pokémon")
local historicalMew = Pokemon.new(eventDataSet, "MEW", 100,
  function() return 8 end)
heritage.stampProfile(eventGame, historicalMew,
  heritage.profile("distribution_mew"), "FARAWAY ISLAND FINALE")
T.eq(historicalMew.level, 5,
  "the optional historical Mew profile restores level 5")
T.eq(historicalMew.dvs.attack, 10,
  "historical Mew keeps the fixed distribution DVs")
local eventGift = heritage.give(eventGame, "flying_pikachu", "BALLOON CUP")
T.eq(type(eventGift), "string",
  "a Heritage Cup can deliver its one-time event prize")
T.eq(eventGame.save.party[1].moves[3].id, "FLY",
  "Flying Pikachu arrives with its event-exclusive move")
T.eq(heritage.state().claimed.flying_pikachu.origin, "BALLOON CUP",
  "the Event Archive permanently records the prize origin")

local ascState = asc.state()
ascState.bossBattles = {}
ascState.gymQuests = {}
ascState.cycle = 0
local adaptiveSource = {
  { species = "FIXMON_A", level = 90, moves = { "TACKLE" } },
  { species = "FIXMON_B", level = 91, moves = { "TACKLE" } },
  { species = "FIXMON_A", level = 92, moves = { "TACKLE" } },
}
local adaptiveGame = { data = Data, save = { party = {} } }
local adaptiveA = asc.selectBossTeam(adaptiveSource,
  { kind = "gym", key = "brock", tier = "master" }, adaptiveGame)
T.eq(adaptiveA[1].species, "FIXMON_A",
  "the first adaptive boss meeting preserves the inspected base order")
ascState.bossBattles["gym:brock:master"] = 1
local adaptiveB = asc.selectBossTeam(adaptiveSource,
  { kind = "gym", key = "brock", tier = "master" }, adaptiveGame)
T.eq(adaptiveB[1].species, "FIXMON_B",
  "a repeat boss meeting rotates its lead and battle plan")
ascState.gymQuests.brock = { done = true }
local adaptiveSignature = asc.selectBossTeam(adaptiveSource,
  { kind = "gym", key = "brock", tier = "master" }, adaptiveGame)
T.eq(adaptiveSignature[#adaptiveSignature].species, "AERODACTYL",
  "finishing Brock's mission unlocks his signature roster variant")
T.eq(adaptiveSource[3].species, "FIXMON_A",
  "adaptive selection never mutates the shared base roster")
T.eq(asc.cycleRule(1, "rotating"), "no_items",
  "Ascendant Cycle 1 seals battle items")
T.eq(asc.cycleRule(2, "rotating"), "set",
  "Ascendant Cycle 2 enforces SET battle style")
T.eq(asc.cycleRule(3, "rotating"), "trio",
  "Ascendant Cycle 3 restricts the party to a trio")
T.eq(asc.cycleRule(4, "rotating"), "purist",
  "Ascendant Cycle 4 bans legendary party members")
T.eq(asc.cycleRule(8, "rotating"), "purist",
  "the four rotating cycle rules repeat deterministically")
T.eq(asc.cycleRule(3, "normal"), "normal",
  "the NORMAL preset removes extra cycle restrictions")

local blockedItems = {
  ascendantNoItems = true,
  say = function(self, message) self.blockMessage = message end,
}
battleStateStub.openItems(blockedItems)
T.eq(blockedItems.blockMessage:find("sealed", 1, true) ~= nil, true,
  "NO-ITEM and Ascendant rules block the Bag inside battle")

ascState.research.completed = {}
for _, assignment in ipairs(asd.research) do
  ascState.research.completed[assignment.id] = true
end
ascState.rocketStage = #asd.rocket
livePostgame.crownChampion = true
livePostgame.apexChampion = true
for _, gym in ipairs(pgd.gyms) do livePostgame.crownWins[gym.key] = true end
livePostgame.catches = livePostgame.catches or {}
for _, species in ipairs(pgd.legendOrder) do
  livePostgame.catches[species] = true
end
T.eq(asc.researchComplete(ascState), true,
  "all enabled research assignments can be completed")
T.eq(asc.allEnabledLegendsCaught(game), true,
  "the finale recognizes every enabled captured legend")
T.eq(asc.mewEligible(game), true,
  "Crown, research, Rocket and legendary completion unlock Mew's clues")
run.loader.modOptions.trainer_rematch = { legend_mew = false }
T.eq(asc.mewEligible(game), false,
  "the dedicated Mew option disables the mythic finale")
run.loader.modOptions.trainer_rematch = nil

for key in pairs(asd.gymQuests) do
  ascState.gymQuests[key] = { done = true }
end
ascState.tournament.wins = 1
ascState.mewCaught = true
local goldState = ex.johtoMasters.state()
goldState.clears = 0
ascState.achievements.ascendant = nil
asc.evaluateAchievements(game)
T.eq(ascState.achievements.leader_confidant, true,
  "all Leader missions unlock KANTO CONFIDANT")
T.eq(ascState.achievements.tournament_champ, true,
  "a completed bracket unlocks GRAND CHAMPION")
T.eq(ascState.achievements.rocket_breaker, true,
  "the fourth Rocket victory unlocks ROCKET BREAKER")
T.eq(ascState.achievements.mew_found, true,
  "catching Mew unlocks MYTH SEEKER")
T.eq(ascState.achievements.ascendant, nil,
  "the first Ascendant cycle remains sealed until Gold is defeated")
T.eq(ex.questTracker.nextObjective(game).id, "gold",
  "the shared Journal and Atlas tracker identifies Gold as the final main fight")
T.eq(asc.newGamePlusReady(game), false,
  "New Game Plus cannot begin before the mandatory Gold clear")
goldState.clears = 1
asc.evaluateAchievements(game)
T.eq(ascState.achievements.ascendant, true,
  "Gold completes the required main path and unlocks KANTO ASCENDANT")
T.eq(ex.questTracker.nextObjective(game).id, "new_game_plus",
  "the tracker advances from Gold to New Game Plus")
T.eq(asc.newGamePlusReady(game), true,
  "Factory and S.S. Anne records remain optional prestige goals")

ascState.selectedTitle = "mew_found"
local catchesBeforeCycle = livePostgame.catches
local newCycle = asc.beginNewGamePlus(game)
T.eq(newCycle, 1, "the first safe New Game Plus starts Ascendant Cycle 1")
T.eq(asc.state().cycleJohtoMastersStartClears, 1,
  "a new cycle records Gold progress so a fresh Gold clear is required")
T.eq(pg.state().apexChampion, nil,
  "New Game Plus resets the Apex circuit")
T.eq(pg.state().crownChampion, nil,
  "New Game Plus resets the Crown circuit")
T.eq(pg.state().catches, catchesBeforeCycle,
  "New Game Plus preserves captured legendary progress")
T.eq(asc.state().mewCaught, true,
  "New Game Plus preserves the unique Mew capture")
T.eq(asc.state().achievements.ascendant, true,
  "New Game Plus preserves permanent titles")
T.eq(asc.state().selectedTitle, "mew_found",
  "New Game Plus preserves the player's selected Trainer Card title")
T.eq(heritage.state().claimed.flying_pikachu.origin, "BALLOON CUP",
  "New Game Plus preserves the separate permanent Event Archive")
local cycleTeam = asc.selectBossTeam(adaptiveSource,
  { kind = "gym", key = "brock", tier = "master" }, adaptiveGame)
for _, slot in ipairs(cycleTeam) do
  T.eq(slot.level, 100,
    "every post-game boss slot reaches level 100 in New Game Plus")
end
run.loader.modOptions.trainer_rematch = { ascendant_rules = "normal" }
local relaxedCycleTeam = asc.selectBossTeam(adaptiveSource,
  { kind = "gym", key = "misty", tier = "master" }, adaptiveGame)
T.eq(relaxedCycleTeam[1].level, 100,
  "level-100 cycle teams do not depend on optional challenge rules")
run.loader.modOptions.trainer_rematch = nil

local cycleRuleGame = {
  save = {
    options = { battleStyle = "shift" },
    party = {
      { species = "MEW", hp = 10, status = "PAR" },
      { species = "FIXMON_A", hp = 11 },
      { species = "FIXMON_A", hp = 12 },
      { species = "FIXMON_A", hp = 13 },
    },
  },
}
asc.state().cycle = 2
local setBattle = { game = cycleRuleGame }
asc.applyBossRules(setBattle)
T.eq(cycleRuleGame.save.options.battleStyle, "set",
  "Cycle 2 temporarily forces SET battle style")
RealRuntime.emit("battle.ended", { battle = setBattle, result = "win" })
T.eq(cycleRuleGame.save.options.battleStyle, "shift",
  "the player's battle-style option is restored after the boss fight")
asc.state().cycle = 3
local trioBattle = { game = cycleRuleGame }
asc.applyBossRules(trioBattle)
T.eq(cycleRuleGame.save.party[4].hp, 0,
  "Cycle 3 seals party slots beyond the leading trio")
RealRuntime.emit("battle.ended", { battle = trioBattle, result = "win" })
T.eq(cycleRuleGame.save.party[4].hp, 13,
  "sealed trio slots are restored after the fight")
asc.state().cycle = 4
local puristBattle = { game = cycleRuleGame }
asc.applyBossRules(puristBattle)
T.eq(cycleRuleGame.save.party[1].hp, 0,
  "Cycle 4 seals legendary party members")
RealRuntime.emit("battle.ended", { battle = puristBattle, result = "win" })
T.eq(cycleRuleGame.save.party[1].hp, 10,
  "sealed legendary HP and status are restored after the fight")
T.eq(cycleRuleGame.save.party[1].status, "PAR",
  "the Purist rule also restores the original status condition")
asc.state().cycle = 1

-- ------------------------------------------------ complete shiny progression

local priorModSave = run.loader.modSave
run.loader.modSave = {}
local shinyOwned, shinyPokemon = {}, {}
for dex = 1, 251 do
  local id = ("DEX_%03d"):format(dex)
  shinyOwned[id] = true
  shinyPokemon[id] = { dex = dex, name = id }
end
local shinyProgressGame = {
  data = { pokemon = shinyPokemon, constants = Data.constants },
  save = {
    inventory = {}, bagOrder = {}, party = {}, boxes = {},
    flags = { EVENT_BEAT_CHAMPION_RIVAL = true },
    pokedex = { seen = shinyOwned, owned = shinyOwned },
  },
}
T.eq(shinySystem.unlockCharm(shinyProgressGame), true,
  "recording all 251 species awards the permanent Shiny Charm")
T.eq(shinySystem.hasCharm(), true,
  "the Shiny Charm ability persists in mod save data")
T.eq(shinyProgressGame.save.inventory.SHINY_CHARM, 1,
  "the Shiny Charm also appears as a non-tossable key item")
for n = 1, 10 do
  shinySystem.afterRematch(shinyProgressGame, {
    rematchTrainerClass = "OPP_YOUNGSTER",
  })
end
local shinyProgress = shinySystem.state()
T.eq(shinyProgress.rematchStreak, 10,
  "consecutive field-rematch wins build the shiny hunting streak")
T.eq(shinyProgress.outbreak, nil,
  "a ten-win streak cannot start a swarm before Elm's starter trials")
local gatedResearch = ex.johtoResearch.state()
for _, key in ipairs(johto.starterOrder) do
  gatedResearch.starters[key] = true
end
shinyProgress.rematchStreak = 0
for n = 1, 10 do
  shinySystem.afterRematch(shinyProgressGame, {
    rematchTrainerClass = "OPP_YOUNGSTER",
  })
end
T.neq(shinyProgress.outbreak, nil,
  "Hall of Fame plus all three starter trials unlock shiny swarms")
T.eq(shinyProgress.outbreak.steps, 2048,
  "a new outbreak receives its full step duration")
T.eq(shinySystem.extraRolls(), 3,
  "Charm plus a ten-win streak grants three additional DV rolls")
for n = 11, 25 do
  shinySystem.afterRematch(shinyProgressGame, {
    rematchTrainerClass = "OPP_YOUNGSTER",
  })
end
T.eq(shinySystem.state().redGyaradosUnlocked, true,
  "a 25-win post-Hall-of-Fame streak unlocks the red Gyarados event")
T.eq(shinySystem.eventMap, "SEAFOAM_ISLANDS_B4F",
  "the guaranteed shiny event lives in Seafoam's deepest floor")
run.loader.modSave = priorModSave

-- ------------------------------------------------ discovery Dex + Johto Masters

local dexProgress = ex.dexProgress
local johtoMasters = ex.johtoMasters
local worldEvents = ex.worldEvents
local fieldTech = ex.fieldTech
local kantoCompletion = ex.kantoCompletion
T.neq(dexProgress, nil,
  "the original-style discovery and certificate controller is exported")
T.neq(johtoMasters, nil,
  "the repeatable Silver/Kris/Gold trial is exported")
T.neq(worldEvents, nil,
  "the step-driven Kanto world-event controller is exported")
T.neq(fieldTech, nil,
  "the HM Field Kit, TM archive and Move Deleter controller is exported")
T.neq(kantoCompletion, nil,
  "the self-contained Kanto 151 controller is exported")
T.eq(#kantoCompletion.criticalAcquisitions, 13,
  "the Kanto completion audit documents every former version or choice lock")
T.eq(kantoCompletion.loadedMode(), "ascendant",
  "KANTO 151 reports the content mode that was actually patched at startup")
local priorKantoOptions = run.loader.modOptions.trainer_rematch
run.loader.modOptions.trainer_rematch = { kanto_151 = "wild" }
T.eq(kantoCompletion.configuredMode(), "wild",
  "KANTO 151 separately observes a newly selected option")
T.eq(kantoCompletion.restartRequired(), true,
  "changing the KANTO 151 patch mode is reported as requiring a restart")
T.eq(kantoCompletion.statusText():find(
  "LOADED: REWARDS", 1, true) ~= nil, true,
  "KANTO 151 status keeps showing the loaded mode until restart")
T.eq(kantoCompletion.statusText():find(
  "RESTART REQUIRED", 1, true) ~= nil, true,
  "KANTO 151 status gives an explicit restart warning")
run.loader.modOptions.trainer_rematch = priorKantoOptions

if kantoCompletion.enabled then
  local function encounterHas(mapId, species)
    local enc = Data.encounters[mapId]
    for _, slot in ipairs(enc and enc.grass and enc.grass.slots or {}) do
      if slot.species == species then return true end
    end
    return false
  end

  T.eq(encounterHas("ROUTE_5", "MEOWTH"), true,
    "Meowth is available without changing game editions")
  T.eq(encounterHas("ROUTE_5", "BELLSPROUT"), true,
    "Bellsprout shares a natural habitat with Oddish")
  T.eq(encounterHas("ROUTE_8", "EKANS")
      and encounterHas("ROUTE_8", "SANDSHREW"), true,
    "Route 8 contains both former version-exclusive Ground/Poison families")
  T.eq(encounterHas("SAFARI_ZONE_CENTER", "SCYTHER")
      and encounterHas("SAFARI_ZONE_CENTER", "PINSIR"), true,
    "both Safari bug prizes can be caught in one save")
  T.eq(encounterHas("POWER_PLANT", "ELECTABUZZ")
      and encounterHas("POKEMON_MANSION_B1F", "MAGMAR"), true,
    "Electabuzz and Magmar are both obtainable")
  T.eq(encounterHas("POKEMON_MANSION_B1F", "MEW"), false,
    "the Kanto 151 layer never bypasses the authored Mew event")
  T.eq(encounterHas("SEAFOAM_ISLANDS_B2F", "SQUIRTLE"), false,
    "reward mode keeps Squirtle as Misty's Master prize")
  T.eq(Data.pokemon.KADABRA.evolutions[1].species, "ALAKAZAM",
    "Kadabra evolves without a trade")
  T.eq(Data.pokemon.MACHOKE.evolutions[1].level, 45,
    "Machoke's replacement level evolution is registered")

  local function hasEvolution(species, target, method, item)
    for _, row in ipairs(Data.pokemon[species].evolutions or {}) do
      if row.species == target
          and (not method or row.method == method)
          and (not item or row.item == item) then return true end
    end
    return false
  end
  T.eq(hasEvolution("GLOOM", "VILEPLUME", "ITEM", "LEAF_STONE")
      and hasEvolution("GLOOM", "BELLOSSOM", "ITEM", "SUN_STONE"), true,
    "Gloom keeps Vileplume while gaining Bellossom")
  T.eq(hasEvolution("POLIWHIRL", "POLIWRATH", "ITEM", "WATER_STONE")
      and hasEvolution("POLIWHIRL", "POLITOED", "ITEM", "KINGS_ROCK"), true,
    "Poliwhirl keeps Poliwrath while gaining Politoed")
  T.eq(hasEvolution("EEVEE", "VAPOREON", "ITEM", "WATER_STONE")
      and hasEvolution("EEVEE", "JOLTEON", "ITEM", "THUNDER_STONE")
      and hasEvolution("EEVEE", "FLAREON", "ITEM", "FIRE_STONE")
      and hasEvolution("EEVEE", "ESPEON", "FRIENDSHIP_DAY")
      and hasEvolution("EEVEE", "UMBREON", "FRIENDSHIP_NIGHT"), true,
    "Eevee exposes all five Kanto and Johto branches together")
  T.eq(hasEvolution("SLOWPOKE", "SLOWBRO", "LEVEL")
      and hasEvolution("SLOWPOKE", "SLOWKING", "ITEM", "KINGS_ROCK"), true,
    "Slowpoke keeps Slowbro while gaining Slowking")

  local priorHallOfFame = game.save.hallOfFame
  local priorChampionFlag = game.save.flags.EVENT_BEAT_CHAMPION_RIVAL
  local function eeveeRng(lo, hi)
    if lo == 1 and hi == 100 then return 1 end
    return hi
  end
  game.save.hallOfFame = {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = nil
  local beforeLeague = RealRuntime.call("encounter.roll",
    function() return { species = "PIDGEY", level = 22 } end,
    Data.encounters.ROUTE_7,
    { mapId = "ROUTE_7", terrain = "grass", rng = eeveeRng })
  T.eq(beforeLeague.species, "PIDGEY",
    "Route 7 does not reveal renewable Eevee before the League")
  game.save.hallOfFame = { {} }
  local afterLeague = RealRuntime.call("encounter.roll",
    function() return { species = "PIDGEY", level = 22 } end,
    Data.encounters.ROUTE_7,
    { mapId = "ROUTE_7", terrain = "grass", rng = eeveeRng })
  T.eq(afterLeague.species, "EEVEE",
    "Route 7 can replace two percent of post-League grass encounters with Eevee")
  T.eq(afterLeague.level, 25,
    "renewable post-League Eevee use their intended level")
  game.save.hallOfFame = priorHallOfFame
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = priorChampionFlag

  local pewterMart =
    Data.text_pointers.PewterMart.TEXT_PEWTERMART_CLERK.mart
  T.eq(pewterMart[1], "POKE_BALL",
    "adding Moon Stone preserves Pewter Mart's normal inventory")
  T.eq(pewterMart[#pewterMart], "MOON_STONE",
    "Moon Stone is renewable at Pewter Mart")

  local priorKantoSave = run.loader.modSave
  run.loader.modSave = {}
  local kantoGiftGame = {
    data = Data,
    save = {
      player = { name = "RED", id = 151 },
      party = {}, inventory = {}, flags = { EVENT_GOT_HELIX_FOSSIL = true },
      pokedex = { seen = {}, owned = {} },
    },
  }
  local starterText =
    kantoCompletion.afterBossWin(kantoGiftGame, "erika", "master")
  T.eq(kantoGiftGame.save.party[1].species, "BULBASAUR",
    "Master Erika awards the Grass starter in reward mode")
  T.eq(starterText ~= nil, true,
    "the starter prize has a visible bilingual reward message")
  local fossilText =
    kantoCompletion.afterBossWin(kantoGiftGame, "brock", "master")
  T.eq(kantoGiftGame.save.inventory.DOME_FOSSIL, 1,
    "Master Brock awards the fossil excluded by the Mt. Moon choice")
  T.eq(fossilText ~= nil, true,
    "the missing fossil receives its own reward message")
  run.loader.modSave = priorKantoSave
end
T.eq(Data.moves.FRENZY_PLANT.power, 150,
  "Frenzy Plant is registered as a full starter signature move")
T.eq(Data.moves.BLAST_BURN.effect, "HYPER_BEAM_EFFECT",
  "Blast Burn uses the authentic recharge effect")
T.eq(Data.moves.HYDRO_CANNON.accuracy, 90,
  "Hydro Cannon carries its intended accuracy")
T.eq(Data.items.TM_FRENZY_PLANT.machine.number, 51,
  "TM51 contains Frenzy Plant")
T.eq(Data.items.TM_BLAST_BURN.machine.number, 52,
  "TM52 contains Blast Burn")
T.eq(Data.items.TM_HYDRO_CANNON.machine.number, 53,
  "TM53 contains Hydro Cannon")
T.eq(#fieldTech.starterFamilies.FRENZY_PLANT, 6,
  "the Grass TM covers both complete Kanto and Johto starter families")
T.eq(#fieldTech.starterFamilies.BLAST_BURN, 6,
  "the Fire TM covers both complete Kanto and Johto starter families")
T.eq(#fieldTech.starterFamilies.HYDRO_CANNON, 6,
  "the Water TM covers both complete Kanto and Johto starter families")

local previousFieldSave = run.loader.modSave
run.loader.modSave = {}
local fieldState = fieldTech.state()
fieldState.kit = true
local fieldSave = {
  inventory = {
    FIELD_KIT = 1, HM_CUT = 1, CASCADEBADGE = 1,
    HM_SURF = 1, SOULBADGE = 1,
  },
  party = { { species = "FIXMON_A", moves = { { id = "FIX_TACKLE" } } } },
}
T.eq(fieldTech.available(fieldSave, "CUT"), true,
  "the Field Kit activates an owned HM only after its matching badge")
fieldSave.inventory.CASCADEBADGE = nil
T.eq(fieldTech.available(fieldSave, "CUT"), false,
  "the Field Kit never bypasses badge progression")
T.eq(fieldTech.available(fieldSave, "FLY"), false,
  "an HM that has not been found remains unavailable")
local deletable = {
  moves = { { id = "CUT" }, { id = "FIX_TACKLE" } },
}
T.eq(fieldTech.forgetMove(deletable, 1), true,
  "the Move Deleter can remove an HM once field tools no longer need it")
T.eq(deletable.moves[1].id, "FIX_TACKLE",
  "deleting the selected HM keeps the other move intact")
T.eq(fieldTech.forgetMove(deletable, 1), false,
  "the Move Deleter protects a Pokémon's final usable move")
run.loader.modSave = previousFieldSave

T.eq(#ex.johtoMastersData.trainers, 3,
  "Silver, Kris and Gold form the complete Johto Masters trial")

for _, trainer in ipairs(ex.johtoMastersData.trainers) do
  T.eq(#trainer.pool, 12,
    trainer.key .. " owns twelve level-100 roster candidates")
  local first = johtoMasters.teamFor(trainer.key, 1)
  local second = johtoMasters.teamFor(trainer.key, 2)
  T.eq(#first, 6, trainer.key .. " selects a full six-Pokémon team")
  T.eq(first[1].level, 100, trainer.key .. " always fights at level 100")
  T.eq(first[1].species ~= second[1].species, true,
    trainer.key .. " changes the team lead on the next challenge")
end

local expandedPokemon, expandedOwned = {}, {}
for dex = 1, 251 do
  local id = ("DISCOVERY_%03d"):format(dex)
  expandedPokemon[id] = {
    id = id, dex = dex, name = id, baseStats = Data.pokemon.FIXMON_A.baseStats,
  }
  if dex <= 150 then expandedOwned[id] = true end
end
local discoveryGame = {
  data = { pokemon = expandedPokemon },
  save = {
    player = { name = "RED" }, party = {}, boxes = {}, inventory = {},
    hallOfFame = { {} },
    pokedex = { seen = expandedOwned, owned = expandedOwned },
  },
}
T.eq(dexProgress.ownedThrough(discoveryGame, 150), 150,
  "the Kanto certificate counts the exact first 150 species")
T.eq(dexProgress.complete(discoveryGame, 150), true,
  "owning Kanto #001-150 unlocks the original completion tier")
T.eq(dexProgress.complete(discoveryGame, 151), false,
  "Mew remains a real undiscovered slot for the 151 certificate")
expandedOwned.DISCOVERY_151 = true
T.eq(dexProgress.complete(discoveryGame, 151), true,
  "capturing Mew unlocks the separate 151 certificate")
T.eq(#johtoMasters.fullRoster(discoveryGame), 251,
  "Gold's reward roster contains every one of all 251 species")
T.eq(johtoMasters.randomSpecies(discoveryGame, function() return 251 end),
  "DISCOVERY_251",
  "Gold can uniformly select Celebi as the 251st shiny reward")

local isolatedModSave = run.loader.modSave
run.loader.modSave = {}
worldEvents.install(discoveryGame)
local worldState = worldEvents.state()
worldState.nextAt, worldState.active = 10, nil
worldEvents.onStep(discoveryGame, 10)
T.eq(worldEvents.active("training_rush"), true,
  "the first scheduled step event starts a real Training Rush")
T.eq(worldEvents.trainingStepBonus(), 1,
  "Training Rush adds one trainer-only recovery tick per walked step")
local worldBucket = run.loader.modSave.trainer_rematch
worldBucket.step_clock, worldBucket.trainer_step_clock = 50, 50
worldEvents.state().active = { id = "training_rush", steps = 100 }
run.loader.events:emit("world.stepped", {})
T.eq(ex.playerStepClock(), 51,
  "Training Rush records exactly one real player step")
T.eq(ex.trainerStepClock(), 52,
  "Training Rush advances only the trainer recovery clock twice")
T.eq(worldEvents.state().active.steps, 99,
  "Training Rush itself and other world events lose one real step, not two")
local migrationResearch = ex.johtoResearch.state()
migrationResearch.finalReward = nil
local migrationState = worldEvents.state()
migrationState.index, migrationState.active, migrationState.nextAt = 21, nil, 60
worldEvents.onStep(discoveryGame, 60)
T.eq(worldEvents.active("johto_migration"), true,
  "the Larvitar cycle still starts a Johto migration before the finale")
T.eq(migrationState.active.species ~= "LARVITAR", true,
  "Larvitar is excluded from migrations until Elm's research finale")
migrationResearch.finalReward = true
migrationState.index, migrationState.active, migrationState.nextAt = 21, nil, 61
worldEvents.onStep(discoveryGame, 61)
T.eq(migrationState.active.species, "LARVITAR",
  "Larvitar joins Route 22 migrations only after the research finale")
worldState.active = { id = "golden_wind", steps = 100 }
T.eq(worldEvents.shinyBonusRolls(), 2,
  "Golden Wind grants two additional shiny checks")
worldState.active = { id = "frontier_festival", steps = 100 }
T.eq(worldEvents.frontierMultiplier(), 2,
  "Frontier Festival doubles Ascendant Frontier points")
run.loader.modSave = isolatedModSave

-- ------------------------------------------------ Kanto Ascendant 5.0 Grand Tour

;(function()
local grandTour = ex.grandTour
local grandTourData = ex.grandTourData
T.neq(grandTour, nil,
  "the Crown Champion's Grand Tour controller is exported")
T.neq(grandTourData, nil,
  "the inspectable Factory and S.S. Anne rosters are exported")
T.eq(grandTourData.cruise.cooldown, 4096,
  "S.S. Anne voyages use the promised 4096 real-step cooldown")

local factoryPokemon = {}
for dex, row in ipairs(grandTourData.factory.candidates) do
  local def = {}
  for key, value in pairs(Data.pokemon.FIXMON_A) do def[key] = value end
  def.id, def.name, def.dex = row.species, row.species, dex
  def.evolutions = {}
  factoryPokemon[row.species] = def
end
local factoryGame = {
  data = { pokemon = factoryPokemon, moves = Data.moves },
  save = {
    player = { name = "RED", id = 500 },
    party = {}, inventory = {}, pokedex = { seen = {}, owned = {} },
  },
}
local firstDraft = grandTour.draftCandidates(factoryGame, 1)
local secondDraft = grandTour.draftCandidates(factoryGame, 2)
T.eq(#firstDraft, 6,
  "the Battle Factory always presents six legal rentals")
T.eq(firstDraft[1].species ~= secondDraft[1].species, true,
  "a later Factory attempt rotates to a different draft")
local draftedSpecies = {}
for _, row in ipairs(firstDraft) do
  T.eq(draftedSpecies[row.species], nil,
    "the six Factory candidates never repeat a species")
  draftedSpecies[row.species] = true
  T.eq(row.level, 100, row.species .. " is offered at level 100")
  T.eq(grandTour.isFinalEvolution(factoryGame, row.species), true,
    row.species .. " is a fully evolved non-legendary rental")
end

local rentals = grandTour.buildRentalTeam(factoryGame,
  { firstDraft[1], firstDraft[2], firstDraft[3] })
T.eq(#rentals, 3,
  "the chosen three draft entries become a three-Pokemon rental party")
for _, mon in ipairs(rentals) do
  T.eq(mon.level, 100, "every built Factory rental remains level 100")
  T.eq(mon.factoryRental, true,
    "temporary Factory Pokemon carry an explicit rental marker")
end

local factoryFoes = grandTour.factoryBracket(1)
T.eq(#factoryFoes, 3,
  "a Factory run selects three changing opponents")
local factoryKeys = {}
for _, foe in ipairs(factoryFoes) do
  T.eq(factoryKeys[foe.key], nil,
    "one Factory bracket never repeats an opponent")
  factoryKeys[foe.key] = true
  T.eq(#foe.team, 3,
    foe.key .. " fields a fair three-Pokemon Factory team")
  for _, slot in ipairs(foe.team) do
    T.eq(slot.level, 100, foe.key .. " always battles at level 100")
  end
end

local cruiseFoes = grandTour.cruiseBracket(1)
local nextCruiseFoes = grandTour.cruiseBracket(2)
T.eq(#cruiseFoes, 5,
  "each S.S. Anne Grand Tour contains five authored battles")
T.eq(cruiseFoes[1].key ~= nextCruiseFoes[1].key, true,
  "the S.S. Anne bracket rotates on the next voyage")
local cruiseKeys = {}
for _, foe in ipairs(cruiseFoes) do
  T.eq(cruiseKeys[foe.key], nil,
    "one voyage never repeats a shipboard opponent")
  cruiseKeys[foe.key] = true
  T.eq(#foe.team, 6, foe.key .. " brings a complete cruise team")
  for _, slot in ipairs(foe.team) do
    T.eq(slot.level, 100, foe.key .. " always battles at level 100")
  end
end

local interruptedOriginal = {
  { species = "FIXMON_A", level = 42, hp = 17 },
  { species = "FIXMON_B", level = 43, hp = 18 },
}
local interruptedSave = {
  party = { { species = "VENUSAUR", level = 100, factoryRental = true } },
  modData = {
    trainer_rematch = {
      grand_tour = {
        factory = {
          attempts = 1, activeRound = 2,
          activeDraft = { "VENUSAUR", "STARMIE", "TAUROS" },
          backupParty = interruptedOriginal,
        },
      },
    },
  },
}
T.eq(grandTour.recoverRawParty(interruptedSave), true,
  "loading an interrupted Factory run detects the party backup")
T.eq(interruptedSave.party, interruptedOriginal,
  "interrupted Factory saves restore the exact original team")
local recoveredFactory =
  interruptedSave.modData.trainer_rematch.grand_tour.factory
T.eq(recoveredFactory.backupParty, nil,
  "successful recovery consumes the stale Factory backup")
T.eq(recoveredFactory.activeRound, 0,
  "successful recovery closes the interrupted Factory round")

local oldGrandTour = grandTour.normalizeState({
  factory = { attempts = -3, wins = 2, bestRound = 99 },
  cruise = { clears = 4, bestRound = 99, nextAt = -1 },
})
T.eq(oldGrandTour.factory.attempts, 0,
  "Grand Tour migration repairs invalid old Factory counters")
T.eq(oldGrandTour.factory.wins, 2,
  "Grand Tour migration preserves legitimate Factory wins")
T.eq(oldGrandTour.factory.bestRound, 3,
  "Factory best-round migration clamps to the three-round maximum")
T.eq(oldGrandTour.cruise.clears, 4,
  "Grand Tour migration preserves legitimate voyage clears")
T.eq(oldGrandTour.cruise.bestRound, 5,
  "voyage best-round migration clamps to the five-round maximum")

local priorGrandTourSave = run.loader.modSave
run.loader.modSave = {}
local grandTourState = grandTour.state()
run.loader.modSave.trainer_rematch.step_clock = 1000
grandTourState.cruise.nextAt = 5096
T.eq(grandTour.cruiseRemaining(), 4096,
  "the voyage status measures its cooldown on literal walked tiles")
run.loader.modSave.trainer_rematch.step_clock = 5096
T.eq(grandTour.cruiseRemaining(), 0,
  "the S.S. Anne returns after all 4096 real steps")
local factoryWrites = 0
grandTourState.factory.backupParty = {
  { species = "FIXMON_A", level = 42 },
}
T.eq(RealRuntime.call("save.write", function()
    factoryWrites = factoryWrites + 1
    return true
  end, {}), false,
  "the global save hotkey is vetoed during a live Factory rental run")
T.eq(factoryWrites, 0,
  "a vetoed Factory save never reaches the disk-writing continuation")
grandTourState.factory.backupParty = nil
T.eq(RealRuntime.call("save.write", function()
    factoryWrites = factoryWrites + 1
    return true
  end, {}), true,
  "normal saving resumes as soon as the Factory party is restored")
T.eq(factoryWrites, 1,
  "the ordinary save path still reaches its continuation exactly once")

local ascendantGrandTourState = asc.state()
ascendantGrandTourState.achievements.factory_architect = true
ascendantGrandTourState.achievements.sea_champion = true
grandTourState.factory.title = false
grandTourState.cruise.title = false
T.eq(grandTour.state().factory.title, true,
  "an existing Factory achievement repairs its stale local title flag")
T.eq(grandTour.state().cruise.title, true,
  "an existing cruise achievement repairs its stale local title flag")

local factoryOriginalParty = rentals
factoryGame.save.party = factoryOriginalParty
local factoryMessages = {}
factoryGame.stack = {
  push = function(_, box) factoryMessages[#factoryMessages + 1] = box end,
}
local factoryNpc = { frozen = true }
local factoryOw = {
  afterBattle = function() end,
  pushBattle = function(self, battle) self.battle = battle end,
}

local originalPokemonNew = Pokemon.new
Pokemon.new = function() error("injected rental build failure") end
local rentalCallOk, rentalStarted, rentalReason = pcall(
  grandTour.startFactoryRun, factoryGame, factoryOw, factoryNpc,
  { firstDraft[1], firstDraft[2], firstDraft[3] })
Pokemon.new = originalPokemonNew
T.eq(rentalCallOk, true,
  "a thrown rental constructor is contained by the Factory transaction")
T.eq(rentalStarted, false,
  "a failed rental build cannot start a partial Factory run")
T.eq(rentalReason, "rental_error",
  "the failed rental transaction reports its precise stage")
T.eq(factoryGame.save.party, factoryOriginalParty,
  "a rental-construction failure keeps the exact original party")
T.eq(grandTour.state().factory.backupParty, nil,
  "a rental-construction failure consumes the temporary party backup")

local originalForcedBattle = pg.newForcedBattle
local forcedBattleCalls = 0
pg.newForcedBattle = function()
  forcedBattleCalls = forcedBattleCalls + 1
  if forcedBattleCalls == 2 then error("injected battle build failure") end
  return { trainer = { name = "FACTORY TEST" } }
end
factoryMessages = {}
factoryNpc.frozen = true
factoryGame.save.party = factoryOriginalParty
package.loaded["src.render.TextBox"] = textBoxStub
local partialStarted = grandTour.startFactoryRun(
  factoryGame, factoryOw, factoryNpc,
  { firstDraft[1], firstDraft[2], firstDraft[3] })
T.eq(partialStarted, true,
  "the injected Factory battle failure occurs only after round one starts")
factoryOw.battle.onFinish("win")
factoryMessages[#factoryMessages].onDone()
package.loaded["src.render.TextBox"] = realTextBoxModule
pg.newForcedBattle = originalForcedBattle
T.eq(factoryGame.save.party, factoryOriginalParty,
  "a later namedBattle failure restores the exact original party")
T.eq(grandTour.state().factory.backupParty, nil,
  "a later namedBattle failure clears the save-veto backup")
T.eq(factoryNpc.frozen, false,
  "a failed later Factory round releases the facility NPC")
T.eq(factoryMessages[#factoryMessages].text:find(
    "original team", 1, true) ~= nil, true,
  "an asynchronous Factory rollback explains that the team was restored")

local festivalState = worldEvents.state()
local priorFestival = festivalState.active
festivalState.active = { id = "frontier_festival", steps = 100 }
ascendantGrandTourState.frontierPoints = 10
pg.newForcedBattle = function()
  return { trainer = { name = "GRAND TOUR TEST" } }
end
factoryMessages = {}
factoryNpc.frozen = true
factoryGame.save.party = factoryOriginalParty
package.loaded["src.render.TextBox"] = textBoxStub
T.eq(grandTour.startFactoryRun(
    factoryGame, factoryOw, factoryNpc,
    { firstDraft[1], firstDraft[2], firstDraft[3] }), true,
  "a complete test Factory run starts with the valid draft")
for round = 1, 3 do
  factoryOw.battle.onFinish("win")
  if round < 3 then factoryMessages[#factoryMessages].onDone() end
end
T.eq(ascendantGrandTourState.frontierPoints, 22,
  "Frontier Festival actually credits twelve points for a clean Factory run")
T.eq(factoryMessages[#factoryMessages].text:find(
    "+12 FRONTIER POINTS", 1, true) ~= nil, true,
  "the Factory clear dialogue shows the twelve points actually credited")

factoryMessages = {}
factoryNpc.frozen = true
grandTour.state().cruise.nextAt = 0
T.eq(grandTour.startCruise(factoryGame, factoryOw, factoryNpc), true,
  "a complete test S.S. Anne Grand Tour starts off cooldown")
for round = 1, 5 do
  factoryOw.battle.onFinish("win")
  if round < 5 then factoryMessages[#factoryMessages].onDone() end
end
package.loaded["src.render.TextBox"] = realTextBoxModule
pg.newForcedBattle = originalForcedBattle
festivalState.active = priorFestival
T.eq(ascendantGrandTourState.frontierPoints, 38,
  "Frontier Festival actually credits sixteen points for the cruise")
T.eq(factoryMessages[#factoryMessages].text:find(
    "+16 FRONTIER POINTS", 1, true) ~= nil, true,
  "the cruise clear dialogue shows the sixteen points actually credited")

run.loader.modSave = priorGrandTourSave
end)()

run.release()
T.finish("trainer_rematch")
