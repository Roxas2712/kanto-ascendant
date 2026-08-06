-- Real-save restart guard for Johto Signals' one-time start choice.
--
-- Run against an isolated UAT identity whose active slot has already
-- accepted or declined the direct-start prompt. The driver deliberately
-- waits through both save.loaded and game.ready before checking that no
-- second request was queued.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local version = os.getenv("POKEPORT_VERSION") or "yellow"
  local slot = os.getenv("KA_ONBOARDING_SLOT") or "slot6026"
  local action = os.getenv("KA_ONBOARDING_ACTION")
  local requested = action == "decline" and "waves" or "unleashed"
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions.trainer_rematch =
    game.mods.modOptions.trainer_rematch or {}
  game.mods.modOptions.trainer_rematch.johto_signals_start = requested
  assert(SaveData.setActiveSlot(version, slot) == slot,
    "could not select onboarding UAT slot")
  local loaded, recovered = SaveData.load(version)
  assert(loaded and not recovered,
    "onboarding UAT slot did not load from its primary save")
  game:restoreSave(loaded, recovered)
  U.wait(90)

  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.trainer_rematch,
    "Kanto Ascendant exports are unavailable")
  local early = assert(exports.johtoSignals,
    "Johto Signals controller is unavailable")
  local state = early.state()
  if action == "accept" then
    assert(state.onboardingComplete ~= true,
      "accept setup slot was already completed")
    local ok, reason = early.completeOnboarding(true, "UNLEASHED", game)
    assert(ok and reason == "configured",
      "accepting direct start did not commit the direct choice")
    assert(early.state().onboardingComplete == true
        and early.state().receiverRepaired == true,
      "accepting direct start did not persist a repaired receiver")
    U.log("PASS Johto onboarding accept written; restart for verification")
    love.event.quit(0)
    return
  end
  if action == "decline" then
    assert(state.onboardingComplete ~= true,
      "decline setup slot was already completed")
    local ok, reason = early.completeOnboarding(false, "WANDERWAVES", game)
    assert(ok and reason == "field-quest",
      "declining direct start did not commit the field-quest choice")
    assert(early.state().onboardingComplete == true,
      "declining direct start did not mark onboarding complete")
    U.log("PASS Johto onboarding decline written; restart for verification")
    love.event.quit(0)
    return
  end
  U.log(("Johto restart state: player=%s complete=%s policy=%s mode=%s repaired=%s")
    :format(tostring(game.save and game.save.player
        and game.save.player.name),
      tostring(state.onboardingComplete), tostring(state.startPolicy),
      tostring(state.mode), tostring(state.receiverRepaired)))
  assert(state.onboardingComplete == true,
    "active UAT slot does not contain a completed onboarding choice")
  assert(early.runtimeStatus().onboardingPending == nil,
    "completed onboarding was queued again after restart")

  U.log(("PASS Johto onboarding stayed remembered: policy=%s mode=%s")
    :format(tostring(state.startPolicy), tostring(state.mode)))
  love.event.quit(0)
end
