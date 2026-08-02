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
run.loader.modOptions.trainer_rematch = { legend_art = "original" }
local originalCtx = { species = "RAIKOU", side = "back", trueColor = false }
local originalPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_back.png", originalCtx)
T.eq(originalPath, "fallback_back.png",
  "the LEGEND ART option can force the original sprite")
T.eq(originalCtx.trueColor, false,
  "the original four-shade sprite stays palette-aware")
run.loader.modOptions.trainer_rematch = nil

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
T.eq(optionRows.legend_articuno.type, "choice",
  "Articuno has its own APEX/VANILLA/OFF option")
T.eq(optionRows.legend_mewtwo.type, "choice",
  "Mewtwo has its own APEX/VANILLA/OFF option")
T.eq(optionRows.legend_raikou.type, "toggle",
  "Raikou can be enabled or disabled independently")
T.eq(optionRows.legend_celebi.type, "toggle",
  "Celebi can be enabled or disabled independently")
T.eq(optionRows.legend_mew.type, "toggle",
  "Mew can be enabled or disabled independently")
T.eq(optionRows.rocket_story.type, "toggle",
  "Rocket Resurgence can be disabled independently")
T.eq(optionRows.grand_tournament.type, "toggle",
  "the Grand Tournament can be disabled independently")
T.eq(optionRows.ascendant_rules.type, "choice",
  "New Game Plus challenge rules can be relaxed")

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

T.eq(ex.rollRestSteps(function(lo) return lo end, 128, 256), 128,
  "rest roll includes the lower bound")
T.eq(ex.rollRestSteps(function(_, hi) return hi end, 128, 256), 256,
  "rest roll includes the upper bound")
T.eq(ex.rollRestSteps(function(lo) return lo end, 256, 128), 128,
  "an inverted option range is normalized")
T.eq(ex.restLine(1):find("1 more step.", 1, true) ~= nil, true,
  "one remaining step uses singular dialogue")
T.eq(ex.restLine(128):find("128 more steps.", 1, true) ~= nil, true,
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
  "the functional EXP.ALL/EP-Teiler starts its 20-percent balanced band")
T.eq(ex.lootForRoll(2100, "balanced",
  { averageLevel = 40, expAllAvailable = true }), "EXP_ALL",
  "the functional EXP.ALL/EP-Teiler fills its 20-percent balanced band")
T.eq(ex.lootForRoll(101, "balanced",
  { averageLevel = 40, expAllAvailable = false }), nil,
  "EXP.ALL can only drop once")
T.eq(ex.lootForRoll(101, "balanced",
  { averageLevel = 39, expAllAvailable = true }), nil,
  "EXP.ALL waits for a level-40 rematch")
T.eq(ex.lootForRoll(2101, "balanced",
  { averageLevel = 20 }), "RARE_CANDY",
  "level-20 rematches can drop Rare Candy")
T.eq(ex.lootForRoll(3601, "balanced",
  { averageLevel = 35 }), "PP_UP",
  "level-35 rematches can drop PP Up")
T.eq(ex.lootForRoll(4601, "balanced",
  { averageLevel = 50 }), "MAX_REVIVE",
  "level-50 rematches can drop Max Revive")
T.eq(ex.lootForRoll(5401, "balanced", { averageLevel = 1 }), "NUGGET",
  "every rematch tier can drop a Nugget")
T.eq(ex.lootForRoll(7401, "balanced",
  { averageLevel = 100, masterUnlocked = true, expAllAvailable = true }), nil,
  "balanced loot keeps a 26-percent no-drop range at full eligibility")
T.eq(ex.lootForRoll(200, "generous",
  { averageLevel = 100, masterUnlocked = true }), "MASTER_BALL",
  "GENEROUS mode gives the Master Ball its full two-percent band")
T.eq(ex.lootForRoll(201, "generous",
  { averageLevel = 40, expAllAvailable = true }), "EXP_ALL",
  "GENEROUS mode gives EXP.ALL a 25-percent band")
T.eq(ex.lootForRoll(2701, "generous", { averageLevel = 20 }), "RARE_CANDY",
  "GENEROUS mode raises the Rare Candy band")
T.eq(ex.lootForRoll(4701, "generous", { averageLevel = 35 }), "PP_UP",
  "GENEROUS mode raises the PP Up band")
T.eq(ex.lootForRoll(6201, "generous", { averageLevel = 50 }), "MAX_REVIVE",
  "GENEROUS mode raises the Max Revive band")
T.eq(ex.lootForRoll(7401, "generous", { averageLevel = 1 }), "NUGGET",
  "GENEROUS mode fills the remaining eligible table with Nuggets")
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
T.eq(pushed[#pushed].text:find("128 more steps.", 1, true) ~= nil, true,
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
T.eq(npc.frozen, false, "npc unfrozen after the battle")
local savedState = game.save.modData.trainer_rematch.trainers[npc.id]
T.eq(savedState.rematches, 1, "completed rematch count persists per trainer")
T.eq(ex.remainingSteps(npc.id), 128, "trainer starts the configured rest")

-- B2: the same trainer refuses until enough real world steps pass
pushed = {}
overworldStub.talkTo(ow, npc)
T.eq(#pushed, 1, "resting trainer shows one status box")
T.eq(pushed[1].text:find("128 more steps.", 1, true) ~= nil, true,
  "rest status shows the exact remaining steps")
T.eq(pushed[1].text:find("\f", 1, true) ~= nil, true,
  "the trainer's normal text follows the step status as a second page")
T.eq(pushed[1].text:find("Nice fixture.", 1, true) ~= nil, true,
  "the second cooldown page preserves the normal post-battle line")
T.eq(pushed[1].opts.choice, nil, "resting trainer offers no battle choice")
pushed[1].onDone()
for _ = 1, 127 do run.loader.events:emit("world.stepped", {}) end
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
T.eq(ex.remainingSteps(originalNpc.id), 128,
  "a newly beaten trainer is not immediately ready for a rematch")

-- E2b: ignoring a ready trainer does not freeze its strength. The visible
-- cooldown ends first; each additional silent cooldown grows the next team
-- while the trainer remains continuously available.
for _ = 1, 128 do run.loader.events:emit("world.stepped", {}) end
T.eq(ex.remainingSteps(originalNpc.id), 0,
  "the ignored trainer becomes ready after the visible cooldown")
T.eq(ex.trainingCycles(originalNpc.id), 0,
  "becoming ready starts rather than completes the first silent cycle")
for _ = 1, 127 do run.loader.events:emit("world.stepped", {}) end
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
local legacySave = {
  defeatedTrainers = { LEGACY_ROUTE_obj_3 = true },
  modData = {},
}
run.loader.modSave = legacySave.modData
run.loader.events:emit("save.loaded", { save = legacySave })
local legacyLeft = ex.remainingSteps("LEGACY_ROUTE_obj_3")
T.eq(legacyLeft >= 128 and legacyLeft <= 256, true,
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
installDeps.lootRandom = function() return 5401 end
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
T.neq(asc, nil, "the Ascendant systems controller is exported")
T.neq(asd, nil, "the Ascendant progression data is exported")

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
T.eq(asc.rankBonusLoot(7500, "veteran", 10), "NUGGET",
  "VETERAN trainers add a bonus Nugget band")
T.eq(asc.rankBonusLoot(8000, "expert", 20), "RARE_CANDY",
  "EXPERT trainers add a bonus Rare Candy band")
T.eq(asc.rankBonusLoot(8500, "master", 35), "PP_UP",
  "MASTER trainers add a bonus PP Up band")
T.eq(asc.rankBonusLoot(9000, "legend", 50), "MAX_REVIVE",
  "LEGEND trainers add a bonus Max Revive band")

T.eq(#asd.ranks, 5, "all five field-trainer ranks are defined")
T.eq(#asd.research, 8, "Oak offers eight sequential research assignments")
T.eq(#asd.achievements, 14, "the Crown Archive tracks fourteen titles")
T.eq(#asd.rocket, 4, "Rocket Resurgence has four consecutive operations")
T.eq(#asd.tournament.opponents, 6,
  "the Grand Tournament has six rotating level-100 opponents")
T.eq(#asd.tournament.rules, 4,
  "the Grand Tournament rotates four different rulesets")
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
asc.evaluateAchievements(game)
T.eq(ascState.achievements.leader_confidant, true,
  "all Leader missions unlock KANTO CONFIDANT")
T.eq(ascState.achievements.tournament_champ, true,
  "a completed bracket unlocks GRAND CHAMPION")
T.eq(ascState.achievements.rocket_breaker, true,
  "the fourth Rocket victory unlocks ROCKET BREAKER")
T.eq(ascState.achievements.mew_found, true,
  "catching Mew unlocks MYTH SEEKER")
T.eq(ascState.achievements.ascendant, true,
  "all major systems together unlock KANTO ASCENDANT")

local catchesBeforeCycle = livePostgame.catches
local newCycle = asc.beginNewGamePlus(game)
T.eq(newCycle, 1, "the first safe New Game Plus starts Ascendant Cycle 1")
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

run.release()
T.finish("trainer_rematch")
