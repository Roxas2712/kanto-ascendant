-- Journal navigation owns presentation only; progression stays with providers.
return function(mod, options)
 options=options or {}
 local J={schema="kanto-ascendant/journal-menu/v1"}
 local function tr(en,de) return options.i18n and options.i18n.text(en,de) or en end
 local function ui() return assert(mod.exports and mod.exports.ascendantUi,"Journal UI unavailable") end
 function J.pages(text)
  local rows={}
  for block in (tostring(text or "").."\f"):gmatch("(.-)\f") do
   block=block:gsub("^%s+",""):gsub("%s+$","")
   if block~="" then
    local title=block:match("^[^\n]+") or block
    rows[#rows+1]={label=title,body=block,help=block}
   end
  end
  return rows
 end
 local function list(game,title,rows,choose)
  if #rows==0 then rows={{label=tr("NO ENTRIES","KEINE EINTRAEGE"),
   body=tr("There are no entries in this category yet.","In diesem Bereich gibt es noch keine Eintraege.")}} end
  local menu=ui().ListMenu.new(game,title,rows,{
   ascendantLayout=true,rows=6,wrap=true,
   ascendantFocusHelp=function(item)return item and (item.help or item.body) or "" end,
   footer=tr("A:DETAILS B:BACK","A:DETAILS B:ZURUECK"),
   onChoose=function(item,current)
    if choose then return choose(item,current) end
    return ui().showHelp(game,item.label,item.body)
   end,
  })
  menu.kascJournal=true
  game.stack:push(menu)
  return menu
 end
 function J.open(game,sections,actions)
  local rows={}
  for _,section in ipairs(sections or {}) do rows[#rows+1]={label=section.label,
   help=section.help or tr("Choose an entry. B always returns directly.","Eintrag auswaehlen. B fuehrt direkt zurueck."),section=section} end
  for _,action in ipairs(actions or {}) do rows[#rows+1]=action end
  return list(game,tr("JOURNAL","JOURNAL"),rows,function(item,current)
   if item.action then
    if current and current.close then current:close() end
    return item.action()
   end
   local section=item.section
   local value=section.read and section.read(game) or ""
   local entries=type(value)=="table" and value or J.pages(value)
   if section.single and #entries>0 then
    local texts={};for _,entry in ipairs(entries) do texts[#texts+1]=entry.body end
    return ui().showHelp(game,section.label,table.concat(texts,"\n\n"))
   end
   return list(game,section.label,entries)
  end)
 end
 return J
end
