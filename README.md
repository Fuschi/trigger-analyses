# trigger-analyses

Reproducible analyses of wearable and environmental data collected in LongCLAVIS within the European TRIGGER project.

## Workflow

1.  Configure the local Python and R environments.
2.  Download the TRIGGER table dumps into `data/`.
3.  Write analyses as Quarto notebooks under `analyses/`.
4.  Render the notebooks as self-contained HTML files.

Analysis notebooks use local data only. API access is isolated in `data/download_data.py`.

## Analysis conventions

The five-minute bucket is the common temporal unit used across data streams. For coverage and availability, one or multiple raw measurements for the same participant and variable within a five-minute bucket count as one observed bucket.

Unless an analysis explicitly defines a different period, only records with a date strictly after 2025-03-01 and strictly before the current date are included. Earlier records belong to the testing phase, while the current day may still be incomplete.

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
- [Data directory](data/README.md)
