-- An Illusion is an entry-scoped appearance, never Transform or a saved
-- species mutation. Keep battle ordering separate from the saved party.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-ILLUSION',OWNER='kasc.illusion/v1'}
  local A,I=opts.abilities,opts.identity
  local cache=setmetatable({},{__mode='k'})
  local displayCache=setmetatable({},{__mode='k'})
  local drawing=setmetatable({},{__mode='k'})
  local renderBattle
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'end
  local function party(b,lane)
    if lane=='player'then return b:playerPartyView() end
    return b.kind=='trainer'and b.enemyParty or{b.enemy.mon}
  end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{} end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local d=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.result or b.demo or b.safari or b.ghost
        or (b.kind~='wild'and b.kind~='trainer')or not d or d.kascIllusion67~=M.OWNER then return end
    local gen=opts.status.epoch(b);return gen and gen>=5 and gen<=7 and gen or nil
  end
  local function row(b,w)
    if not b or not w or not w.mon then return end
    local s=state(b);local lane=b and side(b,w);local r=s and lane and s[lane]
    return r and r.original==w.mon.species and r or nil
  end
  function M.active(b,w)local r=row(b,w);return r and r.look~=nil or false end
  function M.visualMon(b,w)
    local r=row(b,w);if not r or not r.look then return end
    local c=cache[w]
    if not c or c.row~=r then
      local mon=copy(w.mon)
      for k in pairs(I.captureLook(w.mon))do mon[k]=nil end
      for k,v in pairs(r.look)do mon[k]=copy(v)end
      mon.species=r.copied;mon.nickname=r.nickname
      local forms=mod.exports and mod.exports.pokemonHPForms67
      if forms and r.hpForm then forms.bindVisual(mon,r.hpForm)end
      c={row=r,mon=mon};cache[w]=c
    end
    -- Own live PP, items, HP/status etc. must not freeze when the mask is
    -- cached. Only the captured appearance/name/species belong to the mask.
    local look=I.captureLook(w.mon)
    for k in pairs(c.mon)do
      if k~='species'and k~='nickname'and r.look[k]==nil and look[k]==nil then c.mon[k]=nil end
    end
    for k,v in pairs(w.mon)do
      if k~='species'and k~='nickname'and r.look[k]==nil and look[k]==nil then c.mon[k]=v end
    end
    return c.mon
  end
  local function pack(...)return{n=select('#',...),...}end
  -- Pipeline ticks build the staged HUD before BattleState.draw. Keep a
  -- read-only presentation context for KASC's public gender/shiny services;
  -- do not swap battlers across the renderer's lifecycle transactions.
  function M.withRenderContext(fn,game,...)
    local previous=renderBattle
    renderBattle=nil
    local states=game and game.stack and game.stack.states or{}
    for i=#states,1,-1 do
      if getmetatable(states[i])==B then renderBattle=states[i];break end
    end
    local out=pack(pcall(fn,...))
    renderBattle=previous
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.renderMon(mon)
    local b=renderBattle
    if b then
      for _,lane in ipairs({'player','enemy'})do
        local w=b[lane]
        if w and w.mon==mon then return M.visualMon(b,w)or mon end
      end
    end
    return mon
  end
  -- Synchronous draw-only views. Never replace a saved mon or change the
  -- real battler. Stable view identity preserves renderer animation caches.
  function M.withPresentation(fn,b,...)
    if drawing[b]then return fn(b,...)end
    local saved={};local count=0
    for _,lane in ipairs({'player','enemy'})do
      local w=b and b[lane];local mon=w and M.visualMon(b,w)
      if mon then
        local view=displayCache[w]
        if not view or view.mon~=mon then view={};displayCache[w]=view end
        for k in pairs(view)do view[k]=nil end
        for k,v in pairs(w)do view[k]=v end
        view.mon=mon;view.def=b.data.pokemon[mon.species]
        saved[lane]=w;b[lane]=view;count=count+1
      end
    end
    if count==0 then return fn(b,...)end
    drawing[b]=true
    local out=pack(pcall(fn,b,...))
    for lane,w in pairs(saved)do b[lane]=w end
    drawing[b]=nil
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.install(game)
    B._kascIllusion67=M
    M.renderGame=game
    local pipelines=require('src.render.Pipelines')
    if not pipelines.__kascIllusionRender67 then
      local update=pipelines.update
      pipelines.update=function(...)
        local active=B._kascIllusion67
        return active.withRenderContext(update,active.renderGame,...)
      end
      pipelines.__kascIllusionRender67=true
    end
    if not B._kascIllusionDraw67 then
      local draw=assert(B.draw)
      B.draw=function(b,...)return B._kascIllusion67.withPresentation(draw,b,...)end
      B._kascIllusionDraw67=true
    end
    local renderer=opts.renderer and opts.renderer.module(game,'OverworldBattle')
    if not renderer then return false,'renderer-absent'end
    if renderer.__kascIllusionPresentation67 then return true end
    -- Public body seam only. Measurement functions are read-only. HUD
    -- textures, cameras and VASC's provider slots remain renderer-owned.
    for _,method in ipairs({'sideTexture'})do
      local old=renderer[method]
      if type(old)=='function'then
        renderer[method]=function(b,...)return B._kascIllusion67.withPresentation(old,b,...)end
      end
    end
    renderer.__kascIllusionPresentation67=M.OWNER
    return true
  end
  local function refresh(b,w)
    cache[w]=nil
    local visual=M.visualMon(b,w)or I.visualMon(b,w)
    w.illusion=M.active(b,w)and true or nil
    w.name=visual.nickname or b.data.pokemon[visual.species].name
    w.__ascendantCrystalAnimation=nil
    w.sprite=B.makeBattler(b.data,visual,w.isPlayer).sprite
  end
  function M.reveal(b,w,announce)
    local r=row(b,w);if not r or not r.look then return false end
    r.look=nil;r.copied=nil;r.nickname=nil;r.source=nil;r.hpForm=nil
    refresh(b,w)
    if announce then b:sayNext(opts.i18n.text('The illusion wore off!','Das Trugbild ist verflogen!'))end
    return true
  end
  function M.enter(b,w)
    if not M.epoch(b)or not w or not w.mon or w.mon.hp<=0 then return false end
    local lane=side(b,w);if not lane then return false end
    local mons=party(b,lane);local index
    for i,mon in ipairs(mons or{})do if i<=6 and mon==w.mon then index=i;break end end
    if not index then return false end
    local s=state(b,true);local previous=s[lane]
    if previous and previous.original==w.mon.species and previous.index==index
        and previous.entered then return false end
    local order=previous and previous.order or{}
    if #order==0 then for i=1,math.min(6,#mons)do order[i]=i end end
    for pos,i in ipairs(order)do
      if i==index then order[1],order[pos]=order[pos],order[1];break end
    end
    local r={original=w.mon.species,index=index,order=order,entered=true};s[lane]=r
    if A.activeAbility(b,w)~='ILLUSION'or I.transformed(w)then return false end
    for pos=#order,2,-1 do
      local target=mons[order[pos]]
      if target and target.hp and target.hp>0 and not target.egg and not target.isEgg
          and not target.eggSpecies and target.species~='EGG'and b.data.pokemon[target.species]then
        r.source=order[pos];r.copied=target.species;r.look=I.captureLook(target);r.nickname=target.nickname
        -- Capture the reserve's item-selected appearance at entry, using
        -- this battle's frozen era. Never copy its held item or ability.
        local typeItems=mod.exports and mod.exports.pokemonTypeItems67
        local view=typeItems and typeItems.preview(b.game,target,M.epoch(b))
        r.hpForm=view and view.key or nil
        refresh(b,w);return true
      end
    end
    return false
  end
  function M.switch(ev)
    local b,w=ev.battle,ev.battler;local s=state(b);local lane=side(b,w)
    if ev.previous then ev.previous.illusion=nil;cache[ev.previous]=nil end
    if s and lane and s[lane]then s[lane].entered=nil end
    M.enter(b,w)
  end
  function M.sync(b)
    if not state(b)then return end
    for _,w in ipairs({b.player,b.enemy})do
      if w and M.active(b,w)and (w.mon.hp<=0 or not M.epoch(b)
          or A.activeAbility(b,w)~='ILLUSION')then M.reveal(b,w,w.mon.hp>0 and M.epoch(b)~=nil)end
    end
  end
  function M.hit(b,w,damage,hadSub)
    if not hadSub and type(damage)=='number'and damage>0 then return M.reveal(b,w,true)end
    return false
  end
  function M.opening(b)
    if getmetatable(b)~=B or b.result or b.demo or b.safari or b.ghost
        or(b.kind~='wild'and b.kind~='trainer')then return end
    local p=opts.rules.peek(b.game)
    if not p or not p.extensionsEnabled or p.activeEpoch<5 or p.activeEpoch>7 then return end
    if not b.kascGenerationRulesReceipt then opts.rules.attachBattle(b,b.game)end
    for _,w in ipairs({b.player,b.enemy})do A.bindEntry(b,w);M.enter(b,w)end
  end
  function M.resume(b)
    for _,w in ipairs({b.player,b.enemy})do if w and row(b,w)then refresh(b,w)end end
  end
  function M.validateCheckpoint(b)
    local s=state(b);if s==nil then return true end
    if type(s)~='table'then return false,'invalid_illusion_state'end
    local receipt=b.field.tokens['kasc.generation-receipt/v1']
    local gen=type(receipt)=='table'and receipt.activeEpoch or M.epoch(b)
    if next(s)and(type(gen)~='number'or gen<5 or gen>7 or receipt and receipt.mode=='off')then
      return false,'invalid_illusion_generation'
    end
    for lane,r in pairs(s)do
      if lane~='player'and lane~='enemy'then return false,'invalid_illusion_side'end
      local w,mons=b[lane],party(b,lane)
      if type(r)~='table'or not w or r.original~=w.mon.species or r.entered~=true
          or type(r.index)~='number'or r.index%1~=0 or r.index<1 or r.index>6
          or mons[r.index]~=w.mon or type(r.order)~='table'or #r.order~=#mons
          or r.order[1]~=r.index then return false,'invalid_illusion_entry'end
      local seen={}
      for k,i in pairs(r.order)do
        if type(k)~='number'or k%1~=0 or k<1 or k>#mons or type(i)~='number'
            or i%1~=0 or i<1 or i>#mons or seen[i]then return false,'invalid_illusion_order'end
        seen[i]=true
      end
      if r.look~=nil then
        if not I.validLook(r.look)or I.transformed(w)or type(r.source)~='number'
            or r.source%1~=0 or r.source==r.index or not mons[r.source]
            or mons[r.source].species~=r.copied or not b.data.pokemon[r.copied]
            or r.nickname~=nil and(type(r.nickname)~='string'or #r.nickname>100)then
          return false,'invalid_illusion_appearance'
        end
        if r.hpForm~=nil then
          local forms=mod.exports and mod.exports.pokemonHPForms67
          if not forms or not forms.validForm(r.copied,r.hpForm)then return false,'invalid_illusion_form'end
        end
      elseif r.copied~=nil or r.source~=nil or r.nickname~=nil or r.hpForm~=nil then return false,'orphan_illusion_appearance'end
      for k in pairs(r)do
        if not({original=true,index=true,order=true,entered=true,source=true,copied=true,look=true,nickname=true,hpForm=true})[k]then
          return false,'unknown_illusion_field'
        end
      end
    end
    return true
  end
  B._kascIllusion67=M
  if not B._kascIllusionWrapped67 then
    local enter,cry=B.enter,B.playEntranceCry
    B.enter=function(b,...)B._kascIllusion67.opening(b);return enter(b,...)end
    B.playEntranceCry=function(b,w,...)
      local visual=B._kascIllusion67.visualMon(b,w)
      if visual then local display={};for k,v in pairs(w)do display[k]=v end;display.mon=visual;w=display end
      return cry(b,w,...)
    end
    for _,method in ipairs({'performMove','update'})do
      local old=B[method]
      B[method]=function(b,...)
        local out=pack(pcall(old,b,...));B._kascIllusion67.sync(b)
        if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
      end
    end
    B._kascIllusionWrapped67=true
  end
  mod.events:on('battle.battler_switched',M.switch,6500)
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap('render.hud',function(nextHud,game,...)
      return M.withRenderContext(nextHud,game,game,...)
    end,30000)
  end
  mod.events:on('battle.fainted',function(ev)M.reveal(ev.battle,ev.battler,false)end,8000)
  mod.events:on('battle.ended',function(ev)
    local b=ev and ev.battle;if not b then return end
    for _,w in ipairs({b.player,b.enemy})do if w then M.reveal(b,w,false);cache[w]=nil end end
    if state(b)then b.field.tokens[M.OWNER]=nil end
  end,8000)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascIllusion67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-entry-direct-hit-and-presentation-identity',
      providerStatus='illusion-v-vii',buildReceiptId='docs/ILLUSION_67.md',
      rollbackReceiptId='docs/ILLUSION_67.md'})
  end
  return M
end
