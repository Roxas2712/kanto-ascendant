-- KASC discovery fallback. VASC owns the graphical screen when available;
-- its maximum-catalogue adapter retains later discoveries and national numbers.
-- Native/off/Gen2 screens stay native.
return function(mod,opts)
  local D,M=assert(opts.dex),assert(opts.maximum)
  local S={CARD_ID='KASC-WAVE1-MAXIMUM-DEX-SURFACE'}
  local Screens=require('src.ui.Screens')
  local function tr(en,de)return opts.i18n and opts.i18n.text(en,de) or en end
  local function list(game,title,rows,args)
    return (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,title,rows,args)
  end
  function S.active(game)
    local version=require('src.core.GameVersion').get()
    return D.game==game and (version=='red' or version=='blue' or version=='yellow')
  end
  local function graphicalProvider()
    if type(mod.find) ~= 'function' then return nil end
    local ok, vasc=pcall(mod.find,'VOXEL_ASCENDANT')
    if not ok or not vasc then ok,vasc=pcall(mod.find,mod,'VOXEL_ASCENDANT')end
    local provider=ok and vasc and vasc.exports and vasc.exports.modernDex
    return type(provider)=='table' and provider.active==true and provider or nil
  end
  function S.needed(game)
    if not S.active(game)then return false end
    local provider=graphicalProvider()
    if provider and type(provider.mode)=='function' and provider.mode()=='game' then
      return false
    end
    for _,row in ipairs(M.discovered(game,{}))do
      if row.number>411 then return true end
    end
    return false
  end
  function S.fitMenu(menu)
    local update=menu.update
    if type(update)=='function' and not menu.__kascDexScroll67 then
      menu.__kascDexScroll67=true
      menu.update=function(self,...)
        local geometry=self.__vascOrasGeometry
        if geometry and type(geometry.rows)=='number' and geometry.rows>=1 then
          self.__vascOrasRows=geometry.rows
          self.cursorRows=geometry.rows
        end
        return update(self,...)
      end
    end
    return menu
  end
  function S.new(game,args)
    args=args or {}
    local provider=graphicalProvider()
    if provider and provider.maximumCatalogue and type(provider.build)=='function' then
      local ok,page=pcall(provider.build,game,args)
      if ok and type(page)=='table' then return page end
    end
    local native=require('src.ui.PokedexMenu').new(game)
    local rows={}
    for _,row in ipairs(native.items)do
      rows[#rows+1]={label=row.label,value=row.value,
        right=row.ball and tr('OWNED','ERHALTEN') or row.value and tr('SEEN','GESEHEN') or nil,
        help=row.value and ((game.data.pokemon[row.value].name or '') .. '\n'
          .. tr('A: data, cry or habitat.','A: Daten, Ruf oder Fundort.'))
          or tr('Not discovered yet.','Noch nicht entdeckt.')}
    end
    if #rows==0 then rows[1]={label=tr('NO DISCOVERIES','KEINE ENTDECKUNGEN')} end
    local menu=list(game,tr('DISCOVERY DEX','ENTDECKERDEX'),rows,{
      footer=native.footer,pageJump=true,onCancel=args.onCancel,
      onChoose=function(item)
        if not item.value then return end
        local id=item.value
        local actions={
          {label=tr('DATA','DATEN'),value='data'},
          {label=tr('CRY','RUF'),value='cry'},
          {label=tr('AREA','FUNDORT'),value='area'},
          {label=tr('BACK','ZURÜCK'),value='back'},
        }
        game.stack:push(list(game,game.data.pokemon[id].name,actions,{
          onChoose=function(action)
            if action.value=='data' then Screens.push(game,'DexEntryMenu',id)
            elseif action.value=='cry' then require('src.core.Sound').playCry(game.data,id)
            elseif action.value=='area' then Screens.push(game,'TownMap',{nestSpecies=id})
            elseif action.value=='back' then game.stack:pop()end
          end,
        }))
      end,
    })
    menu.__kascMaximumDex67=true
    return S.fitMenu(menu)
  end
  function S.project(page,game)
    if not (page and page.def and page.def.id)then return page end
    page.def=M.entryDefinition(page.def.id,page.def)
    if page.__vascModernDexEntry and not (page.all and page.all.maximumCatalogue)
        and not page.__kascMaximumDexEntry67 then
      local original=page.setSpecies
      page.setSpecies=function(self,id,...)
        local result=original(self,id,...)
        if self.def then self.def=M.entryDefinition(self.def.id,self.def)end
        return result
      end
      -- Native VASC left/right must not fall back to private runtime slots
      -- or expose unknown regional placeholders from its four-region list.
      page.rows={}
      for _,row in ipairs(M.discovered(game,{}))do
        page.rows[#page.rows+1]={id=row.species,dex=row.number,
          def=M.entryDefinition(row.species,row.definition),seen=true,
          owned=game.save.pokedex.owned[row.species]==true}
        if row.species==page.species then page.position=#page.rows end
      end
      page.__kascMaximumDexEntry67=true
    end
    return page
  end
  function S.install()
    local patch=rawget(Screens,'_kascMaximumDex67')
    if not patch then
      patch={build=Screens.build,push=Screens.push}
      Screens._kascMaximumDex67=patch
      local function intercept(kind,game,id,...)
        local owner=patch.owner
        if owner and id=='PokedexMenu' and owner.needed(game) then
          local page=owner.new(game,...);page.screenId=id
          if kind=='push' then game.stack:push(page)end
          return page
        end
        local page=patch[kind](game,id,...)
        if owner and owner.active(game) and id=='DexEntryMenu' then owner.project(page,game)end
        return page
      end
      if type(patch.build)=='function' then
        Screens.build=function(game,id,...)return intercept('build',game,id,...)end
      end
      Screens.push=function(game,id,...)return intercept('push',game,id,...)end
    end
    patch.owner=S
  end
  return S
end
