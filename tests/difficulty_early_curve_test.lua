package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

package.preload["src.ui.BagMenu"] = function()
  return { new = function() return { onChoose = function() end } end }
end

local values = { difficulty = "standard" }
local hooks, events = {}, {}
local mod = {
  options = { get = function(_, key) return values[key] end },
  hooks = { wrap = function(_, key, fn) hooks[key] = fn end },
  events = { on = function(_, key, fn) events[key] = fn end },
}

local difficulty = assert(loadfile(root .. "/difficulty.lua"))()(mod, {
  i18n = { text = function(en) return en end },
})

local badgeIds = {
  "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
  "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
}

local function gameAt(badges)
  local inventory = {}
  for index = 1, badges do inventory[badgeIds[index]] = true end
  return { data = {}, save = { inventory = inventory } }
end

local expected = {
  trainer = {
    standard = { 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    high = { 1, 1, 1, 2, 2, 2, 3, 3, 3 },
    hard = { 2, 2, 3, 3, 4, 4, 5, 5, 5 },
    very_hard = { 3, 4, 5, 6, 7, 8, 8, 8, 8 },
    extreme = { 4, 5, 6, 7, 8, 9, 10, 10, 10 },
  },
  wild = {
    standard = { 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    high = { 1, 1, 1, 1, 2, 2, 2, 2, 2 },
    hard = { 2, 2, 2, 2, 3, 3, 3, 3, 3 },
    very_hard = { 3, 3, 4, 4, 5, 5, 5, 5, 5 },
    extreme = { 4, 4, 5, 5, 6, 6, 7, 7, 7 },
  },
}

local order = { "standard", "high", "hard", "very_hard", "extreme" }
for _, kind in ipairs({ "trainer", "wild" }) do
  for badges = 0, 8 do
    local previous = -1
    for _, tier in ipairs(order) do
      values.difficulty = tier
      local adjusted = difficulty.adjustLevel(20, kind, badges)
      local bonus = adjusted - 20
      assert(bonus == expected[kind][tier][badges + 1],
        ("%s/%s/%d expected +%d, got +%d"):format(
          kind, tier, badges, expected[kind][tier][badges + 1], bonus))
      assert(bonus > previous,
        ("%s tiers not strictly ordered at %d badges: %s"):format(
          kind, badges, tier))
      previous = bonus
    end
  end
end

-- Runtime hooks must derive progress from ordinary badge receipts. At zero
-- badges the authored level-5 first rival remains demanding but feasible;
-- no trainer class, edition, or save-name exception is involved.
assert(type(events["game.ready"]) == "function", "difficulty did not bind game progress")
events["game.ready"]({ game = gameAt(0) })
for index, tier in ipairs(order) do
  values.difficulty = tier
  local party = hooks["trainer.party"](function(_, _, rows) return rows end,
    "OPP_RIVAL1", 1, { { species = "EEVEE", level = 5 } })
  assert(party[1].level == 4 + index,
    tier .. " first rival should be level " .. tostring(4 + index))
  local wild = hooks["encounter.species"](function(row) return row end,
    { species = "RATTATA", level = 5 }, { mapId = "ROUTE_1" })
  assert(wild.level == 4 + index,
    tier .. " opening wild should be level " .. tostring(4 + index))
end

-- Once normal campaign progress reaches the phase-in point, the historical
-- full offsets and their level-100 overflow/mastery input stay byte-for-byte
-- equivalent. Extreme's item policy is intentionally independent.
events["game.ready"]({ game = gameAt(8) })
values.difficulty = "extreme"
local level, overflow = difficulty.adjustLevel(98, "trainer", 8)
assert(level == 100 and overflow == 8,
  "late Extreme level cap/overflow changed")
assert(difficulty.itemsAllowed({ kind = "trainer" }) == false,
  "Extreme trainer item lock changed")
assert(difficulty.itemsAllowed({ kind = "wild" }) == true,
  "Extreme wild item policy changed")

print("difficulty_early_curve_test: PASS")
