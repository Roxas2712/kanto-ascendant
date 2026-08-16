-- Minimal real-LÖVE launcher-import smoke test for the 6.0.8 ID migration.
-- It deliberately installs 6.0.7 first, then imports 6.0.8 without replace.

function love.load()
  local engine = assert(os.getenv("KA_ENGINE_ROOT"), "KA_ENGINE_ROOT required")
  package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
    .. package.path

  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY required")
  love.filesystem.setIdentity(identity)

  local oldPackage = assert(os.getenv("KA_OLD_PACKAGE"),
    "KA_OLD_PACKAGE required")
  local currentPackage = assert(os.getenv("KA_CURRENT_PACKAGE"),
    "KA_CURRENT_PACKAGE required")
  local LauncherMods = require("src.mods.LauncherMods")

  local ok, id = LauncherMods.installZip(oldPackage, {
    replace = true, expectId = "trainer_rematch",
  })
  assert(ok and id == "trainer_rematch",
    "6.0.7 setup import failed: " .. tostring(id))

  ok, id = LauncherMods.installZip(currentPackage, {
    expectId = "kanto_ascendant",
  })
  assert(ok and id == "kanto_ascendant",
    "renamed package import failed: " .. tostring(id))

  local found = {}
  for _, row in ipairs(LauncherMods.list()) do found[row.id] = row end
  assert(found.trainer_rematch, "old ID disappeared during new import")
  assert(found.kanto_ascendant, "new permanent ID is not installed")
  assert(found.trainer_rematch.status == "conflict",
    "old ID is not conflict-protected")
  assert(found.kanto_ascendant.status == "conflict",
    "new ID is not conflict-protected")

  print("LAUNCHER ID MIGRATION PASS: old and new packages import separately; conflict guard active")
  love.event.quit(0)
end
