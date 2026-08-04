function love.conf(t)
  -- Never share saves, options or installed mods with the player's normal
  -- pokemon-love2d identity.
  t.identity = "kanto-ascendant-signals-uat"
  t.version = "11.5"
  t.console = true
  t.window = false
  t.audio = false
  t.joystick = false
  t.physics = false
end
