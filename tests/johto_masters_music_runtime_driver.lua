-- Bounded LÖVE receipt: synthesize both source-bound programs, then exercise
-- map -> trainer battle -> map restoration through the real audio frontend.
return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL")))
  local resultPath = assert(os.getenv("KA_JOHTO_MUSIC_RESULT"))
  local Runtime = require("src.mods.Runtime")
  local Music = require("src.core.Music")
  local ChipAudio = require("src.core.ChipAudio")
  local mapId = "KA_JOHTO_GATE_HALL"
  local mapSong = "Music_KA_GSC_IndigoPlateau"
  local battleSong = "Music_KA_GSC_RivalBattle"
  local indigo = assert(game.data.audio.songs[mapSong])
  local rival = assert(game.data.audio.songs[battleSong])

  local function energy(definition, channel)
    local sound = ChipAudio._renderMusicChannelForTest(
      game.data, definition, 0.35, channel)
    local total = 0
    for index = 0, sound:getSampleCount() - 1 do
      total = total + math.abs(sound:getSample(index))
    end
    return total
  end

  local indigoEnergy = energy(indigo, 1)
  local rivalEnergy = energy(rival, 1)
  assert(indigoEnergy > 1 and rivalEnergy > 1,
    "Johto runtime synthesis was silent")

  local owner = "ka_johto_music_runtime_receipt"
  local started = {}
  Runtime.events:on("music.started", function(payload)
    started[#started + 1] = payload
  end, nil, owner)
  local errorsBefore = Runtime.errors and #Runtime.errors or 0

  Music.reload()
  Music.playMap(game.data, mapId, false, false)
  for _ = 1, 300 do
    if not ChipAudio.awaitingFirstBuffer() then break end
    U.wait(1)
  end
  assert(not ChipAudio.awaitingFirstBuffer(),
    "Indigo map theme never received its first worker buffer")
  assert(started[#started] and started[#started].song == mapSong
    and started[#started].reason == "map")

  Music.playBattle(game.data, "trainer", "KA_JOHTO_SILVER")
  for _ = 1, 300 do
    if not ChipAudio.awaitingFirstBuffer() then break end
    U.wait(1)
  end
  assert(not ChipAudio.awaitingFirstBuffer(),
    "Rival battle theme never received its first worker buffer")
  assert(started[#started] and started[#started].song == battleSong
    and started[#started].reason == "battle")
  assert(started[#started].previous == mapSong)

  Music.restoreMap(game.data)
  for _ = 1, 300 do
    if not ChipAudio.awaitingFirstBuffer() then break end
    U.wait(1)
  end
  assert(not ChipAudio.awaitingFirstBuffer(),
    "restored Indigo theme never received its first worker buffer")
  -- restoreMap deliberately clears the battle label before replaying the
  -- retained mapSong, so the restored event's `previous` field is nil.  The
  -- audible contract is the selected map song plus a completed first buffer.
  assert(started[#started] and started[#started].song == mapSong
    and started[#started].previous == nil)
  assert((Runtime.errors and #Runtime.errors or 0) == errorsBefore,
    "runtime audio added a loader error")

  Runtime.events:removeOwner(owner)
  Music.stop()
  local result = ("PASS\nmap=%s\nbattle=%s\nrestore=%s\n"
    .. "indigo_channel1_energy=%.6f\nrival_channel1_energy=%.6f\n")
    :format(mapSong, battleSong, mapSong, indigoEnergy, rivalEnergy)
  local file = assert(io.open(resultPath, "wb"))
  file:write(result)
  file:close()
  print("[driver] johto_masters_music_runtime: PASS")
  U.wait(2)
  love.event.quit(0)
end
