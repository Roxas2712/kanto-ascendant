-- Mandatory installed-package Legacy Journey release lanes.  Source/headless
-- PASS is necessary but never substitutes for these fresh-identity receipts.
local mod = assert(os.getenv("KA_LEGACY_MOD") or ".")
local out = {}
for _, version in ipairs({ "red", "blue", "yellow" }) do
  out[#out + 1] = {
    id = "legacy-pact-4x4-" .. version .. "-package",
    version = version,
    identity = "ka-legacy-pact-4x4-" .. version .. "-package",
    driver = mod .. "/tests/legacy_pact_three_journeys_visual_driver.lua",
    env = { KA_LEGACY_ACCEPTANCE_MODE = "pact4x4" },
    images = 16,
    required = {
      "LEGACY PACT 4X4 PACKAGE PASS",
      "edition=" .. version,
      "matrix=16/16 pacts=4/4 policies=4/4",
      "partner_gate=16/16 save_reload=16/16 bank_rules=16/16",
      "hall=16 bank=16 locker_items=121 locker_money=1300",
      "transaction_boundary=REAL_LEGACY_ARCHIVE_BEGIN_JOURNEY",
      "new_game_boundary=ENGINE_SAVE_NEW_GAME_HOOK",
      "partner_boundary=REAL_LEGACY_STARTERS_CHOOSE",
      "progression_setup=STAGED_HOF_AND_RIVAL_BALL_BOUNDARIES",
      "direct_archive_state_writes=false",
    },
  }
end
out[#out + 1] = {
    id = "legacy-three-journeys-package",
    version = "red",
    identity = "ka-legacy-three-journeys-package",
    driver = mod .. "/tests/legacy_pact_three_journeys_visual_driver.lua",
    env = { KA_LEGACY_ACCEPTANCE_MODE = "three_journeys" },
    images = 3,
    required = {
      "LEGACY THREE JOURNEYS PACKAGE PASS",
      "edition=red",
      "journeys=3/3 fresh_new_game_hooks=3/3 save_reload=3/3",
      "avatars=RED,BLUE,GREEN active_cycle=3",
      "hall=3 bank=3 locker_items=6 locker_money=600",
      "archived_species=PIKACHU,BULBASAUR,CHARMANDER",
      "active_partner=SQUIRTLE",
      "transaction_boundary=REAL_LEGACY_ARCHIVE_BEGIN_JOURNEY",
      "new_game_boundary=ENGINE_SAVE_NEW_GAME_HOOK",
      "partner_boundary=REAL_LEGACY_STARTERS_CHOOSE",
      "progression_setup=STAGED_HOF_AND_RIVAL_BALL_BOUNDARIES",
      "direct_archive_state_writes=false",
    },
  }
return out
