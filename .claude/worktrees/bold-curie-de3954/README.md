# Open_HKT

Numerical implementation of a **two-country overlapping-generations (OLG) bubble model**, extending [HKT (2025)](https://arxiv.org/abs/2501.08215) to an open-economy setting with two countries (US and Rest of World). The model studies the existence and dynamics of rational asset-price bubbles under regime-switching growth.

This repository contains **two solvers**:

1. **V7 endowment economy** (`V7_Theorem_Conditions.tex` ↔ `TwoCountryOLG.jl`) — exogenous endowment and dividend processes, 5×5 BGP and 6×6 u-path systems.
2. **V9 production economy** (`V9_production.tex` ↔ `TwoCountryProductionOLG.jl`) — endogenous CES production, R&D-driven knowledge growth, HKT per-variety stocks, 7×7 BGP and 7×7 u-path systems.

## Overview

The project solves a two-country OLG model with:

- **Regime switching** — The economy alternates between an *unbalanced-growth* state (US grows faster) and a *balanced-growth* (absorbing) state.
- **Portfolio frictions** — Home-bias costs, convenience yields on US bonds for foreign investors, and bond-issuance costs.
- **Bubble diagnostics** — Numerical tests for the theoretical summability conditions of HKT-type rational bubbles.

The V9 production economy further endogenises:

- **Production block** — CES technology $Y_i = F_i(A_{X,i}\,\varphi_i H_i,\, A_{L,i} L_i)$ with skilled $H_i$ and unskilled $L_i$ workers.
- **Per-variety HKT stocks** — primitive stock object is $q_{i,t} = w_{H,i,t}/(a_i N_{i,t})$, dividend $d_{i,t} = (1-\vartheta_i)/\vartheta_i \cdot w_{H,i,t} \cdot \varphi_{i,t} H_i / N_{i,t}$.
- **Endogenous labour allocation** — $\varphi_{i,t}$ split between intermediate production and R&D, where R&D drives knowledge growth $N_{i,t+1} = (1+a_i(1-\varphi_{i,t})H_i)\,N_{i,t}$.
- **Common-world-growth calibration** — adjusts $\nu_b$ via damped fixed-point iteration so $G_b = G_W$ at the BGP.

## Repository Structure

```
├── TwoCountryOLG.jl                # V7 endowment-economy module
├── TwoCountryProductionOLG.jl      # V9 production-economy module (NEW)
├── V7_Theorem_Conditions.tex       # Companion paper for V7 endowment
├── ../Reference_draft/V9_production.tex  # Companion paper for V9 production
├── Project.toml                    # Julia project dependencies
├── Manifest.toml                   # Julia dependency lock
│
├── 01_model_setup.ipynb            # V7: parameters, exogenous paths
├── 02_balanced_state.ipynb         # V7: 5×5 balanced-state solver
├── 03_unbalanced_path.ipynb        # V7: 6×6 u-path backward induction
├── 04_bubble_diagnostics.ipynb     # V7: bubble-existence conditions
├── 05_comparative_statics.ipynb    # V7: sensitivity analysis
├── 06_nfa_decomposition.ipynb      # V7: NFA dynamics
├── 07_single_country_baseline.ipynb # V7: one-country baseline
│
├── 01_v9_model_setup.ipynb         # V9: parameters, production block
├── 02_v9_bgp.ipynb                 # V9: 7×7 absorbing-regime BGP
├── 03_v9_unbalanced_branch.ipynb   # V9: forward-backward u-branch
├── 04_v9_bubble_diagnostics.ipynb  # V9: Theorem 1 conditions
├── 05_v9_simulation_path.ipynb     # V9: switch-path simulation
│
└── scripts/
    ├── check_comparative_statics_chi.jl
    └── run_v9_baseline.jl          # End-to-end V9 baseline driver (NEW)
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

# 4. Run the V7 endowment economy simulation
include("TwoCountryOLG.jl")
result = run_simulation()

# 5. Run the V9 production economy simulation
include("TwoCountryProductionOLG.jl")
p_v9 = ProductionParams(common_world_growth=true, T_max=30)
result_v9 = run_production_simulation(p_v9)
```

To produce all V9 outputs (CSVs + plots + residual report):

```bash
julia --project=. scripts/run_v9_baseline.jl
# → outputs_v9/  (bgp_solution.csv, unbalanced_branch_solution.csv,
#                  simulation_path.csv, residual_report.txt, *.png)
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

## Module Architecture

### `TwoCountryOLG.jl` (V7 endowment economy)

12 sections from `ModelParams` through `run_simulation()` — see source comments. Solves a 5×5 BGP system and a 6×6 u-path system.

### `TwoCountryProductionOLG.jl` (V9 production economy)

| # | Section | Purpose |
|---|---------|---------|
| 1 | `ProductionParams` | Parameter struct with CES, productivity, growth, and convergence settings |
| 2 | Issuance cost | `LogQuadraticCost`: Υ(θ) = −log(1−θ) + θ²/2 |
| 3 | CES production | `ces_F`, `ces_FX`, `ces_FL` (with Cobb-Douglas limit) |
| 4 | Country block | `compute_production`, `us_block`, `row_block`, `productivity_US/W` |
| 5 | Result structs | `BGPResult`, `UPeriodState`, `ProductionDiagnostics`, `ProductionSimulationResult` |
| 6 | BGP solver | `solve_bgp_at()` — 7×7 system with sigmoid/log transforms for constraints |
| 7 | Common-world-growth | `calibrate_common_growth()` — damped fixed-point on $\nu_b$ such that $G_b=G_W$ |
| 8 | Knowledge paths | `knowledge_path_US/W()` from a $\varphi$-path |
| 9 | u-Branch residual | `u_residual!()` — 7 equations with two stochastic successors (u, b) |
| 10 | Backward induction | `solve_unbalanced_branch()` — forward-backward sweeps + spurious-solution rejection + neighbour interpolation + optional global polish |
| 11 | Diagnostics | `compute_diagnostics()` — V9 Theorem 1 conditions (1a), (1b) |
| 12 | Orchestrator | `run_production_simulation()` — top-level entry point |

Compared to V7, the V9 solver introduces:

- A 7th unknown for the RoW domestic risk-free rate $R_f^W$.
- Endogenous labour allocations $\varphi_{US}, \varphi_W$ replacing exogenous endowment/dividend ratios.
- Per-variety stocks recovered from the HKT IPO condition $q_i = w_{H,i}/(a_i N_i)$ (no separate stock-price unknowns).
- Productivity-driven decay of $\varphi_{US,t}^u \asymp N_{US,t}^{-\psi_{US}/\rho_{US}}$ where $\psi_{US} = (\xi_u-\nu_u)(\rho_{US}-1)$.

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
