# Agent Prompt: V4.3 Production-Model Parameter Sweeps for U.S. NFA and Bubble Share

## 0. Goal

Run systematic parameter sweeps / comparative statics for the current production-economy branch of `Open_HKT`, focusing on the V4.3 production model implemented in `TwoCountryProductionOLG.jl` and the production notebooks `01_v9`–`07_v9`.

The project objective is to identify parameter regions where:

1. U.S. net foreign assets are negative for a long part of the simulated unbalanced-growth path,
2. the negative U.S. NFA is meaningfully driven by the U.S. equity boom,
3. the U.S. stock bubble component is quantitatively nontrivial, i.e.
   \[
   B_{US,t}/Q_{US,t}
   \]
   is economically large, not merely asymptotically positive.

The current code’s NFA decomposition uses
\[
NFA_{US,t}=A_t-Q_{US,t}=(A_t-V_{Q,t})-B_{Q,t},
\]
so the aggregate bubble component lowers U.S. NFA one-for-one.

---

## 1. Files and baseline workflow

Use the production economy, not the older endowment economy.

Relevant files:

- `TwoCountryProductionOLG.jl`
- `01_v9_model_setup.ipynb`
- `02_v9_bgp.ipynb`
- `03_v9_unbalanced_branch.ipynb`
- `04_v9_bubble_diagnostics.ipynb`
- `05_v9_simulation_path.ipynb`
- `06_v9_nfa_decomposition.ipynb`
- `07_v9_assumption_checks.ipynb`

Create either:

- a new notebook `08_v9_parameter_sweeps.ipynb`, or
- a script `scripts/run_v43_parameter_sweeps.jl` plus a notebook that loads the resulting CSVs and plots heatmaps.

Prefer a script for batch runs and a notebook for visualization.

Baseline call:

```julia
include("TwoCountryProductionOLG.jl")

p = ProductionParams(T_max=100)
result = run_production_simulation(p)
dec = nfa_decomposition(result)
```

Do not interpret any quantitative output unless:

```julia
result.branch_converged == true
result.max_u_residual <= 1e-5   # exploratory tolerance can be 1e-4, but flag it
result.diagnostics.psi_ok == true
result.diagnostics.equity_weights_ok == true
```

For exploratory sweeps, keep failed or provisional cases in the master table, but mark them clearly.

---

## 2. Main mechanisms and expected directions

### 2.1 Foreign demand / NFA sign channel

These parameters should help make U.S. NFA more negative by increasing foreign demand for U.S. equity and/or foreign financing capacity:

\[
H_W,L_W,\bar\omega^* \uparrow
\quad\Rightarrow\quad
\text{foreign demand for U.S. equity}\uparrow.
\]

Secondary amplifiers:

\[
\chi\uparrow,\quad \eta\downarrow,
\]

but use these carefully because too much bond-convenience demand shifts the story from “foreign-owned U.S. equity boom” toward a safe-asset mechanism.

### 2.2 Bubble-share channel

These parameters should help increase the U.S. bubble share:

\[
\pi, a_{US}, \vartheta_{US}, \nu_u-\nu_b, \xi_u-\nu_u \uparrow,
\qquad
\gamma\downarrow
\quad\Rightarrow\quad
B_{US}/Q_{US}\uparrow.
\]

Key logic:

- `π_persist ↑`: bubble survives longer; continuation coefficient is closer to one.
- `a_US ↑`: faster knowledge growth; faster decline in dividend yield and switch leakage.
- `ϑ_US ↑`: raises per-variety price and lowers dividend yield because
  \[
  d/q=a_{US}\frac{1-\vartheta_{US}}{\vartheta_{US}}\varphi_{US}H_{US}.
  \]
- `ν_u-ν_b ↑`: larger crash / larger u-vs-b valuation gap.
- `ξ_u-ν_u ↑`: larger
  \[
  \psi_{US}=(\xi_u-\nu_u)(\rho_{US}-1),
  \]
  hence faster dividend-yield decay.
- `γ ↓`: strengthens the HKT stochastic-bubble summability channel because the switch-leakage exponent includes \(1-\gamma\).

---

## 3. Parameter ranges

Start from the default `ProductionParams()` values:

```julia
β = 0.50
γ = 0.50
κ = 0.10
ω̄ = 0.80
ω̄_star = 0.20
χ = 0.005
η = 0.01
π_persist = 0.70
ρ_US = 2.00
ϑ_US = 0.50
a_US = 0.20
H_US = 1.0
L_US = 1.0
H_W = 1.0
L_W = 1.0
ν_b = 0.10
ξ_u = 0.70
ν_u = 0.20
ξ_W = 0.10
common_world_growth = true
T_max = 100
```

### 3.1 NFA-sign parameters

#### RoW scale: `H_W`, `L_W`

Primary paired-size sweep:

```julia
m_W_grid = [1.0, 1.5, 2.0, 3.0, 4.0, 5.0]
H_W = m_W
L_W = m_W
```

Run two variants:

1. **Full-scale variant**: keep `a_W = 0.20`.
   - Interpretation: RoW has more workers and more researchers; RoW R&D scale changes.
2. **Pure-demand-size variant**: set
   ```julia
   a_W = 0.20 / m_W
   ```
   so that `a_W * H_W ≈ 0.20` remains fixed.
   - Interpretation: RoW saving capacity rises, but RoW knowledge-growth intensity is held approximately fixed.

Use the pure-demand-size variant if common-growth calibration or BGP selection becomes unstable.

Record:

```julia
G_N_W path
ν_b_eff path
A_star / A
foreign_equity_share = ω_star * S_star / Q_US
```

#### RoW target weight on U.S. equity: `ω̄_star`

Sweep:

```julia
ω̄_star_grid = [0.20, 0.25, 0.30, 0.35, 0.40, 0.50, 0.60]
```

Guardrails:

```julia
0 < ω̄_star < ω̄ = 0.80
0 < realized ω_star < 1
result.diagnostics.equity_weights_ok == true
```

Associated `κ` adjustment:

- If realized `ω_star` barely responds to `ω̄_star`, try larger `κ`:
  ```julia
  κ_grid_enforcement = [0.10, 0.15, 0.20]
  ```
- If the solver becomes unstable or `Psi <= 0`, try smaller `κ`:
  ```julia
  κ_grid_stability = [0.03, 0.05, 0.08]
  ```

Do not interpret `ω̄_star ↑` as successful unless actual `foreign_equity_share` rises.

#### U.S. bond convenience: `χ`

Secondary amplifier only.

Sweep:

```julia
χ_grid = [0.005, 0.01, 0.02, 0.03, 0.05, 0.08]
```

Use this after checking the direct equity-demand channel from `H_W`, `L_W`, and `ω̄_star`.

Associated `η` adjustment:

```julia
η_grid = [0.02, 0.01, 0.005, 0.0025]
```

Interpretation:

- `χ ↑` encourages RoW demand for U.S. bonds.
- `η ↓` lowers the cost of U.S. bond issuance.
- Together they can raise U.S. leverage and indirectly raise demand for U.S. equity through U.S. home bias.

Guardrails:

```julia
min(Psi) > 0
min(R_A_u) > 0
min(R_A_b) > 0
θ not too close to its domain boundary
θ_US_star not exploding
```

If the negative-NFA result relies almost entirely on `χ ↑`, flag this as a safe-asset mechanism rather than the desired foreign-equity-boom mechanism.

---

### 3.2 Bubble-share parameters

#### Regime persistence: `π_persist`

Sweep:

```julia
π_grid = [0.70, 0.80, 0.90, 0.95, 0.97, 0.98]
```

Direction:

```julia
π_persist ↑  =>  B_US/Q_US ↑
```

For high-persistence runs, increase horizon / buffer:

```julia
T_max = 120 or 150
n_buffer = 50 or 100
```

At minimum, rerun high-π candidates with two buffers:

```julia
n_buffer in [25, 50, 100]
```

and report whether `bubble_share` is stable.

#### U.S. R&D productivity: `a_US`

Stable sweep:

```julia
a_US_grid_stable = [0.20, 0.25, 0.30, 0.40, 0.50]
```

Aggressive short-horizon sweep:

```julia
a_US_grid_aggressive = [0.75, 1.00, 1.20]
T_max in [20, 30, 50]
```

Direction:

```julia
a_US ↑  =>  faster N_US growth  =>  lower d/q and lower switch leakage  =>  B_US/Q_US ↑
```

Guardrail:

High `a_US` can create a corner-conditioning problem because `φ_US -> 0` quickly. If the solver fails at `T_max=100`, do not discard the mechanism; rerun with a shorter horizon and report the maximum reliable horizon.

#### U.S. Dixit-Stiglitz elasticity / inverse markup: `ϑ_US`

Sweep:

```julia
ϑ_US_grid = [0.50, 0.55, 0.60, 0.66, 0.70, 0.75, 0.80]
```

Direction:

```julia
ϑ_US ↑  =>  q_US ↑ and d_US/q_US ↓  =>  Q_US/A ↑ and B_US/Q_US ↑
```

Guardrails:

```julia
0 < ϑ_US < 1
```

Do not push too close to one unless explicitly doing an aggressive robustness check, because dividends become mechanically tiny.

#### Risk aversion: `γ`

Sweep:

```julia
γ_grid = [0.50, 0.40, 0.30, 0.20, 0.10, 0.05]
```

Direction:

```julia
γ ↓  =>  switch-leakage summability improves  =>  B_US/Q_US ↑
```

Guardrail:

```julia
0 < γ < 1
```

Keep `γ=0.05` as an aggressive edge case; preferred quantitative candidates should ideally work for `γ >= 0.10` or `γ >= 0.20`.

#### Crash-growth gap: `ν_u - ν_b`

This gap affects the switch-to-BGP leakage term.

Important: if `common_world_growth=true`, the code recalibrates local `ν_b_eff`, so the primitive `ν_b` is not necessarily the realized absorbing exponent. In all runs, record the realized path or summary of `ν_b_eff`.

Run two panels.

**Panel A: theorem-selection panel**

Use:

```julia
common_world_growth = true
ν_u_grid = [0.20, 0.30, 0.40, 0.50]
```

To avoid accidentally reducing `ξ_u-ν_u`, pair with:

```julia
ξ_gap_fixed = 0.50
ξ_u = ν_u + ξ_gap_fixed
```

Also report realized:

```julia
mean_ν_b_eff
min_ν_b_eff
max_ν_b_eff
realized_gap = ν_u - mean_ν_b_eff
```

**Panel B: fixed-primitive sensitivity panel**

Use:

```julia
common_world_growth = false
ν_b_grid = [0.00, 0.02, 0.05, 0.08, 0.10]
ν_u_grid = [0.20, 0.30, 0.40, 0.50]
```

Keep:

```julia
ξ_u = ν_u + 0.50
```

Guardrail:

```julia
ξ_u > ν_u > ν_b >= 0
```

Label Panel B clearly as a fixed-primitive sensitivity check because it may relax the common-growth equilibrium-selection assumption.

#### Unbalanced-spillover gap: `ξ_u - ν_u`

This gap affects:

\[
\psi_{US}=(\xi_u-\nu_u)(\rho_{US}-1).
\]

Sweep by fixed gaps:

```julia
ξ_gap_grid = [0.50, 0.70, 0.90, 1.10]
ν_u_grid_for_gap = [0.20, 0.30, 0.40]
ξ_u = ν_u + ξ_gap
```

Simpler one-dimensional sweep:

```julia
ν_u = 0.20
ξ_u_grid = [0.70, 0.90, 1.10, 1.30]
```

Direction:

```julia
ξ_u - ν_u ↑  =>  ψ_US ↑  =>  d/q falls faster  =>  B_US/Q_US ↑
```

Guardrails:

```julia
ξ_u > ν_u
ψ_US > 0
```

If the solver fails for high `ξ_u`, reduce `T_max` or combine the sweep with moderate rather than aggressive `a_US`.

#### Optional companion: `ρ_US`

Not required by the main request, but useful because it multiplies the same exponent:

```julia
ρ_US_grid = [2.00, 2.50, 3.00]
```

Guardrail:

```julia
ρ_US > 1
```

Only use as a secondary robustness check after the main sweeps above.

---

## 4. Staged sweep design

Avoid a full Cartesian product at the beginning. Use staged sweeps.

### Stage 0: Baseline replication

Run default:

```julia
ProductionParams(T_max=100)
```

Save:

```text
sweep_results/baseline_summary.csv
sweep_results/baseline_nfa_decomposition.csv
sweep_results/baseline_plots/
```

Confirm that the baseline reproduces the current finding: U.S. NFA is negative only in early periods and `bubble_share` is small.

### Stage 1: One-at-a-time sweeps

Run one-dimensional sweeps for:

```julia
H_W=L_W
ω̄_star
χ
π_persist
a_US
ϑ_US
γ
ν_u - ν_b
ξ_u - ν_u
```

For each one-dimensional sweep, hold all other parameters at baseline except required paired adjustments stated above.

### Stage 2: Two-dimensional mechanism grids

#### NFA-demand grid

```julia
m_W_grid = [1.0, 2.0, 3.0, 4.0]
ω̄_star_grid = [0.20, 0.30, 0.40, 0.50]
κ_grid = [0.05, 0.10, 0.15]
```

Run both full-scale and pure-demand-size variants for `m_W`.

#### Bond-amplifier grid

Only after the NFA-demand grid:

```julia
χ_grid = [0.005, 0.01, 0.02, 0.03, 0.05]
η_grid = [0.02, 0.01, 0.005]
```

Condition this grid on promising NFA-demand cases, not the baseline alone.

#### Bubble-growth grid

```julia
π_grid = [0.70, 0.90, 0.95, 0.98]
a_US_grid = [0.20, 0.30, 0.40, 0.50]
```

#### Bubble-dividend-yield grid

```julia
a_US_grid = [0.20, 0.30, 0.40, 0.50]
ϑ_US_grid = [0.50, 0.60, 0.70, 0.80]
```

#### Bubble-exponent grid

```julia
γ_grid = [0.50, 0.30, 0.20, 0.10]
ν_u_grid = [0.20, 0.30, 0.40]
ξ_gap_grid = [0.50, 0.70, 0.90]
ξ_u = ν_u + ξ_gap
```

Run once with `common_world_growth=true`, recording `ν_b_eff`, and once with `common_world_growth=false` for fixed-primitive sensitivity.

### Stage 3: Joint candidate calibrations

After Stage 1–2, construct candidate sets that combine the best directions.

#### Candidate A: conservative

```julia
ProductionParams(
    H_W=2.0, L_W=2.0,
    ω̄_star=0.35,
    κ=0.10,
    χ=0.01,
    η=0.01,
    π_persist=0.90,
    a_US=0.30,
    ϑ_US=0.60,
    γ=0.30,
    ν_u=0.30,
    ξ_u=0.90,
    common_world_growth=true,
    T_max=120,
    n_buffer=50
)
```

#### Candidate B: strong but still plausible

```julia
ProductionParams(
    H_W=3.0, L_W=3.0,
    ω̄_star=0.40,
    κ=0.08,
    χ=0.02,
    η=0.005,
    π_persist=0.95,
    a_US=0.40,
    ϑ_US=0.70,
    γ=0.20,
    ν_u=0.40,
    ξ_u=1.10,
    common_world_growth=true,
    T_max=120,
    n_buffer=100
)
```

#### Candidate C: aggressive diagnostic

```julia
ProductionParams(
    H_W=4.0, L_W=4.0,
    ω̄_star=0.50,
    κ=0.05,
    χ=0.03,
    η=0.005,
    π_persist=0.97,
    a_US=0.50,
    ϑ_US=0.75,
    γ=0.10,
    ν_u=0.50,
    ξ_u=1.30,
    common_world_growth=true,
    T_max=100,
    n_buffer=100
)
```

If Candidate C fails at `T_max=100`, rerun at:

```julia
T_max = 50
n_buffer = 50
```

and report the failure horizon.

---

## 5. Required metrics

For each run, save the parameter values and the following outputs.

### 5.1 Convergence and validity

```julia
branch_converged
max_u_residual
max_bgp_residual
psi_ok
psi_min
equity_weights_ok
equity_weight_min
min_R_A_u
min_R_A_b
min_R_A_star_u
min_R_A_star_b
```

Mark a run as `valid_core=true` only if:

```julia
branch_converged == true
max_u_residual <= 1e-5
max_bgp_residual <= 1e-5
psi_ok == true
equity_weights_ok == true
min_R_A_u > 0
min_R_A_b > 0
```

For exploratory work, allow:

```julia
max_u_residual <= 1e-4
```

but mark `valid_core=false` and `valid_exploratory=true`.

### 5.2 NFA metrics

Use production output `Y_US` as the main empirical denominator, but also report `e_US` for comparison with existing notebook outputs.

```julia
Y_US = [s.Y_US for s in result.u_path]
e_US = [s.e_US for s in result.u_path]

nfa_Y = dec.NFA ./ Y_US
nfa_e = dec.NFA ./ e_US
nfa_fund_Y = dec.NFA_fund ./ Y_US
nfa_bubble_Y = dec.NFA_bubble ./ Y_US
Q_A = dec.Q_US ./ dec.A
```

Save:

```julia
nfa_Y_t1
nfa_Y_t20
nfa_Y_t40
nfa_Y_t60
nfa_Y_t80
nfa_Y_t100
nfa_Y_final
nfa_Y_min
nfa_Y_late_mean      # mean over last 20 reported periods
nfa_negative_count
nfa_negative_share
last_negative_t      # maximum t with NFA < 0; missing/0 if none
Q_A_final
Q_A_late_mean
```

A run is promising on NFA if:

```julia
nfa_negative_share >= 0.50
# or
nfa_Y_final < 0
# or
last_negative_t >= 0.75*T_max
```

### 5.3 Bubble metrics

```julia
bubble_share = dec.bubble_share
bubble_Y = dec.B_agg ./ Y_US
bubble_e = dec.B_agg ./ e_US
```

Save:

```julia
bubble_share_t1
bubble_share_t20
bubble_share_t40
bubble_share_t60
bubble_share_t80
bubble_share_t100
bubble_share_final
bubble_share_max
bubble_share_late_mean
bubble_Y_final
bubble_Y_max
bubble_Y_late_mean
```

Preferred thresholds:

```julia
bubble_share_late_mean >= 0.05      # minimally interesting
bubble_share_late_mean >= 0.10      # strong
bubble_share_late_mean >= 0.20      # very strong
```

### 5.4 Bubble contribution to NFA

When NFA is negative, compute the fraction of negative NFA accounted for by the bubble:

```julia
bubble_contribution_to_negative_NFA = (-dec.NFA_bubble) ./ abs.(dec.NFA)
```

Only compute this where `dec.NFA < 0`. Save:

```julia
bubble_contribution_mean_when_NFA_negative
bubble_contribution_median_when_NFA_negative
bubble_contribution_final_if_NFA_negative
```

### 5.5 Foreign-demand diagnostics

```julia
foreign_equity_demand = [s.ω_star * s.S_star for s in result.u_path]
foreign_equity_share = foreign_equity_demand ./ dec.Q_US
Astar_A = [s.A_star / s.A for s in result.u_path]
θ_path = [s.θ for s in result.u_path]
θUSstar_path = [s.θ_US_star for s in result.u_path]
```

Save:

```julia
foreign_equity_share_final
foreign_equity_share_late_mean
Astar_A_final
Astar_A_late_mean
θ_final
θ_min
θUSstar_final
θUSstar_max
```

This is crucial for interpreting whether negative U.S. NFA is driven by foreign U.S.-equity demand or by the bond/convenience channel.

### 5.6 Bubble-theorem diagnostics

Save:

```julia
cond_1a_final
cond_1b_final
ratio_1a
ratio_1b
sum_inf_1a
sum_inf_1b
geom_1a_converges
geom_1b_converges
ψ_US = (ξ_u - ν_u)*(ρ_US - 1)
realized_ν_b_eff_mean
realized_ν_b_eff_min
realized_ν_b_eff_max
realized_ν_gap = ν_u - realized_ν_b_eff_mean
ξ_gap = ξ_u - ν_u
```

---

## 6. Suggested Julia structure

Create a robust runner with exception handling.

```julia
include("TwoCountryProductionOLG.jl")
using CSV, DataFrames, Statistics

function safe_mean(x)
    y = collect(skipmissing(x))
    isempty(y) && return missing
    return mean(y)
end

function run_case(label::String; kwargs...)
    p = ProductionParams(; kwargs...)
    row = Dict{String, Any}()
    row["label"] = label

    # Store parameters
    for name in fieldnames(ProductionParams)
        row[string(name)] = getfield(p, name)
    end

    try
        result = run_production_simulation(p)
        dec = nfa_decomposition(result)
        T = length(result.u_path)

        Y_US = [s.Y_US for s in result.u_path]
        e_US = [s.e_US for s in result.u_path]
        R_A_u = [s.R_A_u for s in result.u_path]
        R_A_b = [s.R_A_b for s in result.u_path]
        R_A_star_u = [s.R_A_star_u for s in result.u_path]
        R_A_star_b = [s.R_A_star_b for s in result.u_path]
        Astar_A = [s.A_star / s.A for s in result.u_path]
        foreign_equity_share = [s.ω_star * s.S_star / s.Q_US for s in result.u_path]
        θ_path = [s.θ for s in result.u_path]
        θUSstar_path = [s.θ_US_star for s in result.u_path]
        ν_b_eff_path = [b.ν_b_eff for b in result.bgp_seq[1:T]]

        nfa_Y = dec.NFA ./ Y_US
        nfa_e = dec.NFA ./ e_US
        nfa_bubble_Y = dec.NFA_bubble ./ Y_US
        bubble_Y = dec.B_agg ./ Y_US
        bubble_share = dec.bubble_share
        Q_A = dec.Q_US ./ dec.A

        neg_idx = findall(<(0.0), dec.NFA)
        last20 = max(1, T-19):T

        row["status"] = "ok"
        row["branch_converged"] = result.branch_converged
        row["max_u_residual"] = result.max_u_residual
        row["max_bgp_residual"] = result.max_bgp_residual
        row["psi_ok"] = result.diagnostics.psi_ok
        row["psi_min"] = result.diagnostics.psi_min
        row["equity_weights_ok"] = result.diagnostics.equity_weights_ok
        row["equity_weight_min"] = result.diagnostics.equity_weight_min
        row["min_R_A_u"] = minimum(R_A_u)
        row["min_R_A_b"] = minimum(R_A_b)
        row["min_R_A_star_u"] = minimum(R_A_star_u)
        row["min_R_A_star_b"] = minimum(R_A_star_b)

        row["valid_core"] = result.branch_converged && result.max_u_residual <= 1e-5 &&
                              result.max_bgp_residual <= 1e-5 &&
                              result.diagnostics.psi_ok && result.diagnostics.equity_weights_ok &&
                              minimum(R_A_u) > 0 && minimum(R_A_b) > 0
        row["valid_exploratory"] = result.max_u_residual <= 1e-4 &&
                                    result.diagnostics.psi_ok && result.diagnostics.equity_weights_ok

        # NFA metrics
        row["nfa_Y_final"] = nfa_Y[end]
        row["nfa_Y_min"] = minimum(nfa_Y)
        row["nfa_Y_late_mean"] = mean(nfa_Y[last20])
        row["nfa_negative_count"] = length(neg_idx)
        row["nfa_negative_share"] = length(neg_idx)/T
        row["last_negative_t"] = isempty(neg_idx) ? 0 : maximum(neg_idx)
        row["Q_A_final"] = Q_A[end]
        row["Q_A_late_mean"] = mean(Q_A[last20])

        # Bubble metrics
        row["bubble_share_final"] = bubble_share[end]
        row["bubble_share_max"] = maximum(bubble_share)
        row["bubble_share_late_mean"] = mean(bubble_share[last20])
        row["bubble_Y_final"] = bubble_Y[end]
        row["bubble_Y_max"] = maximum(bubble_Y)
        row["bubble_Y_late_mean"] = mean(bubble_Y[last20])

        # Bubble contribution to negative NFA
        if !isempty(neg_idx)
            contribution = (-dec.NFA_bubble[neg_idx]) ./ abs.(dec.NFA[neg_idx])
            row["bubble_contribution_mean_when_NFA_negative"] = mean(contribution)
            row["bubble_contribution_median_when_NFA_negative"] = median(contribution)
            row["bubble_contribution_final_if_NFA_negative"] = dec.NFA[end] < 0 ? (-dec.NFA_bubble[end])/abs(dec.NFA[end]) : missing
        else
            row["bubble_contribution_mean_when_NFA_negative"] = missing
            row["bubble_contribution_median_when_NFA_negative"] = missing
            row["bubble_contribution_final_if_NFA_negative"] = missing
        end

        # Foreign-demand metrics
        row["foreign_equity_share_final"] = foreign_equity_share[end]
        row["foreign_equity_share_late_mean"] = mean(foreign_equity_share[last20])
        row["Astar_A_final"] = Astar_A[end]
        row["Astar_A_late_mean"] = mean(Astar_A[last20])
        row["θ_final"] = θ_path[end]
        row["θ_min"] = minimum(θ_path)
        row["θUSstar_final"] = θUSstar_path[end]
        row["θUSstar_max"] = maximum(θUSstar_path)

        # Theorem diagnostics
        row["cond_1a_final"] = result.diagnostics.cond_1a[end]
        row["cond_1b_final"] = result.diagnostics.cond_1b[end]
        row["ratio_1a"] = result.diagnostics.ratio_1a
        row["ratio_1b"] = result.diagnostics.ratio_1b
        row["sum_inf_1a"] = result.diagnostics.sum_inf_1a
        row["sum_inf_1b"] = result.diagnostics.sum_inf_1b
        row["geom_1a_converges"] = result.diagnostics.geom_1a_converges
        row["geom_1b_converges"] = result.diagnostics.geom_1b_converges
        row["psi_US"] = (p.ξ_u - p.ν_u) * (p.ρ_US - 1)
        row["realized_ν_b_eff_mean"] = mean(ν_b_eff_path)
        row["realized_ν_b_eff_min"] = minimum(ν_b_eff_path)
        row["realized_ν_b_eff_max"] = maximum(ν_b_eff_path)
        row["realized_ν_gap"] = p.ν_u - mean(ν_b_eff_path)
        row["ξ_gap"] = p.ξ_u - p.ν_u

    catch err
        row["status"] = "error"
        row["error"] = sprint(showerror, err)
    end

    return row
end
```

---

## 7. Output requirements

Save at least:

```text
sweep_results/production_sweep_master.csv
sweep_results/production_sweep_valid_core.csv
sweep_results/production_sweep_exploratory.csv
sweep_results/top_candidates_by_score.csv
sweep_results/failed_cases.csv
```

Generate plots:

```text
sweep_results/plots/heatmap_nfa_Y_late_mean__mW_x_omegastar.png
sweep_results/plots/heatmap_bubble_share_late_mean__pi_x_aUS.png
sweep_results/plots/heatmap_bubble_share_late_mean__aUS_x_varthetaUS.png
sweep_results/plots/heatmap_bubble_share_late_mean__gamma_x_xigap.png
sweep_results/plots/scatter_nfa_vs_bubble_share.png
sweep_results/plots/pareto_frontier_nfa_bubble.png
sweep_results/plots/top_candidate_paths.png
```

For `top_candidate_paths.png`, plot for the best 3–5 valid candidates:

1. `NFA/Y_US`
2. `B_US/Q_US`
3. `-B_US/Y_US`
4. `foreign_equity_share`
5. `Psi`
6. `φ_US`

---

## 8. Ranking / scoring rule

Rank only valid or exploratory-valid cases.

Suggested score:

```julia
score = 0.0
score += 3.0 * max(0, -nfa_Y_late_mean)
score += 2.0 * max(0, -nfa_Y_final)
score += 5.0 * bubble_share_late_mean
score += 2.0 * bubble_share_final
score += 1.0 * nfa_negative_share
score += 1.0 * foreign_equity_share_late_mean
```

Add penalties:

```julia
score -= 10.0 if valid_exploratory == false
score -= 5.0  if psi_min < 1e-3
score -= 5.0  if equity_weight_min < 1e-3
score -= 2.0  if θ_min < -5.0       # flag extreme leverage; threshold can be adjusted
score -= 2.0  if χ >= 0.05 and foreign_equity_share_late_mean does not rise
```

The score is only a sorting device. The final report should interpret mechanisms, not just report the score.

---

## 9. Interpretation rules

When reporting results, classify each promising candidate into one of three channels:

### A. Foreign-equity-boom channel — preferred

Conditions:

```julia
NFA/Y_US < 0 for many periods
foreign_equity_share rises materially
bubble_share is nontrivial
χ remains moderate
θ is not extreme
```

This is the target mechanism.

### B. Safe-asset / bond channel — secondary

Conditions:

```julia
NFA/Y_US < 0
θ_US_star or |θ| rises sharply
χ is high
foreign_equity_share does not rise much
bubble_share remains small
```

Flag this as not the desired primary mechanism.

### C. Pure bubble-share channel but no NFA sign

Conditions:

```julia
bubble_share rises
NFA/Y_US remains positive
```

This identifies parameters that help the bubble theorem quantitatively but still require foreign-demand or saving-side changes.

---

## 10. Final deliverables

Produce a short report with:

1. Baseline recap.
2. One-at-a-time comparative-statistics table.
3. Heatmaps for the main two-dimensional grids.
4. Top 10 valid candidates ranked by score.
5. A mechanism classification for each top candidate.
6. A short conclusion answering:
   - Which parameters most help the NFA sign?
   - Which parameters most help `B_US/Q_US`?
   - Which joint calibration best matches the project’s story?
   - Does the result rely too much on U.S. bond convenience `χ`?
   - Are `Psi`, equity weights, and returns well behaved?
7. Save all tables and plots under `sweep_results/`.

