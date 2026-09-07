#!/usr/bin/env bash
#SBATCH --job-name=phy01_fetch
#SBATCH --partition=batch
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=01:00:00
###############################################################################
# 1_Fetch_And_Verify_Raw_Reads.sh
#
# NARRATIVE:
# Fetches one pilot isolate's real Illumina reads (PRJNA983748, Chakrawarti
# et al. 2024). Three of this pipeline's five real isolates are the same
# ones used in the sibling PRJNA983748_Saureus_Genome_Assembly and
# variant-calling-capstone-suite repos; two more are added here specifically
# because a meaningful phylogenomic tree needs more than 3 taxa (see
# lib/common.sh). This repo is self-contained and fetches its own copies
# rather than depending on either sibling repo's output.
###############################################################################
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd curl

PILOT_ISOLATE="${ISOLATE_IDS[0]}"
note "Fetching pilot isolate ${PILOT_ISOLATE} (${ISOLATE_LABEL[${PILOT_ISOLATE}]}, ${ISOLATE_SOURCE[${PILOT_ISOLATE}]}, ${ISOLATE_STRAIN[${PILOT_ISOLATE}]}, ${ISOLATE_YEAR[${PILOT_ISOLATE}]})..."
fetch_ena_run "${ILLUMINA_RUN[${PILOT_ISOLATE}]}" "${PILOT_ISOLATE}"

md5sum "${RAW_DIR}/${PILOT_ISOLATE}"_*.fastq.gz > "${WORKDIR}/checksums/${PILOT_ISOLATE}_raw.md5"
note "OK: ${PILOT_ISOLATE}'s Illumina reads fetched and MD5-verified."
