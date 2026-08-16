-- Kanto Ascendant 5.0 ROM-free acquisition/data audit.
--
-- Run from the Gen1 Recomp checkout:
--   TRAINER_REMATCH_MOD_DIR=../kanto_ascendant \
--   POKEPORT_DATA_DIR=tests/fixture_data \
--   ./.tools/luajit-src/src/luajit \
--   ../kanto_ascendant/tests/reachability_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = T.fixtures.load()
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/kanto_ascendant"
local audit = assert(loadfile(modPath .. "/tools/reachability_audit.lua"))()

audit.seedFixture(Data)
local run = T.sdk.loadMod(modPath, { data = Data })
T.eq(#run.errors, 0, "Kanto Ascendant loads on the expanded ROM-free fixture")
local exports = assert(run.loader.exports.kanto_ascendant,
  "kanto_ascendant exports unavailable")

local extraData = {}
for _, filename in ipairs({ "grand_tour_data.lua" }) do
  local chunk = loadfile(modPath .. "/" .. filename)
  if chunk then extraData[filename] = chunk() end
end

local report = audit.audit(Data, exports, extraData)
print(audit.format(report))
if not report.ok then
  run.release()
  error("Kanto Ascendant 5.0 reachability audit failed", 0)
end

T.eq(report.reachableCount, 251,
  "every original Kanto/Johto Pokédex number has an acquisition path")
T.same(report.guestReachable, { "GOROCHU" },
  "Raichu's Gorochu evolution is reachable outside the native 251")
T.eq(#report.renewableJohtoItems, #report.requiredJohtoItems,
  "every consumed Johto evolution item becomes renewable")
run.release()
T.finish("reachability")
