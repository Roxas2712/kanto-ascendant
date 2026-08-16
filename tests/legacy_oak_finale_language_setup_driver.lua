-- Package-only language precondition for the Legacy Oak finale matrix.
--
-- Every reviewed closure physically contains the edition-matched German
-- translation package.  Kanto Ascendant deliberately follows the enabled
-- game-language package, so an English acceptance cannot be manufactured by
-- flipping a private mod option after boot.  The EN cells therefore run this
-- one native launcher pass first.  It disables only the matching translation
-- for this edition and persists that ordinary launcher choice; the next LÖVE
-- process then boots the exact same package closure in genuine English.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "battle_art",
    "Oak language setup requires the reviewed Battle Art closure")
  assert(os.getenv("QA_LANGUAGE") == "en",
    "Oak language setup is only valid for QA_LANGUAGE=en")
  local renderer = assert(os.getenv("QA_RENDERER"),
    "QA_RENDERER is required")
  assert(renderer == "2D" or renderer == "BATTLE_ART_FULL",
    "QA_RENDERER must be exactly 2D or BATTLE_ART_FULL")

  local GameVersion = require("src.core.GameVersion")
  local LauncherMods = require("src.mods.LauncherMods")
  local SaveData = require("src.core.SaveData")
  local version = GameVersion.get()
  local languageId = ({
    red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb",
  })[version]
  assert(languageId, "Oak language setup requires Red, Blue, or Yellow")

  local function requiredSha(name)
    local value = os.getenv(name)
    assert(type(value) == "string" and value:match("^[0-9a-f]+$")
        and #value == 64, name .. " must be a lowercase SHA256 receipt")
    return value
  end
  requiredSha("KA_ENGINE_PAYLOAD_SHA256")
  requiredSha("KA_AUTHORITY_PACKAGE_SHA256")
  requiredSha("KA_DEUTSCH_PACKAGE_SHA256")
  requiredSha("KA_PACKAGE_GATE_RECEIPT_SHA256")
  local battleArtSha = requiredSha("KA_BATTLE_ART_PACKAGE_SHA256")
  assert(battleArtSha ==
      "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e",
    "Battle Art package is not the reviewed immutable 1.8.3 archive")

  local loaded = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local language = assert(loaded[languageId],
    "edition-matched German package is not physically installed")
  assert(language.enabled == true and language.state ~= "disabled",
    "fresh EN precondition did not begin with the German package enabled")
  local authority = assert(loaded.kanto_ascendant,
    "installed Authority package is missing")
  local battleArt = assert(loaded.BATTLE_ART_VOXEL_FORK,
    "installed reviewed Battle Art package is missing")
  local expected = {
    kanto_ascendant = true,
    [languageId] = true,
    BATTLE_ART_VOXEL_FORK = true,
  }
  local count = 0
  for id in pairs(loaded) do
    count = count + 1
    assert(expected[id], "unexpected package leaked into Oak closure: " .. id)
  end
  assert(count == 3, "Oak Battle Art closure must contain exactly three packages")

  local function packagePath(value)
    value = tostring(value or "")
    assert(value ~= "" and not value:find(".worktrees", 1, true)
        and not value:find("/Documents/Recompile/", 1, true)
        and not value:find("/tests/", 1, true)
        and not value:find("/tools/", 1, true),
      "source/worktree path is not package evidence: " .. value)
  end
  packagePath(love.filesystem.getSource())
  packagePath(authority.path)
  packagePath(language.path)
  packagePath(battleArt.path)

  local exports = assert(game.mods.exports and
    game.mods.exports.kanto_ascendant, "Authority export is unavailable")
  assert(exports.language and exports.language() == "de",
    "enabled edition language package did not produce German before setup")
  assert(LauncherMods.setEnabled(languageId, false, version) == true,
    "native launcher failed to disable the edition language package")
  local options = SaveData.loadOptions()
  assert(SaveData.modEnabled(options, languageId,
      SaveData.modScope(version)) == false,
    "native per-edition language disable did not persist")

  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  assert(os.execute(("mkdir -p %q"):format(dir)) == 0,
    "could not create Oak language setup receipt directory")
  local out = assert(io.open(dir .. "/language_setup_result.txt", "wb"))
  out:write("status=PASS\n")
  out:write("scope=RC65-OAK-FINALE-LANGUAGE-SETUP\n")
  out:write("edition=", version, "\n")
  out:write("locale=en\n")
  out:write("disabled_package=", languageId, "\n")
  out:close()
  love.event.quit(0)
end
