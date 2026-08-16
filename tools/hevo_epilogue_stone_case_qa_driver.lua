-- Connected real-LÖVE acceptance for the HEVO epilogue durability chain.
--
-- This is an authoritative end/journey harness, not a dungeon shortcut
-- exposed by the product.  It answers each already-tested puzzle through the
-- path module's public runtime API, then uses the real reward transaction,
-- native SaveData writes/reloads, physical final-seal A presses, Legacy
-- archive transitions, Oak's installed left-ball handler and the real Stone
-- Case UI.  It never calls the secret-claim or partner-grant APIs directly.
--
-- Required environment:
--   POKEPORT_VERSION=red
--   POKEPORT_IDENTITY=ka-hevo-epilogue-stone-case-20260811
--   POKEPORT_ONLY_MOD=kanto_ascendant
--   POKEPORT_DRIVER=<absolute path to this file>
--   POKEPORT_TOUCH=0 POKEPORT_SPEED=8
--   SHOT_DIR=<persistent qa/hevo_epilogue_stone_case_20260811 path>

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing HEVO epilogue proof outside the immutable package gate")
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local GBCFX = require("src.render.GBCFX")
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local Pipelines = require("src.render.Pipelines")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")
  local renderer = tostring(assert(os.getenv("QA_RENDERER"),
    "QA_RENDERER is required")):upper()
  local slot = "slothevoepilogue20260811"

  assert(identity == "ka65-final-hevo-epilogue-red-2d"
      or identity == "ka65-final-hevo-epilogue-red-full",
    "refusing a non-isolated HEVO epilogue identity")
  assert(GameVersion.get() == "red", "HEVO epilogue harness requires Red")
  assert(renderer == "2D" or renderer == "FULL",
    "QA_RENDERER must be 2D or FULL")
  if renderer == "FULL" then
    assert(game.mods.exports.DRAMALESS_SHAPE,
      "FULL epilogue requires the pinned DRAMALESS package")
  end
  local pipelineLevel=Pipelines.setLevel("voxel",renderer=="FULL" and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  assert(renderer=="FULL" and pipelineLevel>0
      or renderer=="2D" and pipelineLevel==0,
    "requested epilogue renderer did not activate")

  local api = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export is missing")
  local campaign = assert(api.hiddenEvolutionCampaign,
    "Hidden Evolution campaign export is missing")
  local modules = assert(campaign.modules or campaign.load(),
    "Hidden Evolution path modules are missing")
  local red, blue, green = assert(modules.RED), assert(modules.BLUE),
    assert(modules.GREEN)
  local journey = assert(api.legacyJourney, "Legacy Journey export is missing")
  local archive = assert(journey.archive, "Legacy archive export is missing")
  local adapter = assert(api.legacyDungeonAdapter,
    "Legacy dungeon adapter export is missing")
  local packages = assert(api.hevoPackages, "HEVO package export is missing")
  local starters = assert(api.legacyStarters,
    "Legacy starter export is missing")
  local characters = assert(api.extendedCharacters,
    "extended-character export is missing")
  local mega = assert(api.megaEvolution, "Mega runtime export is missing")

  local checks, receipt = 0, {}
  local function check(label, value)
    if not value then error("FAIL: " .. label, 2) end
    checks = checks + 1
    receipt[#receipt + 1] = "PASS\t" .. label
    U.log("PASS", label)
    return value
  end

  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end

  local function isText(value)
    return value and getmetatable(value) == TextBox
  end

  local function boxText(box)
    local lines = {}
    for _, page in ipairs(box and box.pages or {}) do
      for _, line in ipairs(page) do lines[#lines + 1] = line end
    end
    return table.concat(lines, "\n")
  end

  local function stableText(frames)
    return waitFor(function()
      local top = game.stack:top()
      return isText(top) and (top.done or top.waiting) and top or nil
    end, frames or 1600)
  end

  local function captureTextLine(needle, path)
    local box = assert(waitFor(function()
      local top = game.stack:top()
      return isText(top) and top or nil
    end, 900), "expected final-seal text")
    check("final-seal text contains " .. needle,
      boxText(box):find(needle, 1, true) ~= nil)
    for _ = 1, 1800 do
      assert(game.stack:top() == box,
        "final-seal text stopped being the active modal")
      local line = box.currentLine and box:currentLine() or ""
      if line:find(needle, 1, true)
          and box.charIndex >= #(box.codes or {}) then
        check("visible final-seal line captured for " .. needle,
          U.shot(game, path))
        return box
      end
      U.wait(1)
    end
    error("final-seal line never became visibly complete: " .. needle)
  end

  local function runnerBusy()
    return game.overworld and game.overworld.runner
      and game.overworld.runner:isRunning()
  end

  local function drain(frames)
    return waitFor(function()
      local top = game.stack:top()
      if top == game.overworld and not runnerBusy() then return true end
      if isText(top) then
        if top.done or top.waiting then
          U.tap(game, "a")
        else
          game.input.state.a = true
          U.wait(1)
          game.input.state.a = false
        end
      elseif top and getmetatable(top) == ChoiceBox then
        U.tap(game, "b")
      elseif top ~= game.overworld then
        U.tap(game, "b")
      else
        U.wait(1)
      end
      return nil
    end, frames or 2600) == true
  end

  local function journeyState()
    local bucket = game.save.modData and game.save.modData.kanto_ascendant
    return bucket and bucket.legacy_journey
  end

  local function countTruthy(values)
    local count = 0
    for _, value in pairs(values or {}) do
      if value == true then count = count + 1 end
    end
    return count
  end

  local function countKeys(values)
    local count = 0
    for _ in pairs(values or {}) do count = count + 1 end
    return count
  end

  local function enforceGbcfxOff()
    game.save.options = game.save.options or {}
    game.save.options.gbcfx = 0
    game.save.options.textSpeed = 1
    GBCFX.setLevel(0)
    check("GBCFX is hard OFF",
      GBCFX.level == 0 and not GBCFX.active())
  end

  local function reloadWritten(label)
    local loaded, recovered = SaveData.load()
    check(label .. " primary SaveData load succeeds", loaded ~= nil)
    check(label .. " does not require backup recovery", recovered == nil)
    game:restoreSave(loaded, recovered)
    U.wait(30)
    enforceGbcfxOff()
    check(label .. " active slot remains isolated",
      SaveData.activeSlot("red") == slot)
    return loaded
  end

  local function writeReload(label)
    check(label .. " writes the active save", game:writeSave())
    return reloadWritten(label)
  end

  local heroSpec = {
    RED = {
      key="red", stone="BLAZIKENITE", starter="TORCHIC",
      map="KA_HEVO_RED_SHRINE", object="KA_RED_GROUDON_SEAL",
      x=35, y=11, stand={x=34,y=11,facing="right"},
      shot="red/01_red_last_chance_blazikenite.png",
      catalog="red/02_red_next_journey_torchic_left_ball.png",
    },
    BLUE = {
      key="blue", stone="SWAMPERTITE", starter="MUDKIP",
      map="KA_HEVO_BLUE_KYOGRE_SHRINE",
      object="KA_HEVO_BLUE_KYOGRE_DOOR",
      x=19, y=3, stand={x=19,y=4,facing="up"},
      shot="blue/02_blue_last_chance_swampertite.png",
      catalog="blue/03_blue_next_journey_mudkip_left_ball.png",
      locked="blue/01_blue_before_matching_seal_locked.png",
      lockedNeedle="BLUE RIFT",
    },
    GREEN = {
      key="green", stone="SCEPTILITE", starter="TREECKO",
      map="KA_HEVO_GREEN_RAYQUAZA_SHRINE",
      object="KA_GREEN_RAYQUAZA_SEAL",
      x=45, y=11, stand={x=44,y=11,facing="right"},
      shot="green/02_green_last_chance_sceptilite.png",
      catalog="green/04_green_next_journey_treecko_left_ball.png",
      locked="green/01_green_before_matching_seal_locked.png",
      lockedNeedle="GREEN RIFT",
    },
  }

  local acquired = {}
  local function verifyStoneSet(label)
    local state = assert(mega.state(false), label .. " Mega state is missing")
    check(label .. " has the exact number of claimed stones",
      countTruthy(state.stones) == countTruthy(acquired))
    for stone in pairs(acquired) do
      check(label .. " retains " .. stone, state.stones[stone] == true)
    end
    for _, spec in pairs(heroSpec) do
      check(label .. " has no premature " .. spec.stone,
        acquired[spec.stone] == true or state.stones[spec.stone] ~= true)
    end
  end

  local function adjacentSeal(spec)
    U.teleport(game, spec.map, spec.stand.x, spec.stand.y,
      spec.stand.facing)
    U.wait(30)
    local ow = assert(game.overworld, "overworld is missing")
    local target
    for _, npc in ipairs(ow.npcs or {}) do
      if npc.def and npc.def.name == spec.object then target = npc break end
    end
    check(spec.object .. " exists on its real shrine map", target ~= nil)
    check(spec.object .. " retains its authored coordinate",
      target.cellX == spec.x and target.cellY == spec.y)
    check(spec.object .. " has a walkable physical approach",
      ow.map:isWalkableCell(spec.stand.x, spec.stand.y))
    check(spec.object .. " is one faced cell from the player",
      math.abs(ow.player.cellX - target.cellX)
        + math.abs(ow.player.cellY - target.cellY) == 1
        and ow.player.facing == spec.stand.facing)
    return target
  end

  local function physicalSealPress(spec)
    adjacentSeal(spec)
    local x, y = game.overworld.player.cellX, game.overworld.player.cellY
    U.tap(game, "a")
    check(spec.object .. " A press does not move the player",
      game.overworld.player.cellX == x and game.overworld.player.cellY == y)
  end

  local function stageCompletion(hero)
    local spec = heroSpec[hero]
    local before = countTruthy(acquired)
    check(hero .. " active-character authority is exact",
      journey.activeCharacter(game.save) == hero
        and characters.getPlayerCharacter() == hero)
    check(hero .. " secret is intentionally absent before completion",
      not adapter.hasSecret(game.save, hero)
        and not mega.hasStone(spec.stone))

    if hero == "RED" then
      for index = 1, 5 do
        local name = "KA_RED_STATUE_" .. index
        local question = assert(red.questionForStatue(game.save, name))
        check("RED public statue answer " .. index,
          red.answerStatue(game.save, name, question.id,
            question.answer) == true)
      end
      for _, name in ipairs({ "A", "B", "C" }) do
        check("RED public Strength socket " .. name,
          red.setBoulder(game.save, name) == true)
      end
      local ok, why = red.complete(game)
      check("RED real reward transaction completes: " .. tostring(why), ok)
    elseif hero == "BLUE" then
      for _, name in ipairs({
          "HALL", "ICE_NORTH", "ICE_DEEP", "DEPTHS_WEST", "DEPTHS_EAST",
        }) do
        local question = assert(blue.nextQuestion(name))
        check("BLUE public statue answer " .. name,
          blue.answer(name, question.id, question.correct) == true)
      end
      local granted, why = blue.claimAll(game)
      check("BLUE real reward transaction completes: " .. tostring(why),
        type(granted) == "table" and #granted == 5)
    else
      for index = 1, 5 do
        local question = assert(green.questionFor(game.save, index))
        check("GREEN public statue answer " .. index,
          green.answer(game.save, index, question.answer) == true)
      end
      local ok, why = green.complete(game)
      check("GREEN real reward transaction completes: " .. tostring(why), ok)
    end

    local profile = archive.profile()
    local persistent = assert(packages.persistent(game.save, false),
      hero .. " persistent HEVO state is missing")
    check(hero .. " completion archives only its matching path",
      profile.completedPaths[spec.key] == true
        and persistent.meta[hero] == true)
    check(hero .. " completion did not auto-grant its secret",
      persistent.secretUnlocks[hero] ~= true
        and persistent.permanentItems[spec.stone] ~= true
        and not mega.hasStone(spec.stone)
        and countTruthy(mega.state().stones) == before)

    -- Deliberately reload the adapter's own completion write without another
    -- save.  This is the vulnerable power-cycle boundary that RED/GREEN now
    -- reconstruct from dungeonLegacy.seals.
    reloadWritten(hero .. " completion-before-last-chance")
    check(hero .. " secret remains missed after completion reload",
      not adapter.hasSecret(game.save, hero)
        and not mega.hasStone(spec.stone))
    if hero == "RED" then
      check("RED reload reconstructs the final-seal completion marker",
        red.run(game.save, false).completed == true)
    elseif hero == "BLUE" then
      check("BLUE reload retains the open final shrine", blue.shrineOpen())
    else
      check("GREEN reload reconstructs the final-seal completion marker",
        green.progress(game.save).completed == true)
    end
  end

  local function claimAtFinalSeal(hero)
    local spec = heroSpec[hero]
    local before = countTruthy(mega.state().stones)
    physicalSealPress(spec)
    captureTextLine(spec.stone, dir .. "/" .. spec.shot)
    check(hero .. " last-chance contact returns cleanly", drain())
    acquired[spec.stone] = true
    check(hero .. " last-chance contact claims exactly its matching stone",
      adapter.hasSecret(game.save, hero)
        and mega.hasStone(spec.stone)
        and countTruthy(mega.state().stones) == before + 1)

    -- claimSecret wrote before showing the receipt; consume exactly that
    -- durable save, then retry the same physical object after reload.
    reloadWritten(hero .. " last-chance claim")
    verifyStoneSet(hero .. " post-claim reload")
    physicalSealPress(spec)
    local retry = assert(stableText(), hero .. " retry text is missing")
    check(hero .. " retry is an ordinary sealed-door teaser",
      boxText(retry):find(spec.stone, 1, true) == nil)
    check(hero .. " retry cannot double-grant the stone",
      countTruthy(mega.state().stones) == countTruthy(acquired))
    -- GREEN's ordinary retry chains into its black-door blackout.  Clear the
    -- disposable modal at the map boundary after proving the text/state.
    U.teleport(game, "PALLET_TOWN", 10, 12, "down")
    verifyStoneSet(hero .. " post-retry")
  end

  local function prepareLateGame(hero)
    local beforeRing = game.save.inventory.MEGA_RING
    local beforeCase = game.save.inventory.MEGA_STONE_CASE
    check(hero .. " fresh source starts without duplicate Mega key items",
      beforeRing == nil and beforeCase == nil)
    game.save.flags = game.save.flags or {}
    game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
    check(hero .. " source is a real Legacy-eligible late-game save",
      archive.isEligible(game.save) and mega.available(game))
    mega.unlock(game)
    check(hero .. " late-game source receives one Ring and one Stone Case",
      game.save.inventory.MEGA_RING == 1
        and game.save.inventory.MEGA_STONE_CASE == 1)
    mega.unlock(game)
    check(hero .. " repeated Stone Case unlock is idempotent",
      game.save.inventory.MEGA_RING == 1
        and game.save.inventory.MEGA_STONE_CASE == 1)
    writeReload(hero .. " late-game Stone Case")
    verifyStoneSet(hero .. " late-game source")
  end

  local function newJourney(hero, playerId)
    local oldProfile = archive.profile()
    check("source save is eligible before next " .. hero .. " Journey",
      archive.isEligible(game.save))
    check("source save is durable before next " .. hero .. " Journey",
      game:writeSave())
    local current, err = archive.beginJourney(game.save, {
      pact = "journey", playerAvatar = journey.activeCharacter(game.save),
      runRules = archive.safeRunRulesSnapshot(game.save),
    })
    check("archive begins next " .. hero .. " Journey: " .. tostring(err),
      current ~= nil)
    local fresh = journey.startFreshGame(game)
    fresh.player.id = playerId
    fresh.player.name = hero
    fresh.player.rival = hero == "RED" and "BLUE" or "RED"
    enforceGbcfxOff()
    check(hero .. " Fresh Save is seeded from the archive",
      journey.isActive(fresh) and journeyState()
        and journeyState().cycle == oldProfile.cycle + 1)
    check(hero .. " Fresh Save first write activates the archive run",
      game:writeSave())
    check(hero .. " Fresh Save binds the requested avatar",
      archive.setAvatar(fresh, hero) == true)
    characters.select(hero)
    check(hero .. " selector and archive agree before reload",
      journey.activeCharacter(fresh) == hero
        and characters.getPlayerCharacter() == hero)
    writeReload(hero .. " Fresh Legacy Journey")
    local profile = archive.profile()
    check(hero .. " Journey advances exactly one archive cycle",
      profile.cycle == oldProfile.cycle + 1
        and profile.current.status == "active")
    check(hero .. " Journey survives SaveData reload",
      journey.activeCharacter(game.save) == hero
        and characters.getPlayerCharacter() == hero)
    verifyStoneSet(hero .. " Fresh Journey reconciliation")
  end

  local function stageOakRivalBall(hero)
    local state = assert(journeyState(), hero .. " Legacy state is missing")
    game.save.flags = game.save.flags or {}
    game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
    game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON = true
    U.teleport(game, "OAKS_LAB", 5, 5, "up")
    check(hero .. " real Oak scene durably assigns the rival's right ball",
      waitFor(function()
        return state.rivalBallTaken == true
          and game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN == true
      end, 1800) ~= nil)
    check(hero .. " rival-ball scene returns to the real lab", drain(2800))
    check(hero .. " rival-ball scene grants no player partner",
      #game.save.party == 0 and not state.partnerChosen
        and state.partnerSpecies == nil)
  end

  local function physicalLeftBall()
    U.teleport(game, "OAKS_LAB", 6, 4, "up")
    U.wait(20)
    local beforeX, beforeY = game.overworld.player.cellX,
      game.overworld.player.cellY
    U.tap(game, "a")
    check("physical Oak left-ball A press does not move the player",
      game.overworld.player.cellX == beforeX
        and game.overworld.player.cellY == beforeY)
  end

  local function waitCatalog()
    return waitFor(function()
      local top = game.stack:top()
      return getmetatable(top) == starters.Catalog and top or nil
    end, 1200)
  end

  local function noPartnerGranted(hero)
    local state = assert(journeyState())
    return #game.save.party == 0
      and countKeys(game.save.pokedex and game.save.pokedex.seen) == 0
      and countKeys(game.save.pokedex and game.save.pokedex.owned) == 0
      and not state.partnerChosen and state.partnerSpecies == nil
      and not game.save.flags.EVENT_GOT_STARTER
  end

  local function proveMatchingOakBall(hero)
    local spec = heroSpec[hero]
    stageOakRivalBall(hero)
    check(hero .. " matching archived seal unlocks the left ball",
      starters.hoennUnlocked(game.save)
        and starters.heroChoice(game.save).species == spec.starter)
    physicalLeftBall()
    local catalog = assert(waitCatalog(), hero .. " Hoenn catalog did not open")
    check(hero .. " left ball shows exactly one matching Hoenn starter",
      catalog.mode == "hoenn" and catalog.modeLocked
        and #catalog.rows == 1 and catalog:current().id == spec.starter)
    check(hero .. " matching left-ball catalog capture",
      U.shot(game, dir .. "/" .. spec.catalog))
    U.tap(game, "b")
    check(hero .. " canceled catalog returns without a grant", drain())
    check(hero .. " catalog display performs no automatic grant",
      noPartnerGranted(hero))
    writeReload(hero .. " canceled matching Oak catalog")
    physicalLeftBall()
    local retry = assert(waitCatalog(), hero .. " reload catalog did not reopen")
    check(hero .. " reload still exposes only its one matching starter",
      retry.mode == "hoenn" and retry.modeLocked
        and #retry.rows == 1 and retry:current().id == spec.starter)
    U.tap(game, "b")
    check(hero .. " reload catalog retry returns cleanly", drain())
    check(hero .. " reload/retry still cannot auto- or double-grant",
      noPartnerGranted(hero))
    check(hero .. " no-grant Oak state persists", game:writeSave())
  end

  local function switchHeroBeforeSeal(hero)
    local spec = heroSpec[hero]
    local state = assert(journeyState())
    check(hero .. " switch occurs before this Journey path starts",
      tonumber(state.avatarQuestStage or 0) == 0
        and state.pathComplete ~= true)
    check(hero .. " archive accepts the pre-path avatar switch",
      archive.setAvatar(game.save, hero) == true)
    characters.select(hero)
    writeReload(hero .. " pre-path avatar switch")
    check(hero .. " earlier colors do not unlock this hero's left ball",
      not starters.hoennUnlocked(game.save)
        and starters.heroChoice(game.save).species == spec.starter)
    physicalLeftBall()
    captureTextLine(spec.lockedNeedle, dir .. "/" .. spec.locked)
    check(hero .. " locked left ball opens text, never a catalog",
      getmetatable(game.stack:top()) == TextBox
        and noPartnerGranted(hero))
    check(hero .. " locked left-ball interaction returns cleanly", drain())
  end

  local function captureStoneCase()
    local state = assert(mega.state(false), "final Mega state is missing")
    check("final Stone Case owns exactly three stones",
      countTruthy(state.stones) == 3
        and state.stones.BLAZIKENITE
        and state.stones.SWAMPERTITE
        and state.stones.SCEPTILITE)
    check("final bag still has exactly one Ring and Stone Case",
      game.save.inventory.MEGA_RING == 1
        and game.save.inventory.MEGA_STONE_CASE == 1)
    local closed = false
    mega.stoneMenu(game, function() closed = true end)
    local menu = assert(game.stack:top(), "Stone Case menu did not open")
    local wanted = { BLAZIKEN=0, SWAMPERT=0, SCEPTILE=0 }
    local sceptileIndex
    for index, item in ipairs(menu.items or {}) do
      if wanted[item.label] ~= nil then
        wanted[item.label] = wanted[item.label] + 1
        check(item.label .. " Stone Case row visibly reads OWN",
          item.right == "OWN")
        if item.label == "SCEPTILE" then sceptileIndex = index end
      end
    end
    check("Stone Case contains each HEVO Mega row exactly once",
      wanted.BLAZIKEN == 1 and wanted.SWAMPERT == 1
        and wanted.SCEPTILE == 1 and sceptileIndex ~= nil)
    while menu.index < sceptileIndex do U.tap(game, "down") end
    check("Stone Case cursor reaches the three-row evidence window",
      menu.index == sceptileIndex)
    check("all-three Stone Case capture",
      U.shot(game, dir .. "/green/03_stone_case_all_three_exactly_once.png"))
    U.tap(game, "b")
    check("Stone Case closes through its real cancel callback",
      closed and game.stack:top() == game.overworld)
    writeReload("final three-stone Stone Case")
    verifyStoneSet("final Stone Case reload")
  end

  -- Refuse to append evidence to a stale archive/identity.  This driver is a
  -- single bounded run by design.
  local initialProfile = archive.profile()
  check("isolated Legacy archive starts at cycle zero",
    initialProfile.cycle == 0
      and not initialProfile.completedPaths.red
      and not initialProfile.completedPaths.blue
      and not initialProfile.completedPaths.green)
  check("isolated active slot is selected",
    SaveData.setActiveSlot("red", slot) == slot)

  local source = SaveData.newGame(game:bootConfig())
  source.player.id = 6700
  source.player.name, source.player.rival = "RED", "BLUE"
  game.save = source
  game:adoptSave(source)
  Runtime.emit("save.created", { save = source })
  characters.select("RED")
  enforceGbcfxOff()
  U.teleport(game, source.player.map, source.player.x, source.player.y,
    source.player.facing)
  U.wait(20)
  check("original RED source is not already a Legacy Journey",
    not journey.isActive(game.save))
  prepareLateGame("RED")
  stageCompletion("RED")
  claimAtFinalSeal("RED")

  newJourney("RED", 6701)
  proveMatchingOakBall("RED")
  switchHeroBeforeSeal("BLUE")
  prepareLateGame("BLUE")
  stageCompletion("BLUE")
  claimAtFinalSeal("BLUE")

  newJourney("BLUE", 6702)
  proveMatchingOakBall("BLUE")
  switchHeroBeforeSeal("GREEN")
  prepareLateGame("GREEN")
  stageCompletion("GREEN")
  claimAtFinalSeal("GREEN")
  captureStoneCase()

  newJourney("GREEN", 6703)
  proveMatchingOakBall("GREEN")

  local finalProfile = archive.profile()
  check("all three paths are archived after the connected sequence",
    finalProfile.completedPaths.red
      and finalProfile.completedPaths.blue
      and finalProfile.completedPaths.green)
  check("final active Journey is the matching GREEN successor",
    finalProfile.cycle == 3
      and journey.activeCharacter(game.save) == "GREEN")
  check("final playable save remains grant-free at Oak's left ball",
    noPartnerGranted("GREEN"))
  verifyStoneSet("final GREEN successor")

  os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
  local out = assert(io.open(dir .. "/runtime_assertions.txt", "w"))
  out:write(("HEVO EPILOGUE / STONE CASE / HOENN GATE PASS: %d assertions\n")
    :format(checks))
  out:write("identity=" .. identity .. "\n")
  out:write("slot=" .. slot .. "\n")
  out:write("version=red\nGBCFX=0\nrenderer="..renderer.."\n")
  out:write("final_cycle=" .. tostring(finalProfile.cycle) .. "\n")
  out:write("final_avatar=GREEN\n")
  out:write("stones=BLAZIKENITE,SWAMPERTITE,SCEPTILITE\n")
  out:write("oak_left_ball=TORCHIC->MUDKIP->TREECKO; display-only; no grants\n")
  out:write(table.concat(receipt, "\n"), "\n")
  out:close()
  U.log(("HEVO EPILOGUE PASS: %d assertions; runtime FREE on exit")
    :format(checks))
  love.event.quit(0)
end
