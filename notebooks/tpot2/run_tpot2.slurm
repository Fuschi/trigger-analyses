#!/bin/bash
#SBATCH --job-name=tpot2_heatwave
#SBATCH --partition=m8
#SBATCH --nodelist=mtx30
#SBATCH --reservation=prj-trigger
#SBATCH --exclusive
#SBATCH --cpus-per-task=64
#SBATCH --mem=0
#SBATCH --time=06:00:00
#SBATCH --output=outputs/logs/tpot2_%j.out
#SBATCH --error=outputs/logs/tpot2_%j.err

set -euo pipefail

mkdir -p outputs/logs
mkdir -p outputs/checkpoints/tpot2_heatwave
mkdir -p outputs/results

export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

echo "Running on node: $(hostname)"
echo "SLURM_JOB_NODELIST: ${SLURM_JOB_NODELIST}"
echo "SLURM_CPUS_PER_TASK: ${SLURM_CPUS_PER_TASK}"

apptainer exec container/tpot_0.1.9a0.sif \
  /opt/conda/envs/tpot2env/bin/python \
  tpot2_heatwave.py
