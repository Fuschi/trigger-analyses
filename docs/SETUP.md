# Setup

## Python environment

From the project root:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

## R packages

Install the packages used by the current notebooks:

```r
install.packages(c("reticulate", "tidyverse", "quarto"))
```

## Connect RStudio to the project Python

Copy the environment example:

```bash
cp .Renviron.example .Renviron
```

Set the absolute path to the virtual environment:

```text
RETICULATE_PYTHON=/absolute/path/to/trigger-analyses/.venv/bin/python
```

Restart RStudio, open `trigger-analyses.Rproj`, and verify the configuration:

```r
reticulate::py_config()
```

`.Renviron` and `.venv/` are local files and are not tracked by Git.
