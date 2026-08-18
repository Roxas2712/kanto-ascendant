local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local Y = assert(loadfile(root .. "/yellow_gym_move_fidelity.lua"))()

local cache = os.getenv("KA_ENGINE_CACHE_ROOT")
local fixture = os.getenv("KA_STORY_GYM_FIXTURE")
assert(cache or fixture,
  "KA_ENGINE_CACHE_ROOT or KA_STORY_GYM_FIXTURE is required")
local contract = fixture and assert(loadfile(fixture))() or nil
local trainers = cache
  and assert(loadfile(cache .. "/yellow/data/generated/trainers.lua"))()
  or assert(contract.trainers.yellow,
    "story Gym fixture is missing Yellow trainer rows")
local partyIndex = { OPP_GIOVANNI = 3 }
local count = 0
for class, expected in pairs(Y.moves) do
  local source = trainers[class].parties[partyIndex[class] or 1]
  local out = {}
  for index, row in ipairs(source) do
    out[index] = { species = row.species, level = row.level }
  end
  local applied
  out, applied = Y.apply(class, out)
  assert(applied and #out == #source, class .. " did not apply exactly")
  for index, moves in ipairs(expected) do
    assert(table.concat(out[index].moves, "/") == table.concat(moves, "/"),
      class .. " slot " .. index .. " move mismatch")
  end
  count = count + 1
end
assert(count == 8, "repair must own exactly eight story Gym classes")

local red = cache
  and assert(loadfile(cache .. "/red/data/generated/trainers.lua"))()
  or assert(contract.trainers.red,
    "story Gym fixture is missing Red trainer rows")
local untouched = red.OPP_BROCK.parties[1]
assert(Y.apply("OPP_YOUNGSTER", untouched) == untouched,
  "non-Gym trainer must remain untouched")
assert(untouched[1].moves == nil, "Red data must remain untouched")

print("yellow_gym_move_fidelity_test: PASS")
