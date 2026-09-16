-- HP form changes are temporary battle state. In particular, never turn a
-- saved solo Wishiwashi into a permanently boosted gift species.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local Stats=require('src.pokemon.Stats')
  local M={CARD_ID='KASC-67-HP-FORMS',OWNER='kasc.hp-forms/v1'}
  local families,art={},{}
  local cosmeticBase={}
  local itemPreviews={}
  local active=setmetatable({},{__mode='k'})
  local roster=setmetatable({},{__mode='k'})
  local function copy(t)local out={};for k,v in pairs(t or{})do out[k]=v end;return out end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{} end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function family(base,other,id,gen,high)
    local f={base=base,other=other,id=id,gen=gen,high=high}
    families[base]=f;families[other]=f
  end
  family('dex:555','form:10017','ZEN_MODE',5,false)
  family('dex:746','form:10127','SCHOOLING',7,true)
  for color=0,6 do
    family(color==0 and'dex:774'or'form:'..(10129+color),'form:'..(10136+color),'SHIELDS_DOWN',7,false)
  end
  -- Existing permanent forms keep their current registrar and graphics.
  -- Only the two battle-only forms need presentation aliases, NOT species
  -- registrations, gift codes, or additional visible Pokédex entries.
  local payload={schema='kasc.backend-gift-art/v1',entries={}}
  local function prepareArt(key,payload,alias,slot)
    local images=assert(opts.art[key]);local id=opts.species.byKey[key]
    local def=id and mod.content.pokemon:get(id)
    if def then
      art[key]={artAlias=id,artSlot=def.dex,animated=images.animations and images.animations.front and images.animations.front.animated or false}
    else
      local source=assert(tonumber(key:match('^form:(%d+)$')))
      slot=slot or 88000+source-10000;alias=alias or'KA_GIFT_HP_FORM_'..source
      local p=images.paths;local a=images.animations or{}
      art[key]={artAlias=alias,artSlot=slot,animated=a.front and a.front.animated or false}
      payload.entries[tostring(slot)]={species=alias,heightM=opts.catalog.entries[key].heightM,
        voxelSize=images.voxelSize,
        pixel={front=p.front,frontShiny=p.frontShiny,back=p.back,backShiny=p.backShiny,
          preferPixel2D=true,rearLayout='upper32-of-48'},
        fallback={front=p.voxelFront,frontShiny=p.voxelFrontShiny,scale=images.voxelScale},
        native={front=a.front,back=a.back,frontShiny=a.frontShiny,backShiny=a.backShiny},
        voxel={variants={normal=a.voxel,shiny=a.voxelShiny}}}
    end
  end
  for key in pairs(families)do prepareArt(key,payload)end
  assert(opts.sprites.registerAdditionalArt(payload)==2,'HP form art registration failed')
  -- Other form cards share the proven stat/art/checkpoint boundary without
  -- inheriting an HP rule. They alone decide when their form changes.
  function M.registerExternalPair(base,other,id,gen)
    assert(not families[base]and not families[other],'battle form pair already owned')
    local a,z=assert(opts.catalog.entries[base]),assert(opts.catalog.entries[other])
    local permanent=a.isBase
    for _,f in ipairs(a.formMetadata or{})do if f.is_battle_only=='0'then permanent=true end end
    assert(permanent and not z.isBase and a.nationalDex==z.nationalDex
      and a.baseStats.hp==z.baseStats.hp and gen>=5 and gen<=7,'invalid external battle form pair')
    local source=assert(tonumber(other:match('^form:(%d+)$')))
    local extra={schema='kasc.backend-gift-art/v1',entries={}}
    prepareArt(base,extra)
    prepareArt(other,extra,'KA_GIFT_BATTLE_FORM_'..source,89000+source-10000)
    assert(opts.sprites.registerAdditionalArt(extra)==1,'external battle form art registration failed')
    family(base,other,id,gen)
    families[base].external=true
    return true
  end
  function M.registerExternalSet(sources,other,id,gen)
    local target=assert(opts.catalog.entries[other]);local seen={}
    assert(type(sources)=='table'and #sources>0 and not families[other]
      and not target.isBase and gen>=5 and gen<=7,'invalid external battle form set')
    for _,base in ipairs(sources)do
      local source=assert(opts.catalog.entries[base]);local permanent=source.isBase
      for _,row in ipairs(source.formMetadata or{})do
        if row.is_battle_only=='0'then permanent=true end
      end
      assert(permanent and not seen[base]and not families[base]and opts.species.byKey[base]
        and source.nationalDex==target.nationalDex,'invalid external form source')
      seen[base]=true
    end
    local source=assert(tonumber(other:match('^form:(%d+)$')))
    local extra={schema='kasc.backend-gift-art/v1',entries={}}
    for _,base in ipairs(sources)do prepareArt(base,extra)end
    prepareArt(other,extra,'KA_GIFT_BATTLE_FORM_'..source,89000+source-10000)
    assert(opts.sprites.registerAdditionalArt(extra)==1,'external battle form set art registration failed')
    local f={base=sources[1],other=other,id=id,gen=gen,external=true,sources=seen}
    families[other]=f;for _,base in ipairs(sources)do families[base]=f end
    return true
  end
  function M.artFor(mon,species)
    if not mon or mon.species~=species then return end
    if active[mon]then return active[mon]end
    local original=opts.species.bySpecies[species]
    local preview=original and itemPreviews[original]
    local key=preview and preview(mon)
    return key and M.validForm(species,key)and art[key]or nil
  end
  function M.registerItemPreview(base,preview)
    assert(families[base]and families[base].cosmetic and not itemPreviews[base])
    itemPreviews[base]=assert(type(preview)=='function'and preview)
  end
  -- A cosmetic battle form can share one canonical species row (Cherrim).
  -- Its key is explicitly separate from PokeAPI's Pokemon-id namespace.
  function M.registerCosmeticPair(base,key,id,gen,slot,entry)
    assert(not families[base]and not families[key]and key:match('^cosmetic:'))
    assert(opts.catalog.entries[base]and opts.species.byKey[base]and gen>=4 and gen<=7)
    local extra={schema='kasc.backend-gift-art/v1',entries={[tostring(slot)]=entry}}
    prepareArt(base,extra)
    assert(opts.sprites.registerAdditionalArt(extra)==1,'cosmetic form art registration failed')
    art[key]={artAlias=entry.species,artSlot=slot,animated=true}
    cosmeticBase[key]=base
    family(base,key,id,gen);families[base].external=true;families[base].cosmetic=true
  end
  function M.registerCosmeticSet(base,entries,id,gen)
    assert(not families[base]and opts.catalog.entries[base]and opts.species.byKey[base])
    assert(gen>=4 and gen<=7 and next(entries))
    local extra={schema='kasc.backend-gift-art/v1',entries={}}
    local f={base=base,id=id,gen=gen,external=true,cosmetic=true}
    prepareArt(base,extra)
    local count=0
    for key,row in pairs(entries)do
      assert(key:match('^cosmetic:')and not families[key]and not extra.entries[tostring(row.slot)])
      extra.entries[tostring(row.slot)]=row.entry;count=count+1
    end
    assert(opts.sprites.registerAdditionalArt(extra)==count,'cosmetic form set registration failed')
    families[base]=f
    for key,row in pairs(entries)do
      families[key]=f;cosmeticBase[key]=base
      art[key]={artAlias=row.entry.species,artSlot=row.slot,
        animated=row.entry.native and row.entry.native.front and row.entry.native.front.animated or false}
    end
  end
  function M.canonicalKey(key)return cosmeticBase[key]or key end
  opts.sprites.setBattleFormProvider(M.artFor)
  opts.fronts.setBattleFormProvider(M.artFor)
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local g=getmetatable(b)==B and not b.result and r and r.kascHPForms67==M.OWNER and opts.status.epoch(b)
    return g and g>=4 and g<=7 and g or nil
  end
  function M.validForm(species,key)
    local original=opts.species.bySpecies[species]
    local f=families[original]
    return type(key)=='string'and f~=nil and f==families[key]
      and (not f.sources or key==original or key==f.other)
  end
  function M.currentKey(b,w)
    local t=rows(b);local k=side(b,w)
    if not k and w and w.mon then
      k=b.player and b.player.mon==w.mon and'player'or b.enemy and b.enemy.mon==w.mon and'enemy'or nil
    end
    local r=k and t and t[k]
    return r and r.original==w.mon.species and r.key or nil
  end
  -- Called only for detached Transform/Illusion presentation copies, never saves.
  function M.bindVisual(mon,key)
    if M.validForm(mon.species,key)then active[mon]=art[key]end
  end
  local function refresh(b,w,key)
    active[w.mon]=key and art[key]or nil
    opts.sprites.selected[w.mon]=nil;w.__ascendantCrystalAnimation=nil
    w.sprite=B.makeBattler(b.data,w.mon,w==b.player,b.game and b.game.save).sprite
  end
  local function special(base,mon)
    local dv=mon.dvs and mon.dvs.special or 0
    local exp=mon.statExp and mon.statExp.special or 0
    local ev=math.floor(math.min(255,math.ceil(math.sqrt(math.max(0,exp))))/4)
    return math.floor(((base+dv)*2+ev)*(mon.level or 1)/100)+5
  end
  function M.change(b,w,key,gen,quiet)
    local old=M.currentKey(b,w);if old==key then return false end
    if families[key]and families[key].cosmetic then
      -- Opening a flower changes neither battle stats nor current types.
      -- In particular, preserve Soak, Power Trick and detached split stats.
      rows(b,true)[side(b,w)]={original=w.mon.species,key=key}
      refresh(b,w,key)
      return true
    end
    local canonical=M.canonicalKey(key)
    local s=assert(opts.facts.baseStats(canonical,gen))
    local genetics=mod.exports and mod.exports.daycare and mod.exports.daycare.breedingIVs
    local modern=genetics and genetics.stats(b.game,w.mon,gen,s)
    local calc=modern or Stats.calc({baseStats={hp=s.hp,attack=s.atk,defense=s.def,speed=s.spe,special=s.spa}},w.mon.level,w.mon.dvs,w.mon.statExp)
    local stats=copy(w.curStats)
    for _,k in ipairs({'attack','defense','speed','special'})do stats[k]=calc[k]end
    stats.specialAttack=modern and modern.specialAttack or special(s.spa,w.mon)
    stats.specialDefense=modern and modern.specialDefense or special(s.spd,w.mon)
    w.curStats=stats -- preserve HP, stages, training and save-level identity
    w.curTypes={}
    for _,kind in ipairs(opts.catalog.entries[canonical].types)do
      w.curTypes[#w.curTypes+1]=kind=='PSYCHIC'and'PSYCHIC_TYPE'or kind
    end
    rows(b,true)[side(b,w)]={original=w.mon.species,key=key}
    local body=mod.exports.pokemonBodyUtilities67
    if body then body.formChanged(b,w)end
    refresh(b,w,key)
    if not quiet then b:sayNext(opts.i18n.text('Its form changed!','Seine Form hat sich verändert!'))end
    return true
  end
  function M.detach(b,w)
    local t=rows(b);local lane=side(b,w);if t and lane then t[lane]=nil end
    if w and w.mon then active[w.mon]=nil;opts.sprites.selected[w.mon]=nil end
  end
  local function update(b,w,phase)
    local gen=M.epoch(b)
    if not gen or not w or not w.mon or not side(b,w)or w.mon.hp<=0 or opts.identity.transformed(w)
        or w._ascMegaProfile or w.mon._ascMegaForm or w.mon.ascMegaForm then return end
    local original=opts.species.bySpecies[w.mon.species];local f=families[original]
    if not f or f.external or gen<f.gen then return end
    local old=M.currentKey(b,w);local ability=opts.abilities.activeAbility(b,w)
    if phase=='entry'and old then return end
    if ability~=f.id then
      -- In Gen V/VI Mummy or suppression can end Zen Mode immediately.
      if old and f.id=='ZEN_MODE'and old~=f.base then M.change(b,w,f.base,gen,false)end
      return
    end
    if phase=='watch'then return end
    local key=f.base
    if f.id=='ZEN_MODE'then
      if phase~='entry'and w.mon.hp*2<=w.mon.stats.hp then key=f.other end
    elseif f.id=='SCHOOLING'then
      if w.mon.level>=20 and w.mon.hp*4>w.mon.stats.hp then key=f.other end
    elseif w.mon.hp*2<=w.mon.stats.hp then key=f.other end
    M.change(b,w,key,gen,phase=='entry'and key==original)
  end
  function M.entry(ev)
    local b=ev and ev.battle;if not b then return end
    if ev.previous then
      active[ev.previous.mon]=nil;opts.sprites.selected[ev.previous.mon]=nil
      local t=rows(b);if t then t[side(b,ev.battler)]=nil end
    end
    roster[b]={b.player,b.enemy}
    if ev.battler then update(b,ev.battler,'entry')
    else update(b,b.player,'entry');update(b,b.enemy,'entry')end
  end
  function M.residual(ev)
    local b=ev and ev.battle;local turn=ev and ev.turn
    if not M.epoch(b)or type(turn)~='number'or turn<1 or turn%1~=0 then return end
    local t=rows(b,true);if t.lastTurn==turn then return end;t.lastTurn=turn
    update(b,b.player,'residual');update(b,b.enemy,'residual')
  end
  function M.watch(b)
    if b then update(b,b.player,'watch');update(b,b.enemy,'watch')end
  end
  function M.blocksStatus(b,w)
    if not M.epoch(b)or not w or opts.identity.transformed(w)
        or opts.abilities.activeAbility(b,w)~='SHIELDS_DOWN'then return false end
    local key=M.currentKey(b,w)or opts.species.bySpecies[w.mon.species]
    local f=families[key]
    return f and f.id=='SHIELDS_DOWN'and key==f.base or false
  end
  function M.validateCheckpoint(b)
    local t=rows(b);if t==nil then return true end
    if type(t)~='table'then return false,'invalid_hp_forms'end
    for lane,row in pairs(t)do
      if lane=='lastTurn'then
        if type(row)~='number'or row<1 or row%1~=0 or row>(b.turnCount or 0)then return false,'invalid_hp_form_turn'end
      elseif lane~='player'and lane~='enemy'then return false,'invalid_hp_form_side'
      else
        local w=b[lane]
        if type(row)~='table'or not w or not w.mon or row.original~=w.mon.species
            or not M.validForm(row.original,row.key)or opts.identity.transformed(w)then return false,'invalid_hp_form_record'end
        for k in pairs(row)do if k~='original'and k~='key'then return false,'unknown_hp_form_field'end end
      end
    end
    return true
  end
  function M.resume(b)
    -- Restore the saved mid-turn form, NOT a fresh HP-threshold decision.
    roster[b]={b.player,b.enemy}
    for _,w in ipairs(roster[b])do local key=M.currentKey(b,w);if key then refresh(b,w,key)end end
  end
  function M.clear(b)
    for _,w in ipairs(roster[b]or{})do active[w.mon]=nil;opts.sprites.selected[w.mon]=nil end
    roster[b]=nil
    if b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end
  B._kascHPForms67=M
  if not B._kascHPFormsWrapped67 then
    local old=B.performMove
    B.performMove=function(b,...)
      B._kascHPForms67.watch(b)
      local function pack(...)return {n=select('#',...),...}end
      local result=pack(old(b,...))
      B._kascHPForms67.watch(b)
      return unpack(result,1,result.n)
    end
    B._kascHPFormsWrapped67=true
  end
  mod.events:on('battle.started',M.entry,-10040)
  mod.events:on('battle.battler_switched',M.entry,-10040)
  mod.events:on('battle.turn_ended',M.residual,-20000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,-20000)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascHPForms67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-battler-stats-art-checkpoint',providerStatus='gen5-7-hp-forms',
      buildReceiptId='docs/HP_FORMS_67.md',rollbackReceiptId='docs/HP_FORMS_67.md'})
  end
  return M
end
