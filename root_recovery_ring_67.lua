-- Native Aqua Ring composition from the current ROM's actual Bubble tiles.
-- No Pokemon art, shader, battle state, PP or camera mutation. 2D only.
return function(player, isPlayer)
  local template, left, top
  for _,step in ipairs(player.steps or {}) do
    local visible={}
    for _,s in ipairs(step.sprites or {}) do
      if s.x>0 and s.x<168 and s.y>0 and s.y<160 then visible[#visible+1]=s end
    end
    if #visible>0 then
      if #visible~=4 then return false end
      template=visible;left=math.huge;top=math.huge
      for _,s in ipairs(visible) do left=math.min(left,s.x);top=math.min(top,s.y) end
      local occupied={}
      for _,s in ipairs(visible) do
        local x,y=s.x-left,s.y-top
        if (x~=0 and x~=8) or (y~=0 and y~=8) or occupied[x..':'..y] then return false end
        occupied[x..':'..y]=true
      end
      break
    end
  end
  if not template then return false end
  local cx,cy=isPlayer and 40 or 124,isPlayer and 72 or 40
  local steps={}
  for frame=0,23 do
    local sprites={}
    for dot=0,3 do
      local angle=2*math.pi*(frame/24+dot/4)
      local x=cx+math.floor(8*math.cos(angle)+0.5)
      local y=cy+math.floor(8*math.sin(angle)+0.5)
      for _,s in ipairs(template) do
        local q={};for k,v in pairs(s) do q[k]=v end
        -- OAM x/y store +8/+16 offsets. A 16px bubble is centered here.
        q.x=x+s.x-left;q.y=y+8+s.y-top
        sprites[#sprites+1]=q
      end
    end
    steps[#steps+1]={dur=2,sprites=sprites}
  end
  player.steps=steps;player.events={{frame=0,sound='BUBBLE'}}
  player.stepIndex=1;player.stepLeft=2;player.elapsed=0;player.eventCursor=1
  return true
end
