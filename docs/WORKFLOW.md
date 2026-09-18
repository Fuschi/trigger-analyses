# Analysis workflow

## 1. Download or refresh the data

Follow the complete [data download instructions](../data/README.md).

It downloads the available `tidy`, `5min`, `hourly`, and `daily` dumps into
their corresponding folders. The downloader is the only project component
that accesses the TRIGGER API.

## 2. Analyse local files

Analyses must read from the files already stored under `data/`:

```text
data/tidy/
data/5min/
data/hourly/
data/daily/
data/accounts/
```

This separates data acquisition from analysis and makes each analysis
repeatable without additional API requests.

Load the shared readers in the notebook setup chunk:

```r
library(tidyverse)
source("R/read_data.R")
cfg <- list(data_dir = "data", analysis_start_date = as.Date("2025-03-01"))
```

Read one original wide table, optionally selecting original columns:

```r
myair_daily <- read_trigger_table("myair_daily", data_dir = cfg$data_dir)
accounts <- read_trigger_table("active_accounts", data_dir = cfg$data_dir,
                               columns = c("userId", "nationality"))
```

The reader preserves the selected original columns, units and missing measurement
values. IDs remain character and timestamps use UTC. All readers accept
`start_date` (default `as.Date("2025-03-01")`) and `end_date` (default today in UTC).
Measurement dates must be strictly between these bounds; missing dates are excluded.
Account tables are not filtered by date. No deduplication or caching is applied.
Apply other analytical rules explicitly after import.

## 3. Write the analysis

Keep each analysis in one Quarto source file under `analyses/`:

```text
analyses/example.qmd
```

Keep the workflow linear: import the local data, construct the analytical
dataset, describe the relevant coverage, and present the results. Avoid writing
intermediate tables or figures unless an analysis explicitly requires a
separate deliverable.

## 4. Render the analysis

Render the `.qmd` file to a self-contained `.html` file in the same directory.
Only Quarto sources and HTML reports are version controlled. Downloaded data
remain local and are ignored by Git.
