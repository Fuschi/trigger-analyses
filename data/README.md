# Data downloads

Run from the repository root with the project `.venv` active:

``` bash
python data/download_trigger.py
python data/download_utci.py
```

- `download_trigger.py`: downloads `_tidy`, `_5min`, `_hourly`, `_daily` tables and `accounts`/`active_accounts` via `pytrigger`; writes `data/download_log.csv`.
- `download_utci.py`: retrieves hourly UTCI for Augsburg, Bologna, Geneva and Heraklion from 2025-01-01 through the latest approximately available date (today minus 5 days). Replaces each `data/shared/utci/UTCI-<City>.csv` only after validating its hourly coverage. Original UTCI units are Kelvin; timestamps are UTC.

## Setup

``` bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

Include `cdsapi>=0.7.7` in `requirements.txt` alongside `pytrigger` and `pandas`.

For Copernicus, obtain the personal access token at <https://cds.climate.copernicus.eu/profile> and create `~/.cdsapirc`:

``` yaml
url: https://cds.climate.copernicus.eu/api
key: YOUR_PERSONAL_ACCESS_TOKEN
```

``` bash
chmod 600 ~/.cdsapirc
```

Accept the dataset licence at <https://cds.climate.copernicus.eu/datasets/derived-utci-historical-timeseries?tab=download> before downloading. `pytrigger` stores its credentials in `~/.config/pytrigger/`. Do not commit credentials or downloaded datasets.
