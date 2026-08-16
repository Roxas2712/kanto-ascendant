local root = os.getenv("KANTO_SIGNALS_MOD_DIR") or "."
local data = assert(loadfile(root .. "/hevo_species_data.lua"))()
local create = assert(loadfile(root .. "/hevo_species.lua"))()
local createPackages = assert(loadfile(root .. "/hevo_packages.lua"))()

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local function registry(seed)
  local values = seed or {}
  return {
    values = values,
    get = function(self, id) return self.values[id] end,
    register = function(self, id, row)
      assert(self.values[id] == nil, "duplicate registration " .. id)
      self.values[id] = row
    end,
    patch = function(self, id, row)
      local current = assert(self.values[id], "missing patch target " .. id)
      if type(row) ~= "table" then self.values[id] = row return end
      for key, value in pairs(row) do current[key] = value end
    end,
  }
end

local parents = {
  "AIPOM", "MISDREAVUS", "MURKROW", "SNEASEL", "MAGNETON",
  "LICKITUNG", "RHYDON", "TANGELA", "ELECTABUZZ", "MAGMAR",
  "TOGETIC", "YANMA", "EEVEE", "GLIGAR", "PILOSWINE", "PORYGON2",
  "MARILL", "WOBBUFFET",
}
local pokemonSeed = {}
for _, id in ipairs(parents) do pokemonSeed[id] = { id = id, evolutions = {} } end
local moveSeed = {}
for _, id in ipairs({
  "SCRATCH", "TAIL_WHIP", "SAND_ATTACK", "ASTONISH", "GROWL",
  "TACKLE", "THUNDERSHOCK", "SUPERSONIC", "LICK", "STOMP",
  "QUICK_ATTACK", "LEER", "EMBER", "SPLASH", "CHARM", "COUNTER",
}) do moveSeed[id] = { id = id, effect = "TESTED_EFFECT" } end

local crystalSentinel = { untouched = true }
local mod = {
  id = "kanto_ascendant", path = root,
  exports = { crystalLearnsetAudit = crystalSentinel },
  content = {
    pokemon = registry(pokemonSeed), moves = registry(moveSeed),
    items = registry(), cries = registry(), text = registry(),
    item_effects = registry(), evolution_methods = registry(),
    move_effects = registry(),
    icons = registry(), constants = registry({ dexSize = 260, dexDigits = 3 }),
  },
}
local packages = createPackages(mod, {
  i18n = { text = function(en) return en end },
  bag = { add = function() return true end },
})
local hevo = create(mod, {
  data = data, i18n = { text = function(en) return en end },
  packages = packages,
})

local englishMoveNames = {
  ROLLOUT = "ROLLOUT",
  ANCIENTPOWER = "ANCIENTPOWER",
  DOUBLE_HIT = "DOUBLE HIT",
}
for id, expected in pairs(englishMoveNames) do
  eq(mod.content.moves:get(id).name, expected,
    id .. " keeps its English display name")
end
local germanPreview = create({ exports = {} }, {
  data = data, packages = {}, enabled = false,
  i18n = { text = function(_, de) return de end },
})
local germanMoveNames = {
  ROLLOUT = "WALZER",
  ANCIENTPOWER = "ANTIK-KRAFT",
  DOUBLE_HIT = "DOPPELSCHLAG",
}
for id, expected in pairs(germanMoveNames) do
  eq(germanPreview.moveNames[id], expected,
    id .. " exposes its official German display name")
  check(#expected <= 12,
    id .. " German name fits the twelve-glyph Reminder row")
end

eq(#hevo.order, 19, "the HEVO catalogue registers exactly nineteen species")
eq(data._meta.speciesCount, 19, "generated HGSS source declares nineteen species")
check(data._meta.source:find("pokeheartgold", 1, true),
  "generated rows retain their HGSS source")
eq(mod.content.constants:get("dexSize"), 279,
  "HEVO extends the private catalogue through slot 279")
check(mod.exports.crystalLearnsetAudit == crystalSentinel,
  "HEVO never overwrites the Crystal learnset audit export")
check(mod.exports.hevoSpeciesAudit == hevo.audit,
  "HEVO exposes its own separate projection audit")

local seenDex = {}
for index, species in ipairs(hevo.order) do
  local expectedDex = 260 + index
  local row = mod.content.pokemon:get(species)
  check(row ~= nil, species .. " is registered")
  eq(row.dex, expectedDex, species .. " owns its stable private Dex slot")
  check(not seenDex[row.dex], species .. " does not collide with another slot")
  seenDex[row.dex] = species
  check(mod.content.cries:get(species) ~= nil,
    species .. " has a registered cry")
  for _, move in ipairs(row.level1Moves or {}) do
    check(moveSeed[move] ~= nil,
      species .. " level-one projection contains only registered moves")
    check(not hevo.mechanicsBlocked[move],
      species .. " level-one projection contains no mechanics blocker")
  end
  for _, learn in ipairs(row.learnset or {}) do
    check(moveSeed[learn.move] ~= nil,
      species .. " schedule contains only registered moves")
    check(not hevo.mechanicsBlocked[learn.move],
      species .. " schedule contains no mechanics blocker")
  end
  for _, relative in ipairs({
    "/assets/hevo_19/front/" .. expectedDex .. ".png",
    "/assets/hevo_19/back/" .. expectedDex .. ".png",
    "/assets/audio/hevo_19_cries/" .. expectedDex .. ".ogg",
  }) do
    local file = io.open(root .. relative, "rb")
    check(file ~= nil, species .. " ships " .. relative)
    if file then file:close() end
  end
end

local targetCount = 0
for target, evolution in pairs(hevo.parentEvolutions) do
  targetCount = targetCount + 1
  local package = assert(packages.byId[evolution.package],
    target .. " references an authoritative package")
  check(package.method == evolution.method,
    target .. " uses the package-owned evolution method")
  if package.kind == "item" then
    check(mod.content.items:get(package.item) ~= nil,
      target .. " has a registered direct-use evolution item")
  else
    check(evolution.item == nil,
      target .. " does not invent a relic for field/knowledge evolution")
  end
  local found = false
  for _, row in ipairs(mod.content.pokemon:get(evolution.parent).evolutions) do
    if row.species == target and row.method == package.method
        and row.item == package.item then
      found = true
    end
  end
  check(found, target .. " is appended without replacing the parent chain")
end
eq(targetCount, 17, "the fifteen packages expose exactly seventeen targets")
eq(#packages.order, 15, "one registry owns exactly fifteen packages")
eq(packages.audit.registeredTargets, 17,
  "the authoritative registry reports exactly seventeen targets")
local registeredItems = 0
for _, package in ipairs(packages.order) do
  if package.item then registeredItems = registeredItems + 1 end
end
eq(registeredItems, 8,
  "only the eight item packages register consumable evolution items")
eq(#mod.content.pokemon:get("EEVEE").evolutions, 2,
  "Eevee retains both targeted HEVO branches")
eq(mod.content.pokemon:get("AZURILL").evolutions[1].species, "MARILL",
  "Azurill keeps its own friendship evolution")
eq(mod.content.pokemon:get("WYNAUT").evolutions[1].level, 15,
  "Wynaut keeps its real level-15 evolution")

for _, skipped in ipairs(hevo.audit.skippedRows) do
  if hevo.mechanicsBlocked[skipped.move] then
    check(true, skipped.move .. " is audited instead of installed as a no-op")
  end
end
check(#hevo.audit.skippedRows > 0,
  "unavailable HGSS rows are visible in the separate audit")

print(("HEVO SPECIES PASS: %d assertions"):format(assertions))
