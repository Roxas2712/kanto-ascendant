-- 6.7 contract: Johto Masters questions and handoffs must describe the
-- evolution, reset and reward mechanics the live controllers actually own.

local source = debug.getinfo(1, "S").source:sub(2)
local root = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or source:match("^(.*)/tests/") or "."

local function read(path)
  local file = assert(io.open(root .. "/" .. path, "rb"))
  local value = assert(file:read("*a")); file:close(); return value
end
local function equal(actual, expected, message)
  assert(actual == expected, (message .. ": expected %s, got %s")
    :format(tostring(expected), tostring(actual)))
end

local johto = assert(loadfile(root .. "/johto_data.lua"))()
local saved = {
  activeRun = true, runSerial = 1, challengeAttempt = 0,
  passages = {
    silver = { status = "cleared", quizVersion = 3,
      quizRunSerial = 1, quizAttempt = 0, quizSolved = {} },
    kris = { status = "entered", step = 2, quizVersion = 3,
      quizRunSerial = 1, quizAttempt = 0, quizSolved = { true, true } },
    gold = { status = "locked", quizVersion = 3,
      quizRunSerial = 1, quizAttempt = 0, quizSolved = {} },
  },
}
local persists = 0
local baseline = {
  state = function() return saved end,
  persist = function() persists = persists + 1; return true end,
}
local tileBridge = {
  ids = {
    radio_tower = "RADIO", ruins_of_alph = "RUINS", tower = "TOWER",
    champions_room = "CHAMPION", silver_signal_v9 = "SILVER",
    kris_archive_v9 = "KRIS",
  },
  layout = function(id) return id end,
  register = function() end,
}
local mod = {
  save = { set = function(_, _, value) saved = value end },
  world = {},
}
local passages = assert(loadfile(root .. "/johto_masters_passages.lua"))()(
  mod, {
    baseline = baseline,
    postgame = {},
    tilesetFactory = function() return tileBridge end,
  })

local questions = {}
for _, bank in pairs(passages.questionBanks) do
  for _, question in ipairs(bank) do questions[question.id] = question end
end
local itemLabels = {
  METAL_COAT = "METAL COAT", KINGS_ROCK = "KING'S ROCK",
  UPGRADE = "UP-GRADE",
}
local expected = {
  S_STEELIX = { parent = "ONIX", target = "STEELIX" },
  K_SCIZOR = { parent = "SCYTHER", target = "SCIZOR" },
  K_PORYGON2 = { parent = "PORYGON", target = "PORYGON2" },
  K_POLITOED = { parent = "POLIWHIRL", target = "POLITOED" },
  K_SLOWKING = { parent = "SLOWPOKE", target = "SLOWKING" },
}
for id, contract in pairs(expected) do
  local rule
  for _, candidate in ipairs(johto.kantoEvolutions[contract.parent]) do
    if candidate[2] == contract.target then rule = candidate; break end
  end
  assert(rule and rule[1] == "ITEM", id .. " has no direct-item authority")
  equal(questions[id].answers[1].en, itemLabels[rule[3]],
    id .. " answer drifted from johto_data authority")
end
equal(questions.S_GENGAR.answers[1].en, "LEVEL 42",
  "Haunter quiz answer drifted from Kanto completion authority")
assert(read("kanto_completion.lua"):find(
  'HAUNTER = { species = "GENGAR", level = 42 }', 1, true),
  "Kanto completion no longer owns the tested level-42 Gengar rule")

local reset, receipt = passages.onMapTransition({},
  "KA_JOHTO_GATE_HALL", "INDIGO_PLATEAU_LOBBY")
assert(reset and receipt.reason == "area_exit",
  "leaving the Gate Hall did not execute the advertised area-exit reset")
equal(saved.passages.silver.status, "unlocked",
  "Hall exit retained a completed Silver path")
equal(saved.passages.kris.step, 0,
  "Hall exit retained partial Kris progress")
equal(persists, 1, "Hall exit reset was not persisted exactly once")

local copy = read("johto_masters_passages.lua")
assert(copy:find("shiny Johto\\npartner after defeating GOLD", 1, true),
  "host does not tie the one shiny reward to defeating Gold")
assert(not copy:find("partner after each clear", 1, true),
  "host still promises a shiny after every path clear")

print("johto_masters_dialogue_authority_67_test: PASS")
