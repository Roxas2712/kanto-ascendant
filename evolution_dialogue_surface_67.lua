-- Native evolution retains an intro TextBox below an opaque movie. A glass
-- skin cannot blend new text against those retained glyphs: repaint the
-- scene's paper first and redraw only the native box that still owns it.
return function(mod,opts)
  local M={CARD_ID='KASC-WAVE1-EVOLUTION-DIALOGUE',OWNER='kasc.evolution-dialogue/v1'}
  local EvolutionState=require('src.ui.EvolutionState')
  local function packed(...)return {n=select('#',...),...}end
  local function guardRetainedIntro(game,intro)
    if intro.__kascRetainedEvolutionIntro67 then return end
    local original=intro.draw
    intro.__kascRetainedEvolutionIntro67=M.OWNER
    intro.draw=function(screen,...)
      local marker=game.data and game.data.move_effects and game.data.move_effects.HEAL_EFFECT
      local states=game.stack and game.stack.states
      if marker and marker.kascEvolutionDialogueOwner67==M.OWNER and type(states)=='table' then
        local covered=false
        for _,state in ipairs(states)do
          if state==screen then covered=true
          elseif covered and state.isTextBox then return end
        end
      end
      return original(screen,...)
    end
  end
  -- A stone's result may be hosted by a wide ORAS TextBox while the native
  -- movie below it still draws in 160x144 coordinates. Project only this
  -- native item movie; keep the real dialog's layout and input untouched.
  function M.wideItemDraw(screen,original,...)
    local game=screen and screen.game
    local marker=game and game.data and game.data.move_effects
      and game.data.move_effects.HEAL_EFFECT
    local states=game and game.stack and game.stack.states
    if not marker or marker.kascEvolutionDialogueOwner67~=M.OWNER
        or getmetatable(screen)~=EvolutionState or screen.via~='ITEM'
        or type(states)~='table' then return false end
    local index
    for i,state in ipairs(states)do
      if state.player and state.enemy then return false end -- battle viewport owns its own transform
      if state==screen then index=i end
    end
    local intro=index and states[index-1]
    if not (intro and intro.isTextBox and intro.stay and type(intro.draw)=='function') then return false end
    guardRetainedIntro(game,intro)
    local result=false
    for i=index+1,#states do
      if states[i].isOpaque then return false end
      if states[i].isTextBox then result=true end
    end
    local ok,R=pcall(require,'src.render.Renderer')
    if not ok or not R.uiSize then return false end
    local w,h=R:uiSize()
    if type(w)~='number' or type(h)~='number' or w<=160 or h<144 then return false end
    local g=love and love.graphics
    if not (g and g.push and g.pop and g.rectangle and g.setColor and g.translate and g.scale) then return false end
    local P=require('src.render.PaletteFX')
    local mark=P.markTrueColor
    if type(mark)~='function' then return false end
    local scale=math.min(w/160,h/144)
    local dx,dy=(w-160*scale)/2,0
    local args=packed(...)
    g.push('all')
    local success,values=pcall(function()
      if g.setShader then g.setShader()end
      g.setColor(1,1,1,1);g.rectangle('fill',0,0,w,h)
      g.translate(dx,dy);g.scale(scale,scale)
      P.markTrueColor=function(x,y,rw,rh)
        return mark(dx+x*scale,dy+y*scale,rw*scale,rh*scale)
      end
      return packed(original(screen,unpack(args,1,args.n)))
    end)
    P.markTrueColor=mark
    g.pop()
    if not success then error(values,0)end
    if not result then intro:draw()end
    screen.__kascEvolutionDialogueSurface67={owner=M.OWNER,result=result,
      wideItem=true,width=w,height=h,scale=scale,offsetX=dx}
    return true,values
  end
  function M.prepare(screen)
    local game=screen and screen.game
    local marker=game and game.data and game.data.move_effects
      and game.data.move_effects.HEAL_EFFECT
    local states=game and game.stack and game.stack.states
    if not marker or marker.kascEvolutionDialogueOwner67~=M.OWNER
        or getmetatable(screen)~=EvolutionState or type(states)~='table' then return false end
    local index
    for i,s in ipairs(states)do if s==screen then index=i;break end end
    local intro=index and states[index-1]
    -- Older hosts without the retained intro contract stay completely native.
    if not (intro and intro.isTextBox and intro.stay
        and type(intro.draw)=='function') then return false end
    guardRetainedIntro(game,intro)
    local result=false
    for i=index+1,#states do
      if states[i].isOpaque then return false end
      if states[i].isTextBox then result=true end
    end
    local g=love and love.graphics
    if not (g and g.push and g.pop and g.rectangle and g.setColor) then return false end
    g.push('all')
    local ok,err=pcall(function()
      if g.setShader then g.setShader()end
      g.setColor(1,1,1,1)
      g.rectangle('fill',0,96,160,48)
    end)
    g.pop()
    if not ok then error(err,0)end
    -- With a result box above the movie, StateStack draws that box next.
    -- Otherwise the native intro is hidden by isOpaque and must be redrawn.
    -- Its own ORAS decorator, layout, text and timing remain untouched.
    if not result then intro:draw()end
    screen.__kascEvolutionDialogueSurface67={owner=M.OWNER,result=result}
    return true
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascEvolutionDialogueOwner67=M.OWNER})
  EvolutionState._kascDialogueSurface67=M
  if not EvolutionState._kascDialogueSurfaceWrapped67 then
    local original=EvolutionState.draw
    EvolutionState.draw=function(screen,...)
      local owner=EvolutionState._kascDialogueSurface67
      local handled,values=owner.wideItemDraw(screen,original,...)
      if handled then return unpack(values,1,values.n)end
      owner.prepare(screen)
      return original(screen,...)
    end
    EvolutionState._kascDialogueSurfaceWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-retained-evolution-intro',
      providerStatus='native-or-existing-oras-textbox',
      buildReceiptId='docs/WAVE1_POKEMON_COMPLETION_20260907.md',
      rollbackReceiptId='docs/WAVE1_POKEMON_COMPLETION_20260907.md'})
  end
  return M
end
