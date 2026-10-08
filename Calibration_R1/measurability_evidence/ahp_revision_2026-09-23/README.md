# AHP measurement-transfer check

This dated addition supports the revised measurability report. The review distinguishes measured accounting targets from the structural interpretation used to fit them.

## Source locations

- AHP Section I, journal pp. 2155–2165: external accounts and corporate value/cash-flow concepts.
- AHP Section III, pp. 2174–2176: constructs data first, then identifies parameter paths with the model.
- AHP Appendix A1, pp. 2192–2194: positions, CA, revaluation, non-equity residuals and reconciliation.
- AHP Appendix A2–A3, pp. 2194–2198: corporate GVA, FCF, earnings and enterprise value.
- AHP Appendix A4, pp. 2198–2199: ownership fractions and the foreign monetary-dividend yield without a measured full-world enterprise value.
- AHP Appendix A5, pp. 2199–2200: OECD corporate counterparts, geographic aggregation and country-specific proxies.
- V6 labels `country_stock_aggregation`, `country_labor_income`, `country_ipo_transfer`, and `country_output_income_identity`: the issuance/cash-flow timing behind the remaining V6 bridge.

The supplied paper is a transcription of the published article, not the authors' original TeX. Its marked typographical inconsistencies were not imported into the measurement equations. The separate Supplemental Appendix and original author workbook are outside the supplied source.

## Files

`verify_ahp_mappings.py` verifies saved external and corporate data and builds the new bounded yield sample. `validation.json` records numerical results. `verified_2008_2023_moments.csv` contains the independently recomputed saved-vintage targets. `raw/` contains three unmodified official FRED CSV responses; `query_log.json` records URLs, units via the documented series definitions, dates and hashes. `openecon_receipt.json` records the failed discovery route. `ahp_foreign_dividend_yield_probe.csv` retains the monetary payout, denominator and both quarterly and simple annualized yields.

Exact new payout source: https://fred.stlouisfed.org/series/B3375C1Q027SBEA . It is BEA account B3375C, NIPA Table 4.1 line 11, quarterly billions of dollars at a seasonally adjusted annual rate. Quarterly monetary receipts in million USD are the source value times 1000/4. The yield denominator is lagged US-held foreign equity plus current revaluation of those holdings, following AHP Appendix A4. The raw sample starts in 2023Q4 to provide the lag for 2024Q1.

The resulting yield is an AHP-style monetary-payout statistic. It is not an estimate of a latent discount rate, a pure-price-only return, or a completed alignment of all V6 instrument and payout conventions. The existing corporate and AHP_NFA panels retain their respective vintages; the new yield uses only the three jointly probed series.

`baseline_hashes.json` records source/data files before the revision. The original report is archived one directory above under `archive/2026-09-22/`.
