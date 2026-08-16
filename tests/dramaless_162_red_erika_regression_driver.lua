-- Focused live acceptance for the user's installed DRAMALESS_SHAPE 1.6.2.ST.
-- One real FULL trainer intro must render the legacy-save Red player standee
-- and the approved Erika V2 standee together.  The fresh test identity keeps
-- this entirely separate from ASH/BLITZ and no save API is called here.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local Runtime = require("src.mods.Runtime")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods and game.mods.exports)
  local ascendant = assert(exports.kanto_ascendant)
  local characters = assert(ascendant.extendedCharacters)
  local pack = assert(ascendant.frlgTrainerPack)
  local dramatic = assert(exports.DRAMALESS_SHAPE,
    "installed DRAMALESS_SHAPE export is missing")
  local handle = assert(game.mods.mods.DRAMALESS_SHAPE,
    "installed DRAMALESS_SHAPE handle is missing")
  assert(handle.manifest and handle.manifest.version == "1.6.2.ST",
    "test did not load installed DRAMALESS_SHAPE 1.6.2.ST")
  local overworldBattle = assert(dramatic.lib.require("OverworldBattle"))
  assert(type(overworldBattle.sideTexture) == "function",
    "installed 1.6.2.ST has no sideTexture capability")

  U.wait(20)
  local legacy = characters.getState()
  assert(legacy.enabled == false and legacy.player_character == "RED",
    "fresh legacy save did not resolve canonically to Red")

  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  local options = game.mods.modOptions.kanto_ascendant
  options.character_sprite_style = "crystal"
  options.trainer_portrait_style = "crystal_hd"
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant",
  })
  pack.refresh(game)
  characters.refreshVisuals(game)

  Pipelines.setLevel("voxel", 1)
  Pipelines.syncOptions(game.save.options)
  overworldBattle.setting:setIndex(1, game)
  if overworldBattle.backSetting then
    overworldBattle.backSetting:setIndex(1, game)
  end
  assert(Pipelines.level("voxel") == 1
      and Pipelines.levelLabel("voxel") == "FULL",
    "FULL pipeline did not activate")

  local resolver = assert(characters.voxelResolverStatus,
    "approved trainer resolver sentinel is missing")
  U.log("resolver", tostring(resolver.schema), tostring(resolver.installed),
    tostring(resolver.rendererId), tostring(resolver.rendererVersion),
    tostring(resolver.rendererProvenance), tostring(resolver.capability),
    tostring(resolver.reason))
  assert(resolver.schema == "ka-approved-trainer-resolver/v1"
      and resolver.installed == true
      and resolver.rendererId == "DRAMALESS_SHAPE"
      and resolver.rendererVersion == "1.6.2.ST"
      and resolver.rendererProvenance == "artyrambles-classic-release"
      and resolver.capability == "sideTexture",
    "approved resolver did not bind the installed classic renderer")

  game.save.player = game.save.player or {}
  game.save.player.name = "RED"
  game.save.party = { Pokemon.new(game.data, "CHARMANDER", 50) }
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local battle = BattleState.newTrainer(game, "OPP_ERIKA", 1)
  game.overworld:pushBattle(battle)

  local ready = false
  for _ = 1, 600 do
    if game.stack:top() == battle and battle.showPlayerBack
        and battle.showEnemyTrainer and (battle.introSlide or 1) <= 0 then
      ready = true
      break
    end
    U.wait(1)
  end
  assert(ready, "real Erika FULL trainer intro did not stage")

  local playerTexture = assert(overworldBattle.sideTexture(battle, "player"),
    "Red player FULL texture is missing")
  local erikaTexture = assert(overworldBattle.sideTexture(battle, "enemy"),
    "Erika FULL texture is missing")
  local playerReceipt = assert(playerTexture.ascendantApprovedTrainerResolver,
    "Red player texture has no approved provenance receipt")
  local erikaReceipt = assert(erikaTexture.ascendantApprovedTrainerResolver,
    "Erika texture has no approved provenance receipt")

  assert(playerTexture.ascendantStandingTrainer == "RED"
      and playerTexture.ascendantHighResTrainer == true
      and playerTexture.ascendantHighResSource ==
        "assets/characters/crystal_chars/red_voxel_front_hd.png"
      and playerReceipt.schema == "ka-approved-trainer-texture/v1"
      and playerReceipt.identity == "RED"
      and playerReceipt.rendererVersion == "1.6.2.ST",
    "legacy Red did not use approved Full Red source")
  assert(erikaTexture.kantoTrainerClass == "OPP_ERIKA"
      and erikaTexture.ascendantHighResTrainer == true
      and erikaTexture.ascendantHighResSource ==
        "assets/characters/frlg_trainers/leader_erika_voxel_front_hd_v2.png"
      and erikaReceipt.schema == "ka-approved-trainer-texture/v1"
      and erikaReceipt.class == "OPP_ERIKA"
      and erikaReceipt.approvedVersion == "v2"
      and erikaReceipt.rendererVersion == "1.6.2.ST",
    "Erika did not use the approved V2 FULL source")
  assert(#characters.voxelFallbackReceipts == 0,
    "approved Red/Erika run recorded a silent fallback")

  U.wait(20)
  assert(U.shot(game, dir .. "/04_full_red_erika_dramaless_1.6.2.ST.png"))
  local out = assert(io.open(dir .. "/full_red_erika_result.txt", "wb"))
  out:write("status=PASS\n",
    "scope=real-FULL-intro-red+erika\n",
    "renderer=DRAMALESS_SHAPE@1.6.2.ST\n",
    "provenance=artyrambles-classic-release\n",
    "player=red_voxel_front_hd.png\n",
    "enemy=leader_erika_voxel_front_hd_v2.png\n",
    "fallback_receipts=0\n",
    "user_save_writes=0\n",
    "test_identity_autosave=engine-owned\n",
    "fail=0\n")
  out:close()
  print("DRAMALESS 1.6.2.ST RED ERIKA RESULT pass=12 fail=0")
  love.event.quit(0)
end
