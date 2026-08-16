-- Shared one-shot save builder for the manual Legacy-Journey acceptance
-- points.  Each caller owns a separate POKEPORT_IDENTITY because the Legacy
-- archive is identity-global rather than slot-local.
local Q = {}

local function characterState(character)
  character = tostring(character or "RED"):upper()
  local rows = {
    RED = { rival = "BLUE", third = "GREEN" },
    BLUE = { rival = "GREEN", third = "RED" },
    GREEN = { rival = "RED", third = "BLUE" },
  }
  local row = assert(rows[character], "unknown Legacy QA character")
  return {
    version = 1, enabled = true, player_character = character,
    rival_character = row.rival, third_character = row.third,
  }
end

local function requireIdentity(config)
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY required")
  assert(identity == config.identity,
    ("refusing non-isolated identity %s (expected %s)")
      :format(tostring(identity), tostring(config.identity)))
  return identity
end

local function loadedExports(game)
  local exports = assert(game and game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant must be loaded")
  local journey = assert(exports.legacyJourney,
    "Legacy Journey controller must be loaded")
  assert(journey.archive, "Legacy archive controller must be loaded")
  return exports, journey, journey.archive
end

local function assertCleanArchive(archive, label)
  local profile = assert(archive.profile())
  assert(profile.cycle == 0 and not (profile.current
      and profile.current.runId),
    label .. " requires a fresh isolated Legacy archive")
end

local function baseSave(SaveData, version, character, id)
  local chars = characterState(character)
  local save = SaveData.newGame({
    version = version, playerName = character, rivalName = chars.rival_character,
  })
  save.player.id = id
  save.player.name, save.player.rival = character, chars.rival_character
  save.version = version
  save.meta = SaveData.buildMeta({
    { id = "kanto_ascendant", version = "6.5.0", api = 2 },
  }, save.meta)
  save.modData = type(save.modData) == "table" and save.modData or {}
  local bucket = type(save.modData.kanto_ascendant) == "table"
    and save.modData.kanto_ascendant or {}
  save.modData.kanto_ascendant = bucket
  bucket.extended_characters = chars
  save.lastOutdoor = { id = "PALLET_TOWN", x = 12, y = 12 }
  return save, bucket, chars
end

local function persistAndVerify(SaveData, config, save, verify)
  assert(SaveData.setActiveSlot(config.version, config.slot) == config.slot,
    "could not select isolated Legacy QA slot")
  assert(SaveData.writeSlot(config.version, config.slot, save),
    "could not write isolated Legacy QA slot")
  local loaded = assert(SaveData.load(config.version),
    "could not reload isolated Legacy QA slot")
  verify(loaded)
  return loaded
end

local function finish(U, line)
  if U and U.log then U.log(line) end
  love.event.quit(0)
end

function Q.preJourney(game, config)
  requireIdentity(config)
  local U = dofile("tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  assert(GameVersion.get() == config.version, "game version mismatch")
  local _, journey, archive = loadedExports(game)
  assertCleanArchive(archive, config.identity)

  local save, bucket = baseSave(SaveData, config.version, config.character,
    config.playerId)
  save.flags = type(save.flags) == "table" and save.flags or {}
  save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  save.flags.EVENT_GOT_STARTER = true
  save.flags.EVENT_GOT_POKEDEX = true
  local champion = Pokemon.new(game.data, "CHARIZARD", 70)
  save.party = { champion }
  save.hallOfFame = { { champion } }
  bucket.hevo_run = {
    version = 1, activeCharacter = config.character,
    dungeonLegacy = { seals = { [config.character] = true } },
    puzzles = {}, statues = {}, runComplete = true,
  }
  bucket.hidden_evolution_story_campaign = {
    version = 1, doorVisits = { [config.character] = true },
  }
  local ready, who = journey.reconcileHevoSealGate(save, false)
  assert(ready == true and who == config.character,
    "real seal + door + Hall gate did not reconcile")
  local gate = assert(bucket[journey.HEVO_GATE_KEY])
  gate.ready, gate.oakCalled, gate.pendingCall = true, true, false
  gate.doorAcknowledged, gate.character = true, config.character
  save.flags[journey.HEVO_READY_FLAG] = true
  save.flags[journey.HEVO_OAK_CALLED_FLAG] = true
  save.player.map, save.player.x, save.player.y, save.player.facing =
    journey.OAK_HOST_MAP, 1, 2, "up"
  save.objectToggles = type(save.objectToggles) == "table"
    and save.objectToggles or {}
  save.objectToggles.OAKS_LAB = {
    OAKSLAB_OAK1 = true, OAKSLAB_OAK2 = false,
  }
  assert(journey.canBegin(save) == true,
    "pre-Journey PC slot is not eligible to begin")
  local before = archive.profile()
  assert(before.cycle == 0 and not before.current.runId,
    "pre-Journey fixture must not start NG+ while being built")

  persistAndVerify(SaveData, config, save, function(loaded)
    assert(loaded.player and loaded.player.map == "OAKS_LAB"
        and loaded.player.x == 1 and loaded.player.y == 2
        and loaded.player.facing == "up",
      "pre-Journey slot did not retain the Lab PC position")
    assert(loaded.flags and loaded.flags[journey.HEVO_READY_FLAG]
        and loaded.flags[journey.HEVO_OAK_CALLED_FLAG],
      "pre-Journey slot lost its durable seal/Oak-call gate")
    assert(journey.canBegin(loaded) == true,
      "pre-Journey slot lost BEGIN LEGACY eligibility")
    local profile = archive.profile()
    assert(profile.cycle == 0 and not profile.current.runId,
      "writing B1 must not begin NG+")
  end)
  finish(U, "RC65 LEGACY B1 PASS: Oak Lab PC, durable seal/call, NG+ untouched")
end

local function freshLabBalls(save, version)
  save.objectToggles = type(save.objectToggles) == "table"
    and save.objectToggles or {}
  local lab = type(save.objectToggles.OAKS_LAB) == "table"
    and save.objectToggles.OAKS_LAB or {}
  save.objectToggles.OAKS_LAB = lab
  lab.OAKSLAB_OAK1, lab.OAKSLAB_OAK2 = true, false
  lab.OAKSLAB_RIVAL = true
  if version == "yellow" then
    -- Yellow owns exactly this one authored object; Oak hands every player
    -- choice directly after the rival has claimed it.
    lab.OAKSLAB_EEVEE_POKE_BALL = true
  else
    lab.OAKSLAB_CHARMANDER_POKE_BALL = true
    lab.OAKSLAB_SQUIRTLE_POKE_BALL = true
    lab.OAKSLAB_BULBASAUR_POKE_BALL = true
  end
end

function Q.freshLab(game, config)
  requireIdentity(config)
  local U = dofile("tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  assert(GameVersion.get() == config.version, "game version mismatch")
  local _, journey, archive = loadedExports(game)
  assertCleanArchive(archive, config.identity)

  local source, sourceBucket = baseSave(SaveData, config.version,
    config.character, config.sourcePlayerId)
  source.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  source.hallOfFame = { {} }
  source.party, source.boxes, source.pcItems = {}, { {} }, {}
  sourceBucket.legacy_manual_qa_source = { version = 1, isolated = true }
  local current, stored = assert(archive.beginJourney(source, {
    pact = "journey", bankPolicy = "open", playerAvatar = config.character,
    runRules = archive.safeRunRulesSnapshot(source),
  }))
  assert(current.pact == "journey" and current.bankPolicy == "open"
      and current.status == "pending_new_game",
    "fresh-Lab fixture did not make the real Journey/open hand-off")
  assert(stored and stored.cycle == 1,
    "fresh-Lab fixture did not advance the isolated archive once")

  -- Use the production save.new_game hook to seed the pending archive into
  -- the successor save.  Calling the archive seeding API a second time would
  -- make this QA point less representative of the real PC flow.
  local fresh, bucket, chars = baseSave(SaveData, config.version,
    config.character, config.playerId)
  assert(journey.isActive(fresh),
    "production New Game hook did not seed the pending Legacy run")
  local run = assert(bucket.legacy_journey)
  assert(run.runId == current.runId and run.pact == "journey"
      and run.bankPolicy == "open",
    "fresh save did not retain its durable Journey/open selection")
  assert(archive.setAvatar(fresh, config.character),
    "fresh save could not bind its chosen character")
  bucket.extended_characters = chars
  run.introPhase, run.labLocked = "partner", true
  run.partnerChosen, run.rivalBallTaken, run.rivalPartner = nil, nil, nil
  assert(journey.resumeFreshLab(nil, fresh),
    "fresh save could not enter the fail-closed Oak Lab phase")
  freshLabBalls(fresh, config.version)
  fresh.flags.EVENT_GOT_STARTER = nil
  fresh.lastOutdoor = { id = "PALLET_TOWN", x = 12, y = 12 }
  assert(archive.markRunStarted(fresh),
    "fresh save could not activate its real archive run")
  local bankOpen, bankWhy = archive.bankAccess(fresh)
  assert(bankOpen == false and bankWhy == "partner",
    "Journey/open Bank must still wait for Oak's partner")

  persistAndVerify(SaveData, config, fresh, function(loaded)
    local b = assert(loaded.modData and loaded.modData.kanto_ascendant)
    local s = assert(b.legacy_journey)
    assert(loaded.player and loaded.player.map == "OAKS_LAB"
        and loaded.player.x == 5 and loaded.player.y == 5
        and loaded.player.facing == "up",
      "fresh-Lab slot did not retain its locked Oak position")
    assert(s.pact == "journey" and s.bankPolicy == "open"
        and s.introPhase == "partner" and s.labLocked == true,
      "fresh-Lab slot lost pact or Lab phase")
    assert(not s.partnerChosen and not s.rivalBallTaken
        and s.rivalPartner == nil and not loaded.flags.EVENT_GOT_STARTER,
      "fresh-Lab slot skipped its ball/partner/rival contract")
    assert(loaded.objectToggles.OAKS_LAB.OAKSLAB_OAK1 == true
        and loaded.objectToggles.OAKS_LAB.OAKSLAB_OAK2 == false,
      "fresh-Lab slot lost visible Oak")
    if config.version == "yellow" then
      assert(loaded.objectToggles.OAKS_LAB.OAKSLAB_EEVEE_POKE_BALL == true,
        "Yellow fresh Lab lost its sole authored ball")
      assert(loaded.objectToggles.OAKS_LAB.OAKSLAB_CHARMANDER_POKE_BALL == nil
          and loaded.objectToggles.OAKS_LAB.OAKSLAB_SQUIRTLE_POKE_BALL == nil
          and loaded.objectToggles.OAKS_LAB.OAKSLAB_BULBASAUR_POKE_BALL == nil,
        "Yellow fresh Lab must not manufacture three table balls")
    end
    local open, why = archive.bankAccess(loaded)
    assert(open == false and why == "partner",
      "reloaded fresh-Lab Bank must remain partner-gated")
    local profile = archive.profile()
    assert(profile.cycle == 1 and profile.current.status == "active"
        and profile.current.pact == "journey"
        and profile.current.bankPolicy == "open",
      "fresh-Lab archive did not retain its real active pact")
  end)
  finish(U, ("RC65 LEGACY %s PASS: Journey/open, locked Oak Lab, no partner")
    :format(config.version:upper()))
end

Q.characterState = characterState
return Q
