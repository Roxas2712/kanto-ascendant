-- Real-client Red/Blue regression for the retroactive Gorochu quest.
--
-- Starts from a save where Lt. Surge was already defeated, declines his
-- Thunderheart twice across a map change, accepts on the third visit, then
-- declines and accepts the remote Power Plant condenser. Finally it adds the
-- resulting Gorochu to the party and proves that Surge's Master-rematch
-- prompt remains reachable after the optional quest.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")

  U.wait(30)
  local version = GameVersion.get()
  assert(version == "red" or version == "blue",
    "retroactive Gorochu QA is for Red/Blue")
  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local gorochu = assert(exports.gorochu, "Gorochu export missing")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  game.save.inventory = game.save.inventory or {}
  game.save.inventory[gorochu.heartItemId] = nil
  game.save.inventory[gorochu.tearItemId] = nil
  game.save.inventory.THUNDERBADGE = true
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_LT_SURGE = true
  -- This is deliberately an upgraded post-Elite-Four save. Both the
  -- Gorochu hand-off and the Master-rematch controller are now eligible, so
  -- the real talk dispatcher has to choose the quest first while no Heart is
  -- owned, then choose the rematch after the Heart has been received.
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.party = {
    Pokemon.new(game.data, "RAICHU", 45, function() return 9 end),
  }
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  local quest = gorochu.state()
  for key in pairs(quest) do quest[key] = nil end
  quest.version = 4
  local postgameState = exports.postgame.state()
  postgameState.masterWins = {}
  postgameState.crownWins = {}
  postgameState.bossRest = {}
  assert(exports.postgame.hasHallOfFame(game.save),
    "the upgraded fixture did not enter postgame")

  local function waitForChoice()
    for _ = 1, 100 do
      local top = game.stack:top()
      if top and type(top.onChoose) == "function" then return top end
      U.tap(game, "a")
      U.wait(4)
    end
    error("choice did not open")
  end

  local function closeText()
    for _ = 1, 120 do
      if game.stack:top() == game.overworld then return true end
      U.tap(game, "a")
      U.wait(4)
    end
    return false
  end

  local function captureBagItem(itemId, filename)
    require("src.ui.Screens").push(game, "BagMenu", {})
    U.wait(20)
    local bag = game.stack:top()
    local found
    for index, row in ipairs(bag.items or {}) do
      if row.value == itemId then
        found = index
        break
      end
    end
    assert(found, itemId .. " is owned but missing from the visible Bag data")
    bag.index = found
    bag.scroll = math.max(0, found - math.min(found, bag.rows or 7))
    U.wait(5)
    assert(U.shot(game, shotDir .. "/" .. filename))
    U.tap(game, "b")
    U.wait(10)
    assert(game.stack:top() == game.overworld, "Bag did not close")
  end

  local function enterSurge()
    U.teleport(game, "VERMILION_GYM", 4, 8, "up")
    U.wait(15)
    for _, npc in ipairs(game.overworld.npcs or {}) do
      if npc.def and npc.def.name == "VERMILIONGYM_LT_SURGE" then
        return game.overworld, npc
      end
    end
    error("Lt. Surge disappeared from the defeated Gym")
  end

  for refusal = 1, 2 do
    local surgeOw, surge = enterSurge()
    assert(game.save.inventory[gorochu.heartItemId] == nil,
      "postgame no-Heart precondition was lost")
    surgeOw:talkTo(surge)
    local choice = waitForChoice()
    assert(U.shot(game, ("%s/%02d_surge_decline_offer.png")
      :format(shotDir, refusal)))
    if choice.index == 1 then U.tap(game, "down") end
    U.tap(game, "a")
    assert(closeText(), "Surge refusal did not close")
    assert(game.save.inventory[gorochu.heartItemId] == nil,
      "declining Surge granted the Thunderheart")
    U.teleport(game, refusal == 1 and "ROUTE_11" or "VERMILION_CITY",
      5, 5, "down")
    U.wait(12)
  end

  local surgeOw, surge = enterSurge()
  surgeOw:talkTo(surge)
  local accept = waitForChoice()
  if accept.index == 2 then U.tap(game, "up") end
  U.tap(game, "a")
  assert(closeText(), "Surge acceptance did not close")
  assert(game.save.inventory[gorochu.heartItemId] == 1,
    "post-victory Surge did not place the Thunderheart in the Bag")
  captureBagItem(gorochu.heartItemId, "03_thunderheart_visible_in_bag.png")

  U.teleport(game, "POWER_PLANT", 10, 10, "down")
  U.wait(20)
  gorochu.refreshShrine(game, "POWER_PLANT")
  local condenser
  for _, npc in ipairs(game.overworld.npcs or {}) do
    if npc.def and npc.def.name == gorochu.shrineName then
      condenser = npc
      break
    end
  end
  assert(condenser, "Thunder condenser did not appear after late acceptance")

  assert(gorochu.handleTalk(game.overworld, condenser, game),
    "condenser interaction did not start")
  local declineTear = waitForChoice()
  if declineTear.index == 1 then U.tap(game, "down") end
  U.tap(game, "a")
  assert(closeText(), "condenser refusal did not close")
  assert(game.save.inventory[gorochu.tearItemId] == nil,
    "declining condenser granted a Tear")

  assert(gorochu.handleTalk(game.overworld, condenser, game),
    "condenser stopped responding after refusal")
  local acceptTear = waitForChoice()
  if acceptTear.index == 2 then U.tap(game, "up") end
  U.tap(game, "a")
  assert(closeText(), "condenser acceptance did not close")
  assert(game.save.inventory[gorochu.tearItemId] == 1,
    "accepted Tear was not placed in the Bag")
  assert(game.save.inventory[gorochu.heartItemId] == 1,
    "permanent Thunderheart disappeared at the condenser")

  -- Reproduce the Discord report precisely: Gorochu is in the party, Surge
  -- has already been defeated, and the Hall of Fame has unlocked Master
  -- rematches. The quest controller must decline this talk so postgame can
  -- display Surge's normal challenge.
  game.save.party[#game.save.party + 1] =
    Pokemon.new(game.data, "GOROCHU", 61, function() return 9 end)
  quest.completed = true
  quest.playerEvolved = true
  require("src.ui.Screens").push(game, "PartyMenu", {})
  U.wait(20)
  assert(U.shot(game, shotDir .. "/04_gorochu_visible_in_party.png"))
  U.tap(game, "b")
  U.wait(10)
  assert(game.stack:top() == game.overworld, "party menu did not close")
  local masterOw, masterSurge = enterSurge()
  assert(gorochu.handleTalk(masterOw, masterSurge, game) == false,
    "Gorochu status dialogue still hijacks postgame Surge")
  masterOw:talkTo(masterSurge)
  local masterChoice = waitForChoice()
  assert(U.shot(game, shotDir .. "/05_gorochu_party_master_rematch.png"))
  if masterChoice.index == 1 then U.tap(game, "down") end
  U.tap(game, "a")
  assert(closeText(), "Master-rematch refusal did not close")

  U.log("GOROCHU RETROACTIVE QA PASS", version,
    "Surge already beaten", "2x decline", "late accept",
    "condenser decline+accept", "Gorochu party", "Master rematch")
end
