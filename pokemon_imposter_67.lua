-- Entry-only Transform without a move/AP action. The attempt is checkpointed;
-- un-suppressing an ability or resuming a turn is not another switch-in.
return function(mod,opts)
  local M={CARD_ID='KASC-67-IMPOSTER',OWNER='kasc.imposter/v1'}
  local B=require('src.battle.BattleState');local A=opts.abilities;local I=opts.identity
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.tryEntry(b,w)
    if not b or not w then return false end
    local gen=opts.status.epoch(b);local key=side(b,w)
    if getmetatable(b)~=B or b.result or b.demo or b.kind=='link'or not gen or gen<5 or gen>7
        or not key or not w.mon or w.mon.hp<=0 or A.abilityIdentity(b,w)~='IMPOSTER'then return false end
    local r=rows(b,true);if r[key]then return false end;r[key]=true
    if A.activeAbility(b,w)~='IMPOSTER'then return false end
    local target=key=='player'and b.enemy or b.player
    local messages=I.transform({battle=b,user=w,target=target,move=b.data.moves.TRANSFORM,rng=b.rng})
    if not messages or messages.failed or not I.transformed(w)then return false end
    b:sayNext(opts.i18n.text('Imposter activated!','Doppelgänger aktiviert!'))
    for _,text in ipairs(messages)do b:sayNext(text)end
    b:drainNext();return true
  end
  function M.validateCheckpoint(b)
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_imposter_attempts'end
    for k,v in pairs(r)do if (k~='player'and k~='enemy')or v~=true then return false,'invalid_imposter_attempt'end end
    return true
  end
  mod.events:on('battle.battler_switched',function(ev)
    local r=rows(ev.battle);local key=side(ev.battle,ev.battler);if r and key then r[key]=nil end
  end,8000)
  mod.events:on('battle.ended',function(ev)if rows(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end end,80)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascImposter67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-transform-identity-ability-entry-order',
      providerStatus='entry-only-generation-v-vii',buildReceiptId='docs/IMPOSTER_IMPLEMENTATION_NOTES_20260914.md',
      rollbackReceiptId='docs/IMPOSTER_IMPLEMENTATION_NOTES_20260914.md'})
  end
  return M
end
