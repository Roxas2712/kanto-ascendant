-- Installed-package acceptance for the one HEVO-15 surface which was not
-- covered by the existing full-path and non-map drivers: one connected,
-- durable 15-package grant followed by the three physical field altars.
--
-- The three dungeon results are deliberately staged at their real atomic
-- reward boundary.  The existing RED/BLUE/GREEN input drivers own navigation
-- and puzzle completion; this driver owns their combined archive result.  It
-- never writes package/evolution flags and never calls a package grant or
-- field-evolution helper directly.  Every grant goes through
-- legacyDungeonAdapter.finalize, and every field evolution starts with an A
-- press on the installed map object and continues through PartyMenu and the
-- engine's EvolutionState.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing HEVO-15 proof outside the immutable package gate")
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")
  local TextBox = require("src.render.TextBox")
  local RuntimeMap = require("src.world.Map")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")

  assert(identity == "ka-hevo15-grants-altars-package",
    "refusing a non-isolated HEVO-15 identity")
  assert(GameVersion.get() == "red", "HEVO-15 package driver requires Red")

  local api = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export is missing")
  local packages = assert(api.hevoPackages, "HEVO package runtime is missing")
  local adapter = assert(api.legacyDungeonAdapter,
    "HEVO dungeon reward boundary is missing")
  local journey = assert(api.legacyJourney, "Legacy Journey export is missing")

  local checks, receipt = 0, {}
  local function check(label, value, detail)
    if not value then
      error("FAIL: " .. label .. (detail and (" (" .. detail .. ")") or ""), 2)
    end
    checks = checks + 1
    receipt[#receipt + 1] = "PASS\t" .. label
    U.log("PASS", label, detail or "")
    return value
  end

  local function countTruthy(values)
    local count = 0
    for _, value in pairs(values or {}) do
      if value == true or (type(value) == "number" and value > 0) then
        count = count + 1
      end
    end
    return count
  end

  local function waitFor(predicate, frames)
    for _ = 1, frames or 1500 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end

  local function clearUi()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  local function settleText(box)
    return waitFor(function()
      return game.stack:top() == box and (box.waiting or box.done) and box or nil
    end, 900)
  end

  local function dismissText(box)
    for _ = 1, 120 do
      if game.stack:top() ~= box then return true end
      if box.waiting or box.done then U.tap(game, "a") else U.wait(1) end
    end
    return game.stack:top() ~= box
  end

  local function bucket()
    game.save.modData = type(game.save.modData) == "table"
      and game.save.modData or {}
    game.save.modData.kanto_ascendant =
      type(game.save.modData.kanto_ascendant) == "table"
        and game.save.modData.kanto_ascendant or {}
    return game.save.modData.kanto_ascendant
  end

  local function selectCharacter(character)
    local state = bucket()
    state.extended_characters = type(state.extended_characters) == "table"
      and state.extended_characters or {}
    state.extended_characters.enabled = true
    state.extended_characters.player_character = character
    check(character .. " is the active reward authority",
      journey.activeCharacter(game.save) == character)
  end

  local function persistentCounts()
    local state = packages.persistent(game.save, false) or {}
    return countTruthy(state.packageUnlocks),
      countTruthy(state.evolutionUnlocks), countTruthy(state.firstGrants), state
  end

  U.wait(20)
  if not game.overworld then U.newGame(game) end
  check("fresh disposable identity reached the overworld", game.overworld ~= nil)
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.inventory, game.save.bagOrder = {}, {}
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}

  local beforePackages = persistentCounts()
  check("fresh identity begins without HEVO package grants", beforePackages == 0)
  check("installed registry exposes exactly 15 packages and 17 targets",
    #packages.order == 15 and packages.audit.registeredTargets == 17)

  -- Prove the production boundary rejects a forged subset before accepting
  -- any staged dungeon result.
  selectCharacter("RED")
  local forged, forgedWhy = adapter.finalize(game, {
    character = "RED", packageUnlocks = { "protector" },
  })
  check("dungeon reward boundary rejects caller-provided package subsets",
    forged == false and forgedWhy == "result-packages-forbidden")
  check("forged subset attempt leaves the grant ledger empty",
    persistentCounts() == 0)

  local expectedTargets = { RED = 5, BLUE = 5, GREEN = 7 }
  local cumulativePackages = { RED = 5, BLUE = 10, GREEN = 15 }
  local cumulativeTargets = { RED = 5, BLUE = 10, GREEN = 17 }
  local previous
  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    selectCharacter(character)
    if previous then
      local cross, crossWhy = adapter.finalize(game, { character = previous })
      check(character .. " rejects the previous character's staged result",
        cross == false and crossWhy == "character")
      check(character .. " cross-character rejection changes no package count",
        persistentCounts() == cumulativePackages[previous])
    end
    local ok, result = adapter.finalize(game, {
      character = character,
      questionIds = { "HEVO15_PACKAGE_ACCEPTANCE_" .. character },
      rivalWitness = true,
    })
    check(character .. " uses the real atomic dungeon reward boundary", ok)
    check(character .. " grants exactly five character-bound packages",
      type(result) == "table" and #result.packages == 5)
    check(character .. " reports its exact authored target count",
      result.targetCount == expectedTargets[character])
    local packageCount, targetCount = persistentCounts()
    check(character .. " cumulative package count is exact",
      packageCount == cumulativePackages[character])
    check(character .. " cumulative target count is exact",
      targetCount == cumulativeTargets[character])
    previous = character
  end

  local packageCount, targetCount, firstGrantCount, persistent = persistentCounts()
  check("connected staged results produce exactly fifteen durable packages",
    packageCount == 15)
  check("connected staged results produce exactly seventeen durable targets",
    targetCount == 17)
  check("all eight consumable first grants are recorded exactly once",
    firstGrantCount == 8)
  check("an empty staged Bag receives every direct first-grant item once",
    game.save.inventory.PROTECTOR == 1
      and game.save.inventory.MAGMARIZER == 1
      and game.save.inventory.RAZOR_FANG == 1
      and game.save.inventory.ELECTIRIZER == 1
      and game.save.inventory.RAZOR_CLAW == 1
      and game.save.inventory.DUBIOUS_DISC == 1
      and game.save.inventory.SHINY_STONE == 1
      and game.save.inventory.DUSK_STONE == 1
      and next(persistent.pendingItems or {}) == nil)

  check("combined 15-package ledger writes through the real save boundary",
    game:writeSave())
  local loaded = assert(SaveData.load(), "combined HEVO-15 save did not reload")
  game:restoreSave(loaded, false)
  U.wait(40)
  packageCount, targetCount, firstGrantCount = persistentCounts()
  check("reload retains exactly 15 packages, 17 targets and 8 first grants",
    packageCount == 15 and targetCount == 17 and firstGrantCount == 8)

  clearUi()
  Screens.push(game, "BagMenu", {})
  U.wait(8)
  check("combined first-grant Bag capture",
    U.shot(game, dir .. "/00_all_15_grants_after_reload.png"))
  clearUi()

  local altarCases = {
    {
      character = "BLUE", package = "magnetic_field",
      object = "KA_HEVO_ALTAR_MAGNETIC_FIELD",
      map = "KA_HEVO_BLUE_KYOGRE_SHRINE",
      parent = "MAGNETON", target = "MAGNEZONE", stem = "magnetic",
    },
    {
      character = "BLUE", package = "ice_field",
      object = "KA_HEVO_ALTAR_ICE_FIELD",
      map = "KA_HEVO_BLUE_KYOGRE_SHRINE",
      parent = "EEVEE", target = "GLACEON", stem = "ice",
    },
    {
      character = "GREEN", package = "moss_field",
      object = "KA_HEVO_ALTAR_MOSS_FIELD",
      map = "KA_HEVO_GREEN_RAYQUAZA_SHRINE",
      parent = "EEVEE", target = "LEAFEON", stem = "moss",
    },
  }

  local facing = {
    ["1:0"] = "right", ["-1:0"] = "left",
    ["0:1"] = "down", ["0:-1"] = "up",
  }
  local adjacent = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

  local function approach(row)
    local def = assert(game.data.maps[row.map], "missing altar map " .. row.map)
    local object
    for _, candidate in ipairs(def.objects or {}) do
      if candidate.name == row.object then object = candidate break end
    end
    check(row.object .. " exists once in the installed map", object ~= nil)
    check(row.object .. " is visibly distinct from quiz relics",
      object.sprite == "SPRITE_POKE_BALL")
    local runtime = RuntimeMap.new(def, assert(game.data.tilesets[def.tileset]))
    local stand
    for _, delta in ipairs(adjacent) do
      local x, y = object.x + delta[1], object.y + delta[2]
      if runtime:inBounds(x, y) and runtime:isWalkableCell(x, y)
          and not runtime:warpAtCell(x, y) then
        stand = { x = x, y = y,
          face = facing[(object.x - x) .. ":" .. (object.y - y)] }
        break
      end
    end
    check(row.object .. " has a walkable physical approach", stand ~= nil)
    U.teleport(game, row.map, stand.x, stand.y, stand.face)
    U.wait(30)
    local npc
    for _, candidate in ipairs(game.overworld and game.overworld.npcs or {}) do
      if candidate.def and candidate.def.name == row.object then npc = candidate break end
    end
    check(row.object .. " spawned as the real talk object", npc ~= nil)
    check(row.object .. " remains one faced cell from the player",
      math.abs(game.overworld.player.cellX - npc.cellX)
        + math.abs(game.overworld.player.cellY - npc.cellY) == 1
        and game.overworld.player.facing == stand.face)
    return npc
  end

  local evolved = {}
  for index, row in ipairs(altarCases) do
    selectCharacter(row.character)
    local mon = Pokemon.new(game.data, row.parent, 70)
    mon.moves = { { id = "TACKLE", pp = game.data.moves.TACKLE.pp } }
    game.save.party = { mon }
    approach(row)
    check(row.object .. " physical pre-interaction capture",
      U.shot(game, dir .. ("/%02d_%s_altar.png"):format(index, row.stem)))
    local x, y = game.overworld.player.cellX, game.overworld.player.cellY
    U.tap(game, "a")
    check(row.object .. " A press does not move the player",
      game.overworld.player.cellX == x and game.overworld.player.cellY == y)
    local picker = assert(waitFor(function()
      local top = game.stack:top()
      return top and top.screenId == "PartyMenu" and top or nil
    end, 600), row.object .. " did not open the real PartyMenu")
    check(row.package .. " package is still unlocked at the physical altar",
      packages.unlocked(game.save, row.package))
    U.tap(game, "a")
    local evolution = assert(waitFor(function()
      for _, state in ipairs(game.stack.states or {}) do
        if state.mon == mon and state.newSpecies == row.target then return state end
      end
    end, 900), row.object .. " did not reach EvolutionState")
    check(row.object .. " uses its registered package evolution method",
      evolution.via == packages.byId[row.package].method)
    check(row.object .. " uses the selected real party member", picker ~= nil)
    local congrats = assert(waitFor(function()
      local top = game.stack:top()
      return mon.species == row.target and getmetatable(top) == TextBox
        and top or nil
    end, 1800), row.target .. " evolution did not finish")
    settleText(congrats)
    check(row.parent .. " evolves physically into " .. row.target,
      mon.species == row.target)
    check(row.target .. " evolved-surface capture",
      U.shot(game, dir .. ("/%02d_%s_evolved.png"):format(index, row.stem)))
    dismissText(congrats)
    clearUi()
    evolved[#evolved + 1] = mon
  end

  game.save.party = evolved
  check("three physical altar results write through the real save boundary",
    game:writeSave())
  loaded = assert(SaveData.load(), "physical altar result save did not reload")
  game:restoreSave(loaded, false)
  U.wait(40)
  local seen = {}
  for _, mon in ipairs(game.save.party or {}) do seen[mon.species] = true end
  check("reload retains all three physical field evolutions",
    #game.save.party == 3 and seen.MAGNEZONE and seen.GLACEON and seen.LEAFEON)
  check("altar evolutions consume no package first-grant item",
    game.save.inventory.PROTECTOR == 1
      and game.save.inventory.ELECTIRIZER == 1
      and game.save.inventory.SHINY_STONE == 1)
  packageCount, targetCount, firstGrantCount = persistentCounts()
  check("altar use cannot mutate the 15/17/8 grant ledger",
    packageCount == 15 and targetCount == 17 and firstGrantCount == 8)

  local out = assert(io.open(dir .. "/hevo15_grants_altars_receipt.txt", "wb"))
  out:write("HEVO-15 GRANTS + FIELD ALTARS PASS\n")
  out:write("progression_setup=STAGED_TRIAL_FINALIZATION_BOUNDARIES\n")
  out:write("grant_boundary=REAL_LEGACY_DUNGEON_ADAPTER_FINALIZE\n")
  out:write("manual_package_flag_writes=false\n")
  out:write("packages=15/15 targets=17/17 first_grants=8/8\n")
  out:write("grant_reload=15/17/8\n")
  out:write("physical_altars=3/3\n")
  out:write("altar_input=A_PRESS+PARTY_MENU+EVOLUTION_STATE\n")
  out:write("altar_methods=KA_HEVO_MAGNETIC_FIELD,KA_HEVO_ICE_FIELD,KA_HEVO_MOSS_FIELD\n")
  out:write("altar_results=MAGNEZONE,GLACEON,LEAFEON\n")
  out:write("altar_reload=3/3\n")
  out:write("checks=", tostring(checks), "\n")
  for _, line in ipairs(receipt) do out:write(line, "\n") end
  out:close()
  print("HEVO-15 GRANTS + FIELD ALTARS PASS: " .. checks .. " checks")
  love.event.quit(0)
end
