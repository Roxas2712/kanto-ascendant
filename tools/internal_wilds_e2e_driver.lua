-- Clean-install E2E: Kanto Ascendant is the only gameplay mod. Proves that
-- the bundled Wilds core, not an external overworld_wild_spawns install,
-- creates peaceful town Pokemon and visible route encounters.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  U.wait(45)

  local exports = assert(game.mods and game.mods.exports, "exports missing")
  local ascendant = assert(exports.kanto_ascendant, "Ascendant missing")
  local internal = assert(ascendant.internalWilds,
    "bundled Wilds runtime missing")
  assert(internal.bundled == true and internal.source == "bundled",
    "test accidentally loaded an external Wilds mod")
  local wilds = assert(exports.overworld_wild_spawns,
    "bundled Wilds compatibility export missing")
  assert(wilds == internal.exports and wilds.version == "1.12.2",
    "wrong bundled Wilds export/version")
  assert(wilds.follower == nil and wilds.settingsMenus == nil,
    "standalone Wilds follower/menu ownership leaked into Ascendant")

  local compat = assert(ascendant.wildsCompat, "Ascendant Wilds adapter missing")
  assert(compat.installed and compat.wildsVersion == "1.12.2",
    "Ascendant adapter did not bind the bundled provider")

  U.teleport(game, "PALLET_TOWN", 10, 12, "down")
  U.wait(180)
  local ambient = assert(wilds.ambient, "ambient manager missing")
  local townCount = ambient:countActive()
  assert(townCount >= 1,
    "Pallet Town has no peaceful Pokemon in a clean install")
  for npc in pairs(ambient.active or {}) do
    assert(npc.wildsAmbientPokemon == true
        and npc.wildsBattleable == false
        and npc.wildsEncounterEnabled == false,
      "Pallet Town Pokemon is not peaceful ambient scenery")
    assert(npc.sprite and npc.sprite.def and npc.sprite.def.image,
      "Pallet Town Pokemon has no visible sprite")
  end
  assert(U.shot(game, shotDir .. "/01_pallet_town_bundled_pokemon.png"))

  U.teleport(game, "ROUTE_22", 24, 8, "down")
  U.wait(220)
  local logic = assert(wilds.logic, "visible spawn logic missing")
  local visible = 0
  for _, record in pairs(logic.spawns or {}) do
    if record.mapId == "ROUTE_22" and record.visibleSprite ~= false then
      visible = visible + 1
    end
  end
  assert(visible >= 1,
    "Route 22 has no visible grass Pokemon in a clean install")
  local rendered = 0
  for id, record in pairs(logic.spawns or {}) do
    if record.mapId == "ROUTE_22" and record.visibleSprite ~= false then
      local entity = logic.entities[id]
      assert(entity and entity.sprite and entity.sprite.def
          and entity.sprite.def.image,
        "Route 22 visible encounter has no renderer")
      assert(entity.overworldWildSpawn == true,
        "Route 22 record is not an overworld encounter")
      rendered = rendered + 1
    end
  end
  assert(rendered == visible,
    "visible encounter records and rendered entities disagree")
  assert(U.shot(game, shotDir .. "/02_route22_bundled_visible_wild.png"))

  print(("INTERNAL WILDS E2E PASS: Pallet=%d peaceful, Route22=%d visible")
    :format(townCount, visible))
end
