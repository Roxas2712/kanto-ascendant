-- Real-LÖVE smoke for the complete Pokémon Center PC navigation:
-- Bill's storage, the player's item PC, Prof. Oak's rating, and logoff.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Menu = require("src.ui.Menu")
  local TextBox = require("src.render.TextBox")

  local pass, fail = 0, 0
  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end
  local function topIs(mt)
    return getmetatable(game.stack:top()) == mt
  end
  local function backTo(target)
    for _ = 1, 40 do
      if game.stack:top() == target then return true end
      U.tap(game, "b")
      U.wait(2)
    end
    return false
  end

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_MET_BILL = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen.PIKACHU = true
  game.save.pokedex.owned.PIKACHU = true

  U.teleport(game, "VIRIDIAN_POKECENTER", 13, 4, "up")
  local overworld = game.overworld
  local function openRoot()
    U.tap(game, "a")
    U.wait(6)
    return game.stack:top()
  end

  local root = openRoot()
  check("Pokémon Center PC root opens", topIs(Menu))
  check("PC root exposes Bill, player, Oak, and logoff",
    root and #root.items == 4
      and tostring(root.items[1].label):find("BILL", 1, true)
      and tostring(root.items[2].label):find(
        tostring(game.save.player.name or "RED"), 1, true)
      and tostring(root.items[2].label):find("PC", 1, true)
      and tostring(root.items[3].label):find("OAK", 1, true)
      and tostring(root.items[4].label):find("LOG OFF", 1, true))

  U.tap(game, "a")
  U.wait(6)
  check("Bill's PC opens from the shared root",
    topIs(Menu) and game.stack:top() ~= root)
  check("Bill's PC exits cleanly to the overworld", backTo(overworld))

  root = openRoot()
  U.tap(game, "down")
  U.tap(game, "a")
  U.wait(6)
  check("player item PC opens from the shared root",
    topIs(Menu) and game.stack:top() ~= root)
  check("player item PC exits cleanly to the overworld", backTo(overworld))

  root = openRoot()
  U.tap(game, "down")
  U.tap(game, "down")
  U.tap(game, "a")
  U.wait(6)
  check("Prof. Oak's PC opens the Pokédex rating", topIs(TextBox))
  for _ = 1, 180 do
    if game.stack:top() == overworld then break end
    U.tap(game, "a")
    U.wait(2)
  end
  check("Prof. Oak's rating exits cleanly to the overworld",
    game.stack:top() == overworld)

  root = openRoot()
  U.tap(game, "b")
  U.wait(4)
  check("PC logoff returns to the overworld",
    game.stack:top() == overworld)
  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
