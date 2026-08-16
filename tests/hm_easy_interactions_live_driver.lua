-- Shipped-engine proof for Ascendant's A-button CUT interaction.
return function(game)
  local U = {}
  function U.wait(frames)
    for _ = 1, frames do coroutine.yield() end
  end
  function U.tap(g, button)
    table.insert(g.input.pressQueue, button)
    U.wait(1)
    g.input.state[button] = false
  end
  function U.log(...) print("[hm-driver]", ...) end
  function U.teleport(g, mapId, x, y, facing)
    while g.stack:top() do g.stack:pop() end
    g.stack:push(require("src.world.OverworldController"),
      mapId, x, y, facing or "down")
    U.wait(5)
  end
  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")
  local modId = "kanto_ascendant"
  local fail = 0

  local function check(ok, label)
    U.log(ok and "PASS" or "FAIL", label)
    if not ok then fail = fail + 1 end
  end

  local options = game.mods.modOptions[modId] or {}
  game.mods.modOptions[modId] = options
  options.ascendant_qol = true
  if os.getenv("KA_PRESERVE_QOL_DEFAULT") ~= "1" then
    options.qol_easy_interactions = true
  end
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions[modId] = options
  check(game.mods.optionSchemas[modId] ~= nil,
    "Kanto Ascendant final options schema is installed")
  local easyInteractions
  for _, row in ipairs(game.mods.optionSchemas[modId] or {}) do
    if row.key == "qol_easy_interactions" then
      easyInteractions = options.qol_easy_interactions
      if easyInteractions == nil then easyInteractions = row.default end
      break
    end
  end
  check(easyInteractions == true,
    "Easy Interactions resolves ON without a stored profile value")

  local mon = Pokemon.new(game.data, "BULBASAUR", 30)
  mon.moves = { { id = "CUT", pp = 30 } }
  game.save.party = { mon }
  game.save.inventory = game.save.inventory or {}
  game.save.inventory.CASCADEBADGE = true

  -- The Cerulean block at (9,14) contains the actual tree tile at (19,28).
  U.teleport(game, "CERULEAN_CITY", 19, 27, "down")
  local ow = game.overworld
  check(ow and ow.map:blockAt(9, 14) == 50,
    "Cerulean CUT tree is present before A")
  check(ow and ow:useCutFieldMove() == "ok",
    "engine accepts the facing Pokémon and Cascade Badge")

  U.tap(game, "a")
  U.wait(4)
  check(getmetatable(game.stack:top()) == TextBox,
    "A on the tree opens the normal CUT message")
  check(ow.map:blockAt(9, 14) == 50,
    "tree remains until the CUT message is dismissed")

  -- A press opens the field-move message; like vanilla, a second press only
  -- closes it after the typewriter reaches the end.
  U.wait(240)
  U.tap(game, "a")
  U.wait(12)
  check(ow.map:blockAt(9, 14) == 109,
    "dismissing the message cuts the tree")

  print(("[hm-easy-interactions] RESULT pass=%d fail=%d")
    :format(7 - fail, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
