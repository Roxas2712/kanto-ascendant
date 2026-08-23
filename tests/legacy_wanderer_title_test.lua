local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR is required")
local modRoot = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  assert(value, "FAIL: " .. message)
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end
local function contains(text, fragment, message)
  check(type(text) == "string" and text:find(fragment, 1, true) ~= nil,
    message .. " (text: " .. tostring(text) .. ")")
end
local function excludes(text, fragment, message)
  check(type(text) == "string" and text:find(fragment, 1, true) == nil,
    message .. " (text: " .. tostring(text) .. ")")
end

local language = "en"
local i18n = {
  text = function(en, de) return language == "de" and de or en end,
}
local hooks, events, saveBucket = {}, {}, {}
local mod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key) return saveBucket[key] end,
    set = function(_, key, value) saveBucket[key] = value end,
  },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn) events[name] = fn end },
  world = {
    spawnNpc = function() return nil end,
    removeNpc = function() return true end,
    npc = function() return nil end,
  },
}
local legacyState = {
  cycle = 2, pact = "legacy", wanderersEnabled = true,
}
local legacyProfile = { completedPaths = {}, legacyPass = false }
local journey = {
  wanderersEnabled = function() return true end,
  state = function() return legacyState end,
  profile = function() return legacyProfile end,
}
local selectedId, selectedName
local titles = {
  currentTitle = function() return selectedId, selectedName or "CHAMPION" end,
}

local makeWanderers = assert(loadfile(modRoot .. "/legacy_wanderers.lua"))()
local wanderers = makeWanderers(mod, {
  journey = journey, i18n = i18n, titles = titles,
})
local game = {
  save = { party = { { species = "PIKACHU", level = 30 } } },
  data = {
    pokemon = {
      PIKACHU = { name = "Pikachu" },
      CHARMANDER = { name = "Charmander" },
    },
    trainers = {
      OPP_COOLTRAINER_M = {}, OPP_COOLTRAINER_F = {},
      OPP_JR_TRAINER_M = {}, OPP_JR_TRAINER_F = {},
      OPP_SCIENTIST = {}, OPP_POKEMANIAC = {}, OPP_SUPER_NERD = {},
    },
  },
}
local function active(class, variant, team)
  return {
    game = game,
    archetype = { class = class, legacyVariant = variant },
    team = team or {},
  }
end
local scientist = active("OPP_SCIENTIST")
local ace = active("OPP_COOLTRAINER_M")
local keeper = active("OPP_POKEMANIAC")

-- No selected title is intentionally neutral, including the CHAMPION display
-- fallback returned by Legacy Hall.
eq(wanderers.reactionContext(scientist).kind, "fallback",
  "no selected title preserves the neutral challenger reaction")
contains(wanderers.challengeText(scientist), "sought a trainer",
  "English no-title fallback is authored rather than generic title praise")
language = "de"
contains(wanderers.challengeText(scientist), "Profi wie dich",
  "German no-title fallback is localized")
language = "en"

selectedId, selectedName = "factory_architect", "FACTORY ARCHITECT"
eq(wanderers.reactionContext(scientist).kind, "title_factory",
  "a scientist recognizes the selected Factory Architect title")
eq(wanderers.reactionContext(ace).kind, "fallback",
  "Factory Architect does not overwrite an unrelated wanderer class")
contains(wanderers.challengeText(scientist), "rental team",
  "Factory Architect receives a scientist-specific challenge")

selectedId, selectedName = "legacy_path_red", "KANTO CHALLENGER"
eq(wanderers.reactionContext(ace).kind, "title_red",
  "an ace recognizes the selected Red-path title")
eq(wanderers.reactionContext(scientist).kind, "fallback",
  "the Red-path title is not sprayed across unrelated classes")
selectedId, selectedName = "legacy_path_blue", "OAK'S HEIR"
eq(wanderers.reactionContext(scientist).kind, "title_blue",
  "a scientist recognizes the selected Blue-path title")
selectedId, selectedName = "legacy_path_green", "WILD KEEPER"
eq(wanderers.reactionContext(keeper).kind, "title_green",
  "a Pokemaniac recognizes the selected Green-path title")
selectedId, selectedName = "legacy_pass", "LEGACY KEEPER"
eq(wanderers.reactionContext(ace).kind, "title_pass",
  "the completed Legacy Pass receives its veteran reaction")

selectedId, selectedName = "unknown_future_title", "FUTURE"
eq(wanderers.reactionContext(scientist).kind, "fallback",
  "unknown titles safely retain the fallback")
check(wanderers.setTitleProvider({
  currentTitle = function() error("broken provider") end,
}), "a replacement title provider can be late-bound")
eq(wanderers.reactionContext(scientist).kind, "fallback",
  "a failing title provider cannot break field dialogue")
check(wanderers.setTitleProvider(titles),
  "the real title provider can be rebound after a defensive fallback")
selectedId, selectedName = nil, nil

legacyState.partnerChosen = true
legacyState.partnerSpecies = "PIKACHU"
local partnerMatch = active("OPP_SUPER_NERD", nil, {
  { species = "CHARMANDER", level = 30 },
})
local context = wanderers.reactionContext(partnerMatch)
eq(context.kind, "partner_match",
  "a committed partner is recognized in the wanderer's real roster")
eq(context.partnerName, "Pikachu",
  "the partner reaction uses the registered species name")
eq(context.trainerPartnerName, "Charmander",
  "the partner reaction uses the Wandertrainer's lead species name")
contains(wanderers.challengeText(partnerMatch), "PIKACHU",
  "the English partner reaction names the player's partner")
contains(wanderers.challengeText(partnerMatch), "CHARMANDER",
  "the English partner reaction names the Wandertrainer's partner")
language = "de"
contains(wanderers.challengeText(partnerMatch), "PIKACHU",
  "the German partner reaction names the player's partner")
contains(wanderers.challengeText(partnerMatch), "CHARMANDER",
  "the German partner reaction names the Wandertrainer's partner")
language = "en"
game.save.party = {}
eq(wanderers.reactionContext(partnerMatch).kind, "fallback",
  "a chosen partner outside the current party cannot trigger the team line")
game.save.party = { { species = "PIKACHU", level = 30 } }
legacyState.partnerChosen = false
eq(wanderers.reactionContext(partnerMatch).kind, "fallback",
  "an uncommitted selector species cannot leak into dialogue")
legacyState.partnerChosen, legacyState.partnerSpecies = nil, nil

legacyState.avatar, legacyState.pathComplete = "RED", false
local redPast = active("OPP_COOLTRAINER_M", "red_challenge")
eq(wanderers.reactionContext(redPast).kind, "path_red_past",
  "a completed Red-path challenger gets its authored reaction")
contains(wanderers.challengeText(redPast), "another life",
  "inherited Red completion is described as another life")
legacyState.pathComplete = true
eq(wanderers.reactionContext(redPast).kind, "path_red_current",
  "current-life Red completion receives direct recognition")
contains(wanderers.challengeText(redPast), "overcame",
  "current-life Red completion is acknowledged directly")
excludes(wanderers.challengeText(redPast), "another life",
  "current-life Red completion is not attributed to another life")
language = "de"
contains(wanderers.challengeText(redPast), "Prüfung bestanden",
  "German current-life Red completion is acknowledged directly")
excludes(wanderers.challengeText(redPast), "anderen",
  "German current-life Red completion is not attributed to another life")
language = "en"
legacyState.avatar = "BLUE"
local blueCurrent = active("OPP_SCIENTIST", "oak_researcher")
eq(wanderers.reactionContext(blueCurrent).kind, "path_blue_current",
  "current-life Blue completion receives direct recognition")
contains(wanderers.challengeText(blueCurrent), "mastered",
  "current-life Blue dialogue uses strategy authority")
legacyState.avatar = "GREEN"
local greenCurrent = active("OPP_POKEMANIAC", "wild_keeper")
eq(wanderers.reactionContext(greenCurrent).kind, "path_green_current",
  "current-life Green completion receives direct recognition")
contains(wanderers.challengeText(greenCurrent), "bond opened",
  "current-life Green dialogue uses bond authority")
legacyState.avatar, legacyState.pathComplete = "RED", false
eq(wanderers.reactionContext(active("OPP_SCIENTIST",
  "oak_researcher")).kind, "path_blue_past",
  "a completed Blue-path researcher gets its authored reaction")
eq(wanderers.reactionContext(active("OPP_POKEMANIAC",
  "wild_keeper")).kind, "path_green_past",
  "a completed Green-path keeper gets its authored reaction")
eq(wanderers.reactionContext(active("OPP_COOLTRAINER_F",
  "legacy_keeper")).kind, "path_complete_past",
  "a three-path veteran gets its authored reaction")

eq(#wanderers.availableArchetypes(game), #wanderers.ARCHETYPES,
  "an unfinished profile keeps only the ordinary wanderer pool")
legacyProfile.completedPaths = { red = true, blue = true, green = true }
legacyProfile.legacyPass = true
local available = wanderers.availableArchetypes(game)
eq(#available, #wanderers.ARCHETYPES + 4,
  "each completed path contributes one focused challenger variant")
local variants = {}
for _, row in ipairs(available) do
  if row.legacyVariant then variants[row.legacyVariant] = row.class end
end
eq(variants.red_challenge, "OPP_COOLTRAINER_M",
  "Red completion adds only the ace challenger")
eq(variants.oak_researcher, "OPP_SCIENTIST",
  "Blue completion adds only Oak's researcher")
eq(variants.wild_keeper, "OPP_POKEMANIAC",
  "Green completion adds only the wild keeper")
eq(variants.legacy_keeper, "OPP_COOLTRAINER_F",
  "Legacy Pass adds only the veteran challenger")

-- Every authored page must fit the stock two-line, 18-glyph dialog row in
-- both languages. Count UTF-8 glyphs so HÜTERIN and Kämpfe are measured as
-- the renderer measures them, not as raw bytes.
local contexts = {
  { id = "factory_architect", name = "FACTORY ARCHITECT", active = scientist },
  { id = "legacy_path_red", name = "KANTO CHALLENGER", active = ace },
  { id = "legacy_path_blue", name = "OAK'S HEIR", active = scientist },
  { id = "legacy_path_green", name = "WILD KEEPER", active = keeper },
  { id = "legacy_pass", name = "LEGACY KEEPER", active = ace },
  { active = partnerMatch, partner = true },
  { active = active("OPP_COOLTRAINER_M", "red_challenge") },
  { active = active("OPP_SCIENTIST", "oak_researcher") },
  { active = active("OPP_POKEMANIAC", "wild_keeper") },
  { active = active("OPP_COOLTRAINER_F", "legacy_keeper") },
  { active = scientist },
}
local function glyphCount(text)
  local count = 0
  for _ in tostring(text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    count = count + 1
  end
  return count
end
for _, lang in ipairs({ "en", "de" }) do
  language = lang
  for index, row in ipairs(contexts) do
    selectedId, selectedName = row.id, row.name
    legacyState.partnerChosen = row.partner == true
    legacyState.partnerSpecies = row.partner and "PIKACHU" or nil
    local text = wanderers.challengeText(row.active)
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
      for pageLine in (line .. "\f"):gmatch("([^\f]*)\f") do
        check(glyphCount(pageLine) <= 18,
          lang .. " reaction " .. index .. " line fits 18 glyphs: " .. pageLine)
      end
    end
  end
end

print(("legacy wanderer titles: %d assertions"):format(assertions))
