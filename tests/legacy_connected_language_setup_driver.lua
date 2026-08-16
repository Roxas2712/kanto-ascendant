-- Package-only language precondition for the connected Legacy Lab matrix.
--
-- The frozen base/deutsch closure always contains the edition-matched German
-- package.  German cells prove that native enabled package.  English cells
-- disable it through the launcher's persisted per-edition control and let the
-- following process boot the same closure in genuine English.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "base_deutsch",
    "connected Legacy language setup requires base/deutsch")
  local locale = assert(os.getenv("QA_LANGUAGE"), "QA_LANGUAGE is required")
  assert(locale == "en" or locale == "de",
    "QA_LANGUAGE must be exactly en or de")

  local function requiredSha(name)
    local value = os.getenv(name)
    assert(type(value) == "string" and #value == 64
        and value:match("^[0-9a-f]+$"),
      name .. " must be a lowercase SHA256 receipt")
    return value
  end
  requiredSha("KA_ENGINE_PAYLOAD_SHA256")
  requiredSha("KA_AUTHORITY_PACKAGE_SHA256")
  requiredSha("KA_DEUTSCH_PACKAGE_SHA256")
  requiredSha("KA_PACKAGE_GATE_RECEIPT_SHA256")

  local GameVersion = require("src.core.GameVersion")
  local LauncherMods = require("src.mods.LauncherMods")
  local SaveData = require("src.core.SaveData")
  local edition = GameVersion.get()
  local languageId = ({
    red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb",
  })[edition]
  assert(languageId, "Legacy language setup requires Red, Blue, or Yellow")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")
  assert(identity == ("ka65-final-legacy-connected-%s-%s")
      :format(edition, locale),
    "Legacy language setup requires its exact connected-cell identity")

  local loaded = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local authority = assert(loaded.kanto_ascendant,
    "installed Authority package is missing")
  local language = assert(loaded[languageId],
    "edition-matched German package is not physically installed")
  assert(language.enabled == true and language.state ~= "disabled",
    "fresh connected-language identity did not start with German enabled")
  local expected = { kanto_ascendant = true, [languageId] = true }
  local count = 0
  for id in pairs(loaded) do
    count = count + 1
    assert(expected[id], "unexpected package leaked into base/deutsch: " .. id)
  end
  assert(count == 2,
    "connected Legacy base/deutsch closure must contain exactly two packages")

  for _, path in ipairs({ tostring(love.filesystem.getSource() or ""),
      tostring(authority.path or ""), tostring(language.path or "") }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not installed-package evidence: " .. path)
  end

  local exports = assert(game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Authority export is unavailable")
  assert(exports.language and exports.language() == "de",
    "enabled edition language package did not produce German")
  if locale == "en" then
    assert(LauncherMods.setEnabled(languageId, false, edition) == true,
      "native launcher failed to disable the edition language package")
    local options = SaveData.loadOptions()
    assert(SaveData.modEnabled(options, languageId,
        SaveData.modScope(edition)) == false,
      "native per-edition language disable did not persist")
  end

  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  assert(dir:sub(1, 1) == "/" and not dir:find(".worktrees", 1, true)
      and not dir:find("/Documents/Recompile/", 1, true),
    "source/worktree output is not package evidence")
  local out = assert(io.open(dir .. "/language_setup_result.txt", "wb"))
  out:write("status=PASS\n")
  out:write("scope=LEGACY-CONNECTED-LANGUAGE-SETUP\n")
  out:write("edition=", edition, "\n")
  out:write("locale=", locale, "\n")
  out:write("language_package=", languageId, "\n")
  out:write("native_enabled_state=", locale == "de" and "enabled" or "disabled",
    "\n")
  out:close()
  love.event.quit(0)
end
