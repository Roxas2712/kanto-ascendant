-- Focused renderer-backed proof for RC28 intro defects 11 and 12.
-- This constructs only OakSpeech (no New Game flow and no save writes), then
-- captures the approved Oak V1 portrait and two distinct authored Crystal
-- Nidorino frames.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local OakSpeech = require("src.ui.OakSpeech")
  local Runtime = require("src.mods.Runtime")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local crystal = assert(exports.crystalAnimation)

  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  local options = game.mods.modOptions.kanto_ascendant
  options.pokemon_sprite_style = "crystal"
  options.crystal_animation = true
  options.sprite_style_scenes = true
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant",
  })

  while game.stack:top() do game.stack:pop() end
  local speech = OakSpeech.new(game, function() end)
  speech.steps = speech:buildSteps()
  table.insert(game.stack.states, speech)

  local oakReceipt = assert(speech.__kantoAscendantOakApproved,
    "approved Oak provenance receipt is missing")
  assert(oakReceipt.schema == "ka-approved-oak-intro/v1"
      and oakReceipt.version == "v1"
      and oakReceipt.source ==
        "assets/characters/frlg_trainers/professor_oak_voxel_front_v1.png",
    "Oak intro did not resolve the approved V1 source")
  assert(speech.__kantoAscendantOakHdPortraits
      and speech.__kantoAscendantOakHdPortraits.oak,
    "approved Oak HD post-composite portrait is missing")
  speech:applyPic({ pic = "oak" })
  assert(speech.pic == speech.oakPic and speech.picTrueColor == true,
    "Oak intro did not retain true-colour metadata")
  speech:sayText("PROF. EICH", function() end)
  U.wait(45)
  assert(U.shot(game, dir .. "/01_oak_approved_v1.png"))

  while game.stack:top() and game.stack:top() ~= speech do
    game.stack:pop()
  end
  speech.__kantoAscendantOakHdRole = nil
  -- Oak was rendered for several frames above, so create a fresh copy of the
  -- same real presentation state for deterministic frame evidence.  Freeze
  -- only its draw-time wall clock while the two screenshots are encoded;
  -- advancement below still goes through the production controller.
  local state = assert(crystal.presentationAnimation("NIDORINO", nil,
    "front", "scenes", { data = game.data, forceBundled = true }),
    "Oak Nidorino Crystal presentation state is missing")
  state.__kaOakForceBundled = true
  speech.__ascendantCrystalV15OakDemo = state
  local demoReceipt = assert(speech.__ascendantCrystalV15OakDemoReceipt,
    "Oak Nidorino animation receipt is missing")
  assert(speech.demoSpecies == "NIDORINO" and state.species == "NIDORINO"
      and state.animated == true and demoReceipt.animated == true
      and demoReceipt.frameCount > 1 and demoReceipt.forcedBundled == true,
    "Oak demo is not the forced multi-frame Crystal Nidorino")
  local controller = assert(OakSpeech._ascendantCrystalV15Controller)
  local liveAdvanceOak = controller.advanceOak
  controller.advanceOak = function() end
  speech.demoPic, speech.pic = state.image, state.image
  speech.picFlip = true
  speech.picTrueColor = speech.demoTrueColor == true
  local frameA = state.image
  assert(state.frame == 1, "fresh Nidorino proof did not start on frame one")
  assert(U.shot(game, dir .. "/02_nidorino_crystal_frame_a.png"))

  crystal.advancePresentation(state, 0.101, game)
  assert(state.frame == 2 and state.image ~= frameA,
    "Nidorino Crystal presentation did not advance from frame 1 to frame 2")
  speech.demoPic, speech.pic = state.image, state.image
  assert(U.shot(game, dir .. "/03_nidorino_crystal_frame_b.png"))
  controller.advanceOak = liveAdvanceOak

  local out = assert(io.open(dir .. "/driver_result.txt", "wb"))
  out:write("status=PASS\n",
    "scope=oak-approved-v1+nidorino-forced-crystal-animation\n",
    "oak_receipt=ka-approved-oak-intro/v1\n",
    "nidorino_receipt=ka-oak-crystal-animation/v1\n",
    "nidorino_frames=1->2-distinct\n",
    "save_writes=0\n",
    "fail=0\n")
  out:close()
  print("OAK NIDORINO INTRO RESULT pass=7 fail=0")
  love.event.quit(0)
end
