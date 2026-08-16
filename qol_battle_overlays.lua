local M = {}
local FALLBACK_SNAP_STATE = "__kascRendererBattleHudSnapReceipt"
local FALLBACK_SNAP_HOOK = "__kascRendererBattleHudSnapHook"
local FALLBACK_SNAP_SCHEMA = "ka-renderer-battle-hud-snap/v1"

function M.new(mod)
  local voxelRenderer = mod.exports and mod.exports.voxelRendererCompat
  local rendererBattleHud = mod.exports and mod.exports.rendererBattleHud
  local overlays = {}
  local wrapped = setmetatable({}, { __mode = "k" })
  local installed = false
  local service = {}

  function service:add(overlay)
    overlays[#overlays + 1] = overlay
  end

  function service:install()
    if installed then return end
    installed = true
    mod.events:once("mods.loaded", function()
      -- renderer_battle_hud owns this observational hook in normal KASC
      -- loads.  Keep the same fail-closed receipt as a compatibility fallback
      -- for a reduced/headless load that did not construct that service.
      local handle, rendererId, reason, exported = voxelRenderer
        and voxelRenderer.find(mod)
      local lib = handle and exported and exported.lib
      if not lib or type(lib.require) ~= "function" then return end
      local ok, OverworldBattle = pcall(lib.require, "OverworldBattle")
      local snapKey = rendererBattleHud and rendererBattleHud.snapReceiptKey
        or FALLBACK_SNAP_STATE
      local hookKey = rendererBattleHud and rendererBattleHud.snapHookKey
        or FALLBACK_SNAP_HOOK
      local snapSchema = rendererBattleHud and rendererBattleHud.snapSchema
        or FALLBACK_SNAP_SCHEMA
      if not ok or type(OverworldBattle) ~= "table"
         or type(OverworldBattle.snapHUDs) ~= "function"
         or rawget(OverworldBattle, hookKey) then return end
      local snapHUDs = OverworldBattle.snapHUDs
      local hook = {
        original = snapHUDs, fallback = true, rendererId = rendererId,
      }
      OverworldBattle.snapHUDs = function(battle, shot, ...)
        if battle then
          battle[snapKey] = {
            schema = snapSchema, rendererId = hook.rendererId,
            shot = shot, snapped = false,
            reason = "snap-pending",
          }
        end
        local snapped = snapHUDs(battle, shot, ...)
        if battle then
          battle[snapKey] = {
            schema = snapSchema, rendererId = hook.rendererId,
            shot = shot, snapped = snapped == true,
            reason = snapped == true and nil or "snap-declined",
          }
        end
        return snapped
      end
      OverworldBattle[hookKey] = hook
    end)
    mod.events:on("battle.started", function(event)
      local battle = event and event.battle
      if not battle or wrapped[battle] or type(battle.draw) ~= "function" then
        return
      end

      local states = {}
      local failed = {}
      for i, overlay in ipairs(overlays) do
        states[i] = overlay.start and overlay.start(event) or {}
      end
      wrapped[battle] = states

      local baseDraw = battle.draw
      battle.draw = function(self, ...)
        baseDraw(self, ...)
        if self.blankForAskName then return end

        local fx = self.fx
        local sx = fx and fx.shakeX or 0
        local sy = fx and fx.shakeY or 0
        if sx == 0 and sy == 0 and fx and fx.shake and fx.shake > 0 then
          sx = self.frame % 4 < 2 and 2 or -2
        end
        -- The renderer contract validates the current-shot snap receipt and
        -- supplies explicit HP/band/text anchors.  When the service exists we
        -- never bypass a refusal by guessing from a raw shot field.
        local rendererHudContext
        if rendererBattleHud
            and type(rendererBattleHud.context) == "function" then
          local gotContext, value = pcall(rendererBattleHud.context, self)
          if gotContext then rendererHudContext = value end
        else
          -- Reduced/headless compatibility fallback for older KASC harnesses.
          local shot = rawget(self, "voxelAscendantShot")
            or rawget(self, "dramaticShapeShot")
          local receipt = rawget(self, FALLBACK_SNAP_STATE)
          if type(shot) == "table" and shot.canvas
              and type(shot.scale) == "number" and shot.scale > 0
              and type(shot.pw) == "number" and type(shot.ph) == "number"
              and type(shot.lx) == "number" and type(shot.ly) == "number"
              and type(receipt) == "table"
              and receipt.schema == FALLBACK_SNAP_SCHEMA
              and receipt.shot == shot and receipt.snapped == true then
            rendererHudContext = {
              schema = "ka-renderer-battle-hud-context/v1",
              shot = shot, canvas = shot.canvas, scale = shot.scale,
              enemyScale = shot.scale, playerScale = shot.scale,
              anchors = {
                hudTop = shot.ly, enemyHudLeft = 0, enemySourceX = 8,
                enemyScale = shot.scale,
                playerHudRight = shot.pw,
                playerScale = shot.scale,
                expRight = shot.pw - 13 * shot.scale,
                expY = shot.ly + 89 * shot.scale,
                caughtNameOrigin = -9 * shot.scale,
                caughtY = shot.ly + 7 * shot.scale,
                textLeft = shot.lx, textScale = shot.scale,
              },
            }
          end
        end
        local context = {
          sx = sx,
          sy = sy,
          slide = (self.introSlide or 0) * 4,
          rendererHud = rendererHudContext,
          -- Backward-compatible alias for third-party overlays registered on
          -- KASC's service.  New KASC features consume rendererHud anchors.
          voxel3dBattleData = rendererHudContext and rendererHudContext.shot,
        }

        for i, overlay in ipairs(overlays) do
          if not failed[i] then
            love.graphics.push("all")
            local ok, err = pcall(overlay.draw, self, states[i], context)
            love.graphics.pop()
            if not ok then
              failed[i] = true
              mod.log:error("%s battle overlay disabled: %s",
                overlay.id, tostring(err))
            end
          end
        end
      end
    end)
  end

  return service
end

return M
