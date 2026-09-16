-- Spotlight has no redirection effect in a singles battle, by source rules.
-- Register the real move and its legitimate failure, without a fake volatile.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-SPOTLIGHT',OWNER='kasc.spotlight/v1',ID='SPOTLIGHT'}
  local effect='KA_SPOTLIGHT_67';local tr=opts.i18n.text
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  function M.active(b,move)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch>=1 and r.activeEpoch<=7
      and move and move.id==M.ID and move.backendMoveOwner==M.OWNER
      and marker and marker.kascSpotlight67==M.OWNER
  end
  function M.noUseful(b,user,target,move)return M.active(b,move)end
  function M.cast(ctx)
    -- This engine resolves one selected opposing battler. It exposes no
    -- FoeRedirectTarget event or multi-active target selector. An invented
    -- activePerHalf flag must not turn this into a successful effect.
    return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}
  end
  local f=assert(opts.facts.move(M.ID,7))
  assert(f.number==671 and f.generation==7 and f.type=='NORMAL'and f.category=='status'
    and f.power==0 and f.pp==15 and f.accuracy==100 and f.alwaysHits
    and f.priority==3 and f.target==10,'Spotlight source drift')
  assert(not mod.content.moves:get(M.ID),'foreign Spotlight owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascSpotlight67=M.OWNER,run=M.cast})
  mod.content.moves:register(M.ID,{id=M.ID,name=tr(f.names.en,f.names.de),type='NORMAL',category='status',power=0,
    accuracy=100,pp=15,priority=3,target=10,effect=effect,originGeneration=7,backendMoveNumber=671,
    backendMoveOwner=M.OWNER,backendLearnsetRevision=34,anim=copy(assert(mod.content.moves:get('FOCUS_ENERGY')).anim)})
  local anim=copy(assert(mod.content.battle_anims:get('FOCUS_ENERGY')));anim.source=M.OWNER
  mod.content.battle_anims:register(M.ID,anim)
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if id~=M.ID or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local shift=-16;local sprites={}
      for _,s in ipairs(step.sprites or{})do
        if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end
      end
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        if mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  Player._kascSpotlightAnimation67=M
  if not Player._kascSpotlightAnimationWrapped67 then local start=Player.start
    Player.start=function(self,id,...)
      local result=start(self,id,...);Player._kascSpotlightAnimation67.position(self,id);return result
    end;Player._kascSpotlightAnimationWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-single-target-resolution',
      providerStatus='source-correct-singles-failure',buildReceiptId='docs/SPOTLIGHT_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
