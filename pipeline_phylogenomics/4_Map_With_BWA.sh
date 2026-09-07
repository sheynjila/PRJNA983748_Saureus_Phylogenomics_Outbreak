#!/usr/bin/env bash
#SBATCH --job-name=phy04_bwa
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=12G
#SBATCH --time=02:00:00
###############################################################################
# 4_Map_With_BWA.sh
#
# Same reference (NCTC 8325, GCF_000013425.1) as the sibling variant-calling
# repo, for the same reason: a consistent, well-curated closed reference
# across all five isolates so their core-genome alignment (Script 6) is
# built against one shared coordinate system.
###############################################################################
set -euo pipefail
SCRIPT_DIR="${PIPELINE_SCRIPT_DIR:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}}"
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd bwa
require_cmd samtools

REFERENCE="${REFERENCE_ROOT}/GCF_000013425.1_NCTC8325.fasta"
require_file "${REFERENCE}"
if [[ ! -f "${REFERENCE}.bwt" ]]; then
  note "Indexing the reference (first run only)..."
  bwa index "${REFERENCE}"
fi
[[ -f "${REFERENCE}.fai" ]] || samtools faidx "${REFERENCE}"

mkdir -p "${OUTPUT_DIR}/alignments"

for isolate in "${ISOLATE_IDS[@]}"; do
  r1="${RAW_DIR}/${isolate}_R1.fastq.gz"; r2="${RAW_DIR}/${isolate}_R2.fastq.gz"
  require_file "${r1}"; require_file "${r2}"

  note "Mapping ${isolate} (${ISOLATE_LABEL[${isolate}]}) against NCTC 8325..."
  bwa mem -t "${THREADS}" \
    -R "@RG\tID:${isolate}\tSM:${isolate}\tLB:${isolate}\tPL:ILLUMINA" \
    "${REFERENCE}" "${r1}" "${r2}" \
    | samtools fixmate -m -@ "${THREADS}" - - \
    | samtools sort -@ "${THREADS}" -o "${OUTPUT_DIR}/alignments/${isolate}.sorted.bam" -

  samtools markdup -@ "${THREADS}" \
    "${OUTPUT_DIR}/alignments/${isolate}.sorted.bam" \
    "${OUTPUT_DIR}/alignments/${isolate}.dedup.bam"
  samtools index "${OUTPUT_DIR}/alignments/${isolate}.dedup.bam"

  rg_sample=$(samtools view -H "${OUTPUT_DIR}/alignments/${isolate}.dedup.bam" | grep '^@RG' | sed -E 's/.*SM:([^\t]+).*/\1/')
  [[ "${rg_sample}" == "${isolate}" ]] || die "Read-group SM (${rg_sample}) does not match isolate (${isolate})"
done

note "OK: 5 deduplicated, verified alignments are in ${OUTPUT_DIR}/alignments/."
note "    Continue to Script 5 to call variants jointly across all 5 isolates."
