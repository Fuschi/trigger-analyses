# Setup

## Python environment

Python is used only by `data/download_data.py`. Follow the [data instructions](../data/README.md) to create `.venv`, install `pytrigger`, and download the local datasets. The R analyses do not use `reticulate` or the Python environment.

## R packages

Install the packages used by the analyses:

```r
install.packages(c("tidyverse", "ComplexUpset", "ThermIndex", "hexbin", "knitr", "mgcv", "patchwork", "quarto", "scales", "viridisLite"))
```

Open `trigger-analyses.Rproj` in RStudio after installing the packages. Local Python and R session files are excluded from Git.
