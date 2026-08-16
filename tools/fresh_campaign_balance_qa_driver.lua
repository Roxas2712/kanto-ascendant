-- Real-LÖVE fresh-campaign balance probe.
--
-- Run once per POKEPORT_VERSION with a disposable POKEPORT_IDENTITY.  The
-- driver adopts a real SaveData.newGame skeleton, emits the production save
-- lifecycle, then constructs actual BattleState trainer/wild battles through
-- the complete mod hook chain for all three playable identities.

return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"), "KA_TEST_UTIL is required"))
  local SaveData = require("src.core.SaveData")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local Runtime = require("src.mods.Runtime")
  local GameVersion = require("src.core.GameVersion")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local characters = assert(exports.extendedCharacters)
  local pass, fail = 0, 0

  local function check(label, value, detail)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label, detail or "")
  end

  local function sig(party)
    local out = {}
    for _, mon in ipairs(party or {}) do
      out[#out + 1] = tostring(mon.species) .. "@" .. tostring(mon.level)
    end
    return table.concat(out, ",")
  end

  local function levelSig(party)
    local out = {}
    for _, mon in ipairs(party or {}) do out[#out + 1] = tostring(mon.level) end
    return table.concat(out, ",")
  end

  local function start(character)
    local fresh = SaveData.newGame(game:bootConfig())
    fresh.player.name = character
    fresh.player.rival = "RIVAL"
    game.save = fresh
    game:adoptSave(fresh)
    Runtime.emit("save.created", { save = fresh })
    Runtime.emit("game.ready", { game = game })
    characters.select(character)
    -- BattleState is resolved directly from the title-screen driver, before
    -- an OverworldController instance has been pushed.  Give the real save
    -- writer the same authored bedroom coordinates that New Game would have
    -- so the first-trainer run-rule lock exercises persistence without a
    -- synthetic nil-map warning.
    game.overworld.map = { id = fresh.player.map,
      def = game.data.maps[fresh.player.map] }
    game.overworld.player = {
      cellX = fresh.player.x, cellY = fresh.player.y,
      facing = fresh.player.facing, surfing = false,
    }
    return fresh
  end

  -- The driver starts only after the production loader and graphics context
  -- are ready.  This is intentionally not a love_stub/headless path.
  U.wait(10)
  local edition = GameVersion.get()
  local routePartyIndex = GameVersion.isYellow() and 2 or 4

  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    local fresh = start(character)
    check(edition .. "/" .. character .. " start money",
      fresh.money == 3000, tostring(fresh.money))
    check(edition .. "/" .. character .. " PC Potion economy",
      fresh.pcItems and fresh.pcItems.POTION == 1
        and fresh.inventory.POTION == nil,
      "pc=" .. tostring(fresh.pcItems and fresh.pcItems.POTION)
        .. " bag=" .. tostring(fresh.inventory.POTION))
    check(edition .. "/" .. character .. " Pallet heal anchor",
      fresh.lastHeal and fresh.lastHeal.map == "PALLET_TOWN",
      fresh.lastHeal and fresh.lastHeal.map)
    check(edition .. "/" .. character .. " no Legacy/NG+",
      not exports.legacyJourney.isActive(fresh))
    check(edition .. "/" .. character .. " no postgame scaling",
      not exports.postgame.hasHallOfFame(fresh)
        and exports.postgame.phaseFor({}, fresh) == "story"
        and exports.postgame.eliteTier({}, fresh) == nil)
    local rules = exports.runRules.state(fresh)
    check(edition .. "/" .. character .. " normal run rules",
      rules and rules.preset == "standard"
        and rules.randomizer.enabled == false
        and rules.nuzlocke.mode == "off")

    -- BattleState requires one healthy party member; adding it happens only
    -- after the fresh economy/flag assertions above.
    fresh.party[1] = Pokemon.new(game.data, "BULBASAUR", 5)
    local lab = BattleState.newTrainer(game, "OPP_RIVAL1", 1)
    local route = BattleState.newTrainer(game, "OPP_RIVAL1", routePartyIndex)
    local junior = BattleState.newTrainer(game, "OPP_JR_TRAINER_M", 1)
    local brock = BattleState.newTrainer(game, "OPP_BROCK", 1)
    local baseLab = game.data.trainers.OPP_RIVAL1.parties[1]
    local baseRoute = game.data.trainers.OPP_RIVAL1.parties[routePartyIndex]
    local baseJunior = game.data.trainers.OPP_JR_TRAINER_M.parties[1]
    local baseBrock = game.data.trainers.OPP_BROCK.parties[1]
    check(edition .. "/" .. character .. " real Lab battle matches Base",
      sig(lab.enemyParty) == sig(baseLab), sig(lab.enemyParty))
    check(edition .. "/" .. character .. " real Route22 levels match Base",
      levelSig(route.enemyParty) == levelSig(baseRoute), sig(route.enemyParty))
    check(edition .. "/" .. character .. " real Pewter junior matches Base",
      sig(junior.enemyParty) == sig(baseJunior), sig(junior.enemyParty))
    check(edition .. "/" .. character .. " real Brock matches Base",
      sig(brock.enemyParty) == sig(baseBrock), sig(brock.enemyParty))

    local slots = game.data.encounters.ROUTE_22.grass.slots
    local slot = slots[1]
    for _, candidate in ipairs(slots) do
      if candidate.level > slot.level then slot = candidate end
    end
    local resolved = Runtime.call("encounter.species", function(row) return row end,
      { species = slot.species, level = slot.level },
      { mapId = "ROUTE_22", terrain = "grass" })
    local wild = BattleState.newWild(game, resolved.species, resolved.level,
      { encounterSource = "wild" })
    check(edition .. "/" .. character .. " real Route22 wild level matches Base",
      wild.enemy and wild.enemy.mon and wild.enemy.mon.level == slot.level,
      wild.enemy and sig({ wild.enemy.mon }))
  end

  local wilds = assert(exports.internalWilds.exports)
  check(edition .. " visible Wilds default active",
    (function()
      for _, row in ipairs(game.mods.optionSchemas.kanto_ascendant or {}) do
        if row.key == "living_world_enabled" then return row.default == true end
      end
      return false
    end)())
  check(edition .. " pursuit remains active",
    (function()
      for _, row in ipairs(game.mods.optionSchemas.kanto_ascendant or {}) do
        if row.key == "living_world_chase" then return row.default == true end
      end
      return false
    end)())
  check(edition .. " visible and classic pipelines default on together",
    wilds.logic:canSuppressVanilla() == false,
    "suppressed=" .. tostring(wilds.logic:canSuppressVanilla()))

  U.log(("FRESH BALANCE LOVE RESULT edition=%s pass=%d fail=%d")
    :format(edition, pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
