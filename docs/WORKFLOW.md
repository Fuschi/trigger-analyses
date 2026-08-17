# Analysis workflow

## 1. Download or refresh the data

Run the downloader from the project root:

```bash
python data/download_data.py
```

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
```

This separates data acquisition from analysis and makes each analysis
repeatable without additional API requests.

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
