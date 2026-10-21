# HKT calibration measurability audit — AHP revision, 23 September 2026

The report covers all 35 grouped entries in `../V6_calibration_core.tex`. `build_tables.py` is the authoritative builder; reviewed definitions are mirrored in `measurability_rows.json`, `../V6_calibration_measurability.csv`, and the LaTeX/PDF. The original 22 September report and definitions are preserved in `archive/2026-09-22/`. Older domain findings are supporting working notes, not the current classifications.

## Revised classification

The current assessment contains **7 D, 6 I, 17 L, and 5 D/I families**. D includes transparent accounting calculations; a model simplification does not make an independently constructed empirical target latent. D/I identifies distinct components within a grouped entry, rather than a fourth measurement category. Country/population qualifications remain explicit.

Changes following the user's review and the supplied AHP paper:

- M28, aggregate labor income: I to D for the specified employee-compensation counterpart.
- M34, equity valuation effects: I to D for observed IMA revaluations and their signed sum.
- M35, CA and NFA changes: I to D under the explicit AHP accounting convention.
- M22, portfolio weights: D/I, separating a conditionally constructible US weight from the missing full-RoW denominator.
- M27, skill wages: D/I, making the existing distinction between directly measured US earnings and unmatched RoW wage levels explicit in the class column.
- M29, prices/dividends: D/I, separating observed price-growth and yield moments from per-variety levels.
- M30, value/cash flow: D/I, recognizing AHP EV/FCF as directly constructed targets while retaining the V6 investment/issuance payout bridge.
- M32, bonds: D/I, separating measurable net non-equity positions/flows from the single-safe-bond interpretation.

AHP's ownership ratio is an issuer ownership fraction, not V6's foreign investor portfolio weight. AHP does not directly measure the full RoW enterprise-value level in Appendix A4. AHP's investment-goods price Q, human wealth H, and time preference rho are not the identically lettered V6 quantities.

## What was verified

**AHP revision.** Read the user-supplied `Codes/Reference/Atkeson_2025_End_of_Privilege.tex`, especially Section I, Section III, and Appendix A1–A5. References use journal page numbers. Compared AHP with V6's capitalization, dividend and IPO-transfer identities and Notebook 06's empirical targets. The separate Supplemental Appendix and original author workbook were not obtained; current data are not represented as author-vintage data.

The revision independently reproduces all 145 saved quarterly external observations (1990Q1–2026Q1) for the checked definitions and the 2008Q1–2023Q3 target moments. It reconstructs 36 annual observations each of US corporate GVA, compensation, EV and FCF (1990–2025) from the saved quarterly components, with zero differences from the existing annual mappings. Residual closure is algebraic, not an independent model-fit test.

A new bounded probe retrieves exact FRED B3375C1Q027SBEA (NIPA Table 4.1 line 11), ROWEISQ027S, and BOGZ1FR263181105Q. The dividend series is in billion USD at SAAR; multiply by 1000/4 for quarterly million USD. Three 11-observation samples, including the opening 2023Q4 position, support ten quarterly AHP-style foreign monetary-yield observations through 2026Q2. OpenEcon timed out; its receipt is retained. The official-source CSV requests succeeded. Tax-repatriation spikes and matching payout/instrument coverage remain conditions.

**Preserved 22 September audit.** Three bounded WRDS probes (Compustat North America, Global and CRSP), 19 exact FRED series, and two exact Eurostat samples remain unchanged. The intentionally capped Compustat Global sample is not representative. CRSP's advertised count differed from the actual twelve requested calendar months. The two earlier OpenEcon concept substitutions were rejected; direct-source retrieval supplied usable evidence. Route failures do not establish that a series is unavailable.

## Substantive mapping conditions

1. AHP's financing-neutral operating-asset valuation is a legitimate maintained interpretation for a model with fully equity-financed firms. V6's incumbent dividends and new-variety financing nevertheless require an explicit payout/issuance bridge. The illustrative FCF-plus-investment relation in the PDF is conditional, not a verified empirical identity.
2. Reported equity valuation is observable without separately identifying claim counts and prices. The narrower liability revaluation and broader stock still differ in investment-fund coverage; reconcile the series universe before adopting that particular price index. No baseline series was replaced.
3. AHP defines its CA counterpart from negative ROW net lending divided by four. A separate balance-of-payments CA measure remains an alternative. Keep non-equity revaluation, other-volume changes and statistical discrepancies in the empirical reconciliation.
4. Net non-equity positions and CA-closing non-equity flows are both measured constructions. Their difference is economically meaningful; they cannot both be equated to one valuation-free bond process without a restriction.
5. OECD country panels are not the entire RoW. Preserve Canadian/Japanese corporate-GVA proxies, financial-sector scope, exchange-rate conventions, and the unresolved author-code sign interpretation of OECD net financial worth.

## File map and reproduction

- `build_tables.py`: deterministic, offline report builder.
- `measurability_rows.json`, `source_ledger.json`: current 35-entry crosswalk and 16 source families.
- `ahp_revision_2026-09-23/`: new probe script, raw CSVs, request/response receipts, verified moments, yield construction and validation.
- `production/`, `external/`, `wrds/`, `structural/`: preserved first-audit evidence and working notes.
- `archive/2026-09-22/`: earlier delivered report and definitions.
- `../build/measurability/`: LaTeX intermediates, rendered QA pages and current document validation.

From `Codes/Calibration_R1`:

```sh
python3 measurability_evidence/build_tables.py
/Library/TeX/texbin/latexmk -norc -pdf -interaction=nonstopmode -halt-on-error -outdir=build/measurability V6_calibration_measurability.tex
cp build/measurability/V6_calibration_measurability.pdf V6_calibration_measurability.pdf
```

Run `ahp_revision_2026-09-23/verify_ahp_mappings.py` with the bundled Python runtime for offline numerical checks; add `--download` only to refresh this revision's three bounded probe files. Preserve the snapshot before refreshing: official releases revise history. No empirical baseline, reference paper, model source or calibration notebook was changed, and no model estimation was run.
