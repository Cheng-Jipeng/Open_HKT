# US calibration reference audit

Prepared 12 October 2026. This note audits the supplied Plan and recommends conditional external inputs for the US production block. It does not report estimated parameters or select the final empirical source bundle. The accompanying execution outputs identify the actual sample, data sources, and retained specifications. No applicable on-disk AGENTS.md was found in the project root, Codes, Calibration_R1, Plan, or Do; the user's supplied instructions remain applicable.

## Controlling local sources

Paths below are relative to `Codes/Calibration_R1/Plan/`.

| Source | Relevant location | Use |
|---|---|---|
| `V6_parameter_identifying_moments.tex` | lines 43–71, 152–178, 193–233, 312–321 | Accounting/entry inversion, CES identification, growth timing, sequence and non-identification warnings |
| `V6_calibration_core.tex` | lines 82–117, 123–146 | Model symbols, fixed labor endowments, solver restrictions, regimes, and capitalization timing |
| `external_calibration_review_evidence/production_review.md` | P1–P12 and final recommendations | Exact markup/elasticity definitions and competing empirical evidence |
| `external_calibration_review_evidence/recommendations.tex` | lines 36–59, 99–107, 153–180 | Conditional US external candidates and normalizations |
| `external_calibration_review_evidence/growth_regime_review.md` | M09 and M16 | Period/labor scaling and why illustrative HKT parameters are not estimates |
| `external_calibration_review_evidence/growth_regime_supplement.md` | Kahn–Rich section | Technology-duration analogy, not observed HKT switch data |
| `V6_calibration_measurability.tex` | M07, M08, M14, M19, M26–M28 | Missing empirical regime classifier; population/sector/period bridges |

The Plan distinguishes the inverse markup `vartheta_US` from the portfolio share `theta_US`. The former is the parameter covered here.

## External US production specifications

### Markup

The model gross intermediate markup is `mu=1/vartheta`, not `1+vartheta`. Its variety-demand elasticity is `1/(1-vartheta)` and differs from final-sector substitution.

| Label | Gross markup mu | Exact vartheta | Interpretation |
|---|---:|---:|---|
| COGS listed-firm benchmark | 1.61 | 0.6211180124 | Plan P5: De Loecker, Eeckhout and Unger (2020), 2016 US sales-weighted markup |
| Operating-cost alternative | 1.15 | 0.8695652174 | Plan P6: Traina (2018), COGS plus SG&A specification |
| Low-markup historical alternative | 1.10 | 0.9090909091 | Plan P6: approximately 1980; dated anchor |
| COGS historical alternative | 1.21 | 0.8264462810 | Plan P5: 1980; dated anchor |
| Global-database US alternative | 1.84 | 0.5434782609 | Plan P7: De Loecker and Eeckhout (2021 manuscript), US row for 2016 |

Use the first row as the Plan's proposed conditional benchmark and the second as the main cost-definition sensitivity. These are competing period/measurement specifications, not sampling confidence bounds. They concern heterogeneous listed firms; V6 has a homogeneous intermediate producer with no overhead or physical capital. An aggregate inverse markup therefore remains a substantive mapping assumption. A 2016 estimate is not evidence that the markup was constant over a long historical calibration window. Source ledger: supplied `production_review.md`, P5–P9; [DLEU original manuscript](https://www.janeeckhout.com/wp-content/uploads/RMP.pdf), [Traina original DOI](https://doi.org/10.2139/ssrn.3120849), [Global Market Power manuscript](https://crei.cat/wp-content/uploads/2021/04/GLOBAL.pdf). The DLEU URL was retried during this audit but text retrieval timed out; numerical evidence is from the supplied source audit.

### Final-sector substitution

V6 uses CES exponent `1-rho`, so substitution elasticity is `sigma=1/rho`. Neither rho nor vartheta is annualized.

| Label | rho | sigma | Role |
|---|---:|---:|---|
| Original US IV anchor | 2/3 | 1.5 | Conditional Plan baseline |
| US skill meta alternative | 0.16 | 6.25 | Separate corrected-meta specification; paper rounds sigma to 6.3 |
| US IV endpoint | 0.5 | 2 | Point-specification sensitivity |
| US IV endpoint | 5/6 | 1.2 | Point-specification sensitivity |
| US time-series anchor | 0.709 | 1.410437 | Katz–Murphy alternative |
| Low-substitution skill stress | 1/1.1 | 1.1 | Caselli–Coleman calibration sensitivity, not a separate estimate |
| Capital–labor analogy | 2 | 0.5 | Distinct input-margin stress; not preferred skill evidence |

Ciccone and Peri's Table 4, panel B(iv), column 1 gives sigma=1.50, SE=0.44, with Fuller-modified LIML and compulsory-schooling/child-labor instruments. Its 48-state, 1950–1990 sample and high-school-equivalence margin do not coincide exactly with a contemporary BA+/non-BA production split. The original table and methodological interpretation were rechecked online in this run. [Published author copy](https://giovanniperi.ucdavis.edu/uploads/5/6/8/2/56826033/ciccone_peri_long_run_substitutability_@005.pdf).

Havranek et al.'s final Table 5 reports a US negative inverse elasticity of -0.16 with 95% credible interval [-0.38,0.06], mapping to rho interval [-0.06,0.38]. This crosses zero and cannot be inverted into a finite positive sigma interval. The study's pooled rho=0.27 can be retained only as an explicitly pooled external scenario, rather than US-only empirical evidence. The published table was rechecked online in this run. [Final published paper](https://meta-analysis.cz/skill/skill2.pdf).

The original model solver's `rho_US>1` restriction does not justify selecting the capital–labor branch or excluding the skill branch. Production inversion can be evaluated for positive rho on both sides of one; the Cobb–Douglas boundary rho=1 needs its own formulas. Report disagreement with the solver/theorem as a finding. Do not describe the selected rho as a consensus estimate.

## Normalization and implementation checks

1. For rho not equal to one, set `alpha_US=0.5` only as a declared normalization and recover both augmentation scales jointly. The two identified composites are `C_X=alpha*A_X^(1-rho)` and `C_L=(1-alpha)*A_L^(1-rho)`. An alpha sensitivity is a reparameterization check preserving these composites, not an independent economic sensitivity.
2. Set `N_US,0=1` as a knowledge-unit normalization at the declared initial year. Then the fitted initial augmentation levels are the corresponding barred scales. Raw patents or business counts are not measured model N.
3. Use one fixed labor unit throughout the time series. Under `H'=cH`, `L'=cL`, wages transform by `1/c`, `a'=a/c`, and `aH` is invariant. Dividing by a different total workforce in each year changes economic growth as well as units and is not an innocuous fixed-unit normalization.
4. Report both the unit-dependent a and the dimensionless aH. Annual observed H and L may vary, whereas the reference equilibrium model fixes their endowments. An empirical production calculation with varying inputs must keep this departure explicit. For growth equations use observed `Y_t/L_t` if L varies; do not silently insert fixed L when computing the denominator growth.
5. At rho=1, `alpha=1-w_L L/Y` is the conditional share inversion and only the combined scale `A_X^alpha*A_L^(1-alpha)` is identified. Near one, separate scale recovery becomes poorly conditioned.

## Period, admissibility, and timing

For an annual empirical run, retain annual compensation/output/research flows and a matched year-end capitalization stock; deflate every nominal wage, output, flow, and valuation consistently into the same final-good units. Call the result an annual conditional production calibration. Plan does not establish that one calendar year is a literal young-to-old generation, so this calculation alone does not deliver a cohort-consistent saving or complete equilibrium calibration. There is no permission in the reference evidence to substitute familiar annual discount factors for the model's old-age utility weight beta.

The accounting route is

```
X = vartheta*(Y-w_L*L)/w_H
phi = X/H
I = w_H*H-vartheta*(Y-w_L*L)
a = w_H/(Q-I)
G = Q/(Q-I)
```

Require `0<phi<1` and `0<=I<Q` for the active-entry point inversion, and retain failed rows/specifications as failures. In particular positive research requires `vartheta < (w_H*H)/(Y-w_L*L)` when the denominator is positive. Do not clip a literature markup to obtain a positive research share. At phi=1, use the no-entry inequality `a<=w_H/Q`, not the interior equality estimate.

Capitalization Q is post-entry `N_(t+1)*q_t`; incumbent dividends are `N_t*d_t`. Enterprise value, equity value, and annual cash flows are not interchangeable. AHP free cash flow can map to `D-I`; it does not independently measure D or I. Any enterprise-value route is a distinct perimeter scenario unless the extra corporate financing instruments have been reconciled.

For each transition t to t+1, the growth regression uses `G_t=Q_t/(Q_t-I_t)`, and the left side is forward `log Z_(t+1)-log Z_t`. A CSV written with conventional backward annual differences must pair its year-t growth with year-(t-1) G. Both equations share generated X, I and G: bootstrap or uncertainty propagation must reconstruct them jointly rather than treating them as separately measured moments.

## Regime and sample choices

No reviewed Plan source supplies an observed empirical classifier for the irreversible u-to-b factor-spillover transition. A recession date, dot-com crash, or the 2008 financial crisis is not automatically b. An all-u historical production fit is a maintained assignment. Estimate on the common complete-data window and disclose it; a pre-pandemic window and pre/post-financial-crisis splits are reasonable analyst robustness choices when coverage supports them, not source-imposed regime dates.

The Plan's HKT illustration `aH=0.2`, `xi_u=0.7`, `nu_u=0.2`, and beta=0.5 has no empirically estimated period conversion. Keep it solely as a comparison. The same applies to any local solver defaults. Do not replace negative, equal, or reversed fitted augmentation elasticities with an admissible illustrative pair. Record whether the empirical estimates satisfy `xi_u>nu_u>=0` separately from their measurement validity.

The US-only run cannot identify full two-country financial preference parameters from absent RoW moments. US post-switch augmentation scales and pi remain scenario objects without observed branch classification; no forced numerical completion is supported by the Plan.

## Offline source reconstruction check

On 12 October 2026 the raw official components were independently reaggregated for 1994, 2007, 2022, and 2024 and compared with `Empirical_Data/Variable_mappings/Empirical_Mapping_Annual/data_final/empirical_moments_annual_wide.csv`, selecting `country_or_region=US` and `vintage=latest_official_2026-09-14`. Results and exact raw paths, quarter values, SHA-256 digests, and reconstruction formulas are in `source_validation.csv` in this directory. No raw source, registry, or master file was changed, and no new values were downloaded.

All 36 master comparisons pass: nine mappings in each of the four selected years. These include total/NFC nominal output, compensation, market equity, operating enterprise value, and the pre-existing quarterly-deflated total-corporate output. The 32 nominal-flow/stock comparisons are exactly equal; quarterly-deflated output is equal up to floating-point rounding under a tolerance of `max(1e-6, abs(master)*1e-12)`. All nine raw CSV SHA-256 values match the saved source registry.

| Input | Official raw components | Aggregation |
|---|---|---|
| Total corporate Y | `BOGZ1FU106902501Q` + `BOGZ1FU796902505Q` | Sum four quarterly NSA monetary flows across both sectors |
| Total corporate COMP | `BOGZ1FU106025005Q` + `BOGZ1FU796025005Q` | Sum four quarterly NSA monetary flows across both sectors |
| Total corporate market-equity Q | `NCBEILQ027S` + `BOGZ1LM793164105Q` | Add the two Q4 stock values; the October observation label denotes the fourth quarter |
| Total corporate operating EV | `BOGZ1LM102010405Q` + `BOGZ1LM792010405Q` | Add Q4 stocks; this retains the distinct EV claim perimeter |
| GDP deflator | `GDPDEF` | Arithmetic mean of four quarterly index levels, 2017=100 |

The NFC counterparts use the NFC component alone. Every required component has four nonmissing quarterly observations with labels in January, April, July and October for each checked year. Monetary amounts below are million USD; the deflator is an index.

| Year | Y | COMP | Market-equity Q | Mean GDPDEF |
|---|---:|---:|---:|---:|
| 1994 | 4,261,779 | 2,664,529 | 5,690,731 | 65.56000 |
| 2007 | 8,282,209 | 4,924,531 | 21,053,133 | 86.34550 |
| 2022 | 15,376,906 | 8,614,092 | 55,355,139 | 118.01225 |
| 2024 | 16,984,420 | 9,566,478 | 82,185,191 | 125.42175 |

There is no standalone GDPDEF column in the saved final master. Its four annual means are therefore recorded as `CONSTRUCTED_NO_STANDALONE_MASTER_COLUMN`, with the raw quarter values and matching hashes, rather than a false master-comparison PASS. The saved `Y_US_REAL_CORP_GVA` uses `sum_q(Y_nominal_q/(GDPDEF_q/100))`, which also passes reconstruction. A new run dividing annual nominal output, compensation and valuation by the annual mean GDPDEF uses a coherent common annual numeraire but is a deliberately different construction from that pre-existing quarterly-deflated real-GVA series. It must be declared in the run's source/units documentation.

Successful source reconstruction validates transcription, annualization, and stock timing. It does not remove the economic scope bridge: the broad financial-business sector includes institutions outside the private for-profit CPS labor population, and corporate equity is not automatically a claim on the same consolidated operations as corporate GVA. In particular, a rejected P1 interior condition is not explained away by changing the verified annualization arithmetic.
