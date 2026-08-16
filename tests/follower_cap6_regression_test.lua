-- 6.5.4 regression: the native follower contract spans the complete party.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local function factory(name) return assert(loadfile(root .. "/" .. name))() end

local edition = "red"
local gameVersion = {
  get = function() return edition end,
  isYellow = function() return edition == "yellow" end,
}

local bucket = {
  follower_config = {
    version = 1, count = 4, mode = "party", presentation = "ascendant_box",
    custom = {}, nextId = 0,
  },
}
local listeners = {}
local mod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key) return bucket[key] end,
    set = function(_, key, value) bucket[key] = value end,
  },
  events = { on = function(_, name, callback) listeners[name] = callback end },
  hooks = { wrap = function() end },
  ui = {},
}
local party = {}
for index, species in ipairs({
  "PIKACHU", "ESPEON", "SCIZOR", "TYRANITAR", "LAPRAS", "CHARIZARD",
}) do
  party[index] = { species = species, hp = 30, dvs = {} }
end
local game = {
  save = {
    party = party, boxes = {}, flags = {}, options = { modOptions = {} },
  },
  mods = { modOptions = {} },
}

local config = factory("follower_config.lua")(mod, { gameVersion = gameVersion })
config.install(game, { applyConfig = function() end })
assert(config.count() == 4,
  "an existing four-follower save must retain its explicit count")
assert(config.setCount(6) == 6 and bucket.follower_config.count == 6,
  "the save-local follower count did not accept six")

local selection = factory("follower_selection.lua")({
  gameVersion = gameVersion, config = config,
})
local rows = selection.activeMany(game, 6)
assert(#rows == 6 and rows[1].mon == party[1] and rows[6].mon == party[6],
  "Red did not resolve all six healthy party followers")
edition = "blue"
rows = selection.activeMany(game, 6)
assert(#rows == 6 and rows[1].mon == party[1] and rows[6].mon == party[6],
  "Blue did not resolve all six healthy party followers")
edition = "red"

-- Old CUSTOM ids beyond the historical visible cap must already be preserved;
-- raising Count exposes them in-place rather than allocating duplicates.
config.setMode("custom")
for _, candidate in ipairs(party) do assert(config.add(candidate)) end
assert(#config.customIds() == 6, "six CUSTOM identities were not preserved")
config.setCount(4)
assert(#selection.activeMany(game, config.count()) == 4,
  "legacy Count=4 did not remain a visibility-only clamp")
config.setCount(6)
rows = selection.activeMany(game, config.count())
assert(#rows == 6 and rows[6].mon == party[6],
  "saved CUSTOM followers five and six did not reappear")

-- A save that deliberately hid the tail at Count=1 must reload unchanged.
-- SHOW FOLLOWER then reveals the stored sixth identity without a reset or a
-- second allocation of any Pokemon id.
config.setCount(1)
local savedIds = table.concat(config.customIds(), ",")
local reloaded = factory("follower_config.lua")(mod, {
  gameVersion = gameVersion,
})
reloaded.install(game, { applyConfig = function() end })
assert(reloaded.count() == 1
    and table.concat(reloaded.customIds(), ",") == savedIds,
  "Count=1 hidden CUSTOM tail did not survive reload")
local reloadSelection = factory("follower_selection.lua")({
  gameVersion = gameVersion, config = reloaded,
})
assert(#reloadSelection.activeMany(game, reloaded.count()) == 1,
  "Count=1 save exposed hidden followers during reload")
assert(reloaded.show(party[6]) == true and reloaded.count() == 6,
  "SHOW FOLLOWER did not reveal the saved sixth identity")
assert(table.concat(reloaded.customIds(), ",") == savedIds,
  "SHOW FOLLOWER duplicated or reordered saved identities")

-- Yellow reserves slot one for the exact authored partner. Five healthy
-- extras may follow, but the partner is never duplicated by PARTY/CUSTOM.
edition = "yellow"
local partner = party[4]
local yellowSelection = factory("follower_selection.lua")({
  gameVersion = gameVersion, config = reloaded,
  yellowPartner = { partner = function() return partner end },
})
rows = yellowSelection.activeMany(game, 6)
assert(#rows == 6 and rows[1].mon == partner,
  "Yellow's authored partner did not own follower slot one")
local seen = {}
for index, row in ipairs(rows) do
  assert(not seen[row.mon], "Yellow duplicated a party member at follower " .. index)
  seen[row.mon] = true
end

-- Main option schema must expose the two new values; otherwise save-local six
-- would be silently lowered again through the public options UI.
local handle = assert(io.open(root .. "/main.lua", "rb"))
local main = handle:read("*a")
handle:close()
assert(main:find('{ "5", 5 }', 1, true) and main:find('{ "6", 6 }', 1, true),
  "Follower Count option does not expose five and six")

print("PASS follower cap 6: migration custom Yellow slot ownership options")
