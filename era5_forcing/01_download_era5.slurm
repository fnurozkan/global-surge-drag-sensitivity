#!/bin/bash
# Step 1: download all ERA5 variables needed for the forcing.
# The period runs from December of the first start year to January of the
# year after the last simulated year (2005-12 to 2016-01 for 2006-2015).
#
# Run from the repository root:  sbatch era5_forcing/01_download_era5.slurm

#SBATCH --nodes=1
#SBATCH --tasks-per-node=32
#SBATCH --partition=rome
#SBATCH --time=24:00:00
#SBATCH --job-name=era5_download

source config.sh

first=${START_YEARS%% *}
last=${START_YEARS##* }

for var in chnk msl uv10 uv10n t2m 2d; do
    conda run -n surge-drag python era5_forcing/01_download_era5.py \
        --var $var --start ${first}-12 --end $((last + 2))-01 --out-dir "$ERA5_RAW_DIR/$var"
done
