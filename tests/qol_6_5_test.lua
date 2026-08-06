-- Small host-side checks for the 6.5-only option plumbing.  Engine-backed
-- renderer checks remain in the Modkit/launcher QA stages.

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end

local function read(path)
  local file = assert(io.open(path, "r"))
  local body = file:read("*a")
  file:close()
  return body
end

local main = read("main.lua")
local manifest = read("manifest.json")
for _, key in ipairs({
  "johto_level_bonus", "ascendant_useful_bag", "ascendant_quick_select",
  "ascendant_qol", "modern_storage_ui", "catch_destination",
  "pokedex_filter", "box_filter", "text_speed", "ride_control",
}) do
  ok(main:find('key = "' .. key .. '"', 1, true) ~= nil,
    "main options expose " .. key)
end
ok(manifest:find('"version": "6.5.0"', 1, true) ~= nil,
  "RC manifest reports 6.5.0")

local handlers = {}
local mod = {
  options = { get = function() return "fast" end },
  events = { on = function(_, name, fn) handlers[name] = fn end },
}
local install = assert(loadfile("text_speed.lua"))()
install(mod)
local game = { save = { options = {} } }
handlers["game.ready"]({ game = game })
ok(game.save.options.textSpeed == 1, "FAST preset maps to one-frame text speed")

print(("6.5 QOL PLUMBING PASS: %d assertions"):format(assertions))
