-- Exact 0.1.96/0.1.98 + imported R/B/Y cache regression for the Mt. Moon
-- fossil Super Nerd. Run once per extracted official engine root.

local engineRoot = assert(os.getenv("KA_ENGINE_ROOT"),
  "KA_ENGINE_ROOT is required")
local cacheRoot = assert(os.getenv("KA_ENGINE_CACHE_ROOT"),
  "KA_ENGINE_CACHE_ROOT is required")
local modRoot = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
local germanDialoguePath = assert(os.getenv("KA_GERMAN_DIALOGUE"),
  "KA_GERMAN_DIALOGUE is required")

local Version = assert(loadfile(engineRoot .. "/src/core/Version.lua"))()
assert(Version.engine == expectedEngine,
  "wrong exact engine: " .. tostring(Version.engine))
local GameVersion = assert(loadfile(engineRoot
  .. "/src/core/GameVersion.lua"))()
local makeRepair = assert(loadfile(modRoot
  .. "/yellow_mtmoon_fossil_dialogue.lua"))()
local germanDialogue = assert(loadfile(germanDialoguePath))()
local storyHandle = assert(io.open(engineRoot .. "/data/scripts/story2.lua", "rb"))
local storySource = assert(storyHandle:read("*a"))
storyHandle:close()
assert(storySource:find("local nerd = ow:npcByIndex(1)", 1, true),
  "exact story2 no longer identifies the fossil Super Nerd as object 1")
assert(storySource:find("return not nerd or ow:trainerDefeated(nerd)", 1, true),
  "exact story2 no longer gates fossil choice through trainerDefeated")

local FALLBACK = "I like shorts!\nThey're comfy and\neasy to wear!"
local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local function loadGenerated(edition, name)
  local path = cacheRoot .. "/" .. edition .. "/data/generated/"
    .. name .. ".lua"
  return assert(loadfile(path), path)()
end

local function copied(tableValue)
  local out = {}
  for key, value in pairs(tableValue or {}) do out[key] = value end
  return out
end

local function resolvedBattle(game, object)
  local map = game.data.maps.MT_MOON_B2F
  local header = game.data.trainer_headers[map.label][object.index]
  local text = header and header.battle and game.data.text[header.battle]
  if text then return text, "header" end
  local entry = game.data.text_pointers[map.label][object.text]
  if entry and entry.text and game.data.text[entry.text] then
    return game.data.text[entry.text], "pointer"
  end
  if entry and entry.label and game.data.text["_" .. entry.label] then
    return game.data.text["_" .. entry.label], "label"
  end
  return FALLBACK, "fallback"
end

local function trainerDefeated(save, header, npcId)
  if save.defeatedTrainers[npcId] then return true end
  return header and header.event and save.flags[header.event] == true
end

for _, edition in ipairs({ "red", "blue", "yellow" }) do
  GameVersion.set(edition)
  local maps = loadGenerated(edition, "maps")
  local headers = loadGenerated(edition, "trainer_headers")
  local text = loadGenerated(edition, "text")
  local pointers = loadGenerated(edition, "text_pointers")
  local map = assert(maps.MT_MOON_B2F)
  local object = assert(map.objects[1])
  check(object.index == 1 and object.name == "MTMOONB2F_SUPER_NERD"
      and object.text == "TEXT_MTMOONB2F_SUPER_NERD"
      and object.trainerClass == "OPP_SUPER_NERD"
      and object.trainerParty == 2 and object.x == 12 and object.y == 8,
    edition .. " object 1 is not the fossil Super Nerd")
  local fossils = { map.objects[edition == "yellow" and 7 or 6],
    map.objects[edition == "yellow" and 8 or 7] }
  check(fossils[1].x == 12 and fossils[1].y == 6
      and fossils[2].x == 13 and fossils[2].y == 6,
    edition .. " fossil objects moved")

  local game = { data = {
    maps = maps, trainer_headers = headers, text = text,
    text_pointers = pointers,
  }, save = { flags = {}, defeatedTrainers = {} } }
  local headerTable = headers.MtMoonB2F
  local headerBefore = headerTable[1]
  local mapBefore = maps.MT_MOON_B2F
  local objectBefore = mapBefore.objects[1]
  local before, beforeSource = resolvedBattle(game, object)

  if edition == "yellow" then
    check(headerBefore == nil and before == FALLBACK
        and beforeSource == "fallback",
      "released Yellow path no longer reproduces the Shorts fallback")
  else
    check(headerBefore ~= nil and beforeSource == "header"
        and before:find("fossils", 1, true),
      edition .. " released path lacks its authored fossil line")
  end

  local changed, why = makeRepair({ gameVersion = GameVersion }).install(game)
  if edition ~= "yellow" then
    check(changed == false and why == "edition",
      edition .. " unexpectedly patched")
    check(headers.MtMoonB2F == headerTable
        and headers.MtMoonB2F[1] == headerBefore
        and maps.MT_MOON_B2F == mapBefore
        and maps.MT_MOON_B2F.objects[1] == objectBefore,
      edition .. " was not byte/identity preserving")
  else
    check(changed == true and why == "repaired", "Yellow was not repaired")
    local header = assert(headers.MtMoonB2F[1])
    check(header.battle == "_MtMoonB2FSuperNerdTheyreBothMineText"
        and header.won == "_MtMoonB2fSuperNerdEachTakeOneText"
        and header.after == "_MtMoonB2FSuperNerdTheresAPokemonLabText"
        and header.event == "EVENT_BEAT_MT_MOON_3_SUPER_NERD",
      "Yellow trainer result/after/event contract is incomplete")

    local battle, source = resolvedBattle(game, object)
    check(source == "header" and battle:find("fossils", 1, true)
        and not battle:find("shorts", 1, true),
      "English Yellow prebattle still uses the Shorts fallback")
    check(text[header.won]:find("No being greedy", 1, true)
        and text[header.after]:find("POKéMON", 1, true)
        and text[header.after]:find("LAB", 1, true),
      "English Yellow won/after text did not resolve")

    local localized = copied(text)
    localized[header.battle] = germanDialogue[header.battle]
    localized[header.won] = germanDialogue[header.won]
    localized[header.after] = germanDialogue[header.after]
    game.data.text = localized
    local germanBattle, germanSource = resolvedBattle(game, object)
    check(germanSource == "header" and germanBattle:find("Fossilien", 1, true)
        and not germanBattle:find("Shorts", 1, true)
        and not germanBattle:find("Brennesseln", 1, true),
      "German Yellow prebattle still resolves the Shorts translation")
    check(type(localized[header.won]) == "string"
        and type(localized[header.after]) == "string",
      "German Yellow won/after text did not resolve")

    -- This is the exact engine bookkeeping that unlocks the fossil choice:
    -- victory records both the object and header event, while story2's
    -- superNerdBeaten continues to call trainerDefeated. The shim changes no
    -- save flag until the actual battle reports a win.
    check(next(game.save.flags) == nil
        and next(game.save.defeatedTrainers) == nil,
      "install mutated save progression")
    local npcId = "MT_MOON_B2F_obj_1"
    -- Imported/older saves may carry only the ROM event. Restoring the header
    -- makes trainerDefeated recognize that state without a forced rematch.
    game.save.flags[header.event] = true
    check(trainerDefeated(game.save, header, npcId) == true,
      "event-only old save no longer recognizes the defeated Super Nerd")
    game.save.flags[header.event] = nil
    -- A fresh victory follows exact engageTrainer: object marker plus event.
    game.save.defeatedTrainers[npcId] = true
    game.save.flags[header.event] = true
    local defeated = trainerDefeated(game.save, header, npcId)
    check(defeated == true,
      "repaired victory no longer unlocks the fossil choice")
    check(maps.MT_MOON_B2F == mapBefore
        and maps.MT_MOON_B2F.objects[1] == objectBefore
        and fossils[1] == map.objects[7] and fossils[2] == map.objects[8],
      "Yellow map/Jessie-James/fossil objects changed")
  end
end

print(("yellow_mtmoon_fossil_dialogue_engine_test: PASS engine=%s (%d checks)")
  :format(expectedEngine, checks))
