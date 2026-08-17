-- Narrative/status helpers for Kanto Ascendant's post-game events.

local PHASE_DIALOGUE = {
  master_gyms = "rumor",
  apex_elite = "apex",
  legend_hunt = "hunt",
  crown_gyms = "crown",
  crown_elite = "crown",
  complete = "complete",
}

local DISPLAY = {
  HO_OH = "HO-OH",
}

local MAP_NAMES = {
  en = {
    SEAFOAM_ISLANDS_B4F = "SEAFOAM ISLANDS",
    POWER_PLANT = "POWER PLANT",
    VICTORY_ROAD_2F = "VICTORY ROAD",
    CERULEAN_CAVE_B1F = "CERULEAN CAVE",
    POKEMON_TOWER_7F = "POKéMON TOWER",
    VIRIDIAN_FOREST = "VIRIDIAN FOREST",
  },
  de = {
    SEAFOAM_ISLANDS_B4F = "SEESCHAUMINSELN",
    POWER_PLANT = "KRAFTWERK",
    VICTORY_ROAD_2F = "SIEGESSTRASSE",
    CERULEAN_CAVE_B1F = "AZURIA-HÖHLE",
    POKEMON_TOWER_7F = "POKéMON-TURM",
    VIRIDIAN_FOREST = "VERTANIA-WALD",
  },
}

local function countKeys(bucket, rows, key)
  local count = 0
  bucket = type(bucket) == "table" and bucket or {}
  for _, row in ipairs(rows or {}) do
    if bucket[row[key]] then count = count + 1 end
  end
  return count
end

local function rematchCount(states)
  local count = 0
  for _, row in pairs(type(states) == "table" and states or {}) do
    count = count + math.max(0, math.floor(tonumber(row.rematches) or 0))
  end
  return count
end

return function(data, helpers)
  local E = {}
  local tr = helpers.tr
  local localized = helpers.localized
  local legendSetting = helpers.legendSetting
  local legendaryAvailable = helpers.legendaryAvailable
  local caught = helpers.caught
  local phaseFor = helpers.phaseFor
  local rivalIdentity = helpers.rivalIdentity

  local function currentRivalIdentity()
    if type(rivalIdentity) == "function" then
      local ok, identity = pcall(rivalIdentity)
      if ok and (identity == "RED" or identity == "GREEN") then
        return identity
      end
    end
    return "BLUE"
  end

  local function display(species)
    return DISPLAY[species] or species
  end

  local function isGerman()
    return tr("en", "de") == "de"
  end

  local function mapName(mapId)
    local lang = isGerman() and "de" or "en"
    return MAP_NAMES[lang][mapId]
      or tostring(mapId or "?"):gsub("_", " ")
  end

  function E.enabledLegendCount()
    local total = 0
    for _, species in ipairs(data.legendOrder or {}) do
      if legendSetting(species) ~= "off" then total = total + 1 end
    end
    return total
  end

  function E.caughtLegendCount(s, save)
    local total = 0
    for _, species in ipairs(data.legendOrder or {}) do
      if legendSetting(species) ~= "off" and caught(s, save, species) then
        total = total + 1
      end
    end
    return total
  end

  local function objective(s, save)
    local phase = phaseFor(s, save)
    if phase == "master_gyms" then
      local n = countKeys(s and s.masterWins, data.gyms, "key")
      return tr(
        ("Win the eight\nMASTER crests.\nProgress: %d/8"):format(n),
        ("Erringe die acht\nMEISTER-Wappen.\nFortschritt: %d/8"):format(n))
    elseif phase == "apex_elite" then
      return tr(
        "The seals react!\nDefeat the APEX\nELITE at INDIGO.",
        "Die Siegel reagieren!\nBesiege die APEX-\nLIGA am INDIGO.")
    elseif phase == "legend_hunt" then
      return tr(
        "Follow the sightings.\nFind LUGIA and\nHO-OH.",
        "Folge den Sichtungen.\nFinde LUGIA und\nHO-OH.")
    elseif phase == "crown_gyms" then
      local n = countKeys(s and s.crownWins, data.gyms, "key")
      return tr(
        ("Challenge the CROWN\nLEADERS.\nProgress: %d/8"):format(n),
        ("Fordere die KRONEN-\nLEITER heraus.\nFortschritt: %d/8"):format(n))
    elseif phase == "crown_elite" then
      return tr(
        "Return to INDIGO.\nThe final CROWN\nELITE awaits.",
        "Kehre zum INDIGO\nzurück. Die letzte\nKRONEN-LIGA wartet.")
    elseif phase == "complete" then
      return tr(
        "Research complete.\nKanto's legends\nrecognize you.",
        "Forschung beendet.\nKantos Legenden\nerkennen dich an.")
    end
    return tr(
      "Become Kanto's\nChampion first.",
      "Werde zuerst\nKantos Champ.")
  end

  local function locationFor(species, s)
    local row = data.staticLegends[species]
      or data.spawnedLegends[species]
      or data.roamers[species]
    if data.roamers[species] then
      return s and s.roamers and s.roamers[species]
    end
    return row and row.map
  end

  local function legendStatus(species, s, save)
    if legendSetting(species) == "off" then
      return tr("OFF", "AUS")
    end
    if caught(s, save, species) then
      return tr("CAUGHT", "GEFANGEN")
    end
    if legendaryAvailable(species, s, save) then
      local location = locationFor(species, s)
      return location and mapName(location) or tr("ROAMING", "WANDERT")
    end
    if species == "LUGIA" then
      return tr("NEEDS 3 BIRDS", "BRAUCHT 3 VÖGEL")
    elseif species == "HO_OH" then
      return tr("NEEDS 3 BEASTS", "BRAUCHT 3 BESTIEN")
    elseif species == "CELEBI" then
      return tr("NEEDS SKY PAIR", "BRAUCHT HIMMELSPAAR")
    end
    return tr("SEALED", "VERSIEGELT")
  end

  local function statusPage(title, speciesList, s, save)
    local rows = { title }
    for _, species in ipairs(speciesList) do
      rows[#rows + 1] = ("%s:\n%s"):format(
        display(species), legendStatus(species, s, save))
    end
    return table.concat(rows, "\n")
  end

  function E.researchLog(s, save)
    local caughtCount = E.caughtLegendCount(s, save)
    local enabledCount = E.enabledLegendCount()
    local pages = {
      tr(
        ("OAK RESEARCH LOG\nLEGENDS: %d/%d"):format(caughtCount, enabledCount),
        ("EICHS FORSCHUNGSLOG\nLEGENDEN: %d/%d"):format(caughtCount, enabledCount)),
      tr("CURRENT OBJECTIVE", "AKTUELLES ZIEL") .. "\n" .. objective(s, save),
      statusPage(tr("SKY READINGS", "HIMMELS-MESSUNG"),
        { "ARTICUNO", "ZAPDOS", "MOLTRES", "MEWTWO" }, s, save),
      statusPage(tr("ROAMING SIGNALS", "WANDER-SIGNALE"),
        { "RAIKOU", "ENTEI", "SUICUNE" }, s, save),
      statusPage(tr("DEEP SIGNALS", "TIEFE SIGNALE"),
        { "LUGIA", "HO_OH", "CELEBI" }, s, save),
    }
    return table.concat(pages, "\f")
  end

  function E.trophyText(s, save, trainerStates)
    local master = countKeys(s and s.masterWins, data.gyms, "key")
    local crown = countKeys(s and s.crownWins, data.gyms, "key")
    local legends = E.caughtLegendCount(s, save)
    local enabled = E.enabledLegendCount()
    local yes, no = tr("YES", "JA"), tr("NO", "NEIN")
    return tr("KANTO ASCENDANT\nCROWN ARCHIVE",
        "KANTO ASCENDANT\nKRONEN-ARCHIV")
      .. ("\f%s: %d\n%s: %d/8"):format(
        tr("FIELD REMATCHES", "FELD-REVANCHEN"), rematchCount(trainerStates),
        tr("MASTER CRESTS", "MEISTER-WAPPEN"), master)
      .. ("\f%s: %s\n%s: %d/%d"):format(
        tr("APEX CHAMPION", "APEX-CHAMP"), s and s.apexChampion and yes or no,
        tr("LEGENDS", "LEGENDEN"), legends, enabled)
      .. ("\f%s: %d/8\n%s: %s"):format(
        tr("CROWN CRESTS", "KRONEN-WAPPEN"), crown,
        tr("RIVAL HUNT", "RIVALEN-JAGD"), s and s.huntRivalWon and yes or no)
      .. ("\f%s: %s"):format(
        tr("CROWN CHAMPION", "KRONEN-CHAMP"),
        s and s.crownChampion and yes or no)
  end

  function E.worldReaction(mapId, npcName, s, save)
    if not mapId or not npcName then return nil end
    if E.enabledLegendCount() == 0 then return nil end
    local root = data.dialogue and data.dialogue.world
      and data.dialogue.world[mapId .. ":" .. npcName]
    if not root then return nil end
    local phase = PHASE_DIALOGUE[phaseFor(s, save)] or "rumor"
    return localized(root[phase] or root.rumor)
  end

  function E.legendIntro(species)
    local row = data.dialogue and data.dialogue.legendIntros
      and data.dialogue.legendIntros[species]
    return localized(row)
  end

  function E.huntRivalDialogue(key)
    local row = data.dialogue and data.dialogue.huntRival
    local identityRow = row and row[currentRivalIdentity()]
    return row and localized((identityRow and identityRow[key]) or row[key])
      or nil
  end

  function E.huntRivalAvailable(s, save)
    return s and s.apexChampion and not s.huntRivalWon
      and E.enabledLegendCount() > 0 and E.caughtLegendCount(s, save) > 0
  end

  return E
end
