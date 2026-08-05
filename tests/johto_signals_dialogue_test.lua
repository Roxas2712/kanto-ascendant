-- Deterministic EN/DE dialogue-width coverage for Kanto Ascendant 6.0.
--
-- Unlike a source-text grep, this suite calls the production public text
-- APIs, renders their dynamic variants and captures actual hub TextBoxes.
--
-- Run from the mod directory:
--   ../gen1recomp/.tools/luajit-src/src/luajit \
--     tests/johto_signals_dialogue_test.lua

local source = debug.getinfo(1, "S").source
local testDir = source:sub(1, 1) == "@"
  and source:sub(2):match("^(.*)/[^/]+$") or "tests"
local rootDir = testDir:match("^(.*)/tests$") or "."

local createEarly = assert(loadfile(rootDir .. "/johto_signals.lua"))()
local ContentModule =
  assert(loadfile(rootDir .. "/johto_signals_content.lua"))()
local createHub = assert(loadfile(rootDir .. "/johto_signals_hub.lua"))()
local createMythic = assert(loadfile(rootDir .. "/mythic_signals.lua"))()
local PrismModule =
  assert(loadfile(rootDir .. "/driftglass_prisms.lua"))()

local assertions = 0
local checkedTexts = 0
local checkedLines = 0

local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end

local function visibleLength(text)
  local count = 0
  for index = 1, #text do
    local byte = text:byte(index)
    if byte < 128 or byte >= 192 then count = count + 1 end
  end
  return count
end

local function checkText(label, text)
  checkedTexts = checkedTexts + 1
  check(type(text) == "string" and text ~= "",
    label .. " returns visible text")
  local normalized = text:gsub("\f", "\n")
  for line in (normalized .. "\n"):gmatch("(.-)\n") do
    checkedLines = checkedLines + 1
    check(visibleLength(line) <= 18,
      ("%s exceeds 18 visible characters (%d): %q")
        :format(label, visibleLength(line), line))
  end
end

local function checkCompact(label, text)
  check(type(text) == "string" and text ~= "",
    label .. " is present")
  check(not text:find("[\n\f]"), label .. " stays on one UI line")
  check(visibleLength(text) <= 20,
    ("%s is not compact (%d): %q")
      :format(label, visibleLength(text), text))
end

local function registry()
  local values = {}
  return {
    values = values,
    register = function(_, key, value) values[key] = value end,
    get = function(_, key) return values[key] end,
  }
end

local BADGES = {
  "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
  "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
}

local HABITATS = {
  CHIKORITA = { map = "ROUTE_24", terrain = "grass", level = 18 },
  TOTODILE = {
    map = "SEAFOAM_ISLANDS_B2F", terrain = "indoor", level = 22,
  },
  CYNDAQUIL = {
    map = "POKEMON_MANSION_B1F", terrain = "indoor", level = 22,
  },
  LARVITAR = {
    map = "VICTORY_ROAD_3F", terrain = "indoor", level = 45,
  },
}

local function newSystem(language)
  local root = {
    earlyJohto = {},
    resonance = { echoes = 0, completed = {} },
    prismGrotto = {},
  }
  local state = {}
  function state.section(name)
    root[name] = type(root[name]) == "table" and root[name] or {}
    return root[name]
  end
  function state.persist() return true end
  function state.install() return true end

  local i18n = {}
  function i18n.text(english, german)
    return language == "de" and german or english
  end

  local options = {
    johto_signals_enable = true,
    johto_signals_start = "quest",
    mythic_signals = true,
    legend_mew = true,
    legend_celebi = true,
  }
  local hookRows, eventRows = {}, {}
  local mod = {
    id = "trainer_rematch",
    options = {
      get = function(_, key) return options[key] end,
    },
    hooks = {},
    events = {},
    content = {
      items = registry(),
      maps = registry(),
      map_scripts = registry(),
      map_songs = registry(),
    },
    save = {
      get = function() return nil end,
      set = function() end,
    },
    ui = {},
    world = {},
  }
  function mod.hooks:wrap(name, fn, priority)
    hookRows[name] = hookRows[name] or {}
    hookRows[name][#hookRows[name] + 1] = {
      fn = fn, priority = priority,
    }
  end
  function mod.events:on(name, fn, priority)
    eventRows[name] = eventRows[name] or {}
    eventRows[name][#eventRows[name] + 1] = {
      fn = fn, priority = priority,
    }
  end
  function mod.ui.insertBefore(rows, _, row)
    rows[#rows + 1] = row
    return rows
  end

  local shown, menus = {}, {}
  local bagFull = false
  local function showText(_, text, onDone, boxOptions)
    checkText(language .. " TextBox", text)
    shown[#shown + 1] = {
      text = text, onDone = onDone, options = boxOptions,
    }
    return true
  end
  local function openMenu(_, title, rows, menuOptions)
    checkCompact(language .. " menu title", title)
    for index, row in ipairs(rows or {}) do
      checkCompact(("%s menu row %d"):format(language, index), row.label)
      local renderedWidth = visibleLength(row.label)
      if row.right then
        checkCompact(("%s menu right %d"):format(language, index), row.right)
        renderedWidth = renderedWidth + 1 + visibleLength(row.right)
      end
      check(renderedWidth <= 17,
        ("%s menu row %d exceeds the ListMenu width (%d): %q")
          :format(language, index, renderedWidth, row.label))
      if row.detail then
        checkText(("%s menu detail %d"):format(language, index), row.detail)
      end
    end
    menus[#menus + 1] = {
      title = title, rows = rows, options = menuOptions,
    }
    return true
  end

  local content = ContentModule.create(mod, {
    state = state,
    i18n = i18n,
    showText = showText,
  })
  content.register()

  local game = {
    data = {
      items = mod.content.items.values,
      pokemon = {
        CHIKORITA = { name = "CHIKORITA" },
        TOTODILE = { name = "TOTODILE" },
        CYNDAQUIL = { name = "CYNDAQUIL" },
        LARVITAR = { name = "LARVITAR" },
        MEW = { name = "MEW" },
        CELEBI = { name = "CELEBI" },
        EEVEE = { name = "EEVEE" },
        ESPEON = { name = "ESPEON" },
        UMBREON = { name = "UMBREON" },
      },
    },
    save = {
      flags = { EVENT_GOT_POKEDEX = true },
      inventory = {},
      bagOrder = {},
      party = { { species = "BULBASAUR", level = 20 } },
      pokedex = { seen = {}, owned = {} },
      player = { map = "PALLET_TOWN" },
    },
    overworld = { map = { id = "PALLET_TOWN" } },
    stack = { push = function() end },
  }

  local early = createEarly(mod, {
    state = state,
    content = content,
    johtoData = {
      habitats = HABITATS,
      germanNames = {
        CHIKORITA = "ENDIVIE",
        TOTODILE = "KARNIMANI",
        CYNDAQUIL = "FEURIGEL",
        LARVITAR = "LARVITAR",
      },
    },
    i18n = i18n,
    startPolicy = function() return options.johto_signals_start end,
    random = function(_, maximum) return maximum end,
  })
  early.install(game)

  local mythic = createMythic(mod, {
    state = state,
    content = content,
    johtoSignals = early,
    i18n = i18n,
  })
  local prism = PrismModule.create(mod, {
    state = state,
    content = content,
    i18n = i18n,
    showText = showText,
    openMenu = openMenu,
    addItem = function(addGame, item)
      if bagFull then return false end
      addGame.save.inventory[item] = 1
      addGame.save.bagOrder[#addGame.save.bagOrder + 1] = item
      return true
    end,
  })
  prism.register()
  prism.install(game)
  local hub = createHub(mod, {
    state = state,
    content = content,
    early = early,
    mythic = mythic,
    prisms = prism,
    i18n = i18n,
    showText = showText,
    openMenu = openMenu,
    addItem = function(addGame, item)
      if bagFull then return false end
      addGame.save.inventory[item] = 1
      addGame.save.bagOrder[#addGame.save.bagOrder + 1] = item
      return true
    end,
  })

  return {
    root = root,
    state = state,
    options = options,
    game = game,
    content = content,
    early = early,
    mythic = mythic,
    prism = prism,
    hub = hub,
    shown = shown,
    menus = menus,
    events = eventRows,
    setBagFull = function(value) bagFull = value == true end,
  }
end

local function clear(target)
  for key in pairs(target) do target[key] = nil end
end

local function setEarly(system, values)
  clear(system.root.earlyJohto)
  for key, value in pairs(values or {}) do
    system.root.earlyJohto[key] = value
  end
  return system.early.state()
end

local function setMythic(system, values)
  clear(system.root.resonance)
  for key, value in pairs(values or {}) do
    system.root.resonance[key] = value
  end
  return system.mythic.state()
end

local function setPrism(system, values)
  clear(system.root.prismGrotto)
  for key, value in pairs(values or {}) do
    system.root.prismGrotto[key] = value
  end
  return system.root.prismGrotto
end

local function addBadges(game, amount)
  for _, badge in ipairs(BADGES) do game.save.inventory[badge] = nil end
  for index = 1, amount do game.save.inventory[BADGES[index]] = 1 end
end

local function textResult(label, ...)
  local values = { ... }
  local text
  for index = #values, 1, -1 do
    if type(values[index]) == "string" then
      text = values[index]
      break
    end
  end
  checkText(label, text)
  return values
end

local function checkContent(system, language)
  for key, text in pairs(system.content.dialogue()) do
    checkText(language .. " content." .. key, text)
  end
end

local function checkEarly(system, language)
  local early, game = system.early, system.game
  for _, key in ipairs({
    "offer", "taken", "postponed", "sealed", "opened", "declined",
  }) do
    checkText(language .. " early.capsule." .. key, early.capsuleText(key))
  end
  for _, mode in ipairs({
    early.modes.KANTO_FIRST,
    early.modes.WANDERWAVES,
    early.modes.UNLEASHED,
  }) do
    checkText(language .. " early.onboarding." .. mode,
      early.onboardingText(mode))
  end

  setEarly(system, {})
  system.options.johto_signals_start = "waves"
  check(early.maybeRequestOnboarding(game) == true,
    "from-start onboarding exposes its public confirmation")
  textResult(language .. " early.onboarding.accepted",
    early.completeOnboarding(true, "WANDERWAVES", game))
  setEarly(system, {})
  check(early.maybeRequestOnboarding(game) == true,
    "from-start onboarding can be tested on a fresh save state")
  textResult(language .. " early.onboarding.declined",
    early.completeOnboarding(false, "WANDERWAVES", game))
  system.options.johto_signals_start = "quest"

  setEarly(system, {})
  textResult(language .. " early.inspect.not-ready",
    early.inspectCapsule(true, game))
  local ready = setEarly(system, {
    capsuleAvailable = true, capsuleTarget = 128, pokedexSteps = 128,
  })
  textResult(language .. " early.inspect.declined",
    early.inspectCapsule(false, game))
  textResult(language .. " early.inspect.taken",
    early.inspectCapsule(true, game))
  textResult(language .. " early.inspect.already",
    early.inspectCapsule(true, game))
  check(ready.capsuleTaken == true, "capsule action reached taken state")
  check(ready.capsuleFound ~= true,
    "taking the capsule does not silently open it")
  textResult(language .. " early.open.postponed",
    early.openCapsule(false, game))
  textResult(language .. " early.open.opened",
    early.openCapsule(true, game))
  textResult(language .. " early.open.already",
    early.openCapsule(true, game))
  check(ready.capsuleFound == true and ready.capsuleOpened == true,
    "opening the capsule begins the field quest")
  textResult(language .. " early.boatman.briefed",
    early.onBoatmanCoordinates(game))

  setEarly(system, {})
  textResult(language .. " early.repair.missing",
    early.onResearcherRepair(game))
  setEarly(system, {
    capsuleFound = true, capsuleTaken = true, capsuleOpened = true,
    boatmanBriefed = true, questStarted = true,
  })
  textResult(language .. " early.repair.success",
    early.onResearcherRepair(game))
  textResult(language .. " early.repair.already",
    early.onResearcherRepair(game))

  setEarly(system, {})
  textResult(language .. " early.mode.locked",
    early.setMode(game, early.modes.WANDERWAVES))
  setEarly(system, { receiverRepaired = true })
  textResult(language .. " early.mode.invalid",
    early.setMode(game, "INVALID"))
  for _, mode in ipairs({
    early.modes.KANTO_FIRST,
    early.modes.WANDERWAVES,
    early.modes.UNLEASHED,
  }) do
    setEarly(system, { receiverRepaired = true })
    textResult(language .. " early.mode." .. mode,
      early.setMode(game, mode))
  end

  setEarly(system, {})
  textResult(language .. " early.scan.locked",
    early.scanTrace(game, "ROUTE_1"))
  setEarly(system, { receiverRepaired = true })
  textResult(language .. " early.scan.weak",
    early.scanTrace(game, "ROUTE_1"))
  local sites = {
    { "CHIKORITA", "VIRIDIAN_FOREST" },
    { "TOTODILE", "ROUTE_6" },
    { "CYNDAQUIL", "POKEMON_MANSION_B1F" },
    { "LARVITAR", "VICTORY_ROAD_3F" },
  }
  for _, row in ipairs(sites) do
    setEarly(system, { receiverRepaired = true })
    game.save.pokedex.seen[row[1]] = false
    textResult(language .. " early.scan.new.unknown." .. row[1],
      early.scanTrace(game, row[2]))
    textResult(language .. " early.scan.repeat." .. row[1],
      early.scanTrace(game, row[2]))
    setEarly(system, { receiverRepaired = true })
    game.save.pokedex.seen[row[1]] = true
    textResult(language .. " early.scan.new.known." .. row[1],
      early.scanTrace(game, row[2]))
  end
  setEarly(system, {
    receiverRepaired = true,
    traces = {
      forest = true, coast = true, ember = true, stone = true,
    },
  })
  textResult(language .. " early.scan.complete",
    early.scanTrace(game, "ROUTE_1"))

  local scenarios = {
    { "no-starter", {}, function() game.save.party = {} end },
    { "no-dex", {}, function()
        game.save.party = { { level = 5 } }
        game.save.flags.EVENT_GOT_POKEDEX = nil
      end },
    { "journey", {}, function()
        game.save.flags.EVENT_GOT_POKEDEX = true
      end },
    { "shore", { capsuleAvailable = true } },
    { "sealed", {
        capsuleTaken = true, capsuleAvailable = true,
      } },
    { "boatman", {
        capsuleFound = true, capsuleTaken = true, capsuleOpened = true,
        questStarted = true,
      } },
    { "repair", {
        capsuleFound = true, capsuleTaken = true, capsuleOpened = true,
        boatmanBriefed = true, questStarted = true,
      } },
    { "choice", {
        capsuleFound = true, capsuleTaken = true, capsuleOpened = true,
        boatmanBriefed = true, receiverRepaired = true, questStarted = true,
      } },
    { "kanto", {
        capsuleFound = true, capsuleTaken = true, capsuleOpened = true,
        boatmanBriefed = true, receiverRepaired = true, questStarted = true,
        modeChosen = true, mode = early.modes.KANTO_FIRST,
      } },
    { "trace", {
        capsuleFound = true, capsuleTaken = true, capsuleOpened = true,
        boatmanBriefed = true, receiverRepaired = true, questStarted = true,
        modeChosen = true, mode = early.modes.WANDERWAVES,
      } },
    { "strong-wave", {
        capsuleFound = true, capsuleTaken = true, capsuleOpened = true,
        boatmanBriefed = true, receiverRepaired = true, questStarted = true,
        modeChosen = true, mode = early.modes.WANDERWAVES,
        strongSignal = true,
      } },
    { "unleashed", {
        capsuleFound = true, capsuleTaken = true, capsuleOpened = true,
        boatmanBriefed = true, receiverRepaired = true, questStarted = true,
        modeChosen = true, mode = early.modes.UNLEASHED,
      } },
    { "complete", {
        capsuleFound = true, capsuleTaken = true, capsuleOpened = true,
        boatmanBriefed = true, receiverRepaired = true, questStarted = true,
        modeChosen = true, mode = early.modes.WANDERWAVES,
        traces = {
          forest = true, coast = true, ember = true, stone = true,
        },
      } },
  }
  for _, row in ipairs(scenarios) do
    setEarly(system, row[2])
    if row[3] then row[3]() end
    checkText(language .. " early.objective." .. row[1],
      early.objective(game))
    checkText(language .. " early.status." .. row[1],
      early.status(game))
  end
  game.save.party = { { level = 20 } }
  game.save.flags.EVENT_GOT_POKEDEX = true
  system.options.johto_signals_enable = false
  checkText(language .. " early.objective.disabled", early.objective(game))
  checkText(language .. " early.status.disabled", early.status(game))
  system.options.johto_signals_enable = true
end

local function checkMythic(system, language)
  local mythic, game = system.mythic, system.game
  local function read(tag)
    checkText(language .. " mythic.status." .. tag, mythic.status(game))
    checkText(language .. " mythic.objective." .. tag, mythic.objective(game))
    checkText(language .. " mythic.researcher." .. tag,
      mythic.researcherDialogue(game))
  end

  system.options.mythic_signals = false
  setMythic(system, {})
  read("disabled")
  textResult(language .. " mythic.gate.disabled",
    mythic.researcherCanSeal(game))
  system.options.mythic_signals = true

  setMythic(system, { completed = { MEW = true, CELEBI = true } })
  read("complete")
  setMythic(system, {})
  game.save.flags.EVENT_GOT_POKEDEX = nil
  read("no-dex")
  game.save.flags.EVENT_GOT_POKEDEX = true
  read("echoes")
  textResult(language .. " mythic.gate.echoes",
    mythic.researcherCanSeal(game))

  setMythic(system, { echoes = 3 })
  setEarly(system, { receiverRepaired = false })
  read("sender")
  textResult(language .. " mythic.gate.sender",
    mythic.researcherCanSeal(game))
  setEarly(system, { receiverRepaired = true })
  addBadges(game, 3)
  read("badges")
  textResult(language .. " mythic.gate.badges",
    mythic.researcherCanSeal(game))
  addBadges(game, 4)
  read("ready")
  textResult(language .. " mythic.gate.ready",
    mythic.researcherCanSeal(game))

  setMythic(system, { echoes = 3, sealed = true })
  read("sealed")
  textResult(language .. " mythic.gate.sealed",
    mythic.researcherCanSeal(game))
  setMythic(system, {
    echoes = 3,
    sealed = true,
    bound = { species = "CELEBI", level = 60, retryRolls = 31 },
  })
  game.save.pokedex.seen.CELEBI = true
  read("bound")

  setMythic(system, { echoes = 3 })
  textResult(language .. " mythic.seal.success",
    mythic.researcherSeal(game))

  local handlers = system.events["battle.turn_ended"] or {}
  check(#handlers == 0,
    "mythic echoes no longer carry a timed self-flee dialogue")
end

local function checkPrism(system, language)
  local prism, game = system.prism, system.game
  local function shown()
    return assert(system.shown[#system.shown], "expected Prism TextBox")
  end
  local function finishText()
    local row = shown()
    if row.onDone then row.onDone() end
    return row
  end
  local function choosePuzzle(key, yes)
    local menu = assert(system.menus[#system.menus],
      "expected Prism archive menu")
    local selected
    for _, row in ipairs(menu.rows or {}) do
      if row.value == key then selected = row break end
    end
    check(selected ~= nil, "Prism archive exposes " .. key)
    menu.options.onChoose(selected, {
      close = function() end,
    })
    local prompt = shown()
    check(prompt.options and type(prompt.options.choice) == "function",
      key .. " renders a yes/no inscription prompt")
    prompt.options.choice(yes)
  end

  for key, text in pairs(prism.dialogues(game)) do
    checkText(language .. " prism." .. key, text)
  end
  for key, puzzle in pairs(prism.puzzles) do
    local index = language == "de" and 2 or 1
    checkText(language .. " prism.riddle." .. key, puzzle.riddle[index])
  end
  checkText(language .. " prism.mode.unleashed",
    prism.modeHint("UNLEASHED"))
  checkText(language .. " prism.mode.optional",
    prism.modeHint("KANTO_FIRST"))

  setEarly(system, {})
  prism.enter(game)
  setEarly(system, { receiverRepaired = true })
  prism.enter(game)
  shown().options.choice(false)

  setPrism(system, {})
  game.save.party = {}
  prism.interactReader(game, { frozen = false })
  finishText() -- one-time introduction opens the archive
  choosePuzzle("twilight", true)
  -- Refusal returns to the archive after its explanatory text.
  finishText()

  game.save.party = {
    { species = "ESPEON" },
    { species = "UMBREON" },
    { species = "EEVEE", johtoBond = 0 },
  }
  choosePuzzle("twilight", true)
  for _, statue in ipairs(prism.puzzles.twilight.sequence) do
    prism.touchStatue(game, statue)
  end

  for _, key in ipairs({
    "sunStone", "kingsRock", "metalCoat", "dragonScale", "upgrade",
  }) do
    prism.openArchive(game, { frozen = false })
    choosePuzzle(key, true)
    prism.touchStatue(game, "MOON") -- also renders the reset explanation
    for _, statue in ipairs(prism.puzzles[key].sequence) do
      prism.touchStatue(game, statue)
    end
  end

  prism.openArchive(game, { frozen = false })
  choosePuzzle("sunStone", true)
  for _, statue in ipairs(prism.puzzles.sunStone.sequence) do
    prism.touchStatue(game, statue)
  end
  prism.leave(game)
  shown().options.choice(false)
  game.save.party = { { species = "BULBASAUR", level = 20 } }
end

local function checkHub(system, language)
  local hub, game = system.hub, system.game
  setEarly(system, {
    questStarted = true,
    capsuleFound = true,
    capsuleTaken = true,
    capsuleOpened = true,
    boatmanBriefed = true,
    receiverRepaired = true,
    modeChosen = true,
    mode = system.early.modes.WANDERWAVES,
    traces = {},
  })
  setMythic(system, { echoes = 0 })

  hub.openWorld(game)
  hub.openJohto(game)
  hub.openMythic(game)
  hub.openModeChoice(game)
  local modeMenu = system.menus[#system.menus]
  for _, row in ipairs(modeMenu.rows) do
    modeMenu.options.onChoose(row)
  end

  setEarly(system, {})
  local rows = hub.johtoRows(game)
  rows[1].onSelect()
  rows[2].onSelect()
  rows[3].onSelect()
  rows[4].onSelect()
  setEarly(system, {
    receiverRepaired = true,
    modeChosen = true,
    mode = system.early.modes.WANDERWAVES,
  })
  hub.johtoRows(game)[2].onSelect()
  for _, row in ipairs(hub.mythicRows(game)) do row.onSelect() end

  setEarly(system, {
    questStarted = true, capsuleFound = true, capsuleTaken = true,
    capsuleOpened = true, boatmanBriefed = true, receiverRepaired = false,
  })
  hub.onResearcher(game, nil, { frozen = false })

  game.save.inventory.MIGRATION_RECEIVER = nil
  setEarly(system, {
    questStarted = true, capsuleFound = true, capsuleTaken = true,
    capsuleOpened = true, boatmanBriefed = true, receiverRepaired = false,
  })
  system.setBagFull(true)
  hub.onResearcher(game, nil, { frozen = false })
  system.setBagFull(false)
  game.save.inventory.MIGRATION_RECEIVER = 1
  setEarly(system, {
    questStarted = true, capsuleFound = true, capsuleTaken = true,
    capsuleOpened = true, boatmanBriefed = true, receiverRepaired = false,
  })
  hub.onResearcher(game, nil, { frozen = false })
  setEarly(system, {
    receiverRepaired = true, modeChosen = true,
    mode = system.early.modes.UNLEASHED,
  })
  setMythic(system, { echoes = 0 })
  hub.onResearcher(game, nil, { frozen = false })

  system.options.johto_signals_enable = false
  setEarly(system, {
    questStarted = true, capsuleFound = true, receiverRepaired = true,
    modeChosen = true, mode = system.early.modes.KANTO_FIRST,
  })
  setMythic(system, { echoes = 0 })
  hub.onResearcher(game, nil, { frozen = false })
  system.options.johto_signals_enable = true

  setEarly(system, {
    receiverRepaired = true, modeChosen = true,
    mode = system.early.modes.KANTO_FIRST,
  })
  setMythic(system, { echoes = 3 })
  addBadges(game, 3)
  hub.onResearcher(game, nil, { frozen = false })
  addBadges(game, 4)
  hub.onResearcher(game, nil, { frozen = false })

  system.root.earlyJohto.pendingKeyItems = { "MIGRATION_RECEIVER" }
  game.save.inventory.MIGRATION_RECEIVER = nil
  local claimed, remaining, claimText = hub.claimPendingItems(game)
  check(claimed == 1 and remaining == 0,
    "pending receiver produces the claim dialogue")
  checkText(language .. " hub.claim", claimText)
  system.root.earlyJohto.pendingKeyItems = { "MIGRATION_RECEIVER" }
  game.save.inventory.MIGRATION_RECEIVER = nil
  system.setBagFull(true)
  claimed, remaining, claimText = hub.claimPendingItems(game)
  check(claimed == 0 and remaining == 1,
    "full BAG produces the held-item dialogue")
  checkText(language .. " hub.claim.full", claimText)
  system.setBagFull(false)

  local objectiveStates = {
    {
      early = {}, mythic = {},
    },
    {
      early = {
        questStarted = true, capsuleFound = true, capsuleTaken = true,
        capsuleOpened = true, boatmanBriefed = true,
      },
      mythic = {},
    },
    {
      early = {
        questStarted = true, capsuleFound = true, capsuleTaken = true,
        capsuleOpened = true, boatmanBriefed = true,
        receiverRepaired = true,
      },
      mythic = {},
    },
    {
      early = {
        questStarted = true, capsuleFound = true, capsuleTaken = true,
        capsuleOpened = true, boatmanBriefed = true,
        receiverRepaired = true,
        modeChosen = true, mode = system.early.modes.WANDERWAVES,
      },
      mythic = {},
    },
    {
      early = {
        questStarted = true, capsuleFound = true, capsuleTaken = true,
        capsuleOpened = true, boatmanBriefed = true,
        receiverRepaired = true,
        modeChosen = true, mode = system.early.modes.WANDERWAVES,
        traces = {
          forest = true, coast = true, ember = true, stone = true,
        },
      },
      mythic = { echoes = 3 },
      badges = 4,
    },
    {
      early = {
        questStarted = true, capsuleFound = true, capsuleTaken = true,
        capsuleOpened = true, boatmanBriefed = true,
        receiverRepaired = true,
        modeChosen = true, mode = system.early.modes.WANDERWAVES,
        traces = {
          forest = true, coast = true, ember = true, stone = true,
        },
      },
      mythic = { echoes = 3, sealed = true },
    },
    {
      early = {
        questStarted = false, capsuleFound = false,
        capsuleAvailable = false, receiverRepaired = false,
      },
      mythic = { echoes = 3 },
      johtoEnabled = false,
    },
  }
  for index, row in ipairs(objectiveStates) do
    system.options.johto_signals_enable = row.johtoEnabled ~= false
    setEarly(system, row.early)
    setMythic(system, row.mythic)
    addBadges(game, row.badges or 0)
    local objective = hub.objective(game)
    check(objective ~= nil, "hub objective " .. index .. " exists")
    checkCompact(language .. " objective title " .. index, objective.title)
    if objective.location ~= system.hub.MAP_ID then
      checkCompact(language .. " objective location " .. index,
        objective.location)
    end
    checkText(language .. " objective detail " .. index, objective.detail)
  end
  system.options.johto_signals_enable = true
  local atlasCount = 0
  for mapId, label in pairs(hub.atlasLocations()) do
    atlasCount = atlasCount + 1
    check(mapId == system.hub.MAP_ID
        or mapId == system.prism.MAP_ID,
      "Atlas exposes only its authored Johto maps")
    checkCompact(language .. " Atlas label", label)
  end
  check(atlasCount == 2, "Atlas exposes Driftglass and Prism Grotto")
end

for _, language in ipairs({ "en", "de" }) do
  local system = newSystem(language)
  checkContent(system, language)
  checkEarly(system, language)
  checkMythic(system, language)
  checkPrism(system, language)
  checkHub(system, language)
end

print(("johto_signals_dialogue_test: PASS "
  .. "(%d assertions, %d texts, %d rendered lines)")
  :format(assertions, checkedTexts, checkedLines))
