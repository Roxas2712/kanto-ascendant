-- Interactive, non-saving manual test for Yellow partner Raichu reactions.
-- Talk to the follower repeatedly; each interaction applies the next real
-- happiness/mood/status condition before calling the production talk path.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local GameVersion = require("src.core.GameVersion")
  local PikachuFollower = require("src.world.PikachuFollower")
  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")

  U.wait(20)
  assert(GameVersion.isYellow(), "Raichu mood test requires Yellow")
  local ascendant = assert(
    game.mods and game.mods.exports and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant is not loaded")
  local partnerApi = assert(ascendant.yellowPartner,
    "Yellow partner controller missing")

  game.save.player = game.save.player or {}
  game.save.player.name = "MOOD TEST"
  game.save.player.id = 5301
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_CHOSE_PIKACHU = true
  game.save.inventory = game.save.inventory or {}
  game.save.inventory.THUNDERBADGE = 1
  game.save.inventory[partnerApi.itemId] = 1

  local raichu = Pokemon.new(game.data, "RAICHU", 50,
    function() return 10 end)
  BattleState.stampOT(game.save, raichu)
  raichu[partnerApi.marker] = true
  raichu.hp = raichu.stats.hp
  game.save.party = { raichu }

  local moods = {
    {
      label = "SLEEPY",
      happiness = 230, mood = 128, status = "SLP",
    },
    {
      label = "UNWELL",
      happiness = 230, mood = 128, status = "PSN",
    },
    {
      label = "UPSET",
      happiness = 30, mood = 50,
    },
    {
      label = "WARY",
      happiness = 90, mood = 100,
    },
    {
      label = "CONTENT",
      happiness = 150, mood = 128,
    },
    {
      label = "DEVOTED",
      happiness = 220, mood = 128,
    },
    {
      label = "EXCITED",
      happiness = 240, mood = 150,
    },
  }
  local moodIndex = 1
  local productionTalk = PikachuFollower.talk
  for _, test in ipairs(moods) do
    raichu.status = test.status
    game.save.pikachuHappiness = test.happiness
    game.save.pikachuMood = test.mood
    local reaction = partnerApi.raichuReaction(game, raichu)
    local def = assert(game.data.audio.sfx[reaction.voice],
      "missing voice definition for " .. test.label)
    assert(love.filesystem.getInfo(def.file),
      "missing voice file for " .. test.label .. ": " .. tostring(def.file))
    local ok, source = pcall(love.audio.newSource, def.file, "static")
    assert(ok and source,
      "unplayable voice file for " .. test.label .. ": " .. tostring(source))
  end
  raichu.status = nil

  PikachuFollower.talk = function(gameNow, ow, npc, done)
    local test = moods[moodIndex]
    raichu.status = test.status
    raichu.hp = raichu.stats.hp
    gameNow.save.pikachuHappiness = test.happiness
    gameNow.save.pikachuMood = test.mood
    U.log("Raichu mood", moodIndex, test.label,
      "happiness", test.happiness, "mood", test.mood)
    local result = productionTalk(gameNow, ow, npc, function(...)
      moodIndex = moodIndex % #moods + 1
      if done then return done(...) end
    end)
    -- Manual-review aid only: production uses the voice-matched hold. Keep
    -- the test portrait up for five seconds so every animation loop is easy
    -- to inspect; A/B still skips immediately.
    if ow.emote and ow.emote._ascendantRaichuFrames then
      ow.emote.frames = 300
      ow.emote.pikaTotal = 300
    end
    return result
  end

  U.teleport(game, "VERMILION_CITY", 20, 18, "down")
  PikachuFollower.onMapEntered(game, game.overworld)
  U.wait(20)

  game.stack:push(TextBox.new(game,
    "RAICHU TEST\fSprich RAICHU sieben\nMal an.\fReihenfolge: SLEEPY,\nUNWELL, UPSET, WARY,\fCONTENT, DEVOTED,\nEXCITED.\fPruefe jedes Mal:\nEmoji frei, passende\nMimik und Stimme.\fDanach beginnt die\nReihe von vorn."))

  U.log("Raichu mood test ready; talk to the follower repeatedly")
  while true do coroutine.yield() end
end
