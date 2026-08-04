-- Real LOVE/launcher package smoke test.
--
-- Required environment:
--   KA_OLD_PACKAGE     older Kanto Ascendant .zip
--   KA_CURRENT_PACKAGE current .modpkg
--
-- The driver switches to a dedicated LOVE identity before installing. It
-- first imports the old release, then replaces it through the launcher's
-- exact .zip/.modpkg path and verifies the manager sees 5.2.2.

return function()
  assert(love and love.filesystem, "launcher QA requires LOVE")
  love.filesystem.setIdentity("kanto-ascendant-launcher-qa")
  assert(love.filesystem.getIdentity() == "kanto-ascendant-launcher-qa",
    "could not select the isolated launcher QA identity")

  local oldPackage = assert(os.getenv("KA_OLD_PACKAGE"),
    "KA_OLD_PACKAGE is required")
  local currentPackage = assert(os.getenv("KA_CURRENT_PACKAGE"),
    "KA_CURRENT_PACKAGE is required")
  local LauncherMods = require("src.mods.LauncherMods")

  local function installedVersion()
    for _, row in ipairs(LauncherMods.list()) do
      if row.id == "trainer_rematch" then return row.version, row end
    end
  end

  local ok, id = LauncherMods.installZip(oldPackage, {
    replace = true, expectId = "trainer_rematch",
  })
  assert(ok and id == "trainer_rematch",
    "older package import failed: " .. tostring(id))
  local oldVersion = installedVersion()
  assert(oldVersion == "3.1.0",
    "launcher did not expose installed 3.1.0: " .. tostring(oldVersion))

  ok, id = LauncherMods.installZip(currentPackage, {
    replace = true, expectId = "trainer_rematch",
  })
  assert(ok and id == "trainer_rematch",
    "5.2.2 .modpkg update failed: " .. tostring(id))
  local currentVersion, row = installedVersion()
  assert(currentVersion == "5.2.2",
    "launcher did not expose installed 5.2.2: " .. tostring(currentVersion))
  assert(row.status == "ok",
    "updated package is not launcher-ready: " .. tostring(row.statusDetail))

  local manifest = assert(love.filesystem.read(
    "mods/trainer_rematch/manifest.json"))
  assert(manifest:find('"version"%s*:%s*"5%.2%.2"'),
    "installed tree does not contain the current manifest")

  print(("LAUNCHER PACKAGE QA PASS: 3.1.0 -> %s (%s)")
    :format(currentVersion, love.filesystem.getSaveDirectory()))
end
