#!/usr/bin/env bash
# Shared, intentionally small helper library for Scripts 1-9.
set -euo pipefail
IFS=$'\n\t'

PIPELINE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROJECT_ROOT=$(cd "${PIPELINE_DIR}/.." && pwd)
export PROJECT_ROOT

CONFIG_FILE=${CONFIG_FILE:-"${PROJECT_ROOT}/config/project.env"}
if [[ ! -f "${CONFIG_FILE}" ]]; then
    printf 'ERROR: %s is missing. Copy project.env.example to project.env and review it.\n' "${CONFIG_FILE}" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "${CONFIG_FILE}"

mkdir -p "${WORKDIR}" "${RAW_DIR}" "${OUTPUT_DIR}" \
  "${WORKDIR}/logs" "${WORKDIR}/checksums" \
  "${OUTPUT_DIR}/provenance"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
require_file() { [[ -s "$1" ]] || die "Required non-empty file not found: $1"; }

download_one() {
  local url=$1 expected_md5=$2 destination=$3
  require_cmd curl
  require_cmd md5sum
  [[ "${url}" =~ ^https?:// ]] || url="https://${url}"
  if [[ ! -s "${destination}" ]]; then
    curl --fail --location --retry 5 --retry-delay 5 --continue-at - \
      --output "${destination}.partial" "${url}"
    mv "${destination}.partial" "${destination}"
  fi
  printf '%s  %s\n' "${expected_md5}" "${destination}" | md5sum --check --status \
    || die "MD5 mismatch: ${destination}"
}

fetch_ena_run() {
  local run=$1 label=$2
  local report="${WORKDIR}/logs/${run}_ena_report.tsv"
  curl --fail --location --retry 5 \
    "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${run}&result=read_run&fields=run_accession,fastq_ftp,fastq_md5,library_layout&format=tsv" \
    --output "${report}"
  require_file "${report}"

  local layout ftp md5
  layout=$(awk -F'\t' 'NR==2{print $4}' "${report}")
  ftp=$(awk -F'\t' 'NR==2{print $2}' "${report}")
  md5=$(awk -F'\t' 'NR==2{print $3}' "${report}")

  IFS=';' read -r -a urls <<< "${ftp}"
  IFS=';' read -r -a sums <<< "${md5}"

  if [[ "${layout}" == "PAIRED" ]]; then
    [[ ${#urls[@]} -eq 2 ]] || die "Expected two paired FASTQ files for ${run}; found ${#urls[@]}"
    download_one "${urls[0]}" "${sums[0]}" "${RAW_DIR}/${label}_R1.fastq.gz"
    download_one "${urls[1]}" "${sums[1]}" "${RAW_DIR}/${label}_R2.fastq.gz"
  else
    download_one "${urls[0]}" "${sums[0]}" "${RAW_DIR}/${label}.fastq.gz"
  fi
}

# Five real PRJNA983748 isolates (Chakrawarti et al. 2024), chosen for real
# epidemiological diversity confirmed via each isolate's own real NCBI
# BioSample record -- not just picked for read depth like the sibling
# genome-assembly/variant-calling repos' 3-isolate subset. Three of these
# five (SAMN36020147, SAMN36020150, SAMN36020166) ARE that same subset,
# reused for continuity; two more (SAMN36020155, SAMN36020190) are added
# here specifically because 3 taxa cannot show a real branch-support
# comparison -- an unrooted 3-taxon tree has exactly one possible topology.
ISOLATE_IDS=(SAMN36020147 SAMN36020150 SAMN36020166 SAMN36020155 SAMN36020190)
declare -A ILLUMINA_RUN=(
  [SAMN36020147]=SRR25741607 [SAMN36020150]=SRR25741675 [SAMN36020166]=SRR25741586
  [SAMN36020155]=SRR25741587 [SAMN36020190]=SRR25741539
)
# Real BioSample metadata (farm/isolate ID, isolation source, host, MLST
# strain, collection year) -- used by Script 8 for the metadata overlay
# and outbreak-context interpretation. Confirmed directly against each
# isolate's own NCBI BioSample record, not inferred or assumed.
declare -A ISOLATE_LABEL=(
  [SAMN36020147]=AC06-105 [SAMN36020150]=AC06-111 [SAMN36020166]=OF-17-34
  [SAMN36020155]=AC12-45 [SAMN36020190]=AC05-56
)
declare -A ISOLATE_SOURCE=(
  [SAMN36020147]="human hand swab" [SAMN36020150]="human nasal swab" [SAMN36020166]="bulk tank milk"
  [SAMN36020155]="human nasal swab" [SAMN36020190]="human hand swab"
)
declare -A ISOLATE_STRAIN=(
  [SAMN36020147]=ST398 [SAMN36020150]=ST398 [SAMN36020166]=ST8
  [SAMN36020155]=ST7 [SAMN36020190]=ST5957
)
declare -A ISOLATE_YEAR=(
  [SAMN36020147]=2018 [SAMN36020150]=2018 [SAMN36020166]=2013
  [SAMN36020155]=2018 [SAMN36020190]=2018
)
declare -A ISOLATE_FARM=(
  [SAMN36020147]=AC06 [SAMN36020150]=AC06 [SAMN36020166]=OF-17
  [SAMN36020155]=AC12 [SAMN36020190]=AC05
)

record_versions() {
  local out="${OUTPUT_DIR}/provenance/software_versions.tsv"
  printf 'tool\tversion\n' > "${out}"
  for tool in curl md5sum fastqc bwa samtools bcftools bedtools iqtree2 python3; do
    if command -v "${tool}" >/dev/null 2>&1; then
      version=$(${tool} --version 2>&1 | head -n 1 || true)
      printf '%s\t%s\n' "${tool}" "${version//$'\t'/ }" >> "${out}"
    fi
  done
}
