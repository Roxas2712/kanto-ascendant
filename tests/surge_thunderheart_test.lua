-- Focused Lt. Surge / Major Bob regression matrix on a released engine.
-- Run from the engine directory with GEN1RECOMP_DIR, GEN1RECOMP_TEST_DIR
-- (the engine source checkout supplying tests.modkit), and
-- TRAINER_REMATCH_MOD_DIR set, then execute this file with LuaJIT.
local engine = assert(os.getenv("GEN1RECOMP_DIR"))
local tests = assert(os.getenv("GEN1RECOMP_TEST_DIR"))
package.path = engine .. "/?.lua;" .. tests .. "/?.lua;"
  .. tests .. "/?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
-- Source checkouts intentionally retain the 0.0.0-dev placeholder. Stamp only
-- this synthetic loader to the oldest supported public contract; packaged
-- 0.1.90/0.1.95 fixtures keep and exercise their exact release version.
local Version = require("src.core.Version")
local savedEngineVersion = Version.engine
if Version.engine == "0.0.0-dev" then Version.engine = "0.1.90" end
local testSupport = os.getenv("KASC_TEST_SUPPORT_DIR") or modPath .. "/tests"
local sink = dofile(testSupport .. "/headless_modkit_asset_sink.lua")(T, modPath, {
  derivedPrefix = "save/mod-derived/kanto_ascendant/",
  bridgeLove = true, readOnlyMetadataCache = true,
})
local run = T.sdk.loadMod(modPath, {
  data = Data,
  root = modPath:sub(1, 1) == "/" and "/" or nil,
})
Version.engine = savedEngineVersion
T.neq(run.mod, nil, "Kanto Ascendant loads on the selected engine")
T.eq(#run.errors, 0, "Kanto Ascendant loads without errors")

local exports = assert(run.loader.exports.kanto_ascendant)
local gorochu = assert(exports.gorochu)
local yellowPartner = assert(exports.yellowPartner)
local GameVersion = require("src.core.GameVersion")

local function boxText(box)
  local lines = {}
  for _, page in ipairs(box and box.pages or {}) do
    for _, line in ipairs(page) do lines[#lines + 1] = line end
  end
  return table.concat(lines, "\n")
end

local function setGerman(edition, enabled)
  local ids = {
    red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb",
  }
  local id = assert(ids[edition])
  if enabled then
    run.loader.mods[id] = {
      enabled = true, failed = false,
      manifest = { id = id, version = "test" },
    }
    run.loader.exports[id] = {}
  else
    run.loader.mods[id] = nil
    run.loader.exports[id] = nil
  end
end

local function resetState(extra)
  local bucket = {
    gorochu_quest = {
      version = 4, offered = false, declined = false,
      heartGiven = false, tearGenerated = false, tearClaims = 0,
      completed = false, playerEvolved = false,
    },
    yellow_partner = {
      version = 2, initialized = true, offered = false,
      accepted = false, declined = false, legacy = false,
      steps = 0, wins = 0, heartGiven = false,
    },
  }
  for key, value in pairs(extra or {}) do bucket[key] = value end
  run.loader.modSave = { kanto_ascendant = bucket }
  return bucket
end

local function fixture(edition, opts)
  opts = opts or {}
  GameVersion.set(edition)
  local pushed = {}
  local inventory = opts.inventory or {}
  local game = {
    data = Data,
    save = {
      inventory = inventory,
      bagOrder = {},
      flags = opts.flags or {},
      defeatedTrainers = opts.defeatedTrainers or {},
      party = opts.party or {}, boxes = {},
      player = { name = edition:upper(), id = 25 },
      pokedex = { seen = {}, owned = {} },
    },
    stack = {
      push = function(_, state) pushed[#pushed + 1] = state end,
      top = function() return pushed[#pushed] end,
      pop = function() return table.remove(pushed) end,
    },
  }
  local npc = {
    id = "VERMILION_GYM_obj_1",
    def = {
      name = "VERMILIONGYM_LT_SURGE",
      text = "TEXT_VERMILIONGYM_LT_SURGE",
      trainerClass = "OPP_LT_SURGE",
      trainerParty = 1,
      index = 1,
    },
    frozen = false,
    facePlayer = function() end,
  }
  local overworld = {
    map = { id = "VERMILION_GYM", def = { label = "VermilionGym" } },
    player = {},
  }
  return game, overworld, npc, pushed
end

-- The event-only repair path must explain itself coherently in the actual
-- German game layer too; it may not silently fall back to English.
do
  resetState()
  setGerman("red", true)
  local game, ow, npc, pushed = fixture("red", {
    flags = { EVENT_BEAT_LT_SURGE = true },
  })
  T.eq(gorochu.handleTalk(ow, npc, game), true,
    "German Red reaches the victory-record Thunderheart hand-off")
  T.eq(boxText(pushed[#pushed]):find("DEIN SIEG IST", 1, true) ~= nil,
    true, "German Red explains the canonical victory proof in German")
  setGerman("red", false)
end

for _, edition in ipairs({ "red", "blue" }) do
  resetState()
  local game, ow, npc, pushed = fixture(edition, {
    flags = { EVENT_BEAT_LT_SURGE = true },
  })
  local eligible, proof = gorochu.surgeVictory(game)
  T.eq(eligible, true,
    edition .. " recognizes the canonical Surge victory flag")
  T.eq(proof, "victory_flag",
    edition .. " distinguishes the missing-badge repair path")
  T.eq(gorochu.handleTalk(ow, npc, game), true,
    edition .. " cannot fall through to vanilla advice after a recorded win")
  T.eq(boxText(pushed[#pushed]):find("VICTORY IS ON", 1, true) ~= nil, true,
    edition .. " explains why the missing-badge save still qualifies")
  pushed[#pushed].choice(true)
  T.eq(game.save.inventory[gorochu.heartItemId], 1,
    edition .. " receives exactly one permanent Thunderheart")

  local earnedAt = gorochu.state().heartGivenAt
  for repair = 1, 2 do
    game.save.inventory[gorochu.heartItemId] = nil
    local before = #pushed
    T.eq(gorochu.handleTalk(ow, npc, game), true,
      edition .. " repairs earned Heart loss " .. repair)
    T.eq(#pushed, before + 1,
      edition .. " repair " .. repair .. " opens one recovery notice")
    T.eq(pushed[#pushed].choice, nil,
      edition .. " repair " .. repair .. " never replays the hand-off choice")
    T.eq(boxText(pushed[#pushed]):find("restored", 1, true) ~= nil, true,
      edition .. " repair " .. repair .. " explains the recovery")
    T.eq(game.save.inventory[gorochu.heartItemId], 1,
      edition .. " repair " .. repair .. " restores exactly one Heart")
    T.eq(gorochu.state().heartGivenAt, earnedAt,
      edition .. " repair " .. repair .. " preserves the original receipt")
    local after = #pushed
    T.eq(gorochu.handleTalk(ow, npc, game), false,
      edition .. " owned Heart releases Surge after repair " .. repair)
    T.eq(#pushed, after,
      edition .. " owned Heart never duplicates or reopens the reward")
  end
  gorochu.grantHeart(game)
  gorochu.grantHeart(game)
  T.eq(game.save.inventory[gorochu.heartItemId], 1,
    edition .. " idempotent grants can never stack the permanent Heart")

  resetState()
  game, ow, npc, pushed = fixture(edition, {
    inventory = { THUNDERBADGE = true },
  })
  eligible, proof = gorochu.surgeVictory(game)
  T.eq(eligible, true, edition .. " recognizes the Thunder Badge")
  T.eq(proof, "badge", edition .. " reports the normal badge path")
  T.eq(gorochu.handleTalk(ow, npc, game), true,
    edition .. " opens the normal Thunderheart hand-off")
  T.eq(boxText(pushed[#pushed]):find("THUNDER BADGE", 1, true) ~= nil, true,
    edition .. " keeps the normal badge-specific dialogue")

  resetState()
  game, ow, npc, pushed = fixture(edition, {
    inventory = {
      THUNDERBADGE = true,
      [gorochu.heartItemId] = edition == "red" and true or 1,
    },
  })
  T.eq(gorochu.handleTalk(ow, npc, game), false,
    edition .. " already-owned Heart releases Surge to later dialogue")
  T.eq(#pushed, 0,
    edition .. " already-owned Heart never duplicates the reward")

  resetState()
  game, ow, npc, pushed = fixture(edition)
  eligible, proof = gorochu.surgeVictory(game)
  T.eq(eligible, false,
    edition .. " does not unlock the reward before Surge is beaten")
  T.eq(proof, "not_defeated",
    edition .. " distinguishes the genuine pre-victory gate")
  T.eq(gorochu.handleTalk(ow, npc, game), false,
    edition .. " pre-victory interaction remains vanilla")
end

-- Yellow earns once, makes its published one-time Stay/Awakening decision,
-- then survives two independent physical-item losses. Recovery may restore
-- only the key item: it must not reopen or reapply the partner decision.
do
  local bucket = resetState()
  bucket.yellow_partner.offered = true
  bucket.yellow_partner.accepted = true
  bucket.yellow_partner.steps = yellowPartner.requiredSteps
  bucket.yellow_partner.wins = yellowPartner.requiredWins
  local Stats = require("src.pokemon.Stats")
  local partner = {
    species = "PIKACHU", level = 30,
    dvs = { attack = 8, defense = 9, speed = 10, special = 11, hp = 0 },
    statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
    moves = {},
    [yellowPartner.marker] = true,
  }
  partner.stats = Stats.calc(Data.pokemon.PIKACHU, partner.level,
    partner.dvs, partner.statExp, partner)
  partner.hp = partner.stats.hp
  local game, ow, npc, pushed = fixture("yellow", {
    inventory = { THUNDERBADGE = true }, party = { partner },
  })
  T.eq(yellowPartner.handleTalk(ow, npc, game), true,
    "Yellow earns the completed trial's permanent Thunderheart")
  T.eq(game.save.inventory[gorochu.heartItemId], 1,
    "Yellow's first award contains exactly one Heart")
  T.eq(pushed[#pushed].choice, nil,
    "Yellow's earned reward is not another acceptance choice")

  T.eq(yellowPartner.awaken(game, partner), true,
    "Yellow can commit the published one-time Stay/Awakening choice")
  local chosenStats = {}
  for key, value in pairs(partner.stats) do chosenStats[key] = value end
  T.eq(yellowPartner.awaken(game, partner), false,
    "Yellow cannot apply the final Awakening choice twice")
  T.same(partner.stats, chosenStats,
    "a repeated final choice cannot stack partner stats")
  T.eq(yellowPartner.state().choice, "stay",
    "Yellow records the exact final partner choice")
  local earnedAt = yellowPartner.state().heartGivenAt

  for repair = 1, 2 do
    game.save.inventory[gorochu.heartItemId] = nil
    local before = #pushed
    T.eq(yellowPartner.handleTalk(ow, npc, game), true,
      "Yellow repairs earned Heart loss " .. repair)
    T.eq(#pushed, before + 1,
      "Yellow repair " .. repair .. " opens one recovery notice")
    T.eq(pushed[#pushed].choice, nil,
      "Yellow repair " .. repair .. " never replays the partner choice")
    T.eq(game.save.inventory[gorochu.heartItemId], 1,
      "Yellow repair " .. repair .. " restores exactly one Heart")
    T.eq(yellowPartner.state().heartGivenAt, earnedAt,
      "Yellow repair " .. repair .. " preserves the original receipt")
    T.eq(yellowPartner.state().choice, "stay",
      "Yellow repair " .. repair .. " preserves the final choice")
    T.eq(partner[yellowPartner.awakeningMarker], true,
      "Yellow repair " .. repair .. " preserves the Awakening marker")
    T.same(partner.stats, chosenStats,
      "Yellow repair " .. repair .. " never reapplies partner stats")
    local after = #pushed
    T.eq(yellowPartner.handleTalk(ow, npc, game), false,
      "Yellow owned Heart releases Surge after repair " .. repair)
    T.eq(#pushed, after,
      "Yellow owned Heart never duplicates or reopens the reward")
  end
  yellowPartner.grantHeart(game)
  yellowPartner.grantHeart(game)
  T.eq(game.save.inventory[gorochu.heartItemId], 1,
    "Yellow idempotent grants can never stack the permanent Heart")
  T.eq(yellowPartner.state().choice, "stay",
    "Yellow idempotent item grants never replay the final choice")
end

-- Yellow: a refusal is reversible. The prior implementation remembered
-- `offered=true` and then returned false forever, which exposed only Surge's
-- vanilla Ground-type advice on every later interaction.
do
  local bucket = resetState()
  bucket.yellow_partner.offered = true
  bucket.yellow_partner.declined = true
  local game, ow, npc, pushed = fixture("yellow", {
    inventory = { THUNDERBADGE = true },
  })
  T.eq(yellowPartner.handleTalk(ow, npc, game), true,
    "Yellow can reopen a previously declined Thunderheart trial")
  T.eq(type(pushed[#pushed].choice), "function",
    "Yellow's renewed offer remains an explicit yes/no choice")
  pushed[#pushed].choice(true)
  T.eq(bucket.yellow_partner.accepted, true,
    "accepting the renewed Yellow offer starts the trial")
  T.eq(bucket.yellow_partner.declined, false,
    "accepting clears the old refusal marker")
end


-- The repair notice is localized as well as the normal offer.
do
  local bucket = resetState()
  bucket.yellow_partner.offered = true
  bucket.yellow_partner.accepted = true
  bucket.yellow_partner.heartGiven = true
  setGerman("yellow", true)
  local game, ow, npc, pushed = fixture("yellow", {
    inventory = { THUNDERBADGE = true },
  })
  T.eq(yellowPartner.handleTalk(ow, npc, game), true,
    "German Yellow repairs its missing earned Thunderheart")
  T.eq(boxText(pushed[#pushed]):find("HAT GEFEHLT", 1, true) ~= nil,
    true, "German Yellow explains the restored item in German")
  setGerman("yellow", false)
end

-- Yellow: heartGiven is historical state, not proof that the durable item is
-- still physically present. A lost/mis-migrated item is restored explicitly.
do
  local bucket = resetState()
  bucket.yellow_partner.offered = true
  bucket.yellow_partner.accepted = true
  bucket.yellow_partner.heartGiven = true
  local game, ow, npc, pushed = fixture("yellow", {
    inventory = { THUNDERBADGE = true },
  })
  T.eq(yellowPartner.handleTalk(ow, npc, game), true,
    "Yellow repairs a missing already-earned Thunderheart")
  T.eq(game.save.inventory[gorochu.heartItemId], 1,
    "Yellow repair puts the permanent Thunderheart back in the Bag")
  T.eq(boxText(pushed[#pushed]):find("restored", 1, true) ~= nil, true,
    "Yellow repair explains the recovery instead of showing vanilla advice")
end

-- Yellow uses the same canonical victory proof as Red/Blue, which also
-- covers upgraded saves whose event flag survived but badge inventory did not.
do
  resetState()
  local game, ow, npc, pushed = fixture("yellow", {
    flags = { EVENT_BEAT_LT_SURGE = true },
  })
  T.eq(yellowPartner.handleTalk(ow, npc, game), true,
    "Yellow victory-flag saves reach the trial without a badge-table entry")
  T.eq(type(pushed[#pushed].choice), "function",
    "Yellow victory-flag repair opens the authored offer")

  resetState()
  game, ow, npc, pushed = fixture("yellow")
  T.eq(yellowPartner.handleTalk(ow, npc, game), false,
    "Yellow remains gated before the canonical Surge victory")
end

-- A present Heart is authoritative in Yellow too: no duplicate item and no
-- reward prompt, leaving later/postgame Surge handling untouched.
do
  local bucket = resetState()
  bucket.yellow_partner.offered = true
  bucket.yellow_partner.accepted = true
  bucket.yellow_partner.heartGiven = true
  local game, ow, npc, pushed = fixture("yellow", {
    inventory = {
      THUNDERBADGE = true,
      [gorochu.heartItemId] = true,
    },
  })
  T.eq(yellowPartner.handleTalk(ow, npc, game), false,
    "Yellow already-owned Heart releases Surge to later dialogue")
  T.eq(#pushed, 0, "Yellow already-owned Heart is never duplicated")
end

-- NG+ can deliberately choose a different starter. An old marked partner
-- in the Bank/PC must not be required to unblock Surge in this journey.
for _, species in ipairs({ "TORCHIC", "EEVEE", "RAICHU" }) do
  for _, accepted in ipairs({ false, true }) do
    local bucket = resetState()
    bucket.yellow_partner.offered = accepted
    bucket.yellow_partner.accepted = accepted
    bucket.yellow_partner.steps = 17
    bucket.yellow_partner.wins = 1
    local game, ow, npc, pushed = fixture("yellow", {
      inventory = { THUNDERBADGE = true },
      party = { { species = species, hp = 20 } },
    })
    game.save.legacyStarter = species
    game.save.modData = { kanto_ascendant = { legacy_journey = {
      cycle = 2, partnerChosen = true,
      partnerSpecies = species, partnerChosenAtCycle = 2,
    } } }
    T.eq(yellowPartner.handleTalk(ow, npc, game), true,
      species .. " alternative starter reaches Surge hand-off")
    local prompt = pushed[#pushed]
    T.eq(type(prompt and prompt.choice), "function",
      species .. " stalled trial becomes an actionable hand-off")
    T.eq(boxText(prompt):find("POWER PLANT", 1, true) ~= nil, true,
      species .. " gets the shared reward instead of impossible partner steps")
    if prompt and prompt.choice then
      prompt.choice(true)
      T.eq(game.save.inventory[gorochu.heartItemId], 1,
        species .. " receives one permanent Heart without a prior-run partner")
      T.eq(yellowPartner.handleTalk(ow, npc, game), false,
        species .. " releases Surge to the rematch chain")
      T.eq(gorochu.handleTalk(ow, npc, game), false,
        species .. " is not intercepted again by the next quest controller")
    end
    T.eq(bucket.yellow_partner.steps, 17, "partial partner steps preserved")
    T.eq(bucket.yellow_partner.wins, 1, "partial partner wins preserved")
    T.eq(game.save.party[1][yellowPartner.marker], nil,
      "alternative starter never impersonates Yellow's original Pikachu")
  end
end

-- Current-run proof, optional refusal, localization and old-partner safety.
local function alternateFixture(german)
  local bucket = resetState()
  bucket.yellow_partner.offered = true
  bucket.yellow_partner.accepted = true
  bucket.yellow_partner.steps = 33
  bucket.yellow_partner.wins = 2
  setGerman("yellow", german == true)
  local game, ow, npc, pushed = fixture("yellow", {
    inventory = { THUNDERBADGE = true },
    flags = { EVENT_GOT_STARTER = true },
    party = { { species = "TORCHIC", hp = 20 } },
  })
  game.save.legacyStarter = "TORCHIC"
  game.save.modData = { kanto_ascendant = { legacy_journey = {
    cycle = 2, partnerChosen = true, partnerSpecies = "TORCHIC",
    partnerChosenAtCycle = 2,
  } } }
  return bucket, game, ow, npc, pushed
end

for _, german in ipairs({ false, true }) do
  for _, oldSpecies in ipairs({ "PIKACHU", "RAICHU", "GOROCHU" }) do
    local bucket, game, ow, npc, pushed = alternateFixture(german)
    local old = { species = oldSpecies, hp = 80, level = 100,
      [yellowPartner.marker] = true, ot = "OLD", otId = 99 }
    game.save.boxes = { { mons = { old } } }
    T.eq(yellowPartner.handleTalk(ow, npc, game), true,
      "boxed previous-run " .. oldSpecies .. " does not force partner trial")
    T.eq(boxText(pushed[#pushed]):find(german and "KRAFTWERKS" or "POWER PLANT", 1, true) ~= nil,
      true, "shared hand-off is localized")
    pushed[#pushed].choice(false)
    T.eq(game.save.inventory[gorochu.heartItemId], nil, "refusal awards nothing")
    pushed[#pushed].onDone()
    T.eq(npc.frozen, false, "refusal releases NPC")
    T.eq(yellowPartner.handleTalk(ow, npc, game), true, "refusal can be reconsidered")
    pushed[#pushed].choice(true)
    T.eq(game.save.inventory[gorochu.heartItemId], 1, "later acceptance awards Heart")
    pushed[#pushed].onDone()
    T.eq(npc.frozen, false, "acceptance releases NPC")
    T.eq(yellowPartner.handleTalk(ow, npc, game), false, "rematch dispatch reachable")
    T.eq(bucket.yellow_partner.steps, 33, "stored steps remain intact")
    T.eq(bucket.yellow_partner.wins, 2, "stored wins remain intact")
    T.eq(old[yellowPartner.marker], true, "old identity preserved")
    T.eq(old.species, oldSpecies, "old species preserved")
    T.eq(game.save.party[1][yellowPartner.marker], nil, "new starter not restamped")
    game.save.inventory[gorochu.heartItemId] = nil
    T.eq(yellowPartner.handleTalk(ow, npc, game), true, "earned missing Heart is repaired")
    T.eq(game.save.inventory[gorochu.heartItemId], 1, "repair restores exactly one Heart")
    T.eq(pushed[#pushed].choice, nil, "repair does not repeat reward choice")
  end
end
setGerman("yellow", false)

for _, invalid in ipairs({ "no_journey", "not_chosen", "mismatch", "pikachu" }) do
  local _, game, ow, npc, pushed = alternateFixture(false)
  local journey = game.save.modData.kanto_ascendant.legacy_journey
  if invalid == "no_journey" then game.save.modData = nil
  elseif invalid == "not_chosen" then journey.partnerChosen = false
  elseif invalid == "mismatch" then game.save.legacyStarter = "EEVEE"
  else journey.partnerSpecies = "PIKACHU"; game.save.legacyStarter = "PIKACHU" end
  T.eq(yellowPartner.handleTalk(ow, npc, game), true, invalid .. " retains partner quest")
  T.eq(pushed[#pushed].choice, nil, invalid .. " cannot bypass accepted partner trial")
  T.eq(game.save.inventory[gorochu.heartItemId], nil, invalid .. " awards no free Heart")
end

do
  local _, game, ow, npc, pushed = alternateFixture(false)
  game.save.inventory.THUNDERBADGE = nil
  T.eq(yellowPartner.handleTalk(ow, npc, game), false, "alternate starter still needs Surge victory")
  T.eq(#pushed, 0, "pre-victory opens no quest dialogue")
  game.save.flags.EVENT_BEAT_LT_SURGE = true
  T.eq(yellowPartner.handleTalk(ow, npc, game), true, "victory flag supports alternate starter")
  T.eq(type(pushed[#pushed].choice), "function", "victory flag reaches reward offer")
end

run.release()
sink.cleanup()
T.finish("surge_thunderheart")
