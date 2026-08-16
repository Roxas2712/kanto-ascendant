-- Character-specific writing for the Hall-of-Fame expansion.  Every value
-- carries both languages so LANGUAGE can change at runtime without reloading
-- the mod.  The first clear adds Oak's story bridge into the Hall of Fame;
-- the remaining rows give the APEX and CROWN circuits their own dialogue.

local function text(english, german)
  return { en = english, de = german }
end

local function rest(oneEn, manyEn, oneDe, manyDe)
  return {
    one = text(oneEn, oneDe),
    many = text(manyEn, manyDe),
  }
end

return {
  story = {
    oakLegendEvent = text(
      "OAK: {PLAYER}!\fThe bond with your\nPOKéMON made this\nvictory possible.\fListen closely.\fReports of\nlegendary POKéMON\ngrow across Kanto.\fShadows cross the\nsky. Storms rage.\fBeasts roam afar.\fThey stay hidden,\nbut their power is\nstirring.\fYour journey is\nfar from over.\fAfter this first\nHALL OF FAME, use\nmy LAB PC.\fIt explains a\nseparate LEGACY\nJOURNEY.\fFirst complete your\nown fissure path and\nanswer its final\nblack door.\fThe HALL alone never\nunlocks a new cycle.\fNothing resets this\nlife by itself.\fCome with me!\nThe HALL OF FAME\nis waiting!",
      "EICH: {PLAYER}!\fDie Verbindung zu\ndeinen POKéMON hat\nzum Sieg geführt.\fDoch höre gut zu.\fImmer häufiger\nwerden legendäre\nPOKéMON gesichtet.\fSchatten kreuzen\nden Himmel. Stürme\nziehen auf.\fFerne Bestien\nziehen durch Kanto.\fSie bleiben fern,\ndoch ihre Kraft\nregt sich.\fDeine Reise ist\nnoch lange nicht\nvorbei.\fNach dieser ersten\nRUHMESHALLE nutze\nden LABOR-PC.\fEr erklärt eine\neigene\nVERMÄCHTNIS-REISE.\fVollende zuerst\ndeinen eigenen\nRisspfad und antworte\nan seiner letzten\nschwarzen Tür.\fDie RUHMESHALLE\nallein öffnet keinen\nneuen Zyklus.\fNichts setzt diesen\nLauf selbst zurück.\fFolge mir!\nDie RUHMESHALLE\nwartet!"),
    oakNoLegendEvent = text(
      "OAK: {PLAYER}!\fThe bond with your\nPOKéMON made this\nvictory possible.\fListen closely.\fKanto is changing.\nTrainers all over\ngrow stronger.\fYour journey is\nfar from over.\fAfter this first\nHALL OF FAME, use\nmy LAB PC.\fIt explains a\nseparate LEGACY\nJOURNEY.\fFirst complete your\nown fissure path and\nanswer its final\nblack door.\fThe HALL alone never\nunlocks a new cycle.\fNothing resets this\nlife by itself.\fCome with me!\nThe HALL OF FAME\nis waiting!",
      "EICH: {PLAYER}!\fDie Verbindung zu\ndeinen POKÉMON hat\nzum Sieg geführt.\fDoch höre gut zu.\fKanto ändert sich.\nÜberall werden die\nTrainer stärker.\fDeine Reise ist\nnoch lange nicht\nvorbei.\fNach dieser ersten\nRUHMESHALLE nutze\nden LABOR-PC.\fEr erklärt eine\neigene\nVERMÄCHTNIS-REISE.\fVollende zuerst\ndeinen eigenen\nRisspfad und antworte\nan seiner letzten\nschwarzen Tür.\fDie RUHMESHALLE\nallein öffnet keinen\nneuen Zyklus.\fNichts setzt diesen\nLauf selbst zurück.\fFolge mir!\nDie RUHMESHALLE\nwartet!"),
  },
  gyms = {
    brock = {
      master = {
        intro = text(
          "That first badge was\nonly the beginning.\fMy rocks endured\nand grew harder.\fWill your resolve\ndo the same?",
          "Der erste Orden war\nnur der Anfang.\fMeine Felsen hielten\nstand und wurden\nhärter.\fHält dein Wille\ngenauso stand?"),
        decline = text(
          "A sound choice.\fA mountain is\nclimbed only when\nyou are ready.",
          "Eine kluge Wahl.\fEinen Berg besteigt\nman erst, wenn man\nbereit ist."),
        rest = rest(
          "Even stone needs\ntime to harden.\fReturn in 1 step.",
          "Even stone needs\ntime to harden.\fReturn in %d steps.",
          "Auch Stein muss\nwieder aushärten.\fKomm in 1 Schritt\nzurück.",
          "Auch Stein muss\nwieder aushärten.\fKomm in %d Schritten\nzurück."),
        win = text(
          "Even mountains can\nbe overcome.\fYou earned my\nMASTER crest.",
          "Selbst Berge lassen\nsich bezwingen.\fDu verdienst mein\nMEISTER-Wappen."),
      },
      crown = {
        intro = text(
          "Stone remembers\nevery blow.\fAt LEVEL 100, my\nteam will not crack.\fWill you?",
          "Stein erinnert sich\nan jeden Schlag.\fAuf LEVEL 100\nbricht mein Team\nnicht.\fUnd du?"),
        decline = text(
          "Then the summit\nremains above you.\fCome back stronger.",
          "Dann bleibt der\nGipfel über dir.\fKehre stärker\nzurück."),
        rest = rest(
          "The mountain is\nrebuilding.\fReturn in 1 step.",
          "The mountain is\nrebuilding.\fReturn in %d steps.",
          "Der Berg formt sich\nneu.\fKomm in 1 Schritt\nzurück.",
          "Der Berg formt sich\nneu.\fKomm in %d Schritten\nzurück."),
        win = text(
          "You broke the\nunbreakable.\fThe CROWN victory\nis yours.",
          "Du hast das\nUnbrechbare\ngebrochen.\fDer KRONEN-Sieg\ngehört dir."),
      },
      apexGate = text(
        "Eight masters have\nfallen.\fNow climb higher.\nThe APEX ELITE\nwait at INDIGO.",
        "Acht Meister sind\nbezwungen.\fSteig nun höher.\nDie APEX-LIGA\nwartet am INDIGO."),
      legendGate = text(
        "The oldest stones\nare trembling.\fLUGIA and HO-OH\nhave awakened.",
        "Die ältesten Steine\nbeben.\fLUGIA und HO-OH\nsind erwacht."),
    },

    misty = {
      master = {
        intro = text(
          "You once caught me\nin shallow water.\fNow the current is\nmuch stronger.\fReady to dive in?",
          "Damals trafst du\nmich im flachen\nWasser.\fJetzt ist die\nStrömung stärker.\fTauchst du ein?"),
        decline = text(
          "Cold feet already?\fCome back when you\ncan handle the tide.",
          "Schon kalte Füße?\fKomm wieder, wenn\ndu die Flut\nbezwingen kannst."),
        rest = rest(
          "The tide turns in\n1 more step.",
          "The tide turns in\n%d more steps.",
          "Die Flut kehrt in\n1 Schritt zurück.",
          "Die Flut kehrt in\n%d Schritten zurück."),
        win = text(
          "You read every\ncurrent perfectly.\fTake my MASTER\ncrest.",
          "Du hast jede\nStrömung gelesen.\fNimm mein\nMEISTER-Wappen."),
      },
      crown = {
        intro = text(
          "SUICUNE has stilled\nthe raging sea.\fNow my whole team\nstands at LEVEL 100.\fCan you make waves?",
          "SUICUNE besänftigt\ndas tobende Meer.\fNun steht mein Team\nauf LEVEL 100.\fMachst du noch\nWellen?"),
        introNoLegend = text(
          "No legend will calm\nthis raging sea.\fMy own LEVEL 100\nteam commands it.\fCan you make waves?",
          "Keine Legende zähmt\ndieses tobende Meer.\fMein LEVEL-100-Team\nbeherrscht es selbst.\fMachst du noch\nWellen?"),
        decline = text(
          "Too deep for you?\fThe water will be\nwaiting.",
          "Zu tief für dich?\fDas Wasser wird\nauf dich warten."),
        rest = rest(
          "The sea needs\n1 step to settle.",
          "The sea needs\n%d steps to settle.",
          "Das Meer braucht\n1 Schritt zur Ruhe.",
          "Das Meer braucht\n%d Schritte zur Ruhe."),
        win = text(
          "Not even the\nperfect tide could\nsweep you away.\fYou claim the CROWN.",
          "Nicht einmal die\nperfekte Flut riss\ndich fort.\fDie KRONE gehört\ndir."),
      },
      apexGate = text(
        "You beat every\nMASTER Leader!\fDon't slow down.\nINDIGO is next.",
        "Du hast alle\nMEISTER besiegt!\fJetzt nicht bremsen.\nINDIGO wartet."),
      legendGate = text(
        "Something ancient\nmoves below the sea.\fFind LUGIA... and the\nfire in the sky.",
        "Etwas Uraltes regt\nsich tief im Meer.\fFinde LUGIA... und das\nFeuer am Himmel."),
    },

    surge = {
      master = {
        intro = text(
          "Listen up, soldier!\fMy old voltage was\njust a warning shot.\fThis is the real\nshock campaign!",
          "Aufgepasst, Soldat!\fDie alte Spannung\nwar nur ein\nWarnschuss.\fJetzt beginnt die\nechte Offensive!"),
        decline = text(
          "Retreat accepted!\fRecharge your team\nand report back!",
          "Rückzug genehmigt!\fLade dein Team auf\nund melde dich\nwieder!"),
        rest = rest(
          "Recharging complete\nin 1 step!",
          "Recharging complete\nin %d steps!",
          "Aufladung fertig in\n1 Schritt!",
          "Aufladung fertig in\n%d Schritten!"),
        win = text(
          "Direct hit!\fYou powered through\nmy best defense.\fMASTER crest earned!",
          "Volltreffer!\fDu hast meine beste\nAbwehr durchbrochen.\fMEISTER-Wappen\nverdient!"),
      },
      crown = {
        intro = text(
          "RAIKOU brought the\nstorm with it!\fSix LEVEL 100 bolts\nare locked on you.\fStill standing?",
          "RAIKOU brachte den\nSturm mit!\fSechs LEVEL-100-\nBlitze zielen auf\ndich.\fStehst du noch?"),
        introNoLegend = text(
          "No legendary backup,\nsoldier!\fThese six LEVEL 100\nbolts are all mine.\fStill standing?",
          "Keine legendäre\nVerstärkung, Soldat!\fDiese sechs LEVEL-\n100-Blitze sind\nmeine.\fStehst du noch?"),
        decline = text(
          "Smart retreat,\nsoldier!\fNext time, bring a\nlightning rod!",
          "Kluger Rückzug,\nSoldat!\fBring nächstes Mal\neinen Blitzableiter!"),
        rest = rest(
          "The grid is back in\n1 step!",
          "The grid is back in\n%d steps!",
          "Das Netz steht in\n1 Schritt wieder!",
          "Das Netz steht in\n%d Schritten wieder!"),
        win = text(
          "You took the whole\nstorm and marched\nthrough it!\fCROWN victory!",
          "Du hast den ganzen\nSturm durchquert!\fKRONEN-Sieg,\nSoldat!"),
      },
      apexGate = text(
        "All eight crests!\fYour next mission:\nbreak the APEX\nELITE at INDIGO!",
        "Alle acht Wappen!\fDein nächster\nAuftrag: die APEX-\nLIGA am INDIGO!"),
      legendGate = text(
        "My meters are going\nwild, soldier.\fTwo legendary\nsignals just woke.",
        "Meine Messgeräte\nspielen verrückt!\fZwei legendäre\nSignale sind erwacht."),
    },

    erika = {
      master = {
        intro = text(
          "A garden changes\nwith every season.\fMine has grown wild\nsince we last met.\fShall we begin?",
          "Ein Garten wandelt\nsich mit jeder\nJahreszeit.\fMeiner wuchs seitdem\nungezügelt.\fBeginnen wir?"),
        decline = text(
          "There is no shame in\nwaiting for spring.\fReturn when ready.",
          "Es ist keine Schande,\nauf den Frühling zu\nwarten.\fKehre bereit zurück."),
        rest = rest(
          "A new bloom opens in\n1 step.",
          "A new bloom opens in\n%d steps.",
          "Eine neue Blüte\nöffnet sich in\n1 Schritt.",
          "Eine neue Blüte\nöffnet sich in\n%d Schritten."),
        win = text(
          "Your strength blooms\nbeautifully.\fPlease accept my\nMASTER crest.",
          "Deine Stärke blüht\nwunderschön.\fBitte nimm mein\nMEISTER-Wappen."),
      },
      crown = {
        intro = text(
          "Even CELEBI rests\namong ancient leaves.\fMy LEVEL 100 garden\nhas no weak season.\fWill you enter?",
          "Selbst CELEBI ruht\nzwischen uralten\nBlättern.\fMein LEVEL-100-\nGarten kennt keine\nSchwäche.\fTrittst du ein?"),
        introNoLegend = text(
          "Ancient leaves need\nno guardian.\fMy LEVEL 100 garden\nhas no weak season.\fWill you enter?",
          "Uralte Blätter\nbrauchen keinen\nWächter.\fMein LEVEL-100-\nGarten kennt keine\nSchwäche.\fTrittst du ein?"),
        decline = text(
          "Then let the garden\nsleep a little longer.",
          "Dann darf der Garten\nnoch etwas länger\nschlafen."),
        rest = rest(
          "The garden wakes in\n1 step.",
          "The garden wakes in\n%d steps.",
          "Der Garten erwacht in\n1 Schritt.",
          "Der Garten erwacht in\n%d Schritten."),
        win = text(
          "You crossed a forest\noutside of time.\fThe CROWN blossom\nis yours.",
          "Du durchquertest\neinen Wald jenseits\nder Zeit.\fDie KRONEN-Blüte\ngehört dir."),
      },
      apexGate = text(
        "Eight crests bloom\nin your hands.\fThe APEX ELITE now\nawaits at INDIGO.",
        "Acht Wappen blühen\nin deinen Händen.\fDie APEX-LIGA wartet\nnun am INDIGO."),
      legendGate = text(
        "The wind carries two\nancient voices.\fSeek the sea and the\nsacred sky.",
        "Der Wind trägt zwei\nuralte Stimmen.\fSuche das Meer und\nden heiligen Himmel."),
    },

    koga = {
      master = {
        intro = text(
          "A true ninja never\nreveals the same\ntechnique twice.\fCan you survive what\nyou cannot foresee?",
          "Ein wahrer Ninja\nzeigt keine Technik\nzweimal.\fÜberstehst du, was\ndu nicht vorhersehen\nkannst?"),
        decline = text(
          "Caution is not\ncowardice.\fSharpen your senses\nand return.",
          "Vorsicht ist keine\nFeigheit.\fSchärfe deine Sinne\nund kehre zurück."),
        rest = rest(
          "The antidote needs\n1 step.",
          "The antidote needs\n%d steps.",
          "Das Gegengift braucht\n1 Schritt.",
          "Das Gegengift braucht\n%d Schritte."),
        win = text(
          "You saw through every\nshadow and toxin.\fThe MASTER crest is\nyours.",
          "Du durchschautest\njeden Schatten und\njedes Gift.\fDas MEISTER-Wappen\ngehört dir."),
      },
      crown = {
        intro = text(
          "At LEVEL 100, poison\nneeds only one\nopening.\fI require only one\nmistake from you.",
          "Auf LEVEL 100\nbraucht Gift nur\neine Öffnung.\fMir genügt ein\nFehler von dir."),
        decline = text(
          "You deny me that\nopening today.\fWise.",
          "Heute verweigerst\ndu mir diese\nÖffnung.\fWeise."),
        rest = rest(
          "The shadows reform in\n1 step.",
          "The shadows reform in\n%d steps.",
          "Die Schatten sammeln\nsich in 1 Schritt.",
          "Die Schatten sammeln\nsich in %d Schritten."),
        win = text(
          "No shadow concealed\nyour path.\fYou have earned the\nCROWN victory.",
          "Kein Schatten verbarg\ndeinen Weg.\fDu hast den\nKRONEN-Sieg verdient."),
      },
      apexGate = text(
        "Your eight crests\nform a single path.\fIt leads to the\nAPEX ELITE.",
        "Deine acht Wappen\nformen einen Weg.\fEr führt zur\nAPEX-LIGA."),
      legendGate = text(
        "Two presences hide\nbeyond mortal sight.\fTrack LUGIA and\nHO-OH.",
        "Zwei Wesen verbergen\nsich vor sterblichen\nBlicken.\fSpüre LUGIA und\nHO-OH auf."),
    },

    sabrina = {
      master = {
        intro = text(
          "I saw this moment\nlong ago.\fIn most futures, you\nturn back.\fWhich future did you\nchoose?",
          "Diesen Moment sah\nich vor langer Zeit.\fIn den meisten\nZukünften kehrst du\num.\fWelche wählst du?"),
        decline = text(
          "Yes... this is one of\nthe futures I saw.\fAnother remains.",
          "Ja... diese Zukunft\nhabe ich gesehen.\fEine andere bleibt."),
        rest = rest(
          "Our minds meet again\nin 1 step.",
          "Our minds meet again\nin %d steps.",
          "Unser Geist trifft\nsich in 1 Schritt\nwieder.",
          "Unser Geist trifft\nsich in %d Schritten\nwieder."),
        win = text(
          "You chose the future\nI could not hold.\fTake the MASTER\ncrest.",
          "Du wähltest die\nZukunft, die ich\nnicht halten konnte.\fNimm das\nMEISTER-Wappen."),
      },
      crown = {
        intro = text(
          "Only two futures\nremain.\fIn one, LUGIA and I\nwin.\fShow me the other.",
          "Nur zwei Zukünfte\nbleiben.\fIn einer siegen\nLUGIA und ich.\fZeig mir die andere."),
        introNoLegend = text(
          "Only two futures\nremain.\fIn one, my perfected\nteam wins.\fShow me the other.",
          "Nur zwei Zukünfte\nbleiben.\fIn einer siegt mein\nvollendetes Team.\fZeig mir die andere."),
        decline = text(
          "Then that future must\nwait a little longer.",
          "Dann muss diese\nZukunft noch etwas\nlänger warten."),
        rest = rest(
          "The vision clears in\n1 step.",
          "The vision clears in\n%d steps.",
          "Die Vision klärt sich\nin 1 Schritt.",
          "Die Vision klärt sich\nin %d Schritten."),
        win = text(
          "So that was the\nunseen future...\fThe CROWN victory\nbelongs to you.",
          "Das war also die\nungesehene Zukunft...\fDer KRONEN-Sieg\ngehört dir."),
      },
      apexGate = text(
        "I see four shadows\nand one familiar\nrival at INDIGO.\fThey await you.",
        "Ich sehe vier Schatten\nund einen vertrauten\nRivalen am INDIGO.\fSie erwarten dich."),
      legendGate = text(
        "The future split when\ntwo legends awoke.\fFind LUGIA and HO-OH.",
        "Die Zukunft teilte\nsich, als zwei\nLegenden erwachten.\fFinde LUGIA und\nHO-OH."),
    },

    blaine = {
      master = {
        intro = text(
          "Quiz time!\fWhat burns hotter\nafter defeat?\fAnswer: my entire\nteam! Ready?",
          "Zeit fürs Quiz!\fWas brennt nach\neiner Niederlage\nheißer?\fAntwort: mein ganzes\nTeam! Bereit?"),
        decline = text(
          "Wrong answer!\fGo study, and bring\nsomething fireproof!",
          "Falsche Antwort!\fLerne weiter, und\nbring etwas\nFeuerfestes mit!"),
        rest = rest(
          "The furnace fires in\n1 step!",
          "The furnace fires in\n%d steps!",
          "Der Ofen brennt in\n1 Schritt wieder!",
          "Der Ofen brennt in\n%d Schritten wieder!"),
        win = text(
          "Hah! You stood in the\nfurnace and never\nmelted!\fMASTER crest earned!",
          "Ha! Du standest im\nOfen und bist nicht\ngeschmolzen!\fMEISTER-Wappen\nverdient!"),
      },
      crown = {
        intro = text(
          "ENTEI carries fire\nfrom an older world!\fAt LEVEL 100, this\nis my final quiz:\nCan you take the heat?",
          "ENTEI trägt Feuer\naus einer älteren\nWelt!\fAuf LEVEL 100 ist\ndies mein letztes\nQuiz:\nHältst du die Hitze?"),
        introNoLegend = text(
          "No legendary flame\nneeded!\fAt LEVEL 100, this\nis my final quiz:\nCan you take the heat?",
          "Keine legendäre\nFlamme nötig!\fAuf LEVEL 100 ist\ndies mein letztes\nQuiz:\nHältst du die Hitze?"),
        decline = text(
          "No answer is better\nthan the wrong one!\fCome back prepared.",
          "Keine Antwort ist\nbesser als die\nfalsche!\fKomm vorbereitet\nzurück."),
        rest = rest(
          "The sacred flame\nreturns in 1 step.",
          "The sacred flame\nreturns in %d steps.",
          "Die heilige Flamme\nkehrt in 1 Schritt\nzurück.",
          "Die heilige Flamme\nkehrt in %d Schritten\nzurück."),
        win = text(
          "Correct!\fYour spirit burns\nhotter than legend.\fClaim the CROWN!",
          "Richtig!\fDein Geist brennt\nheißer als Legenden.\fHol dir die KRONE!"),
      },
      apexGate = text(
        "Final quiz!\fWhere does a trainer\nwith eight crests go?\fINDIGO!",
        "Letztes Quiz!\fWohin geht man mit\nacht Wappen?\fZum INDIGO!"),
      legendGate = text(
        "The instruments say\ntwo impossible flames\nburn in Kanto.\fFind their owners!",
        "Die Instrumente zeigen\nzwei unmögliche\nFlammen in Kanto.\fFinde ihre Träger!"),
    },

    giovanni = {
      master = {
        intro = text(
          "Do not mistake my\nreturn for regret.\fTEAM ROCKET is over.\nMy ambition is not.\fFace me as a Trainer.",
          "Verwechsle meine\nRückkehr nicht mit\nReue.\fTEAM ROCKET ist\nvorbei. Mein Ehrgeiz\nnicht.\fStell dich mir."),
        decline = text(
          "So be it.\fPower is patient.\nI can afford to wait.",
          "Wie du willst.\fMacht ist geduldig.\nIch kann warten."),
        rest = rest(
          "My organization needs\n1 step to regroup.",
          "My organization needs\n%d steps to regroup.",
          "Meine Formation\nbraucht 1 Schritt,\num sich zu sammeln.",
          "Meine Formation\nbraucht %d Schritte,\num sich zu sammeln."),
        win = text(
          "Again, you overturn\nall I built.\fThis time, take my\nrespect and the crest.",
          "Erneut stürzt du\nalles, was ich\naufbaute.\fDiesmal erhältst du\nRespekt und Wappen."),
      },
      crown = {
        intro = text(
          "No badge. No Rocket.\fOnly power and our\nunfinished business.\fMy LEVEL 100 empire\nstands before you.",
          "Kein Orden. Kein\nRocket.\fNur Macht und eine\noffene Rechnung.\fMein LEVEL-100-Reich\nsteht vor dir."),
        decline = text(
          "You may leave.\fBut unfinished\nbusiness has a way\nof returning.",
          "Du darfst gehen.\fDoch offene\nRechnungen kehren\nstets zurück."),
        rest = rest(
          "My empire rises again\nin 1 step.",
          "My empire rises again\nin %d steps.",
          "Mein Reich erhebt sich\nin 1 Schritt erneut.",
          "Mein Reich erhebt sich\nin %d Schritten erneut."),
        win = text(
          "So this is power\nbeyond ambition...\fYou have conquered\nthe CROWN circuit.",
          "Das ist also Macht\njenseits des\nEhrgeizes...\fDu hast den KRONEN-\nKreis bezwungen."),
      },
      apexGate = text(
        "You took every crest.\fDo not celebrate yet.\nTrue power waits at\nINDIGO.",
        "Du nahmst jedes\nWappen.\fFeiere noch nicht.\nWahre Macht wartet\nam INDIGO."),
      legendGate = text(
        "Even I cannot command\nthe powers now awake.\fFind LUGIA and HO-OH\nbefore another does.",
        "Selbst ich beherrsche\ndie erwachten Kräfte\nnicht.\fFinde LUGIA und HO-OH,\nbevor es jemand tut."),
    },
  },

  world = {
    ["PALLET_TOWN:PALLETTOWN_FISHER"] = {
      rumor = text(
        "Something huge crossed\nthe sunset.\fIt had wings, but no\nbird casts a shadow\nlike that.",
        "Etwas Riesiges zog\ndurch den Abendhimmel.\fEs hatte Flügel, doch\nkein Vogel wirft so\neinen Schatten."),
      apex = text(
        "The sea went silent\nwhen you won.\fLike the whole horizon\nwas listening.",
        "Als du gewannst,\nwurde das Meer still.\fAls lausche der ganze\nHorizont."),
      hunt = text(
        "A silver shape passed\nfar beyond the bay.\fWhatever it was, it\nwas heading south.",
        "Eine silberne Gestalt\nzog weit hinter der\nBucht vorbei.\fSie flog nach Süden."),
      crown = text(
        "The great shadows no\nlonger frighten us.\fThey know Kanto's\nChampion now.",
        "Die großen Schatten\nmachen uns keine\nAngst mehr.\fSie kennen nun Kantos\nChamp."),
      complete = text(
        "I used to watch the\nsea for adventure.\fNow adventure comes\nhome to PALLET.",
        "Früher suchte ich am\nMeer nach Abenteuern.\fNun kommen sie nach\nALABASTIA."),
    },
    ["VERMILION_CITY:VERMILIONCITY_SAILOR2"] = {
      rumor = text(
        "Every compass in the\nharbor spun at once.\fNo storm chart can\nexplain that.",
        "Jeder Kompass im\nHafen drehte sich.\fKeine Wetterkarte\nerklärt das."),
      apex = text(
        "The currents reversed\nwhen the APEX fell.\fSomething below us\nhas awakened.",
        "Die Strömung drehte\nsich nach dem APEX-\nSieg.\fEtwas unter uns ist\nerwacht."),
      hunt = text(
        "At night we hear a\nsong below the hulls.\fThe old sailors call\nit LUGIA.",
        "Nachts hören wir ein\nLied unter den Rümpfen.\fDie alten Seeleute\nnennen es LUGIA."),
      crown = text(
        "The deep song is calm\nnow.\fYou must have met its\nowner.",
        "Das Lied der Tiefe ist\nnun ruhig.\fDu hast seinen Sänger\nwohl getroffen."),
      complete = text(
        "Any ship would take\nyou as captain.\fEven the sea knows\nyour name.",
        "Jedes Schiff nähme\ndich als Kapitän.\fSelbst das Meer kennt\ndeinen Namen."),
    },
    ["CERULEAN_CITY:CERULEANCITY_SUPER_NERD3"] = {
      rumor = text(
        "My instruments detect\nthought waves north\nof town.\fThat is impossible.",
        "Meine Geräte messen\nGedankenwellen nördlich\nder Stadt.\fDas ist unmöglich."),
      apex = text(
        "The signal from the\ncave just doubled.\fWhatever thinks in\nthere noticed you.",
        "Das Signal aus der\nHöhle hat sich\nverdoppelt.\fEtwas dort bemerkte\ndich."),
      hunt = text(
        "The pattern has a\nname now: MEWTWO.\fPlease do not tell it\nI said that.",
        "Das Muster hat nun\neinen Namen: MEWTU.\fSag ihm bitte nicht,\ndass ich das sagte."),
      crown = text(
        "The psychic pressure\nis gone.\fI can finally sleep\nwithout dreaming.",
        "Der Psycho-Druck ist\nverschwunden.\fEndlich kann ich ohne\nTräume schlafen."),
      complete = text(
        "My next machine will\nmeasure Champions.\fYou broke the scale.",
        "Mein nächstes Gerät\nmisst Champs.\fDu hast die Skala\ngesprengt."),
    },
    ["FUCHSIA_CITY:FUCHSIACITY_ERIK"] = {
      rumor = text(
        "We found three sets\nof tracks overnight.\fNo SAFARI POKéMON\nmade them.",
        "Über Nacht fanden wir\ndrei Arten von Spuren.\fKein SAFARI-POKéMON\nhinterließ sie."),
      apex = text(
        "The three beasts are\ncircling Kanto now.\fThey move faster than\nour patrols.",
        "Drei Bestien ziehen\nnun durch Kanto.\fSie sind schneller als\nunsere Patrouillen."),
      hunt = text(
        "Thunder, flame and\nclear water.\fFollow those signs to\nfind the three.",
        "Donner, Flammen und\nklares Wasser.\fFolge diesen Zeichen\nzu den dreien."),
      crown = text(
        "The strange tracks\nstopped at our gate.\fAlmost like a bow.",
        "Die fremden Spuren\nendeten an unserem Tor.\fFast wie eine\nVerbeugung."),
      complete = text(
        "The SAFARI ZONE wants\na statue of you.\fThe beasts would hate\nstanding still.",
        "Die SAFARI-ZONE will\neine Statue von dir.\fDie Bestien würden\nStillstehen hassen."),
    },
    ["LAVENDER_TOWN:LAVENDERTOWN_SUPER_NERD"] = {
      rumor = text(
        "The tower bell rang\nwith no one inside.\fThen a rainbow crossed\nthe night.",
        "Die Turmglocke erklang,\nobwohl niemand da war.\fDann zog ein Regenbogen\ndurch die Nacht."),
      apex = text(
        "A warm light rests on\nthe tower summit.\fThe spirits call it a\nreturning king.",
        "Warmes Licht liegt auf\nder Turmspitze.\fDie Geister nennen es\neinen heimkehrenden\nKönig."),
      hunt = text(
        "HO-OH waits above the\nclouds.\fThe three roaming\nbeasts are its key.",
        "HO-OH wartet über den\nWolken.\fDie drei wandernden\nBestien sind sein\nSchlüssel."),
      crown = text(
        "The tower spirits are\ncelebrating.\fThat almost never\nhappens.",
        "Die Geister im Turm\nfeiern.\fDas geschieht fast\nnie."),
      complete = text(
        "Even the dead speak\nof your victory.\fThey are very loud.",
        "Selbst die Toten\nsprechen von deinem\nSieg.\fSie sind sehr laut."),
    },
    ["CINNABAR_ISLAND:CINNABARISLAND_GIRL"] = {
      rumor = text(
        "The volcano glowed\nwithout erupting.\fA roar rolled across\nthe water.",
        "Der Vulkan glühte,\nohne auszubrechen.\fEin Brüllen zog über\ndas Wasser."),
      apex = text(
        "Sailors saw fire run\nacross the waves.\fCould a POKéMON move\nlike that?",
        "Seeleute sahen Feuer\nüber die Wellen laufen.\fKann ein POKéMON sich\nso bewegen?"),
      hunt = text(
        "ENTEI leaves no ash,\nonly warm footprints.\fThey point toward the\nmainland.",
        "ENTEI lässt keine\nAsche zurück, nur\nwarme Spuren.\fSie führen zum\nFestland."),
      crown = text(
        "The volcano is quiet\nagain.\fIt feels content, not\nasleep.",
        "Der Vulkan ist wieder\nruhig.\fEr wirkt zufrieden,\nnicht schlafend."),
      complete = text(
        "BLAINE says your fire\nburns brighter than\nours.\fDo not tell him I\nagreed.",
        "PYRO sagt, dein Feuer\nbrenne heller als\nunseres.\fSag ihm nicht, dass ich\nzustimme."),
    },
    ["INDIGO_PLATEAU_LOBBY:INDIGOPLATEAULOBBY_GYM_GUIDE"] = {
      rumor = text(
        "Champion! The Leaders\nare preparing a new\ncircuit.\fKanto is not finished\nwith you yet.",
        "Champ! Die Leiter\nbereiten einen neuen\nKreis vor.\fKanto ist noch nicht\nfertig mit dir."),
      apex = text(
        "Eight MASTER crests!\fThe APEX ELITE is\nready beyond that\ndoor.",
        "Acht MEISTER-Wappen!\fDie APEX-LIGA wartet\nhinter dieser Tür."),
      hunt = text(
        "The League is tracking\nlegendary reports.\fOak's Lab has the\nlatest readings.",
        "Die Liga verfolgt die\nLegenden-Berichte.\fEichs Labor hat die\nneuesten Messungen."),
      crown = text(
        "The CROWN challenge is\nnow official.\fEvery Leader is at\nLEVEL 100.",
        "Die KRONEN-Prüfung ist\nnun offiziell.\fJeder Leiter kämpft\nauf LEVEL 100."),
      complete = text(
        "There is no title left\nabove yours.\fWelcome back, greatest\nChampion.",
        "Es gibt keinen Titel\nmehr über deinem.\fWillkommen, größter\nChamp."),
    },
  },

  legendIntros = {
    ARTICUNO = text(
      "The air crystallizes.\fEvery sound freezes\nbefore reaching you.",
      "Die Luft kristallisiert.\fJeder Laut gefriert,\nbevor er dich erreicht."),
    ZAPDOS = text(
      "The lights die.\fA heartbeat later,\nthunder splits the\nsilence.",
      "Die Lichter erlöschen.\fEinen Herzschlag später\nzerreißt Donner die\nStille."),
    MOLTRES = text(
      "The stone beneath you\nglows red.\fA single feather turns\nthe air to flame.",
      "Der Stein unter dir\nglüht rot.\fEine einzelne Feder\nsetzt die Luft in Brand."),
    MEWTWO = text(
      "Your thoughts fall\nsilent.\fAnother mind has\nentered the room.",
      "Deine Gedanken\nverstummen.\fEin anderer Geist hat\nden Raum betreten."),
    RAIKOU = text(
      "Thunder rolls beneath\na clear sky.\fThe grass bends before\na golden blur.",
      "Donner rollt unter\nklarem Himmel.\fDas Gras weicht einem\ngoldenen Blitz."),
    ENTEI = text(
      "The ground pulses like\na giant heartbeat.\fHeat races along the\nroute.",
      "Der Boden pulsiert wie\nein riesiges Herz.\fHitze jagt über die\nRoute."),
    SUICUNE = text(
      "The wind carries the\nscent of pure water.\fA blue shape glides\nwithout a sound.",
      "Der Wind trägt den Duft\nreinen Wassers.\fEine blaue Gestalt\ngleitet lautlos heran."),
    LUGIA = text(
      "The underground sea\nbecomes perfectly\nstill.\fSomething vast rises\nbeneath it.",
      "Das unterirdische Meer\nwird vollkommen still.\fEtwas Gewaltiges\nsteigt darunter auf."),
    HO_OH = text(
      "Seven colors ignite\nabove the tower.\fThe ancient bell rings\nby itself.",
      "Sieben Farben erglühen\nüber dem Turm.\fDie uralte Glocke\nschlägt von selbst."),
    CELEBI = text(
      "The forest holds its\nbreath.\fFor one impossible\nmoment, time stops.",
      "Der Wald hält den Atem\nan.\fFür einen unmöglichen\nMoment steht die Zeit\nstill."),
  },

  huntRival = {
    before = text(
      "{RIVAL}: So the rumors\nwere true!\fYou already found a\nlegend.\fDo not think you will\nclaim the rest alone.\fI built a team to\ntrack powers like\nthese.\fBeat me, and I will\nshare my readings.\fLegend Hunter battle.\nAccept?",
      "{RIVAL}: Die Gerüchte\nwaren also wahr!\fDu hast schon eine\nLegende gefunden.\fGlaub nicht, dass du\nden Rest allein\nbekommst.\fDieses Team spürt\nsolche Kräfte auf.\fBesiege mich, dann\nteile ich meine Daten.\fLegendenjäger-Kampf.\nAnnehmen?"),
    decline = text(
      "{RIVAL}: Fine.\fThe legends will not\nwait forever.",
      "{RIVAL}: Na schön.\fDie Legenden warten\nnicht ewig."),
    win = text(
      "Again?!\fEven my hunting team\ncould not stop you!",
      "Schon wieder?!\fNicht einmal mein\nJagdteam stoppt dich!"),
    after = text(
      "{RIVAL}: Take the data.\fThe birds answer sky\nand sea. The beasts\nnever stay put.\fThis is still a race,\n{PLAYER}!",
      "{RIVAL}: Nimm die Daten.\fDie Vögel folgen\nHimmel und Meer. Die\nBestien bleiben nie.\fEs ist noch immer ein\nRennen, {PLAYER}!"),
  },

  elite = {
    OPP_LORELEI = {
      map = "LORELEIS_ROOM",
      labels = {
        before = "_LoreleisRoomLoreleiBeforeBattleText",
        win = "_LoreleisRoomLoreleiEndBattleText",
        after = "_LoreleisRoomLoreleiAfterBattleText",
        retreat = "_LoreleisRoomLoreleiDontRunAwayText",
      },
      apex = {
        before = text(
          "Eight masters could\nnot stop you.\fMomentum means\nnothing here.\fI will bring your\nAPEX run to a\nfreezing halt.",
          "Acht Meister konnten\ndich nicht stoppen.\fSchwung bedeutet hier\nnichts.\fIch friere deinen\nAPEX-Lauf ein."),
        win = text(
          "So even perfected\nice can crack...",
          "Selbst vollkommenes\nEis kann also\nbrechen..."),
        after = text(
          "You earned the thaw.\fBRUNO waits beyond.\nHis welcome will not\nbe as cold.",
          "Du hast das Tauwetter\nverdient.\fBRUNO wartet.\nSein Empfang wird\nnicht so kalt."),
        retreat = text(
          "LORELEI: The door is\nfrozen shut.\fForward is the only\nway.",
          "LORELEI: Die Tür ist\nzugefroren.\fNur vorwärts führt\nhinaus."),
      },
      crown = {
        before = text(
          "ARTICUNO rules the\nfrozen sky.\fNow its cold joins\nmine at LEVEL 100.\fLet us freeze even\na champion's fire.",
          "ARKTOS beherrscht den\ngefrorenen Himmel.\fNun vereint sich\nseine Kälte mit\nmeiner auf LEVEL 100.\fAuch Champ-Feuer\nkann gefrieren."),
        beforeNoLegend = text(
          "I need no legend to\ncommand winter.\fMy own LEVEL 100\nteam has perfected\nabsolute cold.",
          "Ich brauche keine\nLegende, um den\nWinter zu beherrschen.\fMein LEVEL-100-Team\nvollendet die Kälte."),
        win = text(
          "Absolute zero...\nand still you moved.",
          "Absoluter Nullpunkt...\nund du bewegtest\ndich dennoch."),
        after = text(
          "The first CROWN seal\nis broken.\fDo not expect BRUNO\nto yield so cleanly.",
          "Das erste KRONEN-\nSiegel ist gebrochen.\fErwarte nicht, dass\nBRUNO so leicht\nnachgibt."),
        retreat = text(
          "LORELEI: A CROWN\nchallenger does not\nretreat from winter.",
          "LORELEI: Wer um die\nKRONE kämpft, flieht\nnicht vor dem Winter."),
      },
    },

    OPP_BRUNO = {
      map = "BRUNOS_ROOM",
      labels = {
        before = "_BrunoBeforeBattleText",
        win = "_BrunoEndBattleText",
        after = "_BrunoAfterBattleText",
        retreat = "_BrunosRoomBrunoDontRunAwayText",
      },
      apex = {
        before = text(
          "HOO HAH!\fStrength is not a\nlevel. It is every\ntime you rose again.\fShow me how often\nyou can rise!",
          "HUAH!\fStärke ist kein\nLevel. Sie zeigt sich\njedes Mal, wenn man\nwieder aufsteht.\fSteh gegen mich!"),
        win = text(
          "Your will struck\nharder than muscle!",
          "Dein Wille schlug\nhärter als Muskeln!"),
        after = text(
          "Excellent!\fBut AGATHA attacks\nthe mind, not the\nbody. Stay focused.",
          "Ausgezeichnet!\fDoch AGATHA greift\nden Geist an, nicht\nden Körper.\fBleib wachsam."),
        retreat = text(
          "BRUNO: Face the path\nyou chose! HOO HAH!",
          "BRUNO: Stell dich\ndeinem gewählten Weg!\nHUAH!"),
      },
      crown = {
        before = text(
          "At LEVEL 100, there\nis no room left for\nexcuses.\fOnly discipline.\nOnly impact.\fHOO HAH!",
          "Auf LEVEL 100 bleibt\nkein Platz für\nAusreden.\fNur Disziplin.\nNur Wucht.\fHUAH!"),
        win = text(
          "You shattered the\nlimit itself!",
          "Du hast die Grenze\nselbst zerschmettert!"),
        after = text(
          "My body is beaten.\nMy spirit is proud.\fAGATHA guards the\nnext CROWN seal.",
          "Mein Körper ist\nbesiegt. Mein Geist\nist stolz.\fAGATHA bewacht das\nnächste Siegel."),
        retreat = text(
          "BRUNO: The summit is\nahead, never behind!",
          "BRUNO: Der Gipfel\nliegt vorn, niemals\nhinter dir!"),
      },
    },

    OPP_AGATHA = {
      map = "AGATHAS_ROOM",
      labels = {
        before = "_AgathaBeforeBattleText",
        win = "_AgathaEndBattleText",
        after = "_AgathaAfterBattleText",
        retreat = "_AgathasRoomAgathaDontRunAwayText",
      },
      apex = {
        before = text(
          "Heheheh...\fBadges, crests,\nperfect little teams.\fNone of them matter\nwhen fear gets inside\nyour head, child.",
          "Heheheh...\fOrden, Wappen,\nperfekte kleine Teams.\fNichts davon zählt,\nwenn Angst in deinen\nKopf kriecht, Kind."),
        win = text(
          "Hah! Even my ghosts\ncould not haunt you!",
          "Ha! Nicht einmal\nmeine Geister konnten\ndich heimsuchen!"),
        after = text(
          "Run along, child.\fLANCE is eager to\nturn your courage\ninto dragon food.",
          "Lauf weiter, Kind.\fLANCE will deinen\nMut zu Drachenfutter\nmachen."),
        retreat = text(
          "AGATHA: Heheheh!\nSomething behind you\nwants you to stay.",
          "AGATHA: Heheheh!\nEtwas hinter dir\nmöchte, dass du\nbleibst."),
      },
      crown = {
        before = text(
          "At the summit, even\nchampions cast long\nshadows.\fMine have waited a\nvery long time for\nyours.",
          "Auf dem Gipfel werfen\nselbst Champs lange\nSchatten.\fMeine warten schon\nsehr lange auf\ndeinen."),
        win = text(
          "So bright...\nyou erased every\nshadow.",
          "So hell...\ndu hast jeden\nSchatten ausgelöscht."),
        after = text(
          "Three seals gone.\fNow face LANCE and\nthe dragons that\nrule his sky.",
          "Drei Siegel sind fort.\fNun stell dich LANCE\nund den Drachen,\ndie seinen Himmel\nbeherrschen."),
        retreat = text(
          "AGATHA: Turn back and\nthe shadows win.",
          "AGATHA: Kehr um, und\ndie Schatten siegen."),
      },
    },

    OPP_LANCE = {
      map = "LANCES_ROOM",
      labels = {
        before = "_LancesRoomLanceBeforeBattleText",
        win = "_LancesRoomLanceEndBattleText",
        after = "_LancesRoomLanceAfterBattleText",
      },
      apex = {
        before = text(
          "You broke ice, power\nand shadow.\fNow face the sky.\fMy dragons are the\nAPEX of Kanto, and\nI am their master.",
          "Du brachst Eis, Kraft\nund Schatten.\fNun stell dich dem\nHimmel.\fMeine Drachen sind\nKantos APEX, und ich\nihre Meister."),
        win = text(
          "Your strength soars\nabove my dragons!",
          "Deine Stärke steigt\nüber meine Drachen!"),
        after = text(
          "You conquered the\nAPEX ELITE.\fBut one Trainer still\nstands above us.\fYour rival awaits.",
          "Du hast die APEX-LIGA\nbezwungen.\fDoch ein Trainer steht\nnoch über uns.\fDein Rivale wartet."),
      },
      crown = {
        before = text(
          "You awakened the two\nsovereigns of the\nsky.\fThey chose the Champion.\fMy LEVEL 100 dragons\nwill answer them!",
          "Du hast die beiden\nHerrscher des Himmels\nerweckt.\fSie wählten den Champ.\fMeine LEVEL-100-\nDrachen antworten!"),
        beforeNoLegend = text(
          "No legend stands\nbeside me today.\fGood.\fMy LEVEL 100 dragons\nwill prove the sky\nwas always theirs!",
          "Heute steht keine\nLegende an meiner\nSeite.\fGut.\fMeine LEVEL-100-\nDrachen beweisen,\ndass der Himmel ihnen\ngehört!"),
        win = text(
          "You command a sky\nno legend can rule!",
          "Du beherrschst einen\nHimmel, den keine\nLegende regiert!"),
        after = text(
          "The four CROWN seals\nare gone.\fBeyond this door waits\na team made only for\nthe greatest Champion.",
          "Die vier KRONEN-\nSiegel sind fort.\fHinter dieser Tür\nwartet ein Team für\nden größten Champ."),
      },
    },

    OPP_RIVAL3 = {
      map = "CHAMPIONS_ROOM",
      labels = {
        before = "_ChampionsRoomRivalIntroText",
        after = "_ChampionsRoomRivalAfterBattleText",
      },
      apex = {
        before = text(
          "{RIVAL}: Took you long\nenough, {PLAYER}!\fYou beat eight masters\nand the ELITE FOUR.\fGood. I built this\nteam to beat the\nTrainer who did.\fThe APEX title is\nmine until you take it!",
          "{RIVAL}: Wurde auch\nZeit, {PLAYER}!\fDu hast acht Meister\nund die TOP VIER\nbesiegt.\fGut. Dieses Team soll\ngenau den Trainer\nschlagen, der das\nschaffte.\fHol dir den APEX-Titel!"),
        win = text(
          "No way!\fYou surpassed the\nteam built to stop\nyou!",
          "Unmöglich!\fDu hast das Team\nübertroffen, das dich\nstoppen sollte!"),
        after = text(
          "{RIVAL}: So you're the\nAPEX Champion now.\fEnjoy it.\fSomewhere out there,\nreal legends just\nnoticed your victory.",
          "{RIVAL}: Jetzt bist du\nalso APEX-Champ.\fGenieß es.\fIrgendwo da draußen\nhaben echte Legenden\ndeinen Sieg bemerkt."),
      },
      crown = {
        before = text(
          "{RIVAL}: You caught the\nlegends. Impressive.\fBut power doesn't\nbelong to whoever\nfinds it first.\fThis is the strongest\nteam ever assembled.\fLet's settle who truly\nwears the CROWN!",
          "{RIVAL}: Du hast die\nLegenden gefangen.\nNicht schlecht.\fDoch Macht gehört\nnicht dem, der sie\nzuerst findet.\fDies ist das stärkste\nTeam aller Zeiten.\fKlären wir, wer die\nKRONE wirklich trägt!"),
        beforeNoLegend = text(
          "{RIVAL}: So you changed\nthe rules on legends?\fFine by me!\fI built the strongest\nteam still allowed.\fLet's settle who truly\nwears the CROWN!",
          "{RIVAL}: Du hast die\nRegeln für Legenden\ngeändert?\fMir recht!\fIch baute das stärkste\nnoch erlaubte Team.\fKlären wir, wer die\nKRONE wirklich trägt!"),
        win = text(
          "Again?!\fYou beat legends,\nmasters... everything!",
          "Schon wieder?!\fDu besiegst Legenden,\nMeister... einfach alles!"),
        after = text(
          "{RIVAL}: Fine. No more\nexcuses.\fYou're not just Kanto's\nChampion.\fYou're the Trainer\neven legends could\nnot surpass.",
          "{RIVAL}: Gut. Keine\nAusreden mehr.\fDu bist nicht nur\nKantos Champ.\fDu bist der Trainer,\nden selbst Legenden\nnicht übertreffen."),
      },
    },
  },
}
