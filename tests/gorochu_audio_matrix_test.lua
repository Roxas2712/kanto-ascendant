-- Gorochu edition-audio matrix.
--
-- ROM-free: Red and Blue synthesize a portable Gen-I cry from the fixture's
-- Raichu chip program, while Yellow selects Ascendant's voiced WAV.
--
-- Run from the engine checkout:
--   POKEPORT_DATA_DIR=tests/fixture_data \
--   TRAINER_REMATCH_MOD_DIR=../gorochu-visual-quality \
--   ./.tools/luajit-src/src/luajit \
--     ../gorochu-visual-quality/tests/gorochu_audio_matrix_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local Sound = require("src.core.Sound")

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/trainer_rematch"

local function fixtureData()
  local data = T.fixtures.fresh()

  -- The three-species fixture deliberately omits Kanto. Gorochu only needs
  -- Raichu's content template and the six move ids referenced by its own
  -- registration.
  data.pokemon.RAICHU = {
    id = "RAICHU", index = 26, dex = 26, name = "RAICHU",
    types = { "ELECTRIC" },
    baseStats = {
      hp = 60, attack = 90, defense = 55, speed = 110, special = 90,
    },
    catchRate = 75, baseExp = 122,
    level1Moves = {}, growthRate = "MEDIUM_FAST", tmhm = {},
    learnset = {}, evolutions = {},
    spriteFront = "tests/fixture_data/assets/fixmon_a_front.png",
    spriteBack = "tests/fixture_data/assets/fixmon_a_back.png",
    frontSize = 6,
    dexEntry = {
      kind = "MOUSE", heightFt = 2, heightIn = 7, weight = 660,
      text = "A test Raichu.",
    },
  }
  for index, moveId in ipairs({
    "THUNDERSHOCK", "BITE", "THUNDER_WAVE",
    "AGILITY", "THUNDERBOLT", "THUNDER",
  }) do
    data.moves[moveId] = {
      id = moveId, index = 100 + index, name = moveId:gsub("_", " "),
      type = moveId == "BITE" and "NORMAL" or "ELECTRIC",
      power = (moveId == "THUNDER_WAVE" or moveId == "AGILITY")
        and 0 or 40,
      accuracy = 100, pp = 20, effect = "NO_ADDITIONAL_EFFECT",
    }
  end

  data.audio = data.audio or {}
  data.audio.cries = data.audio.cries or {}
  data.audio._owners = data.audio._owners or {}
  data.audio._owners.cries = data.audio._owners.cries or {}

  -- A tiny legal Game Boy program makes Sound.playCry exercise the real
  -- derived-cry synthesis path without any ROM-extracted audio.
  local seedChip = require("src.audio.ChipAsm").sfx{
    channels = { { hw = 1, program = {
      { squareNote = {
        len = 6, volume = 13, fade = 2, frequency = 0x500,
      } },
    } } },
  }.chip
  data.audio.cries.RAICHU = {
    chip = seedChip,
    pitch = 0x80,
    length = 0x80,
  }

  return data
end

local data = fixtureData()
GameVersion.set("red")
local run = T.sdk.loadMod(modPath, { data = data })
T.eq(#run.errors, 0, "the complete mod loads against ROM-free fixture data")

local gorochu = run.loader.exports.trainer_rematch.gorochu
T.neq(gorochu, nil, "the Gorochu controller is exported")
T.eq(gorochu.available, true, "the seeded Raichu enables Gorochu")
T.eq(gorochu.audio.primary:match("([^/]+)$"), "gorochu_cry.wav",
  "Yellow's primary Gorochu cry is the dedicated WAV")
T.same(gorochu.audio.fallback, {
  base = "RAICHU",
  pitch = 0x50,
  length = 0xB0,
}, "Red and Blue share the intended original-style Gen-I cry recipe")

local ownerId = run.mod.manifest.id
local owners = data.audio._owners.cries

local function definition()
  return data.audio.cries.GOROCHU
end

local function expectChip(label)
  T.same(definition(), {
    base = "RAICHU",
    pitch = 0x50,
    length = 0xB0,
  }, label .. " selects the portable Raichu-derived chip cry")
  T.eq(definition().file, nil,
    label .. " never falls through to a spoken-name file")
end

local function expectVoice(label)
  T.same(definition(), {
    file = gorochu.audio.primary,
  }, label .. " selects Ascendant's dedicated Gorochu WAV")
  T.eq(definition().base, nil,
    label .. " does not retain the Red/Blue chip definition")
end

-- Owner-aware edition switching on a single live registry. This mirrors a
-- launcher identity change or scripted QA selecting another concrete ROM
-- after the mod has already registered.
data.audio.cries.GOROCHU = nil
owners.GOROCHU = nil

local installed, preserved = gorochu.installAudio({ data = data })
T.eq(installed, 1, "Red installs a missing Gorochu cry")
T.eq(preserved, 0, "Red owns the previously empty cry slot")
T.eq(owners.GOROCHU, ownerId, "the Red definition records mod ownership")
expectChip("Red")

local repeatedInstalled, repeatedPreserved =
  gorochu.installAudio({ data = data })
T.eq(repeatedInstalled, 0, "repeating Red is idempotent")
T.eq(repeatedPreserved, 1, "repeating Red preserves the identical definition")
expectChip("Repeated Red")

GameVersion.set("blue")
installed, preserved = gorochu.installAudio({ data = data })
T.eq(installed, 0, "Blue reuses Red's identical owned chip recipe")
T.eq(preserved, 1, "Blue preserves the already correct owned definition")
expectChip("Blue")

GameVersion.set("yellow")
installed, preserved = gorochu.installAudio({ data = data })
T.eq(installed, 1, "Yellow replaces Ascendant's own Red/Blue fallback")
T.eq(preserved, 0, "Yellow does not treat the owned fallback as external")
T.eq(owners.GOROCHU, ownerId, "Yellow retains Ascendant's ownership marker")
expectVoice("Yellow")

repeatedInstalled, repeatedPreserved =
  gorochu.installAudio({ data = data })
T.eq(repeatedInstalled, 0, "repeating Yellow is idempotent")
T.eq(repeatedPreserved, 1,
  "repeating Yellow preserves the identical voiced definition")
expectVoice("Repeated Yellow")

GameVersion.set("red")
installed, preserved = gorochu.installAudio({ data = data })
T.eq(installed, 1, "returning to Red restores the owned Gen-I chip recipe")
T.eq(preserved, 0, "returning to Red replaces only Ascendant's own WAV")
expectChip("Red after Yellow")

-- A cry supplied by another mod remains authoritative in every edition.
local external = { file = "mods/crystal_cries/gorochu_external.ogg" }
data.audio.cries.GOROCHU = external
owners.GOROCHU = "crystal_cries"
for _, version in ipairs({ "red", "blue", "yellow" }) do
  GameVersion.set(version)
  installed, preserved = gorochu.installAudio({ data = data })
  T.eq(installed, 0, version .. " does not overwrite an external Gorochu cry")
  T.eq(preserved, 1, version .. " reports the external cry as preserved")
  T.eq(data.audio.cries.GOROCHU, external,
    version .. " preserves the external definition by identity")
  T.eq(owners.GOROCHU, "crystal_cries",
    version .. " preserves the external owner")
end

-- Sound.playCry smoke-tests both runtime branches. The audio stub accepts
-- generated SoundData as well as file paths and records which one was used.
local oldAudio = love.audio
local sources = {}
local function newSource(payload, mode)
  local source = {
    payload = payload,
    mode = mode,
    plays = 0,
  }
  function source:setVolume(value) self.volume = value end
  function source:stop() self.stopped = true end
  function source:play() self.plays = self.plays + 1 end
  function source:setPitch(value) self.pitch = value end
  sources[#sources + 1] = source
  return source
end
love.audio = { newSource = newSource }

data.audio.cries.GOROCHU = nil
owners.GOROCHU = nil
for _, row in ipairs({
  { version = "red", kind = "chip" },
  { version = "blue", kind = "chip" },
  { version = "yellow", kind = "file" },
}) do
  GameVersion.set(row.version)
  gorochu.installAudio({ data = data })
  Sound.invalidate("cry:GOROCHU")
  local before = #sources
  local source = Sound.playCry(data, "GOROCHU")
  T.neq(source, nil, row.version .. " produces a playable Gorochu source")
  T.eq(#sources, before + 1,
    row.version .. " resolves a fresh source through Sound.playCry")
  T.eq(source.plays, 1, row.version .. " starts the resolved cry")
  if row.kind == "chip" then
    T.eq(type(source.payload), "table",
      row.version .. " renders chip synthesis into SoundData")
  else
    T.eq(source.payload, gorochu.audio.primary,
      "Yellow loads the dedicated Gorochu WAV path")
  end
end

Sound.invalidate()
love.audio = oldAudio
run.release()
GameVersion.set("red")

T.finish("gorochu_audio_matrix")
