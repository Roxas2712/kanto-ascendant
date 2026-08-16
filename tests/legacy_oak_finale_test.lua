local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.PIKACHU) then Data:load() end

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local hooks = {}
local profile = {
  completedPaths = { red = true, blue = true, green = true }, legacyPass = false,
}
local completeCalls, archiveRows = 0, {
  { id = "ARCHIVE:BULB", mon = { species = "BULBASAUR", level = 50,
    moves = { { id = "TACKLE", pp = 35 }, { id = "GROWL", pp = 40 } } } },
  { id = "ARCHIVE:SQUIRT", mon = { species = "SQUIRTLE", level = 50,
    moves = { { id = "TACKLE", pp = 35 }, { id = "TAIL_WHIP", pp = 30 } } } },
  { id = "ARCHIVE:CATER", mon = { species = "CATERPIE", level = 50,
    moves = { { id = "TACKLE", pp = 35 }, { id = "STRING_SHOT", pp = 40 } } } },
}
local journey = {
  profile = function() return profile end,
  completeFinale = function()
    completeCalls = completeCalls + 1
    profile.legacyPass = true
    return true
  end,
  archive = { availableMons = function() return archiveRows end },
}
local mod = {
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  ui = {},
}
local created, pushed = nil, nil
local make = assert(loadfile("legacy_oak_finale.lua"))()
local oak = make(mod, {
  journey = journey,
  paths = { profile = function() return profile end },
  -- A small injected row proves that authored egg moves are accepted as a
  -- legality source without duplicating the production registry in the test.
  eggMoves = { [25] = { "SPLASH" } },
  newTrainer = function(_, class, index)
    created = { class = class, index = index }
    created.boss = hooks["trainer.party"](
      function(_, _, party) return party end, class, index, {})
    return { class = class }
  end,
  TextBox = { new = function(_, text, done, config)
    return { text = text, done = done, config = config }
  end },
})

ok(oak.validateBoss(Data), "deterministic Oak roster has six legal Gen-I movesets")
eq(#oak.boss, 6, "Oak roster has exactly six distinct monsters")

local function mon(species, moveA, moveB)
  return { species = species, level = 50, moves = {
    { id = moveA, pp = Data.moves[moveA].pp },
    { id = moveB, pp = Data.moves[moveB].pp },
  } }
end
local originalParty = {
  mon("PIKACHU", "THUNDERSHOCK", "GROWL"),
  mon("EEVEE", "TACKLE", "SAND_ATTACK"),
  mon("CHARMANDER", "SCRATCH", "GROWL"),
}
local game = { data = Data, save = { party = originalParty }, stack = {
  push = function(_, value) pushed = value end,
} }
local sources = oak.sources(game)
eq(#sources, 6, "builder combines current legal party and unleased archive rows")
local team = assert(oak.buildTeam(game, sources))
eq(#team, 6, "builder requires and returns exactly six validated Pokémon")
ok(team[1] ~= originalParty[1], "battle team is a copy, never a party ghost/reference")
eq(team[1].hp, team[1].stats.hp,
  "trial projection is safely healed without mutating the source")

local egg = mon("PIKACHU", "THUNDERSHOCK", "GROWL")
egg.isEgg = true
local _, eggErr = oak.normaliseMon(Data, egg)
eq(eggErr, "egg_mon", "Eggs cannot become battleable team-builder ghosts")
local inherited = mon("RAICHU", "QUICK_ATTACK", "THUNDERBOLT")
ok(oak.normaliseMon(Data, inherited),
  "lawful pre-evolution moves remain valid after evolution")
local eggMove = mon("PIKACHU", "SPLASH", "GROWL")
ok(oak.normaliseMon(Data, eggMove),
  "authored breeding move registry is a real legality source")
local ppUp = mon("PIKACHU", "THUNDERSHOCK", "GROWL")
ppUp.moves[1].ppUps = 3
ppUp.moves[1].pp = Data.moves.THUNDERSHOCK.pp
  + 3 * math.floor(Data.moves.THUNDERSHOCK.pp / 5)
local ppNormal = assert(oak.normaliseMon(Data, ppUp))
eq(ppNormal.moves[1].pp, ppUp.moves[1].pp,
  "legal PP Ups are retained and fully restored on the trial copy")
ppUp.moves[1].ppUps = 4
local _, ppUpErr = oak.normaliseMon(Data, ppUp)
eq(ppUpErr, "invalid_move_pp", "impossible PP Up state is fail-closed")
local tamperedStats = mon("PIKACHU", "THUNDERSHOCK", "GROWL")
tamperedStats.stats = { hp = 9999, attack = 9999, defense = 9999,
  speed = 9999, special = 9999 }
tamperedStats.hp = 9999
local safeStats = assert(oak.normaliseMon(Data, tamperedStats))
ok(safeStats.stats.hp < 9999 and safeStats.hp == safeStats.stats.hp,
  "trial stats are recalculated instead of importing a forged combat block")
local forged = {}
for index, source in ipairs(sources) do forged[index] = source end
forged[1] = { identity = sources[1].identity, mon = sources[1].mon }
local _, forgedErr = oak.buildTeam(game, forged)
eq(forgedErr, "untrusted_source",
  "builder accepts only rows resolved from the real party/archive registry")

local short = { sources[1], sources[2], sources[3], sources[4], sources[5] }
local _, shortErr = oak.buildTeam(game, short)
eq(shortErr, "exactly_six_required", "five selections cannot start the beta trial")
local duplicate = { sources[1], sources[2], sources[3], sources[4], sources[5], sources[1] }
local _, duplicateErr = oak.buildTeam(game, duplicate)
eq(duplicateErr, "duplicate_source", "same current/archive identity cannot be selected twice")
sources[1].mon.ghost = true
local _, ghostErr = oak.buildTeam(game, sources)
eq(ghostErr, "ghost_or_missing_mon", "ghost state is fail-closed")
sources[1].mon.ghost = nil
sources[2].mon.moves[1].id = "NOT_A_MOVE"
local _, moveErr = oak.buildTeam(game, sources)
eq(moveErr, "invalid_move_state", "unknown move state is fail-closed")
sources[2].mon.moves[1].id = "TACKLE"
sources[2].mon.moves[1].id = "SPLASH"
local _, illegalLearnErr = oak.buildTeam(game, sources)
eq(illegalLearnErr, "invalid_move_state",
  "known but species-illegal moves are fail-closed")
sources[2].mon.moves[1].id = "TACKLE"
sources[3].mon.heldItem = "MASTER_BALL"
local _, itemErr = oak.buildTeam(game, sources)
eq(itemErr, "invalid_held_item_state", "foreign held-item state is fail-closed")
sources[3].mon.heldItem = nil

local npc = { frozen = false, facePlayer = function() end }
local ow = { player = {}, pushBattle = function(_, battle) pushed = battle end,
  afterBattle = function(_, result) eq(result, "win", "only wins enter normal overworld continuation") end }
local started, battle = oak.startBattle(game, ow, npc, sources)
ok(started, "fully completed paths can start the dedicated Oak battle")
ok(game.data.trainers.KA_OAK_BETA ~= nil, "Oak uses an isolated runtime trainer record")
eq(game.data.trainers.KA_OAK_BETA.baseMoney, 0, "Oak beta has no prize-money source")
eq(created.class, "KA_OAK_BETA", "battle uses no Elite/Champion trainer class")
eq(created.index, 1, "battle uses dedicated deterministic party index")
ok(battle.ascendantOakBeta and battle.noPrizeMoney,
  "battle exposes dedicated no-prize context rather than generic metrics")
ok(game.save.party ~= originalParty, "only battle copies replace the runtime party")
local boss = created.boss
eq(#boss, 6, "actual trainer.party hook supplies all six authored boss slots")
eq(boss[1].moves[1], "BODY_SLAM", "actual boss hook supplies authored move data")
battle.onFinish("lose")
eq(game.save.party, originalParty, "loss restores the exact original party atomically")
eq(completeCalls, 0, "loss grants no title or reward")
ok(pushed and pushed.text:find("restored", 1, true), "loss leaves a clear rematch-safe message")
battle.onFinish("win")
eq(completeCalls, 0, "a duplicate finish callback cannot turn a loss into a reward")

local failingOw = { player = {}, pushBattle = function() error("renderer failed") end }
npc.frozen = true
local failedStart, failedStartErr = oak.startBattle(game, failingOw, npc, sources)
eq(failedStart, false, "battle presentation failure is reported")
eq(failedStartErr, "battle_presentation_failed",
  "battle presentation has an explicit rollback error")
eq(game.save.party, originalParty,
  "presentation failure restores the exact party before returning")
ok(not npc.frozen, "presentation failure releases Oak")

started, battle = oak.startBattle(game, ow, npc, sources)
ok(started, "restored team can immediately retry")
battle.onFinish("win")
eq(game.save.party, originalParty, "win also restores the exact original party")
eq(completeCalls, 1, "first win seals the persistent reward exactly once")
ok(pushed and pushed.text:find("LEGACY KEEPER", 1, true),
  "first win announces the permanent title in player-facing language")

profile.legacyPass = false
journey.completeFinale = function() return false, "simulated write failure" end
started, battle = oak.startBattle(game, ow, npc, sources)
ok(started, "reward write-failure scenario reaches the real battle callback")
battle.onFinish("win")
eq(game.save.party, originalParty,
  "reward write failure still restores the exact borrowed party")
ok(not profile.legacyPass and pushed.text:find("No reward saved", 1, true),
  "failed persistent reward stays ungranted and gives a safe retry message")
journey.completeFinale = function()
  completeCalls = completeCalls + 1
  profile.legacyPass = true
  return true
end
started, battle = oak.startBattle(game, ow, npc, sources)
ok(started, "failed reward can be retried safely")
battle.onFinish("win")
eq(completeCalls, 2, "retry after failed write records one later successful reward")

started, battle = oak.startBattle(game, ow, npc, sources)
ok(started, "completed finale permits an explicit no-reward rematch")
battle.onFinish("win")
eq(completeCalls, 2, "rematch never duplicates the persistent reward")
ok(pushed and pushed.text:find("No prize", 1, true), "rematch rule is explicit")

local createdLists = {}
mod.ui.ListMenu = { new = function(_, title, items, opts)
  local list = { title = title, items = items, onChoose = opts.onChoose,
    onCancel = opts.onCancel }
  function list:close() self.closed = true end
  createdLists[#createdLists + 1] = list
  return list
end }
profile.legacyPass = false
npc.frozen = true
ok(oak.openBuilder(game, ow, npc), "real list-menu builder opens for complete paths")
local firstList = createdLists[#createdLists]
firstList.onChoose(firstList.items[1])
ok(firstList.closed, "each selection closes its prior list before rebuilding")
eq(#createdLists, 2, "one selection creates exactly one replacement list")
local currentList = createdLists[#createdLists]
currentList.onCancel()
ok(not npc.frozen, "builder cancel releases Oak without mutating the team")
eq(game.save.party, originalParty, "builder cancel preserves the exact current party")

profile.completedPaths.green = false
local blocked, blockedErr = oak.startBattle(game, ow, npc, sources)
eq(blocked, false, "missing one path blocks Oak before team mutation")
eq(blockedErr, "paths_incomplete", "all three path completion is the only gate")
eq(game.save.party, originalParty, "blocked start keeps current party untouched")

print(("legacy Oak finale: %d assertions"):format(assertions))
