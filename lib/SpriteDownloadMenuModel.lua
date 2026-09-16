-- Small view model for the existing VASC menu renderer. No image previews bundled.
local M={}
local LABELS={
  ["pokemon-mega-original-20260830"]={"Original Mega collection","Originale Mega-Sammlung","The 30 original Mega forms plus Ascendant Typhlosion, with the approved 30 August front animation timings. Select this version explicitly after download.","Die 30 urspruenglichen Mega-Formen plus Ascendant-Tornupto mit den freigegebenen Front-Framezeiten vom 30. August. Nach Download diese Version gezielt auswaehlen."},
  ["pokemon-animation-updates"]={"Updated animations","Ueberarbeitete Animationen","New and revised Pokemon animation frames from KASC 6.7.","Neue und ueberarbeitete Pokemon-Animationsbilder aus KASC 6.7."},
  ["pokemon-hoenn-animation"]={"Hoenn animations","Hoenn-Animationen","Animated Hoenn Pokemon artwork in the Emerald style.","Animierte Hoenn-Pokemon-Grafiken im Smaragd-Stil."},
  ["pokemon-type-forms"]={"Pokemon type forms","Pokemon-Typformen","Pokemon artwork for forms that change their type.","Pokemon-Grafiken fuer Formen mit wechselndem Typ."},
  ["pokemon-hd-3d"]={"HD overworld Pokemon","HD-Pokemon Spielwelt","Animated 3D Pokemon walking in the world. Kanto and Johto packages.","Animierte 3D-Pokemon in der Spielwelt. Pakete fuer Kanto und Johto."},
  ["pokemon-hd-2d"]={"HD battle sprites","HD-Kampfsprites","Detailed flat Pokemon artwork for battles. These are not walking models.","Detaillierte flache Pokemon-Grafiken im Kampf. Keine Laufmodelle."},
  ["pokemon-crystal"]={"Crystal sprites","Crystal-Sprites","Crystal-style Pokemon fronts and backs. These KASC images need a download.","Pokemon-Fronten und Ruecken im Crystal-Stil. Diese KASC-Bilder werden geladen."},
  ["pokemon-crystal-animation"]={"Crystal animations","Crystal-Animationen","Animated Pokemon battle sprites in the Crystal style, grouped by generation.","Animierte Pokemon-Kampfsprites im Crystal-Stil, nach Generation sortiert."},
  ["pokemon-neo-crystal"]={"Neo Crystal sprites","Neo-Crystal-Sprites","Alternative Pokemon pixel artwork in the Neo Crystal style.","Alternative Pokemon-Pixelgrafiken im Neo-Crystal-Stil."},
  ["pokemon-pixel-2d"]={"Pixel battle sprites","Pixel-Kampfsprites","Static Pokemon fronts and backs in the pixel style.","Unbewegte Pokemon-Fronten und Ruecken im Pixelstil."},
  ["pokemon-overworld-mmo"]={"MMO walking sprites","MMO-Laufsprites","Pokemon walking sprites in the MMO style for the game world.","Pokemon-Laufsprites im MMO-Stil fuer die Spielwelt."},
  ["pokemon-overworld-pixel"]={"Pixel walking sprites","Pixel-Laufsprites","Pokemon follower sprites for walking, swimming and floating.","Pokemon-Begleitersprites zum Laufen, Schwimmen und Schweben."},
  ["pokemon-mega"]={"Mega sprites & motion","Mega-Sprites & Bewegung","Mega Pokemon forms, including their available battle animation frames.","Mega-Pokemon-Formen samt ihren vorhandenen Kampfanimationsbildern."},
  ["pokemon-regional"]={"Regional forms","Regionalformen","Alternative regional Pokemon forms, including Alola forms.","Regionale Pokemon-Varianten, einschliesslich Alola-Formen."},
  ["pokemon-icons"]={"Pokemon menu icons","Pokemon-Menueicons","Small Pokemon images used in party, box and other menus.","Kleine Pokemon-Bilder fuer Team, Boxen und weitere Menues."},
  ["pokemon-crystal-special"]={"Crystal special forms","Crystal-Sonderformen","Additional special Pokemon artwork from the Crystal set.","Zusaetzliche besondere Pokemon-Grafiken aus dem Crystal-Paket."},
  ["pokemon-field-actions"]={"Pokemon field actions","Pokemon-Feldaktionen","Pokemon sprites used during special actions in the game world.","Pokemon-Sprites fuer besondere Aktionen in der Spielwelt."},
  ["pokemon-gorochu"]={"Gorochu sprites","Gorochu-Sprites","Gorochu Pokemon graphics.","Pokemon-Grafiken fuer Gorochu."},
  ["pokemon-hevo"]={"Special evolutions","Spezialentwicklungen","Pokemon graphics for the special evolution forms.","Pokemon-Grafiken fuer die Spezialentwicklungsformen."},
  ["pokemon-hoenn"]={"Hoenn Pokemon sprites","Hoenn-Pokemon-Sprites","Pokemon artwork for the Hoenn species, generation 3.","Pokemon-Grafiken fuer die Hoenn-Arten aus Generation 3."},
  ["pokemon-hoenn-legacy"]={"Legacy Hoenn sprites","Aeltere Hoenn-Sprites","Earlier Hoenn Pokemon artwork used by existing forms.","Aeltere Hoenn-Pokemon-Grafiken fuer bestehende Formen."},
  ["pokemon-later"]={"Later Pokemon species","Spaetere Pokemon-Arten","Artwork for Pokemon species introduced after the earlier generations.","Grafiken fuer Pokemon-Arten aus spaeteren Generationen."},
  ["pokemon-national"]={"National Pokemon set","Nationaler Pokemon-Satz","Additional Pokemon species artwork, grouped by generation and number.","Weitere Pokemon-Artengrafiken, nach Generation und Nummer sortiert."},
  ["pokemon-partner"]={"Partner Pokemon","Partner-Pokemon","Special partner Pokemon graphics.","Grafiken fuer besondere Partner-Pokemon."},
  ["pokemon-special"]={"Special Pokemon forms","Pokemon-Sonderformen","Graphics for special Pokemon variants and forms.","Grafiken fuer besondere Pokemon-Varianten und Formen."},
  ["pokemon-starters"]={"Starter Pokemon","Starter-Pokemon","Additional starter Pokemon species artwork.","Grafiken fuer zusaetzliche Starter-Pokemon-Arten."},
}
function M.new(catalog,store,options)
  options=options or {}
  local de=options.language=="de"
  local function tr(en,german)return de and german or en end
  local self={selected={},catalog=catalog,store=store}
  function self:groups()
    local grouped={};for _,p in ipairs(catalog.data.packages) do
      local family=p.family or "other"
      local text=LABELS[family]
      local g=grouped[family] or {id=family,label=text and tr(text[1],text[2]) or family,help=text and tr(text[3],text[4]) or "",packages={}}
      grouped[family]=g
      local plan=catalog:plan({p.id},store)
      g.packages[#g.packages+1]={id=p.id,band=p.band,species=p.species,
        fileBytes=p.fileBytes,downloadBytes=plan.downloadBytes,estimateExact=plan.estimateExact,
        installed=plan.ready,downloadable=plan.canDownload,selected=self.selected[p.id]==true,
        statusLabel=plan.ready and tr("Already installed","Bereits installiert") or plan.canDownload and tr("Available","Verfügbar") or tr("Not yet available","Noch nicht verfügbar"),
        canDelete=plan.ready or (options.hasPartial and options.hasPartial(p.id)==true) or false,
        status=plan.ready and "installed" or plan.canDownload and "available" or "not_yet_available"}
    end
    local rows={};for _,g in pairs(grouped) do rows[#rows+1]=g end
    table.sort(rows,function(a,b)return a.id<b.id end);return rows
  end
  function self:imports()
    local rows={}
    for _,s in ipairs(catalog.data.styles) do
      if s.kind=="import" and (not options.importIds or options.importIds[s.id]) then
        local installed=store.hasImport and store:hasImport(s.id)==true or false
        local partial=not installed and options.hasPartial and options.hasPartial(s.id)==true
        rows[#rows+1]={id=s.id,label=s.label,installed=installed,canDelete=installed or partial,
          statusLabel=installed and tr("Already installed","Bereits installiert") or partial and tr("Incomplete - import again","Unvollständig - neu importieren") or tr("Not imported","Noch nicht importiert")}
      end
    end
    return rows
  end
  function self:toggle(id)
    if not catalog.packages[id] then return false,"unknown_package" end
    local p=catalog:plan({id},store)
    if p.ready then self.selected[id]=nil;return false,"already_installed" end
    if not p.canDownload then return false,"not_yet_available" end
    self.selected[id]=not self.selected[id] or nil;return true
  end
  function self:plan()
    local keys={};for key,yes in pairs(self.selected) do if yes then keys[#keys+1]=key end end
    table.sort(keys);return catalog:plan(keys,store)
  end
  function self:selectPreset(preset)
    local plan=catalog:plan(preset.packages,store)
    if #plan.unavailable>0 then return false,"not_yet_available" end
    for _,key in ipairs(plan.missing) do self.selected[key]=true end
    return true
  end
  return self
end
return M
