-- Runtime language selection for Kanto Ascendant. English is the standalone
-- fallback; AUTO follows the active German Red/Blue/Yellow translation mod.

local REMATCH = {
  OPP_YOUNGSTER = "Ich mag Shorts!\nDoch zweimal\nverlier ich nicht!",
  OPP_BUG_CATCHER = "Meine KÄFER-\nPOKéMON wollen\neine Revanche!",
  OPP_LASS = "Ich habe seitdem\nhart trainiert.\nNoch ein Kampf?",
  OPP_SAILOR = "Wieder da,\nLandratte? Noch\nein Kampf?",
  OPP_JR_TRAINER_M = "Diesmal streng\nich mich mehr an!\nLos geht's!",
  OPP_JR_TRAINER_F = "Seit damals habe\nich viel geübt!\nNoch einmal?",
  OPP_POKEMANIAC = "Seit unserem Kampf\nfing ich noch mehr\nPOKéMON!",
  OPP_SUPER_NERD = "Ich kenne deine\nStrategie. Neuer\nVersuch!",
  OPP_HIKER = "Seit damals habe\nich viele Berge\nbestiegen!",
  OPP_BIKER = "Du willst mehr?\nDann drehen wir\nnoch eine Runde!",
  OPP_BURGLAR = "Einmal schlugst\ndu mich. Das wird\njetzt geklärt!",
  OPP_ENGINEER = "Ich habe neue\nMaschinen gebaut.\nTeste sie!",
  OPP_UNUSED_JUGGLER = "Ich habe neue\nKunststücke geübt.\nSchau her!",
  OPP_FISHER = "Heute fange ich\nnicht nur Fische!\nKämpfen wir!",
  OPP_SWIMMER = "Das Wasser ist\ngut. Noch ein\nKampf!",
  OPP_CUE_BALL = "Ich bin noch\nnicht fertig mit\ndir. Revanche!",
  OPP_GAMBLER = "Diesmal setze ich\nauf den Sieg\nmeiner POKéMON!",
  OPP_BEAUTY = "Diesmal verliere\nich nicht. Eine\nRevanche?",
  OPP_PSYCHIC_TR = "Ich wusste, dass\ndu wiederkommst.\nKämpfen wir!",
  OPP_ROCKER = "Die Zugabe ist\nvorbei. Runde zwei\nbeginnt!",
  OPP_JUGGLER = "Ich habe neue\nKunststücke geübt.\nSchau her!",
  OPP_TAMER = "Meine POKéMON\nlechzen nach einer\nRevanche!",
  OPP_BIRD_KEEPER = "Meine FLUG-\nPOKéMON wollen\nnoch einen Kampf!",
  OPP_BLACKBELT = "Seit damals habe\nich hart trainiert.\nRevanche?",
  OPP_RIVAL1 = "Du schon wieder?\nDiesmal verliere\nich aber nicht!",
  OPP_RIVAL2 = "Du schon wieder?\nDiesmal verliere\nich aber nicht!",
  OPP_RIVAL3 = "Du schon wieder?\nDiesmal verliere\nich aber nicht!",
  OPP_PROF_OAK = "Möchtest du noch\neinmal gegen mich\nkämpfen?",
  OPP_CHIEF = "Zweimal verliere\nich nicht!\nRevanche!",
  OPP_SCIENTIST = "Meine Forschung\nbeweist: Diesmal\ngewinne ich!",
  OPP_GIOVANNI = "Du hast Mut,\nzurückzukommen.\nWir werden sehen!",
  OPP_ROCKET = "TEAM ROCKET kommt\nimmer zurück.\nRevanche!",
  OPP_COOLTRAINER_M = "Seit unserem\nKampf bin ich\nstärker geworden!",
  OPP_COOLTRAINER_F = "Du bist stark,\ndoch ich trainierte.\nNoch einmal?",
  OPP_BRUNO = "Hah! Meine Muskeln\nsind gewachsen!\nRevanche!",
  OPP_BROCK = "Du bist zurück.\nMeine steinharten\nPOKéMON warten!",
  OPP_MISTY = "Du bist zurück!\nMeine WASSER-\nPOKéMON sind bereit!",
  OPP_LT_SURGE = "Schock mich noch\nmal, wenn du\nkannst, Kleiner!",
  OPP_ERIKA = "Wie schön, dich\nwiederzusehen.\nKämpfen wir?",
  OPP_KOGA = "Du bist gewachsen.\nBeweise es noch\neinmal.",
  OPP_BLAINE = "Ha! Feuer brennt\nbeim zweiten Mal\nnoch heller!",
  OPP_SABRINA = "Ich sah deine\nRückkehr voraus.\nIch wartete.",
  OPP_GENTLEMAN = "Wie wäre es mit\neiner gepflegten\nRevanche?",
  OPP_LORELEI = "Die kalten Winde\nrufen nach einem\nneuen Kampf.",
  OPP_CHANNELER = "Die Geister\nwünschen einen\nweiteren Kampf.",
  OPP_AGATHA = "Hehehe! Wieder\nauf Ärger aus?",
  OPP_LANCE = "Meine Drachen\nruhten lange genug.\nBeweise dich!",
}

local DECLINE = {
  OPP_YOUNGSTER = "Ha! Ich wusste es!\nZu ängstlich für\nmich!",
  OPP_BUG_CATCHER = "Piep, piep! Angst\nvor ein paar\nkleinen Käfern?",
  OPP_LASS = "Oh, verstehe.\nDu hast wohl\nAngst vor mir!",
  OPP_SAILOR = "Ahoi! Angst vor\nder See, was?",
  OPP_JR_TRAINER_M = "Feigling! Angst\nvor einem echten\nKampf?",
  OPP_JR_TRAINER_F = "Du hast Angst,\nnicht wahr? Ich\nwusste es!",
  OPP_POKEMANIAC = "Ha! Meine Sammlung\nhat dich wohl\nverschreckt!",
  OPP_SUPER_NERD = "Interessant. Angst\nist nur eine\nFehlberechnung.",
  OPP_HIKER = "Hmpf! Angst vor\neinem kleinen\nAufstieg?",
  OPP_BIKER = "Feigling! Meine\nRäder sind dir\nzu schnell!",
  OPP_BURGLAR = "Kluge Wahl. Du\nhättest verloren.",
  OPP_ENGINEER = "Angst vor einer\nPanne? Wie passend!",
  OPP_UNUSED_JUGGLER = "Angst, dass ich\ndich schwindlig\nspiele?",
  OPP_FISHER = "Kalte Füße\nbekommen? Ha!",
  OPP_SWIMMER = "Angst, die Zehen\nreinzuhalten?",
  OPP_CUE_BALL = "Ha! Angst vor\nmeinen harten\nTricks!",
  OPP_GAMBLER = "Gekniffen? Darauf\nhätte ich gesetzt!",
  OPP_BEAUTY = "Oh je. Können\ndeine POKéMON\nnicht glänzen?",
  OPP_PSYCHIC_TR = "Ich sehe deine\nAngst. Sie ist\nsehr laut.",
  OPP_ROCKER = "Zu laut für dich?\nWas für ein\nFeigling!",
  OPP_JUGGLER = "Angst, dass ich\ndich schwindlig\nspiele?",
  OPP_TAMER = "Klug. Meine Bestien\nhätten dich\nzerrissen.",
  OPP_BIRD_KEEPER = "Angst vor einem\nkleinen Flug? Ha!",
  OPP_BLACKBELT = "Eine weise Wahl.\nMeine Fäuste sind\nzu stark.",
  OPP_RIVAL1 = "Ha! Was für ein\nWeichei. Ich habe\nBesseres zu tun.",
  OPP_RIVAL2 = "Ha! Was für ein\nWeichei. Ich habe\nBesseres zu tun.",
  OPP_RIVAL3 = "Ha! Was für ein\nWeichei. Ich habe\nBesseres zu tun.",
  OPP_PROF_OAK = "Nun gut. Wenn du\nbereit bist, komm\nwieder.",
  OPP_CHIEF = "Feigling! Ich\ndachte, du hättest\nMut!",
  OPP_SCIENTIST = "Angst ist eine\nVariable, die ich\neingeplant habe.",
  OPP_GIOVANNI = "Feigling. Ich\nhatte mehr von\ndir erwartet.",
  OPP_ROCKET = "Angst vor der\nMacht von TEAM\nROCKET?",
  OPP_COOLTRAINER_M = "Zu cool für eine\nRevanche? Ha!",
  OPP_COOLTRAINER_F = "Feigling! Ich\nhielt dich für\nstark.",
  OPP_BRUNO = "Hah! Angst ist\neine Schwäche!\nTrainiere härter!",
  OPP_BROCK = "Hm. Du bist nicht\nbereit. Komm später\nwieder.",
  OPP_MISTY = "He, Angst vor ein\npaar WASSER-\nPOKéMON?",
  OPP_LT_SURGE = "Ha! Angst vor\neinem Stromschlag,\nSoldat?",
  OPP_ERIKA = "Wie schüchtern.\nIch warte, bis du\nbereit bist.",
  OPP_KOGA = "Angst ist Gift.\nStärke deinen Geist\nund kehre zurück.",
  OPP_BLAINE = "Ha! Ist dir die\nHitze zu viel?",
  OPP_SABRINA = "Auch das sah ich.\nDeine Angst ist\nklar.",
  OPP_GENTLEMAN = "Nun gut. Ein echter\nGentleman drängt\nniemanden.",
  OPP_LORELEI = "Kalte Füße im\nkalten Wind? Wie\npassend.",
  OPP_CHANNELER = "Die Geister warten.\nAngst ist\nnatürlich.",
  OPP_AGATHA = "Hehehe! Angst vor\neiner alten Frau?",
  OPP_LANCE = "Ich achte Vorsicht.\nTrainiere und\nkehre zurück.",
}

local WARN = {
  OPP_BROCK = "Hm. Mein Team ist\nviel stärker als\nzuvor. Sicher?",
  OPP_MISTY = "Meine POKéMON sind\ndeinem Team weit\nvoraus. Wirklich?",
  OPP_LT_SURGE = "Warnung: Mein Team\nist eine andere\nLiga. Weiter?",
  OPP_ERIKA = "Meine Blüten sind\ndeinem Team weit\nvoraus. Sicher?",
  OPP_KOGA = "Mein Gift ist für\ndein Team zu stark.\nBist du sicher?",
  OPP_BLAINE = "Die Hitze übersteigt\ndein Team. Bereit?",
  OPP_SABRINA = "Ich sehe: Dein Team\nliegt weit zurück.\nBist du sicher?",
  OPP_LORELEI = "Mein Eis ist viel\nstärker als dein\nTeam. Weiter?",
  OPP_BRUNO = "Hah! Meine Kraft\nüberragt deine!\nTrotzdem kämpfen?",
  OPP_AGATHA = "Hehehe! Meine\nGeister sind weit\nstärker. Sicher?",
  OPP_LANCE = "Meine Drachen sind\ndeinem Team weit\nvoraus. Wirklich?",
  OPP_RIVAL3 = "Mein Team ist nun\nviel stärker als\ndeins. Sicher?",
}

local function detectedGermanMod(mod)
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  local version = ok and GameVersion.get() or "red"
  local expected = {
    red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb",
  }
  local id = expected[version]
  return id and mod.find(id) ~= nil or false
end

return function(mod)
  local L = {}

  function L.isGerman()
    local selected = mod.options:get("language")
    if selected == "de" then return true end
    if selected == "en" then return false end
    return detectedGermanMod(mod)
  end

  function L.text(english, german)
    return L.isGerman() and german or english
  end

  function L.rematch(classId, english)
    return L.isGerman()
      and (REMATCH[classId] or "Willst du eine\nRevanche?") or english
  end

  function L.decline(classId, english)
    return L.isGerman()
      and (DECLINE[classId] or "Ha! Angst vor\neiner Revanche?") or english
  end

  function L.warning(classId, english)
    return L.isGerman()
      and (WARN[classId] or
        "Mein Team ist viel\nstärker als deins.\nBist du sicher?")
      or english
  end

  function L.rest(steps, english)
    if not L.isGerman() then return english end
    steps = math.max(1, math.floor(tonumber(steps) or 1))
    return ("Noch im Training!\nKomm in %d\n%s wieder."):format(
      steps, steps == 1 and "Schritt" or "Schritten")
  end

  return L
end
