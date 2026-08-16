-- Package-only transactional contract for the durable Legacy archive.
--
-- The factory is read from the installed Authority package, never from the
-- source tree or QA harness.  A deterministic in-memory filesystem injects
-- failures at the same witness/primary boundaries used by the real archive;
-- this lets the cell prove byte-stable rollback, committed-witness recovery,
-- exact-once retry and v1 -> current migration without risking a user file.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "base_deutsch",
    "Legacy archive transaction contract requires base/deutsch")
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

  local GameVersion = require("src.core.GameVersion")
  local Serializer = require("src.core.SaveSerializer")
  local edition = GameVersion.get()
  assert(edition == "red" and os.getenv("POKEPORT_VERSION") == "red",
    "Legacy archive transaction cell is frozen to Red")
  assert(os.getenv("POKEPORT_IDENTITY") ==
      "ka65-final-legacy-archive-transaction",
    "Legacy archive transaction cell requires its exact isolated identity")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  assert(dir:sub(1, 1) == "/" and not dir:find(".worktrees", 1, true)
      and not dir:find("/Documents/Recompile/", 1, true),
    "source/worktree output is not package evidence")

  local loaded = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local installed = assert(loaded.kanto_ascendant,
    "installed Authority package is missing")
  for _, path in ipairs({ tostring(love.filesystem.getSource() or ""),
      tostring(installed.path or "") }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not installed-package evidence: " .. path)
  end
  assert(type(installed.read) == "function",
    "installed Authority package cannot expose its own archive module")
  local source, readErr = installed:read("legacy_archive.lua")
  assert(type(source) == "string" and source:find("function A.beginJourney", 1,
    true), "installed legacy_archive.lua is missing: " .. tostring(readErr))
  local chunk, compileErr = loadstring(source,
    "@" .. tostring(installed.path) .. "/legacy_archive.lua")
  assert(chunk, "installed Legacy archive does not compile: "
    .. tostring(compileErr))
  local createArchive = assert(chunk(),
    "installed Legacy archive did not return its factory")

  local function memoryFs()
    local fs = { files = {}, writes = {}, failAt = {} }
    function fs.getInfo(path)
      return fs.files[path] ~= nil and { type = "file" } or nil
    end
    function fs.read(path) return fs.files[path] end
    function fs.write(path, bytes)
      fs.writes[path] = (fs.writes[path] or 0) + 1
      if fs.failAt[path] == fs.writes[path] then
        return false, "injected package-contract write failure"
      end
      fs.files[path] = bytes
      return true
    end
    function fs.remove(path) fs.files[path] = nil return true end
    function fs.createDirectory() return true end
    return fs
  end

  local common = {
    serializer = Serializer, edition = "red", modId = "kanto_ascendant",
    pokemonRegistry = game.data.pokemon,
    itemRegistry = game.data.items,
    moveRegistry = game.data.moves,
    requireRegistryValidation = true,
    now = function() return 650013 end,
  }
  local function archiveFor(fs, directory)
    return createArchive({
      fs = fs, serializer = common.serializer, edition = common.edition,
      modId = common.modId, directory = directory,
      pokemonRegistry = common.pokemonRegistry,
      itemRegistry = common.itemRegistry,
      moveRegistry = common.moveRegistry,
      requireRegistryValidation = common.requireRegistryValidation,
      now = common.now,
    })
  end
  local function champion(playerId)
    return {
      version = "red",
      player = { id = playerId, name = "ARCHIVE", rival = "ROLLBACK" },
      flags = { EVENT_BEAT_CHAMPION_RIVAL = true },
      hallOfFame = { { { species = "PIKACHU", level = 50 } } },
      party = { { species = "PIKACHU", level = 50,
        moves = { { id = "TACKLE", pp = 35 } } } },
      boxes = { {} }, inventory = { POTION = 2 }, pcItems = {}, money = 321,
      modData = { kanto_ascendant = {
        extended_characters = { player_character = "RED" },
      } },
    }
  end

  -- Failure before the prepared witness is durable must be a byte-for-byte
  -- no-op on the last-good primary.
  local rollbackFs = memoryFs()
  local rollbackArchive = archiveFor(rollbackFs,
    "package_contract/legacy_rollback")
  local installedSchema = assert(rollbackArchive.normalize({ version = 1 }))
  local currentVersion = assert(installedSchema.version,
    "installed archive normalizer did not expose its current schema")
  assert(currentVersion == 7,
    "v1_to_v7 receipt drifted from the installed archive schema")
  assert(rollbackArchive.write({ version = currentVersion,
    current = {} }), "could not create last-good rollback baseline")
  local primaryBefore = assert(rollbackFs.files[rollbackArchive.filename])
  rollbackFs.failAt[rollbackArchive.filename .. ".tmp"] =
    (rollbackFs.writes[rollbackArchive.filename .. ".tmp"] or 0) + 1
  local rollbackSave = champion(6501)
  local rollbackSaveBefore = Serializer.encode(rollbackSave)
  local rejected, rejectErr = rollbackArchive.beginJourney(rollbackSave, {
    pact = "legacy", bankPolicy = "open", playerAvatar = "RED",
    runRules = rollbackArchive.safeRunRulesSnapshot(rollbackSave),
  })
  assert(rejected == nil and tostring(rejectErr):find("injected", 1, true),
    "injected witness failure was not reported")
  assert(rollbackFs.files[rollbackArchive.filename] == primaryBefore,
    "failed witness write changed the last-good archive primary")
  assert(Serializer.encode(rollbackSave) == rollbackSaveBefore,
    "failed archive write mutated the outgoing game save")
  assert(rollbackArchive.load().cycle == 0,
    "failed witness write advanced the Legacy cycle")

  -- Failure after a committed witness replaces the primary is recoverable.
  -- The following load promotes that exact witness, and retrying the same
  -- source transaction must never duplicate Pokémon, items, money or Hall.
  local recoveryFs = memoryFs()
  local recoveryArchive = archiveFor(recoveryFs,
    "package_contract/legacy_recovery")
  assert(recoveryArchive.write({ version = currentVersion,
    current = {} }), "could not create recovery baseline")
  recoveryFs.failAt[recoveryArchive.filename] =
    (recoveryFs.writes[recoveryArchive.filename] or 0) + 2
  local recoverySave = champion(6502)
  local recoverySaveBefore = Serializer.encode(recoverySave)
  local interrupted, interruptErr = recoveryArchive.beginJourney(recoverySave, {
    pact = "ascendant", bankPolicy = "sealed", playerAvatar = "RED",
    runRules = recoveryArchive.safeRunRulesSnapshot(recoverySave),
  })
  assert(interrupted == nil
      and tostring(interruptErr):find("injected", 1, true),
    "injected primary commit failure was not reported")
  assert(Serializer.encode(recoverySave) == recoverySaveBefore,
    "interrupted archive commit mutated the outgoing game save")
  assert(recoveryFs.files[recoveryArchive.filename] == nil
      and recoveryFs.files[recoveryArchive.filename .. ".tmp"] ~= nil,
    "interrupted commit did not retain its durable witness boundary")
  local recovered = recoveryArchive.load()
  assert(recovered.cycle == 1 and #recovered.bank == 1
      and #recovered.hallOfLegacy == 1
      and recovered.locker.items.POTION == 2
      and recovered.locker.money == 321
      and recovered.current.status == "pending_new_game"
      and recovered.lastRollback
      and recovered.lastRollback.save.player.id == 6502,
    "committed witness recovery lost or duplicated archive payload")
  local resumed = assert(recoveryArchive.beginJourney(recoverySave, {
    pact = "ascendant", bankPolicy = "sealed", playerAvatar = "RED",
  }))
  local exactOnce = recoveryArchive.load()
  assert(resumed.runId == exactOnce.current.runId
      and exactOnce.cycle == 1 and #exactOnce.bank == 1
      and #exactOnce.hallOfLegacy == 1
      and exactOnce.locker.items.POTION == 2
      and exactOnce.locker.money == 321,
    "same-source retry duplicated a recovered Legacy transaction")

  -- Loading a real encoded v1 primary through the installed factory must
  -- apply every migration, preserve unknown additive data and persist v6
  -- exactly once.  A second load must be read-only.
  local migrationFs = memoryFs()
  local migrationArchive = archiveFor(migrationFs,
    "package_contract/legacy_migration")
  migrationFs.files[migrationArchive.filename] = Serializer.encode({
    version = 1, cycle = 8, current = {},
    migrationSentinel = { partner = "KEEP", count = 17 },
  })
  local writesBefore = migrationFs.writes[migrationArchive.filename] or 0
  local migrated = migrationArchive.load()
  local writesAfter = migrationFs.writes[migrationArchive.filename] or 0
  local persisted = assert(Serializer.decode(
    migrationFs.files[migrationArchive.filename]))
  assert(migrated.version == currentVersion
      and migrated.cycle == 8
      and migrated.migrationSentinel.partner == "KEEP"
      and migrated.migrationSentinel.count == 17
      and persisted.version == currentVersion
      and writesAfter - writesBefore == 1,
    "v1 archive migration was not additive and exactly-once")
  migrationArchive.load()
  assert((migrationFs.writes[migrationArchive.filename] or 0) == writesAfter,
    "current archive was rewritten again after migration")

  local out = assert(io.open(dir .. "/driver_result.txt", "wb"))
  out:write("status=PASS\n")
  out:write("scope=LEGACY-ARCHIVE-TRANSACTION\n")
  out:write("edition=red\n")
  out:write("installed_archive_factory=1/1\n")
  out:write("failed_witness_rollback=1/1\n")
  out:write("source_save_unchanged=2/2\n")
  out:write("committed_witness_recovery=1/1\n")
  out:write("same_source_retry_exact_once=1/1\n")
  out:write("v1_to_v7_migration=1/1\n")
  out:write("migration_persist_exact_once=1/1\n")
  out:write("engine_payload_sha256=", receipts.engine_payload_sha256, "\n")
  out:write("authority_package_sha256=",
    receipts.authority_package_sha256, "\n")
  out:write("deutsch_package_sha256=", receipts.deutsch_package_sha256,
    "\n")
  out:write("package_gate_receipt_sha256=",
    receipts.package_gate_receipt_sha256, "\n")
  out:write("fail=0\n")
  out:close()
  print("LEGACY ARCHIVE TRANSACTION PACKAGE PASS")
  love.event.quit(0)
end
