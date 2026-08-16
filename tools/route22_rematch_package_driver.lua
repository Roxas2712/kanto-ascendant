-- DRV-ROUTE22-REMATCH-ALT
--
-- Package-only physical proof for the two authored Route 22 rival scenes.
-- The companion setup writes bounded first/late prerequisite slots.  This
-- driver only presses ordinary joypad input, observes real BattleState and
-- Runtime events, and uses native SAVE/load/restore.  It never calls the map
-- script, rematch dispatcher or battle constructor and never assigns story,
-- party, result, damage, rematch, fissure or identity state.
return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 required; source runs are not Route22 evidence")

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
    source_save_sha256 = requiredSha("KA_SOURCE_SAVE_SHA256"),
    package_gate_receipt_sha256 = requiredSha(
      "KA_PACKAGE_GATE_RECEIPT_SHA256"),
  }

  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local utilPath = assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL packaged harness path required")
  local harnessRoot = assert(os.getenv("GEN1RECOMP_DIR"),
    "GEN1RECOMP_DIR packaged harness root required")
  for _, path in ipairs({ dir, utilPath, harnessRoot }) do
    assert(path:sub(1, 1) == "/"
        and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true),
      "source/worktree path is not package evidence: " .. path)
  end

  local U = dofile(utilPath)
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local BattleState = require("src.battle.BattleState")
  local TypeChart = require("src.battle.TypeChart")
  local Runtime = require("src.mods.Runtime")
  local ChoiceBox = require("src.ui.ChoiceBox")

  local edition = GameVersion.get()
  local expectedEdition = tostring(assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION required")):lower()
  local variant = tostring(assert(os.getenv("ROUTE22_QA_VARIANT"),
    "ROUTE22_QA_VARIANT required")):upper()
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY required")
  assert(edition == expectedEdition
      and (edition == "red" or edition == "blue" or edition == "yellow")
      and (variant == "FRESH" or variant == "ALT"),
    "Route22 package driver requires requested R/B/Y and FRESH/ALT")
  local expectedIdentity = ("ka65-final-route22-%s-%s")
    :format(edition, variant:lower())
  assert(identity == expectedIdentity,
    "Route22 package driver rejects a non-orchestrated identity")

  local loadedMods = assert(game.mods and game.mods.mods,
    "installed package registry unavailable")
  local installed = assert(loadedMods.kanto_ascendant,
    "installed Authority package missing")
  for _, path in ipairs({
    tostring(love.filesystem.getSource() or ""),
    tostring(installed.path or ""),
  }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not installed-package evidence: " .. path)
  end

  local api = assert(game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "current Authority exports missing")
  local characters = assert(api.extendedCharacters,
    "extended-character runtime missing")
  local characterByEdition = {
    red = { player = "RED", rival = "BLUE", third = "GREEN" },
    blue = { player = "BLUE", rival = "GREEN", third = "RED" },
    yellow = { player = "GREEN", rival = "RED", third = "BLUE" },
  }
  local expectedCharacter = characterByEdition[edition]
  local firstSlot = "slot65route22_" .. variant:lower() .. "_first"
  local lateSlot = "slot65route22_" .. variant:lower() .. "_late"
  local routeKeys = {
    "ROUTE22_RIVAL1", "ROUTE_22_obj_1",
    "ROUTE22_RIVAL2", "ROUTE_22_obj_2",
  }

  local function expectedOriginKind()
    if variant == "FRESH" then return "native-save-new-game" end
    if edition == "red" then return "immutable-blitz-save" end
    return "immutable-blitz-cross-edition-clone"
  end

  local function assertOrigin(stage)
    local origin = assert(game.save and game.save.qaRoute22Origin,
      "Route22 package origin missing")
    assert(origin.version == 1 and origin.variant == variant
        and origin.kind == expectedOriginKind()
        and origin.sourceSha256 == receipts.source_save_sha256
        and origin.packageGateReceiptSha256
          == receipts.package_gate_receipt_sha256
        and origin.playerCharacter == expectedCharacter.player
        and origin.rivalCharacter == expectedCharacter.rival
        and origin.thirdCharacter == expectedCharacter.third
        and origin.stage == stage,
      "Route22 package origin is not pinned to this cell/stage")
    local state = characters.getState()
    assert(state.enabled == true
        and state.player_character == expectedCharacter.player
        and state.rival_character == expectedCharacter.rival
        and state.third_character == expectedCharacter.third,
      "Route22 native load changed the character/rival matrix")
  end

  local function assertNoGenericRematch(label)
    local states = api.trainerStates()
    for _, key in ipairs(routeKeys) do
      assert(not (game.save.defeatedTrainers or {})[key],
        label .. " leaked a story result into defeatedTrainers: " .. key)
      assert(states[key] == nil,
        label .. " created a generic rematch record: " .. key)
    end
  end

  local function fissureSurface()
    local def = assert(game.data.maps.ROUTE_22,
      "packaged Route22 map missing")
    local rival1, rival2 = 0, 0
    for _, object in ipairs(def.objects or {}) do
      if object.name == "ROUTE22_RIVAL1"
          and object.text == "TEXT_ROUTE22_RIVAL1" then
        rival1 = rival1 + 1
      elseif object.name == "ROUTE22_RIVAL2"
          and object.text == "TEXT_ROUTE22_RIVAL2" then
        rival2 = rival2 + 1
      end
    end
    local decals = 0
    for _, decal in ipairs(def.wallDecals or {}) do
      if decal.id == "KA_HEVO_WALL_FISSURE_RED" then
        assert(decal.cellX == 35 and decal.cellY == 1
            and decal.face == "south"
            and tostring(decal.image):find(
              "hidden_evolution/sealed_fissure.png", 1, true),
          "Route22 RED fissure wall decal changed identity/placement")
        decals = decals + 1
      end
    end
    local anchors = 0
    for _, npc in ipairs(game.overworld and game.overworld.npcs or {}) do
      if npc.def and npc.def.name == "KA_HEVO_FISSURE_RED" then
        assert(npc.cellX == 35 and npc.cellY == 1
            and npc.passable == true and npc.def.renderMode == "none"
            and npc.def.text == "TEXT_KA_HEVO_FISSURE_RED",
          "Route22 RED fissure interaction anchor changed")
        anchors = anchors + 1
      end
    end
    assert(rival1 == 1 and rival2 == 1 and decals == 1 and anchors == 1,
      "Route22 rival/fissure registrations do not coexist exactly once")
    assert(not (35 == 29 and (1 == 4 or 1 == 5)),
      "Route22 fissure overlaps the authored rival trigger")
  end

  local function waitForField(mapId, label)
    for _ = 1, 900 do
      local ow = game.overworld
      local player = ow and ow.player
      local runner = ow and ow.runner
      if ow and game.stack:top() == ow and ow.map.id == mapId
          and player and not player.moving and not player.inputLocked
          and #(ow.scriptMoves or {}) == 0
          and not (runner and runner.isRunning and runner:isRunning()) then
        return
      end
      U.tap(game, "a")
      U.wait(2)
    end
    error(label .. " did not settle on " .. mapId)
  end

  local function nativeReload(stage, slot, label)
    assert(SaveData.setActiveSlot(edition, slot) == slot,
      label .. " could not select native slot")
    local loaded, recovered = assert(SaveData.load(edition),
      label .. " native SaveData.load failed")
    game:restoreSave(loaded, recovered)
    U.wait(36)
    waitForField("ROUTE_22", label)
    assert(game.overworld.player.cellX == 28
        and game.overworld.player.cellY == 4,
      label .. " did not restore the pre-ambush field cell")
    assertOrigin(stage)
    fissureSurface()
    assertNoGenericRematch(label)
  end

  -- Boot the first prerequisite through the ordinary title CONTINUE flow.
  U.wait(5)
  U.tap(game, "start")
  U.wait(10)
  U.tap(game, "a")
  for _ = 1, 600 do
    if game.overworld and game.stack:top() == game.overworld then break end
    U.tap(game, "a")
    U.wait(3)
  end
  waitForField("ROUTE_22", "title CONTINUE")
  assert(SaveData.activeSlot(edition) == firstSlot,
    "title CONTINUE did not load the Route22 first slot")
  assertOrigin("first")
  fissureSurface()
  assertNoGenericRematch("first/fresh")

  local trace = {}
  local labels = setmetatable({}, { __mode = "k" })
  local activePhase
  local originalEmit = Runtime.emit
  Runtime.emit = function(name, payload)
    if name == "battle.started" and payload and payload.battle
        and game.overworld and game.overworld.map
        and game.overworld.map.id == "ROUTE_22"
        and activePhase then
      labels[payload.battle] = activePhase
      trace[activePhase .. "_started"] =
        (trace[activePhase .. "_started"] or 0) + 1
    elseif name == "battle.ended" and payload and payload.battle then
      local phase = labels[payload.battle]
      if phase then
        trace[phase .. "_result"] = payload.result
        trace[phase .. "_ended"] =
          (trace[phase .. "_ended"] or 0) + 1
      end
    elseif name == "world.blacked_out" and activePhase then
      trace[activePhase .. "_blackout"] =
        (trace[activePhase .. "_blackout"] or 0) + 1
    end
    return originalEmit(name, payload)
  end

  local function waitForBattle(class, phase, shotName)
    activePhase = phase
    local p = assert(game.overworld and game.overworld.player,
      phase .. " has no Route22 player")
    assert(game.overworld.map.id == "ROUTE_22"
        and p.cellX == 28 and p.cellY == 4 and p.facing == "right",
      phase .. " did not start at the physical Route22 ambush approach")
    U.tap(game, "right")
    local battle
    for _ = 1, 1200 do
      local top = game.stack:top()
      if getmetatable(top) == ChoiceBox then
        error(phase .. " opened a generic rematch ChoiceBox")
      end
      if getmetatable(top) == BattleState and top.oppClass == class then
        battle = top
        break
      end
      if top ~= game.overworld then U.tap(game, "a") end
      U.wait(2)
    end
    assert(battle, phase .. " did not enter its physical authored BattleState")
    local wantedParty
    if edition == "yellow" then
      wantedParty = class == "OPP_RIVAL1" and 2 or 8
    else
      wantedParty = class == "OPP_RIVAL1" and 4 or 10
    end
    assert(battle.partyIndex == wantedParty and battle.rematch ~= true
        and battle.rematchLevelBoost == nil
        and battle.trainer
        and battle.trainer.ascendantCharacter == expectedCharacter.rival,
      phase .. " became a generic/scaled rematch or changed rival identity")
    for _ = 1, 480 do
      if battle.showEnemyTrainer and (battle.introSlide or 1) <= 0 then break end
      U.wait(1)
    end
    assert(battle.showEnemyTrainer and (battle.introSlide or 1) <= 0,
      phase .. " trainer introduction never became drawable")
    assert(U.shot(game, dir .. "/" .. shotName .. ".png"),
      phase .. " battle capture failed")
    return battle
  end

  local function strongestMoveSlot(top)
    local best, bestScore = 2, -1
    local defender = top.enemy and top.enemy.curTypes or {}
    for index, move in ipairs(top.player and top.player.curMoves or {}) do
      if index > 1 and (tonumber(move.pp) or 0) > 0 then
        local def = game.data.moves[move.id]
        local power = def and tonumber(def.power) or 0
        local effectiveness = def and def.type
          and TypeChart.effectiveness(def.type, defender) or 0
        local score = power * effectiveness
        if score > bestScore then
          best, bestScore = index, score
        end
      end
    end
    assert(bestScore > 0, "Route22 retry has no damaging move")
    return best
  end

  local function chooseMove(top, wanted)
    wanted = wanted == "best" and strongestMoveSlot(top) or wanted
    if top.moveIndex == wanted then
      U.tap(game, "a")
      return
    end
    if top:wideLayout() then
      local row = math.floor((top.moveIndex - 1) / 2)
      local wantedRow = math.floor((wanted - 1) / 2)
      local col = (top.moveIndex - 1) % 2
      local wantedCol = (wanted - 1) % 2
      U.tap(game, row ~= wantedRow and "down"
        or col ~= wantedCol and "right" or "a")
    else
      U.tap(game, "down")
    end
  end

  local function driveBattle(phase, moveMode, expectedResult)
    for tick = 1, 18000 do
      local top = game.stack:top()
      if trace[phase .. "_result"] then
        local field = game.overworld and game.stack:top() == game.overworld
        local settledWin = expectedResult == "win" and field
        local settledLoss = expectedResult == "lose"
          and trace[phase .. "_blackout"] == 1 and field
          and game.overworld.map.id == "PALLET_TOWN"
        if settledWin or settledLoss then break end
        U.tap(game, "a")
      elseif getmetatable(top) == BattleState then
        if top.phase == "menu" then
          U.tap(game, "a")
        elseif top.phase == "moveSelect" then
          chooseMove(top, moveMode)
        else
          U.tap(game, "a")
        end
      else
        U.tap(game, "a")
      end
      U.wait(2)
    end
    assert(trace[phase .. "_started"] == 1
        and trace[phase .. "_ended"] == 1
        and trace[phase .. "_result"] == expectedResult
        and (expectedResult ~= "lose"
          or trace[phase .. "_blackout"] == 1),
      phase .. " did not resolve naturally as " .. expectedResult)
    activePhase = nil
  end

  local FIRST = "EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE"
  local SECOND = "EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE"

  assert(game:writeSave(), "first pre-loss native SAVE failed")
  waitForBattle("OPP_RIVAL1", "first_loss", "01_first_loss_intro")
  driveBattle("first_loss", 1, "lose")
  waitForField("PALLET_TOWN", "first physical blackout")
  assert(game.save.flags[FIRST] ~= true and game.save.flags[SECOND] ~= true,
    "physical first loss consumed a Route22 victory flag")
  assertNoGenericRematch("first/loss")

  nativeReload("first", firstSlot, "first loss reload")
  assert(game.save.flags[FIRST] ~= true,
    "native first-loss reload did not re-arm the authored encounter")
  waitForBattle("OPP_RIVAL1", "first_win", "02_first_retry_intro")
  driveBattle("first_win", "best", "win")
  waitForField("ROUTE_22", "first win script")
  assert(game.save.flags[FIRST] == true and game.save.flags[SECOND] ~= true,
    "physical first retry did not commit only its authored victory flag")
  assertNoGenericRematch("first/win")
  assert(game:writeSave(), "first-win native SAVE failed")
  local firstWon = assert(SaveData.load(edition),
    "first-win native load failed")
  game:restoreSave(firstWon, false)
  U.wait(36)
  waitForField("ROUTE_22", "first win persistence")
  assert(game.save.flags[FIRST] == true and game.save.flags[SECOND] ~= true,
    "first-win flag did not survive native reload")
  assertOrigin("first")
  fissureSurface()
  assertNoGenericRematch("first/win-reload")

  nativeReload("late", lateSlot, "late prerequisite bridge")
  assert(game.save.flags[FIRST] == true
      and game.save.flags.EVENT_BEAT_BROCK == true
      and game.save.flags.EVENT_BEAT_GIOVANNI == true
      and game.save.flags[SECOND] ~= true,
    "late prerequisite slot does not arm only the second Route22 scene")
  assert(game:writeSave(), "late pre-loss native SAVE failed")
  waitForBattle("OPP_RIVAL2", "late_loss", "03_late_loss_intro")
  driveBattle("late_loss", 1, "lose")
  waitForField("PALLET_TOWN", "late physical blackout")
  assert(game.save.flags[FIRST] == true and game.save.flags[SECOND] ~= true,
    "physical late loss changed first/second victory ownership")
  assertNoGenericRematch("late/loss")

  nativeReload("late", lateSlot, "late loss reload")
  assert(game.save.flags[FIRST] == true and game.save.flags[SECOND] ~= true,
    "native late-loss reload did not re-arm only the late encounter")
  waitForBattle("OPP_RIVAL2", "late_win", "04_late_retry_intro")
  driveBattle("late_win", "best", "win")
  waitForField("ROUTE_22", "late win script")
  assert(game.save.flags[FIRST] == true and game.save.flags[SECOND] == true,
    "physical late retry did not preserve first win and commit late win")
  assertNoGenericRematch("late/win")
  assert(game:writeSave(), "late-win native SAVE failed")
  local lateWon = assert(SaveData.load(edition),
    "late-win native load failed")
  game:restoreSave(lateWon, false)
  U.wait(36)
  waitForField("ROUTE_22", "late win persistence")
  assert(game.save.flags[FIRST] == true and game.save.flags[SECOND] == true,
    "late-win flags did not survive native reload")
  assertOrigin("late")
  fissureSurface()
  assertNoGenericRematch("late/win-reload")

  -- Physical coexistence proof: after both story encounters are complete,
  -- walk from the real Route22 field to the wall-local fissure, face its
  -- invisible passable anchor and press A.  The resulting authored Riss text
  -- must remain on Route22; no rival/rematch choice may capture this input.
  local directions = {
    { 1, 0, "right" }, { -1, 0, "left" },
    { 0, 1, "down" }, { 0, -1, "up" },
  }
  local function walkOne(direction)
    local p = game.overworld.player
    local x, y = p.cellX, p.cellY
    for _ = 1, 2 do
      U.tap(game, direction)
      for _ = 1, 24 do
        U.wait(1)
        if p.cellX ~= x or p.cellY ~= y then break end
      end
      if p.cellX ~= x or p.cellY ~= y then break end
    end
    assert(p.cellX ~= x or p.cellY ~= y,
      ("Route22 physical step %s failed at %d,%d")
        :format(direction, x, y))
    U.wait(3)
  end
  local function walkToCell(targetX, targetY)
    local ow, map, p = game.overworld, game.overworld.map,
      game.overworld.player
    local function occupied(x, y)
      local blocker = ow:npcAtCell(x, y)
      return blocker and blocker.passable ~= true
    end
    local start = p.cellX .. ":" .. p.cellY
    local finish = targetX .. ":" .. targetY
    local queue, head = { { p.cellX, p.cellY } }, 1
    local previous = { [start] = false }
    while queue[head] and previous[finish] == nil do
      local point = queue[head]
      head = head + 1
      local tag = point[1] .. ":" .. point[2]
      for _, step in ipairs(directions) do
        local x, y = point[1] + step[1], point[2] + step[2]
        local nextTag = x .. ":" .. y
        if previous[nextTag] == nil and map:isWalkableCell(x, y)
            and (nextTag == finish or not occupied(x, y)) then
          previous[nextTag] = { tag, step[3] }
          queue[#queue + 1] = { x, y }
        end
      end
    end
    assert(previous[finish] ~= nil or finish == start,
      "no physical Route22 route to fissure approach")
    local steps = {}
    while finish ~= start do
      local step = assert(previous[finish])
      steps[#steps + 1] = step[2]
      finish = step[1]
    end
    for index = #steps, 1, -1 do walkOne(steps[index]) end
  end
  walkToCell(35, 2)
  local player = game.overworld.player
  local beforeTurnX, beforeTurnY = player.cellX, player.cellY
  U.tap(game, "up")
  U.wait(6)
  assert(player.cellX == beforeTurnX and player.cellY == beforeTurnY
      and player.facing == "up",
    "ordinary UP input did not face the solid wall-local fissure")
  local fx, fy = player:facingCell()
  local fissure = game.overworld:npcAtCell(fx, fy)
  assert(fx == 35 and fy == 1 and fissure and fissure.passable == true
      and fissure.def and fissure.def.text == "TEXT_KA_HEVO_FISSURE_RED",
    "physical Route22 route did not face the fissure anchor")
  U.tap(game, "a")
  U.wait(18)
  local fissureBox = game.stack:top()
  local textRows = {}
  for _, page in ipairs(fissureBox and fissureBox.pages or {}) do
    for _, line in ipairs(page) do textRows[#textRows + 1] = line end
  end
  local fissureText = table.concat(textRows, " ")
  assert(fissureText:find("Riss", 1, true)
      or fissureText:find("Spalt", 1, true)
      or fissureText:find("fissure", 1, true),
    "physical fissure input was captured by another Route22 interaction")
  if edition == "red" then
    assert(fissureText:find("Feldforscher", 1, true)
        or fissureText:find("field researcher", 1, true),
      "RED Route22 did not reach its sealed rightful fissure response")
  else
    assert(fissureText:find("nicht deiner", 1, true)
        or fissureText:find("not yours", 1, true),
      "BLUE/YELLOW Route22 did not preserve RED-fissure identity denial")
  end
  assert(game.overworld.map.id == "ROUTE_22",
    "fissure coexistence check warped without an explicit YES")
  assert(U.shot(game, dir .. "/05_fissure_coexistence.png"),
    "Route22 fissure coexistence capture failed")

  Runtime.emit = originalEmit
  local out = assert(io.open(dir .. "/driver_result.txt", "wb"),
    "could not write Route22 package result")
  out:write(table.concat({
    "status=PASS",
    "scope=ROUTE22-REMATCH-ALT",
    "edition=" .. edition,
    "variant=" .. variant,
    "player_character=" .. expectedCharacter.player,
    "rival_character=" .. expectedCharacter.rival,
    "first_loss_reload_win=PASS",
    "late_loss_reload_win=PASS",
    "fissure_coexistence=PASS",
    "generic_rematch_conflict=NONE",
    "native_save_reload=4/4",
    "physical_battle_states=4/4",
    "physical_blackouts=2/2",
    "source_save_sha256=" .. receipts.source_save_sha256,
    "engine_payload_sha256=" .. receipts.engine_payload_sha256,
    "authority_package_sha256=" .. receipts.authority_package_sha256,
    "deutsch_package_sha256=" .. receipts.deutsch_package_sha256,
    "package_gate_receipt_sha256="
      .. receipts.package_gate_receipt_sha256,
    "fail=0",
  }, "\n"), "\n")
  out:close()
  print(("ROUTE22 PACKAGE PASS edition=%s variant=%s "
      .. "first+late loss/reload/win fissure/no-generic")
    :format(edition, variant))
  love.event.quit(0)
end
