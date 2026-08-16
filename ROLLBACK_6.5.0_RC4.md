# Kanto Ascendant 6.5.0 RC4 – Rücksetzen

Ausgangsstand: `v6.0.5`
(`8ed87b962d6d77ee7e07d4d41446a8436e1f56d2`)

RC4-Implementierung:
`f8b8c4ee70800dee9e3d9d976a0a8aa570028986`

## Mod-Testinstallation

1. `kanto-ascendant-6.5.0-rc4-test.zip` im Mod-Manager deaktivieren oder
   ersetzen.
2. `kanto-ascendant-6.5.0-rc4-rollback-to-6.0.5.zip` über
   `Import mod .zip` installieren.
3. Das Spiel neu starten und den Spielstand laden.

Die zusätzlichen 6.5-Optionen im Spielstand sind bei 6.0.5 wirkungslos.
Pokémon, Items und Boxdaten werden vom Rollback nicht gelöscht.

## Quellbaum zurücksetzen

Das mitgelieferte Bundle enthält den vollständigen RC4-Quellstand und die
6.0.5-Historie:

```text
git fetch kanto-ascendant-6.5.0-rc4-source.bundle
git switch --detach v6.0.5
```

Das Bundle verändert einen vorhandenen Checkout nicht automatisch.
