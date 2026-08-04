-- Real-runtime smoke test for the Android-facing 5.2.2 audio/follower fix.
-- Run with Kanto Ascendant and PokéPC Followers enabled in a disposable
-- POKEPORT_IDENTITY.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local PikachuFollower = require("src.world.PikachuFollower")
  local Sound = require("src.core.Sound")
  local Sprites = require("src.pokemon.Sprites")

  U.wait(15)
  local exports = assert(game.mods and game.mods.exports,
    "mod exports unavailable")
  local ascendant = assert(exports.trainer_rematch,
    "Kanto Ascendant export missing")
  local followers = assert(exports.PokePCFollowers_VoxelMerge,
    "PokéPC Followers export missing")

  if GameVersion.isYellow() then
    assert(game.data.strings.PIKACHU == "PIKACHU",
      "PokéPC Followers renamed Yellow's starter to Charmander")
    assert(not game.data.text._OaksLabPikachuDislikesPokeballsText2:find(
      "CHARMANDER", 1, true),
      "PokéPC Followers replaced Yellow's Pikachu story dialogue")
    local oakPikachu = Pokemon.new(game.data, "PIKACHU", 5,
      function() return 8 end)
    local oakPath = Sprites.path(game.data, "PIKACHU", "front", {
      kind = "battle",
      mon = oakPikachu,
    })
    assert(oakPath and oakPath:find(
      "assets/crystal_animated/front/normal/25/001.png", 1, true),
      "Oak's Pikachu resolved to the wrong intro sprite: "
        .. tostring(oakPath))
  end

  local cry = assert(Sound.playCry(game.data, "NATU"),
    "Natu derived cry did not create an audio source")
  local okDuration, duration = pcall(cry.getDuration, cry)
  assert(not okDuration or duration > 0, "Natu derived cry is empty")

  local natu = Pokemon.new(game.data, "NATU", 18, function() return 8 end)
  game.save.party = { natu }
  local path = assert(ascendant.spriteAssets.follower("NATU", false),
    "bundled Natu follower sheet missing")
  assert(path:find(
    "assets/followers_runtime/normal/follower_NATU.png", 1, true),
    "Natu did not select the packaged renderer-ready sheet: " .. path)
  local image = love.image.newImageData(path)
  local width, height = image:getDimensions()
  assert(width == 16 and height == 96,
    ("Natu follower has wrong dimensions: %dx%d"):format(width, height))

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  assert(followers.select(natu, game, true), "could not select Natu follower")
  U.wait(45)
  local npc = assert(PikachuFollower.current(game.overworld),
    "Natu follower did not spawn")
  assert(npc.sprite and npc.sprite.def,
    "Natu follower has no renderer")
  assert(npc.sprite.def.image == path,
    "follower renderer did not receive Ascendant's Natu sheet: "
      .. tostring(npc.sprite.def.image))

  U.log("PASS 5.2.2 hotfix:", "Oak Pikachu", "Natu cry",
    "Natu follower", path)
end
