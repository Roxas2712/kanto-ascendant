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
      "Raises trainer levels. Bonuses begin smaller and reach full strength as you earn badges. With DIFFICULTY ROSTERS enabled, higher settings also give story Gym Leaders stronger and more complete authored teams. Wild levels follow this curve only when WILD LEVEL SCALING is ON. EXTREME also blocks items in trainer battles.",
      "Erhöht Trainerlevel. Die Boni starten kleiner und erreichen mit Deinen Orden ihre volle Stärke. Mit SCHWIERIGKEITS-TEAMS erhalten Arenaleiter auf höheren Stufen zusätzlich stärkere und vollständigere handgebaute Teams. Wildlevel folgen dieser Kurve nur mit WILD-LEVEL-SKALIERUNG AN. EXTREM sperrt zusätzlich Items in Trainerkämpfen." },
    story_difficulty_rosters = {
      "Enables the separate story Gym roster card on HIGH through EXTREME: authored thematic team additions, legal move roles, limited leader healing and stronger AI. STANDARD preserves the official roster. OFF removes only this card; numerical Difficulty and Adaptive Trainer Levels remain active.",
      "Aktiviert die eigene Arenateam-Card auf HOCH bis EXTREM: handgebaute thematische Ergänzungen, legale Attackenrollen, begrenzte Arenaleiter-Heilung und stärkere KI. STANDARD bewahrt das offizielle Team. AUS entfernt nur diese Card; numerische Schwierigkeit und adaptive Trainerlevel bleiben aktiv." },
    battle_generation_mode = {
      "AUTO follows the highest generation proven by your journey. GEN I-VII selects an unlocked ruleset manually. Approved gift Pokemon remain usable in earlier rulesets with their permitted moves. Historical legal TM/tutor moves remain learnable. OFF is the hard R/B/Y fallback; incompatible Pokemon and moves stay safely stored.",
      "AUTO folgt der höchsten durch Deinen Spielstand belegten Generation. GEN I-VII wählt ein freigeschaltetes Regelwerk manuell. Freigegebene Geschenk-Pokémon bleiben mit ihren erlaubten Attacken auch in früheren Regelwerken nutzbar. Frühere legale TM-/Tutorattacken bleiben erlernbar. AUS ist der harte R/B/Y-Rückfall; unpassende Pokémon und Attacken bleiben sicher gespeichert." },
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
      "Steuert Überraschungstrainer nur in einem aktiven Legacy-Neues-Spiel-Plus. SELTEN ist Standard; NIE stoppt neue Kämpfe, liefert aber bereits vorgemerkte Preise weiter aus." },
    surprise_dialogue_matrix = {
      "Enables the bilingual Surprise Trainer dialogue card with trainer-class voices, title forms of address, return, Legacy and League context, and result-specific farewells. OFF restores the previous generic dialogue without changing battles, rewards or earned titles.",
      "Aktiviert die zweisprachige Überraschungstrainer-Dialog-Card mit Klassenstimmen, Titelanrede, Wiederbegegnungs-, Vermächtnis- und Liga-Kontext sowie passenden Abschieden. AUS stellt die bisherigen allgemeinen Dialoge wieder her, ohne Kämpfe, Belohnungen oder verdiente Titel zu verändern." },
    surprise_trainer_mega = {
      "Allows a rare, announced post-League Surprise Trainer Mega Evolution only when this save already owns the Mega Ring and the exact official Stone. Active loss relief disables it. OFF removes only this opponent feature.",
      "Erlaubt seltene, vorher angekündigte Mega-Entwicklungen bei Überraschungstrainern nach der Liga, aber nur mit bereits vorhandenem Mega-Ring und exakt passendem offiziellen Stein. Aktive Niederlagenhilfe verhindert sie. AUS entfernt nur diese Gegnerfunktion." },
    surprise_team_fairness = {
      "Checks Surprise Trainer teams against a documented base-stat window, repairs overly strong members only within their legal evolution family and rebuilds moves from active level, machine and tutor sources. It never reads player types. OFF restores the previous team builder.",
      "Prüft Überraschungstrainer-Teams gegen ein dokumentiertes Basiswerte-Fenster, stuft zu starke Mitglieder nur innerhalb ihrer legalen Entwicklungsfamilie zurück und baut Attacken aus aktiven Level-, Maschinen- und Tutorquellen. Spielertypen werden nie gelesen. AUS stellt den bisherigen Team-Builder wieder her." },
    hoenn_encounters = {
      "After receiving Hoenn Honey and the Hoenn Dex, allows the character-bound Hoenn habitat layer in a standard journey. Legacy New Game+ uses Wanderer traces instead; Legendary and Mythical Pokémon never enter the ordinary pool.",
      "Erlaubt nach Erhalt von Hoenn-Honig und Hoenn-Dex die charaktergebundene Hoenn-Habitatschicht im Standardspiel. Legacy-Neues-Spiel-Plus nutzt stattdessen Wandertrainer-Spuren; Legendäre und Mysteriöse Pokémon gelangen nie in den normalen Pool." },
    hoenn_level_mode = {
      "Sets levels for ordinary Hoenn visitors: ROUTE follows the native encounter, BADGES follows safe story progress, and PARTY follows the rounded active-party average. Evolution minimums are always respected.",
      "Bestimmt die Level gewöhnlicher Hoenn-Gäste: ROUTE folgt der nativen Begegnung, ORDEN dem sicheren Storyfortschritt und TEAM dem gerundeten Durchschnitt des aktiven Teams. Mindestlevel für Entwicklungen gelten immer." },
    hoenn_trace_presentation = {
      "Presents a newly won Wanderer clue once on the field and gives the resulting rare, catchable Hoenn trace encounter its own music. OFF removes only the announcement and music; discovered traces, encounter odds, pity, catches and save receipts remain unchanged.",
      "Zeigt eine neu gewonnene Wandertrainer-Spur einmal im Feld an und gibt der daraus entstehenden seltenen, fangbaren Hoenn-Spurbegegnung eigene Musik. AUS entfernt nur Ansage und Musik; entdeckte Spuren, Chancen, Pechschutz, Fänge und Save-Belege bleiben unverändert." },
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
      "Animates supported Crystal battle pictures and every available Gen-II-Neo view on VASC MAP, DISK and ARENA. Missing later animations remain crisp static 2D; classic 2D battles and the team menu never animate.",
      "Animiert unterstützte Kristall-Kampfbilder und jede verfügbare Gen-II-Neo-Ansicht auf VASC-KARTE, -DISK und -ARENA. Fehlende spätere Animationen bleiben scharfes, statisches 2D; klassische 2D-Kämpfe und das Team-Menü bewegen sich nie." },
    non_crystal_pixel_2d = {
      "Uses the reviewed Gen-II-style front/back catalog for #252-721 in classic 2D battles. No animated 3DS/GIF view is used. OFF restores the previous provider.",
      "Verwendet in klassischen 2D-Kämpfen den geprüften Gen-II-Pixelkatalog für #252-721 mit eigener Front- und Rückenansicht. Animierte 3DS-/GIF-Ansichten bleiben dort ausgeschlossen. AUS stellt den vorherigen Provider wieder her.", true },
    classic_2d_sprite_connector = {
      "Fits every static 2D front and back to the established Gen-I battle tracks: fronts keep the opponent baseline, while backs are cropped from the lower half, scaled by comparable Kanto species and anchored to the player's HUD. OFF restores the provider's raw placement.",
      "Passt jede feste 2D-Front und -Rückseite an die etablierten Gen-I-Kampfspuren an: Fronten bleiben auf der Gegner-Grundlinie, Rückseiten werden aus der unteren Hälfte zugeschnitten, nach vergleichbaren Kanto-Arten skaliert und an der Spieler-HUD verankert. AUS stellt die rohe Platzierung des Anbieters wieder her.", true },
    non_crystal_voxel_animations = {
      "Uses the reviewed Gen-II-Neo normal/Shiny animations only in VASC MAP, DISK and ARENA while CRYSTAL ANIMATION is on. A missing real animation uses the selected static 2D front. Classic 2D, Mega forms, Gorochu and #001-251 remain untouched.",
      "Verwendet die geprüften normalen und schillernden Gen-II-Neo-Animationen nur in VASC-KARTE, -DISK und -ARENA, solange KRISTALL-ANIMATION eingeschaltet ist. Fehlt eine echte Animation, erscheint die gewählte statische 2D-Front. Klassisches 2D, Mega-Formen, Gorochu und #001–251 bleiben unangetastet.", true },
    pokemon_sprite_style = {
      "Chooses the global Pokémon artwork family. CRYSTAL 2D is the complete Ascendant presentation; individual screens can still be disabled below.",
      "Wählt die globale Pokémon-Grafikfamilie. CRYSTAL 2D ist Ascendants vollständige Darstellung; einzelne Bereiche lassen sich darunter weiterhin abschalten.", true },
    character_sprite_style = {
      "Chooses Kanto Ascendant's reviewed project character set or the original edition characters for field scenes.",
      "Wählt Kanto Ascendants geprüfte eigene Figuren oder die ursprünglichen Editionsfiguren für Spielszenen.", true },
    trainer_portrait_style = {
      "Chooses approved Kanto Ascendant HD standees or untouched edition-original Gen-I portraits. Red uses the ROM-derived native front where no project-authored front is selected; project-authored throw and Voxel art remains available.",
      "Wählt bestätigte Kanto-Ascendant-HD-Figuren oder unveränderte editionsgebundene Gen-I-Porträts. Rot nutzt ohne eigene Front das aus der ROM erzeugte Original; eigene Wurf- und Voxelbilder bleiben erhalten.", true },
    animated_title_trainers = {
      "ON is the default and gives Red, Green and Blue two alternating, subtle HD title motions on a capable renderer. OFF restores the Classic 6.6 title exactly. An older renderer or a missing HD standee safely uses Classic for this start without changing the saved ON choice.",
      "AN ist Standard und gibt Rot, Grün und Blau auf einer geeigneten Engine zwei abwechselnde, dezente HD-Bewegungen im Titel. AUS stellt exakt den klassischen 6.6-Titel her. Eine ältere Engine oder eine fehlende HD-Figur nutzt für diesen Start sicher den klassischen Titel, ohne die gespeicherte AN-Wahl zu ändern.", true },
    title_visual_theme = {
      "Chooses an asset-free title palette. CLASSIC preserves the current 6.6 title, TRAINER TRIO follows the visible Red, Green, Blue or Yellow identity, and MONO STAGE leaves the full-colour trainer over a neutral monochrome stage. Missing, invalid or failed themes use Classic without changing the saved choice. Music is never changed.",
      "Wählt eine Titelpalette ohne neue Bilddateien. KLASSISCH bewahrt den aktuellen 6.6-Titel, TRAINER-TRIO folgt der sichtbaren roten, grünen, blauen oder gelben Figur und MONO-BÜHNE lässt die farbige Figur über einer neutralen Schwarzweiß-Bühne stehen. Fehlende, ungültige oder fehlerhafte Designs nutzen Klassisch, ohne die gespeicherte Wahl zu ändern. Musik bleibt immer unverändert.", true },
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
      "Hauptschalter für Ascendants erweiterten Beutel. Die genaue Aufteilung wird mit BEUTEL-DESIGN gewählt.", true },
    ascendant_bag_mode = {
      "Chooses the Bag's complete presentation and capacity. FIRERED POCKETS is the new default and preserves six pockets, 999 slots, Field Kit, Quick Select, battle filtering, item moving and protection. KASC SKIN retains the previous layout; GAME DEFAULT yields to the engine Bag. OFF hands ownership to an external compatible mod.",
      "Wählt Darstellung und Kapazität des Beutels. FIRERED-FÄCHER ist der neue Standard und behält sechs Fächer, 999 Plätze, Feld-Kit, Schnellwahl, Kampffilter, Item-Verschieben und Schutzregeln. KASC-SKIN behält die bisherige Ansicht; SPIELSTANDARD übergibt an den Engine-Beutel. AUS übergibt an eine kompatible externe Mod.", true },
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
      "Master switch for Kanto Ascendant menu skins. OFF preserves the previous behavior and yields PC/storage presentation to the engine after restart.",
      "Hauptschalter für Kanto-Ascendant-Menü-Skins. AUS behält das bisherige Verhalten und übergibt PC/Lagerung nach einem Neustart an die Engine.", true },
    pc_interface_style = {
      "Chooses the PC presentation. FIRERED / LEAFGREEN keeps the authentic 480-pixel organizer. FIRERED / LEAFGREEN WIDE adds a native 512 by 288 layout with a larger grid, persistent detail/help panels and remembered navigation. KANTO ASCENDANT restores the previous blue/cream layout. GAME DEFAULT yields to the untouched engine PC. Missing FireRed artwork falls back safely to Kanto Ascendant.",
      "Wählt die PC-Darstellung. FIRERED / LEAFGREEN behält den authentischen 480-Pixel-Organizer. FIRERED / LEAFGREEN WIDE ergänzt eine echte 512-mal-288-Ansicht mit größerem Raster, dauerhaften Detail-/Hilfefeldern und gemerkter Navigation. KANTO ASCENDANT stellt die bisherige blau-cremefarbene Ansicht wieder her. SPIELSTANDARD nutzt den unveränderten Engine-PC. Fehlende FireRed-Grafik fällt sicher auf Kanto Ascendant zurück." },
    legacy_bank_interface_style = {
      "Chooses the Legacy Bank presentation. FOLLOW PC mirrors the normal PC setting. FIRERED / LEAFGREEN keeps the authentic organizer; FIRERED / LEAFGREEN WIDE adds the native 512 by 288 Bank layout. KANTO ASCENDANT restores the compact list. The Bank remains the same archive and all NG+ withdrawal locks still apply.",
      "Wählt die Darstellung der Vermächtnisbank. WIE PC übernimmt die normale PC-Einstellung. FIRERED / LEAFGREEN behält den authentischen Organizer; FIRERED / LEAFGREEN WIDE ergänzt die echte 512-mal-288-Bankansicht. KANTO ASCENDANT stellt die kompakte Liste wieder her. Das Archiv bleibt identisch und alle NG+-Entnahmesperren gelten weiter." },
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
    hoenn_roamers = {
      "Lets Latias and Latios roam Kanto after Hoenn Honey and the Hoenn Dex have unlocked normal Hoenn field access. Their route, DVs, HP and status survive reloads.",
      "Lässt Latias und Latios durch Kanto wandern, sobald Hoenn-Honig und Hoenn-Dex den normalen Hoenn-Feldzugang öffnen. Route, DVs, KP und Status überstehen Neuladen." },
    hoenn_roamer_flee = {
      "Allows Latias and Latios to flee after their first action. Damage and status remain for the next encounter; a knockout starts a three-map recovery.",
      "Erlaubt Latias und Latios nach ihrer ersten Aktion zu fliehen. Schaden und Status bleiben bis zur nächsten Begegnung; nach einem K. o. erholen sie sich über drei Kartenwechsel." },
    hoenn_regi_sanctums = {
      "Enables three removable Hoenn sanctums reached through hidden wall researchers in the Cinnabar volcano, Victory Road and Seafoam Islands.",
      "Aktiviert drei abschaltbare Hoenn-Sanktuarien hinter versteckten Wandforschern im Zinnober-Vulkan, in der Siegesstraße und auf den Seeschauminseln." },
    hoenn_moltres_volcano = {
      "Moves the APEX Moltres hunt from Victory Road to a volcanic puzzle island reached with the Cinnabar expedition scientist. The event must be completed again in each playthrough.",
      "Verlegt die APEX-Lavados-Jagd von der Siegesstraße auf eine Vulkan-Rätselinsel, die der Zinnober-Expeditionsforscher anfährt. Das Ereignis muss in jedem Durchlauf erneut abgeschlossen werden." },
    hoenn_endgame_access_puzzles = {
      "Places the Cinnabar expedition scientist and the three unmarked wall researchers that physically lead to Moltres, Regirock, Regice, Registeel and later Deoxys. Turning it off removes only these access hosts and safely preserves completed events.",
      "Platziert den Zinnober-Expeditionsforscher und die drei unmarkierten Wandforscher, die tatsächlich zu Lavados, Regirock, Regice, Registeel und später Deoxys führen. AUS entfernt nur diese Zugänge und erhält abgeschlossene Ereignisse sicher." },
    hoenn_legend_portals = {
      "Replaces the completed hidden-evolution teaser door with removable RED/Groudon, BLUE/Kyogre and GREEN/Rayquaza capture chambers after the 130-species Hoenn foundation is owned.",
      "Ersetzt die abgeschlossene Teaser-Tür der versteckten Entwicklungen durch abschaltbare Fangkammern für ROT/Groudon, BLAU/Kyogre und GRÜN/Rayquaza, sobald das Hoenn-Fundament aus 130 Arten im Besitz ist." },
    hoenn_birth_island = {
      "Enables Birth Island and its triangle sequence. The Cinnabar expedition scientist offers it only after this playthrough has completed both Moltres and Regirock and the persistent Hoenn prerequisites are met.",
      "Aktiviert die Entstehungsinsel samt Dreieckssequenz. Der Zinnober-Expeditionsforscher bietet sie erst an, wenn in diesem Durchlauf Lavados und Regirock abgeschlossen wurden und die dauerhaften Hoenn-Voraussetzungen erfüllt sind." },
    hoenn_jirachi_finale = {
      "Enables the final wish voyage, repeatable Jirachi capture and Hoenn Ascendant certificate after 134/134 required Hoenn species, all paths and all portal receipts are complete.",
      "Aktiviert die abschließende Wunschfahrt, den wiederholbaren Jirachi-Fang und das Hoenn-Aszendent-Zertifikat, sobald 134/134 Hoenn-Pflichtarten, alle Pfade und alle Portalbelege vollständig sind." },
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
    gift_codes_enabled = {
      "Enables the isolated offline Gift Code Card. OFF hides entry and pauses redemption, pending delivery and archive repair without deleting claimed Pokémon or digest receipts. Turning it ON resumes recovery.",
      "Aktiviert die getrennte Offline-Geschenkcode-Card. AUS blendet die Eingabe aus und pausiert Einlösung, ausstehende Zustellung und Archivreparatur, ohne erhaltene Pokémon oder Digest-Belege zu löschen. EIN setzt die Wiederherstellung fort." },
    starter_habitats_enabled = {
      "Enables the isolated Starter Habitats Card with twelve hidden areas and sixteen entrances. OFF blocks new rumors, reveals, entry and encounters while preserving every discovery and catch receipt; a save inside a habitat is returned safely.",
      "Aktiviert die getrennte Starter-Habitate-Card mit zwölf versteckten Gebieten und sechzehn Zugängen. AUS blockiert neue Gerüchte, Enthüllungen, Eintritte und Begegnungen, erhält aber alle Entdeckungs- und Fangbelege; ein Spielstand im Habitat wird sicher zurückgeführt." },
    legacy_random_partners = {
      "Adds separate RANDOM STARTER POOL and RANDOM GLOBAL routes to the middle ball in Red, Blue and Yellow NG+. Both partners are drawn independently and sealed in the save. OFF removes only both random routes; an already sealed journey remains playable.",
      "Ergänzt am mittleren Ball in Rot, Blau und Gelb NG+ die getrennten Wege ZUFALL STARTERPOOL und ZUFALL GLOBAL. Beide Partner werden unabhängig ausgelost und im Spielstand versiegelt. AUS entfernt nur beide Zufallswege; eine bereits versiegelte Reise bleibt spielbar." },
    legacy_global_babies = {
      "Adds eligible later baby forms through Generation VI to RANDOM GLOBAL once their generation is unlocked. Every included baby evolves into a Generation-I--III species. OFF blocks new draws but preserves sealed saves.",
      "Ergänzt ZUFALL GLOBAL nach Freischaltung ihrer Generation um passende spätere Babyformen bis Generation VI. Jede enthaltene Babyform entwickelt sich zu einer Art aus Generation I bis III. AUS sperrt neue Auslosungen, erhält aber versiegelte Spielstände." },
    rocket_story = {
      "Enables Ascendant's additional Team Rocket story progression.",
      "Aktiviert Ascendants zusätzliche Team-Rocket-Handlung." },
    rocket_raids = {
      "Enables Rocket recovery raids after the Earth Badge. Every theft asks first and defaults to NO. Local Boxes are the normal source; an empty Box may explicitly use Legacy Bank or trailing Party slots while keeping one usable battler. Turning this OFF returns all held Pokemon safely.",
      "Aktiviert Rocket-Rückholraids nach dem Erdorden. Jeder Diebstahl fragt vorher und steht zunächst auf NEIN. Normalerweise gilt die lokale Box; bei leerer Box können ausdrücklich Vermächtnisbank oder hintere Teamplätze gewählt werden, wobei ein kampffähiges Pokémon bleibt. AUS gibt alle festgehaltenen Pokémon sicher zurück." },
    late_species_67 = {
      "Enables the isolated late-evolution and Rocket-capture species Card. OFF after restart removes its registrations and blocks new Darkrai, Genesect, Regigigas and Zygarde 10% raid captures without deleting existing save receipts.",
      "Aktiviert die getrennte Card für späte Entwicklungen und Rocket-Fangarten. AUS entfernt nach dem Neustart ihre Registrierungen und sperrt neue Raid-Fänge von Darkrai, Genesect, Regigigas und Zygarde 10 %, ohne vorhandene Speicherbelege zu löschen." },
    fairy_affection_67 = {
      "Enables the isolated Affection Ribbon and Sylveon Card. OFF after restart removes its item, evolution and species registrations; Rocket raids continue and simply omit the unavailable special reward.",
      "Aktiviert die getrennte Card für Zuneigungsband und Feelinara. AUS entfernt nach dem Neustart deren Item-, Entwicklungs- und Artenregistrierung; Rocket-Raids laufen weiter und lassen die nicht verfügbare Sonderbelohnung aus." },
    grand_tournament = {
      "Enables the Battle Frontier tournament and its related progression and rewards.",
      "Aktiviert das Kampf-Frontier-Turnier samt Fortschritt und Belohnungen." },
    life_of_rival = {
      "Loads A Rival's Life as an isolated optional Card: contextual Red, Blue and Green road meetings, battles and parallel journeys after its progression gates. OFF cold-disables only these optional appearances after restart; native story rivals and their battles remain unchanged.",
      "Lädt Rivalenleben als getrennte optionale Card: kontextbezogene Begegnungen, Kämpfe und Parallelreisen von Rot, Blau und Grün nach ihren Fortschrittssperren. AUS deaktiviert nach einem Neustart ausschließlich diese optionalen Auftritte; Rivalen und Kämpfe der Hauptgeschichte bleiben unverändert." },
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
