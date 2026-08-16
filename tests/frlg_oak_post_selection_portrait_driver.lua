-- Renderer-backed proof for the screen immediately after CharacterSelect.
-- The selection screen is deliberately not inspected or changed here: this
-- driver confirms that Oak's following player/rival pages use the same native
-- 128px standing masters instead of falling back to 64px battle poses.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local OakSpeech = require("src.ui.OakSpeech")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local characters = assert(exports.extendedCharacters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local expectedRival = { GREEN = "RED", BLUE = "GREEN", RED = "BLUE" }
  for selectorIndex, player in ipairs(characters.selectionOrder) do
    while game.stack:top() do game.stack:pop() end
    local speech = OakSpeech.new(game, function() end)
    game.stack:push(speech)
    local selector = characters.CharacterSelect.new(game, speech, function() end)
    selector.index = selectorIndex
    game.stack:push(selector)
    U.tap(game, "a")
    U.wait(2)

    check(player .. " selection returns to OakSpeech",
      game.stack:top() == speech)
    check(player .. " identity persisted", characters.getPlayerCharacter() == player)

    speech:applyPic({ pic = "player" })
    speech.__kantoAscendantOakHdProof = nil
    speech:sayText(player .. " - PLAYER", function() end)
    U.wait(3)
    check(player .. " player screenshot", U.shot(game,
      ("%s/%02d_%s_player_after_selection.png")
        :format(dir, selectorIndex, player:lower())))
    local playerProof = speech.__kantoAscendantOakHdProof
    check(player .. " player uses native standing master",
      playerProof and playerProof.role == "player"
        and playerProof.character == player
        and playerProof.sourceWidth == 128
        and playerProof.sourceHeight == 128
        and playerProof.sourcePath ==
          ("assets/characters/crystal_chars/%s_voxel_front_hd.png")
            :format(player:lower())
        and playerProof.integerZoom == math.floor(playerProof.integerZoom))

    while game.stack:top() and game.stack:top() ~= speech do
      game.stack:pop()
    end
    speech:applyPic({ pic = "rival" })
    speech.__kantoAscendantOakHdProof = nil
    speech:sayText("RIVAL - " .. expectedRival[player], function() end)
    U.wait(3)
    check(player .. " rival screenshot", U.shot(game,
      ("%s/%02d_%s_rival_after_selection.png")
        :format(dir, selectorIndex, player:lower())))
    local rivalProof = speech.__kantoAscendantOakHdProof
    local rival = expectedRival[player]
    check(player .. " route uses correct native rival standing master",
      rivalProof and rivalProof.role == "rival"
        and rivalProof.character == rival
        and rivalProof.sourceWidth == 128
        and rivalProof.sourceHeight == 128
        and rivalProof.sourcePath ==
          ("assets/characters/crystal_chars/%s_voxel_front_hd.png")
            :format(rival:lower())
        and rivalProof.integerZoom == math.floor(rivalProof.integerZoom))

    if player == "RED" then
      while game.stack:top() and game.stack:top() ~= speech do
        game.stack:pop()
      end
      speech.pic = speech.shrinkPic1
      speech.__kantoAscendantOakHdProof = nil
      check("closing shrink-frame screenshot", U.shot(game,
        dir .. "/04_closing_shrink_without_standing_overlay.png"))
      check("standing portrait does not leak over closing shrink",
        speech.__kantoAscendantOakHdProof == nil)
    end
  end

  U.log(("FRLG OAK POST-SELECTION RESULT pass=%d fail=%d")
    :format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
