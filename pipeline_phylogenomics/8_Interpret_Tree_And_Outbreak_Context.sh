#!/usr/bin/env bash
#SBATCH --job-name=phy08_interpret
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:30:00
###############################################################################
# 8_Interpret_Tree_And_Outbreak_Context.sh
#
# NARRATIVE:
# Overlays each isolate's REAL BioSample metadata (farm, isolation source,
# MLST strain, collection year -- confirmed against each isolate's own
# NCBI BioSample record, not inferred from the tree) onto the rooted tree's
# tip labels, then writes an outbreak-interpretation template that states
# the module's own guardrails explicitly against THIS real dataset rather
# than as generic boilerplate: sampling is 5 of the source study's real 62
# isolates (sparse), one isolate (the milk sample) is the only non-human
# source present, and genetic relatedness here is not evidence of a direct
# transmission event regardless of what the tree shows.
###############################################################################
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd python3

tree="${OUTPUT_DIR}/tree/saureus_core_snp.contree"
require_file "${tree}"

python3 "${SCRIPT_DIR}/utils/root_and_interpret_tree.py" \
  --tree "${tree}" \
  --out-newick "${OUTPUT_DIR}/tree/saureus_core_snp.midpoint_rooted.nwk" \
  --out-summary "${OUTPUT_DIR}/tree/tree_support_summary.tsv" \
  --support-threshold "${UFBOOT_SUPPORT_THRESHOLD}"

note "Tree support summary:"
cat "${OUTPUT_DIR}/tree/tree_support_summary.tsv"

REPORT="${OUTPUT_DIR}/tree/metadata_and_outbreak_context.md"
{
  echo "# Isolate metadata overlay"
  echo
  echo "| Isolate | Real farm/isolate ID | Isolation source | MLST strain | Year |"
  echo "|---|---|---|---|---|"
  for isolate in "${ISOLATE_IDS[@]}"; do
    echo "| ${isolate} | ${ISOLATE_LABEL[${isolate}]} | ${ISOLATE_SOURCE[${isolate}]} | ${ISOLATE_STRAIN[${isolate}]} | ${ISOLATE_YEAR[${isolate}]} |"
  done
  echo
  echo "This table is independent evidence, confirmed against each isolate's own real NCBI BioSample record -- it is not derived from the tree and should be read alongside it, not substituted for genomic distance."
  echo
  echo "## Outbreak interpretation (fill in by hand, using the tree + table above)"
  echo
  echo "1. Do SAMN36020147 and SAMN36020150 (same real farm AC06, same real year 2018, same real MLST ST398) form a well-supported clade in the rooted tree (support >= ${UFBOOT_SUPPORT_THRESHOLD})? If yes, this is consistent with within-farm spread -- but consistent-with is not proof-of; state what additional evidence (e.g. contact tracing, more isolates from the same farm) would be needed to say more."
  echo "2. Where does SAMN36020166 (the only non-human isolate here -- bulk tank milk, real farm OF-17, real MLST ST8, real year 2013) fall relative to the four human isolates? A milk isolate that is genetically distant from every human isolate here does NOT prove no human-dairy transmission occurred anywhere in the real 62-isolate study -- it only describes these five isolates."
  echo "3. Which branches in the rooted tree fall below the ${UFBOOT_SUPPORT_THRESHOLD}% UFBoot threshold (see tree_support_summary.tsv)? State plainly that any relationship implied only by those branches is not well supported by this data, rather than reporting the tree's topology as if every branch were equally confident."
  echo
  echo "## Explicit limitations"
  echo
  echo "- Only 5 of this real study's 62 real isolates are used. Sparse, non-random sampling can change which isolates appear to cluster together -- a different 5-isolate subset of the same real cohort could produce a visibly different tree even though nothing about the underlying biology changed."
  echo "- Rooting is midpoint rooting (no real outgroup exists among these isolates) -- a real defensible default, not a claim of a known ancestral state."
  echo "- Recombined regions (see Script 6's SNP-density flags, if any) can inflate apparent relatedness or divergence at specific sites; a flagged window's SNPs should be treated with more caution than the rest of the alignment, not equal weight."
  echo "- This tree describes genetic relationships under a substitution model. It is not a transmission map, a timeline, or proof of any specific transmission event between any two of these isolates."
} > "${REPORT}"

note "OK: ${REPORT} written -- complete the outbreak-interpretation section by hand."
