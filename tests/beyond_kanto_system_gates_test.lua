local checks = 0
local function ok(value, label)
  checks = checks + 1
  assert(value, "FAIL: " .. label)
end
local function eq(actual, expected, label)
  ok(actual == expected, label .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local function harness(initial)
  local stored = initial or {}
  local hooks, events = {}, {}
  local mod = {
    id = "kanto_ascendant",
    save = {
      get = function(_, key, fallback)
        local value = stored[key]
        return value == nil and fallback or value
      end,
      set = function(_, key, value) stored[key] = value end,
    },
    hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
    events = { on = function(_, name, fn)
      events[name] = events[name] or {}
      events[name][#events[name] + 1] = fn
    end },
    options = { get = function() return true end },
    ui = { insertBefore = function(rows) return rows end },
    world = { overworld = function() return nil end },
  }
  return mod, stored, hooks, events
end

local active = false
local changedListener
local boundary = {
  isActive = function() return active end,
  speciesDex = function(game, species)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    return def and def.dex or nil
  end,
  onChanged = function(fn) changedListener = fn return fn end,
}

-- Day-Care: the same Kanto parents produce the original Kanto family root
-- while sealed, then the authored baby after activation. Archived eggs are
-- visible in both states, but may neither leave the counter nor hatch OFF.
do
  package.preload["src.pokemon.Party"] = function() return { MAX = 6 } end
  package.preload["src.battle.BattleState"] = function()
    return { stampOT = function(save, mon) mon.otId = save.player.id end }
  end
  package.preload["src.pokemon.Pokemon"] = function()
    return {
      new = function(_, species, level)
        return { species = species, level = level, moves = {},
          stats = { hp = 20 }, hp = 20 }
      end,
      heal = function(mon) mon.hp = mon.stats.hp; mon.status = nil end,
      movesAtLevel = function() return {} end,
    }
  end
  local mod, stored = harness()
  local daycare = assert(loadfile("daycare.lua"))()(mod, {
    beyondKanto = boundary,
    pokemonGender = {
      MALE = "M", FEMALE = "F",
      getMonGender = function(mon) return mon.gender end,
    },
  })
  local game = {
    data = { moves = {}, pokemon = {
      PICHU = { dex = 172, evolutions = { { species = "PIKACHU" } } },
      PIKACHU = { dex = 25, evolutions = { { species = "RAICHU" } } },
      RAICHU = { dex = 26, evolutions = {} },
    } },
    save = { player = { name = "RED", id = 7 }, party = {},
      pokedex = { seen = {}, owned = {} } },
  }
  local female = { species = "PIKACHU", gender = "F" }
  local male = { species = "PIKACHU", gender = "M" }
  active = false
  eq(daycare.babyFor(game, "RAICHU"), "PIKACHU",
    "sealed Raichu family keeps its original Kanto root")
  eq(daycare.eggSpecies(game, female, male), "PIKACHU",
    "sealed Pikachu breeding produces Pikachu")
  active = true
  eq(daycare.babyFor(game, "RAICHU"), "PICHU",
    "activation restores the authored Pichu family root")
  eq(daycare.eggSpecies(game, female, male), "PICHU",
    "activated Pikachu breeding produces Pichu")

  daycare.reserveEgg("PICHU", 1, "ARCHIVE", "PICHU")
  active = false
  local _, taken = daycare.takeReservedEgg(game, 1)
  ok(not taken and #stored.daycare_plus.reservedEggs == 1
      and #game.save.party == 0,
    "sealed reserved Pichu stays stored and cannot enter the party")
  active = true
  _, taken = daycare.takeReservedEgg(game, 1)
  ok(taken and #stored.daycare_plus.reservedEggs == 0
      and game.save.party[1].isEgg,
    "activation issues the exact same reserved Pichu egg")
  local egg = game.save.party[1]
  active = false
  local _, hatched = daycare.hatchEgg(game, egg)
  ok(not hatched and egg.isEgg and egg.eggSpecies == "PICHU"
      and not game.save.pokedex.owned.PICHU,
    "sealed party Pichu egg stays an egg and marks no ownership")
  active = true
  _, hatched = daycare.hatchEgg(game, egg)
  ok(hatched and not egg.isEgg and egg.species == "PICHU"
      and game.save.pokedex.owned.PICHU,
    "activation lets the retained egg hatch normally")
end

-- Research: copied milestones remain persisted but every public consumer and
-- the queued Egg hand-off returns false/empty until activation.
do
  local initial = { johto_research = {
    version = 2, starters = {}, rewards = {}, trackWins = {},
    eggsQueued = {}, eggsHatched = {}, itemsClaimed = {
      ["3:SUN_STONE"] = true,
    }, eggQueue = {}, pendingMons = {}, pendingItems = {},
    activeEgg = { species = "PICHU", steps = 8, remaining = 8 },
  } }
  local mod, stored, _, events = harness(initial)
  local reserved = 0
  local research = assert(loadfile("johto_research.lua"))()(mod, {
    data = {
      aide = { map = "OAKS_LAB", name = "ELMS_AIDE", preferred = {} },
      starters = {}, starterOrder = {}, rewards = {}, eggs = {},
      items = {}, itemMilestones = { { at = 3, item = "SUN_STONE" } },
      habitats = {}, researchBase = {}, order = {}, species = {},
    },
    postgame = { hasHallOfFame = function() return true end },
    johtoBoundary = boundary,
    daycare = {
      reserveEgg = function() reserved = reserved + 1 return true end,
      researchEggStatus = function() return nil end,
    },
  })
  local game = { data = { maps = {}, pokemon = {}, items = {} },
    save = { party = {}, pokedex = { seen = { FURRET = true }, owned = {} } } }
  active = false
  research.install(game)
  ok(not research.itemUnlocked("SUN_STONE"),
    "sealed copied milestone cannot unlock a Frontier evolution item")
  ok(not research.isSpeciesResearched("FURRET"),
    "sealed copied Dex history cannot advertise Johto research")
  eq(#research.habitatCandidates("ROUTE_1", "grass"), 0,
    "sealed research exposes no Johto habitat")
  for _, fn in ipairs(events["world.stepped"] or {}) do fn() end
  eq(reserved, 0, "sealed active research Egg is paused in storage")
  ok(stored.johto_research.activeEgg ~= nil,
    "paused research Egg is not consumed")
  active = true
  ok(research.itemUnlocked("SUN_STONE"),
    "activation restores the earned Frontier item milestone")
  ok(research.isSpeciesResearched("FURRET"),
    "activation restores the retained researched-species status")
  for _, fn in ipairs(events["world.stepped"] or {}) do fn() end
  eq(reserved, 1, "activation hands the retained research Egg to Day-Care")
  eq(stored.johto_research.activeEgg, nil,
    "successful activated hand-off consumes only the active queue row")
end

-- World events: OFF removes only an inherited Johto migration, skips that
-- rotation slot, and never replaces a native encounter. Other Kanto events
-- survive unchanged; ON restores the migration event and spawn.
do
  local mod, stored, hooks = harness({ world_events = {
    version = 1, index = 0, nextAt = 5,
    active = { id = "training_rush", steps = 20 },
  } })
  local world = assert(loadfile("world_events.lua"))()(mod, {
    beyondKanto = boundary,
    postgame = { hasHallOfFame = function() return true end },
    johtoResearch = { state = function() return { finalReward = true } end },
    showMenu = false,
  })
  local game = { save = { hallOfFame = { {} } },
    data = { pokemon = { STANTLER = { name = "STANTLER" } } } }
  active = false
  world.install(game)
  eq(world.state(false).active.id, "training_rush",
    "sealed sync preserves an unrelated Kanto world event")
  stored.world_events.active = {
    id = "johto_migration", steps = 20, map = "ROUTE_2", species = "STANTLER",
  }
  eq(world.state(false).active, nil,
    "sealed sync clears an inherited active Johto migration")
  stored.world_events.index, stored.world_events.nextAt = 1, 1
  world.onStep(game, 1)
  eq(world.state(false).active.id, "golden_wind",
    "sealed rotation skips Johto migration without losing Kanto events")
  stored.world_events.active = {
    id = "johto_migration", steps = 20, map = "ROUTE_2", species = "STANTLER",
  }
  local base = { species = "RATTATA", level = 5 }
  local rolled = hooks["encounter.roll"](function() return base end, {}, {
    game = game, mapId = "ROUTE_2", rng = function() return 1 end,
  })
  eq(rolled.species, "RATTATA",
    "sealed encounter roll cannot emit Johto migration species")
  active = true
  stored.world_events.active = {
    id = "johto_migration", steps = 20, map = "ROUTE_2", species = "STANTLER",
  }
  rolled = hooks["encounter.roll"](function() return base end, {}, {
    game = game, mapId = "ROUTE_2", rng = function() return 1 end,
  })
  eq(rolled.species, "STANTLER",
    "activation restores the retained Johto migration spawn")
end

-- Mythic Signals: MEW (#151) remains a Kanto echo OFF; CELEBI and a carried
-- retry remain present in state but dormant until activation.
do
  local root = { resonance = { sealed = true, completed = {},
    bound = { species = "CELEBI", level = 60, retryRolls = 7 } } }
  local mod = harness()
  local state = {
    section = function() return root.resonance end,
    persist = function() return true end,
  }
  local mythic = assert(loadfile("mythic_signals.lua"))()(mod, {
    state = state, beyondKanto = boundary,
  })
  local game = { data = { pokemon = {
    MEW = { dex = 151 }, CELEBI = { dex = 251 },
  } }, save = { flags = { EVENT_GOT_POKEDEX = true }, inventory = {},
    party = {}, pokedex = { owned = {} } } }
  active = false
  local pool = mythic.activePool(game)
  eq(#pool, 1, "sealed Mythic pool contains exactly one Kanto species")
  eq(pool[1], "MEW", "sealed Mythic pool still permits Mew")
  local native = { species = "RATTATA", level = 5 }
  local out, transaction = mythic.rollReplacement(native, {
    grass = { rate = 25, slots = { { species = "RATTATA", level = 5 } } },
  }, { mapId = "ROUTE_1", terrain = "grass",
    rng = function() return 1 end }, game)
  eq(out.species, "RATTATA", "sealed carried Celebi retry remains dormant")
  eq(transaction, nil, "dormant Celebi retry advances no pity transaction")
  eq(root.resonance.bound.retryRolls, 7,
    "sealed carried Celebi retry state is retained exactly")
  active = true
  pool = mythic.activePool(game)
  eq(#pool, 2, "activation restores Mew and Celebi to the Mythic pool")
end

-- Journal: Kanto goals stay ahead of the boundary. Once complete, OFF points
-- to Lind instead of leaking Silver/Kris/Gold; the optional Signals row is
-- hidden. ON restores the Johto Masters objective.
do
  local mod = { options = { get = function() return false end } }
  local tracker = assert(loadfile("quest_tracker.lua"))()(mod, {
    beyondKanto = boundary,
    postgame = {
      hasHallOfFame = function() return true end,
      state = function() return {} end,
      phaseFor = function() return "complete" end,
    },
    postgameData = { gyms = {} },
    ascendant = {
      evaluateAchievements = function() return {
        cycle = 0, rocketStage = 0, tournament = { wins = 1 }, mewCaught = true,
      } end,
      activeResearch = function() return nil end,
      questDoneCount = function() return 8 end,
      newGamePlusReady = function() return false end,
    },
    ascendantData = { rocket = {} },
    johtoMasters = { state = function() return { clears = 0 } end },
    signalsHub = { objective = function() return {
      key = "johto", title = "JOHTO", location = "ROUTE_1",
    } end },
  })
  local game = { save = { hallOfFame = { {} },
    pokedex = { seen = {}, owned = {} } } }
  tracker.install(game)
  active = false
  eq(tracker.nextObjective(game).id, "beyond_kanto",
    "sealed Journal points to the irreversible Lind authority")
  eq(tracker.signalsObjective(game), nil,
    "sealed Journal advertises no optional Johto Signal")
  active = true
  eq(tracker.nextObjective(game).id, "gold",
    "activation restores Silver/Kris/Gold progression")
end

-- Randomizer: the selected save owns the species/item pool. A sealed slot
-- cannot pass an out-of-pool Johto source through unchanged, and a boundary
-- notification rebuilds the pool without stale mappings.
do
  local mod = harness()
  local pokemon = {}
  for dex = 1, 251 do
    local id = ("P%03d"):format(dex)
    pokemon[id] = {
      id = id, dex = dex, evolutions = {},
      baseStats = { hp = 50, attack = 50, defense = 50,
        speed = 50, special = 50 },
    }
  end
  local game = {
    data = { pokemon = pokemon, items = {
      FIRE_STONE = { id = "FIRE_STONE", source = "ROM:ItemNames[32]" },
      SUN_STONE = { id = "SUN_STONE" },
      POTION = { id = "POTION", source = "ROM:ItemNames[20]" },
    } },
    save = { player = { name = "RED" }, party = {}, inventory = {},
      pokedex = { seen = {}, owned = {} }, modData = {} },
    overworld = { map = { def = { id = "ROUTE_1" } } },
    writeSave = function() return true end,
  }
  active = false
  local rules = assert(loadfile("run_rules.lua"))()(mod, {
    beyondKanto = boundary,
  })
  rules.install(game)
  eq(#rules.pool, 151, "sealed Randomizer builds exactly the Gen-I pool")
  local s = rules.state()
  s.randomizer.enabled = true
  local mapped = rules.randomSpecies(s, "P200", "wild")
  ok(mapped ~= "P200" and pokemon[mapped].dex <= 151,
    "sealed Randomizer maps an inherited Johto source into Gen I")
  eq(rules.itemAllowed(game, "SUN_STONE"), false,
    "sealed item pool rejects a mod-added evolution item")
  eq(rules.randomItem(game, s, "SUN_STONE"), "FIRE_STONE",
    "sealed item randomizer replaces an extended Stone with a ROM Stone")
  s.mappings.species.LEAK = "P200"
  active = true
  changedListener(true, game)
  eq(#rules.pool, 251, "activation rebuilds the complete 251-species pool")
  eq(next(s.mappings.species), nil,
    "boundary rebuild clears stale species mappings")
  eq(rules.itemAllowed(game, "SUN_STONE"), true,
    "activation restores extended item candidates")
  active = false
  changedListener(false, game)
  eq(#rules.pool, 151,
    "loading a different sealed slot restores the Gen-I pool")
end

-- Grand Tour: facilities remain playable OFF. Rentals and opponents use one
-- deterministic view of the authored data: #1-151 and Gen-I moves while
-- sealed, byte-authored Johto rosters after activation.
do
  local data = assert(loadfile("grand_tour_data.lua"))()
  local nonGen = {}
  for index, row in ipairs(data.factory.candidates) do
    if index > 20 then nonGen[row.species] = true end
  end
  local species, moves, kantoDex, johtoDex = {}, {}, 1, 152
  local function ingestTeam(team)
    for _, slot in ipairs(team or {}) do
      if not species[slot.species] then
        local dex
        if nonGen[slot.species] then dex, johtoDex = johtoDex, johtoDex + 1
        else dex, kantoDex = kantoDex, kantoDex + 1 end
        species[slot.species] = { id = slot.species, dex = dex,
          evolutions = {}, baseStats = { hp = 50, attack = 50,
            defense = 50, speed = 50, special = 50 } }
      end
      for _, move in ipairs(slot.moves or {}) do moves[move] = { pp = 10 } end
    end
  end
  ingestTeam(data.factory.candidates)
  for _, row in ipairs(data.factory.opponents) do ingestTeam(row.team) end
  for _, row in ipairs(data.cruise.opponents) do ingestTeam(row.team) end
  moves.MEGA_DRAIN = moves.MEGA_DRAIN or { pp = 10 }
  species.GOLBAT = { id = "GOLBAT", dex = 42,
    evolutions = { { species = "CROBAT" } },
    baseStats = { hp = 50, attack = 50, defense = 50, speed = 50, special = 50 } }
  species.CROBAT = species.CROBAT or { id = "CROBAT", dex = 169,
    evolutions = {}, baseStats = { hp = 50, attack = 50,
      defense = 50, speed = 50, special = 50 } }
  local mod = harness()
  local game = { data = { pokemon = species, moves = moves },
    save = { party = {}, modData = {} } }
  local grand = assert(loadfile("grand_tour.lua"))()(mod, {
    data = data, beyondKanto = boundary,
    postgame = { state = function() return { crownChampion = true } end },
  })
  active = false
  grand.install(game)
  eq(#grand.availableCandidates(game), 20,
    "sealed Factory exposes its twenty Kanto rentals")
  eq(grand.isFinalEvolution(game, "GOLBAT"), true,
    "sealed Gen-I rules treat Golbat as the available final stage")
  local draft = grand.draftCandidates(game, 1)
  eq(#draft, 6, "sealed Factory still offers six rentals")
  for _, slot in ipairs(draft) do
    ok(species[slot.species].dex <= 151,
      "sealed rental draft contains only #1-151")
    for _, move in ipairs(slot.moves) do
      ok(move ~= "GIGA_DRAIN", "sealed rental uses no Gen-II Giga Drain")
    end
  end
  local function inspectBracket(rows, label)
    for _, row in ipairs(rows) do
      for _, slot in ipairs(row.team) do
        ok(species[slot.species].dex <= 151,
          label .. " contains only #1-151")
        for _, move in ipairs(slot.moves) do
          ok(move ~= "GIGA_DRAIN", label .. " uses only the Gen-I drain move")
        end
      end
    end
  end
  local factoryOff = grand.factoryBracket(1, game)
  local cruiseOff = grand.cruiseBracket(1, game)
  eq(#factoryOff, data.factory.rounds,
    "sealed Factory keeps all authored rounds")
  eq(#cruiseOff, data.cruise.rounds,
    "sealed cruise keeps all authored rounds")
  inspectBracket(factoryOff, "sealed Factory")
  inspectBracket(cruiseOff, "sealed cruise")
  active = true
  eq(#grand.availableCandidates(game), 37,
    "activation restores all authored Factory rentals")
  eq(grand.isFinalEvolution(game, "GOLBAT"), false,
    "activated rules recognize Crobat as Golbat's next stage")
  local rawFactory = grand.rotatingSelection(data.factory.opponents,
    data.factory.rounds, 1)
  local factoryOn = grand.factoryBracket(1, game)
  for index, raw in ipairs(rawFactory) do
    eq(factoryOn[index].key, raw.key,
      "activated Factory keeps the authored opponent order")
    for slot, rawMon in ipairs(raw.team) do
      eq(factoryOn[index].team[slot].species, rawMon.species,
        "activated Factory restores the authored species")
      eq(table.concat(factoryOn[index].team[slot].moves, ","),
        table.concat(rawMon.moves, ","),
        "activated Factory restores the authored moves")
    end
  end
end

print(("beyond_kanto_system_gates_test: %d checks passed"):format(checks))
