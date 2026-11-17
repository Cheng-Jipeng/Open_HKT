# Model vs data slides

Beamer deck that goes over `../On_Model_vs_Data_Failed_Dimensions.md`, mostly through figures. The PDF is `model_vs_data_slides.pdf` (19 slides).

| File | Role |
|---|---|
| `model_vs_data_slides.tex` | Source. Charts are native PGFPlots, so fonts and equations match the text and every chart can be edited here. |
| `build_slide_data.py` | Rebuilds `data/` from saved outputs. Inputs are read only. It stops if an internal check fails. |
| `data/` | One CSV per chart family, plus `overview_*.tex` and `values.tex`, which the slides `\input`. |

## Rebuild

From this folder:

```bash
uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 python -B build_slide_data.py
```

```bash
latexmk -pdf model_vs_data_slides.tex
```

## Conventions

- Blue is data and orange is model on every chart, with shades of one hue for variants of the same object.
- Three model objects appear: the AHP seed (notebook 05), the notebook 06 best point, and the R1 conditional inversion at markup 3.5. Slide 1 defines them.
- External series use the June 2026 release in `Empirical_Data/AHP_NFA`, to match the notebook 06 targets. Implied beta uses the September 2026 release. Slide 18 shows the gap.
- Slide 17 is a judgment about which change addresses which failure. It is not a solved result.
