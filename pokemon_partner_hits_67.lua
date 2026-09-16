-- Remaining Let's Go partner attacks. Shared native owners provide status,
-- drain, screens, seed residuals and critical math; no new Pokemon artwork.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-PARTNER-HITS',OWNER='kasc.partner-hits/v1'}
  local tr=opts.i18n.text
  local specs={
    BOUNCY_BUBBLE={number=733,type='WATER',category='special',drain=true,parts={'BUBBLEBEAM','RECOVER'}},
    BUZZY_BUZZ={number=734,type='ELECTRIC',category='special',status='PAR',chance=100,parts={'THUNDERBOLT'}},
    SIZZLY_SLIDE={number=735,type='FIRE',category='physical',contact=true,status='BRN',chance=100,parts={'FIRE_PUNCH'}},
    SPLISHY_SPLASH={number=730,type='WATER',category='special',status='PAR',chance=30,target=11,parts={'BUBBLEBEAM'}},
    ZIPPY_ZAP={number=729,type='ELECTRIC',category='physical',power=50,priority=2,contact=true,parts={'THUNDERPUNCH'}},
    BADDY_BAD={number=737,type='DARK',category='special',screen='REFLECT',flag='reflect',parts={'NIGHT_SHADE','REFLECT'}},
    GLITZY_GLOW={number=736,type='PSYCHIC_TYPE',category='special',screen='LIGHT_SCREEN',flag='lightScreen',parts={'PSYBEAM','LIGHT_SCREEN'}},
    SAPPY_SEED={number=738,type='GRASS',category='physical',seed=true,parts={'VINE_WHIP','LEECH_SEED'}},
  }
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function say(ctx,rows)for _,message in ipairs(rows or{})do ctx.battle:sayNext(message)end end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and r and r.mode~='off'and r.activeEpoch>=1 and r.activeEpoch<=7 then return r.activeEpoch end
  end
  function M.afterHit(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move
    local gen=M.epoch(b);local s=m and specs[m.id]
    if not gen or not s or m.backendMoveOwner~=M.OWNER or u.mon.hp<=0 then return end
    if s.drain then
      return b.data.move_effects.DRAIN_HP_EFFECT.afterDamage(ctx)
    elseif s.screen then
      local applied
      if gen==1 then
        applied=not u[s.flag];u[s.flag]=true
      else
        applied=mod.exports.pokemonScreens67.cast({battle=b,user=u,target=u,move=b.data.moves[s.screen]})
      end
      if applied then b:sayNext(tr('A protective screen appeared!','Ein Schutzschild wurde errichtet!'))end
      return
    end
    if t.mon.hp<=0 or t.substituteHP or ctx.brokeSub then return end
    if s.seed then
      -- This is an on-hit primary, not a Sheer Force/Shield Dust secondary.
      if t.leechSeeded then return end
      for _,typ in ipairs(t.curTypes or{})do if typ=='GRASS'then return end end
      say(ctx,b.data.move_effects.LEECH_SEED_EFFECT.run(ctx))
    elseif s.status then
      if m.type=='FIRE'and t.mon.status=='FRZ'then
        mod.exports.pokemonCleansingHits67.cure(b,t)
        b:sayNext(tr('%s thawed out!','%s ist aufgetaut!'):format(t.name));return
      end
      -- Infiltrator's shared move scope masks this flag when appropriate.
      -- Safeguard blocks new status, not damage, thawing or Leech Seed.
      if gen>=2 and t.safeguard then return end
      local chance=mod.exports.pokemonAbilityEffects67.secondaryChance(ctx,s.chance)
      if ctx.rng(1,100)<=chance then
        say(ctx,ctx.inflict(t,s.status,{source=m.id,moveType=m.type,secondary=true,kascStatusSource67=u}))
      end
    end
  end
  for _,id in ipairs({'BOUNCY_BUBBLE','BUZZY_BUZZ','SIZZLY_SLIDE','SPLISHY_SPLASH','ZIPPY_ZAP','BADDY_BAD','GLITZY_GLOW','SAPPY_SEED'})do
    local s=specs[id];local f=assert(opts.facts.move(id,7))
    assert(f.number==s.number and f.type==s.type and f.category==s.category and f.power==(s.power or 90)
      and f.accuracy==100 and f.pp==15 and f.priority==(s.priority or 0)and f.target==(s.target or 10),'partner source drift '..id)
    if s.drain then assert(f.meta.drain==50,'Gen VII drain must be half')end
    if id=='ZIPPY_ZAP'then assert(f.meta.crit_rate==6 and #f.statChanges==0,'Gen VII Zippy Zap must crit, not boost evasion')end
    assert(not mod.content.moves:get(id),'foreign partner move '..id)
    local effect='KA_PARTNER_HITS_67_'..id
    mod.content.move_effects:register(effect,{kind='full',afterDamage=M.afterHit,kascPartnerHits67=M.OWNER})
    mod.content.moves:register(id,{id=id,name=tr(f.names.en,f.names.de),type=f.type,category=f.category,
      power=f.power,accuracy=100,pp=15,priority=f.priority,target=f.target,contact=s.contact==true,
      effect=effect,originGeneration=7,backendMoveNumber=s.number,backendMoveOwner=M.OWNER,
      backendLearnsetRevision=23,anim=copy(assert(mod.content.moves:get(s.parts[1])).anim)})
    local anim={seq={},source=M.OWNER}
    for _,part in ipairs(s.parts)do
      for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do anim.seq[#anim.seq+1]=copy(step)end
    end
    mod.content.battle_anims:register(id,anim)
  end
  M.specs=specs
  -- Native Gen-I effect OAM assumes the old battle layout. In the 2D
  -- split-Special HUD its lower bubbles/fists overlap the name or textbox.
  -- Move only copies of visible effect tiles, never Pokemon or source OAM.
  local Player=require('src.battle.AnimPlayer')
  local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
  function M.inHud(s)
    local x,y=s.x-8,s.y-16
    for _,r in ipairs(hud)do
      if x<r[3]and x+8>r[1]and y<r[4]and y+8>r[2]then return true end
    end
    return false
  end
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not specs[id]or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do
      local sprites={}
      for i,s in ipairs(step.sprites or{})do
        local moved=copy(s)
        if s.x>0 and s.x<168 and s.y>=16 and s.y<144 then moved.y=s.y-16 end
        -- The native renderer draws effect tiles after its HUD. Occlude
        -- only our copied OAM where HUD/text tiles must remain on top.
        if moved.x>0 and moved.x<168 and moved.y>0 and moved.y<160 and M.inHud(moved)then moved.x=0 end
        sprites[i]=moved
      end
      step.sprites=sprites
    end
  end
  Player._kascPartnerHitsAnimation67=M
  if not Player._kascPartnerHitsAnimationWrapped67 then local start=Player.start
    Player.start=function(self,id,side,...)
      local result=start(self,id,side,...);Player._kascPartnerHitsAnimation67.position(self,id);return result
    end
    Player._kascPartnerHitsAnimationWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-drain-status-screens-seed-critical',
      providerStatus='generation-seven-partner-attacks',buildReceiptId='docs/PARTNER_HITS_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
