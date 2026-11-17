# Production and labor measurability audit

Audit date: 22 September 2026. This is a measurement-feasibility review of 19 grouped entries in `V6_calibration_core.tex`, not a new calibration. The machine-readable candidate table cells are in `production_entries.json`. All source/model artifacts were read only.

## Classification rule and conclusion

I have applied a strict model-object test: D means that the defined empirical object can be obtained from observations and ordinary aggregation without imposing the equilibrium relation; I means a conditional empirical construction, measurement bridge, normalization or model reconstruction; L means a structural coefficient lacking an independent empirical observation. An I classification does **not** certify a weak proxy as an accurate mapping. The limitation cell states which additional bridge is necessary.

Under this strict current-specification rule, the 19 rows comprise nine L and ten I entries. There are directly measured *components* (education employment, earnings, corporate GVA, security prices, paid dividends), but their equality to the current model entries has not been established. In a presentation using a looser convention, H/L and Y may be labelled D conditional on explicitly adopting the operational labor/sector definitions; that should not erase the unresolved corporate/cohort and accounting differences. Split a grouped entry when its components differ in status.

The most consequential conclusions are:

- Factor-augmentation scales and elasticities remain structurally latent. Neither industry labor productivity, R&D capital, investment growth nor a direct expenditure contribution to GDP measures either augmentation.
- The CES inversion gives model-implied augmentation conditional on curvature, markup, distribution weights, and matched production-labor prices/quantities. Its output cannot then be used as independent validation of those same parameters.
- `a_i` remains structural. Existing free-entry-implied `a_t` is useful as a conditional consistency diagnostic; it relies on the same valuation and knowledge mappings, and does not independently identify constant research productivity.
- Skill shares are not research shares. NRC work is broader than innovation. The denominator of research allocation is H, and the numerator must be inside the same H population.
- The model output identity Y=e+D-I requires an explicit national-accounts bridge. BEA capitalizes R&D investment; output and corporate compensation cannot simply be spliced into the model while ignoring this difference.
- Country coverage is an economic restriction. Existing RoW comparisons are often G4 or OECD-ex-US; those labels must remain visible.

## Live evidence: exact data returned

Two direct official Eurostat API samples were retrieved successfully at 2026-09-22 08:08 UTC. Responses are saved unchanged with request URLs and SHA256 checksums in `query_log_20260922T080846Z.json`.

| Dataset / selection | 2021 | 2022 | 2023 | Exact interpretation |
|---|---:|---:|---:|---|
| `lfsa_egaed`; DE, A, THS_PER, sex T, age Y25-64, ED5-8 | 12,543.1 | 12,708.1 | 13,052.0 | Tertiary-educated employed persons, thousands; 2021 has break flag b |
| `nama_10_a64_p5`; DE, A, TOTAL, N1171G, P51G, CP_MNAC | 105,966 | 110,894 | 124,513 | R&D gross fixed capital formation, current-price million national currency; 2022–23 provisional p |

The successful labor request confirms a measurable education-employment counterpart, not corporate labor, FTE, model efficiency units, or a young cohort. The R&D request confirms an investment-flow series, not N, innovation success, a, or A_X. Every dimension label was checked in the JSON response; the six observations and flags are retained in `probe_observations.csv`.

Exact endpoints:

- [Eurostat education employment probe](https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/lfsa_egaed?lang=en&freq=A&unit=THS_PER&sex=T&age=Y25-64&isced11=ED5-8&geo=DE&sinceTimePeriod=2021&untilTimePeriod=2023).
- [Eurostat R&D investment probe](https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/nama_10_a64_p5?geo=DE&freq=A&nace_r2=TOTAL&asset10=N1171G&na_item=P51G&unit=CP_MNAC&sinceTimePeriod=2021&untilTimePeriod=2023).

## Failed or rejected routes

1. One OpenEcon query explicitly requested OECD MSTI `USA+DEU.A.B_RS.FTE._Z._Z`, 2021–2023. The MCP returned numerical data but exposed URLs ending `USA.A.G+T_RS...` and `DEU.A.G+T_RS...`, with generic unit “value”. Those data were **rejected for this purpose**: they are not the requested business researcher/FTE specification. The complete tool response and query are saved in `raw/openecon_msti_response.json`. This is a semantic-mapping failure, not a timeout or no-data result.
2. First local API attempts failed because the sandbox could not resolve external hosts. That log is retained.
3. After authorized network access, exact OECD MSTI endpoint `https://sdmx.oecd.org/public/rest/v1/data/OECD.STI.STP,DSD_MSTI@DF_MSTI,1.3/USA+DEU.A.B_RS.FTE._Z._Z?startPeriod=2021&endPeriod=2023&dimension_at_observation=AllDimensions&format=csvfile` returned HTTP 403. It was not repeatedly retried. The previous locally preserved OECD data establish an existing route/vintage; this failed probe does not establish absence of the series.
4. Direct OECD documentation retrieval also returned HTTP403, while the web reader could retrieve its official dataset page. Some NCSES/BEA web-open calls returned tool internal errors; primary official search results resolved the exact NCSES 2023 Tables 50/52 and BEA R&D accounting pages below.

## Source keys for table cells

**CPS.** Existing `diagnostics/labor_wages_methodology.md` and `scripts/03_skill_labor_and_wages.py`; raw NBER MORG 1990–2024, US private-for-profit baseline 1994–2024. BA+ is `grade92=43..46`; exhaustive non-BA is 31..42. Annual headcount uses `earnwt/12`; observed-hours FTE uses usual main-job hours/40. Average hourly earnings derive from usual weekly earnings / usual hours. Composition adjustment holds 2007 education×age×sex cells fixed. Public-for-profit is a bridge to corporate employment because CPS does not identify incorporation for all employers. The current model's young cohort is not separately selected by these estimates. Employer-paid benefits are absent from cash earnings. [BLS CPS definitions](https://www.bls.gov/cps/definitions.htm), checked live; [NBER codebook](https://data.nber.org/morg/docs/cpsx.pdf), used by the preserved pipeline.

**LFS.** Existing `diagnostics/row_labor_methods.md`; Eurostat `lfsa_egaed`, age25–64, both sexes, educational groups ED5-8, ED3_4, ED0-2; annual thousands of employed persons. Existing saved panel covers country-specific years within 1990–2025; education coding changes at 2014 and reported breaks remain. The official metadata states that all economic sectors are covered, statistical units are persons, annual frequency, and no adjustments are applied in this detailed LFS collection. [Eurostat annual LFS metadata](https://ec.europa.eu/eurostat/cache/metadata/en/lfsa_esms.htm), retrieved and saved live. OECD EAG earnings ratios in the local panel have irregular 2000–2025 coverage and no 2007 observations; they are relative mean earnings, not matched wage levels. Ratios should not be multiplied by mismatched Eurostat counts to create a RoW wage bill.

**NRC.** Existing `Nonroutine_Cognitive_README.md`; US broad published BLS series `LNU02032201` (management/professional and related) divided by `LNU02000000` is NRC/total employment, not R/H. US CPS microdata can instead produce NRC∩BA+ / BA+ using the same weights/population; this matches the denominator but still requires the substantive NRC-as-innovation assumption. Existing G4 ISCO08 groups1+2+3 (broad) or1+2 (narrow) are not an exact US occupational crosswalk. Do not treat different NRC classifications as a harmonized research input.

**MSTI.** Locally preserved OECD `DSD_MSTI@DF_MSTI` v1.3, business researcher `B_RS` or total personnel `B_TT`, FTE versus headcount `PS`, with `PRICE_BASE=_Z` and `TRANSFORMATION=_Z`. Existing data span 46 individual economies plus OECD/EU aggregates; country coverage and flags vary. OECD-ex-US subtracts a matching aggregate and US, rather than measuring world-ex-US. The live OpenEcon result was rejected and direct OECD route returned403. [OECD MSTI description](https://www.oecd.org/en/data/datasets/main-science-and-technology-indicators.html).

**NCSES.** Existing `diagnostics/rd_knowledge_methods.md`; BERD domestic business researcher and total R&D FTE, saved 2015–2023, thousands converted to persons. [2023 Table52: domestic FTE R&D employees/researchers](https://ncses.nsf.gov/pubs/nsf25354/assets/data-tables/tables/nsf25354-tab052.pdf) and [Table50: employment and researcher education](https://ncses.nsf.gov/pubs/nsf25354/assets/data-tables/tables/nsf25354-tab050.pdf) verified in live primary-source search. Coverage is domestic performance by surveyed nonfarm for-profit businesses with10+ employees; R&D personnel need not all belong to an education-defined H. The 2023 expenditure reporting change and historical SIRD/BRDIS/BRDS/BERD transitions preclude unqualified splicing.

**KNOWLEDGE.** Existing `diagnostics/rd_knowledge_methods.md` and `diagnostics/implied_ai_readme.md`. US current-cost R&D net stock uses Q4 `FL105013465+FL795013465`; the real proxy divides by private R&D investment price `Y006RG3Q086SBEA/100`, an explicit investment-deflator sensitivity. Alternative USPTO grants, OECD triadic families, WIPO resident applications and WRDS-linked patents differ in offices, residence and cohort timing. Perpetual-inventory stock requires depreciation and initialization; existing truncated stocks do not become exact variety counts after normalization. The model timing bridge in the free-entry diagnostic is N_model,t=N_end,t-1, N_model,t+1=N_end,t, q_t=Q_end,t/N_end,t. This yields a_t=(w_H,t/Q_end,t)(N_end,t/N_end,t-1), so the empirical implied a depends heavily on the valuation mapping.

**CORPORATE.** Existing IMA/BEA US corporate accounts and OECD annual institutional sector accounts S11+S12, notably B1G value added and D1 compensation. These directly publish the named accounting quantities; their equality to model Y/e/profits depends on sector, R&D capitalization, taxes and physical capital treatment. Parent/external-account agent verifies specific financial endpoints and coverage. AHP enterprise value is distinct from shareholder capitalization; FCF is distinct from paid cash dividends.

**RDINPUT.** Existing `RD_Input_Output_Evidence_2026-09-20` full supplement and independent annual-method review. Exact US BEA private R&D growth/contribution: `Y006RL1Q225SBEA`, `Y006RY2Q224SBEA`, NIPA1.5.1/1.5.2 line39. Annual total-economy R&D GFCF: asset `N1171G`, transaction `P51G`, Eurostat `nama_10_a64_p5` or OECD national accounts. Neither is direct innovative output nor factor augmentation. GDP contributions are expenditure accounting and can have import offsets; they are not causal GDP/productivity effects. [BEA R&D capitalization](https://www.bea.gov/help/faq/1028) and [R&D investment versus domestic performance](https://www.bea.gov/help/faq/475) verified in live primary-source search.

**MARKET.** Parent's live WRDS/financial audit provides exact accessible security fields and samples. Interpret distribution-excluding price indices, cash dividend flows and shareholder capitalization separately. Listed issuer portfolios differ from domestic corporate activity. Aggregate Q and D may be directly measured *for that explicit security universe*, whereas q,d per variety require N.

**MODEL.** `TwoCountryProductionOLG.jl` and `V6_calibration_core.tex`: both countries CES, elasticity1/rho, active-R&D equalities, zero nu_b/xi_W. Maintained restrictions have no data endpoint.

## Conditional inversion and identification formulas

For X=phi H and rho≠1, exact CES inversion is
A_X=[vartheta alpha Y^rho/(w_H X^rho)]^(1/(rho-1)),
A_L=[(1-alpha)Y^rho/(w_L L^rho)]^(1/(rho-1)).
It requires the model Euler accounting check w_H X/vartheta+w_L L=Y. Do not force empirical shares to sum to one by rescaling incompatible components.

With constant alpha and vartheta, relative augmentation growth satisfies
Delta log(A_X/A_L)=[-Delta log(w_H/w_L)-rho Delta log(X/L)]/(rho-1).
This conditional construction does not independently identify rho or the augmentation exponents. Growth removes constant scale factors but not the production-input mapping or curvature assumption.

For vartheta, D=(1-vartheta)/vartheta * w_H phi H implies vartheta=w_H phi H/(w_H phi H+D) only when D is the model operating-profit flow and wage/input coverage agrees. Substituting ordinary cash dividends or accounting margins without reconciliation does not produce a markup estimate.

## Reproduction and verification

- `python3 probe_official.py` makes five read-only requests and saves raw successes plus a fresh timestamped query log. Official releases may revise historical values.
- `probe_observations.csv` contains only the six live Eurostat observations, not older cached data.
- `validation.json` records dimensions, unique row identifiers, and rejected-route conclusions.
- `production_entries.json` contains all19 candidate table rows with original core-entry IDs.
- Prior memory was used only to locate the annual mapping package. Current source files and definitions were reread; classifications above do not rely on an unverified remembered empirical value. Memory pointer: MEMORY.md507–511, rollout01a09ef1-05be-76a1-b833-20fffde2484b.
