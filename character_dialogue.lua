-- Identity-authored Red / Blue / Green dialogue.
-- Every value is { English, German }; callers select exactly one language
-- from the active game translation, never from a separate mod-language knob.
--
-- Each authored rival owns the same complete 46-key story surface. Form feeds are
-- authored at the two-row Gen-I boundary so important beats never depend on
-- an automatic scroll.

local function p(en, de) return { en, de } end

local red = {
  _OaksLabRivalFedUpWithWaitingText = p(
    "{RIVAL}: PROF. OAK.\fI'm here.",
    "{RIVAL}: PROF. EICH.\fIch bin da."),
  _OaksLabRivalGrampsIsntAroundText = p(
    "{RIVAL}: {PLAYER}.\fPROF. OAK isn't here.\fLet's wait.\nHe'll be back soon.",
    "{RIVAL}: {PLAYER}.\fPROF. EICH ist nicht da.\fWarten wir hier.\nEr kommt sicher bald."),
  _OaksLabRivalGrampsText = p(
    "{RIVAL}: PROF. OAK.\fYou wanted to\nsee us?",
    "{RIVAL}: PROF. EICH.\fSie wollten uns\nsehen?"),
  _OaksLabRivalWhatAboutMeText = p(
    "{RIVAL}: And my\npartner, Professor?",
    "{RIVAL}: Und mein\nPartner, Professor?"),
  _OaksLabRivalWhatDidYouCallMeForText = p(
    "{RIVAL}: You wanted to\nsee us, PROF. OAK?",
    "{RIVAL}: Sie wollten uns\nsehen, PROF. EICH?"),
  _OaksLabRivalGoAheadAndChooseText = p(
    "{RIVAL}: You choose\nfirst, {PLAYER}.\fI've already made up\nmy mind.",
    "{RIVAL}: Such du zuerst\naus, {PLAYER}.\fIch habe mich schon\nentschieden."),
  _OaksLabRivalIllGetABetterPokemonThanYou = p(
    "{RIVAL}: Take your time.\fI know what I'm\nlooking for.",
    "{RIVAL}: Lass dir Zeit.\fIch weiß, wonach\nich suche."),
  _OaksLabRivalIllTakeThisOneText = p(
    "{RIVAL}: I'll choose\nthis one.",
    "{RIVAL}: Ich nehme\ndieses hier."),
  _OaksLabRivalReceivedMonText = p(
    "{RIVAL} received\na {RAM:wNameBuffer}!",
    "{RIVAL} erhält\n{RAM:wNameBuffer}!"),
  _OaksLabRivalTakesText1 = p(
    "{RIVAL}: {PLAYER},\nthis one came to me.\fI thought PROF. OAK\nhad chosen it for me.",
    "{RIVAL}: {PLAYER},\ndieses kam auf mich zu.\fIch dachte, PROF. EICH\nhätte es mir zugedacht."),
  _OaksLabRivalTakesText2 = p(
    "{RIVAL} gently picks\nup the POKéMON.",
    "{RIVAL} nimmt das\nPOKéMON vorsichtig hoch."),
  _OaksLabRivalTakesText3 = p(
    "OAK: {RIVAL}!\fThat was not\nthe plan.",
    "EICH: {RIVAL}!\fSo war das nicht\ngeplant."),
  _OaksLabRivalTakesText4 = p(
    "{RIVAL}: I understand.\fI should have asked\nbefore taking it.",
    "{RIVAL}: Verstanden.\fIch hätte erst\nfragen sollen."),
  _OaksLabRivalTakesText5 = p(
    "OAK: Hmm...\fThen so be it.\nKeep that POKéMON.\f{PLAYER}, come over\nhere.",
    "EICH: Hmm...\fDann soll es so sein.\nBehalte das POKéMON.\f{PLAYER}, komm bitte\nher."),
  _OaksLabRivalIllTakeYouOnText = p(
    "{RIVAL}: Wait,\n{PLAYER}.\fLet's see what our\npartners can do.",
    "{RIVAL}: Warte,\n{PLAYER}.\fSehen wir, was unsere\nPartner können."),
  _OaksLabRivalLeaveItAllToMeText = p(
    "{RIVAL}: Understood,\nPROF. OAK.\fI'll record what\nwe discover.\fWe'll both complete\nthe POKéDEX, {PLAYER}.",
    "{RIVAL}: Verstanden,\nPROF. EICH.\fIch halte fest, was\nwir entdecken.\fWir vervollständigen\nbeide den POKéDEX, {PLAYER}."),
  _OaksLabRivalSmellYouLaterText = p(
    "{RIVAL}: Time to train.\fSee you soon,\n{PLAYER}.",
    "{RIVAL}: Zeit fürs\nTraining.\fBis bald, {PLAYER}."),
  _OaksLabRivalMyPokemonHasGrownStrongerText = p(
    "{RIVAL}: PROF. OAK,\nwe've grown stronger.\fWould you take\na look?",
    "{RIVAL}: PROF. EICH,\nwir sind stärker geworden.\fSehen Sie es sich\nbitte an."),
  _OaksLabRivalMyPokemonLooksStrongerText = p(
    "{RIVAL}: Your partner\nlooks ready.\fMine is ready too.",
    "{RIVAL}: Dein Partner\nwirkt bereit.\fMeiner ist es auch."),
  _OaksLabRivalIPickedTheWrongPokemonText = p(
    "Well fought,\n{PLAYER}.\fYou found my opening.\fBefore I could\nclose it.",
    "Gut gekämpft,\n{PLAYER}.\fDu hast meine Lücke\nerkannt.\fBevor ich sie\nschließen konnte."),
  _OaksLabRivalAmIGreatOrWhatText = p(
    "{RIVAL}: Good battle.\fI controlled the pace\nthis time.",
    "{RIVAL}: Guter Kampf.\fDiesmal habe ich das\nTempo bestimmt."),
  _Rival1WinText = p(
    "{RIVAL}: Good battle.\fI controlled the pace\nthis time.",
    "{RIVAL}: Guter Kampf.\fDiesmal habe ich das\nTempo bestimmt."),
  _CeruleanCityRivalPreBattleText = p(
    "{RIVAL}: {PLAYER}.\fYour team covers for\neach other well.\fLet's see if that holds\nunder pressure.",
    "{RIVAL}: {PLAYER}.\fDein Team sichert sich\ngut gegenseitig ab.\fMal sehen, ob das auch\nunter Druck gelingt."),
  _CeruleanCityRivalDefeatedText = p(
    "You broke through.\fI'll be ready for that\nnext time.",
    "Du bist durchgekommen.\fDarauf bin ich beim\nnächsten Mal vorbereitet."),
  _CeruleanCityRivalIWentToBillsText = p(
    "{RIVAL}: I met BILL.\fHis system is\nimpressive.\fYou should see it\nfor yourself.",
    "{RIVAL}: Ich habe BILL\ngetroffen.\fSein System ist\nbeeindruckend.\fSieh es dir selbst an."),
  _PokemonTower2FRivalWhatBringsYouHereText = p(
    "{RIVAL}: {PLAYER}.\fAre you here to pay\nyour respects too?\fLet's keep this battle\nquiet.\fThis place deserves\nthat much.",
    "{RIVAL}: {PLAYER}.\fBist du auch hier, um\nAbschied zu nehmen?\fKämpfen wir in Ruhe.\fDas sind wir diesem Ort\nschuldig."),
  _PokemonTower2FRivalDefeatedText = p(
    "You won.\fStay close to your\nteam in here.",
    "Du hast gewonnen.\fBleib hier nah bei\ndeinem Team."),
  _PokemonTower2FRivalVictoryText = p(
    "{RIVAL}: I won.\fTake care of them.\fThis tower reminds us\nwhy.",
    "{RIVAL}: Ich habe\ngewonnen.\fPass gut auf dein\nTeam auf.\fDieser Turm erinnert\nuns daran, warum."),
  _Route22RivalBeforeBattleText1 = p(
    "{RIVAL}: The guard says\nwe need BADGEs.\fBefore we head back,\none battle?",
    "{RIVAL}: Die Wache sagt,\nwir brauchen ORDEN.\fBevor wir umkehren:\nEin Kampf?"),
  _Route22Rival1DefeatedText = p(
    "You found the opening.\fNext time, it won't\nbe there.",
    "Du hast die Lücke\ngefunden.\fBeim nächsten Mal\nist sie geschlossen."),
  _Route22Rival1VictoryText = p(
    "{RIVAL}: Your team\nneeds more time.\fUse it well.\nI will too.",
    "{RIVAL}: Dein Team\nbraucht noch Zeit.\fNutze sie gut.\nDas werde ich auch."),
  _Route22RivalAfterBattleText1 = p(
    "{RIVAL}: The LEAGUE\nwill be tougher.\fI'll prepare.\nYou should too.",
    "{RIVAL}: In der LIGA\nwird es schwieriger.\fIch bereite mich vor.\nDas solltest du auch."),
  _Route22RivalBeforeBattleText2 = p(
    "{RIVAL}: Eight BADGEs.\fOne last battle before\nthe LEAGUE?",
    "{RIVAL}: Acht ORDEN.\fEin letzter Kampf vor\nder LIGA?"),
  _Route22Rival2DefeatedText = p(
    "You were sharper today.\fI'll fix that before\nthe LEAGUE.",
    "Heute warst du besser.\fVor der LIGA gleiche\nich das aus."),
  _Route22Rival2VictoryText = p(
    "{RIVAL}: We both know\nwhat to improve.\fI'll see you inside.",
    "{RIVAL}: Wir wissen beide,\nworan wir arbeiten müssen.\fWir sehen uns drinnen."),
  _Route22RivalAfterBattleText2 = p(
    "{RIVAL}: Good battle,\n{PLAYER}.\fThe LEAGUE is next.\fBring your best.\nI will too.",
    "{RIVAL}: Guter Kampf,\n{PLAYER}.\fAls Nächstes die LIGA.\fZeig dort dein Bestes.\nIch tue es auch."),
  _SSAnne2FRivalText = p(
    "{RIVAL}: {PLAYER}.\fYou made it aboard.\fThe sea is quieter\nthan this ship.\fHow is your POKéDEX?",
    "{RIVAL}: {PLAYER}.\fDu bist an Bord.\fAuf See ist es ruhiger\nals auf diesem Schiff.\fWie weit ist dein\nPOKéDEX?"),
  _SSAnne2FRivalDefeatedText = p(
    "You won.\fYour team stayed\nfocused.",
    "Du hast gewonnen.\fDein Team blieb\nkonzentriert."),
  _SSAnne2FRivalCutMasterText = p(
    "{RIVAL}: The captain\nknows CUT.\fHe looks unwell.\nBe considerate.",
    "{RIVAL}: Der Kapitän\nkennt ZERSCHNEIDER.\fIhm geht es nicht gut.\nGeh behutsam vor."),
  _SilphCo7FRivalText = p(
    "{RIVAL}: You came,\n{PLAYER}.\fGood.\nI was concerned.",
    "{RIVAL}: Du bist da,\n{PLAYER}.\fGut.\nIch war besorgt."),
  _SilphCo7FRivalWaitedHereText = p(
    "{RIVAL}: TEAM ROCKET\nis ahead.\fShow me you're ready.\nThen we move.",
    "{RIVAL}: TEAM ROCKET\nist weiter vorn.\fZeig mir, dass du bereit\nbist. Dann gehen wir."),
  _SilphCo7FRivalDefeatedText = p(
    "You are ready.\fStay alert upstairs.",
    "Du bist bereit.\fBleib oben wachsam."),
  _SilphCo7FRivalVictoryText = p(
    "{RIVAL}: Not yet.\fRegroup.\nI'll secure this floor.",
    "{RIVAL}: Noch nicht.\fSammle dich.\nIch sichere diese Etage."),
  _ChampionsRoomRivalIntroText = p(
    "{RIVAL}: I expected you,\n{PLAYER}.\fEvery road through\nKANTO led us here.\fI'm the LEAGUE\nchampion.\fBring me your best.\nI will do the same.",
    "{RIVAL}: Ich erwartete\ndich, {PLAYER}.\fJeder Weg durch KANTO\nführte uns hierher.\fIch bin der\nLIGA-Meister.\fZeig mir dein Bestes.\nIch tue dasselbe."),
  _RivalDefeatedText = p(
    "You earned the title.\fYour team had one more\nanswer than mine.\fI'll return stronger.",
    "Du hast dir den Titel\nverdient.\fDein Team hatte eine\nAntwort mehr als meins.\fIch komme stärker\nzurück."),
  _RivalVictoryText = p(
    "I defended the title.\fRecover, {PLAYER}.\fI'll expect your best\nnext time.",
    "Ich habe den Titel\nverteidigt.\fErhol dich, {PLAYER}.\fBeim nächsten Mal will\nich dein Bestes sehen."),
}

local blue = {
  _OaksLabRivalFedUpWithWaitingText = p(
    "{RIVAL}: Gramps!\fI finished training\nwhile you called.",
    "{RIVAL}: Opa!\fWährend du riefst,\nwar mein Training fertig."),
  _OaksLabRivalGrampsIsntAroundText = p(
    "{RIVAL}: {PLAYER}.\fGramps stepped out.\fTry to keep up.\nWaiting is easy.",
    "{RIVAL}: {PLAYER}.\fOpa ist kurz fort.\fBleib dran.\nWarten ist leicht."),
  _OaksLabRivalGrampsText = p(
    "{RIVAL}: Gramps.\fYou wanted us?",
    "{RIVAL}: Opa.\fDu wolltest uns\nsprechen?"),
  _OaksLabRivalWhatAboutMeText = p(
    "{RIVAL}: And my\nPOKéMON, Gramps?",
    "{RIVAL}: Und mein\nPOKéMON, Opa?"),
  _OaksLabRivalWhatDidYouCallMeForText = p(
    "{RIVAL}: You called,\nGramps?\fMake it interesting.",
    "{RIVAL}: Du hast\ngerufen, Opa?\fMach es interessant."),
  _OaksLabRivalGoAheadAndChooseText = p(
    "{RIVAL}: You pick first,\n{PLAYER}.\fI like knowing what\nI'm about to beat.",
    "{RIVAL}: Wähl zuerst,\n{PLAYER}.\fIch weiß gern, was\nich gleich besiege."),
  _OaksLabRivalIllGetABetterPokemonThanYou = p(
    "{RIVAL}: I'll pick last.\fBest view of the field,\nbest choice.",
    "{RIVAL}: Ich wähle zuletzt.\fBester Blick aufs Feld,\nbeste Wahl."),
  _OaksLabRivalIllTakeThisOneText = p(
    "{RIVAL}: This one.\fIt already looks\nlike a winner.",
    "{RIVAL}: Dieses hier.\fEs sieht schon wie\nein Sieger aus."),
  _OaksLabRivalReceivedMonText = p(
    "{RIVAL} received\na {RAM:wNameBuffer}!",
    "{RIVAL} erhält\n{RAM:wNameBuffer}!"),
  _OaksLabRivalTakesText1 = p(
    "{RIVAL}: {PLAYER},\nthis one's mine.\fYou hesitated.\nI didn't.",
    "{RIVAL}: {PLAYER},\ndieses gehört mir.\fDu hast gezögert.\nIch nicht."),
  _OaksLabRivalTakesText2 = p(
    "{RIVAL} swiftly took\nthe POKéMON!",
    "{RIVAL} nahm das\nPOKéMON blitzschnell!"),
  _OaksLabRivalTakesText3 = p(
    "OAK: {RIVAL}!\fThat one was for--",
    "EICH: {RIVAL}!\fDas war doch für..."),
  _OaksLabRivalTakesText4 = p(
    "{RIVAL}: I noticed.\fIt reached me first.\fCall it field\nresearch, Gramps.",
    "{RIVAL}: Hab ich bemerkt.\fEs kam zuerst zu mir.\fNenn es Feldforschung,\nOpa."),
  _OaksLabRivalTakesText5 = p(
    "OAK: Hmm...\fKeep that POKéMON.\fIt clearly chose\nquickly too.\f{PLAYER}, come over\nhere.",
    "EICH: Hmm...\fBehalte das POKéMON.\fEs hat offenbar auch\nschnell gewählt.\f{PLAYER}, komm bitte\nher."),
  _OaksLabRivalIllTakeYouOnText = p(
    "{RIVAL}: Hold it,\n{PLAYER}.\fLet's settle whose\nchoice was better.",
    "{RIVAL}: Halt,\n{PLAYER}.\fKlären wir, wessen\nWahl besser war."),
  _OaksLabRivalLeaveItAllToMeText = p(
    "{RIVAL}: Leave it to\nme, Gramps.\fI'll finish first.\n{PLAYER} can compare.",
    "{RIVAL}: Überlass das\nmir, Opa.\fIch bin zuerst fertig.\n{PLAYER} darf vergleichen."),
  _OaksLabRivalSmellYouLaterText = p(
    "{RIVAL}: Training time.\fCatch up if you can,\n{PLAYER}.",
    "{RIVAL}: Trainingszeit.\fHol mich ein, wenn\ndu kannst, {PLAYER}."),
  _OaksLabRivalMyPokemonHasGrownStrongerText = p(
    "{RIVAL}: Gramps,\nlook at these results.\fStronger already.\nExactly as planned.",
    "{RIVAL}: Opa,\nsieh dir das an.\fSchon stärker.\nGenau wie geplant."),
  _OaksLabRivalMyPokemonLooksStrongerText = p(
    "{RIVAL}: Yours improved.\fMine set the pace.",
    "{RIVAL}: Deines ist besser.\fMeines gab das Tempo vor."),
  _OaksLabRivalIPickedTheWrongPokemonText = p(
    "Fine, {PLAYER}.\fYou found the one line\nI left open.",
    "Na gut, {PLAYER}.\fDu fandest die eine\nLücke, die ich ließ."),
  _OaksLabRivalAmIGreatOrWhatText = p(
    "{RIVAL}: That's the\nstandard.\fKeep it in sight.",
    "{RIVAL}: Das ist\nder Maßstab.\fBehalt ihn im Blick."),
  _Rival1WinText = p(
    "{RIVAL}: That's the\nstandard.\fKeep it in sight.",
    "{RIVAL}: Das ist\nder Maßstab.\fBehalt ihn im Blick."),
  _CeruleanCityRivalPreBattleText = p(
    "{RIVAL}: {PLAYER}!\fI was already ahead\nwhen I left BILL.\fLet's see if your team\ncaught up.",
    "{RIVAL}: {PLAYER}!\fSchon bei BILL lag\nich vorn.\fMal sehen, ob dein\nTeam aufgeholt hat."),
  _CeruleanCityRivalDefeatedText = p(
    "You caught up.\fDon't get used to\nthe view.",
    "Du hast aufgeholt.\fGewöhn dich nicht\nan die Aussicht."),
  _CeruleanCityRivalIWentToBillsText = p(
    "{RIVAL}: BILL's PC\nis brilliant.\fHe showed me rare\nPOKéMON too.\fGo learn something.\nThen catch up.",
    "{RIVAL}: BILLs PC\nist genial.\fEr zeigte mir auch\nseltene POKéMON.\fGeh etwas lernen.\nDann hol auf."),
  _PokemonTower2FRivalWhatBringsYouHereText = p(
    "{RIVAL}: {PLAYER}.\fI came to pay\nrespects.\fThat doesn't cancel\nour match.\fWe keep it quiet.",
    "{RIVAL}: {PLAYER}.\fIch erweise meinen\nRespekt.\fUnser Kampf fällt\ndeshalb nicht aus.\fWir bleiben leise."),
  _PokemonTower2FRivalDefeatedText = p(
    "You got me.\fTake good care of\nyour team in here.",
    "Du hast mich.\fPass hier gut auf\ndein Team auf."),
  _PokemonTower2FRivalVictoryText = p(
    "{RIVAL}: I won.\fNow look after\nyour team.",
    "{RIVAL}: Ich gewann.\fJetzt kümmere dich\num dein Team."),
  _Route22RivalBeforeBattleText1 = p(
    "{RIVAL}: No BADGEs,\nno LEAGUE.\fAt least this gate\nhas one good battle.",
    "{RIVAL}: Keine ORDEN,\nkeine LIGA.\fWenigstens bietet\ndas Tor einen Kampf."),
  _Route22Rival1VictoryText = p(
    "{RIVAL}: Build your\nteam faster.\fI'll be past this gate\nwhen you do.",
    "{RIVAL}: Bau dein\nTeam schneller auf.\fDann bin ich schon\nhinter diesem Tor."),
  _Route22RivalBeforeBattleText2 = p(
    "{RIVAL}: Eight BADGEs?\fGood.\nNow this counts.\fOne last check before\nI take the LEAGUE.",
    "{RIVAL}: Acht ORDEN?\fGut.\nJetzt zählt es.\fEin letzter Test, bevor\nich die LIGA hole."),
  _Route22Rival2VictoryText = p(
    "{RIVAL}: Still sharp.\fSee you in the\nChampion's room.",
    "{RIVAL}: Immer noch stark.\fWir sehen uns im\nChamp-Raum."),
  _SSAnne2FRivalText = p(
    "{RIVAL}: {PLAYER}!\fThis ship has style.\fMy POKéDEX has more.\fShow me your count.",
    "{RIVAL}: {PLAYER}!\fDieses Schiff hat Stil.\fMein POKéDEX hat mehr.\fZeig deinen Stand."),
  _SSAnne2FRivalDefeatedText = p(
    "You win this deck.\fThe whole voyage\nis still mine.",
    "Dieses Deck gehört dir.\fDie ganze Reise\nbleibt meine."),
  _SSAnne2FRivalCutMasterText = p(
    "{RIVAL}: The captain\nknows CUT.\fHe's seasick.\nTry some tact.",
    "{RIVAL}: Der Kapitän\nkennt ZERSCHNEIDER.\fEr ist seekrank.\nZeig etwas Takt."),
  _SilphCo7FRivalText = p(
    "{RIVAL}: Finally,\n{PLAYER}.\fI cleared my side.\nHow's yours?",
    "{RIVAL}: Endlich,\n{PLAYER}.\fMeine Seite ist frei.\nUnd deine?"),
  _SilphCo7FRivalWaitedHereText = p(
    "{RIVAL}: TEAM ROCKET\nis ahead.\fProve you can keep up,\nthen we split them.",
    "{RIVAL}: TEAM ROCKET\nist voraus.\fBeweis, dass du mithältst,\ndann teilen wir sie."),
  _SilphCo7FRivalDefeatedText = p(
    "Good.\fYou can handle\nthe next floor.",
    "Gut.\fDu schaffst\ndie nächste Etage."),
  _SilphCo7FRivalVictoryText = p(
    "{RIVAL}: Not sharp\nenough.\fReset your plan.\nI'll hold the lead.",
    "{RIVAL}: Nicht scharf\ngenug.\fOrdne deinen Plan.\nIch halte die Führung."),
  _ChampionsRoomRivalIntroText = p(
    "{RIVAL}: Right on time,\n{PLAYER}.\fI built KANTO's\nbest team.\fI'm the LEAGUE\nchampion.\fTake the title--\nif you can.",
    "{RIVAL}: Genau pünktlich,\n{PLAYER}.\fIch baute KANTOs\nbestes Team.\fIch bin der\nLIGA-Meister.\fHol dir den Titel--\nwenn du kannst."),
  _RivalDefeatedText = p(
    "You took it.\fEnjoy the view.\nI'm taking it back.",
    "Du hast ihn.\fGenieß die Aussicht.\nIch hole ihn zurück."),
  _RivalVictoryText = p(
    "Champion stays\nChampion.\fTrain up, {PLAYER}.\nMake the rematch count.",
    "Der Champ bleibt\nChamp.\fTrainiere, {PLAYER}.\nDie Revanche soll zählen."),
}

local green = {
  _OaksLabRivalFedUpWithWaitingText = p(
    "{RIVAL}: Professor!\fI brought my notes.\fEven the important\nones.",
    "{RIVAL}: Professor!\fIch habe meine\nNotizen dabei.\fSogar die wichtigen."),
  _OaksLabRivalGrampsIsntAroundText = p(
    "{RIVAL}: Hey,\n{PLAYER}!\fI checked the whole lab.\fPROF. OAK isn't here.\fSo we wait together.",
    "{RIVAL}: Hey,\n{PLAYER}!\fIch habe im ganzen\nLabor nachgesehen.\fPROF. EICH ist nicht da.\fDann warten wir\nzusammen."),
  _OaksLabRivalGrampsText = p(
    "{RIVAL}: Professor!\fThere you are!",
    "{RIVAL}: Professor!\fDa sind Sie ja!"),
  _OaksLabRivalWhatAboutMeText = p(
    "{RIVAL}: What about me,\nProfessor?\fI was very patient!\nMostly.",
    "{RIVAL}: Was ist mit mir,\nProfessor?\fIch war sehr geduldig!\nMeistens."),
  _OaksLabRivalWhatDidYouCallMeForText = p(
    "{RIVAL}: Did you call\nfor us, Professor?\fI came as fast\nas I could!",
    "{RIVAL}: Wollten Sie\nuns sprechen, Professor?\fIch kam so schnell\nich konnte!"),
  _OaksLabRivalGoAheadAndChooseText = p(
    "{RIVAL}: You choose\nfirst, {PLAYER}!\fI'll compare the others.\nThat's the plan.",
    "{RIVAL}: Such du zuerst\naus, {PLAYER}!\fIch vergleiche die\nanderen. Das ist der Plan."),
  _OaksLabRivalIllGetABetterPokemonThanYou = p(
    "{RIVAL}: I'll choose\ncarefully too!\fI already have\nthree favorites.",
    "{RIVAL}: Ich wähle auch\nganz sorgfältig!\fIch habe schon drei\nFavoriten."),
  _OaksLabRivalIllTakeThisOneText = p(
    "{RIVAL}: This one!\fWe agree.",
    "{RIVAL}: Dieses hier!\fWir sind uns einig."),
  _OaksLabRivalReceivedMonText = p(
    "{RIVAL} received\na {RAM:wNameBuffer}!",
    "{RIVAL} erhält\n{RAM:wNameBuffer}!"),
  _OaksLabRivalTakesText1 = p(
    "{RIVAL}: Then I'll take\nthis one!\f...Wait. Was it meant\nfor you, {PLAYER}?",
    "{RIVAL}: Dann nehme ich\ndieses hier!\f...Moment. War es für\ndich gedacht, {PLAYER}?"),
  _OaksLabRivalTakesText2 = p(
    "{RIVAL} eagerly picks\nup the POKéMON!",
    "{RIVAL} nimmt das\nPOKéMON begeistert hoch!"),
  _OaksLabRivalTakesText3 = p(
    "OAK: {RIVAL}!\fThat one was for--",
    "EICH: {RIVAL}!\fDas war doch für..."),
  _OaksLabRivalTakesText4 = p(
    "{RIVAL}: Oh!\fIt was already spoken\nfor?\fSorry!",
    "{RIVAL}: Oh!\fEs war schon für\njemanden bestimmt?\fEntschuldigung!"),
  _OaksLabRivalTakesText5 = p(
    "OAK: Well...\fYou two seem to get\nalong.\fAll right.\nYou may keep it.\f{PLAYER}, come over\nhere.",
    "EICH: Nun...\fIhr zwei scheint euch\ngut zu verstehen.\fAlso gut.\nDu darfst es behalten.\f{PLAYER}, komm bitte\nher."),
  _OaksLabRivalIllTakeYouOnText = p(
    "{RIVAL}: Wait,\n{PLAYER}!\fOur first battle!\nFor research.\fAnd because I intend\nto win!",
    "{RIVAL}: Warte,\n{PLAYER}!\fUnser erster Kampf!\nFür die Forschung.\fUnd weil ich gewinnen\nwill!"),
  _OaksLabRivalLeaveItAllToMeText = p(
    "{RIVAL}: Leave it to\nme, Professor!\fI'll keep good records.\fRace you to a full\nPOKéDEX, {PLAYER}!",
    "{RIVAL}: Überlassen Sie\ndas mir, Professor!\fIch führe genau Buch.\fWer zuerst den POKéDEX\nfüllt, {PLAYER}!"),
  _OaksLabRivalSmellYouLaterText = p(
    "{RIVAL}: Training first.\fNotes later.\fSee if you can keep up,\n{PLAYER}!",
    "{RIVAL}: Erst trainieren.\fDann die Notizen.\fMal sehen, ob du\nmithältst, {PLAYER}!"),
  _OaksLabRivalMyPokemonHasGrownStrongerText = p(
    "{RIVAL}: Professor,\nlook! We got stronger!\fI recorded everything.\fEven where I filed it.",
    "{RIVAL}: Professor,\nsehen Sie! Wir sind stärker!\fIch habe alles notiert.\fSogar, wo ich es\nabgelegt habe."),
  _OaksLabRivalMyPokemonLooksStrongerText = p(
    "{RIVAL}: The numbers\nare up!\fStrength first.\nHeight second.",
    "{RIVAL}: Die Werte sind\ngestiegen!\fErst die Stärke.\nDann die Größe."),
  _OaksLabRivalIPickedTheWrongPokemonText = p(
    "Okay, {PLAYER}--\nyou found the flaw!\fGood thing we tested\nthe plan right away.",
    "Okay, {PLAYER}--\ndu hast den Fehler gefunden!\fGut, dass wir den Plan\ngleich getestet haben."),
  _OaksLabRivalAmIGreatOrWhatText = p(
    "{RIVAL}: That worked!\fI'll write it down\nbefore I improve it.",
    "{RIVAL}: Das hat\nfunktioniert!\fIch schreibe es auf,\nbevor ich es verbessere."),
  _Rival1WinText = p(
    "{RIVAL}: That worked!\fI'll write it down\nbefore I improve it.",
    "{RIVAL}: Das hat\nfunktioniert!\fIch schreibe es auf,\nbevor ich es verbessere."),
  _CeruleanCityRivalPreBattleText = p(
    "{RIVAL}: Hey,\n{PLAYER}!\fI tested a shortcut\nback from BILL's.\fGreat data.\nSoaked shoes.\fAnyway--team check!",
    "{RIVAL}: Hey,\n{PLAYER}!\fAuf dem Rückweg von BILL\nnahm ich eine Abkürzung.\fGute Daten.\nNasse Schuhe.\fEgal--Teamtest!"),
  _CeruleanCityRivalDefeatedText = p(
    "You win!\fMy plan was sound.\nYou were better.",
    "Du gewinnst!\fMein Plan war gut.\nDu warst besser."),
  _CeruleanCityRivalIWentToBillsText = p(
    "{RIVAL}: BILL showed me\nrare POKéMON!\fI asked twelve\nquestions.\fHe answered eleven.\fGo see for yourself!",
    "{RIVAL}: BILL zeigte mir\nseltene POKéMON!\fIch stellte zwölf\nFragen.\fElf davon beantwortete er.\fSieh es dir selbst an!"),
  _PokemonTower2FRivalWhatBringsYouHereText = p(
    "{RIVAL}: Hey,\n{PLAYER}.\fI came to pay my\nrespects too.\fIt's quiet here.\fLet's keep our battle\nthat way.",
    "{RIVAL}: Hey,\n{PLAYER}.\fIch bin auch hier, um\nAbschied zu nehmen.\fEs ist still hier.\fKämpfen wir genauso\nruhig."),
  _PokemonTower2FRivalDefeatedText = p(
    "You got me.\fStay close to your\nPOKéMON in here.",
    "Du hast gewonnen.\fBleib hier nah bei\ndeinen POKéMON."),
  _PokemonTower2FRivalVictoryText = p(
    "{RIVAL}: I won.\fNow let's both take\ncare of our teams.",
    "{RIVAL}: Ich habe\ngewonnen.\fJetzt kümmern wir uns\num unsere Teams."),
  _Route22RivalBeforeBattleText1 = p(
    "{RIVAL}: No BADGEs,\nno entry.\fSo we're heading back.\fOne battle first?",
    "{RIVAL}: Keine ORDEN,\nkein Zutritt.\fAlso gehen wir zurück.\fVorher noch ein Kampf?"),
  _Route22Rival1DefeatedText = p(
    "You got me!\fThat plan needs\none more note.",
    "Du hast mich!\fIn meinem Plan fehlt\nwohl noch eine Notiz."),
  _Route22Rival1VictoryText = p(
    "{RIVAL}: Meet more\nPOKéMON!\fOr get to know your\nteam better.",
    "{RIVAL}: Lerne mehr\nPOKéMON kennen!\fOder dein eigenes Team\nnoch besser."),
  _Route22RivalAfterBattleText1 = p(
    "{RIVAL}: The LEAGUE has\nstrong Trainers!\fI'll earn the BADGEs.\nYou build your team.\fRace you back here!",
    "{RIVAL}: In der LIGA\nwarten starke Trainer!\fIch hole mir die ORDEN.\nDu baust dein Team aus.\fWer zuerst wieder\nhier ist!"),
  _Route22RivalBeforeBattleText2 = p(
    "{RIVAL}: All BADGEs?\fMe too.\nI counted twice.\fOne warm-up before\nthe LEAGUE?",
    "{RIVAL}: Alle ORDEN?\fIch auch.\nZweimal gezählt.\fEin Aufwärmkampf vor\nder LIGA?"),
  _Route22Rival2VictoryText = p(
    "{RIVAL}: That was close!\fFor you, I mean.\fSee you at the top!",
    "{RIVAL}: Knapp war's!\fFür dich, meine ich.\fWir sehen uns oben!"),
  _Route22Rival2DefeatedText = p(
    "You got me!\fMy plan worked.\nYours worked better.",
    "Du hast mich!\fMein Plan war gut.\nDeiner war besser."),
  _Route22RivalAfterBattleText2 = p(
    "{RIVAL}: That was close!\fThe LEAGUE is next.\fI've got three plans.\fLet's see which one\nwins the crown!",
    "{RIVAL}: Das war knapp!\fAls Nächstes die LIGA.\fIch habe drei Pläne.\fMal sehen, welcher\ndie Krone holt!"),
  _SSAnne2FRivalText = p(
    "{RIVAL}: Bonjour,\n{PLAYER}!\fI practiced my French\nall morning.\fSo far, nobody\ncorrected me.\fHow is your POKéDEX?",
    "{RIVAL}: Bonjour,\n{PLAYER}!\fIch übte den ganzen\nMorgen mein Französisch.\fBislang hat mich\nniemand korrigiert.\fWie weit ist dein\nPOKéDEX?"),
  _SSAnne2FRivalDefeatedText = p(
    "You got me!\fI'm steadier on\nsolid ground.",
    "Du hast gewonnen!\fAn Land stehe ich\nfester."),
  _SSAnne2FRivalCutMasterText = p(
    "{RIVAL}: The captain\nknows CUT.\fHe looks seasick.\nBetter knock first.",
    "{RIVAL}: Der Kapitän\nkennt ZERSCHNEIDER.\fEr wirkt seekrank.\nKlopf besser erst an."),
  _SilphCo7FRivalText = p(
    "{RIVAL}: Finally,\n{PLAYER}!\fI mean--\nperfect timing.",
    "{RIVAL}: Endlich,\n{PLAYER}!\fIch meine--\nperfektes Timing."),
  _SilphCo7FRivalWaitedHereText = p(
    "{RIVAL}: I knew you'd\ncome!\fTEAM ROCKET is\nahead.\fShow me you're ready\nbefore you go on!",
    "{RIVAL}: Ich wusste,\ndass du kommst!\fTEAM ROCKET ist\nvoraus.\fZeig mir vorher, dass\ndu bereit bist!"),
  _SilphCo7FRivalDefeatedText = p(
    "You win!\fTEAM ROCKET is ahead.\fFollow the noise--\nthey're hard to miss.",
    "Du gewinnst!\fTEAM ROCKET ist weiter\nvorn.\fFolge dem Lärm--\nsie sind nicht zu überhören."),
  _SilphCo7FRivalVictoryText = p(
    "{RIVAL}: Not yet!\fI checked my plan\nthree times.\fThis version works.",
    "{RIVAL}: Noch nicht!\fIch habe meinen Plan\ndreimal geprüft.\fDiese Version\nfunktioniert."),
  _ChampionsRoomRivalIntroText = p(
    "{RIVAL}: There you are,\n{PLAYER}!\fI built KANTO's\nbest team.\fWe both made it here.\fNow I'm the LEAGUE\nchampion!\fLet's make this a battle\nworth remembering!",
    "{RIVAL}: Da bist du,\n{PLAYER}!\fIch habe KANTOs\nbestes Team aufgebaut.\fWir haben es beide\nbis hierher geschafft.\fJetzt bin ich\nLIGA-Meisterin!\fDiesen Kampf werden wir\nnicht vergessen!"),
  _RivalDefeatedText = p(
    "You got me!\fThe crown suits you.\fBut it looks better\non me!",
    "Du hast mich!\fDie Krone steht dir.\fAber mir steht sie\nbesser!"),
  _RivalVictoryText = p(
    "I won!\fNot quite, {PLAYER}.\fBut that was really\nclose!",
    "Ich habe gewonnen!\fLeider reicht es nicht,\n{PLAYER}.\fAber das war wirklich\nknapp!"),
}

return {
  selection = {
    GREEN = {
      label = p("GREEN", "GRÜN"),
      relation = p("A GIRL FROM\nPALLET TOWN",
        "EIN MÄDCHEN AUS\nALABASTIA"),
    },
    BLUE = {
      label = p("BLUE", "BLAU"),
      relation = p("MY GRANDSON", "MEIN ENKEL"),
    },
    RED = {
      label = p("RED", "ROT"),
      relation = p("A BOY FROM\nPALLET TOWN",
        "EIN JUNGE AUS\nALABASTIA"),
    },
  },

  introAsk = {
    BLUE = p(
      "This is my grand-\nson.\fHe's quick, proud,\nand very capable.\f...What was his\nname again?",
      "Das ist mein\nEnkel.\fEr ist schnell, stolz\nund sehr begabt.\f...Wie hieß er\nnoch gleich?"),
    GREEN = p(
      "This girl is from\nPALLET TOWN.\fShe's clever, curious,\nand always has a plan.\fUsually more than one.\f...What was her\nname again?",
      "Dieses Mädchen kommt\naus ALABASTIA.\fSie ist klug, neugierig\nund hat immer einen Plan.\fMeist sogar mehrere.\f...Wie hieß sie\nnoch gleich?"),
    RED = p(
      "This boy is from\nPALLET TOWN.\fHe speaks little,\nnotices everything,\fand trusts his skill.\f...What was his\nname again?",
      "Dieser Junge kommt\naus ALABASTIA.\fEr redet wenig,\nbemerkt aber alles\fund kennt sein Können.\f...Wie hieß er\nnoch gleich?"),
  },
  introConfirm = {
    BLUE = p(
      "That's right! His\nname is {RIVAL}!",
      "Natürlich! Er\nheißt {RIVAL}!"),
    GREEN = p(
      "Of course! Her\nname is {RIVAL}!",
      "Genau! Sie heißt\n{RIVAL}!"),
    RED = p(
      "Right! {RIVAL}!\fA trainer from\nPALLET TOWN.",
      "Richtig! {RIVAL}!\fEin Trainer aus\nALABASTIA."),
  },
  motherGreen = p(
    "MOM: Right.\nEveryone starts\vtheir own journey\vsomeday.\fPROF. OAK next\ndoor is looking\vfor you.",
    "MUTTER: Stimmt.\nIrgendwann beginnt\vjeder sein eigenes\vAbenteuer.\fPROF. EICH von\nnebenan sucht dich."),
  oakFamilyHouse = p(
    "OAK FAMILY HOUSE",
    "HAUS DER FAMILIE\nEICH"),
  daisyRedAtLab = p(
    "Hi {PLAYER}!\n{RIVAL} is at\vPROF. OAK's lab.",
    "Hallo {PLAYER}!\n{RIVAL} ist im\vLabor von PROF.\nEICH."),
  lanceGreen = p(
    "One challenge\nremains.\fHer name is...\n{RIVAL}!\fShe took a different\nroute and reached\nthe ELITE FOUR\nbefore you!\fShe is the new\nLEAGUE champion!",
    "Eine Herausforderung\nbleibt noch.\fIhr Name ist...\n{RIVAL}!\fSie nahm einen anderen\nWeg und erreichte die\nTOP VIER vor dir!\fSie ist die neue\nLIGA-Meisterin!"),

  rival = {
    RED = red,
    GREEN = green,
  },
}
