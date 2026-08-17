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

Install the packages used by the analyses:

```r
install.packages(c("tidyverse", "ComplexUpset", "ThermIndex", "mgcv", "hexbin", "knitr", "quarto"))
```

Python is used only by `data/download_data.py`; the R analyses do not require
`reticulate` or a connection to the Python virtual environment.

Open `trigger-analyses.Rproj` in RStudio after installing the R packages.
The `.venv/` directory remains local and is not tracked by Git.
