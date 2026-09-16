-- Battle item ownership is not consumption. Transfers never manufacture a
-- Recycle/Harvest receipt. Temporary transfers survive native checkpoints.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local Effects=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-ITEM-TRANSFER',OWNER='kasc.item-transfer/v1'}
  local A,tr=opts.abilities,opts.i18n.text
  local moveScopes=setmetatable({},{__mode='k'})
  local function pack(...)return {n=select('#',...),...}end
  local function state(b,create)
    if create then
      b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{restore={}}
    end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function side(b,w)return w==b.player and 'player'or w==b.enemy and 'enemy'end
  local function party(b,lane)
    if lane=='player'then return b.game.save.party end
    return b.kind=='trainer'and b.enemyParty or{b.enemy.mon}
  end
  local function key(b,w)
    local lane=side(b,w);if not lane then return end
    for i,mon in ipairs(party(b,lane)or{})do if mon==w.mon and i<=6 then return lane..':'..i end end
  end
  local function monAt(b,k)
    if type(k)~='string'then return end
    local lane,i=k:match('^(%a+):([1-6])$')
    if lane~='player'and lane~='enemy'then return end
    return (party(b,lane)or{})[tonumber(i)]
  end
  local function setItem(mon,id)mon.item=id or nil;mon.heldItem=id or nil end
  function M.epoch(b)
    local gen=b and opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.demo and b.kind~='link' and not b.result
        and gen and gen>=2 and gen<=7 then return gen end
  end
  local function dex(w)
    local k=opts.species.bySpecies[w.mon.species]
    local row=k and opts.catalog.entries[k]
    return row and row.nationalDex
  end
  function M.bound(b,w,id,knock,explicitSourceEpoch)
    local d=b.data.items[id];if not d then return true end
    -- KASC's non-discardable unique equipment is never battle loot.
    if d.keyItem or d.tossable==false or d.kascNoTake67 or not knock and id:find('MAIL',1,true)then return true end
    local gen=type(explicitSourceEpoch)=='number'and explicitSourceEpoch%1==0
      and explicitSourceEpoch>=2 and explicitSourceEpoch<=7 and explicitSourceEpoch or M.epoch(b)
    if not gen then return true end
    local n=dex(w)
    if not knock and gen==3 and id=='ENIGMA_BERRY'then return true end
    if n==493 and (gen==4 or (knock or A.activeAbility(b,w)=='MULTITYPE')and id:match('_PLATE$'))then return true end
    if (n==487 and gen>=4 or knock and gen==4)and id=='GRISEOUS_ORB'then return true end
    if n==649 and gen>=5 and id:match('_DRIVE$')then return true end
    if n==773 and gen==7 and id:match('_MEMORY$')then return true end
    if gen>=6 and(n==382 and id=='BLUE_ORB'or n==383 and id=='RED_ORB')then return true end
    return false
  end
  function M.sticky(b,w)
    local gen=M.epoch(b)
    return gen and gen>=3 and (gen<=4 or w.mon.hp>0)
      and A.activeAbility(b,w)=='STICKY_HOLD'
  end
  local function journal(b,w,id,activeKey)
    local k=assert(activeKey or key(b,w),'item transfer outside party')
    local s=state(b,true)
    if s.restore[k]==nil then s.restore[k]={species=w.mon.species,item=id or false}end
  end
  -- Friendly donation accepts only real active wrappers belonging to a
  -- saved party slot. This does not broaden opposing theft's addressing.
  local function allyKey(b,w)
    if not w or not w.mon or w.mon.hp<=0 or w.fainted or w.mon.isEgg
        or w.mon.egg or w.mon.is_egg or w.mon.eggSpecies then return end
    for index,s in ipairs(b.sides or{})do
      if index<=2 and w.isPlayer==(index==1)then
        for _,v in ipairs(s.battlers or{})do if v==w then
          local lane=index==1 and 'player'or'enemy'
          for i,mon in ipairs(party(b,lane)or{})do
            if i<=6 and mon==w.mon then return lane..':'..i,lane end
          end
        end end
      end
    end
  end
  -- Bestow is intentional donation, not opposing theft. Only the actual
  -- native Card's synchronous transaction window grants write authority.
  function M.bestow(b,donor,receiver,move)
    local owner=mod.exports.pokemonItemAccess67
    local proof=owner and owner.bestowProof(b,donor,receiver,move)
    if type(proof)~='table'or proof.owner~=owner.OWNER or proof.profile~=owner.epoch(b)
        or type(proof.epoch)~='number'or proof.epoch%1~=0 or proof.epoch<5 or proof.epoch>7 then return false end
    local dk,ds=allyKey(b,donor);local rk,rs=allyKey(b,receiver)
    if not dk or not rk or donor==receiver or dk==rk
        or dk~=ds..':'..tostring(proof.sourceParty)or rk~=rs..':'..tostring(proof.targetParty)
        or proof.sourceSpecies~=donor.mon.species or proof.targetSpecies~=receiver.mon.species then return false end
    local id,err=opts.held(donor.mon);local theirs,terr=opts.held(receiver.mon)
    if err or terr or not id or theirs or proof.item~=id or not b.data.items[id]
        or M.bound(b,donor,id,false,proof.epoch)or M.bound(b,receiver,id,false,proof.epoch)then return false end
    local s=state(b)
    if b.kind=='trainer'or rs=='enemy'or s and(s.restore[dk]or s.restore[rk])then
      journal(b,donor,id,dk);journal(b,receiver,false,rk)
    end
    setItem(donor.mon,nil);setItem(receiver.mon,id)
    A.onItemLost(b,donor);A.clearItemLoss(b,receiver)
    local choice=opts.choice and opts.choice()
    if choice then choice.clear(b,donor);choice.clear(b,receiver)end
    if moveScopes[b]then moveScopes[b].itemsChanged=true end
    return id
  end
  function M.giveToAlly(b,receiver,donor)
    local gen=M.epoch(b)
    if not gen or gen<6 or receiver==donor then return false end
    local rk,rs=allyKey(b,receiver);local dk,ds=allyKey(b,donor)
    if not rk or not dk or rk==dk or rs~=ds then return false end
    local mine,merr=opts.held(receiver.mon);local theirs,terr=opts.held(donor.mon)
    if merr or terr or mine or not theirs or M.bound(b,donor,theirs)
        or M.bound(b,receiver,theirs)or M.sticky(b,donor)then return false end
    -- A previously borrowed opponent item remains borrowed through a
    -- friendly pass. Ordinary player-to-player gifts persist normally.
    local s=state(b)
    if s and (s.restore[rk]or s.restore[dk])then
      journal(b,receiver,mine,rk);journal(b,donor,theirs,dk)
    end
    setItem(donor.mon,nil);setItem(receiver.mon,theirs)
    A.onItemLost(b,donor);A.clearItemLoss(b,receiver)
    local choice=opts.choice and opts.choice()
    if choice then choice.clear(b,donor);choice.clear(b,receiver)end
    if moveScopes[b]then moveScopes[b].itemsChanged=true end
    return theirs
  end
  function M.preparePickup(b,w)
    local gen=M.epoch(b)
    if not gen or gen<5 or not key(b,w)then return false end
    -- Consumed trainer items may be used in the battle, not retained as
    -- permanent loot. Wild opponents likewise cannot retain player items.
    -- Do not journal the donor: its item was genuinely consumed, not stolen.
    if b.kind=='trainer'or w==b.enemy then journal(b,w,false)end
    return true
  end
  function M.knocked(b,w)
    local gen=M.epoch(b);local s=state(b);local k=key(b,w)
    return gen and gen<=4 and s and s.knocked and s.knocked[k]or nil
  end
  function M.recycled(b,w)
    -- Emerald commits a recycled item back to the party, replacing the
    -- knocked-off original. Platinum retains the original party item.
    local gen=M.epoch(b)
    if gen and gen<=3 and M.knocked(b,w)then state(b).restore[key(b,w)]=nil end
  end
  function M.displayItem(game,mon)
    for _,b in ipairs(game and game.stack and game.stack.states or{})do
      local gen=M.epoch(b);local s=gen and gen<=4 and state(b)
      if s and s.knocked then
        for k in pairs(s.knocked)do
          local r=s.restore[k]
          if r and monAt(b,k)==mon then return r.item end
        end
      end
    end
  end
  function M.validateCheckpoint(b)
    local s=state(b);if s==nil then return true end
    if type(s)~='table'or type(s.restore)~='table'then return false,'invalid_item_transfer_state'end
    for field in pairs(s)do if field~='restore'and field~='knocked'then return false,'unknown_item_transfer_field'end end
    if s.knocked~=nil then
      -- Validators run before the frozen rules receipt is reattached.
      -- The generation owner validates this receipt/hash before resuming.
      local receipt=b.field.tokens['kasc.generation-receipt/v1']
      local gen=type(receipt)=='table'and receipt.activeEpoch or M.epoch(b)
      if type(s.knocked)~='table'or type(gen)~='number'or gen<2 or gen>4
          or type(receipt)=='table'and receipt.mode=='off'then return false,'invalid_knocked_container'end
      for k,r in pairs(s.knocked)do
        local mon=monAt(b,k)
        if not mon or type(r)~='table'or r.species~=mon.species
            or type(r.item)~='string'or not b.data.items[r.item]then return false,'invalid_knocked_record'end
        for field in pairs(r)do if field~='species'and field~='item'then return false,'unknown_knocked_field'end end
      end
    end
    for k,r in pairs(s.restore)do
      local mon=monAt(b,k)
      if not mon or type(r)~='table'or r.species~=mon.species
          or not(r.item==false or type(r.item)=='string'and b.data.items[r.item])then
        return false,'invalid_item_transfer_record'
      end
      for field in pairs(r)do if field~='species'and field~='item'then return false,'unknown_item_transfer_record'end end
    end
    return true
  end
  function M.finish(ev)
    local b=ev and ev.battle;local s=state(b);if not s then return end
    -- Remove the owner before writing, so repeated end notifications do not
    -- resurrect an item subsequently consumed or moved on the overworld.
    b.field.tokens[M.OWNER]=nil
    for k,r in pairs(s.restore)do
      local mon=monAt(b,k)
      -- Evolution at native battle finish can change species, not party slot.
      if mon then setItem(mon,r.item)end
    end
  end
  function M.steal(b,receiver,donor,reason)
    local gen=M.epoch(b)
    if not gen or not receiver or not donor or receiver==donor
        or not receiver.mon or receiver.mon.hp<=0 or not donor.mon
        or not key(b,receiver)or not key(b,donor)then return false end
    if gen>=3 and gen<=4 and receiver==b.enemy then return false end
    if M.knocked(b,receiver)or M.knocked(b,donor)then return false end
    local mine,merr=opts.held(receiver.mon);local theirs,terr=opts.held(donor.mon)
    if merr or terr or mine or not theirs then return false end
    if M.bound(b,donor,theirs)or M.bound(b,receiver,theirs)then return false end
    if M.sticky(b,donor)then b:sayNext(tr('Sticky Hold!','Klebekörper!'));return false end
    -- V+ trainer items are borrowed, and wild opponents cannot permanently
    -- take player equipment. Wild loot taken by the player remains theirs.
    if gen>=5 and(b.kind=='trainer'or receiver==b.enemy)then
      journal(b,receiver,mine);journal(b,donor,theirs)
    end
    setItem(donor.mon,nil);setItem(receiver.mon,theirs)
    if moveScopes[b]then moveScopes[b].itemsChanged=true end
    A.onItemLost(b,donor);A.clearItemLoss(b,receiver)
    local choice=opts.choice and opts.choice()
    if choice then choice.clear(b,donor);choice.clear(b,receiver)end
    local d=b.data.items[theirs];local names=d.names or{}
    b:sayNext(tr('%s\nwas stolen!','%s\nwurde gestohlen!')
      :format(tr(names.en or d.name or theirs,names.de or d.name or theirs)))
    return true
  end
  function M.canSwap(b,u,t)
    local gen=M.epoch(b)
    if not gen or not u or not t or u==t or not u.mon or not t.mon
        or u.mon.hp<=0 or t.mon.hp<=0 or not key(b,u)or not key(b,t)
        or t.substituteHP or gen>=3 and gen<=4 and u==b.enemy then return false end
    local mine,merr=opts.held(u.mon);local theirs,terr=opts.held(t.mon)
    if M.knocked(b,u)or M.knocked(b,t)then return false end
    if merr or terr or not(mine or theirs)or M.sticky(b,t)then return false end
    -- Validate both old holders AND both new recipients before any write.
    if mine and(M.bound(b,u,mine)or M.bound(b,t,mine))
        or theirs and(M.bound(b,t,theirs)or M.bound(b,u,theirs))then return false end
    return true,mine,theirs
  end
  function M.swap(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target
    local ok,mine,theirs=M.canSwap(b,u,t)
    if not ok or opts.priority.blocks(ctx)then
      return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}
    end
    -- Unlike theft by a wild opponent, a wild Trick is permanent. Any
    -- already-borrowed item keeps its earlier return receipt, however.
    if M.epoch(b)>=5 and b.kind=='trainer'then
      journal(b,u,mine);journal(b,t,theirs)
    end
    setItem(u.mon,theirs);setItem(t.mon,mine)
    if moveScopes[b]then moveScopes[b].itemsChanged=true end
    for _,row in ipairs({{u,mine,theirs},{t,theirs,mine}})do
      if row[2]then A.onItemLost(b,row[1])end -- not a consumed-item receipt
      if row[3]then A.clearItemLoss(b,row[1])end
    end
    local choice=opts.choice and opts.choice()
    if choice then choice.clear(b,u);choice.clear(b,t)end
    return {tr('The held items\nwere swapped!','Items wurden\ngetauscht!')}
  end
  function M.knockOff(b,u,t)
    local gen=M.epoch(b);if not gen or not key(b,u)or not key(b,t)then return false end
    if gen>=5 and(u.mon.hp<=0 or b.kind=='wild'and u==b.enemy)then return false end
    local id,err=opts.held(t.mon)
    if err or not id or M.bound(b,t,id,true)or M.bound(b,u,id,true)then return false end
    if M.sticky(b,t)then b:sayNext(tr('Sticky Hold!','Klebekörper!'));return false end
    journal(b,t,id)
    if gen<=4 then
      local s=state(b,true);s.knocked=s.knocked or{}
      s.knocked[key(b,t)]={species=t.mon.species,item=id}
    end
    setItem(t.mon,nil);A.onItemLost(b,t)
    local choice=opts.choice and opts.choice();if choice then choice.clear(b,t)end
    b:sayNext(tr('The held item\nwas knocked off!','Item wurde\nabgeschlagen!'))
    return true
  end
  function M.power(nextDamage,ctx)
    local b=ctx and ctx.battle;local gen=M.epoch(b)
    if not gen or gen<6 or not ctx.move or ctx.move.id~='KNOCK_OFF'
        or ctx.opts and ctx.opts.typeless or not ctx.user or not ctx.target then return nextDamage(ctx)end
    local id,err=opts.held(ctx.target.mon)
    if err or not id or M.bound(b,ctx.target,id,true)or M.bound(b,ctx.user,id,true)then return nextDamage(ctx)end
    local adjusted={};for k,v in pairs(ctx)do adjusted[k]=v end
    adjusted.opts={};for k,v in pairs(ctx.opts or{})do adjusted.opts[k]=v end
    adjusted.opts.kascKnockOffPower67=true
    return nextDamage(adjusted)
  end
  function M.afterMove(b,whole)
    local u,t,m=whole.user,whole.target,whole.move
    if not whole.landed or not m or not M.epoch(b)then return end
    local gen=M.epoch(b)
    if not A.sheerForce(b,u,m)then
      if gen>=5 and t.mon.hp>0 and A.activeAbility(b,t)=='PICKPOCKET'
          and opts.contact.makesContact(m,gen,b,u)then
        if M.steal(b,t,u,'PICKPOCKET')then whole.itemsChanged=true end
      end
      if gen>=6 and u.mon.hp>0 and m.id~='FLING'and A.activeAbility(b,u)=='MAGICIAN'then
        if M.steal(b,u,t,'MAGICIAN')then whole.itemsChanged=true end
      end
    end
  end
  function M.damage(b,ctx,record,original)
    if not M.epoch(b)then return original(b,ctx,record)end
    local u,t,m=ctx.user,ctx.target,ctx.move
    local landed=false
    local raw,prior=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local real=w==t and w.mon.hp>0 and not w.substituteHP
      local damage=prior(self,w,amount)
      if real and damage>0 then landed=true end
      return damage
    end
    local result=pack(pcall(original,b,ctx,record));b.applyDamage=raw
    if not result[1]then error(result[2],0)end
    if landed then
      local whole=moveScopes[b]
      if whole and whole.user==u and whole.target==t then whole.landed=true;whole.move=m end
      if m.id=='THIEF'or m.id=='COVET'then
        A.moveScope(b,u,t,true,function()M.steal(b,u,t,m.id)end,m)
      elseif m.id=='KNOCK_OFF'then
        A.moveScope(b,u,t,true,function()M.knockOff(b,u,t)end,m)
      end
    end
    return unpack(result,2,result.n)
  end
  Effects._kascItemTransfer67=M;Battle._kascItemTransfer67=M
  function M.perform(original,b,u,t,...)
    if not M.epoch(b)or not u or not t or u==t then return original(b,u,t,...)end
    local prior=moveScopes[b];local whole={user=u,target=t};moveScopes[b]=whole
    local result=pack(pcall(original,b,u,t,...));moveScopes[b]=prior
    if not result[1]then error(result[2],0)end
    M.afterMove(b,whole)
    if whole.itemsChanged then
      -- New berries may activate at move end, outside Mold Breaker's
      -- attacking scope. Passive Leftovers must NOT get an extra tick.
      for _,w in ipairs({u,t})do
        local id=opts.held(w.mon);local def=id and b.data.items[id]
        if def and def.kascConsumableBerry67 then opts.consumption.activateRestored(b,w,true)end
      end
    end
    return unpack(result,2,result.n)
  end
  if not Effects._kascItemTransferWrapped67 then
    local original=Effects.runDamaging
    Effects.runDamaging=function(b,ctx,record)return Effects._kascItemTransfer67.damage(b,ctx,record,original)end
    Effects._kascItemTransferWrapped67=true
  end
  if not Battle._kascItemTransferWrapped67 then
    local original=Battle.performMove
    Battle.performMove=function(b,u,t,...)
      return Battle._kascItemTransfer67.perform(original,b,u,t,...)
    end
    Battle._kascItemTransferWrapped67=true
  end
  if not Battle._kascItemTransferFinishWrapped67 then
    local original=Battle.finish
    Battle.finish=function(b,...)
      -- Native finish checks evolution before battle.ended. Temporary
      -- stolen equipment must not affect that evolution check or its save.
      Battle._kascItemTransfer67.finish({battle=b})
      return original(b,...)
    end
    Battle._kascItemTransferFinishWrapped67=true
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascItemTransfer67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.power,23000)
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  for _,id in ipairs({'TRICK','SWITCHEROO'})do
    local move=assert(mod.content.moves:get(id),'missing item-swap move '..id)
    assert(move.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign item-swap owner '..id)
    local effect='KA_ITEM_SWAP_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=true,run=M.swap})
    mod.content.moves:patch(id,{effect=effect})
    mod.content.battle_anims:patch(id,copy(assert(mod.content.battle_anims:get('CONFUSE_RAY'))))
    for i=#opts.moves.unsupportedStatus,1,-1 do
      if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end
    end
  end
  mod.events:on('battle.ended',M.finish,500)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-damage-and-held-item-owners',providerStatus='item-transfer',
      buildReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
