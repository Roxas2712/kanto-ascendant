-- Real-LÖVE acceptance driver for the additive Crystal v1.5 integration.
-- Run once with COLOR_MODE=redpp and once with COLOR_MODE=gbc.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local mode = os.getenv("COLOR_MODE") or "redpp"
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local Pokemon = require("src.pokemon.Pokemon")
  local Sprites = require("src.pokemon.Sprites")
  local SummaryMenu = require("src.ui.SummaryMenu")
  local BattleState = require("src.battle.BattleState")
  local PaletteFX = require("src.render.PaletteFX")

  U.wait(20)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local crystal = assert(api.crystalAnimation,
    "Crystal animation controller missing")
  local presentation = assert(api.crystalV15,
    "Crystal v1.5 presentation controller missing")

  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}

  local function setOption(key, value)
    game.mods.modOptions.kanto_ascendant[key] = value
    game.save.options.modOptions.kanto_ascendant[key] = value
    if game.mods.events then
      game.mods.events:emit("mod.options_changed", {
        mod = "kanto_ascendant", key = key, value = value,
      })
    end
  end

  setOption("pokemon_sprite_style", "crystal")
  setOption("dex_sprite_style", "crystal")
  setOption("sprite_style_battle", true)
  setOption("sprite_style_summary", true)
  setOption("sprite_style_dex", true)
  setOption("sprite_style_scenes", true)
  setOption("crystal_animation", true)
  PaletteFX.setMode(mode)

  local grayscale = mode ~= "redpp"
  local variant = grayscale and "grayscale" or "normal"
  local mon = Pokemon.new(game.data, "BULBASAUR", 33,
    function() return 8 end)
  game.save.party = { mon }

  local front, frontColor = Sprites.path(game.data, "BULBASAUR", "front", {
    mon = mon, kind = "summary", side = "front",
  })
  assert(tostring(front):find(
      "assets/crystal_animated/front/" .. variant .. "/1/001.png",
      1, true), "wrong v1.5 summary frame: " .. tostring(front))
  assert(frontColor == not grayscale,
    "summary true-color contract does not match " .. mode)

  local back, backColor = Sprites.path(game.data, "BULBASAUR", "back", {
    mon = mon, kind = "battle", side = "back",
  })
  assert(tostring(back):find(
      "assets/crystal_animated/back/" .. variant .. "/1/001.png",
      1, true), "wrong v1.5 battle back: " .. tostring(back))
  assert(backColor == not grayscale,
    "battle-back true-color contract does not match " .. mode)

  local screen = SummaryMenu.new(game, mon)
  local state = assert(screen.__ascendantCrystalV15,
    "SummaryMenu did not attach the v1.5 animation")
  assert(screen.sprite == state.image,
    "SummaryMenu did not install the current animated frame")
  local skipFirst = os.getenv("CRYSTAL_SKIP_FIRST_SHOT") == "1"
  local firstOnly = os.getenv("CRYSTAL_FIRST_ONLY") == "1"
  local first = state.frame
  local firstImage = state.image
  if skipFirst then
    -- Advance off-stack first, then make the progressed frame the first and
    -- only framebuffer capture in this process.  macOS can otherwise return
    -- a partially composited image for a second same-canvas screenshot.
    for _ = 1, 300 do
      presentation:updateScreen(screen, 1 / 60)
      if state.frame ~= first then break end
    end
    assert(state.frame ~= first, "SummaryMenu animation did not advance")
    assert(state.image ~= firstImage,
      "SummaryMenu changed frame without loading the next image")
  end
  if firstOnly or skipFirst then
    -- Freeze only the photographed QA state.  This keeps a GPU upload from
    -- landing in the exact asynchronous capture frame; the paired run above
    -- has already proved that the live controller advances and swaps images.
    state.animated = false
  end
  game.stack:push(screen)
  U.wait(20)
  assert(game.stack:top() == screen,
    "SummaryMenu closed while its Crystal animation was running")
  local suffix = skipFirst and "b" or "a"
  assert(U.shot(game,
    shotDir .. "/" .. mode .. "_summary_frame_" .. suffix .. ".png"))
  U.wait(10)

  if not firstOnly and not skipFirst then
    first, firstImage = state.frame, state.image
    for _ = 1, 300 do
      U.wait(1)
      if state.frame ~= first then break end
    end
    assert(state.frame ~= first, "SummaryMenu animation did not advance")
    assert(state.image ~= firstImage,
      "SummaryMenu changed frame without loading the next image")
  end
  game.stack:pop()

  local battle = BattleState.newTrainer(game, "OPP_YOUNGSTER", 1)
  local trainerPath = BattleState.trainerPicPath(
    game.data, battle.trainer, "OPP_YOUNGSTER", 1)
  local trainerName = tostring(trainerPath):match("([^/\\]+)%.png$")
  local expectedTrainer = presentation:trainerImage(trainerName, "battle")
  assert(expectedTrainer and battle.trainerPic == expectedTrainer,
    "trainer battle did not select the v1.5 portrait")
  battle.onFinish = function() end
  game.stack:push(battle)
  U.wait(100)
  assert(U.shot(game, shotDir .. "/" .. mode .. "_trainer_intro.png"))

  assert(crystal.grayscaleAvailable[1]
      and crystal.backGrayscaleAvailable[1],
    "v1.5 runtime coverage tables are incomplete")
  U.log("CRYSTAL V1.5 REAL-LOVE PASS", mode, shotDir,
    "summary frame", first, "->", state.frame)
  love.event.quit()
end
