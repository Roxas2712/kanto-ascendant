-- Kanto Ascendant 5.0 research atlas.
--
-- The atlas deliberately reveals only information the save has already
-- earned: defeated trainers and seen Pokédex species.  It centralizes the
-- exact rematch loot table, TM queue, known habitats and the current research
-- objective without turning the discovery game into a spoiler list.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local postgame = opts.postgame
  local ascendant = opts.ascendant
  local fieldTech = opts.fieldTech
  local kantoCompletion = opts.kantoCompletion
  local johtoResearch = opts.johtoResearch
  local questTracker = opts.questTracker
  local lootBands = opts.lootBands or {}
  local trainerStates = opts.trainerStates
  local stepClock = opts.stepClock
  local data = opts.ascendantData or {}
  local A = { game = nil }

  local LEGENDARY = {
    ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true,
    MEW = true, RAIKOU = true, ENTEI = true, SUICUNE = true,
    LUGIA = true, HO_OH = true, CELEBI = true,
  }

  local SPECIAL_SOURCES = {
    BULBASAUR = { en = "MASTER ERIKA / WILD mode", de = "MEISTER ERIKA / WILD-Modus" },
    CHARMANDER = { en = "MASTER BLAINE / WILD mode", de = "MEISTER PYRO / WILD-Modus" },
    SQUIRTLE = { en = "MASTER MISTY / WILD mode", de = "MEISTER MISTY / WILD-Modus" },
    OMANYTE = { en = "Fossil restored after MASTER BROCK", de = "Fossil nach MEISTER ROCKO" },
    KABUTO = { en = "Fossil restored after MASTER BROCK", de = "Fossil nach MEISTER ROCKO" },
    AERODACTYL = { en = "Cinnabar fossil restoration", de = "Fossil-Restauration auf Zinnober" },
    MEW = { en = "Oak, Fuji and Cinnabar heritage finale", de = "Eich/Fuji/Zinnober-Finale" },
    GOROCHU = {
      en = "Raichu evolution research at the Power Plant",
      de = "Raichu-Entwicklungsforschung im Kraftwerk",
    },
  }

  local MAP_NAMES = {
    PALLET_TOWN = { en = "PALLET TOWN", de = "ALABASTIA" },
    VIRIDIAN_CITY = { en = "VIRIDIAN CITY", de = "VERTANIA CITY" },
    VIRIDIAN_FOREST = { en = "VIRIDIAN FOREST", de = "VERTANIA-WALD" },
    VIRIDIAN_GYM = { en = "VIRIDIAN GYM", de = "VERTANIA-ARENA" },
    PEWTER_GYM = { en = "PEWTER GYM", de = "MARMORIA-ARENA" },
    CERULEAN_CITY = { en = "CERULEAN CITY", de = "AZURIA CITY" },
    CERULEAN_GYM = { en = "CERULEAN GYM", de = "AZURIA-ARENA" },
    CERULEAN_CAVE_1F = { en = "CERULEAN CAVE 1F", de = "AZURIA-HÖHLE EG" },
    CERULEAN_CAVE_B1F = { en = "CERULEAN CAVE B1F", de = "AZURIA-HÖHLE UG1" },
    VERMILION_CITY = { en = "VERMILION CITY", de = "ORANIA CITY" },
    VERMILION_GYM = { en = "VERMILION GYM", de = "ORANIA-ARENA" },
    LAVENDER_TOWN = { en = "LAVENDER TOWN", de = "LAVANDIA" },
    CELADON_CITY = { en = "CELADON CITY", de = "PRISMANIA CITY" },
    CELADON_GYM = { en = "CELADON GYM", de = "PRISMANIA-ARENA" },
    CELADON_MANSION_3F = {
      en = "CELADON MANSION 3F", de = "PRISMANIA-VILLA 3F",
    },
    FUCHSIA_CITY = { en = "FUCHSIA CITY", de = "FUCHSANIA CITY" },
    FUCHSIA_GYM = { en = "FUCHSIA GYM", de = "FUCHSANIA-ARENA" },
    SAFFRON_GYM = { en = "SAFFRON GYM", de = "SAFFRONIA-ARENA" },
    CINNABAR_ISLAND = { en = "CINNABAR ISLAND", de = "ZINNOBERINSEL" },
    CINNABAR_GYM = { en = "CINNABAR GYM", de = "ZINNOBER-ARENA" },
    CINNABAR_LAB_FOSSIL_ROOM = {
      en = "CINNABAR LAB", de = "ZINNOBER-LABOR",
    },
    OAKS_LAB = { en = "OAK'S LAB", de = "EICHS LABOR" },
    MR_FUJIS_HOUSE = { en = "MR. FUJI'S HOUSE", de = "MR. FUJIS HAUS" },
    MT_MOON_B2F = { en = "MT. MOON B2F", de = "MONDBERG UG2" },
    DIGLETTS_CAVE = { en = "DIGLETT'S CAVE", de = "DIGDA-HÖHLE" },
    POWER_PLANT = { en = "POWER PLANT", de = "KRAFTWERK" },
    POKEMON_MANSION_B1F = {
      en = "POKéMON MANSION B1F", de = "POKéMON-HAUS UG1",
    },
    POKEMON_TOWER_7F = {
      en = "POKéMON TOWER 7F", de = "POKéMON-TURM 7F",
    },
    SEAFOAM_ISLANDS_B2F = {
      en = "SEAFOAM ISLANDS B2F", de = "SEESCHAUMINSELN UG2",
    },
    SEAFOAM_ISLANDS_B4F = {
      en = "SEAFOAM ISLANDS B4F", de = "SEESCHAUMINSELN UG4",
    },
    VICTORY_ROAD_1F = { en = "VICTORY ROAD 1F", de = "SIEGESSTRASSE 1F" },
    VICTORY_ROAD_2F = { en = "VICTORY ROAD 2F", de = "SIEGESSTRASSE 2F" },
    VICTORY_ROAD_3F = { en = "VICTORY ROAD 3F", de = "SIEGESSTRASSE 3F" },
    SAFARI_ZONE_CENTER = {
      en = "SAFARI ZONE CENTER", de = "SAFARI-ZONE ZENTRUM",
    },
    SAFARI_ZONE_EAST = {
      en = "SAFARI ZONE EAST", de = "SAFARI-ZONE OST",
    },
    SILPH_CO_11F = { en = "SILPH CO. 11F", de = "SILPH CO. 11F" },
    INDIGO_PLATEAU_LOBBY = {
      en = "INDIGO PLATEAU LOBBY", de = "INDIGO-PLATEAU-LOBBY",
    },
    HALL_OF_FAME = { en = "HALL OF FAME", de = "RUHMESHALLE" },
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function shownPercent(value)
    local text = ("%.2f"):format(tonumber(value) or 0)
      :gsub("0+$", ""):gsub("%.$", "")
    if i18n and i18n.isGerman and i18n.isGerman() then
      text = text:gsub("%.", ",")
    end
    -- The original Gen-1 font has no percent glyph. Use a compact explicit
    -- abbreviation instead of silently dropping the symbol on real hardware.
    return text .. tr(" PCT", " PROZ")
  end

  local function localized(row)
    if type(row) ~= "table" then return row end
    return tr(row.en or row.de or "", row.de or row.en or "")
  end

  local function clock()
    return stepClock and stepClock()
      or math.max(0, math.floor(tonumber(mod.save:get("step_clock", 0)) or 0))
  end

  local function states()
    return trainerStates and trainerStates()
      or (type(mod.save:get("trainers")) == "table"
        and mod.save:get("trainers") or {})
  end

  local function cleanMapName(game, mapId)
    local route = tostring(mapId or ""):match("^ROUTE_(%d+)$")
    if route then return "ROUTE " .. route end
    local localizedName = MAP_NAMES[mapId]
    if localizedName then return localized(localizedName) end
    local def = game and game.data and game.data.maps
      and game.data.maps[mapId]
    local name = def and (def.name or def.label)
    if type(name) == "string" and name ~= "" then
      return name:gsub("^_+", ""):gsub("Text$", ""):gsub("_", " ")
        :gsub("(%u)(%u%l)", "%1 %2"):gsub("(%l)(%u)", "%1 %2")
    end
    return tostring(mapId or tr("UNKNOWN", "UNBEKANNT")):gsub("_", " ")
  end

  local function trainerLocation(key, state)
    if state and state.mapId then return state.mapId end
    return tostring(key):match("^(.-)_obj_%d+$")
  end

  local function trainerLabel(key, state)
    if state and state.trainerName and state.trainerName ~= "" then
      return state.trainerName
    end
    local class = state and state.trainerClass
    if class then return tostring(class):gsub("^OPP_", ""):gsub("_", " ") end
    return tostring(key):gsub("_obj_%d+$", ""):gsub("_", " ")
  end

  local function rankFor(state)
    local progress = math.max(0, math.floor(tonumber(state.rematches) or 0))
      + math.max(0, math.floor(tonumber(state.trainingCycles) or 0))
    if ascendant and ascendant.rematchRank then
      return ascendant.rematchRank(progress), progress
    end
    return { key = "rookie", name = { en = "ROOKIE", de = "NEULING" } },
      progress
  end

  local function trainerRows(game)
    local rows = {}
    local now = clock()
    for key, state in pairs(states()) do
      if type(state) == "table"
          and (state.readyAt or tonumber(state.rematches)
            or (game.save.defeatedTrainers
              and game.save.defeatedTrainers[key])) then
        local readyAt = tonumber(state.readyAt)
        local remaining = readyAt
          and math.max(0, math.floor(readyAt - now)) or 0
        rows[#rows + 1] = {
          label = trainerLabel(key, state),
          right = remaining == 0 and tr("READY", "BEREIT")
            or tostring(remaining),
          value = { key = key, state = state, remaining = remaining },
        }
      end
    end
    table.sort(rows, function(a, b)
      if a.value.remaining ~= b.value.remaining then
        return a.value.remaining < b.value.remaining
      end
      return a.label < b.label
    end)
    if #rows == 0 then
      rows[1] = {
        label = tr("NO TRAINERS RECORDED", "KEINE TRAINER ERFASST"),
        value = false,
      }
    end
    return rows
  end

  local function trainerDetails(game, row)
    local state, key = row.state, row.key
    local rank, progress = rankFor(state)
    local readyAt = tonumber(state.readyAt)
    local remaining = readyAt
      and math.max(0, math.floor(readyAt - clock())) or 0
    local location = cleanMapName(game, trainerLocation(key, state))
    local status = remaining == 0 and tr("READY", "BEREIT")
      or tr(("%d steps"):format(remaining),
        ("%d Schritte"):format(remaining))
    local pages = {
      trainerLabel(key, state)
        .. "\n" .. tr("LOCATION: ", "ORT: ") .. location,
      tr("STATUS: ", "STATUS: ") .. status
        .. "\n" .. tr("RANK: ", "RANG: ") .. localized(rank.name),
      tr(("REMATCHES: %d\nTRAINING TIERS: %d"):format(
          math.max(0, math.floor(tonumber(state.rematches) or 0)),
          math.max(0, math.floor(tonumber(state.trainingCycles) or 0))),
        ("REVANCHEN: %d\nTRAININGSSTUFEN: %d"):format(
          math.max(0, math.floor(tonumber(state.rematches) or 0)),
          math.max(0, math.floor(tonumber(state.trainingCycles) or 0)))),
      tr(("TOTAL GROWTH: %d"):format(progress),
        ("GESAMTWACHSTUM: %d"):format(progress)),
    }
    if state.pendingLoot and state.pendingLoot.item then
      local item = game.data.items and game.data.items[state.pendingLoot.item]
      pages[#pages + 1] = tr("RESERVED REWARD:\n", "RESERVIERTER PREIS:\n")
        .. (item and item.name or state.pendingLoot.item)
    end
    return table.concat(pages, "\f")
  end

  local function itemName(game, id)
    local def = game and game.data and game.data.items
      and game.data.items[id]
    return def and def.name or tostring(id):gsub("_", " ")
  end

  local function percent(row)
    return math.max(0, (tonumber(row.to) or 0)
      - (tonumber(row.from) or 1) + 1) / 100
  end

  local function rewardRows(game)
    local mode = mod.options:get("loot_mode") or "balanced"
    if mode == "off" then
      return { {
        label = tr("REMATCH LOOT OFF", "REVANCHEN-BEUTE AUS"),
        value = false,
      } }
    end
    local rows, occupied = {}, 0
    for _, band in ipairs(lootBands[mode] or {}) do
      local chance = percent(band)
      occupied = occupied + chance
      rows[#rows + 1] = {
        label = itemName(game, band.item),
        right = shownPercent(chance),
        value = band,
      }
    end
    rows[#rows + 1] = {
      label = tr("NO DROP (BASE)", "NICHTS (BASIS)"),
      right = shownPercent(math.max(0, 100 - occupied)),
      value = { noDrop = true },
    }
    return rows
  end

  local function rewardDetails(game, row)
    if row.noDrop then
      return tr(
        "NO DROP\fLocked or level-gated\nbands also become no\ndrop; other odds never\ninflate silently.",
        "NICHTS\fGesperrte oder level-\ngebundene Bereiche werden\nebenfalls zu NICHTS.\fAndere Chancen steigen\nnicht heimlich.")
    end
    local pages = {
      itemName(game, row.item)
        .. "\n" .. shownPercent(percent(row)),
    }
    if row.minLevel then
      pages[#pages + 1] = tr(
        ("Trainer team average\nmust be at least Lv.%d."):format(row.minLevel),
        ("Trainer-Team braucht\nmindestens Ø-Level %d."):format(row.minLevel))
    end
    if row.gate == "master" then
      local p = postgame and postgame.state and postgame.state(false)
      pages[#pages + 1] = (p and p.apexChampion)
        and tr("APEX gate cleared.", "APEX-Sperre geöffnet.")
        or tr("Requires APEX Champion.", "Benötigt APEX-Champ.")
    elseif row.gate == "expAll" then
      local inventory = game.save.inventory or {}
      local flags = game.save.flags or {}
      pages[#pages + 1] = (inventory.EXP_ALL or flags.EVENT_GOT_EXP_ALL)
        and tr("Already received;\nfuture rolls become no drop.",
          "Bereits erhalten;\nweitere Würfe geben nichts.")
        or tr("Unique reward;\ncan be received once.",
          "Einmaliger Preis;\nnur einmal erhältlich.")
    end
    return table.concat(pages, "\f")
  end

  local function nativeHabitats(game, species)
    local rows, seen = {}, {}
    for mapId, encounter in pairs(game.data.encounters or {}) do
      for _, group in pairs(encounter or {}) do
        for _, slot in ipairs(group.slots or {}) do
          if slot.species == species and not seen[mapId] then
            seen[mapId] = true
            rows[#rows + 1] = cleanMapName(game, mapId)
          end
        end
      end
    end
    table.sort(rows)
    return rows
  end

  local function dynamicTerrainLabel(row)
    local terrain = row and row.terrain
    if terrain == "water" then return tr("water", "Wasser") end
    if terrain == "grass" then return tr("grass", "Gras") end
    if terrain == "indoor" then
      local mapId = tostring(row.map or "")
      if mapId:find("CAVE", 1, true)
          or mapId:find("MT_MOON", 1, true)
          or mapId:find("SEAFOAM", 1, true)
          or mapId:find("VICTORY_ROAD", 1, true)
          or mapId:find("ROCK_TUNNEL", 1, true) then
        return tr("cave", "Höhle")
      end
      if mapId:find("POKEMON_MANSION", 1, true)
          or mapId:find("POKEMON_TOWER", 1, true) then
        return tr("building", "Gebäude")
      end
      return tr("interior", "Innenraum")
    end
    return tostring(terrain or tr("unknown terrain", "unbekanntes Gebiet"))
      :gsub("_", " ")
  end

  local function dynamicHabitat(game, species)
    if johtoResearch and johtoResearch.habitatFor then
      local row = johtoResearch.habitatFor(species)
      if row and (not johtoResearch.isSpeciesResearched
          or johtoResearch.isSpeciesResearched(species)) then
        local candidates = johtoResearch.habitatCandidates
          and johtoResearch.habitatCandidates(row.map, row.terrain) or {}
        local poolChance = 0
        for _, candidate in ipairs(candidates) do
          poolChance = math.max(poolChance,
            math.max(0, math.min(100, tonumber(candidate.chance) or 2)))
        end
        if #candidates == 0 then return nil end
        return ("%s\f%s\f%s: %s\n%s: %s"):format(
          cleanMapName(game, row.map), dynamicTerrainLabel(row),
          tr("POOL BASE", "POOL BASIS"),
          shownPercent(poolChance),
          tr("SPECIES BASE", "ART BASIS"),
          shownPercent(poolChance / #candidates))
      end
    end
    if species == "EEVEE" and kantoCompletion
        and kantoCompletion.postgameEevee then
      local row = kantoCompletion.postgameEevee
      return ("%s %s\n%s: %s"):format(
        cleanMapName(game, row.map),
        tr("after Hall of Fame", "nach Ruhmeshalle"),
        tr("BASE CHANCE", "BASISCHANCE"),
        shownPercent(row.chance or 2))
    end
    return nil
  end

  local function reverseEvolution(game, species)
    local parents = {}
    local pokedex = game.save and game.save.pokedex or {}
    local seen = pokedex.seen or {}
    local owned = pokedex.owned or {}
    for id, def in pairs(game.data.pokemon or {}) do
      for _, evo in ipairs(def.evolutions or {}) do
        if evo.species == species and (seen[id] or owned[id]) then
          parents[#parents + 1] = {
            name = def.name or id,
            evolution = evo,
          }
        end
      end
    end
    table.sort(parents, function(a, b) return a.name < b.name end)
    if #parents == 0 then return nil end
    return parents
  end

  local function evolutionCondition(game, evo)
    local method = tostring(evo.method or "")
    if method == "LEVEL" then
      return tr(("LEVEL %d"):format(tonumber(evo.level) or 1),
        ("LEVEL %d"):format(tonumber(evo.level) or 1))
    elseif method == "ITEM" then
      return itemName(game, evo.item)
    elseif method == "FRIENDSHIP" then
      return tr("HIGH FRIENDSHIP", "HOHE FREUNDSCHAFT")
    elseif method == "FRIENDSHIP_DAY" then
      return tr("HIGH FRIENDSHIP / DAY", "HOHE FREUNDSCHAFT / TAG")
    elseif method == "FRIENDSHIP_NIGHT" then
      return tr("HIGH FRIENDSHIP / NIGHT", "HOHE FREUNDSCHAFT / NACHT")
    elseif method == "TYROGUE_ATTACK" then
      return tr("LEVEL 20 / ATTACK > DEF.", "LEVEL 20 / ANGR. > VERT.")
    elseif method == "TYROGUE_DEFENSE" then
      return tr("LEVEL 20 / DEF. > ATTACK", "LEVEL 20 / VERT. > ANGR.")
    elseif method == "TYROGUE_BALANCE" then
      return tr("LEVEL 20 / ATTACK = DEF.", "LEVEL 20 / ANGR. = VERT.")
    elseif method == "ASCENDANT_STORM_BOND" then
      return tr(
        "HALL OF FAME / HIGH BOND / THUNDER / POWER PLANT",
        "RUHMESHALLE / HOHES BAND / DONNER / KRAFTWERK")
    elseif method == "TRADE" then
      return tr("TRADE", "TAUSCH")
    end
    return method ~= "" and method:gsub("_", " ")
      or tr("SPECIAL CONDITION", "SONDERBEDINGUNG")
  end

  local function evolutionDetails(game, species)
    local def = game.data.pokemon[species]
    local pokedex = game.save and game.save.pokedex or {}
    local seen = pokedex.seen or {}
    local owned = pokedex.owned or {}
    local lines = {}
    for _, evo in ipairs(def and def.evolutions or {}) do
      local target = game.data.pokemon[evo.species]
      local targetName = (seen[evo.species] or owned[evo.species])
        and target and target.name or "???"
      lines[#lines + 1] = evolutionCondition(game, evo)
        .. " -> " .. targetName
    end
    local parents = reverseEvolution(game, species)
    for _, parent in ipairs(parents or {}) do
      lines[#lines + 1] = tr("FROM ", "VON ") .. parent.name
        .. ": " .. evolutionCondition(game, parent.evolution)
    end
    if #lines == 0 then return nil end
    return tr("EVOLUTION CONDITIONS", "ENTWICKLUNGSBEDINGUNGEN")
      .. "\n" .. table.concat(lines, "\n")
  end

  local function habitatDetails(game, species)
    local def = game.data.pokemon[species]
    local pages = { ("%03d %s"):format(def.dex, def.name) }
    local native = nativeHabitats(game, species)
    local dynamic = dynamicHabitat(game, species)
    if #native > 0 then
      pages[#pages + 1] = tr("KNOWN HABITATS\n", "BEKANNTE FUNDORTE\n")
        .. table.concat(native, "\n")
    end
    if dynamic then pages[#pages + 1] = dynamic end
    local source = SPECIAL_SOURCES[species]
    if source then pages[#pages + 1] = localized(source) end
    local evolution = evolutionDetails(game, species)
    if evolution then pages[#pages + 1] = evolution end
    if LEGENDARY[species] and not source then
      pages[#pages + 1] = tr(
        "ASCENDANT legendary\nevent. Consult JOURNAL.",
        "ASCENDANT-Legenden-\nEvent. Siehe JOURNAL.")
    end
    if #pages == 1 then
      pages[#pages + 1] = tr(
        "No exact habitat has\nbeen recorded yet.",
        "Noch kein genauer\nFundort erfasst.")
    end
    return table.concat(pages, "\f")
  end

  local function habitatRows(game)
    local pokedex = game.save.pokedex or {}
    local seen = pokedex.seen or {}
    local owned = pokedex.owned or {}
    local rows = {}
    for species, def in pairs(game.data.pokemon or {}) do
      local dex = tonumber(def.dex)
      if dex and dex >= 1 and (dex <= 251 or species == "GOROCHU")
          and (seen[species] or owned[species]) then
        rows[#rows + 1] = {
          label = ("%03d %s"):format(dex, def.name),
          right = owned[species] and tr("OWN", "HAT") or tr("SEEN", "GES."),
          value = species,
        }
      end
    end
    table.sort(rows, function(a, b) return a.label < b.label end)
    if #rows == 0 then
      rows[1] = {
        label = tr("NO SPECIES SEEN", "NOCH NICHTS GESEHEN"),
        value = false,
      }
    end
    return rows
  end

  local function objectiveText(game)
    if questTracker and questTracker.objectiveText then
      return questTracker.objectiveText(game)
    end
    if ascendant and ascendant.activeResearch then
      local s = ascendant.state and ascendant.state()
      local row = s and ascendant.activeResearch(s)
      if row then
        local value = ascendant.metricValue
          and ascendant.metricValue(row.metric, game, s) or 0
        return localized(row.title)
          .. ("\n%d/%d\f"):format(math.min(value, row.target), row.target)
          .. localized(row.task)
      end
    end
    return tr(
      "Oak has no unfinished\nAscendant assignment.\fConsult JOURNAL for\nworld and legend leads.",
      "Eich hat keinen offenen\nAscendant-Auftrag.\fSieh ins JOURNAL für\nWelt- und Legenden-Spuren.")
  end

  if mod.content and mod.content.screens then
    mod.content.screens:register("AscendantTrainerAtlas", {
      new = function(game)
        return mod.ui.ListMenu.new(game, tr("TRAINER LOG", "TRAINER-LOG"),
          trainerRows(game), {
            pageJump = true,
            onChoose = function(item)
              if not item.value then return end
              game.stack:push(require("src.render.TextBox").new(game,
                trainerDetails(game, item.value)))
            end,
          })
      end,
    })

    mod.content.screens:register("AscendantRewardAtlas", {
      new = function(game)
        return mod.ui.ListMenu.new(game, tr("REWARD DATA", "BEUTE-DATEN"),
          rewardRows(game), {
            pageJump = true,
            onChoose = function(item)
              if not item.value then return end
              game.stack:push(require("src.render.TextBox").new(game,
                rewardDetails(game, item.value)))
            end,
          })
      end,
    })

    mod.content.screens:register("AscendantHabitatAtlas", {
      new = function(game)
        return mod.ui.ListMenu.new(game, tr("KNOWN HABITATS", "BEKANNTE FUNDORTE"),
          habitatRows(game), {
            pageJump = true,
            onChoose = function(item)
              if not item.value then return end
              game.stack:push(require("src.render.TextBox").new(game,
                habitatDetails(game, item.value)))
            end,
          })
      end,
    })
  end

  local function openAtlas(game)
    local rows = {
      { label = tr("CURRENT OBJECTIVE", "AKTUELLES ZIEL"), value = "objective" },
      { label = tr("TRAINER LOG", "TRAINER-LOG"), value = "trainers" },
      { label = tr("REWARD DATA", "BEUTE-DATEN"), value = "rewards" },
      { label = tr("TM ARCHIVE", "TM-ARCHIV"), value = "tm" },
      { label = tr("KNOWN HABITATS", "BEKANNTE FUNDORTE"), value = "habitats" },
    }
    game.stack:push(mod.ui.ListMenu.new(game,
      tr("RESEARCH ATLAS", "FORSCHUNGSATLAS"), rows, {
        onChoose = function(item)
          if item.value == "objective" then
            game.stack:push(require("src.render.TextBox").new(game,
              objectiveText(game)))
          elseif item.value == "trainers" then
            mod.ui.push(game, "AscendantTrainerAtlas")
          elseif item.value == "rewards" then
            mod.ui.push(game, "AscendantRewardAtlas")
          elseif item.value == "tm" then
            local text = fieldTech and fieldTech.statusText
              and fieldTech.statusText(game)
              or tr("TM Archive unavailable.", "TM-Archiv nicht verfügbar.")
            game.stack:push(require("src.render.TextBox").new(game, text))
          elseif item.value == "habitats" then
            mod.ui.push(game, "AscendantHabitatAtlas")
          end
        end,
      }))
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" or not (postgame
        and postgame.hasHallOfFame(game.save)) then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = tr("ATLAS", "ATLAS"),
      ascendantMenu = true,
      ascendantLabel = tr("RESEARCH ATLAS", "FORSCHUNGSATLAS"),
      ascendantOrder = 5,
      onSelect = function() openAtlas(game) end,
    })
  end, 245)

  function A.install(game)
    A.game = game
  end

  A.open = openAtlas
  A.trainerRows = trainerRows
  A.rewardRows = rewardRows
  A.habitatRows = habitatRows
  A.habitatDetails = habitatDetails
  A.objectiveText = objectiveText
  A.cleanMapName = cleanMapName
  A.setQuestTracker = function(controller) questTracker = controller end
  return A
end
