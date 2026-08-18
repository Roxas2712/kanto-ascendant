-- Exhaustive Gen-I legality oracle for every authored Story-Gym row/tier.

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local cache = assert(os.getenv("KA_ENGINE_CACHE_ROOT"),
  "KA_ENGINE_CACHE_ROOT is required")

local values = { difficulty = "standard" }
local mod = {
  options = { get = function(_, key) return values[key] end },
  hooks = { wrap = function() end }, events = { on = function() end },
}
local story = assert(loadfile(root .. "/story_gym_difficulty.lua"))()(mod, {
  gameVersion = { get = function() return "red" end },
  yellowFidelity = assert(loadfile(root .. "/yellow_gym_move_fidelity.lua"))(),
})

local classes = {
  "OPP_BROCK", "OPP_MISTY", "OPP_LT_SURGE", "OPP_ERIKA",
  "OPP_KOGA", "OPP_SABRINA", "OPP_BLAINE", "OPP_GIOVANNI",
}
local tiers = { "high", "hard", "very_hard", "extreme" }
local retained = {}
local illegal = {}

for _, edition in ipairs({ "red", "blue", "yellow" }) do
  local pokemon = assert(loadfile(cache .. "/" .. edition
    .. "/data/generated/pokemon.lua"))()
  local moves = assert(loadfile(cache .. "/" .. edition
    .. "/data/generated/moves.lua"))()
  local trainers = assert(loadfile(cache .. "/" .. edition
    .. "/data/generated/trainers.lua"))()
  local parent = {}
  for species, def in pairs(pokemon) do
    for _, evolution in ipairs(def.evolutions or {}) do
      if evolution.species then parent[evolution.species] = species end
    end
  end

  local function sourceFor(species, level, move)
    local direct = true
    while species do
      local def = assert(pokemon[species], "missing species " .. species)
      for _, id in ipairs(def.level1Moves or {}) do
        if id == move then return direct and "level1" or "retained:" .. species end
      end
      for _, row in ipairs(def.learnset or {}) do
        if row.move == move and tonumber(row.level) <= tonumber(level) then
          return direct and "level" or "retained:" .. species
        end
      end
      for _, id in ipairs(def.tmhm or {}) do
        if id == move then return direct and "tmhm" or "retained-tm:" .. species end
      end
      species, direct = parent[species], false
    end
    return nil
  end

  for _, class in ipairs(classes) do
    local index = class == "OPP_GIOVANNI" and 3 or 1
    local source = trainers[class].parties[index]
    for _, tier in ipairs(tiers) do
      local party = story.plan(edition, tier, class, source)
      assert(#party <= 6, edition .. "/" .. class .. "/" .. tier .. " >6")
      for slot, mon in ipairs(party) do
        assert(pokemon[mon.species], "non-Gen-I species " .. tostring(mon.species))
        assert(type(mon.moves) == "table" and #mon.moves > 0 and #mon.moves <= 4,
          "invalid move count")
        for _, move in ipairs(mon.moves) do
          assert(moves[move], edition .. " missing move definition " .. move)
          local why = sourceFor(mon.species, mon.level, move)
          if not why then
            illegal[#illegal + 1] = table.concat({ edition, class, tier,
              "slot" .. slot, mon.species .. "@" .. mon.level, move }, "/")
          elseif why:match("^retained") then
            retained[mon.species .. ":" .. move .. ":" .. why] = true
          end
        end
      end
    end
  end
end

local retainedCount = 0
for _ in pairs(retained) do retainedCount = retainedCount + 1 end
assert(#illegal == 0, "illegal Story-Gym moves:\n" .. table.concat(illegal, "\n"))
assert(retainedCount > 0,
  "oracle must exercise documented retained pre-evolution move legality")

print(("story_gym_move_legality_test: PASS (retained=%d)"):format(retainedCount))
