# Field altar completion

The earlier feedback patch handled eligibility failures, but Evolution.request also calls its completion callback synchronously when no evolution branch matches. That callback returned the player to the map before the altar could display failure feedback.

The altar now defers completion until the request's return value confirms an evolution started. Missing/declined branches and exceptions reach the existing localized feedback. Successful asynchronous evolution still completes the interaction, once only. No package, generation, species or unlock restrictions changed. Applies to all registered field altars, including the Viridian Forest moss altar.

Regression: new test fails against rc10 on the missing-branch path and passes with rc11; covers EN/DE eligibility, cancellation, successful requests, nil/false/throwing requests and asynchronous/repeated completion. Native Yellow + VASC 3.0.9: three rejected selections, cancellation, then actual Eevee to Leafeon with a disposable unlocked Gen4 fixture; same party object retained, returned to overworld, altar unfrozen.

Runtime ZIP reconstructed from verified rc10. Only hevo_packages.lua and the two package/version manifests change; every other entry remains byte-identical. Physical Android not tested.

Final packed rc11 ZIP + VASC 3.0.9, native Red: same cancellation/rejection/success sequence PASS. Native Card codec, exact pins, art/options/save identity and forward compatibility checks PASS.
