-- Real-client Red/Blue/Yellow QA for the independent Pokédex sprite option.
-- Run the same driver against each ROM cache. It changes only in-memory mod
-- options and exits without writing a save slot.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local Sprites = require("src.pokemon.Sprites")
  local Pokemon = require("src.pokemon.Pokemon")
  local GameVersion = require("src.core.GameVersion")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/kanto-ascendant-dex-sprite-qa"
  local version = GameVersion.get()
  local speciesOrder = { "BULBASAUR", "CHARMANDER", "SQUIRTLE" }
  local johtoOrder = { "SENTRET", "FURRET", "HOOTHOOT", "NOCTOWL" }

  U.wait(20)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.trainer_rematch,
    "Kanto Ascendant export missing")
  assert(api.crystalAnimation and api.crystalAnimation.staticFrameOne,
    "static Crystal Dex resolver missing")

  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  for _, species in ipairs(speciesOrder) do
    game.save.pokedex.seen[species] = true
    game.save.pokedex.owned[species] = true
  end
  for _, species in ipairs(johtoOrder) do
    game.save.pokedex.seen[species] = true
    game.save.pokedex.owned[species] = true
  end

  game.mods.modOptions = game.mods.modOptions or {}
  local loaderOptions = game.mods.modOptions
  loaderOptions.trainer_rematch = loaderOptions.trainer_rematch or {}
  local options = loaderOptions.trainer_rematch
  local function setOption(key, value)
    options[key] = value
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions.trainer_rematch =
      game.save.options.modOptions.trainer_rematch or {}
    game.save.options.modOptions.trainer_rematch[key] = value
    if game.mods.events then
      game.mods.events:emit("mod.options_changed", {
        mod = "trainer_rematch", key = key, value = value,
      })
    end
  end

  local base = {}
  for _, species in ipairs(speciesOrder) do
    base[species] = game.data.pokemon[species].spriteFront
  end

  local function assertOriginalDex()
    for _, species in ipairs(speciesOrder) do
      local path, trueColor = Sprites.path(
        game.data, species, "front", { kind = "dex" })
      assert(path == base[species],
        version .. " ORIGINAL Dex replaced " .. species .. ": " .. tostring(path))
      assert(not trueColor,
        version .. " ORIGINAL Dex disabled normal palette recoloring")
    end
  end

  local function assertCrystalDex()
    for _, species in ipairs(speciesOrder) do
      local dex = game.data.pokemon[species].dex
      local expected = ("assets/crystal_animated/front/normal/%d/001.png")
        :format(dex)
      local path, trueColor = Sprites.path(
        game.data, species, "front", { kind = "dex" })
      assert(path:find(expected, 1, true),
        version .. " CRYSTAL Dex did not use frame one for " .. species)
      assert(trueColor,
        version .. " CRYSTAL Dex frame was not marked true-color")
    end
  end

  local function assertJohtoDex()
    for _, species in ipairs(johtoOrder) do
      local dex = game.data.pokemon[species].dex
      local expected = ("assets/crystal_animated/front/normal/%d/001.png")
        :format(dex)
      local path, trueColor = Sprites.path(
        game.data, species, "front", { kind = "dex" })
      assert(path:find(expected, 1, true),
        version .. " Johto Dex used a Kanto fallback for " .. species
          .. ": " .. tostring(path))
      assert(trueColor,
        version .. " Johto Dex frame was not marked true-color for " .. species)
    end
  end

  local function capture(style, order)
    for _, species in ipairs(order or speciesOrder) do
      Screens.push(game, "DexEntryMenu", species)
      U.wait(45)
      assert(U.shot(game, ("%s/%s_%s_%s.png"):format(
        DIR, version, style, species:lower())))
      U.tap(game, "b")
      U.wait(15)
    end
  end

  setOption("dex_sprite_style", "original")
  setOption("kanto_crystal_art", false)
  assertOriginalDex()
  assertJohtoDex()
  capture("original")
  capture("johto_original", johtoOrder)

  setOption("kanto_crystal_art", true)
  assertOriginalDex()

  setOption("dex_sprite_style", "crystal")
  assertCrystalDex()
  assertJohtoDex()
  capture("crystal")
  capture("johto_crystal", johtoOrder)

  setOption("kanto_crystal_art", false)
  assertCrystalDex()

  setOption("crystal_animation", false)
  assertCrystalDex()

  -- Final independence check: Dex style changes while the battle resolver
  -- remains governed exclusively by KANTO CRYSTAL ART.
  local battleOriginal = {}
  local battleMon = Pokemon.new(game.data, "BULBASAUR", 20,
    function() return 8 end)
  for _, style in ipairs({ "original", "crystal" }) do
    setOption("dex_sprite_style", style)
    local path = Sprites.path(
      game.data, "BULBASAUR", "front", { kind = "battle",
        mon = battleMon })
    battleOriginal[style] = path
  end
  assert(battleOriginal.original == battleOriginal.crystal,
    "DEX SPRITES changed Bulbasaur's battle artwork")

  print(("[ASCENDANT DEX QA] version=%s Kanto+Johto original+crystal matrix PASS; shots=%s")
    :format(version, DIR))
end
