#!/bin/bash
#SBATCH --job-name=tpot2_heatwave
#SBATCH --partition=m8
#SBATCH --nodelist=mtx30
#SBATCH --reservation=prj-trigger
#SBATCH --exclusive
#SBATCH --cpus-per-task=64
#SBATCH --mem=950G
#SBATCH --time=23:59:00
#SBATCH --output=/scratch/applicata/alessandro.fuschi2/trigger-analyses/notebooks/tpot2/outputs/logs/tpot2_%j.out
#SBATCH --error=/scratch/applicata/alessandro.fuschi2/trigger-analyses/notebooks/tpot2/outputs/logs/tpot2_%j.err

set -euo pipefail

WORKDIR="/scratch/applicata/alessandro.fuschi2/trigger-analyses/notebooks/tpot2"

export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

echo "Running on node: $(hostname)"
echo "SLURM_JOB_NODELIST: ${SLURM_JOB_NODELIST}"
echo "SLURM_CPUS_PER_TASK: ${SLURM_CPUS_PER_TASK}"
echo "WORKDIR: ${WORKDIR}"

apptainer exec \
  --bind /scratch:/scratch \
  "${WORKDIR}/container/tpot_0.1.9a0.sif" \
  /opt/conda/envs/tpot2env/bin/python \
  "${WORKDIR}/tpot2_heatwave.py"
