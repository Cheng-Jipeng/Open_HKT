# Run 3: skilled labor normalized to one, 2009–2024

**Executed third calibration attempt. Baseline status: REJECTED_P1.** The external baseline fails allocation in every fitting year, exactly as in Run 1. Conditional on the diagnostic markup 3.5, both spillovers are positive, but the ordering is inadmissible by a wide margin: xi = 1.337747 < nu = 3.411007. These diagnostic estimates are not an adopted full-model parameter vector.

- [17-slide LaTeX report](slides/output/calibration_steps_2009_2024_normalized_skilled_labor.pdf)
- [Editable, self-contained Beamer/PGFPlots source](slides/latex/main.tex)
- [Three-run comparison table](results/run_comparison.csv)
- [Variable-role ledger](results/variable_roles.csv)
- [Implementation checks](results/synthetic_tests.json)

## What changes relative to Runs 1 and 2

The sample contains the same 16 annual observations and September 2026 empirical snapshot. Every year from 2009 to 2024 enters fitting; there is no holdout. Only the labor inputs change:

\[
H_t=1,\qquad L_t=1\times\frac{L_t^{\mathrm{obs}}}{H_t^{\mathrm{obs}}}\quad\text{for every }t.
\]

The unit of labor at each date is that year's skilled workforce. H is constant; L is the observed number of unskilled workers per skilled worker and is **time varying**: it falls from 2.772306 (2009) to 1.771445 (2024), with mean 2.217585. The relative endowment L/H is therefore exactly the observed one at every date. No averaging is used. (Dividing both Run 2 constants by the mean of H would only rescale units and reproduce Run 2's xi and nu exactly, so the annual ratio is the informative version of this normalization.)

Output Y, compensation e, valuation Q and the skill premium w_H/w_L remain annual targets. Notation follows V6_production.tex with the US subscript omitted: e=w_H H+w_L L, varphi is the production share, and xi, nu, A_Xbar, A_Lbar below are the regime-u objects xi_u, nu_u, \bar A_{X,u}, \bar A_{L,u}. The markup mu=1/vartheta is calibration shorthand. Wages are reconstructed as

\[
w_{L,t}=\frac{e_t}{\mathrm{prem}_t\cdot 1+L_t},\qquad w_{H,t}=\mathrm{prem}_tw_{L,t},\qquad \mathrm{prem}_t=\text{observed }w_{H,t}/w_{L,t} .
\]

This preserves compensation and the premium exactly, and both wage bills w_H H and w_L L equal their Run 1 values. With H=1, w_H is the skilled wage bill in trillion 2017 USD per year.

The assignments rho=2, baseline markup 1.61, alpha=0.5, N_2009=1, the diagnostic markups 3.25, 3.5 and 4, the residual weights and all P1–P5 equations are unchanged.

## What the normalization does and does not change

Relative to Run 1 the transformation divides H, L and X by the observed H_t and multiplies both wages by it. Three consequences follow from the equations, and the saved results confirm them:

1. **P1 is invariant.** varphi and research payroll I depend only on Y, the wage bills and theta. At mu=1.61, **16/16** years fail; varphi ranges from **1.458710 to 1.748321**; the allocation bound requires mu above **2.814796** (binding in 2010), the same as Run 1 (2.814796). At mu=3.5, varphi lies between 0.671006 and 0.804227.
2. **The innovation law loses its scale effect.** Knowledge growth is G_t=1+a(1−varphi_t) instead of 1+a H_t(1−varphi_t); the growth of the skilled workforce no longer raises knowledge growth. The implied a_t = w_H/(Q−I) is the Run 1 series times H_t, so a is in different units (per unit of skilled workforce per year).
3. **Both augmentation terms absorb the growth of H.** Since A_X X and A_L L are invariant, the datewise inversions satisfy A_X(Run 3)=A_X(Run 1)·H_t and A_L(Run 3)=A_L(Run 1)·H_t. The common log H_t trend raises xi and nu together. The relative series X/L and the premium are identical to Run 1, so the gap xi−nu differs from Run 1 only because it is projected on a different knowledge path.

## Estimated constants and comparison

| Parameter | Run 1 joint: annual labor | Run 2 joint: fixed means | Run 3 sequential | Run 3 joint: H=1 |
| --- | ---: | ---: | ---: | ---: |
| a | 0.003084663 | 0.002890669 | 0.089413729 | 0.089414335 |
| xi | -0.136299491 | 1.066919845 | 1.202602104 | 1.337746846 |
| nu | 1.683308160 | 1.181410499 | 3.784778540 | 3.411007104 |
| A_X scale | 0.337864127 | 0.269849556 | 8.845121958 | 8.731462503 |
| A_L scale | 0.193366781 | 0.204558226 | 4.481176973 | 4.864360040 |
| xi − nu | -1.819607652 | -0.114490654 | -2.582176436 | -2.073260258 |

a and the technology scales depend on the labor units and are not comparable in level across runs; xi and nu are dimensionless elasticities and are comparable. The joint objective is 0.031130381; the optimizer is interior, with Jacobian rank 5. Those are implementation diagnostics conditional on the assigned markup and curvature, not evidence that the economic restrictions hold.

| Relative RMSE | Run 1 | Run 2 | Run 3 |
| --- | ---: | ---: | ---: |
| Output | 1.567% | 1.237% | 2.184% |
| Skilled compensation rate | 1.809% | 1.972% | 2.133% |
| Unskilled compensation rate | 3.279% | 3.997% | 3.934% |
| Enterprise value | 31.299% | 24.789% | 17.218% |
| Untargeted net cash flow | 251.895% | 250.829% | 250.807% |

Wage targets are in different units across runs; relative errors remain comparable. Y, Q and cash-flow targets are unchanged. Cash flow is untargeted; its large error remains a mapping warning. None of these are out-of-sample or full-equilibrium validation results.

## Why the ordering fails

With constant theta and alpha,

\[
(1-\rho)(\xi-\nu)=
\frac{\operatorname{Cov}(\log N,\log(w_H/w_L)+\rho\log(X/L))}{\operatorname{Var}(\log N)}.
\]

At rho=2, the fitted gap decomposes exactly into **-0.074549484** from the skill-premium term and **-1.998710775** from relative inputs, summing to **-2.073260258**. The relative-input term dominates: X/L=varphi_t H_t/L_t rises with the observed skill mix, which the normalization keeps (Run 2 removed it by fixing both stocks). Datewise CES recovery has maximum relative error 4.44e-16.

The closed-cone fit xi>=nu>=0 reaches **xi=nu=2.374376**, with a=0.089414388, A_Xbar=7.446107, A_Lbar=5.704051. Its objective rises by **71.83%**, from 0.031130381 to 0.053492025 (Run 2: 0.13%). Equality still violates the strict unbalanced-growth primitive. The objective cost is conditional on the residual weights and is not a statistical test.

## Executed sensitivity checks

| Diagnostic markup | Entry-block weight | a | xi | nu | xi−nu |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 3.25 | 1 | 0.08895105 | 1.731990 | 4.429741 | -2.697751 |
| 3.5 | 1 | 0.08941434 | 1.337747 | 3.411007 | -2.073260 |
| 4 | 1 | 0.09017782 | 0.973171 | 2.474566 | -1.501395 |
| 3.5 | 0.1 | 0.08941980 | 1.337666 | 3.410801 | -2.073135 |
| 3.5 | 10 | 0.08941379 | 1.337755 | 3.411028 | -2.073273 |

No executed case restores xi>nu. P3 is also recomputed ([p3_diagnostic.json](results/p3_diagnostic.json)): the unrestricted ratio regression gives theta=10.9698>1, an inadmissible inverse markup.

## Scope, verification and reproduction

H=1 is a normalization of the labor unit date by date, so L is not a constant endowment in this run; the model's time-invariant L is relaxed exactly as in Run 1. The run does not convert CPS employment into cohort masses, align sector perimeters, or convert an annual period into an OLG generation. RoW, finance, regime-b parameters and transition laws remain outside this production-block calibration.

[validation.json](results/validation.json) records that H equals one, L equals the observed ratio, the wage bills equal the observed-labor bridge and all targets are unchanged. [input_manifest.csv](results/input_manifest.csv) records hashes of the frozen inputs, manuscript and active code. The shared tests additionally verify that this treatment reproduces the Run 1 allocation.

From the `1_Do` directory:

```sh
uv run --no-project --python 3.12 --with-requirements shared/requirements.txt python -B shared/rebuild.py --run runs/03_normalized_skilled_labor
```

This rebuilds results, tests, report, slide evidence, editable LaTeX and the PDF for Run 3 only. Runs 1 and 2 are read for comparison and never rewritten.
