#= ================================================================
   TwoCountryProductionOLG.jl  –  Fixed-ν_b types & helpers for the
   two-country PRODUCTION OLG bubble model (V4_3_production.tex)

   Extension of TwoCountryOLG.jl from endowment to production:
   - Two-country CES production with skilled/unskilled labor
   - Endogenous labor allocations φ_US, φ_W
   - Per-variety stock prices q_i and dividends d_i (HKT primitive)
   - Aggregate market caps Q_i = N_{i,t+1} q_i
   - IPO transfer I_i := (1-φ_i)·H_i·w_{H,i} = (N_{i,t+1}-N_i)·q_i
       (V4_3 eq. country_ipo_transfer)
   - V4_3 output decomposition Y_i = e_i + N_i·d_i - I_i
       (V4_3 eq. country_output_income_identity; V9 used Y = e + D)
   - Effective-kernel regularity Ψ_t > 0
       (V4_3 ass_regular_kernel)
   - Reduced 7-equation Markov competitive equilibrium with
       primary unknowns x = (φ_US, φ_W, ω, θ_US^*, ω^*, R_f, R_f^W)
       (V4_3 lines 745–755, 787–788); recovered θ = -θ_US^*·A^*/A
   - ν_b is an exogenous primitive held fixed at every switch state;
       no common-world-growth equation or local ν_b recalibration is solved
   ================================================================ =#

using NLsolve, ForwardDiff, Parameters, LinearAlgebra, Printf, Statistics

# ─────────────────────────────────────────────────────────────────
# 1. Parameters
#
# Except for the requested absorbing exponents, the DEFAULTS reproduce the
# single-country numerical example of Hirano-Kishi-Toda (2025,
# arXiv:2501.08215, §4.2), mapped onto the two-country structure:
#   β=1/2, α=1/2, ρ=2, ϑ(θ)=1/2, A_X·H=10, A_L·L=1,
#   ξ_u=0.7, ν_u(=λ_u)=0.2, a·H=0.2, N_0=1,
# while this workflow sets the fixed primitives ν_b=ξ_W=1.0.
# HKT's gentle knowledge growth (a·H=0.2 ⇒ G_u→1.2) keeps the u-branch
# solver well-conditioned to T≳100. The original fast-growth example
# (a_US·H=1.2 ⇒ G_u→2.2, T≈20 wall) is available via fast_growth_params().
# The portfolio block (κ, ω̄, ω̄*, χ, η, π) has no HKT counterpart.
#
# This fixed-ν_b variant deliberately does not impose the separate
# common-world-growth selection condition G_b=G_W. The US absorbing exponent
# ν_b and the RoW exponent ξ_W are independent primitives, so their implied
# growth rates may differ. `common_world_growth` is retained only so old
# notebook constructors fail clearly rather than silently changing semantics.
# ─────────────────────────────────────────────────────────────────

@with_kw struct ProductionParams
    # ── Preferences ──
    β::Float64  = 0.50                 # saving propensity
    γ::Float64  = 0.50                 # CRRA curvature; γ < 1 favours bubbles

    # ── Portfolio frictions ──
    κ::Float64       = 0.10            # home-bias quadratic cost
    ω̄::Float64       = 0.80            # US target weight on US equity
    ω̄_star::Float64  = 0.20            # RoW target weight on US equity

    # ── US bond convenience yield (RoW preference) ──
    χ::Float64 = 0.005

    # ── Bond-issuance cost ──
    η::Float64 = 0.01                  # scaling of Υ

    # ── Regime switching ──
    π_persist::Float64 = 0.70          # P(z_{t+1}=u | z_t=u)

    # ── US production technology (CES) ──
    # ρ > 1 (substitutes); larger ρ accelerates φ_US^u decay (ψ_US = (ξ_u-ν_u)(ρ_US-1)).
    α_US::Float64  = 0.50              # CES weight on knowledge input (HKT α=1/2; was 0.40)
    ρ_US::Float64  = 2.00              # CES exponent (HKT ρ=2; ρ>1 needed for bubble theory)
    ϑ_US::Float64  = 0.50              # intermediate-firm elasticity (HKT θ=1/2; was 0.66)
    a_US::Float64  = 0.20              # R&D productivity (HKT aH=0.2 with H=1; was 1.20)
    H_US::Float64  = 1.0               # mass of skilled workers
    L_US::Float64  = 1.0               # mass of unskilled workers

    # ── RoW production technology (CES) ──
    α_W::Float64   = 0.50              # RoW mirrors HKT's balanced regime (was 0.30)
    ρ_W::Float64   = 2.00              # (was 1.50)
    ϑ_W::Float64   = 0.50              # (was 0.66)
    a_W::Float64   = 0.20              # (was 1.00)
    H_W::Float64   = 1.0
    L_W::Float64   = 1.0

    # ── Absorbing-regime productivity primitives (US) ──
    Abar_X_US::Float64 = 10.0          # HKT A_X·H = 10 (was 1.0)
    Abar_L_US::Float64 = 1.0           # HKT A_L·L = 1
    ν_b::Float64       = 1.00          # fixed-exponent experiment: held at 1.0 at every switch state

    # ── Unbalanced-regime productivity primitives (US) ──
    # ξ_u > ν_u drives ψ_US; ν_u > ν_b is a separate theorem-ordering
    # condition and is not required merely to solve the equilibrium equations.
    A_X_US_u::Float64 = 10.0           # HKT A_X·H = 10 (was 1.0)
    A_L_US_u::Float64 = 1.0            # HKT A_L·L = 1
    ξ_u::Float64      = 0.70           # HKT ξu=0.7 (was 1.20); ξ_u > ν_u
    ν_u::Float64      = 0.20           # HKT λu=0.2 (was 0.50)

    # ── RoW productivity primitives (common across regimes) ──
    Abar_X_W::Float64 = 10.0           # RoW mirrors HKT (was 1.0)
    Abar_L_W::Float64 = 1.0
    ξ_W::Float64      = 1.00           # requested RoW exponent for the fixed-ν_b experiment

    # ── Initial knowledge stocks ──
    N_US_0::Float64 = 1.0
    N_W_0::Float64  = 1.0

    # ── Compatibility marker (must remain false) ──
    # No equation in this solver enforces G_b == G_W and ν_b is never changed.
    common_world_growth::Bool = false

    # ── Simulation horizon (number of OLG periods) ──
    T_max::Int = 100               # HKT figure horizon (was 60)

    # ── Scratch-buffer periods beyond T_max (absorb terminal artifact). ──
    # -1 ⇒ use the default heuristic max(5, cld(T_max, 5)); ≥0 overrides it.
    n_buffer::Int = -1

    # ── Solver tolerances ──
    ftol::Float64    = 1e-9
    xtol::Float64    = 1e-10
    iterations::Int  = 4000
    branch_iters::Int = 30             # forward-backward sweeps for u-branch
    branch_tol::Float64 = 1e-7
    do_global_polish::Bool = false     # final 7T-equation joint polish (expensive)

    # ── Interiority floor for φ_US, φ_W (numerical regularization) ──
    # V4_3 ass_pathwise_interior_innovation allows φ_US^u → 0 asymptotically, but
    # the equilibrium kernel is singular near the deep-u corner (switch-branch
    # return R_A^b → 0). φ is bounded to [φ_floor, 1-φ_floor] in the solver.
    # Smaller tracks the corner more closely at the cost of robustness.
    φ_floor::Float64 = 1e-3
end

function validate_params(p::ProductionParams)
    @assert 0 < p.β < 1                               "β must be in (0,1)"
    @assert p.γ > 0                                   "γ must be > 0"
    @assert p.κ > 0                                   "κ must be > 0"
    @assert 0.5 ≤ p.ω̄ ≤ 1.0                           "ω̄ must be in [1/2, 1]"
    @assert 0 < p.ω̄_star < 0.5                        "ω̄* must be in (0, 1/2)"
    @assert p.χ > 0                                   "χ must be > 0"
    @assert p.η > 0                                   "η must be > 0"
    @assert 0 < p.π_persist < 1                       "π must be in (0,1)"
    @assert 0 < p.α_US < 1 && 0 < p.α_W < 1           "α in (0,1) per country"
    @assert p.ρ_US > 0 && p.ρ_W > 0                   "ρ > 0 per country"
    @assert 0 < p.ϑ_US < 1 && 0 < p.ϑ_W < 1           "ϑ in (0,1) per country"
    @assert p.a_US > 0 && p.a_W > 0                   "research productivity > 0"
    @assert p.H_US > 0 && p.H_W > 0                   "skilled labour > 0"
    @assert p.L_US > 0 && p.L_W > 0                   "unskilled labour > 0"
    @assert(
        p.ν_b ≥ 0 && p.ν_u ≥ 0 && p.ξ_u ≥ 0 && p.ξ_W ≥ 0,
        "productivity exponents must be nonnegative",
    )
    # The equilibrium equations require nonnegative exponents, but do not require
    # ν_u > ν_b. That inequality belongs to the paper's stronger sufficient
    # conditions. Keep solving when it fails (e.g. the requested fixed-ν_b
    # unbalanced-branch exercise), while making the loss of certification explicit.
    if !(p.ν_u > p.ν_b)
        @warn "V4_3 theorem ordering ν_u > ν_b is not satisfied; equilibrium results may still be computed, but theorem-based bubble certification is not established." ν_u=p.ν_u ν_b=p.ν_b
    end
    # Positive ψ_US := (ξ_u - ν_u)(ρ_US - 1) governs the unbalanced-tail
    # decay used by this solver, so these two strict inequalities remain required.
    @assert p.ξ_u > p.ν_u                             "V4_3 psi_US_def: ξ_u > ν_u"
    @assert p.ρ_US > 1                                "V4_3 psi_US_def: ρ_US > 1 for bubble theorem"
    @assert p.N_US_0 > 0 && p.N_W_0 > 0               "Initial knowledge stocks > 0"
    @assert 0 < p.φ_floor < 0.5                       "φ_floor must be in (0, 1/2)"
    _require_fixed_nu_b(p)
    nothing
end

# Kept separate from `validate_params` because notebook helpers sometimes call
# `solve_bgp_at` directly. A true legacy flag must not be silently interpreted
# as either fixed-ν_b or common-growth behavior.
function _require_fixed_nu_b(p::ProductionParams)
    p.common_world_growth && throw(ArgumentError(
        "This solver holds ν_b fixed and does not support common_world_growth=true. " *
        "Set common_world_growth=false (or omit it).",
    ))
    return nothing
end


# ─────────────────────────────────────────────────────────────────
# 2. Issuance-cost function Υ
# ─────────────────────────────────────────────────────────────────

abstract type IssuanceCost end
struct LogQuadraticCost <: IssuanceCost end

# Υ(θ) = -log(1-θ) + θ²/2  satisfies Ass. ass_issuance_costs (V9 §3)
upsilon(::LogQuadraticCost, θ)        = -log(1 - θ) + θ^2 / 2
upsilon_prime(::LogQuadraticCost, θ)  = 1 / (1 - θ) + θ
upsilon_pprime(::LogQuadraticCost, θ) = 1 / (1 - θ)^2 + 1

const DEFAULT_COST = LogQuadraticCost()
const REGULARITY_WEIGHT_TOL = 1e-3
const POLICY_BOUNDARY_TOL = 1e-10
const CERTIFICATION_RESIDUAL_TOL = 1e-5


# ─────────────────────────────────────────────────────────────────
# 3. CES production
# ─────────────────────────────────────────────────────────────────

# F(X̃, L̃) = (α X̃^(1-ρ) + (1-α) L̃^(1-ρ))^{1/(1-ρ)}
# with the Cobb-Douglas limit at ρ = 1.
function ces_F(α, ρ, X̃, L̃)
    if abs(ρ - 1) < sqrt(eps(float(ρ)))
        return X̃^α * L̃^(1 - α)
    end
    bracket = α * X̃^(1 - ρ) + (1 - α) * L̃^(1 - ρ)
    return bracket^(1 / (1 - ρ))
end

function ces_FX(α, ρ, X̃, L̃)
    if abs(ρ - 1) < sqrt(eps(float(ρ)))
        F = X̃^α * L̃^(1 - α)
        return α * F / X̃
    end
    bracket = α * X̃^(1 - ρ) + (1 - α) * L̃^(1 - ρ)
    return α * bracket^(ρ / (1 - ρ)) * X̃^(-ρ)
end

function ces_FL(α, ρ, X̃, L̃)
    if abs(ρ - 1) < sqrt(eps(float(ρ)))
        F = X̃^α * L̃^(1 - α)
        return (1 - α) * F / L̃
    end
    bracket = α * X̃^(1 - ρ) + (1 - α) * L̃^(1 - ρ)
    return (1 - α) * bracket^(ρ / (1 - ρ)) * L̃^(-ρ)
end


# ─────────────────────────────────────────────────────────────────
# 4. Country production block
# ─────────────────────────────────────────────────────────────────

# Returns (A_X, A_L) for US under a given regime.
function productivity_US(p::ProductionParams, regime::Symbol, N_US)
    if regime === :b
        return (p.Abar_X_US * N_US^p.ν_b, p.Abar_L_US * N_US^p.ν_b)
    elseif regime === :u
        return (p.A_X_US_u * N_US^p.ξ_u, p.A_L_US_u * N_US^p.ν_u)
    else
        error("Unknown regime: $regime (expected :u or :b)")
    end
end

function productivity_W(p::ProductionParams, N_W)
    return (p.Abar_X_W * N_W^p.ξ_W, p.Abar_L_W * N_W^p.ξ_W)
end

# Compute production, wages, per-variety prices, labour income, and IPO transfer.
# Returns NamedTuple with all primitive country quantities.
#   I = (1-φ)·H·w_H  is the IPO transfer to R&D workers (V4_3 eq. country_ipo_transfer).
#   By free entry w_H = a·N·q and the knowledge law N_+-N = a(1-φ)HN, we also have
#   I = (N_+-N)·q = (G_N-1)·N·q.
# Output decomposition (V4_3 eq. country_output_income_identity):
#       Y = φ·H·w_H + L·w_L + N·d  =  e + N·d - I,
#   which corrects the V9 identity Y = e + D by exactly the IPO transfer.
function compute_production(α, ρ, ϑ, a, H, L, φ, N, A_X, A_L)
    X    = φ * H
    X̃    = A_X * X
    L̃    = A_L * L
    Y    = ces_F(α, ρ, X̃, L̃)
    F_X  = ces_FX(α, ρ, X̃, L̃)
    F_L  = ces_FL(α, ρ, X̃, L̃)
    w_H  = ϑ * F_X * A_X
    w_L  = F_L * A_L
    q    = w_H / (a * N)
    d    = (1 - ϑ) / ϑ * w_H * (X / N)
    e    = w_H * H + w_L * L
    I    = (1 - φ) * H * w_H                    # V4_3 country_ipo_transfer
    return (Y=Y, X=X, w_H=w_H, w_L=w_L, q=q, d=d, e=e, I=I, A_X=A_X, A_L=A_L)
end

us_block(p::ProductionParams, regime::Symbol, φ_US, N_US) = let
    A_X, A_L = productivity_US(p, regime, N_US)
    compute_production(p.α_US, p.ρ_US, p.ϑ_US, p.a_US, p.H_US, p.L_US, φ_US, N_US, A_X, A_L)
end

row_block(p::ProductionParams, φ_W, N_W) = let
    A_X, A_L = productivity_W(p, N_W)
    compute_production(p.α_W, p.ρ_W, p.ϑ_W, p.a_W, p.H_W, p.L_W, φ_W, N_W, A_X, A_L)
end

# Knowledge growth factors
G_N_US(p::ProductionParams, φ_US) = 1 + p.a_US * (1 - φ_US) * p.H_US
G_N_W(p::ProductionParams, φ_W)   = 1 + p.a_W  * (1 - φ_W)  * p.H_W

# Effective-kernel divisor (V4_3 eq. effective_US_kernel, ass_regular_kernel line 1145).
#   Ψ_t := 1 - λ_t + φ_t(1 - ω_t)
# with portfolio wedges (V4_3 lines 1129–1131)
#   λ_t      = (η·θ_t/β)·Υ'(θ_t)
#   φ_wedge  = κ(ω_t - ω̄) / (β(1 - θ_t))
# Argument θ here is the US household bond share (recovered, negative in equilibrium).
function compute_psi(p::ProductionParams, ω, θ)
    Υp      = upsilon_prime(DEFAULT_COST, θ)
    λ_t     = (p.η * θ / p.β) * Υp                       # V4_3 line 1131
    φ_wedge = p.κ / (p.β * (1 - θ)) * (ω - p.ω̄)         # V4_3 line 1129
    return 1 - λ_t + φ_wedge * (1 - ω)                   # V4_3 eq. effective_US_kernel
end


# ─────────────────────────────────────────────────────────────────
# 5. Result structs
# ─────────────────────────────────────────────────────────────────

struct BGPResult
    # Policies
    φ_US::Float64; φ_W::Float64
    ω::Float64;    ω_star::Float64
    θ::Float64;    θ_US_star::Float64        # θ_US_star is the V4_3 primary unknown;
                                             # θ is recovered as -θ_US_star·A^*/A.
    R_f::Float64;  R_f_W::Float64

    # State at evaluation point
    N_US::Float64; N_W::Float64

    # Production / aggregates
    Y_US::Float64; Y_W::Float64
    e_US::Float64; e_W::Float64
    q_US::Float64; q_W::Float64
    d_US::Float64; d_W::Float64
    Q_US::Float64; Q_W::Float64
    I_US::Float64; I_W::Float64              # V4_3 country_ipo_transfer

    # Returns (deterministic)
    R_US::Float64; R_W::Float64
    R_p::Float64;  R_A::Float64
    R_p_star::Float64; R_A_star::Float64

    # Knowledge growth
    G_N_US::Float64; G_N_W::Float64
    ν_b_eff::Float64                         # compatibility field; always exactly params.ν_b here

    # V4_3 effective-kernel regularity (ass_regular_kernel)
    Psi::Float64

    # Diagnostics
    converged::Bool
    residual_norm::Float64
end

# Centralized factory for the zero/placeholder BGPResult so that adding new
# fields requires updating only one ctor call.
function _zero_bgp_result()
    BGPResult(0.,0.,0.,0.,0.,0.,0.,0.,             # 8 policy slots
              0.,0.,                               # 2 state slots
              0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,       # 10 prod/agg slots
              0.,0.,                               # I_US, I_W
              0.,0.,0.,0.,0.,0.,                   # 6 return slots
              1.,1.,0.,                            # 2 growth-factor slots + ν_b_eff
              NaN,                                 # Psi
              false, Inf)                          # converged, residual_norm
end

mutable struct UPeriodState
    t::Int
    N_US::Float64; N_W::Float64
    φ_US::Float64; φ_W::Float64
    ω::Float64;    ω_star::Float64
    θ::Float64;    θ_US_star::Float64        # θ_US_star primary; θ recovered.
    R_f::Float64;  R_f_W::Float64
    Y_US::Float64; Y_W::Float64
    e_US::Float64; e_W::Float64
    q_US::Float64; q_W::Float64
    d_US::Float64; d_W::Float64
    Q_US::Float64; Q_W::Float64
    I_US::Float64; I_W::Float64              # V4_3 country_ipo_transfer
    A::Float64;    A_star::Float64
    S::Float64;    S_star::Float64
    R_US_u::Float64; R_W_u::Float64; R_p_u::Float64; R_A_u::Float64
    R_p_star_u::Float64; R_A_star_u::Float64
    R_US_b::Float64; R_W_b::Float64; R_p_b::Float64; R_A_b::Float64
    R_p_star_b::Float64; R_A_star_b::Float64
    Psi::Float64                             # V4_3 ass_regular_kernel
    residual_norm::Float64
end

struct ProductionDiagnostics
    cond_1a::Vector{Float64}     # d_t^u / q_t^u  (V4_3 thm_cond_1a)
    cum_1a::Vector{Float64}
    cond_1b::Vector{Float64}     # (q_t^b + d_t^b)/q_t^u * (C_t^u/C_t^b)^γ  (V4_3 thm_cond_1b)
    cum_1b::Vector{Float64}
    a_t::Vector{Float64}         # leakage ratio
    cum_a_t::Vector{Float64}
    bubble_exists::Bool
    cond_1a_converges::Bool
    cond_1b_converges::Bool
    # V4_3 ass_regular_kernel (line 1145): Ψ_t > 0 along the u-branch.
    psi_path::Vector{Float64}
    psi_min::Float64
    psi_ok::Bool
    # V4_3 ass_interior_equity_weights: ω and ω* bounded away from 0 and 1.
    equity_weight_min::Float64
    equity_weights_ok::Bool
    # Geometric-tail certification of the Theorem-1 conditions (ratio test on the
    # summands' asymptotic decay). Certifies convergence of the *infinite* sums
    # Σ cond_1a, Σ cond_1b from a finite solved path: a summand decaying at
    # geometric ratio r<1 yields a convergent sum even when the fixed-window
    # tail fraction (cond_1a/1b_converges) has not yet dipped below 1% — which,
    # for the slowly-decaying cond_1b, needs a far longer horizon than the
    # u-branch solver can reach. (V4_3 thm_bubble_characterization.)
    ratio_1a::Float64        # fitted geometric decay ratio of d^u/q^u
    ratio_1b::Float64        # fitted geometric decay ratio of the 1b summand
    sum_inf_1a::Float64      # extrapolated Σ_{t=1}^∞ d^u/q^u
    sum_inf_1b::Float64      # extrapolated Σ_{t=1}^∞ branch-leakage summand
    geom_1a_converges::Bool  # ratio_1a < 1
    geom_1b_converges::Bool  # ratio_1b < 1
end

struct ProductionSimulationResult
    params::ProductionParams
    bgp_seq::Vector{BGPResult}          # BGP at (N_US,t^u, N_W,t)
    u_path::Vector{UPeriodState}
    bgp_seq_extended::Vector{BGPResult}
    u_path_extended::Vector{UPeriodState}
    diagnostics::ProductionDiagnostics
    branch_converged::Bool
    max_u_residual::Float64
    max_bgp_residual::Float64
end


# ─────────────────────────────────────────────────────────────────
# 6. Reduced 7-equation Markov competitive equilibrium solver
#    (V4_3 §"Reduced state-by-state characterization", lines 745–882).
#
#    Primary unknowns x = (φ_US, φ_W, ω, θ_US^*, ω^*, R_f, R_f^W)
#    at a given state s = (z, N_US, N_W).
#    Recovered bond shares (V4_3 lines 800–802):
#       θ_W^* = 0,
#       θ     = -θ_US^* · A^* / A.
#
#    Constraints enforced via transformations:
#      φ_US   = sigmoid(g1)         ∈ (0,1)
#      φ_W    = sigmoid(g2)         ∈ (0,1)
#      ω      = sigmoid(g3)         ∈ (0,1)
#      θ_US^* = exp(g4)             > 0      (V4_3: positive RoW US-bond demand)
#      ω^*    = sigmoid(g5)         ∈ (0,1)
#      R_f    = exp(g6)             > 0
#      R_f^W  = exp(g7)             > 0
# ─────────────────────────────────────────────────────────────────

sigmoid(x)       = 1 / (1 + exp(-x))
inv_sigmoid(p)   = log(p / (1 - p))

# Labour allocations φ_US, φ_W are bounded to [φ_floor, 1-φ_floor] via the
# constrained transform below (φ_floor is ProductionParams.φ_floor, threaded in).
# V4_3 ass_pathwise_interior_innovation allows φ_US^u → 0 asymptotically, but the
# equilibrium kernel is singular near the deep-u corner (the switch-branch return
# R_A^b → 0); the floor keeps the solver in the well-conditioned interior.
_phi_from(g, φ_floor) = φ_floor + (1 - 2 * φ_floor) * sigmoid(g)
_phi_to(p_val, φ_floor) = inv_sigmoid(clamp((p_val - φ_floor) / (1 - 2 * φ_floor), 1e-9, 1 - 1e-9))

function _bgp_unpack(x_c, φ_floor)
    g1, g2, g3, g4, g5, g6, g7 = x_c
    return (_phi_from(g1, φ_floor), _phi_from(g2, φ_floor), sigmoid(g3),
            exp(g4), sigmoid(g5), exp(g6), exp(g7))
end

function _bgp_pack(φ_US, φ_W, ω, θ_US_star, ω_s, R_f, R_f_W, φ_floor)
    [_phi_to(φ_US, φ_floor),
     _phi_to(φ_W, φ_floor),
     inv_sigmoid(clamp(ω,    1e-6, 1 - 1e-6)),
     log(max(θ_US_star, 1e-12)),
     inv_sigmoid(clamp(ω_s,  1e-6, 1 - 1e-6)),
     log(max(R_f, 1e-12)),
     log(max(R_f_W, 1e-12))]
end

function bgp_residual!(F, x_c, p::ProductionParams, N_US, N_W)
    # V4_3 reduced unknowns (line 787–788):
    #   x = (φ_US, φ_W, ω, θ_US^*, ω^*, R_f, R_f^W).
    φ_US, φ_W, ω, θ_US_star, ω_s, R_f, R_f_W = _bgp_unpack(x_c, p.φ_floor)

    us = us_block(p, :b, φ_US, N_US)
    rw = row_block(p, φ_W, N_W)

    A   = p.β * us.e
    As  = (p.β + p.χ) / (1 + p.χ) * rw.e
    θ   = -θ_US_star * As / A                   # V4_3 lines 800–802 (θ_W^*=0)
    S   = (1 - θ) * A
    Ss  = (1 - θ_US_star) * As

    G_US = G_N_US(p, φ_US)
    G_W  = G_N_W(p, φ_W)

    Q_US = G_US * N_US * us.q                   # = N_US,t+1 * q_US,t
    Q_W  = G_W  * N_W  * rw.q

    # Deterministic absorbing-regime returns
    R_US = G_US^(p.ν_b - 1) * (1 + us.d / us.q)
    R_W  = G_W ^(p.ξ_W - 1) * (1 + rw.d / rw.q)

    R_p   = ω   * R_US + (1 - ω)   * R_W
    R_A   = (1 - θ)    * R_p + θ * R_f
    R_ps  = ω_s * R_US + (1 - ω_s) * R_W
    R_As  = (1 - θ_US_star) * R_ps + θ_US_star * R_f

    if R_A ≤ 0 || R_As ≤ 0
        F .= 1e8
        return F
    end

    # V4_3 reduced 7-equation system (lines 818–855):
    #   F[1] = intratemporal_phi_US        (stock-market value clearing, US)
    #   F[2] = intratemporal_phi_W         (stock-market value clearing, RoW)
    #   F[3] = intratemporal_omega_US      (US ω FOC)
    #   F[4] = intratemporal_theta_US      (US θ FOC; Euler on recovered bond share)
    #   F[5] = intratemporal_omega_W       (RoW ω^* FOC)
    #   F[6] = intratemporal_thetaW        (RoW R_f^W = R_p^* in deterministic BGP)
    #   F[7] = intratemporal_thetaUS       (RoW θ_US^* clearing with χ wedge)
    sav_scale = max(A + As, 1e-12)
    F[1] = (Q_US - ω * S - ω_s * Ss) / sav_scale
    F[2] = (Q_W  - (1 - ω) * S - (1 - ω_s) * Ss) / sav_scale
    F[3] = p.β * (1 - θ)         * (R_US - R_W) / R_A   - p.κ * (ω   - p.ω̄)
    F[4] = p.β * (R_f - R_p)                    / R_A   - p.η * upsilon_prime(DEFAULT_COST, θ)
    F[5] = p.β * (1 - θ_US_star) * (R_US - R_W) / R_As  - p.κ * (ω_s - p.ω̄_star)
    F[6] = R_f_W - R_ps                                  # deterministic: R_f^W = R_p*
    F[7] = p.β * (R_f - R_ps) / R_As + p.χ / θ_US_star
    return F
end

function _bgp_make_result(p::ProductionParams, N_US, N_W, x_c,
                          is_converged::Bool, residual_norm::Float64;
                          validate::Bool=true)
    φ_US, φ_W, ω, θ_US_star, ω_s, R_f, R_f_W = _bgp_unpack(x_c, p.φ_floor)
    us = us_block(p, :b, φ_US, N_US)
    rw = row_block(p, φ_W, N_W)
    A   = p.β * us.e
    As  = (p.β + p.χ) / (1 + p.χ) * rw.e
    θ   = -θ_US_star * As / A                       # V4_3 lines 800–802
    G_US = G_N_US(p, φ_US)
    G_W  = G_N_W(p, φ_W)
    Q_US = G_US * N_US * us.q
    Q_W  = G_W  * N_W  * rw.q
    R_US = G_US^(p.ν_b - 1) * (1 + us.d / us.q)
    R_W  = G_W ^(p.ξ_W - 1) * (1 + rw.d / rw.q)
    R_p  = ω   * R_US + (1 - ω)   * R_W
    R_A  = (1 - θ)    * R_p + θ * R_f
    R_ps = ω_s * R_US + (1 - ω_s) * R_W
    R_As = (1 - θ_US_star) * R_ps + θ_US_star * R_f

    I_US = us.I
    I_W  = rw.I
    Psi  = compute_psi(p, ω, θ)

    if validate && is_converged
        _check_v43_identities("BGP(US)", us.Y, us.e, N_US, us.d, I_US, G_US, us.q)
        _check_v43_identities("BGP(W)",  rw.Y, rw.e, N_W,  rw.d, I_W,  G_W,  rw.q)
        if !(Psi > 0)
            @warn "V4_3 ass_regular_kernel violated at BGP: Ψ = $(Psi)" N_US N_W ω θ θ_US_star
        end
    end

    BGPResult(φ_US, φ_W, ω, ω_s, θ, θ_US_star, R_f, R_f_W,
              N_US, N_W, us.Y, rw.Y, us.e, rw.e,
              us.q, rw.q, us.d, rw.d, Q_US, Q_W,
              I_US, I_W,
              R_US, R_W, R_p, R_A, R_ps, R_As,
              G_US, G_W, p.ν_b,
              Psi,
              is_converged, residual_norm)
end

# Runtime checks of the V4_3 identities (country_ipo_transfer second equality;
# country_output_income_identity). Emit a warning on violation rather than
# erroring, because solver intermediates may transiently fail.
function _check_v43_identities(label, Y, e, N, d, I, G_N, q)
    tol = 1e-8
    I_alt = (G_N - 1) * N * q
    if abs(I - I_alt) > tol * max(abs(I), 1e-12)
        @warn "$label IPO identity I = (G_N-1)·N·q violated" I I_alt diff=I-I_alt
    end
    Y_alt = e + N * d - I
    if abs(Y - Y_alt) > tol * max(abs(Y), 1e-12)
        @warn "$label V4_3 output identity Y = e + N·d - I violated" Y Y_alt diff=Y-Y_alt
    end
    return nothing
end

"""
Solve the absorbing-regime stationary normalised system at (N_US, N_W).
"""
function solve_bgp_at(p::ProductionParams, N_US, N_W; x0_actual=nothing, verbose=false)
    _require_fixed_nu_b(p)
    # 4th coordinate is θ_US^* > 0 (V4_3 reduced primary unknown).
    # Baseline magnitudes: |θ| ≈ 0.05 at default params, so θ_US^* ≈ 0.05·A/A^* ≈ 0.05.
    if x0_actual === nothing
        x0_actual = (0.7, 0.7, p.ω̄, 0.05, p.ω̄_star, 1.5, 1.4)
    end

    candidate_starts = Tuple[]
    push!(candidate_starts, x0_actual)
    push!(candidate_starts, (0.5, 0.5, p.ω̄, 0.02,  p.ω̄_star, 1.5, 1.5))
    push!(candidate_starts, (0.8, 0.8, p.ω̄, 0.10,  p.ω̄_star, 2.0, 1.8))
    push!(candidate_starts, (0.3, 0.3, p.ω̄, 0.01,  p.ω̄_star, 1.0, 1.0))
    push!(candidate_starts, (0.6, 0.7, p.ω̄, 0.03,  p.ω̄_star, 1.2, 1.2))
    push!(candidate_starts, (0.4, 0.6, p.ω̄, 0.05,  p.ω̄_star, 1.3, 1.3))
    push!(candidate_starts, (0.2, 0.5, p.ω̄, 0.005, p.ω̄_star, 1.05, 1.02))
    push!(candidate_starts, (0.7, 0.7, p.ω̄, 0.20,  p.ω̄_star, 1.5, 1.4))

    best_x = nothing
    best_norm = Inf
    best_conv = false

    for x0 in candidate_starts
        x0_c = _bgp_pack(x0..., p.φ_floor)
        for method in (:trust_region, :newton)
            try
                r = nlsolve((F, x) -> bgp_residual!(F, x, p, N_US, N_W),
                            x0_c; autodiff=:forward, method=method,
                            ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)
                if r.residual_norm < best_norm
                    best_x = r.zero
                    best_norm = r.residual_norm
                    best_conv = converged(r)
                end
                if best_conv && best_norm < 1e-8; break; end
            catch err
                verbose && @info "Solver error at $(x0) [$(method)]: $(err)"
            end
        end
        if best_conv && best_norm < 1e-8; break; end
    end

    if best_x === nothing
        # Catastrophic failure
        x0_c = _bgp_pack(x0_actual..., p.φ_floor)
        F0 = zeros(7); bgp_residual!(F0, x0_c, p, N_US, N_W)
        verbose && @warn "BGP failed at (N_US, N_W)=($N_US, $N_W); returning initial guess"
        return _bgp_make_result(p, N_US, N_W, x0_c, false, norm(F0); validate=false)
    end

    return _bgp_make_result(p, N_US, N_W, best_x, best_conv, best_norm)
end


# ─────────────────────────────────────────────────────────────────
# 7. Fixed-ν_b absorbing-state selection
#    Each BGP is solved at the supplied state using the same primitive p.ν_b.
#    There is no additional common-world-growth equation.
# ─────────────────────────────────────────────────────────────────

"""
Compatibility stub for notebooks written against the common-growth solver.
This fixed-ν_b implementation never recalibrates a primitive and therefore
rejects calls to `calibrate_common_growth` explicitly.
"""
function calibrate_common_growth(args...; kwargs...)
    throw(ArgumentError(
        "calibrate_common_growth is unavailable in the fixed-ν_b solver; " *
        "solve_bgp_at uses the supplied ProductionParams.ν_b unchanged.",
    ))
end

"""
Solve the selected absorbing BGP at a given predetermined state.

The supplied `p.ν_b` is used unchanged at every state. `BGPResult.ν_b_eff`
is retained for notebook compatibility and is always equal to `p.ν_b`.
"""
function solve_selected_bgp_at(p::ProductionParams, N_US, N_W; x0_actual=nothing,
                               verbose::Bool=false)
    _require_fixed_nu_b(p)
    return solve_bgp_at(p, N_US, N_W; x0_actual=x0_actual, verbose=verbose)
end

# Retain the continuation hook used by the branch solver, but never alter p.ν_b.
function _bgp_continuation_seed(p::ProductionParams, previous::BGPResult)
    _require_fixed_nu_b(p)
    return p
end

# Freshly solved BGPs land near 1e-13, so this bound is loose by eight orders
# of magnitude and fires only on an object that does not belong to the state it
# is being attached to.
const BGP_STATE_RESIDUAL_TOL = 1e-5

"""
Residual of the reduced 7-equation BGP system when the stored allocations of
`result` are re-evaluated at the state `(N_US, N_W)` under the fixed primitive
`p.ν_b`. Checking the state-specific equations prevents a stale continuation
entry from being accepted merely because its cached fields are finite.
"""
function _bgp_state_residual_norm(p::ProductionParams, result::BGPResult, N_US, N_W)
    _require_fixed_nu_b(p)
    (isfinite(N_US) && isfinite(N_W) && N_US > 0 && N_W > 0) || return Inf
    all(isfinite, (result.φ_US, result.φ_W, result.ω, result.θ_US_star,
                   result.ω_star, result.R_f, result.R_f_W,
                   result.ν_b_eff)) || return Inf
    result.ν_b_eff == p.ν_b || return Inf
    x_c = _bgp_pack(result.φ_US, result.φ_W, result.ω, result.θ_US_star,
                    result.ω_star, result.R_f, result.R_f_W, p.φ_floor)
    F = zeros(7)
    try
        bgp_residual!(F, x_c, p, N_US, N_W)
    catch
        return Inf
    end
    return all(isfinite, F) ? norm(F) : Inf
end

function _usable_bgp_continuation(p::ProductionParams, result::BGPResult, N_US, N_W)
    _require_fixed_nu_b(p)
    fixed_exponent_ok = isfinite(result.ν_b_eff) && result.ν_b_eff == p.ν_b
    stored_ok = result.converged && isfinite(result.residual_norm) &&
           result.residual_norm < 1e-5 && fixed_exponent_ok &&
           all(isfinite, (result.φ_US, result.φ_W, result.ω,
                          result.θ_US_star, result.ω_star,
                          result.R_f, result.R_f_W, result.ν_b_eff))
    stored_ok || return false
    # The stored allocations must solve the system at THIS date's state.
    return _bgp_state_residual_norm(p, result, N_US, N_W) < BGP_STATE_RESIDUAL_TOL
end


# ─────────────────────────────────────────────────────────────────
# 8. Knowledge-stock paths
# ─────────────────────────────────────────────────────────────────

"""
Forward-compute knowledge stocks along the u-history given a vector of φ_US,t.
Returns Vector{Float64} of length T+1: N_US^u at t = 0, 1, ..., T.
"""
function knowledge_path_US(p::ProductionParams, φ_US_path::Vector{<:Real})
    T = length(φ_US_path)
    N = Vector{Float64}(undef, T + 1)
    N[1] = p.N_US_0
    for t in 1:T
        N[t+1] = G_N_US(p, φ_US_path[t]) * N[t]
    end
    N
end

function knowledge_path_W(p::ProductionParams, φ_W_path::Vector{<:Real})
    T = length(φ_W_path)
    N = Vector{Float64}(undef, T + 1)
    N[1] = p.N_W_0
    for t in 1:T
        N[t+1] = G_N_W(p, φ_W_path[t]) * N[t]
    end
    N
end


# ─────────────────────────────────────────────────────────────────
# 9. Unbalanced-branch residual: 7 unknowns at each date t
#    (φ_US, φ_W, ω, θ_US^*, ω^*, R_f, R_f^W)   per V4_3 line 787–788.
#    BGPResult-at-t+1 is treated as a fixed input (for use within
#    forward-backward iteration).
# ─────────────────────────────────────────────────────────────────

# Same constrained transformation as BGP — inherits the V4_3 θ_US^* swap.
_u_unpack(x_c, φ_floor) = _bgp_unpack(x_c, φ_floor)
_u_pack(φ_US, φ_W, ω, θ_US_star, ω_s, R_f, R_f_W, φ_floor) =
    _bgp_pack(φ_US, φ_W, ω, θ_US_star, ω_s, R_f, R_f_W, φ_floor)

"""
Residual for the date-t u-branch system.
Inputs:
  N_US_t, N_W_t          : current predetermined state
  next_u                 : NamedTuple (φ_US, φ_W, q_US, q_W, d_US, d_W, N_US, N_W)
                            for the u-successor at t+1
  next_b                 : BGPResult at the b-successor evaluated at (N_US_t+1^u, N_W_t+1)
"""
function u_residual!(F, x_c, p::ProductionParams,
                     N_US_t, N_W_t,
                     next_u, next_b::BGPResult)
    # V4_3 reduced unknowns at date t (line 787–788):
    #   x = (φ_US, φ_W, ω, θ_US^*, ω^*, R_f, R_f^W).
    φ_US, φ_W, ω, θ_US_star, ω_s, R_f, R_f_W = _u_unpack(x_c, p.φ_floor)

    us_t = us_block(p, :u, φ_US, N_US_t)
    rw_t = row_block(p, φ_W, N_W_t)

    A    = p.β * us_t.e
    As   = (p.β + p.χ) / (1 + p.χ) * rw_t.e
    θ    = -θ_US_star * As / A                       # V4_3 lines 800–802
    S    = (1 - θ) * A
    Ss   = (1 - θ_US_star) * As

    G_US = G_N_US(p, φ_US)
    G_W  = G_N_W(p, φ_W)
    N_US_tp1 = G_US * N_US_t
    N_W_tp1  = G_W  * N_W_t

    Q_US_t = N_US_tp1 * us_t.q
    Q_W_t  = N_W_tp1  * rw_t.q

    # Re-evaluate successor production at the implied N_US_tp1, N_W_tp1.
    # RoW technology is regime-invariant, but its equilibrium allocation and
    # valuation are branch-specific through φ_W(s), so use next_b.φ_W on the
    # switch branch.
    us_u_next = us_block(p, :u, next_u.φ_US, N_US_tp1)
    rw_u_next = row_block(p,    next_u.φ_W,  N_W_tp1)

    R_US_u = (us_u_next.q + us_u_next.d) / us_t.q
    R_W_u  = (rw_u_next.q + rw_u_next.d) / rw_t.q

    # Use the selected switch-branch BGP objects as stored. Every such object was
    # solved at its own predetermined state with the same fixed primitive p.ν_b.
    R_US_b = (next_b.q_US + next_b.d_US) / us_t.q
    R_W_b  = (next_b.q_W  + next_b.d_W)  / rw_t.q

    R_p_u   = ω   * R_US_u + (1 - ω)   * R_W_u
    R_A_u   = (1 - θ)    * R_p_u + θ * R_f
    R_ps_u  = ω_s * R_US_u + (1 - ω_s) * R_W_u
    R_As_u  = (1 - θ_US_star) * R_ps_u + θ_US_star * R_f

    R_p_b   = ω   * R_US_b + (1 - ω)   * R_W_b
    R_A_b   = (1 - θ)    * R_p_b + θ * R_f
    R_ps_b  = ω_s * R_US_b + (1 - ω_s) * R_W_b
    R_As_b  = (1 - θ_US_star) * R_ps_b + θ_US_star * R_f

    if R_A_u ≤ 0 || R_A_b ≤ 0 || R_As_u ≤ 0 || R_As_b ≤ 0
        F .= 1e8
        return F
    end

    π_p = p.π_persist
    γ   = p.γ

    # Kernels (V4_3 US_K_def, V4_3 RoW analogue)
    E_RA_pow  = π_p * R_A_u^(1 - γ) + (1 - π_p) * R_A_b^(1 - γ)
    K_u = R_A_u^(-γ) / E_RA_pow
    K_b = R_A_b^(-γ) / E_RA_pow

    E_RAs_pow = π_p * R_As_u^(1 - γ) + (1 - π_p) * R_As_b^(1 - γ)
    M_u = R_As_u^(-γ) / E_RAs_pow
    M_b = R_As_b^(-γ) / E_RAs_pow

    # Expectations
    E_K_dR  = π_p * K_u * (R_US_u - R_W_u)  + (1 - π_p) * K_b * (R_US_b - R_W_b)
    E_K_dRf = π_p * K_u * (R_f    - R_p_u)  + (1 - π_p) * K_b * (R_f    - R_p_b)
    E_M_dR  = π_p * M_u * (R_US_u - R_W_u)  + (1 - π_p) * M_b * (R_US_b - R_W_b)
    E_M_dRf = π_p * M_u * (R_f    - R_ps_u) + (1 - π_p) * M_b * (R_f    - R_ps_b)
    E_M_dRfW= π_p * M_u * (R_f_W  - R_ps_u) + (1 - π_p) * M_b * (R_f_W  - R_ps_b)

    # V4_3 reduced 7-equation u-branch system (lines 818–855, expectation form).
    sav_scale = max(A + As, 1e-12)
    F[1] = (Q_US_t - ω * S - ω_s * Ss) / sav_scale
    F[2] = (Q_W_t  - (1 - ω) * S - (1 - ω_s) * Ss) / sav_scale
    F[3] = p.β * (1 - θ)         * E_K_dR  - p.κ * (ω   - p.ω̄)
    F[4] = p.β * E_K_dRf                   - p.η * upsilon_prime(DEFAULT_COST, θ)
    F[5] = p.β * (1 - θ_US_star) * E_M_dR  - p.κ * (ω_s - p.ω̄_star)
    F[6] = p.β * E_M_dRfW
    F[7] = p.β * E_M_dRf + p.χ / θ_US_star
    return F
end

# ─────────────────────────────────────────────────────────────────
# 10. Backward-induction over the u-branch
#     Outer loop: alternate between
#       (i)  fix {φ_US,t^u} → forward-compute {N_US,t^u},
#            solve BGP at each N_US,t+1^u,
#            backward-induct to update y_t^u,
#       (ii) extract new {φ_US,t^u} and check convergence.
# ─────────────────────────────────────────────────────────────────

function _build_u_period(p, t, N_US_t, N_W_t,
                        φ_US, φ_W, ω, ω_s, θ_US_star, R_f, R_f_W,
                        next_u, next_b::BGPResult, residual_norm)
    # 9th positional argument is θ_US^* (primary, V4_3); θ is recovered.
    us_t = us_block(p, :u, φ_US, N_US_t)
    rw_t = row_block(p, φ_W, N_W_t)
    A    = p.β * us_t.e
    As   = (p.β + p.χ) / (1 + p.χ) * rw_t.e
    θ    = -θ_US_star * As / A                       # V4_3 lines 800–802
    S    = (1 - θ) * A
    Ss   = (1 - θ_US_star) * As
    G_US = G_N_US(p, φ_US)
    G_W  = G_N_W(p, φ_W)
    N_US_tp1 = G_US * N_US_t
    N_W_tp1  = G_W  * N_W_t
    Q_US = N_US_tp1 * us_t.q
    Q_W  = N_W_tp1  * rw_t.q

    us_u_next = us_block(p, :u, next_u.φ_US, N_US_tp1)
    rw_u_next = row_block(p,    next_u.φ_W,  N_W_tp1)
    R_US_u = (us_u_next.q + us_u_next.d) / us_t.q
    R_W_u  = (rw_u_next.q + rw_u_next.d) / rw_t.q
    R_US_b = (next_b.q_US + next_b.d_US) / us_t.q
    R_W_b  = (next_b.q_W  + next_b.d_W)  / rw_t.q

    R_p_u  = ω * R_US_u + (1 - ω) * R_W_u
    R_A_u  = (1 - θ) * R_p_u + θ * R_f
    R_ps_u = ω_s * R_US_u + (1 - ω_s) * R_W_u
    R_As_u = (1 - θ_US_star) * R_ps_u + θ_US_star * R_f

    R_p_b  = ω * R_US_b + (1 - ω) * R_W_b
    R_A_b  = (1 - θ) * R_p_b + θ * R_f
    R_ps_b = ω_s * R_US_b + (1 - ω_s) * R_W_b
    R_As_b = (1 - θ_US_star) * R_ps_b + θ_US_star * R_f

    I_US = us_t.I
    I_W  = rw_t.I
    Psi  = compute_psi(p, ω, θ)

    UPeriodState(t, N_US_t, N_W_t,
                 φ_US, φ_W, ω, ω_s, θ, θ_US_star, R_f, R_f_W,
                 us_t.Y, rw_t.Y, us_t.e, rw_t.e,
                 us_t.q, rw_t.q, us_t.d, rw_t.d, Q_US, Q_W,
                 I_US, I_W,
                 A, As, S, Ss,
                 R_US_u, R_W_u, R_p_u, R_A_u, R_ps_u, R_As_u,
                 R_US_b, R_W_b, R_p_b, R_A_b, R_ps_b, R_As_b,
                 Psi,
                 residual_norm)
end

"""
Pack a (7, T+1) policy matrix into a constrained 7T-vector (terminal pol[:,T+1] held fixed).
"""
function _pack_policy(pol::Matrix{Float64}, T::Int, φ_floor)
    x = Vector{Float64}(undef, 7 * T)
    for t in 1:T
        xc = _u_pack(pol[1,t], pol[2,t], pol[3,t], pol[4,t],
                     pol[5,t], pol[6,t], pol[7,t], φ_floor)
        x[7*(t-1)+1:7*t] .= xc
    end
    x
end

"""
Unpack the 7T-vector back into actual values for policy[:, 1..T].
"""
function _unpack_policy_actual(x::AbstractVector, T::Int, φ_floor)
    pol = Matrix{Float64}(undef, 7, T)
    for t in 1:T
        a = _u_unpack(x[7*(t-1)+1:7*t], φ_floor)
        pol[:, t] .= [a[1], a[2], a[3], a[4], a[5], a[6], a[7]]
    end
    pol
end

"""
Global residual: assemble all 7T equations from the period-by-period u-residual,
with N_US, N_W trajectories computed forward from the current policy guess.
"""
function _u_branch_global_residual!(F, x, p::ProductionParams,
                                    bgp_seq::Vector{BGPResult},
                                    pol_terminal::Vector{Float64})
    T = length(bgp_seq) - 1   # bgp_seq has T+1 entries

    # Decode policy, compute knowledge paths
    pol = Matrix{eltype(x)}(undef, 7, T + 1)
    for t in 1:T
        a = _u_unpack(x[7*(t-1)+1:7*t], p.φ_floor)
        pol[:, t] .= [a[1], a[2], a[3], a[4], a[5], a[6], a[7]]
    end
    pol[:, T+1] .= pol_terminal

    # Forward N_US, N_W
    N_US = Vector{eltype(x)}(undef, T + 1)
    N_W  = Vector{eltype(x)}(undef, T + 1)
    N_US[1] = p.N_US_0
    N_W[1]  = p.N_W_0
    for t in 1:T
        N_US[t+1] = G_N_US(p, pol[1, t]) * N_US[t]
        N_W[t+1]  = G_N_W(p, pol[2, t]) * N_W[t]
    end

    # Build residuals at each t = 1..T
    Ft = zeros(eltype(x), 7)
    for t in 1:T
        next_u = (φ_US=pol[1, t+1], φ_W=pol[2, t+1])
        next_b = bgp_seq[t+1]
        x_t = x[7*(t-1)+1:7*t]
        u_residual!(Ft, x_t, p, N_US[t], N_W[t], next_u, next_b)
        F[7*(t-1)+1:7*t] .= Ft
    end
    return F
end

"""
Polish the u-branch by solving all 7T equations simultaneously.
Returns the polished policy matrix (7, T+1) or nothing on failure.
"""
function _polish_u_branch_global(p::ProductionParams,
                                  pol::Matrix{Float64},
                                  bgp_seq::Vector{BGPResult};
                                  verbose::Bool=false)
    T = size(pol, 2) - 1
    pol_terminal = copy(pol[:, T+1])
    x0 = _pack_policy(pol, T, p.φ_floor)

    try
        r = nlsolve((F, x) -> _u_branch_global_residual!(F, x, p, bgp_seq, pol_terminal),
                    x0; autodiff=:forward, method=:trust_region,
                    ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)
        verbose && @printf("  polish ‖F‖=%.2e converged=%s\n", r.residual_norm, converged(r))
        if r.residual_norm < 1e-4
            new_pol_inner = _unpack_policy_actual(r.zero, T, p.φ_floor)
            out = Matrix{Float64}(undef, 7, T + 1)
            out[:, 1:T] .= new_pol_inner
            out[:, T+1] .= pol_terminal
            return out
        else
            return nothing
        end
    catch err
        verbose && @info "Polish solve error: $err"
        return nothing
    end
end

"""
Try to solve the date-t u-residual using multiple strategies.
Returns (best_x_c::Vector, best_norm::Float64, converged::Bool).
Stops early as soon as a converged solution with ‖F‖<1e-8 is found.
"""
function _solve_u_residual_at_t(p::ProductionParams,
                                N_US_t, N_W_t,
                                next_u, next_b::BGPResult,
                                start_guesses::Vector)
    best_x = nothing
    best_norm = Inf
    best_conv = false

    for x0 in start_guesses
        x0_c = _u_pack(x0..., p.φ_floor)
        try
            r = nlsolve((F, x) -> u_residual!(F, x, p, N_US_t, N_W_t, next_u, next_b),
                        x0_c; autodiff=:forward, method=:trust_region,
                        ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)
            if r.residual_norm < best_norm
                best_x = r.zero
                best_norm = r.residual_norm
                best_conv = converged(r)
            end
            if best_conv && best_norm < 1e-8; break; end
        catch; end
    end
    # Newton fallback if no good solution
    if !best_conv || best_norm > 1e-6
        for x0 in start_guesses[1:min(2, length(start_guesses))]
            x0_c = _u_pack(x0..., p.φ_floor)
            try
                r = nlsolve((F, x) -> u_residual!(F, x, p, N_US_t, N_W_t, next_u, next_b),
                            x0_c; autodiff=:forward, method=:newton,
                            ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)
                if r.residual_norm < best_norm
                    best_x = r.zero
                    best_norm = r.residual_norm
                    best_conv = converged(r)
                end
                if best_conv && best_norm < 1e-8; break; end
            catch; end
        end
    end
    return (best_x, best_norm, best_conv)
end

# Decay-consistent terminal closure for the all-u continuation.
# The all-u branch genuinely continues in u (it does NOT switch to BGP at the
# horizon), and its labour allocations decay monotonically along it — for the US,
# φ_US^u ≲ N_US^{-ψ_US/ρ_US} (V4_3 lem_prod_orders upper bound), ψ_US=(ξ_u-ν_u)(ρ_US-1).
# A flat closure φ_{T+1}=φ_T contradicts the period-T Euler equation on a
# decaying branch and leaves a terminal residual. We instead extrapolate the
# successor allocations (φ_US, φ_W) log-linearly from the last two solved
# interior periods, i.e. φ_{i,T+1} = φ_{i,T}^2 / φ_{i,T-1}, which tracks the
# *local* decay rate (more accurate at finite T than the asymptotic ψ_US/ρ_US
# rate). The portfolio/return coordinates are carried forward unchanged: they
# enter period T only as warm-start guesses, since next_u uses only (φ_US, φ_W).
function _extrapolate_terminal!(pol::Matrix{Float64}, T::Int)
    pol[:, T+1] .= pol[:, T]
    if T >= 2
        for i in (1, 2)                       # φ_US, φ_W
            a, b = pol[i, T-1], pol[i, T]
            if a > 1e-12 && b > 1e-12
                pol[i, T+1] = clamp(b * b / a, 1e-8, 1 - 1e-8)
            end
        end
    end
    return pol
end

"""
Seed a longer-horizon policy matrix from an already solved u-path. Existing
dates are copied exactly; newly appended dates carry the portfolio/return
coordinates forward and extend the two labour allocations log-linearly. This
changes only the numerical initial guess, not the equilibrium equations or the
terminal closure applied during the solve.
"""
function _seed_policy_from_u_path!(pol::Matrix{Float64},
                                   initial_u_path::AbstractVector,
                                   T::Int)
    isempty(initial_u_path) && return 0
    n_available = min(length(initial_u_path), T)
    n_seed = 0
    for t in 1:n_available
        s = initial_u_path[t]
        values = Float64[s.φ_US, s.φ_W, s.ω, s.θ_US_star,
                         s.ω_star, s.R_f, s.R_f_W]
        all(isfinite, values) || break
        pol[:, t] .= values
        n_seed = t
    end
    n_seed == 0 && return 0

    for t in (n_seed + 1):(T + 1)
        pol[:, t] .= pol[:, t - 1]
        if t >= 3
            for i in (1, 2)
                a, b = pol[i, t - 2], pol[i, t - 1]
                if isfinite(a) && isfinite(b) && a > 1e-12 && b > 1e-12
                    pol[i, t] = clamp(b * b / a, 1e-8, 1 - 1e-8)
                end
            end
        end
    end
    return n_seed
end

"""
Solve the unbalanced branch by forward-backward iteration.
- At iteration k, hold the trajectory {N_US,t^u} fixed (computed forward
  from a guess of φ_US^u).
- Solve BGP at each (N_US,t+1^u, N_W,t+1).
- Backward-induct y_t^u using the BGP and the next u-period guess.
- Update the trajectory {φ_US,t^u} and iterate.
"""
function solve_unbalanced_branch(p::ProductionParams,
                                 bgp_init::BGPResult;
                                 verbose::Bool=false,
                                 initial_u_path=nothing,
                                 initial_bgp_seq=nothing)
    # Solve a few "scratch" buffer periods beyond the reported horizon so that
    # every *reported* period 1..T_report has a genuinely solved u-successor.
    # The finite-horizon terminal artifact — both the moving-target decay
    # closure and the deep-u φ→0 ill-conditioning (q_US^u→∞ as φ→0) — is then
    # confined to the buffer, which is trimmed before returning.
    T_report = p.T_max
    n_buffer = p.n_buffer >= 0 ? p.n_buffer : max(5, cld(T_report, 5))
    T = T_report + n_buffer

    # Initial guess: φ_US^u = bgp_init.φ_US for all t,  φ_W = bgp_init.φ_W for all t
    φ_US_path = fill(bgp_init.φ_US, T + 1)
    φ_W_path  = fill(bgp_init.φ_W,  T + 1)

    # A parameter-continuation warm start must influence the predetermined
    # states used during the *initial* BGP-sequence construction. Previously,
    # initial_u_path was copied only after that construction, so a nearby
    # parameter case could fail before its warm start was ever used. Seed a
    # temporary policy matrix here solely to obtain the initial φ paths; the
    # regular policy matrix is still rebuilt from the newly solved BGP sequence
    # below, and the equilibrium equations and terminal closure are unchanged.
    if initial_u_path !== nothing
        warm_pol = Matrix{Float64}(undef, 7, T + 1)
        warm_pol .= reshape(
            [bgp_init.φ_US, bgp_init.φ_W, bgp_init.ω,
             bgp_init.θ_US_star, bgp_init.ω_star,
             bgp_init.R_f, bgp_init.R_f_W],
            7, 1,
        )
        _seed_policy_from_u_path!(warm_pol, initial_u_path, T)
        φ_US_path .= warm_pol[1, :]
        φ_W_path  .= warm_pol[2, :]
    end

    # Forward path of N's (will recompute each iteration)
    N_US_path = knowledge_path_US(p, φ_US_path[1:T])
    N_W_path  = knowledge_path_W(p, φ_W_path[1:T])

    # Solve BGP at each forward state (used as switch successor)
    bgp_seq = Vector{BGPResult}(undef, T + 1)
    bgp_seq[1] = bgp_init
    for t in 2:(T + 1)
        seed_bgp = initial_bgp_seq !== nothing && t <= length(initial_bgp_seq) ?
            initial_bgp_seq[t] : bgp_seq[t-1]
        x0 = (seed_bgp.φ_US, seed_bgp.φ_W, seed_bgp.ω,
              seed_bgp.θ_US_star, seed_bgp.ω_star,
              seed_bgp.R_f, seed_bgp.R_f_W)
        p_seed = _bgp_continuation_seed(p, bgp_seq[t-1])
        candidate = solve_selected_bgp_at(
            p_seed, N_US_path[t], N_W_path[t]; x0_actual=x0)
        _usable_bgp_continuation(p, candidate, N_US_path[t], N_W_path[t]) ||
            error("Absorbing-BGP continuation failed during initialization at t=$(t).")
        bgp_seq[t] = candidate
    end

    # u-path policy storage.
    # After V4_3 alignment: pol[4, :] stores θ_US^* (positive); the recovered
    # US bond share is θ(s, x) = -pol[4, t] * A^*(s, x) / A(s, x).
    pol = Matrix{Float64}(undef, 7, T + 1)
    # Initialise from BGP at each date
    for t in 1:(T + 1)
        pol[:, t] .= [bgp_seq[t].φ_US, bgp_seq[t].φ_W, bgp_seq[t].ω, bgp_seq[t].θ_US_star,
                      bgp_seq[t].ω_star, bgp_seq[t].R_f, bgp_seq[t].R_f_W]
    end
    if initial_u_path !== nothing
        n_seed = _seed_policy_from_u_path!(pol, initial_u_path, T)
        verbose && println("  warm-started u-policy from $n_seed solved periods")
    end
    # Finite-horizon terminal condition for the all-u continuation:
    # decay-consistent extrapolation of the u-successor (not a flat repeat,
    # which would contradict the period-T Euler equation on a decaying branch).
    _extrapolate_terminal!(pol, T)
    φ_US_path = copy(pol[1, 1:T+1])
    φ_W_path  = copy(pol[2, 1:T+1])

    converged_flag = false
    last_residual_norms = fill(NaN, T)

    for outer_it in 1:p.branch_iters
        # ---- Step 1: forward N_US_path from the current φ_US_path ----
        N_US_path = knowledge_path_US(p, pol[1, 1:T])
        N_W_path  = knowledge_path_W(p, pol[2, 1:T])

        # ---- Step 2: re-solve BGP at each forward state ----
        n_bgp_failed = 0
        first_bgp_failed_t = 0
        for t in 2:(T + 1)
            x0 = (bgp_seq[t-1].φ_US, bgp_seq[t-1].φ_W, bgp_seq[t-1].ω, bgp_seq[t-1].θ_US_star,
                  bgp_seq[t-1].ω_star, bgp_seq[t-1].R_f, bgp_seq[t-1].R_f_W)
            try
                p_seed = _bgp_continuation_seed(p, bgp_seq[t-1])
                candidate = solve_selected_bgp_at(
                    p_seed, N_US_path[t], N_W_path[t]; x0_actual=x0)
                accepted = _usable_bgp_continuation(
                    p, candidate, N_US_path[t], N_W_path[t])
                accepted && (bgp_seq[t] = candidate)
                # Whatever occupies date t now -- freshly solved or carried over
                # from an earlier sweep -- must solve the BGP system at this
                # date's own state. Without this, a rejected candidate silently
                # leaves a stale successor in place and the path is certified
                # against a state the model has already left.
                if !accepted && !_usable_bgp_continuation(
                        p, bgp_seq[t], N_US_path[t], N_W_path[t])
                    n_bgp_failed += 1
                    first_bgp_failed_t == 0 && (first_bgp_failed_t = t)
                end
            catch
                n_bgp_failed += 1
                first_bgp_failed_t == 0 && (first_bgp_failed_t = t)
                # Abort this outer sweep after collecting the first bad date.
            end
        end
        # A cold iterate may temporarily leave the regular BGP domain and
        # recover after the policy path moves. A warm continuation that fails
        # exactly at its newly required terminal successor is different: using
        # a stale BGP there would certify a horizon whose defining successor
        # was never solved.
        if initial_u_path !== nothing && first_bgp_failed_t == T + 1
            error(
                "Absorbing-BGP continuation failed during outer iteration " *
                "$(outer_it) at the required terminal successor t=$(T + 1).",
            )
        end

        # ---- Step 3: backward induction along u-branch ----
        # Terminal condition: decay-consistent extrapolation of y_{T+1}^u.
        _extrapolate_terminal!(pol, T)
        residual_norms = zeros(T + 1)
        n_failed = 0

        for t in T:-1:1
            N_US_t = N_US_path[t]
            N_W_t  = N_W_path[t]

            # Successor at t+1 (u): use current pol[:, t+1]
            φ_US_next, φ_W_next = pol[1, t+1], pol[2, t+1]
            next_u = (φ_US=φ_US_next, φ_W=φ_W_next)

            # Successor at t+1 (b): BGP at (N_US_path[t+1], N_W_path[t+1])
            next_b = bgp_seq[t+1]

            # Initial-guess pool: prev solution, BGP at this date, neighbour values
            bgp_t = bgp_seq[t]
            start_guesses = Tuple[]
            push!(start_guesses, (pol[1, t], pol[2, t], pol[3, t], pol[4, t],
                                  pol[5, t], pol[6, t], pol[7, t]))
            push!(start_guesses, (bgp_t.φ_US, bgp_t.φ_W, bgp_t.ω, bgp_t.θ_US_star,
                                  bgp_t.ω_star, bgp_t.R_f, bgp_t.R_f_W))
            if t <= T
                push!(start_guesses, (pol[1, t+1], pol[2, t+1], pol[3, t+1], pol[4, t+1],
                                      pol[5, t+1], pol[6, t+1], pol[7, t+1]))
            end
            # Perturbed BGP guesses
            push!(start_guesses, (max(bgp_t.φ_US * 0.7, 0.05), bgp_t.φ_W,
                                  bgp_t.ω, bgp_t.θ_US_star, bgp_t.ω_star,
                                  bgp_t.R_f, bgp_t.R_f_W))
            push!(start_guesses, (min(bgp_t.φ_US * 1.3, 0.95), bgp_t.φ_W,
                                  bgp_t.ω, bgp_t.θ_US_star, bgp_t.ω_star,
                                  bgp_t.R_f, bgp_t.R_f_W))

            best_x, best_norm, best_conv = _solve_u_residual_at_t(
                p, N_US_t, N_W_t, next_u, next_b, start_guesses)

            spurious = false
            if best_x === nothing
                spurious = true
            else
                φ_US_t, φ_W_t, ω_t, θ_US_star_t, ω_s_t, R_f_t, R_f_W_t = _u_unpack(best_x, p.φ_floor)
                spurious = best_norm > 1e-3 ||
                           φ_US_t < POLICY_BOUNDARY_TOL || φ_US_t > 1 - POLICY_BOUNDARY_TOL ||
                           φ_W_t  < POLICY_BOUNDARY_TOL || φ_W_t  > 1 - POLICY_BOUNDARY_TOL ||
                           ω_t < POLICY_BOUNDARY_TOL || ω_t > 1 - POLICY_BOUNDARY_TOL ||
                           ω_s_t < POLICY_BOUNDARY_TOL || ω_s_t > 1 - POLICY_BOUNDARY_TOL ||
                           !isfinite(R_f_t) || !isfinite(R_f_W_t) ||
                           R_f_t < 0 || R_f_W_t < 0
            end

            if spurious
                n_failed += 1
                residual_norms[t] = best_x === nothing ? Inf : best_norm
                # Replace pol[:, t] by interpolation from neighbours so the
                # spurious value does not persist forever.
                if t < T
                    # Linear interp φ_US between t-1 (or BGP at t) and t+1
                    if t > 1
                        pol[:, t] .= 0.5 .* (pol[:, t-1] .+ pol[:, t+1])
                    else
                        pol[:, t] .= pol[:, t+1]
                    end
                else
                    pol[:, t] .= pol[:, t+1]
                end
                continue
            end

            φ_US_t, φ_W_t, ω_t, θ_US_star_t, ω_s_t, R_f_t, R_f_W_t = _u_unpack(best_x, p.φ_floor)
            pol[:, t] .= [φ_US_t, φ_W_t, ω_t, θ_US_star_t, ω_s_t, R_f_t, R_f_W_t]
            residual_norms[t] = best_norm
            best_conv || (n_failed += 1)
        end
        _extrapolate_terminal!(pol, T)

        last_residual_norms = residual_norms[1:T]

        # ---- Step 4: convergence check on both endogenous knowledge paths ----
        new_φ_US_path = pol[1, 1:T+1]
        new_φ_W_path  = pol[2, 1:T+1]
        Δ_US = maximum(abs.(new_φ_US_path .- φ_US_path))
        Δ_W  = maximum(abs.(new_φ_W_path  .- φ_W_path))
        Δ = max(Δ_US, Δ_W)
        # Convergence is judged on the reported region [1:T_report]; the scratch
        # buffer absorbs the terminal artifact and is excluded from the test.
        finite_norms = filter(isfinite, residual_norms[1:T_report])
        max_norm = isempty(finite_norms) ? Inf : maximum(finite_norms)

        verbose && @printf("  outer %2d: Δφ_US=%.2e, Δφ_W=%.2e, max ‖F‖[1:T_rep]=%.2e, u_fails=%d/%d, bgp_fails=%d/%d\n",
                            outer_it, Δ_US, Δ_W, max_norm,
                            n_failed, T, n_bgp_failed, T)

        φ_US_path = new_φ_US_path
        φ_W_path  = new_φ_W_path

        if Δ < p.branch_tol && max_norm < 1e-5 &&
           n_failed == 0 && n_bgp_failed == 0
            converged_flag = true
            verbose && println("  forward-backward converged at iter $outer_it")
            break
        end
    end

    # ---- Optional polish: solve all 7T equations simultaneously ----
    # Expensive (Jacobian is 7T × 7T) and holds the switch-BGP sequence fixed;
    # the final residual rebuild below is the authoritative convergence check.
    if p.do_global_polish && (!converged_flag || any(>(1e-5), filter(isfinite, last_residual_norms)))
        verbose && println("  polishing via simultaneous 7T-equation solve...")
        polished = _polish_u_branch_global(p, pol, bgp_seq, verbose=verbose)
        if polished !== nothing
            pol = polished
            converged_flag = true
        end
    end

    if !converged_flag
        verbose && @warn "Forward-backward did not fully converge after $(p.branch_iters) iters."
    end

    # ---- Build u_path objects ----
    _extrapolate_terminal!(pol, T)
    N_US_path = knowledge_path_US(p, pol[1, 1:T])
    N_W_path  = knowledge_path_W(p, pol[2, 1:T])
    final_bgp_valid = true
    for t in 2:(T + 1)
        x0 = (bgp_seq[t-1].φ_US, bgp_seq[t-1].φ_W, bgp_seq[t-1].ω, bgp_seq[t-1].θ_US_star,
              bgp_seq[t-1].ω_star, bgp_seq[t-1].R_f, bgp_seq[t-1].R_f_W)
        try
            p_seed = _bgp_continuation_seed(p, bgp_seq[t-1])
            candidate = solve_selected_bgp_at(
                p_seed, N_US_path[t], N_W_path[t]; x0_actual=x0)
            accepted = _usable_bgp_continuation(
                p, candidate, N_US_path[t], N_W_path[t])
            accepted && (bgp_seq[t] = candidate)
            if !accepted && !_usable_bgp_continuation(
                    p, bgp_seq[t], N_US_path[t], N_W_path[t])
                final_bgp_valid = false
            end
        catch
            final_bgp_valid = false
        end
    end

    u_path = Vector{UPeriodState}(undef, T)
    for t in 1:T
        N_US_t = N_US_path[t]; N_W_t = N_W_path[t]
        next_u = (φ_US=pol[1, t+1], φ_W=pol[2, t+1])
        next_b = bgp_seq[t+1]
        F = zeros(7); xc = _u_pack(pol[1,t], pol[2,t], pol[3,t], pol[4,t],
                                    pol[5,t], pol[6,t], pol[7,t], p.φ_floor)
        u_residual!(F, xc, p, N_US_t, N_W_t, next_u, next_b)
        u_path[t] = _build_u_period(p, t, N_US_t, N_W_t,
                                    pol[1,t], pol[2,t], pol[3,t], pol[5,t],
                                    pol[4,t], pol[6,t], pol[7,t],
                                    next_u, next_b, norm(F))
    end
    # ---- Preserve the full solve, then trim the scratch buffer for reporting ----
    # The buffer periods absorb the finite-horizon terminal artifact, so every
    # reported period has a genuinely solved u-successor.
    u_path_extended = u_path
    bgp_seq_extended = bgp_seq
    u_path  = u_path_extended[1:T_report]
    bgp_seq = bgp_seq_extended[1:T_report + 1]

    final_residuals = [s.residual_norm for s in u_path]
    final_max_norm = isempty(final_residuals) ? Inf : maximum(final_residuals)
    # The final residual rebuild on the reported region is the authoritative
    # convergence test: the outer-loop flag can lag (the moving-target terminal
    # extrapolation keeps Δφ above branch_tol even when residuals are tiny).
    converged_flag = final_max_norm < 1e-5 && final_bgp_valid

    return (u_path=u_path, bgp_seq=bgp_seq,
            u_path_extended=u_path_extended, bgp_seq_extended=bgp_seq_extended,
            converged=converged_flag)
end


# ─────────────────────────────────────────────────────────────────
# 11. Bubble diagnostics (V4_3 Theorem 1 conditions)
# ─────────────────────────────────────────────────────────────────

# Geometric-tail certification for a Theorem-1 summand sequence.
# The conditions are about convergence of an *infinite* sum Σ cond_t; the
# fixed-window "tail < 1% of the partial sum" rule is only a finite-horizon
# proxy and gives a false negative when the summand decays slowly (e.g. cond_1b
# at ratio ≈ 0.93/period needs T ≈ 60 to register, far past the u-branch solver
# wall). Instead we fit the asymptotic decay ratio r by log-linear least squares
# over the last k+1 solved terms: a sequence with r < 1 converges, and the tail
# beyond the last solved term is the closed-form geometric sum cond_T·r/(1-r).
# Returns (ratio, sum_inf, converges).
function _geometric_tail(cond::AbstractVector{<:Real}, cum_end::Real; k_max::Int=6)
    T = length(cond)
    T < 3 && return (NaN, Inf, false)
    k  = clamp(k_max, 2, T - 1)
    xs = Float64[]; ys = Float64[]
    for t in (T - k):T
        cond[t] > 0 && (push!(xs, float(t)); push!(ys, log(cond[t])))
    end
    length(ys) < 2 && return (NaN, Inf, false)
    # OLS slope b of log(cond) ~ a + b·t ;  geometric ratio r = exp(b).
    x̄ = sum(xs) / length(xs); ȳ = sum(ys) / length(ys)
    Sxx = sum(abs2, xs .- x̄)
    Sxx ≤ 0 && return (NaN, Inf, false)
    b = sum((xs .- x̄) .* (ys .- ȳ)) / Sxx
    ratio = exp(b)
    converges = isfinite(ratio) && 0 < ratio < 1
    sum_inf = converges ? cum_end + cond[T] * ratio / (1 - ratio) : Inf
    return (ratio, sum_inf, converges)
end

function compute_diagnostics(p::ProductionParams,
                              u_path::Vector{UPeriodState},
                              bgp_seq::Vector{BGPResult})
    T = length(u_path)
    π_p = p.π_persist
    γ   = p.γ

    # The theorem's first summand is a successor-date branch object. With
    # Julia's 1-based path storage, u_path[j] is the date-(j-1) state and stores
    # returns into the two date-j successor branches. Therefore term j uses
    # u_path[j] for R_A^u/R_A^b and u_path[j+1], bgp_seq[j+1] for q,d.
    # Keep vectors aligned with u_path for notebook compatibility: index 1 is
    # the initial state and carries no theorem summand, so it remains zero.
    n_terms = T
    cond_1a = zeros(n_terms)
    cond_1b = zeros(n_terms)
    a_t     = zeros(n_terms)

    for j in 1:max(T - 1, 0)
        prev = u_path[j]
        u_t  = u_path[j + 1]
        b_t  = bgp_seq[j + 1]
        k = j + 1

        q_u = u_t.q_US
        q_b = b_t.q_US
        d_b = b_t.d_US

        cond_1a[k] = u_t.d_US / q_u
        ratio = prev.R_A_u / prev.R_A_b   # C_t^u/C_t^b; A_{t-1}^u cancels
        cond_1b[k] = (q_b + d_b) / q_u * ratio^γ
        a_t[k] = cond_1a[k] + (1 - π_p) / π_p * cond_1b[k]
    end

    cum_1a = cumsum(cond_1a)
    cum_1b = cumsum(cond_1b)
    cum_at = cumsum(a_t)

    sum_1a_end = isempty(cum_1a) ? 0.0 : cum_1a[end]
    sum_1b_end = isempty(cum_1b) ? 0.0 : cum_1b[end]
    n_tail = max(1, max(n_terms, 1) ÷ 10)
    tail_start = max(1, n_terms - n_tail + 1)
    pre_tail_1a = tail_start == 1 || isempty(cum_1a) ? 0.0 : cum_1a[tail_start - 1]
    pre_tail_1b = tail_start == 1 || isempty(cum_1b) ? 0.0 : cum_1b[tail_start - 1]
    tail_1a = sum_1a_end - pre_tail_1a
    tail_1b = sum_1b_end - pre_tail_1b
    conv_1a = tail_1a < 0.01 * max(sum_1a_end, 1e-15)
    conv_1b = tail_1b < 0.01 * max(sum_1b_end, 1e-15)

    # Geometric-tail certification (ratio test) — robust to the finite horizon.
    ratio_1a, sum_inf_1a, geom_1a = _geometric_tail(cond_1a, sum_1a_end)
    ratio_1b, sum_inf_1b, geom_1b = _geometric_tail(cond_1b, sum_1b_end)

    # V4_3 ass_regular_kernel (line 1145): Ψ_t > 0 along the u-branch.
    psi_path = Float64[s.Psi for s in u_path]
    psi_min  = isempty(psi_path) ? NaN : minimum(psi_path)
    psi_ok   = all(>(0), psi_path)

    equity_slack = Float64[]
    for t in 1:T
        u_t = u_path[t]
        push!(equity_slack, min(u_t.ω, 1 - u_t.ω, u_t.ω_star, 1 - u_t.ω_star))
        if t <= length(bgp_seq)
            b_t = bgp_seq[t]
            push!(equity_slack, min(b_t.ω, 1 - b_t.ω, b_t.ω_star, 1 - b_t.ω_star))
        end
    end
    equity_weight_min = isempty(equity_slack) ? NaN : minimum(equity_slack)
    equity_weights_ok = isfinite(equity_weight_min) && equity_weight_min > REGULARITY_WEIGHT_TOL

    u_residuals_ok = !isempty(u_path) &&
                     all(s -> isfinite(s.residual_norm) &&
                              s.residual_norm < CERTIFICATION_RESIDUAL_TOL, u_path)
    bgp_residuals_ok = !isempty(bgp_seq) &&
                       all(b -> b.converged && isfinite(b.residual_norm) &&
                                b.residual_norm < CERTIFICATION_RESIDUAL_TOL, bgp_seq)

    # Keep equilibrium solvability distinct from the paper's sufficient-condition
    # certificate. In particular, validation only warns when ν_u <= ν_b, but the
    # theorem-facing headline must not certify that out-of-order calibration.
    theorem_exponent_ordering_ok = p.ξ_u > p.ν_u > p.ν_b ≥ 0 && p.ρ_US > 1
    bubble = theorem_exponent_ordering_ok &&
             geom_1a && geom_1b && psi_ok && equity_weights_ok &&
             u_residuals_ok && bgp_residuals_ok

    ProductionDiagnostics(cond_1a, cum_1a, cond_1b, cum_1b,
                          a_t, cum_at, bubble, conv_1a, conv_1b,
                          psi_path, psi_min, psi_ok,
                          equity_weight_min, equity_weights_ok,
                          ratio_1a, ratio_1b, sum_inf_1a, sum_inf_1b,
                          geom_1a, geom_1b)
end


# ─────────────────────────────────────────────────────────────────
# 12. Switch-path simulation helper
# ─────────────────────────────────────────────────────────────────

function _path_record(s::UPeriodState, regime::Symbol)
    (t=s.t, regime=regime,
     φ_US=s.φ_US, φ_W=s.φ_W,
     q_US=s.q_US, d_US=s.d_US,
     q_W=s.q_W, d_W=s.d_W,
     Q_US=s.Q_US, Q_W=s.Q_W,
     e_US=s.e_US, e_W=s.e_W,
     Y_US=s.Y_US, Y_W=s.Y_W,
     N_US=s.N_US, N_W=s.N_W,
     I_US=s.I_US, I_W=s.I_W,
     ω=s.ω, ω_star=s.ω_star,
     θ=s.θ, θ_US_star=s.θ_US_star,
     R_f=s.R_f, R_f_W=s.R_f_W,
     Psi=s.Psi)
end

function _path_record(t::Int, b::BGPResult, regime::Symbol)
    (t=t, regime=regime,
     φ_US=b.φ_US, φ_W=b.φ_W,
     q_US=b.q_US, d_US=b.d_US,
     q_W=b.q_W, d_W=b.d_W,
     Q_US=b.Q_US, Q_W=b.Q_W,
     e_US=b.e_US, e_W=b.e_W,
     Y_US=b.Y_US, Y_W=b.Y_W,
     N_US=b.N_US, N_W=b.N_W,
     I_US=b.I_US, I_W=b.I_W,
     ω=b.ω, ω_star=b.ω_star,
     θ=b.θ, θ_US_star=b.θ_US_star,
     R_f=b.R_f, R_f_W=b.R_f_W,
     Psi=b.Psi)
end

"""
Build a realized path with switch date τ.

The economy is on the solved u-branch for t < τ and on the absorbing
branch for t ≥ τ.  After the switch, knowledge stocks are advanced using
the absorbing BGP allocations, not the all-u knowledge path used for
one-period switch successors in the backward-induction solver.
"""
function build_switch_path(result::ProductionSimulationResult, τ::Int; T::Int=length(result.u_path))
    p = result.params
    @assert 1 ≤ τ ≤ T + 1
    path = NamedTuple[]

    for t in 1:min(T, τ - 1)
        push!(path, _path_record(result.u_path[t], :u))
    end

    if τ ≤ T
        N_US = result.u_path[τ].N_US
        N_W  = result.u_path[τ].N_W
        guess_idx = min(τ, length(result.bgp_seq))
        guess = result.bgp_seq[guess_idx]
        x0 = (guess.φ_US, guess.φ_W, guess.ω, guess.θ_US_star,
              guess.ω_star, guess.R_f, guess.R_f_W)

        for t in τ:T
            b = solve_selected_bgp_at(p, N_US, N_W; x0_actual=x0)
            push!(path, _path_record(t, b, :b))
            x0 = (b.φ_US, b.φ_W, b.ω, b.θ_US_star, b.ω_star, b.R_f, b.R_f_W)
            N_US *= G_N_US(p, b.φ_US)
            N_W  *= G_N_W(p, b.φ_W)
        end
    end

    return path
end


# ─────────────────────────────────────────────────────────────────
# 13. Top-level orchestrator
# ─────────────────────────────────────────────────────────────────

"""
End-to-end V4_3 production-economy simulation.

Steps:
1. Validate parameters.
2. Hold the supplied primitive ν_b fixed; do not impose `G_b = G_W`.
3. Solve the absorbing equilibrium at the initial state (N_US,0, N_W,0) via the
   reduced 7-equation Markov competitive equilibrium system
   (V4_3 lines 818–855).
4. Solve unbalanced branch by forward-backward iteration.
5. Compute Theorem 1 bubble diagnostics and Ψ-regularity check
   (V4_3 thm_bubble_characterization, ass_regular_kernel).
"""
function run_production_simulation(p::ProductionParams=ProductionParams();
                                    verbose::Bool=true,
                                    initial_u_path=nothing,
                                    initial_bgp_seq=nothing)
    validate_params(p)

    p_use = p
    verbose && @printf("Solving absorbing equilibrium with fixed ν_b = %.6f...\n", p.ν_b)
    bgp0 = solve_bgp_at(p, p.N_US_0, p.N_W_0)
    verbose && @printf("  BGP: φ_b=%.4f  φ_W=%.4f  ω=%.4f  θ_US^*=%+.4f  θ=%+.4f  ω*=%.4f  R_f=%.4f  R_f^W=%.4f\n",
                       bgp0.φ_US, bgp0.φ_W, bgp0.ω, bgp0.θ_US_star, bgp0.θ,
                       bgp0.ω_star, bgp0.R_f, bgp0.R_f_W)
    verbose && @printf("  V4_3 Ψ = %.4f   I_US = %.4e   I_W = %.4e\n",
                       bgp0.Psi, bgp0.I_US, bgp0.I_W)
    verbose && @printf("  Residual norm: %.2e (converged: %s)\n",
                       bgp0.residual_norm, bgp0.converged)

    verbose && println("Solving unbalanced branch by forward-backward iteration...")
    branch = solve_unbalanced_branch(p_use, bgp0;
                                     verbose=verbose,
                                     initial_u_path=initial_u_path,
                                     initial_bgp_seq=initial_bgp_seq)

    verbose && println("Computing bubble diagnostics...")
    diag = compute_diagnostics(p_use, branch.u_path, branch.bgp_seq)
    max_u_residual = isempty(branch.u_path) ? NaN : maximum(s.residual_norm for s in branch.u_path)
    max_bgp_residual = isempty(branch.bgp_seq) ? NaN : maximum(b.residual_norm for b in branch.bgp_seq)

    if verbose
        @printf("  u-branch converged: %s   max ‖F_u‖ = %.2e\n",
                branch.converged, max_u_residual)
        if !branch.converged || !(max_u_residual < 1e-5)
            @warn "u-branch did not meet the requested residual tolerance; diagnostics are provisional." max_u_residual
        end
    end

    if verbose
        println("\n══════ V4_3 PRODUCTION-ECONOMY DIAGNOSTICS ══════")
        @printf("  Condition (1a) converges: %s   (Σ d^u/q^u  = %.6f)\n",
                diag.cond_1a_converges, diag.cum_1a[end])
        @printf("  Condition (1b) converges: %s   (Σ branch   = %.6f)\n",
                diag.cond_1b_converges, diag.cum_1b[end])
        @printf("  Geometric-tail (1a): ratio=%.4f  converges=%s  Σ_∞=%.6f\n",
                diag.ratio_1a, diag.geom_1a_converges, diag.sum_inf_1a)
        @printf("  Geometric-tail (1b): ratio=%.4f  converges=%s  Σ_∞=%.6f\n",
                diag.ratio_1b, diag.geom_1b_converges, diag.sum_inf_1b)
        @printf("  BUBBLE EXISTS: %s  (tail, regularity, and residual checks)\n", diag.bubble_exists)
        @printf("  Total leakage Σ a_t = %.6f\n", diag.cum_a_t[end])
        @printf("  V4_3 ass_regular_kernel  Ψ_t > 0: %s  (min Ψ = %.4e)\n",
                diag.psi_ok, diag.psi_min)
        @printf("  V4_3 ass_interior_equity_weights: %s  (min slack = %.4e)\n",
                diag.equity_weights_ok, diag.equity_weight_min)
        if !diag.equity_weights_ok
            @warn "equity weights are too close to 0 or 1 for the V4_3 sufficient-condition diagnostics." min_slack=diag.equity_weight_min
        end
    end

    ProductionSimulationResult(p_use, branch.bgp_seq, branch.u_path,
                               branch.bgp_seq_extended, branch.u_path_extended,
                               diag,
                               branch.converged, max_u_residual, max_bgp_residual)
end


# ─────────────────────────────────────────────────────────────────
# 14. Original fast-growth calibration (pre-HKT defaults)
#     ProductionParams DEFAULTS are the fixed-ν_b experiment (see §1).
#     This constructor recovers the ORIGINAL fast-growth example, whose
#     aggressive knowledge growth (a_US·H=1.2 ⇒ G_u→2.2) drives φ_US^u into the
#     deep-u corner within ~20 periods and caps the u-branch solver at T≈20.
#     Kept for the convergence/robustness comparison against the HKT default.
# ─────────────────────────────────────────────────────────────────
function fast_growth_params(; T_max::Int=20, n_buffer::Int=-1,
                            common_world_growth::Bool=false)
    ProductionParams(;
        β=0.5, γ=0.5,
        # ── US production block (original fast-growth example) ──
        α_US=0.40, ρ_US=2.00, ϑ_US=0.66, a_US=1.20, H_US=1.0, L_US=1.0,
        A_X_US_u=1.0, A_L_US_u=1.0, ξ_u=1.20, ν_u=0.50,
        Abar_X_US=1.0, Abar_L_US=1.0, ν_b=0.30,
        N_US_0=1.0,
        # ── RoW (original) ──
        α_W=0.30, ρ_W=1.50, ϑ_W=0.66, a_W=1.00, H_W=1.0, L_W=1.0,
        Abar_X_W=1.0, Abar_L_W=1.0, ξ_W=0.30, N_W_0=1.0,
        common_world_growth=common_world_growth,
        T_max=T_max, n_buffer=n_buffer)
end


# ─────────────────────────────────────────────────────────────────
# 15. Fundamental-value decomposition & US NFA (the project's ultimate goal:
#     measure how the US per-variety stock bubble drives negative US NFA)
#
#  Per-variety US stock pricing (V4_3 effective_US_kernel, lines 1115–1207):
#      q_{US,t} = E_t[ M_{t,t+1} (q_{US,t+1} + d_{US,t+1}) ],
#      M_{t,t+1} = K_{t,t+1} / Ψ_t,
#      K_{t,t+1} = R_{A,t+1}^{-γ} / E_t[R_{A,t+1}^{1-γ}].
#  Fundamental value  v_{US,t} = E_t[ Σ_{s≥1} M_{t,t+s} d_{US,t+s} ];
#  per-variety bubble B_{US,t} = q_{US,t} - v_{US,t} = lim_T E_t[M_{t,T} q_{US,T}].
#  On the absorbing branch q = v (V4_3 prop_no_bubble_absorbing_branch).  The
#  result-level recursion applies the no-bubble terminal closure on the extended
#  scratch-buffer horizon, then trims back to the reported path.
#
#  Aggregate market cap Q_{US,t} = N_{US,t+1} q_{US,t} (V4_3 country_stock_aggregation),
#  so the aggregate fundamental/bubble scale by the same N_{US,t+1}:
#      V_{Q,t} = N_{US,t+1} v_{US,t} = Q_{US,t} (v_t/q_t),  B_{Q,t} = Q_{US,t} - V_{Q,t}.
#
#  US net foreign assets. Stock-market clearing Q_US = ω S + ω* S* with S=(1-θ)A,
#  S*=(1-θ_US^*)A^* makes the portfolio weights cancel (same algebra as the
#  endowment model), leaving the total (equity+bond) identity
#      NFA_t = (1-ω_t)(1-θ_t)A_t - ω_t^*(1-θ_{US,t}^*)A_t^* + θ_t A_t = A_t - Q_{US,t},
#  with A_t = β e_{US,t}. Hence the bubble decomposition
#      NFA = (A - V_Q) + (-B_Q):  the US stock bubble B_Q > 0 directly lowers US NFA.
# ─────────────────────────────────────────────────────────────────

"""
    us_effective_kernel(R_A_u, R_A_b, γ, π_persist, Ψ) -> (M_u, M_b)

One-step *effective* US stock-pricing kernels on the two date-(t+1) branches
(V4_3 eq. effective_US_kernel). With the undistorted kernel
`K_z = R_{A}^{z,-γ}/E[R_A^{1-γ}]` and the date-t portfolio wedge `Ψ`,
`M_z = K_z/Ψ`. This is the same kernel built inline in [`u_residual!`](@ref),
exposed here for the fundamental-value recursion.
"""
function us_effective_kernel(R_A_u, R_A_b, γ, π_persist, Ψ)
    E_pow = π_persist * R_A_u^(1 - γ) + (1 - π_persist) * R_A_b^(1 - γ)
    K_u = R_A_u^(-γ) / E_pow
    K_b = R_A_b^(-γ) / E_pow
    return (K_u / Ψ, K_b / Ψ)
end

"""
    fundamental_value_path(p, u_path, bgp_seq) -> NamedTuple

Fundamental value of the per-variety US stock along the supplied all-`u`
branch by backward recursion with the effective kernel (V4_3
effective_US_kernel), plus its aggregate-market-cap counterpart. Returns
length-`T` vectors:

- `v`            per-variety fundamental value `v_{US,t}`
- `B_per`        per-variety bubble `q_{US,t} - v_{US,t}`
- `V_agg`        aggregate fundamental `N_{US,t+1} v_{US,t} = Q_{US,t}(v_t/q_t)`
- `B_agg`        aggregate bubble `Q_{US,t} - V_agg`
- `bubble_share` `B_agg/Q_{US,t}` (`= B_per/q_{US,t}`)

Low-level terminal closure is `v_T = bgp_seq[T].q_US`, the no-bubble
absorbing-branch per-variety price at the terminal predetermined state
(V4_3 prop_no_bubble_absorbing_branch). For quantitative work, prefer
`fundamental_value_path(result)`: it applies this closure on the extended
scratch-buffer path and trims back to the reported horizon. The kernel at date
`t` uses the stored total-saving returns `u_path[t].R_A_u`, `u_path[t].R_A_b`
(returns realized at `t+1` on the continuation/switch branch) and the wedge
`u_path[t].Psi`; the date-`t+1` switch-branch successor is the BGP at the common
predetermined state, `bgp_seq[t+1]` (V4_3 lem_branch_reduction).
"""
function fundamental_value_path(p::ProductionParams,
                                u_path::Vector{UPeriodState},
                                bgp_seq::Vector{BGPResult})
    T = length(u_path)
    @assert length(bgp_seq) ≥ T "bgp_seq must cover every u-period"
    v = zeros(T)
    v[T] = bgp_seq[T].q_US                       # no bubble on absorbing branch
    for t in (T - 1):-1:1
        s = u_path[t]
        M_u, M_b = us_effective_kernel(s.R_A_u, s.R_A_b, p.γ, p.π_persist, s.Psi)
        d_u_next = u_path[t + 1].d_US             # continuation-branch dividend
        v_b_next = bgp_seq[t + 1].q_US            # switch-branch price (= fundamental)
        d_b_next = bgp_seq[t + 1].d_US
        v[t] = p.π_persist       * M_u * (v[t + 1] + d_u_next) +
               (1 - p.π_persist) * M_b * (v_b_next + d_b_next)
    end
    q     = [s.q_US for s in u_path]
    Q     = [s.Q_US for s in u_path]
    B_per = q .- v
    V_agg = Q .* (v ./ q)                         # = N_{US,t+1} v_t
    B_agg = Q .- V_agg
    bubble_share = B_agg ./ Q
    return (v=v, B_per=B_per, V_agg=V_agg, B_agg=B_agg, bubble_share=bubble_share)
end

function _trim_fundamental_value(fv, T::Int)
    return (v=fv.v[1:T],
            B_per=fv.B_per[1:T],
            V_agg=fv.V_agg[1:T],
            B_agg=fv.B_agg[1:T],
            bubble_share=fv.bubble_share[1:T])
end

"""
    fundamental_value_path(result::ProductionSimulationResult) -> NamedTuple

Buffered fundamental-value recursion for quantitative decomposition.  The
recursion is run on `result.u_path_extended` and `result.bgp_seq_extended`,
then trimmed to `length(result.u_path)`, so reported-period fundamentals do not
depend directly on a BGP terminal closure at the reported horizon.
"""
function fundamental_value_path(result::ProductionSimulationResult)
    T_report = length(result.u_path)
    fv_ext = fundamental_value_path(result.params,
                                    result.u_path_extended,
                                    result.bgp_seq_extended)
    return _trim_fundamental_value(fv_ext, T_report)
end

"""
    nfa_decomposition(result) -> NamedTuple

US net-foreign-asset decomposition along the all-`u` branch. With savings
`A_t = β e_{US,t}` (`UPeriodState.A`) and aggregate market cap `Q_{US,t}`,

    NFA_t = A_t - Q_{US,t} = (A_t - V_{Q,t}) + (-B_{Q,t}),

so the aggregate bubble `B_{Q,t} > 0` lowers US NFA one-for-one. The
balanced-state counterfactual is `NFA^b_t = A_t - Q^b_{US,t}`
(`Q^b_{US,t} = bgp_seq[t].Q_US`, no bubble in state `b`), with b-branch
saving `A^b_t = β e^b_{US,t}`. The gap

    ΔNFA_t = NFA^u_t - NFA^b_t
            = (A^u_t - A^b_t) + (V^b_{Q,t} - V_{Q,t}) + (-B_{Q,t}),
      V^b_{Q,t}=Q^b_{US,t}.

Both decompositions are exact equilibrium identities (additive to machine
precision). Returns vectors `A, Q_US, V_agg, B_agg, NFA, NFA_fund, NFA_bubble,
NFA_b_cf, ΔNFA, ΔA, ΔV, ΔB, bubble_share`.
"""
function nfa_decomposition(result::ProductionSimulationResult)
    p, u_path, bgp_seq = result.params, result.u_path, result.bgp_seq
    fv = fundamental_value_path(result)
    T  = length(u_path)
    A      = [s.A    for s in u_path]
    A_b    = [p.β * bgp_seq[t].e_US for t in 1:T]
    Q_US   = [s.Q_US for s in u_path]
    Q_US_b = [bgp_seq[t].Q_US for t in 1:T]       # balanced-state counterfactual
    NFA        = A .- Q_US
    NFA_fund   = A .- fv.V_agg                     # A - V_Q
    NFA_bubble = .-fv.B_agg                        # -B_Q
    NFA_b_cf   = A_b .- Q_US_b
    ΔNFA = NFA .- NFA_b_cf
    ΔA   = A .- A_b
    ΔV   = Q_US_b .- fv.V_agg                      # V^b - V^u (V^b = Q_US_b)
    ΔB   = .-fv.B_agg                              # -B_Q
    return (A=A, A_b=A_b, Q_US=Q_US, V_agg=fv.V_agg, B_agg=fv.B_agg,
            NFA=NFA, NFA_fund=NFA_fund, NFA_bubble=NFA_bubble,
            NFA_b_cf=NFA_b_cf, ΔNFA=ΔNFA, ΔA=ΔA, ΔV=ΔV, ΔB=ΔB,
            bubble_share=fv.bubble_share)
end
