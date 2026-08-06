# Kanto Ascendant 6.5.0 RC3 – Rücksetzen

Ausgangsstand: `v6.0.5` (`8ed87b962d6d77ee7e07d4d41446a8436e1f56d2`)
RC-Code: `1220360f63fdb2d3ca93646d09a93bf5dfc60759`

## Mod-Testinstallation

1. Das Paket `kanto-ascendant-6.5.0-rc3.zip` im Mod-Manager deaktivieren oder ersetzen.
2. Das mitgelieferte, direkt importierbare Paket `kanto-ascendant-6.0.5-rollback.zip` installieren.
3. Spielstand laden. Die 6.5-Einstellungen bleiben folgenlos, wenn die RC-Mod nicht geladen wird.

## Quellbaum zurücksetzen

Im mitgelieferten Git-Bundle ist der Ausgangsstand enthalten:

```text
git fetch kanto-ascendant-6.5.0-rc3-source.bundle v6.0.5
git switch --detach v6.0.5
```

Das Bundle verändert den bestehenden Checkout nicht; es dient nur als lokale Rückversicherung.
