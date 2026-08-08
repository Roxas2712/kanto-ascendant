-- Battle Art Voxel 1.7.6 kept the public OverworldBattle API but renamed its
-- export to BATTLE_ART_VOXEL_FORK. Mega presentation must therefore retain
-- the Voxel front-card path and suppress the classic rear overlay.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("battle art voxel compatibility")
local check, eq = S.check, S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local saved, wrapped = {}, {}
local fakeMod = {
  path = "/fake/kanto-ascendant",
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  options = {
    get = function(_, key)
      if key == "mega_evolution" then return true end
      if key == "kanto_crystal_art" then return true end
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
  read = function() return nil end,
}

local mega = assert(dofile(modDir .. "/mega_evolution.lua")(fakeMod))
local apiCalls = 0
local overworldBattle = {
  wantsFront = function() return true end,
  backPinned = function() return false end,
  sideTexture = function(_, side) return { side = side } end,
}
local game = {
  data = { pokemon = {} },
  mods = {
    exports = {
      BATTLE_ART_VOXEL_FORK = {
        lib = {
          require = function(name)
            eq(name, "OverworldBattle",
              "Battle Art Voxel exposes the documented companion API")
            apiCalls = apiCalls + 1
            return overworldBattle
          end,
        },
      },
    },
  },
}
local battleState = { update = function() end, finish = function() end }

mega.install(game, { battleState = battleState })

eq(apiCalls, 1,
  "Mega compatibility resolves Battle Art Voxel's renamed export")
eq(overworldBattle.kantoAscendantMegaAnchorHook, true,
  "Mega Voxel side-texture hook installs through Battle Art Voxel 1.7.6")
eq(mega.rearOverlayAllowed({ dramaticShapeShot = true }), false,
  "a front-facing Voxel battle never draws the obsolete Mega rear overlay")
check(wrapped["pokemon.sprite"] ~= nil,
  "Mega sprite routing remains registered alongside the Voxel compatibility")

S.finish()
