-- Gorochu's high-detail Voxel source and six-pose field walker must remain
-- independent from its intentional 56 px Crystal battle cards.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("gorochu visuals")
local check, eq = S.check, S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local function pngDimensions(relative)
  local handle = assert(io.open(modDir .. "/" .. relative, "rb"), relative)
  local header = handle:read(24)
  handle:close()
  check(header and #header == 24 and header:sub(1, 8) == "\137PNG\r\n\26\n",
    relative .. " is a PNG")
  local function integer(offset)
    local a, b, c, d = header:byte(offset, offset + 3)
    return a * 16777216 + b * 65536 + c * 256 + d
  end
  return integer(17), integer(21)
end

local files = {}
for _, side in ipairs({ "front", "back" }) do
  for _, shiny in ipairs({ false, true }) do
    local suffix = shiny and "_shiny" or ""
    files[("assets/voxel/gorochu/gorochu_%s%s.png")
      :format(side, suffix)] = { 96, 96 }
  end
end
files["assets/followers/gorochu.png"] = { 96, 16 }
files["assets/followers/shiny/gorochu.png"] = { 96, 16 }
files["assets/followers_runtime/normal/follower_GOROCHU.png"] = { 16, 96 }
files["assets/followers_runtime/shiny/follower_GOROCHU.png"] = { 16, 96 }

for relative, size in pairs(files) do
  local width, height = pngDimensions(relative)
  eq(width, size[1], relative .. " has the expected width")
  eq(height, size[2], relative .. " has the expected height")
end

local readable = {}
for relative in pairs(files) do readable[relative] = true end
local fakeMod = {
  path = "/fake/kanto-ascendant",
  read = function(_, relative)
    return readable[relative] and "png" or nil
  end,
}
local shinySystem = {
  isShiny = function(mon) return mon and mon.shiny == true end,
}
local visuals = assert(
  dofile(modDir .. "/gorochu_visuals.lua")(fakeMod, {
    species = "GOROCHU",
    shinySystem = shinySystem,
  }))

eq(visuals.relativePath({ species = "GOROCHU" }, "front"),
  "assets/voxel/gorochu/gorochu_front.png",
  "normal Voxel front resolves from the dedicated master")
eq(visuals.relativePath({ species = "GOROCHU", shiny = true }, "front"),
  "assets/voxel/gorochu/gorochu_front_shiny.png",
  "shiny Voxel front resolves independently")
eq(visuals.relativePath({ species = "GOROCHU" }, "back"),
  "assets/voxel/gorochu/gorochu_back.png",
  "BACK SPRITES mode owns a high-detail rear master")
check(not visuals.relativePath(
  { species = "GOROCHU" }, "front"):find("crystal", 1, true),
  "Voxel never resolves through the 56px Crystal card")

local pinned = false
local overworldBattle = {
  sideTexture = function(_, side)
    return { side = side, ax = 80, ay = 96 }
  end,
  backPinned = function() return pinned end,
}
local game = {
  mods = {
    exports = {
      DRAMATIC_SHAPE = {
        lib = {
          require = function(name)
            eq(name, "OverworldBattle",
              "Gorochu installs through Dramatic Shape's public module")
            return overworldBattle
          end,
        },
      },
    },
  },
}

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
        width = width,
        height = height,
        setFilter = function() end,
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

eq(visuals.install(game), true,
  "the dedicated Voxel side-texture hook installs")
local battle = {
  player = {
    mon = { species = "GOROCHU" },
    __ascendantCrystalAnimation = { frame = 4 },
  },
  enemy = { mon = { species = "GOROCHU", shiny = true } },
}
local player = overworldBattle.sideTexture(battle, "player")
eq(player.kantoAscendantGorochuSupersampled, true,
  "player Gorochu receives a supersampled Voxel texture")
eq(player.kantoAscendantGorochuSource,
  "assets/voxel/gorochu/gorochu_front.png",
  "camera-facing player uses the approved normal front")
eq(player.canvas.width, 230, "Voxel side texture is 230 px wide")
eq(player.canvas.height, 207, "Voxel side texture is 207 px high")
eq(player.kantoAscendantGorochuAnimationFrame, 4,
  "Voxel master follows the live Crystal animation clock")

local enemy = overworldBattle.sideTexture(battle, "enemy")
eq(enemy.kantoAscendantGorochuSource,
  "assets/voxel/gorochu/gorochu_front_shiny.png",
  "camera-facing enemy selects the shiny front master")

pinned = true
local back = overworldBattle.sideTexture(battle, "player")
eq(back.kantoAscendantGorochuSource,
  "assets/voxel/gorochu/gorochu_back.png",
  "BACK SPRITES mode selects the approved rear master")
eq(back.kantoAscendantGorochuSide, "back",
  "the side-texture marker records the pinned rear view")
eq(visuals.install(game), true, "the Voxel hook is idempotent")

_G.love = oldLove

S.finish()
