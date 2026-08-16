-- Renderer-backed regression for the atomic Ascendant title compositor.
-- The engine keeps its complete edition-specific Pokemon rotation; every real
-- Pokemon change advances Green/Blue/Red once and the final draw contains the
-- new trainer plus that exact species' bundled animated Crystal sprite.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local TitleState = require("src.ui.TitleState")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  while game.stack:top() do game.stack:pop() end
  local title = TitleState.new(game, { onNewGame = function() end })
  game.stack:push(title)
  title.phase = "loop"
  title.scrollPhase = "hold"

  -- Red's historical TitleMons list.  This assertion fails if the mod ever
  -- narrows it back to three fixed starters or changes the engine-owned order.
  local expectedCycle = {
    "CHARMANDER", "SQUIRTLE", "BULBASAUR", "WEEDLE", "NIDORAN_M",
    "SCYTHER", "PIKACHU", "CLEFAIRY", "RHYDON", "ABRA", "GASTLY",
    "DITTO", "PIDGEOTTO", "ONIX", "PONYTA", "MAGIKARP",
  }
  assert(#title.cycleSpecies == #expectedCycle,
    "Ascendant did not preserve the complete native Red title rotation")
  local cycleIndex, cycleSnapshot = {}, {}
  for index, species in ipairs(expectedCycle) do
    assert(title.cycleSpecies[index] == species,
      ("native title slot %d changed: expected %s, got %s")
        :format(index, species, tostring(title.cycleSpecies[index])))
    cycleIndex[species] = index
    cycleSnapshot[index] = title.cycleSpecies[index]
  end

  local pairTrace = {}
  local function rememberPair()
    local id = assert(title.kaTitlePairId, "title pair identity is missing")
    if pairTrace[#pairTrace] ~= id then pairTrace[#pairTrace + 1] = id end
  end
  local function stepTitle(dt)
    title:update(dt or (1 / 60))
    rememberPair()
  end
  rememberPair()

  local nativeDraw = love.graphics.draw
  local function stateFor(trainer, species)
    assert(title.kaTitlePhase == "pair"
        and title.kaTitleTrainerId == trainer
        and title.kaTitleSpecies == species
        and title.kaTitlePairId == trainer .. ":" .. species,
      ("expected atomic %s:%s, got %s")
        :format(trainer, species, tostring(title.kaTitlePairId)))
    assert(title.cycleSpecies[title.cycleIndex] == species,
      "published pair species differs from the engine-owned cycle species")
    local image = assert(title:currentSprite(),
      trainer .. ":" .. species .. " has no bundled Crystal Pokemon")
    local state = assert(title.__ascendantCrystalV15Title,
      trainer .. ":" .. species .. " has no Crystal animation state")
    assert(state.species == species and state.animated,
      trainer .. ":" .. species .. " is not the authored animation")
    return image, state
  end

  local function settleAnimation(trainer, species)
    local firstImage, state = stateFor(trainer, species)
    local firstFrame = state.frame
    local duration = state.durations[firstFrame] or 100
    local steps = math.max(2, math.ceil((duration + 1) / (1000 / 60)))
    for _ = 1, steps do stepTitle() end
    while title.slideIn and title.slideIn > 0 do stepTitle() end
    local image, settled = stateFor(trainer, species)
    assert(settled.frame ~= firstFrame or image ~= firstImage,
      trainer .. ":" .. species .. " animation did not advance")
    return image
  end

  local function capturePair(path, trainer, species)
    local pokemon = settleAnimation(trainer, species)
    local observedTrainer, observedPokemon = false, false
    love.graphics.draw = function(image, ...)
      if image == title.player then observedTrainer = true end
      if image == pokemon then observedPokemon = true end
      return nativeDraw(image, ...)
    end
    local ok, problem = pcall(function()
      assert(U.shot(game, dir .. "/" .. path))
    end)
    love.graphics.draw = nativeDraw
    assert(ok, trainer .. ":" .. species .. " draw raised: "
      .. tostring(problem))
    assert(observedTrainer and observedPokemon,
      trainer .. " and " .. species .. " were not drawn in the same frame")
  end

  assert(title.kaTitleTrainerId == "GREEN"
      and title.kaTitleSpecies == "CHARMANDER",
    "native first species was not published with the first trainer")
  capturePair("01_green_charmander.png", "GREEN", "CHARMANDER")

  -- Drive the native random selector to three real non-starter entries.  The
  -- override changes no title list or product state; it only makes this
  -- disposable renderer proof deterministic.
  local nativeRandom = love.math.random
  local forcedIndex
  love.math.random = function(low, high)
    assert(forcedIndex, "unexpected title random call")
    local pick = forcedIndex
    forcedIndex = nil
    assert(pick >= low and pick <= high, "forced title index out of range")
    return pick
  end

  local function transitionTo(species, trainer)
    forcedIndex = assert(cycleIndex[species])
    local priorPair = title.kaTitlePairId
    title.timer = 239
    stepTitle()
    assert(forcedIndex == nil, "native title selector did not consume the pick")
    assert(title.kaTitlePairId ~= priorPair,
      "real Pokemon change did not publish one new trainer/Pokemon identity")
    stateFor(trainer, species)
  end

  transitionTo("NIDORAN_M", "BLUE")
  local stablePair = title.kaTitlePairId
  local stableTrace = #pairTrace
  for _ = 1, 3 do
    title.timer = 0 -- unrelated native/compatibility reset, not an identity edge
    stepTitle()
  end
  assert(title.kaTitlePairId == stablePair and #pairTrace == stableTrace,
    "timer-only resets advanced or split the atomic title identity")
  capturePair("02_blue_nidoran_m.png", "BLUE", "NIDORAN_M")

  transitionTo("SCYTHER", "RED")
  capturePair("03_red_scyther.png", "RED", "SCYTHER")

  transitionTo("DITTO", "GREEN")
  capturePair("04_green_ditto_wrap.png", "GREEN", "DITTO")
  love.math.random = nativeRandom

  local expectedTrace = {
    "GREEN:CHARMANDER", "BLUE:NIDORAN_M",
    "RED:SCYTHER", "GREEN:DITTO",
  }
  assert(#pairTrace == #expectedTrace,
    "full title run published an intermediate or duplicate pair identity")
  for index, id in ipairs(expectedTrace) do
    assert(pairTrace[index] == id,
      ("pair trace %d expected %s, got %s")
        :format(index, id, tostring(pairTrace[index])))
  end
  assert(#title.cycleSpecies == #cycleSnapshot,
    "title run changed the native cycle length")
  for index, species in ipairs(cycleSnapshot) do
    assert(title.cycleSpecies[index] == species,
      ("title run mutated native cycle slot %d"):format(index))
  end

  local footer = title.title.copyrightText
  local ribbon = title.title.germanFullVersionRibbon
  love.graphics.draw = function()
    error("injected downstream title draw failure")
  end
  local raised, injected = pcall(function() title:draw() end)
  love.graphics.draw = nativeDraw
  assert(not raised and tostring(injected):find(
      "injected downstream title draw failure", 1, true),
    "injected downstream draw failure was not propagated")
  assert(title.title.copyrightText == footer
      and title.title.germanFullVersionRibbon == ribbon,
    "downstream error did not restore footer/ribbon state")
  assert(pcall(function() title:draw() end),
    "normal pair draw after injected failure did not recover")

  local out = assert(io.open(dir .. "/driver_result.txt", "wb"))
  out:write("status=PASS\n",
    "scope=title-native-cycle-atomic-trainer-crystal-pokemon\n",
    "native_cycle_preserved=16/16\n",
    "native_cycle_unchanged_after=16/16\n",
    "nonstarter_pairs=3/3\n",
    "trainer_transitions=3/3\n",
    "trainer_cycle_wrap=1/1\n",
    "bundled_crystal_animation=4/4\n",
    "timer_reset_stability=1/1\n",
    "identity_trace=4/4\n",
    "error_restore=1/1\n",
    "screenshots=4/4\n",
    "runtime_options_changed=0\n",
    "save_write=0\n",
    "fail=0\n")
  out:close()
  print("TITLE NATIVE CYCLE ATOMIC PAIRED DRAW RESULT pass=9 fail=0")
  love.event.quit(0)
end
