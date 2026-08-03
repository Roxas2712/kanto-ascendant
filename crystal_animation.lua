-- Johto half of Crystal Animated Sprites with Shiny Visuals compatibility.
--
-- The community mod owns Crystal animations for Kanto #001-151. Ascendant
-- deliberately mirrors its numbered-frame/duration format for #152-251, but
-- uses a separate battler field so both update wrappers can run together.

return function(mod, opts)
  opts = opts or {}
  local animationData = opts.animationData or {}
  local shinySystem = opts.shinySystem
  local speciesOrder = opts.speciesOrder or {}
  local A = {
    selected = setmetatable({}, { __mode = "k" }),
    available = {},
    shinyAvailable = {},
  }
  local dexFor = {}
  local imageCache = {}

  for index, species in ipairs(speciesOrder) do
    local dex = 151 + index
    dexFor[species] = dex
    A.available[species] =
      mod:read(("assets/crystal_animated/front/normal/%d/001.png"):format(dex))
        ~= nil
      and type(animationData.normal) == "table"
      and type(animationData.normal[tostring(dex)]) == "table"
    A.shinyAvailable[species] =
      mod:read(("assets/crystal_animated/front/shiny/%d/001.png"):format(dex))
        ~= nil
      and type(animationData.shiny) == "table"
      and type(animationData.shiny[tostring(dex)]) == "table"
  end

  local function enabled()
    return mod.options:get("legend_art") == "crystal"
      and mod.options:get("crystal_animation") ~= false
  end

  local function variant(mon)
    return shinySystem and shinySystem.isShiny(mon) and "shiny" or "normal"
  end

  local function relativePath(dex, which, frame)
    return ("assets/crystal_animated/front/%s/%d/%03d.png")
      :format(which, dex, frame or 1)
  end

  local function fullPath(dex, which, frame)
    return mod.path .. "/" .. relativePath(dex, which, frame)
  end

  local function durations(dex, which)
    local group = animationData[which]
    return type(group) == "table" and group[tostring(dex)] or nil
  end

  local function clearSelection(mon)
    if mon then A.selected[mon] = nil end
  end

  -- Called by the final sprite resolver. Returning a path means frame one
  -- should replace the bundled still; nil leaves the still/back/other-mod
  -- result untouched.
  function A.select(ctx, selectedSide, externalOverride)
    local mon = ctx and ctx.mon
    local dex = ctx and dexFor[ctx.species]
    if not (mon and dex and ctx.kind == "battle" and selectedSide == "front")
        or externalOverride or not enabled()
        or mon._ascMegaForm or mon.ascMegaForm then
      clearSelection(mon)
      return nil
    end
    local which = variant(mon)
    local ready = which == "shiny"
      and A.shinyAvailable[ctx.species] or A.available[ctx.species]
    local timing = ready and durations(dex, which) or nil
    if not (timing and #timing > 1) then
      clearSelection(mon)
      return nil
    end
    A.selected[mon] = {
      species = ctx.species,
      dex = dex,
      variant = which,
      durations = timing,
    }
    ctx.trueColor = true
    return fullPath(dex, which, 1)
  end

  local function loadImage(path)
    if imageCache[path] then return imageCache[path] end
    if not (love and love.graphics and love.graphics.newImage) then return nil end
    local ok, image = pcall(love.graphics.newImage, path)
    if not (ok and image) then return nil end
    if image.setFilter then image:setFilter("nearest", "nearest") end
    imageCache[path] = image
    return image
  end

  local function resetBattler(battler)
    local mon = battler and battler.mon
    local selected = mon and A.selected[mon]
    if not selected or mon._ascMegaForm or mon.ascMegaForm then
      if battler then battler.__ascendantCrystalAnimation = nil end
      return nil
    end
    local which = variant(mon)
    if selected.species ~= mon.species or selected.variant ~= which then
      battler.__ascendantCrystalAnimation = nil
      return nil
    end
    local state = {
      species = selected.species,
      dex = selected.dex,
      variant = selected.variant,
      durations = selected.durations,
      frame = 1,
      elapsed = 0,
      image = battler.sprite,
    }
    battler.__ascendantCrystalAnimation = state
    return state
  end

  local function updateBattler(battler, dt)
    local mon = battler and battler.mon
    local selected = mon and A.selected[mon]
    if not (selected and enabled())
        or mon._ascMegaForm or mon.ascMegaForm then
      if battler then battler.__ascendantCrystalAnimation = nil end
      return
    end

    local state = battler.__ascendantCrystalAnimation
    if not state or state.species ~= mon.species
        or state.variant ~= variant(mon) then
      state = resetBattler(battler)
    elseif state.image and battler.sprite ~= state.image then
      -- Transform, Mega Evolution or another renderer changed the live pic.
      -- Do not fight it by restoring the base Johto species every frame.
      battler.__ascendantCrystalAnimation = nil
      clearSelection(mon)
      return
    end
    if not state then return end

    state.elapsed = state.elapsed + (tonumber(dt) or (1 / 60)) * 1000
    local changed, guard = false, 0
    while state.elapsed >= (state.durations[state.frame] or 100)
        and guard < 50 do
      state.elapsed = state.elapsed - (state.durations[state.frame] or 100)
      state.frame = state.frame + 1
      if state.frame > #state.durations then state.frame = 1 end
      changed, guard = true, guard + 1
    end
    if not changed then return end

    local image = loadImage(fullPath(state.dex, state.variant, state.frame))
    if image then
      battler.sprite = image
      state.image = image
    end
  end

  function A.updateBattle(battle, dt)
    if not battle then return end
    if battle.enemy and not battle.showEnemyTrainer
        and not battle.enemySendingOut then
      updateBattler(battle.enemy, dt)
    end
    if battle.player and not battle.showPlayerBack and not battle.sendingOut then
      updateBattler(battle.player, dt)
    end
  end

  function A.clearBattle(battle)
    if not battle then return end
    for _, battler in ipairs({ battle.player, battle.enemy }) do
      if battler then battler.__ascendantCrystalAnimation = nil end
    end
  end

  function A.install(game, deps)
    A.game = game
    deps = deps or {}
    local BattleState = deps.battleState or require("src.battle.BattleState")
    if BattleState._ascendantCrystalAnimationWrapped then return end
    BattleState._ascendantCrystalAnimationWrapped = true
    local vanillaUpdate = BattleState.update
    BattleState.update = function(battle, dt)
      local result = vanillaUpdate(battle, dt)
      A.updateBattle(battle, dt)
      return result
    end
  end

  mod.events:on("battle.battler_switched", function(ev)
    A.clearBattle(ev and ev.battle)
  end)
  mod.events:on("battle.ended", function(ev)
    A.clearBattle(ev and ev.battle)
  end)

  function A.invalidate()
    imageCache = {}
  end

  return A
end
