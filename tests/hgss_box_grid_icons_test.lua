-- Focused 6.5.7 contract for the optional HGSS-style right-hand Box grid.
-- The large selected-Pokemon preview must stay on the existing front-sprite
-- renderer, while only the 20 right-hand cells may use frame zero of a
-- bundled 16x96 walking sheet.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local optionValues = {
  modern_storage_ui = true,
  box_grid_icon_style = "current",
  ascendant_useful_bag = true,
  ascendant_bag_mode = "pockets",
  fast_box_switch = true,
}
local readable = {
  ["vendor/wilds_1_12_2/assets/bundled_runtime/followsprites_runtime/025-normal.png"] = true,
  ["vendor/wilds_1_12_2/assets/bundled_runtime/followsprites_runtime/025-shiny.png"] = true,
  ["vendor/wilds_1_12_2/assets/bundled_runtime/followsprites_runtime/424-normal.png"] = true,
}
local draws, quads, imageLoads = {}, {}, {}

love = { graphics = {} }
function love.graphics.setColor() end
function love.graphics.rectangle() end
function love.graphics.circle() end
function love.graphics.arc() end
function love.graphics.polygon() end
function love.graphics.newImage(path)
  imageLoads[#imageLoads + 1] = path
  local walker = tostring(path):find("followsprites_runtime", 1, true) ~= nil
  return {
    path = path,
    getWidth = function() return walker and 16 or 56 end,
    getHeight = function() return walker and 96 or 56 end,
  }
end
function love.graphics.newQuad(x, y, w, h, iw, ih)
  local quad = { x = x, y = y, w = w, h = h, iw = iw, ih = ih }
  quads[#quads + 1] = quad
  return quad
end
function love.graphics.draw(image, ...)
  draws[#draws + 1] = { image = image, args = { ... } }
end

package.preload["src.render.Font"] = function()
  return {
    width = function(text) return #tostring(text or "") * 8 end,
    split = function(text)
      local out = {}
      for i = 1, #text do out[i] = { from = i, to = i } end
      return out
    end,
    spansFitting = function(spans, width)
      return math.min(#spans, math.floor(width / 8))
    end,
    draw = function() end,
    drawCode = function() end,
  }
end
package.preload["src.pokemon.Boxes"] = function()
  return {
    active = function(save) return save.box end,
    ensure = function(save) return { save.box } end,
    COUNT = 12,
  }
end
package.preload["src.core.Strings"] = function()
  return function(pattern, ...) return string.format(pattern, ...) end
end
package.preload["src.ui.Theme"] = function()
  return { cursor = 1, cursorHollow = 2 }
end
package.preload["src.pokemon.Sprites"] = function()
  return { path = function(_, species, _, ctx)
    local variant = ctx and ctx.shiny == true and "shiny" or "normal"
    return "existing-front/" .. variant .. "/"
      .. tostring(species) .. ".png"
  end }
end
package.preload["src.render.PaletteFX"] = function()
  return { trueColorZone = function() return {} end }
end

local ListMenu = { new = function(game, title, items)
  return { game = game, title = title, items = items, index = 1 }
end }
local BoxMenu = { new = function(game) return { game = game, items = {} } end }
local BagMenu = { new = function(game) return { game = game } end }
local Menu = { new = function(game, items) return { game = game, items = items } end }
package.preload["src.ui.ListMenu"] = function() return ListMenu end
package.preload["src.ui.BoxMenu"] = function() return BoxMenu end
package.preload["src.ui.BagMenu"] = function() return BagMenu end
package.preload["src.ui.Menu"] = function() return Menu end

local runtime = {
  sourceDex = function(mon)
    if mon and mon.species == "AMBIPOM" then return 424 end
    return nil
  end,
}
local mod = {
  id = "kanto_ascendant",
  exports = {
    extendedSpeciesRuntime = runtime,
    shinySystem = { isShiny = function(mon)
      return mon.shiny == true or mon.dvShiny == true
    end },
  },
  options = { get = function(_, key) return optionValues[key] end },
  assets = { path = function(_, relative) return "LOAD:" .. relative end },
  read = function(_, relative) return readable[relative] and "png" or nil end,
  find = function() return nil end,
}

assert(loadfile(root .. "/modern_storage_ui.lua"))()(mod, {
  i18n = {
    isGerman = function() return false end,
    text = function(en) return en end,
  },
})
local ui = assert(mod.exports.modernStorageUi, "storage export missing")

local data = { pokemon = {
  PIKACHU = { name = "PIKACHU", dex = 25 },
  AMBIPOM = {
    name = "AMBIPOM", dex = 261, internalRuntimeDex = 261, sourceDex = 424,
  },
  GOROCHU = { name = "GOROCHU", dex = 1026 },
  MISSING = { name = "MISSING", dex = 999 },
} }
local box, items = {}, {}
for i = 1, 21 do
  box[i] = { species = "PIKACHU", level = 12 }
  items[i] = { value = i, label = "PIKACHU" }
end
local savedOptions = {}
local game = {
  data = data,
  save = {
    box = box,
    currentBox = 1,
    options = { modOptions = { kanto_ascendant = savedOptions } },
  },
}
local menu = ListMenu.new(game, "WITHDRAW POKéMON", items)
assert(menu.__ascendantBoxGrid == true, "Box grid wrapper not installed")

local function resetDraws()
  draws, quads, imageLoads = {}, {}, {}
end
local function walkerDraws()
  local out = {}
  for _, draw in ipairs(draws) do
    if draw.image.path:find("followsprites_runtime", 1, true) then
      out[#out + 1] = draw
    end
  end
  return out
end
local function frontDraws()
  local out = {}
  for _, draw in ipairs(draws) do
    if draw.image.path:find("existing%-front/") then out[#out + 1] = draw end
  end
  return out
end

-- Missing save value and schema default both preserve the current renderer.
resetDraws()
menu:draw()
assert(optionValues.box_grid_icon_style == "current", "test default drifted")
assert(#walkerDraws() == 0, "default unexpectedly drew HGSS walkers")
local currentFront = frontDraws()
assert(#currentFront == 21, "default must draw one left preview plus 20 old grid icons")
local leftArgs = currentFront[1].args
assert(leftArgs[1] >= 7 and leftArgs[1] < 67
    and leftArgs[2] >= 24 and leftArgs[2] < 69,
  "large left preview escaped its existing 56x45 left panel")

-- The option is live: changing the save bucket affects the next draw only.
savedOptions.box_grid_icon_style = "hgss_walker"
resetDraws()
menu:draw()
local walkers = walkerDraws()
local hgssFront = frontDraws()
assert(#walkers == 20, "only the 20 right-hand cells should use walkers")
assert(#hgssFront == 1, "opt-in must retain exactly the existing large left preview")
assert(hgssFront[1].args[1] == leftArgs[1]
    and hgssFront[1].args[2] == leftArgs[2]
    and hgssFront[1].args[4] == leftArgs[4]
    and hgssFront[1].args[5] == leftArgs[5],
  "large left preview geometry changed under the grid-only option")
assert(#quads == 1 and quads[1].x == 0 and quads[1].y == 0
    and quads[1].w == 16 and quads[1].h == 16
    and quads[1].iw == 16 and quads[1].ih == 96,
  "walker must use frame zero of a 16x96 six-frame sheet")
local positions = {}
for _, draw in ipairs(walkers) do
  local quad, x, y = draw.args[1], draw.args[2], draw.args[3]
  assert(quad == quads[1], "right grid did not reuse frame-zero Quad")
  assert(x >= 71 and x <= 139 and y >= 27 and y <= 96,
    "walker escaped the right 5x4 grid")
  positions[x .. ":" .. y] = true
end
local positionCount = 0
for _ in pairs(positions) do positionCount = positionCount + 1 end
assert(positionCount == 20, "5x4 grid did not render 20 distinct cells")

-- The private runtime identity must win over the colliding private slot 261.
local ambipomPath, variant, dex = ui.boxGridWalkerRelative(game, {
  species = "AMBIPOM",
})
assert(dex == 424 and variant == "normal"
    and ambipomPath:match("/424%-normal%.png$")
    and not ambipomPath:match("/261%-normal%.png$"),
  "Ambipom used private slot 261 instead of sourceDex 424")

local shinyPath = ui.boxGridWalkerRelative(game, {
  species = "PIKACHU", shiny = true,
})
assert(shinyPath and shinyPath:match("/025%-shiny%.png$"),
  "shiny Pokemon did not select the exact shiny counterpart")
local dvShinyPath = ui.boxGridWalkerRelative(game, {
  species = "PIKACHU", dvShiny = true,
})
assert(dvShinyPath and dvShinyPath:match("/025%-shiny%.png$"),
  "DV-derived shiny Pokemon did not select the shiny counterpart")
local baseFormPath = ui.boxGridWalkerRelative(game, {
  species = "PIKACHU", form = 0,
})
assert(baseFormPath and baseFormPath:match("/025%-normal%.png$"),
  "numeric base-form marker 0 must not force a false fallback")

local gorochuPath = ui.boxGridWalkerRelative(game, { species = "GOROCHU" })
assert(gorochuPath == nil, "Gorochu must not borrow an HGSS species identity")
local formPath = ui.boxGridWalkerRelative(game, {
  species = "PIKACHU", form = "cosplay",
})
assert(formPath == nil, "unsupported forms must use the established grid icon")
local missing = ui.boxGridWalkerAsset(game, { species = "MISSING" })
assert(missing == nil, "missing runtime sheet must fail closed")

-- A missing/Gorochu sheet falls back to the exact old drawMonImage path.
box[1] = { species = "GOROCHU", level = 50 }
resetDraws()
menu:draw()
assert(#walkerDraws() == 19, "Gorochu should be the sole walker fallback")
local fallbackFront = frontDraws()
assert(#fallbackFront == 2
    and fallbackFront[1].image.path:match("GOROCHU%.png$")
    and fallbackFront[2].image.path:match("GOROCHU%.png$"),
  "Gorochu did not retain both existing left-preview and grid renderers")

-- The fallback preview/grid cache must use the same DV-aware shiny
-- authority as the production sprite resolver. A normal Gorochu loaded
-- first must never contaminate a later true-DV shiny with mon.shiny unset.
box[1] = { species = "GOROCHU", level = 50, dvShiny = true }
resetDraws()
menu:draw()
local shinyGorochuDraws = {}
for _, draw in ipairs(frontDraws()) do
  if draw.image.path:match("GOROCHU%.png$") then
    shinyGorochuDraws[#shinyGorochuDraws + 1] = draw
  end
end
assert(#shinyGorochuDraws == 2,
  "DV-shiny Gorochu must retain both preview and grid fallback draws")
for _, draw in ipairs(shinyGorochuDraws) do
  assert(draw.image.path:find("existing-front/shiny/GOROCHU.png", 1, true),
    "normal Box cache contaminated a DV-shiny Gorochu")
end

print("PASS HGSS Box-grid icons: default-safe, live, right 5x4 only, sourceDex, shiny, fallback")
