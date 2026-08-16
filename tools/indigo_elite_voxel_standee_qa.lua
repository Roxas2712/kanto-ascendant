-- Bounded FULL-Voxel acceptance for the four Indigo Elite standees.  This
-- deliberately starts real trainer battles through BattleState, but quits
-- before resolving them.  The normal 2D trainer pictures are not modified.

return function(game)
  local engine = os.getenv("GEN1RECOMP_DIR") or "."
  local U = dofile(engine .. "/tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local GBCFX = require("src.render.GBCFX")
  local root = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local exports = assert(game.mods and game.mods.exports,
    "mod exports missing")
  local ascendant = assert(exports.kanto_ascendant,
    "Kanto Ascendant did not load")
  local characters = assert(ascendant.extendedCharacters,
    "extended character export missing")
  local dramatic = assert(exports.DRAMALESS_SHAPE,
    "DRAMALESS_SHAPE dependency did not load")
  local overworldBattle = assert(dramatic.lib.require("OverworldBattle"),
    "DRAMALESS OverworldBattle missing")

  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.options.gbcfx = 0
  GBCFX.setLevel(0)
  Pipelines.setLevel("voxel", 2)
  U.wait(3)
  Pipelines.setLevel("voxel", 1)
  Pipelines.syncOptions(game.save.options)
  overworldBattle.setting:setIndex(1, game)
  overworldBattle.backSetting:setIndex(1, game)
  assert(Pipelines.level("voxel") == 1
    and Pipelines.levelLabel("voxel") == "FULL"
    and Pipelines.worldPipeline() == "voxel",
    "FULL Voxel is not active")
  assert(GBCFX.level == 0 and not GBCFX.active(),
    "GBCFX must be off for the acceptance images")

  characters.select("RED")
  characters.refreshVisuals(game)
  game.save.party = { Pokemon.new(game.data, "MEWTWO", 100) }

  local rows = {
    { "OPP_LORELEI", "lorelei",
      "assets/characters/frlg_trainers/elite_four_lorelei_voxel_front_hd_v2.png" },
    { "OPP_BRUNO", "bruno",
      "assets/characters/frlg_trainers/elite_four_bruno_voxel_front_hd_v2.png" },
    { "OPP_AGATHA", "agatha",
      "assets/characters/frlg_trainers/elite_four_agatha_voxel_front_hd_v2.png" },
    { "OPP_LANCE", "lance",
      "assets/characters/frlg_trainers/elite_four_lance_voxel_front_hd_v2.png" },
  }
  local seen = {}
  for index, row in ipairs(rows) do
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    local battle = BattleState.newTrainer(game, row[1], 1)
    game.overworld:pushBattle(battle)
    for _ = 1, 1200 do
      if game.stack:top() == battle and battle.showEnemyTrainer
          and battle.showPlayerBack and (battle.introSlide or 1) <= 0 then
        break
      end
      U.wait(1)
    end
    assert(game.stack:top() == battle and battle.showEnemyTrainer,
      row[1] .. " trainer intro did not render")
    assert(battle.oppClass == row[1], row[1] .. " battle class changed")
    local spec = assert(characters.voxelStandingTrainerSpec(battle, "enemy"),
      row[1] .. " has no dedicated Voxel spec")
    assert(spec.path == row[3], row[1] .. " resolved wrong Voxel source")
    assert(not seen[spec.path], row[1] .. " shares another Elite source")
    seen[spec.path] = true
    local texture = assert(overworldBattle.sideTexture(battle, "enemy"),
      row[1] .. " Voxel texture missing")
    assert(texture.indigoEliteClass == row[1]
      and texture.ascendantHighResSource == row[3]
      and texture.ascendantHighResTrainer == true,
      row[1] .. " used a native 64px card or wrong fallback")
    local width, height = texture.canvas:getDimensions()
    assert(width == 320 and height == 288,
      row[1] .. " HD canvas dimensions changed")
    assert(texture.ay * 2 - 128 >= 4,
      row[1] .. " head is clipped above the card")
    assert(Pipelines.level("voxel") == 1
      and Pipelines.worldPipeline() == "voxel",
      row[1] .. " left FULL Voxel")
    U.wait(24)
    assert(U.shot(game, ("%s/%02d_%s_full_voxel.png")
      :format(root, index, row[2])), row[1] .. " screenshot failed")
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
    U.wait(5)
  end
  local count = 0
  for _ in pairs(seen) do count = count + 1 end
  assert(count == 4, "did not use four distinct Elite Voxel sources")
  local result = assert(io.open(root .. "/driver_result.txt", "wb"))
  result:write("PASS\nrenderer=FULL\nclasses=4\n")
  result:close()
  U.log("INDIGO ELITE FULL VOXEL PASS", root)
  love.event.quit(0)
end
