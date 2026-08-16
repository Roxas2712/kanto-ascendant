-- Static contract for the one-time first-Hall Oak bridge.  PC eligibility,
-- no-reset semantics and post-Hall repetition are exercised by
-- legacy_journey_test.lua; this test keeps the composed Champion payload
-- from silently losing the orientation page in either language/branch.

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end

local dialogue = assert(loadfile("postgame_dialogue.lua"))()
for _, key in ipairs({ "oakLegendEvent", "oakNoLegendEvent" }) do
  local row = assert(dialogue.story[key], key .. " missing")
  ok(row.en:find("HALL OF FAME", 1, true) ~= nil
      and row.en:find("LAB PC", 1, true) ~= nil
      and row.en:find("LEGACY", 1, true) ~= nil
      and row.en:find("fissure path", 1, true) ~= nil
      and row.en:find("black door", 1, true) ~= nil
      and row.en:find("HALL alone never", 1, true) ~= nil
      and row.en:find("Nothing resets", 1, true) ~= nil,
    key .. " English bridge says HOF alone cannot unlock Legacy")
  ok(row.de:find("RUHMESHALLE", 1, true) ~= nil
      and row.de:find("LABOR-PC", 1, true) ~= nil
      and row.de:find("VERMÄCHTNIS", 1, true) ~= nil
      and row.de:find("Risspfad", 1, true) ~= nil
      and row.de:find("schwarzen Tür", 1, true) ~= nil
      and row.de:find("allein öffnet keinen", 1, true) ~= nil
      and row.de:find("Nichts setzt", 1, true) ~= nil,
    key .. " German bridge says HOF alone cannot unlock Legacy")
end

print(("LEGACY STORY GATE PASS: %d assertions"):format(assertions))
