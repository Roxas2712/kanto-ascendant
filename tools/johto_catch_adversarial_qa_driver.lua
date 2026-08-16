-- Real-renderer catch and Pokédex UAT for the four rare early-Johto traces.
--
-- This deliberately catches every unlocked base species in one disposable
-- session.  It proves that a real ball flow records the Johto species
-- instead of a Kanto presentation fallback and that the party can keep
-- receiving later catches after menus, Dex pages and map state have changed.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local Stats = require("src.pokemon.Stats")

  U.wait(30)
  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  assert(exports.johtoSignals and exports.johtoSignalsState,
    "Johto Signals exports missing")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  game.save.player = game.save.player or {}
  game.save.player.name = "TRACE CATCH"
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  game.save.inventory = game.save.inventory or {}
  game.save.bagOrder = game.save.bagOrder or {}
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1

  local lead = Pokemon.new(game.data, "BLASTOISE", 100,
    function() return 15 end)
  lead.stats = Stats.calc(game.data.pokemon.BLASTOISE, 100,
    lead.dvs, lead.statExp)
  lead.hp = lead.stats.hp
  game.save.party = { lead }
  U.teleport(game, "ROUTE_1", 10, 5, "down")

  local rows = {
    { id = "CHIKORITA", dex = 152, level = 8 },
    { id = "TOTODILE", dex = 158, level = 10 },
    { id = "CYNDAQUIL", dex = 155, level = 12 },
    { id = "LARVITAR", dex = 246, level = 15 },
  }

  local function waitForMenu(battle)
    for _ = 1, 260 do
      if battle.phase == "menu" then return true end
      U.tap(game, "a")
      U.wait(4)
    end
    return battle.phase == "menu"
  end

  for index, row in ipairs(rows) do
    local def = assert(game.data.pokemon[row.id],
      row.id .. " is not registered")
    assert(def.dex == row.dex,
      row.id .. " has wrong Johto Dex number " .. tostring(def.dex))

    local battle = BattleState.newWild(game, row.id, row.level)
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)
    assert(waitForMenu(battle), row.id .. " battle did not reach its menu")
    assert(battle.enemy and battle.enemy.mon
        and battle.enemy.mon.species == row.id,
      row.id .. " battle became a different species")
    assert(U.shot(game, ("%s/%02d_%s_encounter.png")
      :format(shotDir, index, row.id:lower())))

    -- Match BagMenu's consume-first contract.
    game.save.inventory.MASTER_BALL = nil
    battle:throwBall("MASTER_BALL")
    for frame = 1, 1500 do
      local top = game.stack:top()
      if top ~= battle and top ~= game.overworld then
        U.tap(game, "b")
        U.wait(2)
      elseif frame % 18 == 0 then
        U.tap(game, "a")
      else
        U.wait(1)
      end
      if game.save.pokedex.owned[row.id] == true then break end
    end
    assert(game.save.inventory.MASTER_BALL == nil,
      row.id .. " unexpectedly returned the used Master Ball")
    assert(game.save.pokedex.seen[row.id] == true
        and game.save.pokedex.owned[row.id] == true,
      row.id .. " was not recorded as seen and owned")
    local caught
    for _, mon in ipairs(game.save.party or {}) do
      if mon.species == row.id then caught = mon break end
    end
    assert(caught, row.id .. " did not enter the party as itself")

    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
    U.wait(12)
  end

  assert(#game.save.party == 5,
    "four Johto catches did not extend the party to five")
  U.log("JOHTO CATCH ADVERSARIAL QA PASS",
    os.getenv("POKEPORT_VERSION") or "unknown",
    "Chikorita Totodile Cyndaquil Larvitar")
end
