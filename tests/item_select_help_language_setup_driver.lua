-- Native package-language precondition for UI-001 English cells.
return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source runs are not package proof")
  assert(os.getenv("QA_ITEM_HELP_LANGUAGE") == "en",
    "language setup is only valid for English UI cells")
  local GameVersion = require("src.core.GameVersion")
  local LauncherMods = require("src.mods.LauncherMods")
  local SaveData = require("src.core.SaveData")
  local edition = GameVersion.get()
  local languageId = ({
    red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb",
  })[edition]
  assert(languageId, "UI language setup requires Red, Blue, or Yellow")
  local row = assert(game.mods and game.mods.mods
    and game.mods.mods[languageId], "edition language package is missing")
  assert(row.enabled == true and row.state ~= "disabled",
    "English setup did not begin with the German package enabled")
  local api = assert(game.mods.exports and game.mods.exports.kanto_ascendant)
  assert(api.language() == "de", "German package was not live before setup")
  assert(LauncherMods.setEnabled(languageId, false, edition) == true,
    "native launcher could not disable the edition language package")
  assert(SaveData.modEnabled(SaveData.loadOptions(), languageId,
      SaveData.modScope(edition)) == false,
    "native language disable did not persist")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  assert(os.execute(("mkdir -p %q"):format(dir)) == 0)
  local out = assert(io.open(dir .. "/language_setup_result.txt", "wb"))
  out:write("status=PASS\nscope=UI-001-LANGUAGE-SETUP\n")
  out:write("edition=", edition, "\nlocale=en\ndisabled_package=", languageId, "\n")
  out:close()
  love.event.quit(0)
end
