#!/usr/bin/env bash
###############################################################################
# 9_QC_Report_Generator.sh
#
# Assembles Scripts 6-8's real evidence into one portfolio artifact. Run
# locally with `bash`, not `sbatch`.
###############################################################################
set -euo pipefail
SCRIPT_DIR="${PIPELINE_SCRIPT_DIR:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}}"
source "${SCRIPT_DIR}/lib/common.sh"

REPORT="${OUTPUT_DIR}/PHYLOGENOMICS_REPORT.md"
{
  echo "# Phylogenomics and Outbreak Context Report — S. aureus, PRJNA983748"
  echo
  echo "Generated $(date -u +'%Y-%m-%dT%H:%M:%SZ')."
  echo
  echo "## Core-SNP alignment"
  echo
  echo '```'
  cat "${OUTPUT_DIR}/alignment/alignment_build_summary.tsv" 2>/dev/null || echo "MISSING -- run Script 6 first."
  echo '```'
  echo
  echo "## Model and tree support"
  echo
  echo '```'
  grep -A1 "Best-fit model" "${OUTPUT_DIR}/tree/saureus_core_snp.iqtree" 2>/dev/null || echo "MISSING -- run Script 7 first."
  echo '```'
  echo '```'
  cat "${OUTPUT_DIR}/tree/tree_support_summary.tsv" 2>/dev/null || echo "MISSING -- run Script 8 first."
  echo '```'
  echo
  echo "## Metadata overlay and outbreak interpretation"
  echo
  if [ -s "${OUTPUT_DIR}/tree/metadata_and_outbreak_context.md" ]; then
    cat "${OUTPUT_DIR}/tree/metadata_and_outbreak_context.md"
  else
    echo "MISSING -- run Script 8 first."
  fi
  echo
  echo "## Portfolio artifact checklist"
  echo
  echo "- [ ] Alignment: \`alignment/core_snp_alignment.fasta\` + \`alignment/core_snp_sites.tsv\`"
  echo "- [ ] Tree file: \`tree/saureus_core_snp.contree\` (support values) and \`tree/saureus_core_snp.midpoint_rooted.nwk\` (rooted)"
  echo "- [ ] Visualization: open the rooted Newick file in a tree viewer (e.g. FigTree, iTOL) and export a labeled figure showing branch support and the metadata overlay above"
  echo "- [ ] Model and support information: this report's own sections above"
  echo "- [ ] Metadata statement: the isolate table above, sourced independently from each isolate's real NCBI BioSample record"
  echo "- [ ] Outbreak interpretation with explicit uncertainty: completed by hand in \`tree/metadata_and_outbreak_context.md\`"
} > "${REPORT}"

note "OK: ${REPORT} written. Complete the checklist above -- the tree visualization step is manual by design."
