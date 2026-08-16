-- Renderer-backed Red/Blue/Yellow QA for the party SummaryMenu.
--
-- The Dex sprite selector must also govern the static artwork shown after
-- PARTY -> STATS.  Battle artwork remains an independent option.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Sprites = require("src.pokemon.Sprites")
  local SummaryMenu = require("src.ui.SummaryMenu")
  local GameVersion = require("src.core.GameVersion")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local version = GameVersion.get()

  U.wait(20)
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.mods.modOptions = game.mods.modOptions or {}
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

  -- This exact combination exposed the regression: Crystal selected for
  -- catalogue screens while the independent Kanto battle-art toggle is off.
  setOption("dex_sprite_style", "crystal")
  setOption("kanto_crystal_art", false)
  setOption("crystal_animation", true)

  for _, row in ipairs({
    { species = "GROWLITHE", dex = 58 },
    { species = "TOTODILE", dex = 158 },
    { species = "FERALIGATR", dex = 160 },
  }) do
    local mon = Pokemon.new(game.data, row.species, 33,
      function() return 8 end)
    local path, trueColor = Sprites.path(
      game.data, row.species, "front", { mon = mon, kind = "summary" })
    local expected = ("assets/crystal_animated/front/normal/%d/001.png")
      :format(row.dex)
    assert(type(path) == "string" and path:find(expected, 1, true),
      ("%s SummaryMenu ignored Crystal for %s: %s")
        :format(version, row.species, tostring(path)))
    assert(trueColor,
      version .. " SummaryMenu Crystal frame was not true-color for "
        .. row.species)

    local screen = SummaryMenu.new(game, mon)
    assert(screen.sprite and screen.spriteTrueColor,
      version .. " SummaryMenu did not load the resolved Crystal image for "
        .. row.species)
    game.stack:push(screen)
    U.wait(35)
    assert(U.shot(game, ("%s/%s_summary_crystal_%s.png"):format(
      shotDir, version, row.species:lower())))
    game.stack:pop()
    U.wait(8)
  end

  -- Independence guard: selecting Crystal for Summary/Dex must not silently
  -- turn on Crystal battle artwork.
  local battleMon = Pokemon.new(game.data, "GROWLITHE", 33,
    function() return 8 end)
  local battlePath = Sprites.path(game.data, "GROWLITHE", "front", {
    mon = battleMon, kind = "battle", side = "front",
  })
  assert(not tostring(battlePath):find(
      "assets/crystal_animated/front/normal/58/", 1, true),
    version .. " Summary selector leaked into battle artwork")

  U.log("SUMMARY CRYSTAL QA PASS", version, shotDir)
  love.event.quit()
end
