-- Human-readable, bilingual help for every Ascendant option.  The visible
-- schema stays compact; SELECT opens these explanations together with the
-- currently selected value and any restart warning.

return function(i18n)
  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local rows = {
    language = {
      "Selects Ascendant's text language. AUTO follows the game language.",
      "Wählt die Ascendant-Textsprache. AUTO folgt der Spielsprache.", true },
    difficulty = {
      "Raises trainer levels. Bonuses begin smaller and reach full strength as you earn badges. Wild levels follow this curve only when WILD LEVEL SCALING is ON. EXTREME also blocks items in trainer battles.",
      "Erhöht Trainerlevel. Die Boni starten kleiner und erreichen mit Deinen Orden ihre volle Stärke. Wildlevel folgen dieser Kurve nur mit WILD-LEVEL-SKALIERUNG AN. EXTREM sperrt zusätzlich Items in Trainerkämpfen." },
    adaptive_trainer_levels = {
      "Controls the party-relative trainer layer separately from the fixed Difficulty curve. OFF = CLASSIC: exact authored level plus Difficulty and, in rematches, classic growth. AUTO is classic on STANDARD; HIGH/HARD/VERY HARD/EXTREME aim at the rounded party average +1/+2/+3/+4. Manual values use the shown gap. Non-Egg party Pokémon count even when fainted; boxed Pokémon do not. The authored plus Difficulty floor is never lowered. Existing saves remain classic until Adaptive or Difficulty is deliberately selected again.",
      "Regelt die teambezogene Trainerstufe getrennt von der festen Schwierigkeitskurve. AUS = KLASSISCH: exakt festgelegtes Level plus Schwierigkeit und bei Revanchen klassisches Wachstum. AUTO ist auf STANDARD klassisch; HOCH/SCHWER/SEHR SCHWER/EXTREM zielen auf den gerundeten Teamdurchschnitt +1/+2/+3/+4. Manuelle Werte nutzen den angezeigten Abstand. Team-Pokémon zählen auch besiegt, Eier und Box-Pokémon nicht. Das festgelegte Level plus Schwierigkeit wird nie gesenkt. Bestehende Spielstände bleiben klassisch, bis Adaptiv oder Schwierigkeit bewusst neu gewählt wird." },
    wild_level_scaling = {
      "OFF preserves every native or authored Wild level. ON adds the selected difficulty's badge-phased Wild-level bonus. Species, encounter odds, Randomizer, Nuzlocke and trainer levels are unchanged.",
      "AUS bewahrt jedes native oder festgelegte Wildlevel. AN addiert den ordenabhängigen Wildlevel-Bonus der gewählten Schwierigkeit. Arten, Chancen, Randomizer, Nuzlocke und Trainerlevel bleiben unverändert." },
    rare_item_lock = {
      "Prevents rare, unique and progression items from being discarded accidentally.",
      "Verhindert, dass seltene, einzigartige und wichtige Items versehentlich weggeworfen werden." },
    vision_encounters = {
      "Allows the rare one-time unknown Ho-Oh vision on southern Route 2. Lugia remains a regular catch encounter.",
      "Erlaubt die seltene, einmalige unbekannte Ho-Oh-Vision auf der südlichen Route 2. Lugia bleibt regulär fangbar." },
    rest_profile = {
      "Sets future field-rematch, silent-training and post-game Gym breaks: VERY SHORT 151-302, SHORT 303-604, NORMAL 605-1255, LONG 1256-1882 or VERY LONG 1883-2510. CUSTOM exposes its two saved values. Already scheduled breaks never change; Legacy Wanderers use their own frequency.",
      "Legt künftige Pausen für Feldrevanchen, stilles Training und Postgame-Arenen fest: SEHR KURZ 151-302, KURZ 303-604, NORMAL 605-1255, LANG 1256-1882 oder SEHR LANG 1883-2510. EIGEN zeigt seine zwei gespeicherten Werte. Bereits geplante Pausen ändern sich nie; Legacy-Wanderer haben eine eigene Häufigkeit." },
    rest_min = {
      "CUSTOM only: minimum steps used for future rematch breaks. Switching profiles preserves this value.",
      "Nur EIGEN: minimale Schritte für künftige Revanchenpausen. Ein Profilwechsel bewahrt diesen Wert." },
    rest_max = {
      "CUSTOM only: maximum steps used for future rematch breaks. Switching profiles preserves this value.",
      "Nur EIGEN: maximale Schritte für künftige Revanchenpausen. Ein Profilwechsel bewahrt diesen Wert." },
    level_gain = {
      "Adds this many levels for every completed rematch, up to level 100.",
      "Addiert pro abgeschlossener Revanche diese Level, höchstens bis Level 100." },
    team_growth = {
      "Lets rematch opponents evolve and expand their teams as their progression rises.",
      "Lässt Revanche-Gegner ihre Teams mit dem Fortschritt entwickeln und erweitern." },
    loot_mode = {
      "Controls additional item or money rewards earned after rematch victories.",
      "Steuert zusätzliche Item- oder Geldbelohnungen nach gewonnenen Revanchen." },
    legacy_wanderer_frequency = {
      "Controls surprise challengers only during an active Legacy New Game+ run. RARE is the default; NEVER stops new encounters but still delivers already reserved rewards.",
      "Steuert Überraschungstrainer nur in einem aktiven Legacy-Neues-Spiel+. SELTEN ist Standard; NIE stoppt neue Kämpfe, liefert aber bereits vorgemerkte Preise weiter aus." },
    kanto_151 = {
      "Controls how all original 151 species become obtainable: rewards, wild encounters or no assistance.",
      "Bestimmt, wie alle ursprünglichen 151 Arten erhältlich werden: Belohnungen, Wildfänge oder keine Hilfe.", true },
    legend_art = {
      "Selects bundled Crystal battle art or a Kanto fallback for Johto species.",
      "Wählt enthaltene Kristall-Kampfgrafik oder einen Kanto-Ersatz für Johto-Arten." },
    kanto_crystal_art = {
      "Uses bundled Crystal-style battle pictures for supported Kanto Pokémon.",
      "Verwendet enthaltene Kristall-Kampfbilder für unterstützte Kanto-Pokémon." },
    dex_sprite_style = {
      "Selects original or Crystal art in Pokédex and status views. It does not control team icons.",
      "Wählt Original- oder Kristallgrafik in Pokédex und Status. Team-Icons werden separat gesteuert." },
    party_icon_style = {
      "ANIMATED SPECIES gives every Pokémon #001-251 its own moving team icon without FollowerEX.",
      "ANIMIERTE ARTEN gibt jedem Pokémon #001-251 ein eigenes bewegtes Team-Icon – ohne FollowerEX.", true },
    crystal_animation = {
      "Animates supported Crystal battle pictures. It does not affect the team menu.",
      "Animiert unterstützte Kristall-Kampfbilder. Das Team-Menü wird nicht beeinflusst." },
    pokemon_sprite_style = {
      "Chooses the global Pokémon artwork family. CRYSTAL 2D is the complete Ascendant presentation; individual screens can still be disabled below.",
      "Wählt die globale Pokémon-Grafikfamilie. CRYSTAL 2D ist Ascendants vollständige Darstellung; einzelne Bereiche lassen sich darunter weiterhin abschalten.", true },
    character_sprite_style = {
      "Chooses Kanto Ascendant's reviewed project character set or the original edition characters for field scenes.",
      "Wählt Kanto Ascendants geprüfte eigene Figuren oder die ursprünglichen Editionsfiguren für Spielszenen.", true },
    trainer_portrait_style = {
      "Chooses approved Kanto Ascendant HD standees or untouched edition-original Gen-I portraits. Red uses the ROM-derived native front where no project-authored front is selected; project-authored throw and Voxel art remains available.",
      "Wählt bestätigte Kanto-Ascendant-HD-Figuren oder unveränderte editionsgebundene Gen-I-Porträts. Rot nutzt ohne eigene Front das aus der ROM erzeugte Original; eigene Wurf- und Voxelbilder bleiben erhalten.", true },
    sprite_style_battle = {
      "Applies the selected Pokémon sprite style in 2D battles. Voxel battles keep their dedicated models.",
      "Verwendet den gewählten Pokémon-Spritestil in 2D-Kämpfen. Voxel-Kämpfe behalten ihre eigenen Modelle." },
    sprite_style_summary = {
      "Applies the selected Pokémon sprite style on status and summary pages.",
      "Verwendet den gewählten Pokémon-Spritestil auf Status- und Übersichtsseiten." },
    sprite_style_dex = {
      "Applies the selected Pokémon sprite style to Pokédex entries, including Johto entries already discovered.",
      "Verwendet den gewählten Pokémon-Spritestil in Pokédex-Einträgen, einschließlich bereits entdeckter Johto-Arten." },
    sprite_style_box = {
      "Applies species-specific selected-style icons and portraits inside Pokémon storage.",
      "Verwendet artgerechte Icons und Bilder des gewählten Stils in der Pokémon-Lagerung." },
    sprite_style_scenes = {
      "Applies the selected Pokémon style to the title, Oak intro and other scripted presentation scenes.",
      "Verwendet den gewählten Pokémon-Stil im Titel, Eich-Intro und weiteren geskripteten Szenen.", true },
    shiny_hunts = {
      "ASCENDANT enables authored shiny hunts; NATURAL uses the classic 1-in-8192 chance.",
      "ASCENDANT aktiviert gestaltete Shiny-Jagden; NATÜRLICH nutzt die klassische Chance 1 zu 8192." },
    shiny_effects = {
      "Shows Ascendant shiny palettes and visual effects for marked shiny Pokémon.",
      "Zeigt Ascendant-Shiny-Paletten und Effekte für als Shiny markierte Pokémon." },
    shiny_protection = {
      "Blocks releasing shiny Pokémon from storage unless this protection is deliberately disabled.",
      "Verhindert das Freilassen von Shiny-Pokémon, solange der Schutz nicht bewusst ausgeschaltet wird." },
    shiny_event = {
      "Enables the authored Red Gyarados encounter and its related progression.",
      "Aktiviert die gestaltete Begegnung mit dem Roten Garados und ihren Fortschritt." },
    mega_evolution = {
      "Enables Mega Evolution, Mega Stones and their related quests and battle command.",
      "Aktiviert Mega-Entwicklung, Mega-Steine sowie zugehörige Missionen und Kampfsteuerung." },
    mega_opponents = {
      "Chooses which enemy trainers may use an available Mega Evolution.",
      "Bestimmt, welche gegnerischen Trainer eine verfügbare Mega-Entwicklung einsetzen dürfen." },
    johto_time = {
      "Uses the clock, fixed day or fixed night for Johto encounters with time conditions.",
      "Nutzt Uhrzeit, festen Tag oder feste Nacht für zeitabhängige Johto-Begegnungen." },
    johto_wilds_integration = {
      "Lets Living Regions use released Johto habitats and signals as visible encounters. Turning it off leaves visible Kanto Pokémon untouched.",
      "Erlaubt Lebenden Regionen, freigeschaltete Johto-Habitate und Signale sichtbar darzustellen. AUS lässt sichtbare Kanto-Pokémon unverändert." },
    living_world_enabled = {
      "Shows encounter Pokémon directly in eligible routes, caves and water areas; touching one starts its battle. New profiles start with this and RANDOM BATTLES enabled. Turning this OFF restores classic step encounters even when RANDOM BATTLES is OFF.",
      "Zeigt Begegnungs-Pokémon direkt auf geeigneten Routen, in Höhlen und Gewässern; Berührung startet den Kampf. Neue Profile starten mit dieser Option und ZUFALLSKÄMPFEN auf AN. AUS stellt klassische Schrittkämpfe wieder her, selbst wenn ZUFALLSKÄMPFE AUS ist." },
    living_world_density = {
      "Controls the target number of visible route, cave and water Pokémon. It does not change encounter probabilities or town Pokémon.",
      "Steuert die Zielmenge sichtbarer Routen-, Höhlen- und Wasser-Pokémon. Fangchancen und Stadt-Pokémon bleiben unverändert." },
    living_world_random_encounters = {
      "Enabled by default on new profiles. Keeps classic step-based random encounters alongside visible Pokémon. Disable it for contact battles only; an explicit choice remains saved.",
      "Bei neuen Profilen standardmäßig AN. Behält klassische schrittbasierte Zufallskämpfe zusätzlich zu sichtbaren Pokémon. AUS bedeutet nur Kontaktkämpfe; die ausdrückliche Wahl bleibt gespeichert." },
    living_world_water = {
      "Chooses swimming sprites, hidden or visible silhouettes, classic random encounters only, or no water encounters.",
      "Wählt Schwimmsprites, verborgene oder sichtbare Silhouetten, nur klassische Zufallskämpfe oder keine Wasserbegegnungen." },
    living_world_caves = {
      "REACHABLE ONLY uses walkable cave tiles. MIXED adds a small amount of unreachable atmospheric cave scenery.",
      "NUR ERREICHBAR nutzt begehbare Höhlenfelder. GEMISCHTE KULISSE ergänzt wenige unerreichbare atmosphärische Höhlen-Pokémon." },
    living_world_grass = {
      "IN GRASS places Pokémon partly inside tall grass like the player. ABOVE GRASS draws them fully above it.",
      "IM GRAS stellt Pokémon wie den Spieler teilweise ins hohe Gras. ÜBER GRAS zeichnet sie vollständig darüber." },
    living_world_idle = {
      "Allows calm visible Pokémon to stay in place and look around until approached.",
      "Erlaubt ruhigen sichtbaren Pokémon, stehen zu bleiben und sich umzusehen, bis man sich nähert." },
    living_world_wander = {
      "Allows visible Pokémon to wander within their connected encounter area.",
      "Erlaubt sichtbaren Pokémon, innerhalb ihres verbundenen Begegnungsgebiets umherzuwandern." },
    living_world_chase = {
      "Allows aggressive species to notice the player, chase them and initiate a battle on contact.",
      "Erlaubt aggressiven Arten, den Spieler zu bemerken, zu verfolgen und bei Kontakt einen Kampf zu beginnen." },
    living_world_hidden = {
      "Allows concealed rustling-grass and cave-dust encounters whose species is revealed only when touched.",
      "Erlaubt verborgene Raschelgras- und Höhlenstaub-Begegnungen, deren Art erst bei Berührung sichtbar wird." },
    living_world_silhouettes = {
      "Draws encounter-zone Pokémon as dark silhouettes while preserving their recognizable shape and behavior.",
      "Zeichnet Pokémon in Begegnungszonen als dunkle Silhouetten, behält aber ihre erkennbare Form und ihr Verhalten." },
    living_world_towns = {
      "Adds peaceful Pokémon to eligible towns and safe interiors. They can be spoken to but never start a battle.",
      "Fügt geeigneten Städten und sicheren Innenräumen friedliche Pokémon hinzu. Man kann sie ansprechen, aber nie bekämpfen." },
    wilds_town_pokemon_amount = {
      "Sets an exact peaceful Pokemon target for each eligible town or safe interior. Automatic keeps Wilds' map-specific 0-3 distribution; actual counts may be lower when too few safe tiles are free.",
      "Legt die genaue Zielmenge friedlicher Pokémon je geeigneter Stadt oder sicherem Innenraum fest. Automatisch nutzt Wilds' ortsabhängige Verteilung von 0-3; bei zu wenigen sicheren Feldern kann die wirkliche Menge kleiner sein." },
    wilds_town_pokemon_species = {
      "Chooses Kanto, Kanto plus Johto, or Johto for peaceful town Pokemon. These walkers cannot start battles; legendary, mythical and finale-locked species remain excluded.",
      "Wählt Kanto, Kanto plus Johto oder Johto für friedliche Stadt-Pokémon. Diese Begleiter lösen keine Kämpfe aus; legendäre, mystische und finale-gesperrte Arten bleiben ausgeschlossen." },
    johto_level_bonus = {
      "Sets how far ordinary Johto encounter levels may rise above the weighted route average.",
      "Bestimmt, wie weit gewöhnliche Johto-Begegnungslevel über dem gewichteten Routenmittel liegen dürfen." },
    ascendant_useful_bag = {
      "Master switch for Ascendant's enhanced Bag support. The detailed layout is selected with BAG MODE.",
      "Hauptschalter für Ascendants erweiterten Beutel. Die genaue Aufteilung wird mit BEUTELMODUS gewählt.", true },
    ascendant_bag_mode = {
      "Chooses vanilla capacity, FireRed skin, expanded capacity or categorized pockets. OFF hands the Bag back to an external compatible owner.",
      "Wählt Standardgröße, Feuerrot-Skin, mehr Platz oder sortierte Fächer. AUS übergibt den Beutel an einen kompatiblen externen Besitzer.", true },
    ascendant_quick_select = {
      "Enables the Field Kit shortcut. Tap SELECT to use the assigned favorite tool; hold SELECT to open the full Field Kit. In the Field Kit, A uses a tool, SELECT makes it the favorite and B closes the menu.",
      "Aktiviert das Feld-Kit-Kürzel. SELECT kurz nutzt das festgelegte Lieblingswerkzeug; SELECT halten öffnet das ganze Feld-Kit. Im Feld-Kit nutzt A ein Werkzeug, SELECT macht es zum Favoriten und B schließt das Menü." },
    ascendant_qol = {
      "Master switch for Ascendant's convenience bundle. The individual helpers below remain independently configurable.",
      "Hauptschalter für Ascendants Komfortpaket. Die einzelnen Hilfen darunter bleiben separat einstellbar." },
    qol_exp_bar = {
      "Shows an EXP progress bar during battle and selects its black or blue presentation.",
      "Zeigt im Kampf einen EP-Fortschrittsbalken und wählt dessen schwarze oder blaue Darstellung." },
    qol_caught_indicator = {
      "Marks opposing Pokémon already registered as caught in the Pokédex, using grey or red.",
      "Markiert gegnerische Pokémon, die im Pokédex bereits als gefangen gelten, in Grau oder Rot." },
    qol_easy_interactions = {
      "Lets A use known field moves directly on matching obstacles, such as CUT on a tree, without opening the party menu.",
      "Lässt A bekannte Feldattacken direkt an passenden Hindernissen nutzen, etwa ZERSCHNEIDER an einem Baum, ohne das Team-Menü zu öffnen." },
    qol_location_banners = {
      "Shows the current place name after entering a map and selects how many seconds it remains visible.",
      "Zeigt nach Betreten einer Karte den Ortsnamen und bestimmt, wie viele Sekunden er sichtbar bleibt." },
    modern_storage_ui = {
      "Uses Ascendant's FireRed-inspired Bag, Box and Pokémon information layout instead of the plain Gen-I menus.",
      "Verwendet Ascendants von Feuerrot inspirierte Beutel-, Box- und Pokémon-Ansicht statt der schlichten Gen-I-Menüs.", true },
    box_grid_icon_style = {
      "Chooses the small icons in the right-hand 5 by 4 storage grid. CURRENT keeps the existing Box art; HGSS WALKERS uses the bundled 16-pixel walking sprites when an exact species asset is available. The large preview on the left never changes.",
      "Wählt die kleinen Icons im rechten 5-mal-4-Boxraster. AKTUELL behält die bisherige Boxgrafik; HGSS-BEGLEITER nutzt die enthaltenen 16-Pixel-Laufsprites, wenn für die genaue Art eine Grafik vorhanden ist. Die große Vorschau links bleibt immer unverändert." },
    catch_destination = {
      "ASK lets you choose party or Box after every catch. PARTY FIRST and BOX FIRST automate the preferred destination when space exists.",
      "FRAGEN lässt nach jedem Fang Team oder Box wählen. ZUERST TEAM und ZUERST BOX automatisieren das bevorzugte Ziel, wenn Platz vorhanden ist." },
    pokedex_filter = {
      "Chooses whether the Pokédex list shows every slot, only seen species or only owned species.",
      "Bestimmt, ob der Pokédex alle Plätze, nur gesehene oder nur gefangene Arten zeigt." },
    box_filter = {
      "Filters the current storage view to all Pokémon, Kanto species or Johto species without deleting or moving anything.",
      "Filtert die aktuelle Lageransicht nach allen, Kanto- oder Johto-Pokémon, ohne etwas zu löschen oder zu verschieben." },
    text_speed = {
      "Overrides the engine text speed with a fixed slow, normal or fast preset. ENGINE OPTION follows the regular game setting.",
      "Überschreibt die Textgeschwindigkeit mit Langsam, Normal oder Schnell. ENGINE-EINSTELLUNG folgt der normalen Spieloption." },
    ride_control = {
      "Legacy fallback used only while QUICK SELECT is OFF: SELECT mounts or dismounts the bicycle, or the bicycle remains Bag-only. With QUICK SELECT on, the assigned favorite owns a short SELECT press.",
      "Alte Rückfalleinstellung nur bei ausgeschalteter SCHNELLWAHL: SELECT steigt aufs Fahrrad oder ab, alternativ bleibt es nur im Beutel. Mit SCHNELLWAHL gehört kurzes SELECT dem festgelegten Favoriten." },
    quick_select_tap = {
      "Seeds the first favorite when an old or new profile has none: bicycle, Field Kit or empty. Once a favorite is assigned in the Field Kit or Bag, that saved choice wins.",
      "Legt den ersten Favoriten fest, wenn ein alter oder neuer Spielstand noch keinen hat: Fahrrad, Feld-Kit oder leer. Sobald im Feld-Kit oder Beutel ein Favorit gewählt wurde, gilt diese gespeicherte Wahl." },
    quick_select_registration = {
      "Adds favorite assignment to the Bag's optional R3 item-actions menu. Bag SELECT remains mark/place, START shows item help, and B cancels a pending move or exits.",
      "Fügt die Favoritenwahl zum optionalen R3-Item-Aktionsmenü des Beutels hinzu. Im Beutel markiert/tauscht SELECT, START zeigt Hilfe und B bricht einen Tausch ab oder verlässt das Menü." },
    quick_select_empty_notice = {
      "Shows a short explanation after tapping SELECT when no favorite tool is assigned.",
      "Zeigt nach kurzem SELECT einen Hinweis, wenn kein Lieblingswerkzeug festgelegt ist." },
    catch_box_notice = {
      "Always announces the destination Box after a caught Pokémon is transferred, including automatic transfers and the next Box when one is full.",
      "Nennt nach der Übertragung immer die Zielbox, auch bei automatischem Transfer und beim Wechsel, wenn eine Box voll ist." },
    status_values = {
      "Adds hidden training values to Pokémon status: DV/IV only, or DV/IV together with accumulated EV values.",
      "Ergänzt versteckte Trainingswerte im Pokémon-Status: nur DV/IV oder DV/IV zusammen mit gesammelten EV-Werten." },
    modern_ball_skins = {
      "Uses later-generation Ball artwork and rolling throw frames while preserving each Ball's original catch behavior.",
      "Verwendet spätere Ballgrafiken und rollende Wurfbilder, ohne das ursprüngliche Fangverhalten eines Balls zu verändern." },
    fast_box_switch = {
      "Allows direct previous/next Box switching with the directional controls and shows the matching control legend.",
      "Erlaubt direkten Wechsel zur vorherigen oder nächsten Box mit den Richtungstasten und zeigt die passende Legende." },
    mythic_signals = {
      "Enables the Mew and Celebi signal investigations and their associated encounters.",
      "Aktiviert die Mew- und Celebi-Signaluntersuchungen samt zugehörigen Begegnungen." },
    mew_profile = {
      "Chooses Ascendant's level-100 Mew challenge or the historical level-5 event profile.",
      "Wählt Ascendants Mew-Herausforderung auf Level 100 oder das historische Eventprofil auf Level 5." },
    event_mode = {
      "Selects cup battles, roaming hunts or disables the historical event archive encounters.",
      "Wählt Cup-Kämpfe, wandernde Jagden oder deaktiviert Begegnungen des historischen Event-Archivs." },
    event_flee = {
      "Allows roaming event Pokémon to flee according to their encounter rules.",
      "Erlaubt wandernden Event-Pokémon gemäß ihren Regeln zu fliehen." },
    event_rosette = {
      "Shows the earned event rosette in supported Pokémon and archive views.",
      "Zeigt die verdiente Event-Rosette in unterstützten Pokémon- und Archivansichten." },
    rocket_story = {
      "Enables Ascendant's additional Team Rocket story progression.",
      "Aktiviert Ascendants zusätzliche Team-Rocket-Handlung." },
    grand_tournament = {
      "Enables the Battle Frontier tournament and its related progression and rewards.",
      "Aktiviert das Kampf-Frontier-Turnier samt Fortschritt und Belohnungen." },
    follower_count = {
      "Selects how many party Pokémon follow the player in the movement chain.",
      "Bestimmt, wie viele Team-Pokémon dem Spieler in der Bewegungskette folgen." },
    follower_order = {
      "Uses party order or the custom order configured in the follower editor.",
      "Verwendet die Team-Reihenfolge oder die eigene Reihenfolge aus dem Begleiter-Editor." },
    ascendant_rules = {
      "Selects the battle rules used by the repeatable Ascendant Challenge.",
      "Wählt die Kampfregeln der wiederholbaren Ascendant-Challenge." },
    yellow_partner_presentation = {
      "Chooses Ascendant's partner layout or Yellow's original centered Pikachu presentation.",
      "Wählt Ascendants Partner-Layout oder Gelbs ursprüngliche zentrierte Pikachu-Darstellung." },
    yellow_raichu_face_style = {
      "Chooses corrected Ascendant Raichu portraits or animated faces adapted from the classic Yellow-style sheet.",
      "Wählt korrigierte Ascendant-Raichu-Porträts oder animierte Gesichter aus dem klassischen Gelb-Stil." },
  }

  local legendNames = {
    legend_articuno = "Articuno", legend_zapdos = "Zapdos",
    legend_moltres = "Moltres", legend_mewtwo = "Mewtwo",
    legend_raikou = "Raikou", legend_entei = "Entei",
    legend_suicune = "Suicune", legend_lugia = "Lugia",
    legend_ho_oh = "Ho-Oh", legend_celebi = "Celebi", legend_mew = "Mew",
  }
  local eventNames = {
    event_university_magikarp = "University Magikarp",
    event_stamp_fearow = "Stamp Fearow",
    event_flying_pikachu = "Flying Pikachu",
    event_stamp_rapidash = "Stamp Rapidash",
    event_surfing_pikachu = "Surfing Pikachu",
  }

  local H = {}
  function H.entry(key)
    local row = rows[key]
    if row then return { en = row[1], de = row[2], restart = row[3] == true } end
    if legendNames[key] then
      return {
        en = "Controls whether and in which profile " .. legendNames[key]
          .. " appears in Ascendant's legendary content.",
        de = "Steuert, ob und in welchem Profil " .. legendNames[key]
          .. " in Ascendants legendären Inhalten erscheint.",
      }
    end
    if eventNames[key] then
      return {
        en = "Enables or disables the historical " .. eventNames[key]
          .. " event encounter.",
        de = "Aktiviert oder deaktiviert die historische Event-Begegnung "
          .. eventNames[key] .. ".",
      }
    end
    return {
      en = "Controls this Kanto Ascendant feature.",
      de = "Steuert diese Kanto-Ascendant-Funktion.",
    }
  end

  function H.text(key, current)
    local row = H.entry(key)
    local body = tr(row.en, row.de)
      .. "\n" .. tr("CURRENT: ", "AKTUELL: ") .. tostring(current or "-")
    if row.restart then
      body = body .. "\n" .. tr(
        "A game restart is required after changing this setting.",
        "Nach einer Änderung ist ein Neustart des Spiels erforderlich.")
    end
    return body
  end

  function H.restartRequired(key)
    return H.entry(key).restart == true
  end

  return H
end
