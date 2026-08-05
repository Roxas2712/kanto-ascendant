-- Real LOVE/launcher package smoke test.
--
-- Required environment:
--   KA_OLD_PACKAGE     older Kanto Ascendant .zip
--   KA_CURRENT_PACKAGE current .modpkg
--
-- The driver switches to a dedicated LOVE identity before installing. It
-- first imports the old release, then replaces it through the launcher's
-- exact .zip/.modpkg path and verifies the manager sees 6.0.1.

return function()
  assert(love and love.filesystem, "launcher QA requires LOVE")
  local qaIdentity = os.getenv("POKEPORT_IDENTITY")
    or "kanto-ascendant-launcher-qa"
  love.filesystem.setIdentity(qaIdentity)
  assert(love.filesystem.getIdentity() == qaIdentity,
    "could not select the isolated launcher QA identity")

  local oldPackage = assert(os.getenv("KA_OLD_PACKAGE"),
    "KA_OLD_PACKAGE is required")
  local currentPackage = assert(os.getenv("KA_CURRENT_PACKAGE"),
    "KA_CURRENT_PACKAGE is required")
  local LauncherMods = require("src.mods.LauncherMods")

  -- Read the launcher's actual writable install tree directly. A source-tree
  -- QA run may have another development copy mounted earlier in PhysFS, which
  -- can legitimately shadow LauncherMods.list() without changing where
  -- installZip wrote the selected package.
  local function installedVersion()
    local path = love.filesystem.getSaveDirectory()
      .. "/mods/trainer_rematch/manifest.json"
    local file = assert(io.open(path, "rb"),
      "launcher did not create " .. path)
    local manifest = file:read("*a")
    file:close()
    return manifest:match('"version"%s*:%s*"([^"]+)"'), manifest
  end

  local ok, id = LauncherMods.installZip(oldPackage, {
    replace = true, expectId = "trainer_rematch",
  })
  assert(ok and id == "trainer_rematch",
    "older package import failed: " .. tostring(id))
  local oldVersion = installedVersion()
  assert(oldVersion == "5.4.2",
    "launcher did not expose installed 5.4.2: " .. tostring(oldVersion))

  ok, id = LauncherMods.installZip(currentPackage, {
    replace = true, expectId = "trainer_rematch",
  })
  assert(ok and id == "trainer_rematch",
    "6.0.1 .modpkg update failed: " .. tostring(id))
  local currentVersion, manifest = installedVersion()
  assert(currentVersion == "6.0.1",
    "launcher did not expose installed 6.0.1: " .. tostring(currentVersion))
  assert(manifest:find('"version"%s*:%s*"6%.0%.1"'),
    "installed tree does not contain the current manifest")

  print(("LAUNCHER PACKAGE QA PASS: 5.4.2 -> %s (%s)")
    :format(currentVersion, love.filesystem.getSaveDirectory()))
end
