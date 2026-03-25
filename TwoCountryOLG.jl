#= ================================================================
   TwoCountryOLG.jl  –  Shared types & helpers for the two-country
   OLG bubble model (Corollary_V4.tex)
   ================================================================ =#

using NLsolve, ForwardDiff, Parameters, LinearAlgebra, Printf, Statistics

# ─────────────────────────────────────────────────────────────────
# 1. Parameters
# ─────────────────────────────────────────────────────────────────

@with_kw struct ModelParams
    # Preferences
    β::Float64  = 0.50          # discount / saving propensity
    γ::Float64  = 0.5           # old-age risk aversion (CRRA); γ < 1 follows Hirano (2025)

    # Portfolio frictions
    κ::Float64      = 0.5      # home-bias cost coefficient
    ω̄::Float64      = 0.80      # US target weight on US equity
    ω̄_star::Float64 = 0.20      # RoW target weight on US equity

    # Convenience yield
    χ::Float64 = 0.005           # RoW convenience yield on US bonds

    # Bond-issuance cost
    η::Float64 = 0.01           # scaling of Υ cost

    # Regime switching
    π_persist::Float64 = 0.70   # P(z_{t+1}=u | z_t=u)

    # Growth rates (per-period; interpret each OLG period as ~5 years)
    g_e_u::Float64 = 1.025^5    # US endowment growth in state u  (~18.8% per 5yr)
    g_e_b::Float64 = 1.01^5     # balanced growth (state b, all)  (~10.4% per 5yr)
    g_D_u::Float64 = 1.015^5    # US dividend growth in state u   (~7.7% per 5yr)
    g_D_W::Float64 = 1.01^5     # RoW dividend growth (always BGP)
    g_e_W::Float64 = 1.01^5     # RoW endowment growth (always BGP)

    # Initial conditions
    e_US_0::Float64 = 1.0
    e_W_0::Float64  = 1.0
    D_e_ratio_0::Float64   = 0.04   # D_{US,0}/e_{US,0}
    D_W_e_W_ratio_0::Float64 = 0.04 # D_{W,0}/e_{W,0}

    # Switch-date scaling (Assumption 5, V4): e_US^b / e_US^u and D_US^b / D_US^u
    # Default 1.0 restores V3 behaviour (x^b = x^u at switch date)
    λ_e::Float64 = 1.0   # level scalar at t=0: e_US^b / e_US^u at switch date τ=0
    λ_D::Float64 = 1.0   # D_US^b / D_US^u  at switch date τ=0
    # Per-period decay of the b-state US endowment relative to u-state.
    # Effective scaling at switch date τ: λ_e_τ = λ_e · ρ^τ
    # ρ = 1          → constant λ_e (original spec)
    # ρ < 1          → b-state becomes increasingly worse than continuation as τ grows
    # Natural default: ρ = g_e_b/g_e_u so e_US^b(τ) = λ_e·e_US_0·g_e_b^τ regardless of τ
    ρ::Float64 = 1.01^5 / 1.025^5   # ≈ 0.929 per 5-year OLG period
    # Per-period decay of the b-state US dividends relative to u-state.
    # Effective dividend scaling at switch date τ: λ_D_τ = λ_D · ρ_D^τ
    # Natural default: ρ_D = g_e_b/g_D_u so D_US^b(τ) grows at g_e_b (same as e_US^b),
    # keeping d_b = D_US^b/e_US^b = (λ_D/λ_e)·d_0 constant — a genuine balanced state.
    # Without this, d_b ∝ (g_D_u/g_e_b)^τ → ∞, breaking the BGP assumption.
    ρ_D::Float64 = 1.01^5 / 1.015^5  # ≈ 0.976 per 5-year OLG period

    # Simulation horizon (number of OLG periods)
    T_max::Int = 120

    # Solver tolerances
    ftol::Float64    = 1e-12
    xtol::Float64    = 1e-12
    iterations::Int  = 5000
end

function validate_params(p::ModelParams)
    @assert p.κ < p.β / p.ω̄  "Lemma 1: need κ=$(p.κ) < β/ω̄=$(p.β/p.ω̄)"
    @assert 0.5 ≤ p.ω̄ ≤ 1.0  "ω̄ must be in [1/2, 1]"
    @assert 0.0 < p.ω̄_star < 0.5  "ω̄* must be in (0, 1/2)"
    @assert 0.0 < p.γ  "Need γ > 0 (CRRA curvature); γ < 1 follows Hirano (2025) for easier bubble existence"
    @assert 0.0 < p.π_persist < 1.0
    @assert p.χ > 0.0
    @assert p.η > 0.0
    @assert p.κ > 0.0
    @assert p.g_e_u > 1.0
    @assert p.g_e_b > 1.0
    @assert p.g_D_u > 1.0
    @assert p.λ_e > 0.0        "Assumption 5 (V4): λ_e = e_US^b/e_US^u must be positive"
    @assert p.λ_D > 0.0        "Assumption 5 (V4): λ_D = D_US^b/D_US^u must be positive"
    @assert 0.0 < p.ρ  ≤ 1.0  "ρ must be in (0, 1]; ρ=1 recovers constant-λ_e spec"
    @assert 0.0 < p.ρ_D ≤ 1.0 "ρ_D must be in (0, 1]; ρ_D=1 keeps dividends on u-state growth path"
    nothing
end

# ─────────────────────────────────────────────────────────────────
# 2. Issuance-cost function Υ  (Assumption 6)
# ─────────────────────────────────────────────────────────────────

abstract type IssuanceCost end
struct LogQuadraticCost <: IssuanceCost end

# Υ(θ) = -log(1-θ) + θ²/2
upsilon(::LogQuadraticCost, θ)   = -log(1 - θ) + θ^2 / 2
upsilon_prime(::LogQuadraticCost, θ)  = 1 / (1 - θ) + θ
upsilon_pprime(::LogQuadraticCost, θ) = 1 / (1 - θ)^2 + 1

const DEFAULT_COST = LogQuadraticCost()

# ─────────────────────────────────────────────────────────────────
# 3. Exogenous paths
# ─────────────────────────────────────────────────────────────────

struct ExogenousPaths
    e_US::Vector{Float64}
    D_US::Vector{Float64}
    e_W::Vector{Float64}
    D_W::Vector{Float64}
    T::Int
end

function generate_exogenous_paths(p::ModelParams)
    T = p.T_max + 1          # need values at t+1 for last period
    e_US = Vector{Float64}(undef, T)
    D_US = Vector{Float64}(undef, T)
    e_W  = Vector{Float64}(undef, T)
    D_W  = Vector{Float64}(undef, T)

    e_US[1] = p.e_US_0
    D_US[1] = p.D_e_ratio_0 * p.e_US_0
    e_W[1]  = p.e_W_0
    D_W[1]  = p.D_W_e_W_ratio_0 * p.e_W_0

    for t in 2:T
        e_US[t] = e_US[t-1] * p.g_e_u
        D_US[t] = D_US[t-1] * p.g_D_u
        e_W[t]  = e_W[t-1]  * p.g_e_W
        D_W[t]  = D_W[t-1]  * p.g_D_W
    end
    ExogenousPaths(e_US, D_US, e_W, D_W, T)
end

# ─────────────────────────────────────────────────────────────────
# 4. Return computations
# ─────────────────────────────────────────────────────────────────

"""
Compute all returns from date t to t+1.
Returns a NamedTuple (R_US, R_W, R_p, R_A, R_p_star, R_A_star).
"""
function compute_returns(Q_US_t, Q_W_t,
                         Q_US_next, Q_W_next,
                         D_US_next, D_W_next,
                         ω, ω_star, θ, θ_US_star, R_f)
    R_US = (Q_US_next + D_US_next) / Q_US_t
    R_W  = (Q_W_next  + D_W_next)  / Q_W_t

    R_p     = ω * R_US + (1 - ω) * R_W
    R_A     = (1 - θ) * R_p + θ * R_f

    R_p_star = ω_star * R_US + (1 - ω_star) * R_W
    R_A_star = (1 - θ_US_star) * R_p_star + θ_US_star * R_f

    (R_US=R_US, R_W=R_W, R_p=R_p, R_A=R_A,
     R_p_star=R_p_star, R_A_star=R_A_star)
end

# ─────────────────────────────────────────────────────────────────
# 5. Kernel helpers (ForwardDiff-compatible)
# ─────────────────────────────────────────────────────────────────

"""
Normalised US portfolio kernel values under both states.
Returns (M_u, M_b).
"""
function us_kernel(R_A_u, R_A_b, γ, π_p)
    E_R = π_p * R_A_u^(1 - γ) + (1 - π_p) * R_A_b^(1 - γ)
    M_u = R_A_u^(-γ) / E_R
    M_b = R_A_b^(-γ) / E_R
    (M_u, M_b)
end

"""
Normalised RoW portfolio kernel values under both states.
"""
function row_kernel(R_A_star_u, R_A_star_b, γ, π_p)
    E_R = π_p * R_A_star_u^(1 - γ) + (1 - π_p) * R_A_star_b^(1 - γ)
    M_u = R_A_star_u^(-γ) / E_R
    M_b = R_A_star_b^(-γ) / E_R
    (M_u, M_b)
end

"""E_t[M * f] = π*M_u*f_u + (1-π)*M_b*f_b"""
expect_Mf(M_u, M_b, f_u, f_b, π_p) = π_p * M_u * f_u + (1 - π_p) * M_b * f_b

# ─────────────────────────────────────────────────────────────────
# 6. Aggregate market-cap identity  (tex eq Qsum_identity)
# ─────────────────────────────────────────────────────────────────

Qsum(e_US, e_W, β, χ) = β * e_US + (β + χ) / (1 + χ) * e_W

# ─────────────────────────────────────────────────────────────────
# 7. Result structs
# ─────────────────────────────────────────────────────────────────

struct BalancedStateResult
    ω_b::Float64
    ω_star_b::Float64
    θ_b::Float64
    θ_US_star_b::Float64
    R_f_b::Float64
    R_f_W_b::Float64
    Q_US_hat::Float64        # Q_US / e_US  (detrended)
    Q_W_hat::Float64         # Q_W / e_US
    R_US_b::Float64
    R_W_b::Float64
    R_p_b::Float64
    R_A_b::Float64
    R_p_star_b::Float64
    R_A_star_b::Float64
    converged::Bool
    residual_norm::Float64
end

mutable struct PeriodState
    # Exogenous
    e_US::Float64; D_US::Float64; e_W::Float64; D_W::Float64
    # Analytical
    A::Float64; A_star::Float64; C_y::Float64; C_y_star::Float64
    # Solved
    ω::Float64; ω_star::Float64
    θ::Float64; θ_US_star::Float64; θ_W_star::Float64
    R_f::Float64; R_f_W::Float64
    # Derived
    S::Float64; S_star::Float64
    Q_US::Float64; Q_W::Float64
    b::Float64; b_US_star::Float64; b_W_star::Float64
end

struct BubbleDiagnostics
    dividend_ratio::Vector{Float64}       # D^u/e^u
    sum_dividend_ratio::Vector{Float64}
    cond_2b_terms::Vector{Float64}        # (C^b/C^u)^{1-γ}
    sum_cond_2b::Vector{Float64}
    a_t::Vector{Float64}                  # leakage ratio
    sum_a_t::Vector{Float64}
    cond_1a::Vector{Float64}              # D^u/Q^u
    cond_1b::Vector{Float64}
    condition_2a_converges::Bool
    condition_2b_converges::Bool
    bubble_exists::Bool
end

struct SimulationResult
    params::ModelParams
    paths::ExogenousPaths
    u_path::Vector{PeriodState}
    balanced_states::Vector{BalancedStateResult}
    diagnostics::BubbleDiagnostics
end

# ─────────────────────────────────────────────────────────────────
# 8. Balanced-state solver  (Phase 1)
# ─────────────────────────────────────────────────────────────────

"""
Solve the deterministic balanced-growth equilibrium for a given switch date.
`d` = D_US/e_US, `d_W` = D_W/e_W, `ε` = e_W/e_US at the switch date.
"""
function solve_balanced_state(p::ModelParams, d, d_W, ε; x0=nothing)
    β, γ, κ, η, χ = p.β, p.γ, p.κ, p.η, p.χ
    ω̄, ω̄s = p.ω̄, p.ω̄_star
    g_b = p.g_e_b

    # Hatted (detrended) quantities
    hat_D_US = d
    hat_D_W  = d_W * ε
    hat_A    = β
    hat_A_s  = (β + χ) / (1 + χ) * ε
    hat_Qsum = hat_A + hat_A_s           # bond clearing: S+S*=Qsum

    function residual!(F, x)
        ω_b, ω_s_b, θ_b, θ_Us_b, Rf_b = x

        # Equity savings
        S_b  = (1 - θ_b) * hat_A
        S_s_b = (1 - θ_Us_b) * hat_A_s

        # Stock prices
        Q_US_b = ω_b * S_b + ω_s_b * S_s_b
        Q_W_b  = hat_Qsum - Q_US_b

        # Guard against non-positive prices
        if Q_US_b ≤ 0 || Q_W_b ≤ 0
            F .= 1e10
            return
        end

        # Returns in balanced growth
        R_US = g_b * (Q_US_b + hat_D_US) / Q_US_b
        R_W  = g_b * (Q_W_b  + hat_D_W)  / Q_W_b

        R_p  = ω_b * R_US + (1 - ω_b) * R_W
        R_A  = (1 - θ_b) * R_p + θ_b * Rf_b

        R_p_s = ω_s_b * R_US + (1 - ω_s_b) * R_W
        R_A_s = (1 - θ_Us_b) * R_p_s + θ_Us_b * Rf_b

        if R_A ≤ 0 || R_A_s ≤ 0
            F .= 1e10
            return
        end

        # Deterministic kernel: M = 1/R_A
        # FOC 1: US ω  (tex line 217)
        F[1] = β * (1 - θ_b) * (1 / R_A) * (R_US - R_W) - κ * (ω_b - ω̄)

        # FOC 2: US θ  (tex line 222)
        F[2] = β * (1 / R_A) * (Rf_b - R_p) - η * upsilon_prime(DEFAULT_COST, θ_b)

        # FOC 3: RoW ω*  (tex line 341)
        F[3] = β * (1 - θ_Us_b) * (1 / R_A_s) * (R_US - R_W) - κ * (ω_s_b - ω̄s)

        # FOC 4: RoW US-bond  (tex line 354)
        F[4] = β * (1 / R_A_s) * (Rf_b - R_p_s) + χ / θ_Us_b

        # FOC 5: Bond clearing  (tex line 391)
        F[5] = θ_b * hat_A + θ_Us_b * hat_A_s
    end

    # Initial guess
    if x0 === nothing
        θ0  = -0.02
        θUs0 = -θ0 * hat_A / hat_A_s
        x0 = [ω̄, ω̄s, θ0, max(θUs0, 0.001), g_b]
    end

    result = nlsolve(residual!, x0,
                     autodiff=:forward, method=:trust_region,
                     ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)

    if !converged(result)
        # Fallback: Newton with try-catch for singular Jacobian
        try
            result2 = nlsolve(residual!, x0,
                             autodiff=:forward, method=:newton,
                             ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)
            if converged(result2)
                result = result2
            end
        catch
        end
    end

    if !converged(result)
        # Fallback: try from default initial guess
        θ0_def  = -0.02
        θUs0_def = -θ0_def * hat_A / hat_A_s
        x0_def = [ω̄, ω̄s, θ0_def, max(θUs0_def, 0.001), g_b]
        try
            result3 = nlsolve(residual!, x0_def,
                             autodiff=:forward, method=:trust_region,
                             ftol=1e-10, xtol=1e-10, iterations=10000)
            if converged(result3)
                result = result3
            end
        catch
        end
    end

    x = result.zero
    ω_b, ω_s_b, θ_b, θ_Us_b, Rf_b = x

    S_b   = (1 - θ_b) * hat_A
    S_s_b = (1 - θ_Us_b) * hat_A_s
    Q_US_hat = ω_b * S_b + ω_s_b * S_s_b
    Q_W_hat  = hat_Qsum - Q_US_hat

    R_US = g_b * (Q_US_hat + hat_D_US) / Q_US_hat
    R_W  = g_b * (Q_W_hat  + hat_D_W)  / Q_W_hat
    R_p  = ω_b * R_US + (1 - ω_b) * R_W
    R_A  = (1 - θ_b) * R_p + θ_b * Rf_b
    R_p_s = ω_s_b * R_US + (1 - ω_s_b) * R_W
    R_A_s = (1 - θ_Us_b) * R_p_s + θ_Us_b * Rf_b

    # RoW domestic bond FOC (deterministic): R_f_W = R_p* (tex line 348)
    R_f_W_b = R_p_s

    BalancedStateResult(ω_b, ω_s_b, θ_b, θ_Us_b, Rf_b, R_f_W_b,
                        Q_US_hat, Q_W_hat,
                        R_US, R_W, R_p, R_A, R_p_s, R_A_s,
                        converged(result), result.residual_norm)
end

# ─────────────────────────────────────────────────────────────────
# 9. u-Path equilibrium residual  (Phase 2, 6×6 system)
#    Formulated in DETRENDED variables to avoid exponential scaling.
#    Unknowns: (ω, ω*, θ, θ*_US, R_f, q_US)
#    where q_US = Q_US / e_US(t)  is the detrended stock price.
#
#    The system also supports a CONSTRAINED formulation where:
#      θ = -exp(x[3])      (enforces θ < 0)
#      θ*_US = exp(x[4])   (enforces θ*_US > 0)
#    This prevents the solver from jumping to wrong equilibrium branches.
# ─────────────────────────────────────────────────────────────────

"""
Core residual computation for the u-path 6-equation system.
Takes actual (ω, ω*, θ, θ*_US, R_f, q_US) values (not transformed).
"""
function _u_path_core_residual!(F, ω, ω_s, θ, θ_Us, Rf, q_US,
                                t, paths, bs_next,
                                q_US_u_next, q_W_u_next, p)
    β, γ, κ, η, χ = p.β, p.γ, p.κ, p.η, p.χ
    ω̄, ω̄s = p.ω̄, p.ω̄_star
    π_p = p.π_persist

    e_US_t = paths.e_US[t]
    e_W_t  = paths.e_W[t]
    ε_t    = e_W_t / e_US_t

    hat_A    = β
    hat_A_s  = (β + χ) / (1 + χ) * ε_t

    hat_S    = (1 - θ) * hat_A
    hat_S_s  = (1 - θ_Us) * hat_A_s

    hat_Qsum = hat_A + hat_A_s
    q_W      = hat_Qsum - q_US

    # Guard: only require stock prices positive
    if q_US ≤ 0 || q_W ≤ 0
        pen = 1e10
        if q_US ≤ 0; pen += abs(q_US) * 1e12; end
        if q_W ≤ 0; pen += abs(q_W) * 1e12; end
        F .= pen; return
    end

    g_e = paths.e_US[t+1] / e_US_t
    d_next = paths.D_US[t+1] / paths.e_US[t+1]
    d_W_next_hat = paths.D_W[t+1] / paths.e_US[t+1]

    # Returns under u at t+1
    R_US_u = g_e * (q_US_u_next + d_next) / q_US
    R_W_u  = g_e * (q_W_u_next  + d_W_next_hat) / q_W

    R_p_u    = ω * R_US_u + (1 - ω) * R_W_u
    R_A_u    = (1 - θ) * R_p_u + θ * Rf
    R_ps_u   = ω_s * R_US_u + (1 - ω_s) * R_W_u
    R_As_u   = (1 - θ_Us) * R_ps_u + θ_Us * Rf

    # Returns under b at t+1
    # bs_next stores Q_hat detrended by e_US^b; actual level = Q_hat * λ_e_tp1 * e_US^u
    # λ_e at switch date t+1: λ_e · ρ^(t+1)  (decays with the switch date)
    # D_US^b = λ_D · ρ_D^(t+1) · D_US^u  (b-state dividend scaling at switch date t+1)
    q_US_b   = bs_next.Q_US_hat
    q_W_b    = bs_next.Q_W_hat
    λ_e_tp1  = p.λ_e  * p.ρ^(t + 1)
    λ_D_tp1  = p.λ_D  * p.ρ_D^(t + 1)

    R_US_b = g_e * (q_US_b * λ_e_tp1 + λ_D_tp1 * d_next) / q_US
    R_W_b  = g_e * (q_W_b  * λ_e_tp1 + d_W_next_hat)   / q_W

    R_p_b    = ω * R_US_b + (1 - ω) * R_W_b
    R_A_b    = (1 - θ) * R_p_b + θ * Rf
    R_ps_b   = ω_s * R_US_b + (1 - ω_s) * R_W_b
    R_As_b   = (1 - θ_Us) * R_ps_b + θ_Us * Rf

    if R_A_u ≤ 0 || R_A_b ≤ 0 || R_As_u ≤ 0 || R_As_b ≤ 0
        pen = 1e10
        for v in [R_A_u, R_A_b, R_As_u, R_As_b]
            if v ≤ 0; pen += abs(v) * 1e12; end
        end
        F .= pen; return
    end

    # Kernels
    M_u, M_b   = us_kernel(R_A_u, R_A_b, γ, π_p)
    Ms_u, Ms_b = row_kernel(R_As_u, R_As_b, γ, π_p)

    # Expected terms
    E_M_dR   = expect_Mf(M_u, M_b, R_US_u - R_W_u, R_US_b - R_W_b, π_p)
    E_M_dRf  = expect_Mf(M_u, M_b, Rf - R_p_u, Rf - R_p_b, π_p)
    E_Ms_dR  = expect_Mf(Ms_u, Ms_b, R_US_u - R_W_u, R_US_b - R_W_b, π_p)
    E_Ms_dRf = expect_Mf(Ms_u, Ms_b, Rf - R_ps_u, Rf - R_ps_b, π_p)

    # 6 residuals
    F[1] = β * (1 - θ)    * E_M_dR  - κ * (ω   - ω̄)
    F[2] = β * E_M_dRf  - η * upsilon_prime(DEFAULT_COST, θ)
    F[3] = β * (1 - θ_Us) * E_Ms_dR - κ * (ω_s - ω̄s)
    F[4] = β * E_Ms_dRf + χ / θ_Us
    F[5] = ω * hat_S + ω_s * hat_S_s - q_US
    F[6] = θ * hat_A + θ_Us * hat_A_s
end

"""
Core residual for u-path asymptote: identical to `_u_path_core_residual!` but
accepts scalar `g_e`, `d_next`, `d_W_next_hat`, `ε` directly instead of
reading from `paths[t]`.  Used by `solve_u_state_asymptote`.

`λ_e_eff` is the effective b-state scaling at the terminal date T:
  λ_e_eff = λ_e · ρ^T   (passed explicitly so the asymptote reflects the
  actual decay at T rather than the level-0 value λ_e).
"""
function _u_path_asymptote_core!(F, ω, ω_s, θ, θ_Us, Rf, q_US,
                                  q_US_u_next, q_W_u_next,
                                  g_e, d_next, d_W_next_hat, ε,
                                  bs_next, p, λ_e_eff)
    β, γ, κ, η, χ = p.β, p.γ, p.κ, p.η, p.χ
    ω̄, ω̄s = p.ω̄, p.ω̄_star
    π_p = p.π_persist

    ε_t = ε

    hat_A    = β
    hat_A_s  = (β + χ) / (1 + χ) * ε_t

    hat_S    = (1 - θ) * hat_A
    hat_S_s  = (1 - θ_Us) * hat_A_s

    hat_Qsum = hat_A + hat_A_s
    q_W      = hat_Qsum - q_US

    # Guard: only require stock prices positive
    if q_US ≤ 0 || q_W ≤ 0
        pen = 1e10
        if q_US ≤ 0; pen += abs(q_US) * 1e12; end
        if q_W ≤ 0; pen += abs(q_W) * 1e12; end
        F .= pen; return
    end

    # Returns under u at t+1
    R_US_u = g_e * (q_US_u_next + d_next) / q_US
    R_W_u  = g_e * (q_W_u_next  + d_W_next_hat) / q_W

    R_p_u    = ω * R_US_u + (1 - ω) * R_W_u
    R_A_u    = (1 - θ) * R_p_u + θ * Rf
    R_ps_u   = ω_s * R_US_u + (1 - ω_s) * R_W_u
    R_As_u   = (1 - θ_Us) * R_ps_u + θ_Us * Rf

    # Returns under b at t+1 (uses λ_e_eff = λ_e · ρ^T for terminal-period asymptote)
    q_US_b = bs_next.Q_US_hat
    q_W_b  = bs_next.Q_W_hat

    R_US_b = g_e * (q_US_b * λ_e_eff + p.λ_D * d_next) / q_US
    R_W_b  = g_e * (q_W_b  * λ_e_eff + d_W_next_hat)   / q_W

    R_p_b    = ω * R_US_b + (1 - ω) * R_W_b
    R_A_b    = (1 - θ) * R_p_b + θ * Rf
    R_ps_b   = ω_s * R_US_b + (1 - ω_s) * R_W_b
    R_As_b   = (1 - θ_Us) * R_ps_b + θ_Us * Rf

    if R_A_u ≤ 0 || R_A_b ≤ 0 || R_As_u ≤ 0 || R_As_b ≤ 0
        pen = 1e10
        for v in [R_A_u, R_A_b, R_As_u, R_As_b]
            if v ≤ 0; pen += abs(v) * 1e12; end
        end
        F .= pen; return
    end

    # Kernels
    M_u, M_b   = us_kernel(R_A_u, R_A_b, γ, π_p)
    Ms_u, Ms_b = row_kernel(R_As_u, R_As_b, γ, π_p)

    # Expected terms
    E_M_dR   = expect_Mf(M_u, M_b, R_US_u - R_W_u, R_US_b - R_W_b, π_p)
    E_M_dRf  = expect_Mf(M_u, M_b, Rf - R_p_u, Rf - R_p_b, π_p)
    E_Ms_dR  = expect_Mf(Ms_u, Ms_b, R_US_u - R_W_u, R_US_b - R_W_b, π_p)
    E_Ms_dRf = expect_Mf(Ms_u, Ms_b, Rf - R_ps_u, Rf - R_ps_b, π_p)

    # 6 residuals
    F[1] = β * (1 - θ)    * E_M_dR  - κ * (ω   - ω̄)
    F[2] = β * E_M_dRf  - η * upsilon_prime(DEFAULT_COST, θ)
    F[3] = β * (1 - θ_Us) * E_Ms_dR - κ * (ω_s - ω̄s)
    F[4] = β * E_Ms_dRf + χ / θ_Us
    F[5] = ω * hat_S + ω_s * hat_S_s - q_US
    F[6] = θ * hat_A + θ_Us * hat_A_s
end

"""
Compute the u-path self-consistent fixed point as d_t → 0, ε_t → 0.
This is the correct infinite-horizon boundary condition (no-bubble asymptote)
for use as the terminal condition in backward induction.
"""
function solve_u_state_asymptote(p::ModelParams; ε_min::Float64 = 1e-6)
    # Effective λ_e at the terminal date T: λ_e · ρ^T
    λ_e_T = p.λ_e * p.ρ^p.T_max

    # Step 1: b-state asymptote at d_b = 0, ε_b = ε_min / λ_e_T
    bs_asym = solve_balanced_state(p, 0.0, 0.0, ε_min / λ_e_T)

    β, χ = p.β, p.χ
    ε = ε_min
    hat_Qsum = β + (β + χ) / (1 + χ) * ε

    # Step 2: self-referential residual — fixed point: q_US_u_next = q_US
    function resid!(F, x_c)
        x = _from_constrained(x_c)
        ω, ω_s, θ, θ_Us, Rf, q_US = x
        q_US_u_next = q_US               # fixed-point condition
        q_W_u_next  = hat_Qsum - q_US
        _u_path_asymptote_core!(F, ω, ω_s, θ, θ_Us, Rf, q_US,
                                 q_US_u_next, q_W_u_next,
                                 p.g_e_u, 0.0, 0.0, ε, bs_asym, p, λ_e_T)
    end

    # Step 3: try two initial guesses, keep best-converged result
    # Guess A: balanced-state asymptote (high-ω branch)
    x0_a = [bs_asym.ω_b, bs_asym.ω_star_b, bs_asym.θ_b,
             bs_asym.θ_US_star_b, bs_asym.R_f_b, bs_asym.Q_US_hat * λ_e_T]
    # Guess B: low-ω branch (typical u-path solution at late dates)
    x0_b = [0.15, p.ω̄_star, -0.5, 0.5, p.g_e_u, β * 0.15]

    best = nothing
    for x0 in [x0_a, x0_b]
        x0_c = _to_constrained(x0)
        try
            r = nlsolve(resid!, x0_c, autodiff=:forward, method=:trust_region,
                        ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)
            if converged(r) && (best === nothing || r.residual_norm < best.residual_norm)
                best = r
            end
        catch; end
    end

    best === nothing && @warn "solve_u_state_asymptote did not converge; falling back to balanced-state"
    x = best !== nothing ? _from_constrained(best.zero) : x0_a

    ω, ω_s, θ, θ_Us, Rf, q_US = x
    q_W = hat_Qsum - q_US
    return (q_US=q_US, q_W=q_W, ω=ω, ω_s=ω_s, θ=θ, θ_Us=θ_Us, Rf=Rf,
            converged = best !== nothing && converged(best))
end

"""
UNCONSTRAINED residual: x = [ω, ω*, θ, θ*_US, R_f, q_US] directly.
"""
function u_path_residual!(F, x, t, paths, bs_next,
                          q_US_u_next, q_W_u_next, p)
    ω, ω_s, θ, θ_Us, Rf, q_US = x
    _u_path_core_residual!(F, ω, ω_s, θ, θ_Us, Rf, q_US,
                           t, paths, bs_next, q_US_u_next, q_W_u_next, p)
end

"""
CONSTRAINED residual: x = [ω, ω*, log(-θ), log(θ*_US), R_f, q_US].
The log-transformation enforces θ < 0 and θ*_US > 0.
"""
function u_path_residual_constrained!(F, x, t, paths, bs_next,
                                      q_US_u_next, q_W_u_next, p)
    ω, ω_s, log_neg_θ, log_θ_Us, Rf, q_US = x
    θ     = -exp(log_neg_θ)
    θ_Us  = exp(log_θ_Us)
    _u_path_core_residual!(F, ω, ω_s, θ, θ_Us, Rf, q_US,
                           t, paths, bs_next, q_US_u_next, q_W_u_next, p)
end

# ─────────────────────────────────────────────────────────────────
# 10. Backward induction along the u-path
# ─────────────────────────────────────────────────────────────────

function build_period_state(t, paths, ω, ω_s, θ, θ_Us, Rf, Q_US, p)
    e_US = paths.e_US[t]; e_W = paths.e_W[t]
    D_US_t = paths.D_US[t]; D_W_t = paths.D_W[t]
    A    = p.β * e_US
    A_s  = (p.β + p.χ) / (1 + p.χ) * e_W
    C_y  = (1 - p.β) * e_US
    C_ys = (1 - p.β) / (1 + p.χ) * e_W
    S    = (1 - θ) * A
    S_s  = (1 - θ_Us) * A_s
    Q_sum = Qsum(e_US, e_W, p.β, p.χ)
    Q_W  = Q_sum - Q_US
    b    = θ * A
    bUs  = θ_Us * A_s

    PeriodState(e_US, D_US_t, e_W, D_W_t,
                A, A_s, C_y, C_ys,
                ω, ω_s, θ, θ_Us, 0.0,
                Rf, 0.0,    # R_f_W filled later
                S, S_s, Q_US, Q_W,
                b, bUs, 0.0)
end

"""
Convert actual values to constrained parameterisation.
x_actual = [ω, ω*, θ, θ*_US, R_f, q_US]  →  x_c = [ω, ω*, log(-θ), log(θ*_US), R_f, q_US]
"""
function _to_constrained(x_actual)
    ω, ω_s, θ, θ_Us, Rf, q_US = x_actual
    # Safeguard: ensure θ < 0 and θ*_US > 0 for log transform
    θ_safe     = θ < -1e-15 ? θ : -1e-3
    θ_Us_safe  = θ_Us > 1e-15 ? θ_Us : 1e-3
    [ω, ω_s, log(-θ_safe), log(θ_Us_safe), Rf, q_US]
end

"""Convert constrained parameterisation back to actual values."""
function _from_constrained(x_c)
    ω, ω_s, log_neg_θ, log_θ_Us, Rf, q_US = x_c
    [ω, ω_s, -exp(log_neg_θ), exp(log_θ_Us), Rf, q_US]
end

"""
Try to solve the u-path system at date t.
Returns (converged::Bool, x_actual, residual_norm).
Uses constrained (log-transform) formulation first, then unconstrained fallback.
"""
function _solve_u_path_at_t(t, paths, bs_next, q_US_u_next, q_W_u_next,
                            p, x_bs_actual, x_prev_actual)
    ftol, xtol, iters = p.ftol, p.xtol, p.iterations
    best_res = nothing
    best_rnorm = Inf

    # Helper to try a solve and track best
    function try_solve!(make_res)
        try
            r = make_res()
            if converged(r) && r.residual_norm < best_rnorm
                best_res = r
                best_rnorm = r.residual_norm
            end
        catch
        end
        return best_rnorm < 1e-8
    end

    # ── Strategy 1: Constrained solver from balanced-state guess ──
    x_c_bs = _to_constrained(x_bs_actual)
    done = try_solve!() do
        nlsolve(
            (F, x) -> u_path_residual_constrained!(F, x, t, paths, bs_next,
                                                    q_US_u_next, q_W_u_next, p),
            x_c_bs, autodiff=:forward, method=:trust_region,
            ftol=ftol, xtol=xtol, iterations=iters)
    end
    done && @goto finish_constrained

    # ── Strategy 2: Constrained solver from previous solution ──
    x_c_prev = _to_constrained(x_prev_actual)
    done = try_solve!() do
        nlsolve(
            (F, x) -> u_path_residual_constrained!(F, x, t, paths, bs_next,
                                                    q_US_u_next, q_W_u_next, p),
            x_c_prev, autodiff=:forward, method=:trust_region,
            ftol=ftol, xtol=xtol, iterations=iters)
    end
    done && @goto finish_constrained

    # ── Strategy 3: Constrained Newton from balanced-state ──
    done = try_solve!() do
        nlsolve(
            (F, x) -> u_path_residual_constrained!(F, x, t, paths, bs_next,
                                                    q_US_u_next, q_W_u_next, p),
            x_c_bs, autodiff=:forward, method=:newton,
            ftol=ftol, xtol=xtol, iterations=iters)
    end
    done && @goto finish_constrained

    # ── Strategy 4: Constrained with perturbed q_US ──
    for α in [0.95, 1.05, 0.90, 1.10, 0.80, 1.20]
        x_c_pert = copy(x_c_bs)
        x_c_pert[6] *= α
        done = try_solve!() do
            nlsolve(
                (F, x) -> u_path_residual_constrained!(F, x, t, paths, bs_next,
                                                        q_US_u_next, q_W_u_next, p),
                x_c_pert, autodiff=:forward, method=:trust_region,
                ftol=1e-10, xtol=1e-10, iterations=10000)
        end
        done && @goto finish_constrained
    end

    @label finish_constrained
    # If we found a constrained solution, convert back
    if best_res !== nothing && best_rnorm < 1e-8
        x_c = best_res.zero
        x_actual = _from_constrained(x_c)
        return (true, x_actual, best_rnorm)
    end

    # ── Strategy 5: Unconstrained fallback from balanced-state ──
    done = try_solve!() do
        nlsolve(
            (F, x) -> u_path_residual!(F, x, t, paths, bs_next,
                                       q_US_u_next, q_W_u_next, p),
            x_bs_actual, autodiff=:forward, method=:trust_region,
            ftol=ftol, xtol=xtol, iterations=iters)
    end

    # ── Strategy 6: Unconstrained from previous ──
    if !done
        try_solve!() do
            nlsolve(
                (F, x) -> u_path_residual!(F, x, t, paths, bs_next,
                                           q_US_u_next, q_W_u_next, p),
                x_prev_actual, autodiff=:forward, method=:trust_region,
                ftol=ftol, xtol=xtol, iterations=iters)
        end
    end

    if best_res !== nothing
        x = best_res.zero
        # Check if this is a constrained result
        if best_rnorm < 1e-8 && length(x) == 6
            # Try to distinguish: if x[3] and x[4] look like log values,
            # it's a constrained result
        end
        # For unconstrained, the result is direct
        x_actual = x
        return (converged(best_res), x_actual, best_rnorm)
    end

    # Complete failure — return balanced-state values
    return (false, x_bs_actual, Inf)
end

function solve_u_path(p::ModelParams, paths::ExogenousPaths,
                      balanced_states::Vector{BalancedStateResult};
                      verbose=false)
    T = p.T_max
    u_path = Vector{PeriodState}(undef, T)

    # ── Terminal condition: u-path self-consistent asymptote ──
    # Solves the fixed point of the 6-eq system as d_t → 0, ε_t → 0.
    # This is the correct infinite-horizon boundary for the no-bubble equilibrium,
    # replacing the previous b-state price (which caused an artificial jump at T).
    asym   = solve_u_state_asymptote(p)
    q_US_T = asym.q_US
    Q_US_T = q_US_T * paths.e_US[T]
    u_path[T] = build_period_state(T, paths,
                    asym.ω, asym.ω_s, asym.θ,
                    asym.θ_Us, asym.Rf, Q_US_T, p)

    ε_T = paths.e_W[T] / paths.e_US[T]
    hat_Qsum_T = p.β + (p.β + p.χ) / (1 + p.χ) * ε_T
    q_W_T = hat_Qsum_T - q_US_T

    q_US_u_next = q_US_T
    q_W_u_next  = q_W_T

    x_prev = [asym.ω, asym.ω_s, asym.θ, asym.θ_Us, asym.Rf, q_US_T]

    n_fail = 0
    for t in (T-1):-1:1
        bs_next = balanced_states[t+1]
        bs_t = balanced_states[t]

        x_bs = [bs_t.ω_b, bs_t.ω_star_b, bs_t.θ_b,
                bs_t.θ_US_star_b, bs_t.R_f_b, bs_t.Q_US_hat]

        conv, x_sol, rnorm = _solve_u_path_at_t(
            t, paths, bs_next, q_US_u_next, q_W_u_next, p, x_bs, x_prev)

        if !conv
            n_fail += 1
            verbose && @warn "Solver did not converge at t=$t, ‖F‖=$(rnorm)"
        end

        ω, ω_s, θ, θ_Us, Rf, q_US = x_sol

        Q_US_level = q_US * paths.e_US[t]
        u_path[t] = build_period_state(t, paths, ω, ω_s, θ, θ_Us, Rf, Q_US_level, p)

        q_US_u_next = q_US
        ε_t = paths.e_W[t] / paths.e_US[t]
        hat_Qsum_t = p.β + (p.β + p.χ) / (1 + p.χ) * ε_t
        q_W_u_next  = hat_Qsum_t - q_US

        x_prev = x_sol

        verbose && t % 10 == 0 &&
            @printf("  t=%3d: ω=%.4f  θ=%+.6f  θ*_US=%+.4f  R_f=%.4f  q_US=%.6f  ‖F‖=%.1e\n",
                    t, ω, θ, θ_Us, Rf, q_US, rnorm)
    end

    verbose && println("  u-path: $(T-1-n_fail)/$(T-1) periods converged.")

    # ── Fill R_f_W by the RoW domestic-bond FOC ──
    for t in 1:(T-1)
        s = u_path[t]
        D_US_next = paths.D_US[t+1]
        D_W_next  = paths.D_W[t+1]

        Q_US_next_u = u_path[t+1].Q_US
        Q_W_next_u  = u_path[t+1].Q_W

        bs_next = balanced_states[t+1]
        # Effective λ_e at switch date t+1: λ_e · ρ^(t+1)
        # actual b-state price = Q_hat * λ_e_{t+1} * e_US^u
        λ_e_tp1 = p.λ_e  * p.ρ^(t + 1)
        λ_D_tp1 = p.λ_D  * p.ρ_D^(t + 1)
        Q_US_next_b = bs_next.Q_US_hat * λ_e_tp1 * paths.e_US[t+1]
        Q_W_next_b  = bs_next.Q_W_hat  * λ_e_tp1 * paths.e_US[t+1]
        D_US_next_b = λ_D_tp1 * D_US_next

        R_US_u = (Q_US_next_u + D_US_next)   / s.Q_US
        R_W_u  = (Q_W_next_u  + D_W_next)    / s.Q_W
        R_US_b = (Q_US_next_b + D_US_next_b) / s.Q_US
        R_W_b  = (Q_W_next_b  + D_W_next)    / s.Q_W

        R_ps_u = s.ω_star * R_US_u + (1 - s.ω_star) * R_W_u
        R_ps_b = s.ω_star * R_US_b + (1 - s.ω_star) * R_W_b
        R_As_u = (1 - s.θ_US_star) * R_ps_u + s.θ_US_star * s.R_f
        R_As_b = (1 - s.θ_US_star) * R_ps_b + s.θ_US_star * s.R_f

        Ms_u, Ms_b = row_kernel(R_As_u, R_As_b, p.γ, p.π_persist)
        E_Ms      = p.π_persist * Ms_u + (1 - p.π_persist) * Ms_b
        E_Ms_Rps  = expect_Mf(Ms_u, Ms_b, R_ps_u, R_ps_b, p.π_persist)

        u_path[t].R_f_W = E_Ms_Rps / E_Ms
    end
    u_path[T].R_f_W = balanced_states[T].R_f_W_b

    u_path
end

# ─────────────────────────────────────────────────────────────────
# 11. Bubble diagnostics
# ─────────────────────────────────────────────────────────────────

function compute_bubble_diagnostics(p::ModelParams,
        u_path::Vector{PeriodState},
        balanced_states::Vector{BalancedStateResult},
        paths::ExogenousPaths)
    T = length(u_path)
    π_p = p.π_persist
    γ   = p.γ

    dividend_ratio = zeros(T)
    cond_1a = zeros(T)
    cond_1b = zeros(T)
    cond_2b_terms = zeros(T)
    a_t = zeros(T)

    for t in 2:T
        D_u = paths.D_US[t]
        e_u = paths.e_US[t]
        Q_u = u_path[t].Q_US

        dividend_ratio[t] = D_u / e_u
        cond_1a[t] = D_u / Q_u

        # Portfolio allocation at t-1
        s_prev = u_path[t-1]

        # Returns under u at t
        ret_u = compute_returns(s_prev.Q_US, s_prev.Q_W,
                    u_path[t].Q_US, u_path[t].Q_W,
                    paths.D_US[t], paths.D_W[t],
                    s_prev.ω, s_prev.ω_star,
                    s_prev.θ, s_prev.θ_US_star, s_prev.R_f)

        # Returns under b at t (switch)
        # Effective λ_e at switch date t: λ_e · ρ^t
        # Q^b = Q_hat * λ_e_t * e_US^u,  D_US^b = λ_D_t * D_US^u
        bs_t   = balanced_states[t]
        λ_e_t  = p.λ_e  * p.ρ^t
        λ_D_t  = p.λ_D  * p.ρ_D^t
        Q_US_b = bs_t.Q_US_hat * λ_e_t * paths.e_US[t]
        Q_W_b  = bs_t.Q_W_hat  * λ_e_t * paths.e_US[t]
        D_US_b = λ_D_t * paths.D_US[t]
        ret_b = compute_returns(s_prev.Q_US, s_prev.Q_W,
                    Q_US_b, Q_W_b,
                    D_US_b, paths.D_W[t],
                    s_prev.ω, s_prev.ω_star,
                    s_prev.θ, s_prev.θ_US_star, s_prev.R_f)

        A_prev = p.β * paths.e_US[t-1]
        C_u = A_prev * ret_u.R_A
        C_b = A_prev * ret_b.R_A

        ratio = C_b / C_u
        cond_2b_terms[t] = ratio^(1 - γ)

        Q_b_plus_D = Q_US_b + D_US_b
        cond_1b[t] = ratio^(1 - γ) * Q_b_plus_D / C_b * C_u / Q_u

        a_t[t] = cond_1a[t] +
                 (1 - π_p) / π_p * (C_u / C_b)^γ * Q_b_plus_D / Q_u
    end

    sum_dr  = cumsum(dividend_ratio)
    sum_2b  = cumsum(cond_2b_terms)
    sum_at  = cumsum(a_t)

    n_tail = max(1, T ÷ 10)
    tail_2a = sum_dr[end] - sum_dr[end - n_tail]
    tail_2b = sum_2b[end] - sum_2b[end - n_tail]

    conv_2a = tail_2a < 0.01 * max(sum_dr[end], 1e-15)
    conv_2b = tail_2b < 0.01 * max(sum_2b[end], 1e-15)

    BubbleDiagnostics(dividend_ratio, sum_dr,
                      cond_2b_terms, sum_2b,
                      a_t, sum_at,
                      cond_1a, cond_1b,
                      conv_2a, conv_2b,
                      conv_2a && conv_2b)
end

# ─────────────────────────────────────────────────────────────────
# 12. Top-level orchestrator
# ─────────────────────────────────────────────────────────────────

function run_simulation(p::ModelParams=ModelParams(); verbose=true)
    validate_params(p)

    verbose && println("Generating exogenous paths...")
    paths = generate_exogenous_paths(p)

    verbose && println("Solving balanced-growth states...")
    T = p.T_max + 1
    bs = Vector{BalancedStateResult}(undef, T)
    x0_bs = nothing

    for t in 1:T
        # Effective scalings at switch date t: λ_e_t = λ_e·ρ^t, λ_D_t = λ_D·ρ_D^t
        # d_b = D_US^b/e_US^b = (λ_D_t·D_US^u)/(λ_e_t·e_US^u)  → (λ_D/λ_e)·d_0  (constant)
        # eps_b = e_W/e_US^b = (e_W/e_US^u)/λ_e_t                (RoW endowment unchanged)
        λ_e_t = p.λ_e  * p.ρ^t
        λ_D_t = p.λ_D  * p.ρ_D^t
        d_b   = (λ_D_t / λ_e_t) * paths.D_US[t] / paths.e_US[t]
        dW    = paths.D_W[t] / paths.e_W[t]
        eps_b = (paths.e_W[t] / paths.e_US[t]) / λ_e_t
        try
            bs[t] = solve_balanced_state(p, d_b, dW, eps_b; x0=x0_bs)
        catch
            # Reset initial guess on failure
            bs[t] = solve_balanced_state(p, d_b, dW, eps_b; x0=nothing)
        end
        if !bs[t].converged
            @warn "Balanced state did not converge at t=$t"
        end
        # Only warm-start from converged solutions
        if bs[t].converged
            x0_bs = [bs[t].ω_b, bs[t].ω_star_b, bs[t].θ_b,
                     bs[t].θ_US_star_b, bs[t].R_f_b]
        end
        verbose && t % 20 == 0 &&
            @printf("  t=%3d: ω_b=%.4f  θ_b=%.6f  R_f_b=%.4f\n",
                    t, bs[t].ω_b, bs[t].θ_b, bs[t].R_f_b)
    end

    verbose && println("Solving u-path by backward induction...")
    u = solve_u_path(p, paths, bs; verbose=verbose)

    verbose && println("Computing bubble diagnostics...")
    diag = compute_bubble_diagnostics(p, u, bs, paths)

    if verbose
        println("\n══════ BUBBLE DIAGNOSTIC RESULTS ══════")
        @printf("  Condition (2a) converges: %s  (Σ = %.6f)\n",
                diag.condition_2a_converges, diag.sum_dividend_ratio[end])
        @printf("  Condition (2b) converges: %s  (Σ = %.6f)\n",
                diag.condition_2b_converges, diag.sum_cond_2b[end])
        @printf("  BUBBLE EXISTS: %s\n", diag.bubble_exists)
        @printf("  Total leakage Σ a_t = %.6f\n", diag.sum_a_t[end])
    end

    SimulationResult(p, paths, u, bs, diag)
end
