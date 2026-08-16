-- Focused real-LÖVE proof for the RC7 follow-up:
-- bundled animated #001-251 party art without Follower EX, exact player name
-- in the German PC root, and a visible fast-box-switch legend.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/ka65-party-pc-proof"
  local Boxes = require("src.pokemon.Boxes")
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")

  local pass, fail = 0, 0
  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local installedFollower = false
  for id in pairs(game.mods.mods or {}) do
    local lower = tostring(id):lower()
    if lower:find("follower", 1, true) then installedFollower = true end
  end
  check("no Follower EX-style mod is installed", not installedFollower)

  local runtime = game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant = runtime
  runtime.pokemon_sprite_style = "original"
  runtime.party_icon_style = "classic"
  runtime.sprite_style_summary = true
  runtime.language = "de"
  runtime.fast_box_switch = true

  -- Deliberately use a distinct save bucket. This reproduces the stale
  -- runtime/hot-reload path that previously made the renderer reject its own
  -- bundled icon and fall back to the generic gray Gen-I groups.
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = {
    pokemon_sprite_style = "crystal",
    party_icon_style = "species",
    sprite_style_summary = true,
    language = "de",
    fast_box_switch = true,
  }

  local species = {
    "BULBASAUR", "PIKACHU", "MEW",
    "CHIKORITA", "UNOWN", "CELEBI",
  }
  game.save.party = {}
  for _, id in ipairs(species) do
    game.save.party[#game.save.party + 1] = Pokemon.new(game.data, id, 12)
  end
  local exports = game.mods.exports.kanto_ascendant
  local icons = exports and exports.partyIcons
  local allBundled = icons and icons.loadedStyle == "animated"
  for index, mon in ipairs(game.save.party) do
    local entry = game.data.icons.bySpecies[mon.species]
    local path = entry and entry.image
    allBundled = allBundled and type(path) == "string"
      and (path:find("followers_kanto/follower_", 1, true) ~= nil
        or path:find("followers_runtime/normal/follower_", 1, true) ~= nil)
      and entry.frames == 6
      and index <= 6
  end
  check("all six representative #001-251 icons use bundled art", allBundled)
  check("live icon-style change requests a clean restart",
    icons and icons.restartRequired())

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  Screens.push(game, "PartyMenu")
  U.wait(3)
  local partyMenu = game.stack:top()
  local partyUpdate = partyMenu.update
  local proofBlink = 0
  partyMenu.update = function(self, dt)
    partyUpdate(self, dt)
    self.blink = proofBlink
  end
  check("bundled party icons resting-frame screenshot",
    U.shot(game, DIR .. "/party_bundled_rest.png"))
  proofBlink = 5
  check("bundled party icons animated-frame screenshot",
    U.shot(game, DIR .. "/party_bundled_animated.png"))
  partyMenu.update = partyUpdate
  U.tap(game, "b")

  game.save.player.name = "ASH"
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_MET_BILL = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  U.teleport(game, "VIRIDIAN_POKECENTER", 13, 4, "up")
  local overworld = game.overworld
  U.tap(game, "a")
  U.wait(4)
  local pcRoot = game.stack:top()
  check("German PC label preserves the exact player name",
    pcRoot and pcRoot.items and pcRoot.items[2]
      and pcRoot.items[2].label == "ASHs PC")
  check("Prof. Oak's PC label is not rewritten as the player PC",
    pcRoot and pcRoot.items and pcRoot.items[3]
      and pcRoot.items[3].label:find("OAK", 1, true))
  check("player-name PC screenshot",
    U.shot(game, DIR .. "/pc_player_name_ash.png"))
  U.tap(game, "b")
  U.wait(2)
  if game.stack:top() ~= overworld then
    while game.stack:top() ~= overworld do game.stack:pop() end
  end

  local boxes = Boxes.ensure(game.save)
  game.save.currentBox = 1
  boxes[1] = { Pokemon.new(game.data, "PIKACHU", 10) }
  Screens.push(game, "BoxMenu")
  U.wait(3)
  local boxMenu = game.stack:top()
  check("Box root advertises the L/R switch legend",
    boxMenu and boxMenu.__ascendantBoxSwitchLegend == "L/R BOX")
  check("Box-switch legend screenshot",
    U.shot(game, DIR .. "/box_switch_legend.png"))
  U.tap(game, "right")
  U.wait(2)
  check("legend describes the working direct Box switch",
    game.save.currentBox == 2)

  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
