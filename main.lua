-- Kanto Ascendant: talk to a trainer you have already beaten to get a
-- ranked rematch. Rematch battles award no money. Each trainer class opens
-- with a line in its own voice, matched to the personality that class
-- shows in its regular dialogue.

local DEFAULT_MIN_REST_STEPS = 151
local DEFAULT_MAX_REST_STEPS = 2510
local DEFAULT_LEVEL_GAIN = 2
local MAX_LEVEL_GAIN = 20
local MAX_LEVEL_BOOST = 99
local MAX_POKEMON_LEVEL = 100

local CRYSTAL_ASSETS = {
  RAIKOU = "raikou", ENTEI = "entei", SUICUNE = "suicune",
  LUGIA = "lugia", HO_OH = "ho_oh", CELEBI = "celebi",
}

local ENTRY_SOURCE = debug.getinfo(1, "S").source
local ENTRY_DIR = ENTRY_SOURCE:sub(1, 1) == "@"
  and ENTRY_SOURCE:sub(2):match("^(.*)/[^/]+$") or "."

local function loadSibling(mod, filename)
  -- mod:read goes through the loader filesystem, so this works identically
  -- for an installed directory, a ZIP and Modkit's virtual validation FS.
  local body, readErr = mod:read(filename)
  local chunk, err
  if body then
    chunk, err = loadstring(body, "@" .. mod.path .. "/" .. filename)
  elseif ENTRY_DIR then
    chunk, err = loadfile(ENTRY_DIR .. "/" .. filename)
  end
  assert(chunk, err or readErr)
  return chunk()
end

local function clampedInteger(value, fallback, minimum, maximum)
  value = math.floor(tonumber(value) or fallback)
  return math.max(minimum, math.min(maximum, value))
end

local function normalizedRestRange(minSteps, maxSteps)
  -- Existing profiles from <=4.2.0 stored the old defaults explicitly.
  -- Treat that exact untouched pair as the new default instead of leaving
  -- upgraded players on the legacy 128-256 range forever.
  if tonumber(minSteps) == 128 and tonumber(maxSteps) == 256 then
    minSteps, maxSteps = DEFAULT_MIN_REST_STEPS, DEFAULT_MAX_REST_STEPS
  end
  minSteps = clampedInteger(minSteps, DEFAULT_MIN_REST_STEPS, 151, 2510)
  maxSteps = clampedInteger(maxSteps, DEFAULT_MAX_REST_STEPS, 151, 2510)
  if minSteps > maxSteps then minSteps, maxSteps = maxSteps, minSteps end
  return minSteps, maxSteps
end

local function rollRestSteps(random, minSteps, maxSteps)
  minSteps, maxSteps = normalizedRestRange(minSteps, maxSteps)
  random = random or math.random
  return clampedInteger(random(minSteps, maxSteps), minSteps, minSteps, maxSteps)
end

local function restLine(steps)
  steps = math.max(1, math.floor(tonumber(steps) or 1))
  return ("Still training!\nCome back in\n%d more step%s."):format(
    steps, steps == 1 and "" or "s")
end

-- The first rematch is already stronger than the original fight.  Every
-- completed rematch raises the next one again until the natural level-100
-- ceiling stops each individual Pokémon.
local function nextLevelBoost(rematches, gain)
  rematches = math.max(0, math.floor(tonumber(rematches) or 0))
  gain = clampedInteger(gain, DEFAULT_LEVEL_GAIN, 0, MAX_LEVEL_GAIN)
  return math.min(MAX_LEVEL_BOOST, (rematches + 1) * gain)
end

local function boostedTeam(team, boost)
  if type(team) ~= "table" then return team end
  boost = math.max(0, math.floor(tonumber(boost) or 0))
  local out = {}
  for i, slot in ipairs(team) do
    local copy = {}
    for key, value in pairs(slot) do copy[key] = value end
    copy.level = math.min(MAX_POKEMON_LEVEL, (tonumber(slot.level) or 1) + boost)
    out[i] = copy
  end
  return out
end

-- One line per trainer class, written in the class's voice.  The line
-- leads straight into the YES/NO prompt, so every one reads as a
-- challenge.  Rows are the text box's lines (max 18 chars each).
local REMATCH_LINES = {
  OPP_YOUNGSTER    = "I like shorts!\nBut I'm not\nlosing twice!",
  OPP_BUG_CATCHER  = "My BUG POKéMON\nwant to battle\nyou again!",
  OPP_LASS         = "I've been training\nsince we last\nfought. Rematch?",
  OPP_SAILOR       = "You're back,\nlandlubber! One\nmore battle?",
  OPP_JR_TRAINER_M = "I'll try harder\nthis time. Let's\nbattle again!",
  OPP_JR_TRAINER_F = "I've practiced\na lot since\nlast time!",
  OPP_POKEMANIAC   = "I've caught even\nmore POKéMON\nsince you beat me!",
  OPP_SUPER_NERD   = "I've studied\nyour strategy.\nLet's try again!",
  OPP_HIKER        = "I've climbed many\nmountains since\nour last battle!",
  OPP_BIKER        = "You're back for\nmore? Let's go\nfor a ride!",
  OPP_BURGLAR      = "You beat me\nonce. I want to\nsettle this!",
  OPP_ENGINEER     = "I've built some\nnew machines.\nTest them!",
  OPP_UNUSED_JUGGLER = "I've been\npracticing my\njuggling. Watch!",
  OPP_FISHER       = "The fish here\naren't the only\nthing I'll catch!",
  OPP_SWIMMER      = "The water's fine.\nLet's battle\nagain!",
  OPP_CUE_BALL     = "I'm not done\nwith you yet.\nRematch!",
  OPP_GAMBLER      = "I'll bet my\nPOKéMON can beat\nyours this time!",
  OPP_BEAUTY       = "I won't lose\nthis time. Care\nfor a rematch?",
  OPP_PSYCHIC_TR   = "I knew you'd\ncome back. Let's\nbattle again!",
  OPP_ROCKER       = "The encore is\nover. Time for\nround two!",
  OPP_JUGGLER      = "I've been\npracticing my\njuggling. Watch!",
  OPP_TAMER        = "My POKéMON are\nhungry for a\nrematch!",
  OPP_BIRD_KEEPER  = "My flying\nPOKéMON want to\nbattle again!",
  OPP_BLACKBELT    = "I've trained hard\nsince our last\nbattle. Rematch?",
  OPP_RIVAL1       = "You again? Fine,\nbut this time\nI'm not losing!",
  OPP_RIVAL2       = "You again? Fine,\nbut this time\nI'm not losing!",
  OPP_RIVAL3       = "You again? Fine,\nbut this time\nI'm not losing!",
  OPP_PROF_OAK     = "Care to battle\nme again, my\nyoung friend?",
  OPP_CHIEF        = "I won't lose\ntwice. Rematch!",
  OPP_SCIENTIST    = "My research\nshows I can\nbeat you now!",
  OPP_GIOVANNI     = "You've got nerve\ncoming back.\nWe'll see!",
  OPP_ROCKET       = "Team Rocket\nalways comes\nback. Rematch!",
  OPP_COOLTRAINER_M = "I've gotten\nstronger since\nwe last fought!",
  OPP_COOLTRAINER_F = "You're strong,\nbut I've trained\nsince then. Again?",
  OPP_BRUNO        = "Hoo hah! My\nmuscles have\ngrown! Rematch!",
  OPP_BROCK        = "You've returned.\nMy rock-hard\nPOKéMON await you!",
  OPP_MISTY        = "You're back!\nMy WATER POKéMON\nare ready for you!",
  OPP_LT_SURGE     = "Shock me again\nif you can,\nkid!",
  OPP_ERIKA        = "How lovely to\nsee you again.\nShall we battle?",
  OPP_KOGA         = "You have grown.\nProve it once\nmore. Rematch.",
  OPP_BLAINE       = "Ha! Fire burns\nbrighter the\nsecond time!",
  OPP_SABRINA      = "I foresaw your\nreturn. I have\nbeen waiting.",
  OPP_GENTLEMAN    = "Care for a\ncivilized\nrematch?",
  OPP_LORELEI      = "The cold winds\ncall for another\nbattle. Come.",
  OPP_CHANNELER    = "The spirits\nwish to see\nanother battle.",
  OPP_AGATHA       = "Heh heh heh.\nBack for more,\nare you?",
  OPP_LANCE        = "My dragons have\nslept long\nenough. Prove\nyourself again!",
}

local DEFAULT_LINE = "You're looking\nfor a rematch?"

-- One line per trainer class for when the player says NO.  Cocky and
-- rough classes mock the player; wise and polite ones are understanding.
local REMATCH_DECLINES = {
  OPP_YOUNGSTER    = "Ha! I knew\nit! Too scared\nto face me!",
  OPP_BUG_CATCHER  = "Chirp chirp!\nScared of a few\nlittle bugs?",
  OPP_LASS         = "Oh, I see.\nToo frightened\nof me, I bet!",
  OPP_SAILOR       = "Avast! Scared\nof the sea,\nare ya?",
  OPP_JR_TRAINER_M = "Coward! I bet\nyou're scared of\na real battle!",
  OPP_JR_TRAINER_F = "You're scared,\naren't you? I\nknew it!",
  OPP_POKEMANIAC   = "Ha! I guess my\ncollection scared\nyou off!",
  OPP_SUPER_NERD   = "Interesting.\nFear is just\npoor calculations.",
  OPP_HIKER        = "Hmph! Scared of\na little climb,\nare ya?",
  OPP_BIKER        = "Chicken! My\nwheels are too\nfast for you!",
  OPP_BURGLAR      = "Smart move.\nYou'd lose your\nPOKéMON to me.",
  OPP_ENGINEER     = "Fear of a\nmachine breakdown?\nHow fitting!",
  OPP_UNUSED_JUGGLER = "Afraid I'll\njuggle you dizzy?\nHeh.",
  OPP_FISHER       = "Got cold feet,\ndid ya? Ha!",
  OPP_SWIMMER      = "Scared to dip\nyour toes in,\nhuh?",
  OPP_CUE_BALL     = "Hah! You're\nscared of my\ntough moves!",
  OPP_GAMBLER      = "Chicken out? I\nwould've bet on\nit. Ha!",
  OPP_BEAUTY       = "Oh my. Afraid\nyour POKéMON\ncan't shine?",
  OPP_PSYCHIC_TR   = "I can see your\nfear. It's\nquite loud.",
  OPP_ROCKER       = "Too loud for\nyou? Ha! What\na pansy!",
  OPP_JUGGLER      = "Afraid I'll\njuggle you dizzy?\nHeh.",
  OPP_TAMER        = "Wise. My beasts\nwould've torn\nyou apart.",
  OPP_BIRD_KEEPER  = "Scared of a\nlittle flight?\nHa!",
  OPP_BLACKBELT    = "A wise choice.\nMy fists are\ntoo strong for\nyou.",
  OPP_RIVAL1       = "Ha! What a\nwimp. I've got\nbetter things\nto do.",
  OPP_RIVAL2       = "Ha! What a\nwimp. I've got\nbetter things\nto do.",
  OPP_RIVAL3       = "Ha! What a\nwimp. I've got\nbetter things\nto do.",
  OPP_PROF_OAK     = "Very well.\nWhen you're\nready, come\nback.",
  OPP_CHIEF        = "Chicken! I\nthought you had\nnerve!",
  OPP_SCIENTIST    = "Fear is a\nvariable I\naccounted for.",
  OPP_GIOVANNI     = "Coward. I\nexpected better\nof you.",
  OPP_ROCKET       = "Scared of Team\nRocket's power,\nhuh?",
  OPP_COOLTRAINER_M = "Too cool for a\nrematch? Ha!",
  OPP_COOLTRAINER_F = "Chicken! And\nhere I thought\nyou were strong.",
  OPP_BRUNO        = "Hoo hah! Fear\nis a weakness!\nTrain harder!",
  OPP_BROCK        = "Hm. You aren't\nready. Come\nback when you\nare.",
  OPP_MISTY        = "Heh, scared of\nsome WATER\nPOKéMON?",
  OPP_LT_SURGE     = "Ha! Scared of\na little shock?\nSome soldier\nyou are!",
  OPP_ERIKA        = "How shy. When\nyou're ready,\nI'll be here.",
  OPP_KOGA         = "Fear is poison.\nTrain your\nmind, then\nreturn.",
  OPP_BLAINE       = "Ha! The heat\ntoo much for\nyou?",
  OPP_SABRINA      = "I foresaw this\ntoo. Your fear\nis clear.",
  OPP_GENTLEMAN    = "Very well. A\ntrue gentleman\nnever presses.",
  OPP_LORELEI      = "Cold feet in\nthe cold winds?\nHow fitting.",
  OPP_CHANNELER    = "The spirits\ncan wait. Fear\nis natural.",
  OPP_AGATHA       = "Heh heh. Scared\nof an old\nwoman, are you?",
  OPP_LANCE        = "I respect a\ncareful trainer.\nTrain, then\nreturn.",
}

local DEFAULT_DECLINE = "Ha! Scared of\na rematch, are\nyou?"

-- One line per trainer class for the "your team is far stronger" warning,
-- spoken when the rematch team averages more than 10 levels above the
-- player's party.  Same voice as the challenge lines: the class owns the
-- warning.  Rows are the text box's lines (max 18 chars each).
local REMATCH_WARNINGS = {
  OPP_BROCK      = "Hm. My team is\nfar stronger than\nbefore. Are you\nsure?",
  OPP_MISTY      = "My POKéMON have\ngrown far beyond\nyours. Really?",
  OPP_LT_SURGE   = "Warning: my team\nis on another\nlevel. Still in?",
  OPP_ERIKA      = "My flowers have\nbloomed past your\nteam's strength.\nStill sure?",
  OPP_KOGA       = "My poison has\ngrown deadlier\nthan your team\ncan handle. Sure?",
  OPP_BLAINE     = "The heat burns\nfar beyond your\nteam. Ready?",
  OPP_SABRINA    = "I foresee your\nteam is far\nbehind mine. Are\nyou certain?",
  OPP_LORELEI    = "My cold winds\nare far stronger\nthan your team.\nContinue?",
  OPP_BRUNO      = "Hoo hah! My power\nis far beyond\nyours! Still\nsure?",
  OPP_AGATHA     = "Heh heh. My\nghosts are far\nabove your team.\nSure about this?",
  OPP_LANCE      = "My dragons tower\nfar above your\nteam. Do you\nreally wish to?",
  OPP_RIVAL3     = "My team is far\nstronger than\nyours now. Sure?",
}

local DEFAULT_WARN = "My team is far\nstronger than\nyours. Are you\nsure?"

local function resolveWarning(classId)
  return REMATCH_WARNINGS[classId] or DEFAULT_WARN
end

-- How many levels the trainer's team averages above the player's party;
-- nil when either side is empty, so callers can skip the warning.
local function levelGap(playerParty, team)
  if not team or #team == 0 then return nil end
  local playerLevels, playerCount = 0, 0
  if playerParty then
    for _, mon in ipairs(playerParty) do
      if mon and mon.level then
        playerLevels = playerLevels + mon.level
        playerCount = playerCount + 1
      end
    end
  end
  if playerCount == 0 then return nil end
  local teamLevels = 0
  for _, slot in ipairs(team) do
    teamLevels = teamLevels + (slot.level or 0)
  end
  return (teamLevels / #team) - (playerLevels / playerCount)
end

local function resolveLine(classId)
  return REMATCH_LINES[classId] or DEFAULT_LINE
end

local function resolveDecline(classId)
  return REMATCH_DECLINES[classId] or DEFAULT_DECLINE
end

-- the prize line filtered out of rematch victory queues
local function isPrizeLine(text)
  return type(text) == "string" and text:find("got ", 1, true) ~= nil
    and text:find("for winning", 1, true) ~= nil
end

return function(mod)
  local makeLocalization = loadSibling(mod, "localization.lua")
  local i18n = makeLocalization(mod)
  local recruitment = loadSibling(mod, "trainer_recruits.lua")
  local loot = loadSibling(mod, "rematch_loot.lua")
  local function menuLabel(english, german)
    return i18n.isGerman() and german or english
  end

  mod.options:define({
    { key = "language", label = menuLabel("LANGUAGE", "SPRACHE"), type = "choice",
      default = "auto",
      choices = { { "AUTO", "auto" }, { "ENGLISH", "en" },
                  { "DEUTSCH", "de" } } },
    { key = "rest_min", label = menuLabel("MIN REST STEPS", "MIN PAUSE"),
      type = "number",
      default = DEFAULT_MIN_REST_STEPS, min = 151, max = 2510, step = 1 },
    { key = "rest_max", label = menuLabel("MAX REST STEPS", "MAX PAUSE"),
      type = "number",
      default = DEFAULT_MAX_REST_STEPS, min = 151, max = 2510, step = 1 },
    { key = "level_gain", label = menuLabel("LEVELS / REMATCH", "LEVEL / REVANCHE"),
      type = "number",
      default = DEFAULT_LEVEL_GAIN, min = 0, max = MAX_LEVEL_GAIN, step = 1 },
    { key = "team_growth", label = menuLabel("TEAM GROWTH", "TEAM-WACHSTUM"),
      type = "toggle", default = true },
    { key = "loot_mode", label = menuLabel("REMATCH LOOT", "REVANCHEN-BEUTE"),
      type = "choice", default = "balanced",
      choices = {
        { menuLabel("OFF", "AUS"), "off" },
        { menuLabel("BALANCED", "NORMAL"), "balanced" },
        { menuLabel("GENEROUS", "VIEL"), "generous" },
      } },
    { key = "kanto_151",
      label = menuLabel("KANTO 151 RESTART", "KANTO 151 NEUST."),
      type = "choice", default = "ascendant",
      choices = {
        { menuLabel("REWARDS", "BELOHNUNGEN"), "ascendant" },
        { menuLabel("WILD", "WILD"), "wild" },
        { menuLabel("OFF", "AUS"), "off" },
      } },
    { key = "legend_art", label = menuLabel("JOHTO ART", "JOHTO-GRAFIK"),
      type = "choice",
      default = "crystal",
      choices = {
        { menuLabel("CRYSTAL (BUNDLED)", "KRISTALL (ENTHALTEN)"), "crystal" },
        { menuLabel("KANTO FALLBACK", "KANTO-ERSATZ"), "original" },
      } },
    { key = "kanto_crystal_art",
      label = menuLabel("KANTO CRYSTAL ART", "KANTO-KRISTALLGRAFIK"),
      type = "toggle", default = true },
    { key = "crystal_animation",
      label = menuLabel("CRYSTAL ANIMATION", "KRISTALL-ANIMATION"),
      type = "toggle", default = true },
    { key = "shiny_hunts", label = menuLabel("SHINY HUNTS", "SHINY-JAGD"),
      type = "choice", default = "ascendant",
      choices = {
        { menuLabel("ASCENDANT", "ASCENDANT"), "ascendant" },
        { menuLabel("NATURAL 1/8192", "NATÜRLICH 1/8192"), "natural" },
      } },
    { key = "shiny_effects",
      label = menuLabel("SHINY EFFECTS", "SHINY-EFFEKTE"),
      type = "toggle", default = true },
    { key = "shiny_protection",
      label = menuLabel("SHINY RELEASE LOCK", "SHINY-SCHUTZ"),
      type = "toggle", default = true },
    { key = "shiny_event",
      label = menuLabel("RED GYARADOS", "ROTES GARADOS"),
      type = "toggle", default = true },
    { key = "mega_evolution",
      label = menuLabel("MEGA EVOLUTION", "MEGA-ENTWICKLUNG"),
      type = "toggle", default = true },
    { key = "mega_opponents",
      label = menuLabel("ENEMY MEGA", "GEGNER-MEGA"),
      type = "choice", default = "bosses",
      choices = {
        { menuLabel("BOSSES", "BOSSE"), "bosses" },
        { menuLabel("ALL TRAINERS", "ALLE TRAINER"), "all" },
        { menuLabel("OFF", "AUS"), "off" },
      } },
    { key = "johto_time", label = menuLabel("JOHTO TIME", "JOHTO-ZEIT"),
      type = "choice", default = "auto",
      choices = {
        { menuLabel("AUTO CLOCK", "AUTO-UHR"), "auto" },
        { menuLabel("DAY", "TAG"), "day" },
        { menuLabel("NIGHT", "NACHT"), "night" },
      } },
    { key = "legend_articuno", label = "ARTICUNO", type = "choice",
      default = "apex",
      choices = { { "APEX", "apex" }, { "VANILLA", "vanilla" },
                  { menuLabel("OFF", "AUS"), "off" } } },
    { key = "legend_zapdos", label = "ZAPDOS", type = "choice",
      default = "apex",
      choices = { { "APEX", "apex" }, { "VANILLA", "vanilla" },
                  { menuLabel("OFF", "AUS"), "off" } } },
    { key = "legend_moltres", label = "MOLTRES", type = "choice",
      default = "apex",
      choices = { { "APEX", "apex" }, { "VANILLA", "vanilla" },
                  { menuLabel("OFF", "AUS"), "off" } } },
    { key = "legend_mewtwo", label = "MEWTWO", type = "choice",
      default = "apex",
      choices = { { "APEX", "apex" }, { "VANILLA", "vanilla" },
                  { menuLabel("OFF", "AUS"), "off" } } },
    { key = "legend_raikou", label = "RAIKOU", type = "toggle", default = true },
    { key = "legend_entei", label = "ENTEI", type = "toggle", default = true },
    { key = "legend_suicune", label = "SUICUNE", type = "toggle", default = true },
    { key = "legend_lugia", label = "LUGIA", type = "toggle", default = true },
    { key = "legend_ho_oh", label = "HO-OH", type = "toggle", default = true },
    { key = "legend_celebi", label = "CELEBI", type = "toggle", default = true },
    { key = "legend_mew", label = "MEW", type = "toggle", default = true },
    { key = "mew_profile", label = menuLabel("MEW PROFILE", "MEW-PROFIL"),
      type = "choice", default = "ascendant",
      choices = {
        { menuLabel("ASCENDANT LV.100", "ASCENDANT LV.100"), "ascendant" },
        { menuLabel("HISTORICAL LV.5", "HISTORISCH LV.5"), "historical" },
      } },
    { key = "event_mode", label = menuLabel("HERITAGE EVENTS", "HERITAGE-EVENTS"),
      type = "choice", default = "festival",
      choices = {
        { menuLabel("FESTIVAL CUPS", "FESTIVAL-CUPS"), "festival" },
        { menuLabel("ROAMING HUNTS", "WANDERNDE JAGD"), "roaming" },
        { menuLabel("OFF", "AUS"), "off" },
      } },
    { key = "event_university_magikarp", label = "UNIV. MAGIKARP",
      type = "toggle", default = true },
    { key = "event_stamp_fearow", label = "STAMP FEAROW",
      type = "toggle", default = true },
    { key = "event_flying_pikachu", label = "FLYING PIKACHU",
      type = "toggle", default = true },
    { key = "event_stamp_rapidash", label = "STAMP RAPIDASH",
      type = "toggle", default = true },
    { key = "event_surfing_pikachu", label = "SURFING PIKACHU",
      type = "toggle", default = true },
    { key = "event_flee", label = menuLabel("ROAMERS CAN FLEE", "WANDERER FLIEHEN"),
      type = "toggle", default = true },
    { key = "event_rosette", label = menuLabel("EVENT ROSETTE", "EVENT-ROSETTE"),
      type = "toggle", default = true },
    { key = "rocket_story", label = menuLabel("ROCKET STORY", "ROCKET-STORY"),
      type = "toggle", default = true },
    { key = "grand_tournament",
      label = menuLabel("BATTLE FRONTIER", "KAMPF-FRONTIER"),
      type = "toggle", default = true },
    { key = "ascendant_rules",
      label = menuLabel("NEW GAME+ RULES", "NEW-GAME+-REGELN"),
      type = "choice", default = "rotating",
      choices = {
        { menuLabel("ROTATING", "ROTIEREND"), "rotating" },
        { menuLabel("NO ITEMS", "KEINE ITEMS"), "ascendant" },
        { menuLabel("NORMAL", "NORMAL"), "normal" },
      } },
  })

  local function localizedLine(classId)
    return i18n.rematch(classId, resolveLine(classId))
  end
  local function localizedDecline(classId)
    return i18n.decline(classId, resolveDecline(classId))
  end
  local function localizedWarning(classId)
    return i18n.warning(classId, resolveWarning(classId))
  end
  local function localizedRestLine(steps)
    return i18n.rest(steps, restLine(steps))
  end

  -- The major post-game expansion lives in focused modules so the original
  -- field-trainer rematch path stays small and backwards-compatible.
  local postgameData = loadSibling(mod, "postgame_data.lua")
  postgameData.dialogue = loadSibling(mod, "postgame_dialogue.lua")
  local johtoData = loadSibling(mod, "johto_data.lua")
  local makeAscendantMenu = loadSibling(mod, "ascendant_menu.lua")
  local ascendantMenu = makeAscendantMenu(mod, { i18n = i18n })
  mod.exports.ascendantMenu = ascendantMenu
  local makeSpriteAssets = loadSibling(mod, "sprite_assets.lua")
  local spriteAssets = makeSpriteAssets(mod)
  mod.exports.spriteAssets = spriteAssets
  for _, species in ipairs(johtoData.order) do
    CRYSTAL_ASSETS[species] = species:lower()
  end
  CRYSTAL_ASSETS.HO_OH = "ho_oh"
  local registerSpecies = loadSibling(mod, "postgame_species.lua")
  local contentEnabled, johtoAudio =
    registerSpecies(mod, postgameData, johtoData, i18n)
  mod.exports.johtoAudio = johtoAudio
  local makeKantoCompletion = loadSibling(mod, "kanto_completion.lua")
  local kantoCompletion = makeKantoCompletion(mod, {
    i18n = i18n,
    contentEnabled = contentEnabled,
  })
  mod.exports.kantoCompletion = kantoCompletion
  local makeFieldTech = loadSibling(mod, "field_tech.lua")
  local fieldTech = makeFieldTech(mod, {
    i18n = i18n,
    contentEnabled = contentEnabled,
  })
  mod.exports.fieldTech = fieldTech
  local makePostgameEvents = loadSibling(mod, "postgame_events.lua")
  local makePostgame = loadSibling(mod, "postgame.lua")
  local postgame = makePostgame(mod, postgameData, {
    contentEnabled = contentEnabled,
    i18n = i18n,
    makeEvents = makePostgameEvents,
    fieldTech = fieldTech,
    kantoCompletion = kantoCompletion,
  })
  mod.exports.postgame = postgame
  mod.exports.postgameData = postgameData
  mod.exports.johtoData = johtoData
  local breedingData = loadSibling(mod, "breeding_data.lua")
  local makeDaycare = loadSibling(mod, "daycare.lua")
  local daycare = makeDaycare(mod, {
    postgame = postgame,
    i18n = i18n,
    contentEnabled = contentEnabled,
    breedingData = breedingData,
    fieldTech = fieldTech,
  })
  local makeMegaEvolution = loadSibling(mod, "mega_evolution.lua")
  local megaAnimationData = loadSibling(mod, "mega_animation_data.lua")
  local megaEvolution = makeMegaEvolution(mod, {
    postgame = postgame,
    i18n = i18n,
    contentEnabled = contentEnabled,
    animationData = megaAnimationData,
  })
  daycare.setMega(megaEvolution)
  local makeShinySystem = loadSibling(mod, "shiny_system.lua")
  local shinySystem = makeShinySystem(mod, {
    postgame = postgame,
    i18n = i18n,
  })
  local crystalAnimationData = loadSibling(mod, "crystal_animation_data.lua")
  local makeCrystalAnimation = loadSibling(mod, "crystal_animation.lua")
  local crystalAnimation = makeCrystalAnimation(mod, {
    animationData = crystalAnimationData,
    shinySystem = shinySystem,
    speciesOrder = johtoData.order,
  })
  daycare.setShinySystem(shinySystem)
  mod.exports.daycare = daycare
  mod.exports.breedingData = breedingData
  mod.exports.megaEvolution = megaEvolution
  mod.exports.shinySystem = shinySystem
  mod.exports.crystalAnimation = crystalAnimation
  local makeFollowerCompat = loadSibling(mod, "follower_compat.lua")
  local followerCompat = makeFollowerCompat(mod, {
    spriteAssets = spriteAssets,
    shinySystem = shinySystem,
  })
  mod.exports.followerCompat = followerCompat
  local makeJohtoResearch = loadSibling(mod, "johto_research.lua")
  local johtoResearch = makeJohtoResearch(mod, {
    data = johtoData,
    postgame = postgame,
    i18n = i18n,
    contentEnabled = contentEnabled,
    daycare = daycare,
  })
  shinySystem.setJohtoResearch(johtoResearch)
  mod.exports.johtoResearch = johtoResearch
  local ascendantData = loadSibling(mod, "ascendant_data.lua")
  local makeAscendant = loadSibling(mod, "ascendant.lua")
  local ascendant
  local eventData = loadSibling(mod, "event_data.lua")
  local makeEventArchive = loadSibling(mod, "event_archive.lua")
  local eventArchive = makeEventArchive(mod, {
    data = eventData,
    postgame = postgame,
    i18n = i18n,
  })
  mod.exports.eventArchive = eventArchive
  mod.exports.eventData = eventData

  -- Official Crystal battle art is bundled for all 251 species. Johto also
  -- has authentic back sprites; Kanto keeps the Gen-I player back in 2D and
  -- uses its bundled Crystal front in ordinary enemy and Voxel positions.
  local crystalAvailable = {}
  local crystalShinyAvailable = {}
  for species, name in pairs(CRYSTAL_ASSETS) do
    local front = "assets/crystal/" .. name .. "_front.png"
    local back = "assets/crystal/" .. name .. "_back.png"
    crystalAvailable[species] =
      mod:read(front) ~= nil and mod:read(back) ~= nil
    crystalShinyAvailable[species] =
      mod:read("assets/crystal/" .. name .. "_front_shiny.png") ~= nil
      and mod:read("assets/crystal/" .. name .. "_back_shiny.png") ~= nil
  end
  mod.exports.crystalSprites = crystalAvailable
  mod.exports.crystalShinySprites = crystalShinyAvailable
  mod.hooks:wrap("pokemon.sprite", function(nextSprite, path, ctx)
    local requestedPath = path
    if shinySystem then shinySystem.prepareSprite(ctx) end
    path = nextSprite(path, ctx)
    local name = ctx and CRYSTAL_ASSETS[ctx.species]
    local selectedSide = ctx.side == "back" and "back" or "front"
    -- Dramatic Shape asks the normal back-sprite route, then replaces its
    -- answer with the species' front path so both battlers face the voxel
    -- camera. Preserve that decision instead of forcing the Crystal back
    -- sprite over it.
    local def = ctx.data and ctx.data.pokemon
      and ctx.data.pokemon[ctx.species]
    local voxelFront = selectedSide == "back"
      and def and path == def.spriteFront
    if voxelFront then
      selectedSide = "front"
    end
    -- A lower-priority visual mod that explicitly replaced the requested
    -- path owns this species. Dramatic Shape's intentional back->front swap
    -- is the one exception: Ascendant supplies its matching Crystal front.
    local externalOverride = type(path) == "string" and path ~= ""
      and path ~= requestedPath and not voxelFront
    if externalOverride then
      if crystalAnimation then
        crystalAnimation.select(ctx, selectedSide, true)
      end
      return shinySystem and shinySystem.spritePath(path, ctx) or path
    end
    if mod.options:get("legend_art") ~= "crystal"
        or not name or not crystalAvailable[ctx.species] then
      local animated = crystalAnimation
        and crystalAnimation.select(ctx, selectedSide, false)
      if animated then return animated end
      return shinySystem and shinySystem.spritePath(path, ctx) or path
    end
    -- Crystal PNGs carry their own limited GBC palette. Opt them out of
    -- Gen1's four-shade/SGB recolor; the original fallback remains
    -- palette-aware.
    ctx.trueColor = true
    local shiny = shinySystem and shinySystem.isShiny(ctx.mon)
      and crystalShinyAvailable[ctx.species]
    local relative = "assets/crystal/" .. name .. "_"
      .. selectedSide .. (shiny and "_shiny" or "") .. ".png"
    local animated = crystalAnimation
      and crystalAnimation.select(ctx, selectedSide, false)
    if animated then return animated end
    return spriteAssets.crystal(relative)
      or (mod.path .. "/" .. relative)
  end, 100)

  mod.exports.resolveLine = localizedLine
  mod.exports.resolveDecline = localizedDecline
  mod.exports.resolveWarning = localizedWarning
  mod.exports.levelGap = levelGap
  mod.exports.isPrizeLine = isPrizeLine
  mod.exports.restLine = localizedRestLine
  mod.exports.language = function()
    return i18n.isGerman() and "de" or "en"
  end
  mod.exports.rollRestSteps = rollRestSteps
  mod.exports.nextLevelBoost = nextLevelBoost
  mod.exports.boostedTeam = boostedTeam
  mod.exports.recruitTeam = recruitment.expand
  mod.exports.recruitPools = recruitment.pools
  mod.exports.lootForRoll = loot.select
  mod.exports.lootBands = loot.bands
  mod.exports.defaults = {
    minRestSteps = DEFAULT_MIN_REST_STEPS,
    maxRestSteps = DEFAULT_MAX_REST_STEPS,
    levelGain = DEFAULT_LEVEL_GAIN,
    maxLevelBoost = MAX_LEVEL_BOOST,
  }

  -- `step_clock` is the literal number of tiles walked. Systems such as
  -- friendship, eggs and world events must never observe Training Rush's
  -- trainer-only bonus. `trainer_step_clock` is the accelerated timeline
  -- used exclusively by field-trainer recovery and silent growth.
  local function playerStepClock()
    return math.max(0, math.floor(tonumber(mod.save:get("step_clock", 0)) or 0))
  end

  local function stepClock()
    local clock = mod.save:get("trainer_step_clock")
    if clock == nil then return playerStepClock() end
    return math.max(0, math.floor(tonumber(clock) or 0))
  end

  mod.exports.playerStepClock = playerStepClock
  mod.exports.trainerStepClock = stepClock

  local function trainerStates()
    local states = mod.save:get("trainers")
    if type(states) ~= "table" then
      states = {}
      mod.save:set("trainers", states)
    end
    return states
  end

  local makeWorldEvents = loadSibling(mod, "world_events.lua")
  local worldEvents = makeWorldEvents(mod, {
    postgame = postgame,
    i18n = i18n,
    johtoResearch = johtoResearch,
  })
  shinySystem.setWorldEvents(worldEvents)
  mod.exports.worldEvents = worldEvents

  ascendant = makeAscendant(mod, postgameData, {
    data = ascendantData,
    postgame = postgame,
    i18n = i18n,
    trainerStates = trainerStates,
    eventArchive = eventArchive,
    johtoResearch = johtoResearch,
    worldEvents = worldEvents,
    kantoCompletion = kantoCompletion,
  })
  eventArchive.setAscendant(ascendant)
  postgame.extension = ascendant
  mod.exports.ascendant = ascendant
  mod.exports.ascendantData = ascendantData

  local makeFrontierExchange = loadSibling(mod, "frontier_exchange.lua")
  local frontierExchange = makeFrontierExchange(mod, {
    i18n = i18n,
    postgame = postgame,
    wallet = ascendant,
    johtoResearch = johtoResearch,
    fieldTech = fieldTech,
  })
  daycare.setFrontierExchange(frontierExchange)
  mod.exports.frontierExchange = frontierExchange

  local johtoMastersData = loadSibling(mod, "johto_masters_data.lua")
  local makeJohtoMasters = loadSibling(mod, "johto_masters.lua")
  local johtoMasters = makeJohtoMasters(mod, {
    data = johtoMastersData,
    postgame = postgame,
    ascendant = ascendant,
    shinySystem = shinySystem,
    i18n = i18n,
  })
  ascendant.setJohtoMasters(johtoMasters)
  mod.exports.johtoMasters = johtoMasters
  mod.exports.johtoMastersData = johtoMastersData

  local makeDexProgress = loadSibling(mod, "dex_progress.lua")
  local dexProgress = makeDexProgress(mod, {
    i18n = i18n,
    postgame = postgame,
    johtoData = johtoData,
    shinySystem = shinySystem,
    ascendant = ascendant,
  })
  mod.exports.dexProgress = dexProgress

  local makeAscendantTyphlosion = loadSibling(
    mod, "ascendant_typhlosion.lua")
  local ascendantTyphlosion = makeAscendantTyphlosion(mod, {
    i18n = i18n,
    johtoMasters = johtoMasters,
    megaEvolution = megaEvolution,
    showMenu = false,
  })
  mod.exports.ascendantTyphlosion = ascendantTyphlosion
  local makeStarterRelicQuests = loadSibling(
    mod, "starter_relic_quests.lua")
  local starterRelicQuests = makeStarterRelicQuests(mod, {
    i18n = i18n,
    megaEvolution = megaEvolution,
    ascendantTyphlosion = ascendantTyphlosion,
  })
  mod.exports.starterRelicQuests = starterRelicQuests

  local makeResearchAtlas = loadSibling(mod, "research_atlas.lua")
  local researchAtlas = makeResearchAtlas(mod, {
    i18n = i18n,
    postgame = postgame,
    ascendant = ascendant,
    ascendantData = ascendantData,
    fieldTech = fieldTech,
    kantoCompletion = kantoCompletion,
    johtoResearch = johtoResearch,
    lootBands = loot.bands,
    trainerStates = trainerStates,
    stepClock = stepClock,
  })
  mod.exports.researchAtlas = researchAtlas

  local grandTourData = loadSibling(mod, "grand_tour_data.lua")
  local makeGrandTour = loadSibling(mod, "grand_tour.lua")
  local grandTour = makeGrandTour(mod, {
    data = grandTourData,
    postgame = postgame,
    i18n = i18n,
    stepClock = playerStepClock,
    awardFrontierPoints = function(amount)
      local multiplier = worldEvents and worldEvents.frontierMultiplier
        and worldEvents.frontierMultiplier() or 1
      return ascendant.addFrontierPoints(
        math.max(0, math.floor(tonumber(amount) or 0))
          * math.max(1, math.floor(tonumber(multiplier) or 1)))
    end,
    unlockTitle = function(id)
      return ascendant.unlockAchievement(id)
    end,
  })
  mod.exports.grandTour = grandTour
  mod.exports.grandTourData = grandTourData

  local makeQuestTracker = loadSibling(mod, "quest_tracker.lua")
  local questTracker = makeQuestTracker(mod, {
    i18n = i18n,
    postgame = postgame,
    postgameData = postgameData,
    ascendant = ascendant,
    ascendantData = ascendantData,
    johtoResearch = johtoResearch,
    johtoData = johtoData,
    johtoMasters = johtoMasters,
    grandTour = grandTour,
    ascendantTyphlosion = ascendantTyphlosion,
    starterRelicQuests = starterRelicQuests,
  })
  ascendant.setQuestTracker(questTracker)
  researchAtlas.setQuestTracker(questTracker)
  mod.exports.questTracker = questTracker

  local makeOnboarding = loadSibling(mod, "onboarding.lua")
  local onboarding = makeOnboarding(mod, {
    i18n = i18n,
    postgame = postgame,
    questTracker = questTracker,
  })
  mod.exports.onboarding = onboarding

  local makeLegacyHall = loadSibling(mod, "legacy_hall.lua")
  local legacyHall = makeLegacyHall(mod, {
    i18n = i18n,
    postgame = postgame,
    ascendant = ascendant,
    ascendantData = ascendantData,
    johtoMasters = johtoMasters,
    grandTour = grandTour,
  })
  mod.exports.legacyHall = legacyHall

  local function trainerKey(overworld, npc)
    if npc and npc.id then return tostring(npc.id) end
    local mapId = overworld and overworld.map and overworld.map.id or "UNKNOWN"
    local index = npc and npc.def and npc.def.index or "?"
    return tostring(mapId) .. "_obj_" .. tostring(index)
  end

  local function stateFor(key, create)
    local states = trainerStates()
    local state = states[key]
    if type(state) ~= "table" and create then
      state = { rematches = 0, trainingCycles = 0 }
      states[key] = state
    end
    if type(state) == "table" then
      state.rematches = math.max(0, math.floor(
        tonumber(state.rematches) or 0))
      state.trainingCycles = math.max(0, math.floor(
        tonumber(state.trainingCycles) or 0))
    end
    return state
  end

  local function levelGain()
    return clampedInteger(mod.options:get("level_gain"),
      DEFAULT_LEVEL_GAIN, 0, MAX_LEVEL_GAIN)
  end

  local function randomSource(deps)
    if deps and deps.random then return deps.random end
    if love and love.math and love.math.random then return love.math.random end
    return math.random
  end

  local function rollConfiguredRest(deps)
    local minSteps, maxSteps = normalizedRestRange(
      mod.options:get("rest_min"), mod.options:get("rest_max"))
    return rollRestSteps(randomSource(deps), minSteps, maxSteps)
  end

  local function scheduleNextTraining(state, startAt, deps)
    local duration = rollConfiguredRest(deps)
    state.nextTrainingAt = math.floor(tonumber(startAt) or stepClock()) + duration
    state.lastTraining = duration
    return duration
  end

  -- Once the visible post-battle rest has expired, the trainer stays ready
  -- but keeps training on silent rest-sized intervals. Every fully completed
  -- interval raises the next rematch tier. Settling on every world step makes
  -- this genuinely background progression; the lazy calls also repair old
  -- saves that predate nextTrainingAt.
  local function settleTraining(state, deps)
    if type(state) ~= "table" or not state.readyAt then return 0 end
    local clock = stepClock()
    if clock < state.readyAt then return 0 end
    state.trainingCycles = math.max(0, math.floor(
      tonumber(state.trainingCycles) or 0))
    if not state.nextTrainingAt then
      -- A 1.0.5-or-older save cannot tell how long its ready trainer has
      -- already waited. Start the first silent cycle now rather than granting
      -- speculative levels retroactively.
      scheduleNextTraining(state, clock, deps)
      return 0
    end

    local gained = 0
    while clock >= state.nextTrainingAt
        and state.trainingCycles < MAX_LEVEL_BOOST do
      state.trainingCycles = state.trainingCycles + 1
      gained = gained + 1
      scheduleNextTraining(state, state.nextTrainingAt, deps)
    end
    -- +99 reaches level 100 even from level 1 when LEVEL GAIN is 1. Keep the
    -- silent clock moving without an unbounded catch-up loop once no further
    -- strength can be represented.
    if clock >= state.nextTrainingAt then
      scheduleNextTraining(state, clock, deps)
    end
    return gained
  end

  local function settleAllTraining(deps)
    for _, state in pairs(trainerStates()) do
      settleTraining(state, deps)
    end
  end

  local function migrateRestTimers(deps)
    if tonumber(mod.save:get("rest_range_version", 0)) >= 2 then return end
    local clock = stepClock()
    for _, state in pairs(trainerStates()) do
      local lastRest = tonumber(state.lastRest)
      if state.readyAt and state.readyAt > clock
          and lastRest and lastRest >= 1 and lastRest <= 256 then
        local duration = rollConfiguredRest(deps)
        state.readyAt = clock + duration
        state.lastRest = duration
        scheduleNextTraining(state, state.readyAt, deps)
      elseif state.readyAt and state.readyAt <= clock
          and tonumber(state.lastTraining)
          and tonumber(state.lastTraining) <= 256 then
        scheduleNextTraining(state, clock, deps)
      end
    end
    mod.save:set("rest_range_version", 2)
  end
  mod.exports.migrateRestTimers = migrateRestTimers

  local function remainingSteps(key)
    local state = stateFor(key, false)
    if not state or not state.readyAt then return 0 end
    settleTraining(state)
    return math.max(0, math.floor(state.readyAt - stepClock()))
  end

  local function trainingCycles(key)
    local state = stateFor(key, false)
    if not state then return 0 end
    settleTraining(state)
    return state.trainingCycles
  end

  local function scheduleRest(key, deps)
    local state = stateFor(key, true)
    local duration = rollConfiguredRest(deps)
    state.readyAt = stepClock() + duration
    state.lastRest = duration
    -- This second interval is invisible: readiness remains available after
    -- readyAt, while reaching nextTrainingAt grows the team in the background.
    scheduleNextTraining(state, state.readyAt, deps)
    return duration
  end

  local function seedDefeatedTrainers(save, deps)
    for key, defeated in pairs((save and save.defeatedTrainers) or {}) do
      if defeated and not stateFor(key, false) then scheduleRest(key, deps) end
    end
  end

  local function strengthenBattle(game, battle, boost)
    battle.rematchLevelBoost = boost
    if boost <= 0 or not battle.enemyParty then return end

    local Pokemon = require("src.pokemon.Pokemon")
    local Stats = require("src.pokemon.Stats")
    local Growth = require("src.pokemon.Growth")
    for _, mon in ipairs(battle.enemyParty) do
      local oldLevel = tonumber(mon.level) or 1
      local newLevel = math.min(MAX_POKEMON_LEVEL, oldLevel + boost)
      if newLevel > oldLevel then
        local species = game.data.pokemon[mon.species]
        -- Growing between rematches can teach normal level-up moves while
        -- preserving any special trainer moves already applied by the
        -- battle constructor.
        Pokemon.learnMovesFromDayCare(game.data, mon, species, oldLevel, newLevel)
        mon.level = newLevel
        mon.exp = Growth.expForLevel(species.growthRate, newLevel,
                                      game.data.growth_rates)
        local fresh = Stats.calc(species, newLevel, mon.dvs, mon.statExp)
        -- The active battler points at this stats table already, so mutate
        -- it in place instead of replacing it underneath the HUD/damage code.
        mon.stats = mon.stats or {}
        for stat, value in pairs(fresh) do mon.stats[stat] = value end
        mon.hp = mon.stats.hp
      end
    end
    if battle.enemy and battle.enemy.mon then
      battle.enemy.shownHP = battle.enemy.mon.hp
    end
  end

  local function appendRecruits(game, battle, team)
    if not (battle and battle.enemyParty and type(team) == "table") then return 0 end
    local first = #battle.enemyParty + 1
    if first > #team then return 0 end
    local Pokemon = require("src.pokemon.Pokemon")
    local Stats = require("src.pokemon.Stats")
    local trainerDvs = (game.data.constants and game.data.constants.trainerDvs)
      or { hp = 8, attack = 9, defense = 8, speed = 8, special = 8 }
    local added = 0
    for i = first, math.min(6, #team) do
      local slot = team[i]
      if game.data.pokemon[slot.species] then
        local mon = Pokemon.new(game.data, slot.species, slot.level,
          function(lo, hi) return math.floor((lo + hi) / 2) end)
        mon.dvs = trainerDvs
        mon.stats = Stats.calc(game.data.pokemon[slot.species],
          slot.level, trainerDvs)
        mon.hp = mon.stats.hp
        if slot.moves then
          mon.moves = {}
          for _, moveId in ipairs(slot.moves) do
            local move = game.data.moves[moveId]
            mon.moves[#mon.moves + 1] = {
              id = moveId, pp = move and move.pp or 0,
            }
          end
        end
        battle.enemyParty[#battle.enemyParty + 1] = mon
        added = added + 1
      end
    end
    return added
  end

  local function itemName(game, itemId)
    local def = game.data.items and game.data.items[itemId]
    return def and def.name or itemId
  end

  local function playerName(game)
    return game.save.player and game.save.player.name or "PLAYER"
  end

  local function markUniqueLoot(game, itemId)
    if itemId == "EXP_ALL" then
      game.save.flags = game.save.flags or {}
      -- EXP.ALL is the fully functional Gen-1 EP-TEILER. Mark Oak's Aide
      -- reward as claimed so he cannot hand out a duplicate later.
      game.save.flags.EVENT_GOT_EXP_ALL = true
    end
  end

  local function hasPendingItem(itemId)
    for _, trainerState in pairs(trainerStates()) do
      if trainerState.pendingLoot
          and trainerState.pendingLoot.item == itemId then return true end
    end
    return false
  end

  local function expAllAvailable(game)
    local inventory = game.save.inventory or {}
    local flags = game.save.flags or {}
    return not inventory.EXP_ALL and not flags.EVENT_GOT_EXP_ALL
      and not hasPendingItem("EXP_ALL")
  end

  local function masterBallUnlocked()
    local s = postgame and postgame.state(false)
    return s and s.apexChampion and true or false
  end

  local function lootRoll(deps)
    local rng = deps and deps.lootRandom
    if not rng and love and love.math and love.math.random then
      rng = love.math.random
    end
    return (rng or math.random)(1, 10000)
  end

  local function lootMessage(game, trainerName, itemId, kind)
    local name = itemName(game, itemId)
    local player = playerName(game)
    if kind == "pending" then
      return i18n.text(
        ("%s kept the\n%s safe.\f%s received the\n%s!"):format(
          trainerName, name, player, name),
        ("%s bewahrte den\nPreis auf:\n%s!\f%s erhält das\nItem!"):format(
          trainerName, name, player))
    end
    if kind == "full" then
      return i18n.text(
        ("Loot from %s:\n%s!\fBut the BAG is\nfull.\fThe trainer keeps\nit for you."):format(
          trainerName, name),
        ("Beute von %s:\n%s!\fDoch der BEUTEL\nist voll.\fDer TRAINER bewahrt\nsie für dich auf."):format(
          trainerName, name))
    end
    return i18n.text(
      ("Loot from %s:\n%s!\f%s put it in\nthe BAG."):format(
        trainerName, name, player),
      ("Beute von %s:\n%s!\f%s legt das Item\nin den BEUTEL."):format(
        trainerName, name, player))
  end

  local function awardRematchLoot(game, battle, state, deps)
    local mode = mod.options:get("loot_mode") or "balanced"
    if mode == "off" or state.pendingLoot then return nil end
    local roll = lootRoll(deps)
    local averageLevel = loot.averageLevel(battle.enemyParty)
    local itemId = loot.select(roll, mode, {
      averageLevel = averageLevel,
      masterUnlocked = masterBallUnlocked(),
      expAllAvailable = expAllAvailable(game),
    })
    if not itemId or not (game.data.items and game.data.items[itemId]) then
      return nil
    end
    game.save.inventory = game.save.inventory or {}
    local Bag = require("src.inventory.Bag")
    local trainerName = battle.trainer and battle.trainer.name or "TRAINER"
    if Bag.add(game.save, itemId, 1, game.data) then
      markUniqueLoot(game, itemId)
      return lootMessage(game, trainerName, itemId, "received")
    end
    state.pendingLoot = { item = itemId, trainer = trainerName }
    return lootMessage(game, trainerName, itemId, "full")
  end

  local function deliverPendingLoot(game, state)
    local pending = state and state.pendingLoot
    if not (pending and pending.item) then return nil, false end
    game.save.inventory = game.save.inventory or {}
    local trainerName = pending.trainer or "TRAINER"
    if require("src.inventory.Bag").add(
        game.save, pending.item, 1, game.data) then
      local itemId = pending.item
      state.pendingLoot = nil
      markUniqueLoot(game, itemId)
      return lootMessage(game, trainerName, itemId, "pending"), true
    end
    return lootMessage(game, trainerName, pending.item, "full"), false
  end

  mod.exports.remainingSteps = remainingSteps
  mod.exports.trainingCycles = trainingCycles
  mod.exports.trainerKey = trainerKey
  mod.exports.trainerStates = trainerStates

  local function offerRematch(self, npc, game, deps)
    local d = npc.def
    local TextBox = deps.textBox or require("src.render.TextBox")
    local Runtime = deps.runtime or require("src.mods.Runtime")
    local BattleState = deps.battleState or require("src.battle.BattleState")
    npc.frozen = true
    npc:facePlayer(self.player)
    local unfreeze = function() npc.frozen = false end

    local function decline()
      -- the class reacts to the NO: mocking, or understanding for the
      -- wise classes.  The trainer's vanilla post-battle line follows as
      -- a second page, so the base-game text is never lost.
      local header = game.data:trainerHeader(self.map.def.label, d.index)
      local after = header and header.after and game.data.text[header.after]
      local line = localizedDecline(d.trainerClass)
      if after then line = line .. "\f" .. after end
      game.stack:push(TextBox.new(game, line, unfreeze))
    end

    local function accept()
      -- a mod may ship a dedicated rematch team for the class: the
      -- trainer record's rematchIndex points at it (Yellow Legacy Changes
      -- appends the hack's L64-77 rematch teams this way).  Fall back to
      -- the trainer's own party when none is marked.
      local record = game.data.trainers and game.data.trainers[d.trainerClass]
      local marked = record and record.rematchIndex
      local partyIndex = marked and record.parties and record.parties[marked]
          and marked or d.trainerParty
      local team = record and record.parties and record.parties[partyIndex]
      local key = trainerKey(self, npc)
      local state = stateFor(key, true)
      -- 5.0's Research Atlas remembers only trainers the player has already
      -- met.  These presentation fields do not affect the stable trainer key
      -- or any old save's cooldown data.
      state.mapId = self.map and self.map.id or state.mapId
      state.trainerClass = d.trainerClass or state.trainerClass
      settleTraining(state, deps)
      local progress = state.rematches + state.trainingCycles
      local boost = nextLevelBoost(progress, levelGain())
      local rank = ascendant and ascendant.rematchRank(progress)
      local rematchTeam = recruitment.expand(game.data, team, d.trainerClass,
        key, progress, boost, mod.options:get("team_growth") ~= false)
      local previewTeam = boostedTeam(rematchTeam, boost)

      local function battle()
        Runtime.emit("world.trainer_engaged", { npc = npc,
          trainerClass = d.trainerClass, partyIndex = partyIndex })
        local header = game.data:trainerHeader(self.map.def.label, d.index)
        local wonText = header and header.won and game.data.text[header.won]
        local b = BattleState.newTrainer(game, d.trainerClass, partyIndex)
        state.trainerName = b.trainer and b.trainer.name
          or state.trainerName or d.name
        state.lastTeamSize = #(b.enemyParty or {})
        b.rematch = true
        b.rematchTrainerKey = key
        b.rematchTrainerClass = d.trainerClass
        b.rematchRank = rank and rank.key
        if ascendant then ascendant.applyRematchRank(b, rank) end
        b.rematchNumber = (state.rematches or 0) + 1
        b.rematchTrainingCycles = state.trainingCycles
        b.rematchRecruits = appendRecruits(game, b, rematchTeam)
        b.rematchRecruitSpecies = {}
        for i = math.max(1, #rematchTeam - b.rematchRecruits + 1),
            #rematchTeam do
          if rematchTeam[i] and rematchTeam[i].recruited then
            b.rematchRecruitSpecies[#b.rematchRecruitSpecies + 1] =
              rematchTeam[i].species
          end
        end
        strengthenBattle(game, b, boost)
        b.endBattleText = wonText and TextBox.substitute(game, wonText) or nil
        b.onFinish = function(result)
          -- A completed battle sends this trainer back to training whether
          -- the player won or blacked out.  The next meeting gets the next
          -- strength tier only after that rest has elapsed.
          state.rematches = math.max(0, math.floor(state.rematches or 0)) + 1
          scheduleRest(key, deps)
          local rewards = {}
          local function addReward(text)
            if text then rewards[#rewards + 1] = text end
          end
          if result == "win" then
            addReward(fieldTech and fieldTech.afterRematch(game, b))
            addReward(awardRematchLoot(game, b, state, deps))
            addReward(johtoResearch.afterRematch(game, b))
            addReward(shinySystem and shinySystem.afterRematch(game, b))
          end
          local reward = #rewards > 0 and table.concat(rewards, "\f") or nil
          self:afterBattle(result, b)
          if reward then
            game.stack:push(TextBox.new(game, reward, unfreeze))
          else
            unfreeze()
          end
        end
        self:pushBattle(b)
      end

      -- when the rematch team averages more than 10 levels above the
      -- player's party, the class warns in its own voice and asks again
      local gap = levelGap(game.save.party, previewTeam)
      if gap and gap > 10 then
        game.stack:push(TextBox.new(game, localizedWarning(d.trainerClass), nil, {
          choice = function(yes)
            if yes then battle() else decline() end
          end,
        }))
      else
        battle()
      end
    end

    local rankState = stateFor(trainerKey(self, npc), true)
    settleTraining(rankState, deps)
    local opening = localizedLine(d.trainerClass)
    if ascendant then
      local shownRank = ascendant.rematchRank(
        rankState.rematches + rankState.trainingCycles)
      if shownRank and shownRank.threshold > 0 then
        opening = ascendant.rankLine(
          rankState.rematches + rankState.trainingCycles) .. "\f" .. opening
      end
    end
    game.stack:push(TextBox.new(game, opening, nil, {
      choice = function(yes)
        if yes then accept() else decline() end
      end,
    }))
  end

  -- deps injectable so the headless test can drive the wraps without the
  -- engine; in-game every one resolves to the real module
  local function install(game, deps)
    deps = deps or {}
    local Overworld = deps.overworld or require("src.world.OverworldController")
    local BattleState = deps.battleState or require("src.battle.BattleState")
    local TextBox = deps.textBox or require("src.render.TextBox")
    local Runtime = deps.runtime or require("src.mods.Runtime")
    local mapScripts = deps.mapScripts or require("data.scripts.init")

    -- Run only after every enabled mod has merged its audio registry. Existing
    -- Gen-II cries therefore always win; Ascendant supplies only missing
    -- Johto entries and Mega/Ascendant forms naturally retain their species
    -- cry.
    if johtoAudio then johtoAudio.install(game) end
    if megaEvolution then megaEvolution.install(game, deps) end
    if kantoCompletion then kantoCompletion.install(game, deps) end
    if fieldTech then fieldTech.install(game, deps) end
    if frontierExchange then frontierExchange.install(game, deps) end
    if daycare then daycare.install(game, deps) end
    if shinySystem then shinySystem.install(game, deps) end
    if crystalAnimation then crystalAnimation.install(game, deps) end
    if ascendant then ascendant.install(game, deps) end
    if eventArchive then eventArchive.install(game, deps) end
    if johtoResearch then johtoResearch.install(game, deps) end
    if worldEvents then worldEvents.install(game, deps) end
    if johtoMasters then johtoMasters.install(game, deps) end
    if dexProgress then dexProgress.install(game, deps) end
    if ascendantTyphlosion then ascendantTyphlosion.install(game, deps) end
    if starterRelicQuests then starterRelicQuests.install(game, deps) end
    if researchAtlas then researchAtlas.install(game, deps) end
    if grandTour then grandTour.install(game, deps) end
    if questTracker then questTracker.install(game, deps) end
    if onboarding then onboarding.install(game, deps) end
    if legacyHall then legacyHall.install(game, deps) end
    if followerCompat then followerCompat.install(game) end

    -- one wrap per boot; hot reload re-runs entry chunks without clearing
    -- the require cache, so the module table is the idempotence sentinel
    if Overworld._rematchTalkWrapped then return end
    Overworld._rematchTalkWrapped = true

    local vanillaTalkTo = Overworld.talkTo
    Overworld.talkTo = function(self, npc)
      local d = npc.def
      if daycare and daycare.handleTalk(self, npc, game) then return end
      if starterRelicQuests
          and starterRelicQuests.handleTalk(self, npc, game) then return end
      -- Hall-of-Fame gym leaders are scripted in the base game, so the
      -- post-game controller gets first refusal before the generic/scripted
      -- split below.
      if johtoResearch and johtoResearch.handleTalk(self, npc, game) then return end
      if ascendant and ascendant.handleTalk(self, npc, game) then return end
      if postgame and postgame.handleTalk(self, npc, game) then return end
      -- only the generic-trainer branch: scripted encounters (gym leaders,
      -- rivals, story fights) keep their own flow, defeated or not
      local scripted = mapScripts and mapScripts.talkScript(self.map.id, d.text)
      if not scripted and d.trainerClass and self:trainerDefeated(npc) then
        local key = trainerKey(self, npc)
        -- A defeated trainer without a mod record can occur when an older
        -- save is adopted after boot or when another mod sets the victory
        -- flag directly. Seed the missing record here as a final safety net
        -- so such trainers never jump straight to an immediate rematch.
        if not stateFor(key, false) then scheduleRest(key, deps) end
        local trainerState = stateFor(key, true)
        trainerState.mapId = self.map and self.map.id or trainerState.mapId
        trainerState.trainerClass = d.trainerClass
          or trainerState.trainerClass
        trainerState.trainerName = trainerState.trainerName or d.name
        if trainerState.pendingLoot then
          npc.frozen = true
          npc:facePlayer(self.player)
          local text = deliverPendingLoot(game, trainerState)
          game.stack:push(TextBox.new(game, text, function()
            npc.frozen = false
          end))
          return
        end
        local left = remainingSteps(key)
        if left > 0 then
          npc.frozen = true
          npc:facePlayer(self.player)
          local header = game.data:trainerHeader(self.map.def.label, d.index)
          local after = header and header.after and game.data.text[header.after]
          local status = localizedRestLine(left)
          if after then status = status .. "\f" .. after end
          game.stack:push(TextBox.new(game, status, function()
            npc.frozen = false
          end))
          return
        end
        return offerRematch(self, npc, game, deps)
      end
      return vanillaTalkTo(self, npc)
    end

    -- The first rematch must not be available one dialogue box after the
    -- original victory.  Wrap the normal trainer flow and start this
    -- trainer's first rest only after the base game has recorded the win.
    local vanillaEngageTrainer = Overworld.engageTrainer
    if vanillaEngageTrainer then
      Overworld.engageTrainer = function(self, npc, onDone)
        local defeatedBefore = self:trainerDefeated(npc)
        local function done(...)
          if not defeatedBefore and self:trainerDefeated(npc) then
            scheduleRest(trainerKey(self, npc), deps)
          end
          if onDone then return onDone(...) end
        end
        return vanillaEngageTrainer(self, npc, done)
      end
    end

    -- A save that already contains beaten trainers cannot tell us when
    -- those old victories happened.  Seed one rest period on first install
    -- so enabling the mod mid-playthrough follows the same rule.
    seedDefeatedTrainers(game.save, deps)

    -- no money from a rematch: zero the class base money for this battle
    -- only (never touch the shared data record) and drop the prize line
    local vanillaFainted = BattleState.enemyMonFainted
    BattleState.enemyMonFainted = function(self, ...)
      if not self.rematch then return vanillaFainted(self, ...) end
      local realTrainer = self.trainer
      self.trainer = setmetatable({ baseMoney = 0 }, { __index = realTrainer })
      local realSayNext = self.sayNext
      self.sayNext = function(s, text)
        if isPrizeLine(text) then return end
        return realSayNext(s, text)
      end
      local ok, err = pcall(vanillaFainted, self, ...)
      self.trainer = realTrainer
      self.sayNext = realSayNext
      if not ok then error(err, 2) end
    end

    -- Pay Day is a reward too: nothing to collect on a rematch
    local vanillaFinish = BattleState.finish
    BattleState.finish = function(self)
      if self.rematch then self.payDay = nil end
      return vanillaFinish(self)
    end
  end
  mod.exports.install = install

  mod.events:on("world.stepped", function()
    local realClock = playerStepClock() + 1
    local gain = 1 + (worldEvents and worldEvents.trainingStepBonus
      and worldEvents.trainingStepBonus() or 0)
    local trainerClock = stepClock() + gain
    mod.save:set("step_clock", realClock)
    mod.save:set("trainer_step_clock", trainerClock)
    settleAllTraining()
    if ascendant then ascendant.refreshRankMarkers() end
    if worldEvents then worldEvents.onStep(nil, realClock) end
  end)

  -- game.ready runs before CONTINUE adopts the selected slot.  Seed old
  -- victories again after that slot becomes the live mod.save backing.
  mod.events:on("save.loaded", function(ev)
    if mod.save:get("trainer_step_clock") == nil then
      mod.save:set("trainer_step_clock", playerStepClock())
    end
    seedDefeatedTrainers(ev.save)
    migrateRestTimers()
  end)

  mod.events:on("game.ready", function(ev)
    install(ev.game)
  end)
end
