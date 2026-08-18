-- Exact-engine regression for Yellow's Oak partner emotion window.
--
-- Run once per supported engine and Red/Blue/Yellow edition.  The positive
-- Yellow case deliberately uses the vanilla three-argument command from
-- pokeyellow's OaksLab script.  Passing an explicit fourth argument would
-- hide the production regression this test protects.

local support = assert(os.getenv("KA_ENGINE_SUPPORT_ROOT"),
  "KA_ENGINE_SUPPORT_ROOT is required")
package.path = "./?.lua;./?/init.lua;" .. support .. "/?.lua;"
  .. support .. "/?/init.lua;" .. package.path

local T = require("tests.modkit")
local Version = require("src.core.Version")
local GameVersion = require("src.core.GameVersion")
local SaveData = require("src.core.SaveData")

local modRoot = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
local edition = assert(os.getenv("KA_EXPECT_EDITION"),
  "KA_EXPECT_EDITION is required")

assert(Version.engine == expectedEngine,
  ("wrong exact engine: expected %s, got %s")
    :format(expectedEngine, tostring(Version.engine)))
assert(edition == "red" or edition == "blue" or edition == "yellow",
  "KA_EXPECT_EDITION must be red, blue, or yellow")
GameVersion.set(edition)

local function clone(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = clone(child) end
  return out
end

-- The public engine fixture is intentionally tiny.  Add only the two native
-- species and six moves needed by Kanto Ascendant's Gorochu registration and
-- by the real Commands.give_pokemon/PikachuFollower path under test.
local Data = T.fixtures.fresh()
Data.pokemon.PIKACHU = clone(Data.pokemon.FIXMON_A)
Data.pokemon.PIKACHU.id = "PIKACHU"
Data.pokemon.PIKACHU.index = 25
Data.pokemon.PIKACHU.dex = 25
Data.pokemon.PIKACHU.name = "PIKACHU"
Data.pokemon.PIKACHU.spriteFront =
  "assets/generated/pokemon/front/025.png"
Data.pokemon.PIKACHU.spriteBack =
  "assets/generated/pokemon/back/025.png"

Data.pokemon.RAICHU = clone(Data.pokemon.FIXMON_B)
Data.pokemon.RAICHU.id = "RAICHU"
Data.pokemon.RAICHU.index = 26
Data.pokemon.RAICHU.dex = 26
Data.pokemon.RAICHU.name = "RAICHU"
Data.pokemon.RAICHU.spriteFront =
  "assets/generated/pokemon/front/026.png"
Data.pokemon.RAICHU.spriteBack =
  "assets/generated/pokemon/back/026.png"

for _, moveId in ipairs({
  "THUNDERBOLT", "BITE", "AGILITY", "THUNDER",
  "THUNDERSHOCK", "THUNDER_WAVE",
}) do
  local move = clone(Data.moves.FIX_TACKLE)
  move.id, move.name = moveId, moveId
  Data.moves[moveId] = move
end

Data.sprites = Data.sprites or {}
Data.sprites.SPRITE_PIKACHU = {
  image = "assets/generated/sprites/pikachu.png",
  frames = 6,
  walker = true,
}
Data.field = Data.field or {}
Data.field.emotionBubbles = {
  path = "assets/generated/ui/emotion_bubbles.png",
  bubbles = {
    { name = "BOLT_BUBBLE", x = 0, y = 0, w = 16, h = 16 },
  },
}

-- Keep asset-transform stamps and derived fixture pixels in memory.  The
-- test remains read-only with respect to both the exact engine tree and the
-- candidate worktree while still using Loader's production discovery path.
local disk = T.fs.new("/")
local memory, directories = {}, {}
local alias = "mods/kanto_ascendant_emotion_test"

local function mapped(path)
  if path == alias then return modRoot end
  if path:sub(1, #alias + 1) == alias .. "/" then
    return modRoot .. path:sub(#alias + 1)
  end
  return path
end

local fs = { root = "/" }
function fs.read(path)
  if memory[path] ~= nil then return memory[path] end
  return disk.read(mapped(path))
end
function fs.write(path, body)
  memory[path] = body
  return true
end
function fs.load(path) return disk.load(mapped(path)) end
function fs.getInfo(path)
  if memory[path] ~= nil then return { type = "file" } end
  if directories[path] or path == "mods" then return { type = "directory" } end
  return disk.getInfo(mapped(path))
end
function fs.getDirectoryItems(path)
  if path == "mods" then return { "kanto_ascendant_emotion_test" } end
  return disk.getDirectoryItems(mapped(path))
end
function fs.createDirectory(path)
  directories[path] = true
  return true
end

local run = T.sdk.loadMods({ alias }, { data = Data, fs = fs })
local loaded = assert(run.mods.kanto_ascendant,
  "Kanto Ascendant did not load through the exact engine SDK")
assert(loaded.manifest.version == "6.5.7",
  "regression must run against Kanto Ascendant 6.5.7")
assert(#(run.errors or {}) == 0, table.concat(run.errors or {}, "\n"))

local function freshSave()
  local save = SaveData.newGame({
    version = edition, playerName = "EMOTION", rivalName = "RIVAL",
  })
  save.party = {}
  save.flags = {}
  save.boxes = {}
  return save
end

local function stackStub()
  local stack = { pushed = {} }
  function stack:push(screen) self.pushed[#self.pushed + 1] = screen end
  function stack:pop() return table.remove(self.pushed) end
  function stack:top() return self.pushed[#self.pushed] end
  return stack
end

local save = freshSave()
local game = {
  data = Data,
  save = save,
  mods = run.loader,
  overworld = nil,
  stack = stackStub(),
  writeSave = function() return true end,
}
run.loader.modSave = save.modData
run.loader.events:emit("save.created", { game = game, save = save })
run.loader.events:emit("game.ready", { game = game })

local exports = assert(run.loader.exports.kanto_ascendant)
local marker = assert(exports.yellowPartner.marker)
local Commands = require("src.script.Commands")

local function commandContext(caseSave, mapId)
  local caseGame = {
    data = Data,
    save = caseSave,
    mods = run.loader,
    stack = stackStub(),
  }
  return {
    game = caseGame,
    save = caseSave,
    overworld = { map = { id = mapId } },
  }
end

local function lastPartyMon(caseSave)
  return caseSave.party[#caseSave.party]
end

if edition ~= "yellow" then
  local ctx = commandContext(save, "OAKS_LAB")
  Commands.give_pokemon(ctx, "PIKACHU", 5)
  assert(ctx.lastCheck == true and lastPartyMon(save),
    "negative-control Oak gift was not created")
  assert(lastPartyMon(save)[marker] ~= true,
    "Red/Blue must never acquire Yellow's persistent partner marker")
  assert(exports.yellowPartner.partner(game) == nil,
    "Red/Blue must never expose a Yellow partner")
  run.release()
  print(("yellow_pikachu_emotion_engine_test: PASS engine=%s edition=%s negative")
    :format(expectedEngine, edition))
  return
end

local ctx = commandContext(save, "OAKS_LAB")

-- This is the exact command signature used by Yellow's Oak script.  Do not add a
-- fourth argument: 6.5.6's regression was an incorrect `== true` predicate
-- for a parameter vanilla never supplies.
Commands.give_pokemon(ctx, "PIKACHU", 5)
assert(ctx.lastCheck == true and #save.party == 1,
  "Yellow's real Oak gift was not created")
local partner = save.party[1]
assert(partner[marker] == true,
  "Yellow's real three-argument Oak gift lacks the persistent partner marker")
assert(exports.yellowPartner.partner(game) == partner,
  "the marked Oak gift is not Yellow's authoritative partner")

-- Fail closed for distinguishable lookalike gifts.  A different caller using
-- the identical three-argument signature in the exact same story context is
-- intentionally indistinguishable from the vanilla command at this seam.
do
  local wrongMap = freshSave()
  Commands.give_pokemon(commandContext(wrongMap, "PALLET_TOWN"),
    "PIKACHU", 5)
  assert(lastPartyMon(wrongMap)[marker] ~= true,
    "a level-5 Pikachu outside Oak's Lab was marked as the partner")

  local wrongLevel = freshSave()
  Commands.give_pokemon(commandContext(wrongLevel, "OAKS_LAB"),
    "PIKACHU", 6)
  assert(lastPartyMon(wrongLevel)[marker] ~= true,
    "a non-starter-level Oak's Lab Pikachu was marked as the partner")

  local alreadyStarted = freshSave()
  alreadyStarted.flags.EVENT_GOT_STARTER = true
  Commands.give_pokemon(commandContext(alreadyStarted, "OAKS_LAB"),
    "PIKACHU", 5)
  assert(lastPartyMon(alreadyStarted)[marker] ~= true,
    "a later Oak's Lab Pikachu replaced an existing starter identity")

  local explicitFalse = freshSave()
  Commands.give_pokemon(commandContext(explicitFalse, "OAKS_LAB"),
    "PIKACHU", 5, false)
  assert(lastPartyMon(explicitFalse)[marker] ~= true,
    "an explicit-false gift impersonated Yellow's vanilla command signature")

  local explicitTrue = freshSave()
  Commands.give_pokemon(commandContext(explicitTrue, "OAKS_LAB"),
    "PIKACHU", 5, true)
  assert(lastPartyMon(explicitTrue)[marker] ~= true,
    "an explicit-true gift impersonated Yellow's vanilla command signature")
end

-- The lab script sets this flag after the command.  At that point the native
-- first-follower entity has Ascendant's synchronized identity metadata.
save.flags.EVENT_GOT_STARTER = true
local player = { facing = "down" }
function player:facingCell() return 5, 5 end
local npc = {
  cellX = 5, cellY = 5, px = 80, py = 80,
  moving = false, facing = "up", pikachuFollower = true,
  followerMon = partner, followerSpecies = "PIKACHU",
  _ascendantChainIndex = 1,
}
function npc:facePlayer() self.facing = "up" end

local Overworld = require("src.world.OverworldController")
local ow = setmetatable({
  player = player,
  npcs = { npc },
  entities = { npc },
  emote = nil,
  map = {
    id = "PALLET_TOWN",
    isCounterCell = function() return false end,
  },
}, { __index = Overworld })
game.overworld = ow

-- OverworldController's production A path captures the engine Game singleton
-- after :enter().  This headless fixture does not enter a ROM map, so inject
-- this exact game only into that native function's private Game upvalue.
local function upvalue(fn, wanted)
  for index = 1, 100 do
    local name, value = debug.getupvalue(fn, index)
    if not name then break end
    if name == wanted then return index, value end
  end
  return nil
end
local _, nativeInteract = upvalue(Overworld.interact, "originalInteract")
assert(type(nativeInteract) == "function",
  "Ascendant's native-interaction delegate is unavailable")
local gameIndex = assert(upvalue(nativeInteract, "Game"),
  "native Overworld.interact no longer exposes its Game lifecycle upvalue")
debug.setupvalue(nativeInteract, gameIndex, game)

local Sound = require("src.core.Sound")
local realPikaCry, realCry = Sound.playPikaCry, Sound.playCry
Sound.playPikaCry = function() return true end
Sound.playCry = function() return true end

-- One real native A interaction must select TalkToPikachu, not Ascendant's
-- generic follower TextBox.  The fresh-save mood is allowed to have no
-- bubble, but every emotion owns the framed pikaPic window.
Overworld.interact(ow)
Sound.playPikaCry, Sound.playCry = realPikaCry, realCry
assert(ow.emote and ow.emote.npc == npc,
  "native A interaction did not enter TalkToPikachu")
assert(type(ow.emote.pikaPic) == "string" and ow.emote.pikaPic ~= "",
  "native TalkToPikachu omitted the framed emotion picture")
assert(#game.stack.pushed == 0,
  "native Pikachu interaction fell back to a generic follower TextBox")

-- Prove the public drawUI path still renders the engine's canonical 7x7
-- Pikachu window for that emote after Ascendant's portrait wrapper is active.
local Font = require("src.render.Font")
local realDrawBox = Font.drawBox
local realNewImage = love.graphics.newImage
local realSetColor = love.graphics.setColor
local realDraw = love.graphics.draw
local box, draws
Font.drawBox = function(x, y, w, h) box = { x, y, w, h } end
love.graphics.newImage = function()
  return { getDimensions = function() return 40, 40 end }
end
love.graphics.setColor = function() end
love.graphics.draw = function() draws = (draws or 0) + 1 end
Overworld.drawUI(ow)
Font.drawBox = realDrawBox
love.graphics.newImage = realNewImage
love.graphics.setColor = realSetColor
love.graphics.draw = realDraw

assert(box and box[1] == 6 and box[2] == 5
    and box[3] == 7 and box[4] == 7,
  "Pikachu emotion drawUI omitted the canonical 7x7 frame")
assert(draws == 1,
  "Pikachu emotion drawUI did not draw the resolved pikaPic")

run.release()
print(("yellow_pikachu_emotion_engine_test: PASS engine=%s edition=%s")
  :format(expectedEngine, edition))
