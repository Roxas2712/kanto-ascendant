-- Catch-tutorial trainer ownership regression.
--
-- `player.sprite` normally means the selected RED/BLUE/GREEN identity, but
-- the engine deliberately passes an already-resolved scripted NPC back pic
-- for the Viridian old-man tutorial (`demo`) and Yellow's Oak tutorial
-- (`oakDemo`). Kanto Ascendant must not replace either tutorial owner.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
local originalVersion = GameVersion.get()
local selectedEdition = os.getenv("ASCENDANT_TEST_EDITION") or "red"
local selectedLanguage = os.getenv("ASCENDANT_TEST_LANGUAGE") or "en"
assert(selectedEdition == "red" or selectedEdition == "blue"
    or selectedEdition == "yellow",
  "ASCENDANT_TEST_EDITION must be red, blue or yellow")
assert(selectedLanguage == "en" or selectedLanguage == "de",
  "ASCENDANT_TEST_LANGUAGE must be en or de")

local germanMarker = {
  red = modPath .. "/tests/fixtures/language_mods/deutsch",
  blue = modPath .. "/tests/fixtures/language_mods/deutsch-blau",
  yellow = modPath .. "/tests/fixtures/language_mods/deutsch-gelb",
}

local function checkMatrix(edition, language)
  GameVersion.set(edition)
  local paths = { modPath }
  if language == "de" then paths[#paths + 1] = germanMarker[edition] end
  local run = T.sdk.loadMods(paths, { data = T.fixtures.load() })
  T.eq(#run.errors, 0,
    edition .. "/" .. language .. " tutorial-owner fixture loads")
  local characters = assert(
    run.loader.exports.kanto_ascendant.extendedCharacters)
  run.loader.modOptions.kanto_ascendant = {
    character_sprite_style = "ascendant",
    trainer_portrait_style = "crystal_hd",
  }

  for _, portraitStyle in ipairs({ "crystal_hd", "original" }) do
    run.loader.modOptions.kanto_ascendant.trainer_portrait_style = portraitStyle
    for _, identity in ipairs({ "RED", "BLUE", "GREEN" }) do
      characters.select(identity)
      for _, renderer in ipairs({ "native", "voxel" }) do
        for _, tutorial in ipairs({
          { flag = "demo", path = "engine/oldman-demo-back.png" },
          { flag = "oakDemo", path = "engine/oak-demo-back.png" },
        }) do
          local ctx = {
            side = "back", kind = "battle", renderer = renderer,
            trueColor = false,
          }
          ctx[tutorial.flag] = true
          local actual = run.loader.hooks:call("player.sprite",
            function(path) return path end, tutorial.path, ctx)
          local label = table.concat({
            edition, language, portraitStyle, identity, renderer,
            tutorial.flag,
          }, "/")
          T.eq(actual, tutorial.path,
            label .. " preserves the engine-selected tutorial owner")
          T.eq(ctx.trueColor, false,
            label .. " preserves the tutorial owner's palette contract")
        end
      end

      local normalCtx = {
        side = "back", kind = "battle", renderer = "native",
        trueColor = false,
      }
      local normal = run.loader.hooks:call("player.sprite",
        function(path) return path end, "engine/normal-player-back.png",
        normalCtx)
      T.neq(normal, "engine/normal-player-back.png",
        edition .. "/" .. language .. "/" .. portraitStyle .. "/"
          .. identity .. " still resolves the selected normal player")
    end
  end
  run.release()
end

checkMatrix(selectedEdition, selectedLanguage)

GameVersion.set(originalVersion)
T.finish("extended character tutorial owner "
  .. selectedEdition .. "/" .. selectedLanguage)
