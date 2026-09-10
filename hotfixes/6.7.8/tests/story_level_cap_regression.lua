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
  "Story cap stays independent of adaptive opponent scaling")
eq(adaptivePlans, 0, "Story cap does not feed back adaptive levels")

-- The published Story cap stays progression-bound during battle, even
-- when the constructed opponent or player party has a higher level.
emit("battle.started", { battle = {
  kind = "trainer", game = game, oppClass = "OPP_MISTY", partyIndex = 1,
  enemyParty = { { species = "STARMIE", level = 25 } },
} })
eq(hooks["pokemon.level_cap"].fn(function() return nil end,
  { mon = game.save.party[1], source = "battle" }), 21,
  "active mandatory battle keeps the progression ceiling")
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

-- Every ordinary badge interval retains a cap, across all supported editions,
-- even before acquiring the next route receipt. Selection must stay read-only.
local writesBeforeGaps = writes
for _, version in ipairs({ "red", "blue", "yellow" }) do
  edition = version
  local gapGame = newGame()
  for index, def in ipairs(controller.gyms) do
    local stage = controller.currentStage(gapGame)
    ok(stage, version .. " badge interval " .. index .. " has a milestone")
    eq(stage.id, def.id, version .. " next undefeated milestone")
    eq(controller.effective(gapGame).level, stage.level,
      version .. " route gap keeps the effective cap")
    eq(hooks["pokemon.level_cap"].fn(function() return 100 end,
      { game = gapGame, source = "battle" }), stage.level,
      version .. " route gap enforces the experience cap")
    gapGame.save.inventory[def.badge] = 1
  end
  eq(controller.currentStage(gapGame).id, "league:lorelei",
    version .. " all badges advance to League")
end
edition = "red"
eq(writes, writesBeforeGaps, "route-gap selection never rewrites saves")
local nonlinear = newGame()
nonlinear.save.inventory.BOULDERBADGE = 1
nonlinear.save.inventory.CASCADEBADGE = 1
nonlinear.save.inventory.BICYCLE = 1
eq(controller.currentStage(nonlinear).id, "gym:koga",
  "accessible nonlinear Gym still takes priority over locked Surge")

-- Route errands between leaders must not disable the cap or its editor.
game.save.inventory.CASCADEBADGE = 1
eq(controller.currentStage(game).id, "gym:surge",
  "after Misty, Surge remains the target before the Cut receipt")
eq(controller.upcomingStage(game).id, "gym:erika",
  "after Misty, the upcoming milestone remains available")
eq(controller.effective(game).level, 24, "story cap remains active before Cut")
local menu = assert(loadfile(root .. "/story_level_cap_menu.lua"))()(mod, {
  controller = controller,
})
ok(controller.setMode("custom"), "custom mode before Cut")
local rows = menu.rows(game)
eq(rows[3].right, "LT.SURGE LV24", "current menu row before Cut")
eq(rows[4].right, "ERIKA LV29", "upcoming menu row before Cut")
ok(menu.adjust(game, rows[3], 1), "current custom cap editable before Cut")
ok(menu.adjust(game, rows[4], -1), "upcoming custom cap editable before Cut")
eq(controller.effective(game).level, 25, "custom cap applies before Cut")
ok(menu.activate(game, rows[5]), "reset current works before Cut")
eq(controller.effective(game).level, 24, "reset current restores derived cap")
eq(controller.levelForStage(controller.upcomingStage(game)).level, 28,
  "reset current preserves upcoming override")
ok(menu.adjust(game, menu.rows(game)[3], 1), "restore current override")
ok(menu.activate(game, rows[6]), "reset all works before Cut")
eq(controller.effective(game).level, 24, "reset all restores current cap")
eq(controller.levelForStage(controller.upcomingStage(game)).level, 29,
  "reset all restores upcoming cap")
ok(controller.setMode("story"), "restore story mode")
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
eq(controller.currentStage(game).id, "gym:koga",
  "Koga remains the cap while clearing the route into Fuchsia")
game.save.flags.EVENT_GOT_POKE_FLUTE = true
eq(controller.currentStage(game).id, "gym:koga",
  "nonlinear Sabrina win does not skip undefeated Koga")
game.save.inventory.SOULBADGE = 1
eq(controller.currentStage(game).id, "gym:blaine",
  "Blaine remains the cap while finding the Secret Key")
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


print(("story_level_cap_regression: PASS checks=%d"):format(checks))
