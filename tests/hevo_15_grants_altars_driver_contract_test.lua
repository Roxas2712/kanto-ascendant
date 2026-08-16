-- Fail-closed source contract for the installed-package HEVO-15 grant/altar
-- driver.  It proves the product registry and refuses QA shortcuts which
-- could manufacture the receipt without the real grant and map surfaces.

local root = assert(os.getenv("KA_HEVO_MOD"), "KA_HEVO_MOD required")
local driverPath = root .. "/tests/hevo_15_grants_altars_visual_driver.lua"
assert(loadfile(driverPath), "HEVO-15 package driver does not compile")
assert(loadfile(root .. "/hevo_packages.lua"), "HEVO packages do not compile")
assert(loadfile(root .. "/legacy_dungeon_adapter.lua"),
  "HEVO dungeon adapter does not compile")

local stream = assert(io.open(driverPath, "rb"))
local source = stream:read("*a"); stream:close()
local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function contains(needle, message)
  check(source:find(needle, 1, true) ~= nil, message or ("missing " .. needle))
end

-- The package identity is part of the native save namespace.  Keep the
-- same-hash plan generator, HEVO matrix manifest, and runtime driver on one
-- exact value so a plan refresh cannot silently test a different save.
local expectedIdentity = "ka-hevo15-grants-altars-package"
local matrix = assert(loadfile(root .. "/tools/hevo_package_matrix_manifest.lua"))()
local grantsAltars = assert(matrix.grantsAltars and matrix.grantsAltars[1],
  "HEVO matrix must expose the grants/altars package")
check(grantsAltars.identity == expectedIdentity,
  "HEVO matrix identity must match the installed-package driver")
check(grantsAltars.driver == driverPath,
  "HEVO matrix driver must be the installed-package driver")
contains('identity == "' .. expectedIdentity .. '"',
  "runtime driver must assert the HEVO matrix identity")

local generatorPath = root .. "/tools/update_final_same_hash_l01_l03.py"
local generatorStream = assert(io.open(generatorPath, "rb"))
local generatorSource = generatorStream:read("*a"); generatorStream:close()
check(generatorSource:find(
    '"l03-hevo15-grants-altars", "' .. expectedIdentity .. '"', 1, true) ~= nil,
  "same-hash plan generator identity must match the HEVO matrix and driver")

for _, needle in ipairs({
  "legacyDungeonAdapter", "adapter.finalize(game",
  "STAGED_TRIAL_FINALIZATION_BOUNDARIES",
  "REAL_LEGACY_DUNGEON_ADAPTER_FINALIZE",
  "SaveData.load", "game:restoreSave", "U.tap(game, \"a\")",
  "screenId == \"PartyMenu\"", "state.newSpecies == row.target",
  "KA_HEVO_ALTAR_MAGNETIC_FIELD", "KA_HEVO_ALTAR_ICE_FIELD",
  "KA_HEVO_ALTAR_MOSS_FIELD", "packages=15/15 targets=17/17 first_grants=8/8",
  "physical_altars=3/3", "manual_package_flag_writes=false",
}) do contains(needle) end

for _, forbidden in ipairs({
  "packages.stageCharacter", "packages.stageRecovery",
  "packages.useFieldAltar", "Evolution.request", "Evolution.evolve",
}) do
  check(source:find(forbidden, 1, true) == nil,
    "driver bypasses production with " .. forbidden)
end
check(source:find("packageUnlocks%s*%[[^%]]+%]%s*=%s*[^=]") == nil,
  "driver writes a package unlock directly")
check(source:find("evolutionUnlocks%s*%[[^%]]+%]%s*=%s*[^=]") == nil,
  "driver writes an evolution unlock directly")
check(source:find("firstGrants%s*%[[^%]]+%]%s*=%s*[^=]") == nil,
  "driver writes a first-grant sentinel directly")
check(source:find("mon%.species%s*=%s*[^=]") == nil,
  "driver mutates an evolved species directly")

local function registry(seed)
  local result = { values = seed or {} }
  function result:get(id) return self.values[id] end
  function result:register(id, row)
    assert(not self.values[id], "duplicate " .. tostring(id))
    self.values[id] = row
  end
  function result:patch(id, row)
    self.values[id] = self.values[id] or {}
    for key, value in pairs(row) do self.values[id][key] = value end
  end
  return result
end

local mapScripts = registry()
function mapScripts:register(id, row)
  local existing = self.values[id]
  if not existing then self.values[id] = row return end
  existing.talk = existing.talk or {}
  for key, handler in pairs(row.talk or {}) do existing.talk[key] = handler end
  existing.priority = math.max(existing.priority or 0, row.priority or 0)
end
local mod = { id = "kanto_ascendant", exports = {}, content = {
  item_effects = registry(), items = registry(), evolution_methods = registry(),
  maps = registry({
    BLUE = { objects = {} }, GREEN = { objects = {} },
  }),
  text = registry(), map_scripts = mapScripts,
  text_pointers = { patch = function() end },
} }
local make = assert(loadfile(root .. "/hevo_packages.lua"))()
local packages = make(mod, { i18n = { text = function(en) return en end } })
check(#packages.order == 15, "product registry must own exactly 15 packages")
check(packages.audit.registeredTargets == 17,
  "product registry must own exactly 17 targets")

local field = {
  magnetic_field = { field = "KA_HEVO_MAGNETIC_ALTAR",
    parent = "MAGNETON", target = "MAGNEZONE", map = "BLUE", x = 11 },
  ice_field = { field = "KA_HEVO_ICE_ALTAR",
    parent = "EEVEE", target = "GLACEON", map = "BLUE", x = 27 },
  moss_field = { field = "KA_HEVO_MOSS_ALTAR",
    parent = "EEVEE", target = "LEAFEON", map = "GREEN", x = 39 },
}
local fieldCount = 0
for id, expected in pairs(field) do
  local row = assert(packages.byId[id], "missing field package " .. id)
  fieldCount = fieldCount + 1
  check(row.kind == "field" and row.field == expected.field,
    id .. " must retain its exact field identity")
  check(#row.targets == 1 and row.targets[1].parent == expected.parent
      and row.targets[1].target == expected.target,
    id .. " must retain its exact parent/target")
  check(packages.byMethod[row.method] == row,
    id .. " must own a registered evolution method")
  check(packages.registerFieldAltar(expected.map,
    "TEXT_" .. id:upper(), id, { x = expected.x, y = 9 }),
    id .. " altar must register")
end
check(fieldCount == 3, "product must expose exactly three field packages")

local altarObjects = 0
for _, mapId in ipairs({ "BLUE", "GREEN" }) do
  for _, object in ipairs(mod.content.maps:get(mapId).objects or {}) do
    if tostring(object.name):find("KA_HEVO_ALTAR_", 1, true) == 1 then
      altarObjects = altarObjects + 1
      check(object.sprite == "SPRITE_POKE_BALL",
        object.name .. " must remain distinct from quiz relics")
      check(object.movement == "STAY" and object.range == "NONE",
        object.name .. " must remain a reusable stationary interaction")
    end
  end
end
check(altarObjects == 3, "exactly three physical field altars must register")

local save = { flags = {}, inventory = {}, party = {}, modData = {} }
local lockedCalls = 0
local locked, lockedWhy = packages.useFieldAltar({ save = save, data = {} },
  "magnetic_field", { species = "MAGNETON" }, nil, {
    request = function() lockedCalls = lockedCalls + 1 end,
  })
check(locked == false and lockedWhy == "locked" and lockedCalls == 0,
  "locked altar must fail before reaching Evolution.request")

for id, expected in pairs(field) do
  assert(packages.stageRecovery(save,
    id == "moss_field" and "GREEN" or "BLUE", { id }, false))
  local calls, trigger = 0
  local ok, result = packages.useFieldAltar({ save = save, data = {} }, id,
    { species = expected.parent }, nil, {
      request = function(_, _, value)
        calls, trigger = calls + 1, value
        return expected.target
      end,
    })
  check(ok and result == expected.target and calls == 1,
    id .. " must cross the request boundary exactly once")
  check(trigger.kind == "hevo_field" and trigger.field == expected.field
      and trigger.package == id,
    id .. " must pass the exact registered Evolution.request trigger")
end

print(("HEVO-15 grants/altars driver contract: PASS (%d assertions)")
  :format(assertions))
