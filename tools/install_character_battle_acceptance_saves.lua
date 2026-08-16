-- Registers the generated character acceptance slots in another launcher
-- identity without touching that identity's existing slots or active slot.

return function()
  local SaveData = require("src.core.SaveData")
  local source = assert(os.getenv("CHARACTER_SAVE_SOURCE"),
    "CHARACTER_SAVE_SOURCE is required")
  local rows = {
    { "slot6501", "01 START RED" },
    { "slot6502", "02 START BLUE" },
    { "slot6503", "03 START CASEY" },
    { "slot6511", "11 BATTLES BLUE" },
    { "slot6512", "12 BATTLES CASEY" },
    { "slot6513", "13 BATTLES RED" },
  }
  local active = SaveData.activeSlot("red")
  for _, row in ipairs(rows) do
    local path = source .. "/" .. row[1] .. ".lua"
    local handle = assert(io.open(path, "rb"), "missing source " .. path)
    local save = assert(SaveData.decode(handle:read("*a")))
    handle:close()
    assert(SaveData.setActiveSlot("red", row[1]) == row[1])
    assert(SaveData.writeSlot("red", row[1], save))
    assert(SaveData.renameSlot("red", row[1], row[2]))
  end
  if active then SaveData.setActiveSlot("red", active) end

  local byId = {}
  for _, row in ipairs(SaveData.listSlots("red")) do byId[row.id] = row end
  for _, expected in ipairs(rows) do
    local actual = assert(byId[expected[1]], "slot not registered")
    assert(actual.exists and actual.label == expected[2],
      "installed slot mismatch for " .. expected[1])
  end
  print("CHARACTER BATTLE SAVES INSTALLED slots=6 existing-preserved=true")
  love.event.quit(0)
end
