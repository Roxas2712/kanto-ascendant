-- Playable Rocket Recovery raid adapter for Kanto Ascendant 6.7.
-- Progress/custody/reward authority stays in rocket_recovery_raids_67.lua;
-- this module only presents offers, maps, battles and static captures.

return function(mod,opts)
  opts=opts or{}
  local raids=assert(opts.raids,"Rocket raid authority missing")
  local data=assert(opts.data,"Rocket raid data missing")
  local maps=assert(opts.maps,"Rocket raid maps missing")
  local content=assert(opts.content,"Rocket raid content missing")
  local postgame=assert(opts.postgame,"Rocket forced-battle authority missing")
  local i18n=opts.i18n
  local R={game=nil,installed=false,offeredThisSession=false,
    offeredRepeatToken=nil}

  local function tr(en,de)return i18n and i18n.text and i18n.text(en,de)or en end
  local function clamp(value,lo,hi)
    value=math.floor(tonumber(value)or lo);return math.max(lo,math.min(hi,value))
  end
  local function show(game,text,done,choice)
    if type(opts.showText)=="function"then return opts.showText(game,text,done,choice)end
    local TextBox=opts.textBox or require("src.render.TextBox")
    game.stack:push(TextBox.new(game,text,done,choice and{
      defaultNo=true,choice=choice}or nil));return true
  end
  local function definitionById(instanceId)
    for index,row in ipairs(data.instances or{})do
      if row.id==instanceId then return row,index end
    end
  end
  local function featureEnabled()
    if mod.options and type(mod.options.get)=="function"then
      local ok,value=pcall(mod.options.get,mod.options,"rocket_raids")
      if ok and value==false then return false end
    end
    return true
  end
  local function setVisible(save,mapId,name,visible)
    if type(save)~="table"then return end
    save.objectToggles=type(save.objectToggles)=="table"and save.objectToggles or{}
    save.objectToggles[mapId]=type(save.objectToggles[mapId])=="table"
      and save.objectToggles[mapId]or{}
    save.objectToggles[mapId][name]=visible==true
  end
  local function objectName(instanceId,index)
    return("KA_ROCKET_RAID_%s_FIGHT_%02d"):format(instanceId:upper(),index)
  end
  local function captureName(key)return"KA_ROCKET_CAPTURE_"..key:upper()end

  local function liveMapId(game)
    local ow=game and game.overworld
    return ow and ow.map and ow.map.id
  end

  function R.secureSave(save)
    local player=save and save.player
    local row=type(player)=="table"and maps.byMap[player.map]
    if not row then return false end
    player.map=row.hostMap;player.x=row.returnPoint[1];player.y=row.returnPoint[2]
    player.facing="down";player.surfing=false
    return true
  end

  function R.returnToHost(game,mapId)
    game=game or R.game;mapId=mapId or liveMapId(game)
    local row=maps.byMap[mapId]
    if not row then return false,"not_instance"end
    R.secureSave(game and game.save)
    if not(mod.world and type(mod.world.warpTo)=="function")then
      return false,"warp"
    end
    return mod.world:warpTo(row.hostMap,row.returnPoint[1],row.returnPoint[2],"down")
  end

  -- Compatibility name used by older recovery callers. There is no mutable
  -- map state to restore anymore; the only action is leaving a live clone.
  function R.restoreAll(game)
    game=game or R.game
    if maps.isInstanceMap(liveMapId(game))then
      local ok=R.returnToHost(game);return ok and 1 or 0
    end
    return R.secureSave(game and game.save)and 1 or 0
  end

  function R.sync(game,mapId)
    game=game or R.game;mapId=mapId or(game and game.overworld and
      game.overworld.map and game.overworld.map.id)
    local row=maps.byMap[mapId];if not row then return false,"map"end
    local objective=raids.objective(game)
    local def=assert(definitionById(row.id),"Rocket instance drift")
    for index=1,def.fights do
      setVisible(game and game.save,mapId,objectName(def.id,index),false)
    end
    for _,row in ipairs(data.contraband or{})do
      setVisible(game and game.save,mapId,captureName(row.key),false)
    end
    local active=featureEnabled()and objective and objective.map==mapId
      and objective.id==row.id
    if active then
      if objective.phase=="active"then
        -- Fill the isolated stock-geometry clone with every remaining checkpoint.
        -- Only the current one accepts a battle; later guards are already
        -- visible so the room reads as a Rocket occupation rather than an
        -- empty corridor with one spawning NPC.
        local def=assert(definitionById(objective.id),"Rocket instance drift")
        for index=objective.fight,def.fights do
          setVisible(game and game.save,mapId,objectName(objective.id,index),true)
        end
      elseif objective.phase=="capture"and objective.capture then
        setVisible(game and game.save,mapId,
          captureName(objective.capture.key),true)
      end
    end
    return true
  end

  local ROSTER_VARIANTS={
    celadon_relay={
      {"RATICATE","ARBOK","WEEZING","PERSIAN","MUK","GOLBAT"},
      {"GOLBAT","MUK","RATICATE","HYPNO","ARBOK","MAROWAK"},
      {"PERSIAN","GENGAR","ARBOK","MUK","WEEZING","TAUROS"},
    },
    lavender_relay={
      {"HAUNTER","ARBOK","WEEZING","PERSIAN","MAROWAK","HYPNO"},
      {"GENGAR","HYPNO","MUK","HAUNTER","PERSIAN","WEEZING"},
      {"MAROWAK","HAUNTER","ARBOK","GOLBAT","HYPNO","PERSIAN"},
    },
    cerulean_relay={
      {"MAGNETON","GOLBAT","MUK","PERSIAN","ELECTRODE","RHYDON"},
      {"CLOYSTER","MAGNETON","WEEZING","GOLBAT","MUK","PERSIAN"},
      {"PERSIAN","GENGAR","MAGNETON","RHYDON","GOLBAT","MUK"},
    },
    viridian_command={
      {"NIDOKING","NIDOQUEEN","RHYDON","PERSIAN","KANGASKHAN","GOLEM"},
      {"PERSIAN","KANGASKHAN","DUGTRIO","RHYDON","TAUROS","NIDOKING"},
      {"NIDOQUEEN","RHYDON","MAROWAK","PERSIAN","NIDOKING","GENGAR"},
    },
  }
  local FALLBACK={"RATICATE","ARBOK","WEEZING","MUK","PERSIAN","GOLBAT"}
  -- Supplemental Rocket roles, not unrestricted legendary/gift selection.
  -- Candidates enter only through the same current profile as other trainers.
  local LATER_ROCKET={
    'CROBAT','HOUNDOOM','MURKROW','SNEASEL','SCIZOR',
    'MIGHTYENA','SHARPEDO','CACTURNE','SEVIPER','BANETTE',
    'HONCHKROW','SKUNTANK','DRAPION','WEAVILE','TOXICROAK',
    'LIEPARD','KROOKODILE','SCRAFTY','GARBODOR','BISHARP',
    'PANGORO','MALAMAR','DRAGALGE','NOIVERN',
    'GUMSHOOS','VIKAVOLT','TOXAPEX','SALAZZLE','BEWEAR','GOLISOPOD',
    'PALOSSAND','TURTONATOR','DHELMISE',
  }
  function R.buildTeam(game,objective)
    objective=objective or raids.objective(game)
    if not objective then return nil,"objective"end
    local def=assert(data.instances[objective.instance],"Rocket instance drift")
    local level=clamp(objective.scaleReceipt and
      objective.scaleReceipt.recommendedLevel or 50,50,100)
    level=clamp(level+objective.instance-1,50,100)
    local target=math.min(6,3+objective.instance+
      (objective.fight==def.fights and 1 or 0))
    local variants=ROSTER_VARIANTS[def.id]or{FALLBACK}
    local incident=math.max(1,math.floor(tonumber(objective.incident)or 1))
    -- Stable per sealed checkpoint: reloads cannot reroll it. A later
    -- incident deliberately selects another authored setup.
    local variantIndex=((incident-1)+(objective.instance-1)*2+
      (objective.fight-1))%#variants+1
    local pool=variants[variantIndex]
    local team,used={},{}
    local owner=opts.trainerPool and opts.trainerPool()
    local function resolve(name)
      return owner and owner.resolve(name) or not owner and name or nil
    end
    local function eligible(species,record)
      if owner then return owner.available(game,species,record) end
      return not opts.generationRules or not opts.generationRules.speciesAvailable
        or opts.generationRules.speciesAvailable(game,species,record)
    end
    local function add(species)
      species=resolve(species)
      if not species then return end
      if used[species]or not(game and game.data and game.data.pokemon
          and game.data.pokemon[species])then return end
      if not eligible(species,game.data.pokemon[species]) then return end
      used[species]=true;team[#team+1]={species=species,level=level}
    end
    local later={}
    if opts.generationRules and opts.generationRules.speciesAvailable then
      for _,name in ipairs(LATER_ROCKET) do
        local species=resolve(name)
        local record=game and game.data and game.data.pokemon[species]
        if record and eligible(species,record) then
          later[#later+1]=species
        end
      end
    end
    if #later>0 then
      local start=((incident-1)*7+(objective.instance-1)*3+objective.fight-1)%#later
      for step=0,math.min(2,#later)-1 do add(later[(start+step)%#later+1]) end
    end
    local offset=((objective.fight-1)%#pool)+1
    for step=0,#pool-1 do add(pool[((offset+step-1)%#pool)+1])end
    for _,species in ipairs(FALLBACK)do add(species)end
    while #team>target do table.remove(team)end
    if #team<1 then return nil,"registered_roster_absent"end
    return team,nil,{variant=variantIndex,incident=incident,
      instance=objective.instance,fight=objective.fight}
  end

  local function refresh(game,ow,mapId)
    R.sync(game,mapId)
    if ow and type(ow.reloadMap)=="function"then
      ow:reloadMap(mapId,"rocket-recovery-progress")
    end
  end
  local function leadName(def,german)
    if def.lead=="GIOVANNI"then return"GIOVANNI"end
    return german and"JESSIE, JAMES UND MAUZI"
      or"JESSIE, JAMES AND MEOWTH"
  end
  local function checkpointVerb(def,german)
    if def.lead=="GIOVANNI"then return german and"bewacht"or"guards"end
    return german and"bewachen"or"guard"
  end
  local ROCKET_CARD_NAMES={
    rocket_raid_jessie_james={en="ROCKET RELAY",de="ROCKET-RELAIS"},
    rocket_raid_meowth={en="MEOWTH'S LEDGER",de="MAUZIS KASSENBUCH"},
    rocket_raid_executive={en="ROCKET CONTRABAND",de="ROCKET-KONTRABANDE"},
    rocket_raid_giovanni={en="GIOVANNI: LAST VAULT",de="GIOVANNI: LETZTES DEPOT"},
  }
  local function clearedText(def,state)
    local plan=state and state.rewardReceipts and state.rewardReceipts[def.id]
    if type(plan)~="table"then return tr(
      "The Rocket line breaks. The next signal is now traceable.",
      "Rockets Linie bricht. Das nächste Signal ist jetzt ortbar.")end
    local names=ROCKET_CARD_NAMES[plan.trainerCard]or{}
    local cardEn=names.en or tostring(plan.trainerCard or "ROCKET")
    local cardDe=names.de or tostring(plan.trainerCard or "ROCKET")
    local machine=plan.machineNumber and ("TM%02d"):format(plan.machineNumber)or nil
    local moveName=tostring(plan.move or ""):gsub("_"," ")
    local extraEn=machine and(" and "..machine.." "..moveName)or""
    local extraDe=machine and(" und "..machine.." "..moveName)or""
    return tr("Depot cleared. Reward: "..cardEn.." Trainer Card"..extraEn
      ..". The next signal is traceable.",
      "Depot geräumt. Belohnung: Trainerkarte "..cardDe..extraDe
      ..". Das nächste Signal ist ortbar.")
  end
  local function startFight(game,ow,npc,objective,done)
    local def=data.instances[objective.instance]
    local team,why,teamReceipt=R.buildTeam(game,objective)
    if not team then return show(game,tr(
      "The raid roster is unavailable. Nothing changed.",
      "Das Raid-Team ist nicht verfügbar. Nichts wurde verändert."),done)end
    local class=def.lead=="GIOVANNI"and"OPP_GIOVANNI"or"OPP_ROCKET"
    local battle=postgame.newForcedBattle(game,class,team,"rocket_recovery",{
      source="rocket_recovery:"..def.id..":"..objective.fight})
    battle.ascendantRocketRaid=true;battle.ascendantNoItems=true
    battle.kaRocketNoEscape=true
    battle.noPrizeMoney=true;battle.rematch=objective.repeatable==true
    battle.kaRocketLead=def.lead;battle.kaRocketRulesReceipt=objective.scaleReceipt
    battle.kaRocketTeamReceipt=teamReceipt
    battle.enemyAIMods={1,2,3}
    -- Yellow's existing combined Jessie/James/Meowth contract remains the
    -- only edition-native combined portrait. The authored roster was already
    -- constructed above; this index is presentation evidence only.
    if def.lead=="JESSIE_JAMES_MEOWTH"then battle.partyIndex=42 end
    battle.introText=tr(leadName(def,false)..": The vault stays ours!",
      leadName(def,true)..": Das Depot bleibt unser!")
    battle.onFinish=function(result)
      if npc then npc.frozen=false end
      if result=="win"then
        local completed=objective.fight==def.fights
        local ok,reason=raids.onFightWon(game)
        ow:afterBattle(result,battle)
        if not ok then return show(game,tr(
          "The raid receipt could not be sealed: ",
          "Der Raid-Beleg konnte nicht gesichert werden: ")..tostring(reason),done)end
        return show(game,completed and clearedText(def,reason)or tr(
          "The Rocket line breaks. The next checkpoint is now open.",
          "Rockets Linie bricht. Der nächste Kontrollpunkt ist jetzt offen."),
          function()
            local nextObjective=raids.objective(game)
            if completed and(not nextObjective or nextObjective.map~=def.map)then
              R.returnToHost(game,def.map)
            else
              refresh(game,ow,def.map)
            end
            if done then done()end
          end)
      end
      local ok,reason=raids.onLoss(game)
      -- Treat defeat as a forced withdrawal, not a vanilla blackout/heal.
      ow:afterBattle("run",battle)
      local lossText
      if ok and reason and reason.lastLossStacked then
        lossText=tr(
          "Rocket moved another Pokemon into custody. Heal outside; this exact fight remains sealed here.",
          "Rocket hat ein weiteres Pokémon festgesetzt. Heile draußen; genau dieser Kampf bleibt hier versiegelt.")
      elseif ok then
        lossText=tr(
          "Rocket found no further safe target. Heal outside; this exact fight remains sealed here.",
          "Rocket konnte kein weiteres Pokémon sicher festsetzen. Heile draußen; genau dieser Kampf bleibt hier versiegelt.")
      else
        lossText=tr("Custody could not be updated: ",
          "Die Verwahrung konnte nicht aktualisiert werden: ")..tostring(reason)
      end
      return show(game,lossText,function()
            R.returnToHost(game,def.map);if done then done()end
          end)
    end
    if npc then npc.frozen=true;if npc.facePlayer then npc:facePlayer(ow.player)end end
    ow:pushBattle(battle);return true
  end

  local function startCapture(game,ow,npc,capture,done)
    if not(game and game.data and game.data.pokemon
        and game.data.pokemon[capture.species])then return show(game,tr(
      "The confiscated life-sign is unstable. Nothing changed.",
      "Das beschlagnahmte Lebenszeichen ist instabil. Nichts wurde verändert."),done)end
    local BattleState=opts.battleState or require("src.battle.BattleState")
    local battle=BattleState.newWild(game,capture.species,capture.level or 70,{
      encounterSource="rocket_recovery",randomizerProtected=true})
    battle.ascendantRocketRaid=true;battle.kaRocketNoEscape=true
    battle.kaRocketCaptureKey=capture.key
    battle.onFinish=function(result)
      local ok,reason=raids.resolveCapture(game,result)
      ow:afterBattle(result,battle)
      if not ok then return show(game,tr("The capture receipt failed: ",
        "Der Fangbeleg schlug fehl: ")..tostring(reason),done)end
      local message=result=="caught"and tr(
        "The confiscated Pokemon is safe. The operation can continue.",
        "Das beschlagnahmte Pokémon ist sicher. Die Operation kann weitergehen.")
        or tr("It remains in the sealed room. You can challenge it again.",
          "Es bleibt im versiegelten Raum. Du kannst es erneut herausfordern.")
      return show(game,message,function()
        local nextObjective=raids.objective(game)
        if result~="caught"or not nextObjective or nextObjective.map~=ow.map.id then
          R.returnToHost(game,ow.map.id)
        else
          refresh(game,ow,ow.map.id)
        end
        if done then done()end
      end)
    end
    ow:pushBattle(battle);return true
  end

  function R.talk(game,ow,npc,kind,index,done)
    local objective=raids.objective(game)
    local mapId=ow and ow.map and ow.map.id
    if not objective or objective.map~=mapId then return show(game,tr(
      "Only a cold Rocket relay remains.","Nur ein kaltes Rocket-Relais bleibt."),done)end
    if kind=="blocked"then return show(game,tr(
      "Deal with Team Rocket first. This passage is sealed during the raid.",
      "Kümmere dich um Team Rocket. Dieser Durchgang ist während des Raids gesperrt."),done)end
    if kind=="capture"then
      local capture=raids.currentCapture()
      if not capture or capture.key~=index then return show(game,tr(
        "The containment field is empty.","Das Eindämmungsfeld ist leer."),done)end
      return show(game,tr(
        "Rocket's containment field collapses. Rescue and catch the Pokemon now!",
        "Rockets Eindämmungsfeld bricht zusammen. Rette und fange das Pokémon jetzt!"),
        function()startCapture(game,ow,npc,capture,done)end)
    end
    if objective.phase~="active"or objective.fight~=index then return show(game,tr(
      "This checkpoint is not the active Rocket line.",
      "Dieser Kontrollpunkt ist nicht Rockets aktive Linie."),done)end
    local def=data.instances[objective.instance]
    return show(game,tr(
      leadName(def,false).." "..checkpointVerb(def,false).." checkpoint "..index.." of "..def.fights..". No Bag. No healing. No escape.",
      leadName(def,true).." "..checkpointVerb(def,true).." Punkt "..index.." von "..def.fights..". Kein Beutel. Keine Heilung. Keine Flucht."),
      function()startFight(game,ow,npc,objective,done)end)
  end

  function R.enter(game)
    if not featureEnabled()then return false,"disabled"end
    local objective=raids.objective(game);if not objective then return false,"objective"end
    local row=assert(maps.byInstance[objective.id],"Rocket raid instance missing")
    R.sync(game,objective.map)
    if not(mod.world and type(mod.world.warpTo)=="function")then return false,"warp"end
    return mod.world:warpTo(objective.map,row.start[1],row.start[2],"up")
  end

  local function selectAndStart(game,sourceId)
    local ok,why=raids.start(game,sourceId)
    if not ok then return show(game,tr("Rocket recovery could not start: ",
      "Rocket-Rückholung konnte nicht starten: ")..tostring(why))end
    return R.enter(game)
  end
  function R.offer(game)
    local model=raids.offerModel(game)
    if not model.unlocked or not model.enabled then return false,"locked"end
    local status=raids.status()
    if status.status=="active"or status.status=="capture"then
      return show(game,tr(
        "The sealed Rocket operation is still active. Return to the current checkpoint?",
        "Die versiegelte Rocket-Operation läuft noch. Zum aktuellen Kontrollpunkt zurückkehren?"),nil,
        function(yes)if yes then R.enter(game)end end)
    end
    if #model.sources<1 then return false,"source"end
    local function prompt(index)
      local source=model.sources[index]
      if not source then return false,"declined"end
      local sourceName=source.id=="box"and tr("local Boxes","lokalen Boxen")
        or source.id=="legacy"and tr("Legacy Bank","Vermächtnisbank")
        or tr("trailing Party slots","hinteren Teamplätzen")
      return show(game,tr(
        "A secure call reports a Rocket bank theft. Deal with Team Rocket. Use "..sourceName.." as tracked bait and begin recovery? Default: NO.",
        "Ein gesicherter Anruf meldet einen Rocket-Bankraub. Kümmere dich um Team Rocket. "..sourceName.." als verfolgten Köder nutzen und die Rückholung beginnen? Standard: NEIN."),nil,
        function(yes)
          if yes then return selectAndStart(game,source.id)end
          -- Local Boxes are the automatic source.  Only when they are empty
          -- do Legacy Bank and trailing Party slots appear as explicit,
          -- individually rejectable fallbacks.  Declining every prompt never
          -- moves a Pokemon and never opens a raid instance.
          if source.id~="box"and model.sources[index+1]then
            return prompt(index+1)
          end
        end)
    end
    return prompt(1)
  end

  function R.install(game)
    R.game=game or R.game
    if R.installed then R.sync(R.game);return false,"already_installed"end
    R.installed=true;content:bindRuntime(R)
    if mod.hooks and type(mod.hooks.wrap)=="function"then
      mod.hooks:wrap("battle.run",function(nextRun,ctx)
        if ctx and ctx.battle and ctx.battle.kaRocketNoEscape then return false end
        return nextRun(ctx)
      end,940)
      mod.hooks:wrap("save.new_game",function(nextNewGame,...)
        -- A same-process NG+ can never retain an instance-map resume point.
        R.secureSave(R.game and R.game.save)
        return nextNewGame(...)
      end,941)
    end
    if mod.events and type(mod.events.on)=="function"then
      mod.events:on("map.entered",function(ev)
        local active=ev and ev.game or R.game
        local mapId=ev and ev.mapId
        if maps.isInstanceMap(mapId)then
          local objective=raids.objective(active)
          if not featureEnabled()or not objective or objective.map~=mapId then
            return R.returnToHost(active,mapId)
          end
          return R.sync(active,mapId)
        end
        local objective=featureEnabled()and raids.objective(active)
        local target=objective and maps.byInstance[objective.id]
        -- Only a real entry from outside redirects. Boot, returning after
        -- defeat, and ordinary internal floor changes never bounce back in.
        if target and mapId==target.hostMap
            and ev.fromMapId==target.entranceMap and ev.via~="boot"then
          return R.enter(active)
        end
        -- A declined first offer is shown only once per session. An already
        -- sealed operation is different: after a loss, a failed capture or a
        -- completed depot the player must always be able to resume the exact
        -- current checkpoint by returning to the Viridian Gym clue.
        local resume=raids.objective(active)~=nil
        if mapId=="VIRIDIAN_GYM"then
          local model=raids.offerModel(active)
          local repeatToken=model.repeatReady and
            (tostring(model.readyAt)..":"..tostring(
              raids.status().incident or 0))or nil
          local shouldOffer=not R.offeredThisSession or resume
            or repeatToken and repeatToken~=R.offeredRepeatToken
          if not shouldOffer then return end
          -- Resuming an already sealed checkpoint never needs a second bait
          -- source. The initial hold may legitimately have exhausted every
          -- eligible Box/Bank/Party candidate.
          if model.unlocked and model.enabled
              and (resume or #model.sources>0) then
            R.offeredThisSession=true
            if repeatToken then R.offeredRepeatToken=repeatToken end
            R.offer(active)
          end
        end
      end,3380)
      mod.events:on("mod.options_changed",function(ev)
        if ev and ev.mod==mod.id and ev.key=="rocket_raids"
            and ev.value==false then
          R.restoreAll(R.game)
        end
      end,3390)
      mod.events:on("save.writing",function(ev)
        R.secureSave(ev and ev.save or R.game and R.game.save)
      end,3391)
      mod.events:on("save.loaded",function(ev)
        R.secureSave(ev and ev.save or R.game and R.game.save)
      end,3391)
      mod.events:on("game.ready",function(ev)
        local active=ev and ev.game or R.game
        if maps.isInstanceMap(liveMapId(active))then R.returnToHost(active)end
      end,3391)
    end
    return true
  end
  return R
end
