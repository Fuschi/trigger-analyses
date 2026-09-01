# Data

This directory contains the Python downloader and the downloaded TRIGGER table dumps.

## Python environment

From the project root, create the environment and install the dependencies:

``` bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

The requirements install a pinned revision of [pytrigger](https://github.com/Nico-Curti/pytrigger), whose Python package is imported as `trigger`.

For later sessions, only activate the existing environment:

``` bash
source .venv/bin/activate
```

Optionally verify the installation:

``` bash
python -c "from trigger import TriggerDB; print('pytrigger is available')"
```

## Download the data

From the project root, with `.venv` active:

``` bash
python data/download_data.py
```

On first use, `pytrigger` requests the TRIGGER account email and password and stores them locally under `~/.config/pytrigger/`. Credentials must never be added to this repository.

The script downloads the current server-side dumps and writes a summary to `data/download_log.csv`. Check the final summary and investigate both `error` and unexpected `empty` statuses before analysis.

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

The `accounts` and `active_accounts` tables are retrieved separately through the API selection endpoint when available.

Each table is saved as a compressed `.csv.gz` file in the corresponding subdirectory.

The downloaded data and download log are not tracked by Git.
