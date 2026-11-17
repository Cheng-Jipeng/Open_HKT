# US calibration data audit

Audit date: 12 October 2026. This audit reads the preserved empirical package, its construction scripts and methods, and the proposed P1 inference supplied by the calibration coordinator. It does not download or revise source data. All recommendations are US-only.

## Source choice and immediate result

Use the **14 September 2026 total-corporate accounts snapshot**, together with the **NBER CPS MORG private-for-profit BA+/non-BA headcount partition and composition-adjusted wage premium**. The package itself identifies this as its preferred exhaustive compensation bridge. Fit on **1994–2022**; keep **2023–2024** as a separately labelled extension because the wage methods flag recent disclosure/topcoding changes. This choice precedes and does not depend on calibration feasibility.

The proposed baseline fails its first economic admissibility test. With `theta=1/1.61`, P1 gives `phi=1.458710–1.915073` over 1994–2022; every observation exceeds one. Extending through 2024 adds no admissible observations. This is a model/data mapping rejection, not a failed numerical solve. It should not be repaired by clipping phi, selecting a skill definition for fit, or presenting an off-literature markup as an externally supported calibration.

The companion `data_audit_feasibility.csv` covers every exhaustive skill pair in the source bridge registry: 14 headcount/FTE pairs × two corporate scopes × markups 1.61 and 1.84 = **56 specifications**. Each uses observed common years in 1994–2022. There are **zero interior phi observations in all 56 specifications**. The narrower NFC sensitivity still uses all private-for-profit CPS labor, so its sector alignment is weaker, not stronger.

## Exact input files, columns, IDs and units

All paths in this section are relative to `Empirical_Data/Variable_mappings/Empirical_Mapping_Annual/`. Read `data_intermediate` files directly to avoid inadvertently pooling duplicated/multiple vintages from the master wide panel. Annual long files use `country_or_region`, `year`, `mapping_id`, `value`, `unit`, `source_ids`, and `vintage`; filter the exact mapping ID and US geography, then assert uniqueness by year.

| Object | File | Exact mapping ID | Unit and coverage |
|---|---|---|---|
| Nominal output Y | `data_intermediate/us_corporate_external_corporate.csv` | `Y_US_AHP_TOTAL_CORP_GVA` | Million USD; complete calendar-year flows, 1990–2025 |
| Corporate compensation C | Same | `COMP_US_AHP_TOTAL_CORP` | Million USD; annual, 1990–2025 |
| Operating enterprise value Q | Same | `Q_US_AHP_ENTERPRISE_VALUE_TOTAL_CORP` | Million USD; Q4/end-year stock, 1990–2025 |
| Real-output sensitivity | Same | `Y_US_REAL_CORP_GVA` | Million 2017 USD; quarterly GDP-deflated flows summed annually, 1990–2025 |
| Skilled H | `data_intermediate/labor_wages.csv` | `H_US_COLLEGE_EQUIV` | Persons, annual average employment, 1994–2024 |
| Unskilled L | Same | `L_US_NONCOLLEGE` | Persons, annual average employment, 1994–2024 |
| Premium wH/wL | Same | `WHWL_US_CPS_COMPOSITION_ADJ_COLLEGE_NONCOLLEGE` | Ratio, 1994–2024 |
| Unscaled micro wage checks | Same | `WH_US_CPS_COMPOSITION_ADJ_COLLEGE_NONCOLLEGE`, `WL_US_CPS_COMPOSITION_ADJ_COLLEGE_NONCOLLEGE` | Nominal USD/hour, 1994–2024; wages exclude benefits |
| FTE H/L sensitivity | Same | `H_US_COLLEGE_EQUIV_FTE_OBSERVED_HOURS`, `L_US_NONCOLLEGE_FTE_OBSERVED_HOURS` | FTE at 40 usual hours/week, 1994–2024 |
| Raw-premium sensitivity | Same | `WHWL_US_CPS_RAW_MEAN_HOURLY_COLLEGE_NONCOLLEGE` | Ratio, 1994–2024 |

The corporate `vintage` is exactly `latest_official_2026-09-14`. The CPS vintage is `NBER public MORG files retrieved 2026-09-14; not AHP vintage`. Neither is a frozen AHP author vintage. The August local replication snapshot contains external accounts and should not be substituted for this corporate block.

### Original measurement sources

- **Y:** Federal Reserve Financial Accounts / IMA via FRED, quarterly `BOGZ1FU106902501Q + BOGZ1FU796902505Q`. Source IDs `FRED_BOGZ1FU106902501Q__20260914` and `FRED_BOGZ1FU796902505Q__20260914`.
- **C:** same source system, `BOGZ1FU106025005Q + BOGZ1FU796025005Q`; source IDs follow the same `FRED_{series}__20260914` convention.
- **Q:** same source system, `BOGZ1LM102010405Q + BOGZ1LM792010405Q`, sampled at Q4. This is market operating-asset value, not public-stock capitalization. The package reports exact reconciliation against independent enterprise-value reconstructions.
- **Price deflator:** BEA NIPA via FRED `GDPDEF`, 2017=100, source ID `FRED_GDPDEF__20260914`, raw path `data_raw/fed/us_corp_GDPDEF_2026-09-14.csv`, source last updated 26 August 2026. Its registry checksum is `6231e4620d155036f4cb5c511a9f045293cf48aa83b6ab1876e2efdda8281d29`.
- **Labor and relative wages:** Census/BLS CPS outgoing-rotation microdata in unchanged NBER annual MORG Stata files, source IDs `CPS_NBER_MORG_YYYY`. Example 2007 raw path `data_raw/cps/labor_nber_morg07_20260914.dta`, SHA-256 `f3593d97b5540f584e1a45e07ec21543103991730f3e8b9f57f18da27a3ab12f`. The adjusted premium additionally cites the 2007 file for composition weights.
- Exact URLs, full source-specific units, raw paths and recorded checksums are in `source_registry.csv`; exact formulas and scope are in `mapping_registry.csv`. These hashes were read from the registry, not independently recomputed over the large raw microdata in this audit.

The corporate FU inputs are **quarterly dollar flows, not SAAR**. Sum four quarters without dividing by four. GDPDEF is an economy-wide deflator, so real corporate GVA is a transparent proxy rather than an official corporate chain-volume series. The existing real output equals `sum_q Y_nominal_q/(GDPDEF_q/100)`. If using its implicit annual deflator `P_t=Y_nominal_t/Y_real_t`, deflate all annual nominal production-side quantities consistently by this same `P_t` and label that choice; it is a GVA-weighted implicit annual price, not necessarily the arithmetic annual GDPDEF mean. For Q, choose and disclose annual versus Q4 timing. Common deflation cancels from P1 feasibility and nominal ratios.

## Labor construction and compensation bridge

The common CPS population is resident employed civilians aged 16+, private-for-profit wage/salary workers (`class94=4`, employed labor-force status), excluding government, nonprofit, self-employment and unpaid-family workers. BA+ is `grade92=43–46`; non-BA is `31–42`. This pair exhausts the education universe. BA+/HS-only omits some-college, associate and less-HS workers and should not absorb all corporate compensation in the primary bridge.

Headcounts sum the stored `earnwt/12`. The data already contain the source-implied weight decimals. These are annual averages of reference-week employment, not unique persons ever employed or end-year stocks.

The composition-adjusted wages hold 2007 education-detail × six age-band × sex employment weights fixed within each skill group, multiplying them by each year's winsorized arithmetic mean hourly earnings. The premium is their ratio. Pooled private-for-profit hourly earnings use usual weekly earnings divided by valid usual main-job hours and weighted 1st/99th-percentile winsorization. This is not a regression wage premium, an actual aggregate wage-bill ratio, or a correction for topcoding.

For `r=wH/wL`, scale to annual total compensation as:

```
wL_nominal = C_million_USD * 1e6 / (r*H_persons + L_persons)
wH_nominal = r*wL_nominal
B_H = C * r*H/(r*H+L)
B_L = C * L/(r*H+L)
```

Then `B_H+B_L=C` by construction. With headcounts, scaled wages are annual compensation dollars/person. The bridge assumes the hourly relative wage also describes annual total-compensation ratios. Benefit differences, annual hours and survey/institutional coverage differences are unmodeled. Thus the identity is an accounting convention, not an independently observed model fit.

The FTE alternative excludes varying/missing usual hours; 1994–2022 valid-hours shares are 93.40%–96.28% for BA+ and 91.61%–94.52% for non-BA. FTE estimates are usual-week equivalents, not measured annual hours. The source bridge explicitly marks this pair as a sensitivity because wage averages are person-weighted. Do not silently replace missing hours with 40.

## Sector perimeter and structural interpretation

Corporate accounts combine nonfinancial corporate business with domestic financial business. The latter includes the central bank, pensions and other institutions broader than financial corporations alone. CPS private-for-profit employment still includes employees of unincorporated businesses and cannot identify the exact accounts perimeter. Its exclusion of nonprofits makes it the most appropriate available broad private labor proxy, but it is not a literal corporate-sector census.

Gross corporate value added includes depreciation, taxes and returns to omitted physical capital. In the model, the residual beyond unskilled compensation is attributed to the intermediate-production margin. Therefore an inferred phi above one may reveal this structural measurement mismatch, together with the markup restriction and compensation mapping. It does not prove that the source data are corrupt. Switching to net output or subtracting capital costs would be a new economic mapping and requires an explicit alternative specification rather than an undocumented data cleaning step.

P1 uses inferred phi. Neither direct BERD R&D labor nor NRC employment is an input to phi here. NRC∩BA/BA and BERD comparisons are valid future diagnostics but are not independent observations of the same narrow innovation object; NRC includes substantial nonresearch work.

## P1 feasibility and labor normalization

Using the proposed formula,

```
phi_t = theta * (Y_t - B_L,t) / B_H,t
theta_max,t = B_H,t / (Y_t - B_L,t)
```

all denominators are positive in these tests. Interior feasibility requires `theta < min_t theta_max,t`. The equality permits phi=1 and zero R&D, so the boundary is not an interior calibration. Neither rho nor alpha enters this rejection.

| Primary mapping, selected year | phi at markup 1.61 | Maximum theta | Minimum markup at phi=1 |
|---|---:|---:|---:|
| 1994 | 1.890082 | 0.328620 | 3.043032 |
| 2007 | 1.738265 | 0.357321 | 2.798606 |
| 2022 | 1.606185 | 0.386704 | 2.585957 |
| 2023 extension | 1.562338 | 0.397557 | 2.515365 |
| 2024 extension | 1.497827 | 0.414679 | 2.411502 |

For the whole 1994–2022 baseline, `theta < 0.3243313294591749`, or markup `>3.0832667373439007`, is needed. This is an **endogenous feasibility bound**, not literature evidence for such a markup.

Selected alternatives at the larger externally considered markup 1.84:

| Skill definition | Scope | Years | phi range | Common theta ceiling |
|---|---|---|---:|---:|
| BA+/non-BA headcount | Total corporate | 1994–2022 | 1.2764–1.6757 | 0.324331 |
| BA+/non-BA headcount | NFC | 1994–2022 | 1.2540–1.6406 | 0.331260 |
| Associate+/nontertiary headcount | Total corporate | 1994–2022 | 1.1625–1.4162 | 0.383755 |
| Associate+/nontertiary headcount | NFC | 1994–2022 | 1.1435–1.3892 | 0.391218 |
| Broad knowledge/NRC versus complement headcount | Total corporate | 2003–2022 | 1.2793–1.5227 | 0.356927 |
| Broad knowledge/NRC versus complement headcount | NFC | 2003–2022 | 1.2568–1.4911 | 0.364478 |

Education alternatives use their corresponding composition-adjusted premiums. Occupational alternatives have no composition-adjusted premium and use their matched raw hourly-mean ratio; do not label them composition-adjusted. Their samples begin in 2003 or 2011 according to code availability. Every headcount/FTE pair, exact source ID, sample, phi range and binding year is retained in the companion CSV. The selected total-corporate baseline is not superseded by these sensitivities.

For the production-path exercise, preserve observed `H_t/L_t` and the measured premium in the primary conditional inversion, and explicitly acknowledge that this relaxes the reference GE solver's constant-endowment assumption. Use a **single common labor scale**, such as `S=H_2007+L_2007`, to normalize `H_t/S` and `L_t/S`; do not normalize each skill group separately without transforming wages and declaring the change.

A fixed-endowment sensitivity can hold `H=H_2007/S`, `L=L_2007/S`, preserve the observed premium `r_t`, and recalibrate the common wage level from C. This changes the implied skill wage bills and is an explicit fixed-composition counterfactual. With the baseline sources it still yields phi 1.554517–1.928675 at markup 1.61. Conversely, fixing H/L while retaining the original skill wage bills leaves P1 phi unchanged but changes the effective wage ratio. Those effective wages must not be presented as the observed CPS premium. Neither choice fixes infeasibility.

## Evidence inspected

- `README.md`, especially definitions, corporate scope, labor partitions and the compensation bridge.
- `diagnostics/us_corporate_external_methodology.md` and `scripts/01_ahp_corporate_accounts.py` for the corporate levels, quarterly annualization and real-output transformation.
- `diagnostics/labor_wages_methodology.md`, `diagnostics/labor_wages_sample_coverage.csv`, and `data_intermediate/labor_wages_bridge_pairs.csv` for the exact labor populations, units and preferred bridge.
- `source_registry.csv`, relevant annual intermediate files, and `Nonroutine_Cognitive_README.md`.

No source re-download, new economic-data estimate, full equilibrium solve, or raw-microdata reconstruction is claimed by this audit.
