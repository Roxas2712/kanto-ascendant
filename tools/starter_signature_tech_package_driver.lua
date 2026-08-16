-- TECH-001 installed-package acceptance for Red, Blue and Yellow.
--
-- The driver exercises the live package controller, its public optional
-- content-provider seam, all-or-nothing provider rollback/reactivation, the
-- real Crown TM award and Move Reminder transactions, and a native save/load
-- round-trip.  It runs only inside an isolated packaged QA identity.
return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")

  local function requiredSha(name)
    local value = os.getenv(name)
    assert(type(value) == "string" and #value == 64
        and value:match("^[0-9a-f]+$"),
      name .. " must be a lowercase SHA256 receipt")
    return value
  end

  local receipts = {
    engine_payload_sha256 = requiredSha("KA_ENGINE_PAYLOAD_SHA256"),
    authority_package_sha256 = requiredSha("KA_AUTHORITY_PACKAGE_SHA256"),
    deutsch_package_sha256 = requiredSha("KA_DEUTSCH_PACKAGE_SHA256"),
    package_gate_receipt_sha256 = requiredSha(
      "KA_PACKAGE_GATE_RECEIPT_SHA256"),
  }
  local utilPath = assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL packaged harness path is required")
  assert(utilPath:sub(1, 1) == "/"
      and not utilPath:find(".worktrees", 1, true)
      and not utilPath:find("/Documents/Recompile/", 1, true),
    "KA_TEST_UTIL must be an absolute packaged harness snapshot")
  local U = dofile(utilPath)
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local edition = GameVersion.get()
  local expectedEdition = assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION is required")
  assert(edition == expectedEdition
      and (edition == "red" or edition == "blue" or edition == "yellow"),
    "TECH-001 must run against the requested Red, Blue or Yellow package")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")
  assert(identity:find("tech%-001") and not identity:find("%.worktrees"),
    "TECH-001 requires its isolated package identity")
  local slot = "slot65tech001_" .. edition
  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve the TECH-001 native save slot")

  U.wait(12)
  local loaded = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local installed = assert(loaded.kanto_ascendant,
    "installed Authority package is missing")
  local runtimeSource = tostring(love.filesystem.getSource() or "")
  local authorityPath = tostring(installed.path or "")
  for _, path in ipairs({ runtimeSource, authorityPath }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not package evidence: " .. path)
  end

  local api = assert(game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "current Kanto Ascendant export missing")
  local tech = assert(api.fieldTech, "field-tech controller missing")
  local order = { "FRENZY_PLANT", "BLAST_BURN", "HYDRO_CANNON" }
  local expected = {
    FRENZY_PLANT = {
      "BULBASAUR", "IVYSAUR", "VENUSAUR",
      "CHIKORITA", "BAYLEEF", "MEGANIUM",
      "TREECKO", "GROVYLE", "SCEPTILE",
    },
    BLAST_BURN = {
      "CHARMANDER", "CHARMELEON", "CHARIZARD",
      "CYNDAQUIL", "QUILAVA", "TYPHLOSION",
      "TORCHIC", "COMBUSKEN", "BLAZIKEN",
    },
    HYDRO_CANNON = {
      "SQUIRTLE", "WARTORTLE", "BLASTOISE",
      "TOTODILE", "CROCONAW", "FERALIGATR",
      "MUDKIP", "MARSHTOMP", "SWAMPERT",
    },
  }
  local external = {
    FRENZY_PLANT = {
      "TECH_EXT_TREECKO", "TECH_EXT_GROVYLE", "TECH_EXT_SCEPTILE",
    },
    BLAST_BURN = {
      "TECH_EXT_TORCHIC", "TECH_EXT_COMBUSKEN", "TECH_EXT_BLAZIKEN",
    },
    HYDRO_CANNON = {
      "TECH_EXT_MUDKIP", "TECH_EXT_MARSHTOMP", "TECH_EXT_SWAMPERT",
    },
  }
  local machines = {
    FRENZY_PLANT = {
      item = "TM_FRENZY_PLANT", number = 51, gym = "erika",
      proofSpecies = "TREECKO",
    },
    BLAST_BURN = {
      item = "TM_BLAST_BURN", number = 52, gym = "blaine",
      proofSpecies = "TORCHIC",
    },
    HYDRO_CANNON = {
      item = "TM_HYDRO_CANNON", number = 53, gym = "misty",
      proofSpecies = "MUDKIP",
    },
  }

  local function hasMove(def, moveId)
    for _, id in ipairs(def and def.tmhm or {}) do
      if id == moveId then return true end
    end
    return false
  end

  local function monHasMove(mon, moveId)
    for _, move in ipairs(mon and mon.moves or {}) do
      if move.id == moveId then return true end
    end
    return false
  end

  local function hasReminder(mon, moveId)
    for _, row in ipairs(tech.reminderMoves(game, mon)) do
      if row.id == moveId and row.source == "crown" then return true end
    end
    return false
  end

  local function exactStatus(provider, stages)
    local status = tech.starterFamilyStatus()
    assert(status.activeProvider == provider,
      "unexpected active Hoenn provider: " .. tostring(status.activeProvider))
    assert(status.totalStages == stages * 3
        and status.generations == (stages == 9 and 3 or 2),
      "starter-family generation/cardinality drift")
    for _, moveId in ipairs(order) do
      assert(status.cardinality[moveId] == stages
          and #tech.starterFamilies[moveId] == stages,
        moveId .. " is not exactly " .. tostring(stages) .. " stages")
    end
    return status
  end

  local initialStatus = exactStatus("registered_hoenn_252_260", 9)
  assert(initialStatus.providers.registered_hoenn_252_260
      and initialStatus.providers.registered_hoenn_252_260.status == "active"
      and initialStatus.providers.registered_hoenn_252_260.stages == 9,
    "installed canonical Hoenn provider status is not exact and active")

  -- Exercise a genuinely separate package-runtime provider with different
  -- internal ids. Its definitions are disposable aliases of the installed
  -- content, preserving National Dex identity while proving the public seam
  -- does not depend on who owns #252-260.
  local pokemon = game.data.pokemon
  local canonical, aliases = {}, {}
  local signatureSet = {
    FRENZY_PLANT = true, BLAST_BURN = true, HYDRO_CANNON = true,
  }
  for _, moveId in ipairs(order) do
    for index = 7, 9 do
      local canonicalId = expected[moveId][index]
      local aliasId = external[moveId][index - 6]
      local original = assert(pokemon[canonicalId],
        canonicalId .. " missing from installed registry")
      canonical[canonicalId] = original
      local alias = {}
      for key, value in pairs(original) do alias[key] = value end
      alias.id, alias.dex = aliasId, original.dex
      alias.tmhm = {}
      for _, id in ipairs(original.tmhm or {}) do
        if not signatureSet[id] then alias.tmhm[#alias.tmhm + 1] = id end
      end
      aliases[aliasId] = alias
      pokemon[aliasId] = alias
    end
  end
  assert(tech.registerStarterFamilyProvider(
      "qa_external_hoenn_252_260", function(context)
        assert(context.data == game.data
            and type(context.getPokemon) == "function",
          "external provider did not receive the live merged registry")
        return { generation = "hoenn", families = external }
      end), "external package-runtime provider registration failed")

  for canonicalId in pairs(canonical) do pokemon[canonicalId] = nil end
  local missingAlias = "TECH_EXT_SWAMPERT"
  local missingDef = pokemon[missingAlias]
  pokemon[missingAlias] = nil
  assert(not tech.syncStarterFamilies(game.data),
    "partial external Hoenn provider did not fail closed")
  local partialStatus = exactStatus(nil, 6)
  assert(partialStatus.providers.qa_external_hoenn_252_260
      and partialStatus.providers.qa_external_hoenn_252_260.status == "invalid",
    "partial external provider lacks an invalid diagnostic")
  for _, moveId in ipairs(order) do
    for _, species in ipairs(external[moveId]) do
      if pokemon[species] then
        assert(not hasMove(pokemon[species], moveId),
          "partial external provider leaked compatibility to " .. species)
      end
    end
  end

  pokemon[missingAlias] = missingDef
  assert(tech.syncStarterFamilies(game.data),
    "completed external Hoenn provider did not activate")
  exactStatus("qa_external_hoenn_252_260", 9)
  for _, moveId in ipairs(order) do
    for _, species in ipairs(external[moveId]) do
      assert(hasMove(pokemon[species], moveId),
        "completed external provider omitted compatibility for " .. species)
    end
  end

  pokemon[missingAlias] = nil
  assert(not tech.syncStarterFamilies(game.data),
    "active external provider did not roll back after losing one stage")
  exactStatus(nil, 6)
  for _, moveId in ipairs(order) do
    for _, species in ipairs(external[moveId]) do
      if pokemon[species] then
        assert(not hasMove(pokemon[species], moveId),
          "deactivated external provider retained compatibility for " .. species)
      end
    end
  end
  pokemon[missingAlias] = missingDef
  assert(tech.syncStarterFamilies(game.data),
    "external provider did not reactivate after its stage returned")
  exactStatus("qa_external_hoenn_252_260", 9)

  -- Restore the package registry exactly before exercising player state.
  for canonicalId, def in pairs(canonical) do pokemon[canonicalId] = def end
  assert(tech.syncStarterFamilies(game.data),
    "canonical installed provider did not restore")
  local restoredStatus = exactStatus("registered_hoenn_252_260", 9)
  assert(restoredStatus.providers.qa_external_hoenn_252_260
      and restoredStatus.providers.qa_external_hoenn_252_260.status == "shadowed",
    "restored canonical provider did not shadow the optional provider")
  for aliasId in pairs(aliases) do pokemon[aliasId] = nil end

  -- Use a native fresh save for this isolated edition. The public Crown-win
  -- callback must create each TM entitlement and BAG transaction; the real
  -- Reminder callback must then teach the corresponding installed Pokémon.
  local fresh = SaveData.newGame(game:bootConfig())
  game:restoreSave(fresh, false)
  tech.syncStarterFamilies(game.data)
  local proofMons = {}
  for _, moveId in ipairs(order) do
    local machine = machines[moveId]
    local mon = Pokemon.new(game.data, machine.proofSpecies, 50,
      function(_, high) return high end)
    mon.moves = {}
    proofMons[#proofMons + 1] = mon
    assert(not hasReminder(mon, moveId),
      machine.proofSpecies .. " had a Crown move before the real award")
  end
  game.save.party = proofMons

  local tmTransactions, reminderTransactions = 0, 0
  for index, moveId in ipairs(order) do
    local machine = machines[moveId]
    local move = assert(game.data.moves[moveId], moveId .. " move missing")
    assert(move.power == 150 and move.accuracy == 90 and move.pp == 5,
      moveId .. " battle definition drifted")
    local item = assert(game.data.items[machine.item],
      machine.item .. " item missing")
    assert(item.machine and item.machine.kind == "TM"
        and item.machine.move == moveId
        and item.machine.number == machine.number,
      machine.item .. " machine definition drifted")
    local before = game.save.inventory[machine.item] or 0
    local awardText = tech.afterBossWin(game, machine.gym, "crown")
    local transactionState = tech.state()
    assert(type(awardText) == "string"
        and (game.save.inventory[machine.item] or 0) == before + 1
        and transactionState.signatureUnlocked[machine.item] == true
        and transactionState.signatureAwarded[machine.item] == true,
      machine.item .. " Crown transaction was not committed")
    tmTransactions = tmTransactions + 1

    local mon = proofMons[index]
    assert(hasReminder(mon, moveId),
      machine.proofSpecies .. " lacks its unlocked Crown Reminder row")
    local learned, why = tech.rememberMove(game, mon, moveId)
    assert(learned and why == nil and monHasMove(mon, moveId),
      machine.proofSpecies .. " Reminder transaction failed: " .. tostring(why))
    reminderTransactions = reminderTransactions + 1
  end
  assert(#tech.state().pendingTMs == 0,
    "Crown TM transactions unexpectedly bypassed the BAG")

  assert(game:writeSave(), "TECH-001 native save write failed")
  local reloaded, recovered = SaveData.load(edition)
  assert(reloaded and recovered == nil, "TECH-001 native save load failed")
  game:restoreSave(reloaded, recovered)
  U.wait(3)

  local savedState = tech.state()
  local persistedItems, persistedMoves, persistedReminder = 0, 0, 0
  for index, moveId in ipairs(order) do
    local machine = machines[moveId]
    assert(savedState.signatureUnlocked[machine.item] == true
        and savedState.signatureAwarded[machine.item] == true,
      machine.item .. " entitlement did not survive native reload")
    if (game.save.inventory[machine.item] or 0) == 1 then
      persistedItems = persistedItems + 1
    end
    local savedMon = assert(game.save.party[index],
      machine.proofSpecies .. " was lost during native reload")
    assert(savedMon.species == machine.proofSpecies,
      "native reload reordered the TECH-001 proof party")
    if monHasMove(savedMon, moveId) then persistedMoves = persistedMoves + 1 end
    local reminderProbe = Pokemon.new(game.data, machine.proofSpecies, 50,
      function(_, high) return high end)
    reminderProbe.moves = {}
    if hasReminder(reminderProbe, moveId) then
      persistedReminder = persistedReminder + 1
    end
  end
  assert(persistedItems == 3 and persistedMoves == 3
      and persistedReminder == 3,
    "TECH-001 Crown transactions did not survive native save/reload")

  local unique, stages, compatible, reminderCoverage = {}, 0, 0, 0
  for _, moveId in ipairs(order) do
    local family = assert(tech.starterFamilies[moveId],
      moveId .. " family missing after native reload")
    assert(#family == 9, moveId .. " lost exact nine-stage cardinality")
    for index, species in ipairs(expected[moveId]) do
      assert(family[index] == species,
        moveId .. " stage order drifted at " .. tostring(index))
      assert(not unique[species], "duplicate eligible stage " .. species)
      unique[species] = true
      stages = stages + 1
      assert(hasMove(game.data.pokemon[species], moveId),
        species .. " lacks installed " .. moveId .. " TM compatibility")
      compatible = compatible + 1
      local reminderMon = Pokemon.new(game.data, species, 100,
        function(_, high) return high end)
      reminderMon.moves = {}
      assert(hasReminder(reminderMon, moveId),
        species .. " lacks its persisted Crown Reminder row")
      reminderCoverage = reminderCoverage + 1
    end
  end
  local uniqueCount = 0
  for _ in pairs(unique) do uniqueCount = uniqueCount + 1 end
  assert(stages == 27 and uniqueCount == 27 and compatible == 27
      and reminderCoverage == 27,
    "installed TECH-001 totals are not exact 27/27/27/27")

  local out = assert(io.open(dir .. "/driver_result.txt", "wb"),
    "could not write TECH-001 package receipt")
  out:write("status=PASS\n")
  out:write("scope=TECH-001-STARTER-SIGNATURES\n")
  out:write("authority=Authority-main/LOVE/package\n")
  out:write("edition=", edition, "\n")
  out:write("provider=registered_hoenn_252_260\n")
  out:write("external_provider=qa_external_hoenn_252_260\n")
  out:write("external_partial_fail_closed=18/18\n")
  out:write("external_complete=27/27\n")
  out:write("external_reactivation=27/27\n")
  out:write("canonical_restored=27/27\n")
  out:write("generations=3/3\n")
  out:write("cardinality=9/9/9\n")
  out:write("stages=27/27\n")
  out:write("unique_stages=27/27\n")
  out:write("tm_definitions=3/3\n")
  out:write("tm_compatibility=27/27\n")
  out:write("reminder=", tostring(reminderCoverage), "/27\n")
  out:write("tm_transactions=", tostring(tmTransactions), "/3\n")
  out:write("reminder_transactions=", tostring(reminderTransactions), "/3\n")
  out:write("native_save_reload=1/1\n")
  out:write("persisted_tm_inventory=", tostring(persistedItems), "/3\n")
  out:write("persisted_reminder_moves=", tostring(persistedMoves), "/3\n")
  out:write("persisted_reminder_access=", tostring(persistedReminder), "/3\n")
  for key, value in pairs(receipts) do out:write(key, "=", value, "\n") end
  out:write("fail=0\n")
  out:close()
  U.log("PASS", "TECH-001 " .. edition
    .. " external-provider and native-save package acceptance")
  love.event.quit(0)
end
