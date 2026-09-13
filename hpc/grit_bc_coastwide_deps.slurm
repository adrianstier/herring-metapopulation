#!/bin/bash
#SBATCH --job-name=herring-bc-deps
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=4:00:00
#SBATCH --exclude=hpc-13.grit.ucsb.edu
#SBATCH --output=/home/astier/herring-bc-stage/logs/%x-%j.out
#SBATCH --error=/home/astier/herring-bc-stage/logs/%x-%j.err

set -euo pipefail

STAGE="/home/astier/herring-bc-stage"
RSCRIPT="${RSCRIPT:-Rscript}"
REMOTE_RUN_BASE="${REMOTE_RUN_BASE:-/home/hpc-scratch/${USER:-astier}}"
if ! mkdir -p "${REMOTE_RUN_BASE}" 2>/dev/null || [[ ! -w "${REMOTE_RUN_BASE}" ]]; then
  printf "WARN: scratch base %s is unavailable; falling back to %s\n" \
    "${REMOTE_RUN_BASE}" "${HOME}/herring-bc-r-cache"
  CACHE_BASE="${HERRING_CACHE_BASE:-${HOME}/herring-bc-r-cache}"
else
  CACHE_BASE="${HERRING_CACHE_BASE:-${REMOTE_RUN_BASE}/herring-bc-r-cache}"
fi
R_MAJOR_MINOR="$("${RSCRIPT}" --no-init-file --vanilla -e 'cat(paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1], sep = "."))')"
DEFAULT_RLIBS="${CACHE_BASE}/R/x86_64-pc-linux-gnu-library/${R_MAJOR_MINOR}"
RLIBS="${HERRING_R_LIBS_USER:-${DEFAULT_RLIBS}}"
TMPDIR="${HERRING_TMPDIR:-${CACHE_BASE}/tmp}"

mkdir -p "${STAGE}/logs" "${RLIBS}" "${TMPDIR}"

if [[ -n "${R_LIBS_USER:-}" && "${R_LIBS_USER}" != "${RLIBS}" ]]; then
  printf "WARN: ignoring inherited R_LIBS_USER=%s; using %s\n" \
    "${R_LIBS_USER}" "${RLIBS}"
fi
export R_LIBS_SITE=""
export R_LIBS_USER="${RLIBS}"
export TMPDIR

printf "GRIT coastwide R dependency preflight\n"
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

    repos <- c(CRAN = "https://cloud.r-project.org")
    primary <- c("rstan", "tidyverse", "here", "janitor")
    has_pkg <- function(pkg) {
      isTRUE(tryCatch(requireNamespace(pkg, quietly = TRUE),
                      error = function(e) FALSE))
    }

    missing <- primary[!vapply(primary, has_pkg, logical(1))]
    if (length(missing)) {
      install.packages(missing, lib = user_lib, repos = repos,
                       dependencies = c("Depends", "Imports", "LinkingTo"),
                       Ncpus = max(1L, min(4L, parallel::detectCores() - 1L)))
    }

    missing_after <- primary[!vapply(primary, has_pkg, logical(1))]
    if (length(missing_after)) {
      stop("Still missing GRIT R packages after install: ",
           paste(missing_after, collapse = ", "))
    }

    user_lib_norm <- normalizePath(user_lib, mustWork = FALSE)
    paths <- vapply(primary, find.package, character(1))
    paths_norm <- normalizePath(paths, mustWork = FALSE)
    external <- paths[!startsWith(paths_norm, user_lib_norm)]
    if (length(external)) {
      stop("GRIT R packages did not resolve from R_LIBS_USER: ",
           paste(names(external), external, sep = "=", collapse = "; "))
    }

    cat("GRIT coastwide dependency preflight passed:\n")
    print(paths)
    writeLines(capture.output(sessionInfo()))
  '
) 9>"${RLIBS}/.install.lock"
