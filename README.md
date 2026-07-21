# trigger-analyses

Reproducible analyses of wearable and environmental data collected in LongCLAVIS within the European TRIGGER project.

## Workflow

1. Configure the local R and Python environment.
2. Download the TRIGGER table dumps into `data/`.
3. Run analyses from the local files only.
4. Save generated results under `outputs/`.
5. Render analysis notebooks to HTML and GitHub Markdown.

## Project structure

```text
trigger-analyses/
├── data/          # download workflow and local table dumps
├── docs/          # setup, workflow and rendering documentation
├── notebooks/     # version-controlled analysis notebooks
└── outputs/       # locally generated analysis results
```

## Documentation

- [Setup](docs/SETUP.md)
- [Analysis workflow](docs/WORKFLOW.md)
- [Rendering notebooks](docs/RENDERING.md)
- [Data directory](data/README.md)
