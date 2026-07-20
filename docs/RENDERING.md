# Rendering notebooks

The project renders notebooks in both HTML and GitHub Markdown.

Run HTML first and GFM second:

```r
quarto::quarto_render(output_format = "html")
quarto::quarto_render(output_format = "gfm")
```

Do not use:

```r
quarto::quarto_render(output_format = "all")
```

because the HTML render may delete the `*_files` directory containing the figures required by the Markdown output.

Notebook sources are selected in `_quarto.yml` with:

```yaml
project:
  render:
    - notebooks/*/*.qmd
```
