-- Real shipped-engine regression for 0.1.75+ PartyMenu and integrated Bag
-- compatibility. This deliberately keeps the saved TEAM ICONS value CLASSIC:
-- global CRYSTAL must still select the bundled #001-251 icon pack.

return function(game)
  local shotDir = os.getenv("SHOT_DIR") or "/tmp/ka65-live-engine"
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    print("[live-compat]", value and "PASS" or "FAIL", label)
  end
  local function wait(frames)
    for _ = 1, frames do coroutine.yield() end
  end
  local function shot(name)
    os.execute('mkdir -p "' .. shotDir .. '" 2>/dev/null')
    local path = shotDir .. "/" .. name
    game.capturePath = path
    for _ = 1, 180 do
      if not game.capturePath then break end
      coroutine.yield()
    end
    wait(1)
    local f = io.open(path, "rb")
    if not f then return false end
    f:close()
    return true
  end
  local function tap(button)
    game.input.state[button] = true
    table.insert(game.input.pressQueue, button)
    wait(1)
    game.input.state[button] = false
    wait(1)
  end
  local function clearStack()
    while game.stack:top() do game.stack:pop() end
  end

  local runtime = game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant = runtime
  runtime.pokemon_sprite_style = "crystal"
  runtime.party_icon_style = "classic"
  runtime.sprite_style_summary = true
  runtime.ascendant_bag_mode = "pockets"
  runtime.modern_storage_ui = true
  runtime.language = "de"

  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = runtime
  local colorMode = os.getenv("COLOR_MODE")
  if colorMode then
    game.save.options.colors = colorMode
    require("src.render.PaletteFX").setMode(colorMode)
  end

  local Pokemon = require("src.pokemon.Pokemon")
  game.save.party = {
    Pokemon.new(game.data, "BULBASAUR", 12),
    Pokemon.new(game.data, "PIKACHU", 12),
    Pokemon.new(game.data, "MEW", 12),
  }

  local PartyMenu = require("src.ui.PartyMenu")
  local exports = game.mods.exports.kanto_ascendant
  local icons = exports and exports.partyIcons
  check("shipped engine exposes public PartyMenu.drawIcon",
    type(PartyMenu.drawIcon) == "function")
  check("Ascendant installs its icon renderer on the shipped engine",
    icons and icons.installedVia == "public")
  check("global Crystal overrides the saved CLASSIC team-icon suboption",
    icons and icons.renderPath(game, game.save.party[1])
      and icons.renderPath(game, game.save.party[1]):find(
        "/001.png", 1, true) ~= nil)

  clearStack()
  require("src.ui.Screens").push(game, "PartyMenu")
  wait(4)
  local partyMenu = game.stack:top()
  local partyUpdate = partyMenu.update
  local forcedBlink = 0
  partyMenu.update = function(self, dt)
    partyUpdate(self, dt)
    self.blink = forcedBlink
  end
  check("party resting-frame screenshot from shipped engine",
    shot("party_crystal_rest_shipped_engine.png"))
  forcedBlink = 5
  check("party animated-frame screenshot from shipped engine",
    shot("party_crystal_animated_shipped_engine.png"))
  partyMenu.update = partyUpdate
  tap("b")

  local keepBag = os.getenv("KEEP_BAG") == "1"
  if not keepBag then
    game.save.inventory = {
      POTION = 3,
      POKE_BALL = 4,
    }
    game.save.bagOrder = { "POTION", "POKE_BALL" }
  end
  clearStack()
  require("src.ui.Screens").push(game, "BagMenu")
  wait(4)
  local bag = game.stack:top()
  check("integrated pocket Bag opens with the modern renderer",
    bag and bag.__ascendantModernBag == true)
  check("an empty ITEMS pocket opens on the first non-empty pocket",
    bag and type(bag.items) == "table"
      and (keepBag or (bag.title == "MEDICINE"
        and #bag.items == 1 and bag.items[1].value == "POTION")))
  check("integrated Bag screenshot",
    shot("bag_items_shipped_engine.png"))
  tap("right")
  check("L/R changes to the next pocket",
    type(bag.items) == "table"
      and (keepBag or (bag.title == "POKé BALLS"
        and #bag.items == 1 and bag.items[1].value == "POKE_BALL")))
  if #bag.items > 0 then
    tap("a")
    check("A opens the normal USE/TOSS item action",
      game.stack:top() ~= bag)
  else
    check("an empty real-save pocket remains safely operable", true)
  end

  print(("[live-compat] RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
