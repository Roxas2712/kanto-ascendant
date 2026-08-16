-- The release ZIP is a mod and must repair the RC25 app's transparent
-- true-colour world rectangles without requiring the user to replace the
-- executable.

local root = assert(os.getenv("KA_MOD_ROOT"), "KA_MOD_ROOT required")
local world = true
local rects, redraws = {}, {}
local PaletteFX = {
  spriteRedrawPassActive = function() return world end,
  spriteRedraws = function() return redraws end,
  markTrueColor = function(x, y, w, h)
    rects[#rects + 1] = { x, y, w, h }
  end,
  markSpriteRedraw = function(image, quad, x, y, sx)
    redraws[#redraws + 1] = { image, quad, x, y, sx }
  end,
}
local SpriteRenderer = {
  STAND = { down = 0, up = 1, left = 2, right = 2 },
  WALK = { down = 3, up = 4, left = 5, right = 5 },
}
function SpriteRenderer.draw(self, px, py, camX, camY)
  PaletteFX.markTrueColor(math.floor(px-camX),
    math.floor(py-camY)-4, 16, 16)
end
function SpriteRenderer.drawTile(self, path, x, y)
  PaletteFX.markTrueColor(x, y, 16, 8)
  self.tileQuads = self.tileQuads or {}
  self.tileQuads[path] = "tile-quad"
end
local tileImage = {}
package.loaded["src.render.PaletteFX"] = PaletteFX
package.loaded["src.render.SpriteRenderer"] = SpriteRenderer
package.loaded["src.render.Assets"] = {
  image = function() return tileImage end,
}

local compat = assert(loadfile(root .. "/truecolor_world_compat.lua"))()()
local ok, kind = compat.install()
assert(ok and kind == "compat", "legacy renderer did not install compat")

local image, quad = {}, {}
local renderer = {
  def = { trueColor = true, frames = 6, walker = true },
  image = image,
  frames = { [0]=quad, [1]=quad, [2]=quad, [3]=quad, [4]=quad, [5]=quad },
}
SpriteRenderer.draw(renderer, 40, 52, 8, 4, "right", 1, false, false)
assert(#rects == 0, "world true-colour rectangle was not suppressed")
assert(#redraws == 1 and redraws[1][1] == image
    and redraws[1][2] == quad and redraws[1][3] == 48
    and redraws[1][4] == 44 and redraws[1][5] == -1,
  "world sprite was not replayed with source alpha and exact geometry")

SpriteRenderer.drawTile(renderer, "fish.png", 12, 20, false)
assert(#rects == 0, "world pose-tile rectangle was not suppressed")
assert(#redraws == 2 and redraws[2][1] == tileImage
    and redraws[2][2] == "tile-quad" and redraws[2][3] == 12
    and redraws[2][4] == 20 and redraws[2][5] == 1,
  "world pose tile was not replayed with source alpha")

world = false
SpriteRenderer.draw(renderer, 40, 52, 8, 4, "down", 0, false, false)
assert(#rects == 1 and #redraws == 2,
  "non-world/UI true-colour behavior was changed")

print("truecolor_world_mod_compat_test: PASS")
