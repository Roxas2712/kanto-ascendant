-- One readable gateway for Kanto Ascendant's Start-menu utilities.
--
-- Feature modules still own unlocks and callbacks. This collector preserves
-- their stable order, groups them into plain-language hubs, keeps contributed
-- help, and promotes Voxel Ascendant as an optional root entry without
-- changing VASC's independently owned menu tree.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local ascendantUi = opts.ascendantUi
  local supportLog = opts.supportLog
  local A = {}

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local GROUPS = {
    {
      key = "quests", label = function() return tr(
        "QUESTS + WORLD", "AUFGABEN + WELT") end,
      help = function() return tr(
        "Current quests, story progress and changes in Kanto and Johto.",
        "Aktuelle Aufgaben, Spielfortschritt und Veränderungen in Kanto und Johto.") end,
    },
    {
      key = "research", label = function() return tr(
        "DEX + RESEARCH", "DEX + FORSCHUNG") end,
      help = function() return tr(
        "Research, Pokedex progress, habitats and earned certificates.",
        "Forschung, Pokédex-Fortschritt, Fundorte und erhaltene Zertifikate.") end,
    },
    {
      key = "partners", label = function() return tr(
        "PARTNERS + FORMS", "PARTNER + FORMEN") end,
      help = function() return tr(
        "Partner quests, Mega Stones, relics and special Pokemon forms.",
        "Partneraufgaben, Mega-Steine, Relikte und besondere Pokémon-Formen.") end,
    },
    {
      key = "events", label = function() return tr(
        "EVENTS + TITLES", "EVENTS + TITEL") end,
      help = function() return tr(
        "Event Archive, Frontier rewards, titles and trophies.",
        "Event-Archiv, Frontier-Belohnungen, Titel und Trophäen.") end,
    },
  }

  local GROUP_BY_KEY = {
    ["order:10"] = "quests", ["order:20"] = "quests",
    johto_signals_world = "quests",
    ["order:5"] = "research", ["order:30"] = "research",
    ["order:40"] = "research", ["order:60"] = "research",
    yellow_partner = "partners", gorochu_quest = "partners",
    ["order:70"] = "partners", ["order:72"] = "partners",
    starter_relics = "partners", ascendant_typhlosion = "partners",
    ["order:50"] = "events", ["order:75"] = "events",
    ["order:80"] = "events",
  }

  local function state()
    local s = mod.save:get("ascendant_menu")
    if type(s) ~= "table" then
      s = { version = 1, initialized = false, known = {}, fresh = {} }
      mod.save:set("ascendant_menu", s)
    end
    s.version = 1
    s.initialized = s.initialized == true
    s.known = type(s.known) == "table" and s.known or {}
    s.fresh = type(s.fresh) == "table" and s.fresh or {}
    return s
  end

  local function itemKey(item)
    return tostring(item.ascendantKey
      or ("order:" .. tostring(tonumber(item.ascendantOrder) or 999)))
  end

  local function defaultHelp(key)
    local help = {
      options = { "Configure Kanto Ascendant without changing save compatibility.",
        "Kanto Ascendant verständlich einstellen, ohne die Spielstand-Kompatibilität zu ändern." },
      ["order:5"] = { "Open the Research Atlas with progress, rewards and known habitats.",
        "Öffnet den Forschungsatlas mit Fortschritt, Belohnungen und bekannten Fundorten." },
      ["order:10"] = { "Review current quests and the most important story progress.",
        "Zeigt aktuelle Aufgaben und den wichtigsten Spielfortschritt." },
      yellow_partner = { "Review the Thunderheart partner quest and its current state.",
        "Zeigt die Donnerherz-Partneraufgabe und ihren aktuellen Stand." },
      gorochu_quest = { "Open Gorochu research and its discoveries.",
        "Öffnet die Gorochu-Forschung und ihre Entdeckungen." },
      ["order:20"] = { "Review active world events and changes.",
        "Zeigt aktive Weltereignisse und Veränderungen." },
      johto_signals_world = { "Review active world events, signals and unlocked paths.",
        "Zeigt Weltereignisse, Signale und freigeschaltete Wege." },
      ["order:30"] = { "Review National Pokedex research and Johto discoveries.",
        "Zeigt Nationaldex-Forschung und Entdeckungen aus Johto." },
      ["order:40"] = { "Review discovered and caught Shiny Pokemon.",
        "Zeigt entdeckte und gefangene Shiny-Pokémon." },
      ["order:50"] = { "Open past and currently available special events.",
        "Öffnet vergangene und aktuell verfügbare Spezial-Events." },
      ["order:60"] = { "Review Pokedex milestones and earned certificates.",
        "Zeigt Pokédex-Meilensteine und erhaltene Zertifikate." },
      ["order:70"] = { "Review found Mega Stones and their compatible Pokemon.",
        "Zeigt gefundene Mega-Steine und die dazu passenden Pokémon." },
      ["order:72"] = { "Review starter relic quests and their progress.",
        "Zeigt Starter-Reliktaufgaben und ihren Fortschritt." },
      starter_relics = { "Review starter relic quests and their progress.",
        "Zeigt Starter-Reliktaufgaben und ihren Fortschritt." },
      ascendant_typhlosion = { "Review the Ascendant Typhlosion form and its unlock.",
        "Zeigt die Ascendant-Tornupto-Form und ihre Freischaltung." },
      ["order:75"] = { "Exchange Frontier Points for unlocked rewards.",
        "Tauscht Frontier-Punkte gegen freigeschaltete Belohnungen." },
      ["order:80"] = { "Review unlocked titles, trophies and achievements.",
        "Zeigt freigeschaltete Titel, Trophäen und Erfolge." },
      voxel_ascendant = { "Open Voxel Ascendant's complete menu in its original order.",
        "Öffnet Voxel Ascendants vollständiges Menü in seiner bisherigen Reihenfolge." },
      support_log = { "Send a bounded support report, including available HD download errors, to the configured maintainer server after confirmation.",
        "Sendet nach Bestätigung einen begrenzten Supportbericht inklusive verfügbarer HD-Download-Fehler an den eingerichteten Entwickler-Server." },
    }
    local entry = help[key]
    return entry and tr(entry[1], entry[2]) or tr(
      "Open this unlocked Kanto Ascendant feature.",
      "Öffnet diese freigeschaltete Kanto-Ascendant-Funktion.")
  end

  local function collect(items)
    local startItems, ascendantItems = {}, {}
    for index, item in ipairs(items or {}) do
      if type(item) == "table" and item.ascendantMenu then
        local key = itemKey(item)
        ascendantItems[#ascendantItems + 1] = {
          label = item.ascendantLabel or item.label,
          right = item.right,
          help = item.ascendantHelp or item.help or defaultHelp(key),
          onSelect = item.onSelect,
          order = tonumber(item.ascendantOrder) or 999,
          sourceIndex = index,
          ascendantKey = key,
          ascendantGroup = item.ascendantGroup or GROUP_BY_KEY[key],
          ascendantFresh = item.ascendantFresh == true,
        }
      else
        startItems[#startItems + 1] = item
      end
    end
    local hasOptions = false
    for _, item in ipairs(ascendantItems) do
      if item.ascendantKey == "options" then hasOptions = true break end
    end
    if mod.exports.ascendantFeaturesScreen and not hasOptions then
      ascendantItems[#ascendantItems + 1] = {
        label = tr("SETTINGS", "EINSTELLUNGEN"),
        help = defaultHelp("options"),
        onSelect = function()
          mod.ui.push(mod.world.game, mod.exports.ascendantFeaturesScreen)
        end,
        order = 1, sourceIndex = #items + 1, ascendantKey = "options",
      }
    end
    table.sort(ascendantItems, function(a, b)
      if a.order == b.order then return a.sourceIndex < b.sourceIndex end
      return a.order < b.order
    end)

    local s, anyNew = state(), false
    for _, item in ipairs(ascendantItems) do
      local key = item.ascendantKey
      if s.initialized and not s.known[key] then s.fresh[key] = true end
      s.known[key] = true
      item.fresh = s.fresh[key] == true or item.ascendantFresh
      if item.fresh then
        item.right = tr("NEW", "NEU")
        anyNew = true
      end
    end
    s.initialized = true
    mod.save:set("ascendant_menu", s)
    return startItems, ascendantItems, anyNew
  end

  local function markRead(item)
    if not (item and item.ascendantKey) then return end
    local s = state()
    if s.fresh[item.ascendantKey] then
      s.fresh[item.ascendantKey] = nil
      mod.save:set("ascendant_menu", s)
    end
  end

  local function openHelp(game, item)
    local ui = mod.exports and mod.exports.ascendantUi
    if item and item.help and ui and type(ui.showHelp) == "function" then
      return ui.showHelp(game, item.label, item.help)
    end
    return false
  end

  local function menu(game, title, rows, root)
    local Menu = mod.ui.KantoListMenu or mod.ui.ListMenu
    return Menu.new(game, title, rows, {
      pageJump = true, rows = 5,
      footer = tr("A:OPEN SEL:HELP", "A:AUF SEL:HILFE"),
      ascendantFocusHelp = function(item) return item and item.help end,
      onCancel = root and function() mod.ui.push(game, "StartMenu") end or nil,
      onSelectKey = function(item) openHelp(game, item) end,
      onChoose = function(item)
        if not item then return end
        if item.children then
          return A.openCategory(game, item.label, item.children)
        end
        markRead(item)
        if item.onSelect then return item.onSelect() end
      end,
    })
  end

  function A.buildRoot(rows)
    local grouped = { quests = {}, research = {}, partners = {}, events = {} }
    local settings, vasc
    for _, item in ipairs(rows or {}) do
      if item.ascendantKey == "options" then
        settings = item
      elseif item.ascendantKey == "voxel_ascendant" then
        vasc = item
      else
        local key = item.ascendantGroup or "events"
        local bucket = grouped[key] or grouped.events
        bucket[#bucket + 1] = item
      end
    end
    local root = {}
    for _, def in ipairs(GROUPS) do
      local children = grouped[def.key]
      if #children > 0 then
        local fresh = false
        for _, child in ipairs(children) do
          if child.fresh then fresh = true break end
        end
        root[#root + 1] = {
          label = def.label(), help = def.help(), children = children,
          right = fresh and tr("NEW", "NEU") or nil,
          ascendantKey = "group:" .. def.key,
        }
      end
    end
    if settings then
      settings.label = tr("SETTINGS", "EINSTELLUNGEN")
      settings.help = settings.help or defaultHelp("options")
      root[#root + 1] = settings
    end
    if supportLog and type(supportLog.open) == "function" then
      root[#root + 1] = {
        label=tr("SUPPORT LOG", "FEHLERPROTOKOLL"),
        help=defaultHelp("support_log"),
        ascendantKey="support_log",
        onSelect=function()
          return supportLog.open(mod.world.game, tr)
        end,
      }
    end
    if vasc then
      vasc.help = vasc.help or defaultHelp("voxel_ascendant")
      root[#root + 1] = vasc
    end
    return root
  end

  function A.openCategory(game, title, rows)
    game.stack:push(menu(game, title, rows, false))
  end

  function A.open(game, rows)
    local root = A.buildRoot(rows)
    -- KASC-66-BILINGUAL-HELP-PRESENTATION owns only this optional adapter.
    -- The established 6.6 groups and the ordinary ListMenu path remain the
    -- exact fail-open behavior when the shared guided API is unavailable.
    if ascendantUi and type(ascendantUi.pushGuidedList) == "function" then
      return ascendantUi.pushGuidedList(game, {
        key = "ascendant_root",
        title = "KANTO ASCENDANT",
        helpTitle = tr("ASCENDANT HELP", "ASCENDANT-HILFE"),
        help = tr(
          "This hub groups Ascendant features. Press A to open one, SELECT on a feature for its explanation, or HELP to repeat this guide.",
          "Diese Zentrale bündelt Ascendant-Funktionen. A öffnet, SELECT erklärt einen Eintrag und HILFE wiederholt diese Einführung."),
        rows = root,
        footer = tr("A:OPEN SEL:HELP", "A:AUF SEL:HILFE"),
        options = {
          pageJump = true,
          ascendantFocusHelp = function(item) return item and item.help end,
          onCancel = function() mod.ui.push(game, "StartMenu") end,
        },
        onChoose = function(item)
          if not item then return end
          if item.children then
            return A.openCategory(game, item.label, item.children)
          end
          markRead(item)
          if item.onSelect then return item.onSelect() end
        end,
      })
    end
    game.stack:push(menu(game, "KANTO ASCENDANT", root, true))
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" then return out end
    local startItems, ascendantItems, anyNew = collect(out)
    if #ascendantItems == 0 then return startItems end
    return mod.ui.insertBefore(startItems, tr("SAVE", "SICHERN"), {
      label = "ASCENDANT",
      right = anyNew and tr("NEW", "NEU") or nil,
      onSelect = function() A.open(game, ascendantItems) end,
    })
  end, 1000)

  A.collect = collect
  A.state = state
  A.defaultHelp = defaultHelp
  A.title = function() return tr("KANTO ASCENDANT", "KANTO ASCENDANT") end
  return A
end
