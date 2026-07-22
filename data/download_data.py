#!/usr/bin/env python3
"""Download TRIGGER tables into the local data directory."""

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

# Tables available as complete dumps.
DUMP_TABLE_GROUPS = {
    "tidy": "_tidy",
    "5min": "_5min",
    "hourly": "_hourly",
    "daily": "_daily",
}

# Tables that must be retrieved through SELECT rather than download().
SELECT_TABLE_GROUPS = {
    "accounts": [
        "accounts",
        "active_accounts",
    ],
}

# Safety limit for tables retrieved through select().
SELECT_MAX_ROWS = 1_000_000


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


def get_dump_tables(
    available_tables: set[str],
) -> dict[str, list[str]]:
    """Group dump tables by temporal resolution."""
    return {
        group: sorted(
            table
            for table in available_tables
            if table.endswith(suffix)
        )
        for group, suffix in DUMP_TABLE_GROUPS.items()
    }


def get_select_tables(
    available_tables: set[str],
) -> dict[str, list[str]]:
    """Return explicitly requested tables available through SELECT."""
    return {
        group: [
            table
            for table in tables
            if table in available_tables
        ]
        for group, tables in SELECT_TABLE_GROUPS.items()
    }


def select_complete_table(
    db: TriggerDB,
    table: str,
) -> pd.DataFrame:
    """Retrieve all exposed columns of a table using select()."""
    columns = list(db.columns(table))

    if not columns:
        raise RuntimeError(
            f"No columns were returned for table {table!r}."
        )

    table_data = pd.DataFrame(
        db.select(
            table=table,
            columns=columns,
            limit=SELECT_MAX_ROWS,
        )
    )

    if len(table_data) >= SELECT_MAX_ROWS:
        raise RuntimeError(
            f"{table!r} reached the SELECT limit of "
            f"{SELECT_MAX_ROWS:,} rows. The result may be incomplete."
        )

    return table_data


def save_log(records: list[dict]) -> None:
    """Save the current download log."""
    pd.DataFrame(records).to_csv(LOG_FILE, index=False)


def add_success_record(
    records: list[dict],
    *,
    started_at: datetime,
    group: str,
    table: str,
    rows: int,
    size_mb: float,
    duration_seconds: float,
) -> str:
    """Add a successful or empty-table record to the log."""
    status = "empty" if rows == 0 else "ok"

    records.append({
        "downloaded_at": started_at.isoformat(),
        "group": group,
        "table": table,
        "rows": rows,
        "size_mb": round(size_mb, 2),
        "duration_seconds": round(duration_seconds, 2),
        "status": status,
        "error": None,
    })

    return status


def add_error_record(
    records: list[dict],
    *,
    started_at: datetime,
    group: str,
    table: str,
    duration_seconds: float,
    error: Exception,
) -> None:
    """Add a failed-table record to the log."""
    records.append({
        "downloaded_at": started_at.isoformat(),
        "group": group,
        "table": table,
        "rows": None,
        "size_mb": None,
        "duration_seconds": round(duration_seconds, 2),
        "status": "error",
        "error": str(error),
    })


def download_dump_table(
    db: TriggerDB,
    *,
    group: str,
    table: str,
    records: list[dict],
) -> None:
    """Download one table using the complete dump endpoint."""
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

        status = add_success_record(
            records,
            started_at=table_started_at,
            group=group,
            table=table,
            rows=rows,
            size_mb=size_mb,
            duration_seconds=duration_seconds,
        )

        print(
            f"  {status.upper()}: {rows:,} rows, "
            f"{size_mb:.2f} MB, "
            f"{format_duration(duration_seconds)}"
        )

        del table_data
        gc.collect()

    except Exception as error:
        duration_seconds = perf_counter() - table_started_clock

        add_error_record(
            records,
            started_at=table_started_at,
            group=group,
            table=table,
            duration_seconds=duration_seconds,
            error=error,
        )

        print(
            f"  ERROR after "
            f"{format_duration(duration_seconds)}: {error}"
        )

    save_log(records)


def download_select_table(
    db: TriggerDB,
    *,
    group: str,
    table: str,
    records: list[dict],
) -> None:
    """Download one table using SELECT * through the API."""
    outfile = DATA_DIR / group / f"{table}.csv.gz"
    table_started_at = datetime.now().astimezone()
    table_started_clock = perf_counter()

    print(f"Selecting {table}...")

    try:
        table_data = select_complete_table(
            db=db,
            table=table,
        )

        table_data.to_csv(
            outfile,
            index=False,
            compression="gzip",
        )

        duration_seconds = perf_counter() - table_started_clock
        rows = len(table_data)
        size_mb = outfile.stat().st_size / 1024**2

        status = add_success_record(
            records,
            started_at=table_started_at,
            group=group,
            table=table,
            rows=rows,
            size_mb=size_mb,
            duration_seconds=duration_seconds,
        )

        print(
            f"  {status.upper()}: {rows:,} rows, "
            f"{size_mb:.2f} MB, "
            f"{format_duration(duration_seconds)}"
        )

        del table_data
        gc.collect()

    except Exception as error:
        duration_seconds = perf_counter() - table_started_clock

        add_error_record(
            records,
            started_at=table_started_at,
            group=group,
            table=table,
            duration_seconds=duration_seconds,
            error=error,
        )

        print(
            f"  ERROR after "
            f"{format_duration(duration_seconds)}: {error}"
        )

    save_log(records)


def main() -> None:
    """Download all configured TRIGGER tables."""
    run_started_at = datetime.now().astimezone()
    run_started_clock = perf_counter()

    DATA_DIR.mkdir(parents=True, exist_ok=True)

    all_groups = (
        *DUMP_TABLE_GROUPS,
        *SELECT_TABLE_GROUPS,
    )

    for group in all_groups:
        (DATA_DIR / group).mkdir(
            parents=True,
            exist_ok=True,
        )

    print("=" * 70)
    print("TRIGGER DATA DOWNLOAD")
    print(f"Started: {run_started_at:%Y-%m-%d %H:%M:%S %Z}")
    print(f"Data directory: {DATA_DIR}")
    print("=" * 70)

    download_log: list[dict] = []

    with TriggerDB() as db:
        available_tables = set(db.tables())

        dump_tables = get_dump_tables(
            available_tables=available_tables,
        )

        select_tables = get_select_tables(
            available_tables=available_tables,
        )

        for group, tables in dump_tables.items():
            print(f"\n[{group}] {len(tables)} dump table(s)")

            for table in tables:
                download_dump_table(
                    db=db,
                    group=group,
                    table=table,
                    records=download_log,
                )

        for group, configured_tables in SELECT_TABLE_GROUPS.items():
            available_group_tables = select_tables[group]
            missing_tables = sorted(
                set(configured_tables) - set(available_group_tables)
            )

            print(
                f"\n[{group}] "
                f"{len(available_group_tables)} SELECT table(s)"
            )

            for table in missing_tables:
                print(
                    f"  WARNING: {table!r} is not available "
                    f"through TriggerDB."
                )

            for table in available_group_tables:
                download_select_table(
                    db=db,
                    group=group,
                    table=table,
                    records=download_log,
                )

    run_finished_at = datetime.now().astimezone()
    total_duration_seconds = perf_counter() - run_started_clock

    if download_log:
        log = pd.DataFrame(download_log)
        status_counts = log["status"].value_counts().to_dict()
    else:
        status_counts = {}

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
