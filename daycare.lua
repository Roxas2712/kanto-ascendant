-- Route 5 Day-Care Plus: two parent slots, step experience, breeding,
-- party eggs and the visible evolution / Mega research terminal.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local postgame = opts.postgame
  local breedingData = opts.breedingData or {}
  local enabled = opts.contentEnabled ~= false
  local D = {
    game = nil,
    enabled = enabled,
    machineName = "ASCENDANT_EVOLUTION_MACHINE",
  }
  local mega
  local shinySystem = opts.shinySystem
  local fieldTech = opts.fieldTech
  local frontierExchange = opts.frontierExchange

  local EGG_CHECK_STEPS = 256
  local DEFAULT_HATCH_STEPS = 2048
  local BABY_SPECIES = {
    PICHU = true, CLEFFA = true, IGGLYBUFF = true, TOGEPI = true,
    TYROGUE = true, SMOOCHUM = true, ELEKID = true, MAGBY = true,
  }
  local BABY_ROOTS = {
    PIKACHU = "PICHU", RAICHU = "PICHU",
    CLEFAIRY = "CLEFFA", CLEFABLE = "CLEFFA",
    JIGGLYPUFF = "IGGLYBUFF", WIGGLYTUFF = "IGGLYBUFF",
    TOGETIC = "TOGEPI",
    HITMONLEE = "TYROGUE", HITMONCHAN = "TYROGUE", HITMONTOP = "TYROGUE",
    JYNX = "SMOOCHUM", ELECTABUZZ = "ELEKID", MAGMAR = "MAGBY",
  }
  local NO_EGGS = {
    ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true,
    MEW = true, RAIKOU = true, ENTEI = true, SUICUNE = true,
    LUGIA = true, HO_OH = true, CELEBI = true, UNOWN = true,
  }
  local GENDERLESS = {
    MAGNEMITE = true, MAGNETON = true, VOLTORB = true, ELECTRODE = true,
    STARYU = true, STARMIE = true, PORYGON = true, PORYGON2 = true,
    DITTO = true,
  }
  local FEMALE_ONLY = {
    NIDORAN_F = true, NIDORINA = true, NIDOQUEEN = true,
    CHANSEY = true, BLISSEY = true, KANGASKHAN = true, JYNX = true,
    SMOOCHUM = true, MILTANK = true,
  }
  local MALE_ONLY = {
    NIDORAN_M = true, NIDORINO = true, NIDOKING = true,
    HITMONLEE = true, HITMONCHAN = true, HITMONTOP = true,
    TAUROS = true,
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function state(create)
    local s = mod.save:get("daycare_plus")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 2, parents = {}, eggMeter = 0, reservedEggs = {},
        eggsProduced = 0, eggsHatched = 0,
      }
      mod.save:set("daycare_plus", s)
    end
    if type(s) == "table" then
      s.version = 2
      s.parents = type(s.parents) == "table" and s.parents or {}
      s.reservedEggs = type(s.reservedEggs) == "table" and s.reservedEggs or {}
      s.eggMeter = math.max(0, math.floor(tonumber(s.eggMeter) or 0))
      s.eggsProduced = math.max(0, math.floor(tonumber(s.eggsProduced) or 0))
      s.eggsHatched = math.max(0, math.floor(tonumber(s.eggsHatched) or 0))
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("daycare_plus", s) end
  end

  local function nameOf(game, mon)
    local def = mon and game.data.pokemon[mon.species]
    return mon and (mon.nickname or (def and def.name) or mon.species) or "?"
  end

  local function gender(game, mon)
    if not mon then return nil end
    local def = game and game.data.pokemon[mon.species]
    local row = def and breedingData[def.dex]
    if row then
      if row.gender == nil or row.gender < 0 then return nil end
      if row.gender == 0 then return "M" end
      if row.gender >= 8 then return "F" end
      local attackDv = mon.dvs and tonumber(mon.dvs.attack) or 0
      return attackDv < row.gender * 2 and "F" or "M"
    end
    if GENDERLESS[mon.species] or NO_EGGS[mon.species] then
      return nil
    end
    if FEMALE_ONLY[mon.species] then return "F" end
    if MALE_ONLY[mon.species] then return "M" end
    local attackDv = mon.dvs and tonumber(mon.dvs.attack) or 0
    return attackDv % 2 == 0 and "F" or "M"
  end

  -- A compact Kanto/Johto breeding-group model. A species may occupy more
  -- than one broad habitat, keeping every one of the 251 usable without
  -- importing later-generation battle/type mechanics.
  local TYPE_GROUPS = {
    NORMAL = { field = true, fairy = true },
    FIRE = { field = true, monster = true },
    WATER = { water = true, monster = true },
    ELECTRIC = { field = true, fairy = true },
    GRASS = { plant = true, fairy = true },
    ICE = { water = true, field = true },
    FIGHTING = { humanoid = true, field = true },
    POISON = { amorphous = true, bug = true },
    GROUND = { field = true, monster = true },
    FLYING = { flying = true, field = true },
    PSYCHIC = { humanoid = true, fairy = true },
    BUG = { bug = true, plant = true },
    ROCK = { mineral = true, monster = true },
    GHOST = { amorphous = true },
    DRAGON = { dragon = true, monster = true },
    DARK = { field = true, amorphous = true },
    STEEL = { mineral = true },
  }

  local function groupsFor(game, mon)
    local out = {}
    local def = mon and game.data.pokemon[mon.species]
    local breeding = def and breedingData[def.dex]
    if breeding then
      for _, group in ipairs(breeding.groups or {}) do out[group] = true end
      return out
    end
    for _, typeId in ipairs(def and def.types or {}) do
      for group in pairs(TYPE_GROUPS[typeId] or {}) do out[group] = true end
    end
    return out
  end

  local function preEvolutionMap(game)
    local map = {}
    for species, def in pairs(game.data.pokemon or {}) do
      for _, evo in ipairs(def.evolutions or {}) do
        if evo.species and not map[evo.species] then map[evo.species] = species end
      end
    end
    return map
  end

  local function babyFor(game, species)
    if BABY_ROOTS[species] then return BABY_ROOTS[species] end
    local pre = preEvolutionMap(game)
    local seen = {}
    while pre[species] and not seen[species] do
      seen[species] = true
      species = pre[species]
    end
    return species
  end

  local function compatible(game, a, b)
    if not (a and b) or a.isEgg or b.isEgg then return false, 0 end
    local ag, bg = groupsFor(game, a), groupsFor(game, b)
    if ag["no-eggs"] or bg["no-eggs"]
        or (ag.ditto and bg.ditto) then return false, 0 end
    if NO_EGGS[a.species] or NO_EGGS[b.species] then return false, 0 end
    if BABY_SPECIES[a.species] or BABY_SPECIES[b.species] then return false, 0 end
    -- Crystal refuses parents whose Defense DVs and lower three Special-DV
    -- bits match. This is the original game's anti-incest check and also
    -- means two Gen-II shinies cannot breed with one another.
    local ad, bd = a.dvs or {}, b.dvs or {}
    if ad.defense ~= nil and ad.defense == bd.defense
        and ad.special ~= nil and bd.special ~= nil
        and ad.special % 8 == bd.special % 8 then
      return false, 0
    end
    if (ag.ditto and not bg["no-eggs"])
        or (bg.ditto and not ag["no-eggs"]) then return true, 50 end
    local ga, gb = gender(game, a), gender(game, b)
    if not ga or not gb or ga == gb then return false, 0 end
    if babyFor(game, a.species) == babyFor(game, b.species) then
      return true, a.species == b.species and 70 or 50
    end
    for group in pairs(ag) do
      if bg[group] then return true, a.species == b.species and 50 or 30 end
    end
    return false, 0
  end

  local function eggSpecies(game, a, b)
    local mother
    if a.species == "DITTO" then mother = b
    elseif b.species == "DITTO" then mother = a
    else mother = gender(game, a) == "F" and a or b end
    local species = babyFor(game, mother.species)
    -- The two Nidoran families share eggs; retain the mother's family so
    -- the result is deterministic and save/replay friendly.
    if mother.species == "NIDORINA" or mother.species == "NIDOQUEEN" then
      species = "NIDORAN_F"
    end
    return species
  end

  local function hatchStepsFor(game, species)
    local def = game.data.pokemon[species]
    local row = def and breedingData[def.dex]
    return math.max(256,
      math.floor(tonumber(row and row.hatch) or (DEFAULT_HATCH_STEPS / 256))
        * 256)
  end

  -- Pokémon Crystal first rolls all four DVs, then inherits Defense and
  -- the low three Special bits from Ditto or the opposite-gender parent.
  -- The random high Special bit is retained. A shiny donor consequently
  -- produces a shiny egg at the authentic 1/64 rate.
  local function inheritedDVs(game, species, a, b, random)
    random = random or (love and love.math and love.math.random) or math.random
    local dvs = {
      attack = random(0, 15), defense = random(0, 15),
      speed = random(0, 15), special = random(0, 15),
    }
    local donor
    if a and a.species == "DITTO" then donor = a
    elseif b and b.species == "DITTO" then donor = b
    else
      local childGender = gender(game, { species = species, dvs = dvs })
      local ga, gb = gender(game, a), gender(game, b)
      local wanted = childGender == "M" and "F"
        or (childGender == "F" and "M" or nil)
      if wanted then donor = ga == wanted and a or (gb == wanted and b or nil) end
    end
    if donor and donor.dvs then
      dvs.defense = donor.dvs.defense or dvs.defense
      dvs.special = math.floor(dvs.special / 8) * 8
        + ((donor.dvs.special or dvs.special) % 8)
    end
    dvs.hp = (dvs.attack % 2) * 8 + (dvs.defense % 2) * 4
      + (dvs.speed % 2) * 2 + (dvs.special % 2)
    return dvs
  end

  local function compatibilityText(game, s)
    local a = s.parents[1] and s.parents[1].mon
    local b = s.parents[2] and s.parents[2].mon
    if not a or not b then
      return tr("The old man needs two\nPOKéMON to find an EGG.",
                "Der Pfleger braucht zwei\nPOKéMON für ein EI.")
    end
    local ok, chance = compatible(game, a, b)
    if not ok then
      return tr("They prefer to play\nwith other POKéMON.",
                "Sie spielen lieber mit\nanderen POKéMON.")
    elseif chance >= 60 then
      return tr("The two get along\nextraordinarily well!",
                "Die beiden verstehen\nsich ausgezeichnet!")
    elseif chance >= 45 then
      return tr("The two seem to get\nalong very well.",
                "Die beiden verstehen\nsich sehr gut.")
    end
    return tr("The two don't seem to\nlike each other much.",
              "Die beiden mögen sich\nnicht besonders.")
  end

  local function levelPreview(game, entry)
    local Growth = require("src.pokemon.Growth")
    local mon = entry.mon
    local def = game.data.pokemon[mon.species]
    local exp = (mon.exp or 0) + math.max(0, tonumber(entry.steps) or 0)
    local level = math.min(100, Growth.levelForExp(def.growthRate, exp))
    return math.max(mon.level, level), exp
  end

  local function makeEgg(game, row)
    local Pokemon = require("src.pokemon.Pokemon")
    local mon = Pokemon.new(game.data, row.species, 5)
    if type(row.dvs) == "table" then
      mon.dvs = {}
      for key, value in pairs(row.dvs) do mon.dvs[key] = value end
      mon.stats = require("src.pokemon.Stats").calc(
        game.data.pokemon[row.species], mon.level, mon.dvs, mon.statExp)
    end
    require("src.battle.BattleState").stampOT(game.save, mon)
    mon.isEgg = true
    mon.eggSpecies = row.species
    mon.eggStepsRemaining = math.max(1,
      math.floor(tonumber(row.steps) or DEFAULT_HATCH_STEPS))
    mon.eggTotalSteps = mon.eggStepsRemaining
    mon.eggOrigin = row.origin or "ROUTE 5 DAY-CARE"
    mon.eggResearchKey = row.researchKey
    mon.nickname = "EGG"
    mon.hp = 0
    mon.status = nil
    return mon
  end

  local function markOwned(game, species)
    local dex = game.save.pokedex
    if dex then
      dex.seen[species] = true
      dex.owned[species] = true
    end
  end

  local function takeReservedEgg(game, index)
    local s = state()
    local row = s.reservedEggs[index or 1]
    if not row then
      return tr("There is no EGG\nwaiting right now.",
                "Momentan wartet\nkein EI.")
    end
    if #game.save.party >= require("src.pokemon.Party").MAX then
      return tr("Make room in your\nPARTY for the EGG.",
                "Schaffe im TEAM\nPlatz für das EI.")
    end
    table.insert(game.save.party, makeEgg(game, row))
    table.remove(s.reservedEggs, index or 1)
    persist(s)
    return tr(
      ("%s received an EGG!\fIt may hatch after\n%d steps."):format(
        game.save.player.name, row.steps or DEFAULT_HATCH_STEPS),
      ("%s erhält ein EI!\fEs schlüpft nach\netwa %d Schritten."):format(
        game.save.player.name, row.steps or DEFAULT_HATCH_STEPS))
  end

  local function hatchEgg(game, mon)
    local species = mon.eggSpecies or mon.species
    mon.species = species
    mon.isEgg = nil
    mon.eggSpecies = nil
    mon.eggStepsRemaining = nil
    mon.eggTotalSteps = nil
    mon.nickname = nil
    mon.johtoBond = 80
    mon.johtoResearch = {
      origin = mon.eggOrigin or "ROUTE 5 DAY-CARE",
      receivedAt = os.time(),
    }
    mon.eggOrigin = nil
    local researchKey = mon.eggResearchKey
    mon.eggResearchKey = nil
    require("src.pokemon.Pokemon").heal(mon)
    markOwned(game, species)
    if shinySystem and shinySystem.onHatched then
      shinySystem.onHatched(game, mon)
    end
    local s = state()
    s.eggsHatched = s.eggsHatched + 1
    persist(s)
    if researchKey then
      local research = mod.save:get("johto_research")
      if type(research) == "table" then
        research.eggsHatched = type(research.eggsHatched) == "table"
          and research.eggsHatched or {}
        research.eggsHatched[researchKey] = true
        mod.save:set("johto_research", research)
      end
    end
    return tr(
      ("Oh?\fThe EGG hatched!\f%s was born!"):format(
        game.data.pokemon[species].name),
      ("Oh?\fDas EI schlüpft!\f%s wurde geboren!"):format(
        game.data.pokemon[species].name))
  end

  local function step(game)
    local s = state(false)
    if not s then return end
    for slot = 1, 2 do
      local entry = s.parents[slot]
      if entry then
        entry.steps = math.max(0, math.floor(tonumber(entry.steps) or 0)) + 1
      end
    end
    local a = s.parents[1] and s.parents[1].mon
    local b = s.parents[2] and s.parents[2].mon
    local ok, chance = compatible(game, a, b)
    if ok and #s.reservedEggs == 0 then
      s.eggMeter = s.eggMeter + 1
      if s.eggMeter >= EGG_CHECK_STEPS then
        s.eggMeter = s.eggMeter - EGG_CHECK_STEPS
        local random = love and love.math and love.math.random or math.random
        if random(1, 100) <= chance then
          local species = eggSpecies(game, a, b)
          s.reservedEggs[#s.reservedEggs + 1] = {
            species = species,
            steps = hatchStepsFor(game, species),
            origin = "ROUTE 5 DAY-CARE",
            dvs = inheritedDVs(game, species, a, b, random),
          }
          s.eggsProduced = s.eggsProduced + 1
        end
      end
    end
    local pages = {}
    for _, mon in ipairs(game.save.party or {}) do
      if mon.isEgg then
        mon.hp = 0
        mon.status = nil
        mon.eggStepsRemaining = math.max(0,
          math.floor(tonumber(mon.eggStepsRemaining) or 1) - 1)
        if mon.eggStepsRemaining <= 0 then
          pages[#pages + 1] = hatchEgg(game, mon)
        end
      end
    end
    persist(s)
    if #pages > 0 then
      game.stack:push(require("src.render.TextBox").new(
        game, table.concat(pages, "\f")))
    end
  end

  local function deposit(game, slot, after)
    if #game.save.party < 2 then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "You need at least two\nPOKéMON in your PARTY.",
        "Du brauchst mindestens\nzwei POKéMON im TEAM."), after))
      return
    end
    game.stack:push(require("src.ui.PartyMenu").new(game, {
      pickOnly = true,
      onCancel = after,
      onSwitch = function(mon)
        if mon.isEgg then
          game.stack:push(require("src.render.TextBox").new(game, tr(
            "An EGG cannot be left\nas a parent.",
            "Ein EI kann kein\nElternteil sein."), after))
          return
        end
        for i, partyMon in ipairs(game.save.party) do
          if partyMon == mon then table.remove(game.save.party, i) break end
        end
        local s = state()
        s.parents[slot] = {
          mon = mon, depositLevel = mon.level, steps = 0,
        }
        persist(s)
        game.stack:push(require("src.render.TextBox").new(game, tr(
          ("I'll look after\n%s in slot %d."):format(nameOf(game, mon), slot),
          ("Ich passe in Platz %d\nauf %s auf."):format(slot, nameOf(game, mon))),
          after))
      end,
    }))
  end

  local function retrieve(game, slot, after)
    local s = state()
    local entry = s.parents[slot]
    if not entry then return after() end
    if #game.save.party >= require("src.pokemon.Party").MAX then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "There is no room in\nyour PARTY.",
        "In deinem TEAM ist\nkein Platz."), after))
      return
    end
    local mon = entry.mon
    local newLevel, newExp = levelPreview(game, entry)
    local gained = math.max(0, newLevel - (entry.depositLevel or mon.level))
    local fee = 100 + gained * 100
    local prompt = tr(
      ("%s grew by %d level%s.\fThe fee is ¥%d.\fTAKE IT BACK?"):format(
        nameOf(game, mon), gained, gained == 1 and "" or "s", fee),
      ("%s stieg um %d Level.\fKosten: ¥%d.\fZURÜCKNEHMEN?"):format(
        nameOf(game, mon), gained, fee))
    game.stack:push(require("src.render.TextBox").new(game, prompt, nil, {
      choice = function(yes)
        if not yes then after() return end
        if (game.save.money or 0) < fee then
          game.stack:push(require("src.render.TextBox").new(game, tr(
            "You don't have\nenough money.",
            "Du hast nicht\ngenug Geld."), after))
          return
        end
        game.save.money = game.save.money - fee
        local oldLevel = mon.level
        mon.exp = newExp
        mon.level = newLevel
        local def = game.data.pokemon[mon.species]
        mon.stats = require("src.pokemon.Stats").calc(
          def, mon.level, mon.dvs, mon.statExp)
        require("src.pokemon.Pokemon").learnMovesFromDayCare(
          game.data, mon, def, oldLevel, newLevel)
        require("src.pokemon.Pokemon").heal(mon)
        table.insert(game.save.party, mon)
        s.parents[slot] = nil
        persist(s)
        game.stack:push(require("src.render.TextBox").new(game, tr(
          ("%s came back to\nyour PARTY!"):format(nameOf(game, mon)),
          ("%s ist wieder\nin deinem TEAM!"):format(nameOf(game, mon))), after))
      end,
    }))
  end

  local function evolutionChoices(game)
    local out = {}
    local inventory = game.save.inventory or {}
    for _, mon in ipairs(game.save.party or {}) do
      if not mon.isEgg then
        local def = game.data.pokemon[mon.species]
        for _, evo in ipairs(def and def.evolutions or {}) do
          if evo.method == "ITEM" and evo.item and inventory[evo.item] then
            out[#out + 1] = { mon = mon, evo = evo }
          end
        end
      end
    end
    return out
  end

  local function evolutionMenu(game, done)
    local choices = evolutionChoices(game)
    if #choices == 0 then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "No PARTY POKéMON can\nuse an evolution item.",
        "Kein TEAM-POKéMON kann\nein Evolutionsitem nutzen."), done))
      return
    end
    local rows = {}
    for i, row in ipairs(choices) do
      rows[#rows + 1] = {
        label = nameOf(game, row.mon),
        right = game.data.pokemon[row.evo.species].name,
        value = i,
      }
    end
    game.stack:push(mod.ui.ListMenu.new(game, tr("EVOLUTION", "ENTWICKLUNG"),
      rows, {
        onCancel = done,
        onChoose = function(item, menu)
          local row = choices[item.value]
          menu:close()
          require("src.inventory.Bag").remove(game.save, row.evo.item, 1)
          require("src.pokemon.Evolution").evolve(
            game, row.mon, row.evo.species, done, row.evo.method)
        end,
      }))
  end

  local function machineMenu(game, done)
    local rows = {
      { label = tr("ITEM EVOLUTION", "ITEM-ENTWICKLUNG"), value = "evolve" },
    }
    if fieldTech then
      rows[#rows + 1] = {
        label = tr("MOVE DELETER", "ATTACKEN-VERL."), value = "forget",
      }
      rows[#rows + 1] = {
        label = tr("MOVE REMINDER", "ATTACKEN-ERINN."), value = "remember",
      }
      rows[#rows + 1] = {
        label = tr("TM ARCHIVE", "TM-ARCHIV"), value = "tm_archive",
      }
    end
    if frontierExchange
        and (type(frontierExchange.available) ~= "function"
          or frontierExchange.available(game)) then
      rows[#rows + 1] = {
        label = tr("FRONTIER EXCHANGE", "FRONTIER-TAUSCH"),
        value = "frontier_exchange",
      }
    end
    if mega and mega.available(game) then
      if mega.hasRing(game) then
        rows[#rows + 1] = {
          label = tr("MEGA STONES", "MEGA-STEINE"),
          value = "stones",
        }
        rows[#rows + 1] = {
          label = tr("MEGA FORM", "MEGA-FORM"),
          value = "forms",
        }
        rows[#rows + 1] = {
          label = tr("MEGA GUIDE", "MEGA-HILFE"), value = "guide",
        }
      else
        rows[#rows + 1] = {
          label = tr("MEGA RING", "MEGA-RING"), value = "ring",
        }
      end
    end
    rows[#rows + 1] = { label = tr("CANCEL", "ZURÜCK"), value = "cancel" }
    game.stack:push(mod.ui.ListMenu.new(game,
      tr("EVOLUTION MACHINE", "ENTWICKLUNGSMASCHINE"), rows, {
        onCancel = done,
        onChoose = function(item, menu)
          if item.value == "evolve" then
            menu:close()
            evolutionMenu(game, done)
          elseif item.value == "forget" then
            menu:close()
            fieldTech.forgetMenu(game, done)
          elseif item.value == "remember" then
            menu:close()
            fieldTech.rememberMenu(game, done)
          elseif item.value == "tm_archive" then
            game.stack:push(require("src.render.TextBox").new(
              game, fieldTech.archiveMachineText(game), nil))
          elseif item.value == "frontier_exchange" then
            menu:close()
            frontierExchange.open(game, done)
          elseif item.value == "ring" then
            menu:close()
            game.stack:push(require("src.render.TextBox").new(
              game, mega.unlock(game), done))
          elseif item.value == "stones" then
            menu:close()
            mega.stoneMenu(game, done)
          elseif item.value == "forms" then
            menu:close()
            mega.formMenu(game, done)
          elseif item.value == "guide" then
            game.stack:push(require("src.render.TextBox").new(
              game, mega.guide(), nil))
          else
            menu:close()
            done()
          end
        end,
      }))
  end

  local function daycareMenu(game, done)
    local s = state()
    local rows = {}
    for slot = 1, 2 do
      local entry = s.parents[slot]
      if entry then
        local level = levelPreview(game, entry)
        local shortName = nameOf(game, entry.mon):sub(1, 4)
        rows[#rows + 1] = {
          label = tr(("TAKE %d"):format(slot), ("HOLEN %d"):format(slot)),
          right = ("%s L%d"):format(shortName, level),
          value = "take" .. slot,
        }
      else
        rows[#rows + 1] = {
          label = tr(("LEAVE %d"):format(slot), ("ABGEBEN %d"):format(slot)),
          value = "leave" .. slot,
        }
      end
    end
    rows[#rows + 1] = {
      label = tr("CHECK PAIR", "PAAR PRÜFEN"), value = "check",
    }
    if #s.reservedEggs > 0 then
      local egg = s.reservedEggs[1]
      rows[#rows + 1] = {
        label = tr("TAKE EGG", "EI ABHOLEN"),
        right = game.data.pokemon[egg.species].name,
        value = "egg",
      }
    end
    rows[#rows + 1] = { label = tr("CANCEL", "ZURÜCK"), value = "cancel" }
    game.stack:push(mod.ui.ListMenu.new(game, tr("ROUTE 5 DAY-CARE", "ROUTE-5-PENSION"),
      rows, {
        onCancel = done,
        onChoose = function(item, menu)
          if item.value == "cancel" then menu:close(); done(); return end
          if item.value == "check" then
            game.stack:push(require("src.render.TextBox").new(
              game, compatibilityText(game, s)))
          elseif item.value == "egg" then
            game.stack:push(require("src.render.TextBox").new(
              game, takeReservedEgg(game, 1)))
            item.right = nil
            item.label = tr("NO EGG", "KEIN EI")
          else
            local action, slot = item.value:match("^(%a+)(%d)$")
            menu:close()
            if action == "leave" then deposit(game, tonumber(slot), done)
            else retrieve(game, tonumber(slot), done) end
          end
        end,
      }))
  end

  function D.handleTalk(ow, npc, game)
    if not (enabled and ow and ow.map and ow.map.id == "DAYCARE"
        and npc and npc.def) then return false end
    if npc.def.name ~= "DAYCARE_GENTLEMAN"
        and npc.def.name ~= D.machineName then return false end
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    if npc.def.name == D.machineName then
      machineMenu(game, done)
    else
      daycareMenu(game, done)
    end
    return true
  end

  local function machineIds(game)
    local ids = {}
    local map = game and game.data and game.data.maps and game.data.maps.DAYCARE
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == D.machineName then
        ids[#ids + 1] = "DAYCARE_obj_" .. tostring(obj.index)
      end
    end
    return ids
  end

  function D.refresh(game, mapId)
    if not (enabled and game and (not mapId or mapId == "DAYCARE")) then return end
    if #machineIds(game) > 0 then return end
    local ow = mod.world and mod.world:overworld()
    if not (ow and ow.map and ow.map.id == "DAYCARE") then return end
    local candidates = { { 6, 2 }, { 5, 2 }, { 1, 1 }, { 6, 5 } }
    local x, y
    for _, cell in ipairs(candidates) do
      if ow.map:inBounds(cell[1], cell[2])
          and ow.map:isWalkableCell(cell[1], cell[2])
          and not ow:npcAtCell(cell[1], cell[2])
          and not ow.map:warpAtCell(cell[1], cell[2]) then
        x, y = cell[1], cell[2]
        break
      end
    end
    if not x then
      for cy = 0, ow.map.heightCells - 1 do
        for cx = 0, ow.map.widthCells - 1 do
          if ow.map:isWalkableCell(cx, cy) and not ow:npcAtCell(cx, cy)
              and not ow.map:warpAtCell(cx, cy)
              and not (ow.player.cellX == cx and ow.player.cellY == cy) then
            x, y = cx, cy
            break
          end
        end
        if x then break end
      end
    end
    if not x then return end
    mod.world:spawnNpc("DAYCARE", {
      name = D.machineName, sprite = "SPRITE_POKEDEX",
      movement = "STAY", range = "DOWN",
      text = "KANTO_ASCENDANT_EVOLUTION_MACHINE", x = x, y = y,
    })
  end

  function D.reserveEgg(species, steps, origin, researchKey)
    local s = state()
    for _, row in ipairs(s.reservedEggs) do
      if researchKey and row.researchKey == researchKey then return true end
    end
    s.reservedEggs[#s.reservedEggs + 1] = {
      species = species,
      steps = math.max(1, math.floor(tonumber(steps) or DEFAULT_HATCH_STEPS)),
      origin = origin or "ELM RESEARCH EGG",
      researchKey = researchKey,
    }
    s.eggsProduced = s.eggsProduced + 1
    persist(s)
    return true
  end

  function D.researchEggStatus(game)
    local s = state(false)
    for _, row in ipairs(s and s.reservedEggs or {}) do
      if row.researchKey then
        return row.species, row.steps, "reserved"
      end
    end
    for _, mon in ipairs(game and game.save.party or {}) do
      if mon.isEgg and mon.eggResearchKey then
        return mon.eggSpecies or mon.species,
          mon.eggStepsRemaining or 0, "party"
      end
    end
  end

  function D.install(game)
    D.game = game
    local s = state()
    -- Adopt a vanilla one-slot deposit when the expansion is enabled on an
    -- existing save. No Pokémon or accumulated step experience is lost.
    local vanilla = game.save.daycare
    if vanilla and vanilla.mon and not s.parents[1] then
      s.parents[1] = {
        mon = vanilla.mon,
        depositLevel = vanilla.depositLevel or vanilla.mon.level,
        steps = math.max(0, math.floor(tonumber(vanilla.steps) or 0)),
      }
      game.save.daycare = nil
      persist(s)
    end
    local Pokemon = require("src.pokemon.Pokemon")
    if not Pokemon._ascendantEggHealWrapped then
      Pokemon._ascendantEggHealWrapped = true
      local vanillaHeal = Pokemon.heal
      Pokemon.heal = function(mon, ...)
        if mon and mon.isEgg then
          mon.hp, mon.status = 0, nil
          return
        end
        return vanillaHeal(mon, ...)
      end
    end
    D.refresh(game, game.overworld and game.overworld.map and game.overworld.map.id)
  end

  function D.setMega(controller)
    mega = controller
  end

  function D.setShinySystem(controller)
    shinySystem = controller
  end

  function D.setFrontierExchange(controller)
    frontierExchange = controller
  end

  function D.status()
    return state(false)
  end

  function D.compatible(game, a, b)
    return compatible(game, a, b)
  end

  function D.babyFor(game, species)
    return babyFor(game, species)
  end

  function D.inheritedDVs(game, species, a, b, random)
    return inheritedDVs(game, species, a, b, random)
  end

  mod.events:on("world.stepped", function()
    if enabled and D.game then step(D.game) end
  end)

  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or D.game
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
    if game then D.refresh(game, mapId) end
  end)

  mod.events:on("save.loaded", function()
    state()
  end)

  return D
end
