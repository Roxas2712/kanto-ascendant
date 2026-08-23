-- Phase-4 Yellow coverage: gameplay role remains Yellow while the selected
-- identity drives only player/rival presentation.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local Commands = require("src.script.Commands")
local PikachuFollower = require("src.world.PikachuFollower")
local Data = T.fixtures.load()
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/kanto_ascendant"
local oldVersion = GameVersion.get()
GameVersion.set("yellow")

local assetSink = assert(loadfile(modPath
  .. "/tests/headless_modkit_asset_sink.lua"))()(T, modPath, {
  bridgeLove = true,
  derivedPrefix = "save/mod-derived/kanto_ascendant/",
})
local sdkOpts = { data = Data }
if modPath:sub(1, 1) == "/" then sdkOpts.root = "/" end
local loaded, run = pcall(T.sdk.loadMod, modPath, sdkOpts)
if not loaded then
  assetSink.cleanup()
  GameVersion.set(oldVersion)
  error(run, 0)
end
T.eq(#run.errors, 0, "Kanto Ascendant loads in a Yellow runtime")
local runtimeModPath = assert(run.mod and run.mod.path,
  "SDK exposes the loader-owned runtime mod path")
local characters = assert(run.loader.exports.kanto_ascendant.extendedCharacters)
T.eq(characters.characterStyle(), "crystal",
  "Yellow also receives CRYSTAL CHARS as the default style")

T.eq(characters.isEnabled(), false,
  "pre-6.5 Yellow visual compatibility does not create story identity")
T.eq(characters.trainerCardProfileFit(nil, 56, 56), nil,
  "unselected vanilla Yellow keeps its edition-native Trainer Card placement")
T.eq(run.loader.hooks:call("player.sprite", function(path) return path end,
  "yellow-vanilla-back.png", { side = "back", kind = "battle" }),
  runtimeModPath .. "/assets/characters/crystal_chars/red_back.png",
  "pre-6.5 Yellow applies the default Red visual family without save mutation")

local red = characters.select("RED")
T.eq(red.rival_character, "BLUE", "Yellow Red keeps Blue in the rival role")
T.eq(run.loader.hooks:call("player.sprite", function(path) return path end,
  "yellow-back.png", { side = "back", kind = "battle" }),
  runtimeModPath .. "/assets/characters/crystal_chars/red_back.png",
  "extended Red Yellow resolves through the default Crystal player seam")

local blue = characters.select("BLUE")
T.eq(blue.rival_character, "GREEN", "Yellow Blue maps Green to rival identity")
T.eq(characters.getPlayerSprite("overworld").sprite,
  "SPRITE_KA_CRYSTAL_BLUE_WALK",
  "Yellow Blue uses Blue's default Crystal overworld mapping")
T.eq(characters.getRivalSprite("rivalPortrait").path,
  "assets/characters/crystal_chars/green_front.png",
  "Yellow Green rival uses the clean 64px Casey portrait")

local green = characters.select("GREEN")
T.eq(green.rival_character, "RED", "Yellow Green maps Red to rival identity")
T.eq(characters.getPlayerGender(), "FEMALE", "Yellow Green keeps trainer gender identity")
T.eq(characters.getThirdCharacter(), "BLUE", "Yellow Green preserves the third role")
T.eq(characters.getState().rivalStarter, nil,
  "character state never owns Yellow's Eevee progression field")

local seen = {}
local originalStartBattle = Commands.start_battle
Commands.start_battle = function(ctx, kind, class, party)
  seen.kind, seen.class, seen.party = kind, class, party
  ctx.lastBattleResult = "win"
end
local yellowBattle = { save = { rivalStarter = 2 }, game = { data = { field = {} } } }
Commands.rival_battle(yellowBattle, "OPP_RIVAL1", 4)
Commands.start_battle = originalStartBattle
T.eq(seen.kind, "trainer", "Yellow first rival battle keeps trainer role")
T.eq(seen.class, "OPP_RIVAL1", "Yellow first rival battle keeps rival battle ID")
T.eq(seen.party, 2, "Yellow Eevee party selection uses rivalStarter, not player identity")
T.eq(yellowBattle.save.rivalStarter, 1,
  "Yellow lab-win evolution progression remains the engine's role state")

local followerSave = {
  flags = { EVENT_GOT_STARTER = true },
  party = { { species = "PIKACHU", hp = 10 } }, pikachuHappiness = 90,
}
T.eq(PikachuFollower.starterInParty(followerSave, true).species, "PIKACHU",
  "Yellow Pikachu follower identity remains the starter Pokémon")
PikachuFollower.modifyHappiness(followerSave, "WALKING")
T.eq(followerSave.pikachuHappiness, 92,
  "Yellow Pikachu reactions continue independently of selected trainer identity")

GameVersion.set(oldVersion)
run.release()
assetSink.cleanup()
T.finish("extended_characters_yellow_test")
