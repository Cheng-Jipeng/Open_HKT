# Run 2: fixed sample-mean labor, 2009–2024

**Executed second calibration attempt. Baseline status: REJECTED_P1.** The external baseline still fails allocation in every fitting year. Conditional on the diagnostic markup 3.5, both spillovers become positive, but their ordering remains inadmissible: xi = 1.066920 < nu = 1.181410. These diagnostic estimates are not an adopted full-model parameter vector.

- [17-slide LaTeX report](slides/output/calibration_steps_2009_2024_fixed_mean_labor.pdf)
- [Editable, self-contained Beamer/PGFPlots source](slides/latex/main.tex)
- [Run comparison table](results/run_comparison.csv)
- [Variable-role and constancy ledger](results/variable_roles.csv)
- [Implementation checks](results/synthetic_tests.json)

## What is held constant

The sample contains the same 16 annual observations and September 2026 empirical snapshot as Run 1. Every year from 2009 to 2024 enters fitting; there is no holdout. This is a controlled comparison of the labor treatment, with no data-vintage update.

\[
\bar H=\frac{1}{16}\sum_{t=2009}^{2024}H_t=32.8280902483,\qquad
\bar L=\frac{1}{16}\sum_{t=2009}^{2024}L_t=71.1805533239.
\]

Units are **million persons**. These are separate unweighted means of the two annual employment levels. They are not a mean skill ratio, a fixed 2007 stock, or a per-capita normalization. The labor endowments are identical at every date in every executed scenario.

The theoretical reference is [V6_production.tex](../../../../../AI_drafting/V6_production.tex): its demographic block fixes masses H and L, its state block distinguishes endogenous predetermined knowledge from the exogenous regime, and its unbalanced-growth primitive imposes rho > 1 and xi_u > nu_u > nu_b >= 0. We maintain regime u throughout the observed window. All externally assigned parameters and all five fitted production parameters are single constants within a scenario. Normalization fixes only initial N, not its subsequent path.

Output Y, compensation C, valuation Q and the skill premium r remain annual **targets for endogenous model outcomes**. With fixed quantities, wages are reconstructed at every date as

\[
w_{L,t}=\frac{C_t}{r_t\bar H+\bar L},\qquad
w_{H,t}=r_tw_{L,t}.
\]

This exactly preserves observed compensation and the premium. Retaining the old annual wages after changing H and L would break the compensation identity. Inferred X, phi, I, N, A_X and A_L also remain time varying. Annual GDPDEF is retained as a measurement conversion into trillion 2017 USD; it is not an exogenous process in the model.

The assignments rho=2 (substitution elasticity 0.5), baseline markup 1.61, alpha=0.5 and N_2009=1 are unchanged. The original literature rationale and its imperfect capital–labor analogy are retained in [the curvature note](../../shared/references/rho_selection.md); this second run introduces no new external estimate. Markups 3.25, 3.5 and 4 are still labelled diagnostic scenarios outside the transferred candidate set.

## Step-by-step procedure and allocation result

1. **P1 allocation:** X=theta(Y−w_L L)/w_H; phi=X/H; I=w_H(H−X). Test every date for 0<X<H and Q>I. No clipping or deletion is used.
2. **P2 entry:** invert a_t=w_H/(Q−I), then fit a constant a using relative valuation residuals. The direct valuation growth diagnostic is G^Q=Q/(Q−I).
3. **Knowledge:** N_2009=1 and N_(t+1)=N_t[1+a(H−X_t)]. Q_t=N_(t+1)q_t is post-entry value; N_t is beginning-of-period knowledge. The last observed growth rate produces N_2025, outside the displayed stock window.
4. **P4 CES inversion:** C_X=(w_H/theta)(X/Y)^rho and C_L=w_L(L/Y)^rho. Given alpha, A_X=(C_X/alpha)^(1/(1−rho)), and analogously A_L.
5. **P5 sequential slopes:** regress coefficient log changes on (1−rho)log G^Q without an intercept, then recover constant technology scales from the full-sample log intercepts.
6. **Joint fit:** profile a, build N(a), and fit log A_X=log A_Xbar+xi log N(a) and log A_L=log A_Lbar+nu log N(a). Minimize the sum of the mean squared relative-Q residual and the two mean squared log-coefficient residuals, with equal block weights. The inversions reuse Y and wages; they are not independent empirical evidence beyond these targets.

At the external baseline mu=1.61, **16/16** years fail P1. Implied phi ranges from **1.531465 to 1.696193** and research payroll from **-2.304971 to -1.346815 trillion 2017 USD**. The allocation bound requires mu strictly above **2.730871**, binding in 2022; this is an accounting bound, not a markup estimate. All five external candidates fail. Changing rho cannot affect P1.

At mu=3.5, all years pass the allocation/entry checks: phi lies between 0.704474 and 0.780249. Downstream estimates below are conditional on this diagnostic markup.

## Estimated constants and comparison

| Parameter | Run 1 joint: annual labor | Run 2 sequential | Run 2 joint: fixed means |
| --- | ---: | ---: | ---: |
| a | 0.003084663 | 0.002890668 | 0.002890669 |
| xi | -0.136299491 | 0.866764697 | 1.066919845 |
| nu | 1.683308160 | 1.468306145 | 1.181410499 |
| A_X scale | 0.337864127 | 0.276425496 | 0.269849556 |
| A_L scale | 0.193366781 | 0.190093884 | 0.204558226 |

The coefficient a is in inverse million workers per annual model period. Technology scales depend on the output/labor units, alpha and initial-N normalization. Xi and nu are dimensionless elasticities. A_Xbar and A_Lbar are constant; A_X,t and A_L,t are evolving augmentation levels.

The joint objective is 0.063364990; the optimizer is interior, with Jacobian rank 5. Those are implementation/identification diagnostics conditional on the assigned markup and curvature, not evidence that the economic restrictions hold.

| Relative RMSE | Run 1 | Run 2 |
| --- | ---: | ---: |
| Output | 1.567% | 1.237% |
| Skilled compensation rate | 1.809% | 1.972% |
| Unskilled compensation rate | 3.279% | 3.997% |
| Enterprise value | 31.299% | 24.789% |
| Untargeted net cash flow | 251.895% | 250.829% |

The wage targets change when the bridge is reconstructed, so the wage-error comparison also reflects that measurement change. The Y, Q and cash-flow target series are unchanged. Cash flow is untargeted; its large error remains a mapping warning, not a new estimation moment. None of these are out-of-sample or full-equilibrium validation results.

## Why the ordering still fails

Fixing populations removes the secular increase in the measured skilled/unskilled labor mix. The unrestricted joint estimate of xi turns positive, and the absolute xi−nu gap falls by 93.71%. This demonstrates that the earlier negative skilled spillover was sensitive to labor mapping. It does not establish that all model restrictions now hold.

With constant theta and alpha,

\[
(1-\rho)(\xi-\nu)=
\frac{\operatorname{Cov}(\log N,\log(w_H/w_L)+\rho\log(X/L))}{\operatorname{Var}(\log N)}.
\]

At rho=2, the fitted gap decomposes exactly into **-0.058314850** from the skill-premium term and **-0.056175804** from relative inputs, summing to **-0.114490654**. The remaining failure is the sign/order implied by those mapped series and the maintained relative-wage equation. It is not produced by a solver boundary or a coding sign error: datewise CES recovery has maximum relative error 4.44e-16, and synthetic recovery with admissible constants passes.

The closed-cone fit xi>=nu>=0 reaches **xi=nu=1.124165**, with a=0.002890669, A_Xbar=0.267048, A_Lbar=0.206704. Its objective rises by only **0.1287%**, from 0.063364990 to 0.063446515. Equality still violates the strict unbalanced-growth primitive. The small objective cost is conditional on the residual weights and is not a statistical rejection test or a confidence region.

## Executed sensitivity checks

Every case below uses the same fixed H and L. Changing the entry-block weight or diagnostic markup does not restore xi>nu. No time-varying exogenous series is reintroduced.

| Diagnostic markup | Entry-block weight | a | xi | nu | xi−nu |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 3.25 | 1 | 0.00287513 | 1.372825 | 1.520215 | -0.147390 |
| 3.5 | 1 | 0.00289067 | 1.066920 | 1.181410 | -0.114491 |
| 4 | 1 | 0.00291627 | 0.781761 | 0.865613 | -0.083852 |
| 3.5 | 0.1 | 0.00289068 | 1.066916 | 1.181406 | -0.114490 |
| 3.5 | 10 | 0.00289067 | 1.066920 | 1.181411 | -0.114491 |

P3 is also recomputed, with its OLS and relative-Q WLS variants in [p3_diagnostic.json](results/p3_diagnostic.json). Freeing the markup does not produce an admissible inverse markup. With theta externally fixed, P3 reuses the entry restriction and supplies no additional independent moment.

## Scope, verification and reproduction

The change makes the labor endowments consistent with the model's time invariance. It does not convert CPS employment into observed young-cohort population masses, equate an hourly premium with annual compensation differences, align all sector perimeters, or convert an annual period into an OLG generation. RoW, finance, regime-b parameters and transition laws remain outside this production-block calibration. The necessary screen xi>nu>0 is not the complete cross-regime condition xi_u>nu_u>nu_b>=0.

Tests verify known-parameter recovery with fixed and variable labor, unit invariance, entry timing, invalid-allocation rejection, rank-deficient P3 rejection, sample-only averaging, preservation of compensation and the premium, and constant labor in every executed scenario. The original central fit is reproduced and all 195 preserved Run 1 files are hash checked. [validation.json](results/validation.json) records the run identities, units/scope checks and runtime; [input_manifest.csv](results/input_manifest.csv) records hashes of the frozen inputs, manuscript and active code.

From the `Do` directory:

```sh
uv run --no-project --python 3.12 --with-requirements shared/requirements.txt python -B shared/rebuild.py --run runs/02_fixed_mean_labor
```

This rebuilds results, tests, report, slide evidence, editable LaTeX and the PDF. It does not rerun or overwrite Run 1. Source data remain in the project empirical-data package, and the exact observed panel used for this comparison is frozen in `inputs/observed_panel.csv`.
