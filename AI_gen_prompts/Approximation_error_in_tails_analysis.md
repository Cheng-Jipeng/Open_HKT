# Approximation Error In Terminal Tails

## Goal

Create numerical notebooks that test whether finite-horizon terminal-tail
approximations contaminate the economically reported part of the production
economy paths.

There are two related analyses:

1. The existing two-country production analysis.
2. A new single-country HKT production notebook under
   `Single_country_production/` that replicates the same tail-approximation
   logic in an exactly solvable benchmark.

Do not modify the shared model files unless the notebook cannot be implemented
without doing so. Prefer notebook-local helpers and terminal-rule dispatchers.
In particular, `Single_country_production/SingleCountryProductionOLG.jl` already
contains the exact HKT static block and forward recursion; use those as the
ground truth.

## Calibration and grids

Use the large-bubble calibration that matches the two-country `12_v9` exercise
as the main target.

For the single-country HKT notebook:

```julia
p = HKTParams(T=100, γ=0.25, ξu=2.0, λu=1.5, ξb=0.5, λb=0.5)
pi_persist = 0.80
```

Keep all other HKT primitives at the `HKTParams()` defaults.

Use these default grids:

```julia
T_report_grid = [45, 60]
n_buffer_grid = [0, 5, 20]
T0_grid = [20, 30, 40]
baseline = (T_report=45, n_buffer=5)
```

Also provide a smoke mode, e.g. via `ENV["TAIL_ANALYSIS_MODE"] = "smoke"`, with
tiny grids:

```julia
T_report_grid = [5, 6]
n_buffer_grid = [0, 2]
T0_grid = [2, 4]
baseline = (T_report=5, n_buffer=2)
```

## A. Two-country horizon and buffer invariance

For the two-country production solver, run the agreed baseline-centered grid:

```julia
T_report_grid = [45, 60]
n_buffer_grid = [0, 5, 20]
T0_grid = [20, 30, 40]
baseline = (T_report=45, n_buffer=5)
```

For each run, report:

$$
\begin{array}{c}
\max_{t\le T_0}\left|\log q_t-\log q_t^{baseline}\right|,\quad
\max_{t\le T_0}\left|\log(d_t/q_t)-\log(d_t/q_t)^{baseline}\right|,\\
\max_{t\le T_0}\left|\phi_t-\phi_t^{baseline}\right|,\quad
\max_{t\le T_0}\left|B_t/Q_t-(B_t/Q_t)^{baseline}\right|.
\end{array}
$$

Also plot the full `B/Q` paths and `v/q = 1 - B/Q` paths across the horizon and
buffer grid. The two-country analysis has already shown that `q` and `phi` can
be almost invariant while `B/Q` varies because the fundamental-value recursion is
tail sensitive. Make this distinction explicit.

## B. Two-country terminal-rule sensitivity

Compare at least four terminal rules:

$$
\begin{array}{c}
\phi_{T+1}=\phi_T
\quad \text{flat, intentionally bad benchmark;}\\
\phi_{T+1}=\frac{\phi_T^2}{\phi_{T-1}}
\quad \text{current local log-linear rule;}\\
\phi_{T+1}=\phi_T G_N^{-\psi/\rho}
\quad \text{asymptotic HKT rate;}\\
\log\phi_{T+1}=\hat a+\hat b(T+1)
\quad \text{tail regression over the last } k \text{ solved periods.}
\end{array}
$$

Show whether reported pre-terminal objects are stable under the last three
rules and whether the flat rule contaminates periods close to the terminal date.
The flat rule is expected to be a useful bad benchmark because a flat closure
contradicts the decaying-branch Euler equation.

## C. New single-country HKT notebook

Create a new notebook under `Single_country_production/`, for example:

```text
Single_country_production/13_single_country_production_tail_approximation_analysis.ipynb
```

The notebook should implement an exactly solvable single-country version of the
two-country tail exercise. It must compare two finite-horizon objects at the
same `T_report` and `n_buffer`.

### C.1 Exact finite-horizon HKT path

This is the benchmark path. Compute it directly from the HKT static block and
forward recursion:

- Use `hkt_block(p, n_t, :u)` for each all-`u` date.
- Use the HKT knowledge law
  $$
  n_{t+1}=G_t n_t,\qquad G_t=1+aH(1-\phi_t).
  $$
- Record at least
  $$
  n_t,\ \phi_t,\ G_t,\ q_t,\ d_t,\ d_t/q_t,\ V_t/q_t,\ B_t/q_t.
  $$

For `q_t` and `d_t`, use the existing notebook convention:

```julia
q_t = block.PD_pv * (block.D / n_t)
d_t = block.D / n_t
```

The exact fundamental and bubble shares should use the rational-bubble product
recursion already used in the single-country notebooks:

```julia
hkt_rational_bubble_path(p; pi_persist=0.80, T_ext=600, tail_k=80)
```

or an equivalent notebook-local helper. Use a long extension and tail
extrapolation so the benchmark is effectively horizon invariant.

### C.2 Tail-approximated finite-horizon HKT path

Construct a second finite-horizon path that mimics the two-country terminal-tail
procedure instead of using the exact static solution at the terminal successor.

For each `(T_report, n_buffer)`:

1. Set `T_solve = T_report + n_buffer`.
2. Compute the all-`u` path over the solved region.
3. At the artificial successor `T_solve+1`, do not use the exact HKT static
   successor for `phi`. Instead use a terminal extrapolation rule for
   `phi_{T_solve+1}`.
4. Recompute the implied terminal-successor objects from that extrapolated
   `phi`, including `G`, `n`, `q`, `d`, and the one-step pricing/fundamental
   recursion objects.
5. Trim results back to `T_report`.

Implement a notebook-local helper such as `hkt_block_given_phi(p, n, z, phi)`
for the artificial successor. It should reuse the formulas in `hkt_block` but
skip `solve_phi`. In particular, at a given predetermined `n` and regime `z`:

```julia
xi, lambda = z === :u ? (p.ξu, p.λu) : (p.ξb, p.λb)
AXH = p.A_XH * n^xi
ALL = p.A_LL * n^lambda
Xtilde = AXH * phi
Ltilde = ALL
FX = _ces_FX(p.α, p.ρ, Xtilde, Ltilde)
FL = _ces_FL(p.α, p.ρ, Xtilde, Ltilde)
HwH = p.θ * FX * AXH
LwL = FL * ALL
e = HwH + LwL
D = (1 - p.θ) / p.θ * HwH * phi
d = D / n
PD_pv = p.θ / ((1 - p.θ) * phi * p.aH)
q = PD_pv * d
G = 1 + p.aH * (1 - phi)
```

For non-terminal dates, use the exact `hkt_block` path. Only the artificial
successor should be replaced by the extrapolated-`phi` block.

The central comparison is between the exact finite-horizon HKT path and this
tail-approximated path. The finite-horizon approximation should use the same
terminal rules as the two-country notebook:

```julia
flat:              phi[T+1] = phi[T]
local_loglinear:   phi[T+1] = phi[T]^2 / phi[T-1]
asymptotic_hkt:    phi[T+1] = phi[T] * G_N(phi[T])^(-psi/rho)
tail_regression:   log(phi[T+1]) = a_hat + b_hat * (T+1)
```

where

$$
\psi=(\xi_u-\lambda_u)(\rho-1).
$$

For the single-country growth factor in the asymptotic rule, use

$$
G(\phi)=1+aH(1-\phi).
$$

The tail-approximated fundamental value should be computed with a finite
backward recursion, not with the long exact product recursion. Use the same
one-step SDF as the existing single-country notebooks. With continuation
successor `u` and switch successor `b` at date `i+1`,

```julia
den = pi * (q_u[i+1] + d_u[i+1])^(1 - p.γ) +
      (1 - pi) * (q_b[i+1] + d_b[i+1])^(1 - p.γ)
m_u = q_u[i] * (q_u[i+1] + d_u[i+1])^(-p.γ) / den
m_b = q_u[i] * (q_b[i+1] + d_b[i+1])^(-p.γ) / den
```

Use the no-bubble terminal closure on the artificial continuation successor:

```julia
V_u[T_solve+1] = q_u[T_solve+1]
```

and recurse backward:

```julia
V_u[i] = pi * m_u * (d_u[i+1] + V_u[i+1]) +
         (1 - pi) * m_b * (d_b[i+1] + q_b[i+1])
B_u[i] = q_u[i] - V_u[i]
bubble_share[i] = B_u[i] / q_u[i]
fundamental_share[i] = V_u[i] / q_u[i]
```

The exact benchmark should still use the long product recursion from C.1. The
finite-horizon recursion above is the object whose terminal-tail approximation
is being tested.

The main horizon/buffer comparison can use `local_loglinear`. Terminal-rule
sensitivity should compare all four rules.

### C.3 Error tables

For each `(T_report, n_buffer, T0)` report errors of the
tail-approximated path relative to the exact HKT path:

$$
\varepsilon_\phi(T_0,T)
=\max_{t\le T_0}
\left|\log\phi_t^{approx}-\log\phi_t^{exact}\right|,
$$

$$
\varepsilon_q(T_0,T)
=\max_{t\le T_0}
\left|\log q_t^{approx}-\log q_t^{exact}\right|,
$$

$$
\varepsilon_{d/q}(T_0,T)
=\max_{t\le T_0}
\left|\log(d_t^{approx}/q_t^{approx})
-\log(d_t^{exact}/q_t^{exact})\right|,
$$

$$
\varepsilon_{V/q}(T_0,T)
=\max_{t\le T_0}
\left|
\frac{V_t^{approx}}{q_t^{approx}}
-\frac{V_t^{exact}}{q_t^{exact}}
\right|,
$$

$$
\varepsilon_{B/q}(T_0,T)
=\max_{t\le T_0}
\left|
\frac{B_t^{approx}}{q_t^{approx}}
-\frac{B_t^{exact}}{q_t^{exact}}
\right|.
$$

Use the baseline `(T_report=45, n_buffer=5)` as the reference case for
cross-horizon plots, but the exact HKT path is the true benchmark for the error
tables.

### C.4 Required single-country plots and exports

Export outputs under a new folder such as:

```text
Single_country_production/outputs_hkt_single_country_tail_analysis/
```

Required CSVs:

- `single_country_exact_paths.csv`
- `single_country_tail_approx_paths.csv`
- `single_country_horizon_buffer_errors.csv`
- `single_country_terminal_rule_sensitivity.csv`
- `single_country_bubble_share_diagnostics.csv`

Required figures:

- Exact vs approximated paths for `phi`, `q`, `d/q`, `V/q`, and `B/q`.
- Horizon/buffer path overlays for `B/q` and `V/q`.
- Error plots across `T_report` and `n_buffer`.
- Terminal-rule sensitivity plots for `phi`, `q`, `V/q`, and `B/q`.

The notebook text should explain the key interpretation:

- If `phi`, `q`, and `d/q` are accurate but `V/q` and `B/q` vary, the error is
  coming from tail valuation rather than the real allocation.
- The two-country solver uses the same local tail logic in a harder equilibrium
  system; the single-country HKT notebook is the exactly solvable sanity check.

## D. Exploratory unreduced single-country solver

Add a separate optional section or appendix in the single-country notebook that
checks whether the single-country production economy can be solved without
directly using the reduced HKT static condition.

This is not a blocker for Sections C.1-C.4.

Recommended implementation:

1. Treat `phi_t` and `q_t` as unknowns on a finite all-`u` horizon.
2. Given a `phi` path, compute production objects, dividends, knowledge growth,
   and stock supply.
3. Enforce stock-market clearing and one-period asset-pricing equations by
   backward/forward iteration, in the spirit of the two-country production
   solver.
4. Use the exact static HKT path as the initial guess and as the ground truth.
5. Report whether the unreduced solver converges back to the exact HKT path:

$$
\max_{t\le T_0}|\log q_t^{unreduced}-\log q_t^{exact}|,\qquad
\max_{t\le T_0}|\log\phi_t^{unreduced}-\log\phi_t^{exact}|.
$$

If the unreduced solver is ill-conditioned or redundant, say so clearly. HKT's
single-country production economy algebraically collapses to the static
condition, so this task is mainly a consistency and feasibility check, not the
core validation.

## Implementation notes for agents

- Read `Single_country_production/SingleCountryProductionOLG.jl` before coding.
- Reuse helper patterns from:
  - `Single_country_production/10_single_country_production_hkt.ipynb`
  - `Single_country_production/12_single_country_production_hkt_larger_bubble_share.ipynb`
  - `Two_country_production/13_v9_approximation_error_in_tails_analysis.ipynb`
- Keep notebook outputs deterministic.
- Include a smoke mode and verify it with `jupyter nbconvert --execute`.
- Do not overwrite existing output folders from earlier notebooks.
- Leave unrelated dirty worktree files untouched.
