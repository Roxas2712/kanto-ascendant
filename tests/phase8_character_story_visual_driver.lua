-- Renderer-backed proof for Phase-8 New Game naming and rival dialogue.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local OakSpeech = require("src.ui.OakSpeech")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant
  local characters = exports and exports.extendedCharacters
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function clearStack()
    while game.stack:top() do game.stack:pop() end
  end

  local function findStep(steps, id)
    for _, step in ipairs(steps) do
      if step.id == id then return step end
    end
  end

  local function newSpeech(character)
    clearStack()
    characters.select(character)
    characters.refreshVisuals(game)
    local speech = OakSpeech.new(game, function() end)
    speech.steps = speech:buildSteps()
    -- Keep the real OakSpeech renderer below the menu/text box, but avoid
    -- enter(), which would start the complete intro sequence.
    table.insert(game.stack.states, speech)
    return speech
  end

  local function nameProof(character, stepId, title, expectedPresets, filename)
    local speech = newSpeech(character)
    local step = assert(findStep(speech.steps, stepId), stepId)
    step.run(speech, function() end)
    U.wait(8)
    local menu = game.stack:top()
    local naming = game.stack.states[#game.stack.states - 1]
    check(filename .. " uses live NamingScreen", naming
      and naming.title == title and menu and menu.items)
    check(filename .. " first preset", menu and menu.items
      and menu.items[1] and menu.items[1].label == expectedPresets[1])
    check(filename .. " second preset", menu and menu.items
      and menu.items[2] and menu.items[2].label == expectedPresets[2])
    check(filename .. " third preset", menu and menu.items
      and menu.items[3] and menu.items[3].label == expectedPresets[3])
    check(filename .. " free entry is last", menu and menu.items
      and menu.items[4] and menu.items[4].label == "NEW NAME")
    check(filename .. " capture", U.shot(game, dir .. "/" .. filename))
    -- NEW NAME closes only the preset overlay, exposing the complete title.
    U.tap(game, "down")
    U.tap(game, "down")
    U.tap(game, "down")
    U.tap(game, "a")
    U.wait(4)
    local gridName = filename:gsub("%.png$", "_grid.png")
    check(gridName .. " exposes full title", game.stack:top() == naming)
    check(gridName .. " capture", U.shot(game, dir .. "/" .. gridName))
  end

  local function selectionProof()
    local speech = newSpeech("RED")
    local step = assert(findStep(speech.steps, "extended_character_selection"))
    step.run(speech, function() end)
    U.wait(8)
    local selector = game.stack:top()
    check("character selection is direct and opaque", selector
      and selector.isOpaque and selector.index == 1)
    check("character selection starts with Green",
      characters.selectionOrder[selector.index] == "GREEN")
    check("all selector identities use canonical English labels",
      characters.selectionLabel("GREEN") == "GREEN"
      and characters.selectionLabel("BLUE") == "BLUE"
      and characters.selectionLabel("RED") == "RED")
    check("Green selection capture",
      U.shot(game, dir .. "/05c_character_select_green.png"))
    U.tap(game, "down")
    U.wait(4)
    check("cursor changes live portrait to Blue",
      characters.selectionOrder[selector.index] == "BLUE")
    check("Blue selection capture",
      U.shot(game, dir .. "/05d_character_select_blue.png"))
    U.tap(game, "down")
    U.wait(4)
    check("cursor changes live portrait to Red",
      characters.selectionOrder[selector.index] == "RED")
    check("Red selection capture",
      U.shot(game, dir .. "/05e_character_select_red.png"))
  end

  local function dialogueProof(character, expectedRival, filename)
    local speech = newSpeech(character)
    local step = assert(findStep(speech.steps, "ask_rival_name"))
    step.run(speech, function() end)
    U.wait(120)
    local trainer = game.data.trainers.OPP_RIVAL1
    check(filename .. " installs expected rival portrait", trainer and trainer.pic
      and trainer.pic:match((
        "/assets/characters/crystal_chars/%s_front%%.png$"
      ):format(expectedRival:lower())))
    check(filename .. " applies rival picture", speech.pic == speech.rivalPic
      and speech.pic ~= speech.playerPic)
    check(filename .. " capture", U.shot(game, dir .. "/" .. filename))
  end

  local function storyTextProof(character, pic, key, needle, filename)
    local speech = newSpeech(character)
    speech:applyPic({ pic = pic })
    local line = game.data.text[key]
    check(filename .. " has authored text", type(line) == "string"
      and line:find(needle, 1, true) ~= nil)
    speech:sayText(line, function() end)
    U.wait(100)
    check(filename .. " capture", U.shot(game, dir .. "/" .. filename))
  end

  local function motherGameplayProof(character, needle, filename)
    clearStack()
    characters.select(character)
    characters.refreshVisuals(game)
    game.save.flags = game.save.flags or {}
    game.save.flags.EVENT_GOT_STARTER = nil
    check(filename .. " has authored text",
      type(game.data.text._RedsHouse1FMomWakeUpText) == "string"
      and game.data.text._RedsHouse1FMomWakeUpText:find(needle, 1, true)
        ~= nil)
    -- This is the real RedsHouse1F interaction, not an OakSpeech/portrait
    -- harness: Green stands directly below Mom, faces her, and presses A.
    U.teleport(game, "REDS_HOUSE_1F", 5, 5, "up")
    U.tap(game, "a")
    U.wait(100)
    local box = game.stack:top()
    check(filename .. " uses the in-house world and plain text box",
      box and box.pages and not box.pic and game.overworld ~= box)
    check(filename .. " capture", U.shot(game, dir .. "/" .. filename))
  end

  check("Kanto Ascendant character API loaded", characters ~= nil)
  if not characters then love.event.quit(1) return end
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  U.wait(12)

  selectionProof()
  nameProof("GREEN", "name_player", "HER NAME?", { "GREEN", "CASEY", "JEAN" },
    "06_green_player_name.png")
  nameProof("BLUE", "name_rival", "HER NAME?", { "GREEN", "CASEY", "JEAN" },
    "07_blue_green_rival_name.png")
  nameProof("RED", "name_rival", "HIS NAME?", { "BLUE", "GARY", "JOHN" },
    "08_red_blue_rival_name.png")
  nameProof("GREEN", "name_rival", "HIS NAME?", { "RED", "ASH", "JACK" },
    "08b_green_red_rival_name.png")

  dialogueProof("RED", "BLUE", "09_red_blue_grandson_intro.png")
  dialogueProof("BLUE", "GREEN", "10_blue_green_cousin_intro.png")
  dialogueProof("GREEN", "RED", "11_green_red_pallet_intro.png")

  local speech = newSpeech("GREEN")
  speech:applyPic({ pic = "player" })
  local relation = assert(findStep(speech.steps, "extended_character_relation"))
  relation.run(speech, function() end)
  U.wait(120)
  check("Green family line keeps Green's player portrait",
    speech.pic == speech.playerPic)
  check("Green granddaughter capture",
    U.shot(game, dir .. "/12_green_pallet_relation.png"))

  speech = newSpeech("GREEN")
  game.save.player.rival = "RAY"
  local confirmation = assert(findStep(speech.steps,
    "extended_rival_confirmation"))
  confirmation.run(speech, function() end)
  U.wait(45)
  check("chosen Red name is confirmed after naming",
    U.shot(game, dir .. "/12b_green_red_name_confirm.png"))
  U.tap(game, "a")
  U.wait(45)
  check("Red's Pallet role is confirmed on its own readable page",
    U.shot(game, dir .. "/12c_green_red_role_confirm.png"))

  motherGameplayProof("GREEN", "girls", "13_green_mother_gender.png")
  storyTextProof("GREEN", "rival", "_OaksLabRivalIllTakeYouOnText",
    "Let's see what", "14_red_calm_lab.png")
  storyTextProof("BLUE", "rival", "_OaksLabRivalIllTakeYouOnText",
    "choice was better", "15_green_cheeky_lab.png")

  U.log(("PHASE8 STORY RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
