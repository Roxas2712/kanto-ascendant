local M = {}

function M.new(mod)
  local overlays = {}
  local wrapped = setmetatable({}, { __mode = "k" })
  local installed = false
  local activeHudHost
  local hudOwnerPredicate
  local service = {}

  function service:add(overlay)
    overlays[#overlays + 1] = overlay
  end

  -- Replacement renderers may publish a stricter, frame-local ownership
  -- predicate than KASC can infer from loader metadata alone. Keep this seam
  -- presentation-only: it never changes user options and never grants KASC
  -- access to the renderer's private canvas.
  function service:setHudOwnerPredicate(predicate)
    if predicate ~= nil and type(predicate) ~= "function" then
      return false, "predicate-must-be-function-or-nil"
    end
    hudOwnerPredicate = predicate
    return true
  end

  local function refreshHudHost(game)
    local voxelRenderer = mod.exports and mod.exports.voxelRendererCompat
    activeHudHost = voxelRenderer and type(voxelRenderer.module) == "function"
      and voxelRenderer.module(game, "OverworldBattle") or nil
  end

  -- Complete replacement HUDs such as VASC's ORAS provider consume KASC's
  -- public gender/QoL data themselves. KASC observes the renderer-owned,
  -- frame-local receipt but never wraps, snaps or draws into its HUD canvas.
  local function externalHudOwned(battle)
    if type(hudOwnerPredicate) == "function" then
      local okPredicate, owned = pcall(hudOwnerPredicate, battle)
      -- A successfully evaluated replacement-renderer predicate is the
      -- frame-local authority, including its explicit `false`.  Falling
      -- through to yesterday's generic snap receipt on false can suppress
      -- native KASC overlays when only VASC's command menu (not its status
      -- HUD) owns the current frame.
      return okPredicate and owned == true
    end
    if not activeHudHost then
      refreshHudHost(type(battle) == "table" and battle.game or nil)
    end
    if not (activeHudHost
        and type(activeHudHost.hudSnapReceipt) == "function") then
      return false
    end
    local ok, receipt = pcall(activeHudHost.hudSnapReceipt, battle)
    local shot = type(battle) == "table"
      and rawget(battle, "voxelAscendantShot") or nil
    if type(activeHudHost.shot) == "function" then
      local okShot, current = pcall(activeHudHost.shot, battle)
      if not okShot or current ~= shot then return false end
    end
    return ok and type(shot) == "table" and type(receipt) == "table"
      and receipt.schema == "voxel-ascendant/hud-snap/v1"
      and receipt.shot == shot and receipt.snapped == true
      and (receipt.owner == "voxel_ascendant.oras"
        or receipt.owner == "kanto_ascendant.oras")
  end

  function service:externalHudOwned(battle)
    return externalHudOwned(battle)
  end

  function service:install()
    if installed then return end
    installed = true
    mod.events:once("mods.loaded", function(ev)
      refreshHudHost(ev and ev.game)
    end)
    mod.events:on("game.ready", function(ev)
      refreshHudHost(ev and ev.game)
    end)
    mod.events:on("battle.started", function(event)
      local battle = event and event.battle
      refreshHudHost((event and event.game)
        or (type(battle) == "table" and battle.game) or nil)
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
        local context = {
          sx = sx,
          sy = sy,
          slide = (self.introSlide or 0) * 4,
          externalHudOwned = externalHudOwned(self),
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
