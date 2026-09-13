#!/bin/bash
#SBATCH --job-name=herring-bc-kfold
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=3-00:00:00
#SBATCH --exclude=hpc-13.grit.ucsb.edu
#SBATCH --output=/home/astier/herring-bc-stage/logs/%x-%j.out
#SBATCH --error=/home/astier/herring-bc-stage/logs/%x-%j.err

set -euo pipefail

MODEL="${MODEL:-m3_bc}"
FOLD="${FOLD:-1}"
K="${K:-5}"
STAN_CHAINS="${STAN_CHAINS:-4}"
STAN_ITER="${STAN_ITER:-4500}"
STAN_WARMUP="${STAN_WARMUP:-2000}"
STAN_CORES="${STAN_CORES:-${SLURM_CPUS_PER_TASK:-4}}"

STAGE="/home/astier/herring-bc-stage"
TARBALL="${STAGE}/herring-bc-coastwide.tar.gz"
RESULTS="${STAGE}/results/kfold"
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
RUN="${RUN_BASE}/herring-bc-kfold-${MODEL}-fold${FOLD}-${SLURM_JOB_ID}"
TMPDIR="${HERRING_TMPDIR:-${CACHE_BASE}/tmp}"

mkdir -p "${STAGE}/logs" "${RESULTS}" "${RUN}" "${RLIBS}" "${TMPDIR}"

case "${MODEL}" in
  m1|m1_bc) MODEL_TAG="m1_bc" ;;
  m3|m3_bc) MODEL_TAG="m3_bc" ;;
  *)
    echo "Unknown MODEL=${MODEL}; use m1_bc or m3_bc for K-fold CV." >&2
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
export STAN_CHAINS STAN_ITER STAN_WARMUP STAN_CORES
export BC_CV_MODEL="${MODEL_TAG}"
export BC_CV_FOLD="${FOLD}"
export BC_CV_K="${K}"
export HERRING_SMOKE="${HERRING_SMOKE:-0}"

printf "GRIT coastwide K-fold fit\n"
printf "  model: %s\n" "${MODEL_TAG}"
printf "  fold: %s of %s\n" "${FOLD}" "${K}"
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
    pkgs <- c("rstan", "tidyverse", "here")
    has_pkg <- function(pkg) {
      isTRUE(tryCatch(requireNamespace(pkg, quietly = TRUE),
                      error = function(e) FALSE))
    }
    missing <- pkgs[!vapply(pkgs, has_pkg, logical(1))]
    if (length(missing)) {
      stop("Missing K-fold R packages on GRIT: ",
           paste(missing, collapse = ", "),
           ". Install/update the GRIT R library outside the model job.")
    }
    user_lib_norm <- normalizePath(user_lib, mustWork = FALSE)
    paths <- vapply(pkgs, find.package, character(1))
    paths_norm <- normalizePath(paths, mustWork = FALSE)
    external <- paths[!startsWith(paths_norm, user_lib_norm)]
    if (length(external)) {
      stop("K-fold R packages did not resolve from R_LIBS_USER: ",
           paste(names(external), external, sep = "=", collapse = "; "),
           ". Repair the version-matched GRIT library before sampling.")
    }
    cat("K-fold R package gate passed:\n")
    print(paths)
  '
) 9>"${RLIBS}/.install.lock"

"${RSCRIPT}" --no-init-file --vanilla analysis/05_bc_coastwide/scripts/13_fit_bc_kfold.R

TAG="bc_kfold_${MODEL_TAG}_fold${FOLD}_of${K}"
if [[ ! -s "analysis/05_bc_coastwide/output/${TAG}.rds" ]]; then
  echo "Expected K-fold output was not created: analysis/05_bc_coastwide/output/${TAG}.rds" >&2
  exit 4
fi

cp "analysis/05_bc_coastwide/output/${TAG}.rds" "${RESULTS}/${TAG}.rds"
cp "Output/diagnostics/${TAG}_summary.csv" "${RESULTS}/${TAG}_summary.csv"
cp "Output/diagnostics/${TAG}_pointwise.csv" "${RESULTS}/${TAG}_pointwise.csv"
"${RSCRIPT}" --no-init-file --vanilla -e 'writeLines(capture.output(sessionInfo()), commandArgs(TRUE)[[1]])' \
  "${RESULTS}/${TAG}_sessionInfo.txt"

printf "Copied K-fold outputs to %s/%s.*\n" "${RESULTS}" "${TAG}"
