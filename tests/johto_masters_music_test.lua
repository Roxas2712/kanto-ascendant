local engine = assert(os.getenv("GEN1RECOMP_DIR"))
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local function registry()
  local values = {}
  return {
    values = values,
    get = function(_, id) return values[id] end,
    register = function(_, id, value)
      assert(values[id] == nil, "duplicate " .. id)
      values[id] = value
    end,
  }
end

local music, mapSongs = registry(), registry()
local mod = {
  path = ".",
  content = { music = music, map_songs = mapSongs },
}
function mod:read(path)
  local file = assert(io.open(path, "rb"))
  local raw = file:read("*a")
  file:close()
  return raw
end

local make = assert(loadfile("johto_masters_music.lua"))()
local source = make(mod)
assert(source.provenance.project == "pret/pokecrystal")
assert(source.provenance.commit == "8e8f7e20052a596371a77022f0392c285e51bbf1")
assert(source.register())

local indigo = assert(music.values.Music_KA_GSC_IndigoPlateau)
local rival = assert(music.values.Music_KA_GSC_RivalBattle)
assert(indigo.chip and #indigo.chip.channels == 4 and #indigo.chip.blob > 100)
assert(rival.chip and #rival.chip.channels == 3 and #rival.chip.blob > 500)
assert(not indigo.file and not rival.file, "Johto tracks must stay chip-only")
assert(indigo.chip.channels[1].frequencyOffset == 2)
assert(indigo.chip.channels[1].panLeft == false
  and indigo.chip.channels[1].panRight == true)
assert(indigo.chip.drums[3] and indigo.chip.drums[3][1].endSample > 0)
assert(indigo.chip.waves and #indigo.chip.waves == 10)
-- The pinned Gen-II source contains full-byte 32..39-tick drum rows.  They
-- must survive at their full duration without being passed through (and
-- rejected by) legacy ChipAsm's 1..16 row validator.
local sourceDrum = assert(indigo.chip.drums[0])
assert(sourceDrum[1].startSample == 0)
assert(sourceDrum[1].endSample == math.floor((32 * 256 * 1470 + 256) / 512))
assert(sourceDrum[1].volume == 1 and sourceDrum[1].fade == 1)

local expected = {
  KA_JOHTO_GATE_HALL = true,
  KA_JOHTO_SILVER_PASSAGE = true, KA_JOHTO_SILVER_FINALE = true,
  KA_JOHTO_KRIS_PASSAGE = true, KA_JOHTO_KRIS_FINALE = true,
  KA_JOHTO_GOLD_PASSAGE = true, KA_JOHTO_GOLD_FINALE = true,
}
local count = 0
for mapId, songId in pairs(mapSongs.values) do
  assert(expected[mapId], "music leaked to unrelated map " .. mapId)
  assert(songId == "Music_KA_GSC_IndigoPlateau")
  count = count + 1
end
assert(count == 7, "all seven Johto hall/passage/finale maps need the theme")

-- Both programs construct and advance without a ROM wave/noise fallback.
local ChipSynth = require("src.core.ChipSynth")
for id, definition in pairs(music.values) do
  local engineState = ChipSynth.newEngine({ audio = {} }, definition,
    { allowLoops = false })
  for _, channel in ipairs(engineState.channels) do
    local events = 0
    while channel:nextEvent() do
      events = events + 1
      assert(events < 10000, id .. " channel did not terminate at loop gate")
    end
    assert(events > 0, id .. " contains an empty channel")
  end
  engineState = ChipSynth.newEngine({ audio = {} }, definition,
    { allowLoops = false })
  local audible = false
  for _ = 1, 20000 do
    if engineState:sample() ~= 0 then audible = true break end
  end
  assert(audible, id .. " did not synthesize an audible sample")
end

print("johto_masters_music_test: PASS")
