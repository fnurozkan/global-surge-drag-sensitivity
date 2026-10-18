"""
Step 1: download hourly ERA5 single-level fields as monthly NetCDF files.

Uses the Copernicus Climate Data Store API (cdsapi); a CDS account and a
~/.cdsapirc key file are required.

Output: <out-dir>/ERA5_<VAR>_<YYYYMM>.nc, e.g. ERA5_MSL_200601.nc

Example:
    python 01_download_era5.py --var msl --start 2005-12 --end 2016-01 --out-dir data/era5_raw/msl
"""

import argparse
import os

import cdsapi

# Short names used throughout the workflow -> ERA5 variable names
VARIABLES = {
    "chnk": ["charnock"],
    "msl": ["mean_sea_level_pressure"],
    "uv10": ["10m_u_component_of_wind", "10m_v_component_of_wind"],
    "uv10n": ["10m_u_component_of_neutral_wind", "10m_v_component_of_neutral_wind"],
    "t2m": ["2m_temperature"],
    "2d": ["2m_dewpoint_temperature"],
}


def months(start, end):
    """Yield (year, month) from start to end inclusive, both given as 'YYYY-MM'."""
    year, month = map(int, start.split("-"))
    end_year, end_month = map(int, end.split("-"))
    while (year, month) <= (end_year, end_month):
        yield year, month
        year, month = (year + 1, 1) if month == 12 else (year, month + 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--var", required=True, choices=VARIABLES)
    parser.add_argument("--start", required=True, help="first month, YYYY-MM")
    parser.add_argument("--end", required=True, help="last month, YYYY-MM")
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    client = cdsapi.Client()

    for year, month in months(args.start, args.end):
        output = os.path.join(args.out_dir, f"ERA5_{args.var.upper()}_{year}{month:02d}.nc")
        if os.path.exists(output):
            print(f"Already downloaded: {output}")
            continue
        print(f"Downloading {output}")
        client.retrieve(
            "reanalysis-era5-single-levels",
            {
                "product_type": "reanalysis",
                "variable": VARIABLES[args.var],
                "year": str(year),
                "month": f"{month:02d}",
                "day": [f"{d:02d}" for d in range(1, 32)],
                "time": [f"{h:02d}:00" for h in range(24)],
                "format": "netcdf",
            },
            output,
        )


if __name__ == "__main__":
    main()
