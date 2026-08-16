-- Real LÖVE product acceptance for the Legacy Workshop (map index 1970).
-- The driver enters through the Celadon Legacy Gallery curator, progresses
-- all four visible seal states, reloads the native save, buys a Heavy Ball
-- through the real Ledger UI, walks out through the physical return warp and
-- captures both flat and DRAMALESS/Voxel rendering.
return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "dramaless_fp",
    "Legacy Workshop product proof requires DRAMALESS+FP")
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
    dramaless_package_sha256 = requiredSha("KA_DRAMALESS_PACKAGE_SHA256"),
    first_person_package_sha256 = requiredSha(
      "KA_FIRST_PERSON_PACKAGE_SHA256"),
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
  local Pipelines = require("src.render.Pipelines")
  local PaletteFX = require("src.render.PaletteFX")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  assert(identity == "ka65-final-legacy-workshop-product-full",
    "Legacy Workshop product proof requires its exact isolated identity")
  assert(version == "red" and GameVersion.get() == version,
    "Legacy Workshop product proof is frozen to Red")
  assert(SaveData.setActiveSlot(version, "slot6970") == "slot6970")

  local loadedMods = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local installed = assert(loadedMods.kanto_ascendant,
    "installed Authority package is missing")
  local dramaticMod = assert(loadedMods.DRAMALESS_SHAPE,
    "installed DRAMALESS_SHAPE package is missing")
  local firstPerson = assert(loadedMods.ds_fp_ceiling,
    "installed first-person ceiling package is missing")
  for _, path in ipairs({ tostring(love.filesystem.getSource() or ""),
      tostring(installed.path or ""), tostring(dramaticMod.path or ""),
      tostring(firstPerson.path or "") }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not installed-package evidence: " .. path)
  end

  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant exports unavailable")
  local workshop = assert(api.ngplusLegacyWorkshop,
    "Legacy Workshop export unavailable")
  local journey = assert(api.legacyJourney, "Legacy Journey export unavailable")
  assert(game.mods.exports.DRAMALESS_SHAPE,
    "DRAMALESS_SHAPE dependency is required for the Voxel proof")

  game.save.flags = game.save.flags or {}
  game.save.inventory = game.save.inventory or {}
  game.save.objectToggles = game.save.objectToggles or {}
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant = game.save.modData.kanto_ascendant or {}
  game.mods.modSave = game.save.modData
  game.save.modData.kanto_ascendant.ngplus_legacy_workshop = nil
  -- This pass is about the Workshop product, not the independent one-time
  -- post-game orientation. Mark it viewed so it cannot cover the curator.
  game.save.modData.kanto_ascendant.onboarding = { version = 1, shown = true }
  game.save.objectToggles[workshop.ID] = nil
  game.save.hallOfFame = { { legacyWorkshopQA = true } }
  game.save.money = 50000
  game.save.repelSteps = 9999
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.options = game.save.options or {}
  game.save.options.colors = "redpp"
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.qol_location_banners = false
  PaletteFX.setMode("redpp")

  local initialProfile = journey.profile()
  local initialCount = 0
  for _, key in ipairs({ "red", "blue", "green" }) do
    if initialProfile.completedPaths and initialProfile.completedPaths[key] then
      initialCount = initialCount + 1
    end
  end
  assert(initialCount == 0,
    "QA identity is not clean; use a fresh POKEPORT_IDENTITY")

  local dirs = {
    { "up", 0, -1 }, { "down", 0, 1 },
    { "left", -1, 0 }, { "right", 1, 0 },
  }
  local facingForDelta = {
    ["0:-1"] = "up", ["0:1"] = "down",
    ["-1:0"] = "left", ["1:0"] = "right",
  }

  local function awaitOverworld(mapId, frames)
    for tick = 1, frames or 300 do
      if game.overworld and game.overworld.map
          and game.overworld.map.id == mapId
          and not game.overworld.transitioning then return true end
      if tick % 12 == 0 and game.overworld and game.overworld.map
          and game.overworld.map.id == mapId
          and game.stack:top() ~= game.overworld then
        U.tap(game, "b")
      end
      coroutine.yield()
    end
    error("overworld did not settle on " .. tostring(mapId)
      .. " map=" .. tostring(game.overworld and game.overworld.map
        and game.overworld.map.id)
      .. " transitioning=" .. tostring(game.overworld
        and game.overworld.transitioning)
      .. " top=" .. tostring(game.stack:top())
      .. " ow=" .. tostring(game.overworld))
  end

  local function walkStep(direction, allowWarp)
    local ow, player = game.overworld, game.overworld.player
    local mapId, x, y = ow.map.id, player.cellX, player.cellY
    for _ = 1, 72 do
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
    U.wait(12)
    return true
  end

  local function pathTo(targetX, targetY, allowTargetNpc)
    local ow, start = game.overworld, game.overworld.player
    local queue, head = { { start.cellX, start.cellY } }, 1
    local seen = { [start.cellX .. ":" .. start.cellY] = true }
    local parent = {}
    local found
    while queue[head] do
      local node = queue[head]; head = head + 1
      if node[1] == targetX and node[2] == targetY then found = node; break end
      for _, dir in ipairs(dirs) do
        local nx, ny = node[1] + dir[2], node[2] + dir[3]
        local key = nx .. ":" .. ny
        local npc = ow:npcAtCell(nx, ny)
        if not seen[key] and ow.map:inBounds(nx, ny)
            and ow.map:isWalkableCell(nx, ny)
            and (not npc or allowTargetNpc and nx == targetX and ny == targetY) then
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
      table.insert(route, 1, step[3])
      cx, cy = step[1], step[2]
    end
    for _, direction in ipairs(route) do walkStep(direction, false) end
  end

  local function standBy(npc)
    local ow = game.overworld
    local choices = {}
    for _, dir in ipairs(dirs) do
      local x, y = npc.cellX - dir[2], npc.cellY - dir[3]
      if ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y)
          and not ow:npcAtCell(x, y) then
        choices[#choices + 1] = { x = x, y = y,
          face = facingForDelta[(npc.cellX - x) .. ":" .. (npc.cellY - y)] }
      end
    end
    local lastError
    for _, choice in ipairs(choices) do
      local ok, err = pcall(pathTo, choice.x, choice.y, false)
      if ok then
        U.tap(game, choice.face)
        U.wait(2)
        return choice
      end
      lastError = err
    end
    error("cannot stand beside " .. tostring(npc.def and npc.def.name)
      .. ": " .. tostring(lastError))
  end

  local function findNpc(name)
    for _, npc in ipairs(game.overworld and game.overworld.npcs or {}) do
      if npc.def and npc.def.name == name then return npc end
    end
  end

  local function awaitMenu(predicate, limit)
    for _ = 1, limit or 80 do
      local top = game.stack:top()
      if top and type(top.items) == "table" and (not predicate or predicate(top)) then
        return top
      end
      U.tap(game, "a")
      U.wait(4)
    end
    error("expected menu did not appear")
  end

  local function chooseMenuValue(menu, predicate)
    local wanted
    for index, item in ipairs(menu.items or {}) do
      if predicate(item, index) then wanted = index; break end
    end
    assert(wanted, "requested menu row is absent")
    while menu.index < wanted do U.tap(game, "down"); U.wait(2) end
    while menu.index > wanted do U.tap(game, "up"); U.wait(2) end
    U.tap(game, "a")
    U.wait(8)
  end

  local function clearToOverworld()
    for _ = 1, 120 do
      if game.stack:top() == game.overworld then return end
      local top = game.stack:top()
      U.tap(game, top and top.pages and "a" or "b")
      U.wait(3)
    end
    local top, keys = game.stack:top(), {}
    for key in pairs(top or {}) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    assert(top == game.overworld, "overlay would not close: top="
      .. tostring(top) .. " ow=" .. tostring(game.overworld)
      .. " topTitle=" .. tostring(top and top.title)
      .. " keys=" .. table.concat(keys, ","))
  end

  local function setVoxel(enabled)
    Pipelines.setLevel("voxel", enabled and 1 or 0)
    Pipelines.syncOptions(game.save.options)
    U.wait(enabled and 100 or 35)
    assert(Pipelines.level("voxel") == (enabled and 1 or 0),
      "Voxel pipeline level did not switch")
  end

  local function visibleSealCount()
    local unlocked = 0
    for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
      local row = workshop.SEAL_OBJECTS[character]
      local locked, open = findNpc(row.locked), findNpc(row.unlocked)
      assert((locked and not open) or (open and not locked),
        character .. " seal has ambiguous live object state")
      if open then unlocked = unlocked + 1 end
    end
    return unlocked
  end

  local function captureState(number)
    workshop.refreshSealVisuals(game)
    U.wait(24)
    assert(visibleSealCount() == number,
      "visible seal count does not match archive state " .. number)
    setVoxel(false)
    assert(U.shot(game, ("%s/2d/%02d_seals.png"):format(shotDir, number)))
    setVoxel(true)
    assert(U.shot(game, ("%s/voxel/%02d_seals.png"):format(shotDir, number)))
    setVoxel(false)
  end

  -- Start on the real Legacy Gallery floor and enter through its curator.
  U.teleport(game, "CELADON_MANSION_3F", 6, 6, "up")
  awaitOverworld("CELADON_MANSION_3F", 180)
  U.wait(30)
  clearToOverworld()
  assert(game:writeSave(), "initial Workshop QA save failed")
  local curator = assert(findNpc("KANTO_ASCENDANT_LEGACY_CURATOR"),
    "Legacy curator did not spawn after Hall of Fame")
  standBy(curator)
  assert(U.shot(game, shotDir .. "/2d/hub_curator.png"))
  U.tap(game, "a")
  local hubMenu = awaitMenu(function(menu)
    for _, item in ipairs(menu.items) do
      if item.value == "workshop" then return true end
    end
  end)
  chooseMenuValue(hubMenu, function(item) return item.value == "workshop" end)
  awaitOverworld(workshop.ID, 300)
  assert(game.overworld.player.cellX == workshop.ENTER.x
      and game.overworld.player.cellY == workshop.ENTER.y,
    "curator entry did not use the audited Workshop spawn")
  pathTo(9, 6, false)
  captureState(0)

  -- The three real archive writes are followed by native save reloads.  The
  -- Workshop must reconstruct its object state from durable authority each
  -- time rather than relying on a screenshot-only toggle.
  for index, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    assert(journey.completeHevoPath(game.save, character),
      character .. " archive seal write failed")
    workshop.refreshSealVisuals(game)
    assert(game:writeSave(), character .. " game save failed")
    local loaded, recovered = SaveData.load()
    assert(loaded, character .. " native save reload failed")
    game:restoreSave(loaded, recovered)
    game.mods.modSave = game.save.modData
    assert(workshop.sealCount(game.save) == index,
      character .. " seal was lost across reload")
    workshop.refreshSealVisuals(game)
    U.wait(25)
    captureState(index)
  end

  -- A completed seal without completed puzzle state must remain gated.
  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    local status = workshop.resonanceStatus(game.save, character,
      workshop.resonanceProgress(game, character))
    assert(status.state == "unsolved" and not status.usable,
      character .. " resonance bypassed an unresolved puzzle")
  end

  -- Open the physical Ledger object and buy Heavy Ball through the real list
  -- and confirmation UI.  This verifies plan visibility, economy and event
  -- freeze/unfreeze, not merely the purchase helper.
  local ledgerNpc = assert(findNpc("KA_NGPLUS_LEDGER_DESK"),
    "Ledger object is missing")
  standBy(ledgerNpc)
  U.tap(game, "a")
  local ledgerMenu = awaitMenu(function(menu)
    for _, item in ipairs(menu.items) do
      if item.value and item.value.item == "HEAVY_BALL" then return true end
    end
  end)
  assert(U.shot(game, shotDir .. "/2d/ledger_open.png"))
  local moneyBefore = game.save.money
  local ballsBefore = game.save.inventory.HEAVY_BALL or 0
  chooseMenuValue(ledgerMenu, function(item)
    return item.value and item.value.item == "HEAVY_BALL"
  end)
  for _ = 1, 80 do
    local top = game.stack:top()
    if top and top.defaultNo ~= nil and top.choice then break end
    U.tap(game, "a"); U.wait(3)
  end
  for _ = 1, 80 do
    local top = game.stack:top()
    if top and top.onChoose and top.index then break end
    U.tap(game, "a"); U.wait(3)
  end
  U.tap(game, "up")
  U.wait(2)
  U.tap(game, "a")
  U.wait(25)
  assert((game.save.inventory.HEAVY_BALL or 0) == ballsBefore + 1,
    "Heavy Ball purchase did not enter the Bag")
  assert(game.save.money == moneyBefore - workshop.BALL_PRICE,
    "Heavy Ball purchase charged the wrong amount")
  assert(U.shot(game, shotDir .. "/2d/heavy_ball_bought.png"))
  clearToOverworld()
  assert(game:writeSave(), "post-purchase save failed")
  local boughtSave = assert(SaveData.load(), "post-purchase reload failed")
  assert((boughtSave.inventory.HEAVY_BALL or 0) == ballsBefore + 1
      and boughtSave.money == moneyBefore - workshop.BALL_PRICE,
    "Heavy Ball transaction did not survive reload")

  -- Walk to the Workshop's one physical exit and prove it returns to the
  -- Gallery floor rather than LAST_MAP or a test-only teleport target.
  pathTo(workshop.EXIT.x, workshop.EXIT.y, false)
  for _ = 1, 240 do
    if game.overworld.map.id == "CELADON_MANSION_3F" then break end
    coroutine.yield()
  end
  assert(game.overworld.map.id == "CELADON_MANSION_3F",
    "Workshop exit did not return to the Legacy Gallery")
  awaitOverworld("CELADON_MANSION_3F", 240)
  assert(U.shot(game, shotDir .. "/2d/returned_to_gallery.png"))

  U.log("LEGACY WORKSHOP PRODUCT E2E PASS",
    "hub entry, 0/1/2/3 seals, reload, gated resonance, ledger purchase, return",
    shotDir)
  local result = assert(io.open(shotDir .. "/driver_result.txt", "wb"))
  result:write("status=PASS\n")
  result:write("scope=LEGACY-WORKSHOP-PRODUCT\n")
  result:write("edition=red\nrenderer=2D+DRAMALESS_FULL\n")
  result:write("curator_entry=1/1\n")
  result:write("seal_states=0/1/2/3\n")
  result:write("native_save_reload=4/4\n")
  result:write("unsolved_resonance_gate=3/3\n")
  result:write("ledger_purchase=1/1\n")
  result:write("physical_gallery_return=1/1\n")
  result:write("engine_payload_sha256=", receipts.engine_payload_sha256, "\n")
  result:write("authority_package_sha256=",
    receipts.authority_package_sha256, "\n")
  result:write("deutsch_package_sha256=", receipts.deutsch_package_sha256,
    "\n")
  result:write("dramaless_package_sha256=",
    receipts.dramaless_package_sha256, "\n")
  result:write("first_person_package_sha256=",
    receipts.first_person_package_sha256, "\n")
  result:write("package_gate_receipt_sha256=",
    receipts.package_gate_receipt_sha256, "\n")
  result:write("fail=0\n")
  result:close()
  love.event.quit(0)
end
