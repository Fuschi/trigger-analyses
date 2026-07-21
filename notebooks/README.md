# Notebooks

Each analysis lives in its own numbered directory:

```text
notebooks/01_example/01_example.qmd
```

Analysis notebooks must:

- read input data from `data/`;
- avoid direct API downloads;
- save generated files under the matching `outputs/<notebook_id>/` directory.
