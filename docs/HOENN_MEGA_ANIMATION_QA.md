# Drei verfasste Megaformen – Animations-QA

> [!WARNING]
> **⚠️ FULL SPOILERS:** Diese technische Referenz nennt die drei geheimen
> Megaformen und ihre Präsentationsassets.

<details>
<summary><strong>Vollständige technische Spoiler öffnen</strong></summary>

Dieses Paket ergänzt ausschließlich Mega Lohgock, Mega Sumpex und Mega
Gewaldro. Es ersetzt weder die vier statischen Masters noch die Voxel-Quelle.

## Herkunft und Rechte

Die vier 96×96-Masters je Form (Front/Back × Normal/Shiny) stammen aus dem
bereits lokal gelieferten, gepinnten `PokeAPI/sprites`-Paket. Die fünf
Bewegungskeys je Variante in `assets/mega_animated/` sind lokal abgeleitete
Fanprojektgrafiken, erzeugt durch
`tools/build_hoenn_mega_animation_frames.py`. Sie sind keine offizielle
Grafik und es wird keine freie Lizenz oder allgemeine Weitergabegenehmigung
behauptet. Die Hashliste
`assets/mega_animated/HOENN_MEGA_DERIVATIVE_SHA256.txt` bindet die 60
derivierten Keys fest.

Die Crystal-Runtime-Karten liegen getrennt unter
`assets/mega_animated_runtime/`. Voxel liest weiter den unveränderten
statischen Master aus `assets/mega/`; Crystal-off nutzt weiter die statischen
vierfarbigen Karten in `assets/mega_gen1_runtime/`.

## Ausführung und Prüfung

Jede der zwölf Front-/Back-/Normal-/Shiny-Varianten hat fünf 96×96-Keyframes
und dieselbe Timingfolge `180, 90, 120, 90, 240` ms. Die Generatorprüfung
weist je Variante fünf verschiedene Frame-Bytes nach. Die Back-Posen werden
nie aus der Front gespiegelt; sie beginnen bei den unabhängigen Back-Masters.
Die individuellen 2D-Back-Anker sind Lohgock `-7`, Sumpex `-13`, Gewaldro
`-10` und halten Kopf/Schulter aus dem Spieler-HUD.

Durchgeführte Tests:

```sh
python3 tools/build_hoenn_mega_animation_frames.py
python3 tools/build_mega_runtime_assets.py --animations-only \
  --asset mega_blaziken --asset mega_swampert --asset mega_sceptile
python3 tools/build_mega_runtime_assets.py --check \
  --asset mega_blaziken --asset mega_swampert --asset mega_sceptile
"$GEN1RECOMP_DIR/.tools/luajit-src/src/luajit" \
  tests/hoenn_mega_runtime_test.lua
```

Zusätzlich lief `tests/trainer_rematch_test.lua` gegen den Main-load mit
7.072/7.072 Checks. Er prüft Profile, finale Formen, Steine, Crystal/Gen-I
Resolver, beide Seiten, Shiny und Voxel-Master-Provenienz.

## Echte LÖVE-Belege

Das private Abnahmearchiv bindet alle 24 echten LÖVE-Captures per SHA-256.
Geprüft wurden folgende Kontaktbögen:

- 2D Crystal — 12 Bilder:
  drei Formen × Spieler/Gegner × Normal/Shiny, Crystal an.
- 2D Gen I — Red/Blue/Yellow,
  Crystal aus, inklusive normaler Spieler- und shiny Gegnerfälle.
- Voxel — echter DRAMALESS-Loader,
  alle drei Forms als Spieler/Gegner sowie Normal/Shiny.
- Authored Keys — 60 autorisierte
  Keyframes vor der Runtime-Reduktion.

Die LÖVE-Captures liefen mit dem lokalen 11.5-Binary. Der Voxel-Lauf verwendet
die vorhandene isolierte Identity `ka-hoenn-mega-qa`, welche DRAMALESS ohne den
konfligierenden DRAMATIC-Shape lädt.

</details>
