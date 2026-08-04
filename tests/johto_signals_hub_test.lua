-- Focused ROM-free tests for the Johto Signals WORLD hub.
--
-- Run from the mod directory:
--   ../gen1recomp/.tools/luajit-src/src/luajit \
--     tests/johto_signals_hub_test.lua

local source = debug.getinfo(1, "S").source
local testDir = source:sub(1, 1) == "@"
  and source:sub(2):match("^(.*)/[^/]+$") or "tests"
local rootDir = testDir:match("^(.*)/tests$") or "."
local createHub = assert(loadfile(rootDir .. "/johto_signals_hub.lua"))()

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end

local function equal(actual, expected, message)
  assertions = assertions + 1
  if actual ~= expected then
    error(("FAIL: %s\nexpected: %s\nactual:   %s")
      :format(message, tostring(expected), tostring(actual)), 2)
  end
end

local function contains(text, fragment, message)
  check(type(text) == "string"
      and text:find(fragment, 1, true) ~= nil,
    message .. "\nmissing: " .. tostring(fragment)
      .. "\ntext: " .. tostring(text))
end

local function visibleLength(text)
  local count = 0
  for index = 1, #(text or "") do
    local byte = text:byte(index)
    if byte < 128 or byte >= 192 then count = count + 1 end
  end
  return count
end

local function menuRowsFit(menu, message)
  for index, row in ipairs(menu.rows or {}) do
    local width = visibleLength(row.label)
    if row.right then width = width + 1 + visibleLength(row.right) end
    check(width <= 17,
      ("%s row %d fits the 17-glyph ListMenu budget: %s")
        :format(message, index, tostring(row.label)))
  end
end

local function newHarness(config)
  config = config or {}
  local language = config.language or "en"
  local root = {
    earlyJohto = config.early or {
      questStarted = true,
      capsuleFound = true,
      receiverRepaired = false,
      modeChosen = false,
      mode = "KANTO_FIRST",
      traces = {},
    },
    resonance = config.resonance or {
      echoes = 0,
      sealed = false,
      completed = {},
    },
  }
  local fixture = {
    root = root,
    persistCount = 0,
    repairCalls = 0,
    setModeCalls = 0,
    scanCalls = 0,
    gateCalls = 0,
    sealCalls = 0,
    displays = {},
    menus = {},
    choices = {},
    installs = {},
    travelRefreshes = 0,
    warpCalls = 0,
    doneCalls = 0,
    closedMenus = 0,
    bagFull = config.bagFull == true,
  }

  local state = {}
  function state.section(name)
    return root[name]
  end
  function state.persist()
    fixture.persistCount = fixture.persistCount + 1
  end
  function state.install(game)
    fixture.stateGame = game
    return true
  end

  local i18n = {}
  function i18n.text(en, de)
    return language == "de" and de or en
  end

  local options = {
    johto_signals_enable = config.johtoEnabled,
    mythic_signals = config.mythicEnabled,
  }
  if options.johto_signals_enable == nil then
    options.johto_signals_enable = true
  end
  if options.mythic_signals == nil then
    options.mythic_signals = true
  end

  local hooks = {}
  local mod = {
    hooks = {},
    options = {
      get = function(_, key) return options[key] end,
    },
    ui = {},
    world = {
      warpTo = function()
        fixture.warpCalls = fixture.warpCalls + 1
        return true
      end,
    },
  }
  function mod.hooks:wrap(name, fn, priority)
    hooks[name] = { fn = fn, priority = priority }
  end
  function mod.ui.insertBefore(rows, _, row)
    rows[#rows + 1] = row
    return rows
  end

  local early = {
    modes = {
      KANTO_FIRST = "KANTO_FIRST",
      WANDERWAVES = "WANDERWAVES",
      UNLEASHED = "UNLEASHED",
    },
  }
  function early.state() return root.earlyJohto end
  function early.enabled()
    return options.johto_signals_enable ~= false
      and options.johto_signals_enable ~= "off"
  end
  function early.hasStarter() return config.hasStarter ~= false end
  function early.hasPokedex() return config.hasPokedex ~= false end
  function early.onResearcherRepair()
    fixture.repairCalls = fixture.repairCalls + 1
    local s = root.earlyJohto
    if not s.capsuleFound then
      return false, "capsule-missing", i18n.text(
        "The source capsule\nis still missing.",
        "Die Quellkapsel\nfehlt noch.")
    end
    if s.receiverRepaired then
      return false, "already-repaired", i18n.text(
        "Receiver ready.", "Empfänger bereit.")
    end
    s.receiverRepaired = true
    s.mode = "KANTO_FIRST"
    s.modeChosen = false
    state.persist()
    return true, "repaired", i18n.text(
      "RESEARCHER: Signal\nrestored.",
      "FORSCHER: Signal\nrepariert.")
  end
  function early.setMode(_, mode)
    fixture.setModeCalls = fixture.setModeCalls + 1
    local s = root.earlyJohto
    if not s.receiverRepaired then
      return false, "receiver-locked", i18n.text(
        "Receiver locked.", "Empfänger gesperrt.")
    end
    s.mode = mode
    s.modeChosen = true
    state.persist()
    return true, "mode-set", i18n.text(
      "Current confirmed.", "Strom bestätigt.")
  end
  function early.scanTrace()
    fixture.scanCalls = fixture.scanCalls + 1
    if not root.earlyJohto.receiverRepaired then
      return false, "receiver-locked", i18n.text(
        "Receiver locked.", "Empfänger gesperrt.")
    end
    return false, "weak", i18n.text(
      "A weak trace answers.",
      "Eine schwache Spur\nantwortet.")
  end
  function early.status()
    return i18n.text(
      "JOHTO SIGNALS\nStatus report.",
      "JOHTO-SIGNALE\nStatusbericht.")
  end
  function early.objective()
    return i18n.text(
      "Follow the next trace.",
      "Folge der nächsten Spur.")
  end

  local badges = config.badges or 0
  local mythic = {}
  function mythic.state() return root.resonance end
  function mythic.badgeCount() return badges end
  function mythic.statusData()
    local active = config.activeMythics
    if active == nil then active = { "MEW", "CELEBI" } end
    local completed = 0
    for _, value in pairs(root.resonance.completed or {}) do
      if value == true then completed = completed + 1 end
    end
    return {
      active = active,
      complete = completed + #active == 0,
    }
  end
  function mythic.researcherCanSeal()
    fixture.gateCalls = fixture.gateCalls + 1
    local m = root.resonance
    if m.echoes ~= 3 then
      return false, "echoes", i18n.text(
        "Three echoes are needed.",
        "Drei Echos werden\ngebraucht.")
    end
    if not root.earlyJohto.receiverRepaired then
      return false, "sender", i18n.text(
        "Repair the sender.",
        "Repariere den Sender.")
    end
    if badges < 4 then
      return false, "badges", i18n.text(
        ("Four BADGES are needed.\nYou have %d."):format(badges),
        ("Vier ORDEN sind nötig.\nDu hast %d."):format(badges))
    end
    return true, "ready", i18n.text(
      "Three echoes agree.",
      "Drei Echos stimmen ein.")
  end
  function mythic.researcherSeal()
    fixture.sealCalls = fixture.sealCalls + 1
    local ready, reason, message = mythic.researcherCanSeal()
    if not ready then return false, reason, message end
    root.resonance.sealed = true
    state.persist()
    return true, "sealed", i18n.text(
      "The RESONANCE SEAL\nis complete.",
      "Das RESONANZ-SIEGEL\nist fertig.")
  end
  function mythic.status()
    return i18n.text(
      "MYTHIC SIGNALS\nStatus report.",
      "MYTHOS-SIGNALE\nStatusbericht.")
  end
  function mythic.objective()
    return i18n.text(
      "Follow the mythic echo.",
      "Folge dem Mythos-Echo.")
  end
  function mythic.publicSpeciesName(species, publicGame)
    local seen = publicGame and publicGame.save
      and publicGame.save.pokedex and publicGame.save.pokedex.seen
    return seen and seen[species] and species or "???"
  end

  local content = {
    MAP_ID = "KANTO_ASCENDANT_DRIFTGLASS",
    PALLET_MAP_ID = "PALLET_TOWN",
    ITEMS = { MIGRATION_RECEIVER = "MIGRATION_RECEIVER" },
  }
  function content.refreshTravelNpc()
    fixture.travelRefreshes = fixture.travelRefreshes + 1
    return true
  end
  function content.install(game, callbacks)
    fixture.installs[#fixture.installs + 1] = {
      game = game,
      callbacks = callbacks,
    }
    fixture.contentCallbacks = callbacks
    return true
  end

  local game = {
    save = {
      inventory = {},
      bagOrder = {},
      pokedex = { seen = {}, owned = {} },
      player = { map = "PALLET_TOWN" },
    },
    data = {
      items = {
        MIGRATION_RECEIVER = { name = "MIGRATION RECEIVER" },
      },
    },
    overworld = { map = { id = "PALLET_TOWN" } },
    stack = { push = function() end },
  }

  local function showText(_, text, onDone, boxOpts)
    fixture.displays[#fixture.displays + 1] = {
      text = text, options = boxOpts,
    }
    if boxOpts and boxOpts.choice then
      local choice = table.remove(fixture.choices, 1)
      if choice == nil then choice = false end
      boxOpts.choice(choice)
    elseif onDone then
      onDone()
    end
    return true
  end

  local function openMenu(_, title, rows, menuOpts)
    local menu = { title = title, rows = rows, options = menuOpts }
    function menu:close()
      self.closed = true
      fixture.closedMenus = fixture.closedMenus + 1
    end
    fixture.menus[#fixture.menus + 1] = menu
    fixture.lastMenu = menu
    return true
  end

  local function addItem(addGame, item)
    if fixture.bagFull then return false end
    addGame.save.inventory[item] = 1
    local present = false
    for _, value in ipairs(addGame.save.bagOrder) do
      if value == item then present = true end
    end
    if not present then
      addGame.save.bagOrder[#addGame.save.bagOrder + 1] = item
    end
    return true
  end

  local hub = createHub(mod, {
    state = state,
    content = content,
    early = early,
    mythic = mythic,
    i18n = i18n,
    showText = showText,
    openMenu = openMenu,
    addItem = addItem,
  })

  fixture.hub = hub
  fixture.game = game
  fixture.mod = mod
  fixture.hooks = hooks
  fixture.options = options
  fixture.early = early
  fixture.mythic = mythic
  fixture.content = content
  fixture.language = function(value) language = value end
  fixture.badges = function(value) badges = value end
  fixture.choose = function(value)
    fixture.choices[#fixture.choices + 1] = value
  end
  return fixture
end

-- ------------------------------------------------------ physical repair flow

local repair = newHarness()
check(repair.hub.install(repair.game), "the hub installs its content binding")
equal(#repair.installs, 1, "content is installed once")
equal(repair.contentCallbacks.canTravel(), true,
  "physical travel unlocks only after the field quest starts")
repair.root.earlyJohto.questStarted = false
equal(repair.contentCallbacks.canTravel(), false,
  "the WORLD menu cannot bypass the field quest")
repair.root.earlyJohto.questStarted = true

local npc = { frozen = false }
repair.contentCallbacks.onResearcher(repair.game, nil, npc, function()
  repair.doneCalls = repair.doneCalls + 1
end)
equal(repair.repairCalls, 1, "the first visit repairs the receiver")
equal(repair.root.earlyJohto.receiverRepaired, true,
  "receiver repair persists before later choices")
equal(repair.game.save.inventory.MIGRATION_RECEIVER, 1,
  "the physical researcher grants the receiver")
equal(repair.lastMenu.title, "CHOOSE CURRENT",
  "repair leads to an explicit three-current choice")
equal(#repair.lastMenu.rows, 3, "all three currents are offered")
equal(repair.lastMenu.rows[1].right, nil,
  "the compact current selector has no colliding right column")
equal(repair.lastMenu.rows[2].right, nil,
  "wave rates move into the readable confirmation text")
equal(repair.lastMenu.rows[3].right, nil,
  "open-current rates move into the readable confirmation text")
equal(repair.setModeCalls, 0, "no current is silently selected")
local firstModeMenu = repair.lastMenu
menuRowsFit(firstModeMenu, "English current selector")
firstModeMenu.options.onChoose(firstModeMenu.rows[2], firstModeMenu)
contains(repair.displays[#repair.displays].text, "Normal: 2 PCT.",
  "choosing a row previews its rates before committing")
contains(repair.displays[#repair.displays].text, "USE THIS CURRENT?",
  "the preview asks for explicit confirmation")
equal(repair.setModeCalls, 0,
  "answering NO leaves the current untouched")
equal(firstModeMenu.closed, nil,
  "answering NO keeps the selector open")
equal(npc.frozen, true,
  "answering NO keeps the researcher interaction active")
repair.choose(true)
firstModeMenu.options.onChoose(firstModeMenu.rows[2], firstModeMenu)
equal(firstModeMenu.closed, true,
  "answering YES closes the selector before the result text")
equal(repair.root.earlyJohto.mode, "WANDERWAVES",
  "the selected current reaches the Early Johto controller")
equal(repair.root.earlyJohto.modeChosen, true,
  "an explicit choice unlocks migration")
equal(npc.frozen, false, "the researcher is released after the flow")
equal(repair.doneCalls, 1, "the map interaction completes exactly once")

repair.contentCallbacks.onResearcher(repair.game, nil, npc)
contains(repair.displays[#repair.displays].text, "0/4",
  "later researcher visits report trace progress")
repair.choose(true)
repair.contentCallbacks.onResearcher(repair.game, nil, npc)
equal(repair.lastMenu.title, "CHOOSE CURRENT",
  "the physical researcher supports later current changes")
local laterModeMenu = repair.lastMenu
repair.choose(true)
laterModeMenu.options.onChoose(laterModeMenu.rows[3], laterModeMenu)
equal(repair.root.earlyJohto.mode, "UNLEASHED",
  "later current changes use the same explicit selector")

local mythicOnly = newHarness({
  johtoEnabled = false,
  mythicEnabled = true,
})
mythicOnly.hub.onResearcher(
  mythicOnly.game, nil, { frozen = false })
equal(mythicOnly.repairCalls, 1,
  "mythic-only play can repair the shared physical receiver")
equal(mythicOnly.root.earlyJohto.mode, "KANTO_FIRST",
  "mythic-only repair keeps the migration current sealed")
equal(mythicOnly.root.earlyJohto.modeChosen, true,
  "the safe Kanto current prevents a forced migration menu")
equal(mythicOnly.setModeCalls, 1,
  "mythic-only repair records exactly one safe current")
equal(#mythicOnly.menus, 0,
  "mythic-only repair never opens the Early Johto mode selector")
contains(mythicOnly.displays[#mythicOnly.displays].text, "Mythic receiver",
  "the researcher explains the independent mythic receiver")

local allSignalsOff = newHarness({
  johtoEnabled = false,
  mythicEnabled = false,
  early = {
    questStarted = true,
    capsuleFound = true,
    receiverRepaired = true,
    modeChosen = true,
    mode = "KANTO_FIRST",
    traces = {},
  },
})
allSignalsOff.hub.onResearcher(
  allSignalsOff.game, nil, { frozen = false })
local allOffText =
  allSignalsOff.displays[#allSignalsOff.displays].text
contains(allOffText, "Signal channels:\nOFF.",
  "the researcher reports that both optional signal systems are OFF")
contains(allOffText, "receiver stays\nquiet",
  "the all-OFF researcher dialogue describes an inactive receiver")
check(allOffText:find("is listening", 1, true) == nil,
  "the all-OFF researcher dialogue never claims an active listener")

-- ---------------------------------------------------------- no menu bypass

local locked = newHarness({
  early = {
    questStarted = false,
    capsuleFound = false,
    receiverRepaired = false,
    modeChosen = false,
    traces = {},
  },
})
local lockedRows = locked.hub.johtoRows(locked.game)
equal(lockedRows[3].right, "LOCKED",
  "the compact scan row visibly reports its lock")
equal(lockedRows[4].right, "LOCKED",
  "the compact current row visibly reports its lock")
lockedRows[3].onSelect()
lockedRows[4].onSelect()
equal(locked.scanCalls, 0, "locked scan never reaches the controller")
equal(locked.setModeCalls, 0,
  "locked current selection never reaches the controller")
locked.options.johto_signals_enable = false
locked.root.earlyJohto.receiverRepaired = true
local offRows = locked.hub.johtoRows(locked.game)
equal(offRows[3].right, "OFF",
  "the compact scan row visibly reports an OFF system")
equal(offRows[4].right, "OFF",
  "the compact current row visibly reports an OFF system")
local menusBeforeOffSelection = #locked.menus
offRows[3].onSelect()
offRows[4].onSelect()
equal(locked.scanCalls, 0,
  "an OFF Johto system cannot mutate primal traces")
equal(#locked.menus, menusBeforeOffSelection,
  "an OFF current selector cannot open the migration mode menu")
equal(locked.setModeCalls, 0,
  "an OFF current selector cannot preselect a migration current")
locked.hub.openWorld(locked.game)
locked.hub.openJohto(locked.game)
locked.hub.openMythic(locked.game)
equal(locked.warpCalls, 0, "WORLD and both submenus never travel")
equal(#locked.hub.mythicRows(locked.game), 3,
  "the mythic submenu exposes guide, next step and status")
local mythicHelp = locked.hub.mythicRows(locked.game)[1]
mythicHelp.onSelect()
contains(locked.displays[#locked.displays].text, "No capsule or",
  "the guide says echoes begin without the field pre-event")
contains(locked.displays[#locked.displays].text, "??? / ???",
  "unseen mythic sources stay hidden in the guide")
contains(locked.displays[#locked.displays].text, "Return rate: 1/16.",
  "the guide explains the bound true-signal retry")
locked.game.save.pokedex.seen.MEW = true
mythicHelp.onSelect()
contains(locked.displays[#locked.displays].text, "MEW / ???",
  "a real sighting reveals only that source in the guide")

-- ----------------------------------------------------------- full BAG claim

local full = newHarness({ bagFull = true })
local fullNpc = { frozen = false }
full.hub.onResearcher(full.game, nil, fullNpc)
equal(full.root.earlyJohto.receiverRepaired, true,
  "a full BAG never rolls back receiver repair")
equal(full.game.save.inventory.MIGRATION_RECEIVER, nil,
  "a full BAG does not forge an inventory entry")
equal(full.root.earlyJohto.pendingKeyItems[1], "MIGRATION_RECEIVER",
  "the key item is safely reserved")
full.lastMenu.options.onChoose(full.lastMenu.rows[1])
full.bagFull = false
local claimed, remaining = full.hub.claimPendingItems(full.game)
equal(claimed, 1, "the reserved receiver can be reclaimed")
equal(remaining, 0, "a successful claim clears the reservation")
equal(full.game.save.inventory.MIGRATION_RECEIVER, 1,
  "the recovered receiver reaches the BAG")
equal(#full.root.earlyJohto.pendingKeyItems, 0,
  "recovery cannot duplicate the key item")

-- ------------------------------------------ authored discovery/onboarding UI

local discovery = newHarness()
discovery.choose(false)
discovery.hub.offerCapsule(discovery.game, "INSPECT IT?",
  function(yes)
    equal(yes, false, "the capsule prompt defaults to NO")
    return false, "declined", "Return later to inspect it."
  end)
equal(#discovery.displays, 2,
  "declining the capsule still shows an authored follow-up")
contains(discovery.displays[2].text, "Return later",
  "the capsule decline explains that the choice remains available")

discovery.choose(true)
discovery.hub.offerCapsule(discovery.game, "INSPECT IT?",
  function(yes)
    equal(yes, true, "the capsule choice reaches Early Johto")
    return true, "found", "Sender recovered."
  end)
equal(discovery.travelRefreshes, 2,
  "finding the capsule refreshes Pallet travel immediately and after the result closes")

local direct = newHarness()
direct.choose(true)
direct.hub.offerOnboarding(direct.game, "UNLEASHED", "START NOW?",
  function(yes)
    equal(yes, true, "direct onboarding remains an explicit opt-in")
    return true, "configured", "Receiver ready."
  end)
equal(direct.game.save.inventory.MIGRATION_RECEIVER, 1,
  "accepted direct onboarding grants the receiver")
equal(direct.travelRefreshes, 1,
  "accepted direct onboarding refreshes the physical boatman")

-- -------------------------------------------------------- physical seal gate

local seal = newHarness({
  badges = 3,
  early = {
    questStarted = true,
    capsuleFound = true,
    receiverRepaired = true,
    modeChosen = true,
    mode = "WANDERWAVES",
    traces = { forest = true, coast = true },
  },
  resonance = {
    echoes = 3,
    sealed = false,
    completed = {},
  },
})
seal.hub.onResearcher(seal.game, nil, { frozen = false })
equal(seal.gateCalls, 1,
  "exactly three echoes invoke the researcher gate")
equal(seal.sealCalls, 0, "three BADGES cannot create the seal")
contains(seal.displays[1].text, "You have 3",
  "the refusal reports actual BADGE progress")

seal.badges(4)
seal.choose(true)
seal.hub.onResearcher(seal.game, nil, { frozen = false })
equal(seal.sealCalls, 1,
  "four BADGES allow the physical researcher to create the seal")
equal(seal.root.resonance.sealed, true,
  "the completed seal persists")

-- ------------------------------------------------------ structured objective

local goals = newHarness({
  badges = 4,
  early = {
    questStarted = true,
    capsuleFound = true,
    receiverRepaired = true,
    modeChosen = true,
    mode = "WANDERWAVES",
    traces = { forest = true, coast = true },
  },
  resonance = {
    echoes = 3,
    sealed = false,
    completed = {},
  },
})
local objective = goals.hub.objective(goals.game)
local objectivePersists = goals.persistCount
equal(objective.key, "mythic_seal",
  "seal readiness outranks unfinished migration traces")
equal(objective.location, "KANTO_ASCENDANT_DRIFTGLASS",
  "the seal objective points to the physical outpost")
equal(objective.current, 3, "the objective exposes current progress")
equal(objective.total, 3, "the objective exposes its target")
check(type(objective.detail) == "string",
  "the objective exposes tracker detail")
equal(goals.persistCount, objectivePersists,
  "reading the structured objective does not persist progress")

local preStarter = newHarness({ hasStarter = false, hasPokedex = false })
equal(preStarter.hub.objective(preStarter.game).key, "signals_starter",
  "the tracker never reveals a foreign signal before starter choice")
local preDex = newHarness({ hasPokedex = false })
equal(preDex.hub.objective(preDex.game).key, "signals_pokedex",
  "the tracker directs the player to Oak before either signal system")
local hiddenCapsule = newHarness({
  mythicEnabled = false,
  early = {
    questStarted = false,
    capsuleFound = false,
    capsuleAvailable = false,
    receiverRepaired = false,
    modeChosen = false,
    mode = "KANTO_FIRST",
    traces = {},
  },
})
equal(hiddenCapsule.hub.objective(hiddenCapsule.game), nil,
  "Journal and Atlas do not reveal Pallet before the hidden capsule gate")
hiddenCapsule.root.earlyJohto.capsuleAvailable = true
equal(hiddenCapsule.hub.objective(hiddenCapsule.game).key, "johto_capsule",
  "the shore objective appears once the capsule can really be found")
local earlyThirdEcho = newHarness({
  johtoEnabled = false,
  mythicEnabled = true,
  early = {
    questStarted = false,
    capsuleFound = false,
    capsuleAvailable = false,
    receiverRepaired = false,
    modeChosen = false,
    mode = "KANTO_FIRST",
    traces = {},
  },
  resonance = {
    echoes = 3,
    sealed = false,
    completed = {},
  },
})
equal(earlyThirdEcho.hub.objective(earlyThirdEcho.game).key,
  "mythic_receiver_wait",
  "a lucky third echo never points at an inaccessible outpost")
earlyThirdEcho.root.earlyJohto.capsuleAvailable = true
equal(earlyThirdEcho.hub.objective(earlyThirdEcho.game).key, "johto_capsule",
  "the mythic-only objective follows the capsule once it truly exists")

local oneMythic = newHarness({
  johtoEnabled = false,
  activeMythics = { "MEW" },
  resonance = {
    echoes = 3,
    sealed = true,
    completed = {},
  },
})
objective = oneMythic.hub.objective(oneMythic.game)
equal(objective.key, "mythic_manifestations",
  "a single enabled mythical still has a true-signal objective")
equal(objective.total, 1,
  "the true-signal target follows the enabled mythical pool")
local noMythics = newHarness({
  johtoEnabled = false,
  activeMythics = {},
  resonance = {
    echoes = 0,
    sealed = false,
    completed = {},
  },
})
equal(noMythics.hub.objective(noMythics.game), nil,
  "disabling both mythical species cannot leave an impossible objective")

goals.options.mythic_signals = false
objective = goals.hub.objective(goals.game)
equal(objective.key, "johto_traces",
  "a disabled mythic system is omitted from objectives")
equal(objective.current, 2, "trace progress remains visible")
equal(objective.total, 4, "all four primal traces are represented")
goals.options.johto_signals_enable = false
equal(goals.hub.objective(goals.game), nil,
  "no objective is emitted when both systems are disabled")

-- -------------------------------------------------------- menu and language

local menus = newHarness()
local hook = menus.hooks["ui.start_menu.items"]
check(hook ~= nil, "the WORLD Start-menu wrapper is registered")
local output = hook.fn(function(_, rows) return rows end,
  menus.game, { { label = "SAVE" } })
equal(#output, 2, "one and only one WORLD row is inserted")
local worldRow = output[2]
equal(worldRow.label, "WORLD", "the public row is WORLD")
equal(worldRow.ascendantLabel, "WORLD",
  "the ASCENDANT gateway also displays WORLD")
equal(worldRow.ascendantKey, "johto_signals_world",
  "the WORLD row owns a stable key")
worldRow.onSelect()
equal(#menus.lastMenu.rows, 2,
  "WORLD opens Johto and Mythic Signals only")
equal(menus.lastMenu.rows[1].label, "JOHTO SIGNALS",
  "the first WORLD row is Johto Signals")
equal(menus.lastMenu.rows[2].label, "MYTHIC SIGNALS",
  "the second WORLD row is Mythic Signals")

menus.language("de")
local locations = menus.hub.atlasLocations()
equal(locations.KANTO_ASCENDANT_DRIFTGLASS, "DRIFTGLAS-POSTEN",
  "the Atlas exposes the localized outpost")
local germanRows = menus.hub.worldRows(menus.game)
equal(germanRows[1].label, "JOHTO-SIGNALE",
  "the Johto row is localized")
equal(germanRows[2].label, "MYTHOS-SIGNALE",
  "the mythic row is localized")
local germanObjective = menus.hub.objective(menus.game)
check(germanObjective.title ~= nil and germanObjective.location ~= nil,
  "structured tracker fields exist in German")

local german = newHarness({ language = "de" })
german.hub.onResearcher(german.game, nil, { frozen = false })
contains(german.displays[1].text, "FORSCHER",
  "the physical researcher speaks German")
equal(german.lastMenu.title, "STROM WÄHLEN",
  "the forced mode selector is localized")
equal(#german.lastMenu.rows, 3,
  "the German flow preserves all three choices")
equal(german.lastMenu.rows[2].right, nil,
  "the German selector also avoids a colliding right column")
menuRowsFit(german.lastMenu, "German current selector")

-- Every hub-authored displayed line fits the compact text box and uses the
-- Gen-I wording for percentages.
for _, row in ipairs(repair.displays) do
  local textLines = row.text:gsub("\f", "\n")
  for line in (textLines .. "\n"):gmatch("(.-)\n") do
    check(#line <= 18,
      "English hub text fits an 18-character line: " .. line)
  end
  check(not row.text:find("%%"),
    "English hub text never uses a percent glyph")
end
for _, row in ipairs(german.displays) do
  local textLines = row.text:gsub("\f", "\n")
  for line in (textLines .. "\n"):gmatch("(.-)\n") do
    local visible = #line
      - select(2, line:gsub("[\128-\191]", ""))
    check(visible <= 18,
      "German hub text fits an 18-character line: " .. line)
  end
  check(not row.text:find("%%"),
    "German hub text never uses a percent glyph")
end

local file = assert(io.open(rootDir .. "/johto_signals_hub.lua", "rb"))
local hubSource = file:read("*a")
file:close()
for _, token in ipairs({
  "STAR" .. "FALL",
  "OR" .. "ANGE",
  "FAI" .. "RY",
  "JIRA" .. "CHI",
}) do
  check(not hubSource:upper():find(token, 1, true),
    "the production hub excludes deferred identifiers")
end

print(("johto_signals_hub_test: PASS (%d assertions)"):format(assertions))
