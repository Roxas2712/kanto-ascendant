-- Installs the exact RC archive through the launcher's production importer.
-- Run in an isolated LOVE identity; this intentionally replaces only the
-- trainer_rematch folder inside that identity.

return function()
  local U = dofile("tests/drivers/util.lua")
  local LauncherMods = require("src.mods.LauncherMods")
  local archive = assert(os.getenv("KA65_RC_ZIP"), "KA65_RC_ZIP is required")
  local expectedVersion = os.getenv("KA65_EXPECT_VERSION") or "6.5.0"
  local expectFireRed = os.getenv("KA65_EXPECT_FIRERED") ~= "false"

  local pass, fail = 0, 0
  local function check(label, ok, detail)
    if ok then
      pass = pass + 1
      U.log("PASS", label)
    else
      fail = fail + 1
      U.log("FAIL", label, detail or "")
    end
  end

  local installed, result = LauncherMods.installZip(archive, {
    replace = true,
    expectId = "trainer_rematch",
  })
  check("launcher importer accepts the archive",
    installed == true and result == "trainer_rematch", result)

  local manifest = love.filesystem.read("mods/trainer_rematch/manifest.json")
  check("installed manifest is readable", type(manifest) == "string")
  check("installed archive identifies Kanto Ascendant " .. expectedVersion,
    manifest and manifest:find(
      '"version"%s*:%s*"' .. expectedVersion:gsub("%.", "%%.") .. '"')
      ~= nil)
  local hasFireRed = love.filesystem.getInfo(
    "mods/trainer_rematch/modern_storage_ui.lua", "file") ~= nil
  local hasHub = love.filesystem.getInfo(
    "mods/trainer_rematch/ascendant_features.lua", "file") ~= nil
  check(expectFireRed
      and "installed archive contains the FireRed UI"
      or "rollback archive removes the 6.5 FireRed UI",
    hasFireRed == expectFireRed)
  check(expectFireRed
      and "installed archive contains the Ascendant feature hub"
      or "rollback archive removes the 6.5 feature hub",
    hasHub == expectFireRed)

  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
end
