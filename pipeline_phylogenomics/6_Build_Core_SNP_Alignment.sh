#!/usr/bin/env bash
#SBATCH --job-name=phy06_alignment
#SBATCH --partition=batch
#SBATCH --cpus-per-task=2
#SBATCH --mem=6G
#SBATCH --time=00:30:00
###############################################################################
# 6_Build_Core_SNP_Alignment.sh
#
# NARRATIVE -- WHAT "CORE-SNP ALIGNMENT" MEANS HERE, PRECISELY:
# A site enters the alignment only if it is (a) inside every isolate's own
# callable region (Script 5's cohort-wide intersection), (b) a real
# biallelic SNP (no indels -- indel alignment columns are not meaningfully
# comparable across isolates the way single-base substitutions are), and
# (c) genotyped with no missing data in any of the 5 isolates. Missing
# a site because coverage was too low in even ONE isolate silently biases
# a tree toward whichever isolates happen to share the best coverage --
# excluding it entirely is the conservative, defensible choice.
#
# utils/vcf_to_snp_alignment.py also runs a sliding-window SNP-density
# scan as a lightweight recombination screen (see that script's own
# comment for exactly what it does and does not detect).
###############################################################################
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd bcftools
require_cmd python3
require_cmd samtools

REFERENCE="${REFERENCE_ROOT}/GCF_000013425.1_NCTC8325.fasta"
raw="${OUTPUT_DIR}/variants/raw_calls.vcf.gz"
callable_bed="${OUTPUT_DIR}/variants/cohort_callable_regions.bed"
require_file "${REFERENCE}"; require_file "${raw}"; require_file "${callable_bed}"
[[ -f "${REFERENCE}.fai" ]] || samtools faidx "${REFERENCE}"

mkdir -p "${OUTPUT_DIR}/alignment"

raw_count=$(bcftools view -H "${raw}" | wc -l)

note "Restricting to the cohort-wide callable region, QUAL >= ${MIN_QUAL}, and biallelic SNPs only..."
bcftools view -R "${callable_bed}" "${raw}" -Ou \
  | bcftools filter -e "QUAL<${MIN_QUAL}" -Ou \
  | bcftools view -m2 -M2 -v snps -Oz -o "${OUTPUT_DIR}/alignment/biallelic_snps.vcf.gz"
bcftools index -t "${OUTPUT_DIR}/alignment/biallelic_snps.vcf.gz"

biallelic_count=$(bcftools view -H "${OUTPUT_DIR}/alignment/biallelic_snps.vcf.gz" | wc -l)

note "Building the core-SNP FASTA alignment (sites with no missing genotype in any isolate)..."
cut -f1,2 "${REFERENCE}.fai" > "${OUTPUT_DIR}/alignment/contig_lengths.tsv"
python3 "${SCRIPT_DIR}/utils/vcf_to_snp_alignment.py" \
  --vcf "${OUTPUT_DIR}/alignment/biallelic_snps.vcf.gz" \
  --fasta-out "${OUTPUT_DIR}/alignment/core_snp_alignment.fasta" \
  --sites-out "${OUTPUT_DIR}/alignment/core_snp_sites.tsv" \
  --density-out "${OUTPUT_DIR}/alignment/snp_density_windows.tsv" \
  --window-size 5000 \
  --contig-length-file "${OUTPUT_DIR}/alignment/contig_lengths.tsv"

final_count=$(($(wc -l < "${OUTPUT_DIR}/alignment/core_snp_sites.tsv") - 1))
flagged=$(awk -F'\t' 'NR>1 && $5=="YES"' "${OUTPUT_DIR}/alignment/snp_density_windows.tsv" | wc -l)

{
  echo -e "metric\tvalue"
  echo -e "raw_call_count\t${raw_count}"
  echo -e "biallelic_snp_count_after_qual_and_region_filter\t${biallelic_count}"
  echo -e "final_core_snp_sites_no_missing_data\t${final_count}"
  echo -e "high_density_windows_flagged\t${flagged}"
} > "${OUTPUT_DIR}/alignment/alignment_build_summary.tsv"
cat "${OUTPUT_DIR}/alignment/alignment_build_summary.tsv"

note "OK: ${OUTPUT_DIR}/alignment/core_snp_alignment.fasta (${final_count} sites x 5 isolates) is ready."
note "    Continue to Script 7 to infer a tree from this alignment."
