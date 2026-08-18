local root = arg[1] or "."
local makeRepair = assert(loadfile(root
  .. "/yellow_mtmoon_fossil_dialogue.lua"))()

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local function contract()
  return {
    after = "_MtMoonB2FSuperNerdTheresAPokemonLabText",
    battle = "_MtMoonB2FSuperNerdTheyreBothMineText",
    event = "EVENT_BEAT_MT_MOON_3_SUPER_NERD",
    won = "_MtMoonB2fSuperNerdEachTakeOneText",
  }
end

local function objects(yellow)
  local rows = {
    { index = 1, name = "MTMOONB2F_SUPER_NERD",
      text = "TEXT_MTMOONB2F_SUPER_NERD",
      trainerClass = "OPP_SUPER_NERD", trainerParty = 2,
      x = 12, y = 8 },
  }
  if yellow then
    rows[#rows + 1] = { index = 2, name = "MTMOONB2F_JESSIE",
      text = "TEXT_MTMOONB2F_JESSIE", hidden = true, x = 9, y = 3 }
    rows[#rows + 1] = { index = 6, name = "MTMOONB2F_JAMES",
      text = "TEXT_MTMOONB2F_JAMES", hidden = true, x = 9, y = 4 }
  end
  rows[#rows + 1] = { index = yellow and 7 or 6,
    name = "MTMOONB2F_DOME_FOSSIL", x = 12, y = 6 }
  rows[#rows + 1] = { index = yellow and 8 or 7,
    name = "MTMOONB2F_HELIX_FOSSIL", x = 13, y = 6 }
  return rows
end

local function gameFor(edition, header)
  return {
    data = {
      maps = { MT_MOON_B2F = {
        label = "MtMoonB2F", objects = objects(edition == "yellow"),
      } },
      trainer_headers = { MtMoonB2F = header or {} },
      text = {
        _MtMoonB2FSuperNerdTheresAPokemonLabText = "after",
        _MtMoonB2FSuperNerdTheyreBothMineText = "battle",
        _MtMoonB2fSuperNerdEachTakeOneText = "won",
      },
      text_pointers = {},
    },
    save = { flags = {}, defeatedTrainers = {} },
  }
end

local function repairFor(edition)
  return makeRepair({
    gameVersion = { get = function() return edition end },
  })
end

-- Red and Blue already own an exact ROM-derived trainer header. The shim is
-- cold there and must preserve the original table and row identities.
for _, edition in ipairs({ "red", "blue" }) do
  local existing = contract()
  local game = gameFor(edition, { existing })
  local tableBefore = game.data.trainer_headers.MtMoonB2F
  local objectBefore = game.data.maps.MT_MOON_B2F.objects[1]
  local changed, why = repairFor(edition).install(game)
  check(changed == false and why == "edition", edition .. " was patched")
  check(game.data.trainer_headers.MtMoonB2F == tableBefore,
    edition .. " header table identity changed")
  check(game.data.trainer_headers.MtMoonB2F[1] == existing,
    edition .. " header row identity changed")
  check(game.data.maps.MT_MOON_B2F.objects[1] == objectBefore,
    edition .. " map object changed")
end

-- Exact Yellow shape: object 1 is the fossil Super Nerd, Jessie/James are
-- separate hidden objects 2/6, and the extracted header row is absent.
do
  local game = gameFor("yellow")
  local map = game.data.maps.MT_MOON_B2F
  local jessie, james = map.objects[2], map.objects[3]
  local flags = game.save.flags
  local changed, why = repairFor("yellow").install(game)
  check(changed == true and why == "repaired",
    "Yellow repair did not run: " .. tostring(why))
  local row = game.data.trainer_headers.MtMoonB2F[1]
  local expected = contract()
  for key, value in pairs(expected) do
    check(row[key] == value, "Yellow header " .. key .. " is wrong")
  end
  check(map.objects[2] == jessie and map.objects[3] == james,
    "Jessie/James objects changed")
  check(game.save.flags == flags and next(flags) == nil,
    "install changed fossil/story flags")
  check(repairFor("yellow").install(game) == false,
    "repeat install overwrote the repaired header")
end

-- Fail closed for another map shape, another NPC, or an upstream engine that
-- already supplies a header. Never guess around third-party map rewrites.
do
  local existing = contract()
  local game = gameFor("yellow", { existing })
  check(repairFor("yellow").install(game) == false,
    "existing upstream header was overwritten")
  check(game.data.trainer_headers.MtMoonB2F[1] == existing,
    "existing upstream row identity changed")

  game = gameFor("yellow")
  game.data.maps.MT_MOON_B2F.objects[1].name = "SOME_OTHER_NPC"
  local changed, why = repairFor("yellow").install(game)
  check(changed == false and why == "shape",
    "foreign Yellow map shape was patched")
  check(game.data.trainer_headers.MtMoonB2F[1] == nil,
    "foreign Yellow map gained a header")
end

do
  local handle = assert(io.open(root .. "/main.lua", "rb"))
  local source = assert(handle:read("*a"))
  handle:close()
  check(source:find('mod, "yellow_mtmoon_fossil_dialogue.lua"', 1, true)
      ~= nil,
    "main does not load the Yellow fossil-dialogue shim")
  check(source:find("yellowMtMoonFossilDialogue.install(game)", 1, true)
      ~= nil,
    "main does not install the Yellow fossil-dialogue shim")
end

print(("yellow_mtmoon_fossil_dialogue_test: PASS (%d checks)"):format(checks))
