#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
MOD_ROOT="${SCRIPT_DIR:h}"
RECOMPILE_ROOT="${MOD_ROOT:h}"
ENGINE_ROOT="${RECOMPILE_ROOT}/gen1recomp"
LOVE_BIN="${LOVE_BIN:-${ENGINE_ROOT}/.bazinga/qa-launcher-app/gen1recomp-localized.app/Contents/MacOS/love}"
SHOT_DIR="${1:-${RECOMPILE_ROOT}/qa/mega-all-live}"
SHINY="${MEGA_QA_SHINY:-0}"
SIDE="${MEGA_QA_SIDE:-enemy}"
CRYSTAL="${MEGA_QA_CRYSTAL:-1}"
VERSION="${MEGA_QA_VERSION:-red}"

forms=(
  mega-aerodactyl
  mega-alakazam
  mega-ampharos
  mega-beedrill
  mega-blastoise
  mega-charizard-x
  mega-charizard-y
  mega-clefable
  mega-dragonite
  mega-feraligatr
  mega-gengar
  mega-gyarados
  mega-heracross
  mega-houndoom
  mega-kangaskhan
  mega-meganium
  mega-mewtwo-x
  mega-mewtwo-y
  mega-pidgeot
  mega-pinsir
  mega-raichu-x
  mega-raichu-y
  mega-scizor
  mega-skarmory
  mega-slowbro
  mega-starmie
  mega-steelix
  mega-tyranitar
  mega-venusaur
  mega-victreebel
  ascendant-typhlosion
)

mkdir -p "${SHOT_DIR}"
total=$(( ${#forms} * 2 ))
index=0

for layout in 2d voxel; do
  for form in "${forms[@]}"; do
    index=$(( index + 1 ))
    print -- "[${index}/${total}] ${form} ${layout}"
    (
      cd "${ENGINE_ROOT}"
      env \
        POKEPORT_IDENTITY=kanto-ascendant-mega-capture \
        POKEPORT_DRIVER="${MOD_ROOT}/tools/mega_crystal_qa_driver.lua" \
        POKEPORT_TOUCH=0 \
        POKEPORT_SPEED=16 \
        SHOT_DIR="${SHOT_DIR}" \
        MEGA_QA_FORM="${form}" \
        MEGA_QA_LAYOUT="${layout}" \
        MEGA_QA_SIDE="${SIDE}" \
        MEGA_QA_SHINY="${SHINY}" \
        MEGA_QA_CRYSTAL="${CRYSTAL}" \
        MEGA_QA_VERSION="${VERSION}" \
        "${LOVE_BIN}" .
    )
  done
done

print -- "Captured ${total} live Mega battle screenshots in ${SHOT_DIR}"
