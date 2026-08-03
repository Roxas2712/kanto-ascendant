-- One-time 5.0 orientation for every Hall-of-Fame save, including saves that
-- already reached the post-game before installing this version.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local postgame = assert(opts.postgame, "postgame controller missing")
  local O = { game = nil }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function state(create)
    local s = mod.save:get("onboarding")
    if type(s) ~= "table" and create ~= false then
      s = { version = 1, shown = false }
      mod.save:set("onboarding", s)
    end
    if type(s) == "table" then
      s.version = 1
      s.shown = s.shown == true
    end
    return s
  end

  local function text()
    return tr(
      "OAK: Good timing!\fKanto's post-game has\ngrown. Open ASCENDANT\nfrom the START menu.",
      "EICH: Gutes Timing!\fKantos Postgame ist\ngewachsen. Öffne\nASCENDANT im START-Menü.")
      .. "\f" .. tr(
        "JOURNAL and ATLAS now\nname your next goal,\nlocation and progress.",
        "JOURNAL und ATLAS\nzeigen nächstes Ziel,\nOrt und Fortschritt.")
      .. "\f" .. tr(
        "ROUTE 5 now houses the\nDay-Care, evolution\nmachine and Move tools.",
        "Auf ROUTE 5 stehen nun\nPension, Entwicklungs-\nmaschine und Attacken-\nWerkzeuge.")
      .. "\f" .. tr(
        "PROF. ELM's aide waits\nin my LAB. His research\nopens Johto habitats.",
        "PROF. LINDS Assistent\nwartet in meinem LABOR.\fSeine Forschung öffnet\nJohto-Lebensräume.")
      .. "\f" .. tr(
        "After the CROWN, visit\nINDIGO's Factory and\nJohto Masters, the S.S.\nANNE at VERMILION and\nthe CELADON Gallery.",
        "Nach der KRONE warten\nFabrik und Johto-Meister\nam INDIGO, die M.S. ANNE\nin ORANIA und die Galerie\nin PRISMANIA.")
      .. "\f" .. tr(
        "GOLD is the final main\nbattle. Factory and ship\nclears are optional\nprestige challenges.",
        "GOLD ist der letzte\nHauptkampf. Fabrik und\nSchiff sind optionale\nPrestige-Prüfungen.")
  end

  local function shouldShow(game)
    local s = state()
    return not s.shown and game ~= nil
      and postgame.hasHallOfFame(game.save)
  end

  local function show(game)
    local s = state()
    if not shouldShow(game) or not game.stack then return false end
    s.shown = true
    mod.save:set("onboarding", s)
    game.stack:push(require("src.render.TextBox").new(game, text()))
    return true
  end

  mod.events:on("map.entered", function(ev)
    show(ev and ev.game or O.game)
  end, -2000)

  mod.events:on("save.loaded", function()
    state()
  end)

  function O.install(game)
    O.game = game
    state()
  end

  O.state = state
  O.text = text
  O.shouldShow = shouldShow
  O.show = show
  return O
end
