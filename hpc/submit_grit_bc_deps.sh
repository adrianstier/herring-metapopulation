#!/bin/bash
set -euo pipefail

REMOTE_HOST="${GRIT_HOST:-astier@hpc.grit.ucsb.edu}"
SSH_KEY="${GRIT_KEY:-$HOME/.ssh/grit}"
STAGE="/home/astier/herring-bc-stage"
SSH_OPTS=(-i "${SSH_KEY}" -o BatchMode=yes -o ConnectTimeout=15)
RSYNC_RSH="ssh -i ${SSH_KEY} -o BatchMode=yes -o ConnectTimeout=15"

ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "mkdir -p ${STAGE}/logs"
rsync -av -e "${RSYNC_RSH}" hpc/grit_bc_coastwide_deps.slurm \
  "${REMOTE_HOST}:${STAGE}/grit_bc_coastwide_deps.slurm"
ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" \
  "sbatch --job-name=herring-bc-deps ${STAGE}/grit_bc_coastwide_deps.slurm"

echo "Submitted GRIT coastwide dependency preflight. Monitor with:"
echo "  perl -e 'alarm 22; exec @ARGV' ssh -i ${SSH_KEY} -o BatchMode=yes -o ConnectTimeout=12 ${REMOTE_HOST} 'squeue -u astier'"
