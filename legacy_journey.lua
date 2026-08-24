-- KA-INTERNAL: LEGACY-JOURNEY-001

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local GameVersion = require("src.core.GameVersion")
  local Bag = require("src.inventory.Bag")
  local activeGame
  local storageScopeReady = false
  local storageBackendFailure
  local freshSeedFailure
  local storageBackendMode = mod.storage
    and type(mod.storage.edition) == "function" and "edition" or "playthrough"

  -- Present the archive's transactional file-shaped interface on top of the
  -- official data-only storage API. Newer engines expose edition storage and
  -- import the old raw v6 archive to `legacy/archive`; exact stock 0.1.86 falls
  -- back to playthrough storage plus the verified fresh-save lineage capsule.
  -- Scope is enabled only after a real save was created or loaded; the
  -- provisional boot skeleton must not allocate a playthrough id.
  local function storageArchiveFs()
    if not mod.storage then return nil end
    if storageBackendMode == "playthrough"
        and not (type(mod.storage.read) == "function"
          and type(mod.storage.write) == "function"
          and type(mod.storage.delete) == "function") then return nil end

    local SaveSerializer = require("src.core.SaveSerializer")
    local editionFacade

    local function game()
      return storageScopeReady and activeGame or nil
    end

    local function playthroughKey(path)
      local encoded = tostring(path or ""):gsub("[^%w_-]", function(char)
        return "_" .. tostring(string.byte(char)) .. "_"
      end)
      return "legacy_lineage/files/" .. encoded
    end

    -- These exact public logical keys match the engine-owned import contract.
    -- The facade stores raw archive tables, not the stock-0.1.86 string wrapper.
    local function editionKey(path)
      path = tostring(path or "")
      if path:find("_rollback%.lua", 1) then return "legacy/rollback" end
      if path:sub(-4) == ".tmp" then return "legacy/archive_tmp" end
      if path:sub(-4) == ".bak" then return "legacy/archive_backup" end
      return "legacy/archive"
    end

    local function failStorage(code, message)
      storageBackendFailure = tostring(message or code
        or "official Legacy storage is unavailable")
      return storageBackendFailure
    end

    local function edition()
      local current = game()
      if not current then return nil, "no active playthrough" end
      if editionFacade then return editionFacade end
      local facade, code, message = mod.storage:edition(current)
      if type(facade) ~= "table" or type(facade.read) ~= "function"
          or type(facade.write) ~= "function"
          or type(facade.delete) ~= "function" then
        return nil, failStorage(code, message)
      end
      editionFacade = facade
      return facade
    end

    local function read(path)
      local current = game()
      if not current then return nil, "no active playthrough" end
      local backend, key
      if storageBackendMode == "edition" then
        local err
        backend, err = edition()
        if not backend then return nil, err end
        key = editionKey(path)
      else
        backend, key = mod.storage, playthroughKey(path)
      end
      local value, code, message
      if storageBackendMode == "edition" then
        value, code, message = backend:read(key)
        if value == nil then
          if code == "not_found" then return nil, message or code end
          return nil, failStorage(code, message)
        end
        if type(value) ~= "table" then
          return nil, failStorage("invalid_data",
            "edition Legacy archive is not data-only table storage")
        end
        local ok, body = pcall(SaveSerializer.encode, value)
        if not ok then return nil, failStorage("encode_failed", body) end
        return body
      end
      value, code, message = backend:read(current, key)
      if value == nil then
        if code == "not_found" then return nil, message or code end
        return nil, failStorage(code, message)
      end
      if type(value) ~= "table" or type(value.body) ~= "string" then
        return nil, failStorage("invalid_data",
          "playthrough Legacy archive is not a versioned data record")
      end
      return value.body
    end

    return {
      getInfo = function(path)
        local body = read(path)
        return body and { type = "file", size = #body } or nil
      end,
      read = read,
      write = function(path, body)
        local current = game()
        if not current then return false, "no active playthrough" end
        if type(body) ~= "string" then
          return false, "archive body is not a string"
        end
        local ok, code, message
        if storageBackendMode == "edition" then
          local facade, bindErr = edition()
          if not facade then return false, bindErr end
          local value, decodeErr = SaveSerializer.decode(body)
          if type(value) ~= "table" then
            return false, "Legacy archive encode bridge rejected data: "
              .. tostring(decodeErr)
          end
          ok, code, message = facade:write(editionKey(path), value)
          if ok == true then
            local verified, readCode, readMessage = facade:read(editionKey(path))
            local wantedOk, wanted = pcall(SaveSerializer.encode, value)
            local gotOk, got = pcall(SaveSerializer.encode, verified)
            if not (wantedOk and gotOk and wanted == got) then
              facade:delete(editionKey(path))
              ok, code, message = false, "verify_failed",
                readMessage or readCode or "edition storage readback mismatch"
            end
          end
          if ok ~= true then failStorage(code, message) end
        else
          local logicalKey = playthroughKey(path)
          ok, code, message = mod.storage:write(current,
            logicalKey, { version = 1, body = body })
          if ok == true then
            local verified, readCode, readMessage =
              mod.storage:read(current, logicalKey)
            if type(verified) ~= "table" or verified.version ~= 1
                or verified.body ~= body then
              -- Stock 0.1.86 can report success after a decodable short write.
              -- Retire that logical generation so A.load recovers from its
              -- separately verified witness/backup key instead of accepting it.
              mod.storage:delete(current, logicalKey)
              ok, code, message = false, "verify_failed",
                readMessage or readCode or "playthrough storage readback mismatch"
            end
          end
        end
        return ok == true, message or code
      end,
      createDirectory = function() return true end,
      remove = function(path)
        local current = game()
        if not current then return false, "no active playthrough" end
        local ok, code, message
        if storageBackendMode == "edition" then
          local facade, bindErr = edition()
          if not facade then return false, bindErr end
          ok, code, message = facade:delete(editionKey(path))
          if ok ~= true and code ~= "not_found" then failStorage(code, message) end
        else
          ok, code, message = mod.storage:delete(current,
            playthroughKey(path))
        end
        if ok == true or code == "not_found" then return true end
        return false, message or code
      end,
    }
  end

  local archive = opts.archive
  if not archive then
    local makeArchive = assert(opts.makeArchive,
      "legacy journey needs the packaged archive factory")
    archive = makeArchive({
      edition = GameVersion.get(),
      modId = mod.id,
      fs = opts.archiveFs or storageArchiveFs(),
      editionScoped = storageBackendMode == "edition",
      enforceLegacyMigrationGuard = true,
      log = mod.log,
      isBadge = Bag.isBadge,
      requireRegistryValidation = true,
    })
  end
  local J = { archive = archive }

  local function bindArchiveData(data)
    if type(archive.bindData) ~= "function" then return true end
    if type(data) ~= "table" then
      local ok, loaded = pcall(require, "src.core.Data")
      if ok then data = loaded end
    end
    return archive.bindData(data)
  end
  bindArchiveData()

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  -- The engine TextBox can scroll a third line within one page.  That is
  -- useful for imported vanilla scripts, but these irreversible Journey
  -- explanations must pause after every two visible lines.  Re-page with the
  -- real renderer's variable-width measurement, then insert an explicit form
  -- feed between every two-line slice.  Dynamic storage errors and names are
  -- therefore held to the same contract as the authored EN/DE copy.
  local textBoxPaginate = require("src.render.TextBox").paginate
  local function twoLinePages(text)
    local rendered = textBoxPaginate(tostring(text or ""))
    local pages = {}
    for _, sourcePage in ipairs(rendered) do
      for first = 1, #sourcePage, 2 do
        local visible = { sourcePage[first] }
        if sourcePage[first + 1] ~= nil then
          visible[#visible + 1] = sourcePage[first + 1]
        end
        pages[#pages + 1] = table.concat(visible, "\n")
      end
    end
    return table.concat(pages, "\f")
  end

  local function newTextBox(game, text, done, boxOpts)
    return require("src.render.TextBox").new(
      game, twoLinePages(text), done, boxOpts)
  end

  local function legacyState(save)
    local bucket = type(save and save.modData) == "table"
      and save.modData[mod.id]
    return type(bucket) == "table" and bucket.legacy_journey or nil
  end

  J.OAK_HOST_MAP = "OAKS_LAB"
  J.OAK_HOST_OBJECT = "OAKSLAB_OAK1"
  J.OAK_HOST_PORTRAIT = "OPP_PROF_OAK"
  J.OAK_HOST_HD_PORTRAIT =
    "assets/characters/frlg_trainers/professor_oak_legacy_host_hd_v1.png"
  J.PACT_IDS = { "journey", "trainer", "legacy", "ascendant" }
  J.BANK_POLICY_IDS = { "open", "badges4", "league", "sealed" }
  J.ITEM_POLICY_IDS = { "safe", "empty" }

  -- PicBox is intentionally a native 160x144 state. In exact engine 0.1.96
  -- it loads trainer.pic (64x64) and draws it 1:1 into the 64px inner slot;
  -- the approved Oak subject inside that file is only 34x58 pixels. The
  -- completed UI canvas then enlarges those pixels with nearest filtering,
  -- which is why the Legacy host looks far rougher than the authored master.
  -- Keep PicBox itself as the palette/frame owner, but replace only its image
  -- layer with the approved 590x1009 v1 master after the UI canvas is scaled.
  local oakHostHdImage
  local function loadOakHostHdImage()
    if oakHostHdImage then return oakHostHdImage end
    if not (love and love.graphics and love.graphics.newImage) then return nil end
    local ok, image = pcall(love.graphics.newImage,
      mod.path .. "/" .. J.OAK_HOST_HD_PORTRAIT)
    if not (ok and image and image.getDimensions) then return nil end
    if image.setFilter then image:setFilter("linear", "linear") end
    oakHostHdImage = image
    return image
  end

  local function oakHostScreenViewport(viewport)
    if type(viewport) == "table" then return viewport, false end
    if not (love and love.graphics and love.graphics.getDimensions) then
      return nil, false
    end
    -- DRAMALESS_SHAPE can preserve render.hud while dropping the viewport
    -- return value. Reconstruct the same centred integer UI viewport used by
    -- Renderer:endFrame so this cosmetic path degrades safely with that mod.
    local okRenderer, Renderer = pcall(require, "src.render.Renderer")
    if not okRenderer then return nil, false end
    local ww, wh = love.graphics.getDimensions()
    local pw, ph = ww, wh
    if love.graphics.getPixelDimensions then
      pw, ph = love.graphics.getPixelDimensions()
    end
    local dpiX = ww > 0 and pw / ww or 1
    local dpiY = wh > 0 and ph / wh or 1
    if dpiX <= 0 then dpiX = 1 end
    if dpiY <= 0 then dpiY = 1 end
    local fit = Renderer.fitScale and Renderer:fitScale()
      or math.max(1, math.floor(math.min(pw / 160, ph / 144)))
    return {
      width = ww, height = wh,
      gameX = math.floor((pw - 160 * fit) / 2) / dpiX,
      gameY = math.floor((ph - 144 * fit) / 2) / dpiY,
      gameWidth = 160 * fit / dpiX,
      gameHeight = 144 * fit / dpiY,
      scale = fit, dpiX = dpiX, dpiY = dpiY,
    }, true
  end

  local function activeOakHostPortrait(game)
    local stack = game and game.stack
    local states = stack and stack.states
    if type(states) ~= "table" then return nil end
    local portrait
    for index = #states, 1, -1 do
      if states[index].kascLegacyOakHdImage then
        portrait = states[index]
        break
      end
    end
    if not portrait then return nil end
    local top = stack.top and stack:top() or states[#states]
    if top == portrait then return portrait, false end
    local topMeta = top and getmetatable(top)
    if topMeta and topMeta.isTextBox then return portrait, true end
    return nil
  end

  mod.hooks:wrap("render.hud", function(nextHud, game, viewport)
    nextHud(game, viewport)
    local portrait, textBoxOnTop = activeOakHostPortrait(game)
    local image = portrait and portrait.kascLegacyOakHdImage
    if not (image and image.getDimensions and love and love.graphics
        and love.graphics.draw) then return end
    local recoveredViewport
    viewport, recoveredViewport = oakHostScreenViewport(viewport)
    if not viewport then return end

    local sourceW, sourceH = image:getDimensions()
    if sourceW <= 0 or sourceH <= 0 then return end
    local gameScaleX = (viewport.gameWidth or 160) / 160
    local gameScaleY = (viewport.gameHeight or 144) / 144
    -- Exact PicBox.lua geometry: frame (6,4,9,9), 64px image centred at
    -- logical (52,36). The TextBox begins at y=96 and must remain above Oak,
    -- so its four-pixel overlap is clipped just as the stack draw clips it.
    local slotX = (viewport.gameX or 0) + 52 * gameScaleX
    local slotY = (viewport.gameY or 0) + 36 * gameScaleY
    local slotW, slotH = 64 * gameScaleX, 64 * gameScaleY
    -- Preserve the exact composition of the approved 64px trainer file: its
    -- non-transparent subject occupies (15,3)-(49,61), i.e. 34x58 pixels.
    -- Only resolution changes; Oak does not grow or move inside the frame.
    local targetX = slotX + 15 * gameScaleX
    local targetY = slotY + 3 * gameScaleY
    local targetW = 34 * gameScaleX
    local targetH = 58 * gameScaleY
    local drawScale = math.min(targetW / sourceW, targetH / sourceH)
    local drawW, drawH = sourceW * drawScale, sourceH * drawScale
    local drawX = math.floor(targetX + (targetW - drawW) / 2)
    local drawY = math.floor(targetY + targetH - drawH)
    local clipH = (textBoxOnTop and 60 or 64) * gameScaleY

    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setScissor(slotX, slotY, slotW, clipH)
    love.graphics.draw(image, drawX, drawY, 0, drawScale, drawScale)
    love.graphics.setScissor()
    portrait.kascLegacyOakHdProof = {
      path = J.OAK_HOST_HD_PORTRAIT,
      sourceWidth = sourceW,
      sourceHeight = sourceH,
      drawWidth = drawW,
      drawHeight = drawH,
      screenSpace = true,
      textBoxOcclusion = textBoxOnTop == true,
      recoveredViewport = recoveredViewport == true,
    }
  end, 82)

  local PACTS = {
    journey = {
      label = { en = "JOURNEY", de = "REISE" },
      detail = {
        en = "Fair, lightly improved teams. You choose the Bank rule separately.",
        de = "Faire, leicht verbesserte Teams. Du wählst die Bankregel getrennt.",
      },
    },
    trainer = {
      label = { en = "TRAINER", de = "TRAINER" },
      detail = {
        en = "Badge-scaled good teams and active challengers. You choose the Bank rule.",
        de = "Ordensbasierte gute Teams und aktive Herausforderer. Du wählst die Bankregel.",
      },
    },
    legacy = {
      label = { en = "LEGACY", de = "VERMÄCHTNIS" },
      detail = {
        en = "Better moves, items and boss synergy. You choose the Bank rule.",
        de = "Bessere Attacken, Items und Boss-Synergien. Du wählst die Bankregel.",
      },
    },
    ascendant = {
      label = { en = "ASCENDANT", de = "ASCENDANT" },
      detail = {
        en = "Hard rules and dangerous challengers. A sealed Bank is recommended.",
        de = "Harte Regeln und gefährliche Herausforderer. Eine versiegelte Bank wird empfohlen.",
      },
    },
  }
  local BANK_POLICIES = {
    open = {
      label = { en = "OPEN", de = "OFFEN" },
      detail = {
        en = "Bank and Locker open as soon as Oak gives your new partner.",
        de = "Bank und Lager öffnen, sobald Eich deinen neuen Partner übergibt.",
      },
    },
    badges4 = {
      label = { en = "AFTER 4 BADGES", de = "AB 4 ORDEN" },
      detail = {
        en = "Bank and Locker need your partner and four current-run badges.",
        de = "Bank und Lager brauchen deinen Partner und vier Orden dieses Laufs.",
      },
    },
    league = {
      label = { en = "AFTER LEAGUE", de = "NACH LIGA" },
      detail = {
        en = "Bank and Locker stay locked until this run enters the Hall of Fame.",
        de = "Bank und Lager bleiben bis zur Ruhmeshalle dieses Laufs gesperrt.",
      },
    },
    sealed = {
      label = { en = "SEALED", de = "VERSIEGELT" },
      detail = {
        en = "Bank and Locker cannot be opened during this run.",
        de = "Bank und Lager können in diesem Lauf nicht geöffnet werden.",
      },
    },
  }
  local ITEM_POLICIES = {
    safe = {
      label = { en = "SAFE", de = "SICHER" },
      detail = {
        en = "Archive transferable items and money. Badges, HMs, Key Items and the Field Kit never cross the reset.",
        de = "Archiviere übertragbare Items und Geld. Orden, VMs, Basis-Items und Feld-Kit werden nie übernommen.",
      },
    },
    empty = {
      label = { en = "EMPTY", de = "LEER" },
      detail = {
        en = "Archive no optional Bag or PC items. The three path Mega Stones remain unique souvenirs; Pokémon and money use separate stores.",
        de = "Archiviere keine optionalen Beutel- oder PC-Items. Die drei Pfad-Megasteine bleiben einzigartige Andenken; Pokémon und Geld nutzen eigene Speicher.",
      },
    },
  }

  local function pactId(value)
    value = tostring(value or ""):lower()
    return PACTS[value] and value or "journey"
  end

  local function bankPolicyId(value, pact)
    value = tostring(value or ""):lower()
    if BANK_POLICIES[value] then return value end
    return pactId(pact) == "ascendant" and "sealed" or "open"
  end

  local function itemPolicyId(value)
    if archive and type(archive.itemPolicyId) == "function" then
      return archive.itemPolicyId(value)
    end
    value = tostring(value or ""):lower()
    return ITEM_POLICIES[value] and value or "safe"
  end

  local function localizedDef(def, field)
    local row = def and def[field]
    return row and tr(row.en, row.de) or ""
  end

  function J.pactRows()
    local rows = {}
    for _, id in ipairs(J.PACT_IDS) do
      rows[#rows + 1] = {
        label = localizedDef(PACTS[id], "label"), value = id,
        detail = localizedDef(PACTS[id], "detail"),
        help = localizedDef(PACTS[id], "detail"),
      }
    end
    return rows
  end

  function J.bankPolicyRows(pact)
    pact = pactId(pact)
    local ids = pact == "ascendant"
      and { "sealed", "open", "badges4", "league" }
      or J.BANK_POLICY_IDS
    local rows = {}
    for _, id in ipairs(ids) do
      rows[#rows + 1] = {
        label = localizedDef(BANK_POLICIES[id], "label"), value = id,
        detail = localizedDef(BANK_POLICIES[id], "detail"),
        help = localizedDef(BANK_POLICIES[id], "detail"),
      }
    end
    return rows
  end

  function J.itemPolicyRows()
    local rows = {}
    for _, id in ipairs(J.ITEM_POLICY_IDS) do
      rows[#rows + 1] = {
        label = localizedDef(ITEM_POLICIES[id], "label"), value = id,
        detail = localizedDef(ITEM_POLICIES[id], "detail"),
        help = localizedDef(ITEM_POLICIES[id], "detail"),
      }
    end
    return rows
  end

  function J.pactName(value)
    return localizedDef(PACTS[pactId(value)], "label")
  end

  function J.bankPolicyName(value, pact)
    return localizedDef(BANK_POLICIES[bankPolicyId(value, pact)], "label")
  end


  function J.itemPolicyName(value)
    return localizedDef(ITEM_POLICIES[itemPolicyId(value)], "label")
  end

  -- An already-active v6 Journey has no archived draft because the rules
  -- screen did not exist yet.  Only the migration marker may authorize the
  -- deterministic OFF contract; pending Lab runs still wait for their 151/251
  -- choice, while active runs are locked immediately on load.
  function J.reconcileLegacyRunRules(save)
    local run = legacyState(save)
    if type(run) ~= "table" or run.archiveStatus ~= "active"
        or run.runRulesLocked == true or run.pendingRunRules ~= nil
        or run.runRulesLegacyDefault ~= true then return false end
    local rules = mod.exports and mod.exports.runRules
    if not (rules and type(rules.seedLegacy) == "function") then return false end
    local bucket = type(save.modData) == "table" and save.modData[mod.id]
    local boundary = type(bucket) == "table"
      and type(bucket.beyond_kanto) == "table"
      and bucket.beyond_kanto.active == true
    local pool = tonumber(run.partnerDexMax) == 251 and 251
      or tonumber(run.partnerDexMax) == 151 and 151
      or boundary and 251 or 151
    local seeded, err = rules.seedLegacy(save, nil, pool)
    if not seeded then
      if mod.log and mod.log.error then
        mod.log:error("Legacy v6 run-rules migration failed: " .. tostring(err))
      end
      return false
    end
    run.runRulesLocked = true
    run.partnerDexMax = pool
    return true
  end

  J.HEVO_GATE_KEY = "legacy_journey_hevo_gate"
  J.HEVO_READY_FLAG = "KA_LEGACY_JOURNEY_HEVO_SEALED"
  J.HEVO_OAK_CALLED_FLAG = "KA_LEGACY_JOURNEY_OAK_CALLED"
  -- Oak's Lab draws one terminal across both north-wall cells.  The stock
  -- 0.1.95 RuntimeMap exposes the left and right halves as (0,1) and (1,1),
  -- approached from the matching x cell on row 2.  Keep this deliberately
  -- narrower than the adjacent Pokédex displays at x=2/3.
  J.OAK_PC_TARGETS = { [0] = true, [1] = true }
  local HEVO_KEYS = { RED = "red", BLUE = "blue", GREEN = "green" }
  local oakCallInFlight = false
  local pushMessage

  local function modBucket(save, create)
    if type(save) ~= "table" then return nil end
    if type(save.modData) ~= "table" then
      if not create then return nil end
      save.modData = {}
    end
    local bucket = save.modData[mod.id]
    if type(bucket) ~= "table" and create then
      bucket = {}
      save.modData[mod.id] = bucket
    end
    return type(bucket) == "table" and bucket or nil
  end

  local function hevoGateState(save, create)
    local bucket = modBucket(save, create)
    if not bucket then return nil end
    local state = bucket[J.HEVO_GATE_KEY]
    if type(state) ~= "table" and create then
      state = { version = 1 }
      bucket[J.HEVO_GATE_KEY] = state
    end
    if type(state) == "table" then
      state.version = 1
      state.character = HEVO_KEYS[tostring(state.character or ""):upper()]
        and tostring(state.character):upper() or nil
      state.ready = state.ready == true
      state.oakCalled = state.oakCalled == true
      state.pendingCall = state.pendingCall == true
      state.doorAcknowledged = state.doorAcknowledged == true
    end
    return state
  end

  local function mirrorHevoGateFlags(save, state)
    save.flags = type(save.flags) == "table" and save.flags or {}
    save.flags[J.HEVO_READY_FLAG] = state and state.ready == true
      and true or nil
    save.flags[J.HEVO_OAK_CALLED_FLAG] = state
      and state.oakCalled == true and true or nil
  end

  -- A seal from this live save is the authority.  Active Legacy saves must
  -- prove completion in their current run; a global RED/BLUE/GREEN archive
  -- entry from an older cycle may never unlock another cycle by itself.
  function J.currentHevoSeal(save, requestedCharacter)
    local character = tostring(requestedCharacter
      or (J.activeCharacter and J.activeCharacter(save)) or ""):upper()
    if not HEVO_KEYS[character] then return false, nil end
    if J.activeCharacter and J.activeCharacter(save) ~= character then
      return false, character
    end
    local bucket = modBucket(save, false)
    local run = bucket and bucket.hevo_run
    local dungeon = type(run) == "table" and run.dungeonLegacy
    local seals = type(dungeon) == "table" and dungeon.seals
    if type(seals) == "table" and seals[character] == true then
      return true, character
    end
    local active = legacyState(save)
    if type(active) == "table" then
      return active.pathComplete == true, character
    end

    -- Original-run migration: the oldest accepted saves can predate both the
    -- run-local seal table and `hevo_persistent.meta`.  The archive completion
    -- bit is its durable seal authority; the separate matching shared-door
    -- visit remains mandatory before readiness is reconciled.
    local profile
    if type(archive.profile) == "function" then
      local ok, value = pcall(archive.profile)
      if ok then profile = value end
    end
    local completed = type(profile) == "table" and profile.completedPaths
    return type(completed) == "table"
      and completed[HEVO_KEYS[character]] == true, character
  end

  function J.currentHevoDoorVisit(save, requestedCharacter)
    local character = tostring(requestedCharacter
      or (J.activeCharacter and J.activeCharacter(save)) or ""):upper()
    if not HEVO_KEYS[character] then return false, nil end
    if J.activeCharacter and J.activeCharacter(save) ~= character then
      return false, character
    end
    local bucket = modBucket(save, false)
    local campaign = bucket and bucket.hidden_evolution_story_campaign
    local visits = type(campaign) == "table" and campaign.doorVisits
    return type(visits) == "table" and visits[character] == true, character
  end

  function J.reconcileHevoSealGate(save, migration)
    local existing = hevoGateState(save, false)
    local selected = J.activeCharacter and J.activeCharacter(save)
    if existing and existing.character and selected
        and existing.character ~= selected then
      existing.ready, existing.oakCalled, existing.pendingCall =
        false, false, false
      existing.doorAcknowledged = false
      mirrorHevoGateFlags(save, existing)
    end
    local sealed, character = J.currentHevoSeal(save)
    if not sealed then return false, "seal" end
    local visited = J.currentHevoDoorVisit(save, character)
    if not visited then return false, "door" end
    local state = hevoGateState(save, true)
    if state.character and state.character ~= character then
      -- Character changes before a path is sealed are legal.  A completed
      -- character's acknowledgement is not transferable to another avatar.
      state.ready, state.oakCalled, state.pendingCall = false, false, false
      state.doorAcknowledged = false
    end
    state.character = character
    state.doorAcknowledged = true
    state.ready = archive.isEligible(save) == true
    if migration == true and state.oakCalled ~= true
        and state.ready then
      state.pendingCall = true
      state.migrated = true
    end
    mirrorHevoGateFlags(save, state)
    if not state.ready then return false, "hall" end
    return true, character
  end

  function J.canBegin(save)
    if not archive.isEligible(save) then return false, "hall" end
    local state = hevoGateState(save, false)
    if not (state and state.ready) then return false, "seal" end
    local sealed, character = J.currentHevoSeal(save, state.character)
    if not sealed or character ~= state.character then return false, "seal" end
    if not J.currentHevoDoorVisit(save, character) then return false, "door" end
    return true, character
  end

  local function oakLegacyCallText(game, character)
    local player = game and game.save and game.save.player
      and game.save.player.name or character or "TRAINER"
    local paths = {
      RED = {
        trial = "GROUDON", colorEn = "RED", colorDe = "ROTER",
        partnerEn = "TORCHIC", partnerDe = "FLEMMLI",
      },
      BLUE = {
        trial = "KYOGRE", colorEn = "BLUE", colorDe = "BLAUER",
        partnerEn = "MUDKIP", partnerDe = "HYDROPI",
      },
      GREEN = {
        trial = "RAYQUAZA", colorEn = "GREEN", colorDe = "GRÜNER",
        partnerEn = "TREECKO", partnerDe = "GECKARBOR",
      },
    }
    local path = paths[character] or paths.RED
    return twoLinePages(tr(
      "PROF. OAK:\n" .. tostring(player) .. "!\f"
        .. path.trial .. " TRIAL:\nPASSED.\f"
        .. path.colorEn .. " FISSURE PATH:\nCOMPLETE.\f"
        .. "NEXT LEGACY TRIP:\n" .. path.partnerEn .. "\f"
        .. "It waits in the\nleft LAB ball.\f"
        .. "Come to my LAB.\nUse the KASC PC.\f"
        .. "It is at the\nupper-left.\f"
        .. "Choose LEGACY.\nNo reset yet.\f"
        .. "Read both reviews.\nEach starts on NO.\f"
        .. "Only the final YES\nstarts it.\f"
        .. "Then this run is\nsafely archived.\f"
        .. "Your new cycle\nstarts after that.",
      "PROF. EICH:\n" .. tostring(player) .. "!\f"
        .. path.trial .. "S PRÜFUNG:\nBESTANDEN.\f"
        .. path.colorDe .. " RISSPFAD:\nVOLLENDET.\f"
        .. "NÄCHSTE REISE:\n" .. path.partnerDe .. "\f"
        .. "Es wartet im\nlinken Labor-Ball.\f"
        .. "Komm in mein LABOR.\nNutze den KASC-PC.\f"
        .. "Er steht links oben.\f"
        .. "Wähle VERMÄCHTNIS.\nNoch kein Neustart.\f"
        .. "Prüfe beide Texte.\nVorgabe ist NEIN.\f"
        .. "Nur das letzte JA\nstartet den Wechsel.\f"
        .. "Dann wird der Lauf\nsicher archiviert.\f"
        .. "Danach beginnt dein\nneuer Zyklus."))
  end

  local function finishOakCall(game, state, done)
    state.pendingCall = false
    state.oakCalled = true
    oakCallInFlight = false
    mirrorHevoGateFlags(game.save, state)
    if game.writeSave then game:writeSave() end
    if done then done() end
  end

  function J.notifyHevoSeal(game, character, done)
    local save = game and game.save
    local sealed, active = J.currentHevoSeal(save, character)
    if not sealed or active ~= tostring(character or ""):upper() then
      if done then done() end
      return false, "seal"
    end
    if not J.currentHevoDoorVisit(save, active) then
      if done then done() end
      return false, "door"
    end
    local state = hevoGateState(save, true)
    state.character = active
    state.doorAcknowledged = true
    -- The shared-story controller persisted the visit before this callback.
    -- Never manufacture that authority here: adapter.finalize() and a direct
    -- Journey call are both intentionally too early.
    if not archive.isEligible(save) then
      state.ready = false
      mirrorHevoGateFlags(save, state)
      if game.writeSave then game:writeSave() end
      if done then done() end
      return true, "hall"
    end
    state.ready = true
    if state.oakCalled then
      if done then done() end
      return false, "already-called"
    end
    state.pendingCall = true
    mirrorHevoGateFlags(save, state)
    if game.writeSave and game:writeSave() == false then
      state.pendingCall = false
      mirrorHevoGateFlags(save, state)
      if done then done() end
      return false, "save"
    end
    if oakCallInFlight then return false, "call-pending" end
    oakCallInFlight = true
    local after = function() finishOakCall(game, state, done) end
    local shown = type(opts.onOakCall) == "function"
      and opts.onOakCall(game, oakLegacyCallText(game, active), after)
    if shown == false or shown == nil then
      pushMessage(game, oakLegacyCallText(game, active), after)
    end
    return true, "called"
  end

  function J.deliverPendingHevoCall(game, mapId)
    local save = game and game.save
    local state = hevoGateState(save, false)
    if not (state and state.pendingCall and not state.oakCalled)
        or oakCallInFlight then return false end
    -- A migrated save loaded inside a fissure gets the authored door sequence
    -- first.  Leaving the HEVO maps still catches the call up safely.
    if tostring(mapId or ""):match("^KA_HEVO_") then return false end
    return J.notifyHevoSeal(game, state.character)
  end

  local function monName(game, mon)
    local def = game.data.pokemon[mon.species]
    return mon.nickname or (def and def.name) or mon.species
  end

  local function itemName(game, id)
    local def = game.data.items[id]
    return (def and def.name) or id
  end

  -- Production asks legacy_archive for the authoritative classification.
  -- These explicit sets keep test doubles and older archive adapters safe;
  -- never infer "Key Item" from tossable=false alone because Ascendant's
  -- evolution tools deliberately share that flag.
  local UI_STORY_ITEM_IDS = {
    TOWN_MAP = true, BICYCLE = true, SURFBOARD = true,
    SAFARI_BALL = true, POKEDEX = true,
    OLD_AMBER = true, DOME_FOSSIL = true, HELIX_FOSSIL = true,
    SECRET_KEY = true, ITEM_2C = true, BIKE_VOUCHER = true,
    CARD_KEY = true, S_S_TICKET = true, GOLD_TEETH = true,
    COIN_CASE = true, OAKS_PARCEL = true, ITEMFINDER = true,
    SILPH_SCOPE = true, POKE_FLUTE = true, LIFT_KEY = true,
    OLD_ROD = true, GOOD_ROD = true, SUPER_ROD = true, EXP_ALL = true,
    SHINY_CHARM = true, ASCENDANT_EXP_MULTIPLIER = true,
    MIGRATION_RECEIVER = true, RESONANCE_SEAL = true,
    ASCENDANT_THUNDERHEART = true, ASCENDANT_THUNDER_TEAR = true,
  }
  local UI_COUNTED_NON_TOSSABLE_IDS = {
    PROTECTOR = true, MAGMARIZER = true, RAZOR_FANG = true,
    ELECTIRIZER = true, RAZOR_CLAW = true, DUBIOUS_DISC = true,
    SHINY_STONE = true, DUSK_STONE = true,
  }
  local UI_MEGA_STONE_IDS = {
    VENUSAURITE = true, CHARIZARDITE_X = true, CHARIZARDITE_Y = true,
    BLASTOISINITE = true, BEEDRILLITE = true, PIDGEOTITE = true,
    ALAKAZITE = true, SLOWBRONITE = true, GENGARITE = true,
    KANGASKHANITE = true, PINSIRITE = true, GYARADOSITE = true,
    AERODACTYLITE = true, MEWTWONITE_X = true, MEWTWONITE_Y = true,
    AMPHAROSITE = true, STEELIXITE = true, SCIZORITE = true,
    HERACRONITE = true, HOUNDOOMINITE = true, TYRANITARITE = true,
    BLAZIKENITE = true, SWAMPERTITE = true, SCEPTILITE = true,
    CLEFABLITE = true, VICTREEBELITE = true, STARMIENITE = true,
    DRAGONINITE = true, MEGANIUMITE = true, FERALIGATRITE = true,
    SKARMORITE = true, RAICHUNITE_X = true, RAICHUNITE_Y = true,
  }

  local function itemPolicy(game, id)
    if type(archive.classifyItem) == "function" then
      local policy = archive.classifyItem(id)
      if type(policy) == "table" then return policy end
    end
    local def = game and game.data and game.data.items
      and game.data.items[id] or nil
    local category = "consumable"
    if Bag.isBadge(id) then category = "badge"
    elseif id == "FIELD_KIT" then category = "field_kit"
    elseif id == "MEGA_RING" or id == "MEGA_STONE_CASE" then
      category = "mega_access"
    elseif UI_MEGA_STONE_IDS[id] then category = "mega_stone"
    elseif tostring(id):find("^HM_")
        or def and def.machine and def.machine.kind == "HM" then
      category = "hm"
    elseif UI_STORY_ITEM_IDS[id] then category = "key_item"
    elseif def and def.machine and def.machine.kind == "TM" then
      category = "tm"
    elseif def and def.tossable == false
        and not UI_COUNTED_NON_TOSSABLE_IDS[id] then
      category = "unknown"
    end
    return {
      id = id, category = category,
      transferable = category == "consumable" or category == "tm"
        or category == "mega_stone",
      claimMode = category == "mega_stone"
        and "unique_after_mega_access" or "counted",
    }
  end

  local function itemClaimStatus(game, id)
    if type(archive.itemClaimStatus) == "function" then
      local ready, reason, policy = archive.itemClaimStatus(game.save, id)
      return ready == true, reason, policy or itemPolicy(game, id)
    end
    local policy = itemPolicy(game, id)
    if not policy.transferable then return false, policy.category, policy end
    if policy.category == "mega_stone" then
      local mega = mod.exports and mod.exports.megaEvolution
      local state = mega and type(mega.state) == "function" and mega.state(false)
      local access = type(state) == "table"
        and (state.case == true or state.ring == true)
        or (tonumber(game.save.inventory
          and game.save.inventory.MEGA_STONE_CASE) or 0) > 0
      if not access then return false, "mega_access_required", policy end
      local owned = mega and type(mega.hasStone) == "function"
        and mega.hasStone(id) == true
      return true, owned and "already_owned" or "ready", policy
    end
    return true, "ready", policy
  end

  -- Both Gen-I stores use one-byte stack counts.  A counted Legacy receipt
  -- may fill the Bag first and then overflow into the Player PC, but neither
  -- destination may exceed 99 or allocate a new stack past its own slot cap.
  -- Probe Bag.add only on a detached inventory copy so capacity checks remain
  -- non-mutating across official, clientfix and current engine variants,
  -- including the pocket-aware Bag implementations.
  local ITEM_STACK_LIMIT = 99
  local DEFAULT_PC_ITEM_CAPACITY = 50

  local function shallowCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = child end
    return result
  end

  local function bagItemRoom(game, id)
    local save = game and game.save or nil
    local inventory = type(save and save.inventory) == "table"
      and save.inventory or nil
    if not inventory then return 0 end
    local held = math.max(0, math.floor(tonumber(inventory[id]) or 0))
    if inventory[id] ~= nil then
      return math.max(0, ITEM_STACK_LIMIT - held)
    end
    local probe = {
      inventory = shallowCopy(inventory),
      bagOrder = type(save.bagOrder) == "table"
        and shallowCopy(save.bagOrder) or nil,
    }
    local called, added = pcall(Bag.add, probe, id, 1,
      game and game.data)
    return called and added == true and ITEM_STACK_LIMIT or 0
  end

  local function pcItemRoom(game, id)
    local save = game and game.save or nil
    if not save or save.pcItems ~= nil
        and type(save.pcItems) ~= "table" then return 0 end
    local pc = save.pcItems or {}
    local held = math.max(0, math.floor(tonumber(pc[id]) or 0))
    if pc[id] ~= nil then
      return math.max(0, ITEM_STACK_LIMIT - held)
    end
    local stacks = 0
    for _ in pairs(pc) do stacks = stacks + 1 end
    local configured = game and game.data and game.data.field
      and tonumber(game.data.field.pcItemCap)
    local capacity = configured and math.max(1, math.floor(configured))
      or DEFAULT_PC_ITEM_CAPACITY
    return stacks < capacity and ITEM_STACK_LIMIT or 0
  end

  local function itemWithdrawalCapacity(game, id, available)
    available = math.max(0, math.floor(tonumber(available) or 0))
    local bagRoom = bagItemRoom(game, id)
    local pcRoom = pcItemRoom(game, id)
    return math.min(available, bagRoom + pcRoom), bagRoom, pcRoom
  end

  local function itemGrantPlan(game, id, requested, available)
    requested = math.max(0, math.floor(tonumber(requested) or 0))
    local maximum, bagRoom, pcRoom = itemWithdrawalCapacity(
      game, id, available)
    if requested < 1 or requested > maximum then
      return nil, "item quantity exceeds current Bag/PC capacity"
    end
    local bagCount = math.min(requested, bagRoom)
    local pcCount = requested - bagCount
    if pcCount > pcRoom then
      return nil, "item quantity exceeds current Player PC capacity"
    end
    return { bag = bagCount, pc = pcCount }
  end

  local HM_UNLOCKS = {
    HM_CUT = {
      "Receive CUT from the\nS.S. ANNE captain.",
      "Erhalte ZERSCHNEIDER vom\nKapitän der M.S. ANNE.",
    },
    HM_FLY = {
      "Find FLY in the house\nwest of ROUTE 16.",
      "Finde FLIEGEN im Haus\nwestlich von ROUTE 16.",
    },
    HM_SURF = {
      "Reach the Secret House\nin the SAFARI ZONE.",
      "Erreiche das Geheimhaus\nin der SAFARI-ZONE.",
    },
    HM_STRENGTH = {
      "Return GOLD TEETH to\nthe SAFARI warden.",
      "Bringe dem SAFARI-WÄRTER\ndie GOLDZÄHNE zurück.",
    },
    HM_FLASH = {
      "Show 10 caught species\nto Oak's ROUTE 2 aide.",
      "Zeige EICHS Assistent auf\nROUTE 2 zehn gefangene Arten.",
    },
  }

  local KEY_ITEM_UNLOCKS = {
    OAKS_PARCEL = {
      "Collect Oak's parcel at\nthe VIRIDIAN MART.",
      "Hole EICHS PAKET im\nVERTANIA-MARKT ab.",
    },
    TOWN_MAP = {
      "Get the map from DAISY\nafter Oak sends you out.",
      "Hole die KARTE bei SARAH,\nnachdem Eich Dich losschickt.",
    },
    S_S_TICKET = {
      "Help BILL on ROUTE 25\nto receive the ticket.",
      "Hilf BILL auf ROUTE 25,\num das Ticket zu erhalten.",
    },
    SILPH_SCOPE = {
      "Defeat GIOVANNI in the\nROCKET HIDEOUT.",
      "Besiege GIOVANNI im\nROCKET-VERSTECK.",
    },
    POKE_FLUTE = {
      "Rescue MR. FUJI in\nPOKéMON TOWER.",
      "Rette MR. FUJI im\nPOKéMON-TURM.",
    },
    SECRET_KEY = {
      "Find the key inside\nPOKéMON MANSION.",
      "Finde den Schlüssel im\nPOKéMON-HAUS.",
    },
    CARD_KEY = {
      "Find the CARD KEY on\nSILPH CO. 5F.",
      "Finde die KARTE in der\n5. ETAGE der SILPH CO.",
    },
    LIFT_KEY = {
      "Defeat its ROCKET guard\nin the CELADON hideout.",
      "Besiege den ROCKET-Wächter\nim PRISMANIA-Versteck.",
    },
    BICYCLE = {
      "Trade the BIKE VOUCHER\nat CERULEAN BIKE SHOP.",
      "Tausche den RAD-COUPON im\nAZURIA-RADLADEN ein.",
    },
    BIKE_VOUCHER = {
      "Hear the Fan Club chair\nin VERMILION CITY.",
      "Höre dem Fanclub-Chef in\nORANIA CITY zu.",
    },
    ITEMFINDER = {
      "Show 30 caught species\nto Oak's ROUTE 11 aide.",
      "Zeige EICHS Assistent auf\nROUTE 11 30 gefangene Arten.",
    },
    EXP_ALL = {
      "Show 50 caught species\nto Oak's ROUTE 15 aide.",
      "Zeige EICHS Assistent auf\nROUTE 15 50 gefangene Arten.",
    },
  }

  local function itemLockedHelp(game, id)
    local policy = itemPolicy(game, id)
    local name = itemName(game, id)
    local category = policy.category
    local function pages(text) return twoLinePages(text) end
    if category == "mega_stone" then
      local ready, reason = itemClaimStatus(game, id)
      if not ready and reason == "mega_access_required" then
        return pages(tr(
          ("%s is safe as one\nunique Legacy Stone."):format(name),
          ("%s liegt einmal sicher\nim Vermächtnis-Lager."):format(name))
          .. "\f" .. tr(
            "LOCKED: This journey\nhas no STONE CASE yet.",
            "GESPERRT: Dieser Lauf\nhat noch keinen STEIN-KOFFER.")
          .. "\f" .. tr(
            "After Hall of Fame use\nthe Route 5 Mega machine.",
            "Nutze nach der Ruhmeshalle\ndie Mega-Maschine auf Route 5."))
      end
      if reason == "already_owned" then
        return pages(tr(
          ("%s is already in\nyour STONE CASE."):format(name),
          ("%s liegt bereits in\nDeinem STEIN-KOFFER."):format(name))
          .. "\f" .. tr(
            "A clears the saved\nreceipt; no duplicate.",
            "A entfernt den Beleg;\nkein Duplikat entsteht."))
      end
      return pages(tr(
        ("%s is one unique\nLegacy Stone."):format(name),
        ("%s ist ein einmaliger\nVermächtnis-Stein."):format(name))
        .. "\f" .. tr(
          "A imports it into the\nactive STONE CASE once.",
          "A übernimmt ihn einmal\nin den aktiven STEIN-KOFFER."))
    end
    local intro = tr(
      ("%s is not a counted\nLegacy Locker item."):format(name),
      ("%s ist kein zählbares\nVermächtnis-Lager-Item."):format(name))
    if category == "hm" then
      local hint = HM_UNLOCKS[id]
      return pages(intro .. "\f" .. tr(
        "WHY: HMs are story\nreceipts for this run.",
        "GRUND: VMs gehören zur\nStory dieses Laufs.") .. "\f"
        .. (hint and tr(hint[1], hint[2]) or tr(
          ("Earn %s from its\ncurrent-run HM event."):format(name),
          ("Erhalte %s im\nVM-Event dieses Laufs."):format(name))))
    elseif category == "field_kit" then
      return pages(intro .. "\f" .. tr(
        "WHY: FIELD KIT is a\ncurrent-run milestone.",
        "GRUND: FELD-KIT ist eine\nMeilenstein-Belohnung.") .. "\f" .. tr(
        "Win one Trainer\nrematch to receive it.",
        "Gewinne eine Trainer-\nRevanche, um es zu erhalten."))
    elseif category == "mega_access" then
      return pages(intro .. "\f" .. tr(
        "WHY: Mega access belongs\nto this journey's story.",
        "GRUND: Mega-Zugang gehört\nzur Story dieser Reise.") .. "\f" .. tr(
        "Use the Route 5 Mega\nmachine after Hall of Fame.",
        "Nutze nach der Ruhmeshalle\ndie Mega-Maschine auf Route 5."))
    elseif category == "badge" then
      return pages(intro .. "\f" .. tr(
        "WHY: Badges prove this\njourney's Gym victories.",
        "GRUND: Orden belegen die\nArena-Siege dieses Laufs.") .. "\f" .. tr(
        "Defeat its Gym Leader\nin the current journey.",
        "Besiege den Arenaleiter\nin dieser Reise."))
    elseif category == "unknown" then
      local missing = policy.lockReason == "unregistered_item"
      return pages(intro .. "\f" .. (missing and tr(
        "WHY: Its item definition\nis not loaded.",
        "GRUND: Seine Item-Daten\nsind nicht geladen.") or tr(
        "WHY: This non-tossable\nitem is not reviewed.",
        "GRUND: Dieses feste Item\nist noch nicht geprüft.")) .. "\f"
        .. (missing and tr(
          "Enable or update the\nmod that owns this item.",
          "Aktiviere oder aktualisiere\ndie zugehörige Mod.") or tr(
          "Update KASC/content; it\nstays safe in quarantine.",
          "Aktualisiere KASC/Inhalt;\nes bleibt in Quarantäne.")))
    end
    local hint = KEY_ITEM_UNLOCKS[id]
    return pages(intro .. "\f" .. tr(
      "WHY: This Key Item must\ncome from the live story.",
      "GRUND: Dieses Basis-Item\nmuss aus der Story kommen.") .. "\f"
      .. (hint and tr(hint[1], hint[2]) or tr(
        ("Complete the event that\nawards %s."):format(name),
        ("Schließe das Event ab,\ndas %s vergibt."):format(name))))
  end

  local function monStorageDescription(game, item)
    local row = item and item.value
    local mon = type(row) == "table" and row.mon or nil
    if not mon then return tr("Archive has no capacity limit.",
      "Das Archiv hat kein Kapazitätslimit.") end
    local def = game.data.pokemon[mon.species] or {}
    local types = type(def.types) == "table" and table.concat(def.types, "/")
      or tr("UNKNOWN TYPE", "TYP UNBEKANNT")
    local status = row.withdrawBlocked and tr("LOCKED - SELECT: HELP",
      "GESPERRT - SELECT: HILFE") or tr("READY - A: WITHDRAW",
      "BEREIT - A: NEHMEN")
    return ("L%s  %s\n%s\n%s"):format(
      tostring(mon.level or "?"), types, status,
      tr("ARCHIVE UNLIMITED", "ARCHIV OHNE LIMIT"))
  end

  local function itemStorageDescription(game, item)
    local id = item and item.value
    if not id then return tr("Locker keeps exact item counts.",
      "Das Lager bewahrt exakte Itemzahlen.") end
    local ready, reason, policy = itemClaimStatus(game, id)
    if not ready then
      if reason == "mega_access_required" then
        return tr("LOCKED: STONE CASE NEEDED\nSELECT: WHY + UNLOCK",
          "GESPERRT: STEIN-KOFFER FEHLT\nSELECT: GRUND + FREIGABE")
      end
      return tr("LOCKED STORY RECEIPT\nSELECT: WHY + UNLOCK",
        "GESPERRTER STORY-BELEG\nSELECT: GRUND + FREIGABE")
    end
    if policy.category == "mega_stone" then
      return reason == "already_owned" and tr(
        "ALREADY IN STONE CASE\nA: CLEAR UNIQUE RECEIPT",
        "SCHON IM STEIN-KOFFER\nA: BELEG ENTFERNEN") or tr(
        "UNIQUE LEGACY STONE\nA: IMPORT  SELECT: HELP",
        "EINMALIGER VERMÄCHTNIS-STEIN\nA: IMPORT  SELECT: HILFE")
    end
    local help = mod.exports and mod.exports.itemHelp
    local detail = help and type(help.describe) == "function"
      and help.describe(game, id) or tr("Counted Legacy item.",
        "Gezähltes Vermächtnis-Item.")
    return detail .. "\n" .. tr("A: QUANTITY  SELECT: HELP",
      "A: MENGE  SELECT: HILFE")
  end

  local function monHelpText(game, row)
    if type(row) ~= "table" or type(row.mon) ~= "table" then return nil end
    local name = monName(game, row.mon)
    if row.withdrawBlocked then
      local reason = row.withdrawReason or tr(
        "This POKéMON is sealed\nby a current-run rule.",
        "Dieses POKéMON ist durch\neine Laufregel versiegelt.")
      return twoLinePages(reason .. "\f" .. tr(
        "BEFORE OAK'S PARTNER:\nchoose YES for JOHTO.",
        "VOR EICHS PARTNERWAHL:\nWähle JA für JOHTO.") .. "\f" .. tr(
        "If already declined:\nenter the Hall of Fame.",
        "Falls schon abgelehnt:\nBetritt die Ruhmeshalle.") .. "\f" .. tr(
        "Then speak to ELM'S AIDE\nin OAK'S LAB.",
        "Sprich dann mit LINDS\nAssistent in EICHS LABOR.") .. "\f" .. tr(
        ("%s remains safe; the\narchive has no limit."):format(name),
        ("%s bleibt sicher; das\nArchiv ist unbegrenzt."):format(name)))
    end
    return twoLinePages(tr(
      ("%s is ready for this\njourney."):format(name),
      ("%s ist für diese Reise\nbereit."):format(name)) .. "\f" .. tr(
      "Withdrawal is saved as\na recoverable lease.",
      "Die Entnahme wird als\nrettbare Leihe gespeichert.") .. "\f" .. tr(
      "The Legacy archive has\nno capacity limit.",
      "Das Vermächtnis-Archiv hat\nkein Kapazitätslimit."))
  end

  local function showMonHelp(game, item)
    local text = monHelpText(game, item and item.value)
    if text then pushMessage(game, text) end
  end

  local function showItemHelp(game, item, locker)
    local id = item and item.value
    if not id then return end
    local ready, _, policy = itemClaimStatus(game, id)
    if not ready or policy.category == "mega_stone" then
      pushMessage(game, itemLockedHelp(game, id))
      return
    end
    local help = mod.exports and mod.exports.itemHelp
    local detail = help and type(help.describe) == "function"
      and help.describe(game, id) or tr("Counted Legacy item.",
        "Gezähltes Vermächtnis-Item.")
    local available = type(locker) == "table"
      and type(locker.items) == "table" and locker.items[id] or 0
    local maximum = itemWithdrawalCapacity(game, id, available)
    local capacityText = maximum > 0 and tr(
        ("Choose 1-%d now. Bag\nfirst, then Player PC."):format(maximum),
        ("Wähle jetzt 1-%d. Erst\nBeutel, dann Spieler-PC."):format(maximum))
      or tr("No free Bag or Player\nPC item capacity remains.",
        "Kein freier Item-Platz in\nBeutel oder Spieler-PC.")
    pushMessage(game, detail .. "\f" .. capacityText
      .. "\f" .. tr(
        "Free Bag/PC space sets\nthe safe maximum.",
        "Freier Beutel-/PC-Platz\nsetzt die sichere Grenze.")
      .. "\f" .. tr(
        "B cancels unchanged. One\nsave-safe transaction follows.",
        "B bricht ohne Änderung ab.\nDanach folgt eine Transaktion."))
  end

  J.itemPolicy = itemPolicy
  J.itemLockedHelp = itemLockedHelp
  J.monHelpText = monHelpText

  local function daycareBlockerText(game)
    local save = game and game.save or {}
    local parents, eggs, seenParents, seenEggs = {}, {}, {}, {}
    local function speciesName(value)
      local mon = type(value) == "table" and (value.mon or value) or nil
      local species = type(mon) == "table" and mon.species
        or type(value) == "table" and value.species or value
      local def = game and game.data and game.data.pokemon
        and game.data.pokemon[species]
      return tostring(type(mon) == "table" and mon.nickname
        or def and def.name or species or "POKéMON")
    end
    local function add(list, seen, value)
      local name = speciesName(value)
      if not seen[name] then
        seen[name], list[#list + 1] = true, name
      end
    end

    if type(save.daycare) == "table" and type(save.daycare.mon) == "table" then
      add(parents, seenParents, save.daycare.mon)
    end
    local bucket = modBucket(save, false)
    local plus = type(bucket) == "table" and bucket.daycare_plus or nil
    if type(plus) == "table" then
      for _, row in pairs(type(plus.parents) == "table" and plus.parents or {}) do
        if type(row) == "table" and (type(row.mon) == "table" or row.species) then
          add(parents, seenParents, row)
        end
      end
      for _, row in pairs(type(plus.reservedEggs) == "table"
          and plus.reservedEggs or {}) do
        if type(row) == "table" and row.species then
          add(eggs, seenEggs, row)
        end
      end
    end

    local parts = { tr(
      "DAY-CARE BLOCKS\nTHE NEW CYCLE.",
      "PENSION BLOCKIERT\nDEN NEUEN ZYKLUS.") }
    if #parents > 0 then
      parts[#parts + 1] = tr("PARENTS TO COLLECT:\n", "ELTERN ABHOLEN:\n")
        .. table.concat(parents, ", ")
    end
    if #eggs > 0 then
      parts[#parts + 1] = tr("EGGS TO CLAIM:\n", "EIER ABHOLEN:\n")
        .. table.concat(eggs, ", ")
    end
    parts[#parts + 1] = tr(
      "Collect them from\nDAY-CARE PLUS / CARE.",
      "Hole sie aus\nDAY-CARE PLUS / PENSION.")
    parts[#parts + 1] = tr(
      "Save the game.\nChoose LEGACY again.",
      "Danach speichern.\nVERMÄCHTNIS neu wählen.")
    parts[#parts + 1] = tr(
      "Nothing was reset.",
      "Nichts wurde\nzurückgesetzt.")
    return twoLinePages(table.concat(parts, "\f"))
  end

  local function removeExact(list, wanted)
    for index, value in ipairs(list or {}) do
      if value == wanted then table.remove(list, index) return true end
    end
    return false
  end

  pushMessage = function(game, text, done)
    game.stack:push(newTextBox(game, text, done))
  end

  local function archiveUnavailableText()
    return twoLinePages(tr(
      "KASC STORAGE:\nNOT AVAILABLE.\fThe official archive\ncannot be opened.\fNothing changed.\nNo reset started.\fReload the game.\nIf this repeats,\fupdate the engine or\nrestore the archive.",
      "KASC-SPEICHER:\nNICHT VERFÜGBAR.\fDas offizielle Archiv\nlässt sich nicht öffnen.\fNichts geändert.\nKein Neustart.\fLade das Spiel neu.\nFalls es bleibt:\fEngine aktualisieren\noder Archiv prüfen."))
  end

  local function archiveMigrationText()
    return twoLinePages(tr(
      "ARCHIVE LINK:\nNOT VERIFIED.\fThis save and its\narchive do not match.\fNothing changed.\nNo reset started.\fUse the verified\nLegacy migration.\fOr restore the archive\nthat belongs here.",
      "ARCHIV-VERKNÜPFUNG:\nNICHT BESTÄTIGT.\fSpielstand und Archiv\npassen nicht sicher.\fNichts geändert.\nKein Neustart.\fNutze die geprüfte\nLegacy-Migration.\fOder stelle das hier\npassende Archiv wieder her."))
  end

  local function archiveFutureText()
    return twoLinePages(tr(
      "ARCHIVE VERSION:\nTOO NEW.\fA newer KASC version\ncreated this archive.\fInstall that version.\nNothing changed.",
      "ARCHIV-VERSION:\nZU NEU.\fEine neuere KASC-Version\nhat dieses Archiv erstellt.\fInstalliere diese Version.\nNichts wurde geändert."))
  end

  local function archiveBindingSaveText()
    return twoLinePages(tr(
      "ARCHIVE LINK:\nNOT SAVED.\fThe verified link could\nnot be stored.\fNothing changed.\nNo reset started.\fCheck free space, then\ntry LEGACY again.",
      "ARCHIV-VERKNÜPFUNG:\nNICHT GESPEICHERT.\fDie sichere Zuordnung\nließ sich nicht speichern.\fNichts geändert.\nKein Neustart.\fPrüfe freien Speicher.\nVersuche es erneut."))
  end

  -- A short-lived RC wrote a valid cycle-zero archive into the engine-owned
  -- playthrough scope before it knew how to stamp the matching save receipt.
  -- legacy_archive.lua owns the deliberately narrow proof/merge rule.  This
  -- UI layer supplies only the engine-issued context and makes the repaired
  -- receipt durable before any Journey summary or confirmation can open.
  local function adoptScopedBootstrap(game, originalReason)
    if storageBackendMode ~= "playthrough"
        or type(archive.adoptScopedBootstrap) ~= "function"
        or not (game and game.save and game.writeSave)
        or not (mod.storage and type(mod.storage.context) == "function") then
      return false, originalReason
    end
    local context, contextCode, contextMessage = mod.storage:context(game)
    if type(context) ~= "table" then
      return false, contextMessage or contextCode or originalReason
    end
    local bucket = modBucket(game.save, false)
    local hadBinding = type(bucket) == "table"
      and bucket.legacy_storage_binding ~= nil
    local oldBinding = hadBinding
      and archive.copy(bucket.legacy_storage_binding) or nil
    local hadOrigin = type(bucket) == "table"
      and bucket.legacy_fresh_origin ~= nil
    local oldOrigin = hadOrigin
      and archive.copy(bucket.legacy_fresh_origin) or nil
    local function restoreReceipts()
      local live = modBucket(game.save, false)
      if type(live) ~= "table" then return end
      live.legacy_storage_binding = hadBinding and oldBinding or nil
      live.legacy_fresh_origin = hadOrigin and oldOrigin or nil
    end

    local adopted, adoptReason =
      archive.adoptScopedBootstrap(game.save, context)
    if adopted ~= true then return false, adoptReason or originalReason end
    local verified, verifyReason = archive.lineageStatus(game.save)
    if verified ~= true then
      restoreReceipts()
      return false, verifyReason or adoptReason or originalReason
    end
    if game:writeSave() ~= true then
      restoreReceipts()
      return false, "binding-save"
    end
    return true, adoptReason or "scoped-bootstrap"
  end

  local function archiveAvailable(game)
    -- Injected/headless archive doubles predate the explicit capability bit;
    -- only a real `false` means no durable backend. Production always sets it.
    if archive.persistent ~= false and not storageBackendFailure then
      local ok, reason = true, nil
      if type(archive.lineageStatus) == "function" then
        ok, reason = archive.lineageStatus(game and game.save)
      end
      if storageBackendFailure then
        if mod.log and mod.log.error then
          mod.log:error("Legacy storage unavailable: "
            .. tostring(storageBackendFailure))
        end
        if game then pushMessage(game, archiveUnavailableText()) end
        return false
      end
      if ok then return true end
      if archive.readOnly ~= true and archive.futureVersion == nil then
        local adopted, adoptReason = adoptScopedBootstrap(game, reason)
        if adopted then return true end
        reason = adoptReason or reason
      end
      if mod.log and mod.log.error then
        mod.log:error("Legacy archive link blocked: " .. tostring(reason))
      end
      if game then
        pushMessage(game, reason == "binding-save"
          and archiveBindingSaveText()
          or (archive.readOnly == true or archive.futureVersion ~= nil)
            and archiveFutureText() or archiveMigrationText())
      end
      return false
    end
    if game then
      pushMessage(game, archiveUnavailableText())
    end
    return false
  end

  local function pushOakHostedMessage(game, text, done)
    local trainers = game and game.data and game.data.trainers or {}
    local oak = trainers[J.OAK_HOST_PORTRAIT]
    local path = oak and oak.pic
    local portrait
    if type(path) == "string" and path ~= "" then
      local okAssets, Assets = pcall(require, "src.render.Assets")
      if okAssets and Assets and Assets.resolve then path = Assets.resolve(path) end
      local okBox, PicBox = pcall(require, "src.ui.PicBox")
      if okBox and PicBox and PicBox.new then
        local okPortrait, value = pcall(PicBox.new, game, path, nil, {
          trueColor = oak.trueColor == true,
        })
        if okPortrait then
          portrait = value
          -- PicBox.new in stock 0.1.96 accepts only three arguments.  Older
          -- code passed a fourth `trueColor` options table which the engine
          -- silently discarded, so the approved full-colour Oak portrait was
          -- remapped through the active Game Boy/SGB palette.  The result was
          -- the broken grey/blue silhouette visible in the Legacy intro.
          -- Mark PicBox's 9x9-tile frame during its draw instead.  A state
          -- `sgbPalettes()` return value is the *exclusive* compositing zone
          -- list in 0.1.96; publishing only Oak's small rectangle therefore
          -- clipped the rest of the Lab and all but an 8px strip of TextBox.
          -- PaletteFX.markTrueColor is additive to the inherited zones, so the
          -- full screen remains visible while Oak alone bypasses remapping.
          if oak.trueColor == true and type(portrait) == "table" then
            portrait.trueColor = true
            local originalDraw = portrait.draw
            local okPalette, PaletteFX = pcall(require, "src.render.PaletteFX")
            if type(originalDraw) == "function" and okPalette and PaletteFX
                and type(PaletteFX.markTrueColor) == "function" then
              portrait.draw = function(self, ...)
                originalDraw(self, ...)
                PaletteFX.markTrueColor(6 * 8, 4 * 8, 9 * 8, 9 * 8)
              end
              portrait.kascTrueColorDrawMark = true
            end
            portrait.kascTrueColorPortrait = true
            portrait.kascPortraitClass = J.OAK_HOST_PORTRAIT
          end
          local hdImage = type(portrait) == "table"
            and loadOakHostHdImage() or nil
          if hdImage then
            local width, height = hdImage:getDimensions()
            portrait.kascLegacyOakFallbackImage = portrait.image
            portrait.kascLegacyOakHdImage = hdImage
            portrait.kascLegacyOakHdPath = J.OAK_HOST_HD_PORTRAIT
            portrait.kascLegacyOakHdSourceWidth = width
            portrait.kascLegacyOakHdSourceHeight = height
            -- PicBox keeps drawing its original frame and palette zone. Only
            -- suppress the low-resolution image when the HD source really
            -- loaded; a missing/corrupt asset therefore falls back safely.
            portrait.image = nil
          end
        end
      end
    end
    if portrait then game.stack:push(portrait) end
    pushMessage(game, text, function()
      -- TextBox pops itself before onDone. The transparent portrait is then
      -- exactly the top state; remove only that instance and leave every Lab
      -- or PC state below untouched.
      if portrait and game.stack:top() == portrait then game.stack:pop() end
      if done then done() end
    end)
    return portrait ~= nil
  end

  local function withdraw(game, row, list)
    local Boxes = require("src.pokemon.Boxes")
    local Party = require("src.pokemon.Party")
    local Stats = require("src.pokemon.Stats")
    local mon, err = archive.leaseMon(game.save, row.id)
    if not mon then
      list.footer = tr("BANK ERROR", "BANK-FEHLER") .. ": " .. tostring(err)
      return
    end

    local destination, boxNumber
    if #(game.save.party or {}) < Party.MAX then
      Stats.ensure(game.data.pokemon[mon.species], mon)
      table.insert(game.save.party, mon)
      destination = "party"
    else
      boxNumber = Boxes.deposit(game.save, mon)
      if boxNumber then destination = "box" end
    end
    if not destination then
      archive.releaseLease(game.save, row.id)
      list.footer = tr("PARTY AND BOXES FULL", "TEAM UND BOXEN VOLL")
      return
    end

    if not game:writeSave() then
      if destination == "party" then removeExact(game.save.party, mon)
      else removeExact(Boxes.ensure(game.save)[boxNumber], mon) end
      archive.releaseLease(game.save, row.id)
      list.footer = tr("SAVE FAILED", "SPEICHERN FEHLGESCHLAGEN")
      return
    end
    list:removeCurrent()
    list.footer = destination == "party"
      and tr("WITHDRAWN TO PARTY", "INS TEAM GENOMMEN")
      or tr("WITHDRAWN TO BOX ", "IN BOX ") .. tostring(boxNumber)
  end

  local function openWithdraw(game)
    local rows = {}
    for _, row in ipairs(archive.availableMons(game.save)) do
      local mon = row.mon
      rows[#rows + 1] = {
        label = monName(game, mon),
        right = row.withdrawBlocked
          and tr("SEALED", "VERSIEGELT")
          or "L" .. tostring(mon.level or "?"),
        value = row,
      }
    end
    if #rows == 0 then
      pushMessage(game, tr(
        "No POKéMON are waiting\nin the Legacy Bank.",
        "In der Vermächtnis-\nBank wartet kein POKéMON."))
      return
    end
    local list
    list = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("LEGACY BANK", "VERMÄCHTNIS-BANK"), rows, {
        messageBox = true,
        ascendantLayout = true,
        ascendantStyle = "firered-legacy-storage",
        ascendantStorageDescription = function(item)
          return monStorageDescription(game, item)
        end,
        footer = tr("A:TAKE SEL:HELP", "A:NEHM SEL:HILFE"),
        pageJump = true,
        onSelectKey = function(item) showMonHelp(game, item) end,
        onChoose = function(item)
          local row = item and item.value
          if not row then return end
          if row.withdrawBlocked then
            showMonHelp(game, item)
            return
          end
          game.stack:push(newTextBox(game, tr(
            ("Withdraw %s?"):format(monName(game, row.mon)),
            ("%s nehmen?"):format(monName(game, row.mon))), nil, {
              defaultNo = true,
              choice = function(yes)
                if yes then withdraw(game, row, list) end
              end,
            }))
        end,
      })
    game.stack:push(list)
  end

  local function depositPartyMon(game, item, list)
    if #(game.save.party or {}) <= 1 then
      list.footer = tr("KEEP ONE PARTY POKéMON", "EIN TEAM-POKéMON BEHALTEN")
      return
    end
    local mon = game.save.party[item.value]
    if not mon then return end
    local id, err = archive.stageDeposit(game.save, mon)
    if not id then list.footer = tostring(err) return end
    table.remove(game.save.party, item.value)
    if not game:writeSave() then
      table.insert(game.save.party, item.value, mon)
      list.footer = tr("SAVE FAILED", "SPEICHERN FEHLGESCHLAGEN")
      return
    end
    local completed, completeErr = archive.completeDeposit(game.save, id)
    if not completed then
      list.footer = tr("BANK WILL RECOVER ON LOAD", "BANK WIRD BEIM LADEN REPARIERT")
      mod.log:error("legacy deposit finalization failed: "
        .. tostring(completeErr))
      return
    end
    list:removeCurrent()
    list.footer = tr("DEPOSITED IN LEGACY BANK", "IN VERMÄCHTNIS-BANK ABGELEGT")
  end

  local function openDeposit(game)
    if #(game.save.party or {}) <= 1 then
      pushMessage(game, tr(
        "You must keep one\nPOKéMON in your party.",
        "Ein POKéMON muss\nim Team bleiben."))
      return
    end
    local rows = {}
    for index, mon in ipairs(game.save.party or {}) do
      rows[#rows + 1] = {
        label = monName(game, mon), right = "L" .. tostring(mon.level or "?"),
        value = index,
      }
    end
    local list
    list = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("DEPOSIT PARTY", "TEAM ABLEGEN"), rows, {
        messageBox = true,
        ascendantLayout = true,
        ascendantStyle = "firered-legacy-storage",
        ascendantStorageDescription = function(item)
          local mon = item and game.save.party[item.value]
          if not mon then return tr("Archive has no capacity limit.",
            "Das Archiv hat kein Kapazitätslimit.") end
          return tr(
            ("%s will remain available\nacross later journeys.\nARCHIVE UNLIMITED")
              :format(monName(game, mon)),
            ("%s bleibt für spätere\nReisen verfügbar.\nARCHIV OHNE LIMIT")
              :format(monName(game, mon)))
        end,
        footer = tr("A:STORE SEL:HELP", "A:ABLG SEL:HILFE"),
        onSelectKey = function(item)
          local mon = item and game.save.party[item.value]
          if not mon then return end
          pushMessage(game, tr(
            ("Deposit %s into the\nunlimited Legacy archive."):format(
              monName(game, mon)),
            ("Lege %s in das\nunbegrenzte Archiv."):format(
              monName(game, mon))) .. "\f" .. tr(
            "The staged deposit is\nsave-safe and recoverable.",
            "Die Ablage ist sicher\ngestuft und wiederherstellbar."))
        end,
        onChoose = function(item)
          if not item then return end
          game.stack:push(newTextBox(game, tr(
            ("Deposit %s?"):format(item.label),
            ("%s ablegen?"):format(item.label)), nil, {
              defaultNo = true,
              choice = function(yes)
                if yes then depositPartyMon(game, item, list) end
              end,
            }))
        end,
      })
    game.stack:push(list)
  end

  local function bankWithdrawToParty(game, row)
    local Party = require("src.pokemon.Party")
    local Stats = require("src.pokemon.Stats")
    game.save.party = type(game.save.party) == "table" and game.save.party or {}
    if #game.save.party >= Party.MAX then
      return false, tr("PARTY IS FULL", "TEAM IST VOLL")
    end
    local mon, err = archive.leaseMon(game.save, row and row.id)
    if not mon then return false, tostring(err) end
    Stats.ensure(game.data.pokemon[mon.species], mon)
    table.insert(game.save.party, mon)
    if not game:writeSave() then
      removeExact(game.save.party, mon)
      archive.releaseLease(game.save, row.id)
      return false, tr("SAVE FAILED", "SPEICHERN FEHLGESCHLAGEN")
    end
    return true
  end

  local function bankDepositFromParty(game, partyIndex, targetIndex)
    game.save.party = type(game.save.party) == "table" and game.save.party or {}
    if #game.save.party <= 1 then
      return false, tr("KEEP ONE IN PARTY", "EINS MUSS IM TEAM BLEIBEN")
    end
    local mon = game.save.party[partyIndex]
    if not mon then return false, tr("EMPTY SLOT", "LEERER PLATZ") end
    local id, err = archive.stageDeposit(game.save, mon)
    if not id then return false, tostring(err) end
    table.remove(game.save.party, partyIndex)
    if not game:writeSave() then
      table.insert(game.save.party, partyIndex, mon)
      return false, tr("SAVE FAILED", "SPEICHERN FEHLGESCHLAGEN")
    end
    local completed, completeErr = archive.completeDeposit(game.save, id)
    if not completed then
      if mod.log and mod.log.error then
        mod.log:error("legacy deposit finalization failed: "
          .. tostring(completeErr))
      end
      return false, tr("BANK WILL RECOVER ON LOAD",
        "BANK WIRD BEIM LADEN REPARIERT")
    end
    if type(archive.reorderAvailableMon) == "function" then
      local reordered, reorderErr = archive.reorderAvailableMon(
        game.save, id, targetIndex)
      if not reordered and mod.log and mod.log.error then
        mod.log:error("legacy bank visual reorder failed: "
          .. tostring(reorderErr))
      end
    end
    return true
  end

  local function openFireRedBank(game)
    local storage = mod.exports and mod.exports.modernStorageUi
    if not (storage and type(storage.newLegacyBankOrganizer) == "function"
        and type(storage.useFireRedPc) == "function"
        and storage.useFireRedPc(game)) then
      return false
    end
    local screen = storage.newLegacyBankOrganizer(game, {
      rows = function()
        return archive.availableMons(game.save)
      end,
      withdraw = function(row)
        return bankWithdrawToParty(game, row)
      end,
      showLocked = function(row)
        return showMonHelp(game, { value = row })
      end,
      deposit = function(partyIndex, targetIndex)
        return bankDepositFromParty(game, partyIndex, targetIndex)
      end,
      move = function(id, targetIndex)
        if type(archive.reorderAvailableMon) ~= "function" then
          return false, tr("BANK ORDER UNAVAILABLE",
            "BANK-REIHENFOLGE NICHT VERFÜGBAR")
        end
        return archive.reorderAvailableMon(game.save, id, targetIndex)
      end,
    })
    game.stack:push(screen)
    return true
  end

  local function itemLocked(game, id)
    return itemClaimStatus(game, id) ~= true
  end

  local function logLockerFailure(stage, err)
    if mod.log and type(mod.log.error) == "function" then
      mod.log:error("legacy item checkout " .. tostring(stage) .. " failed: "
        .. tostring(err))
    end
  end

  local function cancelItemCheckout(id)
    local called, cancelled, err = pcall(archive.cancelCheckout, id)
    if not called or cancelled ~= true then
      logLockerFailure("rollback", called and err or cancelled)
      return false
    end
    return true
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

  local function grantCountedItem(game, id, plan)
    local save = game and game.save
    local snapshot = itemStoreSnapshot(save, id)
    if plan.bag > 0 then
      local called, added = pcall(Bag.add, save, id, plan.bag, game.data)
      if not called or added ~= true then
        restoreItemStores(save, id, snapshot)
        return nil, called and "Bag capacity changed" or added
      end
    end
    if plan.pc > 0 then
      if save.pcItems == nil then save.pcItems = {} end
      if type(save.pcItems) ~= "table" then
        restoreItemStores(save, id, snapshot)
        return nil, "Player PC item storage is unavailable"
      end
      local held = math.max(0, math.floor(
        tonumber(save.pcItems[id]) or 0))
      if held + plan.pc > ITEM_STACK_LIMIT then
        restoreItemStores(save, id, snapshot)
        return nil, "Player PC item stack is full"
      end
      save.pcItems[id] = held + plan.pc
    end
    return snapshot
  end

  local function withdrawItem(game, id, count, plan, list, locker)
    local ready, _, policy = itemClaimStatus(game, id)
    if not ready then
      list.footer = tr("STORY ITEM: LOCKED", "STORY-ITEM: GESPERRT")
      return
    end
    count = math.max(1, math.floor(tonumber(count) or 1))
    local began, checkout, err = pcall(archive.beginItemCheckout,
      game.save, id, count, plan)
    if not began or not checkout then
      if not began then logLockerFailure("staging", checkout) end
      list.footer = began and tostring(err) or tr(
        "LOCKER STORAGE FAILED", "LAGER-SPEICHER FEHLER")
      return
    end
    local megaReceipt, storeSnapshot
    if policy.category == "mega_stone" then
      local mega = mod.exports and mod.exports.megaEvolution
      if not (mega and type(mega.importLegacyStone) == "function") then
        cancelItemCheckout(checkout.id)
        list.footer = tr("STONE CASE UNAVAILABLE", "STEIN-KOFFER NICHT BEREIT")
        return
      end
      local imported
      imported, megaReceipt, err = pcall(mega.importLegacyStone, id)
      if not imported or not megaReceipt then
        if not imported then logLockerFailure("Stone Case grant", megaReceipt) end
        cancelItemCheckout(checkout.id)
        list.footer = imported and tostring(err) or tr(
          "STONE CASE UNAVAILABLE", "STEIN-KOFFER NICHT BEREIT")
        return
      end
    else
      storeSnapshot, err = grantCountedItem(game, id, plan)
      if not storeSnapshot then
        cancelItemCheckout(checkout.id)
        list.footer = tr("BAG + PC CAPACITY CHANGED",
          "BEUTEL-/PC-PLATZ GEÄNDERT")
        return
      end
    end
    local writeCalled, wrote = pcall(game.writeSave, game)
    if not writeCalled or wrote ~= true then
      if megaReceipt then
        local rolled, rollbackErr = pcall(
          mod.exports.megaEvolution.rollbackLegacyStone, megaReceipt)
        if not rolled then logLockerFailure("Stone Case rollback", rollbackErr) end
      else
        restoreItemStores(game.save, id, storeSnapshot)
      end
      cancelItemCheckout(checkout.id)
      if not writeCalled then logLockerFailure("game write", wrote) end
      list.footer = tr("SAVE FAILED", "SPEICHERN FEHLGESCHLAGEN")
      return
    end
    local finalized, completed, completeErr = pcall(
      archive.completeCheckout, game.save, checkout.id)
    if not finalized or not completed then
      logLockerFailure("finalization", finalized and completeErr or completed)
      list.footer = tr("LOCKER WILL RECOVER ON LOAD", "LAGER WIRD BEIM LADEN REPARIERT")
      return
    end
    local left = math.max(0, math.floor(
      tonumber(locker.items[id]) or 0) - count)
    locker.items[id] = left > 0 and left or nil
    if left <= 0 then list:removeCurrent()
    else list.items[list.index].right = "x" .. tostring(left) end
    list.footer = tr("WITHDRAWN x", "GENOMMEN x") .. tostring(count)
      .. ": " .. itemName(game, id)
  end

  local function wideQuantityBox(game, maximum, onDone)
    local QuantityBox = require("src.ui.QuantityBox")
    local box = QuantityBox.new(game, { max = maximum, onDone = onDone })
    if maximum > ITEM_STACK_LIMIT then
      -- The engine selector is laid out for two digits.  Bag + Player-PC
      -- capacity can legitimately reach 198, so widen only this instance;
      -- update/cancel/confirm behavior remains the engine's own implementation.
      local Font = require("src.render.Font")
      local digits = #tostring(maximum)
      function box:draw()
        local tw = digits + 3
        local tx, ty = 20 - tw, 9
        Font.drawBox(tx, ty, tw, 3)
        love.graphics.setColor(0, 0, 0, 1)
        local format = "×%0" .. tostring(digits) .. "d"
        Font.draw(format:format(self.qty), (tx + 1) * 8, (ty + 1) * 8)
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
    return box
  end

  local function openLockerItems(game, locker)
    local rows = {}
    locker = type(locker) == "table" and locker or { items = {}, money = 0 }
    locker.items = type(locker.items) == "table" and locker.items or {}
    local ids = {}
    for id, count in pairs(locker.items or {}) do
      if count > 0 then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b)
      return itemName(game, a) < itemName(game, b)
    end)
    for _, id in ipairs(ids) do
      rows[#rows + 1] = {
        label = itemName(game, id),
        right = itemLocked(game, id) and tr("LOCK", "SPERR")
          or ("x" .. tostring(locker.items[id])),
        value = id,
      }
    end
    if #rows == 0 then
      pushMessage(game, tr("The Legacy Locker is empty.",
        "Das Vermächtnis-Lager ist leer."))
      return
    end
    local list
    list = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("LEGACY ITEMS", "VERMÄCHTNIS-ITEMS"), rows, {
        messageBox = true,
        ascendantLayout = true,
        ascendantStyle = "firered-legacy-storage",
        ascendantStorageDescription = function(item)
          return itemStorageDescription(game, item)
        end,
        footer = tr("A:QTY SEL:HELP", "A:MENGE SEL:HILFE"),
        pageJump = true,
        onSelectKey = function(item) showItemHelp(game, item, locker) end,
        onChoose = function(item)
          if not item then return end
          if itemLocked(game, item.value) then
            showItemHelp(game, item, locker)
            return
          end
          local _, _, policy = itemClaimStatus(game, item.value)
          if policy.category == "mega_stone" then
            withdrawItem(game, item.value, 1, nil, list, locker)
            return
          end
          local available = tonumber(locker.items[item.value]) or 0
          local maximum = itemWithdrawalCapacity(game, item.value, available)
          if maximum < 1 then
            list.footer = tr("BAG + PLAYER PC FULL",
              "BEUTEL + SPIELER-PC VOLL")
            return
          end
          list.footer = tr(
            ("CHOOSE 1-%d  B:CANCEL"):format(maximum),
            ("WÄHLE 1-%d  B:ZURÜCK"):format(maximum))
          game.stack:push(wideQuantityBox(game, maximum, function(quantity)
            if not quantity then
              list.footer = tr("A:QTY SEL:HELP", "A:MENGE SEL:HILFE")
              return
            end
            local grant, grantErr = itemGrantPlan(game, item.value,
              quantity, locker.items[item.value])
            if not grant then
              logLockerFailure("capacity validation", grantErr)
              list.footer = tr("BAG + PLAYER PC FULL",
                "BEUTEL + SPIELER-PC VOLL")
              return
            end
            withdrawItem(game, item.value, quantity, grant, list, locker)
          end))
        end,
      })
    game.stack:push(list)
  end

  local function withdrawMoney(game, amount, list)
    local checkout, err = archive.beginMoneyCheckout(game.save, amount)
    if not checkout then list.footer = tostring(err) return end
    game.save.money = (tonumber(game.save.money) or 0) + amount
    if not game:writeSave() then
      game.save.money = game.save.money - amount
      archive.cancelCheckout(checkout.id)
      list.footer = tr("SAVE FAILED", "SPEICHERN FEHLGESCHLAGEN")
      return
    end
    local ok, completeErr = archive.completeCheckout(game.save, checkout.id)
    if not ok then
      mod.log:error("legacy money checkout finalization failed: "
        .. tostring(completeErr))
    end
    list.footer = tr("WITHDRAWN ¥", "GENOMMEN ¥") .. tostring(amount)
    local left = archive.locker().money
    if left <= 0 then list:close() end
  end

  local function openLockerMoney(game)
    local money = archive.locker().money
    if money <= 0 then
      pushMessage(game, tr("No Legacy money is stored.",
        "Kein Vermächtnis-Geld gelagert."))
      return
    end
    local rows, seen = {}, {}
    for _, amount in ipairs({ 1000, 10000, money }) do
      amount = math.min(amount, money)
      if amount > 0 and not seen[amount] then
        seen[amount] = true
        rows[#rows + 1] = { label = "¥" .. tostring(amount), value = amount }
      end
    end
    local list
    list = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("LEGACY MONEY", "VERMÄCHTNIS-GELD"), rows, {
        messageBox = true,
        ascendantLayout = true,
        ascendantStyle = "firered-storage",
        onChoose = function(item)
          if item then withdrawMoney(game, item.value, list) end
        end,
      })
    game.stack:push(list)
  end

  function J.bankAccess(save)
    if type(archive.bankAccess) == "function" then
      return archive.bankAccess(save)
    end
    local state = legacyState(save)
    return type(state) == "table" and state.bankUnlocked == true,
      state and "compat" or "inactive",
      state and bankPolicyId(state.bankPolicy, state.pact) or nil,
      state and pactId(state.pact) or nil
  end

  function J.bankPolicyHint(save)
    local allowed, why, policy, pact = J.bankAccess(save)
    if not policy then
      return twoLinePages(tr(
        "LEGACY BANK:\nNO ACTIVE JOURNEY.",
        "VERMÄCHTNIS-BANK:\nKEINE AKTIVE REISE."))
    end
    local heading = tr(
      ("PACT:\n%s\fBANK RULE:\n%s"):format(J.pactName(pact),
        J.bankPolicyName(policy, pact)),
      ("PAKT:\n%s\fBANKREGEL:\n%s"):format(J.pactName(pact),
        J.bankPolicyName(policy, pact)))
    if allowed then
      return twoLinePages(heading .. "\f" .. tr(
        "BANK + LOCKER:\nOPEN.",
        "BANK + LAGER:\nGEÖFFNET."))
    end
    local reason = why == "partner" and tr(
        "NEW PARTNER:\nNOT RECEIVED.\fOak must give you the\npartner first.",
        "NEUER PARTNER:\nNOCH NICHT ERHALTEN.\fEich muss ihn dir\nzuerst übergeben.")
      or why == "badges4" and tr(
        "BANK LOCKED:\nFOUR BADGES NEEDED.\fThey must come from\nthis journey.",
        "BANK GESPERRT:\nVIER ORDEN NÖTIG.\fSie müssen aus dieser\nReise stammen.")
      or why == "league_required" and tr(
        "BANK LOCKED:\nHALL ENTRY NEEDED.\fEnter this journey's\nHall of Fame first.",
        "BANK GESPERRT:\nRUHMESHALLE NÖTIG.\fBetritt zuerst die\nHalle dieser Reise.")
      or why == "sealed" and tr(
        "BANK SEALED:\nTHIS ENTIRE JOURNEY.",
        "BANK VERSIEGELT:\nDIESE GANZE REISE.")
      or tr("LEGACY BANK:\nSTILL LOCKED.",
        "VERMÄCHTNIS-BANK:\nNOCH GESPERRT.")
    return twoLinePages(heading .. "\f" .. reason)
  end

  function J.openLocker(game)
    if not J.bankAccess(game and game.save) then
      pushMessage(game, J.bankPolicyHint(game and game.save))
      return false
    end
    bindArchiveData(game and game.data)
    local read, locker, lockerErr = pcall(archive.locker)
    if not read or type(locker) ~= "table" or lockerErr then
      logLockerFailure("screen load", read and lockerErr or locker)
      pushMessage(game, tr(
        "Legacy Locker could not\nbe read. Nothing changed.",
        "Vermächtnis-Lager nicht\nlesbar. Nichts geändert."))
      return false
    end
    locker.items = type(locker.items) == "table" and locker.items or {}
    locker.money = math.max(0, math.floor(tonumber(locker.money) or 0))
    local rows = {
      {
        label = tr("WITHDRAW ITEMS", "ITEMS NEHMEN"),
        -- Reuse this compact snapshot when entering the item list.  The old
        -- path decoded and normalized the complete Pokémon archive twice on
        -- adjacent input frames, which explains a short pre-screen stall on
        -- very large lineages. Successful withdrawals update the snapshot
        -- locally after the durable archive finalization.
        onSelect = function() openLockerItems(game, locker) end,
      },
      {
        label = tr("WITHDRAW MONEY", "GELD NEHMEN"),
        right = "¥" .. tostring(locker.money or 0),
        onSelect = function() openLockerMoney(game) end,
      },
    }
    game.stack:push((mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("LEGACY LOCKER", "VERMÄCHTNIS-LAGER"), rows, {
        ascendantStyle = "firered-storage",
        onChoose = function(item)
          if item and item.onSelect then item.onSelect() end
        end,
      }))
  end

  function J.openBank(game)
    if not J.bankAccess(game and game.save) then
      pushMessage(game, J.bankPolicyHint(game and game.save))
      return false
    end
    bindArchiveData(game and game.data)
    archive.reconcileLeases(game.save)
    if openFireRedBank(game) then return true end
    local available = #archive.availableMons(game.save)
    local rows = {
      {
        label = tr("WITHDRAW POKéMON", "POKéMON NEHMEN"),
        right = tostring(available),
        onSelect = function() openWithdraw(game) end,
      },
      {
        label = tr("DEPOSIT PARTY", "TEAM ABLEGEN"),
        onSelect = function() openDeposit(game) end,
      },
      {
        label = tr("LEGACY LOCKER", "VERMÄCHTNIS-LAGER"),
        onSelect = function() J.openLocker(game) end,
      },
    }
    game.stack:push((mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("LEGACY BANK", "VERMÄCHTNIS-BANK"), rows, {
        ascendantStyle = "firered-storage",
        onChoose = function(item)
          if item and item.onSelect then item.onSelect() end
        end,
      }))
  end

  -- An active Legacy cycle owns a durable Bank, so its access belongs under
  -- the player's PC on every map (bedroom, Pokémon Center, and equivalent
  -- engine entry points).  Starting/configuring a new cycle deliberately
  -- remains exclusive to Oak's KASC terminal: inactive saves receive no row
  -- here and this hook never calls J.begin or the ASC-Run rules UI.
  mod.hooks:wrap("ui.player_pc.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" then return out end
    if type(legacyState(game and game.save)) ~= "table" then return out end

    -- Fail safely across a hot reload or another cooperative wrapper: one
    -- logical Legacy subcategory is enough, regardless of how the PC opened.
    for _, item in ipairs(out) do
      if item and item.value == "kasc_legacy_bank" then return out end
    end
    out[#out + 1] = {
      label = tr("LEGACY BANK", "VERMÄCHTNIS"),
      value = "kasc_legacy_bank",
      keepOpen = true,
      onSelect = function()
        if J.bankAccess(game and game.save) then
          J.openBank(game)
        else
          pushMessage(game, J.bankPolicyHint(game and game.save))
        end
      end,
    }
    return out
  end, 40)

  local function pushOakIntro(game, onDone)
    local Screens = require("src.ui.Screens")
    local screenIds = game.data and game.data.field and game.data.field.boot
      and game.data.field.boot.screens or {}
    Screens.push(game, screenIds.newGame or "OakSpeech", onDone or function() end)
  end

  function J.legacyPrologueText(save)
    local character = (J.activeCharacter and J.activeCharacter(save)) or "RED"
    local player = save and save.player or {}
    local playerName = tostring(player.name or character):upper()
    local rivalName = tostring(player.rival or tr("BLUE", "BLAU")):upper()
    local female = character == "GREEN"
    local subjectEn, possessiveEn = female and "SHE" or "HE",
      female and "HER" or "HIS"
    local subjectDe, possessiveDe = female and "SIE" or "ER",
      female and "IHR" or "SEIN"
    return twoLinePages(tr(
      ("%s / %s\nTURNS 10 TODAY.\f%s HURRIES TO\nPROF. OAK'S LAB."
        .. "\fTO RECEIVE %s\nFIRST POKéMON.\f%s GOT THERE FIRST\nAND CLAIMS A POKé BALL...")
        :format(character, playerName, subjectEn, possessiveEn, rivalName),
      ("%s / %s\nWIRD HEUTE 10.\f%s EILT IN\nPROF. EICHS LABOR."
        .. "\fUM %s ERSTES\nPOKéMON ZU ERHALTEN.\f%s WAR SCHNELLER\nUND NIMMT EINEN POKéBALL...")
        :format(character, playerName, subjectDe, possessiveDe, rivalName)))
  end

  -- Legacy Fresh Save still uses the real OakSpeech identity flow so the
  -- chosen avatar, player name and rival name remain engine-authoritative.
  -- Add one white, portrait-free story card only after those choices are
  -- known and immediately before the normal shrink into Oak's Lab.
  mod.hooks:wrap("intro.oak_speech.build", function(nextBuild, steps, speech)
    steps = nextBuild(steps, speech)
    local save = speech and speech.game and speech.game.save
    local run = legacyState(save)
    if type(run) ~= "table" or type(run.runId) ~= "string"
        or run.runId == "" or run.introPhase ~= "identity"
        or run.labLocked ~= true then return steps end
    for _, step in ipairs(steps or {}) do
      if step.id == "legacy_fresh_chapter_card" then return steps end
    end
    local chapter = {
      id = "legacy_fresh_chapter_card",
      kind = "fn",
      run = function(activeSpeech, done)
        local liveSave = activeSpeech and activeSpeech.game
          and activeSpeech.game.save
        local liveRun = legacyState(liveSave)
        if type(liveRun) ~= "table" or liveRun.introPhase ~= "identity" then
          return done()
        end
        local oldPic, oldFlip, oldTrueColor = activeSpeech.pic,
          activeSpeech.picFlip, activeSpeech.picTrueColor
        activeSpeech.pic, activeSpeech.picFlip,
          activeSpeech.picTrueColor = nil, false, false
        activeSpeech:sayText(J.legacyPrologueText(liveSave), function()
          activeSpeech.pic, activeSpeech.picFlip,
            activeSpeech.picTrueColor = oldPic, oldFlip, oldTrueColor
          done()
        end)
      end,
    }
    local inserted = false
    for index, step in ipairs(steps or {}) do
      if step.id == "shrink" then
        table.insert(steps, index, chapter)
        inserted = true
        break
      end
    end
    if not inserted then steps[#steps + 1] = chapter end
    return steps
  end, 4500)

  local function stageFreshLab(save, phase)
    local state = legacyState(save)
    if type(state) ~= "table" then return false end
    state.introPhase = phase or state.introPhase or "identity"
    state.labLocked = state.introPhase ~= "complete"
    save.player = type(save.player) == "table" and save.player or {}
    save.player.map, save.player.x, save.player.y, save.player.facing =
      J.OAK_HOST_MAP, 5, 5, "up"
    save.flags = type(save.flags) == "table" and save.flags or {}
    save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
    save.flags.EVENT_FOLLOWED_OAK_INTO_LAB_2 = true
    save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON = true
    -- EVENT_GOT_STARTER remains false until the partner + rival contract has
    -- been durably committed by legacy_starters.lua.
    if state.partnerChosen ~= true then save.flags.EVENT_GOT_STARTER = nil end
    save.objectToggles = type(save.objectToggles) == "table"
      and save.objectToggles or {}
    local lab = type(save.objectToggles[J.OAK_HOST_MAP]) == "table"
      and save.objectToggles[J.OAK_HOST_MAP] or {}
    save.objectToggles[J.OAK_HOST_MAP] = lab
    -- Reuse the imported professor and single edition-authored ball layout.
    -- No object is spawned or recoloured; the door Oak remains hidden because
    -- the ordinary Pallet escort is deliberately skipped in Legacy Fresh Save.
    lab.OAKSLAB_OAK1 = true
    lab.OAKSLAB_OAK2 = false
    return true
  end

  -- A title carried into a fresh cycle belongs to the edition archive, not to
  -- either of the two save-local display caches.  Reading the durable owner
  -- here prevents a stale/foreign local title from being staged and also
  -- keeps the post-battle receipt independently verifiable after reload.
  local function archivedSelectedTitle()
    if type(archive.profile) ~= "function" then return nil end
    local ok, profile = pcall(archive.profile)
    local titles = ok and type(profile) == "table" and profile.titles or nil
    local selected = type(titles) == "table" and titles.selectedTitle or nil
    return type(selected) == "string" and selected ~= "" and selected or nil
  end

  local function knownHallSchema(hall)
    if type(hall) ~= "table" then return false end
    return math.max(1, math.floor(tonumber(hall.version) or 1)) <= 1
  end

  local function stageArchivedTitleForRival(save)
    local run = legacyState(save)
    local bucket = type(save and save.modData) == "table"
      and save.modData[mod.id]
    if type(run) ~= "table" or type(bucket) ~= "table" then return false end
    local ascendant = type(bucket.ascendant) == "table" and bucket.ascendant
    local hall = type(bucket.legacy_hall) == "table" and bucket.legacy_hall
    local selected = archivedSelectedTitle()
    if not selected then return false end
    run.archivedTitlePending = selected
    run.archivedTitleRestored = nil
    if ascendant then ascendant.selectedTitle = nil end
    -- A newer Gallery schema is deliberately opaque to this build.  The
    -- known Ascendant cache can still be hidden/restored, but the foreign
    -- table remains byte-for-byte untouched for forward save compatibility.
    if knownHallSchema(hall) then hall.selectedTitle = nil end
    return true
  end

  function J.restoreArchivedTitleAfterLabRival(save)
    local run = legacyState(save)
    if type(run) ~= "table" or run.partnerChosen ~= true
        or not (save and save.flags
          and save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB == true)
        or type(run.archivedTitlePending) ~= "string" then return false end
    if archivedSelectedTitle() ~= run.archivedTitlePending then
      return false
    end
    local bucket = type(save.modData) == "table" and save.modData[mod.id]
    if type(bucket) ~= "table" then return false end
    bucket.ascendant = type(bucket.ascendant) == "table"
      and bucket.ascendant or {}
    bucket.ascendant.selectedTitle = run.archivedTitlePending
    if type(bucket.legacy_hall) ~= "table" then
      bucket.legacy_hall = { version = 1 }
    end
    if knownHallSchema(bucket.legacy_hall) then
      bucket.legacy_hall.selectedTitle = run.archivedTitlePending
    end
    run.archivedTitleRestored = run.archivedTitlePending
    run.archivedTitlePending = nil
    return true
  end

  -- The Lab script owns the exact end of the first rival battle.  Restore the
  -- archived title at that boundary, rather than waiting for an arbitrary
  -- later movement event.  The world.stepped listener below remains only as
  -- a power-loss/hot-upgrade recovery seam for saves whose battle flag was
  -- already committed before this receipt existed.
  function J.onLabRivalResolved(game)
    local save = game and game.save
    local run = legacyState(save)
    local pending = type(run) == "table" and run.archivedTitlePending or nil
    local bucket = type(save and save.modData) == "table"
      and save.modData[mod.id]
    local hadAscendant = type(bucket and bucket.ascendant) == "table"
    local hadHall = type(bucket and bucket.legacy_hall) == "table"
    local oldAscendant = type(bucket and bucket.ascendant) == "table"
      and bucket.ascendant.selectedTitle or nil
    local oldHall = type(bucket and bucket.legacy_hall) == "table"
      and bucket.legacy_hall.selectedTitle or nil
    if not (game and J.restoreArchivedTitleAfterLabRival(save)) then
      return false
    end
    if game.writeSave and game:writeSave() == false then
      run.archivedTitlePending = pending
      run.archivedTitleRestored = nil
      if hadAscendant then
        bucket.ascendant.selectedTitle = oldAscendant
      else
        bucket.ascendant = nil
      end
      if hadHall then
        bucket.legacy_hall.selectedTitle = oldHall
      else
        bucket.legacy_hall = nil
      end
      return false
    end
    pushMessage(game, tr(
      "Your archived title\nis active again.",
      "Dein Archivtitel\nist wieder aktiv."))
    return true
  end

  function J.enterFreshLab(game)
    local save = game and game.save
    if not stageFreshLab(save, "partner") then return false end
    local ow = game.overworld
    if ow and ow.map and ow.map.id ~= J.OAK_HOST_MAP
        and type(ow.startWarpTo) == "function" then
      ow:startWarpTo(J.OAK_HOST_MAP, 5, 5, "up", function()
        if game.writeSave then game:writeSave() end
      end, { keepMusic = false })
    elseif game.writeSave then
      game:writeSave()
    end
    return true
  end

  function J.startFreshGame(game)
    activeGame = game or activeGame
    local SaveData = require("src.core.SaveData")
    local Runtime = require("src.mods.Runtime")
    local OverworldState = require("src.world.OverworldController")
    local sourceSave = game.save
    freshSeedFailure = nil
    local fresh = SaveData.newGame(game:bootConfig())
    local seedErr = freshSeedFailure
    freshSeedFailure = nil
    local state = legacyState(fresh)
    local hasHandoff = type(archive.hasHandoff) == "function"
      and archive.hasHandoff(fresh)
    if type(state) ~= "table" or type(state.runId) ~= "string"
        or state.runId == "" or not hasHandoff then
      return nil, seedErr or storageBackendFailure
        or "target Legacy lineage handoff could not be staged"
    end
    if not stageFreshLab(fresh, "identity") then
      return nil, "target Legacy Lab state could not be staged"
    end
    stageArchivedTitleForRival(fresh)
    while game.stack:top() do game.stack:pop() end
    game.save = fresh
    game:adoptSave(fresh)
    Runtime.emit("save.created", { save = fresh })
    game:applyOptions(fresh.options)
    game.stack:push(OverworldState, fresh.player.map,
      fresh.player.x, fresh.player.y, fresh.player.facing)
    -- Persist the resumable identity phase before any selector is shown.  A
    -- power loss therefore reloads the same locked Lab and restarts Oak's
    -- identity sequence instead of dropping the player into a bedroom.
    if game.writeSave and game:writeSave() == false then
      if type(game.restoreSave) == "function" then
        game:restoreSave(sourceSave, false, { freshBoot = true })
      else
        game.save = sourceSave
        if type(game.adoptSave) == "function" then game:adoptSave(sourceSave) end
      end
      return nil, "target Legacy playthrough could not be committed"
    end
    pushOakIntro(game, function() J.enterFreshLab(game) end)
    return fresh
  end

  function J.resumeFreshLab(game, save)
    game, save = game or activeGame, save or (game and game.save)
    local state = legacyState(save)
    if type(state) ~= "table" or state.partnerChosen == true then return false end
    local phase = state.introPhase == "identity" and "identity" or "partner"
    stageFreshLab(save, phase)
    if not (game and game.save == save and game.overworld) then return true end
    local function arrived()
      if game.writeSave then game:writeSave() end
      if phase == "identity" then
        local top = game.stack and game.stack:top()
        if not (top and top.screenId == "OakSpeech") then
          pushOakIntro(game, function() J.enterFreshLab(game) end)
        end
      end
    end
    local ow = game.overworld
    if not (ow.map and ow.map.id == J.OAK_HOST_MAP
        and ow.player and ow.player.cellX == 5 and ow.player.cellY == 5)
        and type(ow.startWarpTo) == "function" then
      ow:startWarpTo(J.OAK_HOST_MAP, 5, 5, "up", arrived,
        { keepMusic = false })
    else
      arrived()
    end
    return true
  end

  function J.begin(game)
    -- Stop before opening the reset flow whenever the selected official
    -- storage backend cannot prove the active lineage. No reset hook follows.
    if not archiveAvailable(game) then return false end
    local ready = J.canBegin(game and game.save)
    if not ready then
      pushMessage(game, J.storyGateHint(game and game.save))
      return false
    end
    local registryOk, registryErr = bindArchiveData(game and game.data)
    if not registryOk then
      if mod.log and mod.log.error then
        mod.log:error("Legacy registry validation failed: "
          .. tostring(registryErr))
      end
      pushMessage(game, tr(
        "LEGACY DATA:\nCHECK FAILED.\fNothing changed.\nNo reset started.",
        "VERMÄCHTNISDATEN:\nPRÜFUNG FEHLERHAFT.\fNichts geändert.\nKein Neustart."))
      return false
    end
    local summary, summaryErr = archive.summary(game.save)
    if type(summary) ~= "table" or summary.readOnly
        or summary.nextCycle == nil then
      if mod.log and mod.log.error then
        mod.log:error("Legacy summary unavailable: " .. tostring(summaryErr))
      end
      pushMessage(game, (archive.readOnly == true
          or archive.futureVersion ~= nil)
        and archiveFutureText() or archiveMigrationText())
      return false
    end
    if type(summary.blockers) == "table" and #summary.blockers > 0 then
      pushMessage(game, daycareBlockerText(game))
      return false
    end
    local character = J.activeCharacter(game.save) or "RED"
    local hoenn = {
      RED = { en = "TORCHIC", de = "FLEMMLI" },
      BLUE = { en = "MUDKIP", de = "HYDROPI" },
      GREEN = { en = "TREECKO", de = "GECKARBOR" },
    }
    local run = legacyState(game.save)
    local currentPartner = run and run.partnerSpecies or nil
    local contractEn = currentPartner or "ORIGINAL PARTNER"
    local contractDe = currentPartner or "URSPRÜNGLICHER PARTNER"
    local ListMenu = mod.ui.KantoListMenu or mod.ui.ListMenu

    local function closeMenu(menu)
      if game.stack:top() == menu then game.stack:pop() end
    end

    local function showChoiceHelp(item)
      local text = type(item) == "table" and (item.help or item.detail) or nil
      if type(text) ~= "string" or text == "" then return false end
      pushMessage(game, twoLinePages(text))
      return true
    end

    local choiceFooter = tr("A:CHOOSE  SEL:HELP", "A:WAHL  SEL:HILFE")

    local function finalCommit(selectedPact, selectedPolicy,
        selectedItemPolicy, selectedRules)
      -- Re-check at the final confirmation boundary, before writeSave().
      -- A hot-reloaded/unavailable archive may not alter the current save just
      -- because its cross-playthrough commit cannot be completed.
      if not archiveAvailable(game) then return end
      if not J.canBegin(game.save) then
        pushMessage(game, J.storyGateHint(game.save))
        return
      end
      local blockers = type(archive.journeyBlockers) == "function"
        and archive.journeyBlockers(game.save) or {}
      if #blockers > 0 then
        pushMessage(game, daycareBlockerText(game))
        return
      end
      if not game:writeSave() then
        pushMessage(game, tr(
          "CURRENT SAVE:\nWRITE FAILED.\fNothing changed.\nNo reset started.\fCheck free space.\nThen try again.",
          "SPIELSTAND:\nSPEICHERN FEHLERHAFT.\fNichts geändert.\nKein Neustart.\fPrüfe freien Speicher.\nVersuche es erneut."))
        return
      end
      local live = legacyState(game.save)
      local state, err = archive.beginJourney(game.save, {
        pact = selectedPact,
        bankPolicy = selectedPolicy,
        itemPolicy = selectedItemPolicy,
        runRules = selectedRules,
        starter = live and live.partnerSpecies or nil,
        partnerMode = live and live.partnerMode or nil,
        rivalPartner = live and archive.copy(live.rivalPartner) or nil,
        playerAvatar = J.activeCharacter(game.save),
      })
      if not state then
        if mod.log and mod.log.error then
          mod.log:error("Legacy archive transaction failed: " .. tostring(err))
        end
        pushMessage(game, tr(
          "LEGACY ARCHIVE:\nWRITE FAILED.\fThe current save is\nstill intact.\fNo reset started.\nTry again later.",
          "VERMÄCHTNIS-ARCHIV:\nSPEICHERN FEHLERHAFT.\fDer aktuelle Spielstand\nist weiter intakt.\fKein Neustart.\nVersuche es später erneut."))
        return
      end
      local fresh, freshErr = J.startFreshGame(game)
      if not fresh then
        if mod.log and mod.log.error then
          mod.log:error("Legacy fresh-save handoff failed: "
            .. tostring(freshErr))
        end
        pushMessage(game, tr(
          "NEW LEGACY SAVE:\nWRITE FAILED.\fYour previous save\nis still intact.\fRestart the game.\nThen retry LEGACY.",
          "NEUER LEGACY-SAVE:\nSPEICHERN FEHLERHAFT.\fDein vorheriger Save\nist weiter intakt.\fSpiel neu starten.\nVERMÄCHTNIS erneut."))
      end
    end

    local function rulesModeName(selectedRules)
      local mode = selectedRules and selectedRules.nuzlocke
        and selectedRules.nuzlocke.mode or "off"
      return tostring(mode):upper():gsub("_", " ")
    end

    local function openFinalReview(selectedPact, selectedPolicy,
        selectedItemPolicy, selectedRules)
      local selectedSummary = archive.summary(game.save, {
        itemPolicy = selectedItemPolicy,
      }) or summary
      local randomizer = selectedRules.randomizer.enabled
        and tr("ON", "AN") or tr("OFF", "AUS")
      local itemReview
      if selectedItemPolicy == "empty" then
        itemReview = tr(
          ("ITEM ARCHIVE:\nEMPTY\fOPTIONAL ITEMS:\nNONE\fEARNED PATH STONES:\n%d RETAINED")
            :format(selectedSummary.items),
          ("ITEM-ARCHIV:\nLEER\fOPTIONALE ITEMS:\nKEINE\fVERDIENTE PFADSTEINE:\n%d BEHALTEN")
            :format(selectedSummary.items))
      else
        itemReview = tr(
          "ITEM ARCHIVE:\nSAFE\fTRANSFERABLE ITEMS:\n%d",
          "ITEM-ARCHIV:\nSICHER\fÜBERTRAGBARE ITEMS:\n%d")
          :format(selectedSummary.items)
      end
      local finalReview = tr(
        ("PROF. OAK:\nFINAL REVIEW\fPACT / BANK:\n%s / %s\f%s\fRANDOMIZER PROFILE:\n%s\fRANDOMIZER:\n%s\fNUZLOCKE:\n%s\fSEED:\n%d\fPOKéDEX POOL:\nLAB CHOICE 151/251\fBEFORE PARTNER:\nPOOL + RULES LOCK\fTHIS RUN:\nENDS + ARCHIVES\fCURRENT SAVE:\nWILL BE REPLACED\fIT CANNOT BE\nCONTINUED AGAIN\fNEW SAVE:\nCREATED NOW\fARE YOU SURE?\nDEFAULT IS NO.")
          :format(J.pactName(selectedPact),
            J.bankPolicyName(selectedPolicy, selectedPact),
            itemReview,
            tostring(selectedRules.preset):upper(), randomizer,
            rulesModeName(selectedRules), selectedRules.seed),
        ("PROF. EICH:\nLETZTE PRÜFUNG\fPAKT / BANK:\n%s / %s\f%s\fRANDOMIZER-PROFIL:\n%s\fRANDOMIZER:\n%s\fNUZLOCKE:\n%s\fSEED:\n%d\fPOKéDEX-POOL:\nLABORWAHL 151/251\fVOR DEM PARTNER:\nPOOL + REGELN FEST\fDIESER LAUF:\nENDET + ARCHIVIERT\fALTER SPIELSTAND:\nWIRD ERSETZT\fDANACH NICHT MEHR\nFORTSETZBAR\fNEUER SPIELSTAND:\nWIRD JETZT ERSTELLT\fBIST DU SICHER?\nVORGABE IST NEIN.")
          :format(J.pactName(selectedPact),
            J.bankPolicyName(selectedPolicy, selectedPact),
            itemReview,
            tostring(selectedRules.preset):upper(), randomizer,
            rulesModeName(selectedRules), selectedRules.seed))
      game.stack:push(newTextBox(game, finalReview, nil, {
        defaultNo = true,
        choice = function(confirm)
          if confirm then
            finalCommit(selectedPact, selectedPolicy, selectedItemPolicy,
              selectedRules)
          end
        end,
      }))
    end

    local function openResetSummary(selectedPact, selectedPolicy,
        selectedItemPolicy, selectedRules)
      local selectedSummary = archive.summary(game.save, {
        itemPolicy = selectedItemPolicy,
      }) or summary
      local itemBlock
      if selectedItemPolicy == "empty" then
        itemBlock = tr(
          ("OPTIONAL ITEMS:\nNONE\fEARNED PATH STONES:\n%d RETAINED\fMONEY:\n¥%d")
            :format(selectedSummary.items, selectedSummary.money),
          ("OPTIONALE ITEMS:\nKEINE\fVERDIENTE PFADSTEINE:\n%d BEHALTEN\fGELD:\n¥%d")
            :format(selectedSummary.items, selectedSummary.money))
      else
        itemBlock = tr(
          ("ITEMS / MONEY:\n%d / ¥%d"):format(
            selectedSummary.items, selectedSummary.money),
          ("ITEMS / GELD:\n%d / ¥%d"):format(
            selectedSummary.items, selectedSummary.money))
      end
      local first = tr(
        ("PROF. OAK:\nREVIEW\fLEGACY CYCLE:\n%d\fAVATAR:\n%s\fCURRENT PARTNER:\n%s\fLEFT LAB BALL:\n%s\fARCHIVE KEEPS:\n%d POKéMON\f%s\fNEW CYCLE RESETS:\nSTORY + MAPS\fBADGES + PARTY\nBAG + MONEY\fNothing ends yet.\nRead final review next.")
          :format(selectedSummary.nextCycle, character, contractEn,
            hoenn[character].en, selectedSummary.pokemon, itemBlock),
        ("PROF. EICH:\nPRÜFUNG\fLEGACY-ZYKLUS:\n%d\fAVATAR:\n%s\fAKTUELLER PARTNER:\n%s\fLINKER LABOR-BALL:\n%s\fARCHIV BEHÄLT:\n%d POKéMON\f%s\fNEUER ZYKLUS:\nHANDLUNG + KARTEN\fORDEN + TEAM\nBEUTEL + GELD\fNoch endet nichts.\nJetzt letzte Prüfung.")
          :format(selectedSummary.nextCycle, character, contractDe,
            hoenn[character].de, selectedSummary.pokemon, itemBlock))
      game.stack:push(newTextBox(game, first, function()
        if not J.canBegin(game.save) then
          pushMessage(game, J.storyGateHint(game.save))
          return
        end
        openFinalReview(selectedPact, selectedPolicy, selectedItemPolicy,
          selectedRules)
      end))
    end

    local function openRunRules(selectedPact, selectedPolicy,
        selectedItemPolicy)
      -- run_rules.lua is constructed later in main.lua, but every player
      -- interaction happens after module startup. Resolve lazily so the old
      -- source save is never normalized or locked by this Legacy draft.
      local runRules = mod.exports and mod.exports.runRules
      if not (runRules and type(runRules.openLegacyDraft) == "function") then
        pushMessage(game, tr(
          "LEGACY RULES:\nUNAVAILABLE.\fNothing changed.\nNo reset started.",
          "VERMÄCHTNIS-REGELN:\nNICHT VERFÜGBAR.\fNichts geändert.\nKein Neustart."))
        return
      end
      local opened, err = runRules.openLegacyDraft(game, nil,
        function(selectedRules)
          openResetSummary(selectedPact, selectedPolicy,
            selectedItemPolicy, selectedRules)
        end)
      if not opened and err then
        if mod.log and mod.log.error then
          mod.log:error("Legacy rules draft failed: " .. tostring(err))
        end
        pushMessage(game, tr(
          "LEGACY RULES:\nCHECK FAILED.\fNothing changed.\nNo reset started.",
          "VERMÄCHTNIS-REGELN:\nPRÜFUNG FEHLERHAFT.\fNichts geändert.\nKein Neustart."))
      end
    end

    local function openItemPolicyMenu(selectedPact, selectedPolicy)
      local intro = tr(
        "PROF. OAK:\nCHOOSE ITEM ARCHIVE.\fSAFE (DEFAULT):\nTRANSFERABLE ITEMS\fEMPTY:\nNO OPTIONAL ITEMS\fThe three path Mega\nStones always remain.\fBadges, HMs, Key Items\nand Field Kit never cross.\fNext choose Randomizer\nand Nuzlocke rules.",
        "PROF. EICH:\nWÄHLE DAS ITEM-ARCHIV.\fSICHER (VORGABE):\nÜBERTRAGBARE ITEMS\fLEER:\nKEINE OPTIONALEN ITEMS\fDie drei Pfad-Megasteine\nbleiben immer erhalten.\fOrden, VMs, Basis-Items\nund Feld-Kit nie übernehmen.\fDanach Randomizer- und\nNuzlocke-Regeln wählen.")
      pushMessage(game, intro, function()
        local menu
        menu = ListMenu.new(game,
          tr("OAK: ITEM ARCHIVE", "EICH: ITEM-ARCHIV"),
          J.itemPolicyRows(), {
            footer = choiceFooter,
            onSelectKey = showChoiceHelp,
            onChoose = function(item)
              if not item then return end
              closeMenu(menu)
              openRunRules(selectedPact, selectedPolicy,
                itemPolicyId(item.value))
            end,
          })
        -- SAFE is deliberately row one and therefore the non-destructive
        -- default. EMPTY must always be an explicit player selection.
        game.stack:push(menu)
      end)
    end

    local function openBankPolicyMenu(selectedPact)
      local intro = tr(
        "PROF. OAK:\nCHOOSE A BANK RULE.\fOPEN:\nAFTER YOUR PARTNER\fAFTER 4 BADGES:\nAFTER FOUR BADGES\fAFTER LEAGUE:\nAFTER THIS HALL\fSEALED:\nNO ACCESS THIS RUN\fThe rule locks for\nthis whole journey.",
        "PROF. EICH:\nWÄHLE EINE BANKREGEL.\fOFFEN:\nNACH DEINEM PARTNER\fNACH 4 ORDEN:\nNACH VIER ORDEN\fNACH LIGA:\nNACH DIESER HALLE\fVERSIEGELT:\nKEIN ZUGRIFF\fDie Regel gilt für\ndiese ganze Reise.")
      pushMessage(game, intro, function()
        local menu
        menu = ListMenu.new(game, tr("OAK: BANK RULE", "EICH: BANKREGEL"),
          J.bankPolicyRows(selectedPact), {
            footer = choiceFooter,
            onSelectKey = showChoiceHelp,
            onChoose = function(item)
              if not item then return end
              closeMenu(menu)
              openItemPolicyMenu(selectedPact,
                bankPolicyId(item.value, selectedPact))
            end,
          })
        -- ListMenu starts on row one. Ascendant's row order deliberately puts
        -- its authored SEALED recommendation there; all four remain selectable.
        game.stack:push(menu)
      end)
    end

    local function openPactMenu()
      local menu
      menu = ListMenu.new(game, tr("OAK: CHOOSE PACT", "EICH: PAKTWAHL"),
        J.pactRows(), {
          footer = choiceFooter,
          onSelectKey = showChoiceHelp,
          onChoose = function(item)
            if not item then return end
            local selectedPact = pactId(item.value)
            closeMenu(menu)
            openBankPolicyMenu(selectedPact)
          end,
        })
      game.stack:push(menu)
    end

    -- The PC is only the safe entry point.  Oak personally hosts the actual
    -- choice over the live OAKS_LAB background; his existing OAKSLAB_OAK1
    -- object remains untouched and visible, so no replacement art or risky
    -- vanilla object movement is introduced.
    local oakIntro = tr(
      "PROF. OAK:\nI WILL GUIDE YOU.\fThe KASC terminal\nprepares a new cycle.\fFirst choose a PACT.\nIt sets the challenge.\fJOURNEY:\nCLASSIC BALANCE\fTRAINER:\nSTRONGER TEAMS\fLEGACY:\nMOVES + SYNERGY\fASCENDANT:\nHARDEST RULES\fThen choose BANK and\nITEM ARCHIVE rules.\fRandomizer and Nuzlocke\nare separate choices.\fL/R changes values.\nSELECT explains them.\fOnly the final review\ncan end this run.\fIt starts on NO.\nNothing resets earlier.",
      "PROF. EICH:\nICH FÜHRE DICH.\fDas KASC-Terminal\nbereitet den Zyklus vor.\fZuerst einen PAKT.\nEr setzt die Prüfung.\fREISE:\nKLASSISCHE BALANCE\fTRAINER:\nSTÄRKERE TEAMS\fVERMÄCHTNIS:\nATTACKEN + SYNERGIE\fASCENDANT:\nHÄRTESTE REGELN\fDann BANK- und\nITEM-ARCHIV-Regel.\fRandomizer und Nuzlocke\nsind getrennte Wahlen.\fL/R ändert Werte.\nSELECT erklärt sie.\fNur die letzte Prüfung\nkann den Lauf beenden.\fSie startet auf NEIN.\nVorher kein Neustart.")
    pushOakHostedMessage(game, oakIntro, openPactMenu)
    return true
  end

  -- This is an explanation only, deliberately separate from `begin()`: a
  -- player may inspect the alternative fresh-run procedure at Oak's Lab
  -- before the Hall of Fame without creating, archiving or resetting a run.
  -- The same page remains useful after the first entry because it names the
  -- final confirmation and distinguishes Legacy from the much later
  -- Ascendant Cycle.
  function J.storyGateHint(save)
    local eligible = archive.isEligible(save)
    local sealed, character = J.currentHevoSeal(save)
    local visited = sealed and J.currentHevoDoorVisit(save, character)
    if eligible and sealed and not visited then
      return twoLinePages(tr(
        "KASC TERMINAL:\nFINAL DOOR MISSING.\fYour fissure seal\nis recorded.\fReturn to your own\nsealed path.\fUse its final\nblack door.\fNothing starts.\nNothing resets.",
        "KASC-TERMINAL:\nLETZTE TÜR FEHLT.\fDein Riss-Siegel\nist gespeichert.\fKehre in deinen\nRisspfad zurück.\fNutze dort die letzte\nschwarze Tür.\fNichts startet.\nNichts wird gelöscht."))
    end
    if eligible and J.canBegin(save) then
      return twoLinePages(tr(
        "KASC TERMINAL:\nLEGACY IS READY.\fHALL OF FAME:\nRECORDED\fOWN FISSURE SEAL:\nRECORDED\fPACT, BANK, ITEMS\nAND RUN RULES FOLLOW.\fOnly final review\nstarts on NO.\fASC RUN is separate.\fThis info page\nchanges nothing.",
        "KASC-TERMINAL:\nVERMÄCHTNIS BEREIT.\fRUHMESHALLE:\nGESPEICHERT\fEIGENES RISS-SIEGEL:\nGESPEICHERT\fPAKT, BANK, ITEMS\nUND REGELN FOLGEN.\fNur letzte Prüfung\nstartet auf NEIN.\fASC-LAUF ist getrennt.\fDiese Infoseite\nändert nichts."))
    end
    if eligible then
      return twoLinePages(tr(
        "KASC TERMINAL:\nFISSURE PATH MISSING.\fHALL OF FAME:\nRECORDED\fComplete your own\nRED / BLUE / GREEN path.\fThen use its final\nblack door.\fPostgame alone\nstarts no journey.\fNothing resets.",
        "KASC-TERMINAL:\nRISSPFAD FEHLT.\fRUHMESHALLE:\nGESPEICHERT\fVollende deinen\nROT / BLAU / GRÜN-Pfad.\fNutze dann seine letzte\nschwarze Tür.\fPostgame allein\nstartet keine Reise.\fNichts wird gelöscht."))
    end
    return twoLinePages(tr(
      "KASC TERMINAL:\nLEGACY IS LOCKED.\fEnter the\nHALL OF FAME.\fComplete your own\nfissure path.\fUse its final\nblack door.\fNothing starts.\nNothing resets.",
      "KASC-TERMINAL:\nVERMÄCHTNIS GESPERRT.\fBetritt die\nRUHMESHALLE.\fVollende deinen\neigenen Risspfad.\fNutze seine letzte\nschwarze Tür.\fNichts startet.\nNichts wird gelöscht."))
  end

  -- Oak's north-west Lab computer is a dedicated Kanto Ascendant terminal,
  -- not a second route into the stock Player PC. Keep the two irreversible
  -- systems explicit at the top level: Legacy Journey owns the archived
  -- fresh-cycle handoff, while ASC Run owns Randomizer/Nuzlocke setup.
  function J.openLabTerminal(game)
    local stack = game and game.stack
    local ListMenu = mod.ui and (mod.ui.KantoListMenu or mod.ui.ListMenu)
    if not (stack and type(stack.push) == "function"
        and ListMenu and type(ListMenu.new) == "function") then
      return false, "ui"
    end

    local ready = J.canBegin(game.save) == true
    local rows = {
      {
        -- KantoListMenu reserves a right-hand status column. Keep this row
        -- short enough that its readiness state never turns the action into an
        -- ellipsis; Oak's call and the gate page use the full Journey name.
        label = tr("LEGACY", "VERMÄCHTNIS"),
        -- German uses the compact action state START: BEREIT would consume
        -- enough of the status column to truncate VERMÄCHTNIS itself.
        right = ready and tr("READY", "START") or tr("INFO", "INFO"),
        value = "legacy_journey",
        onSelect = function()
          if J.canBegin(game.save) then return J.begin(game) end
          pushMessage(game, J.storyGateHint(game.save))
        end,
      },
      {
        label = tr("ASC RUN", "ASC-LAUF"),
        right = tr("RULES", "REGELN"),
        value = "asc_run",
        onSelect = function()
          -- run_rules.lua is constructed later in main.lua. Resolve its
          -- public seam lazily so load order cannot create a stale nil.
          local runRules = mod.exports and mod.exports.runRules
          if runRules and type(runRules.open) == "function" then
            return runRules.open(game)
          end
          pushMessage(game, tr(
            "ASC RUN is not available.\fReload KANTO ASCENDANT\nand try again.",
            "ASC-LAUF ist nicht\nverfügbar.\fLade KANTO ASCENDANT\nneu und versuche es erneut."))
        end,
      },
    }

    -- Preserve the useful cross-cycle bank shortcut without putting Journey
    -- setup back behind a Player-PC submenu.
    local state = legacyState(game.save)
    if state then
      local bankOpen = J.bankAccess(game.save)
      rows[#rows + 1] = bankOpen and {
          label = tr("LEGACY BANK", "VERMÄCHTNIS-BANK"),
          value = "legacy_bank",
          onSelect = function() J.openBank(game) end,
        } or {
          label = tr("BANK [LOCKED]", "BANK [GESP.]"),
          value = "legacy_bank_locked",
          onSelect = function()
            pushMessage(game, J.bankPolicyHint(game.save))
          end,
        }
    end

    local menu
    menu = ListMenu.new(game, tr("KASC TERMINAL", "KASC-TERMINAL"), rows, {
      footer = tr("A: OPEN  B: BACK", "A: ÖFFNEN  B: ZURÜCK"),
      onChoose = function(item)
        if not (item and type(item.onSelect) == "function") then return end
        -- ListMenu does not pop itself on A. Close the hub before opening a
        -- child screen/text so B always returns directly to the Lab.
        if type(stack.top) == "function" and stack:top() == menu
            and type(stack.pop) == "function" then
          stack:pop()
        elseif type(menu.close) == "function" then
          menu:close()
        end
        item.onSelect()
      end,
    })
    stack:push(menu)
    return menu
  end

  mod.hooks:wrap("save.new_game", function(nextNewGame, save)
    save = nextNewGame(save)
    bindArchiveData()
    if type(archive.markFreshOrigin) == "function" then
      archive.markFreshOrigin(save)
    end
    local seeded, seedErr = archive.seedNewSave(save)
    if not seeded then
      freshSeedFailure = seedErr or storageBackendFailure
        or "target Legacy lineage handoff could not be staged"
    end
    return save
  end, 5000)

  -- The first target save is the commit boundary. Import the complete capsule
  -- into the fresh playthrough's official storage, read it back, activate the
  -- run, read that back as well, and only then allow SaveData to replace the
  -- old progress file. Returning false leaves the previous on-disk save and
  -- its source archive as an idempotent retry point.
  mod.hooks:wrap("save.write", function(nextWrite, game)
    if not (game and game.save and type(archive.hasHandoff) == "function"
        and archive.hasHandoff(game.save)) then
      return nextWrite(game)
    end
    activeGame = game
    storageScopeReady = true
    local imported, importErr = archive.importHandoff(game.save)
    if not imported then
      mod.log:error("Legacy target import failed: " .. tostring(importErr))
      return false
    end
    local started, startErr = archive.markRunStarted(game.save)
    if not started then
      mod.log:error("Legacy target activation failed: " .. tostring(startErr))
      return false
    end
    if storageBackendMode == "playthrough" then
      if type(mod.storage.context) ~= "function"
          or type(archive.stampStorageBinding) ~= "function" then
        mod.log:error("Legacy target binding failed: official storage context unavailable")
        return false
      end
      local context, contextCode, contextMessage = mod.storage:context(game)
      if type(context) ~= "table" then
        mod.log:error("Legacy target binding failed: "
          .. tostring(contextMessage or contextCode))
        return false
      end
      local bound, bindingErr = archive.stampStorageBinding(game.save, context)
      if not bound then
        mod.log:error("Legacy target binding failed: " .. tostring(bindingErr))
        return false
      end
    end
    local finished, finishErr = archive.finishHandoff(game.save)
    if not finished then
      mod.log:error("Legacy handoff verification failed: " .. tostring(finishErr))
      return false
    end
    return nextWrite(game)
  end, 9000)

  mod.events:on("game.ready", function(ev)
    if ev and ev.game then activeGame = ev.game end
  end, 5000)

  mod.events:on("save.created", function(ev)
    -- The engine's provisional boot save is created before game.ready, while a
    -- player-selected New Game (including our direct handoff) is created after
    -- it. This distinction avoids allocating storage for a title skeleton.
    if activeGame and ev and ev.save and activeGame.save == ev.save then
      storageScopeReady = true
    end
  end, 9000)

  mod.events:on("save.loaded", function(ev)
    if ev and ev.save then
      storageScopeReady = true
      local lineageOk, lineageErr = true, nil
      if type(archive.lineageStatus) == "function" then
        lineageOk, lineageErr = archive.lineageStatus(ev.save)
      end
      if storageBackendFailure then
        mod.log:error("Legacy storage unavailable: "
          .. tostring(storageBackendFailure))
        return
      end
      if not lineageOk then
        mod.log:error("Legacy archive migration required: "
          .. tostring(lineageErr))
        return
      end
      archive.reconcileLeases(ev.save)
      archive.reconcileCheckout(ev.save)
      archive.syncProfile(ev.save)
      J.reconcileLegacyRunRules(ev.save)
      -- This is the sole migration backfill: HOF + the matching durable seal
      -- + the matching shared black-door visit.  Seal-only saves remain
      -- locked and are directed back to that final authored interaction.
      J.reconcileHevoSealGate(ev.save, true)
      ev.save.flags = type(ev.save.flags) == "table" and ev.save.flags or {}
      ev.save.flags.HEVO_DOOR_QUEST_READY =
        archive.hevoDoorQuestReady
        and archive.hevoDoorQuestReady(ev.save) and true or nil
      -- Fail closed across power loss: an unfinished Legacy identity/partner
      -- phase always resumes in Oak's Lab, never in the bedroom or Pallet.
      J.resumeFreshLab(ev.game or activeGame, ev.save)
    end
  end, 5000)
  mod.events:on("save.writing", function(ev)
    if ev and ev.save then
      local bucket = modBucket(ev.save, false)
      if type(bucket) == "table" and bucket.legacy_fresh_origin ~= nil
          and type(archive.markFreshOrigin) == "function" then
        archive.markFreshOrigin(ev.save)
      end
      mirrorHevoGateFlags(ev.save, hevoGateState(ev.save, false))
      ev.save.flags = type(ev.save.flags) == "table" and ev.save.flags or {}
      ev.save.flags.HEVO_DOOR_QUEST_READY =
        archive.hevoDoorQuestReady
        and archive.hevoDoorQuestReady(ev.save) and true or nil
      archive.markRunStarted(ev.save)
    end
  end, -5000)
  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
    if game then J.deliverPendingHevoCall(game, mapId) end
  end, 5100)
  mod.events:on("world.stepped", function(ev)
    local game = ev and ev.game or activeGame
    J.onLabRivalResolved(game)
  end, 5200)

  -- Oak's Lab already draws a two-cell computer terminal in the north-west
  -- alcove, but the imported R/B/Y hidden-event tables do not mark either
  -- half as a PC. Bind both authored terminal cells directly to the KASC hub,
  -- and no neighbouring display: (0,1)/(1,1), faced from row 2.
  if mod.content and mod.content.map_scripts then
    mod.content.map_scripts:register("OAKS_LAB", {
      priority = 1800,
      onInteract = function(game, _, x, y)
        if y ~= 1 or not J.OAK_PC_TARGETS[x] then return false end
        return J.openLabTerminal(game) and true or false
      end,
    })
  end

  function J.isActive(save)
    return type(legacyState(save)) == "table"
  end

  function J.wanderersEnabled(save)
    local state = legacyState(save)
    return type(state) == "table" and state.wanderersEnabled == true
  end

  function J.state(save)
    local state = legacyState(save)
    return state and archive.copy(state) or nil
  end

  function J.currentPact(save)
    local run = legacyState(save)
    if type(run) ~= "table" then return nil end
    local current = archive.current and archive.current() or nil
    if type(current) == "table" and current.runId == run.runId then
      return pactId(current.pact)
    end
    return pactId(run.pact)
  end

  function J.profile()
    return archive.profile()
  end

  function J.syncPartner(save)
    return archive.syncPartner and archive.syncPartner(save) or true
  end

  function J.syncHevoPersistent(save)
    return archive.syncHevoPersistent
      and archive.syncHevoPersistent(save) or true
  end

  function J.syncJohtoMastersPersistent(save)
    return archive.syncJohtoMastersPersistent
      and archive.syncJohtoMastersPersistent(save) or true
  end

  function J.completeHevoPath(save, character)
    return archive.completeHevoPath
      and archive.completeHevoPath(save, character)
      or J.advancePath(save, 5, true)
  end

  function J.setAvatar(save, avatar)
    return archive.setAvatar(save, avatar)
  end

  function J.advancePath(save, stage, complete)
    return archive.advancePath(save, stage, complete)
  end

  function J.completeFinale(save)
    return archive.completeFinale(save)
  end

  -- Stable Package-3 compatibility surface. Normal runs resolve the selected
  -- character directly; Legacy runs use the archive-backed avatar. Consumers
  -- never need to know either module's private save layout.
  function J.activeCharacter(save)
    local bucket = type(save and save.modData) == "table"
      and save.modData[mod.id]
    local chars = type(bucket) == "table" and bucket.extended_characters
    if chars ~= nil then
      if type(chars) ~= "table" then return nil end
      local selected = type(chars.player_character) == "string"
        and chars.player_character:upper() or nil
      return ({ RED = true, BLUE = true, GREEN = true })[selected]
        and selected or nil
    end
    local active = archive.activeCharacter and archive.activeCharacter(save)
    active = type(active) == "string" and active:upper() or nil
    if ({ RED = true, BLUE = true, GREEN = true })[active] then return active end
    -- Official pre-6.5 saves have no identity record at all: they are Red.
    -- This same resolver is consumed by the live seal and final-door checks,
    -- so a durable BLITZ-style RED seal cannot be rejected at handoff while
    -- malformed/future records remain closed above.
    return type(save) == "table" and "RED" or nil
  end

  function J.runLocal(save)
    local localState = archive.runLocal and archive.runLocal(save)
    if localState and not localState.activeCharacter then
      localState.activeCharacter = J.activeCharacter(save)
    end
    return localState
  end
  J.legacyPersistent = archive.hevoPersistent or function() return {} end
  J.hevoDoorQuestReady = archive.hevoDoorQuestReady or function() return false end
  J.consumeHevoDoorQuest = archive.consumeHevoDoorQuest or function() return false end

  return J
end
