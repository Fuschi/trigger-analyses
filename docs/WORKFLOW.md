# Analysis workflow

## 1. Download or refresh the data

Run `data/download_data.qmd` manually from RStudio. It downloads all available
`tidy`, `5min`, `hourly`, and `daily` dumps into their corresponding folders.

The downloader is the only notebook that accesses the TRIGGER API.

## 2. Analyse local files

Analysis notebooks must read from the files already stored under `data/`:

```text
data/tidy/
data/5min/
data/hourly/
data/daily/
```

This separates data acquisition from analysis and makes each analysis
repeatable without additional API requests.

## 3. Save generated results

Each notebook should write tables, figures, and intermediate results to a
matching folder under `outputs/`:

```text
notebooks/01_example/01_example.qmd
outputs/01_example/
```

Downloaded data and generated outputs are ignored by Git. Notebook sources and
rendered notebook documents remain version controlled.
