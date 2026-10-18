#!/bin/bash
# Create one GTSM run folder per experiment and simulated year from a template
# folder, and fill in the forcing, run period and SLURM settings.
#
# The template folder holds a GTSM setup (grid, bathymetry, model settings),
# which is not part of this repository: GTSM is developed by Deltares. The
# script expects these placeholders in the template:
#   gtsm_forcing.ext.template    template_quantity, template_file_name
#   gtsm_forcing.mdu.template    template_refdate, template_tstart, template_tstop, template_mapinterval
#   submit_script_snellius.sh    template_tasks_per_node, template_job_name, template_time, template_nPart
#
# Result: $RUNS_DIR/<experiment>/<simulated year>/, ready to submit with
#   cd $RUNS_DIR/2-CV/2006 && sbatch submit_script_snellius.sh
#
# Run from the repository root:  bash model_runs/setup_runs.sh

set -e
source config.sh

TEMPLATE_DIR=${TEMPLATE_DIR:-$PWD/gtsm_template}  # GTSM template folder (not included)
RUNS_DIR=${RUNS_DIR:-$PWD/runs}

N_PARTITIONS=32          # MPI partitions = tasks per node
RUN_TIME="120:00:00"     # SLURM wall time per yearly run
MAP_INTERVAL="0."        # no map (field) output; e.g. "3600. <start> <end>" in seconds for hourly maps
TSTART=0.

declare -A QUANTITY=(
    ["1-CC"]="airpressure_windx_windy"
    ["2-CV"]="airpressure_windx_windy_charnock"
    ["3-UV10N"]="airpressure_windx_windy_charnock"
    ["4-UV10RHO"]="airpressure_windx_windy_charnock"
)
declare -A FORCING_NAME=(
    ["1-CC"]="MSL_UV10"
    ["2-CV"]="C_MSL_UV10"
    ["3-UV10N"]="C_MSL_UV10N"
    ["4-UV10RHO"]="C_MSL_UV10RHO"
)

for experiment in $EXPERIMENTS; do
    for year in $START_YEARS; do
        sim_year=$((year + 1))
        run_dir="$RUNS_DIR/$experiment/$sim_year"
        forcing_file="$EXPERIMENT_DIR/$experiment/ERA5_${FORCING_NAME[$experiment]}_${year}12150000_$((year + 2))01010000.nc"

        # Run length in hours from 15 Dec to 1 Jan (longer when the simulated year is a leap year)
        if (( sim_year % 4 == 0 && (sim_year % 100 != 0 || sim_year % 400 == 0) )); then
            tstop=9192.
        else
            tstop=9169.
        fi

        mkdir -p "$run_dir"
        cp -r "$TEMPLATE_DIR"/. "$run_dir"/

        sed -i -e "s|template_quantity|${QUANTITY[$experiment]}|" \
               -e "s|template_file_name|$forcing_file|" \
               "$run_dir/gtsm_forcing.ext.template"
        sed -i -e "s|template_refdate|${year}1215|" \
               -e "s|template_tstart|$TSTART|" \
               -e "s|template_tstop|$tstop|" \
               -e "s|template_mapinterval|$MAP_INTERVAL|" \
               "$run_dir/gtsm_forcing.mdu.template"
        mv "$run_dir/gtsm_forcing.ext.template" "$run_dir/gtsm_forcing.ext"
        mv "$run_dir/gtsm_forcing.mdu.template" "$run_dir/gtsm_forcing.mdu"

        sed -i -e "s|template_tasks_per_node|$N_PARTITIONS|" \
               -e "s|template_job_name|${experiment}-${sim_year}|" \
               -e "s|template_time|$RUN_TIME|" \
               -e "s|template_nPart|$N_PARTITIONS|" \
               "$run_dir/submit_script_snellius.sh"

        echo "Created $run_dir"
    done
done
