-- Minimal installed-package closure receipt for the final same-hash gate.
--
-- This driver deliberately inspects the live package loader rather than the
-- source tree.  The Python orchestrator supplies the exact expected and
-- forbidden package IDs for one physically isolated closure.
return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source runs are not package proof")

  local function sha(name)
    local value = os.getenv(name)
    assert(type(value) == "string" and #value == 64
        and value:match("^[0-9a-f]+$"),
      name .. " must be a lowercase SHA256 receipt")
    return value
  end

  local expected = assert(os.getenv("KA_EXPECT_ALLOWED"),
    "KA_EXPECT_ALLOWED is required")
  local absent = assert(os.getenv("KA_EXPECT_ABSENT"),
    "KA_EXPECT_ABSENT is required")
  local closure = assert(os.getenv("KA_CLOSURE_PROFILE"),
    "KA_CLOSURE_PROFILE is required")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local loaded = assert(game.mods and game.mods.mods,
    "installed mod registry is unavailable")

  local expectedCount = 0
  for id in expected:gmatch("[^,]+") do
    expectedCount = expectedCount + 1
    assert(loaded[id], "expected installed package is missing: " .. id)
  end
  for id in absent:gmatch("[^,]+") do
    assert(not loaded[id], "forbidden closure package leaked in: " .. id)
  end

  local runtimeSource = tostring(love.filesystem.getSource() or "")
  local authorityPath = tostring(assert(loaded.kanto_ascendant,
    "installed Authority package is missing").path or "")
  for _, path in ipairs({ runtimeSource, authorityPath }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not package evidence: " .. path)
  end

  local hashes = {
    engine_payload_sha256 = sha("KA_ENGINE_PAYLOAD_SHA256"),
    authority_package_sha256 = sha("KA_AUTHORITY_PACKAGE_SHA256"),
    deutsch_package_sha256 = sha("KA_DEUTSCH_PACKAGE_SHA256"),
    package_gate_receipt_sha256 = sha("KA_PACKAGE_GATE_RECEIPT_SHA256"),
  }

  assert(os.execute(("mkdir -p %q"):format(dir)) == 0,
    "could not create closure receipt directory")
  local out = assert(io.open(dir .. "/driver_result.txt", "wb"))
  out:write("status=PASS\n")
  out:write("scope=FINAL-SAME-HASH-CLOSURE\n")
  out:write("closure=", closure, "\n")
  out:write("expected_packages=", tostring(expectedCount), "\n")
  for key, value in pairs(hashes) do out:write(key, "=", value, "\n") end
  out:close()
  love.event.quit(0)
end
