#!/usr/bin/env bash
#SBATCH --job-name=phy07_iqtree
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
###############################################################################
# 7_Infer_Tree_IQTREE.sh
#
# NARRATIVE -- WHY +ASC:
# core_snp_alignment.fasta contains ONLY variable (SNP) sites -- every
# invariant site was excluded by construction in Script 6. A standard
# substitution model assumes the alignment contains a real mix of variable
# and invariant sites and calibrates branch lengths accordingly; feeding it
# a SNP-only alignment without correction systematically UNDERESTIMATES
# branch lengths (it never sees the invariant sites that would normally
# anchor the substitution rate). Lewis's ascertainment-bias correction
# (+ASC) corrects for exactly this by conditioning the likelihood on the
# alignment containing only variable sites. ModelFinder (-m MFP+ASC)
# selects the best-fitting substitution model, restricted to ASC-corrected
# variants, rather than assuming one blindly.
###############################################################################
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd iqtree2

alignment="${OUTPUT_DIR}/alignment/core_snp_alignment.fasta"
require_file "${alignment}"
mkdir -p "${OUTPUT_DIR}/tree"

note "Running IQ-TREE2: ModelFinder (+ASC) + ${UFBOOT_REPLICATES} ultrafast bootstrap replicates..."
iqtree2 -s "${alignment}" \
  -m MFP+ASC \
  -B "${UFBOOT_REPLICATES}" \
  -T "${THREADS}" \
  --seqtype DNA \
  --prefix "${OUTPUT_DIR}/tree/saureus_core_snp"

note "  Selected model:"
grep -A2 "Best-fit model" "${OUTPUT_DIR}/tree/saureus_core_snp.iqtree" || true

note "OK: tree files are in ${OUTPUT_DIR}/tree/ (saureus_core_snp.treefile, .contree, .iqtree log)."
note "    Continue to Script 8 to interpret branch support, rooting, and the real outbreak context."
