#!/usr/bin/env python3
"""Download TRIGGER table dumps into the local data directory."""

from __future__ import annotations

import gc
from datetime import datetime
from pathlib import Path
from time import perf_counter

import pandas as pd
from trigger import TriggerDB


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data"
LOG_FILE = DATA_DIR / "download_log.csv"

TABLE_GROUPS = {
    "tidy": "_tidy",
    "5min": "_5min",
    "hourly": "_hourly",
    "daily": "_daily",
}


def format_duration(seconds: float) -> str:
    """Return a compact human-readable duration."""
    if seconds < 60:
        return f"{seconds:.1f} s"

    minutes, remaining_seconds = divmod(seconds, 60)

    if minutes < 60:
        return f"{int(minutes)} min {remaining_seconds:.1f} s"

    hours, remaining_minutes = divmod(minutes, 60)
    return (
        f"{int(hours)} h {int(remaining_minutes)} min "
        f"{remaining_seconds:.1f} s"
    )


def get_dump_tables(db: TriggerDB) -> dict[str, list[str]]:
    """Group available tables by temporal resolution."""
    available_tables = db.tables()

    return {
        group: sorted(
            table
            for table in available_tables
            if table.endswith(suffix)
        )
        for group, suffix in TABLE_GROUPS.items()
    }


def save_log(records: list[dict]) -> None:
    """Save the current download log."""
    pd.DataFrame(records).to_csv(LOG_FILE, index=False)


def main() -> None:
    """Download all tidy, 5-minute, hourly, and daily table dumps."""
    run_started_at = datetime.now().astimezone()
    run_started_clock = perf_counter()

    DATA_DIR.mkdir(parents=True, exist_ok=True)

    for group in TABLE_GROUPS:
        (DATA_DIR / group).mkdir(parents=True, exist_ok=True)

    print("=" * 70)
    print("TRIGGER DATA DOWNLOAD")
    print(f"Started: {run_started_at:%Y-%m-%d %H:%M:%S %Z}")
    print(f"Data directory: {DATA_DIR}")
    print("=" * 70)

    download_log: list[dict] = []

    with TriggerDB() as db:
        dump_tables = get_dump_tables(db)

        for group, tables in dump_tables.items():
            print(f"\n[{group}] {len(tables)} table(s)")

            for table in tables:
                outfile = DATA_DIR / group / f"{table}.csv.gz"
                table_started_at = datetime.now().astimezone()
                table_started_clock = perf_counter()

                print(f"Downloading {table}...")

                try:
                    table_data = db.download(
                        table=table,
                        outfile=outfile,
                    )

                    duration_seconds = perf_counter() - table_started_clock
                    rows = len(table_data)
                    size_mb = outfile.stat().st_size / 1024**2
                    status = "empty" if rows == 0 else "ok"

                    download_log.append({
                        "downloaded_at": table_started_at.isoformat(),
                        "group": group,
                        "table": table,
                        "rows": rows,
                        "size_mb": round(size_mb, 2),
                        "duration_seconds": round(duration_seconds, 2),
                        "status": status,
                        "error": None,
                    })

                    print(
                        f"  {status.upper()}: {rows:,} rows, "
                        f"{size_mb:.2f} MB, "
                        f"{format_duration(duration_seconds)}"
                    )

                    del table_data
                    gc.collect()

                except Exception as error:
                    duration_seconds = perf_counter() - table_started_clock

                    download_log.append({
                        "downloaded_at": table_started_at.isoformat(),
                        "group": group,
                        "table": table,
                        "rows": None,
                        "size_mb": None,
                        "duration_seconds": round(duration_seconds, 2),
                        "status": "error",
                        "error": str(error),
                    })

                    print(
                        f"  ERROR after "
                        f"{format_duration(duration_seconds)}: {error}"
                    )

                # Update the log after every table so partial progress is preserved.
                save_log(download_log)

    run_finished_at = datetime.now().astimezone()
    total_duration_seconds = perf_counter() - run_started_clock

    log = pd.DataFrame(download_log)
    status_counts = log["status"].value_counts().to_dict()

    print("\n" + "=" * 70)
    print("DOWNLOAD COMPLETED")
    print(f"Started:  {run_started_at:%Y-%m-%d %H:%M:%S %Z}")
    print(f"Finished: {run_finished_at:%Y-%m-%d %H:%M:%S %Z}")
    print(f"Duration: {format_duration(total_duration_seconds)}")
    print(f"OK:       {status_counts.get('ok', 0)}")
    print(f"Empty:    {status_counts.get('empty', 0)}")
    print(f"Errors:   {status_counts.get('error', 0)}")
    print(f"Log:      {LOG_FILE}")
    print("=" * 70)


if __name__ == "__main__":
    main()
