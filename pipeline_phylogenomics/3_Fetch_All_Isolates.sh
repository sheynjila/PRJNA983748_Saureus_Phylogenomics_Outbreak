#!/usr/bin/env bash
#SBATCH --job-name=phy03_fetchall
#SBATCH --partition=batch
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=01:00:00
###############################################################################
# 3_Fetch_All_Isolates.sh
###############################################################################
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd curl

for isolate in "${ISOLATE_IDS[@]:1}"; do
  note "Fetching ${isolate} (${ISOLATE_LABEL[${isolate}]}, ${ISOLATE_SOURCE[${isolate}]}, ${ISOLATE_STRAIN[${isolate}]}, ${ISOLATE_YEAR[${isolate}]}, farm ${ISOLATE_FARM[${isolate}]})..."
  fetch_ena_run "${ILLUMINA_RUN[${isolate}]}" "${isolate}"
  md5sum "${RAW_DIR}/${isolate}"_*.fastq.gz > "${WORKDIR}/checksums/${isolate}_raw.md5"
done

note "OK: all ${#ISOLATE_IDS[@]} isolates' Illumina reads are now in ${RAW_DIR}."
