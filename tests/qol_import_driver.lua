-- Installs the exact RC archive through the launcher's production importer.
-- Run in an isolated LOVE identity; this intentionally replaces only the
-- trainer_rematch folder inside that identity.

return function()
  local U = dofile("tests/drivers/util.lua")
  local LauncherMods = require("src.mods.LauncherMods")
  local archive = assert(os.getenv("KA65_RC_ZIP"), "KA65_RC_ZIP is required")

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
  check("launcher importer accepts the RC archive",
    installed == true and result == "trainer_rematch", result)

  local manifest = love.filesystem.read("mods/trainer_rematch/manifest.json")
  check("installed manifest is readable", type(manifest) == "string")
  check("installed archive identifies Kanto Ascendant 6.5.0",
    manifest and manifest:find('"version"%s*:%s*"6%.5%.0"') ~= nil)
  check("installed archive contains the FireRed UI",
    love.filesystem.getInfo("mods/trainer_rematch/modern_storage_ui.lua",
      "file") ~= nil)
  check("installed archive contains the Ascendant feature hub",
    love.filesystem.getInfo("mods/trainer_rematch/ascendant_features.lua",
      "file") ~= nil)

  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
end
