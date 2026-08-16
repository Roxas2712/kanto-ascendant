-- NG+ Legacy Workshop.  The stable interior is reached from the Legacy
-- Gallery curator on Celadon Mansion 3F and returns to that same floor.  Its
-- Kanto-native Facility composition deliberately keeps map art, progression
-- state, Ledger UI and repeatable purchases in one auditable package.
return function(mod, opts)
  opts = opts or {}
  local packages = assert(opts.packages, "legacy workshop requires HEVO packages")
  local Bag = opts.bag or require("src.inventory.Bag")
  local W = { registered = false }
  W.ID = "KA_NGPLUS_LEGACY_WORKSHOP"
  -- 1960--1966 belong to the three Johto Master passages.  Keep the
  -- permanent workshop on its own stable registry index.
  W.INDEX = 1970
  W.STATE = "ngplus_legacy_workshop"
  W.STATE_VERSION = 3
  W.BALL_PRICE = 1000
  W.NO_RUNTIME_BALL_PURCHASE = false
  W.MAP_WIDTH, W.MAP_HEIGHT = 8, 9
  W.ENTER = { x = 13, y = 14, facing = "DOWN" }
  -- Block 36 at (8,0) is the native Facility stair used by Silph 10F.
  -- Keeping the warp on an actual warp tile makes the return work through
  -- ordinary input; the old (13,15) point was plain floor after the decorative
  -- teleporter tile there was intentionally removed.
  W.EXIT = { x = 8, y = 0 }
  W.ANCHOR = {
    status = "CONNECTED",
    auditedGalleryMapId = "CELADON_MANSION_3F",
    curatorMap = "CELADON_MANSION_3F",
    curatorObject = "KANTO_ASCENDANT_LEGACY_CURATOR",
    enter = { map = W.ID, x = W.ENTER.x, y = W.ENTER.y,
      facing = W.ENTER.facing },
    returnTo = { destMap = "CELADON_MANSION_3F", destWarp = 1 },
  }
  W.RESONANCE = {
    RED = { requires = "red", threshold = "KA_HEVO_RED_UPPER" },
    BLUE = { requires = "blue", threshold = "KA_HEVO_BLUE_FROST_THRESHOLD" },
    GREEN = { requires = "green", threshold = "KA_HEVO_GREEN_THRESHOLD" },
  }

  -- One authority for the three seals, their five HEVO packages, repeatable
  -- Apricorn plans and the two deliberately hidden reward traces.  The HEVO
  -- package rows themselves are never copied: they remain owned by
  -- hevo_packages.lua and are referenced through `packages.byCharacter`.
  local planSource = {
    {
      character = "RED", seal = "red", symbol = "R",
      label = { en = "RED LEGACY PLAN", de = "ROTER VERMÄCHTNISPLAN" },
      balls = { "HEAVY_BALL", "LEVEL_BALL" },
      starter = { id = "starter_lineage_red", item = "LEGACY_STARTER_TORCHIC",
        label = { en = "TORCHIC LINEAGE", de = "FLEMMLI-LINIE" } },
      mega = { id = "mega_resonance_red", item = "BLAZIKENITE",
        label = { en = "BLAZIKENITE RESONANCE", de = "LOHGOCKNIT-RESONANZ" } },
    },
    {
      character = "BLUE", seal = "blue", symbol = "B",
      label = { en = "BLUE LEGACY PLAN", de = "BLAUER VERMÄCHTNISPLAN" },
      balls = { "LURE_BALL", "FAST_BALL" },
      starter = { id = "starter_lineage_blue", item = "LEGACY_STARTER_MUDKIP",
        label = { en = "MUDKIP LINEAGE", de = "HYDROPI-LINIE" } },
      mega = { id = "mega_resonance_blue", item = "SWAMPERTITE",
        label = { en = "SWAMPERTITE RESONANCE", de = "SUMPEXIT-RESONANZ" } },
    },
    {
      character = "GREEN", seal = "green", symbol = "G",
      label = { en = "GREEN LEGACY PLAN", de = "GRÜNER VERMÄCHTNISPLAN" },
      balls = { "FRIEND_BALL", "LOVE_BALL", "MOON_BALL" },
      starter = { id = "starter_lineage_green", item = "LEGACY_STARTER_TREECKO",
        label = { en = "TREECKO LINEAGE", de = "GECKARBOR-LINIE" } },
      mega = { id = "mega_resonance_green", item = "SCEPTILITE",
        label = { en = "SCEPTILITE RESONANCE", de = "GEWALDRONIT-RESONANZ" } },
    },
  }
  W.PLAN_ORDER, W.PLANS, W.BALL_INDEX = {}, {}, {}
  for _, source in ipairs(planSource) do
    local plan = {
      character = source.character, seal = source.seal, symbol = source.symbol,
      label = source.label, balls = source.balls,
      starter = source.starter, mega = source.mega,
      packages = assert(packages.byCharacter[source.character],
        "missing HEVO packages for " .. source.character),
    }
    assert(#plan.packages == 5,
      "legacy workshop requires five HEVO packages for " .. source.character)
    W.PLAN_ORDER[#W.PLAN_ORDER + 1] = plan
    W.PLANS[plan.character] = plan
    W.PLANS[plan.seal] = plan
    for _, item in ipairs(plan.balls) do
      assert(item ~= "GS_BALL", "GS Ball must not enter a Legacy plan")
      assert(not W.BALL_INDEX[item], "duplicate Legacy ball plan " .. item)
      W.BALL_INDEX[item] = plan
    end
  end

  -- Aggregate secret headings only; seal/package/ball rows come exclusively
  -- from W.PLAN_ORDER above.
  W.LEDGER = {
    starter = { id = "STARTER_LINEAGE", symbol = "*", label = { en = "STARTER LINEAGE", de = "STARTER-ERBE" },
      spoiler = { en = "A familiar lineage has left a trace.", de = "Eine vertraute Linie hat eine Spur hinterlassen." } },
    mega = { id = "MEGA_RESONANCE", symbol = "*", label = { en = "MEGA RESONANCE", de = "MEGA-RESONANZ" },
      spoiler = { en = "A deeper resonance is recorded.", de = "Eine tiefere Resonanz ist verzeichnet." } },
  }
  W.LANDMARKS = {
    ARCHIVE_PLINTH = { en = "ARCHIVE PLINTH: Three marks face one ledger.", de = "ARCHIVSOCKEL: Drei Zeichen weisen auf ein Ledger." },
    TRIUNE_DIAL = { en = "TRIUNE DIAL: Triangle, circle, diamond. Trace all three.", de = "DREIKLANG-DREHSCHEIBE: Dreieck, Kreis, Raute. Folge allen dreien." },
    LEDGER_DESK = { en = "LEDGER DESK: Seals reveal plans; discoveries reveal names.", de = "LEDGERPULT: Siegel zeigen Pläne; Entdeckungen zeigen Namen." },
  }

  local function tr(en, de) return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en end
  local function profile(source)
    -- Tests/tools may pass an archive profile directly. A live game save is
    -- also a table, but its completed paths live in the separate archive;
    -- treating it as a profile would make every in-game seal look locked.
    if type(source) == "table"
        and (type(source.completedPaths) == "table"
          or type(source.discoveries) == "table"
          or type(source.hevoPersistent) == "table"
          or type(source.workshopPersistent) == "table") then
      return source
    end
    if type(opts.legacyProfile) == "function" then return opts.legacyProfile() or {} end
    return {}
  end
  local function saved(create)
    local s = mod.save and mod.save:get(W.STATE)
    if type(s) ~= "table" and create ~= false then
      s = { version = W.STATE_VERSION, seals = {}, discoveries = {},
        landmarks = {} }
      if mod.save and mod.save.set then mod.save:set(W.STATE, s) end
    end
    if type(s) == "table" then
      local version = math.max(1, math.floor(tonumber(s.version) or 1))
      s.version = W.STATE_VERSION
      s.seals = type(s.seals) == "table" and s.seals or {}
      s.discoveries = type(s.discoveries) == "table" and s.discoveries or {}
      s.landmarks = type(s.landmarks) == "table" and s.landmarks or {}
      local token = s.resonanceReturn
      local target = type(token) == "table" and W.RESONANCE[token.character]
      if not (target and token.version == 1 and token.sourceMap == W.ID
          and token.threshold == target.threshold) then
        s.resonanceReturn = nil
      end
      -- v1 had only aggregate secret switches. Keep them as migration hints;
      -- W.sync expands them only for seals that were actually earned, so a
      -- legacy boolean can never disclose a character's locked secret.
      if version < W.STATE_VERSION and mod.save and mod.save.set then
        mod.save:set(W.STATE, s)
      end
    end
    return s
  end

  local function hevoPersistent(source, p)
    if type(source) == "table" and type(packages.persistent) == "function" then
      local direct = packages.persistent(source, false)
      if type(direct) == "table" then return direct end
    end
    return type(p and p.hevoPersistent) == "table" and p.hevoPersistent or {}
  end

  local function secretFound(plan, kind, s, persistent)
    local secret = plan[kind]
    if s.seals[plan.seal] ~= true then return false end
    if s.discoveries[secret.id] == true then return true end
    if kind == "mega" then
      return type(persistent.secretUnlocks) == "table"
        and persistent.secretUnlocks[plan.character] == true
    end
    return type(persistent.permanentItems) == "table"
      and persistent.permanentItems[secret.item] == true
  end

  function W.sync(source)
    local p, s, changed = profile(source), saved(true), false
    local completed = type(p.completedPaths) == "table" and p.completedPaths or {}
    local completedIsAuthority = type(p.completedPaths) == "table"
    local discoveries = type(p.discoveries) == "table" and p.discoveries or {}
    local persistedWorkshop = type(p.workshopPersistent) == "table"
      and p.workshopPersistent or {}
    for _, plan in ipairs(W.PLAN_ORDER) do
      local unlocked = completed[plan.seal] == true
      if completedIsAuthority and (s.seals[plan.seal] == true) ~= unlocked then
        s.seals[plan.seal], changed = unlocked or nil, true
      elseif not completedIsAuthority and unlocked and not s.seals[plan.seal] then
        s.seals[plan.seal], changed = true, true
      end
    end
    for key, found in pairs(discoveries) do
      if found == true and not s.discoveries[key] then
        s.discoveries[key], changed = true, true
      end
    end
    for key, found in pairs(type(persistedWorkshop.discoveries) == "table"
        and persistedWorkshop.discoveries or {}) do
      if found == true and not s.discoveries[key] then
        s.discoveries[key], changed = true, true
      end
    end
    for key, found in pairs(type(persistedWorkshop.landmarks) == "table"
        and persistedWorkshop.landmarks or {}) do
      if found == true and not s.landmarks[key] then
        s.landmarks[key], changed = true, true
      end
    end
    local persistent = hevoPersistent(source, p)
    for _, plan in ipairs(W.PLAN_ORDER) do
      for _, kind in ipairs({ "starter", "mega" }) do
        local secret = plan[kind]
        local aggregate = kind == "starter" and "starter_lineage"
          or "mega_resonance"
        local found = s.seals[plan.seal] and (
          s.discoveries[aggregate] == true
          or type(persistent.permanentItems) == "table"
            and persistent.permanentItems[secret.item] == true)
        if found and not s.discoveries[secret.id] then
          s.discoveries[secret.id], changed = true, true
        end
      end
    end
    if changed and mod.save and mod.save.set then mod.save:set(W.STATE, s) end
    return s, changed
  end

  function W.state(source)
    local s = W.sync(source)
    return s
  end

  function W.discover(id)
    local s = saved(true)
    if not W.LANDMARKS[id] then return false, "unknown landmark" end
    if s.landmarks[id] then return false, "already discovered" end
    s.landmarks[id] = true
    if mod.save and mod.save.set then mod.save:set(W.STATE, s) end
    return true
  end

  function W.sealCount(source)
    local s = W.sync(source); local n = 0
    for _, key in ipairs({ "red", "blue", "green" }) do if s.seals[key] then n = n + 1 end end
    return n
  end
  function W.complete(source) return W.sealCount(source) == 3 end

  function W.ledger(source)
    local p, s, rows = profile(source), W.sync(source), {}
    local persistent = hevoPersistent(source, p)
    local discoveryByKind = { starter = {}, mega = {} }
    for _, plan in ipairs(W.PLAN_ORDER) do
      local open = s.seals[plan.seal] == true
      local targets, packageRows, ballRows, secrets = {}, {}, {}, {}
      if open then
        for _, package in ipairs(plan.packages) do
          local packageTargets = {}
          for _, target in ipairs(package.targets) do
            targets[#targets + 1] = target.target
            packageTargets[#packageTargets + 1] = target.target
          end
          packageRows[#packageRows + 1] = {
            id = package.id, kind = package.kind, targets = packageTargets,
          }
        end
        for _, item in ipairs(plan.balls) do
          ballRows[#ballRows + 1] = {
            item = item, price = W.BALL_PRICE, reusable = true,
          }
        end
      end
      local openDiscoveries = 0
      for _, kind in ipairs({ "starter", "mega" }) do
        local secret = plan[kind]
        local found = open and secretFound(plan, kind, s, persistent)
        local display = {
          id = secret.id, kind = kind, character = plan.character,
          available = open, visible = found,
          label = found and tr(secret.label.en, secret.label.de) or "???",
        }
        discoveryByKind[kind][#discoveryByKind[kind] + 1] = display
        if open then
          secrets[#secrets + 1] = display
          if not found then openDiscoveries = openDiscoveries + 1 end
        end
      end
      rows[#rows + 1] = {
        id = plan.character .. "_SEAL", visible = open,
        character = plan.character, seal = plan.seal, symbol = plan.symbol,
        label = open and tr(plan.label.en, plan.label.de) or "???",
        evolution = open and targets or nil,
        packages = open and packageRows or nil,
        balls = open and ballRows or nil,
        secrets = open and secrets or nil,
        openDiscoveries = open and openDiscoveries or nil,
      }
    end
    for _, kind in ipairs({ "starter", "mega" }) do
      local meta = W.LEDGER[kind]
      local visible = false
      for _, secret in ipairs(discoveryByKind[kind]) do
        visible = visible or secret.visible
      end
      rows[#rows + 1] = {
        id = meta.id, visible = visible, symbol = meta.symbol,
        label = visible and tr(meta.label.en, meta.label.de) or "???",
        spoiler = visible and tr(meta.spoiler.en, meta.spoiler.de) or nil,
        discoveries = discoveryByKind[kind],
      }
    end
    return rows
  end

  function W.discoveryLedger(source)
    local rows, out = W.ledger(source), {}
    for index = 4, 5 do
      for _, secret in ipairs(rows[index].discoveries or {}) do
        out[#out + 1] = secret
      end
    end
    return out
  end

  function W.openDiscoveries(source)
    local count = 0
    for _, row in ipairs(W.discoveryLedger(source)) do
      if row.available and not row.visible then count = count + 1 end
    end
    return count
  end

  function W.ledgerText(source)
    local lines = {}
    for index, row in ipairs(W.ledger(source)) do
      if index > 3 then break end
      if not row.visible then
        lines[#lines + 1] = row.symbol .. " ???"
      else
        lines[#lines + 1] = row.symbol .. " " .. row.label
        lines[#lines + 1] = tr(
          ("HEVO %d / BALL PLANS %d / OPEN %d"):format(
            #row.packages, #row.balls, row.openDiscoveries),
          ("HEVO %d / BALLPLÄNE %d / OFFEN %d"):format(
            #row.packages, #row.balls, row.openDiscoveries))
        for _, secret in ipairs(row.secrets) do
          if secret.visible then lines[#lines + 1] = secret.label end
        end
      end
    end
    return table.concat(lines, "\n")
  end

  function W.planText(row)
    if type(row) ~= "table" or not row.visible then return "???" end
    local lines = { row.symbol .. " " .. row.label }
    for _, package in ipairs(row.packages or {}) do
      lines[#lines + 1] = "HEVO: " .. table.concat(package.targets, "/")
    end
    for _, ball in ipairs(row.balls or {}) do
      lines[#lines + 1] = tr("BALL PLAN: ", "BALLPLAN: ")
        .. ball.item:gsub("_", " ")
    end
    for _, secret in ipairs(row.secrets or {}) do
      lines[#lines + 1] = tr("TRACE: ", "SPUR: ") .. secret.label
    end
    return table.concat(lines, "\n")
  end

  function W.sealDisplay(source)
    local rows, out = W.ledger(source), {}
    for i = 1, 3 do
      local row = rows[i]
      out[#out + 1] = { id = row.id, symbol = row.symbol, text = row.label,
        form = row.id:match("^(%u+)_SEAL$") or "???", unlocked = row.visible }
    end
    return out
  end

  function W.offers(source)
    local offers = {}
    for _, package in ipairs(packages.order) do
      if package.kind == "item" and packages.unlocked(source, package.id) then
        offers[#offers + 1] = {
          kind = "evolution",
          packageId = package.id, item = package.item,
          price = package.reacquirePrice, reusable = true,
          source = package.repeatableSource, runtimePurchase = true,
        }
      end
    end
    return offers
  end

  function W.ballOffers(source)
    local s, offers = W.sync(source), {}
    for _, plan in ipairs(W.PLAN_ORDER) do
      if s.seals[plan.seal] then
        for _, item in ipairs(plan.balls) do
          offers[#offers + 1] = {
            kind = "ball", character = plan.character, seal = plan.seal,
            item = item, price = W.BALL_PRICE, reusable = true,
            source = "legacy_workshop", runtimePurchase = true,
          }
        end
      end
    end
    return offers
  end

  function W.shopOffers(source)
    local rows = W.offers(source)
    for _, offer in ipairs(W.ballOffers(source)) do rows[#rows + 1] = offer end
    return rows
  end

  function W.purchase(game, packageId, confirmed)
    return packages.purchase(game, packageId, confirmed)
  end

  function W.purchaseBall(game, item, confirmed)
    if item == "GS_BALL" then return false, "gs-ball-excluded" end
    if confirmed ~= true then return false, "cancelled" end
    local plan = W.BALL_INDEX[item]
    if not plan then return false, "ball-plan" end
    if not (game and game.save and game.data) then return false, "game" end
    local s = W.sync(game.save)
    if not s.seals[plan.seal] then return false, "locked" end
    local def = game.data.items and game.data.items[item]
    if not def or def.ball ~= item then return false, "item" end
    local save = game.save
    if (tonumber(save.money) or 0) < W.BALL_PRICE then
      return false, "money"
    end
    local money, inventory, order = save.money, {}, {}
    local hadOrder = type(save.bagOrder) == "table"
    for id, count in pairs(save.inventory or {}) do inventory[id] = count end
    for index, id in ipairs(save.bagOrder or {}) do order[index] = id end
    if not Bag.add(save, item, 1, game.data) then return false, "bag-full" end
    -- Bag.order also canonicalizes acquisition lists from older/direct-write
    -- saves before the transaction becomes durable.
    Bag.order(save)
    save.money = save.money - W.BALL_PRICE
    if game.writeSave and game:writeSave() == false then
      save.inventory = inventory
      save.bagOrder = hadOrder and order or nil
      save.money = money
      return false, "save"
    end
    return true, item
  end

  function W.purchaseOffer(game, offer, confirmed)
    if type(offer) ~= "table" then return false, "offer" end
    if offer.kind == "ball" then
      return W.purchaseBall(game, offer.item, confirmed)
    end
    if offer.kind == "evolution" then
      return W.purchase(game, offer.packageId, confirmed)
    end
    return false, "offer"
  end

  function W.claimPending(game)
    return packages.claimPending(game)
  end

  local function solvedThreshold(progress, threshold)
    local solved = type(progress) == "table" and progress.solvedThresholds
    if type(solved) ~= "table" then solved = progress end
    return type(solved) == "table" and solved[threshold] == true
  end

  -- Read the real puzzle state from the registered campaign modules.  A seal
  -- on its own never enables a shortcut: missing packages and incomplete
  -- puzzles fail closed.
  local function campaignProgress(game, key)
    local progress = { solvedThresholds = {} }
    local campaign = mod.exports and mod.exports.hiddenEvolutionCampaign
    local ok, modules = pcall(function()
      return campaign and (campaign.modules or campaign.load())
    end)
    if not ok or type(modules) ~= "table" or not (game and game.save) then
      return progress
    end
    local path, solved = modules[key], false
    if key == "RED" and path and type(path.canEnterShrine) == "function" then
      local passed, value = pcall(path.canEnterShrine, game.save)
      solved = passed and value == true
    elseif key == "BLUE" and path and type(path.shrineOpen) == "function" then
      local passed, value = pcall(path.shrineOpen)
      solved = passed and value == true
    elseif key == "GREEN" and path and type(path.visibility) == "function" then
      local passed, value = pcall(path.visibility, game.save)
      solved = passed and tonumber(value) and tonumber(value) >= 16 or false
    end
    local target = W.RESONANCE[key]
    if target then progress.solvedThresholds[target.threshold] = solved end
    return progress
  end

  function W.resonanceProgress(game, key)
    if type(opts.resonanceProgress) == "function" then
      return opts.resonanceProgress(game, key) or {}
    end
    return campaignProgress(game, key)
  end

  local function activeCharacter(game)
    if type(opts.activeCharacter) == "function" then
      local value = opts.activeCharacter(game)
      if value ~= nil then return tostring(value):upper() end
    end
    local state = mod.save and mod.save:get("extended_characters")
    local value = type(state) == "table" and state.player_character or nil
    if value == nil and game and game.save then
      local bucket = game.save.modData and game.save.modData[mod.id]
      state = bucket and bucket.extended_characters
      value = type(state) == "table" and state.player_character or nil
    end
    return value and tostring(value):upper() or nil
  end

  function W.canUseResonance(source, key, progress)
    local target = W.RESONANCE[key]
    if not target then return false, "resonance" end
    local s = W.sync(source)
    if not s.seals[target.requires] then return false, "locked" end
    if not solvedThreshold(progress, target.threshold) then
      return false, "unsolved"
    end
    return true, target.threshold
  end

  function W.resonanceShortcuts(source, progress)
    local s, out = W.sync(source), {}
    for key, target in pairs(W.RESONANCE) do
      if s.seals[target.requires] then
        out[#out + 1] = {
          key = key, threshold = target.threshold, requiresSolved = true,
          usable = solvedThreshold(progress, target.threshold),
        }
      end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
  end

  function W.resonanceDestination(game, key)
    local target = W.RESONANCE[key]
    local def = target and game and game.data and game.data.maps
      and game.data.maps[target.threshold]
    local terrain = def and game.data.tilesets and game.data.tilesets[def.tileset]
    if not (def and terrain) then return nil, "destination" end
    local runtime = require("src.world.Map").new(def, terrain)
    local inbound = def.warps and def.warps[1]
    local ox, oy = inbound and inbound.x or 1, inbound and inbound.y or 1
    local blocked = {}
    for _, warp in ipairs(def.warps or {}) do
      blocked[warp.x .. ":" .. warp.y] = true
    end
    for _, object in ipairs(def.objects or {}) do
      blocked[object.x .. ":" .. object.y] = true
    end
    local best, bestDistance
    for y = 0, runtime.heightCells - 1 do
      for x = 0, runtime.widthCells - 1 do
        if not blocked[x .. ":" .. y] and runtime:isWalkableCell(x, y) then
          local distance = math.abs(x - ox) + math.abs(y - oy)
          if not bestDistance or distance < bestDistance then
            best, bestDistance = { x = x, y = y }, distance
          end
        end
      end
    end
    if not best then return nil, "walkable-destination" end
    best.map = target.threshold
    best.facing = ox <= 2 and "right" or (ox >= runtime.widthCells - 3 and "left"
      or (oy <= 2 and "down" or "up"))
    return best
  end

  function W.resonanceReturnState()
    local s = saved(false)
    return s and s.resonanceReturn or nil
  end

  local function persistReturn(game, token)
    local s = saved(true)
    local previous = s.resonanceReturn
    s.resonanceReturn = token
    if mod.save and mod.save.set then mod.save:set(W.STATE, s) end
    if not (game and type(game.writeSave) == "function")
        or game:writeSave() == false then
      s.resonanceReturn = previous
      if mod.save and mod.save.set then mod.save:set(W.STATE, s) end
      return false, "save"
    end
    return true, previous
  end

  function W.useResonance(game, key, progress)
    if not (game and game.save and mod.world
        and type(mod.world.warpTo) == "function") then return false, "game" end
    if activeCharacter(game) ~= key then return false, "character" end
    progress = progress or W.resonanceProgress(game, key)
    local allowed, why = W.canUseResonance(game.save, key, progress)
    if not allowed then return false, why end
    local destination, destinationWhy = W.resonanceDestination(game, key)
    if not destination then return false, destinationWhy end
    local token = {
      version = 1, character = key, sourceMap = W.ID,
      threshold = destination.map,
    }
    local armed, previous = persistReturn(game, token)
    if not armed then return false, previous end
    local warped, warpWhy = mod.world:warpTo(destination.map, destination.x,
      destination.y, destination.facing)
    if warped == false then
      -- The durable token is useful only after a successful outward warp.
      -- Restore the previous value and make the rollback durable whenever
      -- possible; a failed rollback write remains fail-closed in memory.
      local s = saved(true)
      s.resonanceReturn = previous
      if mod.save and mod.save.set then mod.save:set(W.STATE, s) end
      if game.writeSave then game:writeSave() end
      return false, warpWhy or "warp"
    end
    return warped, destination
  end

  function W.returnFromResonance(game, mapId, x, y)
    if not (game and game.save and mod.world
        and type(mod.world.warpTo) == "function") then return false, "game" end
    local token = W.resonanceReturnState()
    if not token then return false, "inactive" end
    local target = W.RESONANCE[token.character]
    if not (target and token.sourceMap == W.ID
        and token.threshold == target.threshold and mapId == token.threshold) then
      return false, "source"
    end
    if activeCharacter(game) ~= token.character then return false, "character" end
    local progress = W.resonanceProgress(game, token.character)
    local allowed, why = W.canUseResonance(game.save, token.character, progress)
    if not allowed then return false, why end
    local def = game.data and game.data.maps and game.data.maps[mapId]
    local inbound = def and def.warps and def.warps[1]
    if not (inbound and inbound.x == x and inbound.y == y) then
      return false, "cell"
    end

    -- Consume before changing maps, but only after the native save accepts
    -- the mutation.  Save failure leaves both player and token at the
    -- threshold; a later step can retry without duplication or trapping.
    local cleared, clearWhy = persistReturn(game, nil)
    if not cleared then return false, clearWhy end
    local warped, warpWhy = mod.world:warpTo(W.ID, W.ENTER.x, W.ENTER.y,
      W.ENTER.facing:lower())
    if warped == false then
      persistReturn(game, token)
      return false, warpWhy or "warp"
    end
    return warped, { map = W.ID, x = W.ENTER.x, y = W.ENTER.y }
  end

  -- A compact Kanto Facility composition derived from the same native block
  -- grammar as Silph Co.: archive shelves on the west, three connected
  -- display bays in the north/east, a central workbench and a proper lower
  -- return corridor. Tile $01 is the native checker background embedded not
  -- only in block 14 but also in Facility wall/shelf metatiles. Under the
  -- Celadon palette it becomes the rejected pink/cream screen-wide pattern.
  -- Keep the native structures and collision grammar, but append Workshop-
  -- local variants in which only background tile $01 is replaced by the
  -- native, walkable solid Facility tile $11. Existing blocks/maps and raster
  -- assets remain byte-for-byte untouched.
  local WORKSHOP_SOURCE_BLOCKS = {
    60, 61, 61, 61, 36, 125, 124, 62,
    68, 14, 14, 14, 14, 14, 14, 70,
    68, 14, 14, 90, 99, 14, 103, 66,
    68, 14, 14, 70, 13, 14, 14, 70,
    64, 42, 43, 66, 99, 14, 103, 66,
    68, 53, 24, 70, 14, 14, 14, 70,
    68, 30, 53, 70, 14, 14, 55, 70,
    68, 10, 30, 70, 14, 55, 14, 70,
    72, 73, 73, 74, 73, 73, 73, 74,
  }

  local function blocks()
    local remap = assert(W.BLOCK_REMAP,
      "legacy workshop block remap unavailable")
    local result = {}
    for index, source in ipairs(WORKSHOP_SOURCE_BLOCKS) do
      result[index] = assert(remap[source],
        "legacy workshop source block has no remap: " .. tostring(source))
    end
    return result
  end

  local function installFacilityWorkshopBlocks()
    local registry = mod.content and mod.content.tilesets
    local facility = registry and registry.get and registry:get("FACILITY")
    assert(facility and type(facility.blocks) == "table",
      "legacy workshop requires the authority FACILITY tileset")
    local background, floorTile = 1, 17 -- FACILITY $01 -> native solid $11.
    local remap, additions, seen = {}, {}, {}
    for _, source in ipairs(WORKSHOP_SOURCE_BLOCKS) do
      if not seen[source] then
        seen[source] = true
        local native = assert(facility.blocks[source + 1],
          "legacy workshop FACILITY source block missing: " .. source)
        local replacement, changed = {}, false
        for index = 1, 16 do
          local tile = assert(native[index],
            "legacy workshop FACILITY source block is incomplete: " .. source)
          if tile == background then tile, changed = floorTile, true end
          replacement[index] = tile
        end
        if changed then
          -- Map block ids are zero-based. The first appended block therefore
          -- has id #facility.blocks, the next #facility.blocks + 1, and so on.
          remap[source] = #facility.blocks + #additions
          additions[#additions + 1] = replacement
        else
          remap[source] = source
        end
      end
    end
    assert(#additions > 0, "legacy workshop FACILITY remap is unexpectedly empty")
    registry:patch("FACILITY", { blocks = { __append = additions } })
    local merged = registry:get("FACILITY")
    for source, mapped in pairs(remap) do
      local installed = merged and merged.blocks and merged.blocks[mapped + 1]
      assert(type(installed) == "table" and #installed == 16,
        "legacy workshop FACILITY block remap failed: " .. source)
      for index = 1, 16 do
        assert(installed[index] ~= background,
          "legacy workshop block still contains checker tile $01: " .. source)
      end
    end
    W.BLOCK_REMAP = remap
    W.FLOOR_BLOCK = assert(remap[14],
      "legacy workshop floor block unavailable after remap")
    return remap
  end
  W.SEAL_OBJECTS = {
    RED = { seal = "red", x = 4, y = 2,
      locked = "KA_NGPLUS_SEAL_RED_LOCKED",
      unlocked = "KA_NGPLUS_SEAL_RED_UNLOCKED" },
    BLUE = { seal = "blue", x = 8, y = 2,
      locked = "KA_NGPLUS_SEAL_BLUE_LOCKED",
      unlocked = "KA_NGPLUS_SEAL_BLUE_UNLOCKED" },
    GREEN = { seal = "green", x = 12, y = 2,
      locked = "KA_NGPLUS_SEAL_GREEN_LOCKED",
      unlocked = "KA_NGPLUS_SEAL_GREEN_UNLOCKED" },
  }

  function W.sealObjectVisibility(source)
    local display, out = W.sealDisplay(source), {}
    for index, character in ipairs({ "RED", "BLUE", "GREEN" }) do
      local object = W.SEAL_OBJECTS[character]
      local unlocked = display[index].unlocked == true
      out[object.locked], out[object.unlocked] = not unlocked, unlocked
    end
    return out
  end

  function W.refreshSealVisuals(game, source)
    if not (game and game.save) then return false, "game" end
    local visibility = W.sealObjectVisibility(source or game.save)
    local Commands = opts.commands or require("src.script.Commands")
    local ctx = { game = game, save = game.save,
      overworld = mod.world and mod.world:overworld() or game.overworld }
    for name, visible in pairs(visibility) do
      if visible then Commands.show_object(ctx, W.ID, name)
      else Commands.hide_object(ctx, W.ID, name) end
    end
    return true, visibility
  end

  function W.enter(game)
    if not (mod.world and type(mod.world.warpTo) == "function") then
      return false, "world"
    end
    W.refreshSealVisuals(game)
    return mod.world:warpTo(W.ID, W.ENTER.x, W.ENTER.y,
      W.ENTER.facing:lower())
  end

  function W.resonanceStatus(source, key, progress)
    local ok, why = W.canUseResonance(source, key, progress or {})
    if ok then return { state = "ready", usable = true,
      text = tr("RESONANCE: STABLE", "RESONANZ: STABIL") } end
    if why == "locked" then return { state = "locked", usable = false,
      text = tr("RESONANCE: SEALED", "RESONANZ: VERSIEGELT") } end
    if why == "unsolved" then return { state = "unsolved", usable = false,
      text = tr("RESONANCE: THRESHOLD UNSOLVED",
        "RESONANZ: SCHWELLE UNGELÖST") } end
    return { state = "unavailable", usable = false,
      text = tr("RESONANCE: DORMANT", "RESONANZ: RUHEND") }
  end
  local function show(game, text, done)
    if type(opts.showText) == "function" then return opts.showText(game, text, done) end
    game.stack:push(require("src.render.TextBox").new(game, text, done)); return true
  end
  function W.landmarkTalk(id, game, _, _, done)
    local row = W.LANDMARKS[id]
    if not row then return false, "unknown landmark" end
    W.discover(id)
    return show(game, tr(row.en, row.de), done)
  end
  function W.sealTalk(key, game, _, _, done)
    local landmark = ({ red = "ARCHIVE_PLINTH", blue = "TRIUNE_DIAL", green = "LEDGER_DESK" })[key]
    local display = W.sealDisplay(game and game.save)
    local row = ({ red = display[1], blue = display[2], green = display[3] })[key]
    if not (landmark and row) then return false, "unknown seal" end
    W.discover(landmark)
    local clue = W.LANDMARKS[landmark]
    local progress = W.resonanceProgress(game, key:upper())
    local resonance = W.resonanceStatus(game and game.save, key:upper(), progress)
    local text = row.symbol .. " " .. row.text .. "\n"
      .. resonance.text .. "\f" .. tr(clue.en, clue.de)
    if not resonance.usable then return show(game, text, done) end
    game.stack:push(require("src.render.TextBox").new(game,
      text .. "\f" .. tr("Follow the stable resonance?",
        "Der stabilen Resonanz folgen?"), nil, {
        defaultNo = true,
        choice = function(yes)
          if done then done() end
          if not yes then return end
          local ok, why = W.useResonance(game, key:upper(), progress)
          if not ok then
            show(game, tr("The resonance breaks.", "Die Resonanz bricht ab.")
              .. "\n" .. tostring(why or "unknown"))
          end
        end,
      }))
    return true
  end
  function W.ledgerTalk(game, _, _, done)
    -- Pending first grants are offered before paid replacements.
    local pending = packages.persistent(game.save, false)
    if pending and next(pending.pendingItems or {}) then
      packages.claimPending(game)
    end
    local rows, ledger = {}, W.ledger(game.save)
    for index = 1, 3 do
      local row = ledger[index]
      rows[#rows + 1] = {
        label = row.symbol .. " " .. (row.visible and row.character or "???"),
        right = row.visible and (("%d/%d"):format(
          #row.packages, #row.balls)) or "?",
        value = { kind = "ledger", row = row },
      }
    end
    for _, offer in ipairs(W.shopOffers(game.save)) do
      local def = game.data and game.data.items and game.data.items[offer.item]
      rows[#rows + 1] = {
        label = def and def.name or offer.item,
        right = "¥" .. tostring(offer.price), value = offer,
      }
    end
    local list
    list = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("LEGACY LEDGER", "VERMÄCHTNIS-LEDGER"), rows, {
        messageBox = true, pageJump = true, onCancel = done,
        onChoose = function(item)
          local offer = item and item.value
          if not offer then return end
          if offer.kind == "ledger" then
            return show(game, W.planText(offer.row))
          end
          game.stack:push(require("src.render.TextBox").new(game,
            tr("Buy this workshop item?", "Dieses Werkstatt-Item kaufen?"),
            nil, { defaultNo = true, choice = function(yes)
              local ok, err = W.purchaseOffer(game, offer, yes)
              list.footer = ok and tr("ITEM RECEIVED", "ITEM ERHALTEN")
                or tr("NOT PURCHASED: ", "NICHT GEKAUFT: ") .. tostring(err)
            end }))
        end,
      })
    game.stack:push(list)
    return true
  end

  function W.register()
    if W.registered then return false, "already registered" end
    if packages.enabled == false then
      W.registered = true
      return true
    end
    installFacilityWorkshopBlocks()
    local text = {
      TEXT_KA_NGPLUS_WORKSHOP_PLINTH = W.LANDMARKS.ARCHIVE_PLINTH,
      TEXT_KA_NGPLUS_WORKSHOP_DIAL = W.LANDMARKS.TRIUNE_DIAL,
      TEXT_KA_NGPLUS_WORKSHOP_LEDGER = W.LANDMARKS.LEDGER_DESK,
      TEXT_KA_NGPLUS_WORKSHOP_RED_SEAL = { en = "RED SEAL", de = "ROTES SIEGEL" },
      TEXT_KA_NGPLUS_WORKSHOP_BLUE_SEAL = { en = "BLUE SEAL", de = "BLAUES SIEGEL" },
      TEXT_KA_NGPLUS_WORKSHOP_GREEN_SEAL = { en = "GREEN SEAL", de = "GRÜNES SIEGEL" },
    }
    for id, row in pairs(text) do mod.content.text:register(id, tr(row.en, row.de)) end
    mod.content.text_pointers:patch("???", (function() local p = {}; for id in pairs(text) do p[id] = { text = id } end; return p end)())
    if mod.content.sprites then
      for id, image in pairs({
        SPRITE_KA_LEGACY_SEAL_LOCKED = "assets/legacy_workshop/seal_locked.png",
        SPRITE_KA_LEGACY_SEAL_RED = "assets/legacy_workshop/seal_red.png",
        SPRITE_KA_LEGACY_SEAL_BLUE = "assets/legacy_workshop/seal_blue.png",
        SPRITE_KA_LEGACY_SEAL_GREEN = "assets/legacy_workshop/seal_green.png",
        SPRITE_KA_LEGACY_LEDGER = "assets/legacy_workshop/ledger.png",
      }) do
        if not (mod.content.sprites.get and mod.content.sprites:get(id)) then
          mod.content.sprites:register(id, { id = id,
            image = assert(mod.path, "legacy workshop sprite path") .. "/" .. image,
            frames = 1, walker = false, trueColor = true })
        end
      end
    end
    mod.content.maps:register(W.ID, {
      id = W.ID, index = W.INDEX, label = "LegacyWorkshop",
      tileset = "FACILITY", palette = "CELADON",
      width = W.MAP_WIDTH, height = W.MAP_HEIGHT,
      borderBlock = 46, blocks = blocks(), voxelMode = "MAP_STUDIO", voxelRevision = 2,
      voxelSemanticOverrides = {}, outdoor = false, signs = {}, connections = {},
      warps = { { x = W.EXIT.x, y = W.EXIT.y,
        destMap = W.ANCHOR.returnTo.destMap,
        destWarp = W.ANCHOR.returnTo.destWarp } },
      objects = {
        { index = 1, name = W.SEAL_OBJECTS.RED.locked,
          sprite = "SPRITE_KA_LEGACY_SEAL_LOCKED", x = W.SEAL_OBJECTS.RED.x,
          y = W.SEAL_OBJECTS.RED.y, movement = "STAY", range = "NONE",
          text = "TEXT_KA_NGPLUS_WORKSHOP_RED_SEAL" },
        { index = 2, name = W.SEAL_OBJECTS.RED.unlocked, hidden = true,
          sprite = "SPRITE_KA_LEGACY_SEAL_RED", x = W.SEAL_OBJECTS.RED.x,
          y = W.SEAL_OBJECTS.RED.y, movement = "STAY", range = "NONE",
          text = "TEXT_KA_NGPLUS_WORKSHOP_RED_SEAL" },
        { index = 3, name = W.SEAL_OBJECTS.BLUE.locked,
          sprite = "SPRITE_KA_LEGACY_SEAL_LOCKED", x = W.SEAL_OBJECTS.BLUE.x,
          y = W.SEAL_OBJECTS.BLUE.y, movement = "STAY", range = "NONE",
          text = "TEXT_KA_NGPLUS_WORKSHOP_BLUE_SEAL" },
        { index = 4, name = W.SEAL_OBJECTS.BLUE.unlocked, hidden = true,
          sprite = "SPRITE_KA_LEGACY_SEAL_BLUE", x = W.SEAL_OBJECTS.BLUE.x,
          y = W.SEAL_OBJECTS.BLUE.y, movement = "STAY", range = "NONE",
          text = "TEXT_KA_NGPLUS_WORKSHOP_BLUE_SEAL" },
        { index = 5, name = W.SEAL_OBJECTS.GREEN.locked,
          sprite = "SPRITE_KA_LEGACY_SEAL_LOCKED", x = W.SEAL_OBJECTS.GREEN.x,
          y = W.SEAL_OBJECTS.GREEN.y, movement = "STAY", range = "NONE",
          text = "TEXT_KA_NGPLUS_WORKSHOP_GREEN_SEAL" },
        { index = 6, name = W.SEAL_OBJECTS.GREEN.unlocked, hidden = true,
          sprite = "SPRITE_KA_LEGACY_SEAL_GREEN", x = W.SEAL_OBJECTS.GREEN.x,
          y = W.SEAL_OBJECTS.GREEN.y, movement = "STAY", range = "NONE",
          text = "TEXT_KA_NGPLUS_WORKSHOP_GREEN_SEAL" },
        { index = 7, name = "KA_NGPLUS_LEDGER_DESK",
          sprite = "SPRITE_KA_LEGACY_LEDGER", x = 8, y = 5,
          movement = "STAY", range = "DOWN",
          text = "TEXT_KA_NGPLUS_WORKSHOP_LEDGER" },
      },
    })
    if mod.content.map_songs then
      mod.content.map_songs:register(W.ID, "Music_Celadon")
    end
    mod.content.encounters:register(W.ID, { grass = { rate = 0, slots = {} } })
    mod.content.map_scripts:register(W.ID, { priority = 2820, talk = {
      TEXT_KA_NGPLUS_WORKSHOP_PLINTH = function(...) return W.landmarkTalk("ARCHIVE_PLINTH", ...) end,
      TEXT_KA_NGPLUS_WORKSHOP_DIAL = function(...) return W.landmarkTalk("TRIUNE_DIAL", ...) end,
      TEXT_KA_NGPLUS_WORKSHOP_LEDGER = W.ledgerTalk,
      TEXT_KA_NGPLUS_WORKSHOP_RED_SEAL = function(...) return W.sealTalk("red", ...) end,
      TEXT_KA_NGPLUS_WORKSHOP_BLUE_SEAL = function(...) return W.sealTalk("blue", ...) end,
      TEXT_KA_NGPLUS_WORKSHOP_GREEN_SEAL = function(...) return W.sealTalk("green", ...) end,
    } })
    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("game.ready", function(ev)
        W.game = ev and ev.game or W.game
      end)
      mod.events:on("map.entered", function(ev)
        local game = ev and ev.game or W.game
        local mapId = ev and (ev.mapId or ev.map and ev.map.id)
        if game then W.game = game end
        if game and mapId == W.ID then W.refreshSealVisuals(game) end
      end)
      mod.events:on("world.stepped", function(ev)
        local game = ev and ev.game or W.game
        if not (game and ev and W.resonanceReturnState()) then return end
        W.returnFromResonance(game, ev.mapId, ev.x, ev.y)
      end)
      mod.events:on("save.loaded", function(ev)
        local game = ev and ev.game or W.game
        local ow = mod.world and mod.world:overworld()
        if game and ow and ow.map and ow.map.id == W.ID then
          W.refreshSealVisuals(game)
        end
      end)
    end
    W.registered = true
    return true
  end
  return W
end
