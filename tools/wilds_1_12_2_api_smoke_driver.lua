-- Exact runtime-contract smoke for the external Wilds of Kanto 1.12.2 tag.
-- The internal Ascendant port deliberately excludes Wilds' follower and UI
-- ownership, but these assertions pin the public seams used during migration.

return function(game)
  local U = dofile("tests/drivers/util.lua")

  U.wait(30)
  local exports = assert(game.mods and game.mods.exports,
    "mod exports unavailable")
  local ascendant = assert(exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local wilds = assert(exports.overworld_wild_spawns,
    "Wilds of Kanto export missing")

  assert(wilds.version == "1.12.2",
    "wrong Wilds version: " .. tostring(wilds.version))
  assert(type(wilds.logic) == "table"
      and type(wilds.logic.trySpawn) == "function",
    "Wilds spawn API missing")
  assert(type(wilds.registerSpriteProvider) == "function"
      and type(wilds.getSpriteProvider) == "function"
      and type(wilds.refreshAllEntitySprites) == "function",
    "Wilds sprite-provider API missing")
  assert(type(wilds.resolveWaterSprite) == "function"
      and type(wilds.setWaterDisplayMode) == "function",
    "Wilds water API missing")
  assert(type(wilds.occupancy) == "function" and wilds.occupancy(),
    "Wilds atomic occupancy API missing")
  assert(type(wilds.lib) == "table"
      and type(wilds.lib.require) == "function",
    "Wilds library export missing")
  local encounterPick = assert(wilds.lib.require("encounter_pick"),
    "Wilds encounter picker unavailable")
  assert(type(encounterPick.pick) == "function",
    "Wilds encounter picker contract changed")

  local compat = assert(ascendant.wildsCompat,
    "Ascendant Wilds compatibility export missing")
  assert(compat.installed and compat.wildsVersion == "1.12.2",
    "Ascendant habitat adapter did not bind Wilds 1.12.2")
  assert(compat.registeredSprites == 100 and compat.providerInstalled,
    "Ascendant Johto sprite provider is incomplete")
  assert(wilds.getSpriteProvider("followers_ex"),
    "Ascendant walker provider was not registered")
  assert(wilds.logic._kantoAscendantHabitatWrapped,
    "Ascendant researched-habitat wrapper missing")

  local signals = assert(ascendant.signalsWilds,
    "Ascendant transactional Wilds adapter missing")
  assert(signals.installed and signals.wildsVersion == "1.12.2",
    "Ascendant Signals adapter did not bind Wilds 1.12.2")
  local marker = assert(wilds.logic._kantoAscendantSignalsWildsAdapter,
    "transactional adapter marker missing")
  assert(marker.dispatchVersion == 1 and marker.api == signals,
    "transactional adapter dispatch is not current")

  -- This is intentionally diagnostic, not an endorsement of importing the
  -- subsystem: the full 1.12.2 mod also owns followers and its own menus.
  assert(type(wilds.follower) == "table"
      and type(wilds.settingsMenus) == "table",
    "Wilds follower/menu ownership changed; revisit selective-port boundary")

  -- Materialize one researched Johto habitat through the real 1.12.2 spawn
  -- engine. This catches API-shape tests that pass while the final entity
  -- construction, occupancy reservation, or sprite resolution is broken.
  U.teleport(game, "ROUTE_22", 8, 8, "down")
  U.wait(20)
  if wilds.logic._clearMap then wilds.logic:_clearMap("ROUTE_22") end
  local realRoll = ascendant.johtoResearch.rollHabitat
  ascendant.johtoResearch.rollHabitat = function(mapId, terrain)
    assert(mapId == "ROUTE_22" and terrain == "grass",
      "Wilds forwarded the wrong habitat context")
    return { species = "NATU", level = 18 }
  end
  local ok, record, spawnErr, entity = pcall(
    wilds.logic.trySpawn, wilds.logic, game,
    { force = true, x = 10, y = 8 })
  ascendant.johtoResearch.rollHabitat = realRoll
  assert(ok, "Wilds 1.12.2 Johto spawn threw: " .. tostring(record))
  assert(record, "Wilds 1.12.2 Johto spawn failed: " .. tostring(spawnErr))
  assert(record.species == "NATU" and record.level == 18,
    "Wilds materialized the wrong researched habitat")
  assert(entity and entity.sprite and entity.sprite.def,
    "Wilds did not build a visible Johto renderer")
  local asset = wilds.render:resolveAsset("NATU", game, { force = true })
  assert(asset and asset.status == "LOADED" and not asset.fallbackUsed,
    "Wilds could not load Ascendant's Natu overworld asset")
  -- 1.12.2 may materialize a luminance-adjusted runtime SpriteDef instead of
  -- keeping resolveAsset().path byte-identical. The meaningful contract is
  -- a real, non-fallback provider resolution and a loadable entity SpriteDef.
  print("NATU resolved asset:", tostring(asset.path))
  print("NATU entity image:", tostring(entity.sprite.def.image))
  assert(type(entity.sprite.def.image) == "string"
      and entity.sprite.def.image ~= "",
    "Wilds built an empty Natu SpriteDef")
  local shotDir = os.getenv("SHOT_DIR")
  if shotDir then
    U.wait(10)
    assert(U.shot(game, shotDir .. "/wilds_1122_natu_route22.png"),
      "Wilds 1.12.2 Natu screenshot failed")
  end

  print("WILDS 1.12.2 API SMOKE PASS")
  print("ASCENDANT ADAPTERS PASS: habitat + sprites + transactional signals")
  print("VISIBLE JOHTO SPAWN PASS: NATU L18 / ROUTE_22")
end
