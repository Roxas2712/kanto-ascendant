-- Real Authority-main/LÖVE acceptance for the non-map HEVO package surfaces.
--
-- Scope: eight direct target items (nine authored targets because DUSK STONE
-- has two), and the five knowledge targets reached through the three authored
-- moves.  Field altars and dungeon first grants deliberately remain outside
-- this driver.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing HEVO non-map proof outside the immutable package gate")
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local locale = assert(os.getenv("QA_LANGUAGE"), "QA_LANGUAGE is required")
  local Pokemon = require("src.pokemon.Pokemon")
  local Boxes = require("src.pokemon.Boxes")
  local Bag = require("src.inventory.Bag")
  local Screens = require("src.ui.Screens")
  local SaveData = require("src.core.SaveData")
  local Sprites = require("src.pokemon.Sprites")
  local TextBox = require("src.render.TextBox")
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Authority export missing")
  local packages = assert(api.hevoPackages, "HEVO package runtime missing")
  local fieldTech = assert(api.fieldTech, "Route-5 Reminder missing")
  local shiny = assert(api.shinySystem, "shiny runtime missing")
  local pass, fail = 0, 0

  -- Language is a public Authority option.  Set it through the same option
  -- event as the in-game menu so EN/DE cells remain real package behavior
  -- even though the reviewed closure keeps the edition translation loaded.
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.language = locale
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.language = locale
  game.mods.events:emit("mod.options_changed", {
    mod="kanto_ascendant",key="language",value=locale,
  })
  U.wait(12)

  local function check(label, value, detail)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label, detail or "")
    return value
  end

  local function top() return game.stack:top() end
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
  local function pageText(value)
    local out = {}
    for _, page in ipairs(value and value.pages or {}) do
      if type(page) == "table" then
        out[#out + 1] = table.concat(page, " ")
      else
        out[#out + 1] = tostring(page)
      end
    end
    return table.concat(out, " ")
  end
  local function stackState(predicate)
    for _, state in ipairs(game.stack.states or {}) do
      if predicate(state) then return state end
    end
  end
  local function clearUi()
    while top() and top() ~= game.overworld do game.stack:pop() end
  end
  local function listHas(menu, value)
    for _, row in ipairs(menu and menu.items or {}) do
      if row.value == value then return true end
    end
    return false
  end
  local function focusListValue(menu, value)
    local index
    for i, row in ipairs(menu and menu.items or {}) do
      if row.value == value then index = i break end
    end
    if not index then return false end
    while menu.index ~= index do
      U.tap(game, index > menu.index and "down" or "up")
    end
    U.wait(2)
    return true
  end
  local function chooseListValue(menu, value)
    if not focusListValue(menu, value) then return false end
    U.tap(game, "a")
    U.wait(2)
    return true
  end
  local function chooseParty(index)
    local menu = assert(waitFor(function()
      local value = top()
      return value and value.screenId == "PartyMenu" and value or nil
    end, 360), "party target picker did not open")
    while menu.index ~= index do U.tap(game, "down") end
    U.tap(game, "a")
    U.wait(2)
    return menu
  end
  local function hasMove(mon, id)
    for _, move in ipairs(mon and mon.moves or {}) do
      if move.id == id then return true end
    end
    return false
  end
  local function removeMove(mon, id)
    local kept = {}
    for _, move in ipairs(mon and mon.moves or {}) do
      if move.id ~= id then kept[#kept + 1] = move end
    end
    mon.moves = kept
  end
  local function safeShot(path)
    U.wait(3)
    return U.shot(game, path)
  end
  local function dismissText(box)
    for _ = 1, 30 do
      if top() ~= box then return true end
      if box.waiting or box.done then U.tap(game, "a") else U.wait(1) end
    end
    return top() ~= box
  end
  local function settleText(box)
    return waitFor(function()
      return top() == box and (box.waiting or box.done) and box or nil
    end, 480)
  end

  local function setOnlyItem(id, count)
    game.save.inventory, game.save.bagOrder = {}, {}
    assert(Bag.add(game.save, id, count or 1, game.data),
      "could not stage " .. id)
  end

  local function openBagTarget(itemId)
    Screens.push(game, "BagMenu", {})
    local bag = assert(waitFor(function()
      local value = top()
      return value and value.screenId == "BagMenu" and listHas(value, itemId)
        and value or nil
    end, 360), "Bag did not expose " .. itemId)
    assert(chooseListValue(bag, itemId), "Bag row unavailable " .. itemId)
    U.tap(game, "a") -- USE in the real USE/TOSS menu
    U.wait(2)
    local picker = assert(waitFor(function()
      local value = top()
      return value and value.screenId == "PartyMenu" and value or nil
    end, 360), "Bag did not open target picker for " .. itemId)
    return bag, picker
  end

  local function waitEvolution(mon, target)
    local state = waitFor(function()
      return stackState(function(value)
        return value.mon == mon and value.newSpecies == target and value or nil
      end)
    end, 480)
    return state
  end

  local function finishEvolution(mon, target)
    local box = waitFor(function()
      local value = top()
      return mon.species == target and isText(value) and value or nil
    end, 900)
    return box
  end

  local function unlockAll()
    game.save.modData = game.save.modData or {}
    local bucket = game.save.modData.kanto_ascendant or {}
    game.save.modData.kanto_ascendant = bucket
    bucket.hevo_persistent = bucket.hevo_persistent or {}
    bucket.hevo_persistent.packageUnlocks = {}
    for _, package in ipairs(packages.order) do
      bucket.hevo_persistent.packageUnlocks[package.id] = true
    end
    packages.reconcile(game.save)
  end

  local itemCases = {
    { item = "PROTECTOR", package = "protector", parent = "RHYDON",
      target = "RHYPERIOR" },
    { item = "MAGMARIZER", package = "magmarizer", parent = "MAGMAR",
      target = "MAGMORTAR", shiny = true },
    { item = "ELECTIRIZER", package = "electirizer", parent = "ELECTABUZZ",
      target = "ELECTIVIRE" },
    { item = "DUBIOUS_DISC", package = "dubious_disc", parent = "PORYGON2",
      target = "PORYGON_Z", shiny = true },
    { item = "RAZOR_FANG", package = "razor_fang", parent = "GLIGAR",
      target = "GLISCOR" },
    { item = "RAZOR_CLAW", package = "razor_claw", parent = "SNEASEL",
      target = "WEAVILE", shiny = true },
    { item = "SHINY_STONE", package = "shiny_stone", parent = "TOGETIC",
      target = "TOGEKISS" },
    { item = "DUSK_STONE", package = "dusk_stone", parent = "MISDREAVUS",
      target = "MISMAGIUS", shiny = true },
    { item = "DUSK_STONE", package = "dusk_stone", parent = "MURKROW",
      target = "HONCHKROW" },
  }
  local knowledgeCases = {
    { package = "rollout_knowledge", move = "ROLLOUT",
      parent = "LICKITUNG", target = "LICKILICKY" },
    { package = "ancient_power_red", move = "ANCIENTPOWER",
      parent = "PILOSWINE", target = "MAMOSWINE", shiny = true },
    { package = "ancient_power_green", move = "ANCIENTPOWER",
      parent = "TANGELA", target = "TANGROWTH" },
    { package = "ancient_power_green", move = "ANCIENTPOWER",
      parent = "YANMA", target = "YANMEGA", shiny = true },
    { package = "double_hit_knowledge", move = "DOUBLE_HIT",
      parent = "AIPOM", target = "AMBIPOM" },
  }

  U.wait(30)
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.player = game.save.player or { name = "RED", id = 65015 }
  game.save.player.name = locale == "de" and "ROT" or "RED"
  game.save.flags = game.save.flags or {}
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  game.save.boxes, game.save.currentBox = nil, nil
  Boxes.ensure(game.save)
  U.teleport(game, "ROUTE_5", 8, 8, "down")
  unlockAll()
  check("Authority exports exactly 15 packages and 17 targets",
    #packages.order == 15 and packages.audit.registeredTargets == 17)
  check("requested language is active",
    not api.language or api.language() == locale)

  local results = {}
  local function store(mon)
    assert(Boxes.deposit(game.save, mon), "HEVO QA box unexpectedly full")
    results[#results + 1] = mon
  end

  for index, row in ipairs(itemCases) do
    local stem = ("item_%02d_%s_%s"):format(index,
      row.item:lower(), row.target:lower())
    local wrong = Pokemon.new(game.data, "PIKACHU", 50)
    local mon = Pokemon.new(game.data, row.parent, 50)
    mon.moves = { { id = "TACKLE", pp = game.data.moves.TACKLE.pp } }
    if row.shiny then
      assert(shiny.forceMon(mon, game.data.pokemon[row.parent]))
    end
    game.save.party = { wrong, mon }
    setOnlyItem(row.item)
    packages.reconcile(game.save)
    local def = assert(game.data.items[row.item])
    local expectedName = packages.byId[row.package].itemName[locale]
    check(row.item .. " uses the localized live item definition",
      def.name == expectedName, def.name)

    -- B from the real target picker is the cancel contract.
    local _, cancelPicker = openBagTarget(row.item)
    check(row.item .. " target picker capture",
      safeShot(dir .. "/" .. stem .. "_01_target_picker.png"))
    U.tap(game, "b")
    U.wait(3)
    check(row.item .. " B cancel keeps item and both species",
      game.save.inventory[row.item] == 1
        and wrong.species == "PIKACHU" and mon.species == row.parent
        and top() ~= cancelPicker)
    check(row.item .. " cancel/non-consume capture",
      safeShot(dir .. "/" .. stem .. "_02_cancel_kept.png"))
    clearUi()

    -- Wrong species must use the merged item effect and consume nothing.
    openBagTarget(row.item)
    chooseParty(1)
    local refused = assert(waitFor(function()
      local value = top()
      return isText(value) and value or nil
    end, 360), row.item .. " wrong-target refusal missing")
    local refusal = pageText(refused)
    check(row.item .. " wrong target is localized and non-consuming",
      game.save.inventory[row.item] == 1
        and (refusal:find(locale == "de" and "Wirkung" or "effect") ~= nil))
    settleText(refused)
    check(row.item .. " wrong-target/non-consume capture",
      safeShot(dir .. "/" .. stem .. "_03_wrong_target_kept.png"))
    dismissText(refused)
    clearUi()

    -- Correct species follows Bag -> target -> real EvolutionState. The item
    -- is consumed only once the engine accepted that evolution request.
    openBagTarget(row.item)
    chooseParty(2)
    local evolution = waitEvolution(mon, row.target)
    check(row.item .. " reaches the real non-cancelable EvolutionState",
      evolution and evolution.cancelable == false)
    check(row.item .. " consumes exactly one after accepted target",
      game.save.inventory[row.item] == nil)
    local congrats = finishEvolution(mon, row.target)
    check(row.item .. " evolves " .. row.parent .. " -> " .. row.target,
      congrats ~= nil and mon.species == row.target)
    if congrats then settleText(congrats) end
    check(row.item .. " evolved-surface capture",
      congrats and safeShot(dir .. "/" .. stem .. "_04_evolved.png"))
    if row.shiny then
      check(row.target .. " retains shiny state", shiny.isShiny(mon))
    end
    if congrats then dismissText(congrats) end
    clearUi()
    store(mon)
  end

  local function safeLevel(parent, target)
    local occupied = {}
    for _, species in ipairs({ parent, target }) do
      for _, learned in ipairs(game.data.pokemon[species].learnset or {}) do
        occupied[learned.level] = true
      end
    end
    for level = 45, 90 do
      if not occupied[level] then return level end
    end
    error("no safe knowledge level for " .. parent)
  end

  local function findMachine()
    local daycare = api.daycare
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
  local function openReminder(mon)
    game.save.party = { mon }
    U.teleport(game, "DAYCARE", 3, 3, "down")
    local machine = assert(waitFor(findMachine, 360),
      "Route-5 machine did not spawn")
    assert(faceMachine(machine), "no legal cell faces Route-5 machine")
    U.tap(game, "a")
    local machineMenu = assert(waitFor(function()
      local value = top()
      return value and value.items and listHas(value, "remember")
        and value or nil
    end, 360), "physical Route-5 interaction did not open machine menu")
    assert(chooseListValue(machineMenu, "remember"))
    chooseParty(1)
    return assert(waitFor(function()
      local value = top()
      return value and value.items
        and (value.title == "REMEMBER WHICH?"
          or value.title == "WELCHE ERINNERN?") and value or nil
    end, 360), "Route-5 Reminder candidate list did not open")
  end

  local function drainToEvolution(mon, target)
    for _ = 1, 1800 do
      local evo = stackState(function(value)
        return value.mon == mon and value.newSpecies == target and value or nil
      end)
      if evo then return evo end
      local value = top()
      if isText(value) and (value.waiting or value.done) then
        U.tap(game, "a")
      elseif value and value.mon and value.onDone and not value.pages
          and not value.newSpecies then
        U.tap(game, "a") -- real Rare-Candy StatBox
      else
        U.wait(1)
      end
    end
  end

  for index, row in ipairs(knowledgeCases) do
    local stem = ("knowledge_%02d_%s_%s"):format(index,
      row.move:lower(), row.target:lower())
    local nextLevel = safeLevel(row.parent, row.target)
    local mon = Pokemon.new(game.data, row.parent, nextLevel - 1)
    mon.moves = { { id = "TACKLE", pp = game.data.moves.TACKLE.pp } }
    if row.shiny then
      assert(shiny.forceMon(mon, game.data.pokemon[row.parent]))
    end
    packages.reconcile(game.save)
    local reminder = openReminder(mon)
    check(row.parent .. " receives " .. row.move
        .. " from the physical Route-5 Reminder",
      listHas(reminder, row.move))
    assert(focusListValue(reminder, row.move), "Reminder row vanished")
    check(row.move .. " Reminder-offer capture for " .. row.parent,
      safeShot(dir .. "/" .. stem .. "_01_reminder_offer.png"))
    U.tap(game, "a")
    U.wait(2)
    local remembered = assert(waitFor(function()
      local value = top()
      return isText(value) and hasMove(mon, row.move) and value or nil
    end, 480), row.move .. " Reminder transaction did not complete")
    check(row.move .. " is learned through the real Reminder", hasMove(mon, row.move))
    dismissText(remembered)
    clearUi()

    -- One ordinary Rare Candy supplies the next real level-up trigger.  No
    -- direct HEVO method call or test evolution stub is used.
    setOnlyItem("RARE_CANDY")
    game.save.party = { mon }
    Screens.push(game, "BagMenu", {})
    local candyBag = assert(waitFor(function()
      local value = top()
      return value and value.screenId == "BagMenu"
        and listHas(value, "RARE_CANDY") and value or nil
    end, 360), "Rare Candy Bag row missing")
    assert(chooseListValue(candyBag, "RARE_CANDY"))
    U.tap(game, "a") -- USE
    chooseParty(1)
    local evolution = drainToEvolution(mon, row.target)
    check(row.move .. " level-up reaches the registry evolution method",
      evolution ~= nil and evolution.via == packages.byId[row.package].method)
    check(row.move .. " evolution is the normal cancelable level-up form",
      evolution and evolution.cancelable == true)
    local congrats = finishEvolution(mon, row.target)
    check(row.move .. " evolves " .. row.parent .. " -> " .. row.target,
      congrats ~= nil and mon.level == nextLevel and mon.species == row.target)
    if congrats then settleText(congrats) end
    check(row.move .. " evolved-surface capture for " .. row.target,
      congrats and safeShot(dir .. "/" .. stem .. "_02_evolved.png"))
    if row.shiny then
      check(row.target .. " retains shiny state", shiny.isShiny(mon))
    end
    if congrats then dismissText(congrats) end
    clearUi()
    store(mon)
  end

  -- Persist the whole non-map result set and reload it through SaveData.
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 12) }
  setOnlyItem("POTION")
  check("real save after fourteen non-map target evolutions succeeds",
    game:writeSave())
  local loaded = assert(SaveData.load(), "HEVO surface save did not reload")
  game:restoreSave(loaded, false)
  U.wait(40)
  local stored = {}
  for _, box in ipairs(Boxes.ensure(game.save)) do
    for _, mon in ipairs(box) do stored[mon.species] = mon end
  end
  for _, row in ipairs(itemCases) do
    check("reload retains item target " .. row.target, stored[row.target] ~= nil)
  end
  for _, row in ipairs(knowledgeCases) do
    check("reload retains knowledge target and move " .. row.target,
      stored[row.target] ~= nil and hasMove(stored[row.target], row.move))
  end
  clearUi()
  Screens.push(game, "BoxMenu")
  U.wait(4)
  U.tap(game, "a") -- WITHDRAW opens the real persisted box list/grid
  U.wait(8)
  check("post-reload box visibly contains the persisted HEVO set",
    safeShot(dir .. "/post_reload_01_all_targets_box.png"))
  clearUi()

  -- After evolution and reload, the ordinary evolved-species learnset remains
  -- compatible with the same physical Reminder.  Lickilicky learns Rollout
  -- naturally at 33, so forgetting it must expose it again without a parent
  -- species special case.
  local reloadLickilicky = assert(stored.LICKILICKY)
  removeMove(reloadLickilicky, "ROLLOUT")
  local evolvedReminder = openReminder(reloadLickilicky)
  check("post-reload evolved Lickilicky can remember Rollout",
    listHas(evolvedReminder, "ROLLOUT"))
  check("post-reload evolved Reminder capture",
    safeShot(dir .. "/post_reload_02_evolved_reminder.png"))
  assert(chooseListValue(evolvedReminder, "ROLLOUT"))
  local relearned = assert(waitFor(function()
    local value = top()
    return isText(value) and hasMove(reloadLickilicky, "ROLLOUT")
      and value or nil
  end, 480), "post-reload Rollout re-teach did not complete")
  dismissText(relearned)
  clearUi()

  -- Native Summary rendering demonstrates both normal and shiny resolved
  -- front surfaces after the persisted evolution.  Compare one species so a
  -- palette/path difference cannot be mistaken for two unrelated artworks.
  local shinyMagmortar = assert(stored.MAGMORTAR)
  local normalMagmortar = Pokemon.new(game.data, "MAGMORTAR", 50)
  local normalPath = Sprites.path(game.data, "MAGMORTAR", "front",
    { mon = normalMagmortar, kind = "summary" })
  local shinyPath = Sprites.path(game.data, "MAGMORTAR", "front",
    { mon = shinyMagmortar, kind = "summary" })
  check("normal and shiny Magmortar resolve distinct live surfaces",
    normalPath and shinyPath and normalPath ~= shinyPath,
    tostring(normalPath) .. " / " .. tostring(shinyPath))
  clearUi()
  Screens.push(game, "SummaryMenu", normalMagmortar)
  U.wait(8)
  check("normal evolved Summary capture",
    safeShot(dir .. "/post_reload_03_magmortar_normal_summary.png"))
  clearUi()
  Screens.push(game, "SummaryMenu", shinyMagmortar)
  U.wait(8)
  check("shiny evolved Summary capture",
    safeShot(dir .. "/post_reload_04_magmortar_shiny_summary.png"))

  local report = assert(io.open(dir .. "/driver_result.txt", "wb"))
  report:write(("locale=%s\npass=%d\nfail=%d\nitemTargets=%d\nknowledgeTargets=%d\n")
    :format(locale, pass, fail, #itemCases, #knowledgeCases))
  report:write("scope=non-map; field altars and dungeon first grants excluded\n")
  report:close()
  U.log(("HEVO NON-MAP SURFACES RESULT locale=%s pass=%d fail=%d")
    :format(locale, pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
