-- Renderer-backed proof for Oak's real Red/Blue Legacy partner scene.
-- The driver uses a disposable identity and is intended to run from the
-- Gen1 Recomp checkout, for example:
--
--   POKEPORT_ONLY_MOD=kanto_ascendant POKEPORT_VERSION=red \
--   POKEPORT_IDENTITY=legacy-partner-visual POKEPORT_TOUCH=0 \
--   POKEPORT_SPEED=4 LEGACY_HERO=BLUE \
--   POKEPORT_DRIVER=mods/ka_rc11_integration/tests/legacy_partner_scene_visual_driver.lua \
--   SHOT_DIR=/tmp/ka-legacy-partner love .

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local MapScripts = require("data.scripts.init")
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local starters = assert(exports.legacyStarters)
  local characters = assert(exports.extendedCharacters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    return value
  end
  local function countKeys(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
  end
  local function state()
    local bucket = game.save.modData and game.save.modData.kanto_ascendant
    return bucket and bucket.legacy_journey
  end
  local function isCatalog(value)
    return value and getmetatable(value) == starters.Catalog
  end
  local function isText(value)
    return value and getmetatable(value) == TextBox
  end
  local function isChoice(value)
    return value and getmetatable(value) == ChoiceBox
  end
  local function unmasteredOrder(rows, reward)
    local expected = {}
    for _, id in ipairs(starters.partnerAllowlistOrder) do
      if not starters.legendaryIds[id] then expected[#expected + 1] = id end
    end
    if reward then expected[#expected + 1] = reward end
    if #expected ~= (reward and 119 or 118)
        or #(rows or {}) ~= #expected then return false end
    for index, row in ipairs(rows) do
      if row.id ~= expected[index] then return false end
    end
    return rows[#rows].id == (reward or "LARVITAR")
  end
  local function runnerBusy()
    return game.overworld and game.overworld.runner
      and game.overworld.runner:isRunning()
  end
  local function waitFor(predicate, frames)
    for _ = 1, frames or 600 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end
  local function waitForText(frames)
    return waitFor(function()
      local top = game.stack:top()
      return isText(top) and top or nil
    end, frames or 600)
  end
  local function waitForChoice(frames)
    frames = frames or 700
    for _ = 1, frames do
      local top = game.stack:top()
      if isChoice(top) then return top end
      if isText(top) then
        if top.waiting then
          U.tap(game, "a")
        elseif not top.done then
          -- Accelerate typewriting without generating wasPressed("a"), so
          -- the default-NO ChoiceBox cannot be accepted accidentally.
          game.input.state.a = true
          U.wait(1)
          game.input.state.a = false
        else
          U.wait(1)
        end
      else
        U.wait(1)
      end
    end
    game.input.state.a = false
    return nil
  end
  local function chooseYes()
    local box = game.stack:top()
    if not isChoice(box) then return false end
    -- Both irreversible prompts deliberately default to NO.
    if box.index == 2 then U.tap(game, "up") end
    U.tap(game, "a")
    return true
  end
  local function drainToOverworld(frames)
    for _ = 1, frames or 1200 do
      local top = game.stack:top()
      if top == game.overworld and not runnerBusy() then return true end
      if top ~= game.overworld then U.tap(game, "a") else U.wait(1) end
    end
    return false
  end
  local function callBall(textId)
    local handler = MapScripts.talkScript("OAKS_LAB", textId)
    local done = false
    if type(handler) == "function" then
      handler(game, game.overworld, nil, function() done = true end)
    elseif type(handler) == "table" then
      game.overworld.runner:run(handler, { onDone = function() done = true end })
    end
    return function() return done end
  end
  local function objectHidden(id)
    local map = game.save.objectToggles and game.save.objectToggles.OAKS_LAB
    return map and map[id] == false
  end
  local function rowIndex(rows, id)
    for index, row in ipairs(rows or {}) do
      if row.id == id then return index end
    end
  end

  local hero = tostring(os.getenv("LEGACY_HERO") or "BLUE"):upper()
  local heroPartners = {
    RED = "TORCHIC", BLUE = "MUDKIP", GREEN = "TREECKO",
  }
  local heroFlags = {
    RED = "EVENT_CHOSE_CHARMANDER",
    BLUE = "EVENT_CHOSE_SQUIRTLE",
    GREEN = "EVENT_CHOSE_BULBASAUR",
  }
  local expectedHeroPartner = assert(heroPartners[hero],
    "LEGACY_HERO must be RED, BLUE or GREEN")

  -- Keep the existing save and loader identity but make this run disposable,
  -- empty and explicitly Legacy-active. We start before Oak opens the choice
  -- so the untouched three-ball table can be captured first.
  game.save.party = {}
  game.save.inventory = {}
  game.save.pokedex = { seen = {}, owned = {} }
  game.save.flags = {}
  game.save.objectToggles = {}
  game.save.options.textSpeed = 1
  game.save.player.name = hero
  game.save.player.rival = hero == "BLUE" and "GREEN"
    or hero == "GREEN" and "RED" or "BLUE"
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant =
    game.save.modData.kanto_ascendant or {}
  game.save.modData.kanto_ascendant.legacy_journey = {
    version = 5, cycle = 65,
    runId = "legacy-partner-render-" .. hero:lower(), avatar = hero,
    bankUnlocked = true, wanderersEnabled = true,
  }
  characters.select(hero)
  starters.refresh(game)

  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  U.wait(30)
  check("real Oak's Lab loaded for an active Legacy run",
    game.overworld and game.overworld.map.id == "OAKS_LAB"
      and state() ~= nil)
  check("current hero maps the left ball to " .. expectedHeroPartner,
    starters.heroChoice(game.save).species == expectedHeroPartner)
  check("all three physical balls begin visible",
    not objectHidden("OAKSLAB_CHARMANDER_POKE_BALL")
      and not objectHidden("OAKSLAB_SQUIRTLE_POKE_BALL")
      and not objectHidden("OAKSLAB_BULBASAUR_POKE_BALL"))
  check("three-ball table screenshot",
    U.shot(game, dir .. "/01_three_balls_before_claim.png"))

  -- Open Oak's choice through the real composed map onEnter hook. The rival
  -- immediately claims the sealed right ball with the currently selected
  -- character's existing dialogue, while its species remains unresolved.
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  local labScripts = assert(MapScripts.get("OAKS_LAB"))
  labScripts.onEnter(game, game.overworld)
  local claimText = waitForText(900)
  check("early rival claim reaches its authored dialogue", claimText ~= nil)
  local claimLine = tostring(
    game.data.text._OaksLabRivalIllTakeThisOneText or "")
  if hero == "BLUE" then
    check("Blue hero uses Green's character-specific claim line",
      claimLine:find("suits", 1, true) ~= nil
        or claimLine:find("passt", 1, true) ~= nil)
  else
    check("rival claim line remains populated for the selected character",
      claimLine ~= "")
  end
  if claimText then
    check("character-specific rival claim screenshot",
      U.shot(game, dir .. "/02_rival_claim_dialogue.png"))
  end
  check("early rival claim completes in the real map",
    drainToOverworld(1200))
  check("right rival ball is physically hidden",
    objectHidden("OAKSLAB_BULBASAUR_POKE_BALL"))
  check("right-ball claim is durable state", state().rivalBallTaken == true
    and game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN == true)
  check("right-ball claim does not resolve a species",
    state().rivalPartner == nil and state().partnerSpecies == nil)
  check("two remaining balls after early claim screenshot",
    U.shot(game, dir .. "/03_right_ball_gone.png"))

  -- The left ball is a one-entry locked graphical catalogue for the current
  -- hero's exact Hoenn partner.
  local leftDone = callBall("TEXT_OAKSLAB_CHARMANDER_POKE_BALL")
  local left = waitFor(function()
    local top = game.stack:top()
    return isCatalog(top) and top or nil
  end, 300)
  check("left ball opens the same graphical catalogue", left ~= nil)
  check("left catalogue is locked to the hero's Hoenn partner",
    left and left.mode == "hoenn" and left.modeLocked == true
      and #left.rows == 1 and left:current().id == expectedHeroPartner)
  if left then
    check("left Hoenn partner screenshot",
      U.shot(game, dir .. "/04_left_hoenn_partner.png"))
    U.tap(game, "b")
  end
  check("left-ball cancel releases the lab interaction",
    waitFor(leftDone, 120) == true)
  check("left-ball cancel gives no partner", #game.save.party == 0
    and not state().partnerChosen and not game.save.flags.EVENT_GOT_STARTER)

  -- Middle ball opens Balanced by default. Prove physical L/R movement,
  -- then switch to Free and jump by the catalogue's own circular move API to
  -- the first Johto entry for a stable visual specimen.
  local middleDone = callBall("TEXT_OAKSLAB_SQUIRTLE_POKE_BALL")
  local catalog = waitFor(function()
    local top = game.stack:top()
    return isCatalog(top) and top or nil
  end, 300)
  check("middle ball opens the custom catalogue", catalog ~= nil)
  check("middle catalogue starts in Balanced Choice",
    catalog and catalog.mode == "balanced" and #catalog.rows > 0
      and #catalog.rows < #starters.partnerAllowlistOrder)
  if catalog then
    local first = catalog.index
    U.tap(game, "right")
    check("RIGHT advances the Balanced carousel", catalog.index ~= first)
    U.tap(game, "left")
    check("LEFT returns the Balanced carousel", catalog.index == first)
    check("Balanced Kanto entry screenshot",
      U.shot(game, dir .. "/05_catalog_balanced_kanto.png"))
    U.tap(game, "select")
    check("SELECT shows 118 base rows plus this hero's earned Hoenn row",
      catalog.mode == "free"
        and unmasteredOrder(catalog.rows, expectedHeroPartner)
        and starters.partnerAllowlist.GASTLY
        and starters.partnerAllowlist.DITTO
        and starters.partnerAllowlist.PICHU
        and not starters.partnerAllowlist.GENGAR
        and not starters.partnerAllowlist.DRAGONITE
        and not starters.partnerAllowlist.PIKACHU)
    catalog:move(assert(rowIndex(catalog.rows, "CHIKORITA")) - catalog.index)
    check("Free carousel reaches legal Johto base stage Chikorita",
      catalog:current().dex == 152
        and catalog:current().id == "CHIKORITA")
    check("Free Choice Johto entry screenshot",
      U.shot(game, dir .. "/06_catalog_free_johto.png"))
    U.tap(game, "b")
  end
  check("catalogue B cancel releases the lab interaction",
    waitFor(middleDone, 120) == true)
  check("catalogue B cancel sets no flags, Dex bits or Pokémon",
    #game.save.party == 0
      and countKeys(game.save.pokedex.seen) == 0
      and countKeys(game.save.pokedex.owned) == 0
      and not state().partnerChosen
      and not game.save.flags.EVENT_GOT_STARTER
      and not game.save.flags[heroFlags[hero]])
  check("catalogue B cancel leaves rival species unresolved",
    state().rivalPartner == nil)

  -- Reopen the exact same real middle-ball handler and commit Chikorita. Both
  -- confirmations default to NO and are captured separately.
  local finalDone = callBall("TEXT_OAKSLAB_SQUIRTLE_POKE_BALL")
  catalog = waitFor(function()
    local top = game.stack:top()
    return isCatalog(top) and top or nil
  end, 300)
  if catalog then
    U.tap(game, "select")
    catalog:move(assert(rowIndex(catalog.rows, "CHIKORITA")) - catalog.index)
    U.tap(game, "a")
  end
  local firstChoice = waitForChoice(900)
  check("first irreversible prompt is a default-NO choice",
    firstChoice and firstChoice.index == 2)
  if firstChoice then
    check("first confirmation screenshot",
      U.shot(game, dir .. "/07_first_confirmation.png"))
    chooseYes()
  end

  -- The final warning is exactly two lines, so the species and permanence
  -- warning remain visible when its independent YES/NO appears.
  local secondChoice = waitForChoice(600)
  check("second irreversible prompt is independently default-NO",
    secondChoice and secondChoice.index == 2)
  if secondChoice then
    check("final confirmation screenshot",
      U.shot(game, dir .. "/08_final_confirmation.png"))
    chooseYes()
  end

  local receipt = waitForText(900)
  check("final confirmation enters Oak's received-partner beat",
    receipt ~= nil)
  if receipt then
    check("received-partner screenshot",
      U.shot(game, dir .. "/09_received_chikorita.png"))
  end
  check("received-partner beat returns to the real lab",
    drainToOverworld(1200))

  local chosen = state()
  check("final state stores the exact Free Choice partner",
    chosen.partnerChosen == true and chosen.partnerSpecies == "CHIKORITA"
      and chosen.partnerMode == "free" and chosen.partnerBall == "catalog")
  check("rival line resolves only after final confirmation",
    type(chosen.rivalPartner) == "table"
      and chosen.rivalPartner.sourcePartner == "CHIKORITA")
  check("only the chosen partner enters the party",
    #game.save.party == 1 and game.save.party[1].species == "CHIKORITA")
  check("only the chosen partner receives seen/owned Dex bits",
    countKeys(game.save.pokedex.seen) == 1
      and countKeys(game.save.pokedex.owned) == 1
      and game.save.pokedex.seen.CHIKORITA == true
      and game.save.pokedex.owned.CHIKORITA == true)
  check("no Sinnoh species or flags leak into final state",
    game.save.pokedex.seen.TURTWIG == nil
      and game.save.pokedex.owned.TURTWIG == nil
      and game.save.flags.EVENT_CHOSE_PIKACHU == nil)
  check("middle and right balls are gone; unchosen left ball remains",
    objectHidden("OAKSLAB_SQUIRTLE_POKE_BALL")
      and objectHidden("OAKSLAB_BULBASAUR_POKE_BALL")
      and not objectHidden("OAKSLAB_CHARMANDER_POKE_BALL"))
  check("final Oak's Lab state screenshot",
    U.shot(game, dir .. "/10_final_lab_state.png"))
  check("final interaction callback runs exactly once",
    waitFor(finalDone, 60) == true)

  U.log(("LEGACY PARTNER VISUAL RESULT hero=%s pass=%d fail=%d")
    :format(hero, pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
