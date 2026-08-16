-- Exact 0.1.86 persistence policy for True Legacy Journey.
-- Runtime uses only mod.storage. The archive factory itself still fails closed
-- when a test/tool supplies no sanctioned backend.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}; seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end

local function equal(a, b, seen)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  seen = seen or {}
  if seen[a] == b then return true end
  seen[a] = b
  for key, value in pairs(a) do
    if not equal(value, b[key], seen) then return false end
  end
  for key in pairs(b) do if a[key] == nil then return false end end
  return true
end

local serializer = {
  encode = function() error("unavailable archive must never encode") end,
  decode = function() error("unavailable archive must never decode") end,
}
local createArchive = assert(loadfile(root .. "/legacy_archive.lua"))()
local unavailable = createArchive({
  serializer = serializer,
  edition = "red",
  requireRegistryValidation = false,
})
assert(unavailable.persistent == false,
  "archive without a sanctioned backend unexpectedly became persistent")

local save = {
  version = "red",
  player = { id = 23, name = "BLITZ" },
  flags = { HALL_OF_FAME = true },
  party = { { species = "PIKACHU", level = 81 } },
  modData = { kanto_ascendant = { marker = "untouched" } },
}
local before = copy(save)
local state, reason = unavailable.beginJourney(save, { pact = "legacy" })
assert(state == nil and reason == unavailable.unavailableReason,
  "backend-less archive did not fail closed")
assert(equal(save, before), "backend-less beginJourney mutated the save")

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local body = handle:read("*a")
  handle:close()
  return body
end

local main = read(root .. "/main.lua")
local archiveSource = read(root .. "/legacy_archive.lua")
local journeySource = read(root .. "/legacy_journey.lua")
for _, source in ipairs({ main, archiveSource, journeySource }) do
  for _, forbidden in ipairs({
    "SaveData.persistenceFs", "SaveData.portableFs", "love.filesystem",
    "io.open", "os.execute", "os.getenv", "os.remove", "os.rename",
  }) do
    assert(not source:find(forbidden, 1, true),
      "runtime Legacy code contains forbidden persistence path " .. forbidden)
  end
end
assert(journeySource:find("backend:read(current", 1, true)
    and journeySource:find("mod.storage:write", 1, true)
    and journeySource:find("mod.storage:delete", 1, true),
  "runtime Journey does not use the official 0.1.86 storage facade")
assert(journeySource:find('type(mod.storage.edition) == "function"', 1, true)
    and journeySource:find('return "legacy/archive"', 1, true),
  "runtime Journey does not feature-detect the edition archive contract")
assert(journeySource:find('mod.hooks:wrap("save.write"', 1, true)
    and journeySource:find("archive.importHandoff", 1, true)
    and journeySource:find("archive.finishHandoff", 1, true),
  "pre-save target verification boundary is missing")
assert(archiveSource:find("legacy_lineage_handoff", 1, true)
    and archiveSource:find("targetVerified", 1, true)
    and archiveSource:find("verified offline Legacy", 1, true),
  "capsule verification or pre-0.1.86 migration guard is missing")

print("PASS sandbox 0.1.86 Legacy persistence: official storage only, fail-closed fallback")
