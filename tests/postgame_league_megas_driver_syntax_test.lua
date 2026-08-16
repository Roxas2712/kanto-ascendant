local root = assert(os.getenv("KA_LEAGUE_MOD"), "KA_LEAGUE_MOD required")
local files = {
  "postgame_data.lua",
  "postgame.lua",
  "ascendant.lua",
  "mega_evolution.lua",
  "tests/postgame_crown_roster_test.lua",
  "tests/postgame_league_megas_visual_driver.lua",
}
for _, file in ipairs(files) do
  local chunk, why = loadfile(root .. "/" .. file)
  assert(chunk, file .. ": " .. tostring(why))
end

local driverPath = root .. "/tests/postgame_league_megas_visual_driver.lua"
local handle = assert(io.open(driverPath, "rb"))
local driver = handle:read("*a")
handle:close()
local function contains(needle, label)
  assert(driver:find(needle, 1, true), label)
end
contains("BattleState.newTrainer", "driver must construct real trainer battles")
contains("battle.started", "driver must describe the production roster boundary")
contains("battle.battler_switched", "driver must use the real switch event seam")
contains("STAGED_SWITCH_AFTER_REAL_ROSTER_ASSERTION",
  "driver must label every staged non-lead switch honestly")
contains("progression_setup=STAGED_POSTGAME_SAVE_STATE",
  "driver must disclose its synthetic progression setup")
contains("battle_construction=REAL_BATTLESTATE_TRAINER",
  "receipt must distinguish real battles from staged progression")
contains("manual_mega_activation=false",
  "receipt must disclose that Mega activation is automatic")
contains('local GameVersion = require("src.core.GameVersion")',
  "driver must bind its receipt to the live imported edition")
contains('local expectedEdition = assert(os.getenv("POKEPORT_VERSION")',
  "driver must require the orchestrator edition")
contains('assert(edition == expectedEdition',
  "driver must fail closed on an edition mismatch")
contains('"edition=" .. edition',
  "receipt must emit the verified live edition")
contains("voxelRendererCompat", "driver must use the shared renderer resolver")
assert(not driver:find("mega.activate", 1, true),
  "driver may not manually activate a League Mega")
print("postgame League Mega driver contract: PASS (" .. #files .. " files)")
