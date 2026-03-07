# Open_HKT

Numerical implementation of a **two-country overlapping-generations (OLG) bubble model**, extending [HKT (2025)](https://arxiv.org/abs/2501.08215) to an open-economy setting with two countries (US and Rest of World). The model studies the existence and dynamics of rational asset-price bubbles under regime-switching growth.

## Overview

The project solves a two-country OLG model with:

- **Regime switching** — The economy alternates between an *unbalanced-growth* state (US grows faster) and a *balanced-growth* state (both countries grow at the same rate).
- **Portfolio frictions** — Home-bias costs, convenience yields on US bonds for foreign investors, and bond-issuance costs.
- **Bubble diagnostics** — Numerical tests for theoretical conditions under which rational bubbles can exist.

The solution uses a two-phase algorithm:

1. **Phase 1 (Balanced-state solver):** Solves a 5×5 nonlinear system for the deterministic balanced-growth-path equilibrium.
2. **Phase 2 (u-path solver):** Uses backward induction to solve a 6×6 nonlinear system along the unbalanced-growth path, period by period.

## Repository Structure

```
├── TwoCountryOLG.jl           # Core Julia module (model, solvers, diagnostics)
├── Corollary_V3.tex           # Companion LaTeX paper with theory and proofs
├── Project.toml               # Julia project dependencies
├── Manifest.toml              # Julia dependency lock file
├── 01_model_setup.ipynb       # Notebook: parameters, exogenous paths, validation
├── 02_balanced_state.ipynb    # Notebook: solve & inspect balanced-growth equilibria
├── 03_unbalanced_path.ipynb   # Notebook: backward induction along the u-path
├── 04_bubble_diagnostics.ipynb# Notebook: test bubble-existence conditions (2a), (2b)
├── 05_comparative_statics.ipynb # Notebook: sensitivity analysis over parameters
└── 06_nfa_decomposition.ipynb # Notebook: net foreign asset dynamics & bubble burst
```

## Requirements

- [Julia](https://julialang.org/) ≥ 1.10
- Julia packages (installed automatically via `Project.toml`):
  - **NLsolve** — nonlinear equation solving
  - **ForwardDiff** — automatic differentiation for Jacobians
  - **Parameters** — `@with_kw` macro for default-valued structs
  - **Plots** — visualisation
  - **LaTeXStrings** — LaTeX-formatted labels in plots
  - **IJulia** — Jupyter kernel for Julia notebooks

## Getting Started

```julia
# 1. Clone the repository
git clone https://github.com/Cheng-Jipeng/Open_HKT.git
cd Open_HKT

# 2. Start Julia and activate the project environment
julia --project=.

# 3. Install dependencies (first time only)
using Pkg; Pkg.instantiate()

# 4. Run the simulation
include("TwoCountryOLG.jl")
result = run_simulation()
```

The call to `run_simulation()` will:
1. Validate the calibrated parameters.
2. Generate exogenous endowment and dividend paths.
3. Solve balanced-growth equilibria for every potential switch date.
4. Solve the unbalanced-growth path by backward induction.
5. Compute bubble diagnostics and print a summary.

### Running the Notebooks

```bash
# Start Jupyter with the Julia kernel
julia --project=. -e 'using IJulia; notebook(dir=".")'
```

Run the notebooks in order (`01_` through `06_`) for a guided walkthrough of the model and results.

## Model Parameters

Each OLG period represents approximately **5 years**. Key baseline calibration:

| Parameter | Symbol | Default | Description |
|-----------|--------|---------|-------------|
| Discount factor | β | 0.50 | Saving propensity out of young-age income |
| Risk aversion | γ | 0.50 | Old-age CRRA curvature (γ < 1 aids bubble existence) |
| Home-bias cost | κ | 0.01 | Quadratic cost of deviating from target portfolio weight |
| US equity target (US) | ω̄ | 0.80 | US investor target weight on US equity |
| US equity target (RoW) | ω̄* | 0.20 | RoW investor target weight on US equity |
| Convenience yield | χ | 0.03 | RoW convenience yield on US bonds |
| Issuance cost | η | 0.01 | Scaling of bond-issuance cost function |
| Persistence | π | 0.70 | Probability that unbalanced growth continues |
| US growth (unbalanced) | g_e,u | 1.035⁵ | US endowment growth per period in state u |
| Balanced growth | g_e,b | 1.02⁵ | Common growth rate in the balanced state |
| Horizon | T_max | 120 | Number of OLG periods simulated |

## Module Architecture (`TwoCountryOLG.jl`)

The module is organised into 12 sections:

| # | Section | Purpose |
|---|---------|---------|
| 1 | `ModelParams` | Parameter struct with defaults and `validate_params()` |
| 2 | Issuance cost | `LogQuadraticCost`: Υ(θ) = −log(1−θ) + θ²/2 |
| 3 | Exogenous paths | `generate_exogenous_paths()` builds endowment & dividend series |
| 4 | Returns | `compute_returns()` calculates equity, portfolio, and total returns |
| 5 | Kernel helpers | `us_kernel()`, `row_kernel()` for stochastic discount factors |
| 6 | Market-cap identity | `Qsum()` aggregate market capitalisation |
| 7 | Result structs | `BalancedStateResult`, `PeriodState`, `BubbleDiagnostics`, `SimulationResult` |
| 8 | Balanced-state solver | `solve_balanced_state()` — Phase 1 (5×5 system, trust-region + fallbacks) |
| 9 | u-Path residual | Core 6-equation residual with constrained/unconstrained formulations |
| 10 | Backward induction | `solve_u_path()` — Phase 2 (6 solver strategies, warm-starting) |
| 11 | Bubble diagnostics | `compute_bubble_diagnostics()` — tests conditions (2a) and (2b) |
| 12 | Orchestrator | `run_simulation()` — top-level entry point |

## References

- Hirano, T., Kishi, K., & Toda, A. A. (2025).  *Technological Innovations Generating Rational Bubbles*. [arXiv:2312.11956](https://arxiv.org/abs/2501.08215)

## Notes on Corollary 1 Condition (2b)

Condition (2b) requires summability of

$$
\sum_t \left(\frac{C_t^b}{C_t^u}\right)^{1-\gamma}.
$$

In simulations, this term is numerically close to
\((R_{A,t}^b/R_{A,t}^u)^{1-\gamma}\). If the return ratio stays close to a positive
constant (often near 1), the series may fail to converge over long horizons.

Practical levers to move the path of \(R_A^b/R_A^u\):

- **Regime persistence (`π_persist`)**: lower persistence increases switching risk,
  which can widen differences between continuation (`u`) and switch (`b`) returns.
- **Relative growth gap (`g_e_u`, `g_e_b`, `g_D_u`)**: larger state-dependent growth
  wedges typically increase spread between the two return objects.
- **Risk curvature (`γ`)**: changing \(1-\gamma\) alters how strongly return ratios map
  into condition (2b) terms.
- **Portfolio frictions (`κ`, `χ`, `η`)**: these reshape equilibrium portfolios and
  bond positions, which feed into portfolio returns and thus \(R_A^b/R_A^u\).

For diagnostics, notebook `04_bubble_diagnostics.ipynb` plots
`consump_ratio[t] = ret_b.R_A / ret_u.R_A`, which is the direct empirical object
behind condition (2b).
