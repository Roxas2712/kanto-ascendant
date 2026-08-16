-- Real-LÖVE visual acceptance for the shared Kanto Ascendant FireRed UI.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local Pokemon = require("src.pokemon.Pokemon")
  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("ascendant%-ui") or identity:find("phase8%-de%-qa"),
    "refusing to run outside a dedicated ascendant-ui identity")
  assert(GameVersion.get() == version, "wrong imported edition")
  U.wait(5)

  local api = assert(game.mods.exports.kanto_ascendant,
    "Kanto Ascendant exports missing")
  local expectedPath = os.getenv("POKEPORT_EXPECT_MOD_PATH")
  if expectedPath then
    assert(game.mods.mods.kanto_ascendant.path == expectedPath,
      "wrong candidate path: " .. tostring(game.mods.mods.kanto_ascendant.path))
  end
  assert(api.ascendantUi and api.ascendantUi.colors,
    "shared Ascendant UI export missing")

  local shotDir = os.getenv("SHOT_DIR") or "/tmp/ascendant-ui"
  local function assertLayout(screen, label)
    assert(screen and screen.__kantoAscendantLayout == true,
      label .. " is not using the Kanto Ascendant layout")
    assert(screen.__kantoAscendantStyle == "firered",
      label .. " is not using the FireRed style")
    assert(screen.rows <= 6, label .. " exceeds the themed row viewport")
  end
  local function shot(screen, name)
    assertLayout(screen, name)
    U.wait(2)
    assert(U.shot(game, shotDir .. "/" .. version .. "-" .. name .. ".png"),
      name .. " screenshot failed")
  end
  local function overlayShot(name)
    U.wait(2)
    assert(U.shot(game, shotDir .. "/" .. version .. "-" .. name .. ".png"),
      name .. " screenshot failed")
  end

  local startRows = Runtime.call("ui.start_menu.items",
    function(_, rows) return rows end, game, {})
  local gateway
  for _, row in ipairs(startRows) do
    if row.label == "ASCENDANT" then gateway = row break end
  end
  assert(gateway and gateway.onSelect, "ASCENDANT gateway missing")
  gateway.onSelect()
  local mainMenu = game.stack:top()
  shot(mainMenu, "main")

  local options
  for _, row in ipairs(mainMenu.items or {}) do
    if row.ascendantKey == "options" then options = row break end
  end
  assert(options, "central OPTIONS entry missing")
  mainMenu.onChoose(options, mainMenu)
  local root = game.stack:top()
  assert(#root.items == 6, "options root category count changed")
  shot(root, "options-root")

  root.onChoose(root.items[1], root)
  local gameplay = game.stack:top()
  assert(#gameplay.items == 5, "GAMEPLAY is not the compact five-row hub")
  shot(gameplay, "gameplay-top")
  assert(gameplay.onSelectKey and gameplay.items[1].help,
    "GAMEPLAY SELECT help is not connected")
  gameplay.onSelectKey(gameplay.items[1], gameplay)
  local help = game.stack:top()
  assert(help and help.isOpaque == false, "option help is not an overlay")
  overlayShot("gameplay-help")
  game.stack:pop()
  local rematchEntry = gameplay.items[2]
  assert(rematchEntry and rematchEntry.value == "rematch",
    "REMATCH submenu is not in the expected GAMEPLAY position")
  gameplay.onChoose(rematchEntry, gameplay)
  local rematch = game.stack:top()
  assert(#rematch.items == 5, "REMATCH submenu lost a tuning option")
  shot(rematch, "rematch-options")

  game.stack:pop() -- REMATCH
  game.stack:pop() -- GAMEPLAY
  local worldEntry = root.items[2]
  assert(worldEntry and worldEntry.value == "content",
    "WORLD / CONTENT is not the second root category")
  root.onChoose(worldEntry, root)
  local world = game.stack:top()
  assert(#world.items == 5, "WORLD / CONTENT is not a compact five-row hub")
  shot(world, "world-content")
  local livingEntry = world.items[2]
  assert(livingEntry and livingEntry.value == "living_world",
    "LIVING REGIONS is not discoverable from WORLD / CONTENT")
  world.onChoose(livingEntry, world)
  local living = game.stack:top()
  assert(#living.items == 3,
    "LIVING REGIONS is not split into three focused pages")
  shot(living, "living-regions")
  living.onChoose(living.items[1], living)
  local encounters = game.stack:top()
  assert(#encounters.items == 7,
    "VISIBLE ENCOUNTERS did not expose the current 1.12.2 controls")
  shot(encounters, "living-visible-encounters")
  assert(encounters.onSelectKey and encounters.items[1].help,
    "VISIBLE ENCOUNTERS SELECT help is not connected")
  encounters.onSelectKey(encounters.items[1], encounters)
  local livingHelp = game.stack:top()
  assert(livingHelp and livingHelp.isOpaque == false,
    "LIVING REGIONS help is not an overlay")
  overlayShot("living-regions-help")
  game.stack:pop()

  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  local partySpecies = {
    "BULBASAUR", "PIKACHU", "MEOWTH", "CHARMANDER", "SQUIRTLE", "RAICHU",
  }
  game.save.party = {}
  for _, species in ipairs(partySpecies) do
    game.save.party[#game.save.party + 1] = Pokemon.new(game.data, species, 30)
    local icon = game.data.icons.bySpecies[species]
    assert(type(icon) == "table" and icon.image:find("follower_", 1, true),
      species .. " did not receive an exact authored team icon")
  end
  local PartyMenu = require("src.ui.PartyMenu")
  local partyMenu = PartyMenu.new(game)
  game.stack:push(partyMenu)
  -- Screenshot capture may span several fast-forwarded update frames. Freeze
  -- the menu so frame A and B remain deterministic for pixel comparison.
  partyMenu.update = function() end
  local requestedFrame = os.getenv("ASCENDANT_TEAM_FRAME")
  partyMenu.blink = requestedFrame == "b" and 6 or 0
  overlayShot(requestedFrame == "b" and "team-icons-frame-b"
    or "team-icons-frame-a")
  if requestedFrame then
    U.log("ASCENDANT TEAM ICON FRAME PASS", version, requestedFrame)
    love.event.quit(0)
    return
  end
  game.stack:pop()
  partyMenu = PartyMenu.new(game)
  partyMenu.update = function() end
  partyMenu.blink = 6
  game.stack:push(partyMenu)
  overlayShot("team-icons-frame-b")
  game.stack:pop()

  local Bag = require("src.inventory.Bag")
  Bag.add(game.save, "POTION", 2, game.data)
  Bag.add(game.save, "ANTIDOTE", 1, game.data)
  local bag = require("src.ui.BagMenu").new(game, {})
  assert(bag.__kantoAscendantBag and bag.rows == 5,
    "FireRed Bag description layout missing")
  game.stack:push(bag)
  overlayShot("bag-item-description")
  game.stack:pop()

  local mon = game.save.party[2]
  api.followerConfig._openEditor(game, mon)
  shot(game.stack:top(), "follower-editor")

  U.log("ASCENDANT UI REAL E2E PASS", version,
    "options help exact animated team icons Bag descriptions follower layout")
  love.event.quit(0)
end
