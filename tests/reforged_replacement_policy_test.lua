-- Kanto Reforged is an unreviewed registry-overlap stack, not a claimed fix.
-- Stock engine 0.1.90 supports the classic conflicts list: it prevents both
-- entries from initializing together and asks the player to disable one.
-- A later engine may additionally honor Ascendant's richer replacement
-- metadata, but the release safety boundary must not depend on that extension.
-- Run from the engine checkout with TRAINER_REMATCH_MOD_DIR set.

package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local Json = require("src.link.Json")
local Loader = require("src.mods.Loader")
local Manifest = require("src.mods.Manifest")
local ManagerState = require("src.mods.ManagerState")
local sdk = require("tests.modkit.sdk")

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local function read(path)
  local file = assert(io.open(path, "rb"), path)
  local body = file:read("*a")
  file:close()
  return body
end

local raw = assert(Json.decode(read(root .. "/manifest.json")))
local ascendant = Manifest.validate(raw, root .. "/manifest.json")

local function external(id, github)
  return Manifest.validate({
    id = id, name = id, version = "1.1.7", api = 2,
    entry = "main.lua", profile = "content", github = github,
    dependencies = {}, conflicts = {}, priority = 0,
  }, "mods/" .. id .. "/manifest.json")
end

local exact = external("Kanto-Reforged", "1Jamie/Kanto-Reforged")
local renamed = external("reforged_repository_alias",
  "1Jamie/Kanto-Reforged")

local function contains(rows, wanted)
  for _, value in ipairs(rows or {}) do
    if value == wanted then return true end
  end
  return false
end

assert(contains(raw.conflicts, "Kanto-Reforged"),
  "stock 0.1.90 conflict for the canonical Reforged id is missing")
local conflictSpec = false
for _, spec in ipairs(ascendant.conflictSpecs or {}) do
  if spec.id == "Kanto-Reforged" then conflictSpec = true end
end
assert(conflictSpec, "stock 0.1.90 did not parse the Reforged conflict")

local mods = { kanto_ascendant = ascendant, [exact.id] = exact }
local result = ManagerState.resolveToggle(mods, "kanto_ascendant", true,
  { [exact.id] = true })
if type(Manifest.replacement) == "function" then
  -- Newer engines may implement the declared one-way replacement policy.
  assert(result.apply.kanto_ascendant == true
      and result.apply[exact.id] == false,
    "newer engine did not replace Reforged when Ascendant was enabled")
else
  -- Exact 0.1.90: the manager blocks either attempted co-enable and tells the
  -- player to disable the other mod first.
  assert(contains(result.conflicts, exact.id),
    "stock manager allowed Ascendant beside Reforged")
  result = ManagerState.resolveToggle(mods, exact.id, true,
    { kanto_ascendant = true })
  assert(contains(result.conflicts, "kanto_ascendant"),
    "stock manager allowed Reforged beside Ascendant")
end

local function encoded(mod)
  return Json.encode({
    id = mod.id, name = mod.name or mod.id, version = mod.version or "1.1.7",
    api = 2, entry = "main.lua", profile = "content", github = mod.github,
    dependencies = {}, conflicts = {}, priority = mod.priority or 0,
  })
end

local function statusById(loader)
  local out = {}
  for _, row in ipairs(loader:status().available) do out[row.id] = row end
  return out
end

local loaderRaw = assert(Json.decode(read(root .. "/manifest.json")))
loaderRaw.assets_transforms = nil
-- Unit loaders in a development checkout report 0.0.0-dev. Runtime-version
-- gating is validated separately against the exact 0.1.90 fixture.
loaderRaw.game_version = nil

local function stack(candidate)
  return Loader.new({ fs = sdk.memfs({
    ["mods/kanto_ascendant/manifest.json"] = Json.encode(loaderRaw),
    ["mods/kanto_ascendant/main.lua"] =
      "return function(mod) mod.exports.entryRan = true end",
    ["mods/" .. candidate.id .. "/manifest.json"] = encoded(candidate),
    ["mods/" .. candidate.id .. "/main.lua"] =
      "return function(mod) mod.exports.entryRan = true end",
  }) })
end

if type(Manifest.replacement) == "function" then
  for label, candidate in pairs({ exact_id = exact, repository_alias = renamed }) do
    local detail = assert(Manifest.replacement(ascendant, candidate),
      label .. " did not match the newer replacement policy")
    assert(detail.policy == "replace"
        and detail.reason_en and detail.reason_de
        and detail.resolution_en and detail.resolution_de,
      label .. " replacement lacks bilingual policy text")
    local loader = stack(candidate)
    assert(loader:load({}) == true, label .. " replacement boot was not clean")
    local status = statusById(loader)
    assert(status.kanto_ascendant.state == "loaded",
      label .. " displaced Ascendant")
    assert(status[candidate.id].state == "replaced"
        and status[candidate.id].replacedBy == "kanto_ascendant",
      label .. " was not visibly replaced pre-entry")
  end
else
  local loader = stack(exact)
  loader:load({})
  local status = statusById(loader)
  assert(status.kanto_ascendant.state == "conflict",
    "stock 0.1.90 did not block Ascendant before entry")
  assert(status[exact.id].state == "loaded",
    "stock 0.1.90 unexpectedly broke Reforged while enforcing the conflict")
  assert(not (loader.mods.kanto_ascendant.exports
      and loader.mods.kanto_ascendant.exports.entryRan),
    "Ascendant entry ran despite the stock pre-entry conflict")
end

-- The policy is local to Ascendant. Reforged by itself still loads normally.
local standalone = Loader.new({ fs = sdk.memfs({
  ["mods/Kanto-Reforged/manifest.json"] = encoded(exact),
  ["mods/Kanto-Reforged/main.lua"] = "return function() end",
}) })
assert(standalone:load({}) == true
    and statusById(standalone)["Kanto-Reforged"].state == "loaded",
  "Ascendant conflict leaked into a Reforged-only stack")

-- Likewise, once Reforged is disabled/absent, Ascendant starts normally.
local ascendantOnly = Loader.new({ fs = sdk.memfs({
  ["mods/kanto_ascendant/manifest.json"] = Json.encode(loaderRaw),
  ["mods/kanto_ascendant/main.lua"] = "return function() end",
}) })
assert(ascendantOnly:load({}) == true
    and statusById(ascendantOnly).kanto_ascendant.state == "loaded",
  "Ascendant did not recover after Reforged was removed")

print("Kanto Reforged stock conflict/replacement policy tests passed")
