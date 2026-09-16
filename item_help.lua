-- Compact FireRed-style Bag descriptions.  Gen-I item records contain names
-- and effects but no prose field, so derive standard families and keep exact
-- text for items whose numbers or story purpose matter.  Unknown third-party
-- items still receive an honest category description instead of a blank box.

return function(i18n)
  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local exact = {
    SACHET = { "Spritzee: hold it, then use a Linking Cord. Both consumed on evolution. No battle bonus.", "Parfi: tragen lassen, dann Verbindungsschnur anwenden. Beides wird bei der Entwicklung verbraucht. Kein Kampfbonus." },
    WHIPPED_DREAM = { "Swirlix: hold it, then use a Linking Cord. Both consumed on evolution. No battle bonus.", "Flauschling: tragen lassen, dann Verbindungsschnur anwenden. Beides wird bei der Entwicklung verbraucht. Kein Kampfbonus." },
    RAZOR_CLAW = { "Hisuian Sneasel: hold it and level up by day. Ordinary Sneasel: existing Bag evolution. Consumed on evolution.", "Hisui-Sniebel: tragen und tagsüber aufleveln. Normales Sniebel: bestehende Beutel-Entwicklung. Verbrauch bei Entwicklung." },
    LINKING_CORD = { "Solo trade evolution; keeps size. Spritzee must hold a Sachet, Swirlix a Whipped Dream. Cord and required held item are consumed.", "Solo-Tauschentwicklung; Größe bleibt erhalten. Parfi benötigt einen getragenen Duftbeutel, Flauschling ein Sahnehäubchen. Schnur und benötigtes Trageitem werden verbraucht." },
    SCROLL_OF_DARKNESS = { "Use on Kubfu: Urshifu, Single Strike Style. Consumed once.", "Auf Dakuma: Wulaosu im fokussierten Stil. Einmaliger Verbrauch." },
    SCROLL_OF_WATERS = { "Use on Kubfu: Urshifu, Rapid Strike Style. Consumed once.", "Auf Dakuma: Wulaosu im fließenden Stil. Einmaliger Verbrauch." },
    CRACKED_POT = { "Use on Phony Sinistea: Polteageist. Consumed once.", "Auf Fatalitee (Fälschung): Entwicklung zu Mortipot. Einmaliger Verbrauch." },
    UNREMARKABLE_TEACUP = { "Use on Counterfeit Poltchageist: Sinistcha. Consumed once.", "Auf Mortcha (Fälschung): Entwicklung zu Fatalitcha. Einmaliger Verbrauch." },
    DAWN_STONE = { "Male Kirlia evolves into Gallade; female Snorunt into Froslass. Consumed once.", "Männliches Kirlia wird zu Galagladi; weibliches Schneppke zu Frosdedje. Einmaliger Verbrauch." },
    AUSPICIOUS_ARMOR = { "Use on Charcadet: evolves into Armarouge. Consumed once.", "Auf Knarbon anwenden: wird zu Crimanzo. Einmaliger Verbrauch." },
    MALICIOUS_ARMOR = { "Use on Charcadet: evolves into Ceruledge. Consumed once.", "Auf Knarbon anwenden: wird zu Azugladis. Einmaliger Verbrauch." },
    TART_APPLE = { "Use on Applin: evolves into Flapple. Consumed once.", "Auf Knapfel anwenden: wird zu Drapfel. Einmaliger Verbrauch." },
    SWEET_APPLE = { "Use on Applin: evolves into Appletun. Consumed once.", "Auf Knapfel anwenden: wird zu Schlapfel. Einmaliger Verbrauch." },
    SYRUPY_APPLE = { "Use on Applin: evolves into Dipplin. Consumed once.", "Auf Knapfel anwenden: wird zu Sirapfel. Einmaliger Verbrauch." },
    ICE_STONE = { "Cetoddle becomes Cetitan; Crabrawler becomes Crabominable; Galarian Darumaka becomes Galarian Darmanitan. Consumed once.", "Flaniwal wird zu Kolowal; Krabbox zu Krawell; Galar-Flampion zu Galar-Flampivian. Einmaliger Verbrauch." },
    METAL_ALLOY = { "Use on Duraludon: evolves into Archaludon. Consumed once.", "Auf Duraludon anwenden: wird zu Briduradon. Einmaliger Verbrauch." },
    PRISM_SCALE = { "Use on Feebas: evolves into Milotic. Consumed once.", "Auf Barschwa anwenden: wird zu Milotic. Einmaliger Verbrauch." },
    DEEP_SEA_TOOTH = { "Use on Clamperl: evolves into Huntail. Consumed once.", "Auf Perlu anwenden: wird zu Aalabyss. Einmaliger Verbrauch." },
    DEEP_SEA_SCALE = { "Use on Clamperl: evolves into Gorebyss. Consumed once.", "Auf Perlu anwenden: wird zu Saganabyss. Einmaliger Verbrauch." },
    POTION = { "Restores 20 HP.", "Stellt 20 KP wieder her." },
    SUPER_POTION = { "Restores 50 HP.", "Stellt 50 KP wieder her." },
    HYPER_POTION = { "Restores 200 HP.", "Stellt 200 KP wieder her." },
    MAX_POTION = { "Fully restores one Pokémon's HP.", "Füllt die KP eines Pokémon vollständig auf." },
    FULL_RESTORE = { "Fully restores HP and cures status.", "Füllt KP vollständig auf und heilt Status." },
    REVIVE = { "Revives a fainted Pokémon with half HP.", "Belebt ein Pokémon mit halben KP wieder." },
    MAX_REVIVE = { "Revives a fainted Pokémon with full HP.", "Belebt ein Pokémon mit vollen KP wieder." },
    ANTIDOTE = { "Cures poisoning.", "Heilt Vergiftung." },
    BURN_HEAL = { "Cures a burn.", "Heilt Verbrennung." },
    ICE_HEAL = { "Thaws a frozen Pokémon.", "Taut ein eingefrorenes Pokémon auf." },
    AWAKENING = { "Wakes a sleeping Pokémon.", "Weckt ein schlafendes Pokémon." },
    PARLYZ_HEAL = { "Cures paralysis.", "Heilt Paralyse." },
    FULL_HEAL = { "Cures all status conditions.", "Heilt alle Statusprobleme." },
    FRESH_WATER = { "Restores 50 HP.", "Stellt 50 KP wieder her." },
    SODA_POP = { "Restores 60 HP.", "Stellt 60 KP wieder her." },
    LEMONADE = { "Restores 80 HP.", "Stellt 80 KP wieder her." },
    ETHER = { "Restores 10 PP to one move.", "Stellt 10 AP einer Attacke wieder her." },
    MAX_ETHER = { "Fully restores PP to one move.", "Füllt die AP einer Attacke vollständig auf." },
    ELIXER = { "Restores 10 PP to every move.", "Stellt 10 AP aller Attacken wieder her." },
    MAX_ELIXER = { "Fully restores PP to every move.", "Füllt die AP aller Attacken vollständig auf." },
    RARE_CANDY = { "Raises one Pokémon by one level.", "Erhöht den Level eines Pokémon um eins." },
    HP_UP = { "Raises a Pokémon's HP training value.", "Erhöht den KP-Trainingswert eines Pokémon." },
    PROTEIN = { "Raises the Attack training value.", "Erhöht den Angriffs-Trainingswert." },
    IRON = { "Raises the Defense training value.", "Erhöht den Verteidigungs-Trainingswert." },
    CARBOS = { "Raises the Speed training value.", "Erhöht den Initiative-Trainingswert." },
    CALCIUM = { "Raises the Special training value.", "Erhöht den Spezial-Trainingswert." },
    PP_UP = { "Raises the maximum PP of one move.", "Erhöht die maximalen AP einer Attacke." },
    ESCAPE_ROPE = { "Returns you to a dungeon's entrance.", "Bringt Dich zum Eingang eines Dungeons zurück." },
    REPEL = { "Repels weaker wild Pokémon for 100 steps.", "Hält schwächere wilde Pokémon 100 Schritte fern." },
    SUPER_REPEL = { "Repels weaker wild Pokémon for 200 steps.", "Hält schwächere wilde Pokémon 200 Schritte fern." },
    MAX_REPEL = { "Repels weaker wild Pokémon for 250 steps.", "Hält schwächere wilde Pokémon 250 Schritte fern." },
    POKE_DOLL = { "Escapes from a wild battle.", "Beendet einen Kampf gegen ein wildes Pokémon." },
    POKE_FLUTE = { "Wakes sleeping Pokémon in and out of battle.", "Weckt schlafende Pokémon im und außerhalb des Kampfes." },
    BICYCLE = { "Lets you travel faster where cycling is allowed.", "Lässt Dich dort schneller fahren, wo Radfahren erlaubt ist." },
    OLD_ROD = { "Fishes for Pokémon near water.", "Angelt an Gewässern nach Pokémon." },
    GOOD_ROD = { "A good rod for fishing near water.", "Eine gute Angel für Pokémon in Gewässern." },
    SUPER_ROD = { "The best rod for fishing near water.", "Die beste Angel für Pokémon in Gewässern." },
    EXP_ALL = { "Opens Ascendant's unlocked EXP Share settings.", "Öffnet Ascendants freigeschaltete EP-Teiler-Einstellungen." },
    COIN_CASE = { "Holds coins won or bought at the Game Corner.", "Bewahrt Münzen aus der Spielhalle auf." },
    ITEMFINDER = { "Detects hidden items in the surrounding area.", "Spürt versteckte Items in der Umgebung auf." },
    SILPH_SCOPE = { "Reveals the identity of invisible ghosts.", "Enthüllt die Identität unsichtbarer Geister." },
    CARD_KEY = { "Opens secured doors in Silph Co.", "Öffnet gesicherte Türen bei Silph Co." },
    LIFT_KEY = { "Operates the Team Rocket hideout lift.", "Bedient den Aufzug im Rocket-Versteck." },
    SECRET_KEY = { "Opens Cinnabar Island's Gym.", "Öffnet die Arena der Zinnoberinsel." },
    S_S_TICKET = { "A ticket for the S.S. Anne.", "Eine Fahrkarte für die M.S. Anne." },
    BIKE_VOUCHER = { "Can be exchanged for a Bicycle.", "Kann gegen ein Fahrrad eingetauscht werden." },
    OAKS_PARCEL = { "A parcel addressed to Professor Oak.", "Ein Paket für Professor Eich." },
    TOWN_MAP = { "Displays a map of the Kanto region.", "Zeigt eine Karte der Kanto-Region." },
    DOME_FOSSIL = { "A fossil that can be restored into Kabuto.", "Ein Fossil, aus dem Kabuto wiederbelebt werden kann." },
    HELIX_FOSSIL = { "A fossil that can be restored into Omanyte.", "Ein Fossil, aus dem Amonitas wiederbelebt werden kann." },
    OLD_AMBER = { "Amber that can be restored into Aerodactyl.", "Bernstein, aus dem Aerodactyl wiederbelebt werden kann." },
    MIGRATION_RECEIVER = { "Tracks early Johto migration signals.", "Empfängt Signale der frühen Johto-Wanderung." },
    RESONANCE_SEAL = { "Records resonance discovered during signal research.", "Speichert Resonanz aus der Signalforschung." },
    SHINY_CHARM = { "Improves supported Ascendant shiny hunts.", "Verbessert unterstützte Ascendant-Shiny-Jagden." },
    FIELD_KIT = { "Uses owned HMs in the field without taking a move slot.", "Nutzt erhaltene VMs im Feld, ohne einen Attackenplatz zu belegen." },
    TRACE_FINDER = { "Tracks sealed paths without revealing their map locations.", "Spürt versiegelte Pfade auf, ohne ihre Kartenorte zu verraten." },
    HOENN_HONEY = { "Its gentle scent attracts very rare Hoenn visitors after the Hoenn Dex is received.", "Sein sanfter Duft lockt nach Erhalt des Hoenn-Dex sehr seltene Gäste aus Hoenn an." },
    HOENN_DEX = { "Records Hoenn species and reveals their hidden Ascendant field controls.", "Erfasst Hoenn-Arten und schaltet ihre verborgenen Ascendant-Feldoptionen frei." },
    MEGA_RING = { "Allows Mega Evolution when the matching stone is owned.", "Erlaubt Mega-Entwicklung mit dem passenden Mega-Stein." },
    MEGA_STONE_CASE = { "Stores and manages Ascendant Mega Stones.", "Bewahrt Ascendant-Mega-Steine auf und verwaltet sie." },
    ASCENDANT_EXP_MULTIPLIER = { "Opens the unlocked Ascendant EXP multiplier setting.", "Öffnet Ascendants freigeschaltete EP-Multiplikator-Einstellung." },
    ASCENDANT_THUNDERHEART = { "A charged relic tied to Raichu and Gorochu.", "Ein geladenes Relikt, verbunden mit Raichu und Gorochu." },
    ASCENDANT_THUNDER_TEAR = { "A concentrated charge used in Gorochu's progression.", "Gebündelte Ladung für Gorochus Entwicklungspfad." },
    SUN_STONE = { "Triggers evolution for certain Pokémon.", "Löst bei bestimmten Pokémon eine Entwicklung aus." },
    METAL_COAT = { "Triggers evolution for certain Steel-related Pokémon.", "Löst bei bestimmten stahlbezogenen Pokémon eine Entwicklung aus." },
    KINGS_ROCK = { "Triggers evolution for certain Pokémon.", "Löst bei bestimmten Pokémon eine Entwicklung aus." },
    DRAGON_SCALE = { "Triggers Seadra's evolution into Kingdra.", "Löst Seedrakings Entwicklung aus Seemon aus." },
    UPGRADE = { "Triggers Porygon's evolution into Porygon2.", "Löst Porygons Entwicklung zu Porygon2 aus." },
    AFFECTION_RIBBON = { "Evolves Eevee into Sylveon while Generation VI rules are active.", "Entwickelt Evoli bei aktiven Gen-VI-Regeln zu Feelinara." },
  }

  local balls = {
    POKE_BALL = { "A standard ball for catching wild Pokémon.", "Ein normaler Ball zum Fangen wilder Pokémon." },
    GREAT_BALL = { "A ball with a higher catch rate than a Poké Ball.", "Ein Ball mit höherer Fangchance als ein Pokéball." },
    ULTRA_BALL = { "A high-performance ball for difficult catches.", "Ein leistungsstarker Ball für schwierige Fänge." },
    MASTER_BALL = { "Catches a wild Pokémon without fail.", "Fängt ein wildes Pokémon garantiert." },
    SAFARI_BALL = { "A special ball used in the Safari Zone.", "Ein besonderer Ball für die Safari-Zone." },
    HEAVY_BALL = { "Catch rate: +30 at 300kg, +20 at 200kg, -20 below 100kg (min. 1).", "Fangrate: +30 ab 300kg, +20 ab 200kg, -20 unter 100kg (mind. 1)." },
    LEVEL_BALL = { "Catch rate x8/x4/x2 when your level is 4x/2x/higher; otherwise x1.", "Fangrate x8/x4/x2 bei 4x/2x/höherer eigener Stufe; sonst x1." },
    LURE_BALL = { "Catch rate x3 only for a Pokémon actually hooked while fishing.", "Fangrate x3 nur für ein tatsächlich geangeltes Pokémon." },
    FAST_BALL = { "Catch rate x4 if the target's base Speed is at least 100.", "Fangrate x4 bei mindestens 100 Basis-Initiative des Ziels." },
    LOVE_BALL = { "Catch rate x8 for the same species with compatible opposite genders.", "Fangrate x8 bei gleicher Art und kompatiblen Gegengeschlechtern." },
    FRIEND_BALL = { "Normal catch rate; on success the caught Pokémon gets friendship 200.", "Normale Fangrate; bei Erfolg erhält das gefangene Pokémon Freundschaft 200." },
    MOON_BALL = { "Catch rate x4 for members of a registered Moon Stone evolution line.", "Fangrate x4 für Arten einer registrierten Mondstein-Entwicklungslinie." },
  }

  local H = {}
  function H.describe(game, id)
    local def = game and game.data and game.data.items and game.data.items[id]
    if id == "HOENN_HONEY" then
      local save = game and game.save or {}
      local carried = (tonumber((save.inventory or {})[id]) or 0) > 0
      if carried then
        return tr(
          "Smells wonderful. Even your Pokémon find the scent magical. Carry it to attract very rare Hoenn visitors.",
          "Duftet herrlich. Selbst Deine Pokémon finden den Geruch magisch. Führe ihn mit Dir, um sehr seltene Hoenn-Gäste anzulocken.")
      end
      return tr(
        "Stored in the PC, its scent cannot attract Hoenn Pokémon. Carry the jar with you to make it work.",
        "Im PC kann sein Duft keine Hoenn-Pokémon anlocken. Führe das Glas mit Dir, damit es wirkt.")
    end
    if def and def.machine then
      local move = game.data.moves and game.data.moves[def.machine.move]
      local moveName = move and move.name or def.machine.move
      if def.machine.kind == "HM" then
        return tr("HM: Teaches " .. tostring(moveName) .. "; reusable.",
          "VM: Lehrt " .. tostring(moveName) .. "; wiederverwendbar.")
      end
      return tr("TM: Teaches " .. tostring(moveName) .. "; single-use.",
        "TM: Lehrt " .. tostring(moveName) .. "; einmal verwendbar.")
    end
    local row = exact[id] or balls[id]
    if row then return tr(row[1], row[2]) end
    if tostring(id):find("MEGA_STONE", 1, true)
        or tostring(id):match("_ITE$") then
      return tr("Enables its matching Pokémon's Mega Evolution.",
        "Erlaubt dem passenden Pokémon die Mega-Entwicklung.")
    end
    if tostring(id):match("_STONE$") then
      return tr("Triggers evolution for certain Pokémon.",
        "Löst bei bestimmten Pokémon eine Entwicklung aus.")
    end
    if def and def.ball then
      return tr("A ball used to catch wild Pokémon.",
        "Ein Ball zum Fangen wilder Pokémon.")
    end
    if def and (def.keyItem or def.tossable == false) then
      return tr("An important item used during your adventure.",
        "Ein wichtiges Item für Dein Abenteuer.")
    end
    return tr("An item with a usable or progression-related effect.",
      "Ein Item mit nutzbarem oder fortschrittsbezogenem Effekt.")
  end

  return H
end
