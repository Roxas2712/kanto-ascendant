-- KASC's explicitly authorized temporary Mega extension for native Gen II.
-- Gold separates its battle model from the screen; Gen-I battler wrappers
-- and act()/curStats are not native Gen-II combat state.
return function(mod, mega, i18n)
  local G = {}
  local function copy(t)
    local out={};for k,v in pairs(t or {}) do out[k]=v end;return out
  end
  local function enabled()
    return mod.options:get("mega_evolution") ~= false
  end
  local function profile(model, mon)
    local state=model and model._kascNativeMega
    return enabled() and state and state.mon==mon and state.profile or nil
  end
  local function clean(model)
    local state=model and model._kascNativeMega
    if state then
      state.mon._ascMegaForm=nil
      state.mon._ascMegaAnimationFrame=nil
      state.mon._ascMegaAnimationSide=nil
      model._kascNativeMega=nil
    end
  end
  local function eligibleProfile(screen)
    local model=screen and screen.battle
    if not model then return nil,"invalid" end
    if screen.link or screen.tutorial or screen.contest or model.inBattleTowerBattle
        or screen.ascendantNoMega or model.ascendantNoMega
        or screen.ascendantNoSaveMechanics or model.ascendantNoSaveMechanics
        or model.kind=="link" then return nil,"policy" end
    if not enabled() then return nil,"disabled" end
    if not mega.hasRing() then return nil,"locked" end
    local mon=model.player
    if not mon or mon.isEgg then return nil,"invalid" end
    local p=mega.profileFor(mon,false)
    if not p or p.secret then return nil,"stone" end
    return p
  end
  -- Pure public HUD queries: never set a form, receipt, used flag or queue.
  -- Missing KASC means this export does not exist: consumers must hide it.
  function G.isVisible(screen) return eligibleProfile(screen) ~= nil end
  function G.canActivate(screen)
    local p,why=eligibleProfile(screen)
    if not p then return false,why end
    local model=screen.battle
    if screen.phase~="menu" or model.over then return false,"phase" end
    if model._kascNativeMegaUsed then return false,"used" end
    if (model.player.hp or 0)<=0 then return false,"invalid" end
    return true,nil,p
  end
  function G.activate(screen)
    local allowed,why,p=G.canActivate(screen)
    if not allowed then return false,why end
    local model,mon=screen.battle,screen.battle.player
    model._kascNativeMegaUsed=true
    model._kascNativeMega={mon=mon,profile=p,elapsed=0,frame=1}
    mon._ascMegaForm=p.id
    mon.__kaLegacyMega={schema="kasc/bank-mega-form/v1",
      baseSpecies=mon.species,formId=p.id,stone=p.stone}
    screen.picCache={}
    local s=mega.state();s.activations=(s.activations or 0)+1
    mod.save:set("mega_evolution",s)
    screen:push({kind="message",text=i18n.text(
      mon.species.." became "..p.label.."!",
      mon.species.." wird zu "..p.label.."!")})
    screen.phase="resolving"
    return true
  end
  function G.install(game)
    mega.game=game
    local Model=require("src.battle.gen2.Battle")
    local Screen=require("src.ui.gen2.BattleState")
    if Screen._kascNativeMegaBridge then return end
    Screen._kascNativeMegaBridge=true
    local nativeStat=Model.battleStat
    Model.battleStat=function(model,mon,key)
      local p=profile(model,mon)
      if not p then return nativeStat(model,mon,key) end
      -- The native badge boost must read the changed battle stat, while
      -- neither the party's stats nor the shared species registry is changed.
      local shadow=copy(mon)
      shadow.stats=mega.boostedStats({mon=mon,curStats=mon.stats},p)
      local context=setmetatable({player=model.player==mon and shadow or model.player},
        {__index=model})
      return nativeStat(context,shadow,key)
    end
    local nativeDef=Model.speciesDef
    Model.speciesDef=function(model,mon)
      local def=nativeDef(model,mon)
      local p=profile(model,mon)
      if not(def and p and p.types) then return def end
      local out=copy(def);out.types=copy(p.types);return out
    end
    local nativeEnd=Model.endBattle
    Model.endBattle=function(model,...)
      -- Clear before the native ended event can persist a party snapshot.
      clean(model)
      return nativeEnd(model,...)
    end
    local nativeComplete=Screen.completeBattle
    Screen.completeBattle=function(screen,...)
      clean(screen.battle)
      return nativeComplete(screen,...)
    end
    local nativeUpdate=Screen.update
    Screen.update=function(screen,dt)
      local model=screen.battle
      if not enabled() then clean(model) end
      local input=screen.game and screen.game.input
      if screen.phase=="menu" and input and input:wasPressed("select") then
        local ok=G.activate(screen)
        if ok then return end
      end
      local state=model and model._kascNativeMega
      if state then
        local shiny=state.mon.shiny==true
        local timings=mega.animationTimings and mega.animationTimings(state.profile)
          or mega.animationData[state.profile.id]
        timings=timings and timings.front and timings.front[shiny and "shiny" or "normal"]
        local moving=mod.options:get("crystal_animation")~=false
        if moving and timings and #timings>1 then
          if state.timings~=timings then state.timings=timings;state.frame=1;state.elapsed=0 end
          state.elapsed=state.elapsed+mega.presentationDelta(screen,dt)*1000
          local guard=0
          while state.elapsed >= timings[state.frame] and guard<50 do
            state.elapsed=state.elapsed-timings[state.frame]
            state.frame=state.frame%#timings+1;guard=guard+1
          end
          state.mon._ascMegaAnimationFrame=state.frame
        else state.mon._ascMegaAnimationFrame=nil end
      end
      return nativeUpdate(screen,dt)
    end
  end
  G.cleanup=clean
  return G
end
