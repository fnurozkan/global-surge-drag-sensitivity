#!/bin/bash
# Step 3: stress-equivalent wind for the 4-UV10RHO experiment (see the .py file).
#
# Run from the repository root:  sbatch era5_forcing/03_stress_equivalent_wind.slurm

#SBATCH --nodes=1
#SBATCH --tasks-per-node=32
#SBATCH --partition=rome
#SBATCH --time=24:00:00
#SBATCH --job-name=uv10rho

source config.sh

conda run -n surge-drag python era5_forcing/03_stress_equivalent_wind.py \
    --forcing-dir "$FORCING_DIR" --out-dir "$UV10RHO_DAILY_DIR" --start-years $START_YEARS
