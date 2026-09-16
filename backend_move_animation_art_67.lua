-- KASC-owned, colored move effects. Does not change Pokemon sprite owners.
return function(mod,opts)
  local M={CARD_ID='KASC-67-MOVE-ANIMATIONS',OWNER='kasc.move-animation-art/v1',
    active=false,status='native-composition-fallback',flightFrames=37}
  local rel='assets/move_effects_67/lazarus-branch/branch.png'
  local anims=mod.content.battle_anims
  local move=mod.content.moves:get('BRANCH_POKE')
  if not (move and move.backendMoveOwner==opts.moves.OWNER and anims
      and anims:get('POUND') and anims:get('BRANCH_POKE') and mod:read(rel)) then return M end
  local slot=67001
  while anims:get('tilesheet:'..slot) do slot=slot+1 end
  M.sheet=slot
  anims:register('tilesheet:'..slot,{path=mod.path..'/'..rel,width=32,height=32,
    tiles=16,source=M.OWNER})
  -- Keep a fully functional native sequence as fallback for other renderers.
  anims:patch('BRANCH_POKE',{source=M.OWNER})
  local Player=require('src.battle.AnimPlayer')
  local Data=require('src.core.Data')
  function M.owns(player)
    local current=Data.battle_anims
    local entry=current and current.moveAnims and current.moveAnims.BRANCH_POKE
    local sheet=current and current.tilesheets and current.tilesheets[M.sheet]
    return player.data==current and entry and entry.source==M.OWNER
      and sheet and sheet.source==M.OWNER
  end
  function M.flight(side)
    local steps={}
    -- Route the opaque branch through the gap BETWEEN the two HUDs.
    -- A straight attacker/target line crosses the player's name label.
    local path={{40,72},{64,42},{100,42},{120,32}}
    for frame=1,M.flightFrames do
      local t=(frame-1)/(M.flightFrames-1)
      if not side then t=1-t end
      local segment=math.min(3,math.floor(t*3)+1)
      local fraction=t*3-(segment-1)
      local a,b=path[segment],path[segment+1]
      local cx,cy=math.floor(a[1]+(b[1]-a[1])*fraction+.5),
        math.floor(a[2]+(b[2]-a[2])*fraction+.5)
      local sprites={}
      for tile=0,15 do
        local col,row=tile%4,math.floor(tile/4)
        sprites[#sprites+1]={x=cx-16+(side and col or 3-col)*8+8,
          y=cy-16+row*8+16,tile=tile,ts=M.sheet,xf=not side,yf=false}
      end
      steps[#steps+1]={dur=1,sprites=sprites}
    end
    return steps
  end
  function M.start(original,player,id,side,options)
    if id~='BRANCH_POKE' or not M.owns(player) then
      return original(player,id,side,options)
    end
    original(player,'POUND',side,options)
    local tail=player.steps
    local steps=M.flight(side)
    for _,step in ipairs(tail)do steps[#steps+1]=step end
    for _,ev in ipairs(player.events)do ev.frame=ev.frame+M.flightFrames end
    table.insert(player.events,1,{sound='VINE_WHIP',frame=0})
    player.steps=steps
    player.stepIndex,player.stepLeft=1,steps[1].dur
    player.elapsed,player.eventCursor=0,1
  end
  function M.draw(original,player,sprites,colorFn)
    local sheet=player.data and player.data.tilesheets and player.data.tilesheets[M.sheet]
    if not (sheet and sheet.source==M.OWNER) then return original(player,sprites,colorFn) end
    -- Preserve draw order when a caller supplies a mixed native/color batch.
    -- Bypass ONLY the GB shade-remap for our RGBA tiles, restoring shader
    -- state even if image loading/drawing fails. All other effects delegate.
    local first=1
    while first<=#sprites do
      local colored=sprites[first].ts==M.sheet
      local last=first
      while last<#sprites and (sprites[last+1].ts==M.sheet)==colored do last=last+1 end
      local group={};for i=first,last do group[#group+1]=sprites[i]end
      local g=love and love.graphics
      if colored and g and g.getShader and g.setShader then
        local previous=g.getShader();g.setShader()
        local ok,err=pcall(original,player,group,nil)
        g.setShader(previous)
        if not ok then error(err,0)end
      else original(player,group,colorFn)end
      first=last+1
    end
  end
  Player._kascMoveArtOwner67=M
  if not Player._kascMoveArtWrapped67 then
    Player._kascMoveArtWrapped67=true
    local start,draw=Player.start,Player.drawSprites
    Player.start=function(self,...)
      return Player._kascMoveArtOwner67.start(start,self,...)
    end
    Player.drawSprites=function(self,...)
      return Player._kascMoveArtOwner67.draw(draw,self,...)
    end
  end
  M.active,M.status=true,'branch-projectile-needs-visual-review'
  opts.moves.animationReview.moves.BRANCH_POKE={status=M.status,
    graphics='lazarus-v2-tag-10365',flightFrames=M.flightFrames}
  return M
end
