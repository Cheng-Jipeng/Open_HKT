# Open_HKT

Numerical implementation of a **two-country overlapping-generations (OLG) bubble model**, extending [HKT (2025)](https://arxiv.org/abs/2501.08215) to an open-economy setting with two countries (US and Rest of World). The model studies the existence and dynamics of rational asset-price bubbles under regime-switching growth.

This repository contains **two solvers**:

1. **Endowment economy** (`Reference_draft/V9_endowment.tex` ↔ `TwoCountryOLG.jl`) — exogenous endowment and dividend processes, 5×5 BGP and 6×6 u-path systems.
2. **Production economy** (`Reference_draft/V4_3_production.tex` ↔ `TwoCountryProductionOLG.jl`) — endogenous CES production, R&D-driven knowledge growth, HKT per-variety stocks, IPO transfers, and a reduced 7-equation Markov competitive equilibrium (7×7 BGP and 7×7 u-path systems). The current companion draft is `V4_3_production.tex`; it supersedes the earlier `V9_production.tex`.

## Overview

The project solves a two-country OLG model with:

- **Regime switching** — The economy alternates between an *unbalanced-growth* state (US grows faster) and a *balanced-growth* (absorbing) state.
- **Portfolio frictions** — Home-bias costs, convenience yields on US bonds for foreign investors, and bond-issuance costs.
- **Bubble diagnostics** — Numerical tests for the theoretical summability conditions of HKT-type rational bubbles.

The production economy (companion draft `V4_3_production.tex`) further endogenises:

- **Production block** — CES technology $Y_i = F_i(A_{X,i}\,\varphi_i H_i,\, A_{L,i} L_i)$ with skilled $H_i$ and unskilled $L_i$ workers; within-country firm symmetry is a *derived lemma*, not an assumption.
- **Per-variety HKT stocks** — primitive stock object is $q_{i,t} = w_{H,i,t}/(a_i N_{i,t})$, dividend $d_{i,t} = (1-\vartheta_i)/\vartheta_i \cdot w_{H,i,t} \cdot \varphi_{i,t} H_i / N_{i,t}$.
- **Endogenous labour allocation** — $\varphi_{i,t}$ split between intermediate production and R&D, where R&D drives knowledge growth $N_{i,t+1} = (1+a_i(1-\varphi_{i,t})H_i)\,N_{i,t}$.
- **IPO transfers & output identity** — $\mathcal I_{i,t} = (1-\varphi_{i,t})H_i w_{H,i,t} = (N_{i,t+1}-N_{i,t})\,q_{i,t}$, giving the corrected decomposition $Y_{i,t} = e_{i,t} + \mathcal D_{i,t} - \mathcal I_{i,t}$ (the V9 draft used $Y = e + \mathcal D$).
- **Markov competitive equilibrium** — a reduced 7-equation system in $(\varphi_{US},\varphi_W,\omega,\theta_{US}^*,\omega^*,R_f,R_f^W)$; the bond shares $\theta$ and $\theta_W^*$ are *recovered* from zero-net-supply clearing rather than solved for.
- **Effective-kernel regularity** — the diagnostic $\Psi_t = 1-\lambda_t+\phi_t(1-\omega_t) > 0$ required for the bubble theorem.
- **Common-world-growth selection** — when `common_world_growth=true`, each selected absorbing successor BGP recalibrates a local $\nu_b^{eff}$ so $G_b = G_W$ at that switch date.

## Repository Structure

```
├── TwoCountryOLG.jl                # Endowment-economy module
├── TwoCountryProductionOLG.jl      # Production-economy module (V4_3)
├── SingleCountryOLG.jl             # Single-country baseline module
├── Reference_draft/
│   ├── V4_3_production.tex          # Companion paper — production economy (latest)
│   └── V9_endowment.tex            # Companion paper — endowment economy
├── Previous_reference_draft/
│   └── V7_Theorem_Conditions.tex   # Earlier endowment draft (superseded)
├── Project.toml                    # Julia project dependencies
├── Manifest.toml                   # Julia dependency lock
│
├── 01_model_setup.ipynb            # endow: parameters, exogenous paths
├── 02_balanced_state.ipynb         # endow: 5×5 balanced-state solver
├── 03_unbalanced_path.ipynb        # endow: 6×6 u-path backward induction
├── 04_bubble_diagnostics.ipynb     # endow: bubble-existence conditions
├── 05_comparative_statics.ipynb    # endow: sensitivity analysis
├── 06_nfa_decomposition.ipynb      # endow: NFA dynamics
├── 07_single_country_baseline.ipynb # endow: one-country baseline
│
├── 01_v9_model_setup.ipynb         # V4_3: parameters, production block
├── 02_v9_bgp.ipynb                 # V4_3: reduced 7-eq absorbing-regime BGP
├── 03_v9_unbalanced_branch.ipynb   # V4_3: forward-backward u-branch
├── 04_v9_bubble_diagnostics.ipynb  # V4_3: Theorem 1 + Ψ-regularity
├── 05_v9_simulation_path.ipynb     # V4_3: switch-path simulation + baseline export
├── 06_v9_nfa_decomposition.ipynb   # V4_3: fundamental value q=v+B, leakage, ΔNFA = ΔA+ΔV+ΔB
├── 07_v9_assumption_checks.ipynb   # V4_3: numerical check of equilibrium-selection & regularity assumptions
│
└── comparative_statics_chi_check.ipynb  # endowment: χ comparative-statics validation
```

> **Note on `.jl` vs `.ipynb`.** The `*OLG.jl` files are *library modules* loaded via `include(...)` from the notebooks, so they remain `.jl`.
> The former batch scripts (`scripts/run_v9_baseline.jl`, `scripts/check_comparative_statics_chi.jl`) have been converted to notebooks: the baseline solve-and-export pipeline now lives in §6 of `05_v9_simulation_path.ipynb`, and the χ validation in `comparative_statics_chi_check.ipynb`.

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

# 4. Run the endowment economy simulation
include("TwoCountryOLG.jl")
result = run_simulation()

# 5. Run the production economy (V4_3) — defaults are HKT-matched
include("TwoCountryProductionOLG.jl")
p_prod = ProductionParams(T_max=100)   # defaults reproduce HKT (2025) §4.2
result_prod = run_production_simulation(p_prod)
@show result_prod.branch_converged result_prod.max_u_residual
```

To produce all V4_3 outputs (CSVs + plots + residual report), run
`05_v9_simulation_path.ipynb` (§6 is the export section) — interactively,
or headlessly with `nbconvert`:

```bash
jupyter nbconvert --to notebook --execute 05_v9_simulation_path.ipynb
# → outputs_v43/  (bgp_solution.csv, unbalanced_branch_solution.csv,
#                   simulation_path.csv, residual_report.txt, *.png)
# CSVs use the V4_3 25-column schema (adds I_US, I_W, Psi).
```

Check `result_prod.branch_converged` and `result_prod.max_u_residual`
before interpreting the bubble diagnostics.  If the u-branch does not meet
the residual tolerance, the notebooks still report the path, but mark the
diagnostics and exports as provisional in `residual_report.txt`.

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

Run the production notebooks in order (`01_v9_` through `05_v9_`), or the endowment notebooks (`01_` through `07_`), for a guided walkthrough of the model and results. `comparative_statics_chi_check.ipynb` is a standalone endowment validation/plot companion.

## Model Parameters

Each OLG period represents approximately **5 years**.

### Endowment economy (`TwoCountryOLG.jl`, `ModelParams`)

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
| Scratch buffer | n_buffer | auto | Extra all-u periods solved beyond `T_max` before trimming |

### Production economy (`TwoCountryProductionOLG.jl`, `ProductionParams`)

| Parameter | Symbol | Default | Description |
|-----------|--------|---------|-------------|
| Discount factor | β | 0.50 | Saving propensity |
| Risk aversion | γ | 0.50 | CRRA curvature (γ < 1 aids bubble existence) |
| Home-bias cost | κ | 0.10 | Quadratic portfolio-weight cost |
| US equity target (US) | ω̄ | 0.80 | US investor target weight on US equity |
| US equity target (RoW) | ω̄* | 0.20 | RoW investor target weight on US equity |
| US-bond convenience | χ | 0.005 | RoW convenience yield on US bonds |
| Issuance cost | η | 0.01 | Scaling of Υ(θ) = −log(1−θ) + θ²/2 |
| Persistence | π | 0.70 | P(z′=u ∣ z=u) |
| US CES weight / elasticity | α_US, ρ_US | 0.50, 2.00 | HKT α=½, ρ=2 (ρ_US > 1 required for the bubble theorem) |
| US Dixit–Stiglitz | ϑ_US | 0.50 | HKT θ=½ |
| US R&D / labour | a_US, H_US, L_US | 0.20, 1.0, 1.0 | HKT a·H=0.2 ⇒ G_u→1.2 |
| US productivity coeff. | A_X·H, A_L·L | 10.0, 1.0 | HKT A_XH=10, A_LL=1 (u and b regimes) |
| RoW CES weight / elasticity | α_W, ρ_W | 0.50, 2.00 | RoW mirrors HKT's balanced regime |
| RoW Dixit–Stiglitz | ϑ_W | 0.50 | |
| RoW R&D / labour | a_W, H_W, L_W | 0.20, 1.0, 1.0 | |
| Absorbing exponent | ν_b | 0.10 → local ν_b_eff | HKT seed ξ_b=λ_b=0.1; recalibrated for each selected BGP when `common_world_growth=true` |
| Unbalanced exponents | ξ_u, ν_u | 0.70, 0.20 | HKT ξ_u=0.7, λ_u=0.2 (require ξ_u > ν_u > ν_b) |
| RoW exponent | ξ_W | 0.10 | HKT balanced exponent |
| Horizon | T_max | 100 | OLG periods (HKT figure horizon) |

> **The defaults above are the HKT-matched calibration.** `ProductionParams()`
> reproduces the single-country numerical example of
> [HKT (2025), §4.2](https://arxiv.org/abs/2501.08215):
> β = ½, α = ½, ρ = 2, ϑ (θ) = ½, A_X·H = 10, A_L·L = 1,
> ξ_u = 0.7, ν_u (= λ_u) = 0.2, ν_b = ξ_W (= ξ_b = λ_b) = 0.1, a·H = 0.2, N₀ = 1,
> with RoW mirroring HKT's balanced-growth regime. The portfolio block
> (κ, ω̄, ω̄*, χ, η, π) has no HKT counterpart.
>
> HKT's gentle knowledge growth (a·H = 0.2 ⇒ G_u → 1.2) makes the unbalanced
> labour share φ_US decay slowly, so the bubble develops over ~100 periods and the
> u-branch solver stays well-conditioned to **T ≥ 100**. The original fast-growth
> example (a_US·H = 1.2 ⇒ G_u → 2.2, which hits a corner-conditioning wall near
> **T ≈ 20**) is recovered via `fast_growth_params()` (§14 of
> `TwoCountryProductionOLG.jl`).
>
> **Common world growth is on by default** (`common_world_growth=true`). The V4_3
> bubble theorem `thm_prod_sufficient` is proved under
> `ass_absorbing_stationary_equilibrium_selection`, which imposes `G_b = G_W`. HKT's
> literal `ν_b = 0.1` is a single-country primitive with no such constraint. The
> benchmark therefore treats common growth as an equilibrium selection: whenever the
> solver evaluates a possible switch date, it recalibrates a local `ν_b_eff` for that
> selected post-switch BGP and stores it on the `BGPResult`. Set
> `common_world_growth=false` to hold `ν_b = 0.1` exactly.

## Module Architecture

### `TwoCountryOLG.jl` (endowment economy)

12 sections from `ModelParams` through `run_simulation()` — see source comments. Solves a 5×5 BGP system and a 6×6 u-path system.

### `TwoCountryProductionOLG.jl` (production economy, V4_3)

| # | Section | Purpose |
|---|---------|---------|
| 1 | `ProductionParams` | Parameter struct with CES, productivity, growth, and convergence settings |
| 2 | Issuance cost | `LogQuadraticCost`: Υ(θ) = −log(1−θ) + θ²/2 |
| 3 | CES production | `ces_F`, `ces_FX`, `ces_FL` (with Cobb-Douglas limit) |
| 4 | Country block | `compute_production` (returns the IPO transfer `I`), `us_block`, `row_block`, `productivity_US/W`, `compute_psi` |
| 5 | Result structs | `BGPResult`, `UPeriodState` (both carry `I_US`, `I_W`, `Psi`), `ProductionDiagnostics` (carries `psi_min`, `psi_ok`), `ProductionSimulationResult` |
| 6 | BGP solver | `solve_bgp_at()` — reduced 7×7 system with sigmoid/log transforms; primary bond unknown $\theta_{US}^* > 0$ |
| 7 | Common-world-growth | `solve_selected_bgp_at()` / `calibrate_common_growth()` — switch-date BGP selection with local $\nu_b^{eff}$ such that $G_b=G_W$ |
| 8 | Knowledge paths | `knowledge_path_US/W()` from a $\varphi$-path |
| 9 | u-Branch residual | `u_residual!()` — 7 equations with two stochastic successors (u, b) |
| 10 | Backward induction | `solve_unbalanced_branch()` — forward-backward sweeps + spurious-solution rejection + neighbour interpolation + optional global polish |
| 11 | Diagnostics | `compute_diagnostics()` — V4_3 Theorem 1 conditions (1a), (1b) + Ψ-regularity check |
| 12 | Orchestrator | `run_production_simulation()` — top-level entry point |
| 14 | Fast-growth calibration | `fast_growth_params()` — recovers the original fast-growth example (a_US·H = 1.2, T ≈ 20 wall); the `ProductionParams` defaults are now HKT-matched (§1) |
| 15 | Fundamental value & NFA | `us_effective_kernel`, `fundamental_value_path`, `nfa_decomposition` — per-variety $q=v+B$, aggregate $\mathcal Q=V_Q+B_Q$, and gap identity $\Delta NFA=\Delta A+\Delta V+\Delta B$; result-level NFA uses the extended scratch-buffer path and trims to the reported horizon (used by `06_v9_nfa_decomposition.ipynb`) |

Relative to the endowment solver, the production solver introduces a 7th unknown for the RoW risk-free rate $R_f^W$, endogenous labour allocations $\varphi_{US}, \varphi_W$ replacing exogenous endowment/dividend ratios, per-variety stocks recovered from the HKT IPO condition $q_i = w_{H,i}/(a_i N_i)$, and the productivity-driven decay $\varphi_{US,t}^u \lesssim N_{US,t}^{-\psi_{US}/\rho_{US}}$ with $\psi_{US} = (\xi_u-\nu_u)(\rho_{US}-1)$ (V4_3 `lem_prod_orders` proves this **one-sided upper bound**; the empirical decay exponent approaches $\psi_{US}/\rho_{US}$ from below — see `07_v9_assumption_checks.ipynb`).

#### Production all-`u` path algorithm

The production all-`u` path is solved by a **forward-backward fixed point** because the state path is endogenous:

$$
N_{US,t+1}=G_{US}(\varphi_{US,t})N_{US,t},\qquad
N_{W,t+1}=G_W(\varphi_{W,t})N_{W,t}.
$$

Thus today's labour allocations determine tomorrow's knowledge stocks, and those stocks determine the switch-branch BGP used in today's Euler equations.

1. Set the internal horizon to $T_{solve}=T_{report}+n_{buffer}$, where `n_buffer=-1` means `max(5, ceil(T_report/5))`. The buffer absorbs finite-terminal artifacts and is trimmed before reporting.
2. Initialise the policy path
   $y_t^u=(\varphi_{US,t},\varphi_{W,t},\omega_t,\theta_{US,t}^*,\omega_t^*,R_{f,t},R_{f,t}^W)$
   from date-specific selected BGP guesses.
3. Given the current $\varphi$ path, forward-compute $\{N_{US,t},N_{W,t}\}_{t=1}^{T_{solve}+1}$ with `knowledge_path_US/W`.
4. At each possible switch date, solve the selected absorbing BGP at the inherited state:
   $$
   BGP_t = \texttt{solve\_selected\_bgp\_at}(N_{US,t},N_{W,t}).
   $$
   When `common_world_growth=true`, this step recalibrates the local $\nu_b^{eff}$ so the selected post-switch BGP satisfies $G_b=G_W$.
5. Close the artificial all-`u` terminal successor by local log-linear decay extrapolation, not by switching to BGP:
   $$
   \varphi_{i,T+1}=\frac{\varphi_{i,T}^2}{\varphi_{i,T-1}},
   \qquad i\in\{US,W\}.
   $$
   The other terminal coordinates are carried forward only as warm-start values; the u-successor in the residual uses the successor allocations.
6. Backward-induct from $T_{solve}$ to 1. At date $t$, solve the 7-equation u-system `u_residual!` using current state $(N_{US,t},N_{W,t})$, u-successor allocations $(\varphi^u_{US,t+1},\varphi^u_{W,t+1})$, and switch successor `bgp_seq[t+1]` at $(N_{US,t+1},N_{W,t+1})$.
7. Update the policy path and repeat the forward BGP pass and backward u-pass until reported-region residuals are below tolerance and the policy path stabilises. Spurious/corner solutions are rejected and replaced by neighbour interpolation; an optional stacked $7T$ global polish can be applied.
8. Build the full extended `u_path`, keep `u_path_extended` and `bgp_seq_extended` for quantitative objects such as `fundamental_value_path(result)`, and return only the reported slices `u_path_extended[1:T_report]` and `bgp_seq_extended[1:T_report+1]`.

#### V4_3 upgrades over the earlier V9 draft

- **IPO transfer & output identity** — `compute_production` returns $\mathcal I_i = (1-\varphi_i)H_i w_{H,i}$, and the corrected identity $Y_i = e_i + \mathcal D_i - \mathcal I_i$ is asserted at machine precision (V9 used $Y_i = e_i + \mathcal D_i$).
- **Bond-unknown convention** — the reduced system's primary unknown is the RoW US-bond demand $\theta_{US}^* > 0$; the US issuance share $\theta = -\theta_{US}^*\,A^*/A < 0$ and $\theta_W^* = 0$ are recovered from clearing.
- **Effective-kernel regularity** — `compute_psi` evaluates $\Psi_t = 1-\lambda_t+\phi_t(1-\omega_t)$, and `ProductionDiagnostics` records `psi_min`/`psi_ok` (a Theorem 1 prerequisite).
- **Markov competitive equilibrium** — terminology and the reduced state-by-state characterization follow `V4_3_production.tex`; within-country production symmetry is a derived lemma.
- **Outputs** — CSV exports use a 25-column schema (adds `I_US`, `I_W`, `Psi`) written to `outputs_v43/` (the legacy `outputs_v9/` 22-column files are left untouched).

## References

- Hirano, T., Kishi, K., & Toda, A. A. (2025).  *Technological Innovations Generating Rational Bubbles*. [arXiv:2312.11956](https://arxiv.org/abs/2501.08215)

## Notes on Corollary 1 Condition (2b) — endowment economy

*(This section concerns the **endowment** solver, whose bubble test uses Corollary 1 conditions (2a)/(2b). The production economy instead uses the V4_3 Theorem 1 conditions (1a)/(1b) plus the Ψ-regularity check, computed in `04_v9_bubble_diagnostics.ipynb`.)*

Condition (2b) requires summability of

$$
\sum_t \left(\frac{C_t^b}{C_t^u}\right)^{1-\gamma}.
$$

In simulations, this term is numerically close to \((R_{A,t}^b/R_{A,t}^u)^{1-\gamma}\). If the return ratio stays close to a positive constant (often near 1), the series may fail to converge over long horizons.

Practical levers to move the path of \(R_A^b/R_A^u\):

- **Regime persistence (`π_persist`)**: lower persistence increases switching risk, which can widen differences between continuation (`u`) and switch (`b`) returns.
- **Relative growth gap (`g_e_u`, `g_e_b`, `g_D_u`)**: larger state-dependent growth wedges typically increase spread between the two return objects.
- **Risk curvature (`γ`)**: changing \(1-\gamma\) alters how strongly return ratios map into condition (2b) terms.
- **Portfolio frictions (`κ`, `χ`, `η`)**: these reshape equilibrium portfolios and bond positions, which feed into portfolio returns and thus \(R_A^b/R_A^u\).

For diagnostics, notebook `04_bubble_diagnostics.ipynb` plots `consump_ratio[t] = ret_b.R_A / ret_u.R_A`, which is the direct empirical object behind condition (2b).
