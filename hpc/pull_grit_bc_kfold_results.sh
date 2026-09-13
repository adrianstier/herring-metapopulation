#!/bin/bash
set -euo pipefail

REMOTE_HOST="${GRIT_HOST:-astier@hpc.grit.ucsb.edu}"
SSH_KEY="${GRIT_KEY:-$HOME/.ssh/grit}"
STAGE="/home/astier/herring-bc-stage"
RSYNC_RSH="ssh -i ${SSH_KEY} -o BatchMode=yes -o ConnectTimeout=15"

mkdir -p analysis/05_bc_coastwide/output hpc/grit-results/kfold

rsync -av -e "${RSYNC_RSH}" "${REMOTE_HOST}:${STAGE}/results/kfold/bc_kfold_*.rds" \
  hpc/grit-results/kfold/ || true
rsync -av -e "${RSYNC_RSH}" "${REMOTE_HOST}:${STAGE}/results/kfold/bc_kfold_*_summary.csv" \
  hpc/grit-results/kfold/ || true
rsync -av -e "${RSYNC_RSH}" "${REMOTE_HOST}:${STAGE}/results/kfold/bc_kfold_*_pointwise.csv" \
  hpc/grit-results/kfold/ || true
rsync -av -e "${RSYNC_RSH}" "${REMOTE_HOST}:${STAGE}/results/kfold/bc_kfold_*_sessionInfo.txt" \
  hpc/grit-results/kfold/ || true

for path in hpc/grit-results/kfold/bc_kfold_*.rds; do
  [[ -s "${path}" ]] || continue
  cp "${path}" "analysis/05_bc_coastwide/output/$(basename "${path}")"
done

Rscript --vanilla analysis/05_bc_coastwide/scripts/14_collect_bc_kfold.R

echo "Pulled any available GRIT K-fold outputs and refreshed bc_coastwide_kfold_summary."
