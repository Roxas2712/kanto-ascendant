# Extended characters — Phase 8 status

The default New Game selector establishes one stable identity mapping: Red → rival
Blue / third Green; Blue → rival Green / third Red; Green → rival Red / third
Blue. Names remain free-form save text. It routes only presentation through
the central resolver; starter, rival party progression, map IDs, scripts and
Yellow's Pikachu/Eevee systems stay owned by their existing game roles.

The Red/Blue title presentation cycles Green → Blue → Red on the same frame as
the title Pokémon changes, starting with Green. Trainer art keeps the original
foreground draw order. Before naming, all three selector rows deliberately read
`???`; the changing portrait and role line identify the choice. Green receives
`GREEN / CASEY / JEAN`, Red receives `RED / ASH / JACK`, and Blue receives
`BLUE / GARY / JOHN` in either player or rival role. The three presets render
above `NEW NAME`; free entry is always the bottom row.

New Game opens the selector directly, with Green highlighted first. Legacy
saves without character state remain on their vanilla presentation and need no
conversion; the internal disable path remains only as a rollback safeguard.

Red is the complete baseline. Blue's existing walker and rival portrait are
final, but its bike/fishing and intermediate shrink surfaces still use visible
Red fallbacks. Green's overworld sheet is the approved six-frame 16×16 artwork;
her selector/Oak preview is the separate approved 56×56 full-body Casey
trainer portrait. Both assets are protected independently by pixel-exact
tests. With Dramatic Shape/Voxel active, only Green's **battle-back** surface
uses that 56×56 standing Casey portrait; her overworld remains the unchanged
16×96 walking sheet. See `character_asset_matrix.md`: the feature is
integration-ready, **not release ready as a finished character-art package**.
