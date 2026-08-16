-- Focused RC28-MANUAL-018 acceptance.  This driver owns a disposable save
-- identity, stages Hall + the current RED fissure through the production
-- completion/black-door seams, then walks the real Lab-PC -> Oak -> Pact ->
-- Bank-rule UI.  It stops at the REISE Bank menu: no archive transaction,
-- reset, or fresh Legacy Journey is allowed.

return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL is required"))
  local SaveData = require("src.core.SaveData")
  local Serializer = require("src.core.SaveSerializer")
  local Runtime = require("src.mods.Runtime")
  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")
  local GameVersion = require("src.core.GameVersion")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")
  assert(identity:match("^ka%-rc28%-manual%-018%-"),
    "refusing non-disposable identity: " .. identity)
  assert(GameVersion.get() == "red", "focused proof requires Red edition")

  local api = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local journey = assert(api.legacyJourney, "Legacy Journey export missing")
  local characters = assert(api.extendedCharacters,
    "extended character export missing")
  local adapter = assert(api.legacyDungeonAdapter,
    "Hidden-Evolution adapter missing")
  local shared = assert(api.hiddenEvolutionCampaign
      and api.hiddenEvolutionCampaign.modules
      and api.hiddenEvolutionCampaign.modules.shared,
    "shared final-door authority missing")
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    return value
  end
  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
  end
  local function isText(value)
    return value and getmetatable(value) == TextBox
  end
  local function menu(title)
    local top = game.stack:top()
    if not (top and type(top.items) == "table") then return nil end
    if title and not tostring(top.title or ""):find(title, 1, true) then
      return nil
    end
    return top
  end
  local function settleText(box)
    for _ = 1, 700 do
      if box.waiting or box.done then return true end
      game.input.state.a = true
      U.wait(1)
      game.input.state.a = false
    end
    return false
  end
  local function advanceTextTo(predicate, frames)
    return waitFor(function()
      local wanted = predicate()
      if wanted then return wanted end
      local top = game.stack:top()
      if isText(top) then
        if top.waiting or top.done then U.tap(game, "a")
        else
          game.input.state.a = true
          U.wait(1)
          game.input.state.a = false
        end
      elseif top and top ~= game.overworld then
        U.tap(game, "a")
      else
        U.wait(1)
      end
    end, frames or 2400)
  end
  local function drainToOverworld(frames)
    return advanceTextTo(function()
      return game.stack:top() == game.overworld and true or nil
    end, frames or 3000) == true
  end
  local function labels(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do out[#out + 1] = tostring(row.label) end
    return table.concat(out, ",")
  end
  local function values(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do out[#out + 1] = tostring(row.value) end
    return table.concat(out, ",")
  end
  local function findRow(rows, needle)
    for index, row in ipairs(rows or {}) do
      if tostring(row.label):find(needle, 1, true) then return index end
    end
  end
  local function selectRow(current, index)
    assert(current and index, "missing menu selection")
    local guard = 0
    while current.index ~= index do
      guard = guard + 1
      assert(guard <= #current.items + 1, "menu cursor did not reach row")
      U.tap(game, "down")
      U.wait(3)
    end
    U.wait(3)
    U.tap(game, "a")
    U.wait(4)
    return game.stack:top() ~= current
  end
  local function semanticBytes(save)
    local copy = assert(Serializer.decode(Serializer.encode(save)))
    copy.playTime = nil
    return Serializer.encode(copy)
  end

  local slot = "slotrc28manual018"
  assert(SaveData.setActiveSlot("red", slot) == slot,
    "could not reserve disposable Legacy slot")
  local fresh = SaveData.newGame(game:bootConfig())
  game.save = fresh
  game:adoptSave(fresh)
  Runtime.emit("save.created", { save = fresh })
  characters.select("RED")
  game.save.player.name, game.save.player.rival = "ROT", "BLAU"
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 52) }
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.hallOfFame = { { name = "ROT", character = "RED" } }
  game.save.options.textSpeed = 1
  game:adoptSave(game.save)
  -- The adapter refreshes the live map after recording a completion.  Enter a
  -- harmless overworld cell first so this is the same production boundary as
  -- play, not a controller call made while the title stack owns no map.
  U.teleport(game, "PALLET_TOWN", 12, 12, "up")
  U.wait(20)
  check("disposable clone has a real Hall record",
    journey.archive.isEligible(game.save) == true)

  local sealed, sealResult = adapter.finalize(game, {
    character = "RED", questionIds = { "RC28_MANUAL_018" },
  })
  check("production completion boundary records this clone's RED seal",
    sealed == true and sealResult and sealResult.character == "RED"
      and journey.currentHevoSeal(game.save, "RED") == true)
  check("seal alone does not unlock Legacy Journey",
    journey.canBegin(game.save) == false)
  check("production shared black-door seam starts", shared.doorInteraction(game))
  check("black-door/Oak sequence returns to play", drainToOverworld(4200))
  local ready, owner = journey.canBegin(game.save)
  check("Hall + own seal + own door arm only RED's Legacy gate",
    ready == true and owner == "RED"
      and game.save.flags[journey.HEVO_READY_FLAG] == true
      and game.save.flags[journey.HEVO_OAK_CALLED_FLAG] == true)

  U.teleport(game, "OAKS_LAB", 1, 2, "up")
  U.wait(30)
  local beforeSave = semanticBytes(game.save)
  local beforeProfile = Serializer.encode(journey.profile())
  local originalWriteSave = game.writeSave
  local writes = 0
  game.writeSave = function(self, ...)
    writes = writes + 1
    return originalWriteSave(self, ...)
  end
  U.tap(game, "a")
  local pc = waitFor(function() return menu() end, 900)
  local beginIndex = pc and findRow(pc.items, "REISE STARTEN")
  check("physical Lab PC exposes INFO and REISE STARTEN",
    pc and findRow(pc.items, "LEGACY-INFO") and beginIndex)
  check("Lab-PC screenshot", pc and U.shot(game,
    dir .. "/01_lab_pc_legacy_ready.png"))
  check("REISE STARTEN leaves the PC menu", selectRow(pc, beginIndex))

  local oakText = waitFor(function()
    local top = game.stack:top()
    return isText(top) and top or nil
  end, 1200)
  local oakPortrait
  for _, state in ipairs(game.stack.states or {}) do
    if state ~= oakText and state.image and state.trueColor == true then
      oakPortrait = state
    end
  end
  check("Oak visibly hosts the Pact hand-off",
    oakText ~= nil and oakPortrait ~= nil and settleText(oakText))
  local pactMenu = advanceTextTo(function()
    return menu("EICH: PAKTWAHL")
  end, 3000)
  check("Oak's live menu exposes all four independent Pacts",
    pactMenu and values(pactMenu.items)
      == "journey,trainer,legacy,ascendant"
      and labels(pactMenu.items):find("REISE", 1, true)
      and labels(pactMenu.items):find("VERMÄCHTNIS", 1, true))
  check("four-Pact screenshot", pactMenu and U.shot(game,
    dir .. "/02_oak_four_pacts.png"))

  check("selecting REISE opens its separate Bank choice",
    selectRow(pactMenu, 1))
  local bankMenu = advanceTextTo(function()
    return menu("EICH: BANKREGEL")
  end, 3000)
  check("REISE exposes all four independent Bank rules",
    bankMenu and values(bankMenu.items) == "open,badges4,league,sealed"
      and labels(bankMenu.items) == "OFFEN,AB 4 ORDEN,NACH LIGA,VERSIEGELT")
  check("REISE Bank-rule screenshot", bankMenu and U.shot(game,
    dir .. "/03_reise_four_bank_rules.png"))

  -- Abort before even the first summary/confirmation.  The product must not
  -- write, archive, create a run, or alter any semantic save field.
  if bankMenu then U.tap(game, "b"); U.wait(8) end
  game.writeSave = originalWriteSave
  local bucket = game.save.modData and game.save.modData.kanto_ascendant
  check("pre-confirmation abort writes and starts nothing",
    writes == 0 and not (bucket and bucket.legacy_journey)
      and Serializer.encode(journey.profile()) == beforeProfile
      and semanticBytes(game.save) == beforeSave
      and journey.canBegin(game.save) == true)

  local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
  result:write(fail == 0 and "PASS\n" or "FAIL\n")
  result:write(("pass=%d\nfail=%d\nidentity=%s\nslot=%s\n")
    :format(pass, fail, identity, slot))
  result:write("scope=LAB_PC_OAK_4_PACTS_REISE_4_BANK_RULES\n")
  result:write("final_confirmation_reached=false\n")
  result:write("archive_transaction=false\n")
  result:close()
  love.event.quit(fail == 0 and 0 or 1)
end
