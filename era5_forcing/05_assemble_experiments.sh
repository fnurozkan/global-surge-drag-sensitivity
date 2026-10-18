#!/bin/bash
# Step 5: merge the variables each experiment needs into one forcing file per run.
#
#   Experiment (paper name)  Wind in u10/v10           Charnock  GTSM quantity
#   1-CC       (FIX)         10 m wind                 constant  airpressure_windx_windy
#   2-CV       (NST)         10 m wind                 ERA5 (c)  airpressure_windx_windy_charnock
#   3-UV10N    (CAD)         10 m neutral wind         ERA5 (c)  airpressure_windx_windy_charnock
#   4-UV10RHO  (IFS)         stress-equivalent wind    ERA5 (c)  airpressure_windx_windy_charnock
#
# All files also contain mean sea-level pressure (msl).
#
# 1-CC has no Charnock field: GTSM then uses its constant Charnock parameter (0.041).
#
# Run from the repository root:  sbatch era5_forcing/05_assemble_experiments.sh

#SBATCH --nodes=1
#SBATCH --tasks-per-node=32
#SBATCH --partition=rome
#SBATCH --time=12:00:00
#SBATCH --job-name=assemble_experiments

# Snellius modules; adapt or remove on other systems
module load 2022
module load CDO/2.0.6-gompi-2022a

set -e
source config.sh

declare -A INPUTS=(
    ["1-CC"]="MSL UV10"
    ["2-CV"]="C MSL UV10"
    ["3-UV10N"]="C MSL UV10N"
    ["4-UV10RHO"]="C MSL UV10RHO"
)

for experiment in $EXPERIMENTS; do
    mkdir -p "$EXPERIMENT_DIR/$experiment"
    for year in $START_YEARS; do
        window=${year}12150000_$((year + 2))01010000
        files=""
        for var in ${INPUTS[$experiment]}; do
            files="$files $FORCING_DIR/ERA5_${var}_${window}.nc"
        done
        name=$(echo ${INPUTS[$experiment]} | tr ' ' '_')
        cdo -b F64 merge $files "$EXPERIMENT_DIR/$experiment/ERA5_${name}_${window}.nc"
        echo "$experiment $window done"
    done
done
