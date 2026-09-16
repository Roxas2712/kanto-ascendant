-- Item-controlled battle types and read-only menu presentation; no saved
-- species/stat replacement and no new screen provider.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-TYPE-ITEMS',OWNER='kasc.type-items/v1'}
  local A,forms=opts.abilities,opts.forms
  local rows={}
  for _,r in ipairs({
    {'FIGHTING','FIST','FAUST','KAMPF'},{'FLYING','SKY','WOLKEN','FLUG'},
    {'POISON','TOXIC','GIFT','GIFT'},{'GROUND','EARTH','ERD','BODEN'},
    {'ROCK','STONE','STEIN','GESTEIN'},{'BUG','INSECT','KÄFER','KÄFER'},
    {'GHOST','SPOOKY','SPUK','GEIST'},{'STEEL','IRON','EISEN','STAHL'},
    {'FIRE','FLAME','FEUER','FEUER'},{'WATER','SPLASH','WASSER','WASSER'},
    {'GRASS','MEADOW','WIESEN','PFLANZEN'},{'ELECTRIC','ZAP','BLITZ','ELEKTRO'},
    {'PSYCHIC','MIND','HIRN','PSYCHO'},{'ICE','ICICLE','FROST','EIS'},
    {'DRAGON','DRACO','DRACO','DRACHEN'},{'DARK','DREAD','FURCHT','UNLICHT'},
    {'FAIRY','PIXIE','FEEN','FEEN'},
  })do
    rows[r[2]..'_PLATE']={type=r[1],kind='plate',generation=r[1]=='FAIRY'and 6 or 4,
      names={en=r[2]..' PLATE',de=r[3]..'TAFEL'}}
    rows[r[1]..'_MEMORY']={type=r[1],kind='memory',generation=7,
      names={en=r[1]..' MEMORY',de=r[4]..'-DISC'}}
  end
  local families={}
  for _,spec in ipairs({{493,'MULTITYPE',4,'plate'},{773,'RKS_SYSTEM',7,'memory'}})do
    local dex,id,gen,kind=unpack(spec)
    local base='dex:'..dex;local selected={}
    for key,row in pairs(opts.art)do if key:sub(1,#('cosmetic:'..dex..':'))=='cosmetic:'..dex..':'then selected[key]=row end end
    forms.registerCosmeticSet(base,selected,id,gen)
    families[assert(opts.species.byKey[base])]={dex=dex,base=base,ability=id,gen=gen,kind=kind}
  end
  local function copy(t)local r={};for k,v in pairs(t or{})do r[k]=v end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function typeId(kind)return kind=='PSYCHIC'and'PSYCHIC_TYPE'or kind end
  function M.itemMetadata(id)
    local r=rows[id];if not r then return end
    return{id=id,names=copy(r.names),generation=r.generation,flags={'holdable','holdable-passive'},
      kascTypeItem=r.type,kascTypeItemKind=r.kind}
  end
  for id,r in pairs(rows)do
    assert(not mod.content.items:get(id),'type item already owned: '..id)
    local epochs={};for gen=r.generation,7 do epochs[gen]=true end
    mod.content.items:register(id,{id=id,name=opts.i18n.text(r.names.en,r.names.de),names=r.names,
      price=1000,keyItem=false,field=false,battle=false,kascTypeItemOwner67=M.OWNER,
      kascEquipmentRewardEpochs=epochs})
  end
  function M.supportsItem(game,id,gen)
    local r=rows[id];local d=game and game.data and game.data.items and game.data.items[id]
    return r and d and d.kascTypeItemOwner67==M.OWNER and type(gen)=='number'
      and gen%1==0 and gen>=r.generation and gen<=7 or false
  end
  function M.preview(game,mon,generation)
    local f=type(mon)=='table'and families[mon.species]
    if not f or not game or mon.isEgg or mon.egg or mon.is_egg or mon.eggSpecies then return end
    local p=generation==nil and opts.rules.peek(game)
    if generation==nil then
      if not p or not p.extensionsEnabled then return end
      generation=p.activeEpoch
    end
    if type(generation)~='number'or generation%1~=0 or generation<1 or generation>7 then return end
    local tag='NORMAL'
    if generation>=f.gen then
      local ability=opts.binding.view(game,mon,generation)
      local id,err=opts.held(mon)
      if err then return end
      local item=rows[id]
      if ability and ability.id==f.ability and item and item.kind==f.kind
          and M.supportsItem(game,id,generation)then tag=item.type end
    end
    return{key=tag=='NORMAL'and f.base or'cosmetic:'..f.dex..':'..tag:lower(),
      type=typeId(tag),generation=generation}
  end
  for _,family in pairs(families)do
    forms.registerItemPreview(family.base,function(mon)
      local view=M.preview(M.game,mon);return view and view.key
    end)
  end
  -- The native and ORAS Summary renderers read the species definition.
  -- Supply this one screen with a detached read view only while drawing;
  -- never change the shared row (two Arceus may carry different Plates).
  function M.withSummary(original,screen,...)
    local game,mon=screen.game,screen.mon
    if not mon or mon.isEgg or mon.egg or mon.is_egg or mon.eggSpecies then return original(screen,...)end
    local view=M.preview(game,mon)
    local public=mod.exports and mod.exports.maximumDex67
    local def=game and game.data and game.data.pokemon[mon.species]
    if not def then return original(screen,...)end
    -- Reuse the public Dex identity owner for every Summary species; the
    -- renderer must not print private ABI/art slots such as 20493.
    local projected=copy(public and public.entryDefinition(mon.species,def)or def)
    if view then projected.types={view.type}end
    local pokemon=setmetatable({[screen.mon.species]=projected},{__index=game.data.pokemon})
    local data=setmetatable({pokemon=pokemon},{__index=game.data})
    screen.game=setmetatable({data=data},{__index=game})
    local result=pack(pcall(original,screen,...));screen.game=game
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  function M.decorateSummary(screen)
    local Summary=require('src.ui.SummaryMenu')
    if getmetatable(screen)~=Summary or screen.__kascTypeItemSummary67 then return end
    screen.__kascTypeItemSummary67=M.OWNER
    for _,method in ipairs({'draw','drawWidescreen'})do
      local original=screen[method]
      if type(original)=='function'then
        screen[method]=function(self,...)return B._kascTypeItems67.withSummary(original,self,...)end
      end
    end
  end
  function M.install(game)M.game=game;return true end
  mod.events:on('game.ready',function(ev)if ev and ev.game then M.install(ev.game)end end,-9301)
  mod.events:on('save.loaded',function(ev)if ev and ev.game then M.install(ev.game)end end,-9301)
  -- screen.pushed is emitted after constructors/skin decoration and enter.
  mod.events:on('screen.pushed',function(ev)if ev and ev.state then M.decorateSummary(ev.state)end end,-20000)
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=getmetatable(b)==B and not b.result and not b.demo and b.kind~='link'
      and r and r.kascTypeItems67==M.OWNER and opts.status.epoch(b)
    return gen and gen>=1 and gen<=7 and gen or nil
  end
  function M.itemType(b,w,kind,effects)
    local gen=M.epoch(b);if not gen or not w or not w.mon then return end
    local id=(effects and opts.effectiveHeld or opts.held)(w.mon,b,w)
    local r=rows[id]
    if r and r.kind==kind and M.supportsItem(b.game,id,gen)then return typeId(r.type),r.type end
  end
  function M.locked(b,w)
    local f=w and w.mon and families[w.mon.species];local gen=M.epoch(b)
    return f and gen and gen>=f.gen and not opts.identity.transformed(w)and f or nil
  end
  function M.sync(b)
    if not M.epoch(b)then return end
    for _,w in ipairs({b.player,b.enemy})do
      local f=M.locked(b,w)
      if f then
        local typ,tag='NORMAL','NORMAL'
        if A.abilityIdentity(b,w)==f.ability then typ,tag=M.itemType(b,w,f.kind,false)end
        typ,tag=typ or'NORMAL',tag or'NORMAL'
        -- Roost is a later, turn-local type filter, not a replacement of
        -- Multitype/RKS or the item-selected visual form.
        local changing=mod.exports.pokemonTypeChanges67
        local added=changing and changing.typeItemProjection(b,w,{typ})
        w.curTypes=added or{typ=='FLYING'and opts.healing.roostActive(b,w)and'NORMAL'or typ}
        local key=tag=='NORMAL'and f.base or'cosmetic:'..f.dex..':'..tag:lower()
        forms.change(b,w,key,M.epoch(b),true)
      end
    end
  end
  -- Validate against the frozen checkpoint era, before rules.resumeBattle
  -- projects the catalogue. Never silently repair a contradictory saved form.
  function M.validateCheckpoint(b)
    local tokens=b.field and b.field.tokens
    local saved=tokens and tokens[forms.OWNER]
    if type(saved)~='table'then return true end -- structural check belongs to forms
    local receipt=tokens['kasc.generation-receipt/v1']
    local gen=type(receipt)=='table'and receipt.activeEpoch or M.epoch(b)
    for _,lane in ipairs({'player','enemy'})do
      local w=b[lane];local f=w and w.mon and families[w.mon.species]
      local record=saved[lane]
      if f and record then
        if type(gen)~='number'or gen%1~=0 or gen<f.gen or gen>7
            or receipt and receipt.mode=='off'then return false,'invalid_type_item_generation'end
        if opts.identity.transformed(w)then return false,'transformed_type_item_record'end
        local id,err=opts.held(w.mon)
        if err then return false,'invalid_type_item_aliases'end
        local ability=opts.binding.view(b.game,w.mon,gen)
        local item=rows[id]
        local tag=ability and ability.id==f.ability and item and item.kind==f.kind
          and gen>=item.generation and item.type or'NORMAL'
        local expected=tag=='NORMAL'and f.base or'cosmetic:'..f.dex..':'..tag:lower()
        if record.key~=expected then return false,'inconsistent_type_item_form'end
        local typ=typeId(tag)
        local changing=mod.exports.pokemonTypeChanges67
        local added=changing and changing.typesMatch(b,w,{typ})
        if typ=='FLYING'and opts.healing.roostActive(b,w)then typ='NORMAL'end
        if not added and(type(w.curTypes)~='table'or #w.curTypes~=1 or w.curTypes[1]~=typ)then
          return false,'inconsistent_type_item_types'
        end
      end
    end
    return true
  end
  -- Shared move projection runs before accuracy, damage and animation. Item
  -- possession controls the form, but Klutz can suppress an attack's item effect.
  function M.projectMove(b,w,move,id)
    local kind=id=='JUDGMENT'and'plate'or id=='MULTI_ATTACK'and'memory'
    if not kind or not M.epoch(b)then return move end
    local r=copy(move);r.type=M.itemType(b,w,kind,true)or'NORMAL'
    return r
  end
  function M.damage(nextDamage,ctx)
    local b=ctx and ctx.battle
    if not b or not ctx.move or ctx.move.category=='status'or ctx.opts and ctx.opts.typeless
      or not ctx.user or (tonumber(ctx.move.power)or 0)<=0 then return nextDamage(ctx)end
    local typ=M.itemType(b,ctx.user,'plate',true)
    if typ~=ctx.move.type then return nextDamage(ctx)end
    local r=copy(ctx);r.opts=copy(ctx.opts);r.opts.kascHeldTypeBoost67=true
    return nextDamage(r)
  end
  function M.opening(b)
    if getmetatable(b)~=B or b.result or b.demo or b.kind=='link'then return end
    local p=opts.rules.peek(b.game)
    if not p or not p.extensionsEnabled or p.activeEpoch<4 or p.activeEpoch>7 then return end
    if not b.kascGenerationRulesReceipt then opts.rules.attachBattle(b,b.game)end
    for _,w in ipairs({b.player,b.enemy})do if w then A.bindEntry(b,w)end end
    M.sync(b)
  end
  B._kascTypeItems67=M
  if not B._kascTypeItemsWrapped67 then
    local enter=B.enter
    B.enter=function(b,...)B._kascTypeItems67.opening(b);return enter(b,...)end
    for _,method in ipairs({'performMove','update'})do
      local old=B[method]
      B[method]=function(b,...)
        B._kascTypeItems67.sync(b)
        local r=pack(pcall(old,b,...));B._kascTypeItems67.sync(b)
        if not r[1]then error(r[2],0)end;return unpack(r,2,r.n)
      end
    end
    B._kascTypeItemsWrapped67=true
  end
  mod.events:on('battle.battler_switched',function(ev)M.sync(ev.battle)end,6400)
  mod.hooks:wrap('battle.damage',M.damage,-7990)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascTypeItems67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-type-item-move-and-cosmetic-forms',providerStatus='multitype-rks-vii',
      buildReceiptId='docs/TYPE_ITEMS_67.md',rollbackReceiptId='docs/TYPE_ITEMS_67.md'})
  end
  return M
end
