-- Discovery-first Pokédex presentation, legacy certificates and regional
-- Master titles. Species registration never counts as discovery: only the
-- save's ordinary seen/owned flags unlock names, data pages and diplomas.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local beyondKanto = opts.beyondKanto or opts.johtoBoundary
  local D = { game = nil }
  local maximumDex = opts.maximumDex
  local maximumSurface
  function D.bindMaximumSurface(surface) maximumSurface = surface end
  local KANTO_DEX_SIZE = 151
  local NATIONAL_DEX_SIZE = 251
  -- Regional titles refer to the origin-generation groups, not a later
  -- game's regional encounter list (which can contain earlier species).
  local REGIONS = {
    { id = "kanto", en = "Kanto", de = "Kanto" },
    { id = "johto", en = "Johto", de = "Johto" },
    { id = "hoenn", en = "Hoenn", de = "Hoenn" },
    { id = "sinnoh", en = "Sinnoh", de = "Sinnoh" },
    { id = "unova", en = "Unova", de = "Einall" },
    { id = "kalos", en = "Kalos", de = "Kalos" },
    { id = "alola", en = "Alola", de = "Alola" },
    { id = "galar", en = "Galar", de = "Galar" },
    { id = "paldea", en = "Paldea", de = "Paldea" },
  }

  local CERTIFICATES = {
    {
      id = "kanto_150", count = 150,
      title = { en = "KANTO CERTIFICATE", de = "KANTO-ZERTIFIKAT" },
      lines = {
        en = { "The first 150", "Kanto species are", "recorded as owned." },
        de = { "Die ersten 150", "Kanto-Arten wurden", "vollständig gefangen." },
      },
    },
    {
      id = "kanto_151", count = 151,
      title = { en = "MYTH CERTIFICATE", de = "MYTHEN-ZERTIFIKAT" },
      lines = {
        en = { "All 151 Kanto", "species, including", "MEW, are yours." },
        de = { "Alle 151 Kanto-", "Arten samt MEW", "gehören zu dir." },
      },
    },
    {
      id = "national_250", count = 250,
      title = { en = "NATIONAL CERT.", de = "NATIONAL-ZERT." },
      lines = {
        en = { "The first 250", "known species have", "been captured." },
        de = { "Die ersten 250", "bekannten Arten", "wurden gefangen." },
      },
    },
    {
      id = "national_251", count = 251,
      title = { en = "COMPLETE CERT.", de = "KOMPLETT-ZERT." },
      lines = {
        en = { "Every one of all", "251 species is", "recorded as owned." },
        de = { "Alle 251 Arten", "sind als gefangen", "verzeichnet." },
      },
    },
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  if maximumDex then
    for generation, group in ipairs(maximumDex.generations) do
      local region = assert(REGIONS[generation], "missing regional certificate title")
      CERTIFICATES[#CERTIFICATES + 1] = {
        id = "generation_" .. generation, generation = generation, count = #group,
        region = region,
        title = { en = region.en:upper() .. " MASTER", de = region.de:upper() .. "-MEISTER" },
        lines = {
          en = { "All " .. #group .. " species", "from Generation " .. generation,
            "recorded as owned. You are a " .. region.en .. " Master!" },
          de = { "Alle " .. #group .. " Arten", "der Generation " .. generation,
            "als Besitz erfasst. Du bist " .. region.de .. "-Meister!" },
        },
      }
    end
    CERTIFICATES[#CERTIFICATES + 1] = {
      id = "maximum_" .. maximumDex.maximum,
      count = maximumDex.maximum, maximum = true,
      title = { en = "POKéMON MASTER", de = "POKéMON-MEISTER" },
      lines = {
        en = { "All " .. maximumDex.maximum .. " species", "recorded as owned.", "You are a Pokémon Master!" },
        de = { "Alle " .. maximumDex.maximum .. " Arten", "als Besitz erfasst.", "Du bist Pokémon-Meister!" },
      },
    }
  end

  local function localized(row)
    return tr(row.en, row.de)
  end

  local function listTitle(cert)
    if cert.maximum then return tr("MASTER", "MEISTER") end
    if cert.generation then return localized(cert.region):upper() end
    local titles = {
      kanto_150 = { en = "KANTO", de = "KANTO" },
      kanto_151 = { en = "MEW", de = "MEW" },
      national_250 = { en = "NAT.", de = "NAT." },
      national_251 = { en = "ALL", de = "ALLE" },
    }
    return localized(titles[cert.id])
  end

  local function state(create)
    local s = mod.save:get("dex_progress")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 2,
        certificates = {},
        nationalDexUnlocked = false,
      }
      mod.save:set("dex_progress", s)
    end
    if type(s) == "table" then
      local previousVersion = math.floor(tonumber(s.version) or 1)
      -- Public 6.0.0-6.0.2 saves predate the National Dex flag. Remember
      -- exactly one migration opportunity: players whose receiver was
      -- already active at upgrade time receive the National Dex
      -- automatically, while a merely started quest keeps its island gate.
      if previousVersion < 2
          and s.nationalDexLegacyMigration == nil then
        s.nationalDexLegacyMigration = true
      end
      s.version = 2
      s.certificates = type(s.certificates) == "table"
        and s.certificates or {}
      s.nationalDexUnlocked = s.nationalDexUnlocked == true
      s.nationalDexLegacyMigration =
        s.nationalDexLegacyMigration == true
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("dex_progress", s) end
  end

  local function boundaryActive(game)
    return not beyondKanto or type(beyondKanto.isActive) ~= "function"
      or beyondKanto.isActive(game or D.game)
  end

  local function nationalDexText()
    return tr(
      "POKéDEX linked to\nJohto records!\f"
        .. "Your POKéDEX was\nupgraded to the\nNATIONAL DEX!",
      "POKéDEX mit Johto-\nDaten verbunden!\f"
        .. "Dein POKéDEX wurde\nzum NATIONALDEX\nerweitert!")
  end

  function D.hasNationalDex(game)
    if not boundaryActive(game) then return false end
    local s = state(false)
    return type(s) == "table" and s.nationalDexUnlocked == true
  end

  function D.unlockNationalDex(game)
    D.game = game or D.game
    if not boundaryActive(D.game) then
      return false, "beyond-kanto-sealed"
    end
    local s = state()
    if s.nationalDexUnlocked then
      return false, "already-unlocked", nationalDexText()
    end
    s.nationalDexUnlocked = true
    s.nationalDexLegacyMigration = false
    persist(s)
    return true, "unlocked", nationalDexText()
  end

  -- 6.0.0-6.0.2 already let some players repair the physical receiver at
  -- Driftglass before the National Dex milestone existed.  Recognize only
  -- that completed field route.  Remote onboarding may also set
  -- receiverRepaired, so that flag alone must never reveal Johto early.
  function D.reconcileNationalDex(game)
    D.game = game or D.game
    if not boundaryActive(D.game) then
      return false, "beyond-kanto-sealed"
    end
    if D.hasNationalDex(D.game) then return false, "already-unlocked" end
    local s = state()
    local exports = mod.exports or {}
    local signals = exports.johtoSignals
    local early = signals and type(signals.state) == "function"
      and signals.state() or nil
    local inventory = D.game and D.game.save and D.game.save.inventory or {}
    local physicalRepair = type(early) == "table"
      and early.receiverRepaired == true
      and (early.startPolicy == "quest"
        or inventory.MIGRATION_RECEIVER ~= nil)
    local legacyActive = s.nationalDexLegacyMigration == true
      and type(early) == "table"
      and early.receiverRepaired == true
    -- Consume the one-time upgrade inspection even when the old quest had
    -- only begun. A later activation under the new release must still earn
    -- its National Dex at the physical Driftglass researcher.
    if s.nationalDexLegacyMigration then
      s.nationalDexLegacyMigration = false
      persist(s)
    end
    if not physicalRepair and not legacyActive then
      return false, "driftglass-required"
    end
    local unlocked, reason = D.unlockNationalDex(D.game)
    return unlocked, reason
  end

  function D.dexLimit(game)
    local constants = game and game.data and game.data.constants or {}
    -- #252-279 are private save-stable catalogue slots used by optional
    -- later-generation families. They must remain registered for battles,
    -- storage and authored encounters, but the ordinary National Dex ends at
    -- Celebi exactly as its unlock text and completion contract promise.
    local registered = math.min(NATIONAL_DEX_SIZE, math.max(KANTO_DEX_SIZE,
      math.floor(tonumber(constants.dexSize) or KANTO_DEX_SIZE)))
    local full = maximumDex and maximumDex.report(game).complete
    return (full or D.hasNationalDex(game)) and registered or KANTO_DEX_SIZE
  end

  -- The engine's ordinary Pokédex builds its list directly from the global
  -- dexSize constant. Johto species must remain registered for encounters,
  -- saves and battles, so temporarily narrowing that one menu construction
  -- is safer than removing species data. The dispatch slot survives hot
  -- reloads while always calling the newest controller instance.
  local function installPokedexGate()
    local PokedexMenu = require("src.ui.PokedexMenu")
    local patch = rawget(PokedexMenu, "_kantoAscendantNationalDex")
    if type(patch) ~= "table" then
      patch = {
        original = assert(PokedexMenu.new),
        limit = nil,
      }
      PokedexMenu._kantoAscendantNationalDex = patch
      PokedexMenu.new = function(game, menuOpts)
        local constants = game and game.data and game.data.constants
        if type(constants) ~= "table" or type(patch.limit) ~= "function" then
          return patch.original(game, menuOpts)
        end
        local originalSize = constants.dexSize
        local limit = patch.limit(game)
        constants.dexSize = limit
        local ok, menu = pcall(patch.original, game, menuOpts)
        constants.dexSize = originalSize
        if not ok then error(menu, 0) end

        -- Species beyond Celebi are modular and may use private runtime Dex
        -- slots to avoid registry collisions.  Never reveal their mere
        -- registration. Once ordinary seen/owned evidence exists, append the
        -- public National Dex identity in canonical order so every functional
        -- habitat, tournament and reward encounter has a usable Dex entry.
        local dex = game and game.save and game.save.pokedex or {}
        local dexSeen = type(dex.seen) == "table" and dex.seen or {}
        local dexOwned = type(dex.owned) == "table" and dex.owned or {}
        local discovered = {}
        for species, def in pairs(game.data.pokemon or {}) do
          local publicNumber = tonumber(def.sourceDex) or tonumber(def.dex)
          local runtimeNumber = tonumber(def.dex)
          local hasFact = dexOwned[species] == true or dexSeen[species] == true
          local privateCollisionSlot = def.sourceDex == nil
            and runtimeNumber and runtimeNumber >= 252 and runtimeNumber <= 279
          if hasFact and publicNumber and publicNumber > NATIONAL_DEX_SIZE
              and not privateCollisionSlot then
            discovered[#discovered + 1] = {
              species = species,
              definition = def,
              number = publicNumber,
            }
          end
        end
        if patch.maximum then
          local included = {}
          -- Include hidden native placeholders too: discovery of one high
          -- gift must not bypass the existing Johto unlock for other rows.
          for id, def in pairs(game.data.pokemon or {}) do
            local n = tonumber(def.dex)
            if n and n >= 1 and n <= limit then included[id] = true end
          end
          -- Sealed Johto entries remain behind their existing unlock.
          for id, def in pairs(game.data.pokemon or {}) do
            local n = patch.maximum.number(id, def)
            if n and n <= NATIONAL_DEX_SIZE and not def.formId
                and not def.backendForm then included[id] = true end
          end
          discovered = patch.maximum.discovered(game, included)
        end
        table.sort(discovered, function(a, b)
          if a.number ~= b.number then return a.number < b.number end
          return a.species < b.species
        end)
        local digits = math.max(3, math.floor(tonumber(constants.dexDigits) or 3))
        local numberFormat = ("%%0%dd %%s"):format(digits)
        for _, row in ipairs(discovered) do
          menu.items[#menu.items + 1] = {
            label = numberFormat:format(row.number, row.definition.name),
            num = ("%03d"):format(row.number),
            name = row.definition.name,
            ball = dexOwned[row.species] == true or nil,
            value = row.species,
          }
        end

        -- The engine's original "SEEN %d  OWNED %d" footer exceeds the
        -- 18-glyph Game Boy line as soon as either National Dex count reaches
        -- three digits. ListMenu then wraps it onto row seven. Recompute the
        -- visible counts and use a deliberately compact localized footer.
        if type(menu) == "table" then
          local seen, owned = 0, 0
          for _, item in ipairs(menu.items or {}) do
            if item.value then seen = seen + 1 end
            if item.ball then owned = owned + 1 end
          end
          menu.seenCount, menu.ownedCount = seen, owned
          if seen >= 1000 or owned >= 1000 then
            menu.footer = tr(("S:%d O:%d"):format(seen, owned),
              ("G:%d B:%d"):format(seen, owned))
          elseif seen >= 100 or owned >= 100 or #discovered > 0 then
            menu.footer = tr(("SEEN %d OWN %d"):format(seen, owned),
              ("GES.%d GEF.%d"):format(seen, owned))
          end
        end
        return menu
      end
    end
    patch.limit = function(game)
      return D.dexLimit(game)
    end
    patch.maximum = maximumDex
    if maximumDex then
      local Entry = require("src.ui.DexEntryMenu")
      local entryPatch = rawget(Entry, "_kascMaximumDex67")
      if not entryPatch then
        entryPatch = { original = Entry.new, render = Entry.render }
        Entry._kascMaximumDex67 = entryPatch
        Entry.new = function(game, args, ...)
          local page = entryPatch.original(game, args, ...)
          local id = type(args) == "table" and (args.species or args[1]) or args
          if page and page.def and entryPatch.owner then
            page.def = entryPatch.owner.entryDefinition(id, page.def)
          end
          return page
        end
        if type(entryPatch.render) == "function" then
          Entry.render = function(game, def, ...)
            if def and entryPatch.owner then
              def = entryPatch.owner.entryDefinition(def.id, def)
            end
            return entryPatch.render(game, def, ...)
          end
        end
      end
      entryPatch.owner = maximumDex
    end
    return true
  end

  local function dexIndex(game)
    local out = {}
    for id, def in pairs(game and game.data and game.data.pokemon or {}) do
      local n = tonumber(def.dex)
      if n and n >= 1 and n <= 251 and not out[n] then
        out[n] = id
      end
    end
    return out
  end

  -- The engine deliberately quarantines mod-owned Pokémon while a mod is
  -- disabled. Their records return to the PC when the species is available
  -- again, but unknown Pokédex flags cannot survive the mod-off validation
  -- pass. Rebuild only knowledge that physical save storage proves: a
  -- Pokémon in the party, PC, Day-Care or still-known quarantine is both
  -- seen and owned. No registered-but-unencountered species is revealed.
  local function repairOwnedFromStorage(game)
    local save = game and game.save
    local known = game and game.data and game.data.pokemon
    if type(save) ~= "table" or type(known) ~= "table" then return 0 end
    save.pokedex = type(save.pokedex) == "table" and save.pokedex or {}
    local seen = type(save.pokedex.seen) == "table"
      and save.pokedex.seen or {}
    local owned = type(save.pokedex.owned) == "table"
      and save.pokedex.owned or {}
    save.pokedex.seen = seen
    save.pokedex.owned = owned

    local repaired = {}
    local function mark(mon)
      -- Eggs already carry their eventual species internally, but the
      -- Day-Care deliberately registers that species only when it hatches.
      -- Treating an unhatched egg as owned here would reveal its Dex entry.
      if type(mon) == "table" and mon.isEgg then return end
      local species = type(mon) == "table" and mon.species
      if type(species) ~= "string" or not known[species] then return end
      if seen[species] ~= true or owned[species] ~= true then
        repaired[species] = true
      end
      seen[species] = true
      owned[species] = true
    end
    local function markList(list)
      for _, mon in ipairs(type(list) == "table" and list or {}) do mark(mon) end
    end

    markList(save.party)
    markList(save.box)
    for _, box in ipairs(type(save.boxes) == "table" and save.boxes or {}) do
      markList(box)
    end
    if type(save.daycare) == "table" then mark(save.daycare.mon) end
    if type(save.orphaned) == "table" then markList(save.orphaned.mons) end

    local count = 0
    for _ in pairs(repaired) do count = count + 1 end
    return count
  end

  local function ownedThrough(game, maximum)
    local byDex = dexIndex(game)
    local owned = game and game.save and game.save.pokedex
      and game.save.pokedex.owned or {}
    local count = 0
    for n = 1, maximum do
      local id = byDex[n]
      if id and owned[id] then count = count + 1 end
    end
    return count
  end

  local function complete(game, maximum)
    return ownedThrough(game, maximum) >= maximum
  end

  local function refresh(game)
    local s = state()
    local newly = {}
    for _, cert in ipairs(CERTIFICATES) do
      local eligible
      if cert.maximum or cert.generation then
        eligible = maximumDex.report(game, cert.generation).complete
      else eligible = complete(game, cert.count) end
      if not s.certificates[cert.id] and eligible then
        s.certificates[cert.id] = true
        newly[#newly + 1] = cert
      end
    end
    s.pokemonMaster = maximumDex and s.certificates["maximum_" .. maximumDex.maximum] == true or false
    s.regionalMasters = {}
    if maximumDex then
      for generation, region in ipairs(REGIONS) do
        if s.certificates["generation_" .. generation] == true then
          s.regionalMasters[region.id] = true
        end
      end
    end
    persist(s)
    return newly
  end

  function D.masterTitle(game)
    if game then refresh(game) end
    local s = state(false)
    return s and s.pokemonMaster and tr("Pokémon Master", "Pokémon-Meister") or nil
  end

  function D.regionalTitle(generation, game)
    if game then refresh(game) end
    local region = REGIONS[generation]
    local s = state(false)
    if not region or not s or not s.regionalMasters or not s.regionalMasters[region.id] then return nil end
    return tr(region.en .. " Master", region.de .. "-Meister")
  end

  local function certificateMenu(game, title, rows, args)
    local menu = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game, title, rows, args)
    return maximumSurface and maximumSurface.fitMenu(menu) or menu
  end

  local Certificate = {}
  Certificate.__index = Certificate
  Certificate.isOpaque = true

  function Certificate.new(game, cert, onDone)
    if cert.maximum or cert.generation then
      local lines = cert.lines[i18n and i18n.isGerman() and "de" or "en"]
      local rows = {
        { label = tr("TRAINER", "TRAINER"), right = game.save.player.name or "RED" },
        { label = tr("OWNED", "ERHALTEN"), right = ("%d/%d"):format(cert.count, cert.count) },
        { label = tr("COMPLETE", "VOLLSTÄNDIG"), help = table.concat(lines, " ") },
      }
      rows[#rows + 1] = { label = tr("BACK", "ZURÜCK"), value = "back" }
      -- Reuse the existing fullscreen/ORAS ListMenu surface, never a new
      -- hardcoded 160px certificate layered over the wide UI.
      return certificateMenu(game,
        localized(cert.title), rows, {
          onCancel = onDone,
          onChoose = function(item)
            if item.value == "back" then
              game.stack:pop()
              if onDone then onDone() end
            end
          end,
        })
    end
    return setmetatable({ game = game, cert = cert, onDone = onDone },
      Certificate)
  end

  function Certificate:update()
    local input = self.game.input
    if input:wasPressed("a") or input:wasPressed("b") then
      self.game.stack:pop()
      if self.onDone then self.onDone() end
    end
  end

  function Certificate:draw()
    local Font = require("src.render.Font")
    local g = love.graphics
    g.setColor(1, 1, 1, 1)
    g.rectangle("fill", 0, 0, 160, 144)
    g.setColor(0.72, 0.46, 0.04, 1)
    g.rectangle("line", 2.5, 2.5, 155, 139)
    g.rectangle("line", 5.5, 5.5, 149, 133)
    g.setColor(0, 0, 0, 1)
    Font.draw(localized(self.cert.title), 16, 16)
    Font.draw(tr("PLAYER", "TRAINER"), 16, 34)
    Font.draw(self.game.save.player.name or "RED", 80, 34)
    local lines = self.cert.lines[i18n and i18n.isGerman()
      and "de" or "en"]
    for index, line in ipairs(lines) do
      Font.draw(line, 16, 58 + (index - 1) * 12)
    end
    Font.draw(("%03d/251"):format(self.cert.count), 48, 104)
    Font.draw("GAME FREAK", 72, 124)
    g.setColor(1, 1, 1, 1)
  end

  local function openList(game, onDone)
    refresh(game)
    local s = state()
    local rows = {}
    for _, cert in ipairs(CERTIFICATES) do
      local earned = s.certificates[cert.id] == true
      if earned then
        rows[#rows + 1] = {
          label = ("%03d %s"):format(cert.count, listTitle(cert)),
          right = "OK",
          help = localized(cert.title),
          value = cert,
        }
      end
    end
    game.stack:push(certificateMenu(game,
      #rows == 1 and tr("DEX CERTIFICATE", "DEX-ZERTIFIKAT")
        or tr("DEX CERTIFICATES", "DEX-ZERTIFIKATE"), rows, {
        pageJump = true,
        onCancel = onDone,
        onChoose = function(item)
          if item.value then
            game.stack:push(Certificate.new(game, item.value))
          end
        end,
      }))
  end

  if mod.content and mod.content.screens then
    mod.content.screens:register("AscendantCertificates", {
      new = function(game, args)
        args = args or {}
        refresh(game)
        local s = state()
        local rows = {}
        for _, cert in ipairs(CERTIFICATES) do
          local earned = s.certificates[cert.id] == true
          if earned then
            rows[#rows + 1] = {
              label = ("%03d %s"):format(cert.count, listTitle(cert)),
              right = "OK",
              value = cert,
            }
          end
        end
        return certificateMenu(game,
          #rows == 1 and tr("DEX CERTIFICATE", "DEX-ZERTIFIKAT")
            or tr("DEX CERTIFICATES", "DEX-ZERTIFIKATE"), rows, {
            pageJump = true,
            onCancel = args.onDone,
            onChoose = function(item)
              if item.value then
                game.stack:push(Certificate.new(game, item.value))
              end
            end,
          })
      end,
    })
  end

  if mod.content and mod.content.map_scripts then
    mod.content.map_scripts:register("CELADON_MANSION_3F", {
      priority = 2200,
      talk = {
        TEXT_CELADONMANSION3F_GAME_DESIGNER = function(game, ow, npc, done)
          local count = ownedThrough(game, 251)
          local newly = refresh(game)
          if count < 150 and next(state().certificates) == nil then
            game.stack:push(require("src.render.TextBox").new(game, tr(
              ("GAME DESIGNER:\nYour POKéDEX shows\n%d/150.\fKeep discovering and\ncatching POKéMON!"):format(
                ownedThrough(game, 150)),
              ("GAME DESIGNER:\nDein POKéDEX zeigt\n%d/150.\fEntdecke und fange\nweitere POKéMON!"):format(
                ownedThrough(game, 150))), done))
            return
          end
          local earned = 0
          for _, value in pairs(state().certificates) do
            if value == true then earned = earned + 1 end
          end
          local intro = #newly > 0 and tr(
            "A new completion\ncertificate is ready!",
            "Ein neues Abschluss-\nZertifikat ist bereit!")
            or (earned == 1 and tr(
              "Your earned Pokédex\ncertificate is kept\nhere.",
              "Dein verdientes\nPokédex-Zertifikat\nwird hier verwahrt.")
            or tr(
                "Your earned Pokédex\ncertificates are kept\nhere.",
                "Deine verdienten\nPokédex-Zertifikate\nwerden hier verwahrt."))
          game.stack:push(require("src.render.TextBox").new(game, intro,
            function() openList(game, done) end))
        end,
      },
    })
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" then return out end
    refresh(game)
    if next(state().certificates) == nil then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = tr("CERT.", "ZERT."),
      ascendantMenu = true,
      ascendantLabel = tr("DEX CERTIFICATES", "DEX-ZERTIFIKATE"),
      ascendantOrder = 60,
      onSelect = function() mod.ui.push(game, "AscendantCertificates") end,
    })
  end, 245)

  mod.events:on("pokemon.caught", function(ev)
    if D.game then refresh(D.game) end
  end)

  function D.install(game)
    D.game = game
    installPokedexGate()
    if maximumSurface then maximumSurface.install() end
    repairOwnedFromStorage(game)
    state()
    D.reconcileNationalDex(game)
    refresh(game)
  end

  -- save.loaded fires after the engine has reclaimed known quarantined
  -- Pokémon, which is the exact point at which their erased Dex facts can be
  -- derived again without pre-filling any unseen entry.
  mod.events:on("save.loaded", function(ev)
    D.install(ev and ev.game or D.game)
  end, 280)

  D.state = state
  D.boundaryActive = boundaryActive
  D.ownedThrough = ownedThrough
  D.complete = complete
  D.refresh = refresh
  D.nationalDexText = nationalDexText
  D.installPokedexGate = installPokedexGate
  D.repairOwnedFromStorage = repairOwnedFromStorage
  D.certificates = CERTIFICATES
  D.open = openList
  return D
end
