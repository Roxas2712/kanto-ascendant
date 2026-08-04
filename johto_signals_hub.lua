-- Kanto Ascendant 6.0: Johto Signals presentation and story hub.
--
-- Encounter controllers own their rules.  Static content owns the physical
-- boats and outpost.  This module joins those pieces without offering remote
-- travel or remote Resonance Seal creation.

return function(mod, opts)
  opts = opts or {}

  local state = assert(opts.state, "Johto Signals state missing")
  local content = assert(opts.content, "Johto Signals content missing")
  local early = assert(opts.early, "Early Johto controller missing")
  local mythic = assert(opts.mythic, "Mythic Signals controller missing")
  local i18n = opts.i18n
  local worldEvents = opts.worldEvents

  local H = {
    game = nil,
    ASCENDANT_KEY = "johto_signals_world",
    MAP_ID = content.MAP_ID or "KANTO_ASCENDANT_DRIFTGLASS",
  }

  local MODES = early.modes or {
    KANTO_FIRST = "KANTO_FIRST",
    WANDERWAVES = "WANDERWAVES",
    UNLEASHED = "UNLEASHED",
  }
  local RECEIVER = content.ITEMS
      and content.ITEMS.MIGRATION_RECEIVER
    or "MIGRATION_RECEIVER"

  local function tr(english, german)
    return i18n and i18n.text and i18n.text(english, german) or english
  end

  local function persist()
    if type(state.persist) == "function" then return state.persist() end
  end

  local function earlyState()
    local value = early.state and early.state() or nil
    if type(value) == "table" then return value end
    return state.section("earlyJohto")
  end

  local function mythicState()
    local value = mythic.state and mythic.state() or nil
    if type(value) == "table" then return value end
    return state.section("resonance")
  end

  local function show(game, text, onDone, boxOpts)
    if type(opts.showText) == "function" then
      return opts.showText(game, text, onDone, boxOpts)
    end
    local TextBox = require("src.render.TextBox")
    game.stack:push(TextBox.new(game, text, onDone, boxOpts))
    return true
  end

  local function openList(game, title, rows, menuOpts)
    menuOpts = menuOpts or {}
    if type(opts.openMenu) == "function" then
      return opts.openMenu(game, title, rows, menuOpts)
    end
    game.stack:push(mod.ui.ListMenu.new(game, title, rows, menuOpts))
    return true
  end

  local function setFrozen(npc, value)
    if npc then npc.frozen = value and true or false end
  end

  local function ownsItem(game, item)
    return game and game.save and game.save.inventory
      and game.save.inventory[item] ~= nil
  end

  local function addItem(game, item)
    if ownsItem(game, item) then return true, "owned" end
    if type(opts.addItem) == "function" then
      local ok, result = pcall(opts.addItem, game, item)
      return ok and result == true, ok and nil or tostring(result)
    end
    local ok, Bag = pcall(require, "src.inventory.Bag")
    if not ok or type(Bag) ~= "table" or type(Bag.add) ~= "function" then
      return false, "bag-unavailable"
    end
    game.save.inventory = type(game.save.inventory) == "table"
      and game.save.inventory or {}
    local added = Bag.add(game.save, item, 1, game.data)
    return added == true, added and nil or "bag-full"
  end

  local function pendingItems()
    local s = earlyState()
    s.pendingKeyItems = type(s.pendingKeyItems) == "table"
      and s.pendingKeyItems or {}
    return s, s.pendingKeyItems
  end

  local function reserveItem(item)
    local _, pending = pendingItems()
    for _, existing in ipairs(pending) do
      if existing == item then return false end
    end
    pending[#pending + 1] = item
    persist()
    return true
  end

  local function receiverName(game)
    return tr("MIGRATION RECEIVER", "MIGRATIONS-EMPF.")
  end

  function H.claimPendingItems(game)
    game = game or H.game
    local s, pending = pendingItems()
    local kept, claimed = {}, 0
    for _, item in ipairs(pending) do
      if ownsItem(game, item) then
        claimed = claimed + 1
      else
        local added = addItem(game, item)
        if added then
          claimed = claimed + 1
        else
          kept[#kept + 1] = item
        end
      end
    end
    local changed = #kept ~= #pending
    s.pendingKeyItems = kept
    if changed then persist() end
    local message
    if claimed > 0 then
      message = tr(
        "RESEARCHER: Your\nkey item is ready.\f"
          .. "It was placed in\nyour BAG.",
        "FORSCHER: Dein\nSchlüsselitem ist\nbereit.\f"
          .. "Es liegt nun in\ndeinem BEUTEL.")
    elseif #kept > 0 then
      message = tr(
        "RESEARCHER: Your\nBAG is still full.\f"
          .. "I will guard the\nkey item.",
        "FORSCHER: Dein\nBEUTEL ist voll.\f"
          .. "Ich bewahre das\nSchlüsselitem auf.")
    end
    return claimed, #kept, message
  end

  local function grantReceiver(game)
    if ownsItem(game, RECEIVER) then
      return true, tr(
        "Receiver already\nin your BAG.",
        "Empfänger liegt\nim BEUTEL.")
    end
    local added = addItem(game, RECEIVER)
    if added then
      return true, tr(
        "You received:\n" .. receiverName(game),
        "Du erhältst:\n" .. receiverName(game))
    end
    reserveItem(RECEIVER)
    return false, tr(
      "Your BAG is full.\f"
        .. "Researcher keeps\nthe receiver safe.",
      "BEUTEL ist voll.\f"
        .. "Der Forscher hütet\nden Empfänger.")
  end

  function H.onCapsuleFound(game)
    game = game or H.game
    if content and type(content.refreshTravelNpc) == "function" then
      content.refreshTravelNpc(game, content.PALLET_MAP_ID or "PALLET_TOWN")
    end
    return true
  end

  -- Early owns the persisted decision; Hub owns its actual TextBox flow.
  -- Returning the controller result from `decide` lets us present both the
  -- accepted and declined authored follow-up instead of silently mutating
  -- state behind the field screen.
  function H.offerCapsule(game, text, decide)
    H.game = game or H.game
    game = game or H.game
    return show(game, text, nil, {
      defaultNo = true,
      choice = function(yes)
        local ok, reason, resultText = decide(yes)
        if ok and reason == "found" then H.onCapsuleFound(game) end
        if resultText then show(game, resultText) end
      end,
    })
  end

  function H.offerOnboarding(game, _, text, decide)
    H.game = game or H.game
    game = game or H.game
    return show(game, text, nil, {
      defaultNo = true,
      choice = function(yes)
        local ok, reason, resultText = decide(yes)
        if ok and reason == "configured" then
          local _, itemText = grantReceiver(game)
          H.onCapsuleFound(game)
          resultText = resultText and (resultText .. "\f" .. itemText)
            or itemText
        end
        if resultText then show(game, resultText) end
      end,
    })
  end

  local function modeLabel(mode)
    if mode == MODES.WANDERWAVES then
      return tr("WANDERWAVES", "WANDERWELLEN")
    end
    if mode == MODES.UNLEASHED then
      return tr("JOHTO UNLEASHED", "JOHTO ENTFESSELT")
    end
    return tr("KANTO FIRST", "KANTO ZUERST")
  end

  local function modeDetail(mode)
    if mode == MODES.WANDERWAVES then
      return tr(
        "WANDERWAVES\f"
          .. "Small Johto groups\nmove by habitat.\f"
          .. "Normal: 2 PCT.\nStrong: 4 PCT.\f"
          .. "Groups shift every\n384-768 steps.\f"
          .. "One in 4 waves is\nstrong.\f"
          .. "Starters and\nLARVITAR need\nhidden traces.\f"
          .. "Each trace scan\nshows a habitat.\f"
          .. "Rare find there:\n1/512 per battle.\nSure by 512.",
        "WANDERWELLEN\f"
          .. "Kleine Johto-\nGruppen folgen\ndem Lebensraum.\f"
          .. "Normal: 2 PROZ.\nStark: 4 PROZ.\f"
          .. "Gruppen wechseln\nnach 384-768\nSchritten.\f"
          .. "Jede 4. Welle ist\nstark.\f"
          .. "Starter und\nLARVITAR brauchen\nversteckte Spuren.\f"
          .. "Jede Urspur zeigt\neinen Lebensraum.\f"
          .. "Fund dort: 1/512.\nSicher bis 512.")
    end
    if mode == MODES.UNLEASHED then
      return tr(
        "JOHTO UNLEASHED\f"
          .. "Johto spreads into\nmatching habitats.\f"
          .. "About 10 PCT of\nwild encounters.\f"
          .. "Starters and\nLARVITAR need\nhidden traces.\f"
          .. "Each trace scan\nshows a habitat.\f"
          .. "Rare find there:\n1/256 per battle.\nSure by 256.",
        "JOHTO ENTFESSELT\f"
          .. "Johto-Pokemon sind\nweit verbreitet.\f"
          .. "Etwa 10 PROZ der\nWildbegegnungen.\f"
          .. "Starter und\nLARVITAR brauchen\nversteckte Spuren.\f"
          .. "Jede Urspur zeigt\neinen Lebensraum.\f"
          .. "Fund dort: 1/256.\nSicher bis 256.")
    end
    return tr(
      "KANTO FIRST\f"
        .. "No early Johto\nwild encounters\nare added.\f"
        .. "Mythic Signals run\nindependently.\f"
        .. "You may record\ntraces for later.",
      "KANTO ZUERST\f"
        .. "Frühe Johto-\nBegegnungen sind\naus.\f"
        .. "Mythos-Signale\nlaufen getrennt.\f"
        .. "Spuren sind schon\nauffindbar.")
  end

  local function johtoGuideText()
    return tr(
      "EARLY JOHTO\f"
        .. "Fix the receiver\nat DRIFTGLASS.\f"
        .. "Choose Johto's\nreach in Kanto.\f"
        .. "KANTO FIRST adds\nno early Johto\nwild encounters.\f"
        .. "Mythic Signals are\nseparate.\f"
        .. "WANDERWAVES:\nNormal: 2 PCT.\nStrong: 4 PCT.\f"
        .. "UNLEASHED uses\nabout 10 PCT.\f"
        .. "Four primal traces\nunlock four rare\nbase Pokemon.\f"
        .. "At the clue site,\nscan records it.\f"
        .. "The scan reveals\nits rare habitat.\f"
        .. "Names stay ???\nuntil truly seen.\f"
        .. "Rare habitat odds:\n1/512 in waves.\n1/256 unleashed.\f"
        .. "Each has a limit.",
      "FRÜHES JOHTO\f"
        .. "Repariere den\nEmpfänger auf\nDRIFTGLAS.\f"
        .. "Wähle, wie stark\nJohto Kanto füllt.\f"
        .. "KANTO ZUERST:\nKeine frühe Johto-\nWanderung.\f"
        .. "Mythos-Signale\nlaufen getrennt.\f"
        .. "WANDERWELLEN:\nNormal: 2 PROZ.\nStark: 4 PROZ.\f"
        .. "ENTFESSELT nutzt\netwa 10 PROZ.\f"
        .. "Vier Urspuren\ngeben vier seltene\nBasisarten frei.\f"
        .. "Am Hinweis-Ort\nzeichnet der Scan\ndie Spur auf.\f"
        .. "Danach zeigt er\nihren Lebensraum.\f"
        .. "Namen bleiben ???\nbis zur Sichtung.\f"
        .. "Habitat-Chancen:\n1/512 in Wellen.\n1/256 entfesselt.\f"
        .. "Feste Obergrenze.")
  end

  local function mythicSourceNames(game)
    local names = {}
    for _, row in ipairs({
      { species = "MEW", option = "legend_mew" },
      { species = "CELEBI", option = "legend_celebi" },
    }) do
      local enabled = true
      if mod.options and type(mod.options.get) == "function" then
        local value = mod.options:get(row.option)
        enabled = value ~= false and value ~= "off"
      end
      if enabled then
        local name = type(mythic.publicSpeciesName) == "function"
            and mythic.publicSpeciesName(row.species, game)
          or "???"
        names[#names + 1] = name or "???"
      end
    end
    if #names == 0 then names[1] = "---" end
    return table.concat(names, " / ")
  end

  local function mythicGuideText(game)
    local sources = mythicSourceNames(game)
    return tr(
      "MYTHIC SIGNALS\f"
        .. "Echoes start after\nthe POKEDEX.\f"
        .. "No capsule or\nreceiver needed.\f"
        .. "Echo sources:\n" .. sources .. "\f"
        .. "Names reveal when\ntruly seen.\f"
        .. "Echo level: 60+\nor team best +20.\f"
        .. "They can attack.\nThey flee in 1-3\nturns.\f"
        .. "They stay at 1 HP.\nNo BALL can catch.\f"
        .. "MASTER BALL comes\nback unused.\f"
        .. "Need 3 echoes.\nRepeats count.\f"
        .. "Repair receiver.\nEarn 4 BADGES.\f"
        .. "The researcher can\nforge a RESONANCE\nSEAL.\f"
        .. "Then true signals\ncan be caught.\f"
        .. "True signal rate:\n1/8192.\nCertain by 8192.\f"
        .. "If not caught,\nthe same signal\nstays bound.\f"
        .. "Return rate: 1/16.\nSure by 32 valid\nencounters.",
      "MYTHOS-SIGNALE\f"
        .. "Echos starten nach\ndem POKEDEX.\f"
        .. "Kapsel und\nEmpfänger noch\nnicht nötig.\f"
        .. "Echoquellen:\n" .. sources .. "\f"
        .. "Namen erscheinen\nnach Sichtung.\f"
        .. "Echo-Level: 60+\noder bestes +20.\f"
        .. "Sie greifen an.\nFlucht nach 1-3\nRunden.\f"
        .. "Sie bleiben bei\n1 KP.\f"
        .. "Kein BALL wirkt.\nMEISTERBALL\nbleibt erhalten.\f"
        .. "3 Echos nötig.\nGleiche zählen.\f"
        .. "Empfänger richten.\n4 ORDEN holen.\f"
        .. "Der Forscher baut\ndas RESONANZ-\nSIEGEL.\f"
        .. "Danach sind echte\nSignale fangbar.\f"
        .. "Rate: 1/8192.\nSicher bis 8192.\f"
        .. "Nicht gefangen?\nDasselbe Signal\nbleibt gebunden.\f"
        .. "Rückkehr: 1/16.\nSicher bis 32\nBegegnungen.")
  end

  local function traceCount(s)
    local count = 0
    local traces = s and s.traces or {}
    local known, seen = {}, {}
    for _, row in pairs(early.special or {}) do
      if type(row) == "table" and type(row.trace) == "string"
          and not seen[row.trace] then
        seen[row.trace] = true
        known[#known + 1] = row.trace
      end
    end
    if #known == 0 then
      known = { "forest", "coast", "ember", "stone" }
    end
    for _, key in ipairs(known) do
      if traces[key] == true then count = count + 1 end
    end
    return math.min(4, count)
  end

  local function currentMap(game)
    return game and game.overworld and game.overworld.map
      and game.overworld.map.id
      or game and game.save and game.save.player
      and game.save.player.map
  end

  function H.openModeChoice(game, onDone)
    local rows = {}
    for _, mode in ipairs({
      MODES.KANTO_FIRST, MODES.WANDERWAVES, MODES.UNLEASHED,
    }) do
      rows[#rows + 1] = {
        label = modeLabel(mode),
        value = mode,
        detail = modeDetail(mode),
      }
    end
    return openList(game, tr("CHOOSE CURRENT", "STROM WÄHLEN"), rows, {
      onCancel = function()
        if onDone then onDone(false) end
      end,
      onChoose = function(item, menu)
        if not item then return end
        show(game, modeDetail(item.value) .. tr(
          "\fUSE THIS CURRENT?", "\fSTROM AKTIVIEREN?"), nil, {
          defaultNo = true,
          choice = function(yes)
            if not yes then return end
            if menu and type(menu.close) == "function" then menu:close() end
            local ok, _, message = early.setMode(game, item.value)
            show(game, message, function()
              if onDone then onDone(ok == true) end
            end)
          end,
        })
      end,
    })
  end

  local function earlyEnabled()
    if type(early.enabled) == "function" then return early.enabled() ~= false end
    if mod.options and type(mod.options.get) == "function" then
      local value = mod.options:get("johto_signals_enable")
      return value ~= false and value ~= "off"
    end
    return true
  end

  local function mythicEnabled()
    if type(opts.mythicEnabled) == "function" then
      return opts.mythicEnabled() ~= false
    end
    if mod.options and type(mod.options.get) == "function" then
      local value = mod.options:get("mythic_signals")
      if value == nil then value = mod.options:get("mythic_resonance") end
      return value ~= false and value ~= "off"
    end
    return true
  end

  local function badgeCount(game)
    if type(mythic.badgeCount) == "function" then
      return math.max(0, math.floor(tonumber(mythic.badgeCount(game)) or 0))
    end
    local inventory = game and game.save and game.save.inventory or {}
    local count = 0
    for _, badge in ipairs({
      "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
      "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
    }) do
      if inventory[badge] then count = count + 1 end
    end
    return count
  end

  local function researcherStatus(game)
    local s = earlyState()
    local current = s.modeChosen
        and modeLabel(s.mode)
      or tr("NOT CHOSEN", "NICHT GEWÄHLT")
    return tr(
      "RESEARCHER:\nCurrent:\n", "FORSCHER:\nStrom:\n")
      .. current
      .. tr(
        "\fPrimal traces: ", "\fUrspuren: ")
      .. tostring(traceCount(s)) .. "/4"
      .. tr(
        "\fChange current?", "\fStrom ändern?")
  end

  local function finishResearcher(npc, onDone)
    setFrozen(npc, false)
    if onDone then onDone() end
  end

  local function statusOrMode(game, npc, onDone)
    local s = earlyState()
    if not earlyEnabled() then
      local status = mythicEnabled() and tr(
        "RESEARCHER: Johto\nmigration remains\nsealed.\f"
          .. "Mythic receiver\nis listening.",
        "FORSCHER: Johtos\nWanderung bleibt\nversiegelt.\f"
          .. "Mythos-Empfänger\nlauscht weiter.")
        or tr(
          "RESEARCHER: Johto\nmigration remains\nsealed.\f"
            .. "Signal channels:\nOFF.\f"
            .. "The receiver stays\nquiet.",
          "FORSCHER: Johtos\nWanderung bleibt\nversiegelt.\f"
            .. "Signalkanäle:\nAUS.\f"
            .. "Der Empfänger\nbleibt still.")
      return show(game, status, function()
        finishResearcher(npc, onDone)
      end)
    end
    if not s.modeChosen then
      return H.openModeChoice(game, function()
        finishResearcher(npc, onDone)
      end)
    end
    return show(game, researcherStatus(game), nil, {
      defaultNo = true,
      choice = function(yes)
        if yes then
          H.openModeChoice(game, function()
            finishResearcher(npc, onDone)
          end)
        else
          finishResearcher(npc, onDone)
        end
      end,
    })
  end

  local function sealStage(game, npc, onDone)
    local canSeal, _, message = mythic.researcherCanSeal(game)
    if not canSeal then
      return show(game, tr("RESEARCHER:\n", "FORSCHER:\n")
        .. message, function()
        statusOrMode(game, npc, onDone)
      end)
    end
    return show(game, tr("RESEARCHER:\n", "FORSCHER:\n") .. message
      .. tr(
        "\fCreate seal now?", "\fSiegel fertigen?"),
      nil, {
        defaultNo = true,
        choice = function(yes)
          if not yes then
            return statusOrMode(game, npc, onDone)
          end
          local ok, _, sealText = mythic.researcherSeal(game)
          show(game, sealText, function()
            statusOrMode(game, npc, onDone)
          end)
        end,
      })
  end

  local function nextResearcherStage(game, npc, onDone)
    local m = mythicState()
    if mythicEnabled() and m.echoes == 3 and m.sealed ~= true then
      return sealStage(game, npc, onDone)
    end
    return statusOrMode(game, npc, onDone)
  end

  function H.onResearcher(game, _, npc, onDone)
    H.game = game or H.game
    game = game or H.game
    setFrozen(npc, true)

    local _, _, claimText = H.claimPendingItems(game)
    local function begin()
      local s = earlyState()
      if not s.receiverRepaired then
        local ok, _, repairText = early.onResearcherRepair(game)
        if not ok then
          return show(game, repairText, function()
            finishResearcher(npc, onDone)
          end)
        end
        -- Mythic-only players still need the physical receiver quest, but
        -- never receive an accidental Johto encounter mode.  Store the safe
        -- Kanto current so later researcher visits do not force that menu.
        if not earlyEnabled() then
          early.setMode(game, MODES.KANTO_FIRST)
        end
        local _, itemText = grantReceiver(game)
        return show(game, repairText .. "\f" .. itemText, function()
          nextResearcherStage(game, npc, onDone)
        end)
      end
      nextResearcherStage(game, npc, onDone)
    end

    if claimText then
      show(game, claimText, begin)
    else
      begin()
    end
    return true
  end

  local function lockedText()
    return tr(
      "Repair receiver at\nDRIFTGLASS first.",
      "Empfänger zuerst\nauf DRIFTGLAS\nreparieren.")
  end

  function H.johtoRows(game)
    local repaired = earlyState().receiverRepaired == true
    local enabled = earlyEnabled()
    local rowState = not enabled and tr("OFF", "AUS")
      or (not repaired and tr("LOCKED", "GESPERRT"))
      or nil
    return {
      {
        label = tr("EXPLANATION", "ERKLÄRUNG"),
        value = "guide",
        onSelect = function()
          show(game, johtoGuideText())
        end,
      },
      {
        label = tr("STATUS", "STATUS"),
        value = "status",
        onSelect = function()
          show(game, early.status(game))
        end,
      },
      {
        label = rowState and tr("SCAN", "SCANNEN")
          or tr("SCAN AREA", "GEBIET SCANNEN"),
        right = rowState,
        value = "scan",
        onSelect = function()
          if not earlyEnabled() then
            return show(game, tr(
              "JOHTO SIGNALS are\ncurrently OFF.",
              "JOHTO-SIGNALE sind\nzurzeit AUS."))
          end
          if not earlyState().receiverRepaired then
            return show(game, lockedText())
          end
          local _, _, text = early.scanTrace(game, currentMap(game))
          show(game, text)
        end,
      },
      {
        label = rowState and tr("CURRENT", "STROM")
          or tr("CHOOSE CURRENT", "STROM WÄHLEN"),
        right = rowState,
        value = "set",
        onSelect = function()
          if not earlyEnabled() then
            return show(game, tr(
              "JOHTO SIGNALS are\ncurrently OFF.",
              "JOHTO-SIGNALE sind\nzurzeit AUS."))
          end
          if not earlyState().receiverRepaired then
            return show(game, lockedText())
          end
          H.openModeChoice(game)
        end,
      },
    }
  end

  function H.openJohto(game)
    local rows = H.johtoRows(game)
    return openList(game, tr("JOHTO SIGNALS", "JOHTO-SIGNALE"), rows, {
      onChoose = function(item)
        if item and item.onSelect then item.onSelect() end
      end,
    })
  end

  function H.mythicRows(game)
    return {
      {
        label = tr("EXPLANATION", "ERKLÄRUNG"),
        value = "guide",
        onSelect = function()
          show(game, mythicGuideText(game))
        end,
      },
      {
        label = tr("NEXT STEP", "NÄCHSTES ZIEL"),
        value = "next",
        onSelect = function()
          show(game, mythic.objective(game))
        end,
      },
      {
        label = tr("STATUS", "STATUS"),
        value = "status",
        onSelect = function()
          show(game, mythic.status(game))
        end,
      },
    }
  end

  function H.openMythic(game)
    local rows = H.mythicRows(game)
    return openList(game, tr("MYTHIC SIGNALS", "MYTHOS-SIGNALE"),
      rows, {
        onChoose = function(item)
          if item and item.onSelect then item.onSelect() end
        end,
      })
  end

  function H.worldRows(game)
    local rows = {}
    if worldEvents and type(worldEvents.statusText) == "function" then
      rows[#rows + 1] = {
        label = tr("KANTO STATUS", "KANTO-STATUS"),
        value = "kanto",
        onSelect = function()
          show(game, worldEvents.statusText(game))
        end,
      }
    end
    rows[#rows + 1] =
      {
        label = tr("JOHTO SIGNALS", "JOHTO-SIGNALE"),
        value = "johto",
        onSelect = function() H.openJohto(game) end,
      }
    rows[#rows + 1] =
      {
        label = tr("MYTHIC SIGNALS", "MYTHOS-SIGNALE"),
        value = "mythic",
        onSelect = function() H.openMythic(game) end,
      }
    return rows
  end

  function H.openWorld(game)
    local rows = H.worldRows(game)
    return openList(game, tr("WORLD", "WELT"), rows, {
      onChoose = function(item)
        if item and item.onSelect then item.onSelect() end
      end,
    })
  end

  function H.objective(game)
    local johtoOn = earlyEnabled()
    local mythicOn = mythicEnabled()
    if not johtoOn and not mythicOn then return nil end

    local e = earlyState()
    local m = mythicState()
    local mythicData = type(mythic.statusData) == "function"
        and mythic.statusData(game)
      or nil
    local traces = traceCount(e)
    local badges = badgeCount(game)
    local hasStarter = type(early.hasStarter) ~= "function"
      or early.hasStarter(game)
    local hasPokedex = type(early.hasPokedex) ~= "function"
      or early.hasPokedex(game)

    if johtoOn and not hasStarter then
      return {
        key = "signals_starter",
        title = tr("CHOOSE A POKEMON", "POKEMON AUSWÄHLEN"),
        location = tr("OAK'S LAB", "EICHS LABOR"),
        current = 0,
        total = 1,
        detail = tr(
          "Choose your first\nPokemon with OAK.",
          "Wähle dein erstes\nPokemon bei EICH."),
      }
    end
    if (johtoOn or mythicOn) and not hasPokedex then
      return {
        key = "signals_pokedex",
        title = tr("GET THE POKEDEX", "POKEDEX ERHALTEN"),
        location = tr("OAK'S LAB", "EICHS LABOR"),
        current = 0,
        total = 1,
        detail = tr(
          "Finish OAK's task.\nGet the POKEDEX.",
          "Hilf PROF.EICH.\nHol den POKEDEX."),
      }
    end

    local activeMythics = mythicData and mythicData.active or {}
    local completedMythics = 0
    for _, value in pairs(m.completed or {}) do
      if value == true then completedMythics = completedMythics + 1 end
    end
    local mythicTarget = completedMythics + #activeMythics
    if mythicData and mythicData.complete and mythicTarget == 0 then
      mythicOn = false
    end

    -- Once the third echo exists, stabilizing it is more urgent than an
    -- unfinished migration trace.
    if mythicOn and m.echoes == 3 and m.sealed ~= true then
      if not e.receiverRepaired then
        if not e.questStarted then
          if e.capsuleAvailable or e.capsuleFound then
            return {
              key = "johto_capsule",
              title = tr("FOREIGN SIGNAL", "FREMDES SIGNAL"),
              location = tr("PALLET TOWN", "ALABASTIA"),
              current = 0,
              total = 1,
              detail = tr(
                "Follow the foreign\nshore signal.",
                "Folge dem fremden\nKüstensignal."),
            }
          end
          return {
            key = "mythic_receiver_wait",
            title = tr("UNSTABLE SIGNAL", "INSTABILES SIGNAL"),
            location = tr("KANTO", "KANTO"),
            current = 3,
            total = 3,
            detail = tr(
              "Third echo clear.\nKeep exploring.",
              "Drittes Echo klar.\nErkunde Kanto."),
          }
        end
        return {
          key = "signals_repair",
          title = tr("REPAIR RECEIVER", "EMPFÄNGER DEFEKT"),
          location = H.MAP_ID,
          current = 0,
          total = 1,
          detail = tr(
            "Take the sender to\nthe researcher.",
            "Zum Forscher.\nSender mitbringen."),
        }
      end
      if badges < 4 then
        return {
          key = "mythic_badges",
          title = tr("STABILIZE SIGNAL", "SIGNAL FESTIGEN"),
          location = tr("KANTO GYMS", "KANTO-ARENEN"),
          current = badges,
          total = 4,
          detail = tr(
            "Four BADGES steady\nthe third echo.",
            "Vier ORDEN halten\ndas dritte Echo."),
        }
      end
      return {
        key = "mythic_seal",
        title = tr("CREATE THE SEAL", "SIEGEL FERTIGEN"),
        location = H.MAP_ID,
        current = 3,
        total = 3,
        detail = tr(
          "Researcher alone\ncan finish it.",
          "Nur der Forscher\nvollendet es."),
      }
    end

    if johtoOn then
      if not e.questStarted then
        -- The capsule is meant to be a genuine field discovery.  Do not let
        -- Journal or Atlas announce Pallet Town before the hidden step/visit
        -- gate has actually made the shore signal available.
        if e.capsuleAvailable or e.capsuleFound then
          return {
            key = "johto_capsule",
            title = tr("FOREIGN SIGNAL", "FREMDES SIGNAL"),
            location = tr("PALLET TOWN", "ALABASTIA"),
            current = 0,
            total = 1,
            detail = tr(
              "Follow the foreign\nshore signal.",
              "Folge dem fremden\nKüstensignal."),
          }
        end
        if not mythicOn then return nil end
      end
      if e.questStarted and not e.receiverRepaired then
        return {
          key = "signals_repair",
          title = tr("REPAIR RECEIVER", "EMPFÄNGER DEFEKT"),
          location = H.MAP_ID,
          current = 0,
          total = 1,
          detail = tr(
            "Take the sender to\nthe researcher.",
            "Zum Forscher.\nSender mitbringen."),
        }
      end
      if e.questStarted and not e.modeChosen then
        return {
          key = "johto_current",
          title = tr("CHOOSE A CURRENT", "STROM AUSWÄHLEN"),
          location = H.MAP_ID,
          current = 0,
          total = 1,
          detail = tr(
            "Choose a current.\nThree are offered.",
            "Wähle einen Strom.\nDrei zur Wahl."),
        }
      end
      if e.questStarted and traces < 4 then
        return {
          key = "johto_traces",
          title = tr("PRIMAL TRACES", "URSPUREN"),
          location = tr("KANTO", "KANTO"),
          current = traces,
          total = 4,
          detail = tr(
            "At target habitat:\fASCENDANT > WORLD\f"
              .. "JOHTO SIGNALS >\nSCAN CURRENT AREA",
            "Am Zielgebiet:\fASCENDANT > WELT\f"
              .. "JOHTO-SIGNALE >\nGEBIET SCANNEN"),
        }
      end
    end

    if mythicOn then
      if m.sealed ~= true then
        return {
          key = "mythic_echoes",
          title = tr("MYTHIC ECHOES", "MYTHOS-ECHOS"),
          location = tr("KANTO GRASS", "KANTOS GRAS"),
          current = math.max(0, math.min(3,
            math.floor(tonumber(m.echoes) or 0))),
          total = 3,
          detail = tr(
            "Witness 3 echoes\nin Kanto grass.",
            "Finde 3 Echos\nin Kantos Gras."),
        }
      end
      return {
        key = "mythic_manifestations",
        title = tr("TRUE SIGNALS", "ECHTE SIGNALE"),
        location = tr("KANTO GRASS", "KANTOS GRAS"),
        current = completedMythics,
        total = math.max(completedMythics, mythicTarget),
        detail = tr(
          "True signals enter\nKanto grass.",
          "Echte Signale sind\nnun in Kanto-Gras."),
      }
    end

    if not johtoOn then return nil end
    return {
      key = "johto_complete",
      title = tr("JOHTO SIGNALS", "JOHTO-SIGNALE"),
      location = tr("KANTO", "KANTO"),
      current = 4,
      total = 4,
      detail = tr(
        "All primal traces\nare synchronized.",
        "Alle Urspuren sind\nsynchronisiert."),
    }
  end

  function H.atlasLocations()
    return {
      [H.MAP_ID] = tr("DRIFTGLASS POST", "DRIFTGLAS-POSTEN"),
    }
  end

  function H.setWorldEvents(value)
    worldEvents = value
    return H
  end

  function H.install(game)
    H.game = game or H.game
    if type(state.install) == "function" then state.install(H.game) end
    return content.install(H.game, {
      canTravel = function()
        return earlyState().questStarted == true
      end,
      onResearcher = function(researchGame, ow, npc, onDone)
        return H.onResearcher(researchGame, ow, npc, onDone)
      end,
    })
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
      local out = nextItems(game, items)
      if type(out) ~= "table" then return out end
      local row = {
        label = tr("WORLD", "WELT"),
        ascendantMenu = true,
        ascendantLabel = tr("WORLD", "WELT"),
        ascendantOrder = 20,
        ascendantKey = H.ASCENDANT_KEY,
        onSelect = function() H.openWorld(game) end,
      }
      if mod.ui and type(mod.ui.insertBefore) == "function" then
        return mod.ui.insertBefore(out, tr("SAVE", "SICHERN"), row)
      end
      out[#out + 1] = row
      return out
    end, 275)
  end

  return H
end
