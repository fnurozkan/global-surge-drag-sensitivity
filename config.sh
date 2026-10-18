#!/bin/bash
# Settings shared by the shell scripts in era5_forcing/ and model_runs/.
# All scripts are run from the repository root, e.g.
#   sbatch era5_forcing/02_prepare_run_windows.sh
# Edit the paths below for your own system.

# Base folder for all data produced by this workflow
DATA_DIR=${DATA_DIR:-$PWD/data}

ERA5_RAW_DIR=$DATA_DIR/era5_raw            # step 1: monthly ERA5 downloads, one subfolder per variable
FORCING_DIR=$DATA_DIR/forcing              # steps 2-4: one file per variable and yearly run window
UV10RHO_DAILY_DIR=$DATA_DIR/uv10rho_daily  # step 3: daily stress-equivalent winds, one subfolder per run window
EXPERIMENT_DIR=$DATA_DIR/experiments       # step 5: merged forcing, one subfolder per experiment

# CDO grid description of the GTSM forcing grid: the ERA5 0.25° grid,
# extended a few columns beyond ±180° so the forcing covers the date line
GRID_FILE=${GRID_FILE:-$PWD/era5_forcing/forcing_grid.txt}

# Each yearly run starts on 15 December of START_YEAR (15 days of spin-up)
# and ends on 1 January two years later: START_YEAR 2005 simulates 2006.
START_YEARS=${START_YEARS:-"2005 2006 2007 2008 2009 2010 2011 2012 2013 2014"}

# The four drag experiments (code name; paper name in brackets):
#   1-CC       (FIX)  constant Charnock, 10 m wind
#   2-CV       (NST)  ERA5 variable Charnock, 10 m wind
#   3-UV10N    (CAD)  ERA5 variable Charnock, 10 m neutral wind
#   4-UV10RHO  (IFS)  ERA5 variable Charnock, stress-equivalent wind (air-density corrected)
EXPERIMENTS="1-CC 2-CV 3-UV10N 4-UV10RHO"
