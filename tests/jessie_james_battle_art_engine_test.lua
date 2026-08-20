-- Exact-engine authority and renderer integration for Yellow's four
-- Jessie/James encounters.  Run from Gen1 Recomp 0.1.96/0.1.98 for each
-- official Red/Blue/Yellow edition.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Version = require("src.core.Version")
local GameVersion = require("src.core.GameVersion")
local BattleState = require("src.battle.BattleState")

local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
local edition = assert(os.getenv("KA_EXPECT_EDITION"),
  "KA_EXPECT_EDITION is required")
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
assert(expectedEngine == "0.1.96" or expectedEngine == "0.1.98",
  "unsupported exact engine " .. tostring(expectedEngine))
assert(edition == "red" or edition == "blue" or edition == "yellow",
  "official edition required")
T.eq(Version.engine, expectedEngine, "the requested exact engine is active")
GameVersion.set(edition)
T.eq(GameVersion.get(), edition, "the requested edition is active")

local Data = T.fixtures.fresh()
local rocket = {
  id = "OPP_ROCKET",
  name = "ROCKET",
  pic = "/engine/" .. edition .. "/rocket.png",
  parties = { [42] = {}, [43] = {}, [44] = {}, [45] = {} },
}
if edition == "yellow" then
  rocket.picJessieJames = "/engine/yellow/jessie-james.png"
end
Data.trainers.OPP_ROCKET = rocket

local function expectedNative(index)
  if edition == "yellow" and index >= 42 then
    return rocket.picJessieJames
  end
  return rocket.pic
end
for index = 41, 45 do
  T.eq(BattleState.trainerPicPath(Data, rocket, "OPP_ROCKET", index),
    expectedNative(index),
    edition .. " native trainer picture is stable for party " .. index)
end

-- Pin the four canonical story call sites as well as the runtime threshold.
local script = assert(io.open("data/scripts/yellow_jessie_james.lua", "rb"))
local scriptSource = assert(script:read("*a"))
script:close()
for index = 42, 45 do
  local needle = '{ "start_battle", "trainer", "OPP_ROCKET", '
    .. tostring(index) .. " }"
  local _, count = scriptSource:gsub(needle:gsub("([^%w])", "%%%1"), "")
  T.eq(count, 1, "Yellow story registers party " .. index .. " exactly once")
end

local battleDir = modDir .. "/tests/fixtures/battle_art_190_contract_mod"
local sdkRoot = modDir:sub(1, 1) == "/" and "/" or "."
local run = T.sdk.loadMods({ modDir, battleDir }, {
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
T.eq(#unexpected, 0, "KASC and Battle Art load without unexpected errors")

local ascendant = assert(run.loader.exports.kanto_ascendant)
local battleArt = assert(run.loader.exports.BATTLE_ART_VOXEL_FORK)
local characters = assert(ascendant.extendedCharacters)
local overworld = assert(battleArt.overworldBattle)
T.eq(characters.voxelResolverStatus.sealedJessieJamesOverride, true,
  "Battle Art receipt exposes the narrow Jessie/James override")

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
local imageMode = "all"
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

if edition == "yellow" then
  for index = 42, 45 do
    local spec = characters.voxelStandingTrainerSpec(battle(index), "enemy")
    T.eq(spec and spec.id, "YELLOW_JESSIE_JAMES_MEOWTH",
      "party " .. index .. " resolves the sealed trio identity")
    T.eq(spec.authority.partyIndex, index,
      "party " .. index .. " keeps its exact authority receipt")
  end

  -- Start with every packaged surface synthetically unreadable so no cached
  -- texture can hide the final fail-closed path.
  imageMode = "none"
  for _, entry in ipairs({
    { name = "begin", invoke = function(current)
      return overworld.begin({}, current)
    end },
    { name = "ensure", invoke = function(current)
      return overworld.ensure(current)
    end },
  }) do
    local broken = battle(42)
    T.eq(entry.invoke(broken), false,
      "an unreadable trio package declines staged " .. entry.name)
    T.eq(broken.kascJessieJamesBattleMode, "native_2d",
      entry.name .. " decode failure returns to Yellow's native duo picture")
    T.eq(overworld.sideTexture(broken, "enemy"), nil,
      entry.name .. " decode failure never delegates to generic Rocket art")
  end

  local surfaceModes = {
    { mode = "exact-duo-failsafe", role = "exact-duo-failsafe",
      suffix = "assets/crystal_v15/trainers/normal/jessie_james.png" },
    { mode = "voxel64", role = "voxel64",
      suffix = "assets/yellow_jessie_james/battle/"
        .. "jessie_james_meowth_voxel_front.png" },
    { mode = "all", role = "voxel128",
      suffix = "assets/yellow_jessie_james/battle/"
        .. "jessie_james_meowth_voxel_front_hd.png" },
  }
  for _, row in ipairs(surfaceModes) do
    imageMode = row.mode
    local current = battle(42)
    T.eq(overworld.begin({}, current), true,
      row.role .. " keeps the staged renderer available")
    local texture = assert(overworld.sideTexture(current, "enemy"))
    T.eq(texture.yellowJessieJames, true,
      row.role .. " cannot be mistaken for a generic Rocket")
    T.eq(texture.yellowJessieJamesAssetRole, row.role,
      row.role .. " is recorded as the selected safe surface")
    T.check(texture.ascendantHighResSource:sub(-#row.suffix) == row.suffix,
      row.role .. " uses its exact approved package path")
    T.eq(texture.ascendantApprovedTrainerResolver.requiresMeowth, true,
      row.role .. " preserves the approved Meowth requirement")
    T.neq(texture.sourceOwner, "BATTLE_ART_TRAINER_ART",
      row.role .. " overrides Battle Art's class-only Rocket lookup")
    overworld.finish()
  end

  imageMode = "all"
  for _, style in ipairs({ "original", "crystal_hd" }) do
    game.save.options.modOptions.kanto_ascendant.trainer_portrait_style = style
    local texture = overworld.sideTexture(battle(45), "enemy")
    T.eq(texture.yellowJessieJamesPartyIndex, 45,
      style .. " keeps the story identity independent of trainer-card style")
  end

  local copied = {
    id = rocket.id,
    pic = rocket.pic,
    picJessieJames = rocket.picJessieJames,
    parties = rocket.parties,
  }
  for _, row in ipairs({
    { label = "ordinary party", value = battle(41) },
    { label = "copied trainer", value = battle(42, copied) },
  }) do
    local spec = characters.voxelStandingTrainerSpec(row.value, "enemy")
    T.eq(spec and spec.id, "KANTO_ROCKET",
      row.label .. " cannot adopt the trio identity")
    local texture = overworld.sideTexture(row.value, "enemy")
    T.eq(texture.sourceOwner, "BATTLE_ART_TRAINER_ART",
      row.label .. " stays in Battle Art's generic trainer ownership")
  end

  local nativePic = rocket.picJessieJames
  rocket.picJessieJames = nil
  T.eq(characters.voxelStandingTrainerSpec(battle(42), "enemy").id,
    "KANTO_ROCKET", "missing native Yellow portrait fails closed")
  rocket.picJessieJames = nativePic
else
  local spec = characters.voxelStandingTrainerSpec(battle(42), "enemy")
  T.eq(spec and spec.id, "KANTO_ROCKET",
    edition .. " cannot infer the duo from Yellow's party threshold")
  local texture = overworld.sideTexture(battle(42), "enemy")
  T.eq(texture.sourceOwner, "BATTLE_ART_TRAINER_ART",
    edition .. " keeps ordinary Rocket renderer ownership")
end

g.newImage = originalNewImage
run.release()
T.finish("jessie_james_battle_art_engine_test " .. expectedEngine
  .. "/" .. edition)
