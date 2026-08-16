local root = assert(os.getenv("KA_LEGACY_MOD"), "KA_LEGACY_MOD required")
local files = {
  "legacy_archive.lua", "legacy_journey.lua", "legacy_starters.lua",
  "tests/legacy_pact_three_journeys_visual_driver.lua",
  "tests/legacy_package_driver_contract_test.lua",
  "tools/legacy_package_matrix_manifest.lua",
}
for _, file in ipairs(files) do
  local chunk, why = loadfile(root .. "/" .. file)
  assert(chunk, file .. ": " .. tostring(why))
end
print("LEGACY PACKAGE DRIVER SYNTAX PASS: " .. #files .. " files")
