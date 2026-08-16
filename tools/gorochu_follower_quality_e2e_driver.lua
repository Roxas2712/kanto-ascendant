-- Real-LÖVE visual proof for every Gorochu direction/gait frame.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local PaletteFX = require("src.render.PaletteFX")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("gorochu%-follower%-quality"),
    "refusing to run outside a dedicated Gorochu follower QA identity")
  assert(GameVersion.get() == "red", "Gorochu visual QA is pinned to Red")
  U.wait(5)

  local api = assert(game.mods.exports.kanto_ascendant,
    "Kanto Ascendant exports missing")
  local expectedPath = os.getenv("POKEPORT_EXPECT_MOD_PATH")
  if expectedPath then
    assert(game.mods.mods.kanto_ascendant.path == expectedPath,
      "wrong candidate path: " .. tostring(game.mods.mods.kanto_ascendant.path))
  end
  local native = assert(api.singleFollower, "native follower unavailable")
  local registry = assert(api.followerSprites, "follower registry unavailable")
  local shiny = assert(api.shinySystem, "shiny system unavailable")

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.onBike, game.save.repelSteps = false, 9999
  -- ADVANCED leaves the authored true-colour pixels directly inspectable;
  -- SGB intentionally reduces overworld objects to the map's four shades.
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")
  local mon = Pokemon.new(game.data, "GOROCHU", 50)
  game.save.party = { mon }
  api.followerConfig.setMode("party")
  api.followerConfig.setCount(1)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(12)

  local poses = {
    { "stand-down", "down", 0, false },
    { "stand-up", "up", 0, false },
    { "stand-left", "left", 0, false },
    { "walk-down", "down", 1, false },
    { "walk-up", "up", 1, true },
    { "walk-left", "left", 1, false },
    { "walk-right", "right", 1, false },
  }
  local shotDir = os.getenv("SHOT_DIR") or "/tmp/gorochu-follower-quality"

  local function captureVariant(name, expectedSuffix, expectedBody)
    native.refresh(game)
    U.wait(3)
    local entity = assert(native.entity(game), name .. " Gorochu follower missing")
    assert(entity.followerSpecies == "GOROCHU", "wrong follower species")
    assert(entity.followerSprite:match(expectedSuffix .. "$"),
      name .. " selected wrong sheet: " .. tostring(entity.followerSprite))
    assert(entity.sprite.def.trueColor == true,
      name .. " Gorochu was not configured for authored colour")
    assert(entity.sprite.def.image == entity.followerSprite,
      name .. " renderer retained a stale follower sheet: "
        .. tostring(entity.sprite.def.image) .. " != "
        .. tostring(entity.followerSprite))
    local width, height = entity.sprite.image:getDimensions()
    assert(width == 16 and height == 96, "runtime Gorochu sheet geometry changed")
    local pixels = love.image.newImageData(entity.sprite.def.image)
    local r, g, b, a = pixels:getPixel(6, 5)
    local function byte(value) return math.floor(value * 255 + 0.5) end
    local actual = { byte(r), byte(g), byte(b), byte(a) }
    for index = 1, 4 do
      assert(actual[index] == expectedBody[index],
        ("%s renderer loaded wrong pixel at 6,5: got %d,%d,%d,%d")
          :format(name, actual[1], actual[2], actual[3], actual[4]))
    end
    local originalPose = entity.pose
    for _, pose in ipairs(poses) do
      entity.pose = function(self)
        return self.sprite, self.px, self.py, pose[2], pose[3], pose[4], false
      end
      assert(U.shot(game, ("%s/%s-%s.png"):format(shotDir, name, pose[1])),
        name .. " " .. pose[1] .. " screenshot failed")
    end
    entity.pose = originalPose
  end

  captureVariant("normal", "normal/follower_GOROCHU%.png", { 232, 74, 38, 255 })
  assert(shiny.forceMon(mon, game.data.pokemon.GOROCHU),
    "could not create shiny Gorochu QA Pokémon")
  captureVariant("shiny", "shiny/follower_GOROCHU%.png", { 80, 96, 120, 255 })

  U.log("GOROCHU FOLLOWER REAL E2E PASS",
    "normal+shiny all directions/gait frames plus mirrored right")
  love.event.quit(0)
end
