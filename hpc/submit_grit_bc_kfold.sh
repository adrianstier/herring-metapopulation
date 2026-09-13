#!/bin/bash
set -euo pipefail

K="${1:-5}"
ONLY_MODEL="${2:-}"
ONLY_FOLD="${3:-}"
REMOTE_HOST="${GRIT_HOST:-astier@hpc.grit.ucsb.edu}"
SSH_KEY="${GRIT_KEY:-$HOME/.ssh/grit}"
STAGE="/home/astier/herring-bc-stage"
LOCAL_TARBALL="hpc/herring-bc-coastwide.tar.gz"
SSH_OPTS=(-i "${SSH_KEY}" -o BatchMode=yes -o ConnectTimeout=15)
RSYNC_RSH="ssh -i ${SSH_KEY} -o BatchMode=yes -o ConnectTimeout=15"

if ! [[ "${K}" =~ ^[0-9]+$ ]] || [[ "${K}" -lt 2 ]]; then
  echo "Usage: $0 [K>=2] [m1_bc|m3_bc] [fold]" >&2
  exit 2
fi
if [[ -n "${ONLY_MODEL}" && ! "${ONLY_MODEL}" =~ ^m[13]_bc$ ]]; then
  echo "Optional model must be m1_bc or m3_bc, not ${ONLY_MODEL}" >&2
  exit 2
fi
if [[ -n "${ONLY_FOLD}" ]] &&
   (! [[ "${ONLY_FOLD}" =~ ^[0-9]+$ ]] ||
    [[ "${ONLY_FOLD}" -lt 1 ]] || [[ "${ONLY_FOLD}" -gt "${K}" ]]); then
  echo "Optional fold must be an integer in 1:${K}, not ${ONLY_FOLD}" >&2
  exit 2
fi

mkdir -p hpc

COPYFILE_DISABLE=1 tar --no-xattrs \
  --exclude='._*' \
  --exclude='.DS_Store' \
  --exclude='*.pyc' \
  --exclude='__pycache__' \
  --exclude='node_modules' \
  --exclude='analysis/05_bc_coastwide/output/*' \
  --exclude='analysis/05_bc_coastwide/stan/*.rds' \
  --exclude='analysis/05_bc_coastwide/stan/*.hpp' \
  --exclude='Output/posteriors/*' \
  --exclude='Data/processed/*_fit.rds' \
  --exclude='Data/processed/m*_fit.rds' \
  --exclude='Data/processed/m*_exact_reloo*_fit.rds' \
  --exclude='Data/processed/m*_smoke_fit.rds' \
  -czf "${LOCAL_TARBALL}" \
  R \
  analysis/05_bc_coastwide \
  Data/processed/bc_spawn_by_section_year.csv \
  Data/processed/bc_catch_by_section_year_gear.csv \
  Data/processed/bc_predator_covariates.csv \
  Data/processed/bc_predator_covariates_provenance.md \
  Data/processed/bc_distance_within_stock_area.rds \
  Data/processed/bc_fishery_events.csv \
  Data/processed/bc_stan_data.rds

ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "mkdir -p ${STAGE}/logs ${STAGE}/results/kfold"
rsync -av -e "${RSYNC_RSH}" "${LOCAL_TARBALL}" \
  "${REMOTE_HOST}:${STAGE}/herring-bc-coastwide.tar.gz"
rsync -av -e "${RSYNC_RSH}" hpc/grit_bc_coastwide_kfold.slurm \
  "${REMOTE_HOST}:${STAGE}/grit_bc_coastwide_kfold.slurm"

submit_one() {
  local model="$1"
  local fold="$2"
  ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" \
    "sbatch --job-name=herring-${model}-cv${fold} --export=ALL,MODEL=${model},FOLD=${fold},K=${K} ${STAGE}/grit_bc_coastwide_kfold.slurm"
}

models=(m1_bc m3_bc)
folds=($(seq 1 "${K}"))
if [[ -n "${ONLY_MODEL}" ]]; then
  models=("${ONLY_MODEL}")
fi
if [[ -n "${ONLY_FOLD}" ]]; then
  folds=("${ONLY_FOLD}")
fi

for model in "${models[@]}"; do
  for fold in "${folds[@]}"; do
    submit_one "${model}" "${fold}"
  done
done

echo "Submitted ${K}-fold CV jobs to GRIT. Monitor with:"
echo "  perl -e 'alarm 22; exec @ARGV' ssh -i ${SSH_KEY} -o BatchMode=yes -o ConnectTimeout=12 ${REMOTE_HOST} 'squeue -u astier'"
