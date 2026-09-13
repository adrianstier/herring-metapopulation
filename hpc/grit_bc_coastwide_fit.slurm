#!/bin/bash
#SBATCH --job-name=herring-bc
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=3-00:00:00
#SBATCH --exclude=hpc-13.grit.ucsb.edu
#SBATCH --output=/home/astier/herring-bc-stage/logs/%x-%j.out
#SBATCH --error=/home/astier/herring-bc-stage/logs/%x-%j.err

set -euo pipefail

MODEL="${MODEL:-m1_bc}"
SUBSET="${SUBSET:-ALL}"
STAN_CHAINS="${STAN_CHAINS:-4}"
STAN_ITER="${STAN_ITER:-4500}"
STAN_WARMUP="${STAN_WARMUP:-2000}"
STAN_CORES="${STAN_CORES:-${SLURM_CPUS_PER_TASK:-4}}"

STAGE="/home/astier/herring-bc-stage"
TARBALL="${STAGE}/herring-bc-coastwide.tar.gz"
RESULTS="${STAGE}/results"
RSCRIPT="${RSCRIPT:-Rscript}"
REMOTE_RUN_BASE="${REMOTE_RUN_BASE:-/home/hpc-scratch/${USER:-astier}}"
if ! mkdir -p "${REMOTE_RUN_BASE}" 2>/dev/null || [[ ! -w "${REMOTE_RUN_BASE}" ]]; then
  printf "WARN: scratch base %s is unavailable; falling back to %s\n" \
    "${REMOTE_RUN_BASE}" "${HOME}/herring-bc-r-cache"
  CACHE_BASE="${HERRING_CACHE_BASE:-${HOME}/herring-bc-r-cache}"
  RUN_BASE="${HERRING_RUN_BASE:-${HOME}}"
else
  CACHE_BASE="${HERRING_CACHE_BASE:-${REMOTE_RUN_BASE}/herring-bc-r-cache}"
  RUN_BASE="${HERRING_RUN_BASE:-${REMOTE_RUN_BASE}}"
fi
R_MAJOR_MINOR="$("${RSCRIPT}" --no-init-file --vanilla -e 'cat(paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1], sep = "."))')"
DEFAULT_RLIBS="${CACHE_BASE}/R/x86_64-pc-linux-gnu-library/${R_MAJOR_MINOR}"
RLIBS="${HERRING_R_LIBS_USER:-${DEFAULT_RLIBS}}"
RUN="${RUN_BASE}/herring-bc-run-${MODEL}-${SLURM_JOB_ID}"
TMPDIR="${HERRING_TMPDIR:-${CACHE_BASE}/tmp}"

mkdir -p "${STAGE}/logs" "${RESULTS}" "${RUN}" "${RLIBS}" "${TMPDIR}"

case "${MODEL}" in
  m1|m1_bc)
    FIT_SCRIPT="analysis/05_bc_coastwide/scripts/06_fit_m1_bc.R"
    OUT_FILE="analysis/05_bc_coastwide/output/m1_bc_fit.rds"
    MODEL_TAG="m1_bc"
    ;;
  m1_bc_geom|m1geom)
    FIT_SCRIPT="analysis/05_bc_coastwide/scripts/06c_fit_m1_bc_geom.R"
    OUT_FILE="analysis/05_bc_coastwide/output/m1_bc_geom_fit.rds"
    MODEL_TAG="m1_bc_geom"
    ;;
  m1_bc_marginal|m1marginal)
    FIT_SCRIPT="analysis/05_bc_coastwide/scripts/06d_fit_m1_bc_marginal.R"
    OUT_FILE="analysis/05_bc_coastwide/output/m1_bc_marginal_fit.rds"
    MODEL_TAG="m1_bc_marginal"
    ;;
  m3|m3_bc)
    FIT_SCRIPT="analysis/05_bc_coastwide/scripts/07_fit_m3_bc.R"
    OUT_FILE="analysis/05_bc_coastwide/output/m3_bc_fit.rds"
    MODEL_TAG="m3_bc"
    ;;
  m3_bc_geom|m3geom)
    FIT_SCRIPT="analysis/05_bc_coastwide/scripts/07c_fit_m3_bc_geom.R"
    OUT_FILE="analysis/05_bc_coastwide/output/m3_bc_geom_fit.rds"
    MODEL_TAG="m3_bc_geom"
    ;;
  m3_bc_marginal|m3marginal)
    FIT_SCRIPT="analysis/05_bc_coastwide/scripts/07d_fit_m3_bc_marginal.R"
    OUT_FILE="analysis/05_bc_coastwide/output/m3_bc_marginal_fit.rds"
    MODEL_TAG="m3_bc_marginal"
    ;;
  m1catch|m1_bc_catch_pressure)
    FIT_SCRIPT="analysis/05_bc_coastwide/scripts/06b_fit_m1_bc_catch_pressure.R"
    OUT_FILE="analysis/05_bc_coastwide/output/m1_bc_catch_pressure_fit.rds"
    MODEL_TAG="m1_bc_catch_pressure"
    ;;
  m3catch|m3_bc_catch_pressure)
    FIT_SCRIPT="analysis/05_bc_coastwide/scripts/07b_fit_m3_bc_catch_pressure.R"
    OUT_FILE="analysis/05_bc_coastwide/output/m3_bc_catch_pressure_fit.rds"
    MODEL_TAG="m3_bc_catch_pressure"
    ;;
  m5|m5_bc)
    FIT_SCRIPT="analysis/05_bc_coastwide/scripts/08_fit_m5_bc.R"
    OUT_FILE="analysis/05_bc_coastwide/output/m5_bc_fit.rds"
    MODEL_TAG="m5_bc"
    ;;
  *)
    echo "Unknown MODEL=${MODEL}; use m1_bc, m1_bc_geom, m1_bc_marginal, m3_bc, m3_bc_geom, m3_bc_marginal, m5_bc, m1_bc_catch_pressure, or m3_bc_catch_pressure." >&2
    exit 2
    ;;
esac

if [[ ! -s "${TARBALL}" ]]; then
  echo "Missing staged tarball: ${TARBALL}" >&2
  exit 3
fi

cd "${RUN}"
tar xzf "${TARBALL}"
rm -f .Rprofile
touch .here

if [[ -n "${R_LIBS_USER:-}" && "${R_LIBS_USER}" != "${RLIBS}" ]]; then
  printf "WARN: ignoring inherited R_LIBS_USER=%s; using %s\n" \
    "${R_LIBS_USER}" "${RLIBS}"
fi
export R_LIBS_SITE=""
export R_LIBS_USER="${RLIBS}"
export TMPDIR
export SUBSET STAN_CHAINS STAN_ITER STAN_WARMUP STAN_CORES
export HERRING_SMOKE="${HERRING_SMOKE:-0}"

printf "GRIT coastwide fit\n"
printf "  model: %s\n" "${MODEL_TAG}"
printf "  subset: %s\n" "${SUBSET}"
printf "  chains/iter/warmup/cores: %s/%s/%s/%s\n" \
  "${STAN_CHAINS}" "${STAN_ITER}" "${STAN_WARMUP}" "${STAN_CORES}"
printf "  run dir: %s\n" "${RUN}"
printf "  R user library: %s\n" "${R_LIBS_USER}"
printf "  R temp dir: %s\n" "${TMPDIR}"

(
  flock -w 1800 9
  "${RSCRIPT}" --no-init-file --vanilla -e '
    user_lib <- Sys.getenv("R_LIBS_USER")
    if (!nzchar(user_lib)) {
      stop("R_LIBS_USER is empty; refusing to use site libraries.")
    }
    dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
    .libPaths(c(user_lib, .Library), include.site = FALSE)
    pkgs <- c("rstan", "tidyverse", "here", "janitor")
    has_pkg <- function(pkg) {
      isTRUE(tryCatch(requireNamespace(pkg, quietly = TRUE),
                      error = function(e) FALSE))
    }
    missing <- pkgs[!vapply(pkgs, has_pkg, logical(1))]
    if (length(missing)) {
      stop("Missing full-fit R packages on GRIT: ",
           paste(missing, collapse = ", "),
           ". Install/update the GRIT R library outside the model job.")
    }
    user_lib_norm <- normalizePath(user_lib, mustWork = FALSE)
    paths <- vapply(pkgs, find.package, character(1))
    paths_norm <- normalizePath(paths, mustWork = FALSE)
    external <- paths[!startsWith(paths_norm, user_lib_norm)]
    if (length(external)) {
      stop("Full-fit R packages did not resolve from R_LIBS_USER: ",
           paste(names(external), external, sep = "=", collapse = "; "),
           ". Repair the version-matched GRIT library before sampling.")
    }
    cat("Full-fit R package gate passed:\n")
    print(paths)
  '
) 9>"${RLIBS}/.install.lock"

"${RSCRIPT}" --no-init-file --vanilla "${FIT_SCRIPT}"

if [[ ! -s "${OUT_FILE}" ]]; then
  echo "Expected fit output was not created: ${OUT_FILE}" >&2
  exit 4
fi

cp "${OUT_FILE}" "${RESULTS}/${MODEL_TAG}_fit.rds"
"${RSCRIPT}" --no-init-file --vanilla -e 'writeLines(capture.output(sessionInfo()), commandArgs(TRUE)[[1]])' \
  "${RESULTS}/${MODEL_TAG}_sessionInfo.txt"

printf "Copied fit to %s/%s_fit.rds\n" "${RESULTS}" "${MODEL_TAG}"
