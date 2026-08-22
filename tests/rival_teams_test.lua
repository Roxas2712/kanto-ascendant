-- Identity-specific rival team contract.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/kanto_ascendant"
local run = T.sdk.loadMod(modPath, { data = Data })
T.eq(#run.errors, 0, "Kanto Ascendant loads with rival teams")

local exports = assert(run.loader.exports.kanto_ascendant)
local characters = assert(exports.extendedCharacters)
local teams = assert(exports.rivalTeams)
local vanilla = {
  { species = "PIDGEOT", level = 61 },
  { species = "ALAKAZAM", level = 59 },
  { species = "RHYDON", level = 61 },
  { species = "ARCANINE", level = 61 },
  { species = "EXEGGUTOR", level = 63 },
  { species = "BLASTOISE", level = 65 },
}

T.eq(teams.resolve("BLUE", "OPP_RIVAL3", 1, vanilla), vanilla,
  "Blue keeps the exact vanilla team table")

local red = teams.resolve("RED", "OPP_RIVAL3", 3, vanilla)
local redExpected = {
  "PIKACHU:81", "ESPEON:73", "SNORLAX:75",
  "VENUSAUR:77", "CHARIZARD:77", "BLASTOISE:77",
}
local redActual = {}
for _, row in ipairs(red) do
  redActual[#redActual + 1] = row.species .. ":" .. row.level
end
T.eq(table.concat(redActual, ","), table.concat(redExpected, ","),
  "Red final team matches the Mt. Silver Gold/Crystal roster")
T.eq(table.concat(red[1].moves, ","),
  "CHARM,QUICK_ATTACK,THUNDERBOLT,THUNDER",
  "Red Pikachu retains its authored Crystal moves")

local function roster(rows)
  local out = {}
  for _, row in ipairs(rows) do
    out[#out + 1] = row.species .. ":" .. row.level
  end
  return table.concat(out, ",")
end

-- Yellow's RIVAL2 index expresses Eevee's outcome, not a Kanto starter
-- branch. All three Tower variants must advance together and retain the
-- Squirtle line established on the S.S. Anne.
local yellowAnne = teams.resolve("RED", "OPP_RIVAL2", 1, vanilla, true)
T.eq(roster(yellowAnne),
  "PIKACHU:19,RATICATE:16,EEVEE:18,WARTORTLE:20",
  "Yellow Red establishes Wartortle on the S.S. Anne")
for index = 2, 4 do
  local tower = teams.resolve("RED", "OPP_RIVAL2", index, vanilla, true)
  T.eq(roster(tower), "PIKACHU:25,EEVEE:23,SNORLAX:22,WARTORTLE:25",
    "Yellow Tower variant " .. index
      .. " advances levels and retains Wartortle")
end
for index = 5, 7 do
  local silph = teams.resolve("RED", "OPP_RIVAL2", index, vanilla, true)
  T.eq(roster(silph), "PIKACHU:37,ESPEON:35,SNORLAX:38,BLASTOISE:40",
    "Yellow Silph variant " .. index .. " reaches the third story tier")
end
for index = 8, 10 do
  local route = teams.resolve("RED", "OPP_RIVAL2", index, vanilla, true)
  T.eq(#route, 6, "Yellow late Route 22 variant " .. index
    .. " reaches Red's complete pre-Champion team")
  T.eq(route[6].species, "BLASTOISE",
    "Yellow late Route 22 variant " .. index
      .. " keeps the established Squirtle line")
end
T.eq(roster(teams.resolve("RED", "OPP_RIVAL1", 2, vanilla, true)),
  "PIKACHU:9,SQUIRTLE:8",
  "Yellow first Route 22 battle uses Red's second progression tier")
T.eq(roster(teams.resolve("RED", "OPP_RIVAL1", 3, vanilla, true)),
  "PIKACHU:18,EEVEE:15,RATTATA:15,WARTORTLE:17",
  "Yellow Cerulean battle uses Red's third progression tier")

local Music = require("src.core.Music")
local oldPlayMap, restored = Music.playMap, nil
Music.playMap = function(_, mapId, onBike, surfing)
  restored = { mapId = mapId, onBike = onBike, surfing = surfing }
end
local restoredTower = teams.restoreTowerMusic({
  result = "win",
  battle = {
    oppClass = "OPP_RIVAL2",
    game = {
      data = Data,
      save = { onBike = false, player = { map = "POKEMON_TOWER_2F" } },
      overworld = {
        map = { id = "POKEMON_TOWER_2F" },
        player = { surfing = false },
      },
    },
  },
})
Music.playMap = oldPlayMap
T.eq(restoredTower, true,
  "Tower rival victory explicitly restores the authored room music")
T.eq(restored and restored.mapId, "POKEMON_TOWER_2F",
  "Tower music restoration targets only the active room")
T.eq(teams.restoreTowerMusic({
  result = "win",
  battle = {
    oppClass = "OPP_RIVAL2",
    game = { save = { player = { map = "SILPH_CO_7F" } } },
  },
}), false, "unrelated rival battles do not touch map music")

local GameVersion = require("src.core.GameVersion")
local previousVersion = GameVersion.get()
GameVersion.set("yellow")
characters.select("GREEN") -- GREEN's matrix rival is RED.
local yellowThroughHook = run.loader.hooks:call("trainer.party",
  function(_, _, party) return party end, "OPP_RIVAL2", 2, vanilla)
GameVersion.set(previousVersion)
T.eq(roster(yellowThroughHook),
  "PIKACHU:25,EEVEE:23,SNORLAX:22,WARTORTLE:25",
  "live trainer hook applies Yellow's Tower tier and Wartortle continuity")
local green1 = teams.resolve("GREEN", "OPP_RIVAL3", 1, vanilla)
local green2 = teams.resolve("GREEN", "OPP_RIVAL3", 2, vanilla)
local green3 = teams.resolve("GREEN", "OPP_RIVAL3", 3, vanilla)
T.eq(#green1, 6, "Green final team has six members")
T.eq(green1[1].species, "WIGGLYTUFF", "Green keeps Jiggly's evolution")
T.eq(green1[2].species, "NIDOQUEEN", "Green keeps her Nidoqueen")
T.eq(green1[3].species, "CLEFABLE", "Green keeps her Clefable")
T.eq(green1[4].species, "GRANBULL", "Green gains her Gen-II Granbull")
T.eq(green1[5].species, "DITTO", "Green keeps her Ditto")
T.eq(green1[6].species, "BLASTOISE", "water branch retains Blastoise")
T.eq(green2[6].species, "VENUSAUR", "grass branch retains Venusaur")
T.eq(green3[6].species, "CHARIZARD", "fire branch retains Charizard")

characters.select("GREEN")
local throughHook = run.loader.hooks:call("trainer.party",
  function(_, _, party) return party end, "OPP_RIVAL3", 3, vanilla)
T.eq(throughHook[1].species, "PIKACHU",
  "Green player resolves Red through the live trainer hook")
characters.select("RED")
local blueThroughHook = run.loader.hooks:call("trainer.party",
  function(_, _, party) return party end, "OPP_RIVAL3", 1, vanilla)
local blueExpected, blueActual = {}, {}
for _, row in ipairs(vanilla) do
  blueExpected[#blueExpected + 1] = row.species .. ":" .. row.level
end
for _, row in ipairs(blueThroughHook) do
  blueActual[#blueActual + 1] = row.species .. ":" .. row.level
end
T.eq(table.concat(blueActual, ","), table.concat(blueExpected, ","),
  "Red player keeps Blue's exact vanilla roster through difficulty cloning")
T.eq(vanilla[1].level, 61,
  "the combined trainer hook never mutates Blue's source roster")

T.finish()
