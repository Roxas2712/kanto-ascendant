-- Bounded real-LÖVE probe for the exact Run-F Oak Lab checkpoint.
--
-- This file is deliberately NOT part of the final same-hash plan or frozen
-- harness.  A host-side runner must first copy a stable, quiescent snapshot
-- of Run F's fused identity to the exact non-planned identity below, then run
-- this driver against an isolated copy of Run F's base/deutsch Red closure.
-- The driver never teleports, restores, saves, or assigns a player position:
-- title CONTINUE and the one rightward step both travel through normal input.
--
-- Required environment:
--   POKEPORT_IDENTITY=ka65-probe-oak-follower-passable-runf-20260813-01
--   POKEPORT_VERSION=red
--   POKEPORT_TOUCH=0
--   POKEPORT_DRIVER=<absolute path to this file>
--   KA_OAK_PROBE_OUTPUT_DIR=<fresh absolute temp directory>
--   KA_OAK_PROBE_SOURCE_SAVE_SHA256=<64 lowercase hex chars>
--   KA_OAK_PROBE_CLOSURE_TREE_SHA256=<64 lowercase hex chars>
--
-- The receipt is armed as FAIL before any title or field input.  An assertion,
-- crash, missing screenshot, wrong identity, or premature process exit can
-- therefore never leave a stale PASS result behind.

local EXPECTED_IDENTITY =
  "ka65-probe-oak-follower-passable-runf-20260813-01"
local SCHEMA = "ka-oaks-lab-passable-follower-real-probe/v1"

local function envRequired(name)
  local value = os.getenv(name)
  assert(type(value) == "string" and value ~= "", name .. " is required")
  return value
end

local OUTPUT_DIR = envRequired("KA_OAK_PROBE_OUTPUT_DIR")
local RESULT_PATH = OUTPUT_DIR .. "/driver_result.txt"
local BEFORE_PATH = OUTPUT_DIR .. "/01_before_right_input.png"
local AFTER_PATH = OUTPUT_DIR .. "/02_after_right_input.png"
local SOURCE_SAVE_SHA256 = envRequired("KA_OAK_PROBE_SOURCE_SAVE_SHA256")
local CLOSURE_TREE_SHA256 = envRequired("KA_OAK_PROBE_CLOSURE_TREE_SHA256")

assert(SOURCE_SAVE_SHA256:match("^[0-9a-f]+$")
    and #SOURCE_SAVE_SHA256 == 64,
  "KA_OAK_PROBE_SOURCE_SAVE_SHA256 must be lowercase SHA-256")
assert(CLOSURE_TREE_SHA256:match("^[0-9a-f]+$")
    and #CLOSURE_TREE_SHA256 == 64,
  "KA_OAK_PROBE_CLOSURE_TREE_SHA256 must be lowercase SHA-256")

local function oneLine(value)
  return tostring(value):gsub("[\r\n=]", "_")
end

local receiptState = {
  schema = SCHEMA,
  status = "FAIL",
  fail = 1,
  phase = "module-load",
  expected_identity = EXPECTED_IDENTITY,
  source_save_sha256 = SOURCE_SAVE_SHA256,
  closure_tree_sha256 = CLOSURE_TREE_SHA256,
}

local function writeReceipt(extra)
  local rows = {}
  for key, value in pairs(receiptState) do rows[key] = value end
  for key, value in pairs(extra or {}) do rows[key] = value end
  local order = {
    "schema", "status", "fail", "phase", "reason",
    "expected_identity", "env_identity", "love_identity",
    "source_save_sha256", "closure_tree_sha256",
    "edition", "map", "before_player", "right_entity_count",
    "right_entity_id", "right_entity_pikachu_follower",
    "right_entity_passable", "right_entity_wilds_follower",
    "right_entity_ambient", "collision_occupied_nil",
    "right_input_via_live_queue", "after_player", "moved_onto_7_2",
    "before_png", "after_png",
  }
  local body = {}
  local emitted = {}
  for _, key in ipairs(order) do
    if rows[key] ~= nil then
      body[#body + 1] = key .. "=" .. oneLine(rows[key])
      emitted[key] = true
    end
  end
  local rest = {}
  for key in pairs(rows) do
    if not emitted[key] then rest[#rest + 1] = key end
  end
  table.sort(rest)
  for _, key in ipairs(rest) do
    body[#body + 1] = key .. "=" .. oneLine(rows[key])
  end
  local tmp = RESULT_PATH .. ".tmp"
  local file = assert(io.open(tmp, "wb"), "cannot stage probe receipt")
  file:write(table.concat(body, "\n"), "\n")
  file:close()
  assert(os.rename(tmp, RESULT_PATH), "cannot promote probe receipt")
end

local function arm(phase, extra)
  receiptState.status = "FAIL"
  receiptState.fail = 1
  receiptState.phase = phase
  receiptState.reason = nil
  for key, value in pairs(extra or {}) do receiptState[key] = value end
  writeReceipt()
end

local function requireProbe(condition, phase, reason, extra)
  if condition then return condition end
  receiptState.status = "FAIL"
  receiptState.fail = 1
  receiptState.phase = phase
  receiptState.reason = reason
  for key, value in pairs(extra or {}) do receiptState[key] = value end
  writeReceipt()
  error(reason, 0)
end

-- These helpers intentionally match tests/drivers/util.lua's synthetic
-- physical-input seam: pressQueue is drained by Input:step, state models the
-- held direction, and the coroutine yields before the live Game/Overworld
-- update consumes it.  No Player or Overworld movement method is called here.
local function waitFrames(count)
  for _ = 1, count do coroutine.yield() end
end

local function tap(game, button)
  table.insert(game.input.pressQueue, button)
  waitFrames(1)
  game.input.state[button] = false
end

local function holdRightUntilLanding(game, targetX, targetY, maxFrames)
  local injected = 0
  for _ = 1, maxFrames do
    local player = game.overworld and game.overworld.player
    if player and player.cellX == targetX and player.cellY == targetY
        and not player.moving then
      break
    end
    table.insert(game.input.pressQueue, "right")
    game.input.state.right = true
    injected = injected + 1
    coroutine.yield()
  end
  game.input.state.right = false
  waitFrames(1)
  return injected
end

local function capture(game, path)
  game.capturePath = path
  for _ = 1, 180 do
    if not game.capturePath then break end
    coroutine.yield()
  end
  requireProbe(game.capturePath == nil, "screenshot-timeout",
    "renderer did not consume screenshot request", { screenshot = path })
  waitFrames(1)
  local file = io.open(path, "rb")
  requireProbe(file ~= nil, "screenshot-missing",
    "screenshot did not reach disk", { screenshot = path })
  local size = file:seek("end")
  file:close()
  requireProbe(type(size) == "number" and size > 0, "screenshot-empty",
    "screenshot is empty", { screenshot = path })
  return size
end

local function entityId(entity)
  local def = entity and entity.def
  return (def and (def.name or def.id or def.sprite))
    or (entity and (entity.id or entity.spriteId)) or "unknown"
end

local function atCell(entity, x, y)
  return entity and entity.cellX == x and entity.cellY == y
end

local function fieldIdle(game, mapId)
  local ow = game.overworld
  local player = ow and ow.player
  local runner = ow and ow.runner
  return ow ~= nil and game.stack:top() == ow
    and ow.map and ow.map.id == mapId
    and player and not player.moving and not player.inputLocked
    and #(ow.scriptMoves or {}) == 0
    and not (runner and runner.isRunning and runner:isRunning())
end

-- Arm a fail-closed receipt as soon as all required output provenance exists,
-- before this module returns its driver coroutine and before any input occurs.
writeReceipt()

return function(game)
  arm("identity-audit")
  local envIdentity = os.getenv("POKEPORT_IDENTITY")
  local loveIdentity = love.filesystem.getIdentity()
  requireProbe(envIdentity == EXPECTED_IDENTITY, "identity-audit",
    "POKEPORT_IDENTITY is not the isolated non-planned probe identity", {
      env_identity = envIdentity or "missing",
      love_identity = loveIdentity or "missing",
    })
  requireProbe(loveIdentity == EXPECTED_IDENTITY, "identity-audit",
    "LÖVE mounted a different fused identity", {
      env_identity = envIdentity,
      love_identity = loveIdentity or "missing",
    })
  requireProbe(os.getenv("POKEPORT_VERSION") == "red", "identity-audit",
    "probe must boot the Red cache", {
      env_identity = envIdentity,
      love_identity = loveIdentity,
      edition = os.getenv("POKEPORT_VERSION") or "missing",
    })
  receiptState.env_identity = envIdentity
  receiptState.love_identity = loveIdentity
  receiptState.edition = "red"

  -- Reach CONTINUE with normal title input, but never press A blindly.  The
  -- unique localized CONTINUE row must remain the selected actionable row at
  -- the instant A is injected.  A second ordinary A confirms ContinueInfo;
  -- any migration/report overlay is acknowledged through the same A seam.
  arm("title-continue-selection")
  local Strings = require("src.core.Strings")
  local continueLabel = Strings("CONTINUE")
  local titleMenu, continueRow
  for _ = 1, 180 do
    local top = game.stack:top()
    if top and top.titleUiBox and type(top.items) == "table" then
      local matches = 0
      for index, item in ipairs(top.items) do
        if type(item) == "table" and item.label == continueLabel
            and type(item.onSelect) == "function" then
          matches = matches + 1
          continueRow = index
        end
      end
      requireProbe(matches == 1, "title-continue-selection",
        "title must expose exactly one actionable localized CONTINUE row", {
          continue_matches = matches,
        })
      titleMenu = top
      break
    end
    tap(game, "start")
    waitFrames(5)
  end
  requireProbe(titleMenu ~= nil and continueRow ~= nil,
    "title-continue-selection", "could not expose the title CONTINUE menu")

  for _ = 1, #titleMenu.items do
    if titleMenu.index == continueRow then break end
    tap(game, "down")
    waitFrames(2)
  end
  local selected = game.stack:top()
  local selectedItem = selected and selected.items
    and selected.items[continueRow]
  requireProbe(selected == titleMenu and selected.index == continueRow
      and selectedItem and selectedItem.label == continueLabel
      and type(selectedItem.onSelect) == "function",
    "title-continue-selection",
    "verified CONTINUE row changed before selection")
  tap(game, "a")
  waitFrames(4)
  local info = game.stack:top()
  requireProbe(info ~= nil and info ~= titleMenu and info.titleUiBox ~= nil,
    "continue-info", "CONTINUE did not open the native info window")
  tap(game, "a")

  arm("continue-to-field")
  for _ = 1, 720 do
    if fieldIdle(game, "OAKS_LAB") then break end
    if game.overworld and game.stack:top() ~= game.overworld then tap(game, "a") end
    waitFrames(2)
  end
  requireProbe(fieldIdle(game, "OAKS_LAB"), "continue-to-field",
    "native CONTINUE did not settle on idle OAKS_LAB")
  waitFrames(24) -- ordinary map-enter/mod follower lifecycle only
  requireProbe(fieldIdle(game, "OAKS_LAB"), "field-lifecycle",
    "OAKS_LAB stopped being idle during follower lifecycle")

  local ow = game.overworld
  local player = ow.player
  receiptState.map = ow.map.id
  receiptState.before_player = player.cellX .. "," .. player.cellY
  requireProbe(player.cellX == 6 and player.cellY == 2,
    "exact-run-f-state", "snapshot did not load the exact Run-F cell (6,2)")
  requireProbe(player.facing == "down", "exact-run-f-state",
    "snapshot did not preserve Run-F facing=down")
  requireProbe(ow.map:isWalkableCell(7, 2), "target-tile-audit",
    "OAKS_LAB (7,2) is not a walkable floor tile")

  arm("right-entity-audit")
  local rightEntities, seenRight = {}, {}
  -- The engine follower is normally present in both lists; alternate
  -- follower adapters may keep it in only one.  Inspect the same union that
  -- live rendering/navigation can observe and de-duplicate by identity.
  for _, list in ipairs({ ow.entities or {}, ow.npcs or {} }) do
    for _, entity in ipairs(list) do
      if entity ~= player and atCell(entity, 7, 2)
          and not seenRight[entity] then
        seenRight[entity] = true
        rightEntities[#rightEntities + 1] = entity
      end
    end
  end
  receiptState.right_entity_count = #rightEntities
  requireProbe(#rightEntities == 1, "right-entity-audit",
    "expected exactly one live entity at OAKS_LAB (7,2)", {
      right_entity_count = #rightEntities,
    })
  local right = rightEntities[1]
  receiptState.right_entity_id = entityId(right)
  receiptState.right_entity_pikachu_follower = right.pikachuFollower == true and 1 or 0
  receiptState.right_entity_passable = right.passable == true and 1 or 0
  receiptState.right_entity_wilds_follower = right.wildsFollower == true and 1 or 0
  receiptState.right_entity_ambient =
    (right.ambientSpecies ~= nil or right.wildsAmbientPokemon == true) and 1 or 0
  requireProbe(right.pikachuFollower == true, "right-entity-audit",
    "right-side entity is not the live PikachuFollower carrier")
  requireProbe(right.passable == true, "right-entity-audit",
    "right-side follower is not passable=true")
  requireProbe(right.ambientSpecies == nil
      and right.wildsAmbientPokemon ~= true, "right-entity-audit",
    "right-side entity is an ambient blocking Pokemon, not the follower")

  local Collision = require("src.world.Collision")
  local blocker = Collision.occupied(ow.entities, 7, 2, player)
  receiptState.collision_occupied_nil = blocker == nil and 1 or 0
  requireProbe(blocker == nil, "collision-audit",
    "Collision.occupied reports a blocker at the passable follower cell", {
      collision_blocker = blocker and entityId(blocker) or "nil",
    })

  arm("before-screenshot")
  capture(game, BEFORE_PATH)
  receiptState.before_png = "01_before_right_input.png"
  requireProbe(fieldIdle(game, "OAKS_LAB")
      and player.cellX == 6 and player.cellY == 2,
    "before-screenshot", "state drifted while capturing the before frame")
  requireProbe(atCell(right, 7, 2) and right.passable == true,
    "before-screenshot", "right-side follower moved or lost passability")

  -- The proof action: one held RIGHT button through Input:step and the live
  -- OverworldController.  Stop the hold on the first completed landing so a
  -- fast render cannot run on to (8,2).  No collision or movement function is
  -- invoked directly by this driver.
  arm("live-right-input")
  local inputFrames = holdRightUntilLanding(game, 7, 2, 48)
  receiptState.right_input_via_live_queue = 1
  receiptState.right_input_frames = inputFrames
  receiptState.after_player = player.cellX .. "," .. player.cellY
  receiptState.moved_onto_7_2 =
    (player.cellX == 7 and player.cellY == 2) and 1 or 0
  requireProbe(player.cellX == 7 and player.cellY == 2 and not player.moving,
    "live-right-input",
    "normal right input did not land the player on follower cell (7,2)")
  requireProbe(game.stack:top() == ow and ow.map.id == "OAKS_LAB",
    "live-right-input", "right input left the live Oak Lab overworld")

  arm("after-screenshot")
  capture(game, AFTER_PATH)
  receiptState.after_png = "02_after_right_input.png"
  requireProbe(player.cellX == 7 and player.cellY == 2 and not player.moving,
    "after-screenshot", "player drifted after landing on (7,2)")

  receiptState.status = "PASS"
  receiptState.fail = 0
  receiptState.phase = "complete"
  receiptState.reason = nil
  writeReceipt()
end
