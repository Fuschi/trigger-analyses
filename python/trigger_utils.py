from trigger import TriggerDB
import pandas as pd
import logging
from contextlib import contextmanager
import time
import datetime as dt
from tqdm.auto import tqdm

#------------------------------------------------------------------------------#
@contextmanager
def silent_logger(logger_name: str = "trigger", level: int = logging.WARNING):
    """
    Context manager that temporarily changes the log level of a specific logger.

    Parameters
    ----------
    logger_name : str, optional
        Name of the logger to adjust.
        Default: "trigger".
    level : int, optional
        Temporary log level to enforce while inside the context.
        Default: logging.WARNING.
        Examples:
            logging.CRITICAL
            logging.ERROR
            logging.WARNING
            logging.INFO
            logging.DEBUG

    Usage
    -----
    with silent_logger():                     # set "trigger" logger to WARNING
        ...

    with silent_logger(level=logging.ERROR):  # force only ERROR+
        ...

    with silent_logger("urllib3", logging.CRITICAL):  # fully silence urllib3
        ...
    """
    logger = logging.getLogger(logger_name)
    old_level = logger.level
    logger.setLevel(level)
    try:
        yield
    finally:
        logger.setLevel(old_level)


#------------------------------------------------------------------------------#
def get_active_emails(limit=200):
    """
    Retrieve a list of active member emails filtered by country prefixes.

    This function:
    1. Fetches account rows from the 'accounts' table (up to `limit` entries).
    2. Removes accounts with missing `last_login`.
    3. Keeps only emails starting with CH, DE, GR, or IT (uppercase).
    4. Returns a plain Python list of emails.

    Parameters
    ----------
    limit : int, optional
        Maximum number of accounts to fetch (default: 200).

    Returns
    -------
    list of str
        List of filtered active member emails.
    """

    with TriggerDB() as db, silent_logger("trigger", level=logging.WARNING):
      rows = db.from_("accounts").limit(limit).fetch()

    df = pd.json_normalize(rows)
    df = df[~df["last_login"].isna()]
    df = df[df["email"].str.match(r"^(CH|DE|GR|IT)")]

    return df["email"].tolist()


#------------------------------------------------------------------------------#
def collect_timeseries(
    table_name,
    start_date,
    end_date,
    emails=None,
    select_columns=None,
    max_rows_per_query=5000,
    delay_ms=50,
    active_email_limit=200,
):
    """
    Collect time-series data from a TriggerDB table for multiple emails
    across a date interval.

    Parameters
    ----------
    table_name : str
        Name of the table to query. Supported datasets:
        "myair", "ecg", "ppg", "gps", "sleep",
        "smartwatchlow", "smartwatchhigh".
    start_date : datetime.date
        First (inclusive) date to fetch.
    end_date : datetime.date
        Last (inclusive) date to fetch.
    emails : list of str or None, optional
        If None, the function automatically retrieves all *active* users
        using get_active_emails(), up to the limit specified by
        `active_email_limit`.
    select_columns : list of str or None, optional
        Columns to select from the table. If None, no explicit SELECT is used
        and all table columns are returned.
        NOTE: regardless of this argument, the final output will always
        include at least:
            'email', 'userId', 'year', 'month', 'day',
            'hour', 'minute', 'second'
        and, for ECG/PPG tables, also:
            'microsecond'.
    max_rows_per_query : int, optional
        Maximum number of rows returned per (email, day) query.
    delay_ms : int or float, optional
        Delay between queries in milliseconds (to avoid hammering the server).
    active_email_limit : int, optional
        If 'emails' is None, use this limit when calling get_active_emails().

    Returns
    -------
    pandas.DataFrame
        A DataFrame containing all the concatenated results. If no data is
        found, an empty DataFrame is returned.
    """

    # -------------------------
    # Allowed tables 
    # -------------------------
    allowed_tables = {
        "myair",
        "ecg",
        "ppg",
        "gps",
        "sleep",
        "smartwatchlow",
        "smartwatchhigh",
    }

    # -------------------------
    # 0. Sanity checks & defaults
    # -------------------------
    if table_name not in allowed_tables:
        raise ValueError(
            f"Invalid table_name '{table_name}'. "
            f"Allowed values are: {sorted(allowed_tables)}"
        )

    if not isinstance(start_date, dt.date) or not isinstance(end_date, dt.date):
        raise TypeError("start_date and end_date must be datetime.date instances.")

    if start_date > end_date:
        raise ValueError("start_date cannot be after end_date.")

    # Default emails: active accounts
    if emails is None:
        emails = get_active_emails(limit=active_email_limit)
    emails = list(emails)  # in case someone passes generator/Series

    # -------------------------
    # 0b. Columns logic
    # -------------------------
    # Columns that must always be present in the final DataFrame
    required_cols = [
        "email",
        "userId",
        "year",
        "month",
        "day",
        "hour",
        "minute",
        "second",
    ]

    # ECG / PPG require also microsecond
    if table_name in {"ecg", "ppg"}:
        required_cols.append("microsecond")

    # If user specified select_columns, we ensure required columns are included
    effective_select_columns = None
    if select_columns is not None:
        # Keep user order, but guarantee all required columns are present
        existing = list(select_columns)
        missing_required = [col for col in required_cols if col not in existing]
        effective_select_columns = existing + missing_required
        # (optional) could deduplicate in case user already passed duplicates
        # effective_select_columns = list(dict.fromkeys(effective_select_columns))

    # -------------------------
    # 1. Derived objects
    # -------------------------
    days = pd.date_range(start=start_date, end=end_date, freq="D")
    total_iterations = len(emails) * len(days)

    all_dfs = []
    current_rows = 0
    current_bytes = 0

    # -------------------------
    # 2. Main extraction loop
    # -------------------------
    with TriggerDB() as db, tqdm(
        total=total_iterations,
        desc="Extracting data",
        ncols=100
    ) as pbar:

        for email in emails:
            for day in days:
                year_val = day.year
                month_val = day.month
                day_val = day.day

                # Filters specific to (email, day)
                filters = {
                    "hour":  ">=0",
                    "year":  f"={year_val}",
                    "month": f"={month_val}",
                    "day":   f"={day_val}",
                    "email": f"={email}",
                }

                # Only the query + fetch are silenced
                with silent_logger():
                    query = db.from_(table_name)

                    # Add SELECT only if user provided select_columns
                    if effective_select_columns is not None:
                        query = query.select(*effective_select_columns)

                    query = (
                        query
                        .where(**filters)
                        .limit(max_rows_per_query)
                    )

                    rows = query.fetch()

                # Process rows outside the silent_logger context
                if rows:
                    df = pd.json_normalize(rows)
                    all_dfs.append(df)

                    # Update counters
                    current_rows += len(df)
                    current_bytes += df.memory_usage(deep=True).sum()

                size_mb = current_bytes / (1024 * 1024)

                # Update progress bar
                pbar.set_postfix({
                    "rows": current_rows,
                    "MB": f"{size_mb:.2f}",
                })
                pbar.update(1)

                # Delay in *seconds* (input is ms)
                if delay_ms and delay_ms > 0:
                    time.sleep(delay_ms / 1000.0)

    # -------------------------
    # 3. Final concatenation
    # -------------------------
    if all_dfs:
        data_all = pd.concat(all_dfs, ignore_index=True)
    else:
        data_all = pd.DataFrame()

    return data_all

