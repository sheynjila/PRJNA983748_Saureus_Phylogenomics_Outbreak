#!/usr/bin/env bash
#SBATCH --job-name=phy02_fastqc
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=00:30:00
###############################################################################
# 2_Interpret_FastQC_Diagnostics.sh
###############################################################################
set -euo pipefail
SCRIPT_DIR="${PIPELINE_SCRIPT_DIR:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}}"
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd fastqc

PILOT_ISOLATE="${ISOLATE_IDS[0]}"
mkdir -p "${WORKDIR}/qc_before"

fastqc "${RAW_DIR}/${PILOT_ISOLATE}_R1.fastq.gz" "${RAW_DIR}/${PILOT_ISOLATE}_R2.fastq.gz" \
  -o "${WORKDIR}/qc_before" -t "${THREADS}" --extract

for READ in R1 R2; do
  summary="${WORKDIR}/qc_before/${PILOT_ISOLATE}_${READ}_fastqc/summary.txt"
  echo "---- ${PILOT_ISOLATE} ${READ}: FastQC verdicts ----"
  cat "${summary}"
done

note "OK: review the summaries above before trusting Script 4's mapping quality."
