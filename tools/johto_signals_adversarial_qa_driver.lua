-- Renderer-backed adversarial UAT for Kanto Ascendant 6.0.
--
-- Unlike the focused headless contracts, this driver deliberately performs
-- awkward player sequences in a real LÖVE process:
--   * decline the capsule, keep walking on the same map, leave, return,
--     decline/accept later;
--   * decline both boat directions before accepting them;
--   * save on Driftglass and verify the safe Pallet resume rewrite;
--   * scan a wrong habitat, scan every real trace in a strange order, then
--     scan a duplicate;
--   * switch all three receiver modes after repair.
--
-- Run once for Red, Blue and Yellow:
--
--   POKEPORT_VERSION=red POKEPORT_DRIVER=/abs/path/to/this.lua \
--   POKEPORT_IDENTITY=kanto-ascendant-signals-uat POKEPORT_TOUCH=0 \
--   POKEPORT_SPEED=8 SHOT_DIR=/tmp/ka-signals-red love .

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")

  U.wait(30)
  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.trainer_rematch,
    "Kanto Ascendant export missing")
  local stateApi = assert(exports.johtoSignalsState,
    "Johto Signals state export missing")
  local early = assert(exports.johtoSignals,
    "Early Johto export missing")
  local content = assert(exports.johtoSignalsContent,
    "Signals content export missing")
  local hub = assert(exports.signalsHub, "Signals hub export missing")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local version = os.getenv("POKEPORT_VERSION") or "red"
  local qaLanguage = os.getenv("QA_LANGUAGE")
  if qaLanguage then
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions.trainer_rematch =
      game.mods.modOptions.trainer_rematch or {}
    game.mods.modOptions.trainer_rematch.language = qaLanguage
    assert(exports.language() == qaLanguage,
      "could not select QA language " .. tostring(qaLanguage))
  end

  local function clearTable(value)
    for key in pairs(value) do value[key] = nil end
  end

  local function waitForChoice(limit)
    limit = limit or 80
    for _ = 1, limit do
      local top = game.stack:top()
      if top and type(top.onChoose) == "function"
          and (top.index == 1 or top.index == 2) then
        return top
      end
      U.tap(game, "a")
      U.wait(4)
    end
    error("choice box did not appear")
  end

  local function closeText()
    for _ = 1, 100 do
      if game.stack:top() == game.overworld then return true end
      U.tap(game, "a")
      U.wait(4)
    end
    return false
  end

  local function unwindToOverworld()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
    return game.stack:top() == game.overworld
  end

  local function showText(name, text)
    game.stack:push(TextBox.new(game, text))
    U.wait(40)
    assert(U.shot(game, shotDir .. "/" .. name .. ".png"))
    assert(closeText(), "could not close authored text: " .. name)
  end

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.party = {
    Pokemon.new(game.data, "BULBASAUR", 18, function() return 9 end),
  }
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  game.save.inventory = game.save.inventory or {}
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1

  local root = assert(stateApi.root())
  clearTable(root.earlyJohto)
  clearTable(root.resonance)
  stateApi.persist()
  early.install(game)
  hub.install(game)

  local s = early.state()
  s.startPolicy = "quest"
  s.mode = early.modes.KANTO_FIRST
  s.modeChosen = false
  s.capsuleTarget = 128
  s.pokedexSteps = 127
  s.palletVisits = 0
  early.persist()

  -- The one real step which reaches the hidden threshold.
  U.teleport(game, "PALLET_TOWN", 10, 12, "left")
  early.onStep(game, { game = game, map = { id = "PALLET_TOWN" } })
  U.wait(45)
  assert(s.pokedexSteps == 128 and s.capsuleAvailable == true,
    "step 128 did not make the capsule available")
  assert(U.shot(game, shotDir .. "/01_capsule_offer.png"))

  local firstChoice = waitForChoice()
  assert(firstChoice.index == 2,
    "capsule prompt must default to NO")
  assert(U.shot(game, shotDir .. "/02_capsule_default_no.png"))
  U.tap(game, "a") -- deliberately decline
  U.wait(45)
  assert(s.capsuleFound ~= true,
    "declining the capsule incorrectly completed the quest")
  assert(U.shot(game, shotDir .. "/03_capsule_declined.png"))
  assert(closeText(), "decline result did not close")

  -- Repeated same-map steps must not nag. Leaving and returning must retry.
  early.onStep(game, { game = game, map = { id = "PALLET_TOWN" } })
  early.onStep(game, { game = game, map = { id = "PALLET_TOWN" } })
  U.wait(20)
  assert(game.stack:top() == game.overworld,
    "same-map steps reopened a declined capsule prompt")
  U.teleport(game, "ROUTE_1", 10, 2, "down")
  early.onMapEntered({ game = game, map = { id = "ROUTE_1" } })
  U.teleport(game, "PALLET_TOWN", 10, 1, "down")
  early.onMapEntered({ game = game, map = { id = "PALLET_TOWN" } })
  U.wait(45)
  assert(U.shot(game, shotDir .. "/04_capsule_retry_after_map_change.png"))

  local retryChoice = waitForChoice()
  assert(retryChoice.index == 2,
    "retried capsule prompt must still default to NO")
  U.tap(game, "up")
  U.tap(game, "a") -- now accept
  U.wait(50)
  assert(s.capsuleFound == true and s.questStarted == true,
    "accepting after a decline did not start the quest")
  assert(U.shot(game, shotDir .. "/05_capsule_accepted_late.png"))
  assert(closeText(), "accepted capsule text did not close")
  content.refreshTravelNpc(game, "PALLET_TOWN")
  U.wait(30)
  assert(U.shot(game, shotDir .. "/06_pallet_boatman_after_retry.png"))

  -- Boat warning defaults to NO and can be declined without losing travel.
  content.offerTravel(game, { frozen = false })
  U.wait(45)
  assert(U.shot(game, shotDir .. "/07_departure_warning.png"))
  local travelNo = waitForChoice()
  assert(travelNo.index == 2, "departure prompt must default to NO")
  U.tap(game, "a")
  U.wait(25)
  assert(game.overworld.map.id == "PALLET_TOWN",
    "declining departure moved the player")

  content.offerTravel(game, { frozen = false })
  local travelYes = waitForChoice()
  U.tap(game, "up")
  U.tap(game, "a")
  U.wait(90)
  assert(game.overworld.map.id == content.MAP_ID,
    "accepting departure did not reach Driftglass")
  assert(U.shot(game, shotDir .. "/08_driftglass_arrival.png"))

  local copy = {
    player = {
      map = content.MAP_ID, x = 8, y = 12, facing = "up", surfing = true,
    },
  }
  assert(content.secureSaveLocation(copy) == true,
    "Driftglass save was not redirected")
  assert(copy.player.map == "PALLET_TOWN"
      and copy.player.x == content.PALLET_RETURN.x
      and copy.player.y == content.PALLET_RETURN.y
      and copy.player.surfing == false,
    "Driftglass safe resume coordinates are wrong")

  content.offerReturn(game, { frozen = false })
  U.wait(45)
  assert(U.shot(game, shotDir .. "/09_return_warning.png"))
  local returnNo = waitForChoice()
  assert(returnNo.index == 2, "return prompt must default to NO")
  U.tap(game, "a")
  U.wait(20)
  assert(game.overworld.map.id == content.MAP_ID,
    "declining return left Driftglass")

  local npc = { frozen = false }
  hub.onResearcher(game, game.overworld, npc)
  U.wait(45)
  assert(U.shot(game, shotDir .. "/10_receiver_repair.png"))
  assert(unwindToOverworld(), "researcher repair flow did not unwind")
  assert(s.receiverRepaired == true,
    "researcher did not repair the receiver")

  -- Wrong direction first, then every trace in a deliberately odd order.
  local ok, why, text = early.scanTrace(game, "ROUTE_3")
  assert(ok == false and why == "weak-echo",
    "unrelated map did not return a weak echo")
  showText("11_wrong_habitat_weak_echo", text)
  for _, mapId in ipairs({
    "VICTORY_ROAD_3F", "ROUTE_6", "VIRIDIAN_FOREST",
    "POKEMON_MANSION_B1F",
  }) do
    local recorded, reason = early.scanTrace(game, mapId)
    assert(recorded == true and reason == "trace-recorded",
      "real trace failed on " .. mapId)
  end
  local duplicate, duplicateWhy, duplicateText =
    early.scanTrace(game, "ROUTE_6")
  assert(duplicate == false and duplicateWhy == "already-recorded",
    "duplicate trace was recorded twice")
  showText("12_duplicate_trace", duplicateText)

  for _, mode in ipairs({
    early.modes.KANTO_FIRST,
    early.modes.WANDERWAVES,
    early.modes.UNLEASHED,
  }) do
    local changed, reason, modeText = early.setMode(game, mode)
    assert(changed == true and reason == "mode-set",
      "receiver rejected valid mode " .. mode)
    showText("13_mode_" .. mode:lower(), modeText)
  end

  content.offerReturn(game, { frozen = false })
  local returnYes = waitForChoice()
  U.tap(game, "up")
  U.tap(game, "a")
  U.wait(90)
  assert(game.overworld.map.id == "PALLET_TOWN",
    "accepted return did not reach Pallet")
  assert(U.shot(game, shotDir .. "/14_returned_to_pallet.png"))

  U.log("JOHTO SIGNALS ADVERSARIAL QA PASS", version)
end
