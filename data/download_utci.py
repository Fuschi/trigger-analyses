#!/usr/bin/env python3
"""Manage GPS grid-point selection and Copernicus UTCI time-series downloads."""

import argparse
import io
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date, timedelta
from pathlib import Path

import cdsapi
import numpy as np
import pandas as pd
import requests

DATA = Path(__file__).resolve().parent
GPS = DATA / "tidy/gps_tidy.csv.gz"
OUT = DATA / "shared/utci"
POINTS = OUT / "grid_points.csv"
CITIES_ZIP = OUT / ".cache/cities5000.zip"
CITIES_URL = "https://download.geonames.org/export/dump/cities5000.zip"
CITY_POINTS = {
    "Augsburg": (48.50, 10.75),
    "Bologna": (44.50, 11.25),
    "Geneva": (46.25, 6.00),
    "Heraklion": (35.25, 25.00),
}
DEFAULT_START = date(2025, 1, 1)
DEFAULT_END = date.today() - timedelta(days=5)
KEYS = ["grid_latitude", "grid_longitude"]


def read_cities():
    """Load the GeoNames cities5000 catalogue, downloading it only once."""
    CITIES_ZIP.parent.mkdir(parents=True, exist_ok=True)
    if not CITIES_ZIP.exists():
        print("Downloading GeoNames cities5000 catalogue...")
        response = requests.get(CITIES_URL, timeout=120)
        response.raise_for_status()
        with zipfile.ZipFile(io.BytesIO(response.content)) as archive:
            if "cities5000.txt" not in archive.namelist():
                raise ValueError("Unexpected GeoNames archive contents")
        CITIES_ZIP.write_bytes(response.content)

    with zipfile.ZipFile(CITIES_ZIP) as archive:
        with archive.open("cities5000.txt") as source:
            return pd.read_csv(source, sep="\t", header=None, usecols=[1, 4, 5, 8],
                               names=["city", "latitude", "longitude", "country"],
                               dtype={"city": "string", "country": "string"})


def add_city_labels(points, max_distance_km=40):
    """Annotate each cell with the nearest GeoNames city within the radius."""
    cities = read_cities()
    city_lat = np.radians(cities.latitude.to_numpy(dtype=float))
    city_lon = np.radians(cities.longitude.to_numpy(dtype=float))
    results = []

    for row in points.itertuples(index=False):
        latitude = np.radians(row.grid_latitude)
        longitude = np.radians(row.grid_longitude)
        a = (np.sin((city_lat - latitude) / 2)**2 +
             np.cos(latitude) * np.cos(city_lat) * np.sin((city_lon - longitude) / 2)**2)
        distances = 12742 * np.arcsin(np.sqrt(np.clip(a, 0, 1)))
        nearest = int(np.argmin(distances))
        km = float(distances[nearest])
        results.append((cities.city.iloc[nearest], cities.country.iloc[nearest], round(km, 1))
                       if km <= max_distance_km else (pd.NA, pd.NA, pd.NA))

    points[["city", "country", "city_distance_km"]] = pd.DataFrame(results, index=points.index)
    return points


def automatic_mask(points, min_users, min_days, min_gps):
    """Require all coverage thresholds; these are selection, not QC, criteria."""
    return ((points.users_n >= min_users) & (points.user_days_n >= min_days) &
            (points.gps_n >= min_gps))


def prepare(args):
    """Summarize GPS observations and create/update editable grid-point list."""
    if not GPS.exists():
        raise FileNotFoundError(f"Missing GPS file: {GPS}")

    gps = pd.read_csv(GPS, usecols=["userId", "minute_ts", "latitude", "longitude", "accuracy"],
                      dtype={"userId": "string"})
    gps["minute_ts"] = pd.to_datetime(gps.minute_ts, utc=True, errors="coerce")
    gps = gps.loc[gps.userId.notna() & gps.minute_ts.notna() &
                  gps.accuracy.between(args.accuracy_min, args.accuracy_max) &
                  gps.latitude.between(-90, 90) & gps.longitude.between(-180, 180)].copy()
    if gps.empty:
        raise ValueError("No GPS observations pass the accuracy/coordinate filters")

    gps["date"] = gps.minute_ts.dt.date
    gps["grid_latitude"] = (gps.latitude * 4).round() / 4
    gps["grid_longitude"] = (gps.longitude * 4).round() / 4

    points = gps.groupby(KEYS, as_index=False).agg(gps_n=("userId", "size"),
                                                    users_n=("userId", "nunique"))
    days = (gps.drop_duplicates(KEYS + ["userId", "date"])
            .groupby(KEYS).size().reset_index(name="user_days_n"))
    points = points.merge(days, on=KEYS, how="left")
    points = add_city_labels(points, args.max_city_km)
    points["selected"] = automatic_mask(points, args.min_users, args.min_days, args.min_gps)

    if POINTS.exists() and not args.reset_selection:
        previous = pd.read_csv(POINTS, usecols=KEYS + ["selected"])
        previous["selected"] = previous.selected.astype("string").str.lower().eq("true")
        points = points.merge(previous.rename(columns={"selected": "previous_selected"}),
                              on=KEYS, how="left")
        points["selected"] = points.previous_selected.fillna(points.selected).astype(bool)
        points = points.drop(columns="previous_selected")

    points = points.sort_values(["user_days_n", "gps_n"], ascending=False)
    OUT.mkdir(parents=True, exist_ok=True)
    points.to_csv(POINTS, index=False)
    print(f"Grid cells: {len(points):,} | Selected: {int(points.selected.sum()):,}")
    print(f"CSV: {POINTS}")


def select(args):
    """Explicitly recompute all selected flags using new coverage thresholds."""
    points = pd.read_csv(POINTS)
    points["selected"] = automatic_mask(points, args.min_users, args.min_days, args.min_gps)
    points.to_csv(POINTS, index=False)
    print(f"Selected: {int(points.selected.sum()):,} / {len(points):,}")


def read_valid_csv(path, latitude, longitude):
    """Read existing UTCI observations, allowing missing hours and UTCI values."""
    frame = pd.read_csv(path)
    if not {"valid_time", "utci", "latitude", "longitude"}.issubset(frame.columns):
        raise ValueError("Unexpected CSV columns")
    times = pd.to_datetime(frame.valid_time, utc=True, errors="coerce")
    if times.isna().any() or times.duplicated().any():
        raise ValueError("Invalid or duplicate timestamps")
    if times.empty or not times.is_monotonic_increasing:
        raise ValueError("Empty or unordered timestamps")
    if (times.dt.minute.ne(0) | times.dt.second.ne(0)).any():
        raise ValueError("Unexpected sub-hourly timestamps")
    if frame[["latitude", "longitude"]].isna().any().any():
        raise ValueError("Missing coordinates")
    if ((frame.latitude - latitude).abs() > .001).any() or ((frame.longitude - longitude).abs() > .001).any():
        raise ValueError("Unexpected grid coordinates")
    # Missing UTCI values are valid in some meteorological conditions.
    frame["valid_time"] = times
    return frame


def retrieve_csv(client, latitude, longitude, start, end, raw, staged):
    """Retrieve a date range and retain valid UTCI records even if hours are missing."""
    request = {"variable": ["universal_thermal_climate_index"],
               "location": {"longitude": longitude, "latitude": latitude},
               "date": [f"{start}/{end}"], "data_format": "csv"}
    client.retrieve("derived-utci-historical-timeseries", request).download(str(raw))
    if zipfile.is_zipfile(raw):
        with zipfile.ZipFile(raw) as archive:
            names = [n for n in archive.namelist() if n.lower().endswith(".csv")]
            if len(names) != 1:
                raise ValueError("Expected exactly one CSV inside CDS archive")
            staged.write_bytes(archive.read(names[0]))
    else:
        raw.replace(staged)

    frame = read_valid_csv(staged, latitude, longitude)
    expected = pd.date_range(start, f"{end} 23:00", freq="h", tz="UTC")
    times = pd.DatetimeIndex(frame.valid_time)
    outside = times.difference(expected)
    if len(outside):
        raise ValueError(f"{len(outside)} timestamps outside requested range")
    missing = expected.difference(times)
    if len(missing):
        print(f"  WARNING: {len(missing):,} missing hours in {start} to {end} "
              f"(first missing: {missing[0]})", flush=True)
    if frame.utci.isna().any():
        print(f"  INFO: {frame.utci.isna().sum():,} missing UTCI values", flush=True)
    return frame


def download_point(row, start, end, force=False):
    """Download one cell with its own CDS client and temporary files."""
    lat, lon = float(row.grid_latitude), float(row.grid_longitude)
    name = f"{lat:.2f}_{lon:.2f}"
    target = OUT / f"UTCI-{name}.csv"
    raw, staged = OUT / f".{name}.download", OUT / f".{name}.csv"
    candidates = [target] + [OUT / f"UTCI-{city}.csv" for city, coords in CITY_POINTS.items()
                              if coords == (lat, lon)]
    prefix = None
    source = None

    if not force:
        for existing in candidates:
            if not existing.exists():
                continue
            try:
                frame = read_valid_csv(existing, lat, lon)
            except (ValueError, KeyError, pd.errors.ParserError, pd.errors.EmptyDataError):
                print(f"WARNING {name}: invalid {existing.name}; ignoring it", flush=True)
                continue

            times = frame.valid_time
            first, last = times.iloc[0].date(), times.iloc[-1].date()
            if first <= start and last >= end and times.iloc[0].hour == 0 and times.iloc[-1].hour == 23:
                print(f"SKIP {name}: {existing.name} already reaches {end} (check gaps separately)", flush=True)
                return True
            if first <= start and times.iloc[-1].hour == 23 and last < end:
                if prefix is None or last > prefix.valid_time.iloc[-1].date():
                    prefix, source = frame, existing

    missing_start = prefix.valid_time.iloc[-1].date() + timedelta(days=1) if prefix is not None else start
    print(f"Downloading {name} ({missing_start} to {end})..." +
          (f" [extending {source.name}]" if prefix is not None else ""), flush=True)
    try:
        client = cdsapi.Client(retry_max=3, sleep_max=10)
        fetched = retrieve_csv(client, lat, lon, missing_start, end, raw, staged)
        if prefix is not None:
            result = pd.concat([prefix, fetched], ignore_index=True)
            if result.valid_time.duplicated().any():
                raise ValueError("Duplicated timestamps after merging")
            result.to_csv(staged, index=False)
        # Replace atomically; original city CSV is never overwritten.
        staged.replace(target)
        print(f"OK {name}: {len(fetched):,} received hours -> {target.name}", flush=True)
        return True
    except Exception as exc:
        print(f"ERROR {name}: {exc}", flush=True)
        return False
    finally:
        raw.unlink(missing_ok=True)
        staged.unlink(missing_ok=True)


def download(args):
    """Download selected UTCI cells with limited parallel requests."""
    points = pd.read_csv(POINTS)
    points = points.loc[points.selected.astype("string").str.lower().eq("true")]
    if points.empty:
        print("No points selected. Edit grid_points.csv or run 'select'.")
        return

    start = date.fromisoformat(args.start)
    end = date.fromisoformat(args.end)
    if end < start:
        raise ValueError("--end must not precede --start")

    print(f"Processing {len(points):,} selected cells with {args.workers} worker(s)", flush=True)
    rows = list(points.itertuples(index=False))
    errors = 0
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = [executor.submit(download_point, row, start, end, args.force) for row in rows]
        for future in as_completed(futures):
            if not future.result():
                errors += 1

    if errors:
        raise SystemExit(f"Failed downloads: {errors}")


def status(args):
    """Summarize selected grid cells and their GPS coverage."""
    points = pd.read_csv(POINTS)
    selected = points.selected.astype("string").str.lower().eq("true")
    subset = points.loc[selected]

    gps_coverage = 100 * subset.gps_n.sum() / points.gps_n.sum()
    days_coverage = 100 * subset.user_days_n.sum() / points.user_days_n.sum()

    print(f"Total grid cells: {len(points):,}")
    print(f"Selected: {selected.sum():,} ({selected.mean():.1%})")
    print(f"With city label: {points.city.notna().sum():,}")
    print(f"GPS observations covered: {gps_coverage:.1f}% ({subset.gps_n.sum():,} / {points.gps_n.sum():,})")
    print(f"Participant-days covered: {days_coverage:.1f}% ({subset.user_days_n.sum():,} / {points.user_days_n.sum():,})")
    print("Selected cells by country:")
    print(subset.groupby("country", dropna=False).size().sort_values(ascending=False).to_string())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    p = sub.add_parser("prepare", help="Build/update GPS grid-point catalogue")
    p.add_argument("--accuracy-min", type=float, default=1)
    p.add_argument("--accuracy-max", type=float, default=200)
    p.add_argument("--max-city-km", type=float, default=40)
    p.add_argument("--min-users", type=int, default=2)
    p.add_argument("--min-days", type=int, default=10)
    p.add_argument("--min-gps", type=int, default=20)
    p.add_argument("--reset-selection", action="store_true")
    s = sub.add_parser("select", help="Recalculate selection using new thresholds")
    s.add_argument("--min-users", type=int, default=2)
    s.add_argument("--min-days", type=int, default=10)
    s.add_argument("--min-gps", type=int, default=20)
    d = sub.add_parser("download", help="Download selected UTCI time series")
    d.add_argument("--start", default=DEFAULT_START.isoformat())
    d.add_argument("--end", default=DEFAULT_END.isoformat())
    d.add_argument("--force", action="store_true")
    d.add_argument("--workers", type=int, choices=range(1, 5), metavar="{1,2,3,4}", default=1,
                   help="Concurrent CDS requests (default: 1; recommended: 2)")
    sub.add_parser("status", help="Summarize GPS point selection")
    args = parser.parse_args()

    {"prepare": prepare, "select": select, "download": download, "status": status}[args.action](args)


if __name__ == "__main__":
    main()

