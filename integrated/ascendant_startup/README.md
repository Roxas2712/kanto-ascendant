# Embedded Ascendant Entry Card · RC10

One shared intro after confirmed New Game / Continue, after the cartridge boot cinema.
Embedded in both owners; game-scoped ownership deduplicates KASC + VASC. No external
startup mod is required. Supports the owners' six games: Red/Blue/Yellow/Gold/Silver/Crystal.
No platform gate: desktop, iOS, Android and NX use the same LOVE drawing/input path.

The native callback adopts the save only after the first displayed card frame.
Hidden gameplay/dialogue is paused. Gen1 ContinuePreparation and the real renderer
warm their existing region, geometry, light, shader and scenery resources. Gen2
Continue waits for the actual map/neighbor mesh receipts; Gen2 New Game preloads
native introduction and start-map textures, preserving Oak/name/clock/gender order.
No shadow World is created. Mandatory preparation can outlast the music; logo and
animated characters remain until readiness. Skip shortens only the animation.
Optional failed jobs are recorded and native validation dialogs retain priority.
A fresh entry reuses native caches without suppressing required readiness checks.

Eevee's static prepared pose lacked the poser quadruped walk. The atlas now bakes a
24-frame diagonal gait and 20-frame breathing/ear/tail idle. The independent animation
clock continues during the end-logo hold instead of freezing at 11 seconds.
Assets are released on completion/cancellation. Audio obeys SFX volume/splash mute.

Limits: initial engine/mod code loading before the menu is outside this hook.
Later travel or changed assets/settings may still require preparation. Gen3 is not
a supported generation of either parent mod. Physical mobile/NX validation remains
necessary; native Mac tests do not certify device-specific graphics/audio drivers.
