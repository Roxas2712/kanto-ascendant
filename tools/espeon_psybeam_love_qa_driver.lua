-- Real-engine/LÖVE acceptance for RC65-ESPEON-PSYBEAM.
--
-- This driver loads the Authority mod through Gen1Recomp's normal loader,
-- feeds a real Rare Candy through BagMenu, and operates the actual Route-5
-- Day-Care machine with controller inputs. It deliberately does not replace
-- the level-up or Move Reminder implementation with a test double.
--
-- Example (from the Gen1Recomp checkout):
--   POKEPORT_ONLY_MOD=0000_ka_rc11_integration POKEPORT_VERSION=red \
--   POKEPORT_IDENTITY=rc65-espeon-psybeam POKEPORT_TOUCH=0 POKEPORT_SPEED=4 \
--   POKEPORT_DRIVER=mods/0000_ka_rc11_integration/tools/espeon_psybeam_love_qa_driver.lua \
--   KA_TEST_UTIL=tests/drivers/util.lua SHOT_DIR=/tmp/rc65-espeon-psybeam \
--   love .

return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL is required"))
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local Pokemon = require("src.pokemon.Pokemon")
  local Experience = require("src.battle.Experience")
  local Bag = require("src.inventory.Bag")
  local Screens = require("src.ui.Screens")
  local SaveData = require("src.core.SaveData")
  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant,
    "Authority Kanto Ascendant export missing")
  local daycare = assert(exports.daycare, "production Day-Care export missing")
  local fieldTech = assert(exports.fieldTech,
    "production Move Reminder export missing")
  local pass, fail = 0, 0

  local function check(label, value, detail)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label, detail or "")
    return value
  end

  local function waitFor(predicate, frames)
    for _ = 1, frames or 900 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end

  local function top()
    return game.stack:top()
  end

  local function isText(value)
    return value and type(value.pages) == "table"
  end

  local function isChoice(value)
    return value and value.index and value.onChoose and not value.mon
      and not value.items
  end

  local function pagesText(value)
    local parts = {}
    for _, page in ipairs(value and value.pages or {}) do
      if type(page) == "table" then
        for _, line in ipairs(page) do
          if type(line) == "string" then parts[#parts + 1] = line end
        end
      elseif type(page) == "string" then
        parts[#parts + 1] = page
      end
    end
    return table.concat(parts, " ")
  end

  local function stackState(predicate)
    for _, state in ipairs(game.stack.states or {}) do
      if predicate(state) then return state end
    end
  end

  local function hasMove(mon, id)
    for _, move in ipairs(mon and mon.moves or {}) do
      if move.id == id then return true end
    end
    return false
  end

  local function scheduleSignature(def)
    local rows = {}
    for _, id in ipairs(def and def.level1Moves or {}) do
      rows[#rows + 1] = "1:" .. tostring(id)
    end
    for _, row in ipairs(def and def.learnset or {}) do
      rows[#rows + 1] = tostring(row.level) .. ":" .. tostring(row.move)
    end
    return table.concat(rows, ";")
  end

  local function moveRowCount(def, level, id)
    local count = 0
    for _, row in ipairs(def and def.learnset or {}) do
      if row.level == level and row.move == id then count = count + 1 end
    end
    return count
  end

  local function clearToOverworld()
    for _ = 1, 180 do
      if top() == game.overworld then return true end
      local current = top()
      if not current then return false end
      U.tap(game, "b")
      U.wait(1)
    end
    return top() == game.overworld
  end

  local function listHas(menu, value)
    for _, item in ipairs(menu and menu.items or {}) do
      if (item.value or item.id) == value then return true end
    end
    return false
  end

  local function chooseListValue(menu, value)
    local index
    for i, item in ipairs(menu and menu.items or {}) do
      if item.value == value then index = i break end
    end
    if not index then return false end
    while menu.index ~= index do
      local delta = index - menu.index
      U.tap(game, delta > 0 and "down" or "up")
      U.wait(1)
    end
    U.tap(game, "a")
    U.wait(2)
    return true
  end

  local function choosePartyIndex(index)
    local partyMenu = waitFor(function()
      local value = top()
      return value and value.screenId == "PartyMenu" and value or nil
    end, 240)
    if not partyMenu then return nil end
    while partyMenu.index ~= index do
      U.tap(game, "down")
      U.wait(1)
    end
    U.tap(game, "a")
    U.wait(2)
    return partyMenu
  end

  local function findLiveMachine()
    for _, npc in ipairs(game.overworld and game.overworld.npcs or {}) do
      if npc.def and npc.def.name == daycare.machineName then return npc end
    end
  end

  local facingCells = {
    { dx = 0, dy = 1, facing = "up" },
    { dx = 0, dy = -1, facing = "down" },
    { dx = 1, dy = 0, facing = "left" },
    { dx = -1, dy = 0, facing = "right" },
  }

  local function faceMachine(machine)
    local ow = game.overworld
    for _, cell in ipairs(facingCells) do
      local x, y = machine.cellX + cell.dx, machine.cellY + cell.dy
      if ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y)
          and not ow:npcAtCell(x, y) and not ow.map:warpAtCell(x, y) then
        ow.player.cellX, ow.player.cellY = x, y
        ow.player.px, ow.player.py = x * 16, y * 16
        ow.player.targetX, ow.player.targetY = nil, nil
        ow.player.moving, ow.player.facing = false, cell.facing
        return true
      end
    end
    return false
  end

  local function openReminderFor(mon)
    game.save.party = { mon }
    U.teleport(game, "DAYCARE", 3, 3, "down")
    U.wait(20)
    local machine = assert(waitFor(findLiveMachine, 180),
      "live Route-5 evolution machine did not spawn")
    assert(faceMachine(machine), "no walkable cell faces the live machine")
    U.tap(game, "a") -- real Overworld.talkTo -> Day-Care machine handler
    local machineMenu = assert(waitFor(function()
      local value = top()
      return value and value.items and listHas(value, "remember")
        and value or nil
    end, 240), "machine menu did not open from physical A interaction")
    assert(chooseListValue(machineMenu, "remember"),
      "machine menu has no Move Reminder row")
    assert(choosePartyIndex(1), "Move Reminder party picker did not open")
    return waitFor(function()
      local value = top()
      return value and value.items and value.title
        and (value.title == "REMEMBER WHICH?"
          or value.title == "WELCHE ERINNERN?") and value or nil
    end, 240)
  end

  local function captureTextContaining(needle, path, frames)
    local box = waitFor(function()
      local value = top()
      if isText(value) and pagesText(value):find(needle, 1, true) then
        return value
      end
    end, frames or 600)
    if not box then return nil end
    for _ = 1, 12 do
      waitFor(function() return box.waiting or box.done end, 360)
      local page = box.pages and box.pages[box.pageIndex] or {}
      if table.concat(page, " "):find(needle, 1, true) then
        return U.shot(game, path) and box or nil
      end
      if top() ~= box or box.done then break end
      U.tap(game, "a")
      U.wait(1)
    end
    return nil
  end

  local function drainTextUntil(predicate, frames)
    for _ = 1, frames or 900 do
      local value = predicate and predicate()
      if value then return value end
      local current = top()
      if isText(current) and (current.waiting or current.done) then
        U.tap(game, "a")
      elseif current and current.mon and current.onDone
          and not current.pages and not current.newMoveId then
        -- BagMenu pushes BattleState.StatBox directly rather than through
        -- Screens.push, so it intentionally has no screenId.
        U.tap(game, "a")
      else
        U.wait(1)
      end
    end
    return predicate and predicate() or nil
  end

  U.wait(20)
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1

  -- Full-main catalog and no-collateral contract.
  local espeonDef = assert(game.data.pokemon.ESPEON,
    "Espeon missing after full Authority load")
  check("full-main Espeon has exactly one level-36 PSYBEAM",
    moveRowCount(espeonDef, 36, "PSYBEAM") == 1)
  check("full-main Espeon has no erroneous level-30 PSYCHIC",
    moveRowCount(espeonDef, 30, "PSYCHIC_M") == 0)
  check("full-main Espeon restores level-47 PSYCHIC",
    moveRowCount(espeonDef, 47, "PSYCHIC_M") == 1)
  local exact = Experience.movesLearnedAt(espeonDef, 36)
  check("engine exact-level resolver offers only PSYBEAM at 36",
    #exact == 1 and exact[1] == "PSYBEAM")
  check("engine exact-level resolver offers nothing at 35",
    #Experience.movesLearnedAt(espeonDef, 35) == 0)

  local importedPokemon = assert(os.getenv("KA_IMPORTED_POKEMON"),
    "KA_IMPORTED_POKEMON pinned package-cache path is required")
  assert(importedPokemon:sub(1, 1) == "/"
      and not importedPokemon:find(".worktrees", 1, true)
      and not importedPokemon:find("/Documents/Recompile/", 1, true),
    "base RBY schedule must come from the materialized imported cache")
  local basePokemon = assert(loadfile(importedPokemon),
    "pinned imported RBY pokemon table unavailable")()
  local untouched, kantoCount = true, 0
  for species, base in pairs(basePokemon) do
    if tonumber(base.dex) and base.dex >= 1 and base.dex <= 151 then
      kantoCount = kantoCount + 1
      if scheduleSignature(game.data.pokemon[species])
          ~= scheduleSignature(base) then untouched = false break end
    end
  end
  check("all 151 full-main Kanto schedules remain byte-equivalent to RBY",
    untouched and kantoCount == 151, "checked=" .. tostring(kantoCount))
  local noPsybeamResonance = exports.driftglassPrisms
    and exports.driftglassPrisms.resonanceRules.ESPEON == nil
  for _, rules in pairs(exports.driftglassPrisms
      and exports.driftglassPrisms.resonanceRules or {}) do
    if rules.PSYBEAM then noPsybeamResonance = false break end
  end
  check("PSYBEAM does not leak through Johto Move Resonance",
    noPsybeamResonance)

  -- A real Bag/Rare-Candy UI run proves the exact level-up presentation and
  -- teaching transaction, including MoveLearnMenu's full-moveset branch.
  local levelUpMon = Pokemon.new(game.data, "ESPEON", 35)
  levelUpMon.moves = {
    { id = "TACKLE", pp = game.data.moves.TACKLE.pp },
    { id = "TAIL_WHIP", pp = game.data.moves.TAIL_WHIP.pp },
    { id = "CONFUSION", pp = game.data.moves.CONFUSION.pp },
    { id = "QUICK_ATTACK", pp = game.data.moves.QUICK_ATTACK.pp },
  }
  game.save.party = { levelUpMon }
  game.save.inventory, game.save.bagOrder = {}, {}
  Bag.add(game.save, "RARE_CANDY", 1, game.data)
  U.teleport(game, "ROUTE_5", 8, 8, "down")
  Screens.push(game, "BagMenu", {})
  U.wait(4)
  U.tap(game, "a") -- RARE CANDY
  U.wait(2)
  U.tap(game, "a") -- USE
  assert(choosePartyIndex(1), "Rare Candy party picker did not open")
  local learnMenu = drainTextUntil(function()
    return stackState(function(value)
      return value.screenId == "MoveLearnMenu" and value.newMoveId
        and value or nil
    end)
  end, 900)
  check("real Rare-Candy path reaches MoveLearnMenu at level 36",
    levelUpMon.level == 36 and learnMenu ~= nil,
    "level=" .. tostring(levelUpMon.level))
  check("real level-up UI offers exactly PSYBEAM",
    learnMenu and learnMenu.newMoveId == "PSYBEAM",
    learnMenu and learnMenu.newMoveId)
  local offerShot = captureTextContaining("PSYBEAM",
    dir .. "/01_level36_psybeam_offer.png", 480)
  check("level-36 PSYBEAM offer screenshot", offerShot ~= nil)

  -- Move through the real YES choice and replacement picker. The native menu
  -- retains its MoveLearnMenu state underneath each text box.
  local choice = drainTextUntil(function()
    return isChoice(top()) and top() or nil
  end, 720)
  check("level-up PSYBEAM confirmation appears", choice ~= nil)
  if choice then U.tap(game, "a") end -- YES
  local selecting = waitFor(function()
    local value = top()
    return value == learnMenu and value.selecting and value or nil
  end, 240)
  check("level-up replacement picker appears", selecting ~= nil)
  if selecting then U.tap(game, "a") end -- replace first move
  local learnedBox = captureTextContaining("PSYBEAM",
    dir .. "/02_level36_psybeam_learned.png", 600)
  check("level-up learned-PSYBEAM screenshot", learnedBox ~= nil)
  drainTextUntil(function() return hasMove(levelUpMon, "PSYBEAM") end, 480)
  check("real level-up transaction teaches PSYBEAM",
    hasMove(levelUpMon, "PSYBEAM"))
  clearToOverworld()

  local function reminderMon(level)
    local mon = Pokemon.new(game.data, "ESPEON", level)
    mon.moves = {
      { id = "TACKLE", pp = game.data.moves.TACKLE.pp },
      { id = "TAIL_WHIP", pp = game.data.moves.TAIL_WHIP.pp },
      { id = "CONFUSION", pp = game.data.moves.CONFUSION.pp },
    }
    return mon
  end

  -- Lv35: the actual Route-5 screen opens, but PSYBEAM is absent.
  local low = reminderMon(35)
  local lowMenu = assert(openReminderFor(low),
    "level-35 Reminder candidates did not open")
  check("Route-5 Reminder keeps PSYBEAM locked at level 35",
    not listHas(lowMenu, "PSYBEAM"))
  check("level-35 Reminder gate screenshot",
    U.shot(game, dir .. "/03_reminder_level35_locked.png"))
  U.tap(game, "b")
  clearToOverworld()

  local function teachThroughReminder(mon, levelLabel, offerPath, learnedPath)
    local menu = assert(openReminderFor(mon),
      levelLabel .. " Reminder candidates did not open")
    check("Route-5 Reminder offers PSYBEAM at " .. levelLabel,
      listHas(menu, "PSYBEAM"))
    check(levelLabel .. " PSYBEAM offer screenshot",
      U.shot(game, offerPath))
    assert(chooseListValue(menu, "PSYBEAM"),
      levelLabel .. " PSYBEAM row cannot be selected")
    local learned = captureTextContaining("PSYBEAM", learnedPath, 600)
    check(levelLabel .. " learned-PSYBEAM screenshot", learned ~= nil)
    drainTextUntil(function() return hasMove(mon, "PSYBEAM") end, 480)
    check("Route-5 Reminder teaches PSYBEAM at " .. levelLabel,
      hasMove(mon, "PSYBEAM"))
    clearToOverworld()
  end

  teachThroughReminder(reminderMon(36), "level 36",
    dir .. "/04_reminder_level36_offer.png",
    dir .. "/05_reminder_level36_learned.png")
  teachThroughReminder(reminderMon(73), "level 73",
    dir .. "/06_reminder_level73_offer.png",
    dir .. "/07_reminder_level73_learned.png")

  -- Final production-API cross-check uses the already-loaded full-main
  -- controller; it is not a substitute for the UI runs above.
  check("production reminder API rejects level 35",
    not listHas({ items = fieldTech.reminderMoves(game, reminderMon(35)) },
      "PSYBEAM"))
  check("production reminder API accepts level 36",
    listHas({ items = fieldTech.reminderMoves(game, reminderMon(36)) },
      "PSYBEAM"))
  check("production reminder API accepts an existing higher Espeon",
    listHas({ items = fieldTech.reminderMoves(game, reminderMon(73)) },
      "PSYBEAM"))

  -- Persist the final real Reminder transaction through the engine's native
  -- save boundary.  The package gate executes this once per R/B/Y identity,
  -- so this is also the feature matrix's edition-specific reload proof.
  check("native save after Route-5 PSYBEAM transaction succeeds",
    game:writeSave())
  local loaded, recovered = SaveData.load()
  check("native save reload returns the active edition slot",
    loaded ~= nil and recovered ~= true)
  if loaded then
    game:restoreSave(loaded, false)
    U.wait(20)
    local persisted = game.save.party and game.save.party[1]
    check("native reload retains the taught Espeon PSYBEAM",
      persisted and persisted.species == "ESPEON"
        and persisted.level == 73 and hasMove(persisted, "PSYBEAM"))
  end

  U.log(("RC65 ESPEON PSYBEAM LOVE RESULT pass=%d fail=%d")
    :format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
