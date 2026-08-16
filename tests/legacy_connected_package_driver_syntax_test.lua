-- Engine-Lua syntax and manifest-shape guard for the connected L04 package
-- supplement.  This test does not launch LÖVE or execute any package driver.

local files = {
  "tests/legacy_connected_language_setup_driver.lua",
  "tests/legacy_story_partner_fresh_e2e_driver.lua",
  "tools/legacy_archive_transaction_package_driver.lua",
  "tests/legacy_archive_daycare_visual_driver.lua",
  "tools/ngplus_legacy_workshop_e2e_driver.lua",
  "tools/ngplus_legacy_workshop_resonance_e2e_driver.lua",
  "tests/legacy_wanderer_title_visual_driver.lua",
  "tools/legacy_connected_package_matrix_manifest.lua",
}

for _, path in ipairs(files) do
  local chunk, err = loadfile(path)
  assert(chunk, path .. " does not compile: " .. tostring(err))
end

local cells = assert(dofile(
  "tools/legacy_connected_package_matrix_manifest.lua"))
assert(#cells == 11, "connected Legacy manifest must have eleven cells")
local ids, identities, stories = {}, {}, {}
local full = 0
for _, cell in ipairs(cells) do
  assert(type(cell.id) == "string" and not ids[cell.id],
    "duplicate/missing connected Legacy cell id")
  assert(type(cell.identity) == "string" and not identities[cell.identity],
    "duplicate/missing connected Legacy identity")
  ids[cell.id], identities[cell.identity] = true, true
  assert(cell.edition == "red" or cell.edition == "blue"
      or cell.edition == "yellow", "invalid connected Legacy edition")
  assert(cell.closure == "base_deutsch"
      or cell.closure == "dramaless_fp", "invalid package closure")
  if cell.closure == "dramaless_fp" then full = full + 1 end
  assert(type(cell.driver) == "string"
      and (cell.driver:match("^tests/") or cell.driver:match("^tools/")),
    "invalid package driver")
  assert(cell.result and type(cell.result.contains) == "table"
      and #cell.result.contains > 0, "cell lacks a fail-closed result")
  local required = {}
  for _, token in ipairs(cell.result.contains) do required[token] = true end
  assert(required["status=PASS"] and required["fail=0"],
    "cell lacks PASS/fail=0 receipts")
  assert(required["engine_payload_sha256="]
      and required["authority_package_sha256="]
      and required["deutsch_package_sha256="]
      and required["package_gate_receipt_sha256="],
    "cell lacks pinned artifact receipt rows")
  if cell.id:match("^l04%-connected%-%a+%-%a+$") then
    stories[cell.edition .. ":" .. cell.env.QA_LANGUAGE] = cell
    assert(cell.passes and #cell.passes == 2
        and cell.passes[1].driver ==
          "tests/legacy_connected_language_setup_driver.lua"
        and cell.passes[2].driver ==
          "tests/legacy_story_partner_fresh_e2e_driver.lua",
      "story cell lacks its native language/reboot sequence")
  end
end

for _, edition in ipairs({ "red", "blue", "yellow" }) do
  for _, locale in ipairs({ "en", "de" }) do
    assert(stories[edition .. ":" .. locale],
      "missing connected story cell " .. edition .. "/" .. locale)
  end
end
assert(stories["yellow:en"].env.QA_YELLOW_PATH == "catalog"
    and stories["yellow:de"].env.QA_YELLOW_PATH == "pikachu",
  "Yellow cells do not cover Catalogue and Pikachu paths")
assert(full == 1 and ids["l04-workshop-full"],
  "connected Legacy supplement must own exactly one FULL representative")
assert(ids["l04-archive-transaction"]
    and ids["l04-archive-daycare-de"]
    and ids["l04-workshop-resonance-2d"]
    and ids["l04-title-archive-card-de"],
  "connected Legacy focused cells are incomplete")

print("legacy connected package driver syntax/manifest test: PASS")
