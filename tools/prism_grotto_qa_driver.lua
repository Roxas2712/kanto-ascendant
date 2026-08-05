-- Renderer-backed Prism Grotto acceptance capture.
--
--   POKEPORT_VERSION=red \
--   POKEPORT_IDENTITY=kanto-ascendant-prism-uat \
--   POKEPORT_DRIVER=/abs/path/to/prism_grotto_qa_driver.lua \
--   POKEPORT_TOUCH=0 POKEPORT_SPEED=8 SHOT_DIR=/tmp/prism-uat \
--   love .

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  U.wait(30)
  U.log("Prism UAT save directory:", love.filesystem.getSaveDirectory())
  local loaded = game.mods and game.mods.mods
    and game.mods.mods.trainer_rematch
  U.log("Prism UAT Kanto Ascendant:",
    loaded and loaded.path,
    loaded and loaded.manifest and loaded.manifest.version)
  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.trainer_rematch,
    "Kanto Ascendant export missing")
  local stateApi = assert(exports.johtoSignalsState,
    "Johto Signals state export missing")
  local prisms = assert(exports.driftglassPrisms,
    "Prism Grotto export missing")

  local root = assert(stateApi.root())
  root.earlyJohto = root.earlyJohto or {}
  root.earlyJohto.receiverRepaired = true
  root.earlyJohto.modeChosen = true
  root.earlyJohto.mode = "UNLEASHED"
  root.prismGrotto = {
    version = 1,
    introduced = false,
    heard = {},
    solved = {},
    pendingRewards = {},
  }
  stateApi.persist()
  prisms.install(game)

  game.save.inventory = game.save.inventory or {}
  game.save.bagOrder = game.save.bagOrder or {}
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1

  U.teleport(game, prisms.OUTPOST_MAP_ID, 11, 10, "up")
  U.wait(30)
  assert(game.overworld.map.id == prisms.OUTPOST_MAP_ID,
    "Driftglass outpost did not load for entrance capture")
  assert(U.shot(game, shotDir .. "/00_prism_entrance.png"))

  U.teleport(game, prisms.MAP_ID, 7, 12, "up")
  U.wait(35)
  assert(game.overworld.map.id == prisms.MAP_ID,
    "Prism Grotto did not load")
  assert(U.shot(game, shotDir .. "/01_prism_grotto_map.png"))
  U.teleport(game, prisms.MAP_ID, 7, 6, "up")
  U.wait(25)
  assert(U.shot(game, shotDir .. "/01b_tablet_and_reader.png"))
  U.teleport(game, prisms.MAP_ID, 3, 6, "up")
  U.wait(20)
  assert(U.shot(game, shotDir .. "/01c_left_prisms.png"))
  U.teleport(game, prisms.MAP_ID, 12, 6, "up")
  U.wait(20)
  assert(U.shot(game, shotDir .. "/01d_right_prisms.png"))

  local npc = { frozen = false }
  prisms.interactReader(game, npc)
  U.wait(80)
  assert(U.shot(game, shotDir .. "/02_reader_intro_en.png"))

  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  root.prismGrotto.introduced = true
  prisms.openArchive(game, npc)
  U.wait(35)
  assert(U.shot(game, shotDir .. "/03_prism_archive_en.png"))

  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  root.prismGrotto.active = "sunStone"
  root.prismGrotto.progress = 0
  for index, statue in ipairs({ "MOON", "WAVE", "CROWN", "SUN" }) do
    prisms.touchStatue(game, statue)
    U.wait(45)
    if index == 4 then
      assert(U.shot(game, shotDir .. "/04_sun_prism_reward.png"))
    end
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end
  assert(game.save.inventory.SUN_STONE == 1,
    "Sun Prism visual run did not grant exactly one Sun Stone")

  local options = game.mods.modOptions.trainer_rematch
  options.language = "de"
  root.prismGrotto.introduced = false
  prisms.interactReader(game, npc)
  U.wait(80)
  assert(U.shot(game, shotDir .. "/05_reader_intro_de.png"))

  U.log("PASS Prism Grotto renderer UAT:", shotDir)
  love.event.quit()
end
