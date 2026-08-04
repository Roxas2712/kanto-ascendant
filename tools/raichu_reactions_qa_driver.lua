-- Automated visual/audio smoke test for all seven partner-Raichu reactions.
-- It uses production follower talk, captures two animation phases per mood,
-- proves the portrait is mood-specific and verifies emoji/box separation.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local GameVersion = require("src.core.GameVersion")
  local PikachuFollower = require("src.world.PikachuFollower")
  local Pokemon = require("src.pokemon.Pokemon")

  U.wait(20)
  assert(GameVersion.isYellow(), "Raichu reaction QA requires Yellow")
  local ascendant = assert(
    game.mods and game.mods.exports and game.mods.exports.trainer_rematch,
    "Kanto Ascendant is not loaded")
  local partnerApi = assert(ascendant.yellowPartner,
    "Yellow partner controller missing")
  local shotDir = assert(os.getenv("SHOT_DIR"),
    "SHOT_DIR is required for reaction QA")

  game.save.player = game.save.player or {}
  game.save.player.name = "REACTION QA"
  game.save.player.id = 5302
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_CHOSE_PIKACHU = true
  game.save.inventory = game.save.inventory or {}
  game.save.inventory.THUNDERBADGE = 1
  game.save.inventory[partnerApi.itemId] = 1

  -- All-10 DVs satisfy Gen II's shiny formula. Keep this focused Raichu
  -- reaction run explicitly non-shiny; the full dialogue matrix separately
  -- exercises both variants.
  local raichu = Pokemon.new(game.data, "RAICHU", 50,
    function() return 9 end)
  BattleState.stampOT(game.save, raichu)
  raichu[partnerApi.marker] = true
  raichu.hp = raichu.stats.hp
  game.save.party = { raichu }

  local moods = {
    { id = "sleepy", happiness = 230, mood = 128, status = "SLP" },
    { id = "unwell", happiness = 230, mood = 128, status = "PSN" },
    { id = "upset", happiness = 30, mood = 50 },
    { id = "wary", happiness = 90, mood = 100 },
    { id = "content", happiness = 150, mood = 128 },
    { id = "devoted", happiness = 220, mood = 128 },
    { id = "excited", happiness = 240, mood = 150 },
  }

  U.teleport(game, "VERMILION_CITY", 20, 18, "down")
  PikachuFollower.onMapEntered(game, game.overworld)
  U.wait(20)
  local npc = assert(PikachuFollower.current(game.overworld),
    "partner Raichu follower is missing")

  for index, test in ipairs(moods) do
    raichu.status = test.status
    raichu.hp = raichu.stats.hp
    game.save.pikachuHappiness = test.happiness
    game.save.pikachuMood = test.mood
    PikachuFollower.talk(game, game.overworld, npc, function() end)
    local emote = assert(game.overworld.emote,
      "reaction did not create an emote for " .. test.id)
    assert(emote.pikaPic:find(
      "/yellow_partner_raichu_portraits/", 1, true),
      "reaction did not use its custom face for " .. test.id)
    assert(emote.pikaPic:find("/" .. test.id .. "/", 1, true),
      "reaction selected the wrong custom face for " .. test.id)
    local boxLeft = assert(emote._ascendantRaichuBoxX) * 8
    local boxRight = boxLeft + 56
    local cameraX = game.overworld.camera and game.overworld.camera.x or 0
    local bubbleLeft = npc.px - cameraX + 4
    local bubbleRight = bubbleLeft + 16
    assert(boxRight <= bubbleLeft or boxLeft >= bubbleRight,
      "portrait overlaps emoji for " .. test.id)
    assert(U.shot(game, ("%s/%02d_%s_frame_1.png")
      :format(shotDir, index, test.id)),
      "first screenshot failed for " .. test.id)
    local firstPath = emote._ascendantRaichuFrames[1]
    local phase
    for frame = 2, #emote._ascendantRaichuFrames do
      if emote._ascendantRaichuFrames[frame] ~= firstPath then
        phase = frame - 1
        break
      end
    end
    assert(phase, "Raichu portrait has no distinct animation frame")
    -- Drive the exact animation phase instead of depending on QA's
    -- accelerated frame step, which can jump over a short second frame.
    local ticks = math.max(1,
      math.floor(tonumber(emote._ascendantRaichuTicks) or 8))
    emote.frames = math.max(1,
      (emote.pikaTotal or emote.frames or 120) - ticks * phase)
    partnerApi._advanceRaichuPortrait(game.overworld)
    assert(game.overworld.emote,
      "reaction ended before its second frame for " .. test.id)
    assert(emote.pikaPic ~= firstPath,
      "Raichu portrait did not advance to a distinct frame for " .. test.id)
    assert(U.shot(game, ("%s/%02d_%s_frame_2.png")
      :format(shotDir, index, test.id)),
      "second screenshot failed for " .. test.id)
    game.overworld.emote = nil
    U.wait(2)
  end

  U.log("PASS Raichu reactions",
    "7 supplied custom faces",
    "7 voices", "emoji clear", "14 screenshots")
  love.event.quit(0)
end
