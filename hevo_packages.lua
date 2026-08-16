-- Authoritative Hidden Evolution package registry and runtime.
--
-- The dungeon awards fifteen permanent packages (five per RED/BLUE/GREEN
-- path) which expose seventeen evolutions.  Package unlocks are the source
-- of truth; the old per-species evolutionUnlocks table is maintained only as
-- a derived compatibility view for saves and downstream UI.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local Bag = opts.bag or require("src.inventory.Bag")
  local beyondKanto = opts.beyondKanto or opts.johtoBoundary
  local P = {
    enabled = opts.enabled ~= false,
    VERSION = 1,
    REACQUIRE_PRICE = 9800,
    ITEM_EFFECT = "KA_HEVO_PACKAGE_ITEM",
    order = {}, byId = {}, byTarget = {}, byItem = {}, byMethod = {},
    byCharacter = { RED = {}, BLUE = {}, GREEN = {} },
    audit = { missingMoves = {}, registeredPackages = 0, registeredTargets = 0 },
  }

  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end

  local function beyondActive(save)
    return not beyondKanto or type(beyondKanto.isActive) ~= "function"
      or beyondKanto.isActive(save or P.activeGame)
  end

  local definitions = {
    {
      id = "protector", character = "RED", kind = "item",
      item = "PROTECTOR", itemName = { en = "PROTECTOR", de = "SCHÜTZER" },
      targets = { { parent = "RHYDON", target = "RHYPERIOR" } },
    },
    {
      id = "magmarizer", character = "RED", kind = "item",
      item = "MAGMARIZER", itemName = { en = "MAGMARIZER", de = "MAGMAISIERER" },
      targets = { { parent = "MAGMAR", target = "MAGMORTAR" } },
    },
    {
      id = "rollout_knowledge", character = "RED", kind = "knowledge",
      move = "ROLLOUT",
      targets = { { parent = "LICKITUNG", target = "LICKILICKY" } },
    },
    {
      id = "ancient_power_red", character = "RED", kind = "knowledge",
      move = "ANCIENTPOWER",
      targets = { { parent = "PILOSWINE", target = "MAMOSWINE" } },
    },
    {
      id = "razor_fang", character = "RED", kind = "item",
      item = "RAZOR_FANG", itemName = { en = "RAZOR FANG", de = "SCHARFZAHN" },
      targets = { { parent = "GLIGAR", target = "GLISCOR" } },
    },

    {
      id = "magnetic_field", character = "BLUE", kind = "field",
      field = "KA_HEVO_MAGNETIC_ALTAR",
      targets = { { parent = "MAGNETON", target = "MAGNEZONE" } },
    },
    {
      id = "electirizer", character = "BLUE", kind = "item",
      item = "ELECTIRIZER", itemName = { en = "ELECTIRIZER", de = "STROMISIERER" },
      targets = { { parent = "ELECTABUZZ", target = "ELECTIVIRE" } },
    },
    {
      id = "ice_field", character = "BLUE", kind = "field",
      field = "KA_HEVO_ICE_ALTAR",
      targets = { { parent = "EEVEE", target = "GLACEON" } },
    },
    {
      id = "razor_claw", character = "BLUE", kind = "item",
      item = "RAZOR_CLAW", itemName = { en = "RAZOR CLAW", de = "SCHARFKLAUE" },
      targets = { { parent = "SNEASEL", target = "WEAVILE" } },
    },
    {
      id = "dubious_disc", character = "BLUE", kind = "item",
      item = "DUBIOUS_DISC", itemName = { en = "DUBIOUS DISC", de = "DUBIOSDISC" },
      targets = { { parent = "PORYGON2", target = "PORYGON_Z" } },
    },

    {
      id = "moss_field", character = "GREEN", kind = "field",
      field = "KA_HEVO_MOSS_ALTAR",
      targets = { { parent = "EEVEE", target = "LEAFEON" } },
    },
    {
      id = "ancient_power_green", character = "GREEN", kind = "knowledge",
      move = "ANCIENTPOWER",
      targets = {
        { parent = "TANGELA", target = "TANGROWTH" },
        { parent = "YANMA", target = "YANMEGA" },
      },
    },
    {
      id = "shiny_stone", character = "GREEN", kind = "item",
      item = "SHINY_STONE", itemName = { en = "SHINY STONE", de = "LEUCHTSTEIN" },
      targets = { { parent = "TOGETIC", target = "TOGEKISS" } },
    },
    {
      id = "double_hit_knowledge", character = "GREEN", kind = "knowledge",
      move = "DOUBLE_HIT",
      targets = { { parent = "AIPOM", target = "AMBIPOM" } },
    },
    {
      id = "dusk_stone", character = "GREEN", kind = "item",
      item = "DUSK_STONE", itemName = { en = "DUSK STONE", de = "FINSTERSTEIN" },
      targets = {
        { parent = "MISDREAVUS", target = "MISMAGIUS" },
        { parent = "MURKROW", target = "HONCHKROW" },
      },
    },
  }

  local function methodId(id)
    return "KA_HEVO_" .. id:upper()
  end

  for _, source in ipairs(definitions) do
    local row = {}
    for key, value in pairs(source) do row[key] = value end
    row.unlockKey = "hevo_package_" .. row.id
    row.method = methodId(row.id)
    row.repeatableSource = "legacy_workshop"
    row.firstGrant = row.kind == "item" and row.item or nil
    row.characterWhitelist = { [row.character] = true }
    row.reacquirePrice = row.kind == "item" and P.REACQUIRE_PRICE or 0
    P.order[#P.order + 1] = row
    P.byId[row.id] = row
    P.byMethod[row.method] = row
    P.byCharacter[row.character][#P.byCharacter[row.character] + 1] = row
    P.audit.registeredPackages = P.audit.registeredPackages + 1
    if row.item then P.byItem[row.item] = row end
    for _, target in ipairs(row.targets) do
      assert(not P.byTarget[target.target], "duplicate HEVO target " .. target.target)
      P.byTarget[target.target] = { package = row, parent = target.parent,
        target = target.target }
      P.audit.registeredTargets = P.audit.registeredTargets + 1
    end
  end
  P.packages = P.order

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function bucket(save, create)
    if type(save) ~= "table" then return nil end
    if type(save.modData) ~= "table" then
      if not create then return nil end
      save.modData = {}
    end
    local id = opts.modId or mod.id or "kanto_ascendant"
    local b = save.modData[id]
    if type(b) ~= "table" then
      if not create then return nil end
      b = {}; save.modData[id] = b
    end
    return b
  end

  local SET_FIELDS = {
    "meta", "packageUnlocks", "evolutionUnlocks", "permanentItems",
    "firstGrants", "questionIds", "dex", "secretUnlocks",
  }

  local function normalizePersistent(p)
    p.version = P.VERSION
    for _, key in ipairs(SET_FIELDS) do
      p[key] = type(p[key]) == "table" and p[key] or {}
    end
    p.pendingItems = type(p.pendingItems) == "table" and p.pendingItems or {}
    for item, count in pairs(p.pendingItems) do
      count = math.max(0, math.floor(tonumber(count) or 0))
      p.pendingItems[item] = count > 0 and count or nil
    end

    -- One-time compatibility migration from the discarded 17-relic shape.
    -- A dual-target package migrates only when both targets were unlocked,
    -- preventing one old species flag from leaking its paired evolution.
    for _, package in ipairs(P.order) do
      if p.packageUnlocks[package.id] ~= true then
        local complete = true
        for _, target in ipairs(package.targets) do
          if p.evolutionUnlocks[target.target] ~= true then complete = false break end
        end
        if complete then p.packageUnlocks[package.id] = true end
      end
    end
    -- Package ids are authoritative; species/item views never unlock a
    -- package in the other direction after the migration above.
    for _, package in ipairs(P.order) do
      if p.packageUnlocks[package.id] == true then
        for _, target in ipairs(package.targets) do
          p.evolutionUnlocks[target.target] = true
        end
        if package.item then p.permanentItems[package.item] = true end
      end
    end
    return p
  end

  function P.persistent(save, create)
    local b = bucket(save, create)
    if not b then return nil end
    local p = b.hevo_persistent
    if type(p) ~= "table" then
      if not create then return nil end
      p = {}; b.hevo_persistent = p
    end
    return normalizePersistent(p)
  end

  function P.reconcile(save)
    local p = P.persistent(save, true)
    save.flags = type(save.flags) == "table" and save.flags or {}
    for _, package in ipairs(P.order) do
      if p.packageUnlocks[package.id] == true then
        save.flags[package.unlockKey] = true
      end
    end
    return p
  end

  function P.unlocked(save, id)
    local p = P.persistent(save, false)
    return p ~= nil and p.packageUnlocks[id] == true
  end

  local function targetForMon(package, mon)
    local species = type(mon) == "table" and mon.species or nil
    for _, target in ipairs(package and package.targets or {}) do
      if target.parent == species then return target end
    end
    return nil
  end

  local function knows(mon, moveId)
    for _, move in ipairs(type(mon) == "table" and mon.moves or {}) do
      if move.id == moveId then return true end
    end
    return false
  end

  -- Shared decision surface used by Bag, Route 5, Day-Care and field altars.
  -- Returns true,target,package or false,reason,package.
  function P.eligibility(save, mon, packageId, surface, context)
    local package = type(packageId) == "table" and packageId
      or P.byId[packageId]
    if not package then return false, "package" end
    if not beyondActive(save) then
      return false, "beyond-kanto-sealed", package
    end
    if not P.unlocked(save, package.id) then return false, "locked", package end
    if type(mon) ~= "table" or mon.isEgg then return false, "pokemon", package end
    local target = targetForMon(package, mon)
    if not target then return false, "species", package end
    surface = tostring(surface or "")
    context = type(context) == "table" and context or {}
    if surface == "item" or surface == "bag" or surface == "daycare" then
      if package.kind ~= "item" then return false, "method", package end
      if context.item and context.item ~= package.item then
        return false, "item", package
      end
    elseif surface == "route5" then
      if package.kind ~= "knowledge" then return false, "method", package end
      if not (context.data and context.data.moves
          and context.data.moves[package.move]) then
        P.audit.missingMoves[package.move] = true
        return false, "move-missing", package
      end
    elseif surface == "levelup" then
      if package.kind ~= "knowledge" then return false, "method", package end
      if not (context.data and context.data.moves
          and context.data.moves[package.move]) then
        P.audit.missingMoves[package.move] = true
        return false, "move-missing", package
      end
      if not knows(mon, package.move) then return false, "knowledge", package end
    elseif surface == "field" then
      if package.kind ~= "field" then return false, "method", package end
      local field = context.field or context.package
      if field and field ~= package.field and field ~= package.id then
        return false, "field", package
      end
    else
      return false, "surface", package
    end
    return true, target, package
  end

  function P.packageForEvolution(evolution)
    return evolution and P.byMethod[evolution.method] or nil
  end

  function P.evolutionRows()
    local rows = {}
    for _, package in ipairs(P.order) do
      for _, target in ipairs(package.targets) do
        rows[#rows + 1] = {
          package = package, parent = target.parent, target = target.target,
          method = package.method, item = package.item,
        }
      end
    end
    return rows
  end

  local function registerContent()
    if not P.enabled then return end
    mod.content.item_effects:register(P.ITEM_EFFECT, {
      field = true, battle = false, needsTarget = true,
      -- Stock 0.1.86 dispatches one context table. Newer engines may honor
      -- callStyle and dispatch the historical positional arguments instead.
      -- Accept both ABIs without changing the authoritative package logic.
      callStyle = "legacyArgs",
      use = function(data, save, itemId, target, battle)
        if save == nil and itemId == nil and type(data) == "table"
            and data.data ~= nil and data.itemId ~= nil then
          local context = data
          data, save, itemId, target, battle = context.data, context.save,
            context.itemId, context.target, context.battle
        end
        return P.useItemEffect(data, save, itemId, target, battle)
      end,
    })
    for _, package in ipairs(P.order) do
      if package.item then
        mod.content.items:register(package.item, {
          id = package.item,
          name = tr(package.itemName.en, package.itemName.de),
          price = 0, tossable = false, needsTarget = true,
          effect = P.ITEM_EFFECT,
          lootExcluded = true, progressionItem = true,
        })
      end
      mod.content.evolution_methods:register(package.method, {
        check = function(game, mon, _, trigger)
          trigger = type(trigger) == "table" and trigger or {}
          local surface = package.kind == "knowledge" and "levelup"
            or package.kind == "field" and "field" or "item"
          if package.kind == "knowledge" and trigger.kind ~= "levelup" then
            return false
          elseif package.kind == "field"
              and trigger.kind ~= "hevo_field" then
            return false
          elseif package.kind == "item"
              and (trigger.kind ~= "item" or trigger.item ~= package.item) then
            return false
          end
          return P.eligibility(game.save, mon, package, surface, {
            item = trigger.item, field = trigger.field or trigger.package,
            data = game.data,
          }) == true
        end,
        describe = function()
          if package.kind == "item" then
            return tr(package.itemName.en, package.itemName.de)
          elseif package.kind == "field" then
            return tr("Unlocked field altar", "Freigeschalteter Feldaltar")
          end
          return tr("Know " .. package.move, "Kennt " .. package.move)
        end,
      })
    end
  end

  function P.useItemEffect(data, save, itemId, target, battle)
    local package = P.byItem[itemId]
    if not package then return "failed", { tr("It won't have\nany effect.",
      "Es hat keine\nWirkung.") } end
    if battle then
      return "failed", { tr("This item only works\noutside battle.",
        "Dieses Item wirkt nur\naußerhalb des Kampfes.") }
    end
    local ok, targetRow = P.eligibility(save, target, package, "bag", {
      item = itemId, data = data,
    })
    if not ok then
      return "failed", { tr("It won't have\nany effect.",
        "Es hat keine\nWirkung.") }, { reason = targetRow }
    end
    return "consumed", nil, {
      evolveTo = targetRow.target, evolveVia = "ITEM",
      hevoPackage = package.id,
    }
  end

  local function stageSnapshot(save)
    local b = bucket(save, true)
    return {
      save = save, bucket = b, persistent = copy(b.hevo_persistent),
      inventory = copy(save.inventory), bagOrder = copy(save.bagOrder),
      flags = copy(save.flags), money = save.money,
    }
  end

  function P.restore(transaction)
    if type(transaction) ~= "table" or type(transaction.save) ~= "table" then
      return false
    end
    local save = transaction.save
    transaction.bucket.hevo_persistent = copy(transaction.persistent)
    save.inventory = copy(transaction.inventory) or {}
    save.bagOrder = copy(transaction.bagOrder)
    save.flags = copy(transaction.flags)
    save.money = transaction.money
    return true
  end

  local function grantFirst(save, p, package)
    if package.kind ~= "item" or p.firstGrants[package.id] == true then
      return false
    end
    p.firstGrants[package.id] = true
    if Bag.add(save, package.item, 1, P.activeGame and P.activeGame.data) then
      return true
    end
    p.pendingItems[package.item] = (p.pendingItems[package.item] or 0) + 1
    return false
  end

  local function validatePackageList(character, packageIds)
    local out, seen = {}, {}
    for _, id in ipairs(packageIds or {}) do
      local package = P.byId[id]
      if not package then return nil, "package" end
      if not package.characterWhitelist[character] then return nil, "character" end
      if seen[id] then return nil, "duplicate" end
      seen[id] = true; out[#out + 1] = package
    end
    return out
  end

  function P.stageCharacter(save, character)
    if not beyondActive(save) then return nil, "beyond-kanto-sealed" end
    character = tostring(character or ""):upper()
    if not P.byCharacter[character] then return nil, "character" end
    local active = opts.journey and opts.journey.activeCharacter
      and opts.journey.activeCharacter(save) or character
    if active and tostring(active):upper() ~= character then
      return nil, "character"
    end
    local packageIds = {}
    for _, package in ipairs(P.byCharacter[character]) do
      packageIds[#packageIds + 1] = package.id
    end
    return P.stageRecovery(save, character, packageIds, true)
  end

  -- Explicit migration/test recovery seam. Production dungeon results never
  -- accept a caller-provided subset; only this named API does.
  function P.stageRecovery(save, character, packageIds, productionAll)
    if not beyondActive(save) then return nil, "beyond-kanto-sealed" end
    character = tostring(character or ""):upper()
    local packages, err = validatePackageList(character, packageIds)
    if not packages then return nil, err end
    if productionAll and #packages ~= 5 then return nil, "package-count" end
    local transaction = stageSnapshot(save)
    local p = P.reconcile(save)
    for _, package in ipairs(packages) do
      p.packageUnlocks[package.id] = true
      save.flags[package.unlockKey] = true
      for _, target in ipairs(package.targets) do
        p.evolutionUnlocks[target.target] = true
      end
      if package.item then p.permanentItems[package.item] = true end
      grantFirst(save, p, package)
    end
    normalizePersistent(p)
    transaction.packages = packages
    return transaction
  end

  local function syncArchive(save)
    local sync = opts.journey and opts.journey.syncHevoPersistent
    if type(sync) ~= "function" then return true end
    return sync(save)
  end

  function P.commit(game, transaction)
    if not (game and game.save == transaction.save) then
      P.restore(transaction); return false, "game"
    end
    if game.writeSave and game:writeSave() == false then
      P.restore(transaction)
      return false, "save"
    end
    local ok, err = syncArchive(game.save)
    if ok == false then
      P.restore(transaction)
      if game.writeSave then game:writeSave() end
      return false, err or "archive"
    end
    return true
  end

  function P.claimPending(game)
    local save = game and game.save
    if not save then return false, "game" end
    if not beyondActive(save) then return false, "beyond-kanto-sealed" end
    local p = P.persistent(save, false)
    if not p or next(p.pendingItems) == nil then return false, "empty" end
    local transaction = stageSnapshot(save)
    local claimed = {}
    for _, package in ipairs(P.order) do
      local item = package.item
      while item and (p.pendingItems[item] or 0) > 0 do
        if not Bag.add(save, item, 1, game.data) then break end
        p.pendingItems[item] = p.pendingItems[item] - 1
        if p.pendingItems[item] <= 0 then p.pendingItems[item] = nil end
        claimed[#claimed + 1] = item
      end
    end
    if #claimed == 0 then P.restore(transaction); return false, "bag-full" end
    local ok, err = P.commit(game, transaction)
    if not ok then return false, err end
    return true, claimed
  end

  function P.purchase(game, packageId, confirmed)
    if confirmed ~= true then return false, "cancelled" end
    if not beyondActive(game and game.save) then
      return false, "beyond-kanto-sealed"
    end
    local package = P.byId[packageId]
    if not package or package.kind ~= "item" then return false, "package" end
    if not P.unlocked(game and game.save, package.id) then return false, "locked" end
    local save = game.save
    if (tonumber(save.money) or 0) < package.reacquirePrice then
      return false, "money"
    end
    local transaction = stageSnapshot(save)
    if not Bag.add(save, package.item, 1, game.data) then
      P.restore(transaction); return false, "bag-full"
    end
    save.money = save.money - package.reacquirePrice
    if game.writeSave and game:writeSave() == false then
      P.restore(transaction); return false, "save"
    end
    return true, package.item
  end

  function P.reminderRows(game, mon)
    local rows = {}
    for _, package in ipairs(P.order) do
      if package.kind == "knowledge" then
        local ok = P.eligibility(game.save, mon, package, "route5", {
          data = game.data,
        })
        if ok then rows[#rows + 1] = { id = package.move, source = "HEVO" } end
      end
    end
    return rows
  end

  function P.attachFieldTech(fieldTech)
    if P._fieldTechAttached then return false, "attached" end
    if not (fieldTech and fieldTech.registerReminderProvider) then
      return false, "provider"
    end
    local ok, err = fieldTech.registerReminderProvider("hevo_packages",
      function(game, mon) return P.reminderRows(game, mon) end)
    if not ok then return false, err end
    P._fieldTechAttached = true
    return true
  end

  function P.daycareChoices(game)
    local rows = {}
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      if not mon.isEgg then
        for _, package in ipairs(P.order) do
          if package.kind == "item"
              and game.save.inventory and game.save.inventory[package.item] then
            local ok, target = P.eligibility(game.save, mon, package,
              "daycare", { item = package.item, data = game.data })
            if ok then rows[#rows + 1] = {
              mon = mon, package = package, target = target.target,
              item = package.item,
            } end
          end
        end
      end
    end
    return rows
  end

  function P.evolveAtDaycare(game, row, done, deps)
    deps = deps or {}
    local ok, target = P.eligibility(game.save, row and row.mon,
      row and row.package, "daycare", { item = row and row.item, data = game.data })
    if not ok or not game.save.inventory[row.item] then return false, target end
    local evolve = deps.evolve or function(g, mon, species, callback)
      require("src.pokemon.Evolution").evolve(g, mon, species, callback, "ITEM")
      return true
    end
    local called, result = pcall(evolve, game, row.mon, target.target, done)
    if not called or result == false then return false, called and "evolve" or result end
    Bag.remove(game.save, row.item, 1)
    return true, target.target
  end

  function P.useFieldAltar(game, packageId, mon, done, deps)
    local package = P.byId[packageId]
    if not package or package.kind ~= "field" then return false, "package" end
    local function evolve(selected)
      local ok, target = P.eligibility(game.save, selected, package, "field", {
        field = package.field, data = game.data,
      })
      if not ok then return false, target end
      local request = deps and deps.request or function(g, pokemon, trigger, callback)
        return require("src.pokemon.Evolution").request(g, pokemon, trigger, callback)
      end
      local called, evolved = pcall(request, game, selected, {
        kind = "hevo_field", field = package.field, package = package.id,
      }, done)
      if not called then return false, evolved, false end
      -- Evolution.request calls done itself when there is no matching branch.
      return evolved ~= nil and evolved ~= false, evolved or "evolve", true
    end
    if mon then return evolve(mon) end
    require("src.ui.Screens").push(game, "PartyMenu", {
      pickOnly = true, onCancel = done,
      onSwitch = function(selected)
        local ok, _, doneHandled = evolve(selected)
        if not ok and not doneHandled and done then done() end
      end,
    })
    return true
  end

  function P.registerFieldAltar(mapId, textId, packageId, object)
    local package = assert(P.byId[packageId], "unknown HEVO package " .. tostring(packageId))
    assert(package.kind == "field", "HEVO altar requires field package")
    if object then
      local map = assert(mod.content.maps:get(mapId),
        "HEVO altar map unavailable: " .. tostring(mapId))
      local objects = copy(map.objects or {})
      local index = object.index or (#objects + 1)
      objects[#objects + 1] = {
        index = index, name = object.name or ("KA_HEVO_ALTAR_" .. package.id:upper()),
        -- Field evolutions are reusable interaction points, but they are not
        -- part of the five-statue visibility quiz.  Reusing the golden relic
        -- silhouette made BLUE appear to have seven quiz stones and GREEN
        -- six.  Keep them as clearly separate item markers; the five actual
        -- question statues remain the only Evolution Relics in each path.
        sprite = object.sprite or "SPRITE_POKE_BALL",
        x = assert(object.x), y = assert(object.y), movement = "STAY",
        range = "NONE", text = textId,
      }
      mod.content.maps:patch(mapId, { objects = objects })
      mod.content.text:register(textId, tr(
        "The unlocked field resonates.\nChoose a POKéMON.",
        "Das Feld resoniert.\nWähle ein POKéMON."))
      mod.content.text_pointers:patch("???", { [textId] = { text = textId } })
    end
    mod.content.map_scripts:register(mapId, {
      priority = 2840,
      talk = {
        [textId] = function(game, _, _, done)
          return P.useFieldAltar(game, package.id, nil, done)
        end,
      },
    })
    return true
  end

  function P.install(game)
    P.activeGame = game
    if game and game.save then P.reconcile(game.save) end
    P.audit.missingMoves = {}
    for _, package in ipairs(P.order) do
      if package.move and not (game and game.data and game.data.moves
          and game.data.moves[package.move]) then
        P.audit.missingMoves[package.move] = true
      end
    end
    return true
  end

  P.beyondActive = beyondActive

  if P.enabled then registerContent() end
  if mod.exports then mod.exports.hevoPackages = P end
  return P
end
