# SingleCountryOLG.jl
#
# Single-country endowment economy — simplified baseline of the two-country OLG
# bubble model in Hirano et al. (2025) "Technological Innovation and Bursting Bubbles".
#
# Agents:   OLG, one country (US).  Young saves A_t = β·e_t; old consumes from returns.
# Assets:   One Lucas tree (stock) with dividends D_t.  No bonds (θ = 0 trivially).
# Prices:   Q_t = β·e_t always (market clearing, trivial — no portfolio solver needed).
# Regimes:  u-state (bubble continues, growth g_e_u) vs b-state (bubble pops, g_e_b).
# b-state:  Q^b_t = β·λ_e·ρ^τ·e^u_t,  D^b_t = λ_D·D^u_t
#           where ρ ∈ (0,1] is a per-period decay factor for the b-state price.
#           Natural default: ρ = g_e_b/g_e_u, so Q^b_t = β·e_0·g_e_b^t
#           (b-state price is what the endowment would be under fundamental growth).
#
# Equilibrium is closed-form:
#   R^u_t = g_e_u·(β + d^u_t)/β               (u-continuation return)
#   R^b_t = g_e_u·(β·λ_e·ρ^τ + λ_D·d^u_t)/β  (b-switch return)
#   C^b/C^u = R^b/R^u → λ_e·ρ^τ → 0  as τ → ∞  (when ρ < 1)
#
# Condition 2b ≡ Σ(C^b/C^u)^{1-γ} ≈ Σ (λ_e·ρ^τ)^{1-γ}:
#   ρ = 1:  terms → (λ_e)^{1-γ} = constant  → sum grows linearly → DIVERGES
#   ρ < 1:  terms ~ (ρ^{1-γ})^τ → 0        → geometric series  → CONVERGES ✓

using Parameters
using Printf
using Statistics

# ─────────────────────────────────────────────────────────────────
# 1. Parameters
# ─────────────────────────────────────────────────────────────────

"""
Parameters for the single-country endowment OLG economy.
Adapted from ModelParams in TwoCountryOLG.jl; drops all RoW-specific fields.
"""
@with_kw struct SCParams
    # Preferences
    β::Float64 = 0.50           # young saving propensity  (same as two-country)
    γ::Float64 = 0.50           # old-age CRRA (γ < 1)     (same)

    # Regime switching
    π_persist::Float64 = 0.70   # P(u→u)                   (same)

    # Growth rates (per OLG period ≈ 5 years)
    g_e_u::Float64 = 1.025^5   # US endowment growth in u-state  (same)
    g_e_b::Float64 = 1.01^5    # balanced-state growth            (same)
    g_D_u::Float64 = 1.015^5   # US dividend growth in u-state    (same)
    # Note: g_D_u < g_e_u ensures d_t = D_t/e_t → 0 (key for condition 2a)

    # Initial conditions
    e_0::Float64         = 1.0    # initial endowment      (= e_US_0)
    D_e_ratio_0::Float64 = 0.04   # initial D/e ratio      (same)

    # Switch-date scaling: Q^b_t = β·λ_e·ρ^τ·e^u_t,  D^b_t = λ_D·D^u_t
    λ_e::Float64 = 1.0           # level scalar at t=0  (same default as two-country)
    λ_D::Float64 = 1.0           # dividend scalar      (same default)
    # Per-period decay of the b-state price.
    # ρ = 1   → constant λ_e (original spec, condition 2b diverges)
    # ρ < 1   → λ_e·ρ^τ → 0, condition 2b converges as geometric series
    # Natural default: ρ = g_e_b/g_e_u so Q^b_τ = β·e_0·g_e_b^τ
    #   (b-state price = endowment on the fundamental growth path)
    ρ::Float64 = 1.01^5 / 1.025^5   # ≈ 0.929 per 5-year period

    # Simulation horizon
    T_max::Int = 120              # (same)
end

# ─────────────────────────────────────────────────────────────────
# 2. Exogenous paths
# ─────────────────────────────────────────────────────────────────

"""
Exogenous u-path sequences for the single-country model.
e[t] and D[t] grow along the u-state.  Length = T_max + 1 (need t+1 for last period).
"""
struct SCPaths
    e::Vector{Float64}   # endowment e^u_t
    D::Vector{Float64}   # dividends D^u_t
    T::Int               # = T_max + 1
end

function generate_sc_paths(p::SCParams)
    T = p.T_max + 1
    e = Vector{Float64}(undef, T)
    D = Vector{Float64}(undef, T)
    e[1] = p.e_0
    D[1] = p.D_e_ratio_0 * p.e_0
    for t in 2:T
        e[t] = e[t-1] * p.g_e_u
        D[t] = D[t-1] * p.g_D_u
    end
    SCPaths(e, D, T)
end

# ─────────────────────────────────────────────────────────────────
# 3. Period state (trivial closed-form equilibrium)
# ─────────────────────────────────────────────────────────────────

"""
Equilibrium state at period t on the u-path.

Stock prices (market clearing, trivial):
  Q_u   = β·e_t                   (u-path: all savings = stock market cap)
  λ_e_t = λ_e · ρ^(t-1)           (paths[1] is model date 0)
  Q_b   = β·λ_e_t·e_t             (b-state price if bubble pops at t)

Returns received by the old agent at t (who saved A_{t-1} = β·e_{t-1}):
  R_u = (Q_u_t + D_t)        / Q_u_{t-1}   [u-continuation]
  R_b = (Q_b_t + λ_D·D_t)   / Q_u_{t-1}   [b-switch]
Both are NaN for t = 1 (no previous period).
"""
struct SCPeriodState
    t::Int
    e::Float64        # e^u_t
    D::Float64        # D^u_t
    d::Float64        # D_t / e_t  (dividend ratio, declines since g_D_u < g_e_u)
    λ_e_t::Float64    # effective b-state scaling = λ_e · ρ^(t-1)
    Q_u::Float64      # β·e_t
    Q_b::Float64      # β·λ_e_t·e_t
    R_u::Float64      # u-continuation return
    R_b::Float64      # b-switch return
end

"""
Compute the equilibrium path.  Pure forward pass; no solver required.
"""
function solve_sc_u_path(p::SCParams, paths::SCPaths)
    T = p.T_max
    states = Vector{SCPeriodState}(undef, T)
    for t in 1:T
        e_t    = paths.e[t]
        D_t    = paths.D[t]
        λ_e_t  = p.λ_e * p.ρ^(t - 1)  # paths[1] is model date 0
        Q_u    = p.β * e_t
        Q_b    = p.β * λ_e_t * e_t
        d      = D_t / e_t
        if t == 1
            R_u = NaN
            R_b = NaN
        else
            Q_prev = p.β * paths.e[t-1]
            R_u    = (Q_u + D_t)          / Q_prev
            R_b    = (Q_b + p.λ_D * D_t)  / Q_prev
        end
        states[t] = SCPeriodState(t, e_t, D_t, d, λ_e_t, Q_u, Q_b, R_u, R_b)
    end
    states
end

# ─────────────────────────────────────────────────────────────────
# 4. Bubble diagnostics
# ─────────────────────────────────────────────────────────────────

"""
Bubble diagnostics following the same structure as TwoCountryOLG.jl.

Condition 2a: Σ d_t = Σ D^u_t / e^u_t < ∞
  → converges iff g_D_u < g_e_u  (holds with default params)

Condition 2b: Σ (C^b_t / C^u_t)^{1-γ} < ∞
  C^b/C^u = (β·λ_e·ρ^τ + λ_D·d_t) / (β + d_t) → λ_e·ρ^τ  as d_t → 0
  Terms ~ (λ_e·ρ^τ)^{1-γ} = λ_e^{1-γ} · (ρ^{1-γ})^τ
  → ρ = 1: constant → sum linear → DIVERGES
  → ρ < 1: geometric decay → sum CONVERGES  (iff ρ^{1-γ} < 1, i.e. γ < 1)

leakage a_t = D_t/Q_u + (1-π)/π · (C_u/C_b)^γ · (Q_b + D_b)/Q_u
"""
struct SCBubbleDiagnostics
    dividend_ratio::Vector{Float64}      # d_t = D^u_t / e^u_t
    sum_dividend_ratio::Vector{Float64}  # Σ d_t  (condition 2a)
    consump_ratio::Vector{Float64}       # C^b_t / C^u_t
    cond_2b_terms::Vector{Float64}       # (C^b/C^u)^{1-γ}
    sum_cond_2b::Vector{Float64}         # Σ (C^b/C^u)^{1-γ}  (condition 2b)
    a_t::Vector{Float64}                 # leakage ratio
    sum_a_t::Vector{Float64}
    condition_2a_converges::Bool
    condition_2b_converges::Bool
    bubble_exists::Bool
end

function compute_sc_bubble_diagnostics(p::SCParams, states::Vector{SCPeriodState})
    T    = length(states)
    π_p  = p.π_persist
    γ    = p.γ

    dividend_ratio = zeros(T)
    consump_ratio  = zeros(T)
    cond_2b_terms  = zeros(T)
    a_t            = zeros(T)

    for t in 2:T
        s   = states[t]
        R_u = s.R_u
        R_b = s.R_b

        A_prev = p.β * states[t-1].e
        C_u    = A_prev * R_u
        C_b    = A_prev * R_b

        ratio = C_b / C_u

        dividend_ratio[t] = s.d
        consump_ratio[t]  = ratio
        cond_2b_terms[t]  = ratio^(1 - γ)

        Q_b_plus_D = s.Q_b + p.λ_D * s.D
        a_t[t]     = (s.D / s.Q_u) +
                     (1 - π_p) / π_p * (C_u / C_b)^γ * Q_b_plus_D / s.Q_u
    end

    sum_dr  = cumsum(dividend_ratio)
    sum_2b  = cumsum(cond_2b_terms)
    sum_at  = cumsum(a_t)

    # Convergence test: empirical plateau OR geometric extrapolation.
    # The empirical plateau alone fails for slowly-decaying geometric series
    # (e.g. ρ^{1-γ} ≈ 0.964): at T=120 the tail has not plateaued yet even
    # though the infinite series converges.  The geometric extrapolation fix:
    #   estimate the decay ratio r from the last n_fit terms,
    #   extrapolate tail_∞ = last_term * r / (1 - r),
    #   the series converges iff tail_∞ is finite and small relative to sum.
    n_tail   = max(1, T ÷ 10)
    tail_2a  = sum_dr[end] - sum_dr[end - n_tail]
    tail_2b  = sum_2b[end] - sum_2b[end - n_tail]

    conv_2a  = tail_2a < 0.01 * max(sum_dr[end], 1e-15)

    # Plateau test (sufficient for fast decay)
    plateau_2b = tail_2b < 0.01 * max(sum_2b[end], 1e-15)

    # Geometric extrapolation test (catches slow geometric decay)
    n_fit    = max(2, T ÷ 20)        # use last ~5% of periods to fit ratio
    t_start  = T - n_fit + 1
    t_end    = T
    # Estimate geometric ratio r from average of consecutive-term ratios
    geo_ratios = [cond_2b_terms[t] / max(cond_2b_terms[t-1], 1e-300)
                  for t in (t_start+1):t_end
                  if cond_2b_terms[t-1] > 1e-300]
    if !isempty(geo_ratios)
        r_est = median(geo_ratios)
        if r_est < 1.0 - 1e-6          # decaying geometric series
            tail_inf = cond_2b_terms[T] * r_est / (1 - r_est)
            geo_conv_2b = tail_inf < 0.05 * (sum_2b[end] + tail_inf)
        else
            geo_conv_2b = false         # r ≥ 1 → diverges
        end
    else
        geo_conv_2b = false
    end

    conv_2b  = plateau_2b || geo_conv_2b

    SCBubbleDiagnostics(dividend_ratio, sum_dr,
                        consump_ratio, cond_2b_terms, sum_2b,
                        a_t, sum_at,
                        conv_2a, conv_2b,
                        conv_2a && conv_2b)
end

# ─────────────────────────────────────────────────────────────────
# 5. Result struct and top-level orchestrator
# ─────────────────────────────────────────────────────────────────

struct SCSimulationResult
    params::SCParams
    paths::SCPaths
    states::Vector{SCPeriodState}
    diagnostics::SCBubbleDiagnostics
end

"""
Run the single-country endowment economy simulation.

Steps:
  1. Generate exogenous u-path (e_t, D_t)
  2. Compute closed-form equilibrium (Q = β·e, returns R_u, R_b)
  3. Evaluate bubble diagnostics (conditions 2a and 2b)
"""
function run_sc_simulation(p::SCParams = SCParams(); verbose::Bool = true)
    verbose && println("Single-country endowment economy")
    verbose && @printf("  Parameters: β=%.2f  γ=%.2f  π_persist=%.2f\n",
                       p.β, p.γ, p.π_persist)
    verbose && @printf("  Growth:  g_e_u=%.4f  g_e_b=%.4f  g_D_u=%.4f\n",
                       p.g_e_u, p.g_e_b, p.g_D_u)
    verbose && @printf("  Switch scaling: λ_e=%.3f  λ_D=%.3f  ρ=%.6f\n",
                       p.λ_e, p.λ_D, p.ρ)
    verbose && @printf("  b-state price: Q^b_τ = β·λ_e·ρ^τ·e^u_t  (ρ^(T-1) = %.2e)\n",
                       p.ρ^(p.T_max - 1))

    paths  = generate_sc_paths(p)
    states = solve_sc_u_path(p, paths)
    diag   = compute_sc_bubble_diagnostics(p, states)

    if verbose
        println("\n══════ SINGLE-COUNTRY BUBBLE DIAGNOSTICS ══════")
        @printf("  d_0 (initial D/e):         %.6f\n",  states[1].d)
        @printf("  d_T (final D/e):           %.6f\n",  states[end].d)
        @printf("  C^b/C^u (period 2):        %.6f\n",  diag.consump_ratio[2])
        @printf("  C^b/C^u (period T):        %.6f\n",  diag.consump_ratio[end])
        ρ_geom = p.ρ^(1 - p.γ)
        @printf("  (C^b/C^u)^{1-γ} at T:      %.6f  (geometric ratio ρ^{1-γ}=%.6f)\n",
                diag.cond_2b_terms[end], ρ_geom)
        @printf("  Condition (2a) Σ d_t:      %.6f  converges: %s\n",
                diag.sum_dividend_ratio[end], diag.condition_2a_converges)
        @printf("  Condition (2b) Σ terms:    %.6f  converges: %s\n",
                diag.sum_cond_2b[end], diag.condition_2b_converges)
        @printf("  BUBBLE EXISTS:             %s\n", diag.bubble_exists)
        println()
        println("  ── Economic interpretation ──────────────────────────")
        println("  Condition 2a: converges iff g_D_u < g_e_u (default ✓).")
        println()
        if p.ρ < 1.0
            println("  Condition 2b: λ_e·ρ^τ → 0 so (C^b/C^u)^{1-γ} ~ (ρ^{1-γ})^τ.")
            if ρ_geom < 1
                println("  ρ^{1-γ} < 1  → geometric series → CONVERGES ✓  bubble exists.")
            else
                println("  ρ^{1-γ} ≥ 1  → does not converge (need γ < 1 and ρ < 1).")
            end
        else
            println("  Condition 2b: ρ=1, C^b/C^u → λ_e (constant) → sum linear → DIVERGES.")
            println("  Set ρ < 1 (e.g. ρ = g_e_b/g_e_u ≈ 0.929) for bubble existence.")
        end
    end

    SCSimulationResult(p, paths, states, diag)
end
