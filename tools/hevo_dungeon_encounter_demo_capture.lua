-- Deterministic visual proof for the trial-bound cycle-1 Level-70 habitats.
--
-- This driver does not manufacture a Pokemon, package, seal or campaign
-- reward in the save.  It selects one already-published encounter-table row
-- and asks the bundled Visible Wilds runtime to create its normal overworld
-- entity, then starts the ordinary contact-battle script from that record.
-- The deterministic selection avoids an unbounded wait for a particular
-- random visible spawn while retaining the real renderer and battle paths.
--
-- Required environment:
--   KA_HEVO_MOD=/absolute/path/to/Authority-worktree
--   HEVO_ENCOUNTER_DEMO_CHARACTER=RED|BLUE|GREEN
--   POKEPORT_IDENTITY=<isolated identity containing hevo-encounter-demo>
--   SHOT_DIR=/persistent/per-character/evidence/path
return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local GBCFX = require("src.render.GBCFX")
  local Pipelines = require("src.render.Pipelines")
  local SaveData = require("src.core.SaveData")
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing HEVO encounter proof outside the immutable package gate")
  local harness = assert(os.getenv("GEN1RECOMP_DIR"),
    "GEN1RECOMP_DIR package harness required")
  local character = assert(os.getenv("HEVO_ENCOUNTER_DEMO_CHARACTER"),
    "HEVO_ENCOUNTER_DEMO_CHARACTER required"):upper()
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY required")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local renderer = os.getenv("HEVO_ENCOUNTER_RENDERER") == "voxel"
    and "voxel" or "2d"
  local voxelReceipt, voxelSerial = nil, 0
  assert(identity:find("hevo%-encounter%-demo"),
    "refusing non-isolated HEVO encounter demo identity")
  assert(identity:lower():find(character:lower(), 1, true),
    "isolated identity must name the active demo character")

  local manifest = assert(loadfile(harness
    .. "/tools/hevo_dungeon_encounter_demo_manifest.lua"))()
  local demo = assert(manifest[character],
    "demo character must be RED, BLUE or GREEN")
  assert(manifest.GBCFX == 0, "demo manifest must require GBCFX OFF")
  assert(manifest.BASE_CYCLE == 1 and manifest.BASE_LEVEL == 70
      and manifest.LEVEL_STEP == 5 and manifest.MAX_LEVEL == 100,
    "demo manifest has stale Legacy-cycle scaling")
  local requestedCycle = math.max(1, math.floor(tonumber(
    os.getenv("HEVO_ENCOUNTER_DEMO_CYCLE")) or demo.cycle))
  local expectedLevel = math.min(manifest.MAX_LEVEL,
    manifest.BASE_LEVEL + manifest.LEVEL_STEP * (requestedCycle - 1))
  assert(demo.cycle == manifest.BASE_CYCLE
      and demo.expectedLevel == manifest.BASE_LEVEL,
    "visual demo manifest must retain the accepted Level-70 baseline")

  local exactParents = {
    RED = { "RHYDON", "MAGMAR", "LICKITUNG", "PILOSWINE", "GLIGAR" },
    BLUE = { "MAGNETON", "ELECTABUZZ", "EEVEE", "SNEASEL", "PORYGON2" },
    GREEN = {
      "EEVEE", "TANGELA", "YANMA", "TOGETIC", "AIPOM",
      "MISDREAVUS", "MURKROW",
    },
  }
  local representative = {
    RED = "RHYDON", BLUE = "MAGNETON", GREEN = "TOGETIC",
  }
  local hoennStarterLines = {
    "TREECKO", "GROVYLE", "SCEPTILE",
    "TORCHIC", "COMBUSKEN", "BLAZIKEN",
    "MUDKIP", "MARSHTOMP", "SWAMPERT",
  }
  local sharedMaps = {
    "KA_HEVO_TUNNEL_ALL", "KA_HEVO_SHARED_SEALED_ANTECHAMBER",
  }

  local function setOf(list)
    local out = {}
    for _, value in ipairs(list or {}) do out[value] = true end
    return out
  end
  local function countSet(set)
    local count = 0
    for _ in pairs(set or {}) do count = count + 1 end
    return count
  end
  local function sortedKeys(set)
    local out = {}
    for value in pairs(set or {}) do out[#out + 1] = value end
    table.sort(out)
    return out
  end
  local function csv(list)
    return table.concat(list or {}, ",")
  end
  local function containsSavedSpecies(value, wanted, seen)
    if type(value) ~= "table" then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    if type(value.species) == "string" and wanted[value.species] then
      return true, value.species
    end
    for _, child in pairs(value) do
      if type(child) == "table" then
        local found, species = containsSavedSpecies(child, wanted, seen)
        if found then return true, species end
      end
    end
    return false
  end
  local function countArray(value)
    local count = 0
    for _ in pairs(type(value) == "table" and value or {}) do
      count = count + 1
    end
    return count
  end

  -- POKEPORT_DRIVER intentionally boots at the title rather than silently
  -- choosing CONTINUE.  Exercise the same load/restore pair used by the title
  -- callback so this process consumes the builder's active isolated slot.
  local loaded, recovered = SaveData.load()
  assert(loaded, "isolated HEVO encounter demo slot did not load")
  game:restoreSave(loaded, recovered)

  local level = Pipelines.setLevel("voxel", renderer == "voxel" and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  assert(renderer == "voxel" and level > 0
      or renderer == "2d" and level == 0,
    "requested HEVO renderer did not activate")
  if renderer == "voxel" then
    assert(Pipelines.worldPipeline() == "voxel",
      "FULL Voxel pipeline is not live")
    local present = Pipelines.worldPresent
    Pipelines.worldPresent = function(canvas, ctx)
      local out = present(canvas, ctx)
      local mapId = ctx and ctx.state and ctx.state.map and ctx.state.map.id
      if out and mapId then
        voxelSerial = voxelSerial + 1
        voxelReceipt = { serial=voxelSerial, mapId=mapId, canvas=out }
      end
      return out
    end
  end

  -- Let the authored first-floor overworld and Visible Wilds publish their
  -- ordinary runtime state before replacing the random representative with
  -- one deterministic, still-authorized row.
  U.wait(180)
  local exports = assert(game.mods and game.mods.exports, "mod exports missing")
  local ascendant = assert(exports.kanto_ascendant,
    "Kanto Ascendant must be loaded")
  local campaign = assert(ascendant.hiddenEvolutionCampaign,
    "Hidden Evolution campaign missing")
  local encounters = assert(campaign.encounters,
    "HEVO encounter controller missing")
  local packages = assert(ascendant.hevoPackages,
    "HEVO package registry missing")
  local characters = assert(ascendant.extendedCharacters,
    "extended-character runtime missing")
  local wilds = assert(exports.overworld_wild_spawns,
    "bundled Visible Wilds runtime missing")
  assert(wilds.version == "1.12.2", "Visible Wilds 1.12.2 required")
  local logic = assert(wilds.logic, "Visible Wilds logic missing")
  local SpawnFx = assert(wilds.lib and wilds.lib.require
      and wilds.lib.require("spawn_fx"),
    "Visible Wilds spawn FX module missing")

  local save = assert(game.save, "active demo save missing")
  local bucket = assert(save.modData and save.modData.kanto_ascendant,
    "Ascendant save state missing")
  local fixture = assert(bucket.hevo_encounter_demo,
    "HEVO encounter demo fixture missing")
  -- Accepted pre-scaling fixtures predate the explicit cycle field.  They
  -- were original-run Level-70 saves, so migrate that missing metadata to
  -- the documented baseline without changing product progression state.
  local fixtureCycle = math.max(1,
    math.floor(tonumber(fixture.cycle) or manifest.BASE_CYCLE))
  assert(fixture.character == character and fixture.map == demo.map
      and fixtureCycle == requestedCycle and fixture.level == expectedLevel,
    "loaded HEVO fixture does not match requested character/map/level")
  assert(encounters.levelFor(save, game) == expectedLevel,
    "runtime cycle source changed the baseline demo level")
  -- Package reconciliation creates the normalized persistent container on a
  -- normal load.  Its existence is not a grant; every grant-bearing set must
  -- remain empty for this entry-only fixture.
  local persistent = bucket.hevo_persistent
  if persistent then
    for _, key in ipairs({
        "packageUnlocks", "evolutionUnlocks", "permanentItems",
        "firstGrants", "secretUnlocks", "pendingItems",
      }) do
      assert(next(persistent[key] or {}) == nil,
        "demo manufactured HEVO progress in " .. key)
    end
  end
  assert(save.flags
      and save.flags[encounters.ENTERED_FLAG_PREFIX .. character] == true,
    "real matching fissure-entry flag missing")
  assert(characters.getPlayerCharacter() == character,
    "extended-character authority differs from requested trial")

  GBCFX.setLevel(manifest.GBCFX)
  assert(save.options and save.options.gbcfx == 0,
    "active demo save did not retain GBCFX OFF")
  assert(GBCFX.level == 0 and not GBCFX.active(),
    "runtime GBCFX must remain OFF")

  local overworld = assert(game.overworld, "overworld missing")
  local player = assert(overworld.player, "overworld player missing")
  assert(overworld.map and overworld.map.id == demo.map,
    "demo did not load the first trial floor")
  assert(save.player and save.player.map == demo.map,
    "save position is not on the first trial floor")
  -- The saved start was asserted above.  During the deliberate 180-frame
  -- natural-spawn observation an aggressive wild may legitimately approach
  -- or engage the player; that is not a corrupt fixture position.
  assert(player.ascendantCharacter == character,
    "visible field actor does not carry the requested character identity")
  local captureCell = { x=demo.start.x, y=demo.start.y }

  local synced, changed = encounters.sync(game)
  assert(synced and changed == 14,
    "real encounter controller did not publish all fourteen trial maps")
  local expected = setOf(exactParents[character])
  local rows = encounters.rows(save, character, game)
  local rowSet = {}
  for _, row in ipairs(rows) do
    assert(not rowSet[row.species], "duplicate registry parent " .. row.species)
    rowSet[row.species] = true
  end
  assert(countSet(rowSet) == #exactParents[character],
    "registry parent count differs from the acceptance set")
  for _, species in ipairs(exactParents[character]) do
    assert(rowSet[species], character .. " registry parent missing " .. species)
  end
  for species in pairs(rowSet) do
    assert(expected[species], character .. " published unexpected parent " .. species)
  end

  local allParents, finalEvolutions = {}, {}
  for _, package in ipairs(packages.order or {}) do
    for _, target in ipairs(package.targets or {}) do
      allParents[target.parent] = true
      finalEvolutions[target.target] = true
    end
    if package.item then
      assert(not (save.inventory and save.inventory[package.item]),
        "demo directly owns HEVO package item " .. package.item)
    end
  end
  local foreignOnly = {}
  for species in pairs(allParents) do
    if not expected[species] then foreignOnly[species] = true end
  end
  local hoenn = setOf(hoennStarterLines)

  for trialCharacter, maps in pairs(encounters.MAPS) do
    for _, mapId in ipairs(maps) do
      local grass = assert(game.data.encounters[mapId]
          and game.data.encounters[mapId].grass,
        mapId .. " real encounter table missing")
      if trialCharacter == character then
        assert(grass.rate == encounters.RATE[character],
          mapId .. " active habitat rate changed")
        assert(#grass.slots == encounters.SLOT_COUNT,
          mapId .. " active habitat must publish ten slots")
        for _, slot in ipairs(grass.slots) do
          assert(slot.level == expectedLevel,
            mapId .. " published a wrong cycle-scaled level")
          assert(expected[slot.species],
            mapId .. " published a wrong-character parent " .. slot.species)
          assert(not finalEvolutions[slot.species],
            mapId .. " published final evolution " .. slot.species)
          assert(not hoenn[slot.species],
            mapId .. " published Hoenn starter-line species " .. slot.species)
        end
      else
        assert(grass.rate == 0 and #grass.slots == 0,
          character .. " admission opened foreign trial map " .. mapId)
      end
    end
  end
  for _, mapId in ipairs(sharedMaps) do
    assert(encounters.mapCharacter[mapId] == nil,
      "shared map acquired a color-specific habitat owner")
    local entry = game.data.encounters[mapId]
    assert(not entry or entry.kaEncounterSource ~= encounters.SOURCE,
      "shared map acquired a HEVO dungeon encounter source")
  end

  local chosen = representative[character]
  assert(expected[chosen], "representative is not in the active parent set")
  assert(encounters.allowed(save, demo.map,
      { species=chosen, level=expectedLevel }, game),
    "real controller rejected the selected legitimate parent")
  assert(not encounters.allowed(save, demo.map,
      { species=chosen, level=expectedLevel - 1 }, game),
    "real controller accepted the wrong level")
  for species in pairs(foreignOnly) do
    assert(not encounters.allowed(save, demo.map,
        { species=species, level=expectedLevel }, game),
      "real controller accepted foreign parent " .. species)
  end
  for species in pairs(finalEvolutions) do
    assert(not encounters.allowed(save, demo.map,
        { species=species, level=expectedLevel }, game),
      "real controller accepted final evolution " .. species)
  end
  for _, species in ipairs(hoennStarterLines) do
    assert(not encounters.allowed(save, demo.map,
        { species=species, level=expectedLevel }, game),
      "real controller accepted Hoenn starter-line species " .. species)
  end
  for _, mapId in ipairs(sharedMaps) do
    assert(not encounters.allowed(save, mapId,
        { species=chosen, level=expectedLevel }, game),
      "real controller accepted an encounter on shared map " .. mapId)
  end

  local partyCount = countArray(save.party)
  local boxesCount = countArray(save.boxes)
  local inParty, partySpecies = containsSavedSpecies(save.party, expected)
  local inBoxes, boxSpecies = containsSavedSpecies(save.boxes, expected)
  assert(not inParty, "demo directly owns parent in party: " .. tostring(partySpecies))
  assert(not inBoxes, "demo directly owns parent in boxes: " .. tostring(boxSpecies))
  for species in pairs(expected) do
    assert(not (save.pokedex and save.pokedex.owned
        and save.pokedex.owned[species]),
      "demo directly owns parent in Pokedex: " .. species)
  end

  local ready = false
  for _ = 1, 600 do
    if logic.state and logic.state.initialized
        and logic.activeMapId == demo.map then
      ready = true
      break
    end
    U.wait(1)
  end
  assert(ready, "Visible Wilds did not initialize the first trial floor")

  -- Release acceptance mode: consume an entity from the initial map-enter
  -- wave before this driver clears the map or calls trySpawn.  This closes
  -- the distinction between "the table can spawn when QA asks" and "the
  -- player naturally sees and can battle a Pokemon in the trial".
  if os.getenv("HEVO_ENCOUNTER_NATURAL_ONLY") == "1" then
    local naturalRecord, naturalEntity
    for _ = 1, 600 do
      for _, id in ipairs(logic.byMap[demo.map] or {}) do
        local record = logic.spawns[id]
        local entity = logic.entities[id]
        if record and entity and record.testSpawn ~= true
            and record.caveScenery ~= true
            and record.visibleSprite ~= false
            and encounters.allowed(save, demo.map, record, game) then
          naturalRecord, naturalEntity = record, entity
          break
        end
      end
      if naturalRecord then break end
      U.wait(1)
    end
    assert(naturalRecord and naturalEntity,
      "initial map-enter wave produced no reachable natural HEVO encounter")
    local visibleCount=logic:countVisibleOnMap(demo.map)
    assert(visibleCount>=1 and visibleCount<=3,
      "HEVO initial wave ignored the three-visible-Pokemon corridor cap: "
        ..tostring(visibleCount))
    assert(naturalRecord.level == expectedLevel
        and expected[naturalRecord.species],
      "natural encounter escaped the active color/level contract")
    assert(naturalEntity.sprite and naturalEntity.sprite.def
        and naturalEntity.sprite.def.image,
      "natural encounter has no real sprite definition")
    assert(not naturalEntity.usingFallback,
      "natural encounter used the black/fallback renderer")

    for _ = 1, 240 do
      if naturalEntity.hiddenBody ~= true
          and naturalEntity.canTriggerBattle ~= false then break end
      U.wait(1)
    end
    assert(naturalEntity.hiddenBody ~= true
        and naturalEntity.canTriggerBattle ~= false,
      "natural encounter did not finish its spawn presentation")

    local registration = assert(wilds.render
        and wilds.render.registrationInfo
        and wilds.render.registrationInfo[naturalRecord.species],
      "natural encounter has no renderer registration")
    assert(registration.kind == "native_runtime_sheet"
        and registration.walker == true
        and registration.status ~= "FALLBACK_REGISTERED",
      "natural encounter did not use a real six-frame runtime sheet")

    local lower = character:lower()
    local speciesLower = naturalRecord.species:lower()
    local visiblePath = shotDir .. "/01_" .. lower
      .. "_natural_" .. speciesLower .. "_lv" .. expectedLevel .. "_visible.png"
    local battlePath = shotDir .. "/02_" .. lower
      .. "_natural_" .. speciesLower .. "_lv" .. expectedLevel .. "_contact_battle.png"
    local beforeReceipt = voxelReceipt and voxelReceipt.serial or 0
    if renderer == "voxel" then
      for _=1,600 do
        if voxelReceipt and voxelReceipt.serial > beforeReceipt
            and voxelReceipt.mapId == demo.map then break end
        U.wait(1)
      end
      assert(voxelReceipt and voxelReceipt.serial > beforeReceipt
          and voxelReceipt.mapId == demo.map and voxelReceipt.canvas,
        "natural FULL field proof has no fresh Voxel world receipt")
    end
    assert(U.shot(game, visiblePath),
      "could not capture natural visible encounter")
    assert(logic:_startBattle(naturalRecord),
      "natural Visible Wilds contact battle did not queue")
    local battle
    for _ = 1, 600 do
      local top = game.stack:top()
      if top and top.phase then battle = top end
      if battle and battle.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(3)
    end
    assert(battle and battle.phase == "menu",
      "natural contact battle did not reach the command menu")
    assert(battle.enemy and battle.enemy.mon
        and battle.enemy.mon.species == naturalRecord.species
        and battle.enemy.mon.level == expectedLevel,
      "natural contact battle changed species or exact level")
    U.wait(60)
    assert(U.shot(game, battlePath),
      "could not capture natural contact battle")

    local proof = assert(io.open(shotDir .. "/runtime_assertions.txt", "wb"))
    proof:write("HEVO NATURAL DUNGEON ENCOUNTER PASS\n")
    proof:write("character=", character, "\n")
    proof:write("map=", demo.map, "\n")
    proof:write("origin=automatic_initial_map_enter_wave\n")
    proof:write("driver_trySpawn_calls_before_receipt=0\n")
    proof:write("species=", naturalRecord.species, "\n")
    proof:write("journey_cycle=", requestedCycle, "\n")
    proof:write("level=", naturalRecord.level, "\n")
    proof:write("cell=", naturalRecord.x, ",", naturalRecord.y, "\n")
    proof:write("visible_count=", visibleCount, "/3\n")
    proof:write("renderer=", renderer, "\n")
    if renderer == "voxel" then
      proof:write("world_pipeline=voxel\n")
      proof:write("world_receipt=fresh,", voxelReceipt.mapId, "\n")
    end
    proof:write("visible_spawn=reachable,no_fallback,six_frame_sheet\n")
    proof:write("contact_battle=real_start_battle_script,command_menu\n")
    proof:write("screenshots=", visiblePath:match("[^/]+$"), ",",
      battlePath:match("[^/]+$"), "\n")
    proof:close()
    print(("HEVO %s NATURAL PASS: %s Lv%d on %s")
      :format(character, naturalRecord.species, naturalRecord.level, demo.map))
    love.event.quit(0)
    return
  end

  logic:_clearMap(demo.map)
  U.wait(10)

  local spawnIndex = 1
  if character == "GREEN" then
    -- GREEN's return warp begins immediately underneath the threshold's
    -- authored foreground arch.  Walk nine real d-pad cells along the
    -- manifest's already collision-audited route so both Green and the
    -- representative are unobscured in the visual receipt.
    local function physicalStep(target)
      local p = game.overworld.player
      local dx, dy = target[1] - p.cellX, target[2] - p.cellY
      assert(math.abs(dx) + math.abs(dy) == 1,
        "GREEN visual route ceased to be contiguous")
      local direction = dx == 1 and "right" or dx == -1 and "left"
        or dy == 1 and "down" or "up"
      for _ = 1, 180 do
        if game.stack:top() == game.overworld
            and not p.inputLocked and not p.moving then break end
        U.wait(1)
      end
      assert(game.stack:top() == game.overworld
          and not p.inputLocked and not p.moving,
        "GREEN route input layer did not settle")
      game.input.state[direction] = true
      local began = false
      for _ = 1, 180 do
        coroutine.yield()
        if p.moving then began = true break end
      end
      game.input.state[direction] = false
      assert(began, "GREEN physical route step did not begin")
      for _ = 1, 180 do
        if p.cellX == target[1] and p.cellY == target[2]
            and not p.moving then break end
        U.wait(1)
      end
      assert(p.cellX == target[1] and p.cellY == target[2]
          and not p.moving,
        "GREEN physical route step did not reach its target")
    end
    for index = 1, 9 do physicalStep(assert(demo.routeCells[index])) end
    captureCell = {
      x=demo.routeCells[9][1], y=demo.routeCells[9][2],
    }
    spawnIndex = 10
    logic:_clearMap(demo.map)
    U.wait(10)
  end

  local spawnCell = assert(demo.routeCells[spawnIndex],
    "demo route has no spawn cell")
  local record, spawnErr, entity = logic:trySpawn(game, {
    force = true,
    x = spawnCell[1], y = spawnCell[2],
    species = chosen, level = expectedLevel,
    behavior = "IDLE_LOOK",
  })
  assert(record and entity,
    chosen .. " deterministic real-runtime spawn failed: " .. tostring(spawnErr))
  assert(record.mapId == demo.map and record.species == chosen
      and record.level == expectedLevel,
    "Visible Wilds changed the selected encounter identity")
  assert(encounters.allowed(save, demo.map, record, game),
    "spawned record is not allowed by the real HEVO controller")
  assert(entity.sprite and entity.sprite.def and entity.sprite.def.image,
    "visible parent has no real sprite definition")
  assert(not entity.usingFallback,
    "visible parent used the black/fallback renderer")
  local registration = assert(wilds.render and wilds.render.registrationInfo
      and wilds.render.registrationInfo[chosen],
    "visible parent has no renderer registration")
  assert(registration.kind == "native_runtime_sheet"
      and registration.walker == true
      and registration.status ~= "FALLBACK_REGISTERED",
    "visible parent did not use a real six-frame runtime sheet")

  SpawnFx.updateEntity(entity, 1, { map=overworld.map })
  assert(logic:_attach(entity),
    "visible parent could not attach after its spawn presentation")
  U.wait(75)
  assert(entity.canTriggerBattle ~= false and entity.hiddenBody ~= true,
    "visible parent did not finish its normal spawn presentation")
  assert(player.cellX == captureCell.x and player.cellY == captureCell.y,
    "deterministic spawn moved the player")
  assert(countArray(save.party) == partyCount
      and countArray(save.boxes) == boxesCount,
    "visible spawn directly changed party or box storage")
  inParty, partySpecies = containsSavedSpecies(save.party, expected)
  inBoxes, boxSpecies = containsSavedSpecies(save.boxes, expected)
  assert(not inParty and not inBoxes,
    "visible spawn directly granted an encounter parent: "
      .. tostring(partySpecies or boxSpecies))
  assert(GBCFX.level == 0 and not GBCFX.active(),
    "GBCFX changed before the overworld proof")

  local lower = character:lower()
  local speciesLower = chosen:lower()
  local visiblePath = shotDir .. "/01_" .. lower
    .. "_first_trial_floor_" .. speciesLower .. "_lv" .. expectedLevel .. "_visible.png"
  local battlePath = shotDir .. "/02_" .. lower .. "_"
    .. speciesLower .. "_lv" .. expectedLevel .. "_contact_battle.png"
  assert(U.shot(game, visiblePath), "could not capture visible parent proof")

  assert(logic:_startBattle(record),
    "Visible Wilds contact battle did not queue")
  local battle
  for _ = 1, 600 do
    local top = game.stack:top()
    if top and top.phase then battle = top end
    if battle and battle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(3)
  end
  assert(battle and battle.phase == "menu",
    "contact battle did not reach the command menu")
  assert(battle.enemy and battle.enemy.mon
      and battle.enemy.mon.species == chosen
      and battle.enemy.mon.level == expectedLevel,
    "contact battle changed the parent species or exact level")
  assert(GBCFX.level == 0 and not GBCFX.active(),
    "GBCFX changed before the battle proof")
  U.wait(60)
  assert(U.shot(game, battlePath), "could not capture contact-battle proof")

  local proof = assert(io.open(shotDir .. "/runtime_assertions.txt", "wb"))
  proof:write("HEVO DUNGEON ENCOUNTER VISUAL PASS\n")
  proof:write("character=", character, "\n")
  proof:write("map=", demo.map, "\n")
  proof:write("start=", demo.start.x, ",", demo.start.y, ",",
    demo.start.facing, "\n")
  proof:write("capture_cell=", captureCell.x, ",", captureCell.y, "\n")
  proof:write("gbcfx=0\n")
  proof:write("journey_cycle=", requestedCycle, "\n")
  proof:write("level_formula=min(100,70+5*(cycle-1))\n")
  proof:write("exact_level=", expectedLevel, "\n")
  proof:write("expected_parents=", csv(exactParents[character]), "\n")
  proof:write("published_slots_per_active_map=10\n")
  proof:write("representative=", chosen, "\n")
  proof:write("visible_spawn=real_runtime_api,no_fallback,six_frame_sheet\n")
  proof:write("contact_battle=real_start_battle_script,command_menu\n")
  proof:write("foreign_only_excluded=", csv(sortedKeys(foreignOnly)), "\n")
  proof:write("final_evolutions_excluded=",
    csv(sortedKeys(finalEvolutions)), "\n")
  proof:write("hoenn_starter_lines_excluded=", csv(hoennStarterLines), "\n")
  proof:write("shared_maps_excluded=", csv(sharedMaps), "\n")
  proof:write("direct_parent_grant=none\n")
  proof:write("permanent_hevo_progress=none\n")
  proof:write("screenshots=", visiblePath:match("[^/]+$"), ",",
    battlePath:match("[^/]+$"), "\n")
  proof:close()

  print(("HEVO %s VISUAL PASS: %s Lv%d on %s (cycle %d)")
    :format(character, chosen, expectedLevel, demo.map, requestedCycle))
  print("HEVO FAIL-CLOSED PASS: wrong color, shared maps, final evolutions, Hoenn starters")
  print("HEVO NO-DIRECT-GRANT PASS: real Visible Wilds + contact battle runtime paths")
end
