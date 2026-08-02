-- Gen-II legendary content expressed through the native Gen1 Recomp content
-- registries.  It is activated only on a full Kanto data set; the tiny
-- ROM-free CI fixture deliberately skips it while still testing progression.

local function dexEntry(kind, ft, inches, weight, text)
  return {
    kind = kind, heightFt = ft, heightIn = inches, weight = weight,
    text = text,
  }
end

return function(mod, data)
  if not mod.content.pokemon:get("MEWTWO") then return false end
  local ChipAsm = require("src.audio.ChipAsm")

  mod.content.moves:register("SACRED_FIRE", {
    id = "SACRED_FIRE", name = "SACRED FIRE", type = "FIRE",
    power = 100, accuracy = 95, pp = 5, effect = "BURN_SIDE_EFFECT1",
    category = "special",
  })
  mod.content.moves:register("AEROBLAST", {
    id = "AEROBLAST", name = "AEROBLAST", type = "FLYING",
    power = 100, accuracy = 95, pp = 5, effect = "NO_ADDITIONAL_EFFECT",
    category = "physical", highCrit = true,
  })

  local entries = {
    RAIKOU = dexEntry("THUNDER", 6, 3, 3920,
      "It races across\nthe land while\ncalling the storm."),
    ENTEI = dexEntry("VOLCANO", 6, 11, 4370,
      "Its roar is said\nto make volcanoes\nerupt."),
    SUICUNE = dexEntry("AURORA", 6, 7, 4120,
      "It runs across\nthe world to purify\npolluted water."),
    LUGIA = dexEntry("DIVING", 17, 1, 4760,
      "It sleeps deep in\nthe sea to contain\nits great power."),
    HO_OH = dexEntry("RAINBOW", 12, 6, 4390,
      "Its brilliant wings\nleave a rainbow in\ntheir wake."),
    CELEBI = dexEntry("TIME TRAVEL", 2, 0, 110,
      "It crosses time and\nappears where a\nbright future waits."),
  }

  local tmhm = {
    "TOXIC", "BODY_SLAM", "DOUBLE_EDGE", "HYPER_BEAM", "PAY_DAY",
    "SUBMISSION", "COUNTER", "SEISMIC_TOSS", "RAGE", "MIMIC",
    "DOUBLE_TEAM", "REFLECT", "BIDE", "REST", "SUBSTITUTE",
  }
  local artNames = {
    RAIKOU = "raikou", ENTEI = "entei", SUICUNE = "suicune",
    LUGIA = "lugia", HO_OH = "ho_oh", CELEBI = "celebi",
  }

  for id, def in pairs(data.species) do
    local art = artNames[id]
    local speciesTmhm = {}
    for _, move in ipairs(tmhm) do speciesTmhm[#speciesTmhm + 1] = move end
    if id == "RAIKOU" then
      speciesTmhm[#speciesTmhm + 1] = "THUNDERBOLT"
      speciesTmhm[#speciesTmhm + 1] = "THUNDER"
    elseif id == "ENTEI" or id == "HO_OH" then
      speciesTmhm[#speciesTmhm + 1] = "FIRE_BLAST"
    elseif id == "SUICUNE" or id == "LUGIA" then
      speciesTmhm[#speciesTmhm + 1] = "SURF"
      speciesTmhm[#speciesTmhm + 1] = "BLIZZARD"
    elseif id == "CELEBI" then
      speciesTmhm[#speciesTmhm + 1] = "PSYCHIC_M"
      speciesTmhm[#speciesTmhm + 1] = "MEGA_DRAIN"
    end

    -- Self-contained chip cries keep the expansion valid even when the
    -- optional imported audio table is absent.
    local cryFrequency = 0x380 + (def.dex - 151) * 0x55
    mod.content.cries:register(id, {
      chip = ChipAsm.sfx{
        channels = { { hw = 1, program = {
          { pitchSweep = {
            pace = 2 + ((def.dex - 151) % 5),
            subtract = def.dex % 2 == 0, shift = 3,
          } },
          { squareNote = {
            len = 5 + ((def.dex - 151) % 3), volume = 13, fade = 2,
            frequency = cryFrequency,
          } },
        } } },
      }.chip,
      pitch = def.pitch, length = def.length,
    })
    mod.content.pokemon:register(id, {
      id = id, name = def.name, dex = def.dex, types = def.types,
      baseStats = def.stats, catchRate = def.catchRate, baseExp = def.baseExp,
      growthRate = "SLOW", level1Moves = def.level1,
      tmhm = speciesTmhm, learnset = def.learnset, evolutions = {},
      spriteFront = mod.path .. "/assets/" .. art .. "_front.png",
      spriteBack = mod.path .. "/assets/" .. art .. "_back.png",
      frontSize = 7, cry = id, battleScaleBack = 1,
      icon = { image = mod.path .. "/assets/" .. art .. "_icon.png", frames = 1 },
      dexEntry = entries[id],
    })
    mod.content.icons:register(id, {
      image = mod.path .. "/assets/" .. art .. "_icon.png", frames = 1,
    })
  end

  mod.content.constants:patch("dexSize", 157)
  mod.content.constants:patch("dexDigits", 3)
  return true
end
