-- Exact supported-engine contract for the bounded 6.5.7 HD standard card.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Version = require("src.core.Version")
local GameVersion = require("src.core.GameVersion")
local Runtime = require("src.mods.Runtime")
local Screens = require("src.ui.Screens")
local Badges = require("src.inventory.Badges")

local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
T.eq(Version.engine, expectedEngine, "exact supported engine is active")
local edition = assert(os.getenv("KA_EXPECT_EDITION"),
  "KA_EXPECT_EDITION is required")
assert(edition == "red" or edition == "blue" or edition == "yellow")
GameVersion.set(edition)
T.eq(GameVersion.get(), edition, "requested edition is active")

local function noop() end
for _, name in ipairs({ "arc", "ellipse", "polygon" }) do
  if type(love.graphics[name]) ~= "function" then love.graphics[name] = noop end
end

local Data = T.fixtures.fresh()
Data.constants.badges = {
  { id = "BOULDERBADGE" }, { id = "CASCADEBADGE" },
  { id = "THUNDERBADGE" }, { id = "RAINBOWBADGE" },
  { id = "SOULBADGE" }, { id = "MARSHBADGE" },
  { id = "VOLCANOBADGE" }, { id = "EARTHBADGE" },
}

local modPath = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local function relativePath(target, base)
  local function parts(path)
    local result = {}
    for part in tostring(path):gmatch("[^/]+") do result[#result + 1] = part end
    return result
  end
  local targetParts, baseParts = parts(target), parts(base)
  local shared = 0
  while targetParts[shared + 1]
      and targetParts[shared + 1] == baseParts[shared + 1] do
    shared = shared + 1
  end
  local result = {}
  for _ = shared + 1, #baseParts do result[#result + 1] = ".." end
  for index = shared + 1, #targetParts do
    result[#result + 1] = targetParts[index]
  end
  return #result > 0 and table.concat(result, "/") or "."
end

local sdkModPath = modPath
local workingDirectory = os.getenv("PWD")
if modPath:sub(1, 1) == "/" and workingDirectory
    and workingDirectory:sub(1, 1) == "/" then
  sdkModPath = relativePath(modPath, workingDirectory)
end

-- Avoid the unrelated plain-Lua FileData write mismatch in the exact engine
-- fixture by seeding the current asset-transform stamp.
local transformFile = assert(io.open(modPath .. "/shiny_transforms.lua", "rb"))
local transformSource = assert(transformFile:read("*a"))
transformFile:close()
local transformHash = 5381
for index = 1, #transformSource do
  transformHash = (transformHash * 33 + transformSource:byte(index))
    % 4294967296
end
local engineFs = T.fs.new(".")
local cacheMarker = engineFs.read("rom-cache.complete") or "no-cache"
engineFs.createDirectory("save/mod-derived/kanto_ascendant")
assert(engineFs.write("save/mod-derived/kanto_ascendant/.stamp",
  cacheMarker .. "|" .. string.format("%08x", transformHash)))

local run = T.sdk.loadMod(sdkModPath, { data = Data })
T.check(run.mod ~= nil, "Kanto Ascendant loads through the exact SDK")
T.eq(#(run.errors or {}), 0, "full main and registries merge cleanly")
local exports = assert(run.loader.exports.kanto_ascendant)
local renderer = assert(exports.trainerCardHDStandard,
  "bounded HD standard-card export is available")
T.eq(exports.trainerCardCollection, nil,
  "6.7 Trainer Card collection is not present in the 6.5.7 replacement")
T.eq(exports.trainerCardHDRenderer, nil,
  "6.7 gallery/matchup renderer is not present")
T.eq(renderer.width, 640, "HD card owns a 640px logical surface")
T.eq(renderer.height, 400, "HD card owns a 400px logical surface")
T.eq(renderer.assetPolicy.playerSourcePixels, 128,
  "player portrait contract keeps the 128px master")
T.eq(renderer.assetPolicy.leaderSourcePixels, 128,
  "leader portrait contract keeps the 128px masters")

local pressed, popCount = {}, 0
local stack = { states = {} }
function stack:top() return self.states[#self.states] end
function stack:pop()
  popCount = popCount + 1
  return table.remove(self.states)
end
local input = {}
function input:wasPressed(name) return pressed[name] == true end
local game = {
  data = Data,
  input = input,
  stack = stack,
  save = {
    player = { name = edition:upper() },
    inventory = {}, flags = {}, money = 83000, playTime = 5760,
  },
}
renderer.install(game)

local baseModel = renderer.buildModel(game)
T.eq(baseModel.brand, "KANTO ASCENDANT", "fixed product brand is present")
T.eq(baseModel.title, "NO ACTIVE TITLE",
  "fresh card does not manufacture an earned title")
T.eq(baseModel.identity, "RED",
  "unselected saves use the available Red-shaped 128px protagonist master")
T.eq(baseModel.money, 83000, "native money value is retained")
T.eq(baseModel.hours, 1, "native play-time hours are retained")
T.eq(baseModel.minutes, 36, "native play-time minutes are retained")
T.eq(#baseModel.badges, 8, "all eight Kanto badge cells are present")
T.eq(baseModel.badgesOwned, 0, "fresh inventory owns no badges")
T.eq(baseModel.badges[8].hidden, true,
  "Giovanni remains an anonymous silhouette before his defeat")

exports.extendedCharacters.select("GREEN")
local greenModel = renderer.buildModel(game)
T.eq(greenModel.identity, "GREEN",
  "explicit Ascendant identity selects the matching 128px portrait")
T.check(greenModel.portraitPath:find("green_voxel_front_hd.png", 1, true)
    ~= nil, "Green card resolves the HD portrait master")
exports.extendedCharacters.select("BLUE")
local blueModel = renderer.buildModel(game)
T.eq(blueModel.identity, "BLUE",
  "Blue's explicit Ascendant identity is retained on the card")
T.check(blueModel.portraitPath:find("blue_voxel_front_hd.png", 1, true)
    ~= nil, "Blue card resolves the HD portrait master")
exports.extendedCharacters.select("GREEN")

T.check(exports.ascendant.unlockAchievement("master_circuit"),
  "a real title authority can be earned")
T.check(exports.legacyHall.selectTitle("master_circuit"),
  "a real earned title can be selected")
local titled = renderer.buildModel(game)
T.eq(titled.brand, "KANTO ASCENDANT",
  "selected title never replaces the fixed product brand")
T.eq(titled.title, "CRESTBEARER",
  "selected title is shown independently on the card")

local badgeList = Badges.list(Data)
local firstItem = assert(Badges.itemFor(badgeList[1]))
game.save.inventory[firstItem] = false
local falsyBadge = renderer.buildModel(game)
T.eq(falsyBadge.badgesOwned, 0,
  "a falsy native badge inventory value is not treated as earned")
game.save.inventory[firstItem] = 1
local withBadge = renderer.buildModel(game)
T.eq(withBadge.badgesOwned, 1, "native badge inventory drives the HD card")
T.eq(withBadge.badges[1].owned, true, "owned Boulder badge is visible")
T.eq(withBadge.badges[2].owned, false, "unowned Cascade badge stays locked")
T.eq(withBadge.badges[8].hidden, true,
  "unrelated badges do not reveal Giovanni")

local earthItem = assert(Badges.itemFor(badgeList[8]))
game.save.inventory[earthItem] = 1
local earthOnly = renderer.buildModel(game)
T.eq(earthOnly.badges[8].owned, true,
  "the native Earth Badge remains visible when present")
T.eq(earthOnly.badges[8].hidden, true,
  "an injected Earth Badge alone does not prove Giovanni was defeated")

game.save.flags.EVENT_BEAT_GIOVANNI = true
local afterGiovanni = renderer.buildModel(game)
T.eq(afterGiovanni.badges[8].hidden, false,
  "the authoritative Giovanni victory flag reveals his portrait")
game.save.flags.EVENT_BEAT_GIOVANNI = nil
game.save.flags.EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI = true
local afterImportedGiovanni = renderer.buildModel(game)
T.eq(afterImportedGiovanni.badges[8].hidden, false,
  "the imported vanilla Giovanni victory flag also reveals his portrait")
game.save.flags.EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI = nil
game.save.inventory[earthItem] = nil

game.save.modData = { kanto_ascendant = { legacy_journey = {
  runId = "CARD:ENGINE", pact = "legacy",
} } }
local pactModel = renderer.buildModel(game)
T.eq(pactModel.pact, "PACT:LEGACY",
  "the existing Legacy pact remains visible on the HD replacement")
game.save.modData = nil

local function be32(text, offset)
  local a, b, c, d = text:byte(offset, offset + 3)
  return ((a * 256 + b) * 256 + c) * 256 + d
end
local function assertPng128(path, label)
  local file = assert(io.open(modPath .. "/" .. path, "rb"),
    "missing " .. label .. ": " .. tostring(path))
  local header = file:read(24)
  file:close()
  T.check(header and #header == 24
      and header:sub(1, 8) == "\137PNG\r\n\26\n",
    label .. " is a readable PNG")
  T.eq(be32(header, 17), 128, label .. " source width remains 128px")
  T.eq(be32(header, 21), 128, label .. " source height remains 128px")
end
assertPng128(withBadge.portraitPath, "player portrait")
for index, badge in ipairs(withBadge.badges) do
  assertPng128(badge.path, "leader portrait " .. index)
end

Screens.invalidate()
local screen = Screens.build(game, "TrainerCard")
stack.states[1] = screen
T.check(screen[renderer.marker] == true,
  "effective TrainerCard resolves to the HD presentation wrapper")
T.eq(screen.screenId, "TrainerCard", "native screen identity is retained")
T.check(type(screen.update) == "function",
  "native TrainerCard input lifecycle is retained")

local ownedHudLinks = 0
for _, link in ipairs(run.loader.hooks.chains["render.hud"] or {}) do
  if link.owner == "kanto_ascendant" then ownedHudLinks = ownedHudLinks + 1 end
end
T.check(ownedHudLinks >= 1, "Kanto Ascendant owns the final-window HUD pass")

local rectangles = 0
local nativeRectangle = love.graphics.rectangle
love.graphics.rectangle = function(...)
  rectangles = rectangles + 1
  return nativeRectangle(...)
end
local downstream = 0
if love.graphics.setScissor then love.graphics.setScissor(3, 4, 50, 60) end
Runtime.call("render.hud", function() downstream = downstream + 1 end,
  game, { width = 1280, height = 800 })
love.graphics.rectangle = nativeRectangle
T.eq(downstream, 1, "HD card preserves the downstream HUD chain")
T.check(rectangles > 20, "HD card draws substantial window-space geometry")
T.check(renderer.lastError == nil,
  "HD card renders without native fallback: " .. tostring(renderer.lastError))
if love.graphics.getScissor then
  local sx, sy, sw, sh = love.graphics.getScissor()
  T.eq(sx, 3, "HUD restores the incoming scissor x")
  T.eq(sy, 4, "HUD restores the incoming scissor y")
  T.eq(sw, 50, "HUD restores the incoming scissor width")
  T.eq(sh, 60, "HUD restores the incoming scissor height")
  love.graphics.setScissor()
end

game.save.playTime = game.save.playTime + 60
Runtime.call("render.hud", function() end,
  game, { width = 1280, height = 800 })
T.eq(screen[renderer.modelKey].minutes, 37,
  "a second HUD frame refreshes the live native play time")

pressed = { b = true }
screen:update(0)
pressed = {}
T.eq(popCount, 1, "native B input still closes exactly one TrainerCard")

local cancelCount = 0
local aScreen = Screens.build(game, "TrainerCard", {
  onCancel = function() cancelCount = cancelCount + 1 end,
})
stack.states[1] = aScreen
pressed = { a = true }
aScreen:update(0)
pressed = {}
T.eq(popCount, 2, "native A input also closes exactly one TrainerCard")
T.eq(cancelCount, 1, "native TrainerCard onCancel callback remains intact")
T.eq(run.loader.modSave.kanto_ascendant.trainer_card_hd_standard, nil,
  "presentation creates no new save bucket")

run.release()
T.finish(("HD standard Trainer Card engine=%s edition=%s")
  :format(expectedEngine, edition))
