local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local function read(name)
  local file = assert(io.open(root .. "/" .. name, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

local function compact(body)
  return (body:gsub("%s+", " "))
end

local function has(body, needle, message)
  assert(body:find(needle, 1, true), message .. ": " .. needle)
end

local function lacks(body, needle, message)
  assert(not body:find(needle, 1, true), message .. ": " .. needle)
end

for _, name in ipairs({ "README.md", "FAQ.md" }) do
  local body = compact(read(name))
  lacks(body, "| Nugget | 15% | 15% |",
    name .. " still publishes the obsolete six-band loot table")
  lacks(body, "44% total item chance",
    name .. " still publishes the obsolete combined item chance")
  lacks(body, "Rematches give no prize money and Pay Day payouts are disabled",
    name .. " still says the engine's normal money paths are removed")

  has(body, "VERY SHORT | 151-302", name .. " lacks the pause profile table")
  has(body, "NORMAL | 605-1255", name .. " lacks the fresh-save default")
  has(body, "existing 151-2510", name .. " lacks migration disclosure")
  has(body, "historical 128-256", name .. " lacks legacy CUSTOM migration")
  has(body, "already scheduled", name .. " lacks future-only timer wording")

  has(body, "2.25%", name .. " lacks the field EXP Share probability")
  has(body, "1/300", name .. " lacks the field x2 probability")
  has(body, "1/250", name .. " lacks the field x3/x5 probability")
  has(body, "1/50", name .. " lacks the post-Hall-of-Fame Master Ball rate")
  has(body, "65% / 80%", name .. " lacks sub-level-100 item rates")
  has(body, "72% / 87%", name .. " lacks level-100 item rates")
  has(body, "120.5", name .. " lacks the audited ordinary-pool weight")
  has(body, "Thunder Tear", name .. " lacks the Gorochu loot exclusion")
  has(body, "OFF disables only", name .. " does not bound the OFF setting")
  has(body, "Bag -> PC -> pending",
    name .. " lacks the complete reward placement order")

  has(body, "Legacy Wanderers", name .. " lacks a distinct Wanderer section")
  has(body, "1/32", name .. " lacks the Wanderer Master Ball rate")
  has(body, "1/4", name .. " lacks the Wanderer EXP Share catch-up rate")
  has(body, "1/6", name .. " lacks the Wanderer x2 catch-up rate")
  has(body, "1/12", name .. " lacks the Wanderer x3 catch-up rate")
  has(body, "1/24", name .. " lacks the Wanderer x5 catch-up rate")
  has(body, "ordinary pool total is 89",
    name .. " lacks the audited Beyond-Kanto Wanderer pool")
end

print("PASS rematch reward documentation: field, OFF/catch-up, Wanderer")
