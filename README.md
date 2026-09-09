# trigger-analyses

Reproducible analyses of environmental, wearable, GPS, and sleep data collected in LongCLAVIS within the European TRIGGER project.

## Workflow

1.  [Configure the local Python and R environments](docs/SETUP.md).
2.  [Download or refresh the TRIGGER table dumps](data/README.md) in `data/`.
3.  Write analyses as Quarto notebooks under `analyses/`.
4.  Render the notebooks as self-contained HTML files.

Analysis notebooks use local data only. API access is isolated in `data/download_data.py`.

## Analysis conventions

The five-minute bucket is the common temporal unit used across data streams. For coverage and availability, one or multiple raw measurements for the same participant and variable within a five-minute bucket count as one observed bucket.

Unless an analysis explicitly defines a different period, only records with a date strictly after 2025-03-01 and strictly before the current date are included. Earlier records belong to the testing phase, while the current day may still be incomplete.

Technical cleaning and key uniqueness belong to the upstream ETL; notebooks use the tables without structural checks or deduplication. Study dates, exploratory thresholds and model-specific inclusion rules remain analysis decisions.

Each notebook imports complete tables under their original names (e.g. `myair_5min`) only if absent from the current R environment. Analysis objects are selected and filtered separately. After refreshing a dump, remove its object (e.g. `rm(myair_5min)`) to reload it on the next run. Reuse applies within one R session, not across separate Quarto renders; keeping full tables in memory increases RAM use.

## Project structure

``` text
trigger-analyses/
├── analyses/      # Quarto sources and self-contained HTML reports
├── data/          # downloader and local table dumps
└── docs/          # setup, workflow and rendering documentation
```

## Documentation

- [Setup](docs/SETUP.md)
- [Analysis workflow](docs/WORKFLOW.md)
- [Rendering analyses](docs/RENDERING.md)
- [Downloading and storing data](data/README.md)
