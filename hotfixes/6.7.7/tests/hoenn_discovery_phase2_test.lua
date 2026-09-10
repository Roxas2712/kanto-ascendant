package.path = "./?.lua;./?/init.lua;" .. package.path

local State = require("discovery_state")
local Overlay = require("encounter_overlay")
local HoennModule = require("hoenn_discovery")
local Hoenn = HoennModule.create(State, Overlay)

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  check(actual == expected, (message or "values differ") .. " (got "
    .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function sequence(values, fallback, calls)
  local index = 0
  return function(low, high, purpose)
    index = index + 1
    if calls then
      calls[#calls + 1] = { low = low, high = high, purpose = purpose }
    end
    local value = values[index]
    if value == nil then value = fallback or high end
    return value
  end
end

local REGISTERED = { "TREECKO", "TORCHIC", "MUDKIP" }

-- ---------------------------------------------------------- introduction RNG

do
  local root = State.empty()
  local nextRoot, hit = Hoenn.planIntroduction(root, {
    mapId = "ROUTE_1", eligible = true, registeredFamilies = REGISTERED,
    chanceRoll = 2000, familyRoll = 1, token = "surprise:hit",
  })
  check(hit.introduced and hit.natural and not hit.guaranteed,
    "roll 2000 is inside the exact twenty-percent introduction window")
  eq(hit.family, "TREECKO", "the deterministic family roll chooses Treecko")
  eq(hit.rollsUsed, 2, "a natural introduction consumes chance and family rolls")
  eq(Hoenn.introductionPity(nextRoot), 0,
    "a successful introduction resets global introduction pity")
  eq(State.status(nextRoot, "hoenn", "TREECKO"), "trace",
    "a Surprise introduction opens a trace, not a catch")
  eq(Hoenn.traceMap(nextRoot, "TREECKO"), "ROUTE_1",
    "the new trace is bound to the exact Surprise map")
  eq(State.status(root, "hoenn", "TREECKO"), "unseen",
    "the pure introduction planner never mutates its input")

  local missRoot, miss = Hoenn.planIntroduction(State.empty(), {
    mapId = "ROUTE_1", eligible = true, registeredFamilies = REGISTERED,
    chanceRoll = 2001, familyRoll = 1, token = "surprise:miss",
  })
  check(not miss.introduced and not miss.natural,
    "roll 2001 is outside the exact twenty-percent window")
  eq(miss.rollsUsed, 1, "an introduction miss consumes no family roll")
  eq(Hoenn.introductionPity(missRoot), 1,
    "an eligible Surprise miss advances pity exactly once")
end

do
  local root = State.empty()
  for win = 1, 7 do
    local result
    root, result = Hoenn.planIntroduction(root, {
      mapId = "ROUTE_2", eligible = true,
      registeredFamilies = REGISTERED, chanceRoll = 10000,
      familyRoll = 3, token = "surprise:pity:" .. tostring(win),
    })
    check(not result.introduced, "wins one through seven may miss")
    eq(Hoenn.introductionPity(root), win,
      "the eligible Surprise pity advances through win " .. tostring(win))
  end
  local result
  root, result = Hoenn.planIntroduction(root, {
    mapId = "ROUTE_2", eligible = true, registeredFamilies = REGISTERED,
    chanceRoll = 10000, familyRoll = 3, token = "surprise:pity:8",
  })
  check(result.introduced and result.guaranteed and not result.natural,
    "the eighth eligible Surprise win guarantees an introduction")
  eq(result.family, "MUDKIP", "the guarantee still uses the supplied family roll")
  eq(Hoenn.introductionPity(root), 0,
    "the eighth-win guarantee resets introduction pity")

  local duplicate, duplicateResult = Hoenn.planIntroduction(root, {
    mapId = "ROUTE_2", eligible = true, registeredFamilies = REGISTERED,
    chanceRoll = 1, familyRoll = 1, token = "surprise:pity:8",
  })
  eq(duplicateResult.reason, "duplicate-surprise-win",
    "a retried battle token cannot count the same real win twice")
  eq(Hoenn.introductionPity(duplicate), 0,
    "a duplicate win cannot consume or change pity")
end

do
  local root = State.empty()
  root = select(1, Hoenn.planIntroduction(root, {
    mapId = "ROUTE_3", eligible = true,
    registeredFamilies = { "TREECKO" }, chanceRoll = 1,
    familyRoll = 1, token = "surprise:treecko",
  }))
  root = State.mark(root, "hoenn", "TORCHIC", "caught")
  root = State.unlock(root, "hoenn", "TORCHIC")

  local unseenRoot, unseen = Hoenn.planIntroduction(root, {
    mapId = "ROUTE_4", eligible = true, registeredFamilies = REGISTERED,
    chanceRoll = 1, familyRoll = 1, token = "surprise:unseen-first",
  })
  eq(unseen.family, "MUDKIP",
    "an unseen complete family is selected before every repeat")
  eq(unseen.selectionTier, "unseen", "the selected tier is reviewable")

  local unresolvedRoot, unresolved = Hoenn.planIntroduction(unseenRoot, {
    mapId = "ROUTE_5", eligible = true,
    registeredFamilies = { "TREECKO", "TORCHIC" },
    chanceRoll = 1, familyRoll = 1, token = "surprise:unresolved-first",
  })
  eq(unresolved.family, "TREECKO",
    "an unresolved trace is preferred before a caught repeat")
  eq(unresolved.selectionTier, "unresolved",
    "unresolved preference is explicit in the result")
  eq(Hoenn.traceMap(unresolvedRoot, "TREECKO"), "ROUTE_3",
    "a repeated introduction cannot silently rebind an open trace")
end

do
  local root, result = Hoenn.planIntroduction(State.empty(), {
    mapId = "ROUTE_1", eligible = false, registeredFamilies = REGISTERED,
    chanceRoll = 1, familyRoll = 1, token = "surprise:ineligible",
  })
  eq(result.reason, "ineligible-surprise-win",
    "an ineligible Surprise win never enters the lottery")
  eq(result.rollsUsed, 0, "an ineligible win consumes no RNG")
  eq(Hoenn.introductionPity(root), 0,
    "an ineligible win cannot burn introduction pity")

  root, result = Hoenn.planIntroduction(State.empty(), {
    mapId = "ROUTE_1", eligible = true, registeredFamilies = {},
    chanceRoll = 1, familyRoll = 1, token = "surprise:no-family",
  })
  eq(result.reason, "no-registered-family",
    "an empty complete-family pool fails closed")
  eq(result.rollsUsed, 0, "an empty family pool consumes no RNG")

  root, result = Hoenn.planIntroduction(State.empty(), {
    mapId = "ROUTE_1", eligible = true,
    registeredFamilies = REGISTERED, chanceRoll = 1, familyRoll = 1,
  })
  eq(result.reason, "missing-surprise-token",
    "an unreceipted callback cannot impersonate a real Surprise win")
  eq(result.rollsUsed, 0, "a missing battle token consumes no RNG")
  eq(Hoenn.introductionPity(root), 0,
    "a missing battle token cannot advance Surprise pity")
end

-- ------------------------------------------------------- map-bound overlay

local function traced(family, mapId, pity)
  local root = select(1, Hoenn.planIntroduction(State.empty(), {
    mapId = mapId, eligible = true, registeredFamilies = { family },
    chanceRoll = 1, familyRoll = 1, token = "trace:" .. family,
  }))
  root = State.setSightingPity(root, "hoenn", family, pity or 0)
  return root
end

do
  local root = traced("TREECKO", "ROUTE_1", 17)
  local native = {
    species = "RATTATA", level = 4,
    nested = { identity = "native-row" },
  }
  local output, transaction = Hoenn.planOverlay(root, {
    native = native, mapId = "ROUTE_1",
    registeredFamilies = REGISTERED, roll = 9951, serial = 11,
  })
  eq(output.species, "TREECKO", "roll 9951 begins the exact Hoenn bucket")
  eq(output.level, 4, "the overlay preserves the native encounter level")
  eq(output.kaEncounterSource, "hoenn_discovery",
    "the replacement carries a narrow protected source marker")
  eq(transaction.family, "TREECKO",
    "the transaction identifies the exact trace family")
  eq(State.sightingPity(root, "hoenn", "TREECKO"), 17,
    "proposing a Hoenn encounter commits no pity delta")
  eq(Hoenn.pendingCatch(root, "TREECKO"), nil,
    "a rolled candidate is not yet a pending real catch")
  eq(native.species, "RATTATA", "the canonical native row is unchanged")
  eq(native.nested.identity, "native-row",
    "nested canonical encounter metadata is unchanged")

  local mismatchRoot, committed, reason = Hoenn.commitStarted(root,
    transaction, {
      kind = "wild", encounterSource = "wild",
      species = "PIDGEY", level = 4, mapId = "ROUTE_1",
    })
  check(not committed and reason == "battle-mismatch",
    "a different next battle cancels the uncommitted overlay")
  eq(State.sightingPity(mismatchRoot, "hoenn", "TREECKO"), 17,
    "a mismatched battle cannot reset or advance sighting pity")
  eq(Hoenn.pendingCatch(mismatchRoot, "TREECKO"), nil,
    "a mismatched battle cannot create pending catch state")

  output, transaction = Hoenn.planOverlay(root, {
    native = native, mapId = "ROUTE_1",
    registeredFamilies = REGISTERED, roll = 9951, serial = 12,
  })
  local protectedRoot, protected, protectedReason = Hoenn.commitStarted(
    root, transaction, {
      kind = "wild", encounterSource = "wild", noCatch = true,
      species = output.species, level = output.level, mapId = "ROUTE_1",
    })
  check(not protected and protectedReason == "protected-catch-surface",
    "a no-catch battle cannot impersonate a real wild capture surface")
  eq(State.sightingPity(protectedRoot, "hoenn", "TREECKO"), 17,
    "a protected battle cannot reset or advance sighting pity")
  eq(Hoenn.pendingCatch(protectedRoot, "TREECKO"), nil,
    "a protected battle cannot create persisted pending catch state")

  output, transaction = Hoenn.planOverlay(root, {
    native = native, mapId = "ROUTE_1",
    registeredFamilies = REGISTERED, roll = 9951, serial = 13,
  })
  local startedRoot, committed, started = Hoenn.commitStarted(root, transaction, {
    kind = "wild", encounterSource = "wild",
    species = output.species, level = output.level,
    mapId = "ROUTE_1",
  })
  check(committed and started.sighted,
    "the exact actually-started wild encounter commits its sighting")
  eq(State.sightingPity(startedRoot, "hoenn", "TREECKO"), 0,
    "an actual sighting resets that family's overlay pity")
  local pending = assert(Hoenn.pendingCatch(startedRoot, "TREECKO"))
  eq(pending.serial, 13,
    "pending catch state belongs to the exact started transaction")

  local caughtRoot, caught = Hoenn.completeCatch(startedRoot, {
    family = "TREECKO", species = "TREECKO", mapId = "ROUTE_1",
    serial = 13,
  })
  check(caught and caught.unlocked,
    "the exact real wild catch unlocks the evolutionary family")
  eq(State.status(caughtRoot, "hoenn", "TREECKO"), "unlocked",
    "catch and unlock are committed atomically")
  eq(Hoenn.pendingCatch(caughtRoot, "TREECKO"), nil,
    "a successful catch clears its pending receipt")
end

do
  local root = traced("TREECKO", "ROUTE_1", 0)
  local native = { species = "RATTATA", level = 4 }
  local output, transaction = Hoenn.planOverlay(root, {
    native = native, mapId = "ROUTE_1",
    registeredFamilies = REGISTERED, roll = 9950, serial = 21,
  })
  eq(output.species, "RATTATA", "roll 9950 remains outside the Hoenn bucket")
  local missRoot, committed = Hoenn.commitStarted(root, transaction, {
    kind = "wild", encounterSource = "wild",
    species = "RATTATA", level = 4, mapId = "ROUTE_1",
  })
  check(committed, "an exact native battle commits the eligible miss")
  eq(State.sightingPity(missRoot, "hoenn", "TREECKO"), 1,
    "a real eligible native battle advances overlay pity once")

  root = traced("TREECKO", "ROUTE_1", 49)
  output, transaction = Hoenn.planOverlay(root, {
    native = native, mapId = "ROUTE_1",
    registeredFamilies = REGISTERED, roll = 1, serial = 22,
  })
  eq(output.species, "TREECKO",
    "the 50th eligible map encounter guarantees the trace")
  check(transaction.guaranteed and not transaction.natural,
    "the forced trace is distinguished from a natural 0.5-percent hit")
  local pityRoot = select(1, Hoenn.commitStarted(root, transaction, {
    kind = "wild", encounterSource = "wild",
    species = "TREECKO", level = 4, mapId = "ROUTE_1",
  }))
  eq(State.sightingPity(pityRoot, "hoenn", "TREECKO"), 0,
    "the 50th-encounter sighting resets pity")

  local otherOutput, otherTransaction = Hoenn.planOverlay(root, {
    native = native, mapId = "ROUTE_2",
    registeredFamilies = REGISTERED, roll = 9951, serial = 23,
  })
  eq(otherOutput, native,
    "a trace never overlays a native encounter on a different map")
  eq(otherTransaction, nil,
    "another map creates no transaction and therefore cannot burn pity")
end

do
  local root = traced("TREECKO", "ROUTE_6", 49)
  root = select(1, Hoenn.planIntroduction(root, {
    mapId = "ROUTE_6", eligible = true,
    registeredFamilies = { "TORCHIC" }, chanceRoll = 1,
    familyRoll = 1, token = "trace:torchic:route6",
  }))
  root = State.setSightingPity(root, "hoenn", "TORCHIC", 0)
  local output, transaction = Hoenn.planOverlay(root, {
    native = { species = "PIDGEY", level = 7 }, mapId = "ROUTE_6",
    registeredFamilies = REGISTERED, roll = 9952, serial = 24,
  })
  eq(output.species, "TREECKO",
    "a matured 50th-encounter pity outranks another trace's natural hit")
  check(transaction.guaranteed and not transaction.natural,
    "the forced family remains auditable when the Hoenn bucket also hits")
end

do
  local root = traced("TORCHIC", "ROUTE_7", 5)
  local output, transaction = Hoenn.planOverlay(root, {
    native = { species = "VULPIX", level = 18 }, mapId = "ROUTE_7",
    registeredFamilies = REGISTERED, roll = 9951, serial = 31,
  })
  local startedRoot = select(1, Hoenn.commitStarted(root, transaction, {
    kind = "wild", encounterSource = "wild",
    species = output.species, level = output.level,
    mapId = "ROUTE_7",
  }))
  local closedRoot, closed = Hoenn.closePending(startedRoot, {
    family = "TORCHIC", species = "TORCHIC", mapId = "ROUTE_7",
    serial = 31,
  })
  check(closed, "flee or defeat closes the exact pending catch receipt")
  eq(Hoenn.pendingCatch(closedRoot, "TORCHIC"), nil,
    "an unresolved battle cannot leave a stale pending catch")
  eq(State.status(closedRoot, "hoenn", "TORCHIC"), "trace",
    "flee or defeat keeps the discovered trace open")
  eq(State.sightingPity(closedRoot, "hoenn", "TORCHIC"), 0,
    "the real sighting reset survives flee or defeat")
end

-- ------------------------------------------- complete registered families

local FAMILY_MEMBERS = {
  TREECKO = { "TREECKO", "GROVYLE", "SCEPTILE" },
  TORCHIC = { "TORCHIC", "COMBUSKEN", "BLAZIKEN" },
  MUDKIP = { "MUDKIP", "MARSHTOMP", "SWAMPERT" },
}
local DEX = {
  TREECKO = 252, GROVYLE = 253, SCEPTILE = 254,
  TORCHIC = 255, COMBUSKEN = 256, BLAZIKEN = 257,
  MUDKIP = 258, MARSHTOMP = 259, SWAMPERT = 260,
}
local function registryFixture()
  local game = {
    data = {
      pokemon = {}, audio = { cries = {} },
      encounters = {
        ROUTE_1 = { grass = { rate = 25, slots = {
          { species = "RATTATA", level = 4 },
        } } },
        ROUTE_2 = { grass = { rate = 25, slots = {
          { species = "PIDGEY", level = 5 },
        } } },
      },
    },
  }
  game.data.pokemon.RATTATA = { id = "RATTATA", dex = 19 }
  game.data.pokemon.PIDGEY = { id = "PIDGEY", dex = 16 }
  local order, rows = {}, {}
  for family, members in pairs(FAMILY_MEMBERS) do
    for index, species in ipairs(members) do
      order[#order + 1] = species
      rows[species] = { dex = DEX[species] }
      local evolutions = {}
      if members[index + 1] then
        evolutions[1] = {
          method = "LEVEL", level = index == 1 and 16 or 36,
          species = members[index + 1],
        }
      end
      game.data.pokemon[species] = {
        id = species, name = species, dex = DEX[species],
        types = { family == "TREECKO" and "GRASS"
          or family == "TORCHIC" and "FIRE" or "WATER" },
        baseStats = { hp = 40, attack = 40, defense = 40,
          speed = 40, special = 40 },
        catchRate = 45, growthRate = "MEDIUM_SLOW",
        level1Moves = { "TACKLE" }, learnset = {}, evolutions = evolutions,
        tmhm = {}, cry = species,
        spriteFront = "front/" .. species .. ".png",
        spriteBack = "back/" .. species .. ".png",
        icon = "MON", dexEntry = { kind = "TEST", text = "TEST" },
      }
      game.data.audio.cries[species] = { file = "cry/" .. species .. ".ogg" }
    end
  end
  table.sort(order, function(a, b) return DEX[a] < DEX[b] end)
  local legacyHoenn = { order = order, species = rows }
  local extended = {
    identity = function(species)
      if DEX[species] then
        return { species = species, family = "legacy_hoenn",
          internalRuntimeDex = DEX[species], sourceDex = DEX[species] }
      end
    end,
  }
  return game, legacyHoenn, extended
end

do
  local game, legacyHoenn, extended = registryFixture()
  local families = Hoenn.registeredFamilies(game, {
    legacyHoenn = legacyHoenn, extendedSpeciesRuntime = extended,
  })
  eq(table.concat(families, ","), "TREECKO,TORCHIC,MUDKIP",
    "only the three complete shipped Hoenn starter families are eligible")

  game.data.pokemon.SWAMPERT.spriteBack = nil
  families = Hoenn.registeredFamilies(game, {
    legacyHoenn = legacyHoenn, extendedSpeciesRuntime = extended,
  })
  eq(table.concat(families, ","), "TREECKO,TORCHIC",
    "one missing required surface excludes the whole Mudkip family")

  game.data.pokemon.SWAMPERT.spriteBack = "back/SWAMPERT.png"
  game.data.audio.cries.COMBUSKEN = nil
  families = Hoenn.registeredFamilies(game, {
    legacyHoenn = legacyHoenn, extendedSpeciesRuntime = extended,
  })
  eq(table.concat(families, ","), "TREECKO,MUDKIP",
    "one missing cry excludes the whole Torchic family")

  check(Hoenn.isEligibleNative(game,
    { species = "RATTATA", level = 4 },
    game.data.encounters.ROUTE_1, {
      mapId = "ROUTE_1", terrain = "indoor", rng = function() return 1 end,
    }),
    "engine indoor terrain uses the same native table for cave encounters")

  game.data.pokemon.CHIKORITA = { id="CHIKORITA", dex=152, sourceDex=152 }
  local johtoEncounter = {
    grass = { rate=25, slots={{species="CHIKORITA", level=5}} },
  }
  check(Hoenn.isEligibleNative(game,
    { species="CHIKORITA", level=5 }, johtoEncounter, {
      mapId="ROUTE_1", terrain="grass", rng=function() return 1 end,
    }),
    "released Johto encounters can carry the rare Hoenn replacement layer")
  check(not Hoenn.isEligibleNative(game,
    { species="TREECKO", level=5 }, {
      grass={rate=25,slots={{species="TREECKO",level=5}}},
    }, {
      mapId="ROUTE_1", terrain="grass", rng=function() return 1 end,
    }),
    "a native Hoenn encounter cannot recursively enter the replacement layer")
end

-- -------------------------------------- runtime transactions and save slots

local function runtimeHarness(config)
  config = config or {}
  local callbacks, wraps = {}, {}
  local buckets = { red = {}, blue = {}, yellow = {} }
  local active = "red"
  local randomValues, randomCalls = {}, {}
  local game, legacyHoenn, extended = registryFixture()
  local mod = {
    events = {
      on = function(_, name, fn, priority)
        callbacks[name] = callbacks[name] or {}
        callbacks[name][#callbacks[name] + 1] = {
          fn = fn, priority = priority or 0,
        }
        table.sort(callbacks[name], function(a, b)
          return a.priority > b.priority
        end)
      end,
    },
    hooks = {
      wrap = function(_, name, fn, priority)
        wraps[name] = { fn = fn, priority = priority or 0 }
      end,
    },
    save = {
      get = function(_, key) return buckets[active][key] end,
      set = function(_, key, value) buckets[active][key] = value end,
    },
  }
  local manager = State.create(mod)
  local runRules = {
    state = function(save)
      return save.runRules or {
        locked = false,
        randomizer = { enabled = false, wild = false },
        nuzlocke = { mode = "off" },
      }
    end,
  }
  local controller = Hoenn.attach(mod, {
    state = manager, legacyHoenn = legacyHoenn,
    extendedSpeciesRuntime = extended, runRules = runRules,
    generationRules = config.generationRules,
    fieldAccess = {
      encountersEnabled = function()
        return config.encountersEnabled ~= false
      end,
      introductionFamilies = function(_, registered) return registered end,
    },
    random = function(low, high, purpose)
      randomCalls[#randomCalls + 1] = {
        low = low, high = high, purpose = purpose,
      }
      local value = table.remove(randomValues, 1)
      return value == nil and high or value
    end,
  })
  local function use(slot, mapId)
    active = slot
    game.save = buckets[slot]
    game.overworld = { map = { id = mapId or "ROUTE_1" } }
  end
  local function emit(name, value)
    for _, row in ipairs(callbacks[name] or {}) do row.fn(value or {}) end
  end
  return {
    mod = mod, game = game, buckets = buckets, manager = manager,
    controller = controller, wraps = wraps, callbacks = callbacks,
    randomValues = randomValues, randomCalls = randomCalls,
    use = use, emit = emit,
  }
end

do
  local h = runtimeHarness({ encountersEnabled=false })
  h.use("red", "ROUTE_1")
  h.emit("save.loaded", { game=h.game, save=h.game.save })
  h.manager.replace(traced("TREECKO", "ROUTE_1", 19))
  local hook = h.wraps["encounter.roll"].fn
  local native = hook(function()
    return { species="RATTATA", level=4 }
  end, h.game.data.encounters.ROUTE_1, {
    game=h.game, mapId="ROUTE_1", terrain="grass",
    rng=function() error("disabled Card must not roll") end,
  })
  eq(native.species, "RATTATA",
    "Hoenn Encounter Card OFF leaves the native encounter untouched")
  eq(State.sightingPity(h.manager.root(), "hoenn", "TREECKO"), 19,
    "Hoenn Encounter Card OFF preserves existing trace state and pity")
  local randomBefore = #h.randomCalls
  h.emit("battle.ended", {
    result="win", battle={kind="trainer",game=h.game,
      ascendantLegacyWanderer=true,ascendantLegacyToken="disabled:1"},
  })
  eq(#h.randomCalls, randomBefore,
    "Hoenn Encounter Card OFF cannot roll a new Wanderer trace")
  eq(Hoenn.introductionPity(h.manager.root()), 0,
    "Hoenn Encounter Card OFF cannot advance introduction pity")
end

do
  local epoch = 2
  local h = runtimeHarness({
    generationRules = {
      speciesAvailable = function(_, species)
        return species ~= "TREECKO" or epoch >= 3
      end,
    },
  })
  h.use("red", "ROUTE_1")
  h.emit("save.loaded", { game = h.game, save = h.game.save })
  h.manager.replace(traced("TREECKO", "ROUTE_1", 19))
  local hook = h.wraps["encounter.roll"].fn
  local function roll()
    return hook(function()
      return { species = "RATTATA", level = 4 }
    end, h.game.data.encounters.ROUTE_1, {
      game = h.game, mapId = "ROUTE_1", terrain = "grass",
      rng = sequence({ 9951 }, 1),
    })
  end
  eq(roll().species, "RATTATA",
    "manual Gen-II profile suppresses an already discovered Hoenn trace")
  eq(h.controller.pending(), nil,
    "a generation-suppressed trace creates no pending transaction")
  eq(State.sightingPity(h.manager.root(), "hoenn", "TREECKO"), 19,
    "generation suppression preserves the exact Hoenn trace pity")
  epoch = 3
  eq(roll().species, "TREECKO",
    "raising the profile restores the same discovered Hoenn trace")
end

do
  local h = runtimeHarness()
  local function surprise(slot, token, values)
    h.use(slot, "ROUTE_1")
    for _, value in ipairs(values) do h.randomValues[#h.randomValues + 1] = value end
    h.emit("save.loaded", { game = h.game, save = h.game.save })
    local battle = {
      kind = "trainer", game = h.game,
      ascendantLegacyWanderer = true,
      ascendantLegacyToken = token,
    }
    h.emit("battle.ended", {
      result = "win",
      battle = battle,
    })
    return battle
  end

  surprise("red", "red:1", { 2001 })
  eq(Hoenn.introductionPity(h.buckets.red.discovery_core), 1,
    "Red keeps its own Surprise pity")
  eq(h.buckets.blue.discovery_core, nil,
    "Red cannot pre-seed Blue discovery state")

  local blueIntroduction = surprise("blue", "blue:1", { 1, 2 })
  eq(Hoenn.traceMap(h.buckets.blue.discovery_core, "TORCHIC"), "ROUTE_1",
    "Blue records only its deterministically selected trace")
  eq(blueIntroduction.kaHoennIntroductionResult.family, "TORCHIC",
    "Discovery publishes the exact transient result for its presentation Card")
  eq(State.status(h.buckets.red.discovery_core, "hoenn", "TORCHIC"), "unseen",
    "Blue's trace cannot bleed into Red")

  surprise("yellow", "yellow:1", { 2001 })
  eq(Hoenn.introductionPity(h.buckets.yellow.discovery_core), 1,
    "Yellow keeps its own Surprise pity")
  eq(State.status(h.buckets.blue.discovery_core, "hoenn", "TORCHIC"), "trace",
    "loading Yellow does not replace Blue's saved trace")

  h.use("red", "PALLET_TOWN")
  local callsBefore = #h.randomCalls
  h.emit("battle.ended", {
    result = "win", battle = { kind = "trainer", game = h.game,
      ascendantLegacyWanderer = true, ascendantLegacyToken = "red:no-wild" },
  })
  eq(#h.randomCalls, callsBefore,
    "a Surprise win on a map without a real native wild surface consumes no RNG")
  eq(Hoenn.introductionPity(h.buckets.red.discovery_core), 1,
    "an unhostable map cannot burn Surprise pity")
end

do
  local h = runtimeHarness()
  h.use("red", "ROUTE_1")
  h.emit("save.loaded", { game = h.game, save = h.game.save })
  local root = traced("TREECKO", "ROUTE_1", 19)
  h.manager.replace(root)
  local hook = assert(h.wraps["encounter.roll"])
  eq(hook.priority, -25,
    "Hoenn runs after Early Johto and before Mythic special encounters")
  local rngCalls = {}
  local out = hook.fn(function()
    return { species = "RATTATA", level = 4 }
  end, h.game.data.encounters.ROUTE_1, {
    game = h.game, mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 9951 }, 1, rngCalls),
  })
  eq(out.species, "TREECKO", "the runtime hook exposes the proposed trace")
  eq(#rngCalls, 1, "the shared overlay consumes exactly one 1..10000 roll")
  eq(rngCalls[1].low, 1, "the overlay RNG lower bound is exact")
  eq(rngCalls[1].high, 10000, "the overlay RNG upper bound is exact")
  eq(Hoenn.pendingCatch(h.manager.root(), "TREECKO"), nil,
    "the hook alone cannot persist a pending catch")
  eq(State.sightingPity(h.manager.root(), "hoenn", "TREECKO"), 19,
    "the hook alone cannot reset pity")

  h.emit("world.stepped", { game = h.game, mapId = "ROUTE_1" })
  eq(h.controller.pending(), nil,
    "a Repel-suppressed proposal expires on the next world step")
  eq(State.sightingPity(h.manager.root(), "hoenn", "TREECKO"), 19,
    "Repel suppression consumes no overlay pity")

  out = hook.fn(function()
    return { species = "RATTATA", level = 4 }
  end, h.game.data.encounters.ROUTE_1, {
    game = h.game, mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 9951 }, 1),
  })
  local battle = {
    kind = "wild", encounterSource = "wild", game = h.game,
    enemy = { mon = { species = out.species, level = out.level } },
  }
  h.emit("battle.started", { battle = battle, kind = "wild" })
  eq(battle.kaHoennDiscoveryFamily, "TREECKO",
    "the exact real wild battle receives the committed discovery marker")
  check(Hoenn.pendingCatch(h.manager.root(), "TREECKO") ~= nil,
    "only battle.started creates the pending catch receipt")
  eq(State.sightingPity(h.manager.root(), "hoenn", "TREECKO"), 0,
    "the exact real sighting resets persisted pity")

  h.emit("pokemon.caught", {
    game = h.game, battle = battle, species = "TREECKO",
    mon = battle.enemy.mon,
  })
  eq(State.status(h.manager.root(), "hoenn", "TREECKO"), "unlocked",
    "the runtime catch event unlocks the exact pending family")
  eq(Hoenn.pendingCatch(h.manager.root(), "TREECKO"), nil,
    "the runtime catch event consumes its pending receipt")
end

do
  local h = runtimeHarness()
  h.use("red", "ROUTE_1")
  h.emit("save.loaded", { game = h.game, save = h.game.save })
  h.manager.replace(traced("TREECKO", "ROUTE_1", 9))
  local hook = h.wraps["encounter.roll"].fn
  local function roll(ctx)
    return hook(function() return { species = "RATTATA", level = 4 } end,
      h.game.data.encounters.ROUTE_1, ctx)
  end

  local protected = roll({
    game = h.game, mapId = "ROUTE_1", terrain = "grass",
    kaEncounterSource = "story", rng = function() error("must not roll") end,
  })
  eq(protected.species, "RATTATA",
    "an authored encounter source retains authority")
  eq(h.controller.pending(), nil,
    "an authored encounter creates no Hoenn transaction")

  local safari = roll({
    game = h.game, mapId = "SAFARI_ZONE_EAST", terrain = "grass",
    rng = function() error("must not roll") end,
  })
  eq(safari.species, "RATTATA", "Safari retains its capture authority")

  h.game.save.runRules = {
    locked = true,
    randomizer = { enabled = true, wild = true },
    nuzlocke = { mode = "off" },
  }
  local randomized = roll({
    game = h.game, mapId = "ROUTE_1", terrain = "grass",
    rng = function() error("must not roll") end,
  })
  eq(randomized.species, "RATTATA", "an active Randomizer retains authority")

  h.game.save.runRules.randomizer.enabled = false
  h.game.save.runRules.nuzlocke.mode = "standard"
  local nuzlocke = roll({
    game = h.game, mapId = "ROUTE_1", terrain = "grass",
    rng = function() error("must not roll") end,
  })
  eq(nuzlocke.species, "RATTATA", "an active Nuzlocke retains authority")
  eq(State.sightingPity(h.manager.root(), "hoenn", "TREECKO"), 9,
    "protected systems cannot burn Hoenn overlay pity")

  h.game.save.runRules.failed = true
  local afterFailure = roll({
    game = h.game, mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 9951 }, 1),
  })
  eq(afterFailure.species, "TREECKO",
    "a failed Nuzlocke no longer blocks ordinary discovery encounters")
end

io.write(("hoenn discovery phase 2: %d assertions passed\n"):format(assertions))
