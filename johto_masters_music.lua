-- Source-bound Johto Masters music.  The checked-in data is generated from
-- the pinned local pret/pokecrystal ASM; no OGG, download or invented melody
-- participates in this registration.
return function(mod)
  local body, readErr = mod:read("johto_masters_music_data.lua")
  local chunk, compileErr = body and loadstring(body,
    "@" .. mod.path .. "/johto_masters_music_data.lua") or nil
  assert(chunk, compileErr or readErr)
  local source = chunk()
  local ChipAsm = require("src.audio.ChipAsm")

  -- pokecrystal's noise_note duration is a full byte.  Released ChipAsm
  -- versions accepted only 1..16 while the source drumkit legitimately uses
  -- longer rows (32..39).  Compile those rows here into the exact segment
  -- representation consumed by ChipSynth instead of requiring an engine
  -- upgrade or shortening/retriggering the original drums.
  local FRAME_TICKS = 256
  local function snapTicks(ticks)
    return math.floor((ticks * 1470 + 256) / 512)
  end

  local function compileDrums(rows)
    local drums = {}
    for id, program in pairs(rows) do
      local segments, ticks = {}, 0
      for index, row in ipairs(program) do
        local length = row.len or 1
        assert(type(length) == "number" and length == math.floor(length)
          and length >= 1 and length <= 255,
          ("Johto drum %s row %d has invalid duration")
            :format(tostring(id), index))
        local duration = length * FRAME_TICKS
        segments[#segments + 1] = {
          startSample = snapTicks(ticks),
          endSample = snapTicks(ticks + duration),
          volume = row.volume or 0,
          fade = row.fade or 0,
          parameter = row.parameter or 0,
        }
        ticks = ticks + duration
      end
      drums[id] = segments
    end
    return drums
  end

  local function assembleSong(spec, drums)
    -- Do not pass source drum rows into ChipAsm: older released engines
    -- reject full-byte noise_note durations before the mod can load.
    local definition = ChipAsm.song(spec)
    if drums then definition.chip.drums = compileDrums(drums) end

    -- Preserve optional Gen-II tuning/stereo metadata on newer engines while
    -- remaining harmless on older ones that simply ignore these fields.
    for index, channel in ipairs(spec.channels or {}) do
      local built = definition.chip.channels[index]
      if built then
        built.frequencyOffset = channel.frequencyOffset
        built.panLeft = channel.panLeft
        built.panRight = channel.panRight
      end
    end
    return definition
  end

  local M = {
    mapTheme = "Music_KA_GSC_IndigoPlateau",
    battleTheme = "Music_KA_GSC_RivalBattle",
    provenance = source.provenance,
    mapIds = {
      "KA_JOHTO_GATE_HALL",
      "KA_JOHTO_SILVER_PASSAGE", "KA_JOHTO_SILVER_FINALE",
      "KA_JOHTO_KRIS_PASSAGE", "KA_JOHTO_KRIS_FINALE",
      "KA_JOHTO_GOLD_PASSAGE", "KA_JOHTO_GOLD_FINALE",
    },
  }

  local indigoSpec = source.songs.indigo
  indigoSpec.waves = source.waves
  local indigoDrums = assert(source.drumkits[0], "GSC drumkit 0 missing")
  local rivalSpec = source.songs.rival
  rivalSpec.waves = source.waves
  M.definitions = {
    [M.mapTheme] = assembleSong(indigoSpec, indigoDrums),
    [M.battleTheme] = assembleSong(rivalSpec),
  }

  local function registerOnce(registry, id, value, what)
    local current = registry.get and registry:get(id) or nil
    if current ~= nil then
      assert(current == value, ("Johto music %s conflict: %s"):format(what, id))
      return false
    end
    registry:register(id, value)
    return true
  end

  function M.register()
    for id, definition in pairs(M.definitions) do
      registerOnce(mod.content.music, id, definition, "song")
    end
    for _, mapId in ipairs(M.mapIds) do
      registerOnce(mod.content.map_songs, mapId, M.mapTheme, "map assignment")
    end
    return true
  end

  return M
end
