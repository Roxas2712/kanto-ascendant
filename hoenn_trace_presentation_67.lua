-- Optional presentation Card around Hoenn Discovery's existing durable trace.
-- This module never rolls, unlocks, catches or persists a species. It owns
-- exactly one field announcement and the trace battle's music selection.

return function(mod, opts)
  opts = opts or {}
  local P = { PRIORITY = 3900, pending = nil }
  local activeGame

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end

  local function enabled()
    return not (mod.options and mod.options.get
      and mod.options:get("hoenn_trace_presentation") == false)
  end

  local function trainerName(battle)
    local value = battle and battle.trainer and battle.trainer.name
    if type(value) ~= "string" or value == "" then
      return tr("WANDERER", "WANDERTRAINER")
    end
    return value
  end

  local function speciesName(game, species)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    local value = def and def.name
    return type(value) == "string" and value ~= "" and value or species
  end

  local voices = {
    DEFAULT = {
      { "One more travel tip.", "Noch ein Reisetipp." },
      { "A little discovery for you.", "Eine kleine Entdeckung für dich." },
      { "Here is something worth a detour.", "Dafür lohnt sich ein Abstecher." },
      { "Before I move on...", "Bevor ich weiterziehe..." },
      { "I made a note of this.", "Das habe ich mir notiert." },
      { "Take this tip along.", "Nimm diesen Tipp mit." },
    },
    YOUNGSTER = {
      { "Hey, guess what!", "Hey, rate mal!" },
      { "You have to check this out!", "Das musst du dir ansehen!" },
      { "This made my whole day!", "Das war mein Tageshighlight!" },
      { "Wait, I nearly forgot!", "Halt, fast vergessen!" },
      { "My friends will be so jealous!", "Da werden meine Freunde staunen!" },
      { "Ready for another adventure?", "Lust auf noch ein Abenteuer?" },
    },
    LASS = {
      { "I had such a lovely surprise!", "Das war eine schöne Überraschung!" },
      { "I kept hoping to see it again.", "Ich wollte es unbedingt wiedersehen." },
      { "Let me share my lucky find.", "Ich verrate dir meinen Glücksfund." },
      { "I stopped just to watch it.", "Dafür bin ich stehen geblieben." },
      { "This is my favorite travel story.", "Das war mein schönstes Reiseerlebnis." },
      { "I think you would like this.", "Das könnte dir gefallen." },
    },
    BUG_CATCHER = {
      { "My net nearly slipped!", "Fast wäre mir das Netz entglitten!" },
      { "I was checking the undergrowth.", "Ich habe das Unterholz abgesucht." },
      { "Keep your eyes low!", "Schau auch mal nach unten!" },
      { "Not every find fits in a net!", "Nicht jeder Fund passt ins Netz!" },
      { "I took a break from bug hunting.", "Ich machte Pause vom Käferfangen." },
      { "A good catcher notices everything.", "Ein guter Fänger sieht genau hin." },
    },
    HIKER = {
      { "That was worth the long walk!", "Dafür hat sich der Marsch gelohnt!" },
      { "My boots have seen a lot.", "Meine Stiefel kommen viel herum." },
      { "I stopped to catch my breath.", "Ich musste kurz verschnaufen." },
      { "Let me mark your next stop.", "Ich verrate dir einen guten Halt." },
      { "A good hike needs a good find!", "So macht Wandern Spaß!" },
      { "Keep some room in your backpack.", "Lass noch Platz im Rucksack." },
    },
    FISHER = {
      { "Patience paid off again.", "Geduld hat sich wieder ausgezahlt." },
      { "I put my rod aside for a moment.", "Ich legte die Angel kurz beiseite." },
      { "An angler keeps a sharp eye.", "Ein Angler schaut genau hin." },
      { "This one was a surprise!", "Das war eine Überraschung!" },
      { "Not all my stories are about fish.", "Nicht jede Geschichte handelt von Fischen." },
      { "Here is a tip from an old angler.", "Ein Tipp von einem alten Angler." },
    },
    SWIMMER = {
      { "A little tip from my travels!", "Ein Tipp von meinen Ausflügen!" },
      { "I took a break from swimming.", "Ich machte eine Schwimmpause." },
      { "That was a refreshing surprise!", "Das war eine schöne Abwechslung!" },
      { "I was catching my breath.", "Ich holte gerade Luft." },
      { "There is more to see on shore, too.", "Auch an Land gibt es viel zu sehen." },
      { "Here is my find of the day.", "Das war mein Fund des Tages." },
    },
    SAILOR = {
      { "Listen up, mate!", "Hör zu, Kamerad!" },
      { "Put this in your logbook.", "Das gehört ins Logbuch." },
      { "A sailor never forgets a good find.", "So einen Fund vergisst kein Seemann." },
      { "I was taking some shore leave.", "Ich hatte gerade Landgang." },
      { "Here is a tale for your next voyage.", "Eine Geschichte für deine nächste Reise." },
      { "Fair winds brought me a surprise!", "Das war ein guter Reisetag!" },
    },
    BIRD_KEEPER = {
      { "I looked down for a change.", "Ich schaute ausnahmsweise nach unten." },
      { "My birds were not the only sight.", "Es gab nicht nur Vögel zu sehen." },
      { "A sharp eye helps on the ground, too.", "Scharfe Augen helfen auch am Boden." },
      { "I paused on my birdwatching walk.", "Ich machte Pause beim Vogelbeobachten." },
      { "I nearly missed this one!", "Fast hätte ich es übersehen!" },
      { "Here is a sighting for your notes.", "Eine Sichtung für deine Notizen." },
    },
    BLACKBELT = {
      { "Stay focused on your surroundings.", "Achte auf deine Umgebung." },
      { "I found it during a training break.", "Das war in meiner Trainingspause." },
      { "Patience is part of training.", "Geduld gehört zum Training." },
      { "A keen eye is a useful skill.", "Ein wacher Blick ist wichtig." },
      { "My training took an interesting turn.", "Mein Training nahm eine neue Wendung." },
      { "Let your next lesson be discovery.", "Auch Entdeckungen machen dich stärker." },
    },
    SCIENTIST = {
      { "An observation for your records.", "Eine Beobachtung für deine Unterlagen." },
      { "I checked my notes twice.", "Ich habe meine Notizen geprüft." },
      { "This sighting deserves a field visit.", "Diese Sichtung verdient einen Besuch." },
      { "Here is my latest field observation.", "Meine neueste Feldbeobachtung." },
      { "I recorded the location carefully.", "Den Fundort habe ich genau notiert." },
      { "A useful addition to your research.", "Das könnte deiner Forschung helfen." },
    },
    SUPER_NERD = {
      { "I knew my notes would be useful!", "Ich wusste, dass meine Notizen helfen!" },
      { "I checked the species carefully.", "Ich habe die Art genau geprüft." },
      { "My field notes have a new entry.", "Ein neuer Eintrag in meinen Feldnotizen." },
      { "This beats reading about it!", "Besser, als nur davon zu lesen!" },
      { "Here is something for your collection.", "Ein Tipp für deine Sammlung." },
      { "I almost dropped my notebook!", "Fast fiel mir mein Notizbuch herunter!" },
    },
    POKEMANIAC = {
      { "I would know that Pokemon anywhere!", "Dieses Pokémon erkenne ich überall!" },
      { "What a find for a collector!", "Was für ein Fund für einen Sammler!" },
      { "I could talk about this all day.", "Davon könnte ich ewig erzählen." },
      { "That was the highlight of my search.", "Das war der Höhepunkt meiner Suche." },
      { "My collection can wait for a story.", "Für diese Geschichte mache ich Pause." },
      { "You understand why I was excited!", "Du verstehst meine Begeisterung!" },
    },
    ENGINEER = {
      { "I made a note during my break.", "Das habe ich in der Pause notiert." },
      { "My route had an unexpected stop.", "Meine Strecke hatte einen Extra-Halt." },
      { "Here is a precise location.", "Ich kann dir den Ort genau nennen." },
      { "I like a tip you can actually use.", "Ich mag Tipps, mit denen man etwas anfängt." },
      { "This was outside my usual work.", "Das lag außerhalb meiner üblichen Arbeit." },
      { "A small discovery between jobs.", "Eine Entdeckung zwischen zwei Aufträgen." },
    },
    ROCKER = {
      { "That find really rocked!", "Dieser Fund hat gerockt!" },
      { "I stopped humming for a second.", "Da hörte ich kurz auf zu summen." },
      { "Here is a little encore!", "Hier kommt eine kleine Zugabe!" },
      { "This deserves its own song!", "Das verdient ein eigenes Lied!" },
      { "One last note before I go.", "Noch eine Note zum Abschied." },
      { "Listen to this discovery!", "Hör dir diesen Fund an!" },
    },
    BIKER = {
      { "I hit the brakes for this!", "Dafür habe ich gebremst!" },
      { "One stop was worth the ride.", "Dieser Halt war die Fahrt wert." },
      { "Here is a tip from the road.", "Ein Tipp von unterwegs." },
      { "I parked to get a better look.", "Ich hielt an, um genauer hinzusehen." },
      { "That made a good pit stop.", "Das war ein guter Zwischenstopp." },
      { "Keep your eyes open out there.", "Halt unterwegs die Augen offen." },
    },
    CUE_BALL = {
      { "All right, one useful tip.", "Na gut, ein brauchbarer Tipp." },
      { "Even I stopped to look.", "Da blieb sogar ich stehen." },
      { "That got my attention.", "Das hat mich neugierig gemacht." },
      { "You did not hear this from just anyone.", "So einen Tipp gibt dir nicht jeder." },
      { "Take a look for yourself.", "Schau es dir selbst an." },
      { "I know a worthwhile stop.", "Ich kenne einen lohnenden Halt." },
    },
    BURGLAR = {
      { "I keep an eye out for rare finds.", "Ich habe ein Auge für seltene Funde." },
      { "This tip is yours for free.", "Diesen Tipp gibt es gratis." },
      { "I noticed something on my rounds.", "Auf meiner Runde fiel mir etwas auf." },
      { "No lockpicks needed for this one.", "Dafür brauchst du keinen Dietrich." },
      { "A sharp eye beats a heavy bag.", "Ein scharfer Blick zahlt sich aus." },
      { "I remember exactly where it was.", "Ich weiß noch genau, wo es war." },
    },
    ROCKET = {
      { "Fine, here is a tip.", "Na gut, hier ist ein Tipp." },
      { "I was scouting the area.", "Ich habe die Gegend erkundet." },
      { "Do not waste this information.", "Mach etwas aus dieser Information." },
      { "I noticed it while passing through.", "Beim Vorbeigehen fiel es mir auf." },
      { "Call this a little inside information.", "Nenn es einen kleinen Insider-Tipp." },
      { "You might want to follow this up.", "Dem solltest du nachgehen." },
    },
    GAMBLER = {
      { "My lucky find of the day!", "Mein Glücksfund des Tages!" },
      { "This tip costs you nothing.", "Dieser Tipp kostet dich nichts." },
      { "Fortune had a surprise for me.", "Das Glück hatte eine Überraschung parat." },
      { "I would not keep this to myself.", "Das möchte ich dir nicht vorenthalten." },
      { "Sometimes it pays to take a detour.", "Manchmal lohnt sich ein Umweg." },
      { "Luck favors an attentive traveler.", "Aufmerksame Reisende haben mehr Glück." },
    },
    JUGGLER = {
      { "I nearly dropped everything!", "Fast hätte ich alles fallen lassen!" },
      { "Here is one more little surprise.", "Noch eine kleine Überraschung." },
      { "This caught me off balance.", "Das brachte mich aus dem Takt." },
      { "I paused my practice for a look.", "Dafür unterbrach ich meine Übung." },
      { "Keep your eyes on this one!", "Behalte das im Auge!" },
      { "A good trip needs a surprise.", "Zu einer guten Reise gehört Überraschung." },
    },
    TAMER = {
      { "I watched it for a while.", "Ich habe es eine Weile beobachtet." },
      { "A trainer should know local wildlife.", "Trainer sollten die Tierwelt kennen." },
      { "That was an interesting encounter.", "Das war eine interessante Begegnung." },
      { "I gave it plenty of space.", "Ich habe etwas Abstand gehalten." },
      { "Observe first, then approach.", "Erst beobachten, dann nähern." },
      { "Here is a useful field tip.", "Ein nützlicher Tipp von unterwegs." },
    },
    CHANNELER = {
      { "Something drew my attention.", "Etwas zog meinen Blick auf sich." },
      { "I remember that meeting clearly.", "An diese Begegnung erinnere ich mich gut." },
      { "A quiet moment brought a surprise.", "Ein stiller Moment voller Überraschung." },
      { "Not every strange meeting is a ghost.", "Nicht jede seltsame Begegnung ist ein Geist." },
      { "I have a sighting to share.", "Ich möchte dir eine Sichtung verraten." },
      { "Perhaps our paths crossed for a reason.", "Vielleicht trafen wir uns nicht zufällig." },
    },
    PSYCHIC_TR = {
      { "This was an observation, not a vision.", "Eine Beobachtung, keine Vision." },
      { "I noticed it during my travels.", "Es fiel mir auf meiner Reise auf." },
      { "A moment of focus helped.", "Ein aufmerksamer Moment genügte." },
      { "You need no psychic power for this tip.", "Für diesen Tipp brauchst du keine Psi-Kraft." },
      { "I remember the place clearly.", "An den Ort erinnere ich mich genau." },
      { "An interesting meeting stayed with me.", "Diese Begegnung blieb mir im Gedächtnis." },
    },
    GENTLEMAN = {
      { "May I offer a travel tip?", "Darf ich einen Reisetipp geben?" },
      { "A most pleasant discovery.", "Eine äußerst erfreuliche Entdeckung." },
      { "Allow me to share an observation.", "Erlaub mir eine Beobachtung." },
      { "I made a memorable stop.", "Dieser Halt blieb mir im Gedächtnis." },
      { "This may be of interest to you.", "Das könnte dich interessieren." },
      { "One small recommendation before I leave.", "Noch ein kleiner Tipp zum Abschied." },
    },
    BEAUTY = {
      { "That was a lovely sight!", "Das war ein schöner Anblick!" },
      { "I had to stop and look.", "Ich musste einfach stehen bleiben." },
      { "Some finds make a trip special.", "Manche Funde machen eine Reise besonders." },
      { "Here is a little travel secret.", "Ein kleines Reisegeheimnis für dich." },
      { "That encounter made me smile.", "Bei dieser Begegnung musste ich lächeln." },
      { "I have a delightful tip for you.", "Ich habe einen schönen Tipp für dich." },
    },
    COOLTRAINER = {
      { "Here is a useful scouting report.", "Ein nützlicher Erkundungsbericht." },
      { "A good trainer shares good information.", "Gute Trainer teilen gute Informationen." },
      { "I checked the location myself.", "Ich war selbst an diesem Ort." },
      { "Add this stop to your route.", "Plane diesen Halt auf deiner Route ein." },
      { "Something for your next field trip.", "Ein Tipp für deinen nächsten Ausflug." },
      { "I found a promising lead.", "Ich habe eine gute Entdeckung gemacht." },
    },
    JR_TRAINER = {
      { "I learned something on my trip!", "Ich habe unterwegs etwas gelernt!" },
      { "My notes are finally useful!", "Endlich helfen meine Notizen!" },
      { "Here is my latest discovery.", "Hier ist meine neueste Entdeckung." },
      { "I took a good look to be sure.", "Ich habe zur Sicherheit genau hingesehen." },
      { "We can help each other explore.", "Wir können uns beim Erkunden helfen." },
      { "I was proud of this find!", "Auf diesen Fund war ich stolz!" },
    },
    RIVAL = {
      { "Try keeping up with my discoveries!", "Halt mit meinen Entdeckungen Schritt!" },
      { "I found something you might have missed.", "Das hast du vielleicht noch übersehen." },
      { "Here, one tip. Make it count.", "Hier, ein Tipp. Mach etwas daraus." },
      { "I already checked this place out.", "Diesen Ort habe ich schon erkundet." },
      { "Let us see if you can find it too.", "Mal sehen, ob du es auch findest." },
      { "Even a rival can share a good lead.", "Auch ein Rivale kann einen Tipp teilen." },
    },
    BOSS = {
      { "Your journey still has surprises.", "Deine Reise hält noch Überraschungen bereit." },
      { "Experience means knowing where to look.", "Erfahrung heißt auch, gute Fundorte zu kennen." },
      { "I made a useful discovery on my travels.", "Ich machte unterwegs eine nützliche Entdeckung." },
      { "Take this as a tip from a fellow trainer.", "Ein Tipp von Trainer zu Trainer." },
      { "Strength is not all there is to training.", "Zum Training gehört mehr als Stärke." },
      { "Keep exploring beyond our battle.", "Erkunde weiter, auch nach unserem Kampf." },
    },
  }
  local aliases = {
    COOLTRAINER_M="COOLTRAINER", COOLTRAINER_F="COOLTRAINER",
    JR_TRAINER_M="JR_TRAINER", JR_TRAINER_F="JR_TRAINER",
    JUGGLER_X="JUGGLER", UNUSED_JUGGLER="JUGGLER",
    RIVAL1="RIVAL", RIVAL2="RIVAL", RIVAL3="RIVAL",
    BROCK="HIKER", MISTY="SWIMMER", LT_SURGE="ENGINEER",
    ERIKA="BEAUTY", KOGA="TAMER", SABRINA="PSYCHIC_TR",
    BLAINE="SCIENTIST", GIOVANNI="BOSS", LORELEI="BOSS",
    BRUNO="BLACKBELT", AGATHA="CHANNELER", LANCE="BOSS",
    PROF_OAK="SCIENTIST", CHIEF="BOSS", UNUSED="DEFAULT",
  }
  local findings = {
    { "I encountered %s!\fThe exact location:\n%s", "Ich bin %s begegnet!\fDer genaue Fundort:\n%s" },
    { "I spotted %s!\fI saw it at:\n%s", "Ich habe %s gesehen!\fUnd zwar an diesem Ort:\n%s" },
    { "I met %s on my travels.\fMake a note of the place:\n%s", "Unterwegs traf ich %s.\fMerk dir den Fundort:\n%s" },
    { "I stopped to watch %s.\fHere is where I saw it:\n%s", "Ich beobachtete %s.\fDort habe ich es gesehen:\n%s" },
    { "My latest sighting: %s.\fThe location was:\n%s", "Meine letzte Sichtung: %s.\fDas war an diesem Ort:\n%s" },
    { "Want to meet %s?\fI encountered it at:\n%s", "Du möchtest %s treffen?\fIch bin ihm dort begegnet:\n%s" },
  }
  local previousVariants = {}
  local function dialogueChoice(battle)
    local class = battle and (battle.oppClass or battle.trainer and battle.trainer.class) or ""
    class = tostring(class):gsub("^OPP_", "")
    local style = aliases[class] or class
    if not voices[style] then style = "DEFAULT" end
    local token = tostring(battle and battle.ascendantLegacyToken or "")
      .. ":" .. class .. ":" .. trainerName(battle)
    local hash = 0
    for i = 1, #token do hash = (hash * 33 + token:byte(i)) % 2147483647 end
    local index = hash % 6 + 1
    if previousVariants[class] == index then index = index % 6 + 1 end
    return class, style, index
  end
  P.dialogueChoice = dialogueChoice
  P.dialogueVoices = voices

  function P.announcement(battle, result)
    local game = battle and battle.game or activeGame
    local species = result and result.family
    if type(species) ~= "string" or species == "" then return nil end
    local name = speciesName(game, species)
    local habitat = type(result.habitat) == "table" and result.habitat or {}
    local target = result.mapId or habitat.map
    if type(target) ~= "string" or target == "" then return nil end
    local authored = target == habitat.map
    local map = game and game.data and game.data.maps and game.data.maps[target]
    local fallback = target:gsub("_", " ")
    local location = authored and tr(habitat.en or fallback, habitat.de or fallback)
      or type(map) == "table" and type(map.name) == "string" and map.name or fallback
    -- A relocated old trace has no saved terrain; do not claim grass/cave.
    local terrain = authored and habitat.terrain or nil
    local search = terrain == "grass" and tr("Search the grass there.", "Such dort im Gras.")
      or (terrain == "indoor" or terrain == "cave")
        and tr("Explore inside there.", "Suche dort im Inneren.")
      or tr("Search for wild Pokemon there.", "Suche dort wilde Pokémon.")
    local class, style, index = dialogueChoice(battle)
    local voice = voices[style][index]
    local finding = findings[index]
    local text = trainerName(battle) .. ": " .. tr(voice[1], voice[2]) .. "\f"
      .. tr(finding[1], finding[2]):format(name, location) .. "\f"
      .. search .. "\f" .. tr("Within 1-50 wild\nencounters there!",
        "Dort triffst du es in\n1-50 wilden Begegnungen!")
    return text, class, index
  end

  function P.captureAnnouncement(ev)
    local battle = ev and ev.battle
    local result = battle and battle.kaHoennIntroductionResult
    if not (enabled() and ev and ev.result == "win"
        and battle and battle.ascendantLegacyWanderer == true
        and type(result) == "table" and result.introduced == true) then
      return false
    end
    local text, class, variant = P.announcement(battle, result)
    if not text then return false end
    previousVariants[class] = variant
    P.pending = {
      game = battle.game or activeGame,
      token = battle.ascendantLegacyToken,
      text = text,
    }
    return P.pending.text ~= nil
  end

  function P.showPending(ev)
    local pending = P.pending
    local game = ev and ev.game or pending and pending.game or activeGame
    if not (pending and game and game.stack and game.overworld
        and type(game.stack.top) == "function"
        and game.stack:top() == game.overworld
        and type(game.stack.push) == "function") then return false end
    P.pending = nil
    local TextBox = opts.textBox or require("src.render.TextBox")
    game.stack:push(TextBox.new(game, pending.text))
    return true
  end

  function P.beginTraceMusic(ev)
    local battle = ev and ev.battle
    if not (enabled() and battle and battle.kind == "wild"
        and battle.kaHoennDiscoveryMode == "trace") then return false end
    local musicId = opts.musicId or "Music_KA_HoennTrace67"
    local Music = opts.music or require("src.core.Music")
    Music.play(battle.data or battle.game and battle.game.data,
      musicId, true, { reason="hoenn-trace", kind="wild",
        species=battle.kaHoennDiscoverySpecies })
    battle.kaHoennTraceMusic = musicId
    return true
  end

  function P.reset(ev)
    activeGame = ev and ev.game or activeGame
    P.pending = nil
    previousVariants = {}
  end

  P.enabled = enabled
  mod.events:on("battle.started", P.beginTraceMusic, P.PRIORITY)
  mod.events:on("battle.ended", P.captureAnnouncement, P.PRIORITY)
  mod.events:on("world.stepped", P.showPending, P.PRIORITY)
  mod.events:on("save.created", P.reset, 900)
  mod.events:on("save.loaded", P.reset, 900)
  mod.events:on("game.ready", function(ev)
    activeGame = ev and ev.game or activeGame
  end, 900)
  return P
end
