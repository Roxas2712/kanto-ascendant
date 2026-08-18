-- Focused full-loader contract for the Red/Green/Blue Crystal walkers on the
-- exact public 0.1.96 and 0.1.98 engine trees. Run once per edition cache.

local support = assert(os.getenv("KA_ENGINE_SUPPORT_ROOT"),
  "KA_ENGINE_SUPPORT_ROOT is required")
package.path = "./?.lua;./?/init.lua;" .. support .. "/?.lua;"
  .. support .. "/?/init.lua;" .. package.path

local T = require("tests.modkit")
local Version = require("src.core.Version")
local GameVersion = require("src.core.GameVersion")
local Data = require("src.core.Data")

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
local edition = assert(os.getenv("KA_EXPECT_EDITION"),
  "KA_EXPECT_EDITION is required")
assert(Version.engine == expectedEngine, "wrong exact engine")
GameVersion.set(edition)
Data:load()

local run = T.sdk.loadMod(root, { data = Data, root = "/" })
assert(run.mod and #(run.errors or {}) == 0,
  "full candidate did not load cleanly on exact engine")
local exports = assert(run.loader.exports.kanto_ascendant)
local characters = assert(exports.extendedCharacters)
local resolver = assert(exports.crystalWalkAssets)

for _, identity in ipairs({ "RED", "GREEN", "BLUE" }) do
  local lower = identity:lower()
  local prefix = "SPRITE_KA_CRYSTAL_" .. identity .. "_"
  assert(characters.getCharacterSprite(identity, "overworld").sprite
      == prefix .. "WALK",
    identity .. " does not own its Crystal walking registration")
  local walk = assert(run.data.sprites[prefix .. "WALK"])
  assert(walk.image:find("/assets/characters/crystal_chars/"
      .. lower .. "_walk.png", 1, true),
    identity .. " did not register the approved primary")
  assert(walk.frames == 6 and walk.walker == true and walk.trueColor == true,
    identity .. " walking geometry or colour ownership changed")
  assert(walk.frameWidth == nil and walk.frameHeight == nil,
    identity .. " walking registration escaped native 16x16 geometry")
  local receipt = assert(resolver.receipts[lower])
  assert(receipt.lane == "primary-unverified"
      and receipt.path == walk.image,
    identity .. " exact headless loader selected a fallback unexpectedly")
end

run.release()
print(("CRYSTAL WALK EXACT ENGINE PASS: engine=%s edition=%s")
  :format(expectedEngine, edition))
