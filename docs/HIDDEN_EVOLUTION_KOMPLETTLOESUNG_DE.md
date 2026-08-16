# Hidden Evolution 6.5 – deutsche Komplettlösung

Stand: 16. August 2026. Diese Lösung beschreibt Kanto Ascendant
`6.5.3-rc.1` mit den getrennten Rätselstatuen und Etagen-Lichtsteinen.

## Karteninventar und Grundregeln

Der Runtimepfad besitzt **16 eindeutige Hidden-Evolution-Karten**. Der
gemeinsame Tunnel `KA_HEVO_TUNNEL_ALL` (Index 1920) enthält drei voneinander
isolierte Schächte; zwischen zwei Schächten liegt mindestens eine volle
native Kamerabreite solider CAVERN-Fels, sodass kein fremder Schacht ins
Sichtfeld geraten kann. Er ist keine dreifach registrierte Karte. Zusammen
mit Route 22, Route 24 und Route 3 umfasst das Editorprojekt 19 Karten.

| Pfad | Runtimekarten |
|---|---|
| Gemeinsam | `KA_HEVO_TUNNEL_ALL` (1920), `KA_HEVO_SHARED_SEALED_ANTECHAMBER` (1948) |
| RED | `KA_HEVO_RED_UPPER` (1930), `KA_HEVO_RED_ABYSS` (1931), `KA_HEVO_RED_RECOVERY` (1932), `KA_HEVO_RED_LOWER` (1933), `KA_HEVO_RED_SHRINE` (1934) |
| BLUE | `KA_HEVO_BLUE_FROST_THRESHOLD` (1940), `KA_HEVO_BLUE_FROST_HALL` (1941), `KA_HEVO_BLUE_GLACIER_MAZE` (1942), `KA_HEVO_BLUE_TIDAL_DEPTHS` (1943), `KA_HEVO_BLUE_KYOGRE_SHRINE` (1944) |
| GREEN | `KA_HEVO_GREEN_THRESHOLD` (1950), `KA_HEVO_GREEN_GROVE` (1951), `KA_HEVO_GREEN_MIST` (1952), `KA_HEVO_GREEN_RAYQUAZA_SHRINE` (1953) |

Für alle drei Prüfungen gelten dieselben Sicherheitsregeln:

- Die fünf Statuen müssen in ihrer jeweiligen Reihenfolge gelöst werden. Eine
  falsche Antwort verbraucht nur die aktuelle Frage; anschließend erscheint
  eine neue, noch nicht verwendete Frage. Deshalb ist der Antworttext
  maßgeblich, nicht eine feste Menüposition.
- Die fünf Rätselobjekte sind graue, unbewegliche Monsterstatuen. Sie prüfen
  Wissen aus Kanto, Johto, Sinnoh und allgemeines Pokémon-Wissen und zählen
  ausschließlich für den jeweiligen Prüfungsfortschritt.
- Die gelben Relikte sind davon unabhängige **Etagen-Lichtsteine**. Drei
  Lichtsteine pro Sicht-Etage erweitern den kleinen Sichtbereich schrittweise;
  sie dürfen in beliebiger Reihenfolge aktiviert werden und zählen niemals als
  gelöste Rätselstatue oder Siegelbedingung.
- Fragen und richtige Antwortpositionen werden spielstandgebunden gemischt.
  Bereits angezeigte oder beantwortete Fragen sowie gelöste Statuen bleiben
  beim Speichern, Laden und Aktualisieren erhalten.
- Jede Frage erscheint zuerst vollständig im normalen Textfenster. Danach
  wiederholt das große Prüfungsfenster dieselbe Frage über den Antworten. Es
  gibt hier kein Zeitlimit; mit B verlässt du die Auswahl, ohne eine Antwort
  oder die offene Frage zu verbrauchen.
- `BLITZ` hebt Dunkelheit oder GREEN-Nebel nicht auf. Der Feldversuch erzeugt
  nur den Hinweis, dass ein kleines Licht aufflackert, diese Dunkelheit bzw.
  diesen Nebel aber nichts durchdringt.
- Reset-/Rückkehrmarken setzen die aktuelle Position und lose Felsen zurück,
  niemals gelöste Statuen, bereits aktivierte Schalter oder beanspruchte
  Geheimnisse.
- Die drei Megasteine sind optional, einmalig, wiederauffindbar und vom
  normalen Dungeonabschluss getrennt. Ein noch nicht verfügbarer Steinkoffer
  darf den Fund sicher vormerken.

## RED – Basaltprüfung

### Vorbereitung und Eingang

Nimm ein Pokémon mit `STÄRKE` und `SURFER` mit. Der Route-22-Eingang liegt als
schwarzer Haarriss auf der geraden nördlichen Felswand bei `(35,1)`. Stelle
dich auf `(35,2)`, blicke nach Norden und untersuche die Wand. Im gemeinsamen
Tunnel folgt RED ausschließlich seinem isolierten Schacht nach oben; die
anderen beiden Schächte sind nicht erreichbar.

Belege: [Route-22-Riss](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/00_route22_hairline_fissure.png) ·
[final getrennter RED-Schacht](../qa/hidden_evolution_shared_tunnel_spacing_final_20260811/2d/ka_hevo_tunnel_all_red_shaft.png)

### 1. Oberer Basaltgang – zwei Erinnerungen, drei Gewichte

Du startest unten bei `(3,33)`. Der direkte Nordostweg ist absichtlich durch
mehrere Rückschleifen unterbrochen.

1. Verlasse den Hauptpfad an den langen blinden Seitenarmen und löse Statue 1
   bei `(3,6)` sowie Statue 2 bei `(29,4)` in dieser Reihenfolge.
2. Aktiviere `STÄRKE`. Schiebe die drei Basaltgewichte in ihre Fassungen:
   A von `(13,29)` nach `(19,29)`, B von `(21,25)` nach `(21,19)` und C von
   `(31,17)` nach `(37,17)`. Die drei schmalen Umgehungen öffnen sich erst
   nach dem jeweiligen Einrasten.
3. Bei einem Fehler benutze die Reset-Rune nahe dem Eingang. Bereits
   erleuchtete Statuen und eingerastete Schalter bleiben vermerkt.
4. Drei deutlich gerissene Randfelder sind freiwillige Stürze. Jeder Sturz
   landet sicher in der Glut-Zuflucht und besitzt einen echten Rückweg.
5. Der reguläre Ausgang oben rechts bei `(45,3)` führt in den Abgrundring.

Belege: [Statue 1 vor der Lösung](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/03a_statue1_hidden_niche_sight0.png) ·
[drei Strength-Fassungen](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/05d_strength_socket_C.png) ·
[Sturz und Zuflucht](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/06a_upper_fall_1_recovery.png)

### 2. Abgrundring und Glut-Zuflucht – Erinnerungen 3/4 und LOHGOCKNIT

Im Abgrundring liegen vier weitere echte Fallstellen. Sie sind Risiken und
Erkundungsabzweige, niemals die einzige Fortschrittsroute.

1. Folge dem gewundenen Rand zunächst zur westlichen Sackgasse und löse
   Statue 3 bei `(11,4)`.
2. Kehre zum Ring zurück und suche die getrennte östliche Nische mit Statue 4
   bei `(27,10)`.
3. Jeder der vier Stürze führt zur Glut-Zuflucht. Die vier Landebuchten haben
   eigene Leiter-/Runenpads zurück zum Abgrundring.
4. In der Zuflucht weist die Glutrune auf den mittleren Seitenarm. Folge ihm
   bis zur warmen Mulde bei `(33,9)` und nimm optional `BLAZIKENITE`
   (`LOHGOCKNIT`). Speichere und lade neu; die leere Mulde bestätigt die
   einmalige, persistente Vergabe.
5. Verlasse den Abgrundring über `(45,3)` in den unteren Basaltgang. Die
   Zuflucht besitzt ebenfalls einen sicheren Anschluss dorthin.

Belege: [Statue 3](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/09a_statue3_hidden_niche_sight2.png) ·
[vier Abgrundstürze](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/08_f_abyss_fall_4_recovery.png) ·
[LOHGOCKNIT](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/07a_recovery_blazikenite_claim.png) ·
[nach Save/Reload](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/07b_recovery_after_secret_reload.png)

### 3. Untere Spalte – schwarzer Strom und Erinnerung 5

Die südliche und nördliche Felsspur sind durch eine echte Wasserzone getrennt.

1. Folge der schmalen Südbank bis zur markierten Uferkante und setze
   `SURFER` ein. Quere den schwarzen Strom auf der geraden sicheren Linie.
2. Laufe auf der Nordseite nicht sofort zum Ausgang. Der lange westliche
   Seitenarm windet sich mehrfach zurück und endet erst bei Statue 5 `(5,6)`.
3. Nach der fünften richtigen Antwort bleibt ein langer Rückweg über die
   Nordbank. Der Schrein öffnet nur, wenn alle fünf Statuen und alle drei
   Basaltfassungen gelöst sind.
4. Der Ausgang `(45,3)` führt in den Groudon-Schrein.

Belege: [vor SURFER](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/10a_lower_before_surf.png) ·
[Statue 5 verborgen](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/10b_statue5_hidden_niche_sight4.png) ·
[langer Rückweg](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/10d_lower_long_return_after_statue5.png)

### 4. Groudon-Schrein, Belohnung und Rückweg

Folge der ein Feld breiten Zeremonialspirale zum Forschungsspeicher bei
`(31,13)`. Er verzeichnet die fünf RED-Pakete: Schützer/Rihornior,
Magmaisierer/Magmortar, Walzer/Schlurplek, Antik-Kraft/Mamutel und
Scharfzahn/Skorgro. Das Groudon-Siegel bei `(35,11)` öffnet den Pfad zur
versiegelten Vorkammer; hinter der schwarzen Tür erklingt einmal Groudon.

Kehre danach über denselben RED-Pad und alle Etagen in umgekehrter Richtung
zur Route 22 zurück. Save/Reload, vollständiger Rückweg und Riss-Wiedereintritt
lassen Sichtstufen, Fassungen, Reward und Geheimfund bestehen.

Belege: [Schreinspirale](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/11b_shrine_long_spiral_before_reward.png) ·
[Groudon-Endkammer](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/12b_groudon_end_chamber.png) ·
[Route-22-Rückkehr](../qa/hidden_evolution_red_release_full_final_v2_20260811/2d/13_route22_return.png) ·
[Voxel-Vollrun](../qa/hidden_evolution_red_release_full_voxel_final_v1_20260811/voxel/18_route22_return_after_reentry.png)

## BLUE – Frostprüfung

### Vorbereitung und Eingang

Nimm `STÄRKE` mit; `SURFER` ist nur für das optionale `SWAMPERTITE`
erforderlich. Der feine Riss liegt auf der geraden Route-24-Felswand bei
`(10,3)`. Stelle dich auf `(10,4)`, blicke nach Norden und untersuche ihn.
Folge im gemeinsamen Tunnel nur dem BLUE-Schacht bis zur Frostschwelle.

Kanonischer Belegsatz: [REPORT](../qa/hidden_evolution_blue_release_final_20260811/REPORT.md) ·
[Route-24-Riss](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/00_route24_hairline_fissure.png) ·
[final getrennter Shared-Einstieg](../qa/hidden_evolution_shared_tunnel_spacing_final_20260811/2d/01_shared_tunnel_blue_branch.png)

### 1. Frostschwelle und Frosthalle

Die Frostschwelle beginnt bei Sichtstufe 0. `BLITZ` ist hier absichtlich
wirkungslos; orientiere dich an den kurzen Felssegmenten und Rückschleifen.
Der obere Ausgang führt zur Halle.

1. Suche in der Halle den eigenen Sackgassenarm von Statue 1 bei `(25,22)`.
2. Schiebe nach der richtigen Antwort den Hallenfelsen von `(13,25)` nach
   `(27,25)` auf die runde Rune. Der Reset-Stein `(5,31)` setzt nur den
   ungelösten Felsen zurück.
3. Nimm den östlichen Ausgang in das Gletscherlabyrinth.

Belege: [Sight 0](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/02_threshold_dense_darkness_sight0.png) ·
[wirkungsloser BLITZ](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/03_threshold_after_ineffective_flash.png) ·
[Statue 1](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/06a_hall_statue1_before_sight0.png) ·
[Hallenrune gelöst](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/11_hall_boulder_switch_after.png)

### 2. Großes Eisfeld – Statuen 2/3, Strength und sechs Fallrouten

Auf dem zusammenhängenden Eis wird bis zur nächsten trockenen Ablage
gerutscht. Ein schwarzes Auge ist ein echtes Fallloch und setzt den Abschnitt
sicher an seinen Anfang zurück. Die sechs finalen Lochzellen lauten:

`(41,6)`, `(42,7)`, `(4,16)`, `(3,17)`, `(29,28)`, `(30,29)`.

1. Nutze trockene Felsinseln als Bremsfelder und erreiche Statue 2 bei
   `(11,5)` in ihrem nördlichen Seitenarm.
2. Kehre auf das Eis zurück und suche den getrennten tiefen Arm zu Statue 3
   bei `(37,31)`.
3. Schiebe den Gletscherfelsen von `(29,25)` nach `(35,25)`. Die Rune öffnet
   den nächsten Abschnitt; der Reset-Stein `(27,27)` bewahrt gelöste Stufen.
4. Probiere nicht, einen Fehler auf dem Eis zu korrigieren: Die falsche
   Rutschlinie endet bewusst im Loch und beginnt anschließend wieder am
   Abschnittseingang.

Belege: [zusammenhängendes Eisfeld](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/12e_glacier_contiguous_ice_field_sight3.png) ·
[falsche Rutschlinie](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/13a_wrong_slide_line_to_native_hole.png) ·
[sechs Rücksetzungen](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/14_hole_06_30_29_reset.png) ·
[Gletscherrune gelöst](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/18_glacier_boulder_switch_after.png)

### 3. Gezeitentiefe – Statuen 4/5 und SUMPEXNIT

1. Löse Statue 4 im westlichen Seitenarm bei `(3,19)`.
2. Schiebe den Tiefenfelsen von `(35,19)` nach `(41,19)` und folge dem neu
   geöffneten trockenen Weg.
3. Löse Statue 5 im weit entfernten östlichen Arm bei `(47,9)`. Erst danach
   ist der Schreinweg freigegeben.
4. Optional: Kehre zur südlichen Uferlippe zurück, setze `SURFER` ein und
   umrunde die Wasserbucht bis zur Reliktinsel. Untersuche das blaue Relikt
   bei `(21,29)`, um `SWAMPERTITE` (`SUMPEXNIT`) zu sichern. Surfe auf dem
   gleichen Weg zurück und prüfe die Einmaligkeit per Save/Reload.

Belege: [Statue 4](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/20a_depths_west_sidearm_only.png) ·
[Statue 5](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/21a_depths_east_sidearm_only.png) ·
[Surf nach rechts](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/27b_depths_surf_mid_right.png) ·
[SUMPEXNIT](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/29_depths_swampertite_claim.png) ·
[nach Reload](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/31_depths_after_secret_reload.png)

### 4. Kyogre-Schrein, Belohnung und Rückweg

Der blaue Speicher `(19,9)` verzeichnet Magnetfeld/Magnezone,
Stromisierer/Elevoltek, Eisfeld/Glaziola, Scharfklaue/Snibunna und
Dubiosdisc/Porygon-Z. Am schwarzen Siegel `(19,3)` antwortet Kyogre. Nimm den
BLUE-Pad aus der Vorkammer zurück und laufe Gezeitentiefe, Gletscher, Halle,
Schwelle und gemeinsamen Tunnel vollständig rückwärts bis Route 24. Der
erneute Risseinstieg muss Sight 5 und alle gelösten Schalter behalten.

Belege: [Reward](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/34_shrine_reward_recorded.png) ·
[Vorkammer](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/35_shared_sealed_antechamber_blue.png) ·
[Route-24-Rückkehr](../qa/hidden_evolution_blue_release_final_20260811/full_2d_current_v1/2d/43_route24_full_return.png) ·
[finaler Voxel-Reentry](../qa/hidden_evolution_shared_tunnel_spacing_final_20260811/voxel/44_shared_tunnel_reentry.png)

## GREEN – Nebelprüfung

### Vorbereitung, dichter Nebel und Eingang

Für das Wurzelgatter brauchst du zwei gelöste Statuen, den Quellorden und ein
Pokémon/Feldset mit `ZERSCHNEIDER`. `BLITZ` bleibt auch hier wirkungslos.
Außerhalb des kleinen Sichtkreises ist die Welt vollständig durch neutrales,
opakes Dunkelgrau `RGBA 30,30,30,255` ersetzt; die höchstens zwei Pixel breite
Kante liegt innerhalb des Kreises.

Der Haarriss vor dem Mondberg liegt auf der geraden Route-3-Felswand bei
`(41,3)`. Stelle dich auf `(41,4)`, blicke nach Norden und untersuche ihn.
Folge im gemeinsamen Tunnel ausschließlich dem GREEN-Schacht.

Belege: [GREEN-Releasebericht](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/REPORT.md) ·
[Route-3-Riss](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/00_route3_fissure.png) ·
[finaler opaker Nebel Sight 0](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/opaque_outer_v23_targeted_2d/after_opaque_v23/2d/00_grove_sight_0_opaque_exterior.png)

### 1. Nebelschwelle und Wurzelhain – Statuen 1/2

Die Schwelle lehrt die Reihenfolge und führt über mehrere Schleifen zum
Wurzelhain. Merke dir benannte Zeichen; Sporenknospen, Samenhülsen, Tau und
Hakendornen markieren echte Sackgassen und fordern zum Umkehren auf.

1. Verlasse im Hain den Rundweg am südlichen Abzweig und folge dem langen
   toten Arm zu Statue 1 `(21,35)`.
2. Kehre vollständig zur letzten Gabel zurück. Nutze den Mondteich `(31,25)`
   als Landmarke und suche den getrennten nordöstlichen Arm zu Statue 2
   `(55,17)`.
3. Nach zwei richtigen Antworten ist Sichtstufe 2 gespeichert. Gehe durch den
   oberen Warp in den verhüllten Hain.

Belege: [drei Irrwege](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/04b_grove_three_decoy_trails.png) ·
[falsche Antwort](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/05_grove_after_wrong_answer.png) ·
[Mondteich](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/08_grove_moon_pool_landmark.png) ·
[nach Statue 2](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/09_grove_after_statue_2.png)

### 2. Verhüllter Hain – CUT, Statuen 3/4/5 und GEWALDRONIT

1. Prüfe das Wurzelgatter zunächst vorzeitig: Es bleibt geschlossen. Suche
   Statue 3 im langen westlichen Arm bei `(5,25)` und löse sie.
2. Kehre zum Anker `(22,23)` zurück. Mit zwei Blattlichtern, Quellorden und
   echtem `ZERSCHNEIDER` teilt sich die Wurzel dauerhaft; die VM wird nicht
   verbraucht. Der geöffnete Innenzweig vergrößert den erreichbaren Bereich
   von 75 auf 236 Zellen.
3. Optional: Folge hinter der Wurzel dem Hinweis „drei Blattspitzen weisen
   nach Westen“ zur Mittelader und nimm bei `(13,15)` `SCEPTILITE`
   (`GEWALDRONIT`). Save/Reload bestätigt die einmalige Vergabe.
4. Löse Statue 4 in ihrem östlichen Arm bei `(45,21)`.
5. Statue 5 liegt nicht am Ausgang: Nimm den post-CUT-Abzweig in den
   24-Zellen-Sackgassenarm bis `(39,35)`. Danach bleiben 69 Schritte im
   verhüllten Hain und der ganze Schrein; keine Abkürzung setzt dich direkt
   vor das Finale.
6. Das Kronendach bei `(53,5)` öffnet erst mit allen fünf Blattlichtern.

Belege: [Wurzel früh gesperrt](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/07_mist_root_locked_early.png) ·
[echter CUT-Pfad offen](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/12_mist_root_gate_open.png) ·
[GEWALDRONIT](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/14_mist_sceptilite_claimed.png) ·
[Statue 5](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/19_mist_after_statue_5_full_reveal.png) ·
[Kronendach offen](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/20_mist_canopy_open.png)

### 3. Rayquaza-Schrein, Belohnung, Rückweg und Abkürzung

Der Forschungsspeicher `(31,23)` verzeichnet Moosfeld/Folipurba, ein
gemeinsames Antik-Kraft-Paket für Tangoloss+Yanmega, Leuchtstein/Togekiss,
Doppelschlag/Ambidiffel und ein gemeinsames Finsterstein-Paket für
Traunmagil+Kramshef. Das Rayquaza-Siegel `(45,11)` führt zur schwarzen Tür;
dort erklingt einmal Rayquaza.

Kehre über den GREEN-Pad, Schrein, verhüllten Hain, Wurzelhain, Schwelle und
Tunnel zur Route 3 zurück. Ein abschließender Reload und Riss-Wiedereintritt
bewahren Sicht, Wurzel-/Kronendachzustand, Reward und Geheimfund. Erst nach
dem Abschluss führt die geflochtene Wurzel an der Schwelle als sichere
Abkürzung direkt zum Rayquaza-Schrein; ungelöst bleibt sie gesperrt.

Belege: [Reward](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/22_shrine_post_reward.png) ·
[Rayquaza-Ende](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/23_shared_rayquaza_end.png) ·
[Route-3-Rückkehr](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/24_route3_return.png) ·
[Shortcut-Reentry](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/e2e_final_v20_2d/2d/26_shrine_shortcut_reentry.png) ·
[finaler opaker Voxel-Nebel](../qa/hidden_evolution_green_release_20260811/final_user_dense_cut/opaque_outer_v24_targeted_voxel/after_opaque_v24/voxel/02_shrine_sight_5_opaque_exterior.png)

## Gemeinsame versiegelte Vorkammer

Die Vorkammer 1948 besitzt drei getrennte Rückkehrpads. RED hört Groudon,
BLUE Kyogre und GREEN Rayquaza; der jeweils fremde Rückweg wird nicht benutzt.
Die schwarze Tür erzählt nur den vorgesehenen Archivteaser und öffnet keine
unfertige Folgegeschichte. Jeder Charakter kann physisch zu seinem Schrein
zurückkehren und anschließend den gesamten Dungeon verlassen.

Belege: [gemeinsame Vorkammer](../qa/hidden_evolution_shared_antechamber_final_20260811/) ·
[finale Tunnelabstände](../qa/hidden_evolution_shared_tunnel_spacing_final_20260811/REPORT.md) ·
[Wandrisse](../qa/fissure_wall_decal_final_v2_20260811/)

Die Shared-Tunnelbilder der älteren RED-/BLUE-/GREEN-Vollruns bleiben als
Mechaniknachweis erhalten, sind aber ausschließlich für Abstand und
Sichtbarkeit der Schächte superseded. Maßgeblich für die finale Optik sind die
gezielten 2D-/FULL-Voxel-Aufnahmen des Spacing-Reports; Etagen-, Rätsel-,
Reward-, Rückweg- und Reentry-Traces der Vollruns bleiben unverändert gültig.

## Dauerhafte Folgen und ehrliche Releasegrenze

Ein normaler Abschluss speichert Siegel, die zugehörigen Evolutionspakete,
Reward-/Türzustand und den passenden Werkstattfortschritt. Die Werkstattpläne
werden nach Charakter freigeschaltet: RED Schwerball+Levelball, BLUE
Köderball+Turboball, GREEN Freundesball+Sympaball+Mondball. Ein optionaler
Megastein bleibt separat gespeichert und darf den normalen Abschluss oder die
schwarze Tür niemals blockieren.

Der vorhandene Aprikoko-Ball-Funktionsstand bleibt unverändert dokumentiert.
Erweiterung oder erneute Abnahme dieses Scopes ist für den heutigen Abschluss
ausdrücklich geparkt und kein Blocker des Kartenhandoffs.

### Lv.-70-Habitate während der Farbprüfung

Sobald der richtige Reisende seinen echten Wandriss betreten hat, sind **alle**
für seine Farbe vorgesehenen Elternarten ab der ersten Prüfungsetage als
Lv.-70-Begegnungen erreichbar. Ein Paketabschluss ist dafür ausdrücklich
nicht nötig: Die Kandidaten sollen auf dem Weg zum Forschungsspeicher gefunden
und anschließend mit der dort errungenen Methode entwickelt werden können.
Der Eintritts-Flag und die aktive Reiseidentität müssen zur Kartenfarbe passen;
fremde, fehlende oder nur als Text gespeicherte Werte schließen fail-closed:

- RED: Rizeros, Magmar, Schlurp, Keifel und Skorgla.
- BLUE: Magneton, Elektek, Evoli, Sniebel und Porygon2.
- GREEN: Evoli, Tangela, Yanma, Togetic, Griffel, Traunfugil und Kramurx.

Die gemeinsamen Tunnel-/Vorkammerkarten besitzen diese Habitate nicht. Das
Publizieren setzt keinen Pokédex-Eintrag auf gesehen/gefangen, umgeht keine
Entwicklung und bleibt mit Randomizer, Johto-Klassik und sichtbaren Wilds
geschützt. Flemmli, Hydropi und Geckarbor bleiben verdiente Vermächtnisgaben
und erscheinen niemals als wilde Dungeonbegegnung.

Für eine reproduzierbare Sichtprüfung erzeugt der Builder
`tools/hevo_dungeon_encounter_demo_qa_setup.lua` drei QA-Slots direkt hinter
dem ersten Rückwarp: `slothevo65encounterred`, `slothevo65encounterblue` und
`slothevo65encountergreen`. Er liest die geprüften Start- und
Fundwege aus `tools/hevo_dungeon_encounter_demo_manifest.lua`, setzt **keine**
Paketfreischaltung und erzwingt für diese Demo-Slots `GBCFX OFF`, damit weder
LCD-Raster noch Drop-Shadow die Figuren verfälschen. RED/BLUE nutzen erreichbare
Höhlenzellen; GREENs Route führt nachweislich in natives FOREST-Gras.

Die drei einzelnen Kartenkampagnen einschließlich 2D/Voxel, Geheimfund,
Rückweg und Reentry sind belegt. **Nicht** als Gesamt-PASS behauptet wird die
noch offene zusammenhängende Ruhmeshalle→RED→BLUE→GREEN→Steinkoffer-Kette über
drei Vermächtnisreisen. Deren visueller Save-/Reload-/Stone-Case-Nachweis ist
ein separates P0-Releasegate.
