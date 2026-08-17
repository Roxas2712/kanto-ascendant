-- Exact upstream Battle Art 1.9.0 retains full ownership of its separately
-- installed sprites/trainers/animations/options. KASC consumes only a local
-- closed OverworldBattle facade: normal MODDED cards remain byte-for-byte the
-- renderer result, while an active Ascendant form may redraw its own master
-- into the renderer-owned card/camera placement.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("voxel renderer compatibility")
local check, eq = S.check, S.eq
local Pipelines = require("src.render.Pipelines")
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local saved, wrapped, externalMods = {}, {}, {}
local crystalArt, crystalAnimation = false, true
local fakeMod = {
  path = "/fake/kanto-ascendant",
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  options = {
    get = function(_, key)
      if key == "mega_evolution" then return true end
      if key == "kanto_crystal_art" then return crystalArt end
      if key == "crystal_animation" then return crystalAnimation end
      return nil
    end,
  },
  content = {
    items = { register = function() end },
    battle_sprite_scales = { register = function() end },
  },
  hooks = {
    wrap = function(_, name, callback) wrapped[name] = callback end,
  },
  events = { on = function() end },
  ui = { insertBefore = function(_, rows) return rows end },
  read = function() return true end,
  find = function(id) return externalMods[id] end,
}

local voxelRenderer = assert(dofile(modDir .. "/voxel_renderer_compat.lua")(fakeMod))
local mega = assert(dofile(modDir .. "/mega_evolution.lua")(fakeMod, {
  voxelRenderer = voxelRenderer,
  animationData = assert(dofile(modDir .. "/mega_animation_data.lua")),
}))
local apiCalls = 0
local front = true
local sideTextureCalls = 0
local nativeCanvas = {
  getWidth = function() return 160 end,
  getHeight = function() return 144 end,
}
local overworldBattle = {
  wantsFront = function() return front end,
  backPinned = function() return false end,
  sideTexture = function(_, side)
    sideTextureCalls = sideTextureCalls + 1
    return {
      side = side, canvas = nativeCanvas, ax = 80, ay = 96,
      sourceOwner = "BATTLE_ART_MODDED",
      sourceAsset = "/separately-installed/user-selected-sprite.png",
    }
  end,
}
local rawBattleLib = {
  mod = { id = "BATTLE_ART_VOXEL_FORK", assets = {}, options = {} },
  path = "/separately-installed/battle-art",
}
rawBattleLib.require = function(name)
  if name == "OverworldBattle" then
    eq(name, "OverworldBattle",
      "Battle Art exposes the documented companion API")
    apiCalls = apiCalls + 1
    return overworldBattle
  end
  return { private = name }
end
local battleStage = {
  apiVersion = 1, sourceModId = "BATTLE_ART_VOXEL_FORK",
  ownership = { hud = true, animationProjection = true },
  state = function(expected)
    return expected and { staged = true, battle = expected,
      ownership = { battlers = true, animationProjection = true } } or nil
  end,
}
externalMods.BATTLE_ART_VOXEL_FORK = {
  id = "BATTLE_ART_VOXEL_FORK",
  version = "1.9.3",
  exports = {
    version = "1.9.3",
    lib = rawBattleLib,
    battleStage = battleStage,
    battlePresentation = {
      apiVersion = 1, sourceModId = "BATTLE_ART_VOXEL_FORK",
      suppressHook = "battle.presentation.suppress_native.v1",
    },
  },
}
local game = { data = { pokemon = {} } }
local originalBattleStateModule = package.loaded["src.battle.BattleState"]
local battleState = {
  update = function() end,
  finish = function() end,
  makeBattler = function(_, mon)
    return { sprite = { frame = mon._ascMegaAnimationFrame } }
  end,
}
package.loaded["src.battle.BattleState"] = battleState

-- Product code intentionally gives a prepared DRAMALESS shot no ownership
-- while the Voxel display pipeline is OFF.  Install the same minimal active
-- pipeline contract the real renderer registers; otherwise this test would
-- be asserting Voxel front-card behavior while exercising the classic 2D
-- branch.
Pipelines.install({ render_pipelines = {
  voxel = {
    id = "voxel", levels = { "OFF", "ON" },
    drawWorld = function() end,
  },
} })
eq(Pipelines.setLevel("voxel", 1), 1,
  "the compatibility fixture activates the real Voxel pipeline seam")

local oldLove = _G.love
local currentCanvas
_G.love = {
  graphics = {
    newImage = function(path)
      return {
        path = path,
        setFilter = function() end,
        getDimensions = function() return 96, 96 end,
      }
    end,
    newCanvas = function(width, height)
      return {
        width = width, height = height,
        setFilter = function() end,
        getWidth = function(self) return self.width end,
        getHeight = function(self) return self.height end,
      }
    end,
    getCanvas = function() return currentCanvas end,
    setCanvas = function(value) currentCanvas = value end,
    getBlendMode = function() return "alpha", "alphamultiply" end,
    setBlendMode = function() end,
    getColor = function() return 1, 1, 1, 1 end,
    setColor = function() end,
    clear = function() end,
    draw = function() end,
  },
}

mega.install(game, { battleState = battleState })

eq(apiCalls, 1,
  "Mega compatibility resolves Battle Art's maintained export once")
eq(overworldBattle.kantoAscendantMegaAnchorHook, true,
  "Mega Voxel side-texture hook installs through the renderer")
eq(mega.rearOverlayAllowed({ dramaticShapeShot = true }), false,
  "a staged Voxel fight never draws the obsolete Mega rear overlay")
eq(mega.rearOverlayAllowed({}), true,
  "a non-staged renderer fallback keeps Kanto's normal 2D Mega overlay")
check(wrapped["pokemon.sprite"] ~= nil,
  "Mega sprite routing remains registered alongside the Voxel compatibility")

local battle = {
  player = { mon = { species = "RAICHU", _ascMegaForm = "RAICHU_X" } },
  enemy = { mon = { species = "RAICHU", _ascMegaForm = "RAICHU_X" } },
}
local ordinary = overworldBattle.sideTexture({
  player = { mon = { species = "PIKACHU" } },
  enemy = { mon = { species = "EEVEE" } },
}, "player")
eq(ordinary.sourceOwner, "BATTLE_ART_MODDED",
  "ordinary species card remains owned by Battle Art MODDED selection")
eq(ordinary.sourceAsset,
  "/separately-installed/user-selected-sprite.png",
  "KASC does not replace or copy Battle Art's selected sprite asset")

local safeExport, rendererId, resolverError, safeHandle, resolverReceipt =
  voxelRenderer.resolve(game)
eq(rendererId, "BATTLE_ART_VOXEL_FORK",
  "resolver receipt retains Battle Art identity")
eq(resolverError, nil, "exact Battle Art package resolves cleanly")
check(safeExport ~= externalMods.BATTLE_ART_VOXEL_FORK.exports,
  "KASC exposes a local facade instead of the foreign export")
eq(safeExport.lib.mod, nil,
  "local facade exposes no Battle Art asset/options authority")
check(safeExport.battleStage ~= battleStage,
  "Battle Art stage data is copied into KASC's read-only facade")
eq(safeExport.battleStage.state(battle).ownership.animationProjection, true,
  "move-animation projection remains renderer-owned")
eq(safeHandle.exports, safeExport,
  "safe renderer handle does not leak the generic Battle Art loader")
eq(resolverReceipt.export, "kasc-local-allowlist/v1",
  "compatibility receipt names the closed local facade")
eq(resolverReceipt.repository, nil,
  "real 0.1.90 handle shape does not forge repository attestation")
eq(safeHandle.github, nil,
  "local safe handle contains no invented repository authority")
eq(rawBattleLib.mod.id, "BATTLE_ART_VOXEL_FORK",
  "foreign Battle Art export remains byte-structure owned and unmodified")

local player = overworldBattle.sideTexture(battle, "player")
eq(player.kantoAscendantMegaSource,
  "assets/mega_gen1_runtime/mega_raichu_x_front.png",
  "front-view player Mega uses Kanto's dedicated front master")
eq(player.canvas.width, 160,
  "Mega card retains the renderer's native canvas width")
eq(player.canvas.height, 144,
  "Mega card retains the renderer's native canvas height")
eq(player.ax, 80,
  "Mega card retains the renderer's horizontal anchor")
eq(player.ay, 96,
  "Mega card retains the renderer's vertical anchor")

front = false
local back = overworldBattle.sideTexture(battle, "player")
eq(back.kantoAscendantMegaSource,
  "assets/mega_gen1_runtime/mega_raichu_x_back.png",
  "world-space BACK SPRITES uses Kanto's dedicated rear Mega master")

-- Battle Art may retain the canvas returned by sideTexture instead of asking
-- for a new texture every frame. Advancing a Mega animation must therefore
-- repaint that retained renderer-owned canvas at the public sideTexture seam.
crystalArt = true
front = true
local animatedBattle = {
  data = {}, game = { data = {}, save = {} },
  enemy = {
    isPlayer = false,
    sprite = {},
    mon = { species = "CHARIZARD", _ascMegaForm = "CHARIZARD_X" },
  },
  showEnemyTrainer = false,
  enemySendingOut = false,
}
overworldBattle.sideTexture(animatedBattle, "enemy")
local callsBeforeAnimation = sideTextureCalls
mega.updateAnimations(animatedBattle, 1.0)
check(tonumber(animatedBattle.enemy.mon._ascMegaAnimationFrame) ~= nil,
  "Battle Art 1.9.3 Mega animation advances its authored frame")
check(sideTextureCalls > callsBeforeAnimation,
  "Battle Art 1.9.3 retained Mega canvas is repainted after frame advance")

_G.love = oldLove
package.loaded["src.battle.BattleState"] = originalBattleStateModule
Pipelines.install()

S.finish()
