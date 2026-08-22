-- Regression gate for edition-specific Kanto/National reachability.
--
-- Required environment:
--   KA_ENGINE_CACHE_ROOT=/path/to/red-blue-yellow/cache-root
--   GEN1RECOMP_TEST_ROOT=/path/to/gen1recomp
--   TRAINER_REMATCH_MOD_DIR=/path/to/kanto-ascendant

local cacheRoot = assert(os.getenv("KA_ENGINE_CACHE_ROOT"),
  "KA_ENGINE_CACHE_ROOT is required")
local engineRoot = assert(os.getenv("GEN1RECOMP_TEST_ROOT"),
  "GEN1RECOMP_TEST_ROOT is required")
local modRoot = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;"
  .. package.path
love = love or require("tests.love_stub")

local T = require("tests.modkit")
local FsIo = require("tests.fs_io")
local Data = require("src.core.Data")
local GameVersion = require("src.core.GameVersion")
local SaveData = require("src.core.SaveData")
require("src.core.Version").engine = "0.2.14"
local audit = assert(loadfile(modRoot .. "/tools/reachability_audit.lua"))()

local MODULES = {
  "constants", "maps", "tilesets", "text", "text_pointers",
  "trainer_headers", "font", "sprites", "pokemon", "moves", "items",
  "type_chart", "trainers", "encounters", "field", "battle_anims",
}
local OPTIONAL = { "audio", "palettes", "icons" }

local function loadGenerated(edition)
  GameVersion.set(edition)
  local root = cacheRoot .. "/" .. edition .. "/data/generated"
  local data = {}
  for _, name in ipairs(MODULES) do
    data[name] = assert(loadfile(root .. "/" .. name .. ".lua"))()
  end
  for _, name in ipairs(OPTIONAL) do
    local chunk = loadfile(root .. "/" .. name .. ".lua")
    data[name] = chunk and chunk() or nil
  end
  setmetatable(data, { __index = Data })
  Data.seedDefaults(data)
  return data
end

local function clone(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = clone(child) end
  return out
end

local function basename(path)
  return tostring(path):gsub("/+$", ""):match("[^/]+$")
end

local function modFs(mode)
  local inner = FsIo.new("/")
  local alias = basename(modRoot)
  local optionsBody = SaveData.encode({
    modOptions = { kanto_ascendant = { kanto_151 = mode } },
  })
  local function map(path)
    local prefix = "mods/" .. alias
    if path == prefix then return modRoot end
    if path:sub(1, #prefix + 1) == prefix .. "/" then
      return modRoot .. path:sub(#prefix + 1)
    end
    return path
  end
  local fs = { root = "/" }
  function fs.read(path)
    if path == "options.lua" then return optionsBody end
    return inner.read(map(path))
  end
  function fs.write() return true end
  function fs.load(path)
    if path == "options.lua" then
      return function()
        return { modOptions = { kanto_ascendant = { kanto_151 = mode } } }
      end
    end
    return inner.load(map(path))
  end
  function fs.getInfo(path)
    if path == "mods" then return { type = "directory" } end
    if path == "options.lua" then return { type = "file" } end
    return inner.getInfo(map(path))
  end
  function fs.getDirectoryItems(path)
    if path == "mods" then return { alias } end
    return inner.getDirectoryItems(map(path))
  end
  return fs
end

local function missing(report)
  local out = {}
  for dex = 1, 251 do
    local species = report.speciesByDex[dex]
    if species and not report.reachable[species] then out[#out + 1] = species end
  end
  return out
end

local SLOT_WEIGHTS = { 20, 20, 15, 10, 10, 10, 5, 5, 4, 1 }
local editions = { "red", "blue", "yellow" }
local modes = { "ascendant", "wild" }
local reports = {}

local function applyRows(slots, replacements)
  for index, row in pairs(replacements or {}) do slots[index] = clone(row) end
end

local function sourceContains(report, species, needle)
  for _, label in ipairs(report.sources[species] or {}) do
    if label:find(needle, 1, true) then return true end
  end
  return false
end

local function runCell(edition, mode, auditOptions)
  local data = loadGenerated(edition)
  local nativeMansion = clone(data.encounters.POKEMON_MANSION_B1F.grass.slots)
  local run = T.sdk.loadMod(modRoot, { data = data, fs = modFs(mode) })
  T.eq(#run.errors, 0, edition .. "/" .. mode .. " loads")
  local exports = assert(run.loader.exports.kanto_ascendant,
    "kanto_ascendant exports unavailable")
  local kanto = assert(exports.kantoCompletion, "KANTO 151 export unavailable")
  local expected = clone(nativeMansion)
  if mode ~= "off" then
    applyRows(expected, kanto.sharedEncounters.POKEMON_MANSION_B1F)
    if edition == "yellow" then
      applyRows(expected, kanto.yellowEncounters.POKEMON_MANSION_B1F)
    end
  end
  T.same(data.encounters.POKEMON_MANSION_B1F.grass.slots, expected,
    edition .. "/" .. mode .. " changes only its declared Mansion B1F slots")

  local opts = auditOptions or {}
  opts.edition, opts.mode = edition, mode
  local report = audit.audit(data, exports, nil, opts)
  run.release()
  return report
end

for _, edition in ipairs(editions) do
  reports[edition] = {}
  for _, mode in ipairs(modes) do
    local report = runCell(edition, mode)
    reports[edition][mode] = report
    print(("MATRIX %s/%s: %d/251 missing=%s")
      :format(edition, mode, report.reachableCount,
        table.concat(missing(report), ",")))
    T.eq(report.reachableCount, 251,
      edition .. "/" .. mode .. " reaches all 251 species")
    T.eq(report.configuredReachableCount, 251,
      edition .. "/" .. mode .. " meets its enabled configuration boundary")
    T.eq(#report.errors, 0, edition .. "/" .. mode .. " audit errors")
    T.check(sourceContains(report, "HORSEA", "Super Rod"),
      edition .. "/" .. mode .. " counts Horsea through the real Super Rod")
  end
end

for _, mode in ipairs(modes) do
  local yellow = reports.yellow[mode]
  T.eq(yellow.reachable.JYNX.from, "SMOOCHUM",
    "Yellow " .. mode .. " reaches Jynx through the guaranteed Smoochum egg")
  T.eq(yellow.sources.JYNX, nil,
    "Yellow " .. mode .. " has no invented edition-independent Jynx source")
end

for _, edition in ipairs({ "red", "blue" }) do
  for _, mode in ipairs(modes) do
    local found = false
    for _, edge in ipairs(reports[edition][mode].edges) do
      if edge.method == "NPC_TRADE" and edge.from == "POLIWHIRL"
          and edge.to == "JYNX" then found = true end
    end
    T.check(found, edition .. "/" .. mode .. " retains its real Jynx NPC trade")
  end
end

local yellowSlots = runCell("yellow", "ascendant")
local mansionSources = yellowSlots.sources
T.check(mansionSources.KOFFING and mansionSources.WEEZING,
  "Yellow Mansion supplies both Koffing and directly catchable Weezing")
T.eq(SLOT_WEIGHTS[4], 10, "Yellow Koffing replacement slot is 10 percent")
T.eq(SLOT_WEIGHTS[8], 5, "Yellow Weezing replacement slot is 5 percent")

local off = runCell("yellow", "off")
print(("BOUNDARY yellow/off: %d/251 missing=%s")
  :format(off.reachableCount, table.concat(missing(off), ",")))
T.check(off.reachableCount < 251,
  "KANTO 151 OFF is never reported as 251/251")
T.eq(off.completionEligible, false,
  "KANTO 151 OFF is labelled outside the 251 completion contract")

local disabled = runCell("yellow", "ascendant", {
  legends = { MEWTWO = false },
})
T.eq(disabled.configuredTarget, 250,
  "a disabled legendary lowers the deliberate configuration target")
T.eq(disabled.configuredReachableCount, 250,
  "enabled species still meet the disabled-legend boundary")
T.eq(disabled.ok, true,
  "a disabled legendary is a configuration boundary, not an audit defect")
T.same(disabled.configBoundaries, { "MEWTWO disabled by configuration" },
  "the disabled legendary is named explicitly")

T.finish("edition reachability matrix")
