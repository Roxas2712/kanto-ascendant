-- Bounded Hall-of-Fame receipt for Gorochu's animated Crystal picture while
-- FULL Voxel is enabled and the saved colour mode is GBC.  This is the exact
-- combination that exposed the purple four-shade card in RC25.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local HallOfFame = require("src.ui.HallOfFame")
  local PaletteFX = require("src.render.PaletteFX")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")

  U.wait(20)
  local ascendant = assert(game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  assert(ascendant.gorochu and ascendant.gorochu.available,
    "Gorochu unavailable")
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  local function option(key, value)
    game.save.options.modOptions.kanto_ascendant[key] = value
    game.mods.modOptions.kanto_ascendant[key] = value
    game.mods.events:emit("mod.options_changed", {
      mod="kanto_ascendant", key=key, value=value,
    })
  end
  option("pokemon_sprite_style", "crystal")
  option("sprite_style_scenes", true)
  option("crystal_animation", true)
  game.save.options.colors = "gbc"
  PaletteFX.setMode("gbc")
  Pipelines.setLevel("voxel", 1)
  Pipelines.syncOptions(game.save.options)

  local mon = Pokemon.new(game.data, "GOROCHU", 70,
    function() return 9 end)
  mon.hp = mon.stats.hp
  game.save.party = { mon }
  game.save.player = game.save.player or {}
  game.save.player.name = "RED"
  game.save.pokedex = game.save.pokedex or { seen={}, owned={} }

  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  local hall = HallOfFame.new(game, function() end)
  game.stack:push(hall)
  -- StateStack:push invokes enter(). Calling it a second time skipped the
  -- one-Pokémon party straight to the player card and made the QA sampler,
  -- not the Hall itself, report that Gorochu never settled.
  for _ = 1, 180 do
    U.wait(1)
    if hall.phase == "mons" and hall.scrollX >= 96 then break end
  end
  assert(hall.phase == "mons" and hall.index == 1,
    "Hall did not settle on Gorochu")
  local state = assert(hall.__ascendantCrystalV15Hall
      and hall.__ascendantCrystalV15Hall.GOROCHU,
    "Hall did not attach Gorochu's Crystal animation")
  local firstFrame = state.frame
  local firstImage = hall:spriteFor("GOROCHU")
  assert(hall.spriteTrueColors and hall.spriteTrueColors.GOROCHU == true
      or hall.__ascendantCrystalV15HallTrueColors
        and hall.__ascendantCrystalV15HallTrueColors[firstImage] == true,
    "Hall lost Gorochu's true-colour receipt")
  assert(U.shot(game, dir .. "/01_gorochu_hof_full_frame_a.png"),
    "first Hall screenshot failed")
  for _ = 1, 360 do
    U.wait(1)
    if state.frame ~= firstFrame then break end
  end
  assert(state.frame ~= firstFrame,
    "Gorochu Hall animation did not advance")
  assert(U.shot(game, dir .. "/02_gorochu_hof_full_frame_b.png"),
    "advanced Hall screenshot failed")
  local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
  result:write(("PASS renderer=FULL colors=gbc frame=%d->%d trueColor=true\n")
    :format(firstFrame, state.frame))
  result:close()
  love.event.quit(0)
end
