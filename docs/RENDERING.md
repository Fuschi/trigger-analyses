# Rendering notebooks

Analysis notebooks are rendered in both HTML and GitHub Markdown.

From the R console, render HTML first and GFM second:

```r
quarto::quarto_render(output_format = "html")
quarto::quarto_render(output_format = "gfm")
```

Do not use `output_format = "all"`: the self-contained HTML render may remove
the figure directory required by the Markdown output.

Project-wide rendering includes only:

```yaml
project:
  render:
    - notebooks/*/*.qmd
```

`data/download_data.py` is excluded from the Quarto rendering workflow.
Run it manually from the project root with:

```bash
python data/download_data.py
```
