-- Production-import smoke that is self-contained so it can run against the
-- shipped gen1recomp .love archive, which does not bundle tests/drivers/util.

return function()
  local archive = assert(os.getenv("KA65_RC_ZIP"), "KA65_RC_ZIP is required")
  local LauncherMods = require("src.mods.LauncherMods")
  local ok, id = LauncherMods.installZip(archive, {
    replace = true,
    expectId = "kanto_ascendant",
  })
  print("[live-import]", ok and "PASS" or "FAIL", tostring(id))
  love.event.quit(ok and id == "kanto_ascendant" and 0 or 1)
end
