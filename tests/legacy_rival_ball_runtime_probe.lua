-- Bounded real-engine probe for the first post-selector Oak-Lab step.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local Runtime = require("src.mods.Runtime")
  local Pokemon = require("src.pokemon.Pokemon")
  local api = assert(game.mods.exports.kanto_ascendant)
  local journey, archive = api.legacyJourney, api.legacyJourney.archive
  local characters = api.extendedCharacters
  local slot = "slot65rivalballprobe"
  assert(SaveData.setActiveSlot("red", slot) == slot)

  local source = SaveData.newGame(game:bootConfig())
  source.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  source.hallOfFame = { { Pokemon.new(game.data, "CHARIZARD", 70) } }
  source.party = { Pokemon.new(game.data, "CHARIZARD", 70) }
  local current = assert(archive.beginJourney(source, {
    pact = "journey", bankPolicy = "open", playerAvatar = "RED",
    runRules = archive.safeRunRulesSnapshot(source),
  }))
  local fresh = SaveData.newGame(game:bootConfig())
  Runtime.emit("save.created", { save = fresh })
  assert(archive.setAvatar(fresh, "RED"))
  game.save = fresh
  game:adoptSave(fresh)
  characters.select("RED")
  assert(journey.resumeFreshLab(nil, fresh))
  assert(archive.markRunStarted(fresh))
  assert(SaveData.writeSlot("red", slot, fresh))

  local loaded = assert(SaveData.load())
  game:restoreSave(loaded, false)
  U.wait(60)
  local function state()
    return game.save.modData.kanto_ascendant.legacy_journey
  end
  local before = state()
  U.log("RIVAL GATE BEFORE",
    "active=" .. tostring(journey.isActive(game.save)),
    "taken=" .. tostring(before.rivalBallTaken),
    "partner=" .. tostring(before.partnerChosen),
    "followed=" .. tostring(game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB),
    "oakAsked=" .. tostring(game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON),
    "gotStarter=" .. tostring(game.save.flags.EVENT_GOT_STARTER),
    "map=" .. tostring(game.overworld.map and game.overworld.map.id),
    "cell=" .. tostring(game.overworld.player.cellX) .. ","
      .. tostring(game.overworld.player.cellY))

  U.tap(game, "down")
  U.wait(120)
  local after = state()
  local hidden = game.save.objectToggles and game.save.objectToggles.OAKS_LAB
    and game.save.objectToggles.OAKS_LAB.OAKSLAB_BULBASAUR_POKE_BALL == false
  local ok = after.rivalBallTaken == true and hidden
    and after.rivalPartner == nil and after.partnerSpecies == nil
  U.log(ok and "PASS" or "FAIL", "first real Lab step claims right ball",
    "taken=" .. tostring(after.rivalBallTaken),
    "hidden=" .. tostring(hidden))
  love.event.quit(ok and 0 or 1)
end
