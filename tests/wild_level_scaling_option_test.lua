package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

package.preload["src.ui.BagMenu"] = function()
  return { new = function() return { onChoose = function() end } end }
end

local values = { difficulty = "very_hard" }
local hooks, events = {}, {}
local mod = {
  options = { get = function(_, key) return values[key] end },
  hooks = { wrap = function(_, key, fn) hooks[key] = fn end },
  events = { on = function(_, key, fn) events[key] = fn end },
}

local difficulty = assert(loadfile(root .. "/difficulty.lua"))()(mod, {
  i18n = { text = function(en) return en end },
})

local game = { data = {}, save = { inventory = {} } }
events["game.ready"]({ game = game })

-- Missing/legacy/fresh state is deliberately OFF. Trainer difficulty keeps
-- its own curve, while the encounter returned by every upstream author stays
-- byte-for-byte at its authored level.
assert(difficulty.adjustLevel(20, "trainer", 0) == 23,
  "trainer difficulty must not depend on Wild scaling")
assert(difficulty.adjustLevel(20, "wild", 0) == 20,
  "missing Wild-scaling option must default to OFF")
local authored = { species = "RATTATA", level = 7, marker = "native" }
local off = hooks["encounter.species"](function(row) return row end,
  authored, { mapId = "ROUTE_1", terrain = "grass" })
assert(off.level == 7 and off.marker == "native",
  "OFF must preserve the upstream authored/native encounter")
assert(authored.level == 7, "OFF must not mutate the upstream encounter")

-- Explicit ON restores only the existing phased difficulty bonus. It does
-- not own species selection, encounter tables or the trainer curve.
values.wild_level_scaling = true
assert(difficulty.adjustLevel(20, "wild", 0) == 23,
  "ON must restore the existing fresh Very Hard Wild bonus")
local on = hooks["encounter.species"](function(row) return row end,
  authored, { mapId = "ROUTE_1", terrain = "grass" })
assert(on.species == "RATTATA" and on.level == 10 and on.marker == "native",
  "ON must change only the resolved level")
assert(authored.level == 7, "ON must clone before applying its bonus")

values.wild_level_scaling = false
values.difficulty = "extreme"
assert(difficulty.adjustLevel(98, "trainer", 8) == 100,
  "trainer cap remains active with Wild scaling OFF")
assert(difficulty.itemsAllowed({ kind = "trainer" }) == false,
  "Extreme's trainer item rule remains independent")

print("wild_level_scaling_option_test: PASS")
