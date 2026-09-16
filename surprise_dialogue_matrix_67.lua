-- Optional, data-only dialogue matrix for Surprise Trainers.
--
-- The title/reward owner keeps token persistence. This card only selects
-- authored bilingual fragments from a normalized encounter context and can
-- be disabled without touching title unlocks, encounter cadence or rewards.

return function(mod, opts)
  opts = opts or {}
  local M = { VERSION = 1 }

  local GROUP_BY_CLASS = {
    OPP_YOUNGSTER = "young", OPP_BUG_CATCHER = "young", OPP_LASS = "young",
    OPP_JR_TRAINER_M = "ace", OPP_JR_TRAINER_F = "ace",
    OPP_COOLTRAINER_M = "ace", OPP_COOLTRAINER_F = "ace",
    OPP_SCIENTIST = "scholar", OPP_SUPER_NERD = "scholar",
    OPP_ENGINEER = "scholar", OPP_POKEMANIAC = "scholar",
    OPP_HIKER = "outdoor", OPP_FISHER = "outdoor",
    OPP_BIRD_KEEPER = "outdoor", OPP_TAMER = "outdoor",
    OPP_SAILOR = "water", OPP_SWIMMER = "water",
    OPP_ROCKER = "show", OPP_JUGGLER = "show",
    OPP_GAMBLER = "show", OPP_BEAUTY = "show",
    OPP_BIKER = "tough", OPP_CUE_BALL = "tough",
    OPP_BLACKBELT = "tough", OPP_BURGLAR = "tough",
    OPP_GENTLEMAN = "formal", OPP_CHANNELER = "mystic",
    OPP_PSYCHIC_TR = "mystic",
  }

  local SPEAKERS = {
    OPP_YOUNGSTER = { "YOUNGSTER", "KNIRPS" },
    OPP_BUG_CATCHER = { "BUG CATCHER", "KÄFERSAMMLER" },
    OPP_LASS = { "LASS", "GÖRE" },
    OPP_JR_TRAINER_M = { "TRAINER", "TRAINER" },
    OPP_JR_TRAINER_F = { "TRAINER", "TRAINERIN" },
    OPP_COOLTRAINER_M = { "ACE TRAINER", "ASS-TRAINER" },
    OPP_COOLTRAINER_F = { "ACE TRAINER", "ASS-TRAINERIN" },
    OPP_SCIENTIST = { "SCIENTIST", "FORSCHER" },
    OPP_SUPER_NERD = { "SUPER NERD", "STREBER" },
    OPP_ENGINEER = { "ENGINEER", "INGENIEUR" },
    OPP_POKEMANIAC = { "POKéMANIAC", "POKÉMANIAC" },
    OPP_HIKER = { "HIKER", "WANDERER" },
    OPP_FISHER = { "FISHER", "ANGLER" },
    OPP_BIRD_KEEPER = { "BIRD KEEPER", "VOGELWÄRTER" },
    OPP_TAMER = { "TAMER", "DOMPTEUR" },
    OPP_SAILOR = { "SAILOR", "MATROSE" },
    OPP_SWIMMER = { "SWIMMER", "SCHWIMMER" },
    OPP_ROCKER = { "ROCKER", "ROCKER" },
    OPP_JUGGLER = { "JUGGLER", "JONGLEUR" },
    OPP_GAMBLER = { "GAMBLER", "SPIELER" },
    OPP_BEAUTY = { "BEAUTY", "SCHÖNHEIT" },
    OPP_BIKER = { "BIKER", "BIKER" },
    OPP_CUE_BALL = { "CUE BALL", "ROWDY" },
    OPP_BLACKBELT = { "BLACKBELT", "KARATEKA" },
    OPP_BURGLAR = { "BURGLAR", "EINBRECHER" },
    OPP_GENTLEMAN = { "GENTLEMAN", "GENTLEMAN" },
    OPP_CHANNELER = { "CHANNELER", "EXORZISTIN" },
    OPP_PSYCHIC_TR = { "PSYCHIC", "PSYCHO" },
  }

  local CHALLENGE = {
    young = {
      { "I practiced on every route.\fNow I want to see\nwhat you can do!",
        "Ich habe auf jeder\nRoute trainiert.\fJetzt will ich sehen,\nwas du kannst!" },
      { "Everyone talks about your team.\fLet me see it\nfor myself!",
        "Alle reden von\ndeinem Team.\fIch will es mit\neigenen Augen sehen!" },
      { "I finally found you!\fCome on--one fair\nbattle!",
        "Endlich habe ich\ndich gefunden!\fLos--ein fairer\nKampf!" },
    },
    ace = {
      { "A title is a promise.\fShow me you can\nkeep yours.",
        "Ein Titel ist ein\nVersprechen.\fZeig mir, dass du\ndeines hältst." },
      { "I studied your last battles.\fThis one will not\ngo the same way.",
        "Ich kenne deine\nletzten Kämpfe.\fDieser hier wird\nanders laufen." },
      { "No audience, no excuses.\fLet our teams\ndecide this.",
        "Kein Publikum, keine\nAusreden.\fUnsere Teams sollen\nentscheiden." },
    },
    scholar = {
      { "Your record raises\nan interesting question.\fLet us test it\nin battle.",
        "Deine Bilanz wirft\neine Frage auf.\fPrüfen wir sie\nim Kampf." },
      { "I prepared a new strategy.\fYou are the right\ntest for it.",
        "Ich habe eine neue\nStrategie entwickelt.\fDu bist der richtige\nTest dafür." },
      { "Data is useful.\fA real battle tells\nus much more.",
        "Daten sind nützlich.\fEin echter Kampf\nzeigt uns mehr." },
    },
    outdoor = {
      { "The road made both\nour teams stronger.\fLet us compare\nhow far we came.",
        "Der Weg hat unsere\nTeams stärker gemacht.\fSehen wir, wie weit\nwir gekommen sind." },
      { "I followed the stories\nfrom town to town.\fNow the trail\nends with you.",
        "Ich hörte die Geschichten\nin jeder Stadt.\fJetzt führt die Spur\nzu dir." },
      { "A long journey deserves\na good battle.\fAre you ready?",
        "Zu einer langen Reise\ngehört ein guter Kampf.\fBist du bereit?" },
    },
    water = {
      { "Word travels fast\nalong the coast.\fLet us see if the\ntide favors you.",
        "An der Küste spricht\nsich alles schnell herum.\fMal sehen, ob die Flut\nheute für dich ist." },
      { "My team crossed rough water\nto find this battle.\fDo not hold back!",
        "Mein Team trotzte rauer See\nfür diesen Kampf.\fHalte dich nicht zurück!" },
      { "The current brought\nus together.\fNow we battle!",
        "Die Strömung hat uns\nzusammengeführt.\fJetzt kämpfen wir!" },
    },
    show = {
      { "The stage is wherever\ntwo strong teams meet.\fGive me a good show!",
        "Die Bühne ist dort, wo\nstarke Teams sich treffen.\fZeig mir eine gute Show!" },
      { "I heard your name\nfrom the next route.\fTime for an encore!",
        "Dein Name klang bis\nzur nächsten Route.\fZeit für eine Zugabe!" },
      { "No tricks this time.\fJust timing, nerve\nand Pokémon!",
        "Diesmal keine Tricks.\fNur Timing, Mut\nund POKÉMON!" },
    },
    tough = {
      { "Reputation means nothing\nwithout a hard fight.\fProve yours!",
        "Ein Ruf zählt nichts\nohne harten Kampf.\fBeweise deinen!" },
      { "You look confident.\fGood. I did not come\nfor an easy win.",
        "Du wirkst sicher.\fGut. Ich suche keinen\nleichten Sieg." },
      { "We trained too hard\nto turn back now.\fLet us settle this!",
        "Wir haben zu hart\ntrainiert, um umzukehren.\fEntscheiden wir es!" },
    },
    formal = {
      { "Your reputation precedes you.\fMay I request\na proper battle?",
        "Dein Ruf eilt dir voraus.\fDarf ich um einen\nehrlichen Kampf bitten?" },
      { "A fine team should be\ntested with respect.\fShall we begin?",
        "Ein gutes Team verdient\neine würdige Prüfung.\fWollen wir beginnen?" },
      { "I have waited for\nthis meeting.\fLet us make it\nworth remembering.",
        "Ich habe auf diese\nBegegnung gewartet.\fMachen wir sie\nunvergesslich." },
    },
    mystic = {
      { "I sensed your approach\nbefore I saw you.\fOur battle is\nthe reason why.",
        "Ich spürte dich, bevor\nich dich sah.\fUnser Kampf ist\nder Grund dafür." },
      { "Many paths surround you.\fOnly this battle\nis clear.",
        "Viele Wege liegen\nvor dir.\fNur dieser Kampf\nist deutlich." },
      { "Your team carries\na powerful memory.\fLet me witness it.",
        "Dein Team trägt\neine starke Erinnerung.\fLass sie mich erleben." },
    },
  }

  local TONE = {
    proud = {
      { "Defend that name!", "Verteidige diesen Namen!" },
      { "Show why you earned it!", "Zeig, warum du ihn trägst!" },
      { "Let the title speak in battle!", "Lass den Titel im Kampf sprechen!" },
    },
    neutral = {
      { "Let us write the next line together.", "Schreiben wir die nächste Zeile gemeinsam." },
      { "Now I want the story from you.", "Jetzt will ich die Geschichte von dir hören." },
      { "One honest battle will tell me enough.", "Ein ehrlicher Kampf sagt mir genug." },
    },
    teasing = {
      { "I hope the title came with a strategy.", "Hoffentlich gehört zum Titel auch eine Strategie." },
      { "That is a big name. Can your team fill it?", "Ein großer Name. Kann dein Team ihn ausfüllen?" },
      { "Try not to lose the title on this route.", "Verlier den Titel bloß nicht auf dieser Route." },
    },
  }

  local PROGRESS = {
    first = {
      { "This is our first meeting.", "Wir begegnen uns zum ersten Mal." },
      { "I wanted my first impression to be a battle.", "Mein erster Eindruck sollte ein Kampf sein." },
    },
    repeat_encounter = {
      { "Kanto has already told me about your earlier road trials.", "Kanto hat mir schon von deinen früheren Wegprüfungen erzählt." },
      { "You have done this before. So have I.", "Du kennst solche Kämpfe schon. Ich auch." },
    },
    legacy = {
      { "More than one journey follows in your footsteps.", "Mehr als eine Reise klingt in deinen Schritten nach." },
      { "Your team carries memories from another path.", "Dein Team trägt Erinnerungen an einen anderen Weg." },
    },
    champion = {
      { "The League knows your name. I still want my own answer.", "Die Liga kennt deinen Namen. Ich will trotzdem meine eigene Antwort." },
      { "Beating the League did not end your journey. Good.", "Mit der Liga war deine Reise nicht zu Ende. Gut so." },
    },
  }

  local FAREWELL = {
    win = {
      { "You earned that victory.\fWe will train and\nmeet you again.", "Diesen Sieg hast du\ndir verdient.\fWir trainieren weiter\nund sehen uns wieder." },
      { "Now I understand\nwhy Kanto remembers you.\fUntil next time!", "Jetzt verstehe ich,\nwarum Kanto dich kennt.\fBis zum nächsten Mal!" },
      { "Your team found the\nanswer before mine did.\fI will remember that.", "Dein Team fand die\nAntwort vor meinem.\fDas merke ich mir." },
      { "No excuses.\fYou were better today.\fNext time begins now.", "Keine Ausreden.\fHeute warst du besser.\fAb jetzt trainieren wir\nfür das nächste Mal." },
    },
    loss = {
      { "Good battle.\fYour team never gave up.\fWe will meet again.", "Guter Kampf.\fDein Team gab nie auf.\fWir sehen uns wieder." },
      { "We won today.\fTrain on--the next one\nmay end differently.", "Heute haben wir gewonnen.\fTrainiere weiter--der nächste\nKampf kann anders enden." },
      { "That was closer than\nthe result suggests.\fKeep going.", "Das war knapper, als\ndas Ergebnis vermuten lässt.\fBleib dran." },
      { "Our plan worked once.\fIt will not surprise\nyou twice.", "Unser Plan ging einmal auf.\fZweimal überrascht er\ndich nicht." },
    },
  }

  local RARE = {
    { "I also found a rare Pokémon trace nearby.\fWin or lose, keep your eyes open.",
      "Ganz in der Nähe fand ich auch die Spur eines seltenen POKÉMON.\fHalte die Augen offen--egal, wie der Kampf endet." },
    { "There is more than a battle waiting on this route.\fWatch for an unusual encounter.",
      "Auf dieser Route wartet mehr als nur ein Kampf.\fAchte auf eine ungewöhnliche Begegnung." },
  }

  local function pick(rows, purpose, random)
    if type(rows) ~= "table" or #rows == 0 then return nil end
    local index = type(random) == "function" and random(1, #rows, purpose) or 1
    index = math.max(1, math.min(#rows, math.floor(tonumber(index) or 1)))
    return rows[index]
  end

  local function classId(active)
    return active and active.archetype and active.archetype.class
      or active and active.class or ""
  end

  local function speaker(active)
    return SPEAKERS[classId(active)] or { "WANDERER", "WANDERTRAINER" }
  end

  local function progressPool(context)
    if context.postLeague then return PROGRESS.champion, "champion" end
    if tonumber(context.legacyCycle) and tonumber(context.legacyCycle) >= 2 then
      return PROGRESS.legacy, "legacy"
    end
    if tonumber(context.priorWins or 0) + tonumber(context.priorLosses or 0) > 0 then
      return PROGRESS.repeat_encounter, "repeat"
    end
    return PROGRESS.first, "first"
  end

  function M.enabled()
    if opts.enabled then return opts.enabled() ~= false end
    if mod and mod.options and type(mod.options.get) == "function" then
      return mod.options:get("surprise_dialogue_matrix") ~= false
    end
    return true
  end

  function M.challenge(active, context)
    if not M.enabled() then return nil, "disabled" end
    context = type(context) == "table" and context or {}
    local random = context.random
    local group = GROUP_BY_CLASS[classId(active)] or "outdoor"
    local voice = pick(CHALLENGE[group], "dialogue_class", random)
    local tone = pick(TONE[context.tone] or TONE.neutral,
      "dialogue_tone", random)
    local progress, progressKind = progressPool(context)
    local journey = pick(progress, "dialogue_progress", random)
    local who = speaker(active)
    local name = tostring(context.playerName or "TRAINER"):upper()
    local enAddress = context.titleEn and (context.titleEn .. " " .. name)
      or name
    local deAddress = context.titleDe and (context.titleDe .. " " .. name)
      or name
    local en = who[1] .. ":\n" .. enAddress .. "!\f" .. voice[1]
      .. "\f" .. tone[1] .. "\f" .. journey[1]
    local de = who[2] .. ":\n" .. deAddress .. "!\f" .. voice[2]
      .. "\f" .. tone[2] .. "\f" .. journey[2]
    if context.rareOffer == true then
      local rare = pick(RARE, "dialogue_rare", random)
      en, de = en .. "\f" .. rare[1], de .. "\f" .. rare[2]
    end
    return { en = en, de = de, group = group, progress = progressKind }
  end

  function M.farewell(active, result, context)
    if not M.enabled() then return nil, "disabled" end
    result = result == "win" and "win" or result == "loss" and "loss" or nil
    if not result then return nil, "invalid-result" end
    context = type(context) == "table" and context or {}
    local pair = pick(FAREWELL[result], "farewell_" .. result, context.random)
    local who = speaker(active)
    local en, de = who[1] .. ":\n" .. pair[1], who[2] .. ":\n" .. pair[2]
    if context.rareOffer == true then
      local rare = pick(RARE, "farewell_rare", context.random)
      en, de = en .. "\f" .. rare[1], de .. "\f" .. rare[2]
    end
    if context.postLeague then
      en = en .. "\fThe League was not your last worthy battle."
      de = de .. "\fDie Liga war nicht dein letzter würdiger Kampf."
    elseif tonumber(context.legacyCycle) and tonumber(context.legacyCycle) >= 2 then
      en = en .. "\fMay our paths cross in another journey."
      de = de .. "\fVielleicht kreuzen sich unsere Wege in einer anderen Reise."
    end
    return { en = en, de = de }
  end

  function M.counts()
    local classLines = 0
    for _, rows in pairs(CHALLENGE) do classLines = classLines + #rows end
    return {
      classGroups = 9, classLines = classLines, toneLines = 9,
      progressLines = 8, farewellLines = 8, rareLines = #RARE,
    }
  end

  return M
end
