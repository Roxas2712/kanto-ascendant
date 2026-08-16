# Wilds of Kanto 1.12.2 – Johto- und Voxel-E2E

Stand: 10. August 2026

## Prüfaufbau

- Kanto Ascendant 6.5.0 Arbeitsstand
- Wilds of Kanto 1.12.2 (unveränderter Release-Tag)
- DRAMALESS_SHAPE 1.6.2.ST
- Pokémon Rot, erweiterte Farbdarstellung (`redpp`)
- echter LÖVE-/Gen1Recomp-Lauf, keine nachgebaute UI
- reproduzierbarer Treiber: `tools/wilds_1_12_2_voxel_e2e_driver.lua`

## Ergebnis

| Prüfung | Ergebnis |
| --- | --- |
| Wilds-API meldet exakt 1.12.2 | BESTANDEN |
| DRAMALESS_SHAPE wird von Wilds als Voxel-Renderer erkannt | BESTANDEN |
| Johto-Walker normal #152–251 | 100/100, jeweils 16×96 |
| Johto-Walker shiny #152–251 | 100/100, jeweils 16×96 |
| Flache Welt: Endivie, Natu, Ampharos | BESTANDEN |
| Voxel-Welt: Endivie, Natu, Ampharos | BESTANDEN |
| Voxel-Welt: Karnimani, Nachtara, Suicune | BESTANDEN |
| Voxel-Höhle: Iksbat, Sniebel, Despotar | BESTANDEN |
| Voxel-Wasser: Mantax Lv. 42 | BESTANDEN |
| Kontakt löst echten Kampf gegen Despotar Lv. 55 aus | BESTANDEN |
| Kein Johto-Testobjekt nutzt den Notfall-/Fallback-Sprite | BESTANDEN |
| Voxel-Pose und Registrierung aller zehn Repräsentanten | BESTANDEN |
| Stadtmenge: Automatisch, 0 und feste Werte | BESTANDEN |
| Vertania City: exakt 3 friedliche Pokémon | BESTANDEN |
| Stadtregion: Nur Kanto | BESTANDEN |
| Stadtregion: Kanto + Johto | BESTANDEN |
| Stadtregion: Nur Johto | BESTANDEN |
| Vertania: 3/3 ausschließlich Johto, nicht kampffähig | BESTANDEN |
| Legendäre, mystische und finale Arten in Städten gesperrt | BESTANDEN |
| Ansprechen spielt den echten Speziesruf | BESTANDEN |
| Englischer Namensruf, z. B. `SUDOWOODO!` | BESTANDEN |
| Deutscher Namensruf, z. B. `WIESOR!` | BESTANDEN |

## Dabei behobene Integrationsfehler

1. Wilds 1.12.2 sucht ausschließlich nach der alten technischen Kennung
   `DRAMATIC_SHAPE`. Kanto Ascendant unterstützt jedoch auch die aktuelle Fork
   `DRAMALESS_SHAPE`. Der Adapter stellt Wilds nun lokal die erwartete Kennung
   bereit, ohne andere Mods oder die globale Mod-Suche umzuschreiben.
2. Wilds benutzt für sichtbare Wasser-Pokémon einen eigenen Spawn-Pfad.
   Johto-Habitate erreichten zuvor nur Land und Höhlen. Der Adapter speist jetzt
   auch den synchronen Wasser-Pick, während Platzierung, Abstand, Animation und
   Verhalten weiterhin vollständig bei Wilds bleiben.
3. Friedliche Stadt-Pokémon besitzen in Wilds eine von Routenbegegnungen
   getrennte Population. Kanto Ascendant erweitert genau diese Schnittstelle
   um die Auswahl `Nur Kanto`, `Kanto + Johto` und `Nur Johto`. Ein Wechsel
   leert und befüllt den aktuellen sicheren Ort sofort neu; die Figuren bleiben
   reine Dekoration und können keinen Kampf beginnen.
4. Wilds spielte beim Ansprechen bereits den echten Pokémon-Ruf, zeigte für
   fast alle Arten jedoch nur `[...]`. Der Adapter speist nun den zum aktiven
   Spielstand passenden Namen in diesen Dialogpfad. Dadurch bleibt genau ein
   Audioruf aktiv und das Textfenster zeigt beispielsweise `SENTRET!` auf
   Englisch beziehungsweise `WIESOR!` mit dem deutschen Rot-Paket.

## Screenshots

- `qa/wilds-1.12.2-johto-e2e-complete/01_route22_johto_2d.png`
- `qa/wilds-1.12.2-johto-e2e-complete/02_route22_johto_voxel.png`
- `qa/wilds-1.12.2-johto-e2e-complete/03_route22_johto_mixed_voxel.png`
- `qa/wilds-1.12.2-johto-e2e-complete/04_route22_johto_water_voxel.png`
- `qa/wilds-1.12.2-johto-e2e-complete/04b_mantine_voxel_detail.png`
- `qa/wilds-1.12.2-johto-e2e-complete/05_mt_moon_johto_voxel.png`
- `qa/wilds-1.12.2-johto-e2e-complete/06_tyranitar_contact_battle_voxel.png`
- `qa/wilds-town-amount-e2e/viridian_city_exactly_3.png`
- `qa/wilds-town-region-e2e/viridian_city_johto_only_3.png`
- `qa/wilds-town-talk-en/viridian_city_localized_name_and_cry.png`
- `qa/wilds-town-talk-de/viridian_city_localized_name_and_cry.png`

## Bewusste Grenze

Wilds 1.12.2 meldet selbst `Runtime shiny support: NOT_AVAILABLE`. Deshalb ist
die vollständige normale und shiny Johto-Dateimatrix geprüft, aber Wilds kann
vor dem Kampf noch keinen echten Shiny-Zustand eines sichtbaren Zufallsspawns
besitzen. Ein sichtbarer zufälliger Shiny-Spawn wird daher nicht fälschlich als
grün dokumentiert.

Die kräftigen Farben im Despotar-/Turtok-Kampfbild entsprechen pixelgenau den
geladenen Crystal-Quelldateien. Sie sind keine zusätzliche Voxel-Verfärbung.
