#!/bin/bash
set -euo pipefail

REMOTE_HOST="${GRIT_HOST:-astier@hpc.grit.ucsb.edu}"
SSH_KEY="${GRIT_KEY:-$HOME/.ssh/grit}"
STAGE="/home/astier/herring-bc-stage"
RSYNC_RSH="ssh -i ${SSH_KEY} -o BatchMode=yes -o ConnectTimeout=15"

mkdir -p analysis/05_bc_coastwide/output hpc/grit-results

for model in m1_bc m1_bc_geom m1_bc_marginal m3_bc m3_bc_geom m3_bc_marginal m1_bc_catch_pressure m3_bc_catch_pressure m5_bc; do
  rsync -av -e "${RSYNC_RSH}" "${REMOTE_HOST}:${STAGE}/results/${model}_fit.rds" \
    hpc/grit-results/ || true
  rsync -av -e "${RSYNC_RSH}" "${REMOTE_HOST}:${STAGE}/results/${model}_sessionInfo.txt" \
    hpc/grit-results/ || true
done

for model in m1_bc m1_bc_geom m1_bc_marginal m3_bc m3_bc_geom m3_bc_marginal m1_bc_catch_pressure m3_bc_catch_pressure m5_bc; do
  if [[ -s "hpc/grit-results/${model}_fit.rds" ]]; then
    cp "hpc/grit-results/${model}_fit.rds" "analysis/05_bc_coastwide/output/${model}_fit.rds"
  fi
done

echo "Pulled any available GRIT coastwide fits into analysis/05_bc_coastwide/output/."
