-- Transform's copied identity is battle-local, never a mutation of mon.species.
-- Native checkpoints keep field tokens and the detached Transform move list.
return function(mod,opts)
  local M={OWNER='kasc.battle-identity/v1',CARD_ID='KASC-67-BATTLE-IDENTITY'}
  local B=require('src.battle.BattleState')
  local departed=setmetatable({},{__mode='k'})
  local drawing=setmetatable({},{__mode='k'})
  local visuals=setmetatable({},{__mode='k'})
  function M.rendering(b)return drawing[b]~=nil end
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local lookFields={shiny=true,dvs=true,_kascGender67=true,backendKey=true,
    _ascMegaForm=true,ascMegaForm=true,form=true,formId=true}
  local function captureLook(mon)
    local look={};for k in pairs(lookFields)do look[k]=copy(mon[k])end;return look
  end
  local function validLook(look)
    if type(look)~='table'then return false end
    for k,v in pairs(look)do
      if not lookFields[k]then return false end
      if k=='shiny'then if type(v)~='boolean'then return false end
      elseif k=='dvs'then
        if type(v)~='table'then return false end
        for stat,n in pairs(v)do
          if not({hp=true,attack=true,defense=true,speed=true,special=true,specialAttack=true,specialDefense=true})[stat]
              or type(n)~='number'or n%1~=0 or n<0 or n>31 then return false end
        end
      elseif k=='_kascGender67'then
        if type(v)~='table'or v.schema~='kasc.backend-gift-gender/v1'
            or type(v.originKey)~='string'or #v.originKey>100
            or(v.gender~='MALE'and v.gender~='FEMALE')then return false end
        for field in pairs(v)do if field~='schema'and field~='originKey'and field~='gender'then return false end end
      elseif type(v)~='string'or #v>100 then return false end
    end
    return true
  end
  M.captureLook=captureLook
  M.validLook=validLook
  local function side(b,w)return w==b.player and 'player' or w==b.enemy and 'enemy' or nil end
  local function rows(b,create)
    if create then b.field=b.field or {};b.field.tokens=b.field.tokens or {}end
    local t=b and b.field and b.field.tokens
    if create and not t[M.OWNER]then t[M.OWNER]={}end
    return t and t[M.OWNER]
  end
  function M.transformed(w)
    return w and w.mon and type(w.curMoves)=='table' and w.curMoves~=w.mon.moves or false
  end
  function M.current(b,w)
    if not(w and w.mon)then return end
    if not M.transformed(w)then return w.mon.species end
    local t=rows(b);local key=b and side(b,w);local r=t and key and t[key]
    -- An old checkpoint may preserve copied moves without the copied species.
    -- Do not invent it from move names, sprites or the opposing active Pokémon.
    if r and r.original==w.mon.species then return r.copied end
  end
  function M.copiedAbility(b,w)
    local t=rows(b);local key=b and w and side(b,w);local r=key and t and t[key]or not key and departed[w]
    if r and r.original==w.mon.species and M.transformed(w)and r.ability~=nil then
      return r.ability,true
    end
    return nil,false
  end
  function M.formKey(b,w)
    local forms=mod.exports and mod.exports.pokemonHPForms67
    if not M.transformed(w)then return forms and forms.currentKey(b,w)end
    local t=rows(b);local key=side(b,w)
    if not key and w and w.mon then
      key=b.player.mon==w.mon and'player'or b.enemy.mon==w.mon and'enemy'or nil
    end
    local r=key and t and t[key]
    return r and r.original==w.mon.species and r.hpForm or nil
  end
  function M.visualMon(b,w)
    local t=rows(b);local key=b and side(b,w);local row=key and t and t[key]
    if not(row and row.look and M.transformed(w)and row.original==w.mon.species)then return w.mon end
    local cached=visuals[w];if cached and cached.row==row then return cached.mon end
    local mon=copy(w.mon)
    for k in pairs(lookFields)do mon[k]=copy(row.look[k])end
    mon.species=row.copied
    local forms=mod.exports and mod.exports.pokemonHPForms67
    if forms and row.hpForm then forms.bindVisual(mon,row.hpForm)end
    visuals[w]={row=row,mon=mon}
    return mon
  end
  -- Cosmetic disguise is presentation only. Semantic consumers such as
  -- weight/Transform continue to use visualMon/current/formKey above.
  function M.presentationMon(b,w)
    local illusion=mod.exports and mod.exports.pokemonIllusion67
    return illusion and illusion.visualMon(b,w)or M.visualMon(b,w)
  end
  function M.resume(b)
    for _,w in ipairs({b.player,b.enemy})do
      local visual=M.visualMon(b,w)
      if visual~=w.mon then
        w.__ascendantCrystalTransformed=visual.species;w.__ascendantCrystalAnimation=nil
        w.sprite=B.makeBattler(b.data,visual,w.isPlayer).sprite
      end
    end
  end
  function M.validateCheckpoint(b)
    local t=rows(b);if t==nil then return true end
    if type(t)~='table'then return false,'invalid_battle_identity_tokens'end
    for key,r in pairs(t)do
      if key~='player' and key~='enemy'then return false,'invalid_battle_identity_side'end
      local w=b[key]
      if type(r)~='table' or not w or not w.mon or r.original~=w.mon.species
          or not M.transformed(w) or not b.data.pokemon[r.copied]then
        return false,'invalid_battle_identity_record'
      end
      local abilities=mod.exports and mod.exports.pokemonAbilityEffects67
      if r.ability~=nil and (not abilities or not abilities.validCopiedAbility(r.ability))then
        return false,'invalid_copied_ability'
      end
      if r.look~=nil and not validLook(r.look)then return false,'invalid_copied_appearance'end
      if r.hpForm~=nil then
        local forms=mod.exports and mod.exports.pokemonHPForms67
        if not forms or not forms.validForm(r.copied,r.hpForm)then return false,'invalid_copied_hp_form'end
      end
      for field in pairs(r)do
        if field~='original' and field~='copied'and field~='ability'and field~='look'and field~='hpForm'then return false,'unknown_battle_identity_field'end
      end
    end
    return true
  end
  function M.clear(b,w)
    local t=rows(b);if not t then return end
    if w then local key=side(b,w);if key then t[key]=nil end
    else b.field.tokens[M.OWNER]=nil end
  end
  local record=assert(mod.content.move_effects:get('TRANSFORM_EFFECT'))
  local original=assert(record.run)
  function M.transform(ctx)
    local b,w=ctx.battle,ctx.user
    local r=b and b.kascGenerationRulesReceipt
    local enabled=b and not b.demo and b.kind~='link' and not b.result
      and r and r.mode~='off' and (tonumber(r.activeEpoch)or 1)>=2 and side(b,w)
    local gen=enabled and tonumber(r.activeEpoch)or 1
    if enabled and (not ctx.target or ctx.target==w or ctx.target.mon.hp<=0 or w.mon.hp<=0
        or M.transformed(ctx.target)or gen>=5 and (M.transformed(w)or ctx.target.substituteHP~=nil)
        or w.illusion or ctx.target.illusion)then
      local tr=opts.i18n and opts.i18n.text or function(en)return en end
      return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}
    end
    local species=enabled and M.current(b,ctx.target)
    local abilities=mod.exports and mod.exports.pokemonAbilityEffects67
    local copiedAbility
    if enabled and (tonumber(r.activeEpoch)or 1)>=3 and abilities then
      copiedAbility=abilities.abilityIdentity(b,ctx.target)
    end
    local before=w.curMoves
    -- The native Gen-I helper deliberately uses a gray palette and no mon.
    -- Later rules need the target's actual shiny/gender/form context instead.
    -- A transient copy is given to the art resolver, never the stored Ditto.
    local look=enabled and captureLook(ctx.target.mon)
    local forms=mod.exports and mod.exports.pokemonHPForms67
    local hpForm=enabled and forms and forms.currentKey(b,ctx.target)
    if enabled then drawing[b]={target=ctx.target,side=w.isPlayer}end
    local ok,result=pcall(original,ctx);drawing[b]=nil
    if not ok then error(result,0)end
    if enabled and w.curMoves~=before and M.transformed(w)then
      M.clear(b,w)
      if forms then forms.detach(b,w)end
      for _,slot in ipairs(w.curMoves)do
        local move=b.data.moves[slot.id]
        slot.pp=math.min(5,move and tonumber(move.pp)or 5)
      end
      local healing=mod.exports and mod.exports.pokemonHealingMoves67
      if healing then w.curTypes=healing.typesForTransform(b,ctx.target)end
      if gen>=6 then w.focusEnergy=ctx.target.focusEnergy end
      local laser=mod.exports and mod.exports.pokemonLaserFocus67
      if gen>=7 and laser then laser.copyFrom(b,w,ctx.target)end
      if species and b.data.pokemon[species]then
        rows(b,true)[side(b,w)]={original=w.mon.species,copied=species,ability=copiedAbility,look=look,hpForm=hpForm or nil}
        w.__ascendantCrystalTransformed=species;w.__ascendantCrystalAnimation=nil
        local visual=M.visualMon(b,w)
        local pic=B.makeBattler(b.data,visual,w.isPlayer).sprite
        if pic then b:actNext(function()w.sprite=pic;w.__ascendantCrystalAnimation=nil end)end
        local control=mod.exports and mod.exports.pokemonAbilityControl67
        if control then control.transformed(b,w)end
        local hidden=mod.exports and mod.exports.pokemonHiddenPower67
        if hidden then hidden.transformed(b,w,ctx.target)end
        local changing=mod.exports.pokemonTypeChanges67
        if changing then changing.transformed(b,w,ctx.target)end
        local body=mod.exports.pokemonBodyUtilities67
        if body then body.transformed(b,w,ctx.target)end
        if copiedAbility~=nil then abilities.transformedAbilityChanged(b,w)end
      end
    end
    return result
  end
  B._kascIdentityArt67=M
  function M.speciesSprite(b,species,isPlayer,original)
    local ctx=drawing[b]
    if ctx and ctx.side==isPlayer and ctx.target.mon.species==species then
      local visual=copy(ctx.target.mon)
      local forms=mod.exports and mod.exports.pokemonHPForms67
      if forms then forms.bindVisual(visual,forms.currentKey(b,ctx.target))end
      return B.makeBattler(b.data,visual,isPlayer).sprite
    end
    return original(b,species,isPlayer)
  end
  if not B._kascIdentityArtWrapped67 then
    local originalSprite=B.speciesSprite
    B.speciesSprite=function(b,species,isPlayer)
      return B._kascIdentityArt67.speciesSprite(b,species,isPlayer,originalSprite)
    end
    B._kascIdentityArtWrapped67=true
  end
  mod.content.move_effects:patch('TRANSFORM_EFFECT',{kascBattleIdentity67=M.OWNER,run=M.transform})
  -- Withdrawal callbacks run after the host installs the replacement. Keep
  -- the outgoing object's identity until those callbacks have inspected it.
  mod.events:on('battle.battler_switched',function(ev)
    local b,old,w=ev.battle,ev.previous,ev.battler
    local t=rows(b);local key=b and w and side(b,w);local r=t and key and t[key]
    if old and old~=w and r and r.original==old.mon.species and M.transformed(old)then departed[old]=r end
  end,50000)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  return M
end
