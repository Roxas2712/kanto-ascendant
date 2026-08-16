-- Live proof for Oak's Lab: step across the real y=6 event edge, enter the
-- starter rival battle, and verify the Ascendant-only indoor camera lens.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local characters = assert(exports.extendedCharacters)
  local cameraCompat = assert(exports.dramalessCameraCompat)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  game.mods.modOptions.kanto_ascendant.character_sprite_style = "crystal"
  game.mods.modOptions.kanto_ascendant.dramaless_battle_camera = "classic"
  characters.select("GREEN")
  characters.refreshVisuals(game)
  cameraCompat.apply(game)
  game.save.player.name, game.save.player.rival = "CASEY", "RED"
  game.save.party = { Pokemon.new(game.data, "SQUIRTLE", 5) }
  game.save.flags = {
    EVENT_FOLLOWED_OAK_INTO_LAB = true,
    EVENT_GOT_STARTER = true,
    EVENT_CHOSE_SQUIRTLE = true,
  }
  game.save.objectToggles = game.save.objectToggles or {}
  game.save.objectToggles.OAKS_LAB = nil

  U.teleport(game, "OAKS_LAB", 4, 5, "down")
  U.wait(24)
  check("Oak's Lab is loaded at the real event edge", game.overworld
    and game.overworld.map.id == "OAKS_LAB"
    and game.overworld.player.cellY == 5)
  U.hold(game, "down", 24)

  local sawEventText = false
  for _ = 1, 500 do
    local top = game.stack:top()
    if top and top.pages then sawEventText = true break end
    U.wait(2)
  end
  check("Oak's Lab y=6 event challenges the player", sawEventText)
  U.wait(100)
  check("Oak's Lab challenge capture",
    U.shot(game, dir .. "/lab_01_real_challenge.png"))

  local battle
  for _ = 1, 700 do
    local top = game.stack:top()
    if getmetatable(top) == BattleState then battle = top break end
    if top ~= game.overworld then U.tap(game, "a") end
    U.wait(2)
  end
  check("Oak's Lab event pushes the starter rival battle", battle ~= nil)
  if battle then
    for _ = 1, 300 do
      if battle.showEnemyTrainer and battle.showPlayerBack then break end
      U.wait(2)
    end
  end

  local dramatic = game.mods.exports.DRAMALESS_SHAPE
    or game.mods.exports.DRAMATIC_SHAPE
  local BattleCam = dramatic and dramatic.lib.require("BattleCam")
  local BattleArena = dramatic and dramatic.lib.require("BattleArena")
  local arena = BattleArena and BattleArena.find(game.overworld.map,
    game.overworld.player.cellX, game.overworld.player.cellY, false)
  local rig = BattleCam and arena and BattleCam.rigFor(arena)
  check("Oak's Lab uses the map-specific wider lens", rig and rig.frameH
    and rig.frameH >= cameraCompat.OAKS_LAB_WIDE_FRAME_H)
  check("Oak's Lab Voxel battle is fully framed",
    U.shot(game, dir .. "/lab_02_voxel_zoomed_out.png"))

  U.log(("OAK LAB CAMERA RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
