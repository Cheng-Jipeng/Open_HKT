# Calibration procedure slides

This 16-page presentation expands the single calibration figure into one page per step or diagnostic phase of the **2009–2024, rho=2** run. Editable PowerPoint charts contain embedded copies of the plotted numeric series. The PDF contains the same slide pages.

Final files are in `output/`. `build_deck.mjs` authors the presentation. `prepare_slide_data.py` reads the saved calibration outputs and derives plotted transformations without changing data or refitting the model. Speaker notes identify equations, input files, literature, units and interpretation limits. The original overview figure remains available in `../results/figures/`.

## LaTeX version

`latex/calibration_steps_2009_2024.tex` is a self-contained Beamer presentation with the same 16 phases, 28 native PGFPlots charts, typeset equations and three parameter tables. Page 7 includes `X/Y` and `L/Y` above the coefficient and augmentation panels. All coordinates are embedded, so compiling or editing the source requires no external figures, data files, bibliography or PowerPoint. Detailed source notes from the prior deck are retained as comments above each frame. Literature citations are linked on the specification slide. The compiled deliverable is `output/calibration_steps_2009_2024_latex.pdf`.

The source compiles in the Codex LaTeX editor, or with TeX Live / MacTeX using Beamer, Latin Modern, AMS math, TikZ and PGFPlots. To build from the repository root:

```sh
cd Codes/Calibration_R1/Do/Slides/latex
latexmk -norc -pdf -interaction=nonstopmode -halt-on-error -outdir=../.build/latex calibration_steps_2009_2024.tex
cp ../.build/latex/calibration_steps_2009_2024.pdf ../output/calibration_steps_2009_2024_latex.pdf
```

The relative filename avoids latexmk restrictions on characters in the iCloud parent path. `latex/build_latex.py` regenerates the source from the frozen `.build/slide_data.json` and the prior PowerPoint source notes; it verifies source hashes and does not refit the model. Run it only when you intend to replace manual edits to the generated `.tex`. Compilation alone does not regenerate the source. This version uses `\vartheta` for the inverse markup and `\phi` for the production allocation; numerical results are unchanged.

## Page sequence

1. Corporate output, compensation and valuation inputs
2. Labor quantities, skill premium and the wage bridge
3. External parameters and normalizations
4. Step 1, P1: production and research allocation
5. Step 2, P2: innovation productivity
6. Step 3, P2: knowledge growth and accumulation
7. Step 4, P4: effective CES coefficients
8. Step 5, P5: sequential spillover estimates
9. Step 6: sequential productivity-scale intercepts
10. Joint minimum-distance production fit
11. Targeted fit and an untargeted cash-flow check
12. Spillover restriction mechanism
13. Mapping and counterfactual comparisons
14. Constrained spillover diagnostic
15. Optional P3 route with a free inverse markup
16. Parameter ledger and the run's economic status

The first six steps follow the equations in the referenced *Evaluate Calibration Strategy* conversation, checked against `Plan/V6_parameter_identifying_moments.tex` and the executed code. P3 is an alternative identification route rather than an extra independent moment after fixing markup. Sequential estimates and joint estimates are labelled separately. The baseline fails P1. Later fitted results use the higher-markup diagnostic and retain their failed primitive restrictions.

## Reproduction

From the repository root, use the existing calibration Python environment and the bundled presentation Node runtime:

```sh
python Codes/Calibration_R1/Do/Slides/prepare_slide_data.py
node Codes/Calibration_R1/Do/Slides/build_deck.mjs --render-all
node Codes/Calibration_R1/Do/Slides/build_deck.mjs --finalize-only
```

On this Mac the installed runtimes are provided by Codex's workspace dependencies. The builder accepts `CALIBRATION_NODE_MODULES`, `CALIBRATION_PYTHON`, `CALIBRATION_PRESENTATION_SKILL`, and `CALIBRATION_SOFFICE` environment overrides for another installation. PDF conversion uses the installed LibreOffice renderer on the finalized PowerPoint file. Use `CALIBRATION_DECK_NAME` to select a new output stem for a revision. The finalizer preserves existing final files.

The authoring canvas is 1600 × 900, in 16:9 proportions. Arial is the chosen installed font. All data charts, tables and text are native editable PowerPoint objects. Chart workbooks are snapshots of the complete literal series supplied by this build, not live links to the calibration CSVs. Their values use 12 significant digits to respect Excel precision. The source JSON and calibration CSVs retain full numeric precision. Before validation, `set_chart_interpolation.py` makes straight segments explicit in the native chart XML because the exporter omits the series-level smoothing setting. It does not alter chart data or rasterize any content.

The dated explanatory text assumes this sample, rho, central markup and normalizations. The preparation script rejects incompatible settings so a later run cannot silently inherit stale slide language. To present another configuration, update that text and its guard together.

Input hashes, derived series, slide previews and validation records remain in `.build/`. They are build material rather than additional slide deliverables.
