# US production calibration: 2009–2024, rho = 2

**Current status: REJECTED_P1.** 16/16 fitting observations fail the active-research allocation restriction.

## Requested changes and literature choice

The fitting sample is **2009–2024 (16 annual observations)**. The end year is resolved from the latest common complete observation of output, valuation, compensation, H, L, the premium and the annual deflator in the preserved September 2026 package. Corporate accounts extend to 2025, but labor and premium inputs end in 2024 in this snapshot. `results/input_coverage.csv` records the component endpoints. Missing interior years cause an error rather than compressed knowledge transitions. Untargeted cash-flow availability does not determine the fitting sample.

**rho = 2, sigma = 1/rho = 0.5** respects the requested rho > 1 model class. All executed curvature candidates satisfy it. The choice is supported as a capital–labor complementarity analogy by [Oberfield and Raval (2021)](https://doi.org/10.3982/ECTA12807), whose aggregate manufacturing range is 0.5–0.7, and the country-level-data variant of [Gechert et al. (2022), Table 9](https://doi.org/10.1016/j.red.2021.05.003), which gives 0.50. Their input margin differs from V6's skilled-production versus unskilled input. This is a maintained model-compatible calibration, not a directly estimated V6 skill elasticity. See [rho_selection.md](rho_selection.md) for verified source loci and the selection rule.

All available dates, including 2023–2024, are now fitting years. **There is no holdout in this run.** The documented CPS disclosure/topcoding comparability caveat for these last years remains. The markup, source mappings, units and compensation bridge are unchanged.

## Allocation and empirical admissibility

At baseline markup 1.61, P1 implies phi **1.458710–1.748321**, with **0/16** interior dates. Implied research payroll ranges from **-2.190351 to -1.466537 trillion 2017 USD**. No invalid date is clipped or deleted.

The common inverse-markup interval is (0.000000, 0.355266); its upper bound corresponds to markup strictly above **2.814796**, binding in 2010. This is an accounting feasibility bound, not independent markup evidence. P1 contains no rho, so choosing a compatible curvature cannot by itself repair this allocation restriction.

The run screens 10 external markup/curvature/labor specifications; 0 pass P1/P2. It also screens 140 skill-pair/sector/markup combinations; 0 pass on their available dates. `complete_fit_window` distinguishes variants with shorter coverage. The unrestricted P3 ratio diagnostic yields theta=-10.532756131340298 and a=-0.0019034149714786633; its admissibility is False. Original-unit P3 WLS is separately recorded.

## Conditional downstream experiments

Higher markups 3.25, 3.5, 4.0 retain their previous role as scenarios outside the supplied direct-transfer markup set. **They are not accepted baseline estimates.** The unchanged source literature's markup basis still requires a mapping to the model's intermediate stage. No inference that these are impossible under every transformed empirical markup is made.

| Markup | Labor | Entry weight | a | xi | nu | AX | AL | Q error | xi > nu >= 0 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 3.25 | observed | 1 | 0.00306815 | -0.17398 | 2.1722 | 0.313421 | 0.195189 | 31.35% | False |
| 3.5 | observed | 1 | 0.00308466 | -0.1363 | 1.6833 | 0.337864 | 0.193367 | 31.30% | False |
| 4 | observed | 1 | 0.00311189 | -0.10049 | 1.2287 | 0.386479 | 0.19176 | 31.21% | False |
| 3.5 | fixed2007 | 1 | 0.00311446 | 2.0737 | 2.2926 | 0.338078 | 0.168035 | 24.76% | False |
| 3.5 | observed | 0.1 | 0.00308466 | -0.1363 | 1.6833 | 0.337864 | 0.193367 | 31.30% | False |
| 3.5 | observed | 10 | 0.00308466 | -0.1363 | 1.6833 | 0.337864 | 0.193367 | 31.30% | False |

Q error is relative free-entry RMSE. Full scenario identifiers and objective weights are in `conditional_parameters.csv`; repeated labor/markup rows differ in the existing entry-weight sensitivity. `fixed2007` retains the prior counterfactual fixing H and L at that year's levels. No old pre-2009 subwindow is fitted. Parameter sign/order compliance is reported separately from fit quality and does not establish GE admissibility.

## Spillover restriction diagnosis

The spillover investigation is documented in [Spillover_Diagnosis/README.md](Spillover_Diagnosis/README.md); its numerical tables refer to the explicitly dated diagnosis.

For this matching run, xi-nu=-1.819608. At rho=2, the relative-wage identity gives xi-nu = -slope(log(wH/wL) on log N) - 2*slope(log(X/L) on log N). The relative-input term contributes 95.9% of the negative gap; this is an algebraic decomposition. Nu is positive; xi's sign and the xi>nu ordering are the failed restrictions. All 10 mapping/counterfactual cases fail the necessary ordering screen. Fixing H,L makes xi positive but leaves xi<nu.

Native Julia production-function recovery and independent wage-derivative checks pass. No sign, timing or inversion error was found. The evidence identifies a conflict between the mapped factor trends and the maintained model restrictions, without uniquely attributing it to measurement or structural misspecification. Imposing xi>=nu>=0 gives the equality boundary xi=nu=0.773505, raising the equal-weight objective by 22.50%; equality still violates strict xi>nu. This constrained diagnostic is not adopted as the calibration.


## Inputs, equations and units

- Y, Q, compensation and FCF: the preserved Fed/BEA total-corporate mappings. Quarterly flow sums and Q4 valuation are inherited from the data package.
- H and L: CPS MORG private-for-profit BA+/non-BA employment; premium: composition-adjusted hourly wage ratio. The wage bridge is wL=COMP/(premium*H+L), wH=premium*wL.
- Money: trillion 2017 USD, using the same annual mean GDPDEF/100 for each monetary series. Labor: million persons. Plotted wages are thousand 2017 USD per worker-year.
- P1: X=theta*(Y-wL*L)/wH, phi=X/H, I=wH*(H-X), with theta=1/markup. Active entry requires 0<X<H and Q>I.
- P2: Q-I=wH/a. The sequential fit uses Q^(-2) weights. The joint fit profiles log(a), solving the two log-CES regressions at each candidate with weights [1.0, 1.0, 1.0] on the three mean-square blocks.
- Knowledge: N_2009=1, N_(t+1)=[1+a*(H_t-X_t)]N_t. Contemporaneous entry changes next year's N. Alpha=0.5 is a scale normalization.
- Observed annual H,L define a conditional production extension of the fixed-endowment GE model. The full two-country solver, finance block and regime-b technology are not calibrated. Neither wage bridging nor targeted Q fit is independent validation.

## Figure and reproducibility

`results/figures/calibration_overview.png` is the requested single figure. PDF and SVG copies are available alongside it. It combines the input series, wages, skill premium, compensation shares, phi, research labor/payroll and the markup bound. Downstream innovation and technology paths are explicitly labelled with their diagnostic markup; none is inferred for the rejected baseline.

The sidebar reports external assignments and normalizations, all five central conditional estimates, in-sample fit errors, the allocation and spillover failures, and the matching diagnosis's main takeaway. The sidebar is populated from the computed CSV/JSON outputs. Earlier figures and results are preserved under `archive/before_spillover_diagnosis/`.

From this directory, run `python3 run_calibration.py` and `python3 test_calibration.py` in an environment containing `requirements.txt`. A portable isolated alternative is:

```sh
uv run --python 3.12 --with-requirements requirements.txt python run_calibration.py
uv run --python 3.12 --with-requirements requirements.txt python test_calibration.py
```

The numerical tests cover both the original rho=2/3 and the current rho=2 branches. Configuration tests verify automatic sample endpoints, missing-year rejection and the rho>1 rule. Passing them validates implementation, not the empirical model.

The original code, results, reports and figures are preserved under `archive/2026-10-12_before_rho2_2009_latest/` with a SHA-256 manifest. The historical `data_audit.md`, `reference_audit.md`, `solver_audit.md`, and `P1_Diagnosis/` describe the original 1994–2022 exercise. The P1 diagnostic script is pinned to that archived baseline so it cannot accidentally mix samples. Current numerical conclusions are those in this README and `results/`.

Current outputs include `sample_selection.json`, `input_coverage.csv`, `calibration_status.json`, `baseline_panel.csv`, `baseline_allocation.csv`, `external_grid.csv`, `source_feasibility.csv`, `conditional_parameters.csv`, `conditional_paths.csv`, `fit_metrics.csv`, `joint_a_profile.csv`, input/provenance manifests, validation and synthetic-test records. `fit_metrics.csv` contains in-sample errors only. The runner derives status from the computed checks rather than a hard-coded rejection.
