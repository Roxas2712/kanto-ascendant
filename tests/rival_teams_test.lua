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
