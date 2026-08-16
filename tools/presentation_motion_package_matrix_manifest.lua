-- Exact source contract for L02 / DRV-PRESENTATION-MOTION-PACKAGE-MATRIX.
--
-- This manifest does not run LÖVE and does not claim installed-package PASS.
-- A later same-hash package orchestrator may materialize these eight cells,
-- but only the per-phase receipts and aggregate receipt defined here can
-- replace the historical blocked cell.

local DRIVER = "tests/presentation_motion_package_driver.lua"
local FRESH_PHASES = {
  "characters", "crystal_title_gorochu", "follower_wilds",
  "reload_verify", "aggregate",
}
local BLITZ_PHASES = { "blitz_restore", "reload_verify", "aggregate" }

local BATTLE_ART_SHA256 =
  "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e"
local BLITZ_SAVE_SHA256 =
  "f0d8c1925c09ad8ba825240f6218b81fd1f7dbd6c30348f6304fb006dcf2f8a0"
local BLITZ_OPTIONS_SHA256 =
  "2f5ca783613d1ecefd12b3942ef7b12f0c78180e9b6a3820ba2637f21b91e540"

local phaseSpecs = {
  characters = {
    timeout_seconds = 1800,
    images = { ["2D"] = 45, BATTLE_ART_FULL = 15 },
    receipt = "characters_result.txt",
  },
  crystal_title_gorochu = {
    timeout_seconds = 1200,
    images = { ["2D"] = 5, BATTLE_ART_FULL = 5 },
    receipt = "crystal_title_gorochu_result.txt",
  },
  follower_wilds = {
    timeout_seconds = 1500,
    images = { ["2D"] = 8, BATTLE_ART_FULL = 8 },
    receipt = "follower_wilds_result.txt",
  },
  blitz_restore = {
    timeout_seconds = 1200,
    images = { ["2D"] = 6, BATTLE_ART_FULL = 6 },
    receipt = "blitz_restore_result.txt",
  },
  reload_verify = {
    timeout_seconds = 600,
    images = { ["2D"] = 0, BATTLE_ART_FULL = 0 },
    receipt = "reload_verify_result.txt",
  },
  aggregate = {
    timeout_seconds = 120,
    images = { ["2D"] = 0, BATTLE_ART_FULL = 0 },
    receipt = "driver_result.txt",
  },
}

local freshRequired = {
  "status=PASS",
  "scope=PRESENTATION-MOTION-PACKAGE",
  "fixed_identities=6/6",
  "ordinary_modes=3/3",
  "ordinary_classes=42/42",
  "title_rhythm=GREEN>POKEMON>BLUE>POKEMON>RED>POKEMON>GREEN",
  "crystal_species=28/28",
  "crystal_surfaces=9/9",
  "crystal_variants=2/2",
  "follower_exactly_one=1/1",
  "follower_map=1/1",
  "follower_door=1/1",
  "follower_surf=1/1",
  "follower_evolution=1/1",
  "follower_reload=1/1",
  "wilds_spawnfx=1/1",
  "wilds_randomizer_once=1/1",
  "wilds_johto_protection=1/1",
  "wilds_contact=1/1",
  "gorochu_intro_absent=1/1",
  "gorochu_sendout_present=1/1",
  "gorochu_hof=1/1",
  "native_save_write=1/1",
  "native_options_write=1/1",
  "native_process_boot_without_progress_marker=1/1",
  "native_save_load=1/1",
  "native_save_recovery=main",
  "native_save_restore=1/1",
  "renderer_contract_persisted=1/1",
  "renderer_contract_reloaded=1/1",
  "durable_follower_exactly_one=1/1",
  "durable_follower_option=1/1",
  "engine_payload_sha256=",
  "authority_package_sha256=",
  "deutsch_package_sha256=",
  "battle_art_package_sha256=" .. BATTLE_ART_SHA256,
  "package_gate_receipt_sha256=",
  "fail=0",
}

local blitzRequired = {
  "status=PASS",
  "scope=PRESENTATION-MOTION-PACKAGE",
  "blitz_source_sha256=" .. BLITZ_SAVE_SHA256,
  "blitz_options_sha256=" .. BLITZ_OPTIONS_SHA256,
  "blitz_natural_restore=1/1",
  "blitz_load_report_dismissed=1/1",
  "follower_exactly_one=1/1",
  "follower_map=1/1",
  "follower_door=1/1",
  "follower_surf=1/1",
  "follower_reload=1/1",
  "native_save_write=1/1",
  "native_options_write=1/1",
  "native_process_boot_without_progress_marker=1/1",
  "native_save_load=1/1",
  "native_save_recovery=main",
  "native_save_restore=1/1",
  "renderer_contract_persisted=1/1",
  "renderer_contract_reloaded=1/1",
  "durable_follower_exactly_one=1/1",
  "durable_follower_option=1/1",
  "native_active_slot=slot7",
  "immutable_blitz_snapshot_unchanged=1/1",
  "engine_payload_sha256=",
  "authority_package_sha256=",
  "deutsch_package_sha256=",
  "battle_art_package_sha256=" .. BATTLE_ART_SHA256,
  "package_gate_receipt_sha256=",
  "fail=0",
}

-- Literal rows are intentional: the source contract parses this closed list
-- without executing Lua, then also checks the generated runtime cells.
local expectedCells = {
  { id = "l02-presentation-red-2d", identity = "ka65-presentation-motion-red-2d", edition = "red", renderer = "2D", source = "FRESH" },
  { id = "l02-presentation-red-battle-art-full", identity = "ka65-presentation-motion-red-battle-art-full", edition = "red", renderer = "BATTLE_ART_FULL", source = "FRESH" },
  { id = "l02-presentation-blue-2d", identity = "ka65-presentation-motion-blue-2d", edition = "blue", renderer = "2D", source = "FRESH" },
  { id = "l02-presentation-blue-battle-art-full", identity = "ka65-presentation-motion-blue-battle-art-full", edition = "blue", renderer = "BATTLE_ART_FULL", source = "FRESH" },
  { id = "l02-presentation-yellow-2d", identity = "ka65-presentation-motion-yellow-2d", edition = "yellow", renderer = "2D", source = "FRESH" },
  { id = "l02-presentation-yellow-battle-art-full", identity = "ka65-presentation-motion-yellow-battle-art-full", edition = "yellow", renderer = "BATTLE_ART_FULL", source = "FRESH" },
  { id = "l02-presentation-blitz-red-2d", identity = "ka65-presentation-motion-blitz-red-2d", edition = "red", renderer = "2D", source = "BLITZ" },
  { id = "l02-presentation-blitz-red-battle-art-full", identity = "ka65-presentation-motion-blitz-red-battle-art-full", edition = "red", renderer = "BATTLE_ART_FULL", source = "BLITZ" },
}

local function copyList(values)
  local out = {}
  for index, value in ipairs(values) do out[index] = value end
  return out
end

local function durableSpecies(cell)
  if cell.source == "BLITZ" then return "ALAKAZAM" end
  return assert(({ red = "IVYSAUR", blue = "WARTORTLE",
    yellow = "RAICHU" })[cell.edition])
end

local cells = {}
for _, expected in ipairs(expectedCells) do
  local phases = expected.source == "FRESH" and FRESH_PHASES or BLITZ_PHASES
  local passes, exactImages = {}, 0
  for _, phase in ipairs(phases) do
    local spec = assert(phaseSpecs[phase])
    local count = assert(spec.images[expected.renderer])
    exactImages = exactImages + count
    passes[#passes + 1] = {
      name = phase,
      driver = DRIVER,
      timeout_seconds = spec.timeout_seconds,
      env = {
        QA_PRESENTATION_PHASE = phase,
        QA_PRESENTATION_SOURCE = expected.source,
        QA_RENDERER = expected.renderer,
        KA_PRESENTATION_COMPOSITE =
          "${GEN1RECOMP_DIR}/tools/presentation_motion_package_composite.lua",
        KA_CHARACTER_MATRIX =
          "${GEN1RECOMP_DIR}/tools/blitz_character_presentation_matrix.lua",
      },
      receipt = spec.receipt,
      images = { exact_count = count },
    }
  end
  local required = expected.source == "FRESH"
    and copyList(freshRequired) or copyList(blitzRequired)
  required[#required + 1] = "edition=" .. expected.edition
  required[#required + 1] = "renderer=" .. expected.renderer
  required[#required + 1] = "source=" .. expected.source
  required[#required + 1] =
    "durable_follower_species=" .. durableSpecies(expected)

  cells[#cells + 1] = {
    id = expected.id,
    identity = expected.identity,
    edition = expected.edition,
    renderer = expected.renderer,
    source = expected.source,
    closure = "battle_art",
    driver = DRIVER,
    timeout_seconds = 1800,
    env = {
      QA_PRESENTATION_SOURCE = expected.source,
      QA_RENDERER = expected.renderer,
      KA_PRESENTATION_COMPOSITE =
        "${GEN1RECOMP_DIR}/tools/presentation_motion_package_composite.lua",
      KA_CHARACTER_MATRIX =
        "${GEN1RECOMP_DIR}/tools/blitz_character_presentation_matrix.lua",
    },
    passes = passes,
    result = { path = "driver_result.txt", contains = required },
    images = { exact_count = exactImages },
  }
end
assert(#cells == 8, "L02 presentation matrix must remain exactly eight cells")

return {
  schema = "ka-l02-presentation-motion-package-matrix/v1",
  blocker = "DRV-PRESENTATION-MOTION-PACKAGE-MATRIX",
  missingDriver = "DRV-BATTLEART-PRESENTATION-CLOSURE",
  replacementCell = "l02-blocked-complete-presentation",
  driver = "tests/presentation_motion_package_driver.lua",
  packageBoundary = "SOURCE-STATIC-DEFINITION-ONLY",
  battleArt = {
    id = "BATTLE_ART_VOXEL_FORK",
    version = "1.8.3",
    archiveSha256 = BATTLE_ART_SHA256,
    installedIn = { "2D", "BATTLE_ART_FULL" },
    twoDimensionalSetting = "OFF",
  },
  blitz = {
    editions = { "red" },
    save = "qa/blitz_real_save_forensic_20260812/source_snapshot/slot7_original_readonly.lua",
    saveSha256 = BLITZ_SAVE_SHA256,
    options = "qa/blitz_real_save_forensic_20260812/source_snapshot/options_original_readonly.lua",
    optionsSha256 = BLITZ_OPTIONS_SHA256,
  },
  supportFiles = {
    "tests/presentation_motion_package_driver.lua",
    "tools/presentation_motion_package_composite.lua",
    "tools/presentation_motion_package_matrix_manifest.lua",
    "tools/blitz_character_presentation_matrix.lua",
    "tests/trainer_portrait_modes_visual_driver.lua",
    "tools/extended_species_runtime_qa_driver.lua",
    "tools/follower_phase2_e2e_driver.lua",
    "tools/follower_wilds_motion_qa_driver.lua",
    "qa/blitz_real_save_forensic_20260812/source_snapshot/slot7_original_readonly.lua",
    "qa/blitz_real_save_forensic_20260812/source_snapshot/options_original_readonly.lua",
  },
  phases = phaseSpecs,
  freshPhases = FRESH_PHASES,
  blitzPhases = BLITZ_PHASES,
  editions = { "red", "blue", "yellow" },
  renderers = { "2D", "BATTLE_ART_FULL" },
  expectedCells = expectedCells,
  cells = cells,
}
