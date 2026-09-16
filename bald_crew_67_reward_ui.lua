-- Reuse KASC's full-screen/ORAS list owner and native dialogue bridge.
return function(mod,opts)
 local M={}
 local function tr(en,de)return opts.i18n and opts.i18n.text(en,de)or en end
 local function show(game,message,done,choice)
  if opts.show then return opts.show(game,message,done,choice)end
  local T=require('src.render.TextBox')
  game.stack:push(T.new(game,message,done,choice and{choice=choice,defaultNo=true}or nil))
 end
 local errors={
  bag_full={'Make room in your Bag.\nYour whole prize stays reserved.','Schaffe Platz im Beutel.\nDein ganzer Preis bleibt reserviert.'},
  storage_full={'Your party and PC are full.\nYour whole prize stays reserved.','Team und PC sind voll.\nDein ganzer Preis bleibt reserviert.'},
  save_failed={'Saving failed. Nothing was given.\nYour prize is still waiting.','Speichern fehlgeschlagen.\nDein Preis wartet weiterhin.'},
  already_claimed={'You already collected this prize.','Du hast diesen Preis bereits abgeholt.'},
 }
 function M.open(game,done)
  local finished=false
  local function finish()if not finished then finished=true;if done then done()end end end
  local c=opts.contract()
  if not(c and c.approved==true)then
   show(game,tr('The reward desk is not ready.\nYour victory remains recorded.',
    'Die Preisvergabe ist noch nicht bereit.\nDein Sieg bleibt eingetragen.'),finish);return false
  end
  if not opts.state.rewardPending()then
   show(game,tr('There is no unclaimed Crew prize.','Es wartet kein Crew-Preis.'),finish);return false
  end
  local rows={}
  for _,p in ipairs(c.choices or{})do
   local def=game.data.pokemon[p.species]
   rows[#rows+1]={value=p.id,label=(p.shiny and 'SHINY 'or'')..(def and def.name or p.species),
    right='Lv. '..tostring(p.level)}
  end
  if #rows==0 then rows={{value=false,label=tr('COLLECT PRIZE','PREIS ABHOLEN')}}end
  local menu
  local List=mod.ui.KantoListMenu or mod.ui.ListMenu
  menu=List.new(game,tr('CREW REWARD','CREW-BELOHNUNG'),rows,{
   onCancel=finish,
   onChoose=function(item)
    show(game,tr('Collect this prize?\nThis choice is final.',
      'Diesen Preis abholen?\nDie Auswahl ist endgültig.'),nil,function(yes)
     if not yes then return end
     local ok,receipt=opts.rewards.claim(game,item.value or nil)
     if not ok then
      local row=errors[receipt]
      return show(game,row and tr(row[1],row[2])or tr(
       'The prize could not be delivered.\nIt remains reserved.',
       'Die Übergabe war nicht möglich.\nDer Preis bleibt reserviert.'))
     end
     menu:close()
     local message=tr('Your Crew prize was saved.\nThe Shining Dome stays closed.',
      'Dein Crew-Preis ist gespeichert.\nDie Glanzkuppel bleibt geschlossen.')
     if receipt.destination=='box'then message=message..'\f'..tr('Your Pokemon is in BOX ','Dein Pokémon ist in BOX ')..receipt.box..'.'end
     show(game,message,finish)
    end)
   end,
  })
  game.stack:push(menu);return true
 end
 return M
end
