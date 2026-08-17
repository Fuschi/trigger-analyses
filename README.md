# trigger-analyses

Reproducible analyses of wearable and environmental data collected in LongCLAVIS within the European TRIGGER project.

## Workflow

1.  Configure the local Python and R environments.
2.  Download the TRIGGER table dumps into `data/`.
3.  Write analyses as Quarto notebooks under `analyses/`.
4.  Render the notebooks as self-contained HTML files.

Analysis notebooks use local data only. API access is isolated in `data/download_data.py`.

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
