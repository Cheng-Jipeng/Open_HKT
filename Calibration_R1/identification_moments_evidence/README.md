# V6 identifying-moment audit

The deliverable is the standalone `../V6_parameter_identifying_moments.tex` and its compiled PDF. It preserves the authoritative A/B/C taxonomy and all 17 parameter families (30 scalar fields), using three columns. Existing model, solver and calibration documents were not changed.

- `source_hashes.json`: input snapshot hashes; the artifact validator verifies preservation.
- `production_analysis.md` and `.json`: production/technology derivations and source crosswalk.
- `preference_finance_moments.md`: saving, portfolio and transition conditions and rank qualifications.
- `route_reconciliation_memo.md`: measurement routes and distinctions between the supplied literature reviews.
- `check_production_formulas.py` and `check_preference_finance_formulas.py`: reproducible synthetic algebra checks (15 and 11 respectively). Their JSON results are not estimates, data results or full equilibrium solutions.
- `validate_artifact.py`: checks coverage against the authoritative table, unchanged source hashes, PDF page/outline coverage, page bounds and LaTeX diagnostics. `artifact_validation.json` records the result.

Compile from the Calibration_R1 directory with:

```sh
/Library/TeX/texbin/latexmk -norc -pdf -interaction=nonstopmode -halt-on-error -synctex=1 -outdir=build/identifying_moments V6_parameter_identifying_moments.tex
cp build/identifying_moments/V6_parameter_identifying_moments.pdf V6_parameter_identifying_moments.pdf
```

The final source also compiled successfully with the desktop editor's compiler. All eight pages were rendered and visually checked; modified pages were re-rendered and rechecked. Two harmless underfull paragraph warnings remain; there are no overfull boxes, unresolved references, duplicate destinations or compilation errors.

Important interpretation: exact variety stocks remain unmeasured. Active-entry and production restrictions can nevertheless eliminate them from some conditional moment routes. Conversely, exact accounting measurement does not establish identification of utility/friction parameters. The parameter for regime persistence has no direct column in GMM moments evaluated solely on fixed observed returns; it requires transition evidence or an explicit parameter-dependent return distribution/payoff system.
