-- Durable Bald Crew campaign authority. Rendering, rosters and rewards live
-- in separate adapters; only this module advances the one-time campaign.
return function(mod,opts)
  opts=opts or{}
  local data=assert(opts.data)
  local M={CARD_ID='KASC-67-BALD-CREW',key='bald_crew_67',schema='kasc.bald-crew/v1'}
  local function copy(v)
    if type(v)~='table'then return v end
    local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
  end
  local function empty()
    return{schema=M.schema,phase='locked',next=1,serial=0,attempt=0,losses=0,
      completed={},rewards={},battle=false}
  end
  local function read()
    local s=mod.save:get(M.key)
    if s==nil then return empty()end
    if type(s)~='table'or s.schema~=M.schema then return nil,'invalid_state'end
    if not ({locked=true,ready=true,paused=true,active=true,battle=true,reward=true,complete=true})[s.phase]
        or type(s.next)~='number'or s.next%1~=0 or s.next<1 or s.next>#data.order+1
        or type(s.serial)~='number'or type(s.attempt)~='number'
        or type(s.losses)~='number'or type(s.completed)~='table'or type(s.rewards)~='table'then
      return nil,'invalid_state'
    end
    for _,key in ipairs({'serial','attempt','losses'})do
      local n=s[key]
      if n<0 or n~=n or n==math.huge or n%1~=0 then return nil,'invalid_state'end
    end
    local terminal=s.phase=='reward'or s.phase=='complete'
    if terminal~=(s.next==#data.order+1)then return nil,'invalid_state'end
    if s.phase=='battle'then
      if type(s.battle)~='table'or s.battle.index~=s.next
        or type(s.battle.token)~='string'
        or s.battle.token~= ('crew:%d:%d:%d'):format(s.attempt,s.serial,s.next)then return nil,'invalid_state'end
    elseif s.battle~=false then return nil,'invalid_state'end
    for i,id in ipairs(data.order)do
      if (s.completed[id]==true)~=(i<s.next)then return nil,'invalid_state'end
    end
    return copy(s)
  end
  local function commit(game,s)
    local previous=copy(mod.save:get(M.key))
    mod.save:set(M.key,copy(s))
    local ok,result
    if opts.persist then ok,result=pcall(opts.persist,game)
    elseif game and type(game.writeSave)=='function'then ok,result=pcall(game.writeSave,game)
    else ok,result=false,'save_unavailable'end
    if not ok or result==false then mod.save:set(M.key,previous);return false,'save_failed'end
    return true,copy(s)
  end
  function M.status()return read()end
  function M.unlock(game)
    local s,why=read();if not s then return false,why end
    if s.phase~='locked'then return true,s end
    s.phase='ready';return commit(game,s)
  end
  function M.enter(game)
    local s,why=read();if not s then return false,why end
    if s.phase=='complete'or s.phase=='reward'then return false,'sealed'end
    if s.phase=='locked'then return false,'locked'end
    if s.phase=='battle'then return false,'battle_pending'end
    if not data.ready then return false,'rosters_unapproved'end
    if s.phase=='ready'then s.phase='active';s.attempt=s.attempt+1 end
    if s.phase=='paused'then s.phase='active'end
    return commit(game,s)
  end
  function M.beginFight(game,index)
    local s,why=read();if not s then return false,why end
    if s.phase~='active'or index~=s.next then return false,'not_current_opponent'end
    local row=data.opponents[data.order[index]]
    if not row or not row.ready or #row.team~=6 then return false,'roster_unapproved'end
    s.serial=s.serial+1
    s.battle={token=('crew:%d:%d:%d'):format(s.attempt,s.serial,index),index=index}
    s.phase='battle';return commit(game,s)
  end
  local function defeat(s)
    local index=s.battle.index
    local row=data.opponents[data.order[index]]
    local restart=row and row.clearCompletedBlocksOnLoss and 1 or data.blocks[index]
    assert(type(restart)=='number'and restart>=1 and restart<=index,'invalid checkpoint')
    for i=restart,#data.order do s.completed[data.order[i]]=nil end
    s.next=restart;s.battle=false;s.phase='paused';s.losses=s.losses+1
    s.attempt=s.attempt+1
  end
  function M.finishFight(game,token,result)
    local s,why=read();if not s then return false,why end
    if s.phase~='battle'or type(s.battle)~='table'or s.battle.token~=token then
      return false,'stale_battle'
    end
    if result=='win'then
      local index=s.battle.index;s.completed[data.order[index]]=true
      s.next=index+1;s.battle=false
      s.phase=s.next>#data.order and 'reward'or'active'
    elseif result=='lose'or result=='loss'or result=='abort'then defeat(s)
    else return false,'invalid_result'end
    return commit(game,s)
  end
  function M.recover(game)
    local s,why=read();if not s then return false,why end
    if s.phase~='battle'then return true,s end
    -- Closing/reloading during an unresolved fight cannot skip an opponent.
    if type(s.battle)~='table'or s.battle.index~=s.next then return false,'invalid_state'end
    defeat(s);return commit(game,s)
  end
  function M.withdraw(game)
    local s,why=read();if not s then return false,why end
    if s.phase~='active'then return false,'not_active'end
    -- Leaving to heal is allowed, but cannot preserve a half-finished block.
    s.battle={index=s.next};defeat(s);return commit(game,s)
  end
  function M.canEnterInstance()
    local s=read();return s and (s.phase=='active'or s.phase=='battle')or false
  end
  function M.isSealed()
    local s=read();return s and(s.phase=='reward'or s.phase=='complete')or false
  end
  function M.rewardPending()
    local s=read();return s and s.phase=='reward'or false
  end
  -- The reward adapter must deliver inventory + receipt in ONE game-save
  -- transaction. No separate mark-claimed API that could duplicate rewards.
  function M.deliver(game,deliver)
    local s,why=read();if not s then return false,why end
    if s.phase~='reward'then return false,s.phase=='complete'and'already_claimed'or'not_cleared'end
    if type(deliver)~='function'then return false,'reward_adapter_missing'end
    return deliver(game,copy(s),function(updated)
      assert(updated.schema==M.schema and updated.phase=='complete','reward transaction incomplete')
      return commit(game,updated)
    end)
  end
  return M
end
