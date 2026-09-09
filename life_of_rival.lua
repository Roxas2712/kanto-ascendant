-- Kanto Ascendant 6.7: staged third-character intro, then rare road meetings.
--
-- The runtime deliberately owns no maps, sprites, story flags or rewards.
-- It appears only after the League or from the start of a confirmed NG+ run.
-- Route 1/Viridian own one deterministic safe intro before
-- the existing character/Surprise/rematch cadence may place later actors.

return function(mod, opts)
  opts = opts or {}
  local characters = assert(opts.characters,
    "Life of a Rival requires extended characters")
  local postgame = assert(opts.postgame,
    "Life of a Rival requires the postgame battle seam")
  local rivalTeams = assert(opts.rivalTeams,
    "Life of a Rival requires identity rival teams")
  local teamProgression = assert(opts.teamProgression,
    "Life of a Rival requires canonical rival team progression")
  local wanderers = assert(opts.wanderers,
    "Life of a Rival requires the Surprise progression seam")
  local spawnSafety = assert(opts.spawnSafety,
    "Life of a Rival requires the shared spawn-safety boundary")
  local titles = opts.titles
  local journey = opts.journey
  local beyondKanto = opts.beyondKanto
  local generationRules = opts.generationRules
  local explorationDevice = assert(opts.explorationDevice,
    "Life of a Rival requires TRACE FINDER authority")
  local hiddenAccessReveal = assert(opts.hiddenAccessReveal,
    "Life of a Rival requires Access V3.1 authority")
  local starterHabitats = assert(opts.starterHabitats,
    "Life of a Rival requires starter habitat authority")
  assert(type(starterHabitats.recordRumorTrace) == "function",
    "Life of a Rival requires starter rumor discovery authority")
  local dialogueRows = assert(opts.dialogues,
    "Life of a Rival requires generated dialogue data")
  local i18n = opts.i18n
  local gameVersion = opts.gameVersion
  local rumorsEnabled = opts.rumorsEnabled ~= false
  if not gameVersion then
    local ok, value = pcall(require, "src.core.GameVersion")
    gameVersion = ok and value or nil
  end

  local INTRO_MAP_PRIORITY = { "ROUTE_1", "VIRIDIAN_CITY" }
  local INTRO_MAP_RANK = { ROUTE_1 = 1, VIRIDIAN_CITY = 2 }

  local L = {
    SAVE_KEY = "life_of_rival",
    STATE_VERSION = 4,
    MIN_STEPS = 420,
    MAX_STEPS = 960,
    MIN_MAP_CHANGES = 2,
    MAX_MAP_CHANGES = 4,
    HARD_MAX_MAP_CHANGES = 6,
    THIRD_DENOMINATOR = 2,
    THIRD_GUARANTEE_AFTER = 4,
    BATTLE_DENOMINATOR = 6, -- legacy cadence migration/API only
    PRESENCE_SINGLE_PERCENT = 70,
    PRESENCE_DUO_PERCENT = 20,
    PRESENCE_NONE_PERCENT = 10,
    BATTLE_OFFER_PERCENT = 20,
    DUEL_PERCENT = 20,
    DUEL_NEXT_CHALLENGE_PERCENT = 5,
    HISTORY_LIMIT = 24,
    MAX_ACTIVE_TALKS = 1,
    INTRO_WALK_DISTANCE = 4,
    INTRO_WATCHDOG_SECONDS = 2,
    SPAWN_RETRY_STEPS = 12,
    INTRO_MAP_PRIORITY = INTRO_MAP_PRIORITY,
    TEXT = "TEXT_KA_LIFE_ACTOR",
    active = nil,
    game = nil,
    readOnly = false,
    futureVersion = nil,
    VISIT_CONTRACT_ENABLED = opts.visitContract ~= false,
  }

  local ELIGIBLE_MAPS = {}
  for index = 1, 25 do ELIGIBLE_MAPS["ROUTE_" .. index] = true end
  for _, id in ipairs({
    "PALLET_TOWN", "VIRIDIAN_CITY", "PEWTER_CITY", "CERULEAN_CITY",
    "LAVENDER_TOWN", "VERMILION_CITY", "CELADON_CITY", "FUCHSIA_CITY",
    "CINNABAR_ISLAND", "INDIGO_PLATEAU", "SAFFRON_CITY",
  }) do ELIGIBLE_MAPS[id] = true end
  L.ELIGIBLE_MAPS = ELIGIBLE_MAPS

  -- These surfaces contain active vanilla rival/League approach scripts in
  -- a fresh NG+ cycle. Post-Hall-of-Fame saves may use them; pre-League NG+
  -- meetings fail closed there even when a currently empty cell looks safe.
  local NGPLUS_STORY_SENSITIVE = {
    PALLET_TOWN = true, ROUTE_22 = true, CERULEAN_CITY = true,
    INDIGO_PLATEAU = true,
  }

  local CHARACTER_IDS = { RED = true, GREEN = true, BLUE = true }
  local ROLE_MATRIX = {
    RED = { player = "RED", rival = "BLUE", third = "GREEN" },
    BLUE = { player = "BLUE", rival = "GREEN", third = "RED" },
    GREEN = { player = "GREEN", rival = "RED", third = "BLUE" },
  }

  local function savedState()
    if not (mod.save and type(mod.save.get) == "function") then return nil end
    local ok, value = pcall(mod.save.get, mod.save, L.SAVE_KEY)
    return ok and value or nil
  end

  local function tr(en, de)
    if i18n and type(i18n.text) == "function" then
      local ok, value = pcall(i18n.text, en, de)
      if ok and type(value) == "string" then return value end
    end
    return en
  end

  local function integer(value, default, maximum)
    value = math.floor(tonumber(value) or default or 0)
    value = math.max(0, value)
    if maximum then value = math.min(maximum, value) end
    return value
  end

  local function clamp(value, low, high)
    value = math.floor(tonumber(value) or low)
    return math.max(low, math.min(high, value))
  end

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function randomInt(low, high, purpose)
    if type(opts.random) == "function" then
      local ok, value = pcall(opts.random, low, high, purpose)
      if ok and tonumber(value) then return clamp(value, low, high) end
    end
    if love and love.math and type(love.math.random) == "function" then
      return love.math.random(low, high)
    end
    return math.random(low, high)
  end

  local function edition()
    if not (gameVersion and type(gameVersion.get) == "function") then
      return nil
    end
    local ok, value = pcall(gameVersion.get)
    value = ok and tostring(value or ""):lower() or ""
    return (value == "red" or value == "blue" or value == "yellow")
      and value or nil
  end

  local function badgeCount(game)
    if type(opts.badgeCount) == "function" then
      local ok, value = pcall(opts.badgeCount, game)
      return ok and integer(value) or nil
    end
    local ok, Badges = pcall(require, "src.inventory.Badges")
    if not (ok and Badges and type(Badges.count) == "function"
        and game and game.data and game.save) then return nil end
    local counted, value = pcall(Badges.count, game.data, game.save)
    return counted and integer(value) or nil
  end

  local function hallOfFame(save)
    if type(postgame.hasHallOfFame) ~= "function" then return false end
    local ok, value = pcall(postgame.hasHallOfFame, save)
    return ok and value == true
  end

  local function ngplusActive(save)
    if not (journey and type(journey.isActive) == "function") then
      return false
    end
    local ok, value = pcall(journey.isActive, save)
    return ok and value == true
  end

  function L.characterRoles(game)
    if type(characters.getState) ~= "function" then return nil end
    local ok, raw = pcall(characters.getState)
    if not (ok and type(raw) == "table") then
      return nil
    end
    local player = tostring(raw.player_character or ""):upper()
    -- A Legacy Journey can own the current avatar in its verified archive
    -- before a target save has an extended-character bucket. That profile is
    -- the story authority; the ordinary character state remains the fallback
    -- for standard saves and direct test/preview callers.
    if journey and type(journey.activeCharacter) == "function" then
      local save = game and game.save or L.game and L.game.save
      if save then
        local resolved, active = pcall(journey.activeCharacter, save)
        if resolved and CHARACTER_IDS[active] then player = active end
      end
    end
    local matrix = ROLE_MATRIX[player]
    if not matrix then return nil end
    local rival = tostring(raw.rival_character or ""):upper()
    local third = tostring(raw.third_character or ""):upper()
    if rival == matrix.rival and third == matrix.third then
      return { player = player, rival = rival, third = third }
    end
    -- Disabled/pre-6.5 states and archive-owned Journey avatars use the same
    -- canonical matrix instead of silently disabling an existing postgame.
    if raw.enabled ~= true
        or player ~= tostring(raw.player_character or ""):upper() then
      return copy(matrix)
    end
    return nil
  end

  function L.eligible(game)
    if not (game and game.save and edition() and L.characterRoles(game)) then
      return false
    end
    local raw = savedState()
    if type(raw) == "table"
        and integer(raw.version, 1) > L.STATE_VERSION then return false end
    if hallOfFame(game.save) then return true end
    -- NG+ is a separately proven run, never a first vanilla playthrough. Its
    -- own lifecycle receipt is sufficient: safe public maps may introduce an
    -- actually unknown figure before badges or a party can enable battles.
    return ngplusActive(game.save)
  end

  function L.isEligibleMap(mapId)
    return type(mapId) == "string" and ELIGIBLE_MAPS[mapId] == true
      and type(wanderers.isEligibleMap) == "function"
      and wanderers.isEligibleMap(mapId) == true
  end

  function L.mapEligible(game, mapId)
    if not L.isEligibleMap(mapId) then return false end
    if hallOfFame(game and game.save) then return true end
    return ngplusActive(game and game.save)
      and not NGPLUS_STORY_SENSITIVE[mapId]
  end

  local function scheduleFields(s, startMap)
    s.due = false
    s.cycleSteps, s.mapChanges = 0, 0
    s.targetSteps = randomInt(L.MIN_STEPS, L.MAX_STEPS, "schedule_steps")
    s.targetMapChanges = randomInt(L.MIN_MAP_CHANGES,
      L.MAX_MAP_CHANGES, "schedule_maps")
    s.lastEligibleMap = L.isEligibleMap(startMap) and startMap or nil
    s.pending = nil
    return s
  end

  function L.newState()
    local s = {
      version = L.STATE_VERSION,
      eligibleSteps = 0, cycleSteps = 0, mapChanges = 0,
      due = false, appearances = 0, talks = 0,
      battles = 0, wins = 0, losses = 0, declines = 0,
      nextToken = 1, thirdIntroduced = false,
      introArmedMap = nil,
      thirdIntroductions = {}, dialogueHistory = {}, actorAppearances = {},
      rumorsHeard = {}, visitReceipts = {}, actorStrength = {},
      knownActors = {},
    }
    return scheduleFields(s)
  end

  local function cleanHistory(value)
    local out, seen = {}, {}
    for _, id in ipairs(type(value) == "table" and value or {}) do
      if type(id) == "string" and id ~= "" and not seen[id] then
        seen[id] = true
        out[#out + 1] = id
      end
    end
    while #out > L.HISTORY_LIMIT do table.remove(out, 1) end
    return out
  end

  local function normalizePending(value)
    if type(value) ~= "table" or type(value.token) ~= "string"
        or not CHARACTER_IDS[value.actor]
        or (value.role ~= "rival" and value.role ~= "third")
        or type(value.mapId) ~= "string"
        or type(value.dialogue) ~= "table"
        or type(value.dialogue.id) ~= "string"
        or type(value.dialogue.text) ~= "string" then return nil, false end
    local heldBackRumor = value.dialogue.category == "rumor"
      or value.dialogue.kind == "rumor"
      or value.dialogue.id:find("_rumor_", 1, true) ~= nil
    if heldBackRumor and not rumorsEnabled then return nil, true end
    local pending = copy(value)
    pending.arc = pending.arc == "intro" and "intro" or "followup"
    pending.battleOffered = pending.battleOffered == true
      and type(pending.battlePlan) == "table"
    if pending.arc == "intro" then
      pending.battleOffered, pending.battlePlan = false, nil
    end
    pending.spawnCounted = pending.spawnCounted == true
    pending.talked = pending.talked == true
    pending.battleStarted = pending.battleStarted == true
    return pending, false
  end

  local function normalizeStrength(value)
    value = type(value) == "table" and value or {}
    return {
      stage = clamp(value.stage or 1, 1, 6),
      minLevel = clamp(value.minLevel or 2, 2, 100),
      rosterSize = clamp(value.rosterSize or 1, 1, 6),
    }
  end

  local function normalizeVisit(value, mapId)
    if type(value) ~= "table" or value.mapId ~= mapId
        or (value.mode ~= "single" and value.mode ~= "duo"
          and value.mode ~= "none") then return nil end
    local out = copy(value)
    out.duel = out.mode == "duo" and out.duel == true
    out.nextChallenge = out.duel and out.nextChallenge == true
    local actors, seen = {}, {}
    for _, raw in ipairs(type(out.actors) == "table" and out.actors or {}) do
      if type(raw) == "table" and CHARACTER_IDS[raw.actor]
          and not seen[raw.actor]
          and (raw.role == "rival" or raw.role == "third")
          and type(raw.dialogue) == "table"
          and type(raw.dialogue.id) == "string"
          and type(raw.dialogue.text) == "string" then
        local row = copy(raw)
        row.battleOffered = row.battleOffered == true
          and type(row.battlePlan) == "table"
        actors[#actors + 1], seen[row.actor] = row, true
      end
    end
    local expected = out.mode == "none" and 0 or out.mode == "single" and 1 or 2
    if #actors ~= expected then return nil end
    out.actors = actors
    out.talked = type(out.talked) == "table" and out.talked or {}
    out.battleResolved = type(out.battleResolved) == "table"
      and out.battleResolved or {}
    out.battleStarted = type(out.battleStarted) == "table"
      and out.battleStarted or {}
    return out
  end

  local function normalize(raw)
    local s = raw
    local version = integer(s.version, 1)
    if version > L.STATE_VERSION then
      L.readOnly, L.futureVersion = true, version
      return nil
    end
    L.readOnly, L.futureVersion = false, nil
    s.version = L.STATE_VERSION
    for _, key in ipairs({ "eligibleSteps", "cycleSteps", "mapChanges",
      "appearances", "talks", "battles", "wins", "losses", "declines" }) do
      s[key] = integer(s[key])
    end
    s.nextToken = math.max(1, integer(s.nextToken, 1))
    s.due = s.due == true
    s.introArmedMap = INTRO_MAP_RANK[s.introArmedMap]
      and s.introArmedMap or nil
    s.thirdIntroduced = s.thirdIntroduced == true
    s.thirdIntroductions = type(s.thirdIntroductions) == "table"
      and s.thirdIntroductions or {}
    for _, actor in ipairs({ "RED", "GREEN", "BLUE" }) do
      s.thirdIntroductions[actor] = s.thirdIntroductions[actor] == true
    end
    -- Schema-0 development snapshots carried only a single boolean. Preserve
    -- that knowledge for the current matrix without treating malformed truthy
    -- values as an introduction receipt.
    if s.thirdIntroduced then
      local roles = L.characterRoles()
      if roles then s.thirdIntroductions[roles.third] = true end
    end
    s.lastEligibleMap = L.isEligibleMap(s.lastEligibleMap)
      and s.lastEligibleMap or nil
    s.lastAppearanceMap = L.isEligibleMap(s.lastAppearanceMap)
      and s.lastAppearanceMap or nil
    s.targetSteps = clamp(s.targetSteps or L.MIN_STEPS,
      L.MIN_STEPS, L.MAX_STEPS)
    s.targetMapChanges = clamp(s.targetMapChanges or L.MIN_MAP_CHANGES,
      L.MIN_MAP_CHANGES, L.MAX_MAP_CHANGES)
    s.dialogueHistory = type(s.dialogueHistory) == "table"
      and s.dialogueHistory or {}
    for _, actor in ipairs({ "RED", "GREEN", "BLUE" }) do
      s.dialogueHistory[actor] = cleanHistory(s.dialogueHistory[actor])
    end
    s.actorAppearances = type(s.actorAppearances) == "table"
      and s.actorAppearances or {}
    for _, actor in ipairs({ "RED", "GREEN", "BLUE" }) do
      s.actorAppearances[actor] = integer(s.actorAppearances[actor])
    end
    s.actorStrength = type(s.actorStrength) == "table" and s.actorStrength or {}
    s.knownActors = type(s.knownActors) == "table" and s.knownActors or {}
    for _, actor in ipairs({ "RED", "GREEN", "BLUE" }) do
      s.actorStrength[actor] = normalizeStrength(s.actorStrength[actor])
      s.knownActors[actor] = s.knownActors[actor] == true
    end
    local visits = {}
    for mapId, value in pairs(type(s.visitReceipts) == "table"
        and s.visitReceipts or {}) do
      if L.isEligibleMap(mapId) then
        local visit = normalizeVisit(value, mapId)
        if visit then visits[mapId] = visit end
      end
    end
    s.visitReceipts = visits
    local heard = {}
    for species, value in pairs(type(s.rumorsHeard) == "table"
        and s.rumorsHeard or {}) do
      if type(species) == "string" and species ~= "" and value == true then
        heard[species:upper()] = true
      end
    end
    s.rumorsHeard = heard
    local heldBackRumor
    s.pending, heldBackRumor = normalizePending(s.pending)
    if heldBackRumor then
      -- A supported newer save may carry an already frozen rumor. On the 6.6
      -- card those four owner systems are intentionally absent, so retire the
      -- transaction without displaying it or writing a discovery receipt.
      scheduleFields(s, s.lastEligibleMap)
    elseif s.pending then
      s.due = true
    end
    return s
  end

  function L.state(create)
    if not (mod.save and type(mod.save.get) == "function"
        and type(mod.save.set) == "function") then return nil end
    local raw = savedState()
    if type(raw) ~= "table" then
      if create == false then return nil end
      raw = L.newState()
    end
    local s = normalize(raw)
    if s and not L.readOnly then
      local ok = pcall(mod.save.set, mod.save, L.SAVE_KEY, s)
      if not ok then return nil end
      L.reconcileRumorDiscoveries(s)
    end
    return s
  end

  local function persist(s)
    if s and not L.readOnly and mod.save and type(mod.save.set) == "function" then
      return pcall(mod.save.set, mod.save, L.SAVE_KEY, s)
    end
    return false
  end

  function L.scheduleNext(s, startMap)
    return scheduleFields(s or L.state(true), startMap)
  end

  function L.advanceCadence(s, mapId)
    if not (s and L.isEligibleMap(mapId)) then return false end
    s.eligibleSteps = integer(s.eligibleSteps) + 1
    if s.due then return true end
    s.cycleSteps = integer(s.cycleSteps) + 1
    if not s.lastEligibleMap then
      s.lastEligibleMap = mapId
    elseif mapId ~= s.lastEligibleMap then
      s.mapChanges = integer(s.mapChanges) + 1
      s.lastEligibleMap = mapId
    end
    local floors = s.cycleSteps >= integer(s.targetSteps, L.MIN_STEPS)
      and s.mapChanges >= integer(s.targetMapChanges, L.MIN_MAP_CHANGES)
    local hard = s.cycleSteps >= L.MAX_STEPS
      or (s.cycleSteps >= L.MIN_STEPS
        and s.mapChanges >= L.HARD_MAX_MAP_CHANGES)
    if floors or hard then s.due = true end
    return s.due
  end

  local INTRO = {
    RED = {
      id = "third_intro_red", kind = "intro",
      en = "RED: {PLAYER}.\fI'm RED.\f{MAIN_RIVAL} spoke well of\nyour battles.\fI noticed how your team\nfollows your lead.\fNo challenge today.\nUntil next time.",
      de = "RED: {PLAYER}.\fIch bin RED.\f{MAIN_RIVAL} sprach gut über\ndeine Kämpfe.\fMir fiel auf, wie dein\nTeam dir vertraut.\fHeute kein Kampf.\nBis zum nächsten Mal.",
    },
    BLUE = {
      id = "third_intro_blue", kind = "intro",
      en = "BLUE: {PLAYER}.\fBLUE. Oak's grandson.\f{MAIN_RIVAL} calls you strong.\nAccurate.\fYou two took the lead.\nI measured it already.\fNo battle today.\nFirst, I study the pace.",
      de = "BLUE: {PLAYER}.\fBLUE. Eichs Enkel.\f{MAIN_RIVAL} nennt dich stark.\nKorrekt.\fIhr führt.\nIch maß den Vorsprung.\fHeute kein Kampf.\nErst prüfe ich das Tempo.",
    },
    GREEN = {
      id = "third_intro_green", kind = "intro",
      en = "GREEN: {PLAYER}!\fI'm GREEN.\nYes, the third one.\f{MAIN_RIVAL} says you're\nthe one to measure.\fI took the scenic route.\nDeliberately. Great data.\fNo battle yet.\nI have notes to compare.",
      de = "GREEN: {PLAYER}!\fIch bin GREEN.\nJa, die Dritte.\f{MAIN_RIVAL} sagt, an dir\nsoll ich mich messen.\fIch nahm den längeren Weg.\nDa konnte ich mehr sehen.\fNoch kein Kampf.\nErst vergleichen wir Notizen.",
    },
  }

  local DIALOGUE = {
    RED = {
      { id="red_watch", kind="standard",
        en="RED: Good road.\fEnough room to watch\nhow a team moves.",
        de="RED: Gute Strecke.\fGenug Raum, um ein\nTeam zu beobachten." },
      { id="red_steps", kind="standard",
        en="RED: Strong pace.\fI'll set the next one.",
        de="RED: Starkes Tempo.\fDas nächste setze ich." },
      { id="red_weather", kind="standard",
        en="RED: Your lead reads\nthe wind well.\fMine reads you.",
        de="RED: Dein erstes Pokémon\nspürt den Wind gut.\fMeins durchschaut dich." },
      { id="red_rest", kind="standard",
        en="RED: Take the rest.\fRecovery is part\nof winning.",
        de="RED: Ruh dich aus.\fErholung gehört\nzum Siegen." },
      { id="red_master", kind="progress",
        phases={master_gyms=true,ngplus=true},
        en="RED: The GYM LEADERS\nare training again.\fSo am I.\nSee you at the summit.",
        de="RED: Die ARENALEITER\ntrainieren wieder.\fIch auch.\nBis zum Gipfel." },
      { id="red_legend", kind="progress", phases={legend_hunt=true},
        en="RED: Legends leave\nquiet signs.\fTake this trail.\nI'll take the next.",
        de="RED: Legenden lassen\nleise Zeichen.\fNimm diese Spur.\nIch nehme die nächste." },
      { id="red_crown", kind="progress",
        phases={crown_gyms=true,crown_elite=true},
        en="RED: A crown needs\ndefending.\fWhen you're ready,\nI'll challenge it.",
        de="RED: Eine Krone will\nverteidigt sein.\fWenn du bereit bist,\nfordere ich sie." },
      { id="red_complete", kind="progress", phases={complete=true},
        en="RED: You reached\nthe top.\fGood.\nChoose the next road.",
        de="RED: Du warst\nganz oben.\fGut.\nWähl den nächsten Weg." },
    },
    BLUE = {
      { id="blue_map", kind="standard",
        en="BLUE: There you are.\fKANTO's second-best\nroute reader.",
        de="BLUE: Da bist du.\fKANTOs zweitbester\nRoutenleser." },
      { id="blue_pace", kind="standard",
        en="BLUE: Good pace.\fI only slowed down\nonce.",
        de="BLUE: Gutes Tempo.\fIch wurde nur einmal\nlangsamer." },
      { id="blue_team", kind="standard",
        en="BLUE: Your lead has\ncoverage.\fMine has answers.",
        de="BLUE: Dein erstes Pokémon\nist gut abgesichert.\fMeins hat die Antwort darauf." },
      { id="blue_record", kind="standard",
        en="BLUE: I record every\nbattle.\fHistory deserves\na flattering editor.",
        de="BLUE: Ich notiere jeden\nKampf.\fWer Geschichte schreibt,\nbraucht einen guten Redakteur." },
      { id="blue_master", kind="progress",
        phases={master_gyms=true,ngplus=true},
        en="BLUE: MASTER battles?\fGood.\nComfort makes slow rivals.",
        de="BLUE: MEISTERKÄMPFE?\fGut.\nBequemlichkeit macht langsam." },
      { id="blue_legend", kind="progress", phases={legend_hunt=true},
        en="BLUE: Hunting legends?\fI already mapped\nthe fast route.",
        de="BLUE: Legendenjagd?\fDie schnelle Route\nhabe ich schon." },
      { id="blue_crown", kind="progress",
        phases={crown_gyms=true,crown_elite=true},
        en="BLUE: Nice crown.\fIt needs a sharper\nChampion.",
        de="BLUE: Nette Krone.\fSie braucht einen\nschärferen Champ." },
      { id="blue_complete", kind="progress", phases={complete=true},
        en="BLUE: Cleared it all?\fGood.\nNow I know the record.",
        de="BLUE: Alles geschafft?\fGut.\nJetzt kenne ich den Rekord." },
    },
    GREEN = {
      { id="green_map", kind="standard",
        en="GREEN: I tested the\nlong route.\fExcellent scenery.\nTerrible shortcut.\fI wrote both down.",
        de="GREEN: Ich nahm den\nlangen Weg.\fTolle Aussicht.\nMiese Abkürzung.\fBeides habe ich mir gemerkt." },
      { id="green_pace", kind="standard",
        en="GREEN: Scenic detour,\ntimed.\fStill arrived first.\fThe margin is in\nmy notes.",
        de="GREEN: Beim Weg mit Aussicht\nhabe ich die Zeit gemessen.\fTrotzdem war ich zuerst da.\fDen Vorsprung habe ich\nmir notiert." },
      { id="green_team", kind="standard",
        en="GREEN: New formation.\fIt worked twice.\fThird experiment:\nyou.",
        de="GREEN: Neue Formation.\fZweimal klappte sie.\fDrittes Experiment:\ndu." },
      { id="green_secret", kind="standard",
        en="GREEN: My backup plan\nhas a picnic stop.\fGood plans account\nfor morale.",
        de="GREEN: Mein Ersatzplan\nhat eine Picknickpause.\fGute Pläne achten\nauf die Moral." },
      { id="green_master", kind="progress",
        phases={master_gyms=true,ngplus=true},
        en="GREEN: The LEADERS want\nrematches.\fExcellent.\nMy notes need field tests.",
        de="GREEN: Die ARENALEITER\nwollen Revanchen.\fSehr gut.\nIch will meine Ideen ausprobieren." },
      { id="green_legend", kind="progress", phases={legend_hunt=true},
        en="GREEN: Fresh legend\ntracks.\fI marked three routes.\fTwo are deliberate\ndecoys.",
        de="GREEN: Frische Spuren\neiner Legende.\fDrei Routen markiert.\fZwei sind bewusste\nTäuschungen." },
      { id="green_crown", kind="progress",
        phases={crown_gyms=true,crown_elite=true},
        en="GREEN: Nice crown!\fMy backup plan says\n\"rematch.\"\fThe footnote says\n\"win.\"",
        de="GREEN: Schöne Krone!\fMein Ersatzplan sagt\n\"Revanche\".\fDie Fußnote sagt\n\"Sieg\"." },
      { id="green_complete", kind="progress", phases={complete=true},
        en="GREEN: Everything done?\fWonderful.\nNew research question:\fWhat tops everything?",
        de="GREEN: Alles erledigt?\fWunderbar.\nNeue Forschungsfrage:\fWas kommt danach?" },
    },
  }

  local TITLE_DIALOGUE = {
    RED = {
      en = "RED: %s.\fIt suits you.\fKeep it sharp.\nI'm coming for it.",
      de = "RED: %s.\fEr steht dir.\fHalt ihn scharf.\nIch komme dafür.",
    },
    BLUE = {
      en = "BLUE: %s?\fGood title.\nChampion sounds better.\fI'll demonstrate.",
      de = "BLUE: %s?\fGuter Titel.\nCHAMP klingt besser.\fIch zeige dir gern, warum.",
    },
    GREEN = {
      en = "GREEN: %s!\fI prepared applause\nand a rematch plan.\fGuess which one has\nappendices.",
      de = "GREEN: %s!\fIch hatte Applaus und\neine Revanche eingeplant.\fRate mal, wozu ich\nNotizen mitgebracht habe.",
    },
  }

  local DATA_BY_ACTOR = { RED = {}, BLUE = {}, GREEN = {} }
  local DATA_BY_ID = {}
  for _, source in ipairs(dialogueRows) do
    assert(type(source) == "table" and type(source.id) == "string"
      and CHARACTER_IDS[source.actor] and not DATA_BY_ID[source.id],
      "invalid generated Life of a Rival dialogue row")
    local row = copy(source)
    DATA_BY_ID[row.id] = row
    local bucket = DATA_BY_ACTOR[row.actor]
    bucket[#bucket + 1] = row
  end

  local MAP_NAMES = {
    PALLET_TOWN={en="PALLET TOWN",de="ALABASTIA"},
    VIRIDIAN_CITY={en="VIRIDIAN CITY",de="VERTANIA CITY"},
    PEWTER_CITY={en="PEWTER CITY",de="MARMORIA CITY"},
    CERULEAN_CITY={en="CERULEAN CITY",de="AZURIA CITY"},
    LAVENDER_TOWN={en="LAVENDER TOWN",de="LAVANDIA"},
    VERMILION_CITY={en="VERMILION CITY",de="ORANIA CITY"},
    CELADON_CITY={en="CELADON CITY",de="PRISMANIA CITY"},
    FUCHSIA_CITY={en="FUCHSIA CITY",de="FUCHSANIA CITY"},
    CINNABAR_ISLAND={en="CINNABAR ISLAND",de="ZINNOBERINSEL"},
    INDIGO_PLATEAU={en="INDIGO PLATEAU",de="INDIGO PLATEAU"},
    SAFFRON_CITY={en="SAFFRON CITY",de="SAFFRONIA CITY"},
    VIRIDIAN_FOREST={en="VIRIDIAN FOREST",de="VERTANIA-WALD"},
    MT_MOON_B1F={en="MT. MOON",de="MONDBERG"},
    POWER_PLANT={en="POWER PLANT",de="KRAFTWERK"},
  }
  for index = 1, 25 do
    MAP_NAMES["ROUTE_" .. index] = {
      en = "ROUTE " .. index, de = "ROUTE " .. index,
    }
  end
  L.MAP_NAMES = MAP_NAMES

  local function mapGroup(mapId)
    if mapId == "ROUTE_2" or mapId == "VIRIDIAN_FOREST" then
      return "forest-edge"
    end
    if mapId and mapId:match("^ROUTE_") then
      local number = tonumber(mapId:match("(%d+)$"))
      if number and (number >= 12 and number <= 21) then return "coast" end
      return "route"
    end
    return ELIGIBLE_MAPS[mapId] and "city" or nil
  end

  local function localized(row)
    local out = copy(row)
    out.text = tr(out.en, out.de)
    return out
  end

  local function substitute(row, replacements)
    row = copy(row)
    for _, language in ipairs({ "en", "de" }) do
      for key, value in pairs(replacements or {}) do
        row[language] = row[language]:gsub("{" .. key .. "}",
          function() return value end)
      end
    end
    row.text = tr(row.en, row.de)
    return row
  end

  function L.dialogueReviewContract()
    return copy(dialogueRows)
  end

  local function safeTitleName(value)
    value = tostring(value or ""):gsub("[%c]", " "):gsub("%s+", " ")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value ~= "" and value:upper() or nil
  end

  function L.progressContext(game)
    local context = {
      phase = hallOfFame(game and game.save) and "master_gyms" or "ngplus",
      badges = badgeCount(game) or 0,
    }
    if hallOfFame(game and game.save) and type(postgame.phaseFor) == "function" then
      local pg
      if type(postgame.state) == "function" then
        local ok, value = pcall(postgame.state, false)
        if ok then pg = value end
      end
      local ok, value = pcall(postgame.phaseFor, pg, game.save)
      if ok and type(value) == "string" then context.phase = value end
    end
    if titles and type(titles.currentTitle) == "function" then
      local ok, id, name = pcall(titles.currentTitle)
      if ok and type(id) == "string" then
        context.titleId, context.titleName = id, safeTitleName(name)
      end
    end
    if ngplusActive(game and game.save) and journey
        and type(journey.state) == "function" then
      local ok, run = pcall(journey.state, game.save)
      if ok and type(run) == "table" then
        context.cycle = integer(run.cycle, 1)
        context.pact = type(run.pact) == "string" and run.pact or nil
      end
    end
    return context
  end

  local function titleDialogue(actor, id, name)
    if not (type(id) == "string" and name) then return nil end
    local source = DATA_BY_ID[actor:lower() .. "_title"]
    if not source then return nil end
    local row = substitute(source, { TITLE = name })
    row.id = row.id .. "_" .. id:gsub("[^%w_]", "_")
    row.kind = "title"
    return row
  end

  local function phaseMatches(gate, phase)
    if gate == "any" then return true end
    for value in tostring(gate):gmatch("[^|]+") do
      if value == phase then return true end
    end
    return false
  end

  local function encounterSpecies(game, mapId)
    local root = game and game.data and game.data.encounters
      and game.data.encounters[mapId]
    if type(root) ~= "table" then return {} end
    local found, visited = {}, {}
    local function visit(value, depth)
      if type(value) ~= "table" or visited[value] or depth > 8 then return end
      visited[value] = true
      if type(value.species) == "string" and value.species ~= "" then
        found[value.species:upper()] = true
      end
      for _, child in pairs(value) do visit(child, depth + 1) end
    end
    visit(root, 0)
    local out = {}
    for species in pairs(found) do out[#out + 1] = species end
    table.sort(out)
    return out
  end

  function L.routeSearchClaim(game, actor, mapId, context)
    local label = MAP_NAMES[mapId]
    local species = encounterSpecies(game, mapId)
    if not (CHARACTER_IDS[actor] and label and #species > 0) then return nil end
    local templates = {}
    for _, row in ipairs(DATA_BY_ACTOR[actor]) do
      if row.category == "search" then templates[#templates + 1] = row end
    end
    if #templates == 0 then return nil end
    context = context or {}
    local speciesIndex = clamp(context.speciesPick or context.pick
      or randomInt(1, #species, "search_species"), 1, #species)
    local templateIndex = clamp(context.templatePick or context.pick
      or randomInt(1, #templates, "search_dialogue"), 1, #templates)
    local speciesId = species[speciesIndex]
    local pokemon = game and game.data and game.data.pokemon
      and game.data.pokemon[speciesId]
    local speciesName = type(pokemon) == "table"
      and type(pokemon.name) == "string" and pokemon.name or speciesId
    local row = substitute(templates[templateIndex], {
      SPECIES = speciesName:upper(), MAP = label.en,
    })
    -- German map names are canonical but share the same species authority.
    row.de = templates[templateIndex].de
      :gsub("{SPECIES}", function() return speciesName:upper() end)
      :gsub("{MAP}", function() return label.de end)
    row.text = tr(row.en, row.de)
    row.id = row.id .. "_" .. mapId:lower() .. "_" .. speciesId:lower()
    row.species, row.mapId = speciesId, mapId
    return row
  end

  local function traceOwned()
    if not rumorsEnabled then return false end
    if type(explorationDevice.status) ~= "function" then return false end
    local ok, status = pcall(explorationDevice.status)
    return ok and type(status) == "table" and status.owned == true
  end

  local function starterDefinitions()
    if type(hiddenAccessReveal.definitions) ~= "function" then return {} end
    local ok, definitions = pcall(hiddenAccessReveal.definitions)
    if not (ok and type(definitions) == "table") then return {} end
    local grouped, order = {}, {}
    for index, def in ipairs(definitions) do
      local species = type(def) == "table" and type(def.starter) == "string"
        and def.starter:upper() or nil
      local gate = def and def.eligibility
      local destination = def and (def.destination
        or def.handoff and def.handoff.destination)
      if species and gate and gate.kind == "starter"
          and type(def.id) == "string" and MAP_NAMES[def.mapId]
          and type(destination) == "table" and type(destination.map) == "string"
          and starterHabitats.maps and starterHabitats.maps[destination.map] then
        if not grouped[species] then grouped[species], order[#order + 1] = {}, species end
        grouped[species][#grouped[species] + 1] = {
          def = def, index = index, destination = destination.map,
        }
      end
    end
    return grouped, order
  end

  local function accessAvailable(game, def)
    if not traceOwned()
        or type(hiddenAccessReveal.rumorAvailable) ~= "function" then
      return false
    end
    local ok, allowed = pcall(hiddenAccessReveal.rumorAvailable, game, def)
    return ok and allowed == true
  end

  function L.rumorContract(game)
    local grouped = starterDefinitions()
    local speciesOrder, seen = {}, {}
    for _, row in ipairs(dialogueRows) do
      if row.category == "rumor" and not seen[row.species] then
        seen[row.species] = true
        speciesOrder[#speciesOrder + 1] = row.species
      end
    end
    local out = {}
    for _, species in ipairs(speciesOrder) do
      local candidates = grouped[species] or {}
      local chosen, preferred
      for _, candidate in ipairs(candidates) do
        if candidate.def.role == "STARTER_PRIMARY" then
          preferred = preferred or candidate
          if accessAvailable(game, candidate.def) then chosen = candidate break end
        end
      end
      if not chosen then
        for _, candidate in ipairs(candidates) do
          if accessAvailable(game, candidate.def) then chosen = candidate break end
        end
      end
      chosen = chosen or preferred or candidates[1]
      if chosen then
        out[#out + 1] = {
          species = species, id = chosen.def.id, mapId = chosen.def.mapId,
          role = chosen.def.role, destination = chosen.destination,
          available = accessAvailable(game, chosen.def),
          requiredAuthority =
            "TRACE+AccessV3.1.rumorAvailable+unopened-receipt",
        }
      end
    end
    return out
  end

  function L.pendingStarterRumorCount(game, s)
    if not traceOwned() then return 0 end
    s = type(s) == "table" and s or L.state(false)
    local heard = s and type(s.rumorsHeard) == "table" and s.rumorsHeard or {}
    local count = 0
    for _, contract in ipairs(L.rumorContract(game)) do
      if contract.available and heard[contract.species] ~= true then
        count = count + 1
      end
    end
    return count
  end

  function L.traceFinderQuestHint(game, s)
    if not traceOwned() then return nil end
    s = type(s) == "table" and s or L.state(false)
    local heard = s and type(s.rumorsHeard) == "table" and s.rumorsHeard or {}
    for _, contract in ipairs(L.rumorContract(game)) do
      if contract.available and heard[contract.species] == true then
        local label = MAP_NAMES[contract.mapId]
        if label then
          return tr("FIELD NOTES:\n" .. label.en .. ".",
            "FELDNOTIZEN:\n" .. label.de .. ".")
        end
      end
    end
    if L.pendingStarterRumorCount(game, s) > 0 then
      return tr(
        "NO PATH ANSWERS YET.\fLOOK FOR A RIVAL'S\nFRESH FIELD NOTES.",
        "NOCH KEIN WEG REAGIERT.\fSUCH NACH NEUEN\nFELDNOTIZEN EINES RIVALEN.")
    end
  end

  function L.selectStarterRumor(game, s, actor, context)
    if not (CHARACTER_IDS[actor] and traceOwned()) then return nil end
    local available = {}
    for _, contract in ipairs(L.rumorContract(game)) do
      if contract.available and not (s.rumorsHeard
          and s.rumorsHeard[contract.species]) then
        available[#available + 1] = contract
      end
    end
    if #available == 0 then return nil end
    context = context or {}
    local contract = available[clamp(context.pick
      or randomInt(1, #available, "rumor"), 1, #available)]
    local source = DATA_BY_ID[actor:lower() .. "_rumor_"
      .. contract.species:lower()]
    if not source then return nil end
    local label = MAP_NAMES[contract.mapId]
    local row = substitute(source, { MAP = label.en })
    row.de = source.de:gsub("{MAP}", function() return label.de end)
    row.text = tr(row.en, row.de)
    row.species, row.mapId, row.destination = contract.species,
      contract.mapId, contract.destination
    row.accessId = contract.id
    return row
  end

  function L.commitRumorHeard(s, row)
    if not (type(s) == "table" and type(row) == "table"
        and row.category == "rumor" and type(row.species) == "string") then
      return false
    end
    s.rumorsHeard = type(s.rumorsHeard) == "table" and s.rumorsHeard or {}
    s.rumorsHeard[row.species] = true
    return true
  end

  -- `rumorsHeard` is the durable quest receipt and therefore also serves as
  -- a crash-safe outbox.  Replaying it is safe because Discovery Core stages
  -- are monotonic.  This also repairs saves produced by the earlier circular
  -- gate where the dialogue persisted but no starter trace could be created.
  function L.reconcileRumorDiscoveries(s)
    if type(s) ~= "table" or type(s.rumorsHeard) ~= "table" then return false end
    local complete = true
    for species, heard in pairs(s.rumorsHeard) do
      if heard == true then
        local ok, recorded = pcall(starterHabitats.recordRumorTrace, species)
        if not ok or recorded ~= true then complete = false end
      end
    end
    return complete
  end

  local function recentSet(history)
    local out = {}
    for _, id in ipairs(history or {}) do out[id] = true end
    return out
  end

  local function rememberDialogue(s, actor, id)
    s.dialogueHistory = type(s.dialogueHistory) == "table"
      and s.dialogueHistory or {}
    local history = cleanHistory(s.dialogueHistory[actor])
    for index = #history, 1, -1 do
      if history[index] == id then table.remove(history, index) end
    end
    history[#history + 1] = id
    while #history > L.HISTORY_LIMIT do table.remove(history, 1) end
    s.dialogueHistory[actor] = history
  end

  function L.hasThirdIntroduction(s, actor)
    return type(s) == "table" and CHARACTER_IDS[actor]
      and type(s.thirdIntroductions) == "table"
      and s.thirdIntroductions[actor] == true or false
  end

  function L.hasIntroduction(s, actor)
    if not (type(s) == "table" and CHARACTER_IDS[actor]) then return false end
    return (type(s.knownActors) == "table" and s.knownActors[actor] == true)
      or L.hasThirdIntroduction(s, actor)
  end

  function L.syncKnownActors(s, game)
    local roles = L.characterRoles(game)
    if not (s and roles) then return false end
    s.knownActors = type(s.knownActors) == "table" and s.knownActors or {}
    s.knownActors[roles.player] = true
    -- In a normal completed story the authored story rival is already known.
    -- NG+ may use a different archived protagonist, so only actual introduction
    -- receipts are trusted there.
    if hallOfFame(game and game.save) and not ngplusActive(game and game.save) then
      s.knownActors[roles.rival] = true
    end
    for actor, introduced in pairs(s.thirdIntroductions or {}) do
      if introduced == true then s.knownActors[actor] = true end
    end
    return true
  end

  function L.commitDialogue(s, actor, role, row)
    if not (s and CHARACTER_IDS[actor] and type(row) == "table"
        and type(row.id) == "string") then return false end
    rememberDialogue(s, actor, row.id)
    if row.kind == "intro" then
      s.thirdIntroductions = type(s.thirdIntroductions) == "table"
        and s.thirdIntroductions or {}
      s.thirdIntroductions[actor] = true
      s.thirdIntroduced = true
      s.knownActors = type(s.knownActors) == "table" and s.knownActors or {}
      s.knownActors[actor] = true
    end
    if row.category == "rumor" then L.commitRumorHeard(s, row) end
    return true
  end

  local BATTLE_CALLBACK = {
    RED = {
      win = "red_standard_quiet_pace",
      lose = "red_standard_kind_rest",
      decline = "red_standard_champion_watch",
    },
    BLUE = {
      win = "blue_standard_pace_receipt",
      lose = "blue_standard_route_rank",
      decline = "blue_standard_team_answer",
    },
    GREEN = {
      win = "green_standard_map_upside_down",
      lose = "green_standard_snack_variable",
      decline = "green_standard_three_plans",
    },
  }
  local CALLBACK_STANDARD_IDS = {}
  for _, results in pairs(BATTLE_CALLBACK) do
    for _, id in pairs(results) do CALLBACK_STANDARD_IDS[id] = true end
  end

  local takeToken

  function L.selectDialogue(game, s, actor, role, context)
    context = context or L.progressContext(game)
    L.syncKnownActors(s, game)
    local roles = context.roles or L.characterRoles(game)
    local ownsIntro = roles and ((role == "third" and actor == roles.third)
      or (role == "rival" and actor == roles.rival
        and ngplusActive(game and game.save)))
    if ownsIntro and not L.hasIntroduction(s, actor) then
      if not (actor ~= roles.player and CHARACTER_IDS[roles.rival]) then return nil end
      local intro = copy(DATA_BY_ID["third_intro_" .. actor:lower()])
      if not intro then return nil end
      for _, key in ipairs({ "en", "de" }) do
        intro[key] = intro[key]:gsub("{MAIN_RIVAL}", roles.rival)
      end
      intro.kind = "intro"
      intro.text = tr(intro.en, intro.de)
      if context.commit ~= false then L.commitDialogue(s, actor, role, intro) end
      return intro
    end
    local history = s.dialogueHistory and s.dialogueHistory[actor] or {}
    local recent = recentSet(history)
    for id, blocked in pairs(context.excludeIds or {}) do
      if blocked then recent[id] = true end
    end

    -- A battle result is a durable story receipt, not another weighted line.
    -- Only the immediately preceding result owns the next-scene callback;
    -- committing that callback naturally consumes the one-shot priority.
    local last = history[#history]
    local result = type(last) == "string"
      and last:match("^" .. actor:lower() .. "_battle_(%a+)$")
    local callbackId = result and BATTLE_CALLBACK[actor][result] or nil
    if callbackId and (not context.forceKind
        or context.forceKind == "standard") then
      local selected = copy(DATA_BY_ID[callbackId])
      if selected then
        selected.kind, selected.text = selected.category,
          tr(selected.en, selected.de)
        if context.commit ~= false then
          L.commitDialogue(s, actor, role, selected)
        end
        return selected
      end
    end

    local mapRows, phaseRows, standardRows = {}, {}, {}
    local group = mapGroup(context.mapId)
    for _, row in ipairs(DATA_BY_ACTOR[actor] or {}) do
      local category = row.category
      local eligible = (category == "standard"
          and not CALLBACK_STANDARD_IDS[row.id])
        or (category == "progress"
          and phaseMatches(row.progressGate, context.phase))
        or (category == "map" and row.mapGroup == group)
      if eligible and (not context.forceKind
          or category == context.forceKind) then
        local candidate = copy(row)
        candidate.kind = category
        if category == "map" then mapRows[#mapRows + 1] = candidate
        elseif category == "progress" then
          phaseRows[#phaseRows + 1] = candidate
        else standardRows[#standardRows + 1] = candidate end
      end
    end

    local function firstUnseen(rows)
      for _, row in ipairs(rows) do
        if not recent[row.id] then return copy(row) end
      end
    end
    -- New facts about this exact place and current story phase are authored
    -- beats. They play once before any contextual weighted variation.
    local selected = firstUnseen(mapRows) or firstUnseen(phaseRows)
    if selected then
      selected.text = tr(selected.en, selected.de)
      if context.commit ~= false then
        L.commitDialogue(s, actor, role, selected)
      end
      return selected
    end

    local pool = {}
    for _, rows in ipairs({ mapRows, phaseRows, standardRows }) do
      for _, row in ipairs(rows) do pool[#pool + 1] = row end
    end
    local title = titleDialogue(actor, context.titleId,
      safeTitleName(context.titleName))
    -- Selected titles remain Trainer Card metadata. Keep the authored rows
    -- available for explicit catalogue review, but never add them to the
    -- ordinary in-world conversation pool.
    if title and context.forceKind == "title" then
      pool[#pool + 1] = title
    end
    if not context.forceKind or context.forceKind == "search" then
      local search = context.mapId and L.routeSearchClaim(game, actor,
        context.mapId, context.searchContext)
      if search then search.kind = "search"; pool[#pool + 1] = search end
    end
    if not context.forceKind or context.forceKind == "rumor" then
      local rumor = L.selectStarterRumor(game, s, actor, context.rumorContext)
      if rumor then rumor.kind = "rumor"; pool[#pool + 1] = rumor end
    end
    if #pool == 0 and context.forceKind then
      local fallback = copy(context)
      fallback.forceKind = nil
      return L.selectDialogue(game, s, actor, role, fallback)
    end
    if #pool == 0 then return nil end
    local available = {}
    for _, row in ipairs(pool) do
      if not recent[row.id] then available[#available + 1] = row end
    end
    if #available == 0 then
      local last = history[#history]
      for _, row in ipairs(pool) do
        if row.id ~= last then available[#available + 1] = row end
      end
    end
    if #available == 0 then available = pool end
    local totalWeight = 0
    for _, row in ipairs(available) do
      totalWeight = totalWeight + math.max(1, integer(row.weight, 1))
    end
    local roll = randomInt(1, totalWeight, "dialogue")
    selected = available[#available]
    for _, row in ipairs(available) do
      roll = roll - math.max(1, integer(row.weight, 1))
      if roll <= 0 then selected = row break end
    end
    selected = copy(selected)
    selected.text = tr(selected.en, selected.de)
    if context.commit ~= false then
      L.commitDialogue(s, actor, role, selected)
    end
    return selected
  end

  function L.chooseActor(s, roles, roll)
    if not (s and roles) then return nil end
    if not L.hasThirdIntroduction(s, roles.third)
        and integer(s.appearances) >= L.THIRD_GUARANTEE_AFTER then
      return roles.third, "third"
    end
    roll = clamp(roll or randomInt(1, L.THIRD_DENOMINATOR, "actor"),
      1, L.THIRD_DENOMINATOR)
    if roll == L.THIRD_DENOMINATOR then return roles.third, "third" end
    return roles.rival, "rival"
  end

  function L.isIntroMap(mapId)
    return INTRO_MAP_RANK[mapId] ~= nil
  end

  function L.introRequired(s, game)
    local roles = L.characterRoles(game)
    if not roles then return false end
    L.syncKnownActors(s, game)
    if ngplusActive(game and game.save) then
      return not L.hasIntroduction(s, roles.rival)
        or not L.hasIntroduction(s, roles.third)
    end
    return not L.hasIntroduction(s, roles.third)
  end

  function L.nextUnknownActor(s, game)
    local roles = L.characterRoles(game)
    if not roles then return nil end
    L.syncKnownActors(s, game)
    if ngplusActive(game and game.save)
        and not L.hasIntroduction(s, roles.rival) then
      return roles.rival, "rival"
    end
    if not L.hasIntroduction(s, roles.third) then return roles.third, "third" end
    return nil
  end

  local function roleForActor(roles, actor)
    if actor == roles.rival then return "rival" end
    if actor == roles.third then return "third" end
  end

  function L.prepareVisit(game, s, mapId, rolls)
    if not (L.VISIT_CONTRACT_ENABLED and s and L.mapEligible(game, mapId)
        and not L.introRequired(s, game)) then
      return nil
    end
    s.visitReceipts = type(s.visitReceipts) == "table" and s.visitReceipts or {}
    if s.visitReceipts[mapId] then return s.visitReceipts[mapId], false end
    local roles = L.characterRoles(game)
    if not roles then return nil end
    rolls = type(rolls) == "table" and rolls or {}
    local presence = clamp(rolls.presence
      or randomInt(1, 100, "visit_presence"), 1, 100)
    local mode = presence <= L.PRESENCE_SINGLE_PERCENT and "single"
      or presence <= L.PRESENCE_SINGLE_PERCENT + L.PRESENCE_DUO_PERCENT
        and "duo" or "none"
    local visit = {
      token = takeToken(s), mapId = mapId, mode = mode, actors = {},
      talked = {}, battleResolved = {}, battleStarted = {}, presenceRoll = presence,
      duel = false, nextChallenge = false,
    }
    if mode ~= "none" then
      local actorList
      if mode == "single" then
        local pick = clamp(rolls.actor
          or randomInt(1, 2, "visit_actor"), 1, 2)
        actorList = { pick == 1 and roles.rival or roles.third }
      else
        actorList = { roles.rival, roles.third }
        local duelRoll = clamp(rolls.duel
          or randomInt(1, 100, "visit_duel"), 1, 100)
        visit.duelRoll = duelRoll
        visit.duel = duelRoll <= L.DUEL_PERCENT
        if visit.duel then
          local nextRoll = clamp(rolls.nextChallenge
            or randomInt(1, 100, "duel_next_challenge"), 1, 100)
          visit.nextChallengeRoll = nextRoll
          visit.nextChallenge = nextRoll <= L.DUEL_NEXT_CHALLENGE_PERCENT
        end
      end
      for _, actor in ipairs(actorList) do
        local role = roleForActor(roles, actor)
        local context = L.progressContext(game)
        context.commit, context.mapId = false, mapId
        if mapGroup(mapId) == "city" then context.forceKind = "map"
        else context.forceKind = "search" end
        local dialogue = L.selectDialogue(game, s, actor, role, context)
        if visit.duel then
          local suffix = visit.nextChallenge and "duel_next" or "duel_wait"
          dialogue = localized(assert(DATA_BY_ID[actor:lower() .. "_" .. suffix]))
        end
        local battlePlan = L.buildBattlePlan(game, actor, s)
        local offerRoll = clamp((rolls.battle and rolls.battle[actor])
          or randomInt(1, 100, "visit_battle_offer_" .. actor:lower()), 1, 100)
        local offered = not visit.duel and battlePlan ~= nil
          and offerRoll <= L.BATTLE_OFFER_PERCENT
        visit.actors[#visit.actors + 1] = {
          actor = actor, role = role, dialogue = copy(dialogue),
          battlePlan = (offered or (visit.duel and visit.nextChallenge))
            and battlePlan or nil,
          battleOffered = offered or (visit.duel and visit.nextChallenge
            and battlePlan ~= nil), battleOfferRoll = offerRoll,
        }
      end
    end
    s.visitReceipts[mapId] = visit
    persist(s)
    return visit, true
  end

  local function cellOccupied(ow, x, y)
    if ow and type(ow.npcAtCell) == "function" then
      local ok, value = pcall(ow.npcAtCell, ow, x, y)
      if ok and value then return true end
    end
    for _, name in ipairs({ "npcs", "entities" }) do
      for _, entity in pairs(type(ow and ow[name]) == "table"
          and ow[name] or {}) do
        if entity and ((entity.cellX == x and entity.cellY == y)
            or (entity.targetX == x and entity.targetY == y)) then
          return true
        end
      end
    end
    return false
  end

  local function mapMethod(map, name, ...)
    local fn = map and map[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, map, ...)
    return ok and value or nil
  end

  local function safeCell(game, ow, x, y)
    local map = ow and ow.map
    if not (map and mapMethod(map, "inBounds", x, y) ~= false
        and mapMethod(map, "isWalkableCell", x, y) == true) then return false end
    if mapMethod(map, "warpAtCell", x, y)
        or mapMethod(map, "signAtCell", x, y)
        or mapMethod(map, "isWarpTileCell", x, y) == true
        or cellOccupied(ow, x, y) then return false end
    if ow.player and ((ow.player.cellX == x and ow.player.cellY == y)
        or (ow.player.targetX == x and ow.player.targetY == y)) then
      return false
    end
    if type(spawnSafety.isSafeCell) ~= "function" then return false end
    local ok, allowed = pcall(spawnSafety.isSafeCell,
      game, ow, map, x, y, { purpose = "life_of_rival" })
    return ok and allowed == true
  end

  local DIRS = {
    { 0, -1, "up", "down" },
    { 1, 0, "right", "left" },
    { 0, 1, "down", "up" },
    { -1, 0, "left", "right" },
  }
  local function approachable(game, ow, x, y)
    for _, d in ipairs(DIRS) do
      if safeCell(game, ow, x + d[1], y + d[2]) then return true end
    end
    return false
  end

  function L.findSpawnCell(game, ow, excluded, minimumDistance)
    if not (game and ow and ow.map and ow.player) then return nil end
    local px, py = tonumber(ow.player.cellX), tonumber(ow.player.cellY)
    if not (px and py) then return nil end
    local cells, queue, head, seen = {}, {}, 1, {}
    local function key(x, y) return tostring(x) .. ":" .. tostring(y) end
    seen[key(px, py)] = true
    queue[1] = { x = px, y = py, distance = 0 }
    -- A bounded safety-BFS proves that the actor is in the player's current
    -- traversable region. It cannot jump a wall into a visually nearby but
    -- unreachable map component, and it never crosses a reserved corridor.
    while head <= #queue do
      local row = queue[head]
      head = head + 1
      local occupiedByVisit = false
      for _, cell in ipairs(type(excluded) == "table" and excluded or {}) do
        if math.abs(cell.x-row.x)+math.abs(cell.y-row.y)
            < (minimumDistance or 1) then occupiedByVisit = true end
      end
      if row.distance >= 3 and not occupiedByVisit
          and approachable(game, ow, row.x, row.y) then
        cells[#cells + 1] = { x = row.x, y = row.y }
      end
      if row.distance < 8 then
        for _, d in ipairs(DIRS) do
          local x, y = row.x + d[1], row.y + d[2]
          local id = key(x, y)
          if not seen[id] and safeCell(game, ow, x, y) then
            seen[id] = true
            queue[#queue + 1] = {
              x = x, y = y, distance = row.distance + 1,
            }
          end
        end
      end
    end
    if #cells == 0 then return nil end
    return cells[randomInt(1, #cells, "spawn_cell")]
  end

  -- The intro uses a deterministic safety-BFS. A complete walk-in starts four
  -- or more proven cells away and stops beside, never on, the locked player.
  -- When that path or the public scriptMove handle is unavailable, the first
  -- deterministic visible candidate is used as a stationary interaction; no
  -- coordinate mutation pretends that a blocked movement succeeded.
  function L.findIntroStaging(game, ow)
    if not (game and ow and ow.map and ow.player) then return nil end
    local px, py = tonumber(ow.player.cellX), tonumber(ow.player.cellY)
    if not (px and py) then return nil end
    local queue, head, seen, visible = {}, 1, {}, nil
    local function key(x, y) return tostring(x) .. ":" .. tostring(y) end
    seen[key(px, py)] = true
    queue[1] = { x = px, y = py, distance = 0, outward = {} }
    while head <= #queue do
      local row = queue[head]
      head = head + 1
      for _, d in ipairs(DIRS) do
        local x, y = row.x + d[1], row.y + d[2]
        local id = key(x, y)
        if row.distance < 8 and not seen[id] and safeCell(game, ow, x, y) then
          seen[id] = true
          local outward = copy(row.outward)
          outward[#outward + 1] = d[3]
          local nextRow = {
            x = x, y = y, distance = row.distance + 1, outward = outward,
          }
          queue[#queue + 1] = nextRow
          if nextRow.distance >= 3 and approachable(game, ow, x, y)
              and not visible then
            visible = { x = x, y = y, staging = "visible", path = {} }
          end
          if nextRow.distance >= L.INTRO_WALK_DISTANCE then
            local path = {}
            -- Reverse every outward step except the first: the actor finishes
            -- one collision-safe cell from the stationary player.
            for index = #outward, 2, -1 do
              local dir = outward[index]
              for _, candidate in ipairs(DIRS) do
                if candidate[3] == dir then
                  path[#path + 1] = candidate[4]
                  break
                end
              end
            end
            if #path > 0 then
              return { x = x, y = y, staging = "walk_in", path = path }
            end
          end
        end
      end
    end
    return visible
  end

  local function starterBranch(game)
    local save = game and game.save or {}
    if edition() == "yellow" then return clamp(save.rivalStarter or 1, 1, 3) end
    local flags = save.flags or {}
    if flags.EVENT_CHOSE_CHARMANDER then return 1 end
    if flags.EVENT_CHOSE_SQUIRTLE then return 2 end
    if flags.EVENT_CHOSE_BULBASAUR then return 3 end
    return 1
  end

  local function sourceParty(game, actor)
    local trainers = game and game.data and game.data.trainers or {}
    local branch = starterBranch(game)
    local badges = badgeCount(game) or 8
    local class, logical, actual
    if hallOfFame(game and game.save) then
      class, logical, actual = "OPP_RIVAL3", branch, branch
    elseif badges <= 2 then
      class, logical = "OPP_RIVAL1", 3 + branch
      actual = edition() == "yellow" and 3 or logical
    elseif badges <= 5 then
      class, logical = "OPP_RIVAL2", 3 + branch
      actual = edition() == "yellow" and 1 + branch or logical
    elseif badges <= 7 then
      class, logical = "OPP_RIVAL2", 6 + branch
      actual = edition() == "yellow" and 4 + branch or logical
    else
      class, logical = "OPP_RIVAL2", 9 + branch
      actual = edition() == "yellow" and 7 + branch or logical
    end
    local trainer = trainers[class]
    local parties = trainer and trainer.parties
    if type(parties) ~= "table" or #parties == 0 then return nil end
    actual = clamp(actual, 1, #parties)
    local original = parties[actual]
    if type(original) ~= "table" or #original == 0 then return nil end
    local ok, resolved = pcall(rivalTeams.resolve,
      actor, class, logical, original)
    if not ok or type(resolved) ~= "table" then return nil end
    return resolved, class, logical, actual
  end

  local function speciesAllowed(game, species)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    if type(species) ~= "string" or type(def) ~= "table" then return false end
    if type(generationRules) == "table"
        and type(generationRules.speciesAvailable) == "function" then
      return generationRules.speciesAvailable(game, species, def) == true
    end
    if not (beyondKanto and type(beyondKanto.isActive) == "function") then
      return true
    end
    local ok, active = pcall(beyondKanto.isActive, game)
    if ok and active == true then return true end
    local dex
    if type(beyondKanto.speciesDex) == "function" then
      local counted, value = pcall(beyondKanto.speciesDex, game, species)
      dex = counted and tonumber(value) or nil
    end
    dex = dex or tonumber(def.dex)
    return dex ~= nil and dex >= 1 and dex <= 151
  end

  local function neutralClass(game, actor)
    local gender
    if type(characters.definition) == "function" then
      local ok, def = pcall(characters.definition, actor)
      gender = ok and def and def.gender or nil
    end
    local preferred = gender == "FEMALE"
      and { "OPP_COOLTRAINER_F", "OPP_JR_TRAINER_F" }
      or { "OPP_COOLTRAINER_M", "OPP_JR_TRAINER_M" }
    preferred[#preferred + 1] = "OPP_YOUNGSTER"
    for _, class in ipairs(preferred) do
      local trainer = game and game.data and game.data.trainers
        and game.data.trainers[class]
      if trainer and type(trainer.parties) == "table"
          and type(trainer.parties[1]) == "table" then return class end
    end
    return nil
  end

  function L.progressBattlePlan(game, plan, actor, storyTier)
    if not (type(plan) == "table" and type(plan.team) == "table"
        and #plan.team > 0 and CHARACTER_IDS[actor]) then return nil end
    local progressed = teamProgression.resolveTeam(game, plan.team, {
      actor=actor, storyTier=storyTier or "UNKNOWN",
      speciesAllowed=function(target) return speciesAllowed(game, target) end,
    })
    if type(progressed) ~= "table" or #progressed ~= #plan.team then
      return nil
    end
    local out = copy(plan)
    out.team = progressed
    return out
  end

  function L.buildBattlePlan(game, actor, s, planOptions)
    if not (L.eligible(game) and CHARACTER_IDS[actor]
        and type(postgame.newForcedBattle) == "function"
        and type(wanderers.challengeTier) == "function") then return nil end
    planOptions = type(planOptions) == "table" and planOptions or {}
    local source, sourceClass, logical, actual = sourceParty(game, actor)
    if not source then return nil end
    local bonus = randomInt(1, 3, "battle_level_bonus")
    local ok, tier = pcall(wanderers.challengeTier,
      game, bonus, { lossRelief = 0 })
    if not (ok and type(tier) == "table" and tonumber(tier.targetLevel)
        and tonumber(tier.teamSize)) then return nil end
    local clean = {}
    for _, row in ipairs(source) do
      if type(row) == "table" and speciesAllowed(game, row.species) then
        clean[#clean + 1] = copy(row)
      end
    end
    local endgame = hallOfFame(game and game.save)
    s = type(s) == "table" and s or L.state(true)
    local strength = s and normalizeStrength(s.actorStrength
      and s.actorStrength[actor]) or normalizeStrength()
    local maximum = math.max(endgame and 6 or 4, strength.rosterSize)
    local requested = planOptions.teamSize
      or (endgame and #clean or tier.teamSize)
    requested = math.max(requested, strength.rosterSize)
    local count = math.min(#clean, clamp(requested, 1, maximum))
    if count < 1 then return nil end
    local tierLevel = math.max(tonumber(tier.targetLevel) or 2,
      strength.minLevel)
    local team = {}
    for index = 1, count do
      local sourceIndex = index
      if index == count and count < #clean then sourceIndex = #clean end
      team[index] = clean[sourceIndex]
      local targetLevel = tierLevel
      if endgame then
        targetLevel = math.max(targetLevel,
          tonumber(team[index].level) or targetLevel)
      end
      targetLevel = math.max(strength.minLevel,
        targetLevel - math.max(0, integer(planOptions.levelPenalty)))
      team[index].level = clamp(targetLevel, 2, 100)
    end
    local class = neutralClass(game, actor)
    if not class then return nil end
    local plan = L.progressBattlePlan(game, {
      actor = actor, class = class, team = team, tier = copy(tier),
      sourceClass = sourceClass, sourcePartyIndex = actual,
      logicalPartyIndex = logical,
      endgame = endgame,
      fullEndgameTeam = endgame and count == #clean,
    }, actor, endgame and "ENDGAME" or "JOURNEY")
    if not plan then return nil end
    if s then
      s.actorStrength = type(s.actorStrength) == "table" and s.actorStrength or {}
      local floor = 100
      for _, row in ipairs(plan.team) do floor = math.min(floor, row.level or 2) end
      s.actorStrength[actor] = {
        stage = math.max(strength.stage,
          clamp(tier.stage or tier.teamStage or count, 1, 6)),
        minLevel = math.max(strength.minLevel, floor),
        rosterSize = math.max(strength.rosterSize, #plan.team),
      }
      persist(s)
      plan.strengthFloor = copy(s.actorStrength[actor])
    end
    return plan
  end

  takeToken = function(s)
    local token = "life-rival:" .. tostring(math.max(1,
      integer(s.nextToken, 1)))
    s.nextToken = math.max(1, integer(s.nextToken, 1)) + 1
    return token
  end

  function L.prepareIntroAppearance(game, s, mapId)
    local roles = L.characterRoles(game)
    local introActor, introRole = L.nextUnknownActor(s, game)
    if not (roles and L.isIntroMap(mapId) and L.mapEligible(game, mapId)
        and s.introArmedMap == mapId
        and introActor) then return nil end
    local context = L.progressContext(game)
    context.commit, context.roles, context.mapId = false, roles, mapId
    local dialogue = L.selectDialogue(
      game, s, introActor, introRole, context)
    if not dialogue then return nil end
    return {
      token = takeToken(s), mapId = mapId, actor = introActor,
      role = introRole, arc = "intro",
      dialogue = copy(dialogue),
      phase = context.phase, titleId = context.titleId,
      battleOffered = false, battlePlan = nil,
      spawnCounted = false, talked = false, battleStarted = false,
    }
  end

  function L.prepareAppearance(game, s, mapId)
    local roles = L.characterRoles(game)
    if not (roles and L.mapEligible(game, mapId)) then return nil end
    if not L.hasThirdIntroduction(s, roles.third) then
      return L.prepareIntroAppearance(game, s, mapId)
    end
    local actor, role = L.chooseActor(s, roles)
    local context = L.progressContext(game)
    context.commit, context.mapId = false, mapId
    local dialogue = L.selectDialogue(game, s, actor, role, context)
    if not dialogue then return nil end
    local battlePlan = L.buildBattlePlan(game, actor, s)
    local offered = battlePlan ~= nil
      and not (role == "third" and not L.hasThirdIntroduction(s, actor))
      and randomInt(1, L.BATTLE_DENOMINATOR, "battle") == 1
    return {
      token = takeToken(s), mapId = mapId, actor = actor, role = role,
      arc = "followup",
      dialogue = copy(dialogue),
      phase = context.phase, titleId = context.titleId,
      battleOffered = offered, battlePlan = offered and battlePlan or nil,
      spawnCounted = false, talked = false, battleStarted = false,
    }
  end

  function L.bindParallelJourney(runtime)
    if runtime == nil then L.parallelJourney = nil; return true end
    if type(runtime) ~= "table" or type(runtime.isBusy) ~= "function" then
      return false
    end
    L.parallelJourney = runtime
    return true
  end

  local function contextSafe(game, ignoreParallel)
    if wanderers.active then return false end
    if not ignoreParallel and L.parallelJourney
        and L.parallelJourney.isBusy() then return false end
    if type(wanderers.contextSafe) ~= "function" then return false end
    local ok, value = pcall(wanderers.contextSafe, game)
    return ok and value == true
  end
  L.contextSafe = contextSafe

  local function fieldSprite(actor)
    if type(characters.getCharacterSprite) ~= "function" then return nil end
    local ok, visual = pcall(characters.getCharacterSprite, actor, "overworld")
    return ok and type(visual) == "table"
      and type(visual.sprite) == "string" and visual.sprite or nil
  end

  function L.spawnVisit(game, s, visit)
    local ow = game and game.overworld
    if not (ow and visit and visit.mapId == ow.map.id
        and visit.mode ~= "none" and #visit.actors > 0) then return false end
    local entries, cells = {}, {}
    local duelCells
    if visit.duel then
      -- Reserve the pair before spawning either actor. The shared NPC
      -- safety guard excludes cells around an already spawned actor, so
      -- searching afterwards silently separated supposed duel partners.
      local rejected = {}
      local function approachExcept(x, y, other)
        for _, d in ipairs(DIRS) do
          local ax, ay = x + d[1], y + d[2]
          if (ax ~= other.x or ay ~= other.y) and safeCell(game, ow, ax, ay) then
            return true
          end
        end
        return false
      end
      for _ = 1, 128 do
        local first = L.findSpawnCell(game, ow, rejected, 1)
        if not first then break end
        for _, d in ipairs(DIRS) do
          local second = { x = first.x + d[1], y = first.y + d[2] }
          if safeCell(game, ow, second.x, second.y)
              and approachExcept(first.x, first.y, second)
              and approachExcept(second.x, second.y, first) then
            duelCells = { first, second }
            break
          end
        end
        if duelCells then break end
        rejected[#rejected + 1] = first
      end
      if not duelCells then return false end
    end
    local function rollbackSpawn()
      for _, entry in ipairs(entries) do
        if entry.npcId and mod.world and type(mod.world.removeNpc) == "function" then
          pcall(mod.world.removeNpc, mod.world, entry.npcId)
        end
      end
      return false
    end
    for index, row in ipairs(visit.actors) do
      local cell = duelCells and duelCells[index]
      -- Ordinary visits are independent searches, not an accidental pair.
      -- They start at least six cells apart, then walk independently.
      cell = cell or L.findSpawnCell(game, ow, cells, visit.duel and 1 or 6)
      local sprite = fieldSprite(row.actor)
      if not (cell and sprite and mod.world
          and type(mod.world.spawnNpc) == "function") then return rollbackSpawn() end
      cells[#cells + 1] = cell
      local ok, npcId = pcall(mod.world.spawnNpc, mod.world, visit.mapId, {
        name = "KA_LIFE_VISIT_" .. row.actor .. "_" .. index,
        sprite = sprite, movement = visit.duel and "STAY" or "WALK",
        range = visit.duel and "DOWN" or "ANY_DIR",
        text = L.TEXT, x = cell.x, y = cell.y,
      })
      if not (ok and npcId) then return rollbackSpawn() end
      local handle
      if type(mod.world.npc) == "function" then
        local found, value = pcall(mod.world.npc, mod.world, visit.mapId, npcId)
        handle = found and value or nil
      end
      if not handle then
        if type(mod.world.removeNpc) == "function" then
          pcall(mod.world.removeNpc, mod.world, npcId)
        end
        return rollbackSpawn()
      end
      handle.ascendantCharacter = row.actor
      if handle.npc then handle.npc.ascendantCharacter = row.actor end
      entries[#entries + 1] = {
        npcId = npcId, npc = handle, actor = row.actor, row = row, cell = cell,
      }
    end
    if visit.duel and #entries == 2 then
      local left, right = entries[1], entries[2]
      local horizontal = math.abs(left.cell.x - right.cell.x)
        >= math.abs(left.cell.y - right.cell.y)
      local facing = horizontal and (left.cell.x < right.cell.x and "right" or "left")
        or (left.cell.y < right.cell.y and "down" or "up")
      local opposite = facing == "right" and "left"
        or facing == "left" and "right"
        or facing == "down" and "up" or "down"
      if type(left.npc.face) == "function" then pcall(left.npc.face, left.npc, facing) end
      if type(right.npc.face) == "function" then pcall(right.npc.face, right.npc, opposite) end
    end
    if not visit.spawnCounted then
      visit.spawnCounted = true
      s.appearances = integer(s.appearances) + 1
      for _, row in ipairs(visit.actors) do
        s.actorAppearances[row.actor] = integer(s.actorAppearances[row.actor]) + 1
      end
      s.lastAppearanceMap = visit.mapId
      persist(s)
    end
    L.active = {
      game = game, save = game.save, ow = ow, mapId = visit.mapId,
      token = visit.token, visit = visit, entries = entries,
      sessionIds = {}, talkCount = 0,
    }
    return true
  end

  local function releaseIntroLock(active)
    if not active then return end
    local ow = active.ow
    if active.ownsEngaging and ow then ow.engaging = false end
    if active.ownsInputLock and ow and ow.player then
      ow.player.inputLocked = false
    end
    active.ownsEngaging, active.ownsInputLock = false, false
  end

  function L.cleanup(active)
    active = active or L.active
    if not active then return false end
    releaseIntroLock(active)
    if active.entries then
      for _, entry in ipairs(active.entries) do
        if entry.npcId and mod.world and type(mod.world.removeNpc) == "function" then
          pcall(mod.world.removeNpc, mod.world, entry.npcId)
        end
      end
    elseif active.npcId and mod.world and type(mod.world.removeNpc) == "function" then
      pcall(mod.world.removeNpc, mod.world, active.npcId)
    end
    local rawNpc = active.npc and (active.npc.npc or active.npc)
    if rawNpc then rawNpc.frozen = false end
    if L.active == active then L.active = nil end
    return true
  end

  local function abandonDifferentMap(s, mapId)
    local pending = s and s.pending
    if not pending or pending.mapId == mapId then return false end
    if pending.arc == "intro" and not pending.talked then
      -- An unseen intro keeps its token, frozen copy and spawn counter. A later
      -- Route 1/Viridian entry may restage that same transaction exactly once.
      if L.isIntroMap(mapId) then pending.mapId = mapId end
      persist(s)
      return true
    end
    if pending.spawnCounted then
      L.scheduleNext(s, mapId)
    else
      s.pending, s.due = nil, true
      s.lastEligibleMap = L.isEligibleMap(mapId) and mapId
        or s.lastEligibleMap
    end
    persist(s)
    return true
  end

  function L.armIntro(game, s, mapId)
    if not (s and L.eligible(game) and L.isIntroMap(mapId)
        and L.mapEligible(game, mapId)) then return false end
    local roles = L.characterRoles(game)
    if not roles then return false end
    if not L.introRequired(s, game) then
      if s.introArmedMap ~= nil then
        s.introArmedMap = nil
        persist(s)
      end
      return false
    end
    if s.pending and s.pending.arc ~= "intro" then
      -- A v1 random appearance may have been frozen before the v2 intro gate.
      -- It owns no battle-start receipt yet, so retire it without presentation;
      -- accepted battles remain guarded by the existing battleStarted branch.
      if s.pending.battleStarted then return false end
      s.pending = nil
    elseif s.pending and s.pending.arc == "intro" then
      s.pending.mapId = mapId
    end
    s.introArmedMap = mapId
    return persist(s)
  end

  local function pendingMatchesRoles(s, game)
    local pending, roles = s and s.pending, L.characterRoles(game)
    if not (pending and roles) then return false end
    return pending.actor == (pending.role == "rival"
      and roles.rival or roles.third)
  end

  local startIntroStaging, tickIntroStaging

  function L.trySpawn(game)
    game = game or L.game
    if L.active and L.active.save ~= (game and game.save) then
      L.cleanup(L.active)
    end
    if L.active or not (L.eligible(game) and contextSafe(game)) then return false end
    local ow = game.overworld
    local mapId = ow and ow.map and ow.map.id
    if not L.mapEligible(game, mapId) then return false end
    local s = L.state(true)
    if not s then return false end
    local visit = s.visitReceipts and s.visitReceipts[mapId]
    if visit then return L.spawnVisit(game, s, visit) end
    if abandonDifferentMap(s, mapId) then return false end
    if s.pending and s.pending.talked and not s.pending.battleStarted then
      -- The successful textbox push is the once-only scene receipt. If a save
      -- reload lands before its completion callback, retire any received
      -- non-battle scene instead of staging and speaking it a second time.
      local intro = s.pending.arc == "intro"
      L.scheduleNext(s, mapId)
      if intro then s.introArmedMap = nil end
      persist(s)
      return false
    end
    local introRequired = L.introRequired(s, game)
    if introRequired then
      if not ((s.pending and s.pending.arc == "intro")
          or s.introArmedMap == mapId) then return false end
    elseif not (s.due or s.pending) then
      return false
    end
    if s.pending and (s.pending.battleStarted
        or not pendingMatchesRoles(s, game)) then
      -- A crash after accepting a battle never replays its native prize, and
      -- a changed character matrix never materializes a stale identity.
      L.scheduleNext(s, mapId)
      persist(s)
      return false
    end
    local introTransaction = (s.pending and s.pending.arc == "intro")
      or introRequired
    local staging = introTransaction and L.findIntroStaging(game, ow) or nil
    local cell = staging or L.findSpawnCell(game, ow)
    if not cell then return false end
    if not s.pending then
      s.pending = introTransaction
          and L.prepareIntroAppearance(game, s, mapId)
        or L.prepareAppearance(game, s, mapId)
      if not s.pending then return false end
      -- The transaction is durable before spawnNpc can expose an object.
      if not persist(s) then
        s.pending = nil
        return false
      end
    end
    local pending = s.pending
    local sprite = fieldSprite(pending.actor)
    if not sprite or not (mod.world and type(mod.world.spawnNpc) == "function") then
      return false
    end
    local ok, npcId = pcall(mod.world.spawnNpc, mod.world, mapId, {
      -- Do not include RIVAL in the object name: extended_characters reserves
      -- that substring for actual vanilla story-rival objects.
      name = "KA_LIFE_ACTOR_" .. pending.actor,
      sprite = sprite, movement = "STAY", range = "DOWN",
      text = L.TEXT, x = cell.x, y = cell.y,
    })
    if not (ok and npcId) then return false end
    local handle
    if type(mod.world.npc) == "function" then
      local found, value = pcall(mod.world.npc, mod.world, mapId, npcId)
      handle = found and value or nil
    end
    if not handle then
      if type(mod.world.removeNpc) == "function" then
        pcall(mod.world.removeNpc, mod.world, npcId)
      end
      return false
    end
    handle.ascendantCharacter = pending.actor
    if handle.npc then handle.npc.ascendantCharacter = pending.actor end
    if not pending.spawnCounted then
      pending.spawnCounted = true
      s.appearances = integer(s.appearances) + 1
      s.actorAppearances[pending.actor] =
        integer(s.actorAppearances[pending.actor]) + 1
      s.lastAppearanceMap = mapId
      if not persist(s) then
        pending.spawnCounted = false
        s.appearances = math.max(0, integer(s.appearances) - 1)
        s.actorAppearances[pending.actor] = math.max(0,
          integer(s.actorAppearances[pending.actor]) - 1)
        if type(mod.world.removeNpc) == "function" then
          pcall(mod.world.removeNpc, mod.world, npcId)
        end
        return false
      end
    end
    L.active = {
      game = game, save = game.save, ow = ow, mapId = mapId,
      npcId = npcId, npc = handle,
      token = pending.token, actor = pending.actor, role = pending.role,
      arc = pending.arc, sessionIds = {}, talkCount = 0,
    }
    if pending.arc == "intro" and startIntroStaging then
      startIntroStaging(L.active, pending, staging)
    end
    return true
  end

  local function displayName(actor)
    if type(characters.displayName) == "function" then
      local ok, value = pcall(characters.displayName, actor)
      if ok and type(value) == "string" and value ~= "" then return value end
    end
    return actor
  end

  local function portraitPath(actor)
    if type(characters.getCharacterSprite) ~= "function" then return nil, false end
    local ok, visual = pcall(characters.getCharacterSprite,
      actor, "rivalPortrait")
    if not (ok and type(visual) == "table"
        and type(visual.path) == "string") then return nil, false end
    local path = visual.path
    if path:sub(1, 5) ~= "save/" and mod.path then
      path = mod.path .. "/" .. path
    end
    return path, visual.trueColor ~= false
  end

  local function makeActorBattle(game, plan, actor, context)
    local trainer = game and game.data and game.data.trainers
      and game.data.trainers[plan.class]
    if type(trainer) ~= "table" then
      return pcall(postgame.newForcedBattle, game, plan.class,
        copy(plan.team), nil, context)
    end
    -- Engine 0.1.90 freezes trainerPic and introText inside newTrainer. Apply
    -- the actor presentation only for that synchronous construction window,
    -- then restore the shared trainer registry before returning.
    local oldName, oldPic, oldMoney = trainer.name, trainer.pic,
      trainer.baseMoney
    local pic = portraitPath(actor)
    trainer.name = displayName(actor)
    if pic then trainer.pic = pic end
    trainer.baseMoney = 0
    local ok, battle = pcall(postgame.newForcedBattle, game, plan.class,
      copy(plan.team), nil, context)
    trainer.name, trainer.pic, trainer.baseMoney = oldName, oldPic, oldMoney
    return ok, battle
  end

  local function emit(name, payload)
    if type(opts.emit) == "function" then return opts.emit(name, payload) end
    local ok, Runtime = pcall(require, "src.mods.Runtime")
    if ok and Runtime and type(Runtime.emit) == "function" then
      return Runtime.emit(name, payload)
    end
  end

  local function TextBox(game, text, done, boxOpts)
    if type(opts.textBox) == "function" then
      return opts.textBox(game, text, done, boxOpts)
    end
    local ok, module = pcall(require, "src.render.TextBox")
    if not (ok and module and type(module.new) == "function") then return nil end
    return module.new(game, text, done, boxOpts)
  end

  local function pushText(game, text, done, boxOpts)
    local box = TextBox(game, text, done, boxOpts)
    if not (box and game and game.stack and type(game.stack.push) == "function") then
      return false
    end
    local ok = pcall(game.stack.push, game.stack, box)
    return ok
  end

  local function finishAppearance(active, result, done)
    if L.active ~= active then if done then done() end return false end
    local s = L.state(true)
    if not (s and s.pending and s.pending.token == active.token) then
      L.cleanup(active)
      if done then done() end
      return false
    end
    if result == "win" or result == "lose" then
      s.battles = integer(s.battles) + 1
      if result == "win" then s.wins = integer(s.wins) + 1
      else s.losses = integer(s.losses) + 1 end
    elseif result == "decline" then
      s.declines = integer(s.declines) + 1
    end
    local resultId = active.actor:lower() .. "_battle_" .. tostring(result)
    if DATA_BY_ID[resultId] then
      rememberDialogue(s, active.actor, resultId)
    end
    local intro = s.pending.arc == "intro"
    L.scheduleNext(s, active.mapId)
    if intro then s.introArmedMap = nil end
    persist(s)
    L.cleanup(active)
    if done then done() end
    return true
  end

  local RESULT_TEXT = {
    RED = {
      win={
        "RED: Well fought.\fYou earned this one.\fI'll claim the next.",
        "RED: Gut gekämpft.\fDiesen Sieg hast du verdient.\fDen nächsten hole ich mir.",
      },
      lose={
        "RED: Strong battle.\fHeal your team.\fI'll expect your best\nnext time.",
        "RED: Starker Kampf.\fHeile dein Team.\fNächstes Mal erwarte\nich dein Bestes.",
      },
    },
    BLUE = {
      win={
        "BLUE: You got me.\fEnjoy the headline.\fI'm writing the sequel.",
        "BLUE: Du warst besser.\fGenieß deinen Sieg.\fBeim nächsten Mal bin ich dran.",
      },
      lose={
        "BLUE: Lead defended.\fTrain up.\nMake the rematch count.",
        "BLUE: Die Führung bleibt bei mir.\fTrainiere weiter. Bei der Revanche\nwill ich dein Bestes sehen.",
      },
    },
    GREEN = {
      win={
        "GREEN: You win!\fExcellent experiment.\fResult noted.\nRematch scheduled.",
        "GREEN: Du gewinnst!\fStarkes Experiment.\fErgebnis notiert.\nRevanche eingeplant.",
      },
      lose={
        "GREEN: Plan worked!\fThe backup plan was\na victory snack.",
        "GREEN: Plan gelungen!\fDer Ersatzplan war\nein Siegersnack.",
      },
    },
  }

  local function resultText(actor, result)
    local row = DATA_BY_ID[actor:lower() .. "_battle_" .. tostring(result)]
    return row and tr(row.en, row.de) or nil
  end

  -- Visit callbacks must share locals declared before their first use.
  local startVisitBattle

  local function releaseVisitTalk(active, entry, done)
    active.talking = false
    local raw = entry and entry.npc and (entry.npc.npc or entry.npc)
    if raw then raw.frozen = false end
    if done then done() end
  end

  local function finishVisitOutcome(active, entry, result, done)
    local s = L.state(true)
    local visit = s and s.visitReceipts and s.visitReceipts[active.mapId]
    if visit and visit.token == active.token
        and visit.battleResolved[entry.actor] ~= true then
      visit.battleResolved[entry.actor] = true
      s.battles = integer(s.battles) + 1
      if result == "win" then s.wins = integer(s.wins) + 1
      else s.losses = integer(s.losses) + 1 end
      rememberDialogue(s, entry.actor,
        entry.actor:lower() .. "_battle_" .. result)
      persist(s)
    end
    releaseVisitTalk(active, entry, done)
  end

  local function decorateBattle(game, battle, active, pending, done)
    battle.ascendantLifeRival = true
    battle.ascendantLifeRivalCharacter = active.actor
    battle.ascendantLifeRivalToken = active.token
    battle.rematch = true
    battle.rematchRewardSuppressed = true
    battle.ascendantNoBonusReward = true
    battle.ascendantForcedSource = "life_rival"
    local pic, trueColor = portraitPath(active.actor)
    local original = battle.trainer or {}
    battle.trainer = setmetatable({
      name = displayName(active.actor), pic = pic or original.pic,
      trueColor = pic and trueColor or original.trueColor,
      ascendantCharacter = active.actor,
      -- Engine 0.1.90 pays baseMoney * final enemy level directly. The
      -- metadata suppression markers are for other reward owners and do not
      -- suppress that native payout, so this battle itself must own zero.
      baseMoney = 0,
    }, { __index = original })
    if type(postgame.applyMastery) == "function" then
      pcall(postgame.applyMastery, game, battle, {
        kind = "life_rival", key = active.actor,
        progress = integer(L.state(true).wins),
        masteryWins = integer(L.state(true).wins),
      })
    end
    local moneyBefore = tonumber(game.save and game.save.money) or 0
    local finishCalled = false
    battle.onFinish = function(result)
      if finishCalled then return end
      finishCalled = true
      local outcome = result == "win" and "win" or "lose"
      if active.ow and type(active.ow.afterBattle) == "function" then
        pcall(active.ow.afterBattle, active.ow, result, battle)
      end
      if outcome == "lose" and game.save then game.save.money = moneyBefore end
      local actor = active.visit and pending.actor or active.actor
      local text = resultText(actor, outcome)
      if active.visit then finishVisitOutcome(active, pending, outcome, nil)
      else finishAppearance(active, outcome, nil) end
      if text then pushText(game, text, done) elseif done then done() end
    end
    return battle
  end

  local function startBattle(active, pending, done)
    local game = active.game
    local plan = L.progressBattlePlan(game, pending.battlePlan, active.actor,
      hallOfFame(game and game.save) and "ENDGAME" or "JOURNEY")
    if not (type(plan) == "table" and type(plan.team) == "table"
        and #plan.team > 0) then
      return finishAppearance(active, "decline", done)
    end
    local s = L.state(true)
    if not (s and s.pending and s.pending.token == active.token) then
      return finishAppearance(active, "decline", done)
    end
    s.pending.battlePlan = copy(plan)
    s.pending.battleStarted = true
    if not persist(s) then
      s.pending.battleStarted = false
      return finishAppearance(active, "decline", done)
    end
    local ok, battle = makeActorBattle(game, plan, active.actor, {
        kind = "life_rival", key = active.actor,
        actor = active.actor, token = active.token,
        source = "life_rival", suppressRewards = true,
      })
    if not (ok and battle and not battle.dead) then
      if mod.log and type(mod.log.warn) == "function" then
        mod.log:warn("Life of a Rival battle construction failed closed")
      end
      return finishAppearance(active, "decline", done)
    end
    decorateBattle(game, battle, active, pending, done)
    emit("world.trainer_engaged", {
      npc = active.npc, trainerClass = plan.class, partyIndex = 1,
      source = "life_rival",
    })
    if not (active.ow and type(active.ow.pushBattle) == "function") then
      return finishAppearance(active, "decline", done)
    end
    local pushed = pcall(active.ow.pushBattle, active.ow, battle)
    if not pushed then return finishAppearance(active, "decline", done) end
    return true
  end

  startVisitBattle = function(active, entry, visit, done)
    local game, actor = active.game, entry.actor
    local plan = L.progressBattlePlan(game, entry.row.battlePlan, actor,
      hallOfFame(game and game.save) and "ENDGAME" or "JOURNEY")
    if not (plan and type(plan.team) == "table" and #plan.team > 0) then
      releaseVisitTalk(active, entry, done)
      return false
    end
    local s = L.state(true)
    local current = s and s.visitReceipts and s.visitReceipts[active.mapId]
    if not (current and current.token == visit.token
        and current.battleStarted[actor] ~= true) then
      releaseVisitTalk(active, entry, done)
      return false
    end
    current.battleStarted[actor] = true
    if not persist(s) then
      current.battleStarted[actor] = nil
      releaseVisitTalk(active, entry, done)
      return false
    end
    local ok, battle = makeActorBattle(game, plan, actor, {
      kind = "life_rival", key = actor, actor = actor, token = visit.token,
      source = "life_rival_visit", suppressRewards = true,
    })
    if not (ok and battle and not battle.dead) then
      current.battleResolved[actor] = true
      persist(s)
      releaseVisitTalk(active, entry, done)
      return false
    end
    active.actor, active.npc = actor, entry.npc
    decorateBattle(game, battle, active, entry, done)
    emit("world.trainer_engaged", {
      npc = entry.npc, trainerClass = plan.class, partyIndex = 1,
      source = "life_rival_visit",
    })
    if not (active.ow and type(active.ow.pushBattle) == "function") then
      releaseVisitTalk(active, entry, done)
      return false
    end
    return pcall(active.ow.pushBattle, active.ow, battle)
  end

  local DECLINE = {
    RED={
      "RED: Of course.\fWe'll choose a better\nmoment.",
      "RED: Schon gut.\fDann ein andermal.",
    },
    BLUE={
      "BLUE: Wise choice.\fFor now.\nThe lead stays mine.",
      "BLUE: Kluge Wahl.\fVorerst bleibt die\nFührung bei mir.",
    },
    GREEN={
      "GREEN: Fine!\fMy backup plan says\n\"picnic first.\"",
      "GREEN: Gut!\fMein Ersatzplan sagt\n\"erst Picknick\".",
    },
  }

  local BATTLE_PROMPT = {
    RED={
      "Would you honor me\nwith a battle?",
      "Kämpfst du gegen mich?",
    },
    BLUE={
      "Ready to prove\nthat lead?",
      "Bereit zu beweisen, dass dein\nerstes Pokémon führen kann?",
    },
    GREEN={
      "Field test? Optional.\fMy notes survive\na no.",
      "Lust auf einen Feldtest?\fEin Nein ist auch in Ordnung.",
    },
  }

  -- A detached copy gives tests and maintainer tooling one review boundary
  -- for every line that production can select, including post-battle and
  -- decline text that otherwise requires a complete encounter transaction.
  function L.voiceContract()
    local out = { rows = copy(dialogueRows), intro = {}, dialogue = {},
      title = {}, battlePrompt = {}, result = {}, decline = {} }
    for _, row in ipairs(dialogueRows) do
      if row.category == "intro" then out.intro[row.actor] = copy(row)
      elseif row.category == "title" then out.title[row.actor] = copy(row)
      elseif row.category == "battle" then
        local result = row.id:match("_battle_(.+)$")
        local pair = { row.en, row.de, en = row.en, de = row.de,
          id = row.id, category = row.category }
        if result == "prompt" then out.battlePrompt[row.actor] = pair
        elseif result == "decline" then out.decline[row.actor] = pair
        else
          out.result[row.actor] = out.result[row.actor] or {}
          out.result[row.actor][result] = pair
        end
      else
        local voiceRow = copy(row)
        voiceRow.kind = voiceRow.category
        if voiceRow.category == "progress" then
          voiceRow.phases = {}
          for phase in voiceRow.progressGate:gmatch("[^|]+") do
            voiceRow.phases[phase] = true
          end
        end
        out.dialogue[row.actor] = out.dialogue[row.actor] or {}
        out.dialogue[row.actor][#out.dialogue[row.actor] + 1] = voiceRow
      end
    end
    return out
  end

  local function commitTalkReceipt(s, pending)
    if pending.talked then return true end
    local history = copy(s.dialogueHistory and s.dialogueHistory[pending.actor])
    local introductions = copy(s.thirdIntroductions)
    local heard = copy(s.rumorsHeard)
    local introduced, talks = s.thirdIntroduced, s.talks
    pending.talked = true
    s.talks = integer(s.talks) + 1
    L.commitDialogue(s, pending.actor, pending.role, pending.dialogue)
    if persist(s) then
      L.reconcileRumorDiscoveries(s)
      return true
    end
    pending.talked, s.talks = false, talks
    s.thirdIntroduced, s.thirdIntroductions = introduced, introductions
    s.rumorsHeard = heard
    s.dialogueHistory[pending.actor] = history
    return false
  end

  local function visitEntryFor(active, npc)
    for _, entry in ipairs(active.entries or {}) do
      local raw = entry.npc and (entry.npc.npc or entry.npc)
      if npc == entry.npc or npc == raw or npc.id == entry.npcId then return entry end
    end
  end

  function L.handleVisitTalk(game, ow, npc, done)
    local active = L.active
    local entry = active and active.visit and visitEntryFor(active, npc)
    if not (entry and game == active.game and ow == active.ow
        and active.mapId == ow.map.id and not active.talking) then return false end
    local s = L.state(true)
    local visit = s and s.visitReceipts and s.visitReceipts[active.mapId]
    if not (visit and visit.token == active.token) then return false end
    active.talking = true
    local raw = entry.npc and (entry.npc.npc or entry.npc)
    if raw then raw.frozen = true end
    if entry.npc and type(entry.npc.facePlayer) == "function" then
      pcall(entry.npc.facePlayer, entry.npc, ow.player)
    elseif raw and type(raw.facePlayer) == "function" then
      pcall(raw.facePlayer, raw, ow.player)
    end
    local actor, row = entry.actor, entry.row
    if visit.talked[actor] then
      local suffix = mapGroup(active.mapId) == "city"
        and "followup_city" or "followup_route"
      local follow = localized(assert(DATA_BY_ID[actor:lower() .. "_" .. suffix]))
      pushText(game, follow.text, function()
        releaseVisitTalk(active, entry, done)
      end)
      return true
    end
    visit.talked[actor] = true
    s.talks = integer(s.talks) + 1
    L.commitDialogue(s, actor, row.role, row.dialogue)
    persist(s)
    L.reconcileRumorDiscoveries(s)
    local canChallenge = row.battleOffered == true
      and visit.battleResolved[actor] ~= true
    if not canChallenge then
      pushText(game, row.dialogue.text, function()
        releaseVisitTalk(active, entry, done)
      end)
      return true
    end
    local promptRow = DATA_BY_ID[actor:lower() .. "_battle_prompt"]
    local prompt = promptRow and tr(promptRow.en, promptRow.de) or ""
    pushText(game, row.dialogue.text .. "\f" .. prompt, nil, {
      defaultNo = true,
      choice = function(yes)
        if yes then return startVisitBattle(active, entry, visit, done) end
        if visit.battleResolved[actor] ~= true then
          visit.battleResolved[actor] = true
          s.declines = integer(s.declines) + 1
          rememberDialogue(s, actor, actor:lower() .. "_battle_decline")
          persist(s)
        end
        local decline = DATA_BY_ID[actor:lower() .. "_battle_decline"]
        local text = decline and tr(decline.en, decline.de)
        if text then
          pushText(game, text, function()
            releaseVisitTalk(active, entry, done)
          end)
        else releaseVisitTalk(active, entry, done) end
      end,
    })
    return true
  end

  function L.handleTalk(game, ow, npc, done)
    local active = L.active
    if active and active.visit then return L.handleVisitTalk(game, ow, npc, done) end
    if not (active and game == active.game and ow == active.ow and npc
        and (npc == active.npc or npc.id == active.npcId)
        and active.mapId == ow.map.id and not active.talking) then return false end
    local s = L.state(true)
    local pending = s and s.pending
    if not (pending and pending.token == active.token) then
      L.cleanup(active)
      return false
    end
    active.talking = true
    active.npc = npc
    npc.frozen = true
    if type(npc.facePlayer) == "function" then pcall(npc.facePlayer, npc, ow.player) end
    if not pending.battleOffered then
      local shown = pushText(game, pending.dialogue.text, function()
        finishAppearance(active, "talk", done)
      end)
      if shown then
        commitTalkReceipt(s, pending)
        active.sessionIds[pending.dialogue.id] = true
        active.talkCount = 1
      else
        finishAppearance(active, "talk", done)
      end
      return true
    end
    local row = DATA_BY_ID[active.actor:lower() .. "_battle_prompt"]
    local prompt = row and tr(row.en, row.de)
      or tr("Battle while we're here?", "Kämpfen wir, wenn wir\nschon hier sind?")
    local shown = pushText(game, pending.dialogue.text .. "\f" .. prompt, nil, {
      defaultNo = true,
      choice = function(yes)
        if yes then return startBattle(active, pending, done) end
        local row = DATA_BY_ID[active.actor:lower() .. "_battle_decline"]
        local text = row and tr(row.en, row.de) or nil
        finishAppearance(active, "decline", nil)
        if text then pushText(game, text, done) elseif done then done() end
      end,
    })
    if shown then
      commitTalkReceipt(s, pending)
      active.sessionIds[pending.dialogue.id] = true
      active.talkCount = 1
    else
      finishAppearance(active, "talk", done)
    end
    return true
  end

  local function faceIntroActor(active, firstDirection)
    local handle = active and active.npc
    if handle and type(handle.face) == "function" and firstDirection then
      pcall(handle.face, handle, firstDirection)
      return
    end
    local raw = handle and (handle.npc or handle)
    if raw and type(raw.facePlayer) == "function" then
      pcall(raw.facePlayer, raw, active.ow and active.ow.player)
    end
  end

  tickIntroStaging = function(active, dt)
    if not (active and active.approaching) then return false end
    dt = tonumber(dt)
    if not dt or dt <= 0 then dt = 1 / 60 end
    -- A single debugger hitch must not turn the fallback into another long
    -- wait, but ordinary frame deltas still provide a real two-second bound.
    dt = math.min(dt, 0.25)
    active.introWatchdog = math.max(0,
      (tonumber(active.introWatchdog) or L.INTRO_WATCHDOG_SECONDS) - dt)
    if active.introWatchdog > 0 then return false end
    -- scriptMove may report success without ever calling onDone. Retire the
    -- walk transaction, release only locks owned by this feature, and leave
    -- the already spawned actor as a normal stationary interaction.
    active.approaching, active.introWatchdog = false, nil
    releaseIntroLock(active)
    faceIntroActor(active, active.introFallbackDirection)
    local raw = active.npc and (active.npc.npc or active.npc)
    if raw then raw.frozen = false end
    return true
  end

  startIntroStaging = function(active, pending, staging)
    local handle = active and active.npc
    local path = staging and staging.path or {}
    if not (staging and staging.staging == "walk_in" and #path > 0
        and handle and type(handle.scriptMove) == "function") then
      faceIntroActor(active, path[1])
      return "visible"
    end
    -- Never take an input lock on an engine/fixture that cannot advance the
    -- watchdog while movement is suppressed.
    if L.introWatchdogAvailable ~= true then
      faceIntroActor(active, path[1])
      return "visible"
    end
    local ow = active.ow
    if not (ow and ow.player) then return "visible" end
    if ow.engaging ~= true then
      ow.engaging, active.ownsEngaging = true, true
    end
    if ow.player.inputLocked ~= true then
      ow.player.inputLocked, active.ownsInputLock = true, true
    end
    active.approaching = true
    active.introFallbackDirection = path[1]
    active.introWatchdog = L.INTRO_WATCHDOG_SECONDS
    faceIntroActor(active, path[1])
    local function walk(index)
      if L.active ~= active or not active.approaching then
        releaseIntroLock(active)
        return
      end
      local direction = path[index]
      if not direction then
        active.approaching = false
        releaseIntroLock(active)
        local raw = handle.npc or handle
        L.handleTalk(active.game, active.ow, raw)
        return
      end
      active.introWatchdog = L.INTRO_WATCHDOG_SECONDS
      local ok, moved = pcall(handle.scriptMove,
        handle, direction, 1, function() walk(index + 1) end)
      if not ok or moved == false then
        active.approaching = false
        releaseIntroLock(active)
        faceIntroActor(active, direction)
      end
    end
    walk(1)
    return "walk_in"
  end

  local function resetSpawnRetry(game, mapId)
    L.spawnRetry = {
      save = game and game.save or nil,
      mapId = mapId,
      remaining = 0,
    }
  end

  local function trySpawnWithBackoff(game, mapId)
    local retry = L.spawnRetry
    if not (retry and retry.save == (game and game.save)
        and retry.mapId == mapId) then
      resetSpawnRetry(game, mapId)
      retry = L.spawnRetry
    end
    if retry.remaining > 0 then
      retry.remaining = retry.remaining - 1
      return false
    end
    local spawned = L.trySpawn(game)
    if spawned then
      L.spawnRetry = nil
    else
      retry.remaining = L.SPAWN_RETRY_STEPS
    end
    return spawned
  end

  function L.onMapEntered(game, mapId)
    resetSpawnRetry(game, mapId)
    if L.active and (L.active.mapId ~= mapId
        or L.active.save ~= (game and game.save)) then L.cleanup(L.active) end
    if not L.eligible(game) then return false end
    local s = L.state(true)
    if not s then return false end
    abandonDifferentMap(s, mapId)
    if L.introRequired(s, game) then
      return L.armIntro(game, s, mapId)
    end
    if s.introArmedMap ~= nil then
      s.introArmedMap = nil
      persist(s)
    end
    if L.mapEligible(game, mapId) then
      L.prepareVisit(game, s, mapId)
    end
    return true
  end

  if mod.content and mod.content.map_scripts
      and type(mod.content.map_scripts.register) == "function" then
    for mapId in pairs(ELIGIBLE_MAPS) do
      mod.content.map_scripts:register(mapId, {
        priority = 2850,
        talk = {
          [L.TEXT] = function(game, ow, npc, done)
            return L.handleTalk(game, ow, npc, done)
          end,
        },
      })
    end
  end

  local function rememberGame(ev)
    local nextGame = ev and ev.game or L.game
    if L.active then L.cleanup(L.active) end
    L.spawnRetry = nil
    L.game = nextGame
    if L.eligible(nextGame) then L.state(true) end
  end

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("game.ready", function(ev)
      L.game = ev and ev.game or L.game
    end, 1050)
    mod.events:on("save.loaded", rememberGame, 1050)
    mod.events:on("save.created", rememberGame, 1050)
    mod.events:on("map.entered", function(ev)
      local game = ev and ev.game or L.game
      local mapId = ev and (ev.mapId or ev.map and ev.map.id)
      L.onMapEntered(game, mapId)
    end, 2850)
    mod.events:on("world.stepped", function(ev)
      local game = ev and ev.game or L.game
      if not L.eligible(game) then
        if L.active then L.cleanup(L.active) end
        return
      end
      if L.active then return end
      local mapId = ev and ev.mapId
        or game.overworld and game.overworld.map and game.overworld.map.id
      local s = L.state(true)
      if not s then return end
      local visit = s.visitReceipts and s.visitReceipts[mapId]
      if visit then
        if visit.mode ~= "none" then trySpawnWithBackoff(game, mapId) end
        return
      end
      if s.pending then
        if not abandonDifferentMap(s, mapId) then
          trySpawnWithBackoff(game, mapId)
        end
        return
      end
      if L.introRequired(s, game) then
        if s.introArmedMap == mapId then
          trySpawnWithBackoff(game, mapId)
        end
        return
      end
      L.advanceCadence(s, mapId)
      persist(s)
      if s.due then trySpawnWithBackoff(game, mapId) end
    end, 4550)
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    L.introWatchdogAvailable = true
    L.introWatchdogUnwrap = mod.hooks:wrap("input.step",
      function(nextStep, game, dt)
        local result = nextStep(game, dt)
        if L.active and L.active.approaching then
          tickIntroStaging(L.active, dt)
        end
        return result
      end, 4550)
  end

  return L
end
