-- Tiny real-renderer release probe. Run under an isolated POKEPORT_IDENTITY.
-- It proves which on-disk manifest the engine resolved before any larger UAT
-- is accepted as evidence.

return function(game)
  local manifest = assert(love.filesystem.read(
    "mods/trainer_rematch/manifest.json"))
  local version = assert(manifest:match('"version"%s*:%s*"([^"]+)"'))
  local loaded = assert(game.mods and game.mods.mods
    and game.mods.mods.trainer_rematch)
  assert(loaded.manifest.version == version,
    ("loaded %s but resolved manifest says %s")
      :format(tostring(loaded.manifest.version), tostring(version)))
  print(("MANIFEST PROBE PASS: %s (%s)"):format(
    version, love.filesystem.getSaveDirectory()))
end
