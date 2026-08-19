-- Exact Voxel Ascendant 0.1.5 player-trainer role compatibility.
--
-- Run from a compatible Gen1Recomp checkout, once per platform branch:
--   TRAINER_REMATCH_MOD_DIR=../kanto-ascendant \
--   VOXEL_ASCENDANT_MOD_DIR=../voxel-ascendant \
--   KA_VASC_PROBE_OS='OS X' \
--   luajit ../kanto-ascendant/tests/vasc_015_trainer_facing_compat_test.lua
--
-- BACK SPRITES owns Pokemon presentation. Trainer orientation is a separate
-- texture-role contract: native backs keep trainer=true; only an explicit
-- frontal Standing card asks VASC for the player-side mirror.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local GameVersion = require("src.core.GameVersion")
local kascDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local vascDir = assert(os.getenv("VOXEL_ASCENDANT_MOD_DIR"),
  "VOXEL_ASCENDANT_MOD_DIR is required")
local probeOS = os.getenv("KA_VASC_PROBE_OS") or "OS X"
assert(probeOS == "OS X" or probeOS == "iOS",
  "KA_VASC_PROBE_OS must be OS X or iOS")

local function basename(path)
  return tostring(path):gsub("/+$", ""):match("([^/]+)$")
end

love.system.getOS = function() return probeOS end
local Platform = require("src.core.Platform")
Platform._resetForTests()

-- The SDK harness mounts external roots under mods/<basename>. Resolve image
-- reads back to the exact checked-out packages so this exercises the real HD
-- assets instead of the headless stub's missing-file dimensions.
local originalNewImage = love.graphics.newImage
local mounts = {
  ["mods/" .. basename(kascDir) .. "/"] = kascDir .. "/",
  ["mods/" .. basename(vascDir) .. "/"] = vascDir .. "/",
}
love.graphics.newImage = function(source)
  if type(source) == "string" then
    for mounted, real in pairs(mounts) do
      if source:sub(1, #mounted) == mounted then
        source = real .. source:sub(#mounted + 1)
        break
      end
    end
  end
  return originalNewImage(source)
end

local originalEdition = GameVersion.get()
local run = T.sdk.loadMods({ kascDir, vascDir }, { data = Data, root = "/" })
local loadProblems = {}
for _, problem in ipairs(run.errors or {}) do
  loadProblems[#loadProblems + 1] = tostring(problem)
end
for id, loaded in pairs(run.loader.mods or {}) do
  loadProblems[#loadProblems + 1] = table.concat({
    tostring(id), "enabled=" .. tostring(loaded.enabled),
    "error=" .. tostring(loaded.error), "path=" .. tostring(loaded.path),
  }, ",")
end
local loadSummary = table.concat(loadProblems, " | ")
local kasc = assert(run.loader.exports.kanto_ascendant,
  "KASC export did not load: " .. loadSummary)
local vasc = assert(run.loader.exports.VOXEL_ASCENDANT,
  "VASC export did not load: " .. loadSummary)
T.eq(vasc.version, "0.1.5", "test uses exact Voxel Ascendant 0.1.5")

local characters = assert(kasc.extendedCharacters)
local receipt = assert(characters.voxelResolverStatus)
T.eq(receipt.installed, true, "KASC installs its VASC trainer resolver")
T.eq(receipt.rendererId, "VOXEL_ASCENDANT",
  "trainer resolver is owned by Voxel Ascendant")
T.eq(receipt.rendererVersion, "0.1.5",
  "trainer resolver records exact Voxel Ascendant 0.1.5")

local battleModule = assert(vasc.lib.require("OverworldBattle"))
T.eq(battleModule.__ascendantStandingTrainerMirror, true,
  "KASC installs one idempotent trainer-role wrapper")
if probeOS == "iOS" then
  T.eq(battleModule.snapHUDs, nil,
    "iOS keeps the legacy HUD compositor unavailable")
else
  T.eq(type(battleModule.snapHUDs), "function",
    "desktop retains the reviewed legacy HUD compositor")
end

local Pipelines = require("src.render.Pipelines")
Pipelines.install(Data)
Pipelines.setLevel("voxel", 1)
battleModule.setting:setIndex(1)
battleModule.backSetting:setIndex(1)
T.eq(battleModule.backPinned(), false,
  "BACK SPRITES OFF leaves the Pokemon back layer unpinned")

for _, identity in ipairs({ "RED", "BLUE", "GREEN" }) do
  characters.select(identity)
  local texture = battleModule.sideTexture({
    showPlayerBack = true,
    playerBackPic = {},
  }, "player")
  T.eq(texture.trainer, false,
    identity .. " frontal HD Standing art requests the player mirror")
  T.eq(texture.ascendantStandingTrainer, identity,
    identity .. " Standing art retains its exact identity")
  T.eq(texture.ascendantHighResTrainer, true,
    identity .. " resolves its packaged HD Standing asset")
  T.eq(texture.ascendantApprovedTrainerResolver.role, "player",
    identity .. " retains the explicit player-front role")
end

-- Yellow without an extended identity deliberately retains the edition's
-- native trainer back. The renderer already marks that source trainer=true;
-- KASC must not reclassify it as the last selected Standing identity.
GameVersion.set("yellow")
characters.setEnabled(false)
local nativeBack = love.graphics.newImage(kascDir
  .. "/assets/characters/crystal_chars/red_back.png")
local nativeBattle = {
  showPlayerBack = true,
  playerBackPic = nativeBack,
  data = Data,
  bottomUIVisible = function() return false end,
  picImage = function(_, image) return image end,
  picOffset = function() return 0 end,
}
local rawNative = battleModule.__ascendantStandingTrainerOriginal(
  nativeBattle, "player")
local wrappedNative = battleModule.sideTexture(nativeBattle, "player")
T.eq(rawNative.trainer, true,
  "VASC identifies the edition-native player trainer back")
T.eq(wrappedNative.trainer, true,
  "KASC preserves the native trainer-back no-mirror marker")
T.eq(wrappedNative.ascendantStandingTrainer, nil,
  "native trainer back receives no frontal Standing identity")

GameVersion.set(originalEdition)
love.graphics.newImage = originalNewImage
run.release()
T.finish("VASC 0.1.5 trainer-facing compatibility " .. probeOS)
