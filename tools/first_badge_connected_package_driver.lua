-- DRV-EARLY-BALANCE-FIRST-BADGE-PACKAGE
--
-- Connected installed-package acceptance for Red, Blue and Yellow:
-- title-screen NEW GAME -> Oak escort -> real starter/lab rival -> parcel
-- and Pokédex -> real Route 22 rival -> Viridian Forest -> real Brock win ->
-- Boulder Badge/TM34 -> native save/load.  The route is executed exclusively
-- by live input and BattleState; this wrapper never grants progress itself.
return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")

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
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local utilPath = assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL packaged harness path is required")
  local harnessRoot = assert(os.getenv("GEN1RECOMP_DIR"),
    "GEN1RECOMP_DIR packaged harness root is required")
  for _, path in ipairs({ utilPath, harnessRoot, dir }) do
    assert(path:sub(1, 1) == "/"
        and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true),
      "source/worktree path is not package evidence: " .. path)
  end
  local routePath = harnessRoot .. "/tools/first_badge_connected_route.lua"
  local runnerPath = harnessRoot .. "/tests/drivers/route.lua"
  for _, path in ipairs({ routePath, runnerPath }) do
    local handle = assert(io.open(path, "rb"),
      "packaged connected-route support is missing: " .. path)
    handle:close()
  end
  local U = dofile(utilPath)

  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local edition = GameVersion.get()
  local expectedEdition = assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION is required")
  assert(edition == expectedEdition
      and (edition == "red" or edition == "blue" or edition == "yellow"),
    "connected first-badge acceptance must use requested Red/Blue/Yellow")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")
  assert(identity:find("first%-badge") and not identity:find("%.worktrees"),
    "connected first-badge acceptance requires an isolated package identity")
  local slot = "slot65firstbadge_" .. edition
  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve the connected first-badge native save slot")

  U.wait(12)
  local loaded = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local installed = assert(loaded.kanto_ascendant,
    "installed Authority package is missing")
  local runtimeSource = tostring(love.filesystem.getSource() or "")
  local authorityPath = tostring(installed.path or "")
  for _, path in ipairs({ runtimeSource, authorityPath }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not installed-package evidence: " .. path)
  end

  local api = assert(game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "current Kanto Ascendant export missing")
  assert(api.legacyJourney and api.postgame and api.runRules,
    "fresh-story acceptance exports are incomplete")

  -- Instrument the public battle event stream without changing a roster,
  -- result or reward.  The three required victories are classified by the
  -- physical map on which their real BattleState starts.
  local trace = {
    labStarted = 0, labWon = 0,
    route22Started = 0, route22Won = 0,
    brockStarted = 0, brockWon = 0,
  }
  local labels = setmetatable({}, { __mode = "k" })
  local originalEmit = Runtime.emit
  Runtime.emit = function(name, payload)
    if name == "battle.started" and payload and payload.battle then
      local battle = payload.battle
      local mapId = game.overworld and game.overworld.map
        and game.overworld.map.id
      local label
      if mapId == "OAKS_LAB" and battle.oppClass == "OPP_RIVAL1" then
        label = "lab"
        trace.labStarted = trace.labStarted + 1
      elseif mapId == "ROUTE_22" and battle.oppClass == "OPP_RIVAL1" then
        label = "route22"
        trace.route22Started = trace.route22Started + 1
      elseif mapId == "PEWTER_GYM" and battle.oppClass == "OPP_BROCK" then
        label = "brock"
        trace.brockStarted = trace.brockStarted + 1
      end
      if label then labels[battle] = label end
    elseif name == "battle.ended" and payload and payload.battle then
      local label = labels[payload.battle]
      if label == "lab" and payload.result == "win" then
        trace.labWon = trace.labWon + 1
      elseif label == "route22" and payload.result == "win" then
        trace.route22Won = trace.route22Won + 1
      elseif label == "brock" and payload.result == "win" then
        trace.brockWon = trace.brockWon + 1
      end
    end
    return originalEmit(name, payload)
  end

  -- The general route interpreter is a frozen engine QA support file.  Feed
  -- it only the bounded first-badge route.  Override its optional diagnostics
  -- so every artifact lives in this cell's package-evidence directory and no
  -- ambient developer resume/memory switch can change the fresh run.
  local originalGetenv = os.getenv
  local controlled = {
    POKEPORT_ROUTE_ATTEMPTS = "5",
    POKEPORT_ROUTE_CHECKPOINT = dir .. "/route_checkpoint.lua",
    POKEPORT_ROUTE_LOG = dir .. "/route.log",
    POKEPORT_ROUTE_MEMORY = dir .. "/route_memory.lua",
    POKEPORT_ROUTE_RESUME = "0",
    POKEPORT_ROUTE_STOP_ON_STUCK = "0",
    POKEPORT_ROUTE_STUCK_REPEATS = "10",
    POKEPORT_ROUTE_STUCK_REPORT = dir .. "/route_stuck_report.txt",
    POKEPORT_ROUTE_WATCHDOG = "1",
  }
  os.getenv = function(name)
    if controlled[name] ~= nil then return controlled[name] end
    return originalGetenv(name)
  end

  local ok, problem = xpcall(function()
    package.loaded["tests.drivers.util"] = U
    package.loaded["tests.drivers.bot_route"] = dofile(routePath)
    local runConnectedRoute = dofile(runnerPath)
    runConnectedRoute(game)
  end, debug.traceback)
  os.getenv = originalGetenv
  Runtime.emit = originalEmit
  assert(ok, problem)

  local flags = assert(game.save and game.save.flags,
    "connected route returned without a live save")
  local inventory = assert(game.save.inventory,
    "connected route returned without an inventory")
  assert(flags.EVENT_FOLLOWED_OAK_INTO_LAB == true,
    "Oak escort did not complete through real Pallet input")
  assert(flags.EVENT_GOT_STARTER == true,
    "starter selection did not complete through the live lab script")
  assert(flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB == true
      and trace.labStarted >= 1 and trace.labWon >= 1,
    "the real Oak lab rival BattleState was not won")
  assert(flags.EVENT_GOT_POKEDEX == true,
    "parcel/Pokedex story chain did not complete")
  assert(flags.EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE == true
      and trace.route22Started >= 1 and trace.route22Won >= 1,
    "the real first Route 22 rival BattleState was not won")
  assert(flags.EVENT_BEAT_BROCK == true
      and trace.brockStarted >= 1 and trace.brockWon >= 1,
    "the real Brock BattleState was not won")
  assert(inventory.BOULDERBADGE == 1,
    "Brock victory did not award exactly one Boulder Badge")
  assert((inventory.TM_BIDE or 0) >= 1,
    "Brock victory did not award TM34 Bide")
  local mapBeforeReload = game.overworld and game.overworld.map
    and game.overworld.map.id
  assert(mapBeforeReload == "PEWTER_CITY" or mapBeforeReload == "PEWTER_GYM",
    "connected route did not finish at Pewter: " .. tostring(mapBeforeReload))

  local expectedStarter = edition == "yellow"
    and { PIKACHU = true, RAICHU = true }
    or { SQUIRTLE = true, WARTORTLE = true, BLASTOISE = true }
  local function hasStarter(save)
    for _, mon in ipairs(save.party or {}) do
      if expectedStarter[mon.species] then return true end
    end
    return false
  end
  assert(hasStarter(game.save),
    "the edition's real starter family was lost before Brock")
  assert(not api.legacyJourney.isActive(game.save)
      and not api.postgame.hasHallOfFame(game.save),
    "fresh connected campaign leaked Legacy/NG+ or Hall of Fame state")
  local rules = api.runRules.state(game.save)
  assert(rules and rules.preset == "standard"
      and rules.randomizer.enabled == false
      and rules.nuzlocke.mode == "off",
    "fresh connected campaign did not retain normal run rules")

  assert(game:writeSave(), "connected first-badge native save write failed")
  local reloaded, recovered = SaveData.load(edition)
  assert(reloaded and recovered == nil,
    "connected first-badge native save load failed")
  game:restoreSave(reloaded, recovered)
  U.wait(12)

  flags = assert(game.save.flags, "reloaded first-badge flags missing")
  inventory = assert(game.save.inventory,
    "reloaded first-badge inventory missing")
  assert(flags.EVENT_FOLLOWED_OAK_INTO_LAB == true
      and flags.EVENT_GOT_STARTER == true
      and flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB == true
      and flags.EVENT_GOT_POKEDEX == true
      and flags.EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE == true
      and flags.EVENT_BEAT_BROCK == true,
    "connected first-badge story flags did not survive native reload")
  assert(inventory.BOULDERBADGE == 1 and (inventory.TM_BIDE or 0) >= 1,
    "Boulder Badge/TM34 did not survive native reload")
  assert(hasStarter(game.save),
    "edition starter did not survive native reload")
  assert(not api.legacyJourney.isActive(game.save)
      and not api.postgame.hasHallOfFame(game.save),
    "native reload introduced Legacy/NG+ or Hall of Fame state")

  local out = assert(io.open(dir .. "/driver_result.txt", "wb"),
    "could not write connected first-badge package result")
  local rows = {
    "status=PASS",
    "scope=EARLY-BALANCE-FIRST-BADGE",
    "edition=" .. edition,
    "connected_new_game=1/1",
    "oak_escort=1/1",
    "lab_battle_state=1/1",
    "pokedex=1/1",
    "route22_battle_state=1/1",
    "pewter_reached=1/1",
    "brock_battle_state=1/1",
    "boulder_badge=1/1",
    "tm_bide=1/1",
    "native_save_reload=1/1",
    "no_ngplus_leak=1/1",
    "connected_first_badge=1/1",
    "lab_battles_started=" .. trace.labStarted,
    "route22_battles_won=" .. trace.route22Won,
    "brock_battles_won=" .. trace.brockWon,
    "engine_payload_sha256=" .. receipts.engine_payload_sha256,
    "authority_package_sha256=" .. receipts.authority_package_sha256,
    "deutsch_package_sha256=" .. receipts.deutsch_package_sha256,
    "package_gate_receipt_sha256="
      .. receipts.package_gate_receipt_sha256,
    "fail=0",
  }
  out:write(table.concat(rows, "\n"), "\n")
  out:close()
  print(("FIRST BADGE PACKAGE RESULT edition=%s pass=14 fail=0")
    :format(edition))
  love.event.quit(0)
end
