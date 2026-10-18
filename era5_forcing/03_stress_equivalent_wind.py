"""
Step 3: compute the stress-equivalent 10 m wind for the 4-UV10RHO (IFS) experiment.

GTSM computes the surface wind stress with a constant air density
(rho_ref = 1.2 kg/m3). ERA5 (the ECMWF IFS) uses the actual air density.
This script rescales the ERA5 neutral wind so that GTSM, with its constant
air density, feels the same surface stress as with the real air density:

  1. air density from 2 m dew point, 2 m temperature and sea-level pressure
  2. friction velocity u* from the neutral wind and the ERA5 Charnock
     parameter, iterating the Charnock relation z0 = alpha * u*^2 / g
  3. u*_rho = u* * sqrt(rho / rho_ref), converted back to a 10 m wind
     with the logarithmic wind profile

Inputs are the run-window files from step 2. The calculation runs day by day
to keep memory use low and writes one file per day of each run window:
    <out-dir>/<window>/ERA5_UV10RHO_YYYYMMDD.nc

Example:
    python 03_stress_equivalent_wind.py --forcing-dir data/forcing \
        --out-dir data/uv10rho_daily --start-years 2005 2006
"""

import argparse
import gc
import os

import numpy as np
import xarray as xr

# Thermodynamic constants
E0 = 611.21      # reference water vapour pressure [Pa]
T0 = 273.16      # reference temperature [K]
RV = 461.525     # gas constant for water vapour [J/(kg K)]
RD = 287.0597    # gas constant for dry air [J/(kg K)]
EPSILON = RV / RD - 1

# Surface-layer constants
KAPPA = 0.40                 # von Karman constant
G = 9.81                     # gravitational acceleration [m/s2]
Z10 = 10                     # wind reference height [m]
RHO_REF = 1.20000004768372   # constant air density used by GTSM (set in the .mdu file) [kg/m3]

METADATA = {
    "latitude": {"standard_name": "latitude", "short_name": "lat", "units": "degrees_north", "axis": "Y"},
    "longitude": {"standard_name": "longitude", "short_name": "lon", "units": "degrees_east", "axis": "X"},
    "time": {"long_name": "time", "short_name": "time", "axis": "T"},
    "u10": {"long_name": "u component of stress-equivalent wind (air density corrected)", "short_name": "u10", "units": "m/s"},
    "v10": {"long_name": "v component of stress-equivalent wind (air density corrected)", "short_name": "v10", "units": "m/s"},
}


def air_density(td, t2m, msl):
    """Air density [kg/m3] from dew point [K], temperature [K] and pressure [Pa]."""
    e = E0 * np.exp(17.502 * (td - T0) / (td - 32.19))   # water vapour pressure [Pa]
    qv = e / (msl + EPSILON * (msl - e))                  # specific humidity [kg/kg]
    tv = (1 + EPSILON * qv) * t2m                         # virtual temperature [K]
    return msl / (RD * tv)


def drag_coefficient(wind_speed, charnock):
    """Neutral drag coefficient from the 10 m neutral wind speed and the Charnock parameter.

    Solves u* = kappa * U10 / ln(z10 / z0) and z0 = charnock * u*^2 / g iteratively.
    """
    z0 = 0.01 * xr.ones_like(charnock)   # initial guess for the roughness length [m]
    i = 0
    eps_z0 = 1
    while (eps_z0 > 1e-8 or i < 4) and i < 25:
        i += 1
        ustar = wind_speed * KAPPA / np.log(Z10 / z0)
        z0_new = charnock * ustar**2 / G
        eps_z0 = np.max(np.abs(z0_new - z0))
        z0 = z0_new
    return (ustar / wind_speed) ** 2


def stress_equivalent_wind(u10n, v10n, rho, charnock):
    """Rescale the neutral wind components so that rho_ref * Cd * U^2 equals the stress at the actual density."""
    wind_speed = np.sqrt(u10n**2 + v10n**2)
    cd = drag_coefficient(wind_speed, charnock)

    ustar = np.sqrt(cd) * wind_speed
    ustar_rho = ustar * np.sqrt(rho / RHO_REF)
    z0_rho = charnock * ustar_rho**2 / G
    wind_speed_rho = ustar_rho / KAPPA * np.log(Z10 / z0_rho)

    return u10n * wind_speed_rho / wind_speed, v10n * wind_speed_rho / wind_speed


def process_window(forcing_dir, out_dir, start_year):
    window = f"{start_year}12150000_{start_year + 2}01010000"
    window_dir = os.path.join(out_dir, window)
    os.makedirs(window_dir, exist_ok=True)
    print(f"\n=== Run window {window} ===")

    def load(name):
        return xr.open_dataset(os.path.join(forcing_dir, f"ERA5_{name}_{window}.nc"))

    td = load("2D")        # 2 m dew point temperature
    msl = load("MSL")      # mean sea-level pressure
    t2m = load("T2M")      # 2 m temperature
    uv10n = load("UV10N")  # 10 m neutral wind (renamed to u10/v10 in step 2)
    ch = load("C")         # Charnock parameter

    days = td.time.dt.floor("D")
    for day in np.unique(days.values):
        save_path = os.path.join(window_dir, f"ERA5_UV10RHO_{np.datetime_as_string(day, unit='D').replace('-', '')}.nc")
        if os.path.exists(save_path):
            continue
        sel = (days == day).values

        rho = air_density(td.d2m[sel], t2m.t2m[sel], msl.msl[sel])
        u10, v10 = stress_equivalent_wind(uv10n.u10[sel], uv10n.v10[sel], rho, ch.c[sel])

        ds = xr.Dataset(
            coords={
                "latitude": (["latitude"], td.latitude.values, METADATA["latitude"]),
                "longitude": (["longitude"], td.longitude.values, METADATA["longitude"]),
                "time": (["time"], td.time.values[sel], METADATA["time"]),
            },
            data_vars={
                "u10": (["time", "latitude", "longitude"], u10.values, METADATA["u10"]),
                "v10": (["time", "latitude", "longitude"], v10.values, METADATA["v10"]),
            },
        )
        ds.to_netcdf(save_path)
        print(f"Saved: {save_path}")

        del ds, rho, u10, v10
        gc.collect()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--forcing-dir", required=True, help="folder with the run-window files from step 2")
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--start-years", required=True, type=int, nargs="+")
    args = parser.parse_args()

    for start_year in args.start_years:
        process_window(args.forcing_dir, args.out_dir, start_year)
    print("All run windows done.")


if __name__ == "__main__":
    main()
