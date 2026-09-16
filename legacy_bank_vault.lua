-- Kanto Ascendant 6.7 cross-edition Pokémon and item Legacy Vault.
--
-- This module is deliberately pure/data-only. Persistence, UI and game-save
-- writes are owned by legacy_bank_store.lua / legacy_bank_bridge.lua. Keeping
-- the model pure lets every migration and crash seam run against synthetic
-- fixtures without touching a user's save directory.

return function(opts)
  opts = opts or {}
  local Serializer = assert(opts.serializer,
    "Legacy Bank Vault needs the engine SaveSerializer")
  local sha256 = assert(opts.sha256, "Legacy Bank Vault needs SHA-256")
  local now = opts.now or os.time
  local classifyItem = opts.classifyItem or function()
    return "kanto_only"
  end
  local randomId = opts.randomId or function(kind)
    return tostring(kind or "id") .. "-" .. sha256(
      tostring(now()) .. ":" .. tostring({})):sub(1, 24)
  end

  local V = {
    SCHEMA_VERSION = 2,
    PACKAGE_VERSION = 1,
    TRANSACTION_VERSION = 1,
    KIND = "kanto-ascendant.legacy-bank-vault",
    PACKAGE_KIND = "kanto-ascendant.legacy-bank-package",
  }

  local function copy(value)
    if value == nil then return nil end
    local ok, encoded = pcall(Serializer.encode, value)
    if not ok then error("Legacy Vault data is not serializable: "
      .. tostring(encoded), 2) end
    local decoded, err = Serializer.decode(encoded)
    if decoded == nil then error("Legacy Vault data cannot be decoded: "
      .. tostring(err), 2) end
    return decoded
  end

  local function digest(value)
    local ok, body = pcall(Serializer.encode, value)
    if not ok then return nil, tostring(body) end
    return sha256(body), body
  end

  local function integer(value, fallback, minimum, maximum)
    value = math.floor(tonumber(value) or fallback or 0)
    if minimum and value < minimum then value = minimum end
    if maximum and value > maximum then value = maximum end
    return value
  end

  local function stringId(value)
    value = type(value) == "string" and value or nil
    return value and value ~= "" and value or nil
  end

  local function upper(value)
    return stringId(value) and tostring(value):upper() or nil
  end

  local function carried(value)
    if value==nil or value==false or value==0 or value=='' then return nil end
    if type(value)~='string' or not value:upper():match('^[A-Z][A-Z0-9_]*$') then
      return nil,'invalid_held_item'
    end
    if value:upper()=='NO_ITEM' then return nil end
    return value:upper()
  end

  local function listUnion(...)
    local out, seen = {}, {}
    for arg = 1, select("#", ...) do
      local source = select(arg, ...)
      if type(source) == "table" then
        for _, value in ipairs(source) do
          value = upper(type(value) == "table" and (value.id or value.move) or value)
          if value and not seen[value] then
            seen[value] = true
            out[#out + 1] = value
          end
        end
      end
    end
    return out
  end

  local function mapUnion(target, source)
    target = type(target) == "table" and target or {}
    for key, value in pairs(type(source) == "table" and source or {}) do
      if value == true then target[upper(key) or tostring(key)] = true end
    end
    return target
  end

  local function appendUnique(target, value, key)
    target = type(target) == "table" and target or {}
    local wanted = key and value[key] or digest(value)
    for _, row in ipairs(target) do
      local present = key and row[key] or digest(row)
      if present == wanted then return target end
    end
    target[#target + 1] = copy(value)
    return target
  end

  local function pokemonData(context)
    local data = context and context.data
    return type(data) == "table" and type(data.pokemon) == "table"
      and data.pokemon or {}
  end

  local function moveData(context)
    local data = context and context.data
    return type(data) == "table" and type(data.moves) == "table"
      and data.moves or {}
  end

  local function itemData(context)
    local data = context and context.data
    return type(data) == "table" and type(data.items) == "table"
      and data.items or {}
  end

  local function lineage(species, context)
    species = upper(species)
    local registry = pokemonData(context)
    local parent = {}
    for from, definition in pairs(registry) do
      for _, evolution in ipairs(type(definition) == "table"
          and definition.evolutions or {}) do
        local child = upper(evolution and (evolution.species or evolution.into))
        if child and parent[child] == nil then parent[child] = upper(from) end
      end
    end
    local reverse, seen, cursor = {}, {}, species
    while cursor and not seen[cursor] do
      seen[cursor] = true
      reverse[#reverse + 1] = cursor
      cursor = parent[cursor]
    end
    local out = {}
    for index = #reverse, 1, -1 do out[#out + 1] = reverse[index] end
    if #out == 0 and species then out[1] = species end
    return out
  end

  local function stageIndex(stages, species)
    species = upper(species)
    for index, value in ipairs(stages or {}) do
      if upper(value) == species then return index end
    end
    return 0
  end

  local function levelMoves(species, level, context)
    species, level = upper(species), integer(level, 1, 1, 100)
    local definition = pokemonData(context)[species]
    if type(definition) ~= "table" then return {} end
    local out = listUnion(definition.level1Moves)
    local seen = {}
    for _, id in ipairs(out) do seen[id] = true end
    for _, row in ipairs(definition.learnset or definition.levelMoves or {}) do
      local move = upper(row and row.move)
      if move and integer(row.level, 101) <= level and not seen[move] then
        seen[move] = true
        out[#out + 1] = move
      end
    end
    return out
  end

  local function memoryMap(moves, legal, existing)
    local out = mapUnion({}, existing)
    for _, id in ipairs(listUnion(moves, legal)) do out[id] = true end
    return out
  end

  local function identityFrom(mon)
    return {
      nickname = mon.nickname,
      ot = mon.ot or mon.otName,
      otId = mon.otId or mon.originalTrainerId,
      language = mon.language,
    }
  end

  local function geneticsFrom(mon)
    return {
      gender = mon.gender,
      shiny = mon.shiny == true,
      dvs = copy(mon.dvs),
      ivs = copy(mon.ivs),
      personality = mon.personality,
    }
  end

  local function trainingFrom(mon)
    return {
      statExp = copy(mon.statExp or mon.statExperience),
      evs = copy(mon.evs),
      friendship = mon.friendship or mon.happiness,
    }
  end

  local function entryPayload(entry)
    return {
      vaultMonId = entry.vaultMonId,
      species = entry.species,
      current = entry.current,
      identity = entry.identity,
      genetics = entry.genetics,
      training = entry.training,
      progress = entry.progress,
      evolution = entry.evolution,
      moveMemory = entry.moveMemory,
      heldItem = entry.heldItem,
      extensions = entry.extensions,
    }
  end

  local function itemPayload(entry)
    return {
      itemId = entry.itemId,
      quantity = entry.quantity,
      scope = entry.scope,
      provenance = entry.provenance,
    }
  end

  local function refreshItemHash(entry)
    entry.payloadSha256 = assert(digest(itemPayload(entry)))
    return entry
  end

  local function refreshEntryHash(entry)
    entry.payloadSha256 = assert(digest(entryPayload(entry)))
    return entry
  end

  -- A Mega is a battle transformation of an authorized base species, not
  -- a new species to inject into a vanilla target registry. Keep the chosen
  -- form as provenance; Ring/Stone authority still travels via its own lease.
  local function normalizeMega(mon)
    if type(mon) ~= "table" then return mon end
    local species = upper(mon.species)
    local marker = upper(mon._ascMegaForm or mon.ascMegaForm
      or mon.form or mon.formId)
    for _, profile in ipairs(opts.megaProfiles or {}) do
      local base, id = upper(profile.species), upper(profile.id)
      if base and id and not profile.secret and (
          species == "MEGA_" .. id or species == id .. "_MEGA"
          or species == base and marker and (
            marker == id or marker == "MEGA_" .. id
            or marker == "MEGA" and id == base
            or marker == "MEGA_X" and id == base .. "_X"
            or marker == "MEGA_Y" and id == base .. "_Y")) then
        local out = copy(mon)
        out.species, out.form, out.formId, out.dex = base, nil, nil, nil
        out._ascMegaForm, out.ascMegaForm = nil, nil
        out._ascMegaAnimationSide, out._ascMegaAnimationFrame = nil, nil
        out.__kaLegacyMega = { schema = "kasc/bank-mega-form/v1",
          baseSpecies = base, formId = id, stone = profile.stone }
        return out
      end
    end
    return mon
  end

  local function targetEntry(entry)
    local payload = entry and entry.current and entry.current.payload
    local normalized = normalizeMega(payload)
    if normalized == payload then return entry end
    local out = copy(entry)
    out.species, out.current.species = normalized.species, normalized.species
    out.current.payload = normalized
    return out
  end

  function V.canonicalizeMon(mon, context)
    mon = normalizeMega(mon)
    context = context or {}
    assert(type(mon) == "table", "canonical Pokémon must be a table")
    local species = upper(mon.species)
    assert(species, "canonical Pokémon needs species")
    local existing = type(context.existing) == "table" and context.existing or nil
    local id = stringId(context.vaultMonId) or stringId(mon.vaultMonId)
      or stringId(mon.__kaLegacyId) or randomId("mon")
    local level = integer(mon.level, 1, 1, 100)
    local experience = integer(mon.experience or mon.exp, 0, 0)
    local stages = lineage(species, context)
    if existing and type(existing.evolution) == "table" then
      stages = listUnion(existing.evolution.allowedStages, stages)
    end
    local currentRank = stageIndex(stages, species)
    local priorRank = existing and integer(existing.evolution
      and existing.evolution.highestRank, 0) or 0
    local highestRank = math.max(currentRank, priorRank)
    local highestSpecies = stages[highestRank] or species
    local moves = listUnion(mon.moves)
    local memory = memoryMap(moves, levelMoves(species, level, context),
      existing and existing.moveMemory)
    local entry = {
      vaultMonId = id,
      species = species,
      current = {
        species = species,
        level = level,
        experience = experience,
        moves = moves,
        payload = copy(mon),
      },
      identity = identityFrom(mon),
      genetics = geneticsFrom(mon),
      training = trainingFrom(mon),
      progress = {
        experience = experience,
        highestExperience = math.max(experience, existing and integer(
          existing.progress and (existing.progress.highestExperience
            or existing.progress.experience), 0) or 0),
        highestLevel = math.max(level, existing and integer(
          existing.progress and existing.progress.highestLevel, 0) or 0),
      },
      evolution = {
        allowedStages = stages,
        highestRank = highestRank,
        highestSpecies = highestSpecies,
      },
      moveMemory = memory,
      heldItem = upper(mon.item or mon.heldItem),
      origin = {
        game = context.originGame or context.edition,
        edition = context.edition,
        run = context.originRun,
        time = context.time or now(),
      },
      extensions = {
        kasc = copy(mon.kasc or mon.kantoAscendant),
        gameSpecific = copy(mon.gameSpecific),
        preserved = copy(mon.extensions),
      },
      provenance = {},
      transferHistory = existing and copy(existing.transferHistory) or {},
      lease = existing and copy(existing.lease) or nil,
    }
    entry.provenance[1] = copy(entry.origin)
    if existing then
      for _, row in ipairs(existing.provenance or {}) do
        entry.provenance = appendUnique(entry.provenance, row)
      end
    end
    return refreshEntryHash(entry)
  end

  local function newId(kind)
    local id = stringId(randomId(kind))
    assert(id, "Legacy Vault randomId returned no identity")
    return id
  end

  function V.newVault(config)
    config = config or {}
    return {
      kind = V.KIND,
      schemaVersion = V.SCHEMA_VERSION,
      vaultId = stringId(config.vaultId) or newId("vault"),
      createdAt = config.createdAt or now(),
      updatedAt = config.createdAt or now(),
      transactionSerial = 0,
      monSerial = 0,
      pokemon = {},
      items = {},
      quarantine = {},
      transactions = {},
      migrationReceipts = {},
      importReceipts = {},
      backupMetadata = {},
      recovery = {},
    }
  end

  function V.normalize(raw)
    if type(raw) ~= "table" or raw.kind ~= V.KIND then
      return nil, "invalid_vault"
    end
    local version = integer(raw.schemaVersion, 0)
    if version > V.SCHEMA_VERSION then return nil, "future_schema" end
    if version < 1 then return nil, "unsupported_schema" end
    if not stringId(raw.vaultId) then return nil, "missing_vault_identity" end
    local out = copy(raw)
    if version == 1 then
      out.items = {}
      out.schemaVersion = 2
    end
    out.pokemon = type(out.pokemon) == "table" and out.pokemon or {}
    out.items = type(out.items) == "table" and out.items or {}
    out.quarantine = type(out.quarantine) == "table" and out.quarantine or {}
    out.transactions = type(out.transactions) == "table" and out.transactions or {}
    out.migrationReceipts = type(out.migrationReceipts) == "table"
      and out.migrationReceipts or {}
    out.importReceipts = type(out.importReceipts) == "table"
      and out.importReceipts or {}
    out.backupMetadata = type(out.backupMetadata) == "table"
      and out.backupMetadata or {}
    out.recovery = type(out.recovery) == "table" and out.recovery or {}
    out.transactionSerial = integer(out.transactionSerial, 0, 0)
    out.monSerial = integer(out.monSerial, 0, 0)
    local seen = {}
    for _, entry in ipairs(out.pokemon) do
      if type(entry) ~= "table" or not stringId(entry.vaultMonId)
          or seen[entry.vaultMonId] then return nil, "duplicate_or_invalid_mon_id" end
      seen[entry.vaultMonId] = true
      local wanted = digest(entryPayload(entry))
      if entry.payloadSha256 ~= wanted then return nil, "entry_checksum_mismatch" end
    end
    for id, entry in pairs(out.items) do
      if type(id) ~= "string" or id == "" or type(entry) ~= "table"
          or entry.itemId ~= id or integer(entry.quantity, 0) < 1
          or (entry.scope ~= "crossgen_mega" and entry.scope ~= "kanto_only")
          or entry.payloadSha256 ~= digest(itemPayload(entry)) then
        return nil, "invalid_item_entry"
      end
      entry.quantity = integer(entry.quantity, 0, 1)
      entry.provenance = type(entry.provenance) == "table"
        and entry.provenance or {}
    end
    return out
  end

  function V.item(vault, id)
    id = upper(id)
    return id and type(vault.items) == "table" and vault.items[id] or nil
  end

  function V.itemCompatibility(entry, targetGeneration)
    if type(entry) ~= "table" then return false, "unknown_vault_item" end
    if integer(targetGeneration, 1, 1) >= 2
        and entry.scope ~= "crossgen_mega" then
      return false, "kanto_item_locked_in_gen2"
    end
    return true
  end

  function V.addItem(vault, id, quantity, context)
    id = upper(id)
    quantity = integer(quantity, 0, 0)
    if not id or quantity < 1 then return nil, "invalid_item" end
    vault.items = type(vault.items) == "table" and vault.items or {}
    local scope = classifyItem(id) == "crossgen_mega"
      and "crossgen_mega" or "kanto_only"
    local entry = vault.items[id]
    if entry and entry.scope ~= scope then return nil, "item_scope_conflict" end
    if not entry then
      entry = { itemId = id, quantity = 0, scope = scope, provenance = {} }
      vault.items[id] = entry
    end
    if scope == "crossgen_mega" then
      entry.quantity = 1
    else
      entry.quantity = integer(entry.quantity, 0, 0) + quantity
    end
    entry.provenance = appendUnique(entry.provenance, {
      source = context and context.source,
      edition = context and context.edition,
      receiptId = context and context.receiptId,
      createdAt = now(),
    })
    refreshItemHash(entry)
    vault.updatedAt = now()
    return entry
  end

  -- Explicit migration plan, not a read-time normalizer. Store.commit keeps
  -- the original complete vault as backup and commits both stocks together.
  -- Leased Pokémon remain owned by their external save; splitting those
  -- stale snapshots would duplicate an item still carried outside the bank.
  function V.planHeldSplitMigration(vault)
    local staged,err=V.normalize(vault)
    if not staged then return nil,err end
    local count=0
    for _,entry in ipairs(staged.pokemon)do
      if not entry.lease then
        local payload=entry.current and entry.current.payload or {}
        local item
        for _,key in ipairs({'heldItem','item','payloadHeld'})do
          local value=key=='heldItem' and entry.heldItem
            or key=='item' and payload.item or key=='payloadHeld' and payload.heldItem
          local candidate,reason=carried(value)
          if reason then return nil,reason end
          if item and candidate and item~=candidate then return nil,'held_item_alias_conflict' end
          item=item or candidate
        end
        if item then
          local receiptId='held-split:'..entry.vaultMonId..':'..entry.payloadSha256
          if staged.migrationReceipts[receiptId] then return nil,'held_split_receipt_conflict' end
          local original=copy(entry)
          local credited,creditErr=V.addItem(staged,item,1,{source='held-migration',
            edition=entry.origin and entry.origin.edition,receiptId=receiptId})
          if not credited then return nil,creditErr end
          entry.heldItem=nil;payload.item=nil;payload.heldItem=nil
          refreshEntryHash(entry)
          staged.migrationReceipts[receiptId]={schema='kasc.bank-held-split/v1',
            receiptId=receiptId,itemId=item,quantity=1,vaultMonId=entry.vaultMonId,
            sourceSha256=original.payloadSha256,targetSha256=entry.payloadSha256,
            originalEntry=original,completedAt=now()}
          count=count+1
        end
      end
    end
    return staged,count
  end

  local function index(vault)
    local out = {}
    for row, entry in ipairs(vault.pokemon or {}) do
      out[entry.vaultMonId] = { row = row, entry = entry }
    end
    return out
  end

  function V.entry(vault, id)
    local found = index(vault)[id]
    return found and found.entry or nil
  end

  local function quarantine(vault, kind, detail)
    local row = {
      quarantineId = newId("quarantine"),
      kind = kind,
      createdAt = now(),
      detail = copy(detail),
    }
    row.sha256 = assert(digest(row.detail))
    vault.quarantine[#vault.quarantine + 1] = row
    return row
  end

  function V.previewArchiveMigration(vault, archive, context)
    if type(archive) ~= "table" then return nil, "invalid_archive" end
    context = context or {}
    local sourceDigest = stringId(context.sourceDigest) or digest(archive)
    if not sourceDigest then return nil, "archive_digest_failed" end
    local available, leased = 0, 0
    for _, row in ipairs(type(archive.bank) == "table" and archive.bank or {}) do
      if type(row) == "table" and row.lease then leased = leased + 1
      else available = available + 1 end
    end
    local quarantined = 0
    local qbank = type(archive.quarantine) == "table"
      and type(archive.quarantine.bank) == "table"
      and archive.quarantine.bank or {}
    for _ in pairs(qbank) do quarantined = quarantined + 1 end
    local itemRows, crossGenerationItems, kantoOnlyItems = 0, 0, 0
    local lockerItems = type(archive.locker) == "table"
      and type(archive.locker.items) == "table" and archive.locker.items or {}
    for id, count in pairs(lockerItems) do
      if integer(count, 0, 0) > 0 then
        itemRows = itemRows + 1
        if classifyItem(upper(id)) == "crossgen_mega" then
          crossGenerationItems = crossGenerationItems + 1
        else
          kantoOnlyItems = kantoOnlyItems + 1
        end
      end
    end
    return {
      kind = "archive_migration_preview",
      sourceDigest = sourceDigest,
      sourceEdition = context.sourceEdition,
      sourceVersion = integer(archive.version, 0),
      available = available,
      leased = leased,
      quarantined = quarantined,
      itemRows = itemRows,
      crossGenerationItems = crossGenerationItems,
      kantoOnlyItems = kantoOnlyItems,
      conflicts = 0,
      archive = copy(archive),
    }
  end

  local function addProvenance(target, source)
    target.provenance = type(target.provenance) == "table"
      and target.provenance or {}
    for _, row in ipairs(source.provenance or {}) do
      target.provenance = appendUnique(target.provenance, row)
    end
  end

  function V.previewMerge(vault, entries)
    local byId = index(vault)
    local preview = {
      kind = "vault_merge_preview", added = 0, identical = 0,
      conflicts = 0, actions = {}, entries = copy(entries or {}),
    }
    for _, incoming in ipairs(entries or {}) do
      local present = byId[incoming.vaultMonId]
      local action
      if not present then
        action = "add"
        preview.added = preview.added + 1
      elseif present.entry.payloadSha256 == incoming.payloadSha256 then
        action = "identical"
        preview.identical = preview.identical + 1
      else
        action = "conflict"
        preview.conflicts = preview.conflicts + 1
      end
      preview.actions[#preview.actions + 1] = {
        action = action,
        vaultMonId = incoming.vaultMonId,
        entry = copy(incoming),
      }
    end
    return preview
  end

  function V.applyMerge(vault, preview, context)
    context = context or {}
    local byId = index(vault)
    for _, action in ipairs(preview.actions or {}) do
      local present = byId[action.vaultMonId]
      if action.action == "add" and not present then
        vault.pokemon[#vault.pokemon + 1] = copy(action.entry)
        byId[action.vaultMonId] = { row = #vault.pokemon,
          entry = vault.pokemon[#vault.pokemon] }
      elseif action.action == "identical" and present then
        addProvenance(present.entry, action.entry)
      elseif action.action == "conflict" then
        quarantine(vault, "same_id_different_payload", {
          source = context.source,
          vaultMonId = action.vaultMonId,
          authoritative = present and copy(present.entry) or nil,
          incoming = copy(action.entry),
        })
      end
    end
    vault.updatedAt = now()
    return true
  end

  function V.applyArchiveMigration(vault, preview, data)
    local prior = vault.migrationReceipts[preview.sourceDigest]
    if prior then
      local repeated = copy(prior)
      repeated.status = "already_applied"
      return repeated
    end
    local archive = preview.archive
    local entries = {}
    for _, row in ipairs(type(archive.bank) == "table" and archive.bank or {}) do
      if type(row) == "table" and type(row.mon) == "table" then
        local mon = copy(row.mon)
        mon.__kaLegacyId = stringId(row.id) or mon.__kaLegacyId
        local entry = V.canonicalizeMon(mon, {
          data = data,
          edition = preview.sourceEdition,
          originGame = "kanto_ascendant",
          originRun = row.depositedBy,
          vaultMonId = row.id,
        })
        if row.lease then
          entry.lease = {
            version = V.TRANSACTION_VERSION,
            state = "active",
            owner = tostring(row.lease),
            transactionId = "legacy:" .. entry.vaultMonId,
            migrated = true,
          }
        end
        entries[#entries + 1] = entry
      end
    end
    local merge = V.previewMerge(vault, entries)
    V.applyMerge(vault, merge, { source = "archive:" .. preview.sourceDigest })
    local qbank = type(archive.quarantine) == "table"
      and type(archive.quarantine.bank) == "table"
      and archive.quarantine.bank or {}
    for id, row in pairs(qbank) do
      quarantine(vault, "legacy_bank_quarantine", {
        legacyId = id,
        sourceDigest = preview.sourceDigest,
        row = copy(row),
      })
    end
    local migratedItems = 0
    local lockerItems = type(archive.locker) == "table"
      and type(archive.locker.items) == "table" and archive.locker.items or {}
    for id, count in pairs(lockerItems) do
      if integer(count, 0, 0) > 0 then
        local added = V.addItem(vault, id, count, {
          source = "archive:" .. preview.sourceDigest,
          edition = preview.sourceEdition,
        })
        if added then migratedItems = migratedItems + 1 end
      end
    end
    local receipt = {
      receiptId = newId("migration"),
      status = "applied",
      sourceDigest = preview.sourceDigest,
      sourceEdition = preview.sourceEdition,
      sourceVersion = preview.sourceVersion,
      migratedRows = #entries,
      migratedQuarantine = preview.quarantined,
      migratedItems = migratedItems,
      crossGenerationItems = preview.crossGenerationItems or 0,
      kantoOnlyItems = preview.kantoOnlyItems or 0,
      conflicts = merge.conflicts,
      createdAt = now(),
    }
    vault.migrationReceipts[preview.sourceDigest] = copy(receipt)
    vault.updatedAt = now()
    return receipt
  end

  function V.repairBinding(proof)
    if type(proof) ~= "table"
        or not stringId(proof.playthroughId)
        or proof.playthroughId ~= proof.storagePlaythroughId
        or type(proof.archiveDigest) ~= "string"
        or not proof.archiveDigest:match("^[0-9a-f]+$")
        or #proof.archiveDigest ~= 64 then
      return nil, "invalid_binding_proof"
    end
    local matches = 0
    for _, candidate in ipairs(proof.candidateDigests or {}) do
      if candidate == proof.archiveDigest then matches = matches + 1 end
    end
    if matches ~= 1 or #(proof.candidateDigests or {}) ~= 1 then
      return nil, "ambiguous_binding"
    end
    return {
      version = 1,
      scope = "playthrough",
      playthroughId = proof.playthroughId,
      archiveDigest = proof.archiveDigest,
      repaired = true,
    }
  end

  function V.compatibility(entry, target)
    entry = targetEntry(entry)
    target = target or {}
    local payload = entry and entry.current and entry.current.payload or {}
    local species = upper(entry and (entry.species
      or entry.current and entry.current.species) or payload.species)
    if payload.isEgg == true or payload.egg == true or species == "EGG" then
      return false, "egg"
    end
    if species == "GOROCHU" then return false, "gorochu" end
    if payload._ascMegaForm or payload.ascMegaForm then
      return false, "mega_form"
    end
    local form = upper(payload.form or payload.formId)
    if form and form ~= "NORMAL" then
      if form:find("MEGA", 1, true) then return false, "mega_form" end
      return false, "unknown_form"
    end
    local definition = pokemonData(target)[species]
    local dex = integer(payload.dex or definition and definition.dex, 0)
    if dex > 251 then return false, "species_above_251" end
    if not definition then return false, "species_unavailable" end
    return true
  end

  local function remembered(entry, species, level, context)
    local out = mapUnion({}, entry.moveMemory)
    for _, move in ipairs(levelMoves(species, level, context)) do out[move] = true end
    return out
  end

  function V.legalMoves(entry, species, level, context)
    local available, registry = remembered(entry, species, level, context),
      moveData(context)
    local out = {}
    local targetEdition = context.targetEdition or context.edition
    local nativeJohto = targetEdition == "gold" or targetEdition == "silver"
      or targetEdition == "crystal"
    local legal = {}
    if nativeJohto then
      -- Remembered does not mean learnable by this target species. Include
      -- native pre-evolution moves, machines, breeding and tutor sources.
      for _, stage in ipairs(lineage(species, context)) do
        local definition = pokemonData(context)[stage] or {}
        for _, move in ipairs(levelMoves(stage, level, context)) do legal[move] = true end
        for _, key in ipairs({"tmhm", "eggMoves", "tutorMoves"}) do
          for _, move in ipairs(definition[key] or {}) do
            local id = upper(type(move) == "table" and (move.move or move.id) or move)
            if id then legal[id] = true end
          end
        end
      end
    end
    for move in pairs(available) do
      if registry[move] and (not nativeJohto or legal[move]) then
        out[#out + 1] = move
      end
    end
    table.sort(out)
    return out
  end

  local function chooseMoves(entry, species, level, desired, context, fill)
    local available, out, seen = {}, {}, {}
    for _, move in ipairs(V.legalMoves(entry, species, level, context)) do
      available[move] = true
    end
    local function add(move)
      move = upper(move)
      if move and available[move] and not seen[move] and #out < 4 then
        seen[move] = true
        out[#out + 1] = move
      end
    end
    for _, move in ipairs(desired or {}) do add(move) end
    if fill then
      for _, move in ipairs(levelMoves(species, level, context)) do add(move) end
    end
    return out
  end

  function V.buildVariant(entry, config)
    config = config or {}
    entry = targetEntry(entry)
    local allowed, reason = V.compatibility(entry, config)
    if not allowed then return nil, reason end
    local mode = tostring(config.mode or "original"):lower()
    if mode ~= "original" and mode ~= "new_start" and mode ~= "custom" then
      return nil, "invalid_rebirth_mode"
    end
    local stages = entry.evolution.allowedStages or { entry.species }
    local species, level, desired, item, trainingMode
    if mode == "original" then
      species = entry.current.species
      level = entry.current.level
      desired = entry.current.moves
      item = entry.heldItem
      trainingMode = "preserved"
    elseif mode == "new_start" then
      species = stages[1] or entry.species
      level = 5
      desired = levelMoves(species, level, config)
      trainingMode = "fresh"
    else
      species = upper(config.species)
      if stageIndex(stages, species) < 1 then return nil, "locked_evolution" end
      level = integer(config.level, 5, 5, entry.progress.highestLevel)
      desired = config.moves
      trainingMode = ({ fresh = true, scaled = true, preserved = true })[
        tostring(config.training)] and config.training or "fresh"
      item = upper(config.item)
      if item and not itemData(config)[item] then item = nil end
    end
    if item and not itemData(config)[item] then return nil, "item_unavailable" end
    if not pokemonData(config)[species] then return nil, "species_unavailable" end
    level = integer(level, 5, mode == "original" and 1 or 5,
      entry.progress.highestLevel)
    local moves = chooseMoves(entry, species, level, desired, config,
      mode ~= "custom")
    if #moves == 0 then return nil, "no_legal_moves" end
    local pp = {}
    for index, move in ipairs(moves) do
      pp[index] = integer(moveData(config)[move]
        and moveData(config)[move].pp, 0, 0)
    end
    local experience
    if mode == "original" then
      experience = entry.current.experience
    elseif type(config.expForLevel) == "function" then
      experience = config.expForLevel(species, level)
    else
      experience = 0
    end
    local mon = copy(entry.current.payload)
    mon.species, mon.level = species, level
    mon.exp, mon.experience = experience, experience
    mon.moves, mon.pp = moves, pp
    mon.item = item
    mon.heldItem = item
    mon.nickname = entry.identity.nickname
    mon.ot, mon.otId = entry.identity.ot, entry.identity.otId
    mon.gender, mon.shiny = entry.genetics.gender, entry.genetics.shiny
    mon.dvs, mon.ivs = copy(entry.genetics.dvs), copy(entry.genetics.ivs)
    if trainingMode == "fresh" then
      mon.statExp, mon.statExperience, mon.evs = {}, {}, {}
      mon.friendship, mon.happiness = nil, nil
    elseif trainingMode == "preserved" then
      mon.statExp = copy(entry.training.statExp)
      mon.evs = copy(entry.training.evs)
      mon.friendship = entry.training.friendship
      mon.happiness = entry.training.friendship
    else
      mon.statExp = copy(entry.training.statExp)
      mon.evs = copy(entry.training.evs)
    end
    mon.trainingMode = trainingMode
    mon.vaultMonId, mon.__kaLegacyId = entry.vaultMonId, entry.vaultMonId
    mon.__kaTransferReceipt = {
      version = V.TRANSACTION_VERSION,
      vaultMonId = entry.vaultMonId,
      vaultPayloadSha256 = entry.payloadSha256,
      mode = mode,
      targetEdition = config.targetEdition or config.edition,
    }
    if type(config.finalizeMon) == "function" then
      local finalized, err = config.finalizeMon(mon)
      if not finalized then return nil, err or "target_stats_unavailable" end
      mon = finalized
    end
    return mon
  end

  local function transaction(vault, id)
    return type(vault.transactions) == "table" and vault.transactions[id] or nil
  end

  local function nextTransaction(vault, direction, owner, monId)
    vault.transactionSerial = integer(vault.transactionSerial, 0, 0) + 1
    local id = ("%s:TX:%08d"):format(vault.vaultId,
      vault.transactionSerial)
    local tx = {
      version = V.TRANSACTION_VERSION,
      transactionId = id,
      direction = direction,
      state = "prepared",
      vaultMonId = monId,
      owner = copy(owner),
      createdAt = now(),
      updatedAt = now(),
    }
    vault.transactions[id] = tx
    return tx
  end

  function V.prepareItemWithdrawal(vault, itemId, quantity, owner, config)
    config = config or {}
    itemId, quantity = upper(itemId), integer(quantity, 1, 1)
    local entry = V.item(vault, itemId)
    if not entry then return nil, "unknown_vault_item" end
    if entry.lease then return nil, "item_already_leased" end
    if entry.quantity < quantity then return nil, "item_quantity_unavailable" end
    local allowed, reason = V.itemCompatibility(entry,
      config.targetGeneration or owner and owner.generation)
    if not allowed then return nil, reason end
    local tx = nextTransaction(vault, "item_withdraw", owner)
    tx.itemId, tx.quantity = itemId, quantity
    entry.lease = { transactionId = tx.transactionId,
      owner = owner and owner.saveIdentity, state = "prepared" }
    vault.updatedAt = now()
    return tx, copy(entry)
  end

  function V.prepareItemDeposit(vault, itemId, quantity, owner)
    itemId, quantity = upper(itemId), integer(quantity, 1, 1)
    if not itemId then return nil, "invalid_item" end
    local entry = V.item(vault, itemId)
    if entry and entry.lease then return nil, "item_already_leased" end
    local tx = nextTransaction(vault, "item_deposit", owner)
    tx.itemId, tx.quantity = itemId, quantity
    tx.scope = classifyItem(itemId) == "crossgen_mega"
      and "crossgen_mega" or "kanto_only"
    tx.entitlementCopy = tx.scope == "crossgen_mega"
    return tx
  end

  function V.markItemSaveWritten(vault, txId, saveDigest)
    local tx = transaction(vault, txId)
    if not tx or (tx.direction ~= "item_withdraw"
        and tx.direction ~= "item_deposit") or tx.state ~= "prepared" then
      return nil, "invalid_transaction_state"
    end
    tx.state = tx.direction == "item_withdraw"
      and "target_saved" or "source_saved"
    tx.saveDigest, tx.updatedAt = tostring(saveDigest), now()
    return tx
  end

  function V.completeItemTransfer(vault, txId)
    local tx = transaction(vault, txId)
    if not tx or (tx.direction ~= "item_withdraw"
        and tx.direction ~= "item_deposit")
        or (tx.state ~= "target_saved" and tx.state ~= "source_saved") then
      return nil, "invalid_transaction_state"
    end
    local entry = V.item(vault, tx.itemId)
    if tx.direction == "item_withdraw" then
      if not entry or not entry.lease
          or entry.lease.transactionId ~= tx.transactionId then
        return nil, "item_lease_mismatch"
      end
      -- Official Mega equipment is a reusable unlock certificate. Pokémon
      -- and ordinary consumables retain their existing exclusive semantics.
      if entry.scope ~= "crossgen_mega" then
        entry.quantity = entry.quantity - tx.quantity
      end
      entry.lease = nil
      if entry.quantity <= 0 then vault.items[tx.itemId] = nil
      else refreshItemHash(entry) end
    else
      local added, addErr = V.addItem(vault, tx.itemId, tx.quantity, {
        source = "save_deposit", edition = tx.owner and tx.owner.edition,
        receiptId = tx.transactionId,
      })
      if not added then return nil, addErr end
    end
    tx.state, tx.completedAt, tx.updatedAt = "completed", now(), now()
    vault.updatedAt = now()
    return tx
  end

  function V.cancelItemTransfer(vault, txId)
    local tx = transaction(vault, txId)
    if not tx or tx.state == "completed" then
      return nil, "invalid_transaction_state"
    end
    local entry = V.item(vault, tx.itemId)
    if entry and entry.lease
        and entry.lease.transactionId == tx.transactionId then
      entry.lease = nil
      refreshItemHash(entry)
    end
    tx.state, tx.updatedAt = "rolled_back", now()
    vault.updatedAt = now()
    return tx
  end

  local function scanMons(value, wanted, out, seen)
    if type(value) ~= "table" or seen[value] then return end
    seen[value] = true
    local id = value.vaultMonId or value.__kaLegacyId
    if id == wanted and value.species then out[#out + 1] = value end
    for key, child in pairs(value) do
      if key ~= "__kaTransferReceipt" and type(child) == "table" then
        scanMons(child, wanted, out, seen)
      end
    end
  end

  local function matchingMons(value, wanted)
    local out = {}
    scanMons(value, wanted, out, {})
    return out
  end

  function V.prepareWithdrawal(vault, monId, owner, config)
    config = config or {}
    if config.accessAllowed == false then return nil, "bank_policy_denied" end
    local entry = V.entry(vault, monId)
    if not entry then return nil, "unknown_vault_mon" end
    if entry.lease and not config.allowExistingLease then
      return nil, "already_leased"
    end
    local allowed, reason = V.compatibility(entry, config)
    if not allowed then return nil, reason end
    local target, variantErr = V.buildVariant(entry, config)
    if not target then return nil, variantErr end
    local tx = nextTransaction(vault, "withdraw", owner, monId)
    tx.targetMon = copy(target)
    tx.targetSha256 = assert(digest(target))
    tx.recoveryEntry = copy(entry)
    entry.lease = {
      version = V.TRANSACTION_VERSION,
      transactionId = tx.transactionId,
      owner = stringId(owner and owner.saveIdentity)
        or stringId(owner and owner.edition) or "unknown",
      edition = owner and owner.edition,
      state = "prepared",
    }
    vault.updatedAt = now()
    return tx, target
  end

  function V.markTargetSaved(vault, txId, saveDigest)
    local tx = transaction(vault, txId)
    if not tx or tx.direction ~= "withdraw" or tx.state ~= "prepared" then
      return nil, "invalid_transaction_state"
    end
    tx.state, tx.targetSaveDigest, tx.updatedAt =
      "target_saved", tostring(saveDigest), now()
    return tx
  end

  function V.verifyWithdrawal(vault, txId, targetSave)
    local tx = transaction(vault, txId)
    if not tx or tx.direction ~= "withdraw"
        or (tx.state ~= "prepared" and tx.state ~= "target_saved") then
      return nil, "invalid_transaction_state"
    end
    local matches = matchingMons(targetSave, tx.vaultMonId)
    if #matches ~= 1 then
      if #matches > 1 then
        quarantine(vault, "withdrawal_target_conflict", {
          transactionId = txId, copies = #matches, target = copy(targetSave),
        })
        tx.state = "quarantined"
        return nil, "contradictory_target"
      end
      return nil, "target_missing"
    end
    tx.state, tx.verifiedTargetSha256, tx.updatedAt =
      "verified", assert(digest(matches[1])), now()
    return tx
  end

  function V.completeWithdrawal(vault, txId)
    local tx = transaction(vault, txId)
    if not tx or tx.direction ~= "withdraw" or tx.state ~= "verified" then
      return nil, "invalid_transaction_state"
    end
    local entry = V.entry(vault, tx.vaultMonId)
    if not entry or not entry.lease
        or entry.lease.transactionId ~= tx.transactionId then
      return nil, "lease_mismatch"
    end
    tx.state, tx.completedAt, tx.updatedAt = "completed", now(), now()
    entry.lease.state = "active"
    entry.transferHistory = appendUnique(entry.transferHistory, {
      transactionId = tx.transactionId,
      direction = "withdraw",
      edition = tx.owner and tx.owner.edition,
      completedAt = tx.completedAt,
      targetSha256 = tx.verifiedTargetSha256,
    }, "transactionId")
    tx.targetMon = nil
    vault.updatedAt = now()
    return tx
  end

  local function monotonicMerge(existing, incoming)
    existing.current = copy(incoming.current)
    existing.identity = copy(incoming.identity)
    existing.genetics = copy(incoming.genetics)
    existing.training = copy(incoming.training)
    existing.heldItem = incoming.heldItem
    existing.extensions = copy(incoming.extensions)
    existing.species = incoming.species
    existing.progress.experience = incoming.progress.experience
    existing.progress.highestExperience = math.max(
      integer(existing.progress.highestExperience, 0),
      integer(incoming.progress.highestExperience, 0))
    existing.progress.highestLevel = math.max(
      integer(existing.progress.highestLevel, 0),
      integer(incoming.progress.highestLevel, 0))
    existing.moveMemory = mapUnion(existing.moveMemory, incoming.moveMemory)
    if integer(incoming.evolution.highestRank, 0)
        > integer(existing.evolution.highestRank, 0) then
      existing.evolution.highestRank = incoming.evolution.highestRank
      existing.evolution.highestSpecies = incoming.evolution.highestSpecies
    end
    existing.evolution.allowedStages = listUnion(
      existing.evolution.allowedStages, incoming.evolution.allowedStages)
    addProvenance(existing, incoming)
    refreshEntryHash(existing)
    return existing
  end

  function V.prepareDeposit(vault, mon, owner, data)
    if type(mon) ~= "table" or not mon.species then return nil, "invalid_pokemon" end
    -- KASC-67-EQUIPMENT-BANK-HATCHING: one carried unit, even when both
    -- engine aliases are populated. Reject ambiguous data before allocating
    -- an identity or changing a lease; never guess which item to preserve.
    local item,itemErr=carried(mon.item)
    local alias,aliasErr=carried(mon.heldItem)
    if itemErr or aliasErr then return nil,itemErr or aliasErr end
    if item and alias and item~=alias then return nil,'held_item_alias_conflict' end
    item=item or alias
    local scope=item and (classifyItem(item)=='crossgen_mega' and 'crossgen_mega' or 'kanto_only')
    if item and vault.items and vault.items[item] and vault.items[item].scope~=scope then
      return nil,'item_scope_conflict'
    end
    local id = stringId(mon.vaultMonId) or stringId(mon.__kaLegacyId)
    if not id then
      vault.monSerial = integer(vault.monSerial, 0, 0) + 1
      id = ("%s:MON:%08d"):format(vault.vaultId, vault.monSerial)
      mon.vaultMonId, mon.__kaLegacyId = id, id
    end
    local existing = V.entry(vault, id)
    if existing and not existing.lease then return nil, "unleased_duplicate" end
    if existing and existing.lease and owner and owner.saveIdentity
        and existing.lease.owner ~= owner.saveIdentity
        and existing.lease.owner ~= owner.edition then
      return nil, "lease_owner_mismatch"
    end
    local incoming = V.canonicalizeMon(mon, {
      data = data, edition = owner and owner.edition,
      originGame = owner and owner.edition,
      originRun = owner and owner.saveIdentity,
      vaultMonId = id, existing = existing,
    })
    local tx = nextTransaction(vault, "deposit", owner, id)
    if item then
      tx.heldSplit={schema='kasc.bank-held-split/v1',itemId=item,quantity=1,scope=scope}
    end
    incoming.heldItem=nil
    incoming.current.payload.item=nil
    incoming.current.payload.heldItem=nil
    refreshEntryHash(incoming)
    tx.candidateEntry = incoming
    tx.candidateSha256 = incoming.payloadSha256
    tx.recoveryEntry = copy(existing)
    if existing then
      existing.lease = {
        version = V.TRANSACTION_VERSION,
        transactionId = tx.transactionId,
        owner = stringId(owner and owner.saveIdentity)
          or stringId(owner and owner.edition) or "unknown",
        edition = owner and owner.edition,
        state = "depositing",
      }
    end
    return tx
  end

  function V.markSourceSaved(vault, txId, saveDigest)
    local tx = transaction(vault, txId)
    if not tx or tx.direction ~= "deposit" or tx.state ~= "prepared" then
      return nil, "invalid_transaction_state"
    end
    tx.state, tx.sourceSaveDigest, tx.updatedAt =
      "source_saved", tostring(saveDigest), now()
    return tx
  end

  function V.verifyDeposit(vault, txId, sourceSave)
    local tx = transaction(vault, txId)
    if not tx or tx.direction ~= "deposit"
        or (tx.state ~= "prepared" and tx.state ~= "source_saved") then
      return nil, "invalid_transaction_state"
    end
    if #matchingMons(sourceSave, tx.vaultMonId) ~= 0 then
      return nil, "source_still_contains_pokemon"
    end
    tx.state, tx.updatedAt = "verified", now()
    return tx
  end

  function V.completeDeposit(vault, txId)
    local tx = transaction(vault, txId)
    if not tx or tx.direction ~= "deposit" or tx.state ~= "verified" then
      return nil, "invalid_transaction_state"
    end
    local entry = V.entry(vault, tx.vaultMonId)
    if type(tx.candidateEntry)~='table' or tx.candidateSha256~=digest(entryPayload(tx.candidateEntry)) then
      return nil,'candidate_checksum_mismatch'
    end
    -- Stage both halves first. A failure must leave the verified journal,
    -- Pokémon entry and item stock unchanged for crash recovery/retry.
    local stagedEntry=entry and copy(entry) or copy(tx.candidateEntry)
    if entry then monotonicMerge(stagedEntry,tx.candidateEntry) end
    local stagedItems
    if tx.heldSplit then
      local split=tx.heldSplit
      if type(split)~='table' or split.schema~='kasc.bank-held-split/v1'
          or split.quantity~=1 or upper(split.itemId)~=split.itemId
          or not split.itemId
          or split.scope~=(classifyItem(split.itemId)=='crossgen_mega' and 'crossgen_mega' or 'kanto_only')
          or stagedEntry.heldItem or stagedEntry.current.payload.item or stagedEntry.current.payload.heldItem then
        return nil,'invalid_held_split'
      end
      stagedItems={items=copy(vault.items)}
      local credited,creditErr=V.addItem(stagedItems,split.itemId,1,{
        source='held-deposit',edition=tx.owner and tx.owner.edition,receiptId=tx.transactionId})
      if not credited then return nil,creditErr end
    end
    if entry then
      for key in pairs(entry)do entry[key]=nil end
      for key,value in pairs(stagedEntry)do entry[key]=value end
    else
      entry=stagedEntry;vault.pokemon[#vault.pokemon+1]=entry
    end
    if stagedItems then vault.items=stagedItems.items end
    tx.state, tx.completedAt, tx.updatedAt = "completed", now(), now()
    entry.lease = nil
    entry.transferHistory = appendUnique(entry.transferHistory, {
      transactionId = tx.transactionId,
      direction = "deposit",
      edition = tx.owner and tx.owner.edition,
      completedAt = tx.completedAt,
      sourceSha256 = tx.sourceSaveDigest,
    }, "transactionId")
    tx.candidateEntry = nil
    vault.updatedAt = now()
    return tx
  end

  function V.recover(vault, txId, save)
    local tx = transaction(vault, txId)
    if not tx then return nil, "unknown_transaction" end
    if tx.state == "completed" or tx.state == "rolled_back" then
      return tx.state
    end
    local matches = matchingMons(save, tx.vaultMonId)
    if tx.direction == "withdraw" then
      if #matches == 1 then
        if tx.state == "prepared" then tx.state = "target_saved" end
        -- Re-verify persisted targets even after a verified-phase crash.
        if tx.state == "verified" then tx.state = "target_saved" end
        local verified, err = V.verifyWithdrawal(vault, txId, save)
        if not verified then return nil, err end
        local completed, completeErr = V.completeWithdrawal(vault, txId)
        return completed and "completed" or nil, completeErr
      elseif #matches == 0 then
        local entry = V.entry(vault, tx.vaultMonId)
        if entry and entry.lease and entry.lease.transactionId == txId then
          entry.lease = copy(tx.recoveryEntry and tx.recoveryEntry.lease)
        end
        tx.state, tx.updatedAt = "rolled_back", now()
        return "rolled_back"
      end
    else
      if #matches == 0 then
        if tx.state == "prepared" then tx.state = "source_saved" end
        if tx.state ~= "verified" then
          local verified, err = V.verifyDeposit(vault, txId, save)
          if not verified then return nil, err end
        end
        local completed, completeErr = V.completeDeposit(vault, txId)
        return completed and "completed" or nil, completeErr
      elseif #matches == 1 then
        local entry = V.entry(vault, tx.vaultMonId)
        if entry then entry.lease = copy(tx.recoveryEntry
          and tx.recoveryEntry.lease) end
        tx.state, tx.updatedAt = "rolled_back", now()
        return "rolled_back"
      end
    end
    quarantine(vault, "transaction_recovery_conflict", {
      transactionId = txId, copies = #matches, save = copy(save),
    })
    tx.state, tx.updatedAt = "quarantined", now()
    return nil, "contradictory_state"
  end

  function V.exportPackage(vault, context)
    local normalized, normalizeErr = V.normalize(vault)
    if not normalized then return nil, normalizeErr end
    local payload = copy(normalized)
    local payloadSha = assert(digest(payload))
    local entryHashes = {}
    for _, entry in ipairs(payload.pokemon) do
      entryHashes[entry.vaultMonId] = entry.payloadSha256
    end
    local itemHashes = {}
    for id, entry in pairs(payload.items or {}) do
      itemHashes[id] = entry.payloadSha256
    end
    local manifest = {
      kind = V.PACKAGE_KIND,
      packageVersion = V.PACKAGE_VERSION,
      schemaVersion = V.SCHEMA_VERSION,
      vaultId = payload.vaultId,
      createdAt = now(),
      source = context and context.source,
      engineVersion = context and context.engineVersion,
      payloadSha256 = payloadSha,
      entrySha256 = entryHashes,
      itemSha256 = itemHashes,
      containsRom = false,
      absolutePaths = false,
    }
    return { manifest = manifest, payload = payload }
  end

  function V.previewImport(vault, package)
    if type(package) ~= "table" or type(package.manifest) ~= "table"
        or package.manifest.kind ~= V.PACKAGE_KIND
        or package.manifest.packageVersion ~= V.PACKAGE_VERSION
        or type(package.payload) ~= "table" then
      return nil, "invalid_package"
    end
    local actual = digest(package.payload)
    if actual ~= package.manifest.payloadSha256 then
      return nil, "checksum_mismatch"
    end
    local normalized, normalizeErr = V.normalize(package.payload)
    if not normalized then return nil, normalizeErr end
    for _, entry in ipairs(normalized.pokemon) do
      if package.manifest.entrySha256[entry.vaultMonId]
          ~= entry.payloadSha256 then return nil, "entry_checksum_mismatch" end
    end
    for id, entry in pairs(normalized.items or {}) do
      if type(package.manifest.itemSha256) ~= "table"
          or package.manifest.itemSha256[id] ~= entry.payloadSha256 then
        return nil, "item_checksum_mismatch"
      end
    end
    local merge = V.previewMerge(vault, normalized.pokemon)
    merge.itemActions = {}
    merge.itemAdded, merge.itemMerged, merge.itemConflicts = 0, 0, 0
    for id, incoming in pairs(normalized.items or {}) do
      local present = V.item(vault, id)
      local action
      if not present then
        action, merge.itemAdded = "add", merge.itemAdded + 1
      elseif present.scope ~= incoming.scope then
        action, merge.itemConflicts = "conflict", merge.itemConflicts + 1
      else
        action, merge.itemMerged = "merge", merge.itemMerged + 1
      end
      merge.itemActions[#merge.itemActions + 1] = {
        action = action, itemId = id, entry = copy(incoming),
      }
    end
    table.sort(merge.itemActions, function(a, b) return a.itemId < b.itemId end)
    merge.kind = "vault_import_preview"
    merge.package = copy(package)
    merge.packageSha256 = package.manifest.payloadSha256
    merge.importedQuarantine = #normalized.quarantine
    return merge
  end

  function V.applyImport(vault, preview)
    local packageSha = preview and preview.packageSha256
    if not stringId(packageSha) then return nil, "invalid_import_preview" end
    local prior = vault.importReceipts[packageSha]
    if prior then
      local repeated = copy(prior)
      repeated.status = "already_applied"
      return repeated
    end
    V.applyMerge(vault, preview, { source = "package:" .. packageSha })
    for _, action in ipairs(preview.itemActions or {}) do
      local present = V.item(vault, action.itemId)
      if action.action == "add" and not present then
        vault.items[action.itemId] = copy(action.entry)
      elseif action.action == "merge" and present
          and present.scope == action.entry.scope then
        present.quantity = math.max(integer(present.quantity, 0, 0),
          integer(action.entry.quantity, 0, 0))
        for _, row in ipairs(action.entry.provenance or {}) do
          present.provenance = appendUnique(present.provenance, row)
        end
        refreshItemHash(present)
      elseif action.action == "conflict" then
        quarantine(vault, "item_scope_conflict", {
          packageSha256 = packageSha, itemId = action.itemId,
          authoritative = copy(present), incoming = copy(action.entry),
        })
      end
    end
    for _, row in ipairs(preview.package.payload.quarantine or {}) do
      quarantine(vault, "imported_quarantine", {
        packageSha256 = packageSha,
        row = copy(row),
      })
    end
    local receipt = {
      receiptId = newId("import"),
      status = "applied",
      packageSha256 = packageSha,
      sourceVaultId = preview.package.manifest.vaultId,
      added = preview.added,
      identical = preview.identical,
      conflicts = preview.conflicts,
      itemAdded = preview.itemAdded or 0,
      itemMerged = preview.itemMerged or 0,
      itemConflicts = preview.itemConflicts or 0,
      createdAt = now(),
    }
    vault.importReceipts[packageSha] = copy(receipt)
    vault.updatedAt = now()
    return receipt
  end

  V.copy = copy
  V.digest = digest
  return V
end
