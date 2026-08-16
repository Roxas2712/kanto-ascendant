-- Renderer-backed proof using the real German Red translation mod.

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

  local function speechFor(character)
    clearStack()
    characters.select(character)
    characters.refreshVisuals(game)
    local speech = OakSpeech.new(game, function() end)
    speech.steps = speech:buildSteps()
    table.insert(game.stack.states, speech)
    return speech
  end

  local function motherGameplayProof(character, needle, filename)
    clearStack()
    characters.select(character)
    characters.refreshVisuals(game)
    game.save.flags = game.save.flags or {}
    game.save.flags.EVENT_GOT_STARTER = nil
    local mother = game.data.text._RedsHouse1FMomWakeUpText
    check("German mother identifies Green as a girl", mother
      and mother:find(needle, 1, true)
      and not mother:find("boys", 1, true))
    -- Real map interaction: no OakSpeech layer and no character portrait.
    U.teleport(game, "REDS_HOUSE_1F", 5, 5, "up")
    U.tap(game, "a")
    U.wait(100)
    local box = game.stack:top()
    check("German mother scene uses the in-house world and plain text box",
      box and box.pages and not box.pic and game.overworld ~= box)
    check("German mother capture", U.shot(game, dir .. "/" .. filename))
  end

  check("Kanto Ascendant character API loaded", characters ~= nil)
  check("real German translation is active", exports
    and exports.language and exports.language() == "de")
  if not (characters and exports.language() == "de") then
    love.event.quit(1)
    return
  end
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1

  local speech = speechFor("RED")
  findStep(speech.steps, "extended_character_selection").run(speech,
    function() end)
  U.wait(8)
  local selector = game.stack:top()
  U.log("German selector state", tostring(selector),
    tostring(selector and selector.index),
    tostring(getmetatable(selector) == characters.CharacterSelect))
  check("German selector begins with Grün",
    selector and characters.selectionOrder[selector.index] == "GREEN")
  check("German selector uses canonical localized identities",
    characters.selectionLabel("GREEN") == "GRÜN"
    and characters.selectionLabel("BLUE") == "BLAU"
    and characters.selectionLabel("RED") == "ROT")
  check("German direct selector capture",
    U.shot(game, dir .. "/16_de_character_select_gruen.png"))

  speech = speechFor("GREEN")
  findStep(speech.steps, "name_player").run(speech, function() end)
  U.wait(8)
  local menu = game.stack:top()
  local naming = game.stack.states[#game.stack.states - 1]
  check("German naming title is feminine", naming.title == "IHR NAME?")
  check("German presets are Grün, Casey, Jean", menu.items[1].label == "GRÜN"
    and menu.items[2].label == "CASEY" and menu.items[3].label == "JEAN")
  check("German free-name entry is last",
    menu.items[4].label == "NEUER NAME")
  check("German Green naming capture",
    U.shot(game, dir .. "/17_de_green_player_name.png"))

  speech = speechFor("GREEN")
  findStep(speech.steps, "name_rival").run(speech, function() end)
  U.wait(8)
  menu = game.stack:top()
  check("German Red rival suggestions are Rot, Ash, Jack",
    menu.items[1].label == "ROT" and menu.items[2].label == "ASH"
    and menu.items[3].label == "JACK")
  check("German Red rival free-name entry is last",
    menu.items[4].label == "NEUER NAME")
  check("German Red rival naming capture",
    U.shot(game, dir .. "/17b_de_green_red_rival_name.png"))

  speech = speechFor("GREEN")
  findStep(speech.steps, "ask_rival_name").run(speech, function() end)
  U.wait(110)
  check("German Alabastia rival intro capture",
    U.shot(game, dir .. "/18_de_green_red_alabastia_intro.png"))

  speech = speechFor("GREEN")
  game.save.player.rival = "RAY"
  findStep(speech.steps, "extended_rival_confirmation").run(speech,
    function() end)
  U.wait(45)
  check("German chosen-name confirmation capture",
    U.shot(game, dir .. "/18b_de_red_name_confirm.png"))
  U.tap(game, "a")
  U.wait(45)
  check("German Alabastia role confirmation capture",
    U.shot(game, dir .. "/18bb_de_red_role_confirm.png"))

  motherGameplayProof("GREEN", "Mädchen",
    "18c_de_green_mother_gender.png")

  speech = speechFor("GREEN")
  speech:applyPic({ pic = "rival" })
  local lab = game.data.text._OaksLabRivalIllTakeYouOnText
  check("German calm Red line is language-clean", lab
    and lab:find("Sehen wir", 1, true)
    and not lab:find("Let's", 1, true))
  speech:sayText(lab, function() end)
  U.wait(100)
  check("German calm Red capture",
    U.shot(game, dir .. "/18d_de_red_calm_lab.png"))

  U.log(("PHASE8 GERMAN STORY RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
