-- KASC-67-FAIRY-AFFECTION: the narrow Rocket-raid evolution card.
-- This card intentionally owns only Sylveon/Feelinara and its ribbon.

return {
  schema = "kanto-ascendant-fairy-affection/v1",
  order = { "SYLVEON" },
  species = {
    SYLVEON = {
      id="SYLVEON", dex=700, sourceDex=700, originGeneration=6,
      names={en="SYLVEON",de="FEELINARA"}, parent="EEVEE",
      evolutionItem="AFFECTION_RIBBON", types={"FAIRY"},
      baseStats={hp=95,attack=65,defense=65,speed=60,special=110},
      baseExp=184, heightM=1.0, weightKg=23.5,
      level1Moves={"TACKLE","SAND_ATTACK","QUICK_ATTACK","SWIFT"},
      assets={
        front="assets/fairy_affection_67/battle/normal/front/0700.png",
        frontShiny="assets/fairy_affection_67/battle/shiny/front/0700.png",
        back="assets/fairy_affection_67/battle/normal/back/0700.png",
        backShiny="assets/fairy_affection_67/battle/shiny/back/0700.png",
        icon="assets/fairy_affection_67/icons/normal/0700.png",
        iconShiny="assets/fairy_affection_67/icons/shiny/0700.png",
        follower="assets/fairy_affection_67/followers/normal/SYLVEON.png",
        followerShiny="assets/fairy_affection_67/followers/shiny/SYLVEON.png",
        cry="assets/fairy_affection_67/cries/700.ogg",
      },
    },
  },
}
