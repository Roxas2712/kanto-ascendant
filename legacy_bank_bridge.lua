-- Cross-generation PC bridge for Kanto Ascendant's shared Legacy Vault.
--
-- This file deliberately contains no Gen 1 story, map, encounter, title or
-- option hooks.  It consumes only the engine-owned shared-storage capability
-- and the common ui.pc.items seam, so a Gen 2 load remains a minimal Bank UI.

return function(mod, opts)
  opts = opts or {}
  local Serializer = assert(opts.serializer,
    "Legacy Bank Bridge needs the engine SaveSerializer")
  local sha256 = assert(opts.sha256, "Legacy Bank Bridge needs SHA-256")
  local Vault = assert(opts.vault, "Legacy Bank Bridge needs the vault model")
  local Store = assert(opts.store, "Legacy Bank Bridge needs the vault store")
  local Archive = opts.archive
  local ItemRuntime = opts.itemRuntime
  local classifyItem = opts.classifyItem or function() return "kanto_only" end
  local edition = assert(opts.edition, "Legacy Bank Bridge needs edition authority")
  local generation = opts.generation or function() return 1 end
  local i18n = opts.i18n or { text = function(en) return en end }
  local Bag = require("src.inventory.Bag")

  local B = {
    VERSION = 1,
    ROW_ID = "kasc_legacy_bank",
    ITEM_ROW_ID = "kasc_legacy_items",
    EQUIPMENT_SPLIT_SCHEMA = "kasc.bank-held-split/v1",
  }
  local stores = setmetatable({}, { __mode = "k" })
  local helpSeen = setmetatable({}, { __mode = "k" })

  local function copy(value)
    if value == nil then return nil end
    return assert(Serializer.decode(assert(Serializer.encode(value))))
  end

  local function digest(value)
    local ok, body = pcall(Serializer.encode, value)
    return ok and sha256(body) or nil
  end

  local function tr(en, de)
    return i18n.text(en, de)
  end

  local function owner(game, establishIdentity)
    local save = game and game.save
    local meta = save and save.meta
    local storageContext
    local id = meta and (meta.playthroughId or meta.saveIdentity)
      or save and save.playthroughId
    -- Gen 1 and Gen 2 deliberately allocate the opaque playthrough id only
    -- when a public tool first asks for its scoped storage context.  The
    -- shared vault itself has no playthrough component, but every transaction
    -- still needs a stable source/target owner for crash recovery and audit.
    -- Ask the engine for that owner when the player reaches a Bank-capable PC;
    -- never mint or guess one inside the mod.
    if (type(id) ~= "string" or id == "") and establishIdentity ~= false then
      if not (mod.storage and type(mod.storage.context) == "function") then
        return nil, "playthrough_storage_capability_missing"
      end
      local called, context, code, message = pcall(
        mod.storage.context, mod.storage, game)
      if not called then return nil, "playthrough_storage_unavailable" end
      if type(context) ~= "table" then
        return nil, code or message or "save_identity_missing"
      end
      storageContext = context
      id = context.playthroughId
      meta = save and save.meta
    end
    if type(id) ~= "string" or id == "" then
      return nil, "save_identity_missing"
    end
    local current = edition(game)
    if type(current) ~= "string" or current == "" then
      return nil, "edition_missing"
    end
    local saveVersion = save and save.version
    if type(saveVersion) == "string" and saveVersion ~= ""
        and saveVersion ~= current then
      return nil, "edition_context_mismatch"
    end
    if type(storageContext) == "table" and storageContext.gameVersion ~= nil
        and storageContext.gameVersion ~= current then
      return nil, "edition_context_mismatch"
    end
    return { edition = current, saveIdentity = id,
      generation = generation(game) }
  end

  local function boundStore(game)
    if not (game and mod.storage and type(mod.storage.shared) == "function") then
      return nil, "shared_storage_capability_missing"
    end
    if stores[game] then return stores[game] end
    local shared, code, message = mod.storage:shared(game)
    if not shared then return nil, code or "shared_storage_unavailable", message end
    local store, storeErr = Store.new(shared)
    if not store then return nil, storeErr end
    stores[game] = store
    return store
  end

  local function saveGame(game)
    if not (game and type(game.writeSave) == "function") then
      return nil, "game_save_unavailable"
    end
    local ok, wrote = pcall(game.writeSave, game)
    if not ok or wrote ~= true then return nil, "game_save_failed" end
    return digest(game.save) or "saved"
  end

  local function itemRuntime(game)
    local runtime = ItemRuntime or mod.exports and mod.exports.megaEvolution
    if type(runtime) ~= "table" then return nil, "item_runtime_unavailable" end
    runtime.game = game
    return runtime
  end

  local function ownedTransferItems(game)
    local runtime, runtimeErr = itemRuntime(game)
    if not runtime or type(runtime.legacyBankItems) ~= "function" then
      return nil, runtimeErr or "item_runtime_unavailable"
    end
    local ok, items = pcall(runtime.legacyBankItems)
    if not ok or type(items) ~= "table" then
      return nil, "item_inventory_unavailable"
    end
    return items, runtime
  end

  local function shallowCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = child end
    return out
  end

  local function itemStoreSnapshot(save, id)
    local inventory = type(save and save.inventory) == "table"
      and save.inventory or nil
    local pc = type(save and save.pcItems) == "table" and save.pcItems or nil
    return {
      inventory = inventory,
      bagHad = inventory and inventory[id] ~= nil or false,
      bagValue = inventory and inventory[id] or nil,
      pcOriginal = save and save.pcItems or nil,
      pc = pc,
      pcHad = pc and pc[id] ~= nil or false,
      pcValue = pc and pc[id] or nil,
      bagOrderOriginal = save and save.bagOrder or nil,
      bagOrder = type(save and save.bagOrder) == "table"
        and shallowCopy(save.bagOrder) or nil,
    }
  end

  local function restoreItemStores(save, id, snapshot)
    if snapshot.inventory then
      snapshot.inventory[id] = snapshot.bagHad and snapshot.bagValue or nil
      save.inventory = snapshot.inventory
    end
    if snapshot.pc then
      snapshot.pc[id] = snapshot.pcHad and snapshot.pcValue or nil
      save.pcItems = snapshot.pc
    else
      save.pcItems = snapshot.pcOriginal
    end
    if snapshot.bagOrder then
      local order = snapshot.bagOrderOriginal
      for key in pairs(order) do order[key] = nil end
      for key, value in pairs(snapshot.bagOrder) do order[key] = value end
      save.bagOrder = order
    else
      save.bagOrder = snapshot.bagOrderOriginal
    end
  end

  local function kantoItemPlan(game, id, quantity)
    local save = game and game.save
    if type(save) ~= "table" then return nil, "game_save_unavailable" end
    save.inventory = type(save.inventory) == "table" and save.inventory or {}
    local held = math.max(0, math.floor(tonumber(save.inventory[id]) or 0))
    local bagRoom
    if save.inventory[id] ~= nil then
      bagRoom = math.max(0, 99 - held)
    else
      local probe = { inventory = shallowCopy(save.inventory),
        bagOrder = type(save.bagOrder) == "table"
          and shallowCopy(save.bagOrder) or nil }
      local called, added = pcall(Bag.add, probe, id, 1, game.data)
      bagRoom = called and added == true and 99 or 0
    end
    local pc = save.pcItems
    if pc ~= nil and type(pc) ~= "table" then
      return nil, "target_item_storage_full"
    end
    pc = pc or {}
    local pcHeld = math.max(0, math.floor(tonumber(pc[id]) or 0))
    local pcRoom
    if pc[id] ~= nil then
      pcRoom = math.max(0, 99 - pcHeld)
    else
      local stacks = 0
      for _ in pairs(pc) do stacks = stacks + 1 end
      local configured = game.data and game.data.field
        and tonumber(game.data.field.pcItemCap)
      local capacity = configured and math.max(1, math.floor(configured)) or 50
      pcRoom = stacks < capacity and 99 or 0
    end
    local bag = math.min(quantity, bagRoom)
    local pcAdd = quantity - bag
    if pcAdd > pcRoom then return nil, "target_item_storage_full" end
    return { bag = bag, pc = pcAdd, beforeBag = held, beforePc = pcHeld }
  end

  local function importVaultItem(game, id, quantity, scope, plan)
    if scope == "crossgen_mega" then
      local runtime, runtimeErr = itemRuntime(game)
      if not runtime or type(runtime.importLegacyBankItem) ~= "function" then
        return nil, runtimeErr or "item_runtime_unavailable"
      end
      local called, receipt, importErr = pcall(
        runtime.importLegacyBankItem, id)
      if not called or not receipt then
        return nil, called and importErr or "item_import_failed"
      end
      return { kind = "mega", runtime = runtime, receipt = receipt }
    end
    if generation(game) >= 2 then return nil, "kanto_item_locked_in_gen2" end
    local save = game and game.save
    if type(save) ~= "table" then return nil, "game_save_unavailable" end
    save.inventory = type(save.inventory) == "table" and save.inventory or {}
    plan = plan or kantoItemPlan(game, id, quantity)
    if not plan then return nil, "target_item_storage_full" end
    local snapshot = itemStoreSnapshot(save, id)
    if plan.bag > 0 then
      local called, added = pcall(Bag.add, save, id, plan.bag, game.data)
      if not called or added ~= true then
        restoreItemStores(save, id, snapshot)
        return nil, "target_item_storage_full"
      end
    end
    if plan.pc > 0 then
      save.pcItems = type(save.pcItems) == "table" and save.pcItems or {}
      save.pcItems[id] = (tonumber(save.pcItems[id]) or 0) + plan.pc
    end
    return { kind = "kanto", save = save, id = id, snapshot = snapshot }
  end

  local function rollbackVaultItem(staged)
    if type(staged) ~= "table" then return false end
    if staged.kind == "mega" then
      return type(staged.runtime.rollbackLegacyBankItem) == "function"
        and pcall(staged.runtime.rollbackLegacyBankItem, staged.receipt)
    end
    if staged.kind == "kanto" and type(staged.save) == "table" then
      restoreItemStores(staged.save, staged.id, staged.snapshot)
      return true
    end
    return false
  end

  local function party(save)
    save.party = type(save.party) == "table" and save.party or {}
    return save.party
  end

  local function boxMons(save, number)
    if type(save.boxes) ~= "table" then return nil end
    local box = save.boxes[number]
    if type(box) ~= "table" then return nil end
    if type(box.pokemon) == "table" then return box.pokemon end
    if type(box.mons) == "table" then return box.mons end
    return box
  end

  local function locate(save, location)
    if type(location) ~= "table" then return nil, "invalid_location" end
    local index = tonumber(location.index)
    if not index or index < 1 or index ~= math.floor(index) then
      return nil, "invalid_location"
    end
    local list
    if location.kind == "party" then
      list = party(save)
    elseif location.kind == "box" then
      list = boxMons(save, tonumber(location.box) or save.currentBox or 1)
    end
    if type(list) ~= "table" or type(list[index]) ~= "table" then
      return nil, "pokemon_not_found"
    end
    return { list = list, index = index, mon = list[index] }
  end

  local function insertAt(list, index, mon)
    index = math.max(1, math.min(index or (#list + 1), #list + 1))
    table.insert(list, index, mon)
  end

  local function place(game, mon, destination)
    destination = destination or {}
    local save = game.save
    if destination.kind ~= "box" and #party(save) < 6 then
      local list = party(save)
      list[#list + 1] = mon
      return { kind = "party", list = list, index = #list }
    end
    local number = tonumber(destination.box) or save.currentBox or 1
    local list = boxMons(save, number)
    if type(list) ~= "table" then return nil, "target_box_unavailable" end
    local limit = tonumber(destination.capacity) or 20
    if #list >= limit then return nil, "target_box_full" end
    list[#list + 1] = mon
    return { kind = "box", box = number, list = list, index = #list }
  end

  local function removePlaced(location)
    if location and location.list and location.list[location.index] then
      table.remove(location.list, location.index)
    end
  end

  local function commit(store, vault, reason)
    local receipt, code, detail = store:commit(vault, { reason = reason })
    return receipt, code, detail
  end

  function B.probe(game, establishIdentity)
    local store, code = boundStore(game)
    if not store then return nil, code end
    local currentOwner, ownerErr = owner(game, establishIdentity)
    if not currentOwner then return nil, ownerErr end
    return { store = store, owner = currentOwner }
  end

  function B.load(game)
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    return probe.store:load()
  end

  function B.initialize(game)
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local existing, code = probe.store:load()
    if existing then return existing end
    if code ~= "vault_not_found" then return nil, code end
    local vault = Vault.newVault()
    local receipt, commitErr = commit(probe.store, vault, "explicit_initialize")
    if not receipt then return nil, commitErr end
    return vault, receipt
  end

  function B.migrateHeldEquipment(game)
    local probe,probeErr=B.probe(game)
    if not probe then return nil,probeErr end
    local vault,loadErr=probe.store:load()
    if not vault then return nil,loadErr end
    local staged,count=Vault.planHeldSplitMigration(vault)
    if not staged then return nil,count end
    if count==0 then return vault end
    local receipt,commitErr=commit(probe.store,staged,'held_equipment_split_migration')
    if not receipt then return nil,commitErr end
    return staged,receipt
  end

  function B.deposit(game, location)
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local vault, loadErr = probe.store:load()
    if not vault then return nil, loadErr end
    local source, sourceErr = locate(game.save, location)
    if not source then return nil, sourceErr end

    local original = copy(source.mon)
    local canonical = Vault.canonicalizeMon(copy(source.mon), {
      data = game.data, edition = probe.owner.edition,
      originGame = probe.owner.edition, originRun = probe.owner.saveIdentity,
    })
    local allowed, compatibilityErr = Vault.compatibility(canonical, {
      data = game.data, edition = probe.owner.edition,
    })
    if not allowed then return nil, compatibilityErr end

    local tx, prepareErr = Vault.prepareDeposit(vault, source.mon,
      probe.owner, game.data)
    if not tx then return nil, prepareErr end
    local preparedMon = copy(source.mon)
    local prepared, preparedErr = commit(probe.store, vault, "deposit_prepared")
    if not prepared then
      source.list[source.index] = original
      return nil, preparedErr
    end

    table.remove(source.list, source.index)
    local saveDigest, saveErr = saveGame(game)
    if not saveDigest then
      insertAt(source.list, source.index, preparedMon)
      Vault.recover(vault, tx.transactionId, game.save)
      commit(probe.store, vault, "deposit_rolled_back")
      return nil, saveErr
    end

    local marked, markErr = Vault.markSourceSaved(vault,
      tx.transactionId, saveDigest)
    if not marked then return nil, markErr end
    local markedReceipt, markedErr = commit(probe.store, vault,
      "deposit_source_saved")
    if not markedReceipt then return nil, "deposit_pending", markedErr end
    local verified, verifyErr = Vault.verifyDeposit(vault,
      tx.transactionId, game.save)
    if not verified then return nil, verifyErr end
    local completed, completeErr = Vault.completeDeposit(vault,
      tx.transactionId)
    if not completed then return nil, completeErr end
    local finalReceipt, finalErr = commit(probe.store, vault,
      "deposit_completed")
    if not finalReceipt then return nil, "deposit_pending", finalErr end
    return {
      direction = "deposit", transactionId = tx.transactionId,
      vaultMonId = tx.vaultMonId, vaultCommit = finalReceipt,
    }
  end

  function B.withdraw(game, vaultMonId, config)
    config = config or {}
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local vault, loadErr = B.migrateHeldEquipment(game)
    if not vault then return nil, loadErr end
    local targetConfig = copy(config)
    targetConfig.data = game.data
    targetConfig.edition = probe.owner.edition
    targetConfig.targetEdition = probe.owner.edition
    targetConfig.expForLevel = function(species, level)
      local definition = game.data.pokemon[species]
      if probe.owner.generation == 2 then
        local Mon = require("src.battle.gen2.Mon")
        return Mon.experienceForLevel(Mon.growthFor(game.data, definition.growthRate), level)
      end
      local Growth = require("src.pokemon.Growth")
      return Growth.expForLevel(definition.growthRate, level, game.data.growth_rates)
    end
    targetConfig.finalizeMon = function(mon)
      local definition = game.data.pokemon[mon.species]
      if probe.owner.generation == 2 then
        local moves = {}
        for _, id in ipairs(mon.moves or {}) do
          local pp = game.data.moves[id].pp or 0
          moves[#moves+1] = { id = id, pp = pp, maxPp = pp }
        end
        mon.moves, mon.pp = moves, nil
      end
      -- Compact/old-host registries may lack stats; never import a boosted
      -- cached block when a real target definition is available.
      if definition and definition.baseStats then
        mon.stats = nil
        if probe.owner.generation == 2 then
          local Mon = require("src.battle.gen2.Mon")
          Mon.refreshStats(mon, game.data)
        else
          require("src.pokemon.Stats").ensure(definition, mon)
          mon.maxHp = mon.stats and mon.stats.hp
        end
      end
      return mon
    end
    targetConfig.accessAllowed = config.accessAllowed ~= false
    local tx, targetOrErr = Vault.prepareWithdrawal(vault,
      vaultMonId, probe.owner, targetConfig)
    if not tx then return nil, targetOrErr end
    local target = targetOrErr
    local prepared, preparedErr = commit(probe.store, vault,
      "withdraw_prepared")
    if not prepared then return nil, preparedErr end

    local placed, placeErr = place(game, target, config.destination)
    if not placed then
      Vault.recover(vault, tx.transactionId, game.save)
      commit(probe.store, vault, "withdraw_rolled_back")
      return nil, placeErr
    end
    local saveDigest, saveErr = saveGame(game)
    if not saveDigest then
      removePlaced(placed)
      Vault.recover(vault, tx.transactionId, game.save)
      commit(probe.store, vault, "withdraw_rolled_back")
      return nil, saveErr
    end

    local marked, markErr = Vault.markTargetSaved(vault,
      tx.transactionId, saveDigest)
    if not marked then return nil, markErr end
    local markedReceipt, markedErr = commit(probe.store, vault,
      "withdraw_target_saved")
    if not markedReceipt then return nil, "withdraw_pending", markedErr end
    local verified, verifyErr = Vault.verifyWithdrawal(vault,
      tx.transactionId, game.save)
    if not verified then return nil, verifyErr end
    local completed, completeErr = Vault.completeWithdrawal(vault,
      tx.transactionId)
    if not completed then return nil, completeErr end
    local finalReceipt, finalErr = commit(probe.store, vault,
      "withdraw_completed")
    if not finalReceipt then return nil, "withdraw_pending", finalErr end
    return {
      direction = "withdraw", transactionId = tx.transactionId,
      vaultMonId = vaultMonId, destination = {
        kind = placed.kind, box = placed.box, index = placed.index,
      }, vaultCommit = finalReceipt,
    }
  end

  function B.withdrawItem(game, itemId, quantity)
    itemId = tostring(itemId or ""):upper()
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    if classifyItem(itemId) == "crossgen_mega" then
      local owned, ownedErr = ownedTransferItems(game)
      if not owned then return nil, ownedErr end
      if (tonumber(owned[itemId]) or 0) > 0 then
        return nil, "item_already_owned"
      end
    end
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local vault, loadErr = probe.store:load()
    if not vault then return nil, loadErr end
    local tx, entryOrErr = Vault.prepareItemWithdrawal(vault, itemId,
      quantity, probe.owner, { targetGeneration = probe.owner.generation })
    if not tx then return nil, entryOrErr end
    local plan
    if entryOrErr.scope == "kanto_only" then
      plan, probeErr = kantoItemPlan(game, tx.itemId, quantity)
      if not plan then return nil, probeErr end
      tx.targetBeforeBag, tx.targetBeforePc = plan.beforeBag, plan.beforePc
      tx.targetBag, tx.targetPc = plan.bag, plan.pc
    end
    local prepared, preparedErr = commit(probe.store, vault,
      "item_withdraw_prepared")
    if not prepared then return nil, preparedErr end

    local staged, importErr = importVaultItem(game, tx.itemId, quantity,
      entryOrErr.scope, plan)
    if not staged then
      Vault.cancelItemTransfer(vault, tx.transactionId)
      commit(probe.store, vault, "item_withdraw_rolled_back")
      return nil, importErr
    end
    local saveDigest, saveErr = saveGame(game)
    if not saveDigest then
      rollbackVaultItem(staged)
      Vault.cancelItemTransfer(vault, tx.transactionId)
      commit(probe.store, vault, "item_withdraw_rolled_back")
      return nil, saveErr
    end
    local marked, markErr = Vault.markItemSaveWritten(vault,
      tx.transactionId, saveDigest)
    if not marked then return nil, markErr end
    local markedReceipt, markedErr = commit(probe.store, vault,
      "item_withdraw_target_saved")
    if not markedReceipt then return nil, "item_withdraw_pending", markedErr end
    local completed, completeErr = Vault.completeItemTransfer(vault,
      tx.transactionId)
    if not completed then return nil, completeErr end
    local finalReceipt, finalErr = commit(probe.store, vault,
      "item_withdraw_completed")
    if not finalReceipt then return nil, "item_withdraw_pending", finalErr end
    return { direction = "item_withdraw", itemId = tx.itemId,
      quantity = quantity, transactionId = tx.transactionId,
      vaultCommit = finalReceipt }
  end

  function B.depositItem(game, itemId, quantity)
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    if classifyItem(itemId) ~= "crossgen_mega" then
      return nil, "item_not_cross_generation"
    end
    local owned, runtimeOrErr = ownedTransferItems(game)
    if not owned then return nil, runtimeOrErr end
    itemId = tostring(itemId or ""):upper()
    if (tonumber(owned[itemId]) or 0) < quantity then
      return nil, "item_not_owned"
    end
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local vault, loadErr = probe.store:load()
    if not vault then return nil, loadErr end
    local tx, prepareErr = Vault.prepareItemDeposit(vault, itemId,
      quantity, probe.owner)
    if not tx then return nil, prepareErr end
    local prepared, preparedErr = commit(probe.store, vault,
      "item_deposit_prepared")
    if not prepared then return nil, preparedErr end

    -- Publish proof of the owned unlock, not the physical removal of the
    -- Ring/Stone. The originating playthrough keeps its Mega capability.
    local saveDigest, saveErr = saveGame(game)
    if not saveDigest then
      Vault.cancelItemTransfer(vault, tx.transactionId)
      commit(probe.store, vault, "item_deposit_rolled_back")
      return nil, saveErr
    end
    local marked, markErr = Vault.markItemSaveWritten(vault,
      tx.transactionId, saveDigest)
    if not marked then return nil, markErr end
    local markedReceipt, markedErr = commit(probe.store, vault,
      "item_deposit_source_saved")
    if not markedReceipt then return nil, "item_deposit_pending", markedErr end
    local completed, completeErr = Vault.completeItemTransfer(vault,
      tx.transactionId)
    if not completed then return nil, completeErr end
    local finalReceipt, finalErr = commit(probe.store, vault,
      "item_deposit_completed")
    if not finalReceipt then return nil, "item_deposit_pending", finalErr end
    return { direction = "item_deposit", itemId = tx.itemId,
      quantity = quantity, transactionId = tx.transactionId,
      vaultCommit = finalReceipt }
  end

  function B.recover(game)
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local vault, loadErr = probe.store:load()
    if not vault then return nil, loadErr end
    local changed, results = false, {}
    for id, tx in pairs(vault.transactions or {}) do
      if tx.state ~= "completed" and tx.state ~= "rolled_back"
          and tx.state ~= "quarantined" then
        local state, code
        if tx.direction == "item_withdraw" or tx.direction == "item_deposit" then
          if type(tx.owner) == "table"
              and tx.owner.saveIdentity ~= probe.owner.saveIdentity then
            state, code = nil, "different_save_owner"
          else
            local owned = false
            if classifyItem(tx.itemId) == "crossgen_mega" then
              local items = ownedTransferItems(game)
              owned = type(items) == "table"
                and (tonumber(items[tx.itemId]) or 0) > 0
            else
              local save = game.save or {}
              local bag = tonumber(save.inventory
                and save.inventory[tx.itemId]) or 0
              local pc = tonumber(save.pcItems and save.pcItems[tx.itemId]) or 0
              owned = bag >= (tonumber(tx.targetBeforeBag) or 0)
                  + (tonumber(tx.targetBag) or tx.quantity or 0)
                and pc >= (tonumber(tx.targetBeforePc) or 0)
                  + (tonumber(tx.targetPc) or 0)
            end
            local saved = tx.state == "target_saved"
              or tx.state == "source_saved"
              or (tx.direction == "item_withdraw" and owned)
              or (tx.direction == "item_deposit"
                and (tx.entitlementCopy == true and owned
                  or tx.entitlementCopy ~= true and not owned))
            if saved then
              if tx.state == "prepared" then
                Vault.markItemSaveWritten(vault, id, digest(game.save) or "recovered")
              end
              local completed, completeErr = Vault.completeItemTransfer(vault, id)
              state, code = completed and "completed" or nil, completeErr
            else
              local cancelled, cancelErr = Vault.cancelItemTransfer(vault, id)
              state, code = cancelled and "rolled_back" or nil, cancelErr
            end
          end
        else
          state, code = Vault.recover(vault, id, game.save)
        end
        results[#results + 1] = { transactionId = id,
          state = state, code = code }
        changed = changed or state == "completed" or state == "rolled_back"
      end
    end
    if changed then
      local receipt, code = commit(probe.store, vault, "explicit_recovery")
      if not receipt then return nil, code end
    end
    return results
  end

  function B.export(game, name)
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local vault, loadErr = probe.store:load()
    if not vault then return nil, loadErr end
    return probe.store:export(name, vault, {
      edition = probe.owner.edition, generation = probe.owner.generation,
    })
  end

  function B.previewImport(game, name)
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local vault, loadErr = probe.store:load()
    if not vault then return nil, loadErr end
    local preview, previewErr = probe.store:previewImport(name, vault)
    if not preview then return nil, previewErr end
    preview.targetVaultSha256 = assert(Vault.digest(vault))
    preview.packageName = name
    return preview
  end

  function B.listPackages(game)
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    return probe.store:listPackages()
  end

  function B.applyImport(game, preview)
    if type(preview) ~= "table"
        or preview.kind ~= "vault_import_preview"
        or type(preview.targetVaultSha256) ~= "string"
        or type(preview.packageName) ~= "string" then
      return nil, "invalid_import_preview"
    end
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local vault, loadErr = probe.store:load()
    if not vault then return nil, loadErr end
    if Vault.digest(vault) ~= preview.targetVaultSha256 then
      return nil, "vault_changed_since_preview"
    end
    local receipt, applyErr = Vault.applyImport(vault, copy(preview))
    if not receipt then return nil, applyErr end
    local committed, commitErr = commit(probe.store, vault,
      "portable_import_applied")
    if not committed then return nil, commitErr end
    local verified, verifyErr = probe.store:load()
    local durable = verified and verified.importReceipts
      and verified.importReceipts[preview.packageSha256]
    if not durable or durable.receiptId ~= receipt.receiptId then
      return nil, "import_readback_failed", verifyErr
    end
    return {
      direction = "portable_import",
      packageName = preview.packageName,
      packageSha256 = preview.packageSha256,
      importReceipt = copy(durable),
      vaultCommit = committed,
    }
  end

  function B.previewArchiveMigration(game)
    if not (Archive and type(Archive.inspectBankMigration) == "function") then
      return nil, "legacy_archive_unavailable"
    end
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local vault, loadErr = probe.store:load()
    if not vault then return nil, loadErr end
    local archive, archiveErr, candidates = Archive.inspectBankMigration()
    if not archive then return nil, archiveErr, candidates end
    if archive.archive and archive.archive.bankAuthority == "shared_vault" then
      local binding = archive.archive.vaultBinding
      if type(binding) ~= "table" or binding.vaultId ~= vault.vaultId then
        return nil, "shared_vault_binding_mismatch"
      end
      if archive.archive.bankMigrationPending ~= true then
        return nil, "archive_already_synchronized"
      end
    end
    local vaultPreview, previewErr = Vault.previewArchiveMigration(vault,
      archive.rawArchive, {
        sourceDigest = archive.sourceSha256,
        sourceEdition = archive.edition or probe.owner.edition,
      })
    if not vaultPreview then return nil, previewErr end
    return {
      kind = "legacy_bank_archive_transfer_preview",
      vaultId = vault.vaultId,
      archive = archive,
      vault = vaultPreview,
    }
  end

  local function archiveBackupPackage(preview)
    local slots = {}
    for _, name in ipairs({ "main", "witness", "backup" }) do
      local source = preview.archive.candidates
        and preview.archive.candidates[name] or { status = "absent" }
      slots[name] = {
        status = source.status,
        sourceVersion = source.sourceVersion,
        sourceSha256 = source.sourceSha256,
        body = source.body,
        rawArchive = copy(source.rawArchive),
        reason = source.reason,
      }
    end
    local payload = {
      kind = "kanto-ascendant.legacy-archive-full-backup",
      version = 1,
      edition = preview.archive.edition,
      authoritativeSource = preview.archive.source,
      authoritativeSha256 = preview.archive.sourceSha256,
      slots = slots,
    }
    local payloadSha = assert(digest(payload))
    return {
      kind = "kanto-ascendant.legacy-archive-backup-package",
      version = 1,
      manifest = {
        payloadSha256 = payloadSha,
        sourceSha256 = preview.archive.sourceSha256,
        sourceVersion = preview.archive.sourceVersion,
        edition = preview.archive.edition,
      },
      payload = payload,
    }
  end

  function B.applyArchiveMigration(game, preview)
    if type(preview) ~= "table"
        or preview.kind ~= "legacy_bank_archive_transfer_preview"
        or type(preview.archive) ~= "table"
        or type(preview.archive.sourceSha256) ~= "string" then
      return nil, "invalid_archive_transfer_preview"
    end
    if not (Archive and type(Archive.inspectBankMigration) == "function"
        and type(Archive.applyBankMigration) == "function") then
      return nil, "legacy_archive_unavailable"
    end
    local probe, probeErr = B.probe(game)
    if not probe then return nil, probeErr end
    local vault, loadErr = probe.store:load()
    if not vault then return nil, loadErr end
    if vault.vaultId ~= preview.vaultId then
      return nil, "vault_changed_since_preview"
    end
    local inspected, inspectErr = Archive.inspectBankMigration()
    if not inspected then return nil, inspectErr end
    if inspected.sourceSha256 ~= preview.archive.sourceSha256
        or inspected.source ~= preview.archive.source then
      return nil, "archive_source_changed"
    end
    local freshPreview, freshErr = Vault.previewArchiveMigration(vault,
      inspected.rawArchive, {
        sourceDigest = inspected.sourceSha256,
        sourceEdition = inspected.edition or probe.owner.edition,
      })
    if not freshPreview then return nil, freshErr end

    -- The portable, engine-owned package is written before either authority
    -- changes.  It contains main, .tmp and .bak as data-only bytes/tables.
    local package = archiveBackupPackage({ archive = inspected })
    local packageName = ("legacy-archive-v%d-%s-%s"):format(
      tonumber(inspected.sourceVersion) or 0,
      tostring(inspected.edition or probe.owner.edition):lower(),
      inspected.sourceSha256:sub(1, 12))
    local backedUp, backupCode, backupReceipt =
      probe.store.shared:exportPackage(packageName, package)
    if not backedUp then return nil, "archive_backup_failed", backupCode end

    local migration = Vault.applyArchiveMigration(vault,
      freshPreview, game.data)
    if not migration then return nil, "vault_archive_migration_failed" end
    local vaultReceipt, vaultCommitErr = commit(probe.store, vault,
      "archive_migration_committed")
    if not vaultReceipt then return nil, vaultCommitErr end
    local verified, verifyErr = probe.store:load()
    local verifiedMigration = verified and verified.migrationReceipts
      and verified.migrationReceipts[inspected.sourceSha256]
    if not verifiedMigration
        or verifiedMigration.receiptId ~= migration.receiptId then
      return nil, "vault_migration_readback_failed", verifyErr
    end

    -- Only the read-back shared generation may clear the old Bank rows.
    local migratedArchive, archiveApplyErr = Archive.applyBankMigration(
      inspected, {
        version = 1,
        vaultId = verified.vaultId,
        sourceSha256 = inspected.sourceSha256,
        receiptId = verifiedMigration.receiptId,
        packageSha256 = package.manifest.payloadSha256,
        migratedCount = verifiedMigration.migratedRows,
        quarantineCount = verifiedMigration.migratedQuarantine,
        migratedItemCount = verifiedMigration.migratedItems,
      })
    if not migratedArchive then
      return nil, "archive_authority_transfer_pending", archiveApplyErr
    end
    return {
      direction = "archive_to_shared_vault",
      sourceSha256 = inspected.sourceSha256,
      packageName = packageName,
      packageSha256 = package.manifest.payloadSha256,
      packageReceipt = copy(backupReceipt),
      vaultCommit = vaultReceipt,
      migrationReceipt = copy(verifiedMigration),
      archiveBinding = copy(migratedArchive.vaultBinding),
    }
  end

  local function push(game, screen)
    if game and game.stack and type(game.stack.push) == "function" then
      game.stack:push(screen)
      return true
    end
    return nil, "screen_stack_unavailable"
  end

  local function textBox(game, text, done, options)
    local box = mod.ui and mod.ui.TextBox
    if box and type(box.new) == "function" then
      return push(game, box.new(game, text, done, options))
    end
    return nil, "text_box_unavailable"
  end

  local function message(game, text)
    return textBox(game, text)
  end

  local function confirm(game, text, onYes)
    return textBox(game, text, nil, {
      defaultNo = true,
      choice = function(yes)
        if yes == true then onYes() end
      end,
    })
  end

  local function menuClass()
    return mod.ui and (mod.ui.KantoListMenu or mod.ui.ListMenu)
  end

  local function menuOptions(game, options)
    options = options or {}
    if options.messageBox == nil then options.messageBox = true end
    if options.ascendantLayout == nil then options.ascendantLayout = true end
    if options.ascendantStyle == nil then
      options.ascendantStyle = "firered-legacy-storage"
    end
    if options.pageJump == nil then options.pageJump = true end
    if options.footer == nil then
      options.footer = tr("A:SELECT  SEL:HELP", "A:WAHL  SEL:HILFE")
    end
    if options.ascendantStorageDescription == nil then
      options.ascendantStorageDescription = function(item)
        return item and item.help or tr(
          "Choose an action. Nothing moves before confirmation.",
          "Wähle eine Aktion. Vor der Bestätigung wird nichts bewegt.")
      end
    end
    if options.onSelectKey == nil then
      options.onSelectKey = function(item)
        return message(game, item and item.help or tr(
          "Nothing moves before explicit confirmation.",
          "Vor einer ausdrücklichen Bestätigung wird nichts bewegt."))
      end
    end
    return options
  end

  local function makeMenu(game, title, rows, options)
    local menu = menuClass()
    if not (menu and type(menu.new) == "function") then
      return nil, "list_menu_unavailable"
    end
    return menu.new(game, title, rows, menuOptions(game, options))
  end

  local function openMenu(game, title, rows, options)
    local screen, code = makeMenu(game, title, rows, options)
    if not screen then return nil, code end
    return push(game, screen)
  end

  local errors = {
    egg = { "EGGS CANNOT ENTER THE BANK.",
      "EIER KÖNNEN NICHT IN DIE BANK." },
    gorochu = { "GOROCHU REMAINS IN KANTO.",
      "GOROCHU BLEIBT IN KANTO." },
    mega_form = { "THIS MEGA FORM HAS NO VERIFIED BASE-FORM TRANSFER.",
      "FÜR DIESE MEGA-FORM FEHLT EIN GEPRÜFTER GRUNDFORM-TRANSFER." },
    item_unavailable = { "THE HELD ITEM IS NOT AVAILABLE HERE. CHOOSE NEW START OR CUSTOM; THE ORIGINAL STAYS IN THE VAULT.",
      "DAS GETRAGENE ITEM IST HIER NICHT VERFÜGBAR. WÄHLE NEUSTART ODER EIGENE WIEDERGEBURT; DAS ORIGINAL BLEIBT IM VAULT." },
    species_above_251 = { "ONLY POKéMON #001-251 CAN TRANSFER.",
      "NUR POKéMON #001-251 SIND ÜBERTRAGBAR." },
    species_unavailable = { "THIS SPECIES IS NOT AVAILABLE HERE.",
      "DIESE ART IST HIER NICHT VERFÜGBAR." },
    already_leased = { "THIS POKéMON IS ALREADY IN ANOTHER SAVE.",
      "DIESES POKéMON IST BEREITS IN EINEM ANDEREN SPIELSTAND." },
    target_box_full = { "PARTY AND TARGET BOX ARE FULL.",
      "TEAM UND ZIELBOX SIND VOLL." },
    game_save_failed = { "SAVE FAILED. THE TRANSFER WAS ROLLED BACK.",
      "SPEICHERN FEHLGESCHLAGEN. TRANSFER ZURÜCKGEROLLT." },
    kanto_item_locked_in_gen2 = {
      "THIS KANTO ITEM IS STORED SAFELY, BUT CANNOT BE CLAIMED IN GOLD/SILVER/CRYSTAL.",
      "DIESES KANTO-ITEM IST SICHER VERWAHRT, KANN ABER NICHT IN GOLD/SILBER/KRISTALL ABGEHOLT WERDEN." },
    item_already_leased = { "THIS ITEM TRANSFER IS ALREADY IN PROGRESS.",
      "DIESER ITEM-TRANSFER LÄUFT BEREITS." },
    item_not_owned = { "THIS MEGA ITEM IS NOT IN THIS SAVE.",
      "DIESES MEGA-ITEM IST NICHT IN DIESEM SPIELSTAND." },
    item_already_owned = { "THIS MEGA ITEM IS ALREADY ACTIVE IN THIS SAVE.",
      "DIESES MEGA-ITEM IST IN DIESEM SPIELSTAND BEREITS AKTIV." },
    item_not_cross_generation = {
      "ONLY THE MEGA RING AND OFFICIAL MEGA STONES CROSS GENERATIONS.",
      "NUR MEGA-RING UND OFFIZIELLE MEGA-STEINE WECHSELN DIE GENERATION." },
    archive_already_synchronized = {
      "THE LEGACY ARCHIVE IS ALREADY SYNCHRONIZED.",
      "DAS VERMÄCHTNIS-ARCHIV IST BEREITS SYNCHRONISIERT." },
    shared_vault_binding_mismatch = {
      "THIS ARCHIVE IS BOUND TO A DIFFERENT SHARED VAULT.",
      "DIESES ARCHIV IST AN EINEN ANDEREN GEMEINSAMEN VAULT GEBUNDEN." },
  }

  local function errorText(code)
    if code=='held_item_alias_conflict' or code=='invalid_held_item' then
      return tr('HELD ITEM DATA IS AMBIGUOUS. NOTHING WAS MOVED.',
        'TRAGEITEM-DATEN SIND WIDERSPRÜCHLICH. NICHTS WURDE VERSCHOBEN.')
    end
    if code=='held_split_receipt_conflict' then
      return tr('ITEM SPLIT RECEIPT CONFLICT. THE ORIGINAL BANK IS UNCHANGED.',
        'KONFLIKT IM ITEM-TRENNBELEG. DIE URSPRÜNGLICHE BANK BLEIBT UNVERÄNDERT.')
    end
    local row = errors[code]
    return row and tr(row[1], row[2])
      or tr("LEGACY BANK ERROR: ", "VERMÄCHTNIS-BANK-FEHLER: ")
        .. tostring(code or "unknown")
  end

  local function monLabel(entry)
    return tostring(entry and entry.identity and entry.identity.nickname
      or entry and entry.current and entry.current.species
      or entry and entry.species or "POKéMON")
  end

  local function saveMonLabel(mon)
    return tostring(mon and (mon.nickname or mon.name or mon.species)
      or "POKéMON")
  end

  local function itemLabel(game, id)
    local items = game and game.data and game.data.items
    local definition = type(items) == "table" and items[id] or nil
    return tostring(type(definition) == "table" and definition.name
      or id):gsub("_", " ")
  end

  local function refreshPartyLocations(list)
    for index, row in ipairs(list and list.rows or {}) do
      if type(row.value) == "table" then row.value.index = index end
    end
  end

  local function removeCurrent(list)
    if list and type(list.removeCurrent) == "function" then
      list:removeCurrent()
      return
    end
    if list and type(list.rows) == "table" and tonumber(list.index) then
      table.remove(list.rows, list.index)
    end
  end

  local function openDeposit(game, sourceBox)
    local currentParty = sourceBox and boxMons(game.save, sourceBox) or party(game.save)
    if not sourceBox and #currentParty <= 1 then
      return message(game, tr("KEEP AT LEAST ONE PARTY POKéMON.",
        "BEHALTE MINDESTENS EIN POKéMON IM TEAM."))
    end
    local rows = {}
    for index, mon in ipairs(currentParty) do
      rows[#rows + 1] = {
        label = saveMonLabel(mon), right = "L" .. tostring(mon.level or "?"),
        value = { kind = sourceBox and "box" or "party", box = sourceBox, index = index },
        help = tr(
          ("Deposit %s only after a confirmed, verified source-save transaction.")
            :format(saveMonLabel(mon)),
          ("Lege %s erst nach einer bestätigten und geprüften Quell-Save-Transaktion ab.")
            :format(saveMonLabel(mon))),
      }
    end
    local list
    list = assert(makeMenu(game, sourceBox and ("BOX %02d"):format(sourceBox)
      or tr("DEPOSIT PARTY", "TEAM ABLEGEN"), rows, {
      footer = tr("A:STORE  B:BACK", "A:ABLG  B:ZURÜCK"),
      pageJump = true,
      onChoose = function(item)
        if not (item and type(item.value) == "table") then return end
        if not sourceBox and #party(game.save) <= 1 then
          list.footer = tr("KEEP ONE PARTY POKéMON", "EIN TEAM-POKéMON BEHALTEN")
          return
        end
        confirm(game, tr(("Deposit %s into the Legacy Bank?"):format(item.label),
          ("%s in die Vermächtnis-Bank legen?"):format(item.label)),
          function()
            local receipt, code = B.deposit(game, item.value)
            if not receipt then
              list.footer = errorText(code)
              return
            end
            removeCurrent(list)
            refreshPartyLocations(list)
            list.footer = tr("DEPOSIT COMPLETE", "ABLAGE ABGESCHLOSSEN")
            message(game, tr("POKéMON DEPOSITED SAFELY.",
              "POKéMON SICHER ABGELEGT."))
          end
        )
      end,
    }))
    return push(game, list)
  end

  local function openDepositBoxes(game)
    local Boxes = require("src.pokemon.Boxes")
    local boxes = Boxes.ensure(game.save)
    local rows = {}
    for index = 1, Boxes.COUNT do
      if #boxes[index] > 0 then
        rows[#rows + 1] = {label=("BOX %02d"):format(index),
          right=tostring(#boxes[index]), value=index}
      end
    end
    if #rows == 0 then return message(game, tr("PC BOXES ARE EMPTY.", "PC-BOXEN SIND LEER.")) end
    return openMenu(game, tr("DEPOSIT FROM PC", "AUS PC ABLEGEN"), rows, {
      pageJump=true, onChoose=function(item)
        if item and item.value then openDeposit(game, item.value) end
      end,
    })
  end

  local function legalCustomMoves(game, entry, species, level)
    return Vault.legalMoves(entry, species, level, {
      data = game.data, targetEdition = edition(game),
    })
  end

  local function completeWithdrawal(game, entry, config, list)
    if not config.destination then
      local Boxes = require("src.pokemon.Boxes")
      local boxes = Boxes.ensure(game.save)
      local rows = {}
      if #party(game.save) < 6 then
        rows[#rows+1] = {label=tr("PARTY", "TEAM"), value={kind="party"}}
      end
      for index=1, Boxes.COUNT do
        if #boxes[index] < Boxes.CAPACITY then
          rows[#rows+1] = {label=("BOX %02d"):format(index),
            right=("%d/%d"):format(#boxes[index],Boxes.CAPACITY),
            value={kind="box",box=index,capacity=Boxes.CAPACITY}}
        end
      end
      if #rows == 0 then return message(game, tr("PARTY AND BOXES ARE FULL.", "TEAM UND BOXEN SIND VOLL.")) end
      return openMenu(game, tr("DESTINATION", "ZIEL WÄHLEN"), rows, {
        pageJump=true, onChoose=function(item)
          if not (item and item.value) then return end
          local selected=copy(config); selected.destination=item.value
          completeWithdrawal(game,entry,selected,list)
        end,
      })
    end
    confirm(game, tr(("Withdraw %s with this Rebirth?"):format(monLabel(entry)),
      ("%s mit dieser Wiedergeburt nehmen?"):format(monLabel(entry))),
      function()
        local receipt, code = B.withdraw(game, entry.vaultMonId, config)
        if not receipt then
          if list then list.footer = errorText(code) end
          message(game, errorText(code))
          return
        end
        if list then
          removeCurrent(list)
          list.footer = tr("WITHDRAWAL COMPLETE", "ENTNAHME ABGESCHLOSSEN")
        end
        message(game, tr("POKéMON WITHDRAWN SAFELY.",
          "POKéMON SICHER ENTNOMMEN."))
      end)
  end

  local function openCustomTraining(game, entry, species, level, moves, list)
    local rows = {
      { label = tr("FRESH TRAINING", "FRISCHES TRAINING"), value = "fresh",
        help = tr("Reset training values for a clean new journey.",
          "Setze Trainingswerte für eine saubere neue Reise zurück.") },
      { label = tr("SCALED TRAINING", "SKALIERTES TRAINING"), value = "scaled",
        help = tr("Keep bounded training progress for the selected level.",
          "Behalte begrenzten Trainingsfortschritt für das gewählte Level.") },
      { label = tr("PRESERVE TRAINING", "TRAINING BEHALTEN"),
        value = "preserved",
        help = tr("Preserve the recorded training and friendship values.",
          "Behalte die gespeicherten Trainings- und Freundschaftswerte.") },
    }
    return openMenu(game, tr("CUSTOM TRAINING", "TRAINING WÄHLEN"), rows, {
      onChoose = function(item)
        if not (item and item.value) then return end
        completeWithdrawal(game, entry, {
          mode = "custom", species = species, level = level,
          moves = copy(moves), training = item.value,
          item = entry.heldItem,
        }, list)
      end,
    })
  end

  local function openCustomMoves(game, entry, species, level, list)
    local available = legalCustomMoves(game, entry, species, level)
    if #available == 0 then
      return message(game, errorText("no_legal_moves"))
    end
    local selected, selectedOrder = {}, {}
    for _, move in ipairs(entry.current and entry.current.moves or {}) do
      if #selectedOrder < 4 then
        for _, allowed in ipairs(available) do
          if allowed == move and not selected[move] then
            selected[move] = true
            selectedOrder[#selectedOrder + 1] = move
          end
        end
      end
    end
    if #selectedOrder == 0 then
      selected[available[1]] = true
      selectedOrder[1] = available[1]
    end
    local rows = {
      { label = tr("DONE", "FERTIG"), value = "__done__",
        right = tostring(#selectedOrder) .. "/4",
        help = tr("Continue with the selected one to four legal moves.",
          "Fahre mit den gewählten ein bis vier legalen Attacken fort.") },
    }
    for _, move in ipairs(available) do
      rows[#rows + 1] = { label = move, value = move,
        right = selected[move] and "*" or "",
        help = tr("Toggle this remembered, target-edition legal move.",
          "Schalte diese erinnerte und in der Zieledition legale Attacke um.") }
    end
    local moveList
    moveList = assert(makeMenu(game,
      tr("CUSTOM MOVES", "ATTACKEN WÄHLEN"),
      rows, {
        footer = tr("SELECT 1-4 MOVES", "WÄHLE 1-4 ATTACKEN"),
        pageJump = true,
        onChoose = function(item)
          if not item then return end
          if item.value == "__done__" then
            if #selectedOrder < 1 then
              moveList.footer = tr("SELECT AT LEAST ONE MOVE",
                "WÄHLE MINDESTENS EINE ATTACKE")
              return
            end
            openCustomTraining(game, entry, species, level,
              selectedOrder, list)
            return
          end
          local move = item.value
          if selected[move] then
            selected[move] = nil
            for index, chosen in ipairs(selectedOrder) do
              if chosen == move then table.remove(selectedOrder, index) break end
            end
            item.right = ""
          elseif #selectedOrder < 4 then
            selected[move] = true
            selectedOrder[#selectedOrder + 1] = move
            item.right = "*"
          else
            moveList.footer = tr("FOUR MOVES ALREADY SELECTED",
              "BEREITS VIER ATTACKEN GEWÄHLT")
          end
          rows[1].right = tostring(#selectedOrder) .. "/4"
        end,
      }))
    return push(game, moveList)
  end

  local function openCustomLevel(game, entry, species, list)
    local maximum = math.max(5, math.min(100,
      tonumber(entry.progress and entry.progress.highestLevel) or 5))
    local rows = {}
    for level = 5, maximum do
      rows[#rows + 1] = { label = tr("LEVEL ", "LEVEL ") .. tostring(level),
        value = level,
        help = tr("Choose a level not above this POKéMON's recorded peak.",
          "Wähle ein Level höchstens bis zum gespeicherten Höchststand.") }
    end
    return openMenu(game, tr("CUSTOM LEVEL", "LEVEL WÄHLEN"), rows, {
      pageJump = true,
      onChoose = function(item)
        if item and item.value then
          openCustomMoves(game, entry, species, item.value, list)
        end
      end,
    })
  end

  local function openCustomSpecies(game, entry, list)
    local rows, registry = {}, game.data and game.data.pokemon or {}
    for _, species in ipairs(entry.evolution and entry.evolution.allowedStages
        or { entry.species }) do
      local definition = registry[species]
      if definition and (tonumber(definition.dex) or 0) <= 251 then
        rows[#rows + 1] = { label = species, value = species,
          help = tr("Choose an evolution stage already unlocked in its history.",
            "Wähle eine in seiner Historie bereits freigeschaltete Entwicklungsstufe.") }
      end
    end
    if #rows == 0 then return message(game, errorText("species_unavailable")) end
    return openMenu(game, tr("CUSTOM SPECIES", "ART WÄHLEN"), rows, {
      onChoose = function(item)
        if item and item.value then openCustomLevel(game, entry, item.value, list) end
      end,
    })
  end

  local function openRebirth(game, entry, list)
    local rows = {
      { label = tr("ORIGINAL", "ORIGINAL"), value = "original",
        help = tr("Restore species, level, moves, held item, and training as recorded.",
          "Stelle Art, Level, Attacken, getragenes Item und Training wie gespeichert wieder her.") },
      { label = tr("NEW START (LEVEL 5)", "NEUSTART (LEVEL 5)"),
        value = "new_start",
        help = tr("Return at level 5 in its earliest unlocked stage with a legal starter moveset.",
          "Kehre auf Level 5 in der frühesten freigeschalteten Stufe mit legalem Start-Moveset zurück.") },
      { label = tr("CUSTOM", "EIGENE WAHL"), value = "custom",
        help = tr("Choose unlocked species, bounded level, remembered moves, and training policy.",
          "Wähle freigeschaltete Art, begrenztes Level, erinnerte Attacken und Trainingsregel.") },
    }
    return openMenu(game, tr("REBIRTH", "WIEDERGEBURT"), rows, {
      onChoose = function(item)
        if not (item and item.value) then return end
        if item.value == "custom" then
          openCustomSpecies(game, entry, list)
        else
          completeWithdrawal(game, entry, { mode = item.value }, list)
        end
      end,
    })
  end

  local function openWithdraw(game)
    local vault, loadErr = B.load(game)
    if not vault then return message(game, errorText(loadErr)) end
    local rows = {}
    for _, entry in ipairs(vault.pokemon or {}) do
      local allowed, reason = Vault.compatibility(entry, {
        data = game.data, edition = edition(game),
      })
      if entry.lease then allowed, reason = false, "already_leased" end
      rows[#rows + 1] = {
        label = monLabel(entry),
        right = allowed and ("L" .. tostring(entry.current.level or "?"))
          or tr("BLOCK", "SPERR"),
        value = { entry = entry, allowed = allowed, reason = reason },
        help = allowed and tr(
          "Compatible here. Select it to choose a Rebirth policy.",
          "Hier kompatibel. Wähle es für eine Wiedergeburtsregel.")
          or errorText(reason),
      }
    end
    if #rows == 0 then
      return message(game, tr("NO POKéMON ARE STORED.",
        "KEINE POKéMON SIND EINGELAGERT."))
    end
    local list
    list = assert(makeMenu(game,
      tr("WITHDRAW POKéMON", "POKéMON NEHMEN"),
      rows, {
        footer = tr("A:SELECT  B:BACK", "A:WAHL  B:ZURÜCK"),
        pageJump = true,
        onChoose = function(item)
          local value = item and item.value
          if not value then return end
          if not value.allowed then
            message(game, errorText(value.reason))
            return
          end
          openRebirth(game, value.entry, list)
        end,
      }))
    return push(game, list)
  end

  local function openWithdrawItems(game)
    local vault, loadErr = B.load(game)
    if not vault then return message(game, errorText(loadErr)) end
    local localItems = ownedTransferItems(game) or {}
    local rows = {}
    for id, entry in pairs(vault.items or {}) do
      local allowed, reason = Vault.itemCompatibility(entry, generation(game))
      if entry.lease then allowed, reason = false, "item_already_leased" end
      if allowed and classifyItem(id) == "crossgen_mega"
          and (tonumber(localItems[id]) or 0) > 0 then
        allowed, reason = false, "item_already_owned"
      end
      rows[#rows + 1] = {
        label = itemLabel(game, id),
        right = allowed and ("x" .. tostring(entry.quantity or 0))
          or tr("LOCK", "SPERR"),
        value = { id = id, allowed = allowed, reason = reason },
        help = allowed and (classifyItem(id) == "crossgen_mega" and tr(
          "Copy this Mega unlock. The source and shared vault keep it.",
          "Kopiere diese Mega-Freigabe. Ursprung und gemeinsamer Vault behalten sie.") or tr(
          "Kanto item: claimable only in Red, Blue or Yellow.",
          "Kanto-Item: nur in Rot, Blau oder Gelb abholbar."))
          or errorText(reason),
      }
    end
    table.sort(rows, function(a, b) return a.label < b.label end)
    if #rows == 0 then
      return message(game, tr("NO LEGACY ITEMS ARE STORED.",
        "KEINE VERMÄCHTNIS-ITEMS EINGELAGERT."))
    end
    return openMenu(game, tr("WITHDRAW ITEMS", "ITEMS ABHOLEN"), rows, {
      onChoose = function(item)
        local value = item and item.value
        if not value then return end
        if not value.allowed then return message(game, errorText(value.reason)) end
        confirm(game, tr(
          ("Take %s from the shared Legacy Vault?"):format(item.label),
          ("%s aus dem gemeinsamen Vermächtnis-Vault abholen?")
            :format(item.label)), function()
          local receipt, code = B.withdrawItem(game, value.id, 1)
          if not receipt then return message(game, errorText(code)) end
          message(game, tr("ITEM TRANSFERRED.", "ITEM ÜBERTRAGEN."))
        end)
      end,
    })
  end

  local function openDepositItems(game)
    local owned, runtimeErr = ownedTransferItems(game)
    if not owned then return message(game, errorText(runtimeErr)) end
    local rows = {}
    for id, count in pairs(owned) do
      if classifyItem(id) == "crossgen_mega" and (tonumber(count) or 0) > 0 then
        rows[#rows + 1] = { label = itemLabel(game, id), right = "x1", value = id,
          help = tr(
            "Share a copy of this Mega unlock. It stays usable in this save.",
            "Teile eine Kopie dieser Mega-Freigabe. Sie bleibt hier nutzbar.") }
      end
    end
    table.sort(rows, function(a, b) return a.label < b.label end)
    if #rows == 0 then
      return message(game, tr("NO TRANSFERABLE MEGA ITEMS IN THIS SAVE.",
        "KEINE ÜBERTRAGBAREN MEGA-ITEMS IN DIESEM SPIELSTAND."))
    end
    return openMenu(game, tr("COPY MEGA ITEMS", "MEGA-ITEMS KOPIEREN"), rows, {
      onChoose = function(item)
        if not (item and item.value) then return end
        confirm(game, tr(
          ("Share a copy of %s? You keep the original."):format(item.label),
          ("Kopie von %s teilen? Das Original bleibt bei dir.")
            :format(item.label)), function()
          local receipt, code = B.depositItem(game, item.value, 1)
          if not receipt then return message(game, errorText(code)) end
          message(game, tr("MEGA UNLOCK SHARED. ORIGINAL KEPT.", "MEGA-FREIGABE GETEILT. ORIGINAL BEHALTEN."))
        end)
      end,
    })
  end

  function B.openItems(game)
    local vault, loadErr = B.migrateHeldEquipment(game)
    if not vault then return message(game, errorText(loadErr)) end
    local stored = 0
    for _, entry in pairs(vault.items or {}) do
      if (tonumber(entry.quantity) or 0) > 0 then stored = stored + 1 end
    end
    local owned = ownedTransferItems(game) or {}
    local portable = 0
    for _, count in pairs(owned) do
      if (tonumber(count) or 0) > 0 then portable = portable + 1 end
    end
    return openMenu(game, tr("LEGACY ITEMS", "VERMÄCHTNIS-ITEMS"), {
      { label = tr("WITHDRAW ITEMS", "ITEMS ABHOLEN"), value = "withdraw",
        right = tostring(stored), help = tr(
          "Kanto supplies remain locked in Gold/Silver/Crystal. Mega Ring and official Mega Stones can cross.",
          "Kanto-Vorräte bleiben in Gold/Silber/Kristall gesperrt. Mega-Ring und offizielle Mega-Steine dürfen wechseln.") },
      { label = tr("COPY MEGA ITEMS", "MEGA-ITEMS KOPIEREN"), value = "deposit",
        right = tostring(portable), help = tr(
          "Copy a local Mega Ring or official Mega Stone unlock into the shared vault without removing it here.",
          "Kopiere die Freigabe für Mega-Ring oder offiziellen Mega-Stein in den Vault, ohne sie hier zu entfernen.") },
    }, { onChoose = function(item)
      if item and item.value == "withdraw" then return openWithdrawItems(game) end
      if item and item.value == "deposit" then return openDepositItems(game) end
    end })
  end

  local function portableName(game, vault)
    local current = tostring(edition(game) or "edition"):lower()
      :gsub("[^a-z0-9_-]", "-")
    return ("legacy-bank-%s-%s"):format(current,
      assert(Vault.digest(vault)):sub(1, 12))
  end

  local function openExport(game)
    local vault, loadErr = B.load(game)
    if not vault then return message(game, errorText(loadErr)) end
    local name = portableName(game, vault)
    return confirm(game, tr(("Export portable package %s?"):format(name),
      ("Portables Paket %s exportieren?"):format(name)), function()
        local receipt, code = B.export(game, name)
        if not receipt then return message(game, errorText(code)) end
        message(game, tr("PORTABLE PACKAGE EXPORTED: ",
          "PORTABLES PAKET EXPORTIERT: ") .. name)
      end)
  end

  local function openImport(game)
    local names, listErr = B.listPackages(game)
    if not names then return message(game, errorText(listErr)) end
    if #names == 0 then
      return message(game, tr("NO PORTABLE PACKAGES FOUND.",
        "KEINE PORTABLEN PAKETE GEFUNDEN."))
    end
    local rows = {}
    for _, name in ipairs(names) do
      rows[#rows + 1] = { label = name, value = name,
        help = tr(
          "Read and verify this package, then show merge counts without changing the vault.",
          "Lies und prüfe dieses Paket und zeige die Zusammenführungszahlen ohne Vault-Änderung.") }
    end
    return openMenu(game, tr("IMPORT PACKAGE", "PAKET IMPORTIEREN"), rows, {
      pageJump = true,
      onChoose = function(item)
        if not (item and item.value) then return end
        local preview, code = B.previewImport(game, item.value)
        if not preview then return message(game, errorText(code)) end
        local summary = tr(
          ("Preview %s:\n+%d same %d conflicts %d\nApply import?"):format(
            item.value, preview.added or 0, preview.identical or 0,
            preview.conflicts or 0),
          ("Vorschau %s:\n+%d gleich %d Konflikte %d\nImport anwenden?"):format(
            item.value, preview.added or 0, preview.identical or 0,
            preview.conflicts or 0))
        confirm(game, summary, function()
          local receipt, applyErr = B.applyImport(game, preview)
          if not receipt then return message(game, errorText(applyErr)) end
          message(game, tr("IMPORT APPLIED SAFELY.",
            "IMPORT SICHER ANGEWENDET."))
        end)
      end,
    })
  end

  local function openArchiveMigration(game)
    local preview, code = B.previewArchiveMigration(game)
    if not preview then return message(game, errorText(code)) end
    local summary = tr(
      ("Archive v%d: %d ready, %d quarantined, %d items.\nBack up and synchronize?")
        :format(preview.archive.sourceVersion or 0,
          preview.vault.available or 0, preview.vault.quarantined or 0,
          preview.vault.itemRows or 0),
      ("Archiv v%d: %d bereit, %d isoliert, %d Items.\nSichern und synchronisieren?")
        :format(preview.archive.sourceVersion or 0,
          preview.vault.available or 0, preview.vault.quarantined or 0,
          preview.vault.itemRows or 0))
    return confirm(game, summary, function()
      local receipt, applyErr = B.applyArchiveMigration(game, preview)
      if not receipt then return message(game, errorText(applyErr)) end
      message(game, tr("LEGACY ARCHIVE SYNCHRONIZED SAFELY.",
        "VERMÄCHTNIS-ARCHIV SICHER SYNCHRONISIERT."))
    end)
  end

  local function bankHelpText()
    return tr(
      "The edition-neutral LEGACY BANK connects this save to one shared vault."
        .. "\fDEPOSIT uses crash-safe staging and verified saves. WITHDRAW offers ORIGINAL, NEW START (L5), or CUSTOM Rebirth."
        .. "\fEXPORT writes a SHA-256 checked portable package. IMPORT always shows a merge preview first."
        .. "\fPOKéMON #001-251 transfer under the target edition's rules. Official Megas travel as their base species, remembering their Mega form. Ring and Stone unlocks are copied separately; the source keeps them."
        .. "\fEggs, unknown forms, GOROCHU and later species stay visible but blocked. ORIGINAL requires a target-compatible held item.",
      "Die editionsneutrale VERMÄCHTNIS-BANK verbindet diesen Spielstand mit einem gemeinsamen Vault."
        .. "\fABLEGEN nutzt absturzsichere Stufen und geprüfte Saves. NEHMEN bietet ORIGINAL, NEUSTART (L5) oder EIGENE WIEDERGEBURT."
        .. "\fEXPORT schreibt ein SHA-256-geprüftes portables Paket. IMPORT zeigt immer zuerst eine Zusammenführungsvorschau."
        .. "\fPOKéMON #001-251 wechseln nach den Regeln der Zieledition. Offizielle Megas reisen als Basisart mit gemerkter Mega-Form. Ring-/Steinfreigaben werden separat kopiert; der Ursprung behält sie."
        .. "\fEier, unbekannte Formen, GOROCHU und spätere Arten bleiben sichtbar, aber gesperrt. ORIGINAL braucht ein zielkompatibles getragenes Item.")
  end

  local function showBankHelp(game, done)
    return textBox(game, bankHelpText(), done)
  end

  function B.open(game)
    local vault, code = B.migrateHeldEquipment(game)
    if not vault then
      if code ~= "vault_not_found" then
        return message(game, errorText(code))
      end
      -- Opening the bank is sufficient to create an empty, durable vault.
      -- Boot and read-only capability probes still never allocate one.
      local initialized, initErr = B.initialize(game)
      if not initialized then return message(game, errorText(initErr)) end
      return B.open(game)
    end
    if not helpSeen[game] then
      helpSeen[game] = true
      return showBankHelp(game, function() B.open(game) end)
    end
    local rows = {
      { label = tr("DEPOSIT PARTY", "TEAM ABLEGEN"), value = "deposit",
        help = tr(
          "Deposit a party POKéMON through crash-safe staging. The source save is verified before the shared entry becomes authoritative.",
          "Lege ein Team-POKéMON absturzsicher ab. Der Quell-Save wird geprüft, bevor der gemeinsame Eintrag verbindlich wird.") },
      { label = tr("DEPOSIT FROM PC", "AUS PC ABLEGEN"), value = "deposit_boxes",
        help = tr("Move directly from a PC box into the persistent Legacy Bank.",
          "Verschiebe direkt aus einer PC-Box in die dauerhafte Vermächtnis-Bank.") },
      { label = tr("WITHDRAW POKéMON", "POKéMON NEHMEN"),
        value = "withdraw", right = tostring(#(vault.pokemon or {})),
        help = tr(
          "Withdraw a compatible POKéMON with ORIGINAL, level-5 NEW START, or CUSTOM Rebirth. A lease prevents duplicate copies.",
          "Nimm ein kompatibles POKéMON per ORIGINAL, Level-5-NEUSTART oder EIGENER WIEDERGEBURT. Ein Lease verhindert Duplikate.") },
      { label = tr("LEGACY ITEMS", "VERMÄCHTNIS-ITEMS"), value = "items",
        help = tr(
          "Kanto items stay Kanto-only; Mega Ring and official Mega Stones can move between generations.",
          "Kanto-Items bleiben auf Kanto begrenzt; Mega-Ring und offizielle Mega-Steine dürfen zwischen Generationen wechseln.") },
      { label = tr("EXPORT PACKAGE", "PAKET EXPORTIEREN"), value = "export",
        help = tr(
          "Create a data-only portable package whose filename and manifest bind its exact SHA-256 payload.",
          "Erzeuge ein reines Datenpaket, dessen Dateiname und Manifest den exakten SHA-256-Payload binden.") },
      { label = tr("IMPORT PACKAGE", "PAKET IMPORTIEREN"), value = "import",
        help = tr(
          "List portable packages and preview additions, identical entries, and conflicts before any merge is committed.",
          "Liste portable Pakete und prüfe Ergänzungen, gleiche Einträge und Konflikte, bevor eine Zusammenführung gespeichert wird.") },
    }
    if Archive then
      rows[#rows + 1] = { label = tr("SYNC LEGACY ARCHIVE",
        "VERMÄCHTNIS-ARCHIV SYNC"), value = "migrate_archive",
        help = tr(
          "Back up and synchronize the initial archive or a later Legacy Journey outbox with its bound shared vault.",
          "Sichere und synchronisiere das erste Archiv oder den Ausgang einer späteren Vermächtnis-Reise mit dem gebundenen gemeinsamen Vault.") }
    end
    rows[#rows + 1] = { label = tr("HELP", "HILFE"), value = "help",
      help = bankHelpText() }
    return openMenu(game, tr("LEGACY BANK", "VERMÄCHTNIS-BANK"), rows, {
      footer = tr("SHARED ACROSS EDITIONS", "EDITIONSÜBERGREIFEND"),
      onChoose = function(item)
        local action = item and item.value
        if action == "deposit" then return openDeposit(game) end
        if action == "deposit_boxes" then return openDepositBoxes(game) end
        if action == "withdraw" then return openWithdraw(game) end
        if action == "items" then return B.openItems(game) end
        if action == "export" then return openExport(game) end
        if action == "import" then return openImport(game) end
        if action == "migrate_archive" then return openArchiveMigration(game) end
        if action == "help" then return showBankHelp(game) end
      end,
    })
  end

  mod.exports = mod.exports or {}
  mod.exports.legacyBankBridge = B

  mod.hooks:wrap("ui.pc.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" then return out end
    if not B.probe(game) then return out end
    local bankPresent, itemsPresent = false, false
    for _, row in ipairs(out) do
      if row and row.value == B.ROW_ID then bankPresent = true end
      if row and row.value == B.ITEM_ROW_ID then itemsPresent = true end
    end
    if not bankPresent then
      out[#out + 1] = {
        label = tr("LEGACY BANK", "VERMÄCHTNIS-BANK"),
        value = B.ROW_ID,
        keepOpen = true,
        onSelect = function() B.open(game) end,
      }
    end
    if not itemsPresent then
      out[#out + 1] = {
        label = tr("LEGACY ITEMS", "VERMÄCHTNIS-ITEMS"),
        value = B.ITEM_ROW_ID,
        keepOpen = true,
        onSelect = function() B.openItems(game) end,
      }
    end
    return out
  end, 40)

  mod.events:on("game.ready", function(event)
    -- Capability probe only.  The boot skeleton is not yet a player-selected
    -- New Game/Continue owner, so it must never allocate an identity here.
    -- The first real PC hook or explicit Bank operation establishes it.
    B.probe(event and event.game, false)
  end)

  return B
end
