#!/usr/bin/env bash
#SBATCH --job-name=phy05_call
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
###############################################################################
# 5_Call_Variants_Bcftools.sh
#
# --ploidy 1 for the same real reason as the sibling variant-calling repo:
# S. aureus is haploid, and bcftools call -mv defaults to diploid regardless
# of organism. All 5 isolates are called jointly in one command so the
# resulting VCF's sample columns are directly usable as the core-genome
# alignment's per-isolate sequences in Script 6, with consistent site
# coordinates across all five by construction.
###############################################################################
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd bcftools
require_cmd bedtools
require_cmd awk
require_cmd samtools

REFERENCE="${REFERENCE_ROOT}/GCF_000013425.1_NCTC8325.fasta"
require_file "${REFERENCE}"
mkdir -p "${OUTPUT_DIR}/variants" "${OUTPUT_DIR}/alignment_qc"

bams=()
for isolate in "${ISOLATE_IDS[@]}"; do
  bam="${OUTPUT_DIR}/alignments/${isolate}.dedup.bam"
  require_file "${bam}"
  bams+=("${bam}")

  note "Computing ${isolate}'s callable region (depth ${MIN_DEPTH}-${MAX_DEPTH})..."
  samtools depth -a "${bam}" > "${WORKDIR}/logs/${isolate}_depth.tmp"
  awk -v min="${MIN_DEPTH}" -v max="${MAX_DEPTH}" \
    '$3 >= min && $3 <= max {print $1"\t"$2-1"\t"$2}' "${WORKDIR}/logs/${isolate}_depth.tmp" \
    | sort -k1,1 -k2,2n | bedtools merge -i - \
    > "${OUTPUT_DIR}/alignment_qc/${isolate}_callable_regions.bed"
  rm -f "${WORKDIR}/logs/${isolate}_depth.tmp"
done

note "Calling variants jointly across all ${#bams[@]} isolates (ploidy 1, haploid)..."
bcftools mpileup -f "${REFERENCE}" -a AD,DP,SP -Ou "${bams[@]}" \
  | bcftools call --ploidy 1 -mv -Oz -o "${OUTPUT_DIR}/variants/raw_calls.vcf.gz"
bcftools index -t "${OUTPUT_DIR}/variants/raw_calls.vcf.gz"

het_count=$(bcftools view -H "${OUTPUT_DIR}/variants/raw_calls.vcf.gz" \
  | awk -F'\t' '{for(i=10;i<=NF;i++){split($i,gt,":"); if(gt[1]=="0/1"||gt[1]=="1/0") c++}} END{print c+0}')
[[ "${het_count}" -eq 0 ]] || die "${het_count} genotype(s) called heterozygous despite --ploidy 1"

note "Building the cohort-wide callable-region BED (intersection across all 5 isolates)..."
cp "${OUTPUT_DIR}/alignment_qc/${ISOLATE_IDS[0]}_callable_regions.bed" "${OUTPUT_DIR}/variants/cohort_callable_regions.bed"
for isolate in "${ISOLATE_IDS[@]:1}"; do
  bedtools intersect -a "${OUTPUT_DIR}/variants/cohort_callable_regions.bed" \
    -b "${OUTPUT_DIR}/alignment_qc/${isolate}_callable_regions.bed" \
    > "${OUTPUT_DIR}/variants/cohort_callable_regions.tmp.bed"
  mv "${OUTPUT_DIR}/variants/cohort_callable_regions.tmp.bed" "${OUTPUT_DIR}/variants/cohort_callable_regions.bed"
done

note "OK: raw joint call set is ${OUTPUT_DIR}/variants/raw_calls.vcf.gz (0 heterozygous genotypes, as expected)."
note "    Cohort-wide callable region: ${OUTPUT_DIR}/variants/cohort_callable_regions.bed"
note "    Continue to Script 6 to build the core-SNP alignment."
