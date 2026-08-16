-- Focused real-LÖVE regression for the Legacy/New Game+ Oak host overlay.
-- It stages the already-tested qualified first-journey receipts, opens the
-- production journey intro, proves the text is A-gated, then advances to the
-- real four-pact menu.  The PNG must show both the full Oak PicBox and the
-- complete TextBox; a bounded state sgbPalettes() owner clips that screen to
-- a 72x72 rectangle on gen1recomp 0.1.96.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local TextBox = require("src.render.TextBox")
  local PicBox = require("src.ui.PicBox")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local api = assert(game.mods.exports.kanto_ascendant)
  local journey = assert(api.legacyJourney)
  local layout = os.getenv("QA_UI_LAYOUT") or "dynamic"
  assert(layout == "dynamic" or layout == "centered",
    "QA_UI_LAYOUT must be dynamic or centered")
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    return value
  end

  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end

  local edition = GameVersion.get()
  local slot = os.getenv("QA_SLOT") or "slot65_oak_host_textbox_0196"
  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve isolated Oak-host slot")
  local fresh = SaveData.newGame(game:bootConfig())
  game.save = fresh
  game:adoptSave(fresh)
  Runtime.emit("save.created", { save = fresh })
  U.wait(35)

  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.options.uiLayout = layout
  game.save.player.name = "BLITZ"
  game.save.hallOfFame = { { name = "BLITZ" } }
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  api.extendedCharacters.select("RED")
  local bucket = assert(game.save.modData.kanto_ascendant)
  -- This test owns only the presentation boundary.  Stage the already-tested
  -- durable authorities exactly as a completed RED path leaves them; the
  -- focused dungeon suites exercise the physical seal and black-door route.
  bucket.hevo_run = bucket.hevo_run or {}
  bucket.hevo_run.dungeonLegacy = {
    seals = { RED = true }, reentered = { RED = true },
  }
  bucket.hidden_evolution_story_campaign =
    bucket.hidden_evolution_story_campaign or {}
  bucket.hidden_evolution_story_campaign.doorVisits =
    bucket.hidden_evolution_story_campaign.doorVisits or {}
  bucket.hidden_evolution_story_campaign.doorVisits.RED = true
  local gateReady = journey.reconcileHevoSealGate(game.save, false)
  check("focused fixture contains the matching completed RED path",
    journey.currentHevoSeal(game.save, "RED") == true
      and journey.currentHevoDoorVisit(game.save, "RED") == true)
  check("Hall, matching seal and shared-door visit arm Legacy", gateReady == true
    and journey.canBegin(game.save) == true)

  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  U.wait(20)
  check("production journey intro opens", journey.begin(game) == true)

  local intro = waitFor(function()
    local top = game.stack:top()
    return top and getmetatable(top) == TextBox and top or nil
  end)
  local states = game.stack.states or {}
  local portrait = states[#states - 1]
  check("real TextBox is stacked over the real Oak PicBox",
    intro ~= nil and portrait ~= nil and getmetatable(portrait) == PicBox)
  check("portrait uses additive draw marking, never palette ownership",
    portrait and portrait.kascTrueColorDrawMark == true
      and portrait.kascTrueColorPortrait == true
      and portrait.sgbPalettes == nil)
  check("TextBox retains the complete 20x6-tile geometry",
    intro and intro.boxTx == 0 and intro.boxTy == 12
      and intro.boxTw == 20 and intro.boxTh == 6)

  local firstPage = waitFor(function()
    return game.stack:top() == intro and (intro.waiting or intro.done)
      and intro or nil
  end, 1200)
  local heldPage = firstPage and firstPage.pageIndex
  if firstPage then U.wait(30) end
  check("Oak's first page waits for A instead of auto-scrolling",
    firstPage ~= nil and game.stack:top() == intro
      and intro.pageIndex == heldPage and (intro.waiting or intro.done))
  check("full Oak portrait and TextBox render capture",
    firstPage and U.shot(game, dir .. "/legacy_oak_host_textbox_fixed.png"))

  local pactMenu = waitFor(function()
    local top = game.stack:top()
    if top and type(top.items) == "table" then return top end
    if top == intro and (top.waiting or top.done) then
      U.tap(game, "a")
    else
      U.wait(1)
    end
    return nil
  end, 5000)
  check("A advances every page into the real four-pact menu",
    pactMenu ~= nil and #pactMenu.items == 4)
  local portraitStillStacked = false
  local pactMenuCount = 0
  for _, state in ipairs(game.stack.states or {}) do
    if state == portrait then portraitStillStacked = true end
    if type(state and state.items) == "table" and #state.items == 4 then
      pactMenuCount = pactMenuCount + 1
    end
  end
  check("completed intro removes only its portrait overlay",
    pactMenu ~= nil and not portraitStillStacked)
  check("Oak completion callback opens the pact menu exactly once",
    pactMenuCount == 1)
  check("post-input pact menu capture",
    pactMenu and U.shot(game, dir .. "/legacy_oak_host_after_a_pact_menu.png"))

  U.log(("LEGACY OAK HOST TEXTBOX RESULT pass=%d fail=%d")
    :format(pass, fail))
  local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
  result:write((fail == 0 and "PASS" or "FAIL"), "\n")
  result:write(("engine=0.1.96\nlayout=%s\npass=%d\nfail=%d\n")
    :format(layout, pass, fail))
  result:write(("a_gated=true\ncallback_menu_count=%d\n")
    :format(pactMenuCount))
  result:close()
  love.event.quit(fail == 0 and 0 or 1)
end
