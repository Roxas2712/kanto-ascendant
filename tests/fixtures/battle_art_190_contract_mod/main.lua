-- Minimal no-asset fixture for KASC's Battle Art ownership contract. It is
-- not a redistributed renderer; tests use it only to model the public 1.9.2
-- export and prove that KASC changes only explicit selected character
-- identities while Battle Art retains its stage, HUD and ordinary art.

return function(mod)
  local function sideTexture(battle, side)
    if side == "player" and battle and battle.showPlayerBack then
      return {
        sourceOwner = "BATTLE_ART_PLAYER_ART",
        sourceAsset = "/separate-battle-art/player-option.png",
        sourceIdentity = "RED",
      }
    end
    if side == "enemy" and battle and battle.showEnemyTrainer then
      return {
        sourceOwner = "BATTLE_ART_TRAINER_ART",
        sourceAsset = "/separate-battle-art/trainer-option.png",
        sourceIdentity = "BLUE",
      }
    end
    return {
      sourceOwner = "BATTLE_ART_POKEMON_ART",
      sourceAsset = "/separate-battle-art/pokemon-option.png",
    }
  end

  local modules = {
    AntiAlias = {}, BattleCam = {}, FirstPerson = {}, Mat4 = {},
    OverworldBattle = { sideTexture = sideTexture },
    ShadowMap = {}, SpriteBillboards = {}, TerrainAtlas = {},
    Voxel3D = {}, VoxelScene = {}, VoxelState = {},
    VoxelMeshDisk = {
      available = function() return false end,
      staticEligible = function() return false end,
      saveTerrain = function() return false end,
      saveAux = function() return false end,
    },
  }
  local lib = { mod = mod, path = mod.path }
  function lib.require(name) return modules[name] end

  mod.exports.version = "1.9.2"
  mod.exports.originalSideTexture = sideTexture
  mod.exports.overworldBattle = modules.OverworldBattle
  mod.exports.lib = lib
  mod.exports.battleStage = {
    apiVersion = 1,
    sourceModId = "BATTLE_ART_VOXEL_FORK",
    ownership = { hud = true, animationProjection = true },
    state = function() return { staged = true } end,
  }
  mod.exports.battlePresentation = {
    apiVersion = 1,
    sourceModId = "BATTLE_ART_VOXEL_FORK",
    suppressHook = "battle.presentation.suppress_native.v1",
  }
end
