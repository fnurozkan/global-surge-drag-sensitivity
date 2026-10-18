#!/bin/bash
# Step 4: merge the daily stress-equivalent wind files from step 3 into one
# file per run window, matching the other variables from step 2:
#   uv10rho_daily/200512150000_200701010000/ERA5_UV10RHO_*.nc
#     ->  forcing/ERA5_UV10RHO_200512150000_200701010000.nc
# No remapping is needed: step 3 already works on the forcing grid.
#
# Run from the repository root:  sbatch era5_forcing/04_uv10rho_run_windows.sh

#SBATCH --nodes=1
#SBATCH --tasks-per-node=32
#SBATCH --partition=rome
#SBATCH --time=24:00:00
#SBATCH --job-name=uv10rho_windows

# Snellius modules; adapt or remove on other systems
module load 2022
module load CDO/2.0.6-gompi-2022a

set -e
source config.sh

for year in $START_YEARS; do
    window=${year}12150000_$((year + 2))01010000
    cdo -b F64 mergetime "$UV10RHO_DAILY_DIR/$window"/ERA5_UV10RHO_*.nc "$FORCING_DIR/ERA5_UV10RHO_${window}.nc"
    echo "$window done"
done
