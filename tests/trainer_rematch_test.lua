-- Trainer Rematch headless suite. Run from the engine checkout:
--   POKEPORT_DATA_DIR=tests/fixture_data luajit mods/trainer_rematch/tests/trainer_rematch_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = T.fixtures.load()
Data.audio = Data.audio or {}
Data.audio.songs = Data.audio.songs or {}
Data.audio.mapSongs = Data.audio.mapSongs or {}
for _, song in ipairs({ "Music_Cinnabar", "Music_Dungeon1" }) do
  Data.audio.songs[song] = Data.audio.songs[song]
    or { address = 0, bank = 0 }
end

-- The engine's tiny three-species fixture intentionally omits Kanto. Seed the
-- one native template Gorochu extends so this suite can exercise the complete
-- guest registration and evolution edge without requiring ROM-derived data.
Data.pokemon.RAICHU = {
  id = "RAICHU", index = 26, dex = 26, name = "RAICHU",
  types = { "ELECTRIC" },
  baseStats = {
    hp = 60, attack = 90, defense = 55, speed = 100, special = 90,
  },
  catchRate = 75, baseExp = 122,
  level1Moves = {}, growthRate = "MEDIUM_FAST", tmhm = {},
  learnset = {}, evolutions = {},
  spriteFront = "tests/fixture_data/assets/fixmon_a_front.png",
  spriteBack = "tests/fixture_data/assets/fixmon_a_back.png",
  frontSize = 6,
  dexEntry = {
    kind = "MOUSE", heightFt = 2, heightIn = 7, weight = 660,
    text = "A test Raichu.",
  },
}
for index, moveId in ipairs({
  "THUNDERSHOCK", "BITE", "THUNDER_WAVE",
  "AGILITY", "THUNDERBOLT", "THUNDER",
}) do
  Data.moves[moveId] = {
    id = moveId, index = 100 + index, name = moveId:gsub("_", " "),
    type = moveId == "BITE" and "NORMAL" or "ELECTRIC",
    power = (moveId == "THUNDER_WAVE" or moveId == "AGILITY")
      and 0 or 40,
    accuracy = 100, pp = 20, effect = "NO_ADDITIONAL_EFFECT",
  }
end

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/trainer_rematch"
local function packagedPath(runtimePath)
  local relative = type(runtimePath) == "string"
    and runtimePath:match("(assets/.*)$")
  return relative and (modPath .. "/" .. relative) or runtimePath
end
local run = T.sdk.loadMod(modPath, { data = Data })
T.eq(#run.errors, 0, "loads clean")
T.eq(run.mod.manifest.name, "Kanto Ascendant",
  "the full expansion uses its new visible name")
T.eq(run.mod.manifest.id, "trainer_rematch",
  "the stable internal id preserves existing save data")
local ex = run.loader.exports.trainer_rematch
T.neq(ex, nil, "exports reachable")
T.eq(ex.dexKindCompat.MEW.en, "NEW SPECIE",
  "Mew restores its canonical English Pokédex category")
T.eq(ex.dexKindCompat.MEW.de, "NEUE ART",
  "Mew restores its canonical compact German Pokédex category")
T.eq(ex.dexKindCompat.MEWTWO.de, "GENMUTANT",
  "Mewtwo no longer inherits the German bird-category corruption")

-- --------------------------------------------------- Gen-II audio ownership

do
  T.neq(ex.johtoAudio, nil,
    "the late Johto cry compatibility seam is exported")
  local bundledCryCount = 0
  for id, bundled in pairs(ex.johtoAudio.bundled) do
    T.eq(bundled.available, true,
      id .. " has its bundled legacy cry in the release package")
    T.eq(type(bundled.file), "string",
      id .. " exposes a playable bundled cry path")
    bundledCryCount = bundledCryCount + 1
  end
  T.eq(bundledCryCount, 100,
    "all one hundred Johto species have bundled legacy cries")
  local externalTotodileCry = { file = "external/gen2/totodile.ogg" }
  local baseCries = Data.audio and Data.audio.cries or {}
  Data.audio = { cries = {} }
  for id, def in pairs(baseCries) do Data.audio.cries[id] = def end
  Data.pokemon.TOTODILE = {}
  Data.audio.cries.TOTODILE = externalTotodileCry
  local fallbackCount, externalCount = ex.johtoAudio.install({ data = Data })
  T.eq(fallbackCount, 99,
    "Ascendant fills only the 99 Johto cries that remain unavailable")
  T.eq(externalCount, 1,
    "one externally registered Johto cry is recognized")
  T.eq(Data.audio.cries.TOTODILE.file, externalTotodileCry.file,
    "an external Totodile cry wins over Ascendant's bundled legacy cry")
  T.neq(Data.audio.cries.CHIKORITA, nil,
    "a missing Johto cry receives Ascendant's bundled legacy cry")
  T.eq(Data.audio.cries.NATU.file:find(
      "assets/audio/johto_cries/177.ogg", 1, true) ~= nil, true,
    "Natu resolves to its species-authentic bundled Gen-II cry")
  T.eq(Data.pokemon.TOTODILE.cry, "TOTODILE",
    "late audio binding connects the species to the preserved external cry")
  T.eq(ex.johtoAudio.battleScaleBack, 1,
    "all full-size Johto player backs use native 1x scale")
  local localizedDexData = { pokemon = {}, text = {} }
  for _, id in ipairs(ex.johtoData.order) do
    localizedDexData.pokemon[id] = { dexEntry = {} }
  end
  T.eq(ex.johtoAudio.refreshLocalization(localizedDexData, false), 100,
    "all one hundred Johto species receive resolvable English Dex metadata")
  local celebiDexKey = localizedDexData.pokemon.CELEBI.dexEntry.text
  T.eq(celebiDexKey, "_KantoAscendantJohtoDexCELEBI",
    "Johto Dex entries store a stable Data.text key instead of raw prose")
  T.eq(localizedDexData.text[celebiDexKey],
    ex.johtoAudio.wrapDexText(ex.johtoData.species.CELEBI.dexEntry.textEn),
    "an owned English Celebi entry resolves to its actual description")
  T.eq(ex.johtoAudio.refreshLocalization(localizedDexData, true), 100,
    "all one hundred Johto species refresh after a German save loads")
  T.eq(localizedDexData.pokemon.CHIKORITA.name, "ENDIVIE",
    "runtime Johto localization refreshes version-specific species names")
  T.eq(localizedDexData.pokemon.CELEBI.dexEntry.kind, "ZEITREISE",
    "runtime Johto localization refreshes Celebi's German category")
  T.eq(localizedDexData.text[celebiDexKey],
    ex.johtoAudio.wrapDexText(ex.johtoData.species.CELEBI.dexEntry.textDe),
    "runtime Johto localization exposes Celebi's German Dex prose")
  for _, id in ipairs(ex.johtoData.order) do
    local key = localizedDexData.pokemon[id].dexEntry.text
    local prose = localizedDexData.text[key]
    local lines = 0
    for line in (prose .. "\n"):gmatch("(.-)\n") do
      lines = lines + 1
      T.eq(ex.johtoAudio.glyphLength(line) <= 18, true,
        id .. " German Dex prose fits the rendered description column")
    end
    T.eq(lines <= 7, true,
      id .. " German Dex prose fits the rendered page height")
  end
  T.eq(ex.johtoAudio.refreshLocalization(localizedDexData, false), 100,
    "all one hundred Johto species can switch back to English")
  T.eq(localizedDexData.pokemon.CHIKORITA.name, "CHIKORITA",
    "English Johto species names return without rebuilding content")
  T.eq(localizedDexData.pokemon.CELEBI.dexEntry.kind, "TIME TRAVEL",
    "English Celebi category returns without rebuilding content")
  for _, id in ipairs(ex.johtoData.order) do
    local key = localizedDexData.pokemon[id].dexEntry.text
    local prose = localizedDexData.text[key]
    local lines = 0
    for line in (prose .. "\n"):gmatch("(.-)\n") do
      lines = lines + 1
      T.eq(ex.johtoAudio.glyphLength(line) <= 18, true,
        id .. " English Dex prose fits the rendered description column")
    end
    T.eq(lines <= 7, true,
      id .. " English Dex prose fits the rendered page height")
  end

  -- Exercise the same file-backed path Sound.playCry uses. Presence in the
  -- table alone would not catch a missing package asset or stale cache.
  local oldLoveAudio = love.audio
  love.audio = {
    newSource = function(soundData)
      if not soundData then return nil end
      return {
        setVolume = function() end,
        stop = function() end,
        play = function() end,
      }
    end,
  }
  local Sound = require("src.core.Sound")
  Sound.invalidate()
  T.neq(Sound.playCry(Data, "NATU"), nil,
    "the standalone Natu legacy cry reaches a playable audio source")
  Sound.invalidate()
  love.audio = oldLoveAudio

  local repeatedFallbacks, repeatedExternal =
    ex.johtoAudio.install({ data = Data })
  T.eq(repeatedFallbacks, 0, "late Johto audio binding is idempotent")
  T.eq(repeatedExternal, 100,
    "a repeated install preserves every already resolved cry")
  Data.audio.cries.CHIKORITA = ex.johtoAudio.fallbacks.CHIKORITA
  Data.audio._owners.cries.CHIKORITA = "trainer_rematch"
  local upgradedOwn, preservedAfterUpgrade =
    ex.johtoAudio.install({ data = Data })
  T.eq(upgradedOwn, 1,
    "an Ascendant-owned legacy substitute upgrades to the bundled cry")
  T.eq(preservedAfterUpgrade, 99,
    "upgrading one old substitute preserves every other resolved cry")
  T.eq(Data.audio.cries.CHIKORITA.file,
    ex.johtoAudio.bundled.CHIKORITA.file,
    "the hot-reloaded Chikorita definition points at its real legacy OGG")
  Data.pokemon.TOTODILE = nil
end

-- -------------------------------------------------------- Gorochu guest line

do
  local gorochu = ex.gorochu
  T.neq(gorochu, nil, "the Gorochu guest-species controller is exported")
  T.eq(gorochu.available, true,
    "Gorochu registers when the complete Kanto species table is present")
  T.neq(Data.pokemon.GOROCHU, nil,
    "Gorochu exists as its own permanent species")
  T.eq(Data.pokemon.GOROCHU.dex, 1026,
    "Gorochu stays outside the native 251-species Pokédex")
  local surgeMaster
  for _, gym in ipairs(ex.postgameData.gyms or {}) do
    if gym.key == "surge" then surgeMaster = gym.master break end
  end
  T.eq(surgeMaster and surgeMaster[2]
      and surgeMaster[2].species, "GOROCHU",
    "Lt. Surge's authored template retains Gorochu for post-discovery battles")
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  for _, edition in ipairs({ "red", "blue", "yellow" }) do
    GameVersion.set(edition)
    local lockedTeam = ex.postgame.enabledTeam(surgeMaster)
    T.eq(lockedTeam[2].species, "RAICHU",
      edition .. " hides Gorochu from Major Bob before the player's evolution")
    T.same(lockedTeam[2].moves, {
      "THUNDER", "BODY_SLAM", "THUNDER_WAVE", "AGILITY",
    }, edition .. " gives the locked Gorochu slot a coherent Raichu moveset")
    local randomized = Runtime.call("trainer.party",
      function(_, _, party) return party end,
      "OPP_LT_SURGE", 1, {
        { species = "GOROCHU", level = 81,
          moves = { "THUNDER", "BITE" } },
      })
    T.eq(randomized[1].species, "RAICHU",
      edition .. " masks Randomizer-produced trainer Gorochu before discovery")
    T.eq(surgeMaster[2].species, "GOROCHU",
      edition .. " filtering never mutates the authored unlocked template")
  end
  GameVersion.set("red")
  gorochu.migrate({
    save = {
      inventory = {},
      pokedex = { seen = { GOROCHU = true }, owned = { GOROCHU = true } },
      party = { { species = "GOROCHU" } },
      boxes = {},
    },
  })
  T.eq(gorochu.trainerUnlocked(), false,
    "seeing or receiving Gorochu without evolving it does not unlock opponents")
  T.same(Data.pokemon.GOROCHU.types, { "ELECTRIC" },
    "Gorochu preserves the historical line's Electric identity")
  T.same(Data.pokemon.GOROCHU.baseStats, {
    hp = 85, attack = 135, defense = 90, speed = 125, special = 125,
  }, "Gorochu totals 560, 13.13 percent above either 495-point Mega Raichu")
  local gorochuTotal = 0
  for _, value in pairs(Data.pokemon.GOROCHU.baseStats) do
    gorochuTotal = gorochuTotal + value
  end
  T.eq(gorochuTotal, 560,
    "Gorochu stays inside the requested 10-15 percent strength band")

  local gorochuEvolution
  for _, row in ipairs(Data.pokemon.RAICHU.evolutions or {}) do
    if row.species == "GOROCHU" then gorochuEvolution = row break end
  end
  T.neq(gorochuEvolution, nil,
    "Raichu owns a real evolution edge to Gorochu")
  T.eq(gorochuEvolution.method, "ITEM",
    "Gorochu uses the engine's real item-evolution path")
  T.eq(gorochuEvolution.item, gorochu.tearItemId,
    "Raichu evolves only through the generated Tear of Thunder")
  T.eq(Data.items[gorochu.heartItemId].keyItem, true,
    "Heart of Thunder is a permanent key item in every edition")
  T.eq(Data.items[gorochu.heartItemId].tossable, false,
    "Heart of Thunder cannot be discarded")
  T.eq(Data.items[gorochu.heartItemId].price, 0,
    "Heart of Thunder cannot be sold")
  T.eq(Data.items[gorochu.tearItemId].keyItem, true,
    "Tear of Thunder remains protected until its chosen evolution")
  T.eq(Data.items[gorochu.tearItemId].tossable, false,
    "Tear of Thunder cannot be discarded accidentally")

  local raichu = {
    species = "RAICHU", level = 61, johtoBond = 100,
    moves = { { id = "THUNDER" } },
  }
  local evolutionGame = {
    data = Data,
    save = {
      inventory = {}, hallOfFame = {}, flags = {}, party = { raichu },
    },
    overworld = { map = { id = "POWER_PLANT" } },
  }
  T.eq(gorochu.qualifies(
    evolutionGame, raichu, { kind = "levelup" }), false,
    "ordinary level-ups can never bypass the Tear of Thunder")
  T.eq(gorochu.beginQuest(evolutionGame, raichu), true,
    "the compatibility quest entry marks the chosen Raichu")
  T.eq(raichu[gorochu.marker], true,
    "the optional path is tied to the deliberately chosen individual")
  T.eq(evolutionGame.save.inventory[gorochu.heartItemId], 1,
    "Major Bob's story entry grants exactly one permanent Heart")
  T.eq(gorochu.qualifies(
    evolutionGame, raichu,
    { kind = "item", item = "THUNDER_STONE" }), false,
    "an ordinary Thunder Stone cannot create Gorochu")
  T.eq(gorochu.grantTear(evolutionGame), true,
    "the Power Plant condenser generates the first Tear")
  T.eq(evolutionGame.save.inventory[gorochu.tearItemId], 1,
    "the generated Tear is placed safely in the Bag")
  T.eq(gorochu.trainerUnlocked(), false,
    "owning both permanent quest items does not unlock trainer Gorochu")
  local ItemEffects = require("src.inventory.ItemEffects")
  local fakeRedVersion = {
    isYellow = function() return false end,
  }
  gorochu.install(evolutionGame, { gameVersion = fakeRedVersion })
  T.eq(gorochu.handleTalk({
    map = { id = "VERMILION_GYM" }, player = {},
  }, {
    def = { name = "VERMILIONGYM_LT_SURGE" },
    facePlayer = function() end,
  }, evolutionGame), false,
    "owning THUNDERHEART releases Surge to Master and Crown rematch dialogue")
  T.eq(ItemEffects.needsTarget(
    gorochu.tearItemId, Data.items[gorochu.tearItemId]), true,
    "the Tear opens the party picker like a real evolution item")
  local wrongResult = ItemEffects.use(
    Data, evolutionGame.save, gorochu.tearItemId,
    { species = "PIKACHU" }, nil)
  T.eq(wrongResult, "failed",
    "the Tear cannot be spent on Pikachu or another species")
  local useResult, useMessages, useExtra = ItemEffects.use(
    Data, evolutionGame.save, gorochu.tearItemId, raichu, nil)
  T.eq(useResult, "consumed",
    "using the Tear on Raichu enters the standard consumable-item flow")
  T.eq(useMessages, nil,
    "the valid Tear path hands control directly to the evolution movie")
  T.eq(useExtra and useExtra.evolveTo, "GOROCHU",
    "the Tear requests Gorochu from the engine's evolution movie")
  T.eq(gorochu.qualifies(
    evolutionGame, raichu,
    { kind = "item", item = gorochu.tearItemId }), true,
    "the generated Tear qualifies the chosen Raichu in every location")
  local Evolution = require("src.pokemon.Evolution")
  local target = Evolution.pendingFor(
    evolutionGame, raichu,
    { kind = "item", item = gorochu.tearItemId })
  T.eq(target, "GOROCHU",
    "the engine dispatches the Tear of Thunder evolution")
  local markedRaichu = {
    species = "RAICHU", level = 61, hp = 130, johtoBond = 100,
    moves = { { id = "THUNDER", pp = 10 } },
    dvs = {
      attack = 9, defense = 8, speed = 8, special = 8, hp = 8,
    },
    statExp = {
      hp = 0, attack = 0, defense = 0, speed = 0, special = 0,
    },
    stats = {
      hp = 140, attack = 120, defense = 90, speed = 140, special = 120,
    },
    _ascendantYellowPartner = true,
  }
  evolutionGame.save.pokedex = { seen = {}, owned = {} }
  Evolution.apply(
    evolutionGame, markedRaichu, "GOROCHU", gorochu.method)
  T.eq(markedRaichu.species, "GOROCHU",
    "the permanent evolution mutates Raichu into Gorochu")
  T.eq(markedRaichu._ascendantYellowPartner, true,
    "Yellow's persistent partner identity survives the evolution")
  T.eq(markedRaichu.moves[1].id, "THUNDER",
    "Gorochu keeps the original partner's moves")
  T.eq(evolutionGame.save.pokedex.owned.GOROCHU, true,
    "evolving Gorochu records the guest species as owned")
  T.eq(gorochu.state().playerEvolved, true,
    "the player's completed Raichu evolution records trainer permission")
  evolutionGame.save.inventory.THUNDERBADGE = true
  evolutionGame.save.inventory[gorochu.heartItemId] = nil
  evolutionGame.save.player = { name = "RED", rival = "BLUE" }
  local surgeBoxes = {}
  evolutionGame.stack = {
    push = function(_, box) surgeBoxes[#surgeBoxes + 1] = box end,
  }
  local surgeNpc = {
    def = { name = "VERMILIONGYM_LT_SURGE" },
    facePlayer = function() end,
  }
  local surgeOw = {
    map = { id = "VERMILION_GYM" }, player = {},
  }
  T.eq(gorochu.handleTalk(surgeOw, surgeNpc, evolutionGame), true,
    "postgame Gorochu owners with a missing Heart receive the repair offer")
  T.eq(type(surgeBoxes[#surgeBoxes].choice), "function",
    "the repaired Surge hand-off still asks before granting THUNDERHEART")
  surgeBoxes[#surgeBoxes].choice(true)
  T.eq(evolutionGame.save.inventory[gorochu.heartItemId], 1,
    "accepting the postgame repair restores exactly one THUNDERHEART")
  T.eq(gorochu.handleTalk({
    map = { id = "VERMILION_GYM" }, player = {},
  }, {
    def = { name = "VERMILIONGYM_LT_SURGE" },
  }, evolutionGame), false,
    "THUNDERHEART owners reach Surge's normal Master/Crown conversation")
  for _, edition in ipairs({ "red", "blue", "yellow" }) do
    GameVersion.set(edition)
    local unlockedTeam = ex.postgame.enabledTeam(surgeMaster)
    T.eq(unlockedTeam[2].species, "GOROCHU",
      edition .. " allows opposing Gorochu only after the player's evolution")
    local randomized = Runtime.call("trainer.party",
      function(_, _, party) return party end,
      "OPP_LT_SURGE", 1, {
        { species = "GOROCHU", level = 81,
          moves = { "THUNDER", "BITE" } },
      })
    T.eq(randomized[1].species, "GOROCHU",
      edition .. " stops masking Randomizer Gorochu after discovery")
  end
  GameVersion.set("red")

  Data.audio = Data.audio or {}
  Data.audio.cries = Data.audio.cries or {}
  Data.audio.cries.GOROCHU = nil
  local installed, preserved = gorochu.installAudio({ data = Data })
  T.eq(installed, 1,
    "a missing Red/Blue Gorochu cry receives its Gen-I chip program")
  T.eq(preserved, 0, "the first Gorochu fallback install owns the empty slot")
  T.eq(Data.audio.cries.GOROCHU.file, nil,
    "Red/Blue Gorochu does not use Yellow's spoken partner call")
  T.eq(Data.audio.cries.GOROCHU.base, "RAICHU",
    "Red/Blue Gorochu derives its original-style program from Raichu")
  T.eq(Data.audio.cries.GOROCHU.pitch, 0x50,
    "Red/Blue Gorochu uses its authored Gen-I cry pitch")
  T.eq(Data.audio.cries.GOROCHU.length, 0xB0,
    "Red/Blue Gorochu uses its authored Gen-I cry length")
  T.eq(Data.pokemon.GOROCHU.cry, "GOROCHU",
    "the guest species binds to its resolved cry")
  local repeatedInstalled, repeatedPreserved =
    gorochu.installAudio({ data = Data })
  T.eq(repeatedInstalled, 0, "Gorochu audio installation is idempotent")
  T.eq(repeatedPreserved, 1,
    "an existing external or prior Gorochu cry is preserved")

  for _, relative in ipairs({
    "assets/crystal/gorochu_front.png",
    "assets/crystal/gorochu_back.png",
    "assets/crystal/gorochu_front_shiny.png",
    "assets/crystal/gorochu_back_shiny.png",
    "assets/followers_runtime/normal/follower_GOROCHU.png",
    "assets/followers_runtime/shiny/follower_GOROCHU.png",
    "assets/audio/gorochu/gorochu_cry.wav",
  }) do
    local handle = io.open(modPath .. "/" .. relative, "rb")
    T.neq(handle, nil, relative .. " is packaged")
    if handle then handle:close() end
  end
  for _, side in ipairs({ "front", "back" }) do
    for _, variant in ipairs({ "normal", "shiny" }) do
      for frame = 1, #gorochu.animationDurations do
        local relative = (
          "assets/crystal_animated/%s/%s/1026/%03d.png")
          :format(side, variant, frame)
        local handle = io.open(modPath .. "/" .. relative, "rb")
        T.neq(handle, nil, relative .. " is packaged")
        if handle then handle:close() end
      end
    end
  end
end

-- ------------------------------------------------ bundled Crystal art seam

T.neq(ex.crystalSprites, nil, "Crystal availability is exported")
T.neq(ex.crystalShinySprites, nil,
  "Crystal shiny availability is exported independently")
T.neq(ex.crystalAnimation, nil,
  "Crystal animation compatibility is exported")
T.neq(ex.kantoCrystalBacks, nil,
  "Kanto Crystal back-sprite availability is exported")
;(function()
  local crystalNormalCount, crystalShinyCount = 0, 0
  local animatedNormalCount, animatedShinyCount = 0, 0
  local kantoBackCount, kantoShinyBackCount = 0, 0
  for _, available in pairs(ex.crystalSprites) do
    if available then crystalNormalCount = crystalNormalCount + 1 end
  end
  for _, available in pairs(ex.crystalShinySprites) do
    if available then crystalShinyCount = crystalShinyCount + 1 end
  end
  for _, available in pairs(ex.crystalAnimation.available) do
    if available then animatedNormalCount = animatedNormalCount + 1 end
  end
  for _, available in pairs(ex.crystalAnimation.shinyAvailable) do
    if available then animatedShinyCount = animatedShinyCount + 1 end
  end
  for _, available in pairs(ex.kantoCrystalBacks.normal) do
    if available then kantoBackCount = kantoBackCount + 1 end
  end
  for _, available in pairs(ex.kantoCrystalBacks.shiny) do
    if available then kantoShinyBackCount = kantoShinyBackCount + 1 end
  end
  T.eq(crystalNormalCount, 101,
    "all 100 Johto species plus Gorochu ship with Crystal front/back art")
  T.eq(crystalShinyCount, 101,
    "all 100 Johto species plus shiny Gorochu ship with Crystal art")
  T.eq(animatedNormalCount, 252,
    "all 251 native species plus Gorochu ship with animated normal art")
  T.eq(animatedShinyCount, 252,
    "all 251 native species plus Gorochu ship with animated shiny art")
  T.eq(ex.crystalAnimation.backAvailable[1026], true,
    "Gorochu owns animated player-side art")
  T.eq(ex.crystalAnimation.backShinyAvailable[1026], true,
    "shiny Gorochu owns animated player-side art")
  T.eq(kantoBackCount, 151,
    "all 151 Kanto species ship with Crystal player-side art")
  T.eq(kantoShinyBackCount, 151,
    "all 151 Kanto species ship with shiny Crystal player-side art")
  T.eq(ex.crystalSprites.TOTODILE, true,
    "Totodile never needs the Squirtle battle fallback in a release package")
T.eq(ex.crystalSprites.FERALIGATR, true,
  "the visually tested Feraligatr Crystal pair is bundled")
end)()
local RealRuntime = require("src.mods.Runtime")
local crystalCtx = { species = "RAIKOU", side = "front", trueColor = false }
local crystalPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_front.png", crystalCtx)
if ex.crystalSprites.RAIKOU then
  T.eq(crystalPath:find("assets/crystal/raikou_front.png", 1, true) ~= nil, true,
    "an installed Crystal front sprite is selected")
  T.eq(crystalCtx.trueColor, true, "Crystal art keeps its GBC colors")
else
  T.eq(crystalPath, "fallback_front.png",
    "missing Crystal art automatically uses the original fallback")
end
local crystalShinyMon = {
  species = "RAIKOU",
  dvs = { attack = 10, defense = 10, speed = 10, special = 10, hp = 0 },
}
local crystalShinyCtx = {
  species = "RAIKOU", side = "front", trueColor = false,
  mon = crystalShinyMon,
}
local crystalShinyPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_front.png", crystalShinyCtx)
if ex.crystalShinySprites.RAIKOU then
  T.eq(crystalShinyPath:find(
      "assets/crystal/raikou_front_shiny.png", 1, true) ~= nil, true,
    "a shiny Johto mon selects Crystal's real shiny sprite")
  T.eq(crystalShinyCtx.trueColor, true,
    "the official shiny Crystal palette is kept in true color")
end
do
local animatedKanto = {
  species = "FIXMON_A",
  dvs = { attack = 9, defense = 8, speed = 8, special = 8, hp = 8 },
}
local animatedKantoCtx = {
  species = "FIXMON_A", side = "front", trueColor = false,
  mon = animatedKanto, kind = "battle", data = Data,
}
local animatedKantoPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_front.png", animatedKantoCtx)
T.eq(animatedKantoPath:find(
    "assets/crystal_animated/front/normal/1/001.png", 1, true) ~= nil, true,
  "Kanto enemy fronts use the bundled Crystal animation without another mod")
T.eq(animatedKantoCtx.trueColor, true,
  "bundled Kanto Crystal frames keep their authored palette")
local shinyKantoPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_front.png", {
    species = "FIXMON_A", side = "front", trueColor = false,
    mon = {
      species = "FIXMON_A",
      dvs = { attack = 10, defense = 10, speed = 10, special = 10, hp = 0 },
    },
    kind = "battle", data = Data,
  })
T.eq(shinyKantoPath:find(
    "assets/crystal_animated/front/shiny/1/001.png", 1, true) ~= nil, true,
  "Kanto shinies use the bundled matching Crystal frames")
local kantoBackPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_back.png", {
    species = "FIXMON_A", side = "back", trueColor = false,
    mon = animatedKanto, kind = "battle", data = Data,
  })
T.eq(kantoBackPath:find(
    "assets/crystal/kanto/001_back.png", 1, true) ~= nil, true,
  "Kanto player battlers use the matching bundled Crystal back sprite")
T.eq(Data.battle_sprite_scales
    .KANTO_ASCENDANT_CRYSTAL_001_BACK.scale, 1,
  "Kanto Crystal back sprites use their native 1x scale")
run.loader.modOptions.trainer_rematch = { kanto_crystal_art = false }
local disabledKantoPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_front.png", animatedKantoCtx)
T.eq(disabledKantoPath, "fallback_front.png",
  "KANTO CRYSTAL ART can restore the original Gen-I front sprites")
local disabledKantoBackPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_back.png", {
    species = "FIXMON_A", side = "back", trueColor = false,
    mon = animatedKanto, kind = "battle", data = Data,
  })
T.eq(disabledKantoBackPath, "fallback_back.png",
  "KANTO CRYSTAL ART also restores the original Gen-I player back sprites")
run.loader.modOptions.trainer_rematch = nil

-- Pokédex art is intentionally independent from every live battle-art
-- setting. Use the three canonical starter dex numbers and edition-shaped
-- source paths so a hardcoded Red/Blue/Yellow fallback cannot hide here.
local starterDexData = {
  pokemon = {
    BULBASAUR = { id = "BULBASAUR", dex = 1, spriteFront = "unused" },
    CHARMANDER = { id = "CHARMANDER", dex = 4, spriteFront = "unused" },
    SQUIRTLE = { id = "SQUIRTLE", dex = 7, spriteFront = "unused" },
    TOTODILE = { id = "TOTODILE", dex = 158, spriteFront = "johto.png" },
    GOROCHU = { id = "GOROCHU", dex = 1026, spriteFront = "guest.png" },
  },
}
local editionBases = {
  red = {
    BULBASAUR = "red/bulbasaur_front.png",
    CHARMANDER = "red/charmander_front.png",
    SQUIRTLE = "red/squirtle_front.png",
  },
  blue = {
    BULBASAUR = "blue/bulbasaur_front.png",
    CHARMANDER = "blue/charmander_front.png",
    SQUIRTLE = "blue/squirtle_front.png",
  },
  yellow = {
    BULBASAUR = "yellow/bulbasaur_front.png",
    CHARMANDER = "yellow/charmander_front.png",
    SQUIRTLE = "yellow/squirtle_front.png",
  },
}
local GameVersion = require("src.core.GameVersion")
local dexMatrix = {}
for _, crystalArt in ipairs({ false, true }) do
  for _, dexStyle in ipairs({ "original", "crystal" }) do
    local matrixKey = tostring(crystalArt) .. ":" .. dexStyle
    dexMatrix[matrixKey] = { dex = {}, battle = {} }
    run.loader.modOptions.trainer_rematch = {
      kanto_crystal_art = crystalArt,
      dex_sprite_style = dexStyle,
      crystal_animation = true,
    }
    for edition, paths in pairs(editionBases) do
      GameVersion.set(edition)
      for _, species in ipairs({ "BULBASAUR", "CHARMANDER", "SQUIRTLE" }) do
        local dexMon = { species = species }
        local dexCtx = {
          species = species, side = "front", kind = "dex",
          mon = dexMon, trueColor = false, data = starterDexData,
        }
        local resolved = RealRuntime.call("pokemon.sprite",
          function(path) return path end, paths[species], dexCtx)
        dexMatrix[matrixKey].dex[edition .. ":" .. species] = resolved
        if dexStyle == "crystal" then
          local dex = starterDexData.pokemon[species].dex
          T.eq(resolved:find(
              ("assets/crystal_animated/front/normal/%d/001.png"):format(dex),
              1, true) ~= nil, true,
            edition .. " " .. species
              .. " Dex uses bundled static Crystal frame one")
          T.eq(dexCtx.trueColor, true,
            edition .. " " .. species .. " bundled Dex frame is true color")
        else
          T.eq(resolved, paths[species],
            edition .. " " .. species
              .. " Dex preserves the active ROM's original artwork")
          T.eq(dexCtx.trueColor, false,
            edition .. " " .. species
              .. " original Dex art keeps display-palette recoloring")
        end
        T.eq(ex.crystalAnimation.selected[dexMon], nil,
          "Dex resolution never creates Crystal battle-animation state")
      end
    end

    local battleMon = {
      species = "BULBASAUR",
      dvs = { attack = 9, defense = 8, speed = 8, special = 8, hp = 8 },
    }
    local battleCtx = {
      species = "BULBASAUR", side = "front", kind = "battle",
      mon = battleMon, trueColor = false, data = starterDexData,
    }
    dexMatrix[matrixKey].battle.path = RealRuntime.call("pokemon.sprite",
      function(path) return path end, "battle/bulbasaur_front.png", battleCtx)
  end
end
GameVersion.set("red")
for _, edition in ipairs({ "red", "blue", "yellow" }) do
  for _, species in ipairs({ "BULBASAUR", "CHARMANDER", "SQUIRTLE" }) do
    local key = edition .. ":" .. species
    T.eq(dexMatrix["false:original"].dex[key],
      dexMatrix["true:original"].dex[key],
      "KANTO CRYSTAL ART does not affect ORIGINAL Dex results")
    T.eq(dexMatrix["false:crystal"].dex[key],
      dexMatrix["true:crystal"].dex[key],
      "KANTO CRYSTAL ART does not affect CRYSTAL Dex results")
  end
end
T.eq(dexMatrix["false:original"].battle.path,
  dexMatrix["false:crystal"].battle.path,
  "DEX SPRITES does not affect original Kanto battle art")
T.eq(dexMatrix["true:original"].battle.path,
  dexMatrix["true:crystal"].battle.path,
  "DEX SPRITES does not affect Crystal Kanto battle art")

run.loader.modOptions.trainer_rematch = {
  kanto_crystal_art = false,
  dex_sprite_style = "crystal",
  crystal_animation = false,
}
local noMotionCtx = {
  species = "BULBASAUR", side = "front", kind = "dex",
  trueColor = false, data = starterDexData,
}
local noMotionDex = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "red/bulbasaur_front.png", noMotionCtx)
T.eq(noMotionDex, dexMatrix["false:crystal"].dex["red:BULBASAUR"],
  "CRYSTAL ANIMATION has no effect on static Crystal Dex sprites")
local dexOnlyMon = { species = "BULBASAUR" }
ex.crystalAnimation.updateBattle({
  enemy = { mon = dexOnlyMon, sprite = {} },
  showEnemyTrainer = false, enemySendingOut = false,
}, 10)
T.eq(ex.crystalAnimation.selected[dexOnlyMon], nil,
  "a static Dex frame cannot advance through the battle animator")

for _, dexStyle in ipairs({ "original", "crystal" }) do
  run.loader.modOptions.trainer_rematch = {
    dex_sprite_style = dexStyle, kanto_crystal_art = true,
  }
  local johtoDexData = { pokemon = {} }
  for _, species in ipairs(ex.johtoData.order) do
    johtoDexData.pokemon[species] = {
      id = species,
      dex = ex.johtoData.species[species].dex,
      -- Deliberately model a third-party UI receiving the historical Kanto
      -- fallback. The Dex resolver must replace every one of these paths.
      spriteFront = "kanto-fallback/" .. species:lower() .. ".png",
    }
  end
  for _, species in ipairs(ex.johtoData.order) do
    local dex = assert(johtoDexData.pokemon[species].dex)
    local ctx = {
      species = species, side = "front", kind = "dex",
      trueColor = false, data = johtoDexData,
    }
    local resolved = RealRuntime.call("pokemon.sprite",
      function(path) return path end,
      johtoDexData.pokemon[species].spriteFront, ctx)
    T.eq(resolved:find(
        ("assets/crystal_animated/front/normal/%d/001.png"):format(dex),
        1, true) ~= nil, true,
      species .. " Dex uses its own Crystal frame in " .. dexStyle .. " mode")
    T.eq(ctx.trueColor, true,
      species .. " Dex Crystal frame is true-color in " .. dexStyle .. " mode")
  end

  local guestCtx = {
    species = "GOROCHU", side = "front", kind = "dex",
    trueColor = false, data = starterDexData,
  }
  T.eq(RealRuntime.call("pokemon.sprite",
      function(path) return path end, "registered/guest_gorochu.png",
      guestCtx), "registered/guest_gorochu.png",
    "GOROCHU keeps its registered guest Dex artwork in "
      .. dexStyle .. " mode")
end

local originalStaticFrameOne = ex.crystalAnimation.staticFrameOne
ex.crystalAnimation.staticFrameOne = function() return nil end
run.loader.modOptions.trainer_rematch = { dex_sprite_style = "crystal" }
local missingCtx = {
  species = "BULBASAUR", side = "front", kind = "dex",
  trueColor = false, data = starterDexData,
}
T.eq(RealRuntime.call("pokemon.sprite",
    function(path) return path end, "blue/bulbasaur_front.png", missingCtx),
  "blue/bulbasaur_front.png",
  "a missing bundled Crystal Dex frame safely falls back to original art")
T.eq(missingCtx.trueColor, false,
  "a missing Crystal Dex frame does not suppress normal palette recoloring")
ex.crystalAnimation.staticFrameOne = originalStaticFrameOne

local removeExternalDex = run.loader.hooks:wrap(
  "pokemon.sprite", function(nextSprite, path, ctx)
    local downstream = nextSprite(path, ctx)
    if ctx and ctx.kind == "dex" and ctx.species == "BULBASAUR" then
      ctx.trueColor = true
      return "external/all_species/bulbasaur_dex.png"
    end
    return downstream
  end, 0, "dex_external_owner_test")
run.loader.modOptions.trainer_rematch = { dex_sprite_style = "crystal" }
local externalDexCtx = {
  species = "BULBASAUR", side = "front", kind = "dex",
  trueColor = false, data = starterDexData,
}
T.eq(RealRuntime.call("pokemon.sprite",
    function(path) return path end, "yellow/bulbasaur_front.png",
    externalDexCtx), "external/all_species/bulbasaur_dex.png",
  "an explicitly installed external Dex sprite resolver remains authoritative")
removeExternalDex()

local Json = require("src.link.Json")
run.loader.modOptions = Json.decode(Json.encode({
  modOptions = {
    trainer_rematch = { dex_sprite_style = "crystal" },
  },
})).modOptions
local persistedDexCtx = {
  species = "SQUIRTLE", side = "front", kind = "dex",
  trueColor = false, data = starterDexData,
}
local persistedDexPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "red/squirtle_front.png", persistedDexCtx)
T.eq(run.loader.modOptions.trainer_rematch.dex_sprite_style, "crystal",
  "the selected Dex style survives the standard serialized options round trip")
T.eq(persistedDexPath,
  dexMatrix["false:crystal"].dex["red:SQUIRTLE"],
  "a reloaded CRYSTAL Dex option takes effect without restarting the game")
run.loader.modOptions.trainer_rematch = nil

local animatedTotodile = {
  species = "TOTODILE",
  dvs = { attack = 9, defense = 8, speed = 8, special = 8, hp = 8 },
}
local animatedTotodileCtx = {
  species = "TOTODILE", side = "front", trueColor = false,
  mon = animatedTotodile, kind = "battle",
}
local animatedTotodilePath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_front.png", animatedTotodileCtx)
T.eq(animatedTotodilePath:find(
    "assets/crystal_animated/front/normal/158/001.png", 1, true) ~= nil, true,
  "Johto enemy fronts use the bundled Crystal animation frames")
T.eq(animatedTotodileCtx.trueColor, true,
  "animated Crystal frames keep their authored palette")
local animatedShinyTotodile = {
  species = "TOTODILE",
  dvs = { attack = 10, defense = 10, speed = 10, special = 10, hp = 0 },
}
local animatedShinyTotodilePath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_front.png", {
    species = "TOTODILE", side = "front", trueColor = false,
    mon = animatedShinyTotodile, kind = "battle",
  })
T.eq(animatedShinyTotodilePath:find(
    "assets/crystal_animated/front/shiny/158/001.png", 1, true) ~= nil, true,
  "Johto shinies use Crystal's matching animated shiny frames")
local totodileBackPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_back.png", {
    species = "TOTODILE", side = "back", trueColor = false,
    mon = animatedTotodile, kind = "battle",
  })
T.eq(totodileBackPath:find(
    "assets/crystal/totodile_back.png", 1, true) ~= nil, true,
  "ordinary 2D battles retain the correct Crystal back sprite")
RealRuntime.call("pokemon.sprite", function(path) return path end,
  "fallback_front.png", animatedTotodileCtx)
local animatedBattle = {
  enemy = { mon = animatedTotodile, sprite = {} },
  showEnemyTrainer = false,
  enemySendingOut = false,
}
ex.crystalAnimation.updateBattle(animatedBattle, 1.0)
T.neq(animatedBattle.enemy.__ascendantCrystalAnimation, nil,
  "the live battler receives an independent Ascendant animation state")
T.eq(animatedBattle.enemy.__ascendantCrystalAnimation.frame > 1, true,
  "Crystal animation timing advances without depending on render availability")
do
  local animationData = assert(loadfile(
    modPath .. "/crystal_animation_data.lua"))()
  local missingFrames = {}
  for variant, byDex in pairs(animationData) do
    for dex, timing in pairs(byDex) do
      for frame = 1, #timing do
        local relative = ("assets/crystal_animated/front/%s/%s/%03d.png")
          :format(variant, dex, frame)
        local handle = io.open(modPath .. "/" .. relative, "rb")
        if handle then
          handle:close()
        else
          missingFrames[#missingFrames + 1] = relative
        end
      end
    end
  end
  T.eq(#missingFrames, 0,
    "every generated Crystal timing entry has its packaged PNG frame")
end

local removeExternalCrystal = run.loader.hooks:wrap(
  "pokemon.sprite", function(nextSprite, path, ctx)
    nextSprite(path, ctx)
    if ctx and ctx.species == "RAIKOU" then
      ctx.trueColor = true
      return "external/crystal/raikou/001.png"
    end
    return path
  end, 0, "crystal_compat_test")
local externalCrystalPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_front.png", {
    species = "RAIKOU", side = "front", trueColor = false,
    mon = { species = "RAIKOU" }, kind = "battle",
  })
T.eq(externalCrystalPath, "external/crystal/raikou/001.png",
  "an external Johto animation resolver takes priority over bundled stills")
removeExternalCrystal()
end

run.loader.modOptions.trainer_rematch = { legend_art = "original" }
local originalCtx = { species = "RAIKOU", side = "back", trueColor = false }
local originalPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "fallback_back.png", originalCtx)
T.eq(originalPath, "fallback_back.png",
  "the LEGEND ART option can force the original sprite")
T.eq(originalCtx.trueColor, false,
  "the original four-shade sprite stays palette-aware")
run.loader.modOptions.trainer_rematch = nil
T.neq(ex.spriteAssets, nil,
  "sprite preparation for transparent battle and follower art is exported")
T.same(ex.spriteAssets.followerOrder, { 4, 2, 0, 5, 3, 1 },
  "PokeWilds poses map to Gen1 Recomp's down/up/side frame order")
local voxelCtx = {
  species = "RAIKOU", side = "back", trueColor = false,
  mon = { species = "RAIKOU" }, kind = "battle",
  data = { pokemon = { RAIKOU = { spriteFront = "voxel_front.png" } } },
}
local voxelPath = RealRuntime.call("pokemon.sprite",
  function() return "voxel_front.png" end, "fallback_back.png", voxelCtx)
if ex.crystalSprites.RAIKOU then
  T.eq(voxelPath:find(
      "assets/crystal_animated/front/normal/243/001.png", 1, true) ~= nil, true,
    "voxel battles animate Dramatic Shape's front-facing player sprite")
end

local optionRows = {}
for _, row in ipairs(run.loader.optionSchemas.trainer_rematch or {}) do
  optionRows[row.key] = row
end
T.eq(optionRows.language.type, "choice",
  "language can be selected as AUTO, ENGLISH or DEUTSCH")
T.eq(optionRows.team_growth.type, "toggle",
  "class-appropriate party recruitment can be switched off")
T.eq(optionRows.loot_mode.type, "choice",
  "rare rematch loot has OFF, BALANCED and GENEROUS modes")
T.eq(optionRows.rest_min.min, 151,
  "the configurable rematch range starts at Kanto's full Pokédex count")
T.eq(optionRows.rest_max.max, 2510,
  "the configurable rematch range reaches the complete 251 roster times ten")
T.eq(optionRows.kanto_151.type, "choice",
  "all 151 Kanto species support reward, wild and off modes")
T.eq(optionRows.kanto_151.default, "ascendant",
  "Kanto completion defaults to authored rewards instead of random starters")
T.eq(optionRows.kanto_151.label:find("RESTART", 1, true) ~= nil, true,
  "the content-patching KANTO 151 option visibly warns that it needs a restart")
T.eq(optionRows.legend_articuno.type, "choice",
  "Articuno has its own APEX/VANILLA/OFF option")
T.eq(optionRows.shiny_hunts.type, "choice",
  "shiny hunting can use Ascendant boosts or natural 1/8192 odds")
T.eq(optionRows.crystal_animation.type, "toggle",
  "bundled Crystal animation can be disabled independently")
T.eq(optionRows.kanto_crystal_art.type, "toggle",
  "bundled Kanto Crystal art can be enabled without an external sprite mod")
T.eq(optionRows.dex_sprite_style.type, "choice",
  "Pokédex sprite style is an independent ORIGINAL/CRYSTAL choice")
T.eq(optionRows.dex_sprite_style.default, "original",
  "existing saves default to the base-ROM Pokédex presentation")
T.same(optionRows.dex_sprite_style.choices, {
  { "ORIGINAL", "original" }, { "CRYSTAL", "crystal" },
}, "the Dex sprite option exposes only the two requested static styles")
T.eq(optionRows.shiny_effects.type, "toggle",
  "built-in shiny presentation can be switched off")
T.eq(optionRows.shiny_protection.type, "toggle",
  "shiny Pokémon can be protected from accidental PC release")
T.eq(optionRows.shiny_event.type, "toggle",
  "the guaranteed red Gyarados event can be switched off")
T.eq(optionRows.johto_time.type, "choice",
  "Johto friendship branches can follow AUTO, DAY or NIGHT")
T.eq(optionRows.mega_evolution.type, "toggle",
  "official Mega Evolution can be disabled")
T.eq(optionRows.mega_opponents.type, "choice",
  "enemy Mega Evolution supports bosses, all trainers or off")
T.eq(optionRows.legend_mewtwo.type, "choice",
  "Mewtwo has its own APEX/VANILLA/OFF option")
T.eq(optionRows.legend_raikou.type, "toggle",
  "Raikou can be enabled or disabled independently")
T.eq(optionRows.legend_celebi.type, "toggle",
  "Celebi can be enabled or disabled independently")
T.eq(optionRows.legend_mew.type, "toggle",
  "Mew can be enabled or disabled independently")
T.eq(optionRows.mew_profile.type, "choice",
  "Mew can use either its Ascendant or historical distribution profile")
T.eq(optionRows.event_mode.type, "choice",
  "Heritage events can run as cups, roaming hunts or be disabled")
T.eq(optionRows.event_flying_pikachu.type, "toggle",
  "Flying Pikachu can be disabled independently")
T.eq(optionRows.event_rosette.type, "toggle",
  "the in-battle event rosette is optional")
T.eq(optionRows.rocket_story.type, "toggle",
  "Rocket Resurgence can be disabled independently")
T.eq(optionRows.grand_tournament.type, "toggle",
  "the Grand Tournament can be disabled independently")
T.eq(optionRows.ascendant_rules.type, "choice",
  "New Game Plus challenge rules can be relaxed")

-- ------------------------------------------------ tidy Ascendant submenu

;(function()
local ascendantMenu = ex.ascendantMenu
T.neq(ascendantMenu, nil,
  "the centralized Ascendant Start-menu gateway is exported")
local keptRows, groupedRows = ascendantMenu.collect({
  { label = "ITEM" },
  {
    label = "MEGA", ascendantMenu = true,
    ascendantLabel = "MEGA STONES", ascendantOrder = 70,
  },
  {
    label = "JOURNAL", ascendantMenu = true,
    ascendantLabel = "JOURNAL", ascendantOrder = 10,
  },
  { label = "SAVE" },
})
T.eq(#keptRows, 2,
  "the collector preserves ordinary Start-menu rows")
T.eq(keptRows[1].label, "ITEM",
  "ordinary Start-menu row order remains unchanged")
T.eq(keptRows[2].label, "SAVE",
  "the vanilla SAVE anchor remains present")
T.eq(#groupedRows, 2,
  "only explicitly marked Ascendant rows enter the submenu")
T.eq(groupedRows[1].label, "JOURNAL",
  "Ascendant utilities use their intentional logical order")
T.eq(groupedRows[2].label, "MEGA STONES",
  "the submenu can use a clearer label than the compact old Start row")
local _, expandedRows, anyNew = ascendantMenu.collect({
  {
    label = "JOURNAL", ascendantMenu = true,
    ascendantLabel = "JOURNAL", ascendantOrder = 10,
  },
  {
    label = "MEGA", ascendantMenu = true,
    ascendantLabel = "MEGA STONES", ascendantOrder = 70,
  },
  {
    label = "TITLES", ascendantMenu = true,
    ascendantLabel = "TITLES / TROPHIES", ascendantOrder = 80,
  },
})
T.eq(anyNew, true,
  "a utility unlocked after the initial menu visit raises a visible NEW hint")
T.eq(expandedRows[3].right, "NEW",
  "the newly unlocked utility itself carries the NEW marker")

local menuOwned = {}
for id, def in pairs(Data.pokemon) do
  if def.dex and def.dex <= 150 then menuOwned[id] = true end
end
local pushedAscendantMenu
local menuGame = {
  data = Data,
  save = {
    flags = { EVENT_BEAT_CHAMPION_RIVAL = true },
    hallOfFame = { {} },
    pokedex = { seen = menuOwned, owned = menuOwned },
    inventory = {}, bagOrder = {}, party = {},
    player = { name = "RED" }, options = {},
  },
  stack = {
    push = function(_, screen) pushedAscendantMenu = screen end,
  },
}
local megaMenuState = ex.megaEvolution.state()
local priorMegaRing = megaMenuState.ring
megaMenuState.ring = true
local topRows = RealRuntime.call("ui.start_menu.items",
  function(_, rows) return rows end, menuGame, {
    { label = "POKéMON" },
    { label = "ITEM" },
    { label = "SAVE" },
    { label = "OPTION" },
  })
megaMenuState.ring = priorMegaRing
local ascendantRow, ascendantRows = nil, 0
local leakedRows = {
  JOURNAL = true, WORLD = true, WELT = true, JOHTO = true,
  SHINY = true, EVENTS = true, ["CERT."] = true, ZERT = true, MEGA = true,
}
for _, row in ipairs(topRows) do
  if row.label == "ASCENDANT" then
    ascendantRow, ascendantRows = row, ascendantRows + 1
  end
  T.eq(leakedRows[row.label], nil,
    row.label .. " does not leak back into the tidy Start menu")
end
T.eq(ascendantRows, 1,
  "all unlocked utilities produce exactly one ASCENDANT Start row")
T.neq(ascendantRow, nil, "the ASCENDANT Start row is reachable")
ascendantRow.onSelect()
T.neq(pushedAscendantMenu, nil,
  "selecting ASCENDANT opens the dedicated utility list")
T.eq(pushedAscendantMenu.title, "KANTO ASCENDANT",
  "the utility list carries the expansion's full title")
T.eq(#pushedAscendantMenu.items, 9,
  "the fixture exposes every utility whose content is available")
T.same((function()
  local labels = {}
  for _, row in ipairs(pushedAscendantMenu.items) do
    labels[#labels + 1] = row.label
  end
  return labels
end)(), {
  "RESEARCH ATLAS", "JOURNAL", "GOROCHU RESEARCH", "WORLD", "SHINY DEX",
  "EVENT ARCHIVE", "MEGA STONES", "FRONTIER EXCHANGE",
  "TITLES / TROPHIES",
}, "available Ascendant utilities are clear and consistently ordered")
end)()

-- ------------------------------------------------ Route 5 Day-Care Plus

local daycare = ex.daycare
T.neq(daycare, nil, "the full Route 5 Day-Care controller is exported")
T.eq(#ex.breedingData, 251,
  "canonical breeding metadata covers every Kanto and Johto species")
T.eq(ex.breedingData[25].gender, 4,
  "Pikachu uses the canonical half-female Attack-DV threshold")
T.eq(ex.breedingData[150].groups[1], "no-eggs",
  "Mewtwo belongs to the unbreedable egg group")
local breedingGame = { data = { pokemon = {
  PICHU = { dex = 172, evolutions = { { species = "PIKACHU" } } },
  PIKACHU = { dex = 25, evolutions = { { species = "RAICHU" } } },
  RAICHU = { dex = 26, evolutions = { { species = "GOROCHU" } } },
  GOROCHU = { dex = 1026, evolutions = {} },
  MEWTWO = { dex = 150, evolutions = {} },
  DITTO = { dex = 132, evolutions = {} },
} } }
local femalePikachu = { species = "PIKACHU", dvs = { attack = 7 } }
local malePikachu = { species = "PIKACHU", dvs = { attack = 9 } }
local compatible, eggChance = daycare.compatible(
  breedingGame, femalePikachu, malePikachu)
T.eq(compatible, true, "opposite-gender compatible parents can produce eggs")
T.eq(eggChance, 70, "same-species parents receive the best egg chance")
local legendaryCompatible = daycare.compatible(breedingGame,
  { species = "MEWTWO", dvs = { attack = 8 } },
  { species = "DITTO", dvs = { attack = 9 } })
T.eq(legendaryCompatible, false, "legendary Pokémon cannot breed")
T.eq(daycare.babyFor(breedingGame, "RAICHU"), "PICHU",
  "the evolution graph resolves Raichu eggs to Pichu")
T.eq(daycare.babyFor(breedingGame, "GOROCHU"), "PICHU",
  "Gorochu breeding still resolves to the Pichu family root")
local shinySystem = ex.shinySystem
T.neq(shinySystem, nil,
  "the self-contained Generation-II shiny controller is exported")
T.eq(shinySystem.isShiny(crystalShinyMon), true,
  "Defense/Speed/Special 10 plus a valid Attack DV is shiny")
T.eq(shinySystem.isShiny({
  dvs = { attack = 10, defense = 9, speed = 10, special = 10 },
}), false, "near-miss DV combinations are not shiny")
local femaleShinyParent = {
  species = "PIKACHU",
  dvs = { attack = 7, defense = 10, speed = 10, special = 10, hp = 0 },
}
local maleParent = {
  species = "PIKACHU",
  dvs = { attack = 9, defense = 4, speed = 4, special = 4, hp = 0 },
}
local inheritedRolls = { 10, 3, 10, 10 }
local inheritedIndex = 0
local inherited = daycare.inheritedDVs(
  breedingGame, "PIKACHU", femaleShinyParent, maleParent, function()
    inheritedIndex = inheritedIndex + 1
    return inheritedRolls[inheritedIndex]
  end)
T.eq(inherited.defense, 10,
  "a male Gen-II egg inherits Defense from its female parent")
T.eq(inherited.special, 10,
  "a Gen-II egg inherits the donor's low three Special-DV bits")
T.eq(shinySystem.isShiny({ dvs = inherited }), true,
  "canonical inherited DVs can produce the authentic 1/64 shiny result")
local dittoShiny = {
  species = "DITTO",
  dvs = { attack = 10, defense = 10, speed = 10, special = 10, hp = 0 },
}
local tooSimilar, _ = daycare.compatible(
  breedingGame, femaleShinyParent, dittoShiny)
T.eq(tooSimilar, false,
  "Crystal's matching Defense/Special-DV rule also applies to Ditto")
T.eq(daycare.reserveEgg("TOGEPI", 1024, "TEST RESEARCH", "TOGEPI"), true,
  "research eggs can be reserved at Route 5")
local reservedSpecies, reservedSteps, reservedLocation =
  daycare.researchEggStatus({ save = { party = {} } })
T.eq(reservedSpecies, "TOGEPI", "reserved research egg retains its species")
T.eq(reservedSteps, 1024, "reserved research egg retains its hatch distance")
T.eq(reservedLocation, "reserved", "research egg reports the Day-Care location")

-- ------------------------------------------------ official Mega Evolution

local mega = ex.megaEvolution
T.neq(mega, nil, "the official-species Mega controller is exported")
T.eq(#mega.forms, 30,
  "the Kanto/Johto roster contains the 30 official forms available by July 2026")
local megaSpeciesCount = 0
for _ in pairs(mega.formsBySpecies) do megaSpeciesCount = megaSpeciesCount + 1 end
T.eq(megaSpeciesCount, 27,
  "the official forms belong to exactly 27 of the first 251 species")
T.eq(#mega.secretForms, 1,
  "fan-made secret forms are exported outside the official Mega catalog")
T.eq(mega.formsBySpecies.TYPHLOSION, nil,
  "Ascendant Typhlosion never appears as an official Mega Evolution")
T.eq(mega.secretForms[1].id, "TYPHLOSION_ASCENDANT",
  "the single secret form has an explicit non-official identity")
T.same(mega.secretForms[1].types, { "FIRE", "GROUND" },
  "the volcanic secret form adapts to Fire/Ground in the Kanto battle model")
T.eq(mega.formsBySpecies.PIKACHU, nil,
  "Pikachu has no invented Mega Evolution")
T.eq(#mega.formsBySpecies.CHARIZARD, 2,
  "Charizard has distinct X and Y stone profiles")
T.eq(#mega.formsBySpecies.MEWTWO, 2,
  "Mewtwo has distinct X and Y stone profiles")
T.eq(#mega.formsBySpecies.RAICHU, 2,
  "Raichu has distinct official X and Y stone profiles")
T.eq(mega.formsBySpecies.GOROCHU, nil,
  "choosing permanent Gorochu keeps Mega Raichu X/Y exclusive to Raichu")
local xProfile = mega.formsBySpecies.RAICHU[1]
local yProfile = mega.formsBySpecies.RAICHU[2]
local xBonuses = xProfile.bonuses
T.eq(xBonuses.attack > xBonuses.special, true,
  "Mega Raichu X favors physical power")
local yBonuses = yProfile.bonuses
T.eq(yBonuses.speed > yBonuses.defense, true,
  "Mega Raichu Y favors speed")
do
  (function(profiles)
    local raichuBaseTotal, gorochuBaseTotal = 0, 0
    for _, value in pairs(Data.pokemon.RAICHU.baseStats) do
      raichuBaseTotal = raichuBaseTotal + value
    end
    for _, value in pairs(Data.pokemon.GOROCHU.baseStats) do
      gorochuBaseTotal = gorochuBaseTotal + value
    end
    for _, profile in ipairs(profiles) do
      local megaTotal = raichuBaseTotal
      for _, value in pairs(profile.bonuses) do
        megaTotal = megaTotal + value
      end
      T.eq(megaTotal, 495,
        profile.id .. " totals 495 in the Gen-I five-stat model")
      local lead = (gorochuBaseTotal / megaTotal - 1) * 100
      T.eq(lead >= 10 and lead <= 15, true,
        "Gorochu is 10-15 percent stronger than " .. profile.id)
    end
  end)({ xProfile, yProfile })
end
T.eq(xProfile.stone, "RAICHUNITE_X",
  "Mega Raichu X requires its own stone")
T.eq(yProfile.stone, "RAICHUNITE_Y",
  "Mega Raichu Y requires a different stone")
T.eq(mega.stoneName(xProfile), "RAICHUNITE X",
  "Mega Stone display names never expose internal underscore IDs")
T.eq(mega.caseLabel(mega.formsBySpecies.CHARIZARD[1]), "CHARIZARD X",
  "the compact Stone Case label preserves X/Y form identity")
T.eq(#mega.caseLabel(mega.formsBySpecies.KANGASKHAN[1]) <= 13, true,
  "the longest Stone Case species label fits the Gen-1 menu")
local seenMegaStones = {}
for _, profile in ipairs(mega.forms) do
  local total = profile.bonuses.attack + profile.bonuses.defense
    + profile.bonuses.speed + profile.bonuses.special
  T.eq(total, 100, profile.id .. " adapts exactly +100 points to Gen 1")
  T.eq(seenMegaStones[profile.stone], nil,
    profile.stone .. " belongs to only one Mega form")
  seenMegaStones[profile.stone] = true
  T.neq(profile.asset, nil,
    profile.id .. " has a dedicated installed battle asset")
  for _, side in ipairs({ "front", "back" }) do
    for _, variant in ipairs({ "normal", "shiny" }) do
      local suffix = side .. (variant == "shiny" and "_shiny" or "")
      local master = ("assets/mega/%s_%s.png"):format(profile.asset, suffix)
      local handle = io.open(modPath .. "/" .. master, "rb")
      T.neq(handle, nil, master .. " is packaged")
      if handle then handle:close() end
      local gen1 = ("assets/mega_gen1_runtime/%s_%s.png")
        :format(profile.asset, suffix)
      local gen1Handle = io.open(modPath .. "/" .. gen1, "rb")
      T.neq(gen1Handle, nil, gen1 .. " is packaged")
      if gen1Handle then gen1Handle:close() end
      local timings = mega.animationData[profile.id][side][variant]
      T.eq(#timings >= 3, true,
        profile.id .. " " .. side .. "/" .. variant
          .. " has a real motion loop")
      for frame = 1, #timings do
        local relative = (
          "assets/mega_animated/%s/%s/%s/%03d.png")
          :format(profile.asset, side, variant, frame)
        local frameHandle = io.open(modPath .. "/" .. relative, "rb")
        T.neq(frameHandle, nil, relative .. " is packaged")
        if frameHandle then frameHandle:close() end
      end
    end
  end
end
local boosted = mega.boostedStats({
  mon = { species = "RAICHU", level = 100,
    stats = { hp = 200, attack = 100, defense = 100, speed = 100, special = 100 } },
  curStats = { hp = 200, attack = 100, defense = 100, speed = 100, special = 100 },
}, xProfile)
T.eq(boosted.hp, 200, "Mega Evolution never changes HP")
T.eq(boosted.attack, 180,
  "level-100 Mega Raichu X receives its formula-correct Attack boost")

-- Yellow's lab partner keeps one persistent identity through the optional
-- Thunderheart quest, ordinary Raichu evolution and direct Mega resonance.
do
  local yellowPartner = ex.yellowPartner
  T.neq(yellowPartner, nil,
    "the Yellow partner controller is exported")
  T.eq(Data.items.ASCENDANT_THUNDERHEART.keyItem, true,
    "THUNDERHEART is a permanent key item")
  T.eq(Data.items.ASCENDANT_THUNDERHEART.tossable, false,
    "THUNDERHEART can never be discarded")
  T.eq(Data.items.ASCENDANT_THUNDERHEART.price, 0,
    "THUNDERHEART cannot be sold")

  local priorModSave = run.loader.modSave
  local priorPartnerGame = yellowPartner.game
  local priorMegaGame = mega.game
  local realGameVersion = require("src.core.GameVersion")
  local fakeYellow = { isYellow = function() return true end }
  local oldPikachuDef, oldRaichuDef =
    Data.pokemon.PIKACHU, Data.pokemon.RAICHU
  local function species(id, dex, stats)
    return {
      id = id, name = id, dex = dex, baseStats = stats,
      types = { "ELECTRIC" }, catchRate = 75, baseExp = 100,
      level1Moves = {}, growthRate = "MEDIUM_FAST", tmhm = {},
      learnset = {}, evolutions = {},
      spriteFront = "tests/fixture_data/assets/fixmon_a_front.png",
      spriteBack = "tests/fixture_data/assets/fixmon_a_back.png",
      frontSize = 5, dexEntry = {},
    }
  end
  Data.pokemon.PIKACHU = species("PIKACHU", 25,
    { hp = 35, attack = 55, defense = 30, speed = 90, special = 50 })
  Data.pokemon.RAICHU = species("RAICHU", 26,
    { hp = 60, attack = 90, defense = 55, speed = 100, special = 90 })

  local function mon(speciesId)
    return {
      species = speciesId, level = 50, hp = 100,
      ot = "YELLOW", otId = 25, moves = {},
      dvs = { attack = 9, defense = 8, speed = 8, special = 8, hp = 8 },
      statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
      stats = {
        hp = 100, attack = 80, defense = 60, speed = 100, special = 70,
      },
    }
  end
  local function yellowGame(party, badge)
    local pushed = {}
    return {
      data = Data,
      save = {
        flags = { EVENT_GOT_STARTER = true, EVENT_CHOSE_PIKACHU = true },
        inventory = badge and { THUNDERBADGE = true } or {},
        bagOrder = {}, party = party, boxes = {},
        player = { name = "YELLOW", id = 25 },
        pokedex = { seen = {}, owned = {} },
      },
      stack = {
        push = function(_, screen) pushed[#pushed + 1] = screen end,
        pop = function() return table.remove(pushed) end,
        top = function() return pushed[#pushed] end,
      },
      _pushed = pushed,
    }
  end

  local function reactionAt(happiness, mood, status, hp, speciesId)
    local reactionMon = mon(speciesId or "RAICHU")
    reactionMon.status = status
    reactionMon.hp = hp == nil and reactionMon.hp or hp
    local reactionGame = yellowGame({ reactionMon }, true)
    reactionGame.save.pikachuHappiness = happiness
    reactionGame.save.pikachuMood = mood
    return yellowPartner.raichuReaction(reactionGame, reactionMon)
  end

  local partnerTextKey = "_CeladonMansion1Text10"
  local previousPartnerText = Data.text[partnerTextKey]
  Data.text[partnerTextKey] = "Your PIKACHU looks happy."
  local textMon = mon("RAICHU")
  textMon[yellowPartner.marker] = true
  local textGame = yellowGame({ textMon }, true)
  T.eq(yellowPartner._adaptPartnerText(
      textGame, Data.text[partnerTextKey]),
    "Your RAICHU looks happy.",
    "Yellow NPC text follows the evolved partner's Raichu identity")
  textMon.species = "GOROCHU"
  T.eq(yellowPartner._adaptPartnerText(
      textGame, Data.text[partnerTextKey]),
    "Your GOROCHU looks happy.",
    "Yellow NPC text follows the evolved partner's Gorochu identity")
  T.eq(yellowPartner._adaptPartnerText(
      textGame, "My PIKACHU is adorable."),
    "My PIKACHU is adorable.",
    "unrelated NPC-owned Pikachu text is never rewritten")
  Data.text[partnerTextKey] = previousPartnerText

  local sleepyReaction = reactionAt(230, 128, "SLP")
  T.eq(sleepyReaction.id, "sleepy",
    "a sleeping partner Raichu receives its own mood")
  T.eq(sleepyReaction.bubble, "ZZZ_BUBBLE",
    "sleeping Raichu uses the sleep bubble")
  T.eq(sleepyReaction.portrait.sequence[1], 1,
    "sleeping Raichu starts with its dedicated closed-eye portrait")
  local unwellReaction = reactionAt(230, 128, "PSN")
  T.eq(unwellReaction.id, "unwell",
    "a status-afflicted partner Raichu looks unwell")
  local upsetReaction = reactionAt(30, 128)
  T.eq(upsetReaction.id, "upset",
    "very low bond gives Raichu an upset reaction")
  T.eq(upsetReaction.turnAway, true,
    "upset Raichu turns away from the player")
  T.eq(reactionAt(90, 128).id, "wary",
    "low bond gives Raichu a wary reaction")
  T.eq(reactionAt(150, 128).id, "content",
    "mid bond gives Raichu a content reaction")
  local contentReaction = reactionAt(150, 128)
  T.eq(contentReaction.portrait.sequence[1], 1,
    "content Raichu starts with its dedicated gentle smile")
  local devotedReaction = reactionAt(220, 128)
  T.eq(devotedReaction.id, "devoted",
    "high bond gives Raichu a devoted reaction")
  T.eq(devotedReaction.portrait.sequence[1], 1,
    "devoted Raichu starts with its dedicated clasped-paw face")
  local excitedReaction = reactionAt(240, 150)
  T.eq(excitedReaction.id, "excited",
    "high bond and mood give Raichu an excited reaction")
  T.eq(excitedReaction.text:find("RAI-RAICHU!", 1, true), 1,
    "Raichu explicitly speaks its species cry in follower dialogue")
  local reactions = {
    sleepyReaction,
    unwellReaction,
    upsetReaction,
    reactionAt(90, 128),
    contentReaction,
    devotedReaction,
    excitedReaction,
  }
  local voices, portraitLoops = {}, {}
  for _, reaction in ipairs(reactions) do
    T.eq(type(reaction.voice) == "string"
      and reaction.voice:match("^ASCENDANT_RAICHU_VOICE_") ~= nil,
      true,
      reaction.id .. " Raichu reaction selects a spoken voice clip")
    T.eq(not voices[reaction.voice], true,
      reaction.id .. " Raichu reaction has a distinct voice clip")
    voices[reaction.voice] = true
    local voiceDef = run.loader.content.sfx:get(reaction.voice)
    T.eq(type(voiceDef) == "table"
      and type(voiceDef.file) == "string"
      and voiceDef.file:find(
        "assets/audio/partner_raichu/raichu_" .. reaction.id .. ".wav",
        1, true) ~= nil,
      true,
      reaction.id .. " Raichu voice is registered from the mod package")
    local portrait = reaction.portrait
    T.eq(type(portrait) == "table"
      and type(portrait.sequence) == "table"
      and #portrait.sequence > 1
      and tonumber(portrait.ticks) > 0
      and tonumber(portrait.hold) > portrait.ticks,
      true,
      reaction.id .. " Raichu portrait has a timed multi-frame animation")
    local signature = table.concat(portrait.sequence, ",")
      .. ":" .. tostring(portrait.ticks)
    T.eq(not portraitLoops[signature], true,
      reaction.id .. " Raichu portrait loop is mood-specific")
    portraitLoops[signature] = true
    local files = yellowPartner._portraitFrames(
      mon("RAICHU"), reaction)
    T.eq(files[1]:find(
      "assets/yellow_partner_raichu_portraits/normal/"
        .. reaction.id .. "/001.png", 1, true) ~= nil,
      true, reaction.id .. " Raichu uses its own facial artwork")
    for _, path in ipairs(files) do
      local handle = io.open(packagedPath(path), "rb")
      T.neq(handle, nil,
        reaction.id .. " Raichu portrait frame is packaged")
      if handle then handle:close() end
    end
  end
  local portraitOw = {
    emote = {
      frames = 20, pikaTotal = 20,
      pikaPic = "frame-one",
      _ascendantRaichuFrames = { "frame-one", "frame-two" },
      _ascendantRaichuTicks = 4,
    },
  }
  yellowPartner._advanceRaichuPortrait(portraitOw)
  T.eq(portraitOw.emote.pikaPic, "frame-one",
    "Raichu portrait animation starts on its first frame")
  portraitOw.emote.frames = 16
  yellowPartner._advanceRaichuPortrait(portraitOw)
  T.eq(portraitOw.emote.pikaPic, "frame-two",
    "Raichu portrait animation advances while the framed emote is active")
  T.eq(yellowPartner._portraitBoxX(
    { camera = { x = 0 } }, { px = 40 }), 12,
    "a left-side emotion bubble moves the Raichu portrait to the right")
  T.eq(yellowPartner._portraitBoxX(
    { camera = { x = 0 } }, { px = 100 }), 1,
    "a right-side emotion bubble moves the Raichu portrait to the left")
  local sleepyPortraitFiles = yellowPartner._portraitFrames(
    mon("RAICHU"), sleepyReaction)
  T.eq(sleepyPortraitFiles[1]:find(
    "assets/yellow_partner_raichu_portraits/normal/sleepy/001.png",
    1, true) ~= nil, true,
    "sleepy Raichu uses the supplied custom portrait")
  local contentPortraitFiles = yellowPartner._portraitFrames(
    mon("RAICHU"), contentReaction)
  T.eq(contentPortraitFiles[1]:find(
    "assets/yellow_partner_raichu_portraits/normal/content/001.png",
    1, true) ~= nil, true,
    "happy Raichu uses the supplied dedicated expression")
  T.eq(Data.pokemon.RAICHU.spriteFront:find(
    "yellow_partner_raichu_portraits", 1, true) == nil, true,
    "dedicated reaction faces do not replace Raichu's battle front sprite")

  local gorochuReactions = {
    reactionAt(230, 128, "SLP", nil, "GOROCHU"),
    reactionAt(230, 128, "PSN", nil, "GOROCHU"),
    reactionAt(30, 128, nil, nil, "GOROCHU"),
    reactionAt(90, 128, nil, nil, "GOROCHU"),
    reactionAt(150, 128, nil, nil, "GOROCHU"),
    reactionAt(220, 128, nil, nil, "GOROCHU"),
    reactionAt(240, 150, nil, nil, "GOROCHU"),
  }
  local gorochuMoods = {
    "sleepy", "unwell", "upset", "wary",
    "content", "devoted", "excited",
  }
  for index, reaction in ipairs(gorochuReactions) do
    local mood = gorochuMoods[index]
    T.eq(reaction.id, mood,
      "partner Gorochu selects its " .. mood .. " reaction")
    T.eq(reaction.voice, nil,
      mood .. " Gorochu uses its registered species cry")
    local files = yellowPartner._portraitFrames(mon("GOROCHU"), reaction)
    T.eq(#files > 1, true,
      mood .. " Gorochu portrait has a live animation loop")
    T.eq(files[1]:find(
      "assets/yellow_partner_gorochu_portraits/normal/"
        .. mood .. "/001.png", 1, true) ~= nil,
      true, mood .. " Gorochu uses its own facial artwork")
    for _, path in ipairs(files) do
      local handle = io.open(packagedPath(path), "rb")
      T.neq(handle, nil,
        mood .. " Gorochu portrait frame is packaged")
      if handle then handle:close() end
    end
  end
  T.eq(gorochuReactions[7].text:find(
    "GORO-GOROCHU!", 1, true), 1,
    "Gorochu says its own name in the excited partner dialogue")
  T.eq(Data.pokemon.GOROCHU.spriteFront:find(
    "yellow_partner_gorochu_portraits", 1, true) == nil, true,
    "Gorochu's seven faces never replace its battle sprite")

  run.loader.modSave = {}
  local legacyMon = mon("PIKACHU")
  local legacyGame = yellowGame({ legacyMon }, true)
  yellowPartner.install(legacyGame, { gameVersion = fakeYellow })
  T.eq(yellowPartner.partner(legacyGame), legacyMon,
    "an unambiguous upgraded Yellow save adopts its original partner")
  T.eq(legacyMon[yellowPartner.marker], true,
    "the adopted partner receives a persistent per-Pokémon marker")
  T.eq(legacyGame.save.inventory[yellowPartner.itemId], 1,
    "an old post-Surge Yellow save receives THUNDERHEART in its Bag")
  T.eq(yellowPartner.state().legacy, true,
    "the old save skips the early quest grind safely")

  run.loader.modSave = {}
  local earlyLegacyMon = mon("PIKACHU")
  local earlyLegacyGame = yellowGame({ earlyLegacyMon }, false)
  yellowPartner.install(earlyLegacyGame, { gameVersion = fakeYellow })
  T.eq(earlyLegacyGame.save.inventory[yellowPartner.itemId], 1,
    "an old pre-Surge Yellow save also receives THUNDERHEART in its Bag")

  run.loader.modSave = {}
  local ambiguousA, ambiguousB = mon("PIKACHU"), mon("RAICHU")
  local ambiguousGame = yellowGame({ ambiguousA, ambiguousB }, true)
  yellowPartner.install(ambiguousGame, { gameVersion = fakeYellow })
  T.eq(yellowPartner.partner(ambiguousGame), nil,
    "multiple old self-owned candidates are never guessed automatically")
  T.eq(ambiguousGame.save.inventory[yellowPartner.itemId], 1,
    "an ambiguous old save still receives its permanent story item")

  run.loader.modSave = {
    trainer_rematch = {
      yellow_partner = {
        version = 1, initialized = true,
        offered = true, accepted = true, heartGiven = true,
        steps = yellowPartner.requiredSteps,
        wins = yellowPartner.requiredWins,
        choice = "stay",
      },
    },
  }
  local oldStayMon = mon("PIKACHU")
  oldStayMon[yellowPartner.marker] = true
  local oldStayGame = yellowGame({ oldStayMon }, true)
  oldStayGame.save.inventory[yellowPartner.itemId] = 1
  yellowPartner.install(oldStayGame, { gameVersion = fakeYellow })
  local migratedRows = yellowPartner._choiceRows(oldStayMon)
  T.eq(#migratedRows, 3,
    "a 5.4.0 stay choice without the new Pokémon marker asks again")
  T.eq(migratedRows[2].value, "stay",
    "legacy cosmetic consent never claims Thunderheart Awakening")
  T.eq(oldStayMon[yellowPartner.awakeningMarker], nil,
    "migration never stamps Awakening without explicit new consent")

  -- A new game initializes the feature state before Oak gives the starter,
  -- so it follows the optional quest instead of the legacy shortcut.
  run.loader.modSave = {
    trainer_rematch = { yellow_partner = { initialized = true } },
  }
  local questMon = mon("PIKACHU")
  local questGame = yellowGame({ questMon }, false)
  yellowPartner.install(questGame, { gameVersion = fakeYellow })
  local quest = yellowPartner.state()
  quest.offered, quest.accepted = true, true
  local activeHeartRow = yellowPartner._ascendantMenuRow(questGame)
  T.eq(activeHeartRow.ascendantLabel, "THUNDERHEART",
    "the Ascendant submenu uses the compact permanent-item name")
  T.eq(activeHeartRow.right, "ACTIVE",
    "the compact row never displays the old overlapping 0/3 counter")
  for _ = 1, yellowPartner.requiredSteps do
    run.loader.events:emit("world.stepped", {})
  end
  for _ = 1, yellowPartner.requiredWins do
    run.loader.events:emit("battle.ended", {
      result = "win",
      battle = { game = questGame, kind = "trainer", trainer = {} },
    })
  end
  T.eq(yellowPartner.questReady(), true,
    "251 shared steps and three trainer wins complete the early bond trial")
  T.eq(yellowPartner._ascendantMenuRow(questGame).right, "READY",
    "the completed bond trial replaces ACTIVE with READY")
  questGame.save.inventory.THUNDERBADGE = true
  local surge = {
    def = { name = "VERMILIONGYM_LT_SURGE" },
    facePlayer = function() end,
  }
  local surgeOw = {
    map = { id = "VERMILION_GYM" },
    player = {},
  }
  T.eq(yellowPartner.handleTalk(surgeOw, surge, questGame), true,
    "returning to Surge claims the completed quest reward")
  T.eq(questGame.save.inventory[yellowPartner.itemId], 1,
    "the completed quest puts exactly one THUNDERHEART in the Bag")

  local Stats = require("src.pokemon.Stats")
  local SaveData = require("src.core.SaveData")
  local beforeRows = yellowPartner._choiceRows(questMon)
  T.eq(#beforeRows, 3,
    "pre-Awakening Thunderheart offers Evolve, Stay and Not Yet")
  T.eq(beforeRows[1].value, "evolve",
    "Evolve is the first pre-Awakening choice")
  T.eq(beforeRows[2].value, "stay",
    "Stay is available before explicit Awakening consent")
  T.eq(beforeRows[3].value, "later",
    "Not Yet remains the final pre-Awakening choice")

  -- Opening and cancelling the actual ListMenu does not claim the gift.
  yellowPartner.openHeart(questGame)
  local bondBox = questGame.stack:top()
  T.neq(bondBox and bondBox.onDone, nil,
    "Thunderheart opens the partner bond preface")
  bondBox.onDone()
  local cancelMenu = questGame.stack:top()
  T.eq(cancelMenu.items[2].value, "stay",
    "the live pre-Awakening menu contains Stay")
  cancelMenu.onCancel()
  T.eq(questMon[yellowPartner.awakeningMarker], nil,
    "cancelling the choice menu changes no Awakening state")

  -- Declining Stay's warning reopens all three choices without mutation.
  yellowPartner._confirmChoice(questGame, questMon, "stay")
  local declinedStay = questGame.stack:top()
  T.eq(type(declinedStay.choice), "function",
    "Stay is protected by an explicit confirmation")
  declinedStay.choice(false)
  local reopened = questGame.stack:top()
  T.eq(#reopened.items, 3,
    "No at the Stay warning reopens the full choice")
  T.eq(questMon[yellowPartner.awakeningMarker], nil,
    "No at the Stay warning grants no hidden stat state")

  local choiceBeforeLater = yellowPartner.state().choice
  yellowPartner._confirmChoice(questGame, questMon, "later")
  local declinedLater = questGame.stack:top()
  T.eq(type(declinedLater.choice), "function",
    "Not Yet is also protected by an explicit confirmation")
  declinedLater.choice(false)
  T.eq(#questGame.stack:top().items, 3,
    "No at Not Yet reopens the choice")
  T.eq(yellowPartner.state().choice, choiceBeforeLater,
    "declining Not Yet changes no persistent state")
  yellowPartner._confirmChoice(questGame, questMon, "later")
  questGame.stack:top().choice(true)
  T.eq(yellowPartner.state().choice, choiceBeforeLater,
    "confirmed Not Yet still changes no persistent state")
  T.eq(questMon[yellowPartner.awakeningMarker], nil,
    "confirmed Not Yet never claims Awakening")

  questMon.nickname = "SPARK"
  questMon.shiny = true
  questMon.memories = { first = "OAKS_LAB", bond = 251 }
  questMon.dvs = {
    attack = 10, defense = 10, speed = 10, special = 10, hp = 0,
  }
  questMon.statExp = {
    hp = 1024, attack = 2048, defense = 3072,
    speed = 4096, special = 5120,
  }
  questMon.moves = {
    { id = "THUNDERSHOCK", pp = 20 },
    { id = "AGILITY", pp = 30 },
  }
  questMon.stats = Stats.calc(
    Data.pokemon.PIKACHU, questMon.level, questMon.dvs, questMon.statExp)
  local damageBeforeAwakening = 7
  questMon.hp = questMon.stats.hp - damageBeforeAwakening
  local keptDvs, keptStatExp = questMon.dvs, questMon.statExp
  local keptMoves, keptMemories = questMon.moves, questMon.memories
  local keptNickname, keptOT, keptOTId, keptShiny =
    questMon.nickname, questMon.ot, questMon.otId, questMon.shiny

  yellowPartner._confirmChoice(questGame, questMon, "stay")
  local acceptedStay = questGame.stack:top()
  acceptedStay.choice(true)
  T.eq(questMon[yellowPartner.awakeningMarker], true,
    "confirmed Stay stamps the permanent Pokémon Awakening marker")
  T.eq(yellowPartner.isAwakened(questMon), true,
    "only the marked partner Pikachu qualifies as awakened")
  local raichuEquivalent = Stats.calc(
    Data.pokemon.RAICHU, questMon.level, questMon.dvs, questMon.statExp)
  T.same(questMon.stats, raichuEquivalent,
    "awakened Pikachu calculates exactly from Raichu's dynamic base stats")
  local frozenEngineStyle = Stats.calc(
    Data.pokemon.PIKACHU, questMon.level, questMon.dvs, questMon.statExp)
  T.same(frozenEngineStyle, raichuEquivalent,
    "the mod-only shim preserves Awakening on the frozen four-argument Stats API")
  T.eq(questMon.hp, raichuEquivalent.hp - damageBeforeAwakening,
    "Awakening preserves the exact amount of HP already lost")
  T.eq(questMon.dvs, keptDvs,
    "Awakening preserves the original DV table and shiny formula")
  T.eq(questMon.statExp, keptStatExp,
    "Awakening never manufactures or replaces stat experience")
  T.eq(questMon.moves, keptMoves,
    "Awakening preserves Pikachu's moveset")
  T.eq(questMon.memories, keptMemories,
    "Awakening preserves partner memories")
  T.eq(questMon.nickname, keptNickname,
    "Awakening preserves the nickname")
  T.eq(questMon.ot, keptOT,
    "Awakening preserves original-trainer name")
  T.eq(questMon.otId, keptOTId,
    "Awakening preserves original-trainer id")
  T.eq(questMon.shiny, keptShiny,
    "Awakening preserves explicit shiny state")
  T.eq(yellowPartner.partner(questGame), questMon,
    "Awakening preserves exact partner table identity")

  local afterRows = yellowPartner._choiceRows(questMon)
  T.eq(#afterRows, 2,
    "only Stay disappears after confirmed Awakening")
  T.eq(afterRows[1].value, "evolve",
    "Evolve remains available after Awakening")
  T.eq(afterRows[2].value, "later",
    "Not Yet remains available after Awakening")
  T.eq(yellowPartner._ascendantMenuRow(questGame).right, "AWAKE",
    "the compact submenu reports Awakening without an item count")

  local statsAfterFirstGift = SaveData.decode(
    SaveData.encode(questMon.stats))
  T.eq(yellowPartner.awaken(questGame, questMon), false,
    "the one-time gift cannot be applied twice")
  T.same(questMon.stats, statsAfterFirstGift,
    "a repeated use cannot stack Raichu's base stats")

  local ordinaryPikachu = mon("PIKACHU")
  ordinaryPikachu[yellowPartner.awakeningMarker] = true
  local ordinaryStats = Stats.calc(Data.pokemon.PIKACHU,
    ordinaryPikachu.level, ordinaryPikachu.dvs,
    ordinaryPikachu.statExp, ordinaryPikachu)
  local ordinaryExpected = Stats.calc(Data.pokemon.PIKACHU,
    ordinaryPikachu.level, ordinaryPikachu.dvs, ordinaryPikachu.statExp)
  T.same(ordinaryStats, ordinaryExpected,
    "an unmarked ordinary Pikachu never receives Awakening stats")

  -- Rare Candy exercises the real level-up item path, which now forwards
  -- the concrete Pokémon through the centralized stat resolver.
  local ItemEffects = require("src.inventory.ItemEffects")
  local candyResult = ItemEffects.use(
    Data, questGame.save, "RARE_CANDY", questMon, nil)
  T.eq(candyResult, "consumed",
    "Rare Candy remains usable on the awakened partner")
  local levelRaichu = Stats.calc(Data.pokemon.RAICHU,
    questMon.level, questMon.dvs, questMon.statExp)
  T.same(questMon.stats, levelRaichu,
    "the Raichu-equivalent profile survives a real level-up recalculation")

  -- Serialization and the box/status ensure path retain the marker and
  -- rebuild from Raichu while the stored species stays Pikachu.
  local loadedSave = SaveData.decode(SaveData.encode(questGame.save))
  local loadedPartner = loadedSave.party[1]
  T.eq(loadedPartner[yellowPartner.awakeningMarker], true,
    "save/load serialization preserves the Awakening marker")
  loadedPartner.stats = nil
  Stats.ensure(Data.pokemon.PIKACHU, loadedPartner)
  T.same(loadedPartner.stats, Stats.calc(Data.pokemon.RAICHU,
    loadedPartner.level, loadedPartner.dvs, loadedPartner.statExp),
    "box/status stat restoration preserves Raichu-equivalent strength")

  local faintedPartner = mon("PIKACHU")
  faintedPartner[yellowPartner.marker] = true
  faintedPartner.stats = Stats.calc(Data.pokemon.PIKACHU,
    faintedPartner.level, faintedPartner.dvs, faintedPartner.statExp)
  faintedPartner.hp = 0
  questMon[yellowPartner.marker] = nil
  questGame.save.party[1] = faintedPartner
  T.eq(yellowPartner.awaken(questGame, faintedPartner), true,
    "a separate zero-HP fixture can claim its one permitted Awakening")
  T.eq(faintedPartner.hp, 0,
    "Awakening never revives a fainted partner")
  faintedPartner[yellowPartner.marker] = nil
  questMon[yellowPartner.marker] = true
  questGame.save.party[1] = questMon

  mega.install(questGame)
  local megaState = mega.state()
  megaState.ring = true
  mega.grantStone("RAICHUNITE_X")
  mega.grantStone("RAICHUNITE_Y")
  megaState.preferences.RAICHU = "RAICHU_X"
  questMon[yellowPartner.marker] = true
  local directProfile = mega.profileFor(questMon, false)
  T.eq(directProfile and directProfile.id, "RAICHU_X",
    "the marked unevolved partner answers an owned Raichunite directly")
  T.eq(mega.profileFor(mon("PIKACHU"), false), nil,
    "an ordinary Pikachu never gains the partner-only Mega path")
  local directStats = mega.boostedStats({
    mon = questMon,
    curStats = questMon.stats,
  }, directProfile)
  local raichuBase = Stats.calc(
    Data.pokemon.RAICHU, questMon.level, questMon.dvs, questMon.statExp)
  T.eq(directStats.hp, questMon.stats.hp,
    "direct partner resonance never changes Pikachu's live HP")
  T.eq(directStats.attack,
    raichuBase.attack + math.floor(2 * directProfile.bonuses.attack
      * questMon.level / 100),
    "direct resonance uses Raichu's base before applying Mega Raichu X")
  for _, profile in ipairs({ xProfile, yProfile }) do
    local transformed = mega.boostedStats({
      mon = questMon,
      curStats = questMon.stats,
    }, profile)
    for _, key in ipairs({ "attack", "defense", "speed", "special" }) do
      T.eq(transformed[key],
        raichuBase[key] + math.floor(
          2 * profile.bonuses[key] * questMon.level / 100),
        profile.id .. " applies its bonus to Raichu exactly once")
    end
    T.eq(transformed.hp, questMon.stats.hp,
      profile.id .. " remains a temporary no-heal transformation")
  end
  T.same(questMon.stats, raichuBase,
    "leaving the temporary Mega calculation keeps awakened Pikachu unchanged")

  local evolutionDamage = 9
  questMon.hp = questMon.stats.hp - evolutionDamage
  local beforeEvolutionStats = SaveData.decode(
    SaveData.encode(questMon.stats))
  local beforeEvolutionDvs = questMon.dvs
  local beforeEvolutionExp = questMon.statExp
  local beforeEvolutionMoves = questMon.moves
  local beforeEvolutionMemories = questMon.memories
  local priorImageFactory = love.image and love.image.newImageData
  if love.image then love.image.newImageData = nil end
  yellowPartner._evolvePartner(questGame, questMon)
  if love.image then love.image.newImageData = priorImageFactory end
  T.eq(questMon.species, "RAICHU",
    "an awakened partner may still evolve permanently to Raichu")
  T.same(questMon.stats, beforeEvolutionStats,
    "later evolution changes form without a second stat increase")
  T.eq(questMon.hp, questMon.stats.hp - evolutionDamage,
    "later evolution preserves the exact amount of lost HP")
  T.eq(questMon[yellowPartner.marker], true,
    "later evolution preserves Yellow's partner identity")
  T.eq(questMon[yellowPartner.awakeningMarker], true,
    "later evolution retains Awakening as harmless history")
  T.eq(questMon.dvs, beforeEvolutionDvs,
    "later evolution preserves DVs and shiny identity")
  T.eq(questMon.statExp, beforeEvolutionExp,
    "later evolution preserves stat experience")
  T.eq(questMon.moves, beforeEvolutionMoves,
    "later evolution preserves the existing Pikachu moves")
  T.eq(questMon.memories, beforeEvolutionMemories,
    "later evolution preserves partner memories")
  local postEvolutionCalc = Stats.calc(Data.pokemon.RAICHU,
    questMon.level, questMon.dvs, questMon.statExp, questMon)
  T.same(postEvolutionCalc, questMon.stats,
    "the historical marker does not reapply Raichu bases after evolution")

  local faintedEvolution = mon("PIKACHU")
  faintedEvolution[yellowPartner.marker] = true
  faintedEvolution[yellowPartner.awakeningMarker] = true
  faintedEvolution.stats = Stats.calc(Data.pokemon.PIKACHU,
    faintedEvolution.level, faintedEvolution.dvs,
    faintedEvolution.statExp, faintedEvolution)
  faintedEvolution.hp = 0
  questGame.save.party[1] = faintedEvolution
  local priorImageFactory2 = love.image and love.image.newImageData
  if love.image then love.image.newImageData = nil end
  yellowPartner._evolvePartner(questGame, faintedEvolution)
  if love.image then love.image.newImageData = priorImageFactory2 end
  T.eq(faintedEvolution.species, "RAICHU",
    "a fainted awakened partner may still take the chosen form")
  T.eq(faintedEvolution.hp, 0,
    "later evolution never revives a zero-HP partner")
  questGame.save.party[1] = questMon

  local fakeRed = { isYellow = function() return false end }
  local redMarked = mon("PIKACHU")
  redMarked[yellowPartner.marker] = true
  redMarked[yellowPartner.awakeningMarker] = true
  local redGame = yellowGame({ redMarked }, true)
  yellowPartner.install(redGame, { gameVersion = fakeRed })
  local redCalculated = Stats.calc(Data.pokemon.PIKACHU,
    redMarked.level, redMarked.dvs, redMarked.statExp, redMarked)
  T.same(redCalculated, Stats.calc(Data.pokemon.PIKACHU,
    redMarked.level, redMarked.dvs, redMarked.statExp),
    "Red and Blue ignore even a foreign copied Awakening marker")

  -- Restore a real Yellow partner controller before leaving this fixture.
  run.loader.modSave = priorModSave
  Data.pokemon.PIKACHU, Data.pokemon.RAICHU =
    oldPikachuDef, oldRaichuDef
  if priorPartnerGame then
    yellowPartner.install(priorPartnerGame, { gameVersion = realGameVersion })
  end
  if priorMegaGame then mega.install(priorMegaGame) end
end

local megaCtx = {
  species = "RAICHU", side = "front", trueColor = false,
  mon = { species = "RAICHU", _ascMegaForm = "RAICHU_X" },
}
local megaPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "raichu_fallback.png", megaCtx)
T.eq(megaPath:find(
    "assets/mega_runtime/mega_raichu_x_front.png", 1, true) ~= nil,
  true, "Mega Raichu X selects its dedicated sharp front sprite")
T.eq(megaCtx.trueColor, true,
  "animated Mega sprites preserve their authored palettes")
do
local ascendantTyphlosionCtx = {
  species = "TYPHLOSION", side = "front", trueColor = false,
  mon = {
    species = "TYPHLOSION", _ascMegaForm = "TYPHLOSION_ASCENDANT",
  },
}
local ascendantTyphlosionPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "typhlosion_fallback.png",
  ascendantTyphlosionCtx)
T.eq(ascendantTyphlosionPath:find(
    "assets/mega_runtime/ascendant_typhlosion_front.png", 1, true) ~= nil,
  true,
  "Ascendant Typhlosion selects its sharp dedicated front sprite")
T.eq(ascendantTyphlosionCtx.trueColor, true,
  "the secret form preserves its authored obsidian/cyan palette")
local shinyAscendantTyphlosionPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "typhlosion_fallback.png", {
    species = "TYPHLOSION", side = "back", trueColor = false,
    mon = {
      species = "TYPHLOSION", _ascMegaForm = "TYPHLOSION_ASCENDANT",
      shiny = true,
    },
  })
T.eq(shinyAscendantTyphlosionPath:find(
    "assets/mega_runtime/ascendant_typhlosion_back_shiny.png", 1, true)
  ~= nil, true,
  "the secret form has an independent shiny back sprite")
for side, variants in pairs(mega.animationData.TYPHLOSION_ASCENDANT) do
  for variant, timings in pairs(variants) do
    local expected = side == "front" and 23 or 12
    T.eq(#timings, expected,
      "Ascendant Typhlosion " .. side .. "/" .. variant
        .. " uses its full Crystal-driven motion loop")
    for frame = 1, #timings do
      local relative = (
        "assets/mega_animated/ascendant_typhlosion/%s/%s/%03d.png")
        :format(side, variant, frame)
      local handle = io.open(modPath .. "/" .. relative, "rb")
      T.neq(handle, nil, relative .. " is packaged")
      if handle then handle:close() end
    end
  end
end
end
do
local charizardXMon = {
  species = "CHARIZARD", _ascMegaForm = "CHARIZARD_X",
  dvs = { attack = 9, defense = 8, speed = 8, special = 8, hp = 8 },
}
local charizardXCtx = {
  species = "CHARIZARD", side = "front", trueColor = false,
  mon = charizardXMon,
}
local charizardXPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "charizard_fallback.png", charizardXCtx)
T.eq(charizardXPath:find(
    "assets/mega_runtime/mega_charizard_x_front.png", 1, true) ~= nil, true,
  "Mega Charizard X selects its dedicated detailed front sprite")
T.eq(charizardXCtx.trueColor, true,
  "Mega Charizard X preserves its authored blue Crystal palette")
local shinyCharizardXPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "charizard_fallback.png", {
    species = "CHARIZARD", side = "front", trueColor = false,
    mon = {
      species = "CHARIZARD", _ascMegaForm = "CHARIZARD_X",
      dvs = { attack = 10, defense = 10, speed = 10, special = 10, hp = 0 },
    },
  })
T.eq(shinyCharizardXPath:find(
    "assets/mega_runtime/mega_charizard_x_front_shiny.png", 1, true)
  ~= nil, true,
  "shiny Mega Charizard X selects its matching authored-palette art")
T.eq(#mega.animationData.CHARIZARD_X.front.normal >= 3, true,
  "Mega Charizard X ships with a side-aware detailed animation loop")
for side, variants in pairs(mega.animationData.CHARIZARD_X) do
  for variant, timings in pairs(variants) do
    for frame = 1, #timings do
      local relative = (
        "assets/mega_animated/mega_charizard_x/%s/%s/%03d.png")
        :format(side, variant, frame)
      local handle = io.open(modPath .. "/" .. relative, "rb")
      T.neq(handle, nil, relative .. " is packaged")
      if handle then handle:close() end
    end
  end
end
local megaAnimationBattle = {
  enemy = { mon = charizardXMon, sprite = {} },
  showEnemyTrainer = false,
  enemySendingOut = false,
}
mega.updateAnimations(megaAnimationBattle, 1.0)
T.neq(megaAnimationBattle.enemy.__ascendantMegaAnimation, nil,
  "Mega Charizard X receives an independent live animation state")
T.eq(megaAnimationBattle.enemy.__ascendantMegaAnimation.frame > 1, true,
  "Mega Charizard X animation advances using packaged timing")
run.loader.modOptions.trainer_rematch = {
  kanto_crystal_art = false,
  crystal_animation = false,
}
charizardXMon._ascMegaAnimationFrame = nil
local gen1CharizardCtx = {
  species = "CHARIZARD", side = "front", trueColor = true,
  mon = charizardXMon,
}
local gen1CharizardPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "charizard_fallback.png",
  gen1CharizardCtx)
T.eq(gen1CharizardPath:find(
    "assets/mega_gen1_runtime/mega_charizard_x_front.png", 1, true)
  ~= nil, true,
  "disabling Kanto Crystal art selects the four-shade Gen-I Mega card")
T.eq(gen1CharizardCtx.trueColor, false,
  "the Gen-I Mega card receives the active Red/Blue/Yellow monster palette")
megaAnimationBattle.enemy.__ascendantMegaAnimation = nil
mega.updateAnimations(megaAnimationBattle, 1.0)
T.eq(megaAnimationBattle.enemy.__ascendantMegaAnimation, nil,
  "the Gen-I Mega presentation remains authentically static")
run.loader.modOptions.trainer_rematch = {
  legend_art = "original",
  crystal_animation = false,
}
local gen1AmpharosCtx = {
  species = "AMPHAROS", side = "front", trueColor = true,
  mon = { species = "AMPHAROS", _ascMegaForm = "AMPHAROS" },
}
local gen1AmpharosPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "ampharos_fallback.png",
  gen1AmpharosCtx)
T.eq(gen1AmpharosPath:find(
    "assets/mega_gen1_runtime/mega_ampharos_front.png", 1, true)
  ~= nil, true,
  "JOHTO ART = KANTO FALLBACK also selects the Gen-I Johto Mega card")
T.eq(gen1AmpharosCtx.trueColor, false,
  "Johto Gen-I Mega art also receives the active edition palette")
run.loader.modOptions.trainer_rematch = nil
end
do
local removeCrystalKanto = run.loader.hooks:wrap(
  "pokemon.sprite", function(_, _, ctx)
    if ctx and ctx.species == "RAICHU" then
      ctx.trueColor = true
      return "external/crystal/raichu/001.png"
    end
  end, 930, "crystal_mega_compat_test")
local megaOverCrystalCtx = {
  species = "RAICHU", side = "front", trueColor = false,
  mon = { species = "RAICHU", _ascMegaForm = "RAICHU_X" },
}
local megaOverCrystalPath = RealRuntime.call("pokemon.sprite",
  function(path) return path end, "raichu_fallback.png", megaOverCrystalCtx)
T.eq(megaOverCrystalPath:find(
    "assets/mega_runtime/mega_raichu_x_front.png", 1, true) ~= nil, true,
  "Mega forms override the external Crystal mod's priority-930 Kanto art")
T.eq(megaOverCrystalCtx.trueColor, true,
  "Mega art restores its authored palette after external Crystal art")
removeCrystalKanto()
end

-- ------------------------------------------------ complete Johto catalogue

local johto = ex.johtoData
T.neq(johto, nil, "the Johto catalogue is exported")
T.eq(#johto.order, 100, "the complete Johto dex contains 100 species")
T.eq(johto.species.CHIKORITA.dex, 152,
  "Chikorita opens the canonical Johto dex at 152")
T.eq(johto.species.RAIKOU.dex, 243,
  "Raikou uses its canonical full-dex number")
T.eq(johto.species.HO_OH.dex, 250,
  "Ho-Oh uses its canonical full-dex number")
T.eq(johto.species.CELEBI.dex, 251,
  "Celebi closes the canonical full dex at 251")
local johtoDex, johtoIds = {}, {}
for _, id in ipairs(johto.order) do
  T.eq(johtoIds[id], nil, id .. " appears once in the species order")
  T.eq(johtoDex[johto.species[id].dex], nil,
    tostring(johto.species[id].dex) .. " is a unique dex number")
  johtoIds[id] = true
  johtoDex[johto.species[id].dex] = true
end
T.eq(johto.evolutions.CHIKORITA[1][2], "BAYLEEF",
  "starter evolution chains are recorded")
T.eq(johto.kantoEvolutions.EEVEE[1][1], "FRIENDSHIP_DAY",
  "Espeon uses the daytime friendship branch")
T.eq(johto.kantoEvolutions.EEVEE[2][1], "FRIENDSHIP_NIGHT",
  "Umbreon uses the nighttime friendship branch")
T.eq(johto.kantoEvolutions.SCYTHER[1][3], "METAL_COAT",
  "Scizor uses Elm's Metal Coat machine")
T.eq(#johto.rewards, 40,
  "forty non-duplicate Johto family rewards fill themed rematches")
T.eq(#johto.eggs, 8, "all eight Generation-II baby lines hatch from eggs")
local eeveePartners = 0
for _, row in ipairs(johto.partnerMilestones) do
  if row.species == "EEVEE" then eeveePartners = eeveePartners + 1 end
end
T.eq(eeveePartners, 2,
  "Elm supplies two Eevee so both friendship branches are obtainable")
T.eq(johto.finalReward, "LARVITAR",
  "Larvitar is reserved for completing every research track")
T.eq(johto.partyIcons.RAIKOU, "QUADRUPED",
  "Raikou uses the standard animated quadruped party icon")
T.eq(johto.partyIcons.ENTEI, "QUADRUPED",
  "Entei uses the standard animated quadruped party icon")
T.eq(johto.partyIcons.SUICUNE, "QUADRUPED",
  "Suicune uses the standard animated quadruped party icon")
T.eq(johto.partyIcons.LUGIA, "BIRD",
  "Lugia uses the standard animated bird party icon")
T.eq(johto.partyIcons.HO_OH, "BIRD",
  "Ho-Oh uses the standard animated bird party icon")
T.eq(johto.partyIcons.CELEBI, "FAIRY",
  "Celebi uses the standard animated Mew-like party icon")

;(function()
local johtoDexTexts, johtoLearnProfiles, johtoTmProfiles = {}, {}, {}
for _, id in ipairs(johto.order) do
  local def = johto.species[id]
  T.eq(type(def.level1), "table",
    id .. " has a species-authentic starting move set")
  T.eq(type(def.learnset), "table",
    id .. " has an explicit Crystal-shaped level-up plan")
  T.eq(type(def.tmhm), "table",
    id .. " has an explicit TM/HM compatibility profile")
  T.eq(type(def.dexEntry), "table",
    id .. " has individual bilingual Pokédex metadata")
  T.eq(type(def.dexEntry.kindEn), "string",
    id .. " has an English Pokédex classification")
  T.eq(type(def.dexEntry.kindDe), "string",
    id .. " has a German Pokédex classification")
  T.eq(def.dexEntry.heightM > 0, true,
    id .. " has its canonical nonzero metric height")
  T.eq(type(def.dexEntry.textEn), "string",
    id .. " has an individual English field-guide entry")
  T.eq(type(def.dexEntry.textDe), "string",
    id .. " has an individual German field-guide entry")
  T.eq(johtoDexTexts[def.dexEntry.textEn], nil,
    id .. " does not reuse another species' English Dex placeholder")
  johtoDexTexts[def.dexEntry.textEn] = id
  local learnSignature = table.concat(def.level1, ",")
  for _, row in ipairs(def.learnset) do
    learnSignature = learnSignature .. ";" .. row.level .. ":" .. row.move
  end
  johtoLearnProfiles[learnSignature] = true
  johtoTmProfiles[table.concat(def.tmhm, ",")] = true
end
local distinctLearnProfiles, distinctTmProfiles = 0, 0
for _ in pairs(johtoLearnProfiles) do distinctLearnProfiles = distinctLearnProfiles + 1 end
for _ in pairs(johtoTmProfiles) do distinctTmProfiles = distinctTmProfiles + 1 end
T.eq(distinctLearnProfiles >= 60, true,
  "Johto no longer collapses into one generic learn plan per primary type")
T.eq(distinctTmProfiles >= 35, true,
  "Johto families receive varied TM/HM compatibility instead of the same ten TMs")
T.eq(johto.species.CHIKORITA.learnset[1].move, "RAZOR_LEAF",
  "Chikorita begins its Crystal-shaped line with Razor Leaf")
T.eq(johto.species.SCIZOR.learnset[2].move, "METAL_CLAW",
  "Scizor learns a defining implemented Steel move")
T.eq(johto.species.HOUNDOOM.learnset[4].move, "CRUNCH",
  "Houndoom's line keeps its defining Dark progression")
T.eq(johto.species.STEELIX.dexEntry.heightM, 9.2,
  "Steelix uses its canonical 9.2-meter Pokédex height")
T.eq(johto.species.LUGIA.dexEntry.kindDe, "TAUCHER",
  "legendary Pokédex classifications are localized too")

local johtoResearch = ex.johtoResearch
T.neq(johtoResearch, nil, "Elm's living-habitat research API is exported")
T.eq(johtoResearch.state().version, 2,
  "existing Johto research saves migrate in place to living habitats")
local blankResearch = {
  starters = {}, rewards = {}, eggsQueued = {}, eggsHatched = {},
}
T.eq(johtoResearch.starterTrialsComplete(blankResearch), false,
  "starter-trial status is queryable without exposing any Dex entry")
T.eq(johtoResearch.finaleUnlocked(blankResearch), false,
  "the Larvitar finale begins locked")
T.eq(johtoResearch.itemUnlocked("SUN_STONE", {
    itemsClaimed = { ["3:SUN_STONE"] = true },
  }), true,
  "the Frontier Exchange can query an earned evolution item cleanly")
T.eq(johtoResearch.itemUnlocked("KINGS_ROCK", {
    itemsClaimed = { ["3:SUN_STONE"] = true },
  }), false,
  "a later evolution item remains locked until its own milestone")
T.eq(johtoResearch.isSpeciesResearched("SKARMORY", blankResearch), false,
  "seeing a mapped Johto species elsewhere cannot bypass Elm's research gate")
T.eq(#johtoResearch.habitatCandidates("ROUTE_1", "grass", blankResearch), 0,
  "an unrevealed Johto family cannot leak into a wild encounter")
local livingResearch = {
  starters = { chikorita = true, cyndaquil = true, totodile = true },
  rewards = { SENTRET = true, HOUNDOUR = true },
  eggsQueued = {}, eggsHatched = {}, finalReward = true,
}
T.eq(johtoResearch.starterTrialsComplete(livingResearch), true,
  "all three completed starter trials are exposed as one clean status")
T.eq(johtoResearch.isSpeciesResearched("FURRET", livingResearch), true,
  "research status follows a revealed specimen through its evolution family")
T.eq(johtoResearch.isSpeciesResearched("TYRANITAR", livingResearch), true,
  "the finale status covers Larvitar's complete evolution family")
local routeOneHabitats =
  johtoResearch.habitatCandidates("ROUTE_1", "grass", livingResearch)
T.eq(#routeOneHabitats, 1,
  "a researched family establishes one permanent thematic habitat")
T.eq(routeOneHabitats[1].species, "SENTRET",
  "Route 1 becomes Sentret habitat only after its research reward")
T.eq(johtoResearch.habitatFor("LARVITAR").map, "VICTORY_ROAD_3F",
  "Larvitar's post-finale habitat is the deepest Victory Road floor")
end)()

local followerCompat = ex.followerCompat
T.neq(followerCompat, nil,
  "Johto follower compatibility is exported")
do
  local oakGame = {
    save = {
      flags = {},
      player = { map = "PALLET_TOWN", x = 10, y = 0 },
      party = {},
    },
    overworld = {
      map = { id = "PALLET_TOWN" },
      player = { cellX = 10, cellY = 0 },
    },
  }
  T.eq(followerCompat.isYellowOakPikachuRequest(
      oakGame, "CHARMANDER", 5, {
        scriptedEncounter = "yellow_oak_pikachu",
      }), true,
    "the explicit Oak scene marker survives a wrapper's Charmander rewrite")
  T.eq(followerCompat.isYellowOakPikachuRequest(
      oakGame, "CHARMANDER", 5), true,
    "legacy engines recognize only the exact Pallet pre-starter scene")
  oakGame.overworld.map.id = "ROUTE_1"
  oakGame.save.player.map = "ROUTE_1"
  T.eq(followerCompat.isYellowOakPikachuRequest(
      oakGame, "PIKACHU", 5), false,
    "ordinary level-5 Pikachu encounters are not mistaken for Oak's demo")
  oakGame.overworld.map.id = "PALLET_TOWN"
  oakGame.save.player.map = "PALLET_TOWN"
  oakGame.save.flags.EVENT_GOT_STARTER = true
  T.eq(followerCompat.isYellowOakPikachuRequest(
      oakGame, "CHARMANDER", 5), false,
    "post-starter Pallet encounters cannot trigger the legacy repair")

  local repaired = false
  local fakeDemo = {
    repairYellowOakPikachuDemo = function(self)
      repaired = self.scriptedEncounter == "yellow_oak_pikachu"
      return repaired
    end,
  }
  T.eq(followerCompat.repairYellowOakPikachuBattle(
      oakGame, fakeDemo, {}), true,
    "the compatibility layer delegates to the engine's canonical repair")
  T.eq(repaired, true,
    "the stable scene marker is stamped before the engine repair runs")
end
;(function()
  local normal = io.open(
    modPath .. "/assets/followers/totodile.png", "rb")
  local shiny = io.open(
    modPath .. "/assets/followers/shiny/totodile.png", "rb")
  local runtimeNormal = io.open(
    modPath .. "/assets/followers_runtime/normal/follower_TOTODILE.png", "rb")
  local runtimeShiny = io.open(
    modPath .. "/assets/followers_runtime/shiny/follower_TOTODILE.png", "rb")
  local feraligatrRuntimeNormal = io.open(
    modPath .. "/assets/followers_runtime/normal/follower_FERALIGATR.png", "rb")
  local feraligatrRuntimeShiny = io.open(
    modPath .. "/assets/followers_runtime/shiny/follower_FERALIGATR.png", "rb")
  T.neq(normal, nil,
    "Totodile ships with its species-accurate follower sheet")
  T.neq(shiny, nil,
    "shiny Totodile ships with its species-accurate follower sheet")
  T.neq(runtimeNormal, nil,
    "Totodile ships with a renderer-ready mobile follower sheet")
  T.neq(runtimeShiny, nil,
    "shiny Totodile ships with a renderer-ready mobile follower sheet")
  T.neq(feraligatrRuntimeNormal, nil,
    "Feraligatr ships with its renderer-ready follower sheet")
  T.neq(feraligatrRuntimeShiny, nil,
    "shiny Feraligatr ships with its renderer-ready follower sheet")
  if normal then normal:close() end
  if shiny then shiny:close() end
  if runtimeNormal then runtimeNormal:close() end
  if runtimeShiny then runtimeShiny:close() end
  if feraligatrRuntimeNormal then feraligatrRuntimeNormal:close() end
  if feraligatrRuntimeShiny then feraligatrRuntimeShiny:close() end
end)()
T.eq(followerCompat.proxySpecies("TYRANITAR", Data), "RHYDON",
  "Tyranitar uses a sturdy existing follower sheet instead of crashing")
T.eq(followerCompat.proxySpecies("LUGIA", Data), "ARTICUNO",
  "Lugia uses the standard legendary-bird follower silhouette")
T.eq(followerCompat.proxySpecies("CELEBI", Data), "MEW",
  "Celebi uses the small Mew-like follower silhouette")
local missingFollowerProxy = {}
for _, id in ipairs(johto.order) do
  local proxy = followerCompat.proxySpecies(id, Data)
  if type(proxy) ~= "string" or proxy == "" then
    missingFollowerProxy[#missingFollowerProxy + 1] = id
  end
end
T.eq(#missingFollowerProxy, 0,
  "every Johto species has a safe 2D/voxel follower fallback")

do
  -- Feraligatr's family fallback is intentionally Blastoise, but it must
  -- never win while the release's species-accurate runtime sheet exists.
  -- This catches a package or resolver regression before visual QA can
  -- silently show the wrong Pokémon.
  local followerGame = { data = Data }
  local function pokepcPath(species)
    return "pokepc/assets/follower_" .. tostring(species) .. ".png"
  end
  local normalMon = {
    species = "FERALIGATR", hp = 100,
    dvs = { attack = 9, defense = 8, speed = 8, special = 8, hp = 8 },
  }
  local shinyMon = {
    species = "FERALIGATR", hp = 100,
    dvs = { attack = 10, defense = 10, speed = 10, special = 10, hp = 0 },
  }
  -- The fixture LOVE filesystem is rooted at the engine checkout rather
  -- than the external mod directory. The files were opened above with real
  -- IO; expose those two verified package paths to the runtime resolver too.
  local normalRuntimePath =
    modPath .. "/assets/followers_runtime/normal/follower_FERALIGATR.png"
  local shinyRuntimePath =
    modPath .. "/assets/followers_runtime/shiny/follower_FERALIGATR.png"
  local oldLocalPath = followerCompat.localPath
  local oldGetInfo = love.filesystem.getInfo
  followerCompat.localPath = function(species, mon)
    if species ~= "FERALIGATR" then return oldLocalPath(species, mon) end
    return mon == shinyMon and shinyRuntimePath or normalRuntimePath
  end
  love.filesystem.getInfo = function(path, ...)
    if path == normalRuntimePath or path == shinyRuntimePath then
      return { type = "file" }
    end
    return oldGetInfo(path, ...)
  end
  local normalPath =
    followerCompat.resolvedPath(followerGame, normalMon, pokepcPath)
  local shinyPath =
    followerCompat.resolvedPath(followerGame, shinyMon, pokepcPath)
  followerCompat.localPath = oldLocalPath
  love.filesystem.getInfo = oldGetInfo
  T.eq(normalPath, normalRuntimePath,
    "bundled Feraligatr art wins over the Blastoise emergency proxy")
  T.eq(shinyPath, shinyRuntimePath,
    "bundled shiny Feraligatr art wins over the Blastoise emergency proxy")
  T.eq(normalPath and normalPath:find("BLASTOISE", 1, true), nil,
    "normal Feraligatr never silently resolves to Blastoise")
  T.eq(shinyPath and shinyPath:find("BLASTOISE", 1, true), nil,
    "shiny Feraligatr never silently resolves to Blastoise")
end

do
  -- A second follower/visual mod may wrap PokéPC's update function. The
  -- Ascendant bridge must still find and patch PokéPC's nested assetPath
  -- closure instead of silently leaving a missing follower_NATU.png path.
  local PikachuFollower = require("src.world.PikachuFollower")
  local originalUpdate = PikachuFollower.update
  local seenPath
  local function assetPath(species)
    return "pokepc/assets/follower_" .. tostring(species) .. ".png"
  end
  local function configureSpriteDef(_, mon)
    seenPath = assetPath(mon and mon.species)
  end
  local function pokepcUpdate(game)
    configureSpriteDef(game, game.save.party[1])
  end
  local function followersExWrapper(game, ow)
    return pokepcUpdate(game, ow)
  end
  PikachuFollower.update = followersExWrapper

  local oldLocalPath = followerCompat.localPath
  local oldGetInfo = love.filesystem.getInfo
  love.filesystem.getInfo = function(path, ...)
    if type(path) == "string"
        and (path:find("ascendant/cache/", 1, true) == 1
          or path:find("pokepc/assets/", 1, true) == 1) then
      return { type = "file" }
    end
    return oldGetInfo(path, ...)
  end
  followerCompat.localPath = function(species)
    return "ascendant/cache/follower_" .. tostring(species) .. ".png"
  end
  local followerGame = {
    data = {
      pokemon = Data.pokemon,
      sprites = { SPRITE_PIKACHU = {} },
    },
    save = { party = { { species = "NATU", hp = 10 } } },
    mods = {
      exports = {
        pokepc = {
          activeMon = function(game) return game.save.party[1] end,
        },
      },
    },
  }
  T.eq(followerCompat.install(followerGame), true,
    "the follower bridge reaches PokéPC through an outer wrapper")
  followersExWrapper(followerGame, {})
  T.eq(seenPath, "ascendant/cache/follower_NATU.png",
    "nested PokéPC rendering receives Natu's bundled Ascendant sheet")
  T.eq(followerGame.data.sprites.SPRITE_PIKACHU.image,
    "ascendant/cache/follower_NATU.png",
    "the currently visible follower definition refreshes immediately")
  T.eq(followerCompat.restore(), true,
    "the nested follower bridge restores its original asset resolver")
  followerCompat.localPath = oldLocalPath
  love.filesystem.getInfo = oldGetInfo
  PikachuFollower.update = originalUpdate
end

do
  -- Release/mobile runtimes may not expose the closure seam at all. The
  -- renderer guard must replace a missing Johto path before image loading,
  -- so selecting that follower cannot crash even without debug patching.
  local PikachuFollower = require("src.world.PikachuFollower")
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local originalUpdate = PikachuFollower.update
  local originalNew = SpriteRenderer.new
  local oldLocalPath = followerCompat.localPath
  local oldGetInfo = love.filesystem.getInfo
  local renderedPath

  love.filesystem.getInfo = function(path, ...)
    if type(path) == "string"
        and (path:find("ascendant/runtime/", 1, true) == 1
          or path:find("pokepc/assets/follower_CHARMANDER", 1, true)) then
      return { type = "file" }
    end
    return oldGetInfo(path, ...)
  end
  followerCompat.localPath = function(species)
    return "ascendant/runtime/follower_" .. tostring(species) .. ".png"
  end
  SpriteRenderer.new = function(def)
    renderedPath = def.image
    if renderedPath == "pokepc/assets/follower_NATU.png" then
      error("missing follower_NATU.png")
    end
    return { def = def }
  end
  PikachuFollower.update = function(game)
    local def = game.data.sprites.SPRITE_PIKACHU
    def.image = "pokepc/assets/follower_" .. game.save.party[1].species .. ".png"
    return SpriteRenderer.new(def, "follower")
  end

  local followerGame = {
    data = {
      pokemon = Data.pokemon,
      sprites = {
        SPRITE_PIKACHU = {
          id = "SPRITE_PIKACHU", image = "pokepc/assets/follower_CHARMANDER.png",
          frames = 6, walker = true,
        },
      },
    },
    save = { party = { { species = "NATU", hp = 10 } } },
    mods = {
      exports = {
        pokepc = {
          activeMon = function(game) return game.save.party[1] end,
          assetPath = function(species)
            return "pokepc/assets/follower_" .. tostring(species) .. ".png"
          end,
        },
      },
    },
  }
  T.eq(followerCompat.install(followerGame), true,
    "the follower renderer guard installs without a PokéPC closure seam")
  T.eq(pcall(PikachuFollower.update, followerGame, {}), true,
    "selecting a Johto follower cannot reach the missing PokéPC sheet")
  T.eq(renderedPath, "ascendant/runtime/follower_NATU.png",
    "the renderer receives Natu's bundled mobile-ready sheet")
  T.eq(followerCompat.restore(), true,
    "the renderer-only follower guard restores cleanly")

  followerCompat.localPath = oldLocalPath
  love.filesystem.getInfo = oldGetInfo
  PikachuFollower.update = originalUpdate
  SpriteRenderer.new = originalNew
end

-- ------------------------------------------------ pure line resolution

T.eq(ex.resolveLine("OPP_YOUNGSTER"):find("shorts", 1, true) ~= nil, true,
  "YOUNGSTER line is in his voice")
T.eq(ex.resolveLine("OPP_LANCE"):find("dragons", 1, true) ~= nil, true,
  "LANCE line is in his voice")
T.eq(ex.resolveLine("OPP_UNUSED_JUGGLER"):find("juggling", 1, true) ~= nil, true,
  "UNUSED_JUGGLER gets a line too")
T.eq(ex.resolveLine("OPP_FIX_YOUNGSTER"), "You're looking\nfor a rematch?",
  "unknown class falls back to the default prompt")
T.eq(ex.resolveLine(nil), "You're looking\nfor a rematch?",
  "nil class falls back to the default prompt")
run.loader.modOptions.trainer_rematch = { language = "de" }
T.eq(ex.language(), "de", "the manual DEUTSCH override selects German")
T.eq(ex.resolveLine("OPP_YOUNGSTER"):find("Shorts", 1, true) ~= nil, true,
  "German rematch dialogue keeps the class voice")
T.eq(ex.resolveDecline("OPP_KOGA"):find("Gift", 1, true) ~= nil, true,
  "German decline dialogue is localized too")
T.eq(ex.restLine(2):find("Schritten", 1, true) ~= nil, true,
  "German cooldown dialogue uses the correct plural")
run.loader.modOptions.trainer_rematch = nil
T.eq(ex.language(), "en", "English remains the standalone AUTO fallback")

-- ------------------------------------------------ pure decline resolution

T.eq(ex.resolveDecline("OPP_YOUNGSTER"):find("scared", 1, true) ~= nil, true,
  "cocky classes mock the refusal")
T.eq(ex.resolveDecline("OPP_KOGA"):find("Fear", 1, true) ~= nil, true,
  "wise classes answer with understanding")
T.eq(ex.resolveDecline("OPP_GENTLEMAN"):find("gentleman", 1, true) ~= nil, true,
  "polite classes stay polite")
T.eq(ex.resolveDecline("OPP_FIX_YOUNGSTER"), "Ha! Scared of\na rematch, are\nyou?",
  "unknown class falls back to the default decline")
T.eq(ex.resolveDecline(nil), "Ha! Scared of\na rematch, are\nyou?",
  "nil class falls back to the default decline")

-- ------------------------------------------------ prize-line filter

T.eq(ex.isPrizeLine("RED got ¥1500\nfor winning!"), true,
  "prize line is filtered out")
T.eq(ex.isPrizeLine("RED defeated\nYOUNGSTER!"), false,
  "defeated line passes")
T.eq(ex.isPrizeLine("You got here\nfor winning\nnothing!"), true,
  "any line mentioning got/for winning is treated as prize text")
T.eq(ex.isPrizeLine(123), false, "non-string texts pass")

-- ------------------------------------------------ rest + growth rules

T.eq(ex.rollRestSteps(function(lo) return lo end, 151, 2510), 151,
  "rest roll includes the lower bound")
T.eq(ex.rollRestSteps(function(_, hi) return hi end, 151, 2510), 2510,
  "rest roll includes the upper bound")
T.eq(ex.rollRestSteps(function(lo) return lo end, 2510, 151), 151,
  "an inverted option range is normalized")
T.eq(ex.rollRestSteps(function(_, hi) return hi end, 128, 256), 2510,
  "untouched legacy defaults migrate to the expanded range")
T.eq(ex.restLine(1):find("1 more step.", 1, true) ~= nil, true,
  "one remaining step uses singular dialogue")
T.eq(ex.restLine(2510):find("2510 more steps.", 1, true) ~= nil, true,
  "rest dialogue tells the player exactly how long is left")
T.eq(ex.nextLevelBoost(0, 2), 2, "the first rematch is two levels stronger")
T.eq(ex.nextLevelBoost(1, 2), 4, "the second rematch grows again")
T.eq(ex.nextLevelBoost(9, 2), 20, "ten default growth tiers reach +20")
T.eq(ex.nextLevelBoost(99, 2), 99,
  "long-running trainers can now reach the natural level-100 ceiling")
local preview = ex.boostedTeam({ { species = "RATTATA", level = 99 },
                                 { species = "EKANS", level = 12 } }, 4)
T.eq(preview[1].level, 100, "preview levels respect the level-100 cap")
T.eq(preview[2].level, 16, "preview levels include the rematch boost")

local fixtureTeam = Data.trainers.OPP_FIX_YOUNGSTER.parties[1]
local noRecruit = ex.recruitTeam(Data, fixtureTeam, "OPP_FIX_YOUNGSTER",
  "FIX_ROUTE_obj_recruit", 0, 2, true)
T.eq(#noRecruit, 2, "the first growth tier does not add a recruit immediately")
local recruited = ex.recruitTeam(Data, fixtureTeam, "OPP_FIX_YOUNGSTER",
  "FIX_ROUTE_obj_recruit", 1, 4, true)
T.eq(#recruited, 3, "the second growth tier recruits one new Pokémon")
T.eq(recruited[3].species, "RAICHU",
  "an unknown mod trainer recruits a valid non-duplicate fallback species")
T.eq(recruited[3].recruited, true,
  "new party slots are marked as background-training recruits")
local recruitedAgain = ex.recruitTeam(Data, fixtureTeam, "OPP_FIX_YOUNGSTER",
  "FIX_ROUTE_obj_recruit", 1, 4, true)
T.eq(recruitedAgain[3].species, recruited[3].species,
  "the same trainer keeps a deterministic recruit")
local disabledRecruit = ex.recruitTeam(Data, fixtureTeam, "OPP_FIX_YOUNGSTER",
  "FIX_ROUTE_obj_recruit", 9, 20, false)
T.eq(#disabledRecruit, 2, "TEAM GROWTH off preserves the original party size")
local recruitPoolCount = 0
local forbiddenRecruit = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true, LUGIA = true, HO_OH = true,
  CELEBI = true,
}
for class, pool in pairs(ex.recruitPools) do
  recruitPoolCount = recruitPoolCount + 1
  T.eq(#pool > 0, true, class .. " has a non-empty recruitment pool")
  for _, species in ipairs(pool) do
    T.eq(forbiddenRecruit[species], nil,
      class .. " never recruits legendary Pokémon")
  end
end
T.eq(recruitPoolCount, 47,
  "all 47 trainer classes have a thematic recruitment pool")

do
  local recruitment = ex.recruitment
  local johtoOrder = ex.johtoData.order
  local grassTeam = { { species = "FIXMON_A", level = 35 } }
  local oldChikorita, oldBayleef, oldMeganium =
    Data.pokemon.CHIKORITA, Data.pokemon.BAYLEEF, Data.pokemon.MEGANIUM
  local function fixtureJohto(id, dex, evolutions)
    return {
      id = id, index = dex, dex = dex, name = id,
      types = { "GRASS" },
      baseStats = { hp = 60, attack = 60, defense = 60,
        speed = 60, special = 60 },
      catchRate = 45, baseExp = 64,
      level1Moves = { "FIX_TACKLE" }, growthRate = "MEDIUM_SLOW",
      tmhm = {}, learnset = {
        { level = 1, move = "FIX_TACKLE" },
      },
      evolutions = evolutions or {},
    }
  end
  Data.pokemon.CHIKORITA = fixtureJohto("CHIKORITA", 152, {
    { method = "LEVEL", level = 16, species = "BAYLEEF" },
  })
  Data.pokemon.BAYLEEF = fixtureJohto("BAYLEEF", 153, {
    { method = "LEVEL", level = 32, species = "MEGANIUM" },
  })
  Data.pokemon.MEGANIUM = fixtureJohto("MEGANIUM", 154)

  recruitment.configureJohto(johtoOrder, function() return false end)
  local locked = ex.recruitTeam(Data, grassTeam, "OPP_ERIKA",
    "ERIKA_FIELD_LOCKED", 11, 45, true)
  local lockedHasJohto = false
  for _, slot in ipairs(locked) do
    lockedHasJohto = lockedHasJohto
      or (tonumber(Data.pokemon[slot.species].dex) or 0) > 151
  end
  T.eq(lockedHasJohto, false,
    "field trainers remain Kanto-only before a Johto family is researched")

  recruitment.configureJohto(johtoOrder, function(species)
    return species == "CHIKORITA"
  end)
  T.eq(johtoOrder[1], "CHIKORITA",
    "the Johto recruitment order begins with Chikorita")
  T.eq(Data.pokemon.CHIKORITA and Data.pokemon.CHIKORITA.dex, 152,
    "the registered Chikorita carries its National Dex number")
  T.eq(Data.pokemon.CHIKORITA and Data.pokemon.CHIKORITA.types[1], "GRASS",
    "the registered Chikorita carries its Grass typing")
  T.eq(recruitment.eligibleJohtoFamilies(
      Data, grassTeam, "OPP_ERIKA")[1], "CHIKORITA",
    "the shared research callback exposes Chikorita to Grass specialists")
  local remembered = {}
  local unlocked = ex.recruitTeam(Data, grassTeam, "OPP_ERIKA",
    "ERIKA_FIELD_UNLOCKED", 11, 45, true, { selections = remembered })
  local johtoRecruit
  for _, slot in ipairs(unlocked) do
    if (tonumber(Data.pokemon[slot.species].dex) or 0) > 151 then
      johtoRecruit = slot
      break
    end
  end
  T.neq(johtoRecruit, nil,
    "a researched matching Johto family enters a suitable trainer pool")
  if johtoRecruit then
    T.eq(johtoRecruit.species, "MEGANIUM",
      "NPC recruitment deterministically chooses a level-appropriate final stage")
  end
  T.eq(remembered[2], "CHIKORITA",
    "the save-facing recruitment selection stores the evolutionary family")

  recruitment.configureJohto(johtoOrder, function(species)
    return species == "CHIKORITA" or species == "HOPPIP"
  end)
  local loadedAgain = ex.recruitTeam(Data, grassTeam, "OPP_ERIKA",
    "ERIKA_FIELD_UNLOCKED", 11, 45, true, { selections = remembered })
  T.eq(loadedAgain[2].species, "MEGANIUM",
    "new research unlocks do not reroll an existing trainer recruit after load")

  recruitment.configureJohto(johtoOrder, function() return true end)
  local noLegendTeam = ex.recruitTeam(Data, grassTeam, "OPP_ERIKA",
    "ERIKA_FIELD_ALL_JOHTO", 99, 65, true)
  local families = {}
  for _, slot in ipairs(noLegendTeam) do
    T.eq(forbiddenRecruit[slot.species], nil,
      "generic field growth excludes legendary and mythical Johto species")
    local id = slot.species
    T.eq(families[id], nil,
      "a long-running field trainer never receives a duplicate exact species")
    families[id] = true
    T.eq(slot.level <= 100, true,
      "long-running Johto recruitment never overflows level 100")
  end

  recruitment.configureJohto(johtoOrder, function(species)
    return ex.johtoResearch.isRecruitFamilyEligible(species)
  end)
  Data.pokemon.CHIKORITA, Data.pokemon.BAYLEEF, Data.pokemon.MEGANIUM =
    oldChikorita, oldBayleef, oldMeganium
end

T.eq(ex.lootForRoll(1, "balanced",
  { averageLevel = 100, masterUnlocked = false, expAllAvailable = true }), nil,
  "Master Ball rolls are sealed before the Apex Champion")
T.eq(ex.lootForRoll(1, "balanced",
  { averageLevel = 100, masterUnlocked = true }), "MASTER_BALL",
  "the rarest eligible roll awards a Master Ball")
T.eq(ex.lootForRoll(1, "balanced",
  { averageLevel = 79, masterUnlocked = true }), nil,
  "the Master Ball also requires a genuinely high-level rematch")
T.eq(ex.lootForRoll(101, "balanced",
  { averageLevel = 40, expAllAvailable = true }), "EXP_ALL",
  "the functional EXP.ALL/EP-Teiler starts its five-percent balanced band")
T.eq(ex.lootForRoll(600, "balanced",
  { averageLevel = 40, expAllAvailable = true }), "EXP_ALL",
  "the functional EXP.ALL/EP-Teiler fills its five-percent balanced band")
T.eq(ex.lootForRoll(101, "balanced",
  { averageLevel = 40, expAllAvailable = false }), nil,
  "EXP.ALL can only drop once")
T.eq(ex.lootForRoll(101, "balanced",
  { averageLevel = 39, expAllAvailable = true }), nil,
  "EXP.ALL waits for a level-40 rematch")
T.eq(ex.lootForRoll(601, "balanced",
  { averageLevel = 20 }), "RARE_CANDY",
  "Rare Candy starts its five-percent balanced band")
T.eq(ex.lootForRoll(1101, "balanced",
  { averageLevel = 35 }), "PP_UP",
  "level-35 rematches can drop PP Up")
T.eq(ex.lootForRoll(2101, "balanced",
  { averageLevel = 50 }), "MAX_REVIVE",
  "level-50 rematches can drop Max Revive")
T.eq(ex.lootForRoll(2901, "balanced", { averageLevel = 1 }), "NUGGET",
  "Nugget starts its fifteen-percent balanced band")
T.eq(ex.lootForRoll(4401, "balanced",
  { averageLevel = 100, masterUnlocked = true, expAllAvailable = true }), nil,
  "balanced loot keeps the removed percentages as no-drop results")
T.eq(ex.lootForRoll(200, "generous",
  { averageLevel = 100, masterUnlocked = true }), "MASTER_BALL",
  "GENEROUS mode gives the Master Ball its full two-percent band")
T.eq(ex.lootForRoll(201, "generous",
  { averageLevel = 40, expAllAvailable = true }), "EXP_ALL",
  "GENEROUS mode also keeps EXP.ALL at five percent")
T.eq(ex.lootForRoll(701, "generous", { averageLevel = 20 }), "RARE_CANDY",
  "GENEROUS mode also keeps Rare Candy at five percent")
T.eq(ex.lootForRoll(1201, "generous", { averageLevel = 35 }), "PP_UP",
  "GENEROUS mode retains its existing PP Up band")
T.eq(ex.lootForRoll(2701, "generous", { averageLevel = 50 }), "MAX_REVIVE",
  "GENEROUS mode retains its existing Max Revive band")
T.eq(ex.lootForRoll(3901, "generous", { averageLevel = 1 }), "NUGGET",
  "GENEROUS mode keeps Nuggets at fifteen percent")
T.eq(ex.lootForRoll(5401, "generous",
  { averageLevel = 100, masterUnlocked = true, expAllAvailable = true }), nil,
  "GENEROUS leaves reduced reward space as no drop")
T.eq(ex.lootForRoll(1, "off",
  { averageLevel = 100, masterUnlocked = true }), nil,
  "loot can be disabled completely")

-- ------------------------------------------------ post-game progression + rosters

local pg = ex.postgame
local pgd = ex.postgameData
T.neq(pg, nil, "post-game controller is exported")
T.neq(pgd, nil, "post-game roster data is exported")
T.eq(#pgd.gyms, 8, "all eight Kanto leaders join the circuit")
T.eq(#pgd.legendOrder, 10, "ten gated legendary encounters are tracked")
T.neq(pgd.dialogue, nil, "post-game character dialogue is loaded")
local gymDialogueCount = 0
for _, gym in ipairs(pgd.gyms) do
  local writing = pgd.dialogue.gyms[gym.key]
  T.neq(writing, nil, gym.name .. " has character-specific writing")
  for _, tier in ipairs({ "master", "crown" }) do
    local stage = writing[tier]
    T.neq(stage, nil, gym.name .. " has " .. tier .. " dialogue")
    for _, key in ipairs({ "intro", "decline", "win" }) do
      T.eq(type(stage[key].en), "string",
        gym.name .. " " .. tier .. " " .. key .. " has English text")
      T.eq(type(stage[key].de), "string",
        gym.name .. " " .. tier .. " " .. key .. " has German text")
    end
    T.eq(type(stage.rest.one.en), "string",
      gym.name .. " has a singular English rest line")
    T.eq(type(stage.rest.many.de), "string",
      gym.name .. " has a plural German rest line")
  end
  gymDialogueCount = gymDialogueCount + 1
end
T.eq(gymDialogueCount, 8, "all eight leaders have full dialogue sets")
local eliteDialogueCount = 0
for class, writing in pairs(pgd.dialogue.elite) do
  for _, tier in ipairs({ "apex", "crown" }) do
    for _, key in ipairs({ "before", "win", "after" }) do
      T.eq(type(writing[tier][key].en), "string",
        class .. " " .. tier .. " " .. key .. " has English text")
      T.eq(type(writing[tier][key].de), "string",
        class .. " " .. tier .. " " .. key .. " has German text")
    end
  end
  eliteDialogueCount = eliteDialogueCount + 1
end
T.eq(eliteDialogueCount, 5,
  "Lorelei, Bruno, Agatha, Lance and the Champion have full dialogue sets")
T.eq(type(pgd.dialogue.story.oakLegendEvent.en), "string",
  "Oak's first Hall-of-Fame event has English writing")
T.eq(type(pgd.dialogue.story.oakLegendEvent.de), "string",
  "Oak's first Hall-of-Fame event has German writing")
T.eq(pgd.overworldSprites.RAIKOU, "SPRITE_MONSTER",
  "Raikou reuses the standard monster overworld sheet")
T.eq(pgd.overworldSprites.ENTEI, "SPRITE_MONSTER",
  "Entei reuses the standard monster overworld sheet")
T.eq(pgd.overworldSprites.SUICUNE, "SPRITE_MONSTER",
  "Suicune reuses the standard monster overworld sheet")
T.eq(pgd.overworldSprites.LUGIA, "SPRITE_BIRD",
  "Lugia reuses the standard flying overworld sheet")
T.eq(pgd.overworldSprites.HO_OH, "SPRITE_BIRD",
  "Ho-Oh reuses the standard flying overworld sheet")
T.eq(pgd.overworldSprites.CELEBI, "SPRITE_FAIRY",
  "Celebi reuses the small fairy overworld sheet")
T.eq(pgd.roamers.RAIKOU.level, 85,
  "visible and grass Raikou encounters share the intended level")

local pgSave = {
  flags = {}, hallOfFame = {}, pokedex = { seen = {}, owned = {} },
}
local pgState = {
  masterWins = {}, crownWins = {}, eliteApexWins = {},
  eliteCrownWins = {}, catches = {}, roamers = {}, bossRest = {},
}
local oakBase = "OAK: Base-game invitation."
local oakLabel = "_ChampionsRoomOakComeWithMeText"
local oakGame = {
  save = pgSave,
  data = { text = { [oakLabel] = oakBase } },
}
T.eq(pg.applyEliteDialogue("CHAMPIONS_ROOM", oakGame, pgState), true,
  "the first Champion clear installs Oak's event announcement")
T.eq(oakGame.data.text[oakLabel]:find(
    "legendary POKéMON", 1, true) ~= nil, true,
  "Oak foreshadows the growing legendary sightings in English")
run.loader.modOptions.trainer_rematch = { language = "de" }
local germanOakGame = {
  save = { flags = {}, hallOfFame = {} },
  data = { text = { [oakLabel] = oakBase } },
}
T.eq(pg.applyStoryOakDialogue("CHAMPIONS_ROOM", germanOakGame), true,
  "the first Champion announcement can be installed directly")
T.eq(germanOakGame.data.text[oakLabel]:find(
    "Immer häufiger", 1, true) ~= nil
    and germanOakGame.data.text[oakLabel]:find(
      "legendäre", 1, true) ~= nil, true,
  "Oak's event announcement is fully localized in German")
run.loader.modOptions.trainer_rematch = nil
pgSave.flags.EVENT_BEAT_CHAMPION_RIVAL = true
T.eq(pg.applyEliteDialogue("CHAMPIONS_ROOM", oakGame, pgState), false,
  "the first-clear announcement is not reused on later League runs")
T.eq(oakGame.data.text[oakLabel], oakBase,
  "later League runs restore Oak's original invitation")
pgSave.flags.EVENT_BEAT_CHAMPION_RIVAL = nil
T.eq(pg.phaseFor(pgState, pgSave), "story",
  "the circuit stays closed before the Hall of Fame")
pgSave.hallOfFame[1] = {}
T.eq(pg.phaseFor(pgState, pgSave), "master_gyms",
  "the first Hall of Fame opens the Master gyms")
T.eq(pg.applyEliteDialogue("LORELEIS_ROOM",
    { save = pgSave, data = { text = {} } }, pgState), false,
  "the ordinary first Elite Four clear keeps the base-game dialogue")
for _, gym in ipairs(pgd.gyms) do pgState.masterWins[gym.key] = true end
T.eq(pg.allMaster(pgState), true, "all eight Master crests are recognized")
T.eq(pg.phaseFor(pgState, pgSave), "apex_elite",
  "the Master crests unlock the Apex Elite Four")
T.eq(pg.eliteTier(pgState, pgSave), "apex",
  "Apex rosters replace the Elite Four after all Master wins")
T.eq(pg.gymDialogue(pgd.gyms[1], "master", "intro")
    :find("first badge", 1, true) ~= nil, true,
  "Brock's English Master challenge is character-specific")
T.eq(pg.eliteDialogue("OPP_AGATHA", "apex", "before")
    :find("Heheheh", 1, true) ~= nil, true,
  "Agatha's English Apex challenge keeps her voice")
local eliteTextData = { text = {} }
T.eq(pg.applyEliteDialogue("LORELEIS_ROOM",
    { save = pgSave, data = eliteTextData }, pgState), true,
  "entering an active Apex room installs its circuit dialogue")
T.eq(eliteTextData.text._LoreleisRoomLoreleiBeforeBattleText
    :find("Eight masters", 1, true) ~= nil, true,
  "Lorelei's Apex opening replaces the ordinary story opening")
T.eq(eliteTextData.text._LoreleisRoomLoreleiEndBattleText
    :find("perfected", 1, true) ~= nil, true,
  "Lorelei's personal defeat quote is installed too")
run.loader.modOptions.trainer_rematch = { language = "de" }
T.eq(pg.gymDialogue(pgd.gyms[6], "crown", "intro")
    :find("Zukünfte", 1, true) ~= nil, true,
  "Sabrina's German Crown challenge is localized")
T.eq(pg.gymRestDialogue(pgd.gyms[3], "master", 27)
    :find("27 Schritten", 1, true) ~= nil, true,
  "Surge's personal German cooldown reports the exact plural step count")
run.loader.modOptions.trainer_rematch = nil
T.eq(pg.legendaryAvailable("ARTICUNO", pgState, pgSave), false,
  "legendaries stay sealed before the Apex Champion")
run.loader.modOptions.trainer_rematch = { legend_articuno = "vanilla" }
T.eq(pg.legendaryAvailable("ARTICUNO", pgState, pgSave), true,
  "VANILLA Articuno is available without the Apex Champion")
run.loader.modOptions.trainer_rematch = { legend_articuno = "off" }
T.eq(pg.legendaryAvailable("ARTICUNO", pgState, pgSave), false,
  "OFF removes the Articuno encounter")
run.loader.modOptions.trainer_rematch = nil

pgState.apexChampion = true
T.eq(pg.phaseFor(pgState, pgSave), "legend_hunt",
  "the Apex Champion opens the legendary hunt")
T.eq(pg.legendaryAvailable("ARTICUNO", pgState, pgSave), true,
  "the Kanto birds unlock after the Apex Champion")
T.eq(pg.legendaryAvailable("RAIKOU", pgState, pgSave), true,
  "the roaming beasts unlock after the Apex Champion")
T.eq(pg.legendaryAvailable("LUGIA", pgState, pgSave), false,
  "Lugia waits for all three birds")
run.loader.modOptions.trainer_rematch = {
  legend_articuno = "off", legend_zapdos = "off", legend_moltres = "off",
}
T.eq(pg.legendaryAvailable("LUGIA", pgState, pgSave), true,
  "disabled bird encounters do not make Lugia impossible to unlock")
run.loader.modOptions.trainer_rematch = nil
for _, id in ipairs({ "ARTICUNO", "ZAPDOS", "MOLTRES" }) do
  pgState.catches[id] = true
end
T.eq(pg.legendaryAvailable("LUGIA", pgState, pgSave), true,
  "catching all three birds reveals Lugia")
T.eq(pg.legendaryAvailable("HO_OH", pgState, pgSave), false,
  "Ho-Oh waits for all three beasts")
for _, id in ipairs({ "RAIKOU", "ENTEI", "SUICUNE" }) do
  pgState.catches[id] = true
end
T.eq(pg.legendaryAvailable("HO_OH", pgState, pgSave), true,
  "catching all three beasts reveals Ho-Oh")
pgState.catches.LUGIA, pgState.catches.HO_OH = true, true
T.eq(pg.crownUnlocked(pgState, pgSave), true,
  "Lugia and Ho-Oh together unlock the Crown Circuit")
T.eq(pg.legendaryAvailable("CELEBI", pgState, pgSave), true,
  "Celebi becomes the secret final encounter")
T.eq(pg.phaseFor(pgState, pgSave), "crown_gyms",
  "the Crown Circuit starts with the leaders")
for _, gym in ipairs(pgd.gyms) do pgState.crownWins[gym.key] = true end
T.eq(pg.eliteTier(pgState, pgSave), "crown",
  "eight Crown wins replace the Elite Four with level-100 rosters")
T.eq(pg.phaseFor(pgState, pgSave), "crown_elite",
  "the final Elite Four is the last circuit stage")
pgState.crownChampion = true
T.eq(pg.phaseFor(pgState, pgSave), "complete",
  "the Crown Champion completes the expansion")

for _, gym in ipairs(pgd.gyms) do
  T.eq(#gym.master, 6, gym.name .. " has a full Master team")
  T.eq(#gym.crown, 6, gym.name .. " has a full Crown team")
  for _, slot in ipairs(gym.crown) do
    T.eq(slot.level, 100, gym.name .. " Crown slots are level 100")
    T.eq(#slot.moves, 4, gym.name .. " Crown slots have four fixed moves")
  end
end
for class, team in pairs(pgd.apex) do
  T.eq(#team, 6, class .. " has a six-mon Apex roster")
  for _, slot in ipairs(team) do
    T.eq(slot.level >= 90 and slot.level <= 100, true,
      class .. " stays inside the Apex level curve")
  end
end
for class, team in pairs(pgd.crown) do
  for _, slot in ipairs(team) do
    T.eq(slot.level, 100, class .. " Crown roster is level 100")
  end
end
T.eq(pgd.crown.OPP_RIVAL3[1].species, "MEWTWO",
  "the final Champion opens with a legendary")
T.eq(pgd.crown.OPP_RIVAL3[6].species, "HO_OH",
  "the final Champion closes with Ho-Oh")
run.loader.modOptions.trainer_rematch = { legend_raikou = false }
local noRaikou = pg.enabledTeam(pgd.crown.OPP_RIVAL3)
T.eq(noRaikou[2].species, "JOLTEON",
  "disabling Raikou also removes it from boss rosters")
T.eq(pg.gymDialogue(pgd.gyms[3], "crown", "intro")
    :find("No legendary backup", 1, true) ~= nil, true,
  "Surge does not mention Raikou when its option is disabled")
T.eq(pg.eliteDialogue("OPP_RIVAL3", "crown", "before")
    :find("changed", 1, true) ~= nil, true,
  "the Crown Champion acknowledges a legendary option change")
T.eq(pgd.crown.OPP_RIVAL3[2].species, "RAIKOU",
  "option filtering never mutates the canonical Crown roster")
run.loader.modOptions.trainer_rematch = nil

-- ------------------------------------------------ narrative event layer

local event = pg.events
T.neq(event, nil, "the post-game narrative event layer is installed")
local introCount = 0
for _, species in ipairs(pgd.legendOrder) do
  introCount = introCount + 1
  T.eq(type(pgd.dialogue.legendIntros[species].en), "string",
    species .. " has an English cinematic introduction")
  T.eq(type(pgd.dialogue.legendIntros[species].de), "string",
    species .. " has a German cinematic introduction")
end
T.eq(introCount, 10, "all ten legends have cinematic introductions")
local reactionCount = 0
for _, row in pairs(pgd.dialogue.world) do
  reactionCount = reactionCount + 1
  for _, key in ipairs({ "rumor", "apex", "hunt", "crown", "complete" }) do
    T.eq(type(row[key].en), "string",
      "every world reaction phase has English text")
    T.eq(type(row[key].de), "string",
      "every world reaction phase has German text")
  end
end
T.eq(reactionCount, 7,
  "seven witnesses across Kanto react to the post-game events")

local eventSave = {
  flags = { EVENT_BEAT_CHAMPION_RIVAL = true }, hallOfFame = { {} },
  pokedex = { seen = {}, owned = {} },
}
local eventState = {
  masterWins = {}, crownWins = {}, eliteApexWins = {},
  eliteCrownWins = {}, catches = {}, roamers = {}, bossRest = {},
}
eventState.masterWins.brock = true
local earlyLog = event.researchLog(eventState, eventSave)
T.eq(earlyLog:find("OAK RESEARCH LOG", 1, true) ~= nil, true,
  "Oak's research log has an in-world English heading")
T.eq(earlyLog:find("Progress: 1/8", 1, true) ~= nil, true,
  "the research log reports Master Circuit progress")
T.eq(earlyLog:find("SEALED", 1, true) ~= nil, true,
  "the research log explains pre-Apex legendary seals")
T.eq(event.worldReaction("PALLET_TOWN", "PALLETTOWN_FISHER",
    eventState, eventSave):find("sunset", 1, true) ~= nil, true,
  "Pallet Town reacts to the first legendary rumors")

for _, gym in ipairs(pgd.gyms) do eventState.masterWins[gym.key] = true end
eventState.apexChampion = true
eventState.catches.ARTICUNO = true
eventState.roamers.RAIKOU = "ROUTE_10"
local huntLog = event.researchLog(eventState, eventSave)
T.eq(huntLog:find("ARTICUNO:\nCAUGHT", 1, true) ~= nil, true,
  "the research log marks captured legends")
T.eq(huntLog:find("RAIKOU:\nROUTE 10", 1, true) ~= nil, true,
  "the research log reports a roaming beast's current route")
T.eq(event.huntRivalAvailable(eventState, eventSave), true,
  "catching a first legend unlocks the one-time Rival hunt event")
T.eq(#pgd.huntRival.team, 6,
  "the legendary-hunt Rival brings a full adjusted team")
for _, slot in ipairs(pgd.huntRival.team) do
  T.eq(slot.level, 100, "the Rival's hunter team is level 100")
  T.eq(forbiddenRecruit[slot.species], nil,
    "the Rival's hunter team uses no legendary Pokémon")
end
local archive = event.trophyText(eventState, eventSave, {
  a = { rematches = 3 }, b = { rematches = 4 },
})
T.eq(archive:find("FIELD REMATCHES: 7", 1, true) ~= nil, true,
  "the Crown Archive totals all field rematches")
T.eq(archive:find("MASTER CRESTS: 8/8", 1, true) ~= nil, true,
  "the Crown Archive records the Master Circuit")
run.loader.modOptions.trainer_rematch = { language = "de" }
T.eq(event.researchLog(eventState, eventSave)
    :find("EICHS FORSCHUNGSLOG", 1, true) ~= nil, true,
  "the research log is fully localized in German")
T.eq(event.legendIntro("HO_OH")
    :find("Sieben Farben", 1, true) ~= nil, true,
  "Ho-Oh's cinematic introduction follows the selected language")
run.loader.modOptions.trainer_rematch = {
  legend_articuno = "off", legend_zapdos = "off",
  legend_moltres = "off", legend_mewtwo = "off",
  legend_raikou = false, legend_entei = false, legend_suicune = false,
  legend_lugia = false, legend_ho_oh = false, legend_celebi = false,
}
T.eq(event.enabledLegendCount(), 0,
  "the event layer recognizes an all-legendaries-off configuration")
T.eq(event.worldReaction("PALLET_TOWN", "PALLETTOWN_FISHER",
    eventState, eventSave), nil,
  "legendary world rumors disappear when every encounter is disabled")
T.eq(event.huntRivalAvailable(eventState, eventSave), false,
  "the legendary-hunt Rival is skipped when every encounter is disabled")
run.loader.modOptions.trainer_rematch = nil

-- ------------------------------------------------ install (stubbed deps)

local pushed = {}
local calls = { vanillaTalk = 0, engaged = 0, battles = {}, after = 0 }
calls.wilds = {}
calls.fakeWildsLogic = {
  activeMapId = "ROUTE_22",
  surfaceInfo = { surface = "GRASS" },
  render = {
    invalidateAssetCache = function(_, species)
      calls.wilds.invalidated = species
    end,
  },
}
calls.fakeWildsLogic.mod = {
  world = {
    overworld = function()
      return { map = { id = calls.fakeWildsLogic.activeMapId } }
    end,
  },
}
calls.fakeWildsLogic.trySpawn = function(_, _, opts)
  calls.wilds[#calls.wilds + 1] = opts
  return {
    species = opts.species or "FIXMON_A",
    level = opts.level or 5,
  }
end
local game = {
  data = Data,
  save = { money = 3000, inventory = {}, bagOrder = {},
           defeatedTrainers = {}, flags = {}, modData = {},
           player = { name = "RED" },
           party = { { level = 5 }, { level = 6 }, { level = 7 } } },
  stack = { push = function(_, s) table.insert(pushed, s) end },
  mods = {
    exports = {
      overworld_wild_spawns = { logic = calls.fakeWildsLogic },
    },
  },
}

-- ------------------------------------------ centralized forced-battle guard

do
  local BattleState = require("src.battle.BattleState")
  local FixturePokemon = require("src.pokemon.Pokemon")
  local forcedGame = {
    data = Data,
    save = {
      inventory = {}, flags = {}, options = {},
      pokedex = { seen = {}, owned = {} },
      player = { name = "RED" },
      party = {
        FixturePokemon.new(Data, "FIXMON_A", 50, function() return 8 end),
      },
    },
  }
  local record = Data.trainers.OPP_FIX_YOUNGSTER
  local originalParties = record.parties
  record.parties = {
    {
      { species = "FIXMON_A", level = 5 },
      { species = "FIXMON_C", level = 5 },
    },
  }
  local intended = {
    { species = "FIXMON_A", level = 77, moves = { "FIX_TACKLE" } },
    { species = "FIXMON_B", level = 79, moves = { "FIX_SCRATCH" } },
  }
  local originalCount = #record.parties

  local randomizedInput
  local removeAfter = RealRuntime.hooks:wrap("trainer.party",
    function(nextParty, class, partyIndex, party)
      randomizedInput = party
      local downstream = nextParty(class, partyIndex, party)
      return {
        { species = "FIXMON_C", level = 12,
          moves = downstream[1].moves },
        { species = "FIXMON_A", level = 13,
          moves = downstream[2].moves },
      }
    end, -100, "forced-randomizer-after")
  local randomized = pg.newForcedBattle(
    forcedGame, "OPP_FIX_YOUNGSTER", intended, "master")
  removeAfter()
  T.eq(randomizedInput[1].level, 77,
    "a downstream Randomizer receives the authored Master roster as input")
  T.same({ randomized.enemyParty[1].species,
           randomized.enemyParty[2].species },
    { "FIXMON_C", "FIXMON_A" },
    "a cooperative Randomizer keeps ownership of forced-battle species")
  T.same({ randomized.enemyParty[1].level,
           randomized.enemyParty[2].level }, { 77, 79 },
    "Ascendant reapplies the authored per-slot level pattern exactly once")
  T.eq(randomized.enemyParty[1].hp,
    randomized.enemyParty[1].stats.hp,
    "forced randomized opponents start at coherent full HP")
  T.eq(randomized.enemy.mon, randomized.enemyParty[1],
    "the active enemy battler is rebuilt from the finalized lead")
  T.eq(randomized.ascendantForcedSource, "gym",
    "Master battles carry the central gym source marker")
  T.eq(randomized.ascendantForcedRandomized, true,
    "QA metadata records a preserved randomized roster")
  T.eq(#record.parties, originalCount,
    "the synthetic trainer party is removed after construction")
  T.eq(pg.forcedConstructionDepth(), 0,
    "forced construction state is empty after a successful battle")

  local removeBefore = RealRuntime.hooks:wrap("trainer.party",
    function(nextParty, class, partyIndex, party)
      local downstream = nextParty(class, partyIndex, party)
      downstream[1] = {
        species = "FIXMON_B", level = 6, moves = { "FIX_SCRATCH" },
      }
      return downstream
    end, 2000, "forced-randomizer-before")
  local beforeOrder = pg.newForcedBattle(
    forcedGame, "OPP_FIX_YOUNGSTER", intended, "crown")
  removeBefore()
  T.eq(beforeOrder.enemyParty[1].species, "FIXMON_B",
    "a cooperative Randomizer also survives before Ascendant in the hook chain")
  T.eq(beforeOrder.enemyParty[1].level, 77,
    "before-Ascendant hook ordering still normalizes the intended slot level")

  local removeSwallow = RealRuntime.hooks:wrap("trainer.party",
    function()
      return record.parties[1]
    end, 2000, "forced-randomizer-swallow")
  local swallowed = pg.newForcedBattle(
    forcedGame, "OPP_FIX_YOUNGSTER", intended, "heritage")
  removeSwallow()
  T.same({ swallowed.enemyParty[1].species,
           swallowed.enemyParty[2].species },
    { "FIXMON_A", "FIXMON_B" },
    "an explicit swallowed vanilla party-one result falls back to authored data")
  T.eq(swallowed.ascendantForcedFallbackReason, "vanilla_party",
    "the central guard reports the party-one fallback reason")

  local removeInvalid = RealRuntime.hooks:wrap("trainer.party",
    function() return {} end, 2000, "forced-randomizer-invalid")
  local recovered = pg.newForcedBattle(
    forcedGame, "OPP_FIX_YOUNGSTER", intended, "johto_master")
  removeInvalid()
  T.eq(#recovered.enemyParty, 2,
    "an empty Randomizer result recovers through the registered synthetic team")
  T.eq(recovered.enemyParty[2].level, 79,
    "the recovered Johto Master roster retains its authored level pattern")
  T.eq(recovered.ascendantForcedFallbackReason, "invalid_hook_party",
    "invalid hook output is visible in forced-battle QA metadata")

  local beforeErrorCount = #record.parties
  local ok = pcall(pg.newForcedBattle, forcedGame, "OPP_FIX_YOUNGSTER",
    { { species = "NO_SUCH_SPECIES", level = 50 } }, "tournament")
  T.eq(ok, false, "an invalid forced roster fails without building a corrupt battle")
  T.eq(#record.parties, beforeErrorCount,
    "constructor errors never leak a synthetic trainer party")
  T.eq(pg.forcedConstructionDepth(), 0,
    "constructor errors never leak forced hook state")

  local normalRandomizer = RealRuntime.hooks:wrap("trainer.party",
    function(nextParty, class, partyIndex, party)
      nextParty(class, partyIndex, party)
      return {
        { species = "FIXMON_B", level = 5 },
        { species = "FIXMON_B", level = 5 },
      }
    end, -100, "normal-rematch-randomizer")
  local normal = BattleState.newTrainer(
    forcedGame, "OPP_FIX_YOUNGSTER", 1)
  normalRandomizer()
  T.eq(normal.enemyParty[1].species, "FIXMON_B",
    "ordinary trainer construction still preserves Randomizer species")
  T.eq(normal.ascendantForcedBattle, nil,
    "ordinary field fights never inherit forced-battle metadata")

  record.parties = originalParties
end

run.loader.modSave = game.save.modData
do
  local onboarding = assert(ex.onboarding)
  T.eq(onboarding.text():find("ASCENDANT", 1, true) ~= nil, true,
    "the one-time 5.0 orientation introduces the Ascendant menu")
  T.eq(onboarding.text():find("ROUTE 5", 1, true) ~= nil, true,
    "the orientation points both new and upgraded saves to Route 5")
  T.eq(onboarding.text():find("ELM", 1, true) ~= nil, true,
    "the orientation introduces Elm's research line in English")
  local onboardingState = onboarding.state()
  onboardingState.shown = false
  T.eq(onboarding.shouldShow(game), false,
    "the 5.0 orientation stays hidden before the Hall of Fame")
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  T.eq(onboarding.shouldShow(game), true,
    "an existing post-game save receives the 5.0 orientation once")
  onboardingState.shown = true
  T.eq(onboarding.shouldShow(game), false,
    "the orientation does not repeat after save, restart or mod re-enable")
end
local textBoxStub = {
  new = function(g, text, onDone, opts)
    return { text = text, onDone = onDone, opts = opts or {} }
  end,
  substitute = function(g, text) return "sub:" .. text end,
}
local Pokemon = require("src.pokemon.Pokemon")
local battleStateStub = {
  newTrainer = function(g, cls, party)
    local record = g.data.trainers[cls]
    local enemyParty = {}
    for _, slot in ipairs(record.parties[party]) do
      local species = g.data.pokemon[slot.species] and slot.species or "FIXMON_A"
      enemyParty[#enemyParty + 1] =
        Pokemon.new(g.data, species, slot.level, function() return 8 end)
    end
    local lead = enemyParty[1]
    local b = { game = g, trainer = record, enemyParty = enemyParty,
                enemy = { mon = lead, curStats = lead.stats,
                          curMoves = lead.moves, shownHP = lead.hp },
                queue = {} }
    calls.battles[#calls.battles + 1] = { cls = cls, party = party, battle = b }
    return b
  end,
  -- vanilla-shaped victory: award money, queue the prize line + a flavor line
  enemyMonFainted = function(self)
    local prize = (self.trainer.baseMoney or 0) * self.enemy.mon.level
    self.game.save.money = self.game.save.money + prize
    self:sayNext(("RED got ¥%d\nfor winning!"):format(prize))
    self:sayNext("RED defeated\nYOUNGSTER!")
  end,
  finish = function(self)
    if self.payDay and self.result == "win" then
      self.game.save.money = self.game.save.money + self.payDay
      self.paid = self.payDay
    end
  end,
}
local runtimeStub = { emit = function(_, name, payload)
  calls.engaged = calls.engaged + 1 end }
local scriptedFlag = { value = false }
local mapScriptsStub = { talkScript = function()
  return scriptedFlag.value end }
local vanillaTalkTo = function() calls.vanillaTalk = calls.vanillaTalk + 1 end
local vanillaEngageTrainer = function(self, npc, onDone)
  calls.vanillaEngaged = (calls.vanillaEngaged or 0) + 1
  game.save.defeatedTrainers[npc.id] = true
  if onDone then onDone() end
end
local overworldStub = {
  talkTo = vanillaTalkTo,
  engageTrainer = vanillaEngageTrainer,
}

local installDeps = {
  overworld = overworldStub, battleState = battleStateStub,
  textBox = textBoxStub, runtime = runtimeStub,
  mapScripts = mapScriptsStub,
  random = function(lo) return lo end,
  lootRandom = function() return 10000 end,
  wildsRandom = function(lo) return lo end,
}
ex.install(game, installDeps)
T.neq(ex.wildsCompat, nil,
  "Wilds of Kanto compatibility is exported")
T.eq(ex.wildsCompat.installed, true,
  "the active Wilds of Kanto instance is wrapped during install")
T.eq(ex.wildsCompat.terrainForSurface("CAVE"), "indoor",
  "Wilds cave surfaces map to Ascendant's indoor habitats")
calls.preHallWild = calls.fakeWildsLogic:trySpawn(game, {})
T.eq(calls.preHallWild.species, "FIXMON_A",
  "Wilds remains on native Kanto encounters before the Hall of Fame")

-- A Master Leader already beaten once remains repeatable, but reports the
-- exact boss cooldown before offering another battle.
game.save.hallOfFame = { {} }
game.save.pokedex = { seen = {}, owned = {} }
ex.johtoResearch.state().rewards.NATU = true
T.eq(#ex.johtoResearch.habitatCandidates(
    "ROUTE_22", "grass", ex.johtoResearch.state()), 1,
  "Natu's researched Route 22 habitat is eligible")
calls.explicitWild = calls.fakeWildsLogic:trySpawn(game, {
  species = "FIXMON_B", level = 31, testSpawn = true,
})
T.eq(calls.explicitWild.species, "FIXMON_B",
  "Wilds developer/test spawns are never replaced by Ascendant")

;(function()
  local invalidated, received
  local logic = {
    activeMapId = "ROUTE_22",
    surfaceInfo = { surface = "GRASS" },
    render = {
      invalidateAssetCache = function(_, species) invalidated = species end,
    },
  }
  logic.mod = {
    world = {
      overworld = function()
        return { map = { id = "ROUTE_22" } }
      end,
    },
  }
  logic.trySpawn = function(_, _, opts)
    received = opts
    return { species = opts.species or "FIXMON_A", level = opts.level or 5 }
  end
  local research = {
    rollHabitat = function(mapId, terrain, rng)
      T.eq(mapId, "ROUTE_22",
        "Wilds forwards the live map to the Johto habitat selector")
      T.eq(terrain, "grass",
        "Wilds translates its surface to Ascendant encounter terrain")
      T.eq(rng(1, 100), 1,
        "Wilds supplies the configured random source to the habitat selector")
      return { species = "NATU", level = 18 }
    end,
  }
  local makeCompat = assert(loadfile(modPath .. "/wilds_compat.lua"))()
  local compat = makeCompat({ log = { info = function() end } }, {
    johtoResearch = research,
  })
  local compatGame = {
    mods = { exports = { overworld_wild_spawns = { logic = logic } } },
  }
  T.eq(compat.install(compatGame, {
    random = function(lo) return lo end,
  }), true, "a compatible Wilds export installs cleanly")
  local record = logic:trySpawn(compatGame, {})
  T.eq(record.species, "NATU",
    "a researched Johto habitat becomes a visible Wilds of Kanto spawn")
  T.eq(record.level, 18,
    "the visible Johto spawn keeps its authored habitat level")
  T.eq(received.species, "NATU",
    "the selected Johto species reaches Wilds through its public spawn options")
  T.eq(invalidated, "NATU",
    "Wilds refreshes its late species asset before the first Johto spawn")
end)()
pg.game = game
local livePostgame = pg.state()
livePostgame.masterWins.brock = true
livePostgame.bossRest["master:brock"] = 42
livePostgame.masterWins.misty = nil
RealRuntime.emit("battle.ended", {
  result = "win",
  battle = { postgameTier = "master", postgameGym = "misty" },
})
T.eq(livePostgame.masterWins.misty, true,
  "battle.ended permanently records a Master clear before onFinish")
livePostgame.masterWins.surge = nil
ex.ascendant.state().bossBattles["gym:surge:master"] = 1
T.eq(pg.repairGymWinsFromHistory(), true,
  "victory-only boss history repairs a missing Master Circuit clear")
T.eq(livePostgame.masterWins.surge, true,
  "the repaired Master Circuit immediately restores the missing crest")
local masterNpc = {
  def = { trainerClass = "OPP_BROCK" }, frozen = false,
  facePlayer = function() end,
}
local masterOw = { map = { id = "PEWTER_GYM" }, player = {} }
local realTextBoxModule = package.loaded["src.render.TextBox"]
package.loaded["src.render.TextBox"] = textBoxStub
run.loader.modOptions.trainer_rematch = { language = "de" }
T.eq(pg.handleTalk(masterOw, masterNpc, game), true,
  "a resting Master Leader consumes the conversation")
package.loaded["src.render.TextBox"] = realTextBoxModule
T.eq(pushed[#pushed].text:find("42", 1, true) ~= nil, true,
  "a resting Master Leader reports the exact steps remaining")
T.eq(pushed[#pushed].text:find("Schritten", 1, true) ~= nil, true,
  "Master Leader cooldown dialogue follows the selected language")
run.loader.modOptions.trainer_rematch = nil

pushed = {}
local labScientist = {
  def = { name = "OAKSLAB_SCIENTIST1" }, frozen = false,
  facePlayer = function() end,
}
local labOw = {
  map = { id = "OAKS_LAB" }, player = {},
  afterBattle = function() calls.after = calls.after + 1 end,
  pushBattle = function(self, battle) calls.pushedBattle = battle end,
}
package.loaded["src.render.TextBox"] = textBoxStub
T.eq(pg.handleTalk(labOw, labScientist, game), true,
  "Oak's Lab scientist opens the research log after the Hall of Fame")
package.loaded["src.render.TextBox"] = realTextBoxModule
T.eq(pushed[#pushed].text:find("OAK RESEARCH LOG", 1, true) ~= nil, true,
  "the live Lab conversation displays the research log")

livePostgame.apexChampion = true
livePostgame.catches.ARTICUNO = true
pushed = {}
local huntRivalNpc = {
  def = { name = pgd.huntRival.name, trainerClass = pgd.huntRival.class },
  frozen = false,
  facePlayer = function() end,
}
package.loaded["src.render.TextBox"] = textBoxStub
T.eq(pg.handleTalk(labOw, huntRivalNpc, game), true,
  "the legendary-hunt Rival consumes his Lab conversation")
T.eq(type(pushed[#pushed].opts.choice), "function",
  "the Rival event offers its own YES/NO battle prompt")
pushed[#pushed].opts.choice(false)
package.loaded["src.render.TextBox"] = realTextBoxModule
T.eq(pushed[#pushed].text:find("will not", 1, true) ~= nil, true,
  "declining the Rival event gets a character-specific response")
pushed[#pushed].onDone()
T.eq(huntRivalNpc.frozen, false,
  "closing the Rival decline response releases the NPC")

pushed = {}
local huntRivalWinNpc = {
  def = { name = pgd.huntRival.name, trainerClass = pgd.huntRival.class },
  frozen = false,
  facePlayer = function() end,
}
local oldRivalRecord = Data.trainers.OPP_RIVAL3
Data.trainers.OPP_RIVAL3 = {
  baseMoney = 1, parties = { pgd.huntRival.team },
}
local oldBattleStateModule = package.loaded["src.battle.BattleState"]
package.loaded["src.render.TextBox"] = textBoxStub
package.loaded["src.battle.BattleState"] = battleStateStub
T.eq(pg.handleTalk(labOw, huntRivalWinNpc, game), true,
  "the Rival's accepted event is handled in Oak's Lab")
pushed[#pushed].opts.choice(true)
package.loaded["src.battle.BattleState"] = oldBattleStateModule
package.loaded["src.render.TextBox"] = realTextBoxModule
Data.trainers.OPP_RIVAL3 = oldRivalRecord
T.eq(calls.pushedBattle.postgameHuntRival, true,
  "accepting starts the dedicated legendary-hunter battle")
T.eq(calls.pushedBattle.rematch, true,
  "the Rival event is marked as a no-money rematch battle")
calls.pushedBattle.onFinish("win")
T.eq(livePostgame.huntRivalWon, true,
  "winning the Rival event is stored permanently")
T.eq(pushed[#pushed].text:find("Take the data", 1, true) ~= nil, true,
  "the Rival shares his hunt report after losing")
pushed[#pushed].onDone()
T.eq(huntRivalWinNpc.frozen, false,
  "finishing the Rival event releases its NPC")
livePostgame.apexChampion = nil
livePostgame.catches.ARTICUNO = nil
livePostgame.huntRivalWon = nil
calls.battles = {}
calls.pushedBattle = nil
pushed = {}
game.save.hallOfFame = {}

local npcSerial = 0
local function freshNpc(id)
  npcSerial = npcSerial + 1
  local npc = {
    id = id or ("FIX_ROUTE_obj_" .. npcSerial),
    def = { trainerClass = "OPP_FIX_YOUNGSTER", trainerParty = 1,
            text = "X", index = 1 },
    frozen = false,
    facePlayer = function() end,
  }
  local bucket = game.save.modData.trainer_rematch or {}
  game.save.modData.trainer_rematch = bucket
  bucket.trainers = bucket.trainers or {}
  bucket.trainers[npc.id] = { rematches = 0, readyAt = 0 }
  return npc
end
local ow = {
  map = { id = "FIX_ROUTE", def = { label = "FixRoute" } },
  player = {},
  trainerDefeated = function() return true end,
  afterBattle = function() calls.after = calls.after + 1 end,
  pushBattle = function(self, battle) calls.pushedBattle = battle end,
}

-- A0: a defeated trainer whose old save has no mod record is repaired lazily
local lazyNpc = freshNpc("FIX_ROUTE_obj_lazy")
game.save.modData.trainer_rematch.trainers[lazyNpc.id] = nil
overworldStub.talkTo(ow, lazyNpc)
T.eq(pushed[#pushed].text:find("151 more steps.", 1, true) ~= nil, true,
  "a missing defeated-trainer record starts a visible initial rest")
T.eq(pushed[#pushed].opts.choice, nil,
  "the repaired trainer cannot offer an immediate rematch")

-- A: beaten generic trainer -> rematch prompt with the class line
pushed = {}
local npc = freshNpc()
overworldStub.talkTo(ow, npc)
T.eq(#pushed, 1, "rematch prompt pushed")
T.eq(pushed[1].text, ex.resolveLine("OPP_FIX_YOUNGSTER"),
  "prompt shows the class line")
T.eq(type(pushed[1].opts.choice), "function", "prompt carries a YES/NO choice")
T.eq(npc.frozen, true, "npc frozen while the prompt is up")

-- B: YES -> battle starts, flagged as rematch, no victory rewards
pushed[1].opts.choice(true)
T.eq(calls.engaged, 1, "trainer_engaged emitted")
T.eq(#calls.battles, 1, "one battle created")
T.eq(calls.battles[1].cls, "OPP_FIX_YOUNGSTER", "battle uses the npc class")
T.eq(calls.battles[1].party, 1, "battle uses the npc party")
local b = calls.battles[1].battle
T.eq(b.rematch, true, "battle flagged as rematch")
T.eq(b.rematchNumber, 1, "first repeat is identified as rematch one")
T.eq(b.rematchLevelBoost, 2, "first rematch receives the default level boost")
T.eq(b.enemyParty[1].level,
  Data.trainers.OPP_FIX_YOUNGSTER.parties[1][1].level + 2,
  "the actual enemy party is stronger, not just the preview")
local baseLead = Pokemon.new(Data, "FIXMON_A", 5, function() return 8 end)
T.eq(b.enemyParty[1].stats.hp > baseLead.stats.hp, true,
  "the boosted level recalculates real battle stats")
local learnedAtSeven = false
for _, move in ipairs(b.enemyParty[1].moves) do
  if move.id == "FIX_EMBERISH" then learnedAtSeven = true break end
end
T.eq(learnedAtSeven, true, "training can teach newly reached level-up moves")
T.eq(b.endBattleText, "sub:Well fixed!", "loss line still shown")
T.neq(b.onFinish, nil, "onFinish wired")
local afterCount = calls.after
b.onFinish("win")
T.eq(calls.after, afterCount + 1, "afterBattle ran")
T.eq(pushed[#pushed].text:find("FIELD KIT", 1, true) ~= nil, true,
  "the first won rematch awards the optional HM Field Kit")
T.eq(npc.frozen, true,
  "the trainer stays frozen until the Field Kit reward text closes")
pushed[#pushed].onDone()
T.eq(npc.frozen, false, "npc unfrozen after the reward")
local savedState = game.save.modData.trainer_rematch.trainers[npc.id]
T.eq(savedState.rematches, 1, "completed rematch count persists per trainer")
T.eq(ex.remainingSteps(npc.id), 151, "trainer starts the configured rest")

-- B2: the same trainer refuses until enough real world steps pass
pushed = {}
overworldStub.talkTo(ow, npc)
T.eq(#pushed, 1, "resting trainer shows one status box")
T.eq(pushed[1].text:find("151 more steps.", 1, true) ~= nil, true,
  "rest status shows the exact remaining steps")
T.eq(pushed[1].text:find("\f", 1, true) ~= nil, true,
  "the trainer's normal text follows the step status as a second page")
T.eq(pushed[1].text:find("Nice fixture.", 1, true) ~= nil, true,
  "the second cooldown page preserves the normal post-battle line")
T.eq(pushed[1].opts.choice, nil, "resting trainer offers no battle choice")
pushed[1].onDone()
for _ = 1, 150 do run.loader.events:emit("world.stepped", {}) end
T.eq(ex.remainingSteps(npc.id), 1, "only completed world steps count down")
pushed = {}
overworldStub.talkTo(ow, npc)
T.eq(pushed[1].text:find("1 more step.", 1, true) ~= nil, true,
  "the final cooldown step is reported in singular")
run.loader.events:emit("world.stepped", {})
T.eq(ex.remainingSteps(npc.id), 0, "trainer becomes ready at the deadline")
pushed = {}
overworldStub.talkTo(ow, npc)
T.eq(pushed[1].text, ex.resolveLine("OPP_FIX_YOUNGSTER"),
  "the challenge returns after the cooldown")
pushed[1].opts.choice(true)
local b2 = calls.battles[#calls.battles].battle
T.eq(b2.rematchNumber, 2, "the returning trainer starts rematch two")
T.eq(b2.rematchLevelBoost, 4, "the returning trainer has grown again")
T.eq(b2.enemyParty[1].level,
  Data.trainers.OPP_FIX_YOUNGSTER.parties[1][1].level + 4,
  "second-rematch level growth reaches the battle party")
T.eq(#b2.enemyParty, 3,
  "the second growth tier expands a two-Pokémon trainer to three")
T.eq(b2.rematchRecruits, 1,
  "the rematch battle records one newly recruited party member")
T.eq(b2.enemyParty[3].species, "RAICHU",
  "the recruited Pokémon is appended to the actual battle party")
T.eq(b2.enemyParty[3].level, 9,
  "the recruit receives the same final rematch level growth")

-- C: NO -> the class reacts, then the vanilla post-battle line as a page
pushed = {}
local npc2 = freshNpc()
overworldStub.talkTo(ow, npc2)
pushed[1].opts.choice(false)
T.eq(#pushed, 2, "decline pushes the reaction box")
T.eq(pushed[2].text:lower():find("scared", 1, true) ~= nil, true,
  "decline shows the class reaction")
T.eq(pushed[2].text:find("Nice fixture.", 1, true) ~= nil, true,
  "vanilla after text kept as a second page")
T.eq(pushed[2].text:find("\f", 1, true) ~= nil, true, "pages joined by \\f")
T.eq(calls.vanillaTalk, 0, "no vanilla fallback on decline with after text")
pushed[2].onDone()
T.eq(npc2.frozen, false, "npc unfrozen after the reaction box")

-- D: decline with no post-battle header -> just the default reaction
pushed = {}
local owNoHeader = {
  map = { id = "SOMEWHERE", def = { label = "Nowhere" } },
  player = {},
  trainerDefeated = function() return true end,
  afterBattle = function() end,
  pushBattle = function() end,
}
local npc3 = freshNpc()
overworldStub.talkTo(owNoHeader, npc3)
pushed[1].opts.choice(false)
T.eq(#pushed, 2, "reaction box pushed without a header")
T.eq(pushed[2].text, ex.resolveDecline("OPP_FIX_YOUNGSTER"),
  "default reaction used when the class has no header")
T.eq(pushed[2].text:find("\f", 1, true) == nil, true,
  "no \\f page when there is no after text")
T.eq(calls.vanillaTalk, 0, "no vanilla fallback on decline without a header")
pushed[2].onDone()
T.eq(npc3.frozen, false, "npc unfrozen after the reaction box")

-- E: unbeaten trainers keep the vanilla flow
calls.vanillaTalk = 0
local owUnbeaten = {
  map = { id = "FIX_ROUTE", def = { label = "FixRoute" } },
  player = {},
  trainerDefeated = function() return false end,
  afterBattle = function() end,
  pushBattle = function() end,
}
overworldStub.talkTo(owUnbeaten, freshNpc())
T.eq(calls.vanillaTalk, 1, "unbeaten trainer uses the vanilla talk")

-- E2: winning the original encounter starts the first rest period
local originalNpc = freshNpc("FIX_ROUTE_obj_original")
local originalDone = 0
local owOriginal = {
  map = ow.map,
  trainerDefeated = function(_, candidate)
    return game.save.defeatedTrainers[candidate.id] == true
  end,
}
overworldStub.engageTrainer(owOriginal, originalNpc, function()
  originalDone = originalDone + 1
end)
T.eq(calls.vanillaEngaged, 1, "the original trainer flow still runs")
T.eq(originalDone, 1, "the original completion callback still runs")
T.eq(ex.remainingSteps(originalNpc.id), 151,
  "a newly beaten trainer is not immediately ready for a rematch")

-- E2b: ignoring a ready trainer does not freeze its strength. The visible
-- cooldown ends first; each additional silent cooldown grows the next team
-- while the trainer remains continuously available.
for _ = 1, 151 do run.loader.events:emit("world.stepped", {}) end
T.eq(ex.remainingSteps(originalNpc.id), 0,
  "the ignored trainer becomes ready after the visible cooldown")
T.eq(ex.trainingCycles(originalNpc.id), 0,
  "becoming ready starts rather than completes the first silent cycle")
for _ = 1, 150 do run.loader.events:emit("world.stepped", {}) end
T.eq(ex.trainingCycles(originalNpc.id), 0,
  "an incomplete silent cycle grants no speculative growth")
run.loader.events:emit("world.stepped", {})
T.eq(ex.trainingCycles(originalNpc.id), 1,
  "a completed silent counter grows an ignored trainer in the background")
T.eq(ex.remainingSteps(originalNpc.id), 0,
  "silent training never makes a ready trainer unavailable again")
pushed = {}
overworldStub.talkTo(ow, originalNpc)
pushed[1].opts.choice(true)
local idleBattle = calls.battles[#calls.battles].battle
T.eq(idleBattle.rematchNumber, 1,
  "the ignored trainer still calls this its first actual rematch")
T.eq(idleBattle.rematchTrainingCycles, 1,
  "the battle records the completed silent training cycle")
T.eq(idleBattle.rematchLevelBoost, 4,
  "one silent cycle raises the first rematch from +2 to +4 levels")

-- E3: enabling the mod on an existing CONTINUE slot seeds old victories
local oldTimerSave = {
  trainer_rematch = {
    step_clock = 100,
    trainers = {
      OLD_TIMER = {
        rematches = 1, trainingCycles = 0,
        readyAt = 228, lastRest = 128,
        nextTrainingAt = 356, lastTraining = 128,
      },
    },
  },
}
run.loader.modSave = oldTimerSave
ex.migrateRestTimers({ random = function(_, hi) return hi end })
local migratedTimer = oldTimerSave.trainer_rematch.trainers.OLD_TIMER
T.eq(migratedTimer.readyAt, 2610,
  "an active legacy cooldown rerolls once into the expanded range")
T.eq(migratedTimer.nextTrainingAt, 5120,
  "the following silent cycle adopts the expanded range too")

local legacySave = {
  defeatedTrainers = { LEGACY_ROUTE_obj_3 = true },
  modData = {},
}
run.loader.modSave = legacySave.modData
run.loader.events:emit("save.loaded", { save = legacySave })
local legacyLeft = ex.remainingSteps("LEGACY_ROUTE_obj_3")
T.eq(legacyLeft >= 151 and legacyLeft <= 2510, true,
  "loaded saves give previously beaten trainers an initial rest")
run.loader.modSave = game.save.modData

-- F: scripted trainers (gym leaders, rivals) keep their flow
calls.vanillaTalk = 0
pushed = {}
scriptedFlag.value = true
overworldStub.talkTo(ow, freshNpc())
T.eq(calls.vanillaTalk, 1, "scripted trainer skips the rematch prompt")
T.eq(#pushed, 0, "no rematch prompt for scripted trainers")
scriptedFlag.value = false

-- G: rematch win awards no money and drops the prize line
local moneyBefore = game.save.money
local rematch = { game = game, rematch = true,
  trainer = { baseMoney = 150, name = "FIX YOUNGSTER" },
  enemy = { mon = { level = 10 } }, queue = {},
  sayNext = function(self, text) table.insert(self.queue, text) end }
battleStateStub.enemyMonFainted(rematch)
T.eq(game.save.money, moneyBefore, "rematch awards no money")
T.eq(#rematch.queue, 1, "prize line dropped")
T.eq(rematch.queue[1], "RED defeated\nYOUNGSTER!", "flavor line kept")
T.eq(rematch.trainer.baseMoney, 150, "shared trainer record untouched")

-- H: the first (non-rematch) fight still pays
moneyBefore = game.save.money
local normal = { game = game, rematch = false,
  trainer = { baseMoney = 150, name = "FIX YOUNGSTER" },
  enemy = { mon = { level = 10 } }, queue = {},
  sayNext = function(self, text) table.insert(self.queue, text) end }
battleStateStub.enemyMonFainted(normal)
T.eq(game.save.money, moneyBefore + 1500, "normal win still pays")
T.eq(#normal.queue, 2, "prize line kept on normal wins")

-- I: Pay Day pays nothing on a rematch
moneyBefore = game.save.money
local pay = { game = game, rematch = true, payDay = 500, result = "win" }
battleStateStub.finish(pay)
T.eq(pay.paid, nil, "pay day suppressed on rematch")
T.eq(game.save.money, moneyBefore, "no money from pay day on rematch")

-- J: Pay Day still pays in normal battles
moneyBefore = game.save.money
local pay2 = { game = game, rematch = false, payDay = 500, result = "win" }
battleStateStub.finish(pay2)
T.eq(pay2.paid, 500, "pay day pays normally")
T.eq(game.save.money, moneyBefore + 500, "money credited normally")

-- K: a class with a marked rematch team (the Yellow Legacy pattern) uses
-- that party for the rematch instead of the trainer's own -- and since
-- the marked team averages far above the player's party, the class warns
-- first and only battles after a second confirmation
Data.trainers["OPP_FIX_MISTY"] = {
  id = "OPP_FIX_MISTY", name = "MISTY", index = 35, baseMoney = 40,
  parties = {
    { { level = 18, species = "STARYU" }, { level = 21, species = "STARMIE" } },
    { { level = 64, species = "SEADRA" }, { level = 65, species = "STARMIE" } },
  },
  rematchIndex = 2,
}
local mistyBattles = #calls.battles
local pushedBefore = #pushed
local mistyNpc = freshNpc()
mistyNpc.def.trainerClass = "OPP_FIX_MISTY"
overworldStub.talkTo(ow, mistyNpc)
T.eq(#pushed, pushedBefore + 1, "the rematch prompt is pushed")
pushed[#pushed].opts.choice(true)
T.eq(#calls.battles, mistyBattles, "no battle yet: the warning comes first")
T.eq(#pushed, pushedBefore + 2, "the strength warning is pushed")
T.eq(pushed[#pushed].text, ex.resolveWarning("OPP_FIX_MISTY"),
  "the warning speaks in the class's default voice")
pushed[#pushed].opts.choice(true)
T.eq(#calls.battles, mistyBattles + 1, "confirming the warning starts the battle")
T.eq(calls.battles[#calls.battles].party, 2,
  "the marked rematch team is used")
T.eq(calls.battles[#calls.battles].battle.rematch, true,
  "the marked-rematch battle is still a rematch")

-- L: declining the warning walks away without a battle
local lBefore = #calls.battles
local pushedL = #pushed
mistyNpc.frozen = false
overworldStub.talkTo(ow, mistyNpc)
pushed[#pushed].opts.choice(true)
pushed[#pushed].opts.choice(false)
T.eq(#calls.battles, lBefore, "declining the warning starts no battle")
T.eq(#pushed, pushedL + 3, "the decline line follows")

-- M: a small level gap skips the warning and battles directly
local lvlBattles = #calls.battles
local pushedM = #pushed
local lvlNpc = freshNpc()
overworldStub.talkTo(ow, lvlNpc)
T.eq(#pushed, pushedM + 1, "the rematch prompt is pushed")
pushed[#pushed].opts.choice(true)
T.eq(#calls.battles, lvlBattles + 1, "a close team battles straight away")
T.eq(calls.battles[#calls.battles].party, 1, "it uses the trainer's own party")

-- N: the level-gap math behind the warning
T.eq(ex.levelGap({ { level = 5 }, { level = 7 } },
  { { level = 64 }, { level = 65 } }), 58.5, "the gap is team average minus party average")
T.eq(ex.levelGap({ { level = 60 }, { level = 60 } },
  { { level = 55 }, { level = 55 } }), -5, "an easier team is a negative gap")
T.eq(ex.levelGap(nil, { { level = 64 } }), nil, "an empty party yields no gap")
T.eq(ex.levelGap({ { level = 5 } }, nil), nil, "an empty team yields no gap")

-- O: successful loot, full-bag reservation and later delivery
Data.items.NUGGET = { id = "NUGGET", name = "NUGGET", price = 5000 }
run.loader.modOptions.trainer_rematch = { loot_mode = "balanced" }
installDeps.lootRandom = function() return 2901 end
game.save.inventory, game.save.bagOrder = {}, {}
pushed = {}
local lootNpc = freshNpc("FIX_ROUTE_obj_loot")
overworldStub.talkTo(ow, lootNpc)
pushed[1].opts.choice(true)
local lootBattle = calls.battles[#calls.battles].battle
lootBattle.onFinish("win")
T.eq(game.save.inventory.NUGGET, 1,
  "a winning eligible rematch puts its rolled Nugget in the Bag")
T.eq(pushed[#pushed].text:find("NUGGET", 1, true) ~= nil, true,
  "the player sees the awarded item after the battle")
T.eq(lootNpc.frozen, true,
  "the trainer remains frozen until the loot message closes")
pushed[#pushed].onDone()
T.eq(lootNpc.frozen, false, "closing the loot message releases the trainer")

game.save.inventory, game.save.bagOrder = {}, {}
for i = 1, 20 do
  local id = "FILLER_" .. i
  game.save.inventory[id] = 1
  game.save.bagOrder[i] = id
end
pushed = {}
local fullNpc = freshNpc("FIX_ROUTE_obj_full_loot")
overworldStub.talkTo(ow, fullNpc)
pushed[1].opts.choice(true)
local fullBattle = calls.battles[#calls.battles].battle
fullBattle.onFinish("win")
local fullState =
  game.save.modData.trainer_rematch.trainers[fullNpc.id]
T.eq(game.save.inventory.NUGGET, nil,
  "a full Bag never destroys or silently inserts the rolled item")
T.eq(fullState.pendingLoot.item, "NUGGET",
  "the trainer keeps an undeliverable reward for the player")
pushed[#pushed].onDone()

pushed = {}
overworldStub.talkTo(ow, fullNpc)
T.eq(pushed[1].text:find("BAG is", 1, true) ~= nil, true,
  "talking again explains that the reserved reward still cannot fit")
T.eq(fullState.pendingLoot.item, "NUGGET",
  "the pending reward survives another full-Bag conversation")
pushed[1].onDone()
game.save.inventory.FILLER_1 = nil
pushed = {}
overworldStub.talkTo(ow, fullNpc)
T.eq(game.save.inventory.NUGGET, 1,
  "making room lets the trainer deliver the reserved reward")
T.eq(fullState.pendingLoot, nil,
  "a delivered pending reward is cleared exactly once")
pushed[1].onDone()
installDeps.lootRandom = function() return 10000 end
run.loader.modOptions.trainer_rematch = nil

-- P: an actual circuit battle receives the personal in-battle defeat quote
game.save.hallOfFame = { {} }
for _, gym in ipairs(pgd.gyms) do livePostgame.masterWins[gym.key] = true end
livePostgame.apexChampion = nil
pg.game = game
local eliteBattle = { kind = "trainer", oppClass = "OPP_LORELEI" }
RealRuntime.emit("battle.started", { battle = eliteBattle })
T.eq(eliteBattle.postgameTier, "apex",
  "an active Elite Four battle is tagged with the Apex tier")
T.eq(eliteBattle.rematch, true,
  "an active Elite Four circuit fight is treated as a no-money rematch")
T.eq(eliteBattle.endBattleText:find("perfected", 1, true) ~= nil, true,
  "the circuit battle receives Lorelei's personal defeat quote")

-- ------------------------------------------------ Kanto Ascendant 2.0 systems

local asc = ex.ascendant
local asd = ex.ascendantData
local heritage = ex.eventArchive
local heritageData = ex.eventData
T.neq(asc, nil, "the Ascendant systems controller is exported")
T.neq(asd, nil, "the Ascendant progression data is exported")
T.neq(heritage, nil, "the permanent Event Archive controller is exported")
T.neq(heritageData, nil, "the historical event profiles are exported")
local longestEventLabelEn, longestEventLabelDe = 0, 0
for _, profile in ipairs(heritageData.profiles) do
  longestEventLabelEn = math.max(longestEventLabelEn, #profile.short.en)
  longestEventLabelDe = math.max(longestEventLabelDe, #profile.short.de)
end
T.eq(longestEventLabelEn <= 10, true,
  "English Event Archive labels leave room for their status")
T.eq(longestEventLabelDe <= 10, true,
  "German Event Archive labels leave room for their status")

T.eq(asc.rematchRank(0).key, "rookie",
  "a new field opponent begins at ROOKIE rank")
T.eq(asc.rematchRank(2).key, "veteran",
  "two completed growth tiers reach VETERAN rank")
T.eq(asc.rematchRank(5).key, "expert",
  "five completed growth tiers reach EXPERT rank")
T.eq(asc.rematchRank(10).key, "master",
  "ten completed growth tiers reach MASTER rank")
T.eq(asc.rematchRank(20).key, "legend",
  "twenty completed growth tiers reach LEGEND rank")
T.eq(asc.rankBonusLoot(7500, "veteran", 10), nil,
  "VETERAN rank no longer inflates the configured loot table")
T.eq(asc.rankBonusLoot(8000, "expert", 20), nil,
  "EXPERT rank no longer adds a hidden Rare Candy band")
T.eq(asc.rankBonusLoot(8500, "master", 35), nil,
  "MASTER rank no longer adds a hidden PP Up band")
T.eq(asc.rankBonusLoot(9000, "legend", 50), nil,
  "LEGEND rank no longer adds a hidden Max Revive band")

T.eq(#asd.ranks, 5, "all five field-trainer ranks are defined")
T.eq(#asd.research, 8, "Oak offers eight sequential research assignments")
T.eq(#asd.achievements, 17, "the Crown Archive tracks all seventeen titles")
T.eq(#asd.rocket, 4, "Rocket Resurgence has four consecutive operations")
T.eq(#asd.tournament.opponents, 6,
  "the Grand Tournament has six rotating level-100 opponents")
T.eq(#asd.tournament.rules, 6,
  "the Grand Tournament rotates six different rulesets")
local leaderMissionCount = 0
for key, quest in pairs(asd.gymQuests) do
  leaderMissionCount = leaderMissionCount + 1
  T.eq(type(quest.intro.en), "string",
    key .. " has English personal-mission dialogue")
  T.eq(type(quest.intro.de), "string",
    key .. " has German personal-mission dialogue")
  T.eq(quest.target > 0, true, key .. " has a measurable mission target")
end
T.eq(leaderMissionCount, 8,
  "all eight Gym Leaders have personal missions")
for _, operation in ipairs(asd.rocket) do
  T.eq(#operation.team, 6,
    operation.key .. " has a complete Rocket resurgence team")
  T.eq(type(operation.before.en), "string",
    operation.key .. " has English Rocket dialogue")
  T.eq(type(operation.before.de), "string",
    operation.key .. " has German Rocket dialogue")
end
T.eq(asd.mew.level, 100, "Mew is the level-100 mythic finale")
T.eq(type(asd.mew.clues.oak.text.en), "string",
  "Oak has the first English Mew clue")
T.eq(type(asd.mew.clues.fuji.text.de), "string",
  "Mr. Fuji has the second German Mew clue")
T.eq(type(asd.mew.clues.lab.text.en), "string",
  "the Cinnabar lab has the final English Mew clue")

T.eq(#heritageData.profiles, 6,
  "the archive contains all six Generation-I Kanto event profiles")
T.eq(#heritageData.catchupOrder, 5,
  "the five non-Mew distributions have a deterministic catch-up order")
local heritageCupCount = 0
for id, cup in pairs(heritageData.cups) do
  heritageCupCount = heritageCupCount + 1
  T.eq(#cup.opponents, 3, id .. " has a complete three-round Heritage Cup")
end
T.eq(heritageCupCount, 5,
  "five badge-gated Heritage Cups award the non-Mew events")
local eventPokemon = setmetatable({}, { __index = Data.pokemon })
for _, id in ipairs({ "MAGIKARP", "PIKACHU", "FEAROW", "RAPIDASH", "MEW" }) do
  eventPokemon[id] = Data.pokemon.FIXMON_A
end
local eventMoves = setmetatable({}, { __index = Data.moves })
for _, id in ipairs({
  "SPLASH", "DRAGON_RAGE", "THUNDERSHOCK", "GROWL", "FLY", "SURF",
  "LEER", "FURY_ATTACK", "PAY_DAY", "EMBER", "FIRE_SPIN", "STOMP", "POUND",
}) do
  eventMoves[id] = { id = id, name = id:gsub("_", " "), pp = 20 }
end
local eventDataSet = setmetatable({
  pokemon = eventPokemon, moves = eventMoves,
}, { __index = Data })
local eventGame = {
  data = eventDataSet,
  save = {
    player = { name = "RED", id = 1234 },
    party = {}, inventory = {}, flags = {},
    pokedex = { seen = {}, owned = {} },
  },
}
local historicalKarp = Pokemon.new(eventDataSet, "MAGIKARP", 5,
  function() return 8 end)
heritage.stampProfile(eventGame, historicalKarp,
  heritage.profile("university_magikarp"), "UNIVERSITY CUP")
T.eq(historicalKarp.level, 15,
  "University Magikarp keeps its historical distribution level")
T.eq(historicalKarp.moves[2].id, "DRAGON_RAGE",
  "University Magikarp keeps its unusual historical move")
T.eq(historicalKarp.eventDistribution.id, "university_magikarp",
  "event provenance is stored directly on the Pokémon")
local historicalMew = Pokemon.new(eventDataSet, "MEW", 100,
  function() return 8 end)
heritage.stampProfile(eventGame, historicalMew,
  heritage.profile("distribution_mew"), "FARAWAY ISLAND FINALE")
T.eq(historicalMew.level, 5,
  "the optional historical Mew profile restores level 5")
T.eq(historicalMew.dvs.attack, 10,
  "historical Mew keeps the fixed distribution DVs")
local eventGift = heritage.give(eventGame, "flying_pikachu", "BALLOON CUP")
T.eq(type(eventGift), "string",
  "a Heritage Cup can deliver its one-time event prize")
T.eq(eventGame.save.party[1].moves[3].id, "FLY",
  "Flying Pikachu arrives with its event-exclusive move")
T.eq(heritage.state().claimed.flying_pikachu.origin, "BALLOON CUP",
  "the Event Archive permanently records the prize origin")
eventGame.save.inventory.BOULDERBADGE = true
eventGame.save.inventory.CASCADEBADGE = true
T.eq(heritage.details(eventGame,
    heritage.profile("university_magikarp"))
    :find("READY means unlocked", 1, true) ~= nil, true,
  "an unlocked Event Archive entry explains that READY is not a claim button")
T.eq(heritage.details(eventGame,
    heritage.profile("university_magikarp"))
    :find("CERULEAN CITY", 1, true) ~= nil, true,
  "festival event details name the city containing the Cup host")

local ascState = asc.state()
ascState.bossBattles = {}
ascState.gymQuests = {}
ascState.cycle = 0
local adaptiveSource = {
  { species = "FIXMON_A", level = 90, moves = { "TACKLE" } },
  { species = "FIXMON_B", level = 91, moves = { "TACKLE" } },
  { species = "FIXMON_A", level = 92, moves = { "TACKLE" } },
}
local adaptiveGame = { data = Data, save = { party = {} } }
local adaptiveA = asc.selectBossTeam(adaptiveSource,
  { kind = "gym", key = "brock", tier = "master" }, adaptiveGame)
T.eq(adaptiveA[1].species, "FIXMON_A",
  "the first adaptive boss meeting preserves the inspected base order")
ascState.bossBattles["gym:brock:master"] = 1
local adaptiveB = asc.selectBossTeam(adaptiveSource,
  { kind = "gym", key = "brock", tier = "master" }, adaptiveGame)
T.eq(adaptiveB[1].species, "FIXMON_B",
  "a repeat boss meeting rotates its lead and battle plan")
ascState.gymQuests.brock = { done = true }
local adaptiveSignature = asc.selectBossTeam(adaptiveSource,
  { kind = "gym", key = "brock", tier = "master" }, adaptiveGame)
T.eq(adaptiveSignature[#adaptiveSignature].species, "AERODACTYL",
  "finishing Brock's mission unlocks his signature roster variant")
T.eq(adaptiveSource[3].species, "FIXMON_A",
  "adaptive selection never mutates the shared base roster")
T.eq(asc.cycleRule(1, "rotating"), "no_items",
  "Ascendant Cycle 1 seals battle items")
T.eq(asc.cycleRule(2, "rotating"), "set",
  "Ascendant Cycle 2 enforces SET battle style")
T.eq(asc.cycleRule(3, "rotating"), "trio",
  "Ascendant Cycle 3 restricts the party to a trio")
T.eq(asc.cycleRule(4, "rotating"), "purist",
  "Ascendant Cycle 4 bans legendary party members")
T.eq(asc.cycleRule(8, "rotating"), "purist",
  "the four rotating cycle rules repeat deterministically")
T.eq(asc.cycleRule(3, "normal"), "normal",
  "the NORMAL preset removes extra cycle restrictions")

local blockedItems = {
  ascendantNoItems = true,
  say = function(self, message) self.blockMessage = message end,
}
battleStateStub.openItems(blockedItems)
T.eq(blockedItems.blockMessage:find("sealed", 1, true) ~= nil, true,
  "NO-ITEM and Ascendant rules block the Bag inside battle")

ascState.research.completed = {}
for _, assignment in ipairs(asd.research) do
  ascState.research.completed[assignment.id] = true
end
ascState.rocketStage = #asd.rocket
livePostgame.crownChampion = true
livePostgame.apexChampion = true
for _, gym in ipairs(pgd.gyms) do livePostgame.crownWins[gym.key] = true end
livePostgame.catches = livePostgame.catches or {}
for _, species in ipairs(pgd.legendOrder) do
  livePostgame.catches[species] = true
end
T.eq(asc.researchComplete(ascState), true,
  "all enabled research assignments can be completed")
T.eq(asc.allEnabledLegendsCaught(game), true,
  "the finale recognizes every enabled captured legend")
T.eq(asc.mewEligible(game), true,
  "Crown, research, Rocket and legendary completion unlock Mew's clues")
run.loader.modOptions.trainer_rematch = { legend_mew = false }
T.eq(asc.mewEligible(game), false,
  "the dedicated Mew option disables the mythic finale")
run.loader.modOptions.trainer_rematch = nil

for key in pairs(asd.gymQuests) do
  ascState.gymQuests[key] = { done = true }
end
ascState.tournament.wins = 1
ascState.mewCaught = true
local goldState = ex.johtoMasters.state()
goldState.clears = 0
ascState.achievements.ascendant = nil
asc.evaluateAchievements(game)
T.eq(ascState.achievements.leader_confidant, true,
  "all Leader missions unlock KANTO CONFIDANT")
T.eq(ascState.achievements.tournament_champ, true,
  "a completed bracket unlocks GRAND CHAMPION")
T.eq(ascState.achievements.rocket_breaker, true,
  "the fourth Rocket victory unlocks ROCKET BREAKER")
T.eq(ascState.achievements.mew_found, true,
  "catching Mew unlocks MYTH SEEKER")
T.eq(ascState.achievements.ascendant, nil,
  "the first Ascendant cycle remains sealed until Gold is defeated")
T.eq(ex.questTracker.nextObjective(game).id, "gold",
  "the shared Journal and Atlas tracker identifies Gold as the final main fight")
T.eq(asc.newGamePlusReady(game), false,
  "New Game Plus cannot begin before the mandatory Gold clear")
goldState.clears = 1
asc.evaluateAchievements(game)
T.eq(ascState.achievements.ascendant, true,
  "Gold completes the required main path and unlocks KANTO ASCENDANT")
T.eq(ex.questTracker.nextObjective(game).id, "new_game_plus",
  "the tracker advances from Gold to New Game Plus")
T.eq(asc.newGamePlusReady(game), true,
  "Factory and S.S. Anne records remain optional prestige goals")

ascState.selectedTitle = "mew_found"
local catchesBeforeCycle = livePostgame.catches
local newCycle = asc.beginNewGamePlus(game)
T.eq(newCycle, 1, "the first safe New Game Plus starts Ascendant Cycle 1")
T.eq(asc.state().cycleJohtoMastersStartClears, 1,
  "a new cycle records Gold progress so a fresh Gold clear is required")
T.eq(pg.state().apexChampion, nil,
  "New Game Plus resets the Apex circuit")
T.eq(pg.state().crownChampion, nil,
  "New Game Plus resets the Crown circuit")
T.eq(pg.state().catches, catchesBeforeCycle,
  "New Game Plus preserves captured legendary progress")
T.eq(asc.state().mewCaught, true,
  "New Game Plus preserves the unique Mew capture")
T.eq(asc.state().achievements.ascendant, true,
  "New Game Plus preserves permanent titles")
T.eq(asc.state().selectedTitle, "mew_found",
  "New Game Plus preserves the player's selected Trainer Card title")
T.eq(heritage.state().claimed.flying_pikachu.origin, "BALLOON CUP",
  "New Game Plus preserves the separate permanent Event Archive")
local cycleTeam = asc.selectBossTeam(adaptiveSource,
  { kind = "gym", key = "brock", tier = "master" }, adaptiveGame)
for _, slot in ipairs(cycleTeam) do
  T.eq(slot.level, 100,
    "every post-game boss slot reaches level 100 in New Game Plus")
end
run.loader.modOptions.trainer_rematch = { ascendant_rules = "normal" }
local relaxedCycleTeam = asc.selectBossTeam(adaptiveSource,
  { kind = "gym", key = "misty", tier = "master" }, adaptiveGame)
T.eq(relaxedCycleTeam[1].level, 100,
  "level-100 cycle teams do not depend on optional challenge rules")
run.loader.modOptions.trainer_rematch = nil

local cycleRuleGame = {
  save = {
    options = { battleStyle = "shift" },
    party = {
      { species = "MEW", hp = 10, status = "PAR" },
      { species = "FIXMON_A", hp = 11 },
      { species = "FIXMON_A", hp = 12 },
      { species = "FIXMON_A", hp = 13 },
    },
  },
}
asc.state().cycle = 2
local setBattle = { game = cycleRuleGame }
asc.applyBossRules(setBattle)
T.eq(cycleRuleGame.save.options.battleStyle, "set",
  "Cycle 2 temporarily forces SET battle style")
RealRuntime.emit("battle.ended", { battle = setBattle, result = "win" })
T.eq(cycleRuleGame.save.options.battleStyle, "shift",
  "the player's battle-style option is restored after the boss fight")
asc.state().cycle = 3
local trioBattle = { game = cycleRuleGame }
asc.applyBossRules(trioBattle)
T.eq(cycleRuleGame.save.party[4].hp, 0,
  "Cycle 3 seals party slots beyond the leading trio")
RealRuntime.emit("battle.ended", { battle = trioBattle, result = "win" })
T.eq(cycleRuleGame.save.party[4].hp, 13,
  "sealed trio slots are restored after the fight")
asc.state().cycle = 4
local puristBattle = { game = cycleRuleGame }
asc.applyBossRules(puristBattle)
T.eq(cycleRuleGame.save.party[1].hp, 0,
  "Cycle 4 seals legendary party members")
RealRuntime.emit("battle.ended", { battle = puristBattle, result = "win" })
T.eq(cycleRuleGame.save.party[1].hp, 10,
  "sealed legendary HP and status are restored after the fight")
T.eq(cycleRuleGame.save.party[1].status, "PAR",
  "the Purist rule also restores the original status condition")
asc.state().cycle = 1

-- ------------------------------------------------ complete shiny progression

local priorModSave = run.loader.modSave
run.loader.modSave = {}
local shinyOwned, shinyPokemon = {}, {}
for dex = 1, 251 do
  local id = ("DEX_%03d"):format(dex)
  shinyOwned[id] = true
  shinyPokemon[id] = { dex = dex, name = id }
end
local shinyProgressGame = {
  data = { pokemon = shinyPokemon, constants = Data.constants },
  save = {
    inventory = {}, bagOrder = {}, party = {}, boxes = {},
    flags = { EVENT_BEAT_CHAMPION_RIVAL = true },
    pokedex = { seen = shinyOwned, owned = shinyOwned },
  },
}
T.eq(shinySystem.unlockCharm(shinyProgressGame), true,
  "recording all 251 species awards the permanent Shiny Charm")
T.eq(shinySystem.hasCharm(), true,
  "the Shiny Charm ability persists in mod save data")
T.eq(shinyProgressGame.save.inventory.SHINY_CHARM, 1,
  "the Shiny Charm also appears as a non-tossable key item")
for n = 1, 10 do
  shinySystem.afterRematch(shinyProgressGame, {
    rematchTrainerClass = "OPP_YOUNGSTER",
  })
end
local shinyProgress = shinySystem.state()
T.eq(shinyProgress.rematchStreak, 10,
  "consecutive field-rematch wins build the shiny hunting streak")
T.eq(shinyProgress.outbreak, nil,
  "a ten-win streak cannot start a swarm before Elm's starter trials")
local gatedResearch = ex.johtoResearch.state()
for _, key in ipairs(johto.starterOrder) do
  gatedResearch.starters[key] = true
end
shinyProgress.rematchStreak = 0
for n = 1, 10 do
  shinySystem.afterRematch(shinyProgressGame, {
    rematchTrainerClass = "OPP_YOUNGSTER",
  })
end
T.neq(shinyProgress.outbreak, nil,
  "Hall of Fame plus all three starter trials unlock shiny swarms")
T.eq(shinyProgress.outbreak.steps, 2048,
  "a new outbreak receives its full step duration")
T.eq(shinySystem.extraRolls(), 3,
  "Charm plus a ten-win streak grants three additional DV rolls")
for n = 11, 25 do
  shinySystem.afterRematch(shinyProgressGame, {
    rematchTrainerClass = "OPP_YOUNGSTER",
  })
end
T.eq(shinySystem.state().redGyaradosUnlocked, true,
  "a 25-win post-Hall-of-Fame streak unlocks the red Gyarados event")
T.eq(shinySystem.eventMap, "SEAFOAM_ISLANDS_B4F",
  "the guaranteed shiny event lives in Seafoam's deepest floor")
do
  local eventEncounter = RealRuntime.call("encounter.roll",
    function() return { species = "ZUBAT", level = 32 } end,
    Data.encounters.SEAFOAM_ISLANDS_B4F,
    {
      mapId = "SEAFOAM_ISLANDS_B4F",
      terrain = "indoor",
      rng = function(_, hi) return hi end,
    })
  T.eq(eventEncounter.species, "GYARADOS",
    "the unlocked Seafoam event replaces a normal encounter with Gyarados")
  T.eq(eventEncounter.level, 50,
    "the guaranteed red Gyarados event uses level 50")
  local eventMon = {
    species = "GYARADOS", level = 50, hp = 100, stats = { hp = 100 },
    dvs = { attack = 8, defense = 8, speed = 8, special = 8, hp = 8 },
  }
  local externalSawShiny
  local removeEventVisual = RealRuntime.hooks:wrap("pokemon.sprite",
    function(_, _, ctx)
      externalSawShiny = shinySystem.isShiny(ctx.mon)
      return externalSawShiny
        and "external/gyarados_shiny.png"
        or "external/gyarados_normal.png"
    end, 930, "red-gyarados-visual-compat-test")
  local eventPath = RealRuntime.call("pokemon.sprite",
    function(path) return path end, "base/gyarados.png", {
      data = Data,
      mon = eventMon,
      species = "GYARADOS",
      side = "front",
      kind = "battle",
    })
  removeEventVisual()
  T.eq(externalSawShiny, true,
    "priority-930 Crystal/Voxel wrappers see shiny DVs before choosing art")
  T.eq(eventPath, "external/gyarados_shiny.png",
    "a non-delegating graphics wrapper selects shiny Gyarados art")
  T.eq(eventMon.ascendantShinyEvent, true,
    "the prepared event Gyarados keeps its one-time capture marker")
end
do
  local savedCaught = shinyProgress.redGyaradosCaught
  local savedOutbreak = shinyProgress.outbreak
  shinyProgress.redGyaradosCaught = true
  shinyProgress.outbreak = nil
  local bonusEncounter = RealRuntime.call("encounter.roll",
    function() return { species = "ZUBAT", level = 21 } end,
    Data.encounters.ROUTE_1,
    {
      mapId = "ROUTE_1",
      terrain = "grass",
      rng = function() return 1 end,
    })
  local bonusMon = {
    species = bonusEncounter.species,
    level = bonusEncounter.level,
    hp = 50,
    stats = { hp = 50 },
    dvs = { attack = 8, defense = 8, speed = 8, special = 8, hp = 8 },
  }
  local externalSawShiny
  local removeBonusVisual = RealRuntime.hooks:wrap("pokemon.sprite",
    function(_, _, ctx)
      externalSawShiny = shinySystem.isShiny(ctx.mon)
      return externalSawShiny
        and "external/bonus_shiny.png"
        or "external/bonus_normal.png"
    end, 930, "bonus-shiny-visual-compat-test")
  local bonusPath = RealRuntime.call("pokemon.sprite",
    function(path) return path end, "base/zubat.png", {
      data = Data,
      mon = bonusMon,
      species = bonusEncounter.species,
      side = "front",
      kind = "battle",
    })
  removeBonusVisual()
  T.eq(externalSawShiny, true,
    "priority-930 wrappers see Charm/streak bonus shinies before art selection")
  T.eq(bonusPath, "external/bonus_shiny.png",
    "a non-delegating graphics wrapper selects bonus-shiny artwork")
  T.eq(bonusMon.ascendantShinyEvent, nil,
    "ordinary bonus shinies do not receive the Red Gyarados event marker")
  shinyProgress.redGyaradosCaught = savedCaught
  shinyProgress.outbreak = savedOutbreak
end
run.loader.modSave = priorModSave

-- ------------------------------------------------ discovery Dex + Johto Masters

local dexProgress = ex.dexProgress
local johtoMasters = ex.johtoMasters
local worldEvents = ex.worldEvents
local fieldTech = ex.fieldTech
local kantoCompletion = ex.kantoCompletion
T.neq(dexProgress, nil,
  "the original-style discovery and certificate controller is exported")
T.neq(johtoMasters, nil,
  "the repeatable Silver/Kris/Gold trial is exported")
T.neq(worldEvents, nil,
  "the step-driven Kanto world-event controller is exported")
T.neq(fieldTech, nil,
  "the HM Field Kit, TM archive and Move Deleter controller is exported")
T.neq(kantoCompletion, nil,
  "the self-contained Kanto 151 controller is exported")
T.eq(#kantoCompletion.criticalAcquisitions, 13,
  "the Kanto completion audit documents every former version or choice lock")
T.eq(kantoCompletion.loadedMode(), "ascendant",
  "KANTO 151 reports the content mode that was actually patched at startup")
local priorKantoOptions = run.loader.modOptions.trainer_rematch
run.loader.modOptions.trainer_rematch = { kanto_151 = "wild" }
T.eq(kantoCompletion.configuredMode(), "wild",
  "KANTO 151 separately observes a newly selected option")
T.eq(kantoCompletion.restartRequired(), true,
  "changing the KANTO 151 patch mode is reported as requiring a restart")
T.eq(kantoCompletion.statusText():find(
  "LOADED: REWARDS", 1, true) ~= nil, true,
  "KANTO 151 status keeps showing the loaded mode until restart")
T.eq(kantoCompletion.statusText():find(
  "RESTART REQUIRED", 1, true) ~= nil, true,
  "KANTO 151 status gives an explicit restart warning")
run.loader.modOptions.trainer_rematch = priorKantoOptions

if kantoCompletion.enabled then
  local function encounterHas(mapId, species)
    local enc = Data.encounters[mapId]
    for _, slot in ipairs(enc and enc.grass and enc.grass.slots or {}) do
      if slot.species == species then return true end
    end
    return false
  end

  T.eq(encounterHas("ROUTE_5", "MEOWTH"), true,
    "Meowth is available without changing game editions")
  T.eq(encounterHas("ROUTE_5", "BELLSPROUT"), true,
    "Bellsprout shares a natural habitat with Oddish")
  T.eq(encounterHas("ROUTE_8", "EKANS")
      and encounterHas("ROUTE_8", "SANDSHREW"), true,
    "Route 8 contains both former version-exclusive Ground/Poison families")
  T.eq(encounterHas("SAFARI_ZONE_CENTER", "SCYTHER")
      and encounterHas("SAFARI_ZONE_CENTER", "PINSIR"), true,
    "both Safari bug prizes can be caught in one save")
  T.eq(encounterHas("POWER_PLANT", "ELECTABUZZ")
      and encounterHas("POKEMON_MANSION_B1F", "MAGMAR"), true,
    "Electabuzz and Magmar are both obtainable")
  T.eq(encounterHas("POKEMON_MANSION_B1F", "MEW"), false,
    "the Kanto 151 layer never bypasses the authored Mew event")
  T.eq(encounterHas("SEAFOAM_ISLANDS_B2F", "SQUIRTLE"), false,
    "reward mode keeps Squirtle as Misty's Master prize")
  T.eq(Data.pokemon.KADABRA.evolutions[1].species, "ALAKAZAM",
    "Kadabra evolves without a trade")
  T.eq(Data.pokemon.MACHOKE.evolutions[1].level, 45,
    "Machoke's replacement level evolution is registered")

  local function hasEvolution(species, target, method, item)
    for _, row in ipairs(Data.pokemon[species].evolutions or {}) do
      if row.species == target
          and (not method or row.method == method)
          and (not item or row.item == item) then return true end
    end
    return false
  end
  T.eq(hasEvolution("GLOOM", "VILEPLUME", "ITEM", "LEAF_STONE")
      and hasEvolution("GLOOM", "BELLOSSOM", "ITEM", "SUN_STONE"), true,
    "Gloom keeps Vileplume while gaining Bellossom")
  T.eq(hasEvolution("POLIWHIRL", "POLIWRATH", "ITEM", "WATER_STONE")
      and hasEvolution("POLIWHIRL", "POLITOED", "ITEM", "KINGS_ROCK"), true,
    "Poliwhirl keeps Poliwrath while gaining Politoed")
  T.eq(hasEvolution("EEVEE", "VAPOREON", "ITEM", "WATER_STONE")
      and hasEvolution("EEVEE", "JOLTEON", "ITEM", "THUNDER_STONE")
      and hasEvolution("EEVEE", "FLAREON", "ITEM", "FIRE_STONE")
      and hasEvolution("EEVEE", "ESPEON", "FRIENDSHIP_DAY")
      and hasEvolution("EEVEE", "UMBREON", "FRIENDSHIP_NIGHT"), true,
    "Eevee exposes all five Kanto and Johto branches together")
  T.eq(hasEvolution("SLOWPOKE", "SLOWBRO", "LEVEL")
      and hasEvolution("SLOWPOKE", "SLOWKING", "ITEM", "KINGS_ROCK"), true,
    "Slowpoke keeps Slowbro while gaining Slowking")

  local priorHallOfFame = game.save.hallOfFame
  local priorChampionFlag = game.save.flags.EVENT_BEAT_CHAMPION_RIVAL
  local function eeveeRng(lo, hi)
    if lo == 1 and hi == 100 then return 1 end
    return hi
  end
  game.save.hallOfFame = {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = nil
  local beforeLeague = RealRuntime.call("encounter.roll",
    function() return { species = "PIDGEY", level = 22 } end,
    Data.encounters.ROUTE_7,
    { mapId = "ROUTE_7", terrain = "grass", rng = eeveeRng })
  T.eq(beforeLeague.species, "PIDGEY",
    "Route 7 does not reveal renewable Eevee before the League")
  game.save.hallOfFame = { {} }
  local afterLeague = RealRuntime.call("encounter.roll",
    function() return { species = "PIDGEY", level = 22 } end,
    Data.encounters.ROUTE_7,
    { mapId = "ROUTE_7", terrain = "grass", rng = eeveeRng })
  T.eq(afterLeague.species, "EEVEE",
    "Route 7 can replace two percent of post-League grass encounters with Eevee")
  T.eq(afterLeague.level, 25,
    "renewable post-League Eevee use their intended level")
  game.save.hallOfFame = priorHallOfFame
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = priorChampionFlag

  local pewterMart =
    Data.text_pointers.PewterMart.TEXT_PEWTERMART_CLERK.mart
  T.eq(pewterMart[1], "POKE_BALL",
    "adding Moon Stone preserves Pewter Mart's normal inventory")
  T.eq(pewterMart[#pewterMart], "MOON_STONE",
    "Moon Stone is renewable at Pewter Mart")

  local priorKantoSave = run.loader.modSave
  run.loader.modSave = {}
  local kantoGiftGame = {
    data = Data,
    save = {
      player = { name = "RED", id = 151 },
      party = {}, inventory = {}, flags = { EVENT_GOT_HELIX_FOSSIL = true },
      pokedex = { seen = {}, owned = {} },
    },
  }
  local starterText =
    kantoCompletion.afterBossWin(kantoGiftGame, "erika", "master")
  T.eq(kantoGiftGame.save.party[1].species, "BULBASAUR",
    "Master Erika awards the Grass starter in reward mode")
  T.eq(starterText ~= nil, true,
    "the starter prize has a visible bilingual reward message")
  local fossilText =
    kantoCompletion.afterBossWin(kantoGiftGame, "brock", "master")
  T.eq(kantoGiftGame.save.inventory.DOME_FOSSIL, 1,
    "Master Brock awards the fossil excluded by the Mt. Moon choice")
  T.eq(fossilText ~= nil, true,
    "the missing fossil receives its own reward message")
  run.loader.modSave = priorKantoSave
end
T.eq(Data.moves.FRENZY_PLANT.power, 150,
  "Frenzy Plant is registered as a full starter signature move")
T.eq(Data.moves.BLAST_BURN.effect, "HYPER_BEAM_EFFECT",
  "Blast Burn uses the authentic recharge effect")
T.eq(Data.moves.HYDRO_CANNON.accuracy, 90,
  "Hydro Cannon carries its intended accuracy")
T.eq(Data.items.TM_FRENZY_PLANT.machine.number, 51,
  "TM51 contains Frenzy Plant")
T.eq(Data.items.TM_BLAST_BURN.machine.number, 52,
  "TM52 contains Blast Burn")
T.eq(Data.items.TM_HYDRO_CANNON.machine.number, 53,
  "TM53 contains Hydro Cannon")
T.eq(#fieldTech.starterFamilies.FRENZY_PLANT, 6,
  "the Grass TM covers both complete Kanto and Johto starter families")
T.eq(#fieldTech.starterFamilies.BLAST_BURN, 6,
  "the Fire TM covers both complete Kanto and Johto starter families")
T.eq(#fieldTech.starterFamilies.HYDRO_CANNON, 6,
  "the Water TM covers both complete Kanto and Johto starter families")

local previousFieldSave = run.loader.modSave
run.loader.modSave = {}
local fieldState = fieldTech.state()
fieldState.kit = true
local fieldSave = {
  inventory = {
    FIELD_KIT = 1, HM_CUT = 1, CASCADEBADGE = 1,
    HM_SURF = 1, SOULBADGE = 1,
  },
  party = { { species = "FIXMON_A", moves = { { id = "FIX_TACKLE" } } } },
}
T.eq(fieldTech.available(fieldSave, "CUT"), true,
  "the Field Kit activates an owned HM only after its matching badge")
fieldSave.inventory.CASCADEBADGE = nil
T.eq(fieldTech.available(fieldSave, "CUT"), false,
  "the Field Kit never bypasses badge progression")
T.eq(fieldTech.available(fieldSave, "FLY"), false,
  "an HM that has not been found remains unavailable")
local deletable = {
  moves = { { id = "CUT" }, { id = "FIX_TACKLE" } },
}
T.eq(fieldTech.forgetMove(deletable, 1), true,
  "the Move Deleter can remove an HM once field tools no longer need it")
T.eq(deletable.moves[1].id, "FIX_TACKLE",
  "deleting the selected HM keeps the other move intact")
T.eq(fieldTech.forgetMove(deletable, 1), false,
  "the Move Deleter protects a Pokémon's final usable move")
run.loader.modSave = previousFieldSave

T.eq(#ex.johtoMastersData.trainers, 3,
  "Silver, Kris and Gold form the complete Johto Masters trial")

for _, trainer in ipairs(ex.johtoMastersData.trainers) do
  T.eq(#trainer.pool, 12,
    trainer.key .. " owns twelve level-100 roster candidates")
  local first = johtoMasters.teamFor(trainer.key, 1)
  local second = johtoMasters.teamFor(trainer.key, 2)
  T.eq(#first, 6, trainer.key .. " selects a full six-Pokémon team")
  T.eq(first[1].level, 100, trainer.key .. " always fights at level 100")
  T.eq(first[1].species ~= second[1].species, true,
    trainer.key .. " changes the team lead on the next challenge")
end

local expandedPokemon, expandedOwned = {}, {}
for dex = 1, 251 do
  local id = ("DISCOVERY_%03d"):format(dex)
  expandedPokemon[id] = {
    id = id, dex = dex, name = id, baseStats = Data.pokemon.FIXMON_A.baseStats,
  }
  if dex <= 150 then expandedOwned[id] = true end
end
local discoveryGame = {
  data = { pokemon = expandedPokemon },
  save = {
    player = { name = "RED" }, party = {}, boxes = {}, inventory = {},
    hallOfFame = { {} },
    pokedex = { seen = expandedOwned, owned = expandedOwned },
  },
}
T.eq(dexProgress.ownedThrough(discoveryGame, 150), 150,
  "the Kanto certificate counts the exact first 150 species")
T.eq(dexProgress.complete(discoveryGame, 150), true,
  "owning Kanto #001-150 unlocks the original completion tier")
T.eq(dexProgress.complete(discoveryGame, 151), false,
  "Mew remains a real undiscovered slot for the 151 certificate")
expandedOwned.DISCOVERY_151 = true
T.eq(dexProgress.complete(discoveryGame, 151), true,
  "capturing Mew unlocks the separate 151 certificate")
T.eq(#johtoMasters.fullRoster(discoveryGame), 251,
  "Gold's reward roster contains every one of all 251 species")
T.eq(johtoMasters.randomSpecies(discoveryGame, function() return 251 end),
  "DISCOVERY_251",
  "Gold can uniformly select Celebi as the 251st shiny reward")

run.__priorNationalDexSave = run.loader.modSave
run.loader.modSave = {}
;(function()
local pokemon, seen, owned = {}, {}, {}
for dex = 1, 251 do
  local id = ("NATIONAL_%03d"):format(dex)
  pokemon[id] = { id = id, dex = dex, name = id }
end
seen.NATIONAL_161 = true
local nationalGame = {
  data = {
    pokemon = pokemon,
    constants = { dexSize = 251, dexDigits = 3 },
  },
  save = {
    player = { name = "RED" },
    party = {},
    boxes = {},
    inventory = {},
    pokedex = { seen = seen, owned = owned },
  },
}
local signals = ex.johtoSignals.state()
signals.receiverRepaired = true
signals.startPolicy = "waves"
dexProgress.install(nationalGame)
T.eq(dexProgress.hasNationalDex(nationalGame), false,
  "remote onboarding never grants the National Dex before Driftglass")
local PokedexMenu = require("src.ui.PokedexMenu")
local lockedDex = PokedexMenu.new(nationalGame)
T.eq(#lockedDex.items, 151,
  "the ordinary Pokédex remains Kanto-only before Driftglass")
T.eq(nationalGame.data.constants.dexSize, 251,
  "the menu gate restores the registered 251-species data immediately")
signals.startPolicy = "quest"
local unlocked, reason = dexProgress.reconcileNationalDex(nationalGame)
T.eq(unlocked, true,
  "an existing physical Driftglass repair receives the upgrade retroactively")
T.eq(reason, "unlocked",
  "the National Dex migration reports its explicit result")
local nationalDex = PokedexMenu.new(nationalGame)
T.eq(#nationalDex.items, 251,
  "the upgraded National Dex exposes all 251 registered slots")
T.eq(nationalDex.items[161].value, "NATIONAL_161",
  "a seen Johto species reveals its retained name after the upgrade")
T.eq(nationalDex.items[161].ball, nil,
  "a seen-only Johto species remains visibly uncaught")
for number = 1, 102 do
  seen[("NATIONAL_%03d"):format(number)] = true
end
local threeDigitDex = PokedexMenu.new(nationalGame)
T.eq(threeDigitDex.footer, "SEEN 103 OWN 0",
  "three-digit National Dex totals stay on one footer line")
T.eq(threeDigitDex.footer:find("\n", 1, true), nil,
  "the compact National Dex footer cannot overlap the seventh row")
owned.NATIONAL_161 = true
local caughtDex = PokedexMenu.new(nationalGame)
T.eq(caughtDex.items[161].ball, true,
  "catching the Johto species adds the ordinary owned marker")

run.loader.modSave = {
  trainer_rematch = {
    dex_progress = { version = 1, certificates = {} },
  },
}
local legacySignals = ex.johtoSignals.state()
legacySignals.receiverRepaired = true
legacySignals.modeChosen = true
legacySignals.mode = "WANDERWAVES"
legacySignals.startPolicy = "waves"
local legacyGame = {
  data = nationalGame.data,
  save = {
    player = { name = "RED" },
    party = {},
    boxes = {},
    inventory = {},
    pokedex = { seen = {}, owned = {} },
  },
}
dexProgress.install(legacyGame)
T.eq(dexProgress.hasNationalDex(legacyGame), true,
  "an already-active public 6.0 Signals save receives the National Dex")
T.eq(dexProgress.state().nationalDexLegacyMigration, false,
  "the automatic active-save upgrade is consumed exactly once")

run.loader.modSave = {
  trainer_rematch = {
    dex_progress = { version = 1, certificates = {} },
  },
}
local startedSignals = ex.johtoSignals.state()
startedSignals.questStarted = true
startedSignals.capsuleOpened = true
startedSignals.receiverRepaired = false
local startedGame = {
  data = nationalGame.data,
  save = {
    player = { name = "RED" },
    party = {},
    boxes = {},
    inventory = {},
    pokedex = { seen = {}, owned = {} },
  },
}
dexProgress.install(startedGame)
T.eq(dexProgress.hasNationalDex(startedGame), false,
  "an old quest that only started still earns the National Dex on Driftglass")
startedSignals.receiverRepaired = true
startedSignals.modeChosen = true
startedSignals.mode = "WANDERWAVES"
startedSignals.startPolicy = "waves"
dexProgress.install(startedGame)
T.eq(dexProgress.hasNationalDex(startedGame), false,
  "activating after the upgrade cannot reuse the legacy auto-grant")
end)()
run.loader.modSave = run.__priorNationalDexSave
run.__priorNationalDexSave = nil

local isolatedModSave = run.loader.modSave
run.loader.modSave = {}
;(function()
local secretPokemon, secretOwned = {}, {}
for dex = 1, 251 do
  local id = dex == 157 and "TYPHLOSION"
    or ("SECRET_DEX_%03d"):format(dex)
  secretPokemon[id] = { id = id, dex = dex, name = id }
  secretOwned[id] = true
end
local secretGame = {
  data = { pokemon = secretPokemon },
  save = {
    player = { name = "RED" },
    party = { { species = "TYPHLOSION", level = 100 } },
    pokedex = { seen = secretOwned, owned = secretOwned },
  },
}
local secretForm = ex.ascendantTyphlosion
T.neq(secretForm, nil,
  "the Ascendant Typhlosion discovery event is exported")
T.eq(secretForm.ownedCount(secretGame), 251,
  "the Basalt Seal counts an exact complete National Pokédex")
johtoMasters.state().clears = 0
T.eq(secretForm.ready(secretGame), false,
  "the secret form remains sealed before Gold's final main battle")
johtoMasters.state().clears = 1
secretGame.save.party[1].level = 99
T.eq(secretForm.ready(secretGame), false,
  "the Basalt Seal requires Typhlosion to reach level 100")
secretGame.save.party[1].level = 100
T.eq(secretForm.ready(secretGame), true,
  "Gold, all 251 species and level-100 Typhlosion complete the ritual")
T.eq(secretForm.unlock(secretGame), true,
  "the first complete Basalt ritual unlocks the form")
T.eq(secretForm.unlock(secretGame), false,
  "the permanent Basalt Core cannot be awarded twice")
T.eq(mega.secretUnlocked(), true,
  "the battle-form controller receives the permanent secret entitlement")
T.eq(mega.profileFor(secretGame.save.party[1], false).id,
  "TYPHLOSION_ASCENDANT",
  "an entitled player Typhlosion resolves to the secret form")
T.eq(mega.profileFor(secretGame.save.party[1], true), nil,
  "ordinary enemy Typhlosion never uses the player's secret fan form")
T.eq(secretForm.statusText(secretGame):find(
    "BASALT CORE: AWAKE", 1, true) ~= nil, true,
  "the unlocked Ascendant page explains the permanent relic")
end)()

worldEvents.install(discoveryGame)
local worldState = worldEvents.state()
worldState.nextAt, worldState.active = 10, nil
worldEvents.onStep(discoveryGame, 10)
T.eq(worldEvents.active("training_rush"), true,
  "the first scheduled step event starts a real Training Rush")
T.eq(worldEvents.trainingStepBonus(), 1,
  "Training Rush adds one trainer-only recovery tick per walked step")
local worldBucket = run.loader.modSave.trainer_rematch
worldBucket.step_clock, worldBucket.trainer_step_clock = 50, 50
worldEvents.state().active = { id = "training_rush", steps = 100 }
run.loader.events:emit("world.stepped", {})
T.eq(ex.playerStepClock(), 51,
  "Training Rush records exactly one real player step")
T.eq(ex.trainerStepClock(), 52,
  "Training Rush advances only the trainer recovery clock twice")
T.eq(worldEvents.state().active.steps, 99,
  "Training Rush itself and other world events lose one real step, not two")
local migrationResearch = ex.johtoResearch.state()
migrationResearch.finalReward = nil
local migrationState = worldEvents.state()
migrationState.index, migrationState.active, migrationState.nextAt = 21, nil, 60
worldEvents.onStep(discoveryGame, 60)
T.eq(worldEvents.active("johto_migration"), true,
  "the Larvitar cycle still starts a Johto migration before the finale")
T.eq(migrationState.active.species ~= "LARVITAR", true,
  "Larvitar is excluded from migrations until Elm's research finale")
migrationResearch.finalReward = true
migrationState.index, migrationState.active, migrationState.nextAt = 21, nil, 61
worldEvents.onStep(discoveryGame, 61)
T.eq(migrationState.active.species, "LARVITAR",
  "Larvitar joins Route 22 migrations only after the research finale")
worldState.active = { id = "golden_wind", steps = 100 }
T.eq(worldEvents.shinyBonusRolls(), 2,
  "Golden Wind grants two additional shiny checks")
worldState.active = { id = "frontier_festival", steps = 100 }
T.eq(worldEvents.frontierMultiplier(), 2,
  "Frontier Festival doubles Ascendant Frontier points")
run.loader.modSave = isolatedModSave

-- ------------------------------------------------ Johto starter relic quests

;(function()
local previousSave = run.loader.modSave
run.loader.modSave = {}
local relics = ex.starterRelicQuests
T.neq(relics, nil,
  "the acquisition-independent starter relic controller is exported")
local relicGame = {
  data = Data,
  save = {
    party = { { species = "CHIKORITA", level = 18 } },
    boxes = { { { species = "CYNDAQUIL", level = 12 } } },
    pokedex = {
      seen = { CHIKORITA = true, CYNDAQUIL = true },
      owned = { CHIKORITA = true, CYNDAQUIL = true },
    },
    inventory = {}, player = { name = "RED" },
  },
  stack = { push = function(_, box) pushed[#pushed + 1] = box end },
}
relics.install(relicGame)
T.eq(relics.questState("chikorita").assigned, true,
  "owning Chikorita assigns its relic quest on an upgraded save")
T.eq(relics.questState("chikorita").introSeen, false,
  "a newly assigned starter relic remains visibly unread")
T.eq(relics.questState("cyndaquil").assigned, true,
  "a boxed Cyndaquil family member assigns the Basalt quest")
T.eq(relics.nextObjective(relicGame, "chikorita"):find(
    "VIRIDIAN FOREST", 1, true) ~= nil, true,
  "Chikorita's guide names the next required location")
T.eq(relics.nextObjective(relicGame, "cyndaquil"):find(
    "DEFEAT GOLD", 1, true) ~= nil, true,
  "Cyndaquil's guide points to Gold before revealing the Basalt Seal")
T.eq(relics.questState("totodile", false), nil,
  "an unknown starter family does not pre-fill its quest")

local chikoritaQuest = relics.questState("chikorita")
run.loader.events:emit("world.stepped", {})
T.eq(chikoritaQuest.steps, 1,
  "walking with the Chikorita family advances its private quest")
T.eq(chikoritaQuest.trialSteps, 0,
  "ordinary walking does not bypass the Viridian Forest chapter")
chikoritaQuest.steps = relics.quests.chikorita.steps - 1
chikoritaQuest.wins = relics.quests.chikorita.wins - 1
chikoritaQuest.trialSteps = relics.quests.chikorita.trialSteps - 1
run.loader.events:emit("world.stepped", { mapId = "VIRIDIAN_FOREST" })
T.eq(chikoritaQuest.trialSteps, relics.quests.chikorita.trialSteps,
  "walking in Viridian Forest completes Chikorita's forest chapter")
run.loader.events:emit("battle.ended", {
  result = "win",
  battle = { game = relicGame, kind = "trainer", trainer = { name = "IRIS" } },
})
T.eq(relics.ready("chikorita"), true,
  "the Verdant Relic becomes ready after its steps and trainer wins")
T.eq(relics.nextObjective(relicGame, "chikorita"):find(
    "RELIC KEEPER", 1, true) ~= nil, true,
  "a completed Verdant trial directs the player back to its keeper")

local oldTextBox = package.loaded["src.render.TextBox"]
package.loaded["src.render.TextBox"] = textBoxStub
pushed = {}
local relicNpc = {
  def = { name = relics.quests.chikorita.npc },
  frozen = false, facePlayer = function() end,
}
T.eq(relics.handleTalk({ player = {} }, relicNpc, relicGame), true,
  "the Celadon relic keeper handles the completed quest")
T.eq(mega.hasStone("MEGANIUMITE"), true,
  "the one-time Verdant Relic awards Meganiumite")
T.eq(relics.questState("chikorita").claimed, true,
  "the Meganiumite reward is permanently recorded")
T.eq(mega.grantStone("MEGANIUMITE"), false,
  "Meganiumite cannot be awarded a second time")
package.loaded["src.render.TextBox"] = oldTextBox

run.loader.events:emit("pokemon.caught", {
  game = relicGame, species = "TOTODILE",
  mon = { species = "TOTODILE", level = 10 },
})
T.eq(relics.questState("totodile").assigned, true,
  "a wild Totodile immediately assigns the Torrent Relic quest")
relicGame.save.party = { { species = "CROCONAW", level = 25 } }
local totodileQuest = relics.questState("totodile")
run.loader.events:emit("world.stepped", {})
T.eq(totodileQuest.steps, 1,
  "an evolved Croconaw advances the same family quest")
T.eq(totodileQuest.trialSteps, 0,
  "Totodile's tide chapter cannot advance outside Seafoam")
run.loader.events:emit("world.stepped", { mapId = "SEAFOAM_ISLANDS_B2F" })
T.eq(totodileQuest.trialSteps, 1,
  "Seafoam walking advances Totodile's dedicated tide chapter")
T.eq(relics.statusText(relicGame, "totodile"):find(
    "SEAFOAM ISLANDS", 1, true) ~= nil, true,
  "the Torrent Relic page names its required story location")

run.loader.modSave = previousSave
relics.install(game)
end)()

-- ------------------------------------------------ Kanto Ascendant 5.0 Grand Tour

;(function()
local grandTour = ex.grandTour
local grandTourData = ex.grandTourData
T.neq(grandTour, nil,
  "the Crown Champion's Grand Tour controller is exported")
T.neq(grandTourData, nil,
  "the inspectable Factory and S.S. Anne rosters are exported")
T.eq(grandTourData.cruise.cooldown, 4096,
  "S.S. Anne voyages use the promised 4096 real-step cooldown")

local factoryPokemon = {}
for dex, row in ipairs(grandTourData.factory.candidates) do
  local def = {}
  for key, value in pairs(Data.pokemon.FIXMON_A) do def[key] = value end
  def.id, def.name, def.dex = row.species, row.species, dex
  def.evolutions = {}
  factoryPokemon[row.species] = def
end
local factoryGame = {
  data = { pokemon = factoryPokemon, moves = Data.moves },
  save = {
    player = { name = "RED", id = 500 },
    party = {}, inventory = {}, pokedex = { seen = {}, owned = {} },
  },
}
local firstDraft = grandTour.draftCandidates(factoryGame, 1)
local secondDraft = grandTour.draftCandidates(factoryGame, 2)
T.eq(#firstDraft, 6,
  "the Battle Factory always presents six legal rentals")
T.eq(firstDraft[1].species ~= secondDraft[1].species, true,
  "a later Factory attempt rotates to a different draft")
local draftedSpecies = {}
for _, row in ipairs(firstDraft) do
  T.eq(draftedSpecies[row.species], nil,
    "the six Factory candidates never repeat a species")
  draftedSpecies[row.species] = true
  T.eq(row.level, 100, row.species .. " is offered at level 100")
  T.eq(grandTour.isFinalEvolution(factoryGame, row.species), true,
    row.species .. " is a fully evolved non-legendary rental")
end

local rentals = grandTour.buildRentalTeam(factoryGame,
  { firstDraft[1], firstDraft[2], firstDraft[3] })
T.eq(#rentals, 3,
  "the chosen three draft entries become a three-Pokemon rental party")
for _, mon in ipairs(rentals) do
  T.eq(mon.level, 100, "every built Factory rental remains level 100")
  T.eq(mon.factoryRental, true,
    "temporary Factory Pokemon carry an explicit rental marker")
end

local factoryFoes = grandTour.factoryBracket(1)
T.eq(#factoryFoes, 3,
  "a Factory run selects three changing opponents")
local factoryKeys = {}
for _, foe in ipairs(factoryFoes) do
  T.eq(factoryKeys[foe.key], nil,
    "one Factory bracket never repeats an opponent")
  factoryKeys[foe.key] = true
  T.eq(#foe.team, 3,
    foe.key .. " fields a fair three-Pokemon Factory team")
  for _, slot in ipairs(foe.team) do
    T.eq(slot.level, 100, foe.key .. " always battles at level 100")
  end
end

local cruiseFoes = grandTour.cruiseBracket(1)
local nextCruiseFoes = grandTour.cruiseBracket(2)
T.eq(#cruiseFoes, 5,
  "each S.S. Anne Grand Tour contains five authored battles")
T.eq(cruiseFoes[1].key ~= nextCruiseFoes[1].key, true,
  "the S.S. Anne bracket rotates on the next voyage")
local cruiseKeys = {}
for _, foe in ipairs(cruiseFoes) do
  T.eq(cruiseKeys[foe.key], nil,
    "one voyage never repeats a shipboard opponent")
  cruiseKeys[foe.key] = true
  T.eq(#foe.team, 6, foe.key .. " brings a complete cruise team")
  for _, slot in ipairs(foe.team) do
    T.eq(slot.level, 100, foe.key .. " always battles at level 100")
  end
end

local interruptedOriginal = {
  { species = "FIXMON_A", level = 42, hp = 17 },
  { species = "FIXMON_B", level = 43, hp = 18 },
}
local interruptedSave = {
  party = { { species = "VENUSAUR", level = 100, factoryRental = true } },
  modData = {
    trainer_rematch = {
      grand_tour = {
        factory = {
          attempts = 1, activeRound = 2,
          activeDraft = { "VENUSAUR", "STARMIE", "TAUROS" },
          backupParty = interruptedOriginal,
        },
      },
    },
  },
}
T.eq(grandTour.recoverRawParty(interruptedSave), true,
  "loading an interrupted Factory run detects the party backup")
T.eq(interruptedSave.party, interruptedOriginal,
  "interrupted Factory saves restore the exact original team")
local recoveredFactory =
  interruptedSave.modData.trainer_rematch.grand_tour.factory
T.eq(recoveredFactory.backupParty, nil,
  "successful recovery consumes the stale Factory backup")
T.eq(recoveredFactory.activeRound, 0,
  "successful recovery closes the interrupted Factory round")

local oldGrandTour = grandTour.normalizeState({
  factory = { attempts = -3, wins = 2, bestRound = 99 },
  cruise = { clears = 4, bestRound = 99, nextAt = -1 },
})
T.eq(oldGrandTour.factory.attempts, 0,
  "Grand Tour migration repairs invalid old Factory counters")
T.eq(oldGrandTour.factory.wins, 2,
  "Grand Tour migration preserves legitimate Factory wins")
T.eq(oldGrandTour.factory.bestRound, 3,
  "Factory best-round migration clamps to the three-round maximum")
T.eq(oldGrandTour.cruise.clears, 4,
  "Grand Tour migration preserves legitimate voyage clears")
T.eq(oldGrandTour.cruise.bestRound, 5,
  "voyage best-round migration clamps to the five-round maximum")

local priorGrandTourSave = run.loader.modSave
run.loader.modSave = {}
local grandTourState = grandTour.state()
run.loader.modSave.trainer_rematch.step_clock = 1000
grandTourState.cruise.nextAt = 5096
T.eq(grandTour.cruiseRemaining(), 4096,
  "the voyage status measures its cooldown on literal walked tiles")
run.loader.modSave.trainer_rematch.step_clock = 5096
T.eq(grandTour.cruiseRemaining(), 0,
  "the S.S. Anne returns after all 4096 real steps")
local factoryWrites = 0
grandTourState.factory.backupParty = {
  { species = "FIXMON_A", level = 42 },
}
T.eq(RealRuntime.call("save.write", function()
    factoryWrites = factoryWrites + 1
    return true
  end, {}), false,
  "the global save hotkey is vetoed during a live Factory rental run")
T.eq(factoryWrites, 0,
  "a vetoed Factory save never reaches the disk-writing continuation")
grandTourState.factory.backupParty = nil
T.eq(RealRuntime.call("save.write", function()
    factoryWrites = factoryWrites + 1
    return true
  end, {}), true,
  "normal saving resumes as soon as the Factory party is restored")
T.eq(factoryWrites, 1,
  "the ordinary save path still reaches its continuation exactly once")

local ascendantGrandTourState = asc.state()
ascendantGrandTourState.achievements.factory_architect = true
ascendantGrandTourState.achievements.sea_champion = true
grandTourState.factory.title = false
grandTourState.cruise.title = false
T.eq(grandTour.state().factory.title, true,
  "an existing Factory achievement repairs its stale local title flag")
T.eq(grandTour.state().cruise.title, true,
  "an existing cruise achievement repairs its stale local title flag")

local factoryOriginalParty = rentals
factoryGame.save.party = factoryOriginalParty
local factoryMessages = {}
factoryGame.stack = {
  push = function(_, box) factoryMessages[#factoryMessages + 1] = box end,
}
local factoryNpc = { frozen = true }
local factoryOw = {
  afterBattle = function() end,
  pushBattle = function(self, battle) self.battle = battle end,
}

local originalPokemonNew = Pokemon.new
Pokemon.new = function() error("injected rental build failure") end
local rentalCallOk, rentalStarted, rentalReason = pcall(
  grandTour.startFactoryRun, factoryGame, factoryOw, factoryNpc,
  { firstDraft[1], firstDraft[2], firstDraft[3] })
Pokemon.new = originalPokemonNew
T.eq(rentalCallOk, true,
  "a thrown rental constructor is contained by the Factory transaction")
T.eq(rentalStarted, false,
  "a failed rental build cannot start a partial Factory run")
T.eq(rentalReason, "rental_error",
  "the failed rental transaction reports its precise stage")
T.eq(factoryGame.save.party, factoryOriginalParty,
  "a rental-construction failure keeps the exact original party")
T.eq(grandTour.state().factory.backupParty, nil,
  "a rental-construction failure consumes the temporary party backup")

local originalForcedBattle = pg.newForcedBattle
local forcedBattleCalls = 0
pg.newForcedBattle = function()
  forcedBattleCalls = forcedBattleCalls + 1
  if forcedBattleCalls == 2 then error("injected battle build failure") end
  return { trainer = { name = "FACTORY TEST" } }
end
factoryMessages = {}
factoryNpc.frozen = true
factoryGame.save.party = factoryOriginalParty
package.loaded["src.render.TextBox"] = textBoxStub
local partialStarted = grandTour.startFactoryRun(
  factoryGame, factoryOw, factoryNpc,
  { firstDraft[1], firstDraft[2], firstDraft[3] })
T.eq(partialStarted, true,
  "the injected Factory battle failure occurs only after round one starts")
factoryOw.battle.onFinish("win")
factoryMessages[#factoryMessages].onDone()
package.loaded["src.render.TextBox"] = realTextBoxModule
pg.newForcedBattle = originalForcedBattle
T.eq(factoryGame.save.party, factoryOriginalParty,
  "a later namedBattle failure restores the exact original party")
T.eq(grandTour.state().factory.backupParty, nil,
  "a later namedBattle failure clears the save-veto backup")
T.eq(factoryNpc.frozen, false,
  "a failed later Factory round releases the facility NPC")
T.eq(factoryMessages[#factoryMessages].text:find(
    "original team", 1, true) ~= nil, true,
  "an asynchronous Factory rollback explains that the team was restored")

local festivalState = worldEvents.state()
local priorFestival = festivalState.active
festivalState.active = { id = "frontier_festival", steps = 100 }
ascendantGrandTourState.frontierPoints = 10
pg.newForcedBattle = function()
  return { trainer = { name = "GRAND TOUR TEST" } }
end
factoryMessages = {}
factoryNpc.frozen = true
factoryGame.save.party = factoryOriginalParty
package.loaded["src.render.TextBox"] = textBoxStub
T.eq(grandTour.startFactoryRun(
    factoryGame, factoryOw, factoryNpc,
    { firstDraft[1], firstDraft[2], firstDraft[3] }), true,
  "a complete test Factory run starts with the valid draft")
for round = 1, 3 do
  factoryOw.battle.onFinish("win")
  if round < 3 then factoryMessages[#factoryMessages].onDone() end
end
T.eq(ascendantGrandTourState.frontierPoints, 22,
  "Frontier Festival actually credits twelve points for a clean Factory run")
T.eq(factoryMessages[#factoryMessages].text:find(
    "+12 FRONTIER POINTS", 1, true) ~= nil, true,
  "the Factory clear dialogue shows the twelve points actually credited")

factoryMessages = {}
factoryNpc.frozen = true
grandTour.state().cruise.nextAt = 0
T.eq(grandTour.startCruise(factoryGame, factoryOw, factoryNpc), true,
  "a complete test S.S. Anne Grand Tour starts off cooldown")
for round = 1, 5 do
  factoryOw.battle.onFinish("win")
  if round < 5 then factoryMessages[#factoryMessages].onDone() end
end
package.loaded["src.render.TextBox"] = realTextBoxModule
pg.newForcedBattle = originalForcedBattle
festivalState.active = priorFestival
T.eq(ascendantGrandTourState.frontierPoints, 38,
  "Frontier Festival actually credits sixteen points for the cruise")
T.eq(factoryMessages[#factoryMessages].text:find(
    "+16 FRONTIER POINTS", 1, true) ~= nil, true,
  "the cruise clear dialogue shows the sixteen points actually credited")

run.loader.modSave = priorGrandTourSave
end)()

-- ------------------------------------------ Johto Signals -> Lind hand-off

assert(loadfile(modPath .. "/tests/johto_signals_lind_spec.lua"))()(
  T, run.data, modPath)

-- ------------------------------------------------ stable hot-reload dispatch

;(function()
  local hotPushed = {}
  local hotGame = {
    data = Data,
    save = {
      money = 3000,
      inventory = {},
      bagOrder = {},
      defeatedTrainers = {},
      flags = {},
      modData = game.save.modData,
      player = { name = "RED" },
      party = {
        { level = 5 }, { level = 6 }, { level = 7 },
      },
    },
    stack = {
      push = function(_, state)
        hotPushed[#hotPushed + 1] = state
      end,
    },
    mods = { exports = {} },
  }
  local hotDeps = {}
  for key, value in pairs(installDeps) do hotDeps[key] = value end
  hotDeps.mapScripts = {
    talkScript = function() return false end,
  }

  local hotNpc = {
    id = "FIX_ROUTE_obj_hot_reload",
    def = {
      trainerClass = "OPP_FIX_YOUNGSTER",
      trainerParty = 1,
      text = "HOT_RELOAD",
      index = 1,
    },
    frozen = false,
    facePlayer = function() end,
  }
  game.save.modData.trainer_rematch.trainers[hotNpc.id] = {
    rematches = 0,
    trainingCycles = 0,
    readyAt = 0,
  }
  local hotOw = {
    map = { id = "FIX_ROUTE", def = { label = "FixRoute" } },
    player = {},
    trainerDefeated = function() return true end,
    afterBattle = function() end,
    pushBattle = function() end,
  }

  local oldStackCount = #pushed
  local stableTalkWrapper = overworldStub.talkTo
  ex.install(hotGame, hotDeps)
  T.eq(overworldStub.talkTo, stableTalkWrapper,
    "hot install keeps one stable engine-facing talk wrapper")
  overworldStub.talkTo(hotOw, hotNpc)
  T.eq(#hotPushed, 1,
    "the stable talk wrapper dispatches into the freshly installed game")
  T.eq(#pushed, oldStackCount,
    "the superseded game stack receives no post-reload dialogue")
  T.eq(hotPushed[1].text, ex.resolveLine("OPP_FIX_YOUNGSTER"),
    "the fresh runtime retains the normal rematch dialogue flow")

  -- Leave shared controllers pointing back at the suite's original game so
  -- release hooks exercise the same instance they were created with.
  ex.install(game, installDeps)
  T.eq(overworldStub.talkTo, stableTalkWrapper,
    "restoring the original runtime also avoids wrapper stacking")
end)()

run.release()
T.finish("trainer_rematch")
