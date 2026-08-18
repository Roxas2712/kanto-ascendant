-- Minimal ROM-free input for the modern-ball AnimPlayer bridge contract.
-- Runtime animation data still comes from the imported ROM; this fixture is
-- intentionally just large enough to preserve the four-OAM-tile ball shape.

local ballTiles = {
  { x = 0, y = 0, tile = 0, xflip = false, yflip = false },
  { x = 8, y = 0, tile = 1, xflip = false, yflip = false },
  { x = 0, y = 8, tile = 2, xflip = false, yflip = false },
  { x = 8, y = 8, tile = 3, xflip = false, yflip = false },
}

local moveAnims = {}
local subanims = {}
for index, id in ipairs({
  "TOSS_ANIM",
  "GREATTOSS_ANIM",
  "ULTRATOSS_ANIM",
  "SHAKE_ANIM",
  "BLOCKBALL_ANIM",
}) do
  local subanim = index - 1
  subanims[subanim] = {
    type = "NORMAL",
    blocks = { { block = 0, coord = 0, mode = 4 } },
  }
  moveAnims[id] = {
    seq = { { subanim = subanim, tileset = 0, delay = 1 } },
  }
end

-- Non-capture animations deliberately compile to no sprites. The regression
-- verifies that the modern-ball wrapper delegates both of these unchanged.
moveAnims.POOF_ANIM = { seq = {} }
moveAnims.HIDEPIC_ANIM = { seq = {} }

return {
  moveAnims = moveAnims,
  subanims = subanims,
  frameBlocks = { [0] = ballTiles },
  baseCoords = { [0] = { x = 64, y = 64 } },
  tilesheets = {},
}
