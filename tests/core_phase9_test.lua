package.path = "./?.lua;./?/init.lua;" .. package.path
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local count = 0
local function ok(value, message) count = count + 1; assert(value, message) end
local function eq(a, b, message)
  count = count + 1
  assert(a == b, (message or "different") .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

local values = { difficulty = "standard", rare_item_lock = true,
  vision_encounters = true }
local hooks, events, saves = {}, {}, {}
local fake = {
  options = { get = function(_, key) return values[key] end },
  hooks = { wrap = function(_, key, fn) hooks[key] = fn end },
  events = { on = function(_, key, fn) events[key] = fn end },
  save = {
    get = function(_, key) return saves[key] end,
    set = function(_, key, value) saves[key] = value end,
  },
}
local i18n = { text = function(en) return en end }
local difficulty = assert(loadfile(modDir .. "/difficulty.lua"))()(fake, { i18n = i18n })
for name, expected in pairs({ standard = {0,0}, high = {3,2}, hard = {5,3},
    very_hard = {8,5}, extreme = {10,7} }) do
  values.difficulty = name
  local trainer = difficulty.adjustLevel(50, "trainer")
  local wild = difficulty.adjustLevel(50, "wild")
  eq(trainer, 50 + expected[1], name .. " trainer offset")
  eq(wild, 50 + expected[2], name .. " wild offset")
end
values.difficulty = "extreme"
local level, overflow = difficulty.adjustLevel(98, "trainer")
eq(level, 100, "trainer level has an absolute 100 cap")
eq(overflow, 8, "excess strength is retained for mastery conversion")
eq(difficulty.itemsAllowed({ kind = "trainer" }), false,
  "Extreme blocks trainer battle items")
eq(difficulty.itemsAllowed({ kind = "wild" }), true,
  "Extreme still permits wild battle balls/items")

local protection = assert(loadfile(modDir .. "/item_protection.lua"))()(fake,
  { i18n = i18n })
eq(protection.isProtected("MASTER_BALL"), true, "Master Ball is protected")
eq(protection.isProtected("POKE_BALL"), false, "ordinary balls remain direct")
values.rare_item_lock = false
eq(protection.isProtected("MASTER_BALL"), false, "lock is optional")

local vision = assert(loadfile(modDir .. "/vision_encounters.lua"))()(fake,
  { i18n = i18n })
values.vision_encounters = true
eq(saves.vision_encounters, nil, "vision state remains lazy before first use")
eq(vision.eligible(vision.DEFS[1], "ROUTE_2", 0.009), true,
  "Ho-Oh vision can occur by Viridian Forest")
eq(saves.vision_encounters.version, 2,
  "vision state is explicitly versioned for old-save migration")
eq(vision.eligible(vision.DEFS[1], "ROUTE_2", 0.02), false,
  "Ho-Oh chance is one percent")
eq(vision.eligible(vision.DEFS[1], "VIRIDIAN_FOREST", 0), false,
  "Ho-Oh vision never starts inside Viridian Forest")
eq(vision.eligible(vision.DEFS[1], "VIRIDIAN_FOREST_SOUTH_GATE", 0), false,
  "Ho-Oh vision never starts in the forest gate")
saves.vision_encounters.ho_oh = true
eq(vision.eligible(vision.DEFS[1], "ROUTE_2", 0), false,
  "vision flag enforces once-per-save")
eq(#vision.DEFS, 1, "Lugia has no separate vision encounter")
eq(saves.vision_encounters.lugia, nil,
  "old Lugia vision flags are removed during migration")

local function source(name)
  local file = assert(io.open(modDir .. "/" .. name, "rb"))
  local text = file:read("*a"); file:close(); return text
end
local main = source("main.lua")
ok(main:find('key = "kanto_151"', 1, true), "Kanto 151 remains in the real schema")
ok(main:find('dex > 251 and name', 1, true), "guest Dex Crystal art is generic")
local prisms = source("driftglass_prisms.lua")
ok(prisms:find('name = "PRISM_EXIT_ARCH"', 1, true),
  "Prism return is a visible map object")
local bike = source("bicycle_select.lua")
ok(bike:find('queue[index] == "select"', 1, true),
  "bicycle shortcut consumes the logical remappable SELECT action")
ok(bike:find('top == game.overworld', 1, true),
  "bicycle shortcut cannot steal menu SELECT")

print(("PHASE 9 CORE TEST PASS: %d assertions"):format(count))
