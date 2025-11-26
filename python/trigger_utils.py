import pandas as pd
from trigger import TriggerDB
import logging
from contextlib import contextmanager

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

    with TriggerDB() as db:
        rows = db.from_("accounts").limit(limit).fetch()

    df = pd.json_normalize(rows)
    df = df[~df["last_login"].isna()]
    df = df[df["email"].str.match(r"^(CH|DE|GR|IT)")]

    return df["email"].tolist()


@contextmanager
def silent_logger(logger_name: str = "trigger"):
    """
    Context manager that temporarily silences a specific logger.

    Parameters
    ----------
    logger_name : str, optional
        Name of the logger to silence.
        Defaults to "trigger", which is the logger used by TriggerDB.

    Usage
    -----
    with silent_logger():             # silences "trigger"
        ...

    with silent_logger("urllib3"):    # silences urllib3 logs
        ...

    with silent_logger("custom"):     # silences any logger
        ...
    """
    logger = logging.getLogger(logger_name)
    old_level = logger.level
    logger.setLevel(logging.CRITICAL)
    try:
        yield
    finally:
        logger.setLevel(old_level)

