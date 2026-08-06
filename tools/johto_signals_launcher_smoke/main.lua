-- Real launcher/update smoke test for Kanto Ascendant 6.0.
--
-- Required:
--   POKEPORT_ENGINE_ROOT=/absolute/path/to/gen1recomp
--   KA_SIGNALS_PACKAGE=/absolute/path/to/kanto-ascendant-6.0.5.modpkg
--
-- Optional but required for the final release gate:
--   KA_SIGNALS_OLD_PACKAGE=/absolute/path/to/kanto-ascendant-5.3.0.modpkg
--   KA_SIGNALS_OLD_VERSION=5.3.0

local function fail(message)
  io.stderr:write("JOHTO SIGNALS LAUNCHER QA FAIL: "
    .. tostring(message) .. "\n")
  love.event.quit(1)
end

local function assertMissing(path)
  assert(not love.filesystem.getInfo(path),
    "frozen Lab content leaked into installation: " .. path)
end

function love.load()
  local ok, err = xpcall(function()
    assert(love.filesystem.getIdentity() == "kanto-ascendant-signals-uat",
      "launcher QA is not using its isolated LOVE identity")

    local engine = assert(os.getenv("POKEPORT_ENGINE_ROOT"),
      "POKEPORT_ENGINE_ROOT is required")
    local packagePath = assert(os.getenv("KA_SIGNALS_PACKAGE"),
      "KA_SIGNALS_PACKAGE is required")
    local oldPackage = os.getenv("KA_SIGNALS_OLD_PACKAGE")
    local oldVersion = os.getenv("KA_SIGNALS_OLD_VERSION") or "5.3.0"
    package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
      .. package.path

    local LauncherMods = require("src.mods.LauncherMods")
    local id = "trainer_rematch"

    if oldPackage and oldPackage ~= "" then
      local oldOk, oldResult = LauncherMods.installZip(oldPackage, {
        replace = true,
        expectId = id,
      })
      assert(oldOk and oldResult == id,
        "5.3 package import failed: " .. tostring(oldResult))
      local found
      for _, row in ipairs(LauncherMods.list()) do
        if row.id == id then found = row break end
      end
      assert(found and found.version == oldVersion,
        ("upgrade base is %s, expected Kanto Ascendant %s")
          :format(tostring(found and found.version), oldVersion))
    end

    local installedOk, result = LauncherMods.installZip(packagePath, {
      replace = true,
      expectId = id,
    })
    assert(installedOk and result == id,
      "6.0 .modpkg import failed: " .. tostring(result))

    local installed
    for _, row in ipairs(LauncherMods.list()) do
      if row.id == id then installed = row break end
    end
    assert(installed, "launcher did not discover trainer_rematch")
    assert(installed.version == "6.0.5",
      ("launcher exposed version %s, expected 6.0.5")
        :format(tostring(installed.version)))
    assert(installed.status == "ok",
      "installed package is not launcher-ready: "
        .. tostring(installed.statusDetail))

    -- The following native-save builder boots straight past the launcher.
    -- Enable only this package inside the guarded UAT identity so its
    -- production exports are present on that very first scripted boot.
    local SaveData = require("src.core.SaveData")
    local CacheFs = require("src.import.CacheFs")
    local Json = require("src.link.Json")
    local options = SaveData.loadOptions()
    options.mods = {}
    local engineMount = "__signals_uat_engine"
    local scanned = CacheFs.withMounted(engine, engineMount, function()
      local bundledRoot = engineMount .. "/mods"
      for _, folder in ipairs(
          love.filesystem.getDirectoryItems(bundledRoot) or {}) do
        local raw = love.filesystem.read(
          bundledRoot .. "/" .. folder .. "/manifest.json")
        if raw then
          local manifest = Json.decode(raw)
          if type(manifest) == "table" and type(manifest.id) == "string" then
            options.mods[manifest.id] = false
          end
        end
      end
      return true
    end)
    assert(scanned,
      "could not mount engine source for bundled-mod isolation")
    for _, row in ipairs(LauncherMods.list()) do
      options.mods[row.id] = row.id == id
    end
    options.mods[id] = true
    options.modOptions = options.modOptions or {}
    options.modOptions[id] = options.modOptions[id] or {}
    options.modOptions[id].language = "en"
    options.modOptions[id].johto_signals_enable = true
    options.modOptions[id].johto_signals_start = "quest"
    options.modOptions[id].mythic_signals = true
    assert(SaveData.saveOptions(options),
      "could not enable 6.0 in isolated UAT options")

    local prefix = "mods/" .. id .. "/"
    for _, relative in ipairs({
      "manifest.json",
      "johto_encounter_levels.lua",
      "johto_signals.lua",
      "johto_signals_content.lua",
      "johto_signals_hub.lua",
      "johto_signals_state.lua",
      "johto_signals_wilds.lua",
      "mythic_signals.lua",
    }) do
      assert(love.filesystem.getInfo(prefix .. relative),
        "installed tree is missing " .. relative)
    end

    for _, relative in ipairs({
      "assets/guests",
      "assets/orange_trainers",
      "fairy_research.lua",
      "orange_archipelago.lua",
      "orange_puzzles.lua",
      "starfall_content.lua",
      "starfall_debug.lua",
      "starfall_orange_maps.lua",
      "starfall_state.lua",
      "tests",
      "tools/starfall_e2e_save_driver.lua",
    }) do
      assertMissing(prefix .. relative)
    end

    print(("JOHTO SIGNALS LAUNCHER QA PASS: %s (%s)")
      :format(installed.version, love.filesystem.getSaveDirectory()))
  end, debug.traceback)
  if not ok then return fail(err) end
  love.event.quit(0)
end
