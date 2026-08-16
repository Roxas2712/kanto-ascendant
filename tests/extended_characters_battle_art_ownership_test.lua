-- Battle Art 1.9.0 remains the sole owner of player/trainer art and animation
-- choices. KASC may compose its exclusive Pokémon forms elsewhere, but its
-- standing-trainer resolver must not wrap Battle Art's sideTexture.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local battleDir = modDir
  .. "/tests/fixtures/battle_art_190_contract_mod"
local run = T.sdk.loadMods({ modDir, battleDir }, { data = Data })
T.eq(#run.errors, 0,
  "KASC and the exact Battle Art contract fixture load together")

local ascendant = assert(run.loader.exports.kanto_ascendant)
local battleArt = assert(run.loader.exports.BATTLE_ART_VOXEL_FORK)
local characters = assert(ascendant.extendedCharacters)
local overworld = assert(battleArt.overworldBattle)
T.eq(overworld.sideTexture, battleArt.originalSideTexture,
  "KASC does not wrap Battle Art's trainer sideTexture")
T.eq(overworld.__ascendantStandingTrainerMirror, nil,
  "Battle Art receives no KASC standing-trainer ownership marker")
T.eq(characters.voxelResolverStatus.rendererId,
  "BATTLE_ART_VOXEL_FORK", "delegation receipt names Battle Art")
T.eq(characters.voxelResolverStatus.delegated, true,
  "standing-trainer ownership is explicitly delegated")
T.eq(characters.voxelResolverStatus.reason,
  "renderer-owns-trainer-art", "delegation receipt is inspectable")

local game = {
  save = { options = { modOptions = { kanto_ascendant = {
    trainer_portrait_style = "crystal_hd",
  } } } },
}
local player = overworld.sideTexture({
  game = game, showPlayerBack = true,
}, "player")
T.eq(player.sourceOwner, "BATTLE_ART_PLAYER_ART",
  "Battle Art PLAYER ART survives KASC player presentation")
T.eq(player.sourceAsset, "/separate-battle-art/player-option.png",
  "KASC does not replace the selected player asset")

local ordinary = overworld.sideTexture({
  game = game, showEnemyTrainer = true, oppClass = "YOUNGSTER",
}, "enemy")
T.eq(ordinary.sourceOwner, "BATTLE_ART_TRAINER_ART",
  "Battle Art TRAINER ART survives KASC CRYSTAL HD mode")
T.eq(ordinary.sourceAsset, "/separate-battle-art/trainer-option.png",
  "ordinary enemy trainer path remains Battle Art-owned")

local rival = overworld.sideTexture({
  game = game, showEnemyTrainer = true, oppClass = "OPP_RIVAL1",
}, "enemy")
T.eq(rival.sourceOwner, "BATTLE_ART_TRAINER_ART",
  "KASC rival identity does not bypass Battle Art TRAINER ART")
T.eq(overworld.sideTexture, battleArt.originalSideTexture,
  "player/enemy probes leave Battle Art function identity unchanged")

run.release()
T.finish("extended_characters_battle_art_ownership_test")
