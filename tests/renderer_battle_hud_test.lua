local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local checks = 0
local function ok(value, message)
  checks = checks + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, ("%s (got %s, want %s)")
    :format(message, tostring(actual), tostring(expected)))
end
local function rectEq(actual, expected, message)
  checks = checks + 1
  assert(type(actual) == "table", message .. " (missing rect)")
  for i = 1, 4 do
    assert(actual[i] == expected[i], ("%s[%d] (got %s, want %s)")
      :format(message, i, tostring(actual[i]), tostring(expected[i])))
  end
end
local function countKeys(values)
  local count = 0
  for _ in pairs(values or {}) do count = count + 1 end
  return count
end

local originalCalls = 0
local BattleState = {
  drawHUDs = function(_, slide)
    originalCalls = originalCalls + 1
    return "native", slide
  end,
}
package.loaded["src.battle.BattleState"] = BattleState

local events = {}
local mod = {
  events = {
    once = function(_, name, fn) events[name] = fn end,
    on = function(_, name, fn) events[name] = fn end,
  },
}
local current = { id = nil, version = nil, module = nil }
local resolver = {
  module = function(_, name)
    eq(name, "OverworldBattle", "HUD bridge requests only the public module")
    if not current.module then return nil, nil, "renderer-absent" end
    return current.module, current.id, nil, {
      rendererVersion = current.version,
    }
  end,
}

local function makeShot(id, pw, lx)
  return {
    canvas = { id = id }, scale = 4,
    pw = pw or 800, ph = 576, lx = lx or 80, ly = 0,
  }
end

local shotRc = makeShot("rc")
local shotWide = makeShot("wide")
local currentShot = shotRc
local snapAllowed = true
local snapError
local snapCalls, panelCalls = 0, 0
local snapTextCounts, snapModes = {}, {}
local panelEnemy, panelPlayer, panelTextCount
local panelHistory = {}
local renderer
renderer = {
  HUD_RECT = {
    enemy = { 8, 0, 80, 32 },
    player = { 72, 56, 88, 40 },
  },
  HUD_BAND = {
    enemy = { 0, 0, 160, 48 },
    player = { 0, 48, 160, 48 },
  },
  TEXT_RECT = {
    box = { 0, 96, 160, 48 },
    moves = { 0, 64, 88, 32 },
    mimic = { 0, 56, 128, 40 },
  },
  sideTexture = function() end,
  shot = function() return currentShot end,
  snapRects = function(liveShot)
    local scale = liveShot.scale
    local ex = -8 * scale
    local px = liveShot.pw - 160 * scale
    return {
      enemy = { 0, liveShot.ly, 80 * scale, 32 * scale },
      player = {
        px + 72 * scale, liveShot.ly + 56 * scale,
        88 * scale, 40 * scale,
      },
    }, { enemy = ex, player = px }
  end,
  textRects = function(battle)
    local out = { box = renderer.TEXT_RECT.box }
    if battle and battle.phase == "moveSelect" then
      out.moves = renderer.TEXT_RECT.moves
    elseif battle and battle.phase == "mimicSelect" then
      out.mimic = renderer.TEXT_RECT.mimic
    end
    return out
  end,
  hudLive = function() return true, true end,
}
renderer.snapHUDs = function(battle, liveShot)
  snapCalls = snapCalls + 1
  snapTextCounts[#snapTextCounts + 1] = countKeys(renderer.textRects(battle))
  snapModes[#snapModes + 1] = {
    introBalls = battle and battle.introBalls,
    safari = battle and battle.safari,
  }
  if snapError then error(snapError) end
  return snapAllowed and battle and liveShot
    and (battle.voxelAscendantShot == liveShot
      or battle.dramaticShapeShot == liveShot
      or battle.battleArtShot == liveShot)
end
renderer.drawHudPanels = function(battle)
  panelCalls = panelCalls + 1
  panelEnemy, panelPlayer = renderer.hudLive(battle, 0)
  panelTextCount = countKeys(renderer.textRects(battle))
  panelHistory[#panelHistory + 1] = {
    enemy = panelEnemy, player = panelPlayer, text = panelTextCount,
  }
  return "panels"
end

local make = assert(loadfile(root .. "/renderer_battle_hud.lua"))()
local hud = make(mod, { voxelRenderer = resolver })
ok(events["mods.loaded"] and events["game.ready"],
  "HUD profile refreshes on both renderer lifecycle boundaries")

events["mods.loaded"]({ game = {} })
eq(hud.inspect().profile, "NATIVE_2D", "renderer-free play keeps native 2D")

-- DRAMALESS remains renderer-owned.  KASC observes its public snap only to
-- place its own overlays in that already-selected geometry.
current.id, current.version, current.module =
  "DRAMALESS_SHAPE", "1.6.2-ST.190.1", renderer
events["game.ready"]({ game = {} })
eq(hud.inspect().profile, "DRAMALESS_RENDERER_NATIVE",
  "DRAMALESS retains renderer-owned HUD geometry")
local dramaticShot = makeShot("dramaless", 720, 40)
local dramaticBattle = {
  dramaticShapeShot = dramaticShot, phase = "moveSelect",
}
ok(renderer.snapHUDs(dramaticBattle, dramaticShot),
  "DRAMALESS public snap remains callable unchanged")
local dramaticGeometry = hud.context(dramaticBattle)
ok(dramaticGeometry and dramaticGeometry.shot == dramaticShot,
  "DRAMALESS overlay geometry follows its own snapped shot")
local result = BattleState.drawHUDs(dramaticBattle, 7)
eq(result, "native", "DRAMALESS does not acquire KASC HUD ownership")
eq(originalCalls, 1, "DRAMALESS delegates through the original HUD chain")

-- Both reviewed Voxel releases select the same explicit cooperative profile.
-- Runtime receipts, not the version string, decide who snapped this frame.
current.id, current.version = "VOXEL_ASCENDANT", "0.1.0-rc.1"
events["game.ready"]({ game = {} })
eq(hud.inspect().profile, "KASC_VASC_WIDE",
  "Voxel RC selects the explicit wide-edge profile")
local voxelBattle = {
  voxelAscendantShot = shotRc, phase = "moveSelect",
  introBalls = true, safari = true,
}
currentShot = shotRc
ok(renderer.snapHUDs(voxelBattle, shotRc),
  "renderer-owned RC snap records the current shot")
local callsAfterNativeSnap = snapCalls
result = BattleState.drawHUDs(voxelBattle, 8)
eq(result, "native", "renderer-owned snap delegates through captured wrappers")
eq(snapCalls, callsAfterNativeSnap,
  "current-shot receipt prevents a duplicate KASC snap")
eq(hud.inspect().nativeSnapCount, 1,
  "renderer-owned current frame has an explicit diagnostic receipt")

current.version = "0.1.1"
events["game.ready"]({ game = {} })
eq(hud.inspect().profile, "KASC_VASC_WIDE",
  "Voxel 0.1.1 selects the same capability profile without a version branch")
currentShot = shotWide
voxelBattle.voxelAscendantShot = shotWide
renderer.drawHudPanels(voxelBattle)
eq(panelCalls, 1, "centred panel pass still runs for menu/text glass")
eq(panelEnemy, false, "compact enemy HP glass is suppressed")
eq(panelPlayer, false, "compact player HP glass is suppressed")
eq(panelTextCount, 2, "move menu and text glass remain in the centred UI")
eq(renderer.hudLive(), true, "temporary HUD visibility override is restored")

result = BattleState.drawHUDs(voxelBattle, 9)
eq(result, nil, "successful cooperative snap suppresses compact HUD glyphs")
eq(snapTextCounts[#snapTextCounts], 0,
  "KASC snap omits text glass to avoid a duplicate dark menu layer")
eq(countKeys(renderer.textRects(voxelBattle)), 2,
  "text geometry is restored immediately after the snap")
eq(originalCalls, 2, "successful KASC snap skips the compact HUD path")

-- Exact visual-coordinate receipt for a 4x 800x576 landscape shot.
local geometry = assert(hud.context(voxelBattle))
eq(geometry.schema, "ka-renderer-battle-hud-context/v1",
  "overlay geometry has a versioned public schema")
rectEq(geometry.hp.enemy, { 0, 0, 320, 128 },
  "enemy HP/status panel is flush with the left edge")
rectEq(geometry.hp.player, { 448, 224, 352, 160 },
  "player HP/status panel is flush with the right edge")
rectEq(geometry.bands.enemy, { -32, 0, 640, 192 },
  "enemy HUD/party band retains the full renderer crop")
rectEq(geometry.bands.player, { 160, 192, 640, 192 },
  "player HUD/party/Safari band retains the full renderer crop")
rectEq(geometry.partySafariCoverage.enemyParty,
  { -32, 0, 640, 192 }, "enemy Pokéball row is inside snapped coverage")
rectEq(geometry.partySafariCoverage.playerParty,
  { 160, 192, 640, 192 }, "player Pokéball row is inside snapped coverage")
rectEq(geometry.partySafariCoverage.safari,
  { 160, 192, 640, 192 }, "Safari counter is inside snapped coverage")
rectEq(geometry.text.box, { 80, 384, 640, 192 },
  "main text box remains mapped to the centred GB frame")
rectEq(geometry.text.moves, { 80, 256, 352, 128 },
  "move menu clipping boundary remains mapped to the centred GB frame")
eq(geometry.anchors.expRight, 748,
  "EXP semantic anchor ends thirteen native pixels before player HUD edge")
eq(geometry.anchors.expY, 356,
  "EXP semantic anchor retains the engine HUD baseline")
eq(geometry.anchors.caughtNameOrigin, -36,
  "caught semantic anchor includes the enemy source-panel inset")
eq(geometry.anchors.caughtY, 28,
  "caught semantic anchor retains the enemy-name baseline")

voxelBattle.voxelAscendantShot = nil
result = BattleState.drawHUDs(voxelBattle, 10)
eq(result, "native", "missing Voxel shot falls back to the original HUD")
eq(originalCalls, 3, "missing-shot fallback invokes the original once")

local declinedShot = makeShot("declined")
voxelBattle.voxelAscendantShot = declinedShot
currentShot, snapAllowed = declinedShot, false
local panelsBeforeFallback = #panelHistory
renderer.drawHudPanels(voxelBattle)
result = BattleState.drawHUDs(voxelBattle, 11)
eq(result, "native", "declined snap fails back to compact HUD")
eq(originalCalls, 4, "declined snap invokes the original exactly once")
eq(#panelHistory, panelsBeforeFallback + 2,
  "declined snap adds one text pass and one compact-panel recovery")
eq(panelHistory[panelsBeforeFallback + 1].enemy, false,
  "declined snap first suppresses compact enemy glass")
eq(panelHistory[panelsBeforeFallback + 1].text, 2,
  "declined snap keeps centred text glass in the first pass")
eq(panelHistory[panelsBeforeFallback + 2].enemy, true,
  "declined snap restores compact enemy glass exactly once")
eq(panelHistory[panelsBeforeFallback + 2].player, true,
  "declined snap restores compact player glass exactly once")
eq(panelHistory[panelsBeforeFallback + 2].text, 0,
  "declined snap does not frost centred text glass twice")
eq(hud.context(voxelBattle), nil,
  "declined current shot cannot spoof renderer overlay geometry")
snapAllowed = true

local mismatchShot = makeShot("mismatch")
voxelBattle.voxelAscendantShot = mismatchShot
currentShot = makeShot("different-live-shot")
panelsBeforeFallback = #panelHistory
renderer.drawHudPanels(voxelBattle)
result = BattleState.drawHUDs(voxelBattle, 12)
eq(result, "native", "shot mismatch fails back to compact HUD")
eq(originalCalls, 5, "shot mismatch invokes the original exactly once")
eq(#panelHistory, panelsBeforeFallback + 2,
  "shot mismatch restores compact panels exactly once")
eq(panelHistory[panelsBeforeFallback + 2].enemy, true,
  "shot mismatch restores enemy glass")
eq(panelHistory[panelsBeforeFallback + 2].player, true,
  "shot mismatch restores player glass")
eq(panelHistory[panelsBeforeFallback + 2].text, 0,
  "shot mismatch recovery omits duplicate text glass")

local throwingShot = makeShot("throwing")
voxelBattle.voxelAscendantShot = throwingShot
currentShot, snapError = throwingShot, "injected snap failure"
panelsBeforeFallback = #panelHistory
renderer.drawHudPanels(voxelBattle)
result = BattleState.drawHUDs(voxelBattle, 13)
eq(result, "native", "throwing snap fails back to compact HUD")
eq(originalCalls, 6, "throwing snap invokes the original exactly once")
eq(#panelHistory, panelsBeforeFallback + 2,
  "throwing snap restores compact panels exactly once")
eq(panelHistory[panelsBeforeFallback + 2].enemy, true,
  "throwing snap restores enemy glass")
eq(panelHistory[panelsBeforeFallback + 2].player, true,
  "throwing snap restores player glass")
eq(panelHistory[panelsBeforeFallback + 2].text, 0,
  "throwing snap recovery omits duplicate text glass")
snapError = nil
currentShot = throwingShot

local wrapper = BattleState.drawHUDs
events["game.ready"]({ game = {} })
eq(BattleState.drawHUDs, wrapper, "hot refresh does not stack HUD wrappers")

-- Exact upstream Battle Art 1.9.2 owns its snap pass and publishes placement
-- objects because HUD SCALE:SCALED uses max(1, shot.scale - 1). The resolver
-- pins repository/version; this layer consumes only that approved module.
local legacySnapRects = renderer.snapRects
local battleArtSnapRects = function(liveShot)
  local s, hs = liveShot.scale, math.max(1, liveShot.scale - 1)
  local e, p = renderer.HUD_RECT.enemy, renderer.HUD_RECT.player
  local ex = (2 - e[1]) * hs
  local px = liveShot.pw - (p[1] + p[3]) * hs
  return {
    enemy = { ex + e[1] * hs, liveShot.ly + e[2] * s,
      e[3] * hs, e[4] * hs },
    player = { px + p[1] * hs, liveShot.ly + p[2] * s,
      p[3] * hs, p[4] * hs },
  }, {
    enemy = { x = ex, y = liveShot.ly, scale = hs },
    player = { x = px,
      y = liveShot.ly + p[2] * s
        - (p[2] - renderer.HUD_BAND.player[2]) * hs,
      scale = hs },
  }
end
renderer.snapRects = battleArtSnapRects
current.id, current.version = "BATTLE_ART_VOXEL_FORK", "1.9.2"
events["game.ready"]({ game = {} })
eq(hud.inspect().profile, "BATTLE_ART_RENDERER_NATIVE",
  "reviewed Battle Art selects its renderer-owned profile")
local battleArtShot = makeShot("battle-art-1.9", 800, 80)
local battleArtBattle = {
  dramaticShapeShot = battleArtShot, phase = "moveSelect",
  introBalls = true, safari = true,
}
ok(renderer.snapHUDs(battleArtBattle, battleArtShot),
  "Battle Art owns its snap pass")
local battleArtGeometry = assert(hud.context(battleArtBattle))
eq(battleArtGeometry.enemyScale, 3,
  "Battle Art enemy HUD uses its compact integer rung")
eq(battleArtGeometry.playerScale, 3,
  "Battle Art player HUD uses its compact integer rung")
eq(battleArtGeometry.scale, 4,
  "Battle Art text/world geometry retains the fit scale")
rectEq(battleArtGeometry.bands.enemy, { -18, 0, 480, 144 },
  "enemy party row follows Battle Art's exact band placement")
rectEq(battleArtGeometry.bands.player, { 320, 200, 480, 144 },
  "player party/Safari row follows Battle Art's exact band placement")
rectEq(battleArtGeometry.partySafariCoverage.safari,
  { 320, 200, 480, 144 },
  "Safari coverage follows the renderer-owned player band")
eq(battleArtGeometry.anchors.expRight, 761,
  "EXP right edge follows Battle Art's compact player HUD")
eq(battleArtGeometry.anchors.expY, 323,
  "EXP baseline follows Battle Art's relocated player band")
eq(battleArtGeometry.anchors.caughtY, 21,
  "caught marker follows Battle Art's compact enemy band")
local snapCountBeforeBattleArtDraw = hud.inspect().snapCount
BattleState.drawHUDs(battleArtBattle, 14)
eq(hud.inspect().snapCount, snapCountBeforeBattleArtDraw,
  "KASC never acquires Battle Art snap ownership")

-- A doubles-capable companion may add secondary battler slots to the same
-- BattleState. They do not create a second screen-space HUD anchor: Battle
-- Art remains the only snap owner and KASC must not decorate that anchor on
-- either draw pass.
local battleArtDoubleShot = makeShot("battle-art-double", 800, 80)
local battleArtDouble = {
  dramaticShapeShot = battleArtDoubleShot, phase = "moveSelect",
  doubleBattle = true,
  enemy = { mon = { species = "PRIMARY_ENEMY" } },
  enemyPartner = { mon = { species = "SECONDARY_ENEMY" } },
  player = { mon = { species = "PRIMARY_PLAYER" } },
  playerPartner = { mon = { species = "SECONDARY_PLAYER" } },
}
local doubleOwnerSnaps = snapCalls
ok(renderer.snapHUDs(battleArtDouble, battleArtDoubleShot),
  "Battle Art owns the shared doubles HUD anchor")
local doubleKascSnaps = hud.inspect().snapCount
BattleState.drawHUDs(battleArtDouble, 14)
BattleState.drawHUDs(battleArtDouble, 14)
eq(snapCalls, doubleOwnerSnaps + 1,
  "two doubles draw passes do not snap the shared anchor twice")
eq(hud.inspect().snapCount, doubleKascSnaps,
  "KASC never acquires the Battle Art doubles HUD anchor")
renderer.snapRects = legacySnapRects

-- Overlay service consumes the normalized profile, not renderer-specific raw
-- fields.  A stale/missing receipt is inert.
current.id, current.version = "VOXEL_ASCENDANT", "0.1.1"
events["game.ready"]({ game = {} })
currentShot = shotWide
voxelBattle.voxelAscendantShot = shotWide
voxelBattle.phase = "moveSelect"
renderer.snapHUDs(voxelBattle, shotWide)

local overlayEvents = {}
local overlayDrawContext
love = { graphics = { push = function() end, pop = function() end } }
local overlayMod = {
  exports = {
    voxelRendererCompat = {
      find = function()
        return {}, "VOXEL_ASCENDANT", nil, {
          lib = { require = function(name)
            eq(name, "OverworldBattle",
              "overlay fallback requests only the public battle module")
            return renderer
          end },
        }
      end,
    },
    rendererBattleHud = hud,
  },
  events = {
    once = function(_, name, fn) overlayEvents[name] = fn end,
    on = function(_, name, fn) overlayEvents[name] = fn end,
  },
  log = { error = function(_, message) error(message) end },
}
local overlayService = assert(loadfile(root .. "/qol_battle_overlays.lua"))()
  .new(overlayMod)
overlayService:add({
  id = "geometry receipt",
  draw = function(_, _, context) overlayDrawContext = context end,
})
overlayService:install()
overlayEvents["mods.loaded"]()
voxelBattle.draw = function() end
voxelBattle.fx, voxelBattle.frame = {}, 1
overlayEvents["battle.started"]({ battle = voxelBattle })
voxelBattle:draw()
ok(overlayDrawContext.rendererHud
    and overlayDrawContext.rendererHud.shot == shotWide,
  "Voxel overlays receive normalized current-shot geometry")
eq(overlayDrawContext.voxel3dBattleData, shotWide,
  "legacy overlay alias points at the same validated shot")

current.id, current.version = "DRAMALESS_SHAPE", "1.6.2-ST.190.1"
events["game.ready"]({ game = {} })
local dramaticOverlayShot = makeShot("dramaless-overlay", 720, 40)
local dramaticOverlayBattle = {
  draw = function() end, dramaticShapeShot = dramaticOverlayShot,
  fx = {}, frame = 2,
}
renderer.snapHUDs(dramaticOverlayBattle, dramaticOverlayShot)
overlayEvents["battle.started"]({ battle = dramaticOverlayBattle })
dramaticOverlayBattle:draw()
eq(overlayDrawContext.rendererHud.profile, "DRAMALESS_RENDERER_NATIVE",
  "DRAMALESS retains its normalized renderer-owned overlay profile")

local spoofBattle = {
  draw = function() end, dramaticShapeShot = makeShot("spoof"),
  fx = {}, frame = 3,
}
overlayEvents["battle.started"]({ battle = spoofBattle })
spoofBattle:draw()
eq(overlayDrawContext.rendererHud, nil,
  "raw shot without a matching snap receipt fails closed")

-- Feature-level coordinate receipts: EXP uses the player panel's right edge,
-- clips under the centred move menu, and caught follows the shaken enemy HUD.
current.id, current.version = "VOXEL_ASCENDANT", "0.1.1"
events["game.ready"]({ game = {} })
local narrowShot = makeShot("narrow", 640, 0)
local featureBattle = {
  voxelAscendantShot = narrowShot, phase = nil,
  player = { mon = { species = 1, level = 5, exp = 67 } },
  data = {
    pokemon = { [1] = { growthRate = 1 } },
    growth_rates = {}, constants = { levelCap = 100 },
  },
  game = {}, frame = 20, fx = { hudShakeX = 2 },
  wideLayout = function() return false end,
}
currentShot = narrowShot
BattleState.drawHUDs(featureBattle, 0)
local featureGeometry = assert(hud.context(featureBattle))

package.loaded["src.render.Font"] = {
  BORDER = { v = 1, bl = 2, br = 3, h = 4 },
  drawCode = function() end,
}
package.loaded["src.pokemon.Growth"] = {
  expForLevel = function(_, level)
    return level <= 5 and 0 or 67
  end,
}
package.loaded["src.render.HudTiles"] = {
  tile = function() end, capTile = function() return 0 end,
}
local marked = 0
package.loaded["src.render.PaletteFX"] = {
  markTrueColor = function() marked = marked + 1 end,
}

local rectangles, draws, selectedCanvas = {}, {}, nil
local fakeImage = { getDimensions = function() return 8, 8 end }
love = {
  graphics = {
    setCanvas = function(value) selectedCanvas = value end,
    setShader = function() end,
    setColor = function() end,
    rectangle = function(mode, x, y, w, h)
      rectangles[#rectangles + 1] = { mode, x, y, w, h }
    end,
    newImage = function() return fakeImage end,
    newQuad = function() return { id = "ball-quad" } end,
    draw = function(image, quad, x, y, rotation, sx, sy)
      draws[#draws + 1] = { image, quad, x, y, rotation, sx, sy }
    end,
  },
}

local expOverlay
local expMod = { exports = {} }
local expServices = {
  options = { value = function() return "blue" end },
  battle = { add = function(_, value) expOverlay = value end },
}
assert(loadfile(root .. "/qol_feature_xp_bar.lua"))()
  .install(expMod, expServices)
local expState = {}
expOverlay.draw(featureBattle, expState, {
  slide = 0, sx = 0, sy = 0, rendererHud = featureGeometry,
  voxel3dBattleData = narrowShot,
})
local expRect = rectangles[#rectangles]
rectEq({ expRect[2], expRect[3], expRect[4], expRect[5] },
  { 320, 356, 268, 8 },
  "KASC EXP fill ends 13 native pixels before the player HUD edge")
eq(selectedCanvas, narrowShot.canvas,
  "KASC EXP fill targets the renderer world canvas")

featureBattle.phase = "moveSelect"
featureBattle.frame = featureBattle.frame + 1
expOverlay.draw(featureBattle, expState, {
  slide = 0, sx = 0, sy = 0, rendererHud = featureGeometry,
  voxel3dBattleData = narrowShot,
})
expRect = rectangles[#rectangles]
rectEq({ expRect[2], expRect[3], expRect[4], expRect[5] },
  { 352, 356, 236, 8 },
  "EXP fill clips exactly at the move-menu right boundary")

local caughtOverlay
local caughtMod = {
  id = "kanto_ascendant",
  exports = {},
  ui = { Font = { split = function(text)
    local out = {}
    for i = 1, #text do out[i] = text:sub(i, i) end
    return out
  end } },
  log = { warn = function() end },
}
local caughtServices = {
  options = { value = function() return "red" end },
  battle = { add = function(_, value) caughtOverlay = value end },
}
assert(loadfile(root .. "/qol_feature_caught_indicator.lua"))()
  .install(caughtMod, caughtServices)
local caughtBattle = {
  game = { save = { pokedex = { owned = { [25] = true } } } },
  kind = "wild", enemy = { name = "MEW", fainted = false },
  fx = { hudShakeX = 2 },
  growInScale = function() return false end,
  wideLayout = function() return false end,
}
local caughtState = caughtOverlay.start({ battle = caughtBattle, species = 25 })
caughtOverlay.draw(caughtBattle, caughtState, {
  slide = 0, sx = 0, sy = 0, rendererHud = featureGeometry,
  voxel3dBattleData = narrowShot,
})
local caughtDraw = draws[#draws]
eq(caughtDraw[3], 36,
  "caught icon follows enemy name and two-pixel HUD shake at 4x")
eq(caughtDraw[4], 28, "caught icon retains the seven-pixel HUD baseline")
eq(caughtDraw[6], 4, "caught icon uses the renderer's integer scale")
eq(marked, 0, "renderer-canvas overlays do not mark the 2D palette mask")

-- The same KASC overlays follow Battle Art's separate 3x HUD rung while its
-- 4x text/world projection remains untouched.
renderer.snapRects = battleArtSnapRects
current.id, current.version = "BATTLE_ART_VOXEL_FORK", "1.9.2"
events["game.ready"]({ game = {} })
local battleFeatureShot = makeShot("battle-art-feature", 800, 80)
local battleFeature = {
  dramaticShapeShot = battleFeatureShot, phase = nil,
  player = { mon = { species = 1, level = 5, exp = 67 } },
  data = featureBattle.data,
  game = {}, frame = 30, fx = { hudShakeX = 2 },
  wideLayout = function() return false end,
}
ok(renderer.snapHUDs(battleFeature, battleFeatureShot),
  "Battle Art feature frame has a renderer-owned snap receipt")
local battleFeatureGeometry = assert(hud.context(battleFeature))
local battleExpState = {}
expOverlay.draw(battleFeature, battleExpState, {
  slide = 0, sx = 0, sy = 0, rendererHud = battleFeatureGeometry,
  voxel3dBattleData = battleFeatureShot,
})
expRect = rectangles[#rectangles]
rectEq({ expRect[2], expRect[3], expRect[4], expRect[5] },
  { 560, 323, 201, 6 },
  "EXP fill uses Battle Art's 3x player HUD scale and relocated baseline")

caughtBattle.dramaticShapeShot = battleFeatureShot
ok(renderer.snapHUDs(caughtBattle, battleFeatureShot),
  "Battle Art caught frame has a renderer-owned snap receipt")
local battleCaughtGeometry = assert(hud.context(caughtBattle))
caughtOverlay.draw(caughtBattle, caughtState, {
  slide = 0, sx = 0, sy = 0, rendererHud = battleCaughtGeometry,
  voxel3dBattleData = battleFeatureShot,
})
caughtDraw = draws[#draws]
eq(caughtDraw[3], 33,
  "caught icon follows Battle Art's compact enemy HUD and shake")
eq(caughtDraw[4], 21,
  "caught icon uses Battle Art's relocated enemy baseline")
eq(caughtDraw[6], 3,
  "caught icon uses Battle Art's renderer-owned enemy scale")
renderer.snapRects = legacySnapRects

print(("renderer_battle_hud_test: PASS (%d checks)"):format(checks))
