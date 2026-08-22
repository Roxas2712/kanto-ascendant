-- Regression for field-rematch teams changing after a presentation option
-- refresh/reload. The roster seed must adopt the durable playthrough identity
-- before the first team is generated, not transition from active slot later.

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

package.preload["src.core.SaveData"] = function()
  return { activeSlot = function() return "slot1" end }
end

local Authority = assert(loadfile(modPath .. "/rematch_roster_authority.lua"))()
local Recruits = assert(loadfile(modPath .. "/trainer_recruits.lua"))()

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end

local data = { pokemon = {
  PIDGEY = { dex = 16, types = { "NORMAL", "FLYING" },
    evolutions = { { "LEVEL", "PIDGEOTTO", 18 } } },
  PIDGEOTTO = { dex = 17, types = { "NORMAL", "FLYING" },
    evolutions = { { "LEVEL", "PIDGEOT", 36 } } },
  PIDGEOT = { dex = 18, types = { "NORMAL", "FLYING" }, evolutions = {} },
} }

local function oldSave()
  return {
    version = "red", meta = {},
    player = { id = 1, name = "RED", rival = "BLUE" },
    modData = { kanto_ascendant = {
      legacy_journey = { cycle = 0, runId = "original" },
    } },
  }
end

local function storageFor(playthroughId)
  local storage = { calls = 0 }
  function storage:context(game)
    self.calls = self.calls + 1
    game.save.meta = game.save.meta or {}
    game.save.meta.playthroughId = game.save.meta.playthroughId
      or playthroughId
    return { gameVersion = game.save.version,
      playthroughId = game.save.meta.playthroughId }
  end
  return storage
end

local baseTeam = { { species = "PIDGEY", level = 100,
  moves = { "WING_ATTACK", "QUICK_ATTACK", "AGILITY", "MIRROR_MOVE" } } }

local presentations = {
  { character_sprite_style = "ascendant", pokemon_sprite_style = "ascendant" },
  { character_sprite_style = "crystal", pokemon_sprite_style = "ascendant" },
  { character_sprite_style = "crystal", pokemon_sprite_style = "original" },
}

local function fingerprint(game, storage, presentation)
  local owner = Authority.authority(game, {
    key = "ROUTE_8_obj_1", trainerClass = "OPP_LASS",
    rematchNumber = 1, edition = "red", storage = storage,
    presentation = presentation,
  })
  local team = Recruits.expand(data, baseTeam, "OPP_LASS",
    "ROUTE_8_obj_1", 0, 0, false, {
      seed = owner, rematchNumber = 1, deferCommit = true,
      originalStages = { [1] = 2 },
    })
  local rows = { owner }
  for index, slot in ipairs(team) do
    rows[#rows + 1] = table.concat({ tostring(index), slot.species,
      tostring(slot.level), table.concat(slot.moves or {}, ",") }, ":")
  end
  return table.concat(rows, "\n"), team
end

local game = { save = oldSave() }
local storage = storageFor("opaque-playthrough-6511")
local first, firstTeam = fingerprint(game, storage, presentations[1])
check(storage.calls >= 1,
  "first rematch did not resolve official playthrough storage")
storage:context(game)
for _, presentation in ipairs(presentations) do
  eq(fingerprint(game, storage, presentation), first,
    "presentation option changed complete rematch roster")
end

local reloaded = { save = oldSave() }
reloaded.save.meta.playthroughId = game.save.meta.playthroughId
local reloadedFingerprint, reloadedTeam = fingerprint(reloaded,
  storageFor("must-not-replace"), presentations[1])
eq(reloadedFingerprint, first, "reload changed complete rematch roster")
eq(reloadedTeam[1].species, firstTeam[1].species,
  "reload changed the evolved original species")
eq(reloadedTeam[1].species, "PIDGEOT",
  "level-100 Pidgey family did not retain its expected evolved species")

local source = assert(io.open(modPath .. "/main.lua", "rb")):read("*a")
check(source:find("storage = mod.storage", 1, true),
  "main does not pass official storage to rematch roster authority")
check(source:find("seed = rosterAuthority", 1, true),
  "main does not seed recruitment from stable roster authority")

print(("REMATCH OPTION INVARIANCE 6.5.11 PASS: %d checks"):format(checks))
