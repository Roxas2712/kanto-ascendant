-- Installs the package under test into the existing isolated Voxel UAT
-- identity while preserving its Dramatic Shape and follower configuration.

local function fail(message)
  io.stderr:write("VOXEL UAT PACKAGE INSTALL FAIL: "
    .. tostring(message) .. "\n")
  love.event.quit(1)
end

function love.load()
  local ok, err = xpcall(function()
    assert(love.filesystem.getIdentity()
        == "kanto-ascendant-signals-voxel-uat",
      "wrong isolated identity")
    local engine = assert(os.getenv("POKEPORT_ENGINE_ROOT"),
      "POKEPORT_ENGINE_ROOT is required")
    local packagePath = assert(os.getenv("KA_SIGNALS_PACKAGE"),
      "KA_SIGNALS_PACKAGE is required")
    package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
      .. package.path
    local LauncherMods = require("src.mods.LauncherMods")
    local installed, result = LauncherMods.installZip(packagePath, {
      replace = true,
      expectId = "trainer_rematch",
    })
    assert(installed and result == "trainer_rematch",
      "package import failed: " .. tostring(result))
    local version
    for _, row in ipairs(LauncherMods.list()) do
      if row.id == "trainer_rematch" then version = row.version break end
    end
    assert(version == "6.0.4",
      "installed unexpected version " .. tostring(version))
    print("VOXEL UAT PACKAGE INSTALL PASS: " .. version)
  end, debug.traceback)
  if not ok then return fail(err) end
  love.event.quit(0)
end
