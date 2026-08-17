# Data

This directory contains the Python downloader and the downloaded TRIGGER table dumps.

## Structure

``` text
data/
├── download_data.py
├── tidy/
├── 5min/
├── hourly/
├── daily/
└── accounts/
```

`download_data.py` downloads all tables ending in:

- `_tidy`
- `_5min`
- `_hourly`
- `_daily`

The `accounts` and `active_accounts` tables are retrieved separately through
the API selection endpoint when available.

Each table is saved as a compressed `.csv.gz` file in the corresponding subdirectory.

The downloaded data are not tracked by Git.
