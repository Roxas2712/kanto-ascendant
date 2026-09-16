-- Local presentation card: no VASC installation and no save migration required.
-- Vendor modules receive only KASC's loader/UI capability, never VASC gameplay.
return function(mod, i18n)
  local context, loaded = {mod=mod}, {}
  function context.require(name)
    assert(name:match('^[%w_]+$'), 'invalid UI module')
    if loaded[name] then return loaded[name] end
    local body=assert(mod:read('lib/kasc_ui/'..name..'.lua'))
    local chunk=assert(loadstring(body,'@kasc-ui/'..name))
    loaded[name]=chunk(context)
    return loaded[name]
  end
  local style=context.require('VascMenuStyle').new(mod, {
    skin='oras_fullscreen',
    language=function() return i18n.isGerman() and 'de' or 'en' end,
  })
  local card={schema='kanto-ascendant/consumer-card/v1',
    id='kasc.presentation.fullscreen',version='1.0.0',owner=mod.id,
    requires={},saveWrites={},style=style}
  function card.usesVasc(game)
    local exports=game and game.mods and game.mods.exports
    if exports and exports.VOXEL_ASCENDANT then return true end
    if type(mod.find)=='function' then
      local ok,found=pcall(mod.find,'VOXEL_ASCENDANT')
      if not ok then ok,found=pcall(mod.find,mod,'VOXEL_ASCENDANT') end
      return ok and type(found)=='table' and type(found.exports)=='table'
    end
    return false
  end
  -- Some loaders initialize KASC before VASC. Resolve the owner when hooks
  -- run too, not only at installation; a later VASC load must remain sole UI.
  local localMod=setmetatable({}, {__index=mod})
  localMod.events={on=function(_,name,callback,priority)
    return mod.events:on(name,function(event)
      if not card.usesVasc(event and event.game) then return callback(event) end
    end,priority)
  end}
  localMod.hooks={wrap=function(_,name,callback,priority)
    return mod.hooks:wrap(name,function(nextCall,...)
      if card.usesVasc() then return nextCall(...) end
      return callback(nextCall,...)
    end,priority)
  end}
  context.mod=localMod
  function card.decorateMenu(menu,provider,rows)
    if card.usesVasc(menu and menu.game) then
      local exports=menu and menu.game and menu.game.mods and menu.game.mods.exports
      local vasc=exports and exports.VOXEL_ASCENDANT
      if not vasc and mod.find then local ok,found=pcall(mod.find,'VOXEL_ASCENDANT');vasc=ok and found and found.exports end
      local bridge=vasc and vasc.ascendantMenuSkin
      if bridge and bridge.decorateGuided then return bridge.decorateGuided(menu,provider,rows) end
      return menu
    end
    return style.bridgeFocusHelp(menu,provider,rows)
  end
  function card.guidedList(game,spec)
    if card.usesVasc(game) then return mod.exports.ascendantUi.guidedList(game,spec) end
    return style.guidedList(game,spec)
  end
  function card.decorateOptions(state)
    if state.__kascFullscreenOptions then return end
    local projection={game=state.game,title=i18n.isGerman() and 'OPTIONEN' or 'OPTIONS',
      index=state.index,scroll=state.scroll,items={},draw=function()end,update=function()end}
    local function refresh()
      projection.index,projection.scroll=state.index,state.scroll
      projection.items={}
      for index,row in ipairs(state.view or state.rows) do
        local value=type(row.value)=='function' and row.value(state.game) or ''
        projection.items[index]={label=row.label,value=row.id or index,right=value,
          help=row.help or (tostring(row.label or '')..'\n'..tostring(value))}
      end
      projection.items[#projection.items+1]={label=i18n.isGerman() and 'ZURÜCK' or 'BACK'}
    end
    refresh()
    style.bridgeFocusHelp(projection,function(item)return item and (item.help or item.label) or '' end,5)
    state.__kascFullscreenOptions=true
    state.draw=function()refresh();return projection:draw()end
    state.uiSize=function()return projection:uiSize()end
    state.sgbPalettes=function()return projection:sgbPalettes()end
    state.drawsWidescreen=function()return true end
  end
  function card.drawStorage(state,party,boxCursor,partyCursor,carry,header,footer)
    if card.usesVasc(state.game) or not card.party then return false end
    local view={game=state.game,view=party and 'party' or 'box',context='storage',
      language=i18n.isGerman() and 'de' or 'en',boxCursor=boxCursor or 1,
      partyCursor=partyCursor or 1,boxHeaderFocus=header,stripFocus=false,
      held=carry and {kind=carry.zone,index=carry.index,mon=carry.mon,box=carry.box},
      toast=state.message and {text=state.message,timer=1}}
    card.party.draw(view)
    -- The source renderer's search affordance is not offered by this host.
    -- Keep this controller's real input legend, never promise phantom actions.
    love.graphics.setColor(.81,.89,.94,1)
    love.graphics.rectangle('fill',16,257,480,29)
    love.graphics.setColor(1,1,1,1)
    require('src.render.Font').draw(footer or 'A:SELECT  B:BACK',24,266)
    return true
  end
  function card.install()
    if card.installed then return true end
    if card.usesVasc() then card.reason='vasc-owner';card.active=false;return true end
    local skin=context.require('OrasUiSkin')
    local ok,reason=skin.install({mod=localMod,bagSkin=context.require('OrasBagSkin'),
      companionOptionBuckets={}})
    card.installed=ok==true
    card.reason=reason
    if ok then
      card.party=context.require('OrasPartyPresentation')
      local partyOk,partyReason=context.require('PartyMenuSkins').install()
      if not partyOk then return false,partyReason end
      localMod.events:on('screen.pushed',function(event)
        local state=event and event.state
        if type(state)=='table' and (state.screenId=='OptionsMenu'
            or getmetatable(state)==require('src.ui.OptionsMenu')) then
          card.decorateOptions(state);return
        end
        if type(state)~='table' or type(state.items)~='table' then return end
        local start=state.screenId=='StartMenu'
        local pc=state.__ascendantFireRedWideBoxRoot or state.__ascendantFireRedWidePcRoot
        if start or pc then
          state.title=state.title or (start and 'KANTO ASCENDANT' or 'POKEMON STORAGE')
          state.__kantoAscendantFocusHelp=true
          state.__kantoAscendantLayout=true
          card.decorateMenu(state,function(item)return item and (item.help or item.label) or '' end,8)
        end
      end,13000)
      card.active=true
    end
    return ok,reason
  end
  return card
end
