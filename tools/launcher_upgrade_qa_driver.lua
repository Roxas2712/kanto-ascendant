-- Real LOVE/launcher package smoke test.
--
-- Required environment:
--   KA_OLD_PACKAGE     older Kanto Ascendant .zip
--   KA_CURRENT_PACKAGE current .modpkg
--
-- The driver switches to a dedicated LOVE identity before installing. It
-- first imports the accepted old-ID release, then imports the current 6.5
-- package through the launcher's exact .zip/.modpkg path. Both IDs are
-- inspected so this catches duplicate-ID and upgrade regressions.

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
  local function installedVersion(modId)
    local path = love.filesystem.getSaveDirectory()
      .. "/mods/" .. modId .. "/manifest.json"
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
  local oldVersion = installedVersion("trainer_rematch")

  ok, id = LauncherMods.installZip(currentPackage, {
    replace = true, expectId = "kanto_ascendant",
  })
  assert(ok and id == "kanto_ascendant",
    "6.5.0 RC10 package import failed: " .. tostring(id))
  local currentVersion, manifest = installedVersion("kanto_ascendant")
  assert(currentVersion == "6.5.0",
    "launcher did not expose installed 6.5.0: " .. tostring(currentVersion))
  assert(manifest:find('"id"%s*:%s*"kanto_ascendant"'),
    "installed tree does not contain the permanent manifest id")
  assert(manifest:find('"version"%s*:%s*"6%.5%.0"'),
    "installed tree does not contain the current manifest")
  assert(manifest:find('"trainer_rematch"', 1, true),
    "RC10 manifest does not declare the old identity conflict")

  print(("LAUNCHER PACKAGE QA PASS: trainer_rematch %s + "
      .. "kanto_ascendant %s (%s)")
    :format(oldVersion, currentVersion, love.filesystem.getSaveDirectory()))
end
