-- Dedicated 128px FULL-Voxel opponent standees.
--
-- Native 2D uses the edition-original Gen-I trainer fronts. This table is
-- presentation-only and prevents a Voxel renderer from enlarging those
-- compact cards into pale or low-detail FULL-Voxel standees.

return function(mod)
  local M = {}
  local ROOT = "assets/characters/frlg_trainers/"
  local function versionFor(classId)
    -- Oak's CURRENT pair won the explicit user approval.  Every other
    -- ordinary Kanto trainer uses the approved versioned V2 redraw.
    return classId == "OPP_PROF_OAK" and "v1" or "v2"
  end
  local STEMS = {
    OPP_BEAUTY = "beauty",
    OPP_BIKER = "biker",
    OPP_BIRD_KEEPER = "bird_keeper",
    OPP_BLACKBELT = "black_belt",
    OPP_BLAINE = "leader_blaine",
    OPP_BROCK = "leader_brock",
    OPP_BUG_CATCHER = "bug_catcher",
    OPP_BURGLAR = "burglar",
    OPP_CHANNELER = "channeler",
    OPP_COOLTRAINER_F = "cool_trainer_f",
    OPP_COOLTRAINER_M = "cool_trainer_m",
    OPP_CUE_BALL = "cue_ball",
    OPP_ENGINEER = "engineer",
    OPP_ERIKA = "leader_erika",
    OPP_FISHER = "fisherman",
    OPP_GAMBLER = "gamer",
    OPP_GENTLEMAN = "gentleman",
    OPP_GIOVANNI = "leader_giovanni",
    OPP_HIKER = "hiker",
    OPP_JR_TRAINER_F = "picnicker",
    OPP_JR_TRAINER_M = "camper",
    OPP_JUGGLER = "juggler",
    OPP_KOGA = "leader_koga",
    OPP_LASS = "lass",
    OPP_LT_SURGE = "leader_lt_surge",
    OPP_MISTY = "leader_misty",
    OPP_POKEMANIAC = "pokemaniac",
    OPP_PROF_OAK = "professor_oak",
    OPP_PSYCHIC_TR = "psychic_m",
    OPP_ROCKER = "rocker",
    OPP_ROCKET = "rocket_grunt_m",
    OPP_SABRINA = "leader_sabrina",
    OPP_SAILOR = "sailor",
    OPP_SCIENTIST = "scientist",
    OPP_SUPER_NERD = "super_nerd",
    OPP_SWIMMER = "swimmer_m",
    OPP_TAMER = "tamer",
    OPP_YOUNGSTER = "youngster",
  }

  local function spec(classId, stem)
    local version = versionFor(classId)
    return {
      id = "KANTO_" .. classId:gsub("^OPP_", ""),
      class = classId,
      path = ROOT .. stem .. "_voxel_front_hd_" .. version .. ".png",
      fallback = ROOT .. stem .. "_voxel_front_" .. version .. ".png",
      authored = true,
      approvedVersion = version,
    }
  end

  function M.spec(classId)
    if classId == "KA_OAK_BETA" then classId = "OPP_PROF_OAK" end
    local stem = STEMS[classId]
    if not stem then return nil end
    local result = spec(classId, stem)
    if classId == "OPP_PROF_OAK" then result.id = "KANTO_PROFESSOR_OAK" end
    return result
  end

  M.stems = STEMS
  M.count = 38
  return M
end
