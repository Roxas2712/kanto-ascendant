-- Full-engine contract for Ascendant's private #252-279 data package.
--
-- Run from Gen1 Recomp:
--   TRAINER_REMATCH_MOD_DIR=mods/ka_rc11_integration \
--     ./.tools/luajit-src/src/luajit \
--     /path/to/tests/legacy_252_279_data_engine_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
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
local function contains(rows, wanted)
  for _, value in ipairs(rows or {}) do
    local id = type(value) == "table" and (value.id or value.move) or value
    if id == wanted then return true end
  end
  return false
end
local function countKeys(rows)
  local count = 0
  for _ in pairs(rows or {}) do count = count + 1 end
  return count
end

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
local run = T.sdk.loadMod(modPath, { data = Data })
eq(#(run.errors or {}), 0, "the real engine accepts the complete mod graph")
local ex = assert(run.loader.exports.kanto_ascendant)
local hoenn = assert(ex.legacyHoenn)
local hevo = assert(ex.hevoSpecies)
local fieldTech = assert(ex.fieldTech)
local daycare = assert(ex.daycare)
local gender = assert(ex.pokemonGender)
local breeding = assert(ex.breedingData)

-- TECH-001 binds to the merged registry, not to a private Hoenn module
-- shortcut. The complete real #252-260 registration must therefore expose
-- exactly nine stages per signature TM and patch all 27 definitions.
do
  local status = fieldTech.starterFamilyStatus()
  eq(status.activeProvider, "registered_hoenn_252_260",
    "the complete real Hoenn registry activates the canonical provider")
  eq(status.generations, 3,
    "the signature family status exposes all three registered generations")
  eq(status.totalStages, 27,
    "the signature family status exposes exactly 27 registered stages")
  for _, moveId in ipairs({
      "FRENZY_PLANT", "BLAST_BURN", "HYDRO_CANNON",
  }) do
    local family = assert(fieldTech.starterFamilies[moveId])
    eq(#family, 9, moveId .. " owns exactly nine registered stages")
    eq(status.cardinality[moveId], 9,
      moveId .. " reports exact nine-stage cardinality")
    for _, species in ipairs(family) do
      check(contains(assert(Data.pokemon[species]).tmhm, moveId),
        species .. " receives real-data " .. moveId .. " compatibility")
    end
  end
end

-- Stable private-Dex ownership and move implementations.
local order = {}
for _, species in ipairs(hoenn.order) do order[#order + 1] = species end
for _, species in ipairs(hevo.order) do order[#order + 1] = species end
eq(#order, 28, "the private extension owns exactly #252-279")
for index, species in ipairs(order) do
  local def = assert(Data.pokemon[species], "missing " .. species)
  eq(def.dex, 251 + index, species .. " keeps its assigned private Dex slot")
end

local rollout = assert(Data.moves.ROLLOUT)
local ancient = assert(Data.moves.ANCIENTPOWER)
local doubleHit = assert(Data.moves.DOUBLE_HIT)
eq(rollout.effect, "ROLLOUT_EFFECT", "Rollout uses its real effect")
eq(rollout.power, 30, "Rollout starts at 30 power")
eq(rollout.accuracy, 90, "Rollout keeps 90 percent accuracy")
eq(rollout.pp, 20, "Rollout keeps 20 PP")
eq(ancient.effect, "ANCIENTPOWER_EFFECT",
  "AncientPower uses its all-stat effect")
eq(ancient.power, 60, "AncientPower keeps 60 power")
eq(ancient.pp, 5, "AncientPower keeps 5 PP")
eq(doubleHit.effect, "ATTACK_TWICE_EFFECT",
  "Double Hit uses the engine's exact-two-hits effect")
eq(doubleHit.multiHit, 2, "Double Hit requests exactly two hits")
eq(doubleHit.power, 35, "Double Hit keeps 35 power per hit")
eq(doubleHit.accuracy, 90, "Double Hit keeps 90 percent accuracy")
check(type(Data.move_effects.ROLLOUT_EFFECT.run) == "function",
  "Rollout has an executable merged effect")
check(type(Data.move_effects.ANCIENTPOWER_EFFECT.run) == "function",
  "AncientPower has an executable merged effect")
eq(Data.move_effects.ATTACK_TWICE_EFFECT.hitCount({ move = doubleHit }), 2,
  "the engine resolves Double Hit to exactly two strikes")

-- Rollout is a real five-hit lock, not a plain-damage placeholder.  Exercise
-- the same effect record, damage hook and BattleState lock API used in battle.
local BattleState = require("src.battle.BattleState")
local Runtime = require("src.mods.Runtime")
local rolloutEffect = Data.move_effects.ROLLOUT_EFFECT
local user = { isPlayer = true }
local moveInst = { id = "ROLLOUT", pp = 20 }
local powers = {}
for turn = 1, 5 do
  hevo.rollout.onMoveUsed({ user = user, move = rollout })
  powers[turn] = Runtime.call("battle.damage", function(ctx)
    return ctx.move.power
  end, { move = rollout, user = user, target = {}, battle = {}, opts = {} })
  rolloutEffect.run({ user = user, move = rollout, moveInst = moveInst,
    battle = { turnCount = turn }, totalDealt = 1 })
  if turn < 5 then
    eq(BattleState.menuLockedAction({}, user), moveInst,
      "Rollout keeps the engine menu locked on hit " .. turn)
  end
end
for index, expected in ipairs({ 30, 60, 120, 240, 480 }) do
  eq(powers[index], expected, "Rollout escalation step " .. index)
end
eq(user.kaHevoRollout, nil, "the fifth Rollout hit ends its sequence")
eq(BattleState.menuLockedAction({}, user), nil,
  "the fifth Rollout hit releases the engine menu")

hevo.rollout.onMoveUsed({ user = user, move = Data.moves.DEFENSE_CURL })
hevo.rollout.onMoveUsed({ user = user, move = rollout })
eq(Runtime.call("battle.damage", function(ctx) return ctx.move.power end,
  { move = rollout, user = user, target = {}, battle = {}, opts = {} }), 60,
  "Defense Curl doubles Rollout's first step")
rolloutEffect.run({ user = user, move = rollout, moveInst = moveInst,
  battle = { turnCount = 6 }, totalDealt = 1 })
hevo.rollout.onTurnEnded({ battle = {
  turnCount = 7, player = user, enemy = {},
} })
eq(user.kaHevoRollout, nil,
  "a missed or interrupted continuation clears Rollout")
hevo.rollout.onMoveUsed({ user = user, move = rollout })
rolloutEffect.run({ user = user, move = rollout, moveInst = moveInst,
  battle = { turnCount = 8 }, totalDealt = 1 })
hevo.rollout.onMoveUsed({ user = user, move = Data.moves.TACKLE })
eq(user.kaHevoRollout, nil, "choosing another move clears Rollout state")

-- Drive the merged record through BattleState itself: the first turn spends
-- one real PP, all four continuations use the engine lock, and a fifth hit
-- releases it. The low-level attacker keeps the high-level target alive so
-- every continuation reaches the registered damage/effect pipeline.
do
  local Pokemon = require("src.pokemon.Pokemon")
  local battleMon = Pokemon.new(Data, "MAMOSWINE", 5)
  battleMon.moves = { { id = "ROLLOUT", pp = 20 } }
  local battleGame = {
    data = Data,
    save = {
      options = {}, inventory = {}, party = { battleMon },
      pokedex = { seen = {}, owned = {} }, player = { name = "QA" },
    },
  }
  local battle = BattleState.newWild(battleGame, "SNORLAX", 100)
  battle.rng = function(lo) return lo end
  battle.enemy.mon.hp, battle.enemy.mon.stats.hp = 1000000, 1000000
  battle.enemy.shownHP = battle.enemy.mon.hp
  local liveMove = battle.player.mon.moves[1]
  for hit = 1, 5 do
    battle.turnCount = hit
    battle:performMove(battle.player, battle.enemy,
      BattleState.menuLockedAction(battle, battle.player) or liveMove)
    if hit < 5 then
      check(BattleState.menuLockedAction(battle, battle.player) ~= nil,
        "the real BattleState locks Rollout continuation " .. hit)
      eq(battle.player.kaHevoRollout and battle.player.kaHevoRollout.step,
        hit + 1, "the real BattleState advances Rollout step " .. hit)
    end
  end
  eq(liveMove.pp, 19,
    "the real five-hit Rollout sequence consumes exactly one PP")
  eq(BattleState.menuLockedAction(battle, battle.player), nil,
    "the real BattleState releases Rollout after its fifth hit")

  local doubleMon = Pokemon.new(Data, "AMBIPOM", 5)
  doubleMon.moves = { { id = "DOUBLE_HIT", pp = 10 } }
  local doubleGame = {
    data = Data,
    save = {
      options = {}, inventory = {}, party = { doubleMon },
      pokedex = { seen = {}, owned = {} }, player = { name = "QA" },
    },
  }
  local doubleBattle = BattleState.newWild(doubleGame, "SNORLAX", 100)
  doubleBattle.rng = function(lo) return lo end
  doubleBattle.enemy.mon.hp, doubleBattle.enemy.mon.stats.hp = 1000000, 1000000
  doubleBattle.enemy.shownHP = doubleBattle.enemy.mon.hp
  local strikes = 0
  local unsubscribe = Runtime.events:on("battle.damage_dealt", function(ev)
    if ev.user == doubleBattle.player and ev.move.id == "DOUBLE_HIT" then
      strikes = strikes + 1
    end
  end)
  doubleBattle:performMove(doubleBattle.player, doubleBattle.enemy,
    doubleBattle.player.mon.moves[1])
  unsubscribe()
  eq(strikes, 2,
    "the real BattleState emits exactly two Double Hit damage strikes")
  eq(doubleBattle.player.mon.moves[1].pp, 9,
    "the exact-two-hits pipeline consumes one Double Hit PP")
end

local raised = {}
local boostedMessages = Data.move_effects.ANCIENTPOWER_EFFECT.run({
  user = user,
  rng = function() return 0 end,
  changeStage = function(_, stat, delta)
    raised[#raised + 1] = stat .. ":" .. tostring(delta)
    return { stat .. " rose" }
  end,
})
eq(table.concat(raised, ","),
  "attack:1,defense:1,speed:1,special:1",
  "AncientPower raises every engine battle stat by one stage")
eq(#boostedMessages, 4, "AncientPower exposes all four boost messages")
local procCount = 0
for roll = 0, 9 do
  raised = {}
  local messages = Data.move_effects.ANCIENTPOWER_EFFECT.run({
    user = user, rng = function() return roll end,
    changeStage = function()
      raised[#raised + 1] = true
      return { "rose" }
    end,
  })
  if #raised > 0 then procCount = procCount + 1 end
  eq(#raised, roll == 0 and 4 or 0,
    "AncientPower boost outcome for RNG roll " .. roll)
  eq(#messages, roll == 0 and 4 or 0,
    "AncientPower messages match RNG roll " .. roll)
end
eq(procCount, 1, "AncientPower boosts on exactly one of ten RNG outcomes")

-- Every evolved #261-277 species has at least four implemented, reminder-
-- reachable moves.  The three knowledge-evolution moves retain exact level
-- gates for package consumers.
local game = { data = Data }
for index = 1, 17 do
  local species = hevo.order[index]
  local def = Data.pokemon[species]
  local distinct = {}
  for _, move in ipairs(def.level1Moves or {}) do distinct[move] = true end
  for _, row in ipairs(def.learnset or {}) do distinct[row.move] = true end
  check(countKeys(distinct) >= 4,
    species .. " has at least four distinct implemented moves")
  for move in pairs(distinct) do
    local moveDef = Data.moves[move]
    check(moveDef ~= nil, species .. " references registered move " .. move)
    check(Data.move_effects[moveDef.effect] ~= nil,
      species .. " move has a merged effect " .. move)
  end
  local mon = { species = species, level = 100, moves = {} }
  local candidates = fieldTech.reminderMoves(game, mon)
  check(#candidates >= 4,
    species .. " exposes four useful moves through the shared Reminder")
  local taught = candidates[1] and candidates[1].id
  check(taught and fieldTech.rememberMove(game, mon, taught),
    species .. " can learn a legal Reminder candidate")
  eq(mon.moves[1].pp, Data.moves[taught].pp,
    species .. " receives the move's real PP through the Reminder")
end
check(not contains(fieldTech.reminderMoves(game,
  { species = "AMBIPOM", level = 31, moves = {} }), "DOUBLE_HIT"),
  "Ambipom cannot remember Double Hit before level 32")
check(contains(fieldTech.reminderMoves(game,
  { species = "AMBIPOM", level = 32, moves = {} }), "DOUBLE_HIT"),
  "Ambipom remembers Double Hit at level 32")
check(contains(fieldTech.reminderMoves(game,
  { species = "TANGROWTH", level = 33, moves = {} }), "ANCIENTPOWER"),
  "Tangrowth remembers AncientPower at level 33")
check(contains(fieldTech.reminderMoves(game,
  { species = "LICKILICKY", level = 33, moves = {} }), "ROLLOUT"),
  "Lickilicky remembers Rollout at level 33")

-- TM/HM lists contain actual machine moves and drive the regular item path.
local machineMoves = {}
for _, item in pairs(Data.items or {}) do
  if item.machine then machineMoves[item.machine.move] = true end
end
for _, species in ipairs(order) do
  local seen = {}
  for _, move in ipairs(Data.pokemon[species].tmhm or {}) do
    check(machineMoves[move], species .. " TM/HM row is backed by a machine")
    check(not seen[move], species .. " TM/HM row has no duplicate " .. move)
    seen[move] = true
  end
  check(next(seen) ~= nil, species .. " has an authored TM/HM contract")
end
local ItemEffects = require("src.inventory.ItemEffects")
local save = { player = { name = "QA" } }
local function machineResult(species, item)
  return ItemEffects.use(Data, save, item,
    { species = species, moves = {} })
end
local result, move = machineResult("SCEPTILE", "TM_SOLARBEAM")
eq(result, "learn", "Sceptile accepts its regular SolarBeam TM")
eq(move, "SOLARBEAM", "Sceptile receives SolarBeam from the item path")
result, move = machineResult("MAGNEZONE", "TM_THUNDERBOLT")
eq(result, "learn", "Magnezone accepts its regular Thunderbolt TM")
eq(move, "THUNDERBOLT", "Magnezone receives Thunderbolt")
result, move = machineResult("WYNAUT", "TM_COUNTER")
eq(result, "learn", "Wynaut's narrow Counter compatibility is usable")
eq(move, "COUNTER", "Wynaut receives Counter from the item path")

-- Gender, Egg Groups, hatch counters and the two new baby-family roots.
for dex = 252, 279 do
  local row = breeding[dex]
  check(type(row) == "table", "breeding metadata exists for #" .. dex)
  check(type(row.gender) == "number", "gender ratio exists for #" .. dex)
  check(type(row.hatch) == "number" and row.hatch > 0,
    "hatch counter exists for #" .. dex)
  check(type(row.groups) == "table" and #row.groups > 0,
    "Egg Group exists for #" .. dex)
end
eq(gender.getMonGender({ species = "AMBIPOM", dvs = { attack = 0 } }, game),
  gender.FEMALE, "Ambipom uses its 50-percent Gen-II gender ratio")
eq(gender.getMonGender({ species = "AMBIPOM", dvs = { attack = 15 } }, game),
  gender.MALE, "Ambipom derives male gender from its Attack DV")
eq(gender.getMonGender({ species = "MAGNEZONE", dvs = { attack = 0 } }, game),
  gender.GENDERLESS, "Magnezone remains genderless")
local femaleAmbipom = { species = "AMBIPOM", otId = 1,
  dvs = { attack = 0, defense = 1, special = 1 } }
local maleAmbipom = { species = "AMBIPOM", otId = 2,
  dvs = { attack = 15, defense = 2, special = 2 } }
check(daycare.compatible(game, femaleAmbipom, maleAmbipom),
  "new Egg Group metadata participates in Daycare compatibility")
eq(daycare.babyFor(game, "MARILL"), "AZURILL",
  "Marill eggs make Azurill available")
eq(daycare.babyFor(game, "AZUMARILL"), "AZURILL",
  "Azumarill eggs make Azurill available")
eq(daycare.babyFor(game, "WOBBUFFET"), "WYNAUT",
  "Wobbuffet eggs make Wynaut available")
check(not daycare.compatible(game,
  { species = "AZURILL", dvs = { attack = 0, defense = 3, special = 3 } },
  { species = "DITTO", dvs = { attack = 0, defense = 4, special = 4 } }),
  "Azurill remains a no-eggs baby")
check(not daycare.compatible(game,
  { species = "WYNAUT", dvs = { attack = 0, defense = 3, special = 3 } },
  { species = "DITTO", dvs = { attack = 0, defense = 4, special = 4 } }),
  "Wynaut remains a no-eggs baby")
eq(Data.pokemon.AZURILL.evolutions[1].method, "FRIENDSHIP",
  "Azurill keeps its own friendship evolution")
eq(Data.pokemon.AZURILL.evolutions[1].species, "MARILL",
  "Azurill evolves into Marill")
eq(Data.pokemon.WYNAUT.evolutions[1].level, 15,
  "Wynaut keeps its own level-15 evolution")
eq(Data.pokemon.WYNAUT.evolutions[1].species, "WOBBUFFET",
  "Wynaut evolves into Wobbuffet")

-- All authored texts are bilingual and species-specific. Registration and
-- the late audio install must not manufacture Pokédex progress.
local english, german = {}, {}
for _, species in ipairs(hevo.order) do
  local row = assert(hevo.catalogue[species])
  check(row.kindEn ~= "" and row.kindDe ~= "",
    species .. " has bilingual category metadata")
  check(not english[row.textEn], species .. " has a unique English Dex text")
  check(not german[row.textDe], species .. " has a unique German Dex text")
  english[row.textEn], german[row.textDe] = species, species
  local def = Data.pokemon[species]
  check(def.dexEntry.heightM > 0 and def.dexEntry.weightKg > 0,
    species .. " keeps physical Dex metadata")
  local rendered = assert(Data.text[def.dexEntry.text])
  for line in rendered:gmatch("[^\n]+") do
    check(hevo.wrapDexText(line) == line,
      species .. " Dex line fits the 18-glyph description column")
  end
  for line in hevo.wrapDexText(row.textDe):gmatch("[^\n]+") do
    check(hevo.wrapDexText(line) == line,
      species .. " German Dex line fits the 18-glyph description column")
  end
end
local hoennEn, hoennDe = {}, {}
for _, species in ipairs(hoenn.order) do
  local row = hoenn.species[species]
  check(not hoennEn[row.text[1]], species .. " keeps its unique English text")
  check(not hoennDe[row.text[2]], species .. " keeps its unique German text")
  hoennEn[row.text[1]], hoennDe[row.text[2]] = species, species
end

local dexGame = { data = Data, save = { pokedex = { seen = {}, owned = {} } } }
check(hoenn.install(dexGame), "Hoenn data late-install succeeds")
check(hevo.install(dexGame), "HEVO data late-install succeeds")
eq(countKeys(dexGame.save.pokedex.seen), 0,
  "loading Dex data never marks a species seen")
eq(countKeys(dexGame.save.pokedex.owned), 0,
  "loading Dex data never marks a species owned")

print(("LEGACY #252-279 DATA PASS: %d assertions"):format(assertions))
