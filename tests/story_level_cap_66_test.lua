package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local checks = 0
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function ok(value, message)
  checks = checks + 1
  assert(value, message)
end

local function clone(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = clone(child) end
  return out
end

local bucket, writes = {}, 0
local hooks, listeners = {}, {}
local values = { difficulty = "standard" }
local mod = {
  id = "kanto_ascendant",
  options = { get = function(_, key) return values[key] end },
  save = {
    get = function(_, key, default)
      local value = bucket[key]
      return value == nil and default or value
    end,
    set = function(_, key, value)
      writes = writes + 1
      bucket[key] = value
    end,
  },
  hooks = { wrap = function(_, name, fn, priority)
    hooks[name] = { fn = fn, priority = priority }
  end },
  events = { on = function(_, name, fn, priority)
    listeners[name] = listeners[name] or {}
    listeners[name][#listeners[name] + 1] = { fn = fn, priority = priority }
  end },
}

local edition = "red"
local storyPlans, rivalResolves, lastRivalParty = 0, 0, nil
local lastRivalIdentity, lastRivalIsYellow = nil, nil
local selectedRivalIdentity, rivalIdentityEnabled = "GREEN", true
local storyGym = {
  plan = function(version, tier, class, party)
    storyPlans = storyPlans + 1
    local out = clone(party)
    -- Prove that the cap reads the live authored difficulty plan rather than
    -- a second embedded ace table.
    if tier == "hard" and class == "OPP_MISTY" then
      table.insert(out, #out, { species = "PSYDUCK", level = 19 })
    end
    return out, { authority = version .. ":" .. tier .. ":" .. class }
  end,
}
local difficulty = {
  adjustParty = function(party, badges)
    local bonus = values.difficulty == "hard" and (badges >= 1 and 2 or 1) or 0
    local out = clone(party)
    for _, row in ipairs(out) do row.level = math.min(100, row.level + bonus) end
    return out
  end,
}
local rivalTeams = {
  resolve = function(identity, class, partyIndex, original, isYellow)
    rivalResolves = rivalResolves + 1
    lastRivalParty = partyIndex
    lastRivalIdentity = identity
    lastRivalIsYellow = isYellow
    local out = clone(original)
    if identity == "GREEN" and class == "OPP_RIVAL3" then
      out[#out] = { species = "VENUSAUR", level = 67 }
    end
    return out
  end,
}
local adaptiveSelection, adaptivePlans = "off", 0
local adaptive = {
  currentSelection = function() return adaptiveSelection end,
  planAdjusted = function(party, playerParty, context)
    adaptivePlans = adaptivePlans + 1
    local out = clone(party)
    if context.selection == "2" then
      for _, row in ipairs(out) do
        row.level = math.min(context.maxLevel or 100, row.level + 3)
      end
    end
    return out, { mode = context.selection == "2" and "adaptive" or "classic" }
  end,
}
local postgameState = { masterWins = {} }
local postgame = { state = function() return postgameState end }
local postgameData = { gyms = {
  { key = "brock", name = "BROCK", class = "OPP_BROCK",
    master = { { species = "GOLEM", level = 76 },
      { species = "AERODACTYL", level = 78 } } },
  { key = "misty", name = "MISTY", class = "OPP_MISTY",
    master = { { species = "STARMIE", level = 79 },
      { species = "GYARADOS", level = 80 } } },
} }

local trainers = {
  OPP_BROCK = { parties = { {
    { species = "GEODUDE", level = 12 }, { species = "ONIX", level = 14 },
  } } },
  OPP_MISTY = { parties = { {
    { species = "STARYU", level = 18 }, { species = "STARMIE", level = 21 },
  } } },
  OPP_LT_SURGE = { parties = { {
    { species = "VOLTORB", level = 21 }, { species = "RAICHU", level = 24 },
  } } },
  OPP_ERIKA = { parties = { {
    { species = "TANGELA", level = 24 }, { species = "VILEPLUME", level = 29 },
  } } },
  OPP_KOGA = { parties = { {
    { species = "KOFFING", level = 37 }, { species = "WEEZING", level = 43 },
  } } },
  OPP_SABRINA = { parties = { {
    { species = "KADABRA", level = 38 }, { species = "ALAKAZAM", level = 43 },
  } } },
  OPP_BLAINE = { parties = { {
    { species = "PONYTA", level = 40 }, { species = "ARCANINE", level = 47 },
  } } },
  OPP_GIOVANNI = { parties = { {}, {}, {
    { species = "RHYHORN", level = 45 }, { species = "RHYDON", level = 50 },
  } } },
  OPP_LORELEI = { parties = { { { species = "LAPRAS", level = 56 } } } },
  OPP_BRUNO = { parties = { { { species = "MACHAMP", level = 58 } } } },
  OPP_AGATHA = { parties = { { { species = "GENGAR", level = 60 } } } },
  OPP_LANCE = { parties = { { { species = "DRAGONITE", level = 62 } } } },
  OPP_RIVAL3 = { parties = {
    { { species = "BLASTOISE", level = 65 } },
    { { species = "VENUSAUR", level = 65 } },
    { { species = "CHARIZARD", level = 65 } },
  } },
}

local function newGame()
  return {
    data = { trainers = trainers, field = { starterCounterpicks = {
      EVENT_CHOSE_SQUIRTLE = 1, EVENT_CHOSE_BULBASAUR = 2,
    } } },
    save = {
      version = edition, inventory = {}, flags = {}, hallOfFame = {},
      party = {}, player = { name = "RED", rival = "GARY" },
    },
  }
end

local controller = assert(loadfile(root .. "/story_level_cap.lua"))()(mod, {
  gameVersion = { get = function() return edition end },
  storyGym = storyGym,
  difficulty = difficulty,
  adaptiveTrainerLevels = adaptive,
  rivalTeams = rivalTeams,
  rivalIdentity = function()
    return rivalIdentityEnabled and selectedRivalIdentity or "BLUE"
  end,
  postgame = postgame,
  postgameData = postgameData,
})

local function emit(name, payload)
  for _, row in ipairs(listeners[name] or {}) do row.fn(payload) end
end

local game = newGame()
emit("game.ready", { game = game })
eq(controller.STATE_KEY, "story_level_cap", "stable state key")
eq(controller.SCHEMA_VERSION, 1, "initial schema version")
eq(controller.mode(), "off", "missing state defaults OFF")
eq(controller.effective(game), nil, "missing state installs no cap")
eq(writes, 0, "reading an old save does not migrate it")
ok(hooks["pokemon.level_cap"], "public engine level-cap hook registered")
eq(hooks["pokemon.level_cap"].fn(function() return nil end,
  { mon = { level = 5 }, source = "battle" }), nil,
  "OFF is an exact hook pass-through")
eq(writes, 0, "OFF hook does not create state")
ok(controller.setMode("story", game), "STORY can be enabled outside battle")

local fresh = controller.currentStage(game)
eq(fresh.id, "gym:brock", "fresh story starts at Brock")
eq(fresh.level, 14, "Brock cap comes from the live team")
game.save.inventory.BOULDERBADGE = 1
local misty = controller.currentStage(game)
eq(misty.id, "gym:misty", "Brock receipt advances by stable stage id")
eq(misty.level, 21, "Standard Misty is exactly level 21")
eq(controller.summary(game), "CAP: MISTY · LV21", "clear bilingual-safe cap summary")
ok(storyPlans >= 2, "story Gym planner is the roster authority")

adaptiveSelection = "2"
game.save.party = { { species = "PIKACHU", level = 25 } }
eq(controller.currentStage(game).level, 21,
  "adaptive story composition cannot raise the progression cap")
eq(adaptivePlans, 0, "STORY never consults player-based adaptive planning")

-- Once a battle starts, the actual constructed mandatory team is the final
-- authority.  It stays frozen while experience changes the player's party.
emit("battle.started", { battle = {
  kind = "trainer", game = game, oppClass = "OPP_MISTY", partyIndex = 1,
  enemyParty = { { species = "STARMIE", level = 25 } },
} })
eq(hooks["pokemon.level_cap"].fn(function() return nil end,
  { mon = game.save.party[1], source = "battle" }), 21,
  "active mandatory battle freezes its progression cap")
game.save.party[1].level = 40
eq(hooks["pokemon.level_cap"].fn(function() return nil end,
  { mon = game.save.party[1], source = "exp_share" }), 21,
  "battle-time cap cannot drift with player level changes")
emit("battle.ended", {})
adaptiveSelection = "off"
game.save.party = {}

values.difficulty = "hard"
eq(controller.currentStage(game).level, 23,
  "Difficulty-adjusted Misty cap follows the actual planned team")
edition = "yellow"
game.save.version = "yellow"
eq(controller.currentStage(game).level, 23,
  "Yellow reads its live edition team through the same authority")
edition = "blue"
game.save.version = "blue"
eq(controller.currentStage(game).level, 23,
  "Blue shares the authoritative Red-family story roster")
edition = "red"
game.save.version = "red"
values.difficulty = "standard"

-- An unbeaten leader only becomes relevant once the same durable story
-- receipts that unlock the map route exist in the save.
game.save.inventory.CASCADEBADGE = 1
eq(controller.currentStage(game), nil,
  "Surge and Erika are not open before the S.S. Anne Cut receipt")
game.save.flags.EVENT_GOT_HM01 = true
eq(controller.currentStage(game).id, "gym:surge",
  "Cut receipt opens the first undefeated Cut-gated Gym")

-- Nonlinear saves are keyed by each actual receipt: beating Sabrina early
-- must not make a badge count jump over Koga, and a missing lower receipt
-- remains the next relevant leader.
for _, badge in ipairs({ "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE" }) do
  game.save.inventory[badge] = 1
end
game.save.inventory.MARSHBADGE = 1
game.save.flags.EVENT_BEAT_SILPH_CO_GIOVANNI = true
game.save.inventory.BICYCLE = nil
game.save.flags.EVENT_GOT_BICYCLE = nil
game.save.inventory.POKE_FLUTE = nil
game.save.flags.EVENT_GOT_POKE_FLUTE = nil
eq(controller.currentStage(game), nil,
  "Koga is not open before either route into Fuchsia is cleared")
game.save.flags.EVENT_GOT_POKE_FLUTE = true
eq(controller.currentStage(game).id, "gym:koga",
  "nonlinear Sabrina win does not skip undefeated Koga")
game.save.inventory.SOULBADGE = 1
eq(controller.currentStage(game), nil,
  "Blaine is not open before the actual Secret Key receipt")
game.save.inventory.SECRET_KEY = 1
eq(controller.currentStage(game).id, "gym:blaine",
  "Surf authority plus Secret Key opens Blaine")

game.save.inventory.VOLCANOBADGE = 1
eq(controller.currentStage(game).id, "gym:giovanni",
  "Giovanni opens only after the exact seven other Badge receipts")
game.save.inventory.EARTHBADGE = 1
local lorelei = controller.currentStage(game)
eq(lorelei.id, "league:lorelei", "eight badges advance to the live League run")
eq(lorelei.level, 56, "League cap uses the actual trainer table")
game.save.flags.EVENT_BEAT_LORELEIS_ROOM_TRAINER_0 = true
game.save.flags.EVENT_BEAT_BRUNOS_ROOM_TRAINER_0 = true
game.save.flags.EVENT_BEAT_AGATHAS_ROOM_TRAINER_0 = true
game.save.flags.EVENT_BEAT_LANCE = true
game.save.flags.EVENT_CHOSE_SQUIRTLE = true
local champion = controller.currentStage(game)
eq(champion.id, "league:champion", "League sequence ends at Champion/Gary")
eq(champion.level, 67, "Champion cap follows stable rival identity resolution")
ok(rivalResolves > 0, "rival_teams.resolve is consulted for the real Champion")
eq(lastRivalParty, 2, "Red Champion party follows the starter counterpick")
eq(lastRivalIdentity, "GREEN", "enabled character selection reaches the cap")
eq(lastRivalIsYellow, false, "Red resolver receives a non-Yellow receipt")

rivalIdentityEnabled = false
eq(controller.currentStage(game).level, 65,
  "disabled character selection predicts the real vanilla Champion team")
eq(lastRivalIdentity, "BLUE",
  "disabled stale rival choice resolves through the vanilla identity")
rivalIdentityEnabled = true

edition = "yellow"
game.save.version = "yellow"
game.save.rivalStarter = 3
eq(controller.currentStage(game).party, 3,
  "Yellow Champion party follows the durable rivalStarter value")
eq(lastRivalParty, 3, "Yellow resolver receives the actual Champion party")
eq(lastRivalIsYellow, true, "Yellow resolver receives the edition receipt")
edition = "red"
game.save.version = "red"

game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
game.save.hallOfFame = { {} }
postgameState.masterWins = { brock = true }
local master = controller.currentStage(game)
eq(master.id, "master:misty", "Master Circuit uses individual leader wins")
eq(master.level, 80, "Master cap comes from postgame_data master team")
values.difficulty = "hard"
adaptiveSelection = "2"
eq(controller.currentStage(game).level, 80,
  "dedicated Master teams ignore ordinary story Difficulty/Adaptive hooks")
values.difficulty = "standard"
adaptiveSelection = "off"

-- CUSTOM persists by stable id, not by whichever array position happens to
-- be current. Current and upcoming can be edited independently.
ok(controller.setMode("custom", game), "CUSTOM can be enabled outside battle")
eq(controller.mode(), "custom", "CUSTOM mode persisted")
eq(controller.upcomingStage(game), nil, "last unfinished Master has no upcoming stage")
ok(controller.setOverride("master:misty", 77, game), "current override accepted")
eq(controller.effective(game).level, 77, "current stable-id override wins")
postgameState.masterWins = {}
eq(controller.currentStage(game).id, "master:brock", "progress can move backward by receipt")
eq(controller.upcomingStage(game).id, "master:misty", "upcoming stage is inspectable")
ok(controller.setOverride("master:brock", 75, game), "new current override accepted")
ok(controller.setOverride("master:misty", 79, game), "upcoming override accepted")
eq(controller.currentStage(game).id, "master:brock", "override never changes stage identity")
eq(controller.effective(game).level, 75, "current override remains keyed to Brock")
eq(controller.levelForStage(controller.upcomingStage(game)).level, 79,
  "upcoming override remains keyed to Misty")
ok(controller.resetOverride("master:brock", game), "reset current succeeds")
eq(controller.effective(game).level, 78, "reset current restores derived live cap")
ok(controller.resetAll(game), "reset all succeeds")
eq(controller.levelForStage(controller.upcomingStage(game)).level, 80,
  "reset all restores every derived cap")

-- Every source receives the same cap and imported over-level Pokémon are
-- read-only inputs. The engine decides to freeze growth without down-leveling.
local imported = { species = "MEWTWO", level = 99, exp = 970299 }
for _, source in ipairs({ "battle", "exp_share", "daycare", "rare_candy", "other" }) do
  eq(hooks["pokemon.level_cap"].fn(function() return nil end,
    { mon = imported, source = source }), 78, source .. " uses the same cap")
end
eq(imported.level, 99, "cap lookup never down-levels imported Pokémon")
eq(imported.exp, 970299, "cap lookup never rewrites imported experience")

emit("battle.started", { battle = { kind = "trainer" } })
eq(controller.setMode("off", game), false,
  "mode changes are blocked during an active battle")
eq(controller.setOverride("master:brock", 1, game), false,
  "custom changes are blocked during an active battle")
emit("battle.ended", {})
ok(controller.setMode("story", game), "mode changes resume after battle")
eq(controller.mode(), "story", "STORY mode persisted")

-- A New Game+ lineage without this feature's state is indistinguishable
-- from every other legacy save: OFF, no hook effect, and no migration write.
bucket[controller.STATE_KEY] = nil
local beforeNgPlusWrites = writes
game.save.modData = { kanto_ascendant = {
  legacy_journey = { version = 7, cycle = 2, runId = "NGPLUS:2" },
} }
eq(controller.mode(), "off", "New Game+ save without state defaults OFF")
eq(hooks["pokemon.level_cap"].fn(function() return nil end,
  { mon = imported, source = "battle" }), nil,
  "New Game+ OFF remains an exact hook pass-through")
eq(writes, beforeNgPlusWrites, "New Game+ OFF performs no migration write")

-- A future schema is never normalized, downgraded or written. It fails
-- closed to OFF until a newer build understands it.
local future = { version = 99, mode = "story", overrides = {
  ["gym:brock"] = 1,
} }
bucket[controller.STATE_KEY] = future
local beforeFutureWrites = writes
eq(controller.mode(), "off", "future state fails closed to OFF")
eq(controller.effective(game), nil, "future state installs no cap")
eq(controller.setMode("story", game), false, "future state is read-only")
eq(controller.resetAll(game), false, "future overrides are read-only")
eq(bucket[controller.STATE_KEY], future, "future table identity is untouched")
eq(writes, beforeFutureWrites, "future state causes no write")

-- The 6.6 port keeps its two shared-file seams explicit. This prevents a
-- later card merge from silently duplicating the controller, Day-Care bridge,
-- editor registration or CORE RULES gateway.
local function read(path)
  local file = assert(io.open(path, "rb"))
  local content = file:read("*a")
  file:close()
  return content
end
local function countPlain(content, needle)
  local count, cursor = 0, 1
  while true do
    local first = content:find(needle, cursor, true)
    if not first then return count end
    count = count + 1
    cursor = first + #needle
  end
end
local mainSource = read(root .. "/main.lua")
eq(countPlain(mainSource,
  "mod.exports.storyLevelCap = loadSibling(mod, \"story_level_cap.lua\")"), 1,
  "main owns exactly one Story Level Cap controller loader")
eq(countPlain(mainSource,
  "daycare.setLevelCap(mod.exports.storyLevelCap)"), 1,
  "main owns exactly one Day-Care policy bridge")
eq(countPlain(mainSource,
  "mod.exports.storyLevelCapMenu = loadSibling("), 1,
  "main owns exactly one Story Level Cap menu loader")
eq(countPlain(mainSource,
  "if not extendedCharacters.isEnabled() then return \"BLUE\" end"), 1,
  "main mirrors the disabled character selector's vanilla rival fallback")
local menuStart = assert(mainSource:find(
  "mod.exports.storyLevelCapMenu = loadSibling(", 1, true))
local menuEnd = assert(mainSource:find("local bicycleSelect", menuStart, true))
local menuWiring = mainSource:sub(menuStart, menuEnd - 1)
ok(not menuWiring:find("ascendantUi", 1, true),
  "6.6 menu wiring does not import the separate guided-UI owner")
local rewardsSource = read(root .. "/rematch_rewards.lua")
eq(countPlain(rewardsSource, "\"AscendantStoryLevelCap\""), 1,
  "CORE RULES owns exactly one Story Level Cap gateway")

print(("story_level_cap_66_test: PASS checks=%d"):format(checks))
