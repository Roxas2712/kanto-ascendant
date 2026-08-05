-- Discovery-first Pokédex presentation and the four Ascendant completion
-- certificates.  Species registration never counts as discovery: only the
-- save's ordinary seen/owned flags unlock names, data pages and diplomas.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local D = { game = nil }
  local KANTO_DEX_SIZE = 151

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

  local function localized(row)
    return tr(row.en, row.de)
  end

  local function listTitle(cert)
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
      s.version = 2
      s.certificates = type(s.certificates) == "table"
        and s.certificates or {}
      s.nationalDexUnlocked = s.nationalDexUnlocked == true
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("dex_progress", s) end
  end

  local function nationalDexText()
    return tr(
      "POKéDEX linked to\nJohto records!\f"
        .. "Your POKéDEX was\nupgraded to the\nNATIONAL DEX!",
      "POKéDEX mit Johto-\nDaten verbunden!\f"
        .. "Dein POKéDEX wurde\nzum NATIONALDEX\nerweitert!")
  end

  function D.hasNationalDex()
    local s = state(false)
    return type(s) == "table" and s.nationalDexUnlocked == true
  end

  function D.unlockNationalDex(game)
    D.game = game or D.game
    local s = state()
    if s.nationalDexUnlocked then
      return false, "already-unlocked", nationalDexText()
    end
    s.nationalDexUnlocked = true
    persist(s)
    return true, "unlocked", nationalDexText()
  end

  -- 6.0.0-6.0.2 already let some players repair the physical receiver at
  -- Driftglass before the National Dex milestone existed.  Recognize only
  -- that completed field route.  Remote onboarding may also set
  -- receiverRepaired, so that flag alone must never reveal Johto early.
  function D.reconcileNationalDex(game)
    D.game = game or D.game
    if D.hasNationalDex() then return false, "already-unlocked" end
    local exports = mod.exports or {}
    local signals = exports.johtoSignals
    local early = signals and type(signals.state) == "function"
      and signals.state() or nil
    local inventory = D.game and D.game.save and D.game.save.inventory or {}
    local physicalRepair = type(early) == "table"
      and early.receiverRepaired == true
      and (early.startPolicy == "quest"
        or inventory.MIGRATION_RECEIVER ~= nil)
    if not physicalRepair then return false, "driftglass-required" end
    local unlocked, reason = D.unlockNationalDex(D.game)
    return unlocked, reason
  end

  function D.dexLimit(game)
    local constants = game and game.data and game.data.constants or {}
    local registered = math.max(KANTO_DEX_SIZE,
      math.floor(tonumber(constants.dexSize) or KANTO_DEX_SIZE))
    return D.hasNationalDex() and registered or KANTO_DEX_SIZE
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
        constants.dexSize = patch.limit(game)
        local ok, menu = pcall(patch.original, game, menuOpts)
        constants.dexSize = originalSize
        if not ok then error(menu, 0) end
        return menu
      end
    end
    patch.limit = function(game)
      return D.dexLimit(game)
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
      if not s.certificates[cert.id] and complete(game, cert.count) then
        s.certificates[cert.id] = true
        newly[#newly + 1] = cert
      end
    end
    persist(s)
    return newly
  end

  local Certificate = {}
  Certificate.__index = Certificate
  Certificate.isOpaque = true

  function Certificate.new(game, cert, onDone)
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
          value = cert,
        }
      end
    end
    game.stack:push(mod.ui.ListMenu.new(game,
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
        return mod.ui.ListMenu.new(game,
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
          if count < 150 then
            game.stack:push(require("src.render.TextBox").new(game, tr(
              ("GAME DESIGNER:\nYour POKéDEX shows\n%d/150.\fKeep discovering and\ncatching POKéMON!"):format(
                ownedThrough(game, 150)),
              ("GAME DESIGNER:\nDein POKéDEX zeigt\n%d/150.\fEntdecke und fange\nweitere POKéMON!"):format(
                ownedThrough(game, 150))), done))
            return
          end
          local newly = refresh(game)
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
    if type(out) ~= "table" or ownedThrough(game, 150) < 150 then return out end
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
