-- Full-mod / real-engine regression for Route 22's two authored rival scenes.
--
-- Run from Gen1 Recomp:
--   TRAINER_REMATCH_MOD_DIR=mods/0000_ka_rc11_integration \
--     ./.tools/luajit-src/src/luajit \
--     /path/to/tests/route22_character_lifecycle_engine_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
-- The SDK's LÖVE stub intentionally keeps save files in memory. A handful of
-- packaged-content registrars read their immutable JSON directly through
-- love.filesystem, so let those reads fall through to the checkout while the
-- loader itself continues to use its real FsIo/alias path.
local stubRead = love.filesystem.read
love.filesystem.read = function(path)
  local body, err = stubRead(path)
  if body ~= nil then return body, err end
  local handle = io.open(path, "rb")
  if not handle then return nil, err end
  body = handle:read("*a")
  handle:close()
  return body
end
local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.BULBASAUR) then Data:load() end

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  check(actual == expected, (message or "values differ") .. " (got "
    .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
local run = T.sdk.loadMod(modPath, { data = Data })
eq(#(run.errors or {}), 0, "the complete mod graph loads in the real engine")
local exports = assert(run.loader.exports.kanto_ascendant)
local characters = assert(exports.extendedCharacters)
local rivalTeams = assert(exports.rivalTeams)

local SaveData = require("src.core.SaveData")
local Pokemon = require("src.pokemon.Pokemon")
local BattleState = require("src.battle.BattleState")
local ScriptRunner = require("src.script.ScriptRunner")
local Commands = require("src.script.Commands")
local NPC = require("src.world.NPC")
local Overworld = require("src.world.OverworldController")
local route22 = assert(require("data.scripts.story5").ROUTE_22)

local FIRST_WIN = "EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE"
local SECOND_WIN = "EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE"
local ROUTE_KEYS = {
  "ROUTE22_RIVAL1", "ROUTE_22_obj_1",
  "ROUTE22_RIVAL2", "ROUTE_22_obj_2",
}
local MATRIX = {
  RED = { rival = "BLUE", third = "GREEN" },
  BLUE = { rival = "GREEN", third = "RED" },
  GREEN = { rival = "RED", third = "BLUE" },
}

-- Pin the generated-map identity that the production rematch exclusion uses.
local routeDef = assert(Data.maps.ROUTE_22)
eq(routeDef.objects[1].name, "ROUTE22_RIVAL1",
  "generated Route 22 object one is the first story rival")
eq(routeDef.objects[1].text, "TEXT_ROUTE22_RIVAL1",
  "generated first rival retains its authored text identity")
eq(routeDef.objects[1].trainerClass, nil,
  "the first Route 22 rival is not a generic field trainer")
eq(routeDef.objects[2].name, "ROUTE22_RIVAL2",
  "generated Route 22 object two is the late story rival")

local function makeGame(save)
  return {
    data = Data,
    save = save,
    mods = run.loader,
    stack = { push = function() end },
    input = {},
  }
end

-- Install the complete production graph once, exactly as game.ready does.
-- Its stable Overworld wrappers dispatch through this runtime slot; swapping
-- installedGame.save below models CONTINUE/NG+ adopting another save without
-- re-wrapping the engine module.
run.loader.modSave = {}
local installSave = SaveData.newGame()
installSave.party = { Pokemon.new(Data, "MEWTWO", 100) }
run.loader.modSave = installSave.modData
local installedGame = makeGame(installSave)
exports.install(installedGame, {})
local rematchRuntime = assert(Overworld._kantoAscendantTalkRuntime,
  "the full production install exposes its stable trainer-talk dispatcher")

local function freshCharacterGame(character)
  -- Never let the previous case's live mod.save backing influence the New
  -- Game hook. SaveData.newGame is the exact reset primitive used by Legacy
  -- Journey's startFreshGame path before Oak's selector runs.
  run.loader.modSave = {}
  local save = SaveData.newGame()
  save.flags.EVENT_GOT_STARTER = true
  save.flags.EVENT_CHOSE_CHARMANDER = true
  save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true
  save.flags.EVENT_GOT_POKEDEX = true
  save.player.name = character == "GREEN" and "CASEY" or character
  save.player.rival = MATRIX[character].rival
  save.party = {
    Pokemon.new(Data, "MEWTWO", 100, function(lo, hi)
      return math.floor((lo + hi) / 2)
    end),
  }
  run.loader.modSave = save.modData
  local game = makeGame(save)
  characters.select(character)
  characters.refreshVisuals(game)
  return game
end

local function assertCharacter(game, character, phase)
  run.loader.modSave = game.save.modData
  local expected = MATRIX[character]
  local state = characters.getState()
  eq(state.enabled, true, phase .. ": extended identity remains enabled")
  eq(state.player_character, character,
    phase .. ": player identity is save-local")
  eq(state.rival_character, expected.rival,
    phase .. ": rival identity follows only the character matrix")
  eq(state.third_character, expected.third,
    phase .. ": third identity remains independent")
  local stored = assert(game.save.modData.kanto_ascendant)
    .extended_characters
  eq(stored.player_character, character,
    phase .. ": character identity lives in its own mod-save record")
  eq(game.save.flags.player_character, nil,
    phase .. ": character identity never aliases an engine event flag")
  eq(Data.trainers.OPP_RIVAL1.ascendantCharacter, expected.rival,
    phase .. ": live first-rival presentation matches the matrix")
  eq(Data.trainers.OPP_RIVAL2.ascendantCharacter, expected.rival,
    phase .. ": live late-rival presentation matches the matrix")
end

local function assertNoGenericRematch(game, phase)
  run.loader.modSave = game.save.modData
  local states = exports.trainerStates()
  for _, key in ipairs(ROUTE_KEYS) do
    eq(game.save.defeatedTrainers[key], nil,
      phase .. ": story result does not become defeated-trainer flag " .. key)
    eq(states[key], nil,
      phase .. ": story result does not become generic rematch state " .. key)
  end
end

local function assertProductionStoryExclusion(game, phase)
  -- Reproduce the reported post-blackout/reload shape at the exact production
  -- dispatcher boundary: the generated object looks defeated to Overworld,
  -- but it must fall through to its authored onStep story and must never
  -- schedule the generic trainer cooldown that produced a "Red rematch".
  installedGame.save = game.save
  run.loader.modSave = game.save.modData
  local npc = NPC.new(Data, "ROUTE_22", routeDef.objects[1])
  local ow = {
    map = { id = "ROUTE_22", def = routeDef },
    player = {},
    trainerDefeated = function() return true end,
  }
  local handled = rematchRuntime.handle(ow, npc)
  eq(handled, false,
    phase .. ": production talk dispatcher preserves the story encounter")
  eq(exports.trainerStates()[npc.id], nil,
    phase .. ": production talk dispatcher creates no rematch state")
  rematchRuntime.afterTrainer(ow, npc, false)
  eq(exports.trainerStates()[npc.id], nil,
    phase .. ": production post-battle wrapper schedules no cooldown")
end

local function captureScene(game, expectedClass, expectedBaseParty, phase)
  local captured
  local fakeRunner = {
    isRunning = function() return false end,
    run = function(_, rows) captured = rows end,
  }
  local ow = { player = { facing = "right" }, runner = fakeRunner }
  check(route22.onStep(game, ow, 29, 4),
    phase .. ": real Route 22 onStep arms the encounter")
  eq(ow.player.facing, "down",
    phase .. ": real ambush turns the player toward the rival")
  check(type(captured) == "table",
    phase .. ": real story script supplies a command table")
  -- Stock 0.1.86 restores Music_MeetRival before the rival walks away;
  -- current development data omits that presentation-only row. Validate
  -- both concrete engine layouts instead of treating the 0.1.86 row as a
  -- mod regression.
  local hasExitMusic = captured[10] and captured[10][1] == "play_music"
  eq(#captured, hasExitMusic and 12 or 11,
    phase .. ": Route 22 has only the supported eleven/twelve-row layout")
  eq(captured[5][1], "rival_battle",
    phase .. ": row five remains the engine rival command")
  eq(captured[5][2], expectedClass,
    phase .. ": encounter keeps its authored rival class")
  eq(captured[5][3], expectedBaseParty,
    phase .. ": encounter keeps its authored base party")
  eq(captured[6][1], "jump_if_false",
    phase .. ": loss branch remains immediately after the battle")
  eq(captured[6][2], #captured,
    phase .. ": loss branch targets the final hide-object row")
  if hasExitMusic then
    eq(captured[10][2], "Music_MeetRival",
      phase .. ": stock 0.1.86 restores only the authored rival music")
    check(type(captured[10][3]) == "table"
        and captured[10][3].start == "rival",
      phase .. ": stock 0.1.86 rival music uses its authored start cue")
    eq(captured[10][3].tempo, expectedBaseParty == 10 and 100 or nil,
      phase .. ": stock 0.1.86 keeps the encounter-specific rival tempo")
  end
  eq(captured[#captured - 1][1], "walk_npc",
    phase .. ": penultimate row remains the authored rival exit walk")
  eq(captured[#captured][1], "hide_object",
    phase .. ": final row remains the authored rival hide")
  return captured
end

local function assertNoScene(game, phase)
  local ran = false
  local ow = {
    player = { facing = "right" },
    runner = {
      isRunning = function() return false end,
      run = function() ran = true end,
    },
  }
  eq(route22.onStep(game, ow, 29, 4), false,
    phase .. ": completed story window stays disarmed")
  eq(ran, false, phase .. ": disarmed window starts no script")
end

local function rowSpeciesLevels(rows)
  local out = {}
  for _, row in ipairs(rows or {}) do
    out[#out + 1] = tostring(row.species) .. ":" .. tostring(row.level)
  end
  return table.concat(out, ",")
end

local function battleSpeciesLevels(battle)
  local out = {}
  for _, mon in ipairs(battle.enemyParty or {}) do
    out[#out + 1] = tostring(mon.species) .. ":" .. tostring(mon.level)
  end
  return table.concat(out, ",")
end

-- Execute the captured, unmodified engine rows through ScriptRunner. Only
-- presentation text and the asynchronous battle stack edge are made
-- synchronous; Commands.rival_battle itself still resolves the real starter
-- offset, and BattleState.newTrainer still runs every merged trainer hook.
local function executeScene(game, rows, result, expectedRival, phase)
  local originalShowText = Commands.show_text
  local originalStartBattle = Commands.start_battle
  local messages, battle = {}, nil
  Commands.show_text = function(_, textId)
    messages[#messages + 1] = textId
  end
  Commands.start_battle = function(ctx, kind, oppClass, partyIndex)
    eq(kind, "trainer", phase .. ": story requests a trainer battle")
    battle = BattleState.newTrainer(ctx.game, oppClass, partyIndex)
    ctx.lastBattleResult = result
    ctx.lastCheck = result == "win"
  end

  local completed = false
  local runner = ScriptRunner.new(game, nil)
  local success, failure = xpcall(function()
    runner:run(rows, { onDone = function() completed = true end })
  end, debug.traceback)
  Commands.show_text = originalShowText
  Commands.start_battle = originalStartBattle
  check(success, phase .. ": real ScriptRunner failed: " .. tostring(failure))
  check(completed and not runner:isRunning(),
    phase .. ": real ScriptRunner completes synchronously in the harness")
  check(battle ~= nil, phase .. ": real BattleState is constructed")
  eq(battle.trainer.ascendantCharacter, expectedRival,
    phase .. ": battle presentation uses the selected rival identity")
  eq(battle.trainer.name, expectedRival,
    phase .. ": battle name is independent from rematch progression")
  eq(battle.trainerPartyHookFallback, nil,
    phase .. ": merged rival roster passes engine validation")

  local source = Data.trainers[battle.oppClass].parties[battle.partyIndex]
  local identityTeam = rivalTeams.resolve(expectedRival, battle.oppClass,
    battle.partyIndex, source)
  eq(battleSpeciesLevels(battle), rowSpeciesLevels(identityTeam),
    phase .. ": battle roster follows the character matrix, not result flags")
  eq(#messages, result == "win" and 3 or 1,
    phase .. ": loss skips only the authored victory/exit dialogue")
  return battle
end

local function reloadGame(game, phase)
  local encoded = SaveData.encode(game.save)
  local save, decodeError = SaveData.decode(encoded)
  check(save ~= nil, phase .. ": real save serialization reloads: "
    .. tostring(decodeError))
  run.loader.modSave = save.modData
  local reloaded = makeGame(save)
  run.loader.events:emit("save.loaded", { save = save, game = reloaded })
  characters.refreshVisuals(reloaded)
  return reloaded
end

for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local rival = MATRIX[character].rival
  local prefix = character .. "/first"
  local game = freshCharacterGame(character)
  assertCharacter(game, character, prefix .. "/fresh")
  eq(game.save.flags[FIRST_WIN], nil,
    prefix .. ": first-victory flag starts clear")
  eq(game.save.flags[SECOND_WIN], nil,
    prefix .. ": late-victory flag starts clear")
  assertNoGenericRematch(game, prefix .. "/fresh")

  -- First defeat: no win flag, no defeated-trainer record, no rematch state.
  local firstRows = captureScene(game, "OPP_RIVAL1", 4,
    prefix .. "/loss")
  local firstLoss = executeScene(game, firstRows, "lose", rival,
    prefix .. "/loss")
  eq(firstLoss.oppClass, "OPP_RIVAL1",
    prefix .. ": a defeat remains the authored first encounter")
  eq(firstLoss.partyIndex, 4,
    prefix .. ": Charmander branch keeps the authored first party")
  eq(game.save.flags[FIRST_WIN], nil,
    prefix .. ": defeat cannot set the first-victory flag")
  eq(game.save.flags[SECOND_WIN], nil,
    prefix .. ": defeat cannot set the late-victory flag")
  assertNoGenericRematch(game, prefix .. "/loss")
  assertProductionStoryExclusion(game, prefix .. "/loss")

  -- A real encode/decode plus save.loaded must re-arm exactly that first
  -- story fight with the same character matrix; this is the reported Casey
  -- (GREEN player / RED rival) failure boundary.
  game = reloadGame(game, prefix .. "/reload")
  assertCharacter(game, character, prefix .. "/reload")
  eq(game.save.flags[FIRST_WIN], nil,
    prefix .. "/reload: first encounter is still unbeaten")
  assertNoGenericRematch(game, prefix .. "/reload")
  assertProductionStoryExclusion(game, prefix .. "/reload")
  firstRows = captureScene(game, "OPP_RIVAL1", 4,
    prefix .. "/retry")
  local retryWin = executeScene(game, firstRows, "win", rival,
    prefix .. "/retry")
  eq(retryWin.oppClass, "OPP_RIVAL1",
    prefix .. ": retry is not converted into a generic rematch")
  eq(game.save.flags[FIRST_WIN], true,
    prefix .. ": only a win commits the first-victory flag")
  eq(game.save.flags[SECOND_WIN], nil,
    prefix .. ": first win cannot consume the late encounter")
  assertNoGenericRematch(game, prefix .. "/retry-win")
  assertNoScene(game, prefix .. "/first-complete")

  -- The late Route 22 visit owns a separate class, party and win flag. Its
  -- own loss/reload/win lifecycle cannot rewrite the first encounter or the
  -- selected rival identity.
  game.save.flags.EVENT_BEAT_BROCK = true
  game.save.flags.EVENT_BEAT_GIOVANNI = true
  local lateRows = captureScene(game, "OPP_RIVAL2", 10,
    character .. "/late/loss")
  local lateLoss = executeScene(game, lateRows, "lose", rival,
    character .. "/late/loss")
  eq(lateLoss.oppClass, "OPP_RIVAL2",
    character .. "/late: late loss uses only the second rival role")
  eq(lateLoss.partyIndex, 10,
    character .. "/late: Charmander branch keeps the authored late party")
  eq(game.save.flags[FIRST_WIN], true,
    character .. "/late: late loss preserves the first victory")
  eq(game.save.flags[SECOND_WIN], nil,
    character .. "/late: late loss cannot set its victory flag")
  assertNoGenericRematch(game, character .. "/late/loss")

  game = reloadGame(game, character .. "/late/reload")
  assertCharacter(game, character, character .. "/late/reload")
  eq(game.save.flags[FIRST_WIN], true,
    character .. "/late/reload: first-victory flag persists independently")
  eq(game.save.flags[SECOND_WIN], nil,
    character .. "/late/reload: late encounter remains armed")
  assertNoGenericRematch(game, character .. "/late/reload")
  lateRows = captureScene(game, "OPP_RIVAL2", 10,
    character .. "/late/retry")
  executeScene(game, lateRows, "win", rival, character .. "/late/retry")
  eq(game.save.flags[FIRST_WIN], true,
    character .. "/late/win: first-victory flag remains intact")
  eq(game.save.flags[SECOND_WIN], true,
    character .. "/late/win: only the late win commits its own flag")
  assertNoGenericRematch(game, character .. "/late/win")
  assertNoScene(game, character .. "/late/complete")

  -- NG+ uses a genuinely new SaveData skeleton. No character choice, story
  -- victory or generic trainer state may leak across the cycle boundary; Oak
  -- then writes the newly chosen character matrix into the fresh mod bucket.
  run.loader.modSave = game.save.modData
  local nextSave = SaveData.newGame()
  eq(nextSave.flags[FIRST_WIN], nil,
    character .. "/NG+: first-victory flag does not cross cycles")
  eq(nextSave.flags[SECOND_WIN], nil,
    character .. "/NG+: late-victory flag does not cross cycles")
  for _, key in ipairs(ROUTE_KEYS) do
    eq(nextSave.defeatedTrainers[key], nil,
      character .. "/NG+: defeated-trainer state does not cross cycles")
  end
  run.loader.modSave = nextSave.modData
  eq(characters.getState().enabled, false,
    character .. "/NG+: old character selection does not cross cycles")

  nextSave.flags.EVENT_GOT_STARTER = true
  nextSave.flags.EVENT_CHOSE_CHARMANDER = true
  nextSave.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true
  nextSave.flags.EVENT_GOT_POKEDEX = true
  nextSave.player.name = character == "GREEN" and "CASEY" or character
  nextSave.player.rival = rival
  nextSave.party = { Pokemon.new(Data, "MEWTWO", 100) }
  local nextGame = makeGame(nextSave)
  characters.select(character)
  characters.refreshVisuals(nextGame)
  assertCharacter(nextGame, character, character .. "/NG+/selected")
  local nextRows = captureScene(nextGame, "OPP_RIVAL1", 4,
    character .. "/NG+/first-loss")
  executeScene(nextGame, nextRows, "lose", rival,
    character .. "/NG+/first-loss")
  eq(nextGame.save.flags[FIRST_WIN], nil,
    character .. "/NG+: a fresh-cycle defeat re-arms the first story fight")
  assertNoGenericRematch(nextGame, character .. "/NG+/first-loss")
  assertProductionStoryExclusion(nextGame, character .. "/NG+/first-loss")
end

run.release()
print(("route22 character lifecycle engine test: %d assertions"):format(
  assertions))
