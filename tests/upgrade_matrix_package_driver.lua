-- Package-only 6.0.11 / RC25 / RC26 / RC27 upgrade acceptance.
--
-- One cell runs four clean LÖVE processes against a single native slot:
--   stage      mount the real historical archive and write its honest,
--              schema-derived fixture through SaveData.writeSlot;
--   migrate    load it under the current package, exercise rules, native
--              reload, failed-write recovery, backup rollback, then disable;
--   disabled   load/save with Authority disabled and prove quarantine;
--   reenabled  load again with Authority enabled and prove exact restoration.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "base_deutsch",
    "upgrade matrix requires the reviewed base/deutsch closure")

  local phase = assert(os.getenv("QA_UPGRADE_PHASE"),
    "QA_UPGRADE_PHASE is required")
  assert(phase == "stage" or phase == "migrate"
      or phase == "disabled" or phase == "reenabled",
    "unknown upgrade phase: " .. tostring(phase))
  local sourceKey = assert(os.getenv("QA_UPGRADE_SOURCE"),
    "QA_UPGRADE_SOURCE is required")

  local harnessRoot = assert(os.getenv("GEN1RECOMP_DIR"),
    "GEN1RECOMP_DIR packaged harness root is required")
  assert(harnessRoot:sub(1, 1) == "/"
      and harnessRoot:sub(-#"/qa_harness") == "/qa_harness"
      and not harnessRoot:find(".worktrees", 1, true)
      and not harnessRoot:find("/Documents/Recompile/", 1, true),
    "GEN1RECOMP_DIR is not the immutable package harness")
  local immutableRoot = harnessRoot
    .. "/immutable_inputs/upgrade_sources/"
  local fixturePath = immutableRoot .. "upgrade_package_sources.lua"
  local sources = dofile(fixturePath)
  local source = assert(sources[sourceKey],
    "unknown historical source fixture: " .. tostring(sourceKey))
  assert(source.provenance.kind == "schema-derived-sanitized"
      and source.provenance.publishedSave == false
      and source.provenance.containsPlayerPII == false,
    "historical fixture provenance is not honest/fail-closed")

  local archivePath = immutableRoot .. source.archiveName

  local function requiredSha(name)
    local value = os.getenv(name)
    assert(type(value) == "string" and #value == 64
        and value:match("^[0-9a-f]+$"),
      name .. " must be a lowercase SHA256 receipt")
    return value
  end
  requiredSha("KA_ENGINE_PAYLOAD_SHA256")
  requiredSha("KA_AUTHORITY_PACKAGE_SHA256")
  requiredSha("KA_DEUTSCH_PACKAGE_SHA256")
  requiredSha("KA_PACKAGE_GATE_RECEIPT_SHA256")

  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local LauncherMods = require("src.mods.LauncherMods")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local Json = require("src.link.Json")

  local edition = GameVersion.get()
  assert(edition == os.getenv("POKEPORT_VERSION")
      and (edition == "red" or edition == "blue" or edition == "yellow"),
    "upgrade matrix must run against requested Red, Blue or Yellow")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")
  assert(identity:find("upgrade%-matrix", 1, false)
      and not identity:find(".worktrees", 1, true),
    "upgrade matrix requires a fresh isolated package identity")
  local slot = "slot65upgrade_" .. sourceKey .. "_" .. edition
  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve native upgrade slot")

  local languageId = ({
    red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb",
  })[edition]
  local registry = assert(game.mods and game.mods.mods,
    "installed package registry unavailable")
  local authorityRow = assert(registry.kanto_ascendant,
    "Authority package is not physically installed")
  local languageRow = assert(registry[languageId],
    "edition language package is not physically installed")
  local expectedRows = { kanto_ascendant = true, [languageId] = true }
  local registryCount = 0
  for id in pairs(registry) do
    registryCount = registryCount + 1
    assert(expectedRows[id], "unexpected package in upgrade closure: " .. id)
  end
  assert(registryCount == 2,
    "upgrade closure must contain exactly Authority plus edition language")
  for _, path in ipairs({
      tostring(love.filesystem.getSource() or ""),
      tostring(authorityRow.path or ""), tostring(languageRow.path or ""),
    }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true),
      "source/worktree path is not package evidence: " .. path)
  end

  local authorityActive = phase ~= "disabled"
  local authorityExport = game.mods.exports
    and game.mods.exports.kanto_ascendant
  if authorityActive then
    assert(authorityRow.enabled ~= false and authorityRow.state ~= "disabled"
        and authorityExport,
      "Authority must be active in " .. phase)
  else
    assert((authorityRow.enabled == false or authorityRow.state == "disabled")
        and authorityExport == nil,
      "disabled pass unexpectedly loaded Authority")
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do
      out[copy(key, seen)] = copy(child, seen)
    end
    return out
  end

  local function boxes()
    local out = {}
    for index = 1, 12 do out[index] = {} end
    return out
  end

  local function protectedSnapshot(save)
    return SaveData.encode({
      version = save.version,
      player = save.player,
      flags = save.flags,
      inventory = save.inventory,
      pcItems = save.pcItems,
      bagOrder = save.bagOrder,
      party = save.party,
      boxes = save.boxes,
      currentBox = save.currentBox,
      money = save.money,
      defeatedTrainers = save.defeatedTrainers,
      pokedex = save.pokedex,
      hallOfFame = save.hallOfFame,
      lastHeal = save.lastHeal,
      lastOutdoor = save.lastOutdoor,
    })
  end

  local function stableSnapshot(save)
    return SaveData.encode({
      version = save.version,
      player = save.player,
      flags = save.flags,
      pcItems = save.pcItems,
      party = save.party,
      money = save.money,
      defeatedTrainers = save.defeatedTrainers,
      hallOfFame = save.hallOfFame,
      lastHeal = save.lastHeal,
      lastOutdoor = save.lastOutdoor,
    })
  end

  local function inspectHistoricalArchive()
    local file = assert(io.open(archivePath, "rb"),
      "historical archive is not readable inside the package harness")
    local bytes = file:read("*a")
    file:close()
    assert(type(bytes) == "string" and #bytes == source.archiveBytes,
      "historical archive byte count drifted")
    local fd = assert(love.filesystem.newFileData(bytes,
      "upgrade_" .. sourceKey .. ".zip"))
    local mount = "upgrade_source_" .. sourceKey
    assert(love.filesystem.mount(fd, mount),
      "historical archive could not be mounted read-only")
    local rawManifest = assert(love.filesystem.read(mount .. "/manifest.json"),
      "historical archive lacks manifest.json")
    local manifest, manifestErr = Json.decode(rawManifest)
    assert(manifest, "historical manifest is invalid: " .. tostring(manifestErr))
    assert(manifest.id == source.manifestId
        and manifest.version == source.manifestVersion,
      "historical manifest identity/version drifted")
    local schema = assert(love.filesystem.read(
      mount .. "/" .. source.schemaEntry),
      "historical schema entry is missing")
    assert(#schema == source.schemaEntryBytes,
      "historical schema entry byte count drifted")
    for _, marker in ipairs(source.schemaMarkers) do
      assert(schema:find(marker, 1, true),
        "historical schema marker missing: " .. marker)
    end
    local runRules = love.filesystem.getInfo(mount .. "/run_rules.lua")
    assert((runRules ~= nil) == source.runRulesEntry,
      "historical run-rules entry presence drifted")
    assert(love.filesystem.unmount(fd),
      "historical archive could not be unmounted")
    return true
  end

  local function sourceSave()
    local save = SaveData.newGame(game:bootConfig())
    save.version = edition
    save.player.name = ("UP%s%s"):format(
      edition:sub(1, 1):upper(), sourceKey:gsub("[^A-Za-z0-9]", "")):sub(1, 10)
    save.player.rival = "MATRIX"
    save.player.id = 6500 + ({ red = 1, blue = 2, yellow = 3 })[edition]
    save.player.map, save.player.x, save.player.y = "REDS_HOUSE_2F", 3, 6
    save.player.facing = "up"
    -- Native OverworldController:captureSave always serializes this RAM
    -- state as an explicit boolean.  Seed the schema-derived fixture in the
    -- same canonical shape so a successful save/.bak recovery is compared
    -- with its truthful native round-trip, not nil versus false.
    save.player.surfing = false
    save.flags = {
      EVENT_GOT_STARTER = true,
      EVENT_GOT_POKEDEX = true,
      [edition == "yellow" and "EVENT_CHOSE_PIKACHU"
        or "EVENT_CHOSE_BULBASAUR"] = true,
    }
    local vanillaMon = Pokemon.new(game.data, "RATTATA", 31,
      function(_, high) return high end)
    vanillaMon.marker = "upgrade-vanilla-party"
    BattleState.stampOT(save, vanillaMon)
    local modMon = Pokemon.new(game.data, "CHIKORITA", 18,
      function(_, high) return high end)
    modMon.marker = "upgrade-mod-box"
    BattleState.stampOT(save, modMon)
    save.party = { vanillaMon }
    save.boxes = boxes()
    save.box = nil
    save.currentBox = 1
    save.boxes[1][1] = modMon
    save.inventory = { POKE_BALL = 17, MEGA_RING = 1 }
    save.pcItems = { POTION = 1 }
    save.bagOrder = { "POKE_BALL", "MEGA_RING" }
    save.money = 53151
    save.defeatedTrainers = { UPGRADE_MATRIX_VANILLA = true }
    save.pokedex = {
      seen = { RATTATA = true, CHIKORITA = true },
      owned = { RATTATA = true, CHIKORITA = true },
    }
    save.hallOfFame = { { source = sourceKey, edition = edition } }
    save.modData = {
      [source.saveNamespace] = copy(source.sourceBucket),
    }
    save.meta = {
      format = save.meta.format,
      engine = "schema-derived-fixture",
      mods = {
        { id = source.manifestId, version = source.manifestVersion, api = 2 },
      },
    }
    save.options = nil
    local activeReport = SaveData.validate(save, game.data)
    assert(#activeReport.lostMons == 0 and #activeReport.lostItems == 0,
      "current installed data cannot represent the staged source fixture")
    save._upgradeMatrix = {
      schema = "ka-upgrade-package/v1",
      source = sourceKey,
      edition = edition,
      provenance = source.provenance.kind,
      publishedSave = source.provenance.publishedSave,
      archiveSha256 = source.archiveSha256,
      phase = "staged",
      protectedBaseline = protectedSnapshot(save),
      stableBaseline = stableSnapshot(save),
      modMon = SaveData.encode(modMon),
      modItem = "MEGA_RING",
      modItemCount = 1,
      receipts = { archive = true, nativeStageWrite = true },
    }
    return save
  end

  local function loadNative()
    local loaded, recovered = SaveData.load(edition)
    assert(loaded, "native upgrade slot did not load")
    game:restoreSave(loaded, recovered)
    return recovered
  end

  local function marker()
    local value = assert(game.save and game.save._upgradeMatrix,
      "upgrade phase marker missing from native save")
    assert(value.schema == "ka-upgrade-package/v1"
        and value.source == sourceKey and value.edition == edition
        and value.archiveSha256 == source.archiveSha256,
      "upgrade marker source/edition/archive drifted")
    return value
  end

  local function clearMenus()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  local function canonicalBucket()
    return assert(game.save.modData
      and game.save.modData.kanto_ascendant,
      "current namespace did not receive the historical bucket")
  end

  local function assertSourceProgress(bucket)
    assert(bucket.step_clock == source.sourceBucket.step_clock,
      "historical step clock was not preserved")
    assert(bucket.ascendant and bucket.ascendant.rank
        == source.sourceBucket.ascendant.rank,
      "historical Ascendant rank was not preserved")
    assert(bucket.trainers and bucket.trainers.ROUTE_1_obj_1
        and bucket.trainers.ROUTE_1_obj_1.rematches
          == source.sourceBucket.trainers.ROUTE_1_obj_1.rematches,
      "historical rematch progress was not preserved")
  end

  local function injectFailedSave()
    local tmpName = SaveData.saveFilename(edition) .. ".tmp"
    local originalWrite = love.filesystem.write
    local injected = false
    love.filesystem.write = function(name, data, ...)
      if name == tmpName then
        injected = true
        return false, "injected upgrade-matrix staged-write failure"
      end
      return originalWrite(name, data, ...)
    end
    game.save._upgradeMatrix.uncommittedWrite = true
    local ok = game:writeSave()
    love.filesystem.write = originalWrite
    assert(injected and ok == false,
      "failed native write injection did not reach SaveData")
    loadNative()
    assert(marker().uncommittedWrite == nil,
      "failed native write leaked uncommitted state")
    assert(protectedSnapshot(game.save) == marker().protectedBaseline,
      "failed native write changed protected player data")
    marker().receipts.failedWriteRollback = true
  end

  local function exerciseRules()
    local api = assert(game.mods.exports.kanto_ascendant,
      "current Authority exports unavailable")
    local rules = assert(api.runRules, "run-rules controller unavailable")
    local state = assert(rules.state(game.save), "run-rules state unavailable")
    assert(state.version == 2,
      "historical rule schema did not migrate to version 2")
    if source.expectedInitialRuleState == "unlocked" then
      assert(state.locked == false and state.configured == false
          and state.legacyProgress == true,
        "unconfirmed historical rules did not reopen safely")
      if sourceKey == "rc25" then
        assert(state.migrationNoticePending == true,
          "RC25 reasonless lock did not schedule its migration notice")
      end
      rules.open(game)
      local menu = assert(game.stack:top(), "run-rules menu did not open")
      local randomizerBefore = state.randomizer.enabled
      menu.onChoose(menu.items[2], menu)
      assert(state.randomizer.enabled ~= randomizerBefore,
        "unlocked historical Randomizer rule was not selectable")
      local modeBefore = state.nuzlocke.mode
      menu.onChoose(menu.items[3], menu)
      assert(state.nuzlocke.mode ~= modeBefore,
        "unlocked historical Nuzlocke rule was not selectable")
      menu.onChoose(menu.items[7], menu)
      local confirmation = assert(game.stack:top(),
        "run start did not open a default-NO confirmation")
      assert(type(confirmation.choice) == "function"
          and confirmation.defaultNo == true,
        "historical rule lock confirmation is not fail-safe")
      game.stack:pop()
      confirmation.choice(true)
      state = rules.state(game.save)
      assert(state.locked == true and state.configured == true
          and state.lockReason == "player_pc",
        "confirmed historical rules did not lock durably")
      marker().receipts.ruleUnlock = true
    else
      assert(state.locked == true and state.configured == true
          and state.lockReason == "player_pc"
          and state.randomizer.enabled == true
          and state.nuzlocke.mode == "standard",
        "confirmed historical rules were not preserved")
      local before = SaveData.encode(state)
      rules.open(game)
      local menu = assert(game.stack:top(), "locked run-rules menu did not open")
      assert(menu.footer and (menu.footer:find("READ%-ONLY")
          or menu.footer:find("NUR LESBAR", 1, true)),
        "confirmed historical rules are not visibly read-only")
      menu.onChoose(menu.items[2], menu)
      assert(SaveData.encode(state) == before,
        "locked Randomizer rule changed")
      if game.stack:top() ~= menu then game.stack:pop() end
      menu.onChoose(menu.items[3], menu)
      assert(SaveData.encode(state) == before,
        "locked Nuzlocke rule changed")
      if game.stack:top() ~= menu then game.stack:pop() end
      assert(game:writeSave(), "confirmed-rule native save failed")
      marker().receipts.ruleLock = true
    end
    clearMenus()
    return rules
  end

  if phase == "stage" then
    assert(authorityActive and inspectHistoricalArchive(),
      "historical package inspection failed")
    local raw = sourceSave()
    assert(SaveData.writeSlot(edition, slot, raw),
      "native historical fixture write failed")
    local options = SaveData.loadOptions()
    options.modOptions = options.modOptions or {}
    options.modOptions.trainer_rematch = nil
    options.modOptions.kanto_ascendant = nil
    options.modOptions[source.optionNamespace] = copy(source.options)
    assert(SaveData.saveOptions(options),
      "historical option fixture write failed")
    love.event.quit(0)
    return
  end

  if phase == "migrate" then
    assert(inspectHistoricalArchive(), "historical package inspection failed")
    assert(loadNative() == nil, "fresh historical slot required recovery")
    local receipt = marker()
    assert(receipt.phase == "staged"
        and receipt.provenance == "schema-derived-sanitized"
        and receipt.publishedSave == false,
      "staged provenance receipt drifted")
    assert(protectedSnapshot(game.save) == receipt.protectedBaseline,
      "current migration changed protected player data")
    assert(stableSnapshot(game.save) == receipt.stableBaseline,
      "current migration changed stable player data")
    local canonical = canonicalBucket()
    assertSourceProgress(canonical)
    local options = assert(game.mods.modOptions
      and game.mods.modOptions.kanto_ascendant,
      "current option namespace unavailable")
    assert(options.kanto_151 == source.options.kanto_151
        and options.follower_count == source.options.follower_count,
      "historical options did not reach the current namespace")

    injectFailedSave()
    receipt = marker()
    -- The injected write above deliberately reloads the last durable save.
    -- Receipt the already-proven option assertion only after that rollback so
    -- the next normal native save persists it instead of the failed-write
    -- probe correctly discarding it as uncommitted state.
    receipt.receipts.optionMigration = true
    local rules = exerciseRules()
    assert(game:writeSave(), "migrated current save write failed")
    local rollback = assert(game.save.modData.trainer_rematch,
      "rollback namespace was not written")
    assert(SaveData.encode(rollback) == SaveData.encode(canonicalBucket())
        and rollback ~= canonicalBucket(),
      "rollback namespace is not an independent exact shadow")
    receipt = marker()
    receipt.receipts.rollbackShadow = true
    receipt.receipts.nativeReload = true
    assert(game:writeSave(), "pre-backup upgrade receipt write failed")
    receipt = marker()

    -- A newer successful write creates the native .bak. Corrupting main must
    -- promote that last-good backup and discard the newer QA-only marker.
    receipt.backupCandidate = true
    assert(game:writeSave(), "backup candidate write failed")
    assert(love.filesystem.write(SaveData.saveFilename(edition),
      "return { deliberately_corrupt ="),
      "could not inject isolated main-save corruption")
    local recovered = loadNative()
    assert(recovered == "bak" and marker().backupCandidate == nil,
      "native backup rollback did not restore the last-good save")
    assert(protectedSnapshot(game.save) == marker().protectedBaseline,
      "backup rollback changed protected player data")
    local finalRules = assert(rules.state(game.save),
      "rules unavailable after backup rollback")
    assert(finalRules.locked == true and finalRules.configured == true,
      "rule lock did not survive native backup rollback")
    receipt = marker()
    receipt.phase = "active_complete"
    receipt.canonicalBeforeDisable = SaveData.encode(canonicalBucket())
    receipt.finalRuleMode = source.expectedInitialRuleState
    receipt.receipts.backupRollback = true
    receipt.receipts.migration = true
    assert(game:writeSave(), "active upgrade receipt write failed")

    assert(LauncherMods.setEnabled("kanto_ascendant", false, edition) == true,
      "native launcher failed to disable Authority")
    local disabledOptions = SaveData.loadOptions()
    assert(SaveData.modEnabled(disabledOptions, "kanto_ascendant",
        SaveData.modScope(edition)) == false,
      "Authority disable did not persist for this edition")
    love.event.quit(0)
    return
  end

  if phase == "disabled" then
    loadNative()
    local receipt = marker()
    assert(receipt.phase == "active_complete",
      "disabled pass did not receive the migrated current save")
    assert(stableSnapshot(game.save) == receipt.stableBaseline,
      "disabled load changed vanilla/stable player data")
    assert(SaveData.encode(game.save.modData.kanto_ascendant)
        == receipt.canonicalBeforeDisable,
      "disabled load changed preserved canonical mod data")
    assert(SaveData.encode(game.save.modData.trainer_rematch)
        == receipt.canonicalBeforeDisable,
      "disabled load changed the rollback shadow")
    local report = assert(game.saveReport,
      "disabled load did not expose a quarantine report")
    assert(#report.lostMons == 1 and #report.lostItems == 1,
      "disabled load did not quarantine exactly one mod mon and item")
    assert(game.save.orphaned and #game.save.orphaned.mons == 1
        and #game.save.orphaned.items == 1,
      "disabled quarantine payload cardinality drifted")
    assert(SaveData.encode(game.save.orphaned.mons[1]) == receipt.modMon,
      "disabled quarantine changed the complete mod Pokémon")
    assert(game.save.orphaned.items[1].id == receipt.modItem
        and game.save.orphaned.items[1].count == receipt.modItemCount,
      "disabled quarantine changed the mod item transaction")
    receipt.phase = "disabled_complete"
    receipt.receipts.disableSave = true
    receipt.receipts.quarantine = true
    assert(game:writeSave(), "native disabled-state save failed")
    assert(LauncherMods.setEnabled("kanto_ascendant", true, edition) == true,
      "native launcher failed to re-enable Authority")
    local enabledOptions = SaveData.loadOptions()
    assert(SaveData.modEnabled(enabledOptions, "kanto_ascendant",
        SaveData.modScope(edition)) ~= false,
      "Authority re-enable did not persist for this edition")
    love.event.quit(0)
    return
  end

  assert(phase == "reenabled")
  loadNative()
  local receipt = marker()
  assert(receipt.phase == "disabled_complete",
    "re-enabled pass did not receive the disabled-save transaction")
  local report = assert(game.saveReport,
    "re-enabled load did not expose a restoration report")
  assert(#report.restoredMons == 1 and #report.restoredItems == 1
      and #report.lostMons == 0 and #report.lostItems == 0,
    "re-enabled load did not restore exactly one mod mon and item")
  assert(game.save.orphaned == nil,
    "successful re-enable left quarantine residue")
  assert(protectedSnapshot(game.save) == receipt.protectedBaseline,
    "disable/save/re-enable did not restore exact player data")
  assert(stableSnapshot(game.save) == receipt.stableBaseline,
    "disable/save/re-enable changed stable player data")
  local canonical = canonicalBucket()
  assertSourceProgress(canonical)
  local rules = assert(game.mods.exports.kanto_ascendant.runRules)
  local finalRules = assert(rules.state(game.save))
  assert(finalRules.locked == true and finalRules.configured == true,
    "final rule lock did not survive disable/save/re-enable")
  assert(game:writeSave(), "final restored save write failed")
  assert(SaveData.encode(game.save.modData.trainer_rematch)
      == SaveData.encode(canonicalBucket()),
    "final write did not refresh the exact rollback shadow")

  receipt = marker()
  receipt.phase = "complete"
  receipt.receipts.reenableRestore = true
  receipt.receipts.dataEquality = true
  receipt.receipts.finalNativeWrite = true
  assert(game:writeSave(), "final upgrade matrix receipt write failed")

  for _, key in ipairs({
      "archive", "nativeStageWrite", "optionMigration",
      "failedWriteRollback", "rollbackShadow", "nativeReload",
      "backupRollback", "migration", "disableSave", "quarantine",
      "reenableRestore", "dataEquality", "finalNativeWrite",
    }) do
    assert(receipt.receipts[key] == true,
      "missing persisted upgrade receipt: " .. key)
  end
  if source.expectedInitialRuleState == "unlocked" then
    assert(receipt.receipts.ruleUnlock == true,
      "unlocked historical rule transaction was not receipted")
  else
    assert(receipt.receipts.ruleLock == true,
      "confirmed historical rule preservation was not receipted")
  end

  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local out = assert(io.open(dir .. "/driver_result.txt", "wb"),
    "could not write upgrade matrix result")
  out:write("status=PASS\n")
  out:write("scope=UPGRADE-MATRIX-PACKAGE\n")
  out:write("edition=", edition, "\n")
  out:write("source=", sourceKey, "\n")
  out:write("provenance=schema-derived-sanitized\n")
  out:write("published_save=false\n")
  out:write("archive_sha256=", source.archiveSha256, "\n")
  out:write("archive_verified=1/1\n")
  out:write("migration=1/1\n")
  out:write("initial_rules=", source.expectedInitialRuleState, "\n")
  out:write("rules_select_or_preserve=1/1\n")
  out:write("final_rule_lock=1/1\n")
  out:write("native_save_reload=1/1\n")
  out:write("failed_write_rollback=1/1\n")
  out:write("backup_rollback=1/1\n")
  out:write("rollback_shadow=1/1\n")
  out:write("disable_quarantine=2/2\n")
  out:write("reenable_restore=2/2\n")
  out:write("data_equality=1/1\n")
  out:write("fail=0\n")
  out:close()
  love.event.quit(0)
end
