-- Isolated real-battle visual proof for RC65-ESPEON-PSYBEAM.
--
-- Unlike tools/espeon_psybeam_love_qa_driver.lua, this additive probe never
-- uses Rare Candy or the Route-5 Move Reminder.  It starts Espeon at level 35
-- with exactly one EXP point left to level 36, enters a real wild BattleState,
-- selects FIGHT and natural slot-3 QUICK_ATTACK with ordinary controller
-- input, and lets the
-- production KO -> awardExp -> level-up -> MoveLearnMenu path teach PSYBEAM.
-- No battle message, queue row, level, result, or learned move is injected.
--
-- Run once per edition in a fresh, non-planned identity:
--   POKEPORT_VERSION=red|blue|yellow
--   POKEPORT_IDENTITY=ka65-probe-espeon-battle-exp-<edition>-20260813-03
--   POKEPORT_DRIVER=<absolute path to this file>
--   KA_TEST_UTIL=<absolute engine tests/drivers/util.lua>
--   KA_ESPEON_BATTLE_OUTPUT_DIR=<fresh existing absolute directory>
--
-- The output directory receives a FAIL receipt before any game mutation or
-- input.  PASS is promoted only after all four non-empty PNGs and native
-- save/reload verification exist.

local SCHEMA = "ka-espeon-battle-exp-visual/v1"
local IDENTITIES = {
  red = "ka65-probe-espeon-battle-exp-red-20260813-03",
  blue = "ka65-probe-espeon-battle-exp-blue-20260813-03",
  yellow = "ka65-probe-espeon-battle-exp-yellow-20260813-03",
}

local function envRequired(name)
  local value = os.getenv(name)
  assert(type(value) == "string" and value ~= "", name .. " is required")
  return value
end

local EDITION = envRequired("POKEPORT_VERSION"):lower()
local EXPECTED_IDENTITY = assert(IDENTITIES[EDITION],
  "POKEPORT_VERSION must be red, blue, or yellow")
local OUTPUT_DIR = envRequired("KA_ESPEON_BATTLE_OUTPUT_DIR")
assert(OUTPUT_DIR:sub(1, 1) == "/"
    and not OUTPUT_DIR:find("/../", 1, true)
    and OUTPUT_DIR:sub(-3) ~= "/..",
  "KA_ESPEON_BATTLE_OUTPUT_DIR must be a normalized absolute path")

local RESULT_PATH = OUTPUT_DIR .. "/driver_result.txt"
local SCREENSHOTS = {
  exp = OUTPUT_DIR .. "/01_battle_exp_gained.png",
  level = OUTPUT_DIR .. "/02_grew_level36.png",
  offer = OUTPUT_DIR .. "/03_psybeam_offer.png",
  learned = OUTPUT_DIR .. "/04_psybeam_learned.png",
}

local function fileExists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  file:close()
  return true
end

-- Refuse stale output.  The host must provide a new evidence directory for
-- every edition/run, just as it must provide the exact fresh identity above.
assert(not fileExists(RESULT_PATH), "driver_result.txt already exists")
for _, path in pairs(SCREENSHOTS) do
  assert(not fileExists(path), "screenshot already exists: " .. path)
end

local function oneLine(value)
  return tostring(value):gsub("[\r\n=]", "_")
end

local receiptState = {
  schema = SCHEMA,
  status = "FAIL",
  fail = 1,
  phase = "module-load",
  edition = EDITION,
  expected_identity = EXPECTED_IDENTITY,
  screenshot_contract = "4/4",
}

local function writeReceipt(extra)
  local rows = {}
  for key, value in pairs(receiptState) do rows[key] = value end
  for key, value in pairs(extra or {}) do rows[key] = value end
  local order = {
    "status", "fail", "schema", "phase", "reason",
    "edition", "expected_identity", "env_identity", "love_identity",
    "disk_save_absent_before_setup", "battle_kind", "enemy_species",
    "enemy_level", "randomizer_protected", "enemy_ko",
    "battle_layout", "fight_input", "move_input",
    "start_level", "start_exp", "level36_threshold", "exp_gap",
    "exp_share_setting", "exp_multiplier_setting",
    "expected_exp_gained", "actual_exp_gained", "observed_levels", "end_level",
    "pre_exp_prompts_advanced",
    "psybeam_offer", "psybeam_learned", "battle_result",
    "screenshot_contract", "screenshots_written",
    "native_save", "native_reload", "reload_species", "reload_level",
    "reload_psybeam", "exp_png", "level_png", "offer_png", "learned_png",
  }
  local body, emitted = {}, {}
  for _, key in ipairs(order) do
    if rows[key] ~= nil then
      body[#body + 1] = key .. "=" .. oneLine(rows[key])
      emitted[key] = true
    end
  end
  local rest = {}
  for key in pairs(rows) do
    if not emitted[key] then rest[#rest + 1] = key end
  end
  table.sort(rest)
  for _, key in ipairs(rest) do
    body[#body + 1] = key .. "=" .. oneLine(rows[key])
  end
  local tmp = RESULT_PATH .. ".tmp"
  local file = assert(io.open(tmp, "wb"), "cannot stage result receipt")
  file:write(table.concat(body, "\n"), "\n")
  file:close()
  assert(os.rename(tmp, RESULT_PATH), "cannot promote result receipt")
end

local function arm(phase, extra)
  receiptState.status = "FAIL"
  receiptState.fail = 1
  receiptState.phase = phase
  receiptState.reason = nil
  for key, value in pairs(extra or {}) do receiptState[key] = value end
  writeReceipt()
end

local function requireProbe(condition, phase, reason, extra)
  if condition then return condition end
  receiptState.status = "FAIL"
  receiptState.fail = 1
  receiptState.phase = phase
  receiptState.reason = reason
  for key, value in pairs(extra or {}) do receiptState[key] = value end
  writeReceipt()
  error(reason, 0)
end

-- Arm fail-closed output before returning the runtime coroutine.
writeReceipt()

local activeRuntime, originalEmit
local function restoreObserver()
  if activeRuntime and originalEmit then activeRuntime.emit = originalEmit end
  activeRuntime, originalEmit = nil, nil
end

local function run(game)
  local U = dofile(envRequired("KA_TEST_UTIL"))
  local BattleState = require("src.battle.BattleState")
  local Experience = require("src.battle.Experience")
  local Growth = require("src.pokemon.Growth")
  local Pokemon = require("src.pokemon.Pokemon")
  local Runtime = require("src.mods.Runtime")
  local SaveData = require("src.core.SaveData")
  local Strings = require("src.core.Strings")

  local function top() return game.stack:top() end
  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return predicate()
  end
  local function tap(button)
    U.tap(game, button)
    U.wait(1)
  end
  local function hasMove(mon, id)
    local count = 0
    for _, move in ipairs(mon and mon.moves or {}) do
      if move.id == id then count = count + 1 end
    end
    return count > 0, count
  end
  local function pageText(box, index)
    local parts = {}
    for _, line in ipairs(box and box.pages and box.pages[index] or {}) do
      parts[#parts + 1] = tostring(line)
    end
    return table.concat(parts, " ")
  end
  local function pageContaining(box, needle, last)
    local found
    for index = 1, #(box and box.pages or {}) do
      if pageText(box, index):find(needle, 1, true) then
        found = index
        if not last then return found end
      end
    end
    return found
  end
  local function textPageReady(box)
    return top() == box and (box.waiting or box.done)
  end
  local function reachTextPage(box, index, phase)
    requireProbe(type(index) == "number", phase,
      "required text page does not contain the localized move name")
    for _ = 1, 1800 do
      if box.pageIndex == index and textPageReady(box) then return true end
      requireProbe(top() == box, phase,
        "text box changed before the required page was rendered")
      if (box.waiting or box.done) and box.pageIndex < index then
        tap("a")
      else
        U.wait(1)
      end
    end
    return false
  end
  local function findMoveLearnMenu(mon)
    for _, state in ipairs(game.stack.states or {}) do
      if state.screenId == "MoveLearnMenu" and state.mon == mon
          and state.newMoveId then return state end
    end
  end
  local function isChoice(value)
    return value and value.index and value.onChoose
      and not value.mon and not value.items
  end
  local function capture(path, phase)
    game.capturePath = path
    for _ = 1, 240 do
      if not game.capturePath then break end
      U.wait(1)
    end
    requireProbe(game.capturePath == nil, phase,
      "renderer did not consume screenshot request", { screenshot = path })
    U.wait(1)
    local file = io.open(path, "rb")
    requireProbe(file ~= nil, phase, "screenshot did not reach disk",
      { screenshot = path })
    local signature = file:read(8)
    local size = file:seek("end")
    file:close()
    requireProbe(signature == "\137PNG\r\n\26\n"
        and type(size) == "number" and size >= 1000,
      phase, "screenshot is not a non-empty PNG",
      { screenshot = path, screenshot_bytes = size or 0 })
    return size
  end
  local function battleMessageReady(battle, predicate)
    local current = battle.current
    if top() ~= battle or battle.phase ~= "messages"
        or not current or type(current.text) ~= "string"
        or not predicate(current.text) then
      return false
    end
    -- Localized battle messages may contain a real CONT marker (\v), as in
    -- German "PSIANA erreicht\vLevel 36!".  Advance only once ProtectedDelay3
    -- has expired; then keep waiting until the final line is fully rendered.
    if battle.msgWaiting == true and (battle.msgPreWait or 0) <= 0 then
      tap("a")
      return false
    end
    return battle.charIndex >= battle.total and battle.msgPrompt == true
      and (battle.msgPromptWait or 0) <= 0
  end
  local function fieldIdle(mapId)
    local ow = game.overworld
    local player = ow and ow.player
    return ow and top() == ow and ow.map and ow.map.id == mapId
      and player and not player.moving and not player.inputLocked
  end

  arm("identity-audit")
  local envIdentity = os.getenv("POKEPORT_IDENTITY")
  local loveIdentity = love.filesystem.getIdentity()
  receiptState.env_identity = envIdentity or "missing"
  receiptState.love_identity = loveIdentity or "missing"
  requireProbe(envIdentity == EXPECTED_IDENTITY, "identity-audit",
    "POKEPORT_IDENTITY is not this edition's non-planned probe identity")
  requireProbe(loveIdentity == EXPECTED_IDENTITY, "identity-audit",
    "LÖVE mounted a different identity")
  requireProbe(({ red = true, blue = true, yellow = true })[EDITION],
    "identity-audit", "unsupported edition")

  arm("fresh-identity-audit")
  local diskBefore = SaveData.load(EDITION)
  receiptState.disk_save_absent_before_setup = diskBefore == nil and 1 or 0
  requireProbe(diskBefore == nil, "fresh-identity-audit",
    "isolated probe identity already contains a save; use a fresh identity")

  arm("full-main-learnset-audit")
  local exports = game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant
  requireProbe(exports ~= nil, "full-main-learnset-audit",
    "Kanto Ascendant production export is missing")
  local espeonDef = game.data.pokemon.ESPEON
  local psybeam = game.data.moves.PSYBEAM
  requireProbe(espeonDef ~= nil and psybeam ~= nil,
    "full-main-learnset-audit", "ESPEON or PSYBEAM is missing")
  local exact = Experience.movesLearnedAt(espeonDef, 36)
  requireProbe(#exact == 1 and exact[1] == "PSYBEAM",
    "full-main-learnset-audit",
    "production exact-level resolver does not offer only PSYBEAM at 36")
  requireProbe(#Experience.movesLearnedAt(espeonDef, 35) == 0,
    "full-main-learnset-audit", "production resolver offers a move at 35")
  local rematchRewards = exports.rematchRewards
  requireProbe(rematchRewards and type(rematchRewards.state) == "function",
    "full-main-learnset-audit", "production rematch EXP controller is missing")
  local expSettings = rematchRewards.state(game)
  receiptState.exp_share_setting = expSettings and expSettings.expShareSetting
    or "missing"
  receiptState.exp_multiplier_setting = expSettings
    and expSettings.expMultiplierSetting or "missing"
  requireProbe(expSettings and expSettings.expShareSetting == "off"
      and expSettings.expMultiplierSetting == 0,
    "full-main-learnset-audit",
    "fresh production EXP Share or multiplier setting is not OFF")

  arm("level35-battle-setup")
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.options.battleLayout = "og"
  receiptState.battle_layout = game.save.options.battleLayout
  requireProbe((game.save.inventory.EXP_ALL or 0) == 0,
    "level35-battle-setup", "fresh probe unexpectedly has EXP.ALL")
  local espeon = Pokemon.new(game.data, "ESPEON", 35,
    function(_, high) return high end)
  BattleState.stampOT(game.save, espeon)
  local threshold36 = Growth.expForLevel(espeonDef.growthRate, 36,
    game.data.growth_rates)
  local threshold37 = Growth.expForLevel(espeonDef.growthRate, 37,
    game.data.growth_rates)
  espeon.exp = threshold36 - 1
  game.save.party = { espeon }
  local hasPsybeamBefore = hasMove(espeon, "PSYBEAM")
  receiptState.start_level = espeon.level
  receiptState.start_exp = espeon.exp
  receiptState.level36_threshold = threshold36
  receiptState.exp_gap = threshold36 - espeon.exp
  requireProbe(espeon.level == 35 and threshold36 - espeon.exp == 1,
    "level35-battle-setup", "Espeon is not exactly one EXP below level 36")
  requireProbe(Growth.levelForExp(espeonDef.growthRate, espeon.exp, 100,
      game.data.growth_rates) == 35 and threshold37 > threshold36,
    "level35-battle-setup", "level-35 EXP boundary is inconsistent")
  local expectedNaturalMoves = {
    "SAND_ATTACK", "CONFUSION", "QUICK_ATTACK", "SWIFT",
  }
  local naturalMovesExact = #espeon.moves == #expectedNaturalMoves
  for index, moveId in ipairs(expectedNaturalMoves) do
    naturalMovesExact = naturalMovesExact
      and espeon.moves[index] and espeon.moves[index].id == moveId
  end
  requireProbe(naturalMovesExact and not hasPsybeamBefore,
    "level35-battle-setup",
    "Espeon must enter with its exact four natural level-35 moves and no PSYBEAM")

  -- Establish only a harmless field backdrop.  The fight itself is created
  -- below by BattleState.newWild and entered through pushBattle.
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  requireProbe(fieldIdle("ROUTE_1"), "level35-battle-setup",
    "Route 1 field setup did not settle")
  local overworld = game.overworld

  arm("real-wild-battle")
  local observed = {}
  activeRuntime, originalEmit = Runtime, Runtime.emit
  Runtime.emit = function(name, payload)
    if payload and payload.battle == observed.battle then
      if name == "battle.started" then
        observed.started = payload.kind
      elseif name == "battle.exp_gained" and payload.mon == espeon then
        observed.exp = {
          gained = payload.gained,
          levels = payload.levels,
        }
      elseif name == "battle.ended" then
        observed.ended = payload.result
      end
    end
    return originalEmit(name, payload)
  end

  local battle = BattleState.newWild(game, "PIDGEY", 2, {
    encounterSource = "espeon-battle-exp-visual",
    randomizerProtected = true,
  })
  observed.battle = battle
  requireProbe(battle.kind == "wild" and battle.enemy and battle.enemy.mon
      and battle.enemy.mon.species == "PIDGEY"
      and battle.enemy.mon.level == 2
      and battle.randomizerProtected == true,
    "real-wild-battle",
    "BattleState.newWild did not preserve the protected Route-1 PIDGEY L2")
  receiptState.battle_kind = battle.kind
  receiptState.enemy_species = battle.enemy.mon.species
  receiptState.enemy_level = battle.enemy.mon.level
  receiptState.randomizer_protected = battle.randomizerProtected and 1 or 0
  local expectedGain = Experience.gainFor(battle.enemy.def,
    battle.enemy.mon.level, false, 1, espeon.traded, game.data.constants)
  receiptState.expected_exp_gained = expectedGain
  requireProbe(expectedGain >= 1 and espeon.exp + expectedGain < threshold37,
    "real-wild-battle", "bounded wild KO could cross more than one level")
  -- Only the target's survivability and speed are bounded.  Damage, faint,
  -- EXP, level-up, UI, and battle result remain production BattleState work.
  battle.rng = function(low) return low end
  battle.enemy.mon.hp = 1
  battle.enemy.mon.stats.speed = 1
  overworld:pushBattle(battle)

  local menuReady = waitFor(function()
    if top() == battle and battle.phase == "menu" then return true end
    if top() == battle and battle.phase == "messages" then tap("a") end
  end, 1800)
  requireProbe(menuReady and observed.started == "wild",
    "real-wild-battle", "real wild battle did not reach its FIGHT menu")

  arm("real-fight-input")
  receiptState.fight_input = "A"
  tap("a") -- FIGHT
  requireProbe(waitFor(function()
    return top() == battle and battle.phase == "moveSelect" and true or nil
  end, 240), "real-fight-input", "FIGHT did not open move selection")
  tap("down")
  tap("down")
  requireProbe(battle.moveIndex == 3
      and battle.player.curMoves[battle.moveIndex].id == "QUICK_ATTACK",
    "real-fight-input", "two DOWN inputs did not select natural QUICK_ATTACK")
  receiptState.move_input = "DOWN,DOWN,A:QUICK_ATTACK"
  tap("a") -- QUICK_ATTACK; the real damage/faint/EXP pipeline starts here

  arm("01-battle-exp-screenshot")
  local startExp = threshold36 - 1
  local preExpPromptsAdvanced = 0
  local expReady = waitFor(function()
    local expectedText = observed.exp and Strings(
      "%s gained\n%d EXP. Points!", battle.player.name, observed.exp.gained)
    if expectedText and battleMessageReady(battle, function(text)
        return text == expectedText
      end) then
      return true
    end

    -- QUICK_ATTACK can legitimately queue a critical-hit message before the
    -- faint message; enemyMonFainted/awardExp runs only after both prompts
    -- have been acknowledged.  Advance only fully rendered pre-EXP prompts.
    -- Once the exact EXP page is current, leave it untouched for capture.
    if top() == battle and battle.phase == "messages"
        and battle.current and type(battle.current.text) == "string"
        and battle.current.text ~= expectedText
        and ((battle.charIndex >= battle.total and battle.msgPrompt == true
            and (battle.msgPromptWait or 0) <= 0)
          or (battle.msgWaiting == true
            and (battle.msgPreWait or 0) <= 0)) then
      preExpPromptsAdvanced = preExpPromptsAdvanced + 1
      tap("a")
    end
  end, 2400)
  receiptState.pre_exp_prompts_advanced = preExpPromptsAdvanced
  requireProbe(expReady and observed.exp and #observed.exp.levels == 1
      and observed.exp.levels[1] == 36
      and observed.exp.gained == expectedGain
      and espeon.exp - startExp == observed.exp.gained,
    "01-battle-exp-screenshot",
    "real KO did not emit the exact level-36 EXP transaction")
  receiptState.actual_exp_gained = observed.exp.gained
  receiptState.observed_levels = table.concat(observed.exp.levels, ",")
  receiptState.enemy_ko = battle.enemy.mon.hp <= 0 and 1 or 0
  requireProbe(receiptState.enemy_ko == 1, "01-battle-exp-screenshot",
    "enemy was not knocked out by the selected move")
  capture(SCREENSHOTS.exp, "01-battle-exp-screenshot")
  receiptState.exp_png = "01_battle_exp_gained.png"
  tap("a")

  arm("02-level36-screenshot")
  requireProbe(waitFor(function()
    return battleMessageReady(battle, function(text)
      return text == Strings("%s grew\nto level %d!", battle.player.name, 36)
    end)
  end, 1200), "02-level36-screenshot",
    "real battle did not render the grew-to-level-36 message")
  requireProbe(espeon.level == 36, "02-level36-screenshot",
    "Espeon model is not level 36 behind the level-up message")
  capture(SCREENSHOTS.level, "02-level36-screenshot")
  receiptState.level_png = "02_grew_level36.png"
  tap("a")

  arm("03-psybeam-offer-screenshot")
  local statBox = waitFor(function()
    local state = top()
    return state and state.mon == espeon and not state.pages
      and not state.newMoveId and state or nil
  end, 600)
  requireProbe(statBox ~= nil, "03-psybeam-offer-screenshot",
    "level-up StatBox did not open")
  tap("a")
  local learnMenu = waitFor(function()
    return findMoveLearnMenu(espeon)
  end, 900)
  requireProbe(learnMenu and learnMenu.newMoveId == "PSYBEAM",
    "03-psybeam-offer-screenshot",
    "real battle MoveLearnMenu does not offer PSYBEAM")
  local offerBox = waitFor(function()
    local state = top()
    return state and state.isTextBox and state.pages and state or nil
  end, 300)
  requireProbe(offerBox ~= nil, "03-psybeam-offer-screenshot",
    "PSYBEAM offer TextBox did not open")
  local moveName = psybeam.name
  local offerPage = pageContaining(offerBox, moveName, false)
  requireProbe(reachTextPage(offerBox, offerPage,
      "03-psybeam-offer-screenshot"),
    "03-psybeam-offer-screenshot",
    "localized PSYBEAM offer page did not finish rendering")
  requireProbe(not hasMove(espeon, "PSYBEAM"),
    "03-psybeam-offer-screenshot",
    "PSYBEAM was already present before the player accepted the offer")
  capture(SCREENSHOTS.offer, "03-psybeam-offer-screenshot")
  receiptState.offer_png = "03_psybeam_offer.png"
  receiptState.psybeam_offer = 1

  arm("04-psybeam-learned-screenshot")
  local choice = waitFor(function()
    local state = top()
    if isChoice(state) then return state end
    if state == offerBox and (state.waiting or state.done) then tap("a") end
  end, 1800)
  requireProbe(choice and choice.index == 1,
    "04-psybeam-learned-screenshot",
    "PSYBEAM YES/NO confirmation did not appear on YES")
  tap("a") -- YES, through the real ChoiceBox
  requireProbe(waitFor(function()
    return top() == learnMenu and learnMenu.selecting and true or nil
  end, 300), "04-psybeam-learned-screenshot",
    "real replacement picker did not open")
  requireProbe(learnMenu.index == 1 and espeon.moves[1].id == "SAND_ATTACK",
    "04-psybeam-learned-screenshot",
    "replacement cursor is not on the natural non-HM SAND_ATTACK slot")
  tap("a") -- replace SAND_ATTACK; MoveLearnMenu performs the production mutation
  local learnedBox = waitFor(function()
    local state = top()
    return state and state ~= offerBox and state.isTextBox
      and state.pages and state or nil
  end, 300)
  requireProbe(learnedBox ~= nil, "04-psybeam-learned-screenshot",
    "learned-PSYBEAM TextBox did not open")
  local learnedPage = pageContaining(learnedBox, moveName, true)
  requireProbe(reachTextPage(learnedBox, learnedPage,
      "04-psybeam-learned-screenshot"),
    "04-psybeam-learned-screenshot",
    "localized learned-PSYBEAM page did not finish rendering")
  local learned, learnedCount = hasMove(espeon, "PSYBEAM")
  requireProbe(learned and learnedCount == 1 and #espeon.moves == 4,
    "04-psybeam-learned-screenshot",
    "real MoveLearnMenu did not replace exactly one move with PSYBEAM")
  capture(SCREENSHOTS.learned, "04-psybeam-learned-screenshot")
  receiptState.learned_png = "04_psybeam_learned.png"
  receiptState.psybeam_learned = 1

  arm("battle-finish")
  for _ = 1, 2400 do
    if observed.ended and fieldIdle("ROUTE_1") then break end
    local state = top()
    if state and state.isTextBox and (state.waiting or state.done) then
      tap("a")
    elseif state == battle and battle.phase == "messages" then
      tap("a")
    else
      U.wait(1)
    end
  end
  receiptState.battle_result = observed.ended or "missing"
  receiptState.end_level = espeon.level
  requireProbe(observed.ended == "win" and fieldIdle("ROUTE_1"),
    "battle-finish", "real wild battle did not finish as a field-return win")
  requireProbe(espeon.level == 36 and hasMove(espeon, "PSYBEAM"),
    "battle-finish", "level 36 or learned PSYBEAM was lost after battle")
  restoreObserver()

  arm("native-save-reload")
  local saved = game:writeSave()
  receiptState.native_save = saved and 1 or 0
  requireProbe(saved == true, "native-save-reload",
    "Game:writeSave rejected the post-battle save")
  local loaded, recovered = SaveData.load(EDITION)
  requireProbe(loaded ~= nil and recovered ~= true, "native-save-reload",
    "SaveData.load did not return the active edition save")
  game:restoreSave(loaded, recovered)
  U.wait(24)
  local persisted = game.save.party and game.save.party[1]
  local persistedPsybeam, persistedCount = hasMove(persisted, "PSYBEAM")
  receiptState.native_reload = persisted ~= nil and 1 or 0
  receiptState.reload_species = persisted and persisted.species or "missing"
  receiptState.reload_level = persisted and persisted.level or "missing"
  receiptState.reload_psybeam = persistedPsybeam and 1 or 0
  requireProbe(persisted and persisted.species == "ESPEON"
      and persisted.level == 36 and #persisted.moves == 4
      and persistedPsybeam and persistedCount == 1,
    "native-save-reload",
    "native reload did not retain one level-36 Espeon PSYBEAM")

  receiptState.screenshots_written = "4/4"
  receiptState.status = "PASS"
  receiptState.fail = 0
  receiptState.phase = "complete"
  receiptState.reason = nil
  writeReceipt()
  print(("ESPEON BATTLE EXP VISUAL PASS edition=%s screenshots=4/4 "
    .. "native_save_reload=1/1 fail=0"):format(EDITION))
end

return function(game)
  local ok, why = xpcall(function() run(game) end, debug.traceback)
  restoreObserver()
  if ok then
    love.event.quit(0)
    return
  end
  receiptState.status = "FAIL"
  receiptState.fail = 1
  receiptState.reason = oneLine(why)
  pcall(writeReceipt)
  print("ESPEON BATTLE EXP VISUAL FAIL " .. oneLine(why))
  love.event.quit(1)
end
