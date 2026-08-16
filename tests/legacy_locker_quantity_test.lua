local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local function flatText(box)
  local text = type(box and box.text) == "string" and box.text or nil
  if not text then
    local pages = {}
    for _, page in ipairs(box and box.pages or {}) do
      pages[#pages + 1] = type(page) == "table"
        and table.concat(page, "\n") or tostring(page)
    end
    text = table.concat(pages, "\f")
  end
  return tostring(text or ""):gsub("[\n\f]+", " "):gsub("%s+", " ")
end

local function makeCase(opts)
  opts = opts or {}
  local itemId = opts.itemId or "POTION"
  local lockerItems = { [itemId] = opts.locker or 1 }
  local pending, serial = nil, 0
  local metrics = {
    lockerReads = 0, begins = 0, completes = 0, cancels = 0,
    writes = 0, logs = {}, plans = {},
  }
  local megaState = { stones = {} }
  local archive = {}
  function archive.bindData() return true end
  function archive.bankAccess() return true, "compat", "open", "journey" end
  function archive.classifyItem(id)
    local unique = id == "BLAZIKENITE"
    return {
      id = id, category = unique and "mega_stone" or "consumable",
      transferable = true,
      claimMode = unique and "unique_after_mega_access" or "counted",
    }
  end
  function archive.itemClaimStatus(_, id)
    local policy = archive.classifyItem(id)
    return true, id == "BLAZIKENITE" and megaState.stones[id]
      and "already_owned" or "ready", policy
  end
  function archive.locker()
    metrics.lockerReads = metrics.lockerReads + 1
    local items = {}
    for id, count in pairs(lockerItems) do items[id] = count end
    return { items = items, money = 0 }
  end
  function archive.beginItemCheckout(save, id, count, grant)
    metrics.begins = metrics.begins + 1
    ok(pending == nil, "only one item checkout may be staged")
    serial = serial + 1
    local copiedGrant = grant and { bag = grant.bag, pc = grant.pc } or nil
    metrics.plans[#metrics.plans + 1] = copiedGrant
    pending = {
      id = "QTY:" .. serial, item = id, count = count, grant = copiedGrant,
      beforeBag = tonumber(save.inventory and save.inventory[id]) or 0,
      beforePc = tonumber(save.pcItems and save.pcItems[id]) or 0,
    }
    return { id = pending.id, item = id, count = count, grant = copiedGrant }
  end
  function archive.completeCheckout(save, id)
    ok(pending and pending.id == id,
      "finalization owns the exact staged checkout")
    if opts.failFinalize == true then
      return false, "injected archive finalization failure"
    end
    if pending.grant then
      eq(tonumber(save.inventory[pending.item]) or 0,
        pending.beforeBag + pending.grant.bag,
        "finalization observes the exact Bag grant")
      eq(tonumber(save.pcItems[pending.item]) or 0,
        pending.beforePc + pending.grant.pc,
        "finalization observes the exact Player-PC grant")
    else
      ok(megaState.stones[pending.item] == true,
        "unique finalization observes the Stone Case receipt")
    end
    lockerItems[pending.item] = lockerItems[pending.item] - pending.count
    if lockerItems[pending.item] <= 0 then lockerItems[pending.item] = nil end
    metrics.completes = metrics.completes + 1
    pending = nil
    return true
  end
  function archive.cancelCheckout(id)
    ok(pending and pending.id == id,
      "rollback owns the exact staged checkout")
    metrics.cancels = metrics.cancels + 1
    pending = nil
    return true
  end

  local hooks = { wrap = function() end }
  local events = { on = function() end }
  local mapScripts = { register = function() end }
  local function menu(_, title, rows, menuOpts)
    local value = { title = title, items = rows, opts = menuOpts, index = 1 }
    function value:removeCurrent() table.remove(self.items, self.index) end
    function value:close() self.closed = true end
    return value
  end
  local mod = {
    id = "kanto_ascendant", path = ".", hooks = hooks, events = events,
    content = { map_scripts = mapScripts },
    ui = { KantoListMenu = { new = menu }, ListMenu = { new = menu } },
    log = { error = function(_, message)
      metrics.logs[#metrics.logs + 1] = tostring(message)
    end },
    exports = {},
  }
  mod.exports.megaEvolution = {
    state = function() return { case = true, ring = true,
      stones = megaState.stones } end,
    hasStone = function(id) return megaState.stones[id] == true end,
    importLegacyStone = function(id)
      local added = megaState.stones[id] ~= true
      megaState.stones[id] = true
      return { stone = id, added = added }
    end,
    rollbackLegacyStone = function(receipt)
      if receipt and receipt.added then megaState.stones[receipt.stone] = nil end
      return true
    end,
  }

  local inventory = {}
  for index = 1, tonumber(opts.bagFill or 0) do
    local id = ("FILLER_%02d"):format(index)
    inventory[id] = 1
  end
  if opts.bag ~= nil then inventory[itemId] = opts.bag end
  local pcItems = {}
  for index = 1, tonumber(opts.pcFill or 0) do
    pcItems[("PC_FILLER_%02d"):format(index)] = 1
  end
  if opts.pc ~= nil then pcItems[itemId] = opts.pc end
  local save = {
    inventory = inventory, pcItems = pcItems, bagOrder = {}, money = 0,
    modData = { kanto_ascendant = { legacy_journey = {
      runId = "QTY-RUN", bankUnlocked = true,
    } } },
  }
  local items = {
    POTION = { name = "POTION", pocket = "ITEM" },
    BLAZIKENITE = { name = "BLAZIKENITE", tossable = false,
      pocket = "ITEM" },
  }
  for id in pairs(inventory) do
    items[id] = items[id] or { name = id, pocket = "ITEM" }
  end
  for id in pairs(pcItems) do
    items[id] = items[id] or { name = id, pocket = "ITEM" }
  end
  local stack = { states = {} }
  function stack:push(value) self.states[#self.states + 1] = value end
  function stack:pop() return table.remove(self.states) end
  function stack:top() return self.states[#self.states] end
  local game = {
    save = save, stack = stack,
    data = { items = items, pokemon = {}, moves = {},
      constants = { bagSize = 20 }, field = { pcItemCap = 50 } },
  }
  function game:writeSave()
    metrics.writes = metrics.writes + 1
    return opts.failWrite ~= true
  end

  local makeJourney = assert(loadfile("legacy_journey.lua"))()
  local journey = makeJourney(mod, {
    archive = archive,
    i18n = { text = function(en, de) return opts.german and de or en end },
    onOakCall = function() return true end,
  })

  local case = {
    archive = archive, game = game, journey = journey, metrics = metrics,
    lockerItems = lockerItems, megaState = megaState,
  }
  function case:openItems()
    ok(self.journey.openLocker(self.game) ~= false,
      "active Legacy run opens the Locker hub")
    local hub = self.game.stack:top()
    hub.opts.onChoose(hub.items[1])
    local list = self.game.stack:top()
    ok(list ~= hub and list.items[1].value == itemId,
      "Locker item row opens from the cached hub snapshot")
    return list
  end
  function case:choose(list)
    list.opts.onChoose(list.items[list.index])
    return self.game.stack:top()
  end
  function case:finishQuantity(box, quantity)
    eq(self.game.stack:top(), box,
      "quantity selector is topmost before completion")
    self.game.stack:pop()
    box.onDone(quantity)
  end
  return case
end

do
  local case = makeCase({ locker = 150 })
  local list = case:openItems()
  eq(case.metrics.lockerReads, 1,
    "hub and item screen share one archive snapshot read")
  list.opts.onSelectKey(list.items[1])
  local help = flatText(case.game.stack:top())
  ok(help:find("Choose 1-150", 1, true)
      and help:find("Bag", 1, true)
      and help:find("Player PC", 1, true)
      and help:find("B cancels unchanged", 1, true),
    "English SELECT help explains maximum, placement and cancel")
  case.game.stack:pop()

  local quantity = case:choose(list)
  eq(quantity.qty, 1, "large-stack quantity selector starts at one")
  eq(quantity.max, 150,
    "empty Bag plus Player PC expose all 150 archived items")
  ok(type(rawget(quantity, "draw")) == "function",
    "three-digit quantity uses the widened instance renderer")
  case:finishQuantity(quantity, nil)
  eq(case.metrics.begins, 0, "B cancel never stages an archive checkout")
  eq(case.metrics.writes, 0, "B cancel never writes the game save")
  eq(case.game.save.inventory.POTION, nil,
    "B cancel leaves the Bag unchanged")
  eq(case.game.save.pcItems.POTION, nil,
    "B cancel leaves the Player PC unchanged")
  eq(case.lockerItems.POTION, 150,
    "B cancel leaves the Legacy receipt unchanged")

  quantity = case:choose(list)
  case:finishQuantity(quantity, 150)
  eq(case.metrics.begins, 1, "one confirmation stages one checkout")
  eq(case.metrics.writes, 1, "one confirmation writes the game once")
  eq(case.metrics.completes, 1, "one confirmation finalizes once")
  eq(case.metrics.cancels, 0, "successful grant never rolls back")
  eq(case.metrics.plans[1].bag, 99,
    "large withdrawal fills the Bag first")
  eq(case.metrics.plans[1].pc, 51,
    "large withdrawal sends only the overflow to Player PC")
  eq(case.game.save.inventory.POTION, 99,
    "Bag receives its exact planned count")
  eq(case.game.save.pcItems.POTION, 51,
    "Player PC receives its exact planned overflow")
  eq(case.lockerItems.POTION, nil,
    "one atomic finalization consumes the selected 150")
  eq(#list.items, 0, "fully consumed Locker row disappears")
end

do
  local case = makeCase({ locker = 5, bag = 98, pc = 98 })
  local list = case:openItems()
  local quantity = case:choose(list)
  eq(quantity.max, 2,
    "selector is capped by the combined residual Bag/PC stack room")
  case:finishQuantity(quantity, 2)
  eq(case.game.save.inventory.POTION, 99,
    "capacity-edge withdrawal fills the final Bag slot")
  eq(case.game.save.pcItems.POTION, 99,
    "capacity-edge withdrawal fills the final PC slot")
  eq(case.lockerItems.POTION, 3,
    "capacity-edge withdrawal leaves the unselected receipts safe")
  local begins = case.metrics.begins
  eq(case:choose(list), list,
    "a full Bag and PC do not push a zero-capacity selector")
  eq(case.metrics.begins, begins,
    "zero capacity cannot stage another checkout")
  eq(list.footer, "BAG + PLAYER PC FULL",
    "zero capacity reports both full destinations")
end

do
  local case = makeCase({ locker = 120, bagFill = 20 })
  local list = case:openItems()
  local quantity = case:choose(list)
  eq(quantity.max, 99,
    "full Bag with a free Player-PC stack exposes legitimate PC capacity")
  case:finishQuantity(quantity, 99)
  eq(case.game.save.inventory.POTION, nil,
    "full Bag receives no phantom overflow item")
  eq(case.game.save.pcItems.POTION, 99,
    "free Player PC receives the exact fallback stack")
  eq(case.metrics.plans[1].bag, 0,
    "journal records zero Bag grant when its item pocket is full")
  eq(case.metrics.plans[1].pc, 99,
    "journal records the full Player-PC fallback grant")
end

do
  local case = makeCase({ locker = 500 })
  local list = case:openItems()
  local quantity = case:choose(list)
  eq(quantity.max, 198,
    "very large archive stacks cap at two legitimate 99-count destinations")
  case:finishQuantity(quantity, 198)
  eq(case.game.save.inventory.POTION, 99,
    "combined-capacity maximum fills one exact Bag stack")
  eq(case.game.save.pcItems.POTION, 99,
    "combined-capacity maximum fills one exact Player-PC stack")
  eq(case.lockerItems.POTION, 302,
    "combined-capacity maximum preserves the unselected large-stack remainder")
end

do
  local case = makeCase({ locker = 120, bagFill = 19, pcFill = 50 })
  local list = case:openItems()
  local quantity = case:choose(list)
  eq(quantity.max, 99,
    "a full 50-stack Player PC leaves only the free Bag-stack capacity")
  case:finishQuantity(quantity, 99)
  eq(case.metrics.plans[1].bag, 99,
    "full Player-PC slot table routes the entire grant to Bag")
  eq(case.metrics.plans[1].pc, 0,
    "full Player-PC slot table receives no illegal new stack")
end

do
  local case = makeCase({ locker = 10, bag = 95, pc = 98,
    failWrite = true })
  local list = case:openItems()
  local quantity = case:choose(list)
  eq(quantity.max, 5, "failed-write fixture exposes the exact free capacity")
  case:finishQuantity(quantity, 5)
  eq(case.metrics.begins, 1, "failed write was staged once")
  eq(case.metrics.writes, 1, "failed write was attempted once")
  eq(case.metrics.completes, 0,
    "failed game write never finalizes the archive")
  eq(case.metrics.cancels, 1,
    "failed game write cancels the staged archive receipt")
  eq(case.game.save.inventory.POTION, 95,
    "failed write restores the exact Bag before-state")
  eq(case.game.save.pcItems.POTION, 98,
    "failed write restores the exact Player-PC before-state")
  eq(case.lockerItems.POTION, 10,
    "failed write leaves every Locker receipt retryable")
  eq(list.items[1].right, "x10",
    "failed write leaves the visible Locker count unchanged")
  eq(list.footer, "SAVE FAILED", "failed write reports recoverable failure")
end

do
  local case = makeCase({ locker = 3, failWrite = true })
  case.game.save.bagOrder = { "EXISTING_ORDER_SENTINEL" }
  local beforeOrder = case.game.save.bagOrder
  local list = case:openItems()
  local quantity = case:choose(list)
  case:finishQuantity(quantity, 3)
  eq(case.game.save.inventory.POTION, nil,
    "failed new-stack write removes the provisional Bag stack")
  eq(case.game.save.pcItems.POTION, nil,
    "failed new-stack write creates no Player-PC residue")
  eq(case.game.save.bagOrder, beforeOrder,
    "failed new-stack write restores the original Bag-order table identity")
  eq(#beforeOrder, 1,
    "failed new-stack write restores the exact Bag-order length")
  eq(beforeOrder[1], "EXISTING_ORDER_SENTINEL",
    "failed new-stack write restores every prior Bag-order value")
  eq(case.metrics.cancels, 1,
    "failed new-stack write cancels its one pending journal")
  eq(case.lockerItems.POTION, 3,
    "failed new-stack write preserves every Locker receipt")
end

do
  local options = { locker = 10, bag = 95, pc = 98,
    failFinalize = true }
  local case = makeCase(options)
  local list = case:openItems()
  local quantity = case:choose(list)
  case:finishQuantity(quantity, 5)
  eq(case.metrics.writes, 1,
    "finalization-failure fixture first persists the granted items")
  eq(case.metrics.completes, 0,
    "failed archive finalization leaves its journal pending")
  eq(case.metrics.cancels, 0,
    "a persisted grant is never rolled back or cancelled after finalization fails")
  eq(case.game.save.inventory.POTION, 99,
    "failed finalization keeps the exact saved Bag grant")
  eq(case.game.save.pcItems.POTION, 99,
    "failed finalization keeps the exact saved Player-PC overflow")
  eq(case.lockerItems.POTION, 10,
    "failed finalization does not consume the mocked archive early")
  eq(list.items[1].right, "x10",
    "failed finalization does not claim a stale visible Locker count")
  eq(list.footer, "LOCKER WILL RECOVER ON LOAD",
    "failed finalization advertises journal recovery")
  options.failFinalize = false
  ok(case.archive.completeCheckout(case.game.save, "QTY:1") == true,
    "a later reload-style reconciliation completes the pending journal")
  eq(case.lockerItems.POTION, 5,
    "reload-style reconciliation consumes the selected quantity exactly once")
  eq(case.metrics.completes, 1,
    "reload-style reconciliation finalizes exactly once")
end

do
  local case = makeCase({ locker = 150, german = true })
  local list = case:openItems()
  list.opts.onSelectKey(list.items[1])
  local help = flatText(case.game.stack:top())
  ok(help:find("Wähle jetzt 1-150", 1, true)
      and help:find("Beutel", 1, true)
      and help:find("Spieler-PC", 1, true)
      and help:find("B bricht ohne Änderung ab", 1, true),
    "German SELECT help explains maximum, placement and cancel")
end

do
  local case = makeCase({ itemId = "BLAZIKENITE", locker = 1 })
  local list = case:openItems()
  eq(case:choose(list), list,
    "unique Mega receipt bypasses the counted quantity selector")
  eq(case.metrics.plans[1], nil,
    "unique Mega receipt has no Bag/PC split plan")
  eq(case.metrics.begins, 1, "unique Mega receipt stages exactly once")
  eq(case.metrics.writes, 1, "unique Mega receipt writes exactly once")
  eq(case.metrics.completes, 1, "unique Mega receipt finalizes exactly once")
  ok(case.megaState.stones.BLAZIKENITE,
    "unique Mega receipt enters the Stone Case once")
end

do
  local case = makeCase({ locker = 1 })
  case.archive.locker = function() error("injected Locker read failure") end
  ok(case.journey.openLocker(case.game) == false,
    "Locker read exception fails closed instead of crashing the frame")
  eq(case.metrics.writes, 0,
    "failed pre-screen read performs no game write")
  ok(#case.metrics.logs == 1
      and case.metrics.logs[1]:find("screen load", 1, true),
    "failed pre-screen read records one focused diagnostic")
  ok(flatText(case.game.stack:top()):find("Nothing changed", 1, true),
    "failed pre-screen read tells the player state was unchanged")
end

print(("LEGACY LOCKER QUANTITY PASS: %d assertions"):format(assertions))
