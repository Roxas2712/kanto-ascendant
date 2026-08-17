-- Installed-package proof that Ascendant owns exactly one live Wilds,
-- follower, Bag and QoL surface after replacing the four standalone mods.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source runs are not package proof")
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Runtime = require("src.mods.Runtime")
  local Screens = require("src.ui.Screens")
  local Pipelines = require("src.render.Pipelines")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local mode = (os.getenv("QA_RENDER_MODE") or "2d"):lower()
  assert(mode == "2d" or mode == "full", "bad QA_RENDER_MODE")
  local pass, fail = 0, 0
  local report = {
    "scope=MOD-002-INTEGRATED-HOOKS",
    "renderer=" .. mode,
  }

  local function check(label, value)
    value = value and true or false
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    report[#report + 1] = (value and "PASS\t" or "FAIL\t") .. label
    return value
  end

  local function finish()
    report[#report + 1] = "pass=" .. pass
    report[#report + 1] = "fail=" .. fail
    local out = assert(io.open(dir .. "/driver_result.txt", "wb"))
    out:write(table.concat(report, "\n"), "\n")
    out:close()
    love.event.quit(fail == 0 and 0 or 1)
  end

  local exports = assert(game.mods and game.mods.exports, "exports missing")
  local ka = assert(exports.kanto_ascendant, "Ascendant export missing")
  local internal = assert(ka.internalWilds, "bundled Wilds missing")
  local status, byId, loadedById = game.mods:status(), {}, {}
  for _, row in ipairs(status.available or {}) do
    assert(byId[row.id] == nil, "duplicate loader row " .. tostring(row.id))
    byId[row.id] = row
  end
  for _, row in ipairs(status.loaded or {}) do loadedById[row.id] = row end
  for _, id in ipairs({
    "overworld_wild_spawns", "FOLLOWERS_EX", "quality_of_life", "useful_bag",
  }) do
    local row = assert(byId[id], "replacement fixture missing: " .. id)
    local exportOwnedByAscendant = id == "overworld_wild_spawns"
      and exports[id] == internal.exports or exports[id] == nil
    check(id .. " is visibly replaced by Ascendant",
      row.state == "replaced" and row.replacedBy == "kanto_ascendant"
        and row.error == nil and loadedById[id] == nil
        and exportOwnedByAscendant)
  end

  if mode == "full" then
    assert(exports.DRAMALESS_SHAPE, "FULL closure lacks DRAMALESS")
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    U.wait(90)
    check("FULL closure owns one live voxel pipeline",
      Pipelines.level("voxel") == 1 and Pipelines.worldPipeline() == "voxel")
  else
    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    check("2D closure owns the flat pipeline",
      Pipelines.level("voxel") == 0 and exports.DRAMALESS_SHAPE == nil)
  end

  -- Wilds: one bundled provider, one encounter-roll wrapper and one visible
  -- entity record.  A second standalone provider would fail every equality.
  local wilds = assert(exports.overworld_wild_spawns,
    "bundled compatibility export missing")
  local encounterChain = Runtime.hooks.chains
    and Runtime.hooks.chains["encounter.roll"] or {}
  local function captures(fn, value)
    if type(fn) ~= "function" or not (debug and debug.getupvalue) then
      return false
    end
    local index = 1
    while true do
      local name, upvalue = debug.getupvalue(fn, index)
      if name == nil then return false end
      if upvalue == value then return true end
      index = index + 1
    end
  end
  local wildHooks = 0
  for _, row in ipairs(encounterChain) do
    if row.owner == "kanto_ascendant"
        and captures(row.callback, wilds.logic) then
      wildHooks = wildHooks + 1
    end
  end
  check("one bundled Wilds provider owns one encounter hook",
    internal.bundled == true and internal.source == "bundled"
      and wilds == internal.exports and wilds.version == "1.12.2"
      and wildHooks == 1)
  U.teleport(game, "ROUTE_22", 24, 8, "down")
  U.wait(220)
  local visible, entities = 0, 0
  for id, row in pairs(wilds.logic.spawns or {}) do
    if row.mapId == "ROUTE_22" and row.visibleSprite ~= false then
      visible = visible + 1
      local entity = wilds.logic.entities[id]
      if entity and entity.overworldWildSpawn == true then entities = entities + 1 end
    end
  end
  check("Wilds records and actors are one-to-one without duplicates",
    visible >= 1 and entities == visible)

  -- Follower: one selected party mon, one runtime entity, one engine wrapper
  -- owner and no external follower export. The Wilds witness above stands on
  -- Route 22 water, where the production follower is deliberately hidden
  -- while surfing. Move through the real map loader to a known dry cell so
  -- this section proves the field follower rather than misclassifying the
  -- intended Surf suppression as a missing hook.
  game.save.player = game.save.player or {}
  game.save.player.surfing = false
  U.teleport(game, "ROUTE_22", 8, 8, "down")
  U.wait(20)
  check("follower witness uses a dry field cell",
    game.overworld.player.surfing ~= true)
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.onBike = false
  game.save.party = { Pokemon.new(game.data, "RAICHU", 30) }
  local follower = assert(ka.singleFollower, "native follower export missing")
  check("native follower refresh succeeds", follower.refresh(game))
  U.wait(30)
  local followers = follower.entities(game)
  local fieldFollowers = 0
  for _, entity in ipairs(game.overworld.entities or {}) do
    if entity._ascendantNativeFollower then fieldFollowers = fieldFollowers + 1 end
  end
  local Follower = require("src.world.PikachuFollower")
  check("exactly one RAICHU follower actor and wrapper are live",
    follower.active == true and follower.external == nil
      and #followers == 1 and fieldFollowers == 1
      and followers[1].followerSpecies == "RAICHU"
      and rawget(Follower, "__kantoAscendantNativeSingleFollower") ~= nil)

  -- Bag: the registered screen builds exactly one integrated pocket menu.
  game.save.inventory = { POTION = 2, POKE_BALL = 4 }
  game.save.bagOrder = { "POTION", "POKE_BALL" }
  Screens.push(game, "BagMenu")
  U.wait(8)
  local bag = game.stack:top()
  check("exactly one integrated Bag surface owns the live screen",
    bag and bag.__ascendantModernBag == true
      and type(bag.__ascendantShowItemInfo) == "function"
      and bag.__ascendantBagSecondary == "move"
      and bag.externalUsefulBagTestDouble ~= true
      and ka.externalUsefulBag == false)
  check("integrated hooks screenshot",
    U.shot(game, dir .. "/01_integrated_hooks.png"))
  U.tap(game, "b")
  U.wait(3)

  -- QoL: one Ascendant SELECT handler and one overlay listener set; the
  -- replaced standalone entry never ran.  Emit a real map event and inspect
  -- the one installed banner overlay on the current Overworld.
  local OverworldController = require("src.world.OverworldController")
  local handlers = rawget(OverworldController, "__qolSelectHandlers") or {}
  local handlerCount = 0
  for _ in pairs(handlers) do handlerCount = handlerCount + 1 end
  Runtime.emit("map.entered", {
    mapId = game.overworld.map.id, map = game.overworld.map,
  })
  check("one integrated QoL handler tree is live",
    handlerCount == 1 and handlers.kanto_ascendant ~= nil
      and rawget(game.overworld, "__qolLocationBannerOverlay") ~= nil
      and ka.externalQualityOfLife ~= true)

  report[#report + 1] = "wilds_hook_count=" .. wildHooks
  report[#report + 1] = "visible_wild_records=" .. visible
  report[#report + 1] = "follower_actor_count=" .. fieldFollowers
  report[#report + 1] = "bag_owner=integrated"
  report[#report + 1] = "qol_handler_count=" .. handlerCount
  finish()
end
