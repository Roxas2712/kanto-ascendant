-- Real-engine receipt for the Ascendant 6.5 default-deny mod stack.
return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source runs are not package proof")
  local expected = assert(os.getenv("KA_EXPECT_ALLOWED"), "KA_EXPECT_ALLOWED required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("ka65%-mod%-allowlist"),
    "refusing to run outside a dedicated allowlist identity")
  local byId = {}
  local rows = game.mods:status()
  local loadedById = {}
  for _, row in ipairs(rows.available or {}) do
    assert(byId[row.id] == nil, "duplicate loader status id: " .. tostring(row.id))
    byId[row.id] = row
  end
  for _, row in ipairs(rows.loaded or {}) do
    loadedById[row.id] = row
  end
  local ascendant = assert(byId.kanto_ascendant, "Ascendant status missing")
  assert(ascendant.state == "loaded", "Ascendant did not win boot")

  local expectedIds = {}
  for id in expected:gmatch("[^,]+") do expectedIds[id] = true end
  for id in pairs(expectedIds) do
    local row = assert(byId[id], "approved package missing: " .. id)
    assert(row.state == "loaded", id .. " was not loaded: " .. tostring(row.state))
  end
  local replaced = assert(byId.trainer_rematch, "replacement fixture missing")
  assert(replaced.state == "replaced"
      and replaced.replacedBy == "kanto_ascendant"
      and replaced.error == nil,
    "known integrated mod was not replaced")
  local unknown = assert(byId.ka65_unknown_probe, "unknown fixture missing")
  assert(unknown.state == "not_approved"
      and unknown.replacedBy == "kanto_ascendant"
      and unknown.error == nil,
    "unknown mod was not blocked")

  -- The loader's available registry intentionally retains blocked/replaced
  -- manifests for diagnostics.  The execution registry must not contain
  -- either fixture, and neither entry may publish an export or load error.
  assert(not loadedById.trainer_rematch,
    "replacement fixture leaked into loaded mod registry")
  assert(not loadedById.ka65_unknown_probe,
    "unknown fixture leaked into loaded mod registry")
  assert(not (game.mods.exports and game.mods.exports.trainer_rematch),
    "replacement fixture leaked an export")
  assert(not (game.mods.exports and game.mods.exports.ka65_unknown_probe),
    "unknown fixture leaked an export")

  for _, err in ipairs(rows.errors or {}) do
    local text = tostring(err)
    assert(not text:find("kanto_ascendant", 1, true)
      and not text:find("ka65_unknown_probe", 1, true),
      "allowlist boot emitted a policy error: " .. text)
  end

  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  assert(os.execute(("mkdir -p %q"):format(dir)) == 0,
    "could not create receipt directory")
  local f = assert(io.open(dir .. "/driver_result.txt", "wb"))
  f:write("status=PASS\nscope=MOD-ALLOWLIST-NEGATIVE-PACKAGE\n")
  f:write("ASCENDANT loaded\n")
  for id in pairs(expectedIds) do f:write(id, " loaded\n") end
  f:write("trainer_rematch replaced\nka65_unknown_probe not_approved\n")
  f:close()
  love.event.quit(0)
end
