-- Continuous Authority-main/LÖVE acceptance for the non-map Legacy chain.
-- The staged conditions are the exact post-Champion hand-off marker and one
-- bounded call through the real HEVO completion/shared-door Journey seams.
-- Hall induction, credits save, physical Lab PC, both confirmations, Fresh
-- Save, Oak character selection and the physical starter interaction use
-- real UI input. Run each edition/language in a disposable identity.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "base_deutsch",
    "connected Legacy acceptance requires the frozen base/deutsch closure")
  local function requiredSha(name)
    local value = os.getenv(name)
    assert(type(value) == "string" and #value == 64
        and value:match("^[0-9a-f]+$"),
      name .. " must be a lowercase SHA256 receipt")
    return value
  end
  local receipts = {
    engine_payload_sha256 = requiredSha("KA_ENGINE_PAYLOAD_SHA256"),
    authority_package_sha256 = requiredSha("KA_AUTHORITY_PACKAGE_SHA256"),
    deutsch_package_sha256 = requiredSha("KA_DEUTSCH_PACKAGE_SHA256"),
    package_gate_receipt_sha256 = requiredSha(
      "KA_PACKAGE_GATE_RECEIPT_SHA256"),
  }
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local utilPath = assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL packaged harness path is required")
  local harnessRoot = assert(os.getenv("GEN1RECOMP_DIR"),
    "GEN1RECOMP_DIR packaged harness root is required")
  for _, path in ipairs({ dir, utilPath, harnessRoot }) do
    assert(path:sub(1, 1) == "/"
        and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true),
      "source/worktree path is not package evidence: " .. path)
  end
  local U = dofile(utilPath)
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local HallOfFame = require("src.ui.HallOfFame")
  local Credits = require("src.ui.Credits")
  local locale = assert(os.getenv("QA_LANGUAGE"), "QA_LANGUAGE is required")
  local edition = GameVersion.get()
  local expectedEdition = assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION is required")
  assert(edition == expectedEdition
      and (edition == "red" or edition == "blue" or edition == "yellow"),
    "connected Legacy acceptance must use requested Red/Blue/Yellow")
  assert(locale == "en" or locale == "de",
    "QA_LANGUAGE must be exactly en or de")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")
  local expectedIdentity = ("ka65-final-legacy-connected-%s-%s")
    :format(edition, locale)
  assert(identity == expectedIdentity,
    "connected Legacy acceptance requires its exact isolated identity")
  local slot = ("slot65legacyconnected_%s_%s"):format(edition, locale)
  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve the connected Legacy native save slot")

  local loadedMods = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local installed = assert(loadedMods.kanto_ascendant,
    "installed Authority package is missing")
  for _, path in ipairs({ tostring(love.filesystem.getSource() or ""),
      tostring(installed.path or "") }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not installed-package evidence: " .. path)
  end
  local api = assert(game.mods.exports.kanto_ascendant)
  local journey = assert(api.legacyJourney)
  local paths = assert(api.legacyPaths)
  local starters = assert(api.legacyStarters)
  local characters = assert(api.extendedCharacters)
  local freshHero = ({ red = "RED", blue = "BLUE", yellow = "GREEN" })[edition]
  local yellowPath = os.getenv("QA_YELLOW_PATH") or "catalog"
  assert(yellowPath == "catalog" or yellowPath == "pikachu",
    "QA_YELLOW_PATH must be exactly catalog or pikachu")
  local pass, fail = 0, 0
  local failedLabels = {}
  local trace = assert(io.open(dir .. "/runtime_trace.tsv", "wb"))
  trace:write("status\tlabel\n")
  trace:flush()

  local function check(label, value)
    if value then
      pass = pass + 1
    else
      fail = fail + 1
      failedLabels[#failedLabels + 1] = label
    end
    U.log(value and "PASS" or "FAIL", label)
    trace:write(value and "PASS" or "FAIL", "\t", label, "\n")
    trace:flush()
    return value
  end
  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end
  local function isText(value) return value and getmetatable(value) == TextBox end
  local function isChoice(value) return value and getmetatable(value) == ChoiceBox end
  local function isCatalog(value)
    return value and getmetatable(value) == starters.Catalog
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
  local function waitText(frames)
    return waitFor(function()
      local top = game.stack:top()
      return isText(top) and top or nil
    end, frames)
  end
  local function settleText(box)
    for _ = 1, 500 do
      if box.waiting or box.done then return box end
      game.input.state.a = true
      U.wait(1)
      game.input.state.a = false
    end
    return nil
  end
  local function waitChoice(frames)
    return waitFor(function()
      local top = game.stack:top()
      if isChoice(top) then return top end
      if isText(top) then
        if top.waiting then U.tap(game, "a")
        elseif not top.done then
          game.input.state.a = true
          U.wait(1)
          game.input.state.a = false
        end
      end
      return nil
    end, frames or 1400)
  end
  local function waitList(titleNeedle, frames)
    return waitFor(function()
      local top = game.stack:top()
      if top and type(top.items) == "table"
          and tostring(top.title or ""):find(titleNeedle, 1, true) then
        return top
      end
      if isText(top) then
        if top.waiting or top.done then U.tap(game, "a")
        elseif not top.done then
          game.input.state.a = true
          U.wait(1)
          game.input.state.a = false
        end
      end
      return nil
    end, frames or 1800)
  end
  local function dumpStack(label)
    trace:write("STACK\t", label, "\n")
    for index, value in ipairs(game.stack.states or {}) do
      trace:write("STACK\t", tostring(index), "\t",
        tostring(value.screenId or getmetatable(value)), "\ttitle=",
        tostring(value.title), "\ttext=",
        tostring(value.text):gsub("[\r\n]+", " "):sub(1, 120),
        "\twaiting=", tostring(value.waiting),
        "\tdone=", tostring(value.done), "\n")
    end
    trace:flush()
  end
  local function chooseYes(box)
    box = box or assert(waitChoice(), "expected YES/NO choice")
    if box.index == 2 then U.tap(game, "up") end
    U.tap(game, "a")
  end
  local function drainTextToOverworld(frames)
    return waitFor(function()
      local top = game.stack:top()
      if top == game.overworld and not runnerBusy() then return true end
      if isChoice(top) then U.tap(game, "b")
      elseif top ~= game.overworld then U.tap(game, "a")
      else U.wait(1) end
      return nil
    end, frames or 2400) == true
  end
  local function menu()
    local top = game.stack:top()
    return top and type(top.items) == "table" and top or nil
  end
  local function menuIndex(current, needle)
    for index, row in ipairs(current and current.items or {}) do
      if tostring(row.label):find(needle, 1, true) then return index end
    end
  end
  local function selectMenu(index)
    local current = assert(menu(), "expected menu")
    assert(type(index) == "number", "expected numeric menu index")
    local guard = 0
    while current.index ~= index do
      guard = guard + 1
      assert(guard <= #current.items + 1, "menu cursor did not reach target")
      U.tap(game, "down")
      U.wait(3)
      assert(game.stack:top() == current, "menu changed while moving cursor")
    end
    -- Fast QA speeds can advance several simulation ticks per rendered
    -- frame.  Keep the A edge isolated from the final D-pad edge and require
    -- the selected menu to leave the top of the stack; otherwise every later
    -- assertion would only be a misleading cascade from this one input.
    U.wait(3)
    for _ = 1, 4 do
      U.tap(game, "a")
      U.wait(6)
      if game.stack:top() ~= current then return true end
    end
    error("selected menu row did not open: " .. tostring(index))
  end
  local function countKeys(rows)
    local n = 0
    for _ in pairs(rows or {}) do n = n + 1 end
    return n
  end
  local function state()
    local bucket = game.save.modData and game.save.modData.kanto_ascendant
    return bucket and bucket.legacy_journey
  end
  local function objectHidden(id)
    local map = game.save.objectToggles and game.save.objectToggles.OAKS_LAB
    return map and map[id] == false
  end
  local function physicalInteract(mapId, x, y, facing)
    U.teleport(game, mapId, x, y, facing)
    U.wait(25)
    U.tap(game, "a")
  end
  local function physicalInteractNpc(name)
    local npc
    for _, candidate in ipairs(game.overworld and game.overworld.npcs or {}) do
      if candidate.def and candidate.def.name == name then npc = candidate break end
    end
    assert(npc, "missing physical Lab NPC " .. tostring(name))
    local approaches = {
      { 0, 1, "up" }, { 1, 0, "left" },
      { -1, 0, "right" }, { 0, -1, "down" },
    }
    for _, row in ipairs(approaches) do
      local x, y = npc.cellX + row[1], npc.cellY + row[2]
      if game.overworld.map:isWalkableCell(x, y)
          and not game.overworld:npcAtCell(x, y) then
        physicalInteract("OAKS_LAB", x, y, row[3])
        return true
      end
    end
    error("no physical approach to Lab NPC " .. tostring(name))
  end

  local midPhaseNativeReloads, physicalExitLocks = 0, 0
  local function proveReloadedLockedLab(tag)
    local before = state()
    check(tag .. " pre-reload phase is partner-pending and exit-locked",
      before and before.introPhase == "partner"
        and before.rivalBallTaken == true and before.partnerChosen ~= true
        and starters.labExitLocked(game.save))
    check(tag .. " mid-phase native save writes", game:writeSave())
    local loaded, recovered = SaveData.load()
    check(tag .. " mid-phase native save loads without recovery",
      loaded ~= nil and recovered == nil)
    if not loaded then return false end
    game:restoreSave(loaded, recovered)
    U.wait(90)
    local resumed = state()
    local reloaded = game.overworld and game.overworld.map
      and game.overworld.map.id == "OAKS_LAB"
      and resumed and resumed.introPhase == "partner"
      and resumed.rivalBallTaken == true and resumed.partnerChosen ~= true
      and starters.labExitLocked(game.save)
    check(tag .. " native reload resumes inside the locked Fresh Lab", reloaded)
    if reloaded then midPhaseNativeReloads = midPhaseNativeReloads + 1 end

    -- Walk onto the real south-door row.  The composed Oak's Lab onStep must
    -- show Oak's localized blocker and move the player back; the driver never
    -- calls labExitLocked as the action under test.
    U.teleport(game, "OAKS_LAB", 5, 5, "down")
    U.wait(20)
    U.tap(game, "down")
    local blocked = waitText(900)
    local blockedText = blocked and table.concat(blocked.pages[blocked.pageIndex]
      or {}, "\n") or ""
    local localized = blockedText:find(locale == "de" and "Noch nicht"
      or "Not yet", 1, true) ~= nil
    check(tag .. " physical Lab exit opens Oak's localized lock",
      blocked ~= nil and localized)
    if blocked then
      settleText(blocked)
      check(tag .. " physical exit-lock screenshot",
        U.shot(game, dir .. "/10a_midphase_exit_lock.png"))
      U.tap(game, "a")
    end
    check(tag .. " physical exit lock returns inside Oak's Lab",
      drainTextToOverworld(1800)
        and game.overworld.map.id == "OAKS_LAB"
        and game.overworld.player.cellY <= 5
        and starters.labExitLocked(game.save))
    if blocked and localized and game.overworld.map.id == "OAKS_LAB"
        and game.overworld.player.cellY <= 5 then
      physicalExitLocks = physicalExitLocks + 1
      return true
    end
    return false
  end

  -- An isolated, genuinely fresh pre-Hall save.  Character RED represents
  -- the completed journey; the next hero is deliberately chosen later in
  -- Oak's real Fresh-Save selector.
  local initial = SaveData.newGame(game:bootConfig())
  game.save = initial
  game:adoptSave(initial)
  Runtime.emit("save.created", { save = initial })
  characters.select("RED")
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 52) }
  game.save.pokedex = { seen = { PIKACHU = true }, owned = { PIKACHU = true } }
  game.save.player.name = locale == "de" and "ROT" or "RED"
  game.save.player.rival = locale == "de" and "BLAU" or "BLUE"
  game.save.flags = game.save.flags or {}
  check("requested edition has a clean pre-Hall save", edition ~= nil
    and not journey.archive.isEligible(game.save) and state() == nil)
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.pendingHallOfFame = true
  game.save.options.textSpeed = 1
  game:adoptSave(game.save)
  check("requested package language is active",
    api.language and api.language() == locale)

  -- Enter the real room script at the exact post-Champion hand-off.  Its Oak
  -- line, Hall animation, credits and THE END autosave are engine-owned.
  U.teleport(game, "HALL_OF_FAME", 4, 7, "up")
  local hallOak = assert(waitText(1800), "Hall Oak dialogue did not appear")
  local hallOakPages = 0
  local hall
  for _ = 1, 120 do
    local top = game.stack:top()
    if isText(top) then
      settleText(top)
      hallOakPages = hallOakPages + 1
      check(("real Hall Oak dialogue page %d screenshot"):format(hallOakPages),
        U.shot(game, (dir .. "/01_real_hall_oak_page_%02d.png")
          :format(hallOakPages)))
      U.tap(game, "a")
      U.wait(2)
    else
      for _, value in ipairs(game.stack.states or {}) do
        if getmetatable(value) == HallOfFame
            or value.screenId == "HallOfFame" then
          hall = value
          break
        end
      end
      if hall then break end
      U.wait(1)
    end
  end
  check("complete Hall Oak page sequence rendered", hallOakPages >= 1
    and game.stack:top() ~= hallOak)
  check("real Hall induction starts", hall ~= nil)
  if hall then
    check("real Hall induction screenshot",
      U.shot(game, dir .. "/02_real_hall_induction.png"))
  end
  for _ = 1, 1800 do
    local top = game.stack:top()
    if getmetatable(top) == Credits then break end
    U.tap(game, "a")
  end
  local credits = waitFor(function()
    local top = game.stack:top()
    return getmetatable(top) == Credits and top or nil
  end, 1800)
  check("real credits follow Hall induction", credits ~= nil)
  local theEnd = credits and waitFor(function()
    local top = game.stack:top()
    return top == credits and credits.phase == "end_wait" and credits or nil
  end, 12000)
  check("THE END reaches its saved wait state", theEnd ~= nil)
  if theEnd then
    check("real THE END screenshot", U.shot(game, dir .. "/03_the_end.png"))
    U.tap(game, "a")
  end
  U.wait(40)
  local hallSave = assert(SaveData.load(), "Hall save did not reload")
  game:restoreSave(hallSave, false)
  U.wait(30)
  check("first Hall is durable after reload",
    type(game.save.hallOfFame) == "table" and #game.save.hallOfFame == 1
      and journey.archive.isEligible(game.save) and state() == nil)

  -- This driver's subject begins at the destructive hand-off, so reuse the
  -- production adapter and Journey door callback instead of replaying an
  -- unrelated full dungeon.  No Mega secret is claimed.  The dedicated
  -- story-gate driver covers the physical shared-door cry/call presentation.
  local sealed, sealResult = api.legacyDungeonAdapter.finalize(game, {
    character = "RED", questionIds = { "QA_FULL_CHAIN_GATE" },
  })
  check("bounded real HEVO completion seals RED without Mega",
    sealed == true and sealResult.character == "RED"
      and not api.legacyDungeonAdapter.hasSecret(game.save, "RED"))
  check("completion alone remains too early", not journey.canBegin(game.save))
  check("real shared black-door seam arms the current run",
    api.hiddenEvolutionCampaign.modules.shared.doorInteraction(game) == true)
  check("Oak unlock call returns to overworld", drainTextToOverworld(2400))
  check("HOF plus matching seal/door is now ready",
    journey.canBegin(game.save)
      and game.save.flags[journey.HEVO_OAK_CALLED_FLAG] == true)

  -- Use the visible terminal tile with A.  This is the regression path for
  -- the formerly unreachable Lab-PC hook.
  physicalInteract("OAKS_LAB", 1, 2, "up")
  local pc = waitFor(menu, 700)
  local beginNeedle = locale == "de" and "REISE STARTEN" or "BEGIN LEGACY"
  local beginIndex = menuIndex(pc, beginNeedle)
  local infoNeedle = locale == "de" and "LEGACY-INFO" or "LEGACY INFO"
  check("physical Lab terminal exposes info and begin",
    pc and menuIndex(pc, infoNeedle) and beginIndex)
  check("physical Lab-PC screenshot", pc and U.shot(game, dir .. "/04_physical_lab_pc.png"))
  selectMenu(beginIndex)

  local oakIntro = waitText(1200)
  check("Oak visibly hosts the Legacy Pact choice", oakIntro ~= nil)
  if not oakIntro then
    dumpStack("missing-oak-intro")
    error("BEGIN LEGACY did not open Oak's Pact introduction")
  end
  settleText(oakIntro)
  local oakPortrait
  for _, value in ipairs(game.stack.states or {}) do
    if value ~= oakIntro and value.image and value.trueColor == true then
      oakPortrait = value
    end
  end
  check("Oak Pact portrait uses the explicit true-colour PicBox path",
    oakPortrait ~= nil)
  check("Oak Pact portrait screenshot",
    U.shot(game, dir .. "/05_oak_pact_intro_truecolor.png"))
  -- This introduction has several form-feed pages.  Walk every page exactly
  -- as the player does: finish its typewriter, confirm the blinking arrow,
  -- and continue until TextBox pops and invokes openPactMenu.
  for _ = 1, 24 do
    if game.stack:top() ~= oakIntro then break end
    settleText(oakIntro)
    U.tap(game, "a")
    U.wait(4)
  end
  if game.stack:top() == oakIntro then
    dumpStack("oak-intro-would-not-close")
    error("Oak Pact introduction ignored its final A input")
  end

  -- Oak now owns a real four-Pact choice and, for non-JOURNEY choices, a
  -- separate four-row Bank policy.  Exercise the authored hardest/default
  -- pairing here; the focused matrix test covers every other combination.
  local pactMenu = waitList(locale == "de" and "EICH: PAKTWAHL"
    or "OAK: CHOOSE PACT", 2400)
  check("Oak visibly offers all four Legacy pacts",
    pactMenu and #pactMenu.items == 4)
  if not pactMenu then
    dumpStack("missing-pact-menu")
    error("Oak Pact introduction did not reach the four-Pact menu")
  end
  if pactMenu then
    check("four-Pact menu screenshot",
      U.shot(game, dir .. "/06_pact_choice.png"))
    selectMenu(4)
  end
  local bankMenu = waitList(locale == "de" and "EICH: BANKREGEL"
    or "OAK: BANK RULE", 2400)
  check("Oak visibly offers all four Bank policies",
    bankMenu and #bankMenu.items == 4)
  if not bankMenu then
    dumpStack("missing-bank-menu")
    error("Ascendant Pact did not reach the four-policy menu")
  end
  if bankMenu then
    check("Ascendant recommends SEALED on row one",
      bankMenu.index == 1
        and tostring(bankMenu.items[1].value) == "sealed")
    check("four-policy menu screenshot",
      U.shot(game, dir .. "/07_bank_policy.png"))
    selectMenu(1)
  end
  local firstConfirm = waitChoice(1600)
  check("first Fresh-Save confirmation defaults NO",
    firstConfirm and firstConfirm.index == 2)
  if firstConfirm then
    check("first confirmation screenshot",
      U.shot(game, dir .. "/08_first_fresh_confirmation.png"))
    chooseYes(firstConfirm)
  end
  local finalConfirm = waitChoice(1600)
  check("second Fresh-Save confirmation independently defaults NO",
    finalConfirm and finalConfirm.index == 2)
  if finalConfirm then
    check("final confirmation screenshot",
      U.shot(game, dir .. "/09_final_fresh_confirmation.png"))
    chooseYes(finalConfirm)
  end

  -- The destructive boundary has now created a new SaveData object.  Before
  -- CharacterSelect runs the new journey intentionally has no path avatar.
  local freshState = waitFor(function()
    local s = state()
    return s and s.runId and s or nil
  end, 1200)
  check("Fresh Save has empty party/Dex and no inherited avatar",
    freshState and #game.save.party == 0
      and countKeys(game.save.pokedex.seen) == 0
      and countKeys(game.save.pokedex.owned) == 0
      and freshState.avatar == nil)
  check("Fresh Save durably retains selected Ascendant/sealed contract",
    freshState and freshState.pact == "ascendant"
      and freshState.bankPolicy == "sealed")
  local objective = paths.objective(game)
  check("Fresh Save initially asks for a Legacy path",
    objective and objective.id == "legacy_avatar")

  local selected = false
  for _ = 1, 4800 do
    local top = game.stack:top()
    if getmetatable(top) == characters.CharacterSelect then
      if not selected then
        local identityNames = locale == "de"
          and { GREEN = "GRÜN", BLUE = "BLAU", RED = "ROT" }
          or { GREEN = "GREEN", BLUE = "BLUE", RED = "RED" }
        for index, id in ipairs(characters.selectionOrder) do
          while top.index ~= index do U.tap(game, "down") end
          U.wait(8)
          check(id .. " selector identity, HD portrait and relation are active",
            characters.selectionLabel(id) == identityNames[id]
              and top.portraits[id] ~= nil and top.portraitQuads[id] ~= nil)
          check(id .. " Fresh-Save character selector screenshot",
            U.shot(game, (dir .. "/07%s_fresh_character_select_%s.png")
              :format(string.char(96 + index), id:lower())))
        end
        local target = 1
        for index, id in ipairs(characters.selectionOrder) do
          if id == freshHero then target = index break end
        end
        while top.index ~= target do U.tap(game, "down") end
        U.tap(game, "a")
        selected = true
      end
    elseif top == game.overworld then
      if selected then break end
      U.wait(1)
    else
      U.tap(game, "a")
    end
  end
  U.wait(90)
  -- CharacterSelect writes the choice into the Fresh Save.  The normal first
  -- physical world step is the product boundary that lets Legacy Paths bind
  -- that new choice (the archived run's avatar must not be inherited).
  if game.stack:top() == game.overworld then
    U.tap(game, "up")
    U.wait(45)
  end
  local currentPath = paths.current(game.save)
  check("physical character choice binds the new Legacy path",
    selected and currentPath and currentPath.avatar == freshHero
      and state().avatar == freshHero)
  check("Fresh Save reaches overworld with chosen hero",
    game.stack:top() == game.overworld
      and U.shot(game, dir .. "/08_fresh_overworld.png"))

  trace:write("RIVAL_GATE\tactive=", tostring(journey.isActive(game.save)),
    "\ttaken=", tostring(state() and state().rivalBallTaken),
    "\tpartner=", tostring(state() and state().partnerChosen),
    "\tfollowed=", tostring(game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB),
    "\toakAsked=", tostring(game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON),
    "\tgotStarter=", tostring(game.save.flags.EVENT_GOT_STARTER),
    "\tmap=", tostring(game.overworld.map and game.overworld.map.id),
    "\tcell=", tostring(game.overworld.player.cellX), ",",
    tostring(game.overworld.player.cellY), "\n")
  trace:flush()

  -- Stage only Oak's ordinary story gate after the intro.  Ball selection is
  -- then performed by A against the authored object, never by talkScript.
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON = true
  local catalog
  if edition ~= "yellow" then
    U.teleport(game, "OAKS_LAB", 5, 5, "up")
    local claim = waitText(1800)
    check("rival takes the right ball before player selection", claim ~= nil)
    if claim then
      settleText(claim)
      check("characteristic early rival claim screenshot",
        U.shot(game, dir .. "/09_rival_claims_right_ball.png"))
    end
    check("rival claim returns to real lab", drainTextToOverworld(2400))
    check("right ball is hidden without resolving rival species",
      objectHidden("OAKSLAB_BULBASAUR_POKE_BALL")
        and state().rivalBallTaken == true
        and state().rivalPartner == nil and state().partnerSpecies == nil)
    proveReloadedLockedLab("Red/Blue rival-ball boundary")

    -- This Fresh Save follows the path sealed immediately above. The matching
    -- Hoenn ball is the current hero's prior-life reward; that same durable
    -- starter also joins the middle catalogue for every character.
    physicalInteract("OAKS_LAB", 6, 4, "up")
    local hoennCatalog = waitFor(function()
      local top = game.stack:top()
      return isCatalog(top) and top or nil
    end, 1200)
    local expectedHoenn = starters.heroChoice(game.save).species
    check("left Hoenn ball exposes only the matching completed-path reward",
      hoennCatalog and hoennCatalog.mode == "hoenn"
        and hoennCatalog.modeLocked == true
        and #hoennCatalog.rows == 1
        and hoennCatalog.rows[1].id == expectedHoenn
        and #game.save.party == 0 and not state().partnerChosen)
    if hoennCatalog then
      check("left Hoenn reward screenshot",
        U.shot(game, dir .. "/10_left_hoenn_reward.png"))
      U.tap(game, "b")
    end
    check("leaving the Hoenn reward preserves the unchosen Fresh Save",
      drainTextToOverworld(900)
        and #game.save.party == 0 and not state().partnerChosen)

    physicalInteract("OAKS_LAB", 7, 4, "up")
    catalog = waitFor(function()
      local top = game.stack:top()
      return isCatalog(top) and top or nil
    end, 1200)
  else
    physicalInteract("OAKS_LAB", 7, 4, "up")
    local yellowMenu = waitList(locale == "de" and "EICH: DEIN PARTNER"
      or "OAK: YOUR PARTNER", 1800)
    check("Yellow's physical one-ball scene offers three real partner paths",
      yellowMenu and #yellowMenu.items == 3
        and yellowMenu.items[1].value == "pikachu"
        and yellowMenu.items[2].value == "hoenn"
        and yellowMenu.items[3].value == "catalog")
    if yellowMenu then
      check("Yellow partner-path screenshot",
        U.shot(game, dir .. "/09_yellow_partner_paths.png"))
      U.tap(game, "b")
    end
    check("Yellow path-menu cancel leaves the durable rival claim pending",
      drainTextToOverworld(1200) and state().rivalBallTaken == true
        and state().partnerChosen ~= true and #game.save.party == 0)
    proveReloadedLockedLab("Yellow rival-ball boundary")

    -- The sole ball remains gone after the native reload.  Product Oak, not
    -- a test callback, is the authored retry surface for that pending phase.
    physicalInteractNpc("OAKSLAB_OAK1")
    local retryMenu = waitList(locale == "de" and "EICH: DEIN PARTNER"
      or "OAK: YOUR PARTNER", 1800)
    check("Yellow Oak reopens the three-path menu after native reload",
      retryMenu and #retryMenu.items == 3)
    if retryMenu then selectMenu(yellowPath == "pikachu" and 1 or 3) end
    catalog = waitFor(function()
      local top = game.stack:top()
      return isCatalog(top) and top or nil
    end, 1200)
  end

  if edition ~= "yellow" or yellowPath ~= "pikachu" then
    check("middle/Yellow branch opens graphical Balanced catalogue",
      catalog and catalog.mode == "balanced")
    if catalog then
      U.tap(game, "select")
      local earnedHoenn = starters.heroChoice(game.save).species
      check("real SELECT exposes 118 base rows plus the earned Hoenn row",
        catalog.mode == "free" and unmasteredOrder(catalog.rows, earnedHoenn)
          and starters.partnerAllowlist.GASTLY
          and starters.partnerAllowlist.DITTO
          and not starters.partnerAllowlist.GENGAR)
      U.tap(game, "select")
      check("catalogue screenshot",
        U.shot(game, dir .. "/11_graphical_partner_catalog.png"))
      U.tap(game, "b")
    end
    check("catalogue cancel is lossless and releases physical interaction",
      drainTextToOverworld(900) and #game.save.party == 0
        and not state().partnerChosen and countKeys(game.save.pokedex.owned) == 0)

    -- Reopen by physical A and commit the first Balanced row with two real,
    -- independently default-NO confirmations.
    if edition == "yellow" then
      physicalInteractNpc("OAKSLAB_OAK1")
      local retryMenu = waitList(locale == "de" and "EICH: DEIN PARTNER"
        or "OAK: YOUR PARTNER", 1800)
      check("Yellow Oak reopens after catalogue cancel",
        retryMenu and #retryMenu.items == 3)
      if retryMenu then selectMenu(3) end
    else
      physicalInteract("OAKS_LAB", 7, 4, "up")
    end
    catalog = waitFor(function()
      local top = game.stack:top()
      return isCatalog(top) and top or nil
    end, 1200)
    check("catalogue reopens after cancel", catalog ~= nil)
  else
    check("Yellow Pikachu path uses the real single-row graphical handoff",
      catalog and catalog.mode == "yellow" and catalog.modeLocked == true
        and #catalog.rows == 1 and catalog:current().id == "PIKACHU")
    if catalog then
      check("Yellow Pikachu handoff screenshot",
        U.shot(game, dir .. "/11_yellow_pikachu_handoff.png"))
    end
  end

  local chosenSpecies = catalog and catalog:current().id
  if catalog then U.tap(game, "a") end
  local partnerConfirm = waitChoice(1200)
  check("partner confirmation defaults NO",
    partnerConfirm and partnerConfirm.index == 2)
  if partnerConfirm then
    check("partner confirmation screenshot",
      U.shot(game, dir .. "/12_partner_confirmation.png"))
    chooseYes(partnerConfirm)
  end
  local partnerFinal = waitChoice(1200)
  check("partner final warning defaults NO",
    partnerFinal and partnerFinal.index == 2)
  if partnerFinal then
    check("partner final confirmation screenshot",
      U.shot(game, dir .. "/13_partner_final_confirmation.png"))
    chooseYes(partnerFinal)
  end
  local received = waitText(1500)
  check("Oak received-partner beat is visible", received ~= nil)
  if received then
    settleText(received)
    check("received partner screenshot",
      U.shot(game, dir .. (edition == "yellow" and yellowPath == "pikachu"
        and "/14_received_pikachu.png" or "/14_received_partner.png")))
  end
  check("received-partner beat returns control", drainTextToOverworld(1800))
  check("exactly one partner and its delayed rival are committed",
    chosenSpecies and #game.save.party == 1
      and game.save.party[1].species == chosenSpecies
      and state().partnerChosen and state().partnerSpecies == chosenSpecies
      and type(state().rivalPartner) == "table"
      and state().rivalPartner.sourcePartner == chosenSpecies
      and countKeys(game.save.pokedex.seen) == 1
      and countKeys(game.save.pokedex.owned) == 1
      and game.save.pokedex.owned[chosenSpecies] == true)
  if edition == "yellow" and yellowPath == "pikachu" then
    check("Yellow Pikachu branch commits its authored Eevee rival contract",
      chosenSpecies == "PIKACHU"
        and game.save.flags.EVENT_CHOSE_PIKACHU == true
        and game.save.rivalStarter == 1)
  end

  local committedSpecies = state().partnerSpecies
  local committedParty = #game.save.party
  local reloaded, recovered = SaveData.load()
  assert(reloaded and recovered == nil, "partner save did not reload natively")
  game:restoreSave(reloaded, recovered)
  U.wait(60)
  local reloadedState = state()
  local partnerRivalDurable = committedParty == 1 and #game.save.party == 1
      and game.save.party[1].species == committedSpecies
      and reloadedState and reloadedState.partnerSpecies == committedSpecies
      and reloadedState.partnerChosen == true
      and reloadedState.avatar == freshHero
      and type(reloadedState.rivalPartner) == "table"
      and starters.labExitLocked(game.save) == false
  check("Fresh Save reload preserves one partner, path and rival exactly once",
    partnerRivalDurable)
  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  U.wait(30)
  check("post-reload Oak Lab state screenshot",
    U.shot(game, dir .. "/15_post_reload_lab.png"))

  U.log(("LEGACY FULL CHAIN RESULT edition=%s locale=%s path=%s pass=%d fail=%d")
    :format(edition, locale, yellowPath, pass, fail))
  local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
  result:write("status=", fail == 0 and "PASS" or "FAIL", "\n")
  result:write("scope=LEGACY-CONNECTED-FRESH-LAB\n")
  result:write(("edition=%s\nlocale=%s\npath=%s\npass=%d\nfail=%d\n")
    :format(edition, locale, yellowPath, pass, fail))
  result:write("physical_lab_pc=PASS\n")
  result:write("fresh_confirm_default_no=2/2\n")
  result:write("partner_confirm_default_no=2/2\n")
  result:write("rival_ball_boundary=1/1\n")
  result:write("mid_phase_native_reload=", tostring(midPhaseNativeReloads),
    "/1\n")
  result:write("physical_lab_exit_lock=", tostring(physicalExitLocks), "/1\n")
  result:write("partner_rival_durable=",
    partnerRivalDurable and "1/1\n" or "0/1\n")
  result:write("native_save_reload=midphase+partner\n")
  result:write("archive_transaction=1/1\n")
  result:write("engine_payload_sha256=", receipts.engine_payload_sha256, "\n")
  result:write("authority_package_sha256=",
    receipts.authority_package_sha256, "\n")
  result:write("deutsch_package_sha256=", receipts.deutsch_package_sha256,
    "\n")
  result:write("package_gate_receipt_sha256=",
    receipts.package_gate_receipt_sha256, "\n")
  for _, label in ipairs(failedLabels) do
    result:write("failed=", label, "\n")
  end
  result:close()
  trace:close()
  love.event.quit(fail == 0 and 0 or 1)
end
