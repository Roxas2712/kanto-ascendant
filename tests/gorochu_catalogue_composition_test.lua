-- Regression for the recorded partner-Summary failure: one native catalogue
-- source, the v1.5 constructor decorator and the final HUD pass must compose
-- to one current Gorochu identity inside the fixed 56x56 slot.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("gorochu catalogue composition")
local check, eq = S.check, S.eq
local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local values = { dex_sprite_style = "original" }
local hudWrap
local mod = {
  path = root,
  exports = {},
  options = { get = function(_, key) return values[key] end },
  content = {
    battle_sprite_scales = { register = function() end },
  },
  events = { on = function() end },
  read = function(_, relative)
    local file = io.open(root .. "/" .. tostring(relative), "rb")
    if not file then return nil end
    local body = file:read("*a")
    file:close()
    return body
  end,
  hooks = { wrap = function(_, name, callback, priority)
    if name == "render.hud" then
      eq(priority, 900, "catalogue composition keeps deterministic priority")
      hudWrap = callback
    end
  end },
}

local function shiny(mon)
  if not mon then return false end
  if mon.shiny == true then return true end
  local dvs = mon.dvs
  return dvs and dvs.defense == 10 and dvs.speed == 10
    and dvs.special == 10 and dvs.attack == 10 or false
end
local shinySystem = { isShiny = shiny }
local visuals = assert(dofile(root .. "/gorochu_visuals.lua"))(mod, {
  species = "GOROCHU", shinySystem = shinySystem,
})
mod.exports.gorochuVisuals = visuals
local overlay = assert(dofile(root .. "/gorochu_catalogue_overlay.lua"))(mod, {
  species = "GOROCHU", shinySystem = shinySystem, visuals = visuals,
})
overlay.register()
check(type(hudWrap) == "function", "catalogue HUD wrapper registered")

local oldLove = _G.love
local draws = {}
_G.love = { graphics = {
  newImage = function(path)
    return {
      path = path,
      setFilter = function(_, min, mag)
        eq(min, "nearest", "current catalogue minification stays nearest")
        eq(mag, "nearest", "current catalogue magnification stays nearest")
      end,
      getDimensions = function() return 56, 56 end,
    }
  end,
  setColor = function() end,
  draw = function(...)
    draws[#draws + 1] = { ... }
  end,
} }

local presentationCalls = 0
local sceneImage = { path = "obsolete-64px-scene-layer" }
local crystal = {
  presentationAnimation = function()
    presentationCalls = presentationCalls + 1
    return { image = sceneImage, trueColor = true }
  end,
  advancePresentation = function(state) return state and state.image end,
}
local v15 = assert(dofile(root .. "/crystal_v15_features.lua"))(mod, {
  crystalAnimation = crystal,
  shinySystem = shinySystem,
  catalogueOwner = visuals,
})

local viewport = {
  gameX = 0, gameY = 0, gameWidth = 160, gameHeight = 144,
}
local function runSummary(mon, variant)
  draws = {}
  local relative = overlay.cataloguePath({
    species = "GOROCHU", kind = "summary", mon = mon,
  })
  eq(relative, "assets/voxel/gorochu/crystal/" .. variant .. "/001.png",
    variant .. " Summary resolves the current primary source")
  local native = { path = mod.path .. "/" .. relative }
  local screen = {
    screenId = "SummaryMenu", mon = mon, sprite = native,
    game = { data = { pokemon = { GOROCHU = { dex = 1026 } } } },
  }
  v15:decorateSummary(screen, mon)
  eq(screen.sprite, native,
    variant .. " Summary rejects the second v1.5 scene layer")
  local game = { stack = { top = function() return screen end } }
  hudWrap(function() end, game, viewport)
  eq(#draws, 1, variant .. " Summary has exactly one final HUD draw")
  eq(draws[1][1].path, native.path,
    variant .. " native and HUD passes use the same source")
  check(not draws[1][1].path:find("/animation/", 1, true),
    variant .. " Summary never reaches the obsolete illustrated family")
  eq(draws[1][2], 64, variant .. " mirrored Summary anchors at slot right")
  eq(draws[1][3], 0, variant .. " Summary remains at slot top")
  eq(draws[1][5], -1, variant .. " Summary is mirrored at native scale")
  eq(draws[1][6], 1, variant .. " Summary height remains 56 pixels")
end

runSummary({ species = "GOROCHU" }, "normal")
runSummary({
  species = "GOROCHU",
  dvs = { attack = 10, defense = 10, speed = 10, special = 10 },
}, "shiny")
eq(presentationCalls, 0,
  "default normal and shiny Summary never invoke the competing decorator")

draws = {}
local dexRelative = overlay.cataloguePath({
  species = "GOROCHU", kind = "dex",
})
local dexNative = { path = mod.path .. "/" .. dexRelative }
local dexScreen = {
  screenId = "DexEntryMenu", def = { id = "GOROCHU" }, sprite = dexNative,
  game = { data = { pokemon = { GOROCHU = { dex = 1026 } } } },
}
v15:decorateDex(dexScreen, "GOROCHU")
eq(dexScreen.sprite, dexNative,
  "default Dex rejects the second v1.5 scene layer")
hudWrap(function() end, {
  stack = { top = function() return dexScreen end },
}, viewport)
eq(#draws, 1, "default Dex has exactly one final HUD draw")
eq(draws[1][1].path, dexNative.path,
  "Dex native and HUD passes use the same current source")
eq(draws[1][2], 8, "Dex art remains at the slot left")
eq(draws[1][3], 4, "Dex art remains at the slot top")

values.dex_sprite_style = "crystal"
local explicit = { game = dexScreen.game, sprite = dexNative }
v15:decorateSummary(explicit, { species = "GOROCHU" })
eq(explicit.sprite, sceneImage,
  "explicit Crystal Dex mode retains its single v1.5 presentation")
eq(presentationCalls, 1,
  "only explicit Crystal mode invokes the v1.5 decorator")

_G.love = oldLove
S.finish()
