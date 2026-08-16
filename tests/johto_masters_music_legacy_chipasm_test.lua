-- Compatibility regression for the released ChipAsm contract.  The wrapper
-- deliberately rejects any raw source drum rows, exactly as older engines do;
-- johto_masters_music must still load by attaching precompiled segments only
-- after the two songs have assembled.
local engine = assert(os.getenv("GEN1RECOMP_DIR"))
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local realChipAsm = require("src.audio.ChipAsm")
local calls = 0
package.loaded["src.audio.ChipAsm"] = {
  song = function(spec)
    assert(spec.drums == nil,
      "raw full-byte Gen-II drum rows leaked into released ChipAsm")
    calls = calls + 1
    return realChipAsm.song(spec)
  end,
}

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
local controller = make(mod)
assert(calls == 2, "both Johto songs assemble through released ChipAsm")
local indigo = assert(controller.definitions[controller.mapTheme])
assert(indigo.chip.drums and indigo.chip.drums[0])
assert(indigo.chip.drums[0][1].endSample
  == math.floor((32 * 256 * 1470 + 256) / 512),
  "full 32-tick source drum duration is preserved")
assert(controller.register())
assert(music.values[controller.mapTheme] == indigo)
assert(mapSongs.values.KA_JOHTO_GATE_HALL == controller.mapTheme)

package.loaded["src.audio.ChipAsm"] = realChipAsm
print("johto_masters_music_legacy_chipasm_test: PASS")
