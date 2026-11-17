# HKT calibration measurability audit — 22 September 2026

The final crosswalk covers all 35 entries in `../V6_calibration_core.tex`. Its authoritative classifications are in `measurability_rows.json`, mirrored in `../V6_calibration_measurability.csv` and the separate LaTeX/PDF report. The domain findings files are supporting working notes; their stricter preliminary classifications are not alternative final tables.

The final assessment has **5 families with directly measured statistical candidates (all conditional), 13 indirect/model-implied families, and 17 structurally latent families**. “Direct, conditional” does not certify an exact, calibration-ready HKT mapping. It names a measured economic counterpart and states the unresolved population, sector, instrument, timing, or numeraire condition. Country/component qualifications remain explicit. An accounting sum or ratio need not be model implied; an available proxy is not automatically accurate.

## What was actually checked

- Existing annual mappings, method notes, and selected raw/processed evidence under `Codes/Empirical_Data`; V6 equations and the zero-exponent computation; FinAI's SMU object-first, source-suitability and provenance guidance.
- WRDS status, dataset discovery and field/filter metadata, followed by three bounded data probes. North American Compustat returned two format variants for one company/year, with one C/INDL/STD row after local selection. Global Compustat was intentionally capped at three records and is not representative. CRSP returned twelve unique monthly observations for the requested identifier/calendar; the advertised row count of three was inconsistent with the actual twelve and is retained.
- Nineteen exact FRED series, with a saved window starting in 2024. Sixteen quarterly series end in 2026Q2, the monthly bill yield in August 2026, and two annual dividend series in 2025. The external-account NFA identity was checked in all ten sampled quarters.
- Two exact Eurostat API samples: German education-defined employment and R&D GFCF, 2021–2023. All dimensions, six observations, and break/provisional flags were retained.
- Two OpenEcon requests. Both returned a different concept from the one requested; neither substitution was accepted. Exact-source retrieval supplied the accepted evidence. Direct OECD HTTP403 and initial failed routes are documented as access-route results, not evidence that the economic series is absent.

This is a feasibility audit, not a full historical data refresh, source entitlement guarantee, parameter estimate, or numerical equilibrium run. Existing model and empirical baselines were not edited. Official releases can revise history; reproducing a live request later may produce a different vintage.

## Material mapping findings

1. The current liability stock `ROWEINQ027S` / `FL263081005` and the earlier revaluation choice `FR263081115` have different investment-fund coverage. The broad versus narrower 2026Q2 revaluations differ by 202,800 million USD. Reconcile stock, transaction, valuation and other-change universes together before using the resulting price index. No automatic series replacement was made.
2. `RWNEOWQ027S` is ROW net-worth **revaluation**, not financial transactions. US total valuation is its negative. `RWLBACQ027S` is ROW net lending/borrowing at an annual rate; its negative divided by four is a quarterly CA candidate only after capital-account/statistical reconciliation.
3. National saving/DPI does not measure the model's cohort asset-acquisition/labor-income propensity. R&D expenditure does not measure research labor or augmentation. NRC/total employment has the wrong denominator for the model's research share; even a matched NRC/skilled-labor share remains a substantive proxy.
4. Corporate GVA, compensation, enterprise value, shareholder capitalization, FCF, operating profits and paid dividends are distinct objects. Access to all of them does not settle the model's output, funding and equity-cash-flow bridges.

## File map

- `build_tables.py`: reviewed row definitions and deterministic report builder; no network calls.
- `measurability_rows.json`: final 35-entry crosswalk with stable IDs M01–M35.
- `source_ledger.json`: 14 source families, exact identifiers, URLs and verification status.
- `production/`: labor/knowledge audit, raw OpenEcon and official API responses, six accepted Eurostat observations, probe script and validation.
- `external/`: raw exact FRED CSVs, OpenEcon response, source metadata, query logs, spot checks, scripts and validation.
- `wrds/`: native selected-field MCP exports, manifests, OPTIONS/search/query receipts and independent bounded-sample checks. WRDS column projection is local; the exports are not a new complete national or firm panel.
- `structural/`: preference/regime assessment and FinAI workflow pointers.
- `../build/measurability/`: LaTeX intermediates, rendered QA pages and final document validation.

## Rebuild from saved evidence

From `Codes/Calibration_R1`:

```sh
python3 measurability_evidence/build_tables.py
/Library/TeX/texbin/latexmk -norc -pdf -interaction=nonstopmode -halt-on-error -outdir=build/measurability V6_calibration_measurability.tex
cp build/measurability/V6_calibration_measurability.pdf V6_calibration_measurability.pdf
```

The builder writes TeX, CSV and JSON only; it neither re-estimates the model nor refreshes data. Raw HTTP scripts and request receipts document live reproduction separately. Preserve this audit snapshot before rerunning a script that refreshes its own evidence directory. No credentials are stored in this package; WRDS queries use the configured local MCP connection.

The next measurement decision should specify the model period, US/RoW sector/geographic universe, skill and labor units, equity/fund/FDI perimeter, safe-bond aggregation, and output/valuation accounting. Those decisions determine which conditional candidates can become calibration targets.
