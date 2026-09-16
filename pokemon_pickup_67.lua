return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-PICKUP',OWNER='kasc.pickup/v1'}
  local A,H,tr=opts.abilities,opts.consumption,opts.i18n.text
  assert(type(H.claim)=='function'and type(opts.transfer.preparePickup)=='function')
  local finished=setmetatable({},{__mode='k'})
  local metadata={}
  -- Pinned PokeAPI catalog identities missing from the older held-item
  -- facts. Preserve existing evolution/contact/grounding handlers verbatim.
  local extra={
    BALM_MUSHROOM={5,15000,'Balm Mushroom','Duftpilz'},
    BIG_NUGGET={5,40000,'Big Nugget','Riesennugget'},
    PEARL_STRING={5,20000,'Pearl String','Triperle'},
    DAWN_STONE={4,3000,'Dawn Stone','Funkelstein'},
    DUSK_STONE={4,3000,'Dusk Stone','Finsterstein'},
    SHINY_STONE={4,3000,'Shiny Stone','Leuchtstein'},
    PRISM_SCALE={5,2000,'Prism Scale','Schönschuppe'},
    IRON_BALL={4,4000,'Iron Ball','Eisenkugel'},
    DESTINY_KNOT={4,4000,'Destiny Knot','Fatumknoten'},
  }
  local activeItems={KINGS_ROCK=true,WHITE_HERB=true,LEFTOVERS=true,IRON_BALL=true,DESTINY_KNOT=true}
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  for _,id in ipairs(opts.tables.items())do
    local row=opts.facts.item(id,7)
    local old=mod.content.items:get(id)
    if not row and extra[id]then
      local x=extra[id];row={id=id,generation=x[1],cost=x[2],names={en=x[3],de=x[4]}}
    end
    if not row and old and old.machine then
      row={id=id,generation=old.originEpoch or old.originGeneration or 1,
        cost=old.price,names=old.names or{en=old.name,de=old.name}}
    end
    assert(row,'Pickup item metadata missing: '..id)
    row.flags={'holdable'};row.noHeldEffect=not activeItems[id]
    metadata[id]=row
    if not old then
      -- Unknown machines/evolution items must never be manufactured as
      -- inert bag entries just to make a table pass.
      assert(id=='BALM_MUSHROOM'or id=='BIG_NUGGET'or id=='PEARL_STRING'or id=='HEART_SCALE',
        'Pickup requires existing functional item owner: '..id)
      mod.content.items:register(id,{id=id,name=tr(row.names.en,row.names.de),names=row.names,
        price=row.cost,keyItem=false,tossable=true,needsTarget=false,
        originGeneration=row.generation,kascEquipmentCatalog=true})
    end
  end
  function M.itemMetadata(id)return copy(metadata[id])end
  function M.noHeldEffect(id)return metadata[id]and metadata[id].noHeldEffect or false end
  local function state(b,create)
    if create then
      b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}
    end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'end
  local function party(b,lane)
    if lane=='player'then return b.game.save.party end
    return b.kind=='trainer'and b.enemyParty or{b.enemy.mon}
  end
  local function identity(b,w)
    local lane=side(b,w);if not lane then return end
    for i,mon in ipairs(party(b,lane)or{})do
      if mon==w.mon and i<=6 then return lane,i end
    end
  end
  function M.epoch(b)
    local gen=H.epoch(b)
    if gen and gen>=5 then return gen end
  end
  function M.forget(b,w)
    local lane=side(b,w);local s=state(b);if s and lane then s[lane]=nil end
  end
  local function collectable(b,id)
    local d=type(id)=='string'and b.data.items[id]
    return d and id~='AIR_BALLOON'and not d.keyItem and d.tossable~=false
      and not d.kascNoTake67
  end
  function M.remember(b,w,id)
    if not M.epoch(b)then return end
    local lane,index=identity(b,w);if not lane then return end
    -- A new genuine consumption supersedes the previous one, even when
    -- this item (a popped Balloon) is itself excluded from Pickup.
    M.forget(b,w)
    if not collectable(b,id)then return end
    state(b,true)[lane]={index=index,species=w.mon.species,item=id,turn=b.turnCount or 0}
  end
  function M.validateCheckpoint(b)
    local s=state(b);if s==nil then return true end
    if type(s)~='table'then return false,'invalid_pickup_state'end
    local receipt=b.field.tokens['kasc.generation-receipt/v1']
    local gen=type(receipt)=='table'and receipt.activeEpoch or M.epoch(b)
    if next(s)and (type(gen)~='number'or gen<5 or gen>7
        or type(receipt)=='table'and receipt.mode=='off')then return false,'invalid_pickup_generation'end
    for lane,r in pairs(s)do
      if lane~='player'and lane~='enemy'then return false,'invalid_pickup_side'end
      local w=b[lane]
      if type(r)~='table'or not w or type(r.index)~='number'or r.index%1~=0
          or r.index<1 or r.index>6 or (party(b,lane)or{})[r.index]~=w.mon
          or r.species~=w.mon.species or type(r.item)~='string'
          or not collectable(b,r.item)
          or type(r.turn)~='number'or r.turn%1~=0 or r.turn<0 or r.turn>(b.turnCount or 0)then
        return false,'invalid_pickup_record'
      end
      for k in pairs(r)do
        if k~='index'and k~='species'and k~='item'and k~='turn'then return false,'unknown_pickup_field'end
      end
      -- Validate against the serialized consumption owner directly: frozen
      -- generation receipts are reattached only after checkpoint validation.
      local cs=b.field.tokens[H.OWNER]
      local cr=type(cs)=='table'and type(cs.records)=='table'and cs.records[lane..':'..r.index]
      if type(cr)~='table'or cr.species~=r.species or cr.item~=r.item then
        return false,'pickup_without_consumption'
      end
    end
    return true
  end
  function M.recover(b,w)
    if not M.epoch(b)or not w or not w.mon or w.mon.hp<=0
        or A.activeAbility(b,w)~='PICKUP'then return false end
    local held,err=opts.held(w.mon);if held or err then return false end
    local lane=side(b,w);if not lane then return false end
    local other=lane=='player'and'enemy'or'player';local donor=b[other]
    local s=state(b);local r=s and s[other]
    if not r or r.turn~=(b.turnCount or 0)or not donor or donor.mon.hp<=0
        or (party(b,other)or{})[r.index]~=donor.mon or donor.mon.species~=r.species
        or H.consumed(b,donor)~=r.item or not collectable(b,r.item)then return false end
    if not opts.transfer.preparePickup(b,w)then return false end
    local id=r.item;local def=b.data.items[id]
    if not H.claim(b,donor,id)then return false end
    w.mon.item=id;w.mon.heldItem=id;A.clearItemLoss(b,w)
    local choice=opts.choice and opts.choice();if choice then choice.clear(b,w)end
    local names=def.names or{}
    b:sayNext(tr('%s picked up %s!','%s hebt %s mit Mitnahme auf!')
      :format(w.name or w.mon.species,tr(names.en or def.name or id,names.de or def.name or id)))
    b:drainNext();H.activateRestored(b,w,false)
    return true
  end
  function M.finish(ev)
    local b=ev and ev.battle
    if getmetatable(b)~=Battle or finished[b]or ev.skipped or b.demo
        or (b.kind~='wild'and b.kind~='trainer')or b.result~='win'or ev.result~='win'
        or not b.game or not b.game.save then return 0 end
    local gen=opts.status.epoch(b);if not gen or gen<3 or gen>7 then return 0 end
    finished[b]=true
    local found,seen=0,{}
    for index,mon in ipairs(b.game.save.party or{})do
      if index>6 then break end
      if type(mon)=='table'and not seen[mon]then
        seen[mon]=true
        local held,err=opts.held(mon);local ability=opts.binding.view(b.game,mon,gen)
        if not mon.isEgg and not mon.egg and not mon.eggSpecies and mon.species~='EGG'
            and not held and not err and ability.active and ability.id=='PICKUP'
            and opts.tables.draw(gen,mon.level,0)and b.rng(0,9)==0 then
          local id=assert(opts.tables.draw(gen,mon.level,b.rng(0,99)))
          assert(b.data.items[id],'registered Pickup item disappeared: '..id)
          mon.item=id;mon.heldItem=id;found=found+1
        end
      end
    end
    return found
  end
  mod.events:on('battle.battler_switched',function(ev)M.forget(ev.battle,ev.battler)end,30000)
  mod.events:on('battle.ended',function(ev)
    local b=ev and ev.battle
    if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end,100)
  mod.events:on('battle.ended',M.finish,-9000)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascPickup67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='consumption-transfer-and-native-party',providerStatus='pickup-iii-vii',
      buildReceiptId='docs/PICKUP_67.md',rollbackReceiptId='docs/PICKUP_67.md'})
  end
  return M
end
