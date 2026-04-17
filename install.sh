#!/usr/bin/env bash
# =============================================================================
# install.sh
# Installer for the US Army Medical Course offline archive.
#
# This script will:
#   1. Check dependencies
#   2. Download all PDFs from archive.org as a single zip
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
# To force a fresh download even if PDFs already exist:
#   ./install.sh --download
#
# To skip the ZIM build (just download the PDFs):
#   ./install.sh --skip-zim
#
# To automatically deploy to a local Kiwix container after building:
#   ./install.sh --deploy --zim-dest=/path/to/kiwix/library --container=nomad_kiwix_server
#
# All options can be combined:
#   ./install.sh --deploy --zim-dest=/opt/project-nomad/storage/zim --container=nomad_kiwix_server
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HTML_DIR="${SCRIPT_DIR}/html"
PDF_DIR="${HTML_DIR}/pdfs"
ZIM_OUT="${SCRIPT_DIR}/army_medical_course.zim"

ARCHIVE_URL="https://archive.org/compress/us-army-medical-course/formats=TEXT%20PDF,ARCHIVE%20BITTORRENT,METADATA"

FORCE_DOWNLOAD=0
SKIP_ZIM=0
DEPLOY=0
ZIM_DEST=""
CONTAINER=""

for arg in "$@"; do
  case $arg in
    --download)        FORCE_DOWNLOAD=1 ;;
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
  echo -e "  ${CYN}URL:${NC} ${ARCHIVE_URL}"
  echo ""

  mkdir -p "$PDF_DIR"

  local tmp_zip="${SCRIPT_DIR}/medical_course_download.zip"

  if [[ -f "$tmp_zip" ]]; then
    echo -e "  ${YLW}[INFO]${NC}  Found existing download at ${tmp_zip}"
    read -rp "  Re-use it? [Y/n]: " reuse
    reuse="${reuse:-Y}"
    if [[ "$reuse" =~ ^[Nn]$ ]]; then
      rm -f "$tmp_zip"
    fi
  fi

  if [[ ! -f "$tmp_zip" ]]; then
    echo -e "  ${YLW}[GET]${NC}   Downloading zip..."
    wget \
      --progress=bar:force \
      --tries=3 \
      --timeout=300 \
      --waitretry=30 \
      --continue \
      --user-agent="Mozilla/5.0 (compatible; personal-archive-downloader)" \
      -O "$tmp_zip" \
      "$ARCHIVE_URL"
    echo ""
  fi

  echo -e "  ${YLW}[INFO]${NC}  Extracting PDFs to ${PDF_DIR}..."
  echo ""

  unzip -o -j "$tmp_zip" "*.pdf" -d "$PDF_DIR" 2>&1 | \
    grep -E "inflating|extracting" | \
    awk '{print "  extracting: " $NF}' || true

  local pdf_count
  pdf_count=$(find "$PDF_DIR" -name "*.pdf" | wc -l)
  echo ""
  echo -e "  ${GRN}[OK]${NC}   ${pdf_count} PDFs extracted to ${PDF_DIR}"
  echo ""

  read -rp "  Delete the downloaded zip file to save disk space? [Y/n]: " cleanup
  cleanup="${cleanup:-Y}"
  if [[ ! "$cleanup" =~ ^[Nn]$ ]]; then
    rm -f "$tmp_zip"
    echo -e "  ${YLW}[INFO]${NC}  Zip removed."
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
  pdf_count=$(find "$PDF_DIR" -name "*.pdf" 2>/dev/null | wc -l || true)
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
  echo    "     ./install.sh --deploy \\"
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

banner
check_deps

pdf_count=$(find "$PDF_DIR" -name "*.pdf" 2>/dev/null | wc -l || true)
if [[ $FORCE_DOWNLOAD -eq 1 ]]; then
  echo -e "${YLW}[INFO]${NC}  --download specified, forcing fresh download."
  if [[ $pdf_count -gt 0 ]]; then
    echo -e "${YLW}[INFO]${NC}  Removing existing PDFs from ${PDF_DIR}..."
    rm -f "${PDF_DIR}"/*.pdf
  fi
  echo ""
  download_pdfs
elif [[ $pdf_count -gt 0 ]]; then
  echo -e "${YLW}[INFO]${NC}  Found ${pdf_count} PDFs in ${PDF_DIR}, skipping download."
  echo -e "         Run with --download to force a fresh download."
  echo ""
else
  download_pdfs
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
