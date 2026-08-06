# Kanto Ascendant 6.5.0 RC1 – Rücksetzen

Ausgangsstand: `v6.0.5` (`8ed87b962d6d77ee7e07d4d41446a8436e1f56d2`)
RC-Stand: `96751601c05e9e4f29df2ff28bdb86dda428cef2`

## Mod-Testinstallation

1. Das Paket `kanto-ascendant-6.5.0-rc1.modpkg` aus dem ZIP im Mod-Manager deaktivieren oder entfernen.
2. Die zuvor verwendete 6.0.5-Version wieder aktivieren/installieren.
3. Spielstand laden. Die 6.5-Einstellungen bleiben folgenlos, wenn die RC-Mod nicht geladen wird.

## Quellbaum zurücksetzen

Im mitgelieferten Git-Bundle ist der Ausgangsstand enthalten:

```text
git fetch kanto-ascendant-6.5.0-rc1.bundle v6.0.5
git switch --detach v6.0.5
```

Das Bundle verändert den bestehenden Checkout nicht; es dient nur als lokale Rückversicherung.
