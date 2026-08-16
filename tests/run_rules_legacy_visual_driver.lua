-- Real-LÖVE acceptance for Oak's Lab KASC-terminal challenge setup and the complete
-- direct Legacy Journey hand-off. The driver uses a disposable identity.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local Pokemon = require("src.pokemon.Pokemon")
  local MapScripts = require("data.scripts.init")
  local Screens = require("src.ui.Screens")
  local PlayerPC = require("src.ui.PlayerPC")
  local TitleState = require("src.ui.TitleState")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local api = assert(game.mods.exports.kanto_ascendant)
  local rules = assert(api.runRules)
  local journey = assert(api.legacyJourney)
  local language = assert(api.language and api.language(),
    "Kanto Ascendant language export is required")
  local expectedReadOnly = language == "de"
    and "SEL:HILFE GESP." or "SEL:HELP  LOCKED"
  local expectedLocked = expectedReadOnly
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end
  local function clearToOverworld()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end
  local function playerPcRows(direct)
    -- Go through the production PlayerPC constructor so this acceptance also
    -- proves the row is present in the menu the player actually sees.
    return PlayerPC.new(game, direct and { direct = true } or nil).items
  end
  local function visibleRows(menu)
    local out = {}
    for index, item in ipairs(menu.items or {}) do
      out[index] = { key = item.key, label = item.label, right = item.right }
    end
    return SaveData.encode(out)
  end
  local function unwindTo(retained, limit)
    for _ = 1, limit do
      if game.stack:top() == retained then return true end
      local top = game.stack:top()
      if not top or top == game.overworld then return false end
      game.stack:pop()
    end
    return game.stack:top() == retained
  end

  U.teleport(game, "OAKS_LAB", 1, 2, "up")
  game.save.party = {}
  game.save.inventory = {}
  game.save.pokedex = { seen = {}, owned = {} }
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant =
    game.save.modData.kanto_ascendant or {}
  -- Exact RC25 import shape: progress had silently created a permanently
  -- locked STANDARD/OFF record even though the player never confirmed any
  -- challenge rules. The KASC terminal must repair this legacy draft.
  game.save.modData.kanto_ascendant.run_rules = {
    version = 1, configured = true, locked = true,
    preset = "standard", seed = 650025,
    randomizer = {
      enabled=false, wild=true, trainers=true, starters=true,
      gifts=false, static=false, items=false, legendary=false,
      balanced=true, consistent=true,
    },
    nuzlocke = {
      mode="off", dupes=true, blackout="end", shinyOdds=4096,
    },
    mappings={species={},items={}}, areas={}, deaths={},
    encounterSerial=0,
  }
  local state = rules.state(game.save)
  check("RC25 reasonless lock migrates back to configurable",
    state and state.version == 3 and not state.locked
      and not state.configured and state.migrationNoticePending == true)
  local roomRows = playerPcRows(true)
  local runRow
  for _, row in ipairs(roomRows or {}) do
    if row.label and row.label:find("ASC", 1, true) then runRow = row end
  end
  check("ordinary Player PC has no duplicate ASC RUN row", runRow == nil)
  journey.openLabTerminal(game)
  local hub = game.stack:top()
  local hubRun
  for _, row in ipairs(hub and hub.items or {}) do
    if row.value == "asc_run" then hubRun = row end
  end
  check("Oak's Lab KASC terminal exposes ASC RUN directly",
    hubRun ~= nil and type(hub.onChoose) == "function")
  hub.onChoose(hubRun, hub)
  U.wait(3)
  local main = game.stack:top()
  check("ASCENDANT RUN opens in the shared FireRed list",
    main and main.title and main.title:find("ASCENDANT", 1, true)
      and main.__kantoAscendantLayout == true)
  check("run-rules main screenshot",
    U.shot(game, dir .. "/01_run_rules_main.png"))

  main.onChoose(main.items[4], main)
  U.wait(2)
  local randomizer = game.stack:top()
  check("individual Randomizer rules open", randomizer and #randomizer.items == 9)
  check("Randomizer rules screenshot",
    U.shot(game, dir .. "/02_randomizer_rules.png"))
  local beforeWild = state.randomizer.wild
  randomizer.onAdjustKey(randomizer.items[1], 1)
  check("Left/Right changes only the selected Randomizer rule",
    state.randomizer.wild ~= beforeWild
      and state.randomizer.trainers == true)
  local changedWild = state.randomizer.wild
  randomizer.onChoose(randomizer.items[1], randomizer)
  check("A opens Randomizer information without changing its value",
    state.randomizer.wild == changedWild)
  unwindTo(randomizer, 2)
  game.stack:pop()

  main.onChoose(main.items[5], main)
  U.wait(2)
  local nuzlocke = game.stack:top()
  check("individual Nuzlocke rules open", nuzlocke and #nuzlocke.items == 4)
  check("Nuzlocke rules screenshot",
    U.shot(game, dir .. "/03_nuzlocke_rules.png"))
  nuzlocke.onAdjustKey(nuzlocke.items[1], 1)
  check("Left/Right cycles Nuzlocke mode from OFF",
    state.nuzlocke.mode ~= "off")
  local changedMode = state.nuzlocke.mode
  nuzlocke.onChoose(nuzlocke.items[1], nuzlocke)
  check("A opens Nuzlocke information without changing its mode",
    state.nuzlocke.mode == changedMode)
  unwindTo(nuzlocke, 2)
  game.stack:pop()

  state.randomizer.enabled = true
  state.randomizer.wild = true
  state.seed = 650065
  local first = rules.randomSpecies(state, "RATTATA", "wild")
  state.mappings.species = {}
  check("Randomizer mapping is deterministic for one seed",
    rules.randomSpecies(state, "RATTATA", "wild") == first)
  main.onChoose(main.items[7], main)
  local confirmation = game.stack:top()
  check("START RUN uses a default-NO final safety confirmation",
    confirmation and confirmation.defaultNo == true
      and type(confirmation.choice) == "function")
  confirmation.choice(true)
  check("explicit START RUN permanently locks its rules",
    state.locked == true and state.lockReason == "explicit_start")
  unwindTo(main, 3)
  game.stack:pop()
  rules.open(game)
  U.wait(2)
  local locked = game.stack:top()
  check("locked run is visibly read-only",
    (language == "en" or language == "de")
      and locked and locked.footer == expectedReadOnly)
  local lockedState = SaveData.encode(state)
  local lockedRows = visibleRows(locked)
  for _, index in ipairs({ 1, 2, 3, 6, 7 }) do
    locked.onChoose(locked.items[index], locked)
    local restored = unwindTo(locked, 3)
    check(("locked main item %d returns to retained menu"):format(index),
      restored and game.stack:top() == locked)
    check(("locked main item %d leaves full state unchanged"):format(index),
      SaveData.encode(state) == lockedState)
    check(("locked main item %d leaves every visible row unchanged"):format(index),
      visibleRows(locked) == lockedRows)
  end

  locked.onChoose(locked.items[4], locked)
  local lockedRandomizer = game.stack:top()
  check("locked Randomizer menu has every rule and exact localized footer",
    lockedRandomizer and #lockedRandomizer.items == 9
      and lockedRandomizer.footer == expectedLocked)
  local lockedRandomizerRows = visibleRows(lockedRandomizer)
  for index = 1, 9 do
    lockedRandomizer.onChoose(
      lockedRandomizer.items[index], lockedRandomizer)
    local restored = unwindTo(lockedRandomizer, 3)
    check(("locked Randomizer item %d retains its exact menu"):format(index),
      restored and game.stack:top() == lockedRandomizer)
    check(("locked Randomizer item %d leaves full state unchanged"):format(index),
      SaveData.encode(state) == lockedState)
    check(("locked Randomizer item %d leaves every row unchanged"):format(index),
      visibleRows(lockedRandomizer) == lockedRandomizerRows)
  end
  game.stack:pop()

  locked.onChoose(locked.items[5], locked)
  local lockedNuzlocke = game.stack:top()
  check("locked Nuzlocke menu has every rule and exact localized footer",
    lockedNuzlocke and #lockedNuzlocke.items == 4
      and lockedNuzlocke.footer == expectedLocked)
  local lockedNuzlockeRows = visibleRows(lockedNuzlocke)
  for index = 1, 4 do
    lockedNuzlocke.onChoose(lockedNuzlocke.items[index], lockedNuzlocke)
    local restored = unwindTo(lockedNuzlocke, 3)
    check(("locked Nuzlocke item %d retains its exact menu"):format(index),
      restored and game.stack:top() == lockedNuzlocke)
    check(("locked Nuzlocke item %d leaves full state unchanged"):format(index),
      SaveData.encode(state) == lockedState)
    check(("locked Nuzlocke item %d leaves every row unchanged"):format(index),
      visibleRows(lockedNuzlocke) == lockedNuzlockeRows)
  end
  game.stack:pop()
  check("locked run screenshot",
    U.shot(game, dir .. "/04_run_rules_locked.png"))
  clearToOverworld()

  U.teleport(game, "VIRIDIAN_POKECENTER", 3, 4, "up")
  local outside = playerPcRows(false)
  local remoteRun
  for _, row in ipairs(outside or {}) do
    if row.label and row.label:find("ASC%-RUN") then remoteRun = row end
  end
  check("Pokemon Center Player PC has no duplicate ASC RUN row",
    remoteRun == nil)

  -- The focused release gate can stop after the bounded Lab-terminal contract.
  -- The historical second half below covers the separately owned Legacy
  -- Journey and evolves with its pact/bank policy; it must not invalidate a
  -- focused run-rules acceptance when those systems intentionally change.
  if os.getenv("RUN_RULES_ONLY") == "1" then
    local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
    result:write(((fail == 0 and "PASS" or "FAIL")
      .. "\npass=%d\nfail=%d\nscope=bedroom-run-rules\n")
      :format(pass, fail))
    result:close()
    U.log(("RUN RULES ONLY RESULT pass=%d fail=%d"):format(pass, fail))
    love.event.quit(fail == 0 and 0 or 1)
    return
  end

  -- Three complete, direct journeys prove persistent path seals and the
  -- finale. Unique player ids model three genuinely new save identities.
  game.save.party = {
    Pokemon.new(game.data, "BULBASAUR", 50),
    Pokemon.new(game.data, "PIKACHU", 50),
  }
  game.save.inventory = { POTION = 4 }
  game.save.money = 12000
  local avatars = { "RED", "BLUE", "GREEN" }
  for cycle, avatar in ipairs(avatars) do
    game.save.player.id = 65000 + cycle
    local prepared = journey.archive.beginJourney(game.save, {
      pact = "release_e2e",
      runRules = journey.archive.safeRunRulesSnapshot(game.save),
    })
    check(("journey %d archives the outgoing run"):format(cycle),
      prepared ~= nil)
    local fresh = journey.startFreshGame(game)
    check(("journey %d enters Oak directly without the title"):format(cycle),
      fresh and game.stack:top()
        and getmetatable(game.stack:top()) ~= TitleState)
    local legacy = journey.state(fresh)
    check(("journey %d unlocks Bank and wanderers immediately"):format(cycle),
      legacy and legacy.bankUnlocked and legacy.wanderersEnabled)
    if cycle == 1 then
      check("direct New Game+ Oak hand-off screenshot",
        U.shot(game, dir .. "/05_direct_oak_handoff.png"))
      if game.stack:top() ~= game.overworld then game.stack:pop() end
      journey.openBank(game)
      U.wait(2)
      local bank = game.stack:top()
      check("fresh journey opens the FireRed Legacy Bank",
        bank and bank.title and bank.title:find("LEGACY", 1, true)
          and #bank.items == 3)
      check("Legacy Bank screenshot",
        U.shot(game, dir .. "/06_legacy_bank.png"))
      game.stack:pop()
    end
    check(("journey %d selects the %s path"):format(cycle, avatar),
      journey.setAvatar(fresh, avatar))
    check(("journey %d seals the %s path"):format(cycle, avatar),
      journey.advancePath(fresh, 99, true))
    journey.archive.markRunStarted(fresh)
  end
  local profile = journey.profile()
  check("all three Legacy paths persist across fresh saves",
    profile.completedPaths.red and profile.completedPaths.blue
      and profile.completedPaths.green)
  check("three seals unlock the Legacy finale",
    journey.completeFinale(game.save))
  check("Legacy Pass persists in the profile", journey.profile().legacyPass)

  -- Package 3 owns the future door quest, but RC23 must expose the stable,
  -- consumable readiness seam after three seals plus the current-run Champ.
  game.save.hallOfFame = { { champion = true } }
  check("three seals plus the current-run Champ arm HEVO_DOOR_QUEST_READY",
    journey.hevoDoorQuestReady(game.save))
  check("the future door hook is consumable exactly once",
    journey.consumeHevoDoorQuest(game.save)
      and not journey.hevoDoorQuestReady(game.save))

  -- Start one more direct journey after all three seals. The real layered
  -- Oak script must now offer the earned Hoenn family while its original
  -- Kanto chose-flag/rival semantics stay untouched.
  game.save.player.id = 66023
  check("post-seal journey archives successfully",
    journey.archive.beginJourney(game.save, {
      pact = "earned_starter_e2e",
      runRules = journey.archive.safeRunRulesSnapshot(game.save),
    }))
  local rewardSave = journey.startFreshGame(game)
  U.wait(4)
  local torchicScript = MapScripts.talkScript(
    "OAKS_LAB", "TEXT_OAKSLAB_CHARMANDER_POKE_BALL")
  local torchicGive
  for _, command in ipairs(torchicScript or {}) do
    if command[1] == "give_pokemon" then torchicGive = command[2] end
  end
  check("the earned Red seal changes Oak's Fire ball to TORCHIC",
    torchicGive == "TORCHIC")
  check("the direct reward journey still bypasses the title",
    rewardSave and game.stack:top()
      and getmetatable(game.stack:top()) ~= TitleState)
  while game.stack:top() do game.stack:pop() end
  Screens.push(game, "DexEntryMenu", {
    species = "TORCHIC", forceOwned = true,
  })
  U.wait(12)
  check("earned Torchic Oak-card screenshot",
    U.shot(game, dir .. "/07_earned_torchic_oak_card.png"))

  U.log(("RUN RULES / LEGACY RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
