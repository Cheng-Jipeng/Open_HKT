# US production calibration: completed attempt, baseline rejected

Run date: 12 October 2026. Scope: US annual conditional production, 1994–2022; 2023–2024 reserved for conditional temporal checks. No RoW data or fitted RoW parameters enter this run.

## Result

**The supplied empirical mappings and external markup candidates do not admit the proposed active-research calibration. No accepted five-parameter production vector is reported.** At inverse markup 1/1.61, P1 implies skilled production share **1.45871–1.91507**, with **0/29** admissible dates. Implied research payroll is negative in every year. Changing rho, a, alpha, or productivity scales cannot repair P1.

All 60 baseline/fixed-labor markup–rho specifications fail before P2. The broader screen includes 140 labor-pair/sector/markup specifications; 0 have any feasible date. Alternative sector definitions and skill splits therefore do not rescue the documented markup set.

For the preferred observed-labor panel, the common admissible inverse-markup interval is **(0.000000, 0.324331)**, implying gross markup **strictly above 3.083267**; the upper bound binds in 1996. This is an endogenous accounting bound, not an externally estimated markup. The supplied candidates range from 1.10 to 1.84.

## Sources actually used

The preserved September 14, 2026 data snapshot is read offline; no historical values are refreshed. The user-supplied package is a reconstruction of AHP concepts from revised official data, **not AHP's frozen author vintage**.

| Input | Selected source and construction |
| --- | --- |
| Y | Federal Reserve/BEA integrated accounts, total nonfinancial corporate plus domestic financial business GVA; FU106902501Q + FU796902505Q; sum four unannualized quarterly flows. Mapping Y_US_AHP_TOTAL_CORP_GVA. |
| Q | Fed B.1 operating enterprise value, LM102010405Q + LM792010405Q, Q4 stock. Mapping Q_US_AHP_ENTERPRISE_VALUE_TOTAL_CORP. This is a conditional proxy for post-entry N_(t+1)q_t, not an observed entry-timing classification. |
| Total compensation | FU106025005Q + FU796025005Q, summed quarterly flows; COMP_US_AHP_TOTAL_CORP. |
| H, L | NBER CPS MORG private for-profit wage/salary workers age16+, BA+ versus exhaustive non-BA; H_US_COLLEGE_EQUIV and L_US_NONCOLLEGE. No non-US labor inputs. |
| Skill premium | WHWL_US_CPS_COMPOSITION_ADJ_COLLEGE_NONCOLLEGE: winsorized hourly means with fixed 2007 within-group age/sex/education composition. |
| Wage levels | wL=COMP/(premium H+L), wH=premium wL. Matching aggregate compensation is imposed by this bridge, not an independent success. |
| Real units | BEA GDPDEF via preserved FRED raw file, mean of four quarters, 2017=100; divide Y, Q, compensation and FCF by the same yearly index. This run-specific common numeraire differs from the package's quarterly-deflated real-GVA alternative. GDP-wide deflation is a proxy for corporate output prices. |
| Untargeted cash flow check | D_US_AHP_FCF_TOTAL_CORP, compared with fitted incumbent profits minus research payroll only in diagnostic scenarios; physical investment/tax differences prevent exact equivalence. |

Money is trillion 2017 USD; labor is million persons. Wage units are trillion USD per million workers per year. a is per million workers per annual model step. Multiplying labor by c divides a and productivity scales by c, while aH and predictions are invariant. No annual re-normalization by changing GDP or population is performed.

The baseline retains measured H_t,L_t and is therefore a conditional production extension of the fixed-endowment GE model. A separate `fixed2007` sensitivity fixes both stocks at their 2007 values and re-bridges wages using observed compensation and premium; it is a counterfactual measurement bridge, not the original observed workforce. Occupational sensitivity pairs partition their valid-occupation universe, not necessarily the whole workforce. Neither labor treatment admits the supplied markup set. Alpha=0.5 and N_1994=1 are normalizations. No b-regime scales are calibrated. Treating all fitting years as u is a maintained regime hypothesis.

## Executed sequence and safeguards

1. P1: infer X, phi and research I. Preserve every date and reject a specification if any date is infeasible; never clip phi, delete invalid dates, or insert negative-research growth into later equations.
2. P2: for feasible diagnostic specifications only, estimate constant a from weighted free-entry levels with weights 1/Q_t^2; retain datewise implied a and compare G_Q=Q/(Q-I) to G_a=1+a(H-X).
3. Construct N_t with sum of log G_s over s<t. G_t predicts growth from t to t+1. The last observed G is excluded from N at the final date.
4. Recover CES coefficients and sequential growth slopes using forward differences of log C_X and log C_L, correctly including changing L_t. Sequential G_Q paths are diagnostic, never simultaneously imposed with an inconsistent constant-a path.
5. Fit the five production parameters jointly, profiling over log a and solving the two log-CES regressions exactly at each candidate. Equal weight is placed on three mean-square blocks: (Q-I-wH/a)/Q, log C_X residual, and log C_L residual. No extra P5 residuals are added to the P4 level objective. No xi>nu or nu>=0 restriction is imposed.
6. Examine weight, window, markup, curvature and fixed-labor sensitivity, local Jacobian rank/conditioning and the profiled objective. These are diagnostics, not sampling confidence intervals. With aggregate generated inputs and incompatible mappings, precise confidence claims would be unwarranted.

The P3 unconstrained ratio-regression diagnostic also fails: theta=-6.51068, a=-0.00536136. Its weighting differs from P2. The separately saved original-unit P3 WLS uses Q^(-2) weights consistent with P2 and is also checked for admissibility. Neither is substituted for the external candidates.

## Higher-markup experiments: not accepted estimates

To show the downstream implications, the code also fits analyst-chosen markups 3.25, 3.5 and 4.0. They lie outside the supplied evidence-based candidate set and were chosen solely to enter the mathematically feasible region. They must not be quoted as the calibrated US parameter vector. At rho=2/3:

| markup | a | xi | nu | AX | AL | Q_RMSE |
| --- | --- | --- | --- | --- | --- | --- |
| 3.25 | 0.00423749 | 1.4149 | -1.6619 | 0.703795 | 0.0646099 | 31.44% |
| 3.5 | 0.00426279 | 1.0373 | -1.2173 | 0.744027 | 0.0660125 | 31.36% |
| 4 | 0.00430456 | 0.72031 | -0.84475 | 0.837744 | 0.0671608 | 31.23% |

Q_RMSE is the root mean squared relative free-entry residual. AX/AL scales depend on the declared labor, money, alpha and N normalizations. For markup 3.5, the local Jacobian rank is 5/5, the column-scaled condition number is 3.02, and the unrestricted spillovers do not satisfy xi>nu>=0. Full numerical rank does not establish reliable empirical identification.

The labor treatment matters materially: fixing H and L at 2007 levels while preserving the observed wage premium changes the markup-3.5 estimates to a=0.00393849, xi=1.2246, nu=0.27703, versus nu=-1.2173 with observed annual endowments. The sign reversal rules out treating the inferred unskilled spillover as robust to the workforce mapping. Both remain experiments outside the supplied markup set. In the observed-labor example, 2023–2024 free-entry Q error is 55.9%; using the jointly fitted production wage instead gives 53.9%. This is poor valuation performance despite the smaller conditional output errors.

The two-year temporal check uses later observed X reconstructed from later Y and wages; it tests fixed production relationships conditional on those inputs. It is not an unconditional forecast or GE asset-pricing validation. Cash-flow comparisons are untargeted relative to this objective but share national-account sources. No fit to targeted Q is described as independent validation.

## What this implies for the model

This run completes the proposed empirical calibration attempt and identifies a binding contradiction at its first step. An empirically supported production vector requires a revised, justified markup/input mapping or a revised production-accounting model. GVA includes physical-capital returns, whereas the proposed two-labor production reduction has no separately measured physical-capital factor. That is a possible explanation to investigate, not a correction made here. Relabelling capitalized R&D alone cannot reverse the negative-research sign under the corresponding accounting bridge.

The reference Julia module also imposes rho_US>1 and xi_u>nu_u>=0, while the Plan's skill-substitution baseline is rho=2/3. It cannot accept these empirical scenarios unchanged. The reference solver was not modified. No two-country equilibrium, bubble condition, portfolio return, saving parameter, post-switch technology or finance parameter is claimed calibrated.

## Reproduction and files

From this Do directory: `python3 run_calibration.py`, then `python3 test_calibration.py`. Dependencies are numpy, pandas and matplotlib; no SciPy, network or credentials are required. The verified interpreter on this Mac is `/Users/jipengcheng/opt/anaconda3/bin/python3`; use that full path if `python3` resolves to a Python without these dependencies. The run overwrites only its own results/ and README.md; empirical inputs and reference code are read only. Rerunning against a changed source snapshot may alter results. Immediate processed inputs and small macro raw files are hashed in this run; upstream CPS microdata hashes are preserved from the registry but not all rehashed, and CPS microdata are not reaggregated here. The manifest distinguishes those statuses. The captured conversation and Plan sources provide the specification.

- `results/calibration_status.json`: rejected main run, null structural estimates and fixed external assumptions.
- `results/baseline_panel.csv`, `baseline_allocation.csv`: input panel, wage bridge and every P1 failure.
- `results/external_grid.csv`, `source_feasibility.csv`: complete candidate rejection ledgers.
- `results/conditional_parameters.csv`, `conditional_sequential.csv`, `conditional_paths.csv`: explicitly labelled experiments outside the supplied markup set.
- `results/conditional_holdout.csv`, `joint_a_profile.csv`: conditional temporal/untargeted checks and identification profile.
- `results/p3_diagnostic.json`, `validation.json`: alternative identification and numerical checks.
- `results/selected_input_observations.csv`, `mapping_provenance.csv`, `source_registry_selected.csv`, `input_manifest.csv`: exact sources, metadata and SHA-256 hashes.
- `results/figures/`: feasibility and conditional-fit plots, PNG and SVG.
- `data_audit.md`, `reference_audit.md`, `solver_audit.md`: independent measurement, reference and solver audits; `source_validation.csv` supplies raw-component spot checks.

Validation: 16 recorded structural/accounting checks. The synthetic recovery/failure tests are separate from economic fit; a passing numerical test does not turn the rejected empirical run into an accepted calibration.
