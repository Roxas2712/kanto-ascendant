-- Kanto Ascendant 6.7: authored work for two independent companion journeys.
--
-- Rows are role-based.  Runtime resolves the active Red/Blue/Green matrix and
-- freezes actor, text, activity and battle data before an NPC becomes visible.
return {
  schemaVersion = 1,
  personaLeads = {
    RED = {
      training = {
        en = "RED: Quiet training.\nTeam ready.",
        de = "RED: Wir trainieren noch.\nMein Team ist bereit.",
      },
      research = {
        en = "RED: I watched first.\nMy team noticed more.",
        de = "RED: Ich sah erst mal zu.\nMein Team bemerkte mehr.",
      },
      supplies = {
        en = "RED: Every item checked.\nNothing missing.",
        de = "RED: Alles ist geprüft.\nUns fehlt nichts.",
      },
      route = {
        en = "RED: We chose together.\nMy team sets the pace.",
        de = "RED: Wir wählten zusammen.\nMein Team gibt das Tempo.",
      },
      care = {
        en = "RED: Team comes first.\nThe road can wait.",
        de = "RED: Mein Team geht vor.\nDer Weg kann warten.",
      },
      travel = {
        en = "RED: We used the wait.\nNo time wasted.",
        de = "RED: Wir nutzen die Pause.\nKein Schritt war umsonst.",
      },
      heat = {
        en = "RED: We kept our rhythm.\nEven in this heat.",
        de = "RED: Unser Rhythmus hält.\nAuch bei dieser Hitze.",
      },
      league = {
        en = "RED: We're ready.\nMy team knows the way.",
        de = "RED: Wir sind vorbereitet.\nMein Team kennt den Weg.",
      },
      future = {
        en = "RED: Our next path is set.\nThis journey is ours.",
        de = "RED: Das Ziel steht.\nDiese Reise gehört uns.",
      },
    },
    BLUE = {
      training = {
        en = "BLUE: New record.\nTeam made it look easy.",
        de = "BLUE: Rekord geknackt!\nMein Team war spitze.",
      },
      research = {
        en = "BLUE: I checked it all.\nOf course I was right.",
        de = "BLUE: Ich hab nachgesehen.\nNatürlich hatte ich recht.",
      },
      supplies = {
        en = "BLUE: Best gear in Kanto.\nReady for three towns.",
        de = "BLUE: Nur das Beste!\nDrei Städte schaff ich.",
      },
      route = {
        en = "BLUE: I know the fast way.\nTry to keep up.",
        de = "BLUE: Ich kenne den Weg.\nVersuch mitzuhalten.",
      },
      care = {
        en = "BLUE: Champs rest smart.\nThen win again.",
        de = "BLUE: Champs ruhen auch.\nDanach gewinnen sie.",
      },
      travel = {
        en = "BLUE: A late ship?\nFine. We trained anyway.",
        de = "BLUE: Das Schiff ist spät?\nGut. Dann trainieren wir.",
      },
      heat = {
        en = "BLUE: Cinnabar tested us.\nIt lost.",
        de = "BLUE: Zinnober war hart.\nWir waren besser.",
      },
      league = {
        en = "BLUE: This road knows me.\nMy team knows it better.",
        de = "BLUE: Ich kenne den Weg.\nMein Team kennt ihn gut.",
      },
      future = {
        en = "BLUE: My next goal is set.\nYou'll hear when I win.",
        de = "BLUE: Das Ziel steht.\nMein Sieg sagt alles.",
      },
    },
    GREEN = {
      training = {
        en = "GREEN: Try number nine!\nThis time I'm ready.",
        de = "GREEN: Neunter Versuch!\nDiesmal bin ich bereit.",
      },
      research = {
        en = "GREEN: Field notes ready!\nBackup pencil too.",
        de = "GREEN: Notizen? Fertig!\nErsatzstift? Auch da!",
      },
      supplies = {
        en = "GREEN: My bag is packed!\nOne berry left over.",
        de = "GREEN: Alles eingepackt!\nEine Beere ist noch übrig.",
      },
      route = {
        en = "GREEN: Route is planned!\nA scenic detour too.",
        de = "GREEN: Der Plan steht.\nDer Umweg lohnt sich.",
      },
      care = {
        en = "GREEN: My team is ready!\nThe hugs helped.",
        de = "GREEN: Mein Team ist fit.\nJetzt können wir weiter.",
      },
      travel = {
        en = "GREEN: We had to wait.\nSo we trained.",
        de = "GREEN: Wir mussten warten.\nAlso haben wir trainiert.",
      },
      heat = {
        en = "GREEN: It's really hot!\nMy team can handle it.",
        de = "GREEN: Ganz schön heiß.\nMein Team hält durch.",
      },
      league = {
        en = "GREEN: League notes ready!\nTime to try them out.",
        de = "GREEN: Liganotizen fertig.\nJetzt probier ich sie aus.",
      },
      future = {
        en = "GREEN: Next trip planned!\nThere's room for detours.",
        de = "GREEN: Die Reise steht.\nFür Umwege bleibt Zeit.",
      },
    },
  },
  scenes = {
    {
      id = "route_1_departure", mapId = "ROUTE_1", minRank = 1,
      actors = {
        {
          role = "rival", activity = "training_turns", tone = "training", range = "RIGHT",
          movement = "WALK", roamRange = "LEFT_RIGHT",
          en = "{RIVAL}: One more turn.\fMy lead partner keeps\ncutting it too wide.\fWe are learning this\nroute, not waiting.",
          de = "{RIVAL}: Noch eine Runde.\fMein Partner nimmt die\nKurve noch zu weit.\fWir üben hier weiter,\nstatt nur zu warten.",
        },
        {
          role = "third", activity = "researching_tracks", tone = "research", range = "LEFT",
          movement = "WALK", roamRange = "UP_DOWN",
          en = "{THIRD}: Fresh tracks.\fTwo small Pokemon and\none impatient Trainer.\fI'll follow their trail,\nthen we can go.",
          de = "{THIRD}: Frische Spuren.\fZwei kleine Pokémon und\nein eiliger Trainer.\fIch folge ihrer Spur,\ndann geht es weiter.",
        },
      },
      shared = {
        en = "{RIVAL}: Race you north.\f{THIRD}: After the notes!",
        de = "{RIVAL}: Weiter nach Norden.\f{THIRD}: Erst die Notizen!",
      },
    },
    {
      id = "viridian_supplies", mapId = "VIRIDIAN_CITY", minRank = 1,
      actors = {
        {
          role = "rival", activity = "shopping_supplies", tone = "supplies", range = "DOWN",
          en = "{RIVAL}: Potions, balls,\nand no wasted space.\fA good journey starts\nbefore the first battle.",
          de = "{RIVAL}: Alles gepackt.\fEine gute Reise beginnt\nvor dem ersten Kampf.",
        },
        {
          role = "third", activity = "checking_pack", tone = "supplies", range = "DOWN",
          en = "{THIRD}: Three maps packed.\fOne for rain, one for\nwind, and one upside down.\fThat last one was\nnot intentional.",
          de = "{THIRD}: Drei Karten dabei.\fEine für Regen, eine für\nWind und eine für den Weg.\fDie letzte ist verkehrt.\nDas war nicht geplant.",
        },
      },
      shared = {
        en = "{THIRD}: All packed!\f{RIVAL}: Then let's go.",
        de = "{THIRD}: Alles dabei!\f{RIVAL}: Dann gehen wir.",
      },
    },
    {
      id = "route_2_endurance", mapId = "ROUTE_2", minRank = 1,
      actors = {
        {
          role = "rival", activity = "endurance_training", tone = "training", range = "UP",
          movement = "WALK", roamRange = "UP_DOWN",
          battle = true,
          en = "{RIVAL}: The whole road.\nNo rest.\fMy team still has strength\nfor a fair battle.\fNo prize. Just practice.",
          de = "{RIVAL}: Die ganze Strecke,\nohne eine Pause.\fMein Team hat noch Kraft\nfür einen fairen Kampf.\fOhne Preis. Nur zum Üben.",
        },
      },
    },
    {
      id = "pewter_field_notes", mapId = "PEWTER_CITY", minRank = 2,
      actors = {
        {
          role = "third", activity = "museum_research", tone = "research", range = "LEFT",
          battle = true,
          en = "{THIRD}: Fossil notes.\fRight outside the museum.\nNow they're complete!\fMy partner sneezed\nfrom all the stone dust.\fWant to battle instead?",
          de = "{THIRD}: Fossilnotizen.\fDirekt vor dem Museum.\nJetzt sind sie komplett!\fMein Partner musste vom\nganzen Steinstaub niesen.\fKämpfen wir lieber?",
        },
      },
    },
    {
      id = "route_5_shortcut", mapId = "ROUTE_5", minRank = 2,
      actors = {
        {
          role = "rival", activity = "scouting_shortcut", tone = "route", range = "RIGHT",
          movement = "WALK", roamRange = "LEFT_RIGHT",
          battle = true,
          en = "{RIVAL}: The short path is\nnot always the fast one.\fWe timed both.\nMy team chose correctly.",
          de = "{RIVAL}: Der kürzere Weg ist\nnicht immer schneller.\fWir testeten beide.\nMein Team lag richtig.",
        },
        {
          role = "third", activity = "comparing_routes", tone = "route", range = "LEFT",
          movement = "WALK", roamRange = "LEFT_RIGHT",
          en = "{THIRD}: I chose the scenic\nroute for comparison.\fThat is the official\nreason, anyway.",
          de = "{THIRD}: Ich nahm den Weg\nmit der besseren Aussicht.\fNatürlich nur, damit wir\nbeide vergleichen können.",
        },
      },
      shared = {
        en = "{RIVAL}: Same finish time.\f{THIRD}: Better field notes.",
        de = "{RIVAL}: Gleiche Zielzeit.\f{THIRD}: Bessere Notizen.",
      },
    },
    {
      id = "vermilion_departure", mapId = "VERMILION_CITY", minRank = 2,
      actors = {
        {
          role = "rival", activity = "waiting_transport", tone = "travel", range = "DOWN",
          en = "{RIVAL}: The ship is late.\fSo we trained balance\non the harbor stones.\fThe wait wasn't wasted.",
          de = "{RIVAL}: Schiff verspätet.\fAlso üben wir am Hafen\nunser Gleichgewicht.\fSo ist die Wartezeit\nnicht verloren.",
        },
        {
          role = "third", activity = "caring_party", tone = "care", range = "DOWN",
          en = "{THIRD}: Paws are clean.\nFresh water is packed.\fWe'll look around once\neveryone is comfortable.",
          de = "{THIRD}: Pfoten sind sauber.\nFrisches Wasser ist dabei.\fWir sehen uns weiter um,\nsobald alle versorgt sind.",
        },
      },
      shared = {
        en = "{THIRD}: Party ready.\f{RIVAL}: Then so are we.",
        de = "{THIRD}: Team bereit.\f{RIVAL}: Wir auch.",
      },
    },
    {
      id = "route_12_party_care", mapId = "ROUTE_12", minRank = 3,
      actors = {
        {
          role = "rival", activity = "guarding_rest", tone = "care", range = "RIGHT",
          en = "{RIVAL}: Quiet. They earned\na proper rest.\fI will watch the road\nuntil everyone is ready.",
          de = "{RIVAL}: Leise. Sie haben\neine Pause verdient.\fIch halte Wache, bis\nalle wieder bereit sind.",
        },
        {
          role = "third", activity = "healing_party", tone = "care", range = "LEFT",
          battle = true,
          en = "{THIRD}: Bandage secure.\fOne berry, two naps,\nzero heroic shortcuts.\fAfter they wake, we can\ntry a gentle battle.",
          de = "{THIRD}: Der Verband sitzt.\fJetzt noch eine Beere\nund etwas Schlaf.\fDanach können wir eine\nruhige Runde kämpfen.",
        },
      },
      shared = {
        en = "{RIVAL}: Rest matters too.\f{THIRD}: Finally, we agree.",
        de = "{RIVAL}: Auch Pausen zählen.\f{THIRD}: Endlich Einigkeit.",
      },
    },
    {
      id = "fuchsia_habitat_work", mapId = "FUCHSIA_CITY", minRank = 3,
      actors = {
        {
          role = "third", activity = "habitat_observation", tone = "research", range = "UP",
          battle = true,
          en = "{THIRD}: Tracks, feathers,\nand one chewed notebook.\fMy team found the clue.\nThen ate the corner.\fWant to battle while\nthe ink dries?",
          de = "{THIRD}: Spuren, Federn und\nein angenagtes Notizbuch.\fMein Team fand die Spur\nund kaute auf dem Papier.\fKämpfen wir eine Runde,\nbis die Tinte trocken ist?",
        },
      },
    },
    {
      id = "route_15_rematch_study", mapId = "ROUTE_15", minRank = 4,
      actors = {
        {
          role = "rival", activity = "studying_rematches", tone = "training", range = "LEFT",
          movement = "WALK", roamRange = "LEFT_RIGHT",
          battle = true,
          en = "{RIVAL}: Three rematches.\fThree different starts.\fMy team moved before\nI gave the signal.\fShow us a fourth.",
          de = "{RIVAL}: Drei Revanchen.\fDreimal anders angefangen.\fMein Team reagierte schon,\nbevor ich das Zeichen gab.\fZeig uns eine vierte.",
        },
      },
    },
    {
      id = "cinnabar_research", mapId = "CINNABAR_ISLAND", minRank = 4,
      actors = {
        {
          role = "rival", activity = "heat_training", tone = "heat", range = "RIGHT",
          en = "{RIVAL}: It's hot.\nWe have to slow down.\fWe train in short rounds\nand stay focused.\fMy team saves its energy.",
          de = "{RIVAL}: Die Hitze verändert\nunser Tempo.\fWir trainieren kürzer,\naber genauso konzentriert.\fMein Team teilt die Kraft\njetzt besser ein.",
        },
        {
          role = "third", activity = "volcanic_research", tone = "heat", range = "LEFT",
          battle = true,
          en = "{THIRD}: Hot rocks and ash,\nplus one hot notebook.\fMy notes are safe.\nMy lunch isn't.\fWant to battle instead?",
          de = "{THIRD}: Fels und Asche.\nDazu ein heißes Notizbuch.\fMeine Notizen sind sicher.\nMein Proviant nicht.\fKämpfen wir lieber?",
        },
      },
      shared = {
        en = "{THIRD}: Samples packed.\f{RIVAL}: Water break first.",
        de = "{THIRD}: Proben verstaut.\f{RIVAL}: Erst Wasserpause.",
      },
    },
    {
      id = "route_22_league_prep", mapId = "ROUTE_22", minRank = 5,
      actors = {
        {
          role = "rival", activity = "league_sparring", tone = "league", range = "RIGHT",
          movement = "WALK", roamRange = "LEFT_RIGHT",
          battle = true,
          en = "{RIVAL}: Mistakes matter.\fMy team learned from ours.\nShow me what you can do.",
          de = "{RIVAL}: Vor der Liga\nzählt jeder Fehler.\fMein Team lernte daraus.\nZeig, was du kannst.",
        },
        {
          role = "third", activity = "league_observation", tone = "league", range = "LEFT",
          movement = "WALK", roamRange = "LEFT_RIGHT",
          battle = true,
          en = "{THIRD}: Counted turns.\fThen recounted because\n{RIVAL} ran past twice.\fMy team wants its own\nLeague rehearsal.",
          de = "{THIRD}: Ich hab mitgezählt.\fDann noch einmal, weil\n{RIVAL} zweimal vorbeilief.\fJetzt will mein Team auch\nfür die Liga üben.",
        },
      },
      shared = {
        en = "{RIVAL}: Two plans.\nOne summit.\f{THIRD}: And enough snacks.",
        de = "{RIVAL}: Zwei Pläne.\nEin Gipfel.\f{THIRD}: Und genug Proviant.",
      },
    },
    {
      id = "indigo_next_journey", mapId = "INDIGO_PLATEAU", minRank = 6,
      actors = {
        {
          role = "rival", activity = "planning_next_journey", tone = "future", range = "RIGHT",
          battle = true,
          en = "{RIVAL}: The League isn't\nthe end of our journey.\fMy team chose our\nnext challenge together.\fOne last Kanto battle?",
          de = "{RIVAL}: Die Liga ist noch\nnicht das Ende.\fMein Team hat das nächste\nZiel gemeinsam gewählt.\fNoch ein letzter Kampf\nhier in Kanto?",
        },
        {
          role = "third", activity = "cataloguing_journey", tone = "future", range = "LEFT",
          battle = true,
          en = "{THIRD}: We saw every route.\fWe fixed our mistakes.\fMy team added:\n\"Keep travelling.\"\fAnd: \"One more battle.\"",
          de = "{THIRD}: Wir waren überall.\fFehler haben uns geholfen.\fMein Team hat ergänzt:\n\"Wir reisen weiter.\"\fUnd: \"Noch ein Kampf.\"",
        },
      },
      shared = {
        en = "{RIVAL}: Let's keep going.\f{THIRD}: And bring back\nnew stories.",
        de = "{RIVAL}: Wir ziehen weiter.\f{THIRD}: Und bringen neue\nGeschichten mit.",
      },
    },
  },
}
