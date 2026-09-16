-- Kanto Ascendant's bounded private Classic Link policy.
--
-- The engine owns transport, room codes, the wire protocol, party transfer
-- and lockstep battles. This module only opens the reviewed private-room
-- engine state, tightens its peer check and keeps KASC's save-dependent
-- mechanics out of link battles. It never reads or stores a room code.

return function(mod, opts)
  opts = opts or {}
  local M = {
    OWNER = "kasc.private-classic-link/v1",
    ENGINE_API = "src.link.LinkState.new@0.1.90",
    ENGINE_VERSION = "0.1.90",
    MOD_API_VERSION = 2,
    LINK_PROTOCOL = 2,
    MOD_ID = "kanto_ascendant",
    MOD_VERSION = "6.6.0-rc.1",
    REVIEWED_ENGINES = { ["0.1.90"] = true, ["0.2.56"] = true },
  }
  local installed = false
  local uiInstalled = false
  local i18n = opts.i18n
  local generationRules = opts.generationRules

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function finiteNumber(value)
    return value == value and value ~= math.huge and value ~= -math.huge
  end

  local function portable(value, depth, seen)
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return true end
    if kind == "number" then
      return finiteNumber(value), "non-finite number"
    end
    if kind ~= "table" then return false, "non-portable value" end
    if depth >= 8 then return false, "metadata nesting is too deep" end
    if seen[value] then return false, "cyclic metadata" end
    seen[value] = true
    for key, child in pairs(value) do
      local keyKind = type(key)
      if keyKind ~= "string" and keyKind ~= "number" then
        seen[value] = nil
        return false, "non-portable metadata key"
      end
      if keyKind == "number" and not finiteNumber(key) then
        seen[value] = nil
        return false, "non-finite metadata key"
      end
      local ok, why = portable(child, depth + 1, seen)
      if not ok then
        seen[value] = nil
        return false, why
      end
    end
    seen[value] = nil
    return true
  end

  function M.battleFeatureAllowed(battle, _feature)
    return not (battle and (battle.kind == "link"
      or battle.ascendantNoSaveMechanics == true))
  end

  function M.rulesReceipt(game)
    if not (generationRules
        and type(generationRules.rulesReceipt) == "function") then
      return nil, "generation_rules_unavailable"
    end
    return generationRules.rulesReceipt(game)
  end

  function M.attachRulesReceipt(hello, game)
    if type(hello) ~= "table" then return false, "hello" end
    local receipt, why = M.rulesReceipt(game)
    if not receipt then return false, why end
    hello.kascGenerationRules = receipt
    return true, receipt
  end

  function M.compatibleRules(localHello, peerHello)
    if not generationRules or not generationRules.receipts then return true end
    local compare = generationRules.receipts.compatibleLink
      or generationRules.receipts.compatible
    return compare(
      type(localHello)=="table" and localHello.kascGenerationRules,
      type(peerHello)=="table" and peerHello.kascGenerationRules)
  end

  -- Valid metadata is retained by identity. Invalid KASC metadata is removed
  -- in isolation; another mod's extra namespace is never inspected or erased.
  function M.auditProvenance(mon)
    if type(mon) ~= "table" then return false, nil, "invalid mon" end
    if mon.extra == nil then return true, nil end
    if type(mon.extra) ~= "table" then return false, nil, "invalid extra bag" end
    local provenance = mon.extra.kanto_ascendant
    if provenance == nil then return true, nil end
    if type(provenance) ~= "table" then
      mon.extra.kanto_ascendant = nil
      return false, nil, "provenance is not a table"
    end
    local ok, why = portable(provenance, 0, {})
    if not ok then
      mon.extra.kanto_ascendant = nil
      return false, nil, why
    end
    return true, provenance
  end

  local function linkStateModule()
    if opts.linkState ~= nil then return opts.linkState end
    local ok, value = pcall(require, "src.link.LinkState")
    if ok then return value end
    return nil
  end

  local function linkHandshakeModule()
    if opts.linkHandshake ~= nil then return opts.linkHandshake end
    local ok, value = pcall(require, "src.link.Handshake")
    if ok then return value end
    return nil
  end

  local function linkRuntimeModule()
    if opts.linkRuntime ~= nil then return opts.linkRuntime end
    local ok, value = pcall(require, "src.mods.Runtime")
    if ok then return value end
    return nil
  end

  local function affectingMods(hello)
    if type(hello) ~= "table" or type(hello.mods) ~= "table" then
      return nil, "mods_missing"
    end
    local result = {}
    local seen = {}
    local requiredModSeen = false
    local count, highest = 0, 0
    for key in pairs(hello.mods) do
      if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
        return nil, "mods_invalid"
      end
      count = count + 1
      highest = math.max(highest, key)
    end
    if count ~= highest then return nil, "mods_invalid" end
    for index = 1, count do
      local entry = hello.mods[index]
      if type(entry) ~= "table" or type(entry.id) ~= "string"
          or entry.id == "" or type(entry.version) ~= "string"
          or entry.version == "" or type(entry.affectsLink) ~= "boolean" then
        return nil, "mods_invalid"
      end
      if seen[entry.id] then return nil, "mods_duplicate" end
      seen[entry.id] = true
      if entry.id == M.MOD_ID then
        if entry.version ~= M.MOD_VERSION or entry.affectsLink ~= true then
          return nil, "kasc_mod_mismatch"
        end
        requiredModSeen = true
      end
      if entry.affectsLink then
        result[#result + 1] = table.concat({
          entry.id,
          entry.version,
          "true",
        }, "@")
      end
    end
    if not requiredModSeen then return nil, "kasc_mod_missing" end
    table.sort(result)
    return table.concat(result, "|")
  end

  local function supportedHello(hello)
    if type(hello) ~= "table" or hello.type ~= "hello" then
      return false, "hello_missing"
    end
    if hello.protocol ~= M.LINK_PROTOCOL then
      return false, "protocol_mismatch"
    end
    if type(hello.engineVersion) ~= "string"
        or not M.REVIEWED_ENGINES[hello.engineVersion] then
      return false, "engine_mismatch"
    end
    if hello.apiVersion ~= M.MOD_API_VERSION
        and not (hello.engineVersion=="0.2.56"
          and hello.apiVersion==tostring(M.MOD_API_VERSION)) then
      return false, "api_mismatch"
    end
    if hello.linkModified ~= true then
      return false, "link_modified_mismatch"
    end
    if type(hello.fingerprint) ~= "string" or hello.fingerprint == "" then
      return false, "fingerprint_missing"
    end
    if #hello.fingerprint ~= 16
        or not hello.fingerprint:match("^[0-9a-f]+$") then
      return false, "fingerprint_invalid"
    end
    local _, why = affectingMods(hello)
    if why then return false, why end
    return true
  end

  -- Handshake.checkCompat in the reviewed engine intentionally compares only
  -- the SemVer major. That is suitable for vanilla negotiation, but a KASC
  -- private room promises an exact build. Tighten all public hello fields
  -- before the engine is allowed to transfer either party.
  function M.compatibleHello(localHello, peerHello, Handshake)
    local localOk, localWhy = supportedHello(localHello)
    if not localOk then return false, localWhy end
    local peerOk, peerWhy = supportedHello(peerHello)
    if not peerOk then return false, peerWhy end
    if localHello.engineVersion ~= peerHello.engineVersion then
      return false, "engine_mismatch"
    end
    if localHello.fingerprint ~= peerHello.fingerprint then
      return false, "fingerprint_mismatch"
    end
    local localMods = assert(affectingMods(localHello))
    local peerMods = assert(affectingMods(peerHello))
    if localMods ~= peerMods then
      return false, "mods_mismatch"
    end
    local rulesOk, rulesWhy = M.compatibleRules(localHello, peerHello)
    if not rulesOk then return false, rulesWhy end
    local verdict, why = Handshake.checkCompat(localHello, peerHello)
    if verdict ~= "full" then
      return false, why or verdict or "fingerprint_mismatch"
    end
    return true, "full"
  end

  local function refuse(state, mode, isHost, reason)
    state.verdict = "refused"
    state.kascRejectReason = reason or "fingerprint_mismatch"
    local labels = {
      hello_missing = "PEER HELLO INVALID",
      protocol_mismatch = "PROTOCOL MISMATCH",
      engine_mismatch = "ENGINE MISMATCH",
      missing_rules_receipt = "KASC RULES MISSING",
      invalid_rules_receipt = "KASC RULES INVALID",
      rules_profile = "KASC RULES DIFFER",
      rules_data_hash = "KASC RULES DIFFER",
      api_mismatch = "MOD API MISMATCH",
      link_modified_mismatch = "LINK FLAG MISMATCH",
      fingerprint_missing = "DATA ID MISSING",
      fingerprint_invalid = "DATA ID INVALID",
      fingerprint_mismatch = "GAME DATA MISMATCH",
      mods_missing = "MOD LIST MISSING",
      mods_invalid = "MOD LIST INVALID",
      mods_duplicate = "DUPLICATE MOD ID",
      kasc_mod_missing = "KASC MOD MISSING",
      kasc_mod_mismatch = "KASC MOD MISMATCH",
      mods_mismatch = "LINK MODS MISMATCH",
    }
    -- Never delegate malformed peer data to Handshake.describe: the stock
    -- 0.1.90 formatter assumes a well-formed mod array. A fixed bounded
    -- notice is both safer and unambiguous that subset trading is disabled.
    state.noticeLines = {
      "KASC LINK REFUSED",
      labels[state.kascRejectReason] or "PEER DATA INVALID",
      "NO BATTLE OR TRADE",
      "PRESS A TO RETURN",
    }
    state.noticeExits = true
    state.stage = "notice"
    local Runtime = linkRuntimeModule()
    if Runtime and type(Runtime.emit) == "function" then
      local peer = state.peerHello
      pcall(Runtime.emit, "link.connected", {
        role = isHost and "host" or "guest",
        remote = {
          name = peer and peer.name or state.peerName,
          mode = mode,
          mods = peer and peer.mods,
          fingerprint = peer and peer.fingerprint,
        },
        refused = true,
        reason = state.kascRejectReason,
      })
    end
    return false, state.kascRejectReason
  end

  -- The supported 0.1.90 client exposes one ordinary LinkState constructor.
  -- Its ONLINE MATCH submenu owns both room-code hosting and joining. KASC
  -- starts that exact public state and wraps only decideCompat; no transport,
  -- relay URL, token, room code or socket is owned here.
  local function currentPrivateState(game, LinkState)
    if type(LinkState.new) ~= "function" then return nil, "engine_missing" end
    local Handshake = linkHandshakeModule()
    if not (Handshake and type(Handshake.hello) == "function"
        and type(Handshake.checkCompat) == "function"
        and type(Handshake.describe) == "function") then
      return nil, "handshake_missing"
    end
    local helloOk, localHello = pcall(Handshake.hello, game, nil)
    if not helloOk then return nil, "engine_error" end
    local supported, supportWhy = supportedHello(localHello)
    if not supported then return nil, supportWhy end
    if generationRules and localHello.engineVersion=="0.2.56" then
      local loaded,wire=pcall(require,"src.link.Wire")
      if not (loaded and opts.wireAdapter
          and opts.wireAdapter.install(wire,generationRules.receipts)) then
        return nil,"handshake_missing"
      end
    end

    local ok, state = pcall(LinkState.new, game)
    if not ok or type(state) ~= "table" then return nil, "engine_error" end
    local baseDecide = state.decideCompat
    local baseUpdate = state.update
    local baseExitWith = state.exitWith
    if type(baseDecide) ~= "function" then return nil, "handshake_missing" end
    if type(baseUpdate) ~= "function" or type(baseExitWith) ~= "function" then
      return nil, "engine_missing"
    end

    state.stage = localHello.engineVersion == "0.2.56" and "menu" or "onlineMenu"
    state.index = 1
    state.kascPrivateOnline = true
    state.kascPolicyOwner = M.OWNER
    state.requireFullCompat = true
    state.kascExpectedEngineVersion = localHello.engineVersion
    state.kascExpectedModApi = M.MOD_API_VERSION
    state.kascExpectedLinkProtocol = M.LINK_PROTOCOL
    state.kascExpectedModId = M.MOD_ID
    state.kascExpectedModVersion = M.MOD_VERSION
    state.kascTransportKind = localHello.engineVersion == "0.2.56" and "lan" or "relay"
    if generationRules then
      if type(state.sendHello) ~= "function" then return nil, "handshake_missing" end
      -- Same native sendHello seam, with the receipt attached BEFORE the
      -- native session serializes the message. No global Handshake patch,
      -- socket, room code, endpoint or save payload is owned by this adapter.
      state.sendHello = function(self, mode)
        local hello = Handshake.hello(self.game, mode)
        local attached, why = M.attachRulesReceipt(hello, self.game)
        if not attached then return refuse(self, mode, self.isHost, why) end
        -- Wire 0.2.56 declares apiVersion as a string field, whereas the
        -- native Hello producer emits a number. Preserve it through that
        -- sanitizer without relaxing the exact value check on either peer.
        if hello.engineVersion=="0.2.56" then
          hello.apiVersion=tostring(hello.apiVersion)
        end
        self.myHello = hello
        return self.net:send(hello)
      end
    end
    state.decideCompat = function(self, mode, isHost)
      self.isHost = isHost
      self.pendingMode = mode
      self.myHello = self.myHello
        or Handshake.hello(self.game, isHost and mode or nil)
      if generationRules and not self.myHello.kascGenerationRules then
        return refuse(self, mode, isHost, "missing_rules_receipt")
      end
      if generationRules then
        local current = {}
        local attached, reason = M.attachRulesReceipt(current, self.game)
        if not attached then return refuse(self, mode, isHost, reason) end
        local same, why = M.compatibleRules(self.myHello, current)
        if not same then return refuse(self, mode, isHost, why) end
      end
      local compatible, reason = M.compatibleHello(
        self.myHello, self.peerHello, Handshake)
      if compatible then return baseDecide(self, mode, isHost) end
      return refuse(self, mode, isHost, reason)
    end
    state.update = function(self, dt)
      local input = self.game and self.game.input
      if self.stage == "onlineMenu" and input
          and type(input.wasPressed) == "function"
          and input:wasPressed("b") then
        -- The stock state returns from onlineMenu to its public root, which
        -- also exposes LAN and Tournament. This Card has one private action:
        -- Back therefore closes the engine state and reveals the KASC menu.
        return baseExitWith(self, nil, "bye")
      end
      return baseUpdate(self, dt)
    end
    return state
  end

  function M.releaseAvailable()
    -- Keep the historical seam testable without widening its release grant.
    -- Real loader contexts always carry the installed manifest.
    return not mod.manifest or mod.manifest.version==M.MOD_VERSION
  end

  function M.openPrivateOnline(game)
    if not M.releaseAvailable() then return false,"release_deferred" end
    if not (game and game.stack and type(game.stack.push) == "function") then
      return false, "stack"
    end
    local LinkState = linkStateModule()
    if not LinkState then return false, "engine_missing" end
    local previousLinkSession = game.linkSession
    local state, why = currentPrivateState(game, LinkState)
    if not state then
      -- LinkState.new claims the session before returning. A rejected engine
      -- seam must not leave the normal game stuck at link speed.
      game.linkSession = previousLinkSession
      return false, why or "engine_error"
    end
    game.stack:push(state)
    return true, state
  end

  -- The combined 6.6 UI predates the optional guidedList convenience
  -- constructor. Keep the Card on the existing Ascendant ListMenu owner and
  -- synthesize only its own visible HELP row when that helper is unavailable.
  local function guidedList(ui, game, spec)
    if type(ui.guidedList) == "function" then
      return ui.guidedList(game, spec)
    end
    local ListMenu = ui.ListMenu
    if not (ListMenu and type(ListMenu.new) == "function"
        and type(ui.showHelp) == "function") then return nil end
    local rows = {}
    for index, item in ipairs(spec.rows or {}) do rows[index] = item end
    local helpValue = "__kasc_help:" .. tostring(spec.key)
    rows[#rows + 1] = {
      value = helpValue,
      label = tr("HELP", "HILFE"),
      help = spec.help,
      kascPrivateLinkHelp = true,
    }
    local function show(title, body)
      return ui.showHelp(game, title or spec.helpTitle or spec.title,
        body or spec.help)
    end
    return ListMenu.new(game, spec.title, rows, {
      ascendantLayout = true,
      footer = spec.footer,
      ascendantFocusHelp = function(item) return item and item.help end,
      onSelectKey = function(item)
        return show(item and item.label, item and item.help)
      end,
      onChoose = function(item)
        if item and item.value == helpValue then return show() end
        if spec.onChoose then return spec.onChoose(item) end
      end,
    })
  end

  function M.installUi(ui)
    if uiInstalled then return true end
    local guided = ui and type(ui.guidedList) == "function"
    local releasedList = ui and ui.ListMenu
      and type(ui.ListMenu.new) == "function"
      and type(ui.showHelp) == "function"
    if not ((guided or releasedList) and mod.content and mod.content.screens
        and type(mod.content.screens.register) == "function") then
      return false
    end
    uiInstalled = true
    mod.content.screens:register("AscendantLinkMenu", {
      new = function(game)
        if not M.releaseAvailable() then
          return guidedList(ui, game, {
            key="kasc_link_67_deferred",title=tr("KASC LINK","KASC LINK"),
            helpTitle=tr("KASC LINK HELP","KASC-LINK-HILFE"),
            help=tr("Link battles and trades are not approved for this KASC release. Your save is unchanged.",
              "Link-Kämpfe und Tauschen sind für diesen KASC-Release noch nicht freigegeben. Dein Spielstand bleibt unverändert."),
            rows={{value="release_deferred",label=tr("NOT RELEASED","NICHT FREIGEGEBEN"),
              help=tr("Link approval is deferred for this release.","Die Link-Freigabe ist für diesen Release zurückgestellt.")}},
            footer=tr("B:BACK","B:ZURÜCK"),
          })
        end
        local loaded, version = pcall(require, "src.core.Version")
        local lan = loaded and version.engine == "0.2.56"
        local help = tr(
          "Open a private room-code link through the engine's online relay. Both players need the exact same engine release, Mod API, edition data, Kanto Ascendant version and every link-affecting mod.\n\nTrades keep portable Pokémon data. Link battles use Classic rules: Mega Evolution and save-dependent KASC mechanics stay off. Story progress is not compared or transferred.\n\nThis does not enable public tournament matchmaking.",
          "Öffne über den Online-Dienst der Engine einen privaten Raum mit Code. Beide Spieler brauchen exakt dieselbe Engine-Version, Mod-API, Editionsdaten, Kanto-Ascendant-Version und alle linkrelevanten Mods.\n\nBeim Tausch bleiben übertragbare Pokémon-Daten erhalten. Link-Kämpfe nutzen klassische Regeln: Mega-Entwicklung und spielstandabhängige KASC-Mechaniken bleiben aus. Storyfortschritt wird weder verglichen noch übertragen.\n\nDas öffentliche Turnier-Matchmaking wird dadurch nicht freigeschaltet.")
        if lan then
          help = tr(
            "Link over your local network: one player hosts; the other enters the host IP. This engine has no online room-code relay. Both need the same engine, KASC build, link-affecting mods and active battle rules. AUTO and manual selection may match when their effective rules match.\n\nClassic link policy: Mega and save-dependent KASC mechanics stay off. Story progress is not transferred. New forms, items and abilities still require the two-client release check.",
            "Link im lokalen Netzwerk: Einer hostet, der andere gibt dessen IP ein. Diese Engine bietet keinen Online-Raumcode-Dienst. Engine, KASC-Build, linkrelevante Mods und aktive Kampfregeln müssen übereinstimmen. AUTO und manuelle Auswahl dürfen bei gleichen wirksamen Regeln zusammenpassen.\n\nKlassischer Linkmodus: Mega und spielstandabhängige KASC-Mechaniken bleiben aus. Storyfortschritt wird nicht übertragen. Neue Formen, Items und Fähigkeiten benötigen noch die Zwei-Client-Releaseprüfung.")
        end
        return guidedList(ui, game, {
          key = "kasc_link_66",
          title = tr("KASC LINK", "KASC LINK"),
          helpTitle = tr("KASC LINK HELP", "KASC-LINK-HILFE"),
          help = help,
          rows = {
            {
              value = "private_online",
              label = lan and tr("PRIVATE LAN LINK", "PRIVATER LAN-LINK")
                or tr("PRIVATE ONLINE ROOM", "PRIVATER ONLINE-RAUM"),
              help = lan and tr("Host or join by IP on your local network.",
                "Im lokalen Netzwerk hosten oder per IP beitreten.") or tr(
                "Host or join by room code. Every compatibility field must match exactly.",
                "Erstelle einen Raum oder tritt per Code bei. Alle Kompatibilitätsfelder müssen exakt übereinstimmen."),
            },
          },
          footer = tr("A:OPEN  SEL:HELP", "A:ÖFFNEN  SEL:HILFE"),
          onChoose = function(item)
            if not item or item.value ~= "private_online" then return end
            local ok, why = M.openPrivateOnline(game)
            if ok then return true end
            if type(ui.showHelp) == "function" then
              local contractMismatch = {
                engine_missing = true,
                handshake_missing = true,
                engine_mismatch = true,
                protocol_mismatch = true,
                api_mismatch = true,
                link_modified_mismatch = true,
                fingerprint_missing = true,
                fingerprint_invalid = true,
                mods_missing = true,
                mods_invalid = true,
                kasc_mod_missing = true,
                kasc_mod_mismatch = true,
              }
              local message = contractMismatch[why] and tr(
                "This client does not match the reviewed private-link contract. Use Kanto Ascendant 6.6.0-rc.1 with engine 0.1.90.",
                "Dieser Client entspricht nicht dem geprüften Private-Link-Vertrag. Nutze Kanto Ascendant 6.6.0-rc.1 mit Engine 0.1.90.") or tr(
                "The private room could not be opened safely.",
                "Der private Raum konnte nicht sicher geöffnet werden.")
              ui.showHelp(game, tr("KASC LINK ERROR", "KASC-LINK-FEHLER"),
                message)
            end
            return false, why
          end,
        })
      end,
    })
    return true
  end

  function M.install()
    if installed then return true end
    installed = true
    mod.events:on("battle.started", function(event)
      local battle = event and event.battle
      if battle and battle.kind == "link" then
        battle.ascendantNoMega = true
        battle.ascendantNoSaveMechanics = true
        battle.kascLinkPolicyOwner = M.OWNER
      end
    end, 10000)
    mod.events:on("pokemon.received", function(event)
      local ok, _, why = M.auditProvenance(event and event.mon)
      if not ok and mod.log and type(mod.log.warn) == "function" then
        mod.log:warn("Classic Link rejected invalid KASC provenance: "
          .. tostring(why or "invalid payload"))
      end
    end, 100)
    return true
  end

  M.install()
  return M
end
