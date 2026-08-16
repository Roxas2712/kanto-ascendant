-- Real input-driven acceptance for the three Legacy Workshop resonance
-- shortcuts.  Each seal is touched before and after its campaign threshold
-- is genuinely solved.  The ready prompt must default to NO, survive a
-- native save reload and land on a walkable, unoccupied threshold cell.  The
-- ordinary threshold and tunnel warps then carry the player back outside.
return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "base_deutsch",
    "Legacy Workshop resonance proof requires base/deutsch")
  local function requiredSha(name)
    local value = os.getenv(name)
    assert(type(value) == "string" and #value == 64
        and value:match("^[0-9a-f]+$"),
      name .. " must be a lowercase SHA256 receipt")
    return value
  end
  local receipts = {
    engine_payload_sha256 = requiredSha("KA_ENGINE_PAYLOAD_SHA256"),
    authority_package_sha256 = requiredSha("KA_AUTHORITY_PACKAGE_SHA256"),
    deutsch_package_sha256 = requiredSha("KA_DEUTSCH_PACKAGE_SHA256"),
    package_gate_receipt_sha256 = requiredSha(
      "KA_PACKAGE_GATE_RECEIPT_SHA256"),
  }
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local utilPath = assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL packaged harness path is required")
  for _, path in ipairs({ shotDir, utilPath }) do
    assert(path:sub(1, 1) == "/"
        and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true),
      "source/worktree path is not package evidence: " .. path)
  end
  local U = dofile(utilPath)
  local GameVersion = require("src.core.GameVersion")
  local SaveData = require("src.core.SaveData")
  local PaletteFX = require("src.render.PaletteFX")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  assert(identity == "ka65-final-legacy-workshop-resonance-2d",
    "Workshop resonance proof requires its exact isolated identity")
  assert(version == "red" and GameVersion.get() == version,
    "Workshop resonance proof is frozen to Red")
  assert(SaveData.setActiveSlot(version, "slot6971") == "slot6971")

  local loadedMods = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local installed = assert(loadedMods.kanto_ascendant,
    "installed Authority package is missing")
  for _, path in ipairs({ tostring(love.filesystem.getSource() or ""),
      tostring(installed.path or "") }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not installed-package evidence: " .. path)
  end

  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant exports unavailable")
  local workshop = assert(api.ngplusLegacyWorkshop, "Workshop export missing")
  local journey = assert(api.legacyJourney, "Legacy Journey export missing")
  local characters = assert(api.extendedCharacters, "character export missing")
  local campaign = assert(api.hiddenEvolutionCampaign,
    "Hidden Evolution campaign export missing")
  local modules = campaign.modules or campaign.load()
  assert(modules.RED and modules.BLUE and modules.GREEN and modules.tunnel,
    "campaign modules are incomplete")

  game.save.flags = game.save.flags or {}
  game.save.inventory = game.save.inventory or {}
  game.save.objectToggles = game.save.objectToggles or {}
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant = game.save.modData.kanto_ascendant or {}
  game.mods.modSave = game.save.modData
  game.save.modData.kanto_ascendant.ngplus_legacy_workshop = nil
  game.save.modData.kanto_ascendant.hevo_run = nil
  game.save.modData.kanto_ascendant.onboarding = { version = 1, shown = true }
  game.save.objectToggles[workshop.ID] = nil
  game.save.hallOfFame = { { workshopResonanceQA = true } }
  game.save.repelSteps = 9999
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.options = game.save.options or {}
  game.save.options.colors = "redpp"
  game.save.options.textSpeed = 1
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.qol_location_banners = false
  PaletteFX.setMode("redpp")

  local dirs = {
    { "up", 0, -1 }, { "down", 0, 1 },
    { "left", -1, 0 }, { "right", 1, 0 },
  }
  local directionForDelta = {
    ["0:-1"] = "up", ["0:1"] = "down",
    ["-1:0"] = "left", ["1:0"] = "right",
  }

  local function awaitOverworld(mapId, frames)
    for _ = 1, frames or 360 do
      local ow = game.overworld
      if ow and ow.map and ow.map.id == mapId and not ow.transitioning
          and game.stack:top() == ow then return true end
      coroutine.yield()
    end
    error("overworld did not settle on " .. tostring(mapId)
      .. "; current=" .. tostring(game.overworld and game.overworld.map
        and game.overworld.map.id))
  end

  local function walkStep(direction, allowWarp)
    local ow, player = game.overworld, game.overworld.player
    local mapId, x, y = ow.map.id, player.cellX, player.cellY
    for _ = 1, 84 do
      table.insert(game.input.pressQueue, direction)
      game.input.state[direction] = true
      coroutine.yield()
      if allowWarp and ow.map.id ~= mapId then break end
      if player.cellX ~= x or player.cellY ~= y then break end
    end
    game.input.state[direction] = false
    if allowWarp and ow.map.id ~= mapId then return true end
    assert(player.cellX ~= x or player.cellY ~= y,
      "input walk failed: " .. direction .. " at " .. x .. "," .. y)
    U.wait(10)
    return true
  end

  local function pathTo(targetX, targetY)
    local ow, start = game.overworld, game.overworld.player
    local queue, head = { { start.cellX, start.cellY } }, 1
    local seen = { [start.cellX .. ":" .. start.cellY] = true }
    local parent, found = {}, nil
    while queue[head] do
      local node = queue[head]; head = head + 1
      if node[1] == targetX and node[2] == targetY then found = node; break end
      for _, dir in ipairs(dirs) do
        local nx, ny = node[1] + dir[2], node[2] + dir[3]
        local key = nx .. ":" .. ny
        if not seen[key] and ow.map:inBounds(nx, ny)
            and ow.map:isWalkableCell(nx, ny) and not ow:npcAtCell(nx, ny) then
          seen[key] = true
          parent[key] = { node[1], node[2], dir[1] }
          queue[#queue + 1] = { nx, ny }
        end
      end
    end
    assert(found, ("no walkable route to %d,%d on %s"):format(
      targetX, targetY, ow.map.id))
    local route, cx, cy = {}, targetX, targetY
    while cx ~= start.cellX or cy ~= start.cellY do
      local step = assert(parent[cx .. ":" .. cy])
      table.insert(route, 1, step[3]); cx, cy = step[1], step[2]
    end
    for _, direction in ipairs(route) do walkStep(direction, false) end
  end

  local function findNpc(name)
    for _, npc in ipairs(game.overworld and game.overworld.npcs or {}) do
      if npc.def and npc.def.name == name then return npc end
    end
  end

  local function standBy(npc)
    local ow = game.overworld
    for _, dir in ipairs(dirs) do
      local x, y = npc.cellX - dir[2], npc.cellY - dir[3]
      if ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y)
          and not ow:npcAtCell(x, y) then
        local ok = pcall(pathTo, x, y)
        if ok then
          U.tap(game, directionForDelta[(npc.cellX - x) .. ":"
            .. (npc.cellY - y)])
          U.wait(2)
          return true
        end
      end
    end
    error("cannot stand beside " .. tostring(npc.def and npc.def.name))
  end

  local function clearToOverworld()
    for _ = 1, 180 do
      if game.stack:top() == game.overworld then return true end
      U.tap(game, "b"); U.wait(3)
    end
    error("overlay would not close")
  end

  local function awaitChoice()
    for _ = 1, 180 do
      local top = game.stack:top()
      if top and type(top.onChoose) == "function" and top.index then return top end
      U.tap(game, "a"); U.wait(3)
    end
    error("default-NO resonance choice did not appear")
  end

  local function shot(tag)
    assert(U.shot(game, shotDir .. "/" .. tag .. ".png"),
      "screenshot failed: " .. tag)
  end

  local function capture2D(prefix)
    U.wait(35)
    shot(prefix .. "_2d")
  end

  local function solveRed()
    local red = modules.RED
    for index = 1, 5 do
      local name = "KA_RED_STATUE_" .. index
      local question = assert(red.questionForStatue(game.save, name))
      local ok = red.answerStatue(game.save, name, question.id, question.answer)
      assert(ok, "RED statue solution failed at " .. index)
    end
    for _, name in ipairs({ "A", "B", "C" }) do
      assert(red.setBoulder(game.save, name), "RED boulder state failed: " .. name)
    end
    assert(red.canEnterShrine(game.save), "RED threshold is not genuinely solved")
  end

  local function solveBlue()
    local blue = modules.BLUE
    for _, statue in ipairs({
      "HALL", "ICE_NORTH", "ICE_DEEP", "DEPTHS_WEST", "DEPTHS_EAST",
    }) do
      local question = assert(blue.nextQuestion(statue))
      local ok = blue.answer(statue, question.id, question.correct)
      assert(ok, "BLUE statue solution failed at " .. statue)
    end
    assert(blue.shrineOpen(), "BLUE threshold is not genuinely solved")
  end

  local function solveGreen()
    local green = modules.GREEN
    for statue = 1, 5 do
      local question = assert(green.questionFor(game.save, statue))
      local ok = green.answer(game.save, statue, question.answer)
      assert(ok, "GREEN statue solution failed at " .. statue)
    end
    assert(green.visibility(game.save) >= 16,
      "GREEN threshold is not genuinely solved")
  end

  local solvers = { RED = solveRed, BLUE = solveBlue, GREEN = solveGreen }

  local function sealNpc(character)
    workshop.refreshSealVisuals(game)
    U.wait(16)
    return assert(findNpc(workshop.SEAL_OBJECTS[character].unlocked),
      character .. " unlocked Workshop seal is absent")
  end

  local function talkSeal(character)
    standBy(sealNpc(character))
    U.tap(game, "a")
    U.wait(100)
    assert(game.stack:top() ~= game.overworld,
      character .. " seal did not open its real event")
  end

  local function stepOnWarp(warp, expectedMap)
    local ow = game.overworld
    local candidates = {}
    for _, dir in ipairs(dirs) do
      local x, y = warp.x - dir[2], warp.y - dir[3]
      if ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y)
          and not ow:npcAtCell(x, y) then
        candidates[#candidates + 1] = { x = x, y = y, direction = dir[1] }
      end
    end
    -- Prefer the current/nearest side of the warp.  Trying a farther side
    -- first can make the pathfinder cross the very warp under test while it
    -- is merely positioning the player, which replaces the map before the
    -- deliberate held-direction step below.
    local px, py = ow.player.cellX, ow.player.cellY
    table.sort(candidates, function(a, b)
      local da = math.abs(a.x - px) + math.abs(a.y - py)
      local db = math.abs(b.x - px) + math.abs(b.y - py)
      return da < db
    end)
    local chosen
    for _, candidate in ipairs(candidates) do
      if pcall(pathTo, candidate.x, candidate.y) then chosen = candidate; break end
    end
    assert(chosen, "no physical approach to warp on " .. ow.map.id)
    -- Non-door cave ladder cells use CheckWarpsNoCollision, which requires
    -- the d-pad still held when the step finishes.  The ordinary movement
    -- helper releases as soon as the logical cell changes, so keep this one
    -- direction held through the complete physical warp transition.
    local fromMap = ow.map.id
    for _ = 1, 180 do
      table.insert(game.input.pressQueue, chosen.direction)
      game.input.state[chosen.direction] = true
      coroutine.yield()
      -- A successful warp replaces the overworld controller.  Inspect the
      -- live controller rather than the stale source-map reference.
      if game.overworld.map.id ~= fromMap then break end
    end
    game.input.state[chosen.direction] = false
    assert(game.overworld.map.id ~= fromMap,
      "physical warp did not activate on " .. fromMap)
    awaitOverworld(expectedMap, 420)
  end

  local cleanProfile = journey.profile()
  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    assert(not (cleanProfile.completedPaths
      and cleanProfile.completedPaths[character:lower()]),
      "QA identity is not clean: " .. character)
    assert(journey.completeHevoPath(game.save, character),
      "could not grant real archive seal: " .. character)
  end
  assert(workshop.sealCount(game.save) == 3, "three seals did not persist")

  U.teleport(game, workshop.ID, workshop.ENTER.x, workshop.ENTER.y,
    workshop.ENTER.facing:lower())
  awaitOverworld(workshop.ID, 420)
  workshop.refreshSealVisuals(game)

  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    characters.select(character)
    workshop.refreshSealVisuals(game)
    local unsolved = workshop.resonanceStatus(game.save, character,
      workshop.resonanceProgress(game, character))
    assert(unsolved.state == "unsolved" and not unsolved.usable,
      character .. " unresolved puzzle was bypassed")

    talkSeal(character)
    capture2D(character:lower() .. "_01_unsolved")
    clearToOverworld()
    assert(game.overworld.map.id == workshop.ID,
      character .. " unsolved seal unexpectedly warped")

    solvers[character]()
    local ready = workshop.resonanceStatus(game.save, character,
      workshop.resonanceProgress(game, character))
    assert(ready.state == "ready" and ready.usable,
      character .. " solved threshold did not enable resonance")
    assert(game:writeSave(), character .. " solved-state save failed")
    local loaded, recovered = SaveData.load()
    assert(loaded, character .. " solved-state reload failed")
    game:restoreSave(loaded, recovered)
    game.mods.modSave = game.save.modData
    assert(workshop.resonanceStatus(game.save, character,
      workshop.resonanceProgress(game, character)).state == "ready",
      character .. " resonance was lost across Save/Reload")
    workshop.refreshSealVisuals(game)

    talkSeal(character)
    local noChoice = awaitChoice()
    assert(noChoice.index == 2,
      character .. " resonance prompt does not default to NO")
    capture2D(character:lower() .. "_02_ready_default_no")
    U.tap(game, "a")
    awaitOverworld(workshop.ID, 240)
    assert(game.overworld.map.id == workshop.ID,
      character .. " default-NO unexpectedly warped")

    local destination = assert(workshop.resonanceDestination(game, character))
    talkSeal(character)
    local yesChoice = awaitChoice()
    assert(yesChoice.index == 2, "second prompt lost default-NO")
    U.tap(game, "up"); U.wait(2)
    assert(yesChoice.index == 1, "YES could not be selected")
    U.tap(game, "a")
    awaitOverworld(destination.map, 480)
    local ow = game.overworld
    assert(ow.player.cellX == destination.x and ow.player.cellY == destination.y,
      character .. " resonance used the wrong destination cell")
    assert(ow.map:isWalkableCell(destination.x, destination.y),
      character .. " resonance landed on collision")
    assert(not ow:npcAtCell(destination.x, destination.y),
      character .. " resonance landed on an occupied cell")
    capture2D(character:lower() .. "_03_threshold")

    assert(game:writeSave(), character .. " threshold token save failed")
    local thresholdSave, thresholdRecovered = SaveData.load()
    assert(thresholdSave, character .. " threshold token reload failed")
    game:restoreSave(thresholdSave, thresholdRecovered)
    game.mods.modSave = game.save.modData
    local token = assert(workshop.resonanceReturnState(),
      character .. " return token was lost across reload")
    assert(token.character == character and token.sourceMap == workshop.ID
        and token.threshold == destination.map,
      character .. " return token is not bound to character/source/threshold")

    local thresholdDef = assert(game.data.maps[destination.map])
    local inbound = assert(thresholdDef.warps and thresholdDef.warps[1],
      character .. " threshold has no physical return warp")
    stepOnWarp(inbound, workshop.ID)
    assert(workshop.resonanceReturnState() == nil,
      character .. " return token was not consumed exactly once")
    workshop.refreshSealVisuals(game)
    capture2D(character:lower() .. "_04_return_workshop")
    local returned = assert(SaveData.load(),
      character .. " consumed return-token reload failed")
    local returnedBucket = returned.modData and returned.modData.kanto_ascendant
    local returnedWorkshop = returnedBucket
      and returnedBucket.ngplus_legacy_workshop
    assert(not (returnedWorkshop and returnedWorkshop.resonanceReturn),
      character .. " consumed return token reappeared after reload")
  end

  assert(game:writeSave(), "final resonance E2E save failed")
  local final = assert(SaveData.load(), "final resonance E2E reload failed")
  assert(final.modData and final.modData.kanto_ascendant
      and final.modData.kanto_ascendant.hevo_run,
    "solved resonance state is absent from the durable save")
  U.log("LEGACY WORKSHOP RESONANCE E2E PASS",
    "RED BLUE GREEN; unsolved gate; default NO; save/reload; walkable warp; physical return",
    shotDir)
  local result = assert(io.open(shotDir .. "/driver_result.txt", "wb"))
  result:write("status=PASS\n")
  result:write("scope=LEGACY-WORKSHOP-RESONANCE\n")
  result:write("edition=red\nrenderer=2D\n")
  result:write("characters=RED,BLUE,GREEN\n")
  result:write("unsolved_gate=3/3\n")
  result:write("ready_default_no=3/3\n")
  result:write("native_save_reload=10/10\n")
  result:write("walkable_resonance_destination=3/3\n")
  result:write("physical_return=3/3\n")
  result:write("return_token_exact_once=3/3\n")
  result:write("engine_payload_sha256=", receipts.engine_payload_sha256, "\n")
  result:write("authority_package_sha256=",
    receipts.authority_package_sha256, "\n")
  result:write("deutsch_package_sha256=", receipts.deutsch_package_sha256,
    "\n")
  result:write("package_gate_receipt_sha256=",
    receipts.package_gate_receipt_sha256, "\n")
  result:write("fail=0\n")
  result:close()
  love.event.quit(0)
end
