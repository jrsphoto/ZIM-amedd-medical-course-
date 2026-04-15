#!/usr/bin/env bash
# =============================================================================
# install.sh
# Installer for the US Army Medical Course offline archive.
#
# This script will:
#   1. Check dependencies
#   2. Download all PDFs from archive.org individually
#   3. Extract PDFs into html/pdfs/
#   4. Build the ZIM file
#   5. Print deployment instructions
#
# Place this script in the "Medical Course" root folder alongside html/.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#
# To skip the download (if you already have the PDFs):
#   ./install.sh --skip-download
#
# To skip the ZIM build (just download the PDFs):
#   ./install.sh --skip-zim
#
# To automatically deploy to a local Kiwix container after building:
#   ./install.sh --deploy --zim-dest /path/to/kiwix/library --container nomad_kiwix_server
#
# All options can be combined:
#   ./install.sh --skip-download --deploy --zim-dest /opt/project-nomad/storage/zim --container nomad_kiwix_server
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HTML_DIR="${SCRIPT_DIR}/html"
PDF_DIR="${HTML_DIR}/pdfs"
ZIM_OUT="${SCRIPT_DIR}/army_medical_course.zim"

# Each entry is: "IA_IDENTIFIER|output_filename.pdf"
# The IA compress URL pattern is:
#   https://archive.org/compress/<IDENTIFIER>/formats=TEXT%20PDF,...
# We download the zip and extract the PDF from it, renaming to match
# what index.html expects (US_Army_Medical_Course_<Title>_<MDXXXX>.pdf).

declare -a COURSE_LIST=(
  "US_Army_Medical_Course_Basic_Human_Anatomy_MD0006|US_Army_Medical_Course_Basic_Human_Anatomy_MD0006.pdf"
  "US_Army_Medical_Course_Basic_Human_Physiology_MD0007|US_Army_Medical_Course_Basic_Human_Physiology_MD0007.pdf"
  "US_Army_Medical_Course_Basic_Medical_Terminology_MD0010|US_Army_Medical_Course_Basic_Medical_Terminology_MD0010.pdf"
  "US_Army_Medical_Course_Wastewater_Treatment_MD0161|US_Army_Medical_Course_Wastewater_Treatment_MD0161.pdf"
  "US_Army_Medical_Course_Arthropod_Control_MD0171|US_Army_Medical_Course_Arthropod_Control_MD0171.pdf"
  "US_Army_Medical_Course_Oral_And_Maxillofacial_Pathology_MD0511|US_Army_Medical_Course_Oral_and_Maxillofacial_Pathology_MD0511.pdf"
  "US_Army_Medical_Course_Taking_Vital_Signs_MD0531|US_Army_Medical_Course_Taking_Vital_Signs_MD0531.pdf"
  "US_Army_Medical_Course_Cardiopulmonary_Resuscitation_CPR_MD0532|US_Army_Medical_Course_Cardiopulmonary_Resuscitation_CPR_MD0532.pdf"
  "US_Army_Medical_Course_Treating_Fractures_in_the_Field_MD0533|US_Army_Medical_Course_Treating_Fractures_in_the_Field_MD0533.pdf"
  "US_Army_Medical_Course_Sterile_Procedures_MD0540|US_Army_Medical_Course_Sterile_Procedures_MD0540.pdf"
  "US_Army_Medical_Course_Eye_Ear_and_Nose_Injuries_MD0547|US_Army_Medical_Course_Eye_Ear_and_Nose_Injuries_MD0547.pdf"
  "US_Army_Medical_Course_Environmental_Injuries_MD0548|US_Army_Medical_Course_Environmental_Injuries_MD0548.pdf"
  "US_Army_Medical_Course_Psychosocial_Issues_MD0549|US_Army_Medical_Course_Psychosocial_Issues_MD0549.pdf"
  "US_Army_Medical_Course_Treating_Wounds_in_the_Field_MD0554|US_Army_Medical_Course_Treating_Wounds_in_the_Field_MD0554.pdf"
  "US_Army_Medical_Course_Basic_Patient_Care_Procedures_MD0556|US_Army_Medical_Course_Basic_Patient_Care_Procedures_MD0556.pdf"
  "US_Army_Medical_Course_The_Musculoskeletal_System_MD0577|US_Army_Medical_Course_The_Musculoskeletal_System_MD0577.pdf"
  "US_Army_Medical_Course_Food_Containers_MD0708|US_Army_Medical_Course_Food_Containers_MD0708.pdf"
  "US_Army_Medical_Course_Waterfoods_MD0711|US_Army_Medical_Course_Waterfoods_MD0711.pdf"
  "US_Army_Medical_Course_Prescription_Interpretation_MD0801|US_Army_Medical_Course_Prescription_Interpretation_MD0801.pdf"
  "US_Army_Medical_Course_Pharmaceutical_Calculations_MD0802|US_Army_Medical_Course_Pharmaceutical_Calculations_MD0802.pdf"
  "US_Army_Medical_Course_Pharmacology_I_MD0804|US_Army_Medical_Course_Pharmacology_I_MD0804.pdf"
  "US_Army_Medical_Course_Pharmacology_II_MD0805|US_Army_Medical_Course_Pharmacology_II_MD0805.pdf"
  "US_Army_Medical_Course_Pharmacology_III_MD0806|US_Army_Medical_Course_Pharmacology_III_MD0806.pdf"
  "US_Army_Medical_Course_Hematology_I_MD0853|US_Army_Medical_Course_Hematology_I_MD0853.pdf"
  "US_Army_Medical_Course_Mycology_MD0859|US_Army_Medical_Course_Mycology_MD0859.pdf"
  "US_Army_Medical_Course_Basic_Electrical_Circuits_MD0903|US_Army_Medical_Course_Basic_Electrical_Circuits_MD0903.pdf"
  "US_Army_Medical_Course_Nursing_Fundamentals_I_MD0905|US_Army_Medical_Course_Nursing_Fundamentals_I_MD0905.pdf"
  "US_Army_Medical_Course_Nursing_Fundamentals_II_MD0906|US_Army_Medical_Course_Nursing_Fundamentals_II_MD0906.pdf"
  "US_Army_Medical_Course_Special_Surgical_Procedures_II_MD0928|US_Army_Medical_Course_Special_Surgical_Procedures_II_MD0928.pdf"
  "US_Army_Medical_Course_Scrub_Gown_and_Glove_Procedures_MD0933|US_Army_Medical_Course_Scrub_Gown_and_Glove_Procedures_MD0933.pdf"
)

IA_BASE="https://archive.org/compress"
IA_FORMATS="formats=TEXT%20PDF,ARCHIVE%20BITTORRENT,METADATA,ITEM%20TILE"

SKIP_DOWNLOAD=0
SKIP_ZIM=0
DEPLOY=0
ZIM_DEST=""
CONTAINER=""

for arg in "$@"; do
  case $arg in
    --skip-download)   SKIP_DOWNLOAD=1 ;;
    --skip-zim)        SKIP_ZIM=1 ;;
    --deploy)          DEPLOY=1 ;;
    --zim-dest=*)      ZIM_DEST="${arg#*=}" ;;
    --container=*)     CONTAINER="${arg#*=}" ;;
    *)                 echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
CYN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

if [[ $DEPLOY -eq 1 ]]; then
  if [[ -z "$ZIM_DEST" ]]; then
    echo -e "${RED}[ERROR]${NC} --deploy requires --zim-dest=/path/to/kiwix/library"
    exit 1
  fi
  if [[ -z "$CONTAINER" ]]; then
    echo -e "${RED}[ERROR]${NC} --deploy requires --container=<container_name>"
    exit 1
  fi
fi

banner() {
  echo -e "${CYN}"
  echo "  ╔══════════════════════════════════════════════════════════════╗"
  echo "  ║        US ARMY MEDICAL COURSE ARCHIVE -- INSTALLER           ║"
  echo "  ║        PROJECT NOMAD // KIWIX OFFLINE SYSTEM                 ║"
  echo "  ╚══════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

check_deps() {
  echo -e "${BOLD}Checking dependencies...${NC}"
  local missing=0

  for cmd in wget unzip python3; do
    if command -v "$cmd" &>/dev/null; then
      echo -e "  ${GRN}[OK]${NC}  $cmd"
    else
      echo -e "  ${RED}[MISSING]${NC}  $cmd"
      missing=1
    fi
  done

  if [[ $SKIP_ZIM -eq 0 ]]; then
    if command -v zimwriterfs &>/dev/null; then
      echo -e "  ${GRN}[OK]${NC}  zimwriterfs ($(zimwriterfs --version 2>&1 | head -1))"
    else
      echo -e "  ${RED}[MISSING]${NC}  zimwriterfs"
      echo -e "             Install with: sudo apt install zim-tools"
      missing=1
    fi
  fi

  if [[ $missing -eq 1 ]]; then
    echo ""
    echo -e "${RED}[ERROR]${NC} Missing dependencies. Install them and re-run."
    exit 1
  fi
  echo ""
}

download_pdfs() {
  echo -e "${BOLD}Step 1: Downloading PDF collection from archive.org${NC}"
  echo ""
  echo -e "  Downloading ${#COURSE_LIST[@]} course files individually."
  echo -e "  Each is fetched as a zip from IA's compress endpoint, the PDF"
  echo -e "  extracted, and the zip discarded. Failed items are skipped with"
  echo -e "  a warning so the rest of the run can continue."
  echo ""

  mkdir -p "$PDF_DIR"

  local tmp_zip="${SCRIPT_DIR}/_tmp_course.zip"
  local total=${#COURSE_LIST[@]}
  local idx=0
  local failed=0

  for entry in "${COURSE_LIST[@]}"; do
    idx=$((idx + 1))
    local identifier="${entry%%|*}"
    local dest_pdf="${entry##*|}"
    local dest_path="${PDF_DIR}/${dest_pdf}"
    local url="${IA_BASE}/${identifier}/${IA_FORMATS}"

    printf "  [%2d/%d]  %s\n" "$idx" "$total" "$identifier"

    if [[ -f "$dest_path" ]]; then
      echo -e "          ${YLW}[SKIP]${NC}  already exists"
      continue
    fi

    # Download zip
    if ! wget \
        --quiet \
        --tries=3 \
        --timeout=120 \
        --waitretry=15 \
        --user-agent="Mozilla/5.0 (compatible; personal-archive-downloader)" \
        -O "$tmp_zip" \
        "$url" 2>&1; then
      echo -e "          ${RED}[FAIL]${NC}  download error -- skipping"
      rm -f "$tmp_zip"
      failed=$((failed + 1))
      continue
    fi

    # Extract the first PDF found in the zip, rename to our target
    local pdf_in_zip
    pdf_in_zip=$(unzip -l "$tmp_zip" 2>/dev/null | grep -i '\.pdf$' | awk '{print $NF}' | head -1)

    if [[ -z "$pdf_in_zip" ]]; then
      echo -e "          ${RED}[FAIL]${NC}  no PDF found in zip -- skipping"
      rm -f "$tmp_zip"
      failed=$((failed + 1))
      continue
    fi

    unzip -o -j "$tmp_zip" "$pdf_in_zip" -d "$PDF_DIR" &>/dev/null
    # Rename the extracted file to our canonical name
    local extracted_name
    extracted_name=$(basename "$pdf_in_zip")
    if [[ "$extracted_name" != "$dest_pdf" ]]; then
      mv "${PDF_DIR}/${extracted_name}" "$dest_path"
    fi

    rm -f "$tmp_zip"
    echo -e "          ${GRN}[OK]${NC}"
    sleep 1  # be polite to archive.org
  done

  echo ""
  local pdf_count
  pdf_count=$(find "$PDF_DIR" -name "*.pdf" | wc -l)
  echo -e "  ${GRN}[DONE]${NC}  ${pdf_count} PDFs in ${PDF_DIR}  (${failed} failed)"
  if [[ $failed -gt 0 ]]; then
    echo -e "  ${YLW}[WARN]${NC}  ${failed} course(s) failed. Check slugs manually and re-run"
    echo -e "         without --skip-download to retry missing files."
  fi
  echo ""
}

build_zim() {
  echo -e "${BOLD}Step 2: Building ZIM file${NC}"

  if [[ ! -f "${HTML_DIR}/index.html" ]]; then
    echo -e "  ${RED}[ERROR]${NC}  index.html not found at ${HTML_DIR}/index.html"
    exit 1
  fi

  local pdf_count
  pdf_count=$(find "$PDF_DIR" -name "*.pdf" 2>/dev/null | wc -l)
  echo -e "  ${CYN}Source:${NC}  ${HTML_DIR}"
  echo -e "  ${CYN}Output:${NC}  ${ZIM_OUT}"
  echo -e "  ${CYN}PDFs:${NC}    ${pdf_count} files"
  echo ""

  if [[ -f "$ZIM_OUT" ]]; then
    echo -e "  ${YLW}[INFO]${NC}  Removing existing $(basename "$ZIM_OUT")..."
    rm -f "$ZIM_OUT"
  fi

  echo -e "  ${YLW}[INFO]${NC}  Running zimwriterfs -- this will take several minutes..."
  echo "────────────────────────────────────────────────────────────────"

  zimwriterfs \
    --welcome=index.html \
    --illustration=favicon.png \
    --language=eng \
    --name="army_medical_course" \
    --title="US Army Medical Course Archive" \
    --description="US Army Medical Department correspondence course materials" \
    --longDescription="A collection of US Army Medical Department Center and School correspondence course materials (MD-series) covering anatomy, physiology, pharmacology, clinical procedures, field medicine, nursing, laboratory science, and preventive medicine. Sourced from the Internet Archive." \
    --creator="US Government / US Army" \
    --publisher="ProjectNomad" \
    --tags="_category:medicine;military;medical;_ftindex:yes" \
    --verbose \
    "$HTML_DIR" \
    "$ZIM_OUT"

  echo "────────────────────────────────────────────────────────────────"
  echo ""

  if [[ -f "$ZIM_OUT" ]]; then
    local size
    size=$(du -sh "$ZIM_OUT" | cut -f1)
    echo -e "  ${GRN}[OK]${NC}  ZIM created: $(basename "$ZIM_OUT") (${size})"
  else
    echo -e "  ${RED}[ERROR]${NC}  ZIM file not found after build."
    exit 1
  fi
  echo ""
}

deploy_instructions() {
  echo -e "${BOLD}Done. To deploy to Kiwix:${NC}"
  echo ""
  echo    "  1. Copy the ZIM file to your Kiwix library directory:"
  echo    "     cp army_medical_course.zim /your/kiwix/library/"
  echo ""
  echo    "  2. Set correct ownership (use the container's uid):"
  echo    "     KIWIX_UID=\$(sudo docker exec <kiwix_container> id -u)"
  echo    "     sudo chown \$KIWIX_UID:\$KIWIX_UID /your/kiwix/library/army_medical_course.zim"
  echo    "     sudo chown \$KIWIX_UID:\$KIWIX_UID /your/kiwix/library/kiwix-library.xml"
  echo ""
  echo    "  3. Register with Kiwix:"
  echo    "     sudo docker exec -u \$KIWIX_UID <kiwix_container> kiwix-manage \\"
  echo    "       /data/kiwix-library.xml add \\"
  echo    "       /data/army_medical_course.zim"
  echo ""
  echo    "  4. Restart the Kiwix container:"
  echo    "     sudo docker restart <kiwix_container>"
  echo ""
  echo    "  Or run this script with --deploy to do all of the above automatically:"
  echo    "     ./install.sh --skip-download --deploy \\"
  echo    "       --zim-dest=/your/kiwix/library \\"
  echo    "       --container=<kiwix_container>"
  echo ""
}

deploy() {
  local zim_name
  zim_name=$(basename "$ZIM_OUT")
  local dest_zim="${ZIM_DEST}/${zim_name}"
  local dest_xml="${ZIM_DEST}/kiwix-library.xml"

  echo -e "${BOLD}Step 3: Deploying to Kiwix${NC}"
  echo -e "  ${CYN}Container :${NC} ${CONTAINER}"
  echo -e "  ${CYN}Library   :${NC} ${ZIM_DEST}"
  echo ""

  if ! sudo docker inspect "$CONTAINER" &>/dev/null; then
    echo -e "  ${RED}[ERROR]${NC}  Container '${CONTAINER}' not found."
    exit 1
  fi

  local kiwix_uid
  kiwix_uid=$(sudo docker exec "$CONTAINER" id -u)
  echo -e "  ${YLW}[INFO]${NC}  Container runs as uid ${kiwix_uid}"

  echo -e "  ${YLW}[INFO]${NC}  Copying $(basename "$ZIM_OUT") to ${ZIM_DEST}..."
  sudo cp "$ZIM_OUT" "$dest_zim"

  echo -e "  ${YLW}[INFO]${NC}  Setting ownership to ${kiwix_uid}:${kiwix_uid}..."
  sudo chown "${kiwix_uid}:${kiwix_uid}" "$dest_zim"
  if [[ -f "$dest_xml" ]]; then
    sudo chown "${kiwix_uid}:${kiwix_uid}" "$dest_xml"
  fi

  echo -e "  ${YLW}[INFO]${NC}  Removing any existing entries for ${zim_name} from Kiwix library..."
  while true; do
    local existing_id
    existing_id=$(sudo docker exec -u "$kiwix_uid" "$CONTAINER" \
      kiwix-manage /data/kiwix-library.xml show 2>/dev/null | \
      grep -B5 "path:.*${zim_name}" | grep "^id:" | head -1 | awk '{print $2}' || true)

    if [[ -z "$existing_id" ]]; then
      break
    fi

    sudo docker exec -u "$kiwix_uid" "$CONTAINER" \
      kiwix-manage /data/kiwix-library.xml remove "$existing_id"
    echo -e "  ${YLW}[INFO]${NC}  Removed entry: ${existing_id}"
  done

  echo -e "  ${YLW}[INFO]${NC}  Registering with Kiwix library..."
  sudo docker exec -u "$kiwix_uid" "$CONTAINER" \
    kiwix-manage /data/kiwix-library.xml add "/data/${zim_name}"

  echo -e "  ${YLW}[INFO]${NC}  Restarting ${CONTAINER}..."
  sudo docker restart "$CONTAINER"

  echo ""
  echo -e "  ${GRN}[OK]${NC}  Deployment complete. Kiwix is restarting."
  echo ""
}

if [[ $SKIP_DOWNLOAD -eq 0 ]]; then
  download_pdfs
else
  echo -e "${YLW}[INFO]${NC}  Skipping download (--skip-download)."
  echo ""
fi

if [[ $SKIP_ZIM -eq 0 ]]; then
  build_zim
else
  echo -e "${YLW}[INFO]${NC}  Skipping ZIM build (--skip-zim)."
  echo ""
fi

if [[ $DEPLOY -eq 1 ]]; then
  deploy
else
  deploy_instructions
fi
