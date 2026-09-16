-- One-save delivery. Capacity failures leave the victory pending and sealed.
-- The contract is supplied by integration only after reward approval.
return function(mod,opts)
 local S=assert(opts.state)
 local M={}
 local busy=false
 local function copy(v)
  if type(v)~='table'then return v end
  local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
 end
 local function list(v)
  local r={};for i,x in ipairs(v or{})do r[i]=x end;return r
 end
 local fields={'inventory','bagOrder','party','boxes','box','currentBox','pokedex','money'}
 local function staged(save)
  local s={};for k,v in pairs(save)do s[k]=v end
  s.inventory=copy(save.inventory or{});s.bagOrder=copy(save.bagOrder)
  s.pokedex=copy(save.pokedex);s.party=list(save.party)
  if save.boxes then
   s.boxes={};for i,b in ipairs(save.boxes)do s.boxes[i]=list(b)end
  end
  s.box=save.box and list(save.box)or nil
  return s
 end
 local function contract()
  local c=opts.contract and opts.contract()
  if type(c)~='table'or c.approved~=true or type(c.id)~='string'or c.id==''then
   return nil,'rewards_unapproved'
  end
  return copy(c)
 end
 function M.buildPokemon(game,spec,id)
  local data=game.data
  if not(spec and(spec.species=='PIKACHU'or spec.species=='RAICHU'or spec.species=='GOROCHU')and data.pokemon[spec.species]
    and type(spec.level)=='number'and spec.level>=1 and spec.level<=100 and spec.level%1==0)then return nil,'invalid_prize_pokemon'end
  local P=require('src.pokemon.Pokemon');local Stats=require('src.pokemon.Stats')
  -- Retries produce the same prize, without consuming the game's battle RNG.
  local seed=1
  for byte in (id..':'..spec.id..':'..tostring(game.save.player and game.save.player.id)):gmatch('.')do
   seed=(seed*131+byte:byte())%65521
  end
  local mon=P.new(data,spec.species,spec.level,function(lo,hi)
   seed=(seed*25173+13849)%65536;return lo+seed%(hi-lo+1)
  end)
  if spec.shiny then
   -- Native Gen-II shiny DVs survive serialization/transfer; no visual-only
   -- shiny flag with contradictory genetic values.
   mon.dvs={hp=8,attack=15,defense=10,speed=10,special=10}
   mon.shiny=true
  end
  if spec.trained then mon.statExp={hp=65535,attack=65535,defense=65535,speed=65535,special=65535}end
  if spec.nickname then
   if type(spec.nickname)~='string'or #spec.nickname>10 or spec.nickname:find('[%c]')then return nil,'invalid_nickname'end
   mon.nickname=spec.nickname
  end
  local ex=opts.exports and opts.exports()or mod.exports or{}
  if ex.pokemonAbilityBinding67 and ex.generationRules then
   local epoch=ex.generationRules.resolve(game).activeEpoch
   local plan,why=ex.pokemonAbilityBinding67.plan(game,mon,'bald-crew-prize:'..id..':'..spec.id,epoch)
   if plan then for k,v in pairs(plan)do mon[k]=v end
   elseif epoch>=3 then return nil,why or'prize_ability_missing'end
  end
  mon.stats=Stats.calc(data.pokemon[mon.species],mon.level,mon.dvs,mon.statExp,mon);mon.hp=mon.stats.hp
  if #mon.moves==0 then return nil,'prize_moves_missing'end
  return mon
 end
 function M.claim(game,choice)
  if busy then return false,'delivery_busy'end
  local c,why=contract();if not c then return false,why end
  if not(game and game.save and game.data)then return false,'game_unavailable'end
  -- Cosmetic entitlements must be resolved by their existing owners; they
  -- are never silently omitted from a promised bundle.
  if (c.card or c.title)and not opts.entitlements then return false,'entitlement_adapter_missing'end
  local wanted
  for _,p in ipairs(c.choices or{})do if p.id==choice then wanted=p end end
  if # (c.choices or{})>0 and not wanted then return false,'choose_pokemon'end
  busy=true
  local success,ok,result=pcall(S.deliver,game,function(_,state,commit)
   local save=game.save;local stage=staged(save)
   local Bag=opts.Bag or require('src.inventory.Bag')
   for _,row in ipairs(c.items or{})do
    if type(row.item)~='string'or not game.data.items[row.item]
      or type(row.qty)~='number'or row.qty<1 or row.qty%1~=0 or row.qty>99 then return false,'invalid_reward_item'end
    if not Bag.add(stage,row.item,row.qty,game.data)then return false,'bag_full'end
   end
   local receipt={schema='kasc.crew-reward/v1',contract=c.id,choice=choice,items=copy(c.items or{})}
   if wanted then
    local mon,reason=(opts.buildPokemon or M.buildPokemon)(game,copy(wanted),c.id)
    if not mon then return false,reason or'pokemon_unavailable'end
    if not game.data.pokemon[mon.species]or mon.species~=wanted.species then return false,'reward_species_changed'end
    mon._kascCrewReward67={contract=c.id,choice=choice}
    local Party=opts.Party or require('src.pokemon.Party')
    if Party.add(stage.party,mon)then receipt.destination='party'
    else
     local Boxes=opts.Boxes or require('src.pokemon.Boxes')
     local box=Boxes.deposit(stage,mon)
     if not box then return false,'storage_full'end
     receipt.destination='box';receipt.box=box
    end
    if not mon.isEgg then
     stage.pokedex=stage.pokedex or{};stage.pokedex.seen=stage.pokedex.seen or{};stage.pokedex.owned=stage.pokedex.owned or{}
     stage.pokedex.seen[mon.species]=true;stage.pokedex.owned[mon.species]=true
    end
   end
   if c.moneyCap then
    if type(c.moneyCap)~='number'or c.moneyCap%1~=0 or c.moneyCap<0 or c.moneyCap>999999 then return false,'invalid_money_cap'end
    stage.money=math.max(tonumber(stage.money)or 0,c.moneyCap);receipt.moneyCap=c.moneyCap
   end
   local apply,undo
   if opts.entitlements then
    apply,undo=opts.entitlements(game,c,receipt)
    if type(apply)~='function'or type(undo)~='function'then return false,'entitlement_plan_failed'end
   end
   local old={};for _,k in ipairs(fields)do old[k]=save[k];save[k]=stage[k]end
   state.phase='complete';state.rewards.receipt=receipt
   local delivered,a,b=pcall(function()
    if apply then local accepted,reason=apply();if accepted~=true then return false,reason or'entitlement_delivery_failed'end end
    return commit(state)
   end)
   if not delivered or not a then
    for _,k in ipairs(fields)do save[k]=old[k]end
    if undo then undo()end
    return false,delivered and b or tostring(a)
   end
   return true,copy(receipt)
  end)
  busy=false
  if not success then return false,'delivery_error:'..tostring(ok)end
  return ok,result
 end
 return M
end
