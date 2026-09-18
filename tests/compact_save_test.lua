-- Run under LuaJIT/LÖVE with the engine's src tree on package.path.
-- Optional arg[1]: absolute KASC source directory; arg[2]: fixture directory.
local root = assert(arg[1], "KASC source directory required")
local Serializer = require("src.core.SaveSerializer")
local original = Serializer.encode
local Compact = assert(loadfile(root .. "/compact_save.lua"))()
local function equal(actual, expected, label)
  assert(actual == expected, label or "values differ")
end
local function roundtrip(data)
  local raw = original(data)
  local compact = Compact.compact(raw)
  local decoded, err = Serializer.decode(compact)
  assert(decoded, err)
  equal(original(decoded), raw, "all keys, types and values must survive")
  equal(original(data), raw, "input must not be mutated")
  equal(Compact.compact(compact), compact, "compaction is idempotent")
  return raw, compact
end

local bytes = {}
for n = 0, 255 do bytes[#bytes + 1] = string.char(n) end
local tricky = {"", "  nickname  ", "a\n  b\r\n c", "\\\"'--[[ ]]",
  "[=[ raw ]=]", "return { foo = true, }", table.concat(bytes),
  "Pokémon ÄÖÜ é 日本語", "line\\\n    string", "\\\\\"tail"}
local edge = {str = tricky, bools = {false, true}, empty = {},
  numbers = {0, -0.25, 1e-12, 1e30, 9007199254740991},
  keys = {[-50] = "negative", [0] = false, [2000] = {},
    ["  strange\n key"] = "  spaced value  "}}
roundtrip(edge)
for n = 1, 150 do
  local t = {index = n, nested = {}}
  for j = 1, 30 do
    t.nested[j * 3] = {n = n * j / 7, s = tricky[(j + n) % #tricky + 1],
      flag = j % 2 == 0, deep = {a = {b = {c = n}}}}
  end
  roundtrip(t)
end
print("PASS: string escapes, all 256 byte values, sparse keys, numbers, 150 nested cases")
for _, source in ipairs({"return {a='single'}", "return {a=[[long]]}",
    "return {a=[=[long]=]}", "return {-- comment\na=1}",
    'return {a="unterminated}', "new-format"}) do
  equal(Compact.compact(source), source, "unknown syntax must remain unchanged")
end
print("PASS: unknown writer formats retain original bytes")

local function read(path)
  local f = assert(io.open(path, "rb")); local b = f:read("*a"); f:close(); return b
end
local fixtureRoot = assert(arg[2], "fixture directory required")
local fixture
for _, name in ipairs({"slot7.BLITZ-known-good-f0d8c192.lua",
    "slot7.BLITZ-latest-update-test-20260815.lua"}) do
  local source = read(fixtureRoot .. "/" .. name)
  local data, err = Serializer.decode(source); assert(data, err)
  local raw, compact = roundtrip(data)
  print(("REAL_SAVE %s original=%d compact=%d reduction=%.2f%%"):format(
    name, #raw, #compact, 100 * (1 - #compact / #raw)))
  fixture = data
end

local mod = {log = {warn = function() end}}
assert(Compact.install(mod))
local wrapped = Serializer.encode
assert(Compact.install(mod))
equal(Serializer.encode, wrapped, "do not stack wrappers")
equal(Serializer.encode(edge), original(edge), "non-save tables unchanged")
local vanilla = {version = "yellow", boxes = {}, modData = {other = {}}}
equal(Serializer.encode(vanilla), original(vanilla), "non-KASC saves unchanged")
local kasc = {version = "yellow", boxes = {}, modData = {kanto_ascendant = edge}}
equal(Serializer.encode(kasc), Compact.compact(original(kasc)))
assert(not pcall(Serializer.encode, {bad = function() end}), "original errors propagate")
local compactImpl = Compact.compact
Compact.compact = function() error("simulated formatting failure") end
equal(Serializer.encode(kasc), original(kasc), "formatting failure falls back")
Compact.compact = compactImpl
print("PASS: scoped hook, repeated installation, original errors, formatting fallback")

fixture.modData = fixture.modData or {}
fixture.modData.kanto_ascendant = fixture.modData.kanto_ascendant or {}
local mon = assert(fixture.boxes[1][1])
fixture.boxes = {}
for b = 1, 120 do
  fixture.boxes[b] = {}
  for s = 1, 20 do fixture.boxes[b][s] = mon end
end
local raw, compact = roundtrip(fixture)
assert(#raw > 2 * 1024 * 1024 and #compact < 2 * 1024 * 1024,
  "large fixture must cross the actual sync limit after compaction")
equal(Serializer.encode(fixture), compact)

local SyncClient = require("src.sync.SyncClient")
local request
local client = SyncClient.new({account = "test", token = "test", transport = {
  begin = function(_, req) request = req; return "fake-request" end,
}})
local handle, err = client:putSave({version = "yellow", slot = 1, blob = raw})
assert(not handle and err == "this save is too large to sync")
equal(client:putSave({version = "yellow", slot = 1, blob = compact}), "fake-request")
local Json = require("src.link.Json")
local sent = assert(Json.decode(request.body, #request.body + 1))
equal(original(assert(Serializer.decode(sent.blob))), raw,
  "wire JSON must preserve every save value")
print(("SYNC_THRESHOLD original=%d compact=%d reduction=%.2f%% pokemon=2400"):format(
  #raw, #compact, 100 * (1 - #compact / #raw)))
print("PASS: actual SyncClient rejects original, accepts compact save; JSON roundtrip intact")

-- Parser rollback: the unchanged engine reader can load compact data without
-- the mod installed. It may then write pretty bytes again, without data loss.
Serializer.encode = original
Serializer.__kascCompactSave = nil
equal(Serializer.encode(assert(Serializer.decode(compact))), raw)
print("PASS: rollback to unmodified engine reader/writer")
return fixture, raw, compact
