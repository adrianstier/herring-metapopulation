#!/bin/bash
set -euo pipefail

MODEL="${1:-all}"
REMOTE_HOST="${GRIT_HOST:-astier@hpc.grit.ucsb.edu}"
SSH_KEY="${GRIT_KEY:-$HOME/.ssh/grit}"
STAGE="/home/astier/herring-bc-stage"
LOCAL_TARBALL="hpc/herring-bc-coastwide.tar.gz"
SSH_OPTS=(-i "${SSH_KEY}" -o BatchMode=yes -o ConnectTimeout=15)
RSYNC_RSH="ssh -i ${SSH_KEY} -o BatchMode=yes -o ConnectTimeout=15"

case "${MODEL}" in
  all|catch|geom|marginal|m1_bc|m1_bc_geom|m1_bc_marginal|m3_bc|m3_bc_geom|m3_bc_marginal|m5_bc|m1|m1geom|m1marginal|m3|m3geom|m3marginal|m5|m1_bc_catch_pressure|m3_bc_catch_pressure|m1catch|m3catch) ;;
  *)
    echo "Usage: $0 [all|catch|geom|marginal|m1_bc|m1_bc_geom|m1_bc_marginal|m3_bc|m3_bc_geom|m3_bc_marginal|m5_bc|m1_bc_catch_pressure|m3_bc_catch_pressure]" >&2
    exit 2
    ;;
esac

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
  Data/processed/bc_catch_pressure_stock_area_year.csv \
  Data/processed/bc_distance_within_stock_area.rds \
  Data/processed/bc_fishery_events.csv \
  Data/processed/bc_stan_data.rds

ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "mkdir -p ${STAGE}/logs ${STAGE}/results"
rsync -av -e "${RSYNC_RSH}" "${LOCAL_TARBALL}" \
  "${REMOTE_HOST}:${STAGE}/herring-bc-coastwide.tar.gz"
rsync -av -e "${RSYNC_RSH}" hpc/grit_bc_coastwide_fit.slurm \
  "${REMOTE_HOST}:${STAGE}/grit_bc_coastwide_fit.slurm"

submit_one() {
  local model="$1"
  ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" \
    "sbatch --job-name=herring-${model} --export=ALL,MODEL=${model},SUBSET=ALL ${STAGE}/grit_bc_coastwide_fit.slurm"
}

if [[ "${MODEL}" == "all" ]]; then
  submit_one m1_bc
  submit_one m3_bc
  submit_one m5_bc
elif [[ "${MODEL}" == "catch" ]]; then
  submit_one m1_bc_catch_pressure
  submit_one m3_bc_catch_pressure
elif [[ "${MODEL}" == "geom" ]]; then
  submit_one m1_bc_geom
  submit_one m3_bc_geom
elif [[ "${MODEL}" == "marginal" ]]; then
  submit_one m1_bc_marginal
  submit_one m3_bc_marginal
else
  submit_one "${MODEL}"
fi

echo "Submitted ${MODEL} to GRIT. Monitor with:"
echo "  perl -e 'alarm 22; exec @ARGV' ssh -i ${SSH_KEY} -o BatchMode=yes -o ConnectTimeout=12 ${REMOTE_HOST} 'squeue -u astier'"
