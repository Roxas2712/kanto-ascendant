-- Drop-in screen factory for VascPokemonHdDownloads using the existing guided menu.
-- Session owns the shared installer, exact import availability and safe removal service.
local M={SCREEN="VascPokemonHdDownloads"}
function M.new(mod,game,guided,de,session)
  assert(session and session.model and session.removal,"missing unified content session")
  local function tr(en,german)return de and german or en end
  local function push(menu)game.stack:push(menu)end
  local function notice(reason)if session.notice then session:notice(reason)end end
  local function busy()
    local job,err=session.removal:pending()
    return job~=nil or err~=nil or (session.busy and session:busy())
  end
  local function make(key,title,rows,choose,help)
    local builder=type(rows)=='function' and rows or nil
    local menu=guided(mod,game,{key=key,title=title,rows=builder and builder() or rows,help=help or "",
      footer=tr("A:SELECT SEL:HELP B:BACK","A:WAHL SEL:HILFE B:ZURÜCK"),onChoose=choose})
    menu.showFirstGuide=function()return false end
    if builder and menu.items then
      local update,epoch=menu.update,session.epoch
      function menu:update(...)
        if epoch~=session.epoch then
          epoch=session.epoch;local helpRow
          for _,r in ipairs(self.items)do if r.value=='__vasc_help' or r.value=='__kasc_help' then helpRow=r end end
          local fresh=builder();if helpRow then fresh[#fresh+1]=helpRow end
          self.items=fresh;self.index=math.max(1,math.min(self.index or 1,#fresh))
        end
        if update then return update(self,...)end
      end
    end
    return menu
  end
  local function confirmDelete(id,p)
    if busy() then return notice("busy_or_restart_required") end
    local localFiles=p and p.localFiles
    local external=localFiles and not localFiles.checking and localFiles.present>0
    push(make("vasc_content_delete_"..id,tr("DELETE PACKAGE?","PAKET LÖSCHEN?"),{
      {label=tr("CANCEL","ABBRECHEN"),action="cancel"},
      {label=tr("DELETE","LÖSCHEN"),action="delete"}},function(row)
        if row.action=="cancel" then return game.stack:pop() end
        if row.action=="delete" then
          if external then
            local ok,why=session.kascBundledInventory:request(id,true)
            if not ok then return notice(why)end
            local receipt=session.store:receipt(id)
            if receipt or p.cachePartial then
              local removed,err=session.removal:request(id,true)
              if not removed then return notice(err)end
            end
            game.stack:pop()
            return notice(tr('Removal requested. Close the game, run manage-sprites.py from the desktop update bundle, then restart. Local files stay until the helper confirms removal.',
              'Entfernen vorgemerkt. Spiel schliessen, manage-sprites.py aus dem Desktop-Updatepaket starten, dann neu starten. Alte Dateien bleiben bis zur bestaetigten Entfernung durch den Helfer.'))
          end
          local ok,why=session.removal:request(id,true)
          if ok then game.stack:pop() end
          notice(why)
        end
      end,external and tr('Includes old built-in files. The engine cannot delete them in-game. This prepares a desktop helper request with backup; no files are deleted now. Close the game before running the helper.',
        'Enthaelt alte Moddateien. Die Engine kann diese nicht im Spiel loeschen. Bereitet den Desktop-Helfer mit Backup vor; jetzt wird nichts geloescht. Vor dem Helfer das Spiel schliessen.')
        or tr("Deletion happens on restart. Shared files stay. Missing sprites use the original style.",
        "Löschen erfolgt beim Neustart. Gemeinsame Dateien bleiben erhalten. Fehlende Sprites nutzen den Originalstil.")))
  end
  local function packageMenu(p)
    if session.kascBundledInventory then session.kascBundledInventory:prioritize(p.id)end
    local function packageRows()
      for _,group in ipairs(session.model:groups())do for _,fresh in ipairs(group.packages)do if fresh.id==p.id then p=fresh end end end
    local rows={{label=tr("STATUS","STATUS"),right=p.statusLabel,action="status"}}
    if p.localFiles then
      local f=p.localFiles
      rows[#rows+1]={label=tr('OLD MOD FILES','ALTE MODDATEIEN'),right=f.checking and tr('CHECKING','PRUEFUNG') or (f.present..' / '..f.total),
        help=tr('Actual files in this mod. Presence does not claim verified download checksums. Partial sets remain usable and can be completed by a download.',
          'Tatsaechliche Dateien dieser Mod. Vorhandensein ist keine verifizierte Download-Pruefsumme. Teilsammlungen bleiben nutzbar und koennen per Download ergaenzt werden.')}
      local job=session.kascBundledInventory and session.kascBundledInventory:pending()
      if job and job.packageIds[1]==p.id and f.present>0 then
        rows[#rows+1]={label=tr('EXTERNAL REMOVAL PENDING','EXTERNES ENTFERNEN AUSSTEHEND'),action='externalHelp'}
        rows[#rows+1]={label=tr('CANCEL REMOVAL REQUEST','ENTFERNAUFTRAG ABBRECHEN'),action='cancelExternal'}
      end
    end
    if p.installed then
      rows[#rows+1]={label=tr("ALREADY INSTALLED","BEREITS INSTALLIERT"),action="status"}
      local version=p.id:match('^vasc%.sprite%.pokemon%-mega%-original%-20260830%.') and 'original-20260830'
        or p.id:match('^vasc%.sprite%.pokemon%-mega%.') and 'current'
      if version then rows[#rows+1]={label=tr('USE THIS MEGA COLLECTION','DIESE MEGA-SAMMLUNG NUTZEN'),action='megaCollection',version=version}end
    else
      rows[#rows+1]={label=tr("DOWNLOAD","HERUNTERLADEN"),right=string.format("%.1f MiB",p.downloadBytes/1048576),action="download",muted=not p.downloadable}
    end
    rows[#rows+1]={label=tr("CHOOSE FILE / IMPORT","DATEI WÄHLEN / IMPORTIEREN"),action="packageImport"}
    rows[#rows+1]={label=tr("Download keeps failing? Click here.","Download schlägt fehl? Hier klicken."),action="manual"}
    -- Visible even before installation; unused delete explains there's nothing to remove.
    rows[#rows+1]={label=tr("DELETE","LÖSCHEN"),action="delete",muted=not p.canDelete}
    return rows
    end
    push(make("vasc_content_package_"..p.id,p.id,packageRows,function(row)
      if row.action=='externalHelp' then
        return notice(tr('Close the game. Run manage-sprites.py from the update bundle and select this mod and its shared cache. Restart after the helper confirms removal.',
          'Spiel schliessen. manage-sprites.py aus dem Updatepaket starten und diese Mod samt gemeinsamem Cache waehlen. Nach bestaetigter Entfernung neu starten.'))
      elseif row.action=='cancelExternal' then
        local inv=session.kascBundledInventory
        local cached=session.removal:pending()
        if cached and cached.id==p.id then
          local key='sprite-content/removal-pending-v1.json'
          if session.cache:remove(key)~=true or session.cache:read(key)~=nil then return notice('queue_remove_failed')end
        end
        local ok,why=inv:cancel(p.id);session.epoch=session.epoch+1
        return notice(why)
      elseif row.action=='megaCollection' then
        local exports=game.mods and game.mods.exports
        local kasc=exports and exports.kanto_ascendant
        local collections=kasc and kasc.megaSpriteCollections
        if not collections then return notice('kasc_required')end
        local ok,why=collections:select(game,row.version)
        if ok then notice(tr('Mega collection selected.','Mega-Sammlung ausgewaehlt.'))
        elseif why~='sprite_download_required' then notice(why)end
        return
      elseif row.action=="packageImport" then
        if busy() then return notice("busy_or_restart_required")end
        return session:openPackageImport(p.id)
      elseif row.action=="manual" then return session:openManual(p.id,de)
      elseif row.action=="delete" then
        if p.localFiles and p.localFiles.checking then return notice(tr('Checking existing files. Please wait.','Vorhandene Dateien werden geprueft. Bitte warten.'))end
        if not p.canDelete then return notice("not_installed") end
        return confirmDelete(p.id,p)
      elseif row.action=="download" then
        if p.localFiles and p.localFiles.checking then return notice(tr('Checking existing files. Please wait.','Vorhandene Dateien werden geprueft. Bitte warten.'))end
        if busy() then return notice("busy_or_restart_required") end
        if not p.downloadable then return notice("not_yet_available") end
        -- Session opens the existing size-confirmation view, replans at confirmation.
        return session:confirmDownload({p.id})
      end
    end))
  end
  local function groupsMenu(g)
    if g.children then
      local children={};for _,child in ipairs(g.children)do children[#children+1]={label=child.label,group=child,help=child.help}end
      return push(make('vasc_content_category_'..g.id,g.label,children,function(row)if row.group then groupsMenu(row.group)end end,g.help))
    end
    local function rows()
    for _,fresh in ipairs(session.model:groups())do if fresh.id==g.id then g=fresh end end
    local result={}
    for _,p in ipairs(g.packages) do
      local first,last=p.id:match("dex(%d+)%-(%d+)")
      local label=first and (tonumber(first).."-"..tonumber(last)) or p.id
      result[#result+1]={label=label,right=p.statusLabel,package=p,help=g.help}
    end
    return result
    end
    push(make("vasc_content_group_"..g.id,g.label,rows,function(row)if row.package then packageMenu(row.package)end end,g.help))
  end
  local function importMenu(p)
    local function importRows()
      for _,fresh in ipairs(session.model:imports())do if fresh.id==p.id then p=fresh end end
      return {
      {label=tr("STATUS","STATUS"),right=p.statusLabel},
      {label=tr("CHOOSE FILE / IMPORT","DATEI WÄHLEN / IMPORTIEREN"),action="import"},
      {label=tr("DELETE IMPORTED PACKAGE","IMPORTIERTES PAKET LÖSCHEN"),action="delete",muted=not p.canDelete}}
    end
    push(make("vasc_content_import_"..p.id,p.label,importRows,function(row)
        if row.action=="delete" then
          if not p.canDelete then return notice("not_installed") end
          return confirmDelete(p.id)
        elseif row.action=="import" then
          if busy() then return notice("busy_or_restart_required") end
          return session:openImport(p.id)
        end
      end,tr("Use the existing Stadium importer. Deletion removes the generated package; your source ROM stays.",
        "Nutzt den vorhandenen Stadium-Importer. Löschen entfernt das erzeugte Paket; deine Quell-ROM bleibt erhalten.")))
  end
  local crystalFamilies={['pokemon-crystal']=true,['pokemon-crystal-animation']=true,
    ['pokemon-crystal-special']=true,['pokemon-neo-crystal']=true,['pokemon-mega']=true,
    ['pokemon-mega-original-20260830']=true,['pokemon-animation-updates']=true,['pokemon-hoenn-animation']=true}
  local function categoryGroups()
    local buckets={
      {id='full-hd',label=tr('POKEMON FULL HD','POKEMON FULL HD'),children={}},
      {id='pokemon',label=tr('POKEMON GRAPHICS','POKEMON-GRAFIKEN'),children={}},
    }
    local crystal={id='crystal-pokemon',label=tr('CRYSTAL POKEMON','CRYSTAL-POKEMON'),children={},
      help=tr('Crystal Pokemon sprites, their animations and Mega forms belong together here. Choose the current or original Mega collection inside this group.',
        'Crystal-Pokemon, ihre Animationen und Mega-Formen findest du gemeinsam hier. Die aktuelle oder originale Mega-Sammlung waehlst du innerhalb dieser Gruppe.')}
    local megas={id='crystal-mega-forms',label=tr('MEGA FORMS','MEGA-FORMEN'),children={},help=crystal.help}
    for _,g in ipairs(session.model:groups())do
      if g.id:match('^pokemon%-') then
        if g.id=='pokemon-mega' or g.id=='pokemon-mega-original-20260830'then megas.children[#megas.children+1]=g
        elseif crystalFamilies[g.id]then crystal.children[#crystal.children+1]=g
        else local n=g.id=='pokemon-hd-3d' and 1 or 2;buckets[n].children[#buckets[n].children+1]=g end
      end
    end
    if #megas.children>0 then crystal.children[#crystal.children+1]=megas end
    local order={['pokemon-crystal']=1,['pokemon-crystal-animation']=2,['crystal-mega-forms']=3,['pokemon-neo-crystal']=4}
    table.sort(crystal.children,function(a,b)local x,y=order[a.id]or 10,order[b.id]or 10;if x==y then return a.id<b.id end;return x<y end)
    if #crystal.children>0 then table.insert(buckets[2].children,1,crystal)end
    return buckets
  end
  local function rows()
    local buckets=categoryGroups()
    local result={}
    for _,bucket in ipairs(buckets)do
      if #bucket.children==1 then local g=bucket.children[1];result[#result+1]={label=bucket.label,group=g}
      elseif #bucket.children>1 then result[#result+1]={label=bucket.label,group=bucket}end
    end
    for _,p in ipairs(session.model:imports())do result[#result+1]={label='STADIUM 2',right=p.statusLabel,import=p,help=tr('Import your Stadium 2 file or remove its generated models. Your source file is kept.','Stadium-2-Datei importieren oder die erzeugten Modelle löschen. Die Quelldatei bleibt erhalten.')}end
    result[#result+1]={label=tr('CHOOSE FILE / IMPORT','DATEI WÄHLEN / IMPORTIEREN'),action='packageImport'}
    result[#result+1]={label=tr('DOWNLOAD STATUS','DOWNLOAD-STATUS'),action='status'}
    result[#result+1]={label=tr('STARTUP PROMPT','STARTABFRAGE'),right=session.promptDisabled and tr('OFF','AUS') or tr('ON','AN'),action='startupPrompt',help=tr('Show the graphics choice at startup while packs are missing. Select to turn this on or off.','Grafikauswahl beim Start zeigen, solange Pakete fehlen. Hier die Abfrage an- oder abschalten.')}
    result[#result+1]={label=tr('LOGS & REPORTS','LOGS & BERICHTE'),action='diagnostics'}
    for _,row in ipairs(result)do
      row.help=row.help or tr('Download Pokemon sprites or import a downloaded package. Installed packages show their status and can be deleted. More sprites can be added here later.','Pokémon-Sprites herunterladen oder eine Paketdatei importieren. Installierte Pakete zeigen ihren Status und lassen sich löschen. Weitere Sprites kannst du hier später hinzufügen.')
    end
    return result
  end
  local menu=make("vasc_pokemon_hd_downloads",tr("SPRITE DOWNLOADS","SPRITE-DOWNLOADS"),rows,function(row)
    if row.group then return groupsMenu(row.group) end
    if row.import then return importMenu(row.import) end
    if row.action=="packageImport" then
      if busy() then return notice("busy_or_restart_required") end
      return session:openPackageImport()
    end
    if row.action=='startupPrompt' then
      local ok,err=session:setStartupPrompt(session.promptDisabled);if not ok then return notice(err)end
      return
    end
    if row.action=="status" then return session:openStatus() end
    if row.action=="diagnostics" then return session:openDiagnostics() end
  end)
  function menu:openCategory(id)
    for _,g in ipairs(categoryGroups())do if g.id==id then
      if #g.children==1 then return groupsMenu(g.children[1])end
      if #g.children>1 then return groupsMenu(g)end
    end end
    return notice('not_yet_available')
  end
  function menu:openFamily(id)
    for _,g in ipairs(session.model:groups())do if g.id==id then return groupsMenu(g)end end
    return notice('not_yet_available')
  end
  -- Reopening the screen always refreshes verified installation state. The host
  -- refreshes submenus on session epoch changes, preserving stable row IDs/focus.
  return menu
end
return M
