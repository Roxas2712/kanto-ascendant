-- kasc.rival.interaction-dialogue/v1 -- Red voice pack

local VOICE = "TERSE_OBSERVANT_ACTION"
local phases = {
  "ARRIVAL", "FIRST_TALK", "REPEAT_TALK", "INTERRUPTED",
  "PRE_CHALLENGE", "POST_WIN", "POST_LOSS", "POST_ABORT", "FAREWELL",
}
local rows, strings = {}, { en = {}, de = {} }

local function addScene(agendaId, slug, copy)
  for _, phase in ipairs(phases) do
    local pair = assert(copy[phase], agendaId .. " missing " .. phase)
    for variant = 1, 2 do
      local suffix = variant == 1 and "a" or "b"
      local id = "red." .. slug .. "." .. phase:lower() .. "." .. suffix
      local base = "life_of_rival.red." .. slug .. "."
        .. phase:lower() .. "." .. suffix
      local enKey, deKey = base .. ".en", base .. ".de"
      strings.en[enKey], strings.de[deKey] = pair[variant].en, pair[variant].de
      rows[#rows + 1] = {
        id=id, actor="RED", voice=VOICE, agendaId=agendaId, phase=phase,
        localeKeys={ en=enKey, de=deKey }, placeholders={},
        antiRepeat={ scope="ACTOR_AGENDA_PHASE", historySize=4,
          fallbackId="red." .. slug .. "." .. phase:lower() .. "."
            .. (variant == 1 and "b" or "a") },
      }
    end
  end
end

addScene("ROUTE_1_TEAM_DRILL_RED", "route1_drill", {
  ARRIVAL={
    {en="The road is clear. One more turn.", de="Die Strecke ist frei. Noch eine Wende."},
    {en="Enough room ahead. We try it again.", de="Da vorne ist genug Platz. Wir versuchen es noch einmal."},
  },
  FIRST_TALK={
    {en="My partner loses speed in the turn. We are working on it.", de="Mein Partner verliert in der Kurve Tempo. Daran arbeiten wir."},
    {en="The turn is not clean yet. Then we move on.", de="Die Wende sitzt noch nicht. Danach ziehen wir weiter."},
  },
  REPEAT_TALK={
    {en="Two more tries. Then north.", de="Noch zwei Versuche. Dann geht es nach Norden."},
    {en="Almost clean. One more.", de="Fast sauber. Einer noch."},
  },
  INTERRUPTED={
    {en="One moment. We finish this run.", de="Einen Moment. Wir beenden nur diesen Lauf."},
    {en="Right after the marker.", de="Gleich. Noch bis zur Markierung."},
  },
  PRE_CHALLENGE={
    {en="A short battle? I want to see if the practice holds.", de="Ein kurzer Kampf? Ich will sehen, ob die Übung sitzt."},
    {en="Test the turn with us. One battle.", de="Kämpf kurz mit uns. Dann sehen wir, ob die Wende sitzt."},
  },
  POST_WIN={
    {en="Good. You saw the open side at once.", de="Gut. Du hast die offene Seite sofort gesehen."},
    {en="You read the turn better. We adjust.", de="Du hast die Kurve besser gelesen. Wir stellen uns darauf ein."},
  },
  POST_LOSS={
    {en="Close. Next time you will not leave that gap.", de="Knapp. Beim nächsten Mal lässt du mir diese Lücke nicht."},
    {en="The practice held. Your answer nearly did too.", de="Das Training hat sich ausgezahlt. Du warst trotzdem fast dran."},
  },
  POST_ABORT={
    {en="Not here. The road is too busy.", de="Nicht hier. Auf der Strecke ist zu viel los."},
    {en="We stop. No reason to force it.", de="Wir hören auf. Erzwingen bringt nichts."},
  },
  FAREWELL={
    {en="We take the north road. See you.", de="Wir nehmen den Nordweg. Bis später."},
    {en="The turn can wait. We should move.", de="Die Wende kann warten. Wir müssen weiter."},
  },
})

addScene("ROUTE_2_ENDURANCE_RED", "route2_endurance", {
  ARRIVAL={
    {en="Last stretch. Keep the pace.", de="Letztes Stück. Halt das Tempo."},
    {en="To the sign, then we rest.", de="Bis zum Schild. Dann machen wir Pause."},
  },
  FIRST_TALK={
    {en="We ran the whole route. My team still has energy.", de="Wir sind die ganze Route gelaufen. Mein Team hat noch Kraft."},
    {en="Endurance first, speed second. Today that worked.", de="Erst Ausdauer, dann Tempo. Heute hat das funktioniert."},
  },
  REPEAT_TALK={
    {en="Breathing is steady. We can continue.", de="Wir sind wieder bei Atem. Es kann weitergehen."},
    {en="A short rest. Nothing more.", de="Eine kurze Pause. Mehr nicht."},
  },
  INTERRUPTED={
    {en="Let us finish the stretch.", de="Lass uns das Stück noch beenden."},
    {en="At the sign. Then I have time.", de="Bis zum Schild. Dann habe ich Zeit."},
  },
  PRE_CHALLENGE={
    {en="One measured battle. No prize, just practice.", de="Ein Trainingskampf? Es geht nur um die Übung."},
    {en="We still have strength for a battle. You too?", de="Für einen Kampf reicht die Kraft noch. Bei dir auch?"},
  },
  POST_WIN={
    {en="You kept your pace to the end. Good.", de="Du hast dein Tempo bis zum Schluss gehalten. Gut."},
    {en="You were patient. That decided it.", de="Du bist ruhig geblieben. Das hat entschieden."},
  },
  POST_LOSS={
    {en="You started too fast. Save something for the finish.", de="Du bist zu schnell gestartet. Heb dir etwas für den Schluss auf."},
    {en="Your team tired first. It will learn.", de="Dein Team wurde zuerst müde. Das wird sich ändern."},
  },
  POST_ABORT={
    {en="We stop for today. The team comes first.", de="Für heute ist Schluss. Das Team geht vor."},
    {en="No battle while someone needs rest.", de="Kein Kampf, solange jemand eine Pause braucht."},
  },
  FAREWELL={
    {en="We cool down on the way north.", de="Wir gehen langsam nach Norden weiter."},
    {en="Enough for today. See you on the next route.", de="Für heute reicht es. Bis zur nächsten Route."},
  },
})

addScene("ROUTE_5_PATH_RED", "route5_path", {
  ARRIVAL={
    {en="This path looks shorter. I will time it.", de="Der Weg sieht kürzer aus. Ich stoppe die Zeit."},
    {en="Two paths. We check both.", de="Zwei Wege. Wir prüfen beide."},
  },
  FIRST_TALK={
    {en="The shortcut costs too many turns. The open path is faster.", de="Die Abkürzung hat zu viele Kurven. Der offene Weg ist schneller."},
    {en="Shorter is not always faster. My team noticed first.", de="Kürzer heißt nicht immer schneller. Mein Team hat es zuerst gemerkt."},
  },
  REPEAT_TALK={
    {en="The open path wins by twelve seconds.", de="Der offene Weg ist zwölf Sekunden schneller."},
    {en="The result is clear. We take the wide path.", de="Das Ergebnis ist klar. Wir nehmen den breiten Weg."},
  },
  INTERRUPTED={
    {en="Wait at the line. I need one clean time.", de="Warte an der Linie. Mir fehlt noch eine saubere Zeit."},
    {en="One moment. The clock is running.", de="Einen Moment. Die Zeit läuft noch."},
  },
  PRE_CHALLENGE={
    {en="Want to test the faster path in a battle?", de="Willst du den schnelleren Weg im Kampf testen?"},
    {en="One battle. Position matters here.", de="Ein Kampf. Hier kommt es auf die Position an."},
  },
  POST_WIN={
    {en="You took the direct line. I should have expected that.", de="Du hast den direkten Weg genommen. Damit hätte ich rechnen müssen."},
    {en="You gave me no room to adjust. Well done.", de="Du hast mir keine Zeit zum Umstellen gelassen. Gut gemacht."},
  },
  POST_LOSS={
    {en="You hesitated at the turn. That was enough.", de="Du hast an der Wende gezögert. Das hat gereicht."},
    {en="The longer route gave me space. Remember that.", de="Der längere Weg gab mir Platz. Merk dir das."},
  },
  POST_ABORT={
    {en="The route changed. We leave the comparison for later.", de="Die Strecke hat sich geändert. Den Vergleich holen wir nach."},
    {en="No clean result today. That happens.", de="Heute gibt es kein sauberes Ergebnis. Kommt vor."},
  },
  FAREWELL={
    {en="We take the wide path. It is faster.", de="Wir nehmen den breiten Weg. Der ist schneller."},
    {en="The clock has its answer. We move on.", de="Die Stoppuhr hat entschieden. Wir gehen weiter."},
  },
})

addScene("ROUTE_12_REST_RED", "route12_rest", {
  ARRIVAL={
    {en="Quiet. They finally fell asleep.", de="Leise. Sie sind gerade eingeschlafen."},
    {en="This spot is calm. We rest here.", de="Hier ist es ruhig. Wir machen hier Pause."},
  },
  FIRST_TALK={
    {en="They worked hard. I will watch the road until they wake.", de="Sie haben hart gearbeitet. Ich passe auf, bis sie wieder wach sind."},
    {en="The team needs rest. The road can wait.", de="Das Team braucht eine Pause. Der Weg kann warten."},
  },
  REPEAT_TALK={
    {en="Still asleep. Give them a minute.", de="Sie schlafen noch. Gib ihnen einen Moment."},
    {en="Almost ready. I am not waking them early.", de="Gleich sind sie so weit. Ich wecke sie nicht früher."},
  },
  INTERRUPTED={
    {en="Keep your voice down, please.", de="Sprich bitte etwas leiser."},
    {en="One moment. I am checking on them.", de="Einen Moment. Ich sehe nur kurz nach ihnen."},
  },
  PRE_CHALLENGE={
    {en="They are awake. A calm battle, if you want.", de="Sie sind wach. Wenn du willst, kämpfen wir eine ruhige Runde."},
    {en="The rest helped. Shall we test it?", de="Die Pause hat geholfen. Wollen wir es ausprobieren?"},
  },
  POST_WIN={
    {en="You gave your team time too. It showed.", de="Du hast deinem Team auch Zeit gelassen. Das hat man gemerkt."},
    {en="Good timing. You attacked only when it mattered.", de="Gutes Timing. Du hast nur angegriffen, wenn es nötig war."},
  },
  POST_LOSS={
    {en="Rest changed the battle. Do not overlook it.", de="Die Pause hat den Kampf entschieden. Unterschätz das nicht."},
    {en="Your team needs a break now. Give it one.", de="Jetzt braucht dein Team eine Pause. Gönn sie ihm."},
  },
  POST_ABORT={
    {en="No battle. Someone is not ready yet.", de="Kein Kampf. Einer von uns ist noch nicht so weit."},
    {en="We wait. The team decides the pace.", de="Wir warten. Das Team bestimmt das Tempo."},
  },
  FAREWELL={
    {en="Everyone is ready. We are moving on.", de="Alle sind wieder fit. Wir ziehen weiter."},
    {en="The break is over. See you farther down the road.", de="Die Pause ist vorbei. Wir sehen uns unterwegs."},
  },
})

addScene("ROUTE_15_REMATCH_RED", "route15_rematch", {
  ARRIVAL={
    {en="Same opening. A different answer this time.", de="Gleicher Auftakt. Diesmal reagieren wir anders."},
    {en="Again. We react one turn earlier.", de="Noch einmal. Wir reagieren einen Zug früher."},
  },
  FIRST_TALK={
    {en="Three rematches, three openings. We are preparing for all of them.", de="Drei Revanchen, drei verschiedene Eröffnungen. Auf jede bereiten wir uns vor."},
    {en="My team recognizes the first move now. The rest is mine.", de="Mein Team erkennt den ersten Zug inzwischen. Den Rest übernehme ich."},
  },
  REPEAT_TALK={
    {en="The fourth opening still needs work.", de="An der vierten Eröffnung müssen wir noch arbeiten."},
    {en="We are changing only one thing at a time.", de="Wir ändern immer nur eine Sache auf einmal."},
  },
  INTERRUPTED={
    {en="After this sequence.", de="Gleich, nach dieser Runde."},
    {en="Give us one more turn.", de="Gib uns noch einen Zug."},
  },
  PRE_CHALLENGE={
    {en="Show us an opening we have not seen.", de="Zeig uns eine Eröffnung, die wir noch nicht kennen."},
    {en="A rematch without the old pattern. Ready?", de="Ein Rückkampf ohne das alte Muster. Bereit?"},
  },
  POST_WIN={
    {en="That opening was new. We learned something.", de="Diese Eröffnung war neu. Wir haben etwas gelernt."},
    {en="You changed the pattern at the right moment.", de="Du hast das Muster im richtigen Moment gebrochen."},
  },
  POST_LOSS={
    {en="I recognized your opening. Change it next time.", de="Deine Eröffnung kannte ich schon. Probier beim nächsten Mal etwas anderes."},
    {en="You repeated one move too soon.", de="Du hast einen Zug zu früh wiederholt."},
  },
  POST_ABORT={
    {en="We lost the rhythm. We start fresh later.", de="Der Rhythmus ist weg. Später fangen wir neu an."},
    {en="No useful test this time.", de="Diesmal wäre der Test nicht aussagekräftig."},
  },
  FAREWELL={
    {en="We have enough to practice. See you.", de="Wir haben genug zum Üben. Bis später."},
    {en="Next time, bring another opening.", de="Bring beim nächsten Mal eine andere Eröffnung mit."},
  },
})

addScene("ROUTE_22_LEAGUE_PAIR", "route22_pair", {
  ARRIVAL={
    {en="BLUE is already here. Good.", de="BLAU ist schon da. Gut."},
    {en="The League road is clear. We can begin.", de="Der Weg zur Liga ist frei. Wir können anfangen."},
  },
  FIRST_TALK={
    {en="We are comparing League plans. BLUE talks more. I take notes.", de="Wir vergleichen unsere Pläne für die Liga. BLAU redet mehr. Ich mache mir Notizen."},
    {en="Two plans, one road. We will see which one holds.", de="Zwei Pläne, ein Weg. Wir werden sehen, welcher funktioniert."},
  },
  REPEAT_TALK={
    {en="His plan is fast. Mine leaves fewer gaps.", de="Sein Plan ist schnell. Meiner lässt weniger Lücken."},
    {en="We are not finished comparing them.", de="Mit dem Vergleich sind wir noch nicht fertig."},
  },
  INTERRUPTED={
    {en="A moment. BLUE is making his point.", de="Einen Moment. BLAU will gerade etwas beweisen."},
    {en="Let him finish. It will not take long.", de="Lass ihn ausreden. Das dauert nicht lange."},
  },
  PRE_CHALLENGE={
    {en="Join the test. Your approach will settle it.", de="Mach beim Test mit. Dein Kampfstil wird zeigen, wer recht hat."},
    {en="One battle. Then we compare all three plans.", de="Ein Kampf. Danach vergleichen wir alle drei Pläne."},
  },
  POST_WIN={
    {en="Your plan held. I missed one option.", de="Dein Plan hat funktioniert. Eine Möglichkeit hatte ich übersehen."},
    {en="You forced both of us to adjust.", de="Du hast uns beide zum Umdenken gebracht."},
  },
  POST_LOSS={
    {en="You were close. BLUE will mention the rest.", de="Du warst nah dran. Den Rest wird BLAU dir bestimmt erzählen."},
    {en="Your plan needs one more answer near the end.", de="Fürs Ende brauchst du noch einen besseren Plan."},
  },
  POST_ABORT={
    {en="We stop here. The League road must stay clear.", de="Wir hören hier auf. Der Weg zur Liga muss frei bleiben."},
    {en="Not today. We can compare plans elsewhere.", de="Nicht heute. Wir können die Pläne auch woanders vergleichen."},
  },
  FAREWELL={
    {en="We take separate routes from here.", de="Ab hier gehen wir getrennte Wege."},
    {en="The next result will answer the rest.", de="Beim nächsten Kampf klärt sich der Rest."},
  },
})

return {
  actor="RED", voice=VOICE, rows=rows,
  lookup=function(locale, key)
    local bucket = strings[locale == "de" and "de" or "en"]
    return bucket[key]
  end,
  strings=strings,
}
