-- Renderer-backed regression for Oak's character selector.  The deliberately
-- persisted Ascendant field style must not restore compact Gen-I portraits.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local Runtime = require("src.mods.Runtime")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local characters = assert(exports.extendedCharacters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  local options = game.mods.modOptions.kanto_ascendant
  options.character_sprite_style = "ascendant"
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = options
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant",
    key = "character_sprite_style", value = "ascendant",
  })
  check("old option is really active", characters.characterStyle() == "ascendant")

  while game.stack:top() do game.stack:pop() end
  local selector = characters.CharacterSelect.new(game, {}, function() end)
  game.stack:push(selector)
  local hudChain = Runtime.hooks and Runtime.hooks.chains
    and Runtime.hooks.chains["render.hud"] or {}
  U.log("render.hud links", #hudChain)
  for chainIndex, link in ipairs(hudChain) do
    U.log("render.hud link", chainIndex, tostring(link.owner),
      tostring(link.priority))
  end
  check("live stack owns the actual Kanto Ascendant selector",
    game.stack:top() == selector
      and getmetatable(selector) == characters.CharacterSelect)
  for index, id in ipairs(characters.selectionOrder) do
    selector.index = index
    local visual = characters.selectionVisual(id)
    local portrait = selector.portraits[id]
    local width, height
    if portrait then width, height = portrait:getDimensions() end
    check(id .. " selector resolves to its native HD model",
      visual and visual.path ==
        ("assets/characters/crystal_chars/%s_voxel_front_hd.png")
        :format(id:lower()))
    check(id .. " selector portrait retains all 128x128 source pixels",
      width == 128 and height == 128)
    U.wait(3)
    check(id .. " Oak selector screenshot",
      U.shot(game, ("%s/%02d_oak_selector_%s.png")
        :format(dir, index, id:lower())))
    -- POKEPORT_SPEED can execute several coroutine updates between two draw
    -- calls. Inspect the HUD proof only after U.shot has waited for a rendered
    -- frame, otherwise a correct overlay can be sampled one frame too early.
    local hd = selector.__screenSpaceHd
    U.log(id .. " post-shot top/meta/proof",
      tostring(game.stack:top() == selector),
      tostring(getmetatable(game.stack:top()) == characters.CharacterSelect),
      tostring(hd and hd.integerZoom))
    check(id .. " selector uses integer nearest screen-space zoom",
      hd and hd.character == id and hd.sourceWidth == 128
        and hd.sourceHeight == 128 and hd.integerZoom >= 1
        and hd.integerZoom == math.floor(hd.integerZoom))
  end

  U.log(("FRLG OAK SELECTOR RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
