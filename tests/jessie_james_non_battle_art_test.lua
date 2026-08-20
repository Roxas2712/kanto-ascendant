-- The sealed Yellow Jessie/James/Meowth identity must also work through the
-- reviewed DRAMALESS 1.6.2 renderer facade.  This is intentionally separate
-- from Battle Art: it guards the legacy branch that previously indexed the
-- nonexistent `authority.assets` table after a successful trio decode.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local Pipelines = require("src.render.Pipelines")
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

GameVersion.set("yellow")
local Data = T.fixtures.fresh()
local rocket = {
  id = "OPP_ROCKET",
  name = "ROCKET",
  pic = "/engine/yellow/rocket.png",
  picJessieJames = "/engine/yellow/jessie-james.png",
  parties = { [42] = {}, [43] = {}, [44] = {}, [45] = {} },
}
Data.trainers.OPP_ROCKET = rocket

local rendererDir = modDir .. "/tests/fixtures/dramaless_190_contract_mod"
local sdkRoot = modDir:sub(1, 1) == "/" and "/" or "."
local run = T.sdk.loadMods({ modDir, rendererDir }, {
  data = Data,
  root = sdkRoot,
})
local unexpected = {}
local derivedWritePrefix = "kanto_ascendant: asset transform failed: "
  .. "could not write save/mod-derived/kanto_ascendant/hidden_evolution/"
  .. "interaction_anchor.png:"
for _, message in ipairs(run.errors or {}) do
  message = tostring(message)
  if message:sub(1, #derivedWritePrefix) ~= derivedWritePrefix then
    unexpected[#unexpected + 1] = message
  end
end
T.eq(#unexpected, 0,
  "KASC and the reviewed DRAMALESS contract load without unexpected errors")

local ascendant = assert(run.loader.exports.kanto_ascendant)
local dramaless = assert(run.loader.exports.DRAMALESS_SHAPE)
local characters = assert(ascendant.extendedCharacters)
local overworld = assert(dramaless.overworldBattle)
T.eq(characters.voxelResolverStatus.rendererId, "DRAMALESS_SHAPE",
  "the legacy branch is installed through the reviewed renderer receipt")

-- The legacy renderer uses the engine's live Voxel-pipeline state rather than
-- Battle Art's staged-identity exception.  Install the smallest real pipeline
-- contract needed to activate that public branch.
Pipelines.install({ render_pipelines = {
  voxel = {
    id = "voxel", levels = { "OFF", "ON" },
    drawWorld = function() end,
  },
} })
T.eq(Pipelines.setLevel("voxel", 1), 1,
  "the non-Battle-Art renderer branch is genuinely active")

local game = {
  data = Data,
  save = { options = { modOptions = { kanto_ascendant = {
    trainer_portrait_style = "crystal_hd",
  } } } },
}
local function battle(index, trainer)
  return {
    game = game,
    trainer = trainer == nil and rocket or trainer,
    oppClass = "OPP_ROCKET",
    partyIndex = index,
    showEnemyTrainer = true,
  }
end

local g = assert(love.graphics)
local originalNewImage = g.newImage
local imageMode = "none"
local function surfaceRole(path)
  path = tostring(path)
  if path:match("jessie_james_meowth_voxel_front_hd%.png$") then
    return "voxel128", 128
  end
  if path:match("jessie_james_meowth_voxel_front%.png$") then
    return "voxel64", 64
  end
  if path:match("crystal_v15/trainers/normal/jessie_james%.png$") then
    return "exact-duo-failsafe", 56
  end
  return nil, 128
end
g.newImage = function(path)
  local role, width = surfaceRole(path)
  local allowed = not role or imageMode == "all"
    or imageMode == "voxel64" and role ~= "voxel128"
    or imageMode == "exact-duo-failsafe"
      and role == "exact-duo-failsafe"
  if not allowed then error("synthetic decode failure: " .. tostring(path)) end
  return {
    path = path,
    setFilter = function() end,
    getWidth = function() return width end,
    getHeight = function() return width end,
    getDimensions = function() return width, width end,
  }
end

-- A complete decode failure must decline the stage.  In particular it may
-- neither return DRAMALESS' class-only Rocket card nor throw while producing
-- an authority receipt.
local broken = battle(42)
T.eq(overworld.begin({}, broken), false,
  "unreadable trio surfaces decline legacy staged rendering")
T.eq(broken.kascJessieJamesBattleMode, "native_2d",
  "legacy decode failure returns to the native Jessie/James portrait")
T.eq(overworld.sideTexture(broken, "enemy"), nil,
  "legacy decode failure never leaks the generic Rocket card")

local surfaces = {
  { mode = "exact-duo-failsafe", role = "exact-duo-failsafe",
    sha256 = "c6c086d954fe828be6f407438e0c6203d19c6d32a427c4fc2773a4ec9d65e46f" },
  { mode = "voxel64", role = "voxel64",
    sha256 = "07fca69290146b89461746bf03777126cb0c65ff151a8a7846972481b0dbd164" },
  { mode = "all", role = "voxel128",
    sha256 = "8b57885bdb1775bb2a43486af129976583229ca3a462e3c596943d8c55e5eb01" },
}
for _, row in ipairs(surfaces) do
  imageMode = row.mode
  local current = battle(42)
  T.eq(overworld.begin({}, current), true,
    row.role .. " is accepted by the legacy renderer stage")
  local texture = assert(overworld.sideTexture(current, "enemy"))
  T.eq(texture.yellowJessieJames, true,
    row.role .. " remains the exact Yellow identity")
  T.eq(texture.yellowJessieJamesAssetRole, row.role,
    row.role .. " records the actually decoded surface")
  T.eq(texture.ascendantApprovedTrainerResolver.sourceSha256, row.sha256,
    row.role .. " records the verified bytes instead of a forged hash")
  T.eq(texture.ascendantApprovedTrainerResolver.requiresMeowth, true,
    row.role .. " keeps the approved Meowth contract")
  T.neq(texture.sourceOwner, "DRAMALESS_NATIVE_TRAINER_CARD",
    row.role .. " cannot be replaced by a generic Rocket card")
  overworld.finish()
end

-- Trainer-card style is independent from this story identity.  The fixed
-- Yellow trio still uses the approved staged surface in ORIGINAL mode.
game.save.options.modOptions.kanto_ascendant.trainer_portrait_style = "original"
local originalStyle = assert(overworld.sideTexture(battle(45), "enemy"))
T.eq(originalStyle.yellowJessieJamesPartyIndex, 45,
  "ORIGINAL trainer cards retain the exact Yellow party identity")

-- Party 41 is an ordinary Rocket and must remain wholly renderer-owned.
local ordinary = overworld.sideTexture(battle(41), "enemy")
T.eq(ordinary.sourceOwner, "DRAMALESS_NATIVE_TRAINER_CARD",
  "ordinary Rocket parties are unchanged in the legacy renderer")

g.newImage = originalNewImage
Pipelines.install()
run.release()
T.finish("jessie_james_non_battle_art_test")
