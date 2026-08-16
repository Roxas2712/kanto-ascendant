-- E-SHARED/STORY: the deliberately closed shared end room for the character
-- paths.  It is reached after a path shrine reward, owns no reward itself,
-- and never opens the sealed door.
return function(mod, opts)
  opts = opts or {}

  local M = { registered = false, installed = false, game = nil,
    journey = opts.journey }
  local derivedAsset = "assets/" .. "generated/hidden_evolution/"
  M.ID = "KA_HEVO_SHARED_SEALED_ANTECHAMBER"
  M.INDEX = 1948
  M.DOOR = "KA_HEVO_SHARED_SEALED_DOOR"
  M.TEXT = "TEXT_KA_HEVO_SHARED_SEALED_DOOR"
  M.RETURN_POINTS = {
    -- The end room returns to the matching shrine, never to the initial
    -- campaign start.  The tunnel is only the safe exit from that start.
    RED = { map = "KA_HEVO_RED_SHRINE" },
    BLUE = { map = "KA_HEVO_BLUE_KYOGRE_SHRINE" },
    GREEN = { map = "KA_HEVO_GREEN_RAYQUAZA_SHRINE" },
  }
  M.RUN_STATE = "hidden_evolution_story_campaign"

  local CRIES = { RED = "GROUDON", BLUE = "KYOGRE", GREEN = "RAYQUAZA" }
  local STONE_LABELS = {
    BLAZIKENITE = { en="BLAZIKENITE", de="LOHGOCKNIT" },
    SWAMPERTITE = { en="SWAMPERTITE", de="SUMPEXNIT" },
    SCEPTILITE = { en="SCEPTILITE", de="GEWALDRO-NIT" },
  }
  M.TEASERS = {
    RED = { en = "...GROUDON CALLS...\nThe time is not yet right.\nSomething waits beyond\nthis black door...",
      de = "...GROUDON RUFT...\nDie Zeit ist noch nicht reif.\nEtwas wartet hinter\ndieser schwarzen Tür ..." },
    BLUE = { en = "...KYOGRE CALLS...\nThe time is not yet right.\nSomething waits beyond\nthis black door...",
      de = "...KYOGRE RUFT...\nDie Zeit ist noch nicht reif.\nEtwas wartet hinter\ndieser schwarzen Tür ..." },
    GREEN = { en = "...RAYQUAZA CALLS...\nThe time is not yet right.\nSomething waits beyond\nthis black door...",
      de = "...RAYQUAZA RUFT...\nDie Zeit ist noch nicht reif.\nEtwas wartet hinter\ndieser schwarzen Tür ..." },
  }
  M.EPILOGUES = {
    RED = { en = "The RED seal is complete. In your next Legacy Journey, TORCHIC waits in OAK's left ball. The return path stays open.",
      de = "Das ROTE Siegel ist vollendet. In deiner nächsten Vermächtnis-Reise wartet FLEMMLI in EICHS linkem Ball. Der Rückweg bleibt offen." },
    BLUE = { en = "The BLUE seal is complete. In your next Legacy Journey, MUDKIP waits in OAK's left ball. The return path stays open.",
      de = "Das BLAUE Siegel ist vollendet. In deiner nächsten Vermächtnis-Reise wartet HYDROPI in EICHS linkem Ball. Der Rückweg bleibt offen." },
    GREEN = { en = "The GREEN seal is complete. In your next Legacy Journey, TREECKO waits in OAK's left ball. The return path stays open.",
      de = "Das GRÜNE Siegel ist vollendet. In deiner nächsten Vermächtnis-Reise wartet GECKARBOR in EICHS linkem Ball. Der Rückweg bleibt offen." },
  }

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end

  function M.character(game)
    local campaign = M.campaign and M.campaign(false)
    local receipt = campaign and campaign.handoff
    if type(receipt) == "table" and receipt.seal == true
        and CRIES[receipt.character] then
      return receipt.character
    end
    local value
    if type(opts.activeCharacter) == "function" then value = opts.activeCharacter(game) end
    if value == nil and opts.characters and opts.characters.getPlayerCharacter then
      value = opts.characters.getPlayerCharacter()
    end
    if value == nil and mod.save and mod.save.get then
      local s = mod.save:get("extended_characters")
      value = type(s) == "table" and s.player_character or nil
    end
    value = type(value) == "string" and value:upper() or nil
    return value and CRIES[value] and value or nil
  end

  -- Campaign state is explicitly per-run.  Permanent evolution/Mega rewards
  -- stay in their respective persistent controllers and are never touched.
  function M.campaign(create)
    local state = mod.save and mod.save:get(M.RUN_STATE)
    if type(state) ~= "table" and create ~= false then
      state = { version = 1, hints = {}, doorVisits = {} }
      mod.save:set(M.RUN_STATE, state)
    end
    if type(state) == "table" then
      state.version = 1
      state.hints = type(state.hints) == "table" and state.hints or {}
      state.doorVisits = type(state.doorVisits) == "table" and state.doorVisits or {}
      state.handoff = type(state.handoff) == "table" and state.handoff or nil
    end
    return state
  end

  -- The coloured shrine exit owns the identity hand-off.  Relying on the
  -- currently selected presentation avatar again at the shared tablet made
  -- imported saves fragile and could select the wrong cry/reward branch.
  -- This receipt contains no grant authority; it only records the already
  -- completed seal identity and is idempotent across save/reload.
  function M.recordHandoff(game, character, payload)
    character = type(character) == "string" and character:upper() or nil
    if not CRIES[character] then return false, "character" end
    payload = type(payload) == "table" and payload or {}
    local campaign = M.campaign(true)
    local prior = campaign.handoff
    if type(prior) == "table" and prior.character == character
        and prior.seal == true then
      -- A pre-fix RED/legacy run could reach this room with a durable seal
      -- while claimMega still rejected the missing character record.  Do not
      -- freeze that transient `character`/`unavailable` result forever:
      -- monotonically upgrade the same character's receipt after the real
      -- controller proves the stone grant.  Never downgrade an existing
      -- grant and never manufacture a different character's receipt.
      local changed = false
      local incomingSuccess = payload.stoneStatus == "granted"
        or payload.stoneStatus == "claimed"
      local priorSuccess = prior.stoneStatus == "granted"
        or prior.stoneStatus == "claimed"
      if incomingSuccess and (not priorSuccess
          or payload.stoneStatus == "granted"
            and prior.stoneStatus ~= "granted") then
        prior.stone = payload.stone or prior.stone
        prior.stoneStatus = payload.stoneStatus
        prior.stoneAnnounced = false
        changed = true
      end
      if prior.sourceMap == nil and payload.sourceMap ~= nil then
        prior.sourceMap = payload.sourceMap
        changed = true
      end
      if changed then
        if mod.save and mod.save.set then mod.save:set(M.RUN_STATE, campaign) end
        if game and game.writeSave then game:writeSave() end
      end
      return true, prior
    end
    campaign.handoff = {
      version = 1, character = character, seal = true,
      sourceMap = payload.sourceMap, stone = payload.stone,
      stoneStatus = payload.stoneStatus, stoneAnnounced = false,
      acknowledged = false,
    }
    if mod.save and mod.save.set then mod.save:set(M.RUN_STATE, campaign) end
    if game and game.writeSave then game:writeSave() end
    return true, campaign.handoff
  end

  function M.handoff()
    local campaign = M.campaign(false)
    local receipt = campaign and campaign.handoff
    return type(receipt) == "table" and receipt.seal == true
      and CRIES[receipt.character] and receipt or nil
  end

  function M.resetRun()
    -- Intentionally do not clear hevo_persistent or Mega controller state.
    if mod.save and mod.save.set then mod.save:set(M.RUN_STATE, nil) end
  end

  local function show(game, text, done)
    if type(opts.showText) == "function" then return opts.showText(game, text, done) end
    game.stack:push(require("src.render.TextBox").new(game, text, done))
    return true
  end

  -- The black panel is intentionally local: the shared room stays usable in
  -- a minimal mod load, while runtime still gets an actual black-screen/text
  -- sequence after the character-specific cry.
  local function blackoutLines(text)
    local Font = require("src.render.Font")
    local lines = {}
    -- Keep the authored teaser bytes intact on `text`, but wrap each of its
    -- four authored rows to the Game Boy box's 18-glyph interior.  Font.draw
    -- is deliberately single-line and therefore cannot consume `\n` itself.
    for authored in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
      local line = ""
      for word in authored:gmatch("%S+") do
        local candidate = line == "" and word or (line .. " " .. word)
        if line ~= "" and Font.width(candidate) > 18 * 8 then
          lines[#lines + 1] = line
          line = word
        else
          line = candidate
        end
      end
      lines[#lines + 1] = line
    end
    return lines
  end

  local Blackout = {}; Blackout.__index = Blackout; Blackout.isOpaque = true
  function Blackout.new(game, done, text)
    return setmetatable({ game = game, done = done, text = text,
      lines = blackoutLines(text) }, Blackout)
  end
  function Blackout:update()
    if self.game.input and (self.game.input:wasPressed("a") or self.game.input:wasPressed("b")) then
      self.game.stack:pop(); if self.done then self.done() end
    end
  end
  function Blackout:draw()
    local Font = require("src.render.Font")
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    local th = math.min(16, #self.lines + 2)
    local ty = math.max(1, math.floor((18 - th) / 2))
    Font.drawBox(0, ty, 20, th)
    love.graphics.setColor(0, 0, 0, 1)
    for index, line in ipairs(self.lines) do
      if index > th - 2 then break end
      Font.draw(line, 8, (ty + index) * 8)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function black(game, character, done)
    local teaser = M.TEASERS[character]
    if type(opts.blackout) == "function" then
      return opts.blackout(game, { color = "black", teaser = character, text = tr(teaser.en, teaser.de) }, done)
    end
    if game and game.stack then game.stack:push(Blackout.new(game, done, tr(teaser.en, teaser.de))); return true end
    return show(game, tr(teaser.en, teaser.de), done)
  end

  local ORDINARY_INCOMPLETE = {
    gate = true, sight = true, statues = true,
    ["beyond-kanto-sealed"] = true,
  }
  local function result(ok)
    return ok == true and tr("OK", "OK") or tr("MISSING", "FEHLT")
  end
  local function beyondResult(ok)
    return ok == true and tr("ACTIVE", "AKTIV")
      or tr("MISSING", "FEHLT")
  end

  -- Text is deliberately paged as one interaction.  The return warp is only
  -- started by the TextBox completion callback after the player has dismissed
  -- every page, so no prerequisite can flash past during a teleport.
  function M.progressText(character, report)
    report = type(report) == "table" and report or {}
    local statues = math.max(0, math.min(5,
      math.floor(tonumber(report.statues) or 0)))
    local pages = {
      tr("THE BLACK DOOR\nIS SILENT.", "DIE SCHWARZE TÜR\nSCHWEIGT."),
    }
    if character == "RED" then
      local b = type(report.boulders) == "table" and report.boulders or {}
      pages[#pages + 1] = tr("GROUDON TRIAL\nNOT COMPLETE",
        "GROUDON-PRÜFUNG\nNICHT VOLLENDET")
      pages[#pages + 1] = tr("KNOWLEDGE STATUES\n", "WISSENSSTATUEN\n")
        .. statues .. "/5"
      pages[#pages + 1] = tr("BOULDER A\n", "FELSEN A\n")
        .. result(b.A)
      pages[#pages + 1] = tr("BOULDER B\n", "FELSEN B\n")
        .. result(b.B)
      pages[#pages + 1] = tr("BOULDER C\n", "FELSEN C\n")
        .. result(b.C)
      pages[#pages + 1] = tr("BEYOND KANTO:\n", "JENSEITS VON KANTO\n")
        .. beyondResult(report.beyond)
      pages[#pages + 1] = tr("BACK TO RED\nFISSURE PATH.",
        "ZURÜCK ZUM ROTEN\nRISSPFAD.")
    elseif character == "BLUE" then
      local switches = type(report.switches) == "table" and report.switches or {}
      pages[#pages + 1] = tr("KYOGRE TRIAL\nNOT COMPLETE",
        "KYOGRE-PRÜFUNG\nNICHT VOLLENDET")
      pages[#pages + 1] = tr("FROST STATUES\n", "FROSTSTATUEN\n")
        .. statues .. "/5"
      pages[#pages + 1] = tr("EAST DEPTHS STATUE\n",
          "TIEFEN-OSTSTATUE\n")
        .. result(report.finalStatue)
      pages[#pages + 1] = tr("HALL SWITCH\n", "SCHALTER HALLE\n")
        .. result(switches.HALL)
      pages[#pages + 1] = tr("ICE SWITCH\n", "SCHALTER EIS\n")
        .. result(switches.ICE)
      pages[#pages + 1] = tr("DEPTHS SWITCH\n", "SCHALTER TIEFE\n")
        .. result(switches.DEPTHS)
      pages[#pages + 1] = tr("BEYOND KANTO:\n", "JENSEITS VON KANTO\n")
        .. beyondResult(report.beyond)
      pages[#pages + 1] = tr("BACK TO BLUE\nFISSURE PATH.",
        "ZURÜCK ZUM BLAUEN\nRISSPFAD.")
    elseif character == "GREEN" then
      pages[#pages + 1] = tr("RAYQUAZA TRIAL\nNOT COMPLETE",
        "RAYQUAZA-PRÜFUNG\nNICHT VOLLENDET")
      pages[#pages + 1] = tr("LEAF STATUES\n", "BLATTSTATUEN\n")
        .. statues .. "/5"
      pages[#pages + 1] = tr("ROOT GATE: ", "WURZELTOR: ")
        .. result(report.rootgate) .. "\n"
        .. tr("CANOPY: ", "KRONENDACH: ") .. result(report.canopy)
      pages[#pages + 1] = tr("BEYOND KANTO:\n", "JENSEITS VON KANTO\n")
        .. beyondResult(report.beyond)
      pages[#pages + 1] = tr("BACK TO GREEN\nFISSURE PATH.",
        "ZURÜCK ZUM GRÜNEN\nRISSPFAD.")
    else
      return nil
    end
    return table.concat(pages, "\f")
  end

  function M.technicalFailureText(reason)
    if reason == "character" or reason == "game" then
      return tr(
        "PATH NOT VERIFIED\fNOTHING CHANGED.\nYOU REMAIN HERE.",
        "PFAD NICHT GEPRÜFT\fNICHTS VERÄNDERT.\nDU BLEIBST HIER.")
    end
    if reason == "warp" or reason == "entry" then
      return tr(
        "RETURN PATH ERROR\fNOTHING CHANGED.\nYOU REMAIN HERE.",
        "RÜCKWEG-FEHLER\fNICHTS VERÄNDERT.\nDU BLEIBST HIER.")
    end
    local detail=tostring(reason or ""):lower()
    if not (detail:find("save",1,true) or detail:find("archive",1,true)
        or detail:find("storage",1,true)
        or detail:find("rollback",1,true)) then
      return tr(
        "SEAL SYSTEM ERROR\fRESULT UNCONFIRMED\nYOU REMAIN HERE.",
        "SIEGEL-SYSTEMFEHLER\fERGEBNIS OFFEN\nDU BLEIBST HIER.")
    end
    return tr(
      "THE BLACK DOOR\nIS SILENT.\fSAVE/ARCHIVE ERROR\fRESULT UNCONFIRMED\nYOU REMAIN HERE.",
      "DIE SCHWARZE TÜR\nSCHWEIGT.\fSPEICHERFEHLER\nODER ARCHIVFEHLER\fERGEBNIS OFFEN\nDU BLEIBST HIER.")
  end

  function M.doorInteraction(game, _, _, done)
    game = game or M.game
    local character = M.character(game)
    if not character then
      return show(game, M.technicalFailureText("character"), done)
    end
    local currentSeal=opts.journey and opts.journey.currentHevoSeal
    if type(currentSeal)~="function" then
      return show(game,M.technicalFailureText("adapter"),done)
    end
    do
      local readOk,sealed,owner=pcall(currentSeal,game and game.save,
        character)
      if not readOk then
        return show(game,M.technicalFailureText("adapter"),done)
      end
      -- The coloured-shrine -> shared-room edge normally finalizes the
      -- character path and writes its durable hand-off before this object can
      -- be reached.  Released runtimes do not all expose that warp edge in
      -- the same lifecycle order, though: an imported/resumed player can be
      -- standing at the real black door while the run-local seal transaction
      -- has not yet been replayed.  Retry only through the coordinator's
      -- puzzle-gated, exact-character completion seam, then re-read the
      -- Journey authority.  This never trusts the avatar, presentation state
      -- or a stale hand-off receipt by itself, and an unfinished/foreign path
      -- therefore remains locked.
      local recoveryWhy
      if (not sealed or owner~=character)
          and type(M.ensureOwnHandoff)=="function" then
        local recoveryCall,recoveryResult
        recoveryCall,recoveryResult,recoveryWhy=pcall(M.ensureOwnHandoff,
          game,character)
        if not recoveryCall then
          return show(game,M.technicalFailureText("adapter"),done)
        end
        readOk,sealed,owner=pcall(currentSeal,game and game.save,character)
        if not readOk then
          return show(game,M.technicalFailureText("adapter"),done)
        end
      end
      if not sealed or owner~=character then
        if ORDINARY_INCOMPLETE[recoveryWhy]
            and type(M.completionProgress)=="function" then
          local reportCall,report,reportWhy=pcall(M.completionProgress,
            game,character)
          if not reportCall then
            return show(game,M.technicalFailureText("progress"),done)
          end
          if type(report)=="table" then
            if type(M.returnToTrialStart)~="function" then
              return show(game,M.technicalFailureText("warp"),done)
            end
            local text=M.progressText(character,report)
            if not text then
              return show(game,M.technicalFailureText("character"),done)
            end
            local finished=false
            local function finishOnce()
              if finished then return end
              finished=true
              if done then done() end
            end
            return show(game,text,function()
              local returnCall,started,returnWhy=pcall(M.returnToTrialStart,
                game,character,finishOnce)
              if not returnCall then
                started,returnWhy=false,"warp"
              end
              if started~=true and not finished then
                return show(game,M.technicalFailureText(returnWhy or "warp"),
                  finishOnce)
              end
            end)
          end
          return show(game,M.technicalFailureText(reportWhy or "progress"),done)
        end
        -- Every non-allowlisted reason is a transaction/integration failure,
        -- not evidence of ordinary unfinished play.  Stay at the seal and do
        -- not infer permission to teleport from partial report fields.
        return show(game,M.technicalFailureText(recoveryWhy or "progress"),done)
      end
    end
    local campaign = M.campaign(true)
    campaign.doorVisits[character] = true
    if campaign.handoff and campaign.handoff.character == character then
      campaign.handoff.acknowledged = true
    end
    if mod.save and mod.save.set then mod.save:set(M.RUN_STATE, campaign) end
    local epilogue=M.EPILOGUES[character]
    local function beginSealSequence()
      -- A direct cry is also safe in headless tests; Sound.playCry returns nil
      -- when audio is unavailable.
      require("src.core.Sound").playCry(game.data, CRIES[character])
      return black(game, character, function()
      local afterCall=function()
        return show(game,tr(epilogue.en,epilogue.de),done)
      end
      if opts.journey and type(opts.journey.notifyHevoSeal)=="function" then
        return opts.journey.notifyHevoSeal(game,character,afterCall)
      end
      return afterCall()
      end)
    end

    -- Missing the optional cache must not silently swallow the promised
    -- last-chance Mega stone.  The coloured exit transaction already secured
    -- it; acknowledge that exact-once result before cry/Oak so the player can
    -- see what happened instead of having to inspect the Stone Case later.
    local receipt=campaign.handoff
    local label=receipt and receipt.character==character
      and receipt.stoneStatus=="granted" and STONE_LABELS[receipt.stone]
    if label and receipt.stoneAnnounced~=true then
      receipt.stoneAnnounced=true
      if mod.save and mod.save.set then mod.save:set(M.RUN_STATE,campaign) end
      if game and game.writeSave then game:writeSave() end
      return show(game,tr(
        "The completed seal secures "..label.en.." in your Stone Case.",
        "Das vollendete Siegel sichert "..label.de.." in deinem Steinkoffer."),
        beginSealSequence)
    end
    if game and game.writeSave then game:writeSave() end
    return beginSealSequence()
  end

  local ROOM_WIDTH, ROOM_HEIGHT = 16, 16
  local FLOOR, GLINT, WALL, WARP = 25, 21, 125, 124

  local function blocks()
    -- Start in native CAVERN rock and carve three short pilgrimage arms.  The
    -- rejected room was one almost map-sized floor carpet: at its lower edge
    -- both flat and voxel cameras exposed the blank outside world.  Four extra
    -- rock rows now keep every arrival framed inside the cavern, while the
    -- three stable return slots and the northern door coordinate remain
    -- exactly unchanged for old saves and the story coordinator.
    local out = {}
    for index = 1, ROOM_WIDTH * ROOM_HEIGHT do out[index] = WALL end
    local function put(x, y, block)
      assert(x >= 0 and x < ROOM_WIDTH and y >= 0 and y < ROOM_HEIGHT)
      out[x + y * ROOM_WIDTH + 1] = block
    end
    local function rect(x1, y1, x2, y2, block)
      for y = y1, y2 do
        for x = x1, x2 do put(x, y, block or FLOOR) end
      end
    end

    -- Three deliberately separate return alcoves.  Each is large enough to
    -- turn around after arrival, but a single two-cell-wide native passage
    -- leaves it; no broad raster hall points straight at the final door.
    rect(1, 9, 3, 10)       -- RED / western basalt alcove
    rect(6, 9, 9, 10)       -- BLUE / central frost alcove
    rect(12, 9, 14, 10)     -- GREEN / eastern grove alcove
    rect(2, 6, 2, 9)
    rect(2, 6, 5, 6)
    rect(7, 7, 7, 9)
    rect(13, 6, 13, 9)
    rect(10, 6, 13, 6)

    -- The arms meet in a ceremonial loop around two untouched rock blocks.
    -- Arriving from BLUE therefore still has to choose a side; RED/GREEN see
    -- the same central landmark from opposite directions.  The final north
    -- spur is short and centred on the sealed door set into solid rock.
    rect(5, 5, 10, 7)
    put(7, 6, WALL)
    put(8, 6, WALL)
    rect(7, 3, 8, 5)

    -- Native pale/glinting CAVERN blocks identify the three alcoves and the
    -- convergence without adding a foreign tileset or invisible collision.
    -- Slide handling is BLUE-map-local, so these are calm visual inlays here.
    for _, point in ipairs({
      { 2, 9 }, { 7, 9 }, { 13, 9 },
      { 5, 6 }, { 10, 6 }, { 7, 4 },
    }) do put(point[1], point[2], GLINT) end

    -- Each return is an actual walk-on warp.  Native CAVERN block $7c puts
    -- its warp tile in the lower-right cell, matching the stable odd/odd
    -- engine cells (3,21), (15,21), and (27,21).
    for _, blockX in ipairs({ 1, 7, 13 }) do put(blockX, 10, WARP) end
    return out
  end

  function M.register()
    if M.registered then return false, "already registered" end
    mod.content.sprites:register("SPRITE_KA_HEVO_SHARED_SEALED_DOOR", {
      id = "SPRITE_KA_HEVO_SHARED_SEALED_DOOR",
      image = derivedAsset .. "sealed_future_door.png",
      frames = 1, walker = false, trueColor = true,
    })
    mod.content.text:register(M.TEXT, tr("Something waits\nbeyond this door …\fa new adventure …",
      "Etwas wartet\nhinter dieser Tür …\fein neues\nAbenteuer …"))
    mod.content.text_pointers:patch("???", { [M.TEXT] = { text = M.TEXT } })
    mod.content.maps:register(M.ID, {
      id = M.ID, index = M.INDEX,
      label = tr("SEALED ANTECHAMBER", "VERSIEGELTER VORRAUM"), tileset = "CAVERN",
      width = ROOM_WIDTH, height = ROOM_HEIGHT,
      borderBlock = WALL, blocks = blocks(),
      -- These stable slots are the end-room exits.  The coordinator appends
      -- matching shrine -> end-room warps and validates both directions.
      warps = {
        { x = 3, y = 21, destMap = M.RETURN_POINTS.RED.map, destWarp = 1 },
        { x = 15, y = 21, destMap = M.RETURN_POINTS.BLUE.map, destWarp = 1 },
        { x = 27, y = 21, destMap = M.RETURN_POINTS.GREEN.map, destWarp = 1 },
      },
      objects = {
        { index = 1, name = M.DOOR, sprite = "SPRITE_KA_HEVO_SHARED_SEALED_DOOR",
          x = 15, y = 5, movement = "STAY", range = "NONE", text = M.TEXT,
          passable = false },
      },
      signs = {}, connections = {}, outdoor = false,
      voxelMode = "FULL", voxelRevision = 3,
    })
    mod.content.encounters:register(M.ID, { grass = { rate = 0, slots = {} } })
    -- The convergence room can be loaded directly from an interrupted shrine
    -- hand-off.  Give it an explicit song so such a resume cannot inherit an
    -- unrelated route/theme from the previous boot.
    if mod.content.map_songs then
      mod.content.map_songs:register(M.ID, "Music_KA_DeepEvolution")
    end
    mod.content.map_scripts:register(M.ID, { priority = 2750, talk = {
      [M.TEXT] = M.doorInteraction,
    } })
    M.registered = true
    return true
  end

  function M.install(game)
    if M.installed then return false, "already installed" end
    M.installed, M.game = true, game
    return true
  end

  return M
end
