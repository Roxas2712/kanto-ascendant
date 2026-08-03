-- Field Kit, renewable TM archive and the Kanto/Johto starter techniques.
--
-- The Field Kit never skips story progression: a field technique works only
-- when its original HM and badge are already owned.  It merely removes the
-- need to occupy a Pokémon move slot.  HMs remain teachable in the normal way.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local F = { game = nil, ITEM = "FIELD_KIT" }
  local SAVE_VERSION = 2

  local FIELD_MOVES = {
    CUT = { hm = "HM_CUT", badge = "CASCADEBADGE" },
    FLY = { hm = "HM_FLY", badge = "THUNDERBADGE" },
    SURF = { hm = "HM_SURF", badge = "SOULBADGE" },
    STRENGTH = { hm = "HM_STRENGTH", badge = "RAINBOWBADGE" },
    FLASH = { hm = "HM_FLASH", badge = "BOULDERBADGE" },
  }

  local SIGNATURE_TMS = {
    misty = {
      item = "TM_HYDRO_CANNON", move = "HYDRO_CANNON", number = 53,
      en = "HYDRO CANNON", de = "AQUAHAUBITZE",
    },
    erika = {
      item = "TM_FRENZY_PLANT", move = "FRENZY_PLANT", number = 51,
      en = "FRENZY PLANT", de = "FLORA-STATUE",
    },
    blaine = {
      item = "TM_BLAST_BURN", move = "BLAST_BURN", number = 52,
      en = "BLAST BURN", de = "LOHEKANONADE",
    },
  }

  local STARTER_FAMILIES = {
    FRENZY_PLANT = {
      "BULBASAUR", "IVYSAUR", "VENUSAUR",
      "CHIKORITA", "BAYLEEF", "MEGANIUM",
    },
    BLAST_BURN = {
      "CHARMANDER", "CHARMELEON", "CHARIZARD",
      "CYNDAQUIL", "QUILAVA", "TYPHLOSION",
    },
    HYDRO_CANNON = {
      "SQUIRTLE", "WARTORTLE", "BLASTOISE",
      "TOTODILE", "CROCONAW", "FERALIGATR",
    },
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function state(create)
    local s = mod.save:get("field_tech")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = SAVE_VERSION, kit = false, rematchWins = 0, tmWins = 0,
        tmCursor = 0, tmCycles = 0, signatureUnlocked = {},
        signatureAwarded = {}, pendingTMs = {}, archivedTMs = {},
        archiveSeeded = true,
      }
      mod.save:set("field_tech", s)
    end
    if type(s) == "table" then
      local previousVersion = math.max(1,
        math.floor(tonumber(s.version) or 1))
      s.kit = s.kit == true
      s.rematchWins = math.max(0, math.floor(tonumber(s.rematchWins) or 0))
      s.tmWins = math.max(0, math.floor(tonumber(s.tmWins) or 0))
      s.tmCursor = math.max(0, math.floor(tonumber(s.tmCursor) or 0))
      s.tmCycles = math.max(0, math.floor(tonumber(s.tmCycles) or 0))
      s.signatureUnlocked = type(s.signatureUnlocked) == "table"
        and s.signatureUnlocked or {}
      s.signatureAwarded = type(s.signatureAwarded) == "table"
        and s.signatureAwarded or {}
      s.pendingTMs = type(s.pendingTMs) == "table" and s.pendingTMs or {}
      local queue = {}
      for _, row in ipairs(s.pendingTMs) do
        local id = type(row) == "table" and row.id or row
        if type(id) == "string" then queue[#queue + 1] = id end
      end
      -- Version 1 could retain one blocked TM and stopped counting wins
      -- until it was delivered. Preserve that entitlement as the first
      -- entry of the new FIFO queue.
      if previousVersion < SAVE_VERSION and type(s.pendingTM) == "string" then
        table.insert(queue, 1, s.pendingTM)
      end
      if previousVersion < SAVE_VERSION then
        -- Version 1 recorded a failed Crown hand-off as "unlocked" but
        -- required another boss win. Convert that proof into the permanent
        -- entitlement promised by version 2.
        for _, gymKey in ipairs({ "erika", "blaine", "misty" }) do
          local row = SIGNATURE_TMS[gymKey]
          if s.signatureUnlocked[row.item]
              and not s.signatureAwarded[row.item] then
            s.signatureAwarded[row.item] = true
            queue[#queue + 1] = row.item
          end
        end
      end
      s.pendingTMs = queue
      s.pendingTM = nil
      s.archivedTMs = type(s.archivedTMs) == "table"
        and s.archivedTMs or {}
      if previousVersion < SAVE_VERSION then
        -- The old implementation counted the very first TM as a completed
        -- cycle. Every later wrap was otherwise correct, so remove exactly
        -- that phantom round and seed the earned-TM map once game data is
        -- available.
        s.tmCycles = math.max(0, s.tmCycles - (s.tmCursor > 0 and 1 or 0))
        s.archiveSeeded = false
      else
        s.archiveSeeded = s.archiveSeeded ~= false
      end
      s.version = SAVE_VERSION
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("field_tech", s) end
  end

  local function hasHallOfFame(save)
    return save and ((type(save.hallOfFame) == "table"
      and #save.hallOfFame > 0)
      or (save.flags and save.flags.EVENT_BEAT_CHAMPION_RIVAL)) or false
  end

  local function itemName(game, id)
    local def = game and game.data and game.data.items
      and game.data.items[id]
    return def and def.name or id
  end

  local function addItem(game, id)
    game.save.inventory = game.save.inventory or {}
    return require("src.inventory.Bag").add(game.save, id, 1, game.data)
  end

  local function ownsKit(save)
    local s = state(false)
    return s and s.kit == true
      and save and save.inventory and save.inventory.FIELD_KIT ~= nil
  end

  local function available(save, moveId)
    local row = FIELD_MOVES[moveId]
    local inventory = save and save.inventory or {}
    return row ~= nil and ownsKit(save)
      and inventory[row.hm] ~= nil and inventory[row.badge] ~= nil
  end

  local function fieldUser(save)
    local mon = save and save.party and save.party[1]
    return {
      species = mon and mon.species or "PIKACHU",
      nickname = tr("FIELD KIT", "FELD-KIT"),
      moves = {},
    }
  end

  -- Keep vanilla party users first. The kit only supplies a user when the
  -- party does not already know the move.
  mod.hooks:wrap("fieldmove.eligibility",
    function(nextEligibility, moveId, ctx)
      local mon = nextEligibility(moveId, ctx)
      if mon then return mon end
      if available(ctx and ctx.save, moveId) then
        return fieldUser(ctx.save)
      end
      return nil
    end, 1800)

  local function registerStarterContent()
    local moves = {
      FRENZY_PLANT = {
        name = tr("FRENZY PLANT", "FLORA-STATUE"),
        type = "GRASS", anim = "PETAL_DANCE",
      },
      BLAST_BURN = {
        name = tr("BLAST BURN", "LOHEKANONADE"),
        type = "FIRE", anim = "FIRE_BLAST",
      },
      HYDRO_CANNON = {
        name = tr("HYDRO CANNON", "AQUAHAUBITZE"),
        type = "WATER", anim = "HYDRO_PUMP",
      },
    }
    for id, row in pairs(moves) do
      mod.content.moves:register(id, {
        id = id, name = row.name, type = row.type,
        power = 150, accuracy = 90, pp = 5, category = "special",
        effect = "HYPER_BEAM_EFFECT", anim = row.anim,
      })
    end
    for _, row in pairs(SIGNATURE_TMS) do
      mod.content.items:register(row.item, {
        id = row.item, name = ("TM%02d"):format(row.number),
        price = 7500, tossable = true, needsTarget = true,
        machine = { kind = "TM", move = row.move, number = row.number },
      })
    end
    mod.content.items:register(F.ITEM, {
      id = F.ITEM, name = tr("FIELD KIT", "FELD-KIT"),
      price = 0, tossable = false, needsTarget = false,
    })

    for moveId, family in pairs(STARTER_FAMILIES) do
      for _, species in ipairs(family) do
        local def = mod.content.pokemon:get(species)
        if def then
          local tmhm, seen = {}, {}
          for _, existing in ipairs(def.tmhm or {}) do
            if not seen[existing] then
              seen[existing] = true
              tmhm[#tmhm + 1] = existing
            end
          end
          if not seen[moveId] then tmhm[#tmhm + 1] = moveId end
          mod.content.pokemon:patch(species, { tmhm = tmhm })
        end
      end
    end
  end
  registerStarterContent()

  local function renewableTMs(game)
    local s = state()
    local rows = {}
    for id, def in pairs(game and game.data and game.data.items or {}) do
      local machine = def.machine
      if machine and machine.kind == "TM" then
        local number = tonumber(machine.number) or 999
        local signature = number > 50
        if not signature or s.signatureAwarded[id] then
          rows[#rows + 1] = { id = id, number = number }
        end
      end
    end
    table.sort(rows, function(a, b)
      if a.number == b.number then return a.id < b.id end
      return a.number < b.number
    end)
    if s.tmCursor > #rows then s.tmCursor = #rows end
    if not s.archiveSeeded then
      local earned = s.tmCycles > 0 and #rows
        or math.min(s.tmCursor, #rows)
      for index = 1, earned do
        local row = rows[index]
        if row and (row.number <= 50 or s.signatureAwarded[row.id]) then
          s.archivedTMs[row.id] = true
        end
      end
      for id, awarded in pairs(s.signatureAwarded) do
        if awarded then s.archivedTMs[id] = true end
      end
      s.archiveSeeded = true
      persist(s)
    end
    return rows
  end

  local function awardKit(game)
    local s = state()
    if s.kit then return nil end
    if addItem(game, F.ITEM) then
      s.kit = true
      persist(s)
      return tr(
        "REMATCH MILESTONE!\fYou received the\nFIELD KIT!\fOwned HMs now work\nwithout teaching them.",
        "REVANCHEN-MEILENSTEIN!\fDu erhältst das\nFELD-KIT!\fEigene VMs wirken nun\nohne Beibringen.")
    end
    return tr(
      "A FIELD KIT is ready,\nbut the BAG is full.\fWin another rematch\nafter making room.",
      "Ein FELD-KIT ist bereit,\ndoch der BEUTEL ist voll.\fSchaffe Platz und siege\nerneut.")
  end

  local function tmMessage(game, id, held)
    if held then
      return tr(
        ("TM ARCHIVE:\n%s is reserved.\fMake BAG room; the\nRoute 5 machine keeps it."):format(
          itemName(game, id)),
        ("TM-ARCHIV:\n%s ist reserviert.\fSchaffe Platz; die\nRoute-5-Maschine hält sie."):format(
          itemName(game, id)))
    end
    return tr(
      ("TM ARCHIVE REWARD:\nYou received %s!"):format(itemName(game, id)),
      ("TM-ARCHIV-BELOHNUNG:\nDu erhältst %s!"):format(itemName(game, id)))
  end

  local function deliverPendingTMs(game, s, announceWaiting)
    local pages, delivered = {}, 0
    while #s.pendingTMs > 0 do
      local id = s.pendingTMs[1]
      if not addItem(game, id) then break end
      table.remove(s.pendingTMs, 1)
      pages[#pages + 1] = tmMessage(game, id, false)
      delivered = delivered + 1
    end
    if announceWaiting and delivered == 0 and s.pendingTMs[1] then
      pages[#pages + 1] = tmMessage(game, s.pendingTMs[1], true)
    end
    persist(s)
    return #pages > 0 and table.concat(pages, "\f") or nil, delivered
  end

  local function reserveOrDeliverTM(game, s, id)
    s.archivedTMs[id] = true
    -- Never let a later reward jump ahead of an older reserved one.
    if #s.pendingTMs == 0 and addItem(game, id) then
      persist(s)
      return tmMessage(game, id, false), true
    end
    s.pendingTMs[#s.pendingTMs + 1] = id
    persist(s)
    return tmMessage(game, id, true), false
  end

  local function awardNextTM(game, s)
    local pool = renewableTMs(game)
    if #pool == 0 then return nil end
    if s.tmCursor >= #pool then
      if s.tmCursor > 0 then s.tmCycles = s.tmCycles + 1 end
      s.tmCursor = 1
    else
      s.tmCursor = s.tmCursor + 1
    end
    local id = pool[s.tmCursor].id
    return reserveOrDeliverTM(game, s, id)
  end

  function F.afterRematch(game)
    local s = state()
    s.rematchWins = s.rematchWins + 1
    persist(s)
    local pages = {}
    local kit = awardKit(game)
    if kit then pages[#pages + 1] = kit end

    if hasHallOfFame(game.save) then
      local delivered = deliverPendingTMs(game, s, false)
      if delivered then pages[#pages + 1] = delivered end
      -- A full BAG no longer freezes the archive clock. Every eligible
      -- rematch advances it and each even win creates the next entitlement.
      s.tmWins = s.tmWins + 1
      persist(s)
      if s.tmWins % 2 == 0 then
        local msg = awardNextTM(game, s)
        if msg then pages[#pages + 1] = msg end
      end
    end
    return #pages > 0 and table.concat(pages, "\f") or nil
  end

  function F.afterBossWin(game, gymKey, tier)
    local row = tier == "crown" and SIGNATURE_TMS[gymKey] or nil
    if not row then return nil end
    local s = state()
    s.signatureUnlocked[row.item] = true
    if s.signatureAwarded[row.item] then
      local delivered = deliverPendingTMs(game, s, false)
      persist(s)
      return delivered
    end
    -- "Awarded" means the one-time entitlement exists, whether the TM fits
    -- in the BAG now or is waiting in the persistent FIFO.
    s.signatureAwarded[row.item] = true
    local _, received = reserveOrDeliverTM(game, s, row.item)
    if received then
      return tr(
        ("%s gives you\nTM%02d!\f%s!\fKanto and Johto\n%s starters learn it."):format(
          gymKey:upper(), row.number, row.en, row.move == "FRENZY_PLANT"
            and "GRASS" or (row.move == "BLAST_BURN" and "FIRE" or "WATER")),
        ("%s gibt dir\nTM%02d!\f%s!\fKantos und Johtos\nStarter lernen sie."):format(
          gymKey:upper(), row.number, row.de))
    end
    return tr(
      ("TM%02d is safely stored\nfor you.\fMake BAG room and use\nthe Route 5 machine."):format(
        row.number),
      ("TM%02d ist sicher für\ndich verwahrt.\fSchaffe Platz und nutze\ndie Route-5-Maschine."):format(
        row.number))
  end

  local function message(game, text, done)
    game.stack:push(require("src.render.TextBox").new(game, text, done))
  end

  local function fieldFailure(game, reason)
    local lines = {
      no_badge = tr("A required BADGE or\nHM is missing.",
                    "Ein nötiger ORDEN oder\neine VM fehlt."),
      forced_bike = tr("Cycling is fun!\nForget field tools!",
                       "Radfahren macht Spaß!\nKeine Feldtechnik!"),
      current = tr("The current is much\ntoo fast!", "Die Strömung ist\nzu stark!"),
      no_place = tr("There is no place\nto get off.",
                    "Hier kann man nicht\nabsteigen."),
      no_water = tr("No SURFing here!", "Hier kann man nicht\nSURFEN!"),
      nothing = tr("Nothing to CUT!", "Hier gibt es nichts\nzu ZERSCHNEIDEN!"),
    }
    message(game, lines[reason] or tr("It won't work here.",
      "Das funktioniert hier nicht."))
  end

  local function useFieldMove(game, moveId, menu)
    local ow = game.overworld
    if not ow then return fieldFailure(game) end
    if moveId == "FLY" then
      menu:close()
      require("src.ui.Screens").push(game, "TownMap", {
        fly = true,
        onFly = function(mapId) if ow then ow:flyTo(mapId) end end,
      })
      return
    end
    if moveId == "FLASH" then
      menu:close()
      game.save.flashLit = true
      message(game, tr("The FIELD KIT lights\nthe whole area!",
        "Das FELD-KIT erhellt\ndas ganze Gebiet!"), function()
        game.stack:push(require("src.render.Transition").whiteFlash(
          game, nil, function() ow:setDark(false) end))
      end)
      return
    end
    if moveId == "STRENGTH" then
      menu:close()
      ow.strengthActive = true
      message(game, tr(
        "The FIELD KIT activates\nSTRENGTH!\fBoulders can now\nbe moved.",
        "Das FELD-KIT aktiviert\nSTÄRKE!\fFelsen können nun\nbewegt werden."), function()
        game.stack:push(require("src.render.Transition").whiteFlash(game))
      end)
      return
    end
    if moveId == "CUT" then
      local reason = ow:useCutFieldMove()
      if reason ~= "ok" then return fieldFailure(game, reason) end
      local fx, fy = ow.player:facingCell()
      menu:close()
      ow:tryCut(fx, fy)
      return
    end
    if moveId == "SURF" then
      local reason = ow:useSurfFieldMove()
      if reason == "ok" then
        local fx, fy = ow.player:facingCell()
        menu:close()
        ow:trySurf(fx, fy)
        return
      elseif reason == "dismount" then
        menu:close()
        ow.player.surfing = false
        require("src.core.Music").setSurfing(game.data, false)
        game.stack:push(require("src.render.Transition").whiteFlash(
          game, nil, function()
            ow:stepForwardOrCrossEdge(ow.player.facing)
          end))
        return
      end
      return fieldFailure(game, reason)
    end
  end

  local function fieldRows(game)
    local rows = {}
    local ow = game.overworld
    local outside = false
    if ow then
      outside = require("src.world.Map").isOutside(ow.map.def,
        game.data.field.outsideTilesets)
    end
    for _, moveId in ipairs({ "CUT", "FLY", "SURF", "STRENGTH", "FLASH" }) do
      if available(game.save, moveId)
          and (moveId ~= "FLY" or outside)
          and (moveId ~= "FLASH" or (ow and ow.dark)) then
        rows[#rows + 1] = {
          label = game.data.moves[moveId].name, value = moveId,
        }
      end
    end
    return rows
  end

  function F.open(game, done)
    local rows = fieldRows(game)
    if #rows == 0 then
      message(game, tr(
        "No FIELD KIT module\ncan be used here.\fCollect an HM and its\nmatching BADGE first.",
        "Kein FELD-KIT-Modul\nist hier nutzbar.\fFinde zuerst VM und\nden passenden ORDEN."), done)
      return
    end
    game.stack:push(mod.ui.ListMenu.new(game, tr("FIELD KIT", "FELD-KIT"),
      rows, {
        onCancel = done,
        onChoose = function(item, menu)
          useFieldMove(game, item.value, menu)
        end,
      }))
  end

  local function recordRememberedMove(mon, moveId)
    if not (mon and type(moveId) == "string") then return end
    mon.rememberedMoves = type(mon.rememberedMoves) == "table"
      and mon.rememberedMoves or {}
    mon.rememberedMoves[moveId] = true
  end

  local function forgetMove(mon, index)
    if not mon or type(mon.moves) ~= "table" or #mon.moves <= 1 then
      return false
    end
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > #mon.moves then return false end
    recordRememberedMove(mon, mon.moves[index] and mon.moves[index].id)
    table.remove(mon.moves, index)
    return true
  end

  function F.forgetMenu(game, done)
    require("src.ui.Screens").push(game, "PartyMenu", {
      pickOnly = true, onCancel = done,
      onSwitch = function(mon)
        if mon.isEgg then
          message(game, tr("An EGG has no moves\nto forget.",
            "Ein EI kann keine\nAttacke vergessen."), done)
          return
        end
        if #mon.moves <= 1 then
          message(game, tr("A POKéMON must keep\nat least one move.",
            "Ein POKéMON muss\neine Attacke behalten."), done)
          return
        end
        local rows = {}
        for index, move in ipairs(mon.moves) do
          local def = game.data.moves[move.id]
          rows[#rows + 1] = {
            label = def and def.name or move.id,
            right = tostring(move.pp or 0), value = index,
          }
        end
        game.stack:push(mod.ui.ListMenu.new(game,
          tr("FORGET WHICH?", "WELCHE VERLERNEN?"), rows, {
            onCancel = done,
            onChoose = function(item, menu)
              local move = mon.moves[item.value]
              local def = move and game.data.moves[move.id]
              if not move then return end
              game.stack:push(require("src.render.TextBox").new(game,
                tr(("Forget %s?"):format(def and def.name or move.id),
                   ("%s verlernen?"):format(def and def.name or move.id)),
                nil, {
                  choice = function(yes)
                    if not yes then return end
                    if not forgetMove(mon, item.value) then return end
                    menu:close()
                    message(game, tr(
                      ("%s forgot\n%s!"):format(
                        mon.nickname or game.data.pokemon[mon.species].name,
                        def and def.name or move.id),
                      ("%s hat\n%s verlernt!"):format(
                        mon.nickname or game.data.pokemon[mon.species].name,
                        def and def.name or move.id)), done)
                  end,
                }))
            end,
          }))
      end,
    })
  end

  local function knowsMove(mon, moveId)
    for _, move in ipairs(mon and mon.moves or {}) do
      if move.id == moveId then return true end
    end
    return false
  end

  local function inFamily(family, species)
    for _, id in ipairs(family or {}) do
      if id == species then return true end
    end
    return false
  end

  -- Only moves with a species-level source or per-Pokémon evidence are
  -- eligible. This deliberately does not turn every compatible TM into a
  -- free move tutor.
  local function reminderMoves(game, mon)
    local def = mon and game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    if not (def and type(mon.moves) == "table") or mon.isEgg then return {} end
    local rows, seen = {}, {}
    local function add(moveId, source)
      if type(moveId) ~= "string" or seen[moveId] or knowsMove(mon, moveId)
          or not (game.data.moves and game.data.moves[moveId]) then return end
      seen[moveId] = true
      rows[#rows + 1] = { id = moveId, source = source }
    end
    for _, moveId in ipairs(def.level1Moves or {}) do add(moveId, "level") end
    for _, row in ipairs(def.learnset or {}) do
      if (tonumber(row.level) or 101) <= (tonumber(mon.level) or 1) then
        add(row.move, "level")
      end
    end

    local distribution = type(mon.eventDistribution) == "table"
      and mon.eventDistribution or nil
    for _, moveId in ipairs(distribution and distribution.originalMoves or {}) do
      add(moveId, "event")
    end
    for key, remembered in pairs(
        type(mon.rememberedMoves) == "table" and mon.rememberedMoves or {}) do
      local moveId = type(key) == "number" and remembered or key
      if remembered then add(moveId, "memory") end
    end

    local s = state()
    for _, signature in pairs(SIGNATURE_TMS) do
      if (s.signatureUnlocked[signature.item]
          or s.signatureAwarded[signature.item])
          and inFamily(STARTER_FAMILIES[signature.move], mon.species) then
        add(signature.move, "crown")
      end
    end
    return rows
  end

  local function rememberMove(game, mon, moveId, replaceIndex)
    if not (game and mon and type(mon.moves) == "table")
        or knowsMove(mon, moveId) then return false, "known" end
    local legal = false
    for _, row in ipairs(reminderMoves(game, mon)) do
      if row.id == moveId then legal = true break end
    end
    if not legal then return false, "illegal" end
    local move = game.data.moves[moveId]
    if not move then return false, "missing" end
    if #mon.moves < 4 then
      mon.moves[#mon.moves + 1] = { id = moveId, pp = move.pp or 0 }
      return true
    end
    replaceIndex = math.floor(tonumber(replaceIndex) or 0)
    if replaceIndex < 1 or replaceIndex > #mon.moves then
      return false, "full"
    end
    recordRememberedMove(mon, mon.moves[replaceIndex].id)
    mon.moves[replaceIndex] = { id = moveId, pp = move.pp or 0 }
    return true
  end

  local function sourceLabel(source)
    local labels = {
      level = tr("LEVEL", "LEVEL"),
      event = tr("EVENT", "EVENT"),
      memory = tr("MEMORY", "ERINN."),
      crown = tr("CROWN", "KRONE"),
    }
    return labels[source] or source
  end

  function F.rememberMenu(game, done)
    require("src.ui.Screens").push(game, "PartyMenu", {
      pickOnly = true, onCancel = done,
      onSwitch = function(mon)
        if mon.isEgg then
          message(game, tr("An EGG cannot\nremember moves.",
            "Ein EI kann sich an\nkeine Attacken erinnern."), done)
          return
        end
        local candidates = reminderMoves(game, mon)
        if #candidates == 0 then
          message(game, tr(
            "There is no legal old\nmove to remember.",
            "Es gibt keine legale\nalte Attacke."), done)
          return
        end
        local rows = {}
        for _, candidate in ipairs(candidates) do
          local def = game.data.moves[candidate.id]
          rows[#rows + 1] = {
            label = def and def.name or candidate.id,
            right = sourceLabel(candidate.source),
            value = candidate.id,
          }
        end
        game.stack:push(mod.ui.ListMenu.new(game,
          tr("REMEMBER WHICH?", "WELCHE ERINNERN?"), rows, {
            onCancel = done,
            onChoose = function(item, menu)
              local function finish(replaceIndex)
                local learned = rememberMove(
                  game, mon, item.value, replaceIndex)
                if not learned then
                  message(game, tr("That move cannot\nbe remembered.",
                    "Diese Attacke kann\nnicht erinnert werden."), done)
                  return
                end
                local monName = mon.nickname
                  or (game.data.pokemon[mon.species]
                    and game.data.pokemon[mon.species].name) or mon.species
                local moveName = game.data.moves[item.value].name
                message(game, tr(
                  ("%s remembered\n%s!"):format(monName, moveName),
                  ("%s erinnert sich\nan %s!"):format(monName, moveName)), done)
              end
              menu:close()
              if #mon.moves < 4 then finish() return end
              local replaceRows = {}
              for index, move in ipairs(mon.moves) do
                local def = game.data.moves[move.id]
                replaceRows[#replaceRows + 1] = {
                  label = def and def.name or move.id, value = index,
                }
              end
              game.stack:push(mod.ui.ListMenu.new(game,
                tr("FORGET WHICH?", "WELCHE VERLERNEN?"), replaceRows, {
                  onCancel = done,
                  onChoose = function(replacement, replacementMenu)
                    replacementMenu:close()
                    finish(replacement.value)
                  end,
                }))
            end,
          }))
      end,
    })
  end

  local function nextArchiveRow(game, s)
    local pool = renewableTMs(game)
    if #pool == 0 then return nil, pool end
    local index = s.tmCursor >= #pool and 1 or s.tmCursor + 1
    return pool[index], pool
  end

  function F.claimPendingTMs(game, announceWaiting)
    return deliverPendingTMs(game, state(), announceWaiting ~= false)
  end

  function F.archivedTMs(game)
    local s = state()
    local pool = renewableTMs(game)
    local rows = {}
    for _, row in ipairs(pool) do
      if s.archivedTMs[row.id] then
        rows[#rows + 1] = { id = row.id, number = row.number }
      end
    end
    return rows
  end

  function F.statusText(game)
    local s = state()
    local nextRow, pool = nextArchiveRow(game, s)
    local nextWins = 2 - (s.tmWins % 2)
    local nextName = nextRow and itemName(game, nextRow.id)
      or tr("NONE", "KEINE")
    local waiting = s.pendingTMs[1] and itemName(game, s.pendingTMs[1])
      or tr("NONE", "KEINE")
    return tr(
      ("TM ARCHIVE\nRematch wins: %d\fNext in %d win%s:\n%s\fWaiting: %d\nFirst: %s\fArchive: %d/%d\nFull cycles: %d"):format(
        s.tmWins, nextWins, nextWins == 1 and "" or "s", nextName,
        #s.pendingTMs, waiting, #F.archivedTMs(game), #pool, s.tmCycles),
      ("TM-ARCHIV\nRevanche-Siege: %d\fIn %d Sieg%s folgt:\n%s\fWartend: %d\nZuerst: %s\fArchiv: %d/%d\nVolle Runden: %d"):format(
        s.tmWins, nextWins, nextWins == 1 and "" or "en", nextName,
        #s.pendingTMs, waiting, #F.archivedTMs(game), #pool, s.tmCycles))
  end

  function F.archiveMachineText(game)
    local claimed = F.claimPendingTMs(game, true)
    local status = F.statusText(game)
    return claimed and (claimed .. "\f" .. status) or status
  end

  function F.install(game)
    F.game = game
    local s = state()
    if game.save.inventory and game.save.inventory.FIELD_KIT then
      s.kit = true
      persist(s)
    end

    local BagMenu = require("src.ui.BagMenu")
    if not BagMenu._ascendantFieldKitWrapped then
      BagMenu._ascendantFieldKitWrapped = true
      local originalNew = BagMenu.new
      BagMenu.new = function(menuGame, menuOpts)
        menuOpts = menuOpts or {}
        local list = originalNew(menuGame, menuOpts)
        local originalChoose = list.onChoose
        list.onChoose = function(item, menu)
          if item and item.value == F.ITEM and not menuOpts.battle then
            menu:close()
            F.open(menuGame)
            return
          end
          return originalChoose(item, menu)
        end
        return list
      end
    end

    -- Day-Care and silent rematch growth can replace the oldest move. Keep
    -- exact per-Pokémon evidence so the Reminder may restore it later.
    local Pokemon = require("src.pokemon.Pokemon")
    if not Pokemon._ascendantMoveMemoryWrapped then
      Pokemon._ascendantMoveMemoryWrapped = true
      local vanillaLearn = Pokemon.learnMovesFromDayCare
      Pokemon.learnMovesFromDayCare = function(data, mon, ...)
        local before = {}
        for _, move in ipairs(mon and mon.moves or {}) do before[move.id] = true end
        local result = vanillaLearn(data, mon, ...)
        local after = {}
        for _, move in ipairs(mon and mon.moves or {}) do after[move.id] = true end
        for moveId in pairs(before) do
          if not after[moveId] then recordRememberedMove(mon, moveId) end
        end
        return result
      end
    end

    local MoveLearnMenu = require("src.ui.MoveLearnMenu")
    if not MoveLearnMenu._ascendantMoveMemoryWrapped then
      MoveLearnMenu._ascendantMoveMemoryWrapped = true
      local vanillaUpdate = MoveLearnMenu.update
      MoveLearnMenu.update = function(menu, ...)
        local before = {}
        for _, move in ipairs(menu.mon and menu.mon.moves or {}) do
          before[move.id] = true
        end
        local result = vanillaUpdate(menu, ...)
        local after = {}
        for _, move in ipairs(menu.mon and menu.mon.moves or {}) do
          after[move.id] = true
        end
        for moveId in pairs(before) do
          if not after[moveId] then
            recordRememberedMove(menu.mon, moveId)
          end
        end
        return result
      end
    end
  end

  F.state = state
  F.available = available
  F.fieldRows = fieldRows
  F.forgetMove = forgetMove
  F.recordRememberedMove = recordRememberedMove
  F.reminderMoves = reminderMoves
  F.rememberMove = rememberMove
  F.renewableTMs = renewableTMs
  F.nextArchiveTM = function(game)
    return nextArchiveRow(game, state())
  end
  F.signatureTMs = SIGNATURE_TMS
  F.starterFamilies = STARTER_FAMILIES
  return F
end
