local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local cache = assert(os.getenv("KA_ENGINE_CACHE_ROOT"),
  "KA_ENGINE_CACHE_ROOT is required")
local trainers = assert(loadfile(cache .. "/red/data/generated/trainers.lua"))()

local function run(boundaryActive, receiverRepaired, rules, available)
  local hooks, events = {}, {}
  local mod = {
    options = { get = function(_, key)
      return key == "difficulty" and "very_hard" or nil
    end },
    hooks = { wrap = function(_, key, fn) hooks[key] = fn end },
    events = { on = function(_, key, fn)
      events[key] = events[key] or {}; events[key][#events[key] + 1] = fn
    end },
  }
  local story = assert(loadfile(root .. "/story_gym_difficulty.lua"))()(mod, {
    gameVersion = { get = function() return "red" end },
    yellowFidelity = assert(loadfile(root .. "/yellow_gym_move_fidelity.lua"))(),
    -- This is the exact injected production contract: activating/copying the
    -- Beyond boundary alone is insufficient; the save must also contain the
    -- repaired Driftglass receiver milestone.
    johtoUnlocked = function()
      return boundaryActive == true and receiverRepaired == true
    end,
    resonanceRules = rules,
  })
  local game = {
    data = { moves = available }, save = { inventory = {}, hallOfFame = {} },
    overworld = { map = { id = "PEWTER_GYM" } },
  }
  for _, fn in ipairs(events["game.ready"] or {}) do fn({ game = game }) end
  local out = hooks["trainer.party"](function(_, _, rows) return rows end,
    "OPP_BROCK", 1, trainers.OPP_BROCK.parties[1])
  return out, story
end

local rules = {
  ONIX = { IRON_TAIL = { move = "IRON_TAIL", source = "machine" } },
  SANDSHREW = {
    METAL_CLAW = { move = "METAL_CLAW", source = "inherited" },
  },
}
local available = { IRON_TAIL = {}, METAL_CLAW = {} }
local sealed = run(false, false, rules, available)
assert(sealed[#sealed].moves[4] == "BIDE", "sealed Kanto leaked Johto move")
local activeUnrepaired = run(true, false, rules, available)
assert(activeUnrepaired[#activeUnrepaired].moves[4] == "BIDE",
  "active-but-unrepaired save leaked Johto move")
local repairedWithoutBoundary = run(false, true, rules, available)
assert(repairedWithoutBoundary[#repairedWithoutBoundary].moves[4] == "BIDE",
  "receiver milestone without authoritative boundary leaked Johto move")
local open, story = run(true, true, rules, available)
assert(open[#open].moves[4] == "IRON_TAIL", "active boundary missed legal TM")
assert(open[2].species == "SANDSHREW" and open[2].moves[4] == "METAL_CLAW",
  "active boundary missed legal inherited move")
assert(story.johtoPreferred.ONIX[1] == "IRON_TAIL",
  "published Johto preference catalogue missing")
local absent = run(true, true, rules, {})
assert(absent[#absent].moves[4] == "BIDE", "missing move data did not fail closed")
local malformed = run(true, true, { ONIX = { IRON_TAIL = true } }, available)
assert(malformed[#malformed].moves[4] == "BIDE", "malformed rule did not fail closed")
local missingRule = run(true, true, {}, available)
assert(missingRule[#missingRule].moves[4] == "BIDE",
  "missing resonance rule did not fail closed")

-- Exhaust every curated preference against the real Driftglass catalogue,
-- rather than accepting a second hand-maintained legality list in this test.
local prismModule = assert(loadfile(root .. "/driftglass_prisms.lua"))()
local prism = prismModule.create({ content = {} }, {
  state = { section = function() return {} end }, content = {},
})
local checked, illegal = 0, {}
for species, candidates in pairs(story.johtoPreferred) do
  local speciesRules = prism.resonanceRules[species] or {}
  for _, move in ipairs(candidates) do
    local rule = speciesRules[move]
    if not (type(rule) == "table" and rule.move == move
        and (rule.source == "machine" or rule.source == "inherited"
          or rule.source == "level")) then
      illegal[#illegal + 1] = species .. "/" .. move
    end
    checked = checked + 1
  end
end
assert(#illegal == 0,
  "illegal Johto Gym preferences:\n" .. table.concat(illegal, "\n"))
assert(checked >= 50, "Johto preference oracle did not cover the full catalogue")

print(("story_gym_johto_moves_test: PASS (resonance preferences=%d)")
  :format(checked))
