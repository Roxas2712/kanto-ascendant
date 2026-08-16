-- Historical <=0.1.86 Battle Art receipt. It is deliberately separate from
-- the current 0.1.90 renderer-admission gate.
local matrix = dofile("tools/presentation_motion_package_matrix_manifest.lua")

assert(matrix.schema == "ka-l02-presentation-motion-package-matrix/v1")
assert(matrix.blocker == "DRV-PRESENTATION-MOTION-PACKAGE-MATRIX")
assert(matrix.missingDriver == "DRV-BATTLEART-PRESENTATION-CLOSURE")
assert(matrix.replacementCell == "l02-blocked-complete-presentation")
assert(matrix.packageBoundary == "SOURCE-STATIC-DEFINITION-ONLY")
assert(matrix.driver == "tests/presentation_motion_package_driver.lua")
assert(matrix.battleArt.id == "BATTLE_ART_VOXEL_FORK")
assert(matrix.battleArt.version == "1.8.3")
assert(matrix.battleArt.archiveSha256
  == "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e")
assert(matrix.battleArt.twoDimensionalSetting == "OFF")
assert(table.concat(matrix.freshPhases, ",")
  == "characters,crystal_title_gorochu,follower_wilds,reload_verify,aggregate")
assert(table.concat(matrix.blitzPhases, ",")
  == "blitz_restore,reload_verify,aggregate")
assert(table.concat(matrix.editions, ",") == "red,blue,yellow")
assert(table.concat(matrix.renderers, ",") == "2D,BATTLE_ART_FULL")
assert(#matrix.cells == 8 and #matrix.expectedCells == 8)
assert(#matrix.supportFiles == 10)

local expected = {
  ["l02-presentation-red-2d"] = {
    "ka65-presentation-motion-red-2d", "red", "2D", "FRESH", 58,
  },
  ["l02-presentation-red-battle-art-full"] = {
    "ka65-presentation-motion-red-battle-art-full",
    "red", "BATTLE_ART_FULL", "FRESH", 28,
  },
  ["l02-presentation-blue-2d"] = {
    "ka65-presentation-motion-blue-2d", "blue", "2D", "FRESH", 58,
  },
  ["l02-presentation-blue-battle-art-full"] = {
    "ka65-presentation-motion-blue-battle-art-full",
    "blue", "BATTLE_ART_FULL", "FRESH", 28,
  },
  ["l02-presentation-yellow-2d"] = {
    "ka65-presentation-motion-yellow-2d", "yellow", "2D", "FRESH", 58,
  },
  ["l02-presentation-yellow-battle-art-full"] = {
    "ka65-presentation-motion-yellow-battle-art-full",
    "yellow", "BATTLE_ART_FULL", "FRESH", 28,
  },
  ["l02-presentation-blitz-red-2d"] = {
    "ka65-presentation-motion-blitz-red-2d", "red", "2D", "BLITZ", 6,
  },
  ["l02-presentation-blitz-red-battle-art-full"] = {
    "ka65-presentation-motion-blitz-red-battle-art-full",
    "red", "BATTLE_ART_FULL", "BLITZ", 6,
  },
}

local ids, identities, combinations = {}, {}, {}
for _, cell in ipairs(matrix.cells) do
  local want = assert(expected[cell.id], cell.id)
  assert(not ids[cell.id] and not identities[cell.identity])
  ids[cell.id], identities[cell.identity] = true, true
  local combination = table.concat({ cell.edition, cell.renderer, cell.source }, "/")
  assert(not combinations[combination], combination)
  combinations[combination] = true
  assert(cell.identity == want[1] and cell.edition == want[2]
    and cell.renderer == want[3] and cell.source == want[4])
  assert(cell.images.exact_count == want[5])
  assert(cell.closure == "battle_art")
  assert(cell.driver == matrix.driver)
  assert(cell.env.QA_PRESENTATION_SOURCE == cell.source)
  assert(cell.env.QA_RENDERER == cell.renderer)

  local phases = cell.source == "FRESH"
    and matrix.freshPhases or matrix.blitzPhases
  assert(#cell.passes == #phases)
  local imageTotal = 0
  for index, phase in ipairs(phases) do
    local pass = cell.passes[index]
    local spec = assert(matrix.phases[phase])
    assert(pass.name == phase and pass.driver == matrix.driver)
    assert(pass.timeout_seconds == spec.timeout_seconds)
    assert(pass.env.QA_PRESENTATION_PHASE == phase)
    assert(pass.env.QA_PRESENTATION_SOURCE == cell.source)
    assert(pass.env.QA_RENDERER == cell.renderer)
    assert(pass.env.KA_PRESENTATION_COMPOSITE
      == "${GEN1RECOMP_DIR}/tools/presentation_motion_package_composite.lua")
    assert(pass.env.KA_CHARACTER_MATRIX
      == "${GEN1RECOMP_DIR}/tools/blitz_character_presentation_matrix.lua")
    assert(pass.receipt == spec.receipt)
    assert(pass.images.exact_count == spec.images[cell.renderer])
    imageTotal = imageTotal + pass.images.exact_count
  end
  assert(imageTotal == cell.images.exact_count)

  local result = table.concat(cell.result.contains, "\n")
  for _, token in ipairs({
      "status=PASS", "scope=PRESENTATION-MOTION-PACKAGE",
      "edition=" .. cell.edition, "renderer=" .. cell.renderer,
      "source=" .. cell.source,
      "engine_payload_sha256=", "authority_package_sha256=",
      "deutsch_package_sha256=", "battle_art_package_sha256=",
      "package_gate_receipt_sha256=", "follower_exactly_one=1/1",
      "follower_map=1/1", "follower_door=1/1", "follower_surf=1/1",
      "follower_reload=1/1", "native_save_write=1/1",
      "native_options_write=1/1",
      "native_process_boot_without_progress_marker=1/1",
      "native_save_load=1/1", "native_save_recovery=main",
      "native_save_restore=1/1",
      "durable_follower_exactly_one=1/1",
      "durable_follower_option=1/1", "fail=0",
    }) do
    assert(result:find(token, 1, true), token)
  end
  if cell.source == "FRESH" then
    local durable = ({ red = "IVYSAUR", blue = "WARTORTLE",
      yellow = "RAICHU" })[cell.edition]
    assert(result:find("durable_follower_species=" .. durable, 1, true))
    for _, token in ipairs({
        "fixed_identities=6/6", "ordinary_modes=3/3",
        "ordinary_classes=42/42",
        "title_rhythm=GREEN>POKEMON>BLUE>POKEMON>RED>POKEMON>GREEN",
        "crystal_species=28/28", "crystal_surfaces=9/9",
        "crystal_variants=2/2", "follower_evolution=1/1",
        "wilds_spawnfx=1/1", "wilds_randomizer_once=1/1",
        "wilds_johto_protection=1/1", "wilds_contact=1/1",
        "gorochu_intro_absent=1/1", "gorochu_sendout_present=1/1",
        "gorochu_hof=1/1",
      }) do assert(result:find(token, 1, true), token) end
  else
    assert(cell.edition == "red")
    assert(result:find("blitz_natural_restore=1/1", 1, true))
    assert(result:find(matrix.blitz.saveSha256, 1, true))
    assert(result:find(matrix.blitz.optionsSha256, 1, true))
    assert(result:find("durable_follower_species=ALAKAZAM", 1, true))
    assert(result:find("immutable_blitz_snapshot_unchanged=1/1", 1, true))
    assert(not result:find("follower_evolution=1/1", 1, true))
  end
end

assert(next(expected) and #matrix.cells == 8)
for id in pairs(expected) do assert(ids[id], id) end
for _, edition in ipairs(matrix.editions) do
  for _, renderer in ipairs(matrix.renderers) do
    assert(combinations[table.concat({ edition, renderer, "FRESH" }, "/")])
  end
end
for _, renderer in ipairs(matrix.renderers) do
  assert(combinations[table.concat({ "red", renderer, "BLITZ" }, "/")])
end

print("Presentation/motion package manifest PASS: 8 cells x bounded phases")
