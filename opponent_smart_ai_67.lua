-- KASC-67-OPPONENT-SMART-AI. Local trainer policy; never a link/wild override.
return function(mod, opts)
  opts = opts or {}
  local A = { CARD_ID = 'KASC-67-OPPONENT-SMART-AI' }
  local activeGame
  local history = setmetatable({}, {__mode='k'})
  local fixed = {SPECIAL_DAMAGE_EFFECT=true, SUPER_FANG_EFFECT=true,
    OHKO_EFFECT=true}
  function A.damaging(def)
    return type(def)=='table' and def.category~='status'
      and ((tonumber(def.power) or 0)>0 or fixed[def.effect]==true)
  end
  local function eligible(b)
    return b and b.kind=='trainer' and not b.demo and not b.isDemo
      and not b.link and not b.linkBattle and not b.classicLink
      and b.enemy and b.enemy.mon and b.player and b.player.mon
  end
  local function available(game, id)
    local rules=opts.rules
    if not rules or not rules.moveAvailable then return true end
    local resolved=rules.resolve and rules.resolve(game)
    return rules.moveAvailable(id, resolved and resolved.activeEpoch or 1,
      game.data)==true
  end
  -- Repair only local trainer instances, using their actual species' legal
  -- level/TM sources. No Tackle injection into Abra/Metapod or player saves.
  function A.ensureDamage(game, mon)
    if not (game and game.data and mon and not mon.isEgg) then return false end
    local moves=game.data.moves or {}
    for _, slot in ipairs(mon.moves or {}) do
      local row=moves[slot.id]
      if A.damaging(row) and not row.kascFirstAction67 and not row.kascConditionalDamage67 then return false end
    end
    local def=(game.data.pokemon or {})[mon.species]
    if not def then return false end
    local best, power
    local function add(id)
      local row=moves[id]
      if A.damaging(row) and not row.kascFirstAction67 and not row.kascConditionalDamage67 and available(game,id) then
        local score=tonumber(row.power) or 0
        if not best or score>power then best,power=id,score end
      end
    end
    for _, id in ipairs(def.level1Moves or {}) do add(id) end
    for _, row in ipairs(def.learnset or {}) do
      if (tonumber(row.level) or 101)<=(mon.level or 1) then add(row.move) end
    end
    if not best then for _, id in ipairs(def.tmhm or {}) do add(id) end end
    if not best then return false end
    mon.moves=mon.moves or {}
    local index=math.min(4,#mon.moves+1)
    mon.moves[index]={id=best,pp=moves[best].pp or 1}
    return true
  end
  local function useless(b, def)
    if def and opts.noUsefulMove and opts.noUsefulMove(b,b.enemy,b.player,def)then return true end
    if def and def.id=='REST' and opts.blockedStatus
        and opts.blockedStatus(b,b.enemy,'SLP') then return true end
    return opts.useful and opts.useful.noUsefulEffect({battle=b,
      user=b.enemy,target=b.player},def)==true
  end
  local function moveDef(b,slot)
    if not slot then return nil end
    return type(b.moveDef)=='function' and b:moveDef(slot) or b.data.moves[slot.id]
  end
  function A.choose(nextAction,b)
    if not eligible(b) then return nextAction(b) end
    -- Charging, recharge, binding, Bide etc. own the action until released.
    if type(b.lockedAction)=='function' then
      local locked=b:lockedAction(b.enemy)
      if locked then return locked end
    end
    local game=b.game or activeGame or {data=b.data}
    for _, mon in ipairs(b.enemyParty or {b.enemy.mon}) do
      local old=mon.moves
      if A.ensureDamage(game,mon) and mon==b.enemy.mon then
        -- Native battlers copy their move array. Change only the repaired slot.
        if b.enemy.curMoves~=old then
          local index=#mon.moves
          b.enemy.curMoves[index]={id=mon.moves[index].id,pp=mon.moves[index].pp}
        end
      end
    end
    if opts.useful then opts.useful.attach(b,true) end
    local chosen=nextAction(b)
    if chosen and chosen.special then return chosen end
    local candidates, attacks={},{}
    for index, slot in ipairs(b.enemy.curMoves or {}) do
      local def=moveDef(b,slot)
      if def and index~=b.enemy.disabledSlot and
          ((b.ruleset or {}).enemyUnlimitedPP or (slot.pp or 0)>0)
          and not(mod.exports.pokemonGrudge67 and mod.exports.pokemonGrudge67.blockedSlot(b,b.enemy,slot))then
        if not useless(b,def) then
          candidates[#candidates+1]=slot
          if A.damaging(def) then attacks[#attacks+1]=slot end
        end
      end
    end
    local state=history[b.enemy] or {support=0}
    history[b.enemy]=state
    local def=moveDef(b,chosen)
    local actualChosen
    for _,slot in ipairs(b.enemy.curMoves or{})do if slot==chosen then actualChosen=slot;break end end
    if not actualChosen and chosen then
      for _,slot in ipairs(b.enemy.curMoves or{})do if slot.id==chosen.id then actualChosen=slot;break end end
    end
    local depleted=actualChosen and mod.exports.pokemonGrudge67
      and mod.exports.pokemonGrudge67.blockedSlot(b,b.enemy,actualChosen)
    if def and not depleted and not useless(b,def) and
        (A.damaging(def) or state.support<2) then return chosen end
    local pool=#attacks>0 and attacks or candidates
    if #pool==0 or (#attacks==0 and state.support>=2) then
      -- No legal attack exists (or all attacks are disabled/depleted): do
      -- not invent a permanent illegal moveset or loop recovery indefinitely.
      return {id='STRUGGLE',pp=1,struggle=true}
    end
    local best,bestScore
    local ok,chart=pcall(require,'src.battle.TypeChart')
    for _, slot in ipairs(pool) do
      local row=moveDef(b,slot)
      local score=(tonumber(row.power) or 0)
      if fixed[row.effect] or row.kascFixedDamage67 then score=50 end
      if ok and chart.effectiveness then
        local loaded,multiplier=pcall(chart.effectiveness,row.type,b.player.curTypes or {})
        if loaded and type(multiplier)=='number' then score=score*multiplier end
      end
      score=score*math.min(100,tonumber(row.accuracy) or 100)/100
      if not best or score>bestScore then best,bestScore=slot,score end
    end
    return best
  end
  function A.executed(event)
    local b=event and event.battle
    if not eligible(b) or event.user~=b.enemy or event.isCalled then return end
    local state=history[b.enemy] or {support=0}
    history[b.enemy]=state
    state.support=A.damaging(event.move) and 0 or state.support+1
  end
  if mod.events then
    mod.events:on('game.ready',function(e)activeGame=e.game end)
    mod.events:on('save.loaded',function(e)activeGame=e.game or activeGame end)
    mod.events:on('battle.move_used',A.executed,-9000)
  end
  if mod.hooks then mod.hooks:wrap('battle.enemy_action',A.choose,9000) end
  return A
end
