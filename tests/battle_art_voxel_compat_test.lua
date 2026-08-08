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
      if key == "kanto_crystal_art" then return false end
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
}

local mega = assert(dofile(modDir .. "/mega_evolution.lua")(fakeMod))
local apiCalls = 0
local front = true
local nativeCanvas = {
  getWidth = function() return 160 end,
  getHeight = function() return 144 end,
}
local overworldBattle = {
  wantsFront = function() return front end,
  backPinned = function() return false end,
  sideTexture = function(_, side)
    return { side = side, canvas = nativeCanvas, ax = 80, ay = 96 }
  end,
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
  "Mega compatibility resolves Battle Art Voxel's renamed export")
eq(overworldBattle.kantoAscendantMegaAnchorHook, true,
  "Mega Voxel side-texture hook installs through Battle Art Voxel 1.7.6")
eq(mega.rearOverlayAllowed({ dramaticShapeShot = true }), false,
  "a staged Battle Art fight never draws the obsolete Mega rear overlay")
eq(mega.rearOverlayAllowed({}), true,
  "a non-staged Battle Art fallback keeps Kanto's normal 2D Mega overlay")
check(wrapped["pokemon.sprite"] ~= nil,
  "Mega sprite routing remains registered alongside the Voxel compatibility")

local battle = {
  player = { mon = { species = "RAICHU", _ascMegaForm = "RAICHU_X" } },
  enemy = { mon = { species = "RAICHU", _ascMegaForm = "RAICHU_X" } },
}
local player = overworldBattle.sideTexture(battle, "player")
eq(player.kantoAscendantMegaSource,
  "assets/mega_gen1_runtime/mega_raichu_x_front.png",
  "front-view player Mega uses Kanto's dedicated front master")
eq(player.ax, 115,
  "supersampled Mega canvas reports its own horizontal BATTLE_ART anchor")
eq(player.ay, 138,
  "supersampled Mega canvas reports its own vertical BATTLE_ART anchor")

front = false
local back = overworldBattle.sideTexture(battle, "player")
eq(back.kantoAscendantMegaSource,
  "assets/mega_gen1_runtime/mega_raichu_x_back.png",
  "world-space BACK SPRITES uses Kanto's dedicated rear Mega master")

_G.love = oldLove

S.finish()
