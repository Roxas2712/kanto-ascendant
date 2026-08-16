-- KA-INTERNAL: LEGACY-PATHS-001

return {
  order = { "RED", "BLUE", "GREEN" },
  paths = {
    RED = {
      key = "red",
      title = { en = "PATH OF THE CHALLENGER", de = "PFAD DES HERAUSFORDERERS" },
      reward = { en = "KANTO CHALLENGER", de = "KANTO-HERAUSFORDERER" },
      stages = {
        {
          badges = 2, map = "ROUTE_3", class = "OPP_COOLTRAINER_M",
          sprite = "SPRITE_COOLTRAINER_M", text = "KA_LEGACY_RED_1",
          intro = {
            en = "CHALLENGER: OAK says\nyou never turn away.\fShow me whether that\nresolve survives battle!",
            de = "HERAUSFORDERER: EICH\nsagt, du weichst nie.\fZeig, ob dein Wille\nden Kampf übersteht!",
          },
          win = {
            en = "Your first red seal\nmark is proven.\fStronger challengers\nare already waiting.",
            de = "Die erste Prüfung des\nroten Siegels ist klar.\fStärkere Herausforderer\nwarten bereits.",
          },
          team = { "PRIMEAPE", "RAICHU", "PIDGEOT" },
        },
        {
          badges = 4, map = "ROUTE_8", class = "OPP_COOLTRAINER_F",
          sprite = "SPRITE_COOLTRAINER_F", text = "KA_LEGACY_RED_2",
          intro = {
            en = "ACE: Badges are only\nproof of yesterday.\fWin with the choices\nyou make today!",
            de = "ASS: Orden beweisen nur\nden gestrigen Sieg.\fHeute zählen allein\ndeine Entscheidungen!",
          },
          win = { en = "No hesitation.\nContinue toward Fuchsia.",
            de = "Kein Zögern.\nGeh weiter nach Fuchsania." },
          team = { "NIDOQUEEN", "STARMIE", "ARCANINE", "JOLTEON" },
        },
        {
          badges = 6, map = "ROUTE_15", class = "OPP_COOLTRAINER_M",
          sprite = "SPRITE_COOLTRAINER_M", text = "KA_LEGACY_RED_3",
          intro = {
            en = "CHALLENGER: A strong\nlead is not enough.\fCan your whole team\ncarry one purpose?",
            de = "HERAUSFORDERER: Ein\nstarker Start reicht nicht.\fTrägt dein ganzes Team\ndasselbe Ziel?",
          },
          win = { en = "Every member answered.\nOne trial remains below.",
            de = "Jedes Mitglied antwortete.\nUnten wartet eine Prüfung." },
          team = { "EXEGGUTOR", "CLOYSTER", "TAUROS", "GENGAR", "MACHAMP" },
        },
        {
          badges = 8, map = "ROUTE_25", class = "OPP_COOLTRAINER_F",
          sprite = "SPRITE_COOLTRAINER_F", text = "KA_LEGACY_RED_4",
          intro = {
            en = "ACE: Eight badges open\nthe League road.\fThey do not guarantee\nyou belong there.",
            de = "ASS: Acht Orden öffnen\nden Weg zur Liga.\fSie beweisen nicht, dass\ndu dorthin gehörst.",
          },
          win = { en = "You belong.\nFind the silent veteran\nat Indigo Plateau.",
            de = "Du gehörst dorthin.\nFinde den stillen Veteran\nam Indigo-Plateau." },
          team = { "ALAKAZAM", "SNORLAX", "LAPRAS", "RHYDON", "DRAGONITE" },
        },
        {
          badges = 8, map = "INDIGO_PLATEAU", class = "OPP_COOLTRAINER_M",
          sprite = "SPRITE_GENTLEMAN", text = "KA_LEGACY_RED_5",
          intro = {
            en = "VETERAN: ...\fNo speech. No excuses.\nOnly the final answer.",
            de = "VETERAN: ...\fKeine Rede. Keine Ausrede.\nNur die letzte Antwort.",
          },
          win = {
            en = "VETERAN: You carry\nKanto's resolve.\fThe title KANTO\nCHALLENGER is yours.",
            de = "VETERAN: Du trägst\nKantos Entschlossenheit.\fDer Titel KANTO-\nHERAUSFORDERER gehört dir.",
          },
          team = { "TAUROS", "STARMIE", "EXEGGUTOR", "SNORLAX", "GENGAR", "DRAGONITE" },
        },
      },
    },
    BLUE = {
      key = "blue",
      title = { en = "OAK'S LEGACY", de = "EICHS VERMÄCHTNIS" },
      reward = { en = "OAK'S HEIR", de = "EICHS ERBE" },
      stages = {
        {
          badges = 2, map = "ROUTE_4", class = "OPP_SCIENTIST",
          sprite = "SPRITE_SCIENTIST", text = "KA_LEGACY_BLUE_1",
          intro = {
            en = "RESEARCHER: Moon Stone\nchanges more than a type.\fBuild an answer to\nthree different threats.",
            de = "FORSCHER: Ein Mondstein\nändert mehr als den Typ.\fFinde Antworten auf\ndrei verschiedene Gefahren.",
          },
          win = { en = "Good. Coverage is not\njust super-effective moves.",
            de = "Gut. Abdeckung ist mehr\nals sehr effektive Attacken." },
          team = { "CLEFABLE", "PARASECT", "GRAVELER" },
        },
        {
          badges = 4, map = "ROUTE_10", class = "OPP_SCIENTIST",
          sprite = "SPRITE_SCIENTIST", text = "KA_LEGACY_BLUE_2",
          intro = {
            en = "RESEARCHER: The Plant\nrewards speed control.\fStatus first. Pressure\nsecond. Finish last.",
            de = "FORSCHER: Im Kraftwerk\nzählt Tempokontrolle.\fErst Status, dann Druck,\nzuletzt der Abschluss.",
          },
          win = { en = "You read the sequence,\nnot merely the matchup.",
            de = "Du hast die Abfolge gelesen,\nnicht nur das Duell." },
          team = { "ELECTRODE", "MAGNETON", "PORYGON", "RAICHU" },
        },
        {
          badges = 6, map = "LAVENDER_TOWN", class = "OPP_CHANNELER",
          sprite = "SPRITE_CHANNELER", text = "KA_LEGACY_BLUE_3",
          intro = {
            en = "CHANNELER: A safe switch\ncan decide a battle.\fFind the answer hidden\nbehind immunity.",
            de = "EXORZISTIN: Ein sicherer\nWechsel entscheidet Kämpfe.\fFinde die Antwort hinter\nder Immunität.",
          },
          win = { en = "Oak's notes gain a\nvaluable new margin.",
            de = "Eichs Notizen erhalten\neine wertvolle Ergänzung." },
          team = { "GENGAR", "HYPNO", "MAROWAK", "KANGASKHAN", "MUK" },
        },
        {
          badges = 8, map = "CINNABAR_ISLAND", class = "OPP_SCIENTIST",
          sprite = "SPRITE_SCIENTIST", text = "KA_LEGACY_BLUE_4",
          intro = {
            en = "RESEARCHER: The final\nnote has no conclusion.\fProve a balanced team\ncan create its own.",
            de = "FORSCHER: Der letzten\nNotiz fehlt der Schluss.\fBeweise, dass Balance\neinen eigenen schafft.",
          },
          win = {
            en = "Oak's field record is\nwhole again.\fThe title OAK'S HEIR\nis now recorded.",
            de = "Eichs Feldbericht ist\nwieder vollständig.\fDer Titel EICHS ERBE\nist nun verzeichnet.",
          },
          team = { "ARCANINE", "OMASTAR", "VENOMOTH", "MAGNETON", "SNORLAX", "ALAKAZAM" },
        },
      },
    },
    GREEN = {
      key = "green",
      title = { en = "WILD TRAILS OF KANTO", de = "KANTOS WILDE SPUREN" },
      reward = { en = "WILDERNESS KEEPER", de = "HÜTERIN DER WILDNIS" },
      stages = {
        {
          badges = 2, map = "ROUTE_2", class = "OPP_JR_TRAINER_F",
          sprite = "SPRITE_COOLTRAINER_F", text = "KA_LEGACY_GREEN_1",
          intro = {
            en = "RANGER: These prints do\nnot belong to Viridian.\fHelp me protect the\nsmall herd following them.",
            de = "RANGERIN: Diese Spuren\ngehören nicht nach Vertania.\fHilf mir, die kleine\nHerde dahinter zu schützen.",
          },
          win = { en = "The herd can pass.\nA second trail leads south.",
            de = "Die Herde kann weiter.\nEine zweite Spur führt südlich." },
          item = "LEAF_STONE",
          team = { "BUTTERFREE", "BEEDRILL", "IVYSAUR" },
        },
        {
          badges = 4, map = "ROUTE_6", class = "OPP_JR_TRAINER_F",
          sprite = "SPRITE_COOLTRAINER_F", text = "KA_LEGACY_GREEN_2",
          intro = {
            en = "WILDLIFE KEEPER: Noise\nhas split a nesting pair.\fA careful battle can\nguide them together.",
            de = "WILDHÜTERIN: Lärm hat\nein Nestpaar getrennt.\fEin behutsamer Kampf\nführt sie wieder zusammen.",
          },
          win = { en = "The nest is quiet again.\nNew habitat notes unlocked.",
            de = "Das Nest ist wieder ruhig.\nNeue Habitatdaten sind frei." },
          item = "MOON_STONE",
          team = { "PIDGEOTTO", "WEEPINBELL", "GLOOM", "PERSIAN" },
        },
        {
          badges = 6, map = "ROUTE_12", class = "OPP_POKEMANIAC",
          sprite = "SPRITE_SUPER_NERD", text = "KA_LEGACY_GREEN_3",
          intro = {
            en = "COLLECTOR: Rare does not\nmean yours to take.\fConvince me before this\nmarsh becomes a trophy case!",
            de = "SAMMLER: Selten heißt\nnicht, dass es dir gehört.\fÜberzeuge mich, bevor\nder Sumpf zur Vitrine wird!",
          },
          win = { en = "I understand. Observation\nbefore ownership.",
            de = "Ich verstehe. Beobachten\nkommt vor dem Besitzen." },
          item = "WATER_STONE",
          team = { "WEEPINBELL", "SEADRA", "RHYDON", "PINSIR", "DITTO" },
        },
        {
          badges = 8, map = "ROUTE_16", class = "OPP_COOLTRAINER_F",
          sprite = "SPRITE_COOLTRAINER_F", text = "KA_LEGACY_GREEN_4",
          intro = {
            en = "RANGER: Every trail meets\nhere: forest, marsh, sky.\fProtect all three without\nforcing nature to yield.",
            de = "RANGERIN: Hier treffen\nWald, Sumpf und Himmel.\fSchütze alle drei, ohne\ndie Natur zu bezwingen.",
          },
          win = {
            en = "Kanto's wild paths remain\nopen because of you.\fWILDERNESS KEEPER\nis now your title.",
            de = "Kantos wilde Wege bleiben\ndank dir offen.\fHÜTERIN DER WILDNIS\nist nun dein Titel.",
          },
          item = "FIRE_STONE",
          team = { "VENUSAUR", "VAPOREON", "DODRIO", "RAPIDASH", "KANGASKHAN", "SCYTHER" },
        },
      },
    },
  },
  finale = {
    map = "OAKS_LAB",
    text = "KA_LEGACY_FINALE",
    sprite = "SPRITE_OAK",
    teams = {
      { class = "OPP_COOLTRAINER_M", team = { "TAUROS", "STARMIE", "SNORLAX", "GENGAR", "DRAGONITE", "ALAKAZAM" } },
      { class = "OPP_SCIENTIST", team = { "ELECTRODE", "EXEGGUTOR", "CLOYSTER", "PORYGON", "ARCANINE", "SLOWBRO" } },
      { class = "OPP_COOLTRAINER_F", team = { "VENUSAUR", "VAPOREON", "DODRIO", "RHYDON", "PINSIR", "KANGASKHAN" } },
    },
  },
}
