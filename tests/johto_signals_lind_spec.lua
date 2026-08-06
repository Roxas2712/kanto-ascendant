-- Focused Kanto Ascendant 6.0 hand-off tests for Early Johto -> Elm/Lind.
--
-- This file is a spec helper instead of a second stand-alone suite so the
-- release's existing trainer_rematch_test.lua CI entry executes every check.

return function(T, Data, modPath)
  local johtoData = assert(loadfile(modPath .. "/johto_data.lua"))()
  local makeResearch = assert(loadfile(modPath .. "/johto_research.lua"))()
  local oldPokemon = package.loaded["src.pokemon.Pokemon"]
  local oldBattleState = package.loaded["src.battle.BattleState"]
  package.loaded["src.pokemon.Pokemon"] = {
    new = function(_, species, level)
      return {
        species = species, level = level, hp = 10,
        stats = { hp = 10 }, moves = {},
      }
    end,
    heal = function(mon)
      mon.hp = mon.stats and mon.stats.hp or mon.hp
      mon.status = nil
    end,
  }
  package.loaded["src.battle.BattleState"] = {
    stampOT = function(save, mon)
      mon.ot = save.player and save.player.name
      mon.otId = save.player and save.player.id
    end,
  }

  local gameData = {
    pokemon = {},
    items = {},
    maps = Data.maps,
    constants = Data.constants,
  }
  for id, def in pairs(Data.pokemon) do gameData.pokemon[id] = def end
  for id, def in pairs(Data.items) do gameData.items[id] = def end
  for species, def in pairs(johtoData.species) do
    gameData.pokemon[species] = { name = def.name or species }
  end
  for _, row in ipairs(johtoData.items) do
    gameData.items[row.id] = { name = row.name or row.id }
  end

  local function newSubject(existingBucket, save)
    local bucket = existingBucket or {}
    local hooks = {}
    local fakeMod = {
      id = "trainer_rematch",
      save = {
        get = function(_, key, default)
          local value = bucket[key]
          if value == nil then return default end
          return value
        end,
        set = function(_, key, value) bucket[key] = value end,
      },
      hooks = {
        wrap = function(_, name, fn, priority)
          hooks[name] = { fn = fn, priority = priority }
        end,
      },
      events = { on = function() end },
      content = {
        screens = { register = function() end },
      },
      ui = {
        insertBefore = function(rows, _, row)
          rows[#rows + 1] = row
          return rows
        end,
        push = function() end,
        ListMenu = { new = function(_, title, rows, opts)
          return { title = title, items = rows, opts = opts }
        end },
      },
      world = {
        overworld = function() return nil end,
        removeNpc = function() end,
        spawnNpc = function() end,
      },
    }
    local battles = {}
    local postgame = {
      hasHallOfFame = function() return true end,
      newForcedBattle = function(_, class, team, tag)
        local battle = {
          trainer = { name = class },
          team = team,
          tag = tag,
        }
        battles[#battles + 1] = battle
        return battle
      end,
    }
    local research = makeResearch(fakeMod, {
      data = johtoData,
      postgame = postgame,
      i18n = { text = function(en) return en end },
    })
    local game = {
      data = gameData,
      save = save or {
        flags = { EVENT_BEAT_CHAMPION_RIVAL = true },
        hallOfFame = { {} },
        player = { name = "SIGNAL", id = 151 },
        party = {},
        boxes = {},
        currentBox = 1,
        inventory = {},
        bagOrder = {},
        pokedex = { seen = {}, owned = {} },
      },
      pushed = {},
    }
    game.stack = {
      push = function(_, screen)
        game.pushed[#game.pushed + 1] = screen
      end,
    }
    research.install(game)
    return {
      research = research,
      game = game,
      bucket = bucket,
      hooks = hooks,
      battles = battles,
      postgame = postgame,
    }
  end

  local function completeStarterFlags(s)
    s.starters.chikorita = true
    s.starters.cyndaquil = true
    s.starters.totodile = true
  end

  local function battle(class)
    return {
      rematchTrainerClass = class or "OPP_LASS",
      trainer = { name = "SIGNAL TESTER" },
    }
  end

  local function fillBag(game, excluded)
    excluded = excluded or {}
    local ids = {}
    for id in pairs(game.data.items) do
      if not excluded[id] and not id:find("BADGE", 1, true) then
        ids[#ids + 1] = id
      end
    end
    table.sort(ids)
    local capacity = require("src.inventory.Bag").capacity(game.data)
    -- Expanded ASC bags can exceed the number of distinct items in this
    -- deliberately tiny fixture. Clamp the fixture's configured capacity so
    -- this scenario still represents a genuinely full bag.
    capacity = math.min(capacity, #ids)
    game.data.constants = game.data.constants or {}
    game.data.constants.bagSize = capacity
    for index = 1, capacity do
      local id = assert(ids[index], "fixture needs enough Bag items")
      game.save.inventory[id] = 1
      game.save.bagOrder[#game.save.bagOrder + 1] = id
    end
  end

  local function fillStorage(game)
    game.save.party = {}
    for _ = 1, 6 do
      game.save.party[#game.save.party + 1] = {
        species = "FIXMON_A", level = 5,
      }
    end
    game.save.boxes = {}
    for box = 1, 12 do
      game.save.boxes[box] = {}
      for _ = 1, 20 do
        game.save.boxes[box][#game.save.boxes[box] + 1] = {
          species = "FIXMON_A", level = 5,
        }
      end
    end
    game.save.currentBox = 1
  end

  -- The research hook is below Johto Signals in the encounter stack.  Both
  -- supported protection markers must preserve the exact object/result.
  do
    local subject = newSubject()
    local s = subject.research.state()
    s.rewards.NATU = true
    local hook = assert(subject.hooks["encounter.roll"]).fn
    T.eq(subject.hooks["encounter.roll"].priority, -20,
      "Lind remains the low-priority post-game habitat hook")
    local protected = {
      species = "SENTRET", level = 18, kaProtected = true,
    }
    local out = hook(function() return protected end, {}, {
      mapId = "ROUTE_22", terrain = "grass",
      rng = function() return 1 end,
    })
    T.eq(out, protected,
      "Lind preserves the exact kaProtected Johto Signals encounter")
    local sourced = {
      species = "HOOTHOOT", level = 14,
      kaEncounterSource = "johto_signals",
    }
    out = hook(function() return sourced end, {}, {
      mapId = "ROUTE_22", terrain = "grass",
      rng = function() return 1 end,
    })
    T.eq(out, sourced,
      "Lind preserves an encounter-source marker even without kaProtected")
    out = hook(function()
      return { species = "FIXMON_A", level = 5 }
    end, {}, {
      mapId = "ROUTE_22", terrain = "grass",
      rng = function() return 1 end,
    })
    T.eq(out.species, "NATU",
      "an ordinary unprotected native roll still uses Lind's habitat")
  end

  -- Every species exposed by Early Johto has a deterministic compensation.
  do
    local subject = newSubject()
    local allowed = {
      SUN_STONE = true, METAL_COAT = true, KINGS_ROCK = true,
      DRAGON_SCALE = true, UPGRADE = true,
    }
    for _, row in ipairs(johtoData.rewards) do
      local item = subject.research.compensationItemFor(
        row.species, row.track)
      T.eq(allowed[item], true,
        row.species .. " maps to an existing Johto evolution item")
      T.eq(subject.research.compensationItemFor(
        row.species, row.track), item,
        row.species .. " compensation is deterministic")
    end
    T.eq(subject.research.compensationItemFor("CHIKORITA"),
      "SUN_STONE", "early Chikorita maps to a Sun Stone")
    T.eq(subject.research.compensationItemFor("CYNDAQUIL"),
      "SUN_STONE", "early Cyndaquil maps to a Sun Stone")
    T.eq(subject.research.compensationItemFor("TOTODILE"),
      "DRAGON_SCALE", "early Totodile maps to a Dragon Scale")
    T.eq(subject.research.compensationItemFor("LARVITAR"),
      "KINGS_ROCK", "early Larvitar maps to a King's Rock")
  end

  -- An ordinary Early-Johto catch advances research without a second mon.
  do
    local subject = newSubject()
    local s = subject.research.state()
    completeStarterFlags(s)
    subject.game.save.pokedex.seen.SENTRET = true
    subject.game.save.pokedex.owned.SENTRET = true
    local message = subject.research.afterRematch(
      subject.game, battle("OPP_LASS"))
    T.eq(s.rewards.SENTRET, true,
      "an early-owned ordinary species completes Lind's reward flag")
    T.eq(#subject.game.save.party, 0,
      "the completed research step does not duplicate early Sentret")
    T.eq(#s.pendingMons, 0,
      "an early-owned species is not hidden in the pending-mon queue")
    T.eq(subject.game.save.inventory.SUN_STONE, 1,
      "the ordinary early catch receives its deterministic compensation")
    T.eq(s.compensations["reward:SENTRET"], "SUN_STONE",
      "the ordinary compensation entitlement is permanently recorded")
    T.eq(message:find("No duplicate", 1, true) ~= nil, true,
      "the player is explicitly told why no duplicate was created")
  end

  -- With no prior ownership the old authored Pokémon reward is untouched.
  do
    local subject = newSubject()
    local s = subject.research.state()
    completeStarterFlags(s)
    local message = subject.research.afterRematch(
      subject.game, battle("OPP_LASS"))
    T.eq(s.rewards.SENTRET, true,
      "an unowned specimen still completes the same reward flag")
    T.eq(#subject.game.save.party, 1,
      "an unowned Sentret still arrives as the original Pokémon reward")
    T.eq(subject.game.save.party[1].species, "SENTRET",
      "the original research reward species is unchanged")
    T.eq(subject.game.save.inventory.SUN_STONE, nil,
      "an unowned specimen does not receive duplicate compensation")
    T.eq(s.compensations["reward:SENTRET"], nil,
      "ordinary legacy rewards do not create compensation state")
    T.eq(message:find("No duplicate", 1, true), nil,
      "the original reward dialogue is retained for an unowned species")
  end

  -- A full Bag and completely full PC still cannot lose or convert a claim.
  do
    local subject = newSubject()
    local game, s = subject.game, subject.research.state()
    completeStarterFlags(s)
    game.save.pokedex.seen.SENTRET = true
    game.save.pokedex.owned.SENTRET = true
    fillStorage(game)
    fillBag(game, { SUN_STONE = true })
    local partyCount = #game.save.party
    subject.research.afterRematch(game, battle("OPP_LASS"))
    T.eq(#game.save.party, partyCount,
      "a full party is untouched by early-owned compensation")
    T.eq(#game.save.boxes[1], 20,
      "a full PC is untouched by early-owned compensation")
    T.eq(#s.pendingMons, 0,
      "full storage never turns the skipped duplicate into a reserved mon")
    T.eq(s.pendingItems[1], "SUN_STONE",
      "a full Bag reserves the exact deterministic compensation")

    -- Simulate mod disabled/re-enabled: the same serialized bucket is loaded
    -- by a fresh controller, then claimed twice through Elm's aide.
    local restarted = newSubject(subject.bucket, game)
    local rs = restarted.research.state()
    T.eq(rs.pendingItems[1], "SUN_STONE",
      "the pending compensation survives mod off/on and restart")
    T.eq(rs.compensations["reward:SENTRET"], "SUN_STONE",
      "the idempotence ledger survives mod off/on and restart")
    local aide = {
      def = { name = johtoData.aide.name },
      facePlayer = function() end,
    }
    local ow = { player = {} }
    local oldTextBox = package.loaded["src.render.TextBox"]
    package.loaded["src.render.TextBox"] = {
      new = function(_, text, onDone, opts)
        return { text = text, onDone = onDone, opts = opts or {} }
      end,
    }
    restarted.research.handleTalk(ow, aide, game)
    T.eq(rs.pendingItems[1], "SUN_STONE",
      "talking with a full Bag keeps the compensation reserved")

    local removed = game.save.bagOrder[1]
    game.save.inventory[removed] = nil
    restarted.research.handleTalk(ow, aide, game)
    T.eq(#rs.pendingItems, 0,
      "freeing one Bag slot delivers the reserved compensation")
    T.eq(game.save.inventory.SUN_STONE, 1,
      "the reserved compensation is delivered exactly once")
    restarted.research.handleTalk(ow, aide, game)
    T.eq(game.save.inventory.SUN_STONE, 1,
      "repeated aide claims cannot duplicate a delivered compensation")
    package.loaded["src.render.TextBox"] = oldTextBox
  end

  -- Starter trial completion uses the same no-duplicate hand-off.
  do
    local subject = newSubject()
    local game, s = subject.game, subject.research.state()
    game.save.pokedex.seen.CHIKORITA = true
    game.save.pokedex.owned.CHIKORITA = true
    local oldTextBox = package.loaded["src.render.TextBox"]
    package.loaded["src.render.TextBox"] = {
      new = function(_, text, onDone, opts)
        return { text = text, onDone = onDone, opts = opts or {} }
      end,
    }
    local ow = {
      player = {},
      afterBattle = function() end,
      pushBattle = function(self, nextBattle) self.battle = nextBattle end,
    }
    local npc = {
      def = { name = johtoData.starters.chikorita.name },
      facePlayer = function() end,
      frozen = false,
    }
    T.eq(subject.research.handleTalk(ow, npc, game), true,
      "the Chikorita trial remains available after an early catch")
    game.pushed[#game.pushed].opts.choice(true)
    for round = 1, 3 do
      ow.battle.onFinish("win")
      if round < 3 then game.pushed[#game.pushed].onDone() end
    end
    package.loaded["src.render.TextBox"] = oldTextBox
    T.eq(s.starters.chikorita, true,
      "the early-owned Chikorita still completes its starter trial")
    T.eq(#game.save.party, 0,
      "the completed starter trial does not create a second Chikorita")
    T.eq(game.save.inventory.SUN_STONE, 1,
      "the early-owned starter receives its fixed compensation")
    T.eq(s.compensations["starter:chikorita"], "SUN_STONE",
      "the starter compensation is protected against repeat claims")
  end

  -- Larvitar's finale also advances, without replaying all old milestones.
  do
    local subject = newSubject()
    local game, s = subject.game, subject.research.state()
    completeStarterFlags(s)
    for _, row in ipairs(johtoData.rewards) do
      s.rewards[row.species] = true
    end
    for _, row in ipairs(johtoData.eggs) do
      s.eggsQueued[row.species] = true
    end
    for _, row in ipairs(johtoData.itemMilestones) do
      s.itemsClaimed[tostring(row.at) .. ":" .. row.item] = true
    end
    for index in ipairs(johtoData.partnerMilestones) do
      s.partnersClaimed[index] = true
    end
    game.save.pokedex.seen.LARVITAR = true
    game.save.pokedex.owned.LARVITAR = true
    subject.research.afterRematch(game, battle("OPP_HIKER"))
    T.eq(s.finalReward, true,
      "early-owned Larvitar still completes Lind's research finale")
    T.eq(#game.save.party, 0,
      "the finale does not create a duplicate Larvitar")
    T.eq(game.save.inventory.KINGS_ROCK, 1,
      "early Larvitar receives the deterministic finale compensation")
    T.eq(s.compensations["final:LARVITAR"], "KINGS_ROCK",
      "the Larvitar finale compensation is permanently recorded")
  end

  -- Full storage with an unowned species retains the legacy reservation
  -- instead of applying the Early-Johto compensation path.
  do
    local subject = newSubject()
    local game, s = subject.game, subject.research.state()
    completeStarterFlags(s)
    fillStorage(game)
    fillBag(game)
    subject.research.afterRematch(game, battle("OPP_LASS"))
    T.eq(s.pendingMons[1].species, "SENTRET",
      "an unowned reward still reserves its Pokémon when all storage is full")
    T.eq(#s.pendingItems, 0,
      "an unowned full-storage reward is never converted into an item")
    T.eq(s.compensations["reward:SENTRET"], nil,
      "legacy full-storage behavior does not create a compensation claim")
  end

  package.loaded["src.pokemon.Pokemon"] = oldPokemon
  package.loaded["src.battle.BattleState"] = oldBattleState
end
