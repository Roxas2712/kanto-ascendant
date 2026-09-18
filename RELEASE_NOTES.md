# Kanto Ascendant 6.7.13 – iPhone support log hotfix

- Support log sending works around the missing dedicated POST bridge in iOS engine 0.2.61 by using its existing background HTTP request transport.
- SEND SUPPORT LOG sends with one selection after entering the code, without an extra help popup or confirmation click.
- HTTP rejection, timeouts and cancellation remain failures; reports are never retried automatically. Uploads remain manual, bounded and redacted, with no save file attached. Desktop and dedicated mobile POST transports are preserved.

Validation: shared sender regression tests cover success, HTTP rejection, timeout, cancellation, duplicate clicks and desktop routing. The same background request route delivered a verified native test report. Physical iPhone verification is still pending; the separately reported HD-sprite issue remains under investigation.

Update KASC in the launcher and restart the game. For manual updates over an existing sprite installation, use the preserving installer asset and its included instructions.
