local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local checks = 0
local function ok(value, label)
  checks = checks + 1
  assert(value, "FAIL: " .. label)
end
local function eq(actual, expected, label)
  ok(actual == expected, label .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local active = false
local listener
local boundary = {
  isActive = function() return active end,
  onChanged = function(fn) listener = fn return fn end,
}
local events = { rows = {} }
function events:on(name, fn) self.rows[name] = fn end
local hooks = { rows = {} }
function hooks:wrap(name, fn) self.rows[name] = fn end
local mod = {
  id = "kanto_ascendant", exports = {}, events = events, hooks = hooks,
}
local journey = {
  activeCharacter = function(save) return save.character end,
  syncHevoPersistent = function() return true end,
}
local packages = assert(loadfile("hevo_packages.lua"))()(mod, {
  enabled = false, journey = journey, beyondKanto = boundary,
})
local function save(character)
  return {
    character = character, flags = {}, inventory = {}, bagOrder = {},
    party = {}, boxes = {}, modData = { kanto_ascendant = {
      extended_characters = { player_character = character },
    } },
  }
end

local red = save("RED")
local staged, stageWhy = packages.stageCharacter(red, "RED")
ok(not staged and stageWhy == "beyond-kanto-sealed",
  "sealed HEVO completion cannot grant packages or evolution rewards")
eq(next(red.inventory), nil, "sealed HEVO package gate mutates no inventory")
active = true
staged = assert(packages.stageCharacter(red, "RED"))
ok(#staged.packages == 5, "activated RED seal stages all authored packages")
local persistent = packages.persistent(red, false)
ok(persistent.packageUnlocks.protector,
  "activated HEVO package unlock is persisted")
active = false
local eligible, eligibleWhy = packages.eligibility(red,
  { species = "RHYDON" }, "protector", "item",
  { item = "PROTECTOR", data = { moves = {} } })
ok(not eligible and eligibleWhy == "beyond-kanto-sealed",
  "sealed save cannot use a previously archived non-Gen-I evolution unlock")
active = true
ok(packages.eligibility(red, { species = "RHYDON" }, "protector", "item",
    { item = "PROTECTOR", data = { moves = {} } }),
  "activation restores the same archived HEVO evolution unlock")

active = false
local encounters = assert(loadfile("hevo_dungeon_encounters.lua"))()(mod, {
  packages = packages, beyondKanto = boundary,
})
local pokemon = {}
local dex = 1
for _, package in ipairs(packages.order) do
  for _, target in ipairs(package.targets) do
    if not pokemon[target.parent] then
      pokemon[target.parent] = {
        dex = encounters.KANTO_FALLBACK[target.parent] and 200 + dex or dex,
      }
      dex = dex + 1
    end
  end
end
for _, fallback in pairs(encounters.KANTO_FALLBACK) do
  pokemon[fallback] = pokemon[fallback] or { dex = dex }
  if pokemon[fallback].dex > 151 then pokemon[fallback].dex = dex end
  dex = dex + 1
end
local waterDex = {
  GOLDUCK=55, POLIWHIRL=61, TENTACRUEL=73, DEWGONG=87,
  CLOYSTER=91, KINGLER=99, SEAKING=119, GYARADOS=130, LAPRAS=131,
  LANTURN=171, AZUMARILL=184, QUAGSIRE=195, QWILFISH=211,
  CORSOLA=222, OCTILLERY=224, MANTINE=226,
}
for _, layouts in pairs(encounters.WATER_LAYOUTS) do
  for _, rows in pairs(layouts) do
    for _, species in ipairs(rows) do
      pokemon[species] = { dex = assert(waterDex[species], species) }
    end
  end
end
local trialSave = save("RED")
trialSave.flags[encounters.ENTERED_FLAG_PREFIX .. "RED"] = true
local game = { save = trialSave, data = { pokemon = pokemon, encounters = {} } }
local offRows = encounters.rows(trialSave, "RED", game)
ok(#offRows > 0, "sealed HEVO cave retains a playable encounter habitat")
local usedFallback = false
for _, row in ipairs(offRows) do
  ok(pokemon[row.species].dex <= 151,
    "sealed HEVO cave encounter is constrained to #1-151")
  ok(row.evolvesTo == nil,
    "sealed HEVO cave publishes no non-Gen-I evolution reward")
  usedFallback = usedFallback or row.kantoFallback == true
end
ok(usedFallback, "sealed HEVO cave deterministically substitutes authored rows")
local mapsIdentity = encounters.MAPS
ok(encounters.install(game), "sealed encounter controller installs on authored maps")
ok(type(listener) == "function", "encounter controller listens to activation")

local function auditWater(expectBeyond, label)
  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    local characterSave = save(character)
    characterSave.flags[encounters.ENTERED_FLAG_PREFIX .. character] = true
    game.save = characterSave
    encounters.sync(game)
    local sawJohto = false
    for _, mapId in ipairs(encounters.WATER_MAPS[character]) do
      local slots = game.data.encounters[mapId].water.slots
      eq(#slots, encounters.SLOT_COUNT,
        label .. " " .. mapId .. " keeps ten authored Surf slots")
      local gyarados = 0
      local totalWeight = 0
      for index, slot in ipairs(slots) do
        eq(slot.weight, encounters.WATER_SLOT_WEIGHTS[index],
          label .. " " .. mapId .. " preserves Surf bucket " .. index)
        totalWeight = totalWeight + slot.weight
        local speciesDex = assert(pokemon[slot.species], slot.species).dex
        ok(speciesDex >= 1 and speciesDex <= (expectBeyond and 251 or 151),
          label .. " " .. mapId .. " stays inside its active dex boundary")
        if speciesDex > 151 then sawJohto = true end
        if slot.species == "GYARADOS" then
          gyarados = gyarados + 1
          eq(index, encounters.GYARADOS_SLOT,
            label .. " " .. mapId .. " keeps Gyarados in slot 9")
        end
      end
      eq(gyarados, 1,
        label .. " " .. mapId .. " has exactly one Gyarados slot")
      eq(totalWeight, 256,
        label .. " " .. mapId .. " Surf weights sum to 256")
    end
    eq(sawJohto, expectBeyond,
      label .. " " .. character .. " Johto water presence follows the seal")
  end
  game.save = trialSave
  encounters.sync(game)
end

auditWater(false, "sealed")

active = true
listener(true, game)
eq(encounters.MAPS, mapsIdentity,
  "activation reuses the exact same HEVO map/script set")
auditWater(true, "active")
local onRows = encounters.rows(trialSave, "RED", game)
local sawExtended, sawTarget = false, false
for _, row in ipairs(onRows) do
  sawExtended = sawExtended or (pokemon[row.species].dex > 151)
  sawTarget = sawTarget or row.evolvesTo ~= nil
end
ok(sawExtended and sawTarget,
  "activation restores authored extended cave encounters and targets")

-- A missing/out-of-range Johto definition is never published.  The exact
-- Kanto slot underneath it remains registered, so the ten-slot table and its
-- single Gyarados survive without leaking a fabricated species identity.
local savedLanturn = pokemon.LANTURN
pokemon.LANTURN = nil
local blueSave = save("BLUE")
blueSave.flags[encounters.ENTERED_FLAG_PREFIX .. "BLUE"] = true
game.save = blueSave
encounters.sync(game)
local blueWater = game.data.encounters.KA_HEVO_BLUE_TIDAL_DEPTHS.water.slots
eq(#blueWater, encounters.SLOT_COUNT,
  "missing Johto registration falls back to ten safe Kanto slots")
local foundLanturn = false
for _, slot in ipairs(blueWater) do
  foundLanturn = foundLanturn or slot.species == "LANTURN"
  ok(pokemon[slot.species] ~= nil,
    "missing Johto registration never publishes an unknown swimmer")
end
ok(not foundLanturn,
  "missing Johto registration is omitted from the active water layout")
pokemon.LANTURN = savedLanturn
game.save = trialSave
encounters.sync(game)

-- A registered identity outside both supported regional ranges is foreign to
-- this habitat.  OFF must ignore the Beyond layout entirely; ON must replace
-- the poisoned slot with its exact registered Kanto counterpart.
local savedBlueFirst = encounters.WATER_LAYOUTS.BEYOND.BLUE[1]
encounters.WATER_LAYOUTS.BEYOND.BLUE[1] = "TREECKO"
pokemon.TREECKO = { dex = 252 }
game.save = blueSave
active = false
encounters.sync(game)
local foreignOff = game.data.encounters.KA_HEVO_BLUE_TIDAL_DEPTHS.water.slots
eq(#foreignOff, encounters.SLOT_COUNT,
  "sealed foreign registry still publishes ten safe Kanto slots")
eq(foreignOff[1].species, encounters.WATER_LAYOUTS.KANTO.BLUE[1],
  "sealed mode never consults a foreign Beyond-water registration")
active = true
encounters.sync(game)
local foreignOn = game.data.encounters.KA_HEVO_BLUE_TIDAL_DEPTHS.water.slots
eq(#foreignOn, encounters.SLOT_COUNT,
  "active foreign registry still publishes ten safe slots")
eq(foreignOn[1].species, encounters.WATER_LAYOUTS.KANTO.BLUE[1],
  "active mode replaces a #252 swimmer with its Kanto slot")
local foreignGyarados = 0
for _, slot in ipairs(foreignOn) do
  ok(slot.species ~= "TREECKO",
    "active mode never leaks a foreign registered swimmer")
  if slot.species == "GYARADOS" then foreignGyarados = foreignGyarados + 1 end
end
eq(foreignGyarados, 1,
  "foreign-slot fallback retains exactly one low-probability Gyarados")
encounters.WATER_LAYOUTS.BEYOND.BLUE[1] = savedBlueFirst
pokemon.TREECKO = nil

-- Malformed registry metadata and an unreadable Beyond boundary both fail
-- closed to known #1-151 swimmers.  Neither case may fabricate a partial
-- Johto table from whichever rows happened to validate.
local savedMantine = pokemon.MANTINE
pokemon.MANTINE = { dex = "not-a-dex" }
encounters.sync(game)
local malformedOn = game.data.encounters.KA_HEVO_BLUE_TIDAL_DEPTHS.water.slots
eq(#malformedOn, encounters.SLOT_COUNT,
  "malformed active registry still publishes ten safe slots")
for _, slot in ipairs(malformedOn) do
  ok(slot.species ~= "MANTINE",
    "malformed Johto metadata is replaced slot-for-slot")
  ok(pokemon[slot.species] and tonumber(pokemon[slot.species].dex),
    "malformed active registry never publishes an unresolved identity")
end
pokemon.MANTINE = savedMantine

local savedBoundary = boundary.isActive
boundary.isActive = function() error("malformed boundary", 0) end
local malformedBoundary = encounters.waterSpecies(
  blueSave, "BLUE", game)
eq(#malformedBoundary, encounters.SLOT_COUNT,
  "throwing Beyond boundary retains the complete Kanto table")
for _, species in ipairs(malformedBoundary) do
  ok(pokemon[species].dex <= 151,
    "throwing Beyond boundary fails closed at #151")
end
boundary.isActive = savedBoundary
active = true
game.save = trialSave
encounters.sync(game)

active = false
listener(false, game)
auditWater(false, "resealed")
local adapter = assert(loadfile("legacy_dungeon_adapter.lua"))()({
  archive = {}, packages = packages, beyondKanto = boundary,
  i18n = { text = function(en) return en end },
})
local canFinalize, finalWhy = adapter.canFinalize(trialSave, "RED")
ok(not canFinalize and finalWhy == "beyond-kanto-sealed",
  "final HEVO seal remains reward-sealed before activation")
local text = adapter.failureText(finalWhy)
ok(text:find("BEYOND KANTO", 1, true)
    and text:find("then return", 1, true),
  "final seal explains activation and a safe return instead of unfinished puzzle")

for _, file in ipairs({ "hidden_evolution_red_path.lua",
    "hidden_evolution_blue_campaign.lua", "hidden_evolution_green_grove.lua" }) do
  local handle = assert(io.open(file, "rb"))
  local source = handle:read("*a"); handle:close()
  ok(source:find("failureText%(why%)") ~= nil,
    file .. " maps the central Beyond-Kanto reason into final-seal UX")
end

print(("beyond_kanto_hevo_gate_test: %d checks passed"):format(checks))
