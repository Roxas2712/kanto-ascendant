-- Battle Art 1.9.2 remains the sole stage/HUD/animation owner, but a selected
-- KASC Red/Blue/Green identity is stronger than Battle Art's default Red
-- player and Blue rival option. KASC supplies those two approved identity
-- textures at Battle Art's sideTexture source boundary; ordinary trainer and
-- Pokémon art remain renderer-owned.

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
T.neq(overworld.sideTexture, battleArt.originalSideTexture,
  "KASC supplies explicit identities through Battle Art's source boundary")
T.eq(overworld.__ascendantStandingTrainerMirror, true,
  "Battle Art receives one idempotent identity-source resolver")
T.eq(characters.voxelResolverStatus.rendererId,
  "BATTLE_ART_VOXEL_FORK", "delegation receipt names Battle Art")
T.eq(characters.voxelResolverStatus.delegated, true,
  "stage, HUD and animation ownership stay explicitly delegated")
T.eq(characters.voxelResolverStatus.identityOverride, true,
  "receipt narrows the KASC exception to selected identities")
T.eq(characters.voxelResolverStatus.reason,
  "renderer-owns-stage-kasc-owns-selected-identity",
  "mixed ownership receipt is inspectable")

local game = {
  save = { options = { modOptions = { kanto_ascendant = {
    trainer_portrait_style = "crystal_hd",
  } } } },
}
local g = assert(love.graphics)
local originalNewImage = g.newImage
g.newImage = function(path)
  return {
    path = path,
    setFilter = function() end,
    getWidth = function() return 128 end,
    getHeight = function() return 128 end,
    getDimensions = function() return 128, 128 end,
  }
end

local pairs = {
  { player = "RED", rival = "BLUE" },
  { player = "BLUE", rival = "GREEN" },
  { player = "GREEN", rival = "RED" },
}
for _, pair in ipairs(pairs) do
  characters.select(pair.player)
  local player = overworld.sideTexture({
    game = game, showPlayerBack = true,
  }, "player")
  T.eq(player.ascendantStandingTrainer, pair.player,
    pair.player .. " player identity wins over Battle Art's Red default")
  T.check(player.ascendantHighResSource:match(
      "/" .. pair.player:lower() .. "_voxel_front_hd%.png$") ~= nil,
    pair.player .. " uses its approved staged-player asset")
  T.eq(player.ascendantApprovedTrainerResolver.role, "player",
    "player override remains a source receipt, not a second overlay")

  local rival = overworld.sideTexture({
    game = game, showEnemyTrainer = true, oppClass = "OPP_RIVAL1",
  }, "enemy")
  T.eq(rival.ascendantStandingTrainer, pair.rival,
    pair.rival .. " rival identity wins over Battle Art's Blue default")
  T.check(rival.ascendantHighResSource:match(
      "/" .. pair.rival:lower() .. "_voxel_front_hd%.png$") ~= nil,
    pair.rival .. " uses its approved staged-rival asset")
  T.eq(rival.ascendantApprovedTrainerResolver.role, "enemy",
    "rival override remains a source receipt, not a second overlay")
  T.neq(player.ascendantStandingTrainer, rival.ascendantStandingTrainer,
    pair.player .. " player and " .. pair.rival .. " rival stay distinct")
end

local ordinary = overworld.sideTexture({
  game = game, showEnemyTrainer = true, oppClass = "YOUNGSTER",
}, "enemy")
T.eq(ordinary.sourceOwner, "BATTLE_ART_TRAINER_ART",
  "Battle Art TRAINER ART survives KASC CRYSTAL HD mode")
T.eq(ordinary.sourceAsset, "/separate-battle-art/trainer-option.png",
  "ordinary enemy trainer path remains Battle Art-owned")
T.eq(ordinary.sourceIdentity, "BLUE",
  "ordinary trainer selection is not rewritten as the selected rival")

local pokemon = overworld.sideTexture({
  game = game, player = { species = "PIKACHU" },
}, "player")
T.eq(pokemon.sourceOwner, "BATTLE_ART_POKEMON_ART",
  "Battle Art keeps Pokémon art ownership")
T.eq(overworld.__ascendantStandingTrainerOriginal,
  battleArt.originalSideTexture,
  "resolver retains exactly one renderer-owned fallback")

g.newImage = originalNewImage

run.release()
T.finish("extended_characters_battle_art_ownership_test")
