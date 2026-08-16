-- Real screen-stack capture for the #252-279 P1 surface acceptance.
--
-- Unlike extended_species_runtime_qa_driver.lua this deliberately captures
-- the native PartyMenu, modern Box grid, SummaryMenu and DexEntryMenu.  It
-- does not inspect or compose raw walker sheets.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Boxes = require("src.pokemon.Boxes")
  local Screens = require("src.ui.Screens")
  local output = assert(os.getenv("EXTENDED_UI_DIR"), "EXTENDED_UI_DIR required")
  os.execute('mkdir -p "' .. output .. '"')
  local limit = tonumber(os.getenv("EXTENDED_UI_LIMIT"))
  local requested = os.getenv("EXTENDED_UI_SPECIES")
  local boxDetailsOnly = os.getenv("EXTENDED_UI_BOX_DETAILS_ONLY") == "1"

  U.wait(35)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant export missing")
  local runtime = assert(api.extendedSpeciesRuntime, "extended runtime missing")
  local shiny = assert(api.shinySystem, "shiny runtime missing")
  assert(api.modernStorageUi,
    "modern storage hook was not installed before the UI capture driver")

  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions.kanto_ascendant = game.mods.modOptions.kanto_ascendant or {}
  local options = game.mods.modOptions.kanto_ascendant
  options.pokemon_sprite_style = "crystal"
  options.dex_sprite_style = "crystal"
  options.sprite_style_box = true
  options.modern_storage_ui = true
  options.party_icon_style = "animated"
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = options

  local order = {}
  if requested and requested ~= "" then
    for species in requested:gmatch("[^,%s]+") do
      species = species:upper()
      assert(runtime.bySpecies[species], "not an extended-runtime species: " .. species)
      order[#order + 1] = species
    end
  else
    for _, species in ipairs(runtime.order) do
      order[#order + 1] = species
      if limit and #order >= limit then break end
    end
  end
  assert(#order > 0, "no extended species")
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen, game.save.pokedex.owned =
    game.save.pokedex.seen or {}, game.save.pokedex.owned or {}
  for _, species in ipairs(order) do
    game.save.pokedex.seen[species], game.save.pokedex.owned[species] = true, true
  end

  local function clear()
    while game.stack:top() do game.stack:pop() end
  end
  local function mon(species, isShiny)
    local value = Pokemon.new(game.data, species, 30, function() return 8 end)
    if isShiny then
      assert(shiny.forceMon(value, game.data.pokemon[species]),
        "could not force shiny " .. species)
      assert(shiny.isShiny(value), "shiny not retained " .. species)
    end
    return value
  end
  local captures, manifest = 0, {}
  local function shot(group, name)
    local path = output .. "/" .. group .. "/" .. name .. ".png"
    assert(U.shot(game, path), "capture failed " .. path)
    captures = captures + 1
    manifest[#manifest + 1] = { group = group, name = name, path = path }
  end

  if not boxDetailsOnly then
    -- Actual six-slot party pages, five pages for the 28-species set per
    -- variant.  These exercise PartyMenu.drawIcon rather than raw 16x96 data.
    for _, isShiny in ipairs({ false, true }) do
      local variant = isShiny and "shiny" or "normal"
      for start = 1, #order, 6 do
        game.save.party = {}
        local names = {}
        for index = start, math.min(start + 5, #order) do
          game.save.party[#game.save.party + 1] = mon(order[index], isShiny)
          names[#names + 1] = order[index]:lower()
        end
        clear()
        Screens.push(game, "PartyMenu")
        U.wait(8)
        shot("party", variant .. "_" .. table.concat(names, "-"))
      end
    end

    -- Native status and Pokédex screens: every entry is shown through its
    -- actual screen constructor/draw pass, not just the Sprites.path seam.
    for _, isShiny in ipairs({ false, true }) do
      local variant = isShiny and "shiny" or "normal"
      for _, species in ipairs(order) do
        clear()
        Screens.push(game, "SummaryMenu", mon(species, isShiny))
        U.wait(8)
        shot("summary", variant .. "_" .. species:lower())
      end
    end
    for _, species in ipairs(order) do
      clear()
      Screens.push(game, "DexEntryMenu", species)
      U.wait(8)
      local dex = assert(game.stack:top(), "DexEntryMenu did not open")
      local pages = assert(dex.pages, "DexEntryMenu exposes no paginated text")
      for page = 1, #pages do
        assert(dex.page == page, "Dex page did not advance " .. species)
        shot("dex", species:lower() .. "_page" .. page)
        if page < #pages then
          U.tap(game, "a")
          U.wait(4)
        end
      end
    end
  end

  -- BoxMenu's modern storage implementation turns the real WITHDRAW list
  -- into a 5x4 sprite grid.  Two capacities cover all 28 entries; repeat
  -- for shiny mons so box-specific art selection is observable too.
  for _, isShiny in ipairs({ false, true }) do
    local variant = isShiny and "shiny" or "normal"
    for page, start in ipairs({ 1, 21 }) do
      if start <= #order then
        local pageMons = {}
        for index = start, math.min(start + 19, #order) do
          pageMons[#pageMons + 1] = mon(order[index], isShiny)
        end
        -- Begin with a fresh SaveData-compatible box store, then put every
        -- mon through the same public deposit API used by the game.  Do not
        -- seed `boxes[1]` directly: that would only test a table shape.
        game.save.boxes, game.save.currentBox = nil, nil
        Boxes.ensure(game.save)
        for _, value in ipairs(pageMons) do
          assert(Boxes.deposit(game.save, value) == 1,
            "public deposit did not select the active first box")
        end
        assert(#Boxes.active(game.save) == #pageMons and #pageMons > 0,
          "prepared Box contents are not active")
        -- WITHDRAW is intentionally blocked for a six-mon party.  Leave one
        -- valid party mon through the public Pokémon constructor so this test
        -- reaches the actual Box list/grid rather than its full-party dialog.
        game.save.party = { mon("BULBASAUR", false) }
        clear()
        Screens.push(game, "BoxMenu")
        U.wait(4)
        U.tap(game, "a") -- WITHDRAW -> the modern sprite grid ListMenu
        U.wait(8)
        local screen = game.stack:top()
        assert(screen and screen.__ascendantBoxGrid,
          "real modern Box grid was not opened")
        if not boxDetailsOnly then shot("box", variant .. "_page" .. page) end
        -- The grid is a real ListMenu with a modern draw hook.  Step its
        -- public cursor through every occupied cell so each selected detail
        -- panel (especially long species names) is scene evidence too.
        for orderIndex = start, start + #pageMons - 1 do
          local species = order[orderIndex]
          local expected = orderIndex - start + 1
          assert(screen.index == expected, "Box cursor did not reach cell " .. expected)
          shot("box", variant .. "_page" .. page .. "_" .. species:lower())
          if expected < #pageMons then
            -- The productive grid uses five columns: right advances within a
            -- row; from its fifth cell, down enters the next row's fifth
            -- (or final) occupied cell.  These six-mon evidence pages thus
            -- traverse cells 1..6 without bypassing the selected detail UI.
            U.hold(game, expected % 5 == 0 and "down" or "right", 1)
            U.wait(4)
          end
        end
      end
    end
  end

  local report = assert(io.open(output .. "/"
    .. (boxDetailsOnly and "ui_box_detail_capture_manifest.json" or "ui_capture_manifest.json"), "wb"))
  report:write(runtime.encodeJson({
    status = "partial", evidence = "native-screen-stack", species = order,
    captureCount = captures, captures = manifest,
    notes = {
      boxDetailsOnly and "Only real BoxMenu selected-cell detail panels were captured."
        or "PartyMenu, SummaryMenu, DexEntryMenu and BoxMenu are captured through Screens.push.",
      "The Box screenshot is taken only after the real WITHDRAW action opens the modern grid.",
      "This batch is evidence only; global acceptance is decided by the aggregate manifest.",
    },
  }))
  report:close()

  print(("EXTENDED SPECIES UI CAPTURE PASS: %d species, %d real UI screenshots")
    :format(#order, captures))
  love.event.quit(0)
end
