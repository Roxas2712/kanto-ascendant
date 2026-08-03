-- Visual smoke test for Kanto Ascendant 5.0.2. Everything is changed only in
-- the driver's in-memory save and the process exits without writing a slot.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/kanto-ascendant-endgame-qa"
  local Screens = require("src.ui.Screens")
  local Pokemon = require("src.pokemon.Pokemon")
  local Pipelines = require("src.render.Pipelines")

  U.wait(20)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.trainer_rematch, "Kanto Ascendant export missing")
  assert(api.dexProgress and api.johtoMasters and api.worldEvents
      and api.fieldTech and api.ascendantMenu and api.kantoCompletion
      and api.researchAtlas and api.frontierExchange and api.grandTour
      and api.legacyHall,
    "5.0.2 controllers missing")

  local function encounterHas(mapId, species)
    local enc = game.data.encounters[mapId]
    for _, slot in ipairs(enc and enc.grass and enc.grass.slots or {}) do
      if slot.species == species then return true end
    end
    return false
  end
  assert(encounterHas("ROUTE_5", "MEOWTH")
      and encounterHas("ROUTE_5", "BELLSPROUT"),
    "KANTO 151 Route 5 version-independent encounters missing")
  assert(encounterHas("SAFARI_ZONE_CENTER", "SCYTHER")
      and encounterHas("SAFARI_ZONE_CENTER", "PINSIR"),
    "KANTO 151 Safari version-independent encounters missing")
  assert(not encounterHas("POKEMON_MANSION_B1F", "MEW"),
    "Mew must remain exclusive to the authored event")
  assert(game.data.pokemon.KADABRA.evolutions[1].species == "ALAKAZAM",
    "trade-free Kadabra evolution missing")

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.hallOfFame = { {} }
  game.save.pokedex = { seen = {}, owned = {} }

  -- Johto discovery page: two known species, one caught, every other name
  -- still hidden exactly like the original Pokédex.
  game.save.pokedex.seen.CHIKORITA = true
  game.save.pokedex.seen.CYNDAQUIL = true
  game.save.pokedex.owned.CHIKORITA = true
  Screens.push(game, "JohtoResearchDex")
  U.wait(45)
  assert(U.shot(game, DIR .. "/johto_dex_discovery.png"))
  U.tap(game, "b")
  U.wait(20)

  -- Only the first 150 are owned, so only that earned certificate is exposed;
  -- the existence of the 151/250/251 tiers remains secret.
  for id, def in pairs(game.data.pokemon) do
    if def.dex and def.dex <= 150 then
      game.save.pokedex.seen[id] = true
      game.save.pokedex.owned[id] = true
    end
  end
  Screens.push(game, "AscendantCertificates")
  U.wait(45)
  assert(U.shot(game, DIR .. "/dex_certificates_150.png"))
  U.tap(game, "b")
  U.wait(20)

  -- All expansion utilities are collected behind one Start-menu row. The
  -- vanilla menu stays short while the dedicated screen retains every
  -- feature's own progression gate.
  api.megaEvolution.unlock(game)
  Screens.push(game, "StartMenu")
  U.wait(45)
  local startMenu = game.stack:top()
  local ascendantIndex, ascendantCount, saveIndex = nil, 0, nil
  local oldTopLevel = {
    JOURNAL = true, WELT = true, WORLD = true, JOHTO = true, SHINY = true,
    EVENTS = true, ZERT = true, ["CERT."] = true, MEGA = true,
  }
  for index, item in ipairs(startMenu.items or {}) do
    if item.label == "ASCENDANT" then
      ascendantIndex, ascendantCount = index, ascendantCount + 1
    end
    if item.label == "SAVE" or item.label == "SICHERN" then saveIndex = index end
    assert(not oldTopLevel[item.label],
      "legacy Ascendant row leaked into the Start menu: " .. item.label)
  end
  assert(ascendantCount == 1, "Start menu needs exactly one ASCENDANT row")
  assert(saveIndex and ascendantIndex == saveIndex - 1,
    "ASCENDANT must sit immediately before the localized SAVE row")
  assert(U.shot(game, DIR .. "/start_menu_clean.png"))
  startMenu.index = ascendantIndex
  U.tap(game, "a")
  U.wait(45)
  local ascendantScreen = game.stack:top()
  assert(ascendantScreen.title == "KANTO ASCENDANT")
  local utility = {}
  for _, item in ipairs(ascendantScreen.items or {}) do
    utility[item.label] = item
  end
  local function row(en, de)
    return utility[en] or utility[de]
  end
  assert(row("RESEARCH ATLAS", "FORSCHUNGSATLAS")
      and row("JOURNAL", "JOURNAL")
      and row("WORLD STATUS", "WELT-STATUS")
      and row("SHINY DEX", "SHINY-DEX")
      and row("EVENT ARCHIVE", "EVENT-ARCHIV")
      and row("DEX CERTIFICATES", "DEX-ZERTIFIKATE")
      and row("MEGA STONES", "MEGA-STEINE")
      and row("TITLES / TROPHIES", "TITEL / TROPHÄEN"),
    "5.0 Ascendant utilities are incomplete")
  assert(U.shot(game, DIR .. "/ascendant_submenu.png"))

  ascendantScreen.index = (function()
    for index, item in ipairs(ascendantScreen.items) do
      if item.label == "RESEARCH ATLAS"
          or item.label == "FORSCHUNGSATLAS" then return index end
    end
  end)()
  U.tap(game, "a")
  U.wait(45)
  assert(game.stack:top().title == "RESEARCH ATLAS"
      or game.stack:top().title == "FORSCHUNGSATLAS")
  assert(U.shot(game, DIR .. "/research_atlas.png"))

  -- A recorded starter exposes only its own researched habitat. Open the
  -- detail page as a visual proof that the Atlas labels the building and
  -- its pool/species percentages as base chances.
  local researchState = api.johtoResearch.state()
  researchState.starters.cyndaquil = true
  local atlasScreen = game.stack:top()
  for index, item in ipairs(atlasScreen.items or {}) do
    if item.value == "habitats" then atlasScreen.index = index break end
  end
  U.tap(game, "a")
  U.wait(45)
  local habitatScreen = game.stack:top()
  for index, item in ipairs(habitatScreen.items or {}) do
    if item.value == "CYNDAQUIL" then habitatScreen.index = index break end
  end
  U.tap(game, "a")
  U.wait(120)
  U.tap(game, "a")
  U.wait(180)
  assert(U.shot(game, DIR .. "/research_atlas_cyndaquil_location.png"))
  U.tap(game, "a")
  U.wait(90)
  assert(U.shot(game, DIR .. "/research_atlas_cyndaquil_terrain.png"))
  U.tap(game, "a")
  U.wait(180)
  assert(U.shot(game, DIR .. "/research_atlas_cyndaquil_habitat.png"))
  U.tap(game, "b")
  U.wait(20)
  U.tap(game, "b")
  U.wait(20)
  U.tap(game, "b")
  U.wait(20)

  ascendantScreen = game.stack:top()
  ascendantScreen.index = (function()
    for index, item in ipairs(ascendantScreen.items) do
      if item.label == "TITLES / TROPHIES"
          or item.label == "TITEL / TROPHÄEN" then return index end
    end
  end)()
  U.tap(game, "a")
  U.wait(45)
  assert(game.stack:top().title == "TITLES / TROPHIES"
      or game.stack:top().title == "TITEL / TROPHÄEN")
  assert(U.shot(game, DIR .. "/legacy_gallery_menu.png"))
  U.tap(game, "b")
  U.wait(20)
  U.tap(game, "b")
  U.wait(20)

  -- The first Gold clear decorates the ordinary Trainer Card.
  local mastersState = api.johtoMasters.state()
  mastersState.title = true
  local ascendantState = api.ascendant.state()
  ascendantState.achievements = ascendantState.achievements or {}
  ascendantState.achievements.ascendant = true
  assert(api.legacyHall.selectTitle("ascendant"),
    "visual QA could not select the earned KANTO ASCENDANT title")
  Screens.push(game, "TrainerCard")
  U.wait(45)
  assert(U.shot(game, DIR .. "/kanto_ascendant_title_card.png"))
  U.tap(game, "b")
  U.wait(20)

  -- Direct visual smoke of a Battle Factory rental and authored opponent in
  -- the voxel renderer.
  local draft = api.grandTour.draftCandidates(game, 1)
  local rentals = api.grandTour.buildRentalTeam(
    game, { draft[1], draft[2], draft[3] })
  assert(#rentals == 3, "Factory could not build three visual-QA rentals")
  game.save.party = rentals
  Pipelines.setLevel("voxel", 1)
  Pipelines.syncOptions(game.save.options)
  U.teleport(game, "INDIGO_PLATEAU_LOBBY", 5, 5, "down")
  local foe = api.grandTour.factoryBracket(1)[1]
  local battle = api.postgame.newForcedBattle(game, foe.class,
    foe.team, "battle_factory")
  battle.ascendantNoItems = true
  battle.enemyAIMods = { 1, 2, 3 }
  battle.trainer = setmetatable(
    { name = foe.name.en }, { __index = battle.trainer })
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)
  U.wait(180)
  for _ = 1, 24 do U.tap(game, "a"); U.wait(12) end
  U.wait(120)
  assert(U.shot(game, DIR .. "/battle_factory_voxel.png"))
end
