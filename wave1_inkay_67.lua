-- KASC desktop/mobile equivalent of turning the console upside down.
-- An explicit per-Pokémon Equipment switch, never an automatic level shortcut.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-INKAY',ready=false,pending={}}
  local S=assert(opts.species);local reg=mod.content.pokemon
  local method,field='KA_WAVE1_INVERTED_LEVEL','_kascInkayInverted67'
  local parent,target=S.byKey['dex:686'],S.byKey['dex:687']
  for _,dex in ipairs({686,687})do
    local id=S.byKey['dex:'..dex];local def=id and reg:get(id)
    if id~='KA_GIFT_NAT_'..dex or not def or def.backendOwner~=S.OWNER
        or def.backendKey~='dex:'..dex or def.sourceDex~=dex or def.form or def.formId
        or def.baseSpecies or def.isMega or def.isGigantamax then
      C.pending[#C.pending+1]='identity:'..dex
    end
  end
  local def=parent and reg:get(parent)
  if def and #(def.evolutions or {})>0 then C.pending[#C.pending+1]='existing_edges'end
  if mod.content.evolution_methods:get(method)then C.pending[#C.pending+1]='method_owner'end
  if not opts.rules or type(opts.rules.safeBoundary)~='function'then
    C.pending[#C.pending+1]='boundary_owner'
  end
  if #C.pending>0 then return C end
  local tr=opts.i18n.text
  local function body(mon)
    return type(mon)=='table' and mon.species==parent
      and not mon.form and not mon.formId and not mon.baseSpecies
      and not mon._ascMegaForm and not mon.ascMegaForm
      and not mon.cosmeticForm and not mon.cosmeticFormId
      and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
      and type(mon.level)=='number' and mon.level==math.floor(mon.level)
      and mon.level>=1 and mon.level<=100
  end
  local function member(game,mon)
    local n=0
    for _,m in ipairs(game and game.save and game.save.party or {})do if m==mon then n=n+1 end end
    return n==1
  end
  local function state(mon)
    if mon[field]==nil then return false end
    local value=mon[field]
    if type(value)=='table' and value.version==1 and value.enabled==true then return true end
  end
  local function exact(mon,evo)
    return body(mon) and type(evo)=='table' and evo.method==method and evo.species==target
      and evo.level==30 and not evo.item and not evo.move and not evo.partySpecies
  end
  mod.content.evolution_methods:register(method,{
    check=function(game,mon,evo,trigger)
      return C.ready and exact(mon,evo) and member(game,mon) and state(mon)==true
        and mon.level>=30 and mon.item~='EVERSTONE' and mon.heldItem~='EVERSTONE'
        and not(mon.item and mon.heldItem and mon.item~=mon.heldItem)
        and trigger and trigger.kind=='levelup' or false
    end,
    describe=function()return tr('Level up from 30 with HEADSTAND enabled in Equipment',
      'Levelaufstieg ab 30 mit KOPFSTAND in Ausrüstung')end,
  })
  reg:patch(parent,{evolutions={{method=method,species=target,level=30}}})
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    local archive=mod.exports and mod.exports.eventArchive
    if C.ready and exact(mon,evo) and member(game,mon) and archive then
      local valid,_,p=archive.battleCompatibleGift(mon)
      if valid and p and p.backendKey=='dex:686' and p.species==parent
          and not p.formId and not p.baseSpecies and not p.megaFormId and not p.gigantamaxFormId then return true end
    end
    return previous and previous(game,mon,evo) or false
  end
  function C.choice(game,mon)
    if not C.ready or not body(mon) or not member(game,mon) or state(mon)==nil then return end
    return {label=tr('HEADSTAND','KOPFSTAND'),value='inkay_invert',enabled=state(mon),
      right=state(mon) and tr('ON','AN') or tr('OFF','AUS'),
      help=tr('KASC: ON replaces turning the console. Then level up to 30 or higher. Everstone blocks evolution.',
        'KASC: AN ersetzt das Umdrehen. Danach auf Level 30 oder höher steigen. Ewigstein blockiert.')}
  end
  local busy=setmetatable({},{__mode='k'})
  function C.setInverted(game,mon,enabled,expected)
    if type(enabled)~='boolean' or type(expected)~='boolean'then return false,'invalid_request'end
    if not C.choice(game,mon)then return false,'command_not_allowed'end
    if state(mon)~=expected then return false,'stale_revision'end
    if busy[game]then return false,'transaction_busy'end
    local safe,why=opts.rules.safeBoundary(game)
    if not safe then return false,why or 'transaction_active'end
    if type(game.writeSave)~='function'then return false,'save_unavailable'end
    if enabled==expected then return true end
    local old=mon[field];mon[field]=enabled and {version=1,enabled=true} or nil
    busy[game]=true;local ok,wrote=pcall(game.writeSave,game);busy[game]=nil
    if not ok or wrote~=true then mon[field]=old;return false,'setting_save_failed'end
    return true
  end
  mod.events:on('pokemon.evolved',function(ev)
    if ev and ev.via==method and ev.fromSpecies==parent and ev.toSpecies==target
        and ev.mon and ev.mon.species==target then ev.mon[field]=nil end
  end,900)
  C.ready=true;C.method=method;C.field=field;C.parent=parent;C.target=target;return C
end
