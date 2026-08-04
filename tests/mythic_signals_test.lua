-- Production regression suite for Mythic Signals.
--
-- Run from the Gen1 Recomp checkout:
--   TRAINER_REMATCH_MOD_DIR=../kanto-signals-staging \
--   ./.tools/luajit-src/src/luajit \
--   ../kanto-signals-staging/tests/mythic_signals_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Hooks = require("src.mods.Hooks")
local Events = require("src.mods.Events")
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "../kanto-signals-staging"
local makeMythicSignals =
  assert(loadfile(modPath .. "/mythic_signals.lua"))()

local BADGES = {
  "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
  "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
}

local NATIVE_DEF = {
  grass = {
    rate = 25,
    slots = {
      { species = "RATTATA", level = 5 },
      { species = "PIDGEY", level = 4 },
    },
  },
}

local function nativeOut()
  return { species = "RATTATA", level = 5 }
end

local function maxRng(_, maximum)
  return maximum
end

local function minRng(minimum)
  return minimum
end

local function context(rng)
  return {
    mapId = "ROUTE_1",
    terrain = "grass",
    rng = rng or maxRng,
  }
end

local function addBadges(game, count)
  for index = 1, count do
    game.save.inventory[BADGES[index]] = 1
  end
end

local function makeState(root, controls)
  root = root or { resonance = {} }
  root.resonance = root.resonance or {}
  controls = controls or {}
  local adapter = { persists = 0, installs = 0 }
  function adapter.section(name)
    assert(name == "resonance", "unexpected section " .. tostring(name))
    return root.resonance
  end
  function adapter.persist()
    adapter.persists = adapter.persists + 1
    if controls.failPersist then error("synthetic save failure") end
    return true
  end
  function adapter.install()
    adapter.installs = adapter.installs + 1
  end
  adapter.root = root
  return adapter
end

local function makeHarness(opts)
  opts = opts or {}
  local hooks, events = Hooks.new(), Events.new()
  local optionRows = {
    mythic_signals = opts.systemOption,
    legend_mew = opts.mewOption,
    legend_celebi = opts.celebiOption,
  }
  local modSave = opts.modSave or {}
  local marked = {}
  local stateAdapter = opts.stateAdapter
    or makeState(opts.root, opts.stateControls)
  local repaired = opts.repaired == true
  local receiverRepaired = opts.receiverRepaired == true
  local language = opts.language or "en"
  local content = opts.content or {
    ITEMS = { RESONANCE_SEAL = "RESONANCE_SEAL" },
    markCanonicalCaught = function(species)
      marked[#marked + 1] = species
      return true
    end,
  }
  local mod = {
    hooks = hooks,
    events = events,
    options = {
      get = function(_, key) return optionRows[key] end,
    },
    save = {
      get = function(_, key) return modSave[key] end,
      set = function(_, key, value) modSave[key] = value end,
    },
  }
  local game = opts.game or {
    data = {
      pokemon = {
        MEW = {
          name = "MEW",
          baseStats = {
            hp = 100, attack = 100, defense = 100,
            speed = 100, special = 100,
          },
        },
        CELEBI = {
          name = "CELEBI",
          baseStats = {
            hp = 100, attack = 100, defense = 100,
            speed = 100, special = 100,
          },
        },
      },
    },
    save = {
      flags = { EVENT_GOT_POKEDEX = true },
      inventory = {},
      bagOrder = {},
      party = { { level = 20 } },
      pokedex = { seen = {}, owned = {} },
    },
  }
  local battleState = opts.battleState or {
    throwBall = function(battle, ball)
      battle.vanillaBall = ball
      return "vanilla-ball"
    end,
    endOfTurn = function(battle)
      battle.residualSnapshot = {
        status = battle.enemy and battle.enemy.mon.status,
        toxicCounter = battle.enemy and battle.enemy.toxicCounter,
        leechSeeded = battle.enemy and battle.enemy.leechSeeded,
      }
      return "vanilla-turn"
    end,
    applyDamage = function(_, target, damage)
      if target.substituteHP then
        target.substituteHP = target.substituteHP - damage
        if target.substituteHP <= 0 then target.substituteHP = nil end
        return damage
      end
      local dealt = math.min(damage, target.mon.hp)
      target.mon.hp = target.mon.hp - dealt
      return dealt
    end,
  }
  local stats = opts.stats or {
    calc = function(_, level, dvs)
      return {
        hp = 100 + level + (dvs.hp or 0),
        attack = 100, defense = 100, speed = 100, special = 100,
      }
    end,
  }
  local controller = makeMythicSignals(mod, {
    state = stateAdapter,
    content = content,
    johtoSignals = {
      state = function()
        return {
          repaired = repaired,
          receiverRepaired = receiverRepaired,
        }
      end,
    },
    i18n = {
      text = function(english, german)
        return language == "de" and german or english
      end,
    },
  })
  controller.install(game, {
    battleState = battleState,
    stats = stats,
  })

  local H = {
    hooks = hooks,
    events = events,
    mod = mod,
    game = game,
    state = stateAdapter,
    root = stateAdapter.root,
    controller = controller,
    battleState = battleState,
    marked = marked,
    options = optionRows,
    content = content,
  }
  function H.setRepaired(value) repaired = value == true end
  function H.setReceiverRepaired(value)
    receiverRepaired = value == true
  end
  function H.setLanguage(value) language = value end
  function H.roll(out, ctx, def)
    return hooks:call("encounter.roll",
      function() return out or nativeOut() end,
      def or NATIVE_DEF, ctx or context())
  end
  return H
end

local function wildBattle(game, species, hp, level)
  local mon = {
    species = species,
    level = level or 60,
    dvs = { attack = 1, defense = 2, speed = 3, special = 4, hp = 5 },
    statExp = {},
    stats = { hp = 120, attack = 1, defense = 1, speed = 1, special = 1 },
    hp = hp or 10,
    status = nil,
  }
  return {
    game = game,
    data = game.data,
    kind = "wild",
    enemy = {
      mon = mon,
      curStats = mon.stats,
      shownHP = mon.hp,
    },
    sayNext = function(self, text) self.lastText = text end,
  }
end

-- ------------------------------------------------ pure proposal transaction

do
  local h = makeHarness()
  local s = h.controller.state()
  local replacement, transaction = h.controller.rollReplacement(
    nativeOut(), NATIVE_DEF, context(maxRng), h.game)
  T.eq(replacement.species, "RATTATA",
    "a failed pure proposal preserves the native encounter")
  T.neq(transaction, nil,
    "an eligible failed roll still proposes a persistent pity delta")
  T.eq(s.echoRolls, 0,
    "rollReplacement never mutates the live state")
  T.eq(h.controller.pending(), nil,
    "rollReplacement never installs runtime pending data")
  T.eq(h.controller.cancel(transaction), true,
    "cancel accepts an untouched proposal")
  T.eq(s.echoRolls, 0,
    "cancel leaves the live pity counter unchanged")
  T.eq(h.controller.commit(transaction), false,
    "a cancelled proposal cannot later be committed")

  local success, successTx = h.controller.rollReplacement(
    nativeOut(), NATIVE_DEF, context(minRng), h.game)
  T.eq(success.species, "MEW",
    "a deterministic successful proposal selects Mew")
  T.eq(h.controller.state().echoRolls, 0,
    "a successful proposal is still pure before commit")
  local committed, ticket =
    h.controller.commitWildsSpawn(successTx, "MEW", 60)
  T.eq(committed, true,
    "commitWildsSpawn accepts the exact proposed species and level")
  T.eq(ticket.species, "MEW",
    "commitWildsSpawn returns the exact proposed battle ticket")
  local spawned = wildBattle(h.game, "MEW", 10, 60)
  T.eq(h.controller.applyBattleTicket(spawned, ticket), true,
    "Wilds can apply the committed ticket to its constructed battle")
  T.eq(spawned.noCatch, true,
    "the public ticket helper applies all echo battle rules")
  T.eq(h.controller.pending(), nil,
    "the pure Wilds commit does not install stale global pending data")
  T.eq(h.controller.state().echoRolls, 0,
    "a committed manifestation resets its pity counter")
  T.eq(h.controller.commit(successTx), false,
    "a transaction can be committed only once")

  local stale = makeHarness({
    root = { resonance = { sealed = true, trueRolls = 0 } },
  })
  local _, oldMiss = stale.controller.rollReplacement(
    nativeOut(), NATIVE_DEF, context(maxRng), stale.game)
  stale.controller.state().trueRolls = 8191
  local trueOut, trueTx = stale.controller.rollReplacement(
    nativeOut(), NATIVE_DEF, context(maxRng), stale.game)
  T.eq(trueOut.kaMythicKind, "true",
    "the newer transaction reaches the true-signal boundary")
  local trueCommitted = stale.controller.commit(trueTx)
  T.neq(trueCommitted, false,
    "the current true-signal transaction commits")
  local boundSpecies = stale.controller.state().bound.species
  local staleResult, staleReason = stale.controller.commit(oldMiss)
  T.eq(staleResult, false,
    "an older visible-spawn transaction cannot commit afterwards")
  T.eq(staleReason, "stale transaction",
    "stale transaction rejection has a stable reason")
  T.eq(stale.controller.state().bound.species, boundSpecies,
    "stale non-hit state cannot erase a newer bound mythical")
end

-- ------------------------------------------------ native/cross-system scope

do
  local h = makeHarness()
  local chain = h.hooks.chains["encounter.roll"]
  T.eq(chain[#chain].priority, -10,
    "Mythic Signals runs at the required late priority")

  local authored = {
    species = "RATTATA", level = 5,
    kaEncounterSource = "early_johto",
  }
  local out = h.roll(authored, context(minRng))
  T.eq(out, authored,
    "a kaEncounterSource result is never replaced")
  T.eq(h.controller.state().echoRolls, 0,
    "protected authored encounters do not advance Mythic pity")

  local protected = {
    species = "RATTATA", level = 5, kaProtected = true,
  }
  T.eq(h.roll(protected, context(minRng)), protected,
    "a kaProtected result is never replaced")
  T.eq(h.roll({ species = "RATTATA", level = 6 }, context(minRng)).level, 6,
    "an authored level not present in the native slot is rejected")
  local indoor = context(minRng)
  indoor.terrain = "indoor"
  T.eq(h.roll(nativeOut(), indoor).species, "RATTATA",
    "indoor encounters are outside Mythic Signals")
  local ctxProtected = context(minRng)
  ctxProtected.kaEncounterSource = "event_archive"
  T.eq(h.roll(nativeOut(), ctxProtected).species, "RATTATA",
    "a protected encounter context is outside Mythic Signals")
  local safari = context(minRng)
  safari.mapId = "SAFARI_ZONE_EAST"
  T.eq(h.roll(nativeOut(), safari).species, "RATTATA",
    "Safari's separate capture rules are outside ordinary Kanto grass")
  T.eq(h.roll({ species = "EKANS", level = 5 }, context(minRng)).species,
    "EKANS", "a non-native output cannot masquerade as a native roll")
end

do
  local forced = makeHarness({
    root = { resonance = { echoRolls = 511 } },
  })
  forced.hooks:wrap("encounter.roll",
    function(nextRoll, encDef, ctx)
      nextRoll(encDef, ctx)
      return {
        species = "CHIKORITA", level = 5,
        kaEncounterSource = "early_johto", kaProtected = true,
      }
    end, 200)
  local migrated = forced.roll(nativeOut(), context(maxRng))
  T.eq(migrated.species, "CHIKORITA",
    "an outer forced Johto encounter may supersede the proposal")
  T.eq(forced.controller.state().echoRolls, 511,
    "the proposal is not committed before battle.started")
  local migrationBattle = wildBattle(forced.game, "CHIKORITA", 10, 5)
  forced.events:emit("battle.started", { battle = migrationBattle })
  T.eq(forced.controller.state().echoRolls, 511,
    "a forced Johto battle cancels Mythic pity without a delta")
  T.eq(migrationBattle.kaMythicSignal, nil,
    "the forced Johto battle never inherits the Mythic ticket")

  local repelled = makeHarness({
    root = { resonance = { echoRolls = 511 } },
  })
  repelled.roll(nativeOut(), context(maxRng))
  T.neq(repelled.controller.pending(), nil,
    "a proposed encounter waits for an actual battle start")
  repelled.events:emit("world.stepped", {})
  T.eq(repelled.controller.pending(), nil,
    "the next field step expires a Repel-suppressed proposal")
  T.eq(repelled.controller.state().echoRolls, 511,
    "field-step expiry consumes no Mythic pity")
  repelled.roll(nativeOut(), context(maxRng))
  repelled.roll({
    species = "RATTATA", level = 5, kaProtected = true,
  }, context(maxRng))
  T.eq(repelled.controller.pending(), nil,
    "the next roll cancels a proposal swallowed by Repel")
  T.eq(repelled.controller.state().echoRolls, 511,
    "Repel consumes neither pity nor a guaranteed echo")

  local slotLoad = makeHarness({
    root = { resonance = { echoRolls = 511 } },
  })
  slotLoad.roll(nativeOut(), context(maxRng))
  T.neq(slotLoad.controller.pending(), nil,
    "a save-slot switch can begin with a runtime proposal present")
  slotLoad.controller.install(slotLoad.game, {
    battleState = slotLoad.battleState,
  })
  T.eq(slotLoad.controller.pending(), nil,
    "install clears runtime proposals at the save-slot boundary")
  T.eq(slotLoad.controller.state().echoRolls, 511,
    "save-slot cleanup never commits the discarded proposal")
  slotLoad.roll(nativeOut(), context(maxRng))
  slotLoad.game.save.pokedex.owned.MEW = true
  local installsBeforeLoad = slotLoad.state.installs
  slotLoad.events:emit("save.loaded", { game = slotLoad.game })
  T.eq(slotLoad.controller.pending(), nil,
    "save.loaded clears a Mythic proposal without a main-module reinstall")
  T.eq(slotLoad.state.installs, installsBeforeLoad + 1,
    "save.loaded selects the new Signals save section")
  T.eq(slotLoad.controller.state().completed.MEW, true,
    "save.loaded synchronizes canonical ownership for the selected slot")

  local miss = makeHarness()
  miss.roll(nativeOut(), context(maxRng))
  T.eq(miss.controller.state().echoRolls, 0,
    "a miss also waits for a real native battle")
  miss.events:emit("battle.started", {
    battle = wildBattle(miss.game, "RATTATA", 10, 5),
  })
  T.eq(miss.controller.state().echoRolls, 1,
    "the miss counter commits when that native battle starts")
end

-- ------------------------------------------------ echo pity and exact cap

do
  local first = makeHarness({
    root = { resonance = { echoRolls = 511 } },
  })
  local echo = first.roll(nativeOut(), context(maxRng))
  T.eq(echo.species, "CELEBI",
    "the 512th first-echo roll is guaranteed")
  T.eq(echo.level, 60,
    "echo level is at least 60 for an early party")
  T.eq(echo.kaProtected, true,
    "a Mythic replacement protects itself from outer systems")
  T.eq(echo.kaEncounterSource, "mythic_signals",
    "a Mythic replacement identifies its source")

  local battle = wildBattle(first.game, "CELEBI", 20)
  first.events:emit("battle.started", { battle = battle })
  T.eq(battle.noCatch, true,
    "an echo is uncatchable")
  T.eq(battle.kaMythicFleeAt, 3,
    "the successful roll persists a deterministic 1-3 turn escape")
  first.events:emit("battle.turn_ended", { battle = battle })
  T.eq(battle.result, nil, "a three-turn echo stays for turn one")
  first.events:emit("battle.turn_ended", { battle = battle })
  T.eq(battle.result, nil, "a three-turn echo stays for turn two")
  first.events:emit("battle.turn_ended", { battle = battle })
  T.eq(battle.result, "run", "a three-turn echo escapes on turn three")
  first.events:emit("battle.ended", { battle = battle, result = "run" })
  first.events:emit("battle.ended", { battle = battle, result = "run" })
  T.eq(first.controller.state().echoes, 1,
    "one witnessed battle counts once even if teardown repeats")

  local later = makeHarness({
    root = { resonance = { echoes = 1, echoRolls = 2047 } },
  })
  T.neq(later.roll(nativeOut(), context(maxRng)).species, "RATTATA",
    "the 2048th later echo is guaranteed")

  local lowPressure = makeHarness({
    root = { resonance = { echoes = 1, echoRolls = 100 } },
  })
  local highPressure = makeHarness({
    root = { resonance = { echoes = 1, echoRolls = 1535 } },
  })
  T.eq(lowPressure.controller.statusData().echoOdds, 2048,
    "later echo pressure begins at 1/2048")
  T.eq(highPressure.controller.statusData().echoOdds, 1024,
    "later echo pressure visibly rises to 1/1024 by roll 1536")

  local capped = makeHarness({
    root = { resonance = { echoes = 3, echoRolls = 17 } },
  })
  T.eq(capped.roll(nativeOut(), context(minRng)).species, "RATTATA",
    "exactly three echoes stop further omen replacement")
  T.eq(capped.controller.state().echoRolls, 17,
    "the stopped echo system does not silently keep counting")

  local strongParty = makeHarness()
  strongParty.game.save.party[1].level = 95
  T.eq(strongParty.controller.echoLevel(strongParty.game), 100,
    "echo scaling caps party level plus twenty at 100")
end

-- ------------------------------------------------ pending consumption

do
  local h = makeHarness()
  h.roll(nativeOut(), context(minRng))
  local wrong = wildBattle(h.game, "PIDGEY")
  h.events:emit("battle.started", { battle = wrong })
  T.eq(h.controller.pending(), nil,
    "the immediately next mismatched battle consumes pending")
  local late = wildBattle(h.game, "MEW")
  h.events:emit("battle.started", { battle = late })
  T.eq(late.kaMythicEcho, nil,
    "a later matching battle never inherits stale pending data")
end

-- ------------------------------------------------ option/owned/Dex filtering

do
  local disabled = makeHarness({ systemOption = false })
  T.eq(disabled.roll(nativeOut(), context(minRng)).species, "RATTATA",
    "the global Mythic option disables all replacements")

  local mewOff = makeHarness({ mewOption = false })
  T.eq(mewOff.roll(nativeOut(), context(minRng)).species, "CELEBI",
    "a disabled Mew setting filters Mew from the pool")

  local bothOff = makeHarness({ mewOption = false, celebiOption = false })
  T.eq(bothOff.roll(nativeOut(), context(minRng)).species, "RATTATA",
    "no enabled species means no Mythic encounter")
  T.eq(bothOff.controller.statusData().complete, true,
    "disabled species count as no remaining targets")

  local ownedGame = makeHarness()
  ownedGame.game.save.pokedex.owned.MEW = true
  ownedGame.controller.install(ownedGame.game, {
    battleState = ownedGame.battleState,
  })
  T.eq(ownedGame.controller.state().completed.MEW, true,
    "an already-owned Mew is imported as completed")
  T.eq(ownedGame.marked[#ownedGame.marked], "MEW",
    "owned species repair the existing canonical event state")
  T.eq(ownedGame.game.save.pokedex.seen.MEW, nil,
    "owned-state synchronization never prefills Dex seen data")
  T.eq(ownedGame.roll(nativeOut(), context(minRng)).species, "CELEBI",
    "owned Mew is removed from future echo selection")

  local noDex = makeHarness()
  noDex.game.save.flags.EVENT_GOT_POKEDEX = nil
  T.eq(noDex.roll(nativeOut(), context(minRng)).species, "RATTATA",
    "signals remain dormant until Oak gives the Pokédex")
end

-- ------------------------------------------------ damage/status/ball safety

do
  local h = makeHarness()
  h.roll(nativeOut(), context(minRng))
  local battle = wildBattle(h.game, "MEW", 10)
  h.events:emit("battle.started", { battle = battle })
  local direct, directInfo = h.hooks:call("battle.damage",
    function() return 99, { crit = true, random = 252 } end,
    { battle = battle, target = battle.enemy, user = {} })
  T.eq(direct, 9,
    "direct move damage leaves an echo at one HP")
  T.eq(directInfo.crit, true,
    "echo damage protection preserves Damage.compute metadata")
  T.eq(directInfo.random, 252,
    "echo damage protection preserves the complete info table")
  local confusion = h.hooks:call("battle.damage",
    function() return 99 end,
    { battle = battle, target = battle.enemy, user = battle.enemy,
      move = { id = "CONFUSED" } })
  T.eq(confusion, 9,
    "confusion self-damage also leaves an echo at one HP")
  T.eq(h.battleState.applyDamage(battle, battle.enemy, direct), 9,
    "the first hit applies the capped echo damage")
  T.eq(h.battleState.applyDamage(battle, battle.enemy, direct), 0,
    "a second multi-hit strike cannot remove the echo's last HP")
  T.eq(battle.enemy.mon.hp, 1,
    "per-hit damage protection leaves the echo at exactly one HP")
  battle.enemy.substituteHP = 12
  T.eq(h.battleState.applyDamage(battle, battle.enemy, 5), 5,
    "echo protection does not make an active SUBSTITUTE invulnerable")
  T.eq(battle.enemy.substituteHP, 7,
    "SUBSTITUTE damage remains entirely vanilla")

  battle.enemy.mon.status = "PSN"
  battle.enemy.toxicCounter = 4
  battle.enemy.leechSeeded = true
  h.battleState.endOfTurn(battle)
  T.eq(battle.residualSnapshot.status, nil,
    "Poison/Burn status is cleared immediately before residual")
  T.eq(battle.residualSnapshot.toxicCounter, nil,
    "Toxic's residual multiplier is cleared before residual")
  T.eq(battle.residualSnapshot.leechSeeded, nil,
    "Leech Seed is cleared before residual")

  -- Simulate BagMenu's real order: it consumes the final ball first.
  battle.game.save.inventory.MASTER_BALL = nil
  h.battleState.throwBall(battle, "MASTER_BALL")
  T.eq(battle.game.save.inventory.MASTER_BALL, 1,
    "an echo returns the already-consumed Master Ball")
  T.eq(battle.kaMythicMasterBallReturned, true,
    "the battle records the Master Ball return")
  T.eq(battle.vanillaBall, "MASTER_BALL",
    "the protected throw still uses vanilla noCatch presentation")

  local ordinary = wildBattle(h.game, "MEW")
  ordinary.game.save.inventory.MASTER_BALL = nil
  h.battleState.throwBall(ordinary, "MASTER_BALL")
  T.eq(ordinary.game.save.inventory.MASTER_BALL, nil,
    "ordinary encounters do not mint Master Balls")
end

-- ------------------------------------------------ researcher seal gates

do
  local h = makeHarness({
    root = { resonance = { echoes = 3 } },
    repaired = false,
  })
  addBadges(h.game, 4)
  local can, reason = h.controller.researcherCanSeal(h.game)
  T.eq(can, false, "three echoes and four badges are not enough alone")
  T.eq(reason, "sender", "the unrepaired Johto sender blocks sealing")

  h.setRepaired(true)
  h.game.save.inventory[BADGES[4]] = nil
  can, reason = h.controller.researcherCanSeal(h.game)
  T.eq(can, false, "three badges cannot stabilize the seal")
  T.eq(reason, "badges", "the researcher reports the badge gate")

  h.game.save.inventory = {}
  h.game.save.bagOrder = {}
  addBadges(h.game, 4)
  for index = 1, 20 do
    local item = "FULL_SLOT_" .. index
    h.game.save.inventory[item] = 1
    h.game.save.bagOrder[#h.game.save.bagOrder + 1] = item
  end
  local ok, sealedReason = h.controller.researcherSeal(h.game)
  T.eq(ok, true, "the researcher seals after sender repair and four badges")
  T.eq(sealedReason, "sealed", "a new key item reports a fresh seal")
  T.eq(h.game.save.inventory.RESONANCE_SEAL, 1,
    "the key item is granted even when all 20 Bag slots are occupied")
  T.eq(h.controller.state().sealed, true,
    "the state becomes sealed only alongside the key item")
  T.eq(h.controller.researcherCanSeal(h.game), false,
    "an existing seal cannot be created twice")
end

do
  local h = makeHarness({
    root = { resonance = { echoes = 3 } },
    receiverRepaired = true,
  })
  addBadges(h.game, 4)
  T.eq(h.controller.researcherCanSeal(h.game), true,
    "the Early Signals receiverRepaired field satisfies the sender gate")
end

do
  local controls = { failPersist = false }
  local adapter = makeState(
    { resonance = { echoes = 3 } }, controls)
  local h = makeHarness({
    stateAdapter = adapter,
    repaired = true,
  })
  addBadges(h.game, 4)
  controls.failPersist = true
  local ok, reason = h.controller.researcherSeal(h.game)
  T.eq(ok, false, "a failed save aborts seal creation")
  T.eq(reason, "save", "the atomic path reports persistence failure")
  T.eq(h.game.save.inventory.RESONANCE_SEAL, nil,
    "an aborted seal rolls the key item back")
  T.eq(h.controller.state().sealed, false,
    "an aborted seal rolls progression back")
end

-- ------------------------------------------------ true pity and persistent retry

do
  local shared = {
    resonance = {
      echoes = 3,
      sealed = true,
      trueRolls = 8191,
    },
  }
  local first = makeHarness({ root = shared, repaired = true })
  addBadges(first.game, 8)
  local manifested = first.roll(nativeOut(), context(maxRng))
  T.eq(manifested.species, "CELEBI",
    "the 8192nd true roll is guaranteed")
  T.eq(manifested.level, 70,
    "an eight-badge true manifestation uses the capped badge tier")
  T.eq(first.controller.state().bound, nil,
    "a true proposal does not bind before the battle really starts")
  T.eq(first.game.save.pokedex.seen.CELEBI, nil,
    "encounter replacement itself does not prefill Dex visibility")

  local battle = wildBattle(first.game, "CELEBI", 40, 70)
  first.events:emit("battle.started", { battle = battle })
  T.eq(battle.kaMythicTrue, "CELEBI",
    "the pending true ticket owns the matching next battle")
  T.eq(battle.noCatch, nil,
    "a true manifestation is catchable after Resonance is sealed")
  T.eq(battle.enemy.mon.dvs.attack, 15,
    "the battle receives the persisted roamer DVs")
  T.eq(first.controller.state().bound.species, "CELEBI",
    "the started manifestation persists its identity")
  T.eq(first.controller.state().bound.dvs.attack, 15,
    "the started roamer persists deterministic DVs")
  T.eq(battle.enemy.mon.hp, battle.enemy.mon.stats.hp,
    "new deterministic DVs recalculate a full initial HP bar")
  battle.enemy.mon.hp = 23
  battle.enemy.mon.status = "PAR"
  battle.enemy.toxicCounter = 2
  first.events:emit("battle.ended", { battle = battle, result = "run" })
  T.eq(first.controller.state().bound.hp, 23,
    "a failed catch persists current roamer HP")
  T.eq(first.controller.state().bound.status, "PAR",
    "a failed catch persists current roamer status")

  -- A fresh controller represents a full save/restart.  Only save state is
  -- shared; the runtime pending ticket is intentionally gone.
  shared.resonance.bound.retryRolls = 31
  local restarted = makeHarness({ root = shared, repaired = true })
  restarted.game.save.inventory = first.game.save.inventory
  restarted.game.save.pokedex = first.game.save.pokedex
  local retry = restarted.roll(nativeOut(), context(maxRng))
  T.eq(retry.species, "CELEBI",
    "the 32nd retry roll is guaranteed after restart")
  T.eq(retry.level, 70,
    "a retry keeps the original manifestation level")
  local retryBattle = wildBattle(restarted.game, "CELEBI", 100, 70)
  restarted.events:emit("battle.started", { battle = retryBattle })
  T.eq(retryBattle.noCatch, nil,
    "a persisted true-manifestation retry remains catchable")
  T.eq(retryBattle.enemy.mon.hp, 23,
    "retry restores persistent HP")
  T.eq(retryBattle.enemy.mon.status, "PAR",
    "retry restores persistent status")
  T.eq(retryBattle.enemy.toxicCounter, 2,
    "retry restores supported Toxic state")

  restarted.events:emit("pokemon.caught", {
    species = "CELEBI", game = restarted.game,
    battle = retryBattle, mon = retryBattle.enemy.mon,
  })
  T.eq(restarted.controller.state().bound, nil,
    "catching the bound species clears the retry roamer")
  T.eq(restarted.controller.state().completed.CELEBI, true,
    "catching marks that species complete")
  T.eq(restarted.marked[#restarted.marked], "CELEBI",
    "catching also marks the existing canonical Celebi event")
end

do
  local h = makeHarness({
    root = {
      resonance = {
        sealed = true,
        echoes = 3,
        bound = {
          species = "MEW", level = 55,
          dvs = { attack = 2, defense = 4, speed = 6, special = 8, hp = 0 },
          hp = 1, retryRolls = 31,
        },
      },
    },
    mewOption = false,
  })
  T.eq(h.roll(nativeOut(), context(maxRng)).species, "RATTATA",
    "disabling a currently bound species retires it safely")
  h.events:emit("battle.started", {
    battle = wildBattle(h.game, "RATTATA", 10, 5),
  })
  T.eq(h.controller.state().bound, nil,
    "a disabled bound species is removed from retry state")
end

-- ------------------------------------------------ hidden names and localization

do
  local h = makeHarness({
    root = {
      resonance = {
        sealed = true,
        echoes = 3,
        bound = {
          species = "MEW", level = 55,
          dvs = { attack = 2, defense = 4, speed = 6, special = 8, hp = 0 },
          hp = 1, retryRolls = 1,
        },
      },
    },
  })
  T.neq(h.controller.status():find("???", 1, true), nil,
    "status hides an unknown bound species as ???")
  T.eq(h.controller.status():find("MEW", 1, true), nil,
    "status never leaks a species before real Dex sighting")
  T.neq(h.controller.researcherDialogue():find("???", 1, true), nil,
    "researcher dialogue also respects Dex visibility")
  h.game.save.pokedex.seen.MEW = true
  T.neq(h.controller.status():find("MEW", 1, true), nil,
    "a real Dex sighting reveals the species name")

  h.setLanguage("de")
  T.neq(h.controller.status():find("GEBUNDEN", 1, true), nil,
    "status has a complete German branch")
  T.neq(h.controller.objective():find("Kantos", 1, true), nil,
    "the active objective has a German branch")
end

do
  local h = makeHarness({
    root = { resonance = { echoes = 3 } },
    repaired = true,
    language = "de",
  })
  addBadges(h.game, 3)
  T.neq(h.controller.researcherDialogue():find("ORDEN", 1, true), nil,
    "researcher gate dialogue localizes the badge requirement")
  T.eq(h.hooks.chains["ui.start_menu.items"], nil,
    "Mythic Signals never installs menu sealing")
  T.eq(h.controller.travel, nil,
    "Mythic Signals contains no warp API")
end

-- ------------------------------------------------ old canonical-save repair

do
  local modSave = {
    ascendant = { mewCaught = false, mewStage = 1 },
    postgame = { catches = {}, roamers = { CELEBI = "ROUTE_2" } },
  }
  local content = {
    ITEMS = { RESONANCE_SEAL = "RESONANCE_SEAL" },
  }
  local h = makeHarness({ content = content, modSave = modSave })
  h.game.save.pokedex.owned.MEW = true
  h.game.save.pokedex.owned.CELEBI = true
  h.controller.install(h.game, { battleState = h.battleState })
  T.eq(modSave.ascendant.mewCaught, true,
    "an old owned Mew completes the canonical Ascendant event")
  T.eq(modSave.ascendant.mewStage, 4,
    "an old owned Mew advances the canonical clue stage")
  T.eq(modSave.postgame.catches.CELEBI, true,
    "an old owned Celebi completes the canonical postgame event")
  T.eq(modSave.postgame.roamers.CELEBI, nil,
    "an old owned Celebi removes the obsolete canonical roamer")
  T.eq(h.controller.statusData().complete, true,
    "a save owning both species is immediately complete")
  h.setLanguage("de")
  T.neq(h.controller.researcherDialogue():find(
      "Beide", 1, true), nil,
    "complete researcher dialogue selects its German branch")
end

do
  local modSave = {}
  local h = makeHarness({
    content = { ITEMS = { RESONANCE_SEAL = "RESONANCE_SEAL" } },
    modSave = modSave,
  })
  h.game.save.pokedex.owned.MEW = true
  h.game.save.pokedex.owned.CELEBI = true
  h.controller.install(h.game, { battleState = h.battleState })
  T.eq(modSave.ascendant.mewCaught, true,
    "canonical Mew completion creates a missing legacy state table")
  T.eq(modSave.ascendant.mewStage, 4,
    "a newly created canonical Mew state is fully advanced")
  T.eq(modSave.postgame.catches.CELEBI, true,
    "canonical Celebi completion creates a missing postgame state table")
end

T.finish("mythic_signals")
