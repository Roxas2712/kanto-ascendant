-- Contract for the selectable FireRed/LeafGreen PC presentation.
-- The established KASC renderer remains live, and a missing/bad source atlas
-- must make the FireRed choice fail closed to that renderer.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local options = {
  modern_storage_ui = true,
  pc_interface_style = "ascendant",
  box_grid_icon_style = "current",
  fast_box_switch = true,
  ascendant_useful_bag = false,
  pokemon_sprite_style = "crystal",
  sprite_style_box = true,
}
local atlasPath = "assets/ui/frlg_pc/interface.png"
local draws, quads, handPolygons = {}, {}, 0
local loadedImagePaths, spriteRequests = {}, {}

love = { graphics = {} }
function love.graphics.setColor() end
function love.graphics.rectangle() end
function love.graphics.circle() end
function love.graphics.arc() end
function love.graphics.polygon(mode)
  if mode == "fill" then handPolygons = handPolygons + 1 end
end
function love.graphics.push() end
function love.graphics.pop() end
function love.graphics.scale() end
function love.graphics.translate() end
function love.graphics.newImage(path)
  loadedImagePaths[#loadedImagePaths + 1] = tostring(path)
  local atlas = tostring(path):find("frlg_pc/interface.png", 1, true) ~= nil
  return {
    path = path,
    getWidth = function() return atlas and 641 or 56 end,
    getHeight = function() return atlas and 1240 or 56 end,
    setFilter = function(self, min, mag) self.filter = min .. ":" .. mag end,
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
      for i = 1, #tostring(text or "") do
        out[i] = { from = i, to = i }
      end
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
    COUNT = 12,
    CAPACITY = 20,
    active = function(save) return save.boxes[save.currentBox] end,
    ensure = function(save) return save.boxes end,
  }
end
package.preload["src.core.Strings"] = function()
  return function(pattern, ...) return string.format(pattern, ...) end
end
package.preload["src.ui.Theme"] = function()
  return { cursor = 1, cursorHollow = 2 }
end
package.preload["src.pokemon.Sprites"] = function()
  return { path = function(_, species, side, ctx)
    spriteRequests[#spriteRequests + 1] = {
      species = species, side = side, ctx = ctx,
    }
    local variant = ctx and ctx.mon and ctx.mon.shiny and "shiny" or "normal"
    return ("crystal_animated/front/%s/25/001.png"):format(variant)
  end }
end
package.preload["src.render.PaletteFX"] = function()
  return { trueColorZone = function() return {} end }
end

local ListMenu = { new = function(game, title, items)
  return { game = game, title = title, items = items, index = 1, scroll = 0 }
end }
local BoxMenu = { new = function(game)
  return { game = game, index = 1, update = function() end, items = {
    { label = "WITHDRAW POKéMON" }, { label = "DEPOSIT POKéMON" },
    { label = "RELEASE POKéMON" }, { label = "CHANGE BOX" },
    { label = "SEE YA!" },
  } }
end }
local BagMenu = { new = function(game) return { game = game } end }
local Menu = { new = function(game, items)
  return { game = game, items = items, index = 1 }
end }
local TextBox = { new = function(game)
  return { game = game, draw = function() end }
end }
local ChoiceBox = { new = function(game)
  return { game = game, draw = function() end }
end }
package.preload["src.ui.ListMenu"] = function() return ListMenu end
package.preload["src.ui.BoxMenu"] = function() return BoxMenu end
package.preload["src.ui.BagMenu"] = function() return BagMenu end
package.preload["src.ui.Menu"] = function() return Menu end
package.preload["src.render.TextBox"] = function() return TextBox end
package.preload["src.ui.ChoiceBox"] = function() return ChoiceBox end

local mod = {
  id = "kanto_ascendant",
  exports = {},
  options = { get = function(_, key) return options[key] end },
  read = function(_, relative)
    if relative == atlasPath then return "png" end
  end,
  assets = { path = function(_, relative) return "LOAD:" .. relative end },
}
assert(loadfile(root .. "/modern_storage_ui.lua"))()(mod, {
  i18n = {
    isGerman = function() return false end,
    text = function(en) return en end,
  },
})
local ui = assert(mod.exports.modernStorageUi)
local game = {
  data = { pokemon = { PIKACHU = { name = "PIKACHU", dex = 25 } } },
  save = {
    currentBox = 1,
    boxes = {
      [1] = { { species = "PIKACHU", level = 25 } },
      [2] = {},
    },
    party = { { species = "PIKACHU", level = 25, shiny = true } },
    options = { modOptions = { kanto_ascendant = options } },
  },
  input = { wasPressed = function() return false end },
}
local pushed, writes = {}, 0
game.stack = {
  states = pushed,
  push = function(_, state) pushed[#pushed + 1] = state end,
  pop = function() return table.remove(pushed) end,
  top = function() return pushed[#pushed] end,
}
game.writeSave = function() writes = writes + 1 end
local items = { { value = 1, label = "PIKACHU :L25" } }
options.pc_interface_style = "default"
local defaultList = ListMenu.new(game, "BOX 1 (WITHDRAW)", items)
assert(defaultList.__ascendantBoxGrid == nil,
  "DEFAULT PC choice did not yield to the engine-owned Box list")

options.pc_interface_style = "ascendant"
local list = ListMenu.new(game, "BOX 1 (WITHDRAW)", items)
assert(list.__ascendantBoxGrid == true, "storage grid wrapper missing")

-- Explicit KASC means the original code-drawn view and no atlas I/O.
assert(ui.useFireRedPc(game) == false, "KASC choice unexpectedly enabled FRLG")
list:draw()
assert(#quads == 0, "KASC choice unexpectedly sampled the GBA atlas")

-- The option is live for newly drawn storage surfaces.
options.pc_interface_style = "firered"
assert(ui.useFireRedPc(game) == true, "valid FRLG atlas was rejected")
local wideW, wideH = list:uiSize()
assert(wideW == 480 and wideH == 320,
  "FRLG organizer did not request its readable 480x320 PC surface")
pushed[#pushed + 1] = list
local monSubmenu = Menu.new(game, {
  { label = "WITHDRAW" }, { label = "STATS" }, { label = "CANCEL" },
})
local subW, subH = monSubmenu:uiSize()
assert(monSubmenu.__ascendantFireRedPcOverlay
    and subW == 480 and subH == 320,
  "storage action submenu collapsed the wide PC canvas")
local pcPrompt = TextBox.new(game, "TEST")
local promptW, promptH = pcPrompt:uiSize()
assert(pcPrompt.__ascendantFireRedPcOverlay
    and promptW == 480 and promptH == 320,
  "storage TextBox collapsed the wide PC canvas")
pushed[#pushed + 1] = pcPrompt
local pcChoice = ChoiceBox.new(game, function() end)
local choiceW, choiceH = pcChoice:uiSize()
assert(pcChoice.__ascendantFireRedPcOverlay
    and choiceW == 480 and choiceH == 320,
  "storage ChoiceBox collapsed the wide PC canvas")
table.remove(pushed)
table.remove(pushed)
list:draw()
local sawBackdrop, sawData, sawWallpaper, sawWallpaperTitle =
  false, false, false, false
local sawTab, sampledOpaqueHand = false, false
for _, quad in ipairs(quads) do
  sawBackdrop = sawBackdrop or (quad.x == 0 and quad.y == 0
    and quad.w == 240 and quad.h == 160)
  sawData = sawData or (quad.x == 0 and quad.y == 328
    and quad.w == 80 and quad.h == 160)
  sawWallpaper = sawWallpaper or (quad.x == 1 and quad.y == 686
    and quad.w == 156 and quad.h == 115)
  sawWallpaperTitle = sawWallpaperTitle or (quad.x == 21 and quad.y == 698
    and quad.w == 114 and quad.h == 14)
  sawTab = sawTab or (quad.x == 17 and quad.y == 660
    and quad.w == 124 and quad.h == 21)
  sampledOpaqueHand = sampledOpaqueHand or (quad.x == 493 and quad.y == 5
    and quad.w == 18 and quad.h == 20)
end
assert(sawBackdrop, "FRLG orange organizer background was not sampled")
assert(sawData, "FRLG PKMN DATA panel was not sampled")
assert(sawWallpaper, "Box 1 wallpaper was not sampled")
assert(sawWallpaperTitle,
  "Box title did not reuse a real crop from the active wallpaper")
assert(sawTab, "FRLG Box tab was not sampled")
assert(not sampledOpaqueHand and handPolygons > 0,
  "FRLG cursor did not replace the opaque atlas crop with transparent pixels")
assert(ui.wallpaperLabel(1) == "FOREST"
    and ui.wallpaperLabel(12) == "CLOUDS",
  "twelve-Box wallpaper mapping drifted")

local partyList = ListMenu.new(game, "PARTY (DEPOSIT)", items)
partyList:draw()
local sawPartyPanel = false
for _, quad in ipairs(quads) do
  sawPartyPanel = sawPartyPanel or (quad.x == 83 and quad.y == 328
    and quad.w == 94 and quad.h == 160)
end
assert(sawPartyPanel, "FRLG Party rail was not sampled")
local sawCrystalNormal, sawCrystalShiny = false, false
for _, path in ipairs(loadedImagePaths) do
  sawCrystalNormal = sawCrystalNormal
    or path:find("crystal_animated/front/normal/25/001.png", 1, true) ~= nil
  sawCrystalShiny = sawCrystalShiny
    or path:find("crystal_animated/front/shiny/25/001.png", 1, true) ~= nil
end
assert(sawCrystalNormal and sawCrystalShiny,
  "FRLG Box/Party surfaces did not load normal and shiny Crystal fronts")
for _, request in ipairs(spriteRequests) do
  assert(request.side == "front" and request.ctx
      and request.ctx.kind == "box" and request.ctx.mon,
    "FRLG storage art escaped the central kind=box sprite resolver")
end

local rootMenu = Menu.new(game, {
  { label = "BILL's PC" }, { label = "RED's PC" },
  { label = "PROF.OAK's PC" }, { label = "LOG OFF" },
})
assert(rootMenu.__ascendantFireRedPcRoot == true,
  "Pokémon Center PC root did not receive FRLG chrome")
local itemMenu = ListMenu.new(game, "WITHDRAW ITEM", items, { messageBox = true })
assert(itemMenu.__ascendantFireRedItemPc == true,
  "player item storage did not receive FRLG chrome")
local boxRoot = BoxMenu.new(game)
boxRoot:draw()
local moveItem, changeItem
for _, item in ipairs(boxRoot.items) do
  if tostring(item.label):find("MOVE", 1, true) then moveItem = item end
  if tostring(item.label):find("CHANGE", 1, true) then changeItem = item end
end
assert(moveItem and type(moveItem.onSelect) == "function",
  "FRLG organizer MOVE POKéMON action missing")
assert(changeItem and type(changeItem.onSelect) == "function",
  "FRLG direct Box picker missing")
moveItem.onSelect()
local organizer = pushed[#pushed]
assert(organizer and organizer.uiSize and organizer.update and organizer.draw,
  "MOVE POKéMON did not open the live organizer")
local ow, oh = organizer:uiSize()
assert(ow == 480 and oh == 320, "live organizer surface drifted")
organizer:draw()

-- The Box tab changes Box and wallpaper as navigation: no cartridge-era
-- save confirmation and no forced write. A carried mon remains attached to
-- the hand while browsing and can be committed into a different Box.
local pressed = {}
game.input.wasPressed = function(_, key) return pressed[key] == true end
organizer.zone, organizer.boxIndex = "box", 1
local crossBoxMon = game.save.boxes[1][1]
pressed = { a = true }
organizer:update(1 / 60)
assert(organizer.carry and organizer.carry.mon == crossBoxMon,
  "MOVE did not pick the Box Pokémon up")
organizer.zone = "box_tab"
pressed = { right = true }
organizer:update(1 / 60)
pressed = {}
assert(game.save.currentBox == 2, "organizer Box tab did not switch live")
assert(organizer.carry and organizer.carry.mon == crossBoxMon,
  "carried Pokémon was lost while changing Boxes")
assert(writes == 0, "live Box selection forced a cartridge-era save")
organizer:draw()
local sawBox2Wallpaper = false
for _, quad in ipairs(quads) do
  sawBox2Wallpaper = sawBox2Wallpaper or (quad.x == 162 and quad.y == 686
    and quad.w == 156 and quad.h == 115)
end
assert(sawBox2Wallpaper,
  "live Box switch did not replace the Box 1 wallpaper with Box 2")
organizer.zone, organizer.boxIndex = "box", 1
pressed = { a = true }
organizer:update(1 / 60)
pressed = {}
assert(#game.save.boxes[1] == 0 and game.save.boxes[2][1] == crossBoxMon,
  "carried Pokémon was not moved from Box 1 into Box 2")

-- SELECT remains the party button even while carrying, which permits a real
-- Box<->party swap without leaving the organizer.
local boxedBefore, partyBefore = game.save.boxes[2][1], game.save.party[1]
pressed = { a = true }
organizer:update(1 / 60)
pressed = { select = true }
organizer:update(1 / 60)
pressed = {}
organizer:update(.21)
assert(organizer.zone == "party" and organizer.carry,
  "SELECT did not open the party rail while carrying")
pressed = { a = true }
organizer:update(1 / 60)
pressed = {}
assert(game.save.party[1] == boxedBefore
    and game.save.boxes[2][1] == partyBefore,
  "Box/party MOVE did not swap the engine-owned records")

-- CLOSE BOX is a real focus target, not decorative atlas text. Closing with
-- a pending carry cancels that UI operation because the source is untouched.
organizer.zone, organizer.boxIndex = "box", 1
local beforeClose = game.save.boxes[2][1]
pressed = { a = true }
organizer:update(1 / 60)
organizer.zone = "box_tab"
pressed = { up = true }
organizer:update(1 / 60)
assert(organizer.zone == "close", "CLOSE BOX cannot receive focus")
pressed = { a = true }
organizer:update(1 / 60)
pressed = {}
assert(game.stack:top() ~= organizer, "CLOSE BOX did not exit the organizer")
assert(game.save.boxes[2][1] == beforeClose,
  "CLOSE BOX discarded a Pokémon while cancelling carry")

-- The Legacy Bank reuses the organizer without materializing empty archive
-- rows. It starts at 500 virtual pages and grows only once every one of the
-- first 10,000 slots is occupied.
local bankRows = {
  { id = "locked", mon = { species = "PIKACHU", level = 25 },
    withdrawBlocked = true, withdrawReason = "HALL ENTRY NEEDED" },
}
local bankMoves, bankWithdrawals, bankDeposits = 0, 0, 0
local bank = ui.newLegacyBankOrganizer(game, {
  rows = function() return bankRows end,
  move = function() bankMoves = bankMoves + 1 return true end,
  withdraw = function() bankWithdrawals = bankWithdrawals + 1 return true end,
  deposit = function() bankDeposits = bankDeposits + 1 return true end,
})
assert(bank.__ascendantLegacyBankOrganizer and bank:boxCount() == 500,
  "Legacy Bank did not start with 500 sparse virtual Boxes")
bank.zone, bank.bankIndex = "bank", 1
pressed = { a = true }
bank:update(1 / 60)
pressed = {}
assert(bank.carry == nil and bank.message == "HALL ENTRY NEEDED",
  "locked Legacy Pokémon was picked up or its reason was hidden")
for index = 2, 9999 do
  bankRows[index] = { id = "bank:" .. index,
    mon = { species = "PIKACHU", level = 25 } }
end
bank:refresh()
assert(bank:boxCount() == 500,
  "Legacy Bank expanded before its first 500 Boxes were full")
bankRows[10000] = { id = "bank:10000",
  mon = { species = "PIKACHU", level = 25 } }
bank:refresh()
assert(bank:boxCount() == 501,
  "Legacy Bank did not auto-extend after filling Box 500")
assert(bankMoves == 0 and bankWithdrawals == 0 and bankDeposits == 0,
  "capacity navigation mutated Legacy Bank authority")

-- A separate factory owns a separate atlas cache: unavailable artwork must
-- not produce a half-rendered PC, even when the saved choice says firered.
local missing = {
  id = "kanto_ascendant_missing_atlas",
  exports = {},
  options = mod.options,
  read = function() return nil end,
}
assert(loadfile(root .. "/modern_storage_ui.lua"))()(missing, {
  i18n = {
    isGerman = function() return false end,
    text = function(en) return en end,
  },
})
assert(missing.exports.modernStorageUi.useFireRedPc(game) == false,
  "missing FRLG atlas did not fail closed to KASC")

local invalid = {
  id = "kanto_ascendant_invalid_atlas",
  exports = {},
  options = mod.options,
  read = function(_, relative)
    if relative == atlasPath then return "not-the-expected-sheet" end
  end,
  assets = { path = function() return "INVALID_DIMENSIONS.png" end },
}
assert(loadfile(root .. "/modern_storage_ui.lua"))()(invalid, {
  i18n = {
    isGerman = function() return false end,
    text = function(en) return en end,
  },
})
assert(invalid.exports.modernStorageUi.useFireRedPc(game) == false,
  "invalid FRLG atlas dimensions did not fail closed to KASC")

print("frlg pc interface test: ok")
