#!/bin/bash
# Step 2: turn the monthly ERA5 downloads into one file per variable and yearly GTSM run.
#
# For each variable:
#   1. merge the monthly files into calendar years
#        ERA5_MSL_200601.nc ... ERA5_MSL_200612.nc  ->  ERA5_MSL_merged_2006.nc
#   2. cut the run window: 15 December of the start year to 1 January two years
#      later (15 days of spin-up plus one full year)
#        ->  ERA5_MSL_200512150000_200701010000.nc
#   3. remap (nearest neighbour) onto the GTSM forcing grid
# Then rename variables to the names GTSM reads:
#   Charnock     chnk -> c        (file name CHNK -> C)
#   neutral wind u10n/v10n -> u10/v10
#
# Run from the repository root:  sbatch era5_forcing/02_prepare_run_windows.sh

#SBATCH --nodes=1
#SBATCH --tasks-per-node=32
#SBATCH --partition=rome
#SBATCH --time=24:00:00
#SBATCH --job-name=era5_run_windows

# Snellius modules; adapt or remove on other systems
module load 2022
module load CDO/2.0.6-gompi-2022a

set -e
source config.sh

# chnk: Charnock parameter     msl: mean sea-level pressure
# uv10: 10 m wind              uv10n: 10 m neutral wind
# t2m:  2 m temperature        2d: 2 m dew point temperature
VARIABLES="chnk msl uv10 uv10n t2m 2d"

first=${START_YEARS%% *}
last=${START_YEARS##* }
mkdir -p "$FORCING_DIR"

for var in $VARIABLES; do
    VAR=${var^^}
    echo "Processing $var"

    # 1. Monthly files -> calendar-year files
    for year in $(seq $first $((last + 2))); do
        cdo -b F64 mergetime "$ERA5_RAW_DIR/$var"/ERA5_${VAR}_${year}??.nc "$FORCING_DIR/ERA5_${VAR}_merged_${year}.nc"
    done

    # 2. + 3. Run windows on the forcing grid
    cd "$FORCING_DIR"
    for year in $START_YEARS; do
        window=${year}12150000_$((year + 2))01010000
        cdo seldate,${year}-12-15,${year}-12-31 ERA5_${VAR}_merged_${year}.nc tmp_spinup.nc
        cdo seldate,$((year + 2))-01-01T00:00:00 ERA5_${VAR}_merged_$((year + 2)).nc tmp_end.nc
        cdo -b F64 mergetime tmp_spinup.nc ERA5_${VAR}_merged_$((year + 1)).nc tmp_end.nc tmp_window.nc
        cdo remapnn,"$GRID_FILE" tmp_window.nc ERA5_${VAR}_${window}.nc
        rm tmp_spinup.nc tmp_end.nc tmp_window.nc
        echo "  $year done"
    done
    rm ERA5_${VAR}_merged_*.nc
    cd - > /dev/null
done

# Rename variables to the names GTSM reads
cd "$FORCING_DIR"
for year in $START_YEARS; do
    window=${year}12150000_$((year + 2))01010000
    cdo chname,chnk,c ERA5_CHNK_${window}.nc ERA5_C_${window}.nc
    rm ERA5_CHNK_${window}.nc
    cdo chname,u10n,u10,v10n,v10 ERA5_UV10N_${window}.nc tmp_uv10n.nc
    mv tmp_uv10n.nc ERA5_UV10N_${window}.nc
done

echo "Done: run-window files are in $FORCING_DIR"
