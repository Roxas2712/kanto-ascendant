-- Full-engine SDK contract for private catalogue slots #252-279.
-- Run from the Gen1 Recomp checkout:
--   TRAINER_REMATCH_MOD_DIR=../kanto-ascendant \
--     luajit ../kanto-ascendant/tests/extended_species_runtime_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.BULBASAUR) then Data:load() end

local checks = 0
local function ok(value, label)
  checks = checks + 1
  assert(value, label)
end
local function eq(actual, expected, label)
  ok(actual == expected, label .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
-- FsIo normally roots SDK paths at the engine checkout.  An absolute
-- authority path must instead be rooted at the filesystem root; otherwise
-- the adapter prefixes `./` and discovery silently sees no mod at all.
local sdkOpts = { data = Data }
if modPath:sub(1, 1) == "/" then sdkOpts.root = "/" end
local run = T.sdk.loadMod(modPath, sdkOpts)
if not run.mod then
  error("Kanto Ascendant failed real engine SDK load: "
    .. table.concat(run.errors or {}, " | "))
end
ok(run.mod ~= nil, "Kanto Ascendant loads through the real engine SDK")
eq(#(run.errors or {}), 0, "full content merge is clean")
local exports = assert(run.loader.exports.kanto_ascendant)
local runtime = assert(exports.extendedSpeciesRuntime,
  "extended species runtime export is installed")
eq(#runtime.order, 28, "runtime owns exactly slots #252-279")

local game = { data = Data, mods = run.loader }
runtime.install(game)
local matrix = runtime.matrix(game)
local validation = runtime.validate(matrix)
if not validation.ok then
  local messages = {}
  for _, finding in ipairs(validation.findings) do
    messages[#messages + 1] = table.concat({
      finding.species or "?", finding.surface or "?", finding.message or "?",
    }, ":")
  end
  error("runtime matrix failed: " .. table.concat(messages, " | "))
end
eq(validation.rows, 28, "validator inspected all twenty-eight rows")

local bySpecies = {}
for _, row in ipairs(matrix.rows) do bySpecies[row.species] = row end
local authoredMotion = {
  TREECKO = true, GROVYLE = true, SCEPTILE = true,
  TORCHIC = true, COMBUSKEN = true, BLAZIKEN = true,
  MUDKIP = true, MARSHTOMP = true, SWAMPERT = true,
  AMBIPOM = true, MISMAGIUS = true, HONCHKROW = true,
  WEAVILE = true, MAGNEZONE = true, LICKILICKY = true,
  RHYPERIOR = true, TANGROWTH = true,
  ELECTIVIRE = true, MAGMORTAR = true, TOGEKISS = true,
  YANMEGA = true, LEAFEON = true, GLACEON = true, GLISCOR = true,
  MAMOSWINE = true, PORYGON_Z = true, AZURILL = true,
  WYNAUT = true,
}
for _, species in ipairs(runtime.order) do
  local identity = assert(runtime.bySpecies[species])
  local def = assert(Data.pokemon[species], species .. " merged definition")
  local row = assert(bySpecies[species], species .. " matrix row")
  eq(def.internalRuntimeDex, identity.internalRuntimeDex,
    species .. " merged internal runtime id")
  eq(def.sourceDex, identity.sourceDex,
    species .. " merged National-Dex source id")
  local expectedMotion = authoredMotion[species] == true
  eq(row.animation.mode, expectedMotion and "animated" or "static",
    species .. " reports only identity-correct authored Crystal motion")
  eq(row.animation.authoredTiming, expectedMotion,
    species .. " timing provenance matches its supplied source")
  for variant, surfaces in pairs(row.surfaces) do
    local internal = tostring(identity.internalRuntimeDex)
    ok(surfaces.battleEnemy.path:find(
      "/front/" .. variant .. "/" .. internal .. "/001.png", 1, true),
      species .. " " .. variant .. " enemy uses exact internal art card")
    ok(surfaces.battlePlayer.path:find(
      "/back/" .. variant .. "/" .. internal .. "/001.png", 1, true),
      species .. " " .. variant .. " player uses exact internal back card")
    eq(surfaces.wilds.sourceDex, identity.sourceDex,
      species .. " " .. variant .. " Wilds uses National identity")
    eq(surfaces.voxel.sourceDex, identity.sourceDex,
      species .. " " .. variant .. " voxel uses National identity")
    eq(surfaces.voxel.valid, true,
      species .. " " .. variant .. " voxel mapping is live")
  end
end

eq(runtime.sourceDex("AZURILL", Data), 298,
  "Azurill private #278 maps to National #298")
eq(runtime.sourceDex("WYNAUT", Data), 360,
  "Wynaut private #279 maps to National #360")
eq(runtime.internalRuntimeDex("AZURILL", Data), 278,
  "Azurill keeps private runtime slot #278")
eq(runtime.internalRuntimeDex("WYNAUT", Data), 279,
  "Wynaut keeps private runtime slot #279")

local wilds = assert(exports.internalWilds and exports.internalWilds.exports)
local AnimatedSprites = assert(wilds.lib.require("animated_sprites"))
eq(AnimatedSprites.resolveSpeciesId("AZURILL", game,
    exports.internalWilds.proxy), 298,
  "real bundled Wilds resolver maps Azurill through sourceDex")
eq(AnimatedSprites.resolveSpeciesId("WYNAUT", game,
    exports.internalWilds.proxy), 360,
  "real bundled Wilds resolver maps Wynaut through sourceDex")
eq(AnimatedSprites.resolveSpeciesId(278, game,
    exports.internalWilds.proxy), 278,
  "an explicitly numeric National id remains literal")

for _, species in ipairs({ "TREECKO", "AMBIPOM", "AZURILL", "WYNAUT" }) do
  local state = assert(exports.crystalAnimation.presentationAnimation(
    species, { species = species }, "front", "summary", { data = Data }))
  local expectedMotion = authoredMotion[species] == true
  eq(state.animated, expectedMotion,
    species .. " presentation state matches supplied authored motion")
  eq(state.authoredTiming, expectedMotion,
    species .. " presentation state carries no invented timing")
end

local encoded = runtime.matrixJson(game)
ok(type(encoded) == "string" and encoded:find('"rows"', 1, true),
  "runtime matrix has a machine-readable JSON representation")

run.release()
print(("EXTENDED SPECIES RUNTIME PASS: %d checks"):format(checks))
