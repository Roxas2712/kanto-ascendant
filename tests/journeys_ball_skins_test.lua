-- Headless bridge contract. The renderer-backed capture matrix lives in
-- journeys_ball_skins_visual_driver.lua and must run under real LÖVE.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
local AnimPlayer = require("src.battle.AnimPlayer")

if not (Data.pokemon and Data.pokemon.BULBASAUR) then Data:load() end
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/ka_rc11_integration"
local sdkOpts = { data = Data }
if modPath:sub(1, 1) == "/" then sdkOpts.root = "/" end
local run = T.sdk.loadMod(modPath, sdkOpts)
assert(run.mod and run.mod.state == "loaded", "Authority mod did not load")
assert(#(run.errors or {}) == 0, "Loader errors")

local skins = assert(run.loader.exports.kanto_ascendant.journeysBallSkins)
local expected = {
  POKE_BALL = "poke_ball", GREAT_BALL = "great_ball", ULTRA_BALL = "ultra_ball",
  MASTER_BALL = "master_ball", SAFARI_BALL = "safari_ball", FAST_BALL = "fast_ball",
  LEVEL_BALL = "level_ball", LURE_BALL = "lure_ball", HEAVY_BALL = "heavy_ball",
  LOVE_BALL = "love_ball", FRIEND_BALL = "friend_ball", MOON_BALL = "moon_ball",
}
for id, stem in pairs(expected) do
  assert(skins.BALLS[id] == stem, "missing Journeys mapping " .. id)
  assert(skins.pathFor(id):find("/assets/journeys_balls/" .. stem .. ".png", 1, true),
    "runtime path must use checked-in master " .. id)
end
assert(not skins.pathFor("MOON_BALL"):find("Downloads", 1, true),
  "runtime must never read Downloads")
assert(AnimPlayer._ascendantBallBridge and AnimPlayer._ascendantBallBridge.journeys,
  "Journeys raster bridge did not replace procedural modern bridge")
assert(skins.STATES.success == "closed_sheet_final_pose"
    and skins.STATES.full_box == "closed_sheet_final_pose",
  "success/full-box preserve the real engine closed-ball state")
assert(skins.STATES.toss == "closed_sheet_8_frame"
    and skins.STATES.shake == "closed_sheet_8_frame",
  "Journeys toss/shake must use the authored eight-frame masters")
local seen = {}
for elapsed = 0, 15 do
  seen[skins.frameFor("TOSS_ANIM", elapsed)] = true
end
local count = 0
for _ in pairs(seen) do count = count + 1 end
assert(count == 8, "Toss timing did not expose all eight authored frames")
assert(skins.frameFor("SHAKE_ANIM", 0) ~= skins.frameFor("SHAKE_ANIM", 9),
  "Shake timing is frozen on one Journeys frame")
assert(skins.UNWIRED_MASTERS.open_master,
  "open-master engine API gap must remain explicit")

run.release()
print("journeys_ball_skins_test: PASS (12 runtime mappings, no Downloads path)")
