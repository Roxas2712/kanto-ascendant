-- Read-only bilingual descriptions. Never an effect-capability authority.
local abilities={
  PARENTAL_BOND={'In Gen VI/VII, eligible attacks strike twice. The second strike has half base damage in VI, one quarter in VII. Costs one move use; multi-hit, charging and excluded moves are not duplicated.',
    'Geeignete Attacken treffen in Gen VI/VII zweimal. Der zweite Treffer hat in VI halben, in VII ein Viertel des Basisschadens. Nur ein Attackeneinsatz; Mehrfachtreffer, Ladeattacken und Ausnahmen werden nicht verdoppelt.'},
  SURGE_SURFER={'In Gen VII, doubles Speed while Electric Terrain is active. The holder need not be grounded.',
    'Verdoppelt in Gen VII bei aktivem Elektrofeld die Initiative. Der Träger muss nicht geerdet sein.'},
  NEUROFORCE={'In Gen VII, super-effective ordinary attacks deal 25% more damage. No boost to neutral, resisted or fixed damage.',
    'Sehr effektive normale Attacken verursachen in Gen VII 25% mehr Schaden. Kein Bonus für neutrale, widerstandene oder feste Schadenswerte.'},
  POWER_CONSTRUCT={'In Gen VII, eligible Zygarde changes to Complete Forme at turn end at half HP or less. Its higher maximum HP preserves HP already lost. Lasts until battle end.',
    'Geeignetes Zygarde wechselt in Gen VII am Rundenende bei höchstens halben KP zur Optimumform. Der größere KP-Höchstwert erhält bereits verlorene KP. Hält bis Kampfende an.'},
  BATTLE_BOND={'In Gen VII, Battle-Bond Greninja becomes Ash-Greninja after knocking out an opponent if another opponent remains. Water Shuriken gains power 20 and exactly three hits. Lasts until battle end.',
    'Freundschaftsakt-Quajutsu wird in Gen VII nach einem gegnerischen K. o. zu Ash-Quajutsu, sofern ein weiterer Gegner verbleibt. Wasser-Shuriken erhält Stärke 20 und genau drei Treffer. Hält bis Kampfende an.'},
  PRIMORDIAL_SEA={'In Gen VI/VII, creates heavy rain while its source remains. Boosts Water and stops damaging Fire moves. Ordinary weather cannot replace it; Air Lock and Cloud Nine suppress its effects.',
    'Erzeugt in Gen VI/VII starken Regen, solange die Quelle bleibt. Stärkt Wasser und verhindert schädigende Feuerattacken. Normales Wetter ersetzt ihn nicht; Klimaschutz und Wolke Sieben unterdrücken seine Wirkung.'},
  DESOLATE_LAND={'In Gen VI/VII, creates extreme sunlight while its source remains. Boosts Fire and stops damaging Water moves. Ordinary weather cannot replace it; Air Lock and Cloud Nine suppress its effects.',
    'Erzeugt in Gen VI/VII extremes Sonnenlicht, solange die Quelle bleibt. Stärkt Feuer und verhindert schädigende Wasserattacken. Normales Wetter ersetzt es nicht; Klimaschutz und Wolke Sieben unterdrücken seine Wirkung.'},
  DELTA_STREAM={'In Gen VI/VII, creates strong winds while its source remains. Removes only the Flying-type contribution to weaknesses; other type weaknesses remain. Ordinary weather cannot replace it.',
    'Erzeugt in Gen VI/VII starke Winde, solange die Quelle bleibt. Entfernt nur den Flug-Anteil an Schwächen; Schwächen des anderen Typs bleiben. Normales Wetter ersetzt es nicht.'},
  SYMBIOSIS={'Gives its held item to an active ally after that ally consumes an item. Protected equipment cannot be passed. No effect from party reserves or in singles; not an item duplication.',
    'Gibt sein getragenes Item an einen aktiven Partner weiter, nachdem dieser ein Item verbraucht. Geschützte Ausrüstung bleibt beim Träger. Keine Wirkung von der Bank oder im Einzelkampf; keine Item-Kopie.'},
  RECEIVER={'Copies an active ally\'s ability when that ally faints, until switching out or battle end. Certain special abilities cannot be inherited. No effect from opponents or party reserves; no trigger in singles.',
    'Übernimmt die Fähigkeit eines aktiven Partners, wenn dieser besiegt wird, bis zum Auswechseln oder Kampfende. Bestimmte Spezialfähigkeiten sind ausgeschlossen. Keine Wirkung bei Gegnern oder Pokémon auf der Bank; kein Auslöser im Einzelkampf.'},
  POWER_OF_ALCHEMY={'Copies an active ally\'s ability when that ally faints, until switching out or battle end. Certain special abilities cannot be inherited. No effect from opponents or party reserves; no trigger in singles.',
    'Übernimmt die Fähigkeit eines aktiven Partners, wenn dieser besiegt wird, bis zum Auswechseln oder Kampfende. Bestimmte Spezialfähigkeiten sind ausgeschlossen. Keine Wirkung bei Gegnern oder Pokémon auf der Bank; kein Auslöser im Einzelkampf.'},
  HEALER={'At turn end, a 30% chance to cure each adjacent active ally\'s major status before poison/burn damage. Does not heal HP, confusion, the holder or party reserves. No partner effect in singles.',
    'Am Rundenende werden Statusprobleme jedes benachbarten aktiven Partners mit 30% Chance vor Gift-/Verbrennungsschaden geheilt. Heilt keine KP, Verwirrung, den Träger oder Pokémon auf der Bank. Kein Partnereffekt im Einzelkampf.'},
  TELEPATHY={'Avoids damaging moves from active allies, including fixed-damage moves. Does not block opponents, status moves or confusion self-damage. Mold Breaker bypasses it. No protection in singles.',
    'Weicht Schadensattacken aktiver Partner aus, auch solchen mit festem Schaden. Kein Schutz gegen Gegner, Statusattacken oder eigenen Verwirrungsschaden. Überbrückung umgeht es. Kein Schutz im Einzelkampf.'},
  BATTERY={'Raises active allies\' special move power by 30%. Does not boost its own moves, physical attacks or fixed damage. No bonus from party reserves or in singles.',
    'Erhöht die Stärke spezieller Attacken aktiver Partner um 30%. Keine Wirkung auf eigene oder physische Attacken und festen Schaden. Kein Bonus von der Bank oder im Einzelkampf.'},
  FRIEND_GUARD={'Reduces active allies\' ordinary attack damage by 25%, not its own damage. Does not reduce fixed or residual damage. Mold Breaker bypasses it. No bonus from party reserves or in singles.',
    'Verringert normalen Attackenschaden gegen aktive Partner um 25%, nicht den eigenen Schaden. Kein Schutz vor festem oder Restschaden. Überbrückung umgeht es. Kein Bonus von der Bank oder im Einzelkampf.'},
  DISGUISE={'Mimikyu blocks the first damaging hit, including confusion damage. Other effects can still occur. Its busted costume persists until battle end or fainting. In Gen VII breaking it costs no HP.',
    'Mimigma fängt den ersten Schadenstreffer ab, auch Verwirrungsschaden. Zusatzeffekte können wirken. Das Kostüm bleibt bis Kampfende oder K. o. kaputt. In Gen VII kostet das Zerbrechen keine KP.'},
  STANCE_CHANGE={'Aegislash attacks in Blade Forme and returns to Shield Forme with King\'s Shield. Gen VI changes before action-blocking status checks; Gen VII changes only when the move proceeds.',
    'Durengard greift in der Klingenform an und wechselt mit Königsschild zur Schildform. Gen VI wechselt vor aktionsverhindernden Statusprüfungen; Gen VII erst, wenn die Attacke ausgeführt wird.'},
  SCHOOLING={'From level 20, Wishiwashi schools when above 25% HP. Checked on entry and at each turn end. At 25% HP or less it becomes solo again.',
    'Ab Level 20 bildet Lusardin bei mehr als 25% KP einen Schwarm. Prüfung beim Einwechseln und am Rundenende. Bei höchstens 25% KP wird es wieder zur Einzelform.'},
  SHIELDS_DOWN={'Minior keeps its Meteor form above half HP; at half HP or less its colored Core emerges. Checked on entry and at turn end. The Meteor form blocks major status conditions and Yawn.',
    'Meteno behält über halben KP seinen Meteorpanzer; bei höchstens halben KP erscheint der farbige Kern. Prüfung beim Einwechseln und am Rundenende. Der Panzer verhindert Statusprobleme und Gähner.'},
  ZEN_MODE={'At turn end, Darmanitan enters Zen Mode at half HP or less, changing stats and gaining Psychic type. Healing above half HP restores Standard Mode at turn end.',
    'Flampivian wechselt am Rundenende bei höchstens halben KP in den Trance-Modus: andere Kampfwerte und zusätzlich Psycho. Über halben KP kehrt es am Rundenende zur Normalform zurück.'},
  DANCER={'Copies another Pokemon\'s successful dance move without spending PP or the holder\'s normal turn. Does not chain other Dancer reactions. Status conditions and move restrictions still apply.',
    'Macht einen erfolgreichen Tanz eines anderen Pokémon nach, ohne AP oder den eigenen normalen Zug zu verbrauchen. Keine Ketten durch andere Tänzer. Statusprobleme und Attackensperren gelten weiter.'},
  MAGIC_BOUNCE={'Reflects eligible opposing status moves and Sappy Seed once, including stat drops, Taunt and Roar. Costs no extra PP; does not use the holder\'s turn. Mold Breaker can bypass it.',
    'Wirft geeignete gegnerische Statusattacken und Sprießbomben einmal zurück, auch Statuswertsenkungen, Verhöhner und Brüller. Kostet keine zusätzlichen AP und keinen eigenen Zug. Überbrückung kann es umgehen.'},
  KLUTZ={'Disables held-item battle effects without removing the item. Training-item Speed penalties and Primal Orbs are exceptions. Items can still be traded; possession still matters for Acrobatics.',
    'Deaktiviert die Kampfwirkung getragener Items, ohne sie zu entfernen. Initiative-Mali von Trainingsitems und Protomorphose-Kugeln sind ausgenommen. Items bleiben tauschbar; ihr Besitz zählt weiterhin für Akrobatik.'},
  STICKY_HOLD={'Prevents opponents from taking held items. Mold Breaker can bypass it. In Gen V onward, a fainted holder is no longer protected.',
    'Schützt getragene Items vor gegnerischem Raub. Überbrückung kann den Schutz umgehen. Ab Gen V schützt die Fähigkeit ein besiegtes Pokémon nicht mehr.'},
  PICKPOCKET={'After being hit by contact, steals the attacker\'s item if the holder has none. Does not work through Substitute or with no surviving holder.',
    'Stiehlt nach einem Kontakttreffer das Item des Angreifers, wenn es selbst keines trägt. Wirkt nicht durch Delegator oder nach dem eigenen K.O.'},
  MAGICIAN={'After a damaging attack, steals the target\'s item if the user holds none. Protected equipment cannot be stolen.',
    'Stiehlt nach einer Schadensattacke das Item des Ziels, wenn es selbst keines trägt. Geschützte Ausrüstung kann nicht gestohlen werden.'},
  ELECTRIC_SURGE={'Creates Electric Terrain on entry for 5 turns. Grounded Electric attacks gain 50% power and grounded Pokemon cannot fall asleep.',
    'Erzeugt beim Eintritt 5 Runden Elektrofeld. Geerdete Elektro-Attacken erhalten +50% Stärke; geerdete Pokémon können nicht einschlafen.'},
  GRASSY_SURGE={'Creates Grassy Terrain on entry for 5 turns. Boosts grounded Grass attacks, heals grounded Pokemon and weakens Earthquake, Bulldoze and Magnitude.',
    'Erzeugt beim Eintritt 5 Runden Grasfeld. Stärkt geerdete Pflanzen-Attacken, heilt geerdete Pokémon und schwächt Erdbeben, Dampfwalze sowie Intensität.'},
  MISTY_SURGE={'Creates Misty Terrain on entry for 5 turns. Grounded targets resist Dragon moves and new status conditions, including confusion in Gen VII.',
    'Erzeugt beim Eintritt 5 Runden Nebelfeld. Geerdete Ziele nehmen weniger Drachenschaden und sind vor neuen Statusproblemen geschützt, in Gen VII auch vor Verwirrung.'},
  PSYCHIC_SURGE={'Creates Psychic Terrain on entry for 5 turns. Boosts grounded Psychic attacks by 50% and blocks opposing priority moves against grounded targets.',
    'Erzeugt beim Eintritt 5 Runden Psychofeld. Stärkt geerdete Psycho-Attacken um 50% und blockt gegnerische Prioritäts-Attacken gegen geerdete Ziele.'},
  GRASS_PELT={'Defense increases by 50% while Grassy Terrain is active.',
    'Die Verteidigung steigt bei aktivem Grasfeld um 50%.'},
  MEGA_LAUNCHER={'Pulse and aura move power +50%. Heal Pulse restores 75% of the target’s maximum HP instead of 50%.',
    'Puls- und Aura-Attacken erhalten +50% Stärke. Heilwoge heilt 75% statt 50% der maximalen KP des Ziels.'},
  ANALYTIC={'Move power increases by 30% after the opposing Pokemon has acted, including a switch.',
    'Die Attackenstärke steigt um 30%, wenn das gegnerische Pokémon bereits gehandelt hat, auch bei einem Wechsel.'},
  STAKEOUT={'Doubles attacking stats against an opponent that switched in during the current turn.',
    'Verdoppelt die Angriffswerte gegen einen Gegner, der im laufenden Zug eingewechselt wurde.'},
  MAGIC_GUARD={'Prevents indirect HP damage, not direct hits, confusion, Struggle or self-sacrifice. Gen IV also prevents full paralysis, but not Ooze/crash damage.',
    'Verhindert indirekten KP-Schaden, nicht direkte Treffer, Verwirrung, Verzweifler oder Selbstopfer. Gen IV verhindert auch volle Paralyse, aber nicht Kloakensoßen-/Sprungschaden.'},
  NORMALIZE={'Converts eligible moves to Normal. From Gen VII they also gain 20% power; variable-type exceptions remain.',
    'Wandelt geeignete Attacken in Normal um. Ab Gen VII steigt ihre Stärke zusätzlich um 20%; Ausnahmen für variable Typen bleiben.'},
  PIXILATE={'Eligible Normal moves become Fairy: +30% power in Gen VI, +20% in Gen VII.',
    'Geeignete Normal-Attacken werden zu Fee: +30% Stärke in Gen VI, +20% in Gen VII.'},
  AERILATE={'Eligible Normal moves become Flying: +30% power in Gen VI, +20% in Gen VII.',
    'Geeignete Normal-Attacken werden zu Flug: +30% Stärke in Gen VI, +20% in Gen VII.'},
  REFRIGERATE={'Eligible Normal moves become Ice: +30% power in Gen VI, +20% in Gen VII.',
    'Geeignete Normal-Attacken werden zu Eis: +30% Stärke in Gen VI, +20% in Gen VII.'},
  GALVANIZE={'Eligible Normal moves become Electric and gain 20% power.',
    'Geeignete Normal-Attacken werden zu Elektro und erhalten 20% mehr Stärke.'},
  LIQUID_VOICE={'Sound-based moves become Water moves. Does not provide an additional power boost.',
    'Klangbasierte Attacken werden zu Wasser-Attacken. Kein zusätzlicher Stärkebonus.'},
  TRIAGE={'Healing moves, including draining moves, gain +3 priority. Other status moves keep their normal priority.',
    'Heilattacken einschließlich Saugattacken erhalten +3 Priorität. Andere Statusattacken behalten ihre normale Priorität.'},
  DAZZLING={'Blocks opposing priority moves aimed at it. Does not block normal-priority attacks; Mold Breaker can bypass it.',
    'Blockt gegnerische Prioritäts-Attacken gegen sich. Normale Priorität bleibt wirksam; Überbrückung kann den Schutz umgehen.'},
  QUEENLY_MAJESTY={'Blocks opposing priority moves aimed at it. Does not block normal-priority attacks; Mold Breaker can bypass it.',
    'Blockt gegnerische Prioritäts-Attacken gegen sich. Normale Priorität bleibt wirksam; Überbrückung kann den Schutz umgehen.'},
  LEVITATE={'Avoids Ground moves while airborne. Gravity, grounding attacks and Mold Breaker can overcome it.',
    'Vermeidet Boden-Attacken im Schwebezustand. Erdanziehung, herunterholende Attacken und Überbrückung können dies umgehen.'},
  SLOW_START={'Attack and Speed are halved for the first five turns after entry. Switching out resets the timer.',
    'Angriff und Initiative sind nach dem Einwechseln fünf Runden halbiert. Auswechseln setzt den Zähler zurück.'},
  TRUANT={'Alternates acting and loafing. Loafing uses no move PP. Sleep and interruption timing follows the active generation.',
    'Wechselt zwischen Handeln und Faulenzen. Faulenzen kostet keine AP. Schlaf und Unterbrechungen folgen der aktiven Generation.'},
  BAD_DREAMS={'At turn end, sleeping foes lose 1/8 max HP. Magic Guard prevents this damage.',
    'Schlafende Gegner verlieren am Rundenende 1/8 der maximalen KP. Magieschild verhindert den Schaden.'},
  SOUL_HEART={'Whenever another Pokemon faints, raises Sp. Atk by 1 stage while this holder survives.',
    'Wird ein anderes Pokémon besiegt, steigt der Spezial-Angriff um 1 Stufe, solange der Träger kampffähig ist.'},
  INNARDS_OUT={'When a move knocks it out, the attacker loses the HP removed by the final hit. Magic Guard prevents this.',
    'Besiegt eine Attacke den Träger, verliert der Angreifer die vom letzten Treffer abgezogenen KP. Magieschild schützt davor.'},
  BERSERK={'After an attack drops HP from above half to half or less, Special Attack rises one stage. Does not trigger on residual damage or a knockout.',
    'Sinken die KP durch eine Attacke von über der Hälfte auf die Hälfte oder weniger, steigt der Spezial-Angriff um 1 Stufe. Kein Auslösen durch Rundenschaden oder bei K.O.'},
  PROTEAN={'Before using a move, takes that move\'s type. Can change again with each move in Gen VI/VII; saved species types stay unchanged.',
    'Nimmt vor einer Attacke deren Typ an. In Gen VI/VII bei jeder Attacke erneut möglich; die gespeicherten Art-Typen bleiben unverändert.'},
  CURSED_BODY={'After a damaging hit, has a 30% chance to disable that attack for 4 turns. Contact is not required; can activate even when knocked out.',
    'Blockiert die gegnerische Attacke nach einem Schadenstreffer zu 30% für 4 Runden. Kein Kontakt nötig; kann auch beim eigenen K.O. auslösen.'},
  MUMMY={'When hit by contact, replaces the attacker\'s ability with Mummy until it switches out. Special protected abilities cannot be replaced; saved ability slots stay unchanged.',
    'Ersetzt bei einem Kontakttreffer die Fähigkeit des Angreifers bis zum Wechsel durch Mumie. Besonders geschützte Fähigkeiten bleiben erhalten; der gespeicherte Slot wird nicht verändert.'},
  HARVEST={'At turn end, has a 50% chance to regrow the last consumed Berry if no item is held; 100% in effective sunshine. Remembers consumption across switches, not across battles. Unnerve prevents eating, not regrowth.',
    'Gewinnt am Rundenende die letzte verbrauchte Beere zu 50% zurück, wenn kein Item getragen wird; bei wirksamer Sonne zu 100%. Merkt den Verbrauch über Wechsel, nicht über Kämpfe. Anspannung verhindert Essen, nicht Nachwachsen.'},
  FLOWER_VEIL={'If the holder is Grass-type, blocks opposing stat drops, major status and new Yawn. Does not block its own Rest or item status, or cure existing effects. In singles it does not protect the opponent.',
    'Als Pflanzen-Typ gegen gegnerische Statuswertsenkungen, Hauptstatus und neu eingesetzte Gähner geschützt. Eigene Erholung und Item-Status bleiben möglich; heilt keine bestehenden Effekte. Schützt im Einzelkampf nicht den Gegner.'},
  TRACE={'Copies the opposing ability on entry until switching out. Protected special abilities cannot be copied from Gen IV onward; if an uncopyable ability is present, checks again later.',
    'Kopiert beim Einwechseln die gegnerische Fähigkeit bis zum Wechsel. Ab Gen IV werden besondere geschützte Fähigkeiten nicht kopiert; ohne geeignete Fähigkeit wird später erneut geprüft.'},
  STENCH={'From Gen V, damaging hits have a 10% flinch chance against a foe that has not acted. Does not add to moves with their own flinch chance.',
    'Ab Gen V können Schadenstreffer zu 10% zurückschrecken lassen, bevor der Gegner handelt. Kein Zusatz zu Attacken mit eigener Chance.'},
  CORROSION={'Can poison Poison and Steel types. Does not bypass ability, Substitute or terrain protection; Poison attacks still cannot damage Steel.',
    'Kann Gift- und Stahl-Typen vergiften. Umgeht weder Schutzfähigkeiten noch Delegator oder Feldschutz; Giftangriffe schaden Stahl weiterhin nicht.'},
  COLOR_CHANGE={'A damaging hit changes its type to that move\'s type. Gen III/IV: between hits; from Gen V: after the move.',
    'Ein Schadenstreffer ändert seinen Typ zum Attackentyp. Gen III/IV: zwischen Treffern; ab Gen V: nach der Attacke.'},
  ARENA_TRAP={'Grounded foes cannot switch or flee. Flying and levitating foes escape; Ghost types are exempt from Gen VI.',
    'Gegner am Boden können nicht wechseln oder fliehen. Fliegende und schwebende Gegner entkommen; ab Gen VI auch Geist-Typen.'},
  MAGNET_PULL={'Steel-type foes cannot switch or flee. Ghost types are exempt from Gen VI; Shed Shell permits switching.',
    'Stahl-Gegner können nicht wechseln oder fliehen. Ab Gen VI sind Geist-Typen ausgenommen; Wechselhülle erlaubt den Wechsel.'},
  SHADOW_TAG={'Foes cannot switch or flee. From Gen IV another Shadow Tag escapes; from Gen VI Ghost types also escape.',
    'Gegner können nicht wechseln oder fliehen. Ab Gen IV entkommt eine andere Wegsperre; ab Gen VI auch Geist-Typen.'},
  SCRAPPY={'Normal and Fighting moves can hit Ghost types. Other resistances and immunities remain. No Intimidate immunity before Gen VIII.',
    'Normal- und Kampf-Attacken treffen Geist-Typen. Andere Resistenzen und Immunitäten bleiben. Vor Gen VIII kein Schutz vor Bedroher.'},
  HEATPROOF={'Halves incoming Fire damage and burn damage.','Halbiert eintreffenden Feuerschaden und Verbrennungsschaden.'},
  VICTORY_STAR={'Its moves have 10% higher accuracy.','Seine Attacken haben 10% höhere Genauigkeit.'},
  MERCILESS={'Always lands critical hits against poisoned targets unless their ability prevents criticals.',
    'Erzielt gegen vergiftete Ziele immer Volltreffer, sofern deren Fähigkeit Volltreffer nicht verhindert.'},
  FULL_METAL_BODY={'Foes cannot lower its stats, even with Mold Breaker. Self-inflicted drops still apply.',
    'Gegner können seine Statuswerte auch mit Überbrückung nicht senken. Eigene Senkungen wirken weiterhin.'},
  WATER_COMPACTION={'A damaging Water hit raises Defense by 2 stages. Does not prevent the damage.',
    'Ein schädigender Wassertreffer erhöht die Verteidigung um 2 Stufen. Der Schaden wird nicht verhindert.'},
  GOOEY={'Contact lowers the attacker’s Speed by 1 stage.','Kontakt senkt die Initiative des Angreifers um 1 Stufe.'},
  TANGLING_HAIR={'Contact lowers the attacker’s Speed by 1 stage.','Kontakt senkt die Initiative des Angreifers um 1 Stufe.'},
  INFILTRATOR={'Bypasses Reflect, Light Screen, Mist and Safeguard; from Gen VI also bypasses Substitute without breaking it.',
    'Umgeht Reflektor, Lichtschild, Weißnebel und Bodyguard; ab Gen VI auch Delegator, ohne ihn zu zerstören.'},
  HEAVY_METAL={'Doubles its weight, changing weight-based move power.','Verdoppelt sein Gewicht und verändert dadurch gewichtsabhängige Attacken.'},
  LIGHT_METAL={'Halves its weight, changing weight-based move power.','Halbiert sein Gewicht und verändert dadurch gewichtsabhängige Attacken.'},
  UNBURDEN={'Losing or using its held item doubles Speed while it holds no item. Resets on switching or losing the ability.',
    'Nach Verbrauch oder Verlust des Trageitems verdoppelt sich die Initiative ohne Item. Wechsel oder Fähigkeitsverlust setzen den Effekt zurück.'},
  MOODY={'Each turn raises one random stat by 2 and lowers a different stat by 1. Gen V–VII also includes accuracy and evasion.',
    'Erhöht je Runde einen zufälligen Statuswert um 2 und senkt einen anderen um 1. In Gen V–VII auch Genauigkeit und Fluchtwert.'},
  LIQUID_OOZE={'HP-draining moves and Leech Seed hurt their user instead of healing it. Dream Eater is included from Gen V.',
    'KP-saugende Attacken und Egelsamen schaden dem Sauger statt ihn zu heilen. Traumfresser zählt erst ab Gen V dazu.'},
  DARK_AURA={'Boosts Dark moves from either side by about 33%. Does not stack with another Dark Aura.',
    'Verstärkt Unlicht-Attacken beider Seiten um etwa 33%. Zwei Dunkelauren addieren sich nicht.'},
  FAIRY_AURA={'Boosts Fairy moves from either side by about 33%. Does not stack with another Fairy Aura.',
    'Verstärkt Feen-Attacken beider Seiten um etwa 33%. Zwei Feenauren addieren sich nicht.'},
  AURA_BREAK={'Reverses Dark Aura and Fairy Aura: affected moves deal 25% less damage instead.',
    'Kehrt Dunkel- und Feenaura um: Betroffene Attacken werden stattdessen um 25% abgeschwächt.'},
  OBLIVIOUS={'Prevents infatuation and Captivate; from Gen VI also prevents Taunt. Does not block Intimidate in Gen I–VII.',
    'Verhindert Verliebtheit und Liebreiz; ab Gen VI auch Verhöhner. Blockt Bedroher in Gen I–VII nicht.'},
  GLUTTONY={'Pinch berries normally eaten at 1/4 HP are eaten at 1/2 HP instead. Does not change Oran or Sitrus thresholds.',
    'Notfallbeeren mit 1/4-KP-Grenze werden schon bei 1/2 KP gegessen. Sinel- und Tsitrubeeren behalten ihre Grenze.'},
  CHEEK_POUCH={'After eating a berry, restores another 1/3 max HP.','Nach dem Essen einer Beere werden zusätzlich 1/3 der maximalen KP geheilt.'},
  NO_GUARD={'Moves by or against it do not miss, including during Fly or Dig. Type immunity and OHKO level limits remain.',
    'Attacken von ihm und gegen es verfehlen nicht, auch während Fliegen oder Schaufler. Typenimmunität und K.-o.-Levelgrenzen bleiben.'},
  WONDER_SKIN={'Incoming status moves use base accuracy 50 before accuracy and evasion modifiers.',
    'Gegnerische Statusattacken nutzen Basisgenauigkeit 50 vor Genauigkeits- und Fluchtwert-Modifikatoren.'},
  SWEET_VEIL={'Prevents sleep, including Rest and Yawn.','Verhindert Schlaf, einschließlich Erholung und Gähner.'},
  LONG_REACH={'Its attacks make no contact, avoiding contact retaliation.','Seine Attacken lösen keinen Kontakt aus und vermeiden dadurch Kontaktreaktionen.'},
  MOLD_BREAKER={'Its moves bypass ignorable defensive abilities. Does not disable held items or contact retaliation.',
    'Seine Attacken umgehen ignorierbare Schutzfähigkeiten. Trageitems und Kontaktreaktionen bleiben wirksam.'},
  TERAVOLT={'Its moves bypass ignorable defensive abilities. Prism Armor and Shadow Shield remain effective.',
    'Seine Attacken umgehen ignorierbare Schutzfähigkeiten. Prismarüstung und Phantomschutz bleiben wirksam.'},
  TURBOBLAZE={'Its moves bypass ignorable defensive abilities. Prism Armor and Shadow Shield remain effective.',
    'Seine Attacken umgehen ignorierbare Schutzfähigkeiten. Prismarüstung und Phantomschutz bleiben wirksam.'},
  SHEER_FORCE={'Moves with additional effects gain 30% power but lose those effects. Recoil and stat costs remain.',
    'Attacken mit Zusatzeffekten sind 30% stärker, verlieren aber diese Effekte. Rückstoß und Statuswert-Kosten bleiben.'},
  FLUFFY={'Halves contact damage, doubles Fire damage. A Fire contact hit combines both factors.',
    'Halbiert Kontaktschaden, verdoppelt Feuerschaden. Bei Feuerkontakt werden beide Faktoren verrechnet.'},
  WATER_BUBBLE={'Water attacks use double attacking stats; Fire hits use half. Prevents burns.',
    'Wasserattacken nutzen doppelte Angriffswerte; Feuertreffer halbe. Verhindert Verbrennungen.'},
  PRISM_ARMOR={'Super-effective damage is reduced by 25%.','Sehr effektiver Schaden wird um 25% vermindert.'},
  SHADOW_SHIELD={'At full HP, incoming attack damage is halved.','Bei vollen KP wird eingehender Angriffsschaden halbiert.'},
  MOXIE={'Defeating a foe with a move raises Attack 1 stage. No boost if the attacker also faints.',
    'Besiegt es einen Gegner mit einer Attacke, steigt der Angriff um 1 Stufe. Kein Bonus, wenn der Angreifer ebenfalls fällt.'},
  BEAST_BOOST={'A move KO raises its highest stat 1 stage; stage and held-item boosts do not decide the stat.',
    'Nach einem Attacken-K.-o. steigt der höchste Statuswert um 1 Stufe; Stufen und Trageitem-Boni bestimmen die Auswahl nicht.'},
  POISON_TOUCH={'Contact attacks have a 30% chance to poison the foe. Substitute and Shield Dust prevent this.',
    'Kontaktattacken vergiften den Gegner mit 30% Chance. Delegator und Puderabwehr verhindern dies.'},
  SKILL_LINK={'Ordinary 2–5-hit moves use 5 hits if the target survives. Fixed two-hit moves stay two-hit.',
    'Normale 2–5-Treffer-Attacken treffen 5-mal, sofern das Ziel überlebt. Feste Doppeltreffer bleiben Doppeltreffer.'},
  DEFEATIST={'At half HP or less, Attack and Sp. Atk are halved.',
    'Bei höchstens halben KP werden Angriff und Spezial-Angriff halbiert.'},
  RIVALRY={'Move power +25% against the same gender, -25% against the opposite gender. No change for genderless Pokemon.',
    'Attackenstärke +25% bei gleichem, -25% bei anderem Geschlecht. Keine Änderung bei geschlechtslosen Pokémon.'},
  UNAWARE={'Ignores the foe\'s attacking/defending stat and accuracy/evasion stages, not Speed or your own stages.',
    'Ignoriert gegnerische Angriffs-/Abwehr-, Genauigkeits-/Fluchtwertstufen, nicht Initiative oder eigene Stufen.'},
  FRISK={'On entering battle, reveals the foe\'s held item. Does not steal it.',
    'Zeigt beim Einwechseln das getragene Item des Gegners. Stiehlt es nicht.'},
  DOWNLOAD={'On entry, raises Attack if the foe\'s Defense is lower than Sp. Def; otherwise raises Sp. Atk.',
    'Beim Einwechseln: Angriff steigt, falls die gegnerische Abwehr niedriger als die Spezial-Abwehr ist; sonst Spezial-Angriff.'},
  ANTICIPATION={'On entry, warns of a foe\'s super-effective or one-hit-KO attack. Does not prevent damage.',
    'Warnt beim Einwechseln vor sehr effektiven oder K.O.-Attacken des Gegners. Kein Schadensschutz.'},
  FOREWARN={'On entry, reveals one of the foe\'s strongest moves. Special-power moves use their historical ranking.',
    'Zeigt beim Einwechseln eine der stärksten gegnerischen Attacken. Sonderstärken werden generationstreu bewertet.'},
  CONTRARY={'Reverses stat-stage increases and decreases. Haze still resets stages.',
    'Kehrt Erhöhungen und Senkungen von Statuswertstufen um. Dunkelnebel setzt sie weiterhin zurück.'},
  SIMPLE={'Doubles stat-stage changes from Gen5. In Gen4, doubles their effect instead; limits still apply.',
    'Verdoppelt ab Gen5 Änderungen von Statuswertstufen. In Gen4 deren Wirkung; Grenzen bleiben bestehen.'},
  DEFIANT={'When a foe actually lowers a stat stage, Attack rises 2 stages. Own costs do not trigger it.',
    'Senkt ein Gegner tatsächlich eine Statuswertstufe, steigt der Angriff um 2 Stufen. Keine Auslösung durch eigene Kosten.'},
  COMPETITIVE={'When a foe actually lowers a stat stage, Sp. Atk rises 2 stages. Own costs do not trigger it.',
    'Senkt ein Gegner tatsächlich eine Statuswertstufe, steigt der Spezial-Angriff um 2 Stufen. Nicht durch eigene Kosten.'},
  ROCK_HEAD={'Prevents recoil from attacks. Does not prevent Struggle recoil or crash damage.',
    'Verhindert Rückstoß durch Angriffe. Nicht den Rückstoß von Verzweifler oder Schaden nach einem Sprungkick-Fehlschlag.'},
  RECKLESS={'Recoil and crash move power +20%. Struggle is unaffected.',
    'Rückstoß- und Sprungkick-Attacken: Stärke +20%. Verzweifler bleibt unverändert.'},
  UNNERVE={'The opposing Pokemon cannot eat held berries while this holder is active. Does not block Leftovers.',
    'Das gegnerische Pokémon kann keine getragenen Beeren essen, solange der Träger aktiv ist. Blockt keine Überreste.'},
  SOUNDPROOF={'Blocks incoming sound attacks and targeted sound status moves.',
    'Blockt gegnerische Schall-Angriffe und gezielte Schall-Statusattacken.'},
  BULLETPROOF={'Blocks ball and bomb attacks, without healing.',
    'Blockt Kugel- und Bomben-Attacken, ohne KP zu heilen.'},
  OVERCOAT={'Prevents sandstorm and hail damage. From Gen6, also blocks powder and Effect Spore.',
    'Verhindert Sandsturm- und Hagelschaden. Ab Gen6 auch Schutz vor Pulverattacken und Sporenwirt.'},
  JUSTIFIED={'A damaging Dark hit raises Attack 1 stage. Does not prevent its damage.',
    'Ein Schadenstreffer vom Typ Unlicht erhöht den Angriff um 1 Stufe. Verhindert nicht den Schaden.'},
  RATTLED={'Damaging Bug, Ghost or Dark hits raise Speed 1 stage. Does not prevent damage.',
    'Schadenstreffer vom Typ Käfer, Geist oder Unlicht erhöhen die Initiative um 1 Stufe. Kein Schadensschutz.'},
  ANGER_POINT={'A survived critical hit maximizes Attack.','Ein überlebter Volltreffer maximiert den Angriff.'},
  AFTERMATH={'If a contact hit defeats it, the attacker loses 1/4 max HP. Damp prevents this.',
    'Wird es durch Kontakt besiegt, verliert der Angreifer 1/4 max. KP. Feuchtigkeit verhindert dies.'},
  DAMP={'Prevents self-destruction moves and Aftermath while active. PP is still spent.',
    'Verhindert Selbstzerstörungsattacken und Finalschlag, solange aktiv. AP werden trotzdem verbraucht.'},
  IRON_FIST={'Punching move power +20%.','Stärke von Faust-Attacken +20%.'},
  STRONG_JAW={'Biting move power +50%.','Stärke von Biss-Attacken +50%.'},
  TOUGH_CLAWS={'Contact move power +30%.','Stärke von Kontakt-Attacken +30%.'},
  STEELWORKER={'For Steel attacks: attacking stat +50%.','Bei Stahl-Attacken: Angriffswert +50%.'},
  FUR_COAT={'Doubles Defense against physical attacks.','Verdoppelt die Verteidigung gegen physische Attacken.'},
  MOTOR_DRIVE={'Electric moves do no damage and raise Speed 1 stage, even at full HP.',
    'Elektro-Attacken wirken nicht und erhöhen die Initiative um 1 Stufe, auch bei vollen KP.'},
  LIGHTNING_ROD={'Electric moves do no damage and raise Sp. Atk 1 stage, even at full HP.',
    'Elektro-Attacken wirken nicht und erhöhen den Spezial-Angriff um 1 Stufe, auch bei vollen KP.'},
  STORM_DRAIN={'Water moves do no damage and raise Sp. Atk 1 stage, even at full HP.',
    'Wasser-Attacken wirken nicht und erhöhen den Spezial-Angriff um 1 Stufe, auch bei vollen KP.'},
  SAP_SIPPER={'Grass moves do no damage and raise Attack 1 stage, including targeted Grass status moves.',
    'Pflanzen-Attacken wirken nicht und erhöhen den Angriff um 1 Stufe, auch gezielte Pflanzen-Statusattacken.'},
  PRESSURE={'In battle, opposing moves targeting it cost 1 extra PP, even on a miss. Self-only moves are unaffected.',
    'Im Kampf: Gegnerische Attacken gegen den Träger kosten 1 AP mehr, auch bei Fehlschlägen. Reine Selbst-Attacken bleiben unverändert.'},
  SAND_FORCE={'In sandstorms: Ground, Rock and Steel move power +30%. Prevents sandstorm damage.',
    'Im Sandsturm: Stärke von Boden-, Gesteins- und Stahl-Attacken +30%. Verhindert Sandsturmschaden.'},
  DRY_SKIN={'Water hits heal 1/4 max HP. Rain heals 1/8 each turn; sun costs 1/8. Fire move power against it +25%.',
    'Wassertreffer heilen 1/4 max. KP. Regen heilt pro Runde 1/8; Sonne kostet 1/8. Feuer-Attacken gegen den Träger: Stärke +25%.'},
  SOLAR_POWER={'In sun: Special Attack +50%, but loses 1/8 max HP each turn. Can faint from this loss.',
    'Bei Sonne: Spezial-Angriff +50%, aber pro Runde Verlust von 1/8 max. KP. Kann dadurch besiegt werden.'},
  RAIN_DISH={'In rain, restores 1/16 max HP each turn. Does not cure status.',
    'Heilt im Regen jede Runde 1/16 der maximalen KP. Heilt keine Statusprobleme.'},
  ICE_BODY={'In hail, restores 1/16 max HP each turn and prevents hail damage.',
    'Heilt im Hagel jede Runde 1/16 der maximalen KP und verhindert Hagelschaden.'},
  HYDRATION={'At the end of a rainy turn, cures poison, burn, paralysis, sleep or freezing. Not confusion.',
    'Heilt am Rundenende im Regen Gift, Brand, Paralyse, Schlaf oder Frost. Keine Verwirrung.'},
  SWIFT_SWIM={'Doubles Speed in rain. Weather suppression disables the boost.',
    'Verdoppelt die Initiative bei Regen. Nicht bei unterdrücktem Wetter.'},
  CHLOROPHYLL={'Doubles Speed in harsh sunlight. Weather suppression disables the boost.',
    'Verdoppelt die Initiative bei Sonne. Nicht bei unterdrücktem Wetter.'},
  SAND_RUSH={'Doubles Speed in sandstorms and prevents sandstorm damage.',
    'Verdoppelt die Initiative im Sandsturm und schützt vor dessen Schaden.'},
  SLUSH_RUSH={'Doubles Speed in hail. This ability itself does not prevent hail damage.',
    'Verdoppelt die Initiative im Hagel. Die Fähigkeit selbst schützt nicht vor Hagelschaden.'},
  AIR_LOCK={'Suppresses weather effects while active. The weather timer still runs.',
    'Unterdrückt Wetterwirkungen im Kampf. Die Wetterdauer läuft weiter.'},
  CLOUD_NINE={'Suppresses weather effects while active. The weather timer still runs.',
    'Unterdrückt Wetterwirkungen im Kampf. Die Wetterdauer läuft weiter.'},
  WONDER_GUARD={'Only super-effective attacks hit. Status and indirect damage still work.',
    'Nur sehr effektive Angriffe treffen. Status und indirekter Schaden wirken weiterhin.'},
  STAMINA={'Each damaging hit raises Defense by 1 stage. Substitute hits do not count.',
    'Jeder Schadenstreffer erhöht die Abwehr um 1 Stufe. Delegator-Treffer zählen nicht.'},
  OVERGROW={'At 1/3 HP or less, boosts Grass attacks by 50%.','Bei höchstens 1/3 KP: Pflanzen-Angriffe 50% stärker.'},
  BLAZE={'At 1/3 HP or less, boosts Fire attacks by 50%.','Bei höchstens 1/3 KP: Feuer-Angriffe 50% stärker.'},
  TORRENT={'At 1/3 HP or less, boosts Water attacks by 50%.','Bei höchstens 1/3 KP: Wasser-Angriffe 50% stärker.'},
  SWARM={'At 1/3 HP or less, boosts Bug attacks by 50%.','Bei höchstens 1/3 KP: Käfer-Angriffe 50% stärker.'},
  IMMUNITY={'Prevents poisoning.','Verhindert Vergiftung.'},
  LIMBER={'Prevents paralysis.','Verhindert Paralyse.'},
  INSOMNIA={'Prevents sleep, including Rest.','Verhindert Schlaf, auch durch Erholung.'},
  VITAL_SPIRIT={'Prevents sleep, including Rest.','Verhindert Schlaf, auch durch Erholung.'},
  WATER_VEIL={'Prevents burns.','Verhindert Verbrennungen.'},
  MAGMA_ARMOR={'Prevents freezing.','Verhindert Einfrieren.'},
  NATURAL_CURE={'Cures status when leaving battle.','Heilt Statusprobleme beim Verlassen des Kampfes.'},
  REGENERATOR={'On switching out: heals 1/3 max HP. Cannot revive a fainted Pokemon.',
    'Beim Auswechseln: heilt 1/3 max. KP. Belebung besiegter Pokémon ausgeschlossen.'},
  WATER_ABSORB={'Water attacks heal 1/4 max HP instead of damage. Immune even at full HP.',
    'Wasser-Attacken heilen 1/4 max. KP statt Schaden. Auch bei vollen KP immun.'},
  VOLT_ABSORB={'Electric attacks heal 1/4 max HP instead of damage. Immune even at full HP.',
    'Elektro-Attacken heilen 1/4 max. KP statt Schaden. Auch bei vollen KP immun.'},
  SPEED_BOOST={'Raises Speed each turn after the entry turn.','Erhöht jede Runde die Initiative, außer beim Einwechseln.'},
  QUICK_FEET={'In battle, status boosts Speed by 50%. Ignores paralysis slowing, not its chance of being unable to move.',
    'Im Kampf: Bei Statusproblemen Initiative +50%. Kein Tempoverlust durch Paralyse; Aussetzen bleibt möglich.'},
  SHED_SKIN={'Each turn: 33% chance to cure a status problem.','Jede Runde: 33% Chance, ein Statusproblem zu heilen.'},
  POISON_HEAL={'Poison restores 1/8 max HP each turn instead of damage. Poison remains.',
    'Gift heilt jede Runde 1/8 der maximalen KP statt Schaden. Vergiftung bleibt.'},
  INNER_FOCUS={'Prevents flinching.','Verhindert Zurückschrecken.'},
  STEADFAST={'Raises Speed one stage when actually flinching.','Erhöht beim Zurückschrecken die Initiative um eine Stufe.'},
  SERENE_GRACE={'Doubles extra move effect chances (max. 100%).','Verdoppelt Zusatzchancen von Attacken (max. 100%).'},
  SHIELD_DUST={'Blocks extra effects of incoming attacks, not their damage.','Blockt Zusatzeffekte gegnerischer Angriffe, nicht den Schaden.'},
  SUPER_LUCK={'Raises critical-hit chance by one stage.','Volltreffer: Chance steigt um 1 Stufe.'},
  TINTED_LENS={'Doubles resisted attack damage. Does not bypass immunity.','Resistierte Treffer: doppelter Schaden. Keine Wirkung bei Immunität.'},
  TOXIC_BOOST={'When poisoned: physical move power +50%.','Bei Vergiftung: physische Attacken 50% stärker.'},
  FLARE_BOOST={'When burned: special move power +50%.','Bei Brand: spezielle Attacken 50% stärker.'},
  OWN_TEMPO={'Prevents confusion.','Verhindert Verwirrung.'},
  BATTLE_ARMOR={'Prevents critical hits against the holder.','Verhindert gegnerische Volltreffer.'},
  SHELL_ARMOR={'Prevents critical hits against the holder.','Verhindert gegnerische Volltreffer.'},
  RUN_AWAY={'Guarantees escape from wild battles.','Garantiert die Flucht aus wilden Kämpfen.'},
  HUGE_POWER={'Doubles Attack.','Verdoppelt den Angriff.'},
  PURE_POWER={'Doubles Attack.','Verdoppelt den Angriff.'},
  GUTS={'With a status problem: Attack +50%; ignores burn penalty.','Bei Statusproblemen: Angriff +50%; kein Angriffsmalus durch Brand.'},
  THICK_FAT={'Halves the attacking stat of Fire and Ice attacks.','Halbiert den Angriffswert bei Feuer- und Eis-Angriffen.'},
  MARVEL_SCALE={'With a status problem: Defense +50%.','Bei Statusproblemen: Verteidigung +50%.'},
  HUSTLE={'Attack +50%; physical accuracy reduced by 20%.','Angriff +50%; physische Genauigkeit um 20% gesenkt.'},
  COMPOUND_EYES={'Raises move accuracy by 30%.','Erhöht die Attackengenauigkeit um 30%.'},
  TECHNICIAN={'Boosts attacks of power 60 or less by 50%.','Verstärkt Attacken bis Stärke 60 um 50%.'},
  INTIMIDATE={'On entry: lowers the foe\'s Attack by 1 stage.','Beim Einwechseln: Angriff des Gegners sinkt um 1 Stufe.'},
  CLEAR_BODY={'Blocks stat drops caused by foes, not your own moves.','Gegner können Werte nicht senken. Eigene Attacken schon.'},
  WHITE_SMOKE={'Blocks stat drops caused by foes, not your own moves.','Gegner können Werte nicht senken. Eigene Attacken schon.'},
  HYPER_CUTTER={'Foes cannot lower your Attack. Own moves still can.','Gegner können den Angriff nicht senken. Eigene Attacken schon.'},
  BIG_PECKS={'Foes cannot lower your Defense. Own moves still can.','Gegner können die Abwehr nicht senken. Eigene Attacken schon.'},
  TANGLED_FEET={'While confused: halves the accuracy of incoming moves.','Bei Verwirrung: Gegner treffen mit halber Genauigkeit.'},
  FILTER={'Super-effective attacks deal 25% less damage.','Sehr effektive Angriffe: 25% weniger Schaden.'},
  SOLID_ROCK={'Super-effective attacks deal 25% less damage.','Sehr effektive Angriffe: 25% weniger Schaden.'},
  MULTISCALE={'At full HP: attack damage is halved. Checked for each hit.','Bei vollen KP: halber Schaden. Gilt pro Treffer.'},
  ADAPTABILITY={'Same-type attack bonus is 2x instead of 1.5x.','Eigener Angriffstyp: Bonus 2-fach statt 1.5-fach.'},
  PRANKSTER={'Status moves gain 1 priority level. Speed still breaks ties.','Statusattacken: 1 Prioritätsstufe mehr. Bei Gleichstand zählt Initiative.'},
  STALL={'Moves last within the same priority level.','Handelt zuletzt innerhalb derselben Prioritätsstufe.'},
}
local items={
  BLUE_ORB={'In Gen VI/VII, Kyogre automatically undergoes Primal Reversion on battle entry while holding this orb. Remains held; has no effect on other species.',
    'Kyogre vollzieht in Gen VI/VII mit diesem Edelstein beim Einwechseln automatisch die Protomorphose. Bleibt getragen; keine Wirkung bei anderen Arten.'},
  RED_ORB={'In Gen VI/VII, Groudon automatically undergoes Primal Reversion on battle entry while holding this orb. Remains held; has no effect on other species.',
    'Groudon vollzieht in Gen VI/VII mit diesem Edelstein beim Einwechseln automatisch die Protomorphose. Bleibt getragen; keine Wirkung bei anderen Arten.'},
  ULTRANECROZIUM_Z={'In Gen VII, Dusk-Mane or Dawn-Wings Necrozma can use the Ultra Burst command once per team. Remains held. This transformation does not grant a complete Z-Move system.',
    'Ab Gen VII kann Abendmähne- oder Morgenschwingen-Necrozma einmal pro Team die Ultra-Explosion wählen. Bleibt getragen. Diese Verwandlung schaltet kein vollständiges Z-Attackensystem frei.'},
  EVIOLITE={'From Gen V, Defense and Sp. Def increase by 50% if the holder\'s own species/form can evolve in its rule era. Transform keeps original eligibility. No bonus for fully evolved Pokemon or Mega forms; not consumed.',
    'Ab Gen V steigen Verteidigung und Spezial-Verteidigung um 50%, wenn die eigene Art/Form im Regelprofil eine Entwicklung hat. Wandler behält die ursprüngliche Eignung. Kein Bonus für vollständig entwickelte Pokémon oder Mega-Formen; kein Verbrauch.'},
  BIG_ROOT={'From Gen IV, boosts HP gained from draining moves, Leech Seed and Strength Sap by 30%. Also boosts Liquid Ooze damage; does not boost ordinary recovery moves.',
    'Verstärkt ab Gen IV die KP aus Saugattacken, Egelsamen und Kraftabsorber um 30%. Verstärkt auch Kloakensoße-Schaden, nicht normale Heilattacken.'},
  LIGHT_CLAY={'Extends Reflect, Light Screen and Aurora Veil from 5 to 8 turns when the holder sets them. The duration remains after switching. Active from Gen IV.',
    'Verlängert Reflektor, Lichtschild und Auroraschleier beim Aufstellen von 5 auf 8 Runden. Die Dauer bleibt nach dem Wechsel erhalten. Aktiv ab Gen IV.'},
  SHED_SHELL={'From Gen IV, allows switching despite trapping. Does not guarantee fleeing and does not stop binding damage.',
    'Erlaubt ab Gen IV den Wechsel trotz Festhalten. Garantiert keine Flucht und verhindert keinen Fesselschaden.'},
  IRON_BALL={'Halves Speed and grounds the holder. Flying holders take neutral Ground damage from Gen V unless already grounded by another effect.',
    'Halbiert die Initiative und erdet den Träger. Flug-Träger nehmen ab Gen V neutralen Bodenschaden, sofern kein anderer Effekt sie bereits erdet.'},
  AIR_BALLOON={'Avoids Ground moves while airborne. Pops after a damaging move hit, even against Substitute. Gravity and grounding moves can overcome it.',
    'Vermeidet Boden-Attacken im Schwebezustand. Platzt nach einem schädigenden Attackentreffer, auch gegen Delegator. Erdanziehung und herunterholende Attacken umgehen den Schutz.'},
  LIECHI_BERRY={'At 1/4 HP or less: Attack +1 stage; consumed. Gluttony raises the trigger to 1/2 HP.',
    'Bei höchstens 1/4 KP: Angriff +1 Stufe; wird verbraucht. Völlerei erhöht die Grenze auf 1/2 KP.'},
  GANLON_BERRY={'At 1/4 HP or less: Defense +1 stage; consumed. Gluttony raises the trigger to 1/2 HP.',
    'Bei höchstens 1/4 KP: Verteidigung +1 Stufe; wird verbraucht. Völlerei erhöht die Grenze auf 1/2 KP.'},
  SALAC_BERRY={'At 1/4 HP or less: Speed +1 stage; consumed. Gluttony raises the trigger to 1/2 HP.',
    'Bei höchstens 1/4 KP: Initiative +1 Stufe; wird verbraucht. Völlerei erhöht die Grenze auf 1/2 KP.'},
  PETAYA_BERRY={'At 1/4 HP or less: Sp. Atk +1 stage; consumed. Gluttony raises the trigger to 1/2 HP.',
    'Bei höchstens 1/4 KP: Spezial-Angriff +1 Stufe; wird verbraucht. Völlerei erhöht die Grenze auf 1/2 KP.'},
  APICOT_BERRY={'At 1/4 HP or less: Sp. Def +1 stage; consumed. Gluttony raises the trigger to 1/2 HP.',
    'Bei höchstens 1/4 KP: Spezial-Verteidigung +1 Stufe; wird verbraucht. Völlerei erhöht die Grenze auf 1/2 KP.'},
  QUICK_POWDER={'Only untransformed Ditto: doubles Speed. Stops working after Transform. Not consumed.',
    'Nur unverwandeltes Ditto: doppelte Initiative. Nach Wandler ohne Wirkung. Bleibt erhalten.'},
  CHOICE_BAND={'Attack +50%. Locks the first move used until switching or losing the item. Not consumed.',
    'Angriff +50%. Bindet an die erste eingesetzte Attacke bis zum Wechsel oder Itemverlust. Bleibt erhalten.'},
  ROCKY_HELMET={'Each damaging contact hit costs the attacker 1/6 of its max HP, even if the holder faints. Substitute, Long Reach and Magic Guard protect the attacker. Not consumed.',
    'Jeder schädigende Kontakttreffer kostet den Angreifer 1/6 seiner maximalen KP, auch beim K.O. des Trägers. Delegator, Langstrecke und Magieschild schützen. Bleibt erhalten.'},
  CHOICE_SPECS={'Sp. Atk +50%. Locks the first move used until switching or losing the item. Not consumed.',
    'Spezial-Angriff +50%. Bindet an die erste eingesetzte Attacke bis zum Wechsel oder Itemverlust. Bleibt erhalten.'},
  CHOICE_SCARF={'Speed +50%. Locks the first move used until switching or losing the item. Not consumed.',
    'Initiative +50%. Bindet an die erste eingesetzte Attacke bis zum Wechsel oder Itemverlust. Bleibt erhalten.'},
  LIFE_ORB={'Boosts ordinary attack damage by about 30%; a successful damaging move costs 1/10 max HP once. Magic Guard and applicable Sheer Force prevent the cost. Not consumed.',
    'Verstärkt normalen Attackenschaden um etwa 30%; ein erfolgreicher Angriff kostet einmal 1/10 der maximalen KP. Magieschild und wirksame Rohe Gewalt verhindern die Kosten. Bleibt erhalten.'},
  METAL_POWDER={'Only untransformed Ditto: doubles Defense; no Sp. Def bonus. Not consumed.',
    'Nur unverwandeltes Ditto: verdoppelt Verteidigung; kein Spezial-Verteidigungsbonus. Bleibt erhalten.'},
  LIGHT_BALL={'Only Pikachu: doubles Attack and Sp. Atk; not consumed.',
    'Nur Pikachu: verdoppelt Angriff und Spezial-Angriff; bleibt erhalten.'},
  THICK_CLUB={'Only Cubone/Marowak: doubles Attack; not consumed.',
    'Nur Tragosso/Knogga: verdoppelt Angriff; bleibt erhalten.'},
  DEEP_SEA_TOOTH={'Only Clamperl: doubles Sp. Atk. Also used for evolution; no consumption in battle.',
    'Nur Perlu: verdoppelt Spezial-Angriff. Auch Entwicklungsitem; kein Verbrauch im Kampf.'},
  DEEP_SEA_SCALE={'Only Clamperl: doubles Sp. Def. Also used for evolution; no consumption in battle.',
    'Nur Perlu: verdoppelt Spezial-Verteidigung. Auch Entwicklungsitem; kein Verbrauch im Kampf.'},
  SOUL_DEW={'Only Latias/Latios: Sp. Atk and Sp. Def +50%; not consumed.',
    'Nur Latias/Latios: Spezial-Angriff und Spezial-Verteidigung +50%; bleibt erhalten.'},
  DAMP_ROCK={'Extends rain you cause from 5 to 8 turns; not consumed.',
    'Verlängert selbst ausgelösten Regen von 5 auf 8 Runden; bleibt erhalten.'},
  HEAT_ROCK={'Extends sunlight you cause from 5 to 8 turns; not consumed.',
    'Verlängert selbst ausgelöste Sonne von 5 auf 8 Runden; bleibt erhalten.'},
  SMOOTH_ROCK={'Extends sandstorms you cause from 5 to 8 turns; not consumed.',
    'Verlängert eigene Sandstürme von 5 auf 8 Runden; bleibt erhalten.'},
  ICY_ROCK={'Extends hail you cause from 5 to 8 turns; not consumed.',
    'Verlängert selbst ausgelösten Hagel von 5 auf 8 Runden; bleibt erhalten.'},
  SACHET={'Spritzee: hold it, then use a Linking Cord. Both consumed on evolution. No battle bonus.',
    'Parfi: tragen lassen, dann Verbindungsschnur anwenden. Beides wird bei der Entwicklung verbraucht. Kein Kampfbonus.'},
  WHIPPED_DREAM={'Swirlix: hold it, then use a Linking Cord. Both consumed on evolution. No battle bonus.',
    'Flauschling: tragen lassen, dann Verbindungsschnur anwenden. Beides wird bei der Entwicklung verbraucht. Kein Kampfbonus.'},
  SCOPE_LENS={'Raises critical-hit chance by 1 stage; not consumed.',
    'Erhöht die Volltrefferchance um 1 Stufe; bleibt erhalten.'},
  RAZOR_CLAW={'Critical-hit chance +1 stage. Also evolves Hisuian Sneasel on a daytime level-up; consumed only on evolution.',
    'Volltrefferchance +1 Stufe. Entwickelt auch Hisui-Sniebel beim Levelaufstieg am Tag; Verbrauch nur bei Entwicklung.'},
  LUCKY_PUNCH={'Only Chansey: critical-hit chance +2 stages; not consumed.',
    'Nur Chaneira: Volltrefferchance +2 Stufen; bleibt erhalten.'},
  STICK={'Only Farfetch\'d: critical-hit chance +2 stages; not consumed.',
    'Nur Porenta: Volltrefferchance +2 Stufen; bleibt erhalten.'},
  BERRY={'At half HP or less: heals 10 HP, then consumed.','Bei höchstens halben KP: heilt 10 KP; wird verbraucht.'},
  GOLD_BERRY={'At half HP or less: heals 30 HP, then consumed.','Bei höchstens halben KP: heilt 30 KP; wird verbraucht.'},
  LEFTOVERS={'Each turn restores 1/16 max HP; not consumed.','Heilt jede Runde 1/16 der maximalen KP; bleibt erhalten.'},
  MYSTERYBERRY={'At 0 PP restores 5 PP to one move, then consumed.','Bei 0 AP: füllt eine Attacke um 5 AP auf; wird verbraucht.'},
  OVAL_STONE={'Happiny: held, day level-up. Consumed on accepted evolution.','Wonneira: tragen, tagsüber aufleveln. Verbrauch bei angenommener Entwicklung.'},
}
for id,row in pairs({PSNCUREBERRY={'poison','Vergiftung'},PRZCUREBERRY={'paralysis','Paralyse'},
  BURNT_BERRY={'freezing','Einfrieren'},ICE_BERRY={'burn','Verbrennung'},
  MINT_BERRY={'sleep','Schlaf'},BITTER_BERRY={'confusion','Verwirrung'},
  MIRACLEBERRY={'a status problem or confusion','ein Statusproblem oder Verwirrung'}})do
  items[id]={'Cures '..row[1]..', then consumed.','Heilt '..row[2]..'; wird verbraucht.'}
end
local H={schema='kasc.equipment-help/v1',CARD_ID='KASC-WAVE-W-EQUIPMENT-HELP'}
for modern,legacy in pairs({ORAN_BERRY='BERRY',CHERI_BERRY='PRZCUREBERRY',
  CHESTO_BERRY='MINT_BERRY',PECHA_BERRY='PSNCUREBERRY',RAWST_BERRY='ICE_BERRY',
  ASPEAR_BERRY='BURNT_BERRY',PERSIM_BERRY='BITTER_BERRY',LUM_BERRY='MIRACLEBERRY'})do
  items[modern]=items[legacy]
end
items.LEPPA_BERRY={'At 0 PP restores 10 PP to one move, then consumed.',
  'Bei 0 AP: füllt eine Attacke um 10 AP auf; wird verbraucht.'}
local boosts={CHARCOAL={'Fire','Feuer'},MYSTIC_WATER={'Water','Wasser'},
  MIRACLE_SEED={'Grass','Pflanzen'},MAGNET={'Electric','Elektro'},
  NEVERMELTICE={'Ice','Eis'},NEVER_MELT_ICE={'Ice','Eis'},
  BLACKBELT={'Fighting','Kampf'},BLACKBELT_I={'Fighting','Kampf'},BLACK_BELT={'Fighting','Kampf'},
  POISON_BARB={'Poison','Gift'},SOFT_SAND={'Ground','Boden'},
  SHARP_BEAK={'Flying','Flug'},TWISTEDSPOON={'Psychic','Psycho'},TWISTED_SPOON={'Psychic','Psycho'},
  SILVERPOWDER={'Bug','Käfer'},SILVER_POWDER={'Bug','Käfer'},HARD_STONE={'Rock','Gestein'},
  SPELL_TAG={'Ghost','Geist'},DRAGON_FANG={'Dragon','Drachen'},
  BLACKGLASSES={'Dark','Unlicht'},BLACK_GLASSES={'Dark','Unlicht'},METAL_COAT={'Steel','Stahl'},
  PINK_BOW={'Normal','Normal'},POLKADOT_BOW={'Normal','Normal'},SILK_SCARF={'Normal','Normal'}}
function H.describe(kind,id,gen,metadata)
  gen=math.max(1,math.floor(tonumber(gen) or 1))
  local row=kind=='ability' and abilities[id] or kind=='item' and items[id]
  if kind=='ability'and id=='MULTITYPE'then
    row={'Arceus takes its held Plate\'s type; without a suitable Plate it is Normal. Its ability cannot be suppressed or replaced. Plates also set Judgment\'s type and boost matching attacks by 20%.',
      'Arceus nimmt den Typ seiner getragenen Tafel an; ohne passende Tafel ist es Normal. Die Fähigkeit kann nicht unterdrückt oder ersetzt werden. Tafeln bestimmen auch Urteilskrafts Typ und stärken passende Angriffe um 20%.'}
  elseif kind=='ability'and id=='RKS_SYSTEM'then
    row={'Silvally takes its held Memory\'s type; without one it is Normal. The ability cannot be suppressed or replaced. A Memory also sets Multi-Attack\'s type; in Gen VII its base power is 90.',
      'Amigento nimmt den Typ seiner getragenen Disc an; ohne Disc ist es Normal. Die Fähigkeit kann nicht unterdrückt oder ersetzt werden. Die Disc bestimmt auch Multi-Angriffs Typ; seine Basisstärke beträgt in Gen VII 90.'}
  elseif kind=='item'and metadata and metadata.kascTypeItemKind then
    row=metadata.kascTypeItemKind=='plate'and{
      'Held Plate: matching attacks gain 20% power. Sets Judgment\'s type and, with Multitype, Arceus\' form/type. Not consumed.',
      'Getragene Tafel: passende Angriffe erhalten 20% mehr Stärke. Bestimmt Urteilskrafts Typ und mit Variabilität Arceus\' Form/Typ. Kein Verbrauch.'}or{
      'Held Memory: sets Multi-Attack\'s type and, with RKS System, Silvally\'s form/type. No 20% damage bonus; not consumed.',
      'Getragene Disc: bestimmt Multi-Angriffs Typ und mit Alpha-System Amigentos Form/Typ. Kein 20%-Schadensbonus; kein Verbrauch.'}
  end
  if kind=='item'and id=='DESTINY_KNOT'then
    row=gen>=6 and{
      'Reflects infatuation unless immune. In new Day-Care eggs from Gen VI, either parent holding it inherits five different IVs. Two Knots still give five. Not consumed; no item inheritance.',
      'Gibt Verliebtheit zurück, sofern nicht immun. Bei neuen Zuchteiern ab Gen VI vererbt ein Träger fünf verschiedene IVs. Zwei Knoten bleiben fünf. Kein Verbrauch; keine Itemvererbung.'}or{
      'Reflects infatuation unless immune. Not consumed. No five-IV breeding bonus before Gen VI; the Crystal DV model remains under Gen I/II.',
      'Gibt Verliebtheit zurück, sofern nicht immun. Kein Verbrauch. Vor Gen VI kein Fünf-IV-Zuchtbonus; Gen I/II behalten das Crystal-DV-Modell.'}
  elseif kind=='item'and (id=='BALM_MUSHROOM'or id=='BIG_NUGGET'or id=='PEARL_STRING')then
    row={'A valuable treasure to sell. No effect while held.',
      'Ein wertvoller Schatz zum Verkaufen. Kein Effekt beim Tragen.'}
  elseif kind=='item'and id=='HEART_SCALE'then
    row={'A collectible scale. No held effect. KASC\'s existing Move Reminder does not require one.',
      'Eine Schuppe zum Sammeln. Kein Trageeffekt. KASCs bisheriger Attacken-Erinnerer benötigt sie nicht.'}
  end
  if kind=='ability'and id=='ILLUMINATE'then
    row={'In the first party slot, doubles random walking/surfing encounters, even when fainted. Eggs do not count. No battle effect in Gen III–VII; visible-spawn density is unchanged.',
      'An erster Teamstelle doppelt so viele Zufallsbegegnungen beim Laufen/Surfen, auch bei K.O. Eier zählen nicht. Kein Kampfeffekt in Gen III–VII; die Dichte sichtbarer Pokémon bleibt gleich.'}
  end
  if kind=='ability'and id=='ILLUSION'then
    row={'On entry, disguises as the last conscious non-Egg teammate in battle order. Copies appearance and name, not level, types or stats. A direct hit or ability loss ends it; residual damage and Substitute hits do not.',
      'Beim Einwechseln erscheint es als letztes kampffähiges Nicht-Ei im Kampfteam. Kopiert Aussehen und Namen, nicht Level, Typen oder Werte. Direkte Treffer oder Fähigkeitsverlust lösen es auf; Restschaden und Delegator-Treffer nicht.'}
  end
  if kind=='ability'and id=='PICKUP'then
    row={'After victories: an empty-handed party member has a 10% chance to find an item. Finds depend on level and rule era; fainted members count.',
      'Nach Siegen: Teammitglieder ohne Item finden mit 10% Chance ein Item. Funde hängen von Level und Regelprofil ab; K.O. zählt mit.'}
    if gen>=5 then
      row[1]=row[1]..' In battle: collects an item another active Pokémon consumed this turn, once per turn. Trainer-battle items are temporary.'
      row[2]=row[2]..' Im Kampf: hebt einmal pro Runde ein Item auf, das ein anderes aktives Pokémon gerade verbraucht hat. Trainerkampf-Items sind vorübergehend.'
    end
  end
  if kind=='ability'and id=='HONEY_GATHER'then
    row={'After a victory, an empty-handed party member may hold Honey: 5% at Lv.1-10, +5% per 10 levels, up to 50%. Also works when fainted.',
      'Nach einem Sieg kann ein Teammitglied ohne Item Honig tragen: 5% auf Lv.1-10, +5% je 10 Level, bis 50%. Wirkt auch bei K.O.'}
  elseif kind=='item'and id=='HONEY'then
    row={'Ordinary Honey. No effect while held. Not the special Hoenn Honey; it does not unlock habitats.',
      'Gewöhnlicher Honig. Kein Effekt beim Tragen. Nicht der besondere Hoenn-Honig; schaltet keine Habitate frei.'}
  end
  if kind=='ability' and id=='FLOWER_GIFT'then
    row={'Sunlight: Attack and Sp. Defense +50%. No bonus when weather or the ability is suppressed.',
      'Sonne: Angriff und Spezial-Verteidigung +50 %. Kein Bonus bei unterdrücktem Wetter oder unterdrückter Fähigkeit.'}
    row[1]=row[1]..(gen==4 and ' Gen4: copied ability works too; Cherrim opens independently.' or ' Only Cherrim benefits and opens with this ability.')
    row[2]=row[2]..(gen==4 and ' Gen4: wirkt auch kopiert; Kinoso öffnet sich unabhängig davon.' or ' Nur Kinoso erhält den Bonus und öffnet sich mit dieser Fähigkeit.')
  end
  if kind=='ability' and id=='WEAK_ARMOR'then
    local stages=gen>=7 and '2' or '1'
    row={'Each physical hit: Defense -1 stage, Speed +'..stages..' stages. Not triggered by Substitute hits or after fainting.',
      'Jeder physische Treffer: Verteidigung -1 Stufe, Initiative +'..stages..' Stufen. Nicht bei Delegator-Treffern oder nach K.O.'}
  end
  if kind=='ability' and id=='SYNCHRONIZE' then
    row=gen<=4 and {
      'In battle, reflects poison, burn or paralysis to its source. Bad poison is reflected as normal poison. Immunities still apply.',
      'Im Kampf: Gibt Gift, Brand oder Paralyse an den Verursacher zurück. Schweres Gift wird normales Gift. Immunitäten gelten.'}
      or {'In battle, reflects poison, bad poison, burn or paralysis to its source. Immunities still apply.',
      'Im Kampf: Gibt Gift, schweres Gift, Brand oder Paralyse an den Verursacher zurück. Immunitäten gelten.'}
  end
  local weatherNames={DROUGHT={'sunlight','Sonne'},DRIZZLE={'rain','Regen'},
    SAND_STREAM={'a sandstorm','Sandsturm'},SNOW_WARNING={'hail','Hagel'}}
  if kind=='ability' and weatherNames[id] then
    local names=weatherNames[id]
    row=gen<=5 and {'On entry: starts '..names[1]..' until replaced or battle ends.',
      'Beim Einwechseln: '..names[2]..' bis zum Wetterwechsel oder Kampfende.'}
      or {'On entry: starts '..names[1]..' for 5 turns, or 8 with its weather rock.',
      'Beim Einwechseln: '..names[2]..' für 5 Runden, mit passendem Brocken 8.'}
  end
  local contactStatus={STATIC={'paralysis','Paralyse'},FLAME_BODY={'burn','Brand'},
    POISON_POINT={'poison','Gift'}}
  if kind=='ability' and id=='LEAF_GUARD' then
    row={'Sun: prevents new status problems and Yawn; does not cure existing status.',
      'Sonne: schützt vor neuen Statusproblemen und Gähner; heilt keinen alten Status.'}
    row[1]=row[1]..(gen==4 and ' Rest still works in Gen4.' or ' Rest fails in sun.')
    row[2]=row[2]..(gen==4 and ' Erholung wirkt in Gen4 weiterhin.' or ' Erholung scheitert in Sonne.')
  end
  if kind=='ability' and contactStatus[id] then
    local chance=gen<=3 and '1/3' or '30%'
    row={'When hit by contact: '..chance..' chance to inflict '..contactStatus[id][1]..'.',
      'Bei Kontakt: '..chance..' Chance auf '..contactStatus[id][2]..' beim Gegner.'}
  end
  if kind=='ability' and id=='CUTE_CHARM' then
    local chance=gen<=3 and '1/3' or '30%'
    row={'Contact: '..chance..' infatuation with opposite gender; 50% action failure.',
      'Kontakt: '..chance..' Anziehung bei anderem Geschlecht; 50% Zugausfall.'}
  end
  if kind=='ability' and id=='EFFECT_SPORE' then
    local chance=gen<=3 and '10%' or '30%'
    row={'Contact: '..chance..' status chance; sleep, paralysis or poison equally likely.',
      'Kontakt: '..chance..' Statuschance; Schlaf, Paralyse oder Gift gleich häufig.'}
    if gen>=5 then
      row={'Contact: 11% sleep, 10% paralysis, 9% poison.',
        'Kontakt: 11% Schlaf, 10% Paralyse, 9% Gift.'}
    end
    if gen>=6 then
      row[1]=row[1]..' Grass types immune.'
      row[2]=row[2]..' Pflanzen immun.'
    end
  end
  if kind=='ability' and (id=='ROUGH_SKIN' or id=='IRON_BARBS') then
    local fraction=id=='ROUGH_SKIN' and gen<=3 and '1/16' or '1/8'
    row={'Each contact hit hurts the attacker for '..fraction..' of its max HP.',
      fraction..' max. KP Schaden beim Angreifer je Kontakt.'}
  end
  if kind=='ability' and (id=='FLAME_BODY' or id=='MAGMA_ARMOR') then
    if id=='FLAME_BODY' then
      local chance=gen<=3 and '1/3' or '30%'
      row={'Contact hits: '..chance..' chance to burn the attacker.',
        'Kontakt: '..chance..' Brand beim Angreifer.'}
    end
    row={row[1]..' Party eggs hatch twice as fast; no stacking.',
      row[2]..' Team-Eier: halbe Laufzeit; nicht stapelbar.'}
  end
  if kind=='ability' and id=='SNIPER' then
    local factor=gen>=6 and '2.25' or '3'
    row={'Critical hits: '..factor..'x damage. No higher critical chance.',
      'Volltreffer: '..factor..'-facher Schaden. Keine höhere Chance.'}
  end
  if kind=='ability' and id=='VOLT_ABSORB' and gen<=3 then
    row={row[1]..' Does not block Thunder Wave in Gen3.',
      row[2]..' Blockt in Gen3 keine Donnerwelle.'}
  end
  if kind=='ability' and id=='GALE_WINGS' then
    row=gen<=6 and {'Flying moves gain 1 priority level, even below full HP.',
      'Flugattacken: 1 Prioritätsstufe mehr, auch ohne volle KP.'}
      or {'At full HP: Flying moves gain 1 priority level.',
        'Bei vollen KP: Flugattacken erhalten 1 Prioritätsstufe mehr.'}
  end
  if kind=='ability' and id=='PRANKSTER' and gen>=7 then
    row={'Status moves gain 1 priority level. Opposing Dark types block targeted status moves.',
      'Statusattacken erhalten 1 Prioritätsstufe mehr. Gegnerische Unlicht-Pokémon blocken gezielte Statusattacken.'}
  end
  if kind=='ability' and id=='KEEN_EYE' then
    row=gen>=6 and {'Blocks foes lowering accuracy; ignores their evasion stages.',
      'Schützt Genauigkeit. Ignoriert gegnerische Fluchtwert-Stufen.'}
      or {'Foes cannot lower accuracy. Does not ignore evasion yet.',
      'Schützt Genauigkeit. Fluchtwert wird noch berücksichtigt.'}
  end
  if kind=='ability' and id=='STURDY' then
    row=gen>=5 and {'Blocks one-hit KO moves; at full HP survives a lethal hit with 1 HP.',
      'Blockt K.O.-Attacken; bei vollen KP übersteht es einen tödlichen Treffer mit 1 KP.'}
      or {'Blocks one-hit KO moves.','Blockiert K.O.-Attacken.'}
  end
  if kind=='ability' and id=='STENCH' and gen<5 then
    row={'No battle flinch effect before Gen V. Its wild-encounter field effect is not implemented yet.',
      'Vor Gen V kein Zurückschrecken im Kampf. Der Feldeffekt auf wilde Begegnungen ist noch nicht eingebaut.'}
  elseif kind=='ability' and id=='TRACE'and gen<=3 then
    row={'Copies the opposing ability once on entry until switching out. Gen III does not retry later; the saved ability slot stays unchanged.',
      'Kopiert beim Einwechseln einmal die gegnerische Fähigkeit bis zum Wechsel. In Gen III kein späterer Neuversuch; der gespeicherte Slot bleibt unverändert.'}
  elseif kind=='ability' and (id=='LIGHTNING_ROD' or id=='STORM_DRAIN') and gen<5 then
    row=id=='LIGHTNING_ROD' and {'Redirects Electric moves only in doubles. No effect in native singles; no immunity or Sp. Atk boost yet.',
      'Lenkt Elektro-Attacken nur im Doppelkampf um. Kein Effekt im nativen Einzelkampf; noch keine Immunität oder Spezial-Angriffs-Erhöhung.'}
      or {'Redirects Water moves only in doubles. No effect in native singles; no immunity or Sp. Atk boost yet.',
      'Lenkt Wasser-Attacken nur im Doppelkampf um. Kein Effekt im nativen Einzelkampf; noch keine Immunität oder Spezial-Angriffs-Erhöhung.'}
  elseif kind=='ability' and id=='OBLIVIOUS' and gen<6 then
    row={'Prevents infatuation and Captivate, but not Taunt yet.',
      'Verhindert Verliebtheit und Liebreiz, aber noch nicht Verhöhner.'}
  elseif kind=='ability' and id=='INFILTRATOR' and gen<6 then
    row={'Bypasses protective screens, but not Substitute yet.',
      'Umgeht Schutzschirme, aber noch nicht Delegator.'}
  elseif kind=='ability' and (id=='PLUS' or id=='MINUS') then
    local opposite=id=='PLUS'and'Minus'or'Plus'
    if gen==3 then
      row={'Sp. Atk +50% while another active Pokemon has '..opposite..', including an opponent. Party reserves do not count.',
        'SP.-ANG. +50% mit einem anderen aktiven Pokémon mit '..opposite..', auch auf der Gegenseite. Pokémon auf der Bank zählen nicht.'}
    elseif gen==4 then
      row={'Sp. Atk +50% with an active allied '..opposite..' user. No bonus in singles or from party reserves.',
        'SP.-ANG. +50% mit einem aktiven '..opposite..'-Partner. Kein Bonus im Einzelkampf oder durch Pokémon auf der Bank.'}
    else
      row={'Sp. Atk +50% with an active allied Plus or Minus user. Does not stack; no bonus in singles or from party reserves.',
        'SP.-ANG. +50% mit einem aktiven Plus- oder Minus-Partner. Nicht stapelbar; kein Bonus im Einzelkampf oder durch Pokémon auf der Bank.'}
    end
  end
  if kind=='item' and id=='SITRUS_BERRY' then
    row=gen>=4 and {'At half HP or less: heals 1/4 max HP, then consumed.',
      'Bei höchstens halben KP: heilt 1/4 der maximalen KP; wird verbraucht.'} or items.GOLD_BERRY
  end
  if kind=='item' and id=='LIFE_ORB'and gen==4 then
    row={'Ordinary attack damage +30%. A successful power-based hit costs 1/10 max HP once, except against Substitute. Fixed damage does not trigger this cost in Gen IV. Magic Guard protects; not consumed.',
      'Normaler Attackenschaden +30%. Ein erfolgreicher Treffer mit Basisstärke kostet einmal 1/10 der maximalen KP, außer gegen Delegator. Fester Schaden löst in Gen IV keine Kosten aus. Magieschild schützt; bleibt erhalten.'}
  end
  if kind=='item'and id:match('_GEM$')then
    row=gen==5 and {'One use: matching-type damaging move gains 50% base power, including all hits. Consumed on a successful hit; fixed damage stays fixed.',
      'Einmalig: passende Schadensattacke erhält 50% mehr Basisstärke, auch alle Mehrfachtreffer. Verbrauch bei Treffer; fester Schaden bleibt gleich.'}
      or {'One use: matching-type damaging move gains about 30% base power, including all hits. Consumed on a successful hit; fixed damage stays fixed.',
      'Einmalig: passende Schadensattacke erhält etwa 30% mehr Basisstärke, auch alle Mehrfachtreffer. Verbrauch bei Treffer; fester Schaden bleibt gleich.'}
  end
  if kind=='item' and gen==2 and (id=='LUCKY_PUNCH' or id=='STICK')then
    local en,de=id=='STICK' and "Farfetch'd" or 'Chansey',id=='STICK' and 'Porenta' or 'Chaneira'
    row={en..': critical-hit chance 1/4. Does not stack with Focus Energy or high-critical moves; not consumed.',
      de..': Volltrefferchance 1/4. Keine Kombination mit Energiefokus oder Volltrefferattacken; bleibt erhalten.'}
  end
  if kind=='item' and id=='METAL_POWDER' and gen==2 then
    row={'Only Ditto: Defense and Sp. Def +50%, including after Transform; not consumed.',
      'Nur Ditto: Verteidigung und Spezial-Verteidigung +50%, auch nach Wandler; bleibt erhalten.'}
  elseif kind=='item' and id=='LIGHT_BALL' then
    if gen<=3 then row={'Only Pikachu: doubles Sp. Atk; no physical bonus. Not consumed.',
      'Nur Pikachu: verdoppelt Spezial-Angriff; kein physischer Bonus. Bleibt erhalten.'}
    elseif gen==4 then row={'Only Pikachu: doubles attack base power; not consumed.',
      'Nur Pikachu: verdoppelt die Stärke seiner Attacken; bleibt erhalten.'}end
  elseif kind=='item' and id=='SOUL_DEW' and gen>=7 then
    row={'Only Latias/Latios: Dragon and Psychic attacks +20%; no defensive bonus. Not consumed.',
      'Nur Latias/Latios: Drachen- und Psychoattacken +20%; kein Verteidigungsbonus. Bleibt erhalten.'}
  end
  if kind=='item' and boosts[id] then
    local percent=gen>=4 and 20 or 10
    row={('Boosts %s attacks by %d%%; not consumed.'):format(boosts[id][1],percent),
      ('Verstärkt %s-Angriffe um %d%%; bleibt erhalten.'):format(boosts[id][2],percent)}
  end
  if not row then return nil end
  return {en=row[1]:gsub('%+','plus '),de=row[2]:gsub('%+','plus ')}
end
function H.withSource(source,resolve)
  assert(source.schema=='kasc.ability-help-source/v1','unexpected ability help source')
  return {schema=H.schema,CARD_ID=H.CARD_ID,sourceCommit=source.sourceCommit,
    describe=function(kind,id,gen,metadata)
      local current=resolve and resolve(kind,id,gen,metadata)
      if current then return current end
      local reviewed=H.describe(kind,id,gen,metadata)
      if reviewed then return reviewed end
      local eras=kind=='ability' and source.entries[id]
      local row=eras and eras[math.max(3,math.min(9,math.floor(tonumber(gen) or 3)))]
      if row then return {en=row.en,de=row.de} end
    end}
end
return H
