-- Historical type projection for KASC's selectable battle eras.
--
-- This module is intentionally pure.  It never edits a Pokemon record and
-- therefore remains safe for save migration, previews, Voxel and tests.  The
-- generation_rules controller is the sole owner of applying a resolved view
-- to live battle data at a safe boundary.

local M = {}

local INTRODUCED = {
  DARK = 2,
  STEEL = 2,
  FAIRY = 6,
}

local PHYSICAL_BEFORE_GEN4 = {
  NORMAL = true, FIGHTING = true, FLYING = true, POISON = true,
  GROUND = true, ROCK = true, BUG = true, GHOST = true, STEEL = true,
}

-- Species which lose a later type need an authored historical identity.
-- Values are deliberately keyed by canonical species id, not display name.
local GEN1_SPECIES = {
  MAGNEMITE = { "ELECTRIC" }, MAGNETON = { "ELECTRIC" },
  HOUNDOUR = { "FIRE" }, HOUNDOOM = { "FIRE" },
  MURKROW = { "FLYING" }, HONCHKROW = { "FLYING" },
  SNEASEL = { "ICE" }, WEAVILE = { "ICE" },
  LARVITAR = { "ROCK", "GROUND" }, PUPITAR = { "ROCK", "GROUND" },
  TYRANITAR = { "ROCK" },
  SCIZOR = { "BUG" }, STEELIX = { "GROUND" },
  SKARMORY = { "FLYING" }, FORRETRESS = { "BUG" },
  UMBREON = { "NORMAL" },
}

local PRE_FAIRY_SPECIES = {
  CLEFFA = { "NORMAL" }, CLEFAIRY = { "NORMAL" }, CLEFABLE = { "NORMAL" },
  IGGLYBUFF = { "NORMAL" }, JIGGLYPUFF = { "NORMAL" },
  WIGGLYTUFF = { "NORMAL" }, TOGEPI = { "NORMAL" },
  TOGETIC = { "NORMAL", "FLYING" }, TOGEKISS = { "NORMAL", "FLYING" },
  AZURILL = { "NORMAL" }, MARILL = { "WATER" }, AZUMARILL = { "WATER" },
  RALTS = { "PSYCHIC_TYPE" }, KIRLIA = { "PSYCHIC_TYPE" },
  GARDEVOIR = { "PSYCHIC_TYPE" },
  MR_MIME = { "PSYCHIC_TYPE" }, MIME_JR = { "PSYCHIC_TYPE" },
  MAWILE = { "STEEL" }, COTTONEE = { "GRASS" },
  WHIMSICOTT = { "GRASS" },
  FLABEBE = { "NORMAL" }, FLOETTE = { "NORMAL" }, FLORGES = { "NORMAL" },
  SYLVEON = { "NORMAL" },
}

-- A native Gen-I baseline is not necessarily a modern type list. Filtering
-- it backwards alone leaves e.g. Clefairy Normal forever. Explicit forward
-- transitions are just as necessary; these canonical identities do not
-- replace regional/temporary forms. Matches backend national source types.
local FAIRY_SPECIES = {
  CLEFFA={"FAIRY"}, CLEFAIRY={"FAIRY"}, CLEFABLE={"FAIRY"},
  IGGLYBUFF={"NORMAL","FAIRY"}, JIGGLYPUFF={"NORMAL","FAIRY"},
  WIGGLYTUFF={"NORMAL","FAIRY"}, TOGEPI={"FAIRY"},
  TOGETIC={"FAIRY","FLYING"}, TOGEKISS={"FAIRY","FLYING"},
  AZURILL={"NORMAL","FAIRY"}, MARILL={"WATER","FAIRY"}, AZUMARILL={"WATER","FAIRY"},
  RALTS={"PSYCHIC_TYPE","FAIRY"}, KIRLIA={"PSYCHIC_TYPE","FAIRY"},
  GARDEVOIR={"PSYCHIC_TYPE","FAIRY"}, MR_MIME={"PSYCHIC_TYPE","FAIRY"},
  MIME_JR={"PSYCHIC_TYPE","FAIRY"}, MAWILE={"STEEL","FAIRY"},
  COTTONEE={"GRASS","FAIRY"}, WHIMSICOTT={"GRASS","FAIRY"},
}

local function copy(values)
  local out = {}
  for index, value in ipairs(type(values) == "table" and values or {}) do
    out[index] = value
  end
  return out
end

local function normalizedSpecies(value)
  return type(value) == "string" and value:upper() or tostring(value or "")
end

function M.typeAvailable(typeId, epoch)
  typeId = type(typeId) == "string" and typeId:upper() or typeId
  epoch = math.max(1, math.floor(tonumber(epoch) or 1))
  return (INTRODUCED[typeId] or 1) <= epoch
end

function M.projectSpecies(species, types, epoch)
  epoch = math.max(1, math.floor(tonumber(epoch) or 1))
  local key = normalizedSpecies(species)
  if epoch == 1 and GEN1_SPECIES[key] then
    return copy(GEN1_SPECIES[key]), "species_gen1"
  end
  if epoch >= 2 and (key == 'MAGNEMITE' or key == 'MAGNETON') then
    return { 'ELECTRIC', 'STEEL' }, 'species_steel'
  end
  if epoch >= 6 and FAIRY_SPECIES[key] then
    return copy(FAIRY_SPECIES[key]), 'species_fairy'
  end
  if epoch < 6 and PRE_FAIRY_SPECIES[key] then
    local projected = {}
    for _, typeId in ipairs(PRE_FAIRY_SPECIES[key]) do
      if M.typeAvailable(typeId, epoch) then projected[#projected + 1] = typeId end
    end
    if #projected > 0 then return projected, "species_pre_fairy" end
  end

  local projected, seen = {}, {}
  for _, typeId in ipairs(type(types) == "table" and types or {}) do
    typeId = type(typeId) == "string" and typeId:upper() or typeId
    if M.typeAvailable(typeId, epoch) and not seen[typeId] then
      projected[#projected + 1], seen[typeId] = typeId, true
    end
  end
  if #projected == 0 then
    return { "NORMAL" }, "explicit_normal_fallback"
  end
  return projected, "filtered"
end

function M.moveType(moveId, typeId, epoch)
  moveId = type(moveId) == "string" and moveId:upper() or moveId
  epoch = math.max(1, math.floor(tonumber(epoch) or 1))
  if moveId == "BITE" then return epoch == 1 and "NORMAL" or "DARK" end
  if moveId == "KARATE_CHOP" then return epoch == 1 and "NORMAL" or "FIGHTING" end
  if moveId == "GUST" then return epoch == 1 and "NORMAL" or "FLYING" end
  if moveId == "SAND_ATTACK" then return epoch == 1 and "NORMAL" or "GROUND" end
  if M.typeAvailable(typeId, epoch) then return typeId end
  return "NORMAL"
end

function M.moveCategory(moveId, typeId, category, epoch)
  category = type(category) == "string" and category:lower() or category
  if category == "status" then return "status" end
  epoch = math.max(1, math.floor(tonumber(epoch) or 1))
  typeId = M.moveType(moveId, typeId, epoch)
  if epoch < 4 then
    return PHYSICAL_BEFORE_GEN4[typeId] and "physical" or "special"
  end
  return category or "physical"
end

M.introduced = INTRODUCED
M.gen1Species = GEN1_SPECIES
M.preFairySpecies = PRE_FAIRY_SPECIES

return M
