-- Real-LÖVE acceptance for Kanto Ascendant's manifest conflict guard.
-- The test launcher installs exactly one fixture mod beside Ascendant.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local ManagerState = require("src.mods.ManagerState")

  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  local externalId = assert(os.getenv("POKEPORT_EXPECT_CONFLICT_ID"),
    "expected conflict id required")
  assert(identity:find("conflict%-guard"),
    "refusing to run outside a dedicated conflict-guard identity")
  assert(GameVersion.get() == "red", "conflict QA requires Red cache")
  U.wait(5)

  local expectedPath = os.getenv("POKEPORT_EXPECT_MOD_PATH")
  local rows = game.mods:status()
  local byId = {}
  for _, row in ipairs(rows.available or {}) do byId[row.id] = row end
  local ascendant = assert(byId.kanto_ascendant, "Ascendant status missing")
  local external = assert(byId[externalId], "fixture status missing: " .. externalId)
  assert(ascendant.state == "conflict",
    "Ascendant was not disabled by " .. externalId)
  assert(external.state == "loaded",
    "external package did not remain loaded: " .. externalId)
  assert(ascendant.error and ascendant.error:find("conflicts with " .. externalId,
    1, true), "Ascendant error did not name " .. externalId)
  if expectedPath then
    assert(ascendant.path == expectedPath,
      "wrong candidate path: " .. tostring(ascendant.path))
  end

  local foundLog = false
  for _, err in ipairs(rows.errors or {}) do
    if tostring(err):find("kanto_ascendant", 1, true)
        and tostring(err):find(externalId, 1, true) then
      foundLog = true
      break
    end
  end
  assert(foundLog, "boot error log did not name " .. externalId)

  local shotDir = os.getenv("SHOT_DIR") or "/tmp/conflict-guard"
  local manager = ManagerState.new(game)
  game.stack:push(manager)
  manager.currentMod = manager.byId.kanto_ascendant
  manager:goTo("errors")
  U.wait(2)
  assert(U.shot(game, shotDir .. "/" .. externalId .. "-error-log.png"),
    "error-log screenshot failed")

  -- KA-INTERNAL: CONFLICT-TOGGLE-001
  game.mods:setEnabled("kanto_ascendant", false)
  game.save.options.mods = game.save.options.mods or {}
  game.save.options.mods.kanto_ascendant = false
  manager.screen, manager.backStack = "list", {}
  manager:refresh()
  local disabledAscendant = assert(manager.byId.kanto_ascendant)
  assert(disabledAscendant.enabled == false,
    "could not stage Ascendant as disabled")
  manager:beginToggle(disabledAscendant)
  assert(manager.overlay and manager.overlay.kind == "ok",
    "selection did not open the conflict overlay")
  local notice = table.concat(manager.overlay.lines or {}, "|")
  assert(notice:find("CONFLICTS WITH", 1, true)
      and notice:find("DISABLE IT FIRST", 1, true),
    "selection notice is incomplete: " .. notice)
  U.wait(2)
  assert(U.shot(game, shotDir .. "/" .. externalId .. "-selection-block.png"),
    "selection-block screenshot failed")

  U.log("CONFLICT GUARD REAL E2E PASS", externalId,
    "boot disable error log manager selection overlay")
  love.event.quit(0)
end
