-- Deterministic TEST-RC-002 unit contract.  It drives the real HatchState
-- finalization seam with a tiny in-memory full-colour sprite and verifies that
-- border-paper removal does not discard trueColor ownership.

local function eq(actual, expected, label)
  assert(actual == expected, ("%s: expected %s, got %s")
    :format(label, tostring(expected), tostring(actual)))
end

local pixels = {}
for y = 0, 2 do
  pixels[y] = {}
  for x = 0, 2 do pixels[y][x] = { 1, 1, 1, 1 } end
end
pixels[1][1] = { 0.8, 0.2, 0.1, 1 }

local data = {}
function data:getDimensions() return 3, 3 end
function data:getPixel(x, y)
  local p = pixels[y][x]
  return p[1], p[2], p[3], p[4]
end
function data:setPixel(x, y, r, g, b, a)
  pixels[y][x] = { r, g, b, a }
end

local image = { getDimensions = function() return 3, 3 end }
love = {
  image = { newImageData = function(path)
    eq(path, "/bundled/front.png", "resolver path")
    return data
  end },
  graphics = { newImage = function(received)
    eq(received, data, "cutout ImageData")
    return image
  end },
}

package.loaded["src.pokemon.Sprites"] = {
  path = function(_, species, side, ctx)
    eq(species, "BULBASAUR", "species")
    eq(side, "front", "side")
    eq(ctx.kind, "egg_hatch", "surface")
    return "/bundled/front.png", true
  end,
}
package.loaded["src.core.Sound"] = {
  play = function() end,
  playCry = function() end,
}

local factory = assert(loadfile("egg_hatch_animation.lua"))()
local hatch = factory({}, {})
local state = setmetatable({
  game = { data = {} }, mon = { species = "BULBASAUR" }, frame = 153,
  finalized = false, messagePushed = false,
  finalize = function() return "hatched" end,
}, hatch.State)
state:update()

eq(state.finalized, true, "finalized")
eq(state.sprite, image, "cutout image")
eq(state.spriteTrueColor, true, "trueColor survives flood cutout")
eq(pixels[0][0][4], 0, "border paper alpha")
eq(pixels[1][1][4], 1, "enclosed Pokemon pixel alpha")
eq(hatch.fragmentsVisible(154), true, "fragment burst starts")
eq(hatch.fragmentsVisible(188), true, "fragment travel ends visibly")
eq(hatch.fragmentsVisible(189), false, "fragments cleaned before settle")
eq(hatch.fragmentsVisible(210), false, "message has no loose fragments")

print("egg hatch trueColor/lifecycle test PASS (9 checks)")
