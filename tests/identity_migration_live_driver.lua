-- Shipped-engine proof that an RC9 options namespace becomes RC10 state and
-- is mirrored back for rollback when options are written.
return function(game)
  local pass, fail = 0, 0
  local function check(ok, label)
    print("[identity-live]", ok and "PASS" or "FAIL", label)
    if ok then pass = pass + 1 else fail = fail + 1 end
  end

  for _ = 1, 20 do coroutine.yield() end
  local oldId, newId = "trainer_rematch", "kanto_ascendant"
  local migration = game.mods.exports[newId]
    and game.mods.exports[newId].identityMigration
  local options = game.mods.modOptions
  local old, current = options[oldId], options[newId]

  check(migration and migration.legacyOptionsDetected == true,
    "legacy Kanto options were detected before feature installation"
      .. " (actual=" .. tostring(migration
        and migration.legacyOptionsDetected) .. ")")
  check(current and current.language == "de",
    "German selection migrated to kanto_ascendant")
  check(current and current.text_speed == "fast",
    "QoL selection migrated to kanto_ascendant")
  check(old ~= current, "legacy and canonical option buckets are independent")

  current.text_speed = "instant"
  game.save.options = game.save.options or {}
  game.save.options.modOptions = options
  game:writeOptions()
  check(options[oldId] and options[oldId].text_speed == "instant",
    "options write refreshes the RC9 rollback shadow")
  current.text_speed = "slow"
  check(options[oldId].text_speed == "instant",
    "rollback shadow is a deep copy, not a live alias")

  print(("[identity-live] RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
