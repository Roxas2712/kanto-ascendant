-- In-engine QA for Kanto Ascendant 4.1 field tools and TM systems.
-- The driver mutates only its temporary in-memory save.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/kanto-ascendant-field-tech-qa"

  U.wait(20)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Kanto Ascendant export missing")
  local tech = assert(api.fieldTech, "field-tech controller missing")
  local Pokemon = require("src.pokemon.Pokemon")
  local expectedFamilies = {
    FRENZY_PLANT = {
      "BULBASAUR", "IVYSAUR", "VENUSAUR",
      "CHIKORITA", "BAYLEEF", "MEGANIUM",
      "TREECKO", "GROVYLE", "SCEPTILE",
    },
    BLAST_BURN = {
      "CHARMANDER", "CHARMELEON", "CHARIZARD",
      "CYNDAQUIL", "QUILAVA", "TYPHLOSION",
      "TORCHIC", "COMBUSKEN", "BLAZIKEN",
    },
    HYDRO_CANNON = {
      "SQUIRTLE", "WARTORTLE", "BLASTOISE",
      "TOTODILE", "CROCONAW", "FERALIGATR",
      "MUDKIP", "MARSHTOMP", "SWAMPERT",
    },
  }
  local status = tech.starterFamilyStatus()
  assert(status.activeProvider and status.generations == 3
      and status.totalStages == 27,
    "registered Hoenn provider did not expose exact 27-stage compatibility")

  -- Every registered starter move, TM and compatibility row must survive the
  -- complete mod merge, including the 100 newly registered Johto species.
  for moveId, family in pairs(tech.starterFamilies) do
    local expected = assert(expectedFamilies[moveId], moveId .. " unexpected")
    assert(#family == 9 and status.cardinality[moveId] == 9,
      moveId .. " does not expose exactly nine registered stages")
    local move = assert(game.data.moves[moveId], moveId .. " move missing")
    assert(move.power == 150 and move.accuracy == 90 and move.pp == 5,
      moveId .. " battle data mismatch")
    for index, species in ipairs(family) do
      assert(species == expected[index],
        moveId .. " stage order mismatch at " .. index)
      local def = assert(game.data.pokemon[species], species .. " missing")
      local canLearn = false
      for _, id in ipairs(def.tmhm or {}) do
        if id == moveId then canLearn = true break end
      end
      assert(canLearn, species .. " cannot learn " .. moveId)
    end
  end
  assert(game.data.items.TM_FRENZY_PLANT.machine.number == 51)
  assert(game.data.items.TM_BLAST_BURN.machine.number == 52)
  assert(game.data.items.TM_HYDRO_CANNON.machine.number == 53)

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.hallOfFame = { {} }
  game.save.inventory = {}
  game.save.bagOrder = {}
  local mon = Pokemon.new(game.data, "CHARIZARD", 60,
    function() return 8 end)
  mon.moves = {
    { id = "CUT", pp = 30 },
    { id = "FLY", pp = 15 },
    { id = "FLAMETHROWER", pp = 15 },
    { id = "SLASH", pp = 20 },
  }
  game.save.party = { mon }

  local s = tech.state()
  s.kit = false
  s.rematchWins, s.tmWins, s.tmCursor = 0, 0, 0
  s.pendingTM, s.pendingTMs, s.archivedTMs =
    nil, {}, {}
  s.signatureUnlocked, s.signatureAwarded = {}, {}
  local kitText = assert(tech.afterRematch(game),
    "first rematch did not award Field Kit")
  assert(kitText:find("FELD%-KIT") or kitText:find("FIELD KIT"),
    "Field Kit reward text missing")
  assert(game.save.inventory.FIELD_KIT == 1 and tech.state().kit,
    "Field Kit did not enter the Bag")

  for id in pairs({
    HM_CUT = true, HM_FLY = true, HM_SURF = true,
    HM_STRENGTH = true, HM_FLASH = true,
    CASCADEBADGE = true, THUNDERBADGE = true, SOULBADGE = true,
    RAINBOWBADGE = true, BOULDERBADGE = true,
  }) do
    require("src.inventory.Bag").add(game.save, id, 1, game.data)
  end
  U.teleport(game, "PALLET_TOWN", 5, 6, "down")
  U.wait(30)
  for _, moveId in ipairs({ "CUT", "FLY", "SURF", "STRENGTH", "FLASH" }) do
    assert(tech.available(game.save, moveId),
      moveId .. " Field Kit module remained unavailable")
  end
  assert(game.overworld:partyKnows("SURF").nickname,
    "Field Kit did not supply a non-party SURF user")
  local visibleRows = tech.fieldRows(game)
  local visible = {}
  for _, row in ipairs(visibleRows) do visible[row.value] = true end
  assert(visible.CUT and visible.FLY and visible.SURF and visible.STRENGTH,
    "Field Kit menu omitted an available outdoor HM")

  require("src.ui.Screens").push(game, "BagMenu", {})
  U.wait(30)
  assert(game.stack:top().items[1].value == "FIELD_KIT",
    "Field Kit was not retained as the first Bag reward")
  U.tap(game, "a")
  U.wait(60)
  assert(U.shot(game, DIR .. "/field_kit_menu.png"))
  U.tap(game, "b")
  U.wait(20)

  -- The Day-Care machine calls this same UI; verify that an HM appears and
  -- can actually be deleted while the final-move safety remains intact.
  tech.forgetMenu(game)
  U.wait(25)
  U.tap(game, "a")
  U.wait(40)
  assert(U.shot(game, DIR .. "/move_deleter_hm.png"))
  local before = #mon.moves
  U.tap(game, "a")
  U.wait(20)
  for _ = 1, 4 do
    if #mon.moves < before then break end
    U.tap(game, "a")
    U.wait(24)
  end
  assert(#mon.moves == before - 1 and mon.moves[1].id == "FLY",
    "Move Deleter did not remove the selected HM")
  U.tap(game, "b")
  U.wait(20)

  -- The base archive is complete and deterministic; signature TMs join it
  -- only after their thematically matching Crown Leader awards them.
  local basePool = tech.renewableTMs(game)
  local baseNumbers = {}
  for _, row in ipairs(basePool) do baseNumbers[row.number] = true end
  for number = 1, 50 do
    assert(baseNumbers[number], ("TM%02d missing from archive"):format(number))
  end
  assert(tech.afterBossWin(game, "erika", "crown"))
  assert(tech.afterBossWin(game, "blaine", "crown"))
  assert(tech.afterBossWin(game, "misty", "crown"))
  assert(game.save.inventory.TM_FRENZY_PLANT == 1)
  assert(game.save.inventory.TM_BLAST_BURN == 1)
  assert(game.save.inventory.TM_HYDRO_CANNON == 1)
  assert(#tech.renewableTMs(game) == #basePool + 3,
    "earned signature TMs did not join the renewable archive")

  local useResult, taughtMove = require("src.inventory.ItemEffects").use(
    game.data, game.save, "TM_BLAST_BURN", mon, nil)
  assert(useResult == "learn" and taughtMove == "BLAST_BURN",
    "TM52 could not teach Blast Burn to Charizard")

  local nextArchiveTM = tech.renewableTMs(game)[1].id
  local archiveText = assert(tech.afterRematch(game),
    "second post-Hall-of-Fame rematch did not award an archive TM")
  assert(archiveText:find("TM", 1, true)
      and game.save.inventory[nextArchiveTM] == 1,
    "renewable archive did not deliver its first guaranteed TM")
end
