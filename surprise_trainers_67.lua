-- Kanto Ascendant 6.7: authored Surprise Trainer titles and dialogue.
--
-- Title awards are a side transaction.  A failed title roll must never undo
-- the Wanderer's ordinary item reward, while exact encounter tokens keep the
-- side transaction idempotent across reloads and repair retries.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "surprise trainers need title data")
  local i18n = opts.i18n
  local random = opts.random
  local archive = opts.archive
  local dialogue = opts.dialogue
  local S = {
    VERSION = 1,
    HARD_PITY = 5,
    DROP_PERCENT = 22,
  }
  local futureStateReadOnly = false

  local byId, ids = {}, {}
  for _, row in ipairs(data.titles or {}) do
    if type(row) == "table" and type(row.id) == "string"
        and not byId[row.id] then
      byId[row.id] = row
      ids[#ids + 1] = row.id
    end
  end

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function integer(value, default)
    return math.max(0, math.floor(tonumber(value) or default or 0))
  end

  local function roll(low, high, purpose)
    local value
    if type(random) == "function" then value = random(low, high, purpose) end
    if tonumber(value) == nil and love and love.math
        and type(love.math.random) == "function" then
      value = love.math.random(low, high)
    end
    if tonumber(value) == nil then value = math.random(low, high) end
    return math.max(low, math.min(high, math.floor(tonumber(value) or low)))
  end

  local function tr(en, de)
    if i18n and type(i18n.text) == "function" then
      return i18n.text(en, de)
    end
    return en
  end

  local function localized(row)
    return row and tr(row.en, row.de) or nil
  end

  local function normalizeToken(value)
    if type(value) ~= "string" or value == "" or #value > 96 then return nil end
    return value
  end

  local function normalizeState(raw)
    local rawVersion = type(raw) == "table"
      and math.max(1, math.floor(tonumber(raw.version) or 1)) or 1
    if type(raw) == "table" and rawVersion > S.VERSION then
      return raw, true
    end
    local s = type(raw) == "table" and raw or {}
    s.version = S.VERSION
    s.wins = integer(s.wins)
    s.losses = integer(s.losses)
    s.pity = math.min(S.HARD_PITY - 1, integer(s.pity))
    s.unlocked = type(s.unlocked) == "table" and s.unlocked or {}
    s.order = type(s.order) == "table" and s.order or {}
    s.processed = type(s.processed) == "table" and s.processed or {}
    s.classWins = type(s.classWins) == "table" and s.classWins or {}
    s.mapWins = type(s.mapWins) == "table" and s.mapWins or {}
    s.dialogueByToken = type(s.dialogueByToken) == "table"
      and s.dialogueByToken or {}
    s.farewellByToken = type(s.farewellByToken) == "table"
      and s.farewellByToken or {}
    s.scrollByToken = type(s.scrollByToken) == "table"
      and s.scrollByToken or {}
    s.dialogueHistory = type(s.dialogueHistory) == "table"
      and s.dialogueHistory or {}
    s.scrollCursor = integer(s.scrollCursor)

    local unlocked, order, seen = {}, {}, {}
    for id, value in pairs(s.unlocked) do
      if value == true and byId[id] then unlocked[id] = true end
    end
    for _, id in ipairs(s.order) do
      if unlocked[id] and not seen[id] then
        seen[id], order[#order + 1] = true, id
      end
    end
    for _, id in ipairs(ids) do
      if unlocked[id] and not seen[id] then
        seen[id], order[#order + 1] = true, id
      end
    end
    s.unlocked, s.order = unlocked, order

    local processed = {}
    for token, value in pairs(s.processed) do
      token = normalizeToken(token)
      if token and value == true then processed[token] = true end
    end
    s.processed = processed
    return s, false
  end

  local function state()
    local s, future = normalizeState(mod.save:get("surprise_trainers_67"))
    futureStateReadOnly = future == true
    if not futureStateReadOnly then mod.save:set("surprise_trainers_67", s) end
    return s
  end

  local function persist(s)
    if not futureStateReadOnly then mod.save:set("surprise_trainers_67", s) end
  end

  local function starts(text, prefix)
    return type(text) == "string" and text:sub(1, #prefix) == prefix
  end

  local function categoryEligible(row, ctx, s)
    local category = row.category
    local mapId = type(ctx.mapId) == "string" and ctx.mapId or ""
    if category == "route" then
      -- Rows with an exact map allowlist are already checked by
      -- evidenceEligible.  Do not reject caves such as Victory Road merely
      -- because their canonical ids do not begin with ROUTE_.
      if type(row.maps) == "table" then return true end
      return starts(mapId, "ROUTE_") or mapId:find("FOREST", 1, true)
        or mapId:find("TUNNEL", 1, true) or mapId:find("MOON", 1, true)
    elseif category == "city" then
      return mapId:find("CITY", 1, true) or mapId:find("TOWN", 1, true)
        or mapId:find("ISLAND", 1, true) or mapId == "INDIGO_PLATEAU"
    elseif category == "trainer" then
      return type(ctx.class) == "string" and ctx.class ~= ""
    elseif category == "type" then
      return type(ctx.partyTypes) == "table" and #ctx.partyTypes > 0
    elseif category == "tactics" then
      return true
    elseif category == "discovery" then
      return ctx.discovery == true or ctx.research == true or s.wins >= 10
    elseif category == "journey" then
      return integer(ctx.legacyCycle) >= 2
    elseif category == "legacy" then
      return ctx.legacyPass == true or type(ctx.completedPaths) == "table"
        or integer(ctx.legacyCycle) >= 3
    elseif category == "humour" then
      return true
    elseif category == "mythic" then
      return ctx.mythic == true or ctx.legend == true or s.wins >= 25
    end
    return false
  end

  local function listContains(values, needle)
    for _, value in ipairs(type(values) == "table" and values or {}) do
      if tostring(value):upper() == tostring(needle or ""):upper() then
        return true
      end
    end
    return false
  end

  local function evidenceEligible(row, ctx)
    if row.maps and not listContains(row.maps, ctx.mapId) then return false end
    if row.classes and not listContains(row.classes, ctx.class) then return false end
    local partyTypes = type(ctx.partyTypes) == "table" and ctx.partyTypes or {}
    if row.partyType and not listContains(partyTypes, row.partyType) then
      return false
    end
    if row.minPartyTypes then
      local seen, count = {}, 0
      for _, value in ipairs(partyTypes) do
        local key = tostring(value):upper()
        if key ~= "" and not seen[key] then seen[key], count = true, count + 1 end
      end
      if count < integer(row.minPartyTypes) then return false end
    end
    local proofs = type(ctx.proofs) == "table" and ctx.proofs or {}
    if row.proof and proofs[row.proof] ~= true then return false end
    for _, proof in ipairs(type(row.proofsAll) == "table"
        and row.proofsAll or {}) do
      if proofs[proof] ~= true then return false end
    end
    return true
  end

  local function eligibleRows(ctx, s, rarity)
    local rows = {}
    for _, id in ipairs(ids) do
      local row = byId[id]
      if not s.unlocked[id] and integer(row.minWins) <= s.wins
          and (not rarity or row.rarity == rarity)
          and categoryEligible(row, ctx, s)
          and evidenceEligible(row, ctx) then
        rows[#rows + 1] = row
      end
    end
    return rows
  end

  local function chooseRarity(ctx, s)
    local total = 0
    for _, rarity in ipairs(data.rarityOrder or {}) do
      if #eligibleRows(ctx, s, rarity) > 0 then
        total = total + integer(data.rarityWeights
          and data.rarityWeights[rarity])
      end
    end
    if total <= 0 then return nil end
    local needle = roll(1, total, "title_rarity")
    for _, rarity in ipairs(data.rarityOrder or {}) do
      local weight = integer(data.rarityWeights and data.rarityWeights[rarity])
      if #eligibleRows(ctx, s, rarity) > 0 then
        needle = needle - weight
        if needle <= 0 then return rarity end
      end
    end
  end

  local function selectTitle(ctx, s)
    local rows = eligibleRows(ctx, s, chooseRarity(ctx, s))
    if #rows == 0 then rows = eligibleRows(ctx, s) end
    if #rows == 0 then return nil end
    return rows[roll(1, #rows, "title_pick")]
  end

  local hall

  function S.ids()
    return copy(ids)
  end

  function S.eligibleTitleIds(ctx, rarity)
    local s = state()
    if futureStateReadOnly then return {} end
    local out = {}
    for _, row in ipairs(eligibleRows(type(ctx) == "table" and ctx or {},
        s, rarity)) do
      out[#out + 1] = row.id
    end
    return out
  end

  function S.knownTitle(id)
    return type(id) == "string" and byId[id] ~= nil
  end

  function S.titleName(id)
    return localized(byId[id])
  end

  local RARITY_LABELS = {
    common = { "COMMON", "HÄUFIG" },
    uncommon = { "UNCOMMON", "UNGEWÖHNLICH" },
    rare = { "RARE", "SELTEN" },
    epic = { "EPIC", "EPISCH" },
    legendary = { "LEGENDARY", "LEGENDÄR" },
  }

  function S.titleHelp(id)
    local row = byId[id]
    if not row then return nil end
    local rarity = RARITY_LABELS[row.rarity] or {
      tostring(row.rarity or "UNKNOWN"):upper(),
      tostring(row.rarity or "UNBEKANNT"):upper(),
    }
    local hint = type(row.hint) == "table" and row.hint or {}
    return tr(
      "TITLE: " .. tostring(row.en) .. "\nRARITY: " .. rarity[1]
        .. "\f" .. tostring(hint.en or "Win eligible Surprise battles.")
        .. "\fTitles are a separate reward. The fifth eligible win guarantees one; duplicates are excluded."
        .. "\fChoose an earned title with A. It appears on cards and in matching encounters.",
      "TITEL: " .. tostring(row.de) .. "\nSELTENHEIT: " .. rarity[2]
        .. "\f" .. tostring(hint.de or "Gewinne passende Überraschungskämpfe.")
        .. "\fTitel sind eine eigene Belohnung. Der fünfte passende Sieg garantiert einen; Duplikate sind ausgeschlossen."
        .. "\fWähle einen verdienten Titel mit A. Er erscheint auf Karten und in passenden Begegnungen.")
  end

  local function titleLabels(id)
    local row = byId[id]
    if row then return row.en, row.de end
    if hall and type(hall.catalogRows) == "function" then
      local ok, rows = pcall(hall.catalogRows)
      if ok and type(rows) == "table" then
        for _, entry in ipairs(rows) do
          if type(entry) == "table" and (entry.id == id or entry.value == id) then
            local en = entry.en or entry.label
            local de = entry.de or entry.label or en
            if type(en) == "string" and en ~= "" then return en, de end
          end
        end
      end
    end
    if hall and type(hall.titleName) == "function" then
      local ok, name = pcall(hall.titleName, id)
      if ok and type(name) == "string" and name ~= "" then
        return name, name
      end
    end
    return nil, nil
  end

  function S.titleUnlocked(id)
    return byId[id] ~= nil and state().unlocked[id] == true
  end

  function S.state()
    return state()
  end

  function S.recordWin(game, ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local token = normalizeToken(ctx.token)
    if not token then return nil, "invalid-token", false end
    local s = state()
    if futureStateReadOnly then return nil, "future-state", false end
    if s.processed[token] then return nil, "duplicate", false end

    -- The exact token commits even when no title drops.  This is what makes a
    -- hot-reload retry safe without turning old victories into extra rolls.
    s.processed[token] = true
    s.wins = s.wins + 1
    if type(ctx.class) == "string" then
      s.classWins[ctx.class] = integer(s.classWins[ctx.class]) + 1
    end
    if type(ctx.mapId) == "string" then
      s.mapWins[ctx.mapId] = integer(s.mapWins[ctx.mapId]) + 1
    end

    local reason
    local shouldDrop = s.pity >= S.HARD_PITY - 1
    if shouldDrop then
      reason = "hard-pity"
    elseif roll(1, 100, "title_drop") <= S.DROP_PERCENT then
      shouldDrop, reason = true, "drop"
    end

    if not shouldDrop then
      s.pity = math.min(S.HARD_PITY - 1, s.pity + 1)
      persist(s)
      return nil, "no-drop", true
    end

    local row = selectTitle(ctx, s)
    if not row then
      -- Exhausted/temporarily ineligible catalogues are still a committed
      -- victory, but keep pity primed so the next eligible battle is fair.
      s.pity = S.HARD_PITY - 1
      persist(s)
      return nil, "no-eligible-title", true
    end
    s.unlocked[row.id] = true
    s.order[#s.order + 1] = row.id
    s.pity = 0
    persist(s)
    return copy(row), reason, true
  end

  function S.titleRows()
    local s, rows = state(), {}
    for _, id in ipairs(type(s.order) == "table" and s.order or {}) do
      rows[#rows + 1] = {
        label = S.titleName(id), value = id,
        right = "",
      }
    end
    return rows
  end

  function S.catalogRows()
    local rows = {}
    for _, id in ipairs(ids) do
      local row = byId[id]
      rows[#rows + 1] = {
        id = id, value = id, label = localized(row),
        en = row.en, de = row.de, category = row.category,
        rarity = row.rarity, tone = row.tone,
        unlocked = S.titleUnlocked(id),
      }
    end
    return rows
  end

  function S.bindHall(provider)
    if type(provider) ~= "table" then return false end
    hall = provider
    return true
  end

  function S.battleTitle(ctx)
    ctx = type(ctx) == "table" and ctx or {}
    local function usable(id)
      if S.titleUnlocked(id) then return true end
      if hall and type(hall.titleUnlocked) == "function" then
        local ok, value = pcall(hall.titleUnlocked, id)
        return ok and value == true
      end
      return false
    end
    if hall and type(hall.pinnedTitle) == "function" then
      local ok, id = pcall(hall.pinnedTitle)
      if ok and usable(id) then return id end
    end
    local token = normalizeToken(ctx.token)
    local s = state()
    if futureStateReadOnly then return nil end
    if token and usable(s.scrollByToken[token]) then
      return s.scrollByToken[token]
    end
    local pool, seen = {}, {}
    if hall and type(hall.unlockedTitleRows) == "function" then
      local ok, rows = pcall(hall.unlockedTitleRows)
      if ok and type(rows) == "table" then
        for _, row in ipairs(rows) do
          local id = type(row) == "table" and (row.value or row.id) or nil
          if type(id) == "string" and usable(id) and not seen[id] then
            seen[id], pool[#pool + 1] = true, id
          end
        end
      end
    end
    for _, id in ipairs(s.order) do
      if usable(id) and not seen[id] then
        seen[id], pool[#pool + 1] = true, id
      end
    end
    if #pool == 0 then return nil end
    s.scrollCursor = (s.scrollCursor % #pool) + 1
    local id = pool[s.scrollCursor]
    if token then s.scrollByToken[token] = id end
    persist(s)
    return id
  end

  local DIALOGUE = {
    proud = {
      { "WANDERER:\n%s, your title got\nhere before you did!\fNow defend it!",
        "WANDERTRAINER:\n%s, dein Titel war\nvor dir hier!\fJetzt verteidige ihn!" },
      { "ACE TRAINER:\n%s! Kanto remembers\nyour last victory.\fI want the next one!",
        "ASS-TRAINER:\n%s! Kanto erinnert\nsich an deinen Sieg.\fDen nächsten will ich!" },
      { "VETERAN:\n%s, that reputation\nis not decoration.\fShow me why you earned it!",
        "VETERAN:\n%s, dein Ruf ist kein\nSchmuckstück.\fZeig, warum du ihn trägst!" },
      { "TRAINER:\n%s, your story keeps\ngetting louder.\fLet's add a battle!",
        "TRAINER:\n%s, deine Geschichte\nwird immer lauter.\fFügen wir einen Kampf hinzu!" },
    },
    neutral = {
      { "WANDERER:\n%s, I heard your name\non the next route.\fLet's compare notes!",
        "WANDERTRAINER:\n%s, dein Name fiel\nauf der nächsten Route.\fVergleichen wir unsere Notizen!" },
      { "TRAINER:\n%s, every road tells\na different version.\fWhich one is true?",
        "TRAINER:\n%s, jeder Weg erzählt\neine andere Version.\fWelche stimmt?" },
      { "SCOUT:\n%s, your title says\nwhere you've been.\fYour team says where you're going!",
        "SPÄHER:\n%s, dein Titel zeigt\nwo du warst.\fDein Team zeigt, wohin du gehst!" },
      { "TRAVELER:\n%s, no ceremony.\fJust one honest\nSurprise Battle!",
        "REISENDER:\n%s, keine Zeremonie.\fNur ein ehrlicher\nÜberraschungskampf!" },
    },
    teasing = {
      { "TRAINER:\n%s! Big title.\fDid it come with\na map this time?",
        "TRAINER:\n%s! Großer Titel.\fGab es diesmal auch\neine Karte dazu?" },
      { "WANDERER:\n%s, I brought POTIONS.\fYou brought confidence.\nLet's test both!",
        "WANDERTRAINER:\n%s, ich habe TRÄNKE.\fDu hast Selbstvertrauen.\nTesten wir beides!" },
      { "LASS:\n%s, try not to jump\nthe wrong ledge.\fThe battle is over here!",
        "GÖRE:\n%s, spring nicht über\ndie falsche Kante.\fDer Kampf ist hier!" },
      { "YOUNGSTER:\n%s, save first if\nyou need to.\fI'll pretend not to notice!",
        "KNIRPS:\n%s, speichere ruhig\nvorher.\fIch sehe einfach weg!" },
    },
  }

  local function playerName(active)
    local game = active and active.game
    local player = game and game.save and game.save.player
    local name = player and player.name
    return type(name) == "string" and name ~= "" and name or "TRAINER"
  end

  local function dialogueContext(active, row, titleEn, titleDe)
    local s = state()
    local game = active and active.game
    local save = game and game.save or {}
    local wanderers = mod.exports and mod.exports.legacyWanderers
    local wandererState = wanderers and type(wanderers.state) == "function"
      and wanderers.state() or nil
    local journey = mod.exports and mod.exports.legacyJourney
    local legacy = journey and type(journey.state) == "function"
      and journey.state(save) or {}
    local class = active and active.archetype and active.archetype.class
    local reward = active and active.reward
    return {
      playerName = playerName(active), titleEn = titleEn, titleDe = titleDe,
      tone = row and row.tone or "neutral",
      category = row and row.category or nil,
      priorWins = wandererState and wandererState.wins or s.wins,
      priorLosses = wandererState and wandererState.losses or s.losses,
      classWins = type(class) == "string" and s.classWins[class] or 0,
      legacyCycle = legacy and legacy.cycle or 0,
      postLeague = type(save.hallOfFame) == "table" and #save.hallOfFame > 0
        or type(save.flags) == "table"
          and save.flags.EVENT_BEAT_CHAMPION_RIVAL_THIS_RUN == true,
      rareOffer = active and active.rarePokemonOffer == true
        or type(reward) == "table" and (reward.rare == true
          or reward.kind == "master" or reward.kind == "apricorn"),
      random = function(low, high, purpose) return roll(low, high, purpose) end,
    }
  end

  function S.challengeText(active)
    active = type(active) == "table" and active or {}
    local token = normalizeToken(active.token)
    local s = state()
    if futureStateReadOnly then
      return tr(
        "WANDERER:\nI sought you out.\fShow me what this\njourney taught you!",
        "WANDERTRAINER:\nIch suchte dich.\fZeig, was du auf der\nReise gelernt hast!")
    end
    if token and type(s.dialogueByToken[token]) == "table" then
      local cached = s.dialogueByToken[token]
      return tr(cached.en, cached.de)
    end
    -- The raw encounter token is the cross-surface identity. Dialogue, VS
    -- cards and any later consumer must resolve the same title for one fight.
    local titleId = S.battleTitle({ token = token })
    local row = byId[titleId]
    local tone = row and row.tone or "neutral"
    local pool = DIALOGUE[tone] or DIALOGUE.neutral
    local index = roll(1, #pool, "dialogue_pick")
    local last = integer(s.dialogueHistory[tone])
    if #pool > 1 and index == last then index = (index % #pool) + 1 end
    s.dialogueHistory[tone] = index
    local pair = pool[index]
    local name = playerName(active)
    local titleEn, titleDe = titleLabels(titleId)
    if dialogue and type(dialogue.challenge) == "function" then
      local ok, built = pcall(dialogue.challenge, active,
        dialogueContext(active, row, titleEn, titleDe))
      if ok and type(built) == "table" and type(built.en) == "string"
          and type(built.de) == "string" then
        local cached = { en = built.en, de = built.de }
        if token then s.dialogueByToken[token] = cached end
        persist(s)
        return tr(cached.en, cached.de)
      end
    end
    local titlePageEn = titleEn and ("TITLE:\n" .. titleEn .. "\f") or ""
    local titlePageDe = titleDe and ("TITEL:\n" .. titleDe .. "\f") or ""
    local cached = {
      en = titlePageEn .. pair[1]:format(name),
      de = titlePageDe .. pair[2]:format(name),
    }
    if token then s.dialogueByToken[token] = cached end
    persist(s)
    return tr(cached.en, cached.de)
  end

  function S.farewellText(active, result)
    result = result == "win" and "win"
      or (result == "lose" or result == "loss") and "loss" or nil
    if not result or not (dialogue and type(dialogue.farewell) == "function") then
      return nil
    end
    active = type(active) == "table" and active or {}
    local token = normalizeToken(active.token)
    local key = token and (token .. "|" .. result) or nil
    local s = state()
    local cached = key and s.farewellByToken[key]
    if type(cached) == "table" then return tr(cached.en, cached.de) end
    local titleId = S.battleTitle({ token = token })
    local row = byId[titleId]
    local titleEn, titleDe = titleLabels(titleId)
    local ok, built = pcall(dialogue.farewell, active, result,
      dialogueContext(active, row, titleEn, titleDe))
    if not (ok and type(built) == "table" and type(built.en) == "string"
        and type(built.de) == "string") then return nil end
    cached = { en = built.en, de = built.de }
    if key then s.farewellByToken[key] = cached end
    persist(s)
    return tr(cached.en, cached.de)
  end

  function S.awardText(row)
    if type(row) ~= "table" or not byId[row.id] then return nil end
    return tr("NEW TITLE EARNED:\n", "NEUER TITEL ERHALTEN:\n")
      .. localized(byId[row.id])
  end

  if archive and type(archive.registerTitleIds) == "function" then
    local ok, accepted = pcall(archive.registerTitleIds, copy(ids))
    assert(ok and accepted == true,
      "Legacy Archive refused the authored Surprise title catalogue")
  end

  return S
end
