# Setup

## 1. Create the Python virtual environment

From the project root:

``` bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

## 2. Register the Jupyter kernel

With `.venv` active:

``` bash
python -m ipykernel install       --user       --name trigger-analyses       --display-name "Python (trigger-analyses)"
```

The Quarto notebooks select this environment with:

``` yaml
jupyter: trigger-analyses
```

You can verify the registered kernels with:

``` bash
jupyter kernelspec list
```

## 3. Optional: use the same Python from RStudio and reticulate

This is required only for notebooks that mix R and Python chunks through `knitr` and `reticulate`.

Copy the example file:

``` bash
cp .Renviron.example .Renviron
```

Then replace the placeholder with the absolute path to the project Python:

``` text
RETICULATE_PYTHON=/absolute/path/to/trigger-analyses/.venv/bin/python
```

Restart RStudio after creating or editing `.Renviron`.

`.Renviron` is ignored by Git because the path is specific to each computer.

## 4. Render the example notebook

Open `notebooks/00_pytrigger.qmd` in RStudio and use **Render**.

The notebook uses the Jupyter kernel named `trigger-analyses`, which points to `.venv/bin/python`.
