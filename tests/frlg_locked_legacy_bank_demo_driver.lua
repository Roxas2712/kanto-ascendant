-- Focused real-LÖVE demo for a mixed Legacy Bank: a legal Kanto Pokémon
-- remains withdrawable while the current NG+ boundary visibly seals a later
-- species.  Run only against a disposable portable identity because it starts
-- a real Legacy Journey and writes the archive through the production API.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Runtime = require("src.mods.Runtime")
  local SaveData = require("src.core.SaveData")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local api = assert(game.mods.exports.kanto_ascendant)
  local journey = assert(api.legacyJourney)
  local starters = assert(api.legacyStarters)

  local fresh = SaveData.newGame(game:bootConfig())
  game.save = fresh
  game:adoptSave(fresh)
  Runtime.emit("save.created", { game = game, save = fresh })

  fresh.options = fresh.options or {}
  fresh.options.modOptions = fresh.options.modOptions or {}
  local options = fresh.options.modOptions.kanto_ascendant or {}
  fresh.options.modOptions.kanto_ascendant = options
  game.mods.modOptions.kanto_ascendant = options
  options.language = "de"
  options.modern_storage_ui = true
  options.pc_interface_style = "firered"
  options.legacy_bank_interface_style = "firered"
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant", key = "language", value = "de",
  })
  game:applyOptions(fresh.options)

  fresh.player.id = 6516024
  fresh.party = {
    Pokemon.new(game.data, "PIKACHU", 18),
    Pokemon.new(game.data, "CHIKORITA", 18),
  }
  fresh.inventory = {}
  fresh.money = 0
  -- The hand-off itself is production-authentic too: Legacy Journey only
  -- accepts a completed source run, so the disposable fixture carries one
  -- ordinary Hall-of-Fame record before it archives the party.
  fresh.hallOfFame = { { champion = true } }

  local current, err = journey.archive.beginJourney(fresh, {
    pact = "release_e2e",
    runRules = journey.archive.safeRunRulesSnapshot(fresh),
  })
  assert(current, err)
  assert(journey.startFreshGame(game), "fresh Legacy Journey failed")

  -- Cross the same post-rival Oak choice seam used by the authored Lab
  -- sequence.  The OPEN Bank policy intentionally starts only after the new
  -- partner exists, so the demo does not bypass that NG+ rule.
  assert(journey.archive.setAvatar(game.save, "RED"))
  local run = assert(journey.state(game.save))
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON = true
  game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = true
  run.rivalBallTaken = true
  assert(starters.choose(game, "BULBASAUR", "balanced", "catalog",
    "catalog"))

  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  assert(journey.openBank(game), "Legacy Bank did not open")
  U.wait(4)

  local bank = assert(game.stack:top())
  assert(bank.__ascendantLegacyBankOrganizer,
    "FireRed Legacy Bank organizer was not selected")
  bank.bankIndex = 2
  local row = assert(bank:bankRow())
  assert(row.mon and row.mon.species == "CHIKORITA",
    "expected the sealed Chikorita in Legacy Bank slot 2")
  assert(row.withdrawBlocked and row.withdrawReason,
    "NG+ boundary did not expose its visible withdrawal reason")

  U.wait(2)
  assert(U.shot(game, dir .. "/ngplus_legacy_bank_gesperrt.png"))
  local result = assert(io.open(dir .. "/demo_result.txt", "wb"))
  result:write("PASS\nreason=" .. tostring(row.withdrawReason) .. "\n")
  result:close()
  love.event.quit(0)
end
