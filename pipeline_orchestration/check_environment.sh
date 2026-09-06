#!/usr/bin/env bash
###############################################################################
# check_environment.sh
###############################################################################
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FAIL=0

echo "=== Checking config/project.env exists ==="
if [ -s "${PROJECT_ROOT}/config/project.env" ]; then
  echo "OK: config/project.env"
else
  echo "MISSING: config/project.env -- copy config/project.env.example and review it first."
  FAIL=1
fi
echo ""

echo "=== Checking required CLI tools are on PATH ==="
for tool in curl md5sum awk fastqc bwa samtools bcftools bedtools python3 iqtree2; do
  if command -v "${tool}" >/dev/null 2>&1; then
    echo "OK: ${tool}"
  else
    echo "MISSING: ${tool}"
    FAIL=1
  fi
done
echo ""

echo "=== Checking biopython is importable (needed by Script 8) ==="
if python3 -c "import Bio" >/dev/null 2>&1; then
  echo "OK: biopython"
else
  echo "MISSING: biopython -- 'pip install biopython' (Script 8's own error message repeats this)."
  FAIL=1
fi
echo ""

echo "=== Checking the reference genome exists ==="
if [ -s "${PROJECT_ROOT}/config/project.env" ]; then
  export PROJECT_ROOT
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/config/project.env"
  ref="${REFERENCE_ROOT}/GCF_000013425.1_NCTC8325.fasta"
  if [ -s "${ref}" ]; then
    echo "OK: ${ref}"
  else
    echo "MISSING: ${ref} (see references/README.md)"
    FAIL=1
  fi
else
  echo "SKIPPED: config/project.env is missing (see above)."
fi
echo ""

if [ "${FAIL}" -eq 0 ]; then
  echo "=== ALL CHECKS PASSED -- safe to run: bash run_pipeline_from_yaml.sh pipeline_config.yaml ==="
  exit 0
else
  echo "=== ONE OR MORE CHECKS FAILED -- fix the items above before running the real chain. ===" >&2
  exit 1
fi
