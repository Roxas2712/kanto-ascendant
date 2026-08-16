-- Focused real-renderer regression for Crystal title colour and motion.

return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"), "KA_TEST_UTIL required"))
  local out = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local TitleState = require("src.ui.TitleState")

  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.pokemon_sprite_style = "crystal"
  game.mods.modOptions.kanto_ascendant.sprite_style_scenes = true
  game.mods.modOptions.kanto_ascendant.crystal_animation = true
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant
  if game.mods.events then
    for _, row in ipairs({
      { "pokemon_sprite_style", "crystal" },
      { "sprite_style_scenes", true },
      { "crystal_animation", true },
    }) do
      game.mods.events:emit("mod.options_changed", {
        mod = "kanto_ascendant", key = row[1], value = row[2],
      })
    end
  end

  while game.stack:top() do game.stack:pop() end
  local title = TitleState.new(game, { onNewGame = function() end })
  local wanted, diagnostics = nil, {}
  for index in ipairs(title.cycleSpecies or {}) do
    title.cycleIndex = index
    title.__ascendantCrystalV15Title = nil
    title:currentSprite()
    local candidate = title.__ascendantCrystalV15Title
    diagnostics[#diagnostics + 1] = table.concat({
      tostring(title.cycleSpecies[index]),
      candidate and tostring(candidate.dex) or "nil",
      candidate and tostring(candidate.animated) or "nil",
    }, ":")
    if candidate and candidate.animated then wanted = index break end
  end
  assert(wanted, "title cycle has no available animated Crystal witness; "
    .. "style=" .. tostring(game.mods.modOptions.kanto_ascendant.pokemon_sprite_style)
    .. " scenes=" .. tostring(game.mods.modOptions.kanto_ascendant.sprite_style_scenes)
    .. " rows=" .. table.concat(diagnostics, ","))
  title.cycleIndex, title.__ascendantCrystalV15Title = wanted, nil
  title.timer = 0
  game.stack:push(title)

  local first, trueColor = title:currentSprite()
  local state = assert(title.__ascendantCrystalV15Title,
    "title did not attach the Crystal presentation state")
  assert(first and trueColor == true and state.trueColor == true,
    "title Crystal frame was not preserved as true colour")
  assert(state.animated and #state.durations > 1,
    "title Crystal witness has no authored animation")
  local firstFrame, firstImage = state.frame, state.image
  assert(U.shot(game, out .. "/01_title_crystal_colour.png"))

  for _ = 1, 300 do
    game:step(1 / 60)
    if state.frame ~= firstFrame or state.image ~= firstImage then break end
  end
  state = assert(title.__ascendantCrystalV15Title)
  assert(state.frame ~= firstFrame or state.image ~= firstImage,
    "title Crystal animation did not advance")
  assert(select(2, title:currentSprite()) == true,
    "advanced title frame lost its true-colour contract")
  assert(U.shot(game, out .. "/02_title_crystal_animated.png"))

  local file = assert(io.open(out .. "/driver_result.txt", "wb"))
  file:write(("PASS species=%s first=%d advanced=%d trueColor=true\n")
    :format(title.cycleSpecies[wanted], firstFrame, state.frame))
  file:close()
  love.event.quit(0)
end
