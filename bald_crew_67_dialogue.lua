-- Deliberately short bilingual text pages for native and ORAS/VASC dialogs.
local D={
 noItems={en='No Bag items inside the trial.\nHealing moves work in battle.\fLeave to heal or change supplies.\nYour current block will restart.',
  de='Keine Beutel-Items in der Prüfung.\nHeilattacken wirken im Kampf.\fZum Heilen bitte hinausgehen.\nDein aktueller Block beginnt neu.'},
 rear={en='No sneaking in from behind.\nThe Crew sealed this entrance.\fUse the main entrance\non the other side of Mt. Moon.',
  de='Von hinten wird nicht gemogelt.\nDie Crew hat hier abgeriegelt.\fNimm den Haupteingang\nauf der anderen Mondberg-Seite.'},
 stairs={en='Only the entrance hall today.\nThese stairs are sealed.\fAll the stars are up here.\nSome just have shinier heads.',
  de='Heute zählt nur die Eingangshalle.\nDie Treppen sind versiegelt.\fDie Stars stehen alle hier oben.\nManche glänzen nur etwas mehr.'},
 future={en='One shiny head at a time.\nBeat the trainer before me first.',
  de='Eine glänzende Stirn nach der\nanderen. Erst mein Vorgänger!'},
 defeated={en='You beat me fair and square.\nKeep going. The Crew is waiting.',
  de='Du hast mich fair geschlagen.\nWeiter! Die Crew wartet schon.'},
 trainers={},
}
-- Adapted from the original Youngster Crew story draft (2026-08-31).
-- Current 3+4 blocks/rewards override the historical draft; no cut rewards return.
D.callOpening={en='RING! RING!\fCREW: Champion? The Youngster Crew here. You beat the Elite Four. Time for the hairless hard mode.',
 de='Klingeling!\fCREW: Champion? Hier ist die Youngster Crew. Top Vier geschafft? Jetzt fehlt die haarlose Härteprüfung.'}
D.callOmega={
 RED={en='OmegaDIAS: There you are, Champion. Ready for a proper challenge? A nod will do. Red should stay silent.',de='OmegaDIAS: Da bist du ja, Champion. Bereit für eine echte Herausforderung? Nicken reicht. Red bleibt still.'},
 GREEN={en='OmegaDIAS: Green as the hero? That was not in the manual! I asked for a Champion and got a walking mod.',de='OmegaDIAS: Green als Hauptfigur? Das stand nicht im Handbuch! Ich wollte einen Champion und bekam eine wandelnde Mod.'},
 BLUE={en='OmegaDIAS: Blue?! You are the rival! Who gave you the leading role? Fine. Bring your team.',de='OmegaDIAS: Blue?! Du bist doch der Rivale! Wer hat dir die Hauptrolle gegeben? Na gut. Bring dein Team mit.'},
}
D.call={
 chibi_gaming={en='Chibi: Who scaled this call? The text edge is flickering.',de='Chibi: Wer hat diesen Anruf skaliert? Die Textkante flimmert.'},
 tav={en='Tav: Connection established. No errors in the log. Yet.',de='Tav: Verbindung steht. Keine Fehler im Log. Noch nicht.'},
 ya_dad={en='Ya Dad: Bring your strongest team. I like a challenge with staying power.',de='Ya Dad: Bring dein stärkstes Team. Ich mag Herausforderungen mit ordentlich Ausdauer.'},
 ag64={en='AG64: If the route fails, send exact steps to reproduce it. Not just: it is broken.',de='AG64: Falls der Weg nicht klappt: genaue Schritte zum Reproduzieren. Nicht nur: geht nicht.'},
 james={en='James: Bring new stuff. Properly retro! No modern nonsense.',de='James: Bring neuen Stuff. Aber richtig retro! Kein moderner Schnickschnack.'},
 fabelle_moon={en='Fabelle: Mt. Moon already has my name. One blue eye on your team, one green eye on victory.',de='Fabelle: Der Mond gehört schon zu meinem Namen. Ein blaues Auge auf dein Team, ein grünes auf den Sieg.'},
}
D.callClosing={en='CREW: Mt. Moon. The original entrance hall. Follow the SHINING DOME sign. Bring your team. Leave the comb at home.',
 de='CREW: Mondberg. Die bekannte Eingangshalle. Folge dem Schild GLANZKUPPEL. Bring dein Team. Lass den Kamm zu Hause.'}
D.sign={en='THE SHINING DOME\nYOUNGSTER CREW\fHair optional. Strategy required. The seven are waiting inside.',
 de='DIE GLANZKUPPEL\nYOUNGSTER CREW\fHaare optional. Strategie Pflicht. Die sieben warten drinnen.'}
D.halfTime={en='Tav: First block compiled. Ya Dad starts the next one with your team fully restored. Enjoy the break. We do not need to comb anything.',
 de='Tav: Erster Block kompiliert. Bei Ya Dad startet der nächste mit vollem Team. Genieß die Pause. Wir müssen nichts kämmen.'}
D.reveal={en='AG64: Seven wins. Reproducible.\fTav: Both blocks complete. Reward path... blocked?\fJames: That should be everyone. Unless someone added new stuff.\fChibi: His sprite has not even passed my review.\fFabelle: There is a shadow in the middle. And it is not my tail.\fPandy: I built this quest. Did you think I would just watch?\fOmegaDIAS: Secret boss accepted. You are welcome.',
 de='AG64: Sieben Siege. Reproduzierbar.\fTav: Beide Blöcke fertig. Belohnungspfad... blockiert?\fJames: Das wären alle. Es sei denn, jemand hat etwas Neues eingebaut.\fChibi: Sein Sprite ist nicht mal von mir abgenommen.\fFabelle: Da ist ein Schatten in der Mitte. Und es ist nicht mein Schweif.\fPandy: Ich habe die Quest gebaut. Dachtet ihr, ich schaue nur zu?\fOmegaDIAS: Geheimer Boss angenommen. Gern geschehen.'}
D.cheat={en='Pandy: Defeated? That is a display bug.\fUP UP DOWN DOWN LEFT RIGHT LEFT RIGHT B A!\fCHEAT ACCEPTED: LOAD RESERVE.\fSix NEW Pokemon. Six more Megas. No healing for your side.\fChibi: That is not a HUD bug. That is cheating.\fPandy: Developer feature. Welcome to phase two.',
 de='Pandy: Besiegt? Das ist ein Anzeigefehler.\fHOCH HOCH RUNTER RUNTER LINKS RECHTS LINKS RECHTS B A!\fCHEAT AKTIV: RESERVE LADEN.\fSechs NEUE Pokemon. Sechs weitere Megas. Keine Heilung für deine Seite.\fChibi: Das ist kein HUD-Bug. Das ist Schummeln.\fPandy: Entwickler-Feature. Willkommen in Phase zwei.'}
D.trainers.omega_dias={en='Six feature ideas. Six Pokemon. You are the acceptance test.',de='Sechs Feature-Ideen. Sechs Pokemon. Du bist der Abnahmetest.'}
D.trainers.chibi_gaming={en='Your shadow is one pixel too far left. The floor pattern repeats. Our heads are too shiny.\fRight. NOW we can battle.',de='Dein Schatten sitzt einen Pixel zu weit links. Das Bodenmuster wiederholt sich. Unsere Köpfe glänzen zu stark.\fSo. JETZT können wir kämpfen.'}
D.trainers.tav={en='Team compiled. No warnings. Bag locked; held items allowed. Start the build.',de='Team kompiliert. Keine Warnungen. Beutel gesperrt, Trage-Items erlaubt. Starten wir den Build.'}
D.trainers.ya_dad={en='You brought stamina? Good. Four of us, no healing break. I will take it easy with the first Pokemon. Allegedly.',de='Ausdauer mitgebracht? Gut. Vier von uns, keine Heilpause. Beim ersten Pokemon bin ich noch sanft. Angeblich.'}
D.trainers.ag64={en='Usually I test bugs. Today I test the Champion. Please fail in a reproducible way.',de='Sonst teste ich Bugs. Heute den Champion. Bitte scheitere reproduzierbar.'}
D.trainers.james={en='New stuff, old-school rules. Give me a fight we would have lied about on the playground.',de='Neuer Stuff, alte Schule. Zeig mir einen Kampf, über den man auf dem Schulhof gelogen hätte.'}
D.trainers.fabelle_moon={en='One eye blue, one green. Neither missed your last battle.\fMy Pikachu stayed Pikachu on purpose. You will find out why.',de='Ein Auge blau, eins grün. Keines hat deinen letzten Kampf verpasst.\fMein Pikachu blieb mit Absicht Pikachu. Du erfährst gleich warum.'}
D.trainers.pandy={en='Your team gets one full heal before we start. Your usual one Mega stays one.\fMy team? Six Megas. I commented out the limit.\fIf you lose, the entire run resets. Welcome to the developer build.',de='Dein Team wird vor dem Start voll geheilt. Deine eine Mega bleibt eine.\fMein Team? Sechs Megas. Ich habe das Limit auskommentiert.\fVerlierst du, beginnt der ganze Lauf neu. Willkommen im Entwickler-Build.'}
D.waiting={
 omega_dias={en='First beat %s. My feature list has an order.',de='Schlag erst %s. Meine Feature-Liste hat eine Reihenfolge.'},
 chibi_gaming={en='First beat %s. Your progress bar is visibly too short.',de='Schlag erst %s. Dein Fortschrittsbalken ist sichtbar zu kurz.'},
 tav={en='Missing dependency: %s. Defeat that trainer before running this build.',de='Abhängigkeit fehlt: %s. Erst besiegen, dann diesen Build starten.'},
 ya_dad={en='First beat %s. No skipping the warm-up.',de='Schlag erst %s. Das Aufwärmen überspringen wir nicht.'},
 ag64={en='Step one: defeat %s. Step two: come back. Reproducible?',de='Schritt eins: %s besiegen. Schritt zwei: wiederkommen. Reproduzierbar?'},
 james={en='First beat %s. Even the old games had an order.',de='Schlag erst %s. Selbst früher gab es eine Reihenfolge.'},
 fabelle_moon={en='First beat %s. Both my eyes can see you trying to skip ahead.',de='Schlag erst %s. Ich sehe mit beiden Augen, wie du abkürzen willst.'},
 pandy={en='First beat %s. You cannot skip the final dependency.',de='Schlag erst %s. Die letzte Abhängigkeit lässt sich nicht überspringen.'},
}
D.defeatedBy={
 omega_dias={en='Challenge passed. I will add tougher opponents to my feature list. No speech needed. A nod is enough.',de='Prüfung bestanden. Stärkere Gegner kommen auf meine Wunschliste. Keine Rede nötig. Nicken reicht.'},
 chibi_gaming={en='You won. The shadow is still wrong. Add bloom to my defeat.',de='Du hast gewonnen. Der Schatten ist trotzdem falsch. Meine Niederlage braucht Bloom.'},
 tav={en='Unexpected result. No crash, but I am opening the debugger.',de='Unerwartetes Ergebnis. Kein Crash. Ich öffne trotzdem den Debugger.'},
 ya_dad={en='Not angry. Just disappointed. Kidding. You lasted impressively long.',de='Nicht wütend. Nur enttäuscht. Spaß! Du hast erstaunlich lange durchgehalten.'},
 ag64={en='Result reproducible: Champion wins. Severity: hair-raising. Harmless to us.',de='Ergebnis reproduzierbar: Champion gewinnt. Schweregrad: haarsträubend. Für uns ungefährlich.'},
 james={en='Now THAT was a playground rumour. When is the next retro boss?',de='DAS war ein Schulhof-Gerücht. Wann kommt der nächste Retro-Boss?'},
 fabelle_moon={en='Both eyes saw that coming. Neither wanted to believe it.',de='Beide Augen haben es kommen sehen. Keines wollte es glauben.'},
 pandy={en='An exploit I cannot patch: skill. Twelve Megas. You still won.\fFine. No third team. My ego has run out of PP.',de='Ein Exploit, den ich nicht patchen kann: Können. Zwölf Megas. Du gewinnst trotzdem.\fGut. Kein drittes Team. Mein Ego hat keine AP mehr.'},
}
D.victorious={
 omega_dias={en='Feature accepted: the boss wins. Retry starts at me.',de='Feature angenommen: Der Boss gewinnt. Neustart bei mir.'},
 chibi_gaming={en='Your defeat needs more particles. The checkpoint does not.',de='Deine Niederlage braucht mehr Partikel. Der Kontrollpunkt nicht.'},
 tav={en='Build successful. Your input was invalid. Please try again.',de='Build erfolgreich. Deine Eingabe war ungültig. Bitte erneut versuchen.'},
 ya_dad={en='Catch your breath. Then come back. Dad\'s orders.',de='Hol erst mal Luft. Dann komm wieder. Weil Papa es sagt.'},
 ag64={en='Test complete. Worked on my machine.',de='Test abgeschlossen. Bei mir funktioniert es.'},
 james={en='Old-school defeat. At least this trial leaves your money alone.',de='Niederlage wie früher. Wenigstens lässt die Prüfung dein Geld in Ruhe.'},
 fabelle_moon={en='The Moon keeps its crown. Ya Dad will welcome you back.',de='Der Mond behält seine Krone. Ya Dad nimmt dich wieder in Empfang.'},
 pandy={en='Working as intended. All the way back to OmegaDIAS. No saved phase two.',de='Funktioniert wie vorgesehen. Ganz zurück zu OmegaDIAS. Kein Phase-zwei-Checkpoint.'},
}
D.sendouts={
 chibi_gaming={'That fade-out worked. Finally.','These pixels deserve better lighting.','The camera moved. I saw that.','No interpolation on my watch.','Last slot. If I lose, blame the renderer.'},
 tav={'Next process. No fatal error.','Fallback loaded. Mind the cave walls.','Small interface. Fewer bugs.','Previous process returned false.','Last process. Rest is not a crash.'},
 omega_dias={'Feature two: find your weak point.','Feature three: a less comfortable boss.','Feature four: an unusual team.','Feature five: earn that title.','Feature six: no easy last slot.'},
 ya_dad={'Already out of breath?','That ended sooner than expected.','Still standing? I like the stamina.','Do not mash A. Enjoy the challenge.','Last slot. The climax. Of the battle.'},
 ag64={'Three heads. Three independent testers.','If anything burns, it is intended.','Now testing the water resistance.','Feature, not bug. Poor documentation.','The shiny colour is intentional.'},
 james={'A missed Blizzard is retro authenticity.','Old-school status. Still works.','No changelog. Just playground rumours.','New stuff. Still honest pixels.','Last slot. An honest fight.'},
 fabelle_moon={'Water off a Vaporeon.','My night shift is arriving.','Enough staring. Time to gallop.','Nine tails. No loose ends.','Pikachu. Small body. Large invoice.'},
 pandy={'Breakpoint cleared. Enter DEADLOCK.','Four brains. No warnings.','My Raichu is overclocked.','Administrator rights belong to ROOT.','MAIN. Shiny developer build.',
 'The firewall has teeth.','Your stack trace ends here.','Memory access denied.','This hotfix really burns.','KERNEL panic. Your final test.'},
}
D.sendoutsDE={
 chibi_gaming={'Der Fade-out klappt. Endlich.','Diese Pixel verdienen besseres Licht.','Die Kamera bewegt sich. Ich sehe das.','Keine Interpolation unter meiner Aufsicht.','Letzter Slot. Schuld ist der Renderer.'},
 tav={'Nächster Prozess. Kein schwerer Fehler.','Ersatz geladen. Vorsicht, Höhlenwand.','Kleine Schnittstelle. Weniger Fehler.','Voriger Prozess meldet: gescheitert.','Letzter Prozess. Erholung ist kein Absturz.'},
 omega_dias={'Feature zwei: Schwachstellen suchen.','Feature drei: ein unbequemer Boss.','Feature vier: ungewöhnliches Team.','Feature fünf: Verdiene den Titel.','Feature sechs: kein leichter letzter Slot.'},
 ya_dad={'Schon außer Atem?','Das war schneller als erwartet.','Noch auf den Beinen? Gute Ausdauer.','Nicht auf A hämmern. Genieß den Kampf.','Letzter Slot. Der Höhepunkt. Des Kampfes.'},
 ag64={'Drei Köpfe. Drei unabhängige Tester.','Falls etwas brennt: Absicht.','Jetzt kommt der Wassertest.','Feature, kein Bug. Nur schlecht dokumentiert.','Die Shiny-Farbe ist Absicht.'},
 james={'Blizzard daneben? Echtes Retro-Gefühl.','Status wie früher. Wirkt noch immer.','Kein Changelog. Nur Schulhof-Gerüchte.','Neuer Stuff. Ehrliche Pixel.','Letzter Slot. Ein ehrlicher Kampf.'},
 fabelle_moon={'Das perlt an Aquana ab.','Meine Nachtschicht kommt.','Genug gestarrt. Jetzt wird galoppiert.','Neun Schweife. Keine losen Enden.','Pikachu. Kleiner Körper. Große Rechnung.'},
 pandy={'Breakpoint geschafft. Jetzt DEADLOCK.','Vier Gehirne. Keine Warnungen.','Mein Raichu ist übertaktet.','Administratorrechte gehören ROOT.','MAIN. Shiny. Entwickler-Build.',
 'Die Firewall hat Zähne.','Dein Stacktrace endet hier.','Speicherzugriff verweigert.','Dieser Hotfix brennt wirklich.','KERNEL-Panik. Dein letzter Test.'},
}
D.front={
 en='Welcome to the Shining Dome!\nI handle the paperwork. They handle the shine.\fBattles come in blocks. Full healing before each block; no Bag items inside.\fHealing moves and held items work in battle. Leaving or losing restarts your current block and reopens Mt. Moon.\fReady to step inside?',
 de='Willkommen in der Glanzkuppel!\nIch mache Papierkram. Die anderen glänzen.\fGekämpft wird in Blöcken. Vollheilung vor jedem Block; keine Beutel-Items drinnen.\fHeilattacken und Trage-Items wirken im Kampf. Bei Abbruch oder Niederlage beginnt dein Block neu. Der Mondberg wird wieder frei.\fBereit, hineinzugehen?'}
D.restart={
 en='Mt. Moon is open again.\nThe Crew is on its comb-free break.\fYour next block starts with %s.\nSet up the Shining Dome and try again?',
 de='Der Mondberg ist wieder frei.\nDie Crew macht kämmfreie Pause.\fDein nächster Block beginnt mit %s.\nGlanzkuppel aufbauen und neu versuchen?'}
D.loss={
 en='This block starts over.\nYour team has been healed.\fMt. Moon is open again.\nTalk to the host beside the entrance to retry.',
 de='Dieser Block beginnt von vorn.\nDein Team ist wieder geheilt.\fDer Mondberg ist wieder frei.\nNeustart beim Betreuer neben dem Eingang.'}
D.finalLoss={
 en='Pandy ended the whole streak.\nNext attempt starts with OmegaDIAS.\fMt. Moon is open again.\nThe host beside the entrance handles retries.',
 de='Pandy hat die ganze Serie beendet.\nNächster Versuch: ab OmegaDIAS.\fDer Mondberg ist wieder frei.\nNeustart beim Betreuer neben dem Eingang.'}
D.exit={
 en='Leave the trial?\nYour current block will reset.\fMt. Moon reopens immediately.\nAsk the host beside the entrance to retry.',
 de='Prüfung verlassen?\nDein aktueller Block beginnt neu.\fDer normale Mondberg wird sofort frei.\nNeustart beim Betreuer neben dem Eingang.'}
D.sealed={
 en='You beat the Shining Dome!\nMy head is still processing that.\fThe trial is complete.\nMt. Moon and its stairs are open again.',
 de='Du hast die Glanzkuppel geschafft!\nMein Kopf verarbeitet das noch.\fDie Prüfung ist abgeschlossen.\nMondberg und Treppen sind wieder frei.'}
D.reward={
 en='Every shining head defeated!\nYour prize stays reserved.\fMt. Moon is open again.\nCollect your prize from the host outside.',
 de='Alle glänzenden Köpfe besiegt!\nDein Preis bleibt für dich reserviert.\fDer Mondberg ist wieder frei.\nPreis beim Betreuer neben dem Eingang abholen.'}
return D
