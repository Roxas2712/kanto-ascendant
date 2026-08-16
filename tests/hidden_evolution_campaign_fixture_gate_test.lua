-- Compact-fixture regression: Content-disabled Authority loads without maps.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local sdkRoot = root:sub(1, 1) == "/" and "/" or "."
local fixture = T.fixtures.load()
local run = T.sdk.loadMod(root, { data = fixture, root = sdkRoot })
T.eq(#run.errors, 0, "fixture load skips content-gated HEVO maps")
T.eq(fixture.maps.KA_HEVO_RED_UPPER, nil,
  "fixture data does not receive CAVERN campaign maps")
T.check(run.loader.exports.kanto_ascendant.hiddenEvolutionCampaign ~= nil,
  "fixture load exports the dormant campaign controller")
run.release()
T.finish("hidden_evolution_campaign_fixture_gate_test")
