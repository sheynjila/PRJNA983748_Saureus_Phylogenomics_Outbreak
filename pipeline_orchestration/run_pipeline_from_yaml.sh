#!/usr/bin/env bash
###############################################################################
# run_pipeline_from_yaml.sh
#
# NARRATIVE:
# Reads pipeline_config.yaml and submits every step it lists as a real
# Slurm job, chained via --dependency=afterok:<previous_jobid> -- Slurm's
# own native mechanism for "run job B only if job A succeeded". No external
# workflow-manager software is installed or required, and every bash step
# still runs with its own script's real #SBATCH resource directives
# untouched.
#
# NO PATH DUPLICATION OR ISOLATION TRICK IS NEEDED HERE, UNLIKE OTHER
# ORCHESTRATED REPOS IN THIS CURRICULUM:
# This pipeline already reads all of its working directories from
# config/project.env (sourced once by lib/common.sh), not from paths
# hardcoded inside each numbered script. Every raw-read download already
# skips re-fetching a file that exists and still verifies its checksum
# (see download_one() in lib/common.sh), and Script 1 already refuses to
# silently regenerate an already-reviewed data/run_manifest.tsv. Because
# of that, this driver simply re-runs the exact same scripts a student
# would run by hand, against the student's own config/project.env --
# there is no separate "orchestrated" copy of anything to keep in sync.
#
# MIXED BASH + R CHAIN:
# Unlike a pipeline_config.yaml with only bash steps, this one also
# chains a final R analysis step (run_analysis.R, which itself bundles
# analysis_metagenomics_phyloseq/01-09 into one R session). run_analysis.R
# has no #SBATCH header of its own, so it needs mode: sbatch_wrap like any
# other unwrapped script -- but it needs `Rscript`, not `bash`, to run it,
# and its own resource footprint (phyloseq loading, ALDEx2 Monte Carlo,
# dashboard rendering), and it lives in a different folder
# (analysis_metagenomics_phyloseq/, not pipeline_raw_reads_to_counts/).
# Three optional per-step YAML fields make this possible without any new
# top-level schema: `dir` (overrides scripts_dir for just this step),
# `wrap_cmd` (interpreter for mode: sbatch_wrap; defaults to bash), and
# `wrap_cpus` / `wrap_mem` / `wrap_time` (resource request for mode:
# sbatch_wrap; default to a minimal 1 CPU / 2G / 10 minutes, matching a
# lightweight wrapped script -- override them for a heavier step like the
# R analysis).
#
# mode: sbatch_wrap does NOT add a --partition by default, since a wrapped
# script's own resources are declared entirely on the sbatch command line
# (there's no #SBATCH header to inherit one from). Add `wrap_partition:
# <name>` per step if your cluster requires an explicit partition --
# confirmed true for teach-sub1 (real error: "You must specify a
# partition (queue) to run in."), which is why this repo's own
# pipeline_config.yaml sets `wrap_partition: batch` on its sbatch_wrap
# step.
#
# Usage:
#   bash run_pipeline_from_yaml.sh [path/to/pipeline_config.yaml] \
#        [--start-from N]
#
#   --start-from N   Skip steps before N and submit only step N onward,
#                     with step N running immediately (no dependency) and
#                     every step after it still chained normally. Use this
#                     to resume after fixing a script that failed partway
#                     through a previous run, without re-submitting steps
#                     that already succeeded -- and to skip Step 1 entirely
#                     when data/run_manifest.tsv has already been reviewed
#                     by hand (Step 1 will otherwise refuse to run; see the
#                     NARRATIVE above).
#
# WHAT HAPPENS IF A STEP FAILS:
# Slurm's --dependency=afterok means if step N exits non-zero, every step
# after it is automatically left in a "DependencyNeverSatisfied" state and
# never runs -- it does NOT retry, skip, or silently continue. Check
# `sacct` (see this script's own final echo) to see exactly which step
# failed and why before resubmitting.
###############################################################################
set -euo pipefail

YAML_FILE="pipeline_config.yaml"
START_FROM=1

EXPECT_VALUE_FOR=""
for arg in "$@"; do
    if [ -n "${EXPECT_VALUE_FOR}" ]; then
        case "${EXPECT_VALUE_FOR}" in
            start-from) START_FROM="${arg}" ;;
        esac
        EXPECT_VALUE_FOR=""
        continue
    fi
    case "${arg}" in
        --start-from) EXPECT_VALUE_FOR="start-from" ;;
        *.yaml|*.yml) YAML_FILE="${arg}" ;;
    esac
done

if [ ! -f "${YAML_FILE}" ]; then
    echo "ERROR: pipeline config not found: ${YAML_FILE}" >&2
    exit 1
fi

DEFAULT_SCRIPTS_DIR_REL=$(grep -E '^scripts_dir:' "${YAML_FILE}" | sed -E 's/^scripts_dir:\s*//')
YAML_DIR="$(cd "$(dirname "${YAML_FILE}")" && pwd)"
DEFAULT_SCRIPTS_DIR="$(cd "${YAML_DIR}/${DEFAULT_SCRIPTS_DIR_REL}" && pwd)"

echo "Pipeline config      : ${YAML_FILE}"
echo "Default scripts dir  : ${DEFAULT_SCRIPTS_DIR}"
echo "Starting from step   : ${START_FROM}"
echo ""

# Extracts one field's value from a single "- {...}" YAML flow-mapping
# line, or prints nothing if the field is absent from that line.
field() {
    local line=$1 name=$2
    echo "${line}" | grep -oE "${name}:[^,}]+" | sed -E "s/^${name}:\s*//" | xargs 2>/dev/null || true
}

PREV_JOBID=""
SUBMITTED_ANY=0

while IFS= read -r line; do
    ID=$(field "${line}" "id")
    SCRIPT=$(field "${line}" "script")
    MODE=$(field "${line}" "mode")
    STEP_DIR_REL=$(field "${line}" "dir")
    WRAP_CMD=$(field "${line}" "wrap_cmd"); WRAP_CMD=${WRAP_CMD:-bash}
    WRAP_CPUS=$(field "${line}" "wrap_cpus"); WRAP_CPUS=${WRAP_CPUS:-1}
    WRAP_MEM=$(field "${line}" "wrap_mem"); WRAP_MEM=${WRAP_MEM:-2G}
    WRAP_TIME=$(field "${line}" "wrap_time"); WRAP_TIME=${WRAP_TIME:-00:10:00}
    WRAP_PARTITION=$(field "${line}" "wrap_partition")

    if [ "${ID}" -lt "${START_FROM}" ]; then
        echo "Skipping step ${ID} (${SCRIPT}) -- before --start-from ${START_FROM}."
        continue
    fi

    if [ -n "${STEP_DIR_REL}" ]; then
        SCRIPTS_DIR="$(cd "${YAML_DIR}/${STEP_DIR_REL}" && pwd)"
    else
        SCRIPTS_DIR="${DEFAULT_SCRIPTS_DIR}"
    fi
    SCRIPT_PATH="${SCRIPTS_DIR}/${SCRIPT}"
    if [ ! -f "${SCRIPT_PATH}" ]; then
        echo "ERROR: step ${ID}'s script not found: ${SCRIPT_PATH}" >&2
        exit 1
    fi

    DEP_ARGS=()
    if [ -n "${PREV_JOBID}" ]; then
        DEP_ARGS=(--dependency=afterok:"${PREV_JOBID}")
    fi

    case "${MODE}" in
        sbatch)
            # PIPELINE_SCRIPT_DIR tells the job its own real directory --
            # Slurm copies a submitted batch script into its own spool
            # directory before running it, so ${BASH_SOURCE[0]} inside the
            # job never points at SCRIPTS_DIR on its own (real, confirmed
            # failure: "source lib/common.sh: No such file or directory").
            JOBID=$(sbatch --parsable --export=ALL,PIPELINE_SCRIPT_DIR="${SCRIPTS_DIR}" \
                "${DEP_ARGS[@]}" "${SCRIPT_PATH}")
            ;;
        sbatch_wrap)
            WRAP_ARGS=(--job-name="step${ID}_wrapped" --ntasks=1
                       --cpus-per-task="${WRAP_CPUS}" --mem="${WRAP_MEM}" --time="${WRAP_TIME}")
            [ -n "${WRAP_PARTITION}" ] && WRAP_ARGS+=(--partition="${WRAP_PARTITION}")
            JOBID=$(sbatch --parsable "${DEP_ARGS[@]}" "${WRAP_ARGS[@]}" \
                --wrap="cd '${SCRIPTS_DIR}' && ${WRAP_CMD} '${SCRIPT_PATH}'")
            ;;
        *)
            echo "ERROR: unknown mode '${MODE}' for step ${ID}" >&2
            exit 1
            ;;
    esac

    if [ -n "${PREV_JOBID}" ]; then
        echo "Step ${ID} (${SCRIPT}): submitted as job ${JOBID}, depends on job ${PREV_JOBID}"
    else
        echo "Step ${ID} (${SCRIPT}): submitted as job ${JOBID}, no dependency (runs immediately)"
    fi

    PREV_JOBID="${JOBID}"
    SUBMITTED_ANY=1
done < <(grep -E '^\s*-\s*\{' "${YAML_FILE}")

if [ "${SUBMITTED_ANY}" -eq 0 ]; then
    echo "ERROR: no steps submitted -- check --start-from against real step IDs in ${YAML_FILE}." >&2
    exit 1
fi

echo ""
echo "OK: full chain submitted. Monitor with:"
echo "  squeue -u \$(whoami)"
echo "Check final pass/fail per step with:"
echo "  sacct -u \$(whoami) --format=JobID,JobName%20,State,ExitCode,Start,End"
