-- kasc.rival.interaction-dialogue/v1 -- Blue voice pack

local VOICE = "CONFIDENT_COMPETITIVE_POINTED"
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
      local id = "blue." .. slug .. "." .. phase:lower() .. "." .. suffix
      local base = "life_of_rival.blue." .. slug .. "."
        .. phase:lower() .. "." .. suffix
      local enKey, deKey = base .. ".en", base .. ".de"
      strings.en[enKey], strings.de[deKey] = pair[variant].en, pair[variant].de
      rows[#rows + 1] = {
        id=id, actor="BLUE", voice=VOICE, agendaId=agendaId, phase=phase,
        localeKeys={ en=enKey, de=deKey }, placeholders={},
        antiRepeat={ scope="ACTOR_AGENDA_PHASE", historySize=4,
          fallbackId="blue." .. slug .. "." .. phase:lower() .. "."
            .. (variant == 1 and "b" or "a") },
      }
    end
  end
end

addScene("VIRIDIAN_SUPPLIES_BLUE", "viridian_supplies", {
  ARRIVAL={
    {en="Potions, Balls, map. Done.", de="Tränke, Bälle, Karte. Alles da."},
    {en="One stop, everything packed. That is how you travel.", de="Ein Stopp, und alles ist eingepackt. So plant man eine Reise."},
  },
  FIRST_TALK={
    {en="I packed for the next three towns. You are still checking one pocket.", de="Ich habe für die nächsten drei Städte gepackt. Du kramst immer noch in derselben Tasche."},
    {en="Good preparation wins time before the first battle starts.", de="Gute Vorbereitung spart Zeit, bevor der erste Kampf überhaupt beginnt."},
  },
  REPEAT_TALK={
    {en="Yes, I checked twice. That is why nothing is missing.", de="Ja, ich habe zweimal nachgesehen. Deshalb fehlt auch nichts."},
    {en="The bag is ready. I am waiting on you now.", de="Meine Tasche ist fertig. Jetzt warte ich auf dich."},
  },
  INTERRUPTED={
    {en="Hold on. I am counting the Full Heals.", de="Warte kurz. Ich zähle gerade die Top-Genesungen."},
    {en="One second. Losing track now would be embarrassing.", de="Eine Sekunde. Jetzt durcheinanderzukommen wäre peinlich."},
  },
  PRE_CHALLENGE={
    {en="Packed already? Prove it in a quick battle.", de="Schon fertig gepackt? Dann zeig es in einem kurzen Kampf."},
    {en="Let us see whether your planning survives first contact.", de="Mal sehen, ob dein Plan den ersten Zug übersteht."},
  },
  POST_WIN={
    {en="All right. You came prepared after all.", de="Na gut. Du warst doch vorbereitet."},
    {en="You had the right answer ready. I did not expect that one.", de="Du hattest die richtige Antwort parat. Mit der habe ich nicht gerechnet."},
  },
  POST_LOSS={
    {en="That is what preparation looks like. Remember it.", de="So sieht Vorbereitung aus. Merk dir das."},
    {en="You were searching for answers I had already packed.", de="Du hast nach Antworten gesucht, die ich längst dabeihatte."},
  },
  POST_ABORT={
    {en="Forget the battle. I am not unpacking everything again.", de="Lass den Kampf. Ich packe nicht noch einmal alles aus."},
    {en="Bad timing. We settle this outside town.", de="Schlechtes Timing. Das klären wir außerhalb der Stadt."},
  },
  FAREWELL={
    {en="I am ready. Try to catch up before Pewter.", de="Ich bin fertig. Hol mich vor Marmoria ein."},
    {en="Next stop, Pewter. Do not take all day.", de="Nächster Halt: Marmoria. Lass dir nicht den ganzen Tag Zeit."},
  },
})

addScene("PEWTER_MUSEUM_BLUE", "pewter_museum", {
  ARRIVAL={
    {en="The museum closes soon. Plenty of time.", de="Das Museum schließt bald. Reicht völlig."},
    {en="Fossils first. The Gym can wait ten minutes.", de="Erst die Fossilien. Die Arena kann zehn Minuten warten."},
  },
  FIRST_TALK={
    {en="Two exhibits contradict each other. I am checking which label is old.", de="Zwei Tafeln widersprechen sich. Ich prüfe gerade, welche veraltet ist."},
    {en="The claw marks fit the smaller fossil. The display is wrong.", de="Die Kratzspuren passen zum kleineren Fossil. Die Vitrine ist falsch beschriftet."},
  },
  REPEAT_TALK={
    {en="I was right. The curator found the old catalog.", de="Ich hatte recht. Der Kurator hat den alten Katalog gefunden."},
    {en="Mystery solved. Faster than their filing system.", de="Fall geklärt. Schneller als deren Ablage."},
  },
  INTERRUPTED={
    {en="Wait. I almost have the date.", de="Warte. Mir fehlt nur noch das Datum."},
    {en="One minute. This label will not win.", de="Eine Minute. Ich finde schon heraus, was auf diesem Schild nicht stimmt."},
  },
  PRE_CHALLENGE={
    {en="Research done. Now for something less dusty.", de="Damit wäre das geklärt. Jetzt etwas mit weniger Staub."},
    {en="Want a battle before the Gym? Call it a practical test.", de="Ein Kampf vor der Arena? Nennen wir es einen Praxistest."},
  },
  POST_WIN={
    {en="You found the flaw in my plan. Fair result.", de="Du hast die Schwachstelle in meinem Plan gefunden. Verdient gewonnen."},
    {en="Good catch. I will correct that before the next battle.", de="Gut erkannt. Bis zum nächsten Kampf korrigiere ich das."},
  },
  POST_LOSS={
    {en="I checked the facts. You should have checked my lead.", de="Ich habe die Fakten geprüft. Du hättest mein erstes Pokémon prüfen sollen."},
    {en="Wrong assumption at the start. The rest followed.", de="Am Anfang lagst du falsch. Danach war der Kampf entschieden."},
  },
  POST_ABORT={
    {en="The museum staff needs this space. We move.", de="Das Museumspersonal braucht den Platz. Wir gehen."},
    {en="No battle between the exhibits. Sensible rule, unfortunately.", de="Kein Kampf zwischen den Vitrinen. Leider eine vernünftige Regel."},
  },
  FAREWELL={
    {en="I have my answer. The Gym is next.", de="Ich habe meine Antwort. Als Nächstes kommt die Arena."},
    {en="Tell the curator the left label is wrong. I already did.", de="Sag dem Kurator, dass die linke Tafel falsch ist. Ich habe es schon getan."},
  },
})

addScene("VERMILION_HARBOR_BLUE", "vermilion_harbor", {
  ARRIVAL={
    {en="Ship delayed. Fine. We train here.", de="Das Schiff verspätet sich. Gut, dann trainieren wir hier."},
    {en="If the ship waits, it can watch us practice.", de="Wenn das Schiff warten lässt, kann es uns beim Training zusehen."},
  },
  FIRST_TALK={
    {en="The stones are uneven. Perfect for balance training.", de="Die Steine sind uneben. Perfekt fürs Gleichgewichtstraining."},
    {en="Ten minutes late, ten minutes of practice. Nothing wasted.", de="Zehn Minuten Verspätung, zehn Minuten Training. Keine Zeit verloren."},
  },
  REPEAT_TALK={
    {en="Still late. We are already better.", de="Immer noch verspätet. Wenigstens hat sich unser Training schon gelohnt."},
    {en="The harbor is useful once you stop complaining about it.", de="Der Hafen ist ziemlich nützlich, wenn man aufhört, sich zu beschweren."},
  },
  INTERRUPTED={
    {en="Watch the edge. Then talk.", de="Achte auf die Kante. Dann reden wir."},
    {en="One more step. I am not fishing my partner out of the water.", de="Noch ein Durchgang. Meinen Partner fische ich jedenfalls nicht aus dem Wasser."},
  },
  PRE_CHALLENGE={
    {en="The ship is not here. You are. Battle?", de="Das Schiff ist nicht da. Du schon. Kämpfen wir?"},
    {en="Let us test that balance before boarding.", de="Testen wir das Gleichgewicht, bevor es an Bord geht."},
  },
  POST_WIN={
    {en="You used the uneven ground better. Nice work.", de="Du hast den unebenen Boden besser genutzt. Nicht schlecht."},
    {en="You adjusted faster than I did. This time.", de="Du hast dich schneller angepasst als ich. Diesmal."},
  },
  POST_LOSS={
    {en="Steady feet, steady plan. You lost both first.", de="Sicherer Stand, klarer Plan. Beides hat dir gefehlt."},
    {en="You watched the water instead of the battle.", de="Du hast mehr aufs Wasser geachtet als auf den Kampf."},
  },
  POST_ABORT={
    {en="The ship is boarding. Our timing is terrible.", de="Das Schiff wird beladen. Unser Timing ist miserabel."},
    {en="We stop. Missing the ship would be ridiculous.", de="Wir hören auf. Das Schiff zu verpassen wäre lächerlich."},
  },
  FAREWELL={
    {en="There is the signal. Try not to miss your ride.", de="Da ist das Signal. Verpass deine Fahrt nicht."},
    {en="Training over. Time to board.", de="Training beendet. Zeit, an Bord zu gehen."},
  },
})

addScene("FUCHSIA_TRACKS_BLUE", "fuchsia_tracks", {
  ARRIVAL={
    {en="Fresh tracks. Finally, something useful.", de="Frische Spuren. Endlich etwas Brauchbares."},
    {en="They turn east. I knew this was the right spot.", de="Sie führen nach Osten. Ich wusste, dass wir hier richtig sind."},
  },
  FIRST_TALK={
    {en="Three species crossed here. The smallest one doubled back.", de="Drei Arten sind hier vorbeigekommen. Die kleinste ist umgekehrt."},
    {en="The broken grass points east. The footprints are a distraction.", de="Das geknickte Gras zeigt nach Osten. Die Fußspuren führen absichtlich in die falsche Richtung."},
  },
  REPEAT_TALK={
    {en="Yes, east. I checked the wind too.", de="Ja, nach Osten. Den Wind habe ich auch geprüft."},
    {en="The trail is clear once you ignore the obvious clue.", de="Die Spur ist eindeutig, wenn man den auffälligen Hinweis ignoriert."},
  },
  INTERRUPTED={
    {en="Do not step there. That print is intact.", de="Tritt nicht dahin. Der Abdruck ist noch unberührt."},
    {en="Hold it. I need one measurement.", de="Warte kurz. Ich muss das noch ausmessen."},
  },
  PRE_CHALLENGE={
    {en="We found the trail. Now show me whether you can follow a battle.", de="Wir haben die Spur. Jetzt zeig, ob du auch einem Kampf folgen kannst."},
    {en="Quick battle before we follow it east?", de="Ein kurzer Kampf, bevor wir der Spur nach Osten folgen?"},
  },
  POST_WIN={
    {en="You changed direction without warning. Good instinct.", de="Du hast ohne Vorwarnung die Richtung gewechselt. Gutes Gespür."},
    {en="You hid your real plan well. I respect that.", de="Du hast deinen eigentlichen Plan gut verborgen. Respekt."},
  },
  POST_LOSS={
    {en="Your plan left tracks everywhere. Easy to follow.", de="Dein Plan hat überall Spuren hinterlassen. Leicht zu lesen."},
    {en="I knew your next move before you chose it.", de="Ich kannte deinen nächsten Zug, bevor du ihn gewählt hast."},
  },
  POST_ABORT={
    {en="The trail is moving. Battle later.", de="Die Pokémon ziehen weiter. Wir kämpfen später."},
    {en="We are losing daylight. I am not losing the trail too.", de="Uns läuft das Licht davon. Die Spur verliere ich nicht auch noch."},
  },
  FAREWELL={
    {en="East, then south. Keep up if you can.", de="Nach Osten, dann nach Süden. Komm mit, wenn du mithalten kannst."},
    {en="I have the route. See you at the end of it.", de="Ich kenne den Weg. Wir sehen uns am Ende der Spur."},
  },
})

addScene("CINNABAR_HEAT_BLUE", "cinnabar_heat", {
  ARRIVAL={
    {en="Hotter than yesterday. Good test.", de="Heißer als gestern. Ein guter Test."},
    {en="Short rounds today. Same standard.", de="Heute kurze Einheiten. Der Anspruch bleibt."},
  },
  FIRST_TALK={
    {en="The heat slows every decision. We are learning to notice it early.", de="In der Hitze reagiert man langsamer. Wir lernen, es rechtzeitig zu merken."},
    {en="We cut the drills in half, not the effort.", de="Wir haben die Trainingsrunden verkürzt, nicht den Einsatz."},
  },
  REPEAT_TALK={
    {en="Water first. Then the next round.", de="Erst Wasser. Dann die nächste Runde."},
    {en="The pace is right now. No reason to overdo it.", de="Das Tempo stimmt jetzt. Wir müssen es nicht übertreiben."},
  },
  INTERRUPTED={
    {en="Give us a second. Shade first.", de="Einen Moment. Wir gehen erst in den Schatten."},
    {en="Wait. My partner needs water.", de="Warte. Mein Partner braucht Wasser."},
  },
  PRE_CHALLENGE={
    {en="One short battle. If either team slows, we stop.", de="Ein kurzer Kampf. Sobald ein Team langsamer wird, hören wir auf."},
    {en="Think you can keep a clear head in this heat?", de="Behältst du bei der Hitze einen klaren Kopf?"},
  },
  POST_WIN={
    {en="You stayed calm longer. That was the difference.", de="Du bist länger ruhig geblieben. Das war der Unterschied."},
    {en="Good pacing. You did not waste a move.", de="Gutes Tempo. Du hast keinen Zug verschwendet."},
  },
  POST_LOSS={
    {en="You rushed when the heat got to you.", de="Als dir die Hitze zugesetzt hat, wurdest du hektisch."},
    {en="You spent your strength too early.", de="Du hast deine Kraft zu früh verbraucht."},
  },
  POST_ABORT={
    {en="That is enough. We cool down now.", de="Das reicht. Wir kühlen uns jetzt ab."},
    {en="No result is worth overheating for.", de="Kein Training ist einen Hitzschlag wert."},
  },
  FAREWELL={
    {en="We are heading to the water. You should too.", de="Wir gehen ans Wasser. Das solltest du auch."},
    {en="Practice over. The island wins this round.", de="Training beendet. Diese Runde geht an die Insel."},
  },
})

addScene("ROUTE_22_LEAGUE_PAIR", "route22_pair", {
  ARRIVAL={
    {en="RED is early. I am exactly on time.", de="ROT ist zu früh. Ich bin genau pünktlich."},
    {en="Good, you are both here. Now this gets useful.", de="Gut, ihr seid beide da. Jetzt wird es interessant."},
  },
  FIRST_TALK={
    {en="RED wants fewer risks. I want a plan that actually wins fast.", de="ROT will weniger Risiko. Ich will einen Plan, der schnell gewinnt."},
    {en="We are comparing League plans. Mine is faster. His is annoyingly solid.", de="Wir vergleichen Pläne für die Liga. Meiner ist schneller. Seiner ist leider ziemlich solide."},
  },
  REPEAT_TALK={
    {en="He still calls it patience. I call it giving up momentum.", de="Er nennt es immer noch Geduld. Ich nenne es verlorenen Schwung."},
    {en="Neither plan is perfect yet. Mine is closer.", de="Noch ist keiner der Pläne perfekt. Meiner ist schon näher dran."},
  },
  INTERRUPTED={
    {en="Wait. RED is about to admit my route is faster.", de="Warte. ROT gibt gleich zu, dass mein Weg schneller ist."},
    {en="One second. I am winning the argument.", de="Eine Sekunde. Ich gewinne gerade die Diskussion."},
  },
  PRE_CHALLENGE={
    {en="Settle this for us. Pick a plan and battle.", de="Entscheide das für uns. Such dir einen Plan aus und kämpf."},
    {en="Three Trainers, three approaches. Let us see which one survives.", de="Drei Trainer, drei Ansätze. Mal sehen, welcher sich durchsetzt."},
  },
  POST_WIN={
    {en="Fine. Your plan worked. I already know what I would change.", de="Na gut. Dein Plan hat funktioniert. Ich weiß schon, was ich ändern würde."},
    {en="You beat both predictions. That was worth seeing.", de="Du hast beide Vorhersagen widerlegt. Das war sehenswert."},
  },
  POST_LOSS={
    {en="You chose the slow answer and still rushed it.", de="Du hast dich für den langsamen Plan entschieden und bist trotzdem hektisch geworden."},
    {en="RED saw the gap too. I used it first.", de="ROT hat die Lücke auch gesehen. Ich habe sie zuerst genutzt."},
  },
  POST_ABORT={
    {en="We are blocking the League road. Argument postponed.", de="Wir blockieren den Weg zur Liga. Die Diskussion geht später weiter."},
    {en="Bad place for this. We move before someone complains.", de="Schlechter Ort dafür. Wir gehen, bevor sich jemand beschwert."},
  },
  FAREWELL={
    {en="I take the fast route. RED can take the scenic one.", de="Ich nehme den schnellen Weg. ROT kann ja den mit Aussicht nehmen."},
    {en="Next meeting, bring a better counterargument.", de="Bring beim nächsten Treffen ein besseres Gegenargument mit."},
  },
})

return {
  actor="BLUE", voice=VOICE, rows=rows,
  lookup=function(locale, key)
    local bucket = strings[locale == "de" and "de" or "en"]
    return bucket[key]
  end,
  strings=strings,
}
