# Data

This directory contains the notebook used to download TRIGGER data and the downloaded table dumps.

## Structure

``` text
data/
├── download_data.qmd
├── tidy/
├── 5min/
├── hourly/
└── daily/
```

`download_data.py` downloads all tables ending in:

- `_tidy`
- `_5min`
- `_hourly`
- `_daily`

Each table is saved as a compressed `.csv.gz` file in the corresponding subdirectory.

The downloaded data are not tracked by Git.
